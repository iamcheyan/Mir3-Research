// anims.js — MirAction(17) → MirAnimation(47) 全分派 (par-anim 路)
// 逐行移植: Client/Models/PlayerObject.cs:578-803 (SetAnimation/SetFrame),
// Functions.cs:119-190 (GetAttackAnimation), Functions.cs:185-346 (GetMagicAnimation,
// 后者经 frames.js)。Godot 等价入口: GodotClient/Scripts/PlayerRenderer.cs:246-578。
//
// 用法 (world.js 胶水):
//   import { AnimAction, PlayerAnimState } from './anims.js';
//   const st = new PlayerAnimState(player);      // 包装 world.js PlayerObject
//   st.apply(new AnimAction(MIR_ACTION.Spell, dir, {x,y}, [magicType]));
//
// 与 world.js 现有 per-call setAnimation 相比, 本模块是唯一权威分派层:
// 包驱动事件 → AnimAction → selectAnimation() → anim 名称 (PLAYERS 表键)。

import {
  MIR_ACTION, MAGIC, getAttackAnimation, getMagicAnimation, PLAYERS,
} from './frames.js';

// ---- BuffType (Enum.cs:216-317) — 动画相关的 4 个 ----
export const BUFF_CLOAK = 404;            // 潜行
export const BUFF_ELEMENTAL_HURRICANE = 203; // 元素风暴 (引导)
export const BUFF_GHOST_WALK = 405;     // 鬼步 (潜行快走)
export const BUFF_DRAGON_REPULSE = 408; // 龙威压制
// ---- FishingState / TamingState (Enum.cs:2213-2226) ----
export const FISHING_NONE = 0, FISHING_CAST = 1, FISHING_REEL = 2, FISHING_CANCEL = 3;
export const TAMING_NONE = 0, TAMING_CAST = 1, TAMING_CANCEL = 2;

// ---- 动画名常量 (MirAnimation 47 种中玩家可用的 46 种; Skeleton 仅怪物) ----
export const ANIM = Object.freeze({
  Standing: 'standing', Walking: 'walking', CreepStanding: 'creepStanding',
  CreepWalkSlow: 'creepWalkSlow', CreepWalkFast: 'creepWalkFast', Running: 'running',
  Pushed: 'pushed',
  Combat1: 'combat1', Combat2: 'combat2', Combat3: 'combat3', Combat4: 'combat4',
  Combat5: 'combat5', Combat6: 'combat6', Combat7: 'combat7', Combat8: 'combat8',
  Combat9: 'combat9', Combat10: 'combat10', Combat11: 'combat11', Combat12: 'combat12',
  Combat13: 'combat13', Combat14: 'combat14', Combat15: 'combat15',
  Harvest: 'harvest', Stance: 'stance', Struck: 'struck', Die: 'die', Dead: 'dead',
  Show: 'show', Hide: 'hide',
  HorseStanding: 'horseStanding', HorseWalking: 'horseWalking',
  HorseRunning: 'horseRunning', HorseStruck: 'horseStruck',
  StoneStanding: 'stoneStanding',
  DragonRepulseStart: 'dragonRepulseStart', DragonRepulseMiddle: 'dragonRepulseMiddle',
  DragonRepulseEnd: 'dragonRepulseEnd',
  ChannellingStart: 'channellingStart', ChannellingMiddle: 'channellingMiddle',
  ChannellingEnd: 'channellingEnd',
  FishingCast: 'fishingCast', FishingWait: 'fishingWait', FishingReel: 'fishingReel',
  TamingCast: 'tamingCast', TamingWait: 'tamingWait',
});

// 一次性动作 (PlayerRenderer.cs:281-289): 播完回 Standing/状态站立
export const ONE_SHOT_ANIMS = new Set([
  ANIM.Combat1, ANIM.Combat2, ANIM.Combat3, ANIM.Combat4, ANIM.Combat5,
  ANIM.Combat6, ANIM.Combat7, ANIM.Combat8, ANIM.Combat9, ANIM.Combat10,
  ANIM.Combat11, ANIM.Combat12, ANIM.Combat13, ANIM.Combat14, ANIM.Combat15,
  ANIM.Struck, ANIM.Pushed, ANIM.Harvest, ANIM.FishingCast, ANIM.FishingReel,
  ANIM.TamingCast, ANIM.ChannellingStart, ANIM.ChannellingEnd,
  ANIM.DragonRepulseStart, ANIM.DragonRepulseEnd, ANIM.Die, ANIM.Dead,
  ANIM.Show, ANIM.Hide,
]);
// 播完保持 (不回 Standing): 死亡 / 持续施法中段 / 龙威中段 / 钓鱼等待 / 驯兽等待
export const KEEP_ANIMS = new Set([
  ANIM.Die, ANIM.Dead, ANIM.ChannellingMiddle, ANIM.DragonRepulseMiddle,
  ANIM.FishingWait, ANIM.TamingWait,
]);

// ---- AnimAction: ObjectAction.cs 的 JS 化 ----
// action=MIR_ACTION.*, direction=0..7, location={x,y}, extra=[] (对齐 C# Extra[])
export class AnimAction {
  constructor(action, direction, location, extra = []) {
    this.action = action;
    this.direction = direction;
    this.location = location;
    this.extra = extra;
  }
}

// ====================================================================
// PlayerAnimState — 逐行移植 PlayerObject.SetAnimation/SetFrame 状态
// ====================================================================
// 字段对照 (C# PlayerObject / Godot PlayerRenderer):
//   stanceTimeMs     StanceTime / _stanceUntilMs      (Attack/Spell 后 3s)
//   currentAnimation CurrentAnimation / Animation
//   drawWeapon       DrawWeapon (PoisonousCloud 施法隐藏武器)
//   fishingState     FishingState, tamingState        TamingState
//   horse            Horse (HorseType)
//   buffs            VisibleBuffs (Set<BuffType>)
export class PlayerAnimState {
  constructor() {
    this.currentAnimation = ANIM.Standing;
    this.stanceTimeMs = 0;          // epoch ms; < now → Stance
    this.drawWeapon = true;
    this.fishingState = FISHING_NONE;
    this.tamingState = TAMING_NONE;
    this.horse = 0;                 // HorseType.None
    this.buffs = new Set();         // BuffType 数值
  }

  hasBuff(type) { return this.buffs.has(type); }
  addBuff(type) { this.buffs.add(type); }
  removeBuff(type) { this.buffs.delete(type); }

  // ----------------------------------------------------------------
  // SetAnimation (PlayerObject.cs:578-685) — MirAction → MirAnimation
  // 返回 { anim, drawWeapon }; 未知 action → null (对照 C# throw)
  // ----------------------------------------------------------------
  selectAnimation(action, nowMs) {
    let animation;
    let drawWeapon = true;                       // :581 DrawWeapon = true
    let type;

    switch (action.action) {
      // ---- Standing (:585-605): StanceTime→Stance, Cloak→Creep, Horse,
      //      DragonRepulse 中/尾, ElementalHurricane 引导中段 ----
      case MIR_ACTION.Standing: {
        animation = ANIM.Standing;                                   // :586
        if (nowMs < this.stanceTimeMs) animation = ANIM.Stance;      // :588-589
        if (this.hasBuff(BUFF_CLOAK)) animation = ANIM.CreepStanding; // :591-592
        if (this.horse !== 0) animation = ANIM.HorseStanding;        // :594-595
        // :597-600 龙威: 有 buff → 中段; 刚离开中段 → 尾段
        if (this.hasBuff(BUFF_DRAGON_REPULSE)) animation = ANIM.DragonRepulseMiddle;
        else if (this.currentAnimation === ANIM.DragonRepulseMiddle) animation = ANIM.DragonRepulseEnd;
        // :602-603 引导: 元素风暴持续中 → 引导中段
        if (this.hasBuff(BUFF_ELEMENTAL_HURRICANE)) animation = ANIM.ChannellingMiddle;
        break;
      }

      // ---- Moving (:606-624): 冲锋 Combat8 > 潜行步 > 跑/走 > 骑马 ----
      case MIR_ACTION.Moving: {
        animation = ANIM.Walking;                                    // :609
        if (this.horse !== 0) animation = ANIM.HorseWalking;         // :611-612
        const moveMagic = action.extra[1] ?? 0;                      // (MagicType)action.Extra[1]
        const distance = action.extra[0] ?? 1;                       // (int)action.Extra[0]
        if (moveMagic === MAGIC.ShoulderDash || moveMagic === MAGIC.Assault)
          animation = ANIM.Combat8;                                  // :614-615
        else if (this.hasBuff(BUFF_CLOAK))
          animation = this.hasBuff(BUFF_GHOST_WALK) ? ANIM.CreepWalkFast : ANIM.CreepWalkSlow; // :616-617
        else if (distance >= 2) {                                    // :618-623
          animation = this.horse !== 0 ? ANIM.HorseRunning : ANIM.Running;
        }
        break;
      }

      case MIR_ACTION.Pushed:                                        // :625-627
        animation = ANIM.Pushed;
        break;

      // ---- Attack (:628-631): GetAttackAnimation(Class, WeaponShape, Magic) ----
      case MIR_ACTION.Attack: {
        type = action.extra[1] ?? 0;                                 // :629
        animation = getAttackAnimation(action.cls ?? 0, action.weaponShape ?? 0, type);
        break;
      }

      // ---- Mining (:632-634): 攻击动作, MagicType.None ----
      case MIR_ACTION.Mining:
        animation = getAttackAnimation(action.cls ?? 0, action.weaponShape ?? 0, 0);
        break;

      // ---- Fishing (:635-642): Cast↔Wait 状态机, Reel 仅从 Wait ----
      case MIR_ACTION.Fishing: {
        const state = action.extra[0] ?? FISHING_NONE;               // :636
        if (state === FISHING_CAST)
          animation = (this.currentAnimation === ANIM.FishingWait
            || this.currentAnimation === ANIM.FishingCast)
            ? ANIM.FishingWait : ANIM.FishingCast;                   // :638-639
        else
          animation = this.currentAnimation === ANIM.FishingWait
            ? ANIM.FishingReel : ANIM.Standing;                      // :640-641
        this.fishingState = state === FISHING_REEL ? FISHING_NONE : state; // MapObject.cs:3232-3233
        break;
      }

      // ---- Taming (:643-648): Cast→Wait 保持 ----
      case MIR_ACTION.Taming: {
        if (this.currentAnimation === ANIM.TamingCast
          || this.currentAnimation === ANIM.TamingWait)
          animation = ANIM.TamingWait;                               // :644-645
        else
          animation = ANIM.TamingCast;                               // :646-647
        this.tamingState = action.extra[0] ?? TAMING_NONE;
        break;
      }

      // ---- RangeAttack (:649-651): 弓手恒 Combat1 ----
      case MIR_ACTION.RangeAttack:
        animation = ANIM.Combat1;
        break;

      // ---- Spell (:652-663): GetMagicAnimation; 毒云藏武器; 引导收尾 ----
      case MIR_ACTION.Spell: {
        type = action.extra[0] ?? 0;                                 // :653
        animation = getMagicAnimation(type);                         // :655
        if (type === MAGIC.PoisonousCloud) drawWeapon = false;       // :657-658
        if (this.hasBuff(BUFF_ELEMENTAL_HURRICANE)) animation = ANIM.ChannellingEnd; // :660-661
        break;
      }

      // ---- Struck (:664-668): 骑马被击 ----
      case MIR_ACTION.Struck:
        animation = ANIM.Struck;
        if (this.horse !== 0) animation = ANIM.HorseStruck;
        break;

      case MIR_ACTION.Die:                                           // :669-671
        animation = ANIM.Die;
        break;
      case MIR_ACTION.Dead:                                          // :672-674
        animation = ANIM.Dead;
        break;
      case MIR_ACTION.Harvest:                                       // :675-677
        animation = ANIM.Harvest;
        break;

      // Show/Hide (怪物图库专属; 玩家缺表回退 Standing — FrameSet.Players 无此键)
      case MIR_ACTION.Show:
        animation = PLAYERS[ANIM.Show] ? ANIM.Show : ANIM.Standing;
        break;
      case MIR_ACTION.Hide:
        animation = PLAYERS[ANIM.Hide] ? ANIM.Hide : ANIM.Standing;
        break;

      // Mount: 无独立动画 — C# Process(S.ObjectMount) 直接改 Horse 后走 Standing 分支
      // (CConnection.cs:1045-1067); Idle: MapObject 怪物分支, 玩家回 Standing。
      case MIR_ACTION.Mount:
      case MIR_ACTION.Idle:
        animation = this.selectAnimation(new AnimAction(MIR_ACTION.Standing, action.direction, action.location), nowMs).anim;
        break;

      default:
        return null;   // ArgumentOutOfRangeException (:678-679)
    }

    return { anim: animation, drawWeapon };
  }

  // ----------------------------------------------------------------
  // SetFrame (PlayerObject.cs:687-803) — 施法/攻击后 StanceTime = +3s
  // ----------------------------------------------------------------
  // 返回 selectAnimation 结果; 调用方负责把 anim 写进渲染对象。
  apply(action, nowMs) {
    const sel = this.selectAnimation(action, nowMs);
    if (!sel) return null;
    this.currentAnimation = sel.anim;
    this.drawWeapon = sel.drawWeapon;
    // :691-697 — Attack/Spell 结束后 3 秒战斗站姿
    if (action.action === MIR_ACTION.Spell || action.action === MIR_ACTION.Attack) {
      this.stanceTimeMs = nowMs + 3000;
    }
    // Dash (冲锋) 也刷新 StanceTime (CConnection.cs:1229)
    if (action.action === MIR_ACTION.Moving
      && (action.extra[1] === MAGIC.ShoulderDash || action.extra[1] === MAGIC.Assault)) {
      this.stanceTimeMs = nowMs + 3000;
    }
    return sel;
  }
}

// ----------------------------------------------------------------
// 便捷入口: 各 S.Object* 包 → AnimAction (CConnection.cs 各 Process)
// 对照 Godot GameScene.cs 同名 On* 处理器。
// ----------------------------------------------------------------
export function actionFromAttack(p)       // S.ObjectAttack → Attack {target, magic, element}
  { return new AnimAction(MIR_ACTION.Attack, p.direction, p.location, [p.targetID ?? 0, p.attackMagic ?? 0, p.attackElement ?? 0]); }
export function actionFromMining(p)       // S.ObjectMining → Mining {effect}
  { return new AnimAction(MIR_ACTION.Mining, p.direction, p.location, [p.effect ?? false]); }
export function actionFromFishing(p)      // S.ObjectFishing → Fishing {state, float, found}
  { return new AnimAction(MIR_ACTION.Fishing, p.direction, p.location, [p.state ?? 0, p.floatLocation, p.fishFound ?? false]); }
export function actionFromTaming(p)       // S.ObjectTaming → Taming {state, targetID}
  { return new AnimAction(MIR_ACTION.Taming, p.direction, p.location, [p.state ?? 0, p.tamingObjectID ?? 0]); }
export function actionFromRangeAttack(p)  // S.ObjectRangeAttack → RangeAttack {targets, magic, element}
  { return new AnimAction(MIR_ACTION.RangeAttack, p.direction, p.location, [p.targets ?? [], p.attackMagic ?? 0, p.attackElement ?? 0]); }
export function actionFromMagic(p)        // S.ObjectMagic → Spell {type} (Extra[0] = MagicType)
  { return new AnimAction(MIR_ACTION.Spell, p.direction, p.location, [p.type ?? 0]); }
export function actionFromMove(p)         // S.ObjectMove → Moving {distance, magic}
  { return new AnimAction(MIR_ACTION.Moving, p.direction, { x: p.x, y: p.y }, [p.distance ?? 1, 0]); }
export function actionFromDash(p)         // S.ObjectDash → Moving {1, magic} + StanceTime
  { return new AnimAction(MIR_ACTION.Moving, p.direction, p.location, [1, p.magic ?? 0]); }
export function actionFromPushed(p)       // S.ObjectPushed → Pushed
  { return new AnimAction(MIR_ACTION.Pushed, p.direction, p.location); }
export function actionFromStruck(p)       // S.ObjectStruck → Struck {attacker, element}
  { return new AnimAction(MIR_ACTION.Struck, p.direction, p.location, [p.attackerID ?? 0, p.element ?? 0]); }
export function actionFromHarvest(p)      // S.ObjectHarvest → Harvest
  { return new AnimAction(MIR_ACTION.Harvest, p.direction, p.location); }
