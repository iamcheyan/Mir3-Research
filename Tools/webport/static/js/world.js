// world.js — 共享世界控制器 (双 UI 模式共用: 协议/状态机/世界数据)
// 从 GameScene.cs 移植的世界逻辑: 地图加载/对象表/移动门控/渲染循环/事件订阅。
// UI 层 (themes/zircon, themes/ei) 只负责 HUD 外观; 本类不碰 DOM 之外的 UI 框架。
import * as data from './data.js';
import * as res from './res.js';
import { Camera } from './camera.js';
import { drawFrame, PLAYER_ANIMS } from './data.js';

const DIRS = [[0, -1], [1, -1], [1, 0], [1, 1], [0, 1], [-1, 1], [-1, 0], [-1, -1]]; // MirDirection 0-7
export { DIRS };

export class World {
  // canvas: UI 层提供的渲染目标; hooks: {onChat(text,type), onPosChange(player), onMapChange(meta)}
  constructor(conn, startInfo, canvas, hooks = {}) {
    this.conn = conn;
    this.info = startInfo;
    this.canvas = canvas;
    this.hooks = hooks;
    this.objects = new Map();      // objectID → {kind,x,y,dir,name,...}
    this.moveLock = false;         // ServerTime 门控 (GameScene.cs:836-840)
    this.camera = new Camera(canvas);
    this.camera.setResolution(innerWidth, innerHeight);
    this.camera.setZoom(1);
    addEventListener('resize', () => {
      this.camera.setResolution(innerWidth, innerHeight);
      this.camera.setZoom(1);
    });
    this.#wire();
    void this.#enterWorld();
  }

  addChat(text, type) { this.hooks.onChat?.(text, type); }

  async #enterWorld() {
    await data.loadAll();
    const maps = data.D().maps;
    // MapIndex → 文件名: maps_manifest id 字段
    let stem = null;
    for (const [s, m] of Object.entries(maps)) if (m.id === this.info.mapIndex) { stem = s; break; }
    if (!stem) { console.error('未知 MapIndex', this.info.mapIndex); return; }
    this.stem = stem;
    this.mapMeta = maps[stem];
    this.walk = await data.walkBits(stem);
    this.#applyLight();
    this.npcById = new Map((data.D().npcs ?? []).map(n => [n.id, n]));
    // 自己入对象表
    this.player = {
      kind: 'self', objectID: this.info.objectID, name: this.info.name,
      x: this.info.locationX, y: this.info.locationY, dir: this.info.direction,
      class: this.info.class, gender: this.info.gender, level: this.info.level,
      hairType: this.info.hairType, weapon: this.info.weapon, armour: this.info.armour,
    };
    this.objects.set(this.info.objectID, this.player);
    this.camera.centerOn(this.player.x * data.CELL_W, this.player.y * data.CELL_H);
    this.hooks.onPosChange?.(this.player);
    this._startLoop();
    this.addChat(`欢迎来到 ${this.mapMeta.name_cn} (${stem})`, 'system');
    this.addChat('方向键/WASD 走路, 鼠标点击移动, Enter 聊天', 'hint');
  }

  // ---- 网络事件 (GameScene 事件订阅 1119-1230) ----
  #wire() {
    const c = this.conn;
    c.addEventListener('objectMove', (e) => this.#onObjectMove(e.detail));
    c.addEventListener('objectTurn', (e) => {
      const d = e.detail;
      if (this.player && d.objectID === this.player.objectID) { this.player.dir = d.direction; return; }
      const o = this.objects.get(d.objectID);
      if (o) { o.dir = d.direction; o.x = d.x; o.y = d.y; }
    });
    c.addEventListener('objectRemove', (e) => this.objects.delete(e.detail.objectID));
    c.addEventListener('objectPlayer', (e) => this.#onObjectPlayer(e.detail));
    c.addEventListener('objectMonster', (e) => {
      const p = e.detail;
      this.objects.set(p.objectID, { kind: 'monster', ...p });
    });
    c.addEventListener('objectNPC', (e) => {
      const p = e.detail;
      this.objects.set(p.objectID, { kind: 'npc', ...p });
    });
    c.addEventListener('userLocation', (e) => { // 权威纠正 (OnUserLocation GameScene.cs:1856)
      const p = e.detail;
      if (!this.player) return;
      this.player.dir = p.direction;
      this.player.x = p.x; this.player.y = p.y;
      this.moveLock = false;
      this.camera.centerOn(p.x * data.CELL_W, p.y * data.CELL_H);
      this.hooks.onPosChange?.(this.player);
    });
    c.addEventListener('chat', (e) => {
      // 服务端 Text 已含发送者名 (TestHero: xxx), 不再重复前缀
      this.addChat(e.detail.text);
    });
    c.addEventListener('mapChanged', async (e) => {
      if (!this.player) return;
      const maps = data.D().maps;
      for (const [s, m] of Object.entries(maps)) if (m.id === e.detail.mapIndex) {
        this.stem = s; this.mapMeta = m;
        this.walk = await data.walkBits(s);
        this.addChat(`进入 ${m.name_cn}`, 'system');
        this.objects.clear();
        this.objects.set(this.player.objectID, this.player);
        this.hooks.onMapChange?.(m);
      }
    });
    c.addEventListener('dayTime', (e) => { // OnDayTimeChanged (GameScene.cs:1822-1825)
      this.dayTime = Math.min(1, Math.max(0, e.detail));
      this.#applyLight();
    });
    c.addEventListener('disconnected', () => this.addChat('连接已断开', 'system'));
  }

  // ---- 地图光照 (MapLightLayer.cs:105-112 AmbientFor 移植) ----
  // 环境光 = f(LightSetting, dayTime); Light/Night/Twilight 固定, Default 跟随服务器昼夜。
  // 偏差: Godot 还有 .map 格子光/物体光的径向光源 (MapLightLayer._Draw 162-174),
  // webport 无逐格 light 数据 (webres 未导出), 仅做全局环境光乘法近似。
  #applyLight() {
    const NIGHT = 0.25, TWILIGHT = 100 / 255;      // MapLightLayer.cs:15-16
    if (this.dayTime === undefined) this.dayTime = this.info?.dayTime ?? 1;
    const setting = this.mapMeta?.light ?? 'Default';
    let ambient;
    if (setting === 'Light') ambient = 1;
    else if (setting === 'Night') ambient = NIGHT;
    else if (setting === 'Twilight') ambient = TWILIGHT;
    else ambient = Math.min(1, Math.max(NIGHT, this.dayTime));
    this.lightAlpha = 1 - ambient;
  }

  #onObjectPlayer(p) {
    if (!this.player || p.objectID === this.player.objectID) return;
    this.objects.set(p.objectID, { kind: 'player', ...p });
  }

  #onObjectMove(p) { // OnObjectMove (GameScene.cs:2033-2095)
    if (!this.player) return;
    if (p.objectID === this.player.objectID) {
      // 自己: 确认预测 (ShowUserLocation GameScene.cs:7715)
      this.player.dir = p.direction;
      this.player.x = p.x; this.player.y = p.y;
      this.moveLock = false;
      this.hooks.onPosChange?.(this.player);
    } else {
      const o = this.objects.get(p.objectID);
      if (o) { o.x = p.x; o.y = p.y; o.dir = p.direction; }
    }
  }

  // ---- 输入 (MouseWalker + 键盘方向) ----
  #bindKeys() {
    this.keys = new Set();
    addEventListener('keydown', (ev) => {
      const k = ev.key.toLowerCase();
      this.keys.add(k);
    });
    addEventListener('keyup', (ev) => this.keys.delete(ev.key.toLowerCase()));
    // 点击移动: 目标格 → 逐步走向 (MouseWalker 一步一发 + ServerTime 门控)
    this.canvas.addEventListener('mousedown', (ev) => {
      if (this.moveLock || !this.player) return;
      const w = this.camera.screenToWorld(ev.clientX, ev.clientY);
      const tx = Math.floor(w.x / data.CELL_W), ty = Math.floor(w.y / data.CELL_H);
      this.#stepTowards(tx, ty);
    });
    // 键盘走路节拍
    this.lastKeyStep = 0;
  }

  #dirIndex(dx, dy) {
    for (let i = 0; i < 8; i++) if (DIRS[i][0] === dx && DIRS[i][1] === dy) return i;
    return 0;
  }

  #stepTowards(tx, ty) {
    const p = this.player;
    let dx = Math.sign(tx - p.x), dy = Math.sign(ty - p.y);
    if (dx === 0 && dy === 0) return;
    const dir = this.#dirIndex(dx, dy);
    this.#tryMove(dir);
  }

  #tryMove(dir) { // CanPlayerMove + 门控 (GameScene.cs:836-840)
    if (this.moveLock) return;
    const p = this.player;
    const nx = p.x + DIRS[dir][0], ny = p.y + DIRS[dir][1];
    if (this.walk && !data.walkable(this.walk, nx, ny, this.mapMeta.w)) {
      // 尝试绕行 (BestWalkDirection MouseWalker.cs:262)
      const alts = [dir, this.#dirIndex(DIRS[dir][0], 0), this.#dirIndex(0, DIRS[dir][1])];
      for (const d of alts) {
        const ax = p.x + DIRS[d][0], ay = p.y + DIRS[d][1];
        if (data.walkable(this.walk, ax, ay, this.mapMeta.w)) {
          this.#sendMove(d, ax, ay);
          return;
        }
      }
      return;
    }
    this.#sendMove(dir, nx, ny);
  }

  #sendMove(dir, nx, ny) {
    this.moveLock = true;
    // 预测位移 (SendMouseMove GameScene.cs:7854-7905)
    this.player.x = nx; this.player.y = ny; this.player.dir = dir;
    this.hooks.onPosChange?.(this.player);
    this.conn.sendMove(dir, 1);
    setTimeout(() => { // 5s 兜底解锁 (GameScene.cs:7894)
      if (this.moveLock) { this.moveLock = false; }
    }, 5000);
  }

  // 聊天发送 (UI 层输入框调用)
  sendChat(text) { this.conn.sendChat(text); }

  _startLoop() {
    this.#bindKeys();
    requestAnimationFrame(() => this._frame());
  }
  _frame = () => {
    requestAnimationFrame(this._frame);
    const now = performance.now();
    // 键盘连续走路 (600ms/段 MouseWalker.cs:56)
    if (this.player && this.walk) {
      const k = this.keys;
      let dx = 0, dy = 0;
      if (k.has('arrowup') || k.has('w')) dy = -1;
      else if (k.has('arrowdown') || k.has('s')) dy = 1;
      if (k.has('arrowleft') || k.has('a')) dx = -1;
      else if (k.has('arrowright') || k.has('d')) dx = 1;
      if ((dx || dy) && now - this.lastKeyStep > 600 && !this.moveLock) {
        this.lastKeyStep = now;
        this.#tryMove(this.#dirIndex(dx, dy));
      }
    }
    if (!this.player) return;
    // 相机跟随 (camera lerp main.js:413) + 瓦片渲染
    this.camera.x += (this.player.x * data.CELL_W - this.camera.x) * 0.25;
    this.camera.y += (this.player.y * data.CELL_H - this.camera.y) * 0.25;
    this.camera.drawMap(this.stem, this.mapMeta.tiles);
    this.#drawObjects();
    // 环境光覆盖 (MapLightLayer: 世界之上、UI 之下)
    if (this.lightAlpha > 0.001) {
      const ctx = this.camera.ctx;
      ctx.fillStyle = `rgba(0,0,0,${this.lightAlpha})`;
      ctx.fillRect(0, 0, this.canvas.width, this.canvas.height);
    }
  };

  async #drawObjects() {
    const cam = this.camera;
    const list = [...this.objects.values()].filter(o =>
      Math.abs(o.x - this.player.x) <= 14 && Math.abs(o.y - this.player.y) <= 12);
    list.sort((a, b) => a.y - b.y);
    for (const o of list) {
      const sp = cam.worldToScreen(o.x * data.CELL_W, o.y * data.CELL_H);
      const sx = sp.x, sy = sp.y;
      if (o.kind === 'self' || o.kind === 'player') {
        await this.#drawPlayer(o, sx, sy);
      } else if (o.kind === 'npc') {
        const npc = this.npcById?.get(o.npcIndex);
        if (npc) {
          const f = await res.loadSprite('NPC', data.npcFrame(npc.image, 0));
          if (f) this.#blit(f, sx, sy);
        }
      } else if (o.kind === 'monster') {
        const mon = (data.D().monsters ?? []).find(m => m.index === o.monsterIndex);
        if (mon) {
          const f = await res.loadSprite(mon.lib, data.monsterFrame(mon.shape, 'standing', 0, o.dir));
          if (f) this.#blit(f, sx, sy);
        }
      }
      // 名字
      if (o.name) {
        cam.ctx.font = '12px "Noto Sans CJK SC"';
        cam.ctx.textAlign = 'center';
        cam.ctx.fillStyle = 'rgba(0,0,0,.7)';
        cam.ctx.fillText(o.name, sx + 1, sy - 25);
        cam.ctx.fillStyle = o.kind === 'self' ? '#8cf' : '#fff';
        cam.ctx.fillText(o.name, sx, sy - 26);
      }
    }
  }

  #blit(f, sx, sy) { // 底中锚定 (sprites.js drawFramed: cell bottom-center)
    const w = f.naturalWidth ?? f.width, h = f.naturalHeight ?? f.height;
    this.camera.ctx.drawImage(f, sx - w / 2, sy - h + 16);
  }

  async #drawPlayer(o, sx, sy) {
    // 站立动画帧 (playerFrames standing (0,4) — Godot FrameSet)
    const anim = PLAYER_ANIMS.standing;
    const base = drawFrame(anim, 0, o.dir);
    const libs = data.pickLibs({
      cls: ['Warrior', 'Wizard', 'Taoist', 'Assassin'][o.class] ?? 'Warrior',
      gender: o.gender === 1 ? 'F' : 'M',
      armourShape: o.armour ?? 0, weaponShape: o.weapon ?? 0, helmetShape: 0,
    });
    const f = await res.loadSprite(libs.body, base);
    if (f) this.#blit(f, sx, sy);
    const wf = o.weapon ? await res.loadSprite(libs.weapon, base) : null;
    if (wf) this.#blit(wf, sx, sy);
  }
}
