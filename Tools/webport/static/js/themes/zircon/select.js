// select.js — SelectScene (Scripts/SelectScene.cs 逐行移植; 布局 = BuildLegacySelectUi L359-516)
import { DXImageControl, DXAnimatedControl, DXLabel, DXButton, DXTextInput, DXControl, LegacyWindowFrame } from '../../dx.js';
import { skin } from '../../skin.js';
import { NewCharacterResultText, NEWCHARACTER_SUCCESS, StartGameResultText, STARTGAME_SUCCESS, STARTGAME_DELAYED } from '../../net.js';

const CLASS_NAMES = ['战士', '法师', '道士', '刺客'];
const GENDER_NAMES = ['男', '女'];

// 角色 intro/idle 动画表 (SelectScene.cs:283-293)
const INTRO_TABLE = {
  '0-0': [240, 22, 300, 13, 2200, 1900],   // Warrior-M
  '0-1': [440, 28, 500, 13, 2800, 1900],   // Warrior-F
  '1-0': [740, 20, 800, 10, 2000, 1500],   // Wizard-M
  '1-1': [940, 26, 1000, 15, 2600, 2250],  // Wizard-F
  '2-0': [1240, 27, 1300, 15, 2700, 2250], // Taoist-M
  '2-1': [1440, 20, 1500, 10, 2000, 1500], // Taoist-F
  '3-0': [1740, 25, 1800, 16, 2500, 2400], // Assassin-M
  '3-1': [1940, 20, 2000, 10, 2000, 1500], // Assassin-F (fallback)
};
// 建角色预览表 (SelectScene.cs:550-567)
const PREVIEW_TABLE = {
  '0-0': [300, 13], '0-1': [500, 13], '1-0': [800, 10], '1-1': [1000, 10],
  '2-0': [1300, 15], '2-1': [1500, 15], '3-0': [1800, 16], '3-1': [2000, 16],
};

export class SelectScene {
  constructor(conn, characters, onEnterGame) {
    this.conn = conn;
    this.characters = characters ?? [];
    this.onEnterGame = onEnterGame; // (characterIndex) => void
    this.selectedIndex = this.characters.length > 0 ? 0 : -1;
    this.root = document.createElement('div');
    this.root.style.cssText = 'position:absolute;inset:0;';
    this.charButtons = [];
    this.idleMode = false;
    this.maps = undefined;          // 地图表缓存 (非敏感, 普通字段)
    this.locationLabels = [];
    this.#loadMaps();
    this.#build();
    this.#wire();
    this.#refresh();
  }

  #build() {
    // 背景 Interface1c[50] (SelectScene.cs:363-372)
    const bg = new DXImageControl({
      library: 'Interface1c', index: 50, fixedSize: true,
      location: [0, 0], size: [1024, 768], isControl: false,
    });
    this.bg = bg;
    this.root.appendChild(bg.el);

    // 左右光晕 (SelectScene.cs:388-413)
    bg.addControl(new DXAnimatedControl({
      library: 'Interface1c', baseIndex: 2800, frameCount: 17,
      animationDelayMs: 3000, loop: true, blend: true, isControl: false,
    }));
    bg.addControl(new DXAnimatedControl({
      library: 'Interface1c', baseIndex: 2900, frameCount: 17,
      animationDelayMs: 3000, loop: true, blend: true, useOffSet: true,
      location: [20, 25], isControl: false,
    }));

    // 角色动画 + overlay (SelectScene.cs:415-429)
    this.charAnim = new DXAnimatedControl({
      library: 'Interface1c', frameCount: 1, animationDelayMs: 1,
      useOffSet: true, location: [450, 200], isControl: false,
    });
    this.overlay1 = new DXImageControl({
      library: 'Interface1c', useOffSet: true, location: [450, 200],
      visible: false, isControl: false,
    });
    this.overlay2 = new DXImageControl({
      library: 'Interface1c', useOffSet: true, location: [450, 200],
      visible: false, isControl: false,
    });
    bg.addControl(this.charAnim);
    bg.addControl(this.overlay1);
    bg.addControl(this.overlay2);
    // idle 时 overlay 跟随 (SelectScene.cs:141-162 _Process)
    setInterval(() => this.#updateOverlays(), 120);

    // 角列表面板 320x425 (SelectScene.cs:431-443)
    this.panel = new DXControl({
      size: [320, 425],
      location: [Math.trunc((1024 / 2 - 320) / 2), Math.trunc((768 - 425) / 2)],
    });
    this.root.appendChild(this.panel.el);
    this.panel.addControl(new LegacyWindowFrame({ size: [320, 425], hasTitle: true, hasFooter: true }));
    this.panel.addControl(new DXLabel({
      text: '选择角色', fontSize: 12, textColour: [255, 217, 89, 255], drawOutline: true,
      location: [0, 0], size: [320, 28], align: 'center', isControl: false,
    }));

    // 底部按钮 (SelectScene.cs:445-453)
    skin.frame('Interface', 16).then(f => {
      const h = f?.h ?? 21;
      this.btnStart = new DXButton({
        text: '进入游戏', fontSize: 10, library: 'Interface', index: -1,
        location: [25, 382], size: [80, h], enabled: false,
        onClick: () => this.#onStart(),
      });
      this.btnCreate = new DXButton({
        text: '创建角色', fontSize: 10, library: 'Interface', index: -1,
        location: [120, 382], size: [80, h],
        onClick: () => { if (this.characters.length < 4) this.#showCreate(); },
      });
      this.btnDelete = new DXButton({
        text: '删除角色', fontSize: 10, library: 'Interface', index: -1,
        location: [215, 382], size: [80, h], enabled: false,
        onClick: () => this.#onDelete(),
      });
      this.panel.addControl(this.btnStart);
      this.panel.addControl(this.btnCreate);
      this.panel.addControl(this.btnDelete);
      if (this.characters.length > 0 && this.selectedIndex >= 0) {
        this.btnStart.enabled = true;
        this.btnDelete.enabled = true;
      }
      this.#buildCreatePanel();
    });
  }

  #buildCreatePanel() {
    // 建角色面板 260x650 (SelectScene.cs:455-468)
    this.createPanel = new DXControl({
      size: [260, 650],
      location: [Math.trunc((1024 - 260) / 2), Math.trunc((768 - 650) / 2)],
      visible: false,
    });
    this.root.appendChild(this.createPanel.el);
    this.createPanel.addControl(new LegacyWindowFrame({ size: [260, 650], hasTitle: true, hasFooter: true }));
    this.createPanel.addControl(new DXLabel({
      text: '创建角色', fontSize: 12, textColour: [255, 217, 89, 255], drawOutline: true,
      location: [0, 0], size: [260, 30], align: 'center', isControl: false,
    }));

    // 职业选项框 (SelectScene.cs:471-477 CreateOptionBox + AddCreateOption)
    this.createClass = 0; this.createGender = 0;
    const classBox = this.#optionBox('职业', [30, 40]);
    this.selectedClassLabel = new DXLabel({
      text: '战士', fontSize: 8, location: [60, 65], size: [80, 15], align: 'center', isControl: false,
    });
    classBox.addControl(this.selectedClassLabel);
    this.classButtons = [];
    const classNormal = [121, 126, 131, 136], classPressed = [120, 125, 130, 135];
    for (let i = 0; i < 4; i++) {
      const b = new DXButton({
        text: ['战士', '法师', '道士', '刺客'][i], fontSize: 8,
        library: 'Interface1c', index: classNormal[i],
        location: [12 + i * 45, 25], size: [40, 38],
        onClick: () => { this.createClass = i; this.#updateCreateStates(); this.#updatePreview(); },
      });
      classBox.addControl(b);
      this.classButtons.push(b);
    }

    // 性别选项框 (SelectScene.cs:479-483)
    const genderBox = this.#optionBox('性别', [30, 135]);
    this.selectedGenderLabel = new DXLabel({
      text: '男', fontSize: 8, location: [60, 65], size: [80, 15], align: 'center', isControl: false,
    });
    genderBox.addControl(this.selectedGenderLabel);
    this.genderButtons = [];
    for (let i = 0; i < 2; i++) {
      const b = new DXButton({
        text: GENDER_NAMES[i], fontSize: 8,
        library: 'Interface1c', index: i === 0 ? 116 : 111,
        location: [12 + i * 45, 25], size: [40, 38],
        onClick: () => { this.createGender = i; this.#updateCreateStates(); this.#updatePreview(); },
      });
      genderBox.addControl(b);
      this.genderButtons.push(b);
    }

    // 外观区 (SelectScene.cs:485-501)
    const appearance = new DXControl({
      size: [200, 330], location: [30, 230],
      backColour: [71, 36, 36, 255], border: true, borderColour: [191, 140, 51, 255],
    });
    this.createPanel.addControl(appearance);
    appearance.addControl(new DXLabel({
      text: '外观设置', fontSize: 9, textColour: [255, 217, 140, 255],
      location: [0, 0], size: [200, 22], align: 'center', isControl: false,
    }));
    // 预览面板 (SelectScene.cs:497-501)
    const previewPanel = new DXControl({
      size: [190, 225], location: [5, 100],
      backColour: [48, 41, 23, 255], border: true, borderColour: [191, 140, 51, 255],
    });
    appearance.addControl(previewPanel);
    previewPanel.addControl(new DXLabel({
      text: '角色预览', fontSize: 9, textColour: [255, 217, 140, 255],
      location: [0, 0], size: [190, 20], align: 'center', isControl: false,
    }));
    this.preview = new DXAnimatedControl({
      library: 'Interface1c', baseIndex: 300, frameCount: 13,
      animationDelayMs: 1900, loop: true, useOffSet: true,
      location: [70, 145], isControl: false,
    });
    previewPanel.addControl(this.preview);

    // 名字 + 确认/取消 (SelectScene.cs:502-512)
    this.nameInput = new DXTextInput({ location: [75, 570], size: [155, 20], text: 'TestHero' });
    this.createPanel.addControl(this.nameInput);
    this.createPanel.addControl(new DXLabel({
      text: '角色名字', fontSize: 9, location: [20, 572], isControl: false,
    }));
    this.btnConfirm = new DXButton({
      text: '创建', fontSize: 10, library: 'Interface', index: -1,
      location: [90, 607], size: [80, 21], onClick: () => this.#onCreate(),
    });
    const btnCancel = new DXButton({
      library: 'Interface', index: 15, location: [230, 3],
      onClick: () => this.#hideCreate(),
    });
    this.createPanel.addControl(this.btnConfirm);
    this.createPanel.addControl(btnCancel);
    this.#updateCreateStates();
  }

  #optionBox(title, location) { // CreateOptionBox (SelectScene.cs:518-524)
    const box = new DXControl({
      size: [200, 85], location,
      backColour: [71, 36, 36, 255], border: true, borderColour: [191, 140, 51, 255],
    });
    this.createPanel.addControl(box);
    box.addControl(new DXLabel({
      text: title, fontSize: 9, textColour: [255, 217, 140, 255],
      location: [0, 0], size: [200, 20], align: 'center', isControl: false,
    }));
    return box;
  }

  #wire() {
    this.conn.addEventListener('newCharacterResult', (e) => this.#onNewCharacter(e.detail));
    this.conn.addEventListener('deleteCharacterResult', (e) => this.#onDeleteCharacter(e.detail));
    this.conn.addEventListener('startGameResult', (e) => this.#onStartGame(e.detail));
    this.nameInput?.onTextChanged(() => this.#updateCreateStates());
  }

  // ---- 角色列表 (SelectScene.cs:187-245 RefreshList) ----
  #refresh() {
    for (const b of this.charButtons) this.panel.removeControl(b);
    this.charButtons = [];
    for (let i = 0; i < this.characters.length && i < 4; i++) {
      const c = this.characters[i];
      const btn = new DXButton({
        location: [20, 45 + i * 78], size: [280, 75],
        backColour: [24, 12, 12, 255], border: true, borderColour: [184, 133, 61, 255],
        onClick: () => this.#selectChar(i),
      });
      // 职业图标 Interface[27+class] 64x64 (SelectScene.cs:213-221)
      btn.addControl(new DXImageControl({
        library: 'Interface', index: 27 + c.class, fixedSize: true,
        size: [64, 64], location: [6, 4], isControl: false,
      }));
      const mkLabel = (text, fontSize, colour, loc, size, extra = {}) => new DXLabel({
        text, fontSize, textColour: colour, location: loc, size, isControl: false, ...extra,
      });
      btn.addControl(mkLabel('名字', 8, [204, 179, 128, 255], [77, 7], [0, 0]));
      btn.addControl(mkLabel(c.characterName, 10, [255, 255, 255, 255], [135, 8], [130, 15],
        { backColour: [10, 5, 5, 191], border: true, borderColour: [128, 89, 46, 255] }));
      btn.addControl(mkLabel('职业', 8, [204, 179, 128, 255], [77, 29], [0, 0]));
      btn.addControl(mkLabel(CLASS_NAMES[c.class] ?? '?', 9, [255, 255, 255, 255], [135, 28], [53, 15],
        { backColour: [10, 5, 5, 191], border: true, borderColour: [128, 89, 46, 255] }));
      btn.addControl(mkLabel(`${c.level}`, 9, [255, 255, 255, 255], [235, 28], [30, 15],
        { backColour: [10, 5, 5, 191], border: true, borderColour: [128, 89, 46, 255] }));
      btn.addControl(mkLabel('所在地', 8, [204, 179, 128, 255], [77, 51], [0, 0]));
      const locLabel = mkLabel(this.#locationName(c.location), 8, [255, 255, 255, 255], [135, 48], [130, 15]);
      (this.locationLabels ??= []).push({ el: locLabel.el, index: c.location });
      btn.addControl(locLabel);
      this.panel.addControl(btn);
      this.charButtons.push(btn);
    }
    if (this.characters.length === 0) {
      this.btnStart && (this.btnStart.enabled = false);
      this.btnDelete && (this.btnDelete.enabled = false);
      this.charAnim.visible = false;
    } else {
      this.#selectChar(0);
    }
    if (this.btnCreate) this.btnCreate.enabled = this.characters.length < 4;
  }

  async #loadMaps() { // Globals.MapInfoList 等价: maps_manifest.json id→中文名
    if (this.maps !== undefined) return this.maps;
    this.maps = null;
    try {
      const m = await fetch('/res/data/maps_manifest.json').then(r => r.ok ? r.json() : null);
      this.maps = m?.maps ?? null;
    } catch { this.maps = null; }
    // 数据到达后刷新已建行的所在地标签
    this.#refreshLocationLabels();
    return this.maps;
  }
  #locationName(index) { // GetLocationName (SelectScene.cs:265-271)
    const maps = this.maps;
    if (!maps) return '新角色';
    for (const [stem, m] of Object.entries(maps)) {
      if (m.id === index) return m.name_cn || stem;
    }
    return '新角色';
  }
  #refreshLocationLabels() {
    this.locationLabels?.forEach(({ el, index }) => { el.textContent = this.#locationName(index); });
  }

  #selectChar(i) { // SelectSkinCharacter (SelectScene.cs:247-263)
    this.selectedIndex = i;
    if (this.btnStart) this.btnStart.enabled = true;
    if (this.btnDelete) this.btnDelete.enabled = true;
    for (let j = 0; j < this.charButtons.length; j++) {
      const sel = j === i;
      this.charButtons[j].backColour = sel ? [71, 36, 36, 255] : [24, 12, 12, 255];
      this.charButtons[j].border = !sel;
      this.charButtons[j].applyBase();
    }
    this.#updateCharacterDisplay(this.characters[i]);
  }

  #updateCharacterDisplay(info) { // UpdateCharacterDisplay (SelectScene.cs:273-306)
    if (!info || !this.charAnim) return;
    this.charAnim.clearAnimationHandlers();
    this.charAnim.visible = true;
    const key = `${info.class}-${info.gender}`;
    const [intro, introF, idle, idleF, introMs, idleMs] = INTRO_TABLE[key] ?? INTRO_TABLE['3-1'];
    this.charAnim.baseIndex = intro;
    this.charAnim.frameCount = introF;
    this.charAnim.animationDelayMs = introMs;
    this.charAnim.loop = false;
    this.charAnim.afterAnimation = () => { // L298-304
      this.charAnim.baseIndex = idle;
      this.charAnim.frameCount = idleF;
      this.charAnim.animationDelayMs = idleMs;
      this.charAnim.restart(true);
    };
    this.charAnim.restart(false);
    this.idleMode = false;
  }

  #updateOverlays() { // SelectScene.cs:141-162 _Process overlay 跟随
    const anim = this.charAnim;
    if (!anim || !anim.visible) return;
    const idle = !anim.loop && anim.animated === false; // intro 播完
    this.idleMode = idle;
    this.overlay1.visible = idle;
    this.overlay2.visible = idle;
    if (idle) {
      this.overlay1.index = anim.index + 100;
      this.overlay2.index = anim.index + 130;
      Promise.all([
        skin.frame('Interface1c', anim.index),
        skin.frame('Interface1c', anim.index + 100),
        skin.frame('Interface1c', anim.index + 130),
      ]).then(([base, o1, o2]) => {
        if (!base) return;
        if (o1) {
          this.overlay1.location = [450 + base.ox - o1.ox, 200 + base.oy - o1.oy];
          this.overlay1.applyBase();
        }
        if (o2) {
          this.overlay2.location = [450 + base.ox - o2.ox, 200 + base.oy - o2.oy];
          this.overlay2.applyBase();
        }
      });
    }
  }

  #showCreate() { // ShowCreateCharacterPanel (SelectScene.cs:315-320)
    this.panel.visible = false;
    this.createPanel.visible = true;
    this.charAnim.visible = false;
  }
  #hideCreate() { // HideCreateCharacterPanel (SelectScene.cs:308-313)
    this.createPanel.visible = false;
    this.panel.visible = true;
    this.charAnim.visible = true;
  }

  #updateCreateStates() { // UpdateCreateButtonStates (SelectScene.cs:336-349)
    const classNormal = [121, 126, 131, 136], classPressed = [120, 125, 130, 135];
    this.classButtons?.forEach((b, i) => { b.index = this.createClass === i ? classPressed[i] : classNormal[i]; });
    this.genderButtons?.forEach((b, i) => {
      b.index = this.createGender === i ? (i === 0 ? 115 : 110) : (i === 0 ? 116 : 111);
    });
    if (this.selectedClassLabel) this.selectedClassLabel.text = CLASS_NAMES[this.createClass];
    if (this.selectedGenderLabel) this.selectedGenderLabel.text = GENDER_NAMES[this.createGender];
  }

  #updatePreview() { // UpdateCreatePreview (SelectScene.cs:547-572)
    const [base, frames] = PREVIEW_TABLE[`${this.createClass}-${this.createGender}`] ?? [300, 13];
    this.preview.baseIndex = base;
    this.preview.frameCount = frames;
    this.preview.animationDelayMs = 1900;
    this.preview.restart(true);
  }

  #onCreate() { // SubmitSkinCharacter (SelectScene.cs:351-357)
    const name = this.nameInput.text.trim();
    if (!name) return;
    this.btnConfirm.enabled = false;
    this.conn.sendNewCharacter(name, this.createClass, this.createGender);
  }

  #onNewCharacter(p) { // ShowNewCharacterResult (SelectScene.cs:598-620)
    this.btnConfirm.enabled = true;
    if (p.result === NEWCHARACTER_SUCCESS) {
      if (p.character) this.characters.push(p.character);
      this.#refresh();
      this.#hideCreate();
    } else {
      console.warn('创建失败', NewCharacterResultText[p.result]);
    }
  }

  #onDelete() { // OnDeletePressed (SelectScene.cs:634-652)
    if (this.selectedIndex < 0) return;
    if (!confirm(`确定要删除角色 ${this.characters[this.selectedIndex].characterName} 吗?`)) return;
    this.btnDelete.enabled = false;
    this.conn.sendDeleteCharacter(this.characters[this.selectedIndex].characterIndex);
  }

  #onDeleteCharacter(p) { // OnDeleteCharacterResult (SelectScene.cs:654-669)
    if (p.result === 0) { // Success
      this.characters = this.characters.filter(c => c.characterIndex !== p.deletedIndex);
      this.selectedIndex = -1;
      this.#refresh();
    }
  }

  #onStart() { // OnStartPressed (SelectScene.cs:622-632)
    if (this.selectedIndex < 0) return;
    this.btnStart.enabled = false;
    this.conn.sendStartGame(this.characters[this.selectedIndex].characterIndex);
  }

  #onStartGame(p) { // ShowStartGameResult (SelectScene.cs:679-714)
    if (p.result === STARTGAME_SUCCESS) {
      this.onEnterGame(p.startInformation);
    } else if (p.result === STARTGAME_DELAYED) {
      setTimeout(() => {
        const idx = this.selectedIndex >= 0
          ? this.characters[this.selectedIndex].characterIndex
          : this.characters[0]?.characterIndex;
        if (idx != null) this.conn.sendStartGame(idx);
      }, 3000);
    } else {
      console.warn('进入游戏失败:', StartGameResultText[p.result]);
      this.btnStart.enabled = true;
    }
  }
}
