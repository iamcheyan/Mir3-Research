// dxgrid.js — DXItemGrid.cs + DXItemCell.cs + DXVScrollBar.cs 移植 (D路 par-win)
// 格子 36px, 步进 37 (DXItemCell.cs:20-21, DXItemGrid.cs:118); slot = y*cols + x (:143-147)
// 虚拟滚动: ScrollValue 夹 [0, rows-VisibleHeight] (DXItemGrid.cs:51-60,172-190)
// 交互 (DXItemCell.cs): 左键点击选中/使用, 双击使用, 右键快路由(装备/出售), 拖拽 MoveItem,
//   数量格 (StackSize>1) Shift 拖 = 拆分对话框, Ctrl 右键 = 拆一半, Locked 红边, 出售高亮。

import { DXControl, DXLabel } from './dx.js';
import { skin } from './skin.js';
import { GRID, ITEM_FLAGS, RarityColour } from './net.js';
import { setHint } from './windows.js';

export const CELL = 36, STEP = 37;

// 拖拽幽灵 (全局一个)
let dragGhost = null;
function ensureGhost() {
  if (!dragGhost) {
    dragGhost = document.createElement('div');
    dragGhost.style.cssText =
      'position:fixed;z-index:99998;pointer-events:none;width:36px;height:36px;' +
      'background-size:contain;background-repeat:no-repeat;image-rendering:pixelated;display:none;filter:drop-shadow(0 2px 4px rgba(0,0,0,.7));';
    document.body.appendChild(dragGhost);
  }
  return dragGhost;
}

// ItemAmountDialog (ItemAmountDialog.cs) — 数量选择模态
export function itemAmountDialog(title, max, initial = 1, cb) {
  const ov = document.createElement('div');
  ov.style.cssText =
    'position:fixed;inset:0;z-index:99997;background:rgba(0,0,0,.45);' +
    'display:flex;align-items:center;justify-content:center;';
  const box = document.createElement('div');
  box.style.cssText =
    'width:280px;background:rgba(28,22,10,.97);border:1px solid #8a6d35;padding:12px;' +
    "font-family:'Noto Sans CJK SC','Noto Sans CJK',sans-serif;color:#ffdb8e;";
  const h = document.createElement('div');
  h.textContent = title ?? '数量';
  h.style.cssText = 'font-size:14px;margin-bottom:8px;color:#ffd94d;';
  const row = document.createElement('div');
  row.style.cssText = 'display:flex;align-items:center;gap:6px;margin-bottom:10px;';
  const minus = mkBtn('−'), plus = mkBtn('+');
  const val = document.createElement('input');
  val.type = 'number';
  val.min = '1'; val.max = String(Math.max(1, max));
  val.value = String(Math.max(1, Math.min(initial, max)));
  val.style.cssText =
    'flex:1;padding:4px 6px;background:#000;border:1px solid #8a6d35;color:#ffdb8e;' +
    'font-size:13px;outline:none;text-align:center;';
  const clamp = () => {
    const n = Math.max(1, Math.min(max, parseInt(val.value, 10) || 1));
    val.value = String(n);
  };
  minus.onclick = () => { val.stepDown?.() ?? (val.value = String(parseInt(val.value) - 1)); clamp(); };
  plus.onclick = () => { val.stepUp?.() ?? (val.value = String(parseInt(val.value) + 1)); clamp(); };
  val.oninput = clamp;
  row.append(minus, val, plus);
  const btns = document.createElement('div');
  btns.style.cssText = 'display:flex;gap:8px;justify-content:flex-end;';
  const ok = mkBtn('确定'), cancel = mkBtn('取消');
  ok.onclick = () => { const n = parseInt(val.value, 10) || 1; cleanup(); cb(Math.max(1, Math.min(max, n))); };
  cancel.onclick = () => cleanup();
  btns.append(ok, cancel);
  box.append(h, row, btns);
  ov.appendChild(box);
  document.addEventListener('keydown', esc, { once: false });
  function esc(ev) { if (ev.key === 'Escape') cleanup(); }
  function cleanup() { ov.remove(); document.removeEventListener('keydown', esc); }
  document.body.appendChild(ov);
  val.focus(); val.select();
  function mkBtn(t) {
    const b = document.createElement('button');
    b.textContent = t;
    b.style.cssText =
      'min-width:34px;padding:5px 10px;cursor:pointer;background:#4a3818;color:#ffdb8e;' +
      'border:1px solid #8a6d35;font-size:13px;';
    return b;
  }
  return cleanup;
}

// ConfirmDialog (ConfirmDialog.cs)
export function confirmDialog(text, caption, cb) {
  const ov = document.createElement('div');
  ov.style.cssText =
    'position:fixed;inset:0;z-index:99997;background:rgba(0,0,0,.45);' +
    'display:flex;align-items:center;justify-content:center;';
  const box = document.createElement('div');
  box.style.cssText =
    'width:300px;background:rgba(28,22,10,.97);border:1px solid #8a6d35;padding:14px;' +
    "font-family:'Noto Sans CJK SC','Noto Sans CJK',sans-serif;color:#ffdb8e;";
  const c = document.createElement('div');
  c.textContent = caption ?? '确认';
  c.style.cssText = 'font-size:14px;margin-bottom:8px;color:#ffd94d;';
  const t = document.createElement('div');
  t.textContent = text ?? '';
  t.style.cssText = 'font-size:13px;margin-bottom:12px;white-space:pre-wrap;';
  const btns = document.createElement('div');
  btns.style.cssText = 'display:flex;gap:8px;justify-content:flex-end;';
  const ok = document.createElement('button'), cancel = document.createElement('button');
  ok.textContent = '确定'; cancel.textContent = '取消';
  for (const b of [ok, cancel])
    b.style.cssText = 'padding:6px 14px;cursor:pointer;background:#4a3818;color:#ffdb8e;border:1px solid #8a6d35;font-size:13px;';
  ok.onclick = () => { ov.remove(); cb?.(); };
  cancel.onclick = () => ov.remove();
  btns.append(ok, cancel);
  box.append(c, t, btns);
  ov.appendChild(box);
  document.body.appendChild(ov);
}

// ---- DXVScrollBar (DXVScrollBar.cs) ----
export class DXVScrollBar extends DXControl {
  constructor(opts = {}) {
    super({ size: [14, 100], ...opts, isControl: true });
    this.change = opts.change ?? 1;
    this.visibleSize = opts.visibleSize ?? 100;
    this.maxValue = opts.maxValue ?? 0;
    this._value = 0;
    this.onValueChanged = opts.onValueChanged ?? null;
    this.el.style.cursor = 'default';
    this.el.innerHTML = '';
    const track = document.createElement('div');
    track.style.cssText =
      'position:absolute;inset:0;background:rgba(0,0,0,.45);border:1px solid #6a5225;overflow:hidden;';
    this.thumb = document.createElement('div');
    this.thumb.style.cssText =
      'position:absolute;left:1px;width:10px;background:#8a6d35;border:1px solid #c8a463;cursor:pointer;';
    track.appendChild(this.thumb);
    this.el.appendChild(track);
    this.thumb.addEventListener('mousedown', (ev) => {
      ev.preventDefault(); ev.stopPropagation();
      const rect = this.el.getBoundingClientRect();
      const startY = ev.clientY, startVal = this._value;
      const scale = rect.height / this.el.style ? 1 : 1;
      const move = (e2) => {
        const dy = (e2.clientY - startY) * (scale / Math.max(1, (rect.height / window.devicePixelRatio) ? 1 : 1));
        this.value = startVal + Math.round(dy / Math.max(1, rect.height - 20) * (this.maxValue));
      };
      const up = () => { removeEventListener('mousemove', move); removeEventListener('mouseup', up); };
      addEventListener('mousemove', move); addEventListener('mouseup', up);
    });
    // 滚轮: 挂到宿主由 grid 绑定
    this.refresh();
  }
  get value() { return this._value; }
  set value(v) {
    v = Math.max(0, Math.min(this.maxValue, Math.round(v)));
    if (v === this._value) return;
    this._value = v;
    this.refresh();
    this.onValueChanged?.(v);
  }
  doMouseWheel(deltaY) {
    this.value = this._value - Math.sign(deltaY) * this.change;
  }
  refresh() {
    const h = this.size[1];
    const range = Math.max(1, this.maxValue);
    const ratio = Math.min(1, this.visibleSize / Math.max(1, this.maxValue + this.visibleSize));
    const th = Math.max(14, Math.round(h * ratio));
    const free = Math.max(1, h - th - 2);
    this.thumb.style.height = `${th}px`;
    this.thumb.style.top = `${1 + Math.round((this.maxValue ? this._value / this.maxValue : 0) * free)}px`;
  }
}

// ---- DXItemGrid (DXItemGrid.cs) ----
export class DXItemGrid extends DXControl {
  // opts: cols, rows, gridType, store (ItemStore), readOnly, linked, onChange
  //       hostGetSlot(hostSlot) — 可选: TradeUser/Repair 等虚拟格 → {gridType, slot, count}
  constructor(opts = {}) {
    super({ ...opts, isControl: true });
    this.cols = opts.cols ?? 1;
    this.rows = opts.rows ?? 1;
    this.gridType = opts.gridType ?? GRID.NONE;
    this.store = opts.store ?? null;
    this.readOnly = !!opts.readOnly;
    this.linked = !!opts.linked;           // 虚拟链接格 (trade/repair/guild storage)
    this.onChange = opts.onChange ?? null;
    this.onCellClick = opts.onCellClick ?? null;
    this.onCellRightClick = opts.onCellRightClick ?? null;
    this.visibleHeight = opts.visibleHeight ?? this.rows;
    this.scrollValue = 0;
    this.virtualGrid = opts.virtualGrid ?? null;  // Map(hostSlot → item) 用于 ReadOnly 展示格
    this.capacity = opts.capacity ?? this.cols * this.rows;

    this.size = [this.cols * STEP + 1, Math.min(this.rows, this.visibleHeight) * STEP + 1];
    this.cells = [];
    for (let i = 0; i < this.cols * this.rows; i++) {
      const cell = new DXItemCell({
        grid: this, slot: i, location: this.#cellLoc(i),
        size: [CELL, CELL],
      });
      this.cells.push(cell);
      this.addControl(cell);
    }
    this.refreshGrid();
  }

  #cellLoc(i) {
    const x = i % this.cols, y = Math.floor(i / this.cols);
    const vy = y - this.scrollValue;
    return [x * STEP + 1, vy * STEP + 1];
  }

  setScroll(v) {
    this.scrollValue = Math.max(0, Math.min(Math.max(0, this.rows - this.visibleHeight), v));
    this.cells.forEach((c, i) => {
      c.location = this.#cellLoc(i);
      const y = Math.floor(i / this.cols);
      c.visible = y >= this.scrollValue && y < this.scrollValue + this.visibleHeight;
    });
  }

  setRows(rows) {
    const sel = new Set([...this.children.keys()]);
    void sel;
    // 重建 cells (RefreshStorage 模式)
    for (const c of this.cells) this.removeControl(c);
    this.cells = [];
    this.rows = rows;
    for (let i = 0; i < this.cols * rows; i++) {
      const cell = new DXItemCell({ grid: this, slot: i, location: this.#cellLoc(i), size: [CELL, CELL] });
      this.cells.push(cell);
      this.addControl(cell);
    }
    this.setScroll(this.scrollValue);
    this.refreshGrid();
  }

  itemAt(slot) {
    if (this.virtualGrid) return this.virtualGrid.get(slot) ?? null;
    if (!this.store) return null;
    if (this.gridType === GRID.STORAGE && this.storageParts) return this.store.partItem(slot);
    return this.store.item(this.gridType, slot);
  }

  refreshGrid() {
    for (const c of this.cells) c.refreshItem();
    this.onChange?.();
  }
}

// ---- DXItemCell (DXItemCell.cs) ----
let draggedCell = null;    // 拖拽源 (跨 grid 移动)

export class DXItemCell extends DXControl {
  constructor(opts = {}) {
    super({ size: [CELL, CELL], ...opts, isControl: true });
    this.grid = opts.grid;
    this.slot = opts.slot ?? 0;
    this.el.classList.add('dxcell');
    this.el.style.cssText +=
      'background:rgba(0,0,0,.25);box-sizing:border-box;cursor:pointer;';
    this.icon = document.createElement('div');
    this.icon.style.cssText = 'position:absolute;inset:2px;background-size:contain;' +
      'background-position:center;background-repeat:no-repeat;image-rendering:pixelated;';
    this.countLabel = document.createElement('div');
    this.countLabel.style.cssText =
      'position:absolute;right:2px;bottom:1px;font:10px "Noto Sans CJK SC",sans-serif;' +
      'color:#fff;text-shadow:1px 1px 0 #000;pointer-events:none;';
    this.duraBar = document.createElement('div');   // 耐久 (低耐久红条)
    this.duraBar.style.cssText =
      'position:absolute;left:2px;right:2px;bottom:2px;height:2px;display:none;pointer-events:none;';
    this.el.append(this.icon, this.countLabel, this.duraBar);

    this.el.addEventListener('mousedown', (ev) => this.#onMouseDown(ev));
    this.el.addEventListener('contextmenu', (ev) => ev.preventDefault());
    this.el.addEventListener('dblclick', (ev) => this.#onDblClick(ev));
    this.el.addEventListener('mouseenter', () => this.#hover(true));
    this.el.addEventListener('mouseleave', () => this.#hover(false));
    this._hover = false;
  }

  get gridType() { return this.grid?.gridType ?? GRID.NONE; }
  get store() { return this.grid?.store ?? null; }
  get item() { return this.grid?.itemAt(this.slot) ?? null; }
  get locked() {
    const it = this.item;
    if (!it) return false;
    return this.store?.isLocked(this.gridType, this.slot)
      || !!(it.flags & ITEM_FLAGS.LOCKED)
      || !!(it.flags & ITEM_FLAGS.MARRIAGE);
  }
  get saleSelected() { return this.store?.saleSelected.has(`${this.gridType}:${this.slot}`) ?? false; }

  refreshItem() {
    const it = this.item;
    this.el.style.borderColor = 'transparent';
    if (!it) {
      this.icon.style.backgroundImage = '';
      this.countLabel.textContent = '';
      this.duraBar.style.display = 'none';
      this.el.dataset.hint = this.grid?.emptyHint ?? '';
      this.#applyBorder();
      return;
    }
    const info = this.store?.constructor.itemInfo?.(it.infoIndex)
      ?? (this.store ? this.store.constructor.itemInfo(it.infoIndex) : null);
    if (info && info.image > 0) {
      skin.frame('Items', info.image).then(f => {
        if (this.item === it && f) this.icon.style.backgroundImage = `url(${f.url})`;
      }).catch(() => {});
    } else this.icon.style.backgroundImage = '';
    this.countLabel.textContent = Number(it.count) > 1 ? String(it.count) : '';
    // 耐久条
    if (it.maxDurability > 0 && it.currentDurability < it.maxDurability) {
      const pct = it.currentDurability / it.maxDurability;
      this.duraBar.style.display = 'block';
      this.duraBar.style.width = `${Math.round(pct * 100)}%`;
      this.duraBar.style.background = pct > 0.5 ? '#5fbf5f' : pct > 0.25 ? '#d9a73a' : '#d94545';
    } else this.duraBar.style.display = 'none';
    // tooltip (DXItemCell tooltip: 名称+稀有度颜色+数量+耐久)
    const zh = this.store?.constructor.itemZh ? this.store.constructor.itemZh(it.infoIndex) : '';
    const parts = [zh];
    if (Number(it.count) > 1) parts.push(`数量: ${it.count}`);
    if (it.maxDurability > 0) parts.push(`耐久: ${it.currentDurability}/${it.maxDurability}`);
    if (info?.type) parts.push(info.type);
    this.el.dataset.hint = parts.join('\n');
    this.#applyBorder();
  }

  #applyBorder() {
    let b = '1px solid rgba(120,96,48,.35)';
    if (this.saleSelected) b = '1px solid #5fd97a';
    else if (this.locked) b = '1px solid #d94545';
    else if (this._hover && this.item) b = '1px solid #ffdb8e';
    this.el.style.border = b;
    // 稀有度底色微调
    const it = this.item;
    if (it) {
      const info = this.store?.constructor.itemInfo?.(it.infoIndex);
      const rar = info?.rarity ?? 0;
      if (rar >= 2) this.el.style.background = 'rgba(40,30,70,.35)';
      else this.el.style.background = 'rgba(0,0,0,.25)';
    } else this.el.style.background = 'rgba(0,0,0,.25)';
  }

  #hover(on) { this._hover = on; this.#applyBorder(); }

  #onMouseDown(ev) {
    if (ev.button === 2) { this.#onRightClick(ev); return; }
    if (ev.button !== 0) return;
    ev.preventDefault();
    const it = this.item;
    this.grid?.onCellClick?.(this, ev);
    if (this.grid?.readOnly || !this.store) {
      if (it) this.#selectThis();
      return;
    }
    // 拖拽起点
    const start = { x: ev.clientX, y: ev.clientY };
    const ghost = ensureGhost();
    let dragging = false;
    const move = (e2) => {
      const dx = e2.clientX - start.x, dy = e2.clientY - start.y;
      if (!dragging && (Math.abs(dx) > 4 || Math.abs(dy) > 4)) {
        if (!it) return;
        dragging = true;
        draggedCell = this;
        ghost.style.display = 'block';
        const bg = this.icon.style.backgroundImage;
        ghost.style.backgroundImage = bg;
      }
      if (dragging) {
        ghost.style.left = `${e2.clientX + 8}px`;
        ghost.style.top = `${e2.clientY + 8}px`;
      }
    };
    const up = (e2) => {
      removeEventListener('mousemove', move);
      removeEventListener('mouseup', up);
      ghost.style.display = 'none';
      if (!dragging) {
        this.#onClick(e2);
        return;
      }
      if (draggedCell !== this) return;
      draggedCell = null;
      // 命中测试: 找 drop 目标 cell
      const target = this.#cellAtPoint(e2.clientX, e2.clientY);
      if (target && target !== this) this.#moveTo(target, e2);
      else if (!target) this.#dropOutside(e2);
    };
    addEventListener('mousemove', move);
    addEventListener('mouseup', up);
  }

  #cellAtPoint(cx, cy) {
    const els = document.elementsFromPoint(cx, cy);
    for (const el of els) {
      const ctl = el.__ctl ?? el.parentElement?.__ctl;
      if (ctl instanceof DXItemCell) return ctl;
    }
    return null;
  }

  // MoveItem (DXItemCell.cs:540-622)
  #moveTo(target, ev) {
    const src = this.item;
    if (!src) return;
    const fromG = this.gridType, fromS = this.slot;
    const toG = target.gridType, toS = target.slot;
    if (fromG === toG && fromS === toS) return;
    const info = this.store.constructor.itemInfo(src.infoIndex);
    const stackable = info && info.stack > 1;
    const dstItem = target.item;
    // 同格叠加已有 → merge; 数量格拖拽 → 拆分对话框; 普通整格移动
    if (dstItem && dstItem.infoIndex === src.infoIndex && stackable) {
      this.#sendMove(fromG, toG, fromS, toS, true);
    } else if (stackable && Number(src.count) > 1 && !ev.shiftKey && dstItem == null && fromG === toG) {
      // 拆分: 询问数量 (ItemSplit 流)
      itemAmountDialog('拆分数量', Number(src.count) - 1, 1, (n) => {
        if (n > 0 && n < Number(src.count)) {
          this.store.conn.sendItemSplit(this.#protoGrid(fromG), fromS, BigInt(n));
        }
      });
    } else {
      this.#sendMove(fromG, toG, fromS, toS, false);
    }
  }

  #sendMove(fromG, toG, fromS, toS, merge) {
    // Equipment 协议槽 = slot + 1000 (Globals.EquipmentOffSet)
    const fg = this.#protoGrid(fromG), tg = this.#protoGrid(toG);
    const fs = fromS, ts = toS;
    this.store.conn.sendItemMove(fg, tg, fs, ts, merge);
    this.store.lock(fg, fs);
  }

  #protoGrid(g) {
    // parts storage 特例: 移动到 PartsStorage 用 GRID.STORAGE + slot+2000 表达
    if (g === GRID.STORAGE && this.grid?.storageParts) return GRID.STORAGE;
    return g;
  }

  #dropOutside(ev) {
    // 拖到窗口外 = 丢弃 (ItemDrop; Godot: 拖到地面丢)
    const src = this.item;
    if (!src || this.locked) return;
    confirmDialog(`确定丢弃 ${this.store.constructor.itemZh(src.infoIndex)} 吗？`, '丢弃', () => {
      this.store.conn.sendItemDrop(this.#protoGrid(this.gridType), this.slot, src.count, -1);
    });
    void ev;
  }

  #onClick(ev) {
    const it = this.item;
    if (!it) { DXItemCell.SelectedCell = null; this.grid.refreshGrid(); return; }
    if (this.locked) return;
    // NPC 出售模式: 多选
    if (this.grid.onSaleSelect) { this.grid.onSaleSelect(this); return; }
    // 链接格 (trade/repair): 点击 = 取消链接
    if (this.grid.linked) { this.grid.onUnlink?.(this); return; }
    DXItemCell.SelectedCell = this;
    this.#selectThis();
    // 双击使用由 dblclick 处理; 单击只选中
    void ev;
  }

  #selectThis() {
    for (const c of this.grid.cells) c.el.style.outline = '';
    this.el.style.outline = '1px solid #ffd94d';
  }

  #onDblClick(ev) {
    ev.preventDefault();
    const it = this.item;
    if (!it || this.grid?.readOnly) return;
    if (this.locked) return;
    if (this.locked) return;
    // 使用/装备 (DXItemCell: 双击 = Use)
    const g = this.#protoGrid(this.gridType);
    if (this.gridType === GRID.EQUIPMENT) {
      // 装备格双击 = 卸下到背包
      this.store.conn.sendItemMove(GRID.EQUIPMENT, GRID.INVENTORY, this.slot, this.#firstEmpty(), false);
    } else {
      this.store.conn.sendItemUse(g, this.slot, it.count);
    }
  }

  #firstEmpty() {
    const inv = this.store.items(GRID.INVENTORY);
    for (let s = 0; s < 48; s++) if (!inv.has(s)) return s;
    return 0;
  }

  #onRightClick(ev) {
    ev.preventDefault();
    const it = this.item;
    this.grid?.onCellRightClick?.(this, ev);
    if (!it || this.grid?.readOnly) return;
    if (this.locked) return;
    // 右键快路由: 装备格 → 卸下; 背包 → 快路由钩子 (修理/NPC出售/寄售)
    if (this.gridType === GRID.EQUIPMENT) {
      this.store.conn.sendItemMove(GRID.EQUIPMENT, GRID.INVENTORY, this.slot, this.#firstEmpty(), false);
      return;
    }
    if (this.grid.onQuickRoute) { this.grid.onQuickRoute(this); return; }
    // 默认: 使用
    this.store.conn.sendItemUse(this.#protoGrid(this.gridType), this.slot, it.count);
  }
}

DXItemCell.SelectedCell = null;
