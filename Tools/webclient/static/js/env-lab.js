// env-lab.js — E5 Light Lab 环境实验室引擎（天气×昼夜×光照×特殊态）
//
// 规格事实源（逐项移植，勿凭记忆改）:
//   环境光   GodotClient/Scripts/MapLightLayer.cs AmbientFor
//            原版 Client/Scenes/Views/MapControl.cs UpdateAmbientLight:
//              Default=255×DayTime | Night=(15,15,15) | Twilight=(100,100,100) | Light=255(不渲染)
//   光源半径 MapLightLayer ObjectLightRadius=256×(0.1+L×0.04)
//            EffectLightRadius=ObjectLightRadius(max(1,fl/5))  [原版 ÷5]
//            TileLightRadius=256×(0.1+L×0.6)                   [原版 ×30×0.02]
//            AbyssGlowRadius=256×(0.1+4×0.02)=46.08
//   衰减     shader: influence=1-smoothstep(r×0.35, r, dist); brightness=max(ambient, ambient+inf×(1-ambient));
//            tint=mix(white, colour, inf×0.22)   (乘性, COLOR=scene×brightness×tint)
//   特殊态   死亡=整层 IndianRed(205,92,92) 相乘(白天也渲染,优先于深渊);
//            深渊=ambient 0 + 玩家微光 46.08 + MagicEx4 帧2000起 14帧×70ms 循环 (Zircon 8d1a6a3b)
//   天气粒子 GodotClient/Scripts/MapWeatherLayer.cs 全参数 (legacy tick=100/s)
//   光源色   GameScene.GetObjectLightSources: 火把暖色(1,0.86,0.55) / 无光源白(1,1,1)
//
// 叠加顺序 (对齐 Godot ZIndex): 地图/对象 → 天气(Z850) → 光照(Z900) → 深渊特效(原版画入光照层) → UI
import { loadSprite, frameMeta } from './res.js';
import { spriteFrame, drawFramed } from './sprites.js';
import { pickLibs, D, CELL_W, CELL_H, MONSTER_ANIMS, drawFrame } from './data.js';

const $ = (s) => document.querySelector(s);
const stage = $('#env-stage');
const ctx = stage.getContext('2d');
ctx.imageSmoothingEnabled = false;
const lightCv = document.createElement('canvas');   // 光照遮罩离屏层
lightCv.width = stage.width; lightCv.height = stage.height;
const lctx = lightCv.getContext('2d');

// ---------- 常量 (照抄 MapLightLayer.cs / MapControl.cs) ----------
const NIGHT_AMBIENT = 0.25;          // Godot 柔和月夜 (刻意偏差)
const NIGHT_ORIGINAL = 15 / 255;     // 原版严格模式
const TWILIGHT_AMBIENT = 100 / 255;
const LEGACY_TICKS = 100;            // 原版粒子 10ms tick
const INDIANRED = 'rgb(205,92,92)';
const WARM = [1.0, 0.86, 0.55];      // 火把暖色
const WHITE = [1, 1, 1];

const PLAYER = { x: 629, y: 626 };   // 场地中心 (与 Magic Lab 同区)
const BYSTANDER_SPOTS = [            // 其他玩家站位 (微光保底 L=3)
  { x: PLAYER.x - 6, y: PLAYER.y - 3 }, { x: PLAYER.x + 5, y: PLAYER.y - 2 },
  { x: PLAYER.x - 4, y: PLAYER.y + 4 }, { x: PLAYER.x + 7, y: PLAYER.y + 3 },
  { x: PLAYER.x + 1, y: PLAYER.y - 6 }, { x: PLAYER.x - 8, y: PLAYER.y + 1 },
  { x: PLAYER.x + 9, y: PLAYER.y - 5 }, { x: PLAYER.x - 2, y: PLAYER.y + 7 },
];
const DUMMY = { x: PLAYER.x + 3, y: PLAYER.y - 4 };
const TILE_LIGHT_CELL = { x: PLAYER.x - 7, y: PLAYER.y + 2 };  // 格子光演示瓦片
const FX_LIGHT_AT = { x: PLAYER.x - 3, y: PLAYER.y - 5 };      // 特效光演示位

// ---------- 全局状态 ----------
const S = {
  map: { stem: '0', w: 800, h: 800, light: 'Default', weather: 'None', name: '比奇城' },
  camX: 0, camY: 0, tiles: new Map(), manifest: null, snapshot: null,
  env: {
    setting: 'Default', dayTime: 1.0, strict: false,
    weather: { rain: false, snow: false, fog: false, lightning: false },
    intensity: 1.0,
    torch: 0,                       // Light 值; 0=无
    crowd: 3,                       // 其他玩家微光数
    fxLight: false, tileLight: false,
    state: 'normal',                // normal | dead | abyss
  },
  sprites: { player: null, bystanders: [], dummy: null },
  abyssFx: [],
};

const ANCHOR = (gx, gy) => ({ x: gx * CELL_W + CELL_W / 2 - S.camX, y: (gy + 1) * CELL_H - S.camY });

// ---------- 环境光 (AmbientFor 移植) ----------
function ambientFor(setting, dayTime, strict) {
  const night = strict ? NIGHT_ORIGINAL : NIGHT_AMBIENT;
  switch (setting) {
    case 'Light': return 1.0;
    case 'Night': return night;
    case 'Twilight': return TWILIGHT_AMBIENT;
    default: return Math.min(1, Math.max(strict ? NIGHT_ORIGINAL : NIGHT_AMBIENT, dayTime));
    // 注意: 原版 Default=255×DayTime 无下限; Godot=max(0.25,dayTime)。
    // 严格模式用 15/255 兜底近似原版 byte 截断语义, 差异记 PARITY_REPORT。
  }
}

// ---------- 光源半径 (MapLightLayer 移植) ----------
const objectLightRadius = (l) => 256 * (0.1 + Math.max(0, l) * 0.04);
const effectLightRadius = (fl) => objectLightRadius(Math.max(1, Math.floor(fl / 5)));
const tileLightRadius = (l) => 256 * (0.1 + Math.max(0, l) * 0.6);
const abyssGlowRadius = 256 * (0.1 + 4 * 0.02);   // 46.08

// smoothstep(e0,e1,x) — shader 同式
function smoothstep(e0, e1, x) {
  const t = Math.min(1, Math.max(0, (x - e0) / (e1 - e0)));
  return t * t * (3 - 2 * t);
}

// ============================================================
// 天气粒子引擎 — MapWeatherLayer.cs 逐行移植
// ============================================================
class WeatherLayer {
  constructor() { this.reset(); }
  reset() {
    this.parts = [];
    this.rainSpawn = this.snowSpawn = 0;
    this.boltTimer = 0;
    this.seed = 0x2f6e2b1;          // 简单 LCG, 便于重放
    this.imgs = {};                  // textureIndex -> Image
    this.fogTinted = null;
  }
  rnd() { this.seed = (this.seed * 1103515245 + 12345) & 0x7fffffff; return this.seed / 0x7fffffff; }
  range(a, b) { return a + this.rnd() * (b - a); }
  irange(a, b) { return Math.floor(this.range(a, b + 1)); }

  async loadAssets() {
    const names = { 500: 'snow', 509: 'rain', 510: 'splash1', 511: 'splash2',
      512: 'splash3', 513: 'splash4', 514: 'splash5', 540: 'lightning', 550: 'fog' };
    for (const [idx, n] of Object.entries(names)) {
      const im = new Image();
      im.src = `/static/assets/weather/${n}.webp?v=1`;
      await new Promise((r) => { im.onload = im.onerror = r; });
      this.imgs[idx] = im;
    }
    // 雾色 DarkGray (169,169,169) 着色 — 预生成 tint 版
    const f = this.imgs[550];
    if (f && f.naturalWidth) {
      const c = document.createElement('canvas'); c.width = f.width; c.height = f.height;
      const cc = c.getContext('2d');
      cc.drawImage(f, 0, 0);
      cc.globalCompositeOperation = 'multiply';
      cc.fillStyle = 'rgb(169,169,169)';       // Colors.DarkGray
      cc.fillRect(0, 0, c.width, c.height);
      cc.globalCompositeOperation = 'destination-in';
      cc.drawImage(f, 0, 0);
      this.fogTinted = c;
    }
  }

  setWeather(w, intensity) {
    // 切换天气组合时清空重排 (对齐 SetWeather: Clear+重播 Fog)
    const changed = JSON.stringify(w) !== JSON.stringify(this.current);
    this.intensity = intensity;
    if (changed) {
      this.current = { ...w };
      this.parts = [];
      this.rainSpawn = this.snowSpawn = this.boltTimer = 0;
      if (w.fog) this.spawnFog();
    }
  }

  countKind(tex) { let n = 0; for (const p of this.parts) if (p.tex === tex) n++; return n; }

  spawnRain(w, h) {
    const top = this.rnd() < 0.8;
    this.parts.push({
      tex: 509,
      x: top ? this.range(0, w) : w, y: top ? 1 : this.range(0, h),
      vx: -1, vy: 5, scale: this.irange(1, 2), rot: 0.4, avel: 0,
      age: 0, life: this.irange(500, 2000), opacity: 1, fadeRate: 0,
      grounded: false, fade: false, fading: false,
    });
  }
  spawnSnow(w, h) {
    this.parts.push({
      tex: 500,
      x: this.range(0, w), y: 0,
      vx: this.irange(-1, 0), vy: 1,
      scale: this.range(0, 1.5), avel: 0.1, rot: this.rnd() * Math.PI * 2,
      age: 0, life: this.irange(4000, 10000), opacity: 1, fadeRate: 0,
      grounded: false, fade: true, fading: false,
    });
  }
  spawnFog() {
    const w = stage.width, h = stage.height;
    const fogW = (this.imgs[550]?.naturalWidth) || 128;
    const n = Math.max(1, Math.round(4 * (this.intensity || 1)));
    const first = this.parts.findIndex((p) => p.tex === 550);
    if (first >= 0) this.parts = this.parts.filter((p) => p.tex !== 550);
    for (let i = 0; i < n; i++) this.parts.push({
      tex: 550, x: w / 2 - i * fogW * 4, y: h / 2,
      vx: 1, vy: 0, scale: 4, avel: 0, rot: 0,
      age: 0, life: 3600000, opacity: 1, fadeRate: 0,
      grounded: false, fade: false, fading: false,
    });
  }
  spawnBolt(w) {
    this.parts.push({
      tex: 540, x: this.range(0, w), y: 0,
      vx: 0, vy: 0, scale: this.irange(1, 3), avel: 0, rot: 0,
      age: 0, life: this.irange(100, 200), opacity: 1, fadeRate: 0.1,
      grounded: false, fade: true, fading: false,
    });
  }

  update(dtSec, w) {
    const wx = this.current || {};
    const ms = dtSec * 1000;
    const h = stage.height;
    const inten = this.intensity || 1;
    if (wx.rain) {
      this.rainSpawn += ms;
      const interval = 10 / inten;               // 强度=生成率倍率
      while (this.rainSpawn >= interval && this.parts.length < 600) {
        this.rainSpawn -= interval; this.spawnRain(w, h);
      }
    }
    if (wx.snow) {
      this.snowSpawn += ms;
      const interval = 20 / inten;
      while (this.snowSpawn >= interval && this.countKind(500) < 500) {
        this.snowSpawn -= interval; this.spawnSnow(w, h);
      }
    }
    if (wx.lightning) {
      this.boltTimer -= ms;
      if (this.boltTimer <= 0 && this.countKind(540) < 3) {
        this.spawnBolt(w);
        this.boltTimer = this.range(1000, 5000);
      }
    }
    for (let i = this.parts.length - 1; i >= 0; i--) {
      const p = this.parts[i];
      p.age += ms;
      if (!p.grounded) { p.x += p.vx * dtSec * LEGACY_TICKS; p.y += p.vy * dtSec * LEGACY_TICKS; }
      p.rot += p.avel * dtSec * LEGACY_TICKS;
      if (p.tex === 509 && p.age >= p.life && !p.grounded) {
        p.grounded = true; p.tex = 510; p.age = 0; p.life = 100;
        p.vx = p.vy = 0;   // 509→510 水花, 每 100ms 一帧
      } else if (p.grounded && p.tex >= 510 && p.tex < 514 && p.age >= 100) {
        p.tex++; p.age = 0; p.life = 100;
      } else if (p.tex === 500 && p.age >= p.life && !p.grounded) {
        p.grounded = true; p.vx = p.vy = 0; p.avel = 0;
        p.fading = true; p.age = 0; p.life = 1000;
      } else if (p.fade && p.age >= p.life) {
        p.fading = true; p.age = 0; p.life = 100;
      }
      if (p.fading) {
        if (p.tex === 540) p.opacity -= p.fadeRate * dtSec * LEGACY_TICKS;
        else p.scale -= 0.01 * dtSec * LEGACY_TICKS;
      }
      const dead = (p.grounded && p.tex >= 514 && p.age >= p.life)
        || (p.tex === 500 && p.scale <= 0)
        || (p.tex === 540 && p.opacity <= 0)
        || (p.fading && p.tex !== 500 && p.tex !== 540 && p.age >= p.life);
      if (dead) this.parts.splice(i, 1);
    }
  }

  draw(c) {
    for (const p of this.parts) {
      const img = p.tex === 550 ? this.fogTinted : this.imgs[p.tex];
      if (!img || !img.naturalWidth) continue;
      const scale = Math.max(0.01, p.scale);
      c.save();
      c.globalAlpha = Math.min(1, Math.max(0, p.opacity));
      c.translate(p.x, p.y);
      c.rotate(p.rot);
      c.scale(scale, scale);
      c.drawImage(img, -img.naturalWidth / 2, -img.naturalHeight / 2);
      c.restore();
    }
  }
}
const weather = new WeatherLayer();

// ============================================================
// 光照层 — MapLightLayer shader 语义的 canvas 移植
// ============================================================
// 亮度遮罩: alpha = 1-brightness; 光源以 destination-out 渐变擦除
// (dest×(1-inf) ≈ Godot max(ambient, ambient+inf×(1-ambient)), 多光源略保守, 见 PARITY)
function punchLight(c, x, y, r, peak = 1) {
  const g = c.createRadialGradient(x, y, 0, x, y, r);
  for (let i = 0; i <= 16; i++) {
    const t = i / 16;
    const inf = (1 - smoothstep(0.35, 1, t)) * peak;
    g.addColorStop(t, `rgba(0,0,0,${inf})`);
  }
  c.fillStyle = g;
  c.fillRect(x - r, y - r, r * 2, r * 2);
}
// 乘性色偏 (shader tint=mix(white,colour,inf×0.22)): multiply 渐变, 外圈白=不动
function tintLight(c, x, y, r, colour) {
  const g = c.createRadialGradient(x, y, 0, x, y, r);
  const mix = (k) => `rgb(${Math.round(255 * (1 - k) + 255 * colour[0] * k)},${Math.round(255 * (1 - k) + 255 * colour[1] * k)},${Math.round(255 * (1 - k) + 255 * colour[2] * k)})`;
  for (let i = 0; i <= 16; i++) {
    const t = i / 16;
    g.addColorStop(t, mix(0.22 * (1 - smoothstep(0.35, 1, t))));
  }
  c.save();
  c.globalCompositeOperation = 'multiply';
  c.fillStyle = g;
  c.fillRect(x - r, y - r, r * 2, r * 2);
  c.restore();
}

function activeSources() {
  const src = [];
  const pa = ANCHOR(PLAYER.x, PLAYER.y);
  // 玩家火把 (光心=水平中心/格顶, GameScene Position+(24,0) 语义)
  if (S.env.torch > 0) src.push({ x: pa.x, y: pa.y - CELL_H, r: objectLightRadius(S.env.torch), c: WARM });
  // 其他玩家微光保底 3
  for (let i = 0; i < Math.min(S.env.crowd, BYSTANDER_SPOTS.length); i++) {
    const b = ANCHOR(BYSTANDER_SPOTS[i].x, BYSTANDER_SPOTS[i].y);
    src.push({ x: b.x, y: b.y - CELL_H, r: objectLightRadius(3), c: WHITE });
  }
  // 特效光 FrameLight=10 → max(1,10/5)=2
  if (S.env.fxLight) {
    const f = ANCHOR(FX_LIGHT_AT.x, FX_LIGHT_AT.y);
    src.push({ x: f.x, y: f.y - CELL_H / 2, r: effectLightRadius(10), c: [0.6, 0.85, 1] });
  }
  // 格子光演示瓦片 (cell.Light=1, 原版 .map 字段, 光心=格中心)
  if (S.env.tileLight) {
    const t = ANCHOR(TILE_LIGHT_CELL.x, TILE_LIGHT_CELL.y);
    src.push({ x: t.x, y: t.y - CELL_H / 2, r: tileLightRadius(1), c: WHITE });
  }
  return src;
}

function drawLightLayer() {
  const ambient = ambientFor(S.env.setting, S.env.dayTime, S.env.strict);
  const sources = activeSources();
  // 特殊态优先: 死亡 > 深渊 > 常规 (白天也渲染)
  if (S.env.state === 'dead') {
    ctx.save();
    ctx.globalCompositeOperation = 'multiply';
    ctx.fillStyle = INDIANRED;
    ctx.fillRect(0, 0, stage.width, stage.height);
    ctx.restore();
    return { ambient: 1, tinted: true, sources: [] };
  }
  if (S.env.state === 'abyss') {
    lctx.globalCompositeOperation = 'source-over';
    lctx.clearRect(0, 0, lightCv.width, lightCv.height);
    lctx.fillStyle = 'rgba(0,0,0,1)';
    lctx.fillRect(0, 0, lightCv.width, lightCv.height);
    lctx.globalCompositeOperation = 'destination-out';
    const pa = ANCHOR(PLAYER.x, PLAYER.y);
    punchLight(lctx, pa.x, pa.y - CELL_H, abyssGlowRadius);
    lctx.globalCompositeOperation = 'source-over';
    ctx.drawImage(lightCv, 0, 0);
    return { ambient: 0, tinted: false, sources: [] };
  }
  if (ambient >= 0.999) return { ambient, tinted: false, sources };
  lctx.globalCompositeOperation = 'source-over';
  lctx.clearRect(0, 0, lightCv.width, lightCv.height);
  lctx.fillStyle = `rgba(0,0,0,${1 - ambient})`;
  lctx.fillRect(0, 0, lightCv.width, lightCv.height);
  lctx.globalCompositeOperation = 'destination-out';
  for (const s of sources) punchLight(lctx, s.x, s.y, s.r);
  lctx.globalCompositeOperation = 'source-over';
  ctx.drawImage(lightCv, 0, 0);
  for (const s of sources) tintLight(ctx, s.x, s.y, s.r, s.c);
  return { ambient, tinted: false, sources };
}

// ---------- 深渊环绕特效 (MagicEx4 2000..2013, 70ms/帧 循环) ----------
async function preloadAbyssFx() {
  for (let f = 2000; f <= 2013; f++) {
    const spr = await spriteFrame('MagicEx4', f);
    if (spr) S.abyssFx[f - 2000] = spr;
  }
}
function drawAbyssFx(nowMs) {
  const spr = S.abyssFx[Math.floor(nowMs / 70) % 14];
  if (!spr) return;
  const pa = ANCHOR(PLAYER.x, PLAYER.y);
  // 原版 CreateMagicEffect(Abyss) 画入光照层 → 黑暗中可见; 画在光照层之后等效
  ctx.save();
  ctx.globalAlpha = 0.92;
  drawFramed(ctx, spr, pa.x, pa.y);
  ctx.restore();
}

// ---------- 特效光演示标记 (光圈已由光源层承担, 这里画个脉冲星标) ----------
function drawFxLightMark(nowMs) {
  if (!S.env.fxLight) return;
  const f = ANCHOR(FX_LIGHT_AT.x, FX_LIGHT_AT.y);
  const pulse = 0.6 + 0.4 * Math.sin(nowMs / 180);
  ctx.save();
  ctx.globalCompositeOperation = 'lighter';
  const g = ctx.createRadialGradient(f.x, f.y - CELL_H / 2, 0, f.x, f.y - CELL_H / 2, 18);
  g.addColorStop(0, `rgba(140,200,255,${0.75 * pulse})`);
  g.addColorStop(1, 'rgba(140,200,255,0)');
  ctx.fillStyle = g;
  ctx.fillRect(f.x - 20, f.y - CELL_H / 2 - 20, 40, 40);
  ctx.restore();
  label('FrameLight=10', f.x, f.y + 4);
}

// ---------- 场景 ----------
const LOOKS = {
  cls: 'Warrior', gender: 'M', armourShape: 11, weaponShape: 60,
  helmetShape: 0, hairType: 1,
};
const LOOKS_CROWD = { cls: 'Wizard', gender: 'M', armourShape: 3, weaponShape: 0, helmetShape: 0, hairType: 2 };

async function refreshSprites(nowMs) {
  const fIdx = Math.floor((nowMs % 500) / 125) % 4;   // stance 4帧
  const mk = async (looks) => {
    const libs = pickLibs(looks);
    const fr = await spriteFrame(libs.body, 0 + (looks.armourShape % 11) * 5000);
    return fr;
  };
  S.sprites.player = await mk(LOOKS);
  const n = Math.min(S.env.crowd, BYSTANDER_SPOTS.length);
  for (let i = 0; i < n; i++) S.sprites.bystanders[i] = await mk(LOOKS_CROWD);
  const da = ANCHOR(DUMMY.x, DUMMY.y);
  S.sprites.dummy = await spriteFrame('Mon-5', drawFrame(MONSTER_ANIMS.standing, fIdx, 2));
  return da;
}

function label(text, x, y) {
  ctx.font = '11px sans-serif';
  ctx.fillStyle = 'rgba(255,255,255,.75)';
  ctx.textAlign = 'center';
  ctx.fillText(text, x, y);
  ctx.textAlign = 'left';
}

function drawScene(nowMs) {
  const pa = ANCHOR(PLAYER.x, PLAYER.y);
  if (S.sprites.player) drawFramed(ctx, S.sprites.player, pa.x, pa.y);
  label('玩家', pa.x, pa.y + 13);
  for (let i = 0; i < Math.min(S.env.crowd, BYSTANDER_SPOTS.length); i++) {
    const b = ANCHOR(BYSTANDER_SPOTS[i].x, BYSTANDER_SPOTS[i].y);
    const spr = S.sprites.bystanders[i];
    if (spr) drawFramed(ctx, spr, b.x, b.y);
  }
  const da = ANCHOR(DUMMY.x, DUMMY.y);
  if (S.sprites.dummy) drawFramed(ctx, S.sprites.dummy, da.x, da.y);
  label('木桩', da.x, da.y + 13);
  if (S.env.tileLight) {
    const t = ANCHOR(TILE_LIGHT_CELL.x, TILE_LIGHT_CELL.y);
    ctx.strokeStyle = 'rgba(120,220,255,.5)';
    ctx.strokeRect(t.x - CELL_W / 2, t.y - CELL_H, CELL_W, CELL_H);
    label('格子光 L=1', t.x, t.y + 4);
  }
  drawFxLightMark(nowMs);
}

// ---------- 地图 ----------
// 进图继承配置 (实验室语义: 切图=读该图 MapInfo.Light/Weather 为面板初值)
function inheritMapEnv() {
  const e = S.env;
  e.setting = S.map.light;
  const sel = document.querySelector(`input[name=setting][value=${S.map.light}]`);
  if (sel) sel.checked = true;
  const wx = S.map.weather;
  e.weather = {
    rain: /Rain/.test(wx), snow: /Snow/.test(wx),
    fog: /Fog/.test(wx), lightning: /Lightning/.test(wx),
  };
  for (const [k, v] of Object.entries(e.weather)) {
    const el = document.getElementById(`wx-${k}`);
    if (el) el.checked = v;
  }
}
async function loadMapTiles(stem) {
  const mf = await (await fetch('/res/data/maps_manifest.json')).json();
  const m = mf.maps?.[stem];
  if (!m) throw new Error(`maps_manifest 无 ${stem}`);
  S.manifest = m;
  S.map.stem = stem; S.map.w = m.w; S.map.h = m.h;
  // 快照现值 (权威, 可能比 webres 生成时新)
  const snap = S.snapshot?.maps?.find?.((x) => x.FileName === stem);
  S.map.light = snap?.Light ?? m.light ?? 'Default';
  S.map.weather = snap?.Weather ?? m.weather ?? 'None';
  S.map.name = m.name_cn || m.name_en || stem;
  inheritMapEnv();
  // 玩家站位: 大图沿用比奇场地坐标, 小图钳到地图中心 (相机不越界)
  if (PLAYER.x >= m.w || PLAYER.y >= m.h) {
    PLAYER.x = Math.floor(m.w / 2); PLAYER.y = Math.floor(m.h / 2);
  }
  // 相机: 以玩家为中心 (并钳回地图内, 小图相机停在边缘)
  const cx = (PLAYER.x + 0.5) * CELL_W, cy = (PLAYER.y + 1) * CELL_H;
  S.camX = Math.max(0, Math.min(Math.round(cx - stage.width / 2), m.w * CELL_W - stage.width));
  S.camY = Math.max(0, Math.min(Math.round(cy - stage.height / 2), m.h * CELL_H - stage.height));
  S.tiles.clear();
  const t0x = Math.floor(S.camX / 512), t1x = Math.floor((S.camX + stage.width) / 512);
  const t0y = Math.floor(S.camY / 512), t1y = Math.floor((S.camY + stage.height) / 512);
  const waits = [];
  for (let ty = t0y; ty <= t1y; ty++) for (let tx = t0x; tx <= t1x; tx++) {
    const img = new Image();
    img.src = `/res/maps/${stem}/${tx}_${ty}.webp`;
    S.tiles.set(`${tx}_${ty}`, img);
    waits.push(new Promise((r) => { img.onload = img.onerror = r; }));
  }
  await Promise.all(waits);
}
function drawMap() {
  ctx.fillStyle = '#101018';
  ctx.fillRect(0, 0, stage.width, stage.height);
  const t0x = Math.floor(S.camX / 512), t1x = Math.floor((S.camX + stage.width) / 512);
  const t0y = Math.floor(S.camY / 512), t1y = Math.floor((S.camY + stage.height) / 512);
  for (let ty = t0y; ty <= t1y; ty++) for (let tx = t0x; tx <= t1x; tx++) {
    const img = S.tiles.get(`${tx}_${ty}`);
    if (img?.complete && img.naturalWidth) ctx.drawImage(img, tx * 512 - S.camX, ty * 512 - S.camY);
    else { ctx.fillStyle = '#16161c'; ctx.fillRect(tx * 512 - S.camX, ty * 512 - S.camY, 512, 512); }
  }
}

// ---------- 读数 ----------
function updateReadout(lightInfo) {
  const el = $('#env-readout');
  const e = S.env;
  const wx = [e.weather.rain && '雨', e.weather.snow && '雪', e.weather.fog && '雾', e.weather.lightning && '雷'].filter(Boolean).join('+') || '无';
  const stateZh = { normal: '正常', dead: '死亡红染', abyss: '深渊黑视' }[e.state];
  el.textContent =
    `${S.map.name} (${S.map.stem})  Light=${S.map.light}  Weather=${S.map.weather}\n` +
    `setting=${e.setting} dayTime=${e.dayTime.toFixed(2)}${e.strict ? ' [原版严格]' : ''} → ambient=${lightInfo.ambient.toFixed(3)}\n` +
    `天气=${wx} 强度${e.intensity.toFixed(1)}× 粒子=${weather.parts.length}\n` +
    `火把=${e.torch > 0 ? `L${e.torch} r=${objectLightRadius(e.torch).toFixed(1)}` : '无'}  路人微光×${e.crowd}  ` +
    `特效光=${e.fxLight ? `r=${effectLightRadius(10).toFixed(1)}` : '✗'}  格子光=${e.tileLight ? `r=${tileLightRadius(1).toFixed(1)}` : '✗'}\n` +
    `特殊态=${stateZh}  叠加: 地图→对象→天气(Z850)→光照(Z900)`;
  $('#env-ambient-read').textContent = `ambient=${lightInfo.ambient.toFixed(3)} ( ${(lightInfo.ambient * 255) | 0}/255 )`;
  $('#wx-count').textContent = `${weather.parts.length} 粒子`;
}

// ---------- 主循环 ----------
let lastTs = 0;
function tick(ts) {
  const dt = Math.min(0.1, (ts - lastTs) / 1000 || 0);
  lastTs = ts;
  weather.update(dt, stage.width);
  weather.setWeather(S.env.weather, S.env.intensity);   // 强度变化即时生效
  refreshSprites(ts).catch(() => {});
  drawMap();
  drawScene(ts);
  weather.draw(ctx);          // Z850: 天气在光照之下 → 粒子也被暗化/红染
  const info = drawLightLayer();  // Z900
  if (S.env.state === 'abyss') drawAbyssFx(ts);   // 原版特效画入光照层=黑暗可见
  updateReadout(info);
  S.lastLight = info;
  requestAnimationFrame(tick);
}

// ---------- 面板绑定 ----------
function bindPanel(snapshot) {
  const e = S.env;
  const setTorchOptions = () => {
    const sel = $('#lt-torch');
    sel.innerHTML = '<option value="0">无（裸视野）</option>' +
      (snapshot.lightItems || []).map((t) =>
        `<option value="${t.Light}">${t.Name} (L${t.Light})</option>`).join('');
    sel.value = '0';
  };
  setTorchOptions();

  document.querySelectorAll('input[name=setting]').forEach((r) =>
    r.addEventListener('change', () => { e.setting = r.value; hintSetting(); }));
  $('#env-daytime').addEventListener('input', (ev) => {
    e.dayTime = parseFloat(ev.target.value);
    $('#env-daytime-v').textContent = e.dayTime.toFixed(2);
  });
  $('#env-strict').addEventListener('change', (ev) => { e.strict = ev.target.checked; hintSetting(); });

  for (const k of ['rain', 'snow', 'fog', 'lightning']) {
    $(`#wx-${k}`).addEventListener('change', (ev) => { e.weather[k] = ev.target.checked; });
  }
  $('#wx-intensity').addEventListener('input', (ev) => {
    e.intensity = parseFloat(ev.target.value);
    $('#wx-intensity-v').textContent = e.intensity.toFixed(1) + '×';
  });

  $('#lt-torch').addEventListener('change', (ev) => { e.torch = parseInt(ev.target.value, 10) || 0; });
  $('#lt-crowd').addEventListener('input', (ev) => {
    e.crowd = parseInt(ev.target.value, 10);
    $('#lt-crowd-v').textContent = String(e.crowd);
  });
  $('#lt-fx').addEventListener('change', (ev) => { e.fxLight = ev.target.checked; });
  $('#lt-tile').addEventListener('change', (ev) => { e.tileLight = ev.target.checked; });

  document.querySelectorAll('input[name=pstate]').forEach((r) =>
    r.addEventListener('change', () => { e.state = r.value; }));

  // 地图下拉
  const mapSel = $('#env-map');
  const maps = (snapshot.maps || []).slice().sort((a, b) =>
    (a.Description || a.FileName).localeCompare(b.Description || b.FileName, 'zh'));
  mapSel.innerHTML = maps.map((m) =>
    `<option value="${m.FileName}">${m.Description || m.FileName} · ${m.FileName}</option>`).join('');
  mapSel.value = S.map.stem;
  mapSel.addEventListener('change', async () => {
    const stem = mapSel.value;
    try {
      await loadMapTiles(stem);
      $('#env-mapinfo').textContent = `${S.map.name} · ${S.map.light}/${S.map.weather}`;
      inheritMapEnv();
      hintSetting();
    } catch (err) {
      $('#env-mapinfo').textContent = `地图加载失败: ${err.message}`;
    }
  });

  hintSetting();
}
function hintSetting() {
  const e = S.env;
  const a = ambientFor(e.setting, e.dayTime, e.strict);
  const notes = {
    Default: e.strict
      ? '原版 Default=255×DayTime（byte 截断）；此处严格模式按下限 15/255 兜底'
      : 'Godot Default=max(0.25, dayTime)（柔和月夜下限）',
    Night: e.strict ? '原版严格 15/255≈5.9% 全黑' : 'Godot 0.25=25% 柔和月夜（刻意偏差）',
    Twilight: '100/255≈39.2%（两端一致）',
    Light: '1.0 全亮（两端一致，光照层不渲染）',
  };
  $('#env-setting-hint').textContent = `${notes[e.setting]} → 当前 ${(a * 255) | 0}/255`;
}

// ---------- P3: 应用到地图 (dbeditor 管线, 绝不直写 .db) ----------
const DBEDITOR = 'http://127.0.0.1:8810';
function bindApply() {
  $('#ap-preview').addEventListener('click', async () => {
    const stem = S.map.stem;
    const snapRow = S.snapshot.maps.find((m) => m.FileName === stem);
    if (!snapRow) { $('#ap-diff').textContent = `快照中无 ${stem}`; return; }
    const wx = $('#ap-weather').value, lt = $('#ap-light').value;
    const lines = [`MapInfo #${snapRow.Index} (${snapRow.Description || stem} / ${stem})`,
      `  Weather: ${snapRow.Weather} → ${wx}${snapRow.Weather === wx ? '  (无变化)' : ''}`];
    if (lt) lines.push(`  Light:   ${snapRow.Light} → ${lt}${snapRow.Light === lt ? '  (无变化)' : ''}`);
    lines.push('', `面板当前预览已按 ${wx} 生效（本地渲染）。`);
    lines.push('「写入 workspace + 同步」= PUT dbeditor /api/row/MapInfo → POST /api/sync（停服校验/备份/round-trip）。');
    $('#ap-diff').textContent = lines.join('\n');
    $('#ap-exec').disabled = false;
  });
  $('#ap-exec').addEventListener('click', async () => {
    const btn = $('#ap-exec');
    btn.disabled = true; btn.textContent = '同步中…';
    try {
      const stem = S.map.stem;
      const row = S.snapshot.maps.find((m) => m.FileName === stem);
      const r0 = await fetch(`${DBEDITOR}/api/row/MapInfo/${row.Index}`);
      if (!r0.ok) throw new Error(`读取当前行失败 HTTP ${r0.status}`);
      const { row: full } = await r0.json();   // dbeditor 返回 {row, subs, meta}
      const body = { ...full };
      for (const k of Object.keys(body)) if (k.startsWith('__')) delete body[k];  // 剔除 __zh 等注入显示字段
      body.Weather = $('#ap-weather').value;
      const lt = $('#ap-light').value;
      if (lt) body.Light = lt;
      const r1 = await fetch(`${DBEDITOR}/api/row/MapInfo/${row.Index}`, {
        method: 'PUT', headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ row: body }),
      });
      if (!r1.ok) throw new Error(`写 workspace 失败: ${(await r1.text()).slice(0, 300)}`);
      const r2 = await fetch(`${DBEDITOR}/api/sync`, { method: 'POST' });
      const sync = await r2.json();
      $('#ap-diff').textContent =
        `✅ workspace 已提交 (dbeditor git 可回滚)\n` +
        `sync ${sync.ok ? '成功' : '失败'}${sync.skipped ? `（${sync.skipped}）` : ''}\n` +
        (sync.report || sync.stdout || sync.error || '').slice(-1500);
    } catch (err) {
      $('#ap-diff').textContent = `❌ ${err.message}\n（dbeditor 需在 :8810 运行；服务端运行中会被 409 拒绝——先停服）`;
    } finally {
      btn.textContent = '写入 workspace + 同步'; btn.disabled = false;
    }
  });
}

// ---------- 启动 ----------
async function main() {

  S.snapshot = await fetch('/static/assets/env-snapshot.json?v=1').then((r) => r.json());
  D().appearance = await fetch('/res/data/appearance.json').then((r) => r.json());
  await weather.loadAssets();
  await loadMapTiles('0');
  await preloadAbyssFx();
  bindPanel(S.snapshot);
  bindApply();
  $('#env-mapinfo').textContent = `${S.map.name} · ${S.map.light}/${S.map.weather}`;
  requestAnimationFrame(tick);
}

// ---------- 验收钩子 (CDP / batch 截图用) ----------
window.__ENV = {
  S,
  ambientFor, objectLightRadius, effectLightRadius, tileLightRadius, abyssGlowRadius,
  weather,
  set(patch) {   // 编程设参, 立即生效: {setting, dayTime, strict, weather:{...}, intensity, torch, crowd, fxLight, tileLight, state, map}
    Object.assign(S.env, patch);
    if (patch.map) return loadMapTiles(patch.map);
    return Promise.resolve();
  },
  stats() {
    const li = S.lastLight || {};
    return {
      ambient: li.ambient ?? ambientFor(S.env.setting, S.env.dayTime, S.env.strict),
      rendered: !!li, tinted: !!li.tinted,
      state: S.env.state, setting: S.env.setting, dayTime: S.env.dayTime, strict: S.env.strict,
      weather: { ...S.env.weather }, intensity: S.env.intensity,
      torch: S.env.torch, crowd: S.env.crowd,
      particles: weather.parts.length,
      byKind: { rain: weather.countKind(509), splash: weather.countKind(510) + weather.countKind(511) + weather.countKind(512) + weather.countKind(513) + weather.countKind(514), snow: weather.countKind(500), fog: weather.countKind(550), bolt: weather.countKind(540) },
      map: { ...S.map },
    };
  },
  ready: main().catch((e) => {
    document.body.innerHTML = `<pre style="color:#f88;padding:20px">Light Lab 启动失败: ${e}\n${e.stack}</pre>`;
  }),
};
