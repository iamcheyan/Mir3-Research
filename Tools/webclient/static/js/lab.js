// lab.js — Magic Lab 技能特效实验室引擎
//
// 事实源链（全部来自仓库，无手抄表）:
//   /lab/table          magic-effect-table.json   原版 MapObject.cs 两段 Spell switch 提取物
//   /lab/frame-formulas frame-formulas.json       帧公式单一数据源 (E3 生成, webport 同源)
//   /res/data/magics.json                        MagicInfo 174 技能 + MIcon 图标 + 中文名
//
// 引擎语义对齐原版:
//   MirEffect.Process      DrawFrame = FrameIndex + StartIndex + Direction*Skip
//   MirProjectile.Process  直线飞行 duration=Distance(px) ms; Direction16 量化 22.5°
//                          (Direction16 由等距校正坐标 y/32*48 计算, 原版 Functions.cs:593)
//   PlayerObject.Spell     animation = GetMagicAnimation(type) (frame-formulas magicDispatch)
//   spellRelease           前 min(3,count-1) 帧延迟和 (PlayerRenderer.cs 语义)
import { loadSprite, frameMeta } from './res.js';
import { spriteFrame, drawFramed } from './sprites.js';
import { pickLibs, D, CELL_W, CELL_H, MONSTER_ANIMS, drawFrame } from './data.js';

const $ = (s) => document.querySelector(s);
const stage = $('#lab-stage');
const ctx = stage.getContext('2d');
ctx.imageSmoothingEnabled = false;

// ---------- 常量 ----------
const DIRS8 = [
  [0, -1], [1, -1], [1, 0], [1, 1], [0, 1], [-1, 1], [-1, 0], [-1, -1],
]; // MirDirection Up..UpLeft (格向量近似, Y 等距)
const CLASS_ORDER = ['Warrior', 'Wizard', 'Taoist', 'Assassin', 'Archer'];
const CLASS_ZH = { Warrior: '战士', Wizard: '法师', Taoist: '道士', Assassin: '刺客', Archer: '弓手', Universal: '通用' };

// 场景布局 (地图格坐标)
const CASTER = { x: 629, y: 626 };
const DUMMIES = [ // 主木桩 + 环绕, 攻击目标候选 (从近到远)
  { x: 634, y: 629 }, { x: 636, y: 626 }, { x: 635, y: 632 },
  { x: 638, y: 630 }, { x: 633, y: 634 },
];
const MAP_STEM = '0'; // 比奇

// ---------- 全局状态 ----------
const S = {
  magics: [], table: null, ff: null,
  timeScale: 1, paused: false, labT: 0,
  fx: [],           // 活跃特效实例
  events: [],       // 事件日志 [{t, text}]
  casterAnims: [],  // 施法动画状态
  trace: false, loop: true,
  selected: null, lastPlay: null,
  targetCount: 3,
  camX: 0, camY: 0, // 视口左上角的世界像素
  tiles: new Map(), // 瓦片缓存
  manifest: null, dummySprites: [], dummyFrames: [], casterSprites: {},
};
const CELL_ANCHOR = (gx, gy) => ({ x: gx * CELL_W + CELL_W / 2 - S.camX, y: (gy + 1) * CELL_H - S.camY });

// ---------- 工具 ----------
function direction16(sx, sy, dx, dy) {
  // 原版 Functions.Direction16 (Functions.cs:593): 等距校正 + 余弦定理角度 + 22.5° 量化
  const y0 = Math.round(sy / 32) * 48, y1 = Math.round(dy / 32) * 48;
  const c = { x: sx, y: y0 }, b = { x: dx, y: y1 };
  const bc = Math.hypot(b.x - c.x, b.y - c.y);
  if (bc === 0) return 4; // Down
  const a = { x: c.x, y: 0 };
  const bb = { x: b.x, y: b.y + bc };
  const ab = Math.hypot(bb.x - a.x, bb.y - a.y);
  const cos = (bc * bc + bc * bc - ab * ab) / (2 * bc * bc);
  let ang = Math.acos(Math.max(-1, Math.min(1, cos))) * 180 / Math.PI;
  if (dx < c.x) ang = 360 - ang;
  ang += 11.25;
  if (ang > 360) ang -= 360;
  return Math.floor(ang / 22.5) % 16;
}
function dir8To(from, to) {
  let best = 0, bd = 1e9;
  DIRS8.forEach((d, i) => {
    const px = d[0], py = d[1] * 32 / 48; // 屏幕方向感 (Y 压扁)
    const dd = (px * 48 - (to.x - from.x)) ** 2 + (py * 48 - (to.y - from.y)) ** 2;
    if (dd < bd) { bd = dd; best = i; }
  });
  return best;
}
function log(t, text, cls = '') {
  S.events.push({ t, text, cls });
  if (S.events.length > 40) S.events.shift();
}

// ---------- 帧公式 (frame-formulas) ----------
const FF = {
  players: null, magicDispatch: null, armourShift: null,
  animOf(magicKey) {
    const g = this.magicDispatch?.groups || [];
    for (const grp of g) if (grp.magics?.includes(magicKey)) return grp.anim;
    return this.magicDispatch?.default || 'combat1';
  },
  frame(name) { return this.players?.[name] || null; },
};
function frameDelays(f) { // Frame → [ms per frame]
  const out = [];
  for (let i = 0; i < f.count; i++) out.push(f.delays?.[i] ?? f.ms);
  return out;
}
function spellReleaseDelayMs(animName) {
  const f = FF.frame(animName);
  if (!f) return 400;
  const d = frameDelays(f);
  const n = Math.min(3, Math.max(1, f.count - 1));
  let s = 0;
  for (let i = 0; i < n; i++) s += d[i];
  return s;
}

// ---------- 纸娃娃 ----------
const LOOKS = {
  Warrior:  { cls: 'Warrior', gender: 'M', armourShape: 21, weaponShape: 63, helmetShape: 0, hairType: 1 },
  Wizard:   { cls: 'Wizard', gender: 'M', armourShape: 24, weaponShape: 111, helmetShape: 0, hairType: 2 },
  Taoist:   { cls: 'Taoist', gender: 'M', armourShape: 22, weaponShape: 111, helmetShape: 0, hairType: 3 },
  Assassin: { cls: 'Assassin', gender: 'F', armourShape: 24, weaponShape: 130, helmetShape: 0, hairType: 1 },
  Archer:   { cls: 'Warrior', gender: 'F', armourShape: 26, weaponShape: 63, helmetShape: 0, hairType: 2 },
};
async function paperdoll(look, animName, frameIdx, dir) {
  // 与 data.js playerFrames 同公式, 但动画表来自 frame-formulas (delays 逐帧)
  const f = FF.frame(animName) || FF.frame('standing');
  const base = frameIdx + f.start + dir * (f.offset ?? 10);
  const isSin = look.cls === 'Assassin';
  const off = isSin ? 3000 : 5000;
  let shift = 0;
  if (isSin) shift = FF.armourShift?.[animName] ?? 0;
  const libs = pickLibs(look);
  const ws = look.weaponShape >= 1000 ? look.weaponShape - 1000 : look.weaponShape;
  const jobs = [
    frameSprite(libs.body, base + (look.armourShape % 11) * off + shift),
    look.hairType > 0 ? frameSprite(libs.hair, base + (look.hairType - 1) * 5000) : null,
    look.weaponShape >= 0 ? frameSprite(libs.weapon, base + (ws % 10) * 5000) : null,
  ];
  const [body, hair, weapon] = await Promise.all(jobs);
  return { body, head: hair, weapon, dir, backDirs: [0, 5, 6, 7], frontDirs: [1, 2, 3, 4] };
}
function drawPaperdoll(spr, sx, sy) {
  if (!spr) return;
  if (spr.weapon && spr.backDirs.includes(spr.dir)) drawFramed(ctx, spr.weapon, sx, sy);
  if (spr.body) drawFramed(ctx, spr.body, sx, sy);
  if (spr.head) drawFramed(ctx, spr.head, sx, sy);
  if (spr.weapon && spr.frontDirs.includes(spr.dir)) drawFramed(ctx, spr.weapon, sx, sy);
}

// ---------- 特效引擎 ----------
// inst: {lib,frame,count,delay,skip,dir,dir16,has16,colour,
//        attach:'caster'|'target:i'|'point'|{x,y}, t0, kind, label,
//        flight:{from,to,dur}|null, onDone:[]}
function spawnFx(def) { S.fx.push({ t0: S.labT, ...def }); }

function fxFrame(inst, t) {
  const idx = Math.floor(t / inst.delay);
  if (idx >= inst.count) return null;
  const dirOff = inst.has16 ? inst.dir16 * (inst.skip ?? 10) : inst.dir * (inst.skip ?? 10);
  return { idx, drawFrame: idx + inst.frame + dirOff };
}
function fxPos(inst, t) {
  if (inst.flight) {
    const p = Math.min(1, t / inst.flight.dur);
    const wx = inst.flight.fromX + (inst.flight.toX - inst.flight.fromX) * p;
    const wy = inst.flight.fromY + (inst.flight.toY - inst.flight.fromY) * p;
    return { wx, wy };
  }
  let gx, gy;
  if (inst.attach === 'caster') ({ x: gx, y: gy } = CASTER);
  else if (typeof inst.attach === 'number') { const d = DUMMIES[inst.attach]; ({ x: gx, y: gy } = d); }
  else ({ x: gx, y: gy } = inst.point);
  return { wx: gx * CELL_W + CELL_W / 2, wy: (gy + 1) * CELL_H };
}

function updateFx(dt) {
  for (let i = S.fx.length - 1; i >= 0; i--) {
    const f = S.fx[i];
    const t = S.labT - f.t0;
    if (t < 0) continue;
    if (f.flight && t >= f.flight.dur) {
      for (const cb of f.onDone || []) cb();
      S.fx.splice(i, 1);
      continue;
    }
    if (!f.flight && t >= f.count * f.delay) {
      for (const cb of f.onDone || []) cb();
      S.fx.splice(i, 1);
    }
  }
}
const _frameCache = new Map();
async function frameSprite(lib, frame) {
  const key = `${lib}:${frame}`;
  if (_frameCache.has(key)) return _frameCache.get(key);
  const p = spriteFrame(lib, frame);
  _frameCache.set(key, p);
  p.then((v) => { if (v == null) _frameCache.delete(key); }).catch(() => { _frameCache.delete(key); });  // 失败/缺帧不缓存, 下次重试 (截图确定性)
  return p;
}
function drawFx() {
  for (const f of S.fx) {
    const t = S.labT - f.t0;
    if (t < 0) continue;
    const pos = fxPos(f, t);
    const fr = f.flight ? { idx: Math.min(f.count - 1, Math.floor(t / f.delay)), drawFrame: null } : fxFrame(f, t);
    let drawFrameNo = f.flight
      ? fr.idx + f.frame + f.dir16 * (f.skip ?? 10)
      : fr?.drawFrame;
    if (drawFrameNo == null) continue;
    frameSprite(f.lib, drawFrameNo).then((s) => { f._last = s ?? false; f._lastFrameNo = drawFrameNo; });
    const s = f._last;  // undefined=未就绪, false=已确认缺帧(原版空帧), 对象=可用
    if (s) {
      const sx = pos.wx - S.camX, sy = pos.wy - S.camY;
      ctx.globalAlpha = 0.92;
      drawFramed(ctx, s, sx, sy);
      ctx.globalAlpha = 1;
    }
  }
}

// ---------- 施法编排 ----------
function effectsOf(entry, seg) { return entry?.[seg]?.effects || []; }
function playSkill(magic) {
  const key = magic.key;
  const entry = S.table[key];
  S.lastPlay = magic;
  const anim = FF.animOf(key);
  const relDelay = spellReleaseDelayMs(anim);
  const cls = magic.cls === 'Universal' ? 'Wizard' : magic.cls;
  const look = LOOKS[cls] || LOOKS.Wizard;
  const dir = dir8To(CASTER, DUMMIES[0]);
  S.casterAnims = [{ anim, frameIdx: 0, t: 0, delays: frameDelays(FF.frame(anim) || { count: 5, ms: 100 }), look, dir }];
  S.fx = [];
  S.events = [];
  const targets = DUMMIES.slice(0, S.targetCount);
  S.cast0 = S.labT;

  const casterPx = { x: CASTER.x * CELL_W + CELL_W / 2, y: (CASTER.y + 1) * CELL_H };
  const targetPx = (i) => ({ x: DUMMIES[i].x * CELL_W + CELL_W / 2, y: (DUMMIES[i].y + 1) * CELL_H });

  // start 段 (t=0)
  for (const e of effectsOf(entry, 'start')) spawnFromEffect(e, { attach: 'caster', at: 0, dir });

  // release 段 (t=relDelay)
  for (const e of effectsOf(entry, 'release')) {
    const at = relDelay;
    if (e.kind === 'projectile') {
      const tg = e.target === 'point' ? null : 0; // point 弹道飞向主木桩格 (MagicLocations 单点)
      const ti = tg ?? 0;
      const to = targetPx(ti);
      const d16 = direction16(casterPx.x, casterPx.y, to.x, to.y);
      const dur = Math.max(1, Math.hypot(to.x - casterPx.x, to.y - casterPx.y));
      const skip = e.extra?.Skip ?? 10;
      const has16 = e.extra?.Has16Directions !== false;
      spawnFx({
        lib: e.lib, frame: e.frame ?? e.directionFrames?.[0], count: e.count, delay: e.delayMs || 100,
        skip, dir: 0, dir16: has16 ? d16 : Math.floor(d16 / 2), has16: false, // DrawFrame 已含 dir16
        attach: null, point: CASTER,
        flight: { fromX: casterPx.x, fromY: casterPx.y, toX: to.x, toY: to.y, dur },
        t0: S.labT + at, kind: 'projectile', label: `弹道 ${e.lib}#${e.frame}`,
        onDone: [],
      });
      log(at, `→ 弹道 ${e.lib}#${e.frame}×${e.count} dir16=${d16} ${Math.round(dur)}ms`, 'seg');
    } else if (e.segment === 'aoe') {
      // MagicLocations 语义: 落点地面特效 (实验室取主木桩格)
      // 原版 StartTime = Now + N ms (距离延迟) → 实验室近似 +N
      // E5: 提取器已结构化 (StartDelayMs/DistanceDelayMs), 旧 StartTime 字符串兜底
      let delay0 = e.extra?.StartDelayMs ?? 0;
      if (!delay0) {
        const st = String(e.extra?.StartTime ?? '');
        const stm = st.match(/AddMilliseconds\((\d+)/);
        if (stm) delay0 = +stm[1];
      }
      spawnFromEffect(e, { attach: { point: DUMMIES[0] }, at: at + delay0, dir });
      log(at + delay0, `◉ 地面 ${e.lib}#${e.frame ?? e.frameExpr}×${e.count}`, 'seg');
    } else if (e.segment === 'hitEffect' && !e.ctx?.includes('arrival')) {
      // release 段直接命中特效 (无弹道承载): 目标身上/落点
      const at2 = at;
      for (let i = 0; i < targets.length; i++) {
        spawnFromEffect(e, { attach: e.target === 'point' ? { point: DUMMIES[0] } : i, at: at2, dir });
      }
      log(at, `✦ ${e.lib}#${e.frame}×${e.count} → ${e.target === 'point' ? '落点' : targets.length + '目标'}`, 'seg');
    }
    // arrival 类 (弹道 CompleteAction) 由 projectile onDone 触发, 见下
  }

  // arrival: release 段 ctx 含 arrival 的特效挂在 projectile 到达后
  const arrivals = effectsOf(entry, 'release').filter((e) => e.ctx?.includes('arrival'));
  const endSounds = (S.table[key]?.sound?.end) || [];
  if (arrivals.length || endSounds.length) {
    // 计算最长弹道到达时刻: relDelay + max(dur)
    let maxDur = 0;
    for (const e of effectsOf(entry, 'release')) if (e.kind === 'projectile') {
      const to = targetPx(0);
      maxDur = Math.max(maxDur, Math.hypot(to.x - casterPx.x, to.y - casterPx.y));
    }
    const tHit = relDelay + Math.max(maxDur, 1);
    for (const e of arrivals) {
      for (let i = 0; i < targets.length; i++) {
        spawnFromEffect(e, { attach: i, at: tHit, dir });
      }
      log(tHit, `✸ 命中 ${e.lib}#${e.frame}×${e.count}`, 'seg');
    }
    for (const sname of endSounds) log(tHit, `♪ ${sname}`, 'snd');
  }
  for (const sname of S.table[key]?.sound?.start || []) log(0, `♪ ${sname}`, 'snd');
  for (const sname of S.table[key]?.sound?.travel || []) log(relDelay, `♪ ${sname}`, 'snd');

  const total = 3000;
  if (S.loop) {
    clearTimeout(S._loopTimer);
    S._loopTimer = setTimeout(() => { if (S.loop && S.lastPlay === magic && !S.paused) playSkill(magic); }, total / S.timeScale);
  }
}

function spawnFromEffect(e, { attach, at, dir }) {
  let frame = e.frame ?? e.directionFrames?.[dir] ?? e.directionFrames?.[0];
  if (frame == null && e.frameExpr) {
    // 动态帧表达式: 随机组取首组基址 (如 2450 + Random(5)*10 → 2450)
    const m = String(e.frameExpr).match(/(\d+)/);
    if (m) frame = +m[1];
  }
  if (frame == null) return;
  const skip = e.extra?.Skip ?? 10;
  const useDir = e.extra?.Direction != null ? (typeof e.extra.Direction === 'number' ? e.extra.Direction : dir) : 0;
  spawnFx({
    lib: e.lib, frame, count: e.count, delay: e.delayMs || 100, skip,
    dir: useDir, dir16: 0, has16: false,
    attach: typeof attach === 'object' ? null : attach,
    point: typeof attach === 'object' ? attach.point : undefined,
    t0: S.labT + at, kind: e.segment, label: `${e.lib}#${frame}`,
    onDone: [],
  });
}

// ---------- 场景渲染 ----------
async function loadMapTiles() {
  const mf = await (await fetch('/res/data/maps_manifest.json')).json();
  const m = mf.maps?.find?.((x) => String(x.id ?? x.name_en) === MAP_STEM) || mf[MAP_STEM] || mf.maps?.[0];
  S.manifest = m;
  const cx = (CASTER.x + 0.5) * CELL_W, cy = (CASTER.y + 1) * CELL_H;
  S.camX = Math.round(cx - stage.width / 2);
  S.camY = Math.round(cy - stage.height / 2);
  const t0x = Math.floor(S.camX / 512), t1x = Math.floor((S.camX + stage.width) / 512);
  const t0y = Math.floor(S.camY / 512), t1y = Math.floor((S.camY + stage.height) / 512);
  for (let ty = t0y; ty <= t1y; ty++) for (let tx = t0x; tx <= t1x; tx++) {
    const img = new Image();
    img.src = `/res/maps/${MAP_STEM}/${tx}_${ty}.webp`;
    S.tiles.set(`${tx}_${ty}`, img);
    img.onload = () => { S.tiles.set(`${tx}_${ty}`, img); };
  }
}
function drawMap() {
  ctx.fillStyle = '#101018';
  ctx.fillRect(0, 0, stage.width, stage.height);
  const t0x = Math.floor(S.camX / 512), t1x = Math.floor((S.camX + stage.width) / 512);
  const t0y = Math.floor(S.camY / 512), t1y = Math.floor((S.camY + stage.height) / 512);
  for (let ty = t0y; ty <= t1y; ty++) for (let tx = t0x; tx <= t1x; tx++) {
    const img = S.tiles.get(`${tx}_${ty}`);
    if (img?.complete && img.naturalWidth) {
      ctx.drawImage(img, tx * 512 - S.camX, ty * 512 - S.camY);
    } else {
      ctx.fillStyle = '#16161c';
      ctx.fillRect(tx * 512 - S.camX, ty * 512 - S.camY, 512, 512);
    }
  }
}
function drawScene(dtReal) {
  // 木桩 (站立 4 帧循环, 125ms) — 相位由 labT 派生, freeze 定格后逐字节可复现
  const dFrame = Math.floor((S.labT % 500) / 125) % 4;
  const dummyNo = drawFrame(MONSTER_ANIMS.standing, dFrame, 2);
  for (let i = 0; i < DUMMIES.length; i++) {
    const d = DUMMIES[i];
    const a = CELL_ANCHOR(d.x, d.y);
    frameSprite('Mon-5', dummyNo).then((s) => { S.dummySprites[i] = s ?? false; S.dummyFrames[i] = dummyNo; });
    if (i < S.targetCount) {
      ctx.strokeStyle = 'rgba(255,90,90,.35)';
      ctx.strokeRect(a.x - 24, a.y - 60, 48, 60);
    }
    const s = S.dummySprites[i];
    if (s) drawFramed(ctx, s, a.x, a.y);
  }
  // 施法者 — 动画相位由 (labT - cast0) 派生, 不用真实时间累加器
  const ca = CELL_ANCHOR(CASTER.x, CASTER.y);
  const st = S.casterAnims[0];
  if (st) {
    let t = Math.max(0, S.labT - (S.cast0 ?? S.labT));
    let anim = st.anim, frameIdx = 0;
    const delaysOf = (a) => frameDelays(FF.frame(a) || { count: 4, ms: 200 });
    let delays = delaysOf(anim);
    while (t >= delays[frameIdx]) {
      t -= delays[frameIdx];
      if (frameIdx + 1 < delays.length) frameIdx++;
      else { anim = 'stance'; frameIdx = 0; delays = delaysOf('stance'); }
    }
    const look = st.look;
    const req = JSON.stringify([anim, frameIdx, st.dir, look.cls]);
    S._pdReq = req;
    paperdoll(look, anim, frameIdx, st.dir).then((p) => {
      // 部件 (body/head/weapon) 任何一个瞬时缺失都拒绝结算: 服务器抽帧偶发 5xx 会让
      // null 被当成合法 settle → 截图缺部件 → 跨会话 changed 误报。重试直到全齐。
      const ok = p && p.body && (!p.head || p.head) && (!p.weapon || p.weapon);
      if (S._pdReq === req) {
        S.casterSprites.cur = p;
        if (ok) S._pdGot = req;
      }
    }).catch(() => {});   // 拒绝不缓存, 下一 tick 重试; framesReady 持续等待
  }
  ctx.font = '11px sans-serif';
  ctx.fillStyle = '#9fe0a8';
  ctx.fillText('施法者', ca.x - 18, ca.y + 14);
}
function drawTrace() {
  if (!S.trace || !S.lastPlay) return;
  const entry = S.table[S.lastPlay.key] || {};
  const from = CELL_ANCHOR(CASTER.x, CASTER.y);
  ctx.save();
  for (const e of effectsOf(entry, 'release')) {
    if (e.kind !== 'projectile') continue;
    const to = CELL_ANCHOR(DUMMIES[0].x, DUMMIES[0].y);
    ctx.strokeStyle = 'rgba(120,220,255,.7)';
    ctx.setLineDash([6, 5]);
    ctx.beginPath(); ctx.moveTo(from.x, from.y - 24); ctx.lineTo(to.x, to.y - 24); ctx.stroke();
    ctx.setLineDash([]);
    // 16 方向刻度
    for (let k = 0; k < 16; k++) {
      const ang = k * 22.5 * Math.PI / 180;
      ctx.strokeStyle = k === Math.floor((Math.atan2(to.y - 24 - (from.y - 24), to.x - from.x) * 180 / Math.PI + 360 + 11.25) / 22.5) % 16 ? 'rgba(120,220,255,.25)' : 'rgba(255,220,90,.9)';
      ctx.beginPath();
      ctx.moveTo(from.x + Math.cos(ang) * 46, from.y - 24 + Math.sin(ang) * 30);
      ctx.lineTo(from.x + Math.cos(ang) * 58, from.y - 24 + Math.sin(ang) * 38);
      ctx.stroke();
    }
  }
  ctx.restore();
}
function drawEvents() {
  const el = $('#lab-events');
  el.innerHTML = S.events.slice(-8).map((e) =>
    `<div><span class="t">${String(Math.round(e.t)).padStart(4)}ms</span> <span class="${e.cls}">${e.text}</span></div>`).join('');
}

// ---------- 主循环 ----------
let lastTs = 0;
function tick(ts) {
  const dtReal = Math.min(0.1, (ts - lastTs) / 1000 || 0);
  lastTs = ts;
  if (!S.paused) {
    const dt = Math.round(dtReal * 1000 * S.timeScale);  // 定点化: 浮点累加会让 t 骑在 idx 边界 ±ε 抖动
    if (dt > 0) { S.labT += dt; updateFx(dt); }
  }
  drawMap();
  drawScene(S.paused ? 0 : dtReal * S.timeScale);
  drawTrace();
  drawFx();
  drawEvents();
  requestAnimationFrame(tick);
}


// ---------- 启动 ----------
async function main() {
  const nc = `_=${Date.now()}`; // 事实源会再生成, 禁用中间层缓存
  const [magics, table, ff, minfo] = await Promise.all([
    fetch(`/res/data/magics.json?${nc}`).then((r) => r.json()),
    fetch(`/lab/table?${nc}`).then((r) => r.json()),
    fetch(`/lab/frame-formulas?${nc}`).then((r) => r.json()),
    fetch(`/lab/magicinfo?${nc}`).then((r) => r.json()).catch(() => null),
  ]);
  S.magics = magics;
  // data.js pickLibs 依赖 Data.appearance (模块私有, 经 D() 注入)
  D().appearance = await fetch('/res/data/appearance.json').then((r) => r.json());
  // MagicInfo 全字段 join (NeedLevel/Cost/Delay/描述); Magic 列为无空格标识
  const rows = minfo?.rows || [];
  const byKey = new Map(rows.map((r) => [r.Magic || r._Identity, r]));
  for (const m of S.magics) {
    const r = byKey.get(m.key);
    if (r) Object.assign(m, {
      need1: r.NeedLevel1, cost: r.BaseCost, delay: r.Delay,
      desc: r.Description, school: r.School,
    });
  }
  S.table = table;
  FF.players = ff.frameSets?.players || {};
  FF.magicDispatch = ff.magicDispatch || {};
  FF.armourShift = ff.armourShift?.Assassin || ff.armourShift || {};
  S.monsters = await fetch('/res/data/monsters.json').then((r) => r.json()).catch(() => []);
  await loadMapTiles().catch((e) => console.warn('map tiles:', e));
  buildList();
  bindControls();
  requestAnimationFrame(tick);
}

// ---------- 技能列表 ----------
function badge(entry) {
  const has = (x) => x ? '<span class="b on">有</span>' : '<span class="b off">无</span>';
  const st = effectsOf(entry, 'start').length, rel = effectsOf(entry, 'release').length;
  if (!entry) return '<span class="b off">原版无特效</span>';
  return `<span class="b">${st}起</span><span class="b">${rel}放</span>`;
}
function buildList() {
  const q = $('#lab-search').value.trim().toLowerCase();
  const box = $('#lab-groups');
  box.innerHTML = '';
  const groups = new Map();
  for (const m of S.magics) {
    const g = m.cls || 'Universal';
    if (!groups.has(g)) groups.set(g, []);
    groups.get(g).push(m);
  }
  const order = CLASS_ORDER.filter((c) => groups.has(c)).concat([...groups.keys()].filter((c) => !CLASS_ORDER.includes(c)));
  for (const g of order) {
    const h = document.createElement('div');
    h.className = 'lab-group';
    h.innerHTML = `<h3>${CLASS_ZH[g] || g} · ${groups.get(g).length}</h3>`;
    for (const m of groups.get(g)) {
      if (q && !(`${m.zh}|${m.name}|${m.key}`.toLowerCase().includes(q))) continue;
      const row = document.createElement('div');
      row.className = 'lab-skill';
      row.dataset.key = m.key;
      const entry = S.table[m.key];
      row.innerHTML = `
        <img loading="lazy" src="/res/sprites/MIcon/${m.icon || 0}.webp" onerror="this.style.visibility='hidden'">
        <div class="nm"><div class="zh">${m.zh || m.name}</div><div class="en">${m.key}</div></div>
        <div class="badges">${badge(entry)}</div>`;
      row.onclick = () => {
        document.querySelectorAll('.lab-skill.sel').forEach((x) => x.classList.remove('sel'));
        row.classList.add('sel');
        S.selected = m;
        showInfo(m, entry);
        playSkill(m);
      };
      h.appendChild(row);
    }
    box.appendChild(h);
  }
  $('#lab-stat').textContent = `${S.magics.length} 技能 / 表覆盖 ${S.magics.filter((m) => S.table[m.key]).length}`;
}
function showInfo(m, entry) {
  const info = $('#lab-info');
  if (!entry) {
    info.innerHTML = `<h4>${m.zh} (${m.key})</h4><div class="dim">原版 Spell switch 无此 case（被动/纯服务端/Attack 语义）</div>`;
    return;
  }
  const rows = [];
  const fmt = (e) => `${e.lib}#${e.frame ?? e.frameExpr ?? 'dir'} ×${e.count} @${e.delayMs}ms`;
  const st = effectsOf(entry, 'start'), rel = effectsOf(entry, 'release');
  rows.push(['castAnim', entry.castAnim || '—']);
  if (st.length) rows.push(['起手 start', st.map(fmt).join('<br>')]);
  const proj = rel.filter((e) => e.kind === 'projectile');
  const hit = rel.filter((e) => e.segment === 'hitEffect');
  const aoe = rel.filter((e) => e.segment === 'aoe');
  if (proj.length) rows.push(['弹道 projectile', proj.map(fmt).join('<br>')]);
  if (hit.length) rows.push(['命中 hit', hit.map(fmt).join('<br>')]);
  if (aoe.length) rows.push(['范围 aoe', aoe.map(fmt).join('<br>')]);
  const snd = Object.entries(entry.sound || {}).map(([k, v]) => `${k}: ${v.join(',')}`);
  if (snd.length) rows.push(['音效', snd.join('<br>')]);
  rows.push(['MagicInfo', `Lv${m.need1 ?? ''} Cost${m.cost ?? '?'} ${m.desc?.slice(0, 40) || ''}`]);
  info.innerHTML = `<h4>${m.zh} (${m.key})</h4><table>${rows.map((r) => `<tr><td class="k">${r[0]}</td><td>${r[1]}</td></tr>`).join('')}</table>`;
}

// ---------- 控件 ----------
function bindControls() {
  $('#lab-speed').onchange = (e) => { S.timeScale = +e.target.value; };
  $('#lab-pause').onclick = () => {
    S.paused = !S.paused;
    $('#lab-pause').textContent = S.paused ? '继续' : '暂停';
    $('#lab-step').disabled = !S.paused;
    clearTimeout(S._loopTimer);
  };
  $('#lab-step').onclick = () => {
    const dt = 100; // 一帧 @100ms
    S.labT += dt;
    updateFx(dt);
  };
  $('#lab-trace').onchange = (e) => { S.trace = e.target.checked; };
  $('#lab-loop').onchange = (e) => { S.loop = e.target.checked; };
  $('#lab-clear').onclick = () => { S.fx = []; S.events = []; S.casterAnims = []; };
  $('#lab-search').oninput = buildList;
}

// ---------- 启动 ----------
main().catch((e) => {
  document.body.innerHTML = `<pre style="color:#f88;padding:20px">Magic Lab 启动失败: ${e}\n${e.stack}</pre>`;
});

// ---------- 验收钩子 (batch_run.mjs / CDP 使用) ----------
window.__LAB = {
  S, playSkill,
  magicByKey: (k) => S.magics.find((m) => m.key === k),
  play(key) {
    const m = this.magicByKey(key);
    if (!m) return false;
    // labT 对齐 500ms 边界: 木桩等一切 labT 派生相位在 freeze 时刻绝对确定
    this._cast0 = Math.ceil(S.labT / 500) * 500;
    S.labT = this._cast0;
    S.paused = false;
    S.fx = []; S.events = [];
    showInfo(m, S.table[m.key]);   // 与 DOM 点击行为一致
    playSkill(m);
    return true;
  },
  freezeAt(offsetMs) {  // 暂停并把 lab-time 定位到施法开始后 offsetMs (确定性截图)
    S.paused = true;
    S.labT = (this._cast0 ?? S.labT) + offsetMs;
    updateFx(0);
  },
  framesReady() {  // 当前 labT 下特效/纸娃娃/木桩的当帧是否已解码 (排除异步竞态)
    for (const f of S.fx) {
      const t = S.labT - f.t0;
      if (t < 0) continue;
      let no;
      if (f.flight) {
        const idx = Math.min(f.count - 1, Math.floor(t / f.delay));
        no = idx + f.frame + f.dir16 * (f.skip ?? 10);
      } else {
        const idx = Math.floor(t / f.delay);
        if (idx >= f.count) continue;
        no = idx + f.frame + f.dir * (f.skip ?? 10);
      }
      if (f._last === undefined || f._lastFrameNo !== no) return false;
    }
    const dFrame = Math.floor((S.labT % 500) / 125) % 4;
    const dummyNo = drawFrame(MONSTER_ANIMS.standing, dFrame, 2);
    for (let i = 0; i < DUMMIES.length; i++) {
      // 帧号已结算且 sprite 真值: 冷启动抽帧失败 (null→false) 不算就绪, 重试直到画上
      if (S.dummyFrames[i] !== dummyNo || !S.dummySprites[i]) return false;
    }
    return true;
  },
  resumeRealtime() { S.paused = false; },
};
