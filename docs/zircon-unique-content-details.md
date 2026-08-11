# Zircon 独有内容详解（199 张地图 + 30+ Boss）

> 日期：2026-08-11
> 这些是 Zircon（LOMCN 现代版）相对 EI 3.0 原版**新增的内容**，本次迁移已删除（以 EI 为准）。
> 但怪物定义（MonsterInfo 309 种）和掉落配置（DropInfo 10382 条）仍保留在 DB，可随时恢复。

---

## 1. 独有地图内容详解

### 1.1 巨型城镇区（00/15/16/17/18/19）

| 地图 | 尺寸 | 内容 | 怪物 |
|------|------|------|------|
| **00.map** | 1360×1500 | 全服最大巨型城镇 | — |
| **15.map** | 800×800 | 大型新城镇 | — |
| **16.map** | 800×800 | 高级练级区 | Gang Spider、Venom Spider、Ettin、Evil Snake、**Urukhia**、Rot Wraith、Oma Mage、Centurion |
| **17.map** | 800×800 | 高级练级区 | Oma Mage、Evil Snake、Gang Spider、Venom Spider、Ettin、Centurion |
| **18.map** | 400×400 | 精英区 | Bobbit Worm、Evil Snake、Vex Wings、**Azog**、**Urukhia** |
| **19.map** | 250×250 | 精英区 | Imp、Ettin、Centurion、Rot Wraith、Cotoblepas、Oma Mage |

### 1.2 D3005 系列（元素守护神殿）

| 地图 | 尺寸 | 内容 |
|------|------|------|
| D3005 | 400×400 | **四大元素守护者**：Sama Fire/Ice/Lightning/Wind Guardian |
| D3005_BH/CR/HM/JJ | 80×80 | 4 个关联小图 |

### 1.3 D3400 系列（万兽之王区域）

| 地图 | 尺寸 | 怪物 |
|------|------|------|
| D3400 | 600×600 | Wild Monkey、Wild Fanatic、Wild Elephant、Tiger、Young Tiger |
| D3400_1 | 600×600 | 关联图 |

### 1.4 D3900 系列（D3901-D3906）

6 张 400×400 地图，**无刷怪点**——推测为活动/事件预留图或过渡图。

### 1.5 D4000 系列（沙漠神殿）

| 地图 | 尺寸 | 怪物 |
|------|------|------|
| D4000 | 400×400 | Salamander、Crystal Golem、Dust Devil |
| D4001 | 400×400 | + Bloody Mole、Twin Tail Scorpion |
| D4002 | 400×200 | + Sand Golem |
| D4003 | 200×200 | Crystal Golem、Dust Devil、Twin Tail Scorpion、Oma Mage |
| D4101/D4102 | 200×200 | 精英 Boss 区：Imp、Ettin、Centurion、Rot Wraith、Cotoblepas、Oma Mage |

### 1.6 ID7 系列（虫翼巢穴 — Bobbit 线）

| 地图 | 尺寸 | 怪物 | 进度 |
|------|------|------|------|
| ID7_000 | 100×100 | Vex Wings | 入口 |
| ID7_001 | 200×200 | Vex Wings、Shimmer Wings、Bobbit Worm | 1层 |
| ID7_002 | 300×300 | + Cobalt Golum、**Bobbit Bobbit** | 2层 |
| ID7_003 | 300×300 | + Ember Mage、Ember SpearMan、**Kongeegen** | 3层 |
| ID7_004 | 150×150 | **Zauhk、Zauhk Spawn**、Bobbit Bobbit | Boss层 |

### 1.7 ID9 系列（苏美尔神殿 — 终极内容）

| 地图 | 尺寸 | 怪物 | 进度 |
|------|------|------|------|
| ID9_00 | 400×400 | MonasteryRaisingGhost、MonasteryGhoul、MonasterySorcer、MonasteryVoracious、MonasteryDevour | 入口 |
| ID9_01 | 300×300 | **Puabi、Quadishtu、Sumerian** | 内殿 |
| ID9_02 | 200×200 | **Enheduanna、Quadishtu、Sumerian King、Puabi** | 终极Boss层 |

### 1.8 活动/特殊地图

| 地图 | 尺寸 | 说明 |
|------|------|------|
| E01/E02 | 300×100 | 活动图 |
| E11/E12 | 300×200 | 活动图 |
| er51_ice | 300×300 | 冰原活动图（Frost Yeti、Elder White Tiger） |
| ithuejingot | 320×320 | 专属 Boss 图 |
| GM/GM_001 | 20-400 | 管理地图 |

---

## 2. 独有 Boss 详解

### 2.1 苏美尔/两河文明主题（ID9 系列）

| Boss | 等级 | 经验 | 说明 |
|------|------|------|------|
| **Sumerian King** | Lv250 | 5000万 | 苏美尔王，终极 Boss |
| Enheduanna | Lv250 | 324万 | 苏美尔女祭司/诗人 |
| Puabi | Lv250 | 324万 | 苏美尔王后（乌尔王朝） |
| Quadishtu | Lv250 | 324万 | 圣娼（两河宗教人物） |
| Urukhia | Lv250 | 4000万 | 乌鲁克（吉尔伽美什之城） |

### 2.2 神话/史诗主题

| Boss | 等级 | 经验 | 说明 |
|------|------|------|------|
| **Doom Claw** | **Lv500** | 1500万 | 全服最强 Boss |
| Azog | Lv250 | 4000万 | 阿佐格（矮人王） |
| Zauhk | Lv250 | 900万 | 虫王 |
| Bobbit Bobbit | Lv250 | 3360万 | 虫后（最高 Elite 掉率 47 条） |
| Kongeegen | Lv250 | 390万 | 丹麦王室之剑（北欧） |
| Chiwoo General Of East/West | Lv250 | 81.9万 | 支无（韩国神话）将军 |
| Frost Lord Hwa | Lv250 | 185万 | 冰霜领主 |
| Emperor Sa'Woo | Lv250 | 58.5万 | 萨武皇帝 |
| Lord Ji'Nae | Lv250 | 29万 | 智奈领主 |
| Elder White Tiger | Lv250 | 100万 | 白虎尊者 |

### 2.3 兵马俑主题（Lv90 系列）

| Boss | 等级 | 经验 |
|------|------|------|
| Terracotta1-4 | Lv90 | — |
| **TerracottaBoss** | Lv90 | 1000 |
| TerracottaSub | Lv90 | — |

### 2.4 中高级精英怪

| 怪物 | 等级 | 经验 |
|------|------|------|
| Goru General | Lv80 | 11.7万 |
| Yumgon General | Lv80 | 8.2万 |
| Sama Fire Guardian | Lv88 | 52.5万 |
| MonasteryDevour | Lv79 | 220万 |
| Wild Elephant | Lv60 | 12万 |

---

## 3. 内容结构分析

### 3.1 Zircon 新增内容的特点

1. **主题创新**：苏美尔文明（Sumerian/Puabi/Enheduanna）、北欧神话（Kongeegen/Azog）、韩国神话（Chiwoo）、兵马俑（Terracotta）——远超 EI 的东方玄幻主题。

2. **Boss 设计**：Lv500 Doom Claw 是 Zircon 独有的终极挑战（EI 最高 Lv250）。

3. **地图结构**：ID7/ID9 系列采用**渐进式多层副本**（入口→1层→2层→3层→Boss层），比 EI 传统地图更有层次。

4. **精英怪物**：Goru/Yumgon/Sama/Monastery 系列填补了 Lv60-90 的中高端空白。

### 3.2 为什么删除

按用户要求以 EI 为准。删除的是：
- 199 张 Zircon 独有地图文件
- 这些地图上的刷怪/NPC/传送门/安全区配置

**保留的**：
- MonsterInfo（309 种，含所有 Zircon 独有 Boss 定义）
- DropInfo（10382 条掉落配置）
- 武器/装备（1078 件，含 Zircon 独有 Elite）

### 3.3 恢复可能性

如果以后想加回 Zircon 独有内容，只需：
1. 复制回 .map 文件（在备份目录 `/home/tetsuya/NAS/TMP/zircon-backup-20260811-095139/Map/`）
2. 用 DbMigrationTool 重新创建 MapInfo + MapRegion + RespawnInfo
3. Boss 定义和掉落配置都还在 DB 里

---

## 4. 总结

Zircon 相对 EI 新增的内容主要是**西方神话主题的 Boss 线和多层副本结构**：

```
EI 原版：   东方玄幻（沃玛/祖玛/赤月/神舰）→ Lv250 封顶
Zircon 新增：苏美尔（Sumerian King）/北欧（Azog/Kongeegen）
           /虫族（Bobbit/Zauhk）/兵马俑（Terracotta）
           → Doom Claw Lv500 终极挑战
```

内容质量上 Zircon 的 Boss 设计更现代（多层副本、主题鲜明），但 EI 的地图是经典原版。当前部署选择**EI 地图 + EI 怪物生态**，Zircon 独有内容已备份可随时恢复。
