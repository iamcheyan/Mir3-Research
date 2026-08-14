// themes/ei/game.js — EI 参考模式游戏场景 (webclient 风格: 顶栏/HP球/聊天/腰带)
// 世界逻辑在共享 world.js — 与 Zircon 模式同一条协议/状态机/渲染管线。
import { World } from '../../world.js';

const css = `
.ei-game { position:absolute; inset:0; display:flex; flex-direction:column; background:#101014;
  font-family:"Noto Sans CJK SC",sans-serif; }
.ei-topbar { display:flex; align-items:center; gap:10px; padding:4px 10px;
  background:linear-gradient(#3a3223,#241f16); border-bottom:1px solid #6b5a33; z-index:5; }
.ei-brand { color:#e8c96a; font-weight:bold; letter-spacing:1px; font-size:13px; }
.ei-mapname { color:#fff; font-size:13px; }
.ei-pos { color:#9c8f6f; font-family:monospace; font-size:12px; }
.ei-viewport { position:relative; flex:1; overflow:hidden; }
.ei-viewport canvas { position:absolute; inset:0; width:100%; height:100%; image-rendering:pixelated; }
.ei-chat { position:absolute; left:8px; bottom:8px; width:460px; max-width:55%; z-index:4; }
.ei-chat-log { max-height:140px; overflow-y:auto; background:rgba(8,8,10,.55);
  border:1px solid #3a3223; padding:4px 8px; font-size:12px; color:#ddd; }
.ei-chat-log .sys { color:#8fd18f; }
.ei-chat-log .hint { color:#e8c96a; }
.ei-chat-row { display:flex; gap:4px; margin-top:2px; }
.ei-chat-input { flex:1; background:rgba(8,8,10,.7); border:1px solid #3a3223;
  color:#eee; padding:3px 6px; font-size:12px; }
.ei-orbs { position:absolute; bottom:8px; right:8px; display:flex; gap:6px; z-index:4; }
.ei-orb { width:74px; height:74px; border-radius:50%; border:2px solid #6b5a33;
  background:#1a150c; position:relative; overflow:hidden; }
.ei-orb .fill { position:absolute; bottom:0; left:0; right:0; transition:height .3s; }
.ei-orb.hp .fill { background:#8c1f1f; height:100%; }
.ei-orb.mp .fill { background:#1f3f8c; height:100%; }
.ei-orb span { position:absolute; inset:0; display:flex; align-items:center; justify-content:center;
  font-size:10px; color:#fff; text-shadow:0 1px 2px #000; }
.ei-belt { position:absolute; bottom:8px; left:50%; transform:translateX(-50%);
  display:flex; gap:4px; z-index:4; }
.ei-belt-slot { width:44px; height:44px; background:rgba(20,18,12,.85); border:1px solid #6b5a33;
  color:#555; font-size:11px; display:flex; align-items:center; justify-content:center; }
`;

export class GameScene {
  constructor(conn, startInfo) {
    this.conn = conn;
    this.info = startInfo;
    this.chatLines = [];

    this.root = document.createElement('div');
    this.root.className = 'ei-game';
    const style = document.createElement('style');
    style.textContent = css;
    this.root.appendChild(style);

    this.root.innerHTML += `
      <header class="ei-topbar">
        <span class="ei-brand">Mir3 · EI 风格</span>
        <span class="ei-mapname" id="eig-map">加载中…</span>
        <span class="ei-pos" id="eig-pos"></span>
      </header>
      <div class="ei-viewport">
        <canvas id="eig-canvas"></canvas>
        <div class="ei-chat">
          <div class="ei-chat-log" id="eig-chatlog"></div>
          <div class="ei-chat-row"><input class="ei-chat-input" id="eig-chatin" placeholder="回车发言 / Esc 收起" maxlength="200"></div>
        </div>
        <div class="ei-belt" id="eig-belt"></div>
        <div class="ei-orbs">
          <div class="ei-orb hp"><div class="fill"></div><span id="eig-hp">HP —</span></div>
          <div class="ei-orb mp"><div class="fill"></div><span id="eig-mp">MP —</span></div>
        </div>
      </div>`;

    this.canvas = this.root.querySelector('#eig-canvas');
    this.mapEl = this.root.querySelector('#eig-map');
    this.posEl = this.root.querySelector('#eig-pos');
    this.chatLogEl = this.root.querySelector('#eig-chatlog');
    this.chatInput = this.root.querySelector('#eig-chatin');
    this.hpEl = this.root.querySelector('#eig-hp');
    this.mpEl = this.root.querySelector('#eig-mp');

    // 腰带占位 (Phase 2 接物品)
    const belt = this.root.querySelector('#eig-belt');
    for (let i = 0; i < 6; i++) {
      const s = document.createElement('div');
      s.className = 'ei-belt-slot';
      s.textContent = '空';
      belt.appendChild(s);
    }

    this.chatInput.addEventListener('keydown', (ev) => {
      ev.stopPropagation();
      if (ev.key === 'Enter') {
        const t = this.chatInput.value.trim();
        if (t) { this.world.sendChat(t); this.chatInput.value = ''; }
        this.chatInput.blur();
      } else if (ev.key === 'Escape') this.chatInput.blur();
    });
    // Enter 聚焦聊天 (世界层已吃 keydown, 这里在捕获阶段抢)
    addEventListener('keydown', (ev) => {
      if (ev.key === 'Enter' && document.activeElement !== this.chatInput) {
        ev.preventDefault();
        this.chatInput.focus();
      }
    }, true);

    this.world = new World(conn, startInfo, this.canvas, {
      onChat: (text, type) => this.addChat(text, type),
      onPosChange: () => this.#updatePos(),
      onMapChange: (m) => { this.mapEl.textContent = m?.name_cn ?? ''; },
    });
    for (const k of ['player', 'objects', 'stem', 'mapMeta', 'moveLock']) {
      Object.defineProperty(this, k, { get: () => this.world[k] });
    }
    this.hpEl.textContent = `HP ${this.info?.hp ?? '—'}`;
    this.mpEl.textContent = `MP ${this.info?.mp ?? '—'}`;
  }

  #updatePos() {
    const p = this.world.player;
    if (p) {
      this.posEl.textContent = `${p.x},${p.y}`;
      if (this.world.mapMeta && this.mapEl.textContent === '加载中…')
        this.mapEl.textContent = this.world.mapMeta.name_cn ?? this.world.stem;
    }
  }

  addChat(text, type = 'say') {
    this.chatLines.push({ text, type, t: Date.now() });
    if (this.chatLines.length > 250) this.chatLines.shift();
    const div = document.createElement('div');
    if (type === 'hint' || type === 'system') div.className = type === 'system' ? 'sys' : 'hint';
    div.textContent = text;
    this.chatLogEl.appendChild(div);
    while (this.chatLogEl.childElementCount > 80) this.chatLogEl.firstChild.remove();
    this.chatLogEl.scrollTop = this.chatLogEl.scrollHeight;
  }
}
