// windows.js — DXWindow.cs + WindowManager.cs 移植
// 标题栏拖动 / 关闭按钮 (Interface 15) / 边缘缩放 / 置顶 / Esc 关最上层。
// Z 序 = DOM 顺序 (OpenWindows 列表尾 = 最上层), ClientArea 与 C# 同公式。

import { DXControl, DXLabel, DXButton } from './dx.js';

export const TITLE_H = 24, FOOTER_H = 20;

// ---- WindowManager (WindowManager.cs) ----
export const WindowManager = {
  OpenWindows: [],

  open(w, parent) {
    if (!w) return;
    if (w.visible) { this.bringToFront(w); return; }
    if (!this.OpenWindows.includes(w)) this.OpenWindows.push(w);
    w.showWindow(parent);
    this.#refreshZ();
  },

  close(w) {
    if (!w) return;
    const i = this.OpenWindows.indexOf(w);
    if (i >= 0) this.OpenWindows.splice(i, 1);
    w.close();
    this.#refreshZ();
  },

  toggle(w, parent) {
    if (!w) return;
    if (w.visible) this.close(w);
    else this.open(w, parent);
  },

  // Esc: 关闭最上层可见窗口; 没有返回 false
  closeTop() {
    for (let i = this.OpenWindows.length - 1; i >= 0; i--) {
      const w = this.OpenWindows[i];
      if (!w.visible) { this.OpenWindows.splice(i, 1); continue; }
      this.close(w);
      return true;
    }
    return false;
  },

  bringToFront(w) {
    if (!w || !w.visible) return;
    const i = this.OpenWindows.indexOf(w);
    if (i >= 0) { this.OpenWindows.splice(i, 1); this.OpenWindows.push(w); }
    this.#refreshZ();
  },

  #refreshZ() {
    for (const w of this.OpenWindows) w.el.style.zIndex = w.el.style.zIndex ?? '';
    // DOM append 顺序即 Z 序; z-index 统一放 100+ (与 C# BaseZ 对齐)
    this.OpenWindows.forEach((w, i) => { w.el.style.zIndex = 100 + i; });
  },
};

// ---- DXWindow (DXWindow.cs) ----
export class DXWindow extends DXControl {
  constructor(opts = {}) {
    super({ isControl: true, ...opts });
    this.hasTitle = opts.hasTitle ?? true;
    this.hasFooter = opts.hasFooter ?? false;
    this.showCloseButton = opts.showCloseButton ?? true;
    this.movable = opts.movable ?? true;
    this.allowResize = opts.allowResize ?? false;
    this.canResizeWidth = opts.canResizeWidth ?? true;
    this.canResizeHeight = opts.canResizeHeight ?? true;
    this.modal = !!opts.modal;
    this.onClose = opts.onClose ?? null;

    this.el.classList.add('dxwindow');
    // DropShadow (DXWindow.cs:143-157)
    this.el.style.filter = 'drop-shadow(0 2px 6px rgba(0,0,0,.5))';

    this.title = opts.title ?? '';
    this._moving = false;
    this._resizeEdges = 0;

    if (this.hasTitle && this.title) this.#buildTitle();
    if (this.showCloseButton) this.#buildClose();
    this.#wire();
    this.updateClientArea();
    this.visible = false; // DXWindow 构造即隐藏 (DXWindow.cs:80)
  }

  #buildTitle() {
    this.titleLabel = new DXLabel({
      text: this.title, fontSize: 13, textColour: [255, 242, 178, 255],
      drawOutline: true, align: 'center', valign: 'center',
      location: [30, 4], size: [Math.max(0, this.size[0] - 60), TITLE_H - 4],
      isControl: false,
    });
    this.titleLabel.el.style.zIndex = '5';
    this.addControl(this.titleLabel);
  }

  #buildClose() {
    // 已有 Interface[15] 按钮的窗口 (ui_tree 渲染) 不重复创建 — 由 wireClose 复用
    this.closeButton = new DXButton({
      library: 'Interface', index: 15, location: [Math.max(0, this.size[0] - 30), 3],
      hint: '关闭',
    });
    this.closeButton.onClick = () => WindowManager.close(this);
    this.addControl(this.closeButton);
  }

  // ui_tree 渲染的窗口自带 Interface[15]: 移除默认按钮并复用它
  wireClose(existingButton) {
    if (!existingButton) return;
    if (this.closeButton) this.removeControl(this.closeButton);
    this.closeButton = existingButton;
    existingButton.onClick = () => WindowManager.close(this);
  }

  #wire() {
    const el = this.el;
    el.addEventListener('mousedown', (ev) => {
      if (ev.button !== 0) return;
      WindowManager.bringToFront(this);
      const rect = el.getBoundingClientRect();
      const lx = (ev.clientX - rect.left) / UiScaleNow(), ly = (ev.clientY - rect.top) / UiScaleNow();
      // AllowResize 边缘判定 (DXWindow.cs:242-266, ResizeBuffer=6)
      if (this.allowResize) {
        let edges = 0;
        if (this.canResizeWidth) {
          if (lx < 6) edges |= 1;
          else if (lx > this.size[0] - 6) edges |= 2;
        }
        if (this.canResizeHeight) {
          if (ly < 6) edges |= 4;
          else if (ly > this.size[1] - 6) edges |= 8;
        }
        if (edges) {
          this._resizeEdges = edges;
          this._resizeStart = { mx: ev.clientX, my: ev.clientY, x: this.location[0], y: this.location[1], w: this.size[0], h: this.size[1] };
          ev.preventDefault();
          return;
        }
      }
      // 仅标题栏可拖 (DXWindow.cs:267-274)
      if (this.hasTitle && this.movable && ly < TITLE_H) {
        this._moving = true;
        this._grab = [lx, ly];
        ev.preventDefault();
      }
    });
    addEventListener('mousemove', (ev) => {
      if (this._moving) {
        // _stage 的 transform 缩放: 屏幕像素 → 逻辑像素
        const s = UiScaleNow();
        let nx = (ev.clientX - this._grab[0] * s) / s;
        let ny = (ev.clientY - this._grab[1] * s) / s;
        nx = Math.min(Math.max(nx, 0), Math.max(0, 1024 - this.size[0]));
        ny = Math.min(Math.max(ny, 0), Math.max(0, 768 - this.size[1]));
        this.location = [Math.round(nx), Math.round(ny)];
      } else if (this._resizeEdges) {
        this.#applyResize(ev);
      }
    });
    const stop = () => { this._moving = false; this._resizeEdges = 0; };
    addEventListener('mouseup', stop);
    this._stopGlobal = stop;
  }

  #applyResize(ev) {
    const s = UiScaleNow();
    const dx = (ev.clientX - this._resizeStart.mx) / s;
    const dy = (ev.clientY - this._resizeStart.my) / s;
    const st = this._resizeEdges;
    let { x, y, w, h } = this._resizeStart;
    if (st & 2) w = this._resizeStart.w + dx;
    if (st & 8) h = this._resizeStart.h + dy;
    if (st & 1) { x = this._resizeStart.x + dx; w = this._resizeStart.w - dx; }
    if (st & 4) { y = this._resizeStart.y + dy; h = this._resizeStart.h - dy; }
    const accept = this.getAcceptableResize([w, h]);
    w = accept[0]; h = accept[1];
    if (st & 1) x = this._resizeStart.x + (this._resizeStart.w - w);
    if (st & 4) y = this._resizeStart.y + (this._resizeStart.h - h);
    x = Math.min(Math.max(x, 0), Math.max(0, 1024 - w));
    y = Math.min(Math.max(y, 0), Math.max(0, 768 - h));
    this.location = [Math.round(x), Math.round(y)];
    this.size = [Math.round(w), Math.round(h)];
    this.updateClientArea();
    this.onResized?.();
  }

  // GetAcceptableResize (DXWindow.cs:72-75): 子类覆盖 (MinResize=12)
  getAcceptableResize([w, h]) {
    return [Math.max(12, Math.round(w)), Math.max(12, Math.round(h))];
  }

  updateClientArea() {
    const top = this.hasTitle ? TITLE_H : 0;
    const bottom = this.size[1] - (this.hasFooter ? FOOTER_H : 0);
    this.clientArea = { x: 0, y: top, w: this.size[0], h: bottom - top };
  }

  // ShowWindow (DXWindow.cs:298-307)
  showWindow(parent) {
    const host = parent ?? this.parent;
    if (host && !this.el.isConnected) {
      if (host.addControl) host.addControl(this);
      else host.el.appendChild(this.el);
    }
    this.visible = true;
    WindowManager.bringToFront(this);
    this.onShown?.();
  }

  close() {
    this._moving = false;
    this.visible = false;
    this.el.remove();
    this.onClose?.();
  }

  set title(v) { this._title = v; if (this.titleLabel) this.titleLabel.text = v; }
  get title() { return this._title; }
}

// 逻辑画布缩放比 (#stage transform scale) — game.js 挂载后更新
let _uiScale = 1;
export function setUiScale(s) { _uiScale = s; }
export function UiScaleNow() { return _uiScale; }

// 简易 tooltip (Godot TooltipText) — 全局一个浮层
{
  const tip = document.createElement('div');
  tip.style.cssText =
    'position:fixed;z-index:99999;pointer-events:none;display:none;padding:3px 6px;' +
    'background:rgba(20,16,8,.92);border:1px solid #7a6234;color:#ffdb8e;' +
    "font:12px 'Noto Sans CJK SC','Noto Sans CJK',sans-serif;white-space:pre;";
  document.body.appendChild(tip);
  document.addEventListener('mouseover', (ev) => {
    const el = ev.target?.closest?.('[data-hint]');
    if (el) {
      tip.textContent = el.dataset.hint;
      tip.style.display = 'block';
    } else {
      tip.style.display = 'none';
    }
  });
  document.addEventListener('mousemove', (ev) => {
    if (tip.style.display !== 'none') {
      tip.style.left = `${ev.clientX + 14}px`;
      tip.style.top = `${ev.clientY + 16}px`;
    }
  });
}

// DXControl.hint 快捷注入 (ui_tree hint → tooltip)
export function setHint(ctl, text) {
  if (!ctl || !text) return;
  ctl.el.dataset.hint = text;
}
