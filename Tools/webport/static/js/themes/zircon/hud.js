// hud.js — par-hud C 路: MainPanel.cs + MiniMapDialog.cs 逐方法移植
// 行为权威: GodotClient/Controls/MainPanel.cs, MiniMapDialog.cs (行号随注)。
// 按钮/坐标: MainPanel.cs CreateButton/CreateStatImage 原值; Interface.Zl→WebP 帧号经 skin.js。
import { DXControl, DXImageControl, DXLabel, DXButton } from '../../dx.js';
import { skin } from '../../skin.js';
import { DXWindow, WindowManager, setHint } from '../../windows.js';
import { getKeyBindLabel, KeyBindAction } from '../../keybinds.js';
import { CLASS_NAMES, C } from '../../net.js';

const F = (lib, idx) => skin.frame(lib, idx);
const rgba = (c) => `rgba(${c[0]},${c[1]},${c[2]},${(c[3] ?? 255) / 255})`;

// Lang.MainPanel*Hint (ChineseMessages.cs:620-629): {0}=键位标签
const HINT = (s, a) => s.replace('{0}', getKeyBindLabel(a));

function fmtRange(min, max) { // Stats.GetFormat: min==max → 单值
  if (min == null) return max != null ? String(max) : '';
  return min === max ? String(max) : `${min}-${max}`;
}

// ====================================================================
// MainPanel (MainPanel.cs:15-384)
// ====================================================================
export class MainPanel extends DXImageControl {
  constructor(opts = {}) {
    super({ library: 'GameInter', index: 50, isControl: false }); // MainPanel.cs:33-34
    this.onButton = opts.onButton ?? (() => {}); // 9 功能键 → game.js 开窗

    this._hp = 0; this._mp = 0; this._fp = 0;
    this._maxHp = 0; this._maxMp = 0; this._maxFp = 0;
    this._experience = 0; this._maxExperience = 0;
    this._level = 0; this._class = 0;
    this._barEls = {};

    // ExperienceBar (MainPanel.cs:36-39): GameInter[51] 居中 y=3
    this.experienceBar = new DXImageControl({ library: 'GameInter', index: 51, isControl: false, location: [1, 3] });
    this.addControl(this.experienceBar);
    this._panelReady = F('GameInter', 50).then(async (panel) => {
      const f = await F('GameInter', 51);           // 经验条底 (MainPanel.cs:36)
      if (f && panel) {
        this.experienceBar.location = [Math.trunc((panel.w - f.w) / 2) + 1, 3];
        this.experienceBar.applyBase();
      }
      const fill = await F('GameInter', 56);        // 填充 GameInter[56] 水平居中 (MainPanel.cs:201-216)
      if (fill) {
        const wrap = document.createElement('div');
        wrap.style.cssText =
          `position:absolute;left:${Math.trunc((this.experienceBar.size[0] - fill.w) / 2)}px;` +
          `top:${Math.trunc((this.experienceBar.size[1] - fill.h) / 2) - 1}px;` +
          `width:${fill.w}px;height:${fill.h}px;overflow:hidden;`;
        const img = document.createElement('img');
        img.src = fill.url;
        img.style.cssText = 'position:absolute;left:0;top:0;height:100%;image-rendering:pixelated;';
        wrap.appendChild(img);
        this.experienceBar.el.appendChild(wrap);
        this._barEls.exp = { img, w: fill.w };
        this.#paintExp();
      }
    });

    // 三条 (MainPanel.cs:41-43): CreateBar(x,y,sizeIdx,fillIdx,percent,glow)
    this.#createBar('health', 35, 22, 52, 52, 59);   // HP: 填充52 满时辉光59
    this.#createBar('mana', 35, 36, 52, 54, -1);     // MP
    this.#createBar('focus', 35, 50, 58, 58, -1);    // FP (FocusBar.Visible 由 SetFocus 控制)

    // 9 宫功能按钮 (MainPanel.cs:47-55 CreateButton(图标,x,y) 原值)
    const BTN = [
      ['character', 82, 650, 23, '角色 [{0}]', KeyBindAction.CharacterWindow],
      ['inventory', 87, 689, 23, '背包 [{0}]\n宠物 [{0}]', KeyBindAction.InventoryWindow],
      ['spell', 92, 728, 23, '技能 [{0}]', KeyBindAction.MagicWindow],
      ['quest', 112, 767, 23, '任务 [{0}]', KeyBindAction.QuestLogWindow],
      ['mail', 97, 806, 23, '聊天 [{0}]', KeyBindAction.MailBoxWindow],
      ['belt', 107, 845, 23, '腰带 [{0}]', KeyBindAction.BeltWindow],
      ['group', 102, 884, 23, '编组 [{0}]', KeyBindAction.GroupWindow],
      ['menu', 117, 923, 23, '菜单 [{0}]', KeyBindAction.MenuWindow],
      ['cashshop', 122, 972, 16, '商铺 [{0}]', KeyBindAction.GameStoreWindow],
    ];
    this.buttons = {};
    for (const [name, idx, x, y, hint, action] of BTN) {
      const b = new DXImageControl({
        library: 'GameInter', index: idx, location: [x, y],
        onClick: () => this.onButton(name),
      });
      b.el.style.cursor = 'pointer';
      setHint(b, HINT(hint, action));
      this.addControl(b);
      this.buttons[name] = b;
    }

    // 邮件/任务角标 (MainPanel.cs:70-103): GameInter 240/241 @2,2
    this.newMailIcon = this.#attachBadge(this.buttons.mail, 240);
    this.availableQuestIcon = this.#attachBadge(this.buttons.quest, 240);
    this.completedQuestIcon = this.#attachBadge(this.buttons.quest, 241);

    // 属性图标 (MainPanel.cs:105-115 CreateStatImage)
    const STATS = [
      ['classImage', 70, 277, 25], ['levelImage', 71, 277, 45],
      ['fpImage', 72, 362, 25], ['cpImage', 73, 362, 45],
      ['acImage', 66, 445, 25], ['dcImage', 65, 445, 45],
      ['macImage', 63, 531, 25], ['mcImage', 62, 541, 45], ['scImage', 64, 547, 45],
    ];
    for (const [key, idx, x, y] of STATS) {
      const img = new DXImageControl({ library: 'GameInter', index: idx, location: [x, y], isControl: false });
      this.addControl(img);
      this[key] = img;
    }
    setHint(this.classImage, '职'); setHint(this.levelImage, '级');
    setHint(this.fpImage, '战斗力'); setHint(this.cpImage, '贡献');
    setHint(this.acImage, '物理防御'); setHint(this.dcImage, '物理攻击');
    setHint(this.macImage, '魔法防御'); setHint(this.mcImage, '魔法攻击'); setHint(this.scImage, '道术攻击');

    // 属性标签 (MainPanel.cs:124-132 CreateStatLabel 60x16 居中)
    const mkLabel = (x, y) => {
      const l = new DXLabel({
        fontSize: 8, textColour: [255, 255, 255, 255], location: [x, y], size: [60, 16],
        align: 'center', valign: 'center', isControl: false,
      });
      this.addControl(l);
      return l;
    };
    this.classLabel = mkLabel(300, 22); this.levelLabel = mkLabel(300, 42);
    this.fpLabel = mkLabel(385, 22); this.cpLabel = mkLabel(385, 42);
    this.acLabel = mkLabel(470, 22); this.dcLabel = mkLabel(470, 42);
    this.macLabel = mkLabel(567, 22); this.mcLabel = mkLabel(567, 42); this.scLabel = mkLabel(567, 42);

    // 条上文字 (MainPanel.cs:134-137 CreateBarLabel, 描边居中)
    const barLabel = () => {
      const l = new DXLabel({
        textColour: [255, 255, 255, 255], drawOutline: true, outlineColour: [0, 0, 0, 255], isControl: false,
        align: 'center', valign: 'center',
      });
      this.addControl(l);
      return l;
    };
    this.healthLabel = barLabel(); this.manaLabel = barLabel(); this.focusLabel = barLabel();

    this._glowT = setInterval(() => { // 满专注辉光 (MainPanel.cs:186-187 Second%2)
      this.#paintBar('focus');
    }, 500);
  }

  #attachBadge(parent, idx) {
    const badge = new DXImageControl({ library: 'GameInter', index: idx, location: [2, 2], isControl: false });
    badge.visible = false;
    parent.addControl(badge);
    return badge;
  }

  // CreateBar (MainPanel.cs:167-178): 容器尺寸=sizeIdx 图, 填充按百分比
  async #createBar(key, x, y, sizeIndex, fillIndex, glowIndex) {
    const sizeF = await F('GameInter', sizeIndex);
    const fillF = await F('GameInter', fillIndex);
    if (!sizeF) return;
    const bar = new DXControl({ location: [x, y], size: [sizeF.w, sizeF.h], clip: true, isControl: false });
    this.addControl(bar);
    if (!fillF) return;
    const img = document.createElement('img');
    img.src = fillF.url;
    // 高度贴容器, 顶对齐 (MainPanel.cs:193-198)
    const h = Math.min(fillF.h, sizeF.h);
    img.style.cssText = `position:absolute;left:0;top:${Math.trunc((sizeF.h - h) / 2)}px;height:${h}px;` +
      `image-rendering:pixelated;`;
    bar.el.appendChild(img);
    let glowUrl = null;
    if (glowIndex >= 0) glowUrl = (await F('GameInter', glowIndex))?.url ?? null;
    this._barEls[key] = { img, w: fillF.w, fillUrl: fillF.url, glowUrl };
    this[key + 'BarCtl'] = bar;
    this.#paintBar(key);
  }

  // PercentOf (MainPanel.cs:158-163)
  static percentOf(cur, max) {
    if (cur > 0 && max <= 0) max = cur;
    if (max <= 0) return 0;
    return Math.min(1, Math.max(0, cur / max));
  }

  #paintBar(key) {
    const el = this._barEls[key];
    if (!el) return;
    const cur = key === 'health' ? this._hp : key === 'mana' ? this._mp : this._fp;
    const max = key === 'health' ? this._maxHp : key === 'mana' ? this._maxMp : this._maxFp;
    const p = MainPanel.percentOf(cur, max);
    // 满值辉光 (MainPanel.cs:185-187)
    if (el.glowUrl && p >= 1 && Math.floor(Date.now() / 1000) % 2 === 0) {
      el.img.src = el.glowUrl;
      el.img.style.width = `${el.w}px`;
      return;
    }
    if (el.fillUrl) el.img.src = el.fillUrl;
    el.img.style.width = p > 0 ? `${Math.round(el.w * p)}px` : '0px';
  }

  #paintExp() {
    const el = this._barEls.exp;
    if (!el) return;
    if (this._maxExperience <= 0) { el.img.style.width = '0px'; return; }
    const p = Math.min(1, Math.max(0, this._experience / this._maxExperience));
    el.img.style.width = p > 0 ? `${Math.round(el.w * p)}px` : '0px';
  }

  // CenterBarLabel (MainPanel.cs:274-281): 条上文字居中
  #centerBarLabel(label, key) {
    const bar = this[key + 'BarCtl'];
    if (!label || !bar) return;
    label.size = [bar.size[0], bar.size[1]];
    label.location = [bar.location[0], bar.location[1]];
    label.applyBase();
  }

  // ---- GameScene 数据注入 (MainPanel.cs:285-339) ----
  setLevel(level) { this._level = level; this.levelLabel.text = String(level); }
  setClass(cls) {
    this._class = cls;
    this.classLabel.text = CLASS_NAMES[cls] ?? '';
    const showMC = cls === 1 || cls === 0;  // Wizard/Warrior (MainPanel.cs:293)
    const showSC = cls === 2 || cls === 3;  // Taoist/Assassin
    this.mcLabel.visible = showMC; this.mcImage.visible = showMC;
    this.scLabel.visible = showSC; this.scImage.visible = showSC;
  }
  setStats(s) { // s: {MINAC,MAXAC,...} 由 game.js 从 statsUpdate 组装
    this.acLabel.text = fmtRange(s.MINAC, s.MAXAC);
    this.macLabel.text = fmtRange(s.MINMR, s.MAXMR);
    this.dcLabel.text = fmtRange(s.MINDC, s.MAXDC);
    this.scLabel.text = fmtRange(s.MINSC, s.MAXSC);
    this.mcLabel.text = fmtRange(s.MINMC, s.MAXMC);
    this.fpLabel.text = String(s.FP ?? '');
    this.cpLabel.text = String(s.CP ?? '');
  }
  setHealth(cur) { this._hp = cur; this.healthLabel.text = this._maxHp > 0 ? `${cur}/${this._maxHp}` : String(cur); this.#centerBarLabel(this.healthLabel, 'health'); this.#paintBar('health'); }
  setMana(cur) { this._mp = cur; this.manaLabel.text = this._maxMp > 0 ? `${cur}/${this._maxMp}` : String(cur); this.#centerBarLabel(this.manaLabel, 'mana'); this.#paintBar('mana'); }
  setFocus(cur) {
    this._fp = cur;
    this.focusLabel.visible = this._maxFp > 0; // MainPanel.cs:329
    this.focusLabel.text = `${cur}/${this._maxFp}`;
    this.#centerBarLabel(this.focusLabel, 'focus');
    this.#paintBar('focus');
  }
  setMaxHealth(v) { this._maxHp = v; }
  setMaxMana(v) { this._maxMp = v; }
  setMaxFocus(v) { this._maxFp = v; if (this.focusBarCtl) this.focusBarCtl.visible = v > 0; }
  setExperience(exp, max) { this._experience = exp; this._maxExperience = max; this.#paintExp(); }
  setQuestIndicators(hasAvailable, hasCompleted) { // MainPanel.cs:341-346
    this.availableQuestIcon.visible = hasAvailable;
    this.completedQuestIcon.visible = hasCompleted;
    this.completedQuestIcon.location = hasAvailable ? [2, Math.max(2, this.buttons.quest.size[1] - 16)] : [2, 2];
  }
  setMailIndicator(v) { this.newMailIcon.visible = v; }
  setAttackModeText(t) { this._attackModeText = t; }
  setPetModeText(t) { this._petModeText = t; }
}

// ====================================================================
// MiniMapDialog (MiniMapDialog.cs:16-518)
// ====================================================================
export class MiniMapDialog extends DXWindow {
  constructor(opts = {}) {
    // MiniMapDialog.cs:59-65: 黑底/无 footer/无关闭/可缩放 200x200
    super({
      size: [200, 200], backColour: [0, 0, 0, 255], hasFooter: false,
      showCloseButton: false, allowResize: true, movable: true,
      title: ' ',
    });
    // DXWindow 只在构造时建标题; MiniMap 标题随地图变 → 自管 label (实例属性遮蔽)
    this._mapTitle = '';
    Object.defineProperty(this, 'title', {
      get: () => this._mapTitle,
      set: (v) => { this._mapTitle = v ?? ''; if (this.titleLabel) this.titleLabel.text = this._mapTitle; },
    });
    this.uiScale = opts.uiScale ?? (() => 1);
    this.isLarge = false; this.isTransparent = false;
    this.mapWidth = 0; this.mapHeight = 0; this.mapIndex = 0;
    this.playerObjectID = 0;
    this.scaleX = 1; this.scaleY = 1;
    this._objectMarkers = new Map();  // DXControl per objectID
    this._staticMarkers = [];
    this._pressPos = null;

    // Panel: ClientArea 向外扩 6px (MiniMapDialog.cs:49-55 → Panel Clip)
    this.panel = new DXControl({ location: [-6, 18], size: [212, 188], clip: true, isControl: false });
    this.addControl(this.panel);

    // Image: MiniMap.Zl 帧, 可拖动平移 (MiniMapDialog.cs:75-82)
    this.image = new DXImageControl({ library: 'MiniMap', index: -1, location: [0, 0] });
    this.image.el.style.cursor = this.#gm ? 'crosshair' : 'default';
    this.panel.addControl(this.image);
    this.#wireImageDrag();

    // 三按钮 (MiniMapDialog.cs:89-114): 大小/透明/大地图, 悬停显示
    this.sizeButton = this.#cornerButton(132, () => this.#toggleSize());
    this.transparencyButton = this.#cornerButton(130, () => this.#toggleTransparency());
    this.bigMapButton = this.#cornerButton(137, () => this.onBigMap());

    // TimeOfDayImage (MiniMapDialog.cs:116-122): GameInter[0] 无贴图则跳过
    this.timeOfDayImage = new DXImageControl({ library: 'GameInter', index: 216, isControl: false });
    this.addControl(this.timeOfDayImage);
    this.#updateButtonLocations();
    // Process (MiniMapDialog.cs:475-500): 悬停显隐
    this.el.addEventListener('mouseenter', () => this.#setButtonsVisible(true));
    this.el.addEventListener('mouseleave', () => this.#setButtonsVisible(false));
  }

  get #gm() { return !!this._gmFlag; }
  setGM(v) { this._gmFlag = v; this.image.el.style.cursor = v ? 'crosshair' : 'default'; }

  #cornerButton(idx, fn) {
    const b = new DXImageControl({ library: 'GameInter', index: idx, onClick: fn });
    b.el.style.cursor = 'pointer';
    b.visible = false;
    this.addControl(b);
    return b;
  }
  #setButtonsVisible(v) {
    this.sizeButton.visible = v;
    this.transparencyButton.visible = v;
    this.bigMapButton.visible = v;
  }

  // UpdateButtonLocations (MiniMapDialog.cs:504-517): 右缘 3px 垂直叠
  #updateButtonLocations() {
    const top = this.hasTitle ? 24 : 0, rightPad = 3;
    this.sizeButton.location = [this.size[0] - this.sizeButton.size[0] - rightPad, top];
    this.transparencyButton.location = [this.size[0] - this.transparencyButton.size[0] - rightPad, top + this.sizeButton.size[1]];
    this.bigMapButton.location = [this.size[0] - this.bigMapButton.size[0] - rightPad, top + this.sizeButton.size[1] * 2];
  }

  // 拖动平移 + GM 点击传送 (MiniMapDialog.cs:128-150)
  #wireImageDrag() {
    const el = this.image.el;
    let dragging = false, start = null, imgStart = null;
    el.addEventListener('mousedown', (ev) => {
      if (ev.button !== 0) return;
      dragging = true;
      start = [ev.clientX, ev.clientY];
      imgStart = [...this.image.location];
      this._pressPos = [ev.clientX, ev.clientY];
      ev.preventDefault();
    });
    addEventListener('mousemove', (ev) => {
      if (!dragging) return;
      const s = this.uiScale();
      this.image.location = [
        Math.round(imgStart[0] + (ev.clientX - start[0]) / s),
        Math.round(imgStart[1] + (ev.clientY - start[1]) / s),
      ];
    });
    addEventListener('mouseup', (ev) => {
      if (!dragging) return;
      dragging = false;
      // 拖动 >6px 不算点击 (MiniMapDialog.cs:146)
      if (Math.hypot(ev.clientX - this._pressPos[0], ev.clientY - this._pressPos[1]) > 6) return;
      if (!this.#gm) return;                    // 非 GM 完全忽略 (MiniMapDialog.cs:135)
      const rect = el.getBoundingClientRect();
      const local = [
        (ev.clientX - rect.left) / this.uiScale() - this.image.location[0],
        (ev.clientY - rect.top) / this.uiScale() - this.image.location[1],
      ];
      // GetMapPoint (MiniMapDialog.cs:153-159)
      const x = Math.min(Math.max(0, Math.round(local[0] / Math.max(0.001, this.scaleX))), Math.max(0, this.mapWidth - 1));
      const y = Math.min(Math.max(0, Math.round(local[1] / Math.max(0.001, this.scaleY))), Math.max(0, this.mapHeight - 1));
      this.onTeleport?.(x, y, this.mapIndex);
    });
  }
  onTeleport = null;

  // SetMap (MiniMapDialog.cs:164-208)
  async setMap(mapMeta, stem, playerObjectID, npcList) {
    this.mapWidth = mapMeta.w; this.mapHeight = mapMeta.h;
    this.mapIndex = mapMeta.id;
    this.playerObjectID = playerObjectID;
    this.title = mapMeta.name_cn ?? stem;
    this._objectMarkers.forEach(m => m.el.remove());
    this._objectMarkers.clear();
    this._staticMarkers.forEach(m => m.el.remove());
    this._staticMarkers = [];

    const idx = mapMeta.minimap || 0;
    if (idx > 0) {
      this.image.index = idx;
      this.image.location = [0, 0];
      const f = await F('MiniMap', idx);
      if (!f) return;
      this.scaleX = f.w / Math.max(1, mapMeta.w);   // MiniMapDialog.cs:198-199
      this.scaleY = f.h / Math.max(1, mapMeta.h);
      this.#addNpcMarkers(npcList, stem);
      this.#addExitMarkers(mapMeta.exits ?? []);
    } else {
      this.allowResize = false;
      this.size = [this.size[0], 32];               // 无图: 高度 32 (MiniMapDialog.cs:176-181)
      this.updateClientArea();
    }
  }

  // UpdateStatic(NPCInfo) (MiniMapDialog.cs:224-240): 本图 NPC → 中心点标记
  async #addNpcMarkers(npcs, stem) {
    const frame = await F('MiniMapIcon', 0);        // 无任务状态: icon=0 白色 (MapMarkerFactory)
    for (const n of npcs ?? []) {
      if (n.map !== stem) continue;
      const m = new DXImageControl({ library: 'MiniMapIcon', index: 0, isControl: false });
      m.location = [
        Math.trunc(this.scaleX * n.x) - Math.trunc((frame?.w ?? 8) / 2),
        Math.trunc(this.scaleY * n.y) - Math.trunc((frame?.h ?? 8) / 2),
      ];
      setHint(m, n.zh || n.name);
      this.image.addControl(m);
      this._staticMarkers.push(m);
    }
  }

  // UpdateStatic(MovementInfo) (MiniMapDialog.cs:242-265) + UpdateMapIcon (268-298)
  async #addExitMarkers(exits) {
    // 按目的地聚合 → 区域质心 (RegionCenter, MiniMapDialog.cs:300-312)
    const byDest = new Map();
    for (const e of exits) {
      if (!e.icon || e.icon === 'None') continue;
      if (!byDest.has(e.to)) byDest.set(e.to, []);
      byDest.get(e.to).push(e);
    }
    const ICON = {
      Cave: { index: 1, colour: 'rgba(255,0,0,1)' },           // 红
      Exit: { index: 1, colour: 'rgba(0,128,0,1)' },           // 绿
      Down: { index: 1, colour: 'rgba(199,20,133,1)' },        // MediumVioletRed
      Up: { index: 1, colour: 'rgba(0,191,255,1)' },           // DeepSkyBlue
      Province: { index: 7, colour: null },
      Building: { index: 6, colour: null },
    };
    for (const list of byDest.values()) {
      let minX = 1e9, maxX = -1e9, minY = 1e9, maxY = -1e9;
      for (const p of list) {
        if (p.x < minX) minX = p.x; if (p.x > maxX) maxX = p.x;
        if (p.y < minY) minY = p.y; if (p.y > maxY) maxY = p.y;
      }
      const cx = (minX + maxX) / 2, cy = (minY + maxY) / 2;
      const spec = ICON[list[0].icon] ?? { index: 1, colour: null };
      const icon = new DXImageControl({ library: 'MiniMapIcon', index: spec.index, isControl: false });
      if (spec.colour) icon.el.style.filter = this.#colourFilter(spec.colour);
      const f = await F('MiniMapIcon', spec.index);
      icon.location = [
        Math.trunc(this.scaleX * cx) - Math.trunc((f?.w ?? 8) / 2),
        Math.trunc(this.scaleY * cy) - Math.trunc((f?.h ?? 8) / 2),
      ];
      this.image.addControl(icon);
      this._staticMarkers.push(icon);
    }
  }
  #colourFilter(rgbaStr) { // ARGB tint → CSS (近似: 亮度×色调)
    const m = rgbaStr.match(/rgba\((\d+),(\d+),(\d+)/);
    if (!m) return '';
    const [r, g, b] = [+m[1], +m[2], +m[3]];
    return `sepia(1) saturate(${Math.max(r, g, b)}) hue-rotate(${Math.atan2(g - b, r - g || 1e-6)}rad)`;
  }

  // UpdateObject (MiniMapDialog.cs:315-343): 怪红/物深蓝/玩家青, 自己=lime 空心
  updateObject(objectID, cellX, cellY, kind) {
    if (objectID === this.playerObjectID) { this.updatePlayer(cellX, cellY); return; }
    let dot = this._objectMarkers.get(objectID);
    if (!dot) {
      dot = new DXControl({ size: [3, 3], backColour: [255, 255, 255, 255], isControl: false });
      this.image.addControl(dot);
      this._objectMarkers.set(objectID, dot);
    }
    const colour = { monster: [255, 0, 0, 255], item: [0, 0, 140, 255], player: [0, 255, 255, 255] }[kind] ?? [255, 255, 255, 255];
    dot.backColour = colour;
    dot.el.style.backgroundColor = rgba(colour);
    dot.location = [Math.trunc(this.scaleX * cellX) - 1, Math.trunc(this.scaleY * cellY) - 1];
  }

  // UpdatePlayerMarker (MiniMapDialog.cs:358-378): 玩家标记 + 地图平移居中
  updatePlayer(cellX, cellY) {
    let dot = this._objectMarkers.get(this.playerObjectID);
    if (!dot) {
      dot = new DXControl({ size: [5, 5], backColour: [0, 255, 0, 255], isControl: false });
      dot.el.style.boxShadow = 'inset 0 0 0 1px rgba(0,255,0,1)'; // Hollow
      this.image.addControl(dot);
      this._objectMarkers.set(this.playerObjectID, dot);
    }
    dot.location = [Math.trunc(this.scaleX * cellX) - 2, Math.trunc(this.scaleY * cellY) - 2];
    this.image.location = [
      -dot.location[0] + Math.trunc(this.panel.size[0] / 2),
      -dot.location[1] + Math.trunc(this.panel.size[1] / 2),
    ];
    this.#clipMap();
  }

  removeObject(objectID) {
    const dot = this._objectMarkers.get(objectID);
    if (dot) { dot.el.remove(); this._objectMarkers.delete(objectID); }
  }

  // ClipMap (MiniMapDialog.cs:394-409)
  #clipMap() {
    const imgW = this.image.size[0], imgH = this.image.size[1];
    const pW = this.panel.size[0], pH = this.panel.size[1];
    let [x, y] = this.image.location;
    if (x + imgW < pW) x = pW - imgW;
    if (x > 0) x = 0;
    if (y + imgH < pH) y = pH - imgH;
    if (y > 0) y = 0;
    if (imgW < pW) x = -Math.trunc((imgW - pW) / 2);
    if (imgH < pH) y = -Math.trunc((imgH - pH) / 2);
    this.image.location = [Math.round(x), Math.round(y)];
  }

  // ToggleSize (MiniMapDialog.cs:411-421)
  #toggleSize() {
    const right = this.location[0] + this.size[0];
    this.isLarge = !this.isLarge;
    this.allowResize = this.isLarge;
    this.size = this.isLarge ? [300, 300] : [200, 200];
    this.location = [right - this.size[0], this.location[1]];
    this.#onResized();
  }

  #onResized() { // OnResized (MiniMapDialog.cs:423-437)
    this.panel.location = [-6, this.hasTitle ? 18 : 0];
    this.panel.size = [this.size[0] + 12, this.size[1] - (this.hasTitle ? 18 : 0) + 12];
    this.#updateButtonLocations();
    this.#clipMap();
  }

  getAcceptableResize([w, h]) { // 150~300 (MiniMapDialog.cs:439-445)
    return [Math.min(300, Math.max(150, Math.round(w))), Math.min(300, Math.max(150, Math.round(h)))];
  }

  // ToggleTransparency (MiniMapDialog.cs:447-452)
  #toggleTransparency() {
    this.isTransparent = !this.isTransparent;
    const opacity = this.isTransparent ? 0.5 : 1;
    this.el.style.opacity = opacity;
    this.transparencyButton.index = this.isTransparent ? 131 : 130; // 457
  }

  // Process: TimeOfDayImage (MiniMapDialog.cs:482-499)
  setTimeOfDay(tod) { // TimeOfDay enum: 0=Dawn 1=Day 2=Dusk 3=Night
    const idx = [215, 216, 217, 218][tod] ?? 216;
    this.timeOfDayImage.index = idx;
    this.timeOfDayImage.location = [3, this.size[1] - 29];
    setHint(this.timeOfDayImage, ['黎明', '白天', '黄昏', '夜晚'][tod] ?? '');
  }
}

// ====================================================================
// 兜底窗口 (par-win 未注册时启用; 全部为真实数据/真实行为, 无"暂未实现")
// ====================================================================
export function fallbackWindow(type, scene) {
  const info = scene.world?.info ?? {};
  const mapName = scene.world?.mapMeta?.name_cn ?? '';
  const win = new DXWindow({ title: { character: '角色', inventory: '背包', spell: '技能', quest: '任务日志', mail: '聊天/好友', belt: '腰带', group: '编组', menu: '菜单', cashshop: '商铺', bigmap: `大地图 - ${mapName}` }[type] ?? type, size: [360, 300] });
  const body = new DXControl({ location: [10, 34], size: [340, 250], clip: true, isControl: false });
  win.addControl(body);
  const row = (t, c = '#eee') => {
    const d = document.createElement('div');
    d.textContent = t;
    d.style.cssText = `font:12px/1.6 'Noto Sans CJK SC',sans-serif;color:${c};text-shadow:1px 1px 0 #000;padding:0 4px;`;
    body.el.appendChild(d);
    return d;
  };
  const itemName = (infoIndex) => scene.world && window.__D ? (window.__D().itemsById?.[infoIndex]?.zh ?? `物品#${infoIndex}`) : `物品#${infoIndex}`;
  switch (type) {
    case 'character': {
      row(`${CLASS_NAMES[info.class] ?? '?'}  Lv.${info.level}  ${info.name}`, '#ffd573');
      row(`HP ${scene.world?.player?.hp ?? 0}/${scene.world?.player?.maxHp ?? 0}   MP ${scene.world?.player?.mp ?? 0}/${scene.world?.player?.maxMp ?? 0}`);
      row(`经验 ${Math.floor(scene.mainPanel?._experience ?? 0)}/${Math.floor(scene.mainPanel?._maxExperience ?? 0)}`);
      const s = scene.lastStats ?? {};
      for (const k of ['MAXAC', 'MAXMR', 'MAXDC', 'MAXMC', 'MAXSC', 'ACCURACY', 'AGILITY'])
        if (s[k] != null) row(`${k} ${s[k]}`);
      break;
    }
    case 'inventory': {
      const items = info.items ?? [];
      row(`共 ${items.length} 件`, '#ffd573');
      for (const it of items.slice(0, 14)) row(`· ${itemName(it.infoIndex)} x${it.count ?? 1n}`);
      break;
    }
    case 'spell': {
      const magics = info.magics ?? [];
      row(`已学技能 ${magics.length} 个`, '#ffd573');
      for (const m of magics.slice(0, 14)) row(`· 技能#${m.infoIndex} Lv.${m.level} ${m.set1Key ? '(F键已绑)' : ''}`);
      break;
    }
    case 'quest': {
      const quests = (info.quests ?? []).filter(Boolean);
      row(`任务 ${quests.length} 个`, '#ffd573');
      for (const q of quests.slice(0, 14)) row(`· 任务#${q.index} ${q.complete ? '[已完成]' : '[进行中]'}`);
      break;
    }
    case 'mail': {
      row(`好友 ${(info.friends ?? []).length} 人`, '#ffd573');
      for (const f of (info.friends ?? []).slice(0, 14)) row(`· ${f.name} ${f.online ? '(在线)' : ''}`);
      break;
    }
    case 'belt': {
      const links = info.beltLinks ?? [];
      row(`腰带槽 ${links.length}/10`, '#ffd573');
      for (const l of links.slice(0, 10)) row(`· 槽${l.slot} → ${itemName(l.linkItemIndex)}`);
      break;
    }
    case 'group': {
      row('编组设置', '#ffd573');
      const b1 = new DXButton({ text: '允许组队: 开', fontSize: 9, library: 'Interface', index: -1, location: [10, 30], size: [120, 24], onClick() { scene.conn.sendGroupSwitch(true); this.el.querySelector('.dxbtn-label').textContent = '允许组队: 开'; } });
      const b2 = new DXButton({ text: '允许组队: 关', fontSize: 9, library: 'Interface', index: -1, location: [140, 30], size: [120, 24], onClick() { scene.conn.sendGroupSwitch(false); this.el.querySelector('.dxbtn-label').textContent = '允许组队: 关'; } });
      body.addControl(b1);
      body.addControl(b2);
      row('邀请: 聊天输入 /名字 组队', '#aaa');
      break;
    }
    case 'menu': {
      row('菜单', '#ffd573');
      const mk = (text, y, fn) => {
        const b = new DXButton({ text, fontSize: 9, library: 'Interface', index: -1, location: [10, y], size: [160, 24], onClick: fn });
        body.addControl(b);
      };
      mk('攻击模式: 切换', 30, () => scene.conn.sendChangeAttackMode(((scene.attackMode ?? 0) + 1) % 6));
      mk('宠物模式: 切换', 60, () => scene.conn.sendChangePetMode(((scene.petMode ?? 0) + 1) % 8));
      mk('退出游戏', 90, () => scene.conn.sendLogout());
      break;
    }
    case 'cashshop': {
      row('商铺', '#ffd573');
      row(scene.gameStoreItems?.length ? `热销 ${scene.gameStoreItems.length} 件` : '向服务器请求商品数据...', '#aaa');
      for (const it of (scene.gameStoreItems ?? []).slice(0, 12)) row(`· 商品#${it.index}`);
      break;
    }
    case 'bigmap': {
      const img = document.createElement('img');
      img.src = `/res/sprites/MiniMap/${scene.world?.mapMeta?.minimap ?? 0}.webp`;
      img.style.cssText = 'width:100%;height:100%;object-fit:contain;image-rendering:pixelated;';
      body.el.appendChild(img);
      break;
    }
  }
  return win;
}
