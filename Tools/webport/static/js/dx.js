// dx.js — DXControl 体系的 Web 移植 (GodotClient/Controls/*.cs 对照)
// 渲染: DOM + CSS; 贴图: /res/sprites/{lib}/{n}.webp (MirSkin.GetTexture 等价)
// 坐标: 逻辑画布 1024x768 (与 Godot 一致), #stage 整体 transform 缩放 (UiScaler)

import { skin } from './skin.js';

export const BASE_W = 1024, BASE_H = 768;

// ---- UiScaler (UiScaler.cs:27-62) ----
export const UiScaler = {
  scale: 1, ox: 0, oy: 0,
  apply(stageEl) {
    const vw = innerWidth, vh = innerHeight;
    const s = Math.min(Math.max(Math.min(vh / BASE_H, vw / BASE_W), 1), 2);
    this.scale = s;
    this.ox = Math.max((vw - BASE_W * s) / 2, 0);
    this.oy = Math.max((vh - BASE_H * s) / 2, 0);
    stageEl.style.transform = `translate(${this.ox}px, ${this.oy}px) scale(${s})`;
  },
};

const rgba = (c) => c == null ? 'transparent'
  : `rgba(${c[0]},${c[1]},${c[2]},${(c[3] ?? 255) / 255})`;

// ---- DXControl (DXControl.cs) ----
export class DXControl {
  constructor(opts = {}) {
    this.el = document.createElement('div');
    this.el.className = 'dxctl';
    this.el.style.position = 'absolute';
    this.el.__ctl = this;
    this.children = [];
    this.parent = null;
    this._visible = true;
    this._enabled = true;
    this._location = [0, 0]; this._size = [0, 0];
    Object.assign(this, {
      location: [0, 0], size: [0, 0], backColour: null, border: false,
      borderColour: [255, 255, 255, 255], isControl: true, clip: false,
    }, opts);
    if (opts.backColour != null) this.backColour = opts.backColour;
    if (opts.border) this.border = true;
    this.applyBase();
  }
  applyBase() {
    const [x, y] = this.location;
    this.el.style.left = `${x}px`;
    this.el.style.top = `${y}px`;
    if (this.size[0]) this.el.style.width = `${this.size[0]}px`;
    if (this.size[1]) this.el.style.height = `${this.size[1]}px`;
    if (this.backColour != null) this.el.style.backgroundColor = rgba(this.backColour);
    this.el.style.border = this.border ? `1px solid ${rgba(this.borderColour)}` : 'none';
    this.el.style.visibility = this._visible ? 'visible' : 'hidden';
    this.el.style.pointerEvents = this.isControl && this._enabled ? 'auto' : 'none';
    this.el.style.overflow = this.clip ? 'hidden' : 'visible';
  }
  get location() { return this._location; }
  set location(v) { this._location = v; this.applyBase(); }
  get size() { return this._size; }
  set size(v) { this._size = v; this.applyBase(); }
  get visible() { return this._visible; }
  set visible(v) { this._visible = v; this.applyBase(); }
  get enabled() { return this._enabled; }
  set enabled(v) { this._enabled = v; this.applyBase(); this.applyEnabled?.(); }
  addControl(c) {
    this.children.push(c);
    c.parent = this;
    this.el.appendChild(c.el);
    return c;
  }
  removeControl(c) {
    const i = this.children.indexOf(c);
    if (i >= 0) { this.children.splice(i, 1); c.parent = null; }
    c.el.remove();
  }
  bringToFront() {
    if (this.parent) this.parent.el.appendChild(this.el);
  }
}

// ---- DXImageControl (DXImageControl.cs) ----
export class DXImageControl extends DXControl {
  constructor(opts = {}) {
    super(opts);
    this.library = opts.library ?? 'Interface';
    this._index = opts.index ?? -1;
    this.fixedSize = !!opts.fixedSize;
    this.useOffSet = !!opts.useOffSet;
    this.blend = !!opts.blend;
    this.opacity = opts.opacity ?? 1;
    this.hoverIndex = opts.hoverIndex ?? -1;
    this.pressedIndex = opts.pressedIndex ?? -1;
    this._hover = false; this._pressed = false;
    this.el.classList.add('dximg');
    this.el.style.imageRendering = 'pixelated';
    if (opts.mouseFilter === 'ignore') { this.isControl = false; this.applyBase(); }
    if (this._index >= 0) this._renderImg();
  }
  get index() { return this._index; }
  set index(v) { this._index = v; this._renderImg(); }
  async _renderImg() {
    const idx = this.getCurrentIndex();
    if (idx < 0) { this.el.style.backgroundImage = ''; return; }
    let f = null;
    try { f = await skin.frame(this.library, idx); } catch { f = null; }
    if (!f) { this.el.style.backgroundImage = ''; return; }
    if (this.getCurrentIndex() !== idx) return; // 竞态: 索引已变
    if (!f) { this.el.style.backgroundImage = ''; return; }
    if (!this.fixedSize) {
      this.size = [f.w, f.h];
      this.el.style.width = `${f.w}px`;
      this.el.style.height = `${f.h}px`;
    }
    const ox = this.useOffSet ? f.ox : 0, oy = this.useOffSet ? f.oy : 0;
    this.el.style.backgroundImage = `url(${f.url})`;
    this.el.style.backgroundRepeat = 'no-repeat';
    this.el.style.backgroundPosition = `${ox}px ${oy}px`;
    this.el.style.mixBlendMode = this.blend ? 'screen' : 'normal';
    this.el.style.opacity = this.opacity;
    this.applyEnabled();
  }
  getCurrentIndex() { // DXImageControl.cs:155-160: 按下 > 悬停 > 普通
    if (this._pressed && this.pressedIndex >= 0) return this.pressedIndex;
    if (this._hover && this.hoverIndex >= 0) return this.hoverIndex;
    return this._index;
  }
  applyEnabled() {
    this.el.style.filter = this._enabled ? '' : 'grayscale(1) brightness(0.45)';
  }
}

// ---- DXAnimatedControl (DXAnimatedControl.cs) ----
// AnimationDelay = 一轮总时长 (非单帧); _Process 每帧计算 frame (DXAnimatedControl.cs:58-90)
export class DXAnimatedControl extends DXImageControl {
  constructor(opts = {}) {
    super({ ...opts, index: opts.baseIndex ?? -1 });
    this.baseIndex = opts.baseIndex ?? -1;
    this.frameCount = opts.frameCount ?? 0;
    this.animationDelayMs = opts.animationDelayMs ?? 0; // 总时长
    this.loop = opts.loop ?? true;
    this.animated = opts.animated ?? true;
    this.afterAnimation = null;
    this._start = null; this._finished = false; this._raf = 0;
    if (this.animated) this.start();
  }
  #tick = () => {
    requestAnimationFrame(this.#tick);
    if (!this.animated || this.frameCount <= 0 || this.animationDelayMs <= 0 || this._finished) return;
    if (this._start === null) this._start = performance.now();
    const elapsed = performance.now() - this._start;
    let frame = Math.floor(elapsed / this.animationDelayMs * this.frameCount);
    if (this.loop) {
      if (frame >= this.frameCount) frame %= this.frameCount;
    } else if (frame >= this.frameCount) {
      this.index = this.baseIndex + this.frameCount - 1;
      this._finished = true;
      this.animated = false;
      this.afterAnimation?.();
      return;
    }
    const idx = this.baseIndex + Math.min(Math.max(frame, 0), this.frameCount - 1);
    if (idx !== this.index) this.index = idx;
  };
  start() { if (!this._raf) this._raf = requestAnimationFrame(this.#tick); }
  restart(loop = false) { // DXAnimatedControl.cs:92-98
    this.loop = loop;
    this.animated = true;
    this._start = null;
    this._finished = false;
  }
  clearAnimationHandlers() { this.afterAnimation = null; }
}

// ---- DXLabel (DXLabel.cs) ----
// FontScale = 4/3 (MirSkin.cs:169): 旧字号 pt → 逻辑像素
export const FONT_SCALE = 4 / 3;
export class DXLabel extends DXControl {
  constructor(opts = {}) {
    super(opts);
    this.el.classList.add('dxlabel');
    this.fontSize = opts.fontSize ?? 12;
    this.textColour = opts.textColour ?? [255, 255, 255, 255];
    this.drawOutline = !!opts.drawOutline;
    this.outlineColour = opts.outlineColour ?? [0, 0, 0, 255];
    this.align = opts.align ?? 'left';
    this.valign = opts.valign ?? 'top';
    this.text = opts.text ?? '';
    this.applyText();
  }
  applyText() {
    const el = this.el;
    el.textContent = this.text;
    el.style.fontFamily = "'Noto Sans CJK SC','Noto Sans CJK',sans-serif";
    el.style.fontSize = `${Math.round(this.fontSize * FONT_SCALE)}px`;
    el.style.lineHeight = 1.0;
    el.style.color = rgba(this.textColour);
    el.style.textAlign = this.align;
    el.style.whiteSpace = 'pre';
    if (this.valign === 'center') {
      el.style.display = 'flex';
      el.style.alignItems = 'center';
    }
    if (this.drawOutline) { // DrawStringOutline width 4
      const px = Math.max(1, Math.round(4 / FONT_SCALE));
      el.style.webkitTextStrokeWidth = `${px}px`;
      el.style.webkitTextStrokeColor = rgba(this.outlineColour);
      el.style.paintOrder = 'stroke fill';
    }
    // enabled=false → 文字半透明 (DXLabel.cs:59)
    el.style.opacity = this._enabled ? 1 : 0.5;
  }
  set text(v) { this._text = v ?? ''; if (this.el) this.el.textContent = this._text; }
  get text() { return this._text; }
}

// ---- DXButton (DXButton.cs) ----
export class DXButton extends DXImageControl {
  constructor(opts = {}) {
    super(opts);
    this.el.classList.add('dxbtn');
    this.text = opts.text ?? '';
    this.fontSize = opts.fontSize ?? 12;
    this.textColour = opts.textColour ?? [255, 224, 140, 255]; // 1,.88,.55
    this.onClick = opts.onClick ?? null;
    if (this._index < 0) this.#renderGenerated();
    this.el.addEventListener('mousedown', () => { this._pressed = true; this.#renderGenerated(); });
    this.el.addEventListener('mouseup', () => { this._pressed = false; this.#renderGenerated(); });
    this.el.addEventListener('mouseleave', () => { this._pressed = false; this.#renderGenerated(); });
    this.el.addEventListener('click', () => { if (this._enabled && this.onClick) this.onClick(); });
    this.#label();
  }
  async #label() {
    const l = document.createElement('span');
    l.className = 'dxbtn-label';
    l.textContent = this.text;
    l.style.cssText = `position:absolute;inset:0;display:flex;align-items:center;justify-content:center;` +
      `font-family:'Noto Sans CJK SC','Noto Sans CJK',sans-serif;` +
      `font-size:${Math.round(this.fontSize * FONT_SCALE)}px;color:${rgba(this.textColour)};` +
      `pointer-events:none;text-shadow:1px 1px 0 #000;`;
    this.el.appendChild(l);
  }
  // Index=-1: Interface 左/中/右三片拼按钮 (DXButton.cs:187-203 parts 16/18/17)
  async #renderGenerated() {
    if (this._index >= 0 || !this.size[0] || !this.size[1]) return;
    const [lw, mw, rw] = await Promise.all([
      skin.frame('Interface', 16), skin.frame('Interface', 18), skin.frame('Interface', 17),
    ]);
    if (!lw || !mw || !rw) {
      this.el.style.background = this._enabled ? 'rgba(90,70,40,.9)' : 'rgba(50,50,50,.9)';
      return;
    }
    const L = lw.w, R = rw.w;
    const midW = Math.max(0, this.size[0] - L - R);
    this.el.style.setProperty('--btn-left', `url(${lw.url})`);
    this.el.style.setProperty('--btn-mid', `url(${mw.url})`);
    this.el.style.setProperty('--btn-right', `url(${rw.url})`);
    this.el.style.background =
      `var(--btn-right) no-repeat ${this.size[0] - R}px 0/ ${R}px 100%,` +
      `var(--btn-left) no-repeat 0 0/ ${L}px 100%,` +
      `var(--btn-mid) repeat-x ${L}px 0/ ${midW}px 100%`;
    this.el.style.imageRendering = 'pixelated';
    this.applyEnabled();
  }
}

// ---- DXTextInput (FilterDropDialog.cs:59-145) ----
export class DXTextInput extends DXControl {
  constructor(opts = {}) {
    super(opts);
    this.input = document.createElement('input');
    this.input.type = opts.secret ? 'password' : 'text';
    if (opts.maxLength) this.input.maxLength = opts.maxLength;  // 不传=不限 (DOM maxLength=0 会吞掉全部输入)
    this.input.style.cssText =
      `width:100%;height:100%;border:none;outline:none;background:transparent;` +
      `color:#e8dcc0;font-family:'Noto Sans CJK SC','Noto Sans CJK',sans-serif;` +
      `font-size:${Math.round((opts.fontSize ?? 8) * FONT_SCALE)}px;padding:0 2px;caret-color:#e8dcc0;`;
    this.el.appendChild(this.input);
    if (this._pendingText !== undefined) { this.input.value = this._pendingText; this._pendingText = undefined; }
    else if (opts.text) this.input.value = opts.text;
  }
  get text() { return this.input ? this.input.value : (this._pendingText ?? ''); }
  set text(v) { this._pendingText = v ?? ''; if (this.input) this.input.value = v ?? ''; }
  onTextChanged(fn) { this.input.addEventListener('input', () => fn(this.input.value)); }
  focus() { this.input.focus(); }
}

// ---- DXCheckBox (DXCheckBox.cs) ----
export class DXCheckBox extends DXControl {
  constructor(opts = {}) {
    super(opts);
    this.checked = !!opts.checked;
    this.el.style.cursor = 'pointer';
    this.box = document.createElement('span');
    this.box.style.cssText =
      `display:inline-block;width:12px;height:12px;border:1px solid #c8a463;` +
      `background:${this.checked ? '#c8a463' : 'rgba(0,0,0,.5)'};vertical-align:middle;`;
    this.label = document.createElement('span');
    this.label.textContent = opts.label ?? '';
    this.label.style.cssText =
      `margin-left:4px;color:${rgba(opts.textColour ?? [255, 191, 64, 255])};` +
      `font-family:'Noto Sans CJK SC','Noto Sans CJK',sans-serif;` +
      `font-size:${Math.round((opts.fontSize ?? 9) * FONT_SCALE)}px;text-shadow:1px 1px 0 #000;`;
    this.el.append(this.box, this.label);
    this.el.addEventListener('click', () => {
      this.checked = !this.checked;
      this.box.style.background = this.checked ? '#c8a463' : 'rgba(0,0,0,.5)';
    });
  }
}

// ---- LegacyWindowFrame (LegacyWindowFrame.cs) — Interface 九宫格 ----
export class LegacyWindowFrame extends DXControl {
  constructor(opts = {}) {
    super({ ...opts, isControl: false });
    this.hasTitle = opts.hasTitle ?? true;
    this.hasFooter = opts.hasFooter ?? false;
    this._renderFrame();
  }
  async _renderFrame() {
    const F = async (i) => skin.frame('Interface', i);
    const [top, side, mid, t2, t3, bottom, bl, br] = await Promise.all([
      F(this.hasTitle ? 0 : 2), F(1), F(3), F(4), F(5), F(this.hasFooter ? 126 : 2), F(8), F(9),
    ]);
    if (!top || !side) return;
    const W = this.size[0], H = this.size[1];
    const sideW = side.w;
    const topH = top.h, botH = bottom.h;
    const css = (f, x, y, w, h, repeat = 'no-repeat') =>
      `url(${f.url}) ${repeat} ${x}px ${y}px / ${w}px ${h}px`;
    this.el.style.background = [
      css(bl, 0, H - bl.h, bl.w, bl.h),
      css(br, W - br.w, H - br.h, br.w, br.h),
      css(bottom, 0, H - botH, W, botH, 'repeat-x'),
      this.hasTitle ? css(t2, sideW, topH, Math.max(0, W - sideW * 2), t2.h, 'repeat') : '',
      css(side, 0, topH, sideW, Math.max(0, H - topH), 'repeat-y'),
      css(side, W - sideW, topH, sideW, Math.max(0, H - topH), 'repeat-y'),
      css(top, 0, 0, W, topH, 'repeat-x'),
    ].filter(Boolean).join(',');
    this.el.style.imageRendering = 'pixelated';
  }
}
