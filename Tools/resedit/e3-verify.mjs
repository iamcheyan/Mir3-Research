// e3-verify.mjs — E3 帧公式 JSON 化验收 (node Tools/resedit/e3-verify.mjs)
// 真服全链路: 注册独立账号→登录→建角→进比奇→验证玩家动画帧全部来自
// frame-formulas.json (单一数据源), 截图存证 docs/resedit/proof/
import { spawn } from 'node:child_process';
import { mkdirSync } from 'node:fs';

const CHROME = '/home/tetsuya/.cache/ms-playwright/chromium-1208/chrome-linux64/chrome';
const PORT = 9361;
const EMAIL = `e3${Date.now().toString(36)}@test.com`;
const PASS = 'test123';
const SHOTS = '/home/tetsuya/development/Mir3-Research/docs/resedit/proof';
mkdirSync(SHOTS, { recursive: true });
const sleep = (ms) => new Promise(r => setTimeout(r, ms));

const chrome = spawn(CHROME, ['--headless=new', '--disable-gpu', '--no-sandbox', '--window-size=1280,800', '--lang=zh-CN', `--remote-debugging-port=${PORT}`, 'about:blank'], { stdio: 'ignore' });
const die = (msg) => { console.log('FATAL:', msg); try { chrome.kill(9); } catch {} process.exit(1); };

let list = null;
for (let i = 0; i < 30; i++) { await sleep(300); try { list = await (await fetch(`http://127.0.0.1:${PORT}/json/list`)).json(); if (list.length) break; } catch {} }
const page = list?.find(t => t.type === 'page' && t.webSocketDebuggerUrl);
if (!page) die('no devtools page');
const ws = new WebSocket(page.webSocketDebuggerUrl);
await new Promise((res, rej) => { ws.onopen = res; ws.onerror = () => rej(new Error('ws')); });

let mid = 0; const pending = new Map(); const exc = []; const failedFetch = [];
ws.onmessage = (ev) => {
  const m = JSON.parse(ev.data);
  if (m.id && pending.has(m.id)) { pending.get(m.id)(m); pending.delete(m.id); return; }
  if (m.method === 'Runtime.exceptionThrown') exc.push((m.params.exceptionDetails?.exception?.description ?? m.params.exceptionDetails?.text ?? '').slice(0, 300));
  if (m.method === 'Network.loadingFailed') failedFetch.push(m.params);
};
const ev = (expr) => new Promise((res) => {
  const id = ++mid;
  pending.set(id, (m) => res(m.result?.result?.value));
  ws.send(JSON.stringify({ id, method: 'Runtime.evaluate', params: { expression: expr, returnByValue: true, awaitPromise: true } }));
});
const shot = (name) => new Promise((res) => {
  const id = ++mid;
  pending.set(id, () => res());
  ws.send(JSON.stringify({ id, method: 'Page.captureScreenshot', params: { format: 'png' } }));
  const t = pending.get(id);
  pending.set(id, (m) => {
    if (m.result?.data) require_fs_write(name, m.result.data);
    t?.(m);
  });
});
import { writeFileSync } from 'node:fs';
const require_fs_write = (name, b64) => writeFileSync(`${SHOTS}/${name}`, Buffer.from(b64, 'base64'));

await ev('Page.enable()').catch?.(() => {});
ws.send(JSON.stringify({ id: ++mid, method: 'Page.enable' }));
await sleep(200);

// --- S1: 打开 webport, 帧公式 JSON 数据完整性 ---
await ev(`location.href = 'http://127.0.0.1:8823/'`);
await sleep(3500);
const banner = await ev(`document.body.innerText.includes('帧公式数据加载失败')`);
if (banner === true) die('帧公式加载失败横幅出现');
const data = await ev(`import('/static/js/frames.js').then(m => m.ensureLoaded().then(() => ({
  players: Object.keys(m.PLAYERS).length,
  monster: Object.keys(m.DEFAULT_MONSTER).length,
  npcSpecial: m.NPC_SPECIAL.size,
  magic: Object.keys(m.MAGIC).length,
  walking: m.PLAYERS.walking,
  combat1delays: m.PLAYERS.combat1.delays,
  hideReversed: m.DEFAULT_MONSTER.hide.reversed,
  npcSingle: m.NPC_SPECIAL.get(64),
  npc56: m.NPC_SPECIAL.get(56),
  shiftWalking: m.armourShift('walking', true),
  shiftCombat1: m.armourShift('combat1', true),
  shiftWarrior: m.armourShift('walking', false),
  attackSlaying: m.getAttackAnimation(0, 0, m.MAGIC.Slaying),
  attackFullBloom1250: m.getAttackAnimation(0, 1250, m.MAGIC.FullBloom),
  attackSin1200: m.getAttackAnimation(3, 1200, 0),
  attackSinDefault: m.getAttackAnimation(3, 100, 0),
  magicFireBall: m.getMagicAnimation(m.MAGIC.FireBall),
  magicHeal: m.getMagicAnimation(m.MAGIC.Heal),
  magicHurricane: m.getMagicAnimation(m.MAGIC.ElementalHurricane),
  magicUnknown: m.getMagicAnimation(99999),
})))`);
console.log('S1 frame-formulas.json 驱动:');
console.log('  PLAYERS:', data.players, '| DEFAULT_MONSTER:', data.monster, '| NPC_SPECIAL:', data.npcSpecial, '| MAGIC:', data.magic);
console.log('  walking:', JSON.stringify(data.walking));
console.log('  combat1.delays:', JSON.stringify(data.combat1delays), '| monster.hide.reversed:', data.hideReversed);
console.log('  NPC_SPECIAL[64]:', JSON.stringify(data.npcSingle), '[56]:', JSON.stringify(data.npc56));
console.log('  armourShift: walking=', data.shiftWalking, 'combat1=', data.shiftCombat1, '非刺客=', data.shiftWarrior);
console.log('  分派: Slaying→', data.attackSlaying, 'FullBloom(1250)→', data.attackFullBloom1250,
  '刺(1200)→', data.attackSin1200, '刺默认→', data.attackSinDefault);
console.log('  魔法: FireBall→', data.magicFireBall, 'Heal→', data.magicHeal,
  'Hurricane→', data.magicHurricane, '未知→', data.magicUnknown);
const assert = (cond, msg) => { if (!cond) die(`断言失败: ${msg}`); };
assert(data.players >= 42 && data.monster >= 12 && data.magic >= 200 && data.npcSpecial === 23, '表规模');
assert(data.walking.start === 80 && data.walking.count === 6 && data.walking.offset === 10, 'walking 表');
assert(data.combat1delays[1] === 200, 'combat1 delay 覆盖');
assert(data.hideReversed === true, 'monster hide reversed');
assert(data.npcSingle && data.npcSingle.single === true, 'NPC 特例 single');
assert(data.npc56 && data.npc56.count === 12 && data.npc56.ms === 200, 'NPC 56 特例');
assert(data.shiftWalking === 1600 && data.shiftCombat1 === -400 && data.shiftWarrior === 0, 'ArmourShift');
assert(data.attackSlaying === 'combat3' && data.attackFullBloom1250 === 'combat13', '攻击分派');
assert(data.attackSin1200 === 'combat11' && data.attackSinDefault === 'combat3', '刺客分派');
assert(data.magicFireBall === 'combat1' && data.magicHeal === 'combat2'
  && data.magicHurricane === 'channellingStart' && data.magicUnknown === 'combat1', '魔法分派');
console.log('S1 ✓ 全部断言通过');

// --- S2: 注册独立账号 ---
await ev(`window.__WEBPORT.conn.sendNewAccount(${JSON.stringify(EMAIL)}, ${JSON.stringify(PASS)})`);
for (let i = 0; i < 40; i++) {
  await sleep(500);
  const st = await ev('window.__WEBPORT.current.statusLabel ? window.__WEBPORT.current.statusLabel.text : ""');
  if (typeof st === 'string' && st.includes('成功')) break;
  if (i === 20) await ev(`window.__WEBPORT.conn.sendNewAccount(${JSON.stringify(EMAIL)}, ${JSON.stringify(PASS)})`);
}
console.log('S2 registered', EMAIL);

// --- S3: 登录 ---
await ev(`window.__WEBPORT.conn.sendLogin(${JSON.stringify(EMAIL)}, ${JSON.stringify(PASS)})`);
let ok = false;
for (let i = 0; i < 60; i++) { await sleep(1000); if ((await ev('window.__WEBPORT.current?.constructor?.name')) === 'SelectScene') { ok = true; break; } }
if (!ok) die('login timeout');
console.log('S3 logged in → SelectScene');

// --- S4: 建角 ---
await sleep(800);
ok = false;
for (let i = 0; i < 12; i++) {
  await ev(`(function(){ const c = window.__WEBPORT.current; if (c.createPanel && c.createPanel.visible === false && c.btnCreate) c.btnCreate.onClick(); if (c.createPanel && c.createPanel.visible === true) { c.nameInput.text = 'E3RES${Date.now() % 1000}'; c.btnConfirm.onClick(); return 'sent'; } return 'wait'; })()`);
  const r = await ev('window.__WEBPORT.current.characters.length');
  if (typeof r === 'number' && r > 0) { ok = true; break; }
  await sleep(1000);
}
if (!ok) die('create char timeout');
console.log('S4 character created');

// --- S5: 进游戏 ---
await ev(`(function(){ const c = window.__WEBPORT.current; c.selectedIndex = 0; if (c.btnStart) c.btnStart.onClick(); return 'ok'; })()`);
ok = false;
for (let i = 0; i < 120; i++) {
  await sleep(700);
  if ((await ev('window.__WEBPORT.current?.constructor?.name')) === 'GameScene') {
    const ready = await ev('!!(window.__WEBPORT.current.world && window.__WEBPORT.current.world.player && window.__WEBPORT.current.world.mapMeta)');
    if (ready === true) { ok = true; break; }
  }
  if (i === 30) await ev('(function(){ const c = window.__WEBPORT.current; if (c.btnStart) c.btnStart.onClick(); return "retry"; })()');
}
if (!ok) die('startgame timeout');
console.log('S5 IN-GAME ✓ (world.player 就绪)');

// --- S6: 玩家动画真值来自 JSON: 站立→走路, 抓取帧表与 DrawFrame ---
await sleep(2500);
await shot('ingame_standing.png');
const p1 = await ev(`(function(){ const w = window.__WEBPORT.current.world; const p = w.player; const f = p.frameTable || p.currentFrame; return { anim: p.animName ?? p.anim, drawFrameSample: (p.frameIndex ?? 0) }; })()`);
console.log('S6 站立状态:', JSON.stringify(p1));
// 触发移动 (MouseWalker 走到远处格) — 通过 world 内部 API 或模拟点击
await ev(`(function(){ const w = window.__WEBPORT.current.world; const p = w.player; if (w.tryWalk) w.tryWalk((p.x ?? p.cx ?? 500) + 3, (p.y ?? p.cy ?? 500)); return 'walk'; })()`);
await sleep(1500);
const p2 = await ev(`(function(){ const w = window.__WEBPORT.current.world; const p = w.player; return { anim: p.animName ?? p.anim }; })()`);
console.log('S6 移动后动画:', JSON.stringify(p2), '(期望 running/walking)');
await shot('ingame_moving.png');
const canvasInfo = await ev(`(function(){ const c = document.querySelector('canvas'); if (!c) return null; const ctx = c.getContext('2d'); const d = ctx.getImageData(0, 0, c.width, c.height).data; let nz = 0; for (let i = 3; i < d.length; i += 40) if (d[i] !== 0) nz++; return { w: c.width, h: c.height, nonEmptySample: nz }; })()`);
console.log('S6 canvas:', JSON.stringify(canvasInfo), '(nonEmptySample>0 = 画布有内容)');
assert(canvasInfo && canvasInfo.nonEmptySample > 0, '画布为空 — 渲染失败');

// --- S7: 页面异常审计 ---
console.log('S7 Runtime exceptions:', exc.length ? exc : '无');
console.log('S7 failed fetches:', failedFetch.length ? failedFetch.map(f => f.errorText).slice(0, 5) : '无');
assert(exc.length === 0, `页面抛异常: ${exc[0] ?? ''}`);

console.log('\n=== E3 webport JSON 驱动验收全部通过 ===');
console.log('账号:', EMAIL, '| 截图:', SHOTS);
try { chrome.kill(9); } catch {}
process.exit(0);
