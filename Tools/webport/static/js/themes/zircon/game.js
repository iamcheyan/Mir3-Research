// game.js — Zircon 模式 GameScene (主 HUD 编排; par-hud C 路)
// 世界逻辑在共享 world.js; 本文件 = CreateHud/LayoutHud (GameScene.cs:4264-4846)
// + MainPanel/ChatTextBox/MiniMap 数据注入 (InitHudData/On* 处理器对照)。
// 控件实现: hud.js (MainPanel/MiniMap) + chat.js (ChatTextBox/ChatLogPanel)。
import { DXControl, DXLabel, DXImageControl } from '../../dx.js';
import { WindowManager, UiScaleNow, setUiScale } from '../../windows.js';
import { statsToObj, STAT, MsgTypeName, MsgTypeColour, MSG, C } from '../../net.js';
import { MainPanel, MiniMapDialog, fallbackWindow } from './hud.js';
import { ChatTextBox, ChatLogPanel } from './chat.js';

const BASE_W = 1024, BASE_H = 768;

export class GameScene {
  constructor(conn, startInfo) {
    this.conn = conn;
    this.info = startInfo;
    this.attackMode = startInfo.attackMode ?? 0;
    this.petMode = startInfo.petMode ?? 0;
    this.gameStoreItems = [];
    this._openWins = new Map();     // type → DXWindow (懒建)

    this.root = document.createElement('div');
    this.root.style.cssText = 'position:absolute;inset:0;background:#000;';
    this.canvas = document.createElement('canvas');
    this.canvas.style.cssText = 'position:absolute;left:0;top:0;width:100%;height:100%;image-rendering:pixelated;';
    this.root.appendChild(this.canvas);
    this.hud = document.createElement('div');
    this.hud.style.cssText = 'position:absolute;inset:0;pointer-events:none;';
    this.hudLayer = new DXControl({ size: [BASE_W, BASE_H], isControl: true });
    this.hud.appendChild(this.hudLayer.el);

    this.world = new World(conn, startInfo, this.canvas, {
      onChat: (text, type) => this.#receiveChat(text, type),
      onPosChange: () => this.#updatePos(),
      onMapChange: (m) => this.#onMapChange(m),
      onStats: () => this.#refreshBars(),
      onRawStats: (d) => this.#onRawStats(d),
      onTarget: (o) => { if (o) this.#receiveChat(`选中: ${o.name}${o.dead ? ' (尸体)' : ''}`, 'hint'); },
    });
    for (const k of ['player', 'objects', 'stem', 'mapMeta', 'moveLock']) {
      Object.defineProperty(this, k, { get: () => this.world[k] });
    }
    this.#buildHud();
    this.#wireNet();
  }

  // ---- CreateHud (GameScene.cs:4264-4468) ----
  async #buildHud() {
    // MainPanel: 底中 (LayoutHud GameScene.cs:4712-4715)
    this.mainPanel = new MainPanel({
      onButton: (name) => this.#onMainButton(name),
    });
    this.hudLayer.addControl(this.mainPanel);
    this.mainPanel._panelReady?.then(() => this.#layoutHud());

    // InitHudData (GameScene.cs:4927-5021)
    const info = this.info;
    this.mainPanel.setLevel(info.level);
    this.mainPanel.setClass(info.class);
    this.mainPanel.setHealth(info.currentHP ?? info.hp ?? 0);
    this.mainPanel.setMana(info.currentMP ?? info.mp ?? 0);
    this.mainPanel.setExperience(info.experience ?? 0, 0);

    // ChatLogPanel: 主面板上方 (LayoutHud GameScene.cs:4720-4723)
    this.chatLog = new ChatLogPanel();
    this.hudLayer.addControl(this.chatLog);
    // ChatTextBox: 主面板正上 (LayoutHud GameScene.cs:4724-4727)
    this.chatBox = new ChatTextBox({
      selfName: info.name,
      onSend: (text, linked) => this.#sendChat(text, linked),
      onOptions: () => this.#openWindow('chatoptions'),
    });
    this.hudLayer.addControl(this.chatBox);

    // MiniMap: 右上 (LayoutHud GameScene.cs:4728-4730)
    this.miniMap = new MiniMapDialog({
      uiScale: UiScaleNow,
      onBigMap: () => this.#openWindow('bigmap'),
    });
    this.miniMap.setGM(!!this.conn.isGM);
    this.miniMap.onTeleport = (x, y, mapIndex) => {
      // GM 点击小地图传送 (MiniMapDialog.cs:148 SendTeleportRing)
      this.conn.send(C.TeleportRing(x, y, mapIndex));
    };
    this.hudLayer.addControl(this.miniMap);
    this.miniMap.visible = true;
    if (this.world.mapMeta) this.#applyMiniMap();

    // 世界坐标显示 (调试, 对应 Godot DebugLabel)
    this.posLabel = new DXLabel({
      fontSize: 9, textColour: [255, 255, 255, 255], drawOutline: true,
      location: [8, 8], size: [400, 16], isControl: false,
    });
    this.hudLayer.addControl(this.posLabel);

    this.#layoutHud();
    this.#bindGlobalKeys();
  }

  // LayoutHud (GameScene.cs:4698-4846) — 1024x768 逻辑画布
  #layoutHud() {
    const mp = this.mainPanel, vp = [BASE_W, BASE_H];
    if (mp && mp.size[0]) {
      mp.location = [Math.max(0, Math.trunc((vp[0] - mp.size[0]) / 2)), Math.max(0, vp[1] - mp.size[1])];
      this.panelOrigin = [...mp.location];
      if (this.chatLog) this.chatLog.location = [Math.max(0, mp.location[0]), Math.max(0, mp.location[1] - this.chatLog.size[1] - 29)];
      if (this.chatBox) this.chatBox.location = [Math.max(0, mp.location[0]), Math.max(0, mp.location[1] - this.chatBox.size[1] - 2)];
    }
    if (this.miniMap) this.miniMap.location = [Math.max(0, vp[0] - this.miniMap.size[0]), 0];
  }

  // ---- 主面板 9 键 → 窗口开关 (GameScene.cs:4432-4463 CreateHud 绑定) ----
  #onMainButton(name) {
    const MAP = {
      character: 'character', inventory: 'inventory', spell: 'spell', quest: 'quest',
      mail: 'mail', belt: 'belt', group: 'group', menu: 'menu', cashshop: 'cashshop',
    };
    const type = MAP[name];
    if (type) this.#openWindow(type);
  }

  // 窗口统一入口: par-win 注册 → ui_tree; 未注册 → fallbackWindow (真实数据)
  #openWindow(type) {
    let w = this._openWins.get(type);
    if (!w) {
      w = window.__WEBPORT_WIN?.(type, this) ?? fallbackWindow(type, this); // par-win 接口层
      this._openWins.set(type, w);
      w.onClose = () => {};
    }
    WindowManager.toggle(w, this.hudLayer);
    if (w.visible && type === 'spell' && w.refresh) w.refresh();
  }

  // ---- 聊天 (GameScene.cs SendChat:287-308 / OnChat:2536-2545) ----
  #sendChat(text, linked) {
    if (!text || !text.trim()) return;
    this.conn.sendChat(text.trim());  // C.Chat (LinkedItemIndexes 附加见 net.js C.Chat)
  }

  #receiveChat(text, type = 'say', sender = '') {
    // OnChat 行格式: [频道] 发送者: 文本 (GameScene.cs:2541)
    const t = MSG[type?.toUpperCase?.()] ?? (typeof type === 'number' ? type : MSG.NORMAL);
    const label = MsgTypeName[t] ?? '';
    const line = label || sender ? `${label} ${sender ? sender + ': ' : ''}${text}` : text;
    this.chatLog?.addMessage(line, t, MsgTypeColour[t] ?? '#ffffff');
  }

  // ---- 网络事件 → HUD (GameScene On* 处理器对照) ----
  #wireNet() {
    const c = this.conn;
    c.addEventListener('chat', (e) => {
      const p = e.detail;
      const o = this.world.objects.get(p.objectID);
      const sender = o?.name ?? (p.objectID === this.info.objectID ? this.info.name : '系统');
      this.#receiveChat(p.text, p.type, sender);
    });
    c.addEventListener('levelChanged', (e) => {   // OnLevelChanged (GameScene.cs:5071-5078)
      const p = e.detail;
      this.mainPanel.setLevel(p.level);
      this.mainPanel.setExperience(p.experience, p.maxExperience);
    });
    c.addEventListener('gainedExperience', (e) => { // OnGainedExperience (5080-5084)
      this._exp = (this._exp ?? this.info.experience ?? 0) + (e.detail.amount ?? 0);
      this.mainPanel.setExperience(this._exp, this._maxExp ?? 0);
    });
    c.addEventListener('informMaxExperience', (e) => { // OnInformMaxExperience (5086-5090)
      this._maxExp = e.detail.maxExperience ?? 0;
      this.mainPanel.setExperience(this._exp ?? this.info.experience ?? 0, this._maxExp);
    });
    c.addEventListener('manaChanged', (e) => {    // OnManaChanged (5093-5098)
      if (e.detail.objectID !== this.info.objectID) return;
      this._mp = Math.max(0, (this._mp ?? this.info.currentMP ?? 0) + e.detail.change);
      this.mainPanel.setMana(this._mp);
    });
    c.addEventListener('focusChanged', (e) => {   // OnFocusChanged (5100-5105)
      if (e.detail.objectID !== this.info.objectID) return;
      this._fp = Math.max(0, (this._fp ?? this.info.currentFP ?? 0) + e.detail.change);
      this.mainPanel.setFocus(this._fp);
    });
    c.addEventListener('changeAttackMode', (e) => { this.attackMode = e.detail.mode; });
    c.addEventListener('changePetMode', (e) => { this.petMode = e.detail.mode; });
    c.addEventListener('timeOfDayChanged', (e) => this.miniMap?.setTimeOfDay(e.detail.timeOfDay));
    c.addEventListener('gameStoreTopItems', (e) => { this.gameStoreItems = e.detail.items ?? []; });
  }

  #onRawStats(d) { // OnStatsUpdate (GameScene.cs:5031-5043)
    const s = statsToObj(d.stats);
    this.lastStats = s;
    const maxHp = s[STAT.HEALTH] ?? 0, maxMp = s[STAT.MANA] ?? 0;
    this.mainPanel.setMaxHealth(maxHp);
    this.mainPanel.setMaxMana(maxMp);
    this.mainPanel.setStats({
      MINAC: s[STAT.MINAC], MAXAC: s[STAT.MAXAC], MINMR: s[STAT.MINMR], MAXMR: s[STAT.MAXMR],
      MINDC: s[STAT.MINDC], MAXDC: s[STAT.MAXDC], MINMC: s[STAT.MINMC], MAXMC: s[STAT.MAXMC],
      MINSC: s[STAT.MINSC], MAXSC: s[STAT.MAXSC], FP: s[44] ?? '', CP: s[45] ?? '',
    });
    this.#refreshBars();
  }

  // RefreshPlayerBars (GameScene.cs:5023-5029): world player hp/mp → MainPanel
  #refreshBars() {
    const p = this.world.player;
    if (!p || !this.mainPanel) return;
    if (p.hp != null) this.mainPanel.setHealth(p.hp);
    if (p.mp != null) this.mainPanel.setMana(p.mp);
  }

  #updatePos() {
    const p = this.world.player;
    if (p && this.posLabel)
      this.posLabel.text = `${this.world.mapMeta?.name_cn ?? this.world.stem} ${p.x},${p.y}`;
    if (p && this.miniMap && this.miniMap.mapWidth) this.miniMap.updatePlayer(p.x, p.y);
  }

  async #onMapChange(mapMeta) {
    this.#applyMiniMap();
  }

  async #applyMiniMap() {
    const m = this.world.mapMeta;
    if (!m || !this.miniMap) return;
    const npcs = (await import('../../data.js')).D().npcs ?? [];
    await this.miniMap.setMap(m, this.world.stem, this.info.objectID, npcs);
    this.miniMap.setTimeOfDay(this.info.timeOfDay ?? 1);
    const p = this.world.player;
    if (p) this.miniMap.updatePlayer(p.x, p.y);
    this.#layoutHud();
  }

  // ---- 全局键 (GameScene _Input → ChatTextBox.HandleGlobalKey + KeyBind 窗口) ----
  #bindGlobalKeys() {
    this._keyHandler = (ev) => {
      // 聊天框已聚焦: 只拦分发 (ChatTextBox.cs:128)
      if (this.chatBox?.handleGlobalKey?.(ev)) { ev.preventDefault(); return; }
      if (ev.repeat) return;
      // Esc: 关最上层窗口 (WindowManager)
      if (ev.code === 'Escape') { if (WindowManager.closeTop()) ev.preventDefault(); return; }
    };
    addEventListener('keydown', this._keyHandler);
  }

  addChat(text, type = 'say') { this.#receiveChat(text, type); }

  dispose() {
    if (this._keyHandler) removeEventListener('keydown', this._keyHandler);
  }
}
