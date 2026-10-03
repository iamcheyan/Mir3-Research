# Mud3 ↔ Zircon 怪物身份表（monster）

> 只读产出，不改 `System.db` / `db_names.json` / Zircon C#。
> 权威契约见本目录 `README.md` 与 `Zircon/docs/pending/MUD3_CONTENT_AND_LEGACY_BAG_HANDOFF_2026-10-03.md` §1.4。
> 生成：`build_monster_identity.py`（2026-10-03）。Mud3 433 条 / Zircon 434 行。

## 强制锚点（不得违反）

| Mud3 中文 | Zircon 身份 | Index |
|---|---|---:|
| 半兽人 | `Oma` | 22 |
| 沃玛教主 | `Uma King` | 65 |
| 祖玛教主 | `Zuma King` | 81 |

`Uma King` 与 `Zuma King` 是两条不同怪，不得都译成「祖玛王」。

## 数量（按 confidence）

| confidence | 数量 |
|---|---:|
| closed | 64 |
| pending | 86 |
| missing | 283 |
| zircon-only | 284 |

自检：`closed+pending+missing == 433`，`closed+pending+zircon-only == 434`，`closed` 无重复 `zircon_index`，`closed/pending` 引用亦无重复。

> **pending 的 `zircon_index` 只是候选（人工勾选用），不是定案映射，禁止据此写库。**

## closed（1:1，主证据闭合）（64）

| Mud3 Index | Mud3 中文名 | Zircon Index | Zircon 身份 | 证据 |
|---|---|---:|---|---|
| 8 | 赤月恶魔 | 75 | Red Moon The Fallen | 已审锚点 Red Moon The Fallen（manifest verified-alias） |
| 9 | 火焰狮子 | 448 | Flame Lion | 已审锚点 Flame Lion（manifest high） |
| 12 | 祖玛教主 | 81 | Zuma King | 强制锚点 Zuma King（README 不得违反） |
| 13 | 蝎蛇 | 126 | Claw Serpent | 数值锚点：Level 30=30 |
| 17 | 食人花 | 17 | Carnivorous Plant | 数值锚点：Level 10=10；HP 21=21 |
| 23 | 霸王教主 | 115 | Emperor Sa'Woo | 已审锚点 Emperor Sa'Woo（manifest verified, 老版 20000→21000 最近） |
| 28 | 半兽人 | 22 | Oma | 数值锚点：Level 13=13；强制锚点 Oma（README 不得违反） |
| 35 | 半兽战士 | 18 | Oma Warrior | 数值锚点：Level 13=13；HP 50=50 |
| 56 | 触角神魔 | 421 | Otherworld Tentacle Demon | 已审锚点 Otherworld Tentacle Demon（manifest medium, 异界触手族） |
| 61 | 大法老 | 399 | Great Pharaoh | 已审锚点 Great Pharaoh（manifest high, 名=Great Pharaoh） |
| 62 | 大老鼠 | 79 | Vicious Rat | 数值锚点：Level 45=45 |
| 65 | 稻草人 | 21 | Scarecrow | 数值锚点：Level 10=10 |
| 67 | 地牢女神1 | 395 | Dungeon Goddess 1 | 已审锚点 Dungeon Goddess 1（manifest high） |
| 69 | 地牢女神2 | 396 | Dungeon Goddess 2 | 已审锚点 Dungeon Goddess 2（manifest high） |
| 73 | 洞蛆 | 31 | Cave Maggot | 数值锚点：Level 20=20 |
| 75 | 毒蜘蛛 | 20 | Spitting Spider | 数值锚点：Level 10=10；HP 22=22 |
| 80 | 多钩猫 | 13 | Claw Cat | 数值锚点：Level 10=10；HP 20=20 |
| 97 | 骨鬼将 | 404 | Corpse Bone Spirit | 已审锚点 Corpse Bone Spirit（manifest high） |
| 106 | 黑野猪 | 127 | Black Boar | 数值锚点：Level 30=30；已审锚点 Black Boar（manifest high） |
| 111 | 红野猪 | 125 | Red Boar | 数值锚点：Level 30=30；已审锚点 Red Boar（manifest high） |
| 117 | 虎蛇 | 19 | Tiger Snake | 数值锚点：Level 15=15；HP 70=70 |
| 132 | 鸡 | 8 | Chicken | 已审锚点 Chicken（manifest high） |
| 150 | 角蝇 | 472 | Fly | 数值锚点：Level 30=30；已审锚点 Fly（manifest high） |
| 159 | 骷髅 | 27 | Skeleton | 数值锚点：Level 18=18；HP 100=100 |
| 165 | 骷髅教主 | 121 | Arch Lich Taedu | 已审锚点 Arch Lich Taedu（manifest medium, 老版 10000→15000） |
| 176 | 骷髅战将 | 26 | Skeleton Axeman | 数值锚点：Level 18=18 |
| 180 | 骷髅战士 | 29 | Skeleton Warrior | 数值锚点：Level 18=18 |
| 183 | 盔甲虫 | 43 | Beetle | 数值锚点：Level 13=13 |
| 198 | 掷斧骷髅 | 28 | Skeleton Axe Thrower | 数值锚点：Level 18=18；HP 100=100 |
| 202 | 猪 | 9 | Pig | 已审锚点 Pig（manifest high；Zircon 另有 Lv0 宠物版 189） |
| 209 | 祖玛卫士 | 78 | Zuma Guardian | 数值锚点：Level 45=45 |
| 216 | 巨象兽 | 85 | Evil Elephant | 数值锚点：Level 47=47 |
| 219 | 火焰沃玛 | 63 | Uma Flame Thrower | 数值锚点：Level 25=25 |
| 222 | 狼 | 14 | Wolf | 数值锚点：Level 15=15；HP 60=60 |
| 229 | 栗子树 | 16 | Chestnut Tree | 数值锚点：Level 10=10 |
| 277 | 诺玛斧兵 | 89 | Numa Grunt | 已审锚点 Numa Grunt（manifest medium） |
| 284 | 诺玛抛石兵 | 163 | Numa Stone Thrower | 已审锚点 Numa Stone Thrower（manifest high） |
| 287 | 诺玛突击队长 | 166 | Numa Assault Captain | 已审锚点 Numa Assault Captain（manifest high；与 286 同候选取此条） |
| 290 | 诺玛装甲兵 | 165 | Numa Armored Soldier | 已审锚点 Numa Armored Soldier（manifest high） |
| 299 | 潘夜牛魔王 | 113 | Flame Minotaur | 已审锚点 Flame Minotaur（manifest verified, 潘夜系） |
| 304 | 潘夜战士 | 186 | Banyo Warrior | 已审锚点 Banyo Warrior（manifest high） |
| 315 | 森林雪人 | 15 | Forest Yeti | 数值锚点：Level 13=13；HP 40=40 |
| 323 | 沙鬼 | 93 | Stone Golem | 数值锚点：Level 35=35 |
| 331 | 沙漠树魔 | 95 | Cursed Cactus | 数值锚点：Level 35=35 |
| 339 | 山洞蝙蝠 | 24 | Cave Bat | 数值锚点：Level 18=18；HP 90=90 |
| 350 | 石像狮子 | 484 | Stone Lion | 已审锚点 Stone Lion（manifest high） |
| 370 | 沃玛教主 | 65 | Uma King | 强制锚点 Uma King（README 不得违反） |
| 388 | 楔蛾 | 124 | Wedge Moth | 数值锚点：Level 30=30；已审锚点 Wedge Moth（manifest high；Level 30 同） |
| 391 | 蝎子 | 25 | Scorpion | 数值锚点：Level 18=18；HP 95=95 |
| 402 | 羊 | 12 | Sheep | 已审锚点 Sheep（manifest high；Zircon 另有 Lv0 宠物版 195） |
| 405 | 祖玛弓箭手 | 76 | Zuma Sharpshooter | 数值锚点：Level 45=45 |
| 408 | 牛 | 11 | Cow | 已审锚点 Cow（manifest high） |
| 420 | 冰宫射手 | 374 | Ice Palace Archer | 已审锚点 Ice Palace Archer（manifest high，名一一对应） |
| 421 | 冰城帝王 | 372 | Ice City Emperor | 已审锚点 Ice City Emperor（manifest high） |
| 422 | 冰宫巫师 | 375 | Ice Palace Wizard | 已审锚点 Ice Palace Wizard（manifest high） |
| 423 | 冰原勇士 | 485 | Ice Plain Warrior | 已审锚点 Ice Plain Warrior（manifest high） |
| 424 | 冰宫骑士 | 377 | Ice Palace Knight | 数值锚点：Level 80=80；已审锚点 Ice Palace Knight（manifest high） |
| 425 | 冰原狼王 | 369 | Ice Plain Wolf King | 已审锚点 Ice Plain Wolf King（manifest high） |
| 426 | 冰原雪狼 | 371 | Ice Plain Snow Wolf | 已审锚点 Ice Plain Snow Wolf（manifest high） |
| 427 | 冰原战士 | 486 | Ice Plain Soldier | 已审锚点 Ice Plain Soldier（manifest high） |
| 428 | 冰宫法师 | 376 | Ice Palace Mage | 已审锚点 Ice Palace Mage（manifest high） |
| 429 | 冰宫守卫 | 373 | Ice Palace Guard | 已审锚点 Ice Palace Guard（manifest high） |
| 430 | 冰原豪猪 | 370 | Ice Plain Boar | 已审锚点 Ice Plain Boar（manifest high） |
| 431 | 寒冰守护神 | 403 | Frost Guardian God | 已审锚点 Frost Guardian God（manifest high） |

## pending（候选/一对多，人工勾选；禁止当 closed）（86）

| Mud3 Index | Mud3 中文名 | Zircon Index | Zircon 身份 | 证据 |
|---|---|---:|---|---|
| 15 | 潘夜云魔 | 252 | Sama Wind Guardian | 资源图别名 SamaWindGuardian→Image 反查（仅候选）；候选 [252]（未定案，禁止据此写库）；当前列首位 Sama Wind Guardian(252) |
| 18 | 暗黑战士 | 62 | Uma Infidel | website alignment 候选（仅候选）；候选 [62]（未定案，禁止据此写库）；当前列首位 Uma Infidel(62) |
| 21 | 八脚首领 | 73 | Arachnid Broodmother | 蛛形首领（Arachnid Broodmother 73）；候选 [73, 67]（未定案，禁止据此写库）；当前列首位 Arachnid Broodmother(73) |
| 24 | 霸王守卫 | 147 | Infernal Soldier | 资源图别名 InfernalSoldier→Image 反查（仅候选）；候选 [147, 400, 416, 417]（未定案，禁止据此写库）；当前列首位 Infernal Soldier(147) |
| 27 | 白野猪 | 128 | Tusk Lord | 石墓 Boss 系（Tusk Lord 128，资源图候选；Wild Boar 176 备选）；候选 [128, 176]（未定案，禁止据此写库）；当前列首位 Tusk Lord(128) |
| 32 | 半兽勇士 | 23 | Oma Hero | website alignment 候选（仅候选）；候选 [23]（未定案，禁止据此写库）；当前列首位 Oma Hero(23) |
| 43 | 爆毒蚂蚁 | 40 | Ant Needler | 资源图别名 AntNeedler→Image 反查（仅候选）；候选 [40]（未定案，禁止据此写库）；当前列首位 Ant Needler(40) |
| 45 | 爆毒神魔 | 412 | Otherworld Poison Demon | website alignment 候选（仅候选）；候选 [412]（未定案，禁止据此写库）；当前列首位 Otherworld Poison Demon(412) |
| 48 | 变异骷髅 | 30 | Skeleton Lord | 骷髅系强化（Skeleton Lord 30）；候选 [30, 120]（未定案，禁止据此写库）；当前列首位 Skeleton Lord(30) |
| 49 | 不死雄狮 | 176 | Wild Boar | 狮子/野猪系，无唯一候选（Wild Boar 176）；候选 [176, 128]（未定案，禁止据此写库）；当前列首位 Wild Boar(176) |
| 52 | 赤黄猪王 | 394 | Fierce Black Boar | 资源图别名 BlackBoar→Image 反查（仅候选）；候选 [127, 394]（未定案，禁止据此写库）；当前列首位 Fierce Black Boar(394) |
| 53 | 赤血恶魔 | 70 | Red Moon Protector | 赤月系护卫（Red Moon Protector 70）；候选 [70, 69]（未定案，禁止据此写库）；当前列首位 Red Moon Protector(70) |
| 57 | 触龙神 | 183 | Millipede | 资源图别名 Centipede→Image 反查（仅候选）；候选 [51, 183, 381]（未定案，禁止据此写库）；当前列首位 Millipede(183) |
| 58 | 雌诺玛 | 91 | Numa Elite | 诺玛系（Numa Elite 91）；候选 [91, 90]（未定案，禁止据此写库）；当前列首位 Numa Elite(91) |
| 64 | 单腿诺玛 | 90 | Numa Mage | 诺玛系（Numa Elite 91）；候选 [91, 90]（未定案，禁止据此写库）；当前列首位 Numa Mage(90) |
| 78 | 独眼蜘蛛 | 66 | Spider Bat | 资源图别名 SpiderBat→Image 反查（仅候选）；候选 [66]（未定案，禁止据此写库）；当前列首位 Spider Bat(66) |
| 82 | 多角虫 | 44 | Corpse Devourer | 资源图别名 ShellNipper→Image 反查（仅候选）；候选 [44]（未定案，禁止据此写库）；当前列首位 Corpse Devourer(44) |
| 88 | 恶形鬼 | 105 | Death Lord Jichon | 鬼系 Boss（Death Lord Jichon 105，仅猜测）；候选 [105]（未定案，禁止据此写库）；当前列首位 Death Lord Jichon(105) |
| 89 | 粪虫 | 61 | Spined Dark Lizard | website alignment 候选（仅候选）；候选 [61]（未定案，禁止据此写库）；当前列首位 Spined Dark Lizard(61) |
| 90 | 疯狂魔神盗 | 245 | Sama Cursed Bladesman | 萨玛系刀客（Sama Cursed Bladesman 245）；候选 [245, 246]（未定案，禁止据此写库）；当前列首位 Sama Cursed Bladesman(245) |
| 91 | 腐蚀人鬼 | 185 | Banyo Soldier | 资源图别名 RottingGhoul→Image 反查（仅候选）；候选 [57, 185]（未定案，禁止据此写库）；当前列首位 Banyo Soldier(185) |
| 98 | 海神将领 | 409 | Otherworld Sea General | website alignment 候选（仅候选）；候选 [409]（未定案，禁止据此写库）；当前列首位 Otherworld Sea General(409) |
| 100 | 黑角蜘蛛 | 72 | Dark Arachnid | 资源图别名 DarkArachnid→Image 反查（仅候选）；候选 [72, 73]（未定案，禁止据此写库）；当前列首位 Dark Arachnid(72) |
| 103 | 黑色恶蛆 | 53 | Mutant Maggot | 资源图别名 MutantMaggot→Image 反查（仅候选）；候选 [53]（未定案，禁止据此写库）；当前列首位 Mutant Maggot(53) |
| 113 | 红衣法师 | 418 | Otherworld Red Mage | website alignment 候选（仅候选）；候选 [418]（未定案，禁止据此写库）；当前列首位 Otherworld Red Mage(418) |
| 114 | 蝴蝶虫 | 52 | Butterfly Worm | 资源图别名 ButterflyWorm→Image 反查（仅候选）；候选 [52]（未定案，禁止据此写库）；当前列首位 Butterfly Worm(52) |
| 119 | 护法天 | 80 | Zuma Keeper | website alignment 候选（仅候选）；候选 [78, 80]（未定案，禁止据此写库）；当前列首位 Zuma Keeper(80) |
| 121 | 花色蜘蛛 | 302 | Gang Spider | 资源图别名 GangSpider→Image 反查（仅候选）；候选 [302]（未定案，禁止据此写库）；当前列首位 Gang Spider(302) |
| 124 | 灰血恶魔 | 69 | Red Moon Guardian | 赤月系守卫（Red Moon Guardian 69）；候选 [69, 70]（未定案，禁止据此写库）；当前列首位 Red Moon Guardian(69) |
| 149 | 僵尸王 | 60 | Blood Thristy Zombie | 僵尸王（Blood Thirsty Zombie 60）；候选 [60, 57]（未定案，禁止据此写库）；当前列首位 Blood Thristy Zombie(60) |
| 163 | 骷髅弓箭手 | 116 | Bone Archer | 骷髅弓手（Bone Archer 116）；候选 [116, 28]（未定案，禁止据此写库）；当前列首位 Bone Archer(116) |
| 166 | 骷髅精灵 | 120 | Skeleton Enforcer | 骷髅系（Skeleton Lord 30）；候选 [30, 120]（未定案，禁止据此写库）；当前列首位 Skeleton Enforcer(120) |
| 170 | 骷髅士兵 | 119 | Bone Soldier | 骷髅系（Bone Soldier 119）；候选 [119, 117]（未定案，禁止据此写库）；当前列首位 Bone Soldier(119) |
| 174 | 骷髅武士 | 117 | Bone Bladesman | 骷髅系（Bone Bladesman 117）；候选 [117, 119]（未定案，禁止据此写库）；当前列首位 Bone Bladesman(117) |
| 185 | 盔甲蚂蚁 | 41 | Armoured Ant | 资源图别名 ArmoredAnt→Image 反查（仅候选）；候选 [41, 42]（未定案，禁止据此写库）；当前列首位 Armoured Ant(41) |
| 187 | 异界之门 | 96 | Netherworld Gate | 异界之门 = Netherworld Gate(96)，仅名称证据；候选 [96]（未定案，禁止据此写库）；当前列首位 Netherworld Gate(96) |
| 188 | 猿猴战将 | 274 | Wild Monkey | 资源图别名 WildMonkey→Image 反查（仅候选）；候选 [274]（未定案，禁止据此写库）；当前列首位 Wild Monkey(274) |
| 192 | 月魔蜘蛛 | 71 | Venomous Arachnid | 资源图别名 VenomousArachnid→Image 反查（仅候选）；候选 [71]（未定案，禁止据此写库）；当前列首位 Venomous Arachnid(71) |
| 193 | 震天魔神 | 139 | Jinchon Warlord | 真天系（Jinchon Warlord 139）；候选 [139, 199]（未定案，禁止据此写库）；当前列首位 Jinchon Warlord(139) |
| 194 | 震天神兵 | 199 | Jinchon Devil | 真天系（Jinchon Devil 199）；候选 [199, 139]（未定案，禁止据此写库）；当前列首位 Jinchon Devil(199) |
| 203 | 祖玛雕像 | 77 | Zuma Fanatic | website alignment 候选（仅候选）；候选 [77]（未定案，禁止据此写库）；当前列首位 Zuma Fanatic(77) |
| 223 | 浪子人鬼 | 221 | Oyoung Beast | 资源图别名 OYoungBeast→Image 反查（仅候选）；候选 [221, 223, 362]（未定案，禁止据此写库）；当前列首位 Oyoung Beast(221) |
| 225 | 劳动蚂蚁 | 38 | Ant Soldier | 资源图别名 AntSoldier→Image 反查（仅候选）；候选 [38]（未定案，禁止据此写库）；当前列首位 Ant Soldier(38) |
| 228 | 雷电僵尸 | 58 | Decaying Ghoul | 僵尸系（Decaying Ghoul 58）；候选 [58, 57]（未定案，禁止据此写库）；当前列首位 Decaying Ghoul(58) |
| 234 | 鹿 | 10 | Deer | website alignment 候选（仅候选）；候选 [10]（未定案，禁止据此写库）；当前列首位 Deer(10) |
| 235 | 蚂蚁道士 | 39 | Ant Healer | 资源图别名 AntHealer→Image 反查（仅候选）；候选 [39, 470]（未定案，禁止据此写库）；当前列首位 Ant Healer(39) |
| 237 | 蚂蚁将军 | 42 | Ant Commander | 资源图别名 ArmoredAnt→Image 反查（仅候选）；候选 [41, 42]（未定案，禁止据此写库）；当前列首位 Ant Commander(42) |
| 240 | 魔神怪1 | 248 | Sama Cursed Slave | 资源图别名 SamaCursedSlave→Image 反查（仅候选）；候选 [248]（未定案，禁止据此写库）；当前列首位 Sama Cursed Slave(248) |
| 247 | 牛老道 | 57 | Rotting Ghoul | 僵尸系（Rotting Ghoul 57）；候选 [57, 58]（未定案，禁止据此写库）；当前列首位 Rotting Ghoul(57) |
| 249 | 怒龙神 | 385 | Fierce Poison Dragon | 资源图别名 TigerSnake→Image 反查（仅候选）；候选 [19, 385]（未定案，禁止据此写库）；当前列首位 Fierce Poison Dragon(385) |
| 282 | 诺玛教主 | 98 | Numa Elder Shaman | 诺玛系首领（Numa Elder Shaman 98）；候选 [98, 166]（未定案，禁止据此写库）；当前列首位 Numa Elder Shaman(98) |
| 285 | 诺玛骑兵 | 161 | Numa Cavalry | 诺玛骑兵 = Numa Cavalry(161)；候选 [161, 165]（未定案，禁止据此写库）；当前列首位 Numa Cavalry(161) |
| 286 | 诺玛司令 | 164 | Numa Royal Guard | 诺玛系（Numa Royal Guard 164；166 已被突击队长占用）；候选 [164, 166]（未定案，禁止据此写库）；当前列首位 Numa Royal Guard(164) |
| 292 | 潘夜冰魔 | 458 | Ice Break Demon Soldier | 资源图别名 IceMob→Image 反查（仅候选）；候选 [458]（未定案，禁止据此写库）；当前列首位 Ice Break Demon Soldier(458) |
| 294 | 潘夜风魔 | 390 | Fierce Wind Demon | 资源图别名 FierceWindDemon→Image 反查（仅候选）；候选 [390]（未定案，禁止据此写库）；当前列首位 Fierce Wind Demon(390) |
| 296 | 潘夜鬼将 | 160 | Pachon The Chaos bringer | 资源图别名 PachonTheChaosBringer→Image 反查（仅候选）；候选 [160, 188]（未定案，禁止据此写库）；当前列首位 Pachon The Chaos bringer(160) |
| 297 | 潘夜火魔 | 449 | Flame Demon Soldier | 资源图别名 FlameMob→Image 反查（仅候选）；候选 [449]（未定案，禁止据此写库）；当前列首位 Flame Demon Soldier(449) |
| 300 | 潘夜右护卫 | 445 | Force God General 1 | 资源图别名 LightArmedSoldier→Image 反查（仅候选）；候选 [152, 186, 445, 446]（未定案，禁止据此写库）；当前列首位 Force God General 1(445) |
| 306 | 潘夜左护卫 | 446 | Force God General 2 | 资源图别名 LightArmedSoldier→Image 反查（仅候选）；候选 [152, 186, 445, 446]（未定案，禁止据此写库）；当前列首位 Force God General 2(446) |
| 311 | 钳虫 | 88 | Spiked Beetle | 资源图别名 SpikedBeetle→Image 反查（仅候选）；候选 [88, 179]（未定案，禁止据此写库）；当前列首位 Spiked Beetle(88) |
| 313 | 轻甲守卫 | 425 | Otherworld Light Guard | website alignment 候选（仅候选）；候选 [425]（未定案，禁止据此写库）；当前列首位 Otherworld Light Guard(425) |
| 314 | 犬猴魔 | 223 | Ma Warden | 资源图别名 OYoungBeast→Image 反查（仅候选）；候选 [221, 223, 362]（未定案，禁止据此写库）；当前列首位 Ma Warden(223) |
| 327 | 沙漠风魔 | 292 | Dust Devil | 资源图别名 DustDevil→Image 反查（仅候选）；候选 [292]（未定案，禁止据此写库）；当前列首位 Dust Devil(292) |
| 329 | 沙漠石人 | 291 | Crystal Golem | 资源图别名 CrystalGolem→Image 反查（仅候选）；候选 [291]（未定案，禁止据此写库）；当前列首位 Crystal Golem(291) |
| 334 | 沙漠威思而小虫 | 47 | Poisonous Mutant Flea | 小虫系（Poisonous Mutant Flea 47）；候选 [47, 46]（未定案，禁止据此写库）；当前列首位 Poisonous Mutant Flea(47) |
| 335 | 沙漠蜥蜴 | 379 | Ice Soul General | 资源图别名 GiantLizard→Image 反查（仅候选）；候选 [102, 379, 485]（未定案，禁止据此写库）；当前列首位 Ice Soul General(379) |
| 337 | 沙漠鱼魔 | 393 | Fierce Fish Demon | 资源图别名 ZumaGuardian→Image 反查（仅候选）；候选 [78, 80, 393]（未定案，禁止据此写库）；当前列首位 Fierce Fish Demon(393) |
| 338 | 沙漠战士 | 152 | Light Armed Soldier | 沙漠/神舰系（Light Armed Soldier 152）；候选 [152, 147]（未定案，禁止据此写库）；当前列首位 Light Armed Soldier(152) |
| 343 | 神舰守卫 | 416 | Otherworld Ship Guard | website alignment 候选（仅候选）；候选 [416]（未定案，禁止据此写库）；当前列首位 Otherworld Ship Guard(416) |
| 344 | 神兽 | 146 | Shinsu | 召唤兽（Shinsu 146）；候选 [146, 140]（未定案，禁止据此写库）；当前列首位 Shinsu(146) |
| 347 | 尸王 | 56 | Lord Ji'Nae | website alignment 候选（仅候选）；候选 [56, 59, 105]（未定案，禁止据此写库）；当前列首位 Lord Ji'Nae(56) |
| 355 | 天狼蜘蛛 | 303 | Venom Spider | 资源图别名 VenomSpider→Image 反查（仅候选）；候选 [303]（未定案，禁止据此写库）；当前列首位 Venom Spider(303) |
| 357 | 跳跳蜂 | 50 | Wasp Hatchling | 资源图别名 WaspHatchling→Image 反查（仅候选）；候选 [50]（未定案，禁止据此写库）；当前列首位 Wasp Hatchling(50) |
| 362 | 陀大怪 | 231 | Dragon Queen Jin'Ru | 龙渊系（Dragon Queen 231，仅猜测）；候选 [231, 232]（未定案，禁止据此写库）；当前列首位 Dragon Queen Jin'Ru(231) |
| 363 | 威思而小虫 | 46 | Mutant Flea | website alignment 候选（仅候选）；候选 [46]（未定案，禁止据此写库）；当前列首位 Mutant Flea(46) |
| 364 | 卫士 | 1 | Guard | 城镇守卫；Zircon 仅 Guard(1) 一条，体系已重做；候选 [1, 364]（未定案，禁止据此写库）；当前列首位 Guard(1) |
| 368 | 沃玛护卫 | 64 | Uma Anguisher | 沃玛系（Uma Anguisher 64）；候选 [64, 62]（未定案，禁止据此写库）；当前列首位 Uma Anguisher(64) |
| 383 | 蜈蚣 | 51 | Centipede | 蜈蚣 = Centipede(51)，仅名称证据；候选 [51, 183]（未定案，禁止据此写库）；当前列首位 Centipede(51) |
| 394 | 邪恶钳虫 | 179 | Bloody Armed Beetle | 资源图别名 SpikedBeetle→Image 反查（仅候选）；候选 [88, 179]（未定案，禁止据此写库）；当前列首位 Bloody Armed Beetle(179) |
| 398 | 雪人 | 276 | Frost Yeti | 雪人 = Frost Yeti(276)；候选 [276, 15]（未定案，禁止据此写库）；当前列首位 Frost Yeti(276) |
| 414 | 变异刺骨蜥 | 97 | Raging Lizard | 变异蜥蜴系（Raging Lizard 97）；候选 [97, 106]（未定案，禁止据此写库）；当前列首位 Raging Lizard(97) |
| 415 | 变异毒蜥 | 101 | Sonic Lizard | 变异蜥蜴系（Sonic Lizard 101）；候选 [101, 100]（未定案，禁止据此写库）；当前列首位 Sonic Lizard(101) |
| 416 | 变异丑蜥 | 106 | Mutant Lizard | 变异蜥蜴系（Mutant Lizard 106）；候选 [106, 99]（未定案，禁止据此写库）；当前列首位 Mutant Lizard(106) |
| 417 | 变异利爪蜥 | 99 | Saw Tooth Lizard | 变异蜥蜴系（Saw Tooth Lizard 99）；候选 [99, 106]（未定案，禁止据此写库）；当前列首位 Saw Tooth Lizard(99) |
| 418 | 变异迅猛蜥 | 102 | Giant Lizard | 变异蜥蜴系（Giant/Crazed Lizard）；候选 [102, 103]（未定案，禁止据此写库）；当前列首位 Giant Lizard(102) |
| 419 | 地天灭王 | 232 | Dragon Lord Jin'Ryung | 龙渊系 Boss（Dragon Queen/Lord）；候选 [231, 232]（未定案，禁止据此写库）；当前列首位 Dragon Lord Jin'Ryung(232) |

## missing（Mud3 有、Zircon 无 / 变体记录）（283）

| Mud3 Index | Mud3 中文名 | Zircon Index | Zircon 身份 | 证据 |
|---|---|---:|---|---|
| 0 | — | — | — | 头部占位记录（raw 首 u32=433 明文，非怪物；无身份） |
| 1 | 守卫武将 | — | — | Zircon 城镇守卫体系重做，无直接对应（manifest 已审 old-only） |
| 2 | 守卫狮子 | — | — | Zircon 城镇守卫体系重做，无直接对应 |
| 3 | 守卫血魔 | — | — | Zircon 城镇守卫体系重做，无直接对应 |
| 4 | 守卫沃玛 | — | — | Zircon 城镇守卫体系重做，无直接对应 |
| 5 | 守卫右狮 | — | — | Zircon 城镇守卫体系重做，无直接对应 |
| 6 | 署箭 | — | — | 任务/守卫类，Zircon 无对应身份 |
| 7 | 沃玛战将61 | — | — | 变体记录（后缀）；基础物种「沃玛战将」在本表中未闭合；Zircon 无独立变体条目，按 handoff 不建新怪 |
| 10 | 血巨人 | — | — | 候选 [69, 70] 均已被其它条目占用，Zircon 无独立条目可分配；按一对多处理但无空闲候选 → missing（需人工决定合并或新增） |
| 11 | 祖玛雕像0 | — | — | 变体记录（后缀）；基础物种「祖玛雕像」在本表中未闭合；Zircon 无独立变体条目，按 handoff 不建新怪 |
| 14 | 七点白蛇 | — | — | RedSnake 仅有资源图，无 MonsterInfo 身份行 |
| 16 | 石像狮子98 | — | — | 变体记录（后缀）；基础物种「石像狮子」已闭合到 Zircon Index 484；Zircon 无独立变体条目，按 handoff 不建新怪 |
| 19 | 暗黑战士0 | — | — | 变体记录（后缀）；基础物种「暗黑战士」在本表中未闭合；Zircon 无独立变体条目，按 handoff 不建新怪 |
| 20 | 暗黑战士40 | — | — | 变体记录（后缀）；基础物种「暗黑战士」在本表中未闭合；Zircon 无独立变体条目，按 handoff 不建新怪 |
| 22 | 霸群雕像 | — | — | 雕像物件，非怪物身份 |
| 25 | 霸王守卫9 | — | — | 变体记录（后缀）；基础物种「霸王守卫」在本表中未闭合；Zircon 无独立变体条目，按 handoff 不建新怪 |
| 26 | 白马 | — | — | 坐骑在 Zircon 是物品，无怪物身份 |
| 29 | 半兽人0 | — | — | 变体记录（后缀）；基础物种「半兽人」已闭合到 Zircon Index 22；Zircon 无独立变体条目，按 handoff 不建新怪 |
| 30 | 半兽人61 | — | — | 变体记录（后缀）；基础物种「半兽人」已闭合到 Zircon Index 22；Zircon 无独立变体条目，按 handoff 不建新怪 |
| 31 | 半兽人9 | — | — | 变体记录（后缀）；基础物种「半兽人」已闭合到 Zircon Index 22；Zircon 无独立变体条目，按 handoff 不建新怪 |
| 33 | 半兽勇士61 | — | — | 变体记录（后缀）；基础物种「半兽勇士」在本表中未闭合；Zircon 无独立变体条目，按 handoff 不建新怪 |
| 34 | 半兽勇士9 | — | — | 变体记录（后缀）；基础物种「半兽勇士」在本表中未闭合；Zircon 无独立变体条目，按 handoff 不建新怪 |
| 36 | 半兽战士0 | — | — | 变体记录（后缀）；基础物种「半兽战士」已闭合到 Zircon Index 18；Zircon 无独立变体条目，按 handoff 不建新怪 |
| 37 | 半兽战士61 | — | — | 变体记录（后缀）；基础物种「半兽战士」已闭合到 Zircon Index 18；Zircon 无独立变体条目，按 handoff 不建新怪 |
| 38 | 半兽战士9 | — | — | 变体记录（后缀）；基础物种「半兽战士」已闭合到 Zircon Index 18；Zircon 无独立变体条目，按 handoff 不建新怪 |
| 39 | 胞眼虫1 | — | — | 变体记录（后缀）；基础物种「胞眼虫」在本表中未闭合；Zircon 无独立变体条目，按 handoff 不建新怪 |
| 40 | 胞眼虫10 | — | — | 变体记录（后缀）；基础物种「胞眼虫」在本表中未闭合；Zircon 无独立变体条目，按 handoff 不建新怪 |
| 41 | 胞眼虫2 | — | — | 变体记录（后缀）；基础物种「胞眼虫」在本表中未闭合；Zircon 无独立变体条目，按 handoff 不建新怪 |
| 42 | 胞眼虫20 | — | — | 变体记录（后缀）；基础物种「胞眼虫」在本表中未闭合；Zircon 无独立变体条目，按 handoff 不建新怪 |
| 44 | 爆毒蚂蚁0 | — | — | 变体记录（后缀）；基础物种「爆毒蚂蚁」在本表中未闭合；Zircon 无独立变体条目，按 handoff 不建新怪 |
| 46 | 爆裂蜘蛛 | — | — | 候选 [20] 均已被其它条目占用，Zircon 无独立条目可分配；按一对多处理但无空闲候选 → missing（需人工决定合并或新增） |
| 47 | 蝙蝠 | — | — | Mud3 独有 / 无 Zircon 对应身份 |
| 50 | 柴三郎 | — | — | NPC/任务，Zircon 无对应身份 |
| 51 | 超级圣诞树 | — | — | 节日活动怪，Zircon 无对应身份 |
| 54 | 赤血恶魔0 | — | — | 变体记录（后缀）；基础物种「赤血恶魔」在本表中为 pending 或有说明；Zircon 无独立变体条目，按 handoff 不建新怪 |
| 55 | 赤血恶魔50 | — | — | 变体记录（后缀）；基础物种「赤血恶魔」在本表中为 pending 或有说明；Zircon 无独立变体条目，按 handoff 不建新怪 |
| 59 | 丛林战士1 | — | — | 变体记录（后缀）；基础物种「丛林战士」在本表中未闭合；Zircon 无独立变体条目，按 handoff 不建新怪 |
| 60 | 丛林战士2 | — | — | 变体记录（后缀）；基础物种「丛林战士」在本表中未闭合；Zircon 无独立变体条目，按 handoff 不建新怪 |
| 63 | 大老鼠0 | — | — | 变体记录（后缀）；基础物种「大老鼠」已闭合到 Zircon Index 79；Zircon 无独立变体条目，按 handoff 不建新怪 |
| 66 | 稻草人0 | — | — | 变体记录（后缀）；基础物种「稻草人」已闭合到 Zircon Index 21；Zircon 无独立变体条目，按 handoff 不建新怪 |
| 68 | 地牢女神10 | — | — | 变体记录（后缀）；基础物种「地牢女神」在本表中未闭合；Zircon 无独立变体条目，按 handoff 不建新怪 |
| 70 | 地牢女神20 | — | — | 变体记录（后缀）；基础物种「地牢女神」在本表中未闭合；Zircon 无独立变体条目，按 handoff 不建新怪 |
| 71 | 钉耙猫 | — | — | RakingCat 仅有资源图，无 MonsterInfo 身份行 |
| 72 | 钉耙猫0 | — | — | 变体记录（后缀）；基础物种「钉耙猫」在本表中为 pending 或有说明；Zircon 无独立变体条目，按 handoff 不建新怪 |
| 74 | 洞蛆61 | — | — | 变体记录（后缀）；基础物种「洞蛆」已闭合到 Zircon Index 31；Zircon 无独立变体条目，按 handoff 不建新怪 |
| 76 | 毒蜘蛛61 | — | — | 变体记录（后缀）；基础物种「毒蜘蛛」已闭合到 Zircon Index 20；Zircon 无独立变体条目，按 handoff 不建新怪 |
| 77 | 独臂诺玛 | — | — | 候选 [91, 90] 均已被其它条目占用，Zircon 无独立条目可分配；按一对多处理但无空闲候选 → missing（需人工决定合并或新增） |
| 79 | 独眼蜘蛛0 | — | — | 变体记录（后缀）；基础物种「独眼蜘蛛」在本表中未闭合；Zircon 无独立变体条目，按 handoff 不建新怪 |
| 81 | 多钩猫0 | — | — | 变体记录（后缀）；基础物种「多钩猫」已闭合到 Zircon Index 13；Zircon 无独立变体条目，按 handoff 不建新怪 |
| 83 | 多角虫0 | — | — | 变体记录（后缀）；基础物种「多角虫」在本表中未闭合；Zircon 无独立变体条目，按 handoff 不建新怪 |
| 84 | 多脚虫1 | — | — | 变体记录（后缀）；基础物种「多脚虫」在本表中未闭合；Zircon 无独立变体条目，按 handoff 不建新怪 |
| 85 | 多脚虫10 | — | — | 变体记录（后缀）；基础物种「多脚虫」在本表中未闭合；Zircon 无独立变体条目，按 handoff 不建新怪 |
| 86 | 多脚虫2 | — | — | 变体记录（后缀）；基础物种「多脚虫」在本表中未闭合；Zircon 无独立变体条目，按 handoff 不建新怪 |
| 87 | 多脚虫20 | — | — | 变体记录（后缀）；基础物种「多脚虫」在本表中未闭合；Zircon 无独立变体条目，按 handoff 不建新怪 |
| 92 | 腐蚀人鬼0 | — | — | 变体记录（后缀）；基础物种「腐蚀人鬼」在本表中未闭合；Zircon 无独立变体条目，按 handoff 不建新怪 |
| 93 | 蛤蟆 | — | — | Zircon 无青蛙类身份行 |
| 94 | 蛤蟆0 | — | — | 变体记录（后缀）；基础物种「蛤蟆」在本表中为 pending 或有说明；Zircon 无独立变体条目，按 handoff 不建新怪 |
| 95 | 弓箭手 | — | — | 泛用弓手，Mud3 独有（Zircon 用 Bone/Goru Archer） |
| 96 | 弓箭守卫 | — | — | 泛用弓卫，Mud3 独有 |
| 99 | 褐色马 | — | — | 坐骑在 Zircon 是物品，无怪物身份 |
| 101 | 黑角蜘蛛0 | — | — | 变体记录（后缀）；基础物种「黑角蜘蛛」在本表中未闭合；Zircon 无独立变体条目，按 handoff 不建新怪 |
| 102 | 黑马 | — | — | 坐骑在 Zircon 是物品，无怪物身份 |
| 104 | 黑色恶蛆0 | — | — | 变体记录（后缀）；基础物种「黑色恶蛆」在本表中未闭合；Zircon 无独立变体条目，按 handoff 不建新怪 |
| 105 | 黑色恶蛆61 | — | — | 变体记录（后缀）；基础物种「黑色恶蛆」在本表中未闭合；Zircon 无独立变体条目，按 handoff 不建新怪 |
| 107 | 黑野猪0 | — | — | 变体记录（后缀）；基础物种「黑野猪」已闭合到 Zircon Index 127；Zircon 无独立变体条目，按 handoff 不建新怪 |
| 108 | 红甲虫 | — | — | 候选 [72, 73] 均已被其它条目占用，Zircon 无独立条目可分配；按一对多处理但无空闲候选 → missing（需人工决定合并或新增） |
| 109 | 红蛇 | — | — | RedSnake/TigerSnake 均已被占用或仅资源图 |
| 110 | 红蛇0 | — | — | 变体记录（后缀）；基础物种「红蛇」在本表中为 pending 或有说明；Zircon 无独立变体条目，按 handoff 不建新怪 |
| 112 | 红野猪0 | — | — | 变体记录（后缀）；基础物种「红野猪」已闭合到 Zircon Index 125；Zircon 无独立变体条目，按 handoff 不建新怪 |
| 115 | 蝴蝶虫0 | — | — | 变体记录（后缀）；基础物种「蝴蝶虫」在本表中未闭合；Zircon 无独立变体条目，按 handoff 不建新怪 |
| 116 | 蝴蝶虫61 | — | — | 变体记录（后缀）；基础物种「蝴蝶虫」在本表中未闭合；Zircon 无独立变体条目，按 handoff 不建新怪 |
| 118 | 虎蛇0 | — | — | 变体记录（后缀）；基础物种「虎蛇」已闭合到 Zircon Index 19；Zircon 无独立变体条目，按 handoff 不建新怪 |
| 120 | 护卫武士 | — | — | 守卫类，Zircon 无对应身份 |
| 122 | 花色蜘蛛0 | — | — | 变体记录（后缀）；基础物种「花色蜘蛛」在本表中未闭合；Zircon 无独立变体条目，按 handoff 不建新怪 |
| 123 | 幻影蜘蛛 | — | — | Mud3 独有 / 无 Zircon 对应身份 |
| 125 | 灰血恶魔0 | — | — | 变体记录（后缀）；基础物种「灰血恶魔」在本表中为 pending 或有说明；Zircon 无独立变体条目，按 handoff 不建新怪 |
| 126 | 灰血恶魔60 | — | — | 变体记录（后缀）；基础物种「灰血恶魔」在本表中为 pending 或有说明；Zircon 无独立变体条目，按 handoff 不建新怪 |
| 127 | 火焰狮子0 | — | — | 变体记录（后缀）；基础物种「火焰狮子」已闭合到 Zircon Index 448；Zircon 无独立变体条目，按 handoff 不建新怪 |
| 128 | 火焰狮子97 | — | — | 变体记录（后缀）；基础物种「火焰狮子」已闭合到 Zircon Index 448；Zircon 无独立变体条目，按 handoff 不建新怪 |
| 129 | 火焰沃玛0 | — | — | 变体记录（后缀）；基础物种「火焰沃玛」已闭合到 Zircon Index 63；Zircon 无独立变体条目，按 handoff 不建新怪 |
| 130 | 火焰沃玛30 | — | — | 变体记录（后缀）；基础物种「火焰沃玛」已闭合到 Zircon Index 63；Zircon 无独立变体条目，按 handoff 不建新怪 |
| 131 | 火焰沃玛62 | — | — | 变体记录（后缀）；基础物种「火焰沃玛」已闭合到 Zircon Index 63；Zircon 无独立变体条目，按 handoff 不建新怪 |
| 133 | 记事本1 | — | — | 变体记录（后缀）；基础物种「记事本」在本表中未闭合；Zircon 无独立变体条目，按 handoff 不建新怪 |
| 134 | 记事本2 | — | — | 变体记录（后缀）；基础物种「记事本」在本表中未闭合；Zircon 无独立变体条目，按 handoff 不建新怪 |
| 135 | 记事本3 | — | — | 变体记录（后缀）；基础物种「记事本」在本表中未闭合；Zircon 无独立变体条目，按 handoff 不建新怪 |
| 136 | 记事本4 | — | — | 变体记录（后缀）；基础物种「记事本」在本表中未闭合；Zircon 无独立变体条目，按 handoff 不建新怪 |
| 137 | 僵尸1 | — | — | 变体记录（后缀）；基础物种「僵尸」在本表中未闭合；Zircon 无独立变体条目，按 handoff 不建新怪 |
| 138 | 僵尸10 | — | — | 变体记录（后缀）；基础物种「僵尸」在本表中未闭合；Zircon 无独立变体条目，按 handoff 不建新怪 |
| 139 | 僵尸2 | — | — | 变体记录（后缀）；基础物种「僵尸」在本表中未闭合；Zircon 无独立变体条目，按 handoff 不建新怪 |
| 140 | 僵尸20 | — | — | 变体记录（后缀）；基础物种「僵尸」在本表中未闭合；Zircon 无独立变体条目，按 handoff 不建新怪 |
| 141 | 僵尸261 | — | — | 变体记录（后缀）；基础物种「僵尸」在本表中未闭合；Zircon 无独立变体条目，按 handoff 不建新怪 |
| 142 | 僵尸3 | — | — | 变体记录（后缀）；基础物种「僵尸」在本表中未闭合；Zircon 无独立变体条目，按 handoff 不建新怪 |
| 143 | 僵尸30 | — | — | 变体记录（后缀）；基础物种「僵尸」在本表中未闭合；Zircon 无独立变体条目，按 handoff 不建新怪 |
| 144 | 僵尸4 | — | — | 变体记录（后缀）；基础物种「僵尸」在本表中未闭合；Zircon 无独立变体条目，按 handoff 不建新怪 |
| 145 | 僵尸40 | — | — | 变体记录（后缀）；基础物种「僵尸」在本表中未闭合；Zircon 无独立变体条目，按 handoff 不建新怪 |
| 146 | 僵尸461 | — | — | 变体记录（后缀）；基础物种「僵尸」在本表中未闭合；Zircon 无独立变体条目，按 handoff 不建新怪 |
| 147 | 僵尸5 | — | — | 变体记录（后缀）；基础物种「僵尸」在本表中未闭合；Zircon 无独立变体条目，按 handoff 不建新怪 |
| 148 | 僵尸50 | — | — | 变体记录（后缀）；基础物种「僵尸」在本表中未闭合；Zircon 无独立变体条目，按 handoff 不建新怪 |
| 151 | 角蝇80 | — | — | 变体记录（后缀）；基础物种「角蝇」已闭合到 Zircon Index 472；Zircon 无独立变体条目，按 handoff 不建新怪 |
| 152 | 巨象兽0 | — | — | 变体记录（后缀）；基础物种「巨象兽」已闭合到 Zircon Index 85；Zircon 无独立变体条目，按 handoff 不建新怪 |
| 153 | 巨型多角虫 | — | — | 候选 [44] 均已被其它条目占用，Zircon 无独立条目可分配；按一对多处理但无空闲候选 → missing（需人工决定合并或新增） |
| 154 | 聚宝箱1 | — | — | 变体记录（后缀）；基础物种「聚宝箱」在本表中未闭合；Zircon 无独立变体条目，按 handoff 不建新怪 |
| 155 | 聚宝箱2 | — | — | 变体记录（后缀）；基础物种「聚宝箱」在本表中未闭合；Zircon 无独立变体条目，按 handoff 不建新怪 |
| 156 | 聚宝箱3 | — | — | 变体记录（后缀）；基础物种「聚宝箱」在本表中未闭合；Zircon 无独立变体条目，按 handoff 不建新怪 |
| 157 | 聚宝箱4 | — | — | 变体记录（后缀）；基础物种「聚宝箱」在本表中未闭合；Zircon 无独立变体条目，按 handoff 不建新怪 |
| 158 | 聚宝箱5 | — | — | 变体记录（后缀）；基础物种「聚宝箱」在本表中未闭合；Zircon 无独立变体条目，按 handoff 不建新怪 |
| 160 | 骷髅0 | — | — | 变体记录（后缀）；基础物种「骷髅」已闭合到 Zircon Index 27；Zircon 无独立变体条目，按 handoff 不建新怪 |
| 161 | 骷髅61 | — | — | 变体记录（后缀）；基础物种「骷髅」已闭合到 Zircon Index 27；Zircon 无独立变体条目，按 handoff 不建新怪 |
| 162 | 骷髅9 | — | — | 变体记录（后缀）；基础物种「骷髅」已闭合到 Zircon Index 27；Zircon 无独立变体条目，按 handoff 不建新怪 |
| 164 | 骷髅弓箭手0 | — | — | 变体记录（后缀）；基础物种「骷髅弓箭手」在本表中为 pending 或有说明；Zircon 无独立变体条目，按 handoff 不建新怪 |
| 167 | 骷髅精灵61 | — | — | 变体记录（后缀）；基础物种「骷髅精灵」在本表中为 pending 或有说明；Zircon 无独立变体条目，按 handoff 不建新怪 |
| 168 | 骷髅精灵62 | — | — | 变体记录（后缀）；基础物种「骷髅精灵」在本表中为 pending 或有说明；Zircon 无独立变体条目，按 handoff 不建新怪 |
| 169 | 骷髅精灵9 | — | — | 变体记录（后缀）；基础物种「骷髅精灵」在本表中为 pending 或有说明；Zircon 无独立变体条目，按 handoff 不建新怪 |
| 171 | 骷髅士兵0 | — | — | 变体记录（后缀）；基础物种「骷髅士兵」在本表中为 pending 或有说明；Zircon 无独立变体条目，按 handoff 不建新怪 |
| 172 | 骷髅武将 | — | — | 候选 [120, 30] 均已被其它条目占用，Zircon 无独立条目可分配；按一对多处理但无空闲候选 → missing（需人工决定合并或新增） |
| 173 | 骷髅武将0 | — | — | 变体记录（后缀）；基础物种「骷髅武将」在本表中为 pending 或有说明；Zircon 无独立变体条目，按 handoff 不建新怪 |
| 175 | 骷髅武士0 | — | — | 变体记录（后缀）；基础物种「骷髅武士」在本表中为 pending 或有说明；Zircon 无独立变体条目，按 handoff 不建新怪 |
| 177 | 骷髅战将0 | — | — | 变体记录（后缀）；基础物种「骷髅战将」已闭合到 Zircon Index 26；Zircon 无独立变体条目，按 handoff 不建新怪 |
| 178 | 骷髅战将61 | — | — | 变体记录（后缀）；基础物种「骷髅战将」已闭合到 Zircon Index 26；Zircon 无独立变体条目，按 handoff 不建新怪 |
| 179 | 骷髅战将9 | — | — | 变体记录（后缀）；基础物种「骷髅战将」已闭合到 Zircon Index 26；Zircon 无独立变体条目，按 handoff 不建新怪 |
| 181 | 骷髅战士0 | — | — | 变体记录（后缀）；基础物种「骷髅战士」已闭合到 Zircon Index 29；Zircon 无独立变体条目，按 handoff 不建新怪 |
| 182 | 骷髅战士61 | — | — | 变体记录（后缀）；基础物种「骷髅战士」已闭合到 Zircon Index 29；Zircon 无独立变体条目，按 handoff 不建新怪 |
| 184 | 盔甲虫0 | — | — | 变体记录（后缀）；基础物种「盔甲虫」已闭合到 Zircon Index 43；Zircon 无独立变体条目，按 handoff 不建新怪 |
| 186 | 夜行鬼09 | — | — | 变体记录（后缀）；基础物种「夜行鬼」在本表中未闭合；Zircon 无独立变体条目，按 handoff 不建新怪 |
| 189 | 猿猴战将0 | — | — | 变体记录（后缀）；基础物种「猿猴战将」在本表中未闭合；Zircon 无独立变体条目，按 handoff 不建新怪 |
| 190 | 猿猴战士 | — | — | 候选 [274] 均已被其它条目占用，Zircon 无独立条目可分配；按一对多处理但无空闲候选 → missing（需人工决定合并或新增） |
| 191 | 猿猴战士0 | — | — | 变体记录（后缀）；基础物种「猿猴战士」在本表中未闭合；Zircon 无独立变体条目，按 handoff 不建新怪 |
| 195 | 震天首将 | — | — | 候选 [139, 199] 均已被其它条目占用，Zircon 无独立条目可分配；按一对多处理但无空闲候选 → missing（需人工决定合并或新增） |
| 196 | 蜘蛛娃 | — | — | 候选 [72, 73] 均已被其它条目占用，Zircon 无独立条目可分配；按一对多处理但无空闲候选 → missing（需人工决定合并或新增） |
| 197 | 蜘蛛娃0 | — | — | 变体记录（后缀）；基础物种「蜘蛛娃」在本表中未闭合；Zircon 无独立变体条目，按 handoff 不建新怪 |
| 199 | 掷斧骷髅0 | — | — | 变体记录（后缀）；基础物种「掷斧骷髅」已闭合到 Zircon Index 28；Zircon 无独立变体条目，按 handoff 不建新怪 |
| 200 | 掷斧骷髅61 | — | — | 变体记录（后缀）；基础物种「掷斧骷髅」已闭合到 Zircon Index 28；Zircon 无独立变体条目，按 handoff 不建新怪 |
| 201 | 掷斧骷髅62 | — | — | 变体记录（后缀）；基础物种「掷斧骷髅」已闭合到 Zircon Index 28；Zircon 无独立变体条目，按 handoff 不建新怪 |
| 205 | 祖玛雕像91 | — | — | 变体记录（后缀）；基础物种「祖玛雕像」在本表中未闭合；Zircon 无独立变体条目，按 handoff 不建新怪 |
| 206 | 祖玛弓箭手0 | — | — | 变体记录（后缀）；基础物种「祖玛弓箭手」已闭合到 Zircon Index 76；Zircon 无独立变体条目，按 handoff 不建新怪 |
| 207 | 祖玛弓箭手92 | — | — | 变体记录（后缀）；基础物种「祖玛弓箭手」已闭合到 Zircon Index 76；Zircon 无独立变体条目，按 handoff 不建新怪 |
| 208 | 祖玛教主62 | — | — | 变体记录（后缀）；基础物种「祖玛教主」已闭合到 Zircon Index 81；Zircon 无独立变体条目，按 handoff 不建新怪 |
| 210 | 祖玛卫士0 | — | — | 变体记录（后缀）；基础物种「祖玛卫士」已闭合到 Zircon Index 78；Zircon 无独立变体条目，按 handoff 不建新怪 |
| 211 | 祖玛卫士90 | — | — | 变体记录（后缀）；基础物种「祖玛卫士」已闭合到 Zircon Index 78；Zircon 无独立变体条目，按 handoff 不建新怪 |
| 212 | 守卫神将 | — | — | Zircon 城镇守卫体系重做，无直接对应 |
| 213 | 沃玛勇士60 | — | — | 变体记录（后缀）；基础物种「沃玛勇士」在本表中未闭合；Zircon 无独立变体条目，按 handoff 不建新怪 |
| 214 | 火焰沃玛61 | — | — | 变体记录（后缀）；基础物种「火焰沃玛」已闭合到 Zircon Index 63；Zircon 无独立变体条目，按 handoff 不建新怪 |
| 215 | 暗黑战士61 | — | — | 变体记录（后缀）；基础物种「暗黑战士」在本表中未闭合；Zircon 无独立变体条目，按 handoff 不建新怪 |
| 217 | 魔石狂热者 | — | — | 魔石系，Zircon 无对应身份 |
| 218 | 火焰狮子99 | — | — | 变体记录（后缀）；基础物种「火焰狮子」已闭合到 Zircon Index 448；Zircon 无独立变体条目，按 handoff 不建新怪 |
| 220 | 小诺玛 | — | — | 候选 [91, 90] 均已被其它条目占用，Zircon 无独立条目可分配；按一对多处理但无空闲候选 → missing（需人工决定合并或新增） |
| 221 | 盔甲蚂蚁0 | — | — | 变体记录（后缀）；基础物种「盔甲蚂蚁」在本表中未闭合；Zircon 无独立变体条目，按 handoff 不建新怪 |
| 224 | 浪子人鬼0 | — | — | 变体记录（后缀）；基础物种「浪子人鬼」在本表中未闭合；Zircon 无独立变体条目，按 handoff 不建新怪 |
| 226 | 劳动蚂蚁0 | — | — | 变体记录（后缀）；基础物种「劳动蚂蚁」在本表中未闭合；Zircon 无独立变体条目，按 handoff 不建新怪 |
| 227 | 老道僵尸61 | — | — | 变体记录（后缀）；基础物种「老道僵尸」在本表中未闭合；Zircon 无独立变体条目，按 handoff 不建新怪 |
| 230 | 练功师 | — | — | 练功假人，Zircon 无对应身份 |
| 231 | 猎鹰 | — | — | SkyStinger 仅有资源图，无 MonsterInfo 身份行 |
| 232 | 猎鹰0 | — | — | 变体记录（后缀）；基础物种「猎鹰」在本表中为 pending 或有说明；Zircon 无独立变体条目，按 handoff 不建新怪 |
| 233 | 玲花 | — | — | NPC/任务，Zircon 无对应身份 |
| 236 | 蚂蚁道士0 | — | — | 变体记录（后缀）；基础物种「蚂蚁道士」在本表中未闭合；Zircon 无独立变体条目，按 handoff 不建新怪 |
| 238 | 蚂蚁战士 | — | — | 候选 [41, 42] 均已被其它条目占用，Zircon 无独立条目可分配；按一对多处理但无空闲候选 → missing（需人工决定合并或新增） |
| 239 | 蚂蚁战士0 | — | — | 变体记录（后缀）；基础物种「蚂蚁战士」在本表中未闭合；Zircon 无独立变体条目，按 handoff 不建新怪 |
| 241 | 武力神将81 | — | — | 变体记录（后缀）；基础物种「武力神将」在本表中未闭合；Zircon 无独立变体条目，按 handoff 不建新怪 |
| 242 | 魔神怪10 | — | — | 变体记录（后缀）；基础物种「魔神怪」在本表中未闭合；Zircon 无独立变体条目，按 handoff 不建新怪 |
| 243 | 魔神怪2 | — | — | 候选 [245] 均已被其它条目占用，Zircon 无独立条目可分配；按一对多处理但无空闲候选 → missing（需人工决定合并或新增） |
| 244 | 魔神怪20 | — | — | 变体记录（后缀）；基础物种「魔神怪」在本表中未闭合；Zircon 无独立变体条目，按 handoff 不建新怪 |
| 245 | 木障 | — | — | 地图障碍物，非怪物身份 |
| 246 | 震天兽 | — | — | 候选 [199, 139] 均已被其它条目占用，Zircon 无独立条目可分配；按一对多处理但无空闲候选 → missing（需人工决定合并或新增） |
| 248 | 弩车 | — | — | 守城器械，Zircon 无对应身份 |
| 250 | 诺玛0 | — | — | 变体记录（后缀）；基础物种「诺玛」在本表中未闭合；Zircon 无独立变体条目，按 handoff 不建新怪 |
| 251 | 诺玛将士 | — | — | 候选 [165] 均已被其它条目占用，Zircon 无独立条目可分配；按一对多处理但无空闲候选 → missing（需人工决定合并或新增） |
| 252 | 诺玛00 | — | — | 变体记录（后缀）；基础物种「诺玛」在本表中未闭合；Zircon 无独立变体条目，按 handoff 不建新怪 |
| 253 | 诺玛07 | — | — | 变体记录（后缀）；基础物种「诺玛」在本表中未闭合；Zircon 无独立变体条目，按 handoff 不建新怪 |
| 254 | 诺玛08 | — | — | 变体记录（后缀）；基础物种「诺玛」在本表中未闭合；Zircon 无独立变体条目，按 handoff 不建新怪 |
| 255 | 诺玛09 | — | — | 变体记录（后缀）；基础物种「诺玛」在本表中未闭合；Zircon 无独立变体条目，按 handoff 不建新怪 |
| 256 | 诺玛1 | — | — | 变体记录（后缀）；基础物种「诺玛」在本表中未闭合；Zircon 无独立变体条目，按 handoff 不建新怪 |
| 257 | 诺玛10 | — | — | 变体记录（后缀）；基础物种「诺玛」在本表中未闭合；Zircon 无独立变体条目，按 handoff 不建新怪 |
| 258 | 诺玛17 | — | — | 变体记录（后缀）；基础物种「诺玛」在本表中未闭合；Zircon 无独立变体条目，按 handoff 不建新怪 |
| 259 | 诺玛18 | — | — | 变体记录（后缀）；基础物种「诺玛」在本表中未闭合；Zircon 无独立变体条目，按 handoff 不建新怪 |
| 260 | 诺玛19 | — | — | 变体记录（后缀）；基础物种「诺玛」在本表中未闭合；Zircon 无独立变体条目，按 handoff 不建新怪 |
| 261 | 诺玛2 | — | — | 变体记录（后缀）；基础物种「诺玛」在本表中未闭合；Zircon 无独立变体条目，按 handoff 不建新怪 |
| 262 | 诺玛20 | — | — | 变体记录（后缀）；基础物种「诺玛」在本表中未闭合；Zircon 无独立变体条目，按 handoff 不建新怪 |
| 263 | 诺玛27 | — | — | 变体记录（后缀）；基础物种「诺玛」在本表中未闭合；Zircon 无独立变体条目，按 handoff 不建新怪 |
| 264 | 诺玛28 | — | — | 变体记录（后缀）；基础物种「诺玛」在本表中未闭合；Zircon 无独立变体条目，按 handoff 不建新怪 |
| 265 | 诺玛29 | — | — | 变体记录（后缀）；基础物种「诺玛」在本表中未闭合；Zircon 无独立变体条目，按 handoff 不建新怪 |
| 266 | 诺玛3 | — | — | 变体记录（后缀）；基础物种「诺玛」在本表中未闭合；Zircon 无独立变体条目，按 handoff 不建新怪 |
| 267 | 诺玛30 | — | — | 变体记录（后缀）；基础物种「诺玛」在本表中未闭合；Zircon 无独立变体条目，按 handoff 不建新怪 |
| 268 | 诺玛37 | — | — | 变体记录（后缀）；基础物种「诺玛」在本表中未闭合；Zircon 无独立变体条目，按 handoff 不建新怪 |
| 269 | 诺玛38 | — | — | 变体记录（后缀）；基础物种「诺玛」在本表中未闭合；Zircon 无独立变体条目，按 handoff 不建新怪 |
| 270 | 诺玛39 | — | — | 变体记录（后缀）；基础物种「诺玛」在本表中未闭合；Zircon 无独立变体条目，按 handoff 不建新怪 |
| 271 | 诺玛城门 | — | — | 城门物件，非怪物身份 |
| 272 | 诺玛法老 | — | — | 候选 [166] 均已被其它条目占用，Zircon 无独立条目可分配；按一对多处理但无空闲候选 → missing（需人工决定合并或新增） |
| 273 | 诺玛法老0 | — | — | 变体记录（后缀）；基础物种「诺玛法老」在本表中未闭合；Zircon 无独立变体条目，按 handoff 不建新怪 |
| 274 | 诺玛法老7 | — | — | 变体记录（后缀）；基础物种「诺玛法老」在本表中未闭合；Zircon 无独立变体条目，按 handoff 不建新怪 |
| 275 | 诺玛法老8 | — | — | 变体记录（后缀）；基础物种「诺玛法老」在本表中未闭合；Zircon 无独立变体条目，按 handoff 不建新怪 |
| 276 | 诺玛法老9 | — | — | 变体记录（后缀）；基础物种「诺玛法老」在本表中未闭合；Zircon 无独立变体条目，按 handoff 不建新怪 |
| 278 | 诺玛将士0 | — | — | 变体记录（后缀）；基础物种「诺玛将士」在本表中未闭合；Zircon 无独立变体条目，按 handoff 不建新怪 |
| 279 | 诺玛将士7 | — | — | 变体记录（后缀）；基础物种「诺玛将士」在本表中未闭合；Zircon 无独立变体条目，按 handoff 不建新怪 |
| 280 | 诺玛将士8 | — | — | 变体记录（后缀）；基础物种「诺玛将士」在本表中未闭合；Zircon 无独立变体条目，按 handoff 不建新怪 |
| 281 | 诺玛将士9 | — | — | 变体记录（后缀）；基础物种「诺玛将士」在本表中未闭合；Zircon 无独立变体条目，按 handoff 不建新怪 |
| 283 | 诺玛王 | — | — | 候选 [98] 均已被其它条目占用，Zircon 无独立条目可分配；按一对多处理但无空闲候选 → missing（需人工决定合并或新增） |
| 288 | 诺玛卫士 | — | — | 诺玛守卫，Zircon 诺玛系无对应名 |
| 289 | 诺玛巡逻队长 | — | — | 候选 [164, 161] 均已被其它条目占用，Zircon 无独立条目可分配；按一对多处理但无空闲候选 → missing（需人工决定合并或新增） |
| 291 | 诺玛阻力军1 | — | — | 变体记录（后缀）；基础物种「诺玛阻力军」在本表中未闭合；Zircon 无独立变体条目，按 handoff 不建新怪 |
| 293 | 潘夜冰魔0 | — | — | 变体记录（后缀）；基础物种「潘夜冰魔」在本表中未闭合；Zircon 无独立变体条目，按 handoff 不建新怪 |
| 295 | 潘夜风魔0 | — | — | 变体记录（后缀）；基础物种「潘夜风魔」在本表中未闭合；Zircon 无独立变体条目，按 handoff 不建新怪 |
| 298 | 潘夜火魔0 | — | — | 变体记录（后缀）；基础物种「潘夜火魔」在本表中未闭合；Zircon 无独立变体条目，按 handoff 不建新怪 |
| 301 | 潘夜右护卫0 | — | — | 变体记录（后缀）；基础物种「潘夜右护卫」在本表中未闭合；Zircon 无独立变体条目，按 handoff 不建新怪 |
| 302 | 潘夜右护卫95 | — | — | 变体记录（后缀）；基础物种「潘夜右护卫」在本表中未闭合；Zircon 无独立变体条目，按 handoff 不建新怪 |
| 303 | 潘夜云魔0 | — | — | 变体记录（后缀）；基础物种「潘夜云魔」在本表中未闭合；Zircon 无独立变体条目，按 handoff 不建新怪 |
| 305 | 潘夜战士0 | — | — | 变体记录（后缀）；基础物种「潘夜战士」已闭合到 Zircon Index 186；Zircon 无独立变体条目，按 handoff 不建新怪 |
| 307 | 潘夜左护卫0 | — | — | 变体记录（后缀）；基础物种「潘夜左护卫」在本表中未闭合；Zircon 无独立变体条目，按 handoff 不建新怪 |
| 308 | 潘夜左护卫94 | — | — | 变体记录（后缀）；基础物种「潘夜左护卫」在本表中未闭合；Zircon 无独立变体条目，按 handoff 不建新怪 |
| 309 | 千年毒蛇 | — | — | RedSnake 仅有资源图，无 MonsterInfo 身份行 |
| 310 | 千年毒蛇0 | — | — | 变体记录（后缀）；基础物种「千年毒蛇」在本表中为 pending 或有说明；Zircon 无独立变体条目，按 handoff 不建新怪 |
| 312 | 钳虫0 | — | — | 变体记录（后缀）；基础物种「钳虫」在本表中未闭合；Zircon 无独立变体条目，按 handoff 不建新怪 |
| 316 | 森林雪人0 | — | — | 变体记录（后缀）；基础物种「森林雪人」已闭合到 Zircon Index 15；Zircon 无独立变体条目，按 handoff 不建新怪 |
| 317 | 僧侣僵尸 | — | — | 候选 [58, 57] 均已被其它条目占用，Zircon 无独立条目可分配；按一对多处理但无空闲候选 → missing（需人工决定合并或新增） |
| 318 | 僧侣僵尸61 | — | — | 变体记录（后缀）；基础物种「僧侣僵尸」在本表中为 pending 或有说明；Zircon 无独立变体条目，按 handoff 不建新怪 |
| 319 | 沙巴克城门1 | — | — | 变体记录（后缀）；基础物种「沙巴克城门」在本表中为 pending 或有说明；Zircon 无独立变体条目，按 handoff 不建新怪 |
| 320 | 沙巴克城门2 | — | — | 变体记录（后缀）；基础物种「沙巴克城门」在本表中为 pending 或有说明；Zircon 无独立变体条目，按 handoff 不建新怪 |
| 321 | 沙巴克城门3 | — | — | 变体记录（后缀）；基础物种「沙巴克城门」在本表中为 pending 或有说明；Zircon 无独立变体条目，按 handoff 不建新怪 |
| 322 | 沙巴克城门4 | — | — | 变体记录（后缀）；基础物种「沙巴克城门」在本表中为 pending 或有说明；Zircon 无独立变体条目，按 handoff 不建新怪 |
| 324 | 沙鬼0 | — | — | 变体记录（后缀）；基础物种「沙鬼」已闭合到 Zircon Index 93；Zircon 无独立变体条目，按 handoff 不建新怪 |
| 325 | 沙魔树魔0 | — | — | 变体记录（后缀）；基础物种「沙魔树魔」在本表中未闭合；Zircon 无独立变体条目，按 handoff 不建新怪 |
| 326 | 沙魔鱼魔0 | — | — | 变体记录（后缀）；基础物种「沙魔鱼魔」在本表中未闭合；Zircon 无独立变体条目，按 handoff 不建新怪 |
| 328 | 沙漠风魔0 | — | — | 变体记录（后缀）；基础物种「沙漠风魔」在本表中未闭合；Zircon 无独立变体条目，按 handoff 不建新怪 |
| 330 | 沙漠石人0 | — | — | 变体记录（后缀）；基础物种「沙漠石人」在本表中未闭合；Zircon 无独立变体条目，按 handoff 不建新怪 |
| 332 | 沙漠树魔61 | — | — | 变体记录（后缀）；基础物种「沙漠树魔」已闭合到 Zircon Index 95；Zircon 无独立变体条目，按 handoff 不建新怪 |
| 333 | 沙漠树魔62 | — | — | 变体记录（后缀）；基础物种「沙漠树魔」已闭合到 Zircon Index 95；Zircon 无独立变体条目，按 handoff 不建新怪 |
| 336 | 沙漠蜥蜴0 | — | — | 变体记录（后缀）；基础物种「沙漠蜥蜴」在本表中未闭合；Zircon 无独立变体条目，按 handoff 不建新怪 |
| 340 | 山洞蝙蝠0 | — | — | 变体记录（后缀）；基础物种「山洞蝙蝠」已闭合到 Zircon Index 24；Zircon 无独立变体条目，按 handoff 不建新怪 |
| 341 | 山洞蝙蝠61 | — | — | 变体记录（后缀）；基础物种「山洞蝙蝠」已闭合到 Zircon Index 24；Zircon 无独立变体条目，按 handoff 不建新怪 |
| 342 | 神鬼王 | — | — | 候选 [70] 均已被其它条目占用，Zircon 无独立条目可分配；按一对多处理但无空闲候选 → missing（需人工决定合并或新增） |
| 345 | 神兽1 | — | — | 变体记录（后缀）；基础物种「神兽」在本表中为 pending 或有说明；Zircon 无独立变体条目，按 handoff 不建新怪 |
| 346 | 圣诞树 | — | — | 节日活动怪，Zircon 无对应身份 |
| 348 | 尸王2 | — | — | 变体记录（后缀）；基础物种「尸王」在本表中未闭合；Zircon 无独立变体条目，按 handoff 不建新怪 |
| 349 | 尸王61 | — | — | 变体记录（后缀）；基础物种「尸王」在本表中未闭合；Zircon 无独立变体条目，按 handoff 不建新怪 |
| 351 | 石像狮子0 | — | — | 变体记录（后缀）；基础物种「石像狮子」已闭合到 Zircon Index 484；Zircon 无独立变体条目，按 handoff 不建新怪 |
| 352 | 石像狮子96 | — | — | 变体记录（后缀）；基础物种「石像狮子」已闭合到 Zircon Index 484；Zircon 无独立变体条目，按 handoff 不建新怪 |
| 353 | 食人花61 | — | — | 变体记录（后缀）；基础物种「食人花」已闭合到 Zircon Index 17；Zircon 无独立变体条目，按 handoff 不建新怪 |
| 354 | 守卫虫 | — | — | 守卫类，Zircon 无对应身份 |
| 356 | 天狼蜘蛛0 | — | — | 变体记录（后缀）；基础物种「天狼蜘蛛」在本表中未闭合；Zircon 无独立变体条目，按 handoff 不建新怪 |
| 358 | 跳跳蜂0 | — | — | 变体记录（后缀）；基础物种「跳跳蜂」在本表中未闭合；Zircon 无独立变体条目，按 handoff 不建新怪 |
| 359 | 跳跳蜂61 | — | — | 变体记录（后缀）；基础物种「跳跳蜂」在本表中未闭合；Zircon 无独立变体条目，按 handoff 不建新怪 |
| 360 | 投石车 | — | — | 守城器械，Zircon 无对应身份 |
| 361 | 图书馆护卫 | — | — | 任务守卫，Zircon 无对应身份 |
| 365 | 卫士1 | — | — | 变体记录（后缀）；基础物种「卫士」在本表中为 pending 或有说明；Zircon 无独立变体条目，按 handoff 不建新怪 |
| 366 | 沃毒蜈蚣61 | — | — | 变体记录（后缀）；基础物种「沃毒蜈蚣」在本表中未闭合；Zircon 无独立变体条目，按 handoff 不建新怪 |
| 367 | 沃毒蜈蚣62 | — | — | 变体记录（后缀）；基础物种「沃毒蜈蚣」在本表中未闭合；Zircon 无独立变体条目，按 handoff 不建新怪 |
| 369 | 沃玛护卫61 | — | — | 变体记录（后缀）；基础物种「沃玛护卫」在本表中为 pending 或有说明；Zircon 无独立变体条目，按 handoff 不建新怪 |
| 371 | 沃玛教主62 | — | — | 变体记录（后缀）；基础物种「沃玛教主」已闭合到 Zircon Index 65；Zircon 无独立变体条目，按 handoff 不建新怪 |
| 372 | 沃玛卫士 | — | — | 候选 [65] 均已被其它条目占用，Zircon 无独立条目可分配；按一对多处理但无空闲候选 → missing（需人工决定合并或新增） |
| 373 | 沃玛勇士 | — | — | 候选 [64] 均已被其它条目占用，Zircon 无独立条目可分配；按一对多处理但无空闲候选 → missing（需人工决定合并或新增） |
| 374 | 沃玛勇士0 | — | — | 变体记录（后缀）；基础物种「沃玛勇士」在本表中未闭合；Zircon 无独立变体条目，按 handoff 不建新怪 |
| 375 | 沃玛勇士10 | — | — | 变体记录（后缀）；基础物种「沃玛勇士」在本表中未闭合；Zircon 无独立变体条目，按 handoff 不建新怪 |
| 376 | 沃玛勇士61 | — | — | 变体记录（后缀）；基础物种「沃玛勇士」在本表中未闭合；Zircon 无独立变体条目，按 handoff 不建新怪 |
| 377 | 沃玛战将 | — | — | 候选 [64] 均已被其它条目占用，Zircon 无独立条目可分配；按一对多处理但无空闲候选 → missing（需人工决定合并或新增） |
| 378 | 沃玛战将0 | — | — | 变体记录（后缀）；基础物种「沃玛战将」在本表中未闭合；Zircon 无独立变体条目，按 handoff 不建新怪 |
| 379 | 沃玛战将20 | — | — | 变体记录（后缀）；基础物种「沃玛战将」在本表中未闭合；Zircon 无独立变体条目，按 handoff 不建新怪 |
| 380 | 沃玛战士 | — | — | 候选 [63] 均已被其它条目占用，Zircon 无独立条目可分配；按一对多处理但无空闲候选 → missing（需人工决定合并或新增） |
| 381 | 沃玛战士0 | — | — | 变体记录（后缀）；基础物种「沃玛战士」在本表中未闭合；Zircon 无独立变体条目，按 handoff 不建新怪 |
| 382 | 沃玛战士61 | — | — | 变体记录（后缀）；基础物种「沃玛战士」在本表中未闭合；Zircon 无独立变体条目，按 handoff 不建新怪 |
| 384 | 蜈蚣0 | — | — | 变体记录（后缀）；基础物种「蜈蚣」在本表中为 pending 或有说明；Zircon 无独立变体条目，按 handoff 不建新怪 |
| 385 | 蜈蚣61 | — | — | 变体记录（后缀）；基础物种「蜈蚣」在本表中为 pending 或有说明；Zircon 无独立变体条目，按 handoff 不建新怪 |
| 386 | 武力神将 | — | — | 候选 [164, 166] 均已被其它条目占用，Zircon 无独立条目可分配；按一对多处理但无空闲候选 → missing（需人工决定合并或新增） |
| 387 | 武力神将0 | — | — | 变体记录（后缀）；基础物种「武力神将」在本表中未闭合；Zircon 无独立变体条目，按 handoff 不建新怪 |
| 389 | 楔蛾93 | — | — | 变体记录（后缀）；基础物种「楔蛾」已闭合到 Zircon Index 124；Zircon 无独立变体条目，按 handoff 不建新怪 |
| 390 | 蝎蛇0 | — | — | 变体记录（后缀）；基础物种「蝎蛇」已闭合到 Zircon Index 126；Zircon 无独立变体条目，按 handoff 不建新怪 |
| 392 | 蝎子61 | — | — | 变体记录（后缀）；基础物种「蝎子」已闭合到 Zircon Index 25；Zircon 无独立变体条目，按 handoff 不建新怪 |
| 393 | 邪恶毒蛇 | — | — | Mud3 独有 / 无 Zircon 对应身份 |
| 395 | 邪恶钳虫62 | — | — | 变体记录（后缀）；基础物种「邪恶钳虫」在本表中未闭合；Zircon 无独立变体条目，按 handoff 不建新怪 |
| 396 | 邪恶蜈蚣61 | — | — | 变体记录（后缀）；基础物种「邪恶蜈蚣」在本表中未闭合；Zircon 无独立变体条目，按 handoff 不建新怪 |
| 397 | 雄诺玛 | — | — | 候选 [91, 90] 均已被其它条目占用，Zircon 无独立条目可分配；按一对多处理但无空闲候选 → missing（需人工决定合并或新增） |
| 399 | 血金刚0 | — | — | 变体记录（后缀）；基础物种「血金刚」在本表中未闭合；Zircon 无独立变体条目，按 handoff 不建新怪 |
| 400 | 血金刚70 | — | — | 变体记录（后缀）；基础物种「血金刚」在本表中未闭合；Zircon 无独立变体条目，按 handoff 不建新怪 |
| 401 | 血巨人0 | — | — | 变体记录（后缀）；基础物种「血巨人」在本表中未闭合；Zircon 无独立变体条目，按 handoff 不建新怪 |
| 403 | 夜行鬼 | — | — | Mud3 独有 / 无 Zircon 对应身份 |
| 404 | 夜行鬼0 | — | — | 变体记录（后缀）；基础物种「夜行鬼」在本表中未闭合；Zircon 无独立变体条目，按 handoff 不建新怪 |
| 406 | 超强骷髅 | — | — | 召唤兽强化版，Zircon 无独立身份 |
| 407 | 血金刚 | — | — | 候选 [70] 均已被其它条目占用，Zircon 无独立条目可分配；按一对多处理但无空闲候选 → missing（需人工决定合并或新增） |
| 409 | 诺玛阻力军0 | — | — | 变体记录（后缀）；基础物种「诺玛阻力军」在本表中未闭合；Zircon 无独立变体条目，按 handoff 不建新怪 |
| 410 | 阿龙怪 | — | — | 候选 [128, 176] 均已被其它条目占用，Zircon 无独立条目可分配；按一对多处理但无空闲候选 → missing（需人工决定合并或新增） |
| 411 | 魔石咆哮者 | — | — | 魔石系，Zircon 无对应身份 |
| 412 | 魔石狂热者 | — | — | 魔石系，Zircon 无对应身份 |
| 413 | 魔石守护神 | — | — | 魔石系，Zircon 无对应身份 |
| 432 | 圣诞树 | — | — | 节日活动怪，Zircon 无对应身份 |
| 433 | 圣诞鹿 | — | — | 节日活动怪，Zircon 无对应身份 |

## zircon-only（Zircon 有、Mud3 无）（284）

| Mud3 Index | Mud3 中文名 | Zircon Index | Zircon 身份 | 证据 |
|---|---|---:|---|---|
| — | — | 32 | GhostSorcerer | Zircon 后期/强化行，Mud3 DAT 无 |
| — | — | 33 | Ghost Mage | Zircon 后期/强化行，Mud3 DAT 无 |
| — | — | 34 | Voracious Ghost | Zircon 后期/强化行，Mud3 DAT 无 |
| — | — | 35 | Devouring Ghost | Zircon 后期/强化行，Mud3 DAT 无 |
| — | — | 36 | Corpse Raising Ghost | Zircon 后期/强化行，Mud3 DAT 无 |
| — | — | 37 | Ghoul Champion | Zircon 后期/强化行，Mud3 DAT 无 |
| — | — | 45 | Visceral Worm | Zircon 后期/强化行，Mud3 DAT 无 |
| — | — | 48 | Blaster Mutant Flea | Zircon 后期/强化行，Mud3 DAT 无 |
| — | — | 49 | Terror Spike | Zircon 后期/强化行，Mud3 DAT 无 |
| — | — | 54 | Earwig | Zircon 后期/强化行，Mud3 DAT 无 |
| — | — | 55 | Iron Lance | Zircon 后期/强化行，Mud3 DAT 无 |
| — | — | 59 | Blood Thristy Ghoul | Zircon 后期/强化行，Mud3 DAT 无 |
| — | — | 67 | Arachnid Gazer | Zircon 后期/强化行，Mud3 DAT 无 |
| — | — | 68 | Larva | Zircon 后期/强化行，Mud3 DAT 无 |
| — | — | 74 | Red Moon Royal Guard | Zircon 后期/强化行，Mud3 DAT 无 |
| — | — | 82 | Evil Fanatic | Zircon 后期/强化行，Mud3 DAT 无 |
| — | — | 83 | Monkey | Zircon 后期/强化行，Mud3 DAT 无 |
| — | — | 84 | Evil Monkey | Zircon 后期/强化行，Mud3 DAT 无 |
| — | — | 86 | Cannibal Fanatic | Zircon 后期/强化行，Mud3 DAT 无 |
| — | — | 87 | Crazed Warrior | Zircon 后期/强化行，Mud3 DAT 无 |
| — | — | 92 | Sand Shark | Zircon 后期/强化行，Mud3 DAT 无 |
| — | — | 94 | Windfury Sorceress | Zircon 后期/强化行，Mud3 DAT 无 |
| — | — | 100 | Venom Spitter | Zircon 后期/强化行，Mud3 DAT 无 |
| — | — | 103 | Crazed Lizard | Zircon 后期/强化行，Mud3 DAT 无 |
| — | — | 104 | Tainted Terror | Zircon 后期/强化行，Mud3 DAT 无 |
| — | — | 107 | Minotaur | Zircon 后期/强化行，Mud3 DAT 无 |
| — | — | 108 | Frost Minotaur | Zircon 后期/强化行，Mud3 DAT 无 |
| — | — | 109 | Banya Right Guard | Zircon 后期/强化行，Mud3 DAT 无 |
| — | — | 110 | Shock Minotaur | Zircon 后期/强化行，Mud3 DAT 无 |
| — | — | 111 | Banya Left Guard | Zircon 后期/强化行，Mud3 DAT 无 |
| — | — | 112 | Fury Minotaur | Zircon 后期/强化行，Mud3 DAT 无 |
| — | — | 114 | Banya Guardian | Zircon 后期/强化行，Mud3 DAT 无 |
| — | — | 118 | Bone Captain | Zircon 后期/强化行，Mud3 DAT 无 |
| — | — | 122 | Wedge Moth Larva | Zircon 后期/强化行，Mud3 DAT 无 |
| — | — | 123 | Lesser Wedge Moth | Zircon 后期/强化行，Mud3 DAT 无 |
| — | — | 129 | Razor Tusk | Zircon 后期/强化行，Mud3 DAT 无 |
| — | — | 130 | Pink Goddess Of Black Palace | Zircon 后期/强化行，Mud3 DAT 无 |
| — | — | 131 | Green Goddess Of Black Palace | Zircon 后期/强化行，Mud3 DAT 无 |
| — | — | 132 | Mutant Captain | Zircon 后期/强化行，Mud3 DAT 无 |
| — | — | 133 | Stone Griffin | Zircon 后期/强化行，Mud3 DAT 无 |
| — | — | 134 | Flame Griffin | Zircon 后期/强化行，Mud3 DAT 无 |
| — | — | 135 | Black Palace Warlord | Zircon 后期/强化行，Mud3 DAT 无 |
| — | — | 136 | Pink Goddess Of Underground | Zircon 后期/强化行，Mud3 DAT 无 |
| — | — | 137 | Vicious Mutant Captain | Zircon 后期/强化行，Mud3 DAT 无 |
| — | — | 138 | Green Goddess Of Underground | Zircon 后期/强化行，Mud3 DAT 无 |
| — | — | 140 | SummonPuppet | Zircon 后期/强化行，Mud3 DAT 无 |
| — | — | 141 | Apparition Archer | Zircon 后期/强化行，Mud3 DAT 无 |
| — | — | 142 | Apparition Bladesman | Zircon 后期/强化行，Mud3 DAT 无 |
| — | — | 143 | Apparition Soldier | Zircon 后期/强化行，Mud3 DAT 无 |
| — | — | 144 | Skeleton | Zircon 后期/强化行，Mud3 DAT 无 |
| — | — | 145 | Jin Skeleton | Zircon 后期/强化行，Mud3 DAT 无 |
| — | — | 150 | MirrorImage | Zircon 后期/强化行，Mud3 DAT 无 |
| — | — | 151 | Corpse Stalker | Zircon 后期/强化行，Mud3 DAT 无 |
| — | — | 153 | Corrosive Poison Spitter | Zircon 后期/强化行，Mud3 DAT 无 |
| — | — | 154 | Phantom Soldier | Zircon 后期/强化行，Mud3 DAT 无 |
| — | — | 155 | Mutated Octopus | Zircon 后期/强化行，Mud3 DAT 无 |
| — | — | 156 | Aqua Lizard | Zircon 后期/强化行，Mud3 DAT 无 |
| — | — | 157 | Stomper | Zircon 后期/强化行，Mud3 DAT 无 |
| — | — | 158 | Crimson Necromancer | Zircon 后期/强化行，Mud3 DAT 无 |
| — | — | 159 | Chaos Knight | Zircon 后期/强化行，Mud3 DAT 无 |
| — | — | 162 | Numa High Mage | Zircon 后期/强化行，Mud3 DAT 无 |
| — | — | 167 | Icy Ranger | Zircon 后期/强化行，Mud3 DAT 无 |
| — | — | 168 | Icy Goddess | Zircon 后期/强化行，Mud3 DAT 无 |
| — | — | 169 | Icy Spirit Warrior | Zircon 后期/强化行，Mud3 DAT 无 |
| — | — | 170 | Icy Spirit General | Zircon 后期/强化行，Mud3 DAT 无 |
| — | — | 171 | Ghost Knight | Zircon 后期/强化行，Mud3 DAT 无 |
| — | — | 172 | Icy Spirit Spearman | Zircon 后期/强化行，Mud3 DAT 无 |
| — | — | 173 | Werewolf | Zircon 后期/强化行，Mud3 DAT 无 |
| — | — | 174 | Whitefang | Zircon 后期/强化行，Mud3 DAT 无 |
| — | — | 175 | Icy Spirit Solider | Zircon 后期/强化行，Mud3 DAT 无 |
| — | — | 177 | Jinam Stone Gate | Zircon 后期/强化行，Mud3 DAT 无 |
| — | — | 178 | Frost Lord Hwa | Zircon 后期/强化行，Mud3 DAT 无 |
| — | — | 180 | Golden Armored Beetle | Zircon 后期/强化行，Mud3 DAT 无 |
| — | — | 181 | Earwig King | Zircon 后期/强化行，Mud3 DAT 无 |
| — | — | 182 | Mature Earwig | Zircon 后期/强化行，Mud3 DAT 无 |
| — | — | 184 | Enraged Lord Ji'Nae | Zircon 后期/强化行，Mud3 DAT 无 |
| — | — | 187 | Banyo Captain | Zircon 后期/强化行，Mud3 DAT 无 |
| — | — | 188 | Banyo Lord Guzak | Zircon 后期/强化行，Mud3 DAT 无 |
| — | — | 189 | Pig | 宠物/坐骑伴随兽（Level 0，AI=-2），Mud3 DAT 无 |
| — | — | 190 | Tusk Lord | 宠物/坐骑伴随兽（Level 0，AI=-2），Mud3 DAT 无 |
| — | — | 191 | Skeleton Lord | 宠物/坐骑伴随兽（Level 0，AI=-2），Mud3 DAT 无 |
| — | — | 192 | Griffin | 宠物/坐骑伴随兽（Level 0，AI=-2），Mud3 DAT 无 |
| — | — | 193 | Dragon | 宠物/坐骑伴随兽（Level 0，AI=-2），Mud3 DAT 无 |
| — | — | 194 | Donkey | 宠物/坐骑伴随兽（Level 0，AI=-2），Mud3 DAT 无 |
| — | — | 195 | Sheep | 宠物/坐骑伴随兽（Level 0，AI=-2），Mud3 DAT 无 |
| — | — | 196 | Pachon  | 宠物/坐骑伴随兽（Level 0，AI=-2），Mud3 DAT 无 |
| — | — | 197 | Panda | 宠物/坐骑伴随兽（Level 0，AI=-2），Mud3 DAT 无 |
| — | — | 198 | Rabbit | 宠物/坐骑伴随兽（Level 0，AI=-2），Mud3 DAT 无 |
| — | — | 200 | Black Palace Demon | Zircon 后期/强化行，Mud3 DAT 无 |
| — | — | 201 | Brass Feral Warrior | Zircon 后期/强化行，Mud3 DAT 无 |
| — | — | 202 | Obsidian Feral Warrior | Zircon 后期/强化行，Mud3 DAT 无 |
| — | — | 203 | Sun Feral Warrior | Zircon 后期/强化行，Mud3 DAT 无 |
| — | — | 204 | Moon Feral Warrior | Zircon 后期/强化行，Mud3 DAT 无 |
| — | — | 205 | Ox Feral General | Zircon 后期/强化行，Mud3 DAT 无 |
| — | — | 206 | Flame Demon | Zircon 后期/强化行，Mud3 DAT 无 |
| — | — | 207 | Winged Horror | Zircon 后期/强化行，Mud3 DAT 无 |
| — | — | 208 | Enraged Emperor Sa'Woo | Zircon 后期/强化行，Mud3 DAT 无 |
| — | — | 209 | Ferocious Flame Demon | Zircon 后期/强化行，Mud3 DAT 无 |
| — | — | 210 | Oma Warlord | Zircon 后期/强化行，Mud3 DAT 无 |
| — | — | 211 | Goru Spearman | Zircon 后期/强化行，Mud3 DAT 无 |
| — | — | 212 | Goru Archer | Zircon 后期/强化行，Mud3 DAT 无 |
| — | — | 213 | Goru General | Zircon 后期/强化行，Mud3 DAT 无 |
| — | — | 215 | Enraged Arch Lich Taedu | Zircon 后期/强化行，Mud3 DAT 无 |
| — | — | 216 | Escort Commander | Zircon 后期/强化行，Mud3 DAT 无 |
| — | — | 217 | Fiery Dancer | Zircon 后期/强化行，Mud3 DAT 无 |
| — | — | 218 | Emerald Dancer | Zircon 后期/强化行，Mud3 DAT 无 |
| — | — | 219 | Queen Of Dawn | Zircon 后期/强化行，Mud3 DAT 无 |
| — | — | 220 | Sabuk Lord | Zircon 后期/强化行，Mud3 DAT 无 |
| — | — | 222 | Yumgon Witch | Zircon 后期/强化行，Mud3 DAT 无 |
| — | — | 224 | Ma Warlord | Zircon 后期/强化行，Mud3 DAT 无 |
| — | — | 225 | Jinhwan Spirit | Zircon 后期/强化行，Mud3 DAT 无 |
| — | — | 226 | Jinhwan Guardian | Zircon 后期/强化行，Mud3 DAT 无 |
| — | — | 227 | Oyoung General | Zircon 后期/强化行，Mud3 DAT 无 |
| — | — | 228 | Yumgon General | Zircon 后期/强化行，Mud3 DAT 无 |
| — | — | 229 | Chiwoo General Of East | Zircon 后期/强化行，Mud3 DAT 无 |
| — | — | 230 | Chiwoo General Of West | Zircon 后期/强化行，Mud3 DAT 无 |
| — | — | 233 | Ferocious Ice Tiger | 后期/强化系列，Mud3 DAT 无独立条目 |
| — | — | 244 | Escort Commander | Zircon 后期/强化行，Mud3 DAT 无 |
| — | — | 246 | Sama Cursed Flame Mage | 萨玛/苏美尔私服原创，Mud3 DAT 无 |
| — | — | 249 | Sama Fire Guardian | 萨玛/苏美尔私服原创，Mud3 DAT 无 |
| — | — | 250 | Sama Ice Guardian | 萨玛/苏美尔私服原创，Mud3 DAT 无 |
| — | — | 251 | Sama Lightning Guardian | 萨玛/苏美尔私服原创，Mud3 DAT 无 |
| — | — | 253 | Black Sama | 萨玛/苏美尔私服原创，Mud3 DAT 无 |
| — | — | 254 | Blue Sama | 萨玛/苏美尔私服原创，Mud3 DAT 无 |
| — | — | 255 | Phoenix Sama | 萨玛/苏美尔私服原创，Mud3 DAT 无 |
| — | — | 256 | White Tiger Sama | 萨玛/苏美尔私服原创，Mud3 DAT 无 |
| — | — | 258 | Enshrinement Box | Zircon 后期/强化行，Mud3 DAT 无 |
| — | — | 259 | Sama Prophet | 萨玛/苏美尔私服原创，Mud3 DAT 无 |
| — | — | 260 | Sama Sorcerer | 萨玛/苏美尔私服原创，Mud3 DAT 无 |
| — | — | 261 | Blood Stone | Zircon 后期/强化行，Mud3 DAT 无 |
| — | — | 262 | Life Stone | Zircon 后期/强化行，Mud3 DAT 无 |
| — | — | 263 | Dark Stone | Zircon 后期/强化行，Mud3 DAT 无 |
| — | — | 264 | Young Tiger | Zircon 后期/强化行，Mud3 DAT 无 |
| — | — | 265 | Tiger | Zircon 后期/强化行，Mud3 DAT 无 |
| — | — | 266 | Blood Tiger | Zircon 后期/强化行，Mud3 DAT 无 |
| — | — | 267 | Blizzard Tiger | Zircon 后期/强化行，Mud3 DAT 无 |
| — | — | 268 | Dark Tiger | Zircon 后期/强化行，Mud3 DAT 无 |
| — | — | 269 | Elder Dark Tiger | Zircon 后期/强化行，Mud3 DAT 无 |
| — | — | 270 | Elder White Tiger | Zircon 后期/强化行，Mud3 DAT 无 |
| — | — | 271 | Tiger General | Zircon 后期/强化行，Mud3 DAT 无 |
| — | — | 272 | Tiger War Lord | Zircon 后期/强化行，Mud3 DAT 无 |
| — | — | 273 | Wild Elephant | Zircon 后期/强化行，Mud3 DAT 无 |
| — | — | 275 | Wild Fanatic | Zircon 后期/强化行，Mud3 DAT 无 |
| — | — | 277 | Evil Snake | Zircon 后期/强化行，Mud3 DAT 无 |
| — | — | 278 | Salamander | Zircon 后期/强化行，Mud3 DAT 无 |
| — | — | 279 | Sand Golem | Zircon 后期/强化行，Mud3 DAT 无 |
| — | — | 284 | Oma Mage | Zircon 后期/强化行，Mud3 DAT 无 |
| — | — | 293 | Twin Tail Scorpion | Zircon 后期/强化行，Mud3 DAT 无 |
| — | — | 294 | Bloody Mole | Zircon 后期/强化行，Mud3 DAT 无 |
| — | — | 295 | Imp | Zircon 后期/强化行，Mud3 DAT 无 |
| — | — | 296 | Ettin | Zircon 后期/强化行，Mud3 DAT 无 |
| — | — | 297 | Centurion | Zircon 后期/强化行，Mud3 DAT 无 |
| — | — | 298 | Rot Wraith | Zircon 后期/强化行，Mud3 DAT 无 |
| — | — | 299 | Cotoblepas | Zircon 后期/强化行，Mud3 DAT 无 |
| — | — | 300 | Azog | 萨玛/苏美尔私服原创，Mud3 DAT 无 |
| — | — | 301 | Urukhia | 萨玛/苏美尔私服原创，Mud3 DAT 无 |
| — | — | 304 | Chubarak | 萨玛/苏美尔私服原创，Mud3 DAT 无 |
| — | — | 305 | Doom Claw | Zircon 后期/强化行，Mud3 DAT 无 |
| — | — | 307 | Zauhk Spawn | Zircon 后期/强化行，Mud3 DAT 无 |
| — | — | 308 | Shell Spliter | Zircon 后期/强化行，Mud3 DAT 无 |
| — | — | 309 | Ember Mage | Zircon 后期/强化行，Mud3 DAT 无 |
| — | — | 310 | Bobbit Worm | Zircon 后期/强化行，Mud3 DAT 无 |
| — | — | 311 | Cobalt Golum | Zircon 后期/强化行，Mud3 DAT 无 |
| — | — | 312 | Shimmer Wings | Zircon 后期/强化行，Mud3 DAT 无 |
| — | — | 313 | Vex Wings | Zircon 后期/强化行，Mud3 DAT 无 |
| — | — | 314 | Rot Wraith | Zircon 后期/强化行，Mud3 DAT 无 |
| — | — | 331 | Rot Wraith | Zircon 后期/强化行，Mud3 DAT 无 |
| — | — | 332 | Ember SpearMan | Zircon 后期/强化行，Mud3 DAT 无 |
| — | — | 333 | Kongeegen | Zircon 后期/强化行，Mud3 DAT 无 |
| — | — | 334 | Adamantoise | Zircon 后期/强化行，Mud3 DAT 无 |
| — | — | 335 | Zauhk | Zircon 后期/强化行，Mud3 DAT 无 |
| — | — | 336 | MonasteryRaisingGhost | Zircon 后期/强化行，Mud3 DAT 无 |
| — | — | 337 | MonasteryGhoul | Zircon 后期/强化行，Mud3 DAT 无 |
| — | — | 338 | MonasterySorcer | Zircon 后期/强化行，Mud3 DAT 无 |
| — | — | 339 | MonasteryVoracious | Zircon 后期/强化行，Mud3 DAT 无 |
| — | — | 341 | MonasteryDevour | Zircon 后期/强化行，Mud3 DAT 无 |
| — | — | 342 | Sumerian | 萨玛/苏美尔私服原创，Mud3 DAT 无 |
| — | — | 343 | Sacrifice | 萨玛/苏美尔私服原创，Mud3 DAT 无 |
| — | — | 344 | Enheduanna | 萨玛/苏美尔私服原创，Mud3 DAT 无 |
| — | — | 345 | Quadishtu | 萨玛/苏美尔私服原创，Mud3 DAT 无 |
| — | — | 347 | Sumerian King | 萨玛/苏美尔私服原创，Mud3 DAT 无 |
| — | — | 348 | Puabi | 萨玛/苏美尔私服原创，Mud3 DAT 无 |
| — | — | 349 | Bobbit Bobbit | Zircon 后期/强化行，Mud3 DAT 无 |
| — | — | 350 | Sabuk Flag | Zircon 后期/强化行，Mud3 DAT 无 |
| — | — | 351 | Tornado | Zircon 后期/强化行，Mud3 DAT 无 |
| — | — | 352 | Undead Soul | Zircon 后期/强化行，Mud3 DAT 无 |
| — | — | 353 | Cursed Doll | Zircon 后期/强化行，Mud3 DAT 无 |
| — | — | 354 | Terracotta1 | Zircon 后期/强化行，Mud3 DAT 无 |
| — | — | 355 | Terracotta2 | Zircon 后期/强化行，Mud3 DAT 无 |
| — | — | 356 | Terracotta3 | Zircon 后期/强化行，Mud3 DAT 无 |
| — | — | 357 | Terracotta4 | Zircon 后期/强化行，Mud3 DAT 无 |
| — | — | 358 | TerracottaSub | Zircon 后期/强化行，Mud3 DAT 无 |
| — | — | 359 | TerracottaBoss | Zircon 后期/强化行，Mud3 DAT 无 |
| — | — | 360 | Dharma Protector | Zircon 后期/强化行，Mud3 DAT 无 |
| — | — | 361 | Jungle Mammoth | Zircon 后期/强化行，Mud3 DAT 无 |
| — | — | 362 | Centaur Warrior | Zircon 后期/强化行，Mud3 DAT 无 |
| — | — | 363 | Wounded Soul Corpse | Zircon 后期/强化行，Mud3 DAT 无 |
| — | — | 364 | Xiuluo Warrior | Zircon 后期/强化行，Mud3 DAT 无 |
| — | — | 365 | Xiuluo Mage | Zircon 后期/强化行，Mud3 DAT 无 |
| — | — | 366 | Xiuluo Taoist | Zircon 后期/强化行，Mud3 DAT 无 |
| — | — | 378 | Ice Soul Warrior | 后期/强化系列，Mud3 DAT 无独立条目 |
| — | — | 380 | Fierce Monk | 后期/强化系列，Mud3 DAT 无独立条目 |
| — | — | 381 | Fierce Centipede | 后期/强化系列，Mud3 DAT 无独立条目 |
| — | — | 382 | Fierce Corpse King | 后期/强化系列，Mud3 DAT 无独立条目 |
| — | — | 383 | Fierce Demon | 后期/强化系列，Mud3 DAT 无独立条目 |
| — | — | 384 | Fierce Tree Demon | 后期/强化系列，Mud3 DAT 无独立条目 |
| — | — | 386 | Fierce Woma | 后期/强化系列，Mud3 DAT 无独立条目 |
| — | — | 387 | Fierce Mad Bull | 后期/强化系列，Mud3 DAT 无独立条目 |
| — | — | 388 | Fierce Falcon | 后期/强化系列，Mud3 DAT 无独立条目 |
| — | — | 389 | Fierce Stone Man | 后期/强化系列，Mud3 DAT 无独立条目 |
| — | — | 391 | Fierce Skeleton | 后期/强化系列，Mud3 DAT 无独立条目 |
| — | — | 392 | Fierce Demon God | 后期/强化系列，Mud3 DAT 无独立条目 |
| — | — | 397 | Dungeon Goddess 3 | Zircon 后期/强化行，Mud3 DAT 无 |
| — | — | 398 | Dungeon Goddess 4 | Zircon 后期/强化行，Mud3 DAT 无 |
| — | — | 400 | Guardian Sword Disciple | Zircon 后期/强化行，Mud3 DAT 无 |
| — | — | 401 | Guardian Spell Disciple | Zircon 后期/强化行，Mud3 DAT 无 |
| — | — | 402 | Guardian Fire Disciple | Zircon 后期/强化行，Mud3 DAT 无 |
| — | — | 405 | Otherworld Guardian | 异界/后期地图怪，Mud3 EI2.0 DAT 无 |
| — | — | 406 | Otherworld Guardian 1 | 异界/后期地图怪，Mud3 EI2.0 DAT 无 |
| — | — | 407 | Otherworld Guardian 2 | 异界/后期地图怪，Mud3 EI2.0 DAT 无 |
| — | — | 408 | Otherworld Guardian 3 | 异界/后期地图怪，Mud3 EI2.0 DAT 无 |
| — | — | 410 | Otherworld Sea General 1 | 异界/后期地图怪，Mud3 EI2.0 DAT 无 |
| — | — | 411 | Otherworld Sea General 3 | 异界/后期地图怪，Mud3 EI2.0 DAT 无 |
| — | — | 413 | Otherworld Poison Demon 1 | 异界/后期地图怪，Mud3 EI2.0 DAT 无 |
| — | — | 414 | Otherworld Poison Demon 2 | 异界/后期地图怪，Mud3 EI2.0 DAT 无 |
| — | — | 415 | Otherworld Poison Demon 3 | 异界/后期地图怪，Mud3 EI2.0 DAT 无 |
| — | — | 417 | Otherworld Ship Guard 1 | 异界/后期地图怪，Mud3 EI2.0 DAT 无 |
| — | — | 419 | Otherworld Red Mage 1 | 异界/后期地图怪，Mud3 EI2.0 DAT 无 |
| — | — | 420 | Otherworld Red Mage 2 | 异界/后期地图怪，Mud3 EI2.0 DAT 无 |
| — | — | 422 | Otherworld Tentacle Demon 1 | 异界/后期地图怪，Mud3 EI2.0 DAT 无 |
| — | — | 423 | Otherworld Tentacle Demon 2 | 异界/后期地图怪，Mud3 EI2.0 DAT 无 |
| — | — | 424 | Otherworld Tentacle Demon 3 | 异界/后期地图怪，Mud3 EI2.0 DAT 无 |
| — | — | 426 | Otherworld Light Guard 1 | 异界/后期地图怪，Mud3 EI2.0 DAT 无 |
| — | — | 427 | Otherworld Light Guard 3 | 异界/后期地图怪，Mud3 EI2.0 DAT 无 |
| — | — | 428 | Evil Spirit Soldier | Zircon 后期/强化行，Mud3 DAT 无 |
| — | — | 429 | Evil Spirit Archer | Zircon 后期/强化行，Mud3 DAT 无 |
| — | — | 430 | Evil Spirit Warrior | Zircon 后期/强化行，Mud3 DAT 无 |
| — | — | 431 | War Horse General | Zircon 后期/强化行，Mud3 DAT 无 |
| — | — | 432 | Whirlwind Demon Soldier | Zircon 后期/强化行，Mud3 DAT 无 |
| — | — | 433 | Moon River Ghost | 异界/后期地图怪，Mud3 EI2.0 DAT 无 |
| — | — | 434 | Moon River Phantom | 异界/后期地图怪，Mud3 EI2.0 DAT 无 |
| — | — | 435 | Moon River Arhat | 异界/后期地图怪，Mud3 EI2.0 DAT 无 |
| — | — | 436 | Moon River Rat Immortal | 异界/后期地图怪，Mud3 EI2.0 DAT 无 |
| — | — | 437 | Suzaku Heavenly King | 后期扩展地图怪，Mud3 EI2.0 DAT 无 |
| — | — | 438 | Tree Elf | Zircon 后期/强化行，Mud3 DAT 无 |
| — | — | 439 | Taoyuan Ice Phoenix | 后期扩展地图怪，Mud3 EI2.0 DAT 无 |
| — | — | 440 | Taoyuan Ice Flower | 后期扩展地图怪，Mud3 EI2.0 DAT 无 |
| — | — | 441 | Taoyuan Infantry | 后期扩展地图怪，Mud3 EI2.0 DAT 无 |
| — | — | 442 | Taoyuan Fire Phoenix | 后期扩展地图怪，Mud3 EI2.0 DAT 无 |
| — | — | 443 | Taoyuan Fire Flower | 后期扩展地图怪，Mud3 EI2.0 DAT 无 |
| — | — | 444 | Taoyuan Cavalry | 后期扩展地图怪，Mud3 EI2.0 DAT 无 |
| — | — | 447 | Deep Mud Man | Zircon 后期/强化行，Mud3 DAT 无 |
| — | — | 450 | Unicorn Rhino | Zircon 后期/强化行，Mud3 DAT 无 |
| — | — | 451 | Xuanwu Heavenly King | 后期扩展地图怪，Mud3 EI2.0 DAT 无 |
| — | — | 452 | Mafa General | 后期扩展地图怪，Mud3 EI2.0 DAT 无 |
| — | — | 453 | Mafa Wizard | 后期扩展地图怪，Mud3 EI2.0 DAT 无 |
| — | — | 454 | Mafa Warrior | 后期扩展地图怪，Mud3 EI2.0 DAT 无 |
| — | — | 455 | Mafa Mage | 后期扩展地图怪，Mud3 EI2.0 DAT 无 |
| — | — | 456 | Mafa Taoist | 后期扩展地图怪，Mud3 EI2.0 DAT 无 |
| — | — | 457 | Baihu Heavenly King | 后期扩展地图怪，Mud3 EI2.0 DAT 无 |
| — | — | 459 | Qin Sword Infantry | 后期扩展地图怪，Mud3 EI2.0 DAT 无 |
| — | — | 460 | Qin Spear Infantry | 后期扩展地图怪，Mud3 EI2.0 DAT 无 |
| — | — | 461 | Qin Sword Cavalry | 后期扩展地图怪，Mud3 EI2.0 DAT 无 |
| — | — | 462 | Qin Spear Cavalry | 后期扩展地图怪，Mud3 EI2.0 DAT 无 |
| — | — | 463 | Desolation Corpse | Zircon 后期/强化行，Mud3 DAT 无 |
| — | — | 464 | Heartless Guard | 后期/强化系列，Mud3 DAT 无独立条目 |
| — | — | 465 | Heartless Palace Master | 后期/强化系列，Mud3 DAT 无独立条目 |
| — | — | 466 | Heartless Red Lady | 后期/强化系列，Mud3 DAT 无独立条目 |
| — | — | 467 | Heartless Green Lady | 后期/强化系列，Mud3 DAT 无独立条目 |
| — | — | 468 | Demon Horde Cook | 异界/后期地图怪，Mud3 EI2.0 DAT 无 |
| — | — | 469 | Demon Horde Warrior | 异界/后期地图怪，Mud3 EI2.0 DAT 无 |
| — | — | 470 | Demon Horde Healer | 异界/后期地图怪，Mud3 EI2.0 DAT 无 |
| — | — | 471 | Demon Horde Overlord | 异界/后期地图怪，Mud3 EI2.0 DAT 无 |
| — | — | 473 | Evil Thunderer | Zircon 后期/强化行，Mud3 DAT 无 |
| — | — | 474 | Evil Fallen | Zircon 后期/强化行，Mud3 DAT 无 |
| — | — | 475 | Evil Avenger | Zircon 后期/强化行，Mud3 DAT 无 |
| — | — | 476 | Evil Judge | Zircon 后期/强化行，Mud3 DAT 无 |
| — | — | 477 | Evil Punisher | Zircon 后期/强化行，Mud3 DAT 无 |
| — | — | 478 | Evil Soul Sealer | Zircon 后期/强化行，Mud3 DAT 无 |
| — | — | 479 | Zuan Ka Tree | Zircon 后期/强化行，Mud3 DAT 无 |
| — | — | 480 | Thunder Demon Soldier | Zircon 后期/强化行，Mud3 DAT 无 |
| — | — | 481 | Frost Stone Beast | Zircon 后期/强化行，Mud3 DAT 无 |
| — | — | 482 | Qinglong Heavenly King | 后期扩展地图怪，Mud3 EI2.0 DAT 无 |
| — | — | 483 | Otherworld Light Guard 2 | 异界/后期地图怪，Mud3 EI2.0 DAT 无 |
