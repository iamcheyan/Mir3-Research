# Zircon ↔ mir2ei 全量数据对照网页报告

生成时间：2026-09-26 08:26:18 UTC（本机记录 2026-09-26）  
数据版本：`MIR3-ALIGNMENT-BROWSER-2026.09.26`  
入口：`docs/research/ei-ui-layout/alignment-browser/index.html`

## 交付物

- `build_alignment_browser.py`：Python 标准库生成器；读取 workspace、website、alignment manifest、批准应用计划，输出静态 JSON 和证据图片副本。
- `index.html`：零依赖入口。
- `app.js`：按分类加载 JSON；分页、全局搜索、状态筛选、差异/未决筛选、左右对照、详情抽屉、证据来源展开。
- `style.css`：桌面 1280/1920 与手机 390 宽度响应式布局；手机改为上下对照；不使用原生 select/confirm/prompt。
- `data/*.json`：按怪物、NPC、物品、技能、地图、刷新、任务分组；记录保留 `left`、`right`、`conclusion`、`evidence`、`raw`。
- `data/images/website/`：390 个已知 website 图片的静态副本；生成器仅从 `/home/tetsuya/development/mir3-website` 复制，页面只接受 `data/images/` 路径。
- `ALIGNMENT_BROWSER_DESKTOP_1280x800.png`、`ALIGNMENT_BROWSER_DESKTOP_1920x800.png`、`ALIGNMENT_BROWSER_MOBILE_390x844.png`：浏览器验收截图。

## 数据数量

### Zircon workspace

| 表 | 行数 |
|---|---:|
| ItemInfo | 1,078 |
| MonsterInfo | 434 |
| MagicInfo | 174 |
| NPCInfo | 294 |
| MapInfo | 627 |
| MapRegion | 5,009 |
| RespawnInfo | 2,475 |
| QuestInfo | 38 |
| DropInfo | 10,382 |
| ItemInfoStat | 3,196 |
| MonsterInfoStat | 4,117 |

### mir3-website

| 数据 | 条数 |
|---|---:|
| items | 371 |
| monsters | 154 |
| skills | 61 |
| missions | 24 |
| map groups | 3 |
| map family areas | 22 |

### 网页记录（包含 website 对照记录与 Zircon-only 记录）

| 分类 | 记录数 |
|---|---:|
| monsters | 527 |
| npcs | 294 |
| items | 1,402 |
| skills | 176 |
| maps | 472 |
| respawns | 2,475 |
| quests | 62 |

技能页面单独核对：website 61 条，Zircon 174 条；manifest 直接闭合 `confirmed=59`，`investigate=2`。  
网页不把 61 条当作 Zircon 技能全量。怪物、物品同理：website 154 vs Zircon 434，website 371 vs Zircon 1,078。

## 状态统计
汇总状态明确值：`confirmed=126`、`investigate=91`、`pending=48`、`unmatched=0`（alignment manifest）、`retain-current=2,007`。`unmatched=0` 是 manifest 的未匹配统计；没有 website 对应的 Zircon-only 记录仍按 retain-current/Zircon-only 展示，不会隐藏。

生成数据中的状态计数：

| 状态 | 数量 |
|---|---:|
| confirmed | 126 |
| investigate | 91 |
| pending | 48 |
| retain-current | 2,007 |
| confirmed-name | 47 |
| legacy-source-only | 266 |
| pending-legacy-name | 58 |
| variant | 100 |
| exact | 92 |
| replacement | 19 |
| renamed | 6 |
| position-applied | 73 |
| production-applied | 18 |
| zircon-only | 2,058 |
| conflict | 89 |
| matched | 310 |

NPC 记录中 `position-applied=73`，刷新记录中 `production-applied=18`；两者都从 `approved-offline-plan.json` 的具体 Index 生成，不由页面文案猜测。未批准记录仍显示 pending/candidate/conflict/Zircon-only/YXS-only。

## 生产应用状态

来源：`production-apply-evidence-20260926.json`、`final-production-targets-20260926.json`、官方客户端 smoke 日志。

- approved NPC：73；approved RespawnInfo：18。
- `MonsterInfo` 业务字段变更：0。
- `MagicInfo` 业务字段变更：0。
- 服务端与客户端 System.db SHA-256：
  `b6aaa4bf2912a8fcd66664981a28d556aa6e2256ce2c40ad307b3d6913b03bb9`。
- 双库 SHA 相同：是。
- 生产备份：
  - `/home/tetsuya/development/zircon/Debug/ServerCore/Database/Backup/npc-monster-align-20260926-154039/System.db`
  - `/home/tetsuya/development/zircon/Debug/Client/Backup/npc-monster-align-20260926-154039/System.db`
- round-trip：PASS；unapproved changes=0；target mismatches=0。
- `Users.db` 写入：否；应用范围只打开 System.db。
- 官方客户端 smoke：PASS；收到 GoodVersion、LoginResult.Success、SelectScene、StartGame.Success 并进入 GameScene。
- isolated map smoke：NPC 目标与 Respawn 目标均 PASS；headless runtime 没有 sprite 像素，因此未宣称像素级断言。

## 来源与证据策略

每条记录都有 `source_type`、`source_path`、`source_id`（必要时 `page`/`image`）。右栏无直接对应时输出 `direct_correspondence=false` 和“无直接对应”，不会用同名强行闭合。

使用的输入层：

1. `Tools/dbeditor/workspace/*.json`：当前 Zircon 数据。
2. `/home/tetsuya/development/mir3-website/data/*.json`：website 的中文名、分类、技能/物品/怪物/任务/地图区域。
3. `docs/research/ei-ui-layout/artifacts/website-alignment-2026-09-26/`：逐条 monster/skill/item/NPC/respawn/map/mission manifest、图片证据、production evidence、verification。
4. `docs/research/ei-ui-layout/artifacts/npc-monster-alignment-2026-09-25/approved-offline-plan.json`：73 NPC 与 18 Respawn 的批准 Index/目标坐标。
5. `docs/research/ei-ui-layout/artifacts/npc-monster-alignment-2026-09-25/` 与 refresh-audit：NPC/怪物/刷怪位置、YXS-only/Zircon-only/conflict 证据。
6. Legacy Atlas / `mir2ei` 证据只作为来源层显示；没有结构化业务字段时不造记录。

## 输入 SHA-256

生成器把下列哈希写入 `data/meta.json`：

| 输入 | SHA-256 |
|---|---|
| alignment manifest | `55c3663e72c1c7e69939f452701e23b76468b288b65202743e8c5595636218ac` |
| production evidence | `9bdbe3a75b7c5c8d9831a141599836accbb04a2b71f93812b375cef3155e555c` |
| final production targets | `24225ffe16d2b0208ee1b8e93a798dcf9ee065f94d2c553bfdaeff74124abe07` |
| approved offline plan | `a68450609d82554891b2fd93c146eaa08c75e89c0a8317cef08ce23da5fbe005` |
| workspace ItemInfo | `5e871babba87232edb29ce53c1db3d1b765e3ea19cba31746431403a8e2ae1d2` |
| workspace MonsterInfo | `ed84588ffff45a1b9d9b85c7b886a3d469429356799f6a57ac142cf276aba09f` |
| workspace MagicInfo | `63cd1086e38b4384ed411f5c70c3bcc770b293ad89bfe94bb907f32f7a68bff9` |
| workspace NPCInfo | `09e19595b102f7ff0ba859f76964b7a812bd9acce7ae1871ee473d278f2b0e88` |
| workspace MapInfo | `f5d1077f3106c6a24203b996fbcad9b532f75f4c1ca9d82afb81cc95db6ab81c` |
| workspace MapRegion | `a598c92f73c0cb4ac2342f8cdb761c4525362e49c7e128b8e6e397aeecc37ee2` |
| workspace RespawnInfo | `40e656ec41f009cf4af4b5ae306399063a948cb10589ab1948cdd71459e6fe95` |
| workspace QuestInfo | `f9094da2c3b47cb65aed1378c52f5b55c0921ad6ef6f0d8e308a788d0a451bab` |
| workspace ItemInfoStat | `2fbcd3a2cf8360c958b076dca9e5dda252adba7f139cb1bf0998a28f575c490f` |
| workspace MonsterInfoStat | `9dfcc55f5889615d9b143f509a9a76aa7292dce53edd641093d3f39b4804ed12` |
| website items | `682d8eaf98cb2e9806416d0cd8b60c1a4ae1e3648164156b75154d7c6290c159` |
| website monsters | `bc84872907981f6567cf30d4aa5c3839ac9ec3e7c79f8f7b27530b4d4ed7ba99` |
| website skills | `8bd461409a1c9cb67a444a672f3cf0811ede6401bc24c311e87a16fd6a1919d4` |
| website missions | `6aa03bb8e4f447655c8fa9e9a3babdbf4d2a5387fc82900ebd70c027d4258af8` |
| website maps | `a7c142eaff5eace41a1b92028845f81f40eabb9507176435effc5ad63b0e6e0b` |

完整哈希字典见 `data/meta.json`。

## 浏览器验证

静态服务：`python3 -m http.server 8911 --bind 127.0.0.1`。  
入口响应：HTTP 200（浏览器成功加载 `index.html` 与全部 `data/*.json`）。

已执行：

- Python `py_compile`：PASS。
- 生成器重跑：PASS；真实行数与 workspace/website 输入一致。
- Node `--check app.js`：PASS。
- Chromium console/pageerror：0；初始页、分类切换、搜索、筛选、详情抽屉、结论页均无错误。
- 桌面 1280×800：`scrollWidth=1280`，`clientWidth=1280`，无横向溢出。
- 桌面 1920×800：`scrollWidth=1920`，`clientWidth=1920`，无横向溢出。
- 手机 390×844：`scrollWidth=390`，`clientWidth=390`，无横向溢出。
- 分类实际打开：怪物、NPC、物品、技能、地图、刷新、任务；每类分页首屏 36 条。
- 详情实际打开：怪物 Chicken；抽屉包含 ZIRCON / CURRENT、MIR2EI / EVIDENCE、SOURCES、RAW MANIFEST。
- 搜索抽查：输入 `Chicken` 得到 1 条；confirmed 筛选显示 `67 / 527`。
- 技能抽查：生成数据 176 条（Zircon 全量 + website 对照），`confirmed=59`、`investigate=2`。
- NPC/刷新生产应用抽查：`73 / 18` 与批准计划一致。
- 随机实体抽查：`website:mob-0` 为 Zircon `Index=8 / Chicken`，右侧 `鸡`，状态 `confirmed`；来源指向 monster-manifest.tsv。

## 未决项

- `investigate`、`pending`、`conflict`、`legacy-source-only`、`pending-legacy-name`、`Zircon-only`、`YXS-only` 仍在网页中可筛选，未被标成完成。
- website 目录覆盖的是标准资料/区域图，不是 Zircon 627 张 MapInfo、434 条 MonsterInfo、1,078 条 ItemInfo 或 174 条 MagicInfo 的替代全集。
- 官方客户端 smoke 的 headless runtime 没有 NPC.Zl/Mon_3 像素资源，报告只认网络/实体包/进入地图链路，不认 sprite-pixel 断言。
- production browser login disconnect 是 webport-only 既有问题，不属于本次 System.db 应用成功范围。
