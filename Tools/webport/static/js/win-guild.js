// win-guild.js — 行会 GuildDialog.cs 移植 (D路 par-win)
// 6 页签 (创建-主页/成员/仓库/战争/样式/城堡 :54-56); 无行会时只留创建页 (:89-92);
// 主页: 公告编辑/保存 (C.GuildEditNotice) + 税率 (C.GuildTax) + 资金;
// 成员: 2列列表 + 邀请 (C.GuildInviteMember) + 踢人 (C.GuildKickMember);
// 仓库: 10列网格 (GuildStorage GridType=15); 创建页: C.GuildCreate{name}/C.JoinStarterGuild。
// 数据: ItemStore.guild (S.GuildInfo/GuildUpdate/MemberOnline/Offline/FundsChanged)。

import { getWindow } from './uitree.js';
import { WindowManager } from './windows.js';
import { DXControl, DXLabel, DXButton, DXTextInput } from './dx.js';
import { DXItemGrid } from './dxgrid.js';
import { GRID, C } from './net.js';

const GUILD_CREATE_COST = 7500000;   // Globals.GuildCreationCost (Godot GuildDialog.cs:213-220)

export async function winGuild(scene, store, reg) {
  const w = await getWindow('GuildDialog');
  if (!w) return null;
  const conn = scene.conn;

  let tab = 0;
  const bg = w.byPath.get('GuildDialog/0');

  const tabDefs = ['创建', '成员', '仓库', '战争', '样式', '城堡'];
  const tabs = tabDefs.map((text, i) => {
    const b = new DXButton({ text, fontSize: 8, library: 'Interface', index: -1,
      location: [14 + i * 76, 39], size: [68, 25],
      onClick: () => selectTab(i) });
    w.addControl(b);
    return b;
  });

  const content = new DXControl({ location: [0, 62], size: [456, 400], clip: true, isControl: false });
  w.addControl(content);

  function hasGuild() { return !!store.guild; }
  function selectTab(i) {
    if (!hasGuild() && i > 0) i = 0;      // 无行会只留创建页 (:89-92)
    tab = i;
    if (bg) bg.index = [hasGuild() ? 261 : 260, 262, 263, 264, 265, 266][i];
    render();
  }

  function mkText(text, x, y, colour = [255, 255, 255, 255], size = 9, wpx = 300) {
    return new DXLabel({ text, fontSize: size, textColour: colour, drawOutline: true,
      location: [x, y], size: [wpx, 18], isControl: false });
  }

  async function render() {
    content.el.replaceChildren();
    tabs.forEach((b, i) => {
      b.visible = hasGuild() || i === 0;
      b.text = i === 0 ? (hasGuild() ? '主页' : '创建') : tabDefs[i];
      b.textColour = i === tab ? [255, 216, 77, 255] : [255, 255, 255, 255];
    });
    if (tab === 0) hasGuild() ? renderHome() : renderCreate();
    else if (tab === 1) renderMembers();
    else if (tab === 2) renderStorage();
    else if (tab === 3) renderWar();
    else if (tab === 4) renderStyle();
    else if (tab === 5) renderCastle();
  }

  // ---- 创建页 (193-228) ----
  let createName = null, useGold = true;
  function renderCreate() {
    content.addControl(mkText('第一步: 行会名称', 18, 10, [255, 216, 77, 255]));
    createName = new DXTextInput({ location: [150, 8], size: [190, 20], fontSize: 9 });
    content.addControl(createName);
    content.addControl(mkText('第二步: 创建费用', 18, 60, [255, 216, 77, 255]));
    const gold = new DXButton({ text: `金币 ${GUILD_CREATE_COST.toLocaleString()}`, fontSize: 8,
      library: 'Interface', index: -1, location: [150, 56], size: [160, 22],
      textColour: [255, 216, 77, 255], onClick: () => { useGold = true; render(); } });
    const horn = new DXButton({ text: '行会号角', fontSize: 8,
      library: 'Interface', index: -1, location: [150, 80], size: [160, 22],
      textColour: [255, 255, 255, 255], onClick: () => { useGold = false; render(); } });
    content.addControl(gold, horn);
    content.addControl(mkText('第四步: 总费用', 18, 130, [255, 216, 77, 255]));
    content.addControl(mkText(useGold ? GUILD_CREATE_COST.toLocaleString() : '行会号角 x1', 150, 130));
    const create = new DXButton({ text: '创建行会', fontSize: 9, library: 'Interface', index: -1,
      location: [150, 190], size: [105, 27], onClick: () => {
        const name = createName.text.trim();
        if (!name) { scene.addChat('请输入行会名称', 'hint'); return; }
        // C.GuildCreate{Name, UseGold, Members, Storage} — 服务端实际为 {Name}(ClientPackets.cs:589)
        conn.send(C.GuildCreate(name));
      } });
    const starter = new DXButton({ text: '加入新手行会', fontSize: 8, library: 'Interface', index: -1,
      location: [18, 190], size: [125, 27], onClick: () => conn.sendJoinStarterGuild() });
    content.addControl(create, starter);
  }

  // ---- 主页 (247-294) ----
  let noticeInput = null, noticeReadonly = true;
  function renderHome() {
    const g = store.guild;
    content.addControl(mkText('行会公告', 8, 4, [255, 216, 77, 255]));
    const edit = new DXButton({ text: '编辑', fontSize: 8, library: 'Interface', index: -1,
      location: [328, 0], size: [60, 24], onClick: () => { noticeReadonly = false; noticeInput.input.readOnly = false; noticeInput.focus(); } });
    const save = new DXButton({ text: '保存', fontSize: 8, library: 'Interface', index: -1,
      location: [262, 0], size: [60, 24], onClick: () => {
        noticeReadonly = true; noticeInput.input.readOnly = true;
        conn.sendGuildEditNotice(noticeInput.text);
      } });
    content.addControl(edit, save);
    noticeInput = new DXTextInput({ location: [4, 27], size: [382, 60], fontSize: 9, text: g?.notice ?? '' });
    noticeInput.input.readOnly = true;
    noticeInput.input.style.cssText += 'white-space:pre-wrap;';
    content.addControl(noticeInput);
    // 统计
    let y = 100;
    content.addControl(mkText('行会统计', 8, y, [255, 216, 77, 255])); y += 20;
    content.addControl(mkText(`成员: ${(g?.members ?? []).length} / ${g?.memberLimit ?? 0}`, 18, y)); y += 18;
    content.addControl(mkText(`行会资金: ${Number(g?.guildFunds ?? 0).toLocaleString()}`, 18, y)); y += 18;
    content.addControl(mkText(`今日增长: ${g?.dailyGrowth ?? 0}`, 18, y)); y += 18;
    content.addControl(mkText(`总贡献: ${g?.totalContribution ?? 0}`, 18, y)); y += 18;
    content.addControl(mkText(`今日贡献: ${g?.dailyContribution ?? 0}`, 18, y)); y += 18;
    content.addControl(mkText(`税率: ${g?.tax ?? 0}%`, 18, y)); y += 26;
    // 税率设置 (C.GuildTax)
    content.addControl(mkText('设置税率:', 18, y));
    const taxInput = new DXTextInput({ location: [80, y - 2], size: [80, 20], fontSize: 9, text: String(g?.tax ?? 0) });
    content.addControl(taxInput);
    const taxBtn = new DXButton({ text: '设置税率', fontSize: 8, library: 'Interface', index: -1,
      location: [165, y - 3], size: [82, 24], onClick: () => {
        const v = parseInt(taxInput.text, 10);
        if (!Number.isNaN(v)) conn.sendGuildTax(BigInt(Math.max(0, v)));
      } });
    content.addControl(taxBtn);
    // 底栏: 邀请/扩容 (58-74)
    const inviteInput = new DXTextInput({ location: [18, 368], size: [165, 24], fontSize: 9 });
    content.addControl(inviteInput);
    const invite = new DXButton({ text: '邀请成员', fontSize: 8, library: 'Interface', index: -1,
      location: [190, 367], size: [100, 28], onClick: () => {
        const n = inviteInput.text.trim();
        if (n) { conn.sendGuildInviteMember(n); inviteInput.text = ''; }
      } });
    const upMember = new DXButton({ text: '扩大成员上限', fontSize: 8, library: 'Interface', index: -1,
      location: [18, 400], size: [120, 28], onClick: () => conn.sendGuildIncreaseMember() });
    const upStorage = new DXButton({ text: '扩大仓库', fontSize: 8, library: 'Interface', index: -1,
      location: [146, 400], size: [100, 28], onClick: () => conn.sendGuildIncreaseStorage() });
    content.addControl(invite, upMember, upStorage);
  }

  // ---- 成员页 (124-149, 行路由 :577-619) ----
  function renderMembers() {
    const g = store.guild;
    content.addControl(mkText(`成员 (${(g?.members ?? []).length})`, 18, 7, [255, 216, 77, 255]));
    content.addControl(mkText('序号  名称               职务        状态     贡献', 18, 28, [200, 160, 90, 255], 8));
    (g?.members ?? []).forEach((m, i) => {
      const online = m.online ?? (m.objectID > 0);
      const line = `${String(i + 1).padStart(2)}  ${(m.name ?? '').padEnd(16)} ${(m.rank ?? '').padEnd(8)} ${online ? '在线' : '离线'}  贡献 ${Number(m.totalContribution ?? 0).toLocaleString()}`;
      const l = mkText(line, 18, 48 + i * 23, online ? [255, 255, 255, 255] : [150, 150, 150, 255], 8, 420);
      l.el.style.cursor = 'pointer';
      // 左键=编辑成员(踢人入口), 中键=组队邀请, 右键=大地图定位(此处提示)
      l.el.addEventListener('click', () => {
        if (confirm(`将 ${m.name} 踢出行会?`)) conn.sendGuildKickMember(m.index);
      });
      l.el.addEventListener('auxclick', (ev) => {
        if (ev.button === 1) { conn.sendGroupInvite(m.name); ev.preventDefault(); }
      });
      content.addControl(l);
    });
  }

  // ---- 仓库页 (150-176): 10 列 GuildStorage ----
  function renderStorage() {
    const g = store.guild;
    content.addControl(mkText('仓库', 18, 5, [255, 216, 77, 255]));
    const storageItems = new Map();
    for (const it of g?.storage ?? []) if (it) storageItems.set(it.slot, it);
    const grid = new DXItemGrid({
      cols: 10, rows: 10, gridType: GRID.GUILDSTORAGE, store,
      location: [8, 45], size: [10 * 37 + 1, 10 * 37 + 1],
      readOnly: true,
      virtualGrid: storageItems,
    });
    grid.capacity = g?.storageLimit ?? 0;
    content.addControl(grid);
    content.addControl(mkText('从背包拖入物品存放 (需在安全区)', 18, 420, [160, 160, 160, 255], 8));
  }

  // ---- 战争页 (327-368) ----
  function renderWar() {
    content.addControl(mkText('城堡与攻城战', 18, 16, [255, 216, 77, 255]));
    content.addControl(mkText('敌方行会:', 18, 34));
    const enemy = new DXTextInput({ location: [85, 32], size: [170, 24], fontSize: 9 });
    content.addControl(enemy);
    const declare = new DXButton({ text: '宣战', fontSize: 8, library: 'Interface', index: -1,
      location: [265, 31], size: [92, 24], onClick: () => {
        const n = enemy.text.trim();
        if (n) conn.sendGuildWar(n);
      } });
    content.addControl(declare);
    content.addControl(mkText('(城堡数据由 S.GuildCastleInfo 推送)', 18, 70, [160, 160, 160, 255], 8));
    // 城堡维护
    const open = new DXButton({ text: '开/关城门', fontSize: 8, library: 'Interface', index: -1,
      location: [18, 360], size: [110, 26], onClick: () => conn.sendGuildToggleCastleGates() });
    const repG = new DXButton({ text: '修理城门', fontSize: 8, library: 'Interface', index: -1,
      location: [148, 360], size: [90, 26], onClick: () => conn.sendGuildRepairCastleGates() });
    const repU = new DXButton({ text: '修理守卫', fontSize: 8, library: 'Interface', index: -1,
      location: [258, 360], size: [90, 26], onClick: () => conn.sendGuildRepairCastleGuards() });
    content.addControl(open, repG, repU);
  }

  // ---- 样式页 (296-325): 旗帜/颜色 → C.GuildFlag/C.GuildColour ----
  let previewFlag = 0;
  function renderStyle() {
    content.addControl(mkText('行会样式', 18, 10, [255, 216, 77, 255]));
    content.addControl(mkText('旗帜 (CastleFlag 库):', 18, 60, [255, 255, 255, 255], 9, 200));
    content.addControl(mkText(`旗帜 #${previewFlag}`, 150, 85));
    const prev = new DXButton({ text: '上一个', fontSize: 8, library: 'Interface', index: -1,
      location: [8, 110], size: [70, 24], onClick: () => { previewFlag = (previewFlag + 9) % 10; conn.sendGuildFlag(previewFlag); render(); } });
    const next = new DXButton({ text: '下一个', fontSize: 8, library: 'Interface', index: -1,
      location: [84, 110], size: [70, 24], onClick: () => { previewFlag = (previewFlag + 1) % 10; conn.sendGuildFlag(previewFlag); render(); } });
    content.addControl(prev, next);
    const COLOURS = [0xFFFFFFFF, 0xFFD93333, 0xFF33BF4D, 0xFF4073E6, 0xFFCCA633];
    let ci = 0;
    const colBtn = new DXButton({ text: '选择颜色', fontSize: 8, library: 'Interface', index: -1,
      location: [230, 85], size: [110, 20], onClick: () => {
        ci = (ci + 1) % COLOURS.length;
        conn.sendGuildColour(COLOURS[ci] | 0);
        scene.addChat(`行会颜色已设为 #${(COLOURS[ci] >>> 0).toString(16)}`, 'hint');
      } });
    content.addControl(colBtn);
    content.addControl(mkText('每次点击旗帜/颜色立即发送设置包', 18, 140, [160, 160, 160, 255], 8));
  }

  // ---- 城堡页 (500-518) ----
  function renderCastle() {
    content.addControl(mkText('城堡管理', 18, 18, [255, 216, 77, 255]));
    content.addControl(mkText('城门与守卫维护', 18, 62, [255, 216, 77, 255]));
    const open = new DXButton({ text: '开/关城门', fontSize: 8, library: 'Interface', index: -1,
      location: [18, 105], size: [110, 26], onClick: () => conn.sendGuildToggleCastleGates() });
    const repG = new DXButton({ text: '修理城门', fontSize: 8, library: 'Interface', index: -1,
      location: [148, 105], size: [110, 26], onClick: () => {
        if (confirm('确认修理城门?')) conn.sendGuildRepairCastleGates();
      } });
    const repU = new DXButton({ text: '修理守卫', fontSize: 8, library: 'Interface', index: -1,
      location: [268, 105], size: [110, 26], onClick: () => {
        if (confirm('确认修理守卫?')) conn.sendGuildRepairCastleGuards();
      } });
    content.addControl(open, repG, repU);
  }

  // 行会邀请弹窗 (S.GuildInvite :232-245)
  conn.addEventListener('guildInvite', (e) => {
    const d = e.detail;
    const overlay = inviteOverlay(`${d.name ?? '未知玩家'} 邀请你加入行会：${d.guildName ?? ''}`,
      (accept) => conn.sendGuildResponse(accept));
    scene.root.appendChild(overlay);
  });
  function inviteOverlay(text, cb) {
    const ov = document.createElement('div');
    ov.style.cssText = 'position:fixed;inset:0;z-index:99996;display:flex;align-items:center;justify-content:center;background:rgba(0,0,0,.35);';
    const box = document.createElement('div');
    box.style.cssText = `width:320px;padding:14px;background:rgba(28,22,10,.97);border:1px solid #8a6d35;color:#ffdb8e;font-family:'Noto Sans CJK SC',sans-serif;`;
    const t = document.createElement('div');
    t.textContent = text;
    t.style.cssText = 'font-size:13px;margin-bottom:12px;';
    const row = document.createElement('div');
    row.style.cssText = 'display:flex;gap:8px;justify-content:flex-end;';
    const mk = (label, val) => {
      const b = document.createElement('button');
      b.textContent = label;
      b.style.cssText = 'padding:6px 16px;cursor:pointer;background:#4a3818;color:#ffdb8e;border:1px solid #8a6d35;font-size:13px;';
      b.onclick = () => { ov.remove(); cb(val); };
      return b;
    };
    row.append(mk('接受', true), mk('拒绝', false));
    box.append(t, row);
    ov.appendChild(box);
    return ov;
  }

  store.on((kind) => { if (kind === 'guild') render(); });
  render();

  reg.wins.set('guild', w);
  return {
    win: w,
    open: () => { render(); WindowManager.open(w, scene.hudLayer); },
    close: () => WindowManager.close(w),
    toggle: () => { if (w.visible) WindowManager.close(w); else { render(); WindowManager.open(w, scene.hudLayer); } },
    render,
  };
}
