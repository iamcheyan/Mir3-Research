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
| 位置 | `${MIR3_EI_ROOT}/` | `reference/mir3-source/Source/` |
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
| DataBaseServer→SQL Server 2000 | ODBC | SQL Server record path; not proof that binary `System.db` is generated from or backed by this connection |
| GameServer inter-server | `ServerIndex=0` 启动 `MsgServerPort` listener；非零 server 连接 `MsgServerAddress:MsgServerPort`。`ISM_*` 帧由主 server 转发给其它 peers；friend/tag 与 `ISM_USER_INFO` callbacks 进入 `UserMgrEngine` 队列，`TUserInfo` 可将 user status 重发为 `SM_USER_INFO`；`ISM_USERSERVERCHANGE` 使用共享 `.shr` handoff file | 新增源码侧跨服消息与用户路由；不建立 EI `.db` 或资源映射 |

> ⚠️ 被排除的 `LoginSvr.ini` / `DBSvr.ini` 含 `ODBC_ID=sa` / `ODBC_PW=sa`
> （SQL Server 2000 默认口令）。**禁止**复制进仓库。

**处理**：拓扑表可直接用于解释本仓库 `Tools/wsgateway`（浏览器→ServerCore:7000）与
Zircon 的对应关系；不改变现有结论，属**补充**。

---

## D5. SQL records and text configuration are separate evidence tracks

| | |
|---|---|
| 原版 | `System.db` = .NET BinaryFormatter. An excluded `Mud3 Preview/SQL/` dump (687 MB) exists, but this source read does not establish that it is `System.db`'s upstream |
| 源码 | `DataBaseServer/DBSvr/tablesdefine.cpp` declares SQL Server player-record tables; GameServer→DataBaseServer→ODBC is separate from `System.db`/`Users.db` MirDB files. Server text configuration is read by name: `MapInfo.txt` `MonGen.txt` `Merchant.txt` `Npcs.txt` `GuardList.txt` `AdminList.txt` `MiniMap.txt` `StartPoint.txt` `SafePoint.txt` `MakeItem.txt` `DecoItem.txt` `DragonItem.txt` `GenMsg.txt` `MapQuest.txt` `UnbindList.txt` `StartupQuest.txt` `AttackSabukWall.txt` `Sabuk.txt` `enckey.txt`; `svMain.pas:619` sets `EnvirDir := ini.ReadString('Share','EnvirDir','.\Envir\')` |
| GameServer ADO 子系统 | `SQLLocalDB.pas` 从 `Setup/!DBSETUP.TXT` 连接并读取 StdItems/Monster/MonsterItem/Magic；`DBSQL.pas`/`SqlEngn.pas` 处理物品市场与行会据点公告板 SQL。与 C++ DataBaseServer ODBC 路径分开，不建立 `.db` 文件映射 |
| GameServer `MaketSystem.pas` user-market cache | **Source:** `Server_JOB_ItemGen.dpr` explicitly selects this server copy; `ObjBase.TUserHuman` owns it, `ObjNpc.TMerchant.SendUserMarket` starts list requests, and `SqlEngn` sends result data back to `GetMarketData` then `SendUserMarketList`. **Difference:** GameServer `Delete`, `OnMsgReadData`, and `OnMsgWriteData` are empty; `Load`/`ReLoad` have no external per-user-manager caller, and `Destroy` does not free its `FItems` list. On a non-success market result, `GetMarketData` leaves cached rows intact while `SqlEngn` still sends the list. `Source/Client/MaketSystem.pas` is a separate same-named unit selected by `Mir3.dpr`, with client-only methods used by `FState`. | Preview ADO market path only; no EI MirDB mapping, build, or runtime validation
| 角色记录网络通路 | `GameServer/RunDB.pas` 将 `FDBRecord` 与 `TUserHuman` 互转，经 `DBSocket` 发送 `DB_LOADHUMANRCD`/`DB_SAVEHUMANRCD`；`FrnEngn.TFrontEngine` 缓冲登录、保存、角色金币调整和 DB 消息，再驱动 `RunDB` 请求。`DataBaseServer/DBSvr/netgameserver.cpp` 注册到 `OnLoadHumanRcd`/`OnSaveHumanRcd`。这是玩家角色记录网络/ODBC路径，仍未证明与 EI `System.db`/`Users.db` 的文件映射 |
| 客户端网关通路 | `GameServer/RunSock.pas` 处理 RunGate `TMsgHeader`/`GM_*` 数据、认证并把准入交给 LoginServer/FrontEngine；不是 `RunDB` 角色记录套接字，也不表示 EI 静态资源/数据库来源 |
| 跨服角色迁移 | `UsrEngn` 把 `TServerShiftUserInfo`（含 `FDBRecord` 和运行态字段）写成共享 `.shr` 文件并附加加法校验和，`ISM_USERSERVERCHANGE` 传输编码文件名、目标服读取后回 ACK；这是临时跨服移交，不是 `System.db`/`Users.db` 的持久化 schema |
| GameServer legacy `MasSock.pas` socket form | **Source:** `FormCreate` allocates `UserList` and activates a `TServerSocket` on port 5600; connect/disconnect add and dispose `PTUserInfo` entries, read events append `ReceiveText` to `SocStr`, and `SendInterServerMsg(word, body)` wraps `(<msg>/<body>)` and broadcasts to connected sockets. **Reachability:** source-wide `MasSock`/`TFrmMasSoc` searches found only this unit, with no project map, external form caller or matching DFM; `SocStr` is never parsed. This method is distinct from `TUserEngine.SendInterServerMsg(string)` through `FrmSrvMsg`/`FrmMsgClient`. **Difference:** no active GameServer interserver path is established | Static unit only; no form build, socket runtime, or EI equivalence
| GameServer CRC/MD5 hash utility | `crc_32.pas` and `CryptMd5.pas` feed `ElHashList`; repository search found no non-comment `TElHashList.Create` callsite outside its own constructor (FriendSystem/TagSystem/UserMgr retain actual `TList`/`TStringList`) | legacy lookup code, not checksum evidence for EI MirDB or a verified live service path |
| GameServer shared rules | `M2Share.pas` defines source-version EXP/bonus tables, equipment `StdMode` predicates, direction/range masks and shared movement helpers used by GameServer units | secondary-source behavior only; no EI primary-static equivalence, client geometry, or `.db` mapping established |
| GameServer runtime settings dialog | **Primary:** EI primary-static counterpart not established. **Source:** `FSrvValue.pas` exposes timeout values, send-block thresholds, gate-load count, and diagnostic flags; `svMain` persists accepted settings except `AvailableBlock`. **Difference:** `AvailableBlock` is read/changed but not saved, and its `RunSock` threshold is commented | Preview server configuration only; no EI UI equivalence or MirDB mapping established |
| GameServer `ConfirmDlg.pas` helper | **Source:** `TFrmConfirmDlg.ExecuteDlg` copies the supplied `TStringList` into `Memo1`, calls `ShowModal`, and returns true only for `mrYes`; all other modal results return false. **Reachability:** source-wide `ConfirmDlg`/`ExecuteDlg` searches found no importer, caller or explicit project mapping. The unit declares `{$R *.DFM}`, but no matching form resource appeared in source-reader searches; the expected lowercase/uppercase DFM paths were not found, so button modal-result wiring is unresolved. **Difference:** no active GameServer UI path is established | Static Preview unit only; no Delphi/resource runtime or EI equivalence
| GameServer login notices (`NoticeM.pas`) | **Source:** `svMain` creates/frees `TNoticeManager`; `UsrEngn` refreshes its `.\Notice\*.txt` cache every 10 minutes, while a comment in `ObjBase` says five. `TUserHuman.SendLoginNotice` reads the fixed `Notice` list and sends its lines in `SM_SENDNOTICE`. **Difference:** refresh leaves cached entries intact when files disappear; first-load exceptions still register the name and return true; the `Valid` flag is never consumed. | Preview GameServer notice path only; no EI UI or runtime/file-change test
| Client `CMsg.pas` message table | **Source:** `Mir3.dpr` maps the unit; `ClMain` constructs it, calls `LoadMsg` under `boFirstTime`, and frees it on shutdown. `ClMain`, `FState`, and `IntroScn` call `GetMsg`. Parsing skips blank/`;` lines and accepts `#<id> <text>` records; lookup is linear and returns the first duplicate. **Difference:** `LoadMsg` appends without clearing, leaves the decrypted list allocated on success, and has an empty `DelMsg`; its exception handler frees `TmpList` even if `Decrypt` failed before assignment, and `StrToInt` is unguarded. `EDcode` has no explicit `Mir3.dpr` mapping; Common `EDCode` contains the only searched `Decrypt`, but compiler resolution is unverified | Preview client source only; no build/runtime/fixture or EI message-string equivalence |
| Client `ClFunc.pas` item, persistence and direction helpers | `Mir3.dpr` maps the sole `ClFunc` source; `ClMain` imports it, and its implementation imports `ClMain`. It supplies local `.itm` inventory snapshots and `.Opt` settings, bag/trade/drop/crafting operations, tile and projectile directions, equipment-slot mapping, and change-face tracking. **Difference:** `AddItemBag` merges stack durability without setting its Boolean result; stacked `DelCountItemBag` matches every same-name stack without checking `MakeIndex` and also leaves its result false. | Preview client helper layer; local files, not server DB; no build/runtime or EI equivalence |
| Unlinked Client `DrawHint.pas` manager | **Source:** `TDxHintMgr` splits `\`-separated rows and parses `<text|I=... C=... S=... B=...>` markup into cached segments. **Reachability:** no project mapping, import, manager construction, or external caller was found; the separately mapped `DrawScrn.TDrawScreen` hint methods are called through `DScreen` by `ClMain`/`FState`. **Difference:** cache matching uses only `CRC32(text)` plus black/nonblack style, not actual text or other colors; markup can copy an uninitialized/stale `Segment.Image`, and a nil atlas-image exit bypasses the temporary render target's `Free`. | Static unlinked Preview unit; no claim of active hint UI, runtime, or EI correspondence |
| Client `Logo.pas` RLE splash surface | **Source:** `Logo.pas` decodes a four-byte-per-pixel RLE payload into `g_LogoSurface`; `ClMain` calls `CreateLogoSurface` and contains `DeviceRender` branches that draw/fade this global surface. **Reachability:** the sole unit is absent from `Mir3.dpr` and `ClMain`'s `uses` list despite those symbol references; its `LogoBitemp.inc` include was not found by the source-reader, leaving data and unit binding unresolved. **Difference:** the decoder has no source-length or output-run bound; failed lock/decode does not destroy/reset the surface, and no external `DestroyLogoSurface` caller was found. | Static Preview source only; no verified build, embedded pixels, runtime, or EI splash equivalence |
| Unlinked Client `MShare.pas` metadata records | **Source:** interface-only packed `TImagesInfo`/`TWMImages` records, `TImagesStatus`/`TWMFileType` enums, and WIL format/type fields. **Reachability:** the only import found is `DrawHint.pas`, itself unmapped and unreferenced; `Mir3.dpr` has no `MShare` entry, and no external consumer of the `MShare` metadata types was found. Its packed `TWMImages` record is distinct from `WIL.TWMImages`, an alias to `TWMBaseImages`. | Unlinked Preview declarations only; no wire/shared-memory/serialized ABI or EI contract established |
| Client `MaketSystem.pas` market-list cache | `Mir3.dpr` maps this Client unit; `ClMain` owns `g_Market`, dispatches `SM_MARKET_LIST` to `OnMsgWriteData`, then opens the dialog; `FState` renders its rows/pages and sends market requests through `ClMain`. The response parser reads a slash-delimited count/page header and `TMarketItem` records from `Common/Grobal2.pas`. **Difference:** `Load`, `OnMsgReadData`, and `Delete` are empty; `PageCount` overcounts exact multiples of ten; `Clear`/destruction leak `TList` containers, and the 120-row constant is unenforced. | Distinct from GameServer's same-named unit; source-level behavior only, with no client build, packet fixture, or EI equivalence
| Client `MapUnit.pas` current-map window and walk/door cells | `Mir3.dpr` maps `MapUnit`; `ClMain` owns the global `Map`, while `PlayScn` loads maps on test/map-change messages, moves the cached window, and renders from `MArrOb`; `ClMain`/`PlayScn` query movement and doors, and `HerbActor` marks castle/wall walkability. **Difference:** segmented loading and `CanFly` are stubs; map reads ignore byte counts and dimension bounds, and several cell/door APIs lack full bounds checks or leave Boolean results unset/false. | Preview Client map source only; no map-file fixture/runtime, binary-layout validation, or EI comparison
| Client `Mpeg.pas` DirectShow media wrapper | `ClMain` imports the unit and creates global `Video`; `ClMain`, `FState`, and `IntroScn` call `Play` for the WEMADE/start-game/create-character `.dat` paths, while `TimerBrowserUpdate` polls state/positions and stops playback. **Difference:** `Play` continues after failed initialization and swallows exceptions; `Close` unconditionally calls `CoUninitialize`; `GetState` can return without assigning its result, and no `Video.Free` caller was found. | `Mir3.dpr` has no explicit `Mpeg` mapping although `ClMain` uses it; no build, DirectShow runtime, media fixture, or EI asset comparison
| Client `Relationship.pas` romance-state manager | `Mir3.dpr` maps the Client unit; `ClMain` owns/creates `fLover`, parses `SM_LM_LIST` rows into manager entries, handles option/delete messages, and sorts friends by the lover name; `FState` renders its display rows and uses manager lookups for friend highlighting. **Difference:** `Delete` removes a lover entry without decrementing `FLoverCount`; the join-limit helpers depend on that counter but have no external Client caller, and no `fLover.Free` path was found. | Distinct from GameServer's same-named unit; no Common record, serialized-layout, or EI equivalence established
| Mapped but unreferenced Client `SingleInstance.pas` mutex helper | `Mir3.dpr` lists the unit, but no Client construction or `TSingleInstance.Initialize` call was found. **Difference:** the existing-instance path discards the `CreateMutex` handle without closing it; other `CreateMutex` failures can still return success, and the window-activation code is commented out. | Source mapping only; no app-level single-instance behavior or runtime test established
| Client `SoundUtil.pas` effect queue and BASS music paths | `Mir3.dpr` maps `SoundUtil`; `ClMain` creates/initializes `SoundManager`, effect/UI/actor code routes indexed sounds, and `PlayScn` resolves map tracks while `IntroScn`/`ClMain` call BASS playback. **Difference:** the worker starts before queue/critical-section setup and has no explicit Client stop/free path; list loaders misclassify `CreateFile` failure and skip read-count checks; the unused `PlayBGM` function returns an unassigned value, and saved `BoPlaySoundEffect` is not the gate used by `SoundUtil`. | Source only; no `.wwl`/audio fixture, build, playback runtime, or EI comparison
| Client `clEvent.pas` dynamic event renderer and manager | `Mir3.dpr` maps the unit; `ClMain` builds events from `SM_SHOWEVENT`, removes them on `SM_HIDEEVENT`, clears session state and frees the manager; `AxeMon` creates local dig effects, while `Actor` advances stone-pile state. `PlayScn` ticks/draws by tile row and applies event light. **Difference:** `ET_FIRE` leaves light set after effects are disabled, offscreen cleanup requires both axes to exceed 30, and only six of ten Common event tags have render cases. | Client source only; no map/image fixture, event runtime, or EI visual comparison
| Client `cliUtil.pas` shared draw and color helpers | `Mir3.dpr` maps the unit; `ClMain` assigns the shared `g_DXCanvas`, calls `LoadColorLevels`, uses `MakeDark` for fades, and copies errors to the clipboard; `Actor`, `AxeMon`, `HerbActor`, `PlayScn`, `FState`, and `IntroScn` use blend/shadow/effect helpers. **Difference:** `DrawFog`, `DrawFog2`, `MMXBlt`, and `SpriteCopy` are no-ops; `FogCopy` handles only 8-byte MMX chunks and has no active caller; color-table/cache APIs and `GetTempSurface` have no Client callers, while startup-created temp surfaces have no unload caller. | Preview Client source only; no rendering runtime, fixture, or EI comparison
| ImageEditor authoring utility | **Primary:** EI primary-static UI was not compared. **Source:** `ImageEditor.dpr`/`FrmMain` dispatch `.wil`/`.Lib` into `TWMM3DefImages`/`TWMMyImageImages` and invoke import/delete/export/conversion dialogs. **Difference:** no direct in-game UI or rendering correspondence is established | Preview authoring-tool source only; do not infer EI client behavior or primary asset appearance |
| ImageEditor Common EDCode line-format unit | **Primary:** EI protocol/wire equivalence was not compared. **Source:** `Source/Tools/ImageEditor/Common/EDCode.pas` exposes message, string and buffer APIs over its 6-bit encoder/decoder; the active loops use positional and public-key-byte XORs, while the declared substitution tables are not used. **Reachability:** no ImageEditor import/DPR entry or external caller of this copy was found. `Source/GameServer/EDCode.pas` and `Source/Common/EDCode.pas` are separate same-named units; `Server_JOB_ItemGen.dpr` explicitly maps to the latter. **Difference:** no build or wire-fixture comparison | ImageEditor copy unreferenced in checked source; no equivalence to the other EDCode copies asserted
| ImageEditor root `DES.pas` copy | **Primary:** EI asset/payload-cipher comparison not performed. **Source:** root-level `Source/Tools/ImageEditor/DES.pas` implements 16-round block operations; DPR-bound `wmMyImage.pas` calls `DecryBuffer` for an 8-byte library marker and routes 128-byte payload buffers through `FormatDataBuffer`. **Reachability:** `wmMyImage` imports unqualified `DES`; root `DES.pas` and `Common/DES.pas` both declare that unit name, and project search-path/build resolution was not verified, so these calls cannot be attributed to this root copy. `FormatImageInfo`'s buffer calls require `FCanEncry` and an empty password, while initialization sets `FCanEncry` only for a nonempty password. **Difference:** no EI copy/equivalence established | Preview `.Lib` handling only; string/hex wrappers have no active external ImageEditor caller; no protocol/MirDB mapping or cryptographic-suitability claim
| ImageEditor `Common/DES.pas` copy | **Primary:** EI cipher/asset comparison not performed. **Source:** this separate `DES` unit contains the permutation/S-box tables and 16-round core, plus string, hex, and buffer APIs. String helpers NUL-pad and decryption strips trailing NULs; buffer encryption adds `8-(length mod 8)` bytes (including a full block for aligned input), while buffer decryption processes complete blocks only and stops at the destination limit. **Reachability:** no explicit ImageEditor reference to this `Common/DES.pas` path was found; `wmMyImage` names `DES` unqualified, and the root sibling copy also declares it, so compiler selection is unverified. MapEdit explicitly selects a different `Source/Common/DES.pas` copy. **Difference:** no EI equivalence or runtime behavior established | Static Preview source only; no Delphi build, cipher fixture, or cryptographic-suitability claim
| ImageEditor embedded BASS payload | **Primary:** EI audio/resource equivalence not compared. **Source:** `DLLFile.pas` embeds a 98,872-byte I386 PE with a BASS 2.4.3 version resource and calls `TDLLLoader`. **Difference:** no `DLLFile`/`BassDLL` consumer or ImageEditor project reference connects this payload to an app callsite; ImageEditor Common `bass.pas` is an external API binding, not a consumer of the embedded `BassDLL` object | Unlinked source evidence only; no claim that the payload runs in ImageEditor, the Client BASS callsites use it, or it corresponds to EI
| ImageEditor Common BASS 2.4 API unit | **Primary:** EI audio/API equivalence not compared. **Source:** `Common/bass.pas` declares version `2.4` (`BASSVERSION=$204`) and external functions with platform library names `bass.dll`/`libbass.so`/`libbass.dylib`; local helpers are `BASS_SPEAKER_N` and a Windows EAX preset wrapper. **Reachability:** no ImageEditor BASS callsite or `ImageEditor.dproj` binding found. Client `ClMain.pas`/`SoundUtil.pas` call BASS APIs, but `Mir3.dpr` does not explicitly map `Bass`; `Source/Common/bass.pas` separately declares the same unit name, and actual resolution is unverified. **Difference:** the Client calls do not establish linkage to the ImageEditor Common unit or embedded BASS 2.4.3 payload | Static API declarations only; no ABI/build/runtime or EI equivalence asserted
| ImageEditor PE32 loader | **Primary:** EI loader/audio behavior not compared. **Source:** `DLLLoader.pas` implements an I386 PE mapper with import, relocation, entrypoint, and export stages. **Difference:** no ImageEditor consumer was found beyond the unreferenced `DLLFile` unit; load failures do not unwind, and `Unload` returns `FALSE` unconditionally | Static Preview-source behavior only; no runtime/security assessment or EI equivalence |
| ImageEditor file-drop helper | **Primary:** EI file-drop/UI behavior not compared. **Source:** `DropGroupPas.TDropFileGroupBox` enumerates `WM_DROPFILES` into a `TStringList`; **Difference:** deactivation passes the window handle to `DragFinish`, and no `DragFinish` handles the message's `HDROP`; `FrmAlpha` has no component instance/callback | Helper source only; it is imported but not used by the observed conversion dialog |
| ImageEditor HUtil32 imports and utility callers | **Primary:** EI helper/bitmap equivalence not compared. **Source:** ImageEditor forms/image units import `HUtil32` without a source path; observed uses include delimited offset/hint parsing, filename stems, min/max sizing, record/texture zero-fill and WIL transparent-mask drawing. `ImageEditor.dpr` lists root forms/image units but no HUtil32 source path; both root and `Common/HUtil32.pas` declare unit `HUtil32`, so these callsites cannot be assigned to the Common copy without verifying project search-path resolution. **Difference:** root and Common copies are separate sources | Static source only; no Delphi build, runtime, or EI behavior established
| ImageEditor Common `HUtil32.pas` copy | **Primary:** EI helper/string/bitmap equivalence not compared. **Source:** the 2,216-line CP949 unit implements token/number/date/file/pointer, palette, GDI, double-pack, SQL-token and high-byte text helpers. Its `EDCode`/`MfdbDef`/`mudutil` Common importers call `Str_ToInt`, `PackDouble`/`SolveDouble`, `FileCopy`/`FileCopyEx` and `GetValidStr3`; these Common units are not referenced by `ImageEditor.dpr` or elsewhere in the checked ImageEditor source. The ImageEditor forms' unqualified `HUtil32` calls cannot be assigned to this file. **Difference:** separate from root `HUtil32.pas`, whose interface differs; no build/path resolution was verified | Static Common-copy evidence only; no ImageEditor Common binding, Delphi build, runtime, or EI equivalence asserted
| ImageEditor Common `MfdbDef.pas` legacy file DB | **Primary:** no EI `System.db`/`Users.db` mapping established. **Source:** `TFileDB` composes conditional `THuman`/bag/magic/save records into raw file records with a sibling `.idx`; its index loader checks only selected metadata before accepting cached keys. **Reachability:** no ImageEditor importer/project binding or `TFileDB` callsite found. `Server_JOB_ItemGen.dpr` explicitly maps the separate `Source/Common/MfdbDef.pas`; source-wide `TFileDB` searches found only the two same-named unit definitions. **Difference:** `MIR2EI` build-layout selection and actual binary record sizes are unverified | Static Preview source only; no current System.db/Users.db equivalence, file fixture, Delphi build, or runtime asserted
| ImageEditor Common `ZLibEx.pas` compression unit | **Primary:** compression equivalence not compared. **Source:** `ZLibEx` exposes stream and buffer wrappers around deflate/inflate; regular buffer helpers allocate/grow outputs, but `CompressBufZ`/`DecompressBufZ` leave output allocation/resizing commented and swallow exceptions. `DecompressToUserBuf` raises its target-buffer-too-small resource for a nonnegative non-end result; negative results raise through `DCheck`. `TDecompressionStream.Read` routes inflate errors through `CCheck`/`ECompressionError`. **Reachability:** no active Common importer/caller found; `wmMyImage`'s `ZLibEx` import and `FrmAdd`'s `CompressBuf` call are comments, while `WIL` imports `ZLIB`. Third-party `Plug/DelphiZlib/ZLibEx.pas` declares the same unit name; path selection is unverified. **Difference:** no runtime, codec, or project-resolution comparison | Static Preview source only; no active Common `ZLibEx` path, Delphi build, runtime, or EI equivalence asserted
| ImageEditor Common `ZLibx.pas` compression unit | **Primary:** compression equivalence not compared. **Source:** the separate `unit ZLibx` exposes the legacy stream and buffer deflate/inflate APIs (version constant `1.0.4`); `CompressBufZ`/`DecompressBufZ` leave output allocation/resizing commented and swallow exceptions, and `TDecompressionStream.Read` uses `CCheck`/`ECompressionError`. **Reachability:** case-insensitive source-wide search found only unit declarations in ImageEditor Common `ZLibx.pas` and the separate `Source/Common/ZLibx.pas`; no caller or project binding found. **Difference:** it shares an API family with Common `ZLibEx`, but implementation identity and path resolution are unverified | Static Preview source only; no active `ZLibx` path, Delphi build, runtime, or EI equivalence asserted
| ImageEditor Common `mudutil.pas` utility unit | **Primary:** EI helper/gameplay equivalence not compared. **Source:** the 1,009-line unit provides sorted `TQuickList`/`TQuickIdList`, linear `TFindList`, validation/date/string helpers and abusive-word filtering. `TQuickList.QAddObject` reports success for a duplicate in a one-item list; `TQuickIdList.QAdd` uses `Objects[0]` when its equality branch matches a key at nonzero index, and the class has no destructor for remaining nested lists/allocated records. `CheckListValid`/`CheckListValidTrim` skip the last item; `SafeLoadFromFile` leaves global `FileMode=0`. **Reachability:** ImageEditor Common `MfdbDef` is the only ImageEditor reference found (`TQuickList`/quicksort); no ImageEditor DPR caller. GameServer utility callers exist, but `Source/Common/mudutil.pas` is separate; the only explicit project mapping found is `Server_JOB_ItemGen.dpr` to that separate path, so runtime unit resolution remains unverified. | Static Preview source only; no Delphi build, runtime, or EI equivalence established
| ImageEditor MyCommon version/system helpers | **Primary:** EI helper equivalence not compared. **Source:** `FrmMain.FormCreate` calls `GetFileVersion(ParamStr(0), @g_FileVersionInfo)` and appends `sVersion`; `ZShare` holds the version record, and `FrmMain.dfm:16` binds `OnCreate = FormCreate`. **Difference:** other process, CPU, disk, date, and version-resource helpers have no caller found | Static Preview-source evidence only; no runtime or EI equivalence asserted |
| ImageEditor MyD3DX9 Direct3DX bindings | **Primary:** EI graphics/import equivalence not compared. **Source:** root `MyD3DX9.pas` declares the D3DX9 SDK surface and local math helpers; `FrmOut.SaveTextureToFile` calls the ANSI `D3DXSaveTextureToFile` export for BMP/PNG/TGA/DDS, while `FrmAdd` only retains a commented texture-load example. **Difference:** SDK-family imports resolve in this source configuration to `d3dx9_31.dll`; the nested `Plug/MyDirect9/include/MyD3DX9.pas` copy remains separately excluded, and build-time unit resolution/DLL availability are unverified | Static Preview-source evidence only; no Delphi build, runtime, or EI equivalence asserted |
| ImageEditor WIL cache and decoder path | **Primary:** EI image-cache/decoder equivalence was not compared. **Source:** root `WIL.pas` defines the base class, cache lifecycle and zlib helpers, with a factory for `TWMM3DefImages`/`TWMMyImageImages`; observed ImageEditor opens select `ltLoadBmp`, and no external `GetCachedImage`/`DrawZoom` caller was found. **Difference:** the same-named MapEdit/Client WIL units (including legacy `MapEdit/o_WIL.pas`) were not reconciled with this root unit. | Preview ImageEditor source contract only; no build, runtime, or EI equivalence asserted |
| ImageEditor shared globals and utility paths | **Primary:** EI authoring-helper equivalence was not compared. **Source:** root `ZShare.pas` holds shared library/conversion, DX texture, palette, color, selection, version and progress globals; observed consumers cover import/delete/export and WIL→Lib conversion. Active helpers include PNG import, folder selection/search, and mapped-file splicing. **Difference:** `FrmAdd` ignores the PNG loader’s Boolean and add/delete callers ignore the mapped-file helper results. | Preview tool-source contract only; no EI client behavior, compiler, or runtime is established |
| ImageEditor M3Def decoder and WIL index | **Primary:** EI decoder equivalence was not compared. **Source:** root `wmM3Def.pas` reads WIL records and sibling `.WIX` offsets; WIX signature `$B13A0000` selects 24/28-byte index starts, and bitmap/direct-texture reads share a word-run decoder. **Difference:** active decoding omits the format-specific two-row handling present only in a commented implementation; index loading can report success after mapping/table failures and consume uninitialized offsets. | Preview source only; ImageEditor root unit is explicit in its project, while MapEdit/Client copies remain unreconciled; no Delphi/runtime or EI equivalence |
| ImageEditor MyImage `.Lib` reader and index writer | **Primary:** EI `.Lib` decoder/editor equivalence was not compared. **Source:** root `wmMyImage.pas` reads a packed header, offset list, per-image metadata and compressed payload; WIL factory dispatches `t_wmMyImage`, and the ImageEditor project enables its `WORKFILE` bitmap/texture/edit paths. **Difference:** payload bounds/read results are incompletely checked, zlib failure can reach nil-buffer consumers, index writes ignore I/O results, and RGB565 texture copies index rows by width rather than pitch | Preview ImageEditor source only; same-named MapEdit/Client units remain unreconciled; no Delphi/runtime or EI equivalence |
| MapEdit About dialog | **Primary:** EI editor/About counterpart not inspected. **Source:** `MapEdit.dpr` includes `about.pas` and auto-creates `Form1`; `About.dfm` labels it as the map editor and binds its OK button to `Button1Click` (`Close`). **Difference:** the menu item bound to `N10Click` calls `ShellAbout`; `Form1.ShowModal` is commented and no active display call was found | Preview MapEdit source only; no runtime/UI or EI equivalence established |
| MapEdit door marker dialog | **Primary:** EI door-marker editing was not compared. **Source:** `DoorDlg.UpdateEx` turns `DoorIndex` bit `$80` into a checkbox and edits the lower seven-bit index plus raw offset; parsed values are returned only on `mrOk`. **Difference:** the `mdDoor` map-click caller applies fields only on acceptance but marks the map `Edited` after the dialog call even when cancelled; inputs have no explicit range checks before assignment to byte fields | Preview MapEdit source only; no Delphi/runtime or EI equivalence asserted |
| MapEdit main form and map-data paths | **Primary:** EI editor and map-file equivalence were not compared. **Source:** `EdMain.pas` wires canvas editing/rendering, brush/mode controls, undo and dialogs; the DPR auto-creates its forms. **Difference:** main `LoadFromFile`/`SaveToFile` leave their I/O commented and return false; `.sem` segment routines are also commented. `MArr` is declared as `TTileInfo[]` while `TMapInfo` accessors treat it as map records, an unresolved source-level type mismatch | Preview MapEdit source only; DFM parsing/build/runtime and EI equivalence unverified |
| MapEdit object-image palette | **Primary:** EI palette/index equivalence was not compared. **Source:** `FObj` lists all 70 `WilArr` names, previews the selected object image at 0.5× or 1×, and its selection feeds `EdMain.DrawObject`. **Difference:** `EdMain.ObjWil` resolves only library indices 0–39 and otherwise returns `WilArr[0]`, so palette entries 40–69 route to that default in the observed source path; `GetCurrentIndex` uses only `ObjGrid.Col` | Preview MapEdit source/resource only; DFM row count and runtime/EI behavior unverified |
| MapEdit scroll-offset dialog | **Primary:** EI equivalent not compared. **Source:** `FScrlXY.Execute` parses both fields with `StrToIntDef(..., 0)` after `ShowModal`; the only observed MapEdit caller applies both offsets inside a `CopyTempBegin`/`CopyTempEnd` bracket. **Difference:** zero offsets enter fallback loops that zero the last column and row, and the handler does not set `Edited` | Preview MapEdit source/resource only; no Delphi/runtime/EI equivalence asserted |
| MapEdit HUtil32 helper unit | **Primary:** EI/Common helper equivalence was not compared. **Source:** the local copy implements string/token, numeric/bit/color, file/memory and GDI helpers; `BoolToCStr` and `Str_Catch` have empty bodies. **Difference:** MapEdit's DPR explicitly lists `..\..\Common\HUtil32.pas`, so the local copy's project/build reachability is unverified | Preview source only; no Delphi build/runtime or local/Common equivalence asserted |
| MapEdit ImgMan image-manager unit | **Primary:** EI image-loading/cache equivalence not compared. **Source:** declares screen, login, buffered-library and monster-image managers; no importer/caller found elsewhere under `Source`. **Difference:** the visible source has declaration/implementation mismatches, a malformed `TLoginImages.GetImage`, unchecked negative indices and an uninitialized/incorrectly indexed lazy-cache path | Preview source only; no Delphi build/runtime or EI equivalence asserted |
| MapEdit project entrypoint | **Primary:** EI startup and unit-resolution equivalence not compared. **Source:** `MapEdit.dpr` initializes VCL, creates `TFrmMain` first, then 13 more forms in fixed order before `Application.Run`; `HUtil32`/`DES` explicitly map to `Common`, while `WIL` maps to `Wil\WIL.pas`. **Difference:** `ImgMan.pas` is absent from the project uses list | Preview project source only; no Delphi build/runtime or EI equivalence asserted |
| MapEdit map-size dialog | **Primary:** EI dialog/resize semantics not compared. **Source:** `MapSize.Execute` defaults dimensions to 20×20 and parses accepted input with fallback 1; New and Resize both use it. **Difference:** New clears `MArr`/undo through `NewMap`, while Resize changes dimensions/canvas/cursor without a map-data snapshot or `Edited` update; DFM numeric spin limits were not recovered | Preview source/resource only; no Delphi/UI/EI comparison |
| MapEdit object-move tool | **Primary:** EI object-move/remove behavior not compared. **Source:** `CellMove1Click` opens the modeless `TFrmMoveObj`; Button1 offsets matching `FrImg` IDs and Button2 clears matching IDs. **Difference:** Button1 accepts any `y < 10`, including negatives, directly clears source cells outside the field-level undo helper, and can clear an object when the destination write is rejected at the final row; Button2's direct clears are not recorded in the temporary undo snapshot | Preview source/resource only; DFM parsing, Delphi/runtime, undo and EI behavior unverified |
| MapEdit object-piece editor | **Primary:** EI piece-set editor behavior not compared. **Source:** `TFrmObjEdit` edits background/middle/front images, marks, light, doors and animation in a modal copy; accepted callers duplicate the result into an object set. **Difference:** region selection normally appends only on acceptance, but `PasteSet` leaves `RowCount` stale and can make that path replace the last set before confirmation; arrow shifts bypass Ctrl+Z and the visible `Button1Click` body is commented out | Preview source/resource only; DFM tree incomplete and Delphi/runtime/EI behavior unverified |
| MapEdit small-tile palette | **Primary:** EI palette/selection behavior was not compared. **Source:** `SmTile` switches between 60-frame automatic middle-tile groups and a five-column individual-frame view; the clicked group/frame feeds `EdMain` map painting or `ObjEdit` pieces. **Difference:** individual-view `RowCount` uses `ImageCount div 5` and omits any remainder; automatic view creates one extra row beyond selectable groups. `FormCreate`'s combo population is commented out, and `EdMain.WilSmTile` refers to `WilSmTileArr`, for which no declaration appeared in the source-wide exact-name search; the initialized `WilArr` mapping is unresolved | Preview MapEdit source/mixed DFM only; parser recovers only two DFM entries, no Delphi/runtime or EI equivalence asserted |
| MapEdit tile palette | **Primary:** EI tile-selection behavior was not compared. **Source:** `Tile` supplies 50-frame auto-tile groups for `mbAuto` and five-column individual frames; `mbFill` uses the selected group to repaint matching map groups. **Difference:** individual rows floor-divide by five; grouped mode has an extra blank row and its last incomplete group's sample indices are not bounded by `ImageCount`. Combo population is commented out, and `EdMain.WilTile` references `WilTileArr`, whose declaration was not found in `Source`; initialization of `WilArr` does not resolve that mapping | Preview MapEdit source/mixed DFM only; parser recovers only two DFM entries, no Delphi/runtime or EI equivalence asserted |
| MapEdit light-value dialog | **Primary:** EI map-light editor was not compared. **Source:** `glight.GetValue` preloads the current value, opens a modal SpinEdit, then parses its text with fallback 0; the `mdLight` left-click path adds/replaces a light, while Alt-left updates only cells already having `Light > 0`. **Difference:** the caller ignores the modal result and marks the map `Edited` after either path; the DFM shows a `(0..4)` label and SpinEdit min/max properties, but scalar bounds are unrecovered | Preview MapEdit source/mixed DFM only; no Delphi/runtime/undo or EI equivalence asserted |
| MapEdit legacy tile palette | **Primary:** EI palette/attribute behavior was not compared. **Source:** `mpalett` previews `UNITBLOCK` groups in three columns and toggles per-row `Tile.atr` marks with F1. **Difference:** `UnitMax` starts at 0; EdMain's only `SetImageUnitCount` and palette-show calls are commented, while the Tile menu shows `FrmTile`. The attribute-driven `$8000` branch is also commented; palette reads use the current directory while saves use `BaseDir` captured at main-form creation | Preview source/mixed DFM only; parser recovers a form plus unknown grid type, no Delphi/runtime or EI equivalence asserted |
| MapEdit legacy `o_WIL.pas` image manager | **Primary:** EI image-library behavior was not compared. **Source:** a stand-alone `unit WIL` `TWMImages` component exposes BMP, full-memory, and WIX-offset/cache modes with palette and zoom helpers. **Difference:** `MapEdit.dpr` explicitly binds `WIL` to `Wil/WIL.pas`, whose `TWMImages` aliases `TWMBaseImages`; no `o_WIL` caller or data-file binding was found. In this legacy unit, cache limits are commented out, index loading leaks an unused record per entry, selected surface getters swallow errors, and destruction omits image/cache arrays | Preview source only; no Delphi build/runtime, image-file loading or EI comparison
| MapEdit project-selected `Wil/WIL.pas` image base | **Primary:** EI image loading was not compared. **Source:** `MapEdit.dpr` binds this unit; `TWMImages` aliases `TWMBaseImages`, whose factory creates MyImage or M3Def readers. `EdMain` initializes 70 relative `WilArr` library paths as MyImage/`ltLoadBmp` and falls back from failed `.Lib` initialization to `.wil`/M3Def. **Difference:** base initialization only opens the stream; subclasses read headers/indexes. The base surface-cache loader is a no-op, and M3Def does not override it; the observed EdMain bitmap path bypasses that cache. `DrawZoom`/bitmap/write APIs are `WORKFILE`-conditional, but no project-local define was found and build options are unverified | Preview source only; no Delphi build/runtime or library decoding; active selector identifiers in EdMain remain separately unresolved
| MapEdit M3Def image decoder | **Primary:** EI `.wil` loading was not compared. **Source:** failed MyImage `.Lib` initialization routes through the WIL factory to `TWMM3DefImages` on sibling `.wil`/`.WIX`; active decoder consumes 16-bit row tokens and builds bitmaps, with optional 16-bit-color-to-ARGB texture conversion. **Difference:** WIX loading opens the index twice and leaks the `FileOpen` handle; after that handle succeeds, mapping/allocation failures can still report success and reach an uninitialized offset pointer. Index/image reads and token decoding lack bounds checks; decode-buffer cleanup is not exception-safe. `CopyDataToTexture` has no MapEdit caller found | Preview source only; no Delphi build/runtime, malformed-file test, image-library load or EI comparison
| MapEdit unreferenced `wmM3Zip.pas` decoder | **Primary:** README D9 records a static layout comparison between Preview `wmM3Zip` and measured EI `MagicEx.wil/.wix`; no runtime decoder comparison was performed in this round. **Source:** `TWMM3ZipImages` has a sibling `.Idx` loader and a cached-texture decoder that skips six bytes before `DecompressBuf`; zero 16-bit pixels become transparent. **Difference:** no MapEdit source reference, WIL factory branch or verified caller was found. Index loading exposes no status and `InitializeTexture`'s result is ignored; WIL/`.Idx` header-read results, offset values and decompressed length are unchecked, an over-limit index count exits without closing its handle, compressed lengths 1–5 still trigger a six-byte read into the shorter allocation, texture writes ignore pitch, and output-buffer cleanup is not exception-safe | Preview source only; no Delphi build/runtime, decompression or texture exercise, or runtime EI decoder comparison
| MapEdit MyImage `.Lib` reader | **Primary:** EI `.Lib` decoding was not compared in this round. **Source:** the selected factory creates `TWMMyImageImages` for EdMain's initial libraries; failed MyImage initialization may fall back to sibling `.wil`/M3Def. `LoadDxImage` handles cached decoding; `WORKFILE` conditionally exposes bitmap, texture-copy and file/index edit APIs. **Difference:** after initialization, `FCanEncry` requires a nonempty password but `FormatImageInfo`'s crypto guard requires an empty one; data-buffer transformation touches only the first 128 bytes. Header/image-info read counts are unchecked, offsets are not file-bounded, index counts/uncompressed sizes are incompletely bounded, and several writes ignore byte counts. `SaveIndexList` compresses a 40-byte uninitialized prefix that `LoadIndex` skips. Direct edit/texture APIs have no MapEdit caller found; the project `WORKFILE` define/build settings remain unverified | Preview source only; no Delphi build/runtime, `.Lib` decoding, passworded fixture, editing or EI comparison
| MapEdit unselected `wmUtil.pas` helpers | **Primary:** EI palette/conversion behavior was not compared. **Source:** defines a 256-entry byte-to-word table, a 65,536-entry word conversion table, x86 `Move`/line helpers, a 1024-byte palette copied to `PotoPalette`, and zlib wrappers. **Reachability:** MapEdit.dpr selects `Wil/WIL.pas`; within MapEdit, only the old, unselected `o_WIL.pas` imports this unit. The selected WIL unit defines its own ZIP helpers, and no selected-path caller of the conversion/palette helpers was found. A separate `Source/Client/wmUtil.pas` exists and was not equated with this copy. **Difference:** the line converters do not guard nonpositive counts, and on in-try errors the zlib wrappers suppress exceptions, set the output to nil, and retain the current `Result` length; no build/runtime or EI comparison | Preview source only; no Delphi/compiler/runtime/pixel or EI comparison
| MapEdit segment-project form | **Primary:** EI segment workflow was not compared. **Source:** `segunit` derives names from the project ID and grid row/column, stores a packed project-metadata record, and passes a visible 3×3 selection of 40×40 `.sem` names to `EdMain`. **Difference:** EdMain's `LoadSegment`/`SaveSegment` bodies are entirely commented, so these callbacks do not load/save segment-map data; `LoadFromFile` checks `Handle` rather than `fhandle`, `BtnOpen` ignores its result, and `BtnEdit` continues after No/Cancel. The DPR auto-creates the form, but its only located menu `Show` call is commented | Preview source/mixed DFM only; parser reports grid type `0x12` as unknown; no Delphi/runtime or EI equivalence asserted
| 差异 | 源码只读 `Mud3-Config/Envir/`（Mir2 风格 391 txt）；`Mud3-Config/Envir3/`（1729 txt + 69 `.gen`）在整个包内 grep 命中 **0 次** → **本版源码不读 Envir3** |
| 结论 | `Envir3/` 属另一/更新构建，只能当**独立参考资料**（含 `QuestDiary/` 任务脚本树、`Mon_Def/*.gen` 刷怪定义）；DataBaseServer 的 SQL player-record schema is not a verified mapping to the EI `.db` files |
| 处理 | 本仓库 `Tools/questdata`、dbeditor workspace 与 `Envir3/` 的对照**必须标注**「源码不读它」这一前提；`tablesdefine.cpp` 只按 legacy SQL schema 记录 |

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
（来源 `${MIR3_EI_ROOT}/Data/GameInter.wil`）。

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

---

## 0.6 全量精读状态（2026-09-26 收尾）

**来源**：`coverage-ledger.tsv`（393 个源码文件逐一登记）。
**复现**：`python3 Tools/source-read/ledger.py --summary`

| 状态 | 文件数 | 行数 | 占比 |
|---|---:|---:|---:|
| `covered`（已精读并写入文档） | 27 | 29,884 | 9.5% |
| `partial`（读了主要结构/区段） | 21 | 99,738 | 31.6% |
| `excluded`（第三方，明确排除） | 43 | 60,230 | 19.1% |
| `pending`（待读） | 302 | 125,472 | 39.8% |
| **合计** | **393** | **315,324** | 100% |

**已读覆盖**：`covered + partial = 129,622 行（41.1%）`。

### 0.6.1 本轮（Round 810–820）新增的文档

| 文件 | 内容 |
|---|---|
| [`magic.md`](magic.md) | 技能系统：4 块 26 条分派、三伤害公式、符咒、击退概率 |
| [`monsters.md`](monsters.md) | 71 个怪物类、AI 核心（`Think`/`AttackTarget`/`Run`）、A\* 死代码 |
| [`items-systems.md`](items-systems.md) | 装备升级两公式、**攻速有符号编码**、玩法系统 |
| [`client-internals.md`](client-internals.md) | 按钮四态、`TDGrid`、**背包几何 6×8@38**、`+6` 偏移 |
| [`client-rendering.md`](client-rendering.md) | **动作帧公式** `start + Dir*(frame+skip)`、46 表 329 项 |
| [`tools-and-servers.md`](tools-and-servers.md) | 工具链、登录/DB 服、**3 个缺失 opcode 定案** |

### 0.6.2 本轮新增的机器可读产物

| 文件 | 行数 | 内容 |
|---|---:|---|
| [`coverage-ledger.tsv`](coverage-ledger.tsv) | 394 | 393 个源码文件的阅读状态 |
| [`gm-commands.tsv`](gm-commands.tsv) | 162 | **GM 命令 131 条**（含韩文别名与动作） |
| [`quest-opcodes.tsv`](quest-opcodes.tsv) | 129 | **任务脚本语言 53 条件 + 75 动作** |
| [`config-parsers.tsv`](config-parsers.tsv) | 95 | 19 个配置解析器 / 94 字段读取点 |
| [`magic-dispatch.tsv`](magic-dispatch.tsv) | 27 | 26 条 MagicId 分派（4 个 case 块） |
| [`monster-classes.tsv`](monster-classes.tsv) | 72 | 71 个怪物类层次 |
| [`actor-frames.tsv`](actor-frames.tsv) | 330 | **46 个动作表 / 329 项** |
| [`client-runtime-layout.tsv`](client-runtime-layout.tsv) | 346 | 345 项运行时窗口几何 |

### 0.6.3 本轮新增的工具（`Tools/source-read/`）

`ledger.py`（销账台账）、`extract_gm_commands.py` + `gm_to_markdown.py`、
`extract_quest_opcodes.py`、`wemade_decrypt.py`、`extract_config_parsers.py`、
`extract_magic_dispatch.py`、`extract_monster_classes.py`、
`extract_runtime_layout.py`、`extract_actor_frames.py`、
`verify_missing_opcodes.py`、`env_compare.py`。

### 0.6.4 本轮的两项**修正**（前序阶段的错误结论）

1. **屏幕基准**：初版称「Preview 是 1024×768+，与原版 800×600 不同」
   —— **错**。`ClMain.pas:25-26` 明确 `SCREENWIDTH=800`/`SCREENHEIGHT=600`，
   两版**同为 800×600**。DFM 的 1095×975 只是编辑期画布（`client-windows.md` §8）。
2. **A\* 寻路**：初版称「`astar.h` 有 A\* 实现」—— **不准确**。
   `astar.h` **无任何 `#include`**（仅工程文件列出），是**死代码**；
   实际寻路是贪心 8 方向（`monsters.md` §4）。

### 0.6.5 未破译项已清零

`config.md` §7 曾登记 3 个「未破译的私有编码」任务脚本
（`Nm_Chiken`/`Nm_Cow`/`Nm_OmaJunsa`）—— **本轮已破译**：
它们是 **WEMADE 加密**（`EDCode.pas:465-522` 的 `Decrypt`），
工具 `Tools/source-read/wemade_decrypt.py`。扫描确认 `QuestDiary/` 全树
443 个文件**只有这 3 个加密**，现已全部可读（`server.md` §13.10）。
