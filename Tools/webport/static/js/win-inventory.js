// win-inventory.js — 背包 InventoryDialog.cs 移植 (D路 par-win)
// 6x8 格 @(20,39) 步进37 (:78-86); 金币/GG 标签; 整理(364)/移除(358)/出售(354) 按钮;
// 负重条; NPC 出售模式 (SellMode/NormalMode :278-315) — C.ItemSort/ItemDelete/NPCSell。
// 数据: ItemStore (S.ItemsGained/ItemMove/ItemsChanged/CurrencyChanged/WeightUpdate 全量镜像)。

import { getWindow } from './uitree.js';
import { WindowManager } from './windows.js';
import { DXControl, DXLabel } from './dx.js';
import { DXItemGrid, itemAmountDialog } from './dxgrid.js';
import { GRID } from './net.js';
import { D } from './data.js';

export async function winInventory(scene, store, reg) {
  const w = await getWindow('InventoryDialog');
  if (!w) return null;
  const conn = scene.conn;

  // ui_tree 里的占位 DXItemGrid (InventoryDialog/3) → 替换为真格子引擎
  const oldGrid = w.byPath.get('InventoryDialog/3');
  const grid = new DXItemGrid({
    cols: 6, rows: 8, gridType: GRID.INVENTORY, store,
    location: [20, 39], size: [6 * 37 + 1, 8 * 37 + 1],
  });
  if (oldGrid) {
    const idx = w.children.indexOf(oldGrid);
    if (idx >= 0) { w.children.splice(idx, 1); }
    oldGrid.el.remove();
    w.addControl(grid);
    grid.el.style.zIndex = oldGrid.el.style.zIndex ?? '';
  } else w.addControl(grid);

  // 出售模式状态
  let invMode = 'normal';          // normal | sell
  let primaryCurrency = null;      // {currencyIndex, amount} (Gold 默认)
  let sellableTypes = [];

  // NPC 出售选择 (TrySelectForSale :318-355)
  grid.onSaleSelect = null;
  grid.onCellClick = (cell) => {
    if (invMode === 'sell' && cell.item && cell.gridType === GRID.INVENTORY) {
      trySelectForSale(cell);
    }
  };
  // 右键快路由: 出售模式=选中; 否则走注册表链 (修理格/交易格 — par-win 各窗口注册)
  grid.onQuickRoute = (cell) => {
    if (invMode === 'sell') { trySelectForSale(cell); return; }
    for (const fn of reg.routeHandlers) {
      if (fn(cell)) return;
    }
  };

  function trySelectForSale(cell) {
    const it = cell.item;
    const info = D().itemsById?.[it.infoIndex];
    if (it.flags & 2 /* Marriage */) return;
    if (info?.canSell === false || it.flags & 1) { scene.addChat(`无法出售 ${ItemZh(it)}`, 'hint'); return; }
    if (sellableTypes.length && !sellableTypes.includes(info?.type)) {
      scene.addChat(`无法在当前商人处售卖 ${ItemZh(it)}`, 'hint'); return;
    }
    const keyS = `${GRID.INVENTORY}:${cell.slot}`;
    if (store.saleSelected.has(keyS)) store.saleSelected.delete(keyS);
    else store.saleSelected.add(keyS);
    grid.refreshGrid();
    updateSaleTotal();
  }
  const ItemZh = (it) => {
    const info = D().itemsById?.[it.infoIndex];
    return info?.zh && info.zh !== info.name ? info.zh : (info?.name ?? '');
  };
  const itemPrice = (it) => {
    const info = D().itemsById?.[it.infoIndex];
    return info?.price ?? 0;
  };
  function saleTotal() {
    let sum = 0;
    for (const keyS of store.saleSelected) {
      const [, slot] = keyS.split(':');
      const it = store.item(GRID.INVENTORY, +slot);
      if (it) sum += itemPrice(it) * Number(it.count);
    }
    return sum;
  }
  function updateSaleTotal() {
    if (ggLabel) ggLabel.text = String(saleTotal());
  }

  // 标签: 金币(7)/GG(9) 值; 负重值(5); 标题(1)
  const title = w.byPath.get('InventoryDialog/1');
  const weightLabel = w.byPath.get('InventoryDialog/5');
  const goldLabel = w.byPath.get('InventoryDialog/7');
  const ggLabel = w.byPath.get('InventoryDialog/9');

  // 按钮: 整理(364)=11, 移除(358)=12, 出售(354)=13 (隐藏)
  const btnSort = w.byPath.get('InventoryDialog/11');
  const btnTrash = w.byPath.get('InventoryDialog/12');
  const btnSell = w.byPath.get('InventoryDialog/13');
  if (btnSort) btnSort.onClick = () => conn.sendItemSort(GRID.INVENTORY);
  if (btnTrash) btnTrash.onClick = trashItem;
  if (btnSell) { btnSell.visible = false; btnSell.enabled = false; btnSell.onClick = sellSelected; }
  function trashItem() {   // TrashItem :207-218
    const sel = grid.cells.find(c => c.el.style.outline?.includes('ffd94d'));
    const it = sel?.item;
    if (!it || sel.gridType !== GRID.INVENTORY) return;
    if (it.flags & 1 || it.flags & 2) return;
    store.lock(GRID.INVENTORY, sel.slot);
    conn.sendItemDelete(GRID.INVENTORY, sel.slot);
    sel.el.style.outline = '';
  }
  function sellSelected() {   // SellSelected :366-393
    const candidates = [];
    if (store.saleSelected.size) {
      for (const keyS of store.saleSelected) {
        const [, slot] = keyS.split(':');
        const it = store.item(GRID.INVENTORY, +slot);
        if (it && !(it.flags & 1) && !(it.flags & 2)) candidates.push(it);
      }
    } else {
      // 无选择 = 全部可售
      for (const [slot, it] of store.items(GRID.INVENTORY)) {
        const info = D().itemsById?.[it.infoIndex];
        if (it.flags & 1 || it.flags & 2) continue;
        if (info?.canSell === false) continue;
        if (sellableTypes.length && !sellableTypes.includes(info?.type)) continue;
        candidates.push(it);
        void slot;
      }
    }
    if (!candidates.length) return;
    const links = candidates.map(it => ({ gridType: GRID.INVENTORY, slot: it.slot, count: it.count }));
    for (const it of candidates) store.lock(GRID.INVENTORY, it.slot);
    store.saleSelected.clear();
    conn.sendNPCSell(links);
    grid.refreshGrid();
  }

  // NPC 出售模式切换 (供 win-npc 调用; ShowInventoryForNpcSale GameScene.cs:497-501)
  function sellMode(currency, types) {
    invMode = 'sell';
    primaryCurrency = currency ?? store.currency(0);
    sellableTypes = types ?? [];
    store.saleSelected.clear();
    if (title) title.text = '背包 [出售]';
    if (btnTrash) btnTrash.visible = false;
    if (btnSell) { btnSell.visible = true; btnSell.enabled = true; }
    grid.refreshGrid();
  }
  function normalMode() {
    invMode = 'normal';
    primaryCurrency = null;
    sellableTypes = [];
    store.saleSelected.clear();
    if (title) title.text = '背包';
    if (btnTrash) btnTrash.visible = true;
    if (btnSell) { btnSell.visible = false; btnSell.enabled = false; }
    grid.refreshGrid();
  }

  // 数据刷新
  function refresh() {
    grid.refreshGrid();
    if (goldLabel) goldLabel.text = String(store.gold());
    if (ggLabel) ggLabel.text = invMode === 'sell' ? String(saleTotal()) : String(store.gameGold());
    if (weightLabel) weightLabel.text = String(store.bagWeight);
  }
  store.on((kind) => {
    if (kind === 'items' || kind === 'currency' || kind === 'weight') refresh();
  });
  refresh();

  reg.wins.set('inventory', w);
  return {
    win: w,
    open: () => WindowManager.open(w, scene.hudLayer),
    close: () => WindowManager.close(w),
    toggle: () => WindowManager.toggle(w, scene.hudLayer),
    sellMode, normalMode,
    refresh,
  };
}
