// win-trade.js — 交易 TradeDialog.cs 移植 (D路 par-win)
// 双侧 5x2 格 (:31-43); 我方格可拖入 (链接流 C.TradeAddItem), 对方只读 (S.TradeItemAdded);
// 金币点击 = 数量对话框 → C.TradeAddGold; 确认按钮状态机 (点击即锁, S.TradeUnlock 解锁);
// S.TradeOpen 开窗 / S.TradeClose 清窗+解锁源格 / 请求弹窗 → C.TradeRequestResponse。

import { getWindow } from './uitree.js';
import { WindowManager } from './windows.js';
import { DXControl, DXLabel, DXButton } from './dx.js';
import { DXItemGrid, itemAmountDialog } from './dxgrid.js';
import { GRID } from './net.js';
import { D } from './data.js';

export async function winTrade(scene, store, reg) {
  const w = await getWindow('TradeDialog');
  if (!w) return null;
  const conn = scene.conn;

  // 状态
  const userItems = new Map();     // hostSlot → item (本地展示)
  const playerItems = new Map();   // hostSlot → item (对方)
  const pendingSources = new Map(); // hostSlot → {gridType, slot, item} 快照
  let userGold = 0n, playerGold = 0n;
  let confirmed = false;
  let otherName = '';

  // ---- 双侧格子 (15,73) / (226,73) 5x2 ----
  const userGrid = new DXItemGrid({
    cols: 5, rows: 2, gridType: GRID.TRADEUSER, store,
    location: [15, 73], size: [5 * 37 + 1, 2 * 37 + 1], linked: true,
  });
  userGrid.virtualGrid = userItems;
  userGrid.onUnlink = (cell) => {   // 点击已放格 = 撤回 (ClearLinkedItem)
    const src = pendingSources.get(cell.slot);
    if (src) {
      userItems.delete(cell.slot);
      pendingSources.delete(cell.slot);
      store.unlockPublic(src.gridType, src.slot);
      userGrid.refreshGrid();
    }
  };
  const playerGrid = new DXItemGrid({
    cols: 5, rows: 2, gridType: GRID.TRADEPLAYER, store,
    location: [226, 73], size: [5 * 37 + 1, 2 * 37 + 1], readOnly: true,
  });
  playerGrid.virtualGrid = playerItems;
  w.addControl(userGrid, playerGrid);

  // 背包右键快路由: 出售/修理未占用时 → 交易格 (TryRouteItem :195-202)
  // 由 win-inventory grid.onQuickRoute 链 (注册表接线见下)

  // ---- 金币标签 (11,168)/(222,168) ----
  const mkGold = (x, isMine) => {
    const caption = new DXLabel({ text: '金币', fontSize: 9, textColour: [255, 216, 77, 255],
      drawOutline: true, location: [x, 168], size: [50, 16], isControl: false });
    const value = new DXLabel({ text: '0', fontSize: 9, align: 'right',
      location: [x + 55, 168], size: [130, 16], isControl: isMine });
    if (isMine) {
      value.el.style.cursor = 'pointer';
      value.el.addEventListener('click', () => {
        if (confirmed) return;
        const avail = Number(store.gold());
        if (avail <= 0) { scene.addChat('没有金币可支付', 'hint'); return; }
        itemAmountDialog('交易金币', avail, 1, (n) => {
          if (n > 0 && n <= Number(store.gold())) conn.sendTradeAddGold(BigInt(n));
        });
      });
    }
    w.addControl(caption, value);
    return value;
  };
  const userGoldL = mkGold(11, true);
  const playerGoldL = mkGold(222, false);

  // ---- 确认按钮 (126,203) 80x25 状态机 ----
  const confirmBtn = new DXButton({ text: '确认交易', fontSize: 9, library: 'Interface', index: -1,
    location: [126, 203], size: [80, 25], onClick: () => {
      if (confirmed) return;
      confirmed = true;            // 点击即锁 (L62-66)
      confirmBtn.enabled = false;
      conn.sendTradeConfirm();
    } });
  w.addControl(confirmBtn);

  // ---- 标题/用户名 ----
  const userHead = new DXLabel({ text: '用户', fontSize: 9, textColour: [255, 255, 255, 255],
    drawOutline: true, location: [15, 38], size: [186, 20], isControl: false });
  const playerHead = new DXLabel({ text: '玩家', fontSize: 9, textColour: [255, 255, 255, 255],
    drawOutline: true, location: [226, 38], size: [186, 20], isControl: false });
  w.addControl(userHead, playerHead);

  function setConfirmEnabled(on) { confirmed = !on; confirmBtn.enabled = on; }

  function clearTrade() {   // ClearTrade :106-127
    for (const src of pendingSources.values()) store.unlockPublic(src.gridType, src.slot);
    pendingSources.clear();
    userItems.clear();
    playerItems.clear();
    userGold = 0n; playerGold = 0n;
    userGoldL.text = '0'; playerGoldL.text = '0';
    userGrid.refreshGrid(); playerGrid.refreshGrid();
    setConfirmEnabled(true);
    WindowManager.close(w);
  }

  // ---- S 包 (GameScene.cs:1176-1213) ----
  conn.addEventListener('tradeOpen', (e) => {
    otherName = e.detail.name ?? '';
    playerHead.text = otherName || '玩家';
    setConfirmEnabled(true);
    WindowManager.open(w, scene.hudLayer);
  });
  conn.addEventListener('tradeRequest', (e) => {   // ShowRequest :74-84
    const name = e.detail.name;
    const ov = document.createElement('div');
    ov.style.cssText = 'position:fixed;inset:0;z-index:99996;display:flex;align-items:center;justify-content:center;background:rgba(0,0,0,.35);';
    const box = document.createElement('div');
    box.style.cssText = `width:300px;padding:14px;background:rgba(28,22,10,.97);border:1px solid #8a6d35;color:#ffdb8e;font-family:'Noto Sans CJK SC',sans-serif;`;
    const t = document.createElement('div');
    t.textContent = `${name ?? '未知玩家'} 请求交易`;
    t.style.cssText = 'font-size:13px;margin-bottom:12px;';
    const row = document.createElement('div');
    row.style.cssText = 'display:flex;gap:8px;justify-content:flex-end;';
    const mk = (label, accept) => {
      const b = document.createElement('button');
      b.textContent = label;
      b.style.cssText = 'padding:6px 16px;cursor:pointer;background:#4a3818;color:#ffdb8e;border:1px solid #8a6d35;font-size:13px;';
      b.onclick = () => { ov.remove(); conn.sendTradeRequestResponse(accept); };
      return b;
    };
    row.append(mk('接受', true), mk('拒绝', false));
    box.append(t, row);
    ov.appendChild(box);
    scene.root.appendChild(ov);
  });
  conn.addEventListener('tradeClose', clearTrade);
  conn.addEventListener('tradeUnlock', () => setConfirmEnabled(true));
  conn.addEventListener('tradeItemAdded', (e) => {   // SetOtherItem :85-91
    const it = e.detail.item;
    if (!it) return;
    for (let i = 0; i < 10; i++) {
      if (!playerItems.has(i)) { playerItems.set(i, it); break; }
    }
    playerGrid.refreshGrid();
  });
  conn.addEventListener('tradeGoldAdded', (e) => {   // 对方加钱
    playerGold = e.detail.gold;
    playerGoldL.text = Number(playerGold).toLocaleString();
  });
  conn.addEventListener('tradeAddItem', (e) => {     // ApplyTradeAddItem :131-165
    const link = e.detail.cell ?? e.detail.link;
    if (!link) return;
    // 找对应 host 格
    let hostSlot = -1;
    for (const [hs, src] of pendingSources) {
      if (src.gridType === link.gridType && src.slot === link.slot) { hostSlot = hs; break; }
    }
    if (!e.detail.success) {
      if (hostSlot >= 0) {
        userItems.delete(hostSlot);
        pendingSources.delete(hostSlot);
        store.unlockPublic(link.gridType, link.slot);
        userGrid.refreshGrid();
      }
      scene.addChat('交易物品添加失败', 'hint');
      return;
    }
    if (hostSlot >= 0) store.lock(link.gridType, link.slot);   // 锁源格 (L161-164)
  });

  // ---- 拖入接口 (inventory 右键快路由 / 拖放目标) ----
  // DXItemCell drop 到 trade 格 → 链接
  function offerItem(cell) {   // TryRouteItem :195-202
    if (!cell.item) return false;
    if (cell.gridType !== GRID.INVENTORY && cell.gridType !== GRID.STORAGE
      && cell.gridType !== GRID.EQUIPMENT) return false;
    if (cell.item.flags & 2) return false;   // Marriage
    for (let i = 0; i < 10; i++) {

      if (!userItems.has(i) && !pendingSources.has(i)) {
        pendingSources.set(i, { gridType: cell.gridType, slot: cell.slot, item: cell.item });
        userItems.set(i, cell.item);
        conn.sendTradeAddItem({ gridType: cell.gridType, slot: cell.slot, count: cell.item.count });
        userGrid.refreshGrid();
        return true;
      }
    }
    return false;
  }

  // 关闭 = C.TradeClose + 清窗 (:203-206)
  if (w.closeButton) w.closeButton.onClick = () => { conn.sendTradeClose(); clearTrade(); };
  // 快路由 (背包右键 → 交易格) + 拖入 onOffer
  userGrid.onOffer = (srcCell) => offerItem(srcCell);
  reg.routeHandlers.push((cell) => (w.visible ? offerItem(cell) : false));
  void D;

  reg.wins.set('trade', w);
  return {
    win: w,
    open: () => WindowManager.open(w, scene.hudLayer),
    close: () => { conn.sendTradeClose(); clearTrade(); },
    toggle: () => { if (w.visible) { conn.sendTradeClose(); clearTrade(); } else WindowManager.open(w, scene.hudLayer); },
    offerItem,
  };
}
