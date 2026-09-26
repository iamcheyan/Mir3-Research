# Preview 客户端窗口精读（DFM 几何 + 与原版对照）

> 证据源：`reference/mir3-source/Source/Client/{FState,ClMain}.dfm`（Delphi 二进制 DFM）。
> 证据等级 `secondary-source`。
> 解析器：[`Tools/source-read/dfm_parse.py`](../../Tools/source-read/dfm_parse.py)（自研 TPF0 解析）。
>
> **为什么必须解析 .dfm**：`.pas` 里只有 `DBeltWin: TDWindow;` 这类**字段声明**，
> 窗口坐标/尺寸**全部**在 `.dfm` 里。跳过 DFM 就只能看到「有哪些窗口」而看不到几何。

---

## 1. DFM 格式与解析要点

`FState.dfm` = 114,288 B，可打印率 81.6%，`file(1)` 误判为 JPEG XL。
真实格式是 **Delphi 二进制窗件（TPF0）**，且**不是从偏移 0 开始**：

```
偏移 0-16: ff 0a 00 'TFRMDLG' 00 '0' 10 5f be 01 00     ← 窗体元信息头
偏移 17:   'TPF0'                                        ← 真正的 DFM 流起点
```

**三个解析陷阱**（都实测踩过，`dfm_parse.py` 已处理）：

1. **根对象没有 `0x01` 前置标记**：`TPF0 07 'TFrmDlg' 06 'FrmDlg' ...`。
   只有**子对象**才带 `0x01`。按「所有对象都有 0x01」写会立刻抛错。
2. **属性区结束后有两个 `0x00`**：`...属性... 00 00 08 'TDWindow' 09 'DStateWin'`。
   第一个结束属性区，第二个是「无更多属性」的占位。只跳一个就会把第二个
   当成「本层无子对象」，导致**解析出 0 个子窗口**（本文件踩过的坑）。
3. 字符串是 **CP949/GB18030 ANSI**，不是 UTF-8；且部分字符串属性长度前缀异常
   （实测 `Caption` 值 `FrmDlg` 被读成 `rmDlg`，`Font.Name` 更长）。
   → **解析器对字符串属性不完全可靠，但几何属性（整型）100% 可靠**。
   本文档只用几何属性。

**可靠性**：`FState.dfm` 解析出 **100 项**（1 根 + 15 窗口 + 84 按钮等）；
`ClMain.dfm` 8 项。数量与 `.pas` 的 352 条声明不矛盾（DFM 只存可视化控件，
`.pas` 声明含运行时动态创建的）。

---

## 2. 窗口几何全表（源码侧）

`FState.dfm` 的 **30 个 TDWindow**（含 15 个在顶层、其余嵌套）：

| 窗口 | (Left, Top) | W×H | 功能 |
|---|---|---|---|
| `DStateWin` | (627, 117) | 201×216 | 人物状态/装备 |
| `DUserState1` | (846, 131) | 162×200 | 他人状态 |
| `DItemBag` | (165, 170) | 111×144 | 背包 |
| `DInventoryWnd` | (315, 127) | 111×144 | 背包（另一实例，同尺寸） |
| `DBottom` | (15, 517) | 476×121 | **主 HUD 底板** |
| `DBeltWin` | (820, 590) | 231×81 | 腰带 |
| `DChat` | (115, 530) | 189×100 | 聊天 |
| `DMiniMapDlg` | (515, 8) | 77×64 | 小地图 |
| `DMagicWnd` | (327, 8) | 182×73 | 技能栏 |
| `DLogIn` | (10, 7) | 159×61 | 登录窗 |
| `DSelServerDlg` | (8, 188) | 151×155 | 选服 |
| `DMerchantDlg` | (260, 400) | 149×106 | 商人 |
| `DMenuDlg` | (430, 400) | 191×111 | 菜单 |
| `DSellDlg` | — | — | 出售（见按钮族） |
| `DKeySelDlg` | (240, 900) | 291×136 | 按键设置 |
| `DGroupDlg` | (840, 10) | 186×116 | 组队 |
| `DDealDlg` | (500, 290) | 121×101 | 交易（己方） |
| `DDealRemoteDlg` | (420, 290) | 79×101 | 交易（对方） |
| `DGuildDlg` | (630, 340) | 391×111 | 行会 |
| `DGuildEditNotice` | (630, 460) | 161×61 | 行会公告编辑 |
| `DAdjustAbility` | (630, 530) | 161×111 | 属性加点 |
| `DFriendDlg` | (15, 655) | 186×116 | 好友 |
| `DMailListDlg` | (225, 655) | 186×116 | 邮件列表 |
| `DMailDlg` | (425, 655) | 186×116 | 邮件 |
| `DBlockListDlg` | (625, 655) | 186×116 | 黑名单 |
| `DMemo` | (820, 680) | 161×91 | 备忘录 |
| `DCountDlg` | (15, 780) | 216×101 | 计数/查询 |
| `DMakeItemDlg` | (236, 780) | 182×101 | 制作 |
| `DItemMarketDlg` | (430, 780) | 191×111 | 拍卖 |
| `DJangwonListDlg` | (631, 780) | 120×111 | 掌院目录 |
| `DDealJangwon` | (461, 251) | 122×32 | 掌院交易 |

### 2.1 关键观察：坐标**不是 800×600 布局**

`DBottom`（主 HUD 底板）在 **(15, 517)**，尺寸 **476×121**。
`DStateWin` 在 **x=627**，`DGroupDlg` 在 **x=840**，`DUserState1` 在 **x=846**，
`DMemo` 在 **x=820**，`DKeySelDlg` 在 **y=900**。

→ **x 最大到 846+162=1008，y 最大到 900+136=1036**。这是 **1024×768 及以上**
的布局，**不是**原版的 800×600。

`FState.dfm` 的根窗体 `TFrmDlg` 是 **(329, 0) 1095×975** —— 主窗体本身就是
1095×975 的逻辑画布。

### 2.2 窗口被「排成网格」

`DFriendDlg`(15,655) / `DMailListDlg`(225,655) / `DMailDlg`(425,655) /
`DBlockListDlg`(625,655) 四个窗口 **y 相同、x 等距 200**；
下一行 `DCountDlg`(15,780) / `DMakeItemDlg`(236,780) / `DItemMarketDlg`(430,780) /
`DJangwonListDlg`(631,780) 同样 y 相同、x 等距约 205。

→ 这是**开发期把窗口摆开以便同时编辑/调试**的痕迹，**不是游戏内实际位置**
（游戏里这些窗口由 `.pas` 的初始化代码动态定位）。**结论：DFM 坐标是编辑期布局，
只能作「窗口尺寸」证据，不能作「游戏内坐标」证据** —— 这是一个重要的方法论边界。

---

## 3. 与原版几何对照

原版基准：`docs/research/ei-ui-layout/window_layout.json`，13 条记录，
`viewport: 800×600`，`position_basis` 明确写
「raw wrapper call-site inputs；final screen rect 由共享构造器 `0x00423B30`
按 WIL 尺寸 + 锚点/居中分支计算」。

| id | 原版帧 | 原版 (x,y) | 原版 W×H |
|---|---|---|---|
| 0 | 250 | (518, 0) | 284×324 |
| 1 | 200 | (0, 0) | 244×328 |
| 2 | 1000 | (0, 0) | 300×304 |
| 3 | 1050 | (0, 0) | 484×330 |
| 4 | 600 | (102, 22) | 596×446 |
| 6 | 900 | (272, 123) | 256×244 |
| 7 | 200 | (560, 0) | 244×328 |
| 8 | 350 | (114, 76) | 572×388 |
| 9 | 1100 | (0, 0) | 552×176 |
| 11 | 700 | (0, 0) | 340×440 |
| 12 | 750 | (276, 113) | 248×264 |
| 13 | 850 | (0, 0) | 296×332 |
| 14 | 400 | (0, 0) | 296×332 |

### 3.1 可对照的两组

| 功能 | 原版 | 源码 | 判定 |
|---|---|---|---|
| 背包 | id0 frame250 **284×324** | `DItemBag` **111×144** | ❌ 差 2.5× |
| 人物状态 | id1 frame200 **244×328** | `DStateWin` **201×216** | ❌ 尺寸不同 |
| 聊天 | id8 frame350 **572×388** | `DChat` **189×100** | ❌ 差 3× |
| 组队 | id6 frame900 **256×244** | `DGroupDlg` **186×116** | ❌ 尺寸不同 |

**没有一组尺寸吻合。** 结合 `client.md` §4 的帧号结论（91 个帧号里只有 10 个
落在原版范围、且与已详查帧零交集），可以确认：

> **Preview 版与原版 EI 3.0 是两套独立的 UI 布局，窗口尺寸、帧号、资源库
> 三者都不通用。**

### 3.2 这不否定原版证据的价值

原版 `window_layout.json` 的坐标是 **`primary-static`**（来自 `Mir3.exe`
反汇编的构造器调用点），源码 DFM 坐标是 **编辑期布局**（见 §2.2）。
**两者本来就不该相同** —— 源码的价值不在坐标，而在：

- **字段/控件语义命名**（`DStateWin` / `DItemBag` / `DSWWeapon` 等装备槽名）
- **窗口与消息的对应关系**（哪个窗口响应哪个 opcode）
- **控件类型与行为**（`TDButton` 的 302 个实例、`TDGrid` 的格子模型）

---

## 4. 装备槽命名（源码给出原版缺的语义）

`FState.dfm` 的 `DSW*` 按钮族给出了**装备槽的业务名**，这是原版反编译
（只能看到帧号和矩形）拿不到的信息：

| 控件 | (Left, Top) | W×H | 槽位 |
|---|---|---|---|
| `DSWHelmet` | (710, 120) | 36×36 | 头盔 |
| `DSWNecklace` | (750, 135) | 36×36 | 项链 |
| `DSWWeapon` | (680, 160) | 31×51 | 武器（非方形） |
| `DSWDress` | (720, 160) | 26×141 | 衣服（高条） |
| `DSWLight` | (750, 180) | 36×36 | 照明/火把 |
| `DSWArmRingR` | (680, 230) | 36×36 | 右臂环 |
| `DSWArmRingL` | (750, 230) | 36×36 | 左臂环 |
| `DSWRingR` | (680, 275) | 36×36 | 右戒指 |
| `DSWRingL` | (750, 275) | 36×36 | 左戒指 |

**9 个槽**（原版证据记「8 个装备候选槽 + 3 个非装备记录」）。
`DSWDress` 是 26×141 的**高条**、`DSWWeapon` 是 31×51 —— 这两个的非方形尺寸
说明装备槽不是等距网格，与「8 槽」的简单描述不完全一致，值得在阶段 5 细核。

---

## 5. 主 HUD 按钮族（`DBottom` 内）

`DBottom`（476×121）内是原版反编译里那批「底部操作栏按钮」的对应物：

| 按钮 | (Left, Top) | W×H | 语义（源码名） |
|---|---|---|---|
| `DMyState` | (380, 574) | 36×31 | 状态 |
| `DMyBag` | (343, 571) | 31×31 | 背包 |
| `DMyMagic` | (422, 574) | 36×31 | 技能 |
| `DOption` | (380, 611) | 36×31 | 选项 |
| `DGold` | (172, 282) | 30×25 | 金币 |
| `DRepairItem` | (206, 282) | 30×25 | 修理 |
| `DCloseBag` | (240, 282) | 30×25 | 关闭背包 |

> 注意这些坐标是**相对其父容器**的（DFM 的 `Left/Top` 对子控件是相对父窗口），
> 所以 `DMyState (380,574)` 相对 `DBottom (15,517)` 即屏幕 **(395, 1091)** ——
> 再次印证这不是游戏内实际布局。

---

## 6. 待办

| 项 | 说明 |
|---|---|
| DFM 字符串属性的长度前缀异常 | `Caption`/`Font.Name` 解码不可靠（见 §1 陷阱 3），需修 |
| `ClMain.dfm` 只有 8 项 | 主窗体的控件极少，说明大部分 UI 是运行时动态建 —— 需读 `.pas` 的 `FormCreate` |
| 游戏内实际窗口坐标 | 不在 DFM 里，需读 `FState.pas` 的初始化段（`InitDialog` 之类） |
| 装备槽数 9 vs 原版「8 槽」 | 需细核 |
| 302 个 `TDButton` 逐个 | 未做，只读了 HUD 与装备槽两组 |
| `DInventoryWnd` vs `DItemBag` | 两个 111×144 背包窗口并存，需确认哪个是主用 |

---

## 7. 复核方式

```bash
# 解析 DFM（自研 TPF0 解析器）
python3 Tools/source-read/dfm_parse.py list reference/mir3-source/Source/Client/FState.dfm
python3 Tools/source-read/dfm_parse.py list reference/mir3-source/Source/Client/FState.dfm --class TDWindow
python3 Tools/source-read/dfm_parse.py json reference/mir3-source/Source/Client/FState.dfm --out /tmp/fs.json

# 与原版对照
python3 -c "import json;d=json.load(open('docs/research/ei-ui-layout/window_layout.json'));print(d['viewport'], len(d['records']))"
```
