# Zircon 相对 EI 传奇3.0 的版本更新

> 日期：2026-08-11
> 分析基于：Zircon（LOMCN 开源，现代重构版）vs EI 3.0 原版（2003 韩国原版 + 英雄杀服务端）
> 当前部署：EI 地图 + EI 怪物/装备数据 + Zircon 服务器引擎

## 1. 版本关系

| 项目 | EI 3.0 原版 | Zircon（当前部署） |
|------|------------|-------------------|
| 时间 | 2003 韩国原版 / 2011 国内服务端 | 2017-2026 开源重构（LOMCN） |
| 引擎 | Delphi 客户端 + 文本配置服务端 | C# .NET + Godot 4.6 客户端 |
| 地图 | 544 张（已迁移） | 原 258 张 → 已替换为 EI 544 张 |
| 数据 | 文本文件（.txt/.gen/.dat） | MirDB 二进制（System.db） |

## 2. Zircon 相对 EI 的核心更新

### 2.1 引擎与架构（最大差异）

| 更新 | EI | Zircon |
|------|----|--------|
| 客户端 | WinForms/Win32（Delphi） | **Godot 4.6** 跨平台 |
| 服务器 | 文本配置 | **.NET 10** + 反射加载 |
| 数据库 | 文本文件 | **MirDB 二进制**（53 表） |
| 图形 | 2D 贴图 | **Godot 渲染**（光影/特效升级） |
| 平台 | Windows only | **Linux/macOS/Windows** |

### 2.2 新增游戏系统（代码级）

| 系统 | 说明 | EI 有无 |
|------|------|--------|
| **自动寻路**（AutoPath） | 点击地图自动寻路 | ❌ 无 |
| **自动战斗**（AutoPath + 脚本） | 挂机刷怪 | ❌ 无 |
| **伙伴/宠物系统**（Companion） | 可收集伙伴、装备伙伴 | ❌ 无 |
| **钓鱼系统**（Fishing） | 钓竿/鱼饵/渔具套装 | ❌ 无 |
| **强化/精炼**（Refine/Gem） | 装备强化、宝石镶嵌 | ❌ 无 |
| **套装系统**（SetInfo） | 装备套装属性 | ❌ 无 |
| **声望系统**（Fame） | 声望称号 | ❌ 无 |
| **里程碑系统**（Milestone） | 成就/里程碑任务 | ❌ 无 |
| **副本/地下城**（Dungeon/Instance） | 动态副本 | 部分 |
| **攻城战**（Conquest/Sabuk） | 沙巴克争夺 | 有（简化） |

### 2.3 新增地图内容（Zircon 独有，已删除）

Zircon 原版有 199 张 EI 没有的地图，代表 Zircon 新增内容（本次迁移已删除，以 EI 为准）：

| 地图系列 | 规模 | 内容推测 |
|---------|------|---------|
| 00.map | 1360×1500 | 巨型新城镇（全服最大） |
| 15/16/17.map | 800×800 | 大型新区域 |
| D3005 + 4 个变体 | 400×400 + 80×80 | 新 Boss 区域 |
| D3400/D3400_1 | 600×600 | 大型新地牢 |
| D3901-D3906 | 400×400 | 新系列地牢 |
| D4000-D4003 | 400×400 | 新系列地牢 |
| D4101/D4102 | 200×200 | 新 Boss 区 |
| ID3/ID7/ID9 系列 | 100-400 | 副本/活动地图 |
| E01/E02/E11/E12 | 300×100-200 | 活动地图 |
| ithuejingot | 320×320 | 专用 Boss 图 |
| er51_ice | 300×300 | 冰主题活动图 |
| GM/GM_001 | 20-400 | 管理地图 |

### 2.4 新增怪物（Zircon 独有 Boss）

Zircon 引入了**两河文明/苏美尔主题**的独有 Boss（EI 完全没有）：

| Boss | 等级 | 主题 |
|------|------|------|
| Sumerian / Sumerian King | Lv250 | 苏美尔王 |
| Enheduanna | Lv250 | 苏美尔女祭司 |
| Puabi | Lv250 | 苏美尔王后 |
| Quadishtu | Lv250 | 圣娼 |
| Urukhia | Lv250 | 乌鲁克 |
| Chiwoo General Of East/West | Lv250 | 东方/西方将军 |
| Goru Archer/General/Spearman | Lv250 | 哥鲁军团 |
| Zauhk / Zauhk Spawn | Lv250 | 扎乌克 |
| Azog | Lv250 | 阿佐格 |
| Yumgon General/Witch | Lv250 | 云贡 |
| Terracotta1-4/Boss/Sub | Lv250 | 兵马俑 |
| Odyn / OdynElemental / OdynSin | Lv250 | 北欧奥丁系列 |
| Frost Lord Hwa / Emperor Sa'Woo / Lord Ji'Nae | Lv250 | 冰霜领主/皇帝 |
| Doom Claw | **Lv500** | 全服最强 |

### 2.5 新增装备（Zircon 独有 Elite）

Zircon 的 Elite 装备（61 件）多为英文原创命名，对应新 Boss 掉落：

| 装备 | 对应 Boss 主题 |
|------|---------------|
| Nemesis The Blade of Betrayal | 复仇女神 |
| Valkyrie Blade of Reckoning | 瓦尔基里 |
| StormCaller The Sky Blade | 风暴召唤 |
| Celestia Fan of the Heavens | 天界扇 |
| Chaos The Spiral Death | 混沌 |
| Deluge Winter's Might | 寒冬 |
| Lifebinder The Ancient Healer | 生命绑定者 |
| Sword Of Abyss / Glaive Of Doom | 深渊/末日 |

## 3. 本次迁移的取舍

### 3.1 保留的 Zircon 更新（引擎层）
- ✅ Godot 客户端、.NET 服务器
- ✅ 自动寻路/自动战斗
- ✅ 伙伴/钓鱼/强化/声望/里程碑
- ✅ 攻城战

### 3.2 删除的 Zircon 内容（数据层，以 EI 为准）
- ❌ 199 张 Zircon 独有地图
- ❌ Zircon 独有 Boss（苏美尔/奥丁/兵马俑系列）——**但怪物定义仍保留在 DB（309 种）**
- ❌ Zircon 独有地图上的刷怪/NPC/传送门

### 3.3 保留的 Zircon 怪物（DB 中仍在）
- 309 种怪物全部保留在 MonsterInfo 表
- 但只有 EI 刷怪配置引用的怪物会实际出现
- Zircon 独有 Boss 的掉落配置（DropInfo）仍在 DB，只是没有对应刷怪点

## 4. 结论

**Zircon 相对 EI 的更新分两层：**

1. **引擎/系统层（保留）**：Godot 客户端、自动寻路、伙伴、钓鱼、强化、声望、攻城战——这些是 Zircon 的核心价值，本次迁移完全保留。

2. **内容层（以 EI 为准替换）**：地图、NPC、刷怪、传送门、安全区全部换成 EI 原版。Zircon 独有的 199 张地图和 30+ 独有 Boss 被删除（用户要求以 EI 为准）。

3. **潜在恢复空间**：如果以后想加回 Zircon 独有内容，DB 里的 MonsterInfo（309 种含 Zircon 独有 Boss）和 DropInfo（10382 条）仍在，只需要重新部署对应地图和刷怪点即可。
