// win-storage.js — 仓库 StorageDialog.cs 移植 (D路 par-win)
// 双页签 仓库/碎片 (:199-224); 10 列动态行 (rows = max(10, ceil(size/10)) :147-160);
// 虚拟滚动 VisibleHeight=10, 滚动条 x=390 (:105-126); 容量 S.StorageSize 禁用超额格;
// 排序按钮 = 确认后 C.ItemSort (SortStorage :275-280); 关闭 = CancelLinks (:246-251)。
// 槽位协议: Storage 0-99 / PartsStorage 2000+i (协议在 dxgrid #protoGrid 层)。

import { getWindow } from './uitree.js';
import { WindowManager } from './windows.js';
import { DXItemGrid, DXVScrollBar, confirmDialog } from './dxgrid.js';
import { GRID } from './net.js';
const GRID_PARTS = 44;   // GridType.PartsStorage (Enum.cs:168-215: ...ItemFragment=24 ... PartsStorage=44)

export async function winStorage(scene, store, reg) {
  const w = await getWindow('StorageDialog');
  if (!w) return null;
  const conn = scene.conn;

  let partsVisible = false;
  let grid = null, partGrid = null, scroll = null, partScroll = null;
  let tabBtn = null, partTabBtn = null;

  // 真格子引擎替换 ui_tree 占位 (StorageDialog/6=主 /7=碎片)
  const oldMain = w.byPath.get('StorageDialog/6');
  const oldParts = w.byPath.get('StorageDialog/7');

  const rowsFor = (size) => Math.max(10, Math.ceil(size / 10));
  const mainRows = () => rowsFor(store.storageSize);
  const partRows = () => 10;   // Globals.StorageSize=100 默认

  function makeGrid(rows, parts) {
    const g = new DXItemGrid({
      cols: 10, rows, gridType: GRID.STORAGE,
      store, location: [19, 72], size: [10 * 37 + 1, 10 * 37 + 1],
      visibleHeight: 10,
    });
    g.storageParts = parts;   // parts 标记: itemAt 走 partsStorage
    return g;
  }

  grid = makeGrid(mainRows(), false);
  partGrid = makeGrid(partRows(), true);
  partGrid.visible = false;
  if (oldMain) { oldMain.el.remove(); w.children.splice(w.children.indexOf(oldMain), 1); }
  if (oldParts) { oldParts.el.remove(); w.children.splice(w.children.indexOf(oldParts), 1); }
  w.addControl(grid, partGrid);

  // 滚动条 x=390 (SD:105-126)
  const mkScroll = (g) => {
    const s = new DXVScrollBar({
      location: [390, 72], size: [14, 349], visibleSize: 10, change: 1,
      onValueChanged: (v) => g.setScroll(v),
    });
    s.maxValue = Math.max(0, g.rows - 10);
    w.addControl(s);
    return s;
  };
  scroll = mkScroll(grid);
  partScroll = mkScroll(partGrid);
  partScroll.visible = false;

  // 滚轮绑定 (BindWheel :132-144)
  for (const [g, s] of [[grid, scroll], [partGrid, partScroll]]) {
    g.el.addEventListener('wheel', (ev) => {
      s.doMouseWheel(ev.deltaY);
      ev.preventDefault();
    }, { passive: false });
  }

  // 容量禁用 (ApplyCapacity :163-168)
  function applyCapacity() {
    grid.cells.forEach((c) => { c.enabled = c.slot < store.storageSize; });
  }

  // 刷新行数 (RefreshStorage :147-160)
  function refreshStorage() {
    grid.setRows(mainRows());
    scroll.maxValue = Math.max(0, grid.rows - 10);
    applyCapacity();
    grid.refreshGrid();
    partGrid.refreshGrid();
  }

  // 页签 (CreateTab :199-215)
  tabBtn = w.byPath.get('StorageDialog/4');
  partTabBtn = w.byPath.get('StorageDialog/5');
  function selectTab(parts) {
    partsVisible = parts;
    grid.visible = !parts;
    scroll.visible = !parts;
    partGrid.visible = parts;
    partScroll.visible = parts;
    if (tabBtn) tabBtn.textColour = parts ? [255, 255, 255, 255] : [255, 216, 77, 255];
    if (partTabBtn) partTabBtn.textColour = parts ? [255, 216, 77, 255] : [255, 255, 255, 255];
  }
  if (tabBtn) tabBtn.onClick = () => selectTab(false);
  if (partTabBtn) partTabBtn.onClick = () => selectTab(true);
  selectTab(false);

  // 排序按钮 (364) = 确认 + C.ItemSort
  const sortBtn = w.byPath.get('StorageDialog/3');
  if (sortBtn) sortBtn.onClick = () => {
    confirmDialog('确定要整理当前仓库吗？', '确认整理', () => {
      conn.sendItemSort(partsVisible ? GRID_PARTS : GRID.STORAGE);
    });
  };

  // 关闭 (CancelLinks 语义: 未提交链接由 itemsChanged 解锁; 此处直接关)
  const closeBtn = w.buttons.find(b => b.treeNode?.hint === '关闭');
  if (closeBtn) closeBtn.onClick = () => WindowManager.close(w);

  store.on((kind) => {
    if (kind === 'storage') refreshStorage();
    if (kind === 'items') { grid.refreshGrid(); partGrid.refreshGrid(); }
  });
  refreshStorage();

  reg.wins.set('storage', w);
  return {
    win: w,
    open: () => { refreshStorage(); WindowManager.open(w, scene.hudLayer); },
    close: () => WindowManager.close(w),
    toggle: () => { if (w.visible) WindowManager.close(w); else { refreshStorage(); WindowManager.open(w, scene.hudLayer); } },
    refreshStorage,
  };
}
