# Mir3 Preview Version — 源码与服务端配置参考

《传奇3》复刻版预览版的**完整源码 + 服务端文本配置**。2026-09-26 从仓库根目录的
`Mir3 Preview Version.rar`（RAR5，53 MB）解出，按公开仓库规则筛选后收录。

- 收录：**2636 个文件 / 约 18 MB**（源码 ~13 MB / 443 文件 + 配置 ~6 MB / 2193 文件），另加本 README
- 排除：构建产物、二进制、巨型生成查表、1.3 GB 运行环境 —— 清单见 [§5](#5-排除清单)

---

## 1. 来源与性质

| 项 | 值 |
|---|---|
| 原始包 | `Mir3 Preview Version.rar`（53 MB，RAR5，仓库根目录） |
| 内层包 | `Source.rar` 11 MB · `Mud3 Preview.rar` 43 MB · `Client.rar` 1.1 MB · `ODBC Data Source.rar` 849 B |
| 版本标识 | 客户端 `Mir3.dpr` 标题 `Legend Of Mir 3 Development`；ODBC 注册表名 `传奇3复刻版建立ODBC数据源` |
| SVN 出处 | `https://code.lom2.com/svn/Mir2`（LOM2 社区仓库；目录名仍叫 Mir2，代码已改造为 Mir3） |
| 代码年代 | 文件时间戳 2002–2019；C++ 工程为 VS2003（`.vcproj Version="7.10"`） |
| 语言基准 | `GameServer/svMain.pas` 中 `KOREANVERSION = TRUE`，其余版本开关为 `FALSE` → **服务端以韩版为基准** |
| 运营者标识 | `Envir3/adminlist.txt` 与 `Mon_Def/*.gen` 注释中出现 `海メ盗` |

> 这是第三方社区源码（LOM2/Mir2 系），非本项目原创。收录目的是**对照逆向**，
> 尤其用于验证本仓库 `Tools/` 下各工具对协议、图库、数据格式的推断。

---

## 2. 目录结构

```
reference/mir3-source/
├── README.md                  ← 本文件
├── Source/                    ← 源码（13 MB / 443 文件，~20 万行游戏代码）
│   ├── Client/                Delphi Win32 客户端          63,357 行
│   ├── Common/                客户端+服务端共享单元        14,836 行
│   ├── GameServer/            Delphi 游戏逻辑服            79,769 行
│   ├── DataBaseServer/        C++/MFC 数据库服             23,349 行
│   ├── LoginServer/           C++/MFC 登录服               18,157 行
│   └── Tools/                 Delphi 编辑器工具           115,955 行（含 62,337 行第三方）
└── Mud3-Config/               ← 服务端文本配置（6 MB / 2193 文件）
    ├── Envir/                 Mir2 风格配置（391 个 .txt）
    └── Envir3/                Mir3 风格配置（1729 个 .txt + 69 个 .gen）
```

**技术栈构成**：Delphi/Object Pascal（163 `.pas` + 27 `.dfm` + 4 `.dpr`）为主，
C++/MFC（82 `.cpp` + 128 `.h` + 3 `.sln`）负责登录服与数据库服。

---

## 3. 代码导览

### 3.1 协议 —— 建议从这里开始

| 文件 | 行数 | 说明 |
|---|---|---|
| `Source/Common/Grobal2.pas` | 2862 | **协议总表**：392 个 `CM_*`/`SM_*` 消息常量 + 包结构 record |
| `Source/Common/Grobal2 - 副本.pas` | 2599 | 旧版本备份，比正本少 263 行 —— **diff 两份可看出协议演进** |
| `Source/Tools/ImageEditor/Common/Grobal2.pas` | — | 第三份副本 |
| `Source/LoginServer/LoginServer/protocol.h` | — | C++ 侧登录服协议 |
| `Source/DataBaseServer/Def/Protocol.h` | — | C++ 侧数据库服协议 |

### 3.2 客户端（Delphi，63k 行）

- 入口：`Source/Client/Mir3.dpr` → `TFrmMain`（在 `ClMain.pas`，9924 行）
- 核心：`FState.pas` 14853 行（主游戏窗体/交互）、`DWinCtl.pas` 7804 行（窗口控件）
- 渲染：`Actor.pas` 4743 · `AxeMon.pas` 4217 · `HerbActor.pas`（角色/怪物）
- 图库：`WIL.pas` · `uWilFile.pas` —— WIL/WIX 解码
- 图像/压缩：`wmUtil.pas` 4497 · `wmM2Zip.pas` · `wmM3Zip.pas` · `wmMyImage.pas` · `wmM2Def.pas` · `wmM3Def.pas`
- 场景：`MapUnit.pas` · `DrawScrn.pas` · `PlayScn.pas` · `IntroScn.pas`
- 其他：`magiceff.pas`（魔法特效）· `SoundUtil.pas` + `Common/bass.pas`（BASS 音频）
- 光照：`Light/Light0a–0d.pas`（配套的 8.1 MB `.inc` 查表已排除，见 [§5](#5-排除清单)）

### 3.3 游戏逻辑服（Delphi，80k 行）

- 入口：`Source/GameServer/Server_JOB_ItemGen.dpr` → `TFrmMain`（在 `svMain.pas`）
  - ⚠️ **工程名 `Server_JOB_ItemGen` 有误导性**，它就是游戏服主程序，产出 `Mir3.exe`
- `ObjBase.pas` **31768 行** —— 全仓库最大文件，玩家/怪物/NPC 的对象基类
- `ObjNpc.pas` 6409 行 —— NPC 脚本引擎；`Envir.pas` —— 世界环境/地图/刷怪
- 玩法系统：`Magic.pas` · `itmunit.pas`（技能/物品）· `Guild.pas` 3600 · `Castle.pas`（行会/攻城）
  · `DragonSystem.pas` · `Mission.pas` · `Event.pas` · `TagSystem.pas`
  · `FriendSystem.pas` · `Relationship.pas` · `UserSystem.pas`
- 会话/连接：`UsrEngn.pas` 3696 · `UserMgrEngn.pas` · `UserMgr.pas` · `RunSock.pas` · `MasSock.pas`
- 数据访问：`SqlEngn.pas` · `DBSQL.pas` · `SQLLocalDB.pas` · `LocalDB.pas`
- GM 命令：`CmdMgr.pas`

### 3.4 登录服（C++/MFC，18k 行）

- 入口：`LoginServer/LoginServer/mir2wnd.cpp:420` `WinMain`
- 监听：`netloginsvr.cpp`（`CLoginSvr`）
- 出向连接：`netlogingate.cpp`（`CLoginGate`）· `netgameserver.cpp`（`CGameServer`）
  · `netcheckserver.cpp`（`CCheckServer`）· `netUdpsender.cpp`（`CUdpsender`）
- 编解码：`Common/mir2packet.cpp` · `Common/endecode.cpp`
- `_Oranze Library/` —— 自研基础库：`netiocp.cpp`（IOCP 网络）· `astar.h`（A* 寻路）
  · `database.cpp` · `base64.cpp` · `http.cpp` · `pop3.cpp` · `vtimage.cpp` · `syncobj.cpp` · `bstree.h`

### 3.5 数据库服（C++/MFC，23k 行）

- 入口：`DataBaseServer/DBSvr/mir2wnd.cpp:411` `WinMain`
- 监听：`netdbserver.cpp`（`CDBServer`）
- 出向连接：`netgameserver.cpp` · `netloginserver.cpp` · `netrungate.cpp`
- SQL/ODBC 层：`Common/sqlhandler.cpp` + `Def/database.cpp`；表定义 `DBSvr/tablesdefine.cpp`

### 3.6 工具（Delphi，116k 行）

| 路径 | 行数 | 说明 |
|---|---|---|
| `Tools/MapEdit/` | 16,298 | 地图编辑器（`MapEdit.dpr`） |
| `Tools/ImageEditor/`（顶层） | 26,733 | 图库编辑器（`ImageEditor.dpr`） |
| `Tools/ImageEditor/Plug/` | 62,337 | **第三方组件**：GraphicEx · MyDirect9(DX9 封装) · pngimage · DelphiZlib |

> 看游戏逻辑时**不要**把 `Plug/` 当成游戏代码；它占 Tools 的一半以上。

### 3.7 服务进程拓扑与端口

依据 `Mud3 Preview` 各 `*.ini` 与 C++ `net*.h` 的类关系推断（gate 的 `ServerPort` = 其上游服务端口）：

```
客户端
 ├─ 7000 ─→ LoginGate   ──5500→ LoginServer（LG_BPORT=5500）
 ├─ 7100 ─→ SelChrGate  ──5100→ DataBaseServer（RG_BPORT=5100）
 └─ 7200 ─→ RunGate     ──5000→ GameServer
                                    │
                                    └─6000→ DataBaseServer（GS_BPORT=6000）
                                                  │
                        DataBaseServer ──5600→ LoginServer（LS_CPORT=5600）
                                                  │
                        DataBaseServer ──ODBC──→ SQL Server 2000
```

| 配置键 | 值 | 含义 |
|---|---|---|
| LoginGate `GatePort` / `ServerPort` | 7000 / 5500 | 客户端入口 / 上游 LoginServer |
| SelChrGate `GatePort` / `ServerPort` | 7100 / 5100 | 客户端入口 / 上游 DataBaseServer |
| RunGate `GatePort` / `ServerPort` | 7200 / 5000 | 客户端入口 / 上游 GameServer |
| LoginServer `LG_BPORT` / `GS_BPORT` / `CS_BPORT` | 5500 / 5600 / 3000 | 监听 LoginGate / 监听 DataBaseServer / 其他 |
| DataBaseServer `GS_BPORT` / `RG_BPORT` / `LS_CPORT` | 6000 / 5100 / 5600 | 监听 GameServer / 监听 SelChrGate / 连 LoginServer |

---

## 4. 配置数据（Mud3-Config）

两套配置目录并存，**格式与用途不同**：

| 目录 | 规模 | 风格 | 代表文件 |
|---|---|---|---|
| `Envir/` | 391 `.txt` | Mir2 风格 | `Mapinfo.txt` `1MapInfo.txt` `MonGen.txt` `MerChant.txt` `Npcs.txt` `GuardList.txt` `Npc_Def/` `Market_Def/` `MonItems/` `Castle/` `QuestDiary/` |
| `Envir3/` | 1729 `.txt` + 69 `.gen` | Mir3 风格 | `Mon_Def/*.gen` `MonItems/` `QuestDiary/` `Market_Def/` `GM_Def/` `Flag_Def/` `Convert_Def/` `StartPoint.txt` |

**哪一套是源码真正读的**：`Envir/`。证据链：

- `GameServer/svMain.pas:619` → `EnvirDir := ini.ReadString('Share','EnvirDir','.\Envir\');`
- `GameServer/Setup/!Setup.txt` → `EnvirDir=.\Envir\`（同时 `MapDir=.\Map\`、`CastleDir=.\Envir\Castle\`）

**`Envir3/` 在本包中零引用** —— 对整个解出包 grep `Envir3` 命中 **0 次**。
它是一套并存的更新版配置（含 `Mon_Def/*.gen` 刷怪定义、`QuestDiary/` 任务脚本树、
`Flag_Def/`/`GM_Def/`/`Convert_Def/`），推测属于另一个/更新的服务端构建，
本版源码不会读它。研究时别把它当成 `Envir.pas` 的输入。

源码实际按名读取的配置（部分，见 `GameServer/*.pas` 字符串常量）：
`MapInfo.txt` `MonGen.txt` `Merchant.txt`/`merchant.txt` `Npcs.txt` `GuardList.txt`
`AdminList.txt` `MiniMap.txt` `StartPoint.txt` `SafePoint.txt` `MakeItem.txt`
`DecoItem.txt` `DragonItem.txt` `GenMsg.txt` `MapQuest.txt` `UnbindList.txt`
`StartupQuest.txt` `AttackSabukWall.txt` `Sabuk.txt` `enckey.txt`。

> 小注意：`Envir/` 下同时存在 `Mapinfo.txt`（4507 行）与 `1MapInfo.txt`（3320 行），
> 内容不同 —— 后者是手工保留的备用地图表（文件名带字面 `1`，非大小写冲突）。

---

## 5. 排除清单

未收录内容与原因（需要时从原 rar 重新取）。

### 5.1 巨型生成查表（`.inc`，6 个唯一文件，约 10.5 MB）

均为**编译期生成的查表数据**，非逻辑代码：

| 文件 | 大小 | 内容 |
|---|---|---|
| `Client/Light/Light0a.inc` | 645 KB | `LightBuffer: array[0..122820-1] of Byte`（原始像素） |
| `Client/Light/Light0b.inc` | 1.89 MB | 同上 |
| `Client/Light/Light0c.inc` | 2.12 MB | 同上 |
| `Client/Light/Light0d.inc` | 3.48 MB | 同上 |
| `Client/LogoBitemp.inc` | 1.18 MB | `LogoBuffer: array[0..225308-1] of Byte`（原始像素） |
| `Client/BitChange.inc` | 479 KB | `X8_A1R5G5B5: array[Byte] of Word` —— **色彩格式转换 LUT** |

`BitChange.inc` 在 3 处各有一份副本：`Client/` · `Tools/MapEdit/Wil/` · `Tools/ImageEditor/`。
该表是 A1R5G5B5 等 16 位色格式的转换查找表，**与本仓库 `.Zl`/WIL 解码研究相关**，
需要时值得单独取回。

> 保留的小型 `.inc`（7 个）：`Jedi.inc` `Blowfish.inc` `bitconv32.inc` `DirectX.inc`
> `lineasm.inc` `pixasm.inc` `ZLibEx.inc`。

### 5.2 二进制与构建产物

- **二进制**：`*.dcu` `*.obj`（含 `Common/*.OBJ` 预编译 zlib 共 9 个）`*.lib` `*.dll`
  （`vic32.dll`、`d3dx9_31.dll`）`*.exe` `*.pdb` `*.bpl` `*.chm` `*.drc` `*.dcr` `*.ico` `*.bmp`
- **Delphi 资源**：`*.res`（含 `ColorTable.RES` 调色板数据资源，运行工具需要，读代码不需要）
- **构建/IDE 目录**：`.svn` `__history`(×3) `Dcu` `Release` `out` `obj` `_bin` `_Bin`
  `_Obj_Debug` `_Obj_Release`
- **IDE 状态**：`*.ncb` `*.suo` `*.idb` `*.pch` `*.aps` `*.dof` `*.cfg` `*.dproj.local`
  `*.identcache` `*.map`（链接器 map）
- **内嵌 rar**：`Tools/ImageEditor/Release/*.rar`（3 个，3.15 MB，图像编辑器发布包）

### 5.3 运行环境与数据库（Mud3 Preview，1.3 GB，全部排除）

- `SQL/`（687 MB）—— SQL Server 2000 数据库（`Binn` `Data` `MakeSQL文件.exe`），
  **System.db 的上游**
- `GameServer/{Map,Log,ConLog,GuildBase,MissionBase,Notice,Setup,Share,ShareV}`
- 各服务 exe：`GameServer/Mir3.exe` `DBSvr.exe` `LoginSvr.exe` `*Gate.exe`
- `Client.rar` 全部内容：`Mir3.exe`(3.6 MB) `bass.dll` `Mir3.ini` `MInfo.dat` `Magic.exp`
  `Weapon.ord` `*List.wwl`
- `ODBC Data Source.rar`：2 个 `.reg`（32/64 位 ODBC 注册表导出，UTF-16）

### 5.4 Envir/Envir3 内排除的二进制

| 项 | 数量 | 说明 |
|---|---|---|
| `Envir/Market_Saved/*.sav` | 84（2.19 MB） | 二进制市场存档 |
| `Envir/Market_Prices/*.prc` | 84 | 二进制市场价目 |
| `Envir/Market_Upg/*.upg` | 1 | 二进制市场升级记录 |
| `Envir3/*.dat` | 5 | `magic.dat` `monster.dat` `stditem.dat` 等 —— **Mir3 二进制数据表**，本仓库逆向的核心对象，但为二进制且被 `.gitignore` 的 `*.dat` 拦截 |
| `Envir3/Mir3param.exe` · `*.bak` · `*.svn-base` · `.svn/` | — | 可执行文件 / 备份 / SVN 元数据 |

### 5.5 已收录但**非纯文本**的例外

- **15 个二进制 DFM**（`ClMain.dfm` `FState.dfm` `Tools/MapEdit/*.dfm` 等）：
  Delphi 二进制窗件格式，属性名/字符串值可读但夹有二进制标记字节
  （典型可打印率 81–83%）。**保留原因**：它是窗件布局的唯一来源，`.pas` 里的
  `Timer1: TTimer` 这类控件声明靠它才能对应到界面。转文本需 Delphi 的 `convert.exe`。
  其余 12 个 `.dfm` 是纯文本。
- **3 个编码/加密 `.txt`**（`Envir3/QuestDiary/NQ_BASE/MonQuest/`
  `Nm_Chiken.txt` `Nm_Cow.txt` `Nm_OmaJunsa.txt`，342–881 B）：
  非 GB18030/cp949 文本，`iconv` 在首字节即失败；字节呈
  `… 72 6c 6e 6c 6a 6c … 0e 0c 0a 0c 0e 0c …` 的定长对模式
  （每对的低字节低位恒为 `0xC`），疑似 Mir3 MonQuest 的私有编码。**未破译**。

### 5.6 未纳入 git 的文件

本目录内的文件**全部可入库**（`git check-ignore` 零命中，见 [§9](#9-复核方式)）。
被排除在 git 之外的是**上游原始素材**，不是本目录的内容：

| 文件 | 大小 | 处理 | 理由 |
|---|---|---|---|
| `Mir3 Preview Version.rar` | 53 MB | 加入 `.gitignore` 的 `*.rar` 规则（与既有 `*.7z`/`*.zip` 一致） | 公开仓库不放大型二进制；其内容已按 §5.1–5.4 筛选后入库 |
| `/tmp/mir3-preview/` | ~1.4 GB | 不在仓库内 | 解压工作区，含被排除的 1.3 GB 运行环境与 SQL 库 |

需要取回被排除的内容（`BitChange.inc`、`Mir3.exe`、`magic.dat`、`SQL/` 等）：

```bash
# 注意：p7zip 17.05 打不开 RAR5，本机用 unrar-free（libarchive 版）
UNRAR=$(ls /nix/store/*-unrar-free-*/bin/unrar-free | head -1)
mkdir -p /tmp/mir3-preview && cd /tmp/mir3-preview
"$UNRAR" -x -f "/home/tetsuya/development/Mir3-Research/Mir3 Preview Version.rar" .
cd "Mir3 Preview Version"
for a in Source Client "Mud3 Preview" "ODBC Data Source"; do
  mkdir -p "x_$a" && "$UNRAR" -x -f "$a.rar" "x_$a"
done
```

---

## 6. 编码注意事项

| 范围 | 编码 | 读取方式 |
|---|---|---|
| `Source/**` 的 Pascal/C++ 注释 | **CP949（韩文）** | `iconv -f cp949` |
| `Mud3-Config/**` 文本 | **GB18030/GBK（中文）** | `iconv -f gb18030` |

例：`Source/Common/Grobal2.pas` 注释 `//게이트와 서버 통신에 사용`（网关与服务器通信用）。

- 直接以 UTF-8 打开会乱码；VSCode 需手动切换编码，`rg`/`grep` 对中文/韩文关键字无效。
- 与本仓库 `AGENTS.md` §九.9 记录的 GB18030 坑同源。
- 检索中文配置时先转码，例如：
  ```bash
  iconv -f gb18030 -t utf-8 Mud3-Config/Envir3/Mon_Def/!Lv0_Animal.gen
  ```

---

## 7. 与本仓库工具链的对应关系

这份源码是 `Tools/` 下多项逆向结论的**权威对照源**：

| 本仓库 | 对照位置 |
|---|---|
| `Tools/wsgateway`（packet id 反射导出） | `Common/Grobal2.pas` 的 392 个 `CM_*`/`SM_*`；`protocol.h` |
| `Tools/common/wilsdk.py` | `Client/WIL.pas` · `Client/uWilFile.pas` |
| `Tools/common/zlsdk.py`（`.Zl` 容器） | `Client/wmM3Zip.pas` · `wmM2Zip.pas` · `Common/ZLibEx.pas` |
| `Tools/item_icon_extractor`（`zldecode`） | `Tools/ImageEditor/` 的图库读写逻辑 |
| `Tools/maps/mapviewer.py` | `GameServer/Envir.pas` + `Mud3-Config/Envir*/MapInfo.txt` `MiniMap.txt` |
| dbeditor workspace 的 NPCInfo/MapRegion/MovementInfo | `Mud3-Config/Envir3/` 的 NPC/地图定义 |
| `Tools/SystemDbProbe` / `DBImporter`（System.db） | `DataBaseServer/` + 被排除的 `SQL/`（System.db 的上游 SQL 库） |
| `Tools/questdata`（QuestInfo） | `GameServer/Mission.pas` `itmunit.pas` + `Mud3-Config/Envir3/QuestDiary/` |
| `Client/Mir3.ini` 的 `Param1=7000` | 与 `LoginGate/mirgate.ini` 的 `GatePort=7000` 一致 |

> ⚠️ **不要**把被排除的 `LoginSvr.ini` / `DBSvr.ini` 复制进仓库 —— 它们含
> `ODBC_ID=sa` / `ODBC_PW=sa`（SQL Server 2000 默认口令）。已收录的
> `Envir/AdminList.txt`（`* admin` `* admin1`）与 `Envir3/adminlist.txt`（`* 海メ盗`）
> 只是 GM 角色名，非凭据。

---

## 8. 建议阅读路线

1. **协议先行** —— `Source/Common/Grobal2.pas`（392 消息常量 + 包结构），
   顺手 diff `Grobal2 - 副本.pas` 看协议演进。
2. **定拓扑** —— 读 [§3.7](#37-服务进程拓扑与端口)，挑一条链路深入。
3. **客户端** —— `Mir3.dpr` → `ClMain.pas` → `FState.pas`；
   想看资源格式转 `WIL.pas` / `wmM3Zip.pas`。
4. **服务端** —— `Server_JOB_ItemGen.dpr` → `svMain.pas` → `ObjBase.pas`（31k 行，重头）；
   玩法逻辑按 [§3.3](#33-游戏逻辑服delphi80k-行) 的清单按需跳读。
5. **C++ 侧** —— 先 `_Oranze Library/netiocp.cpp` 理解网络框架，再看各 `net*.cpp` 的业务。
6. **配置对照** —— 边读 `Envir.pas` 边翻 `Mud3-Config/Envir/`（这才是源码读的那套）；
   `Mud3-Config/Envir3/` 当独立参考资料看（含 `QuestDiary/` 任务脚本树），
   注意本版源码不读它。

---

## 9. 复核方式

```bash
# 体量
du -sh --apparent-size reference/mir3-source

# 确认无文件被 .gitignore 静默吞掉（应为空）
find reference/mir3-source -type f | git check-ignore --stdin

# 确认无残留二进制（预期 61 项，且全部可解释）
#   31 x-wine-extension-ini  ← .h/.cpp 的 libmagic 误判，实际是文本
#   15 image/jxl             ← 二进制 DFM（见 §5.5）
#   12 inode/x-empty         ← 空文件
#    3 application/octet-stream ← 编码/加密的 MonQuest .txt（见 §5.5）
find reference/mir3-source -type f -print0 | xargs -0 file -b --mime-type \
  | grep -v '^text/' | sort | uniq -c | sort -rn
```
