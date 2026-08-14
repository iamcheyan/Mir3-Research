// win-party.js — 组队 GroupDialog.cs 移植 (D路 par-win)
// 打开=C.GroupNotify{true} 关闭=false (:33-37); 成员 2 列 (RebuildMembers :177-194);
// 邀请 (C.GroupInvite)/移除 (C.GroupRemove 按名); 允许组队勾选 (C.GroupSwitch 双向);
// 邀请弹窗 (S.GroupInvite → C.GroupResponse); LFG 列表 (S.GroupLFG → C.GroupRequest)。
// 数据: S.GroupMember/GroupRemove/GroupSwitch/GroupLFG/GroupUpdate 事件直连。

import { getWindow } from './uitree.js';
import { WindowManager } from './windows.js';
import { DXControl, DXLabel, DXButton, DXTextInput } from './dx.js';
import { D } from './data.js';

const GROUP_LIMIT = 8;   // Globals.GroupLimit

export async function winParty(scene, store, reg) {
  const w = await getWindow('GroupDialog');
  if (!w) return null;
  const conn = scene.conn;

  const members = new Map();   // objectID → name (S.GroupMember/GroupRemove)
  let lfgList = [];
  let ownLfg = null;
  let allowGroup = scene.info?.allowGroup ?? true;
  let selectedMember = 0;

  // ---- 成员区 (RebuildMembers) ----
  const memberArea = new DXControl({ location: [10, 5], size: [220, 200], isControl: false });
  w.addControl(memberArea);
  function rebuildMembers() {
    memberArea.el.replaceChildren();
    let i = 0;
    for (const [id, name] of members) {
      if (i >= GROUP_LIMIT) break;
      const l = new DXLabel({
        text: name, fontSize: 9,
        textColour: id === selectedMember ? [180, 255, 160, 255] : [255, 255, 255, 255],
        drawOutline: true, location: [10 + (i % 2) * 100, 5 + Math.floor(i / 2) * 20],
        size: [95, 20], isControl: true,
      });
      l.el.style.cursor = 'pointer';
      l.el.addEventListener('click', () => { selectedMember = id; rebuildMembers(); });
      memberArea.addControl(l);
      i++;
    }
    if (!members.size) memberArea.addControl(new DXLabel({
      text: '(未组队)', fontSize: 9, textColour: [160, 160, 160, 255],
      location: [10, 5], size: [150, 20], isControl: false }));
  }

  // ---- 邀请输入 (Add 按钮 :71-73) ----
  const inviteRow = new DXControl({ location: [10, 175], size: [220, 26], isControl: false, visible: false });
  w.addControl(inviteRow);
  const inviteInput = new DXTextInput({ location: [0, 0], size: [130, 24], fontSize: 9 });
  inviteRow.addControl(inviteInput);
  const inviteBtn = new DXButton({ text: '邀请', fontSize: 8, library: 'Interface', index: -1,
    location: [135, 0], size: [60, 24], onClick: () => {
      const n = inviteInput.text.trim();
      if (n) { conn.sendGroupInvite(n); inviteInput.text = ''; inviteRow.visible = false; }
    } });
  inviteRow.addControl(inviteBtn);

  // ---- 按钮行 y=217 ----
  const btnAdd = new DXButton({ text: '添加', fontSize: 8, library: 'Interface', index: -1,
    location: [10, 217], size: [52, 26],
    onClick: () => { inviteRow.visible = !inviteRow.visible; } });
  const btnRemove = new DXButton({ text: '移除', fontSize: 8, library: 'Interface', index: -1,
    location: [66, 217], size: [52, 26], onClick: () => {
      if (selectedMember && members.has(selectedMember)) {
        conn.sendGroupRemove(members.get(selectedMember));   // C.GroupRemove 按名
        members.delete(selectedMember);
        selectedMember = 0;
        rebuildMembers();
      }
    } });
  const btnLfg = new DXButton({ text: '招募', fontSize: 8, library: 'Interface', index: -1,
    location: [122, 217], size: [52, 26], onClick: openLfgEditor });
  w.addControl(btnAdd, btnRemove, btnLfg);

  // ---- 允许组队勾选 (ToggleAllow :152-157) ----
  const allowBtn = new DXButton({
    text: `允许组队: ${allowGroup ? '开' : '关'}`, fontSize: 8,
    library: 'Interface', index: -1, location: [166, 40], size: [64, 22],
    textColour: allowGroup ? [180, 255, 160, 255] : [255, 160, 160, 255],
    onClick: () => conn.sendGroupSwitch(!allowGroup),   // 服务端 echo S.GroupSwitch 同步
  });
  w.addControl(allowBtn);

  // ---- LFG 列表 (5 行 :93-100) ----
  const lfgHeader = new DXLabel({ text: '寻找队伍', fontSize: 9, textColour: [255, 216, 77, 255],
    drawOutline: true, location: [10, 255], size: [200, 18], isControl: false });
  w.addControl(lfgHeader);
  const lfgRows = [];
  for (let i = 0; i < 5; i++) {
    const l = new DXLabel({ text: '', fontSize: 8, textColour: [255, 255, 255, 255],
      drawOutline: true, location: [10, 293 + i * 21], size: [194, 19], isControl: true });
    l.el.style.cursor = 'pointer';
    l.visible = false;
    w.addControl(l);
    lfgRows.push(l);
  }
  function rebuildLfg() {
    const list = lfgList.filter(e => e?.enabled).sort((a, b) => (a.groupName ?? '').localeCompare(b.groupName ?? ''));
    lfgRows.forEach((l, i) => {
      const e = list[i];
      if (!e) { l.visible = false; return; }
      l.visible = true;
      const cur = (e.memberInfo ?? []).length;
      l.text = `${(e.groupName ?? '').slice(0, 10)} [${cur}/${e.maxCount}] ${e.groupType ?? ''}`;
      l.textColour = e.enabled ? [140, 255, 140, 255] : [255, 255, 255, 255];
      l.el.onclick = () => {
        // RequestLfg (:213-217): 有队伍/自己开招募时不可申请
        if (members.size > 0) { scene.addChat('你已在队伍中', 'hint'); return; }
        if (!allowGroup) { scene.addChat('请先开启允许组队', 'hint'); return; }
        conn.sendGroupRequest(e.leaderName);
      };
    });
  }

  // ---- LFG 编辑器 (GroupLfgInputDialog) ----
  function openLfgEditor() {
    const own = ownLfg ?? lfgList.find(e => e.leaderName === scene.info?.name) ?? null;
    const ov = document.createElement('div');
    ov.style.cssText = 'position:fixed;inset:0;z-index:99996;display:flex;align-items:center;justify-content:center;background:rgba(0,0,0,.35);';
    const box = document.createElement('div');
    box.style.cssText = `width:318px;padding:14px;background:rgba(28,22,10,.97);border:1px solid #8a6d35;color:#ffdb8e;font-family:'Noto Sans CJK SC',sans-serif;`;
    const mkRow = (label) => {
      const r = document.createElement('div');
      r.style.cssText = 'margin-bottom:10px;';
      const l = document.createElement('div');
      l.textContent = label;
      l.style.cssText = 'font-size:12px;margin-bottom:4px;';
      r.appendChild(l);
      return r;
    };
    const nameRow = mkRow('队伍名称');
    const nameI = document.createElement('input');
    nameI.value = own?.groupName ?? '';
    nameI.style.cssText = 'width:100%;padding:4px 6px;background:#000;border:1px solid #8a6d35;color:#ffdb8e;';
    nameRow.appendChild(nameI);
    const typeRow = mkRow('类型');
    const typeB = document.createElement('button');
    let pvp = own?.groupType === 'PvP';
    const syncType = () => typeB.textContent = pvp ? 'PvP' : 'PvE';
    syncType();
    typeB.onclick = () => { pvp = !pvp; syncType(); };
    typeB.style.cssText = 'padding:4px 20px;cursor:pointer;background:#4a3818;color:#ffdb8e;border:1px solid #8a6d35;';
    typeRow.appendChild(typeB);
    const cntRow = mkRow('最大人数 (2-8)');
    const cntI = document.createElement('input');
    cntI.type = 'number'; cntI.min = '2'; cntI.max = String(GROUP_LIMIT);
    cntI.value = String(own?.maxCount ?? 4);
    cntI.style.cssText = 'width:80px;padding:4px 6px;background:#000;border:1px solid #8a6d35;color:#ffdb8e;';
    cntRow.appendChild(cntI);
    const btns = document.createElement('div');
    btns.style.cssText = 'display:flex;gap:8px;justify-content:flex-end;';
    const mkB = (t, fn) => {
      const b = document.createElement('button');
      b.textContent = t;
      b.style.cssText = 'padding:6px 14px;cursor:pointer;background:#4a3818;color:#ffdb8e;border:1px solid #8a6d35;font-size:13px;';
      b.onclick = fn;
      return b;
    };
    const send = (enabled) => {
      const n = nameI.value.trim() || scene.info?.name || '';
      const c = Math.max(1, Math.min(GROUP_LIMIT, parseInt(cntI.value, 10) || 4));
      conn.sendGroupLFGUpdate(enabled, n, pvp ? 'PvP' : 'PvE', c);
      ov.remove();
    };
    btns.append(
      mkB('开启', () => send(true)),
      mkB('关闭', () => send(false)),
      mkB('取消', () => ov.remove()));
    box.append(nameRow, typeRow, cntRow, btns);
    ov.appendChild(box);
    scene.root.appendChild(ov);
  }

  // ---- 事件 (GameScene :2549-2563) ----
  conn.addEventListener('groupMember', (e) => { members.set(e.detail.objectID, e.detail.name); rebuildMembers(); });
  conn.addEventListener('groupRemove', (e) => {
    if (e.detail.objectID === scene.world?.player?.objectID) members.clear();
    else members.delete(e.detail.objectID);
    rebuildMembers();
  });
  conn.addEventListener('groupSwitch', (e) => {
    allowGroup = e.detail.allow;
    allowBtn.text = `允许组队: ${allowGroup ? '开' : '关'}`;
    allowBtn.textColour = allowGroup ? [180, 255, 160, 255] : [255, 160, 160, 255];
  });
  conn.addEventListener('groupLFG', (e) => { lfgList = e.detail.list ?? []; rebuildLfg(); });
  conn.addEventListener('groupUpdate', (e) => {
    const g = e.detail.group;
    if (!g) return;
    const i = lfgList.findIndex(x => x.leaderName === g.leaderName);
    if (i >= 0) lfgList[i] = g; else lfgList.push(g);
    ownLfg = g.leaderName === scene.info?.name ? g : ownLfg;
    rebuildLfg();
  });
  conn.addEventListener('groupRequest', (e) => {
    const d = e.detail;
    scene.addChat(`${d.name} (Lv.${d.level}) 请求加入队伍`, 'hint');
  });
  conn.addEventListener('groupInvite', (e) => {
    const d = e.detail;
    const ov = document.createElement('div');
    ov.style.cssText = 'position:fixed;inset:0;z-index:99996;display:flex;align-items:center;justify-content:center;background:rgba(0,0,0,.35);';
    const box = document.createElement('div');
    box.style.cssText = `width:300px;padding:14px;background:rgba(28,22,10,.97);border:1px solid #8a6d35;color:#ffdb8e;font-family:'Noto Sans CJK SC',sans-serif;`;
    const t = document.createElement('div');
    t.textContent = `${d.name ?? '未知玩家'} 邀请你组队`;
    t.style.cssText = 'font-size:13px;margin-bottom:12px;';
    const row = document.createElement('div');
    row.style.cssText = 'display:flex;gap:8px;justify-content:flex-end;';
    const mk = (label, accept) => {
      const b = document.createElement('button');
      b.textContent = label;
      b.style.cssText = 'padding:6px 16px;cursor:pointer;background:#4a3818;color:#ffdb8e;border:1px solid #8a6d35;font-size:13px;';
      b.onclick = () => { ov.remove(); conn.sendGroupResponse(d.name, accept); };
      return b;
    };
    row.append(mk('接受', true), mk('拒绝', false));
    box.append(t, row);
    ov.appendChild(box);
    scene.root.appendChild(ov);
  });

  rebuildMembers();
  rebuildLfg();
  void D; void store;

  reg.wins.set('party', w);
  return {
    win: w,
    open: () => { rebuildMembers(); WindowManager.open(w, scene.hudLayer); },
    close: () => WindowManager.close(w),
    toggle: () => {
      if (w.visible) WindowManager.close(w);
      else { rebuildMembers(); WindowManager.open(w, scene.hudLayer); }
    },
    // 开/关窗副作用 (GameScene OpenGroupDialog :625 / GroupDialog Close override :33-37)
    onShow: () => conn.sendGroupNotify(true),
    onHide: () => conn.sendGroupNotify(false),
  };
}
