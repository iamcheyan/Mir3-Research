// check-keybinds-cdp.mjs — E路 dispatch 级逐键回归 (真服真客户端):
//   注册独立账号 → 登录 → 建角 → 进比奇城 → 对 keybinds.js 的全部 70 条默认绑定
//   逐个 Input.dispatchKeyEvent, 记录: 可见窗口数/标题变化 (toggle 语义) +
//   全程页面异常数。输出矩阵 JSON 到 stdout。
// 运行: node Tools/webport/scripts/check-keybinds-cdp.mjs
import { spawn } from 'node:child_process';
import { KeyBinds, KeyBindAction } from '../static/js/keybinds.js';

const CHROME = '/home/tetsuya/.cache/ms-playwright/chromium-1208/chrome-linux64/chrome';
const PORT = 9360;
const EMAIL = `pk${Date.now().toString(36)}@test.com`;
const PASS = 'test123';
const sleep = (ms) => new Promise(r => setTimeout(r, ms));

const chrome = spawn(CHROME, ['--headless=new', '--disable-gpu', '--no-sandbox', '--window-size=1024,768', '--lang=zh-CN', `--remote-debugging-port=${PORT}`, 'about:blank'], { stdio: 'ignore' });
const die = (msg) => { console.log('FATAL:', msg); try { chrome.kill(9); } catch {} process.exit(1); };

let list = null;
for (let i = 0; i < 30; i++) { await sleep(300); try { list = await (await fetch(`http://127.0.0.1:${PORT}/json/list`)).json(); if (list.length) break; } catch {} }
const page = list?.find(t => t.type === 'page' && t.webSocketDebuggerUrl);
if (!page) die('no devtools page');
const ws = new WebSocket(page.webSocketDebuggerUrl);
await new Promise((res, rej) => { ws.onopen = res; ws.onerror = () => rej(new Error('ws')); });

let mid = 0; const pending = new Map(); const exc = [];
ws.onmessage = (ev) => {
  const m = JSON.parse(ev.data);
  if (m.id && pending.has(m.id)) { pending.get(m.id)(m); pending.delete(m.id); return; }
  if (m.method === 'Runtime.exceptionThrown') {
    exc.push((m.params.exceptionDetails?.exception?.description ?? m.params.exceptionDetails?.text ?? '').slice(0, 200));
  }
};
function send(method, params = {}) { return new Promise(r => { const id = ++mid; pending.set(id, r); ws.send(JSON.stringify({ id, method, params })); setTimeout(() => { if (pending.has(id)) { pending.delete(id); r({ error: { message: 'TO' } }); } }, 15000); }); }
async function ev(expr) {
  const r = await send('Runtime.evaluate', { expression: expr, returnByValue: true });
  if (r.error) return 'ERR:' + r.error.message;
  if (r.exceptionDetails) return 'EXC:' + (r.exceptionDetails.exception?.description ?? '').slice(0, 150);
  return r.result?.result?.value;
}

await send('Runtime.enable'); await send('Page.enable');
await send('Page.navigate', { url: 'http://127.0.0.1:8823/' });

// --- stage 1: versionOK (btnLogin enabled; ServerCore 冷启动 ~11s) ---
let ok = false;
for (let i = 0; i < 90; i++) {
  await sleep(1000);
  const v = await ev('window.__WEBPORT && __WEBPORT.current && __WEBPORT.current.btnLogin && __WEBPORT.current.btnLogin.enabled === true');
  if (v === true) { ok = true; break; }
}
if (!ok) die('versionOK timeout');
console.log('S1 versionOK');

// --- stage 2: register + login (独立账号, 不碰共享 test@test.com) ---
await ev(`window.__WEBPORT.conn.sendNewAccount(${JSON.stringify(EMAIL)}, ${JSON.stringify(PASS)})`);
for (let i = 0; i < 40; i++) {
  await sleep(500);
  const st = await ev('window.__WEBPORT.current.statusLabel ? window.__WEBPORT.current.statusLabel.text : ""');
  if (typeof st === 'string' && st.includes('成功')) break;
  if (i === 20) await ev(`window.__WEBPORT.conn.sendNewAccount(${JSON.stringify(EMAIL)}, ${JSON.stringify(PASS)})`);
}
console.log('S2 registered', EMAIL);
await ev(`window.__WEBPORT.conn.sendLogin(${JSON.stringify(EMAIL)}, ${JSON.stringify(PASS)})`);
ok = false;
for (let i = 0; i < 60; i++) { await sleep(1000); if ((await ev('window.__WEBPORT.current?.constructor?.name')) === 'SelectScene') { ok = true; break; } }
if (!ok) die('login timeout');
console.log('S3 logged in → SelectScene');

// --- stage 4: 建角 (btnCreate 先开面板, 等 createPanel.visible 再确认) ---
await sleep(800);
ok = false;
for (let i = 0; i < 12; i++) {
  await ev(`(function(){ const c = window.__WEBPORT.current; if (c.createPanel && c.createPanel.visible === false && c.btnCreate) c.btnCreate.onClick(); if (c.createPanel && c.createPanel.visible === true) { c.nameInput.text = 'PK${Date.now() % 1000}'; c.btnConfirm.onClick(); return 'sent'; } return 'wait'; })()`);
  const r = await ev('window.__WEBPORT.current.characters.length');
  if (typeof r === 'number' && r > 0) { ok = true; break; }
  await sleep(1000);
}
if (!ok) die('create char timeout');
console.log('S4 character created');

// --- stage 5: 进游戏 (world.player + mapMeta 就绪) ---
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
console.log('S5 IN-GAME');
// --- 窗口快照助手 (DXControl.visible = style.visibility, 非 display; HUD 常驻控件
//     (buffdialog/questtracker/minimap) 在 Godot 是 _uiLayer 普通子节点, 不入册
//     WindowManager, 排除之; Escape/CloseTop 语义只覆盖注册窗口) ---
const SNAP = `(() => { const s = window.__WEBPORT.current;
  const wins = [...s.hudLayer.el.querySelectorAll(':scope > .dxwindow')]
    .filter(w => w.style.visibility !== 'hidden' && w.style.display !== 'none')
    .filter(w => !/(buffdialog|questtracker|minimap)/.test(w.className))
    .map(w => (w.dataset.type || w.className || '').toString().slice(0, 30));
  return JSON.stringify(wins); })()`;
const snap = async () => JSON.parse(await ev(SNAP) || '[]');

// 关全部注册窗口: Escape→CloseTop 直到窗口集合不再变化 (避免 fall-through 开 ExitDialog)
const closeAll = async () => {
  let prev = null;
  for (let i = 0; i < 8; i++) {
    const cur = await snap();
    if (cur.length === 0) break;
    if (JSON.stringify(cur) === prev) break;
    prev = JSON.stringify(cur);
    await send('Input.dispatchKeyEvent', { type: 'keyDown', key: 'Escape', code: 'Escape', windowsVirtualKeyCode: 27 });
    await send('Input.dispatchKeyEvent', { type: 'keyUp', key: 'Escape', code: 'Escape', windowsVirtualKeyCode: 27 });
    await sleep(150);
  }
};

// --- CDP 按键: 修饰键掩码 Alt=1 Ctrl=2 Shift=8 ---
const VK = { escape: 27, tab: 9, scrolllock: 145, ',': 188, '.': 190 };
const vkOf = (k) => VK[k] ?? (k.length === 1 && /[a-z]/.test(k) ? k.toUpperCase().charCodeAt(0)
  : k.length === 1 && /[0-9]/.test(k) ? k.charCodeAt(0)
  : /^f\d{1,2}$/.test(k) ? 111 + Number(k.slice(1)) : 0);
const codeOf = (k) => k.length === 1 && /[a-z]/.test(k) ? 'Key' + k.toUpperCase()
  : k.length === 1 && /[0-9]/.test(k) ? 'Digit' + k
  : /^f\d{1,2}$/.test(k) ? k.toUpperCase()
  : { ',': 'Comma', '.': 'Period', escape: 'Escape', tab: 'Tab', scrolllock: 'ScrollLock' }[k] ?? k;

async function press(b) {
  const mods = (b.control1 ? 2 : 0) | (b.alt1 ? 1 : 0) | (b.shift1 ? 8 : 0);
  const code = codeOf(b.key1), vk = vkOf(b.key1);
  const base = { key: b.key1.length === 1 ? b.key1 : b.key1, code, windowsVirtualKeyCode: vk, modifiers: mods };
  await send('Input.dispatchKeyEvent', { type: 'keyDown', ...base });
  await send('Input.dispatchKeyEvent', { type: 'keyUp', ...base });
}

const nameOf = Object.fromEntries(Object.entries(KeyBindAction).map(([k, v]) => [v, k]));
const results = [];
const excBefore = 0;

for (const b of KeyBinds) {
  await closeAll();
  const before = await snap();
  await press(b);
  await sleep(500);
  const after = await snap();
  // toggle 语义: 再按一次应回到 before (仅对开了窗的键)
  let toggled = false;
  if (after.length > before.length) {
    await press(b);
    await sleep(400);
    const again = await snap();
    toggled = again.length <= before.length;
  }
  results.push({
    action: nameOf[b.action], key: b.key1,
    ctrl: b.control1, alt: b.alt1, shift: b.shift1,
    windowsAfter: after, opened: after.length > before.length, toggleOk: toggled || after.length === before.length,
  });
  process.stdout.write(`  ${nameOf[b.action].padEnd(22)} ${b.key1.padEnd(11)} -> ${after.length ? after.join('|') : '(无窗口变化)'}${after.length > before.length ? (toggled ? ' [toggle✓]' : ' [toggle✗]') : ''}\n`);
}

// --- Escape 双段语义 (R0 仲裁 #1): 无窗时 Esc 应开 ExitDialog ---
await closeAll();
await send('Input.dispatchKeyEvent', { type: 'keyDown', key: 'Escape', code: 'Escape', windowsVirtualKeyCode: 27 });
await send('Input.dispatchKeyEvent', { type: 'keyUp', key: 'Escape', code: 'Escape', windowsVirtualKeyCode: 27 });
await sleep(500);
const escNoWin = await snap();

// --- HUD 常驻控件开关 (GameScene.cs:1891-1900): V=小地图可见性取反,
//     L=QuestTracker 可见性取反 (均非 WindowManager 窗口) ---
const hudProbe = {};
for (const [key, prop] of [['KeyV', 'miniMap'], ['KeyL', 'questTracker']]) {
  const a = await ev(`window.__WEBPORT.current.${prop}.visible`);
  await send('Input.dispatchKeyEvent', { type: 'keyDown', key: key === 'KeyV' ? 'v' : 'l', code: key, windowsVirtualKeyCode: key === 'KeyV' ? 86 : 76 });
  await send('Input.dispatchKeyEvent', { type: 'keyUp', key: key === 'KeyV' ? 'v' : 'l', code: key, windowsVirtualKeyCode: key === 'KeyV' ? 86 : 76 });
  await sleep(300);
  const b = await ev(`window.__WEBPORT.current.${prop}.visible`);
  hudProbe[prop] = { before: a, after: b, toggled: a !== b };
}

const summary = {
  account: EMAIL, total: results.length,
  openedWindows: results.filter(r => r.opened).length,
  toggleVerified: results.filter(r => r.opened && r.toggleOk).length,
  pageExceptions: exc.length,
  hudToggles: hudProbe,
  escNoWindowOpens: escNoWin,
  exceptions: exc.slice(0, 5),
};
console.log('\nSUMMARY', JSON.stringify(summary, null, 1));
console.log('MATRIX', JSON.stringify(results));
import { writeFileSync } from 'node:fs';
writeFileSync('/tmp/pk-cdp-matrix.json', JSON.stringify({ summary, results }, null, 1));
ws.close(); chrome.kill(9); process.exit(0);
