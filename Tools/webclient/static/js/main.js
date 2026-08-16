// main.js — 浏览器世界观测试台入口
// 职责: 组装 world/render/input/ui, 主循环 (V-Sync 开关= rAF vs 定时器),
//       地图切换过场, GM 命令解析, 设置持久化, 大地图/小地图, 自动药水。
import { loadAll, D, CELL_W, CELL_H, TILE } from './data.js';
import { Camera } from './camera.js';
import { World } from './world.js';
import { Renderer } from './render.js';
import { Input, STEP } from './input.js';
import { UI, CLASS_NAMES } from './ui.js';
import { pendingCount, tileURL, loadTile } from './res.js';
import { makeFF, createFxEngine, dir8To, frameDelays } from './effects.js';

class Game {
  constructor() {
    this.canvas = document.getElementById('game');
    this.cam = new Camera(this.canvas);
    this.ctx = this.canvas.getContext('2d');
    this.world = new World(this);
    this.renderer = new Renderer(this);
    this.ui = new UI(this);
    this.input = new Input(this);
    this.hoverCell = null;
    this.settings = this.loadSettings();
    this.lastT = performance.now();
    this.fps = 0; this._fpsCnt = 0; this._fpsT = 0;
    this._entityHits = [];        // 最近一帧实体屏幕坐标 (点击检测)
    this._rafId = null;
    this._timerId = null;
  }

  loadSettings() {
    const def = {
      resW: 1280, resH: 720, zoom: 1, uiZoom: 1, vsync: true,
      drawEffects: true, drawParticles: true, showNames: true,
      showNpcs: true, showMons: true, showExits: true, borderless: false,
      autoPot: false, autoPotHp: 50, autoPotMp: 30,
    };
    try { return { ...def, ...JSON.parse(localStorage.getItem('wc_settings') || '{}') }; }
    catch { return def; }
  }

  saveSettings() {
    localStorage.setItem('wc_settings', JSON.stringify(this.settings));
  }

  applySettings() {
    const s = this.settings;
    this.cam.setResolution(s.resW, s.resH);
    this.cam.setZoom(s.zoom);
    // UI 缩放: Godot UiScaler = clamp(min(h/768, w/1024), 1, 2) 应用于档位, 手动档覆盖
    document.documentElement.style.setProperty('--ui-zoom', s.uiZoom);
    document.getElementById('app').style.zoom = s.uiZoom;
    this.renderer.showNames = s.showNames;
    this.renderer.showNpcs = s.showNpcs;
    this.renderer.showMons = s.showMons;
    this.renderer.showExits = s.showExits;
    this.renderer.drawEffects = s.drawEffects;
    this.renderer.drawParticles = s.drawParticles;
    this.restartLoop();
  }

  restartLoop() {
    if (this._rafId) cancelAnimationFrame(this._rafId);
    if (this._timerId) clearInterval(this._timerId);
    this._rafId = null; this._timerId = null;
    this._frameBusy = false;   // 上一循环若挂起, 强制解锁
    if (this.settings.vsync) {
      // rAF 独立驱动: 每显示帧都调度下一帧, 异步 frame() 重入时跳过
      const tick = (ts) => {
        this._rafId = requestAnimationFrame(tick);
        if (!this._frameBusy) {
          this._frameBusy = true;
          this.frame().finally(() => { this._frameBusy = false; });
        }
      };
      this._rafId = requestAnimationFrame(tick);
    } else {
      // V-Sync off: 250Hz 定时器驱动 (演示帧率差异; 受渲染管线限制)
      this._timerId = setInterval(() => {
        if (!this._frameBusy) {
          this._frameBusy = true;
          this.frame().finally(() => { this._frameBusy = false; });
        }
      }, 4);
    }
  }


  async init() {
    this.ui.setLoadingText('加载地图清单…');
    await loadAll((label) => this.ui.setLoadingText(`加载${label}…`));
    // E5: 特效引擎 + 帧公式 (ClientData 同源)
    this.FF = makeFF(D().frameFormulas || {});
    this.fx = createFxEngine({
      toScreen: (wx, wy) => this.cam.worldToScreen(wx, wy),
    });
    this.renderer.fxEngine = this.fx;
    this.applySettings();
    this.ui.fillBelt();
    this.input.bind();
    this.world.onMapChange = (stem, m) => {
      this.ui.setMapLabel(stem, m);
      this.ui.log(`进入 [${m.name_cn}] (${stem})`, 'sys');
    };
    // E5/C2: 位置持久化 — 每图记忆最后坐标 (localStorage wc_pos:<stem>)
    const sp = D().manifest.spawn;
    let sx = sp.x, sy = sp.y;
    try {
      const saved = JSON.parse(localStorage.getItem(`wc_pos:${sp.map}`) || 'null');
      if (saved && Number.isInteger(saved.x) && Number.isInteger(saved.y)) { sx = saved.x; sy = saved.y; }
    } catch { /* 忽略坏档 */ }
    await this.world.enterMap(sp.map, sx, sy);
    this.savePos();
    this.centerCamera();
    this.ui.hideLoading();
    this.ui.log('欢迎来到 Mir3 浏览器世界观测试台 (GM 满配 255 级)', 'sys');
    this.ui.log('方向键/WASD 移动 · S 技能(点地面/怪物选目标施放) · B 大地图 · G GM面板 · Enter @命令', 'sys');
    this.restartLoop();
  }

  savePos() {
    const p = this.world.player;
    try { localStorage.setItem(`wc_pos:${this.world.map}`, JSON.stringify({ x: p.x, y: p.y })); } catch { }
  }

  centerCamera() {
    const p = this.world.player;
    this.cam.centerOn(p.x * CELL_W + CELL_W / 2, p.y * CELL_H + CELL_H / 2);
  }
  // ---- 移动一步 ----
  tryStep(dir) {
    const w = this.world;
    const p = w.player;
    const [dx, dy] = STEP[dir];
    const nx = p.x + dx, ny = p.y + dy;
    p.anim = 'walking';
    if (!w.canWalk(nx, ny)) {
      p.animFrame = 0;
      return;
    }
    p.x = nx; p.y = ny;
    this.savePos();
    // 出口?
    const exit = w.exitAt(nx, ny);
    if (exit && !w.transitioning) {
      this.transition(exit);
      return;
    }
    // 拾取
    const got = w.pickupAt();
    if (got) this.ui.toast(`拾取: ${got.zh}`);
  }

  // ---- 地图切换 (过场渐变) ----
  async transition(exit) {
    const w = this.world;
    w.transitioning = true;
    const fade = document.getElementById('fade');
    fade.style.opacity = 1;
    const t0 = performance.now();
    this.ui.log(`→ ${D().manifest.maps[exit.to]?.name_cn || exit.to} (${exit.to})`, 'sys');
    await new Promise((r) => setTimeout(r, 380));
    this._lastSwitchMs = performance.now();
    this.cam.tileImgs.clear();     // 换图: 旧瓦片全部失效
    await w.enterMap(exit.to, exit.tx, exit.ty);
    this.savePos();
    // 等首批瓦片
    const waitStart = performance.now();
    await new Promise((r) => {
      const check = () => {
        if (pendingCount(exit.to) === 0 || performance.now() - waitStart > 3000) r();
        else requestAnimationFrame(check);
      };
      check();
    });
    this.mapSwitchMs = performance.now() - t0;
    fade.style.opacity = 0;
    w.transitioning = false;
  }

  // ---- 传送 (GM) ----
  async teleport(stem, x, y) {
    const w = this.world;
    w.transitioning = true;
    const fade = document.getElementById('fade');
    fade.style.opacity = 1;
    const t0 = performance.now();
    await new Promise((r) => setTimeout(r, 380));
    try {
      this.cam.tileImgs.clear();   // 换图: 旧瓦片全部失效
      await w.enterMap(stem, x ?? undefined, y ?? undefined);
      this.savePos();
      this.centerCamera();        // 直接对准落点 (不走渐近跟随, 避免扫过途中区域)
      const waitStart = performance.now();
      await new Promise((r) => {
        const check = () => {
          if (pendingCount(stem) === 0 || performance.now() - waitStart > 3000) r();
          else requestAnimationFrame(check);
        };
        check();
      });
      this.mapSwitchMs = performance.now() - t0;
      this.ui.log(`@move ${stem} ${w.player.x} ${w.player.y}`, 'gm');
    } catch (e) {
      this.ui.log(`传送失败: ${e.message}`, 'err');
    }
    fade.style.opacity = 0;
    w.transitioning = false;
  }

  // ---- 施法 (E5/C3: 帧公式分派动作 + ClientData 特效编排) ----
  castMagic(m) {
    const p = this.world.player;
    const table = D().magicEffects || {};
    const entry = table[m.key];
    const hasVisual = entry && (entry.start || entry.release);
    const anim = this.FF ? this.FF.animOf(m.key) : 'combat2';
    // 目标选择: 悬停实体优先 (怪物/召唤物), 否则悬停格为落点, 否则面前 3 格
    let target = null, point = null;
    const hover = this.hoverEnt || null;
    if (hover && (hover.kind === 'mon' || hover.kind === 'npc')) target = { x: hover.x, y: hover.y };
    else if (this.hoverCell && this.world.canWalk(this.hoverCell.x, this.hoverCell.y))
      point = { ...this.hoverCell };
    else {
      const [dx, dy] = STEP[p.dir];
      point = { x: p.x + dx * 3, y: p.y + dy * 3 };
    }
    const aim = target || point;
    p.dir = dir8To(p, aim);
    p.anim = anim; p.animFrame = 0; p.animT = 0; p.inCombat = true;

    if (hasVisual) {
      this.fx.playFromEntry(entry, {
        magicKey: m.key, caster: { x: p.x, y: p.y }, target, point,
        ff: this.FF, aoeRadius: 2,
        log: (ms, text) => this.ui.log(`  ${text}`, 'sys'),
      });
      this.ui.log(`施法 [${m.zh}] ${anim} → (${aim.x},${aim.y})`, 'sys');
    } else {
      // 兜底: 图标放大动画
      this.world.effects.push({ fallbackIcon: m.icon, x: p.x, y: p.y, t: 0 });
      this.ui.log(`施法 [${m.zh}] (无特效数据, 图标兜底)`, 'sys');
    }
  }

  // ---- GM 命令解析 ----
  execCommand(raw) {
    const ui = this.ui;
    if (!raw.startsWith('@')) { ui.log(raw, 'sys'); return; }
    const parts = raw.slice(1).split(/\s+/);
    const cmd = parts[0].toLowerCase();
    const w = this.world, p = w.player;
    const findMap = (q) => {
      q = q.toLowerCase();
      return Object.entries(D().manifest.maps).find(([stem, m]) =>
        stem.toLowerCase() === q || m.name_cn === q || m.name_en.toLowerCase() === q || String(m.id) === q);
    };
    switch (cmd) {
      case 'move': case 'map': case 'goto': {
        const hit = findMap(parts[1] || '');
        if (!hit) { ui.log(`@move: 找不到地图 '${parts[1]}'`, 'err'); break; }
        const x = parts[2] ? parseInt(parts[2]) : null;
        const y = parts[3] ? parseInt(parts[3]) : null;
        this.teleport(hit[0], x, y);
        break;
      }
      case 'spawn': {
        const q = parts.slice(1).join(' ').toLowerCase();
        const mon = D().monsters.find((m) => m.zh === q || m.name.toLowerCase() === q ||
          m.img.toLowerCase() === q || m.zh.includes(q));
        if (!mon) { ui.log(`@spawn: 找不到怪物 '${q}'`, 'err'); break; }
        w.summon(mon.id, p.x + 1, p.y);
        ui.log(`@spawn ${mon.name} → (${p.x + 1},${p.y})`, 'gm');
        break;
      }
      case 'make': {
        const q = parts.slice(1).join(' ');
        const it = D().items.find((i) => i.zh === q || i.name === q || i.zh.includes(q) || i.name.includes(q));
        if (!it) { ui.log(`@make: 找不到物品 '${q}'`, 'err'); break; }
        w.dropItem(it.id, p.x, p.y + 1);
        ui.log(`@make ${it.name} → (${p.x},${p.y + 1})`, 'gm');
        break;
      }
      case 'level': {
        p.level = Math.max(1, Math.min(255, parseInt(parts[1]) || 255));
        ui.log(`@level ${p.level}`, 'gm');
        break;
      }
      case 'hide': case 'invisible': {
        p.invis = !p.invis;
        ui.log(`@hide ${p.invis ? 'on' : 'off'}`, 'gm');
        break;
      }
      case 'speed': {
        p.speed = Math.max(0.5, Math.min(5, parseFloat(parts[1]) || 1));
        ui.log(`@speed ${p.speed}`, 'gm');
        break;
      }
      case 'pet': {
        const kind = parts[1] === '神兽' || parts[1] === 'shinsoo' ? 'shinsoo' : 'skeleton';
        w.addPet(kind);
        ui.log(`@pet ${kind === 'shinsoo' ? '神兽' : '骷髅'}`, 'gm');
        break;
      }
      case 'where': {
        const m = D().manifest.maps[w.map];
        ui.log(`当前: [${m.name_cn}] (${w.map}) 坐标 (${p.x},${p.y})`, 'gm');
        break;
      }
      case 'clear': {
        w.summons.length = 0; w.mons = []; w.items = []; w.pets = [];
        ui.log('@clear 场面已清空', 'gm');
        break;
      }
      default:
        ui.log(`未知命令 @${cmd} (支持: move/spawn/make/level/hide/speed/pet/where/clear)`, 'err');
    }
  }

  className(cls) { return CLASS_NAMES[cls] || cls; }

  // ---- 点击命中检测 (利用渲染时缓存的屏幕坐标) ----
  hitTest(e) {
    const rect = this.canvas.getBoundingClientRect();
    const sx = (e.clientX - rect.left) * (this.canvas.width / rect.width);
    const sy = (e.clientY - rect.top) * (this.canvas.height / rect.height);
    let best = null, bestD = 1e9;
    for (const en of this.renderer.lastEnts || []) {
      if (!en._sx || !en.info) continue;
      const d = Math.hypot(en._sx - sx, en._sy - 40 * this.cam.zoom - sy);
      if (d < 60 * this.cam.zoom && d < bestD) { bestD = d; best = en; }
    }
    return best;
  }

  // ---- 大地图 ----
  async renderBigmap(el) {
    const cv = document.getElementById('bigmap-canvas');
    const info = document.getElementById('bigmap-info');
    const m = D().manifest.maps[this.world.map];
    const scale = Math.min(1400 / (m.w * CELL_W), 700 / (m.h * CELL_H), 1);
    cv.width = Math.max(320, Math.floor(m.w * CELL_W * scale));
    cv.height = Math.max(240, Math.floor(m.h * CELL_H * scale));
    const c = cv.getContext('2d');
    c.fillStyle = '#101014';
    c.fillRect(0, 0, cv.width, cv.height);
    // 瓦片缩略 (只取 1/4 密度避免海量请求)
    const [nx, ny] = m.tiles;
    // 目标: ≤24x24 = ≤576 采样瓦片; step 保证覆盖率
    const target = 24;
    const step = Math.max(1, Math.ceil(Math.max(nx, ny) / target));
    const jobs = [];
    for (let ty = 0; ty < ny; ty += step) {
      for (let tx = 0; tx < nx; tx += step) {
        jobs.push([tx, ty]);
      }
    }
    // 分帧绘制避免阻塞
    const drawJob = async () => {
      const batch = jobs.splice(0, 24);
      for (const [tx, ty] of batch) {
        const im = await loadTile(this.world.map, tx, ty);
        if (im) c.drawImage(im, tx * TILE * scale, ty * TILE * scale,
                            TILE * scale * step + 1, TILE * scale * step + 1);
      }
      if (jobs.length) requestAnimationFrame(drawJob);
    };
    drawJob();
    await new Promise((r) => setTimeout(r, 1200));   // 先画一部分再叠标记
    // NPC 标记
    c.fillStyle = '#7de27d';
    for (const n of this.world.npcs) {
      c.fillRect(n.x * CELL_W * scale - 1, n.y * CELL_H * scale - 4, 3, 3);
    }
    // 出口标记
    c.fillStyle = '#8cdcff';
    for (const e of m.exits) {
      c.fillRect(e.x * CELL_W * scale - 2, e.y * CELL_H * scale - 5, 5, 5);
    }
    // 玩家
    const p = this.world.player;
    c.fillStyle = '#ff6a6a';
    c.beginPath();
    c.arc(p.x * CELL_W * scale, p.y * CELL_H * scale, 4, 0, Math.PI * 2);
    c.fill();
    info.textContent = `${m.name_cn} (${this.world.map}) — 绿=NPC(${this.world.npcs.length}) 蓝=出口(${m.exits.length}) 红=玩家 · 点击传送到该处`;
    cv.onclick = (ev) => {
      const r = cv.getBoundingClientRect();
      const x = Math.floor((ev.clientX - r.left) / r.width * m.w);
      const y = Math.floor((ev.clientY - r.top) / r.height * m.h);
      this.teleport(this.world.map, x, y);
      el.classList.add('hidden');
    };
  }

  // ---- 小地图 ----
  drawMinimap() {
    const cv = document.getElementById('minimap');
    const c = cv.getContext('2d');
    const m = D().manifest.maps[this.world.map];
    const s = Math.min(cv.width / m.w, cv.height / m.h);
    const p = this.world.player;
    const vw = Math.ceil(cv.width / s / 40), vh = Math.ceil(cv.height / s / 40); // 视野格数
    c.fillStyle = '#000';
    c.fillRect(0, 0, cv.width, cv.height);
    // 世界 → 小地图 (以玩家为中心)
    const toMini = (x, y) => [cv.width / 2 + (x - p.x) * s, cv.height / 2 + (y - p.y) * s];
    c.fillStyle = '#3a4a5a';
    for (let y = p.y - vh; y <= p.y + vh; y++) {
      for (let x = p.x - vw; x <= p.x + vw; x++) {
        if (x < 0 || y < 0 || x >= m.w || y >= m.h) continue;
        if (this.world.canWalk(x, y)) { const [mx, my] = toMini(x, y); c.fillRect(mx, my, Math.ceil(s), Math.ceil(s)); }
      }
    }
    c.fillStyle = '#7de27d';
    for (const n of this.world.npcs) { const [mx, my] = toMini(n.x, n.y); c.fillRect(mx - 1, my - 1, 3, 3); }
    c.fillStyle = '#8cdcff';
    for (const e of m.exits) { const [mx, my] = toMini(e.x, e.y); c.fillRect(mx - 1, my - 1, 3, 3); }
    c.fillStyle = '#e07a7a';
    for (const mo of this.world.mons) { const [mx, my] = toMini(mo.x, mo.y); c.fillRect(mx - 1, my - 1, 2, 2); }
    c.fillStyle = '#ff6a6a';
    const [px, py] = toMini(p.x, p.y);
    c.beginPath(); c.arc(px, py, 3, 0, Math.PI * 2); c.fill();
  }

  // ---- 自动药水 ----
  autoPotion() {
    const s = this.settings;
    if (!s.autoPot) return;
    const p = this.world.player;
    if (p.hp / p.hpMax * 100 < s.autoPotHp) {
      const slot = this.ui.belt.find((b) => b.item && performance.now() >= b.cdUntil);
      if (slot) this.ui.useBeltSlot(this.ui.belt.indexOf(slot));
    }
  }

  // ---- 主帧 ----
  async frame() {
    const now = performance.now();
    const dt = Math.min(64, now - this.lastT);
    this.lastT = now;
    this._fpsCnt++;
    if (now - this._fpsT > 1000) {
      this.fps = this._fpsCnt; this._fpsCnt = 0; this._fpsT = now;
      this.ui.setFps(this.fps);
    }
    if (this.world.transitioning) {
      // 过场: 不推进游戏逻辑, 但保持地图渲染 (瓦片加载/淡入由渲染帧驱动)
      this.renderer.frame(dt);
      return;
    }
    this.input.update(dt);
    this.world.update(dt);   // E5/C3: 动画推进接回主循环 (旧代码从未调用, combat 动作卡死在第0帧)
    this.autoPotion();
    // 镜头跟随
    const p = this.world.player;
    const tx = p.x * CELL_W + CELL_W / 2, ty = p.y * CELL_H + CELL_H / 2;
    this.cam.centerOn(
      this.cam.x + (tx - this.cam.x) * 0.25,
      this.cam.y + (ty - this.cam.y) * 0.25,
    );
    this.renderer.frame(dt);
    this.drawMinimap();
    this.ui.updateOrbs();
  }
}

const game = new Game();
window.game = game;   // 调试/截图脚本入口
game.init().catch((e) => {
  console.error(e);
  const el = document.getElementById('loading-text');
  if (el) el.textContent = `加载失败: ${e.message} (请确认 serve.py :8822 已启动)`;
});
