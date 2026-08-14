// render.js — 主渲染循环: 地图瓦片 + 实体 (Y 排序) + 特效 + 名称
import { CELL_W, CELL_H, D } from './data.js';
import { loadSprite, frameMeta } from './res.js';
import { monsterSprite, npcSprite, itemSprite, playerSprites, drawFramed, drawPlayer } from './sprites.js';

const DIR_VEC = [
  [0, -1], [1, -1], [1, 0], [1, 1], [0, 1], [-1, 1], [-1, 0], [-1, -1],
];

export class Renderer {
  constructor(game) {
    this.game = game;
    this.playerSpr = null;
    this.entitySpr = new Map();   // key -> Promise/sprite
    this.showNames = true;
    this.showNpcs = true;
    this.showMons = true;
    this.showExits = true;
    this.drawEffects = true;
    this.drawParticles = true;
    this.lastFrameStats = { draw: 0, entities: 0 };
  }

  cellAnchor(cam, x, y) {
    // 格底边中点 (rect 布局: 格 = 48x32; 人物锚 = 底边中点, 见 PlayerRenderer.ComputeScreenPos
    //   Position = (CellX-…)*48, (CellY-…+1)*32 - 34  → 锚在格底边再上提 34px 由帧 oy 承担)
    const wx = x * CELL_W + CELL_W / 2;
    const wy = (y + 1) * CELL_H;
    return cam.worldToScreen(wx, wy);
  }

  frame(dt) {
    const { game } = this;
    const { world, cam, ctx } = game;
    this.lastFrameStats.draw++;

    // 1. 地图 (缺瓦片后台加载, 本帧占位)
    const m = D().manifest.maps[world.map];
    const missing = cam.drawMap(world.map, m.tiles, m.w * CELL_W, m.h * CELL_H);

    // 2. 实体收集 (Y 排序); 精灵异步解析, 就绪后由下一帧绘制 (不阻塞)
    const ents = this.collectEntities();
    ents.sort((a, b) => a.y - b.y);
    this.lastEnts = ents;
    this.drawEntities(ctx, cam, ents, dt);

    return missing;
  }

  collectEntities() {
    const { world } = this.game;
    const ents = [];
    const p = world.player;
    const look = world.currentLook();
    ents.push({
      y: p.y, x: p.x, kind: 'player',
      key: `player:${p.cls}${p.gender}:${p.armourShape},${p.weaponShape},${p.helmetShape},${p.hairType}:${p.anim === 'moving' ? 'standing' : p.anim}:${p.animFrame}:${p.dir}:${p.invis ? 1 : 0}`,
      spr: playerSprites(look, p.anim === 'moving' ? 'standing' : p.anim, p.animFrame, p.dir),
      alpha: p.invis ? 0.45 : 1,
      name: `${this.game.className(p.cls)}·Lv${p.level}`, color: '#7ec8ff',
    });
    if (this.showNpcs) {
      for (const n of world.npcs) {
        ents.push({ y: n.y, x: n.x, kind: 'npc', e: n, key: `npc:${this.game.world.map}:${n.mid ?? n.image}:${n.x}:${n.y}`,
          spr: npcSprite(D().appearance.npc_lib, n.image, 0),
          name: n.zh, color: '#7de27d', info: n });
      }
    }
    if (this.showMons) {
      for (const mo of world.mons) {
        ents.push({ y: mo.y, x: mo.x, kind: 'mon', e: mo, key: `mon:${mo.mon.lib}:${mo.mon.shape}:${mo.frame}`,
          spr: monsterSprite(mo.mon.lib, mo.mon.shape, 'standing', mo.frame, 4),
          name: mo.mon.zh + (mo.mon.boss ? ' [BOSS]' : ''), color: mo.mon.boss ? '#ff7a7a' : '#e8c96a',
          info: mo.mon });
      }
      for (const s of world.summons) {
        ents.push({ y: s.y, x: s.x, kind: 'mon', e: s, key: `sum:${s.id}`,
          spr: monsterSprite(s.mon.lib, s.mon.shape, 'standing', s.frame, 4),
          name: `召唤:${s.mon.zh}`, color: '#c99fff', info: s.mon });
      }
      for (const pet of world.pets) {
        ents.push({ y: pet.y, x: pet.x, kind: 'mon', e: pet, key: `pet:${pet.kind}`,
          spr: monsterSprite(pet.mon.lib, pet.mon.shape, 'standing', pet.frame, 4),
          name: pet.name, color: '#8ad8ff', info: pet.mon });
      }
    }
    for (const d of world.items) {
      ents.push({ y: d.y, x: d.x, kind: 'item', e: d, key: `item:${d.id}`,
        spr: itemSprite(D().appearance.icon_libs.ground, d.it.image),
        name: d.it.zh, color: '#ffd873', info: d.it });
    }
    return ents;
  }
  drawEntities(ctx, cam, ents, _dt) {
    // 出口高亮
    const m = D().manifest.maps[this.game.world.map];
    if (this.showExits) this.drawExits(ctx, cam, m);
    // 实体: 稳定 key 缓存已解析精灵 (collectEntities 每帧重建对象, 不能挂对象上)
    let drawn = 0;
    for (const en of ents) {
      let spr = this.entitySpr.get(en.key);
      if (spr === undefined) {
        spr = null;
        this.entitySpr.set(en.key, null);            // 防重复预取
        Promise.resolve(en.spr).then((s) => this.entitySpr.set(en.key, s ?? null))
          .catch(() => this.entitySpr.set(en.key, null));
      }
      if (spr) { this._drawEnt(ctx, cam, en, spr); drawn++; }
    }
    if (this.entitySpr.size > 800) this.entitySpr.clear();
    this.lastFrameStats.entities = drawn;
    // 施法特效
    if (this.drawEffects) this.drawEffectsNow(ctx, cam, _dt);
    // 悬停格
    if (this.game.hoverCell) {
      const a = this.cellAnchor(cam, this.game.hoverCell.x, this.game.hoverCell.y);
      ctx.strokeStyle = '#ffffff66';
      ctx.strokeRect(a.x - CELL_W / 2 * cam.zoom, a.y - CELL_H * cam.zoom / 2 - CELL_H * cam.zoom / 2, CELL_W * cam.zoom, CELL_H * cam.zoom);
    }
  }

  _drawEnt(ctx, cam, en, spr) {
    if (!spr) return;
    const a = this.cellAnchor(cam, en.x, en.y);
    if (a.x < -200 || a.y < -300 || a.x > cam.canvas.width + 200 || a.y > cam.canvas.height + 300) return;
    if (en.kind === 'player') drawPlayer(ctx, spr, a.x, a.y, en.alpha);
    else drawFramed(ctx, spr, a.x, a.y);
    if (this.showNames && en.name) this.drawName(ctx, a.x, a.y, en.name, en.color);
    en._sx = a.x; en._sy = a.y;
  }


  drawName(ctx, x, y, name, color) {
    ctx.font = '12px sans-serif';
    ctx.textAlign = 'center';
    ctx.fillStyle = '#000c';
    ctx.fillText(name, x + 1, y - 48);
    ctx.fillStyle = color;
    ctx.fillText(name, x, y - 49);
  }

  drawExits(ctx, cam, m) {
    for (const e of m.exits) {
      const a = this.cellAnchor(cam, e.x, e.y);
      const r = Math.max(e.r, 1);
      const w = (2 * r + 1) * CELL_W * cam.zoom, h = (2 * r + 1) * CELL_H * cam.zoom;
      const cx = a.x, cy = a.y - CELL_H * cam.zoom / 2;
      const pulse = 0.5 + 0.3 * Math.sin(performance.now() / 400);
      ctx.fillStyle = `rgba(120,200,255,${0.12 * pulse + 0.06})`;
      ctx.fillRect(cx - w / 2, cy - h / 2, w, h);
      ctx.strokeStyle = `rgba(140,220,255,${0.55 * pulse + 0.2})`;
      ctx.lineWidth = 1.5;
      ctx.strokeRect(cx - w / 2, cy - h / 2, w, h);
    }
  }

  drawEffectsNow(ctx, cam, dt) {
    const world = this.game.world;
    for (let i = world.effects.length - 1; i >= 0; i--) {
      const fx = world.effects[i];
      fx.t += dt;
      const done = this.renderEffect(ctx, cam, fx);
      if (done) world.effects.splice(i, 1);
    }
  }

  renderEffect(ctx, cam, fx) {
    const a = this.cellAnchor(cam, fx.x, fx.y);
    let allDone = true;
    for (const layer of [fx.effect, fx.proj, fx.impact]) {
      if (!layer) continue;
      const idx = Math.floor(fx.t / layer.ms);
      if (idx >= layer.count) { if (layer === fx.impact || !fx.loop) continue; }
      const frame = layer.start + Math.min(idx, layer.count - 1);
      const fr = spriteFrameSync(layer.lib, frame);
      // 前瞻: 预取后 3 帧, 避免动画播放中途缺帧
      for (let k = 1; k <= 3 && idx + k < layer.count; k++)
        spriteFrameSync(layer.lib, layer.start + idx + k);
      if (fr) {
        ctx.globalAlpha = 0.9;
        ctx.drawImage(fr.img, a.x + fr.ox, a.y - fr.h / 2 + fr.oy, fr.w, fr.h);
        ctx.globalAlpha = 1;
      }
      if (idx < layer.count) allDone = false;
    }
    // 粒子开关演示 (简单火花)
    if (this.drawParticles && fx.particles) {
      for (let k = 0; k < 6; k++) {
        const ang = (k / 6) * Math.PI * 2 + fx.t / 300;
        const rad = 20 + 14 * Math.sin(fx.t / 200 + k);
        ctx.fillStyle = 'rgba(255,200,90,.6)';
        ctx.fillRect(a.x + Math.cos(ang) * rad, a.y - 20 + Math.sin(ang) * rad, 3, 3);
      }
    }
    return allDone && fx.t > 200;
  }
}

// 特效帧同步缓存: key = "lib:frame" -> {img,w,h,ox,oy} | undefined (预取中)
const _fxCache = new Map();
function spriteFrameSync(lib, frame) {
  const key = `${lib}:${frame}`;
  if (_fxCache.has(key)) return _fxCache.get(key);
  _fxCache.set(key, undefined);      // 先占位防重
  Promise.all([loadSprite(lib, frame), frameMeta(lib)]).then(([im, meta]) => {
    if (!im) return;
    const m = meta[frame];
    _fxCache.set(key, {
      img: im,
      w: m ? m[0] : im.width, h: m ? m[1] : im.height,
      ox: m ? m[2] : 0, oy: m ? m[3] : 0,
    });
  }).catch(() => {});
  return undefined;
}

export { DIR_VEC };
