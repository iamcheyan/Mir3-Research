// frames.js — FrameSet.cs / Functions.cs 动画帧表与算法移植 (Phase2 对象系统)
// 依据: LibraryCore/FrameSet.cs:76-157 (Players/DefaultMonster/DefaultNPC/DefaultItem),
//       FrameSet.cs:1076-1139 (Frame 结构 + GetFrame), Functions.cs:119-302 (动作选择),
//       Enum.cs:463-542 (MirAction/MirAnimation), Formats/MonsterLookup (经 WebData monsters.json)

// ---- MirDirection (Enum.cs:48) ----
export const DIR_UP = 0, DIR_UPRIGHT = 1, DIR_RIGHT = 2, DIR_DOWNRIGHT = 3;
export const DIR_DOWN = 4, DIR_DOWNLEFT = 5, DIR_LEFT = 6, DIR_UPLEFT = 7;

// ---- Frame (FrameSet.cs:1076-1139) ----
export class Frame {
  constructor(start, count, offset, ms, reversed = false, staticSpeed = false) {
    this.start = start; this.count = count; this.offset = offset;
    this.reversed = reversed; this.staticSpeed = staticSpeed;
    this.delays = new Array(count).fill(ms);
    this.sum = ms * count;
  }
  setDelay(i, ms) { this.sum += ms - this.delays[i]; this.delays[i] = ms; }
  // GetFrame (1109-1139): 返回当前帧号 (0-based) 或 count (播完)
  getFrame(startMs, now, doubleSpeed) {
    let elapsed = now - startMs;
    if (doubleSpeed && !this.staticSpeed) elapsed *= 2;
    if (elapsed < 0) return 0;
    for (let i = 0; i < this.count; i++) {
      const d = this.delays[this.reversed ? this.count - 1 - i : i];
      if (elapsed < d) return i;
      elapsed -= d;
    }
    return this.count; // 播完
  }
}

const F = (s, c, o, ms, r, ss) => new Frame(s, c, o, ms, r, ss);

// ---- 玩家帧表 FrameSet.Players (FrameSet.cs:76-128) ----
export const PLAYERS = {
  standing:      F(0, 4, 10, 500),
  walking:       F(80, 6, 10, 100),
  running:       F(160, 6, 10, 100),
  creepStanding: F(1680, 4, 10, 500),
  creepWalkSlow: F(1760, 6, 10, 200),
  creepWalkFast: F(1760, 6, 10, 100),
  pushed:        F(240, 6, 10, 50, true, true),
  stance:        F(400, 3, 10, 500),
  harvest:       F(480, 2, 10, 300),
  combat1:       F(560, 5, 10, 100),
  combat2:       F(640, 5, 10, 100),
  combat3:       F(720, 6, 10, 100),
  combat4:       F(800, 6, 10, 100),
  combat5:       F(880, 10, 10, 60),
  combat6:       F(960, 10, 10, 60),
  combat7:       F(1040, 10, 10, 100),
  combat8:       F(1120, 6, 10, 50, false, true),
  combat9:       F(1200, 10, 10, 100),
  combat10:      F(1280, 10, 10, 60),
  combat11:      F(1360, 10, 10, 60),
  combat12:      F(1440, 10, 10, 60),
  combat13:      F(1520, 6, 10, 100),
  combat14:      F(1600, 8, 10, 100),
  combat15:      F(400, 3, 10, 200),
  dragonRepulseStart: F(1600, 6, 10, 100),
  dragonRepulseMiddle:F(1605, 1, 10, 1000),
  dragonRepulseEnd:   F(1606, 2, 10, 100),
  struck:        F(1840, 3, 10, 100),
  die:           F(1920, 10, 10, 100),
  dead:          F(1929, 1, 10, 1000),
  fishingCast:   F(2000, 8, 10, 100),
  fishingWait:   F(2080, 6, 10, 120),
  fishingReel:   F(2160, 8, 10, 100),
  horseStanding: F(2240, 4, 10, 500),
  horseWalking:  F(2320, 6, 10, 100),
  horseRunning:  F(2400, 6, 10, 100),
  horseStruck:   F(2480, 3, 10, 100),
  channellingStart: F(560, 4, 10, 100),
  channellingMiddle:F(563, 1, 10, 1000),
  channellingEnd:   F(0, 1, 10, 60),
  tamingCast:    F(720, 6, 10, 100),
  tamingWait:    F(725, 1, 10, 100),
};
// 覆盖帧延迟 (FrameSet.cs:127-128)
PLAYERS.combat1.setDelay(1, 200);
PLAYERS.combat2.setDelay(3, 200);

// ---- 怪物/NPC/物品默认帧表 (FrameSet.cs:132-157) ----
export const DEFAULT_MONSTER = {
  standing: F(0, 4, 10, 500),
  walking:  F(80, 6, 10, 100),
  pushed:   F(80, 6, 10, 50, true, true),
  combat1:  F(160, 6, 10, 100),
  combat2:  F(160, 6, 10, 100),
  combat3:  F(160, 6, 10, 100),
  struck:   F(240, 2, 10, 100),
  die:      F(320, 10, 10, 100),
  dead:     F(329, 1, 10, 1000),
  skeleton: F(880, 1, 10, 1000),
  show:     F(640, 10, 10, 100),
  hide:     F(640, 10, 10, 100, true),
  stoneStanding: F(640, 1, 10, 500),
};
// 怪物多格移动恒用 Walking (MapObjectNode Running 分支缺表回退 Standing 的 Godot 偏差不复制)
export const DEFAULT_NPC = {
  standing: F(0, 4, 0, 1000),   // 无方向帧
};
// NPC 特例帧表 (ObjectRenderer.cs:270-297): image → {single}|{start,count,ms}
const NPC_SPECIAL_DATA = [
  [64, 65, 91, 92, 93, 157, 158, 160, 165, 166, 168, 208, 209, 210, 211, 212, 213, 214, 231, 234],
].flatMap(imgs => imgs.map(i => [i, { single: true }]));
NPC_SPECIAL_DATA.push([56, { start: 0, count: 12, ms: 200 }]);
NPC_SPECIAL_DATA.push([57, { start: 0, count: 12, ms: 200 }]);
NPC_SPECIAL_DATA.push([156, { start: 0, count: 16, ms: 200 }]);
export const NPC_SPECIAL = new Map(NPC_SPECIAL_DATA);
export const DEFAULT_ITEM = { standing: F(0, 1, 0, 1000) };

// ---- MirAction (Enum.cs:463) ----
export const MIR_ACTION = {
  Standing: 0, Moving: 1, Pushed: 2, Attack: 3, RangeAttack: 4, Spell: 5,
  Harvest: 6, Struck: 7, Die: 8, Dead: 9, Show: 10, Hide: 11, Mount: 12,
  Mining: 13, Fishing: 14, Taming: 15, Idle: 16,
};
export const SPELL_ACTION = MIR_ACTION.Spell;

// ---- MagicType 数值 (Enum.cs 脚本自动提取, /tmp/magic_js.txt) ----
export const MAGIC = {
  Slaying: 102, Thrusting: 103, FlamingSword: 106, DefensiveBlow: 130,
  HalfMoon: 104, DestructiveSurge: 109, OffensiveBlow: 134, DragonRise: 107,
  BladeStorm: 108, FullBloom: 405, WhiteLotus: 407, RedLotus: 410,
  DanceOfSwallow: 428, SweetBrier: 414, Karma: 416, Beckon: 112,
  MassBeckon: 123, FireBall: 201, IceBolt: 203, LightningBall: 202,
  GustBlast: 204, ScortchedEarth: 212, LightningBeam: 213, AdamantineFireBall: 208,
  FireBounce: 231, IceBlades: 210, FrozenEarth: 214, MeteorShower: 226,
  LightningStrike: 236, IceAura: 243, IceDragon: 244, ExplosiveTalisman: 303,
  EvilSlayer: 304, MagicResistance: 306, Resilience: 309, MassInvisibility: 307,
  GreaterEvilSlayer: 308, GreaterFrozenEarth: 224, Parasite: 326, ElementalSuperiority: 312,
  BloodLust: 314, LifeSteal: 320, ImprovedExplosiveTalisman: 321, Neutralize: 340,
  CorpseExploder: 345, SoulResonance: 325, SearingLight: 343, BindingTalisman: 347,
  BrainStorm: 348, Hemorrhage: 451, FlamingDaggers: 454, Shredding: 455,
  Interchange: 110, ElementalSwords: 131, TaecheonSword: 135, FireSword: 136,
  Repulsion: 205, ElectricShock: 206, LightningWave: 221, Cyclone: 211,
  Teleportation: 207, FireWall: 216, FireStorm: 220, BlowEarth: 215,
  ExpelUndead: 217, MagicShield: 219, IceStorm: 222, DragonTornado: 223,
  ChainLightning: 225, GeoManipulation: 218, Transparency: 317, ThunderBolt: 209,
  Renounce: 227, FrostBite: 239, Tempest: 228, JudgementOfHeaven: 229,
  ThunderStrike: 230, MirrorImage: 237, Asteroid: 240, SuperiorMagicShield: 233,
  IceRain: 238, Tornado: 242, IceBreaker: 245, FrozenDragon: 246,
  Heal: 300, PoisonDust: 302, Invisibility: 305, TrapOctagon: 310,
  MassHeal: 313, Resurrection: 315, Purification: 316, SummonSkeleton: 332,
  SummonJinSkeleton: 334, SummonShinsu: 333, StrengthOfFaith: 335, CelestialLight: 318,
  AugmentPoisonDust: 322, SummonDemonicCreature: 336, DemonExplosion: 337, CursedDoll: 323,
  DarkSoulPrison: 342, SummonDead: 346, HeavenlySky: 349, PoisonCloud: 350,
  ElementalHurricane: 232, PoisonousCloud: 404, SummonPuppet: 415, Containment: 449,
  FourWheels: 456, CrescentMoon: 457, DragonRepulse: 430, ThunderKick: 324,
  CombatKick: 311, Shuriken: 132,
};

// MirClass (Enum.cs)
export const CLASS_WARRIOR = 0, CLASS_WIZARD = 1, CLASS_TAOIST = 2, CLASS_ASSASSIN = 3, CLASS_ARCHER = 4;

// ---- GetAttackAnimation (Functions.cs:119-190) ----
export function getAttackAnimation(cls, weaponShape, magicType = 0) {
  const M = MAGIC;
  switch (magicType) {
    case M.Slaying: case M.Thrusting: case M.FlamingSword: case M.DefensiveBlow:
      return 'combat3';
    case M.HalfMoon: case M.DestructiveSurge: case M.OffensiveBlow:
      return 'combat4';
    case M.DragonRise: return 'combat5';
    case M.BladeStorm: return 'combat6';
    case M.FullBloom: case M.WhiteLotus: case M.RedLotus: case M.DanceOfSwallow:
      return weaponShape >= 1200 ? 'combat13' : weaponShape >= 1100 ? 'combat5' : 'combat3';
    case M.SweetBrier: case M.Karma:
      return weaponShape >= 1200 ? 'combat12' : weaponShape >= 1100 ? 'combat10' : 'combat3';
    default:
      if (cls === CLASS_ASSASSIN)
        return weaponShape >= 1200 ? 'combat11' : weaponShape >= 1100 ? 'combat4' : 'combat3';
      return 'combat3';
  }
}

// Combat1 组 (弹道/远程/指向辅助系) — Functions.cs:193-236
const MAGIC_C1 = new Set([
  'Beckon', 'MassBeckon', 'FireBall', 'IceBolt', 'LightningBall', 'GustBlast', 'ScortchedEarth',
  'LightningBeam', 'AdamantineFireBall', 'FireBounce', 'IceBlades', 'FrozenEarth', 'MeteorShower',
  'LightningStrike', 'IceAura', 'IceDragon', 'ExplosiveTalisman', 'EvilSlayer', 'MagicResistance',
  'Resilience', 'MassInvisibility', 'GreaterEvilSlayer', 'GreaterFrozenEarth', 'Parasite',
  'ElementalSuperiority', 'BloodLust', 'LifeSteal', 'ImprovedExplosiveTalisman', 'Neutralize',
  'CorpseExploder', 'SoulResonance', 'SearingLight', 'BindingTalisman', 'BrainStorm',
  'Hemorrhage', 'FlamingDaggers', 'Shredding',
]);
// Combat2 组 (指向/召唤/辅助系) — Functions.cs:238-283
const MAGIC_C2 = new Set([
  'Interchange', 'ElementalSwords', 'TaecheonSword', 'FireSword', 'Repulsion', 'ElectricShock',
  'LightningWave', 'Cyclone', 'Teleportation', 'FireWall', 'FireStorm', 'BlowEarth', 'ExpelUndead',
  'MagicShield', 'IceStorm', 'DragonTornado', 'ChainLightning', 'GeoManipulation', 'Transparency',
  'ThunderBolt', 'Renounce', 'FrostBite', 'Tempest', 'JudgementOfHeaven', 'ThunderStrike',
  'MirrorImage', 'Asteroid', 'SuperiorMagicShield', 'IceRain', 'Tornado', 'IceBreaker', 'FrozenDragon',
  'Heal', 'PoisonDust', 'Invisibility', 'TrapOctagon', 'MassHeal', 'Resurrection', 'Purification',
  'SummonSkeleton', 'SummonJinSkeleton', 'SummonShinsu', 'StrengthOfFaith', 'CelestialLight',
  'AugmentPoisonDust', 'SummonDemonicCreature', 'DemonExplosion', 'CursedDoll', 'DarkSoulPrison',
  'SummonDead', 'HeavenlySky', 'PoisonCloud',
]);
const MAGIC_C14 = new Set(['PoisonousCloud', 'SummonPuppet', 'Containment', 'FourWheels', 'CrescentMoon']);

// ---- GetMagicAnimation (Functions.cs:190-302) ----
export function getMagicAnimation(magicType) {
  if (magicType === MAGIC.ElementalHurricane) return 'channellingStart';
  if (MAGIC_C14.has(magicType)) return 'combat14';
  if (magicType === MAGIC.DragonRepulse) return 'dragonRepulseStart';
  if (magicType === MAGIC.ThunderKick || magicType === MAGIC.CombatKick) return 'combat7';
  for (const name of MAGIC_C1) if (MAGIC[name] === magicType) return 'combat1';
  for (const name of MAGIC_C2) if (MAGIC[name] === magicType) return 'combat2';
  return 'combat1'; // PlaySpell 容错 (PlayerRenderer.cs:317-341)
}

// ---- DirectionFromPoint / Distance (Functions.cs:414-464) ----
export function directionFromPoint(sx, sy, dx, dy) {
  if (sx < dx) return sy < dy ? DIR_DOWNRIGHT : sy > dy ? DIR_UPRIGHT : DIR_RIGHT;
  if (sx > dx) return sy < dy ? DIR_DOWNLEFT : sy > dy ? DIR_UPLEFT : DIR_LEFT;
  return sy < dy ? DIR_DOWN : DIR_UP;
}
export const chebyshev = (ax, ay, bx, by) => Math.max(Math.abs(ax - bx), Math.abs(ay - by));
export const inRange = (ax, ay, bx, by, r) => Math.abs(ax - bx) <= r && Math.abs(ay - by) <= r;

// ---- 刺客 ArmourShift (PlayerRenderer.cs:811-831) — 其他职业 0 ----
const ASSASSIN_SHIFT = {
  walking: 1600, running: 1600, creepStanding: 240, creepWalkSlow: 240, creepWalkFast: 240,
  pushed: 160, combat1: -400, combat4: 80, combat5: 400, combat6: 400, combat7: 400,
  combat8: 720, combat9: -960, combat10: -480, combat11: -400, combat12: -400, combat13: -400,
  harvest: 160, stance: 160, struck: -640, die: -400, dead: -400,
  horseStanding: 80, horseWalking: 80, horseRunning: 80, horseStruck: 80,
  fishingCast: 80, fishingWait: 80, fishingReel: 80,
};
export function armourShift(animName, isAssassin) {
  return isAssassin ? (ASSASSIN_SHIFT[animName] ?? 0) : 0;
}

// 施法释放延迟 = 前 min(3, count-1) 帧 Delays 之和 (PlayerRenderer.cs:98-133)
export function spellReleaseDelayMs(frame) {
  let sum = 0;
  for (let i = 0; i < Math.min(3, frame.count - 1); i++) sum += frame.delays[i];
  return sum;
}
