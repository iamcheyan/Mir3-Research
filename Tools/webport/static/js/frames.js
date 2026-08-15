// frames.js — 帧表/纸娃娃公式: 运行时读 Tools/resedit/frame-formulas.json (单一数据源)
// 数据由 Tools/resedit/frameformulas.py 从 Zircon C# 事实源生成:
//   LibraryCore/FrameSet.cs (94 表) / Functions.cs (攻击+魔法分派) / Enum.cs (MagicType 221 项)
//   GodotClient/Scripts/PlayerRenderer.cs (ArmourShift) / ObjectRenderer.cs (NPC 特例)
// 本文件只保留: JSON 加载器 + 纯算法 (Frame 步进/方向计算/分派求值); 不再手抄任何表。
// 消灭 JS/C# 双份维护 (总纲 §7.1 任务 1): 改帧表 → 重跑提取器 → 两侧同步变。

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

// ---- 帧表 (从 JSON 构建; ensureLoaded() 后可用) ----
function F(e) {
  const f = new Frame(e.start, e.count, e.offset, e.ms, e.reversed, e.staticSpeed);
  if (e.delays) for (const [i, ms] of Object.entries(e.delays)) f.setDelay(+i, ms);
  return f;
}
const table = (obj) => Object.fromEntries(Object.entries(obj).map(([k, e]) => [k, F(e)]));

export let PLAYERS = null;          // FrameSet.Players
export let DEFAULT_MONSTER = null;  // FrameSet.DefaultMonster
export let DEFAULT_NPC = null;      // FrameSet.DefaultNPC
export let DEFAULT_ITEM = null;     // FrameSet.DefaultItem
export let NPC_SPECIAL = null;      // ObjectRenderer NPC 特例 (Map image→spec)
export let MIR_ACTION = null;       // Enum.cs MirAction
export let MAGIC = null;            // Enum.cs MagicType (name→value)
export let FRAME_FORMULAS = null;   // 原始 JSON (调试/对照面板)

let _loading = null;
export async function ensureLoaded() {
  if (FRAME_FORMULAS) return;
  if (_loading) return _loading;
  _loading = (async () => {
    let j;
    if (typeof location !== 'undefined') {
      // 浏览器: serve.py /frame-formulas.json
      const r = await fetch('/frame-formulas.json');
      if (!r.ok) throw new Error(`frame-formulas.json HTTP ${r.status}`);
      j = await r.json();
    } else {
      // node (测试脚本/工具): 直接读仓库内文件
      const { readFile } = await import('node:fs/promises');
      j = JSON.parse(await readFile(
        new URL('../../../resedit/frame-formulas.json', import.meta.url), 'utf8'));
    }
    PLAYERS = table(j.frameSets.players);
    DEFAULT_MONSTER = table(j.frameSets.defaultMonster);
    DEFAULT_NPC = table(j.frameSets.defaultNPC);
    DEFAULT_ITEM = table(j.frameSets.defaultItem);
    NPC_SPECIAL = new Map(Object.entries(j.npcSpecial).map(([img, tbl]) => {
      const e = tbl.standing;
      return [+img, e.static === true ? { single: true }
        : { start: e.start, count: e.count, ms: e.ms }];
    }));
    MIR_ACTION = j.enums.mirAction;
    MAGIC = j.magicTypes;
    FRAME_FORMULAS = j;
  })();
  return _loading;
}

// MirClass (Enum.cs:12, 本 fork 4 职业; Archer=4 为上游兼容别名)
export const CLASS_WARRIOR = 0, CLASS_WIZARD = 1, CLASS_TAOIST = 2,
  CLASS_ASSASSIN = 3, CLASS_ARCHER = 4;

// ---- GetAttackAnimation (Functions.cs:119-190) — JSON attackDispatch.rules 求值 ----
export function getAttackAnimation(cls, weaponShape, magicType = 0) {
  const byWeapon = (chain) => {
    for (const r of chain) if (weaponShape >= r.min) return r.anim;
    return chain[chain.length - 1].anim;
  };
  for (const rule of FRAME_FORMULAS.attackDispatch.rules) {
    if (rule.magics && !rule.magics.some((n) => MAGIC[n] === magicType)) continue;
    switch (rule.type) {
      case 'group': return rule.anim;
      case 'groupWeapon': return byWeapon(rule.byWeapon);
      case 'classWeapon': if (cls === CLASS_ASSASSIN) return byWeapon(rule.byWeapon); break;
      case 'default': return rule.anim;
    }
  }
  return 'combat3';  // 不可达 (rules 必含 default)
}

// ---- GetMagicAnimation (Functions.cs:185-346) — JSON magicDispatch.groups 求值 ----
export function getMagicAnimation(magicType) {
  for (const g of FRAME_FORMULAS.magicDispatch.groups)
    if (g.magics.some((n) => MAGIC[n] === magicType)) return g.anim;
  return 'combat1'; // C# default: NotImplementedException; Godot 容错 Combat1 (PlayerRenderer.cs:322-323)
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
export function armourShift(animName, isAssassin) {
  return isAssassin ? (FRAME_FORMULAS.armourShift[animName] ?? 0) : 0;
}

// 施法释放延迟 = 前 min(3, count-1) 帧 Delays 之和 (PlayerRenderer.cs:98-133)
export function spellReleaseDelayMs(frame) {
  let sum = 0;
  for (let i = 0; i < Math.min(3, frame.count - 1); i++) sum += frame.delays[i];
  return sum;
}
