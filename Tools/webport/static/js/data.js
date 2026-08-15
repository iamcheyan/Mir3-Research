// data.js — 数据清单加载 + 帧号公式 (从 frames.js 单一数据源派生)
// 公式事实源: Tools/resedit/frame-formulas.json (frameformulas.py 从 Zircon C# 提取)
//   DrawFrame = i + start + offset*dir;  ArmourFrame = DrawFrame + (ArmourShape%11)*Off + Shift
//   WeaponFrame = DrawFrame + (WeaponShape%10)*5000;  HairFrame = DrawFrame + (HairType-1)*5000
//   HelmetFrame = DrawFrame + ((HelmetShape-1)%10)*Off + Shift
//   怪物帧 = Shape*1000 + DrawFrame;  NPC帧 = Image*100 + i
import { PLAYERS, DEFAULT_MONSTER, armourShift as _armourShift } from './frames.js';

export const TILE = 512;
export const CELL_W = 48, CELL_H = 32;

// ---- 帧公式 (懒投影: ensureLoaded() 后可用; 旧 API 签名不变) ----
const project = (getTable) => new Proxy({}, {
  get: (_, name) => {
    const f = getTable()?.[name];
    return f ? { start: f.start, count: f.count, offset: f.offset, ms: f.delays[0] } : undefined;
  },
});
export const PLAYER_ANIMS = project(() => PLAYERS);
export const MONSTER_ANIMS = project(() => DEFAULT_MONSTER);

export function drawFrame(anim, frameIdx, dir) {
  return frameIdx + anim.start + anim.offset * dir;
}
export const armourShift = (animName, isAssassin) => _armourShift(animName, isAssassin);

export function playerFrames(animName, { frameIdx, dir, armourShape = 0, isAssassin = false }) {
  const anim = PLAYER_ANIMS[animName] || PLAYER_ANIMS.standing;
  const base = drawFrame(anim, frameIdx, dir);
  const off = isAssassin ? 3000 : 5000;
  const shift = armourShift(animName, isAssassin);
  return {
    body: base + (armourShape % 11) * off + shift,
    weapon: base,          // + (weaponShape%10)*5000 由调用方叠加 (per-lib)
    hair: base,            // + (hairType-1)*5000
    helmet: base + shift,  // + ((helmetShape-1)%10)*off
  };
}

export function monsterFrame(shape, animName, frameIdx, dir) {
  const anim = MONSTER_ANIMS[animName] || MONSTER_ANIMS.standing;
  return shape * 1000 + drawFrame(anim, frameIdx, dir);
}

export function npcFrame(image, frameIdx) {
  return image * 100 + frameIdx;   // DefaultNPC Standing(0,4) 无方向偏移
}

// ---- 数据清单 ----
const Data = {
  manifest: null, maps: {}, npcs: [], monsters: [], respawns: {}, magics: [], items: [],
  appearance: null, monstersById: {}, itemsById: {},
};

export async function loadAll(progress) {
  const get = async (url) => (await fetch(url)).json();
  const step = async (label, fn) => {
    if (progress) progress(label);
    return fn();
  };
  Data.manifest = await step('地图清单', () => get('/res/data/maps_manifest.json'));
  Data.maps = Data.manifest?.maps ?? {};
  Data.npcs = await step('NPC 数据', () => get('/res/data/npcs.json'));
  Data.monsters = await step('怪物数据', () => get('/res/data/monsters.json'));
  Data.respawns = await step('刷怪数据', () => get('/res/data/respawns.json'));
  Data.magics = await step('技能数据', () => get('/res/data/magics.json'));
  Data.items = await step('物品数据', () => get('/res/data/items.json'));
  Data.appearance = await step('外观表', () => get('/res/data/appearance.json'));
  for (const m of Data.monsters) Data.monstersById[m.id] = m;
  for (const it of Data.items) Data.itemsById[it.id] = it;
  return Data;
}

export const D = () => Data;
window.__D = D;   // 调试/验收脚本入口 (不经模块导出)

// ---- 库选择 (RefreshLibraries 移植; appearance.json 带 C# switch 表) ----
export function pickLibs({ cls, gender, armourShape, weaponShape, helmetShape }) {
  // 竞态防护: 建号进图瞬间 appearance.json 可能未就绪 (par-keys R5 转来)。
  // 返回 null-libs 骨架, world.#enterWorld loadAll 后统一 refreshLibs 重解析。
  if (!Data.appearance) return { body: null, weapon: null, helmet: null, hair: null };
  const t = Data.appearance.tables;
  const libs = Data.appearance.libraries;
  const isFemale = gender === 'F';
  const isSin = cls === 'Assassin';
  const femaleOff = isFemale ? 5000 : 0;
  const sinOff = isSin ? 50000 : 0;

  let body = isSin ? (isFemale ? 'WM_HumA' : 'M_HumA') : (isFemale ? 'WM_Hum' : 'M_Hum');
  if (armourShape != null) {
    const lib = t.armour[Math.floor(armourShape / 11) + femaleOff + sinOff];
    if (lib) body = lib;
  }
  let weapon = 'M_Weapon1';
  if (weaponShape != null && weaponShape >= 0) {
    weapon = t.weapon[Math.floor(weaponShape / 10) + femaleOff] || 'M_Weapon1';
  }
  let helmet = null;
  if (helmetShape > 0) helmet = t.helmet[Math.floor((helmetShape - 1) / 10) + femaleOff + sinOff] || null;
  const hair = isSin ? (isFemale ? 'WM_HairA' : 'M_HairA') : (isFemale ? 'WM_Hair' : 'M_Hair');
  return {
    body: libs[body], weapon: libs[weapon], helmet: helmet ? libs[helmet] : null,
    hair: libs[hair],
  };
}

// ---- 可行走位图 ----
const walkCache = {};
export async function walkBits(stem) {
  if (walkCache[stem]) return walkCache[stem];
  const buf = await (await fetch(`/res/walk/${stem}.bin`)).arrayBuffer();
  // zlib 解压 (浏览器无 zlib; serve.py 输出 DEFLATE 原始流 -> ffxlate 兜底用 pako-lite 内联实现)
  const bits = await inflate(new Uint8Array(buf));
  walkCache[stem] = bits;
  return bits;
}

// 极简 zlib inflate (RFC1950/1951) — 只需解压服务端 zlib 压缩位图
async function inflate(bytes) {
  const ds = new DecompressionStream('deflate');
  const stream = new Blob([bytes]).stream().pipeThrough(ds);
  return new Uint8Array(await new Response(stream).arrayBuffer());
}

export function walkable(bits, x, y, w) {
  if (!bits) return true;
  const i = x + y * w;
  return (bits[i >> 3] >> (i & 7) & 1) === 1;
}
