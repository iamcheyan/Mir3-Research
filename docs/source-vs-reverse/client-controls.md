# Preview 客户端控件基类与输入路径（DWinCtl.pas 精读）

> 证据源：`reference/mir3-source/Source/Client/DWinCtl.pas`（7,804 行）。
> 证据等级 `secondary-source`。
> 读源码：`python3 Tools/source-read/read_src.py show Source/Client/DWinCtl.pas --start N --end M`

---

## 1. 类层次（`DWinCtl.pas` 共 17 个类）

```
TCustomControl (VCL)
└── TDControl                         :69     ← 所有控件基类
    ├── TDButton                      :203    ← 按钮（DFM 里 302 个实例）
    │   ├── TDWindow                  :257    ← 窗口（可移动/可关闭）
    │   │   └── TDModalWindow         :292    ← 模态窗
    │   ├── TDUpDown                  :331
    │   └── TDTreeView                :767
    ├── TDGrid                        :221    ← 网格（背包/仓库）
    ├── TDCheckBox                    :304
    ├── TDHooKKey                     :375
    ├── TDCustomEdit                  :401    ← 文本编辑基类
    │   ├── TDMemo                    :418
    │   ├── TDImageEdit               :505
    │   └── TDEdit                    :581
    │       └── TDComboBox            :645
    ├── TDListView                    :697
    └── TDPopUpMemu                   :727    ← 拼写错误（Menu→Memu），保留原样

TDWinManager = class(TComponent)      :809    ← 窗口管理器（非控件）
```

**关键结构事实**：`TDWindow` 继承自 `TDButton`，不是 `TDControl`。
即**窗口本身就是一种按钮** —— 它有 `FOnClick`、可以响应点击。
这解释了原版反编译里「窗口类同时有 vtable 绘制槽和点击处理器」的现象。

---

## 2. 全局单例（`DWinCtl.pas:842-859`）

```pascal
var
  MouseCaptureControl: TDControl;   // 鼠标捕获（拖拽中）
  FocusedControl: TDControl;        // 当前焦点
  KeyControl: TDControl;            // 键盘焦点
  MainWinHandle: integer;
  FrmMainWinHandle: Integer;
  FrmShowIME: Boolean = False;      // 输入法
  FrmIMEX, FrmIMEY: Integer;
  HklKeyboardLayout: LongWord = 0;
  ModalDWindowList: TList;          // 模态窗栈
  ModalDWindow: TDControl;
  TopDWindow: TDControl = nil;
  PopUpDWindow: TDControl = nil;    // 弹出窗（最高优先级）
  MouseEntryControl: TDControl = nil;
  KeyDownControl: TDControl = nil;
  GUIFScreenWidth: Integer = 800;   // ← 注意
  GUIFScreenHeight: Integer = 600;  // ← 注意
```

> ⚠️ **`GUIFScreenWidth/Height` 默认是 800×600**（`:858-859`），
> 但 `FState.dfm` 的根窗体是 1095×975、窗口 x 最大到 1008（见 `client-windows.md` §2.1）。
> **两个数字矛盾** —— 说明 800×600 是**残留的默认值**，运行时被改写。
> 这正好印证了原版证据的 800×600 基准与 Preview 版的实际布局不同。

配套的焦点/捕获管理函数（`:833-838`）：
`SetDFocus`/`ReleaseDFocus`、`SetDCapture`/`ReleaseDCapture`、`SetDKocus`/`ReleaseDKocus`
（注意最后一个也是拼写错误，`Focus`→`Kocus`，代码里就这么用的）。

---

## 3. 输入分发：**四级优先级**

`TDWinManager` 的每个输入方法（`MouseMove`/`MouseDown`/`MouseUp`/`KeyPress`/
`KeyDown`/`KeyUp`/`MouseWheel`/`Click`/`DblClick`）都是同一套优先级骨架。
以 `MouseMove`（`:2271-2324`）为例：

```
1. PopUpDWindow（弹出窗）      —— 若可见，独占，直接 exit
2. ModalDWindowList（模态栈）  —— 从栈顶倒序找第一个可见的，独占 exit
3. ModalDWindow（单个模态窗）  —— 若可见，独占 exit
4. MouseCaptureControl（捕获） —— 有捕获则只发给它
5. DWinList（普通窗口列表）    —— 正序遍历，第一个返回 True 的 break
```

**注意第 5 步是「正序」（`for i := 0 to Count-1`）**，
而 `TDControl.MouseMove` 内部的子控件遍历是**倒序**（`:1520` `for i := DControls.Count - 1 downto 0`）。

→ **父层正序、子层倒序**。含义：`DWinList` 里**索引小的先被命中**（即索引小 = 更靠前/z 更高），
而同一窗口内的子控件**后添加的先被命中**（后添加 = 更靠上）。

### 3.1 绘制顺序与之相反

`DirectPaint`（`:2691-2738`）的顺序：

```
1. DWinList 正序绘制（但先把 ModalDWindow 与 PopUpDWindow 临时 Visible:=False 藏起来）
2. ModalDWindow（恢复可见后绘制）
3. ModalDWindowList 正序绘制
4. PopUpDWindow 最后绘制（在最上层）
```

**「先藏起来再画、最后补画」** 是为了保证模态/弹出窗**永远画在普通窗之上**，
不依赖 `DWinList` 的顺序。这是个巧妙但隐晦的写法 —— 静态阅读容易误判成
「模态窗被漏画」。

### 3.2 命中测试：`InRange`（`:1439-1458`）

```pascal
function TDControl.InRange(x, y: integer): Boolean;
begin
  if (x >= Left) and (x < Left + Width) and (y >= Top) and (y < Top + Height) then begin
    boinrange := TRUE;
    if Assigned(FOnInRealArea) then
      FOnInRealArea(self, x - Left, y - Top, boinrange)   // ← 自定义形状
    else if WLib <> nil then begin
      d := WLib.Images[FaceIndex];
      if d <> nil then
        if d.Pixels[x - Left, y - Top] <= 0 then
          boinrange := FALSE;                              // ← 透明像素不命中
    end;
    Result := boinrange;
  end else Result := FALSE;
end;
```

**两级命中**：
1. **矩形框**（`Left/Top/Width/Height`）
2. **像素级**：查该控件的帧位图 `WLib.Images[FaceIndex]`，
   若该点像素 **alpha ≤ 0（全透明）则判为不命中**

这是原版反编译里 `PtInRect` 调用链的对应物 —— 原版 `0x4762B4` 的
`PtInRect` 只做矩形，**像素级命中由 `FOnInRealArea` 或 WLib 像素查表补足**。
研究原版不规则控件（罗盘按钮、X 关闭钮）时，必须考虑这条像素级规则。

### 3.3 坐标转换：`LocalX`/`LocalY`（`:1315-1341`）

```pascal
function TDControl.LocalX(x: integer): integer;
begin
  d := self;
  while TRUE do begin
    if d.DParent = nil then break;
    x := x - d.DParent.Left;   // 逐级减去父控件的 Left
    d := d.DParent;
  end;
  Result := x;
end;
```

沿 `DParent` 链**逐级减**，直到根（`DParent = nil`）。
注意与 `TDControl.MouseMove` 里 `X - Left, Y - Top`（`:1522`）的**区别**：
- 子控件递归时减的是**自己**的 `Left/Top`（因为父调子时传的是父坐标系的值）
- `LocalX/LocalY` 用于从**屏幕坐标**直接换算到某控件坐标，减的是**所有祖先**

两者混用会算错。这是阅读时的常见陷阱。

---

## 4. 控件属性（`TDControl` 字段，`:69-200`）

事件回调类型共 **18 种**（`:45-67`）：

| 回调 | 用途 |
|---|---|
| `TOnDirectPaint` | 直接绘制（绕过 VCL） |
| `TOnKeyPress`/`TOnKeyDown`/`TOnKeyUp` | 键盘 |
| `TOnMouseWheel`/`TOnMouseMove`/`TOnMouseDown`/`TOnMouseUp` | 鼠标 |
| `TOnClick`/`TOnClickEx` | 点击（后者带 X,Y） |
| `TOnInRealArea` | **自定义命中形状** |
| `TOnGridSelect`/`TOnGridPaint` | 网格 |
| `TOnItemIndex`/`TOnCheckItem` | 列表项 |
| `TOnMouseEntry` | 鼠标进入/离开 |
| `TOnClickSound` | **点击音效**（`TClickSound = (csNone, csStone, csGlass, csNorm)`） |
| `TOnVisible` | 可见性变化 |
| `TOnDrawEditImage` | 编辑框图像 |
| `TOnTreeViewSelect`/`TOnTreeClearItem` | 树控件 |

**`TClickSound`** 四态（`:38`）—— 这对应原版证据里的「共享音效命令 `0x69`」
（F251 记录：共享 release 处理器命中后调 `0x45AFC0(0x8AB130, cmd 0x69)`，
Finding 243 定 `0x69` = 共享音效命令）。**源码给出了这四个音效名的业务含义**：
`csNone`（无）/ `csStone`（石）/ `csGlass`（玻璃）/ `csNorm`（普通）。

**编辑框字符白名单**（`:10-14`）：
```
AllowedChars        = [#32..#254]            // 通用
AllowedIntegerChars = [#48..#57]             // 纯数字
AllowedEnglishChars = [#33..#126]            // 英文
AllowedStandard     = [#48..#57,#65..#90,#97..#122]  // 字母数字
AllowedCDKey        = [#48..#57,#65..#90,#95,#97..#122] // 含下划线
```
`TDEditClass = (deNone, deInteger, deMonoCase, deChinese, deStandard, deEnglishAndInt, deCDKey)`（`:39`）
—— 7 种输入模式，对应不同白名单。

**默认字体**（`:24-25`）：`DEFFONTNAME = '芥竟'`、`DEFFONTSIZE = 9`
（`芥竟` 是 CP949 解码出的字形，实际应是某个韩文字体名）。

**常量 `WINLEFT = 60; WINTOP = 60;`**（`:19-20`），配套被注释掉的
`g_FScreenWidth = 800` / `g_FScreenHeight = 600`（`:16-17`）——
再次印证 800×600 是被替换掉的旧基准。

---

## 5. 窗口管理器 API（`TDWinManager`，`:809-832`）

```pascal
DWinList: TList;                                   // 窗口列表（z 序）
procedure AddDControl(dcon; visible);              // 注册窗口
procedure DelDControl(dcon);
procedure CloseSurface();                          // 释放绘制表面
procedure CloseModalShow();                        // 关闭模态显示
procedure ClearAll;
function KeyPress/KeyDown/KeyUp(...): Boolean;
function MouseWheel/MouseMove/MouseDown/MouseUp(...): Boolean;
function DblClick/Click(X,Y): Boolean;
function EscClose(): Boolean;                      // ESC 关窗
procedure DirectPaint(dsurface);
```

**`EscClose`** 是独立的 ESC 处理入口 —— 原版反编译里 ESC 键的路由
（`0x447FA0` 那类点击处理器 + 键盘转发）可以对照这里。

---

## 6. 与原版证据的对照

| 原版（`primary-static`） | 源码（`secondary-source`） | 关系 |
|---|---|---|
| 共享控件构造器 `0x417550`（vtable `0x4763A8`） | `TDControl` 基类 + `TDButton`/`TDWindow` 派生 | 结构对应，**但不是同一份代码** |
| `PtInRect` IAT `[0x4762B4]` 命中测试 | `InRange`（矩形 + 像素 alpha） | 源码补上**像素级**规则 |
| 共享 release 处理器 → `0x45AFC0(cmd 0x69)` 音效 | `TOnClickSound` + `TClickSound` 四态 | 源码给出**音效名语义** |
| 窗口 vtable `+0x0c` 绘制槽 | `TOnDirectPaint` / `FOnEndDirectPaint` | 对应 |
| 可见窗口链表 → 各专用绘制入口（`0x004280F0`） | `DWinList` + `DirectPaint` 优先级 | 源码给出**完整优先级模型** |
| 原版 800×600 基准 | `GUIFScreenWidth=800` **残留默认值**，实际 1095×975 | ⚠️ 矛盾，见 §2 |

**本轮新增的可用于原版研究的语义**：

1. **四级输入优先级**（PopUp > Modal 栈 > 单个 Modal > Capture > DWinList）
   —— 原版只观察到「可见窗口链表」，源码给出了**为什么**是这个顺序。
2. **像素级命中**（透明像素不响应）—— 解释原版不规则按钮的命中边界。
3. **`TDWindow` 是 `TDButton` 的子类** —— 解释「窗口也有点击处理器」。
4. **`TClickSound` 四态** —— 给原版 `0x69` 共享音效命令补上业务名。

---

## 7. 待办

| 项 | 说明 |
|---|---|
| `TDButton`（`:203-220`）内部实现 | 只读了声明，未读 pressed/hover/disabled 三态切换 |
| `TDWindow`（`:257-291`）移动/关闭逻辑 | 未读 |
| `TDGrid`（`:221-256`）格子模型 | 背包 6×6 格与源码 `TDGrid` 的对应未核 |
| `TDMemo`/`TDEdit` 输入与 IME | 未读（`FrmShowIME`/`HklKeyboardLayout` 有中文输入线索） |
| `TDTreeView` | 未读（原版无对应控件） |
| `AddDControl` 的 z 序插入策略 | 未读，影响「索引小 = 更靠前」的确认 |
| `芥竟` 字体的真实名称 | CP949 解码字形，需确认 |

---

## 8. 复核方式

```bash
python3 Tools/source-read/read_src.py show Source/Client/DWinCtl.pas --start 69 --end 110
python3 Tools/source-read/read_src.py show Source/Client/DWinCtl.pas --start 1439 --end 1458   # InRange
python3 Tools/source-read/read_src.py show Source/Client/DWinCtl.pas --start 2271 --end 2324   # MouseMove 优先级
python3 Tools/source-read/read_src.py show Source/Client/DWinCtl.pas --start 2691 --end 2738   # DirectPaint
grep -an '= class' reference/mir3-source/Source/Client/DWinCtl.pas
```
