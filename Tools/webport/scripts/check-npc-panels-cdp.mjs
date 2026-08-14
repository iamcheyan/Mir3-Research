// check-npc-panels-cdp.mjs — NPC 高级面板链 (R15-R20) CDP 回归
// 覆盖: 14 DialogType 面板显隐/内容 + 提交路径包 id (253/254/257/261/274)
//        + R19 回包反馈 (取回删行/伙伴同步/真服 e2e 聊天) + R20 提交锁三态。
// 依赖: webport :8823 + wsgateway :7001 + ServerCore :7000 (hub daemon servercore-7k)。
// 用法: node Tools/webport/scripts/check-npc-panels-cdp.mjs   (退出码 0=全绿)
//
// 经验教训 (勿重踩):
// - Runtime.evaluate 必须 awaitPromise (returnPromise 无效 → promise 序列化成 {})
// - DOM 句柄/类实例不能跨 CDP 边界 → 页面侧装 __npcRun (eval 驱动), 只传 JSON
// - 进 GameScene 后 Data.loadAll 仍在顺序拉取, itemsById 空是竞态不是 bug — 等 GameDB.npcPage 可查
// - registry 模块安装失败被 console.warn 吞 — addScriptToEvaluateOnNewDocument 捕获 __winWarns
// - 独立注册账号 (共享账号 [Account in Use]); chrome 必须 kill(9)
import { spawn } from 'node:child_process';
const CHROME = '/home/tetsuya/.cache/ms-playwright/chromium-1208/chrome-linux64/chrome';
const PORT = 9393;
const sleep = (ms) => new Promise(r => setTimeout(r, ms));
const chrome = spawn(CHROME, ['--headless=new', '--disable-gpu', '--no-sandbox', '--window-size=1024,768', '--lang=zh-CN', `--remote-debugging-port=${PORT}`, 'about:blank'], { stdio: 'ignore' });
const die = (m) => { console.log('FATAL:', m); try { chrome.kill(9); } catch {} process.exit(1); };
let list = null;
for (let i = 0; i < 30; i++) { await sleep(300); try { list = await (await fetch(`http://127.0.0.1:${PORT}/json/list`)).json(); if (list.length) break; } catch {} }
const page = list?.find(t => t.type === 'page' && t.webSocketDebuggerUrl);
if (!page) die('no page');
const ws = new WebSocket(page.webSocketDebuggerUrl);
await new Promise((res, rej) => { ws.onopen = res; ws.onerror = () => rej(new Error('ws')); });
let mid = 0; const pending = new Map(); const logs = [];
ws.onmessage = (ev) => { const m = JSON.parse(ev.data);
  if (m.id && pending.has(m.id)) { pending.get(m.id)(m); pending.delete(m.id); }
  else if (m.method === 'Runtime.exceptionThrown') logs.push('[EXC] ' + (m.params.exceptionDetails.exception?.description ?? '') + ' @ ' + (m.params.exceptionDetails.url ?? '?'));
  else if (m.method === 'Runtime.consoleAPICalled' && (m.params.type === 'warning' || m.params.type === 'error')) logs.push('[' + m.params.type + '] ' + (m.params.args ?? []).map(a => a.value ?? a.description ?? '').join(' ').slice(0, 300)); };
function send(method, params = {}) { const id = ++mid; return new Promise(r => { pending.set(id, r); ws.send(JSON.stringify({ id, method, params })); setTimeout(() => { if (pending.has(id)) { pending.delete(id); r({ error: { message: 'TIMEOUT' } }); } }, 15000); }); }
async function ev(expr) { const r = await send('Runtime.evaluate', { expression: expr, awaitPromise: true, returnPromise: true === false, returnByValue: true });
  if (r.error) return 'ERR:' + r.error.message;
  if (r.exceptionDetails) return 'EXC:' + (r.exceptionDetails.exception?.description ?? '').slice(0, 300);
  return r.result?.result?.value; }
await send('Runtime.enable'); await send('Page.enable');
await send('Page.addScriptToEvaluateOnNewDocument', { source: 'window.prompt = (msg, def) => window.__promptQueue?.shift() ?? def ?? ""; window.alert = () => {}; window.confirm = () => true; window.__winWarns = []; const ow = console.warn; console.warn = function () { try { window.__winWarns.push(Array.from(arguments).map(x => String(x?.message ?? x)).join(" ").slice(0, 300)); } catch (e) {} ow.apply(console, arguments); };' });
await send('Page.navigate', { url: 'http://127.0.0.1:8823/' });

// ---- 登录/建角/进世界 ----
for (let i = 0; i < 60; i++) { await sleep(500); const v = await ev('window.__WEBPORT?.current?.btnLogin?.enabled === true'); if (v === true) break; }
const EMAIL = 'pm' + Date.now().toString(36) + '@test.com';
await ev(`__WEBPORT.conn.sendNewAccount(${JSON.stringify(EMAIL)}, "test123")`);
await sleep(2500);
await ev(`__WEBPORT.conn.sendLogin(${JSON.stringify(EMAIL)}, "test123")`);
for (let i = 0; i < 60; i++) { await sleep(500); if (await ev('window.__WEBPORT.current?.constructor?.name ?? "none"') === 'SelectScene') break; }
for (let t = 0; t < 3; t++) {
  await ev('(function(){ const c = window.__WEBPORT.current; if (c?.btnCreate && c?.createPanel && !c.createPanel.visible) c.btnCreate.onClick?.(); if (c?.nameInput && c?.btnConfirm) { c.nameInput.text = "PNpc" + Math.random().toString(36).slice(2, 6); c.btnConfirm.enabled = true; c.btnConfirm.onClick?.(); return "sent"; } return "no-input"; })()');
  for (let i = 0; i < 24; i++) { await sleep(500); if (await ev('window.__WEBPORT.current?.constructor?.name ?? "none"') === 'GameScene') break; }
  if (await ev('window.__WEBPORT.current?.constructor?.name ?? "none"') === 'GameScene') break;
  await ev('(function(){ const c = window.__WEBPORT.current; if (c?.btnStart) { c.btnStart.enabled = true; c.btnStart.onClick?.(); return "started"; } return "no-btnStart"; })()');
  for (let i = 0; i < 24; i++) { await sleep(500); if (await ev('window.__WEBPORT.current?.constructor?.name ?? "none"') === 'GameScene') break; }
  if (await ev('window.__WEBPORT.current?.constructor?.name ?? "none"') === 'GameScene') break;
}
if (await ev('window.__WEBPORT.current?.constructor?.name ?? "none"') !== 'GameScene') die('not GameScene');
// 就绪门闩: Data.loadAll 完成 + GameDB 可查页 + npc 模块安装成功
{
  let ok = false;
  for (let i = 0; i < 180; i++) {
    ok = await ev('(async () => { const m = await import("/static/js/data.js"); const g = await import("/static/js/gamedb.js"); const s = __WEBPORT.current; const reg = await s._winInstall; return m.D().items?.length > 0 && !!(await g.GameDB.npcPage(168)) && !!reg.win("npc"); })()');
    if (ok === true) break;
    await sleep(500);
  }
  if (ok !== true) {
    const warns = await ev('JSON.stringify((window.__winWarns ?? []).slice(0, 3))');
    die('readiness TIMEOUT warns=' + warns);
  }
}
console.log('READY    : scene=GameScene data+db+npc');

// ---- 页面侧 helper: 开 NPC 页 → 签名找面板 → 注入物品 → eval 步骤 (返回值须 JSON 可序列化) ----
await ev(`window.__npcRun = async (pageIdx, sigJson, itemsJson, actionSrc, opts) => {
  const sig = JSON.parse(sigJson), items = JSON.parse(itemsJson);
  const s = __WEBPORT.current; const reg = await s._winInstall; const w = reg.win('npc');
  if (opts?.rawPage !== true) s.conn.dispatchEvent(new CustomEvent('npcResponse', { detail: { index: pageIdx, objectID: 1, values: [] } }));
  let pc = null;
  const deep = (c) => { if (!c) return; const t = c?.el?.textContent ?? ''; if (c.visible && sig.every(x => t.includes(x))) pc = c; for (const cc of c?.children ?? []) deep(cc); };
  for (let i = 0; i < 25 && !pc; i++) { await new Promise(r => setTimeout(r, 200)); deep(w); }
  if (!pc) return { err: 'no-panel sig=' + sig.join('|') + ' warns=' + JSON.stringify((window.__winWarns ?? []).slice(0, 2)) };
  const btns = [];
  const scan = (c) => { if (c?.onClick && c.el?.textContent) btns.push(c); for (const cc of c?.children ?? []) scan(cc); };
  scan(pc);
  const inv = reg.itemStore.grids.get(1);
  for (const [slot, infoIndex, count] of items) inv.set(slot, { infoIndex, slot, count, currentDura: 1, maxDura: 1 });
  const ctx = { pc, btns, inv, s, reg, w, conn: s.conn, store: reg.itemStore };
  try { return await eval('(async () => { const { pc, btns, inv, s, reg, w, conn, store } = ctx; ' + actionSrc + ' })()'); }
  catch (e) { return { err: 'ACTERR:' + e.message }; }
}; true`);

const npcRun = (pageIdx, sig, items, actionSrc, opts) =>
  ev(`__npcRun(${JSON.stringify(pageIdx)}, ${JSON.stringify(JSON.stringify(sig))}, ${JSON.stringify(JSON.stringify(items))}, ${JSON.stringify(actionSrc)}, ${JSON.stringify(opts ?? {})})`);
const trackIds = 'const sentIds = []; const orig = conn.send.bind(conn); conn.send = (b) => { if (b?.byteLength > 6) sentIds.push(new DataView(b.buffer, b.byteOffset).getInt16(4, true)); return b; };';   // 拦截不真发 (隔离真服时序); 恢复: conn.send = orig
const trackIdsFwd = 'const sentIds = []; const orig = conn.send.bind(conn); conn.send = (b) => { if (b?.byteLength > 6) sentIds.push(new DataView(b.buffer, b.byteOffset).getInt16(4, true)); return orig(b); };';   // 拦截且真发 (e2e)

const results = [];
const report = (name, pass, detail) => { results.push({ name, pass }); console.log(pass ? 'PASS' : 'FAIL', name.padEnd(10), ':', typeof detail === 'string' ? detail : JSON.stringify(detail)); };

// ============ 1. 单链接面板 ×4 显隐 (dtype 6/10/11/13) ============
{
  const d = {};
  for (const [name, idx, sig] of [['WeddingRing', 155, ['制作结婚戒指']], ['ItemFragment', 171, ['分解物品']], ['AccessoryRefineUpgrade', 197, ['强化饰品']], ['AccessoryReset', 266, ['重置饰品']]]) {
    const r = await npcRun(idx, sig, [], 'return { ok: !!pc.visible };');
    d[name] = !r?.err && r?.ok === true;
  }
  report('SINGLE', Object.values(d).length === 4 && Object.values(d).every(Boolean), d);
}

// ============ 2. ItemFragment 提交 → C.NPCFragment 253 ============
{
  const r = await npcRun(171, ['分解', '从背包导入', '提交'], [[0, 1, 1]], `
    btns.find(b => b.el.textContent.includes('从背包导入'))?.onClick?.();
    await new Promise(r => setTimeout(r, 300));
    const rows = [...pc.el.querySelectorAll('div')].filter(d => d.textContent.startsWith('·')).length;
    const sub = btns.find(b => b.el.textContent.trim() === '提交');
    const enabled = !!sub?.enabled;
    ${trackIds}
    sub?.onClick?.();
    await new Promise(r => setTimeout(r, 300));
    conn.send = orig;
    conn.dispatchEvent(new CustomEvent('npcMasterRefineResult', { detail: { success: false } }));   // 兜底解锁 (Fragment 无独立 S 回包)
    return { rows, enabled, sentIds, remaining: [...pc.el.querySelectorAll('div')].filter(d => d.textContent.startsWith('·')).length };`);
  const d = typeof r === 'object' ? r : {};
  report('SUBMIT253', d.rows >= 1 && d.enabled && d.sentIds?.includes(253) && d.remaining === 0, r);
}

// ============ 3. Refine 面板 (dtype 3) → C.NPCRefine 257 ============
{
  const r = await npcRun(85, ['开始精炼', '黑铁矿'], [[0, 541, 5]], `
    btns.find(b => b.el.textContent.includes('从背包导入'))?.onClick?.();
    await new Promise(r => setTimeout(r, 300));
    const boxTxt = pc.el.querySelector('div[style*="overflow-y"]')?.textContent ?? '';
    btns.find(b => b.el.textContent.includes('攻击 DC'))?.onClick?.();
    ${trackIds}
    btns.find(b => b.el.textContent.includes('开始精炼'))?.onClick?.();
    await new Promise(r => setTimeout(r, 300));
    conn.send = orig;
    return { oreBucket: boxTxt.includes('黑铁矿 (1)') && boxTxt.includes('黑铁矿石 x5'), typeSel: btns.some(b => b.el.textContent.includes('●')), sentIds };`);
  const d = typeof r === 'object' ? r : {};
  report('REFINE257', d.oreBucket && d.typeSel && d.sentIds?.includes(257), r);
}

// ============ 4. R18 五面板显隐 (dtype 5/7/8/12/14) ============
{
  const d = {};
  for (const [name, idx, sig] of [['CompanionManage', 149, ['放生', '寄存']], ['RefinementStone', 167, ['铁矿石', '金币投入']], ['MasterRefine', 168, ['评估', '碎片']], ['AccessoryRefineLevel', 196, ['目标饰品', '升级']], ['WeaponCraft', 268, ['模板武器', '打造']]]) {
    const r = await npcRun(idx, sig, [], 'return { ok: true };');
    d[name] = !r?.err;
  }
  report('R18x5', Object.values(d).length === 5 && Object.values(d).every(Boolean), d);
}

// ============ 5. MasterRefine 254 / RefinementStone 261 / WeaponCraft 274 ============
{
  const master = await npcRun(168, ['评估', '从背包导入'], [[0, 829, 10], [1, 830, 10], [2, 831, 1], [3, 828, 1]], `
    btns.find(b => b.el.textContent.includes('从背包导入'))?.onClick?.();
    await new Promise(r => setTimeout(r, 300));
    btns.find(b => b.el.textContent.trim() === '攻击')?.onClick?.();
    ${trackIds}
    btns.find(b => b.el.textContent.includes('精炼') && !b.el.textContent.includes('大师'))?.onClick?.();
    await new Promise(r => setTimeout(r, 300));
    conn.send = orig;
    return sentIds;`);
  const stone = await npcRun(167, ['铁矿石', '金币投入', '从背包导入'], [[0, 327, 1], [1, 540, 2], [2, 544, 4], [3, 538, 3]], `
    btns.find(b => b.el.textContent.includes('从背包导入'))?.onClick?.();
    await new Promise(r => setTimeout(r, 300));
    ${trackIds}
    btns.find(b => b.el.textContent.includes('制作'))?.onClick?.();
    await new Promise(r => setTimeout(r, 300));
    conn.send = orig;
    return sentIds;`);
  const craft = await npcRun(268, ['模板武器', '打造', '从背包导入'], [[0, 549, 1], [1, 493, 1]], `
    btns.find(b => b.el.textContent.includes('从背包导入'))?.onClick?.();
    await new Promise(r => setTimeout(r, 300));
    const clsBtn = btns.find(b => b.el.textContent.includes('职业'));
    clsBtn?.onClick?.();
    const cls = clsBtn?.el?.textContent ?? '';
    ${trackIds}
    btns.find(b => b.el.textContent.includes('打造'))?.onClick?.();
    await new Promise(r => setTimeout(r, 300));
    conn.send = orig;
    return { ids: sentIds, cls };`);
  const pass = master?.includes?.(254) && stone?.includes?.(261) && craft?.ids?.includes?.(274);
  report('PKTS', !!pass, { master, stone, craft });
}

// ============ 6. R19 回包: 取回删行 + 伙伴同步 ============
{
  const rt = await npcRun(97, ['取回选中', '刷新'], [], `
    conn.dispatchEvent(new CustomEvent('refineList', { detail: { list: [
      { index: 101, weapon: { infoIndex: 549 }, type: 0, quality: 2, chance: 80, maxChance: 100 },
      { index: 102, weapon: { infoIndex: 549 }, type: 0, quality: 3, chance: 50, maxChance: 100 },
    ] } }));
    await new Promise(r => setTimeout(r, 300));
    conn.dispatchEvent(new CustomEvent('npcRefineRetrieveResult', { detail: { index: 101 } }));
    await new Promise(r => setTimeout(r, 300));
    const txt = pc.el.textContent;
    return { removed101: !txt.includes('80/100'), kept102: txt.includes('50/100') };`);
  const c2 = await npcRun(149, ['放生', '寄存', '取回'], [], `
    reg.itemStore.info.companions = [ { index: 7, name: '测试虎', level: 3, hunger: 50 }, { index: 8, name: '测试鹰', level: 2, hunger: 60 } ];
    pc.render ? null : null;
    // 重新打开页面触发 renderCompanions
    conn.dispatchEvent(new CustomEvent('npcResponse', { detail: { index: 149, objectID: 1, values: [] } }));
    await new Promise(r => setTimeout(r, 400));
    const beforeTxt = pc.el.textContent;
    conn.dispatchEvent(new CustomEvent('companionReleaseResult', { detail: { index: 7 } }));
    await new Promise(r => setTimeout(r, 300));
    const afterTxt = pc.el.textContent;
    conn.dispatchEvent(new CustomEvent('companionRetrieveResult', { detail: { index: 8 } }));
    await new Promise(r => setTimeout(r, 300));
    const finalTxt = pc.el.textContent;
    return { had2: beforeTxt.includes('测试虎') && beforeTxt.includes('测试鹰'), released: !afterTxt.includes('测试虎') && afterTxt.includes('测试鹰'), retrievedMark: finalTxt.includes('●') && finalTxt.includes('测试鹰') };`);
  const cp = typeof c2 === 'object' ? c2 : {};
  report('R19', rt?.removed101 && rt?.kept102 && cp.had2 && cp.released && cp.retrievedMark, { retrieve: rt, companion: c2 });
}

// ============ 7. R20 提交锁三态 (拦截发送隔离真服时序) ============
{
  const r = await npcRun(168, ['评估', '从背包导入'], [[0, 829, 10], [1, 830, 10], [2, 831, 1], [3, 828, 1]], `
    btns.find(b => b.el.textContent.includes('从背包导入'))?.onClick?.();
    await new Promise(r => setTimeout(r, 300));
    btns.find(b => b.el.textContent.trim() === '攻击')?.onClick?.();
    const sub = btns.find(b => b.el.textContent.includes('精炼') && !b.el.textContent.includes('大师'));
    ${trackIds}
    sub.onClick?.();
    await new Promise(r => setTimeout(r, 50));
    const lockedAfterSubmit = [0, 1, 2, 3].every(sl => store.isLocked(1, sl));
    btns.find(b => b.el.textContent.includes('从背包导入'))?.onClick?.();
    await new Promise(r => setTimeout(r, 50));
    const before2 = sentIds.length;
    btns.find(b => b.el.textContent.trim() === '攻击')?.onClick?.();
    sub.onClick?.();
    await new Promise(r => setTimeout(r, 50));
    const secondBlocked = sentIds.length === before2;
    conn.dispatchEvent(new CustomEvent('npcMasterRefineResult', { detail: { fragment1s: [{ gridType: 1, slot: 0, count: 10 }], fragment2s: [{ gridType: 1, slot: 1, count: 10 }], fragment3s: [{ gridType: 1, slot: 2, count: 1 }], stones: [{ gridType: 1, slot: 3, count: 1 }], specials: [], success: false } }));
    await new Promise(r => setTimeout(r, 50));
    const unlockedAfterResult = [0, 1, 2, 3].every(sl => !store.isLocked(1, sl));
    btns.find(b => b.el.textContent.includes('从背包导入'))?.onClick?.();
    await new Promise(r => setTimeout(r, 50));
    btns.find(b => b.el.textContent.trim() === '攻击')?.onClick?.();
    sub.onClick?.();
    await new Promise(r => setTimeout(r, 50));
    const resendOk = sentIds.length > before2;
    conn.send = orig;
    return { lockedAfterSubmit, secondBlocked, unlockedAfterResult, resendOk, sentIds };`);
  const d = typeof r === 'object' ? r : {};
  report('LOCKS', d.lockedAfterSubmit && d.secondBlocked && d.unlockedAfterResult && d.resendOk, r);
}

// ============ 8. 真服 e2e: 254 真发 → S 回包 → 聊天 (需 ServerCore) ============
{
  const r = await npcRun(168, ['评估', '从背包导入'], [[0, 829, 10], [1, 830, 10], [2, 831, 1], [3, 828, 1]], `
    const captured = [];
    const origChat = s.addChat.bind(s);
    s.addChat = (t, k) => { captured.push(String(t)); return origChat(t, k); };
    btns.find(b => b.el.textContent.includes('从背包导入'))?.onClick?.();
    await new Promise(r => setTimeout(r, 300));
    btns.find(b => b.el.textContent.trim() === '攻击')?.onClick?.();
    const sub = btns.find(b => b.el.textContent.includes('精炼') && !b.el.textContent.includes('大师'));
    sub.enabled = true;
    sub.onClick?.();   // 锁可能残留 (前段拦截未解锁) — 强制发
    await new Promise(r => setTimeout(r, 4000));
    s.addChat = origChat;
    return { chat: captured.filter(t => t.includes('精炼')).slice(0, 3) };`);
  const d = typeof r === 'object' ? r : {};
  report('E2E', Array.isArray(d.chat) && d.chat.length > 0, r);
}

// ============ 9. 右键快路由 (TryRouteItem :155-162): MasterRefine 面板开着, 右键碎片入桶 ============
{
  const r = await npcRun(168, ['评估', '从背包导入'], [[0, 829, 10], [1, 830, 10]], `
    // 模拟背包右键: 直接走 routeHandlers 链 (win-inventory grid.onQuickRoute 同源); inv 由 ctx 提供
    const mkCell = (slot) => ({ item: inv.get(slot), gridType: 1, slot });
    const routed1 = reg.routeHandlers.some(fn => fn(mkCell(0)));   // 碎片I → f1
    const routed2 = reg.routeHandlers.some(fn => fn(mkCell(1)));   // 碎片II → f2
    const boxTxt = pc.el.querySelector('div[style*="overflow-y"]')?.textContent ?? '';
    const lockedOk = store.isLocked(1, 0) && store.isLocked(1, 1);
    // WeddingRing 面板路由校验 (非 Ring 拒绝): 开 155 页右键碎片 → false
    conn.dispatchEvent(new CustomEvent('npcResponse', { detail: { index: 155, objectID: 1, values: [] } }));
    await new Promise(r => setTimeout(r, 400));
    const rejected = !reg.routeHandlers.some(fn => fn(mkCell(0)));
    return { routed1, routed2, inBuckets: boxTxt.includes('碎片（一） (1)') && boxTxt.includes('碎片（二） (1)'), lockedOk, rejected };`);
  const d = typeof r === 'object' ? r : {};
  report('ROUTE', d.routed1 && d.routed2 && d.inBuckets && d.lockedOk && d.rejected, r);
}

// ---- 汇总 ----
const failed = results.filter(x => !x.pass);
console.log(`\nNPC PANELS: ${results.length - failed.length}/${results.length} PASS${failed.length ? ' — FAIL: ' + failed.map(f => f.name).join(', ') : ''}`);
if (logs.length) console.log('PAGE LOGS:', logs.slice(0, 6).join('\n'));
try { chrome.kill(9); } catch {}
process.exit(failed.length ? 1 : 0);
