// win-belt.js — BeltDialog (BeltDialog.cs) 药品腰带栏
// 无标题 10×1 格, 每格角标 (slot+1)%10 (:120-138); 链接格 (linked):
//   拖入 = 建链 (DXItemCell.MoveItem 腰带分支 :745-782, ShouldLinkInfo 分流)
//   拖出/内部交换 = 换链/清链 (双向 C.BeltLinkChanged)
//   双击/右键 = 使用 (UseItem :1123 解析回背包格)
import { DXControl } from './dx.js';
import { DXWindow, WindowManager } from './windows.js';
import { DXItemGrid } from './dxgrid.js';
import { GRID } from './net.js';

let shared = null;

export async function winBelt(scene, itemStore, reg) {
  if (shared) { WindowManager.open(shared.win, scene.hudLayer); return shared; }
  const store = itemStore ?? scene.itemStore;
  const conn = scene.conn;

  const win = new DXWindow({ title: '腰带', hasTitle: false, showCloseButton: false, size: [10 * 32 + 1, 33] });

  // 虚拟链接格: beltDisplay(slot) → 展示物品 (QuickInfo 合计 / QuickItem 实例)
  const virtual = new Map();
  const rebuild = () => {
    virtual.clear();
    for (let s = 0; s < 10; s++) {
      const it = store.beltDisplay(s);
      if (it) virtual.set(s, it); else virtual.delete(s);
    }
    grid?.refreshGrid();
  };

  const grid = new DXItemGrid({
    cols: 10, rows: 1, gridType: GRID.BELT, store, linked: true, readOnly: true,
    virtualGrid: virtual, emptyHint: '拖入背包物品建立链接',
    location: [0, 0],
    // 拖入 (含腰带内部拖动): MoveItem 腰带分支
    onOffer: (srcCell, tgtCell) => {
      const slot = tgtCell.slot;
      // 源也是腰带格 = 交换链接 (:757-773 两包都发)
      if (srcCell.grid?.gridType === GRID.BELT) {
        const a = srcCell.slot, b = slot;
        const la = store.beltLinks.find(l => l.slot === a);
        const lb = store.beltLinks.find(l => l.slot === b);
        const tmpI = lb?.linkInfoIndex ?? -1, tmpT = lb?.linkItemIndex ?? -1;
        store.setBeltLink(b, la?.linkInfoIndex ?? -1, la?.linkItemIndex ?? -1);
        store.setBeltLink(a, tmpI, tmpT);
        rebuild();
        return;
      }
      const it = srcCell.item;
      if (!it) return;
      // ShouldLinkInfo (ItemInfo.cs:458): StackSize>1 || Consumable || Scroll → 类型链接; 否则实例链接
      if (store.shouldLinkInfo(it.infoIndex)) store.setBeltLink(slot, it.infoIndex, -1);
      else store.setBeltLink(slot, -1, Number(it.index));
      rebuild();
    },
    // 拖出 = 清链 (C.BeltLinkChanged -1,-1 — Godot 同款移除包 :9098)
    onUnlink: (cell) => { store.setBeltLink(cell.slot, -1, -1); rebuild(); },
    // 使用: beltUse 解析回背包格 (DXItemCell.UseItem :1123-1134)
    onUse: (cell) => { store.beltUse(cell.slot); },
  });
  win.addControl(grid);

  // 角标 (slot+1)%10, 金色描边 (AddSlotLabels :120-138)
  for (let i = 0; i < 10; i++) {
    const lbl = document.createElement('div');
    lbl.textContent = String((i + 1) % 10);
    lbl.style.cssText = 'position:absolute;left:-1px;top:-2px;font:8px "Noto Sans CJK SC",sans-serif;' +
      'color:rgb(255,229,127);text-shadow:1px 1px 0 #000;pointer-events:none;z-index:2;';
    grid.cells[i].el.appendChild(lbl);
  }

  // 链接数据变化 (含 ItemMove 消耗实例) → 重算展示
  store.on((kind) => { if (!kind || kind === 'items' || kind === 'mail') rebuild(); });
  rebuild();

  reg.wins.set('belt', win);
  shared = { win, open: () => WindowManager.open(win, scene.hudLayer), refresh: rebuild, grid };
  return shared;
}
