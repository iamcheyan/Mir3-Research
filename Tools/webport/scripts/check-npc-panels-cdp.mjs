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
  const r = await npcRun(171, ['分解', '从背包导入', '提交'], [[0, 549, 1]], `
    if (!store.currency(0)) store.currencies.push({ currencyIndex: 0, amount: 0n });
    store.currency(0).amount = 999999n;   // 抬高余额满足 RefreshFragment 门闩 (:379)
    await new Promise(r => setTimeout(r, 400));   // 等 fragInfo 预热 (showPage 异步)
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

// ============ 10. 行移除解锁 (CancelLinks): 路由入桶→点击移除→格解锁 ============
{
  const r = await npcRun(168, ['评估', '从背包导入'], [[0, 829, 10]], `
    const mkCell = (slot) => ({ item: inv.get(slot), gridType: 1, slot });
    const routed = reg.routeHandlers.some(fn => fn(mkCell(0)));
    const lockedAfterRoute = store.isLocked(1, 0);
    // 点击 · 行 = 移除 (列表 DOM 第一个 '· ' 行)
    const rows = [...pc.el.querySelectorAll('div')].filter(d => d.textContent.startsWith('·'));
    rows[0]?.click();
    await new Promise(r => setTimeout(r, 200));
    const unlockedAfterRemove = !store.isLocked(1, 0);
    const bucketEmpty = (pc.el.querySelector('div[style*="overflow-y"]')?.textContent ?? '').includes('碎片（一） (0)');
    return { routed, lockedAfterRoute, unlockedAfterRemove, bucketEmpty };`);
  const d = typeof r === 'object' ? r : {};
  report('RMVLOCK', d.routed && d.lockedAfterRoute && d.unlockedAfterRemove && d.bucketEmpty, r);
}

// ============ 11. 分解规则 (CanFragment/FragmentCost :622/:653 + RefreshFragment :371) ============
{
  // 549=裁决之锤 Superior Weapon req38 → cost 38*10000/2=190000, 可分解; 1=Gold Currency → 拒
  const r = await npcRun(171, ['分解', '从背包导入', '提交'], [[0, 549, 1], [1, 1, 100], [2, 2, 1]], `
    btns.find(b => b.el.textContent.includes('从背包导入'))?.onClick?.();
    await new Promise(r => setTimeout(r, 600));   // 等 fragInfo 预热+重渲染
    const boxTxt = pc.el.querySelector('div[style*="overflow-y"]')?.textContent ?? '';
    const labelTxt = pc.el.textContent.match(/费用[^）]*/) ?? [''] ;
    const tookWeapon = boxTxt.includes('裁决之锤');
    const rejectedGold = !boxTxt.includes('Gold') && !boxTxt.includes('金币 x');
    const rejectedBook = !boxTxt.includes('基本剑术') && !boxTxt.includes('剑术');
    return { tookWeapon, rejectedGold, rejectedBook, label: labelTxt[0].slice(0, 40) };`);
  const d = typeof r === 'object' ? r : {};
  report('FRAGMENT', d.tookWeapon && d.rejectedGold && d.rejectedBook && /费用/.test(d.label ?? ''), r);
}

// ============ 12. 强化属性 19 选 (BuildAccessoryUpgrade :639-672): 选择器+门闩+包值 ============
{
  // 197=AccessoryRefineUpgrade 页; 160=Plain Ring
  const r = await npcRun(197, ['强化饰品', '从背包导入', '提交'], [[0, 160, 1]], `
    btns.find(b => b.el.textContent.includes('从背包导入'))?.onClick?.();
    await new Promise(r => setTimeout(r, 300));
    const sub = btns.find(b => b.el.textContent.trim() === '提交');
    const gateBefore = !sub?.enabled;   // 未选属性 → disabled (:672)
    const optCount = [...pc.el.querySelectorAll('div')].filter(d => /攻击 DC 1%|幻影 \+1|准确 \+1/.test(d.textContent)).length;
    // 拦截 (id+尾字节: cellLink(target).byte(refineType) — 末字节=RefineType, Accuracy=16)
    let lastByte = -1; const sentIds = []; const orig = conn.send.bind(conn);
    conn.send = (b) => { if (b?.byteLength > 6) { const id = new DataView(b.buffer, b.byteOffset).getInt16(4, true); sentIds.push(id); if (id === 246) lastByte = b[b.byteLength - 1]; } return b; };
    [...pc.el.querySelectorAll('div')].find(d => d.children.length === 0 && d.textContent.trim() === '准确 +1')?.click();   // 叶子节点 (选项 div)
    await new Promise(r => setTimeout(r, 200));
    const optNow = [...pc.el.querySelectorAll('div')].some(d => d.children.length === 0 && d.textContent.trim() === '✓ 准确 +1');   // 重渲染后 ✓ 标记
    const gateAfter = !!sub?.enabled;   // 选中 → enabled (:660-661)
    sub?.onClick?.();
    await new Promise(r => setTimeout(r, 300));
    conn.send = orig;
    return { gateBefore, optCount: optCount >= 3, gateAfter, optNow, sentIds, lastByte };`);
  const d = typeof r === 'object' ? r : {};
  report('UPGRADE', d.gateBefore && d.optCount && d.gateAfter && d.optNow && d.sentIds?.includes(246) && d.lastByte === 16, r);
}

// ============ 13. 寄售行全链 (ConsignmentDialog/ConsignItemDialog): 弹窗+校验+包+锁+S 解锁 ============
{
  const r = await ev(`(async () => {
    const s = __WEBPORT.current; const reg = await s._winInstall;
    const { winConsign } = await import('/static/js/win-consign.js');
    const sh = await winConsign(s);
    const win = sh.win; const store = reg.itemStore; const conn = s.conn;
    const captured = []; const origChat = s.addChat.bind(s);
    s.addChat = (t, k) => { captured.push(String(t)); return origChat(t, k); };
    const btn = (t) => [...win.el.querySelectorAll('.dxbtn')].find(b => b.textContent.includes(t));
    btn('我的寄售')?.click(); await new Promise(r => setTimeout(r, 300));
    const inv = reg.itemStore.grids.get(1);
    inv.set(5, { infoIndex: 165, slot: 5, count: 2, currentDura: 1, maxDura: 1 });   // 165 Horned Ring (独占物品, 前组 slot 0 有 160 同名行)
    btn('寄售物品')?.click();
    await new Promise(r => setTimeout(r, 500));
    const q = (t) => [...win.el.querySelectorAll('button')].filter(b => b.textContent.trim() === t);
    const leaf = (p) => [...win.el.querySelectorAll('div')].filter(d => d.children.length === 0 && p(d));
    const popupShown = leaf(d => d.textContent.includes('单价') === false && d.textContent.startsWith('·')).length >= 0 && !!q('确认')[0];
    // 1) 未选物品确认 → 聊天错误 (:575)
    q('确认')[0]?.click(); await new Promise(r => setTimeout(r, 150));
    const errNoItem = captured.some(t => t.includes('未选择物品'));
    // 2) 选物品 (按 160 的名字定位行 — 前组在 slot 0-2 有残留物品) + 价格 ±5000 (:558-561)
    const { D } = await import('/static/js/data.js');
    const ringNm = D().itemsById?.[165]?.zh ?? D().itemsById?.[165]?.name ?? '物品#165';   // win-consign itemName 同源
    leaf(d => d.textContent.startsWith('·') && d.textContent.includes(ringNm))[0]?.click();
    await new Promise(r => setTimeout(r, 150));
    const priceInp = [...win.el.querySelectorAll('input')].filter(i => i.type === 'text').pop();   // 弹窗价格框 (nameInput 的 input 在 DOM 前面)
    priceInp.value = '12000';
    [...win.el.querySelectorAll('button')].find(b => b.textContent === '-5000')?.click();
    await new Promise(r => setTimeout(r, 100));
    const priceAfter = priceInp.value;
    // 3) 确认 → 二次确认框 (手续费) → 发包 C_MARKETPLACECONSIGN 213 + 锁来源 (:266-270)
    const sentIds = []; const orig = conn.send.bind(conn);
    conn.send = (b) => { if (b?.byteLength > 6) sentIds.push(new DataView(b.buffer, b.byteOffset).getInt16(4, true)); return b; };
    q('确认')[0]?.click(); await new Promise(r => setTimeout(r, 200));
    const confirm2 = win.el.textContent.includes('手续费');
    q('确认')[0]?.click(); await new Promise(r => setTimeout(r, 300));
    conn.send = orig;
    const lockedOk = store.isLocked(1, 5);
    // 4) S 库存回包 → 解锁 (:270 注释)
    conn.dispatchEvent(new CustomEvent('marketPlaceConsign', { detail: { consignments: [] } }));
    await new Promise(r => setTimeout(r, 200));
    const unlockedOk = !store.isLocked(1, 5);
    s.addChat = origChat;
    return { popupShown, errNoItem, priceAfter, confirm2, sentIds, lockedOk, unlockedOk };
  })()`);
  const d = typeof r === 'object' ? r : {};
  report('CONSIGN', d.popupShown && d.errNoItem && d.priceAfter === '7000' && d.confirm2 && d.sentIds?.includes(213) && d.lockedOk && d.unlockedOk, r);
}

// ============ 14. 寄售搜索参数 (Search :294-304): 排序切换/类型过滤/历史链 ============
{
  const r = await ev(`(async () => {
    const s = __WEBPORT.current;
    const { winConsign } = await import('/static/js/win-consign.js');
    const sh = await winConsign(s);
    const win = sh.win; const conn = s.conn;
    const ctl = (t) => [...win.el.querySelectorAll('.dxbtn')].find(b => b.textContent.includes(t))?.__ctl;   // DXButton 实例 (DOM click 不可靠)
    const pkts = []; const orig = conn.send.bind(conn);
    conn.send = (b) => { if (b?.byteLength > 6) { const dv = new DataView(b.buffer, b.byteOffset); pkts.push({ id: dv.getInt16(4, true), hex: [...b.slice(6, Math.min(b.byteLength, 44))].map(x => x.toString(16).padStart(2, '0')).join('') }); } return b; };
    ctl('搜索购买')?.onClick();   // 前组 CONSIGN 停在 mine 页 — 先回 search 页 (否则行不渲染)
    await new Promise(r => setTimeout(r, 150));
    // 排序二态 (:91-92): 最新 → 最低价格 (直调 onClick)
    const sortCtl = ctl('最新');
    sortCtl?.onClick();
    await new Promise(r => setTimeout(r, 150));
    const toggled = !!ctl('最低价格');
    // 类型过滤: 选武器(2) → 搜索 C 219
    const sel = win.el.querySelector('select');
    sel.value = '2'; sel.dispatchEvent(new Event('change'));
    await new Promise(r => setTimeout(r, 150));
    conn.send = orig;
    const searchPkt = pkts.filter(p => p.id === 219).pop();   // 取最后一次 (typeSel change 的)
    // 历史链: S search 结果 → 选中行 → 成交记录 C 216 → 双门闩回填
    conn.dispatchEvent(new CustomEvent('marketPlaceSearch', { detail: { results: [{ index: 7, item: { infoIndex: 160, count: 1 }, price: 500 }] } }));
    await new Promise(r => setTimeout(r, 400));
    const rows = [...win.el.querySelectorAll('div')].filter(d => d.children.length === 0 && d.textContent.includes('500'));
    rows[0]?.click();
    await new Promise(r => setTimeout(r, 250));
    const histCtl = ctl('成交记录');
    const histEnabled = !!histCtl?.enabled;
    let histSent = false;
    conn.send = (b) => { if (new DataView(b.buffer, b.byteOffset).getInt16(4, true) === 216) histSent = true; return b; };
    histCtl?.onClick();
    await new Promise(r => setTimeout(r, 300));
    conn.send = orig;
    conn.dispatchEvent(new CustomEvent('marketPlaceHistory', { detail: { index: 160, display: 99, saleCount: 1n, lastPrice: 1n, averagePrice: 1n } }));
    await new Promise(r => setTimeout(r, 150));
    const gateBlocked = !win.el.textContent.includes('销量: 1');
    conn.dispatchEvent(new CustomEvent('marketPlaceHistory', { detail: { index: 160, display: 1, saleCount: 42n, lastPrice: 500n, averagePrice: 480n } }));
    await new Promise(r => setTimeout(r, 150));
    const filled = win.el.textContent.includes('销量: 42') && win.el.textContent.includes('最近成交: 500') && win.el.textContent.includes('平均价: 480');
    return { toggled, searchPkt, histEnabled, histSent, gateBlocked, filled };
  })()`);
  const d = typeof r === 'object' ? r : {};
  // C 219 由 typeSel change 触发: name=''(00) bool(01) itemType=Weapon(02) sort=3 LE (03000000)
  const pktOk = d.searchPkt?.hex === '00010203000000';
  report('SRCHHIST', d.toggled && pktOk && d.histEnabled && d.histSent && d.gateBlocked && d.filled, r);
}

// ============ 15. 搜索惰性加载 (ApplySearch/Index :334-366): null 占位+请求+回填 ============
{
  const r = await ev(`(async () => {
    const s = __WEBPORT.current;
    const { winConsign } = await import('/static/js/win-consign.js');
    const sh = await winConsign(s);
    const win = sh.win; const conn = s.conn;
    const ctl = (t) => [...win.el.querySelectorAll('.dxbtn')].find(b => b.textContent.includes(t))?.__ctl;
    ctl('搜索购买')?.onClick();
    await new Promise(r => setTimeout(r, 150));
    const sent222 = []; const orig = conn.send.bind(conn);
    conn.send = (b) => { if (new DataView(b.buffer, b.byteOffset).getInt16(4, true) === 222) sent222.push(b.byteLength); return b; };
    // S search: count=3 实数据 1 条 → 2 个 null 槽
    conn.dispatchEvent(new CustomEvent('marketPlaceSearch', { detail: { count: 3, results: [{ index: 0, item: { infoIndex: 160, count: 1 }, price: 500, seller: '甲', message: '急售' }] } }));
    await new Promise(r => setTimeout(r, 600));   // render 循环内逐行 await itemName — 留足
    const txt = win.el.textContent;
    const loading = (txt.match(/加载中…/g) ?? []).length;
    const sellerShown = txt.includes('甲') && txt.includes('急售');
    const reqOnce = sent222.length === 2;   // index 1,2 各一次 (:451-452 去重)
    // 选中行 0 → 回填 index=1 → 选中复位 (ApplySearchIndex :363-364)
    const rows = [...win.el.querySelectorAll('div')].filter(d => d.children.length === 0 && d.textContent.includes('500'));
    rows[0]?.click();
    await new Promise(r => setTimeout(r, 200));
    const buyCtl = [...win.el.querySelectorAll('.dxbtn')].find(b => b.textContent.trim() === '购买')?.__ctl;   // 精确匹配 (tab '搜索购买' 含 '购买')
    const selBefore = !!buyCtl?.enabled;
    conn.dispatchEvent(new CustomEvent('marketPlaceSearchIndex', { detail: { index: 1, result: { index: 1, item: { infoIndex: 165, count: 2 }, price: 700, seller: '乙', message: '' } } }));
    await new Promise(r => setTimeout(r, 600));
    conn.send = orig;
    const filled = win.el.textContent.includes('700 金币') && win.el.textContent.includes('乙');
    const selReset = !buyCtl?.enabled;
    // searchCount trim (:350-351)
    conn.dispatchEvent(new CustomEvent('marketPlaceSearchCount', { detail: { count: 1 } }));
    await new Promise(r => setTimeout(r, 400));
    const trimmed = !win.el.textContent.includes('加载中…');
    return { loading, sellerShown, reqOnce, selBefore, filled, selReset, trimmed };
  })()`);
  const d = typeof r === 'object' ? r : {};
  report('LAZYIDX', d.loading === 2 && d.sellerShown && d.reqOnce && d.selBefore && d.filled && d.selReset && d.trimmed, r);
}

// ============ 16. 寄售 S 应用器 (AddConsignments :368 / Changed :385 / Buy :396) ============
{
  const r = await ev(`(async () => {
    const s = __WEBPORT.current;
    const { winConsign } = await import('/static/js/win-consign.js');
    const sh = await winConsign(s);
    const win = sh.win; const conn = s.conn;
    const ctl = (t) => [...win.el.querySelectorAll('.dxbtn')].find(b => b.textContent.trim() === t)?.__ctl;
    ctl('我的寄售')?.onClick();
    await new Promise(r => setTimeout(r, 150));
    // 全量 2 条 (Index 10/11) → 增量 1 条 (Index 11 更新) + 新增 (Index 12) — 合并不清空
    conn.dispatchEvent(new CustomEvent('marketPlaceConsign', { detail: { consignments: [
      { index: 10, item: { infoIndex: 160, count: 1 }, price: 100 },
      { index: 11, item: { infoIndex: 165, count: 5 }, price: 200 }] } }));
    await new Promise(r => setTimeout(r, 500));
    const afterFull = win.el.textContent.includes('100') && win.el.textContent.includes('200');
    conn.dispatchEvent(new CustomEvent('marketPlaceConsign', { detail: { consignments: [
      { index: 11, item: { infoIndex: 165, count: 2 }, price: 250 }] } }));   // 单条增量 (寄售成功)
    await new Promise(r => setTimeout(r, 500));
    const merged = win.el.textContent.includes('250') && win.el.textContent.includes('100 金币');   // 11 更新 250, 10 保留
    const noDup = (win.el.textContent.match(/250 金币/g) ?? []).length === 1;
    // Changed: count<=0 → 移除 (:389)
    conn.dispatchEvent(new CustomEvent('marketPlaceConsignChanged', { detail: { index: 10, count: 0 } }));
    await new Promise(r => setTimeout(r, 400));
    const removed = !win.el.textContent.includes('100 金币');
    // Buy: search 页售罄 → 空槽不移位 (:405-407)
    ctl('搜索购买')?.onClick();
    await new Promise(r => setTimeout(r, 150));
    conn.dispatchEvent(new CustomEvent('marketPlaceSearch', { detail: { count: 1, results: [{ index: 55, item: { infoIndex: 160, count: 3 }, price: 900 }] } }));
    await new Promise(r => setTimeout(r, 500));
    conn.dispatchEvent(new CustomEvent('marketPlaceBuy', { detail: { index: 55, count: 0, success: true } }));
    await new Promise(r => setTimeout(r, 400));
    const soldOut = !win.el.textContent.includes('900 金币') && win.el.textContent.includes('加载中…');   // 售罄 → item=null → 加载中标签 (:407→:445), 空槽不移位
    return { afterFull, merged, noDup, removed, soldOut };
  })()`);
  const d = typeof r === 'object' ? r : {};
  report('APPLYERS', d.afterFull && d.merged && d.noDup && d.removed && d.soldOut, r);
}

// ---- 汇总 ----
const failed = results.filter(x => !x.pass);
console.log(`\nNPC PANELS: ${results.length - failed.length}/${results.length} PASS${failed.length ? ' — FAIL: ' + failed.map(f => f.name).join(', ') : ''}`);
if (logs.length) console.log('PAGE LOGS:', logs.slice(0, 6).join('\n'));
try { chrome.kill(9); } catch {}
process.exit(failed.length ? 1 : 0);
