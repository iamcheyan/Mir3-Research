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
| 客户端窗口集 | 13 个主窗口（HUD 底部操作栏体系） | 26 个 `D*Dlg`，**无任务窗** |
| 编码 | GBK 文本 | `Source/**` = CP949，`Mud3-Config/**` = GB18030 |

**读源码前必读**：`Source/**` 注释是 CP949，`rg`/`grep` 对中文/韩文关键字**直接失效**。
先转码：`iconv -f cp949 -t utf-8 -c <file>`（个别文件有非法序列，必须加 `-c`）。
协议常量与标识符是 ASCII，不受影响。

---

## D1. 协议 opcode 语义（最高价值，已部分闭合）

### D1.1 `0x409` = `CM_WANTMINIMAP`

| | |
|---|---|
| 原版（F321） | `0x451770` = msg **0x409**（地图查询，ret 0）；唯一调用者 `0x42C259`（HUD 小地图 cap1），`GetTickCount` 3s 冷却 + `[0x6210]` 上次时刻 + `[0x6518]` 状态 |
| 源码 | `CM_WANTMINIMAP = 1033`（`Common/Grobal2.pas:1732`）；客户端 `ClMain.pas:4676` `SendWantMiniMap`；服务端 `ObjBase.pas:25170` → `ServerGetWantMiniMap`（`:28529`）回 `SM_READMINIMAP_OK=710` / `FAIL=711`（`Param` = `PEnvir.MiniMap`） |
| 差异 | **无**。原版 3s 冷却常量 `0xBB8` = 源码 `GetTickCount + 3000`（`FState.pas:7746`），逐字节一致 |
| 结论 | 业务名闭合为「请求当前地图的小地图索引」。`[+0x6210]` 写点 = 客户端点击处理器自身（非服务端回包） |
| 处理 | 已写入 RESEARCH_LOG Round 802-A；`hud-caption-action-tail-evidence.json` 的业务名可从 candidate 升级，**但须保留 primary-static 的 opcode/调用点原文** |

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
4. **编码**：读 `Source/**` 必须 `iconv -f cp949 -t utf-8 -c`；读 `Mud3-Config/**`
   必须 `iconv -f gb18030 -t utf-8`。
5. **安全**：`LoginSvr.ini`/`DBSvr.ini` 含 `sa/sa`，禁止入库；`Mud3-Config/Envir*/adminlist.txt`
   只是 GM 角色名，非凭据。
6. **不写库**：本目录的所有工作均为只读研究，`database_write=false` 维持。
