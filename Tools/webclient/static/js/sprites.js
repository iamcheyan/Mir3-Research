// sprites.js — 精灵绘制: 人物纸娃娃 / 怪物 / NPC / 掉落物 / 特效
// 层序依据 PlayerRenderer.DrawPlayerAt:
//   [back weapon(Up|DownLeft|Left|UpLeft)] -> [back shield(UpRight|Right|DownRight)]
//   -> body -> head(helmet|hair) -> [front weapon(UpRight|Right|DownRight|Down)]
// 锚点: DrawLayer dest = (px + OffSetX, py + OffSetY); 本端锚 = 格底边中点,
//   帧 manifest 元数据 [w,h,ox,oy] (ox/oy 为帧左上相对锚点偏移, 与 Zl OffSetX/Y 同源)。
import { loadSprite, frameMeta } from './res.js';
import { PLAYER_ANIMS, MONSTER_ANIMS, drawFrame, armourShift } from './data.js';

const metaWaiters = new Map();

function metaOf(lib) {
  if (metaWaiters.has(lib)) return metaWaiters.get(lib);
  const p = frameMeta(lib);
  metaWaiters.set(lib, p);
  p.catch(() => { metaWaiters.delete(lib); });  // 失败不缓存 (manifest 生成偶发失败不可毒化)
  return p;
}

export async function spriteFrame(lib, frame) {
  const im = await loadSprite(lib, frame);
  if (!im) return null;
  const meta = await metaOf(lib);
  const m = meta[frame];
  return { img: im, w: m ? m[0] : im.width, h: m ? m[1] : im.height,
           ox: m ? m[2] : 0, oy: m ? m[3] : 0 };
}

// 绘制一帧: 以 (sx, sy)=屏幕上格底边中点为锚; ox/oy 为帧内偏移
export function drawFramed(ctx, fr, sx, sy, alpha = 1) {
  if (!fr) return;
  ctx.globalAlpha = alpha;
  ctx.drawImage(fr.img, sx + fr.ox, sy + fr.oy, fr.w, fr.h);
  ctx.globalAlpha = 1;
}

// ---- 人物 (纸娃娃) ----
// look: {cls, gender, armourShape, weaponShape, helmetShape, hairType}
export async function playerSprites(look, animName, frameIdx, dir) {
  const anim = PLAYER_ANIMS[animName] || PLAYER_ANIMS.standing;
  const base = drawFrame(anim, frameIdx, dir);
  const isSin = look.cls === 'Assassin';
  const off = isSin ? 3000 : 5000;
  const shift = armourShift(animName, isSin);
  const ws = look.weaponShape >= 1000 ? look.weaponShape - 1000 : look.weaponShape;

  const jobs = [
    spriteFrame(look.libs.body, base + (look.armourShape % 11) * off + shift),
    look.helmetShape > 0
      ? spriteFrame(look.libs.helmet, base + ((look.helmetShape - 1) % 10) * off + shift)
      : (look.hairType > 0
          ? spriteFrame(look.libs.hair, base + (look.hairType - 1) * 5000)
          : Promise.resolve(null)),
  ];
  const backDirs = [0, 5, 6, 7];       // Up|DownLeft|Left|UpLeft
  const frontDirs = [1, 2, 3, 4];      // UpRight|Right|DownRight|Down
  const weapon = look.weaponShape != null && look.weaponShape >= 0
    ? spriteFrame(look.libs.weapon, base + (ws % 10) * 5000) : Promise.resolve(null);
  jobs.push(weapon);
  const [body, head, weaponFr] = await Promise.all(jobs);
  return { body, head, weapon: weaponFr, backDirs, frontDirs, dir };
}

export function drawPlayer(ctx, spr, sx, sy, alpha = 1) {
  if (!spr) return;
  // 背武器
  if (spr.weapon && spr.backDirs.includes(spr.dir)) drawFramed(ctx, spr.weapon, sx, sy, alpha);
  // 身体
  drawFramed(ctx, spr.body, sx, sy, alpha);
  // 头
  drawFramed(ctx, spr.head, sx, sy, alpha);
  // 前武器
  if (spr.weapon && spr.frontDirs.includes(spr.dir)) drawFramed(ctx, spr.weapon, sx, sy, alpha);
}

// ---- 怪物 ----
export async function monsterSprite(lib, shape, animName, frameIdx, dir) {
  const anim = MONSTER_ANIMS[animName] || MONSTER_ANIMS.standing;
  return spriteFrame(lib, shape * 1000 + drawFrame(anim, frameIdx, dir));
}

// ---- NPC ----
export async function npcSprite(lib, image, frameIdx) {
  return spriteFrame(lib, image * 100 + frameIdx);
}

// ---- 掉落物 ----
export async function itemSprite(lib, image) {
  return spriteFrame(lib, image);
}

