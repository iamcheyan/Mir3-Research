// themes/zircon/game.js — Ziron 模式 GameScene (MainPanel.cs + ChatTextBox.cs 移植)
// 世界逻辑在共享 world.js; 本文件只做 HUD 外观 (GameInter 贴图 + DXControl)。
import { DXImageControl, DXLabel, DXButton, DXTextInput, DXControl } from '../../dx.js';
import { skin } from '../../skin.js';
import { World } from '../../world.js';

export class GameScene {
  constructor(conn, startInfo) {
    this.conn = conn;
    this.info = startInfo;
    this.chatLines = [];
    this.root = document.createElement('div');
    this.root.style.cssText = 'position:absolute;inset:0;background:#000;';
    this.canvas = document.createElement('canvas');
    this.canvas.style.cssText = 'position:absolute;left:0;top:0;width:100%;height:100%;image-rendering:pixelated;';
    this.root.appendChild(this.canvas);
    this.hud = document.createElement('div');
    this.hud.style.cssText = 'position:absolute;inset:0;pointer-events:none;';
    this.hudLayer = new DXControl({ size: [1024, 768], isControl: true });
    this.hud.appendChild(this.hudLayer.el);

    this.world = new World(conn, startInfo, this.canvas, {
      onChat: (text, type) => this.addChat(text, type),
      onPosChange: () => this.#updatePos(),
    });
    // 代理共享字段 (HUD/调试读取)
    for (const k of ['player', 'objects', 'stem', 'mapMeta', 'moveLock']) {
      Object.defineProperty(this, k, { get: () => this.world[k] });
    }
    this.#buildHud();
  }

  async #buildHud() {
    const h = this.hudLayer;
    // 主面板 GameInter[50] (MainPanel.cs:31-34)
    this.mainPanel = new DXImageControl({ library: 'GameInter', index: 50, isControl: false });
    h.addControl(this.mainPanel);
    await new Promise(r => setTimeout(r, 50)); // 等贴图 size 解析
    const ps = this.mainPanel.size;
    // LayoutHud (GameScene.cs:4713-4718): 底部居中
    this.mainPanel.location = [Math.max(0, Math.trunc((1024 - ps[0]) / 2)), Math.max(0, 768 - ps[1])];
    this.mainPanel.applyBase();
    this.panelOrigin = this.mainPanel.location;

    // 血/蓝/专注条 (MainPanel.cs:41-43 CreateBar 35,22/35,36/35,50)
    this.healthFill = await this.#bar(35, 22, 52);
    this.manaFill = await this.#bar(35, 36, 54);
    // 经验条 GameInter[51] (MainPanel.cs:36-38)
    const expBar = new DXImageControl({ library: 'GameInter', index: 51, isControl: false,
      location: [Math.trunc((ps[0] - 0) / 2) + 1, 3] });
    skin.frame('GameInter', 51).then(f => { if (f) { expBar.location = [Math.trunc((ps[0] - f.w) / 2) + 1, 3]; expBar.applyBase(); } });
    this.mainPanel.addControl(expBar);

    // 9 宫功能按钮 (MainPanel.cs:47-55)
    const BTN = [[82, '角色'], [87, '背包'], [92, '技能'], [112, '任务'], [97, '邮件'],
                 [107, '药品'], [102, '组队'], [117, '菜单'], [122, '商城']];
    const XS = [650, 689, 728, 767, 806, 845, 884, 923, 972];
    BTN.forEach(([idx, name], i) => {
      const b = new DXImageControl({
        library: 'GameInter', index: idx, location: [XS[i], i === 8 ? 16 : 23],
        onClick: () => this.addChat(`${name}窗口: Phase 3 点亮`, 'hint'),
      });
      b.el.style.cursor = 'pointer';
      b.el.style.pointerEvents = 'auto';
      this.mainPanel.addControl(b);
    });

    // 聊天记录面板 (ChatLogPanel.cs: 400x150, 位于主面板上方-29)
    const chatLog = new DXControl({
      size: [400, 150],
      location: [this.panelOrigin[0], this.panelOrigin[1] - 150 - 29],
      backColour: [0, 0, 0, 89], clip: true,
    });
    h.addControl(chatLog);
    this.chatLogEl = document.createElement('div');
    this.chatLogEl.style.cssText =
      `position:absolute;inset:2px;overflow:hidden;display:flex;flex-direction:column;justify-content:flex-end;` +
      `font:12px/1.35 'Noto Sans CJK SC','Noto Sans CJK',sans-serif;color:#eee;text-shadow:1px 1px 0 #000;`;
    chatLog.el.appendChild(this.chatLogEl);

    // 聊天输入框 (ChatTextBox.cs:43-70: 400x25 Opacity .6)
    const chatBox = new DXControl({
      size: [400, 25],
      location: [this.panelOrigin[0], this.panelOrigin[1] - 25 - 2],
      backColour: [0, 0, 0, 89],
    });
    chatBox.el.style.pointerEvents = 'auto';
    h.addControl(chatBox);
    const modeBtn = new DXButton({
      text: '喊话', fontSize: 9, library: 'Interface', index: -1,
      location: [0, 0], size: [60, 24],
      onClick: () => this.addChat('频道切换: Phase 3 实现', 'hint'),
    });
    chatBox.addControl(modeBtn);
    this.chatInput = new DXTextInput({ location: [65, 1], size: [275, 23], fontSize: 9 });
    chatBox.addControl(this.chatInput);
    this.chatInput.input.addEventListener('keydown', (ev) => {
      if (ev.key === 'Enter') {
        const t = this.chatInput.text.trim();
        if (t) { this.conn.sendChat(t); this.chatInput.text = ''; }
        this.chatInput.input.blur();
      } else if (ev.key === 'Escape') {
        this.chatInput.input.blur();
      }
    });

    // 世界坐标显示 (调试, 对应 Godot DebugLabel)
    this.posLabel = new DXLabel({
      fontSize: 9, textColour: [255, 255, 255, 255], drawOutline: true,
      location: [8, 8], size: [400, 16], isControl: false,
    });
    h.addControl(this.posLabel);

    // 血/蓝满条 (MaxHP 未知前; Phase2 StatsUpdate 接入)
    this.setBarPct(this.healthFill, 1);
    this.setBarPct(this.manaFill, 1);
  }

  async #bar(x, y, fillIndex) {
    const sizeF = await skin.frame('GameInter', fillIndex);
    const bar = new DXControl({
      location: [x, y], size: [sizeF?.w ?? 120, sizeF?.h ?? 8], clip: true, isControl: false,
    });
    this.mainPanel.addControl(bar);
    const fill = await skin.frame('GameInter', fillIndex);
    if (fill) {
      const img = document.createElement('img');
      img.src = fill.url;
      img.style.cssText = `position:absolute;left:0;top:0;height:100%;image-rendering:pixelated;`;
      bar.el.appendChild(img);
      bar.el.style.pointerEvents = 'none';
      return { el: img, w: fill.w };
    }
    return null;
  }

  setBarPct(bar, pct) {
    if (bar) bar.el.style.width = `${Math.round(bar.w * Math.min(1, Math.max(0, pct)))}px`;
  }

  #updatePos() {
    const p = this.world.player;
    if (p && this.posLabel)
      this.posLabel.text = `${this.world.mapMeta?.name_cn ?? this.world.stem} ${p.x},${p.y}`;
  }

  addChat(text, type = 'say') {
    this.chatLines.push({ text, type, t: Date.now() });
    if (this.chatLines.length > 250) this.chatLines.shift();
    if (this.chatLogEl) {
      const div = document.createElement('div');
      div.textContent = text;
      if (type === 'hint' || type === 'system') div.style.color = '#ffd573';
      this.chatLogEl.appendChild(div);
      while (this.chatLogEl.childElementCount > 12) this.chatLogEl.firstChild.remove();
    }
  }
}
