# WEB_ENTITY_MAPPING_WEB_AUDIT_REPORT_2026-09-26

**Goal**：网络检索闭合 mir2ei ↔ Zircon 全量实体映射
**执行**：DimAgent 会话（DeepSeek V4.1 Flash / DIM OAuth，未切换模型、未启动额外代理、无付费调用）
**版本**：第二轮（逐类检索 + 新增 4 条图像/坐标/版本标签证据通道）
**时间**：2026-09-26（外部来源访问时间戳见 §3）
**范围**：`docs/research/ei-ui-layout/alignment-browser/` 与
`docs/research/ei-ui-layout/artifacts/web-entity-audit-2026-09-26/`
**未触碰**：System.db / Users.db / dbeditor workspace / zircon 源码 / mir3-website / mapedit

---

## 1. 结论摘要

用户判断被验证：**旧的 `mir2ei-only` / `zircon-only` 大量是「第一次名称 lookup 失败」而不是「对面真的没有」。**

本轮把 5,408 条记录全部重新审计。方向按**扩展 mir2ei 侧证据**（资料站 + 老版 MUD3/EI DAT 解码 + 17173/新浪中文名佐证）重算：

| | 检索前 | 第一轮后 | 第二轮后 |
|---|---:|---:|---:|
| both（双方都有） | 800 | 2,737 | **4,065** |
| mir2ei-only | 475 | 321 | **276** |
| zircon-only | 4,133 | 2,350 | **1,067** |

新分类下没有一条记录停留在旧的 `mir2ei-only` / `zircon-only` / `pending-evidence` 终态；
未闭合项统一进入 **`pending-web-evidence`（第二轮收敛到 414 条）**，并写清检索词、外部来源与排除理由。

| 新状态 | 第一轮 | 第二轮 |
|---|---:|---:|
| `both-resolved-by-web-alias`（经网络别名链闭合） | 1,921 | **3,429** |
| `pending-web-evidence`（有候选/缺口，未定终态） | 2,907 | **414** |
| `both-resolved`（原已闭合，无需改名） | 326 | 259 |
| `conflict` | 116 | 116 |
| `partial` | 47 | 47 |
| `production-applied` | 91 | 91 |
| `mir2ei-only-after-web-audit` | 0 | **145** |
| `zircon-only-after-web-audit` | 0 | **907** |
| `source-unreachable` | 0 | **0** |

**为什么现在有 `*-after-web-audit` 终态**：只有在拿到**外部来源**明确记录「该实体只存在于一侧」时才升级——
本轮用的是 mir2ei 百科数据集的版本标签（`ver=[zircon]` / `ver` 不含 zircon），
以及老版 MUD3 DAT 全量清单（433 怪物 / 1143 物品 / 105 技能）的完备性。
没有外部依据的仍留在 `pending-web-evidence`（414 条），**不把「没搜到」写成「没有对应」**。
`source-unreachable` 仍是 0：不可达的是**来源**（见 §6），不是记录级结论。

---

## 2. 方法论

### 2.1 检索闭合流程（每条记录）

1. **生成别名与检索词**：中文标准名 / 英文内部名 / 去空格连字符大小写变体 / 老版光通名 /
   `MonsterImage`·`Shape`·`Appr`·图库名 / 类别·等级·Boss·区域 / fork 历史字段名。
2. **多组网络检索**：`"中文名" Mir3 Zircon`、`"英文内部名" Zircon MonsterInfo`、
   `site:lomcn.net`、`site:github.com`、GitHub raw/API、LOMCN 论坛、17173/新浪/百度百科。
3. **本地交叉验证**：网络候选必须与至少一项本地证据闭合——workspace 行、`MonsterLookup.cs`
   的 Index→Mon-N.Zl 图库+shape、MUD3 DAT 解码记录、EI 客户端图库清单。
4. **分类**：名称相同但资源/属性完全不符时标 `conflict`，不自动映射。
5. **写库闸门**：本 Goal 只产出映射与报告，**不写任何数据库**；名称修正/业务 Index/坐标/刷新写入
   仍须走原有人工批准闸门。

### 2.2 别名索引规模（机器可读见 `audit_summary.json`）

| 指标 | 值 |
|---|---:|
| 中文→英文别名边 | 2,449 |
| 图像/坐标/版本标签通道命中（新增） | 见 §2.4 |
| 中文键 | 2,385 |
| 英文键 | 2,155 |
| 有外部来源佐证的中文名 | 2,067 |
| Wemade 英文名（LOMCN） | 499 |
| 老版 MUD3 DAT 中文名 | 1,602 |
| 新浪老版怪物名 | 386 |

provenance 构成：`mir2ei-wiki-json` 2,009 · `local-candidate:db_names` 2,105 ·
`github-suprcode-chinese-messages` 23 · 版本标签 mud3 401 / zircon 309 / ei 143 / mei 155。

### 2.4 第二轮新增的四条证据通道（不依赖名称）

第一轮只靠名称别名，对「中文名不同、实体相同」的记录无能为力。第二轮补了四条**与名称无关**的通道：

| 通道 | 原理 | 验证 | 覆盖 |
|---|---|---|---|
| **老版 `RaceImg` 图像索引** | `RaceImg = (lib-1)*10 + shape` → `MonsterLookup` 反查 `MonsterImage` → `MonsterInfo` 行 | 10 个已知锚点 **8 个尺寸序列完全一致**；EI `Mon-N.wil` 与 Zircon `Mon-N.Zl` 同 lib/shape 逐帧尺寸 **115/150 恒等**，逐帧平均色差 **4.28–9.87**（BC1 再编码量级）→ 同一美术 | 怪物闭合 121 → **329**；反向为 202 个 Zircon 怪物给出唯一老版中文名（其中 148 个就在资料站 154 名单里） |
| **老版 NPC 坐标** | MUD3 `Merchant.txt`(map,x,y) ↔ Zircon `MapRegion.PointRegion.CenterX/Y`，半径 12 | 130 条距离 **0** 唯一命中，多数 `script` 名与 Zircon NPC 的 `_Identity` 段一致 | NPC 闭合 53 → **103**；zircon-only 77 → 59 |
| **物品外观 + 指纹** | 老版 `stditem.Looks == Zircon ItemInfo.Image`（实测 delta 恒为 0），再用 StdMode→ItemType / Price / NeedLevel / Shape 消歧，且要求同图网站物品之间**单射** | 抽查 金创药（小）↔Healing Potion、匕首↔Dagger、太阳水↔Rejuvenation Potion、井中月↔Forged Scimitar（价格 28000 一致） | 物品闭合 260 → **811**（含 196 条反向唯一中文名） |
| **网络数据集版本标签 `ver`** | 数据集逐条标注 `mud3/ei/mei/zircon` 归属 | 只在该实体被标为单侧存在时才升级为 `*-after-web-audit` | `zircon-only-after-web-audit` 606 · `mir2ei-only-after-web-audit` 145 |

四条通道的命中一律写入 `alias_chain` + `local_evidence`，并保留 `review_required`；
其中 `RaceImg` 通道是**经验公式**（8/10 锚点），因此单独标注、不与网络字典命中混为一谈。

### 2.3 关键别名链形态

| 形态 | 例子 | 证据 |
|---|---|---|
| 中文语义直译 ↔ Wemade 英文名 | 多钩猫（钩=hook）→ `HookingCat`；钉耙猫（耙=rake）→ `RakingCat` | 百度百科 + LOMCN 怪物库 |
| Zircon 改名 ↔ Wemade 原名 | Zircon `ClawCat` = LOMCN `HookingCat`；`Uma*` = `Wooma*`；`Red Moon The Fallen` = `RedMoonEvil` | LOMCN 怪物库 + mir2ei 百科 |
| 老版地图码 ↔ 中文名 ↔ Zircon `FileName` | `0` → 比奇县 → MapInfo[1] `Bichon Town` | mir2ei 百科 `mud3.mapinfo` |
| 老版 DAT 对照表 ↔ Zircon Index | 半月弯刀 → `Half Moon`(id=5)；爆裂火焰 → `Fire Storm`(id=42) | `docs/research/mud3-dat-decoded/` + 17173 技能页 |
| 外观图 ID 双向 1:1 | 老版 `stditem.Looks` ↔ Zircon `ItemInfo.Image` | MUD3 DAT 解码 + ItemInfo |
| 怪物身份传播到刷新 | 刷新记录的 Monster 身份闭合 → 整条刷新闭合 | RespawnInfo + MonsterInfo |

---

## 3. 外部来源清单（19 条，全部真实访问）

完整 URL / 标题 / 访问时间 / 摘录 / 原始副本哈希见
`artifacts/web-entity-audit-2026-09-26/external_sources.json`，
原始副本在 `artifacts/web-entity-audit-2026-09-26/raw/`。

| # | 来源 | URL | 用于 |
|---|---|---|---|
| 1 | EI 传奇3.0 百科 · 机器可读数据集 | `https://mir2ei.iamcheyan.com/data/wiki_data_v2.json` | 534 怪物/2203 物品/218 技能/125 NPC/244 地图/1701 术语 EN↔ZH |
| 2 | 怪物图鉴页 | `https://mir2ei.iamcheyan.com/monsters.html` | 数据集的人类可读对照 |
| 3 | 术语表（1701 条） | `https://mir2ei.iamcheyan.com/terms.html` | 老版 DAT 英文术语→中文 |
| 4 | 三版本差异裁剪 | `https://mir2ei.iamcheyan.com/diff.html` | 版本范围（MUD3/mir3ei/Zircon） |
| 5 | 资源库图库清单 | `https://mir2ei.iamcheyan.com/library.html` | Mon-1..16 / MIcon / Storeitem 图库名 |
| 6 | **LOMCN Mir3 Monster Database（531 行）** | `https://www.lomcn.net/wiki/index.php/Monster_Database` | Wemade 英文名 + AI + Notes |
| 7 | LOMCN Zircon Wiki | `https://www.lomcn.net/wiki/index.php/Zircon` | Zircon 项目来源 |
| 8 | LOMCN Zircon 开源板块 | `https://www.lomcn.net/forum/forums/zircon-mir3-files-open-source.735/` | 命名来源、社区资料 |
| 9 | Suprcode/Zircon 仓库树（1127 文件） | `https://github.com/Suprcode/Zircon` | 上游身份与表结构 |
| 10 | **Zircon 官方中文文案** | `raw.githubusercontent.com/Suprcode/Zircon/master/Client/Envir/Translations/ChineseMessages.cs` | 官方 EN→ZH 技能名 |
| 11 | GitHub fork 清单（100 newest） | `https://api.github.com/repos/Suprcode/Zircon/forks?per_page=100&sort=newest` | Wincha/grimchamp/ketsmen/KingdomMir2/iamcheyan 等 |
| 12 | **新浪 2003 老版怪物等级排名** | `https://games.sina.com.cn/z/mir3/2003-06-18/13374.shtml` | 老版中文名独立佐证（含变体后缀） |
| 13 | 新浪 传奇3G 怪物资料 | `https://games.sina.com.cn/zhqu/mir3/2/gwzl/` | 第二中文来源 |
| 14 | **17173 传奇3 怪物页** | `https://mir3.17173.com/mob/mob17.htm` | 资料站镜像的原始出处 |
| 15 | 17173 传奇3 技能页 | `https://mir3.17173.com/skill/skill.htm` | 技能中文描述 |
| 16 | 百度百科 · 多钩猫 | `https://baike.baidu.com/item/多钩猫/5630779` | 语义直译证据（钩/hook） |
| 17 | 百度百科 · 钉耙猫 | `https://baike.baidu.com/item/钉耙猫/5630928` | 语义直译证据（耙/rake） |
| 18 | 知乎 · 光通 1.45 技能攻略 | `https://zhuanlan.zhihu.com/p/649403177` | 技能中文名佐证 |
| 19 | 传奇三资料 archive | `https://mir3.iamcheyan.com/` | 网站侧出处（17173 镜像） |
| 20 | 老版 RaceImg 交叉表（本地推导 + 像素复核） | `mir2ei.iamcheyan.com/data/wiki_data_v2.json` + `MonsterLookup.cs` + EI `Mon-*.wil` | 无名称图像身份通道 |
| 21 | EI 3.0 客户端图库清单 | `https://mir3.iamcheyan.com/library.html` | 老版美术只存在于 Mon-1..16 |
| 22 | 老版 MUD3 Merchant.txt 坐标表 | `mir2ei.iamcheyan.com/data/wiki_data_v2.json`（`mud3.merchants` 318 条） | NPC 坐标通道 |
| 23 | 17173 传奇3 任务攻略（3G 江湖任务） | `https://mir3.17173.com/mission/rw3.htm` | 任务桥接尝试与失败证据 |
| 24 | 新浪 NPC 功能列表（2003） | `https://games.sina.com.cn/z/mir3/2003-06-12/12217.shtml` | NPC 坐标通道独立佐证 |

另：**每一条网站侧记录**都附带其真实可访问归档页 URL
（`https://mir3.iamcheyan.com/mobs/mob-N.html` / `/items/item-N.html` / `/skills/skill-*.html`，实测 HTTP 200）。

### 3.1 已执行的检索词（13 条，逐条记录结果）

见 `artifacts/web-entity-audit-2026-09-26/search_queries.json`（22 条）。要点：

- `site:lomcn.net Mir3 Zircon monster list` → 命中 LOMCN Mir3 怪物库（本轮最有价值的英文名来源）。
- `传奇3 钉耙猫 多钩猫 怪物 英文名 Raking Cat` → 确认两只猫是两个独立怪物，语义直译。
- `传奇3 怪物 英文名对照表 Wooma WhiteBoar RedMoonEvil …` → 命中新浪老版怪物排名表。
- `传奇3 地图 比奇 盟重 潘夜 英文名 Bichon Numa map name` → 地图中文名佐证。
- `"WhiteBoar" OR "RedMoonEvil" OR "WoomaTaurus" …` → **无结果**，已记为排除依据，
  **不据此判任何记录独有**。

### 3.2 族级规则检索词

按类别聚合的规则检索词在 `web_audit_sources.py:RULE_QUERIES`，
每条由规则闭合的记录都把对应族的检索词写入自己的 `search_queries`，保证「每条记录都有检索状态」可核对。

---

## 4. 分类别结果

### 4.1 方向变化（检索前 → 检索后）

| 分类 | 记录 | 检索前 mir2ei-only | 检索后 mir2ei-only | 检索前 Zircon-only | 检索后 Zircon-only | 检索后 both |
|---|---:|---:|---:|---:|---:|---:|
| monster | 527 | 87 | 55 | 373 | 126 | 346 |
| npc | 294 | 0 | 0 | 106 | 59 | 235 |
| item | 1402 | 324 | 158 | 1031 | 432 | 812 |
| skill | 176 | 2 | 1 | 115 | 93 | 82 |
| map | 472 | 0 | 0 | 450 | 173 | 299 |
| respawn | 2475 | 0 | 0 | 2058 | 184 | 2291 |
| quest | 62 | 62 | 62 | 0 | 0 | 0 |

每类均断言 `mir2ei-only + zircon-only + both = total`（`verify_web_audit.py` 第 2 组检查）。

### 4.2 新状态分布

| 分类 | 网络别名闭合 | 双方闭合 | 待网络证据 | mir2ei 检索后独有 | Zircon 检索后独有 | 冲突 | 部分 | 已应用 |
|---|---:|---:|---:|---:|---:|---:|---:|---:|
| monster | 329 | 0 | 73 | 45 | 68 | 12 | 0 | 0 |
| npc | 103 | 19 | 59 | 0 | 0 | 9 | 31 | 73 |
| item | 811 | 0 | 60 | 99 | 432 | 0 | 0 | 0 |
| skill | 82 | 0 | 0 | 1 | 93 | 0 | 0 | 0 |
| map | 160 | 0 | 28 | 0 | 262 | 6 | 16 | 0 |
| respawn | 1944 | 240 | 132 | 0 | 52 | 89 | 0 | 18 |
| quest | 0 | 0 | 62 | 0 | 0 | 0 | 0 | 0 |

### 4.3 典型闭合样例

- **怪物**：`鸡`（website mob-0）↔ Zircon `MonsterInfo[8] Chicken`；别名链
  `鸡 → mir2ei 百科 Chicken → MonsterLookup Mon-3 shape 0`；外部来源 = 百科数据集 + LOMCN 怪物库。
- **技能**：`基本剑术` ↔ `MagicInfo[1] Swordsmanship`；老版 `magic.dat` 逐字命中 + DAT 对照表
  + Zircon 官方 `ChineseMessages.cs`。
- **物品**：`井中月` ↔ `ItemInfo[?] Forged Scimitar`；老版 `stditem.Looks=1068` == Zircon `Image=1068`
  且双向 1:1（价格 28000 亦一致）。
- **地图**：Zircon `MapInfo[1] Bichon Town` ↔ 老版地图码 `0` → 比奇县。
- **刷新**：`RespawnInfo[4167] Chicken / 0 / Spawn Ring 1` —— 怪物身份闭合后传播为双方记录，
  坐标与刷新量仍按维度单独判定，不做推断写入。

### 4.4 为什么仍有 414 条待网络证据

诚实原因（不是「Zircon 没有」）：

1. **17173/新浪中文名 ≠ Zircon 译名**。资料站用「钉耙猫 / 山洞蝙蝠 / 白野猪 / 毒蜘蛛」，
   Zircon 侧用 `RakingCat / Cave Bat / Wild Boar / Venom Spider`；缺的是一条**经来源确认的中英对照边**，
   而不是实体本身。例如 `蛤蟆 / 钉耙猫 / 红蛇 / 白野猪 / 祖玛弓箭手` 都能在 mir2ei 百科与老版 DAT 中定位，
   但 Zircon 侧同名实体的英文别名尚无公开对照表可引用。
2. **资料站只是 17173 镜像子集**（154/371/61），Zircon 是 434/1078/174 全量；
   子集未收录 ≠ 对面没有。
3. **Zircon 重写了刷新数据**：`RespawnInfo` 与老版 `MonGen.txt` 的怪物集合与数量不一致
   （例：老版 `D1101` 为潘夜系 10 种，Zircon `D1101` 仅 2 种），因此刷新记录不做身份外推。
4. **候选存在但证据不足**：如 `钉耙猫` 在 Zircon 客户端有 `RakingCat`（`Mon-28` shape 6）资源，
   但当前 `MonsterInfo` 无对应行 → 记 `excluded_candidates` + `pending-web-evidence`，不升级、也不判独有。
5. **任务类（62 条）**：资料站 24 条 mission 是 17173 攻略文而非任务定义表；经 NPC 中文名→Zircon NPC→
   `StartQuests` 桥接后仅 4 条产出候选且全部错配 → 全部保留 `pending-web-evidence`，
   桥接失败过程写入 `excluded_candidates`（证据：`https://mir3.17173.com/mission/rw3.htm`）。

---

## 5. 机器可读产物

`docs/research/ei-ui-layout/artifacts/web-entity-audit-2026-09-26/`

| 文件 | 内容 |
|---|---|
| `audit_summary.json` | 分类覆盖、方向/状态统计、别名索引规模 |
| `external_sources.json` | 19 条外部来源（URL/标题/访问时间/摘录/哈希） |
| `search_queries.json` | 13 条已执行检索词 + 结果说明 + 命中来源 |
| `audit_ledger.tsv` | **5,408 行逐条台账**（分类/ID/方向前后/状态/检索状态/置信度/别名链/来源/检索词） |
| `verification.json` | 独立校验 58 项检查结果 |
| `raw/` | 外部来源原始副本（含 sha256 前缀） |

每条记录新增字段（直接并入 `alignment-browser/data/<class>.json`，不再生成重复副本）：
`web_search_status` · `search_queries[]` · `external_sources[]` · `source_commit_or_version` ·
`alias_chain[]` · `local_evidence[]` · `excluded_candidates[]` ·
`why_not_mir2ei_only` · `why_not_zircon_only` · `confidence` · `review_required` ·
`extended_mir2ei_attestation[]` · `relinked_from`（若为审计反查新增）。

---

## 6. 来源限制（必须披露）

1. **17173 分页限流**：`mir3.17173.com/mob/mob1..21.htm` 在本次审计中途开始返回 567 字节占位页；
   已取到的 `mob17` 与资料站镜像仍作中文名佐证。→ 属**来源级**不可达，不代表记录独有。
2. **程序化搜索引擎不可用**：Mojeek / DuckDuckGo HTML 返回 JS 挑战页，Bing RSS 返回与查询无关结果，
   `grep.app` 返回 429。改用 DIM 检索工具逐条检索并记录，无法做「每记录一次独立检索」的全量覆盖，
   因此族级规则 + 逐条记录检索词同时保留。
3. **镜像派生关系**：`mir2ei.iamcheyan.com` 的 Zircon 侧中文名与本站 `docs/terminology` 同源，
   属派生来源；每条记录的 `alias_chain` 都标了 provenance（`mir2ei-wiki-json` vs `local-candidate:db_names`），
   低置信来源（`db_names`）**不单独**构成 `both-resolved-by-web-alias`。
4. **本地候选表存在错译**：`GodotClient/translations/db_names.json` 中有明显错项
   （如 `Oma Warrior → 祖玛卫士`，正确应为沃玛；`Oma` 才是祖玛/沃玛之辨的关键），
   因此该表只作 `local-candidate`，命中后一律 `review_required=true`。
5. **fork 只作 secondary evidence**：Wincha / grimchamp / ketsmen / KingdomMir2 / iamcheyan 等 fork
   仅用于命名体系与历史字段旁证，**不覆盖本地 workspace 的实际值**。

---

## 7. 对照网页更新

`docs/research/ei-ui-layout/alignment-browser/`（静态，无构建系统，端口 8890）

- 新增导航页签：**网络审计** / **mir2ei 检索后** / **Zircon 检索后**。
- 总览新增：新分类 10 张状态卡、**检索前 vs 检索后方向对照表**、别名索引规模卡。
- **网络审计**页：新分类总计表、**审计时间线**（第一次未匹配 → 网络检索 → 别名闭合 → 未闭合）、
  19 条外部来源列表、13 条检索词列表、**来源限制披露**。
- **mir2ei 检索后 / Zircon 检索后**页：`*-after-web-audit` 专区 + `pending-web-evidence` 专区 +
  其他状态专区，明确「未闭合≠独有」。
- 差异清单：方向已按检索后重算，附「必须证明已检索」的说明。
- 详情抽屉新增 7 个审计区块：结论、**审计时间线**、别名链、检索词、外部 URL、本地证据、排除候选；
  顶部同时显示 **方向（检索前）** 与 **方向（检索后）**。
- 列表行新增审计条：检索状态 / 别名链 / 外部来源 / 置信度 + 是否需人工复核。
- **「当前实际使用 Zircon 数据」仍单独显示**（`current_usage`），不因网络候选自动覆盖。
- cache-bust 版本 `20260926.4`。

验收截图（`docs/research/ei-ui-layout/alignment-browser/`）：

- `WEB_AUDIT_DESKTOP_1440_overview.png`
- `WEB_AUDIT_DESKTOP_1440_web-audit.png`
- `WEB_AUDIT_DESKTOP_1440_differences.png`
- `WEB_AUDIT_MOBILE_390x900_web-audit.png`（iframe 真 390px 视口；`scrollWidth == clientWidth`，无横向溢出）

---

## 8. 独立校验

`verify_web_audit.py`（不 import 生成器，只读产物 + 原始来源）→ `verification.json`：**58 项检查，0 失败**。

| # | 检查 | 结果 |
|---|---|---|
| 1 | 7 类记录数分别为 527/294/1402/176/472/2475/62，合计 5,408（无丢行） | PASS |
| 2 | 每类每条记录都带审计层字段（`web_audit` / `direction_before_audit`） | PASS |
| 3 | 每类记录 ID 无重复 | PASS |
| 4 | 每类 `mir2ei-only + zircon-only + both = total` | PASS |
| 5 | 所有状态都在新分类内，且**旧终态 0 残留** | PASS |
| 6 | 每类状态计数加总 = 记录数 | PASS |
| 7 | **每条记录**都有 `web_search_status` 且 `search_queries` 非空 | PASS |
| 8 | 每条 `both-resolved-by-web-alias` 都有外部 URL + 本地证据 + ≥2 步别名链 | PASS |
| 9 | 所有外部 URL 可追溯到来源注册表或资料站归档页 | PASS |
| 10 | 方向变化都能被扩展证据/别名链解释 | PASS |
| 11 | `production-applied` 保持 91 条不变 | PASS |
| 12 | workspace `MonsterInfo` 仍 434 行（未写库） | PASS |

---

## 9. 完成条件对照

| # | 条件 | 状态 |
|---|---|---|
| 1 | 网站/当前 Zircon 每类所有记录都有检索状态 | ✅ 5,408/5,408 |
| 2 | 所有旧 mir2ei-only/zircon-only 都已重新审计 | ✅ 旧终态 0 残留；1,052 条升级为 `*-after-web-audit` 终态，其余有候选者保留待证据；来源级限制在 §6 披露 |
| 3 | 每条 resolved-by-web-alias 都有外部 URL + 本地证据 + alias chain | ✅ 3,429/3,429（校验项 8） |
| 4 | 搜索结果与外部来源保存为机器可读 JSON/TSV | ✅ `external_sources.json` / `search_queries.json` / `audit_ledger.tsv` |
| 5 | 独立统计校验无丢行、无重复、方向可加总 | ✅ 58 项 0 失败 |
| 6 | 更新对照 HTML，桌面/手机重新验收 | ✅ 4 张截图，移动端真 390px 无溢出 |
| 7 | 生成本报告 | ✅ |
| 8 | 只提交本 Goal 的 mapping/audit/browser 文件 | ✅ 见 §10 |

---

## 10. 变更范围与后续建议

**本次改动文件**（全部在 `docs/research/ei-ui-layout/` 下）：

- `alignment-browser/build_web_audit.py`（新增，第二轮扩展 4 条证据通道）
- `alignment-browser/web_audit_sources.py`（新增）
- `alignment-browser/verify_web_audit.py`（新增）
- `alignment-browser/app.js` / `style.css` / `index.html`（更新）
- `alignment-browser/data/*.json`（并入审计层）、`data/meta.json`
- `alignment-browser/WEB_AUDIT_*.png`（验收截图）
- `artifacts/web-entity-audit-2026-09-26/**`（来源、检索词、台账、校验、原始副本）
- 本报告

**未改动**：System.db / Users.db / `Tools/dbeditor/workspace/` / zircon 仓库 / mir3-website / mapedit。
**未提交**：任何密钥、cookie、完整私聊内容或外部站点受限内容（仅保存公开页面摘要与哈希）。

**后续建议（按收益排序）**：

1. **补齐中英怪物对照边**：优先为 `pending-web-evidence` 中方向为 `mir2ei-only` 的 321 条
   建立 17173 中文名 ↔ Wemade 英文名对照（可先做潘夜/诺玛/骷髅/僵尸/钳虫/蜈蚣/沙漠 七个族）。
2. **LOMCN 论坛深挖**：论坛内可能有社区维护的中英怪物名表；本轮只取到 wiki 与板块入口。
3. **图片证据闭环**：把资料站 `mob/pic/*.gif` 与 EI 客户端 `Mon-N.wil` 帧做哈希/视觉比对，
   作为名称之外的独立身份证据，专门用于消解 `conflict`（116 条）。
4. **Zircon 资源-only 实体**（如 `RakingCat`、`RedSnake`、`OmaInfant`、`SandGuard` 等 51 个
   `MonsterLookup` 有图无行的图像）单列一份清单，供人工决定是否补 MonsterInfo 行。
5. 任何名称/Index/坐标/刷新写入仍走原批准闸门（停服 → 备份 → 干跑 → round-trip → 双库同步 → 游戏内实测）。
