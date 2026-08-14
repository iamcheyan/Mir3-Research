// themes/ei/select.js — EI 参考模式选人页 (webclient 风格 CSS 面板; 逻辑层共用)
import {
  NewCharacterResultText, NEWCHARACTER_SUCCESS,
  DeleteCharacterResultText, DELETECHARACTER_SUCCESS,
  StartGameResultText, STARTGAME_SUCCESS, STARTGAME_DELAYED,
} from '../../net.js';

const CLASS_NAMES = ['战士', '法师', '道士', '刺客'];
const css = `
.ei-select-root { position:absolute; inset:0; display:flex; align-items:center; justify-content:center; gap:16px;
  background: radial-gradient(ellipse at 50% 30%, #241f16 0%, #0a0a0e 70%); font-family:"Noto Sans CJK SC",sans-serif; }
.ei-char-panel { width:400px; }
.ei-char-list { display:flex; flex-direction:column; gap:8px; padding:12px 14px 0; }
.ei-char { display:flex; align-items:center; gap:10px; padding:8px 10px; border:1px solid #6b5a33;
  background:rgba(20,18,12,.85); border-radius:3px; cursor:pointer; color:#ddd; font-size:13px; }
.ei-char.selected { border-color:#e8c96a; background:rgba(74,63,36,.6); }
.ei-char .cls { color:#d8c690; width:36px; }
.ei-char .lvl { color:#8fd18f; width:44px; }
.ei-char .loc { color:#9c8f6f; flex:1; font-size:12px; }
.ei-panel-footer { display:flex; gap:8px; padding:12px 14px 14px; }
.ei-create { display:none; }
.ei-create.open { display:block; }
.ei-opt { display:flex; gap:10px; align-items:center; }
.ei-opt label { color:#d8c690; }
`;

export class SelectScene {
  constructor(conn, characters, onEnterGame) {
    this.conn = conn;
    this.characters = characters ?? [];
    this.onEnterGame = onEnterGame;
    this.selectedIndex = this.characters.length > 0 ? 0 : -1;
    this.maps = undefined;
    this.locationEls = [];

    this.root = document.createElement('div');
    this.root.className = 'ei-select-root';
    const style = document.createElement('style');
    style.textContent = css;
    this.root.appendChild(style);

    // 角色列表面板
    const panel = document.createElement('div');
    panel.className = 'ei-panel ei-char-panel';
    panel.innerHTML = `<div class="ei-title">选择角色（EI 风格）</div>
      <div class="ei-char-list" id="ei-char-list"></div>
      <div class="ei-panel-footer">
        <button class="ei-btn" id="ei-start" disabled>进入游戏</button>
        <button class="ei-btn" id="ei-create-open">创建角色</button>
        <button class="ei-btn" id="ei-delete" disabled>删除角色</button>
      </div>`;
    this.root.appendChild(panel);

    // 创建面板
    const create = document.createElement('div');
    create.className = 'ei-panel ei-create';
    create.innerHTML = `<div class="ei-title">创建角色</div>
      <div class="ei-body">
        <div class="ei-row"><label>名字</label><input class="ei-input" id="ei-new-name" maxlength="20"></div>
        <div class="ei-opt"><label>职业</label>
          <label><input type="radio" name="ei-cls" value="0" checked>战士</label>
          <label><input type="radio" name="ei-cls" value="1">法师</label>
          <label><input type="radio" name="ei-cls" value="2">道士</label>
          <label><input type="radio" name="ei-cls" value="3">刺客</label>
        </div>
        <div class="ei-opt"><label>性别</label>
          <label><input type="radio" name="ei-gender" value="0" checked>男</label>
          <label><input type="radio" name="ei-gender" value="1">女</label>
        </div>
        <div class="ei-row">
          <span style="flex:1"></span>
          <button class="ei-btn" id="ei-create-ok">确认创建</button>
          <button class="ei-btn" id="ei-create-cancel">取消</button>
        </div>
        <div class="ei-status" id="ei-create-status"></div>
      </div>`;
    this.root.appendChild(create);

    this.charListEl = panel.querySelector('#ei-char-list');
    this.btnStart = panel.querySelector('#ei-start');
    this.btnDelete = panel.querySelector('#ei-delete');
    this.createPanel = create;
    this.createStatus = create.querySelector('#ei-create-status');

    panel.querySelector('#ei-create-open').addEventListener('click', () => {
      if (this.characters.length < 4) create.classList.toggle('open');
    });
    create.querySelector('#ei-create-cancel').addEventListener('click', () => create.classList.remove('open'));
    create.querySelector('#ei-create-ok').addEventListener('click', () => this.#onCreate());
    this.btnStart.addEventListener('click', () => this.#onStart());
    this.btnDelete.addEventListener('click', () => this.#onDelete());

    this.#refresh();
    this.#loadMaps();
    this.#wire();
  }

  async #loadMaps() { // Globals.MapInfoList 等价: maps_manifest id→中文名
    try {
      const m = await fetch('/res/data/maps_manifest.json').then(r => r.ok ? r.json() : null);
      this.maps = m?.maps ?? null;
    } catch { this.maps = null; }
    for (const { el, index } of this.locationEls) el.textContent = this.#locationName(index);
  }

  #locationName(index) {
    if (!this.maps) return '新角色';
    for (const [stem, m] of Object.entries(this.maps)) {
      if (m.id === index) return m.name_cn || stem;
    }
    return '新角色';
  }

  #refresh() {
    this.charListEl.replaceChildren();
    this.locationEls = [];
    this.characters.forEach((c, i) => {
      const row = document.createElement('div');
      row.className = 'ei-char' + (i === this.selectedIndex ? ' selected' : '');
      const loc = document.createElement('span');
      loc.className = 'loc';
      loc.textContent = this.#locationName(c.location);
      this.locationEls.push({ el: loc, index: c.location });
      row.append(
        Object.assign(document.createElement('span'), { className: 'cls', textContent: CLASS_NAMES[c.class] ?? '?' }),
        Object.assign(document.createElement('span'), { textContent: c.characterName }),
        Object.assign(document.createElement('span'), { className: 'lvl', textContent: `Lv.${c.level}` }),
        loc,
      );
      row.addEventListener('click', () => this.#selectChar(i));
      this.charListEl.appendChild(row);
    });
    const has = this.characters.length > 0 && this.selectedIndex >= 0;
    this.btnStart.disabled = !has;
    this.btnDelete.disabled = !has;
  }

  #selectChar(i) {
    this.selectedIndex = i;
    [...this.charListEl.children].forEach((el, j) => el.classList.toggle('selected', j === i));
    this.btnStart.disabled = false;
    this.btnDelete.disabled = false;
  }

  #wire() {
    this.conn.addEventListener('newCharacterResult', (e) => this.#onNewCharacter(e.detail));
    this.conn.addEventListener('deleteCharacterResult', (e) => this.#onDeleteCharacter(e.detail));
    this.conn.addEventListener('startGameResult', (e) => this.#onStartGame(e.detail));
  }

  #onCreate() {
    const name = this.createPanel.querySelector('#ei-new-name').value.trim();
    if (!name) { this.createStatus.textContent = '请输入角色名'; return; }
    const cls = +this.createPanel.querySelector('input[name="ei-cls"]:checked').value;
    const gender = +this.createPanel.querySelector('input[name="ei-gender"]:checked').value;
    this.createStatus.textContent = '正在创建...';
    this.conn.sendNewCharacter(name, cls, gender);
  }

  #onNewCharacter(p) {
    if (p.result === NEWCHARACTER_SUCCESS) {
      if (p.character) { this.characters.push(p.character); this.selectedIndex = this.characters.length - 1; }
      this.createPanel.classList.remove('open');
      this.createStatus.textContent = '';
      this.#refresh();
    } else {
      this.createStatus.textContent = `创建失败: ${NewCharacterResultText[p.result] ?? p.result}`;
    }
  }

  #onStart() {
    if (this.selectedIndex < 0) return;
    this.btnStart.disabled = true;
    this.conn.sendStartGame(this.characters[this.selectedIndex].characterIndex);
  }

  #onDelete() {
    if (this.selectedIndex < 0) return;
    this.conn.sendDeleteCharacter(this.characters[this.selectedIndex].characterIndex);
  }

  #onDeleteCharacter(p) {
    if (p.result === DELETECHARACTER_SUCCESS) {
      this.characters.splice(this.selectedIndex, 1);
      this.selectedIndex = this.characters.length > 0 ? 0 : -1;
      this.#refresh();
    }
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
      this.createStatus.textContent = `进入游戏失败: ${StartGameResultText[p.result] ?? p.result}`;
      this.btnStart.disabled = false;
    }
  }
}
