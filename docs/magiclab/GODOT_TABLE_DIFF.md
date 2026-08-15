# Godot MagicEffectTable 对账报告
事实源：原版 `Client/Models/MapObject.cs` 两段 Spell switch（release :768 + start :3603）→ `magic-effect-table.json`；对照 `GodotClient/Scripts/MagicEffectTable.cs`。比对口径：每技能特效 (lib, StartIndex, FrameCount) 三元组集合（跨施法/弹道/命中/地面段合并去重）。

- 原版 switch 技能数: **138**（玩家 119 + 怪物 19）
- Godot `_table` 条目: **141**；`OriginalSpellCases` 白名单: **90**
- 共有技能: 131，其中三元组 (lib,frame,count) 完全一致: **120**
- 参数错配技能: **11**

## A. Godot 完全缺失的玩家技能（原版有特效、Godot 表无条目）

- CrushingWave（Combat3）
- FrostBite（Combat2）
- Rake（Combat5）
- SeismicSlam（Combat3）
- Spiritualism（Combat15）

## B. Godot 有、原版 Spell switch 没有的条目（非 Spell 语义或已失源）

- Assault
- AugmentCelestialLight
- DestructiveSurge
- FlameSplash
- FlamingSword
- HalfMoon
- HundredFist
- MonsterDeathCloud
- PoisonousCloud
- Swordsmanship

## C. 白名单 `OriginalSpellCases` vs 原版 switch 的口径差

- 白名单多出（switch 无此 case）: ['Assault', 'HundredFist']
- 玩家技能在 switch 有特效但白名单未收录: ['Abyss', 'Beckon', 'Cloak', 'Concentration', 'Containment', 'CrushingWave', 'CursedDoll', 'Defiance', 'DragonRepulse', 'Endurance', 'Evasion', 'Fetter', 'FireWall', 'FlashOfLight', 'FrostBite', 'GeoManipulation', 'Interchange', 'Invincibility', 'Invisibility', 'MagicShield', 'MassBeckon', 'Might', 'MirrorImage', 'RagingWind', 'Rake', 'ReflectDamage', 'Renounce', 'Repulsion', 'SeismicSlam', 'Spiritualism', 'SummonDead', 'SummonDemonicCreature', 'SummonJinSkeleton', 'SummonPuppet', 'SummonShinsu', 'SummonSkeleton', 'SuperiorMagicShield', 'Teleportation', 'Tempest', 'TheNewBeginning', 'ThunderKick', 'Tornado', 'Transparency']

## D. 共有技能的特效参数错配明细

### AdamantineFireBall
- 原版有 Godot 无: Magic #1640 ×6
- 原版有 Godot 无: Magic #1800 ×10
- Godot 有原版无: Magic #420 ×5
- Godot 有原版无: Magic #580 ×10
- 判读: ❌ Godot 抄错：Godot 条目复用了 FireBall 的 420/580，原版 AdamantineFireBall 与 FireBounce/MeteorShower 共用 1640 弹道 + 1800 命中（MapObject.cs:1040 fall-through 组）
### AugmentPoisonDust
- Godot 有原版无: Magic #60 ×10
- 判读: ⚠️ Godot 补画：原版 start 段无 AugmentPoisonDust case（MapObject.cs:4264 只有 PoisonDust 60×10），Godot 复制了 PoisonDust 起手
### DoomClawLeftPinch
- 原版有 Godot 无: MonMagicEx19 #2680 ×9
- 判读: ⚠️ Godot 缺第二段：原版 CompleteAction 里 2680×9 横扫
### DoomClawRightPinch
- 原版有 Godot 无: MonMagicEx19 #2680 ×9
- 判读: ⚠️ Godot 缺第二段：同上
### GreenSludgeBall
- 原版有 Godot 无: MonMagicEx23 #2780 ×6
- 判读: ⚠️ Godot 缺命中段：原版 2780×6（MapObject.cs CompleteAction）
### ImprovedExplosiveTalisman
- Godot 有原版无: Magic #980 ×6
- 判读: ❌ Godot 库选错：原版起手是 MagicEx2#980（MapObject.cs start 段），Godot Source 写成 Magic#980
### MonsterScortchedEarth
- 原版有 Godot 无: Magic #2450 + CEnvir.Random.Next(5) * 10 ×10
- Godot 有原版无: Magic #2450 ×10
- 判读: ≈ 可接受：同 ScortchedEarth（随机帧）
### ScortchedEarth
- 原版有 Godot 无: Magic #2450 + CEnvir.Random.Next(5) * 10 ×10
- Godot 有原版无: Magic #2450 ×10
- 判读: ≈ 可接受：原版第二段为动态随机帧 2450+Random(5)*10（MapObject.cs:1219），Godot 固定 2450；Godot 未实现 ProgUse#220 地面标记与 1900×30 火墙段
### SummonJinSkeleton
- 原版有 Godot 无: Magic #740 ×10
- Godot 有原版无: Magic #750 ×10
- 判读: ❌ 帧号错：同上，原版 740，Godot 750
### SummonSkeleton
- 原版有 Godot 无: Magic #740 ×10
- Godot 有原版无: Magic #750 ×10
- 判读: ❌ 帧号错：原版 start 740×10，Godot 用 750
### ThunderStrike
- Godot 有原版无: Magic #1430 ×12
- 判读: ⚠️ Godot 补画：原版 start 段 ThunderStrike 只播音效无特效（MapObject.cs:4159），Godot 把 ThunderBolt 的 1430 起手也给了它

## 判读指南

- A/C 类 = Godot 端缺视觉（游戏内表现为无特效/诊断日志）
- D 类 = Godot 端帧号/帧数/库选错（游戏内表现为特效错乱——用户主诉）
- 怪物技能（Monster*/Sama*/DoomClaw*）原版由怪物分支处理，此处只对玩家技能判缺失

_source: /home/tetsuya/development/zircon/GodotClient/Scripts/MagicEffectTable.cs_
_json: /home/tetsuya/development/zircon/Client/Models/MapObject.cs_
