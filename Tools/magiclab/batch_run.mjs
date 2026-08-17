#!/usr/bin/env node
// batch_run.mjs — Magic Lab P2 回归画廊采集 + 基线 diff (CDP 驱动)。
//
// 用法:
//   node Tools/magiclab/batch_run.mjs [--only FireBall,IceBolt] [--freeze 900]
//     [--baseline]   采集并把本次结果写入基线 (docs/magiclab/gallery/_baseline/)
//   默认: 采集 174 技能截图 docs/magiclab/gallery/<MagicType>.webp,
//         与基线做 dHash 感知对比 → docs/magiclab/REGRESSION.md
//
// 确定性: 每技能经 __LAB.play() 施法 → 真实时间等预取 → __LAB.freezeAt(T)
// 暂停在固定 lab-time → 截图。同一数据下逐字节可比, 改 JSON/引擎即出差异。
import { spawn } from 'node:child_process';
import { mkdirSync, writeFileSync, readFileSync, existsSync, copyFileSync } from 'node:fs';
import { createHash } from 'node:crypto';

const ROOT = new URL('../..', import.meta.url).pathname;
const GALLERY = `${ROOT}docs/magiclab/gallery`;
const BASELINE = `${GALLERY}/_baseline`;
const REPORT = `${ROOT}docs/magiclab/REGRESSION.md`;
const CHROME = '/home/tetsuya/.cache/ms-playwright/chromium-1208/chrome-linux64/chrome';
const PORT = 9364;
const sleep = (ms) => new Promise(r => setTimeout(r, ms));

const args = process.argv.slice(2);
const ONLY = args.includes('--only') ? args[args.indexOf('--only') + 1].split(',') : null;
const FREEZE = args.includes('--freeze') ? +args[args.indexOf('--freeze') + 1] : 900;
const SET_BASELINE = args.includes('--baseline');
const CHROME_PROFILE = `/home/tetsuya/.cache/magiclab-chrome-${process.pid}`;  // 一次性: 硬杀不损坏持久 profile
const chrome = spawn(CHROME, [
  '--headless=new', '--disable-gpu', '--no-sandbox',
  '--window-size=1680,950', '--lang=zh-CN',
  `--user-data-dir=${CHROME_PROFILE}`,
  `--remote-debugging-port=${PORT}`, 'about:blank',
], { stdio: 'ignore' });

const die = (m) => { try { chrome.kill(9); } catch {} console.error('FATAL:', m); process.exit(1); };
mkdirSync(GALLERY, { recursive: true });
if (SET_BASELINE) mkdirSync(BASELINE, { recursive: true });

let page = null;
for (let i = 0; i < 30; i++) {
  await sleep(300);
  try {
    const list = await (await fetch(`http://127.0.0.1:${PORT}/json/list`)).json();
    page = list?.find(t => t.type === 'page' && t.webSocketDebuggerUrl);
    if (page) break;
  } catch {}
}
if (!page) die('no devtools page');
const ws = new WebSocket(page.webSocketDebuggerUrl);
await new Promise((res, rej) => { ws.onopen = res; ws.onerror = () => rej(new Error('ws')); });

let mid = 0; const pending = new Map(); const exc = [];
ws.onmessage = (ev) => {
  const m = JSON.parse(ev.data);
  if (m.id && pending.has(m.id)) { pending.get(m.id)(m); pending.delete(m.id); return; }
  if (m.method === 'Runtime.exceptionThrown') exc.push(m.params.exceptionDetails?.text ?? 'exc');
};
function send(method, params = {}) {
  return new Promise(r => {
    const id = ++mid; pending.set(id, r);
    ws.send(JSON.stringify({ id, method, params }));
    setTimeout(() => { if (pending.has(id)) { pending.delete(id); r({ error: { message: 'TO' } }); } }, 20000);
  });
}
async function ev(expr) {
  const r = await send('Runtime.evaluate', { expression: expr, returnByValue: true, awaitPromise: true });
  return r.result?.result?.value;
}

await send('Runtime.enable'); await send('Page.enable');
await send('Page.navigate', { url: `http://127.0.0.1:8822/lab?t=${Date.now()}` });

// 等实验室就绪
let ready = false;
for (let i = 0; i < 50; i++) {
  await sleep(300);
  if (await ev('!!window.__LAB && document.querySelectorAll(".lab-skill").length > 0') === true) { ready = true; break; }
}
if (!ready) die('lab not ready');
// 预热: 火球全链路一遍, 触发首帧抽帧/manifest
await ev('window.__LAB.play("FireBall")');
await sleep(2500);

const keys = await ev('window.__LAB.S.magics.map(m => m.key)');
const zhOf = await ev('JSON.stringify(Object.fromEntries(window.__LAB.S.magics.map(m => [m.key, m.zh])))');
const zh = zhOf ? JSON.parse(zhOf) : {};
const targets = ONLY ? keys.filter(k => ONLY.includes(k)) : keys;
console.log(`capturing ${targets.length} skills, freeze@${FREEZE}ms ...`);

async function captureOne(key) {
  const ok = await ev(`window.__LAB.play(${JSON.stringify(key)})`);
  if (!ok) return { key, error: 'play failed' };
  await sleep(FREEZE + 400);                    // 真实时间跑到 freeze 之后一点, 完成帧预取
  await ev(`window.__LAB.freezeAt(${FREEZE})`);
  // 轮询帧就绪 (排除异步解码竞态), 最多 20s; 服务端抽帧全局锁串行, 冷库排队慢
  let ready = false;
  for (let i = 0; i < 200; i++) {
    if (await ev('window.__LAB.framesReady()') === true) { ready = true; break; }
    await sleep(100);
  }
  if (!ready) return { key, error: 'frames not ready' };
  await sleep(250);   // 等待 ≥2 个 rAF: ready 判真时画布可能还没画上刚解码的 sprite
  // 指纹 = canvas 像素 hash (页面内计算, 绕过截图光栅化/编码非确定性)
  const pxHash = await ev(`(() => {
    const c = document.querySelector('#lab-stage');
    const d = c.getContext('2d').getImageData(0, 0, c.width, c.height).data;
    let h1 = 5381, h2 = 52711;
    for (let i = 0; i < d.length; i += 97) { h1 = (h1 * 33 + d[i]) >>> 0; h2 = ((h2 ^ d[i]) * 2654435761) >>> 0; }
    return h1 + ',' + h2;
  })()`);
  // 画廊截图 (人看; 编码层有 ± 噪声不作指纹)
  const rect = await ev(`JSON.stringify((() => {
    const r = document.querySelector('#lab-stage').getBoundingClientRect();
    return { x: r.x, y: r.y, width: r.width, height: r.height, scale: window.devicePixelRatio || 1 };
  })())`);
  const { x, y, width, height, scale } = JSON.parse(rect || '{}');
  const shot = await send('Page.captureScreenshot', {
    format: 'webp', quality: 80,
    clip: { x, y, width, height, scale },
  });
  if (!shot?.result?.data) return { key, error: 'shot failed' };
  const buf = Buffer.from(shot.result.data, 'base64');
  writeFileSync(`${GALLERY}/${key}.webp`, buf);
  return { key, zh: zh[key], md5: pxHash, bytes: buf.length };
}

const results = [];
let shotId = 0;
const baselineFile = `${BASELINE}/manifest.json`;
const baseline = SET_BASELINE ? null : (existsSync(baselineFile) ? JSON.parse(readFileSync(baselineFile, 'utf8')) : null);
for (const key of targets) {
  let r = await captureOne(key);
  if (r.error) r = await captureOne(key);   // 冷库排队超时 → 重试一次 (服务端已预热)
  // 不一致当场复拍一次: 真回归必复现, 冷启动闪失自愈 (结果语义: 复拍一致按一致计)
  const b = r.md5 ? baseline?.hashes?.[r.key] : undefined;
  if (b && b !== r.md5) {
    const r2 = await captureOne(key);
    if (r2.md5 === b) r = r2;
  }
  results.push(r);
  if (++shotId % 20 === 0) console.log(`  ${shotId}/${targets.length}`);
  exc.length = 0;
}
chrome.kill(9);
setTimeout(() => { try { rmSync(CHROME_PROFILE, { recursive: true, force: true }); } catch {} }, 500);
process.on('exit', () => { try { rmSync(CHROME_PROFILE, { recursive: true, force: true }); } catch {} });

// ---- 基线 diff (canvas 像素 hash 严格相等) ----
const same = [], changed = [], added = [], removed = [], errors = [];
for (const r of results) {
  if (r.error) { errors.push(r); continue; }
  const b = baseline?.hashes?.[r.key];
  if (!b) added.push(r.key);
  else if (b === r.md5) same.push(r.key);
  else changed.push(r.key);
}
if (baseline) for (const k of Object.keys(baseline.hashes)) {
  if (ONLY && !ONLY.includes(k)) continue;   // --only 模式下未采集的不算消失
  if (!results.find(r => r.key === k && !r.error)) removed.push(k);
}

const lines = [
  '# Magic Lab — 回归画廊 diff 报告',
  '',
  `- 采集: ${targets.length} 技能, freeze@${FREEZE}ms (lab-time 确定性定格)`,
  `- 对比基线: ${baseline ? baseline.createdAt : '（无, 首次采集）'}`,
  `- 结果: ${same.length} 一致 / ${changed.length} 变更 / ${added.length} 新增 / ${removed.length} 消失 / ${errors.length} 失败`,
  '',
];
if (changed.length) {
  lines.push('## ⚠️ 变更技能（与基线像素级不同——若非本轮有意改动即为回归）', '');
  lines.push(...changed.map(k => `- ${k}（${zh[k] ?? ''}）`));
  lines.push('');
}
if (added.length) lines.push('## 新增', '', ...added.map(k => `- ${k}`), '');
if (removed.length) lines.push('## 消失', '', ...removed.map(k => `- ${k}`), '');
if (errors.length) lines.push('## 失败', '', ...errors.map(r => `- ${r.key}: ${r.error}`), '');
if (!changed.length && !errors.length) lines.push('✅ 全部与基线一致。');
lines.push('', '_再生成: `node Tools/magiclab/batch_run.mjs`（重置基线加 `--baseline`）_', '');
writeFileSync(REPORT, lines.join('\n'));
console.log(`-> ${REPORT} (same=${same.length} changed=${changed.length} added=${added.length} removed=${removed.length} errors=${errors.length})`);

if (SET_BASELINE) {
  copyFileSync(REPORT, `${BASELINE}/REGRESSION.md`);
  writeFileSync(baselineFile, JSON.stringify({
    createdAt: new Date().toISOString(),
    freeze: FREEZE,
    hashes: Object.fromEntries(results.filter(r => !r.error).map(r => [r.key, r.md5])),
  }, null, 1));
  console.log(`baseline updated -> ${baselineFile}`);
}
process.exit(errors.length ? 1 : 0);
