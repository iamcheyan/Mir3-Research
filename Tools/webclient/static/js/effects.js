// effects.js — E5/C4 特效引擎公共模块 (lab 与 roam 共用, 消灭第三份手抄)
//
// 数据源 (事实源链, 全部来自仓库无手抄):
//   /lab/table          ClientData/magic-effects.json 投影 — original 段为运行时语义
//                      (kind: effect|projectile, ctx: [point|target|arrival], segment:
//                       castEffect|projectile|hitEffect|aoe, extra: Blend/Opacity/DrawType/
//                       StartDelayMs/DistanceDelayMs/Skip/DirectionSemantic)
//   /lab/frame-formulas ClientData/frame-formulas.json — 施法动作分派 + 逐帧延迟
//
// 编排语义 (对齐原版 MapObject.Spell / MirEffect / MirProjectile):
//   t=0          entry.start.effects → 施法者
//   t=relDelay   entry.release.effects → projectile 直线 (dur=Distance px),
//                aoe → 落点地面 (StartDelayMs + 距离×DistanceDelayMs),
//                hitEffect → 目标/落点, ctx 含 arrival → 弹道到达后
// 渲染保真:
//   Blend=true → 'lighter' 叠加; Opacity; DrawType Floor/Object/Final 分层;
//   Colour(Fire/Ice/...) 离屏 multiply 色染; startLight/endLight 忽略 (canvas 无光照)
//   DrawFrame = FrameIndex + Frame + Direction*Skip (MirEffect.Process)

import { CELL_W, CELL_H } from './data.js';
import { spriteFrame } from './sprites.js';

export const DIRS8 = [
  [0, -1], [1, -1], [1, 0], [1, 1], [0, 1], [-1, 1], [-1, 0], [-1, -1],
];

// ---------- 帧公式 ----------
export function makeFF(ffJson) {
  return {
    players: ffJson.frameSets?.players || null,
    magicDispatch: ffJson.magicDispatch || null,
    armourShift: ffJson.armourShift || null,
    animOf(magicKey) {
      for (const g of this.magicDispatch?.groups || [])
        if (g.magics?.includes(magicKey)) return g.anim;
      return this.magicDispatch?.default || 'combat2';
    },
    frame(name) { return this.players?.[name] || null; },
  };
}
export function frameDelays(f) {
  const out = [];
  for (let i = 0; i < f.count; i++) out.push(f.delays?.[i] ?? f.ms);
  return out;
}
export function spellReleaseDelayMs(ff, animName) {
  const f = ff.frame(animName);
  if (!f) return 400;
  const d = frameDelays(f);
  const n = Math.min(3, Math.max(1, f.count - 1));
  let s = 0;
  for (let i = 0; i < n; i++) s += d[i];
  return s;
}
export function direction16(sx, sy, dx, dy) {
  const c = { x: sx, y: sy }, b = { x: dx, y: dy };
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
export function dir8To(from, to) {
  let best = 0, bd = 1e9;
  DIRS8.forEach((d, i) => {
    // 单位=格; Y 按 32/48 屏幕压扁 (原式 px*48 与格差直接相减是单位错位, 东南恒判 Down)
    const dd = (d[0] - (to.x - from.x)) ** 2 + ((d[1] * 32 / 48) - (to.y - from.y)) ** 2;
    if (dd < bd) { bd = dd; best = i; }
  });
  return best;
}

// ---------- 精帧缓存 (失败不缓存 → 下次重试) ----------
const _frameCache = new Map();
export function frameSpriteCached(lib, frame) {
  const key = `${lib}:${frame}`;
  if (_frameCache.has(key)) return _frameCache.get(key);
  const p = spriteFrame(lib, frame);
  _frameCache.set(key, p);
  p.then((v) => { if (v == null) _frameCache.delete(key); }).catch(() => { _frameCache.delete(key); });
  return p;
}

// ---------- 色染 (Colour: Fire/Ice/... 离屏 multiply, 按帧缓存) ----------
const TINT_COLORS = { Fire: '#ff451a', Ice: '#7fd7ff', Lightning: '#ffe14d', Wind: '#8effc8',
                      Holy: '#fff3b0', Dark: '#b366ff', Phantom: '#d8a8ff', None: null };
const _tintCache = new Map();
function tinted(sprite, colour) {
  const key = `${sprite.img.src}|${sprite.w}x${sprite.h}|${colour}`;
  if (_tintCache.has(key)) return _tintCache.get(key);
  const cv = document.createElement('canvas');
  cv.width = sprite.w; cv.height = sprite.h;
  const c2 = cv.getContext('2d');
  c2.drawImage(sprite.img, 0, 0, sprite.w, sprite.h);
  c2.globalCompositeOperation = 'multiply';
  c2.fillStyle = TINT_COLORS[colour] || '#ffffff';
  c2.fillRect(0, 0, cv.width, cv.height);
  c2.globalCompositeOperation = 'destination-in';
  c2.drawImage(sprite.img, 0, 0, sprite.w, sprite.h);
  const out = { img: cv, w: sprite.w, h: sprite.h, ox: sprite.ox, oy: sprite.oy };
  _tintCache.set(key, out);
  if (_tintCache.size > 500) _tintCache.clear();
  return out;
}

// ---------- 引擎实例 ----------
// opts: { toScreen(wx, wy) -> {x, y} 屏幕像素 }
export function createFxEngine(opts) {
  const st = { t: 0, fx: [] };

  const cellPx = (c) => ({ x: c.x * CELL_W + CELL_W / 2, y: (c.y + 1) * CELL_H });

  function spawn(def) { st.fx.push({ t0: st.t + (def.at || 0), ...def, onDone: def.onDone || [] }); }

  // ---- original 段特效条目 → 单实例 (lab spawnFromEffect 通用化) ----
  function spawnFromEffect(e, { attach, at, dir, dir16 }) {
    let frame = e.frame ?? e.directionFrames?.[dir] ?? e.directionFrames?.[0];
    if (frame == null && e.frameExpr) {
      const m = String(e.frameExpr).match(/(\d+)/);   // 随机组取首组基址
      if (m) frame = +m[1];
    }
    if (frame == null) return null;
    const skip = e.extra?.Skip ?? 10;
    const useDir = typeof e.extra?.Direction === 'number' ? e.extra.Direction
      : (e.extra?.DirectionSemantic === 'castDirection' ? dir : 0);
    spawn({
      lib: e.lib, frame, count: e.count, delay: e.delayMs || 100, skip,
      dir: useDir, dir16: dir16 ?? 0, has16: false,     // dir16 由弹道路径内联进 drawFrame
      attach: typeof attach === 'object' ? null : attach,
      point: typeof attach === 'object' ? attach.point : undefined,
      at, kind: e.kind || e.segment, label: `${e.lib}#${frame}`,
      blend: e.extra?.Blend !== false && (e.extra?.Blend ?? true) !== false,
      blendRate: e.extra?.BlendRate ?? 0.7,
      opacity: e.extra?.Opacity ?? 1,
      layer: String(e.extra?.DrawType || 'Object').toLowerCase(),
      colour: e.colour && e.colour !== 'None' ? e.colour : null,
      onDone: [],
    });
    return frame;
  }

  // ---- 施法编排 (lab playSkill 通用化; 多目标/落点由 caller 决定) ----
  // ctx: { caster:{x,y}, target:{x,y}|null, point:{x,y}|null, targets:[{x,y}],
  //        ff, dir8?, aoeRadius?, now?, log?(ms, text) }
  function playFromEntry(entry, ctx) {
    const { caster, target, point, ff } = ctx;
    const targets = ctx.targets?.length ? ctx.targets : (target ? [target] : []);
    const aim = point || target || caster;
    const casterPx = cellPx(caster);
    const aimPx = cellPx(aim);
    const dir = ctx.dir8 ?? dir8To(caster, aim);
    const d16 = direction16(casterPx.x, casterPx.y, aimPx.x, aimPx.y);
    const anim = ff.animOf(ctx.magicKey);
    const relDelay = ctx.relDelay ?? spellReleaseDelayMs(ff, anim);
    const effectsOf = (seg) => entry?.[seg]?.effects || [];
    const log = ctx.log || (() => {});
    const aoeCells = [];
    if (point) {
      const r = ctx.aoeRadius ?? 2;
      for (let dy = -r; dy <= r; dy++) for (let dx = -r; dx <= r; dx++)
        if (dx * dx + dy * dy <= r * r + 1) aoeCells.push({ x: point.x + dx, y: point.y + dy });
    }

    // start 段 (t=0, 施法者)
    for (const e of effectsOf('start')) spawnFromEffect(e, { attach: { point: caster }, at: 0, dir });

    // release 段 (t=relDelay)
    for (const e of effectsOf('release')) {
      if (e.kind === 'projectile') {
        const to = cellPx(aim);
        const dur = Math.max(1, Math.hypot(to.x - casterPx.x, to.y - casterPx.y));
        const skip = e.extra?.Skip ?? 10;
        const has16 = e.extra?.Has16Directions !== false;
        const fr = e.frame ?? e.directionFrames?.[0];
        if (fr == null) continue;
        const last = {
          lib: e.lib, frame: fr, count: e.count, delay: e.delayMs || 100, skip,
          dir: 0, dir16: has16 ? d16 : Math.floor(d16 / 2), has16: false, // dir16 已含在 drawFrame
          attach: null, point: caster,
          flight: { fromX: casterPx.x, fromY: casterPx.y, toX: to.x, toY: to.y, dur },
          at: relDelay, kind: 'projectile', label: `弹道 ${e.lib}#${fr}`,
          blend: e.extra?.Blend !== false, blendRate: e.extra?.BlendRate ?? 0.7, opacity: 1,
          layer: 'object', colour: e.colour !== 'None' ? e.colour : null,
          onDone: [],
        };
        spawn(last);
        log(relDelay, `→ 弹道 ${e.lib}#${fr}×${e.count} dir16=${d16} ${Math.round(dur)}ms`);
      } else if (e.segment === 'aoe') {
        let delay0 = e.extra?.StartDelayMs ?? 0;
        if (!delay0) {
          const stm = String(e.extra?.StartTime ?? '').match(/AddMilliseconds\((\d+)/);
          if (stm) delay0 = +stm[1];
        }
        const perCell = e.extra?.DistanceDelayMs ?? 0;
        const cells = aoeCells.length ? aoeCells : [aim];
        for (const c of cells) {
          const dist = Math.hypot(c.x - caster.x, c.y - caster.y);
          spawnFromEffect(e, { attach: { point: c }, at: relDelay + delay0 + dist * perCell, dir });
        }
        log(relDelay + delay0, `◉ 地面 ${e.lib}#${e.frame ?? e.frameExpr}×${e.count} (${cells.length}格)`);
      } else if (e.ctx?.includes('arrival')) {
        continue; // 由弹道 onDone 触发 (下)
      } else {
        const dst = e.target === 'point' ? [aim] : targets.length ? targets : [caster];
        dst.forEach((c, i) => spawnFromEffect(e, { attach: { point: c }, at: relDelay + i * 80, dir }));
        log(relDelay, `✦ ${e.lib}#${e.frame}×${e.count} → ${e.target === 'point' ? '落点' : dst.length + '目标'}`);
      }
    }

    // arrival: 弹道到达后 (dur 像素=ms)
    const arrivals = effectsOf('release').filter((e) => e.ctx?.includes('arrival'));
    if (arrivals.length) {
      let maxDur = 0;
      for (const e of effectsOf('release')) if (e.kind === 'projectile') {
        const to = cellPx(aim);
        maxDur = Math.max(maxDur, Math.hypot(to.x - casterPx.x, to.y - casterPx.y));
      }
      const tHit = relDelay + Math.max(maxDur, 1);
      for (const e of arrivals) {
        const dst = e.target === 'point' ? [aim] : (targets.length ? targets : [aim]);
        for (const c of dst) spawnFromEffect(e, { attach: { point: c }, at: tHit, dir });
        log(tHit, `✸ 命中 ${e.lib}#${e.frame}×${e.count}`);
      }
    }
    for (const sname of entry?.sound?.start || []) log(0, `♪ ${sname}`);
    for (const sname of entry?.sound?.end || []) {
      log(relDelay, `♪ ${sname}`);
    }
  }

  // ---------- 帧推进 ----------
  function update(dt) {
    st.t += dt;
    for (let i = st.fx.length - 1; i >= 0; i--) {
      const f = st.fx[i];
      const t = st.t - f.t0;
      if (t < 0) continue;
      if (f.flight && t >= f.flight.dur) {
        for (const cb of f.onDone) cb();
        st.fx.splice(i, 1);
        continue;
      }
      if (!f.flight && t >= f.count * f.delay) {
        for (const cb of f.onDone) cb();
        st.fx.splice(i, 1);
      }
    }
  }

  // ---------- 绘制 (分层: floor < object < final) ----------
  function draw(ctx, layer, toScreen) {
    const scr = toScreen || opts.toScreen;
    for (const f of st.fx) {
      const t = st.t - f.t0;
      if (t < 0) continue;
      if ((f.layer || 'object') !== layer) continue;
      let wx, wy, idx, dirOff;
      if (f.flight) {
        const p = Math.min(1, t / f.flight.dur);
        wx = f.flight.fromX + (f.flight.toX - f.flight.fromX) * p;
        wy = f.flight.fromY + (f.flight.toY - f.flight.fromY) * p;
        idx = Math.min(f.count - 1, Math.floor(t / f.delay));
        dirOff = f.dir16 * (f.skip ?? 10);
      } else {
        const c = f.point || { x: 0, y: 0 };
        wx = c.x * CELL_W + CELL_W / 2; wy = (c.y + 1) * CELL_H;
        idx = Math.floor(t / f.delay);
        if (idx >= f.count) continue;
        dirOff = f.dir * (f.skip ?? 10);
      }
      if (idx < 0) continue;
      const frameNo = f.frame + idx + dirOff;
      frameSpriteCached(f.lib, frameNo)
        .then((s) => { f._last = s ?? false; f._lastNo = frameNo; })
        .catch(() => {});
      for (let k = 1; k <= 3 && idx + k < f.count; k++)
        frameSpriteCached(f.lib, f.frame + idx + k + dirOff);
      const s = f._lastNo === frameNo ? f._last : null;
      if (!s) continue;
      const p = scr(wx, wy);
      const img = f.colour && TINT_COLORS[f.colour] ? tinted(s, f.colour) : s;
      if (f.blend) { ctx.globalCompositeOperation = 'lighter'; ctx.globalAlpha = f.blendRate; }
      else ctx.globalAlpha = f.opacity ?? 1;
      ctx.drawImage(img.img, p.x + img.ox, p.y - img.h / 2 + img.oy, img.w, img.h);
      ctx.globalCompositeOperation = 'source-over';
      ctx.globalAlpha = 1;
    }
  }

  return { st, spawn, spawnFromEffect, playFromEntry, update, draw };
}
