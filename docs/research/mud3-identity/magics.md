# Mud3 ↔ Zircon 魔法/技能身份表（magic）

> 只读产出，不改 `System.db` / `db_names.json` / Zircon C#。
> 权威契约见本目录 `README.md` 与 `Zircon/docs/pending/MUD3_CONTENT_AND_LEGACY_BAG_HANDOFF_2026-10-03.md` §1.4。
> 生成：`build_magic_identity.py`（2026-10-03）。Mud3 105 条 / Zircon 174 行。

## 数量（按 confidence）

| confidence | 数量 |
|---|---:|
| closed | 57 |
| pending | 6 |
| missing | 42 |
| zircon-only | 111 |

自检：`closed+pending+missing == 105`，`closed+pending+zircon-only == 174`，`closed` 无重复 `zircon_index`。

## closed（1:1，主证据闭合）

| Mud3 Index | Mud3 中文名 | Zircon Index | Zircon 身份 | 证据 |
|---|---|---:|---|---|
| 1 | 火球术 | 23 | Fire Ball | NeedLevel 三元组 7/9/11 与 Zircon Fire Ball(23) 完全一致；Mud3 sch0 → Zircon Wizard/Fire |
| 2 | 治愈术 | 59 | Heal | NeedLevel 三元组 7/9/11 与 Zircon Heal(59) 完全一致；Mud3 sch4 → Zircon Taoist/Holy |
| 3 | 基本剑术 | 1 | Swordsmanship | NeedLevel 三元组 7/9/11 与 Zircon Swordsmanship(1) 完全一致；Mud3 sch7 → Zircon Warrior/Passive |
| 4 | 精神力战法 | 60 | Spirit Sword | NeedLevel 三元组 8/10/12 与 Zircon Spirit Sword(60) 完全一致；Mud3 sch7 → Zircon Taoist/Physical；Mud3 归战技系，Zircon 归道士 Spirit Sword；跨职业重归类，三元组仍一致 |
| 5 | 大火球 | 30 | Adamantine Fire Ball | NeedLevel 三元组 15/17/19 与 Zircon Adamantine Fire Ball(30) 完全一致；Mud3 sch0 → Zircon Wizard/Fire；Zircon 英文 Adamantine Fire Ball 旧显示名误作金刚火球，官方名为大火球 |
| 6 | 施毒术 | 61 | Poison Dust | NeedLevel 三元组 12/14/16 与 Zircon Poison Dust(61) 完全一致；Mud3 sch5 → Zircon Taoist/Dark |
| 7 | 攻杀剑术 | 3 | Slaying | NeedLevel 三元组 14/16/18 与 Zircon Slaying(3) 完全一致；Mud3 sch7 → Zircon Warrior/Passive |
| 8 | 抗拒火环 | 27 | Repulsion | NeedLevel 三元组 12/14/16 与 Zircon Repulsion(27) 完全一致；Mud3 sch3 → Zircon Wizard/Wind |
| 9 | 地狱火 | 34 | Scorched Earth | NeedLevel 三元组 20/22/24 与 Zircon Scorched Earth(34) 完全一致；Mud3 sch0 → Zircon Wizard/Fire |
| 10 | 疾光电影 | 35 | Lightning Beam | NeedLevel 三元组 21/23/25 与 Zircon Lightning Beam(35) 完全一致；Mud3 sch2 → Zircon Wizard/Lightning |
| 11 | 雷电术 | 31 | Thunder Bolt | NeedLevel 三元组 16/18/20 与 Zircon Thunder Bolt(31) 完全一致；Mud3 sch2 → Zircon Wizard/Lightning |
| 12 | 刺杀剑术 | 4 | Thrusting | NeedLevel 三元组 19/21/23 与 Zircon Thrusting(4) 完全一致；Mud3 sch7 → Zircon Warrior/Toggle |
| 13 | 灵魂火符 | 62 | Explosive Talisman | NeedLevel 三元组 13/15/17 与 Zircon Explosive Talisman(62) 完全一致；Mud3 sch5 → Zircon Taoist/Dark |
| 14 | 幽灵盾 | 65 | Magic Resistance | NeedLevel 三元组 21/23/25 与 Zircon Magic Resistance(65) 完全一致；Mud3 sch5 → Zircon Taoist/Dark |
| 15 | 神圣战甲术 | 68 | Resilience | NeedLevel 三元组 25/27/29 与 Zircon Resilience(68) 完全一致；Mud3 sch5 → Zircon Taoist/Dark |
| 16 | 困魔咒 | 69 | Trap Octagon | NeedLevel 三元组 27/29/31 与 Zircon Trap Octagon(69) 完全一致；Mud3 sch5 → Zircon Taoist/Dark |
| 17 | 召唤骷髅 | 130 | Summon Skeleton | NeedLevel 三元组 17/19/21 与 Zircon Summon Skeleton(130) 完全一致；Mud3 sch6 → Zircon Taoist/Phantom |
| 18 | 隐身术 | 64 | Invisibility | NeedLevel 三元组 20/22/24 与 Zircon Invisibility(64) 完全一致；Mud3 sch5 → Zircon Taoist/Dark |
| 19 | 集体隐身术 | 66 | Mass Invisibility | NeedLevel 三元组 23/25/27 与 Zircon Mass Invisibility(66) 完全一致；Mud3 sch5 → Zircon Taoist/Dark |
| 21 | 瞬息移动 | 29 | Teleportation | NeedLevel 三元组 14/16/18 与 Zircon Teleportation(29) 完全一致；Mud3 sch6 → Zircon Wizard/Phantom |
| 22 | 火墙 | 38 | Fire Wall | NeedLevel 三元组 24/26/28 与 Zircon Fire Wall(38) 完全一致；Mud3 sch0 → Zircon Wizard/Fire |
| 23 | 爆裂火焰 | 42 | Fire Storm | NeedLevel 三元组 32/34/36 与 Zircon Fire Storm(42) 完全一致；Mud3 sch0 → Zircon Wizard/Fire |
| 24 | 地狱雷光 | 43 | Lightning Wave | NeedLevel 三元组 33/35/37 与 Zircon Lightning Wave(43) 完全一致；Mud3 sch2 → Zircon Wizard/Lightning |
| 25 | 半月弯刀 | 5 | Half Moon | NeedLevel 三元组 24/26/28 与 Zircon Half Moon(5) 完全一致；Mud3 sch7 → Zircon Warrior/Toggle |
| 26 | 烈火剑法 | 7 | Flaming Sword | NeedLevel 三元组 32/34/36 与 Zircon Flaming Sword(7) 完全一致；Mud3 sch7 → Zircon Warrior/Active |
| 27 | 野蛮冲撞 | 6 | Shoulder Dash | NeedLevel 三元组 27/29/31 与 Zircon Shoulder Dash(6) 完全一致；Mud3 sch7 → Zircon Warrior/Active |
| 29 | 群体治愈术 | 72 | Mass Heal | NeedLevel 三元组 31/33/35 与 Zircon Mass Heal(72) 完全一致；Mud3 sch4 → Zircon Taoist/Holy |
| 30 | 召唤神兽 | 133 | Summon Shinsu | NeedLevel 三元组 30/32/34 与 Zircon Summon Shinsu(133) 完全一致；Mud3 sch6 → Zircon Taoist/Phantom |
| 31 | 魔法盾 | 41 | Magic Shield | NeedLevel 三元组 29/31/33 与 Zircon Magic Shield(41) 完全一致；Mud3 sch3 → Zircon Wizard/Phantom |
| 33 | 冰咆哮 | 44 | Ice Storm | NeedLevel 三元组 34/36/38 与 Zircon Ice Storm(44) 完全一致；Mud3 sch1 → Zircon Wizard/Ice |
| 34 | 莲月剑法 | 9 | Blade Storm | NeedLevel 三元组 38/40/42 与 Zircon Blade Storm(9) 完全一致；Mud3 sch7 → Zircon Warrior/Active |
| 35 | 翔空剑法 | 8 | Dragon Rise | NeedLevel 三元组 35/37/39 与 Zircon Dragon Rise(8) 完全一致；Mud3 sch7 → Zircon Warrior/Active；Zircon 英文 Dragon Rise 旧显示名误作龙影剑法，官方名为翔空剑法 |
| 36 | 空拳刀法 | 70 | Combat Kick | NeedLevel 三元组 28/30/32 与 Zircon Combat Kick(70) 完全一致；Mud3 sch7 → Zircon Taoist/Physical；Mud3 归战技系，Zircon 归道士 Combat Kick；跨职业重归类，三元组仍一致 |
| 37 | 月魂断玉 | 63 | Evil Slayer | NeedLevel 三元组 14/16/18 与 Zircon Evil Slayer(63) 完全一致；Mud3 sch4 → Zircon Taoist/Holy |
| 38 | 月魂灵波 | 67 | Greater Evil Slayer | NeedLevel 三元组 24/26/28 与 Zircon Greater Evil Slayer(67) 完全一致；Mud3 sch4 → Zircon Taoist/Holy |
| 39 | 冰月神掌 | 25 | Ice Bolt | NeedLevel 三元组 9/11/13 与 Zircon Ice Bolt(25) 完全一致；Mud3 sch1 → Zircon Wizard/Ice |
| 40 | 冰月震天 | 32 | Ice Blades | NeedLevel 三元组 17/19/21 与 Zircon Ice Blades(32) 完全一致；Mud3 sch1 → Zircon Wizard/Ice |
| 41 | 霹雳掌 | 24 | Lightning Ball | NeedLevel 三元组 8/10/12 与 Zircon Lightning Ball(24) 完全一致；Mud3 sch2 → Zircon Wizard/Lightning |
| 53 | 冰沙掌 | 36 | Frozen Earth | NeedLevel 三元组 22/24/26 与 Zircon Frozen Earth(36) 完全一致；Mud3 sch1 → Zircon Wizard/Ice |
| 67 | 风掌 | 26 | Gust Blast | NeedLevel 三元组 10/12/14 与 Zircon Gust Blast(26) 完全一致；Mud3 sch3 → Zircon Wizard/Wind |
| 72 | 龙卷风 | 45 | Dragon Tornado | NeedLevel 三元组 35/37/39 与 Zircon Dragon Tornado(45) 完全一致；Mud3 sch3 → Zircon Wizard/Wind |
| 73 | 风震天 | 37 | Blow Earth | NeedLevel 三元组 23/25/27 与 Zircon Blow Earth(37) 完全一致；Mud3 sch3 → Zircon Wizard/Wind |
| 74 | 击风 | 33 | Cyclone | NeedLevel 三元组 18/20/22 与 Zircon Cyclone(33) 完全一致；Mud3 sch3 → Zircon Wizard/Wind |
| 77 | 回生术 | 74 | Resurrection | NeedLevel 三元组 35/37/39 与 Zircon Resurrection(74) 完全一致；Mud3 sch4 → Zircon Taoist/Holy |
| 89 | 强魔震法 | 71 | Elemental Superiority | NeedLevel 三元组 29/31/33 与 Zircon Elemental Superiority(71) 完全一致；Mud3 sch5 → Zircon Taoist/Dark |
| 94 | 猛虎强势 | 73 | Blood Lust | NeedLevel 三元组 34/36/38 与 Zircon Blood Lust(73) 完全一致；Mud3 sch5 → Zircon Taoist/Dark |
| 102 | 铁布衫 | 12 | Defiance | NeedLevel 三元组 44/47/50 与 Zircon Defiance(12) 完全一致；Mud3 sch7 → Zircon Warrior/Active |
| 103 | 十方斩 | 10 | Destructive Surge | NeedLevel 三元组 40/43/46 与 Zircon Destructive Surge(10) 完全一致；Mud3 sch7 → Zircon Warrior/Toggle；Zircon 英文 Destructive Surge 旧显示名误作破血狂杀，官方名为十方斩 |
| 105 | 超强召唤骷髅 | 132 | Summon Jin Skeleton | NeedLevel 三元组 33/35/37 与 Zircon Summon Jin Skeleton(132) 完全一致；Mud3 sch6 → Zircon Taoist/Phantom |
| 106 | 破血狂杀 | 14 | Might | NeedLevel 三元组 48/51/54 与 Zircon Might(14) 完全一致；Mud3 sch7 → Zircon Warrior/Active；Zircon 英文 Might 旧显示名误作蛮力，官方名为破血狂杀 |
| 107 | 乾坤大挪移 | 11 | Interchange | NeedLevel 三元组 42/45/48 与 Zircon Interchange(11) 完全一致；Mud3 sch7 → Zircon Warrior/Active |
| 108 | 斗转星移 | 13 | Beckon | NeedLevel 三元组 46/49/52 与 Zircon Beckon(13) 完全一致；Mud3 sch7 → Zircon Warrior/Active；Zircon 英文 Beckon 旧显示名误作召唤，官方名为斗转星移 |
| 110 | 魄冰刺 | 46 | Greater Frozen Earth | NeedLevel 三元组 38/41/44 与 Zircon Greater Frozen Earth(46) 完全一致；Mud3 sch1 → Zircon Wizard/Ice |
| 111 | 怒神霹雳 | 47 | Chain Lightning | NeedLevel 三元组 40/42/44 与 Zircon Chain Lightning(47) 完全一致；Mud3 sch2 → Zircon Wizard/Lightning |
| 113 | 焰天火雨 | 48 | Meteor Shower | NeedLevel 三元组 43/45/47 与 Zircon Meteor Shower(48) 完全一致；Mud3 sch0 → Zircon Wizard/Fire |
| 120 | 云寂术 | 75 | Purification | NeedLevel 三元组 38/41/44 与 Zircon Purification(75) 完全一致；Mud3 sch4 → Zircon Taoist/Holy |
| 121 | 妙影无踪 | 76 | Transparency | NeedLevel 三元组 43/45/47 与 Zircon Transparency(76) 完全一致；Mud3 sch5 → Zircon Taoist/Dark |

## pending（语义待定，人工勾选；禁止当 closed）

| Mud3 Index | Mud3 中文名 | Zircon Index | Zircon 身份 | 证据 |
|---|---|---:|---|---|
| 20 | 诱惑之光 | 28 | Electric Shock | 三元组 13/15/17 与 Electric Shock(28) 一致，但语义不确定（Mud3 诱惑之光疑为魅惑系，Zircon Electric Shock 为闪电麻痹）；同一三元组另有 Explosive Talisman(62) |
| 32 | 圣言术 | 39 | Expel Undead | 三元组 26/28/30 与 Expel Undead(39) 一致，但语义不确定（超度亡灵 vs 圣言术）；Zircon 侧另有译名亦作「圣言术」的 Celestial Light(77) |
| 104 | 异形换位 | 40 | Geo Manipulation | 三元组 27/29/31 与 Geo Manipulation(40) 一致，但语义不确定（缩地术 vs 异形换位） |
| 112 | 凝血离魂 | 77 | Celestial Light | 三元组 46/48/50 与 Celestial Light(77) 一致；该三元组 Mud3 两条 vs Zircon 两条，无法唯一定位（另一条为阴阳法环），语义亦不确定 |
| 122 | 阴阳法环 | 49 | Renounce | 三元组 46/48/50 与 Renounce(49) 一致，但语义不确定（迷魂咒 vs 阴阳法环）；同一三元组另有 Celestial Light(77) |
| 123 | 移花接玉 | 18 | Reflect Damage | 无三元组锚点（Mud3 38/41/44 vs Zircon 53/58/63）；Zircon Reflect Damage(18) 的既定中文译名为移花接玉且同为道士系，但仅有术语证据、非主证据，故 pending |

## missing（Mud3 有、Zircon 无）

| Mud3 Index | Mud3 中文名 | Zircon Index | Zircon 身份 | 证据 |
|---|---|---:|---|---|
| 28 | 心灵启示 | — | — | MagicSchool=99 特殊/未开放条目；Zircon 当前库无对应技能 |
| 42 | 聚集火球 | — | — | 装备附魔变体（MagicSchool=99，聚集/连锁/通天/分散/属性盾系）；Zircon 以装备词缀实现，无 1:1 技能 |
| 44 | 通天大火球 | — | — | 装备附魔变体（MagicSchool=99，聚集/连锁/通天/分散/属性盾系）；Zircon 以装备词缀实现，无 1:1 技能 |
| 45 | 连锁大火球 | — | — | 装备附魔变体（MagicSchool=99，聚集/连锁/通天/分散/属性盾系）；Zircon 以装备词缀实现，无 1:1 技能 |
| 46 | 火焰壁 | — | — | MagicSchool=99 特殊/未开放条目；Zircon 当前库无对应技能 |
| 48 | 云石召唤 | — | — | MagicSchool=99 特殊/未开放条目；Zircon 当前库无对应技能 |
| 49 | 聚集冰月神掌 | — | — | 装备附魔变体（MagicSchool=99，聚集/连锁/通天/分散/属性盾系）；Zircon 以装备词缀实现，无 1:1 技能 |
| 51 | 通天冰月神掌 | — | — | 装备附魔变体（MagicSchool=99，聚集/连锁/通天/分散/属性盾系）；Zircon 以装备词缀实现，无 1:1 技能 |
| 52 | 连锁冰月神掌 | — | — | 装备附魔变体（MagicSchool=99，聚集/连锁/通天/分散/属性盾系）；Zircon 以装备词缀实现，无 1:1 技能 |
| 57 | 聚集霹雳掌 | — | — | 装备附魔变体（MagicSchool=99，聚集/连锁/通天/分散/属性盾系）；Zircon 以装备词缀实现，无 1:1 技能 |
| 58 | 分散霹雳掌 | — | — | 装备附魔变体（MagicSchool=99，聚集/连锁/通天/分散/属性盾系）；Zircon 以装备词缀实现，无 1:1 技能 |
| 59 | 通天霹雳掌 | — | — | 装备附魔变体（MagicSchool=99，聚集/连锁/通天/分散/属性盾系）；Zircon 以装备词缀实现，无 1:1 技能 |
| 60 | 连锁霹雳掌 | — | — | 装备附魔变体（MagicSchool=99，聚集/连锁/通天/分散/属性盾系）；Zircon 以装备词缀实现，无 1:1 技能 |
| 61 | 聚集雷电术 | — | — | 装备附魔变体（MagicSchool=99，聚集/连锁/通天/分散/属性盾系）；Zircon 以装备词缀实现，无 1:1 技能 |
| 62 | 乱降雷电术 | — | — | MagicSchool=99 特殊/未开放条目；Zircon 当前库无对应技能 |
| 63 | 霹雳壁 | — | — | MagicSchool=99 特殊/未开放条目；Zircon 当前库无对应技能 |
| 66 | 霹雳圈 | — | — | MagicSchool=99 特殊/未开放条目；Zircon 当前库无对应技能 |
| 68 | 聚集风掌 | — | — | 装备附魔变体（MagicSchool=99，聚集/连锁/通天/分散/属性盾系）；Zircon 以装备词缀实现，无 1:1 技能 |
| 70 | 通天风掌 | — | — | 装备附魔变体（MagicSchool=99，聚集/连锁/通天/分散/属性盾系）；Zircon 以装备词缀实现，无 1:1 技能 |
| 71 | 连锁风掌 | — | — | 装备附魔变体（MagicSchool=99，聚集/连锁/通天/分散/属性盾系）；Zircon 以装备词缀实现，无 1:1 技能 |
| 78 | 移花术 | — | — | MagicSchool=99 特殊/未开放条目；Zircon 当前库无对应技能 |
| 79 | 聚集月魂断玉 | — | — | 装备附魔变体（MagicSchool=99，聚集/连锁/通天/分散/属性盾系）；Zircon 以装备词缀实现，无 1:1 技能 |
| 80 | 分散月魂断玉 | — | — | 装备附魔变体（MagicSchool=99，聚集/连锁/通天/分散/属性盾系）；Zircon 以装备词缀实现，无 1:1 技能 |
| 81 | 通天月魂断波 | — | — | 装备附魔变体（MagicSchool=99，聚集/连锁/通天/分散/属性盾系）；Zircon 以装备词缀实现，无 1:1 技能 |
| 82 | 连锁月魂断波 | — | — | 装备附魔变体（MagicSchool=99，聚集/连锁/通天/分散/属性盾系）；Zircon 以装备词缀实现，无 1:1 技能 |
| 83 | 聚集灵魂火符 | — | — | 装备附魔变体（MagicSchool=99，聚集/连锁/通天/分散/属性盾系）；Zircon 以装备词缀实现，无 1:1 技能 |
| 84 | 分散灵魂火符 | — | — | 装备附魔变体（MagicSchool=99，聚集/连锁/通天/分散/属性盾系）；Zircon 以装备词缀实现，无 1:1 技能 |
| 85 | 幽灵盾（火） | — | — | 装备附魔变体（MagicSchool=99，聚集/连锁/通天/分散/属性盾系）；Zircon 以装备词缀实现，无 1:1 技能 |
| 86 | 幽灵盾（冰） | — | — | 装备附魔变体（MagicSchool=99，聚集/连锁/通天/分散/属性盾系）；Zircon 以装备词缀实现，无 1:1 技能 |
| 87 | 幽灵盾（雷） | — | — | 装备附魔变体（MagicSchool=99，聚集/连锁/通天/分散/属性盾系）；Zircon 以装备词缀实现，无 1:1 技能 |
| 88 | 幽灵盾（风） | — | — | 装备附魔变体（MagicSchool=99，聚集/连锁/通天/分散/属性盾系）；Zircon 以装备词缀实现，无 1:1 技能 |
| 90 | 强魔震法（火） | — | — | 装备附魔变体（MagicSchool=99，聚集/连锁/通天/分散/属性盾系）；Zircon 以装备词缀实现，无 1:1 技能 |
| 91 | 强魔震法（冰） | — | — | 装备附魔变体（MagicSchool=99，聚集/连锁/通天/分散/属性盾系）；Zircon 以装备词缀实现，无 1:1 技能 |
| 92 | 强魔震法（雷） | — | — | 装备附魔变体（MagicSchool=99，聚集/连锁/通天/分散/属性盾系）；Zircon 以装备词缀实现，无 1:1 技能 |
| 93 | 强魔震法（风） | — | — | 装备附魔变体（MagicSchool=99，聚集/连锁/通天/分散/属性盾系）；Zircon 以装备词缀实现，无 1:1 技能 |
| 95 | 分身术 | — | — | Mud3 独有，Zircon 当前库无对应技能 |
| 96 | 魔防系术 | — | — | 装备附魔变体（MagicSchool=99，聚集/连锁/通天/分散/属性盾系）；Zircon 以装备词缀实现，无 1:1 技能 |
| 97 | 魔防系术（火） | — | — | 装备附魔变体（MagicSchool=99，聚集/连锁/通天/分散/属性盾系）；Zircon 以装备词缀实现，无 1:1 技能 |
| 98 | 魔防系术（冰） | — | — | 装备附魔变体（MagicSchool=99，聚集/连锁/通天/分散/属性盾系）；Zircon 以装备词缀实现，无 1:1 技能 |
| 99 | 魔防系术（雷） | — | — | 装备附魔变体（MagicSchool=99，聚集/连锁/通天/分散/属性盾系）；Zircon 以装备词缀实现，无 1:1 技能 |
| 100 | 魔防系术（风） | — | — | 装备附魔变体（MagicSchool=99，聚集/连锁/通天/分散/属性盾系）；Zircon 以装备词缀实现，无 1:1 技能 |
| 101 | 防御系术 | — | — | 装备附魔变体（MagicSchool=99，聚集/连锁/通天/分散/属性盾系）；Zircon 以装备词缀实现，无 1:1 技能 |

## zircon-only（Zircon 有、Mud3 无）

| Mud3 Index | Mud3 中文名 | Zircon Index | Zircon 身份 | 证据 |
|---|---|---:|---|---|
| — | — | 2 | Potion Mastery | Warrior/Passive；Zircon 后期/强化技能，Mud3 DAT 无 |
| — | — | 15 | Swift Blade | Warrior/Active；Zircon 后期/强化技能，Mud3 DAT 无 |
| — | — | 16 | Assault | Warrior/Active；Zircon 后期/强化技能，Mud3 DAT 无 |
| — | — | 17 | Endurance | Warrior/Active；Zircon 后期/强化技能，Mud3 DAT 无 |
| — | — | 19 | Fetter | Warrior/Active；Zircon 后期/强化技能，Mud3 DAT 无 |
| — | — | 20 | Advanced Destructive Surge | Warrior/Toggle；Zircon 后期/强化技能，Mud3 DAT 无 |
| — | — | 21 | Advanced Defiance | Warrior/Passive；Zircon 后期/强化技能，Mud3 DAT 无 |
| — | — | 22 | Advanced Reflect Damage | Warrior/Passive；Zircon 后期/强化技能，Mud3 DAT 无 |
| — | — | 50 | Tempest | Wizard/Wind；Zircon 后期/强化技能，Mud3 DAT 无 |
| — | — | 51 | Judgement Of Heaven | Wizard/Lightning；Zircon 后期/强化技能，Mud3 DAT 无 |
| — | — | 52 | Thunder Storm | Wizard/Lightning；Zircon 后期/强化技能，Mud3 DAT 无 |
| — | — | 53 | Fire Bounce | Wizard/None；Zircon 后期/强化技能，Mud3 DAT 无 |
| — | — | 54 | Elemental Hurricane | Wizard/Wind；Zircon 后期/强化技能，Mud3 DAT 无 |
| — | — | 55 | Superior Magic Shield | Wizard/Phantom；Zircon 后期/强化技能，Mud3 DAT 无 |
| — | — | 56 | Burning | Wizard/Fire；Zircon 后期/强化技能，Mud3 DAT 无 |
| — | — | 57 | Shock | Wizard/Lightning；Zircon 后期/强化技能，Mud3 DAT 无 |
| — | — | 58 | Lightning Strike | Wizard/Lightning；Zircon 后期/强化技能，Mud3 DAT 无 |
| — | — | 78 | Empowered Healing | Taoist/Holy；Zircon 后期/强化技能，Mud3 DAT 无 |
| — | — | 79 | Life Steal | Taoist/Holy；Zircon 后期/强化技能，Mud3 DAT 无 |
| — | — | 80 | Improved Explosive Talisman | Taoist/Dark；Zircon 后期/强化技能，Mud3 DAT 无 |
| — | — | 81 | Empowered Poison Dust | Taoist/Dark；Zircon 后期/强化技能，Mud3 DAT 无 |
| — | — | 82 | Cursed Doll | Taoist/Phantom；Zircon 后期/强化技能，Mud3 DAT 无 |
| — | — | 83 | Thunder Kick | Taoist/Physical；Zircon 后期/强化技能，Mud3 DAT 无 |
| — | — | 84 | Soul Resonance | Taoist/Holy；Zircon 后期/强化技能，Mud3 DAT 无 |
| — | — | 85 | Parasite | Taoist/Dark；Zircon 后期/强化技能，Mud3 DAT 无 |
| — | — | 86 | Spiritualism | Taoist/Dark；Zircon 后期/强化技能，Mud3 DAT 无 |
| — | — | 87 | Willow Dance | Assassin/Atrocity；Zircon 后期/强化技能，Mud3 DAT 无 |
| — | — | 88 | Vine Tree Dance | Assassin/Atrocity；Zircon 后期/强化技能，Mud3 DAT 无 |
| — | — | 89 | Discipline | Assassin/Atrocity；Zircon 后期/强化技能，Mud3 DAT 无 |
| — | — | 90 | Poisonous Cloud | Assassin/Atrocity；Zircon 后期/强化技能，Mud3 DAT 无 |
| — | — | 91 | Full Bloom | Assassin/Kill；Zircon 后期/强化技能，Mud3 DAT 无 |
| — | — | 92 | Cloak | Assassin/Assassination；Zircon 后期/强化技能，Mud3 DAT 无 |
| — | — | 93 | White Lotus | Assassin/Kill；Zircon 后期/强化技能，Mud3 DAT 无 |
| — | — | 94 | Calamity Of Full Moon | Assassin/Kill；Zircon 后期/强化技能，Mud3 DAT 无 |
| — | — | 95 | Wraith Grip | Assassin/Atrocity；Zircon 后期/强化技能，Mud3 DAT 无 |
| — | — | 96 | Red Lotus | Assassin/Kill；Zircon 后期/强化技能，Mud3 DAT 无 |
| — | — | 97 | Hell Fire | Assassin/Kill；Zircon 后期/强化技能，Mud3 DAT 无 |
| — | — | 98 | Pledge Of Blood | Assassin/Assassination；Zircon 后期/强化技能，Mud3 DAT 无 |
| — | — | 99 | Rake | Assassin/Assassination；Zircon 后期/强化技能，Mud3 DAT 无 |
| — | — | 100 | Sweetbrier | Assassin/Kill；Zircon 后期/强化技能，Mud3 DAT 无 |
| — | — | 101 | Summon Puppet | Assassin/Assassination；Zircon 后期/强化技能，Mud3 DAT 无 |
| — | — | 102 | Karma | Assassin/Assassination；Zircon 后期/强化技能，Mud3 DAT 无 |
| — | — | 103 | Touch Of The Departed | Assassin/Atrocity；Zircon 后期/强化技能，Mud3 DAT 无 |
| — | — | 104 | Waning Moon | Assassin/Assassination；Zircon 后期/强化技能，Mud3 DAT 无 |
| — | — | 105 | Ghost Walk | Assassin/Assassination；Zircon 后期/强化技能，Mud3 DAT 无 |
| — | — | 106 | Elemental Puppet | Assassin/Assassination；Zircon 后期/强化技能，Mud3 DAT 无 |
| — | — | 107 | Rejuvenation | Assassin/Atrocity；Zircon 后期/强化技能，Mud3 DAT 无 |
| — | — | 108 | Resolution | Assassin/Assassination；Zircon 后期/强化技能，Mud3 DAT 无 |
| — | — | 109 | Change Of Seasons | Assassin/None；Zircon 后期/强化技能，Mud3 DAT 无 |
| — | — | 110 | Release | Assassin/Assassination；Zircon 后期/强化技能，Mud3 DAT 无 |
| — | — | 111 | Flame Splash | Assassin/Kill；Zircon 后期/强化技能，Mud3 DAT 无 |
| — | — | 112 | Bloody Flower | Assassin/Kill；Zircon 后期/强化技能，Mud3 DAT 无 |
| — | — | 113 | The New Beginning | Assassin/Atrocity；Zircon 后期/强化技能，Mud3 DAT 无 |
| — | — | 114 | Dance Of Swallow | Assassin/Kill；Zircon 后期/强化技能，Mud3 DAT 无 |
| — | — | 115 | Dark Conversion | Assassin/Atrocity；Zircon 后期/强化技能，Mud3 DAT 无 |
| — | — | 116 | Dragon Repulse | Assassin/Atrocity；Zircon 后期/强化技能，Mud3 DAT 无 |
| — | — | 117 | Advent Of Demon | Assassin/Kill；Zircon 后期/强化技能，Mud3 DAT 无 |
| — | — | 118 | Advent Of Devil | Assassin/Assassination；Zircon 后期/强化技能，Mud3 DAT 无 |
| — | — | 119 | Abyss | Assassin/Atrocity；Zircon 后期/强化技能，Mud3 DAT 无 |
| — | — | 120 | Flash Of Light | Assassin/Kill；Zircon 后期/强化技能，Mud3 DAT 无 |
| — | — | 121 | Stealth | Assassin/Assassination；Zircon 后期/强化技能，Mud3 DAT 无 |
| — | — | 122 | Evasion | Assassin/Atrocity；Zircon 后期/强化技能，Mud3 DAT 无 |
| — | — | 123 | Raging Wind | Assassin/Atrocity；Zircon 后期/强化技能，Mud3 DAT 无 |
| — | — | 124 | Empowered Explosive Talisman | Taoist/None；Zircon 后期/强化技能，Mud3 DAT 无 |
| — | — | 125 | Empowered Evil Slayer | Taoist/None；Zircon 后期/强化技能，Mud3 DAT 无 |
| — | — | 126 | Empowered Purification | Taoist/None；Zircon 后期/强化技能，Mud3 DAT 无 |
| — | — | 127 | Empowered Resurrection | Taoist/None；Zircon 后期/强化技能，Mud3 DAT 无 |
| — | — | 128 | Demon Explosion | Taoist/Phantom；Zircon 后期/强化技能，Mud3 DAT 无 |
| — | — | 129 | Strength Of Faith | Taoist/Phantom；Zircon 后期/强化技能，Mud3 DAT 无 |
| — | — | 131 | Mirror Image | Wizard/None；Zircon 后期/强化技能，Mud3 DAT 无 |
| — | — | 134 | Summon Demonic Creature | Taoist/Phantom；Zircon 后期/强化技能，Mud3 DAT 无 |
| — | — | 135 | Advanced Potion Mastery | Warrior/None；Zircon 后期/强化技能，Mud3 DAT 无 |
| — | — | 136 | _Blank_ | Assassin/None；占位条目 _Blank_（未使用） |
| — | — | 137 | Ice Rain | Wizard/Ice；Zircon 后期/强化技能，Mud3 DAT 无 |
| — | — | 138 | Mass Beckon | Warrior/Active；Zircon 后期/强化技能，Mud3 DAT 无 |
| — | — | 139 | Frost Bite | Wizard/Ice；Zircon 后期/强化技能，Mud3 DAT 无 |
| — | — | 140 | Infection | Taoist/Dark；Zircon 后期/强化技能，Mud3 DAT 无 |
| — | — | 141 | Massacre | Assassin/None；Zircon 后期/强化技能，Mud3 DAT 无 |
| — | — | 142 | Seismic Slam | Warrior/Active；Zircon 后期/强化技能，Mud3 DAT 无 |
| — | — | 143 | Demonic Recovery | Taoist/Phantom；Zircon 后期/强化技能，Mud3 DAT 无 |
| — | — | 144 | Asteroid | Wizard/Fire；Zircon 后期/强化技能，Mud3 DAT 无 |
| — | — | 145 | Art of Shadows | Assassin/None；Zircon 后期/强化技能，Mud3 DAT 无 |
| — | — | 146 | Invincibility | Warrior/Active；Zircon 后期/强化技能，Mud3 DAT 无 |
| — | — | 147 | Crushing Wave | Warrior/Active；Zircon 后期/强化技能，Mud3 DAT 无 |
| — | — | 148 | Neutralize | Taoist/Dark；Zircon 后期/强化技能，Mud3 DAT 无 |
| — | — | 149 | Empowered Neutralize | Taoist/None；Zircon 后期/强化技能，Mud3 DAT 无 |
| — | — | 150 | Dark Soul Prison | Taoist/Dark；Zircon 后期/强化技能，Mud3 DAT 无 |
| — | — | 151 | Searing Light | Taoist/Holy；Zircon 后期/强化技能，Mud3 DAT 无 |
| — | — | 152 | Defensive Mastery | Warrior/Passive；Zircon 后期/强化技能，Mud3 DAT 无 |
| — | — | 153 | Physical Immunity | Warrior/Passive；Zircon 后期/强化技能，Mud3 DAT 无 |
| — | — | 154 | Magic Immunity | Warrior/Passive；Zircon 后期/强化技能，Mud3 DAT 无 |
| — | — | 155 | Defensive Blow | Warrior/Active；Zircon 后期/强化技能，Mud3 DAT 无 |
| — | — | 156 | Elemental Swords | Warrior/Active；Zircon 后期/强化技能，Mud3 DAT 无 |
| — | — | 157 | Storm | Wizard/None；Zircon 后期/强化技能，Mud3 DAT 无 |
| — | — | 158 | Tornado | Wizard/Wind；Zircon 后期/强化技能，Mud3 DAT 无 |
| — | — | 159 | Empowered Celestial Light | Taoist/Holy；Zircon 后期/强化技能，Mud3 DAT 无 |
| — | — | 160 | Corpse Exploder | Taoist/Dark；Zircon 后期/强化技能，Mud3 DAT 无 |
| — | — | 161 | Summon Dead | Taoist/Phantom；Zircon 后期/强化技能，Mud3 DAT 无 |
| — | — | 162 | Dragon Blood | Assassin/Kill；Zircon 后期/强化技能，Mud3 DAT 无 |
| — | — | 163 | Fatal Blow | Assassin/Kill；Zircon 后期/强化技能，Mud3 DAT 无 |
| — | — | 164 | Last Stand | Assassin/Atrocity；Zircon 后期/强化技能，Mud3 DAT 无 |
| — | — | 165 | Magic Combustion | Assassin/Atrocity；Zircon 后期/强化技能，Mud3 DAT 无 |
| — | — | 166 | Vitality | Assassin/Atrocity；Zircon 后期/强化技能，Mud3 DAT 无 |
| — | — | 167 | Chain | Assassin/Atrocity；Zircon 后期/强化技能，Mud3 DAT 无 |
| — | — | 168 | Concentration | Assassin/Atrocity；Zircon 后期/强化技能，Mud3 DAT 无 |
| — | — | 169 | Dual Weapon Skills | Assassin/Atrocity；Zircon 后期/强化技能，Mud3 DAT 无 |
| — | — | 170 | Containment | Assassin/Atrocity；Zircon 后期/强化技能，Mud3 DAT 无 |
| — | — | 171 | Dragon Wave | Assassin/Kill；Zircon 后期/强化技能，Mud3 DAT 无 |
| — | — | 172 | Hemorrhage | Assassin/Kill；Zircon 后期/强化技能，Mud3 DAT 无 |
| — | — | 173 | Burning Fire | Assassin/Kill；Zircon 后期/强化技能，Mud3 DAT 无 |
| — | — | 174 | Chain Of Fire | Assassin/Atrocity；Zircon 后期/强化技能，Mud3 DAT 无 |
