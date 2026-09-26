# Preview 源码 ↔ EI 3.0 反编译证据 差异总表

> 本目录登记 `reference/mir3-source/`（Mir3 Preview Version 社区源码）与
> `docs/research/ei-ui-layout/`（EI 3.0 原版 `Mir3.exe` 反编译证据）之间的**差异**，
> 以及每条差异的处理结论。
>
> **纪律**：源码证据等级为 `secondary-source`，**不得**覆盖原版 `primary-static` 结论。
> 差异不是「谁对谁错」，而是「同谱系不同构建」的事实记录。每一条都必须写清
> ①原版证据 ②源码证据 ③差异 ④如何处理（不处理 / 标注 / 待运行期闭合）。
>
> 建立于 2026-09-26（commit 见 git log），首轮闭合记录见
> [`../research/ei-ui-layout/RESEARCH_LOG.md`](../research/ei-ui-layout/RESEARCH_LOG.md) Round 802。

## 0. 两份证据的身份对照

| 项 | EI 3.0 原版（primary） | Preview 源码（secondary） |
|---|---|---|
| 载体 | `Mir3.exe` 524288 B + `mir3.dat` 532 KB + WIL/WIX | Delphi 源码 163 `.pas` + C++ 210 `.cpp/.h` |
| 位置 | `/data/NAS/TMP/EI传奇3.0客户端/` | `reference/mir3-source/Source/` |
| 出处 | 2003 年商业客户端 | LOM2 社区 SVN `code.lom2.com/svn/Mir2`，时间戳 2002–2019 |
| 版本开关 | — | `GameServer/svMain.pas`: `KOREANVERSION = TRUE`（服务端以韩版为基准） |
| 资源容器名 | `Data/GameInter.wil` | `Data\GameInter.Lib`（失败才回退 `.wil`，`uWilFile.pas:189-191`） |
| 客户端窗口集 | 13 个主窗口（HUD 底部操作栏体系） | 40 个窗口（352 条控件声明），**无任务窗** |
| 屏幕基准 | **800×600** | **800×600**（`ClMain.pas:25-26`）✅ 相同基准；DFM 的 1095×975 只是编辑期画布 |
| 编码 | GBK 文本 | `Source/**` = CP949（**混有 GB18030 中文注释**），`Mud3-Config/**` = GB18030 |

**读源码前必读（三条硬约束）**：

1. **编码是混合的**。`Source/**` 以 CP949 韩文为主，但**混有 GB18030 中文注释**
   （实测 `Grobal2.pas:419` `//防御上限` 的字节 `b7c0 d3f9 c9cf cfde`，
   其中 `c9cf` 恰好是**合法** CP949 双字节）。整文件一刀切判定必然出错。
   用 `Tools/source-read/read_src.py show|grep`（逐行计分 + 混合行重解）。
2. **`rg`/`grep` 对中文/韩文关键字直接失效**（编码不匹配）。
3. **`.pas` 里没有窗口几何** —— 坐标/尺寸全在二进制 `.dfm` 里，
   用 `Tools/source-read/dfm_parse.py` 解析。

---

## 0.5 本目录文件索引

| 文件 | 内容 |
|---|---|
| [`protocol.md`](protocol.md) | 474 个协议常量 + 拓扑分区 + EI 证据 28 opcode 对照 |
| [`protocol-constants.tsv`](protocol-constants.tsv) | 机器可读常量表（474 行） |
| [`dispatch-coverage.json`](dispatch-coverage.json) | 客户端/服务端分派覆盖统计 |
| [`wire-format.md`](wire-format.md) | 6bit 编码 + `Etc` 防外挂校验 + 公钥协商链 |
| [`client.md`](client.md) | 客户端骨架 / 场景状态机 / 帧号空间 |
| [`client-windows.md`](client-windows.md) | DFM 几何提取 + 窗口对照 |
| [`client-windows.tsv`](client-windows.tsv) | 352 条窗口/控件声明 |
| [`client-controls.md`](client-controls.md) | 控件基类 / 四级输入优先级 / 像素级命中 |
| [`client-libraries.md`](client-libraries.md) | WIL/Zl 加载链 + 真实资源交叉验证 |
| [`server.md`](server.md) | 对象模型 / `.map` 格式 / 任务引擎真相 |
| [`config.md`](config.md) | Envir/Envir3 对比 / MapInfo 格式 / 小地图链 |
| [`verification.md`](verification.md) | 独立验证记录 |

工具（`Tools/source-read/`）：`read_src.py`（转码读取）、`dfm_parse.py`（DFM 解析）、
`edcode.py`（线格式参考实现）、`extract_protocol_constants.py` + `verify_protocol_constants.py`
（常量表生成/独立校验）、`coverage.py`（分派统计）、`extract_client_windows.py` +
`frame_overlap.py`（窗口/帧号）、`env_compare.py`（配置对比）。

---

## D0. 贯穿全篇的总结论（先读这条）

**Preview 版与原版 EI 3.0 是同引擎的不同构建。协议与屏幕基准相同，但帧号与资源容器不通用**：

> ⚠️ **2026-09-26 修正**：初版称「四类关键资产全部不通用」是**过强**的 ——
> 屏幕基准实为**相同**（同为 800×600）。正确表述见下表。

| 资产 | 原版 | Preview | 可互推？ |
|---|---|---|---|
| **帧号空间** | `GameInter` 1103 帧（0–1102） | 引用 184–1960（91 个唯一帧号） | ❌ 交集 10 个且与已详查帧零重合 |
| **窗口尺寸** | 800×600 基准 | **同为 800×600**（`ClMain.pas:25-26`） | ⚠️ 基准**相同**；但尺寸值不同（原版背包 284×324 vs 源码 DFM 111×144，运行时值待逐窗对照 `client-windows.md` §8） |
| **WIL 容器** | `ILIB v1.0-WEMADE` 签名 | `Title[20]+IndexCount` 25B 头 + 17B 图头 | ❌ 两者不能互相解析 |
| **配置内容** | （不在本仓库） | `Envir/` 被抽空，`Envir3/` 有内容 | — |

**但协议层是通用的**：`Grobal2.pas` 是**全链路总表**，客户端与服务端
`uses ..\Common\Grobal2.pas` 共用同一份；EI 证据引用的 28 个出站 opcode
与源码 `CM_` **100% 值命中**。→ **协议可互推，资源/布局不可互推。**

> 这条结论决定了本 Goal 的产出边界：**源码的价值在语义命名与协议，
> 不在几何与资源**。任何用源码坐标/帧号改写原版证据的做法都是错的。

---

## D1. 协议 opcode 语义（最高价值，已部分闭合）

### D1.1 `0x409` = `CM_WANTMINIMAP`

| | |
|---|---|
| 原版（F321） | `0x451770` = msg **0x409**（地图查询，ret 0）；唯一调用者 `0x42C259`（HUD 小地图 cap1），`GetTickCount` 3s 冷却 + `[0x6210]` 上次时刻 + `[0x6518]` 状态 |
| 源码 | `CM_WANTMINIMAP = 1033`（`Common/Grobal2.pas:1732`）；客户端 `ClMain.pas:4676` `SendWantMiniMap`；服务端 `ObjBase.pas:25170` → `ServerGetWantMiniMap`（`:28529`）回 `SM_READMINIMAP_OK=710` / `FAIL=711`（`Param` = `PEnvir.MiniMap`） |
| 数据源 | **`Envir/MiniMap.txt`**（格式 `<地图名> <小地图号>`）→ `LocalDB.LoadMiniMapInfos`（`:1389-1415`）→ `TEnvirnoment.MiniMap`（`Envir.pas:155`）→ 回包 `Param` → 客户端 `MiniMapIndex := Param - 1` |
| 差异 | **无**。原版 3s 冷却常量 `0xBB8` = 源码 `GetTickCount + 3000`（`FState.pas:7746`），逐字节一致 |
| 结论 | 业务名闭合为「请求当前地图的小地图索引」。`[+0x6210]` 写点 = 客户端点击处理器自身（非服务端回包） |
| 处理 | 已写入 RESEARCH_LOG Round 802-A / Round 809；`hud-caption-action-tail-evidence.json` 的业务名可从 candidate 升级，**但须保留 primary-static 的 opcode/调用点原文** |

> **端到端链路已完整闭合**（Round 802 + Round 809）：
> `MiniMap.txt` → 服务端 `MiniMapList` → `TEnvirnoment.MiniMap` →
> `CM_WANTMINIMAP(0x409)` → `SM_READMINIMAP_OK(710)` → 客户端显示。
> 本仓库 `minimap-server-crossref.json` 正是这张交叉表，**现在有了权威格式依据**。

### D1.2 `0x418` = `CM_FRIEND_EDIT`，`0x419` = `CM_FRIEND_LIST`

| | |
|---|---|
| 原版（F218/F251/F321） | `0x451A10`=msg **0x418**（1 参 dword）、`0x451A40`=msg **0x419**（2 参 dword）；E8-scan 单调用点定案：0x418 ← `0x44862B`（任务窗选中记录，`+0x20C==0` 门）、0x419 ← `0x448148`（任务窗子记录 `+0x228` 点击，`+0x220` 空门）。业务名候选「前进/下一任务记录」「请求任务详情」 |
| 源码 | `CM_FRIEND_EDIT = 1048`（`:1748`，好友说明变更，**带字符串 body**）、`CM_FRIEND_LIST = 1049`（`:1749`，好友列表请求，**无 body**）；客户端 `ClMain.pas:9385` / `:5556`；服务端 FriendSystem `FriendSystem.pas:482/483` |
| 差异 | ①**业务域不同**：原版同 opcode 的宿主是任务窗，源码是好友窗 ②**参数布局分叉**：源码带/不带 body，原版实测是 1 个 / 2 个 dword ③**宿主 UI 不同**：源码客户端**没有任务系统**（CM_ 全集里无任何 Mission/Quest 消息，`FState.pas` 无任务窗） |
| 结论 | opcode 命名空间同源，但 **EI 3.0 的线上业务名不是「任务详情/放弃」**。F251 的 candidate 业务名标为**被 Round 802 修正** |
| 处理 | **不得**据此改写原版任务窗几何证据（单调用点定案不变）；**不得**主张「任务窗=好友窗」。要最终判定 EI 3.0 线语义，需 `Mir3.exe` 发 0x418/0x419 时的服务端应答抓包 |

### D1.3 `0x409` 的「库存」标注需拆分

| | |
|---|---|
| 原版（F514） | 「重置 0x407/0x408 + 库存 0x409」与「0x409 背包」两处并置 |
| 源码 | `CM_WANTMINIMAP = 1033` 是唯一 1033；另有一处 `0x451BB0` 分派（0x406 金币 / 0x407 / 0x408 / **0x409**）属**交易金币族**，`0x451CC0` 是库存字符串解析器 |
| 差异 | 同一 opcode 数字在不同 UI 上下文被原版工具记成了两种语义 |
| 处理 | 证据文件中两处必须**分开标注上下文**，不得合并成一条 |

---

## D2. 资源路径表（157 vs 57，比对已完成）

| | |
|---|---|
| 原版 | `resource-path-table.json`：157 条路径字段（140 批量表 + 17 单独加载器），其中 **144 个唯一 `wil/wix`**；含 4 套地形前缀（`forest/ sand/ snow/ wood/`）× 18 个 `*sc` 族、20 个 `Mon-N.wil` + 20 个 `DMon-N.wil`、`M-Hum/M-Weapon1-4/M-Hair/M-Helmet1` + `WM-` 对应族、`NPCFace.WIL`、`MonImg.wil`、`Horse.wil` |
| 源码 | `uWilFile.pas` + `FState.pas` + `ClMain.pas`：**57 个唯一** `Data\*.Lib` / `Data\*.wil`；`Mon1–Mon25.wil`、`Items.wil`、`Dragon.wil`、`GameInter1.Lib`；**无地形前缀族、无 `-` 分隔命名** |
| 交集 | **仅 29 个**（`gameinter / interface1c / magic / magicex / monmagic / monmagicex / equip / inventory / ground / storeitem / micon / proguse / npc / mmap / fmmap / tilesc / wallsc …`） |
| 差异 | ①命名法不同：`Mon-N.wil`/`Mon-Ns.wil` vs `MonN.wil` ②原版有 4 套地形变体 + `DMon`（暗怪）+ 外观族，源码无 ③源码有 `Items.wil`/`Dragon.wil`/`GameInter1`，原版路径表未出现 |
| 结论 | **核心 UI 族完全重合，扩展族是两套不同资产集**。原版路径表仍是资源解析的唯一权威；源码可用于**理解字段含义与加载顺序**，不可用于补全原版表 |
| 处理 | 已记入本文件；后续源码精读时按族逐条补注「源码对应物有/无」 |

**关键对照（核心族）**

| 族 | 原版 | 源码 | 一致 |
|---|---|---|---|
| 主界面 | `.\Data\GameInter.wil`（`0x0047ce0c`） | `Data\GameInter.Lib` | ✅ |
| 辅助窗口 | `.\Data\Interface1c.wil`（`0x0047aaa0`） | `Data\Interface1c.Lib` | ✅ |
| 技能/魔法 | `Magic.wil` `MagicEx.wil` `MonMagic.wil` `MonMagicEx.wil` | 同名 `.Lib` | ✅ |
| 物品/装备 | `Inventory` `Equip` `Ground` `StoreItem` `MIcon` `ProgUse` | 同名 `.Lib` | ✅ |
| 地图 | `MMap` `FMMap` | `Data\Mmap.Lib` `Data\Fmmap.Lib` | ✅ |
| NPC | `.\Data\NPC.wil` | `Data\Npc.Lib` | ✅ |
| 怪物 | `Mon-1..9` + `DMon-1` + `MonImg` | `Mon1..Mon25` | ⚠️ 命名与数量分叉 |
| 角色外观 | `M-Hum/M-Weapon1-4/M-Hair/M-Helmet1` + `WM-` | **无** | ❌ 源码独缺 |

---

## D3. UI 窗口集与帧号空间

| | |
|---|---|
| 原版 | 13 个主窗口（HUD 底部操作栏：交换 80/81、小地图 82/83、技能 84/85、退出 90/91、登出 92/93、组队 94/95、行会 96/97、腰带翻页 52/53、罗盘按钮 100–115…）；`GameInter` 帧数 **1103**（ZL2 与 WIL 一致），硬编码索引有效范围 0..1102 |
| 源码 | 26 个 `D*Dlg`（`DFriendDlg` `DMailDlg` `DJangwonListDlg` `DItemMarketDlg` `DMasterDlg` `DBlockListDlg` `DGABoard*` `DGADecorateDlg` `DMakeItemDlg` …）；`g_WGameInter` 有 130 处引用，帧号出现 79–97、202、226–228、372/373、1210/1211、1221/1222、1240/1241/1245、1960 |
| 差异 | ①**窗口集分叉**：源码有好友/邮件/市场/师徒/黑名单/公告板/装饰等**现代扩展窗**，原版无 ②**帧号越界**：源码引用 1210–1960，远超原版 `GameInter` 的 1103 帧 ③原版有任务窗，源码无 |
| 结论 | 帧号空间**同源但已分叉**；源码的越界帧号**不可**用于推导原版帧语义 |
| 处理 | 源码精读时，凡引用帧号 >1102 的，一律标注「Preview 专属，原版无对应」 |

---

## D4. 服务进程拓扑与端口（新增信息，原版证据缺失）

| 项 | 源码证据 | 与原版的关系 |
|---|---|---|
| 客户端→LoginGate | `LoginGate/GatePort = 7000` | ✅ 与本仓库 `Client/Mir3.ini` 的 `Param1=7000` 一致 |
| LoginGate→LoginServer | `ServerPort = 5500`（`LG_BPORT`） | 原版无对应证据，**新增** |
| 客户端→SelChrGate | `GatePort = 7100` → DataBaseServer `5100`（`RG_BPORT`） | **新增** |
| 客户端→RunGate | `GatePort = 7200` → GameServer `5000` | **新增** |
| GameServer→DataBaseServer | `GS_BPORT = 6000` | **新增** |
| DataBaseServer→LoginServer | `LS_CPORT = 5600` | **新增** |
| DataBaseServer→SQL Server 2000 | ODBC | 与本仓库「`System.db` 上游是 SQL 库」结论一致 |

> ⚠️ 被排除的 `LoginSvr.ini` / `DBSvr.ini` 含 `ODBC_ID=sa` / `ODBC_PW=sa`
> （SQL Server 2000 默认口令）。**禁止**复制进仓库。

**处理**：拓扑表可直接用于解释本仓库 `Tools/wsgateway`（浏览器→ServerCore:7000）与
Zircon 的对应关系；不改变现有结论，属**补充**。

---

## D5. 数据表/配置（System.db 上游）

| | |
|---|---|
| 原版 | `System.db` = .NET BinaryFormatter；上游 SQL Server 2000（`Mud3 Preview/SQL/`，687 MB，已排除） |
| 源码 | 服务端按名读取：`MapInfo.txt` `MonGen.txt` `Merchant.txt` `Npcs.txt` `GuardList.txt` `AdminList.txt` `MiniMap.txt` `StartPoint.txt` `SafePoint.txt` `MakeItem.txt` `DecoItem.txt` `DragonItem.txt` `GenMsg.txt` `MapQuest.txt` `UnbindList.txt` `StartupQuest.txt` `AttackSabukWall.txt` `Sabuk.txt` `enckey.txt`；`svMain.pas:619` `EnvirDir := ini.ReadString('Share','EnvirDir','.\Envir\')` |
| 差异 | 源码只读 `Mud3-Config/Envir/`（Mir2 风格 391 txt）；`Mud3-Config/Envir3/`（1729 txt + 69 `.gen`）在整个包内 grep 命中 **0 次** → **本版源码不读 Envir3** |
| 结论 | `Envir3/` 属另一/更新构建，只能当**独立参考资料**（含 `QuestDiary/` 任务脚本树、`Mon_Def/*.gen` 刷怪定义） |
| 处理 | 本仓库 `Tools/questdata`、dbeditor workspace 与 `Envir3/` 的对照**必须标注**「源码不读它」这一前提 |

---

## D6. 未破译 / 缺口

| 项 | 状态 |
|---|---|
| `Envir3/QuestDiary/NQ_BASE/MonQuest/` 3 个 `.txt`（`Nm_Chiken/Nm_Cow/Nm_OmaJunsa`） | **未破译**。非 GB18030/cp949，字节呈定长对模式（每对低字节低位恒 `0xC`），疑 Mir3 MonQuest 私有编码 |
| 15 个二进制 DFM（`ClMain.dfm` `FState.dfm` 等） | 可打印率 81–83%，是窗件布局唯一来源；转文本需 Delphi `convert.exe` |
| `BitChange.inc`（A1R5G5B5 色转换 LUT，479 KB） | **已排除未入库**，与 `.Zl`/WIL 解码研究相关，值得单独取回 |
| `Mir3 Preview Version.rar`（53 MB 原件） | **本机已不在**（`.gitignore` 已加 `*.rar`）；取回排除内容需先找回原件，方法见 `reference/mir3-source/README.md` §5 |
| `SM_FRIEND_*` 在客户端的分派点 | 未查（本轮只追 `CM_` 方向） |

---

## D7. 处理规则（给后续 goal 的约束）

1. **不覆盖**：任何差异都不得用源码改写 `primary-static` 证据的原始表述。
2. **分级**：源码结论一律标 `secondary-source`；与原版吻合的标 `source-corroborated`；
   与原版冲突的标 `source-divergent`（本文件即 `source-divergent` 的登记处）。
3. **不猜**：源码里没有的（如 EI 任务协议）不得用「应该有」补齐。
4. **编码**：读 `Source/**` 用 `read_src.py`（**混合编码**，见 §0 约束 1）；
   读 `Mud3-Config/**` 必须 `iconv -f gb18030 -t utf-8`。
5. **安全**：`LoginSvr.ini`/`DBSvr.ini` 含 `sa/sa`，禁止入库；`Mud3-Config/Envir*/adminlist.txt`
   只是 GM 角色名，非凭据。
6. **不写库**：本目录的所有工作均为只读研究，`database_write=false` 维持。
7. **几何不可互推**（Round 805 新增）：源码 `.dfm` 坐标是**开发期编辑布局**
   （窗口被排成网格：`DFriendDlg`(15,655)/`DMailListDlg`(225,655)/`DMailDlg`(425,655)/
   `DBlockListDlg`(625,655) y 相同 x 等距 200），**不是游戏内位置**。
   只能作「窗口尺寸」证据，**不能作坐标证据**。
8. **字段名不可望文生义**（Round 808 新增）：`TCreature.HairColorR/G/B` 是
   **假的颜色字段** —— `HairColorR` 被挪用为位标志，G/B 是空占位
   （`ObjBase.pas:314-316` 注释明确写「不是头发颜色」）。
9. **常量名不是全局唯一 key**：474 个常量里有 **31 组跨前缀重值**
   （`CM_`/`SM_`/`ISM_`/`DBR_` 是独立命名空间）。按值查名必须带 `prefix` 维度。

---

## D8. 帧号空间不可互推（Round 804/805）

| 项 | 值 |
|---|---|
| 源码引用唯一帧号 | **91**（范围 184–1960） |
| 落在原版范围内（0–1102） | **10**：`184,188,202,372,373,556,564,566,568,570` |
| 超出原版范围 | **81**（1160–1672 连续族 + 1960） |
| 这 10 个 ∩ 原版已详查 37 帧 | **0（空集）** |

原版基准：`gameinter-frame-metadata.json` 的 `library_count: 1103`
（来源 `/data/NAS/TMP/EI传奇3.0客户端/Data/GameInter.wil`）。

**结论**：既有纪律「>1102 标 Preview 专属」**不够** ——
**≤1102 的同样不能直接当原版帧用**，必须逐帧像素比对。

窗口尺寸对照（`window_layout.json` vs `FState.dfm`）：

| 功能 | 原版 | 源码 DFM | 判定 |
|---|---|---|---|
| 背包 | id0 frame250 284×324 | `DItemBag` 111×144 | ❌ 差 2.5× |
| 人物状态 | id1 frame200 244×328 | `DStateWin` 201×216 | ❌ |
| 聊天 | id8 frame350 572×388 | `DChat` 189×100 | ❌ 差 3× |
| 组队 | id6 frame900 256×244 | `DGroupDlg` 186×116 | ❌ |

**没有一组吻合。**

---

## D9. WIL 容器格式不可互解析（Round 807）

| | `wmM3Zip.pas`（Preview） | 真实 `MagicEx.wil/.wix`（EI 原版） |
|---|---|---|
| 索引文件头 | `Title:string[20] + IndexCount:int32` = **25 B** | **20 B 全 0** + 偏移表 |
| 图像数位置 | 索引文件 `@21` | `.wil` `@24`（int16） |
| 图像头 | `TWMImageInfo` = **17 B**（含 `CompressedLen`） | `wilsdk` 解析为 **16 B** 项 |
| 压缩 | zlib（`DecompressBuf`） | `wilsdk` 正常读出 |
| 签名 | 无 | **`ILIB v1.0-WEMADE`** |

**实测交叉验证**：本仓库 `Tools/common/wilsdk.py` 在真实 EI `.wil` 上
**解析正确**（`MagicEx.wil` → `count=1780`，与文件头 `@24` 的 int16 自洽；
`header(0)` = 16×16 offset(4,-14) shadow(7,-44)）。
→ **原版资源仍以 `wilsdk.py`/`zlsdk.py` 为唯一权威解析器**，源码只用于理解设计意图。

**`.wix` 语义修正**：实测确认为**纯偏移表**（不是「索引+数据」），
`MagicEx.wix` 7144 B = 20 字节全 0 头 + 1781 × int32，
偏移值最大 27,652,185 **超出 `.wix` 自身大小** → 指向同名 `.wil`（27,652,718 B）。

---

## D10. `.map` 格式（Round 808，**源码给权威结构**）

`Envir.pas:49-77` 给出结构定义，**本仓库既有工具已正确处理**：

```
TMIR3MapHeader     = 28 B  (bhDesc[20] + bhAttribut/bhWidth/bhHeight 各 2
                            + bhEventFileIdx/bhFogColor 各 1)
TMIR3MapTileHeader =  3 B  (thTileTextureFile 1 + thTileTextureID 2)   ← 四分之一分辨率
TMIR3MapCellHeader = 14 B  (block/backAnim/topAnim/topFile/backFile 各 1
                            + backImg/topImg 各 2 + doorIndex 1 + doorOffset 2 + light 2)
文件大小 = 28 + (W*H/4)*3 + W*H*14
```

**实测验证**：`0_000.map`（70×70）实测 72,303 B = 公式预测 72,303 B ✅ **精确吻合**。

**发现的数据缺陷**：`D614.map`/`0_002.map` 等 6 个文件的**单元格区被截断**
（实际每格 13 字节）。用 `Tools/maps/map_roundtrip.py` 独立解析器验证：
`0.map` → `800×800 n=640000 n_records=640000`（完整）；
`0_002.map` → `20×20 n=400 n_records=371`（**缺 29 格**）。
200 个抽样文件里 194 个 C=14（完整）、6 个 C=13（截断）。
→ **源码的 14 字节定义是权威结构**，截断是**数据文件缺陷**而非格式变体；
**仓库既有 `map_roundtrip.py` 已正确处理**。

**`chCellBlock` 语义**（源码给出，原版反编译没有）：
`3`→不可走；`0,252`→可走；`1,2,254`→不可走且不可飞。
**门**：`chCellDoorIndex & $80` 非零即有门，`nDoor := chCellDoorIndex and $7F`
（**低 7 位是门号、高位是标志**）；坐标差 ≤10 且门号相同则共享 `pCore`。

---

## D11. 配置：`Envir/` 被抽空（Round 809，**严重**）

| | `Envir/` | `Envir3/` |
|---|---:|---:|
| 文件数 | 391 | 1,802 |
| 总字节 | 850,307 | 5,279,416 |
| **空文件** | **9** | 3 |
| 源码引用 | ✅ `EnvirDir` 默认 `.\Envir\` | ❌ **全仓 grep 命中 0 次** |

`Envir/` 的 9 个空文件：`Castle/AttackSabukWall.txt`、`GenMsg.txt`、
`GuardList.txt`、`MapQuest.txt`、`Market_Def/Light-D2083.txt`、`MerChant.txt`、
`MonGen.txt`、`Npcs.txt`、`StartUp/StartupQuest.txt`。

**而 `Envir3/` 里同名文件有内容**：`guardlist.txt` 0→4,703、
`mapquest.txt` 0→59,726、`merchant.txt` 0→41,074、`mongen.txt` 0→1,915。

→ `Envir/` 的地图表与商店脚本完整，但 **NPC 列表、刷怪表、守卫表、
地图任务表全被清空**。研究**实际内容必须用 `Envir3/`**，
同时清楚「本版源码不读它」这个矛盾。**二者合起来才是一份完整配置。**

---

## D12. 已闭合的疑问（原 README 的两处不准确表述）

| README 原文 | 实测修正 |
|---|---|
| §4 把 `enckey.txt` 列入「源码实际按名读取的配置」 | ❌ **不准确**。`svMain.pas:1273` 整行被注释掉：`// if LoadPublicKey( EnvirDir + 'enckey.txt' ) then`。公钥是**登录期动态协商**（见 `wire-format.md` §5） |
| §4 称「`Envir/` 才是源码真正读的那套」 | ⚠️ **代码层面正确，数据层面 `Envir/` 是空的**（见 D11） |
| §1 称「392 个常量」 | ❌ 实测 **474**（`SM 271 / CM 120 / ISM 57 / DBR 26`）。口径差异原因未查，以脚本解析为准 |

---

## D13. 未破译 / 缺口

| 项 | 状态 |
|---|---|
| `Envir3/QuestDiary/NQ_BASE/MonQuest/` 3 个 `.txt` | **未破译**。非 GB18030/cp949，字节呈定长对模式（每对低字节低位恒 `0xC`） |
| 15 个二进制 DFM | 可打印率 81–83%，是窗件布局唯一来源；转文本需 Delphi `convert.exe` |
| `BitChange.inc`（A1R5G5B5 LUT，479 KB） | **已排除未入库**，`WIL.pas:9` 有 `{$INCLUDE}`，逐像素精确对照时需取回 |
| `Mir3 Preview Version.rar`（53 MB 原件） | **本机已不在**（`.gitignore` 已加 `*.rar`） |
| `.Zl` 真实文件 | **本机没有**（`mir2ei` 与 EI 客户端目录均无）→ `zlsdk.py` 对真实 `.Zl` 的验证**未做** |
| DFM 字符串属性 | 长度前缀异常（`Caption` 值 `FrmDlg` 读成 `rmDlg`）→ **字符串不可靠，几何整型可靠** |
| `CM_ADDNEWUSER`(2002)/`CM_CHANGEPASSWORD`(2003)/`CM_UPDATEUSER`(2004) | 接收端 `case` 在本源码包内**确实缺失**，标注待查 |
| `SM_FRIEND_*` 在客户端的分派点 | 未查（只追了 `CM_` 方向） |
