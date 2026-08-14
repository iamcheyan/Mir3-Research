// test-anims.mjs — par-anim 全分派审计 (node Tools/webport/scripts/test-anims.mjs)
// 覆盖: 17 MirAction × 状态矩阵 (骑马/潜行/引导/龙威/钓鱼/驯兽/StanceTime/冲锋/武器shape)
// 依据: Client/Models/PlayerObject.cs:578-803, Functions.cs:119-346, Enum.cs, CConnection.cs
import { AnimAction, PlayerAnimState, ANIM, BUFF_CLOAK, BUFF_GHOST_WALK,
  BUFF_ELEMENTAL_HURRICANE, BUFF_DRAGON_REPULSE, FISHING_CAST, FISHING_REEL, TAMING_CAST,
  actionFromAttack, actionFromMining, actionFromFishing, actionFromTaming, actionFromRangeAttack,
  actionFromMagic, actionFromMove, actionFromDash, actionFromPushed, actionFromStruck,
  actionFromHarvest } from '../static/js/anims.js';
import { MIR_ACTION, MAGIC, CLASS_WARRIOR, CLASS_ASSASSIN } from '../static/js/frames.js';

const NOW = 1_000_000; const A = MIR_ACTION;
let pass = 0, fail = 0;
function t(name, got, want) { if (got === want) pass++; else { fail++; console.log('FAIL', name, '→ got', got, 'want', want); } }
function st(mods = {}) { const s = new PlayerAnimState(); Object.assign(s, mods); return s; }
const sel = (s, a) => s.selectAnimation(a, NOW)?.anim;

// Standing 状态阶梯 (:585-605)
t('Standing/base', sel(st(), new AnimAction(A.Standing, 0, {})), ANIM.Standing);
t('Standing/stance<3s', sel(st({ stanceTimeMs: NOW + 2000 }), new AnimAction(A.Standing, 0, {})), ANIM.Stance);
t('Standing/stance过期', sel(st({ stanceTimeMs: NOW - 1 }), new AnimAction(A.Standing, 0, {})), ANIM.Standing);
{ const s = st({ stanceTimeMs: NOW + 2000 }); s.addBuff(BUFF_CLOAK);
  t('Standing/cloak>stance', sel(s, new AnimAction(A.Standing, 0, {})), ANIM.CreepStanding); }
{ const s = st({ stanceTimeMs: NOW + 2000 }); s.addBuff(BUFF_CLOAK); s.horse = 1;
  t('Standing/horse>cloak', sel(s, new AnimAction(A.Standing, 0, {})), ANIM.HorseStanding); }
{ const s = st(); s.addBuff(BUFF_DRAGON_REPULSE);
  t('Standing/drMiddle', sel(s, new AnimAction(A.Standing, 0, {})), ANIM.DragonRepulseMiddle);
  const s2 = st(); s2.currentAnimation = ANIM.DragonRepulseMiddle;
  t('Standing/drEnd-after-middle', sel(s2, new AnimAction(A.Standing, 0, {})), ANIM.DragonRepulseEnd); }
{ const s = st(); s.addBuff(BUFF_ELEMENTAL_HURRICANE);
  t('Standing/channellingMiddle', sel(s, new AnimAction(A.Standing, 0, {})), ANIM.ChannellingMiddle); }

// Moving (:606-624)
t('Moving/walk', sel(st(), new AnimAction(A.Moving, 0, {}, [1, 0])), ANIM.Walking);
t('Moving/run dist2', sel(st(), new AnimAction(A.Moving, 0, {}, [2, 0])), ANIM.Running);
t('Moving/horseWalk', sel(st({ horse: 1 }), new AnimAction(A.Moving, 0, {}, [1, 0])), ANIM.HorseWalking);
t('Moving/horseRun', sel(st({ horse: 1 }), new AnimAction(A.Moving, 0, {}, [2, 0])), ANIM.HorseRunning);
t('Moving/dash=Combat8', sel(st(), new AnimAction(A.Moving, 0, {}, [2, MAGIC.ShoulderDash])), ANIM.Combat8);
t('Moving/assault=Combat8', sel(st(), new AnimAction(A.Moving, 0, {}, [2, MAGIC.Assault])), ANIM.Combat8);
{ const s = st(); s.addBuff(BUFF_CLOAK);
  t('Moving/cloak=slow', sel(s, new AnimAction(A.Moving, 0, {}, [2, 0])), ANIM.CreepWalkSlow);
  s.addBuff(BUFF_GHOST_WALK);
  t('Moving/ghostwalk=fast', sel(s, new AnimAction(A.Moving, 0, {}, [2, 0])), ANIM.CreepWalkFast); }

// Attack/Mining (Functions.GetAttackAnimation)
t('Attack/warrior basic', sel(st(), new AnimAction(A.Attack, 0, {}, [0, 0, 0])), ANIM.Combat3);
{ const a = new AnimAction(A.Attack, 0, {}, [0, MAGIC.Slaying, 0]); a.cls = CLASS_WARRIOR;
  t('Attack/Slaying', sel(st(), a), ANIM.Combat3); }
{ const a = new AnimAction(A.Attack, 0, {}, [0, MAGIC.HalfMoon, 0]); t('Attack/HalfMoon', sel(st(), a), ANIM.Combat4); }
{ const a = new AnimAction(A.Attack, 0, {}, [0, MAGIC.DragonRise, 0]); t('Attack/DragonRise', sel(st(), a), ANIM.Combat5); }
{ const a = new AnimAction(A.Attack, 0, {}, [0, MAGIC.BladeStorm, 0]); t('Attack/BladeStorm', sel(st(), a), ANIM.Combat6); }
{ const a = new AnimAction(A.Attack, 0, {}, [0, MAGIC.FullBloom, 0]); a.weaponShape = 1250;
  t('Attack/FullBloom-1250', sel(st(), a), ANIM.Combat13);
  a.weaponShape = 1150; t('Attack/FullBloom-1150', sel(st(), a), ANIM.Combat5);
  a.weaponShape = 100;  t('Attack/FullBloom-100', sel(st(), a), ANIM.Combat3); }
{ const a = new AnimAction(A.Attack, 0, {}, [0, MAGIC.SweetBrier, 0]); a.cls = CLASS_ASSASSIN;
  a.weaponShape = 1250; t('Attack/SweetBrier-1250', sel(st(), a), ANIM.Combat12);
  a.weaponShape = 1150; t('Attack/SweetBrier-1150', sel(st(), a), ANIM.Combat10);
  a.weaponShape = 100;  t('Attack/SweetBrier-100', sel(st(), a), ANIM.Combat3); }
{ const a = new AnimAction(A.Attack, 0, {}, [0, 0, 0]); a.cls = CLASS_ASSASSIN;
  a.weaponShape = 1250; t('Attack/assassin-default-1250', sel(st(), a), ANIM.Combat11);
  a.weaponShape = 1150; t('Attack/assassin-default-1150', sel(st(), a), ANIM.Combat4);
  a.weaponShape = 100;  t('Attack/assassin-default-100', sel(st(), a), ANIM.Combat3); }
t('Mining', sel(st(), new AnimAction(A.Mining, 0, {}, [false])), ANIM.Combat3);

// Fishing (:635-642)
t('Fishing/first-cast', sel(st(), new AnimAction(A.Fishing, 0, {}, [FISHING_CAST, null, false])), ANIM.FishingCast);
{ const s = st(); s.currentAnimation = ANIM.FishingCast;
  t('Fishing/recast→Wait', sel(s, new AnimAction(A.Fishing, 0, {}, [FISHING_CAST, null, false])), ANIM.FishingWait);
  s.currentAnimation = ANIM.FishingWait;
  t('Fishing/wait-cast→Wait', sel(s, new AnimAction(A.Fishing, 0, {}, [FISHING_CAST, null, false])), ANIM.FishingWait);
  t('Fishing/reel-from-wait', sel(s, new AnimAction(A.Fishing, 0, {}, [FISHING_REEL, null, false])), ANIM.FishingReel);
  const s2 = st(); s2.currentAnimation = ANIM.Standing;
  t('Fishing/cancel-from-standing', sel(s2, new AnimAction(A.Fishing, 0, {}, [FISHING_REEL, null, false])), ANIM.Standing); }

// Taming (:643-648)
t('Taming/first', sel(st(), new AnimAction(A.Taming, 0, {}, [TAMING_CAST, 5])), ANIM.TamingCast);
{ const s = st(); s.currentAnimation = ANIM.TamingCast;
  t('Taming/cast→Wait', sel(s, new AnimAction(A.Taming, 0, {}, [TAMING_CAST, 5])), ANIM.TamingWait);
  s.currentAnimation = ANIM.TamingWait;
  t('Taming/wait→Wait', sel(s, new AnimAction(A.Taming, 0, {}, [TAMING_CAST, 5])), ANIM.TamingWait); }

// RangeAttack/Spell/Struck/Die/Dead/Harvest/Show/Hide/Mount/Idle
t('RangeAttack', sel(st(), new AnimAction(A.RangeAttack, 0, {}, [[], 0, 0])), ANIM.Combat1);
t('Spell/FireBall', sel(st(), new AnimAction(A.Spell, 0, {}, [MAGIC.FireBall])), ANIM.Combat1);
t('Spell/Heal', sel(st(), new AnimAction(A.Spell, 0, {}, [MAGIC.Heal])), ANIM.Combat2);
t('Spell/ElementalHurricane', sel(st(), new AnimAction(A.Spell, 0, {}, [MAGIC.ElementalHurricane])), ANIM.ChannellingStart);
{ const s = st(); s.addBuff(BUFF_ELEMENTAL_HURRICANE);
  t('Spell/hurricane-end', sel(s, new AnimAction(A.Spell, 0, {}, [MAGIC.ElementalHurricane])), ANIM.ChannellingEnd); }
{ const r = st().selectAnimation(new AnimAction(A.Spell, 0, {}, [MAGIC.PoisonousCloud]), NOW);
  t('Spell/PoisonousCloud anim', r.anim, ANIM.Combat14);
  t('Spell/PoisonousCloud hideWeapon', r.drawWeapon, false); }
t('Struck', sel(st(), new AnimAction(A.Struck, 0, {})), ANIM.Struck);
t('Struck/horse', sel(st({ horse: 2 }), new AnimAction(A.Struck, 0, {})), ANIM.HorseStruck);
t('Die', sel(st(), new AnimAction(A.Die, 0, {})), ANIM.Die);
t('Dead', sel(st(), new AnimAction(A.Dead, 0, {})), ANIM.Dead);
t('Harvest', sel(st(), new AnimAction(A.Harvest, 0, {})), ANIM.Harvest);
t('Show fallback', sel(st(), new AnimAction(A.Show, 0, {})), ANIM.Standing);
t('Hide fallback', sel(st(), new AnimAction(A.Hide, 0, {})), ANIM.Standing);
t('Mount→standing', sel(st({ horse: 1 }), new AnimAction(A.Mount, 0, {})), ANIM.HorseStanding);
t('Idle→standing', sel(st(), new AnimAction(A.Idle, 0, {})), ANIM.Standing);
t('unknown→null', st().selectAnimation(new AnimAction(99, 0, {}), NOW), null);

// StanceTime (:691-697) + Dash (CConnection.cs:1229)
{ const s = st(); s.apply(new AnimAction(A.Attack, 0, {}), NOW); t('StanceTime after attack', s.stanceTimeMs, NOW + 3000); }
{ const s = st(); s.apply(new AnimAction(A.Spell, 0, {}, [MAGIC.FireBall]), NOW); t('StanceTime after spell', s.stanceTimeMs, NOW + 3000); }
{ const s = st(); s.apply(new AnimAction(A.Struck, 0, {}), NOW); t('no StanceTime after struck', s.stanceTimeMs, 0); }
{ const s = st(); s.apply(new AnimAction(A.Moving, 0, {}, [2, MAGIC.ShoulderDash]), NOW); t('StanceTime after dash', s.stanceTimeMs, NOW + 3000); }

// 包→AnimAction 入口 (CConnection.cs Process 各处理器)
t('fromAttack magic', actionFromAttack({ direction: 2, location: {}, targetID: 7, attackMagic: MAGIC.Slaying }).extra[1], MAGIC.Slaying);
t('fromMagic type', actionFromMagic({ direction: 2, location: {}, type: MAGIC.Heal }).action, A.Spell);
t('fromFishing state', actionFromFishing({ direction: 2, state: 1 }).extra[0], 1);
t('fromTaming', actionFromTaming({ direction: 2, state: 1, tamingObjectID: 9 }).extra[1], 9);
t('fromDash magic', actionFromDash({ direction: 2, location: {}, magic: MAGIC.Assault }).extra[1], MAGIC.Assault);
t('fromMove distance', actionFromMove({ direction: 2, x: 1, y: 1, distance: 2 }).extra[0], 2);
t('fromRangeAttack', actionFromRangeAttack({ direction: 2, location: {}, targets: [1] }).action, A.RangeAttack);
t('fromPushed', actionFromPushed({ direction: 2, location: {} }).action, A.Pushed);
t('fromStruck', actionFromStruck({ direction: 2, location: {}, attackerID: 3, element: 1 }).action, A.Struck);
t('fromHarvest', actionFromHarvest({ direction: 2, location: {} }).action, A.Harvest);
t('fromMining', actionFromMining({ direction: 2, location: {}, effect: true }).action, A.Mining);

console.log(pass + ' passed, ' + fail + ' failed');
process.exit(fail ? 1 : 0);
