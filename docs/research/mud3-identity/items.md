# Mud3 ↔ Zircon 物品身份表（item identity）

> 由 `build_item_identity.py` 只读生成，禁止手改。
> Zircon 快照来自 `SystemDbProbe --json`（当前库 1078 物品）；
> 老版来自 `stditem.json`（1143 记录）。

## 计数

| confidence | 行数 |
|---|---:|
| closed | 366 |
| pending | 82 |
| missing | 695 |
| zircon-only | 630 |
| **total rows** | 1773 |

- distinct Mud3 indices covered (closed/pending/missing): **1143** / 1143
- distinct Zircon indices covered (closed/pending/zircon-only): **1078** / 1078
- `closed` rows are 1:1 (no duplicated zircon_index).

> **pending 语义**：每条 Mud3 记录只给**一个候选** `zircon_index`，它是人工复核的**提议**，**不是已确认身份**；evidence 里列出其它备选候选（`alternatives:`）。多候选时**不会**标记为 `closed`。下游工具（`db_names.json` 重写、掉落迁移）**不得**消费 pending 行。

## closed — 1:1 已闭合（366）

| mud3_index | mud3_name | → zircon_index | zircon_en | evidence |
|---:|---|---:|---|---|
| 0 | 金币 | 1 | Gold | manual anchor (verified): StdMode 41 currency; Mud3 price=1 (min unit) matches only Currency row 'Gold' |
| 1 | 金创药（小） | 133 | Healing Potion | manual anchor (verified): price 80=80; image Looks5=Image5; Health 30=30 |
| 2 | 魔法药（小） | 143 | Mana Potion | manual anchor (verified): image Looks15=Image15; Mana 40=40; price 80->84 (tier) |
| 4 | 布衣（男） | 127 | Commoner Outfit (M) | manual anchor (verified): price 500=500; weight 5=5; dura 5000=5000; level 1=1; Looks940<->Image941 |
| 5 | 布衣（女） | 128 | Commoner Outfit (F) | manual anchor (verified): price 500=500; weight 5=5; dura 5000=5000; level 1=1; Looks950<->Image951 |
| 6 | 木剑 | 126 | Wood Sword | manual anchor (verified): price 50=50; weight 5=5; dura 4000=4000; level 1=1; image Looks1042=Image1042 |
| 7 | 铁剑 | 176 | Iron Sword | manual anchor (verified): price 1000=1000; weight 10=10; dura 10000=10000; level 7=7; image 1043=1043 |
| 8 | 青铜剑 | 439 | Bronze Sword | manual anchor (verified): price 500=500; weight 9=9; dura 8000=8000; level 5=5; image 1043=1043 |
| 14 | 火球术 | 24 | Fire Ball | skill book: SKILL_MAP '火球术'->skill#23 'Fire Ball'; price 1000=1000; level(DuraMax 7=RequiredAmount 7) |
| 15 | 治愈术 | 60 | Heal | skill book: SKILL_MAP '治愈术'->skill#59 'Heal'; price 1000=1000; level(DuraMax 7=RequiredAmount 7) |
| 16 | 基本剑术 | 2 | Swordsmanship | skill book: SKILL_MAP '基本剑术'->skill#1 'Swordsmanship'; price 1000=1000; level(DuraMax 7=RequiredAmount 7) |
| 17 | 蜡烛 | 132 | Candle | 1:1 mutual-unique; image 290=290; price 10=10; weight 1=1; dura 8000=8000 |
| 19 | 精神力战法 | 61 | Spirit Sword | skill book: SKILL_MAP '精神力战法'->skill#60 'Spirit Sword'; price 1000=1000; level(DuraMax 8=RequiredAmount 8) |
| 20 | 青铜斧 | 184 | Bronze Axe | 1:1 mutual-unique; image 1060=1060; price 3500=3500; weight 20=20; dura 20000=20000; level 14=14 |
| 21 | 重盔甲（女） | 193 | Medium Armour (F) | 1:1 mutual-unique; image 990=990; weight 23=23; dura 25000=25000; level 22=22 |
| 22 | 魔法长袍（女） | 195 | Flame Robe (F) | 1:1 mutual-unique; image 1030=1030; price 10000=10000; weight 12=12; dura 20000=20000; level 22=22 |
| 23 | 灵魂战衣（女） | 197 | Faith Robe (F) | 1:1 mutual-unique; image 1010=1010; price 10000=10000; weight 15=15; dura 20000=20000; level 22=22 |
| 24 | 重盔甲（男） | 192 | Medium Armour (M) | 1:1 mutual-unique; image 980=980; weight 23=23; dura 25000=25000; level 22=22 |
| 25 | 魔法长袍（男） | 194 | Flame Robe (M) | 1:1 mutual-unique; image 1020=1020; price 10000=10000; weight 12=12; dura 20000=20000; level 22=22 |
| 26 | 灵魂战衣（男） | 196 | Faith Robe (M) | 1:1 mutual-unique; image 1000=1000; price 10000=10000; weight 15=15; dura 20000=20000; level 22=22 |
| 27 | 大火球 | 31 | Adamantine Fire Ball | skill book: SKILL_MAP '大火球'->skill#30 'Adamantine Fire Ball'; price 1000=1000; level(DuraMax 15=RequiredAmount 15) |
| 28 | 攻杀剑术 | 4 | Slaying | skill book: SKILL_MAP '攻杀剑术'->skill#3 'Slaying'; price 1000=1000; level(DuraMax 14=RequiredAmount 14) |
| 29 | 施毒术 | 62 | Poison Dust | skill book: SKILL_MAP '施毒术'->skill#61 'Poison Dust'; price 1000=1000; level(DuraMax 12=RequiredAmount 12) |
| 30 | 匕首 | 174 | Dagger | 1:1 mutual-unique; image 1045=1045; price 100=100; weight 7=7; dura 6000=6000; level 3=3 |
| 31 | 井中月 | 547 | Forged Scimitar | manual anchor (verified): price 28000=28000; weight 54=54; dura 26000=26000; level 35=35; image 1068=1068 |
| 32 | 银蛇 | 330 | Serpent Sword | 1:1 mutual-unique; image 1102=1102; price 10000=10000; weight 21=21; dura 22000=22000 |
| 33 | 海魂 | 186 | Trident | 1:1 mutual-unique; image 1080=1080; price 3500=3500; weight 10=10; dura 9000=9000; level 14=14 |
| 34 | 修罗 | 306 | Power Axe | 1:1 mutual-unique; image 1065=1065; price 6000=6000; weight 30=30; dura 22000=22000; level 20=20 |
| 38 | 斩马刀 | 200 | Hexagon Blade | 1:1 mutual-unique; image 1063=1063; price 5000=5000; weight 27=27; dura 18000=18000; level 18=18 |
| 39 | 食人树叶 | 241 | Carnivorous Plant Leaf | 1:1 mutual-unique; image 113=113; price 50=50 |
| 40 | 毒蜘蛛牙齿 | 244 | Spitting Spider Tooth | 1:1 mutual-unique; image 111=111; price 50=50 |
| 41 | 食人树的果实 | 242 | Carnivorous Plant Fruit | 1:1 mutual-unique; image 114=114; price 300=300 |
| 42 | 蝎子的尾巴 | 257 | Scorpion Tail | 1:1 mutual-unique; image 112=112; price 100=100 |
| 43 | 蛆卵 | 259 | Maggot Pill | 1:1 mutual-unique; image 110=110; price 500=500 |
| 46 | 古铜戒指 | 440 | Copper Ring | 1:1 mutual-unique; image 530=530; weight 1=1; dura 7000=7000; level 7=7 |
| 47 | 青铜头盔 | 231 | Bronze Helmet | 1:1 mutual-unique; image 370=370; price 1000=1000; weight 4=4; dura 8000=8000; level 9=9 |
| 48 | 金项链 | 164 | Gold Necklace | 1:1 mutual-unique; image 870=870; weight 1=1; dura 8000=8000; level 2=2 |
| 49 | 铁手镯 | 161 | Iron Bracer | 1:1 mutual-unique; image 646=646; price 300=300; weight 1=1; dura 7000=7000; level 3=3 |
| 54 | 乌木剑 | 178 | Arisu Wood Sword | 1:1 mutual-unique; image 1042=1042; price 1000=1000; weight 5=5; level 7=7 |
| 55 | 魔杖 | 329 | Mage Staff | 1:1 mutual-unique; image 1082=1082; price 10000=10000; weight 10=10; dura 13000=13000 |
| 57 | 鸡肉 | 179 | Chicken Meat | 1:1 mutual-unique; image 301=301; price 80=80; weight 1=1; dura 4000=4000 |
| 58 | 水晶魔戒 | 166 | Glass Ring | 1:1 mutual-unique; image 490=490; price 1000=1000; weight 1=1; dura 5000=5000; level 7=7 |
| 59 | 牛角戒指 | 165 | Horned Ring | 1:1 mutual-unique; image 470=470; price 1200=1200; weight 1=1; dura 6000=6000 |
| 60 | 蓝色水晶戒指 | 441 | Blue Crystal Ring | 1:1 mutual-unique; image 472=472; price 1500=1500; weight 1=1; dura 6000=6000; level 9=9 |
| 61 | 六绝星环 | 442 | Hexagonal Ring | 1:1 mutual-unique; image 510=510; weight 1=1; dura 4000=4000; level 7=7 |
| 62 | 黑檀项链 | 213 | Arisu Necklace | 1:1 mutual-unique; image 850=850; weight 1=1; dura 6000=6000; level 11=11 |
| 63 | 黄色水晶项链 | 450 | Yellow Crystal Necklace | 1:1 mutual-unique; image 830=830; price 4000=4000; weight 1=1; dura 7000=7000; level 11=11 |
| 64 | 黑色水晶项链 | 212 | Black Crystal Necklace | 1:1 mutual-unique; image 810=810; weight 1=1; dura 9000=9000; level 11=11 |
| 65 | 魔法头盔 | 234 | Magic Bronze Helmet | 1:1 mutual-unique; image 370=370; price 3000=3000; weight 4=4; dura 8000=8000; level 15=15 |
| 66 | 沃玛号角 | 358 | Horn Of Uma King | 1:1 mutual-unique; image 100=100; price 1000=1000; weight 1=1 |
| 67 | 半月 | 187 | Scimitar | 1:1 mutual-unique; image 1100=1100; price 3500=3500; weight 13=13; dura 12000=12000; level 14=14 |
| 68 | 皮制手套 | 167 | Leather Glove | 1:1 mutual-unique; image 640=640; price 500=500; weight 2=2; dura 10000=10000; level 5=5 |
| 69 | 坚固手套 | 293 | Rugged Leather Gauntlet | 1:1 mutual-unique; image 642=642; price 5000=5000; weight 3=3; dura 10000=10000; level 17=17 |
| 70 | 钢手镯 | 443 | Steel Bracelet | 1:1 mutual-unique; image 646=646; price 1000=1000; weight 1=1; dura 7000=7000; level 8=8 |
| 71 | 玄铁指环 | 582 | Iron Ring | 1:1 mutual-unique; image 471=471; weight 1=1; dura 4000=4000; level 9=9 |
| 72 | 金戒指 | 307 | Gold Ring | 1:1 mutual-unique; image 473=473; price 7000=7000; weight 1=1; dura 6000=6000; level 20=20 |
| 73 | 灯笼项链 | 205 | Necklace Of Lantern | 1:1 mutual-unique; image 872=872; price 4000=4000; weight 1=1; dura 8000=8000; level 13=13 |
| 74 | 白色虎齿项链 | 207 | White Tiger Tooth Necklace | 1:1 mutual-unique; image 871=871; price 6000=6000; weight 1=1; dura 8000=8000; level 18=18 |
| 75 | 魅力戒指 | 308 | Band Of Sorcery | 1:1 mutual-unique; image 512=512; weight 1=1; dura 4000=4000; level 19=19 |
| 76 | 道德戒指 | 468 | Ring Of Discipline | 1:1 mutual-unique; image 492=492; price 6000=6000; weight 1=1; dura 5000=5000; level 19=19 |
| 77 | 白金项链 | 295 | Platinum Necklace | 1:1 mutual-unique; image 851=851; weight 1=1; dura 6000=6000; level 10=10 |
| 78 | 降妖除魔戒指 | 333 | Ring Of Exorcism | 1:1 mutual-unique; image 474=474; price 10000=10000; weight 2=2; dura 6000=6000; level 27=27 |
| 79 | 躲避手链 | 486 | Necklace Of Evasion | 1:1 mutual-unique; image 874=874; price 30000=30000; weight 1=1; dura 7000=7000 |
| 81 | 偃月 | 201 | War Spear | 1:1 mutual-unique; image 1081=1081; price 5000=5000; weight 11=11; dura 10000=10000; level 18=18 |
| 82 | 降魔 | 202 | War Blade | 1:1 mutual-unique; image 1101=1101; price 5000=5000; weight 15=15; dura 14000=14000; level 18=18 |
| 83 | 传统项链 | 162 | Necklace Of Tranquility | 1:1 mutual-unique; image 873=873; weight 1=1; dura 8000=8000; level 3=3 |
| 84 | 小手镯 | 444 | Gold-Plated Bracelet | 1:1 mutual-unique; image 648=648; price 400=400; weight 1=1; dura 7000=7000; level 4=4 |
| 85 | 银手镯 | 163 | Silver Bracelet | 1:1 mutual-unique; image 722=722; price 500=500; weight 1=1; dura 7000=7000; level 5=5 |
| 86 | 大手镯 | 168 | Golden Bracelet | 1:1 mutual-unique; image 644=644; price 1500=1500; weight 1=1; dura 7000=7000 |
| 87 | 鹤嘴锄 | 816 | Pick Axe | 1:1 mutual-unique; image 1040=1040; price 700=700; weight 10=10; dura 10000=10000 |
| 88 | 隐身戒指 | 304 | Loop Of Invisibility | 1:1 mutual-unique; image 574=574; weight 1=1 |
| 89 | 抗拒火环 | 28 | Repulsion | skill book: SKILL_MAP '抗拒火环'->skill#27 'Repulsion'; price 1000=1000; level(DuraMax 12=RequiredAmount 12) |
| 90 | 地狱火 | 35 | Scorched Earth | skill book: SKILL_MAP '地狱火'->skill#34 'Scorched Earth'; price 1000=1000; level(DuraMax 20=RequiredAmount 20) |
| 91 | 雷电术 | 32 | Thunder Bolt | skill book: SKILL_MAP '雷电术'->skill#31 'Thunder Bolt'; price 1000=1000; level(DuraMax 16=RequiredAmount 16) |
| 92 | 疾光电影 | 36 | Lightning Beam | skill book: SKILL_MAP '疾光电影'->skill#35 'Lightning Beam'; price 1000=1000; level(DuraMax 21=RequiredAmount 21) |
| 93 | 灵魂火符 | 63 | Explosive Talisman | skill book: SKILL_MAP '灵魂火符'->skill#62 'Explosive Talisman'; price 1000=1000; level(DuraMax 13=RequiredAmount 13) |
| 94 | 幽灵盾 | 66 | Magic Resistance | skill book: SKILL_MAP '幽灵盾'->skill#65 'Magic Resistance'; price 1000=1000; level(DuraMax 21=RequiredAmount 21) |
| 95 | 神圣战甲术 | 69 | Resilience | skill book: SKILL_MAP '神圣战甲术'->skill#68 'Resilience'; price 1000=1000; level(DuraMax 25=RequiredAmount 25) |
| 96 | 金创药（中） | 134 | Healing Potion (II) | manual anchor (verified): price 200=200; image Looks6=Image6; Health 70=70 |
| 97 | 魔法药（中） | 144 | Mana Potion (II) | manual anchor (verified): image Looks16=Image16; Mana 110=110; price 200->210 (tier) |
| 98 | 黑色水晶戒指 | 172 | Black Crystal Ring | 1:1 mutual-unique; image 531=531; weight 1=1; dura 7000=7000; level 13=13 |
| 99 | 魔鬼项链 | 204 | Naga Necklace | 1:1 mutual-unique; image 811=811; weight 1=1; dura 9000=9000; level 15=15 |
| 100 | 珊瑚戒指 | 208 | Coral Ring | 1:1 mutual-unique; image 533=533; weight 1=1; dura 7000=7000; level 20=20 |
| 101 | 蓝翡翠项链 | 309 | Blue Jade Necklace | 1:1 mutual-unique; image 812=812; weight 1=1; dura 9000=9000; level 21=21 |
| 102 | 蛇眼戒指 | 452 | Serpent Ring | 1:1 mutual-unique; image 511=511; weight 1=1; dura 4000=4000; level 13=13 |
| 103 | 琥珀项链 | 453 | Amber Necklace | 1:1 mutual-unique; image 852=852; weight 1=1; dura 6000=6000; level 15=15 |
| 105 | 刺杀剑术 | 5 | Thrusting | skill book: SKILL_MAP '刺杀剑术'->skill#4 'Thrusting'; price 1000=1000; level(DuraMax 19=RequiredAmount 19) |
| 106 | 放大镜 | 310 | Pendant Of Image | 1:1 mutual-unique; image 853=853; weight 1=1; dura 6000=6000; level 22=22 |
| 107 | 红宝石戒指 | 531 | Ruby Ring | 1:1 mutual-unique; image 513=513; weight 1=1; dura 4000=4000; level 17=17 |
| 108 | 珍珠戒指 | 173 | Pearl Ring | 1:1 mutual-unique; image 491=491; price 2500=2500; weight 1=1; dura 5000=5000; level 13=13 |
| 109 | 竹笛 | 469 | Bamboo Necklace | 1:1 mutual-unique; image 832=832; price 10000=10000; weight 1=1; dura 7000=7000; level 22=22 |
| 110 | 铂金戒指 | 532 | Platinum Ring | 1:1 mutual-unique; image 493=493; price 10000=10000; weight 1=1; dura 5000=5000; level 17=17 |
| 111 | 骷髅戒指 | 581 | Skeleton Ring | 1:1 mutual-unique; image 532=532; weight 1=1; dura 7000=7000; level 30=30 |
| 112 | 龙之戒指 | 533 | Gold Dragon Ring | 1:1 mutual-unique; image 534=534; weight 2=2; dura 7000=7000; level 37=37 |
| 113 | 死神手套 | 210 | Gauntlet Of Deathbringer | 1:1 mutual-unique; image 661=661; weight 2=2; dura 8000=8000; level 25=25 |
| 115 | 魔法手镯 | 169 | Magic Bracelet | 1:1 mutual-unique; image 647=647; price 2500=2500; weight 1=1; dura 7000=7000; level 12=12 |
| 116 | 金手镯 | 381 | Gold Plated Bracelet | 1:1 mutual-unique; image 645=645; price 10000=10000; weight 1=1; dura 7000=7000; level 25=25 |
| 117 | 道士头盔 | 311 | Helmet Of Shaman | 1:1 mutual-unique; image 372=372; price 5500=5500; weight 3=3; dura 8000=8000; level 20=20 |
| 118 | 传送戒指 | 299 | Loop Of Teleportation | 1:1 mutual-unique; image 573=573; weight 1=1; dura 5000=5000 |
| 120 | 骑士手镯 | 504 | Hero's Bracelet | 1:1 mutual-unique; image 662=662; weight 2=2; dura 8000=8000 |
| 121 | 绿色项链 | 370 | Green Bead Necklace | 1:1 mutual-unique; image 814=814; weight 3=3; dura 9000=9000 |
| 123 | 道士手镯 | 451 | Bracer Of Magic | 1:1 mutual-unique; image 680=680; price 2000=2000; weight 1=1; level 10=10 |
| 124 | 三眼手镯 | 470 | Bracelet Of Three Eyes | 1:1 mutual-unique; image 681=681; price 8000=8000; weight 1=1; dura 6000=6000; level 22=22 |
| 125 | 灵魂项链 | 478 | Pendent Of Holy Spirit | 1:1 mutual-unique; image 834=834; price 30000=30000; weight 2=2; dura 7000=7000 |
| 126 | 黑檀手镯 | 170 | Arisu Bracelet | 1:1 mutual-unique; image 700=700; weight 1=1; dura 5000=5000; level 10=10 |
| 127 | 思贝儿手镯 | 211 | Bracelet Of Sorcery | 1:1 mutual-unique; image 701=701; price 8000=8000; weight 1=1; dura 5000=5000; level 22=22 |
| 128 | 恶魔铃铛 | 371 | Anti Evil Necklace | 1:1 mutual-unique; image 855=855; weight 1=1; dura 6000=6000 |
| 129 | 铜矿 | 539 | Silver Ore | 1:1 mutual-unique; image 215=215; weight 4=4; dura 10000=10000 |
| 130 | 铁矿 | 537 | Copper Ore | 1:1 mutual-unique; image 216=216; weight 4=4; dura 10000=10000 |
| 131 | 银矿 | 538 | Iron Ore | 1:1 mutual-unique; image 211=211; weight 4=4; dura 10000=10000 |
| 132 | 金矿 | 540 | Gold Ore | 1:1 mutual-unique; image 210=210; price 6000=6000; weight 4=4; dura 10000=10000 |
| 133 | 战神油 | 298 | Oil Of The War God | 1:1 mutual-unique; image 61=61; price 1000=1000; weight 1=1 |
| 134 | 回城卷 | 156 | Scroll Of Town Portal | 1:1 mutual-unique; image 207=207; price 500=500; weight 1=1 |
| 135 | 祝福油 | 296 | Oil Of Benediction | 1:1 mutual-unique; image 63=63; price 1000=1000; weight 1=1 |
| 136 | 麻痹戒指 | 300 | Loop Of Paralysis | 1:1 mutual-unique; image 571=571; weight 1=1; dura 5000=5000 |
| 137 | 复活戒指 | 302 | Loop Of Ressurection | 1:1 mutual-unique; image 575=575; weight 1=1; dura 5000=5000 |
| 141 | 护身戒指 | 303 | Loop Of Protection | 1:1 mutual-unique; image 576=576; weight 1=1; dura 5000=5000 |
| 142 | 神力戒指 | 454 | Seal Of Titans | 1:1 mutual-unique; image 572=572; weight 1=1; dura 5000=5000 |
| 143 | 技巧项链 | 301 | Choker Of Learning | 1:1 mutual-unique; image 891=891; price 50000=50000; weight 1=1; dura 8000=8000 |
| 144 | 狂风戒指 | 354 | Gale Ring | 1:1 mutual-unique; image 550=550; price 50000=50000; weight 1=1; dura 5000=5000 |
| 145 | 夏普儿手镯 | 487 | Dark Blade | 1:1 mutual-unique; image 721=721; price 30000=30000; weight 1=1; dura 6000=6000 |
| 146 | 狂风项链 | 355 | Gale Necklace | 1:1 mutual-unique; image 877=877; price 50000=50000; weight 1=1; dura 7000=7000 |
| 147 | 辟邪手镯 | 488 | Bracelet Of Evasion | 1:1 mutual-unique; image 723=723; price 30000=30000; weight 1=1; dura 6000=6000 |
| 149 | 困魔咒 | 70 | Trap Octagon | skill book: SKILL_MAP '困魔咒'->skill#69 'Trap Octagon'; price 1000=1000; level(DuraMax 27=RequiredAmount 27) |
| 150 | 召唤骷髅 | 585 | Summon Skeleton | skill book: SKILL_MAP '召唤骷髅'->skill#130 'Summon Skeleton'; price 1000=1000; level(DuraMax 17=RequiredAmount 17) |
| 151 | 隐身术 | 65 | Invisibility | skill book: SKILL_MAP '隐身术'->skill#64 'Invisibility'; price 1000=1000; level(DuraMax 20=RequiredAmount 20) |
| 152 | 集体隐身术 | 67 | Mass Invisibility | skill book: SKILL_MAP '集体隐身术'->skill#66 'Mass Invisibility'; price 1000=1000; level(DuraMax 23=RequiredAmount 23) |
| 153 | 诱惑之光 | 29 | Electric Shock | skill book: SKILL_MAP '诱惑之光'->skill#28 'Electric Shock'; price 1000=1000; level(DuraMax 13=RequiredAmount 13) |
| 154 | 瞬息移动 | 30 | Teleportation | skill book: SKILL_MAP '瞬息移动'->skill#29 'Teleportation'; price 1000=1000; level(DuraMax 14=RequiredAmount 14) |
| 155 | 火墙 | 39 | Fire Wall | skill book: SKILL_MAP '火墙'->skill#38 'Fire Wall'; price 1000=1000; level(DuraMax 24=RequiredAmount 24) |
| 156 | 爆裂火焰 | 43 | Fire Storm | skill book: SKILL_MAP '爆裂火焰'->skill#42 'Fire Storm'; price 1000=1000; level(DuraMax 32=RequiredAmount 32) |
| 157 | 地狱雷光 | 44 | Lightning Wave | skill book: SKILL_MAP '地狱雷光'->skill#43 'Lightning Wave'; price 1000=1000; level(DuraMax 33=RequiredAmount 33) |
| 158 | 半月弯刀 | 6 | Half Moon | skill book: SKILL_MAP '半月弯刀'->skill#5 'Half Moon'; price 1000=1000; level(DuraMax 24=RequiredAmount 24) |
| 161 | 太阳水 | 153 | Rejuvenation Potion | manual anchor (verified): image Looks20=Image20; price 500=500; Health 70=70; Mana 110=110 |
| 164 | 随机传送卷 | 155 | Scroll Of Random Teleport | 1:1 mutual-unique; image 205=205; price 100=100; weight 1=1 |
| 165 | 无极棍 | 548 | Runed Staff | 1:1 mutual-unique; image 1103=1103; price 40000=40000; weight 33=33; dura 24000=24000 |
| 167 | 裁决之杖 | 549 | Judgement Mace | manual anchor (verified): price 40000=40000; weight 90=90; image Looks1069=Image1069 |
| 168 | 记忆戒指 | 359 | Signet Of Summoning | 1:1 mutual-unique; image 590=590; weight 1=1; dura 7000=7000 |
| 169 | 记忆项链 | 360 | Amulet Of Summoning | 1:1 mutual-unique; image 910=910; weight 1=1; dura 8000=8000 |
| 170 | 记忆手镯 | 361 | Bracelet Of Summoning | 1:1 mutual-unique; image 760=760; weight 1=1; dura 6000=6000 |
| 171 | 记忆头盔 | 362 | Head-Guard Of Summoning | 1:1 mutual-unique; image 390=390; weight 7=7; dura 8000=8000 |
| 172 | 祈祷之刃 | 312 | Blade Of Spirit Caller | 1:1 mutual-unique; image 1120=1120; price 80000=80000; weight 15=15; dura 20000=20000 |
| 173 | 祈祷手镯 | 315 | Bracelet Of Spirit Caller | 1:1 mutual-unique; image 761=761; weight 1=1; dura 6000=6000 |
| 174 | 祈祷项链 | 314 | Necklace Of Spirit Caller | 1:1 mutual-unique; image 911=911; weight 1=1; dura 7000=7000 |
| 175 | 祈祷戒指 | 316 | Ring Of Spirit Caller | 1:1 mutual-unique; image 591=591; weight 1=1; dura 5000=5000 |
| 176 | 祈祷头盔 | 313 | Helmet Of Spirit Caller | 1:1 mutual-unique; image 391=391; price 30000=30000; weight 2=2; dura 5000=5000 |
| 179 | 金创药（大） | 135 | Healing Potion (III) | manual anchor (verified): price 500=500; image Looks7=Image7; Health 110=110 |
| 180 | 魔法药（大） | 145 | Mana Potion (III) | manual anchor (verified): image Looks17=Image17; Mana 180=180; price 500->525 (tier) |
| 182 | 力量戒指 | 489 | Spiked Ring | 1:1 mutual-unique; image 535=535; weight 3=3; dura 7000=7000; level 29=29 |
| 183 | 心灵手镯 | 505 | Holy Bracer | 1:1 mutual-unique; image 682=682; weight 2=2; dura 6000=6000 |
| 184 | 黑铁头盔 | 557 | Crown Of Dark Crusader | 1:1 mutual-unique; image 374=374; price 30000=30000; weight 20=20; dura 10000=10000 |
| 185 | 烈火剑法 | 8 | Flaming Sword | skill book: SKILL_MAP '烈火剑法'->skill#7 'Flaming Sword'; price 1000=1000; level(DuraMax 32=RequiredAmount 32) |
| 186 | 野蛮冲撞 | 7 | Shoulder Dash | skill book: SKILL_MAP '野蛮冲撞'->skill#6 'Shoulder Dash'; price 1000=1000; level(DuraMax 27=RequiredAmount 27) |
| 188 | 群体治愈术 | 73 | Mass Heal | skill book: SKILL_MAP '群体治愈术'->skill#72 'Mass Heal'; price 1000=1000; level(DuraMax 31=RequiredAmount 31) |
| 189 | 召唤神兽 | 586 | Summon Shinsu | skill book: SKILL_MAP '召唤神兽'->skill#133 'Summon Shinsu'; price 1000=1000; level(DuraMax 30=RequiredAmount 30) |
| 190 | 魔法盾 | 42 | Magic Shield | skill book: SKILL_MAP '魔法盾'->skill#41 'Magic Shield'; price 1000=1000; level(DuraMax 29=RequiredAmount 29) |
| 191 | 圣言术 | 40 | Expel Undead | skill book: SKILL_MAP '圣言术'->skill#39 'Expel Undead'; price 1000=1000; level(DuraMax 26=RequiredAmount 26) |
| 192 | 冰咆哮 | 45 | Ice Storm | skill book: SKILL_MAP '冰咆哮'->skill#44 'Ice Storm'; price 1000=1000; level(DuraMax 34=RequiredAmount 34) |
| 195 | 强效太阳水 | 154 | Rejuvenation Potion (II) | manual anchor (verified): image Looks21=Image21; Health/Mana recovery match Rejuvenation Potion (II) |
| 198 | 黑铁 | 541 | Black Iron Ore | manual anchor (verified): price 1000=1000; weight 4=4; dura 10000=10000; image 214=214 |
| 204 | 命运之刃 | 363 | Enchanted Blade | 1:1 mutual-unique; image 1067=1067; price 15000=15000; weight 47=47; dura 24000=24000; level 29=29 |
| 205 | 屠龙 | 819 | Obsidian Giant Blade | manual anchor (verified): price 80000=80000; weight 100=100; image Looks1070=Image1070 |
| 206 | 骨玉权杖 | 550 | Dragon Bone Staff | manual anchor (verified): price 40000=40000; weight 15=15; image Looks1084=Image1084 |
| 207 | 龙纹剑 | 820 | Divine Blade Of Judgement | 1:1 mutual-unique; image 1104=1104; price 80000=80000; dura 26000=26000 |
| 209 | 火把 | 158 | Torch | 1:1 mutual-unique; image 291=291; price 500=500; weight 3=3; dura 20000=20000 |
| 213 | 紫碧螺 | 490 | Opal Ring | 1:1 mutual-unique; image 514=514; weight 1=1; dura 4000=4000; level 27=27 |
| 214 | 泰坦戒指 | 491 | Hieroglyphic Ring | 1:1 mutual-unique; image 494=494; price 10000=10000; weight 2=2; dura 5000=5000; level 27=27 |
| 215 | 幽灵手套 | 380 | Bronze Gauntlet | 1:1 mutual-unique; image 641=641; price 15000=15000; weight 5=5; dura 10000=10000; level 28=28 |
| 216 | 阎罗手套 | 556 | Augmented Bronze Gauntlet | 1:1 mutual-unique; image 643=643; price 30000=30000; weight 10=10; dura 10000=10000 |
| 217 | 龙之手镯 | 506 | Wyvern Bracelet | 1:1 mutual-unique; image 702=702; weight 1=1; dura 5000=5000 |
| 219 | 幽灵项链 | 334 | Claw Necklace | 1:1 mutual-unique; image 813=813; weight 1=1; dura 9000=9000; level 27=27 |
| 222 | 鹿血 | 791 | Elixir Of Purification | 1:1 mutual-unique; image 32=32 |
| 242 | 万年雪霜 | 323 | Ginseng Of Eternity | 1:1 mutual-unique; image 70=70; HP 170=170; MP 250=250 |
| 261 | 金盒 | 1097 | Gold Chest | 1:1 mutual-unique; image 127=127 |
| 262 | 攻击神水（中） | 263 | Elixir Of Destruction (II) | 1:1 mutual-unique; image 84=84; weight 5=5 |
| 263 | 自然神水（中） | 283 | Elixir Of Nature (II) | 1:1 mutual-unique; image 82=82; weight 5=5 |
| 264 | 灵魂神水（中） | 464 | Elixir Of Spirit (II) | 1:1 mutual-unique; image 81=81; weight 5=5 |
| 265 | 疾风神水（中） | 268 | Elixir Of Haste (II) | 1:1 mutual-unique; image 80=80; weight 5=5 |
| 266 | 体力强效神水（中） | 273 | Elixir Of Life (II) | 1:1 mutual-unique; image 85=85; weight 5=5 |
| 267 | 魔力强效神水（中） | 278 | Elixir Of Mana (II) | 1:1 mutual-unique; image 83=83; weight 5=5 |
| 268 | 攻击神水（大） | 264 | Elixir Of Destruction (III) | 1:1 mutual-unique; image 84=84; weight 9=9 |
| 269 | 自然神水（大） | 284 | Elixir Of Nature (III) | 1:1 mutual-unique; image 82=82; weight 9=9 |
| 270 | 灵魂神水（大） | 465 | Elixir Of Spirit (III) | 1:1 mutual-unique; image 81=81; weight 9=9 |
| 271 | 体力强效神水（大） | 274 | Elixir Of Life (III) | 1:1 mutual-unique; image 85=85; weight 9=9 |
| 272 | 魔力强效神水（大） | 279 | Elixir Of Mana (III) | 1:1 mutual-unique; image 83=83; weight 9=9 |
| 279 | 疾风神水（大） | 269 | Elixir Of Haste (III) | 1:1 mutual-unique; image 80=80; weight 9=9 |
| 282 | 魔血戒指 | 364 | Signet Of Vigor | 1:1 mutual-unique; image 593=593; weight 1=1; dura 5000=5000 |
| 283 | 魔血手镯 | 365 | Arm Wrap Of Vigor | 1:1 mutual-unique; image 763=763; weight 1=1; dura 6000=6000 |
| 284 | 魔血项链 | 366 | Pendant Of Vigor | 1:1 mutual-unique; image 913=913; weight 2=2; dura 7000=7000 |
| 285 | 虹魔戒指 | 372 | Ring Of Life Stealing | 1:1 mutual-unique; image 592=592; weight 1=1; dura 5000=5000 |
| 286 | 虹魔手镯 | 373 | Wrist Guard Of Life Stealing | 1:1 mutual-unique; image 762=762; weight 1=1; dura 6000=6000 |
| 295 | 玉水晶 | 827 | Pure Quartz | 1:1 mutual-unique; image 1141=1141 |
| 299 | 战神盔甲（男） | 335 | Iron Plate Armour (M) | 1:1 mutual-unique; image 981=981; weight 51=51; dura 30000=30000; level 33=33 |
| 300 | 战神盔甲（女） | 336 | Iron Plate Armour (F) | 1:1 mutual-unique; image 991=991; weight 51=51; dura 30000=30000; level 33=33 |
| 301 | 恶魔长袍（男） | 337 | Robe Of Dark Flame (M) | 1:1 mutual-unique; image 1021=1021; price 30000=30000; weight 17=17; dura 22000=22000; level 33=33 |
| 302 | 恶魔长袍（女） | 338 | Robe Of Dark Flame (F) | 1:1 mutual-unique; image 1031=1031; price 30000=30000; weight 17=17; dura 22000=22000; level 33=33 |
| 303 | 幽灵战衣（男） | 339 | Robe Of Balance (M) | 1:1 mutual-unique; image 1001=1001; price 30000=30000; weight 28=28; dura 24000=24000; level 33=33 |
| 304 | 幽灵战衣（女） | 340 | Robe Of Balance (F) | 1:1 mutual-unique; image 1011=1011; price 30000=30000; weight 28=28; dura 24000=24000; level 33=33 |
| 305 | 无名刀 | 430 | Valor Blade | 1:1 mutual-unique; image 1062=1062; price 23000=23000; weight 25=25; dura 24000=24000; level 33=33 |
| 313 | 鸡血 | 438 | Chicken Blood | 1:1 mutual-unique; image 31=31; price 10=10; weight 1=1; HP 5=5; MP 5=5 |
| 324 | 斗笠 | 382 | Bamboo Hat | 1:1 mutual-unique; image 411=411; price 8000=8000; weight 4=4; dura 8000=8000; level 27=27 |
| 325 | 翔空剑法 | 9 | Dragon Rise | skill book: SKILL_MAP '翔空剑法'->skill#8 'Dragon Rise'; price 1000=1000; level(DuraMax 35=RequiredAmount 35) |
| 326 | 莲月剑法 | 10 | Blade Storm | skill book: SKILL_MAP '莲月剑法'->skill#9 'Blade Storm'; price 1000=1000; level(DuraMax 38=RequiredAmount 38) |
| 328 | 月魂断玉 | 64 | Evil Slayer | skill book: SKILL_MAP '月魂断玉'->skill#63 'Evil Slayer'; price 1000=1000; level(DuraMax 14=RequiredAmount 14) |
| 329 | 冰月神掌 | 26 | Ice Bolt | skill book: SKILL_MAP '冰月神掌'->skill#25 'Ice Bolt'; price 1000=1000; level(DuraMax 9=RequiredAmount 9) |
| 330 | 冰月震天 | 33 | Ice Blades | skill book: SKILL_MAP '冰月震天'->skill#32 'Ice Blades'; price 1000=1000; level(DuraMax 17=RequiredAmount 17) |
| 331 | 霹雳掌 | 25 | Lightning Ball | skill book: SKILL_MAP '霹雳掌'->skill#24 'Lightning Ball'; price 1000=1000; level(DuraMax 8=RequiredAmount 8) |
| 332 | 月魂灵波 | 68 | Greater Evil Slayer | skill book: SKILL_MAP '月魂灵波'->skill#67 'Greater Evil Slayer'; price 1000=1000; level(DuraMax 24=RequiredAmount 24) |
| 333 | 墨龙屠龙 | 823 | Muk's Obsidian Giant Blade | 1:1 mutual-unique; price 30000=30000; weight 100=100; dura 36000=36000; level 36=36 |
| 334 | 墨龙嗜魂法杖 | 825 | Muk's Staff Of Retribution | 1:1 mutual-unique; image 1085=1085; price 30000=30000; weight 16=16; dura 19000=19000; level 36=36 |
| 335 | 墨龙龙纹剑 | 824 | Muk's Divine Blade Of Judgement | 1:1 mutual-unique; price 30000=30000; weight 37=37; dura 26000=26000; level 36=36 |
| 348 | 金刚铃铛 | 432 | Amulet Of Ancient Kingdom | 1:1 mutual-unique; image 914=914; weight 1=1; dura 7000=7000 |
| 353 | 霹雷 | 635 | Sword Of Abyss | 1:1 mutual-unique; image 1074=1074; price 80000=80000; dura 35000=35000 |
| 402 | 天机戒指 | 396 | Ring Of Endless Circle | 1:1 mutual-unique; image 476=476; weight 2=2; dura 5000=5000 |
| 404 | 天鸣戒指 | 384 | Ring Of Dawn | 1:1 mutual-unique; image 493=493; price 8000=8000; weight 1=1; dura 5000=5000; level 25=25 |
| 405 | 火玉戒指 | 474 | Band Of Magic | 1:1 mutual-unique; image 513=513; weight 1=1; dura 4000=4000; level 25=25 |
| 406 | 五彩项链 | 345 | Puple Crystal Pendant | 1:1 mutual-unique; image 854=854; weight 1=1; dura 6000=6000; level 30=30 |
| 407 | 遗魂项链 | 472 | Choker Of Ashes | 1:1 mutual-unique; image 833=833; price 25000=25000; weight 1=1; dura 7000=7000; level 30=30 |
| 436 | 荣耀项链 | 385 | Battle Necklace | 1:1 mutual-unique; image 837=837; weight 2=2; dura 9000=9000; level 25=25 |
| 440 | 行者帽 | 560 | Turban Of Discipline | 1:1 mutual-unique; image 413=413; price 15000=15000; weight 5=5; dura 8000=8000 |
| 441 | 战神头盔 | 324 | Helmet Of The War God | 1:1 mutual-unique; image 414=414; price 30000=30000; weight 20=20; dura 10000=10000 |
| 442 | 虎面头盔 | 325 | Crown Of Feral Lord | 1:1 mutual-unique; image 415=415; price 30000=30000; weight 4=4; dura 8000=8000 |
| 443 | 旋风流星刀 | 621 | Fury Blade | 1:1 mutual-unique; image 1049=1049; price 60000=60000; weight 87=87; dura 35000=35000 |
| 445 | 飞魂魔刃 | 622 | Twisted Blade Of Souls | 1:1 mutual-unique; image 1061=1061; price 60000=60000; weight 18=18; dura 19000=19000 |
| 446 | 虚空道环 | 536 | Loop Of Secrets | 1:1 mutual-unique; image 479=479; weight 1=1; dura 5000=5000 |
| 448 | 红叶血环 | 492 | Red Maple Ring | 1:1 mutual-unique; image 499=499; weight 2=2; dura 7000=7000; level 26=26 |
| 449 | 六棱戒 | 530 | Ring Of Unification | 1:1 mutual-unique; image 498=498; weight 2=2; dura 7000=7000 |
| 450 | 紫金环 | 397 | Ancient Myrmidon Band | 1:1 mutual-unique; image 497=497; weight 3=3; dura 7000=7000 |
| 451 | 武圣之戒 | 398 | Loop Of Endless Combat | 1:1 mutual-unique; image 496=496; weight 4=4; dura 7000=7000 |
| 487 | 七彩金环 | 399 | Loop Of Seven Gems | 1:1 mutual-unique; image 478=478; weight 2=2; dura 5000=5000 |
| 494 | 心魔戒指 | 326 | Glowing Diamond Band | 1:1 mutual-unique; image 477=477; weight 1=1; dura 4000=4000 |
| 507 | 宝玉 | 493 | Jewel | 1:1 mutual-unique; image 1424=1424; price 1000=1000 |
| 509 | 制魔油 | 803 | Venom | 1:1 mutual-unique; image 60=60 |
| 510 | 牛肉 | 181 | Beef | 1:1 mutual-unique; image 300=300; price 250=250; dura 10000=10000 |
| 511 | 猪肉 | 180 | Pork | 1:1 mutual-unique; image 300=300; price 180=180; dura 10000=10000 |
| 523 | 狼肉 | 183 | Wolf Meat | 1:1 mutual-unique; image 300=300; price 300=300; dura 10000=10000 |
| 537 | 蚂蚁卵 | 260 | Ant Egg | 1:1 mutual-unique; image 102=102; price 600=600 |
| 585 | 回生神水 | 583 | Potion Of Repentance | 1:1 mutual-unique; image 64=64; price 100=100; weight 10=10 |
| 591 | 魔灵戒指 | 624 | Band Of Netherworld | 1:1 mutual-unique; image 495=495; price 30000=30000; weight 1=1; dura 6000=6000 |
| 592 | 石榴戒指 | 625 | Diamond Encrusted Band | 1:1 mutual-unique; image 516=516; weight 1=1; dura 5000=5000 |
| 593 | 青摇戒指 | 626 | Perfection Ring | 1:1 mutual-unique; image 536=536; weight 1=1; dura 7000=7000 |
| 595 | 莲丸戒指 | 627 | Universe Ring | 1:1 mutual-unique; image 537=537; weight 1=1; dura 7000=7000 |
| 596 | 冰沙掌 | 37 | Frozen Earth | skill book: SKILL_MAP '冰沙掌'->skill#36 'Frozen Earth'; price 1000=1000; level(DuraMax 22=RequiredAmount 22) |
| 597 | 铁系项链 | 628 | Iron Plate Necklace | 1:1 mutual-unique; image 878=878; price 20000=20000; weight 1=1; dura 8000=8000 |
| 598 | 追魂项链 | 629 | Amulet Of Absorption | 1:1 mutual-unique; image 892=892; weight 1=1; dura 6000=6000 |
| 599 | 追风项链 | 630 | Pendant Of Wind Elemental | 1:1 mutual-unique; image 893=893; weight 1=1; dura 8000=8000 |
| 600 | 魔令项链 | 631 | Soul Trapped Necklace | 1:1 mutual-unique; image 894=894; weight 1=1; dura 7000=7000 |
| 601 | 全能戒指 | 682 | Hero's Band Of Supremacy | 1:1 mutual-unique; image 517=517; price 50000=50000; weight 2=2; dura 6000=6000 |
| 610 | 风掌 | 27 | Gust Blast | skill book: SKILL_MAP '风掌'->skill#26 'Gust Blast'; price 1000=1000; level(DuraMax 10=RequiredAmount 10) |
| 614 | 气血项链 | 387 | Amulet Of Empowerment | 1:1 mutual-unique; image 916=916; weight 2=2; dura 8000=8000 |
| 615 | 龙卷风 | 46 | Dragon Tornado | skill book: SKILL_MAP '龙卷风'->skill#45 'Dragon Tornado'; price 1000=1000; level(DuraMax 35=RequiredAmount 35) |
| 616 | 风震天 | 38 | Blow Earth | skill book: SKILL_MAP '风震天'->skill#37 'Blow Earth'; price 1000=1000; level(DuraMax 23=RequiredAmount 23) |
| 617 | 击风 | 34 | Cyclone | skill book: SKILL_MAP '击风'->skill#33 'Cyclone'; price 1000=1000; level(DuraMax 18=RequiredAmount 18) |
| 618 | 流星项链 | 400 | Meteorite Pendant | 1:1 mutual-unique; image 898=898; price 30000=30000; weight 4=4; dura 9000=9000 |
| 619 | 毁灭魔链 | 516 | Amulet Of The Cult Leader | 1:1 mutual-unique; image 899=899; weight 3=3; dura 8000=8000 |
| 620 | 回生术 | 75 | Resurrection | skill book: SKILL_MAP '回生术'->skill#74 'Resurrection'; price 1000=1000; level(DuraMax 35=RequiredAmount 35) |
| 621 | 震天项链 | 473 | Necklace Of Nature | 1:1 mutual-unique; image 896=896; weight 1=1; dura 6000=6000; level 29=29 |
| 622 | 五行神镜 | 517 | Amulet Of Five Elements | 1:1 mutual-unique; image 915=915; weight 1=1; dura 6000=6000 |
| 623 | 银镜项链 | 343 | Tri Stone Necklace | 1:1 mutual-unique; image 895=895; price 23000=23000; weight 1=1; dura 7000=7000; level 29=29 |
| 625 | 武器强化油 | 297 | Oil Of Conservation | 1:1 mutual-unique; image 53=53; price 10000=10000; weight 1=1 |
| 626 | 黑皮手套 | 388 | Gloves Of Black Guard | 1:1 mutual-unique; image 669=669; price 20000=20000; weight 5=5; dura 8000=8000; level 32=32 |
| 627 | 铁炼腕 | 376 | Dark Iron Gauntlet | 1:1 mutual-unique; image 667=667; price 30000=30000; weight 9=9; dura 8000=8000 |
| 628 | 英雄手套 | 389 | Gauntlet Of Hero | 1:1 mutual-unique; image 666=666; price 30000=30000; weight 12=12 |
| 632 | 强魔震法 | 72 | Elemental Superiority | skill book: SKILL_MAP '强魔震法'->skill#71 'Elemental Superiority'; price 1000=1000; level(DuraMax 29=RequiredAmount 29) |
| 633 | 月光鞋 | 519 | Boots Of Despair | 1:1 mutual-unique; image 1371=1371; price 30000=30000; weight 2=2; dura 8000=8000 |
| 635 | 无影靴 | 587 | Shadow Chaser | 1:1 mutual-unique; image 1373=1373; price 30000=30000; weight 4=4; dura 12000=12000 |
| 636 | 五彩鞋 | 390 | Brightly Coloured Shoes | 1:1 mutual-unique; image 1374=1374; price 8000=8000; weight 1=1; dura 8000=8000; level 26=26 |
| 637 | 猛虎强势 | 74 | Blood Lust | skill book: SKILL_MAP '猛虎强势'->skill#73 'Blood Lust'; price 1000=1000; level(DuraMax 34=RequiredAmount 34) |
| 638 | 仙云靴 | 520 | Boots Of Swiftness | 1:1 mutual-unique; image 1375=1375; price 30000=30000; weight 4=4; dura 12000=12000 |
| 639 | 武神之靴 | 318 | Boots Of Crimson Steed | 1:1 mutual-unique; image 1376=1376; price 50000=50000; weight 4=4; dura 12000=12000 |
| 640 | 绝地靴 | 521 | Boots Of Levitation | 1:1 mutual-unique; image 1377=1377; price 30000=30000; weight 2=2; dura 8000=8000 |
| 647 | 异形换位 | 41 | Geo Manipulation | skill book: SKILL_MAP '异形换位'->skill#40 'Geo Manipulation'; price 1000=1000; level(DuraMax 27=RequiredAmount 27) |
| 649 | 鞋子 | 844 | Lupine Greaves | 1:1 mutual-unique; image 1384=1384 |
| 651 | 破山剑 | 683 | Apocalypse | manual anchor (verified): price 100000=100000; dur 35000=35000; image Looks1041=Image1041 |
| 653 | 拐杖 | 669 | Talon Staff Of A'Ryong | 1:1 mutual-unique; image 1087=1087; dura 20000=20000 |
| 655 | 封魔剑 | 632 | Celestial Blade | 1:1 mutual-unique; image 1046=1046; price 60000=60000; weight 36=36; dura 26000=26000 |
| 661 | 震天魔印 | 551 | Runed Emblem | 1:1 mutual-unique; image 1441=1441; price 1600=1600 |
| 662 | 思念珍珠 | 437 | Sanyum Bead | 1:1 mutual-unique; image 1346=1346; price 1400=1400 |
| 668 | 复血 | 368 | Pendant Of Courage | 1:1 mutual-unique; image 818=818; weight 3=3; dura 9000=9000 |
| 669 | 沃玛头盔 | 317 | White Skull Helmet | 1:1 mutual-unique; image 373=373; price 6000=6000; weight 5=5; dura 8000=8000; level 21=21 |
| 670 | 天藤头盔 | 391 | Iron Wood Helmet | 1:1 mutual-unique; image 410=410; price 9000=9000; weight 6=6; dura 8000=8000; level 29=29 |
| 675 | 双刃剑 | 328 | Bone Claymore | 1:1 mutual-unique; image 1044=1044; price 8500=8500; weight 33=33; dura 22000=22000; level 26=26 |
| 684 | 乾坤一气 | 518 | Amulet Of The Enlightened | 1:1 mutual-unique; image 897=897; weight 2=2; dura 7000=7000 |
| 712 | 白月银蛇戒指 | 209 | White Serpent Ring | 1:1 mutual-unique; image 511=511; price 6000=6000; weight 1=1; dura 4000=4000; level 19=19 |
| 723 | 蓝光凝霜 | 522 | Blue Sword Of Purification | 1:1 mutual-unique; price 10000=10000; weight 40=40; dura 22000=22000; level 28=28 |
| 726 | 诺玛族修罗 | 494 | Numa Power Axe | 1:1 mutual-unique; image 1250=1250; price 9000=9000; weight 50=50; dura 26000=26000; level 27=27 |
| 727 | 诅咒银蛇 | 497 | Cursed Serpent Sword | 1:1 mutual-unique; image 1231=1231; price 9000=9000; weight 23=23; dura 22000=22000; level 27=27 |
| 728 | 诺玛族魔杖 | 495 | Numa Mage Staff | 1:1 mutual-unique; image 1280=1280; price 9000=9000; weight 12=12; dura 13000=13000; level 27=27 |
| 730 | 腐烂骷髅头盔 | 407 | Laurel Mask | 1:1 mutual-unique; price 12000=12000; weight 6=6; dura 8000=8000; level 35=35 |
| 741 | 幸运降妖除魔戒指 | 401 | Blessed Ring Of Exorcism | 1:1 mutual-unique; image 474=474; price 20000=20000; weight 2=2; dura 6000=6000; level 34=34 |
| 743 | 潘夜命运之刃 | 507 | Enchanted Blade Of Banya | 1:1 mutual-unique; image 1170=1170; price 23000=23000; weight 61=61; dura 28000=28000 |
| 744 | 潘夜银蛇 | 523 | Serpent Sword Of Banya | 1:1 mutual-unique; image 1233=1233; price 20000=20000; weight 27=27; dura 22000=22000; level 31=31 |
| 745 | 潘夜魔杖 | 524 | Banya Mage Staff | 1:1 mutual-unique; image 1281=1281; price 20000=20000; weight 14=14; dura 14000=14000; level 31=31 |
| 749 | 骷髅骨 | 256 | Skeleton Bone | 1:1 mutual-unique; image 103=103; price 200=200 |
| 752 | 祖玛裁决之杖 | 402 | Zuma Judgement Mace | 1:1 mutual-unique; image 1302=1302; weight 80=80; dura 32000=32000; level 33=33 |
| 753 | 祖玛无极棍 | 403 | Zuma Runed Staff | 1:1 mutual-unique; image 1260=1260; price 23000=23000; weight 29=29; dura 24000=24000; level 33=33 |
| 754 | 祖玛骨玉权杖 | 404 | Zuma Dragon Bone Staff | 1:1 mutual-unique; image 1193=1193; price 23000=23000; weight 14=14; dura 15000=15000; level 33=33 |
| 760 | 亮蜡烛 | 157 | Bright Candle | 1:1 mutual-unique; image 290=290; price 30=30; weight 1=1; dura 8000=8000 |
| 768 | 亮火把 | 159 | Bright Torch | 1:1 mutual-unique; image 291=291; price 1500=1500; weight 3=3; dura 20000=20000 |
| 769 | 草鞋 | 235 | Straw Sandles | 1:1 mutual-unique; image 1360=1360; price 1000=1000; weight 1=1; dura 6000=6000; level 6=6 |
| 770 | 皮靴 | 236 | Leather Shoes | 1:1 mutual-unique; image 1361=1361; price 5000=5000; weight 1=1; dura 8000=8000; level 16=16 |
| 771 | 赤飞靴子 | 525 | Rugged Leather Boots | 1:1 mutual-unique; image 1363=1363; price 10000=10000; weight 2=2; dura 10000=10000; level 33=33 |
| 772 | 黑皮靴子 | 526 | Boots Of Black Tortoise | 1:1 mutual-unique; image 1364=1364; price 30000=30000; weight 3=3; dura 12000=12000 |
| 773 | 天掌靴子 | 527 | Silk Boots | 1:1 mutual-unique; image 1362=1362; price 20000=20000; weight 2=2; dura 10000=10000 |
| 774 | 潘夜珠 | 332 | Banya Gem Stone | 1:1 mutual-unique; image 1349=1349; price 600=600 |
| 775 | 潘夜之泪 | 528 | Tears Of Banya | 1:1 mutual-unique; image 1348=1348; price 800=800 |
| 776 | 夜明珠 | 508 | Dark Banya Gem Stone | 1:1 mutual-unique; image 1350=1350; price 1400=1400 |
| 777 | 超强召唤骷髅 | 216 | Summon Jin Skeleton | skill book: SKILL_MAP '超强召唤骷髅'->skill#132 'Summon Jin Skeleton'; price 1000=1000; level(DuraMax 33=RequiredAmount 33) |
| 779 | 牙齿 | 245 | Tooth | 1:1 mutual-unique; image 1431=1431; price 800=800 |
| 782 | 蜘蛛线 | 369 | Spider Web Thread | 1:1 mutual-unique; image 105=105; price 1000=1000 |
| 785 | 金创药（特） | 136 | Healing Potion (IV) | manual anchor (verified): price 1250=1250; image Looks8=Image8; Health 170=170 |
| 787 | 魔法药（特） | 146 | Mana Potion (IV) | manual anchor (verified): image Looks18=Image18; Mana 250=250; price 1250->1375 (tier) |
| 801 | 皮 | 322 | Husk | 1:1 mutual-unique; image 107=107; price 800=800 |
| 807 | 指甲 | 378 | Claw | 1:1 mutual-unique; image 1340=1340; price 1200=1200 |
| 808 | 神灵雕像 | 405 | Statue Fragment | 1:1 mutual-unique; image 1430=1430; price 1400=1400 |
| 809 | 僵尸骨头 | 258 | Zombie Bone | 1:1 mutual-unique; image 1149=1149; price 400=400 |
| 811 | 灵魂护身符（小） | 228 | Talisman Of Soul | 1:1 mutual-unique; image 1150=1150; weight 2=2 |
| 817 | 霸龙头盔 | 561 | Helmet Of The Conqueror | 1:1 mutual-unique; image 412=412; price 18000=18000; weight 7=7; dura 8000=8000 |
| 820 | 紫水晶 | 542 | Amethyst | 1:1 mutual-unique; image 217=217; price 500=500; weight 4=4; dura 10000=10000 |
| 821 | 石榴石 | 543 | Garnet | 1:1 mutual-unique; image 218=218; price 1000=1000; weight 4=4; dura 10000=10000 |
| 822 | 金刚石 | 544 | Diamond | manual anchor (verified): price 2500=2500; weight 4=4; dura 10000=10000; image 219=219 |
| 824 | 风之鹤嘴锄 | 817 | Pick Axe Of Wind | 1:1 mutual-unique; image 1048=1048; price 30000=30000; weight 21=21; dura 30000=30000 |
| 825 | 跳蚤皮 | 261 | Flea Husk | 1:1 mutual-unique; image 1444=1444; price 400=400 |
| 827 | 潘夜血饮 | 509 | Mage Sword Of Banya | 1:1 mutual-unique; image 1083=1083; price 25000=25000; weight 15=15; dura 16000=16000; level 34=34 |
| 837 | 龙鳞战甲（男） | 562 | Enchanted Iron Plate Armour (M) | 1:1 mutual-unique; image 982=982; weight 61=61; dura 35000=35000; level 38=38 |
| 838 | 龙鳞战甲（女） | 563 | Enchanted Iron Plate Armour (F) | 1:1 mutual-unique; image 992=992; weight 61=61; dura 35000=35000; level 38=38 |
| 839 | 袁灵法衣（男） | 564 | Robe Of Conjurer (M) | 1:1 mutual-unique; image 1022=1022; price 50000=50000; weight 20=20; dura 23000=23000; level 38=38 |
| 840 | 袁灵法衣（女） | 565 | Robe Of Conjurer (F) | 1:1 mutual-unique; image 1032=1032; price 50000=50000; weight 20=20; dura 23000=23000; level 38=38 |
| 841 | 天极道衣（男） | 566 | Robe Of Preserver (M) | 1:1 mutual-unique; image 1002=1002; price 50000=50000; weight 30=30; dura 26000=26000; level 38=38 |
| 842 | 天极道衣（女） | 567 | Robe Of Preserver (F) | 1:1 mutual-unique; image 1012=1012; price 50000=50000; weight 30=30; dura 26000=26000; level 38=38 |
| 847 | 火玉手镯 | 377 | Tainted Bracelet | 1:1 mutual-unique; image 684=684; weight 3=3; dura 8000=8000 |
| 851 | 勇士项链 | 344 | Butcher's Necklace | 1:1 mutual-unique; image 835=835; weight 2=2; dura 9000=9000; level 30=30 |
| 852 | 破坏项链 | 482 | Pendant Of Destruction | 1:1 mutual-unique; image 836=836; price 30000=30000; weight 4=4; dura 9000=9000 |
| 856 | 真善项链 | 206 | Necklace Of Meditation | 1:1 mutual-unique; image 830=830; price 5000=5000; weight 1=1; dura 7000=7000; level 15=15 |
| 859 | 指环 | 160 | Plain Ring | 1:1 mutual-unique; image 530=530; price 500=500; weight 1=1; dura 6000=6000; level 5=5 |
| 866 | 号角 | 356 | Horn | 1:1 mutual-unique; image 1338=1338; price 600=600 |
| 896 | 圣山项链 | 866 | Symbol Of Holy Grounds | 1:1 mutual-unique; image 879=879; price 30000=30000; weight 2=2; dura 9000=9000 |
| 900 | 心念手镯 | 867 | Holy Bracer Of Grace | 1:1 mutual-unique; image 741=741; price 30000=30000; weight 6=6; dura 7000=7000 |
| 905 | 玫瑰 | 793 | Thorned Rose | 1:1 mutual-unique; image 88=88 |
| 988 | 生锈师承戒指 | 640 | Rusty Signet Of Myrmidon | 1:1 mutual-unique; image 538=538; price 1000=1000; weight 1=1 |
| 989 | 生锈龙马戒指 | 641 | Rusty Signet Of Evoker | 1:1 mutual-unique; image 518=518; price 1000=1000; weight 1=1 |
| 990 | 生锈青云戒指 | 642 | Rusty Signet Of Vicar | 1:1 mutual-unique; image 553=553; price 1000=1000; weight 1=1 |
| 991 | 生锈破荒项链 | 643 | Rusty Charm Of The Destroyer | 1:1 mutual-unique; image 819=819; price 1000=1000; weight 1=1 |
| 992 | 生锈魔云项链 | 644 | Rusty Amulet Of Dark Sorcery | 1:1 mutual-unique; image 859=859; price 1000=1000; weight 1=1 |
| 993 | 生锈定心项链 | 645 | Rusty Pendant Of Purification | 1:1 mutual-unique; image 839=839; price 1000=1000; weight 1=1 |
| 994 | 生锈金棱手镯 | 646 | Rusty Bracer Of Revelation | 1:1 mutual-unique; image 685=685; price 1000=1000; weight 1=1 |
| 995 | 生锈思过手镯 | 647 | Rusty Ring Of Enlightenment | 1:1 mutual-unique; image 703=703; price 1000=1000; weight 1=1 |
| 996 | 生锈世尊手镯 | 648 | Rusty Bracelet Of Ascension | 1:1 mutual-unique; image 725=725; price 1000=1000; weight 1=1 |
| 1026 | 天赐战甲（女） | 693 | Ghost Armour (F) | 1:1 mutual-unique; image 994=994; weight 25=25; dura 25000=25000 |
| 1029 | 神勇之物 | 649 | Courage Of Kelsar | 1:1 mutual-unique; image 917=917; price 50000=50000; weight 1=1; dura 10000=10000 |
| 1030 | 决断之物 | 651 | Determination Of Tanguere | 1:1 mutual-unique; image 766=766; price 50000=50000; weight 1=1; dura 10000=10000 |
| 1031 | 节制之物 | 650 | Temperance Of Hunta | 1:1 mutual-unique; image 765=765; price 50000=50000; weight 1=1; dura 10000=10000 |
| 1032 | 正义之物 | 653 | Justice Of Natura | 1:1 mutual-unique; image 596=596; price 50000=50000; weight 1=1; dura 10000=10000 |
| 1033 | 智慧之物 | 652 | Wisdom Of Dumachi | 1:1 mutual-unique; image 595=595; price 50000=50000; weight 1=1; dura 10000=10000 |
| 1078 | 黄玫瑰 | 794 | Guardian Angel's Flower | 1:1 mutual-unique; image 89=89 |
| 1099 | 灵魂之刃 | 670 | Calamity | 1:1 mutual-unique; image 1078=1078 |
| 1109 | 恶魔铁轮 | 500 | Ambitious Glaive Of Doom | 1:1 mutual-unique; image 1088=1088 |
| 1110 | 游龙扇 | 499 | Ambitious Warden's Fan Of Obedience | 1:1 mutual-unique; image 1107=1107 |
| 1111 | 破雷剑 | 498 | Ambitious Sword Of Abyss | 1:1 mutual-unique; image 1077=1077 |
| 1112 | 碎冰破天 | 672 | Bracelet Of Canopus | 1:1 mutual-unique; image 767=767; dura 8000=8000 |
| 1113 | 飞冰泣雪 | 678 | The Master's Bracelet | 1:1 mutual-unique; image 769=769 |
| 1114 | 寻冰踏月 | 675 | Dazzling Bracelet Of Earth | 1:1 mutual-unique; image 768=768 |
| 1115 | 碎冰倚天 | 673 | Ring Of Alpha Centauri | 1:1 mutual-unique; image 597=597 |
| 1116 | 飞冰残雪 | 676 | Brilliant Band Of Harmony | 1:1 mutual-unique; image 598=598 |
| 1117 | 寻冰逐月 | 679 | The Master's Ring | 1:1 mutual-unique; image 599=599 |
| 1119 | 飞冰舞雪 | 674 | Celestial Necklace Of Eternity | 1:1 mutual-unique; image 798=798 |

## pending — 候选，待人工确认（82）

| mud3_index | mud3_name | → zircon_index | zircon_en | evidence |
|---:|---|---:|---|---|
| 3 | 肉 | 182 | Deer Meat | PROPOSED, human confirmation required (never auto-closed); anchors: image 300=300; price 200=200; dura 10000=10000; alternatives: #252 Mutton [image 300=300; price 200=200; dura 10000=10000]; #180 Pork [image 300=300; dura 10000=10000]; #181 Beef [image 300=300; dura 10000=10000]; #183 Wolf Meat [image 300=300; dura 10000=10000] |
| 9 | 轻型盔甲（男） | 188 | Light Armour (M) | PROPOSED, human confirmation required (never auto-closed); anchors: price 5000=5000; weight 8=8; dura 8000=8000; level 11=11; alternatives: #189 Light Armour (F) [price 5000=5000; weight 8=8; dura 8000=8000; level 11=11]; #190 Shroud Of Stealth (M) [price 5000=5000; dura 8000=8000; level 11=11]; #191 Shroud Of Stealth (F) [price 5000=5000; dura 8000=8000; level 11=11] |
| 10 | 轻型盔甲（女） | 189 | Light Armour (F) | PROPOSED, human confirmation required (never auto-closed); anchors: price 5000=5000; weight 8=8; dura 8000=8000; level 11=11; alternatives: #188 Light Armour (M) [price 5000=5000; weight 8=8; dura 8000=8000; level 11=11]; #190 Shroud Of Stealth (M) [price 5000=5000; dura 8000=8000; level 11=11]; #191 Shroud Of Stealth (F) [price 5000=5000; dura 8000=8000; level 11=11] |
| 13 | 凝霜 | 357 | Sword Of Purification | PROPOSED, human confirmation required (never auto-closed); anchors: price 8000=8000; weight 33=33; dura 20000=20000; level 25=25; alternatives: #471 Assassin's Ripper [price 8000=8000; weight 33=33; dura 20000=20000; level 25=25]; #328 Bone Claymore [image 1044=1044; weight 33=33] |
| 35 | 炼狱 | 428 | Great Axe | PROPOSED, human confirmation required (never auto-closed); anchors: image 1066=1066; price 23000=23000; weight 70=70; dura 30000=30000; level 33=33; alternatives: #431 White Lotus Glaive [price 23000=23000; dura 30000=30000; level 33=33] |
| 119 | 小手镯 | 171 | Bracelet Of Exertion | PROPOSED, human confirmation required (never auto-closed); anchors: image 660=660; weight 1=1; dura 8000=8000; level 15=15 |
| 140 | 愤怒之钟（冰） | 475 | Pendant Of Wrath | PROPOSED, human confirmation required (never auto-closed); anchors: image 856=856; weight 1=1; dura 6000=6000; level 25=25; alternatives: #310 Pendant Of Image [price 15000=15000; weight 1=1; dura 6000=6000] |
| 148 | 探测项链 | 305 | Pendant Of Tracking | PROPOSED, human confirmation required (never auto-closed); anchors: image 890=890; dura 8000=8000; alternatives: #301 Choker Of Learning [price 50000=50000; weight 1=1; dura 8000=8000] |
| 162 | 祖玛头像 | 394 | Fragment Of Zuma King | PROPOSED, human confirmation required (never auto-closed); anchors: image 101=101; price 1000=1000; weight 1=1; alternatives: #667 Relic Fragment [image 101=101; price 1000=1000; level 1=1] |
| 166 | 血饮 | 429 | Mage Sword | PROPOSED, human confirmation required (never auto-closed); anchors: image 1083=1083; price 23000=23000; weight 13=13; dura 20000=20000; level 33=33 |
| 232 | 莲花宝镜（暗黑） | 386 | Phantom Choker | PROPOSED, human confirmation required (never auto-closed); anchors: image 817=817; price 15000=15000; weight 1=1; dura 7000=7000; level 25=25 |
| 252 | 参加活动卷 | 483 | Freedom Pass | PROPOSED, human confirmation required (never auto-closed); anchors: image 180=180; price 50=50 |
| 254 | 攻击神水（小） | 262 | Elixir Of Destruction | PROPOSED, human confirmation required (never auto-closed); anchors: image 84=84; weight 3=3 |
| 255 | 自然神水（小） | 282 | Elixir Of Nature | PROPOSED, human confirmation required (never auto-closed); anchors: image 82=82; weight 3=3 |
| 256 | 灵魂神水（小） | 463 | Elixir Of Spirit | PROPOSED, human confirmation required (never auto-closed); anchors: image 81=81; weight 3=3 |
| 257 | 疾风神水（小） | 267 | Elixir Of Haste | PROPOSED, human confirmation required (never auto-closed); anchors: image 80=80; weight 3=3 |
| 258 | 体力强效神水（小） | 272 | Elixir Of Life | PROPOSED, human confirmation required (never auto-closed); anchors: image 85=85; weight 3=3 |
| 259 | 魔法强效神水（小） | 277 | Elixir Of Mana | PROPOSED, human confirmation required (never auto-closed); anchors: image 83=83; weight 3=3 |
| 273 | 攻击神水（特） | 265 | Elixir Of Destruction (IV) | PROPOSED, human confirmation required (never auto-closed); anchors: image 84=84; weight 13=13; alternatives: #262 Elixir Of Destruction [image 84=84; price 10000=10000] |
| 274 | 自然神水（特） | 285 | Elixir Of Nature (IV) | PROPOSED, human confirmation required (never auto-closed); anchors: image 82=82; weight 13=13; alternatives: #282 Elixir Of Nature [image 82=82; price 10000=10000] |
| 275 | 灵魂神水（特） | 466 | Elixir Of Spirit (IV) | PROPOSED, human confirmation required (never auto-closed); anchors: image 81=81; weight 13=13; alternatives: #463 Elixir Of Spirit [image 81=81; price 10000=10000] |
| 276 | 体力强效神水（特） | 275 | Elixir Of Life (IV) | PROPOSED, human confirmation required (never auto-closed); anchors: image 85=85; weight 13=13; alternatives: #272 Elixir Of Life [image 85=85; price 10000=10000] |
| 277 | 魔力强效神水（特） | 280 | Elixir Of Mana (IV) | PROPOSED, human confirmation required (never auto-closed); anchors: image 83=83; weight 13=13; alternatives: #277 Elixir Of Mana [image 83=83; price 10000=10000] |
| 278 | 疾风神水（特） | 270 | Elixir Of Haste (IV) | PROPOSED, human confirmation required (never auto-closed); anchors: image 80=80; weight 13=13; alternatives: #267 Elixir Of Haste [image 80=80; price 10000=10000] |
| 287 | 虹魔项链 | 374 | Pendant Of Life Stealing | PROPOSED, human confirmation required (never auto-closed); anchors: image 912=912; dura 7000=7000; alternatives: #486 Necklace Of Evasion [price 30000=30000; weight 1=1; dura 7000=7000] |
| 349 | 金刚魔法指环 | 433 | Nature Band Of Ancient Kingdom | PROPOSED, human confirmation required (never auto-closed); anchors: image 594=594; weight 1=1; dura 5000=5000; alternatives: #434 Spirit Band Of Ancient Kingdom [image 594=594; weight 1=1; dura 5000=5000] |
| 350 | 金刚精神戒指 | 434 | Spirit Band Of Ancient Kingdom | PROPOSED, human confirmation required (never auto-closed); anchors: image 594=594; weight 1=1; dura 5000=5000; alternatives: #433 Nature Band Of Ancient Kingdom [image 594=594; weight 1=1; dura 5000=5000] |
| 351 | 金刚防御手镯 | 435 | Armoured Bracer Of Ancient Kingdom | PROPOSED, human confirmation required (never auto-closed); anchors: image 764=764; weight 1=1; dura 6000=6000; alternatives: #436 Holy Bracer Of Ancient Kingdom [image 764=764; weight 1=1; dura 6000=6000]; #487 Dark Blade [price 30000=30000; weight 1=1; dura 6000=6000]; #488 Bracelet Of Evasion [price 30000=30000; weight 1=1; dura 6000=6000] |
| 352 | 金刚魔法手镯 | 436 | Holy Bracer Of Ancient Kingdom | PROPOSED, human confirmation required (never auto-closed); anchors: image 764=764; weight 1=1; dura 6000=6000; alternatives: #435 Armoured Bracer Of Ancient Kingdom [image 764=764; weight 1=1; dura 6000=6000]; #487 Dark Blade [price 30000=30000; weight 1=1; dura 6000=6000]; #488 Bracelet Of Evasion [price 30000=30000; weight 1=1; dura 6000=6000] |
| 354 | 铁轮 | 636 | Glaive Of Doom | PROPOSED, human confirmation required (never auto-closed); anchors: image 1086=1086; price 80000=80000; dura 18000=18000 |
| 355 | 逍遥扇 | 637 | Warden's Fan Of Obedience | PROPOSED, human confirmation required (never auto-closed); anchors: image 1105=1105; price 80000=80000; dura 25000=25000 |
| 359 | 雷神戒指 | 558 | Blue Jade Signet | PROPOSED, human confirmation required (never auto-closed); anchors: image 857=857; weight 1=1; dura 4000=4000 |
| 360 | 毁灭手镯 | 480 | Ring Of Destruction | PROPOSED, human confirmation required (never auto-closed); anchors: image 683=683; weight 1=1; dura 5000=5000 |
| 361 | 神谕项链 | 367 | Pendant Of Luminary | PROPOSED, human confirmation required (never auto-closed); anchors: image 858=858; weight 1=1; dura 6000=6000 |
| 362 | 昏暗风印 | 481 | Amulet Of Chaos | PROPOSED, human confirmation required (never auto-closed); anchors: image 816=816; weight 1=1; dura 6000=6000 |
| 363 | 润神戒指 | 559 | Loop Of Reincarnation | PROPOSED, human confirmation required (never auto-closed); anchors: image 475=475; weight 2=2; dura 5000=5000 |
| 364 | 如来手镯 | 375 | Bracer Of Artisan | PROPOSED, human confirmation required (never auto-closed); anchors: image 663=663; price 30000=30000; weight 2=2; dura 6000=6000 |
| 365 | 猫眼 | 477 | Amulet Of Wisdom | PROPOSED, human confirmation required (never auto-closed); anchors: image 838=838; price 30000=30000; weight 2=2; dura 7000=7000; alternatives: #478 Pendent Of Holy Spirit [price 30000=30000; weight 2=2; dura 7000=7000] |
| 366 | 怨恨项链 | 395 | Amulet Of Vanquishment | PROPOSED, human confirmation required (never auto-closed); anchors: image 815=815; weight 2=2; dura 7000=7000; alternatives: #477 Amulet Of Wisdom [price 30000=30000; weight 2=2; dura 7000=7000]; #478 Pendent Of Holy Spirit [price 30000=30000; weight 2=2; dura 7000=7000] |
| 376 | 七点白蛇胆汁 | 243 | Snake Gall | PROPOSED, human confirmation required (never auto-closed); anchors: image 1341=1341; price 100=100 |
| 394 | 触龙神皮 | 253 | !Shell Fragment | PROPOSED, human confirmation required (never auto-closed); anchors: image 108=108 |
| 403 | 巨龙戒指 | 383 | Fierce Dragon Ring | PROPOSED, human confirmation required (never auto-closed); anchors: image 534=534; weight 2=2; dura 7000=7000; level 25=25; alternatives: #533 Gold Dragon Ring [image 534=534; weight 2=2; dura 7000=7000] |
| 422 | 战士的证票 | 255 | !Bat Fang (OLD) | PROPOSED, human confirmation required (never auto-closed); anchors: image 1453=1453 |
| 447 | 移动炼狱 | 431 | White Lotus Glaive | PROPOSED, human confirmation required (never auto-closed); anchors: price 23000=23000; dura 30000=30000; level 33=33; alternatives: #428 Great Axe [image 1066=1066; price 23000=23000; weight 70=70; dura 30000=30000; level 33=33] |
| 524 | 羊肉 | 252 | Mutton | PROPOSED, human confirmation required (never auto-closed); anchors: image 300=300; price 200=200; dura 10000=10000; alternatives: #182 Deer Meat [image 300=300; price 200=200; dura 10000=10000]; #180 Pork [image 300=300; dura 10000=10000]; #181 Beef [image 300=300; dura 10000=10000]; #183 Wolf Meat [image 300=300; dura 10000=10000] |
| 631 | 诅咒之药水 | 634 | Potion Of Oblivion | PROPOSED, human confirmation required (never auto-closed); anchors: image 64=64; price 100=100; weight 2=2; alternatives: #534 Potion Of Forgetfulness [image 64=64; price 100=100; weight 2=2]; #583 Potion Of Repentance [image 64=64; price 100=100] |
| 634 | 亡灵之药水 | 534 | Potion Of Forgetfulness | PROPOSED, human confirmation required (never auto-closed); anchors: image 64=64; price 100=100; weight 2=2; dura 1000=1000; alternatives: #634 Potion Of Oblivion [image 64=64; price 100=100; weight 2=2; dura 1000=1000]; #583 Potion Of Repentance [image 64=64; price 100=100] |
| 664 | 天神法杖 | 684 | Heavenly Staff Of Immortality | PROPOSED, human confirmation required (never auto-closed); anchors: image 1047=1047; price 100000=100000; dura 19000=19000 |
| 736 | 神圣道士头盔 | 321 | Assassination Mask | PROPOSED, human confirmation required (never auto-closed); anchors: price 6000=6000; dura 8000=8000; level 21=21; alternatives: #311 Helmet Of Shaman [image 372=372; weight 3=3; dura 8000=8000]; #317 White Skull Helmet [price 6000=6000; dura 8000=8000; level 21=21] |
| 784 | 阿才的书 | 3 | Potion Mastery | PROPOSED, human confirmation required (never auto-closed); anchors: image 304=304; weight 1=1; alternatives: #2 Swordsmanship [image 304=304; weight 1=1]; #4 Slaying [image 304=304; weight 1=1]; #5 Thrusting [image 304=304; weight 1=1]; #6 Half Moon [image 304=304; weight 1=1] |
| 823 | 钢玉矿石 | 545 | Corundum | PROPOSED, human confirmation required (never auto-closed); anchors: image 220=220; price 6000=6000; weight 4=4; dura 10000=10000; alternatives: #540 Gold Ore [price 6000=6000; weight 4=4; dura 10000=10000] |
| 829 | 潘夜无极棍 | 510 | Runed Staff Of Banya | PROPOSED, human confirmation required (never auto-closed); anchors: price 25000=25000; weight 33=33; dura 24000=24000; level 34=34; alternatives: #548 Runed Staff [image 1103=1103; weight 33=33; dura 24000=24000] |
| 843 | 帝王戒指 | 568 | Ring Of Sovereignty | PROPOSED, human confirmation required (never auto-closed); anchors: image 515=515; weight 4=4; dura 7000=7000 |
| 868 | 诺玛王雕像 | 667 | Relic Fragment | PROPOSED, human confirmation required (never auto-closed); anchors: image 101=101; price 1000=1000; level 1=1; alternatives: #394 Fragment Of Zuma King [image 101=101; price 1000=1000; weight 1=1] |
| 889 | 泰轮拂尘 | 668 | Heavenly Blade Of Tranquility | PROPOSED, human confirmation required (never auto-closed); anchors: price 100000=100000; weight 37=37; dura 26000=26000; alternatives: #685 Afterlife [image 1106=1106; dura 26000=26000] |
| 890 | 师承戒指 | 658 | Signet Of Myrmidon | PROPOSED, human confirmation required (never auto-closed); anchors: image 538=538; dura 7000=7000 |
| 891 | 龙马戒指 | 659 | Signet Of Evoker | PROPOSED, human confirmation required (never auto-closed); anchors: image 518=518; weight 1=1; dura 5000=5000 |
| 892 | 青云戒指 | 660 | Signet Of Vicar | PROPOSED, human confirmation required (never auto-closed); anchors: image 553=553; price 30000=30000; dura 6000=6000 |
| 893 | 破荒项链 | 661 | Charm Of The Destroyer | PROPOSED, human confirmation required (never auto-closed); anchors: image 819=819; price 30000=30000; weight 3=3; dura 8000=8000 |
| 894 | 魔云项链 | 662 | Amulet Of Dark Sorcery | PROPOSED, human confirmation required (never auto-closed); anchors: image 859=859; weight 1=1; dura 6000=6000 |
| 895 | 定心项链 | 663 | Pendant Of Purification | PROPOSED, human confirmation required (never auto-closed); anchors: image 839=839; weight 2=2; dura 7000=7000; alternatives: #477 Amulet Of Wisdom [price 30000=30000; weight 2=2; dura 7000=7000]; #478 Pendent Of Holy Spirit [price 30000=30000; weight 2=2; dura 7000=7000] |
| 897 | 金棱手镯 | 664 | Bracer Of Revelation | PROPOSED, human confirmation required (never auto-closed); anchors: image 685=685; weight 5=5; dura 8000=8000 |
| 898 | 思过手镯 | 665 | Ring Of Enlightenment | PROPOSED, human confirmation required (never auto-closed); anchors: image 703=703; weight 2=2; dura 5000=5000 |
| 899 | 世尊手镯 | 666 | Bracelet Of Ascension | PROPOSED, human confirmation required (never auto-closed); anchors: image 725=725; weight 3=3; dura 6000=6000 |
| 1021 | 仙风神袍（男） | 571 | Raiment Of Arch Mage (M) | PROPOSED, human confirmation required (never auto-closed); anchors: price 50000=50000; weight 25=25; dura 25000=25000; alternatives: #572 Raiment Of Arch Mage (F) [price 50000=50000; weight 25=25; dura 25000=25000]; #692 Ghost Armour (M) [price 50000=50000; weight 25=25; dura 25000=25000]; #693 Ghost Armour (F) [price 50000=50000; weight 25=25; dura 25000=25000]; #564 Robe Of Conjurer (M) [image 1022=1022; price 50000=50000] |
| 1022 | 仙风神袍（女） | 572 | Raiment Of Arch Mage (F) | PROPOSED, human confirmation required (never auto-closed); anchors: price 50000=50000; weight 25=25; dura 25000=25000; alternatives: #571 Raiment Of Arch Mage (M) [price 50000=50000; weight 25=25; dura 25000=25000]; #692 Ghost Armour (M) [price 50000=50000; weight 25=25; dura 25000=25000]; #693 Ghost Armour (F) [price 50000=50000; weight 25=25; dura 25000=25000]; #565 Robe Of Conjurer (F) [image 1032=1032; price 50000=50000] |
| 1023 | 阴阳圣衣（男） | 573 | Raiment Of High Priest (M) | PROPOSED, human confirmation required (never auto-closed); anchors: price 50000=50000; weight 40=40; dura 29000=29000; alternatives: #574 Raiment Of High Priest (F) [price 50000=50000; weight 40=40; dura 29000=29000]; #566 Robe Of Preserver (M) [image 1002=1002; price 50000=50000] |
| 1024 | 阴阳圣衣（女） | 574 | Raiment Of High Priest (F) | PROPOSED, human confirmation required (never auto-closed); anchors: price 50000=50000; weight 40=40; dura 29000=29000; alternatives: #573 Raiment Of High Priest (M) [price 50000=50000; weight 40=40; dura 29000=29000]; #567 Robe Of Preserver (F) [image 1012=1012; price 50000=50000] |
| 1025 | 天赐战甲（男） | 692 | Ghost Armour (M) | PROPOSED, human confirmation required (never auto-closed); anchors: image 984=984; weight 25=25; dura 25000=25000 |
| 1054 | 魄冰刺 | 47 | Greater Frozen Earth | PROPOSED, human confirmation required; skill book: SKILL_MAP '魄冰刺'->skill#46 'Greater Frozen Earth'; price 50000=1000; level(DuraMax 38=RequiredAmount 38); price/level anchor differs from the current Zircon book |
| 1055 | 怒神霹雳 | 48 | Chain Lightning | PROPOSED, human confirmation required; skill book: SKILL_MAP '怒神霹雳'->skill#47 'Chain Lightning'; price 60000=1000; level(DuraMax 40=RequiredAmount 40); price/level anchor differs from the current Zircon book |
| 1056 | 焰天火雨 | 49 | Meteor Shower | PROPOSED, human confirmation required; skill book: SKILL_MAP '焰天火雨'->skill#48 'Meteor Shower'; price 70000=1000; level(DuraMax 42=RequiredAmount 43); price/level anchor differs from the current Zircon book |
| 1058 | 云寂术 | 76 | Purification | PROPOSED, human confirmation required; skill book: SKILL_MAP '云寂术'->skill#75 'Purification'; price 50000=1000; level(DuraMax 38=RequiredAmount 38); price/level anchor differs from the current Zircon book |
| 1060 | 妙影无踪 | 77 | Transparency | PROPOSED, human confirmation required; skill book: SKILL_MAP '妙影无踪'->skill#76 'Transparency'; price 70000=1000; level(DuraMax 42=RequiredAmount 43); price/level anchor differs from the current Zircon book |
| 1061 | 阴阳法环 | 50 | Renounce | PROPOSED, human confirmation required; skill book: SKILL_MAP '阴阳法环'->skill#49 'Renounce'; price 80000=1000; level(DuraMax 44=RequiredAmount 46); price/level anchor differs from the current Zircon book |
| 1062 | 十方斩 | 11 | Destructive Surge | PROPOSED, human confirmation required; skill book: SKILL_MAP '十方斩'->skill#10 'Destructive Surge'; price 50000=1000; level(DuraMax 40=RequiredAmount 40); price/level anchor differs from the current Zircon book |
| 1063 | 乾坤大挪移 | 12 | Interchange | PROPOSED, human confirmation required; skill book: SKILL_MAP '乾坤大挪移'->skill#11 'Interchange'; price 60000=1000; level(DuraMax 42=RequiredAmount 42); price/level anchor differs from the current Zircon book |
| 1064 | 铁布衫 | 13 | Defiance | PROPOSED, human confirmation required; skill book: SKILL_MAP '铁布衫'->skill#12 'Defiance'; price 70000=1000; level(DuraMax 44=RequiredAmount 33); price/level anchor differs from the current Zircon book |
| 1065 | 斗转星移 | 14 | Beckon | PROPOSED, human confirmation required; skill book: SKILL_MAP '斗转星移'->skill#13 'Beckon'; price 80000=1000; level(DuraMax 46=RequiredAmount 46); price/level anchor differs from the current Zircon book |
| 1066 | 破血狂杀 | 15 | Might | PROPOSED, human confirmation required; skill book: SKILL_MAP '破血狂杀'->skill#14 'Might'; price 90000=1000; level(DuraMax 48=RequiredAmount 48); price/level anchor differs from the current Zircon book |
| 1118 | 碎冰擎天 | 671 | Amulet Of Sirius | PROPOSED, human confirmation required (never auto-closed); anchors: image 797=797; dura 8000=8000; alternatives: #301 Choker Of Learning [price 50000=50000; weight 1=1; dura 8000=8000] |
| 1120 | 寻冰傲月 | 677 | The Master's Pendant | PROPOSED, human confirmation required (never auto-closed); anchors: image 799=799; weight 1=1; alternatives: #301 Choker Of Learning [price 50000=50000; weight 1=1; dura 8000=8000] |

## missing — Mud3 有、Zircon 无（695）

| mud3_index | mud3_name | → zircon_index | zircon_en | evidence |
|---:|---|---:|---|---|
| 11 | 干肉 |  |  | no Zircon counterpart under anchors (price/weight/dura/level/image) |
| 12 | 包子 |  |  | no Zircon counterpart under anchors (price/weight/dura/level/image) |
| 18 | 短剑 |  |  | no Zircon counterpart under anchors (price/weight/dura/level/image) |
| 36 | 凌风 |  |  | no Zircon counterpart under anchors (price/weight/dura/level/image) |
| 37 | 破魂 |  |  | no Zircon counterpart under anchors (price/weight/dura/level/image) |
| 44 | 灰色药粉（小） |  |  | no Zircon counterpart under anchors (price/weight/dura/level/image) |
| 45 | 黄色药粉（小） |  |  | no Zircon counterpart under anchors (price/weight/dura/level/image) |
| 50 | 灰色药粉（中） |  |  | no Zircon counterpart under anchors (price/weight/dura/level/image) |
| 51 | 灰色药粉（大） |  |  | no Zircon counterpart under anchors (price/weight/dura/level/image) |
| 52 | 黄色药粉（中） |  |  | no Zircon counterpart under anchors (price/weight/dura/level/image) |
| 53 | 黄色药粉（大） |  |  | no Zircon counterpart under anchors (price/weight/dura/level/image) |
| 56 | 八荒 |  |  | no Zircon counterpart under anchors (price/weight/dura/level/image) |
| 80 | 地牢逃脱卷 |  |  | no Zircon counterpart under anchors (price/weight/dura/level/image) |
| 104 | 护身符（小） |  |  | no Zircon counterpart under anchors (price/weight/dura/level/image) |
| 114 | 骷髅头盔 |  |  | no free Zircon candidate (all plausible candidates consumed): #317 White Skull Helmet |
| 122 | 凤凰明珠 |  |  | no Zircon counterpart under anchors (price/weight/dura/level/image) |
| 138 | 火焰戒指 |  |  | no free Zircon candidate (all plausible candidates consumed): #354 Gale Ring |
| 139 | 防御戒指 |  |  | no free Zircon candidate (all plausible candidates consumed): #354 Gale Ring |
| 159 | 愤怒之钟（雷） |  |  | no free Zircon candidate (all plausible candidates consumed): #475 Pendant Of Wrath; #310 Pendant Of Image |
| 160 | 愤怒之钟（风） |  |  | no free Zircon candidate (all plausible candidates consumed): #475 Pendant Of Wrath; #310 Pendant Of Image |
| 163 | 兑换卷 |  |  | no Zircon counterpart under anchors (price/weight/dura/level/image) |
| 177 | 行会回城卷 |  |  | no Zircon counterpart under anchors (price/weight/dura/level/image) |
| 178 | 修复油 |  |  | no free Zircon candidate (all plausible candidates consumed): #297 Oil Of Conservation |
| 181 | 生命项链 |  |  | no free Zircon candidate (all plausible candidates consumed): #345 Puple Crystal Pendant; #475 Pendant Of Wrath |
| 187 | 心灵启示 |  |  | no Zircon counterpart under anchors (price/weight/dura/level/image) |
| 193 | 金创药（大）包 |  |  | no Zircon counterpart under anchors (price/weight/dura/level/image) |
| 194 | 魔法药（大）包 |  |  | no Zircon counterpart under anchors (price/weight/dura/level/image) |
| 196 | 骰子 |  |  | no Zircon counterpart under anchors (price/weight/dura/level/image) |
| 197 | 木料 |  |  | no Zircon counterpart under anchors (price/weight/dura/level/image) |
| 199 | 彩卷 |  |  | no Zircon counterpart under anchors (price/weight/dura/level/image) |
| 200 | 祝福道士头盔 |  |  | no free Zircon candidate (all plausible candidates consumed): #311 Helmet Of Shaman |
| 201 | 韩服（男） |  |  | no Zircon counterpart under anchors (price/weight/dura/level/image) |
| 202 | 韩服（女） |  |  | no Zircon counterpart under anchors (price/weight/dura/level/image) |
| 203 | 体验怨恨项链（暗黑） |  |  | no free Zircon candidate (all plausible candidates consumed): #395 Amulet Of Vanquishment |
| 208 | 嗜魂法杖 |  |  | no free Zircon candidate (all plausible candidates consumed): #825 Muk's Staff Of Retribution |
| 210 | 体验怨恨项链（幻影） |  |  | no free Zircon candidate (all plausible candidates consumed): #395 Amulet Of Vanquishment |
| 211 | 鹿茸 |  |  | no Zircon counterpart under anchors (price/weight/dura/level/image) |
| 212 | 命运之书 |  |  | no Zircon counterpart under anchors (price/weight/dura/level/image) |
| 218 | 天珠项链 |  |  | no free Zircon candidate (all plausible candidates consumed): #472 Choker Of Ashes; #314 Necklace Of Spirit Caller; #469 Bamboo Necklace |
| 220 | 米糕 |  |  | no Zircon counterpart under anchors (price/weight/dura/level/image) |
| 221 | 金条 |  |  | no Zircon counterpart under anchors (price/weight/dura/level/image) |
| 223 | 神秘戒指 |  |  | no Zircon counterpart under anchors (price/weight/dura/level/image) |
| 224 | 神秘腰带 |  |  | no free Zircon candidate (all plausible candidates consumed): #506 Wyvern Bracelet |
| 225 | 神秘头盔 |  |  | no Zircon counterpart under anchors (price/weight/dura/level/image) |
| 226 | 神水 |  |  | no free Zircon candidate (all plausible candidates consumed): #534 Potion Of Forgetfulness; #583 Potion Of Repentance; #634 Potion Of Oblivion |
| 227 | 蓝包 |  |  | no Zircon counterpart under anchors (price/weight/dura/level/image) |
| 228 | 红包 |  |  | no Zircon counterpart under anchors (price/weight/dura/level/image) |
| 229 | 绿包 |  |  | no Zircon counterpart under anchors (price/weight/dura/level/image) |
| 230 | 人参 |  |  | no Zircon counterpart under anchors (price/weight/dura/level/image) |
| 231 | 馒头 |  |  | no Zircon counterpart under anchors (price/weight/dura/level/image) |
| 233 | 莲花宝镜（幻影） |  |  | no free Zircon candidate (all plausible candidates consumed): #386 Phantom Choker |
| 234 | 五色项链（火） |  |  | no Zircon counterpart under anchors (price/weight/dura/level/image) |
| 235 | 五色项链（冰） |  |  | no Zircon counterpart under anchors (price/weight/dura/level/image) |
| 236 | 五色项链（雷） |  |  | no Zircon counterpart under anchors (price/weight/dura/level/image) |
| 237 | 五色项链（风） |  |  | no Zircon counterpart under anchors (price/weight/dura/level/image) |
| 238 | 介绍信 |  |  | no Zircon counterpart under anchors (price/weight/dura/level/image) |
| 239 | 红苹果 |  |  | no Zircon counterpart under anchors (price/weight/dura/level/image) |
| 240 | 筹码 |  |  | no Zircon counterpart under anchors (price/weight/dura/level/image) |
| 241 | 特殊药水 |  |  | no Zircon counterpart under anchors (price/weight/dura/level/image) |
| 243 | 金创药（小）包 |  |  | no Zircon counterpart under anchors (price/weight/dura/level/image) |
| 244 | 魔法药（小）包 |  |  | no Zircon counterpart under anchors (price/weight/dura/level/image) |
| 245 | 金创药（中）包 |  |  | no Zircon counterpart under anchors (price/weight/dura/level/image) |
| 246 | 魔法药（中）包 |  |  | no Zircon counterpart under anchors (price/weight/dura/level/image) |
| 247 | 地牢逃脱卷包 |  |  | no Zircon counterpart under anchors (price/weight/dura/level/image) |
| 248 | 随机传送卷包 |  |  | no Zircon counterpart under anchors (price/weight/dura/level/image) |
| 249 | 回城卷包 |  |  | no Zircon counterpart under anchors (price/weight/dura/level/image) |
| 250 | 行会回城卷包 |  |  | no Zircon counterpart under anchors (price/weight/dura/level/image) |
| 251 | 筹码包 |  |  | no Zircon counterpart under anchors (price/weight/dura/level/image) |
| 253 | 水饺 |  |  | no Zircon counterpart under anchors (price/weight/dura/level/image) |
| 260 | 金条包 |  |  | no Zircon counterpart under anchors (price/weight/dura/level/image) |
| 280 | 苹果 |  |  | no Zircon counterpart under anchors (price/weight/dura/level/image) |
| 281 | 赤血宝剑 |  |  | no Zircon counterpart under anchors (price/weight/dura/level/image) |
| 288 | 血剑碎片 |  |  | no Zircon counterpart under anchors (price/weight/dura/level/image) |
| 289 | _水饺200 |  |  | no Zircon counterpart under anchors (price/weight/dura/level/image) |
| 290 | _水饺400 |  |  | no Zircon counterpart under anchors (price/weight/dura/level/image) |
| 291 | _水饺600 |  |  | no Zircon counterpart under anchors (price/weight/dura/level/image) |
| 292 | _水饺800 |  |  | no Zircon counterpart under anchors (price/weight/dura/level/image) |
| 293 | _水饺1000 |  |  | no Zircon counterpart under anchors (price/weight/dura/level/image) |
| 294 | 体验炼狱（火） |  |  | no Zircon counterpart under anchors (price/weight/dura/level/image) |
| 296 | 血魔心脏 |  |  | no Zircon counterpart under anchors (price/weight/dura/level/image) |
| 297 | 魔血油 |  |  | no Zircon counterpart under anchors (price/weight/dura/level/image) |
| 298 | 生死宝刀 |  |  | no Zircon counterpart under anchors (price/weight/dura/level/image) |
| 306 | 袖里剑 |  |  | no Zircon counterpart under anchors (price/weight/dura/level/image) |
| 307 | 标枪 |  |  | no Zircon counterpart under anchors (price/weight/dura/level/image) |
| 308 | 铁枪 |  |  | no Zircon counterpart under anchors (price/weight/dura/level/image) |
| 309 | 白马标志 |  |  | no Zircon counterpart under anchors (price/weight/dura/level/image) |
| 310 | 赤兔马标志 |  |  | no Zircon counterpart under anchors (price/weight/dura/level/image) |
| 311 | 褐色马标志 |  |  | no Zircon counterpart under anchors (price/weight/dura/level/image) |
| 312 | 古籍 |  |  | no Zircon counterpart under anchors (price/weight/dura/level/image) |
| 314 | 烧酒 |  |  | no Zircon counterpart under anchors (price/weight/dura/level/image) |
| 315 | 毒蛇牙齿 |  |  | no Zircon counterpart under anchors (price/weight/dura/level/image) |
| 316 | 王铁匠的铁锤 |  |  | no Zircon counterpart under anchors (price/weight/dura/level/image) |
| 317 | 角笛 |  |  | no Zircon counterpart under anchors (price/weight/dura/level/image) |
| 318 | 半块不死牌 |  |  | no Zircon counterpart under anchors (price/weight/dura/level/image) |
| 319 | 不死牌 |  |  | no Zircon counterpart under anchors (price/weight/dura/level/image) |
| 320 | 雷电僵尸骨 |  |  | no Zircon counterpart under anchors (price/weight/dura/level/image) |
| 321 | 僧侣僵尸骨 |  |  | no Zircon counterpart under anchors (price/weight/dura/level/image) |
| 322 | 毁灭护身符 |  |  | no Zircon counterpart under anchors (price/weight/dura/level/image) |
| 323 | 七点白蛇胆 |  |  | no Zircon counterpart under anchors (price/weight/dura/level/image) |
| 327 | 空拳刀法 |  |  | skill book '空拳刀法': no SKILL_MAP entry / no matching Zircon book |
| 336 | 体验炼狱（冰） |  |  | no Zircon counterpart under anchors (price/weight/dura/level/image) |
| 337 | 体验炼狱（雷） |  |  | no Zircon counterpart under anchors (price/weight/dura/level/image) |
| 338 | 体验炼狱（风） |  |  | no Zircon counterpart under anchors (price/weight/dura/level/image) |
| 339 | 体验银蛇（火） |  |  | no Zircon counterpart under anchors (price/weight/dura/level/image) |
| 340 | 体验银蛇（冰） |  |  | no Zircon counterpart under anchors (price/weight/dura/level/image) |
| 341 | 体验银蛇（雷） |  |  | no Zircon counterpart under anchors (price/weight/dura/level/image) |
| 342 | 体验银蛇（风） |  |  | no Zircon counterpart under anchors (price/weight/dura/level/image) |
| 343 | 韩服（男） |  |  | no Zircon counterpart under anchors (price/weight/dura/level/image) |
| 344 | 体验昏暗封印（冰） |  |  | no free Zircon candidate (all plausible candidates consumed): #481 Amulet Of Chaos |
| 345 | 体验昏暗封印（雷） |  |  | no free Zircon candidate (all plausible candidates consumed): #481 Amulet Of Chaos |
| 346 | 体验昏暗封印（风） |  |  | no free Zircon candidate (all plausible candidates consumed): #481 Amulet Of Chaos |
| 347 | 七点白蛇血 |  |  | no free Zircon candidate (all plausible candidates consumed): #438 Chicken Blood |
| 356 | 劳动蚂蚁卵 |  |  | no Zircon counterpart under anchors (price/weight/dura/level/image) |
| 357 | 诺玛法老珍珠 |  |  | no Zircon counterpart under anchors (price/weight/dura/level/image) |
| 358 | 制炼石 |  |  | no Zircon counterpart under anchors (price/weight/dura/level/image) |
| 367 | 尾毛 |  |  | no Zircon counterpart under anchors (price/weight/dura/level/image) |
| 368 | 汤药 |  |  | no free Zircon candidate (all plausible candidates consumed): #534 Potion Of Forgetfulness; #583 Potion Of Repentance; #634 Potion Of Oblivion |
| 369 | 信件 |  |  | no Zircon counterpart under anchors (price/weight/dura/level/image) |
| 370 | 帐簿 |  |  | no Zircon counterpart under anchors (price/weight/dura/level/image) |
| 371 | 半兽人角笛 |  |  | no Zircon counterpart under anchors (price/weight/dura/level/image) |
| 372 | 不死骨头 |  |  | no Zircon counterpart under anchors (price/weight/dura/level/image) |
| 373 | 尹老人的酒瓶 |  |  | no Zircon counterpart under anchors (price/weight/dura/level/image) |
| 374 | 姜铁匠的斧头 |  |  | no Zircon counterpart under anchors (price/weight/dura/level/image) |
| 375 | 盔甲蚂蚁卵 |  |  | no Zircon counterpart under anchors (price/weight/dura/level/image) |
| 377 | 邪恶钳虫皮 |  |  | no Zircon counterpart under anchors (price/weight/dura/level/image) |
| 378 | 腐蚀人鬼之泪 |  |  | no Zircon counterpart under anchors (price/weight/dura/level/image) |
| 379 | 沃玛勇士号角 |  |  | no Zircon counterpart under anchors (price/weight/dura/level/image) |
| 380 | 钳虫皮 |  |  | no Zircon counterpart under anchors (price/weight/dura/level/image) |
| 381 | 七点白蛇血 |  |  | no free Zircon candidate (all plausible candidates consumed): #438 Chicken Blood |
| 382 | 千年毒蛇牙齿 |  |  | no Zircon counterpart under anchors (price/weight/dura/level/image) |
| 383 | 沃玛角 |  |  | no Zircon counterpart under anchors (price/weight/dura/level/image) |
| 384 | 骷髅精灵骨 |  |  | no Zircon counterpart under anchors (price/weight/dura/level/image) |
| 385 | 啊潘的信件 |  |  | no Zircon counterpart under anchors (price/weight/dura/level/image) |
| 386 | 华玉的信件 |  |  | no Zircon counterpart under anchors (price/weight/dura/level/image) |
| 387 | 比奇历史书 |  |  | no Zircon counterpart under anchors (price/weight/dura/level/image) |
| 388 | 魔灵牌 |  |  | no Zircon counterpart under anchors (price/weight/dura/level/image) |
| 389 | 呼神项链（雷） |  |  | no free Zircon candidate (all plausible candidates consumed): #367 Pendant Of Luminary |
| 390 | 幻影蜘蛛线 |  |  | no Zircon counterpart under anchors (price/weight/dura/level/image) |
| 391 | 呼神项链（火） |  |  | no free Zircon candidate (all plausible candidates consumed): #367 Pendant Of Luminary |
| 392 | 呼神项链（冰） |  |  | no free Zircon candidate (all plausible candidates consumed): #367 Pendant Of Luminary |
| 393 | 血巨人心脏 |  |  | no Zircon counterpart under anchors (price/weight/dura/level/image) |
| 395 | 法师神杖 |  |  | no Zircon counterpart under anchors (price/weight/dura/level/image) |
| 396 | 航海日志 |  |  | no Zircon counterpart under anchors (price/weight/dura/level/image) |
| 397 | 遗骸 |  |  | no Zircon counterpart under anchors (price/weight/dura/level/image) |
| 398 | 七点白蛇牙齿 |  |  | no Zircon counterpart under anchors (price/weight/dura/level/image) |
| 399 | 魔幻戒指 |  |  | no Zircon counterpart under anchors (price/weight/dura/level/image) |
| 400 | 石头 |  |  | no Zircon counterpart under anchors (price/weight/dura/level/image) |
| 401 | 箭 |  |  | no Zircon counterpart under anchors (price/weight/dura/level/image) |
| 408 | 王大人的书信 |  |  | no Zircon counterpart under anchors (price/weight/dura/level/image) |
| 409 | 护卫 |  |  | no Zircon counterpart under anchors (price/weight/dura/level/image) |
| 410 | 护卫的信件 |  |  | no Zircon counterpart under anchors (price/weight/dura/level/image) |
| 411 | 生锈牙轮 |  |  | no Zircon counterpart under anchors (price/weight/dura/level/image) |
| 412 | 汤药 |  |  | no Zircon counterpart under anchors (price/weight/dura/level/image) |
| 413 | 瓷器箱子 |  |  | no Zircon counterpart under anchors (price/weight/dura/level/image) |
| 414 | 旧扇子 |  |  | no Zircon counterpart under anchors (price/weight/dura/level/image) |
| 415 | 怀旧项链 |  |  | no Zircon counterpart under anchors (price/weight/dura/level/image) |
| 416 | 旧娃娃 |  |  | no Zircon counterpart under anchors (price/weight/dura/level/image) |
| 417 | 水晶球 |  |  | no Zircon counterpart under anchors (price/weight/dura/level/image) |
| 418 | 锦秀的衣角 |  |  | no Zircon counterpart under anchors (price/weight/dura/level/image) |
| 419 | 万多罗的护身符 |  |  | no Zircon counterpart under anchors (price/weight/dura/level/image) |
| 420 | 万相的护身符 |  |  | no Zircon counterpart under anchors (price/weight/dura/level/image) |
| 421 | 三妹的护身符 |  |  | no Zircon counterpart under anchors (price/weight/dura/level/image) |
| 423 | 秘密医书 |  |  | no Zircon counterpart under anchors (price/weight/dura/level/image) |
| 424 | 黑野猪牙齿 |  |  | no Zircon counterpart under anchors (price/weight/dura/level/image) |
| 425 | 七点白蛇牙齿10 |  |  | no Zircon counterpart under anchors (price/weight/dura/level/image) |
| 426 | 祖玛卫士雕像 |  |  | no Zircon counterpart under anchors (price/weight/dura/level/image) |
| 427 | 半兽利齿 |  |  | no Zircon counterpart under anchors (price/weight/dura/level/image) |
| 428 | 七点白蛇血 |  |  | no free Zircon candidate (all plausible candidates consumed): #438 Chicken Blood |
| 429 | 千年毒蛇血 |  |  | no free Zircon candidate (all plausible candidates consumed): #438 Chicken Blood |
| 430 | 虎蛇血 |  |  | no free Zircon candidate (all plausible candidates consumed): #438 Chicken Blood |
| 431 | 黑檀雕像 |  |  | no Zircon counterpart under anchors (price/weight/dura/level/image) |
| 432 | 波善的短剑 |  |  | no Zircon counterpart under anchors (price/weight/dura/level/image) |
| 433 | 黑婵项链 |  |  | no Zircon counterpart under anchors (price/weight/dura/level/image) |
| 434 | 消魔的护身符 |  |  | no Zircon counterpart under anchors (price/weight/dura/level/image) |
| 435 | 陈氏护身符 |  |  | no Zircon counterpart under anchors (price/weight/dura/level/image) |
| 437 | 愤怒之钟 |  |  | no free Zircon candidate (all plausible candidates consumed): #475 Pendant Of Wrath; #310 Pendant Of Image |
| 438 | 莲花宝镜 |  |  | no free Zircon candidate (all plausible candidates consumed): #386 Phantom Choker |
| 439 | 魔神怪手镯 |  |  | no Zircon counterpart under anchors (price/weight/dura/level/image) |
| 444 | 角剑 |  |  | no Zircon counterpart under anchors (price/weight/dura/level/image) |
| 452 | 基本剑术（秘籍） |  |  | advanced manual 秘籍: SKILL_MAP '基本剑术'->skill#1 'Swordsmanship'; Zircon keeps one book per spell (already closed to the StdMode 51 sibling as #2 Swordsmanship) -- Mud3-only variant |
| 453 | 攻杀剑术（秘籍） |  |  | advanced manual 秘籍: SKILL_MAP '攻杀剑术'->skill#3 'Slaying'; Zircon keeps one book per spell (already closed to the StdMode 51 sibling as #4 Slaying) -- Mud3-only variant |
| 454 | 刺杀剑术（秘籍） |  |  | advanced manual 秘籍: SKILL_MAP '刺杀剑术'->skill#4 'Thrusting'; Zircon keeps one book per spell (already closed to the StdMode 51 sibling as #5 Thrusting) -- Mud3-only variant |
| 455 | 半月弯刀（秘籍） |  |  | advanced manual 秘籍: SKILL_MAP '半月弯刀'->skill#5 'Half Moon'; Zircon keeps one book per spell (already closed to the StdMode 51 sibling as #6 Half Moon) -- Mud3-only variant |
| 456 | 野蛮冲撞（秘籍） |  |  | advanced manual 秘籍: SKILL_MAP '野蛮冲撞'->skill#6 'Shoulder Dash'; Zircon keeps one book per spell (already closed to the StdMode 51 sibling as #7 Shoulder Dash) -- Mud3-only variant |
| 457 | 烈火剑法（秘籍） |  |  | advanced manual 秘籍: SKILL_MAP '烈火剑法'->skill#7 'Flaming Sword'; Zircon keeps one book per spell (already closed to the StdMode 51 sibling as #8 Flaming Sword) -- Mud3-only variant |
| 458 | 莲月剑法（秘籍） |  |  | advanced manual 秘籍: SKILL_MAP '莲月剑法'->skill#9 'Blade Storm'; Zircon keeps one book per spell (already closed to the StdMode 51 sibling as #10 Blade Storm) -- Mud3-only variant |
| 459 | 翔空剑法（秘籍） |  |  | advanced manual 秘籍: SKILL_MAP '翔空剑法'->skill#8 'Dragon Rise'; Zircon keeps one book per spell (already closed to the StdMode 51 sibling as #9 Dragon Rise) -- Mud3-only variant |
| 460 | 火球术（秘籍） |  |  | advanced manual 秘籍: SKILL_MAP '火球术'->skill#23 'Fire Ball'; Zircon keeps one book per spell (already closed to the StdMode 51 sibling as #24 Fire Ball) -- Mud3-only variant |
| 461 | 诱惑之光（秘籍） |  |  | advanced manual 秘籍: SKILL_MAP '诱惑之光'->skill#28 'Electric Shock'; Zircon keeps one book per spell (already closed to the StdMode 51 sibling as #29 Electric Shock) -- Mud3-only variant |
| 462 | 抗拒火环（秘籍） |  |  | advanced manual 秘籍: SKILL_MAP '抗拒火环'->skill#27 'Repulsion'; Zircon keeps one book per spell (already closed to the StdMode 51 sibling as #28 Repulsion) -- Mud3-only variant |
| 463 | 雷电术（秘籍） |  |  | advanced manual 秘籍: SKILL_MAP '雷电术'->skill#31 'Thunder Bolt'; Zircon keeps one book per spell (already closed to the StdMode 51 sibling as #32 Thunder Bolt) -- Mud3-only variant |
| 464 | 瞬息移动（秘籍） |  |  | advanced manual 秘籍: SKILL_MAP '瞬息移动'->skill#29 'Teleportation'; Zircon keeps one book per spell (already closed to the StdMode 51 sibling as #30 Teleportation) -- Mud3-only variant |
| 465 | 大火球（秘籍） |  |  | advanced manual 秘籍: SKILL_MAP '大火球'->skill#30 'Adamantine Fire Ball'; Zircon keeps one book per spell (already closed to the StdMode 51 sibling as #31 Adamantine Fire Ball) -- Mud3-only variant |
| 466 | 地狱火（秘籍） |  |  | advanced manual 秘籍: SKILL_MAP '地狱火'->skill#34 'Scorched Earth'; Zircon keeps one book per spell (already closed to the StdMode 51 sibling as #35 Scorched Earth) -- Mud3-only variant |
| 467 | 爆裂火焰（秘籍） |  |  | advanced manual 秘籍: SKILL_MAP '爆裂火焰'->skill#42 'Fire Storm'; Zircon keeps one book per spell (already closed to the StdMode 51 sibling as #43 Fire Storm) -- Mud3-only variant |
| 468 | 疾光电影（秘籍） |  |  | advanced manual 秘籍: SKILL_MAP '疾光电影'->skill#35 'Lightning Beam'; Zircon keeps one book per spell (already closed to the StdMode 51 sibling as #36 Lightning Beam) -- Mud3-only variant |
| 469 | 火墙（秘籍） |  |  | advanced manual 秘籍: SKILL_MAP '火墙'->skill#38 'Fire Wall'; Zircon keeps one book per spell (already closed to the StdMode 51 sibling as #39 Fire Wall) -- Mud3-only variant |
| 470 | 地狱雷光（秘籍） |  |  | advanced manual 秘籍: SKILL_MAP '地狱雷光'->skill#43 'Lightning Wave'; Zircon keeps one book per spell (already closed to the StdMode 51 sibling as #44 Lightning Wave) -- Mud3-only variant |
| 471 | 魔法盾（秘籍） |  |  | advanced manual 秘籍: SKILL_MAP '魔法盾'->skill#41 'Magic Shield'; Zircon keeps one book per spell (already closed to the StdMode 51 sibling as #42 Magic Shield) -- Mud3-only variant |
| 472 | 圣言术（秘籍） |  |  | advanced manual 秘籍: SKILL_MAP '圣言术'->skill#39 'Expel Undead'; Zircon keeps one book per spell (already closed to the StdMode 51 sibling as #40 Expel Undead) -- Mud3-only variant |
| 473 | 冰咆哮（秘籍） |  |  | advanced manual 秘籍: SKILL_MAP '冰咆哮'->skill#44 'Ice Storm'; Zircon keeps one book per spell (already closed to the StdMode 51 sibling as #45 Ice Storm) -- Mud3-only variant |
| 474 | 冰月神掌（秘籍） |  |  | advanced manual 秘籍: SKILL_MAP '冰月神掌'->skill#25 'Ice Bolt'; Zircon keeps one book per spell (already closed to the StdMode 51 sibling as #26 Ice Bolt) -- Mud3-only variant |
| 475 | 冰月震天（秘籍） |  |  | advanced manual 秘籍: SKILL_MAP '冰月震天'->skill#32 'Ice Blades'; Zircon keeps one book per spell (already closed to the StdMode 51 sibling as #33 Ice Blades) -- Mud3-only variant |
| 476 | 霹雳掌（秘籍） |  |  | advanced manual 秘籍: SKILL_MAP '霹雳掌'->skill#24 'Lightning Ball'; Zircon keeps one book per spell (already closed to the StdMode 51 sibling as #25 Lightning Ball) -- Mud3-only variant |
| 477 | 精神力战法（秘籍） |  |  | advanced manual 秘籍: SKILL_MAP '精神力战法'->skill#60 'Spirit Sword'; Zircon keeps one book per spell (already closed to the StdMode 51 sibling as #61 Spirit Sword) -- Mud3-only variant |
| 478 | 治愈术（秘籍） |  |  | advanced manual 秘籍: SKILL_MAP '治愈术'->skill#59 'Heal'; Zircon keeps one book per spell (already closed to the StdMode 51 sibling as #60 Heal) -- Mud3-only variant |
| 479 | 施毒术（秘籍） |  |  | advanced manual 秘籍: SKILL_MAP '施毒术'->skill#61 'Poison Dust'; Zircon keeps one book per spell (already closed to the StdMode 51 sibling as #62 Poison Dust) -- Mud3-only variant |
| 480 | 灵魂火符（秘籍） |  |  | advanced manual 秘籍: SKILL_MAP '灵魂火符'->skill#62 'Explosive Talisman'; Zircon keeps one book per spell (already closed to the StdMode 51 sibling as #63 Explosive Talisman) -- Mud3-only variant |
| 481 | 幽灵盾（秘籍） |  |  | advanced manual 秘籍: SKILL_MAP '幽灵盾'->skill#65 'Magic Resistance'; Zircon keeps one book per spell (already closed to the StdMode 51 sibling as #66 Magic Resistance) -- Mud3-only variant |
| 482 | 神圣战甲术（秘籍） |  |  | advanced manual 秘籍: SKILL_MAP '神圣战甲术'->skill#68 'Resilience'; Zircon keeps one book per spell (already closed to the StdMode 51 sibling as #69 Resilience) -- Mud3-only variant |
| 483 | 召唤骷髅（秘籍） |  |  | advanced manual 秘籍: SKILL_MAP '召唤骷髅'->skill#130 'Summon Skeleton'; Zircon keeps one book per spell (already closed to the StdMode 51 sibling as #585 Summon Skeleton) -- Mud3-only variant |
| 484 | 困魔咒（秘籍） |  |  | advanced manual 秘籍: SKILL_MAP '困魔咒'->skill#69 'Trap Octagon'; Zircon keeps one book per spell (already closed to the StdMode 51 sibling as #70 Trap Octagon) -- Mud3-only variant |
| 485 | 隐身术（秘籍） |  |  | advanced manual 秘籍: SKILL_MAP '隐身术'->skill#64 'Invisibility'; Zircon keeps one book per spell (already closed to the StdMode 51 sibling as #65 Invisibility) -- Mud3-only variant |
| 486 | 集体隐身术（秘籍） |  |  | advanced manual 秘籍: SKILL_MAP '集体隐身术'->skill#66 'Mass Invisibility'; Zircon keeps one book per spell (already closed to the StdMode 51 sibling as #67 Mass Invisibility) -- Mud3-only variant |
| 488 | 群体治愈术（秘籍） |  |  | advanced manual 秘籍: SKILL_MAP '群体治愈术'->skill#72 'Mass Heal'; Zircon keeps one book per spell (already closed to the StdMode 51 sibling as #73 Mass Heal) -- Mud3-only variant |
| 489 | 召唤神兽（秘籍） |  |  | advanced manual 秘籍: SKILL_MAP '召唤神兽'->skill#133 'Summon Shinsu'; Zircon keeps one book per spell (already closed to the StdMode 51 sibling as #586 Summon Shinsu) -- Mud3-only variant |
| 490 | 空拳刀法（秘籍） |  |  | advanced manual 秘籍: no SKILL_MAP entry / no matching Zircon book |
| 491 | 月魂断玉（秘籍） |  |  | advanced manual 秘籍: SKILL_MAP '月魂断玉'->skill#63 'Evil Slayer'; Zircon keeps one book per spell (already closed to the StdMode 51 sibling as #64 Evil Slayer) -- Mud3-only variant |
| 492 | 月魂灵波（秘籍） |  |  | advanced manual 秘籍: SKILL_MAP '月魂灵波'->skill#67 'Greater Evil Slayer'; Zircon keeps one book per spell (already closed to the StdMode 51 sibling as #68 Greater Evil Slayer) -- Mud3-only variant |
| 493 | 拓本 |  |  | no Zircon counterpart under anchors (price/weight/dura/level/image) |
| 495 | 破真刀 |  |  | no Zircon counterpart under anchors (price/weight/dura/level/image) |
| 496 | 纱王项链 |  |  | no Zircon counterpart under anchors (price/weight/dura/level/image) |
| 497 | 灵魂明珠 |  |  | no Zircon counterpart under anchors (price/weight/dura/level/image) |
| 498 | 花毒粉 |  |  | no Zircon counterpart under anchors (price/weight/dura/level/image) |
| 499 | 沃毒神精 |  |  | no Zircon counterpart under anchors (price/weight/dura/level/image) |
| 500 | 连环明珠 |  |  | no Zircon counterpart under anchors (price/weight/dura/level/image) |
| 501 | 祖玛卫士明珠 |  |  | no Zircon counterpart under anchors (price/weight/dura/level/image) |
| 502 | 制灵水 |  |  | no Zircon counterpart under anchors (price/weight/dura/level/image) |
| 503 | 真实明镜 |  |  | no Zircon counterpart under anchors (price/weight/dura/level/image) |
| 504 | 祖玛明珠 |  |  | no Zircon counterpart under anchors (price/weight/dura/level/image) |
| 505 | 安心石 |  |  | no Zircon counterpart under anchors (price/weight/dura/level/image) |
| 506 | 诸神道书 |  |  | no Zircon counterpart under anchors (price/weight/dura/level/image) |
| 508 | 祖玛雕像号角 |  |  | no Zircon counterpart under anchors (price/weight/dura/level/image) |
| 512 | 攻杀铁剑 |  |  | no Zircon counterpart under anchors (price/weight/dura/level/image) |
| 513 | 道力护身符 |  |  | no Zircon counterpart under anchors (price/weight/dura/level/image) |
| 514 | 肉汤 |  |  | no Zircon counterpart under anchors (price/weight/dura/level/image) |
| 515 | 灵珠 |  |  | no Zircon counterpart under anchors (price/weight/dura/level/image) |
| 516 | 无名药 |  |  | no Zircon counterpart under anchors (price/weight/dura/level/image) |
| 517 | 千年毒蛇胆汁 |  |  | no Zircon counterpart under anchors (price/weight/dura/level/image) |
| 518 | 胆汁 |  |  | no Zircon counterpart under anchors (price/weight/dura/level/image) |
| 519 | 沃玛角 |  |  | no free Zircon candidate (all plausible candidates consumed): #358 Horn Of Uma King |
| 520 | 战酒 |  |  | no Zircon counterpart under anchors (price/weight/dura/level/image) |
| 521 | 耐久轻型盔甲（男） |  |  | no Zircon counterpart under anchors (price/weight/dura/level/image) |
| 522 | 耐久轻型盔甲（女） |  |  | no Zircon counterpart under anchors (price/weight/dura/level/image) |
| 525 | 不死戒指 |  |  | no free Zircon candidate (all plausible candidates consumed): #581 Skeleton Ring; #208 Coral Ring |
| 526 | 起爆石 |  |  | no Zircon counterpart under anchors (price/weight/dura/level/image) |
| 527 | 树脂 |  |  | no Zircon counterpart under anchors (price/weight/dura/level/image) |
| 528 | 闪电石 |  |  | no Zircon counterpart under anchors (price/weight/dura/level/image) |
| 529 | 树脂魔法长袍（男） |  |  | no free Zircon candidate (all plausible candidates consumed): #194 Flame Robe (M) |
| 530 | 树脂魔法长袍（女） |  |  | no free Zircon candidate (all plausible candidates consumed): #195 Flame Robe (F) |
| 531 | 书信 |  |  | no free Zircon candidate (all plausible candidates consumed): #483 Freedom Pass |
| 532 | 诺玛石 |  |  | no Zircon counterpart under anchors (price/weight/dura/level/image) |
| 533 | 诺玛重盔甲（男） |  |  | no free Zircon candidate (all plausible candidates consumed): #192 Medium Armour (M) |
| 534 | 诺玛重盔甲（女） |  |  | no free Zircon candidate (all plausible candidates consumed): #193 Medium Armour (F) |
| 535 | 神奇灵魂战衣（男） |  |  | no free Zircon candidate (all plausible candidates consumed): #196 Faith Robe (M) |
| 536 | 神奇灵魂战衣（女） |  |  | no free Zircon candidate (all plausible candidates consumed): #197 Faith Robe (F) |
| 538 | 诅咒骷髅精灵头盔 |  |  | no free Zircon candidate (all plausible candidates consumed): #317 White Skull Helmet |
| 539 | 浪雨刀 |  |  | no Zircon counterpart under anchors (price/weight/dura/level/image) |
| 540 | 波纹手镯 |  |  | no free Zircon candidate (all plausible candidates consumed): #381 Gold Plated Bracelet |
| 541 | 白虎剑 |  |  | no Zircon counterpart under anchors (price/weight/dura/level/image) |
| 542 | 灵魂护卫 |  |  | no Zircon counterpart under anchors (price/weight/dura/level/image) |
| 543 | 沃玛神铁锤 |  |  | no Zircon counterpart under anchors (price/weight/dura/level/image) |
| 544 | 无名日志 |  |  | no Zircon counterpart under anchors (price/weight/dura/level/image) |
| 545 | 沃玛金牌 |  |  | no Zircon counterpart under anchors (price/weight/dura/level/image) |
| 546 | 地狱神钟 |  |  | no Zircon counterpart under anchors (price/weight/dura/level/image) |
| 547 | 黑珍珠戒指 |  |  | no free Zircon candidate (all plausible candidates consumed): #172 Black Crystal Ring |
| 548 | 龙骨戒指 |  |  | no free Zircon candidate (all plausible candidates consumed): #581 Skeleton Ring; #208 Coral Ring |
| 549 | 天龙环 |  |  | no free Zircon candidate (all plausible candidates consumed): #383 Fierce Dragon Ring; #533 Gold Dragon Ring |
| 550 | 魔家项链 |  |  | no free Zircon candidate (all plausible candidates consumed): #213 Arisu Necklace |
| 551 | 流星天玉 |  |  | no free Zircon candidate (all plausible candidates consumed): #310 Pendant Of Image |
| 552 | 月光石手镯 |  |  | no free Zircon candidate (all plausible candidates consumed): #361 Bracelet Of Summoning |
| 553 | 天仙之珠 |  |  | no Zircon counterpart under anchors (price/weight/dura/level/image) |
| 554 | 松笛 |  |  | no free Zircon candidate (all plausible candidates consumed): #469 Bamboo Necklace |
| 555 | 八面太极戒指 |  |  | no free Zircon candidate (all plausible candidates consumed): #359 Signet Of Summoning |
| 556 | 伏羲手镯 |  |  | no free Zircon candidate (all plausible candidates consumed): #171 Bracelet Of Exertion |
| 557 | 栗子1 |  |  | no free Zircon candidate (all plausible candidates consumed): #133 Healing Potion |
| 558 | 栗子2 |  |  | no Zircon counterpart under anchors (price/weight/dura/level/image) |
| 559 | 栗子3 |  |  | no free Zircon candidate (all plausible candidates consumed): #153 Rejuvenation Potion; #134 Healing Potion (II); #144 Mana Potion (II) |
| 560 | 栗子4 |  |  | no Zircon counterpart under anchors (price/weight/dura/level/image) |
| 561 | 栗子5 |  |  | no Zircon counterpart under anchors (price/weight/dura/level/image) |
| 562 | 栗子6 |  |  | no Zircon counterpart under anchors (price/weight/dura/level/image) |
| 563 | 栗子7 |  |  | no Zircon counterpart under anchors (price/weight/dura/level/image) |
| 564 | 栗子8 |  |  | no free Zircon candidate (all plausible candidates consumed): #323 Ginseng Of Eternity |
| 565 | 栗子9 |  |  | no Zircon counterpart under anchors (price/weight/dura/level/image) |
| 566 | 栗子10 |  |  | no Zircon counterpart under anchors (price/weight/dura/level/image) |
| 567 | 活动专用褐色栗子 |  |  | no Zircon counterpart under anchors (price/weight/dura/level/image) |
| 568 | 活动专用铜色栗子 |  |  | no Zircon counterpart under anchors (price/weight/dura/level/image) |
| 569 | 活动专用银色栗子 |  |  | no Zircon counterpart under anchors (price/weight/dura/level/image) |
| 570 | 活动专用金色栗子 |  |  | no Zircon counterpart under anchors (price/weight/dura/level/image) |
| 571 | 成致日志 |  |  | no Zircon counterpart under anchors (price/weight/dura/level/image) |
| 572 | 秋夕力量戒指 |  |  | no free Zircon candidate (all plausible candidates consumed): #489 Spiked Ring |
| 573 | 秋夕紫碧螺 |  |  | no free Zircon candidate (all plausible candidates consumed): #490 Opal Ring |
| 574 | 秋夕泰坦戒指 |  |  | no free Zircon candidate (all plausible candidates consumed): #491 Hieroglyphic Ring |
| 575 | 风之黑檀项链 |  |  | no free Zircon candidate (all plausible candidates consumed): #213 Arisu Necklace |
| 576 | 变形银蛇戒指 |  |  | no free Zircon candidate (all plausible candidates consumed): #209 White Serpent Ring; #452 Serpent Ring |
| 577 | 暗黑凤凰明珠 |  |  | no Zircon counterpart under anchors (price/weight/dura/level/image) |
| 578 | 暗黑竹笛 |  |  | no free Zircon candidate (all plausible candidates consumed): #469 Bamboo Necklace |
| 579 | 毒蛇胆汁 |  |  | no free Zircon candidate (all plausible candidates consumed): #243 Snake Gall |
| 580 | 千年毒蛇牙齿 |  |  | no Zircon counterpart under anchors (price/weight/dura/level/image) |
| 581 | 褐色栗子 |  |  | no Zircon counterpart under anchors (price/weight/dura/level/image) |
| 582 | 铜色栗子 |  |  | no Zircon counterpart under anchors (price/weight/dura/level/image) |
| 583 | 银色栗子 |  |  | no Zircon counterpart under anchors (price/weight/dura/level/image) |
| 584 | 金色栗子 |  |  | no Zircon counterpart under anchors (price/weight/dura/level/image) |
| 586 | 霸王教主雕像 |  |  | no Zircon counterpart under anchors (price/weight/dura/level/image) |
| 587 | 老中医的医书 |  |  | no Zircon counterpart under anchors (price/weight/dura/level/image) |
| 588 | _丸药（100） |  |  | no Zircon counterpart under anchors (price/weight/dura/level/image) |
| 589 | _丸药（500） |  |  | no free Zircon candidate (all plausible candidates consumed): #155 Scroll Of Random Teleport |
| 590 | _丸药（2000） |  |  | no Zircon counterpart under anchors (price/weight/dura/level/image) |
| 594 | 火焰沃玛号角 |  |  | no Zircon counterpart under anchors (price/weight/dura/level/image) |
| 602 | 尸王白骨 |  |  | no Zircon counterpart under anchors (price/weight/dura/level/image) |
| 603 | 魔令手镯 |  |  | no Zircon counterpart under anchors (price/weight/dura/level/image) |
| 604 | 参与权 |  |  | no Zircon counterpart under anchors (price/weight/dura/level/image) |
| 605 | 呼神项链（风） |  |  | no free Zircon candidate (all plausible candidates consumed): #367 Pendant Of Luminary |
| 606 | _丸药（1000） |  |  | no Zircon counterpart under anchors (price/weight/dura/level/image) |
| 607 | _丸药（5000） |  |  | no Zircon counterpart under anchors (price/weight/dura/level/image) |
| 608 | _丸药（10000） |  |  | no Zircon counterpart under anchors (price/weight/dura/level/image) |
| 609 | _丸药（20000） |  |  | no Zircon counterpart under anchors (price/weight/dura/level/image) |
| 611 | _丸药（50000） |  |  | no Zircon counterpart under anchors (price/weight/dura/level/image) |
| 612 | 移动无名刀 |  |  | no free Zircon candidate (all plausible candidates consumed): #430 Valor Blade; #403 Zuma Runed Staff |
| 613 | 诺玛药水 |  |  | no Zircon counterpart under anchors (price/weight/dura/level/image) |
| 624 | 沙漠鱼魔牙齿 |  |  | no Zircon counterpart under anchors (price/weight/dura/level/image) |
| 629 | 添加手套2 |  |  | no Zircon counterpart under anchors (price/weight/dura/level/image) |
| 630 | 添加手套4 |  |  | no Zircon counterpart under anchors (price/weight/dura/level/image) |
| 641 | 虎齿刀 |  |  | no Zircon counterpart under anchors (price/weight/dura/level/image) |
| 642 | 青云鞋 |  |  | no Zircon counterpart under anchors (price/weight/dura/level/image) |
| 643 | 足皮 |  |  | no Zircon counterpart under anchors (price/weight/dura/level/image) |
| 644 | 青山鞋 |  |  | no Zircon counterpart under anchors (price/weight/dura/level/image) |
| 645 | 扛造鞋 |  |  | no Zircon counterpart under anchors (price/weight/dura/level/image) |
| 646 | 阿才的书 |  |  | no Zircon counterpart under anchors (price/weight/dura/level/image) |
| 648 | 移动天灵 |  |  | no free Zircon candidate (all plausible candidates consumed): #429 Mage Sword |
| 650 | 红娥宝玉 |  |  | no Zircon counterpart under anchors (price/weight/dura/level/image) |
| 652 | 阴阳刀 |  |  | no Zircon counterpart under anchors (price/weight/dura/level/image) |
| 654 | 神兽 |  |  | no Zircon counterpart under anchors (price/weight/dura/level/image) |
| 656 | 魔镜 |  |  | no Zircon counterpart under anchors (price/weight/dura/level/image) |
| 657 | 花色蜘蛛毒药 |  |  | no Zircon counterpart under anchors (price/weight/dura/level/image) |
| 658 | 武炎铁饼 |  |  | no Zircon counterpart under anchors (price/weight/dura/level/image) |
| 659 | 冰沙掌（秘籍） |  |  | advanced manual 秘籍: SKILL_MAP '冰沙掌'->skill#36 'Frozen Earth'; Zircon keeps one book per spell (already closed to the StdMode 51 sibling as #37 Frozen Earth) -- Mud3-only variant |
| 660 | 法师剑1 |  |  | no Zircon counterpart under anchors (price/weight/dura/level/image) |
| 663 | 法师剑2 |  |  | no Zircon counterpart under anchors (price/weight/dura/level/image) |
| 665 | 稻草人木剑 |  |  | no Zircon counterpart under anchors (price/weight/dura/level/image) |
| 666 | 法师剑4 |  |  | no Zircon counterpart under anchors (price/weight/dura/level/image) |
| 667 | 临时 |  |  | no free Zircon candidate (all plausible candidates consumed): #684 Heavenly Staff Of Immortality |
| 671 | 添加头盔3 |  |  | no free Zircon candidate (all plausible candidates consumed): #560 Turban Of Discipline |
| 672 | 添加头盔4 |  |  | no Zircon counterpart under anchors (price/weight/dura/level/image) |
| 673 | 风掌（秘籍） |  |  | advanced manual 秘籍: SKILL_MAP '风掌'->skill#26 'Gust Blast'; Zircon keeps one book per spell (already closed to the StdMode 51 sibling as #27 Gust Blast) -- Mud3-only variant |
| 674 | 添加头盔5 |  |  | no free Zircon candidate (all plausible candidates consumed): #325 Crown Of Feral Lord |
| 676 | 石人心核 |  |  | no Zircon counterpart under anchors (price/weight/dura/level/image) |
| 677 | 体验破坏项链 |  |  | no free Zircon candidate (all plausible candidates consumed): #482 Pendant Of Destruction |
| 678 | 龙卷风（秘籍） |  |  | advanced manual 秘籍: SKILL_MAP '龙卷风'->skill#45 'Dragon Tornado'; Zircon keeps one book per spell (already closed to the StdMode 51 sibling as #46 Dragon Tornado) -- Mud3-only variant |
| 679 | 风震天（秘籍） |  |  | advanced manual 秘籍: SKILL_MAP '风震天'->skill#37 'Blow Earth'; Zircon keeps one book per spell (already closed to the StdMode 51 sibling as #38 Blow Earth) -- Mud3-only variant |
| 680 | 击风（秘籍） |  |  | advanced manual 秘籍: SKILL_MAP '击风'->skill#33 'Cyclone'; Zircon keeps one book per spell (already closed to the StdMode 51 sibling as #34 Cyclone) -- Mud3-only variant |
| 681 | 体验怨恨项链（神圣） |  |  | no free Zircon candidate (all plausible candidates consumed): #395 Amulet Of Vanquishment |
| 682 | 体验昏暗封印（火） |  |  | no free Zircon candidate (all plausible candidates consumed): #481 Amulet Of Chaos |
| 683 | 回生术（秘籍） |  |  | advanced manual 秘籍: SKILL_MAP '回生术'->skill#74 'Resurrection'; Zircon keeps one book per spell (already closed to the StdMode 51 sibling as #75 Resurrection) -- Mud3-only variant |
| 685 | _献血证 |  |  | no Zircon counterpart under anchors (price/weight/dura/level/image) |
| 686 | 毁灭戒指（风） |  |  | no free Zircon candidate (all plausible candidates consumed): #480 Ring Of Destruction |
| 687 | 怨恨项链（暗黑） |  |  | no free Zircon candidate (all plausible candidates consumed): #395 Amulet Of Vanquishment; #477 Amulet Of Wisdom; #478 Pendent Of Holy Spirit |
| 688 | 怨恨项链（幻影） |  |  | no free Zircon candidate (all plausible candidates consumed): #395 Amulet Of Vanquishment; #477 Amulet Of Wisdom; #478 Pendent Of Holy Spirit |
| 689 | 聚集灵魂火符（秘籍） |  |  | equipment-enchant manual variant (秘籍); Zircon implements this via item affixes, no 1:1 item |
| 690 | 分散灵魂火符（秘籍） |  |  | equipment-enchant manual variant (秘籍); Zircon implements this via item affixes, no 1:1 item |
| 691 | 瑕疵黑檀手镯 |  |  | no Zircon counterpart under anchors (price/weight/dura/level/image) |
| 692 | 蛇谷老人手镯 |  |  | no Zircon counterpart under anchors (price/weight/dura/level/image) |
| 693 | 幽灵盾（雷）（秘籍） |  |  | equipment-enchant manual variant (秘籍); Zircon implements this via item affixes, no 1:1 item |
| 694 | 幽灵盾（风）（秘籍） |  |  | equipment-enchant manual variant (秘籍); Zircon implements this via item affixes, no 1:1 item |
| 695 | 强魔震法（秘籍） |  |  | advanced manual 秘籍: SKILL_MAP '强魔震法'->skill#71 'Elemental Superiority'; Zircon keeps one book per spell (already closed to the StdMode 51 sibling as #72 Elemental Superiority) -- Mud3-only variant |
| 696 | 体验魔杖（火） |  |  | no Zircon counterpart under anchors (price/weight/dura/level/image) |
| 697 | 体验魔杖（冰） |  |  | no Zircon counterpart under anchors (price/weight/dura/level/image) |
| 698 | 润神戒指（暗黑） |  |  | no free Zircon candidate (all plausible candidates consumed): #559 Loop Of Reincarnation |
| 699 | 润神戒指（幻影） |  |  | no free Zircon candidate (all plausible candidates consumed): #559 Loop Of Reincarnation |
| 700 | 猛虎强势（秘籍） |  |  | advanced manual 秘籍: SKILL_MAP '猛虎强势'->skill#73 'Blood Lust'; Zircon keeps one book per spell (already closed to the StdMode 51 sibling as #74 Blood Lust) -- Mud3-only variant |
| 701 | 如来手镯（暗黑） |  |  | no free Zircon candidate (all plausible candidates consumed): #375 Bracer Of Artisan |
| 702 | 如来手镯（幻影） |  |  | no free Zircon candidate (all plausible candidates consumed): #375 Bracer Of Artisan |
| 703 | 昏暗封印（雷） |  |  | no free Zircon candidate (all plausible candidates consumed): #481 Amulet Of Chaos |
| 704 | 昏暗封印（风） |  |  | no free Zircon candidate (all plausible candidates consumed): #481 Amulet Of Chaos |
| 705 | 昏暗封印（冰） |  |  | no free Zircon candidate (all plausible candidates consumed): #481 Amulet Of Chaos |
| 706 | 雷神戒指（雷） |  |  | no free Zircon candidate (all plausible candidates consumed): #558 Blue Jade Signet |
| 707 | 雷神戒指（风） |  |  | no free Zircon candidate (all plausible candidates consumed): #558 Blue Jade Signet |
| 708 | 毁灭戒指（冰） |  |  | no free Zircon candidate (all plausible candidates consumed): #480 Ring Of Destruction |
| 709 | 毁灭戒指（雷） |  |  | no free Zircon candidate (all plausible candidates consumed): #480 Ring Of Destruction |
| 710 | 异形换位（秘籍） |  |  | advanced manual 秘籍: SKILL_MAP '异形换位'->skill#40 'Geo Manipulation'; Zircon keeps one book per spell (already closed to the StdMode 51 sibling as #41 Geo Manipulation) -- Mud3-only variant |
| 711 | 沃毒骷髅戒指 |  |  | no free Zircon candidate (all plausible candidates consumed): #581 Skeleton Ring; #208 Coral Ring |
| 713 | 白眼珍珠戒指 |  |  | no free Zircon candidate (all plausible candidates consumed): #173 Pearl Ring; #468 Ring Of Discipline; #433 Nature Band Of Ancient Kingdom; #434 Spirit Band Of Ancient Kingdom |
| 714 | 金刚黑檀项链 |  |  | no free Zircon candidate (all plausible candidates consumed): #170 Arisu Bracelet |
| 715 | 沃毒小手镯 |  |  | no free Zircon candidate (all plausible candidates consumed): #171 Bracelet Of Exertion |
| 716 | 沃角手镯 |  |  | no free Zircon candidate (all plausible candidates consumed): #451 Bracer Of Magic |
| 717 | 高级重盔甲（男） |  |  | no Zircon counterpart under anchors (price/weight/dura/level/image) |
| 718 | 高级重盔甲（女） |  |  | no Zircon counterpart under anchors (price/weight/dura/level/image) |
| 719 | 高级魔法长袍（男） |  |  | no Zircon counterpart under anchors (price/weight/dura/level/image) |
| 720 | 高级魔法长袍（女） |  |  | no Zircon counterpart under anchors (price/weight/dura/level/image) |
| 721 | 高级灵魂战衣（男） |  |  | no Zircon counterpart under anchors (price/weight/dura/level/image) |
| 722 | 高级灵魂战衣（女） |  |  | no Zircon counterpart under anchors (price/weight/dura/level/image) |
| 724 | 红光偃月 |  |  | no free Zircon candidate (all plausible candidates consumed): #201 War Spear |
| 725 | 黑光降魔 |  |  | no Zircon counterpart under anchors (price/weight/dura/level/image) |
| 729 | 雷之道士头盔 |  |  | no free Zircon candidate (all plausible candidates consumed): #311 Helmet Of Shaman |
| 731 | 蓝竹笛 |  |  | no free Zircon candidate (all plausible candidates consumed): #469 Bamboo Necklace |
| 732 | 腐烂竹笛 |  |  | no free Zircon candidate (all plausible candidates consumed): #469 Bamboo Necklace |
| 733 | 火之道士头盔 |  |  | no free Zircon candidate (all plausible candidates consumed): #311 Helmet Of Shaman |
| 734 | 风之道士头盔 |  |  | no free Zircon candidate (all plausible candidates consumed): #311 Helmet Of Shaman |
| 735 | 冰凉道士头盔 |  |  | no free Zircon candidate (all plausible candidates consumed): #311 Helmet Of Shaman |
| 737 | 暗黑道士头盔 |  |  | no free Zircon candidate (all plausible candidates consumed): #311 Helmet Of Shaman; #317 White Skull Helmet; #321 Assassination Mask |
| 738 | 腐烂道士头盔 |  |  | no free Zircon candidate (all plausible candidates consumed): #311 Helmet Of Shaman |
| 739 | 旧放大镜 |  |  | no free Zircon candidate (all plausible candidates consumed): #310 Pendant Of Image |
| 740 | 旧蓝翡翠项链 |  |  | no free Zircon candidate (all plausible candidates consumed): #309 Blue Jade Necklace; #334 Claw Necklace |
| 742 | 炸铜炼狱 |  |  | no Zircon counterpart under anchors (price/weight/dura/level/image) |
| 746 | 沃玛修罗 |  |  | no Zircon counterpart under anchors (price/weight/dura/level/image) |
| 747 | 沃玛降魔 |  |  | no Zircon counterpart under anchors (price/weight/dura/level/image) |
| 748 | 沃玛偃月 |  |  | no Zircon counterpart under anchors (price/weight/dura/level/image) |
| 750 | 虎蛇牙齿 |  |  | no Zircon counterpart under anchors (price/weight/dura/level/image) |
| 751 | 红蛇血 |  |  | no free Zircon candidate (all plausible candidates consumed): #438 Chicken Blood |
| 755 | 童子像 |  |  | no Zircon counterpart under anchors (price/weight/dura/level/image) |
| 756 | 竹棍 |  |  | no Zircon counterpart under anchors (price/weight/dura/level/image) |
| 757 | 牛毛 |  |  | no Zircon counterpart under anchors (price/weight/dura/level/image) |
| 758 | 苍蝇拍 |  |  | no Zircon counterpart under anchors (price/weight/dura/level/image) |
| 759 | 制魔宝玉 |  |  | no Zircon counterpart under anchors (price/weight/dura/level/image) |
| 761 | 焰火项链 |  |  | no free Zircon candidate (all plausible candidates consumed): #213 Arisu Necklace |
| 762 | 焰火手镯 |  |  | no free Zircon candidate (all plausible candidates consumed): #170 Arisu Bracelet |
| 763 | 闪电眼 |  |  | no free Zircon candidate (all plausible candidates consumed): #209 White Serpent Ring; #452 Serpent Ring |
| 764 | 灵魂铁手镯 |  |  | no free Zircon candidate (all plausible candidates consumed): #161 Iron Bracer; #443 Steel Bracelet |
| 765 | 幻影玉珠 |  |  | no Zircon counterpart under anchors (price/weight/dura/level/image) |
| 766 | 黑除魔戒指 |  |  | no Zircon counterpart under anchors (price/weight/dura/level/image) |
| 767 | 神圣铂金戒指 |  |  | no free Zircon candidate (all plausible candidates consumed): #384 Ring Of Dawn; #532 Platinum Ring |
| 778 | 超强召唤骷髅（秘籍） |  |  | advanced manual 秘籍: SKILL_MAP '超强召唤骷髅'->skill#132 'Summon Jin Skeleton'; Zircon keeps one book per spell (already closed to the StdMode 51 sibling as #216 Summon Jin Skeleton) -- Mud3-only variant |
| 780 | 祝福霸龙头盔 |  |  | no free Zircon candidate (all plausible candidates consumed): #561 Helmet Of The Conqueror |
| 781 | 古诗秘书 |  |  | no Zircon counterpart under anchors (price/weight/dura/level/image) |
| 783 | 浓烟黑檀项链 |  |  | no Zircon counterpart under anchors (price/weight/dura/level/image) |
| 786 | 蝉翼刀 |  |  | no Zircon counterpart under anchors (price/weight/dura/level/image) |
| 788 | 金创药（特）包 |  |  | no Zircon counterpart under anchors (price/weight/dura/level/image) |
| 789 | 魔法药（特）包 |  |  | no Zircon counterpart under anchors (price/weight/dura/level/image) |
| 790 | 耐久铁手镯 |  |  | no free Zircon candidate (all plausible candidates consumed): #161 Iron Bracer; #443 Steel Bracelet |
| 791 | 气霖证书 |  |  | no Zircon counterpart under anchors (price/weight/dura/level/image) |
| 792 | 玉指环 |  |  | no Zircon counterpart under anchors (price/weight/dura/level/image) |
| 793 | 威魂深怨护身符 |  |  | no Zircon counterpart under anchors (price/weight/dura/level/image) |
| 794 | 第一困魔石 |  |  | no Zircon counterpart under anchors (price/weight/dura/level/image) |
| 795 | 第二困魔石 |  |  | no Zircon counterpart under anchors (price/weight/dura/level/image) |
| 796 | 第三困魔石 |  |  | no Zircon counterpart under anchors (price/weight/dura/level/image) |
| 797 | 第四困魔石 |  |  | no Zircon counterpart under anchors (price/weight/dura/level/image) |
| 798 | 最后困魔石 |  |  | no Zircon counterpart under anchors (price/weight/dura/level/image) |
| 799 | 焱火剑 |  |  | no Zircon counterpart under anchors (price/weight/dura/level/image) |
| 800 | 新火镜 |  |  | no Zircon counterpart under anchors (price/weight/dura/level/image) |
| 802 | 断交先生的书信 |  |  | no Zircon counterpart under anchors (price/weight/dura/level/image) |
| 803 | 雷神戒指（冰） |  |  | no free Zircon candidate (all plausible candidates consumed): #558 Blue Jade Signet |
| 804 | 灵魂 |  |  | no Zircon counterpart under anchors (price/weight/dura/level/image) |
| 805 | 汤药 |  |  | no Zircon counterpart under anchors (price/weight/dura/level/image) |
| 806 | 无名油 |  |  | no free Zircon candidate (all plausible candidates consumed): #297 Oil Of Conservation |
| 810 | 护身符（中） |  |  | no Zircon counterpart under anchors (price/weight/dura/level/image) |
| 812 | 灵魂护身符（中） |  |  | no Zircon counterpart under anchors (price/weight/dura/level/image) |
| 813 | 藏罪据证 |  |  | no Zircon counterpart under anchors (price/weight/dura/level/image) |
| 814 | 猫眼（幻影） |  |  | no free Zircon candidate (all plausible candidates consumed): #477 Amulet Of Wisdom; #478 Pendent Of Holy Spirit |
| 815 | 体验魔杖（风） |  |  | no Zircon counterpart under anchors (price/weight/dura/level/image) |
| 816 | 大寰板 |  |  | no Zircon counterpart under anchors (price/weight/dura/level/image) |
| 818 | 猫眼（神圣） |  |  | no free Zircon candidate (all plausible candidates consumed): #477 Amulet Of Wisdom; #478 Pendent Of Holy Spirit |
| 819 | 猫眼（暗黑） |  |  | no free Zircon candidate (all plausible candidates consumed): #477 Amulet Of Wisdom; #478 Pendent Of Holy Spirit |
| 826 | 诅咒海魂 |  |  | no free Zircon candidate (all plausible candidates consumed): #186 Trident |
| 828 | 诅咒半月 |  |  | no Zircon counterpart under anchors (price/weight/dura/level/image) |
| 830 | 幸运青铜头盔 |  |  | no free Zircon candidate (all plausible candidates consumed): #231 Bronze Helmet; #234 Magic Bronze Helmet |
| 831 | 幸运斗笠 |  |  | no free Zircon candidate (all plausible candidates consumed): #382 Bamboo Hat |
| 832 | 幸运骷髅头盔 |  |  | no free Zircon candidate (all plausible candidates consumed): #317 White Skull Helmet |
| 833 | 高级布衣（男） |  |  | no Zircon counterpart under anchors (price/weight/dura/level/image) |
| 834 | 高级布衣（女） |  |  | no Zircon counterpart under anchors (price/weight/dura/level/image) |
| 835 | 高级轻型盔甲（男） |  |  | no Zircon counterpart under anchors (price/weight/dura/level/image) |
| 836 | 高级轻型盔甲（女） |  |  | no Zircon counterpart under anchors (price/weight/dura/level/image) |
| 844 | 润神戒指（神圣） |  |  | no free Zircon candidate (all plausible candidates consumed): #559 Loop Of Reincarnation |
| 845 | 雷神戒指（火） |  |  | no free Zircon candidate (all plausible candidates consumed): #558 Blue Jade Signet |
| 846 | 武士手镯 |  |  | no free Zircon candidate (all plausible candidates consumed): #171 Bracelet Of Exertion; #451 Bracer Of Magic |
| 848 | 毁灭戒指（火） |  |  | no free Zircon candidate (all plausible candidates consumed): #480 Ring Of Destruction |
| 849 | 如来手镯（神圣） |  |  | no free Zircon candidate (all plausible candidates consumed): #375 Bracer Of Artisan |
| 850 | 钻石项链 |  |  | no free Zircon candidate (all plausible candidates consumed): #385 Battle Necklace |
| 853 | 五色项链 |  |  | no free Zircon candidate (all plausible candidates consumed): #366 Pendant Of Vigor |
| 854 | 愤怒之钟（火） |  |  | no free Zircon candidate (all plausible candidates consumed): #475 Pendant Of Wrath; #310 Pendant Of Image |
| 855 | 昏暗封印（火） |  |  | no free Zircon candidate (all plausible candidates consumed): #481 Amulet Of Chaos |
| 857 | 莲花宝镜（神圣） |  |  | no free Zircon candidate (all plausible candidates consumed): #386 Phantom Choker |
| 858 | 怨恨项链（神圣） |  |  | no free Zircon candidate (all plausible candidates consumed): #395 Amulet Of Vanquishment; #477 Amulet Of Wisdom; #478 Pendent Of Holy Spirit |
| 860 | 神圣护身符（小） |  |  | no Zircon counterpart under anchors (price/weight/dura/level/image) |
| 861 | 神圣护身符（中） |  |  | no Zircon counterpart under anchors (price/weight/dura/level/image) |
| 862 | 火焰护身符（小） |  |  | no Zircon counterpart under anchors (price/weight/dura/level/image) |
| 863 | 寒气护身符（小） |  |  | no Zircon counterpart under anchors (price/weight/dura/level/image) |
| 864 | 霹雷护身符（小） |  |  | no Zircon counterpart under anchors (price/weight/dura/level/image) |
| 865 | 狂风护身符（小） |  |  | no Zircon counterpart under anchors (price/weight/dura/level/image) |
| 867 | 雪球 |  |  | no Zircon counterpart under anchors (price/weight/dura/level/image) |
| 869 | 我乃炼狱 |  |  | no Zircon counterpart under anchors (price/weight/dura/level/image) |
| 870 | 我乃裁决之杖 |  |  | no Zircon counterpart under anchors (price/weight/dura/level/image) |
| 871 | 我乃屠龙 |  |  | no Zircon counterpart under anchors (price/weight/dura/level/image) |
| 872 | 我乃魔杖 |  |  | no Zircon counterpart under anchors (price/weight/dura/level/image) |
| 873 | 我乃骨玉权杖 |  |  | no free Zircon candidate (all plausible candidates consumed): #816 Pick Axe |
| 874 | 我乃嗜魂法杖 |  |  | no Zircon counterpart under anchors (price/weight/dura/level/image) |
| 875 | 我乃银蛇 |  |  | no Zircon counterpart under anchors (price/weight/dura/level/image) |
| 876 | 我乃无极棍 |  |  | no Zircon counterpart under anchors (price/weight/dura/level/image) |
| 877 | 我乃龙纹剑 |  |  | no Zircon counterpart under anchors (price/weight/dura/level/image) |
| 878 | 我乃蓝翡翠项链 |  |  | no free Zircon candidate (all plausible candidates consumed): #309 Blue Jade Necklace |
| 879 | 我乃幽灵项链 |  |  | no free Zircon candidate (all plausible candidates consumed): #334 Claw Necklace |
| 880 | 我乃绿色项链 |  |  | no Zircon counterpart under anchors (price/weight/dura/level/image) |
| 881 | 我乃放大镜 |  |  | no free Zircon candidate (all plausible candidates consumed): #310 Pendant Of Image |
| 882 | 我乃生命项链 |  |  | no free Zircon candidate (all plausible candidates consumed): #345 Puple Crystal Pendant |
| 883 | 我乃恶魔铃铛 |  |  | no free Zircon candidate (all plausible candidates consumed): #371 Anti Evil Necklace |
| 884 | 我乃逼真竹笛 |  |  | no free Zircon candidate (all plausible candidates consumed): #469 Bamboo Necklace |
| 885 | 我乃天珠项链 |  |  | no free Zircon candidate (all plausible candidates consumed): #472 Choker Of Ashes |
| 886 | 我乃灵魂项链 |  |  | no Zircon counterpart under anchors (price/weight/dura/level/image) |
| 887 | 箱子 |  |  | no Zircon counterpart under anchors (price/weight/dura/level/image) |
| 888 | 霸群雕像 |  |  | no Zircon counterpart under anchors (price/weight/dura/level/image) |
| 901 | 当啷戒指 |  |  | no Zircon counterpart under anchors (price/weight/dura/level/image) |
| 902 | 阐释戒指 |  |  | no Zircon counterpart under anchors (price/weight/dura/level/image) |
| 903 | 遗物 |  |  | no Zircon counterpart under anchors (price/weight/dura/level/image) |
| 904 | 魔晶石 |  |  | no free Zircon candidate (all plausible candidates consumed): #544 Diamond; #540 Gold Ore; #545 Corundum |
| 906 | 生存游戏场地地图1 |  |  | no Zircon counterpart under anchors (price/weight/dura/level/image) |
| 907 | 生存游戏场地地图2 |  |  | no Zircon counterpart under anchors (price/weight/dura/level/image) |
| 908 | 生存游戏场地地图3 |  |  | no Zircon counterpart under anchors (price/weight/dura/level/image) |
| 909 | 生存游戏场地地图4 |  |  | no Zircon counterpart under anchors (price/weight/dura/level/image) |
| 910 | 钢玉石 |  |  | no free Zircon candidate (all plausible candidates consumed): #545 Corundum; #540 Gold Ore |
| 911 | 新年吉服（男） |  |  | no Zircon counterpart under anchors (price/weight/dura/level/image) |
| 912 | 新年吉服（女） |  |  | no Zircon counterpart under anchors (price/weight/dura/level/image) |
| 913 | 饺子（自然） |  |  | no Zircon counterpart under anchors (price/weight/dura/level/image) |
| 914 | 饺子（灵魂） |  |  | no Zircon counterpart under anchors (price/weight/dura/level/image) |
| 915 | 饺子（攻击） |  |  | no Zircon counterpart under anchors (price/weight/dura/level/image) |
| 916 | 饺子（疾风） |  |  | no Zircon counterpart under anchors (price/weight/dura/level/image) |
| 917 | 饺子（体力） |  |  | no Zircon counterpart under anchors (price/weight/dura/level/image) |
| 918 | 饺子（魔力） |  |  | no Zircon counterpart under anchors (price/weight/dura/level/image) |
| 919 | 汤圆（自然） |  |  | no Zircon counterpart under anchors (price/weight/dura/level/image) |
| 920 | 汤圆（灵魂） |  |  | no Zircon counterpart under anchors (price/weight/dura/level/image) |
| 921 | 汤圆（攻击） |  |  | no Zircon counterpart under anchors (price/weight/dura/level/image) |
| 922 | 汤圆（疾风） |  |  | no Zircon counterpart under anchors (price/weight/dura/level/image) |
| 923 | 汤圆（体力） |  |  | no Zircon counterpart under anchors (price/weight/dura/level/image) |
| 924 | 汤圆（魔力） |  |  | no Zircon counterpart under anchors (price/weight/dura/level/image) |
| 925 | 师承戒指（火） |  |  | no free Zircon candidate (all plausible candidates consumed): #658 Signet Of Myrmidon |
| 926 | 师承戒指（冰） |  |  | no free Zircon candidate (all plausible candidates consumed): #658 Signet Of Myrmidon |
| 927 | 师承戒指（雷） |  |  | no free Zircon candidate (all plausible candidates consumed): #658 Signet Of Myrmidon |
| 928 | 师承戒指（风） |  |  | no free Zircon candidate (all plausible candidates consumed): #658 Signet Of Myrmidon |
| 929 | 师承戒指（神圣） |  |  | no free Zircon candidate (all plausible candidates consumed): #658 Signet Of Myrmidon |
| 930 | 师承戒指（暗黑） |  |  | no free Zircon candidate (all plausible candidates consumed): #658 Signet Of Myrmidon |
| 931 | 师承戒指（幻影） |  |  | no free Zircon candidate (all plausible candidates consumed): #658 Signet Of Myrmidon |
| 932 | 龙马戒指（火） |  |  | no free Zircon candidate (all plausible candidates consumed): #659 Signet Of Evoker |
| 933 | 龙马戒指（冰） |  |  | no free Zircon candidate (all plausible candidates consumed): #659 Signet Of Evoker |
| 934 | 龙马戒指（雷） |  |  | no free Zircon candidate (all plausible candidates consumed): #659 Signet Of Evoker |
| 935 | 龙马戒指（风） |  |  | no free Zircon candidate (all plausible candidates consumed): #659 Signet Of Evoker |
| 936 | 龙马戒指（神圣） |  |  | no free Zircon candidate (all plausible candidates consumed): #659 Signet Of Evoker |
| 937 | 龙马戒指（暗黑） |  |  | no free Zircon candidate (all plausible candidates consumed): #659 Signet Of Evoker |
| 938 | 龙马戒指（幻影） |  |  | no free Zircon candidate (all plausible candidates consumed): #659 Signet Of Evoker |
| 939 | 青云戒指（火） |  |  | no free Zircon candidate (all plausible candidates consumed): #660 Signet Of Vicar |
| 940 | 青云戒指（冰） |  |  | no free Zircon candidate (all plausible candidates consumed): #660 Signet Of Vicar |
| 941 | 青云戒指（雷） |  |  | no free Zircon candidate (all plausible candidates consumed): #660 Signet Of Vicar |
| 942 | 青云戒指（风） |  |  | no free Zircon candidate (all plausible candidates consumed): #660 Signet Of Vicar |
| 943 | 青云戒指（神圣） |  |  | no free Zircon candidate (all plausible candidates consumed): #660 Signet Of Vicar |
| 944 | 青云戒指（暗黑） |  |  | no free Zircon candidate (all plausible candidates consumed): #660 Signet Of Vicar |
| 945 | 青云戒指（幻影） |  |  | no free Zircon candidate (all plausible candidates consumed): #660 Signet Of Vicar |
| 946 | 破荒项链（火） |  |  | no free Zircon candidate (all plausible candidates consumed): #661 Charm Of The Destroyer |
| 947 | 破荒项链（冰） |  |  | no free Zircon candidate (all plausible candidates consumed): #661 Charm Of The Destroyer |
| 948 | 破荒项链（雷） |  |  | no free Zircon candidate (all plausible candidates consumed): #661 Charm Of The Destroyer |
| 949 | 破荒项链（风） |  |  | no free Zircon candidate (all plausible candidates consumed): #661 Charm Of The Destroyer |
| 950 | 破荒项链（神圣） |  |  | no free Zircon candidate (all plausible candidates consumed): #661 Charm Of The Destroyer |
| 951 | 破荒项链（暗黑） |  |  | no free Zircon candidate (all plausible candidates consumed): #661 Charm Of The Destroyer |
| 952 | 破荒项链（幻影） |  |  | no free Zircon candidate (all plausible candidates consumed): #661 Charm Of The Destroyer |
| 953 | 魔云项链（火） |  |  | no free Zircon candidate (all plausible candidates consumed): #662 Amulet Of Dark Sorcery |
| 954 | 魔云项链（冰） |  |  | no free Zircon candidate (all plausible candidates consumed): #662 Amulet Of Dark Sorcery |
| 955 | 魔云项链（雷） |  |  | no free Zircon candidate (all plausible candidates consumed): #662 Amulet Of Dark Sorcery |
| 956 | 魔云项链（风） |  |  | no free Zircon candidate (all plausible candidates consumed): #662 Amulet Of Dark Sorcery |
| 957 | 魔云项链（神圣） |  |  | no free Zircon candidate (all plausible candidates consumed): #662 Amulet Of Dark Sorcery |
| 958 | 魔云项链（暗黑） |  |  | no free Zircon candidate (all plausible candidates consumed): #662 Amulet Of Dark Sorcery |
| 959 | 魔云项链（幻影） |  |  | no free Zircon candidate (all plausible candidates consumed): #662 Amulet Of Dark Sorcery |
| 960 | 定心项链（火） |  |  | no free Zircon candidate (all plausible candidates consumed): #663 Pendant Of Purification; #477 Amulet Of Wisdom; #478 Pendent Of Holy Spirit |
| 961 | 定心项链（冰） |  |  | no free Zircon candidate (all plausible candidates consumed): #663 Pendant Of Purification; #477 Amulet Of Wisdom; #478 Pendent Of Holy Spirit |
| 962 | 定心项链（雷） |  |  | no free Zircon candidate (all plausible candidates consumed): #663 Pendant Of Purification; #477 Amulet Of Wisdom; #478 Pendent Of Holy Spirit |
| 963 | 定心项链（风） |  |  | no free Zircon candidate (all plausible candidates consumed): #663 Pendant Of Purification; #477 Amulet Of Wisdom; #478 Pendent Of Holy Spirit |
| 964 | 定心项链（神圣） |  |  | no free Zircon candidate (all plausible candidates consumed): #663 Pendant Of Purification; #477 Amulet Of Wisdom; #478 Pendent Of Holy Spirit |
| 965 | 定心项链（暗黑） |  |  | no free Zircon candidate (all plausible candidates consumed): #663 Pendant Of Purification; #477 Amulet Of Wisdom; #478 Pendent Of Holy Spirit |
| 966 | 定心项链（幻影） |  |  | no free Zircon candidate (all plausible candidates consumed): #663 Pendant Of Purification; #477 Amulet Of Wisdom; #478 Pendent Of Holy Spirit |
| 967 | 金棱手镯（火） |  |  | no free Zircon candidate (all plausible candidates consumed): #664 Bracer Of Revelation |
| 968 | 金棱手镯（冰） |  |  | no free Zircon candidate (all plausible candidates consumed): #664 Bracer Of Revelation |
| 969 | 金棱手镯（雷） |  |  | no free Zircon candidate (all plausible candidates consumed): #664 Bracer Of Revelation |
| 970 | 金棱手镯（风） |  |  | no free Zircon candidate (all plausible candidates consumed): #664 Bracer Of Revelation |
| 971 | 金棱手镯（神圣） |  |  | no free Zircon candidate (all plausible candidates consumed): #664 Bracer Of Revelation |
| 972 | 金棱手镯（暗黑） |  |  | no free Zircon candidate (all plausible candidates consumed): #664 Bracer Of Revelation |
| 973 | 金棱手镯（幻影） |  |  | no free Zircon candidate (all plausible candidates consumed): #664 Bracer Of Revelation |
| 974 | 思过手镯（火） |  |  | no free Zircon candidate (all plausible candidates consumed): #665 Ring Of Enlightenment |
| 975 | 思过手镯（冰） |  |  | no free Zircon candidate (all plausible candidates consumed): #665 Ring Of Enlightenment |
| 976 | 思过手镯（雷） |  |  | no free Zircon candidate (all plausible candidates consumed): #665 Ring Of Enlightenment |
| 977 | 思过手镯（风） |  |  | no free Zircon candidate (all plausible candidates consumed): #665 Ring Of Enlightenment |
| 978 | 思过手镯（神圣） |  |  | no free Zircon candidate (all plausible candidates consumed): #665 Ring Of Enlightenment |
| 979 | 思过手镯（暗黑） |  |  | no free Zircon candidate (all plausible candidates consumed): #665 Ring Of Enlightenment |
| 980 | 思过手镯（幻影） |  |  | no free Zircon candidate (all plausible candidates consumed): #665 Ring Of Enlightenment |
| 981 | 世尊手镯（火） |  |  | no free Zircon candidate (all plausible candidates consumed): #666 Bracelet Of Ascension |
| 982 | 世尊手镯（冰） |  |  | no free Zircon candidate (all plausible candidates consumed): #666 Bracelet Of Ascension |
| 983 | 世尊手镯（雷） |  |  | no free Zircon candidate (all plausible candidates consumed): #666 Bracelet Of Ascension |
| 984 | 世尊手镯（风） |  |  | no free Zircon candidate (all plausible candidates consumed): #666 Bracelet Of Ascension |
| 985 | 世尊手镯（神圣） |  |  | no free Zircon candidate (all plausible candidates consumed): #666 Bracelet Of Ascension |
| 986 | 世尊手镯（暗黑） |  |  | no free Zircon candidate (all plausible candidates consumed): #666 Bracelet Of Ascension |
| 987 | 世尊手镯（幻影） |  |  | no free Zircon candidate (all plausible candidates consumed): #666 Bracelet Of Ascension |
| 997 | 影魅之刃 |  |  | no Zircon counterpart under anchors (price/weight/dura/level/image) |
| 998 | 寂幻之刃 |  |  | no Zircon counterpart under anchors (price/weight/dura/level/image) |
| 999 | 魄冰刺（秘籍） |  |  | advanced manual 秘籍: SKILL_MAP '魄冰刺'->skill#46 'Greater Frozen Earth'; Zircon keeps one book per spell (already closed to the StdMode 51 sibling as #47 Greater Frozen Earth) -- Mud3-only variant |
| 1000 | 怒神霹雳（秘籍） |  |  | advanced manual 秘籍: SKILL_MAP '怒神霹雳'->skill#47 'Chain Lightning'; Zircon keeps one book per spell (already closed to the StdMode 51 sibling as #48 Chain Lightning) -- Mud3-only variant |
| 1001 | 焰天火雨（秘籍） |  |  | advanced manual 秘籍: SKILL_MAP '焰天火雨'->skill#48 'Meteor Shower'; Zircon keeps one book per spell (already closed to the StdMode 51 sibling as #49 Meteor Shower) -- Mud3-only variant |
| 1002 | 凝血离魂（秘籍） |  |  | advanced manual 秘籍: no SKILL_MAP entry / no matching Zircon book |
| 1003 | 云寂术（秘籍） |  |  | advanced manual 秘籍: SKILL_MAP '云寂术'->skill#75 'Purification'; Zircon keeps one book per spell (already closed to the StdMode 51 sibling as #76 Purification) -- Mud3-only variant |
| 1004 | 移花接玉（秘籍） |  |  | advanced manual 秘籍: no SKILL_MAP entry / no matching Zircon book |
| 1005 | 妙影无踪（秘籍） |  |  | advanced manual 秘籍: SKILL_MAP '妙影无踪'->skill#76 'Transparency'; Zircon keeps one book per spell (already closed to the StdMode 51 sibling as #77 Transparency) -- Mud3-only variant |
| 1006 | 阴阳法环（秘籍） |  |  | advanced manual 秘籍: SKILL_MAP '阴阳法环'->skill#49 'Renounce'; Zircon keeps one book per spell (already closed to the StdMode 51 sibling as #50 Renounce) -- Mud3-only variant |
| 1007 | 十方斩（秘籍） |  |  | advanced manual 秘籍: SKILL_MAP '十方斩'->skill#10 'Destructive Surge'; Zircon keeps one book per spell (already closed to the StdMode 51 sibling as #11 Destructive Surge) -- Mud3-only variant |
| 1008 | 乾坤大挪移（秘籍） |  |  | advanced manual 秘籍: SKILL_MAP '乾坤大挪移'->skill#11 'Interchange'; Zircon keeps one book per spell (already closed to the StdMode 51 sibling as #12 Interchange) -- Mud3-only variant |
| 1009 | 铁布衫（秘籍） |  |  | advanced manual 秘籍: SKILL_MAP '铁布衫'->skill#12 'Defiance'; Zircon keeps one book per spell (already closed to the StdMode 51 sibling as #13 Defiance) -- Mud3-only variant |
| 1010 | 斗转星移（秘籍） |  |  | advanced manual 秘籍: SKILL_MAP '斗转星移'->skill#13 'Beckon'; Zircon keeps one book per spell (already closed to the StdMode 51 sibling as #14 Beckon) -- Mud3-only variant |
| 1011 | 破血狂杀（秘籍） |  |  | advanced manual 秘籍: SKILL_MAP '破血狂杀'->skill#14 'Might'; Zircon keeps one book per spell (already closed to the StdMode 51 sibling as #15 Might) -- Mud3-only variant |
| 1012 | 飞龙剑（火） |  |  | no Zircon counterpart under anchors (price/weight/dura/level/image) |
| 1013 | 飞龙剑（冰） |  |  | no Zircon counterpart under anchors (price/weight/dura/level/image) |
| 1014 | 飞龙剑（雷） |  |  | no Zircon counterpart under anchors (price/weight/dura/level/image) |
| 1015 | 飞龙剑（风） |  |  | no Zircon counterpart under anchors (price/weight/dura/level/image) |
| 1016 | 飞龙剑（神圣） |  |  | no Zircon counterpart under anchors (price/weight/dura/level/image) |
| 1017 | 飞龙剑（暗黑） |  |  | no Zircon counterpart under anchors (price/weight/dura/level/image) |
| 1018 | 飞龙剑（幻影） |  |  | no Zircon counterpart under anchors (price/weight/dura/level/image) |
| 1019 | 麒麟宝铠（男） |  |  | no Zircon counterpart under anchors (price/weight/dura/level/image) |
| 1020 | 麒麟宝铠（女） |  |  | no Zircon counterpart under anchors (price/weight/dura/level/image) |
| 1027 | 绝世极品战甲（男） |  |  | no Zircon counterpart under anchors (price/weight/dura/level/image) |
| 1028 | 绝世极品战甲（女） |  |  | no Zircon counterpart under anchors (price/weight/dura/level/image) |
| 1034 | 血花落照（血） |  |  | no Zircon counterpart under anchors (price/weight/dura/level/image) |
| 1035 | 血花落照（花） |  |  | no Zircon counterpart under anchors (price/weight/dura/level/image) |
| 1036 | 血花落照（落） |  |  | no Zircon counterpart under anchors (price/weight/dura/level/image) |
| 1037 | 血花落照（照） |  |  | no Zircon counterpart under anchors (price/weight/dura/level/image) |
| 1038 | 黑天暗云（黑） |  |  | no Zircon counterpart under anchors (price/weight/dura/level/image) |
| 1039 | 黑天暗云（天） |  |  | no Zircon counterpart under anchors (price/weight/dura/level/image) |
| 1040 | 黑天暗云（暗） |  |  | no Zircon counterpart under anchors (price/weight/dura/level/image) |
| 1041 | 黑天暗云（云） |  |  | no Zircon counterpart under anchors (price/weight/dura/level/image) |
| 1042 | 九宫云雾（九） |  |  | no Zircon counterpart under anchors (price/weight/dura/level/image) |
| 1043 | 九宫云雾（宫） |  |  | no Zircon counterpart under anchors (price/weight/dura/level/image) |
| 1044 | 九宫云雾（云） |  |  | no Zircon counterpart under anchors (price/weight/dura/level/image) |
| 1045 | 九宫云雾（雾） |  |  | no Zircon counterpart under anchors (price/weight/dura/level/image) |
| 1046 | 万里碧海（万） |  |  | no Zircon counterpart under anchors (price/weight/dura/level/image) |
| 1047 | 万里碧海（里） |  |  | no Zircon counterpart under anchors (price/weight/dura/level/image) |
| 1048 | 万里碧海（碧） |  |  | no Zircon counterpart under anchors (price/weight/dura/level/image) |
| 1049 | 万里碧海（海） |  |  | no Zircon counterpart under anchors (price/weight/dura/level/image) |
| 1050 | 血花落照 |  |  | no free Zircon candidate (all plausible candidates consumed): #301 Choker Of Learning |
| 1051 | 黑天暗云 |  |  | no free Zircon candidate (all plausible candidates consumed): #301 Choker Of Learning |
| 1052 | 九宫云雾 |  |  | no free Zircon candidate (all plausible candidates consumed): #301 Choker Of Learning |
| 1053 | 万里碧海 |  |  | no Zircon counterpart under anchors (price/weight/dura/level/image) |
| 1057 | 凝血离魂 |  |  | skill book '凝血离魂': no SKILL_MAP entry / no matching Zircon book |
| 1059 | 移花接玉 |  |  | skill book '移花接玉': no SKILL_MAP entry / no matching Zircon book |
| 1067 | 积分彩票 |  |  | no Zircon counterpart under anchors (price/weight/dura/level/image) |
| 1068 | 积分卷 |  |  | no Zircon counterpart under anchors (price/weight/dura/level/image) |
| 1069 | 高级积分彩票 |  |  | no Zircon counterpart under anchors (price/weight/dura/level/image) |
| 1070 | 嫁祸卡 |  |  | no Zircon counterpart under anchors (price/weight/dura/level/image) |
| 1071 | 积分点卷 |  |  | no Zircon counterpart under anchors (price/weight/dura/level/image) |
| 1072 | 破荒步 |  |  | skill book '破荒步': no SKILL_MAP entry / no matching Zircon book |
| 1073 | 回风刚幕 |  |  | skill book '回风刚幕': no SKILL_MAP entry / no matching Zircon book |
| 1074 | 灭杀界 |  |  | skill book '灭杀界': no SKILL_MAP entry / no matching Zircon book |
| 1075 | 破荒步（秘籍） |  |  | advanced manual 秘籍: no SKILL_MAP entry / no matching Zircon book |
| 1076 | 回风刚幕（秘籍） |  |  | advanced manual 秘籍: no SKILL_MAP entry / no matching Zircon book |
| 1077 | 灭杀界（秘籍） |  |  | advanced manual 秘籍: no SKILL_MAP entry / no matching Zircon book |
| 1079 | 爱情礼盒 |  |  | no Zircon counterpart under anchors (price/weight/dura/level/image) |
| 1080 | 飞龙剑碎片（火） |  |  | no Zircon counterpart under anchors (price/weight/dura/level/image) |
| 1081 | 飞龙剑碎片（冰） |  |  | no Zircon counterpart under anchors (price/weight/dura/level/image) |
| 1082 | 飞龙剑碎片（雷） |  |  | no Zircon counterpart under anchors (price/weight/dura/level/image) |
| 1083 | 飞龙剑碎片（风） |  |  | no Zircon counterpart under anchors (price/weight/dura/level/image) |
| 1084 | 飞龙剑碎片（神圣） |  |  | no Zircon counterpart under anchors (price/weight/dura/level/image) |
| 1085 | 飞龙剑碎片（暗黑） |  |  | no Zircon counterpart under anchors (price/weight/dura/level/image) |
| 1086 | 飞龙剑碎片（幻影） |  |  | no Zircon counterpart under anchors (price/weight/dura/level/image) |
| 1087 | 绿玫瑰 |  |  | no Zircon counterpart under anchors (price/weight/dura/level/image) |
| 1088 | 蓝玫瑰 |  |  | no Zircon counterpart under anchors (price/weight/dura/level/image) |
| 1089 | 遗址雕像 |  |  | no free Zircon candidate (all plausible candidates consumed): #394 Fragment Of Zuma King; #667 Relic Fragment |
| 1090 | 魔法糖果 |  |  | no Zircon counterpart under anchors (price/weight/dura/level/image) |
| 1091 | 灵魂糖果 |  |  | no Zircon counterpart under anchors (price/weight/dura/level/image) |
| 1092 | 疾风糖果 |  |  | no Zircon counterpart under anchors (price/weight/dura/level/image) |
| 1093 | 攻击糖果 |  |  | no Zircon counterpart under anchors (price/weight/dura/level/image) |
| 1094 | 体力糖果 |  |  | no Zircon counterpart under anchors (price/weight/dura/level/image) |
| 1095 | 火焰护身符（中） |  |  | no Zircon counterpart under anchors (price/weight/dura/level/image) |
| 1096 | 寒气护身符（中） |  |  | no Zircon counterpart under anchors (price/weight/dura/level/image) |
| 1097 | 霹雷护身符（中） |  |  | no Zircon counterpart under anchors (price/weight/dura/level/image) |
| 1098 | 狂风护身符（中） |  |  | no Zircon counterpart under anchors (price/weight/dura/level/image) |
| 1100 | 铁轮（奖励） |  |  | no free Zircon candidate (all plausible candidates consumed): #636 Glaive Of Doom |
| 1101 | 逍遥扇（奖励） |  |  | no free Zircon candidate (all plausible candidates consumed): #637 Warden's Fan Of Obedience |
| 1102 | 天神法杖（改） |  |  | no free Zircon candidate (all plausible candidates consumed): #684 Heavenly Staff Of Immortality |
| 1103 | 天赐神甲（男） |  |  | no free Zircon candidate (all plausible candidates consumed): #692 Ghost Armour (M) |
| 1104 | 天赐神甲（女） |  |  | no free Zircon candidate (all plausible candidates consumed): #692 Ghost Armour (M) |
| 1105 | 神赐戒指 |  |  | no free Zircon candidate (all plausible candidates consumed): #568 Ring Of Sovereignty |
| 1106 | 天赐戒指 |  |  | no free Zircon candidate (all plausible candidates consumed): #558 Blue Jade Signet |
| 1107 | 魔赐戒指 |  |  | no free Zircon candidate (all plausible candidates consumed): #660 Signet Of Vicar |
| 1108 | 乾坤刀 |  |  | no Zircon counterpart under anchors (price/weight/dura/level/image) |
| 1121 | 黄金裁决之杖 |  |  | no Zircon counterpart under anchors (price/weight/dura/level/image) |
| 1122 | 凌霜骨玉权杖 |  |  | no Zircon counterpart under anchors (price/weight/dura/level/image) |
| 1123 | 暗黑无极棍 |  |  | no Zircon counterpart under anchors (price/weight/dura/level/image) |
| 1124 | 诺玛遗物 |  |  | no Zircon counterpart under anchors (price/weight/dura/level/image) |
| 1125 | 猫眼石 |  |  | no Zircon counterpart under anchors (price/weight/dura/level/image) |
| 1126 | 碧玉水 |  |  | no Zircon counterpart under anchors (price/weight/dura/level/image) |
| 1127 | 青空石 |  |  | no Zircon counterpart under anchors (price/weight/dura/level/image) |
| 1128 | 大地石 |  |  | no Zircon counterpart under anchors (price/weight/dura/level/image) |
| 1129 | 太阳石 |  |  | no Zircon counterpart under anchors (price/weight/dura/level/image) |
| 1130 | 月光石 |  |  | no Zircon counterpart under anchors (price/weight/dura/level/image) |
| 1131 | 受胎石 |  |  | no Zircon counterpart under anchors (price/weight/dura/level/image) |
| 1132 | 安息石 |  |  | no Zircon counterpart under anchors (price/weight/dura/level/image) |
| 1133 | 活石 |  |  | no Zircon counterpart under anchors (price/weight/dura/level/image) |
| 1134 | 心石 |  |  | no Zircon counterpart under anchors (price/weight/dura/level/image) |
| 1135 | 神秘之印 |  |  | no Zircon counterpart under anchors (price/weight/dura/level/image) |
| 1136 | 藏宝箱 |  |  | no Zircon counterpart under anchors (price/weight/dura/level/image) |
| 1137 | 尸骨项链 |  |  | no Zircon counterpart under anchors (price/weight/dura/level/image) |
| 1138 | 击退护身符 |  |  | no Zircon counterpart under anchors (price/weight/dura/level/image) |
| 1139 | 书籍 |  |  | no Zircon counterpart under anchors (price/weight/dura/level/image) |
| 1140 | 潘夜天灵 |  |  | no free Zircon candidate (all plausible candidates consumed): #509 Mage Sword Of Banya |
| 1141 | 毁灭之印 |  |  | no Zircon counterpart under anchors (price/weight/dura/level/image) |
| 1142 | 藏宝箱 |  |  | no Zircon counterpart under anchors (price/weight/dura/level/image) |

## zircon-only — Zircon 有、Mud3 无（630）

| mud3_index | mud3_name | → zircon_index | zircon_en | evidence |
|---:|---|---:|---|---|
|  |  | 16 | Swift Blade | no Mud3 EI2.0 counterpart (late LOMCN / private-server addition) |
|  |  | 17 | Assault | no Mud3 EI2.0 counterpart (late LOMCN / private-server addition) |
|  |  | 18 | Endurance | no Mud3 EI2.0 counterpart (late LOMCN / private-server addition) |
|  |  | 19 | Reflect Damage | no Mud3 EI2.0 counterpart (late LOMCN / private-server addition) |
|  |  | 20 | Fetter | no Mud3 EI2.0 counterpart (late LOMCN / private-server addition) |
|  |  | 21 | Advanced Destructive Surge | no Mud3 EI2.0 counterpart (late LOMCN / private-server addition) |
|  |  | 22 | Advanced Defiance | no Mud3 EI2.0 counterpart (late LOMCN / private-server addition) |
|  |  | 23 | Advanced Reflect Damage | no Mud3 EI2.0 counterpart (late LOMCN / private-server addition) |
|  |  | 51 | Tempest | no Mud3 EI2.0 counterpart (late LOMCN / private-server addition) |
|  |  | 52 | Judgement Of Heaven | no Mud3 EI2.0 counterpart (late LOMCN / private-server addition) |
|  |  | 53 | Thunder Storm | no Mud3 EI2.0 counterpart (late LOMCN / private-server addition) |
|  |  | 54 | Elemental Hurricane | no Mud3 EI2.0 counterpart (late LOMCN / private-server addition) |
|  |  | 55 | Superior Magic Shield | no Mud3 EI2.0 counterpart (late LOMCN / private-server addition) |
|  |  | 56 | Burning | no Mud3 EI2.0 counterpart (late LOMCN / private-server addition) |
|  |  | 57 | Shock | no Mud3 EI2.0 counterpart (late LOMCN / private-server addition) |
|  |  | 58 | Lightning Strike | no Mud3 EI2.0 counterpart (late LOMCN / private-server addition) |
|  |  | 59 | Mirror Image | no Mud3 EI2.0 counterpart (late LOMCN / private-server addition) |
|  |  | 71 | Taoist Combat Kick | no Mud3 EI2.0 counterpart (late LOMCN / private-server addition) |
|  |  | 78 | Celestial Light | no Mud3 EI2.0 counterpart (late LOMCN / private-server addition) |
|  |  | 79 | Empowered Healing | no Mud3 EI2.0 counterpart (late LOMCN / private-server addition) |
|  |  | 80 | Life Steal | no Mud3 EI2.0 counterpart (late LOMCN / private-server addition) |
|  |  | 81 | Improved Explosive Talisman | no Mud3 EI2.0 counterpart (late LOMCN / private-server addition) |
|  |  | 82 | Empowered Poison Dust | no Mud3 EI2.0 counterpart (late LOMCN / private-server addition) |
|  |  | 83 | Cursed Doll | no Mud3 EI2.0 counterpart (late LOMCN / private-server addition) |
|  |  | 84 | Thunder Kick | no Mud3 EI2.0 counterpart (late LOMCN / private-server addition) |
|  |  | 85 | Soul Resonance | no Mud3 EI2.0 counterpart (late LOMCN / private-server addition) |
|  |  | 86 | Parasite | no Mud3 EI2.0 counterpart (late LOMCN / private-server addition) |
|  |  | 87 | Spiritualism | no Mud3 EI2.0 counterpart (late LOMCN / private-server addition) |
|  |  | 88 | Willow Dance | no Mud3 EI2.0 counterpart (late LOMCN / private-server addition) |
|  |  | 89 | Vine Tree Dance | no Mud3 EI2.0 counterpart (late LOMCN / private-server addition) |
|  |  | 90 | Discipline | no Mud3 EI2.0 counterpart (late LOMCN / private-server addition) |
|  |  | 91 | Poisonous Cloud | no Mud3 EI2.0 counterpart (late LOMCN / private-server addition) |
|  |  | 92 | Full Bloom | no Mud3 EI2.0 counterpart (late LOMCN / private-server addition) |
|  |  | 93 | Cloak | no Mud3 EI2.0 counterpart (late LOMCN / private-server addition) |
|  |  | 94 | White Lotus | no Mud3 EI2.0 counterpart (late LOMCN / private-server addition) |
|  |  | 95 | Calamity Of Full Moon | no Mud3 EI2.0 counterpart (late LOMCN / private-server addition) |
|  |  | 96 | Wraith Grip | no Mud3 EI2.0 counterpart (late LOMCN / private-server addition) |
|  |  | 97 | Red Lotus | no Mud3 EI2.0 counterpart (late LOMCN / private-server addition) |
|  |  | 98 | Hell Fire | no Mud3 EI2.0 counterpart (late LOMCN / private-server addition) |
|  |  | 99 | Pledge Of Blood | no Mud3 EI2.0 counterpart (late LOMCN / private-server addition) |
|  |  | 100 | Rake | no Mud3 EI2.0 counterpart (late LOMCN / private-server addition) |
|  |  | 101 | Sweetbrier | no Mud3 EI2.0 counterpart (late LOMCN / private-server addition) |
|  |  | 102 | Summon Puppet | no Mud3 EI2.0 counterpart (late LOMCN / private-server addition) |
|  |  | 103 | Karma | no Mud3 EI2.0 counterpart (late LOMCN / private-server addition) |
|  |  | 104 | Touch Of The Departed | no Mud3 EI2.0 counterpart (late LOMCN / private-server addition) |
|  |  | 105 | Waning Moon | no Mud3 EI2.0 counterpart (late LOMCN / private-server addition) |
|  |  | 106 | Ghost Walk | no Mud3 EI2.0 counterpart (late LOMCN / private-server addition) |
|  |  | 107 | Elemental Puppet | no Mud3 EI2.0 counterpart (late LOMCN / private-server addition) |
|  |  | 108 | Rejuvenation | no Mud3 EI2.0 counterpart (late LOMCN / private-server addition) |
|  |  | 109 | Resolution | no Mud3 EI2.0 counterpart (late LOMCN / private-server addition) |
|  |  | 110 | Change Of Seasons | no Mud3 EI2.0 counterpart (late LOMCN / private-server addition) |
|  |  | 111 | Release | no Mud3 EI2.0 counterpart (late LOMCN / private-server addition) |
|  |  | 112 | Flame Splash | no Mud3 EI2.0 counterpart (late LOMCN / private-server addition) |
|  |  | 113 | Bloody Flower | no Mud3 EI2.0 counterpart (late LOMCN / private-server addition) |
|  |  | 114 | The New Beginning | no Mud3 EI2.0 counterpart (late LOMCN / private-server addition) |
|  |  | 115 | Dance Of Swallow | no Mud3 EI2.0 counterpart (late LOMCN / private-server addition) |
|  |  | 116 | Dark Conversion | no Mud3 EI2.0 counterpart (late LOMCN / private-server addition) |
|  |  | 117 | Dragon Repulse | no Mud3 EI2.0 counterpart (late LOMCN / private-server addition) |
|  |  | 118 | Advent Of Demon | no Mud3 EI2.0 counterpart (late LOMCN / private-server addition) |
|  |  | 119 | Advent Of Devil | no Mud3 EI2.0 counterpart (late LOMCN / private-server addition) |
|  |  | 120 | Abyss | no Mud3 EI2.0 counterpart (late LOMCN / private-server addition) |
|  |  | 121 | Flash Of Light | no Mud3 EI2.0 counterpart (late LOMCN / private-server addition) |
|  |  | 122 | Stealth | no Mud3 EI2.0 counterpart (late LOMCN / private-server addition) |
|  |  | 123 | Evasion | no Mud3 EI2.0 counterpart (late LOMCN / private-server addition) |
|  |  | 124 | Raging Wind | no Mud3 EI2.0 counterpart (late LOMCN / private-server addition) |
|  |  | 129 | Trainee's Glaive | no Mud3 EI2.0 counterpart (late LOMCN / private-server addition) |
|  |  | 130 | Trainee's Armour (M) | no Mud3 EI2.0 counterpart (late LOMCN / private-server addition) |
|  |  | 131 | Trainee's Armour (F) | no Mud3 EI2.0 counterpart (late LOMCN / private-server addition) |
|  |  | 137 | Healing Potion (V) | no Mud3 EI2.0 counterpart (late LOMCN / private-server addition) |
|  |  | 138 | Life Pill | no Mud3 EI2.0 counterpart (late LOMCN / private-server addition) |
|  |  | 139 | Life Pill (II) | no Mud3 EI2.0 counterpart (late LOMCN / private-server addition) |
|  |  | 140 | Life Pill (III) | no Mud3 EI2.0 counterpart (late LOMCN / private-server addition) |
|  |  | 141 | Life Pill (IV) | no Mud3 EI2.0 counterpart (late LOMCN / private-server addition) |
|  |  | 142 | Life Pill (V) | no Mud3 EI2.0 counterpart (late LOMCN / private-server addition) |
|  |  | 147 | !Mana Potion (V) | no Mud3 EI2.0 counterpart (late LOMCN / private-server addition) |
|  |  | 148 | Mana Pill | no Mud3 EI2.0 counterpart (late LOMCN / private-server addition) |
|  |  | 149 | Mana Pill (II) | no Mud3 EI2.0 counterpart (late LOMCN / private-server addition) |
|  |  | 150 | Mana Pill (III) | no Mud3 EI2.0 counterpart (late LOMCN / private-server addition) |
|  |  | 151 | Mana Pill (IV) | no Mud3 EI2.0 counterpart (late LOMCN / private-server addition) |
|  |  | 152 | !Mana Pill (V) | no Mud3 EI2.0 counterpart (late LOMCN / private-server addition) |
|  |  | 185 | Claw Of Horror | no Mud3 EI2.0 counterpart (late LOMCN / private-server addition) |
|  |  | 190 | Shroud Of Stealth (M) | no Mud3 EI2.0 counterpart (late LOMCN / private-server addition) |
|  |  | 191 | Shroud Of Stealth (F) | no Mud3 EI2.0 counterpart (late LOMCN / private-server addition) |
|  |  | 198 | Tunic Of Velocity (M) | no Mud3 EI2.0 counterpart (late LOMCN / private-server addition) |
|  |  | 199 | Tunic Of Velocity (F) | no Mud3 EI2.0 counterpart (late LOMCN / private-server addition) |
|  |  | 203 | Master's Glaive | no Mud3 EI2.0 counterpart (late LOMCN / private-server addition) |
|  |  | 214 | Empowered Explosive Talisman | no Mud3 EI2.0 counterpart (late LOMCN / private-server addition) |
|  |  | 215 | Empowered Evil Slayer | no Mud3 EI2.0 counterpart (late LOMCN / private-server addition) |
|  |  | 217 | Summon Demonic Creature | no Mud3 EI2.0 counterpart (late LOMCN / private-server addition) |
|  |  | 218 | Demon Explosion | no Mud3 EI2.0 counterpart (late LOMCN / private-server addition) |
|  |  | 219 | Strength Of Faith | no Mud3 EI2.0 counterpart (late LOMCN / private-server addition) |
|  |  | 220 | Talisman | no Mud3 EI2.0 counterpart (late LOMCN / private-server addition) |
|  |  | 221 | Talisman Of Darkness | no Mud3 EI2.0 counterpart (late LOMCN / private-server addition) |
|  |  | 222 | Talisman Of Fire | no Mud3 EI2.0 counterpart (late LOMCN / private-server addition) |
|  |  | 223 | Talisman Of Holiness | no Mud3 EI2.0 counterpart (late LOMCN / private-server addition) |
|  |  | 224 | Talisman Of Ice | no Mud3 EI2.0 counterpart (late LOMCN / private-server addition) |
|  |  | 225 | Talisman Of Illusions | no Mud3 EI2.0 counterpart (late LOMCN / private-server addition) |
|  |  | 226 | Talisman Of Lightning | no Mud3 EI2.0 counterpart (late LOMCN / private-server addition) |
|  |  | 227 | Talisman Of Wind Storm | no Mud3 EI2.0 counterpart (late LOMCN / private-server addition) |
|  |  | 229 | Green Poison | no Mud3 EI2.0 counterpart (late LOMCN / private-server addition) |
|  |  | 230 | Red Poison | no Mud3 EI2.0 counterpart (late LOMCN / private-server addition) |
|  |  | 232 | Trainee's Mask | no Mud3 EI2.0 counterpart (late LOMCN / private-server addition) |
|  |  | 233 | Apprentice's Mask | no Mud3 EI2.0 counterpart (late LOMCN / private-server addition) |
|  |  | 237 | Brown Chestnut | no Mud3 EI2.0 counterpart (late LOMCN / private-server addition) |
|  |  | 238 | Bronze Chestnut | no Mud3 EI2.0 counterpart (late LOMCN / private-server addition) |
|  |  | 239 | Silver Chestnut | no Mud3 EI2.0 counterpart (late LOMCN / private-server addition) |
|  |  | 240 | Gold Chestnut | no Mud3 EI2.0 counterpart (late LOMCN / private-server addition) |
|  |  | 246 | !Cat's Claw | no Mud3 EI2.0 counterpart (late LOMCN / private-server addition) |
|  |  | 247 | !Tuft of Fur | no Mud3 EI2.0 counterpart (late LOMCN / private-server addition) |
|  |  | 248 | !Trinket | no Mud3 EI2.0 counterpart (late LOMCN / private-server addition) |
|  |  | 249 | !Rejuvenation Potion (III) | no Mud3 EI2.0 counterpart (late LOMCN / private-server addition) |
|  |  | 250 | !Rejuvenation Potion (IV) | no Mud3 EI2.0 counterpart (late LOMCN / private-server addition) |
|  |  | 251 | !Rejuvenation Potion (V) | no Mud3 EI2.0 counterpart (late LOMCN / private-server addition) |
|  |  | 254 | !Worm Guts | no Mud3 EI2.0 counterpart (late LOMCN / private-server addition) |
|  |  | 266 | Elixir Of Destruction (V) | no Mud3 EI2.0 counterpart (late LOMCN / private-server addition) |
|  |  | 271 | Elixir Of Haste (V) | no Mud3 EI2.0 counterpart (late LOMCN / private-server addition) |
|  |  | 276 | Elixir Of Life (V) | no Mud3 EI2.0 counterpart (late LOMCN / private-server addition) |
|  |  | 281 | Elixir Of Mana (V) | no Mud3 EI2.0 counterpart (late LOMCN / private-server addition) |
|  |  | 286 | Elixir Of Nature (V) | no Mud3 EI2.0 counterpart (late LOMCN / private-server addition) |
|  |  | 294 | !Balanced Bracelet (OLD) | no Mud3 EI2.0 counterpart (late LOMCN / private-server addition) |
|  |  | 319 | Disguise Of The Master | no Mud3 EI2.0 counterpart (late LOMCN / private-server addition) |
|  |  | 320 | Blood Prophet's Cowl | no Mud3 EI2.0 counterpart (late LOMCN / private-server addition) |
|  |  | 327 | Crystal | no Mud3 EI2.0 counterpart (late LOMCN / private-server addition) |
|  |  | 331 | Glaive Of Manes | no Mud3 EI2.0 counterpart (late LOMCN / private-server addition) |
|  |  | 341 | Shadow Armour Of Deviation (M) | no Mud3 EI2.0 counterpart (late LOMCN / private-server addition) |
|  |  | 342 | Shadow Armour Of Deviation (F) | no Mud3 EI2.0 counterpart (late LOMCN / private-server addition) |
|  |  | 346 | Wyvern Armour (M) | no Mud3 EI2.0 counterpart (late LOMCN / private-server addition) |
|  |  | 347 | Wyvern Armour (F) | no Mud3 EI2.0 counterpart (late LOMCN / private-server addition) |
|  |  | 348 | Nephrite Armour (M) | no Mud3 EI2.0 counterpart (late LOMCN / private-server addition) |
|  |  | 349 | Nephrite Armour (F) | no Mud3 EI2.0 counterpart (late LOMCN / private-server addition) |
|  |  | 350 | Wyvern Armour Of Protection (M) | no Mud3 EI2.0 counterpart (late LOMCN / private-server addition) |
|  |  | 351 | Wyvern Armour Of Protection (F) | no Mud3 EI2.0 counterpart (late LOMCN / private-server addition) |
|  |  | 352 | Demon Hunter's Shroud (M) | no Mud3 EI2.0 counterpart (late LOMCN / private-server addition) |
|  |  | 353 | Demon Hunter's Shroud (F) | no Mud3 EI2.0 counterpart (late LOMCN / private-server addition) |
|  |  | 392 | White Lotus Disguise | no Mud3 EI2.0 counterpart (late LOMCN / private-server addition) |
|  |  | 393 | Red Lotus Disguise | no Mud3 EI2.0 counterpart (late LOMCN / private-server addition) |
|  |  | 406 | Claw Of Black Tortoise | no Mud3 EI2.0 counterpart (late LOMCN / private-server addition) |
|  |  | 408 | Burning Dark Stone | no Mud3 EI2.0 counterpart (late LOMCN / private-server addition) |
|  |  | 409 | Burning Dark Stone (II) | no Mud3 EI2.0 counterpart (late LOMCN / private-server addition) |
|  |  | 410 | Burning Dark Stone (III) | no Mud3 EI2.0 counterpart (late LOMCN / private-server addition) |
|  |  | 411 | Burning Dark Stone (IV) | no Mud3 EI2.0 counterpart (late LOMCN / private-server addition) |
|  |  | 412 | Burning Dark Stone (V) | no Mud3 EI2.0 counterpart (late LOMCN / private-server addition) |
|  |  | 413 | Frozen Dark Stone | no Mud3 EI2.0 counterpart (late LOMCN / private-server addition) |
|  |  | 414 | Frozen Dark Stone (II) | no Mud3 EI2.0 counterpart (late LOMCN / private-server addition) |
|  |  | 415 | Frozen Dark Stone (III) | no Mud3 EI2.0 counterpart (late LOMCN / private-server addition) |
|  |  | 416 | Frozen Dark Stone (IV) | no Mud3 EI2.0 counterpart (late LOMCN / private-server addition) |
|  |  | 417 | Frozen Dark Stone (V) | no Mud3 EI2.0 counterpart (late LOMCN / private-server addition) |
|  |  | 418 | Shocking Dark Stone | no Mud3 EI2.0 counterpart (late LOMCN / private-server addition) |
|  |  | 419 | Shocking Dark Stone (II) | no Mud3 EI2.0 counterpart (late LOMCN / private-server addition) |
|  |  | 420 | Shocking Dark Stone (III) | no Mud3 EI2.0 counterpart (late LOMCN / private-server addition) |
|  |  | 421 | Shocking Dark Stone (IV) | no Mud3 EI2.0 counterpart (late LOMCN / private-server addition) |
|  |  | 422 | Shocking Dark Stone (V) | no Mud3 EI2.0 counterpart (late LOMCN / private-server addition) |
|  |  | 423 | Gusting Dark Stone | no Mud3 EI2.0 counterpart (late LOMCN / private-server addition) |
|  |  | 424 | Gusting Dark Stone (II) | no Mud3 EI2.0 counterpart (late LOMCN / private-server addition) |
|  |  | 425 | Gusting Dark Stone (III) | no Mud3 EI2.0 counterpart (late LOMCN / private-server addition) |
|  |  | 426 | Gusting Dark Stone (IV) | no Mud3 EI2.0 counterpart (late LOMCN / private-server addition) |
|  |  | 427 | Gusting Dark Stone (V) | no Mud3 EI2.0 counterpart (late LOMCN / private-server addition) |
|  |  | 445 | Apprentice's Hand Blade | no Mud3 EI2.0 counterpart (late LOMCN / private-server addition) |
|  |  | 446 | Expert's Hand Blade | no Mud3 EI2.0 counterpart (late LOMCN / private-server addition) |
|  |  | 447 | Big Skeleton Bone | no Mud3 EI2.0 counterpart (late LOMCN / private-server addition) |
|  |  | 449 | Razor Sharp Hand Blade | no Mud3 EI2.0 counterpart (late LOMCN / private-server addition) |
|  |  | 457 | Deathblow Talon | no Mud3 EI2.0 counterpart (late LOMCN / private-server addition) |
|  |  | 467 | Elixir Of Spirit (V) | no Mud3 EI2.0 counterpart (late LOMCN / private-server addition) |
|  |  | 471 | Assassin's Ripper | no Mud3 EI2.0 counterpart (late LOMCN / private-server addition) |
|  |  | 496 | Rogue's Render | no Mud3 EI2.0 counterpart (late LOMCN / private-server addition) |
|  |  | 501 | Crystallized Dark Ore | no Mud3 EI2.0 counterpart (late LOMCN / private-server addition) |
|  |  | 502 | Lance Of Obedience | no Mud3 EI2.0 counterpart (late LOMCN / private-server addition) |
|  |  | 511 | Forged Scimitar Of Banya | no Mud3 EI2.0 counterpart (late LOMCN / private-server addition) |
|  |  | 512 | Glaive Of Frozen Heart | no Mud3 EI2.0 counterpart (late LOMCN / private-server addition) |
|  |  | 513 | Red Lotus Glaive | no Mud3 EI2.0 counterpart (late LOMCN / private-server addition) |
|  |  | 515 | Conqueror's Talon | no Mud3 EI2.0 counterpart (late LOMCN / private-server addition) |
|  |  | 529 | Death Glaive | no Mud3 EI2.0 counterpart (late LOMCN / private-server addition) |
|  |  | 535 | Enraged Demon's Hood | no Mud3 EI2.0 counterpart (late LOMCN / private-server addition) |
|  |  | 552 | Death Steel Claw | no Mud3 EI2.0 counterpart (late LOMCN / private-server addition) |
|  |  | 553 | Carmine Claw Determination | no Mud3 EI2.0 counterpart (late LOMCN / private-server addition) |
|  |  | 554 | Raiment Of Executioner(M) | no Mud3 EI2.0 counterpart (late LOMCN / private-server addition) |
|  |  | 555 | Raiment Of Executioner(F) | no Mud3 EI2.0 counterpart (late LOMCN / private-server addition) |
|  |  | 569 | Armour Of Condemned (M) | no Mud3 EI2.0 counterpart (late LOMCN / private-server addition) |
|  |  | 570 | Armour Of Condemned (F) | no Mud3 EI2.0 counterpart (late LOMCN / private-server addition) |
|  |  | 575 | Tunic Of Annihilation (M) | no Mud3 EI2.0 counterpart (late LOMCN / private-server addition) |
|  |  | 576 | Tunic Of Annihilation (F) | no Mud3 EI2.0 counterpart (late LOMCN / private-server addition) |
|  |  | 578 | Hood Of Nemesis | no Mud3 EI2.0 counterpart (late LOMCN / private-server addition) |
|  |  | 579 | Enraged Falcon's Mask | no Mud3 EI2.0 counterpart (late LOMCN / private-server addition) |
|  |  | 584 | Redemption Key Stone | no Mud3 EI2.0 counterpart (late LOMCN / private-server addition) |
|  |  | 588 | Ice Rain | no Mud3 EI2.0 counterpart (late LOMCN / private-server addition) |
|  |  | 589 | Empowered Purification | no Mud3 EI2.0 counterpart (late LOMCN / private-server addition) |
|  |  | 590 | Empowered Resurrection | no Mud3 EI2.0 counterpart (late LOMCN / private-server addition) |
|  |  | 623 | Yun Wine | no Mud3 EI2.0 counterpart (late LOMCN / private-server addition) |
|  |  | 633 | Halberd Of Integrity | no Mud3 EI2.0 counterpart (late LOMCN / private-server addition) |
|  |  | 638 | Divine Command | no Mud3 EI2.0 counterpart (late LOMCN / private-server addition) |
|  |  | 639 | Relic | no Mud3 EI2.0 counterpart (late LOMCN / private-server addition) |
|  |  | 654 | Shamal's Obsidian Giant Blade | no Mud3 EI2.0 counterpart (late LOMCN / private-server addition) |
|  |  | 655 | Shamal's Divine Blade Of Judgment | no Mud3 EI2.0 counterpart (late LOMCN / private-server addition) |
|  |  | 656 | Shamal's Staff Of Retribution | no Mud3 EI2.0 counterpart (late LOMCN / private-server addition) |
|  |  | 657 | Falcon Glaive | no Mud3 EI2.0 counterpart (late LOMCN / private-server addition) |
|  |  | 680 | Claw Of The Demon God | no Mud3 EI2.0 counterpart (late LOMCN / private-server addition) |
|  |  | 685 | Afterlife | no Mud3 EI2.0 counterpart (late LOMCN / private-server addition) |
|  |  | 686 | Phoenix Glaive Of Havoc | no Mud3 EI2.0 counterpart (late LOMCN / private-server addition) |
|  |  | 687 | Chrome Armguard Of Earth | no Mud3 EI2.0 counterpart (late LOMCN / private-server addition) |
|  |  | 688 | Jade Armguard Of Purity | no Mud3 EI2.0 counterpart (late LOMCN / private-server addition) |
|  |  | 689 | Glowing Armguard Of Crescent | no Mud3 EI2.0 counterpart (late LOMCN / private-server addition) |
|  |  | 690 | Wind Walkers | no Mud3 EI2.0 counterpart (late LOMCN / private-server addition) |
|  |  | 691 | Medallion Of Black Magic | no Mud3 EI2.0 counterpart (late LOMCN / private-server addition) |
|  |  | 694 | Raiment Of Spectral Energy (M) | no Mud3 EI2.0 counterpart (late LOMCN / private-server addition) |
|  |  | 695 | Raiment Of Spectral Energy (F) | no Mud3 EI2.0 counterpart (late LOMCN / private-server addition) |
|  |  | 696 | Band Of Azure Sky | no Mud3 EI2.0 counterpart (late LOMCN / private-server addition) |
|  |  | 697 | Aged Gold Band Of Mystic | no Mud3 EI2.0 counterpart (late LOMCN / private-server addition) |
|  |  | 698 | Channeler's Signet Of Wizardry | no Mud3 EI2.0 counterpart (late LOMCN / private-server addition) |
|  |  | 699 | Cobalt Armguard Of Earth | no Mud3 EI2.0 counterpart (late LOMCN / private-server addition) |
|  |  | 700 | Azure Armguard Of Purity | no Mud3 EI2.0 counterpart (late LOMCN / private-server addition) |
|  |  | 701 | Blazing Armguard Of Crescent | no Mud3 EI2.0 counterpart (late LOMCN / private-server addition) |
|  |  | 709 | Mark Of Destruction [T] | no Mud3 EI2.0 counterpart (late LOMCN / private-server addition) |
|  |  | 710 | Mark Of Nature [T] | no Mud3 EI2.0 counterpart (late LOMCN / private-server addition) |
|  |  | 711 | Mark Of Spirit [T] | no Mud3 EI2.0 counterpart (late LOMCN / private-server addition) |
|  |  | 712 | Mark Of Fire [T] | no Mud3 EI2.0 counterpart (late LOMCN / private-server addition) |
|  |  | 713 | Mark Of Ice [T] | no Mud3 EI2.0 counterpart (late LOMCN / private-server addition) |
|  |  | 714 | Mark Of Lightning [T] | no Mud3 EI2.0 counterpart (late LOMCN / private-server addition) |
|  |  | 715 | Mark Of Wind [T] | no Mud3 EI2.0 counterpart (late LOMCN / private-server addition) |
|  |  | 716 | Mark Of Holy [T] | no Mud3 EI2.0 counterpart (late LOMCN / private-server addition) |
|  |  | 717 | Mark Of Dark [T] | no Mud3 EI2.0 counterpart (late LOMCN / private-server addition) |
|  |  | 718 | Mark Of Phantom [T] | no Mud3 EI2.0 counterpart (late LOMCN / private-server addition) |
|  |  | 719 | Mark Of Destruction [P] | no Mud3 EI2.0 counterpart (late LOMCN / private-server addition) |
|  |  | 720 | Mark Of Nature [P] | no Mud3 EI2.0 counterpart (late LOMCN / private-server addition) |
|  |  | 721 | Mark Of Spirit [P] | no Mud3 EI2.0 counterpart (late LOMCN / private-server addition) |
|  |  | 722 | Mark Of Fire [P] | no Mud3 EI2.0 counterpart (late LOMCN / private-server addition) |
|  |  | 723 | Mark Of Ice [P] | no Mud3 EI2.0 counterpart (late LOMCN / private-server addition) |
|  |  | 724 | Mark Of Lightning [P] | no Mud3 EI2.0 counterpart (late LOMCN / private-server addition) |
|  |  | 725 | Mark Of Wind [P] | no Mud3 EI2.0 counterpart (late LOMCN / private-server addition) |
|  |  | 726 | Mark Of Holy [P] | no Mud3 EI2.0 counterpart (late LOMCN / private-server addition) |
|  |  | 727 | Mark Of Dark [P] | no Mud3 EI2.0 counterpart (late LOMCN / private-server addition) |
|  |  | 728 | Mark Of Phantom [P] | no Mud3 EI2.0 counterpart (late LOMCN / private-server addition) |
|  |  | 729 | Mir Package [T] | no Mud3 EI2.0 counterpart (late LOMCN / private-server addition) |
|  |  | 730 | Tonic Of Experience [T] | no Mud3 EI2.0 counterpart (late LOMCN / private-server addition) |
|  |  | 731 | Tonic Of Treasure [T] | no Mud3 EI2.0 counterpart (late LOMCN / private-server addition) |
|  |  | 732 | Tonic Of Wealth [T] | no Mud3 EI2.0 counterpart (late LOMCN / private-server addition) |
|  |  | 733 | Tonic Of Spelunking [T] | no Mud3 EI2.0 counterpart (late LOMCN / private-server addition) |
|  |  | 734 | Tonic Of Destruction [T] | no Mud3 EI2.0 counterpart (late LOMCN / private-server addition) |
|  |  | 735 | Tonic Of Nature [T] | no Mud3 EI2.0 counterpart (late LOMCN / private-server addition) |
|  |  | 736 | Tonic Of Spirit [T] | no Mud3 EI2.0 counterpart (late LOMCN / private-server addition) |
|  |  | 737 | Tonic Of Life [T] | no Mud3 EI2.0 counterpart (late LOMCN / private-server addition) |
|  |  | 738 | Tonic Of Mana [T] | no Mud3 EI2.0 counterpart (late LOMCN / private-server addition) |
|  |  | 739 | Tonic Of Velocity [T] | no Mud3 EI2.0 counterpart (late LOMCN / private-server addition) |
|  |  | 740 | Tonic Of Dexterity [T] | no Mud3 EI2.0 counterpart (late LOMCN / private-server addition) |
|  |  | 741 | Tonic Of Knowledge [T] | no Mud3 EI2.0 counterpart (late LOMCN / private-server addition) |
|  |  | 742 | Tonic Of Luck [T] | no Mud3 EI2.0 counterpart (late LOMCN / private-server addition) |
|  |  | 743 | Mir Package [P] | no Mud3 EI2.0 counterpart (late LOMCN / private-server addition) |
|  |  | 744 | Tonic Of Experience [P] | no Mud3 EI2.0 counterpart (late LOMCN / private-server addition) |
|  |  | 745 | Tonic Of Treasure [P] | no Mud3 EI2.0 counterpart (late LOMCN / private-server addition) |
|  |  | 746 | Tonic Of Wealth [P] | no Mud3 EI2.0 counterpart (late LOMCN / private-server addition) |
|  |  | 747 | Tonic Of Spelunking [P] | no Mud3 EI2.0 counterpart (late LOMCN / private-server addition) |
|  |  | 748 | Tonic Of Destruction [P] | no Mud3 EI2.0 counterpart (late LOMCN / private-server addition) |
|  |  | 749 | Tonic Of Nature [P] | no Mud3 EI2.0 counterpart (late LOMCN / private-server addition) |
|  |  | 750 | Tonic Of Spirit [P] | no Mud3 EI2.0 counterpart (late LOMCN / private-server addition) |
|  |  | 751 | Tonic Of Life [P] | no Mud3 EI2.0 counterpart (late LOMCN / private-server addition) |
|  |  | 752 | Tonic Of Mana [P] | no Mud3 EI2.0 counterpart (late LOMCN / private-server addition) |
|  |  | 753 | Tonic Of Velocity [P] | no Mud3 EI2.0 counterpart (late LOMCN / private-server addition) |
|  |  | 754 | Tonic Of Dexterity [P] | no Mud3 EI2.0 counterpart (late LOMCN / private-server addition) |
|  |  | 755 | Tonic Of Knowledge [P] | no Mud3 EI2.0 counterpart (late LOMCN / private-server addition) |
|  |  | 756 | Megaphone [P] | no Mud3 EI2.0 counterpart (late LOMCN / private-server addition) |
|  |  | 757 | Hair Change | no Mud3 EI2.0 counterpart (late LOMCN / private-server addition) |
|  |  | 758 | Gender Change | no Mud3 EI2.0 counterpart (late LOMCN / private-server addition) |
|  |  | 759 | Armour Dye | no Mud3 EI2.0 counterpart (late LOMCN / private-server addition) |
|  |  | 760 | Additional Vault | no Mud3 EI2.0 counterpart (late LOMCN / private-server addition) |
|  |  | 761 | Crafting Vault | no Mud3 EI2.0 counterpart (late LOMCN / private-server addition) |
|  |  | 762 | Name Change | no Mud3 EI2.0 counterpart (late LOMCN / private-server addition) |
|  |  | 763 | Scroll Of Boss Tracking | no Mud3 EI2.0 counterpart (late LOMCN / private-server addition) |
|  |  | 764 | Scroll Of Player Tracking | no Mud3 EI2.0 counterpart (late LOMCN / private-server addition) |
|  |  | 765 | Scroll Of Teleportation | no Mud3 EI2.0 counterpart (late LOMCN / private-server addition) |
|  |  | 766 | Scroll Of Greater Teleportation | no Mud3 EI2.0 counterpart (late LOMCN / private-server addition) |
|  |  | 767 | Elixir Of Regret Lv 3 | no Mud3 EI2.0 counterpart (late LOMCN / private-server addition) |
|  |  | 768 | Elixir Of Regret Lv 5 | no Mud3 EI2.0 counterpart (late LOMCN / private-server addition) |
|  |  | 769 | Elixir Of Regret Lv 7 | no Mud3 EI2.0 counterpart (late LOMCN / private-server addition) |
|  |  | 770 | Elixir Of Regret Lv 10 | no Mud3 EI2.0 counterpart (late LOMCN / private-server addition) |
|  |  | 771 | Potion Of Awareness | no Mud3 EI2.0 counterpart (late LOMCN / private-server addition) |
|  |  | 772 | Green Apple | no Mud3 EI2.0 counterpart (late LOMCN / private-server addition) |
|  |  | 773 | Chestnut Rice Ball | no Mud3 EI2.0 counterpart (late LOMCN / private-server addition) |
|  |  | 774 | Meat Dumpling | no Mud3 EI2.0 counterpart (late LOMCN / private-server addition) |
|  |  | 775 | Fresh Meat | no Mud3 EI2.0 counterpart (late LOMCN / private-server addition) |
|  |  | 776 | Basic Worn Bag | no Mud3 EI2.0 counterpart (late LOMCN / private-server addition) |
|  |  | 777 | Fantastic Wool Bag | no Mud3 EI2.0 counterpart (late LOMCN / private-server addition) |
|  |  | 778 | Luxury Silk Box | no Mud3 EI2.0 counterpart (late LOMCN / private-server addition) |
|  |  | 779 | Angel Wings | no Mud3 EI2.0 counterpart (late LOMCN / private-server addition) |
|  |  | 780 | Angel Head Band | no Mud3 EI2.0 counterpart (late LOMCN / private-server addition) |
|  |  | 781 | Rabbit Head Band | no Mud3 EI2.0 counterpart (late LOMCN / private-server addition) |
|  |  | 782 | Refiner's Ore (Weapon) | no Mud3 EI2.0 counterpart (late LOMCN / private-server addition) |
|  |  | 783 | Refiner's Ore (Reset) | no Mud3 EI2.0 counterpart (late LOMCN / private-server addition) |
|  |  | 784 | Refiner's Ore (Safe Master) | no Mud3 EI2.0 counterpart (late LOMCN / private-server addition) |
|  |  | 785 | Refiner's Ore (Armour) | no Mud3 EI2.0 counterpart (late LOMCN / private-server addition) |
|  |  | 786 | Refiner's Ore (Master) | no Mud3 EI2.0 counterpart (late LOMCN / private-server addition) |
|  |  | 787 | Superior Repair Oil | no Mud3 EI2.0 counterpart (late LOMCN / private-server addition) |
|  |  | 788 | Accessory Repair Oil | no Mud3 EI2.0 counterpart (late LOMCN / private-server addition) |
|  |  | 789 | Armour Repair Oil | no Mud3 EI2.0 counterpart (late LOMCN / private-server addition) |
|  |  | 790 | Pill Of Reincarnation | no Mud3 EI2.0 counterpart (late LOMCN / private-server addition) |
|  |  | 792 | Potion Of Repentence (II) | no Mud3 EI2.0 counterpart (late LOMCN / private-server addition) |
|  |  | 795 | Iron Horse Armour | no Mud3 EI2.0 counterpart (late LOMCN / private-server addition) |
|  |  | 796 | Silver Horse Armour | no Mud3 EI2.0 counterpart (late LOMCN / private-server addition) |
|  |  | 797 | Gold Horse Armour | no Mud3 EI2.0 counterpart (late LOMCN / private-server addition) |
|  |  | 798 | Blue Horse Armour | no Mud3 EI2.0 counterpart (late LOMCN / private-server addition) |
|  |  | 799 | Dark Horse Armour | no Mud3 EI2.0 counterpart (late LOMCN / private-server addition) |
|  |  | 801 | Experience | no Mud3 EI2.0 counterpart (late LOMCN / private-server addition) |
|  |  | 802 | Wool | no Mud3 EI2.0 counterpart (late LOMCN / private-server addition) |
|  |  | 804 | Arachnid Teeth | no Mud3 EI2.0 counterpart (late LOMCN / private-server addition) |
|  |  | 805 | Spider Curare | no Mud3 EI2.0 counterpart (late LOMCN / private-server addition) |
|  |  | 806 | Edible Chestnut | no Mud3 EI2.0 counterpart (late LOMCN / private-server addition) |
|  |  | 807 | Skeletal Spine | no Mud3 EI2.0 counterpart (late LOMCN / private-server addition) |
|  |  | 808 | Henry's Journal | no Mud3 EI2.0 counterpart (late LOMCN / private-server addition) |
|  |  | 809 | David's Key | no Mud3 EI2.0 counterpart (late LOMCN / private-server addition) |
|  |  | 810 | Haylee's Key | no Mud3 EI2.0 counterpart (late LOMCN / private-server addition) |
|  |  | 811 | Kacy's Key | no Mud3 EI2.0 counterpart (late LOMCN / private-server addition) |
|  |  | 812 | Zombie Flesh | no Mud3 EI2.0 counterpart (late LOMCN / private-server addition) |
|  |  | 813 | Gresham's Journal | no Mud3 EI2.0 counterpart (late LOMCN / private-server addition) |
|  |  | 814 | Isaac's Journal | no Mud3 EI2.0 counterpart (late LOMCN / private-server addition) |
|  |  | 815 | Companion Ticket | no Mud3 EI2.0 counterpart (late LOMCN / private-server addition) |
|  |  | 818 | Pick Axe Of Storm | no Mud3 EI2.0 counterpart (late LOMCN / private-server addition) |
|  |  | 821 | Staff Of Retribution | no Mud3 EI2.0 counterpart (late LOMCN / private-server addition) |
|  |  | 822 | Ruination | no Mud3 EI2.0 counterpart (late LOMCN / private-server addition) |
|  |  | 826 | Muk's Unparalleled Polearm | no Mud3 EI2.0 counterpart (late LOMCN / private-server addition) |
|  |  | 828 | Refinement Stone | no Mud3 EI2.0 counterpart (late LOMCN / private-server addition) |
|  |  | 829 | Fragment | no Mud3 EI2.0 counterpart (late LOMCN / private-server addition) |
|  |  | 830 | Fragment (II) | no Mud3 EI2.0 counterpart (late LOMCN / private-server addition) |
|  |  | 831 | Fragment (III) | no Mud3 EI2.0 counterpart (late LOMCN / private-server addition) |
|  |  | 832 | Fragment (IV) | no Mud3 EI2.0 counterpart (late LOMCN / private-server addition) |
|  |  | 833 | The Sun Raiser | no Mud3 EI2.0 counterpart (late LOMCN / private-server addition) |
|  |  | 834 | Medallion Of The Eight Kings | no Mud3 EI2.0 counterpart (late LOMCN / private-server addition) |
|  |  | 835 | Ascension Bracelet | no Mud3 EI2.0 counterpart (late LOMCN / private-server addition) |
|  |  | 836 | Band Of Unstable Energy | no Mud3 EI2.0 counterpart (late LOMCN / private-server addition) |
|  |  | 837 | Pendant Of The Full Moon | no Mud3 EI2.0 counterpart (late LOMCN / private-server addition) |
|  |  | 838 | Dragon Bracelet Of Supremacy | no Mud3 EI2.0 counterpart (late LOMCN / private-server addition) |
|  |  | 839 | Gift Of Aquatic Guardian | no Mud3 EI2.0 counterpart (late LOMCN / private-server addition) |
|  |  | 840 | Medallion Of Underworld | no Mud3 EI2.0 counterpart (late LOMCN / private-server addition) |
|  |  | 841 | Keeper's Bracelet Of Insight | no Mud3 EI2.0 counterpart (late LOMCN / private-server addition) |
|  |  | 842 | Argent Sabatons Of Comet | no Mud3 EI2.0 counterpart (late LOMCN / private-server addition) |
|  |  | 843 | Lupine Headgear | no Mud3 EI2.0 counterpart (late LOMCN / private-server addition) |
|  |  | 845 | Raven Hood Of Covertness | no Mud3 EI2.0 counterpart (late LOMCN / private-server addition) |
|  |  | 847 | Advanced Bloody Flower | no Mud3 EI2.0 counterpart (late LOMCN / private-server addition) |
|  |  | 857 | Bloodthirsty Signet Of Carnage | no Mud3 EI2.0 counterpart (late LOMCN / private-server addition) |
|  |  | 858 | Celestial Loop Of The Stars | no Mud3 EI2.0 counterpart (late LOMCN / private-server addition) |
|  |  | 859 | Oracle's Loop Of Serenity | no Mud3 EI2.0 counterpart (late LOMCN / private-server addition) |
|  |  | 860 | Bloodthirsty Bracelet Of Carnage | no Mud3 EI2.0 counterpart (late LOMCN / private-server addition) |
|  |  | 861 | Celestial Bracelet Of The Stars | no Mud3 EI2.0 counterpart (late LOMCN / private-server addition) |
|  |  | 862 | Oracle's Bracer Of Serenity | no Mud3 EI2.0 counterpart (late LOMCN / private-server addition) |
|  |  | 863 | Bloodthirsty Pendant Of Carnage | no Mud3 EI2.0 counterpart (late LOMCN / private-server addition) |
|  |  | 864 | Celestial Amulet Of The Stars | no Mud3 EI2.0 counterpart (late LOMCN / private-server addition) |
|  |  | 865 | Oracle's Locket Of Serenity | no Mud3 EI2.0 counterpart (late LOMCN / private-server addition) |
|  |  | 868 | Rusty Seal Of Overlord | no Mud3 EI2.0 counterpart (late LOMCN / private-server addition) |
|  |  | 869 | Cracked Seal Of Overlord | no Mud3 EI2.0 counterpart (late LOMCN / private-server addition) |
|  |  | 870 | Worn Seal Of Overlord | no Mud3 EI2.0 counterpart (late LOMCN / private-server addition) |
|  |  | 871 | Rusty Bracelet Of Overlord | no Mud3 EI2.0 counterpart (late LOMCN / private-server addition) |
|  |  | 872 | Cracked Bracelet Of Overlord | no Mud3 EI2.0 counterpart (late LOMCN / private-server addition) |
|  |  | 873 | Worn Bracelet Of Overlord | no Mud3 EI2.0 counterpart (late LOMCN / private-server addition) |
|  |  | 874 | Scratched Bracelet Of Overlord | no Mud3 EI2.0 counterpart (late LOMCN / private-server addition) |
|  |  | 875 | Rusty Medallion Of Overlord | no Mud3 EI2.0 counterpart (late LOMCN / private-server addition) |
|  |  | 876 | Cracked Medallion Of Overlord | no Mud3 EI2.0 counterpart (late LOMCN / private-server addition) |
|  |  | 877 | Worn Medallion Of Overlord | no Mud3 EI2.0 counterpart (late LOMCN / private-server addition) |
|  |  | 878 | Rusty Signet Of Moon | no Mud3 EI2.0 counterpart (late LOMCN / private-server addition) |
|  |  | 879 | Cracked Signet Of Moon | no Mud3 EI2.0 counterpart (late LOMCN / private-server addition) |
|  |  | 880 | Worn Signet Of Moon | no Mud3 EI2.0 counterpart (late LOMCN / private-server addition) |
|  |  | 881 | Rusty Bracer Of Moon | no Mud3 EI2.0 counterpart (late LOMCN / private-server addition) |
|  |  | 882 | Cracked Bracer Of Moon | no Mud3 EI2.0 counterpart (late LOMCN / private-server addition) |
|  |  | 883 | Worn Bracer Of Moon | no Mud3 EI2.0 counterpart (late LOMCN / private-server addition) |
|  |  | 884 | Scratched Bracer Of Moon | no Mud3 EI2.0 counterpart (late LOMCN / private-server addition) |
|  |  | 885 | Rusty Pendant Of Moon | no Mud3 EI2.0 counterpart (late LOMCN / private-server addition) |
|  |  | 886 | Cracked Pendant Of Moon | no Mud3 EI2.0 counterpart (late LOMCN / private-server addition) |
|  |  | 887 | Worn Pendant Of Moon | no Mud3 EI2.0 counterpart (late LOMCN / private-server addition) |
|  |  | 888 | Rusty Band Of Dignity | no Mud3 EI2.0 counterpart (late LOMCN / private-server addition) |
|  |  | 889 | Cracked Band Of Dignity | no Mud3 EI2.0 counterpart (late LOMCN / private-server addition) |
|  |  | 890 | Worn Band Of Dignity | no Mud3 EI2.0 counterpart (late LOMCN / private-server addition) |
|  |  | 891 | Rusty Bracelet Of Dignity | no Mud3 EI2.0 counterpart (late LOMCN / private-server addition) |
|  |  | 892 | Cracked Bracelet Of Dignity | no Mud3 EI2.0 counterpart (late LOMCN / private-server addition) |
|  |  | 893 | Worn Bracelet Of Dignity | no Mud3 EI2.0 counterpart (late LOMCN / private-server addition) |
|  |  | 894 | Scratched Bracelet Of Dignity | no Mud3 EI2.0 counterpart (late LOMCN / private-server addition) |
|  |  | 895 | Rusty Amulet Of Dignity | no Mud3 EI2.0 counterpart (late LOMCN / private-server addition) |
|  |  | 896 | Cracked Amulet Of Dignity | no Mud3 EI2.0 counterpart (late LOMCN / private-server addition) |
|  |  | 897 | Worn Amulet Of Dignity | no Mud3 EI2.0 counterpart (late LOMCN / private-server addition) |
|  |  | 898 | East Chiwoo Iron | no Mud3 EI2.0 counterpart (late LOMCN / private-server addition) |
|  |  | 899 | West Chiwoo Iron | no Mud3 EI2.0 counterpart (late LOMCN / private-server addition) |
|  |  | 900 | Blade Of The Dragon Lord | no Mud3 EI2.0 counterpart (late LOMCN / private-server addition) |
|  |  | 901 | Loop Of The Dragon Lord | no Mud3 EI2.0 counterpart (late LOMCN / private-server addition) |
|  |  | 902 | Armband Of The Dragon Lord | no Mud3 EI2.0 counterpart (late LOMCN / private-server addition) |
|  |  | 903 | Amulet Of The Dragon Lord | no Mud3 EI2.0 counterpart (late LOMCN / private-server addition) |
|  |  | 904 | Greaves Of The Dragon Lord | no Mud3 EI2.0 counterpart (late LOMCN / private-server addition) |
|  |  | 905 | Headcover Of The Dragon Lord | no Mud3 EI2.0 counterpart (late LOMCN / private-server addition) |
|  |  | 906 | Frost Bite | no Mud3 EI2.0 counterpart (late LOMCN / private-server addition) |
|  |  | 907 | Argent Battleplate Of Might (M) | no Mud3 EI2.0 counterpart (late LOMCN / private-server addition) |
|  |  | 908 | Argent Battleplate Of Might (F) | no Mud3 EI2.0 counterpart (late LOMCN / private-server addition) |
|  |  | 909 | Sacred Warplate Of Mastery (M) | no Mud3 EI2.0 counterpart (late LOMCN / private-server addition) |
|  |  | 910 | Sacred Warplate Of Mastery (F) | no Mud3 EI2.0 counterpart (late LOMCN / private-server addition) |
|  |  | 911 | Blazing Raiment Of Phoenix (M) | no Mud3 EI2.0 counterpart (late LOMCN / private-server addition) |
|  |  | 912 | Blazing Raiment Of Phoenix (F) | no Mud3 EI2.0 counterpart (late LOMCN / private-server addition) |
|  |  | 913 | Azure Raiment Of Illusion (M) | no Mud3 EI2.0 counterpart (late LOMCN / private-server addition) |
|  |  | 914 | Azure Raiment Of Illusion (F) | no Mud3 EI2.0 counterpart (late LOMCN / private-server addition) |
|  |  | 915 | Wyvern Scale Armour (M) | no Mud3 EI2.0 counterpart (late LOMCN / private-server addition) |
|  |  | 916 | Wyvern Scale Armour (F) | no Mud3 EI2.0 counterpart (late LOMCN / private-server addition) |
|  |  | 917 | Armour Of Demonic Wrath (M) | no Mud3 EI2.0 counterpart (late LOMCN / private-server addition) |
|  |  | 918 | Armour Of Demonic Wrath (F) | no Mud3 EI2.0 counterpart (late LOMCN / private-server addition) |
|  |  | 919 | Blazing Raiment Of Embers (M) | no Mud3 EI2.0 counterpart (late LOMCN / private-server addition) |
|  |  | 920 | Blazing Raiment Of Embers (F) | no Mud3 EI2.0 counterpart (late LOMCN / private-server addition) |
|  |  | 921 | Demonic Raiment Of Illusion (M) | no Mud3 EI2.0 counterpart (late LOMCN / private-server addition) |
|  |  | 922 | Demonic Raiment Of Illusion (F) | no Mud3 EI2.0 counterpart (late LOMCN / private-server addition) |
|  |  | 923 | Seal Of Overlord | no Mud3 EI2.0 counterpart (late LOMCN / private-server addition) |
|  |  | 924 | Bracelet Of Overlord | no Mud3 EI2.0 counterpart (late LOMCN / private-server addition) |
|  |  | 925 | Medallion Of Overlord | no Mud3 EI2.0 counterpart (late LOMCN / private-server addition) |
|  |  | 926 | Arcanist's Band Of Dignity | no Mud3 EI2.0 counterpart (late LOMCN / private-server addition) |
|  |  | 927 | Arcanist's Bracelet Of Dignity | no Mud3 EI2.0 counterpart (late LOMCN / private-server addition) |
|  |  | 928 | Arcanist's Amulet Of Dignity | no Mud3 EI2.0 counterpart (late LOMCN / private-server addition) |
|  |  | 929 | Hierophant's Signet Of Moon | no Mud3 EI2.0 counterpart (late LOMCN / private-server addition) |
|  |  | 930 | Hierophant's Bracer Of Moon | no Mud3 EI2.0 counterpart (late LOMCN / private-server addition) |
|  |  | 931 | Hierophant's Pendant Of Moon | no Mud3 EI2.0 counterpart (late LOMCN / private-server addition) |
|  |  | 932 | Fortune Checker | no Mud3 EI2.0 counterpart (late LOMCN / private-server addition) |
|  |  | 933 | [Part] | no Mud3 EI2.0 counterpart (late LOMCN / private-server addition) |
|  |  | 934 | Tonic of Comfort [T] | no Mud3 EI2.0 counterpart (late LOMCN / private-server addition) |
|  |  | 935 | Helmet Of Dragon Abyss | no Mud3 EI2.0 counterpart (late LOMCN / private-server addition) |
|  |  | 936 | Armour Of Abyss (M) | no Mud3 EI2.0 counterpart (late LOMCN / private-server addition) |
|  |  | 937 | Armour Of Abyss (F) | no Mud3 EI2.0 counterpart (late LOMCN / private-server addition) |
|  |  | 938 | Pendant Of Dragon Abyss | no Mud3 EI2.0 counterpart (late LOMCN / private-server addition) |
|  |  | 939 | Armguard Of Dragon Abyss | no Mud3 EI2.0 counterpart (late LOMCN / private-server addition) |
|  |  | 940 | Band Of Dragon Abyss | no Mud3 EI2.0 counterpart (late LOMCN / private-server addition) |
|  |  | 941 | Greaves Of Dragon Abyss | no Mud3 EI2.0 counterpart (late LOMCN / private-server addition) |
|  |  | 942 | Jade Choker Of Purity | no Mud3 EI2.0 counterpart (late LOMCN / private-server addition) |
|  |  | 943 | Amulet Of Redemption | no Mud3 EI2.0 counterpart (late LOMCN / private-server addition) |
|  |  | 944 | Jade Bracelet Of Purity | no Mud3 EI2.0 counterpart (late LOMCN / private-server addition) |
|  |  | 945 | Bracelet Of Redemption | no Mud3 EI2.0 counterpart (late LOMCN / private-server addition) |
|  |  | 946 | Jade Band Of Purity | no Mud3 EI2.0 counterpart (late LOMCN / private-server addition) |
|  |  | 947 | Signet Of Redemption | no Mud3 EI2.0 counterpart (late LOMCN / private-server addition) |
|  |  | 948 | Overlord's Battleplate (M) | no Mud3 EI2.0 counterpart (late LOMCN / private-server addition) |
|  |  | 949 | Overlord's Battleplate (F) | no Mud3 EI2.0 counterpart (late LOMCN / private-server addition) |
|  |  | 950 | Dragon Necklace Of Revival | no Mud3 EI2.0 counterpart (late LOMCN / private-server addition) |
|  |  | 951 | Dragon Bracelet Of Revival | no Mud3 EI2.0 counterpart (late LOMCN / private-server addition) |
|  |  | 952 | Dragon Ring Of Revival | no Mud3 EI2.0 counterpart (late LOMCN / private-server addition) |
|  |  | 953 | Wraith Blade Of Sama | no Mud3 EI2.0 counterpart (late LOMCN / private-server addition) |
|  |  | 954 | Ancestral Tablet Of Sama Mage | no Mud3 EI2.0 counterpart (late LOMCN / private-server addition) |
|  |  | 955 | Elementalist's Battleplate (M) | no Mud3 EI2.0 counterpart (late LOMCN / private-server addition) |
|  |  | 956 | Elementalist's Battleplate (F) | no Mud3 EI2.0 counterpart (late LOMCN / private-server addition) |
|  |  | 957 | Archon's Battleplate (M) | no Mud3 EI2.0 counterpart (late LOMCN / private-server addition) |
|  |  | 958 | Archon's Battleplate (F) | no Mud3 EI2.0 counterpart (late LOMCN / private-server addition) |
|  |  | 959 | Burning Blade Of Sama | no Mud3 EI2.0 counterpart (late LOMCN / private-server addition) |
|  |  | 960 | Unholy Blade Of Sama | no Mud3 EI2.0 counterpart (late LOMCN / private-server addition) |
|  |  | 961 | Blades Of Sama | no Mud3 EI2.0 counterpart (late LOMCN / private-server addition) |
|  |  | 962 | Old Carrot | no Mud3 EI2.0 counterpart (late LOMCN / private-server addition) |
|  |  | 963 | Mass Beckon | no Mud3 EI2.0 counterpart (late LOMCN / private-server addition) |
|  |  | 964 | Asteroid | no Mud3 EI2.0 counterpart (late LOMCN / private-server addition) |
|  |  | 965 | Infection | no Mud3 EI2.0 counterpart (late LOMCN / private-server addition) |
|  |  | 966 | Massacre | no Mud3 EI2.0 counterpart (late LOMCN / private-server addition) |
|  |  | 967 | Weapon Template | no Mud3 EI2.0 counterpart (late LOMCN / private-server addition) |
|  |  | 968 | Warrior's Edge | no Mud3 EI2.0 counterpart (late LOMCN / private-server addition) |
|  |  | 969 | Wizard's Edge | no Mud3 EI2.0 counterpart (late LOMCN / private-server addition) |
|  |  | 970 | Taoist's Edge | no Mud3 EI2.0 counterpart (late LOMCN / private-server addition) |
|  |  | 971 | Assassin's Edge | no Mud3 EI2.0 counterpart (late LOMCN / private-server addition) |
|  |  | 972 | Yellow Cube | no Mud3 EI2.0 counterpart (late LOMCN / private-server addition) |
|  |  | 973 | Blue Cube | no Mud3 EI2.0 counterpart (late LOMCN / private-server addition) |
|  |  | 974 | Red Cube | no Mud3 EI2.0 counterpart (late LOMCN / private-server addition) |
|  |  | 975 | Purple Cube | no Mud3 EI2.0 counterpart (late LOMCN / private-server addition) |
|  |  | 976 | Green Cube | no Mud3 EI2.0 counterpart (late LOMCN / private-server addition) |
|  |  | 977 | Grey Cube | no Mud3 EI2.0 counterpart (late LOMCN / private-server addition) |
|  |  | 978 | Yellow Orb | no Mud3 EI2.0 counterpart (late LOMCN / private-server addition) |
|  |  | 979 | Blue Orb | no Mud3 EI2.0 counterpart (late LOMCN / private-server addition) |
|  |  | 980 | Red Orb | no Mud3 EI2.0 counterpart (late LOMCN / private-server addition) |
|  |  | 981 | Purple Orb | no Mud3 EI2.0 counterpart (late LOMCN / private-server addition) |
|  |  | 982 | Green Orb | no Mud3 EI2.0 counterpart (late LOMCN / private-server addition) |
|  |  | 983 | Grey Orb | no Mud3 EI2.0 counterpart (late LOMCN / private-server addition) |
|  |  | 984 | Yellow Trinket | no Mud3 EI2.0 counterpart (late LOMCN / private-server addition) |
|  |  | 985 | Blue Trinket | no Mud3 EI2.0 counterpart (late LOMCN / private-server addition) |
|  |  | 986 | Red Trinket | no Mud3 EI2.0 counterpart (late LOMCN / private-server addition) |
|  |  | 987 | Purple Trinket | no Mud3 EI2.0 counterpart (late LOMCN / private-server addition) |
|  |  | 988 | Green Trinket | no Mud3 EI2.0 counterpart (late LOMCN / private-server addition) |
|  |  | 989 | Grey Trinket | no Mud3 EI2.0 counterpart (late LOMCN / private-server addition) |
|  |  | 990 | Carrot | no Mud3 EI2.0 counterpart (late LOMCN / private-server addition) |
|  |  | 991 | Potion of Greed | no Mud3 EI2.0 counterpart (late LOMCN / private-server addition) |
|  |  | 992 | Novice Emblem | no Mud3 EI2.0 counterpart (late LOMCN / private-server addition) |
|  |  | 993 | Expert Emblem | no Mud3 EI2.0 counterpart (late LOMCN / private-server addition) |
|  |  | 994 | Elite Emblem | no Mud3 EI2.0 counterpart (late LOMCN / private-server addition) |
|  |  | 995 | Heavy Boots | no Mud3 EI2.0 counterpart (late LOMCN / private-server addition) |
|  |  | 996 | Old Whistle | no Mud3 EI2.0 counterpart (late LOMCN / private-server addition) |
|  |  | 997 | White Whistle | no Mud3 EI2.0 counterpart (late LOMCN / private-server addition) |
|  |  | 998 | FootBall Kit (M) | no Mud3 EI2.0 counterpart (late LOMCN / private-server addition) |
|  |  | 999 | FootBall Kit (F) | no Mud3 EI2.0 counterpart (late LOMCN / private-server addition) |
|  |  | 1000 | Tunic of the Blood God (M) | no Mud3 EI2.0 counterpart (late LOMCN / private-server addition) |
|  |  | 1001 | Tunic of the Blood God (F) | no Mud3 EI2.0 counterpart (late LOMCN / private-server addition) |
|  |  | 1002 | Armour of the Blessed King | no Mud3 EI2.0 counterpart (late LOMCN / private-server addition) |
|  |  | 1003 | Armour of the Blessed Queen | no Mud3 EI2.0 counterpart (late LOMCN / private-server addition) |
|  |  | 1004 | Vestment of Shattered Souls (M) | no Mud3 EI2.0 counterpart (late LOMCN / private-server addition) |
|  |  | 1005 | Vestment of Shattered Souls (F) | no Mud3 EI2.0 counterpart (late LOMCN / private-server addition) |
|  |  | 1006 | Robes of the Blessed One (M) | no Mud3 EI2.0 counterpart (late LOMCN / private-server addition) |
|  |  | 1007 | Robes of the Blessed One (F) | no Mud3 EI2.0 counterpart (late LOMCN / private-server addition) |
|  |  | 1008 | Valhalla, The Last Hope | no Mud3 EI2.0 counterpart (late LOMCN / private-server addition) |
|  |  | 1009 | Spellkeeper, Knowledge of the Ancients | no Mud3 EI2.0 counterpart (late LOMCN / private-server addition) |
|  |  | 1010 | Moonlight, Light in the Darkness | no Mud3 EI2.0 counterpart (late LOMCN / private-server addition) |
|  |  | 1011 | Echo, Blades of Torment | no Mud3 EI2.0 counterpart (late LOMCN / private-server addition) |
|  |  | 1012 | Garnet Ring | no Mud3 EI2.0 counterpart (late LOMCN / private-server addition) |
|  |  | 1013 | Lapis Lazuli Ring | no Mud3 EI2.0 counterpart (late LOMCN / private-server addition) |
|  |  | 1014 | Malachite Ring | no Mud3 EI2.0 counterpart (late LOMCN / private-server addition) |
|  |  | 1015 | Garnet Bracelet | no Mud3 EI2.0 counterpart (late LOMCN / private-server addition) |
|  |  | 1016 | Lapis Lazuli Bracelet | no Mud3 EI2.0 counterpart (late LOMCN / private-server addition) |
|  |  | 1017 | Malachite Bracelet | no Mud3 EI2.0 counterpart (late LOMCN / private-server addition) |
|  |  | 1018 | Garnet Necklace | no Mud3 EI2.0 counterpart (late LOMCN / private-server addition) |
|  |  | 1019 | Lapis Lazuli Necklace | no Mud3 EI2.0 counterpart (late LOMCN / private-server addition) |
|  |  | 1020 | Malachite Necklace | no Mud3 EI2.0 counterpart (late LOMCN / private-server addition) |
|  |  | 1021 | Alpha, Hammer of Cruelty | no Mud3 EI2.0 counterpart (late LOMCN / private-server addition) |
|  |  | 1022 | Sunshard, Elements Fury | no Mud3 EI2.0 counterpart (late LOMCN / private-server addition) |
|  |  | 1023 | Dawnseeker,  Lights Vengeance | no Mud3 EI2.0 counterpart (late LOMCN / private-server addition) |
|  |  | 1024 | Reaper, The Tri-blade | no Mud3 EI2.0 counterpart (late LOMCN / private-server addition) |
|  |  | 1025 | Nemesis, The Blade of Betrayal | no Mud3 EI2.0 counterpart (late LOMCN / private-server addition) |
|  |  | 1026 | Deluge, Winter's Might | no Mud3 EI2.0 counterpart (late LOMCN / private-server addition) |
|  |  | 1027 | Celestia, Fan of the Heavens | no Mud3 EI2.0 counterpart (late LOMCN / private-server addition) |
|  |  | 1028 | Chaos, The Spiral Death | no Mud3 EI2.0 counterpart (late LOMCN / private-server addition) |
|  |  | 1037 | Armour of the Sun Keeper (M) | no Mud3 EI2.0 counterpart (late LOMCN / private-server addition) |
|  |  | 1038 | Armour of the Sun Keeper (F) | no Mud3 EI2.0 counterpart (late LOMCN / private-server addition) |
|  |  | 1039 | Armour of Arcane Fury (M) | no Mud3 EI2.0 counterpart (late LOMCN / private-server addition) |
|  |  | 1040 | Armour of Arcane Fury (F) | no Mud3 EI2.0 counterpart (late LOMCN / private-server addition) |
|  |  | 1041 | Armour of Eternal Rest (M) | no Mud3 EI2.0 counterpart (late LOMCN / private-server addition) |
|  |  | 1042 | Armour of Eternal Rest (F) | no Mud3 EI2.0 counterpart (late LOMCN / private-server addition) |
|  |  | 1043 | Tunic of Whispers (M) | no Mud3 EI2.0 counterpart (late LOMCN / private-server addition) |
|  |  | 1044 | Tunic of Whispers (F) | no Mud3 EI2.0 counterpart (late LOMCN / private-server addition) |
|  |  | 1045 | Kingsguard Helmet | no Mud3 EI2.0 counterpart (late LOMCN / private-server addition) |
|  |  | 1046 | Shimmering Light Crown | no Mud3 EI2.0 counterpart (late LOMCN / private-server addition) |
|  |  | 1047 | Half Moon Hood | no Mud3 EI2.0 counterpart (late LOMCN / private-server addition) |
|  |  | 1048 | Nightstalkers Cowl | no Mud3 EI2.0 counterpart (late LOMCN / private-server addition) |
|  |  | 1049 | Masters Emblem | no Mud3 EI2.0 counterpart (late LOMCN / private-server addition) |
|  |  | 1050 | Champions Emblem | no Mud3 EI2.0 counterpart (late LOMCN / private-server addition) |
|  |  | 1051 | Kings Emblem | no Mud3 EI2.0 counterpart (late LOMCN / private-server addition) |
|  |  | 1052 | Zirconian Emblem | no Mud3 EI2.0 counterpart (late LOMCN / private-server addition) |
|  |  | 1053 | Striking Boots | no Mud3 EI2.0 counterpart (late LOMCN / private-server addition) |
|  |  | 1054 | Swiftcaster Boots | no Mud3 EI2.0 counterpart (late LOMCN / private-server addition) |
|  |  | 1055 | Lifeseeker Boots | no Mud3 EI2.0 counterpart (late LOMCN / private-server addition) |
|  |  | 1057 | Obsidian Ring | no Mud3 EI2.0 counterpart (late LOMCN / private-server addition) |
|  |  | 1058 | Sapphire Ring | no Mud3 EI2.0 counterpart (late LOMCN / private-server addition) |
|  |  | 1059 | Alexandrite Ring | no Mud3 EI2.0 counterpart (late LOMCN / private-server addition) |
|  |  | 1060 | Obsidian Bracelet | no Mud3 EI2.0 counterpart (late LOMCN / private-server addition) |
|  |  | 1061 | Sapphire Bracelet | no Mud3 EI2.0 counterpart (late LOMCN / private-server addition) |
|  |  | 1062 | Alexandrite Bracelet | no Mud3 EI2.0 counterpart (late LOMCN / private-server addition) |
|  |  | 1063 | Obsidian Necklace | no Mud3 EI2.0 counterpart (late LOMCN / private-server addition) |
|  |  | 1064 | Sapphire Necklace | no Mud3 EI2.0 counterpart (late LOMCN / private-server addition) |
|  |  | 1065 | Alexandrite Necklace | no Mud3 EI2.0 counterpart (late LOMCN / private-server addition) |
|  |  | 1066 | Tonic of Collection [T] | no Mud3 EI2.0 counterpart (late LOMCN / private-server addition) |
|  |  | 1067 | Dusk Bracelet | no Mud3 EI2.0 counterpart (late LOMCN / private-server addition) |
|  |  | 1068 | Crushing Bracelet | no Mud3 EI2.0 counterpart (late LOMCN / private-server addition) |
|  |  | 1069 | Odyn Son | no Mud3 EI2.0 counterpart (late LOMCN / private-server addition) |
|  |  | 1070 | Odyn Mythical | no Mud3 EI2.0 counterpart (late LOMCN / private-server addition) |
|  |  | 1072 | Odyn Elemental | no Mud3 EI2.0 counterpart (late LOMCN / private-server addition) |
|  |  | 1073 | Crushing Ring | no Mud3 EI2.0 counterpart (late LOMCN / private-server addition) |
|  |  | 1074 | Occult Ring | no Mud3 EI2.0 counterpart (late LOMCN / private-server addition) |
|  |  | 1075 | Radiant Ring | no Mud3 EI2.0 counterpart (late LOMCN / private-server addition) |
|  |  | 1076 | Occult Bracelet | no Mud3 EI2.0 counterpart (late LOMCN / private-server addition) |
|  |  | 1077 | Radiant Bracelet | no Mud3 EI2.0 counterpart (late LOMCN / private-server addition) |
|  |  | 1078 | Dusk Ring | no Mud3 EI2.0 counterpart (late LOMCN / private-server addition) |
|  |  | 1079 | Odyn Sin | no Mud3 EI2.0 counterpart (late LOMCN / private-server addition) |
|  |  | 1080 | Radiant Necklace | no Mud3 EI2.0 counterpart (late LOMCN / private-server addition) |
|  |  | 1081 | Occult Necklace | no Mud3 EI2.0 counterpart (late LOMCN / private-server addition) |
|  |  | 1082 | Crushing Necklace | no Mud3 EI2.0 counterpart (late LOMCN / private-server addition) |
|  |  | 1083 | Dusk Necklace | no Mud3 EI2.0 counterpart (late LOMCN / private-server addition) |
|  |  | 1084 | Seismic Slam | no Mud3 EI2.0 counterpart (late LOMCN / private-server addition) |
|  |  | 1085 | Demonic Recovery | no Mud3 EI2.0 counterpart (late LOMCN / private-server addition) |
|  |  | 1086 | Storm | no Mud3 EI2.0 counterpart (late LOMCN / private-server addition) |
|  |  | 1087 | Art of Shadows | no Mud3 EI2.0 counterpart (late LOMCN / private-server addition) |
|  |  | 1088 | Worm Squashers | no Mud3 EI2.0 counterpart (late LOMCN / private-server addition) |
|  |  | 1089 | PVP Champion | no Mud3 EI2.0 counterpart (late LOMCN / private-server addition) |
|  |  | 1090 | PVP Apprentice | no Mud3 EI2.0 counterpart (late LOMCN / private-server addition) |
|  |  | 1092 | Stat Extractor | no Mud3 EI2.0 counterpart (late LOMCN / private-server addition) |
|  |  | 1093 | Stat Extractor | no Mud3 EI2.0 counterpart (late LOMCN / private-server addition) |
|  |  | 1094 | Elixir Of Regret Lv 11 | no Mud3 EI2.0 counterpart (late LOMCN / private-server addition) |
|  |  | 1095 | Elixir Of Regret Lv 13 | no Mud3 EI2.0 counterpart (late LOMCN / private-server addition) |
|  |  | 1096 | Elixir Of Regret Lv 15 | no Mud3 EI2.0 counterpart (late LOMCN / private-server addition) |
|  |  | 1098 | Item Polisher | no Mud3 EI2.0 counterpart (late LOMCN / private-server addition) |
|  |  | 1099 | Armour Polisher | no Mud3 EI2.0 counterpart (late LOMCN / private-server addition) |
|  |  | 1101 | Tunic of Vengence (F) | no Mud3 EI2.0 counterpart (late LOMCN / private-server addition) |
|  |  | 1103 | Tunic of Vengence (M) | no Mud3 EI2.0 counterpart (late LOMCN / private-server addition) |
|  |  | 1104 | Armour of the Titan Slayer (M) | no Mud3 EI2.0 counterpart (late LOMCN / private-server addition) |
|  |  | 1105 | Armour of the Titan Slayer (F) | no Mud3 EI2.0 counterpart (late LOMCN / private-server addition) |
|  |  | 1106 | Rainments of the Blazing Comet (M) | no Mud3 EI2.0 counterpart (late LOMCN / private-server addition) |
|  |  | 1107 | Rainments of the Blazing Comet (F) | no Mud3 EI2.0 counterpart (late LOMCN / private-server addition) |
|  |  | 1108 | Robes of the Titan Slayer (M) | no Mud3 EI2.0 counterpart (late LOMCN / private-server addition) |
|  |  | 1109 | Robes of the Titan Slayer (F) | no Mud3 EI2.0 counterpart (late LOMCN / private-server addition) |
|  |  | 1110 | Refine Extractor | no Mud3 EI2.0 counterpart (late LOMCN / private-server addition) |
|  |  | 1111 | Refine Extractor | no Mud3 EI2.0 counterpart (late LOMCN / private-server addition) |
|  |  | 1112 | Wooden Shield | no Mud3 EI2.0 counterpart (late LOMCN / private-server addition) |
|  |  | 1113 | Bronze Shield | no Mud3 EI2.0 counterpart (late LOMCN / private-server addition) |
|  |  | 1114 | Iron Shield | no Mud3 EI2.0 counterpart (late LOMCN / private-server addition) |
|  |  | 1115 | Ice Spike Shield | no Mud3 EI2.0 counterpart (late LOMCN / private-server addition) |
|  |  | 1116 | Defenders Embrace | no Mud3 EI2.0 counterpart (late LOMCN / private-server addition) |
|  |  | 1117 | Reflection Mirror Shield | no Mud3 EI2.0 counterpart (late LOMCN / private-server addition) |
|  |  | 1118 | Maple Guard Adamantine Shield | no Mud3 EI2.0 counterpart (late LOMCN / private-server addition) |
|  |  | 1119 | Barrage breaker Phoenix Shield | no Mud3 EI2.0 counterpart (late LOMCN / private-server addition) |
|  |  | 1120 | Santa Outfit (F) | no Mud3 EI2.0 counterpart (late LOMCN / private-server addition) |
|  |  | 1121 | Santa Outfit (M) | no Mud3 EI2.0 counterpart (late LOMCN / private-server addition) |
|  |  | 1122 | Valkyrie Blade of Reckoning | no Mud3 EI2.0 counterpart (late LOMCN / private-server addition) |
|  |  | 1123 | Lifebinder The Ancient Healer | no Mud3 EI2.0 counterpart (late LOMCN / private-server addition) |
|  |  | 1124 | Crescent Moon Cry of the Fallen | no Mud3 EI2.0 counterpart (late LOMCN / private-server addition) |
|  |  | 1125 | StormCaller The Sky Blade | no Mud3 EI2.0 counterpart (late LOMCN / private-server addition) |
|  |  | 1126 | Companion Experience Tonic [T] | no Mud3 EI2.0 counterpart (late LOMCN / private-server addition) |
|  |  | 1127 | Fame Point | no Mud3 EI2.0 counterpart (late LOMCN / private-server addition) |
|  |  | 1128 | Contribution Point | no Mud3 EI2.0 counterpart (late LOMCN / private-server addition) |
|  |  | 1129 | Advanced Potion Mastery | no Mud3 EI2.0 counterpart (late LOMCN / private-server addition) |
|  |  | 1130 | Invincibility | no Mud3 EI2.0 counterpart (late LOMCN / private-server addition) |
|  |  | 1131 | Crushing Wave | no Mud3 EI2.0 counterpart (late LOMCN / private-server addition) |
|  |  | 1132 | Defensive Mastery | no Mud3 EI2.0 counterpart (late LOMCN / private-server addition) |
|  |  | 1133 | Physical Immunity | no Mud3 EI2.0 counterpart (late LOMCN / private-server addition) |
|  |  | 1134 | Magic Immunity | no Mud3 EI2.0 counterpart (late LOMCN / private-server addition) |
|  |  | 1135 | Defensive Blow | no Mud3 EI2.0 counterpart (late LOMCN / private-server addition) |
|  |  | 1136 | Elemental Swords | no Mud3 EI2.0 counterpart (late LOMCN / private-server addition) |
|  |  | 1137 | Tornado | no Mud3 EI2.0 counterpart (late LOMCN / private-server addition) |
|  |  | 1138 | Neutralize | no Mud3 EI2.0 counterpart (late LOMCN / private-server addition) |
|  |  | 1139 | Empowered Neutralize | no Mud3 EI2.0 counterpart (late LOMCN / private-server addition) |
|  |  | 1140 | Dark Soul Prison | no Mud3 EI2.0 counterpart (late LOMCN / private-server addition) |
|  |  | 1141 | Searing Light | no Mud3 EI2.0 counterpart (late LOMCN / private-server addition) |
|  |  | 1142 | Empowered Celestial Light | no Mud3 EI2.0 counterpart (late LOMCN / private-server addition) |
|  |  | 1143 | Corpse Exploder | no Mud3 EI2.0 counterpart (late LOMCN / private-server addition) |
|  |  | 1144 | Summon Dead | no Mud3 EI2.0 counterpart (late LOMCN / private-server addition) |
|  |  | 1145 | Dragon Blood | no Mud3 EI2.0 counterpart (late LOMCN / private-server addition) |
|  |  | 1146 | Fatal Blow | no Mud3 EI2.0 counterpart (late LOMCN / private-server addition) |
|  |  | 1147 | Last Stand | no Mud3 EI2.0 counterpart (late LOMCN / private-server addition) |
|  |  | 1148 | Magic Combustion | no Mud3 EI2.0 counterpart (late LOMCN / private-server addition) |
|  |  | 1149 | Vitality | no Mud3 EI2.0 counterpart (late LOMCN / private-server addition) |
|  |  | 1150 | Chain | no Mud3 EI2.0 counterpart (late LOMCN / private-server addition) |
|  |  | 1151 | Concentration | no Mud3 EI2.0 counterpart (late LOMCN / private-server addition) |
|  |  | 1152 | Dual Weapon Skills | no Mud3 EI2.0 counterpart (late LOMCN / private-server addition) |
|  |  | 1153 | Containment | no Mud3 EI2.0 counterpart (late LOMCN / private-server addition) |
|  |  | 1154 | Dragon Wave | no Mud3 EI2.0 counterpart (late LOMCN / private-server addition) |
|  |  | 1155 | Hemorrhage | no Mud3 EI2.0 counterpart (late LOMCN / private-server addition) |
|  |  | 1156 | Burning Fire | no Mud3 EI2.0 counterpart (late LOMCN / private-server addition) |
|  |  | 1157 | Chain Of Fire | no Mud3 EI2.0 counterpart (late LOMCN / private-server addition) |
|  |  | 1158 | War Thurible | no Mud3 EI2.0 counterpart (late LOMCN / private-server addition) |
|  |  | 1159 | Penance Thurible | no Mud3 EI2.0 counterpart (late LOMCN / private-server addition) |
|  |  | 1160 | Censorship Thurible | no Mud3 EI2.0 counterpart (late LOMCN / private-server addition) |
|  |  | 1161 | Petrichor Thurible | no Mud3 EI2.0 counterpart (late LOMCN / private-server addition) |
|  |  | 1162 | Chaotic Heaven Blade | no Mud3 EI2.0 counterpart (late LOMCN / private-server addition) |
|  |  | 1163 | Janitors Scimitar | no Mud3 EI2.0 counterpart (late LOMCN / private-server addition) |
|  |  | 1164 | Janitors Dual Blade | no Mud3 EI2.0 counterpart (late LOMCN / private-server addition) |
|  |  | 1165 | Chaotic Heaven Blade 2 | no Mud3 EI2.0 counterpart (late LOMCN / private-server addition) |
|  |  | 1166 | Royal Horse Armour | no Mud3 EI2.0 counterpart (late LOMCN / private-server addition) |
|  |  | 1167 | Blue Dragon Armour | no Mud3 EI2.0 counterpart (late LOMCN / private-server addition) |
