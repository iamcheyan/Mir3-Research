// game.js — Zircon 模式 GameScene (主 HUD 编排; par-hud C 路)
// 世界逻辑在共享 world.js; 本文件 = CreateHud/LayoutHud (GameScene.cs:4264-4846)
// + MainPanel/ChatTextBox/MiniMap 数据注入 (InitHudData/On* 处理器对照)。
// 控件实现: hud.js (MainPanel/MiniMap) + chat.js (ChatTextBox/ChatLogPanel)。
import { DXControl, DXLabel, DXImageControl } from '../../dx.js';
import { World } from '../../world.js';
import { WindowManager, UiScaleNow, setUiScale } from '../../windows.js';
import { statsToObj, STAT, MsgTypeName, MsgTypeColour, MSG, C } from '../../net.js';
import { getAction, KeyBindAction as KA } from '../../keybinds.js';
import { installWindows } from '../../win-registry.js';
import { MainPanel, MiniMapDialog, fallbackWindow, BuffDialog, QuestTracker } from './hud.js';
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
    this.hudLayer = new DXControl({ size: [BASE_W, BASE_H], isControl: false }); // 根层 MouseFilter.IGNORE; 交互由子控件自理
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
    this._winInstall = installWindows(this);   // par-win 15 模块并行安装 (异步, 不阻塞 HUD)
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
    WindowManager.open(this.miniMap, this.hudLayer);   // DXWindow 语义: 入 WindowManager (Esc/M 可关)

    // BuffDialog: 小地图左侧 (GameScene.cs:4732 LayoutHud + BuffDialog.LayoutNeeded)
    this.buffDialog = new BuffDialog();
    this.hudLayer.addControl(this.buffDialog);
    this._selfBuffs = new Map();
    for (const b of this.info.buffs ?? []) if (b) this._selfBuffs.set(b.index, b);
    this.#refreshBuffs();

    // QuestTracker: 小地图下方 (QuestTrackerDialog.cs)
    this.questTracker = new QuestTracker();
    this.hudLayer.addControl(this.questTracker);
    this._winInstall?.then?.((reg) => {
      const store = reg?.itemStore ?? this.itemStore;
      const off = store.on(() => this.#refreshQuests());
      this._qtOff = off;
      this.#refreshQuests();
    });
    if (this.world.mapMeta) { clearInterval(this._mmWait); this.#applyMiniMap(); }
    // world 数据异步加载: 首图 meta 未就绪时, 等 enterWorld 完成后再挂小地图
    this._mmWait = setInterval(() => {
      if (this.world.mapMeta) { clearInterval(this._mmWait); this.#applyMiniMap(); }
    }, 300);
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
    // BuffDialog 锚小地图左侧; QuestTracker 锚小地图下方 (GameScene.cs:4731-4736)
    if (this.buffDialog) this.buffDialog.location = [Math.max(4, (this.miniMap?.location?.[0] ?? vp[0]) - this.buffDialog.size[0] - 8), 0];
    if (this.questTracker) this.questTracker.location = [Math.max(0, vp[0] - this.questTracker.size[0] - 4), (this.miniMap?.location?.[1] ?? 0) + (this.miniMap?.size?.[1] ?? 0) + 8];
  }

  // ---- Buffs (GameScene.cs:5107-5159 OnBuff*) ----
  #refreshBuffs() {
    if (!this.buffDialog) return;
    this.buffDialog.buffsChanged([...this._selfBuffs.values()]);
    this.#layoutHud();   // BuffDialog.LayoutNeeded → 重锚 (BuffDialog.cs:23)
  }

  async #refreshQuests() {
    if (!this.questTracker) return;
    const store = this.itemStore;
    const questInfo = (i) => import('../../gamedb.js').then(m => m.GameDB.questInfo(i)).catch(() => null);
    await this.questTracker.refresh(store?.quests, questInfo);
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
  async #openWindow(type) {
    let w = this._openWins.get(type);
    if (!w) {
      // par-win 模块安装是异步的 (ui_tree 逐窗构建); 首次开窗等它就绪再决定接管/兜底
      try { await this._winInstall; } catch { /* 安装失败走兜底 */ }
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
      if (p.overheadOnly) return;   // 仅头顶气泡, 不进日志 (GameScene.cs:2538)
      const o = this.world.objects.get(p.objectID);
      const sender = o?.name ?? (p.objectID === this.info.objectID ? this.info.name : '系统');
      this.#receiveChat(p.text, p.type, sender);
    });
    c.addEventListener('buffAdd', (e) => {       // OnBuffAdd (GameScene.cs:5107)
      if (e.detail?.buff) { this._selfBuffs.set(e.detail.buff.index, e.detail.buff); this.#refreshBuffs(); }
    });
    c.addEventListener('buffRemove', (e) => {    // OnBuffRemove
      this._selfBuffs.delete(e.detail.index); this.#refreshBuffs();
    });
    c.addEventListener('buffTime', (e) => {      // OnBuffTime: 服务端校时
      const b = this._selfBuffs.get(e.detail.index);
      if (b) { b.remainingTime = e.detail.time; this.#refreshBuffs(); }
    });
    c.addEventListener('buffPaused', (e) => {    // OnBuffPaused
      const b = this._selfBuffs.get(e.detail.index);
      if (b) { b.pause = e.detail.paused; this.#refreshBuffs(); }
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

  // ---- 全局键 (GameScene._Input:9842 → ChatTextBox.HandleGlobalKey → GetAction 分发) ----
  #bindGlobalKeys() {
    // KeyBindAction → 窗口类型 (fallbackWindow/par-win __WEBPORT_WIN 通用小写类型)
    const WIN = {
      [KA.MenuWindow]: 'menu', [KA.HelpWindow]: 'help', [KA.ConfigWindow]: 'config',
      [KA.CharacterWindow]: 'character', [KA.InventoryWindow]: 'inventory',
      [KA.MagicWindow]: 'spell', [KA.MagicBarWindow]: 'spell',
      [KA.DungeonFinderWindow]: 'dungeonfinder', [KA.StorageWindow]: 'storage',
      [KA.BeltWindow]: 'belt', [KA.AutoPotionWindow]: 'autopotion',
      [KA.CurrencyWindow]: 'currency', [KA.FilterDropWindow]: 'filterdrop',
      [KA.FortuneWindow]: 'fortune', [KA.QuestTrackerWindow]: 'questtracker',
      [KA.MapBigWindow]: 'bigmap', [KA.RankingWindow]: 'ranking',
      [KA.GameStoreWindow]: 'cashshop', [KA.CompanionWindow]: 'companion',
      [KA.GroupWindow]: 'group', [KA.GuildWindow]: 'guild',
      [KA.MailBoxWindow]: 'mail', [KA.MailSendWindow]: 'mail', [KA.BlockListWindow]: 'mail',
      [KA.QuestLogWindow]: 'quest', [KA.ChatOptionsWindow]: 'chatoptions',
      [KA.ExitGameWindow]: 'exit',
    };
    this._keyHandler = (ev) => {
      // 聊天框已聚焦: 只拦分发 (ChatTextBox.cs:128 HandleGlobalKey 先于键位)
      if (this.chatBox?.handleGlobalKey?.(ev)) { ev.preventDefault(); return; }
      if (ev.repeat) return;
      // Escape: 先关最上层窗口; 真关掉才拦截 (GameScene.cs:9855 CloseTop 语义)
      if (ev.code === 'Escape') {
        if (WindowManager.closeTop()) { ev.preventDefault(); return; }
      }
      const a = getAction(ev);
      if (!a) return;
      ev.preventDefault();
      if (WIN[a]) return this.#openWindow(WIN[a]);
      switch (a) {
        case KA.MapMiniWindow: return WindowManager.toggle(this.miniMap, this.hudLayer);
        case KA.ItemPickUp: return this.conn.sendPickUp();
        case KA.GroupAllowSwitch:
          this.allowGroup = !this.allowGroup;
          this.conn.sendGroupSwitch(this.allowGroup);
          return this.addChat(`允许组队: ${this.allowGroup ? '开' : '关'}`, 'hint');
        case KA.GroupTarget: {
          // 组队协助: 以当前目标为协助对象 (GroupDialog.cs GroupTarget 语义)
          const t = this.world.target;
          if (!t) return this.addChat('没有选中目标', 'hint');
          return this.addChat(`协助目标: ${t.name}`, 'hint');
        }
        case KA.TradeRequest:
          if (!this.world.target) return this.addChat('先选中交易对象', 'hint');
          return this.conn.sendTradeRequest();
        case KA.TradeAllowSwitch:
          this.allowTrade = !this.allowTrade;
          return this.addChat(`允许交易: ${this.allowTrade ? '开' : '关'}`, 'hint');
        case KA.PartnerTeleport: return this.conn.sendMarriageTeleport();
        case KA.MountToggle: return this.conn.sendMount();
        case KA.AutoRunToggle: {
          const mw = this.world.mouseWalker;
          if (mw) { mw.autoRun = !mw.autoRun; this.addChat(`自动跑步: ${mw.autoRun ? '开' : '关'}`, 'hint'); }
          return;
        }
        case KA.ChangeChatMode: return this.chatBox?.cycleMode?.();
        case KA.ToggleItemLock:
          // Godot: 锁定当前选中物品格 (LockItem); 无选中 = 无操作
          return void this.#toggleItemLock();
        case KA.ChangeAttackMode:
          this.attackMode = ((this.attackMode ?? 0) + 1) % 5;
          this.conn.sendChangeAttackMode(this.attackMode);
          return this.addChat(`攻击模式: ${['全体', '和平', '组队', '行会', '善恶'][this.attackMode]}`, 'hint');
        case KA.ChangePetMode:
          this.petMode = ((this.petMode ?? 0) + 1) % 5;
          this.conn.sendChangePetMode(this.petMode);
          return this.addChat(`宠物模式: ${['全体', '和平', '组队', '行会', '善恶'][this.petMode]}`, 'hint');
        default: {
          if (a >= KA.SpellSet01 && a <= KA.SpellSet04) return this.world.setSpellSet(a - KA.SpellSet01 + 1);
          if (a >= KA.SpellUse01 && a <= KA.SpellUse24) return this.world.useMagicSlot(a - KA.SpellUse01);
          if (a >= KA.UseBelt01 && a <= KA.UseBelt10) return this.world.useBeltSlot(a - KA.UseBelt01);
        }
      }
    };
    addEventListener('keydown', this._keyHandler);
  }
  // par-win dxgrid / uitree 两套 DXItemCell 的选中格 → 锁定 (ToggleItemLock)
  async #toggleItemLock() {
    for (const mod of ['/static/js/dxgrid.js', '/static/js/uitree.js']) {
      try {
        const m = await import(mod);
        const c = m.DXItemCell?.SelectedCell;
        if (c && c.grid != null && c.slot >= 0) {
          this.conn.sendItemLock(c.grid, c.slot, !c.item?.locked);
          return;
        }
      } catch { /* 模块缺失时忽略 */ }
    }
    this.addChat('先在物品栏选中物品', 'hint');
  }

  addChat(text, type = 'say') { this.#receiveChat(text, type); }

  dispose() {
    if (this._keyHandler) removeEventListener('keydown', this._keyHandler);
  }
}
