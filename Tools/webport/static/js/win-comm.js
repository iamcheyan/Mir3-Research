// win-comm.js — CommunicationDialog (通信, CommunicationDialog.cs) 4 页全量
// 页 0 好友 (状态切换/过滤器/增删) · 页 1 收件 (列表/详情/取附件/回复/删除/批量)
// 页 2 写信 (收件人正则校验/金币 2e9 钳制/5 附件格/发送锁生命周期) · 页 3 屏蔽
// 对照: 构造 :44-99 / ShowPage :342-380 / RebuildReceived :579-598 / OpenMail :599-682
//       BuildSendPage :684-726 / PrepareMailSend :398-416 / ItemsChanged :418-436
import { DXControl, DXLabel, DXButton, DXTextInput } from './dx.js';
import { DXWindow, WindowManager } from './windows.js';
import { GRID } from './net.js';
import { GameDB } from './gamedb.js';

const ROW_CSS = 'padding:2px 6px;font:12px/1.8 \'Noto Sans CJK SC\',sans-serif;color:#eee;text-shadow:1px 1px 0 #000;cursor:pointer;';
const SEL_CSS = 'background:rgba(120,180,255,.25);';
const BOX_CSS = 'position:absolute;left:50%;top:50%;transform:translate(-50%,-50%);background:rgba(20,24,40,.97);border:1px solid #6bf;padding:10px 12px;min-width:240px;font:12px/1.7 \'Noto Sans CJK SC\',sans-serif;color:#eee;z-index:2;';
const BTN_CSS = 'margin:4px 6px 0 0;padding:3px 14px;background:#2a4;border:1px solid #7d7;cursor:pointer;';
const BTN_OFF_CSS = BTN_CSS.replace('#2a4', '#444').replace('#7d7', '#888');
const INPUT_CSS = 'background:#111;color:#fff;border:1px solid #567;padding:2px 4px;';
const INPUT_GREEN = '#2e6';   // _inputGreen :753
const INPUT_RED = '#f44';     // _inputRed :754

const ONLINE_STATE = ['在线', '离开', '忙碌', '离线'];   // OnlineState enum 0-3
const STATE_COLOR = ['#7c7', '#f80', '#f44', '#999'];   // RefreshOwnState :538-548
const ITEM_NAME = async (idx) => {
  const info = await GameDB.itemInfo(idx);
  return info?.ItemName ?? `物品#${idx}`;
};
// CharacterReg 等价: 非空 + 禁空白
const NAME_OK = (t) => /^[^\s]+$/.test(t ?? '');
// GoldBoxValid :762 (0 ≤ v ≤ 2e9 且 ≤ 余额)
const GOLD_OK = (t, avail) => { const v = Number(t); return Number.isFinite(v) && v >= 0 && v <= 2_000_000_000 && v <= avail; };
const CLAMP_GOLD = (t) => { const v = Number(t); return Number.isFinite(v) && v > 2_000_000_000 ? '2000000000' : t; };   // ClampGoldInput :758

let shared = null;   // 单例 (GameScene _communicationDialog 语义)

export async function winComm(scene, itemStore, reg) {
  if (shared) { WindowManager.open(shared.win, scene.hudLayer); return shared; }
  const conn = scene.conn;
  const store = itemStore ?? scene.itemStore;   // registry install 传 (scene, store, reg)
  const win = new DXWindow({ title: '通信', size: [296, 424] });
  const body = new DXControl({ location: [0, 60], size: [296, 316], clip: true, isControl: false });
  win.addControl(body);

  let page = 0;
  let selectedFriend = -1;
  let selectedBlock = -1;
  let friendFilter = 0;   // 0 全部 / 1 在线 / 2 离线 (FriendFilterText :527)
  const pendingMailItemGets = new Set();   // (mailIndex, slot) 去重 (:68)
  let pendingMailLinks = [];   // _pendingMailLinks (发送锁 :398)
  let mailSending = false;
  let openMailIndex = -1;   // 详情态 (page1 内)

  // ---- 页签 (:61-64) ----
  const tabs = [];
  const mkTab = (text, p) => {
    const b = new DXButton({ text, fontSize: 9, library: 'Interface', index: -1,
      location: [10 + tabs.length * 61, 37], size: [60, 21], onClick: () => showPage(p) });
    tabs.push(b); win.addControl(b);
  };
  mkTab('好友', 0); mkTab('收件', 1); mkTab('写信', 2); mkTab('屏蔽', 3);

  // ---- 底部动作钮区 (CreateActionButtons :111-180) ----
  const actions = new DXControl({ location: [0, 380], size: [296, 30], isControl: false });
  win.addControl(actions);
  const mkAct = (text, x, w, fn) => {
    const b = new DXButton({ text, fontSize: 9, library: 'Interface', index: -1,
      location: [x, 0], size: [w, 25], onClick: () => { if (b.enabled) fn(); } });
    b.enabled = false;
    actions.addControl(b);
    return b;
  };
  const btnFriendAdd = mkAct('添加好友', 43, 100, addFriendFlow);
  const btnFriendRemove = mkAct('删除好友', 153, 100, () => { if (selectedFriend >= 0) conn.sendFriendRemove(selectedFriend); });
  const btnCollectAll = mkAct('全部收取', 15, 80, collectAll);
  const btnDeleteAll = mkAct('全部删除', 105, 80, deleteAll);
  const btnNewMail = mkAct('写新邮件', 195, 80, () => showPage(2));
  btnFriendAdd.enabled = true;
  btnNewMail.enabled = true;
  const btnBlockAdd = mkAct('添加', 43, 100, addBlockFlow);
  const btnBlockRemove = mkAct('删除', 153, 100, () => { if (selectedBlock >= 0) conn.sendBlockRemove(selectedBlock); });
  btnBlockAdd.enabled = true;

  function setActionVisibility() {   // SetActionVisibility :185-194
    btnFriendAdd.visible = btnFriendRemove.visible = page === 0 && openMailIndex < 0;
    btnCollectAll.visible = btnDeleteAll.visible = btnNewMail.visible = page === 1 && openMailIndex < 0;
    btnBlockAdd.visible = btnBlockRemove.visible = page === 3 && openMailIndex < 0;
  }

  // ---- S 监听 (SetMails/SetFriends/ApplyFriend/RemoveFriend/AddMail/RemoveMail/RemoveMailItem :209-262) ----
  conn.addEventListener('mailList', () => { pendingMailItemGets.clear(); if (page === 1 && openMailIndex < 0) render(); });   // SetMails :216
  conn.addEventListener('mailNew', () => { if (page === 1) render(); });
  conn.addEventListener('mailDelete', () => { if (page === 1) render(); });
  conn.addEventListener('mailItemDelete', (e) => {   // RemoveMailItem :257-262: 删附件行+hasItem 复算
    const { index, slot } = e.detail ?? {};
    pendingMailItemGets.delete(`${index}:${slot}`);
    const mail = store.mails.find(x => x.index === index);
    if (mail) {
      mail.items = (mail.items ?? []).filter(x => x && x.slot !== slot);
      mail.hasItem = mail.items.length > 0;
    }
    if (page === 1 && openMailIndex === index) render();
  });

  // 好友/屏蔽 S 事件 → 对应页重绘 (ApplyFriend :232 / RemoveFriend :240 / SetBlocks :517)
  conn.addEventListener('friendAdd', () => { if (page === 0) render(); });
  conn.addEventListener('friendUpdate', () => { if (page === 0) render(); });
  conn.addEventListener('friendRemove', () => { if (page === 0) { selectedFriend = -1; btnFriendRemove.enabled = false; render(); } });
  conn.addEventListener('blockAdd', () => { if (page === 3) render(); });
  conn.addEventListener('blockRemove', () => { if (page === 3) { selectedBlock = -1; btnBlockRemove.enabled = false; render(); } });

  // ---- 页渲染 ----
  function showPage(p) {
    page = p; openMailIndex = -1;
    render();
  }
  async function render() {
    setActionVisibility();
    body.el.replaceChildren();
    if (page === 0) await renderFriends();
    else if (page === 1) { openMailIndex >= 0 ? await renderMailDetail() : await renderReceived(); }
    else if (page === 2) await renderSend();
    else await renderBlocks();
  }

  // ==== 页 0: 好友 (BuildFriendsPage :473-487 / RebuildFriends :550-577) ====
  let friendInputEl = null;
  function addFriendFlow() {   // :115-133: 首点弹输入框, 再点提交
    if (!friendInputEl) {
      friendInputEl = document.createElement('input');
      friendInputEl.type = 'text';
      friendInputEl.style.cssText = INPUT_CSS + 'position:absolute;left:151px;top:10px;width:122px;height:18px;display:none;';
      friendInputEl.placeholder = '输入名字回车';
      friendInputEl.onkeydown = (ev) => {
        if (ev.key === 'Enter' && NAME_OK(friendInputEl.value)) { conn.sendFriendAdd(friendInputEl.value.trim()); friendInputEl.remove(); friendInputEl = null; }
        if (ev.key === 'Escape') { friendInputEl.remove(); friendInputEl = null; }
      };
      body.el.appendChild(friendInputEl);
      friendInputEl.style.display = '';
      friendInputEl.focus();
      return;
    }
    if (NAME_OK(friendInputEl.value)) { conn.sendFriendAdd(friendInputEl.value.trim()); friendInputEl.remove(); friendInputEl = null; }
  }
  async function renderFriends() {
    const mk = (text, css, x, y) => { const d = document.createElement('div'); d.textContent = text; d.style.cssText = `position:absolute;left:${x}px;top:${y}px;font:12px 'Noto Sans CJK SC',sans-serif;` + css; body.el.appendChild(d); return d; };
    mk('在线状态', 'color:#fff;', 25, 12);
    // 自己的状态钮 (RefreshOwnState :538 + CycleOnlineState GameScene.cs:6430 Online→Busy→Away 循环)
    const ownState = store.info?.onlineState ?? 0;
    const stateBtn = new DXButton({ text: ONLINE_STATE[ownState], fontSize: 9, library: 'Interface', index: -1,
      location: [151, 10], size: [122, 18], onClick: () => {
        const next = ownState === 0 ? 2 : ownState === 2 ? 1 : 0;   // Online→Busy→Away (GameScene.cs:6432)
        conn.sendChangeOnlineState(next);
        store.info.onlineState = next;
        render();
      } });
    stateBtn.el.style.color = STATE_COLOR[ownState];
    body.addControl(stateBtn);
    mk('查看状态', 'color:#fff;', 25, 33);
    const filterLabels = ['全部好友', '仅在线', '仅离线'];   // FriendFilterText :527
    const filterBtn = new DXButton({ text: filterLabels[friendFilter], fontSize: 9, library: 'Interface', index: -1,
      location: [151, 31], size: [122, 18], onClick: () => { friendFilter = (friendFilter + 1) % 3; render(); } });   // :484
    body.addControl(filterBtn);
    // 好友列表 (排序: State→Name :230)
    const list = document.createElement('div');
    list.style.cssText = 'position:absolute;left:12px;top:65px;width:260px;bottom:0;overflow-y:auto;';
    body.el.appendChild(list);
    const friends = [...(store.friends ?? [])]
      .filter(f => friendFilter === 0 || (friendFilter === 1 ? f.state !== 3 : f.state === 3))
      .sort((a, b) => (a.state ?? 0) - (b.state ?? 0) || (a.name ?? '').localeCompare(b.name ?? ''));
    if (!friends.length) { const d = document.createElement('div'); d.textContent = '暂无好友'; d.style.cssText = ROW_CSS + 'cursor:default;color:#ccc;'; list.appendChild(d); }
    for (const f of friends) {
      const d = document.createElement('div');
      d.textContent = `${f.name}  [${ONLINE_STATE[f.state] ?? '离线'}]`;
      d.style.cssText = ROW_CSS + (f.state === 3 ? 'color:#999;' : '') + (selectedFriend === f.index ? SEL_CSS : '');
      d.onclick = () => { selectedFriend = f.index; btnFriendRemove.enabled = true; render(); };   // :567 选中→删除钮启用
      d.oncontextmenu = (ev) => { ev.preventDefault(); conn.sendFriendRemove(f.index); };   // :570 右键直删
      list.appendChild(d);
    }
  }

  // ==== 页 1: 收件 (RebuildReceived :579-598) ====
  async function renderReceived() {
    const hdr = (t, x, w) => { const d = document.createElement('div'); d.textContent = t; d.style.cssText = `position:absolute;left:${x}px;top:5px;width:${w}px;font:11px 'Noto Sans CJK SC',sans-serif;color:#ffd573;`; body.el.appendChild(d); };
    hdr('类别', 15, 50); hdr('标题', 65, 140); hdr('日期', 200, 65);
    const list = document.createElement('div');
    list.style.cssText = 'position:absolute;left:15px;top:26px;right:0;bottom:0;overflow-y:auto;';
    body.el.appendChild(list);
    const mails = [...(store.mails ?? [])].sort((a, b) => Number(b.date ?? 0) - Number(a.date ?? 0));   // SetMails :216 按 Date 降序 (comparator 必须 number)
    if (!mails.length) { const d = document.createElement('div'); d.textContent = '（邮箱为空）'; d.style.cssText = ROW_CSS + 'cursor:default;color:#aaa;'; list.appendChild(d); }
    for (const m of mails) {
      const d = document.createElement('div');
      const cat = m.hasItem ? '物品' : m.gold > 0 ? '金币' : '';
      const date = m.date ? new Date(Number(m.date) / 10000 - 62135596800000) : null;   // Date ticks BigInt → Number
      const ds = date ? `${String(date.getMonth() + 1).padStart(2, '0')}/${String(date.getDate()).padStart(2, '0')}` : '';
      d.textContent = `${cat.padEnd(2, '　')}${m.opened ? '' : '● '}${m.subject ?? ''}  ${ds}`;
      d.style.cssText = ROW_CSS + (m.opened ? '' : 'color:#ffd54f;');   // :590 未读金色
      d.onclick = () => openMail(m.index);
      list.appendChild(d);
    }
  }
  async function openMail(index) {   // OpenMail :599
    const mail = store.mails.find(x => x.index === index);
    if (!mail) return;
    if (!mail.opened) {   // ShouldSendMailOpened :683 — 已读不重发
      mail.opened = true;
      conn.sendMailOpened(index);
    }
    openMailIndex = index;
    setActionVisibility();
    await renderMailDetail();
  }
  async function renderMailDetail() {
    const mail = store.mails.find(x => x.index === openMailIndex);
    if (!mail) { openMailIndex = -1; return render(); }
    const mk = (t, y) => { const d = document.createElement('div'); d.textContent = t; d.style.cssText = `position:absolute;left:15px;top:${y}px;font:12px 'Noto Sans CJK SC',sans-serif;color:#eee;`; body.el.appendChild(d); };
    mk(`发件人: ${mail.sender ?? '?'}`, 8);   // :609
    mk(`主题: ${mail.subject ?? ''}`, 27);
    mk(`日期: ${mail.date ? new Date(Number(mail.date) / 10000 - 62135596800000).toLocaleString() : ''}`, 46);
    const detail = document.createElement('div');   // _detail (:612)
    detail.textContent = `${mail.message ?? ''}${mail.gold > 0 ? `\n\n附金币: ${Number(mail.gold).toLocaleString()}` : ''}`;
    detail.style.cssText = 'position:absolute;left:15px;top:73px;width:241px;height:167px;overflow-y:auto;font:12px/1.6 \'Noto Sans CJK SC\',sans-serif;color:#ddd;white-space:pre-wrap;background:rgba(0,0,0,.25);padding:4px;';
    body.el.appendChild(detail);
    // 7 只读附件格 (:615-626: 点击取物, pendingMailItemGets 去重)
    const grid = document.createElement('div');
    grid.style.cssText = 'position:absolute;left:13px;top:265px;display:flex;gap:3px;';
    body.el.appendChild(grid);
    for (let s = 0; s < 7; s++) {
      const item = (mail.items ?? []).find(x => x && x.slot === s);
      const cell = document.createElement('div');
      const nm = item ? await ITEM_NAME(item.infoIndex) : '';
      cell.textContent = nm;
      cell.title = item ? `${nm} x${item.count ?? 1} (点击收取)` : '';
      cell.style.cssText = `width:31px;height:31px;display:flex;align-items:center;justify-content:center;font:9px 'Noto Sans CJK SC',sans-serif;color:${item ? '#ffd573' : '#555'};background:rgba(0,0,0,.4);border:1px solid #456;cursor:${item ? 'pointer' : 'default'};overflow:hidden;`;
      if (item) cell.onclick = () => {   // CanGetMailItem :684 + 去重 :630
        if (pendingMailItemGets.has(`${mail.index}:${s}`)) return;
        pendingMailItemGets.add(`${mail.index}:${s}`);
        conn.sendMailGetItem(mail.index, s);
      };
      grid.appendChild(cell);
    }
    // 返回/回复/删除 (:636-681)
    const back = new DXButton({ text: '返回', fontSize: 9, library: 'Interface', index: -1,
      location: [8, 229], size: [65, 25], onClick: () => { openMailIndex = -1; render(); } });
    body.addControl(back);
    const reply = new DXButton({ text: '回复', fontSize: 9, library: 'Interface', index: -1,
      location: [43, 4], size: [100, 25], onClick: () => {   // ReplyMail :666-671
        showPage(2);
        replyTo = { recipient: mail.sender, subject: (mail.subject ?? '').startsWith('RE: ') ? mail.subject : `RE: ${mail.subject ?? ''}` };
        render();
      } });
    body.addControl(reply);
    const del = new DXButton({ text: '删除', fontSize: 9, library: 'Interface', index: -1,
      location: [153, 4], size: [100, 25], onClick: () => {   // DeleteMail :673-680
        if ((mail.items ?? []).length > 0) { scene.addChat('无法删除含物品的邮件', 'system'); return; }
        conn.sendMailDelete(mail.index);
        openMailIndex = -1;
        render();
      } });
    body.addControl(del);
  }
  function collectAll() {   // :143-157: 最多 15 封, 逐附件去重请求
    for (const mail of (store.mails ?? []).filter(x => (x.items ?? []).length > 0).slice(0, 15)) {
      if (!mail.opened) { mail.opened = true; conn.sendMailOpened(mail.index); }
      for (const item of mail.items) {
        if (item && !pendingMailItemGets.has(`${mail.index}:${item.slot}`)) {
          pendingMailItemGets.add(`${mail.index}:${item.slot}`);
          conn.sendMailGetItem(mail.index, item.slot);
        }
      }
    }
    render();
  }
  function deleteAll() {   // :158-170: 仅无附件邮件, 最多 15 封, 等 S 回包删行
    for (const mail of (store.mails ?? []).filter(x => (x.items ?? []).length === 0).slice(0, 15)) {
      conn.sendMailDelete(mail.index);
    }
    render();
  }

  // ==== 页 2: 写信 (BuildSendPage :684-726) ====
  let replyTo = null;
  async function renderSend() {
    const mkLbl = (t, y) => { const d = document.createElement('div'); d.textContent = t; d.style.cssText = `position:absolute;left:8px;top:${y}px;font:12px 'Noto Sans CJK SC',sans-serif;color:#ffd573;`; body.el.appendChild(d); };
    mkLbl('收件人:', 11);
    const recipient = document.createElement('input');   // _recipient (:687-689 正则校验+边框色)
    recipient.type = 'text';
    recipient.value = replyTo?.recipient ?? '';
    recipient.style.cssText = INPUT_CSS + 'position:absolute;left:86px;top:11px;width:115px;height:18px;';
    body.el.appendChild(recipient);
    mkLbl('主题:', 30);
    const subject = document.createElement('input');
    subject.type = 'text';
    subject.value = replyTo?.subject ?? '';
    subject.maxLength = 30;   // :692
    subject.style.cssText = INPUT_CSS + 'position:absolute;left:86px;top:30px;width:155px;height:18px;';
    body.el.appendChild(subject);
    mkLbl('正文:', 55);
    const message = document.createElement('textarea');   // _message (:694 MaxLength 300)
    message.maxLength = 300;
    message.style.cssText = INPUT_CSS + 'position:absolute;left:15px;top:75px;width:241px;height:165px;resize:none;font:12px/1.5 \'Noto Sans CJK SC\',sans-serif;';
    body.el.appendChild(message);
    mkLbl('附件 (点击背包物品加入):', 246);
    // 5 附件格 (DXItemCell linked — web 等价: 列表点击加入; _sendMailCells :703-711)
    const links = [];   // CellLinkInfo[] (展示用)
    const grid = document.createElement('div');
    grid.style.cssText = 'position:absolute;left:13px;top:265px;display:flex;gap:4px;align-items:flex-start;';
    body.el.appendChild(grid);
    const cells = [];
    for (let i = 0; i < 5; i++) {
      const cell = document.createElement('div');
      cell.style.cssText = 'width:31px;height:31px;display:flex;align-items:center;justify-content:center;font:9px \'Noto Sans CJK SC\',sans-serif;color:#555;background:rgba(0,0,0,.4);border:1px solid #456;overflow:hidden;';
      cell.textContent = '';
      cell.onclick = () => {   // 点击附件格 = 移除 (linked unlink)
        if (!links[i]) return;
        store.unlockPublic(links[i].gridType, links[i].slot);
        links[i] = null;
        cell.textContent = '';
        cell.title = '';
      };
      cells.push(cell);
      grid.appendChild(cell);
    }
    // 背包物品选择 (linked grid 拖入的 web 等价)
    const pick = document.createElement('div');
    pick.style.cssText = 'position:absolute;left:180px;top:262px;width:110px;height:64px;overflow-y:auto;border:1px solid #345;background:rgba(0,0,0,.3);';
    body.el.appendChild(pick);
    const renderPick = async () => {
      pick.replaceChildren();
      const inv = [...store.items(GRID.INVENTORY).entries()].filter(([, it]) => it).sort((a, b) => a[0] - b[0]);
      for (const [slot, it] of inv) {
        const nm = await ITEM_NAME(it.infoIndex);
        const d = document.createElement('div');
        d.textContent = `· ${nm}`;
        d.style.cssText = ROW_CSS + 'font-size:10px;padding:0 3px;';
        d.onclick = () => {   // 拖入附件格 = lock + link
          const free = links.findIndex(x => !x);
          if (free < 0) return;
          if (links.some(l => l && l.slot === slot)) return;
          links[free] = { gridType: GRID.INVENTORY, slot, count: it.count ?? 1 };
          store.lock(GRID.INVENTORY, slot);
          cells[free].textContent = nm;
          cells[free].title = `${nm} x${it.count ?? 1} (点击移除)`;
        };
        pick.appendChild(d);
      }
    };
    await renderPick();
    mkLbl('金币:', 304);
    const gold = document.createElement('input');   // :713-717 (2e9 钳制 + 边框色)
    gold.type = 'text';
    gold.value = '0';
    gold.style.cssText = INPUT_CSS + 'position:absolute;left:86px;top:303px;width:122px;height:18px;';
    body.el.appendChild(gold);
    // 发送钮 (:718-726)
    const sendBtn = new DXButton({ text: '发送', fontSize: 9, library: 'Interface', index: -1,
      location: [113, 3], size: [70, 25], onClick: () => {
        if (mailSending) return;   // :721
        const amount = Number(gold.value);
        const avail = Number(store.gold());
        if (!NAME_OK(recipient.value) || !GOLD_OK(gold.value, avail) || !Number.isFinite(amount)) return;   // IsMailSendValid :728-734
        // PrepareMailSend :398-416 — pending 锁 + 清格
        if (pendingMailLinks.length) return;
        pendingMailLinks = links.filter(Boolean).map(l => ({ ...l }));
        for (const l of pendingMailLinks) store.lock(l.gridType, l.slot);
        const sent = links.filter(Boolean);
        for (let i = 0; i < 5; i++) { links[i] = null; cells[i].textContent = ''; cells[i].title = ''; }
        mailSending = true;
        conn.sendMailSend(sent, recipient.value.trim(), subject.value.trim(), message.value, amount);
      } });
    sendBtn.enabled = false;
    body.addControl(sendBtn);
    const refreshSendState = () => {   // UpdateSendState :736-739
      const avail = Number(store.gold());
      recipient.style.borderColor = recipient.value === '' ? '#567' : NAME_OK(recipient.value) ? INPUT_GREEN : INPUT_RED;
      gold.value = CLAMP_GOLD(gold.value);   // ClampGoldInput :758
      gold.style.borderColor = gold.value === '0' ? '#567' : GOLD_OK(gold.value, avail) ? INPUT_GREEN : INPUT_RED;   // GoldBorderColour :766
      sendBtn.enabled = !mailSending && NAME_OK(recipient.value) && GOLD_OK(gold.value, avail);
    };
    recipient.oninput = refreshSendState;
    gold.oninput = refreshSendState;
    refreshSendState();
    replyTo = null;
    return { clear() { recipient.value = ''; subject.value = ''; message.value = ''; gold.value = '0'; refreshSendState(); } };
  }
  // 发送生命周期 (ItemsChanged :418-436): 成功清表单, 失败保留; 解锁 pending
  conn.addEventListener('itemsChanged', (e) => {
    if (!pendingMailLinks.length) return;
    const changed = e.detail?.links ?? [];
    for (const link of changed) {
      pendingMailLinks = pendingMailLinks.filter(p => !(p.gridType === link.gridType && p.slot === link.slot));
      store.unlockPublic(link.gridType, link.slot);
    }
    if (!pendingMailLinks.length) {
      if (e.detail?.success && page === 2) {
        // 成功: 清表单 (:425-431) — 借重渲染置空
        replyTo = null;
        render();
      }
      mailSending = false;
    }
  });
  // 断线回滚 (CancelPendingMailLinks :438-443)
  conn.addEventListener('close', () => {
    for (const l of pendingMailLinks) store.unlockPublic(l.gridType, l.slot);
    pendingMailLinks = [];
    mailSending = false;
  });

  // ==== 页 3: 屏蔽 (BuildBlockPage :489-515) ====
  let blockInputEl = null;
  function addBlockFlow() {   // :496-503
    if (!blockInputEl) {
      blockInputEl = document.createElement('input');
      blockInputEl.type = 'text';
      blockInputEl.style.cssText = INPUT_CSS + 'position:absolute;left:151px;top:10px;width:122px;height:18px;';
      blockInputEl.placeholder = '输入名字回车';
      blockInputEl.onkeydown = (ev) => {
        if (ev.key === 'Enter' && NAME_OK(blockInputEl.value)) { conn.sendBlockAdd(blockInputEl.value.trim()); blockInputEl.remove(); blockInputEl = null; }
        if (ev.key === 'Escape') { blockInputEl.remove(); blockInputEl = null; }
      };
      body.el.appendChild(blockInputEl);
      blockInputEl.focus();
    }
  }
  async function renderBlocks() {
    const mkLbl = (t, y) => { const d = document.createElement('div'); d.textContent = t; d.style.cssText = `position:absolute;left:8px;top:${y}px;font:12px 'Noto Sans CJK SC',sans-serif;color:#ffd573;`; body.el.appendChild(d); };
    mkLbl('屏蔽列表', 5);
    const list = document.createElement('div');
    list.style.cssText = 'position:absolute;left:12px;top:35px;width:240px;bottom:0;overflow-y:auto;';
    body.el.appendChild(list);
    const blocks = store.blocks ?? [];
    if (!blocks.length) { const d = document.createElement('div'); d.textContent = '（无屏蔽名单）'; d.style.cssText = ROW_CSS + 'cursor:default;color:#aaa;'; list.appendChild(d); }
    for (const b of blocks) {
      const d = document.createElement('div');
      d.textContent = b.name ?? '?';
      d.style.cssText = ROW_CSS + (selectedBlock === b.index ? SEL_CSS : '');
      d.onclick = () => { selectedBlock = b.index; btnBlockRemove.enabled = true; render(); };
      d.oncontextmenu = (ev) => { ev.preventDefault(); conn.sendBlockRemove(b.index); };   // 行点击直删 (:510)
      list.appendChild(d);
    }
  }

  await render();
  reg.wins.set('comm', win);
  shared = { win, open: () => WindowManager.open(win, scene.hudLayer), refresh: render };
  return shared;
}

export function commDialog() { return shared; }
