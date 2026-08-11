# EI 地图下的等级与装备生态分析

> 日期：2026-08-11
> 分析基于：当前 System.db（544 张 EI 地图迁移后）+ 怪物/装备/掉落/经验曲线数据

## 1. 结论速览

| 项目 | 当前值 | 数据来源 |
|------|--------|---------|
| **人物最高等级** | **10 级（当前配置）** | `Server.ini:81 MaxLevel=10` |
| **可配置上限** | **90 级**（BaseStat 有 4 职业 × 90 级完整数据） | System.db BaseStat 表 |
| **经验曲线上限** | **100 级**（90 级后经验需求爆炸） | `Globals.cs ExperienceList`（100 项） |
| **最高等级怪物** | **Lv500**（Doom Claw，1500 万经验） | MonsterInfo |
| **装备总量** | 579 件（武器 124 / 铠甲 104 / 戒指 99 等） | ItemInfo |
| **装备品质** | Common 226 / Superior 293 / **Elite 61** | ItemInfo.Rarity |
| **Elite 装备掉落来源** | 68 种怪（全为 Lv250/500 Boss） | DropInfo |

---

## 2. 等级上限分析

### 2.1 当前实际配置

```
Server.ini:81:  MaxLevel=10
Config.cs:103:  public static int MaxLevel { get; set; } = 10;
```

**当前服务器最高 10 级**——玩家练到 10 级就无法再升级（`PlayerObject.cs:2027` 检查 `Level >= Config.MaxLevel`）。

### 2.2 数据支持的上限

| 数据 | 上限 | 说明 |
|------|------|------|
| BaseStat（属性表） | **90 级** | 4 职业（Warrior/Mage/Taoist/Assassin）× 90 级完整 HP/MP/攻防数据 |
| ExperienceList（经验曲线） | **100 级** | 索引 0-99，90 级后经验需求暴增（90级=144万亿，99级=200万亿） |
| 怪物等级 | **500 级** | Doom Claw Lv500（1500 万经验） |

**结论：数据设计上限是 90 级**（BaseStat 有完整属性），经验曲线预留到 100 级。当前 MaxLevel=10 是 Zircon 服务器的保守配置，**可以调高**。

### 2.3 升级经验需求（关键节点）

| 等级 | 所需经验 | 说明 |
|------|---------|------|
| 1→2 | 100 | 新手 |
| 10→11 | 6000 | 当前上限处 |
| 20→21 | 140000 | |
| 30→31 | 2000000 | |
| 40→41 | 4000000 | |
| 50→51 | 60000000 | |
| 60→61 | 400000000 | |
| 70→71 | 900000000000 | 90 级后爆炸增长 |
| 80→81 | 17000000000000 | |
| 90→91 | 144000000000000 | |

---

## 3. 怪物等级生态（当前 DB 刷怪分布）

### 3.1 刷怪点按怪物等级

| 怪物等级段 | 刷怪点数 | 对应地图类型 |
|-----------|---------|-------------|
| Lv5-10 | 113 | 新手村周边（比奇城/银杏山谷） |
| Lv13-20 | 170 | 初级洞穴（比奇洞穴/半兽人） |
| Lv25-30 | 406 | 中级洞穴（蚂蚁洞/天然洞穴） |
| Lv35-40 | 128 | 高级洞穴（祖玛/沃玛） |
| Lv45-55 | 233 | 精英区域（赤月/诺玛） |
| Lv63-75 | 116 | 高级地牢（诺玛遗址/真天宫） |
| Lv80-88 | 187 | 顶级区域（冰原/Sama） |
| Lv100 | 19 | 终极区域（Oma Mage/Imp） |
| **Lv250** | **439** | **Boss 集中营（全部 68 种 Elite 掉落怪）** |
| Lv500 | — | Doom Claw（终极 Boss） |

### 3.2 刷怪量最大的怪

| 怪物 | 等级 | 刷怪点 |
|------|------|--------|
| （索引60） | ？ | 226 点 |
| （索引51） | ？ | 81 点 |
| Cave Maggot | 20 | 77 点 |
| （索引293） | ？ | 54 点 |

---

## 4. 装备生态

### 4.1 装备品质分层

| 品质 | 数量 | 代表装备 |
|------|------|---------|
| **Common**（普通） | 226 | Wood Sword、Trainee's Glaive、各级药水 |
| **Superior**（精良） | 293 | Amulet Of Chaos、Aged Gold Band Of Mystic、Ambitious 系列 |
| **Elite**（精英） | **61** | Sword Of Abyss、Glaive Of Doom、Blade Of The Dragon Lord、StormCaller、Valkyrie Blade Of Reckoning、Helmet Of The War God、Crown Of Feral Lord |

### 4.2 Elite 装备顶级清单（各部位）

| 部位 | 顶级装备 |
|------|---------|
| 武器 | Nemesis The Blade of Betrayal、Valkyrie Blade of Reckoning、StormCaller The Sky Blade、Blade Of The Dragon Lord、Apocalypse、Phoenix Glaive Of Havoc |
| 铠甲 | FootBall Kit |
| 头盔 | Helmet Of The War God、Crown Of Feral Lord、Crown Of Dark Crusader |
| 项链 | Amulet Of The Dragon Lord、Pendant Of Dragon Abyss |
| 戒指 | Loop Of The Dragon Lord、Hero's Band Of Supremacy、Seal Of Titans、Loop Of Invisibility |
| 手镯 | Armband Of The Dragon Lord、Holy Bracer Of Grace |
| 鞋子 | Greaves Of The Dragon Lord、Boots Of Crimson Steed、Shadow Chaser |

### 4.3 Elite 装备掉落来源（68 种怪，全为 Boss）

| 怪物 | 等级 | Elite 掉落条数 |
|------|------|---------------|
| Bobbit Bobbit | Lv250 | 47 |
| Queen Of Dawn | Lv250 | 13 |
| Lord Ji'Nae | Lv250 | 11 |
| Arch Lich Taedu | Lv250 | 11 |
| Razor Tusk | Lv250 | 11 |
| Uma King | Lv250 | 11 |
| Sumerian King | Lv250 | 9 |
| **Doom Claw** | **Lv500** | **8** |
| Dragon Lord Jin'Ryung | Lv250 | 6 |

---

## 5. 等级 → 装备 生态链

### 5.1 当前（MaxLevel=10）

| 阶段 | 等级 | 能打的怪 | 能掉的装备 |
|------|------|---------|-----------|
| 新手 | 1-5 | 鸡/鹿/狼（Lv5-9） | Common 木剑 |
| 成长 | 5-10 | 半兽人/骷髅（Lv10-18） | Common 铜器 |
| **封顶** | **10** | — | — |

**10 级封顶意味着：玩家只能体验新手区，所有 Superior/Elite 装备（579 件）和 Boss 内容完全无法触及。**

### 5.2 若调整到 90 级（数据支持的完整生态）

| 阶段 | 等级 | 地图 | 怪物 | 装备 |
|------|------|------|------|------|
| 新手 | 1-10 | 比奇城/银杏山谷 | Lv5-10 | Common |
| 初级 | 10-20 | 比奇洞穴/半兽人洞穴 | Lv13-20 | Common 高级 |
| 中级 | 20-30 | 蚂蚁洞/天然洞穴 | Lv25-30 | Superior 初级 |
| 高级 | 30-45 | 沃玛/祖玛 | Lv35-45 | Superior |
| 精英 | 45-60 | 赤月/潘夜/诺玛 | Lv45-55 | Superior 高级 |
| 顶级 | 60-80 | 诺玛遗址/真天宫/冰原 | Lv63-88 | Superior 顶级 |
| 终极 | 80-90 | 神舰/终极区域 | Lv100 | Elite 部分 |
| Boss | 90+ | Boss 集中营 | Lv250/500 | **全部 Elite** |

---

## 6. 结论与建议

1. **当前等级上限 10 级严重限制内容**：玩家只能玩新手区，579 件装备、68 种 Boss、Lv250/500 怪物全部不可达。

2. **数据完整支持到 90 级**：BaseStat 4 职业 × 90 级属性齐全，经验曲线到 100 级。

3. **装备生态按等级递进**：
   - Lv1-20：Common 装备
   - Lv20-60：Superior 装备（293 件）
   - Lv60-90：Superior 顶级 + Elite 入门
   - Lv90+：Elite 顶级（61 件，Boss 掉落）

4. **调整建议**：如要完整体验 EI 地图内容，应将 `Server.ini MaxLevel` 从 10 调高（如 50-90 级），让玩家能逐步进入高级地图挑战 Boss 获取 Elite 装备。

5. **注意**：调整 MaxLevel 前需确认：
   - BaseStat 90 级属性是否平衡
   - 怪物 Lv250/500 的血量/攻击是否适合玩家
   - 经验曲线 60 级后需求暴增，升级节奏是否合理

---

## 7. MaxLevel 调整记录（2026-08-11）

### 7.1 调整内容

| 项 | 修改前 | 修改后 |
|----|--------|--------|
| `Server.ini MaxLevel` | 10 | **90** |
| 备份 | — | `Debug/ServerCore/Server.ini.bak` |
| 生效 | — | 重启服务器后生效（Network Started 05:30） |

### 7.2 调整后可达内容

MaxLevel=90 后，玩家可以完整探索 EI 版本的全部内容：

| 等级段 | 地图 | 怪物 | 装备 |
|--------|------|------|------|
| 1-10 | 比奇城/银杏山谷 | Lv5-10 | Common |
| 10-20 | 比奇洞穴/半兽人 | Lv13-20 | Common 高级 |
| 20-30 | 蚂蚁洞/天然洞穴 | Lv25-30 | Superior |
| 30-45 | 沃玛/祖玛 | Lv35-45 | Superior 高级 |
| 45-60 | 赤月/潘夜/诺玛 | Lv45-55 | Superior 顶级 |
| 60-80 | 真天宫/冰原 | Lv63-88 | Elite 入门 |
| 80-90 | 神舰/蚂蚁洞深层 | Lv100+ | Elite 顶级 |
| 90（封顶） | Boss 集中营 | Lv250/500 | **全部 Elite（61件）** |

### 7.3 终极区域确认（EI 版本内容上限）

EI 版本的最高内容：

| 区域 | 地图 | 终极 Boss |
|------|------|----------|
| **神舰** | D900-D903 | Tainted Terror / Netherworld Gate |
| **蚂蚁洞深层** | D8001-D8204 | Ant Commander / Iron Lance |
| **赤月恶魔巢穴** | D10162 | Red Moon The Fallen（赤月恶魔） |
| **祖玛神殿** | D505/D507x | Zuma King |
| **石阁** | D701-D717 | Skeleton Enforcer |
| **全服最强** | 终极区域 | **Doom Claw（Lv500）** |

**确认：EI 版本最高内容到神舰 + 蚂蚁洞深层 + 赤月恶魔，全服最强 Boss 是 Doom Claw（Lv500）。**
