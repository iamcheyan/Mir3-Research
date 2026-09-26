# Preview 客户端精读（骨架 / 场景 / 窗口 / 帧号）

> 证据源：`reference/mir3-source/Source/Client/`（Delphi，63,357 行）。
> 证据等级 `secondary-source`。机器可读产物：
> [`client-windows.tsv`](client-windows.tsv)（352 条窗口/控件声明）、
> 生成器 `Tools/source-read/extract_client_windows.py`。
>
> 读源码：`python3 Tools/source-read/read_src.py show Source/Client/<文件> --start N --end M`

---

## 1. 入口与单元依赖

`Mir3.dpr`（45 行）：

```
program Mir3;
uses Forms, Dialogs, IniFiles, Windows, SysUtils, classes, shellapi,
     ClMain in 'ClMain.pas' {FrmMain},        ← 主窗体，TFrmMain
     DrawScrn in 'DrawScrn.pas',              ← TDrawScreen，场景容器
     IntroScn, PlayScn, MapUnit, FState {FrmDlg},
     ClFunc, cliUtil, DWinCtl, magiceff, SoundUtil,
     Actor, HerbActor, AxeMon, clEvent,
     HUtil32 in '..\Common\HUtil32.pas',
     Grobal2 in '..\Common\Grobal2.pas',      ← 协议总表（与服端共用）
     SingleInstance, MaketSystem, RelationShip,
     uWilFile, WIL, wmUtil, CMsg;
begin
  Application.Initialize;
  Application.Title := 'Legend Of Mir 3 Development';
  Application.MainFormOnTaskBar := True;
  Application.CreateForm(TFrmMain, FrmMain);
  Application.Run;
end.
```

**注意**：`Grobal2` 与 `HUtil32` 通过 `..\Common\` 引用，即**客户端与服务端共用
同一份协议单元** —— 这解释了为什么 `protocol-constants.tsv` 的 474 条常量
对两端都成立。`Source/Client/` 下**没有独立的 EDCode.pas**，客户端 `uses EdCode`
（`CMsg.pas:30`、`ClFunc.pas:7`、`clEvent.pas:7`、`IntroScn.pas:8`、`MaketSystem.pas:7`）
解析到的是 `Source/Common/EDCode.pas`（含 `Decrypt` 的那份，见 `wire-format.md` §4）。

---

## 2. 场景状态机

**枚举**（`IntroScn.pas:19`）：

```pascal
TSceneType = (stIntro, stLogin, stSelectCountry, stSelectChr,
              stNewChr, stLoading, stLoginNotice, stPlayGame);
```

**切换**（`DrawScrn.pas:115-129`）：

| 场景 | 实例 | 备注 |
|---|---|---|
| `stIntro` | `IntroScene` | 开场动画 |
| `stLogin` | `LoginScene` | 登录 |
| `stSelectCountry` | **空实现**（`;`） | 未启用 |
| `stSelectChr` | `SelectChrScene` | 选角 |
| `stNewChr` | **空实现**（`;`） | 未启用 |
| `stLoading` | `LoadingScene` | 过场 |
| `stLoginNotice` | `LoginNoticeScene` | 登录公告 |
| `stPlayGame` | `PlayScene` | 主游戏 |

`ChangeScene` 会先 `CurrentScene.CloseScene` 再切、再 `OpenScene`。

**`stSelectCountry` / `stNewChr` 是空实现** —— 设计上留了槽位但没接场景类。
建号流程（`CM_NEWCHR`）不走独立场景，走选角场景内的对话框。

---

## 3. 窗口/控件清单（352 条声明）

`FState.pas`（`TFrmDlg` 窗体）+ `ClMain.pas`（`TFrmMain`）合计 **352 条**
字段声明。类型分布：

| 类型 | 数量 | 说明 |
|---|---:|---|
| `TDButton` | **302** | 绝大多数是按钮 |
| `TDWindow` | 40 | 窗口 |
| `TDGrid` | 4 | 网格（背包/仓库类） |
| `TList` | 2 | 列表 |
| `TClientItem` | 2 | 客户端物品对象 |
| `TDrawScreen` | 1 | 场景容器 |
| `TD3DAdapterIdentifier8` | 1 | Direct3D 适配器信息（非 UI） |

**40 个窗口**（`D*Dlg` / `D*`），按功能分组：

| 组 | 窗口 |
|---|---|
| 主 HUD | `DMiniMapDlg`（小地图） |
| 角色 | `DMasterDlg`（师徒） |
| 社交 | `DFriendDlg`（好友）`DBlockListDlg`（黑名单）`DGroupDlg`/`DGrpDlg`（组队）`DGuildDlg`（行会） |
| 邮件/公告 | `DMailDlg` `DMailListDlg` `DGABoardDlg` `DGABoardListDlg` `DJangwonListDlg` |
| 交易 | `DDealDlg` `DDealRemoteDlg` `DItemMarketDlg` `DSellDlg` `DMerchantDlg` |
| 物品 | `DMakeItemDlg`（制作）`DGADecorateDlg`（装饰） |
| 系统 | `DKeySelDlg` `DMessageDlg` `DMsgDlg` `DCountDlg` `DCountMsgDlg` `DMenuDlg` `DSelServerDlg` |

> **对照原版**：原版 EI 3.0 的 13 个主窗口是 **HUD 底部操作栏体系**
> （交换 80/81、小地图 82/83、技能 84/85、退出 90/91、登出 92/93、组队 94/95、
> 行会 96/97、腰带翻页 52/53、罗盘按钮 100-115）。本源码的 40 个窗口里
> **没有任务窗**，且多出邮件/师徒/黑名单/公告板/装饰/制作等**现代扩展窗**。
> 详细差异见 [`README.md`](README.md) D3。

---

## 4. 帧号空间（关键发现）

### 4.1 实测数据

| 项 | 值 |
|---|---|
| 源码引用唯一帧号 | **91** |
| 帧号范围 | **184 – 1960** |
| 落在原版范围内（0–1102） | **10**：`184, 188, 202, 372, 373, 556, 564, 566, 568, 570` |
| **超出原版范围** | **81**（含 1160–1672 的连续族 + 1960） |
| 这 10 个与原版已详查的 37 帧交集 | **0（空集）** |

原版基准来自 `docs/research/ei-ui-layout/gameinter-frame-metadata.json`：
`library_count: 1103`（即有效索引 0..1102，来源
`/data/NAS/TMP/EI传奇3.0客户端/Data/GameInter.wil`）。

### 4.2 结论

1. **两套 `GameInter` 是不同构建的资源库**。原版 1103 帧，Preview 版至少 1961 帧
   （因为引用了 1960）。源码的 81 个高帧号在原版里**不存在**。
2. **两套帧号语义无法互推**。即使数值落在共同范围内（那 10 个），
   也**没有一个**与原版已详查的 37 帧重合 —— 也就是说连「同号同图」的最小假设
   都没有证据支持。
3. 因此本仓库此前定的纪律（「源码引用帧号 >1102 的一律标 Preview 专属」）
   **需要加强**：即使 ≤1102 也不能直接当原版帧用，必须逐帧比对像素。

### 4.3 高帧号族的结构（源码侧）

```
1160-1207  连续族（1160,1161,...,1207，步长 1-2）—— 疑似某窗口的多状态帧
1210-1251  消息/腰带/弹窗族（DMsgDlg 1240/1241/1245、DBeltWin 1210/1211）
1280-1371  技能/状态族
1450-1484  一组
1620-1672  邮件/备忘录族（DMailListDlg/DMemo 用 1960）
1960       最大帧号（DMailListDlg 与 DMemo 共用）
```

`FState.pas:1402/2872/2901` 有 `d := g_WGameInter.Images[1240]` 这种先取图再
`SetImgIndex` 的写法 —— **说明源码会先探测帧是否存在**（`d` 用于判空），
这是资源缺失的降级路径。研究时不要把这些探测语句当成独立的帧引用。

---

## 5. 待办

| 项 | 说明 |
|---|---|
| 40 个窗口逐个（帧号/坐标/控件/事件） | ✅ **已提取**（`client-windows.md` §8 运行时布局 345 项 + `client-runtime-layout.tsv`） |
| `DWinCtl.pas`（7804 行）通用控件基类 | ✅ **已读**（`client-controls.md` + `client-internals.md`） |
| `uWilFile.pas` 的 57 个资源路径与加载顺序 | ✅ **已读**（`client-libraries.md`，含 `.Lib → .wil` 回退规则） |
| `PlayScn.pas` 的主循环与实体渲染 | ⚠️ 部分（`client-internals.md` §4 结构+调用点，主循环 pending） |
| `Actor.pas`/`AxeMon.pas`/`HerbActor.pas` | ⚠️ 部分（`Actor.pas` 动作帧表已提取；`AxeMon`/`HerbActor` pending） |
| `magiceff.pas` 魔法特效 | ⚠️ 仍 pending |
| `FState.pas`（14853 行） | ⚠️ 部分（窗口声明+帧号+**运行时布局 345 项**已读；其余主体 pending） |
| 那 10 个共同范围内的帧号是否同图 | 需逐帧像素比对（需原版 WIL + Preview 版 WIL） |

---

## 6. 复核方式

```bash
# 窗口清单重生成（含帧号范围与越界统计）
python3 Tools/source-read/extract_client_windows.py

# 帧号交集分析
python3 /tmp/frame_overlap.py   # 脚本逻辑见本文件 §4.1

# 读源码
python3 Tools/source-read/read_src.py show Source/Client/Mir3.dpr
python3 Tools/source-read/read_src.py show Source/Client/DrawScrn.pas --start 115 --end 129
python3 Tools/source-read/read_src.py grep 'SetImgIndex' --scope Source/Client
```
