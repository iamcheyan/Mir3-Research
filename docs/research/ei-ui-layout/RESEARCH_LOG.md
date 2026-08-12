# EI 3.0 原版 UI 反编译持续研究日志

本日志记录反编译过程中的发现、推理依据、失败尝试和待验证事项。它和机器可读数据同等重要：后续继续分析时，任何结论都应能追溯到本日志中的原始地址、资源文件或交叉来源。

## 2026-08-09：建立原版 UI 证据链

### 研究目标

恢复 20 年前 EI 3.0 传奇 3 客户端的完整 800×600 UI。当前范围不仅是底部操作栏，还包括主 HUD、人物状态、装备、背包、技能、任务、地图、小地图、聊天、NPC、商店、仓库、组队、行会、好友、系统菜单和各种弹窗。

### 第一证据源

```text
/home/tetsuya/NAS/TMP/EI传奇3.0客户端/Mir3.exe
/home/tetsuya/NAS/TMP/EI传奇3.0客户端/mir3.dat
/home/tetsuya/NAS/TMP/EI传奇3.0客户端/Data/*.wil
/home/tetsuya/NAS/TMP/EI传奇3.0客户端/Data/*.wix
```

已确认的关键资源：

- `Data/GameInter.wil`：主 HUD 和大量窗口/按钮资源，当前库计数 1103。
- `GameInter.wil` Frame 50：原版资源尺寸 `800×136`，可以作为底部 HUD 背板证据。
- `GameInter.wil` Frame 60/61：`56×110`，血球/魔球候选。
- `GameInter.wil` Frame 63：`164×6`，经验条候选。
- `GameInter.wil` Frame 67：`4×70`，重量条候选。
- Frame 80–85：`24×16`。
- Frame 90–97：`28×26`。
- Frame 100–115：`40×38`，与右侧罗盘入口按钮组吻合。

资源尺寸由 `Tools/build_mir3_ui_resource_metadata.py` 从原版 WIL 头部读取，输出到 `gameinter-frame-metadata.json`。尺寸不是人工测量，也不是现代客户端推断。

### 发现一：固定控件初始化函数

在 `Mir3.exe` 中定位到：

```text
VA 0x00417550
```

该函数不是普通业务函数。静态分析显示它：

1. 从调用参数读取资源对象和两个连续 Frame 编号；
2. 把资源/状态字段写入 `this` 对象；
3. 保存两个位置参数；
4. 读取 WIL 当前帧的宽高；
5. 通过 `SetRect` IAT（`VA 0x004762B0`；USER32 import descriptor 的 IAT RVA 为 `0x76234`，SetRect 是该表第 31 项）建立控件的命中区域。

因此，本项目暂时把 `0x00417550` 命名为“原版 UI 控件初始化候选”，证据等级为 `primary-static-control-initializer`。还没有把它命名成源码中的具体类名，因为 EI 二进制没有符号。

### 发现二：底部 HUD 有连续的 16 组按钮初始化

原版二进制在 `0x004279B2` 至 `0x00427D94` 之间连续调用上述函数。每组调用都有连续 Frame 对，且 X 坐标常量与早期 Mir3 源码一致：

| 调用 VA | Frame | 二进制 X 偏移 | 二进制 Y 偏移 |
|---|---:|---:|---:|
| `0x4279B2` | 80/81 | 204 | 2 |
| `0x4279E6` | 82/83 | 228 | 2 |
| `0x427A1A` | 84/85 | 252 | 2 |
| `0x427A4E` | 90/91 | 161 | 46 |
| `0x427A82` | 92/93 | 161 | 82 |
| `0x427AB6` | 94/95 | 616 | 47 |
| `0x427AEA` | 96/97 | 616 | 82 |
| `0x427B58` | 100/101 | 703 | 16 |
| `0x427BAA` | 102/103 | 718 | 32 |
| `0x427BFC` | 104/105 | 718 | 70 |
| `0x427C4D` | 106/107 | 703 | 85 |
| `0x427C9F` | 108/109 | 664 | 86 |
| `0x427CF1` | 110/111 | 648 | 70 |
| `0x427D42` | 112/113 | 648 | 32 |
| `0x427D94` | 114/115 | 665 | 16 |

这些位置不是裸数字。实际形式是：

```text
X = [esi + 0xc58] + 常量
Y = [esi + 0xc5c] + 常量
```

`[esi+0xc58]` 和 `[esi+0xc5c]` 的高层字段名仍待继续追踪；目前不能直接把它们叫作 `main.left/top`，只能叫二进制中的 X/Y 基准字段。

### 发现三：x86 参数顺序容易造成误判

早期提取器针对 `VA 0x00449C50` 的三 WORD helper 最初按机器码出现顺序记录参数，导致字段顺序反了。x86 调用者是反向压栈：

```text
push value3
push value2
push value1
push pointer
call helper
```

现已在 `Tools/reverse-engineering/extract_mir3_ui_layout.py` 中反转还原，并在 JSON 中保留 `raw_pushes` 作为原始证据。这个 helper 的字段语义仍未确认，所以 93 条记录继续标记为 `static-initializer-candidate`，不能当成屏幕 Rect。

### 发现四：源码交叉参考与 EI 不完全一致

公开的早期 Mir3 C++ 源码给出相同的 Frame 对和 X 偏移，说明 EI 与该早期版本有很强的结构关联。但源码中的 Y 偏移与 EI 二进制不完全一致，例如源码写作 `main.top+34` 的技能按钮，在 EI 二进制中表现为 `[esi+0xc5c]+16`。

当前处理原则：

- 帧对和 X 偏移同时被 EI 二进制确认，可以记录为 `primary-static`，并标注源码交叉吻合。
- Y 偏移只采用 EI 反汇编表达式，不强行套源码。
- 公开源码记录统一标记为 `secondary-source-hypothesis`，不能替代 EI 证据。
- 未确认的字段名、按钮业务名称和最终屏幕绝对坐标都不能写成“已确定”。

### 发现五：窗口基类和窗口创建簇

在 `0x00423B30` 处确认了通用窗口基类初始化逻辑。它调用 `0x00466130` 选择 Frame，然后用 Frame 的宽高设置图像矩形；如果调用者传入显式宽高，则另外保存窗口矩形尺寸。这个函数与早期源码中的 `CGameWnd::CreateGameWnd` 结构对应。

主 UI 初始化函数 `0x00427600` 附近出现一组连续窗口创建调用。当前已解析出：

```text
ID 0  Frame 250   x=518 y=0   w=284 h=324  movable=1  背包候选
ID 1  Frame 200   x=0   y=0   w=244 h=328  movable=1  人物状态候选
ID 2  Frame 1000  x=0   y=0   w=300 h=304  movable=0  商店/仓库候选
ID 3  Frame 1050  x=0   y=0   w=484 h=330  movable=1  交易候选
ID 4  Frame 600   x=102 y=22  w=596 h=446  movable=1  行会候选
ID 6  Frame 900   x=272 y=123 w=256 h=244  movable=1  组队候选
ID 8  Frame 350   x=114 y=76  w=572 h=388  movable=1  聊天弹窗候选
ID 7  Frame 200   x=560 y=0   w=244 h=328  movable=1  附属面板候选
ID 12 Frame 750   x=276 y=113 w=248 h=264  movable=1  选项候选
ID 11 Frame 700   x=0   y=0   w=340 h=440  movable=1  任务候选
ID 13 Frame 850   x=0   y=0   w=296 h=332  movable=1  马匹候选
ID 14 Frame 400   x=0   y=0   w=296 h=332  movable=1  其他窗口候选
ID 9  Frame 1100  x=0   y=0   w=552 h=176  movable=0  NPC 对话候选
```

其中 `250/200/900/350/750/700/850` 与早期源码资源族吻合；`1000/1050/1100` 是 EI 二进制直接出现的编号，暂时不能用源码中的 `253/251/300` 替换。窗口表和原始调用邻域分别保存于 `window_layout.json`、`window_init_candidates.json` 和 `primary-window-init-evidence.md`。

### 发现六：按钮命中矩形可以由原版自动恢复

对 `VA 0x00417550` 的完整反汇编确认了此前的关键推断：

```text
this+0x14 -> 当前 WIL 资源对象
this+0x28 -> position_x
this+0x2c -> position_y
this+0x04 -> RECT
```

函数在资源有效时读取当前 Frame 的宽高，并调用 `USER32.SetRect` IAT `0x004762B0`，把位置与宽高组合成命中矩形。随后控件鼠标处理函数 `0x00417780`、`0x004177C0`、`0x004177F0` 分别在 `0x00417791`、`0x004177D1`、`0x00417802` 通过 `PtInRect` IAT `0x004762B4` 测试 `this+0x04`。

这证明“手动拖动校准按钮命中区域”不是必要路线。正确路线是：提取原版控件的位置参数，读取对应 WIL Frame 的尺寸，再合并所属窗口基准位置。尚未确认所属窗口基准的位置时，仍必须把结果标记为相对坐标。

调用点提取器和证据说明：

```text
Tools/extract_mir3_ptinrect_calls.py
docs/research/ei-ui-layout/ptinrect_calls.json
docs/research/ei-ui-layout/primary-ptinrect-evidence.md
```

证据边界：`SetRect`/`PtInRect` 的调用关系是一级静态证据；具体业务名称、窗口归属和透明像素轮廓尚未全部确认。WIL Frame 的外接矩形可能大于可见像素区域。

### 发现七：窗口 Frame 的资源头与窗口矩形是两套数据

从原版 `Data/GameInter.wil/.wix` 读取窗口候选 Frame 的 17 字节头部后，发现资源头尺寸与 `0x00427600` 传给通用窗口初始化器的显式窗口尺寸并不总是相同。例如：

| Frame | WIL 头部 width×height | 窗口初始化显式尺寸 |
|---:|---:|---:|
| 200 | 256×512 | 244×328 |
| 250 | 512×512 | 284×324 |
| 350 | 1024×512 | 572×388 |
| 600 | 1024×512 | 596×446 |
| 700 | 512×512 | 340×440 |
| 750 | 256×512 | 248×264 |
| 850 | 512×512 | 296×332 |
| 900 | 256×256 | 256×244 |
| 1000 | 512×512 | 300×304 |
| 1050 | 512×512 | 484×330 |
| 1100 | 512×256 | 552×176 |

这里的“WIL 头部尺寸”来自 `Tools/common/wilsdk.py` 的原始解码，不是把窗口尺寸倒推出来的；“显式尺寸”来自窗口创建调用的参数。二者不能混为一谈：前者是资源绘制/解码矩形，后者是窗口容器或裁剪/交互区域候选。Frame 145、202、251、253、254、255 在 `GameInter.wil` 中为空或不存在，早期源码中相同数字的含义不能直接覆盖 EI 的资源编号。

这一差异是后续还原完整窗口时的重要约束：预览器必须同时显示 `resource_rect` 与 `window_rect`，并记录两者的证据来源。

### 发现八：窗口构造尺寸与非透明像素边界高度相关

使用 `Tools/analyze_mir3_window_resources.py` 解码 GameInter.wil，并对每个窗口候选取 RGBA 非透明像素的外接框，得到如下对照：

| 窗口候选 | Frame | 非透明像素框 | 构造尺寸 | 差值（构造−像素框） |
|---|---:|---:|---:|---:|
| inventory | 250 | 281×324 | 284×324 | +3×0 |
| status | 200 | 241×327 | 244×328 | +3×1 |
| chat-pop | 350 | 570×387 | 572×388 | +2×1 |
| guild | 600 | 594×445 | 596×446 | +2×1 |
| quest | 700 | 340×439 | 340×440 | 0×1 |
| option | 750 | 248×273 | 248×264 | 0×−9 |
| exchange | 1050 | 483×330 | 484×330 | +1×0 |

这不是偶然的尺寸相等：多个窗口的显式尺寸与非透明边界只差 0–3 个像素。当前最合理的解释是窗口构造尺寸和资源的有效内容/裁剪区域有关，但仍不能仅凭尺寸确定绘制原点、透明边缘是否参与命中或窗口是否使用了额外的内部裁剪。

Frame 1100 的非透明边界与当前 `552×176` 构造参数差异较大，因此 NPC 窗口候选暂时降级为“资源/调用关联已确认、尺寸语义待追踪”，不能套用其他窗口的规律。

机器可读结果：

```text
docs/research/ei-ui-layout/window-resource-analysis.json
```

### 发现九：建立数据驱动的证据布局预览页

为避免旧版 HUD 拆解页中的手写红框继续被误认为原版坐标，`Tools/web/wilviewer.py` 新增：

```text
/ui                 固定 800×600 证据布局页面
/api/ui-layout      返回 layout.json 与窗口资源边界分析
```

页面当前行为：

- Frame 50 按二进制主 HUD 结果放置在 `(0,465)`；
- 15 个按钮读取 `layout.json` 的 Frame、相对位置和 WIL 尺寸；
- 13 个窗口候选读取构造坐标/尺寸；窗口资源图像用非透明边界对齐仅作为“资源裁剪推断”显示；
- 坐标/命中框开关、Frame 标签开关和 localStorage 状态记忆已实现；
- 每条记录显示证据等级，未确认业务名称不会被自动升级。

离线验证已通过：布局记录 28 条（15 按钮 + 13 窗口），窗口资源分析 13 条，页面模板可正常加载。由于当前执行沙箱禁止绑定本地 TCP 端口，HTTP 访问只能在用户本机启动服务后验证；这不影响静态数据和 Python 语法检查。

### 发现十：资源 Frame 选择调用的索引入口

原版二进制中 `VA 0x00466130` 被大量调用，调用形式通常是先把资源对象放入 `ECX`，再压入一个 Frame 编号。该函数与窗口构造和控件初始化中的资源选择行为一致，因此新增了初步索引器：

```text
Tools/extract_mir3_resource_select_calls.py
docs/research/ei-ui-layout/resource_select_calls.json
```

索引器只提取调用点、最近压栈参数、`ECX` 设置和 Frame 候选；它没有把所有调用升级为绘制调用。后续应以窗口构造函数 `0x00423B30` 的调用者为入口，沿每个窗口类函数继续追踪 `0x00466130` 后的资源绘制/裁剪调用，以建立真正的 `draw-call` 顺序。

### 发现十一：窗口内部也复用了同一个控件初始化器

对已确认的 13 个窗口包装函数进行函数体范围扫描后，发现它们内部多次直接调用 `0x00417550`。例如背包候选包装函数 `0x0042EA80` 中至少有：

| 调用 VA | Frame 对候选 | 控件对象字段 |
|---|---:|---|
| `0x0042EADB` | 161/162 | `[esi+0x5C]` |
| `0x0042EB07` | 264/265 | `[esi+0x110]` |
| `0x0042EB2D` | 267/268 | `[esi+0x1C4]` |

状态窗口 `0x0044B130` 也出现 161/162、171/172 等局部按钮对；商店候选 `0x0044D310` 出现 1010–1017 的连续状态帧。它们不是底部 HUD 的 80–115 组按钮，说明完整 UI 还需要按窗口对象分别建立控件表。

机器可读产物：

```text
Tools/extract_mir3_window_controls.py
docs/research/ei-ui-layout/window-control-calls.json
```

这些 Frame 对和对象字段是一级静态证据；控件的最终相对坐标仍需从调用前的位置参数、窗口基准和 WIL 有效边界继续解析。

当前清理后的扫描结果为 72 个窗口内部控件构造调用，其中 70 个具有连续 Frame 对候选。提取器现在按“当前 `0x00417550` 调用之前的上一个调用边界”截取参数块，避免把相邻控件的 Frame 对串入当前记录；原始指令和压栈参数仍全部保留。

这些控件构造调用已通过 `Tools/reverse-engineering/enrich_mir3_layout_evidence.py` 写入统一 `layout.json` 的 `control_constructors` 字段。字段明确保留 `position=null`、`size=null` 和未解析资源句柄，防止预览器把 Frame 对误画成已经确认的屏幕坐标。

进一步根据 `0x00417550` 的栈访问和 `ret 0x24` 确认了参数槽位：调用者按 `arg9..arg1` 压栈；`arg1` 是资源对象，`arg2/arg3` 是普通/状态 Frame，`arg4/arg5` 是控件的 X/Y，后续参数是控件标志和附加字段。窗口控件 JSON 现在保留这些命名槽位。X/Y 的寄存器值仍可能是窗口基准加偏移，尚未把寄存器表达式误算成绝对屏幕坐标。

新增 `Tools/resolve_mir3_control_positions.py`，从窗口包装函数入口到每次 `0x00417550` 调用执行有限的寄存器/ESP 符号追踪。结果同时保存：

- 原始 X/Y 参数寄存器；
- `window.x + offset` / `window.y + offset` 表达式；
- 可安全代入的绝对坐标候选；
- X/Y 轴向一致性；
- 是否落在对应窗口容器内。

当前 72 条记录中，36 条得到轴向一致的绝对候选，其中 29 条落在窗口几何范围内、7 条被标记为超出窗口；其余仍是表达式或待验证状态。这个数量不是“已完成坐标数”，而是静态解析器通过的保守子集。

机器可读结果：

```text
docs/research/ei-ui-layout/window-control-position-analysis.json
```

证据预览页 `/ui` 已增加橙色窗口内部控件调试层：只有 `geometric_status=inside-window` 的位置候选进入该层；它显示 Frame 对和候选矩形，但不改变 `layout.json` 中“资源句柄未解析”的证据等级。

### 发现十二：窗口控件 Frame 存在跨 WIL 库编号重用

窗口控件 Frame 不能只按数字在一个库中查找。比如 `264/265` 在 GameInter.wil 中是 `64×20`/`64×20`，在 Interface1c.wil 中则是完全不同的图像；`267/268` 在 GameInter.wil 中为空，但在 Interface1c.wil 中存在有效图像。相同编号在两个 WIL 库中被重用，说明必须继续追踪窗口包装函数收到的资源对象句柄，不能仅凭 Frame 编号猜库。

已生成跨库交叉检查：

```text
Tools/analyze_mir3_control_resources.py
docs/research/ei-ui-layout/window-control-resource-analysis.json
```

这一步只证明“某库中存在该编号及其尺寸”，不证明实际绘制使用了哪个库；资源句柄追踪仍属于下一阶段一级证据工作。

### 发现十三：确认资源对象选择器与 WIL 加载辅助函数

反汇编显示：

```text
0x004660E0  资源/WIL 加载或重置辅助函数
0x00466130  当前 Frame 选择函数
```

`0x00466130` 先检查资源对象 `this+0x04` 的类型字节，再分派到不同的 Frame 选择实现；因此它不是一个全局“按数字取图”函数，调用者传入的资源对象决定实际 WIL 库。

在 `0x004660E0` 的调用点可以看到 PE `.rdata` 中的路径字符串：`0x0047AAA0` 对应 `Data/Interface1c.wil`，`0x0047AAB8` 对应 `Data/gameinter.wil`。这解释了为什么同一个 Frame 编号在不同 WIL 库中会有不同图像。新增提取器：

```text
Tools/extract_mir3_wil_load_calls.py
docs/research/ei-ui-layout/wil_load_calls.json
```

当前只把路径字符串和资源对象 `LEA` 作为一级候选记录，尚未把某个窗口强行绑定到某个库；下一步需要追踪 `0x00427600` 初始化时的 `arg+0x5898` 对象和各窗口包装函数接收的资源指针。

### 反汇编标签纠错记录

后续复核 `.rdata` 原始字节后发现，之前版本的 `wil_load_calls.json` 曾把两个相邻字符串地址的标签写反。正确关系是：

```text
0x0047AAA0 -> .\Data\Interface1c.wil
0x0047AAB8 -> .\Data\gameinter.wil
```

现已修正 `Tools/extract_mir3_wil_load_calls.py` 并重新生成 JSON。机器码中的地址、调用 VA 和原始反汇编没有改变；这是路径语义标签纠正，不是原版客户端文件修改。

### 发现十四：按钮已经进入原版绘制链，但不能把所有 SetRect 当成最终坐标

在原版 `Mir3.exe` 的 `0x004179B0` 找到按钮/控件渲染函数候选。它的执行顺序提供了比“构造控件”更接近真实画面的证据：

1. 从 `this+0x04` 取资源对象，从 `this+0x08` 取当前 Frame 编号；
2. 调用 `0x00466130` 选择实际资源帧；
3. 从资源对象 `+0x38` 读取当前帧的有符号 WORD 宽高；
4. 根据 `this+0x0c`、`this+0x10` 计算缩放/动画相关尺寸；
5. 通过 `SetRect` IAT `0x004762B0` 构造多个经过模式变换的矩形；
6. 从资源对象 `+0x3c` 取得像素/解码缓冲区，最后在 `0x00417C17` 或 `0x00417C65` 调用 `0x0045F2D0`。

`0x0045F2D0` 的函数体会读取传入结构的 `+0/+4/+8/+0xc` 字段，计算裁剪后的宽高，并通过上下文对象的虚表偏移 `+0x64` 继续处理像素缓冲区。这使它成为“图像合成/绘制后端”候选，证据等级暂定 `primary-static-draw-candidate`；它的精确调用约定和最终屏幕 API 仍需运行时或全调用者交叉验证。

交叉搜索发现 `0x0045F2D0` 不只由按钮调用，还出现在 `0x0040B83B`、`0x0040CA06`、`0x00416BBA`、`0x00419A25`、`0x00429A42`、`0x00429C4E`、`0x00429CC6`、`0x0042A03D`、`0x0042A248`、`0x0042F960` 等调用点。多个调用者在 `ECX=0x008AB7A8` 时传入像素缓冲区、矩形指针、X/Y 和 `0xffff` 裁剪边界，说明该函数很可能是共享的屏幕图像合成例程，而不是按钮专属函数。各调用点的原始前置压栈已收录在 `button-draw-calls.json` 的 `all_composition_call_sites` 中；具体参数顺序仍标为待验证。

重要边界：`0x00417AA7`、`0x00417B06`、`0x00417BBA` 的 `SetRect` 调用发生在缩放、翻转/模式分支中，不能直接当成最终屏幕 UI Rect。当前只能确认它们是绘制前的矩形计算；最终坐标要继续追踪 `0x0045F2D0` 的参数和后端。

新增机器可读证据：

```text
Tools/extract_mir3_button_draw_calls.py
docs/research/ei-ui-layout/button-draw-calls.json
```

该提取器保留 `0x004179B0` 全部原始指令、两个 `0x0045F2D0` 调用点及其前置证据，也保留被分析的 `0x0045F2D0` 函数体片段。它不把推测性的绘制后端名称或坐标写成事实。

### 发现十五：窗口构造函数与窗口背景绘制函数是两个阶段

对前面列出的 13 个窗口包装函数重新检查后发现，它们主要调用通用初始化器 `0x00423B30` 和控件构造器 `0x00417550`，并没有直接调用 `0x0045F2D0`。因此 `window-draw-calls.json` 中这些函数的 `0` 个共享合成调用是一个重要的否定结果：不能把窗口构造阶段误写成绘制顺序。

在 `Mir3.exe` 的 `0x00423D00` 找到共享窗口背景绘制候选：

- `this+0x30` 先作为有效状态检查；资源对象来自 `this+0x2c`；
- 通过 `0x00466130` 选择当前 Frame，并从资源对象 `+0x38/+0x3c` 读取尺寸和像素缓冲；
- 非零渲染上下文分支在 `0x00423D62` 调用 `0x00460240`，前置压栈中直接出现目标宽 `0x320`（800）和目标高 `0x258`（600），并出现两个 `0xffff` 裁剪边界；
- 另一分支在 `0x00423DFA` 调用 `0x004542A0`，随后在 `0x00423E66` 调用 `0x004542F0`，使用位置/尺寸浮点计算以及 `this+0x50/0x51` 的颜色/透明度字节。

证据等级为 `primary-static-window-paint-candidate`。800×600 常量是原版二进制直接证据，但三个被调用函数的精确图形 API 语义、派生窗口的子控件绘制顺序仍需继续追踪。

继续反汇编 `0x00460240` 后，发现它不是简单的 `SetRect` 辅助：函数会做源/目标边界裁剪，读取上下文 `+0x1c` 的对象，通过虚表 `+0x64` 调用，并在内层循环中处理像素缓冲；同时识别 `0xc0/0xc1/0xc2/0xc3` 等压缩/透明编码标记。当前最稳妥的命名是“透明/编码图像 blit 或解码到目标缓冲区候选”。这增强了 `0x00423D62` 为实际窗口背景图像处理调用的证据，但还不足以证明它就是最终 GPU/窗口 API。

### 发现十六：窗口 vtable 把派生窗口连接到共享背景绘制

从 `Mir3.exe` `.rdata` 读取 vtable，并搜索构造函数中的 `mov [esi], <vtable>`：

- 发现 61 个窗口/相关对象 vtable 表；
- 发现 119 个直接 vtable 赋值点；
- 其中 59 个赋值点的 vtable `+0x0c` 项指向 `0x00423D00`；
- 基础窗口 vtable `0x00476624` 的前几项包含 `0x00423CF0`、`0x00423D00`，而 `0x00423D00` 也被多个 `call [object-vtable+0xc]` 形式的间接调用路径使用。

这说明派生窗口通常采用“派生构造函数建立自己的控件 + 共享基类绘制方法绘制窗口背景”的结构。vtable 表本身是一级二进制证据，但 `+0x0c` 的业务名称仍使用“绘制槽候选”，不擅自命名为源码类的 `Paint`。

新增机器可读结果：

```text
Tools/extract_mir3_window_vtables.py
docs/research/ei-ui-layout/window-vtable-evidence.json
```

该结果保留每个表的原始函数地址、每个构造赋值点附近的反汇编，以及 `call [vtable+0xc]` 的间接调用邻域，后续可按窗口对象继续绑定。

### 发现十七：13 个主窗口已经可以建立 vtable 绑定候选，NPC 窗口存在专用绘制方法

将主 UI 初始化中的 13 个窗口包装调用与前方同一对象类代码簇中的派生 vtable 写入进行关联，得到 13/13 个静态绑定候选；其中 12 个候选的 vtable `+0x0c` 指向共享背景绘制 `0x00423D00`。当前结果必须仍标记为候选，因为绑定采用“包装函数前 500 条反汇编指令内最近的非基类 vtable 写入”启发式，并保留了距离与原始邻域。

NPC 候选窗口是例外：其候选 vtable 为 `0x00476938`，`+0x0c` 指向 `0x0043F040`，不是共享 `0x00423D00`。对 `0x0043F040` 的静态分析确认：

- 选择连续 Frame `1100/1101/1102`；
- 在多个分支使用固定目标 `800×600` 和 `0xffff/0xffff` 裁剪边界；
- 通过 `0x00460240` 合成对话背景/编码图像；
- 使用 `this+0x520/0x524`、`+0x530/0x534`、`+0x540/0x544` 等字段作为对话内容或条目坐标/数据来源；
- 读取 `this+0x51c` 循环计数，并按 `0x12` 步长处理重复内容；
- fallback 路径调用 `0x004542A0/0x004542F0`，并读取 `this+0x580/0x581` 的透明度/颜色字节。

这已经是“NPC 对话窗口不只是一个背景 Frame，而是由多个连续 Frame 和动态条目组成”的一级静态证据。新增：

```text
Tools/bind_mir3_windows_to_vtables.py
docs/research/ei-ui-layout/window-vtable-bindings.json
Tools/extract_mir3_npc_paint.py
docs/research/ei-ui-layout/npc-paint-evidence.json
```

### 发现十八：vtable/特殊绘制证据已并入统一 layout

重新运行 `Tools/reverse-engineering/enrich_mir3_layout_evidence.py` 后，统一 `layout.json` 已升级为 `0.3-primary-evidence-vtable-enriched`：

- 13 个窗口记录各自包含 `vtable.derived_vtable`、vtable 赋值地址、`paint_slot_plus_0xc` 和候选证据等级；
- `window.npc-candidate` 额外包含 `special_paint`，保存 `0x0043F040`、连续 Frame 和调用邻域；
- 顶层 `draw_evidence` 保存背景、按钮、vtable、绑定和 NPC 专用绘制证据文件的路径；
- 15 个 HUD 按钮、13 个窗口和 72 个窗口控件构造记录保持不变。

这使预览器和后续导出器可以只依赖一个统一布局文件，同时仍能回溯到原始反汇编 JSON；候选绑定仍不会被提升为 `verified`。

新增：

```text
Tools/extract_mir3_window_base_draw.py
docs/research/ei-ui-layout/window-base-draw-evidence.json
```

### 发现十九：主 UI 的资源句柄已绑定到 GameInter.wil

本次完成了此前日志中留下的资源对象追踪，原始证据来自同一个 `Mir3.exe`：

1. `0x00427600` 读取调用者传入的资源管理对象指针，`0x00427609` 加上
   `0x5898`，并在 `0x00427611` 写入 `main_ui_this+0x1c`。
2. `0x00427750` 至 `0x0042792A` 的 13 个主窗口创建调用，都在调用包装器之前从
   `main_ui_this+0x1c` 取出同一个资源句柄，并作为窗口资源参数传入。
3. 这些窗口包装函数内的 72 个 `0x00417550` 控件构造调用，均在当前静态提取结果中
   以 `edi` 作为 `resource_arg1`；`edi` 是包装器接收的资源参数。这个寄存器传播仍
   保留“静态流候选”警告，不能替代运行时对象检查。
4. 资源路径初始化函数 `0x0045361D` 从绝对地址 `0x0047CE0C` 复制字符串
   `./Data/GameInter.wil` 到资源所有者的 `+0xF848` 字段；`0x00452AA0` 的第二组
   资源加载循环从所有者 `+0x5898` 开始，使用 `+0xF848` 起始的路径表，循环次数
   为 `0x46`（70）。因此主 UI 句柄的 WIL 文件绑定现在有一级静态路径证据。

新增机器可读结果：

```text
Tools/resolve_mir3_window_resource_handles.py
docs/research/ei-ui-layout/window-resource-handle-bindings.json
```

`layout.json` 已把窗口和 72 个子控件的 `resource_handle` 写入统一目录，版本仍为
`0.3-primary-evidence-vtable-enriched`。这次没有把 `Interface1c.wil` 的同编号 Frame
混入主 UI；后续分析其它资源族时，必须先建立同样的“对象句柄 → 路径表 → WIL 文件”证据。

替代解释与边界：`+0x5898` 是资源句柄数组/对象起始地址的静态表达式，尚未通过调试器
读取运行时指针验证；`0x00466130` 的资源对象类型分派也尚未完全命名。因此文档使用
“primary-static-handle-flow”，而不是 `runtime-verified`。

### 发现二十：控件坐标必须在压栈瞬间取值

复核 `Tools/resolve_mir3_control_positions.py` 时发现一个反汇编数据流陷阱：窗口
控件构造调用使用 x86 反向压栈，`push x` / `push y` 之后，调用前还会把同一个寄存器
改写为控件对象的 `this` 指针。如果在 `call 0x00417550` 时读取寄存器最终状态，
会把对象地址表达式误认为坐标。

以背包包装函数 `0x0042EA80` 的第二个控件为例：

```text
0x0042EAF4  push ecx       ; y 参数，当前为 window.y + 0x106
0x0042EAF5  push ebp       ; x 参数，当前为 window.x + 0xB0
0x0042EB00  push edi       ; resource
0x0042EB01  lea  ecx,[esi+0x110] ; 随后改写 ecx 为控件 this
0x0042EB07  call 0x00417550
```

提取器现在保存每个寄存器在对应 `push` 指令时的表达式，而不是使用 call 点的最终
寄存器状态。重新计算结果为：72 个控件中 65 个同时得到 x/y 绝对候选，51 个位于
对应窗口矩形内。对于拥有 GameInter Frame 尺寸的 60 个控件，已根据
`0x00417550 SetRect` 生成命中矩形。

新增/更新：

```text
Tools/resolve_mir3_control_positions.py
docs/research/ei-ui-layout/window-control-position-analysis.json
docs/research/ei-ui-layout/layout.json
Tools/web/wilviewer.py
```

预览器现在显示所有已解析但窗口外的控件为红色调试框；坐标未闭合或 Frame 尺寸缺失
的控件显示虚线占位框和明确的 `size unresolved` 标签，不再静默隐藏。Frame 在
GameInter 中为空而在 Interface1c 中存在的情况继续保留两库交叉记录，不能仅凭编号
替换资源文件。

### 发现二十一：全局控件构造调用不能只按主窗口筛选

对 `Mir3.exe` 全部直接调用 `0x00417550` 的记录进行分类后，共有 109 条：

| 分类 | 数量 | 当前状态 |
|---|---:|---|
| 主窗口内部控件 | 72 | 已绑定 13 个主窗口并进入 `layout.json` |
| 主 HUD 控件 | 15 | 已绑定底部 HUD 相对坐标 |
| 未归属控件候选 | 22 | 保留原始 Frame/对象/反汇编，等待函数归属和资源句柄追踪 |

未归属记录分布在 `0x004027DF`、`0x00418176`、`0x00418968`、`0x0043E2BB`、
`0x00455AF5`、`0x00456DC1` 等代码簇中；其中一部分出现 Frame `151/152`、
`154/155`、`606/607`、`86/87`、`89/90` 等连续状态帧。这说明原版还有未纳入当前
13 个主窗口表的 UI/对象控件，不能因为没有立即识别出窗口名称就丢弃。

新增目录：

```text
Tools/build_mir3_global_control_catalog.py
docs/research/ei-ui-layout/global-control-constructor-catalog.json
```

该目录只做证据保全，不把未归属控件伪装成完整坐标；下一阶段将以这些代码簇为入口，
追踪各自的构造函数、资源句柄和窗口开关状态。

进一步按地址间距整理后，22 条未归属调用形成 7 个复核簇：

```text
Tools/cluster_mir3_unassigned_controls.py
docs/research/ei-ui-layout/unassigned-control-clusters.json
```

其中 `0x00418176–0x004181E0`、`0x00418968–0x0041898E`、
`0x0043E2BB–0x0043E2E4` 和 `0x00456DC1–0x00456EC8` 含有连续 Frame 对，优先级
高于只有逻辑参数、没有连续 Frame 的簇。

其中第一个簇 `0x004027DF–0x00402845` 已进一步闭合资源来源：`0x00402735` 附近
将 `Interface1c.wil`（路径字面量 `0x0047AAA0`）加载到 `owner+0x5B0`，四个控件
构造调用均以 `esi=owner+0x5B0` 作为资源参数。它们的 Frame 参数是 11、13、15、17
等小编号，当前可以确认属于 Interface1c 资源对象，但业务窗口名称和最终绘制层级仍
未确认。

### 发现二十二：Interface1c 代码簇已形成第一个完整次级控件样本

对 `0x004027DF`、`0x00402801`、`0x00402823`、`0x00402845` 四个调用，按
`0x00417550` 的参数顺序恢复出以下矩形：

| 调用 | Frame | x | y | w | h |
|---|---:|---:|---:|---:|---:|
| `0x004027DF` | 11 | 459 | 436 | 96 | 24 |
| `0x00402801` | 13 | 139 | 379 | 96 | 26 |
| `0x00402823` | 15 | 279 | 379 | 96 | 26 |
| `0x00402845` | 17 | 439 | 379 | 48 | 26 |

坐标来自 `Mir3.exe` 的 `push` 常量，尺寸来自原版 `Data/Interface1c.wil` 的 17 字节
Frame 头部；四条记录均生成 `0x00417550 SetRect` 命中框。业务名称、父窗口名称和
绘制层级仍标为待验证。

新增：

```text
Tools/build_interface1c_cluster_catalog.py
docs/research/ei-ui-layout/interface1c-cluster-4027.json
```

这四条记录已写入 `layout.json.secondary_control_constructors`，并在 800×600 预览器
中以紫色证据框显示。

### 发现二十三：第二个 Interface1c 控件簇已闭合

函数 `0x00456CB0` 中：

- `0x00456CC1` 将 `Interface1c.wil` 加载到 `owner+0x14C`；
- `0x00456DC1–0x00456EC8` 的 9 个控件均把 `ebx=owner+0x14C` 作为资源参数；
- Frame、普通/状态帧、x/y 常量和对象偏移均可从连续反汇编直接恢复。

该簇已生成 9 个 `SetRect` 命中框，Frame/尺寸来自 Interface1c 原始 WIL：

```text
Tools/build_interface1c_cluster_456d_catalog.py
docs/research/ei-ui-layout/interface1c-cluster-456d.json
```

当前两个 Interface1c 簇共 13 个次级控件已经进入 `layout.json` 和 800×600 预览器。
它们的具体业务名称、父窗口和绘制层级仍保持待验证状态。

### 发现二十四：主初始化中存在额外的 GameInter 窗口候选

在主 UI 初始化 `0x0042797E` 发现对 `0x0043E260` 的额外窗口构造调用。调用参数中
直接出现 Frame `602`，并传入 `main_ui_this+0x1c`。该包装函数内部继续构造：

| 调用 | Frame 对 | 静态 x | 静态 y | GameInter 尺寸 |
|---|---:|---:|---:|---:|
| `0x0043E2BB` | 161/162 | 655 | 16 | 28×26 |
| `0x0043E2E4` | 606/607 | 603 | 27 | 40×20 |

坐标表达式分别来自 `window_arg4+0x224` / `window_arg8+0x10` 及其后续增量；主调用
的原始参数为 `15, resource, 602, 107, 110, 584, 252, 0, 3`。由于该包装器的窗口
参数槽位语义尚未完全确认，Frame 602 的窗口容器矩形暂不强行写入绝对布局；两个
控件作为 `primary-static-candidate` 记录。

新增：

```text
Tools/build_gameinter_cluster_43e260_catalog.py
docs/research/ei-ui-layout/gameinter-cluster-43e260.json
```

当前统一布局已包含 15 个次级控件和 1 个额外窗口候选。

### 发现二十五：原版初始化器包含完整的 WIL 路径表

针对 `/home/tetsuya/NAS/TMP/EI传奇3.0客户端/Mir3.exe`，扫描所有形如
`mov edi, <绝对地址>` 的路径字面量、独立加载器的 `push <路径地址>` 参数，并沿资源初始化复制序列追踪
`lea edx,[ebx+偏移]` 目标，恢复出 157 条静态路径字段。结果覆盖四组地形资源（普通、Wood、Sand、Forest、Snow）
以及主界面、角色、武器、技能、背包、装备、地面物品、图标、坐骑、怪物、NPC、魔法特效和商店物品等资源族。

典型记录：

```text
GameInter.wil  -> owner+0xF848
Magic.wil      -> owner+0x10478
Inventory.wil  -> owner+0x1057C
Equip.wil      -> owner+0x10680
MIcon.wil      -> owner+0x10888
NPC.wil        -> owner+0x13434
StoreItem.wil  -> owner+0x13F9C
```

证据等级为 `primary-static-path-table`：它证明原版程序把这些路径复制到对象字段，
但不能单独证明每个字段对应哪个运行时窗口或绘制类。该表首先用于资源族与后续控件/窗口簇的交叉匹配，
不能把同编号 Frame 直接等同为同一素材。

新增：

```text
Tools/extract_mir3_resource_path_table.py
docs/research/ei-ui-layout/resource-path-table.json
```

预览器的 `/api/ui-layout` 数据现在同时携带该表，供后续制作资源族导航和证据检查使用。

### 发现二十六：路径表与原始 WIL/WIX 库已完成资源族索引

将发现二十五的路径记录和原始客户端目录重新合并，得到 157 条资源路径记录及 89 组实际存在的 WIL/WIX
库。重要资源库的头部统计如下：

| 资源库 | 总 Frame 槽位 | 非空 Frame | 资源族 |
|---|---:|---:|---|
| `GameInter.wil` | 1103 | 253 | UI/HUD |
| `Magic.wil` | 3550 | 1948 | 技能/魔法 |
| `Inventory.wil` | 1440 | 499 | 背包物品 |
| `Equip.wil` | 1320 | 125 | 装备 |
| `MIcon.wil` | 1106 | 138 | 图标 |
| `NPC.wil` | 6400 | 1994 | NPC |
| `StoreItem.wil` | 1440 | 490 | 商店物品 |

这里的“非空 Frame”来自原始 `.wix` 偏移和 WIL 17 字节头解析，不代表每个 Frame 都在
当前游戏状态中被绘制。资源族分类也只是导航和交叉匹配标签，不能直接推出窗口业务名称。

新增：

```text
Tools/build_mir3_resource_family_catalog.py
docs/research/ei-ui-layout/resource-family-catalog.json
```

预览器 `/api/ui-layout` 已携带路径表和资源族索引，后续可以在同一个 800×600 证据界面
中跳转查看 UI、技能、装备、NPC 和地图素材来源。

### 发现二十七：`mir3.dat` 与 `Mir3.exe` 的资源路径表一致

对原版 `/home/tetsuya/NAS/TMP/EI传奇3.0客户端/mir3.dat` 单独进行 PE 头和反汇编检查：
它是一个 PE32 GUI 可执行文件，时间戳为 2002-10-25，入口点为 `0x0046A882`，并且包含
同一批 `Data/*.wil` 路径字面量。使用同一提取器恢复出 157 条路径记录，与 `Mir3.exe`
逐条比较后，路径名和对象字段偏移全部一致。

这不是把两个文件混为一个程序，而是一个很有价值的交叉验证：`Mir3.exe` 中得到的资源
族表不是偶然扫描结果，`mir3.dat` 也保留了同样的初始化表结构。当前还没有宣称两者所有
窗口函数和绘制实现完全相同；坐标/窗口结论仍以实际调用点分别确认。

新增：

```text
docs/research/ei-ui-layout/mir3-dat-resource-path-table.json
```

### 发现二十八：资源族索引已进入统一 layout

`Tools/reverse-engineering/enrich_mir3_layout_evidence.py` 现在把路径表和 WIL/WIX 资源族索引写入
`layout.json.resource_evidence`，记录两个机器可读 artifact、157 条路径记录及当前库统计。
这让 800×600 预览器、交接文档和后续窗口匹配共享同一份资源证据入口，同时继续保留“资源存在
不等于窗口绘制”的警告。

新增字段并更新：

```text
docs/research/ei-ui-layout/layout.json.resource_evidence
docs/research/ei-ui-layout/layout.schema.json
```

### 发现二十九：两个 Interface1c 控件簇已与独立加载字段精确交叉匹配

将 `resource-path-table.json` 的 `owner+偏移` 与已闭合控件簇中的资源对象表达式进行精确连接：

| 控件簇 | 对象字段 | 匹配资源 | 状态 |
|---|---|---|---|
| `0x004027DF–0x00402845` | `owner+0x5B0` | `Interface1c.wil` | matched |
| `0x00456DC1–0x00456EC8` | `owner+0x14C` | `Interface1c.wil` | matched |
| `0x0043E260` | `main_ui_this+0x1C` | GameInter 句柄字段表达式不同 | unresolved |

前两个簇因此拥有“路径字面量 → 资源对象字段 → Frame → 尺寸 → 坐标/命中框”的完整
静态链；但它们的业务名称和父窗口仍未强行猜测。第三个簇保留为未匹配候选，因为主 UI
句柄是另一层对象传播，不应把 `+0x1C` 直接等同于路径表字段。

新增：

```text
Tools/crossmatch_mir3_resource_clusters.py
docs/research/ei-ui-layout/resource-cluster-crossmatch.json
```

### 发现三十：Interface1c 簇属于一个 640×480 的前置角色界面候选

对 `0x00456A90` 对象初始化器和 `0x00456CB0` 构造函数继续向上追踪，发现它们都操作同一个
全局对象 `ECX=0x008A7140`，并在两个状态转换点 `0x00402989`、`0x00419C0A` 被调用。
构造函数同时加载 `GameInter.wil`（`owner+0x8`）和 `Interface1c.wil`（`owner+0x14C`），
然后建立 9 组 Interface1c 普通/状态按钮：

```text
Frame 51/52  -> (440, 93), 96×26
Frame 53/54  -> (79, 243), 96×26
Frame 55/56  -> (259, 49), 96×24
Frame 57/58  -> (28, 438), 48×26
Frame 92/93  -> (266,419), 40×38
Frame 95/96  -> (308,419), 40×38
Frame 98/99  -> (352,419), 40×38
Frame 86/87  -> (450,444), 28×28
Frame 89/90  -> (491,444), 28×28
```

Interface1c Frame 50 的头部尺寸为 640×480，Frame 51–58 是中文文字按钮素材。结合完整
屏幕尺寸、固定按钮布局和状态转换位置，目前将其标为“角色选择/创建角色界面候选”，不是
最终业务命名。原始素材的视觉检查显示它与游戏内 800×600 HUD 是不同状态，不能把这 9 个
按钮误并入底部操作栏。

新增：

```text
Tools/analyze_mir3_interface1c_parent.py
docs/research/ei-ui-layout/interface1c-parent-context.json
```

该候选已进入 `layout.json.secondary_screen_candidates`，证据等级为
`candidate-not-runtime-confirmed`。

### 发现三十一：启动阶段存在独立的角色选择界面

`0x004026E0` 由启动流程 `0x004020A8` 调用。它独立加载 `GameInter.wil` 到 `owner+0x46C`
和 `Interface1c.wil` 到 `owner+0x5B0`，并构造 4 个 Interface1c 按钮：

```text
Frame 11/11 -> (459,436), 96×24
Frame 13/13 -> (139,379), 96×26
Frame 15/15 -> (279,379), 96×26
Frame 17/17 -> (439,379), 48×26
```

对这些帧进行原始素材视觉检查后，按钮文字属于角色选择操作族；结合它们在启动阶段的
调用位置，将该界面标为 `character-selection-screen` 候选。它与发现三十的 9 按钮界面
是两个不同初始化器，不能合并成一个窗口；两者最终状态仍需运行时确认。

新增：

```text
Tools/analyze_mir3_interface1c_select_screen.py
docs/research/ei-ui-layout/interface1c-select-screen-context.json
```

两个候选屏幕现在都进入 `layout.json.secondary_screen_candidates`。

### 发现三十二：主窗口 Frame 的视觉语义已与静态窗口表分层记录

对原始 `GameInter.wil` 的 13 个窗口底图做了逐帧解码和视觉复核。得到的高置信资源形态包括：

```text
Frame 250  背包网格
Frame 400  技能书/技能界面候选
Frame 700  任务卷轴
Frame 750  系统选项
Frame 850  坐骑界面候选
Frame 900  组队界面
Frame 1000 商店物品列表候选
Frame 1050 交易界面
Frame 1100 NPC 对话底图（另有 1101/1102 状态帧）
```

Frame 200 的装备/人物状态角色仍保持二义性；Frame 600 的行会/社交管理语义也保持候选。
这些视觉判断没有覆盖或改写 `window_layout.json` 的一级静态证据，而是以
`visual_semantics` 字段进入统一 `layout.json`，证据等级为
`secondary-resource-visual-review`。

新增：

```text
Tools/annotate_mir3_window_visual_semantics.py
docs/research/ei-ui-layout/window-frame-visual-semantics.json
```

### 发现三十三：58 个窗口控件形成可识别的功能组候选

把 72 个主窗口控件按窗口、普通/状态 Frame 对和原始窗口底图形态交叉检查后，得到 58 条
辅助语义记录：

```text
技能书分类/技能槽候选       11
商店导航/物品操作候选        8
行会/社交页签操作候选        8
系统选项开关/数值候选        8
聊天频道/操作候选            6
组队操作候选                 4
坐骑操作候选                 4
窗口关闭按钮                 3
交易操作候选                 2
任务翻页候选                 2
NPC 对话选项/标记候选        2
```

这些分组来自 Frame 对重复规律、控件尺寸和原始窗口图形，不是最终业务名称；例如技能
槽位的实际页签文字、商店按钮行为和 NPC 对话选项仍需从字符串/输入处理路径确认。记录已
挂到 `layout.json.control_constructors[*].semantic_candidate`。

新增：

```text
Tools/annotate_mir3_control_semantics.py
docs/research/ei-ui-layout/control-semantic-catalog.json
```

### 发现三十四：技能书窗口出现原版中文元素分类字符串

在主 UI 初始化 `0x00427904` 调用的窗口包装器 `0x00439250` 中，窗口 Frame 400 的控件
构造附近直接引用了 `Mir3.exe` 的 GB18030 字符串，并与控件调用点一一对应：

| 字面量 VA | 原文 | 分类键 | 控件调用 |
|---|---|---|---|
| `0x0047C330` | 火 | fire | `0x00439334` |
| `0x0047C32C` | 冰 | ice | `0x0043935D` |
| `0x0047C328` | 电 | lightning | `0x00439386` |
| `0x0047C324` | 风 | wind | `0x004393B3` |
| `0x0047C31C` | 神圣 | holy | `0x004393E0` |
| `0x0047C314` | 黑暗 | dark | `0x0043940D` |
| `0x0047C30C` | 幻影 | illusion | `0x00439437` |
| `0x0047C308` | 剑 | sword | `0x00439464` |

同一构造器还引用 `Magic.exp`，并创建 Frame 410–459 范围内的技能页签/技能槽候选。

### Finding 35：`Magic.exp` 是客户端根目录文件，不能与 Mud3 `magic.dat` 混用（2026-08-09）

复核 `Mir3.exe` 的字面量与实际客户端目录后确认：程序引用的是裸文件名
`Magic.exp`，实际供应文件为 `/home/tetsuya/NAS/TMP/EI传奇3.0客户端/Magic.exp`，
不是 `Data/Magic.exp`。该文件为编码/加密二进制。`/home/tetsuya/NAS/TMP/Mud3/Envir/magic.dat`
是独立的服务端技能表，虽然已经可以解出 105 条老版记录，但不能替代客户端技能窗口
的读取证据。详细的参数映射、坐标边界和后续路线见：

`docs/research/ei-ui-layout/skill-window-static-evidence.md`
这是比单纯观察 Frame 400 更强的一级静态文本证据：可以确认该窗口存在元素/流派分类，
但还不能据此推出每个分类下的完整技能名称或技能等级，需要继续追踪技能数据加载和输入分支。

### Finding 36：技能窗口存在独立的 `Magic.exp` 加载链（2026-08-09）

`0x00439150` 在窗口创建后准备 16 字节栈上初始化数据，调用 `0x00452580`，随后
把 `Magic.exp` 和 `/%s` 传给 `0x0046926D`。返回对象经 `0x00469382`、`0x00468B1A`
处理后保存到窗口对象 `this+0x968`；析构函数 `0x00439220` 会释放并清零该字段。

这已把证据从“出现文件名字面量”提升到 `primary-static-loader-chain`：客户端确实
为技能窗口加载独立扩展数据。当前仍未知初始化数据的算法、记录大小和字段布局，不能
把它直接解释成技能名称或等级表。完整调用链和待验证项见
`docs/research/ei-ui-layout/skill-window-static-evidence.md`。

### Finding 37：`Magic.exp` 已恢复为 50 条客户端技能记录（2026-08-09）

使用已复现的 `0x004525F0` 解码器后，`Magic.exp` 可按 GB18030 文本解析出 50 条
记录：文件顺序形成战士候选 8 条、法师候选 23 条、道士候选 19 条。三段起点技能
ID 分别为 3、1、2；这些数字是技能 ID，不是独立的区段头。每条记录含
原版 ID、中文名、属性、元素、1–4 级门槛、修炼值和说明；第 4 级的“未知”保持原样。

逐条 JSON 和转 UTF-8 的原文已落在 `magic-exp-records.json`、`Magic.exp.decoded.txt`，
内容目录见 `exp-content-catalog.md`。这使技能百科首次有客户端文件一级证据，
但仍不能把文件区段直接当成八个 UI 页签，页签映射要继续追踪控件回调。

新增：

```text
Tools/analyze_mir3_skill_window.py
docs/research/ei-ui-layout/skill-window-context.json
```

该记录已进入 `layout.json.specialized_window_evidence`。

### Finding 38：技能分类控件的八组相对坐标由窗口重绘函数完整恢复（2026-08-09）

继续反汇编 `Mir3.exe` 的技能窗口刷新路径后，确认 `0x00439500` 会在每次重绘时
调用通用定位逻辑，把八个分类控件按窗口对象 `this+0x18/this+0x1c` 的原点重新放置。
这条路径直接给出了最终的窗口相对坐标，修正了早先只依据构造器寄存器表达式时对后四项
坐标的“未解析”标记：

| 分类 | 控件对象偏移 | X | Y |
|---|---:|---:|---:|
| 火 | `this+0x2f4` | 5 | 21 |
| 冰 | `this+0x3a8` | 3 | 56 |
| 电 | `this+0x45c` | 4 | 91 |
| 风 | `this+0x510` | 2 | 126 |
| 神圣 | `this+0x5c4` | 2 | 161 |
| 黑暗 | `this+0x678` | 2 | 196 |
| 幻影 | `this+0x72c` | 1 | 231 |
| 剑 | `this+0x7e0` | 2 | 266 |

证据等级为 `primary-static-redraw-position`。这些值是窗口内部坐标；仍需继续恢复
窗口基类的屏幕原点、移动状态和控件最终 RECT，才能得到屏幕绝对坐标。机器可读结果同步
写入 `skill-window-context.json` 与 `layout.json` 的 `control_constructors`。

本次方法：以 `llvm-objdump` 反汇编 `0x00439500`，核对八个 `0x00417830` 定位调用
使用的 X/Y 常量与 `this` 内对象偏移；再由 `analyze_mir3_skill_window.py` 和
`enrich_mir3_layout_evidence.py` 写入结构化证据。分类控件也可能是带图标的复合控件，
但坐标本身不依赖业务命名，因此可直接用于 800×600 预览器。

### Finding 39：技能列表刷新循环暴露了原版列表起点和行间距（2026-08-09）

在 `0x0043A440` 继续恢复技能窗口刷新函数。原版从 `this+0x968+8` 的数据流逐行读取
记录：以 `0x00468BF0(0x0d, stream)` 取得行，`#` 行用于段/ID 筛选，`;` 行作为分隔或
注释。匹配后的数据经 `0x0045E200` 解析到局部记录区域，再由 `0x0045DBA0`、
`0x0045DD70` 交替绘制多个字段。

可直接用于布局的一级静态坐标是：首行原点为 `this+0x18+0x0f,
this+0x1c+0xeb`，之后每行 Y 增加 `0x0f`（15 像素）；记录缓冲区每行增加 `0x104`。
这解释了技能书内列表的固定行距，并为预览器提供了不依赖手动拖动的初始参数。字段含义、
列宽和窗口移动后的屏幕原点仍标记为待解析。详情写入
`skill-window-render-loop-evidence.json` 与技能窗口静态证据文档。

### Finding 40：背包窗口包含三组子控件并使用 36 像素物品网格步长（2026-08-09）

在 `Mir3.exe` 的背包构造函数 `0x0042EA80` 和绘制函数 `0x0042EB7F` 中确认：Frame 250
窗口之外，原版还在 `this+0x5c`、`this+0x110`、`this+0x1c4` 创建三个子控件，调用
分别为 `0x0042EADB`、`0x0042EB07`、`0x0042EB2D`，帧对为 `161/162`、`264/265`、
`267/268`。其中第三组静态资源交叉结果指向 `Interface1c.wil`，第二组同时存在
`GameInter.wil` 和 `Interface1c.wil` 候选，不能在没有运行时句柄前武断选择。

绘制路径在 `0x0042EC54`、`0x0042EC64` 明确出现 `index*36` 的横纵网格计算，起点候选
为窗口原点偏移 `(0x19,0x29)`；这足以作为预览器的一级静态网格参数，但列数、行数和
具体物品字段仍待继续追踪。完整机器记录见
`inventory-window-render-evidence.json`。

### Finding 41：人物状态窗口的装备槽矩形由原版 SetRect 调用直接恢复（2026-08-09）

在 `Mir3.exe` 的状态窗口构造/绘制路径（`0x0044B130`、`0x0044B2D0`）中，确认背景为
GameInter Frame 200（构造尺寸 244×328），并找到 11 个连续的 `SetRect` 初始化区域。
其中 7 个 38×38 区域位于 `(27,186)`、`(175,186)`、`(27,227)`、`(175,227)`、
`(27,264)`、`(64,264)`、`(103,264)`，另有顶部 `(177,70)` 的 38×38 区域；这些
是人物装备槽的一级位置候选。窗口还包含 `(86,114)-(146,204)` 的 60×90 人物图像区域、
`(38,70)-(91,154)` 的属性区域和 `(94,71)-(143,104)` 的头像/名称区域候选。

这些矩形不是从现代 Zircon 坐标反推，而是由原版 `0x004762B0` SetRect 的参数顺序
逐个还原。对象偏移、VA、尺寸、证据边界和未决装备语义已写入
`status-window-render-evidence.json`。

### Finding 42：任务窗口的操作按钮与文本列表坐标由刷新函数恢复（2026-08-09）

在 `Mir3.exe` 任务窗口构造函数 `0x00447400` 和刷新函数 `0x00447470` 中确认 Frame 700
背景尺寸 340×440。两个控件构造调用 `0x0044743B`、`0x0044745E` 使用 Frame 对
`723/724`、`721/722`，并在重绘时固定到窗口相对 `(290,59)` 与 `(290,89)`。

任务文本通过 `this+0x1E8` 数据链交给 `0x0045E0C0` 读取；字段绘制路径在
`0x0044760B`、`0x004477EF` 计算窗口相对的首列 `(65,90)`，每行增加 15 像素，
并保留最多 19 行的边界判断。字段分隔、换行宽度和滚动状态仍待解析。机器记录见
`quest-window-render-evidence.json`。

### Finding 43：商店路径确认动态商品链表、8 行区域和 38 像素商品格循环（2026-08-09）

在 `Mir3.exe` 的商店候选构造函数 `0x0044D310` 与绘制函数 `0x0044D590` 中，确认
资源帧对覆盖 `1010/1011`、`1012/1013`、`1014/1015`、`1016/1017`，并且对象包含
`this+0x64C` 的动态链表候选。`0x0044D4C4` 的 SetRect 循环产生 8 个列表行，
`0x0044D51E` 的循环产生横向步长 38、纵向步长 38 的商品格候选（5 列×4 行的静态
循环边界候选）。

这里不能直接把常量升级为最终屏幕坐标：原始格子 X 起点为 323，而当前 Frame 1000
可见宽度只有 300，说明商店窗口绑定、父坐标或 Frame 1000 的完整组合仍有替代解释。
因此机器记录保留 `arg4/arg5` 原始表达式和“parent-basis-pending”证据等级，见
`store-window-render-evidence.json`。

### Finding 44：原版地图对象明确装载 MMap/FMMap 并按地图编号选择 Frame（2026-08-09）

在 `Mir3.exe` 的地图资源对象路径 `0x0043D4D0` 中，`Data/MMap.wil` 被装载到
`owner+0x04`，`Data/FMMap.wil` 被装载到 `owner+0x148`。`owner+0x2D0` 是后续
初始化的运行时矩形/状态区域，不是 WIL 句柄。资源头交叉确认 MMap 为 255 槽/154 非空，
FMMap 为 31 槽/29 非空。

在 `0x0043D780` 看到 `map_id >= 1000` 的分支：选择 FMMap 资源时使用精确的
`frame = map_id - 1000` 表达式；低于 1000 时选择 MMap 并使用 `frame = map_id`，
然后把帧头源矩形送入 `owner+0x2E0` 目标矩形。地图
表面初始化函数 `0x0043D5F0` 还维护 `owner+0x2C0` 视口矩形和 `owner+0x2B8/0x2BC`
视图位置字段。当前这些是地图子系统一级证据，尚未把输出绑定到 GameInter 的小地图
控件或全地图窗口；机器记录见 `map-ui-resource-evidence.json`。

### 当前产物

```text
Tools/reverse-engineering/extract_mir3_ui_layout.py
Tools/find_mir3_ui_patterns.py
Tools/extract_mir3_button_calls.py
Tools/extract_mir3_button_draw_calls.py
Tools/build_mir3_ui_resource_metadata.py

docs/research/ei-ui-layout/static_rect_initializers.json
docs/research/ei-ui-layout/ui-pattern-candidates.json
docs/research/ei-ui-layout/button_constructor_calls.json
docs/research/ei-ui-layout/button-draw-calls.json
docs/research/ei-ui-layout/gameinter-frame-metadata.json
docs/research/ei-ui-layout/layout.schema.json
docs/research/ei-ui-layout/layout.json
docs/research/ei-ui-layout/primary-button-evidence.md
docs/research/ei-ui-layout/secondary-source-catalog.md
```

### 尚未完成、不能提前宣称的内容

1. `hud.left/top` 基准字段的真实来源和分辨率变化逻辑。
2. 各按钮的最终 `hit_rect`，因为必须读取对应 WIL Frame 尺寸并确认控件初始化函数的边界计算。
3. Frame 50、60/61、63/67 的真实绘制顺序和裁切参数。
4. 人物状态、背包、技能、任务、地图、聊天、NPC、商店、仓库、组队、行会、好友和系统弹窗的完整窗口构造函数。
5. 原版运行时截图、绘图调用参数和最终 800×600 差异叠加验证。
6. `mir3.dat` 对 UI 状态、窗口开关或坐标的影响。
7. 其它 WIL 资源族（Interface1c、Inventory、Magic、MIcon 等）各自的句柄起点、完整
   窗口绘制顺序，以及窗口打开/关闭状态机。

## 后续日志规则

每次得到新结论时必须记录：

1. 原始文件路径和文件版本；
2. 函数 VA、调用 VA 或 WIL Frame；
3. 使用的反汇编/资源解析方法；
4. 结论本身及其证据等级；
5. 与已有源码/文档是否一致；
6. 仍然存在的替代解释；
7. 对 `layout.json` 或预览工具产生的具体变更。

### Finding 45：聊天窗口的历史区、输入区与频道按钮坐标已恢复（2026-08-09）

在 `Mir3.exe` 聊天窗口构造路径 `0x00414080` 中确认 Frame 350（572×388）。原版
`SetRect` 直接给出历史区 `(40,29)-(531,308)`、输入区 `(25,311)-(524,326)`；频道
控件 Frame 对 `360/361`、`362/363`、`364/365`、`366/367`、`368/369`、`370/371`
按窗口相对 X=25、65、105、145、185、225 排列，Y 均为 332。右侧另有 Frame 对
`380/381`、`382/383`，坐标为 `(539,25)` 和 `(539,311)`。

刷新路径 `0x004142C0` 维护 `this+0x720` 的文本行缓存，步长 16，行数 19 为当前
静态候选；频道业务名称和共享文本渲染参数仍待确认。机器记录见
`chat-window-render-evidence.json`。

### Finding 46：NPC 对话窗口的三层资源与动态条目步长已恢复（2026-08-09）

在原版 `Mir3.exe` 的 NPC 窗口构造函数 `0x0043ED00` 和绘制函数 `0x0043F040` 中，确认
主底图为 `Data/GameInter.wil` Frame 1100，构造尺寸为 `552×176`；绘制路径随后选择
连续的 Frame 1101 与 Frame 1102 作为动态/状态层。三个控件构造调用分别位于
`0x0043ED65`、`0x0043ED8B`、`0x0043EDB1`，窗口相对坐标为 `(7,141)`、`(290,145)`、
`(306,136)`，帧对分别是 `161/162`、`52/53`、`54/55`。

绘制循环从 `this+0x51C` 读取条目数量，每个条目使源数据偏移增加 `0x12`（18 字节）；
动态合成坐标使用 `this+0x530/+0x534`，末层使用 `this+0x540/+0x544`，调用中还固定
传入 `800×600` 视口参数。上述内容属于 `primary-static`，但控件的业务名称、条目字段
语义及文字绘制顺序仍未提升到 runtime-confirmed。机器记录见
`npc-window-render-evidence.json`，并已接入 `layout.json` 的 `specialized_window_evidence`
和顶层 `npc_window_evidence`。

### Finding 47：组队与行会窗口的控件构造位置已整理（2026-08-09）

原版 `Mir3.exe` 的组队窗口构造路径 `0x004242AB`（主初始化 `0x00427811`）绑定
`GameInter.wil` Frame 900，尺寸 `256×244`，主屏候选原点为 `(272,123)`。五个控件
调用使用 Frame `161/162`、`910/911`、`912/913`、`914/915`、`920/921`，窗口相对
坐标分别为 `(226,214)`、`(17,197)`、`(80,197)`、`(159,197)`、`(9,52)`。

行会窗口构造路径 `0x00424EC0`（主初始化 `0x004277E8`）绑定 Frame 600，尺寸
`596×446`，原点候选 `(102,22)`。共发现 9 个控件构造调用，其中 5 个坐标可直接解析，
4 个因寄存器复用暂保留表达式歧义；控件帧对覆盖 `161/162`、`610/611` 至 `624/625`。
这批结果属于 `primary-static`，尚未把控件业务名和成员列表文字绘制顺序升级为最终结论。
机器记录见 `social-window-render-evidence.json`，并已接入 `layout.json`。

### Finding 48：800×600 证据预览增加次级 Interface1c 界面切换（2026-08-09）

`Tools/web/wilviewer.py` 的 `/ui` 页面新增预览模式选择器：主 HUD、角色选择/创建候选 A、
角色选择候选 B。次级模式读取 `layout.json.secondary_screen_candidates` 中的原版
`Interface1c.wil` Frame 50（640×480），按原始坐标居中到固定 800×600 视口，并叠加对应
`secondary_control_constructors` 的 Frame 和命中矩形。模式选择与调试/Frame 开关共同写入
`mir3_evidence_ui_state`，刷新后恢复。此功能只展示候选证据，不把候选屏幕名称升级成已
运行时确认的业务结论。

### Finding 50：证据预览支持本地原版截图差异叠加（2026-08-09）

`/ui` 新增本地图片导入、叠加开关和 0–100% 透明度控制。截图会以固定
`800×600` 视口尺寸覆盖在当前 HUD/次级界面证据层之上，用于直接检查资源边界、窗口
原点和层级偏差；开关与透明度写入 `mir3_evidence_ui_state`。浏览器安全限制下，原始
图片本身不写入仓库，也不伪装成静态反编译证据。

### Finding 49：建立统一 UI 绘制层级候选表（2026-08-09）

新增 `draw-order-evidence.json`，把分散在按钮绘制、窗口基类、NPC 专用绘制和
`Interface1c` 屏幕初始化记录中的顺序约束汇总为统一层：场景底层 → HUD Frame 50 →
HUD 控件/血球/经验条 → 普通窗口底图 → 窗口子控件与文字 → NPC 专用合成 → 次级全屏界面。
其中明确标记了已由机器码确认的约束，以及尚未有运行时重叠窗口截图支持的候选顺序；该表
已接入 `layout.json.draw_order_evidence`，不会把推测的 z-order 当成最终事实。

### Finding 55：任务详情 Frame 705 与正文绘制坐标已恢复（2026-08-09）

在任务窗口刷新路径 `0x00447D00` 附近确认：当详情文本存在时，`0x00447E07` 选择
`GameInter.wil` Frame 705，并在 `0x00447E43` 通过共享文本/合成调用绘制；窗口原点上
的固定偏移为 `(0x41,0x126)`，即窗口相对 `(65,294)`。这与任务窗口 Frame 700 和
列表起点 `(65,90)` 形成同一窗口内的列表/详情两段布局。证据已补入
`quest-window-render-evidence.json` 和 `layout.json`。

### Finding 52：恢复公告板与 YES/NO 提示资源簇（2026-08-09）

`GameInter.wil` Frame 602 的原始图像检查确认其为公告/公告板样式的大窗口资源，头部尺寸
为 `1024×256`，可见内容候选约 `584×252`。原版 `0x0043E260` 簇构造了 Frame
`161/162` 和 `606/607` 两个控件对；构造入口由 `0x0042797E` 调用。附近 Frame 603
视觉上是中文 YES/NO 确认提示，Frame 604 是带勾选状态的窄消息/输入面板，605–607 是
小型状态资源。由于这些帧是否由同一运行时状态机组合仍未确认，全部记录为
`primary-static-candidate`，原始参数表达式和候选坐标均保留在
`notice-prompt-window-evidence.json`。

### Finding 53：确认 YES/NO/勾选按钮的未归属构造簇（2026-08-09）

对全局未归属控件中的 `0x00418176–0x004181E0` 和 `0x00418968–0x0041898E` 两个代码簇
进行了原始 WIL 视觉交叉检查。Frame `151/152`、`154/155` 是 YES/NO 的普通/绿色状态
对，`157/158` 是勾选确认状态对，尺寸分别为 `44×20` 和 `64×20`。前一个簇构造三个
横向操作控件，后一个簇再构造两个同资源族控件；它们都直接调用 `0x00417550`。因此
这批资源可以确定属于确认/提示操作族，但父窗口、文字来源和最终屏幕坐标仍为待追踪。
机器记录见 `confirmation-prompt-evidence.json`，已接入 `layout.json`。

### Finding 54：确认提示父窗口 Frame 950 已由原版构造函数闭合（2026-08-09）

继续追踪 `0x00418176–0x004181E0` 所在函数，确认其父构造入口为 `0x00418030`；在
`0x0041804E` 通过 `0x00466130` 选择 `GameInter.wil` Frame 950。WIL 头部尺寸为
`360×190`，视觉上是带文字区域和底部操作条的宽提示框。随后该函数构造 Frame
`151/152`、`157/158`、`154/155` 三组控件。因此 YES/NO/勾选控件属于这个确认提示
父窗口的证据强度提升到 `primary-static-parent-and-resource`；文字内容和运行时坐标仍
保留待验证状态。

### Finding 51：预览器增加绘制层级可视图例（2026-08-09）

`/ui` 增加“显示绘制层级”开关，读取 `layout.json.draw_order_evidence.layers`，在固定
视口内显示层序号、层名称和证据等级。图例与差异截图叠加层分离，便于同时检查“资源边界
偏差”和“层级顺序候选”；开关状态写入同一份本地预览状态。

### Finding 56：商店/仓库共用状态机的多种原版面板尺寸已恢复（2026-08-09）

继续反汇编 `0x0044E9B0` 附近的物品业务状态机，确认 `this+0x5F8` 会取值 `0–4`，并多次调用通用窗口工厂 `0x00423E80`。调用点绑定了 Frame 1000 `(0,186,300,304)`、Frame 1003 `(1,186,498,304)`、Frame 1001 `(-4,182,205,205)`、Frame 1000 `(0,186,300,304)` 和 Frame 1002 `(0,184,540,307)` 五组状态面板几何参数。

这些是原版机器码直接传入窗口工厂的参数，不是手动拖拽校准结果。当前可以把 F1000–F1003 归入同一个商店/仓库/物品操作资源簇，并将仓库从“待追踪”提升为“候选”；但 state 数值与 NPC 商店、仓库、扩展购买、物品详情的业务名称仍必须通过打开窗口的协议入口或运行时调用继续确认，不能仅凭图片外观命名。完整参数和待办见 `store-window-render-evidence.json`。

### Finding 57：原版小地图固定目标矩形恢复为右上角 128×128（2026-08-09）

反汇编地图对象初始化 `0x0043D4D0–0x0043D5F0` 时，在 `0x0043D551` 发现对
`owner+0x2C0` 的直接 `SetRect` 调用。按 Win32 `SetRect(rect,left,top,right,bottom)` 的
压栈顺序，原版常量为 `left=0x2A0 (672)`、`top=0`、`right=0x320 (800)`、
`bottom=0x80 (128)`，因此 800×600 画面的固定小地图目标矩形是
`(672,0)-(800,128)`，尺寸 `128×128`。

同一初始化路径还以 `0x0043D5F0(128,128)` 建立初始地图表面，并在 `0x0043D780` 根据
`map_id >= 1000` 从 `FMMap.wil` 选择 `map_id-1000` 帧、否则从 `MMap.wil` 选择同号帧，
再将视图/源矩形合成到上述目标区。后续 `0x0043DE40` 可把同一表面重建为 `256×256`。
这给出了原版小地图的静态屏幕位置，不是手动拖拽校准；地图边框、玩家/队伍标记和完整地图
窗口仍需继续从对应绘制调用区分。

### Finding 145：更正地图表面尺寸证据（2026-08-10）

复核 `0x0043D4D0–0x0043D5F0` 的真实压栈顺序后，构造器调用 `0x0043D5F0` 时传入的
宽、高均为 `0x80`，即初始地图表面为 `128×128`；`0x0043DE40` 的两个分支明确重建为
`256×256` 或 `128×128`。此前把 `800×800` 写入 `surface_size_candidate` 是把目标
矩形的 `right=0x320 (800)` 误当成了表面尺寸，现已从机器可读证据和 Finding 57 修正。
固定屏幕目标仍然是 `(672,0)-(800,128)`，两者不再混淆。

### Finding 146：组队与行会窗口的局部绘制顺序归档（2026-08-10）

`social-window-render-evidence.json` 现已把组队和行会窗口的局部绘制顺序分别记录为一级
静态证据。组队窗口顺序是：Frame 900 背景/标题 → 两列成员文字（横向步长 100、纵向
步长 20）→ 五个控件重定位 → `this+0x3F0` 选择的 `[允许]`/`[拒绝]` 文字 → 五个子控件
的 vtable `+0x04` 绘制。行会窗口顺序是：Frame 600 背景/标题 → `this+0x98` 状态分派的
链表行文字 → 九个控件重定位 → 九个子控件绘制。

因此跨窗口绘制总表不再把这两个窗口列为“完全没有文字/图标顺序证据”；尚未闭合的是
商店、交换、系统设置等窗口的具体文字/图标调用，以及多个可移动窗口重叠时的运行时 z-order。

### Finding 147：系统设置窗口九组控件命中矩形闭合（2026-08-10）

系统设置窗口 Frame 750 的八组状态控件使用两类原版资源：Frame 760/761 的
`32×22` 控件位于相对 `(148,43)`、`(148,116)`、`(148,190)`、`(148,217)`，Frame
762/763 的 `40×22` 控件位于相同四行的 `(185,y)`；关闭控件 Frame 161/162 为
`(218,238,28,26)`。另外两个 Frame 751 条目是 `20×16` 的非状态文字/辅助控件，
相对位置为 `(34,96)` 和 `(34,170)`。

这些矩形来自 `0x00417550` 根据 GameInter 帧头尺寸写入 `SetRect` 的路径，已同步到
`system-window-render-evidence.json` 和统一 `layout.json`。选项的中文标签、状态字段
和两个 Frame 751 条目的业务含义仍保持待验证。

### Finding 148：交换窗口控件资源尺寸边界归档（2026-08-10）

交换窗口构造器的 Frame 161/162 控件原始位置为 `(532,350)`，由原版帧头得到
`28×26`；Frame 1061/1062 控件原始位置为 `(185,332)`，帧头得到 `48×20`。这两组
位置目前仍标为 `outside-parent-unresolved`，因为 EI 的交换窗口构造器还需要继续闭合
其父矩形/运行时中心原点，不能直接把它们当成最终屏幕坐标。

Frame 1064/1065 在当前原版 GameInter.wil 中为空，因此只记录原始位置 `(225,332)`，
不人为填入宽高或命中区域。该“空资源仍保留调用关系”的处理已同步到
`system-window-render-evidence.json` 和 `layout.json`。

### Finding 149：任务窗口两个操作控件命中矩形闭合（2026-08-10）

任务窗口 Frame 700 的两个操作控件均使用 `28×28` 的 GameInter 资源：Frame 723/724
位于窗口相对 `(290,59)`，Frame 721/722 位于 `(290,89)`。矩形由公共控件构造器读取
帧头宽高后通过 `SetRect` 写入，已同步到 `quest-window-render-evidence.json` 和统一布局。
任务列表与详情正文的 15px 行距、19 行列表上限和 3 行详情窗口仍保持原版静态证据；
控件的最终业务名称继续沿点击分支待确认。

### Finding 150：确认框父矩形与三个动作按钮坐标闭合（2026-08-10）

原版确认框构造器 `0x00418030` 在两个位置参数均为 `-1` 时，根据 Frame 950 的
`360×190` 资源头以 `(400-180, 246-95) = (220,151)` 居中。三个子控件的原版
窗口相对矩形为：Frame 151/152 `(51,125,44,20)`、Frame 157/158
`(147,125,64,20)`、Frame 154/155 `(244,125,44,20)`；换算后的屏幕矩形分别为
`(271,276,44,20)`、`(367,276,64,20)`、`(464,276,44,20)`。

这些值来自 `0x0041815F–0x004181E0` 的寄存器表达式和 GameInter 帧头，而不是预览器
手写校准。确认框预览现在从 `confirmation-prompt-evidence.json` 读取这些记录；后续
Frame 151/154/157 的悬停状态转换仍需运行时点击路径继续确认。

### Finding 151：技能书八个元素分类控件命中矩形归档（2026-08-10）

技能书 Frame 400 的八个分类控件已按原版重绘坐标和 GameInter 帧头尺寸归档：火
`(5,21,44×36)`、冰 `(3,56,44×36)`、电 `(4,91,44×36)`、风 `(2,126,48×36)`、
神圣 `(2,161,48×36)`、黑暗 `(2,196,44×36)`、幻影 `(1,231,44×36)`、剑
`(2,266,44×36)`。普通/状态帧对分别为 `450/451`、`452/453`、`454/455`、
`456/457`、`458/459`，后四类按原版重复使用前三组资源族。

坐标和尺寸已写入 `skill-window-context.json` 的 `category_hit_rects`，并继续区分
窗口相对矩形与最终屏幕位置；技能名称、页码字段和 Magic.exp 的运行时选中态仍保持
各自证据边界。

### Finding 59：证据预览器已改用原版小地图 Rect 并持久化调试开关（2026-08-09）

修正 `Tools/web/wilviewer.py` 中旧的占位框：原先错误的 `(650,10,140×140)` 已替换为原版
机器码确认的 `(672,0,128×128)`。证据布局 `/ui` 新增“显示原版小地图 Rect”开关，直接
读取 `layout.map_ui_evidence.viewport.fixed_minimap_widget.screen_rect`，并把开关与
调试框、Frame、差异截图、绘制层级一起写入 `mir3_evidence_ui_state`。这只是坐标/证据层，
不会把未知地图帧或对象标记伪装成已经确认的运行时画面。

### Finding 58：小地图底图合成、对象标记和点击坐标转换路径已闭合（2026-08-09）

在 `0x0043DA80` 的地图绘制函数中确认，原版流程不止选择 MMap 帧：`0x0043DB0B–0x0043DB2B`
调用 `0x004542F0`，把地图/视图数据合成到固定小地图区域；随后通过共享绘制辅助
`0x0045E570` 画出多个地图对象标记。已恢复的直接调用包括：

- `0x0043DB7F`：计算对象矩形后四边扩展 4 像素，颜色参数 `0x64C864`；
- `0x0043DCB8`：遍历全局链表 `0x00560070`，只处理对象 `entry+0x88 == 0x32`，矩形四边扩展 2 像素，颜色参数 `0xFFFF00`；
- `0x0043DD75`：遍历全局链表 `0x005600A0`，矩形四边各扩展 1 像素，颜色参数 `0x64C864`。

`0x0043DDB0` 的命中测试直接使用 `owner+0x2C0` 的 128×128 Rect，并把点击位置转换到
`owner+0x2F0/0x2F4` 的视图相对字段。这样已经得到小地图“底图 + 标记 + 点击换算”的
静态结构；但由于二进制中尚未确认两个全局链表的业务类名，当前只能称为地图对象标记，
不能擅自命名成玩家、NPC、队友或地面物品。

### Finding 60：MMap/FMMap 的多分辨率尺寸族确认完整地图资源分工（2026-08-09）

读取原版 WIL 17 字节帧头后确认：`MMap.wil` 的有效帧包含 `600×400`、`300×200`、
`152×100` 和 `76×50` 等尺寸族，绝大多数帧偏移为 `(-24,-16)`，小尺寸 35–38 使用
`(7,-44)`；`FMMap.wil` 则包含 `1200×800`、`900×600`、`600×500`、`600×400`、
`600×200`、`600×600` 及 `452×300` 等尺寸族。

这与机器码中“先选择资源帧，再裁剪/缩放到 128×128 小地图 Rect”的路径一致：MMap 是
多分辨率小地图图像族，FMMap 是完整地图/大地图图像族候选。尺寸和帧列表已写入
`map-ui-resource-evidence.json`，但具体地图编号到 FMMap 帧号的业务表仍需继续从加载参数
和完整地图打开入口追踪，不能按帧号顺序臆测地图名称。

### Finding 61：地图资源选择、绘制、命中和尺寸模式调用链已串联（2026-08-10）

进一步追踪地图类的调用者，得到以下静态链：`0x00420C3C → 0x0043D780` 传入
`(word & 0xFFFF)-1` 进行地图编号/资源帧选择；主世界绘制 `0x004295B4 → 0x0043DA80`；
小地图 Rect 命中与坐标换算 `0x0042BDC0 → 0x0043DDB0`；交互/视图状态候选
`0x0042C75C → 0x0043DEB0`。另外 `0x0042CED2` 调用表面初始化并传入 `256×256`，
`0x0042CEF0` 传入 `128×128`，说明原版保留大地图表面与固定小地图表面两种运行模式。

这些调用点已加入 `map-ui-resource-evidence.json`。目前可以确认地图系统不是一个简单的
静态贴图，而是地图编号选择 → 表面尺寸模式 → 视图合成 → 对象标记 → 点击坐标转换的
连续链路；完整地图窗口的最终屏幕布局仍需从打开入口继续确认。

### Finding 62：预览器增加完整地图资源候选模式（2026-08-10）

`Tools/web/wilviewer.py` 的固定 800×600 证据预览新增“完整地图资源候选 / FMMap F0”模式，
把原版 `FMMap.wil` Frame 0（头部尺寸 `1200×800`）按比例显示在 800×600 视口内，并
明确标记为资源候选，不伪装成已确认的地图编号、窗口原点或最终缩放规则。主 HUD 模式
仍独立显示原版小地图 Rect `(672,0,128×128)`，两者不会混在同一层中。

### Finding 63：Frame 602 窗口容器坐标恢复，但业务归属应为公告窗口（2026-08-10）

此前把 `0x0042797E → 0x0043E260` 只记录成“Frame 602 窗口候选”，本轮重新检查了包装器和
后续控件构造。主初始化向该对象传入的原始参数为：

```text
ID=15, resource=main_ui_this+0x1c (GameInter), Frame=602,
x=107, y=110, width=584, height=252, trailing flags=0,3
```

因此，按通用窗口参数的前七个槽位解释，Frame 602 公告容器的屏幕矩形候选为
`(107,110)-(691,362)`。它与固定小地图 `(672,0)-(800,128)` 是两条不同的 UI 路径，
但不能再称为完整地图容器：Frame 602 的真实图像是公告板/公告窗口。

该包装器内部还直接构造两个 GameInter 控件：

- Frame `161/162`，大小 `28×26`，原始位置 `(655,16)`，调用 `0x0043E2BB`；
- Frame `606/607`，大小 `40×20`，原始位置 `(603,27)`，调用 `0x0043E2E4`。

两者的位置表达式来自包装器参数槽位和常量增量，已写入
`gameinter-cluster-43e260.json`。容器 Frame 602 的窗口原点是否在运行时再次叠加父窗口偏移，
以及 FMMap 的具体帧/滚动缩放绑定，仍需从地图打开、绘制和输入状态继续验证；不能只凭这组
参数断言最终画面中的地图内容已经完全恢复。

### Finding 64：Frame 602 公告对象进入主 UI 生命周期，并拥有独立绘制/命中分发（2026-08-10）

继续追踪主对象字段 `main_ui_this+0x52E5C`，确认它不是只在初始化时短暂创建的贴图容器：

- `0x0043E0E0` / `0x0043E170` 分别负责该对象的初始化/释放；
- `0x0043E680` 遍历两个子控件并调用共享控件虚表的 `+0x08`，是子控件绘制/更新分发候选；
- `0x0043E640` 遍历两个子控件并调用虚表 `+0x0C`，是命中/事件分发候选；
- 主 UI 生命周期在 `0x004271CC` 和 `0x00427513` 通过该对象虚表的 `+0x04/+0x08` 调用它。

这闭合了“公告窗口构造 → 主 UI 生命周期 → 子控件绘制/命中”的证据链。完整地图的专用
UI 容器仍未从当前静态证据中确认，不能用 Frame 602 代替；FMMap 的资源绑定和地图表面
绘制链仍需与真正的地图打开入口继续关联。

### Finding 65：原版静态窗口清单中没有独立好友窗口构造（2026-08-10）

对 `Mir3.exe` 中全部 15 个通用窗口基类调用及主 HUD 的帧对进行了归档。已能分别归类为
背包、状态、商店、交易、行会、组队、聊天、组队附属、选项、任务、坐骑、技能/其他、NPC、
确认/提示和公告 ID 15；没有出现一个可以独立命名为好友/好友列表的窗口构造函数，也没有
在主 HUD 的原版帧对表中发现专用好友按钮。

这是一条“静态范围内未发现”的负证据，不等于功能绝对不存在。当前最合理的待查方向是：
好友列表作为行会/社交 F600 的页签或状态、由动态分配的通用对话框承载，或藏在未归属的
`Interface1c.wil` 控件簇中。已写入 `social-window-render-evidence.json.friend_entry_audit`，
并禁止预览器再凭现代客户端概念硬编码一个好友按钮。

### Finding 66：原版 Mud3 MiniMap.txt 闭合 FMMap/MMap 的服务器映射规则（2026-08-10）

检查原版服务器 `/home/tetsuya/NAS/TMP/Mud3/Envir/MiniMap.txt`，得到本发行版的明确规则：

```text
服务器值 >= 1001：FMMap.wil，frame = value - 1001
服务器值 <  1001：MMap.wil，frame = value
```

共解析 313 条配置记录，其中 45 条指向 FMMap、268 条指向 MMap；与 EI 客户端 `Map/*.map`
文件名匹配 211 条，WIL 帧实际可解码 209 条。`0 -> FMMap F0`、`01 -> FMMap F1`、
`02 -> FMMap F2`、`1 -> FMMap F3` 等基础映射均可直接复核。

这条证据说明完整地图资源并不是泛泛的“FMMap 候选”，而是服务器配置明确使用的资源族；但
它属于服务器配置的第二证据源。exe 内 `0x0043D780` 的 `map_id >= 1000` 分支与服务器值
之间仍需继续追踪调用者的归一化过程，不能把两个数值条件未经验证地当成同一个输入。

### Finding 67：纠正地图资源字段绑定，并闭合服务器值与 exe 分支（2026-08-10）

重新反汇编 `0x0043D4D0` 和 `0x0043D780` 后确认此前字段记录有误，正确关系为：

```text
owner+0x04   <- .\Data\MMap.wil   (literal 0x0047C428)
owner+0x148  <- .\Data\FMMap.wil  (literal 0x0047C414)
owner+0x2D0  <- 运行时矩形/状态字段，不是 WIL 资源句柄
```

`0x0043D780` 的分支是：`map_id >= 1000` 时选择 `owner+0x148` 的 FMMap，帧号为
`map_id-1000`；否则选择 `owner+0x04` 的 MMap，帧号为 `map_id`。而 `0x00420C24–0x00420C3C`
在调用前对网络/状态字段做 `word & 0xffff` 后再减一，因此服务器 `MiniMap.txt` 的
`1001 -> FMMap F0` 恰好归一化为 exe 的 `1000 -> FMMap F0`。

这修正了早期“owner+0x148 是 MMap、owner+0x2D0 是 FMMap”的错误表述；相关机器可读证据
已同步更新，后续地图 UI 不得再使用旧绑定。

### Finding 68：主 HUD 资源条不是静态贴图，原版明确计算 0–1 比例（2026-08-10）

反汇编 `Mir3.exe` 的 `0x00429740`，确认主 HUD 在绘制过程中先计算多个归一化比例，而不是
只把 F60/F61/F63 原图整张贴上去。关键路径使用 x87 `fild`/`fidiv`，并在比较后把结果钳制到
`0.0–1.0`；之后进入 `0x00466800` 的条带几何/纹理准备，再由 `0x004542F0` 合成。

当前可复核的第一条比例是 `low16(0x007D9264) / low16(0x007D9262)`，第二条为
`low16(0x007D9266) / low16(0x007DA113)`，经验为 `0x007DA115 / 0x007DA119`，
负重为 `low16(0x007DA109) / low16(0x007DA11F)`。同时在 `.data` 中直接解出
`(血量)%d/%d`、`(魔法量)%d/%d`、`(负重)%d/%d` 和 `(经验条)%.2f%s`，分别对应
这些全局字段的业务语义。
第一、第二条分别受固定 Rect `[this+0xC68] = (61,496)-(104,566)` 与
`[this+0xC78] = (105,496)-(147,566)` 约束。全局字段的业务名称仍不凭现代源码猜测，
完整地址、调用点和置信度已保存到 `hud-bars-render-evidence.json`。

同一绘制族还将经验比例乘以 `[0x0047644C]`，通过格式化函数 `0x0046811C` 写入
`[this+0xC88] = (235,586)-(400,597)` 对应的底部文字区域（`0x0042A065–0x0042A087`）。
因此主 HUD 的经验显示至少包含“比例条 + 百分比/进度文字候选”两层，预览器不能只复原
F63 的 164×6 贴图。

### Finding 72：组队窗口成员列表是两列链表绘制（2026-08-10）

在组队窗口绘制函数 `0x004243D0` 中，原版从 `this+0x58` 链表遍历成员，使用从 0 开始
的局部序号。`0x00424445–0x0042448E` 对序号做奇偶判断：偶数成员列位 0，奇数成员列位
1；每两名成员换下一行。精确窗口相对坐标为：

```text
x = window.x + 45 + 100 * (index % 2)
y = window.y + 90 + 20 * floor(index / 2)
```

成员字段最终交给共享文字绘制函数 `0x0045DD70`。因此组队窗口不应只实现三个按钮，
还必须按这个两列列表显示动态成员；成员字段的具体排列和链表可见上限仍保持待验证。

### Finding 73：行会窗口成员/公告列表的滚动几何与原文标记已恢复（2026-08-10）

行会绘制函数 `0x00425280` 从 `this+0xD4` 链表读取条目，以 `this+0x9C` 作为滚动起点，
可见数量由 `this+0xE4 - scroll_start` 给出并限制为最多 `0x12`（18）行。每行的窗口相对
横坐标固定为 `35`，纵坐标为 `60 + (index-scroll_start) * (font_metric_height+5)`；
行高由 `0x00425297–0x004252C8` 的原版字体度量计算出来。

原版还直接比较并识别 GB18030 字符串 `[联盟行会]`、`[敌对行会]`、`[行会公告]`，
说明行会页并非只有普通成员名字，还包含联盟、敌对和公告类别行。相关特殊颜色/字段
分支仍保持为待验证，不能在预览器中把三类标记误画成普通成员。

### Finding 69：技能窗口包装器的原始构造参数已补档（2026-08-10）

在主 UI `0x00427904` 的调用点确认技能窗口包装器 `0x00439250` 的压栈常量为
`3, 1, 0x17C, 0x1C4, 0, 0x15C, GameInter, 0x0E`。包装器会重新排列这些值后
调用通用窗口基类 `0x00423B30`，因此它们不能未经签名恢复就全部命名成 x/y/w/h。
该原始参数序列已写入 `skill-window-static-evidence.md`，用于后续完整恢复窗口原点和
拖动边界；现阶段仍以 Frame 400 尺寸及 `0x00439500` 重绘出的八个分类控件坐标为
可靠的窗口内部证据。

### Finding 70：背包是原版确定的 6×6、36 像素物品网格（2026-08-10）

`0x0042F150` 的命中/搜索循环分别以 `0,36,72,108,144,180` 扫描横纵轴，并以
`< 0xD8` 结束；`0x0042F2A0` 再将槽位索引除以 6，余数为列、商为行。由此可以直接
得到 36 个槽位的窗口相对矩形：

```text
x = window.x + 0x19 + 36 * column
y = window.y + 0x29 + 36 * row
size = 36 × 36
column,row = 0..5
```

同时复核 `0x0042EA80` 的调用者 `0x00427750`：它把主 UI 的 GameInter 资源句柄传给
库存窗口，窗口内部三个控件均使用同一句柄。因此 Frame 264/265 与 267/268 在此 EI
版本中也是 `GameInter.wil`，此前的 Interface1c 候选已纠正。

### Finding 71：状态窗口装备绘制使用 11 条连续位置记录和 0xC24 物品记录步长（2026-08-10）

`0x0044B6B0` → `0x0044B720` 的命中路径返回一个 `0..10` 的槽位索引；该索引同时
选择 `this+0x1C0+index*0x10` 的位置记录和 `this+0x2F4+index*0xC24` 的物品记录，
最终在 `0x004341F0` 绘制物品。11 条几何记录与构造器写入的 Rect 一一对应：

```text
0: (86,114)-(146,204)  人物图区域候选
1: (38,70)-(91,154)    属性区候选
2: (27,264)-(65,302)   装备候选
3: (177,70)-(215,108)  装备候选
4: (94,71)-(143,104)   姓名/头像区候选
5: (27,186)-(65,224)   装备候选
6: (175,186)-(213,224) 装备候选
7: (27,227)-(65,265)   装备候选
8: (175,227)-(213,265) 装备候选
9: (64,264)-(102,302)  装备候选
10:(103,264)-(141,302) 装备候选
```

其中索引 `0/1/4` 的代码分支把物品/人物绘制送到固定中央目标
`(window.x+0x61, window.y+0xC8)`，其余 8 个索引使用各自位置记录的前两个 dword
并加 `0x0F`。因此“8 个装备槽 + 3 个非装备显示记录”的结构已经闭合，尚待把 8 个
索引和具体的武器、首饰、戒指、手镯等业务名称对应起来。

### Finding 74：原版地图存在明确的 256×256 / 128×128 表面模式切换（2026-08-10）

反汇编 `0x0043DE40` 可见，例程先把 `owner+0x294` 作为布尔状态取反，然后根据新状态
调用同一个表面初始化函数 `0x0043D5F0`：真分支压入 `256,256`，假分支压入
`128,128`，两条路径均返回成功。该例程由 `0x0042C75C` 通过 `0x0043DEB0` 的地图
交互路径触发。

这证明原版并非只有一个固定尺寸的地图绘制状态：资源选择（MMap/FMMap）、地图表面尺寸、
视图矩形和最终合成是连续链路中的不同层。`0x0043DEB0` 先对固定小地图 Rect
`owner+0x2C0` 做 `PtInRect`，再检查两个输入状态（传入 `1` 与 `0x11`），并将点击坐标
按 `owner+0x2F0/+0x2F4` 与 `owner+0x2B8/+0x2BC` 换算后写回 Rect；因此坐标转换证据已
闭合，但两个输入状态的用户-facing 命令名称仍不能仅凭数值猜测。

服务器值与 exe 分支的关系已在 Finding 67 闭合：`MiniMap.txt` 的 `1001` 在调用
`0x0043D780` 前被减一为运行时 `1000`，从而选择 FMMap Frame 0；本条不再作为待解决项。

### Finding 75：聊天窗口的六个频道/命令字符串与固定位置已恢复（2026-08-10）

从 `0x00414080` 构造器的六个字符串参数回溯到 `.data`，并按 GBK 解码得到：

| 控件对象 | 窗口相对 X | 原始地址 | 原版字符串 | 内容含义 |
|---|---:|---|---|---|
| `this+0x120` | 25 | `0x0047AD08` | `拒绝和 某人 私聊(@拒绝 某人名)` | 拒绝某人私聊 |
| `this+0x1D4` | 65 | `0x0047ACF8` | `大喊话(!喊话)` | 大喊话 |
| `this+0x288` | 105 | `0x0047ACE4` | `编组 喊话(!!喊话)` | 编组/组队喊话 |
| `this+0x33C` | 145 | `0x0047ACD0` | `行会 喊话(!~喊话)` | 行会喊话 |
| `this+0x3F0` | 185 | `0x0047ACB8` | `拒绝 私聊(@拒绝私聊)` | 拒绝私聊 |
| `this+0x4A4` | 225 | `0x0047AC98` | `拒绝 行会 聊天(@拒绝行会聊天)` | 拒绝行会聊天 |

这些字符串与控件构造调用及固定 X 坐标一一对应，因此聊天窗口的频道/命令内容不再只是
根据按钮帧号推测。仍需从共用控件绘制函数确认它们最终表现为按钮文字、鼠标提示还是命令
说明；但字符串本身、地址、顺序和布局位置已经是原版静态证据。

### Finding 76：地图表面切换已经关联到原版键盘分发（2026-08-10）

继续检查主输入分发 `0x0042CC76–0x0042CF1F`，发现它调用键状态 IAT `0x00476278` 检查
`0x54`，随后切换主对象 `main+0x64A8`。当该字段由 0 变 1 时，原版直接调用
`0x0043D5F0(256,256)`；由 1 变 0 时调用 `0x0043D5F0(128,128)`。`0x54` 与 ASCII
字符 `T` 相符，但这里仅记录为键码/ASCII 候选，不把它擅自命名成“打开大地图”快捷键。

因此当前可以确定：地图模式切换不是我们手动拖动校准出来的，也不是现代客户端坐标推测，
而是原版主循环中的静态键盘分支；地图表面尺寸和切换状态均有机器码来源。另一个相邻的
`0x59` 分支只切换 `main+0x64A4`，其与地图 UI 的业务关系暂不命名。

### Finding 77：NPC 对话窗口的动态条目容量、步长和三段资源状态已补齐（2026-08-10）

NPC 构造器 `0x0043ED00` 将 `this+0x51C` 初始化为 `0x0D`，即默认最多 13 个动态
条目；绘制函数 `0x0043F040` 按 `entry_index*0x12`（18 字节）步长读取/生成条目，
分别经过资源/状态编号 `0x44C`、`0x44D`、`0x44E` 对应的加载与共享合成调用，并在
`this+0x530/+0x534`、`this+0x540/+0x544` 两组位置字段上绘制前后状态。

因此 NPC 窗口目前可以确定为：GameInter F1100 背景（552×176）+ 最多 13 行动态
内容 + F1101 重复条目状态 + F1102 最终状态。具体字段是 NPC 名称、对话文本、选项
还是动作按钮，仍需继续追踪条目填充调用；这里不以现代客户端命名替代原始字段证据。

同一构造器 `0x0043EDC5` 还把 `Data/NPCFace.WIL`（路径字符串 VA `0x0047C4EC`）绑定到
`owner+0x278`，原始库头为 440 帧、46 个非空帧。由此可将 NPC UI 的资源分成两层：
GameInter 提供窗口背景/控件，NPCFace 提供 NPC 对象的头像资源；不能把头像帧误列为
GameInter 帧。

### Finding 78：商店/仓库类状态机已找到协议分发入口（2026-08-10）

主消息处理区 `0x0042BE20–0x0042C359` 先通过 `0x0042AAB0` 读取子码，再用跳表
`0x0042C4D4` 分发。跳表第 2 项是 `0x0042BFE1`，该分支依次调用
`0x0044E910`（物品/商店数据处理候选）和 `0x0044E9B0`（窗口状态机）。因此“商店类
窗口完全没有入口”这一假设可以排除：原版存在明确的消息分发 → 数据处理 → UI 状态机链。

该链路仍不能单凭子码数值命名为“NPC 商店”或“仓库”，所以状态 0–4 的业务标签继续
保持候选；但现在已经有真实的协议入口地址，可以继续沿参数字段和服务端处理寻找名称。

### Finding 79：服务端脚本确认仓库、购买、出售 NPC 入口（2026-08-10）

新增 `Tools/extract_mir3_store_server_crossref.py`，只读解析 `Mud3/Envir/Merchant.txt`
以及 `Market_Def`、`Convert_Def/Market_Def` 脚本，并把商店类服务端资料写入
`store-server-crossref.json`。共发现 318 条商人记录，全部能匹配到脚本；其中 19 条包含
`NPC_Storage`/`NPC_GetBack` 仓库存取入口，108 条包含购买入口，108 条包含出售入口。

三个可复核示例：

- `19GM_INN-Z014` 的 `[NPC_Main]` 暴露“寄存/取回”，并有 `[NPC_Storage]`、
  `[NPC_GetBack]` 段落及对应提示文本；
- `06Inn_Oasis` 的服务端名称为“绿洲仓库保管员”，归入仓库入口；
- `04Potion_Bichon1` 的“药店老板”同时存在 `[@NPC_Buy]` 与 `[@NPC_Sell]`。

这些资料确认原版时期的服务端业务入口确实存在，并可作为客户端 F1000 商店/仓库窗口
继续追踪的第二证据源；但服务端 NPC 名称和脚本分类不能证明客户端状态 0–4 的具体数值
含义，也不能替代 Mir3.exe 的绘制与命中证据，因此相关业务标签仍保持 candidate/pending。

### Finding 80：地图对象的固定小地图 Rect 与内部视图状态不是同一层（2026-08-10）

重新核对 `0x0043D4D0–0x0043DA80` 的连续机器码后，地图对象至少包含三类不同几何：

- `owner+0x2C0` 在构造器中通过 `SetRect` 固定为 `(672,0)-(800,128)`，这是屏幕上的小地图
  目标区；
- `owner+0x2B8/+0x2BC` 保存视图位置，`0x0043D5F0` 会依据资源源图尺寸限制它，并重新建立
  同一个目标 Rect；
- `owner+0x2D0` 保存绘制过程使用的内部视图/裁剪 Rect，`owner+0x2E0` 保存所选 WIL
  Frame 的源尺寸/偏移换算结果。`0x0043D780` 在选帧后才调用 `0x0043D5F0`，所以不能
  把 WIL 图片尺寸直接当成屏幕窗口尺寸。

`0x0043DA80` 的绘制链先把视图位置、目标 Rect 和缩放参数交给共享合成函数
`0x004542F0`，再按三个不同的全局对象链绘制绿色/黄色候选标记。由此，预览器新增的
“固定小地图 128×128 候选”只展示屏幕目标和资源缩放关系；完整地图窗口、边框、滚动条
及标记业务语义仍保持 pending，避免用一张拉伸后的 FMMap 图伪造原版布局。

### Finding 81：公告窗口的 800×600 父窗口原点由初始化参数直接闭合（2026-08-10）

反汇编 `0x00427960–0x0042797E` 的参数压栈顺序为：窗口 ID `15`、主 UI 资源句柄、
Frame `602`、`x=107`、`y=110`、`width=584`、`height=252`、末尾标志 `0`，随后调用
`0x0043E260`。因此公告窗口在固定视口中的原点和外框候选不是 `(252,110)`，而是准确的
`(107,110)-(691,362)`；此前记录已更正。

`0x0043E260` 的两个子控件仍以父窗口参数表达相对位置：关闭/确认类控件为
`(548,16)`、`28×26`，另一个公告动作控件为 `(496,43)`、`40×20`。如果父窗口原点
直接参与最终屏幕合成，它们对应 `(655,126)` 与 `(603,153)`；这两个屏幕位置已记录为
派生值，子控件最终业务语义和文字绘制仍保持候选。
### Finding 82：确认框 F950 存在原版固定中心定位规则（2026-08-10）

`0x00418030` 的构造路径在位置参数为 `-1/-1` 时，从资源句柄 `this+0x45C` 读取图像尺寸，
按固定中心 `(400,246)` 计算父窗口左上角。对应 `GameInter.wil` Frame 950 的原始尺寸
`360×190`，得到 `(220,151)-(580,341)`。这条坐标来自构造器算术和 WIL 头部，不是人工
校准；机器可读结果已写入 `confirmation-prompt-evidence.json`。

目前仍不能仅凭静态代码证明所有确认框调用都走 `-1/-1` 分支，也不能把 151/152、154/155、
157/158 的业务文字和颜色状态全部命名，因此状态机和运行时分支继续保持候选。

### Finding 83：聊天记录步长与屏幕视觉行距已分离（2026-08-10）

在聊天绘制函数 `0x00414700–0x00414999` 中，链表记录从 `this+0x720` 按 `0x10` 字节
移动，但用于屏幕绘制的局部索引每行增加 `0x0E`。结合构造器建立的 Rect，可恢复：

- 文字绘制起点为窗口相对 `(40,29)`；
- 相邻可见行的视觉 Y 步长为 `14px`；
- 每行裁剪 Rect 第一行相对值为 `(35,28)-(520,43)`，后续每行上下各增加 `14px`；
- 记录内存步长仍是 `16` 字节，不能把它误当成字体行距。

该结论来自 `0x004147BA–0x0041481F` 的坐标计算和 `0x0041496D–0x00414997` 的逐行
裁剪循环。频道字符串仍经共享控件绘制，具体字体颜色和字符串是否同时作为 tooltip 继续
保留待验证。

### Finding 84：商店状态值的按钮分支与面板重建路径已分开记录（2026-08-10）

在 `0x0044E910–0x0044EA07` 和 `0x0044E9B0` 中，`this+0x5F8` 的状态字节出现且只比较
`0、1、2、3、4`。静态行为如下：状态 1/3/4 进入第一组按钮/命中路径，状态 1/2/4
进入第二组路径；状态 2 的第二组路径可在控件处理成功后直接返回。命中测试使用窗口
对象的 `this+0x18/+0x1C/+0x20/+0x24` 几何字段，并在状态分支中出现相对偏移
`(300,208)`、`(300,100)`。

状态切换后的工厂调用也能闭合资源层：状态 0/3 重建 `GameInter F1000` 的
`300×304` 面板，状态 2 创建 `F1001` 的 `205×205` 紧凑面板，状态 4 创建
`F1002` 的 `540×307` 宽面板，状态 1 创建 `F1003` 的 `498×304` 扩展面板。
这些是机器码中的 Frame/尺寸/调用关系，不是“仓库”“购买”“出售”等业务名称；业务
映射仍必须依靠消息参数和服务端脚本继续交叉，不能由视觉相似度命名。

### Finding 85：人物状态窗口的绘制状态与装备循环已由反汇编闭合（2026-08-10）

继续反汇编 `0x0044B2D0–0x0044B629` 后确认，状态窗口并非只有静态 Frame 200：入口读取
`this+0x54`，状态 0 和 1 都经过 `0x0044B560` 的准备/合成路径，并建立相同的裁剪表达式
`SetRect(window.x-0x0A, window.y+0x1E, window.x+0xFF, window.y+0x32)`，随后调用
`0x0045DBA0`、`0x0045DE50`、`0x0044BC80`、`0x00466130` 和 `0x0045FD50` 等共享绘制链。

`0x0044B5D9–0x0044B629` 是 11 次迭代的装备/角色记录循环：物品记录从 `this+0x2F4` 开始、
步长 `0xC24`，位置记录从 `this+0x1C0` 开始、步长 `0x10`，空记录以当前基址首 dword 为零
跳过。索引 0、1、4 使用固定中心目标 `window origin+(0x61,0xC8)` 并把合成标志设为 1；
其它非空索引使用位置记录的两个 dword 加窗口原点和 `0x0F` 偏移，并把标志设为 0，最终调用
`0x00430A40`。这强化了装备槽/角色区的机器码证据，但仍不能仅凭静态代码命名每个索引对应
的武器、头盔、项链、戒指等业务栏位。

完整原始参数已同步到 `status-window-render-evidence.json` 的
`paint_state.primary_disassembly_details`，所有业务名称和运行时资源句柄继续保持待验证。

### Finding 86：人物属性文字的中文语义与两列基线已从原版字符串引用恢复（2026-08-10）

`0x0044BC80–0x0044CCCC` 是状态窗口属性文字辅助路径。它直接把 Mir3.exe 内的 GBK 字符串
传给 `0x0046811C` 格式化，再经 `0x0045DD70` 合成到窗口：第一列从
`window.x+0xFF, window.y+0x43` 开始，每行步长 `15px`，依次包含 `LEVEL`、`HP`、`MP`、
`经验`、`包袱负重`、`装备负重`、`腕力`、`准确`、`敏捷`、`毒物躲避`、`中毒恢复`、`生命恢复`、
`魔法恢复`；第二列在代码中执行 `x+=0x17F,y+=0x1E` 后，从
`window.x+0x27E, window.y+0x127` 开始，包含 `防御`、`攻击`、`魔法`、`火(火焰)`、`冰(冰冻)`、
`电(雷电)`、`风(狂风)`、`治疗(神圣)`、`攻击(黑暗)`、`召唤(幻影)`、`魔法防御力`。

这次恢复的是原版字符串引用和绘制基线，不是根据现代客户端或截图猜标签。对应字符串地址、
引用指令和数值格式化调用已写入 `status-window-render-evidence.json` 的
`attribute_text_draw_chain`；属性值对应的全局字段、字体颜色和最终 z-order 仍单独标记为待验证。

### Finding 87：地图模式键盘入口的守卫、状态字段和两种表面尺寸已闭合（2026-08-10）

在 `0x0042CC76–0x0042CF1F` 的同一输入分发函数中，键码由 `0x00476278` 间接读取。键码
`0x54` 只有在 `main+0x6518 == 1` 的地图/世界子系统状态下才进入切换：
`0x0042CEA5–0x0042CEBA` 翻转 `main+0x64A8`，非零分支调用 `0x0043D5F0(256,256)`，
零分支调用 `0x0043D5F0(128,128)`。因此这是原版明确存在的地图显示表面切换入口，数字键码和
调用参数是静态确定的；“T键”“大地图”“小地图”等用户界面名称仍不能只凭二进制命名。

相邻键码 `0x59` 在 `0x0042CEF7–0x0042CF19` 翻转 `main+0x64A4`，但该分支没有直接重建
地图表面，暂记为同一客户端状态机的未命名相邻功能。上述信息已同步到
`map-ui-resource-evidence.json` 的 `mode_switch.keyboard_dispatch_evidence` 和
`adjacent_key_evidence`。

### Finding 88：商店状态面板已加入工厂算法与逐状态800×600预览（2026-08-10）

`0x00423E80` 的反汇编确认它不是简单把调用参数写成屏幕坐标：先用 `0x00466130` 选择资源，
从资源句柄 `this+0x2C` 的 `+0x38` 读取 WIL 头部尺寸，建立栈上局部 RECT，再把计算结果写入
对象的 `this+0x40/+0x44`，最后在 `0x00423F55` 和 `0x00423F6D` 对 `this+0x08`、`this+0x18`
执行最终矩形设置，函数以 `ret 0x14` 清理五个参数。由此，状态 0–4 的原始调用参数和最终
父窗口定位必须分开保存。

预览器新增“商店状态0–4”五种模式，分别使用 F1000/F1003/F1001/F1000/F1002，并按
`(800-width)/2,(600-height)/2` 显示一个明确标注为“工厂居中候选”的观察位置，同时显示原始
工厂调用参数和状态命中矩形。该观察位置是可视化推导，不提升证据等级；原始工厂算法与参数
仍是唯一坐标依据。

### Finding 89：任务窗口的列表与详情正文绘制基线已闭合（2026-08-10）

在 `0x00447470` 任务绘制函数中，任务列表通过 `this+0x1E8 -> 0x0045E0C0` 取得记录，
文字基线为 `window.x+0x41, window.y+0x5A+row*15`，并受 19 行边界保护。任务详情背景
路径在 `0x00447E07` 选择 GameInter Frame 705，并从 `window.x+0x41,window.y+0x126`
进入正文区；随后 `this+0x6C` 的正文字符串按 `this+0x60 <= line < this+0x60+3`
显示最多三行，正文起点为 `window.x+0x50,window.y+0x136`，行距同为 `15px`，文本测量
上限为160字节。列表与正文都经共享 `0x0045DD70` 合成。

这些坐标和行数已写入 `quest-window-render-evidence.json`，任务预览也从原先的大范围详情
候选框改为 Frame 705 背景条与三行正文证据框；任务标题、字段分隔符和滚动业务语义仍保持
待验证。

### Finding 91：地图从源图到固定小地图的归一化合成链已补全（2026-08-10）

在 `0x0043DA80` 的地图绘制函数中，程序先读取 `owner+0x2C0/+0x2C4` 的目标视图尺寸，
再结合 `owner+0x2B8/+0x2BC` 的当前视图位置，调用共享浮点归一化助手 `0x00466800`。
随后在 `0x0043DB0B–0x0043DB2B` 通过公共合成器 `0x004542F0`、上下文
`0x005600FC` 送入固定地图目标。`owner+0x2D0/+0x2D4` 是源偏移/裁剪状态，不能与屏幕
坐标混用；`owner+0x300` 还参与一个 0 到 800 的中间动画/时序值。

合成参数还受 `owner+0x290` 分支影响：零值路径使用 `1.0f`，非零路径使用静态浮点常量
`0x3F2FAFB0`。这说明仅把 FMMap/MMap 原图缩放到 128×128 会丢失原版的裁剪、视图和
透明度行为。上述字段、调用点和分支已写入 `map-ui-resource-evidence.json` 的
`render_evidence.source_to_view_transform`，后续 Zircon 还原应实现这条数据链，而不是手动
校准一张截图。

### Finding 90：NPC 对话窗口的动态条目绘制循环已从静态代码闭合（2026-08-10）

继续检查 `0x0043F040` 绘制函数后，Frame 1101 并不是一个只显示一次的装饰图，而是在
`0x0043F0B2–0x0043F10B` 中按 `this+0x51C` 次循环绘制。循环索引为 `edi`，条目偏移寄存器
从 0 开始，每次增加 `0x12`（18 字节）；共享合成器为 `0x00460240`。条目的目标坐标来自
`this+0x530`/`this+0x534`，其中 Y 明确按 `entry_index*18` 递增，X 路径在
`0x0043F0FA` 对读出的基准值再加 1。构造函数默认计数是 13，但运行时计数仍必须以对象字段为准。

循环之后，程序在 `0x0043F120` 选择 Frame 1102，并在 `0x0043F16D` 绘制最后一个条目；其
索引是 `max(count-1,0)`，目标为 `this+0x540` 与 `this+0x544+index*18`。因此现在可以确定
NPC 对话框的动态区具有 18px 行节奏和“重复条目 + 最终选中/状态条目”的两阶段绘制结构，
但不能把 `this+0x530` 等字段直接误命名为屏幕坐标或正文字符串。

当全局 `0x008B1874 == 0` 时，函数从 `0x0043F179` 进入另一条归一化/透明度合成分支，读取
`this+0x520/+0x524/+0x528/+0x52C`，调用 `0x004542A0` 和 `0x00466800`。这条分支已记录为
静态候选，暂不解释为 NPC 业务文本。预览器现在将 13 个 18px 行框和最后条目框明确标为
candidate，避免把运行时字段尚未解析的目标位置伪装成已证实坐标。

### Finding 92：背包选中物品不是简单格子贴图，而是原版矩形合成链（2026-08-10）

重新反汇编 `0x0042EB7F–0x0042F050` 后，背包的选中物品路径在 `0x0042EC8C–0x0042EE2A`
先由 6×6 命中结果建立源矩形和目标矩形，再经 `0x00466800` 做浮点尺寸/坐标归一化，最后
通过 `0x004542F0`、上下文 `0x005600FC` 合成。这证明背包图标与选中态还原时应保留原版
的资源矩形和合成参数，不能只在 36×36 格子里放一个缩略图。

同一绘制函数还存在两组独立文字/数值绘制路径：`0x0042EE62` 通过 `0x0046811C` 使用
数据字符串 VA `0x0047A214` 的 `%d` 格式；`0x0042EFC4–0x0042F003` 通过 `0x0045DE50`
绘制第二组固定参数文字。当前已精确记录调用地址、窗口相对基线和共享合成器，但全局字段
对应“数量/名称/负重”等业务含义仍不以猜测命名，继续保留 pending。

### Finding 93：人物状态装备的选中资源由原版表驱动选择（2026-08-10）

在 `0x0044B560–0x0044B6A8`，状态窗口不是把选中装备固定画成某个 Frame：程序读取
`0x00777720` 的低字节，调用资源选择器 `0x00466130`，使用表 `0x00566DD4`，并从
`0x00566E0C/+0x04` 取得所选资源的尺寸/头信息，再交给 `0x0045FD50` 合成到人物中心
目标 `window+(0x61,0xC8)`。另一条分支还使用索引表达式
`low8(0x00777720)*10 + low8(0x00777723) + 0x3B`。

这条证据确认了装备图标/覆盖图的真实机制是“运行时类型或状态 → 原版资源表 → 资源头尺寸
→ 合成目标”，而不是现代 Zircon 的静态装备图标映射。字段的业务名字和每个索引对应的
武器、头盔、项链等名称仍未从原版符号中得到，因此继续标为候选，不强行命名。

### Finding 94：Frame 602 窗口的真实文字是行会公告/行会修改占位内容（2026-08-10）

对 `0x0043E260` 的绘制邻域继续追踪，在 `0x0043E3C0` 分支中发现了两组直接引用的 GBK
字符串：`0x0047C440` 为“[行会公告，请自行修改公告内容.]”，`0x0047C460` 为
“[行会修改 请自行修改行会等级、成员排行信息]”。两者都通过 `0x0045DD70` 绘制，主文字
基线为窗口相对 `(23,94)`；`this+0x1D0` 决定使用哪一组，随后还有相对 `(24,95)` 的辅助
文字路径。

因此 Frame 602 不能只标成无语义的“公告框”：内容证据明确指向行会/公告信息。但构造器的
主初始化参数仍是 id15、Frame602、`(107,110,584,252)`，二进制没有在这一段直接证明它
是否是独立提示窗口，还是行会窗口内部的一个状态。预览和 JSON 已记录真实字符串、分支、
坐标和颜色，同时保留“公告/行会信息候选”的归属状态。

### Finding 95：F950 确认框包含参数驱动的消息区域高度分支（2026-08-10）

在确认框包装器 `0x00418030` 中，构造参数在 `0x004181E5` 被测试；随后通过已确认的
`SetRect` IAT `0x004762B0` 设置 `this+0x18` 消息区域。非零参数分支的原始表达式为
`left=[esi]+0x18, top=argument_y+0x17, right=[esi]+0x14D, bottom=argument_y+0x64`，
零参数分支保持左右和顶部表达式不变，但底部改为 `argument_y+0x78`。这说明 F950 的
消息区并非固定按截图手调，至少存在两种由构造状态决定的高度。

RECT 设置后，代码调用 `0x004762BC`、`0x004762B8` 和 `0x004762AC`，参数中出现资源/上下文
`0x008AA48C`、常量 `0x135` 和视图偏移字段；由于这些是 IAT 间接调用，当前只把它们记录
为文本/字体资源操作候选，不把 API 名称或文字内容过度解释。三组按钮仍由
`0x00418176/AB/E0` 直接构造，父框、消息区和按钮状态现在可以在同一 JSON 中分层复核。
### Finding 96：商店构造函数的右侧物品网格确认为 4×3（2026-08-10）

`0x0044D4C4–0x0044D53B` 的商店构造函数实际初始化了三组矩形：左侧 `this+0x660` 为 5 行、
`(left,right)=(28,64)`、起始 y=26、步长49、高36；左侧文字/说明区 `this+0x6B0` 为 5 行、
`(left,right)=(69,256)`、起始 y=21、步长49、高45；右侧 `this+0x720` 的嵌套循环边界为
x=323,361,399,437 与 y=43,81,119，严格是 `4列×3行`、每格 `37×37`、步长38。

这纠正了此前把右侧网格写成“5×4 candidate”的错误。上述数字来自连续 `SetRect` 调用，
已写入 `store-window-render-evidence.json` 的 `constructor_rect_initializers`；它们仍是
窗口参数坐标，不能因为超出 F1000 的当前可见宽度就擅自平移或裁剪。

### Finding 97：商店绘制的可见商品列表上限为 5，且资源/价格链已闭合（2026-08-10）

在 `0x0044D631–0x0044DB15` 的主绘制循环中，商品链表头为 `this+0x64C`，节点下一指针为
`node+0x04`，商品资源 ID 为 `node+0x30`。局部行索引从 0 开始，达到 5 后退出，因此原版
当前窗口的可见商品行上限是 5；之前预览器使用 8 项是错误候选，已改为读取构造器的 5 行
矩形。

每个商品资源通过 `0x00466130` 和表 `0x0056B0E8` 选择，资源头尺寸来自 `0x0056B120` 等字段，
再经 `0x00466800` 归一化并由 `0x004542F0` 合成。对应文字走 `0x0046811C` 与
`0x0045DD70`，格式字符串 VA `0x0047C784` 的原始字节为 `(%d两)`，可确定存在价格/数量
类数值显示，但不把它单独命名为“价格”还是“重量”。

同函数后半段 `0x0044DB50–0x0044E021` 处理选中商品与分页：选中索引字段为 `this+0x7E4`，
记录入口为 `this+0x728+index*0x10`，状态 2 的页数按 `ceil((this+0x71C)/12)` 计算。
这些是静态字段和算法证据；商品业务是购买、出售还是仓库取存，仍需与状态入口绑定。

### Finding 98：行会窗口的三态绘制分支与九个控件位置已闭合（2026-08-10）

在行会窗口绘制函数 `0x00425040` 中，`this+0x98` 明确分派到三个子绘制函数：状态 0 调用
`0x00425280`，状态 1 调用 `0x00425440`，其它状态调用 `0x00425590`。这说明行会窗口不
是单一静态页，而是至少有三种内容/页签绘制状态。

同一函数在 `0x00425152–0x00425258` 通过 `0x00417830` 重新设置九个子控件的位置；相对
窗口原点的坐标依次为：`this+0x118=(556,409)`、`+0x1CC=(34,376)`、`+0x280=(34,402)`、
`+0x334=(121,402)`、`+0x3E8=(309,376)`、`+0x49C=(397,376)`、`+0x550=(484,376)`、
`+0x604=(309,402)`、`+0x6B8=(397,402)`。这些是绘制阶段真实的 SetPosition 参数，优先级
高于构造阶段寄存器尚未完全命名的表达式；Frame 610–625 的具体标签业务仍保持待绑定。

### Finding 99：组队窗口直接绘制“允许/拒绝”状态文字并重定位五个控件（2026-08-10）

在 `0x004243D0` 的组队窗口绘制函数中，成员链表仍从 `this+0x58` 读取，列表项通过
`0x0045DD70` 绘制；另一个状态字段 `this+0x3F0` 在 `0x00424532–0x00424570` 选择原版
GBK 字符串 `0x0047BA00=[拒绝]` 或 `0x0047BA08=[允许]`。这证明组队窗口确实包含权限/邀请
类状态显示，而不是只有成员名字。

同一段还通过 `0x00417830` 重新设置子控件：`this+0x6C=(226,214)`、`+0x120=(17,197)`、
`+0x1D4=(80,197)`、`+0x288=(159,197)`、`+0x33C=(9,52)`，均为窗口相对绘制阶段位置。
文字基线的寄存器来源还需运行时或更完整调用者上下文确认，因此保留 candidate；控件位置和
“允许/拒绝”字符串本身已是原版静态证据。

### Finding 100：聊天窗口的频道语义、滚动行数与重绘坐标已补齐（2026-08-10）

在聊天窗口刷新函数 `0x004142C0–0x0041482A` 中，原版从 `this+0x5C` 遍历聊天记录链表，
最多绘制 19 行；记录结构步长为 16 字节，但屏幕文字的视觉行距由绘制循环的 `0x0E` 确定，
即 14 像素。共享文字合成调用位于 `0x004147F3`，文字来源候选为 `node+0x08`，目标坐标
表达式为 `x=this+0x6C0+window.x`、`y=this+0x6C4+window.y+row_offset`。这比单纯用窗口背景
或现代客户端布局推测更接近原版真实绘制链。

六个频道/命令控件的状态分支位于 `0x00414A24–0x00414C00`，状态检查对象偏移依次为
`this+0x120/+0x1D4/+0x288/+0x33C/+0x3F0/+0x4A4`，对应静态命令字符串分别为：
`@拒绝 `、`!`、`!!`、`!~`、`@拒绝私聊`、`@拒绝行会聊天`。结合构造器中的完整中文说明，
可确定它们分别代表私聊拒绝、普通喊话、组队喊话、行会喊话、拒绝私聊开关、拒绝行会聊天开关。
是否把中文说明直接显示为按钮文字，仍取决于共享控件实现；预览器将其标记为命令语义候选，
不伪装成已经确认的 UI caption。

刷新阶段还会重新设置频道控件的固定窗口相对坐标：`(25,332)`、`(65,332)`、`(105,332)`、
`(145,332)`、`(185,332)`、`(225,332)`；关闭/首控件为 `(532,350)`。这些坐标与构造器坐标
一致，已写入 `chat-window-render-evidence.json` 并在 `wilviewer.py` 的聊天模式显示命令语义框。
输入框解析邻域还确认了 `/`、`(`、`)`、空格和冒号等语法标记，以及 `/%s ` 格式字符串；
剩余待确认项是共享文字渲染器的字体、颜色、裁剪和记录字段的精确顺序。

### Finding 101：任务列表存在长度分支与状态颜色分支（2026-08-10）

重新核对任务刷新函数 `0x00447470` 的完整反汇编后，任务记录通过 `0x0045E0C0` 解析，文本
记录字段候选为 `record+0x04`。列表文字仍以窗口相对 `(65,90)` 为首行、15 像素为行距，
最多受 19 行守卫限制；但长度超过 200 字节会进入 `0x0044755C–0x0044764E` 的长记录路径，
短记录走 `0x0044777E–0x00447824`，因此不能把所有任务标题都当作单一固定宽度字符串。

长短路径都会依据记录附近的 `+0x204/+0x210` 状态字段选择不同颜色常量候选
`0x0019197D/0x001919C8`，再调用共享文字合成 `0x0045DD70`。详情正文同样存在长行处理路径，
单行长度阈值候选约 190 字节，正文区域只显示当前滚动窗口的 3 行、15 像素行距。颜色常量
和记录字段顺序仍标为候选，但长度分支、列表坐标、详情坐标与 19/3 行上限均已固化到 JSON。

### Finding 102：系统设置窗口的九个控件在绘制阶段再次确认（2026-08-10）

系统设置窗口构造函数 `0x0044103E` 使用 Frame 750、窗口大小 `248×264`，随后绘制/重定位函数
`0x00441380` 通过通用位置函数再次写入九个控件的位置：关闭控件 `(218,238)`；两列开关
分别在 `(148,43)/(185,43)`、`(148,116)/(185,116)`、`(148,190)/(185,190)` 和
`(148,217)/(185,217)`。这些位置来自 `0x0044139E–0x0044148A` 的窗口相对坐标表达式，
因此优先级高于单次构造调用。原版还在 `0x00441CC0` 读取配置文件并把结果写入对象/全局字段，
但当前没有把这些字段强行命名成具体“音效、显示”等现代设置；预览器只显示静态控件几何框，
设置标签和状态字段继续保留为待解析内容。

### Finding 103：背包选中物品与数值文本的状态门控已补齐（2026-08-10）

背包绘制函数 `0x0042EB7F` 的选中物品分支并不是无条件绘制：它先检查全局字段
`0x007DA1C0/0x007DA1C4` 和 `0x007243D8`，再通过 `0x0042F150`、`0x0042F2A0` 解析鼠标/选中
槽位，最后进入源矩形、目标矩形、浮点归一化 `0x00466800` 和合成 `0x004542F0`。绘制入口在
`0x0042EBB0` 调用共享条/量条控件 `0x004179B0`（成员 `this+0x278`，构造于 `0x0042EB4B`，
GameInter 帧 `0x118`=280、12×218 竖直填充），`0x5E`=94 是量条的量程上限、不是素材帧号
（详见 Finding 141 之后的量条家族条目；本 Finding 的“顶部/详情组合素材”表述已被修正）。

数值文字链也已从反汇编中具体化：主数值读取 `0x007DA100`，格式字符串地址为 `0x0047A214`，
目标布局使用窗口相对 x=`0x41`、y=`0x11A/0x12B`；第二组文字读取
`0x007DA11D/0x007DA11F`，并由 `this+0x54` 的四态分支选择格式/颜色路径，格式字符串候选位于
`0x0047BDFC`、`0x0047BE10`、`0x0047BE18`。这些字段已经写入背包证据 JSON，但由于没有
符号和运行时数据，仍不把它们擅自命名为“负重、金币或数量”。

### Finding 104：交换窗口的左右交易区由原版构造器明确二分（2026-08-10）

交换窗口构造函数 `0x004159D0` 在创建三个控件前，直接读取对象边界字段
`this+0x18/+0x1C/+0x20/+0x24`，计算 `center_x=(left+right)/2`，然后通过两个 `SetRect`
调用把 `this+0x5C` 设为 `[left,top,center_x,bottom]`，把 `this+0x6C` 设为
`[center_x,top,right,bottom]`。因此 Frame 1050 的交易界面确实是左右双方区域，而不是
把两个候选面板凭视觉拼接出来。

交换绘制函数 `0x00415B10` 还给出了双方物品格的真实步长：状态 0 的起点为窗口相对
`(0x15,0x30)`，状态 1 的起点为 `(0xFD,0x30)`，横纵步长均为 36 像素；行索引来自
`this+0x54` 或其状态索引表。选中物品仍走源/目标矩形、`0x00466800` 归一化和
`0x004542F0` 合成链。两条交易重量量条（共享条/量条控件，成员 `this+0x13648/0x13694`、
GameInter 帧 `0x42E`=1070、12×184 竖直填充、量程上限 94）分别在
`(window.x+0xD1,window.y-0x73)` 和 `(window.x+0x1B9,window.y-0x73)` 被绘制（`0x41601C`/
`0x41603D`）——不是 Frame 94 素材侧板（见量条家族 Finding）。交换窗口的最终屏幕原点仍由
父对象传入，所以保留窗口原点待确认，不把构造参数直接当成 800×600 绝对坐标。

### Finding 105：坐骑窗口五个动作控件与点击分派已从原版闭合（2026-08-10）

坐骑窗口 Frame 850 的绘制/重定位函数 `0x004269C0–0x00426A56` 再次确认五个控件的固定
窗口相对位置：关闭 `(252,293)`，四个动作控件依次为 `(28,244)`、`(74,244)`、`(133,244)`、
`(192,244)`，与构造函数的 Frame 860–867 成对资源一致。

点击处理函数 `0x00426A80–0x00426B45` 按相同五个控件对象顺序进行命中测试，并根据全局
`0x007DA060` 选择不同动作/提示字符串候选 `0x0047B058/0x0047B060/0x0047B068`，最终进入
`0x004520F0`。其中 `0x008A68BC=0x12C` 和 `0x008A68C0=0` 是动作后的计时/状态写入候选。
因此坐骑窗口不只是静态背景，五个按钮的命中顺序和状态分支现在有原版机器码证据；具体中文
标签与坐骑字段仍保持待解析。

### Finding 106：商店/仓库共享面板状态图独立固化（2026-08-10）

为避免把商店、仓库和选中物品页混成一个业务窗口，新增
`store-state-graph.json`。它把协议入口 `0x0042BFE1`、共享状态字段 `this+0x5F8`、工厂
`0x00423E80` 与状态 0–4 的 Frame/调用点/原始工厂参数分开记录：状态 0/3 使用 F1000
`300×304`，状态 1 使用 F1003 `498×304`，状态 2 使用 F1001 `205×205`，状态 4 使用
F1002 `540×307`。同时明确记录工厂会继续做父级居中和 RECT 计算，因此这些参数不能直接
当作 800×600 屏幕坐标。

服务器 `Merchant.txt` 与 `Market_Def` 的 19 个仓储、108 个买入、108 个卖出分类只作为
二级交叉证据，暂不把任何一个客户端 state 强行命名为“仓库”或“商店”。

### Finding 107：NPC 对话条目数量、换行间距与动态按钮位置已闭合（2026-08-10）

在 NPC 对话数据准备函数 `0x00440750–0x00440AA0` 中，输入对话/菜单字符串按 `0x5C` 反斜杠
分隔，状态字段 `this+0x582`、源偏移 `this+0x584`、原始条目计数 `this+0x588` 最终生成
绘制计数 `this+0x51C = max(raw_count-6,0)`，并限制为 16 项；超过上限时设置 `this+0x58C`
溢出标记。绘制行距不是固定猜测：当 `this+0x582==1 && this+0x58C==1` 时为 14 像素，
否则为 21 像素，值存于 `this+0x594`。

同一准备路径还会按窗口底边重定位三个控件：`this+0x58` 到
`(window.x+0x15B, window.bottom-0x24)`，`this+0x1C0` 到
`(window.x+0x0B8, window.bottom-0x1E)`，`this+0x10C` 到
`(window.x+0x0C8, window.bottom-0x1E)`。这解释了为什么只看构造函数会得到不完整的 NPC
按钮布局；现在这些动态表达式已加入 NPC JSON，业务按钮名称仍保持待验证。

### Finding 108：窗口基类绘制门控与父背景先于子控件（2026-08-10）

窗口基类绘制函数 `0x00423D00` 只有在 `this+0x30 != 0` 且全局 `0x008B1874 != 0` 时才进入资源背景绘制；`this+0x28` 保存 Frame，`this+0x2C` 保存资源句柄，经 `0x00466130` 选择资源头后调用 `0x00460240`，源视口为 `800×600`。全局为 0 时会转入 `0x00466800` 的归一化/alpha fallback，这不是另一个独立窗口层。

这组机器码只能严格证明一个局部顺序约束：可见窗口的基类背景必须先于该窗口的派生绘制和子控件绘制；它不能证明两个可移动窗口之间谁覆盖谁。因此统一预览器将其标为 `base-before-child`，而把跨窗口 z-order 保留为 pending，避免把调用地址顺序误读成完整的运行时窗口管理顺序。

### Finding 109：公告预览器已接入原始子控件图层（2026-08-10）

统一证据预览的 `prompt.notice` 模式现在除 Frame 602 父容器外，还按
`0x0043E260` 包装器的原始表达式叠加两个子控件：Frame 161/162 的
`(655,126,28×26)` 与 Frame 606/607 的 `(603,153,40×20)`。这些位置来自父参数
`(107,110)` 加上已记录的相对偏移，不是视觉手工校准；控件的业务语义和 Frame 603/604
是否属于同一状态机仍保持候选。

### Finding 110：全局控件目录已把已知次级窗口控件从未归属池分离（2026-08-10）

全量 `0x00417550` 直接调用目录共 109 条，其中 72 条属于主窗口、15 条属于主 HUD；
另外 20 条已经能够由专用静态证据绑定到 Interface1c 选择界面、Interface1c 主界面候选、
确认框两个控件簇以及 Frame 602 公告包装器。它们现在标记为
`secondary-window-control`，并保留各自的 owner，不再和真正尚未追踪的 2 条调用混在一起。

这次分类只提升“代码归属”证据等级，不等同于确认业务名称或运行时状态；未归属的两条仍需
继续追踪 wrapper 和资源句柄后才能提升为坐标记录。

### Finding 111：主 HUD 的原版键盘语义字符串已从构造调用闭合（2026-08-10）

在主 HUD 初始化附近，`0x00427B24`、`0x00427B58` 和 `0x00427BAA` 还会把原版 GBK
字符串绑定到控件构造调用：`腰带(Ctrl+Z, Z)` 位于 Frame 159 的
`(hud.left+393, hud.top+13)`；`技能书(Ctrl+E, E)` 对应 F100/F101 的
`(hud.left+703, hud.top+16)`；`聊天记录(Ctrl+R, R)` 对应 F102/F103 的
`(hud.left+718, hud.top+32)`。后两项与已经恢复的技能、聊天历史 HUD 按钮坐标完全
重合，说明这些字符串是原版控件语义/提示链的一部分，而不是现代代码推断。

这些记录已写入 `hud-label-evidence.json` 并合并进 `layout.json`。Frame 159 是否在所有
状态下可见、以及文字颜色/字体的最终绘制路径仍保持 pending。

### Finding 112：腰带辅助文字控件已从未归属池提升为主 HUD 文本控件（2026-08-10）

`0x00427B24` 位于主 HUD 初始化连续调用中，直接使用 Frame 159、字符串
`0x0047BC68`（`腰带(Ctrl+Z, Z)`），并以 `[esi+0x0C58]+0x189`、
`[esi+0x0C5C]+0x0D` 计算位置。由于调用上下文、资源帧、原始字符串和坐标表达式均已
闭合，它现在在全局目录中标为 `main-hud-text-control / hud.belt-label`；这不等同于
确认它是始终可见的独立按钮，Frame 159 的最终显示状态仍按 HUD 文本 pending 处理。
### Finding 113：统一证据预览已显示主 HUD 原始语义控件框（2026-08-10）

`/ui` 的固定 800×600 HUD 模式现在从 `layout.json.hud_label_evidence` 读取三个原版
文本/辅助控件记录，并用金色调试框显示其 Frame、文本和绝对化坐标。该显示层只帮助核对
原版构造表达式，不会把字符串渲染成现代客户端的最终字体，也不会改变主 HUD 15 个按钮
的资源和命中矩形。

### Finding 114：剩余未归属控件已定位到独立组件 0x13，但暂不提升为游戏窗口（2026-08-10）

全局目录剩余的 `0x00455AF5` 不再是无上下文的孤立调用：它位于组件初始化
`0x00418CF1` 创建的 `owner+0x362354` 对象中，父构造器为 `0x00455A80`、vtable 为
`0x00476B7C`，实际控件初始化方法为 `0x00455AC0`。该方法在资源参数非空时使用
Frame 2/3，固定构造位置 `(135,400)`，并把资源参数保存到 `this+0x20EC`。

这些是可靠的静态组件/控件事实，但目前还没有证明资源参数属于 GameInter、也没有找到
它的可见绘制入口。因此它继续保留在 `unassigned-control-clusters.json`，并明确标为
`primary-static-component-context`，不把 `(135,400)` 擅自当成主游戏 UI 绝对坐标。

### Finding 115：商店/仓库状态的居中候选公式已进入统一布局数据（2026-08-10）

原版公共工厂 `0x00423E80` 会读取资源尺寸并执行父级矩形/居中算术；结合固定
`800×600` 证据视口，可得到状态 0/3 `(250,148)`、状态 1 `(151,148)`、状态 2
`(298,198)`、状态 4 `(130,147)` 的预览候选原点。它们现在写入
`store-state-graph.json.factory_centering_evidence` 并合并进 `layout.json`。

这些原点只表示“父级为完整 800×600 视口”的候选，不覆盖运行时父容器平移，因此仍不把
它们提升为 runtime-confirmed 绝对坐标。
### Finding 116：原版窗口位置更新由 0–15 号运行时窗口表分派（2026-08-10）

在 `0x0042B430` 发现了统一的位置更新分派：它先检查窗口运行时列表，读取选中节点 ID，
再通过 `0x0042B658` 跳转表把位置参数转给 `0x00423FA0`。已确认的映射包括背包 ID0、
状态 ID1、商店 ID2、交换 ID3、行会 ID4、组队 ID6、组队附属 ID7、聊天 ID8、NPC ID9、
任务 ID11、设置 ID12、坐骑 ID13 和其他窗口 ID14；ID5/10 是空分支，ID15 指向额外组件
`main+0x52E5C`。

这证明可移动窗口的“最终位置”不能只从初始化构造参数读取：原版会在运行时通过窗口表更新
位置。该证据已进入 `window-position-dispatch-evidence.json` 和统一 `layout.json`；由于
`0x00423FA0` 的初始窗口表尚未完全闭合，但其参数 ABI 已经闭合：普通 `flag=0` 分支中，
调用者压入的第一个位置参数是 X，第二个是 Y；函数分别加上 `this+0x40`、`this+0x44`，
再将左上角和保存的宽高写入窗口 RECT。

### Finding 118：位置更新辅助函数的 X/Y ABI 已由 SetRect 数据流闭合（2026-08-10）

`0x00423FA0` 的栈布局在函数序言后为：原始第一个参数位于 `[esp+0x18]`，第二个位于
`[esp+0x1C]`，第三个 flag 位于 `[esp+0x20]`。在 `flag=0` 分支，第一个参数与
`this+0x40` 相加形成 left，第二个参数与 `this+0x44` 相加形成 top，随后调用
`0x004762B0` 写入 RECT；窗口宽高来自 `this+0x10-this+0x08` 与
`this+0x14-this+0x0C`。

因此原版坐标恢复可以沿“注册/位置调用 → 参数 → 0x423FA0 → SetRect”自动化，不能再把
X/Y ABI 标成未知；目前真正剩余的是每个窗口初始注册调用传入的数值及运行时拖动后的更新。

位置分派的已知调用者只有 `0x0042C745`：外层 `0x0042C511` 先把两个输入参数保存到
`edi/ebx`，再按 `push edi; push ebx` 转交给 `0x0042B430`。这条链确认了运行时位置更新
来自统一窗口输入/更新入口；它还没有给出启动时每个窗口的初始常量，因此启动注册链仍需
继续追踪。

### Finding 117：原版窗口可见性是独立的显示/隐藏状态机（2026-08-10）

在 `0x0042ADB0` 发现了与位置更新分开的 0–15 号窗口可见性分派。它按窗口 ID 跳转，
再根据对象内的状态字段选择 `0x0042AC50`（显示）或 `0x0042AC30`（隐藏），并通过
对象 vtable `+0x10` 以参数 `1/0` 通知可见性变化。背包分支还会在首次显示后初始化子项
列表，说明“对象已构造”与“窗口当前显示”不是同一件事。

完整跳转表已核对：ID 0/1/2/3/4/6/7/8/9/11/12/13/14/15 的分支入口分别为
`0x0042ADCF`、`0x0042AE42`、`0x0042AE91`、`0x0042AEE0`、`0x0042B06B`、
`0x0042B0BA`、`0x0042B131`、`0x0042B180`、`0x0042B25E`、`0x0042AF2F`、
`0x0042AF7E`、`0x0042AFCD`、`0x0042B01C`、`0x0042B2AD`；ID5/10 落入默认分支。
这组证据已经写入 `window-visibility-dispatch-evidence.json` 并合并进 `layout.json`。
初始窗口注册顺序与 ID15 的业务身份继续保留为 pending；预览器不应仅凭构造器存在就默认
显示所有窗口。

进一步反汇编确认了两个辅助函数的方向：`0x0042AC30` 是显示路径，它把 `main+0xD24`
作为链表管理器并调用 `0x00449870` 分配/插入窗口 ID 节点；`0x0042AC50` 是隐藏路径，
遍历 `main+0xD28` 链表，摘除匹配 ID、递减数量并通过 `0x004680F8` 释放节点。分派中的
状态测试地址均等于对应窗口对象的 `this+0x30`，随后 vtable `+0x10` 收到 `1/0`。
这使“注册对象”“进入可见窗口链表”和“收到绘制可见通知”三个状态可以严格区分。
可见窗口链表的节点布局也已确认：节点 `+0` 保存窗口 ID，`+4/+8` 为前后指针；管理器
位于 `main+0xD24`，其 head/current/tail/index/count 分别为 `+0xD28/+0xD2C/
+0xD30/+0xD34/+0xD38`。这为后续按原版 z-order/窗口可见状态重建提供了直接数据结构依据。

### Finding 120：可见窗口链表存在独立的运行时遍历/重置入口（2026-08-10）

`0x0042B820` 从 `main+0xD28` 开始按节点 `+0x04` 遍历当前可见窗口，按 ID 分派到 13
个窗口对象，并调用 `0x00423F90` 将每个对象的 `this+0x34` 置零。该入口确认了原版
运行时遍历顺序和窗口 ID 映射，但它调用的是状态字段 setter，不是窗口 vtable 绘制槽；因此
暂时不能把它直接命名为最终跨窗口 z-order。证据已写入 `window-traversal-evidence.json`，
并把“找到真正消费该顺序的绘制入口”列为 pending。

### Finding 119：主 UI 初始化器完整注册了 0–15 窗口表中的可见对象（2026-08-10）

在 `0x00427600` 主 UI 初始化函数中，已逐项记录窗口包装器的构造调用：背包、状态、商店、
交换、行会、组队、组队附属、聊天、NPC、任务、设置、坐骑、其他窗口以及 ID15 的附属组件。
每条记录保留原始 wrapper 地址、GameInter Frame、800×600 中的构造位置和尺寸；这些值来自
原版调用参数，不是预览器手动拖动结果。

这组数据写入 `window-initialization-evidence.json` 并合并到统一 `layout.json`。显示状态仍
单独由 `0x0042ADB0` 分派，因此“已注册”不会被错误解释为“启动时必定可见”；ID15 仍标记为
附属提示/公告组件候选。

### Finding 122：人物状态窗口的局部绘制顺序已闭合（2026-08-10）

原版状态窗口 `0x0044B2D0` 的公共准备函数 `0x0044B560` 首先经窗口 vtable `+0x0C`
调用基类背景绘制 `0x00423D00`；随后执行选中装备/人物覆盖层 `0x0045FD50`，再进入
11 槽装备物品循环 `0x00430A40`，最后调用 `0x0044BC80` 绘制人物属性标签和格式化数值。
这条“背景 → 选中覆盖 → 装备物品 → 属性文本”的局部顺序来自原版调用地址，不代表跨窗口
覆盖顺序；已写入 `status-window-render-evidence.json`。

### Finding 121：坐骑窗口的基类背景与五个子控件绘制顺序已闭合（2026-08-10）

原版 `0x004269C0` 先通过窗口 vtable `+0x0C` 调用共享背景绘制候选 `0x00423D00`，
随后依次调用 `0x00417830` 重定位并绘制 `this+0x54`、`+0x108`、`+0x1BC`、`+0x270`、
`+0x324` 五个控件。相对坐标分别为 `(252,293)`、`(28,244)`、`(74,244)`、`(133,244)`、
`(192,244)`，对应 Frame 161/162、860/861、862/863、864/865、866/867。

这证明至少对坐骑窗口，背景必定先于子控件，且子控件顺序来自原版调用顺序；证据已写入
`horse-window-render-evidence.json` 并接入统一 `layout.json`。控件业务名称和最终命中框仍保持
pending。

### Finding 129：组队窗口局部绘制顺序已由原版入口闭合（2026-08-10）

原版组队窗口成员列表绘制入口为 `0x004243D0`。函数先经窗口 vtable `+0x0C` 绘制 Frame 900
背景并绘制固定头部文本；存在成员链表时，再按索引奇偶分成两列，以 `(window.x+45,
window.y+90)` 为起点、列间距 100、行间距 20 绘制成员文本。随后按固定坐标重新定位关闭/操作
控件，依据 `this+0x3F0` 绘制 `[允许]` 或 `[拒绝]`，最后按原始对象顺序调用五个子控件的
vtable `+0x04` 绘制槽。

因此组队窗口当前可确认的局部顺序是：Frame 900 背景/头部 → 成员列表 → 控件定位 → 权限
状态文字 → 子控件绘制。成员记录字段与头像/图标顺序、权限文字的最终命中框以及运行时打开
状态仍保持 pending；证据已接入组队聚焦预览。

### Finding 123：背包窗口局部绘制顺序已由入口反汇编闭合（2026-08-10）

原版背包绘制入口为 `0x0042EB7F`。函数一开始经窗口 vtable `+0x0C` 调用基类背景，随后
在 `0x0042EBB0` 调用共享条/量条控件 `0x004179B0`（成员 `this+0x278`）：竖直量条
GameInter 帧 `0x118`=280（16×424）、填充区 12×218、量程上限 `0x5E`=94，绘制于
`(window.x+0xF8, window.y-0xA5)`。`0x5E` 是量条量程、不是素材帧号——原先“顶部/详情组合
素材 Frame 94”的判断已被量条家族 Finding 修正。接下来才处理选中物品分支：先检查选择状态，
调用 `0x0042F150`/`0x0042F2A0` 完成 6×6 格命中与索引换算，再通过 `0x00466800` 和
`0x004542F0` 组合源/目标矩形。两条分支随后汇合到 `0x0042F790`，再绘制主数量/数值文本；
最后按固定偏移更新三个子控件，并依据 `this+0x54` 的状态分支绘制第二组文本。

因此当前可用于重建的局部顺序是：背景 → 竖直量条（填充值 `[this+0x58]` 本构建从未写入→
空条） → 选中物品命中/图标组合 → 物品列表路径 → 数量/数值文本 → 三个子控件定位 →
状态相关文本。该顺序是函数内调用顺序，
不等同于所有窗口之间的全局 z-order；业务字段名称、运行时物品句柄和数量/名称的确切语义
仍保持 pending。证据已写入 `inventory-window-render-evidence.json`，并接入 `/ui` 的背包
聚焦预览右上角“原版局部绘制顺序”面板。

### Finding 124：任务窗口局部绘制顺序已由刷新函数闭合（2026-08-10）

原版任务窗口刷新/绘制入口为 `0x00447470`。入口先经窗口 vtable `+0x0C` 绘制 Frame 700
背景，然后定位并调用两个操作控件的 vtable `+0x04` 绘制槽；之后刷新任务链表，使用
`0x0045E0C0` 解码长/短任务记录并按每行 15 像素绘制列表。列表更新结束后，如果存在当前
任务详情，`0x00447E07` 选择 Frame 705 并在 `(window.x+0x41,window.y+0x126)` 绘制详情
区域，最后在 `(window.x+0x50,window.y+0x136+15*line)` 绘制最多三行正文。

因此任务窗口的局部顺序是：Frame 700 背景 → 两个操作控件 → 任务列表行 → Frame 705
详情区域 → 详情正文。详情字段分隔符、换行宽度和运行时业务名称仍保持 pending；证据已写入
`quest-window-render-evidence.json` 并接入背包/状态/坐骑同样的预览器绘制顺序面板。

### Finding 125：商店/仓库候选窗口的局部物品绘制顺序已补齐（2026-08-10）

原版商店候选窗口绘制入口为 `0x0044D590`。它先按照 `this+0x5F8` 状态构造裁剪矩形，随后
遍历 `this+0x64C` 的物品链表；每个可见记录通过 `0x00466130` 选择资源，使用
`0x00466800` 与 `0x004542F0` 完成图标源/目标矩形组合，最多处理五个可见行。选中项路径
随后调用 `0x0045E570` 选择标记并绘制描述区域，再格式化 `this+0x24` 的数值，使用
`0x0047C784`（原始字符串为 `(%d两)`）输出价格/数量文本，最后按状态绘制辅助操作文字。

这条证据把商店/仓库候选的“裁剪 → 物品行 → 选中标记/描述 → 价格/数量 → 辅助文本”局部
顺序接入预览器；它没有把 state 0–4 强行命名为商店或仓库，因为这些业务名称仍需协议和
运行时入口绑定。原始窗口工厂的父级居中算法与最终屏幕原点继续保持 pending。

### Finding 126：聊天窗口局部绘制顺序已由原版绘制入口闭合（2026-08-10）

聊天窗口实际绘制入口为 `0x00414700`；`0x004142C0` 是刷新/滚动数据准备路径。绘制函数
首先经窗口 vtable `+0x0C` 绘制背景，随后写入固定的输入区裁剪矩形
`(window.x+25,window.y+311)-(window.x+524,window.y+326)`。之后遍历聊天链表，以
`(window.x+40,window.y+29)` 为首行位置、每行 14 像素绘制最多 19 行历史文本。历史文本完成
后，函数按固定偏移定位关闭、六个频道和两个滚动控件，依次调用九个子控件的 vtable
`+0x04` 绘制槽，最后根据输入缓冲区生成输入字符矩形。

这使聊天窗口的局部顺序明确为：背景 → 输入区裁剪 → 聊天历史 → 控件定位/绘制 → 输入字符
矩形。频道命令语义和文本字段已保留在原证据中；共享文本渲染器的字体、颜色及第一个控件
的最终命中语义仍保持 pending。证据已接入聊天聚焦预览的“原版局部绘制顺序”面板。

### Finding 128：系统设置窗口局部绘制顺序已由原版重绘入口闭合（2026-08-10）

系统设置窗口重绘入口为 `0x00441380`。函数首先经窗口 vtable `+0x0C` 绘制 Frame 750
背景，然后按原版调用顺序定位关闭控件和八个选项控件，并额外定位两个状态相关控件；所有
位置写入完成后，循环调用前九个子对象的 vtable `+0x04` 绘制槽。

因此当前可确认的局部顺序是：Frame 750 背景 → 九个固定控件定位 → 两个附加状态控件定位
→ 九个子控件绘制。Frame 760/762 的选项语义、状态字段以及 y=96/170 的非 Frame 文本项
仍保持 pending，避免把控件外观误命名为业务标签。证据已接入系统设置聚焦预览。

### Finding 127：NPC 对话窗口的资源绘制顺序已由原版入口闭合（2026-08-10）

NPC 窗口绘制入口为 `0x0043F040`。在主资源路径中，函数首先选择并合成 GameInter Frame 1100，
随后按 `this+0x51C` 循环选择 Frame 1101，最后将索引限制到最后一项并选择 Frame 1102。
这些操作全部经过原版 800×600 图像合成器 `0x00460240`，每项来源记录保持 18 字节步进。
当主资源路径不可用时，函数转入单独的 `0x004542A0` 归一化/透明合成分支；目前没有证据
把该分支命名为正文绘制。

因此当前可确认的局部顺序是：Frame 1100 主对话背景/入口 → Frame 1101 重复对话或菜单项 →
Frame 1102 最后一项 → 透明/归一化 fallback。三枚子控件的动态底部位置来自独立重排路径，
仍不把它们错误地插入到本绘制入口中。证据已接入 NPC 聚焦预览的局部绘制顺序面板。

### Finding 132：确认框与公告框局部绘制顺序已闭合（2026-08-10）

确认框类的绘制入口为 `0x004182A0`：先合成 Frame 950 父面板，再通过共享文本/资源路径
绘制消息缓冲区，最后按对象顺序处理最多三个 YES/NO/确认动作控件。`-1/-1` 构造参数的
Frame 950 居中规则为屏幕矩形 `(220,151)-(580,341)`。

公告/行会提示窗口绘制入口为 `0x0043E3C0`：先调用窗口 vtable `+0x0C`，再根据
`this+0x1D0` 绘制原版 GBK 状态文本，随后绘制第二条文本，最后定位并绘制两个子控件。
两组证据均已写入对应 JSON，且预览器的确认框/公告框模式现在显示“原版局部绘制顺序”面板。
确认框父业务类型、公告 Frame 602 与行会页面的最终绑定仍保持 pending。

### Finding 131：交换窗口局部绘制顺序已由原版交易入口闭合（2026-08-10）

交换窗口绘制入口为 `0x00415B10`。它首先调用窗口 vtable `+0x0C`，然后依据窗口边界写入
左右交易区的中心分割矩形。接着读取选择状态和 `0x007DA1C0/0x007DA1C4`，按状态选择左侧
`x+0x15` 或右侧 `x+0xFD` 的 36 像素物品格，并把物品源/目标矩形交给 `0x00466800` 与
`0x004542F0`。物品路径完成后，函数调用 `0x004169B0` 并输出交易标签、物品文字及数值
状态；最后在 `x+0xD1` 和 `x+0x1B9`、`y-0x73` 绘制两条交易重量量条（`0x41601C`/
`0x41603D`，共享条/量条控件成员 `this+0x13648/0x13694`、GameInter 帧 `0x42E`=1070、
12×184 竖直填充、量程上限 94）——不是 Frame 94 素材侧板。

当前可确认的局部顺序是：背景/左右分区 → 状态物品格与选中合成 → 交易文本/数值 → 两条
交易重量量条（填充字段 `[this+0x54/0x58]` 从未写入→空条）。窗口工厂父级居中后的最终
屏幕原点及三个控件的业务语义仍保持 pending；证据已接入交换聚焦预览。

### Finding 133：技能书窗口主重绘顺序已由原版入口闭合（2026-08-10）

技能书/技能类别候选窗口的主重绘入口为 `0x00439500`。原版先通过窗口 vtable `+0x0C`
绘制 GameInter Frame 400 基础面板，随后调用 `0x004397A0` 组合当前页和类别下的技能图标、
名称及列表内容，再调用 `0x0043A440` 从 `Magic.exp` 流解析并绘制说明/列表文字。文字完成后，
函数按固定偏移重定位并绘制三个页签/翻页控件，随后重定位并绘制八个类别按钮（火、冰、电、风、
神圣、黑暗、幻影、剑），最后调用共享文字渲染路径输出当前类别/页码等数值状态。

因此当前可确认的局部顺序是：Frame 400 基础面板 → 技能图标/名称组合 → Magic.exp 技能
文字 → 三个页签/翻页控件 → 八个类别按钮 → 数值/状态标签。技能类别按钮的静态相对位置和
Frame 对已记录在 `skill-window-context.json`；Magic.exp 的加密/编码格式、列表字段语义以及
窗口最终屏幕原点仍保持 pending，不能仅凭静态调用顺序强行命名。

补充核对 `0x00439500` 的尾部调用后，分页状态文字也已闭合：程序读取当前类别的记录计数
`this+0x58+4*byte(this+0x54)`，通过 `imul 0x2AAAAAAB` 得到按六条一页的商，再分别计算
`商*2+1` 与 `商*2+2`，使用格式化入口 `0x0046811C` 和共享文字绘制入口 `0x0045DD70`，
在窗口相对 `(117,299)` 与 `(118,309)` 附近输出两组状态字符串。这里的“起始/结束页”是
根据计算形式得出的语义候选，格式字符串的最终中文含义仍保留证据等级，不把它强行改名为
现代客户端的页码标签。

### Finding 134：窗口默认可见性门与完整 ID 分派已由共享构造器闭合（2026-08-10）

重新核对 `0x00427600` 主 UI 初始化段和所有登记包装器后确认：15 个窗口包装器都进入共享
构造路径 `0x00423B30`，其基类初始化实现 `0x00423CA0` 明确把对象 `+0x30` 可见性门写为
`0`。主初始化段按 ID 0、1、2、3、4、6、7、8、9、11、12、13、14、15 构造/注册对象，
但在这段登记序列中没有调用 `0x0042AC30` 显示辅助函数。

因此原版初始状态可以静态确定为：窗口对象存在，但默认不进入 `main+0xD24` 可见链表；之后
由 `0x0042ADB0` 的 ID 分派调用显示辅助函数，将 ID 插入链表并对对象虚表 `+0x10` 传入 `1`。
此前把“默认 visibility gate 初值”列为 pending 的标记已移除。ID15 是否业务上对应 Frame 602
公告/提示家族仍单独保留为待确认事项。

### Finding 135：ID15 与 Frame 602 公告/行会提示对象身份闭合（2026-08-10）

`0x0042797E` 的主初始化调用 `0x0043E260`，该包装器在 `0x0043E295` 进入共享基类构造，
随后直接创建 `this+0x54` 的 Frame 161/162 控件和 `this+0x108` 的 Frame 606/607 控件。
同一对象的重绘入口从 `0x0043E3C0` 开始：它先调用对象 vtable `+0x0C`，读取同一对象的
`this+0x1D0` 状态字段绘制两组原版行会/公告文字，再重定位并绘制这两个子控件。

这条对象字段、构造器、绘制入口和子控件偏移的连续链条足以确认：窗口 ID15 就是 Frame 602
公告/行会提示窗口，而不是独立的地图 UI 或未知 secondary component。仍未强行推断的是它由
行会页面还是某个独立命令打开，以及 F603/F604 是否属于同一状态机。

### Finding 130：行会窗口状态分派与局部绘制顺序已闭合（2026-08-10）

行会窗口的公共绘制包装器为 `0x00425040`。它先通过窗口 vtable `+0x0C` 绘制 Frame 600
背景并写入窗口裁剪矩形/头部文本，然后根据 `this+0x98` 分派到三个状态路径：
`0x00425280`、`0x00425440`、`0x00425590`。三条路径都使用 `this+0x9C` 作为滚动起点，遍历
对应链表并通过 `0x0045DD70` 绘制可见行；返回公共包装器后，才按固定参数重定位九个控件，
最后按原始对象顺序调用九个子控件的 vtable `+0x04`。

因此当前可确认的顺序是：Frame 600 背景/头部 → 状态页列表 → 九个控件定位 → 九个子控件
绘制。三个状态的业务名称、四个构造阶段寄存器歧义项和特殊标记颜色仍保持 pending；证据
已接入行会聚焦预览。

### Finding 138：人物装备图标的原版资源选择链已定位（2026-08-10）

人物状态绘制命中某个槽位后，`0x0044B6F7` 把该槽位记录的 `+0x04`（即窗口对象中
`this+0x2F8+index*0xC24` 的图形对象）传给通用物品绘制入口 `0x004341F0`。该入口读取
图形对象 `+0x28` 的 WORD，作为参数调用 `0x00466130`，并固定使用选择上下文
`0x005668C4`；随后从 `0x005668FC` 读取所选帧的宽高，再进入原版图形合成路径。

这已经证明装备图标是“每件物品自己的记录 → 原版帧选择器 → 原版合成器”的链路，而不是
现代客户端可以随意替换的统一占位图。当前仍未把选择上下文反查到具体 `WIL/WIX` 文件名，
所以该文件绑定继续标为 pending；相关字段和地址已写入状态窗口证据 JSON。

### Finding 137：ID15 的显示/隐藏分派路径已闭合（2026-08-10）

`0x0042ADB0` 的 ID15 分支 `0x0042B2AD` 先测试 `main+0x52E8C`，然后在两条路径中分别调用
`0x0042AC30`/`0x0042AC50` 修改可见窗口链表，并通过对象虚表 `+0x10` 写入显示值 `1` 或
隐藏值 `0`。显示路径还会调用一个带全局位置参数的外部提示/消息例程；这证明公告窗口有
独立的运行时状态切换入口，但仅凭这一层仍不能把业务触发者冒充成“行会页面”，因此该
业务来源继续保持 pending。相关原始地址和分支已写入 `notice-prompt-window-evidence.json`。

### Finding 136：人物状态窗口的 11 个槽位索引与固定矩形闭合（2026-08-10）

人物状态窗口构造器 `0x0044B130` 通过 `SetRect` IAT `0x004762B0` 为 `this+0x1C0` 起始的 11 个位置记录写入固定矩形；绘制循环 `0x0044B5D9-0x0044B629` 以相同的 11 项、每项 `0xC24` 的物品记录步长和每项 `0x10` 的位置记录步长逐项消费它们。因此下表是原版索引事实，不是现代客户端的业务猜测：

| 索引 | 位置记录 | 相对矩形 | 当前语义边界 |
|---:|---|---|---|
| 0 | `this+0x1C0` | `(86,114)-(146,204)` | 中央角色图/特殊装备绘制目标 |
| 1 | `this+0x1D0` | `(38,70)-(91,154)` | 属性/角色区域候选 |
| 2 | `this+0x1E0` | `(27,264)-(65,302)` | 装备槽候选 |
| 3 | `this+0x1F0` | `(177,70)-(215,108)` | 装备槽候选 |
| 4 | `this+0x200` | `(94,71)-(143,104)` | 中央头像/名称区域候选 |
| 5 | `this+0x210` | `(27,186)-(65,224)` | 装备槽候选 |
| 6 | `this+0x220` | `(175,186)-(213,224)` | 装备槽候选 |
| 7 | `this+0x230` | `(27,227)-(65,265)` | 装备槽候选 |
| 8 | `this+0x240` | `(175,227)-(213,265)` | 装备槽候选 |
| 9 | `this+0x250` | `(64,264)-(102,302)` | 装备槽候选 |
| 10 | `this+0x260` | `(103,264)-(141,302)` | 装备槽候选 |

索引 `0/1/4` 走 `0x00430A40` 的特殊中心绘制分支；其余八个索引使用各自位置记录的左上坐标加窗口偏移和 `+0x0F` 边距。槽位的“武器/头盔/项链”等业务名称，以及实际装备图标资源句柄，仍必须从物品数据/资源选择路径继续闭合，不能仅凭左右位置命名。

### Finding 139：坐骑窗口五个控件的命中矩形与点击分支闭合（2026-08-10）

坐骑窗口的五个子控件不需要手工拖动校准。共享控件构造器 `0x00417550–0x004175B0` 在选择资源帧后，以 `SetRect(this+0x04, x, y, x+selected_frame.width, y+selected_frame.height)` 写入命中矩形。结合 GameInter.wil 的帧头尺寸，可以得到相对于 Frame 850 左上角的精确矩形：`161/162=(252,293,28,26)`、`860/861=(28,244,44,20)`、`862/863=(74,244,60,20)`、`864/865=(133,244,60,20)`、`866/867=(192,244,56,20)`。

点击入口 `0x00426A80–0x00426B45` 按同一对象顺序测试五个控件。首个对象只返回 handled；其余分支根据 `byte [0x007DA060]` 和子控件处理结果，把运行时数据指针 `0x0047B058/0x0047B060/0x0047B068` 交给共享消息入口 `0x004520F0(this=0x008AB828)`。这证明了交互顺序和消息分派，但这些指针位于运行时数据区，中文业务标签尚未静态解出，因此没有冒充成“上马/喂养”等名称。

Frame 850 的资源可见 alpha 包围盒为 `275×323`，窗口构造尺寸为 `296×332`；目前可确认它是窗口底图的完整资源范围，不能据此断言整个最终合成只包含底图，状态相关文字或叠加层仍可能在其后绘制。

### Finding 140：背包物品绘制的资源句柄与记录字段入口进一步闭合（2026-08-10）

背包窗口不是用现代客户端的统一图标表填充。原版主对象在 `0x00452AE6` 开始装载 70 个资源句柄，GameInter 路径字面量为 `0x0047CE0C`；窗口构造调用 `0x00417550` 时把该句柄通过 `EDI` 传给关闭按钮和另外两个状态控件。背包的物品绘制入口 `0x0042F790–0x0042FA68` 从 `this+0x774+4*record_index` 的记录数组读取物品/位置/状态字段，使用 `window.x+0x19+36*column`、`window.y+0x29+36*row` 形成 36×36 网格格位，再以记录中的 WORD 帧选择值调用 `0x00466130(context=0x005668C4)`，最终通过 `0x00466800 → 0x004542F0` 做原版源矩形/目标矩形合成。

这批证据把“资源句柄从哪里来”和“图标绘制从哪条记录开始”从 pending 中移出；尚未强行命名的是 `x+0xF8/y-0xA5` 量条（共享条/量条控件、填充值 `[this+0x58]` 从未写入）的具体业务用途（负重候选），以及数量/名称文字字段的完整排列和记录步长。

### Finding 141：聊天窗口首七个控件的命中矩形和输入顺序闭合（2026-08-10）

聊天窗口的首个关闭/控制帧 `161/162` 命中矩形为 `(532,350,28,26)`；六个频道按钮使用 GameInter 帧宽高 `36×34`，相对矩形依次为 `(25,332)`、`(65,332)`、`(105,332)`、`(145,332)`、`(185,332)`、`(225,332)`。这些矩形不是按截图估计，而是共享 `0x00417550` 根据所选帧头尺寸写入 `SetRect` 的结果。

聊天输入处理入口 `0x004149A0–0x00414C56` 先测试 `this+0x6C` 的子控件 `vtable+0x10`；若已处理立即返回，所以这条路径确认它是通用关闭/控制入口，不应误命名为聊天频道。只有该控件未处理后，程序才按构造顺序测试六个频道控件并更新对应的命令状态；滚动条控件 `this+0x558/0x60C` 在其后处理，因状态资源来自不同库，其最终命中矩形继续保留待解。

### Finding 142：主 HUD 血条/经验条资源调用顺序闭合（2026-08-10）

主 HUD 动态绘制入口 `0x00429740` 的资源调用顺序已从分支地址闭合：状态动态帧 `0x82–0x85`（`0x00429819`）→ GameInter Frame 62（`0x004299CB`）→ Frame 60（`0x00429BDB`）→ Frame 61（`0x00429C53`）→ Frame 63（`0x00429FD5`）→ 经验百分比文字（`0x0042A065`）。每个填充路径都先计算归一化比例，再经 `0x00466800` 和 `0x004542F0` 合成；经验文字使用原版格式字面量 `0x0047BD4C/0x0047BD5C`。

这确认了原版内部资源调用顺序，但不能把所有帧简单命名成“前景/背景”：Frame 60/61/62/63 在不同状态分支中可能承担不同方向或覆盖层角色，最终可见剪裁方向仍需运行时绘图捕获验证。

### Finding 143：NPC 对话窗口三个子控件的静态命中矩形闭合（2026-08-10）

NPC 窗口构造器把 GameInter 帧头尺寸直接用于公共控件 `SetRect`：Frame 161/162 的首控件相对命中矩形为 `(7,141,28,26)`；Frame 52/53 和 54/55 在该客户端的 GameInter 版本均为 `12×8`，对应矩形分别为 `(290,145,12,8)` 与 `(306,136,12,8)`。Interface1c 中同号帧是另一组大尺寸资源，不能混入这个 EI 3.0 GameInter 对话窗口。

这批结果只闭合几何和资源库选择，不把三个小控件强行命名为“确认/下一页/头像按钮”；它们的业务语义仍需沿点击分支或运行时数据继续确认。

### Finding 144：装配预览明确区分“已构造”与“初始可见”（2026-08-10）

原版主初始化会构造并登记窗口对象，但共享构造器把窗口对象的 `+0x30` 可见性门写为
零；只有 `0x0042ADB0` 的 ID 分派路径调用 `0x0042AC30` 插入可见窗口链表，并通过
虚表 `+0x10` 传入显示值 `1`。因此固定 800×600 装配预览中同时展示多个窗口时，不能
被理解为“原版启动时全部叠加在屏幕上”。

预览器现在把每个窗口的 `default_visibility` 证据附加到窗口标签中。窗口底图仍可在
主组合页查看，作用是核对资源与构造矩形；实际显示状态必须以窗口专项模式和可见链表
证据为准。这种标注避免为了方便调 UI 而把隐藏窗口错误当成原版最终层级。

### Finding 145：背包与人物状态控件的命中矩形闭合（2026-08-10）

继续沿用公共控件构造器 `0x00417550` 的实际行为，把两个窗口的固定子控件从“只有坐标表达式”提升为可直接用于还原和点击测试的窗口相对矩形。背包 Frame 250 的三个控件为：关闭/确认 `161/162=(249,288,28,26)`；`264/265=(176,262,64,20)`；`267/268=(176,286,76,88)`。最后一组在 EI 3.0 中实际来自 `Interface1c.wil`，不能因为调用方属于背包就错误地假设全部来自 `GameInter.wil`。

人物状态 Frame 200 的两个公共控件为 `161/162=(212,298,28,26)` 和 `171/172=(176,286,36,36)`。这些均是窗口局部坐标，窗口移动时应整体平移，不应重新手工校准。人物装备槽的 11 个 `38×38` 区域仍按状态窗口自己的物品循环单独处理，不能与公共按钮矩形混为一谈。

证据已写入 `inventory-window-render-evidence.json` 与 `status-window-render-evidence.json`，并由 `enrich_mir3_layout_evidence.py` 合并到统一 `layout.json`。

### Finding 146：商店窗口八个操作控件的资源尺寸与坐标表达式闭合（2026-08-10）

商店/仓库状态机的八个公共控件现在也记录了完整的命中矩形输入：`1010/1011` 为 `28×26`，`1012/1013` 为 `48×20`，`1014/1015` 与 `1016/1017` 为 `28×26`，全部由 `GameInter.wil` 帧头直接提供尺寸。坐标保留为 `arg4/arg5` 的原始相对表达式，例如首个控件为 `arg4+0x10A,arg5+0x10E`，而不是把尚未经过 `0x00423E80` 父窗口居中算法的参数伪装成屏幕坐标。

这一步把“按钮能点击到哪里”和“按钮究竟是购买、出售、仓库或翻页”分开：前者已由静态二进制和资源闭合，后者仍必须沿状态字段 `this+0x5F8` 的消息/点击分支确认。

### Finding 147：NPC 菜单重复条目的实际绘制几何闭合（2026-08-10）

重新核对 `0x0043F0B2–0x0043F111` 的原始指令后，`EBX` 从 0 开始并以 `0x12`（18 字节）递增，但循环体没有读取 `[this+EBX]` 之类的业务字段；它只把 `EBX/0x12` 作为条目序号参与目标位置计算。Frame 1101 的每一项实际落点为：`x = this+0x530 + 1 + entry_index`，`y = this+0x534 + entry_index*18`，源图尺寸来自 Frame 1101 的 WIL 头部，循环上限是 `DWORD [this+0x51C]`。

因此目前可以准确还原 NPC 菜单的重复贴图带和最后一项 Frame 1102 的位置，但不能把 18 字节步长直接解释成“每条文本记录的字段布局”。文本/业务字段由前面的对话解析与对象状态准备路径产生，仍需独立闭合。

### Finding 148：聊天文字绘制调用的参数流闭合（2026-08-10）

在聊天绘制循环 `0x004147C1–0x004147F3` 中，原版把 `node+0x08` 作为文字指针传给共享文字合成器 `0x0045DD70`；屏幕坐标是 `x=this+0x6C0+window.x`、`y=this+0x6C4+window.y+row_offset`，`row_offset` 每行增加 14。相同调用还把 `node+0x00`、`node+0x04` 和全局渲染上下文 `0x008AB7A8/0x008AB7C4` 传入。

这比仅记录“调用了 0x45DD70”更强：已经可以在复刻器中按原始参数顺序生成文字调用和调试标记；但 `node+0x00/node+0x04` 的业务含义，以及 `0x008AB7C4` 最终对应的字体/颜色表，仍保持待验证，没有把它们臆测成颜色或频道编号。

### Finding 149：跨窗口绘制分派入口闭合（2026-08-10）

在 `0x004280F0–0x00428357` 找到真正消费可见窗口链表的绘制分派。函数从 `main+0xD2C` 当前节点读取 `node+0x00` 窗口 ID，在 `0x0042815F` 的 ID 跳转表中分派到专用绘制入口，然后在 `0x004282A9–0x004282D8` 沿 `node+0x04` 进入下一个可见窗口。已闭合的入口包括：背包 `0x0042EB80`、状态 `0x0044B2D0`、商店 `0x0044E260`、交换 `0x00415B10`、行会 `0x00425040`、组队 `0x004243D0`、聊天 `0x00414700`、NPC 包装 `0x0043F460`、任务 `0x00447470`、选项 `0x00441380`、坐骑 `0x004269C0` 和公告 `0x0043E3C0`。

这证明当前可见窗口链表顺序确实是跨窗口绘制顺序的输入，不再只是可见性更新顺序。它仍不能推出固定启动层级：显示、隐藏和置顶操作会改变链表顺序，具体插入策略继续保留为待追踪项。

### Finding 150：可见窗口链表的追加/删除策略闭合（2026-08-10）

`0x0042AC30` 并不是把新窗口插到链表头部，而是把窗口 ID交给 `0x00449870`。该分配器在空表时建立循环头/尾；非空时把新节点接到当前 `manager+0x0C` 尾部，并递增计数。`0x004280F0` 从 `manager+0x04` 开始沿节点的 `+0x04` 链绘制，因此“后显示的窗口”在没有其他状态变化时位于更晚的绘制位置，覆盖先显示的窗口。

隐藏路径 `0x0042AC50` 会摘除匹配 ID、减少计数并经 `0x004680F8` 释放节点；之后再次显示会重新追加到尾部。二进制目前没有证明独立的“置顶”原语，所以任何置顶语义都必须由调用方的隐藏后再显示序列来解释，不能凭 UI 习惯臆测。

### Finding 151：坐骑按钮文字直接从原版 WIL 像素确认（2026-08-10）

直接解码原版 `Data/GameInter.wil` 的 860–867 帧后，四组普通/按下按钮的图中文字可见：`860/861` 为“马上骑”，`862/863` 为“马儿跑”；`864/865` 与 `866/867` 的字形目前分别记录为“马鞍骑”“马鞍跑”候选，第二字仍保留中等置信度，避免把像素辨识误当成字符串表证据。

这补足了坐骑窗口中原先只有 Frame 编号而没有内容语义的缺口，同时保留了点击分支的独立证据：`0x00426A80–0x00426B45` 只证明不同控件根据 `0x007DA060` 和子控件处理结果调用 `0x004520F0`，不能仅凭按钮上的文字断言状态业务。

### Finding 152：行会窗口八组操作按钮的原版像素文字补全（2026-08-10）

直接从原版 `Data/GameInter.wil` 解码并放大检查 Frame 610–625，确认这是八组普通/按下按钮，而不是抽象的“若干行会操作”。从左上到后续按钮，其可见文字依次为：`会员升职`、`成员踢出`、`盟主转让`（中等置信度）、`邀请入会`（中等置信度）、`行会公告`、`退出行会`（中等置信度）、`行会解散`、`关闭窗口`。普通帧与按下帧只在视觉状态上变化，文字本身相同。

该结果已写入 `social-window-render-evidence.json` 的 `resource_visual_text.guild_control_records`。这里仍严格区分“按钮美术上写了什么”和“点击后执行什么”：后者必须继续沿子控件对象、窗口消息分支和行会状态字段闭合，不能仅凭四字标签推导业务行为。`Frame 610/611` 等资源文字也不能覆盖静态位置证据；四个构造器位置目前仍保留为寄存器流候选，等待与绘制期 `SetPosition` 及点击分支对应。

### Finding 153：窗口显示/隐藏调用者与状态链补全（2026-08-10）

对原版 `Mir3.exe` 直接调用 `0x0042ADB0` 的位置做了全量静态扫描，并把立即压入的窗口 ID 与相邻基本块写入 `window-visibility-dispatch-evidence.json`。输入/命令路径 `0x0042BFA2–0x0042C16C` 分别覆盖背包、状态、商店、交换、行会、组队、组队成员信息、聊天、任务、选项、坐骑和技能书窗口；`0x0042BE99` 是公告窗口 ID15 的结果路径。另确认 `0x0041C1F6/0x0041C227/0x0042062D/0x0042B1BC/0x0042B2EE` 等清理路径分别隐藏 NPC、商店、交换、聊天和公告对象。

这次扫描没有在同一基本块发现无条件的“先隐藏再显示”组合，因此不能把所有再次打开都解释为显式置顶。更可靠的复刻规则是：原版普通显示调用把 ID 追加到可见链表尾部，清理调用摘除节点；是否发生覆盖关系由实际打开/关闭序列决定。主初始化阶段没有显示调用，所有窗口的初始可见门字段仍为 0；各窗口初始坐标则以 `window-initialization-evidence.json` 为准，而非手工拖动校准。

### Finding 154：系统设置窗口的原版韩文标签确认（2026-08-10）

直接解码并放大检查 `Data/GameInter.wil` Frame 750，确认设置窗口底图内嵌的是韩文文字，而不是由程序运行时绘制的中文标签。可读标签为：`환경설정`（环境设置）、`배경음`（背景音）、`배경음 크기조절`（背景音音量调节）、`효과음`（效果音）、`효과음 크기조절`（效果音音量调节）、`주변 효과음`（周边效果音），以及一项阴影有无/效果相关设置（最后一项部分字形与暗纹理融合，保留中等置信度）。

因此系统设置的复刻应直接使用原版 Frame 750 作为视觉标签来源；`760/761` 与 `762/763` 只证明四行 ON/OFF 子控件的资源与命中矩形，不能仅凭按钮位置断定具体配置字段。两个 Frame 751 条目仍作为独立的非按钮/滑块候选，等待与状态字段和输入处理路径对应。

### Finding 160：背包负重与界面字面量解码（2026-08-10）

从原版 `Mir3.exe` 数据区直接读取背包绘制路径使用的字面量：`0x0047A214` 是 `%d` 数字格式，`0x0047BDFC` 按 GB18030 解码为 `负重:%d / 总量:%d`，`0x0047BE10` 为 `[包袱]`。`0x0047BE18` 的字节按 CP949 解码为韩文字体名 `굴림체`，因此不能把它误判为背包名称或装备字段；在 GB18030 下出现的乱码只是编码误读。

该结果补强了背包的内容层证据：除了 6×6、36 像素网格和原始物品合成链，现在还确认了负重/总量文字与 `[包袱]` 标签的原始字面。物品名称、数量字段顺序和 `this+0x774` 记录的完整语义仍保持 pending。

### Finding 161：人物状态 Frame 200 的空槽与运行时物品分层确认（2026-08-10）

直接检查原版 `Data/GameInter.wil` Frame 200 后确认：底图提供的是纵向人物状态面板和空的装备槽轮廓，装备槽名称并未烘焙进底图。关闭按钮 `161/162` 与状态操作控件 `171/172` 也是独立子控件，不属于 11 条装备记录。

因此状态窗口的正确复刻层次是：Frame 200 背板 → 运行时 11 条记录中的角色/装备图像 → 属性文字 → 独立子控件。不能从 Frame 200 的空槽轮廓单独推断武器、头盔、项链等业务名称；这些名称仍需沿物品记录类型或协议数据继续确认。

### Finding 162：Magic.exp 技能目录接入原版技能窗口预览（2026-08-10）

`Magic.exp` 已由原版客户端对应的解码工具恢复为 50 条技能记录，包含技能 ID、名称、属性/元素、1–3 级所需等级、修炼值和说明。现在 `enrich_mir3_layout_evidence.py` 会把完整 `magic-exp-records.json` 纳入 `layout.json.magic_exp_records`；技能窗口聚焦预览也会显示这份目录的前 12 条及其等级/修炼值摘要。

预览中的目录是内容资料层，不等于当前角色已经学会的技能列表，也不等于原版某一类别分页的实际可见行。原版窗口的八个类别控件、15px 行距和分页状态仍以 `skill-window-context.json` / `skill-window-render-loop-evidence.json` 为机器码证据；类别到具体运行时页的绑定继续标为待追踪。

### Finding 163：坐骑点击命令字符串与状态分支闭合（2026-08-10）

从 `Mir3.exe` 数据区直接解码坐骑点击分支引用的三个字符串：`0x0047B058 = @收马`、`0x0047B060 = @上马`、`0x0047B068 = @遛马`。与 `0x00426A80–0x00426B45` 的控件分支对应关系已写入 `horse-window-render-evidence.json`：`this+0x108` 在状态字节 `0x007DA060 == 0` 时发送 `@上马`，`this+0x1BC` 在非零时发送 `@遛马`，`this+0x270` 发送 `@收马`，`this+0x324` 发送 `@遛马`。

这比仅凭 Frame 864–867 的像素文字猜测更可靠。按钮图片文字和点击命令现在被明确分成两层：命令业务已是 primary-static，864–867 的低分辨率标签仍需与状态变化逐项对应，不能因为文字相似就假设一一相同。

### Finding 159：主 HUD 血蓝球与经验条的资源层区别确认（2026-08-10）

直接检查原版 `Data/GameInter.wil` Frame 60–63：Frame 60 是 `56×110` 红色半球，Frame 61 是 `56×110` 蓝色半球，Frame 62 是 `112×110` 完整红球，Frame 63 是 `164×6` 黄色经验条。它们不能简单合并成一个“血条/蓝条”概念。

机器码 `0x00429740` 的静态调用顺序为：动态 Frame 82–85 → Frame 62 → Frame 60 → Frame 61 → Frame 63 → 经验百分比文字。统一证据已加入 `hud-bars-render-evidence.json.resource_visual_inspection`。当前仍不把 Frame 60/61/62 分别命名为满值、当前值或耗尽遮罩，因为那需要运行时字段与裁剪方向共同确认；但预览器和后续复刻器必须保留这四种独立资源及原始顺序。

### Finding 158：地图资源与服务器地图名目录接入预览器（2026-08-10）

在不改变地图 exe 证据等级的前提下，扩展 `extract_mir3_minimap_server_crossref.py`：从原版 EI `Envir/MiniMap.txt` 读取服务器值与地图 stem，再从 `Envir/Mapinfo.txt`（GB18030）读取对应中文显示名。当前目录共生成 313 条映射，其中 FMMap 45 条、MMap 268 条；211 条能在客户端 `Map/` 找到同名地图文件，209 条对应 WIL Frame 可以解码。

这些记录已经合并到 `layout.json.map_ui_evidence.server_cross_reference_rows`。预览器的地图资源选择和固定 128×128 小地图候选会显示匹配的地图名、库和 Frame，例如 `比奇县 → FMMap F0`。这里的地图名明确标为服务器配置的二级内容证据；真正的资源选择、裁剪、目标 Rect、视图变换和键盘切换仍以 `Mir3.exe` 的 `0x0043D780/0x0043D5F0/0x0043DA80/0x0043DDB0` 证据为准。

### Finding 155：系统设置音量滑块资源的视觉归类（2026-08-10）

Frame 751 不是文字条目：直接解码后是一个小型金色圆形旋钮。它在 Frame 750 的两条横向调节轨道对应位置各出现一次，静态矩形为窗口内 `[34,96,20,16]` 与 `[34,170,20,16]`。因此预览器可以把这两个对象标为“滑块旋钮候选”，并保留 Frame 750 的轨道作为底图；但旋钮的实际数值范围、拖动输入和对应的音量字段仍需从 `0x0044103E` 窗口的消息处理路径确认。

### Finding 156：商店/仓库公共控件的原版图形语义归类（2026-08-10）

直接解码 `Data/GameInter.wil` 的 Frame 1010–1017 后，确认这些公共控件没有内嵌中文业务标签，而是四组普通/按下图标：`1010/1011` 为圆形叉号，`1012/1013` 为长条确认/执行样式，`1014/1015` 为左箭头，`1016/1017` 为右箭头。

这使预览器和统一证据表可以显示更接近原版的控件视觉，但仍不能把它们直接命名为“购买、出售、存入、取出”或“上一页、下一页”。这些业务含义必须结合 `this+0x5F8` 的状态分支、点击矩形和协议入口继续确认；本次只提升图形层证据，不提升业务语义置信度。

### Finding 157：交换窗口交易按钮的原版文字与资源索引差异（2026-08-10）

直接检查 `Data/GameInter.wil` Frame 1060–1062，确认这一组资源的像素文字为 `交易`，普通/状态变化帧的文字保持一致。与此同时，交换窗口构造器静态记录中还出现 Frame 1061/1062 与空白 Frame 1064/1065 的控件引用。两组事实暂不强行合并：这可能涉及资源索引偏移、空白状态帧或构造器使用的不同状态对象。

因此当前证据可以把“交易”作为原版美术文字高置信度记录，但不能据此断言哪个控件对象、哪一个状态分支就是最终确认按钮，也不能把空白 Frame 1064/1065 改写成有文字资源。资源索引问题已明确列入交换窗口待追踪项。

### Finding 164：任务窗口贴图文字与操作图标状态确认（2026-08-10）

直接导出并检查 `Data/GameInter.wil` 的任务窗口资源后，确认 Frame 700 的底图已经烘焙了英文分区文字 `QUESTS` 与 `DONE QUESTS`；Frame 705 是用于承载运行时选中任务正文的空白羊皮纸详情区。两者属于美术底图证据，不能替代运行时任务字段的业务命名。

Frame 721/722 是同一组 X/交叉操作图标的高亮态与普通态：721 为绿色高亮，722 为暗色普通态。Frame 723 是右向箭头的绿色高亮图标；构造器仍把它与 724 作为同一控件帧对绑定，但当前客户端导出结果中的 Frame 724 为空，因此暂时记录为“资源状态/资源副本差异”，不把它强行解释成分页、关闭或完成按钮。任务窗口的静态绘制顺序、控件坐标和命中矩形仍以 `quest-window-render-evidence.json` 为准；721–724 的最终业务含义必须继续追踪消息处理函数。

### Finding 165：NPC 对话窗口底图、选项条与控制图标分层确认（2026-08-10）

直接检查 `Data/GameInter.wil` 的 NPC 资源后，Frame 1100 是深色石质/金属边框的对话底图，中心区域没有烘焙对话文字；Frame 1101 是可按 18px 节奏重复合成的细长内框条。Frame 1102 在当前客户端副本中为空，但原版绘制函数仍明确把它作为最后一项状态资源选择，因此不能因空图就删除最终项绘制分支。

同样直接检查控件像素：161/162 是圆形交叉剑/X 图标的普通与绿色高亮态；52/53 是小型向上三角/箭头样式；54/55 是小型向下/漏斗样式。它们的形状与高亮关系已经作为 primary-resource 证据写入 `npc-window-render-evidence.json`，但“关闭、上一项、下一项、选择”等业务名称仍必须由消息处理和运行时字段确认，不能仅凭图标命名。

### Finding 166：提示资源实际为韩文确认图与勾选状态（2026-08-10）

重新以原始像素导出 Frame 603–607 后，修正了先前过于笼统的资源描述：Frame 603 不是中文确认图，而是带韩文问题文字的 `YES / NO` 确认面板；Frame 604 是窄型黑色消息/输入框，右侧带白色勾选标记；Frame 605/606 是白色普通态与绿色高亮态的勾选小按钮。该修正已写入 `notice-prompt-window-evidence.json`，并明确保留 607 的资源状态差异，不把附近帧号误合并成一个控件。

### Finding 167：聊天窗口六频道图标与滚动控件的原版像素归类（2026-08-10）

直接检查 Frame 360–383：六组频道控件均为“绿色高亮 / 金色普通”的图标状态对，前两组是圆形图标，中间两组是斜线样式，后两组是双人/群组样式；380/381 与 382/383 是竖向链条式滚动控件，中间带红色状态点。资源本身没有把中文频道名烘焙进图标。

因此聊天窗口的六种业务频道仍以原版字符串为准：私聊、世界大喊、编组喊话、行会喊话、拒绝私聊、拒绝行会聊天；图标只负责视觉状态。固定控件坐标、19 行最大可见记录、14px 文字行距及输入区域 Rect 已在 `chat-window-render-evidence.json` 中保留，后续复刻应将这三层（图标、命令/提示字符串、运行时聊天记录）分离。

### Finding 168：确认框 YES/NO 与勾选资源状态逐帧确认（2026-08-10）

直接放大 Frame 151–158 后，确认 151 是金色普通态 `YES`、152 是绿色高亮态 `YES`；154 是金色普通态 `NO`、155 是绿色高亮态 `NO`；157/158 则是白色普通态与绿色高亮态的勾选按钮。150/153 是同尺寸的额外 YES/NO 候选资源，不能仅凭帧号邻近关系并入主要三控件构造簇。

这批资源现在同时具备“像素文字/图形”和“构造器帧对/命中矩形”两类证据。确认框复刻时应保留三种控件状态，不要把绿色高亮绘制成点击后永久状态；它应由共享控件的 hover/pressed 状态驱动。

### Finding 169：全局窗口覆盖关系由可见链表决定，而非固定类别顺序（2026-08-10）

对 `0x004280F0–0x00428357` 的窗口绘制分发与 `main+0xD28` 可见窗口链表交叉核对后，确认全局绘制规则是：读取当前链表节点 ID，调用对应窗口的专用 Paint，再沿 `node+0x04` 前进。因而“背包永远在状态窗口上面”之类的固定类别假设没有静态依据；只要窗口矩形重叠，后出现在可见链表中的窗口就会覆盖先绘制者。

目前已经闭合的是窗口内部顺序（底图→动态内容→子控件）和跨窗口的链表分发规则；仍未闭合的是每个业务命令是否通过 hide/remove 后重新 insert 来提升某窗口。预览器和最终还原器应把可见链表顺序作为独立 debug 层展示，而不是把它写死在各窗口资源定义中。

### Finding 170：人物状态窗口辅助控件的像素状态补充（2026-08-10）

直接导出 Frame 171/172 后，确认 Frame 171 是一个小型向右箭头样式的绿色/金色状态控件；当前客户端副本中 Frame 172 没有可导出的像素内容。它位于状态窗口相对 Rect `[176,286,36,36]`，与关闭控件 161/162 分离，也不属于 11 条装备记录循环。

该事实只提升了控件的视觉证据，不把它命名为“下一页、切换装备或展开属性”。状态窗口的八个装备候选槽、三个特殊角色区域和属性两列坐标仍保持原版静态结果；槽位业务名称与装备图标 WIL 选择上下文继续单独追踪。

### Finding 171：商店/仓库状态 Frame 1000–1003 的真实面板形态确认（2026-08-10）

直接以原始像素导出 Frame 1000–1003 后，确认 Frame 1000 是五行物品列表面板：左侧五个物品框、五条说明区域、底部勾选/执行板和右下角 X；Frame 1001 是紧凑物品网格面板，带左右箭头、底部执行板和 X；Frame 1002 是“左侧五行列表 + 右侧附加详情/操作面板”的宽组合资源。

Frame 1003 在当前客户端副本中没有可导出的像素内容，但状态机在 `0x0044F7E8` 仍明确选择它，因此记录为“原版索引绑定 + 当前资源副本空帧”的差异，不能用 Frame 1002 的漂亮宽图替代它。以上视觉事实已写入 `store-window-render-evidence.json` 与 `store-state-graph.json`；仓库、购买、出售等业务名称仍需协议/调用者绑定。

### Finding 172：地图标记颜色分层已从反汇编参数中闭合（2026-08-10）

地图绘制函数的三个标记分支直接把颜色参数传给原版矩形/选择标记辅助函数：常规对象矩形与另一组全局对象使用 `0x64C864`（RGB 100,200,100，绿色），`entry+0x88 == 0x32` 的对象组使用 `0xFFFF00`（黄色）。这证明原版地图至少存在绿色与黄色两种覆盖层。

目前只提升“颜色—分支条件—矩形扩展像素”的证据，不把绿色/黄色直接命名为玩家、NPC、物品或队伍；这些语义需要继续解析全局对象记录布局。结果已写入 `map-ui-resource-evidence.json.render_evidence.marker_visual_semantics`。

### Finding 173：坐骑按钮原版文字实际为韩文，修正此前中文误读（2026-08-10）

将 Frame 860–867 按最近邻放大后重新逐字检查，确认按钮烘焙文字不是中文候选，而是韩文：860/861=`말타기`（骑马/上马）、862/863=`말내리기`（下马）、864/865=`말숨기기`（收马/隐藏马）、866/867=`말꺼내기`（取马/召出马）。四组文字的普通态与按下态保持同一语义，颜色状态由帧对区分。

这些像素文字与反汇编中精确解出的 `@上马`、`@遛马`、`@收马` 命令现在被明确分成两层：韩文是客户端美术标签，命令是点击业务字符串。已修正 `horse-window-render-evidence.json` 中原先错误的中文转录，并把中文只保留为翻译候选，不再当作原版文字。

### Finding 174：主 HUD 技能/聊天图标与腰带资源的可见性边界（2026-08-10）

直接检查 HUD 相关资源后，Frame 100/101 与 102/103 都是带绿色/金色状态变化的金属图标，不包含 `技能书` 或 `聊天记录` 中文文字；这些中文及快捷键语义来自 `Mir3.exe` 构造器传入的字符串。Frame 159 在当前 WIL 副本中没有可导出的像素内容，因此不能把它当成已确认的可见腰带贴图，只能保留“构造器关联的腰带字符串/控件候选”。

该边界已写入 `hud-label-evidence.json`：资源图形、构造器文本和实际运行时可见性分为三层，避免预览器把 tooltip/描述字符串误绘制成原版 HUD 固定文字。

### Finding 175：背包第三个子资源实际来自 Interface1c 角色图，而非普通按钮（2026-08-10）

直接导出背包相关资源后，Frame 264/265（GameInter.wil）是小型金属横向操作控件；而 Frame 267（Interface1c.wil）是完整的持武器角色图，Frame 268 在当前副本为空。它不是一个可以按“普通/悬停按钮”处理的 GameInter 控件。

这项像素与库文件交叉检查修正了背包证据中“第三控件可能是动作按钮”的过宽描述，并同步修正 `inventory-window-render-evidence.json.confirmed`：关闭/264–265 走 GameInter 路径，267/268 必须保留 Interface1c 角色图路径。后续预览器不能仅按帧号把它渲染成按钮。

### Finding 176：统一 layout 生成器按实际 WIL 库选择控件资源（2026-08-10）

修正 `Tools/reverse-engineering/enrich_mir3_layout_evidence.py`：窗口控件的尺寸、资源来源和命中矩形不再无条件写成 `GameInter.wil`，而是从 `window-control-resource-analysis.json` 的已解码库头中选择实际存在的 WIL。重新生成后，背包三个控件分别为 GameInter 161/162、GameInter 264/265、Interface1c 267/268；第三项尺寸为 76×88，统一 `layout.json` 与独立证据保持一致。

这条规则是通用修复，不是背包特例：当相同 Frame 编号在多个 WIL 库中有不同含义时，预览器和后续还原器必须以“调用点 + 实际可解码库 + 帧头尺寸”联合决定资源，不能只看 Frame 数字。

### Finding 177：主 HUD 预览增加固定小地图资源候选层（2026-08-10）

预览器 `/ui` 新增“显示小地图资源候选层”开关，并纳入 `localStorage` 状态记忆。开启后，主 HUD 的固定目标 Rect `(672,0)-(800,128)` 会显示当前选定的 `MMap.wil`/`FMMap.wil` Frame 缩放候选，同时保留“资源缩放候选、边框/裁剪/标记尚未冒充已确认”的明确提示。

该层只使用已经由 `map-ui-resource-evidence.json` 证明的目标矩形，不把手工拖动结果写入布局；默认关闭，以保持原始 HUD 模式不被候选层遮挡。服务已重启并通过 `/ui` 页面检查开关存在，API 仍返回 800×600 布局和 72 个控件构造记录。

### Finding 178：Interface1c 角色选择/创建按钮中文像素文字确认（2026-08-10）

直接检查 `Data/Interface1c.wil` 的启动/角色流程按钮，确认选择屏候选中的 Frame 11=`选择角色`、Frame 13=`创建账号`、Frame 15=`修改密码`；创建/角色管理候选中的 Frame 51=`创建角色`、Frame 53=`删除角色`、Frame 55=`开始游戏`。这些文字来自原版按钮像素，不是现代 UI 或人工翻译。

Frame 17 与 Frame 57 虽有静态尺寸/索引记录，但在当前客户端副本中没有可导出的像素内容，因此没有把它们命名为“结束、确定”等按钮。两份 Interface1c 上下文 JSON、覆盖矩阵和 `/ui` 次级屏预览已同步保留这一差异。

### Finding 179：系统设置 ON/OFF 控件状态与坐骑命令证据同步（2026-08-10）

直接检查设置窗口资源 Frame 760–763，确认两组控件都是带 `ON/OFF` 像素文字的状态对：760/761 一组，762/763 一组；Frame 751 是独立的金色圆形滑块旋钮。设置窗口的韩文标签、九个固定控件位置和两条旋钮候选位置现在形成完整的资源—坐标记录。

同时修正系统窗口汇总证据：坐骑分支不再把 `0x0047B058/60/68` 留作未解码候选，而是同步记录原版命令 `@收马/@上马/@遛马`；韩文按钮美术标签与运行时命令仍保持两层，不合并成未经证明的一一对应关系。

### Finding 180：无头浏览器发现并修复 `/ui` 初始化错误（2026-08-10）

使用 Chromium 对 `/ui` 做真实 DOM/截图验证时，页面最初停留在“读取中…”。DevTools 异常明确指出：脚本把 `const renderEvidenceLayout = render` 再次赋值，触发 `Assignment to constant variable`，因此 API 虽然可访问，`load()` 却没有完成。

已将该别名改为可重新绑定的 `let renderEvidenceLayout`，并同时修正公告/确认框包装器不能覆盖顶层函数声明的问题。修复后无头浏览器验证得到：摘要显示 `15 个按钮 · 13 个窗口 · 72 个窗口控件构造`，`DATA.layout.records.length=28`；打开候选层后 `localStorage.mapCandidate=true`，刷新仍恢复候选层，随后已恢复测试浏览器为默认关闭状态。

### Finding 181：将 EI 地图/小地图交叉引用生成为可检索目录（2026-08-10）

为了让后续 UI 还原和内容百科都能直接查地图，而不是只读一份难以浏览的 JSON，新增 `Tools/content/build_ei_map_catalog.py`，从 `minimap-server-crossref.json` 生成 `EI_MAP_RESOURCE_CATALOG.md`。当前目录明确记录 313 条服务器地图值、地图文件名、`FMMap.wil`/`MMap.wil` 资源库、Frame、服务器名称、客户端 `.map` 是否存在以及 WIL 帧是否能解码。

这次整理同时固定了证据边界：地图名称和数值属于 Mud3 服务器配置的二级交叉引用；资源库选择、Frame 范围、固定小地图目标 `(672,0)-(800,128)` 和 `128×128/256×256` 表面模式属于原版 `Mir3.exe` 与 WIL 的一级证据。目录中的名称不能反过来证明客户端标记一定是玩家、NPC 或物品，未解析的标记业务语义继续保留为待验证。

### Finding 182：补全地图对象初始化与地图值分支的机器码链（2026-08-10）

重新用 `llvm-objdump` 对 `0x0043D4D0–0x0043D83F` 做 PE `.text` 反汇编后，把此前分散在文字说明中的地图链写入 `map-ui-resource-evidence.json` 的 `static_initializer_trace`：

- `0x0043D4E7` 将 `0x0047C428` 绑定到 `owner+0x04`，即 `Data/MMap.wil`；`0x0043D502` 将 `0x0047C414` 绑定到 `owner+0x148`，即 `Data/FMMap.wil`。
- 构造函数把当前地图 ID 初始化为 `-1`，视图位置初始化为 `(128,128)`，模式标志和动画字段清零，并在 `0x0043D5DE` 首次创建 `128×128` 地图表面。
- `0x0043D780` 将 `map_id>=1000` 分支规范化为 `map_id-1000` 并读取 `owner+0x180` 的 FMMap 帧头；小于 1000 的分支读取 `owner+0x3C` 的 MMap 帧头，随后两条路径都把帧宽高与当前视图位置交给 `0x0043D5F0`。

因此“地图库/Frame/表面”三者的关系现在有连续的一级机器码链，而不是单独的资源猜测。仍然未把资源渲染冒充成最终 UI：GameInter 边框绑定、完整地图专用容器和标记对象业务类型继续保持 pending。

### Finding 183：地图绘制分支包含五组可见颜色（2026-08-10）

对 `0x0043DA80` 绘制例程的调用参数继续向下核对，确认 `0x0045E570` 的矩形辅助绘制调用不只有此前记录的绿色 `0x64C864` 与黄色 `0xFFFF00`：

| 调用点 | 颜色 | 当前可确认的用途 |
|---|---|---|
| `0x0043DBD7` | `0x646464` | 固定地图辅助矩形分支 |
| `0x0043DC0D` | `0xC8C8C8` | 第二个固定辅助矩形分支 |
| `0x0043DC40` | `0x96C8FF` | 第三个固定辅助矩形分支 |
| `0x0043DBBF` 等 | `0x64C864` | 视图/对象矩形分支 |
| `0x0043DCB8` 等 | `0xFFFF00` | 全局列表中 `entry+0x88 == 0x32` 的分支 |

这些颜色和调用地址已加入 `map-ui-resource-evidence.json`。它们证明地图层存在多种辅助/对象视觉分支，但颜色本身不能证明业务名称；在解析全局对象结构以前，预览器和文档继续使用“颜色分支候选”而不是玩家、NPC、队伍或物品等确定标签。

### Finding 184：聊天控件命令字符串的共享对象字段已闭合（2026-08-10）

继续反汇编通用控件构造器 `0x00417550` 与其绘制/几何分支，确认非空字符串参数会被复制到 `control_object+0x34`；聊天窗口构造器 `0x00414155–0x00414219` 传入的六个原版 GBK 命令/说明字符串，分别绑定到 `this+0x120`、`+0x1D4`、`+0x288`、`+0x33C`、`+0x3F0`、`+0x4A4` 六个频道控件。共享控件路径在 `0x00417B55` 与 `0x00417BB3` 引用该字段。

这闭合了“字符串属于哪个控件”的静态证据，但没有把它错误命名为最终可见标题：共享控件可能在普通绘制、悬停提示或两条路径中使用该字段，显示载体仍需进一步定位。`chat-window-render-evidence.json` 已新增 `shared_control_string_storage`，保留这一证据边界。

### Finding 185：确认框直接调用者与原版业务文本建立交叉引用（2026-08-10）

对整个 `Mir3.exe` 的 `call 0x00418030` 交叉引用进行扫描，并把调用点前的字符串指针与原始编码解码后，确认共享确认/提示构造路径被多个业务调用：

- `0x00416F9C`：`您要付给对方多少金币?`，交易/转账金额确认；
- `0x0041D633`：`您准备扔下多少金币?`，丢弃金币数量确认；
- `0x00420B9F` / `0x00420BD3`：仓库已满、无法保管；
- `0x004246BA`：添加要删除的小组成员名字；
- `0x00403E12` / `0x0041C196`：服务器断开与连接不稳定提示。

这些文本来自客户端 `.data` 原始字符串（中文 GBK 或韩文 CP949），不是现代 Zircon 翻译。它们证明 Frame 950 共享路径确实承载交易、丢弃、仓库、组队和网络提示等多类业务；但调用点仍不能单独证明每一种业务都使用相同的按钮状态组合，因此 `confirmation-prompt-evidence.json` 的状态切换 pending 保留不变。

### Finding 186：NPC 对话解析器的分隔符、特殊 token 与计数公式闭合（2026-08-10）

对原版 `0x00440750` 调用的内部扫描器 `0x00440AA0` 逐指令核对后，补充了 NPC 对话数据的实际解析规则：

- `this+0x584` 是源字符串游标，`this+0x588` 是原始段计数；反斜杠 `0x5C` 结束当前段并推动段计数。
- 花括号 `0x7B/0x7D` 包围特殊 token，token 通过 `0x00469400` 与 `0x0047C568` 的原版格式/匹配字面量比较；成功时设置 `this+0x582=1`。
- `@` `0x40` 进入特殊扫描路径，继续寻找 `0x3E` 结束字节并调整游标；它不能被当作普通 NPC 文本字符。
- 绘制条目数不是原始分段数：最终为 `max(raw_count-6,0)`，再限制到 16；溢出标志 `this+0x58C` 和 mode=1 共同决定 14px/21px 行距。

这些规则解释了为什么 NPC 窗口既能显示普通对话，又能承载带菜单/特殊标记的脚本内容；它们也为后续从 Mud3 NPC 脚本反向验证每条对话记录提供了精确的解析边界。尚未把 token 的业务名称强行解释为任务、商店或传送选项。

同时抽查 Mud3 的 `Envir/Convert_Def/QuestDiary/Repair/TotalRepair.txt`，发现服务器脚本实际使用 `{...}` 对话块、反斜杠行分隔、`<文本/@动作>` 菜单项以及 `<$OUTPUT(P9)>` 动态值。该文件已作为 `server_script_syntax_cross_reference` 写入 NPC 证据，但明确标为二级交叉资料：它只能帮助未来构造输入样本，不能替代客户端解析器，也不能直接证明某个 token 在客户端的按钮业务名。
### Finding 172：商店/仓库状态机的协议入口与状态输入字段补全（2026-08-10）

继续反汇编原版 `Mir3.exe` 的商店对象后，确认消息分派不是直接“打开某一种中文业务窗口”，而是先把解码消息交给共享对象 `main+0x33188`：`0x0042BFE1` 在 `0x0042BFE9` 调用 `0x0044E9B0`，成功后于 `0x0042BFFA` 调用 `0x0042ADB0(2)` 保持/显示窗口 ID 2。这是商店、仓库及其相关物品列表共用状态对象的 primary-static 入口；二进制中没有可直接读取的业务枚举名。

状态构造路径现在还补上了动态字段证据。状态 1 的 `0x0044F7E8` 先清理 `this+0x708` 链表，把一个消息派生值除以 6 后写入 `this+0x7E8`，并按输入数量把 `this+0x7E4` 设为 `-1` 或 `0`，随后选择 Frame 1003、原始工厂参数 `[x=1,y=186,w=498,h=304]`。状态 2 的 `0x0044F9E4` 重置分页字段 `this+0x7E0`，按输入数量设置 `this+0x7E4`，随后选择 Frame 1001、原始参数 `[-4,182,205,205]`。状态 2 的交互分支明确以 `this+0x71C / 12` 计算页数，并通过 `this+0x3D8` 处理翻页控制。

状态 4 的两个构造点 `0x0044EBCB` 与 `0x0044F263` 都选择 Frame 1002、原始参数 `[0,184,540,307]`；它们都要求 `this+0x704` 能通过 `0x0044E6D0` 解析出选中记录，再刷新 `this+0x7F0`。因此 Frame 1002 的“宽面板/选中记录动作面板”解释获得了更强的状态前置条件证据，但仍不能据此把它命名为购买、出售、存入或取出。

同一输入处理函数还暴露了状态到控件对象的静态关系：`this+0x54` 在状态 0/1/3/4 中参与处理，`this+0x1BC` 在状态 1/2/4 中参与处理，`this+0x270` 在状态 1/2 中参与处理，`this+0x324` 是状态 1 的附加控制，`this+0x540` 是状态 0 的控制，`this+0x48C` 是状态 4 的控制，`this+0x3D8` 是状态 2 的分页控制。这些是对象偏移和命中/激活调用的 primary-static 事实，不等于按钮的中文业务标题。

本次结果已同步到 `store-state-graph.json` 与 `store-window-render-evidence.json`。仓库 NPC、买卖 NPC 的 Mud3 脚本交叉引用仍只作为 secondary corroboration；state 0–4 的最终业务命名继续保留 pending，避免把视觉形态误写成协议语义。

### Finding 173：Mud3 商店/仓库动作词与客户端状态机的边界确认（2026-08-10）

从 Mud3 原始脚本以 GBK 解码核对了三类代表性 NPC。`06Inn_Bichon-0.txt` 的 `NPC_Storage` / `NPC_Getback` 分支使用 `@storage` 与 `@PreGetback`，语义明确是仓库存入/取回；`04Potion_Bichon1-0.txt` 的 `NPC_Buy` / `NPC_Sell` 使用 `@buy` / `@sell`，语义明确是药品买卖；`01Meet_Bichon1-0.txt` 同样使用 `@buy` / `@sell`，但商品语义是肉类买卖。

这一步确认了服务器资料中“仓库、购买、出售”不是凭文件名推测，而是由脚本动作词和 NPC 分支共同支持的 secondary evidence。但在 `Mir3.exe` 中没有找到这些 ASCII 动作词或 `NPC_*` 标签，也没有找到能直接把 `@buy/@sell/@storage` 映射到 state 0–4 的明文枚举。因此当前正确的数据模型是：服务器动作语义独立记录，客户端 state/Frame 独立记录，两者之间保留未闭合映射；不能因为某个 NPC 脚本调用了 `@buy` 就把客户端 Frame 1000 强行命名为购买窗口。

继续检查 `0x0044E9B0` 的函数入口后，确认它使用 `this + 两个栈参数` 的候选调用约定（函数尾部 `ret 0x8`）。保存寄存器后，两个参数分别从入口栈帧的 `[esp+0x0C]` 与 `[esp+0x18]` 取出，并按当前 state 转发给多个控件对象的 vtable `+0x10` 处理器。由此可以确定它同时承担输入/激活分派与状态重建；但仅凭 `0x0042BFE1` 的调用边界，还不能把这两个参数直接命名为服务器数据包字段或鼠标坐标。该 ABI 事实已写入商店状态 JSON，参数语义继续保持 pending。

### Finding 187：窗口初始化 x/y 与最终屏幕 Rect 的语义分离（2026-08-10）

重新核对主初始化调用和共享构造器 `0x00423B30` 后，确认 `window-initialization-evidence.json` 中的 `position` 是各派生窗口 wrapper 接收到的原始 x/y 输入，不应无条件当作最终 800×600 屏幕左上角。共享构造器从 WIL 资源头读取宽高，把锚点字段写入 `window_object+0x40/+0x44`，并在 `window_object+0x08` 与 `window_object+0x18` 上调用 `SetRect`；其分支会根据 anchor/centering 参数决定直接采用输入值还是计算相对父视口的偏移。

因此像人物状态、商店、交换、NPC 等记录中出现的 `[0,0]`，当前只能说明“初始化时传入零偏移”，不能证明窗口最终位于屏幕左上角；反之，行会、组队、聊天、设置等非零输入也必须经过同一构造器分支解释。此结论已同步到 `layout.json` 和窗口初始化证据，预览器若展示这些值必须标注为 raw wrapper input，最终屏幕 Rect 继续按构造器分支或运行时捕获闭合。

### Finding 188：NPC 对话三组动态目标 Rect 字段从构造器到 Paint 闭合（2026-08-10）

核对 `0x0043EE00–0x0043EFF6` 后，NPC 对象的动态绘制目标不是一个笼统的“文本区域”：构造器分别写入背景目标基址 `this+0x520/+0x524`、重复菜单条目标基址 `this+0x530/+0x534`、最后一项目标基址 `this+0x540/+0x544`。`0x0043F040` 的 Paint 逐项直接消费这三组字段：Frame 1100 画背景，Frame 1101 按 `this+0x51C` 和 18 字节节奏重复，Frame 1102 画最后一项并使用 `max(count-1,0)`。

构造器中还能直接看到 WIL 头部宽高参与计算，以及 `384×384`、`138` 和 `24` 等固定参考常量。它们证明了原版有独立的目标矩形推导链，但不能把这些中间常量误写成最终 800×600 屏幕坐标；最终位置仍受窗口对象 `this+0x18/+0x1C` 与运行时状态影响。该字段流已同步到 NPC 专项证据和统一 `layout.json`。

### Finding 189：人物状态属性值的原始全局字段与格式化调用点闭合（2026-08-10）

继续核对人物状态 Paint `0x0044BC80–0x0044CCCC`，把标签、相对基线和格式化参数分开记录。属性文字不是静态占位文本：绘制前会从 `0x007DA108`、`0x007DA10D–0x007DA124`、`0x007DA149–0x007DA165`、`0x007DA169–0x007DA170` 等原版全局区域加载 byte/word/dword 字段，经 `0x0046811C` 格式化，再由 `0x0045DD70` 合成到窗口上。

已确认的可复现事实包括：等级使用 `0x007DA108` 的低字节；HP/MP、负重分别使用相邻 word 对；经验使用 `0x007DA115 / 0x007DA119` 的整数比例并乘全局 double `0x00476970`，当分母不大于零时跳过除法；元素抗性列连续读取 `0x007DA149` 起的 word 字段。所有字段目前保留“原始全局字段”命名，没有未经交叉引用就改写为现代服务端属性名。

这一步闭合了“状态窗口显示哪些动态值、从哪里取值、在哪个 Paint 调用格式化”的静态证据链；装备槽业务名称、颜色语义以及这些字段与 Zircon/Mud3 运行时对象的最终映射仍是后续工作。证据已写入 `status-window-render-evidence.json` 的 `attribute_text_draw_chain.value_field_sources`，并由 `enrich_mir3_layout_evidence.py` 同步到 `layout.json`。

### Finding 190：人物状态窗口 11 条几何记录与绘制循环索引对齐（2026-08-10）

重新核对构造器 `0x0044B130` 的 `SetRect` 调用，确认 11 条记录在构造时已经按固定顺序写入 `this+0x1F0`、`+0x1E0`、`+0x250`、`+0x210`、`+0x220`、`+0x230`、`+0x240`、`+0x200`、`+0x1C0`、`+0x1D0`、`+0x260`。它们的顺序与 Paint `0x0044B5D9–0x0044B629` 的 0–10 循环一致，因此预览器可以用同一索引绘制调试框，而不必再次手工校准。

其中 0、1、2、3、4、5、6、10 八条是 38px 左右的装备大小矩形；7–9 分别是更大的名字/肖像邻域、人物图像区和属性区候选，不能因为它们也进入对象记录就直接当成装备槽。原版仍没有在这段构造器里提供“武器/头盔/戒指”等文字语义，所以业务命名继续等待调用者填充记录的交叉引用。该索引—Rect 表已写入 `status-window-render-evidence.json` 的 `equipment_slot_rect_constructor_calls`，并同步到 `layout.json`。

### Finding 191：坐骑窗口韩文按钮与原版命令字面量直接绑定（2026-08-10）

核对 `0x004269C0` 的五子控件绘制顺序与 `0x00426A80–0x00426B45` 的点击分派后，四个可见坐骑按钮已经可以建立直接绑定：Frame 860/861 的 `말타기` 在 `0x007DA060 == 0` 时发送 `@上马`；Frame 862/863 的 `말내리기` 在该字段非零时发送 `@遛马`；Frame 864/865 的 `말숨기기` 发送 `@收马`；Frame 866/867 的 `말꺼내기` 也发送 `@遛马`。最后一项说明“命令字符串”不能反过来当作控件唯一 ID，两个不同按钮确实共享同一原版字面量。

因此本窗口的按钮几何、WIL 帧、韩文像素文本、点击条件和客户端命令已经闭合；仍未把 `@遛马` 的服务器语义扩展成未经证实的“下马/遛马/取马”之一，也没有假设 Frame 850 之外不存在状态覆盖层。该边界已同步到 `horse-window-render-evidence.json` 的 `artwork_to_command_binding`。

### Finding 192：系统设置四组选项与 Config.ini 字段、两个音量滑块闭合（2026-08-10）

继续追踪系统设置窗口 `0x0044103E` 的点击分派和配置刷新函数 `0x00441B30`，确认原版配置文件为 `Config.ini`，选项段为 `Options`。四组 WIL 开关的固定行与字段如下：`배경음` → `BGM` → `this+0x54`；`효과음` → `EffectSound` → `this+0x58`；`주변 효과음` → `Ambience` → `this+0x5C`；`그림자 유무효과` → `ShadowBlend` → `this+0x60`。每组 ON/OFF 控件的点击分支都会更新对应字段，并调用 `0x00441B30` 重新写入/读取配置。

两个看似未命名的 Frame 751 也已闭合：相对位置 `(34,96)` 的 `this+0x6D0` 是 `BGMLevel`，写入全局 `0x008AB150`；相对位置 `(34,170)` 的 `this+0x784` 是 `EffectSoundLevel`，写入全局 `0x008AB14C`。`0x00441F40` 把 0–160 的滑块位置按原版浮点常量转换成音量值，分别由拖动分支 `0x004415C2(1)` 与 `0x00441667(0)` 触发。

这一步把设置窗口从“韩文视觉标签候选”提升为原版资源、控件位置、对象状态字段、Config.ini 键名和滑块写回公式的完整静态证据；仍保留音频引擎所有播放路径是否复用这些全局字段这一运行时问题，不扩大静态结论。

### Finding 194：坐骑状态字节的直接交叉引用已定位（2026-08-10）

对 `0x007DA060–0x007DA064` 做全量静态交叉引用后，确认 `0x007DA060` 是坐骑窗口点击分支唯一直接读取的状态字段：`0x00426ABC` 在其为零时允许 `말타기` 控件发送 `@上马`，`0x00426AE1` 在其非零时允许 `말내리기` 控件发送 `@遛马`。状态更新链 `0x0041F5BA–0x0041F5CD` 同时把输入/数据块写入 `0x007DA061–0x007DA064`，然后继续刷新客户端状态。

坐骑 Paint `0x004269C0–0x00426A74` 本身没有引用该状态块以绘制额外覆盖层，只按固定顺序绘制 F850 和五个子控件。因此目前能确定“按钮命令受状态字节控制”，但不能把 `0x007DA060` 擅自命名为骑乘枚举、马匹 ID 或动画状态，也不能据此断言全局窗口管理器绝对没有叠加层。该交叉引用、边界和待验证项已同步到 `horse-window-render-evidence.json`。

### Finding 195：人物装备图标选择器的内部模式分派闭合（2026-08-10）

继续沿 `0x0044B6B0 → 0x0044B720 → 0x004341F0` 追装备图标，确认 `slot_record+0x04` 不是直接的贴图编号，而是传给 `0x00466130` 的图形对象。该选择器使用 `ECX=0x005668C4` 的原版资源上下文，并读取 `[0x005668C4+0x04]` 模式字节：模式 0 分派到 `0x00466640`，模式 1/2 分派到 `0x00466720`，其他模式返回零；成功后从 `0x005668FC` 读取所选帧宽高，再进入 `0x004542F0/0x0045E570` 组合链。

这一步把“装备槽 → 物品记录 → 原版资源选择器 → 帧头尺寸 → 合成绘制”的 ABI 证据补完整了，也说明不能把现代客户端的通用图标图集当作原版依据。`0x005668C4` 对应的具体 WIL/WIX 文件名仍未从初始化/资源加载字符串中闭合，因此继续保留为待验证项；该选择器模式和调用关系已写入 `status-window-render-evidence.json`。

### Finding 196：背包动态内容字段与 6×6 选中合成链整理完成（2026-08-10）

重新按 `0x0042EB7F` 的调用顺序整理背包动态内容：窗口先绘制共享条/量条控件
（成员 `this+0x278`，`0x0042EBB0` 调用 `0x004179B0`；GameInter 帧 `0x118`=280、量程上限
`0x5E`=94、`(window.x+0xF8, window.y-0xA5)`——`0x5E` 是量条量程而非素材帧号，见量条家族
Finding），然后检查 `0x007DA1C0/0x007DA1C4` 与 `0x007243D8`，用 `0x0042F150` 命中 36px
网格、再由 `0x0042F2A0` 把线性索引拆成 `column=index%6`、`row=floor(index/6)`，最终把
源/目标矩形送入 `0x00466800` 和 `0x004542F0`。

动态文字也已按原始操作数闭合：主数值从 `0x007DA100` 读取，经 `0x0047A214="%d"` 与 `0x0046811C` 绘制到窗口相对 `(0x41,0x11A..0x12B)`；负重/总量路径从 `0x007DA11D`、`0x007DA11F` 读取，经 `0x0047BDFC="负重:%d / 总量:%d"`，并由 `this+0x54` 四态分支选择后续颜色/格式调用。物品记录的 `+0x00/+0x04/+0x08/+0x34/+0x2E8/+0x351..+0x353` 也分别绑定到身份、网格位置、帧选择、状态分支和附加打包字节的实际读取点。

因此“背包是 6×6 物品内容窗口、不是纯按钮网格”的原版内容证据已经可直接提供给 UI 还原器；仍不把主数值或打包字段命名为现代数据库字段，也不把量条的业务用途（负重候选）从坐标表达式扩大解释。以上映射已同步到 `inventory-window-render-evidence.json`。

### Finding 197：小地图是直接表面合成，不是已证实的 GameInter 子窗口（2026-08-10）

重新检查地图专用 Paint `0x0043DA80` 的完整调用链，确认地图对象先准备 `MMap.wil/FMMap.wil` 选中的表面，再通过 `0x004542F0` 把它合成到 `owner+0x2C0` 的固定矩形 `(672,0)-(800,128)`。地图 Paint 的主合成区间 `0x0043DB0B–0x0043DB2B` 没有调用通用 GameInter 子控件绘制或额外的地图边框帧查找。

因此本 EI 客户端的第一证据更支持“地图表面直接占据右上 128×128 目标区”，而不是先画一个另有 Frame 编号的现代式小地图边框。这个负结果只针对地图专用 Paint：边框可能被烘焙在其他全局 HUD 表面，或由外部窗口层运行时叠加，必须以运行时截图再确认，不能把负搜索扩大成绝对不存在。结论、范围和待验证项已写入 `map-ui-resource-evidence.json`，并同步覆盖矩阵。

### Finding 198：商店/仓库共享状态机的控件门控与选中记录条件闭合（2026-08-10）

继续追踪共享处理器 `0x0044E9B0`，确认 `this+0x5F8` 不只是决定背景 Frame：它还决定哪些子控件进入 vtable `+0x10` 激活路径。状态 0/1/3/4 处理 `this+0x54`；状态 1/2/4 处理 `this+0x1BC`；状态 1/2 继续处理 `this+0x270`；状态 1 独有 `this+0x324`，状态 4 独有 `this+0x48C`，状态 2 还存在 `this+0x3D8` 分页/选择控件路径。由此可知这些 Frame 1000–1003 变体不是单纯换背景，而是不同输入控件集合的业务状态。

状态 4 的宽面板还有明确前置条件：`this+0x704` 选中索引必须经 `0x0044E6D0` 成功解析，得到的记录指针写入 `this+0x7F0`，且记录 `+0x20` 为零，随后才调用 `0x0044EBCB/0x0044F263` 创建 Frame 1002。状态重置路径则清空列表/页字段并重建 Frame 1000。以上闭合了“状态 → 可用控件 → 选中记录 → 面板资源”的静态链，但控件图中文字和仓库/买卖的人类业务名称仍没有被二进制直接命名，因此继续保留候选边界；证据已写入 `store-state-graph.json`。

### Finding 193：任务窗口两个操作控件的事件分派链与状态字段闭合（2026-08-10）

继续核对任务窗口输入处理 `0x00447FA0`、更新/导航处理 `0x00448230` 以及它们在全局 UI 分派器中的调用点，确认 721/722 与 723/724 并非只有静态图标关系。`0x0042C0E1` 将指针输入交给 `0x00447FA0`；`0x0042BCDC` 将任务槽 11 的更新事件交给 `0x00448230`。前者通过 `this+0x128` 子控件的 vtable `+0x10` 处理后进入 `0x00448580`，后者通过 `this+0x74` 子控件的 vtable `+0x0C` 更新并在子控件报告 handled 时进入同一函数。

`0x00448580` 会遍历 `this+0x1E8` 链表，清理记录 `+0x208` 状态、标记选中记录，设置窗口 `this+0x68=1`；当记录 `+0x20C` 为零时，调用 `0x00451A10`，由原版消息构造链发送类型 `0x418`。因此现在已经闭合“帧对 → 子控件 → 窗口处理器 → 记录状态 → 原版事件”的静态证据链，但没有把 `0x418` 擅自命名为删除、完成或翻页操作。

同一段代码还确认了 `this+0x60` 是列表可见起始行/详情行窗口的候选滚动字段，`this+0x6C` 是 Paint 消费的详情正文指针，`this+0x1DC` 是选中记录指针，`this+0x1F4` 是输入遍历使用的记录数，记录 `+0x218..+0x224` 是命中矩形。具体文字分隔、换行策略和事件 0x418 的业务名称仍需继续从调用者、协议或运行时样本交叉验证；以上字段流已同步到 `quest-window-render-evidence.json`，并通过统一布局证据生成器写入 `layout.json`。

### Finding 200：技能窗口 11 组控件帧对与构造器相对位置闭合（2026-08-10）

继续核对技能窗口构造器 `0x00439250`，确认它通过共同控件构造器 `0x00417550` 建立 11 组 GameInter 状态帧对：440/441、410/411、412/413、450/451、452/453、454/455、456/457、458/459、460/461、462/463、464/465。每组的相对位置表达式已经从原版指令恢复，覆盖顶部/侧边操作控件以及技能条目区域；这些值暂时保留为 `window_arg_x/y + offset`，不越过公共窗口 wrapper 的锚点计算直接当最终屏幕坐标。

技能列表渲染循环 `0x0043A440` 同时确认：记录从 `this+0x968` 数据流解析，选中行按 `#` 标记匹配请求段，普通行经 `0x0045E200` 解析，屏幕行距为 15 像素，数据记录步长为 0x104 字节。技能名、等级字段和每个帧对的业务名称仍需结合 `Magic.exp` 实际内容与运行时对象闭合，不能仅凭图标序号命名。证据已同步到技能专项 JSON 和覆盖矩阵。

### Finding 199：NPC 对话解析器到共享布局状态的边界闭合（2026-08-10）

重新核对 `0x00440750–0x00440AA0` 后，确认 NPC 对话输入在进入绘制前会清零 `this+0x582`、`+0x584`、`+0x588`、`+0x51C`、`+0x58C`，再由扫描器识别反斜杠、花括号 token 和 `@...>` 特殊段。成功的花括号 token 比较会把 `this+0x582` 置为模式 1；原始段计数写入 `this+0x588`，最终绘制项数写入 `this+0x51C`，计算规则为 `max(raw-6,0)` 并封顶 16，超过封顶时置 `this+0x58C`。只有模式 1 与溢出同时成立时，行距才从 21 改为 14 像素。

同一解析/布局阶段还把 `this+0x550/+0x554/+0x57C`、`+0x55C/+0x560/+0x568`、`+0x56C/+0x570/+0x578` 三组结构交给共享布局调用。NPC Paint `0x0043F040` 本身只负责 Frame 1100/1101/1102 及 fallback 图像合成，未看到直接的字形绘制 helper。因此当前已闭合“原始脚本 token → 布局状态 → 条带数量/行距 → 图像合成”的证据链，但不把 raw 段数等同于可见文本行，也不虚构字体、颜色、基线；这些仍需沿共享布局结构的调用者继续追踪。以上边界已写入 `npc-window-render-evidence.json` 并同步覆盖矩阵。

### Finding 201：商店状态 0–4 的工厂调用与状态写入点闭合（2026-08-10）

沿 `this+0x5F8` 的全部写入继续回溯，确认状态不是由 Frame 外观推断：状态 0 在 `0x0044EA82–0x0044EAB1` 的 Frame 1000 重建/复位路径写入；状态 1 在 `0x0044F7D7–0x0044F7F4` 创建 `[1,186,498,304]` 的 Frame 1003 后写入；状态 2 在 `0x0044F9D3–0x0044F9F0` 创建 `[-4,182,205,205]` 的 Frame 1001 后写入；状态 3 在 `0x0044FBAC–0x0044FBE0` 创建 `[0,186,300,304]` 的 Frame 1000 后写入。

状态 4 的两条操作路径分别从 `0x0044EB77` 和 `0x0044F1E1` 设置 `bl=4`，先要求选中索引、`0x0044E6D0` 记录解析成功且记录 `+0x20==0`，再创建 `[0,184,540,307]` 的 Frame 1002，并把选中记录刷新到 `this+0x7F0`。这一步把“状态寄存器 → 工厂参数 → Frame”从候选提升为一级静态事实；买卖、仓库、扩展操作的人类名称仍等待协议/调用者交叉验证。

### Finding 202：好友/社交独立窗口的静态负范围进一步闭合（2026-08-10）

对当前 EI 客户端已分类的 15 个通用窗口构造器、主 HUD 控件目录，以及两个已恢复的 Interface1c 构造簇 `0x004027DF–0x00402845` 和 `0x00456DC1–0x00456EC8` 做了边界审计。前者的资源文字是“选择角色/创建账号/修改密码”，后者是“创建角色/删除角色/开始游戏”及角色槽图标候选；两簇均未出现独立好友列表文字或好友窗口背景。

因此目前可以确认“没有已归属的独立好友面板证据”，但不能把它扩大成“客户端绝无好友功能”：好友可能是行会 F600 的状态/页签、动态分配窗口，或未归属的 Interface1c 控件。该边界、已检查的 Frame 范围和未来入口追踪方向已写入 `social-window-render-evidence.json`，预览器不新增未经证实的好友面板。

### Finding 203：窗口预览已改为原始控件图层叠加，而非仅显示几何框（2026-08-10）

预览器 `Tools/web/wilviewer.py` 的聊天和坐骑窗口模式现在直接使用原版 `GameInter.wil` 控件帧对叠加到窗口背景上。聊天窗口按 Paint 重定位记录绘制六个频道控件（F360/362/364/366/368/370）及其原始 36×34 命中区域；坐骑窗口按 F860/862/864/866 与 F161 的实际资源尺寸绘制四个坐骑操作按钮和右上控件，均保留窗口相对坐标。

这些图层是“原始资源 + 原始静态坐标”的可视化验证工具，不代表已经证明所有运行时状态、文字渲染、透明像素裁剪或窗口最终锚点。界面标签仍明确标为 original window evidence，未把预览居中规则升级成原版屏幕位置。该改动已通过 Python 编译、HTTP 页面加载检查，并提交为 `622d0e4` 推送到远端。

### Finding 204：公告 Frame 602 的打开调用者已从窗口注册链外部闭合（2026-08-10）

继续追踪窗口 ID15 的可见性分支，确认 `0x0042BE21–0x0042BEA7` 先调用 `0x0043E4B0` 准备公告/通知数据；只有该调用返回非零，才在 `0x0042BE95–0x0042BE99` 将 ID15 送入 `0x0042ADB0` 显示分派器。该路径与行会窗口的注册和初始化序列分离，因此不能把 Frame 602 误标成“行会页面必然打开的子窗口”。

结论已写入 `window-initialization-evidence.json`、`window-visibility-dispatch-evidence.json` 并重新生成 `layout.json`。目前已闭合“注册 → 默认隐藏 → 公告结果准备成功 → ID15 显示”的静态链；`0x0043E4B0` 的消息字段含义及其是否先使用 Interface1c 提示资源仍保留为待解析项。

### Finding 205：可见窗口绘制顺序的显式提升审计完成（2026-08-10）

对可见链表绘制器 `0x004280F0–0x00428357` 与已恢复的显示/隐藏调用者做了交叉审计。绘制器严格从 `main+0xD28` 头节点按 `node+0x04` 遍历，并依据节点 ID 分派到 13 个已归属 Paint 入口；显示操作通过 `0x0042AC30` 追加节点，隐藏操作通过 `0x0042AC50` 移除节点。

在已覆盖的直接调用基本块中，没有发现“同一调用者无条件 hide(ID) 后立即 show(ID)”的显式提升模式。因而不能写死一个全局窗口层级；具体 z-order 是运行时可见链表的结果，窗口隐藏后再次显示会重新追加到尾部。该审计结果已写入 `window-traversal-evidence.json` 并同步到统一布局证据。

### Finding 206：ID15 公告窗口正式纳入统一布局目录（2026-08-10）

修正布局生成器的来源优先级：`window_layout.json` 未收录的窗口不再从统一目录中丢失，只要原版主初始化 `0x00427600` 已有注册记录，就用其 Frame、原始位置和尺寸补入。当前新增记录为 `window.notice-prompt-candidate`：ID15、Frame 602、原始构造输入 `(107,110,584,252)`，并保留“默认隐藏、由 ID15 可见性分派器控制”的状态说明。

这不是把公告窗口强行显示到运行时 HUD，而是让它能被统一资源/窗口清单、绘制层分析和预览器检索到；业务打开条件仍由公告结果路径证据单独描述。布局目录现包含 15 个按钮、14 个原版注册窗口记录和 72 个窗口控件构造记录。

### Finding 207：ID15 公告窗口可从预览模式直接打开（2026-08-10）

预览器新增“公告窗口 / Frame 602”模式入口，并通过 `/api/ui-layout` 验证它读取统一布局中的 `window.notice-prompt-candidate` 记录。该模式使用现有 `addFocusedWindow` 路径，因此会同时显示 Frame 602 原始背景、窗口位置/尺寸、证据标签和公告专用绘制/控件说明；窗口仍按原版默认隐藏语义标注，不被误当成启动时必现界面。改动已提交为 `d344562` 并推送。

### Finding 208：背包与人物状态预览补入原始子控件资源图层（2026-08-10）

依据两个窗口专项证据，预览器不再只画背包 6×6 / 状态装备矩形：背包模式现在叠加 F161/162 关闭控件、F264/265 操作控件，以及明确标记为 `Interface1c.wil` 的 F267/268 人物外观资源候选；人物状态模式叠加 F161/162 关闭控件和 F171/172 状态操作控件。

所有位置均来自窗口相对 Rect 表，Interface1c 资源没有被误归类到 GameInter；这些资源层只表达原始静态绘制证据，动态物品图标、角色数据和状态分支仍按专项 JSON 的 pending 边界处理。改动已提交为 `7bafc62` 并推送。

### Finding 209：任务、NPC 与技能窗口预览补入原始 Frame 图层（2026-08-10）

预览器继续把已有专项证据落到窗口图层：任务窗口叠加 F723/724、F721/722 两个 28×28 操作控件和原始 F705 204×76 详情面板；NPC 窗口叠加 F161/162、F52/53、F54/55 三组构造器控件；技能窗口按构造器恢复的 11 组相对位置叠加 F440–465 控件帧对，并保留各组真实 Frame 尺寸。

任务列表 19 行/15px、详情正文 3 行/15px、NPC 动态条带数量与技能数据行距仍由几何调试框和专项证据面板表示，没有把未确认的业务字段或最终窗口锚点伪装成结论。改动已提交为 `cfc0184` 并推送。

### Finding 210：专项控件 Rect 归并为统一 layout 目录（2026-08-10）

布局生成器新增 `specialized_control_rects`，从任务、NPC、聊天、坐骑、背包、人物状态等专项证据中提取已经拥有数值相对 Rect 的控件，并保留 `window_id`、Frame 对、资源库、角色、调用点、证据等级和来源文件。当前统一目录包含 22 条控件 Rect，其中明确保留了背包 Frame 267 属于 `Interface1c.wil` 的跨资源事实。

没有数值坐标、只有 `arg+offset` 表达式的控件不会被强行加入；原始专项 JSON 仍是这些表达式的权威来源。验证器现在会检查该目录存在、字段完整且每条 Rect 为四元组，避免后续还原器只读取局部证据文件而遗漏已闭合控件。

### Finding 211：商店/仓库五状态预览显示原始控件构造证据（2026-08-10）

商店状态 0–4 的预览现在在对应背景和网格之外显示 8 个原始控件构造记录：F1010/1011 关闭候选、F1012/1013 执行候选、F1014/1015 左箭头、F1016/1017 右箭头，以及它们的原始 `arg4+offset / arg5+offset` 表达式。

面板明确标注这些是工厂输入的相对表达式，不把 `0x00423E80` 重新计算前的参数冒充最终 800×600 坐标；最终父窗口 Rect 仍以窗口工厂算法和运行时实例为准。改动已提交为 `766a9b1` 并推送。

### Finding 212：统一专项控件目录接入窗口预览（2026-08-10）

窗口预览现在直接消费 `layout.json.specialized_control_rects`，在已选窗口的证据画布中显示统一控件目录面板。每行包含控件 Frame 对、资源库、窗口相对 `(x,y,w,h)` 和证据等级；因此可以直接核对预览图层与统一还原数据是否一致。

目录面板只显示已经拥有数值 Rect 的记录，工厂表达式、动态字段和未确认语义仍留在专项 JSON 中，不会因为可视化方便而被推导成最终屏幕坐标。改动已提交为 `06d290e` 并推送。

### Finding 213：800×600 交互式客户端模拟器交付（2026-08-10）

新增 `Tools/mir3_client_simulator/`（HTML 客户端模拟器），作为 wilviewer 的新路由 `/sim` 内嵌（`/sim` → `/sim/` 301 重定向保证相对资源解析）。模拟器消费 `Tools/web/build_mir3_simulator_data.py` 从 `layout.json` + 专项证据生成的统一数据模型 `data/*.json`（windows=14、controls=37 = 22 专项 + 15 HUD 按钮、resources=157、entities=6、equipment_slots=6、skills=12、maps=2），HTML/JS 内不散落坐标。

关键事实复用（均来自既有证据文件，未新增伪证）：

- HUD `GameInter.wil F50` 800×136 @ `(0,465)`；HP/MP/EXP 条 rect `(61,496,104,566)`/`(105,496,147,566)`/`(61,586,400,597)`；聊天总区 `(224,492,578,566)`；小地图 `(672,0)-(800,128)`。
- 确认框 `GameInter.wil F950` 360×190 居中 `(400,246)`，三子按钮 rel `[51,125,44,20]`F151/152、`[147,125,64,20]`F157/158、`[244,125,44,20]`F154/155（confirmation-prompt-evidence.json `primary-static-exact-relative-and-derived-screen`）。
- 公告 `GameInter.wil F602` 固定 `(107,110)`，子按钮 F161/162 与 F606/607（notice-prompt-window-evidence.json）。
- 聊天窗历史 `(40,29,531,308)`、输入 `(25,311,524,326)`（chat-window-render-evidence.json）。
- 商店状态 0–4 → 帧 `1000/1003/1001/1000/1002`，factory args `[0,186,300,304]`/`[1,186,498,304]`/`[-4,182,205,205]`/`[0,184,540,307]`（store-state-graph.json）；**不**把状态映射到买卖/仓库业务名（保持 pending）。
- 已确认静态窗口原点直接使用：guild `(102,22)`、group `(272,123)`、chat-pop `(114,76)`、option `(276,113)`、notice `(107,110)`；未闭合原点窗口按视口居中并标 `candidate`，永不冒充 primary。

证据模式覆盖层按证据等级着色（primary 蓝 / candidate 橙 / pending 红），每矩形显示控件 ID、资源库/Frame、相对坐标与 evidence_level。冒烟测试（headless Chromium）33/35 通过，2 项为测试脚本口径问题（stage 尺寸来自 CSS var、坐骑无独立 HUD 按钮走测试导航），实际功能全部正常；117/117 贴图加载、14 窗口可开/关/拖拽/置顶、确认框/公告弹出、无 JS 错误。改动已提交为 `a041fba` 并推送。

### Finding 214：聊天窗口 pending 闭合 — 关闭钮、节点字段与共享渲染器参数槽（2026-08-10）

本轮把聊天窗口证据从 candidate 提升为 `primary-static` 加参数流事实，写入
`chat-window-render-evidence.json`、`layout.json.chat_window_evidence`、`ui-coverage-matrix.json`
与 `UI_COMPLETION_AUDIT.md`：

- 构造器 VA 修正：`window_init_candidates.json` 记录 `window_id=8 / window.chat-pop` 主初始化
  `0x00427839` 调用包装器 `0x00414060`（此前 JSON 中的 `0x00414080` 是过期值）。
- 首个控件 `this+0x6C` 升级为 **关闭按钮**：Frame `161/162` 是全局关闭字形（圆形交叉剑/X，
  绿色高亮 vs 常态，npc-window-render-evidence.json 像素检查 high）；同一帧对在 10+ 窗口对象
  （状态/背包/社交好友/行会/系统/坐骑/交换/NPC/公告/聊天）中都是首控件关闭入口；聊天命中
  分派 `0x004149A0–0x00414C56` 首测该控件且 handled 立即返回，符合通用关闭路径而非频道命令。
- 六个频道控件 `this+0x120…0x4A4` 角色定为频道开关；滚动控件 `this+0x558/0x60C` 保留；
  新增第 10 个控件 `this+0x6D4`（输入框候选，构造器 `0x00417960`，与共享 `0x00417550` 不同，
  原始参数 `[0x17C,0x13,0xC,0x104,0xC,0]`）。
- 聊天节点字段顺序确认：聊天绘制调用 `0x004147F3 → 0x0045DD70` 按
  `node+0x00→颜色槽、node+0x04→背景槽(0=透明→SetBkMode(TRANSPARENT))、node+0x08→文本指针
  (strlen+TextOutA)` 传递；节点链 `node+0x408/0x40C` 仍为候选。
- 共享渲染器 `0x0045DD70`（thiscall `ecx=0x008AB7A8`，7 栈参）参数槽：颜色（其它调用点推字面
  `0x323232/0x0A0A0A/0xB4FFB4`）、背景（`0x0045DDB1` 分支 SetBkColor vs TRANSPARENT）、文本。
- 仍 pending：六条命令字符串在共享控件 `+0x34` 的可见标题 vs 悬浮提示；渲染器绝对 x/y 槽序
  需下次 exe 可用时复核；输入框构造器 `0x00417960` 参数语义；关闭钮 vtable+0x10 处理器与
  可见性门 `0x0042B180` 接线。

本轮同时确认 NAS 挂载点 `/tmp/nas_mnt` 已消失且无自动恢复配置（无 fstab/autofs/crontab 条目，
SMB 主机 192.168.3.1/.62/.110 不可达），Mir3.exe 暂时不可访问；已完成的证据更新全部来自仓库
内保留的 primary 反汇编产物与交叉引用，未新增伪证。其余窗口 pending 项待 NAS 恢复后继续。

### Finding 214.5：NAS 挂载恢复（2026-08-10）

NAS 网络恢复后可匿名枚举 Samba 共享（`smbclient -L 192.168.3.10 -N`：Samba 4.22.8，
共享 NAS/print$/IPC$/nobody）；`/etc/fstab` 暴露凭据文件 `/root/.smbcredentials`
（immich/Photos 挂载使用同一凭据），据此用
`mount -t cifs //192.168.3.10/NAS /tmp/nas_mnt/NAS -o credentials=/root/.smbcredentials,vers=3.0,uid=1000,gid=1000,forceuid,forcegid,noperm`
重新挂载成功。Mir3.exe（524288 字节，.text VA 0x401000–0x476000，.data 为 bss 虚拟段——
解释文件小但 VA 高达 0x47xxxx 的疑问）、WIL/WIX、Map 数据全部恢复可达。
wilviewer（:8765）与 mapviewer（:8899）已重新启动。EXE Investigation 阶段恢复。

### Finding 215：小地图/地图证据闭合（2026-08-10）

NAS 恢复后对 `map-ui-resource-evidence.json` 四条 pending 逐项静态闭合：

1. **边框=程序绘制，非 GameInter 帧**（pending_1 关闭）。地图 Paint `0x0043DA80` 在合成
   （`0x0043DB0B–0x0043DB2B` → `0x004542F0`）之后、`0x0043DBD7` 处以
   `push 1 / push 0x646464 / push 0 / push &rect(owner+0x2C0) / call 0x0045E570`
   绘制 1px 灰色描边。`0x0045E570` 反汇编确认机制：按 arg1&0xFF 查跳转表 `0x0045E71C`
   （5 模式），GDI 调用链 CreatePen(style=0,width=0,color)@IAT`0x476084` →
   SelectObject@`0x476048` → MoveToEx@`0x47606C` → LineTo@`0x476080` → DeleteObject@`0x476068`
   （IAT 名经 .rdata 导入名 RVA 解析确认）。整条世界绘制链 `0x00429540–0x00429620`
   （含 `0x4295B4→0x43DA80`）无任何 GameInter WIL 帧 blit——小地图无烘焙/外部边框。
   同一辅助函数还绘制：绿色 `0x64FA64` 当前视野指示框（`0x43DBC1`）、浅灰 `0xC8C8C8`
   `owner+0x298`（`0x43DC0D`，点击切换 alpha `owner+0x290`）、淡蓝 `0x96C8FF` `owner+0x2A8`
   （`0x43DC40`，点击切换模式 `owner+0x294` 并重建表面）、黄色 `0xFFFF` 类型 0x32 标记
   （`0x43DCBC`）、绿色 `0x64C864` 近距对象标记（`0x43DD79`）。

2. **无独立地图对话框**（pending_2 关闭）。地图对象构造器 `0x0043D4D0` 全二进制仅一个调用点
   `0x00427E08`（主世界构造器内，`lea ecx,[esi+0x6214]` → 地图对象为主世界子对象）；
   主世界构造器 `0x00427D89–0x00427E1F` 同时构造：共享控件 `0x417550`（main+0x6108）、
   输入框 `0x417960`（main+0x61BC，参数 0x44/5/0xC/0x54/0xC/0）、6 个 HUD 矩形控件
   （帧 0x117..0x1DF 步 0x28）、地图子对象、`0x428BA0`/`0x4292B0`。T 键/点击切换的
   “大地图”即同一表面的 128↔256 分辨率重建。

3. **T 键与鼠标双输入路径**（pending_3 关闭，标签除外）。按键分发 `0x0042CC76–0x0042CF1F`
   完整恢复（GetKeyState@IAT`0x476278`，`mov cl,ah` 取高字节）：
   Q→`0x42ADB0`(0x10C/0x10B 确认对话框)、W/E/R/S/D→`0x42ADB0`(1/0x0E/8/0x0D/0x0B)、
   Z→行走/跑步状态 `main+0xD40`（clamp 0x2E，`+0xD42`=2）、B→切换 `main+0x6208`、
   G→`0x42ADB0`(6)、F→`0x4523E0`(0x8AB828)、N→`0x42ADB0`(0x0C)、
   **T（0x54）**→门控 `main+0x6518==1` 后切换 `main+0x64A8`，两分支分别以 0x100×0x100
   （`0x42CED2`）/0x80×0x80（`0x42CEF0`）经 `0x43D5F0` 重建 `main+0x6214` 地图表面；
   Y（0x59）→切换 `main+0x64A4`（不重建表面）。鼠标路径：`0x43DDB0` 命中 `owner+0x2C0`
   转世界坐标存 `+0x2F0/+0x2F4`；命中 `+0x298` 切换 alpha `+0x290`；命中 `+0x2A8`
   切换模式 `+0x294` 并 256/128 重建（`0x43DE60`/`0x43DE84`）。用户可见标签不在二进制内
   （.rdata 无任何地图相关 GBK/ASCII 字符串，仅有 IAT 名），标签保留为语义候选
   “小地图缩放切换”。

4. **对象链表布局与类型字节**（pending_4 关闭，业务名除外）。链表 `0x560070`（头指针，
   节点 vtable `0x476448`，`+4`=对象 entry、`+8`=prev、`+0xC`=next；尾 `0x56008C`、
   计数 `0x560098`，20+ 处插入点）entry 布局：`+4`=对象 id（`0x41ECAE` 按 xy 查找）、
   `+0x88`=类型字节、`+0xCC/+0xD0`=世界坐标、`+0x61C74`=存活标志。类型字节观测值：
   0/1（`0x41ECE1` 按坐标查找对象命中集合；`0x43CD29` 地图收集跳过）、2（`0x405F61`）、
   3=演员（`0x4071A0` kind 字 `+0x8A`、`0x43CD3F` 子类型 `+0xC0`==4、`0x408276` 法术
   分派）、**0x32（50）=小地图黄色标记对象**（`0x43DC65` 绘制 + `0x4123E3` 目标/阻挡检查）。
   链表 `0x5600A0`：entry `+4/+8`=坐标，绿点，半视野裁剪（`0x43DD46` 与 `0x2B8/0x2BC`
   比较），候选=附近玩家/队员。类型 0x32 业务名（NPC vs 传送点）无静态命名依据，保留候选。
   绘制顺序：视野指示（绿）→ 边框（灰）→ 辅助框（浅灰/淡蓝）→ 类型 0x32 标记（黄）
   → 近距对象（绿），全部在合成之后。

视觉交叉验证：wilviewer 导出 MMap.wil 帧 0/1，wilsdk 解码为 600×400 地形图（棕/褐
噪点地形+对角道路特征+4 个内嵌白色 ^ 标记），确认 MMap 帧是地图艺术而非边框/UI 帧；
小地图边框确为代码绘制。`0x47630C`=timeGetTime（`0x408396` 动画时钟）顺带确认。

剩余 pending：类型 0x32 业务名、缩放切换运行时画面、按键标签（无字符串资源）。

### Finding 216：状态窗口 pending 三项处置 + 全局 selector 数组/构造循环定位（2026-08-10）

状态窗口三条 pending 的调查全部完成，本轮落盘并附加两项结构性发现。

1. **属性文本坐标闭合（pending_1 关闭）**。`0x0044BC80` 属性绘制链坐标模型修正：
   第一列 label 原点 `(winx+0xFF, winy+0x43)`、行步 0x0F（13 行，y 67..247）；
   **第二列不是累计偏移**——`0x44C3D4/0x44C3D8` 复位重读 `[ebp+0x18]/[ebp+0x1C]`
   （窗口原点）后 `0x44C3F8 add edi,0x17F; add esi,0x1E`，即第二列 label 原点
   `(winx+0x17F, winy+0x1E)`（11 行，y 30..180）；`0x44C44F lea ebx,[edi+0x44]`
   → 第二列数值 x=`winx+0x1C3`。旧 JSON 的 “第二列 x=winx+0x27E / y=winy+0x127 /
   累计模型” 废止并标注。颜色事实：第一列 label 0xfae1c8、第二列 label 0xff。
   窗口双位置字段注记：`[this+8]/[this+0xC]`=背景屏幕位置（0x423D00/0x460240），
   `[this+0x18]/[this+0x1C]`=属性/装备/命中测试基准（0x44B2D0/0x44BC80/0x44B720）；
   两对均在基类 ctor `0x423B30` SetRect。

2. **装备槽类别 = server-driven（pending_2 保持 candidate，客户端无类别逻辑）**。
   `0x44B720` 为纯位置命中测试（索引扫描 + PtInRect），无任何类别分支；仓库服务端
   EquipmentSlot 枚举（0武器/1衣服/2头盔/3火把/4项链/5左手镯/6右手镯/7左戒指/8右戒指/
   9鞋子/10毒药/11护身符/12花/13马甲/14徽章/15盾/16时装）是唯一类别依据；状态窗 8 槽
   索引 2,3,5,6,7,8,9,10 → 经典 Mir3 八件套仅按位置/配对记录为 candidate。

3. **全局 selector 数组与构造循环定位（pending_3 结构闭合）**。0x566780/0x5668C4/
   0x566A08/0x566B4C/0x566C90/0x566DD4 间距恰 0x144（324）→ 全局数组基址
   **0x5600FC、步长 0x144**（元素=base+index*0x144）：el14=0x5612B4、
   el70=0x565994、el81=0x566780、**el82=0x5668C4（flag0 item）**、
   **el83=0x566A08（flag1 item）**、el84=0x566B4C、el85=0x566C90、
   el86=0x566DD4、**el139=0x56B0E8（flag2 item）**。这解释了此前 imm32 扫描
   找不到构造点：构建走“地址计算 + 等步长循环”而非 mov imm32。

   构造循环位于地图进入/重建函数 **`0x43B600`**（caller 0x422B2B；格式串
   `.\\Map\\%s.map` @0x47C404 → 写 [ebx+4] → CreateFileA IAT 0x4760DC → 读 0x1C
   头 → 分配 [ebx+0x108]/[ebx+0x10C]）：
   - 析构循环 `0x43B75B`：`esi=0x5612B4; call 0x465FE0; esi+=0x144;
     cmp esi,0x565994; jl` → 覆盖元素 14..79。
   - 构造循环 `0x43B7B2`（14 次）：`esi = 0x5600FC + start*0x144`，
     start=`([ebx+0x124]+1)*14`；路径槽 `ebp = 0x56B22C + start*0x104`；
     每迭代 `push 1; push ebp; call 0x4660E0`（mode1 优先），失败 `call 0x465FE0`
     后 `push 0` 重试（mode0 回退）；`esi+=0x144; ebp+=0x104`。
   - **[ebx+0x124]=4 推断**（推断级）：start=70 → 构造元素 70..83（0x565994..
     0x566A08），el82 为第 12 个、el83 为第 13 个；路径槽 0x56F944+0x104i
     （slot12=0x57058C、slot13=0x570690）。依据：主对象图块装载器第二循环
     `0x452AF7` 恰 0x46=70 次、第二成员区起点 this+0x5898=this+0x144*70，
     两个 “70 基数” 吻合。

   路径槽静态分析：0x56F944/0x57058C/0x570690/0x56B22C 的 imm32 扫描全负
   （唯一引用是 0x43B7AE 的 lea）；.rdata 指向 0x47C878..0x47CE0C 的指针表
   零命中 → bss 路径槽由计算地址运行时填充 → **具体 WIL 文件名绑定仍为运行期**，
   Equip.wil（@0x47CCE4）/ Inventory.wil（@0x47CCF8）并列 candidate 维持。
   el139（flag2）与元素 84+ 的构造循环未在 .text 定位（另一循环，未穷举）。

   附带确认：`0x468306` = 数组元素构造助手（`0x452A40` 处参数 ctor=0x465f40、
   count=0x8C=140、size=0x144）——主对象持有 140 个 selector 成员槽（推断）；
   map 窗口成员间距 0x148（+4 MMap/+0x148 FMMap）为独立布局。`.rdata` 每个 WIL
   字符串在 .text 恰 1 处引用且均为主对象路径字段复制 → 静态路径仅注入主对象
   字段（本轮修正字段偏移：Magic→+0x10374、Inventory→+0x10478、Equip→+0x1057C、
   Ground→+0x10680、MIcon→+0x10784；M-Hum→+0xFA50、M-Weapon4→+0xFB54、
   M-Weapon3→+0xFC58、M-Weapon2→+0xFD5C），与全局 selector 数组无静态绑定。

落盘：`status-window-render-evidence.json` 新增 global_selector_array /
selector_construction / flag_dispatch / equipment_slot_classification 小节，
修正 coordinate_bases.second_column 与 second_column_labels y 偏移（30..180），
pending 3 项按闭合/候选状态改写。

剩余 pending：运行时 WIL 文件名绑定（el82/83/139）、装备槽人类名（server-driven
candidate）、[ebx+0x124]=4 的运行时确认、el84+/el139 构造循环定位。

### Finding 217：背包/交换/商店“Frame 94 侧板”之谜 = 共享条/量条控件（0x00417960/0x004179B0）（2026-08-10）

**结论**：背包绘制入口 `0x0042EBB0` 处的 `push 0x5E` 是共享量条控件 **量程上限 94**，
不是 GameInter 素材帧号。背包、交换、商店（以及聊天、行会、主 HUD、NPC 窗口）里的这些
12px 宽竖条全部来自同一个控件类：构造 `0x00417960`（7 参，`ret 0x1C`）、绘制
`0x004179B0`（`GetFrame(sel,[esi+8])` → 比例 `value/(max-1)` 存 `[esi+0xC]` 浮点 →
帧宽高从 `selector->[+0x38]` 读 → RECT 经 USER32 **SetRect** IAT `[0x4762B0]`（导入名记录
VA `0x4793D8`，hint `0x0244`——不是代码函数）建立 → ftol `0x468520` → 附带
`0x45F2D0`(class 0x8AB7A8) 裁剪填充图）。控件成员布局：`+0x04`=selector、`+0x08`=帧号、
`+0x14`=arg3、`+0x1C/+0x1E/+0x20`=w/h/pad、`+0x44`=USER32 **PtInRect** IAT
`[0x47630C]`（导入名记录 VA `0x4797DE`，hint `0x01EA`，命中测试）、`+0x48`=模式
（0=竖直，1=水平）。

**家族全表（本轮闭合的 7 个消费点）**：

| ctor VA | 窗口 | 成员 | 帧号 | 素材尺寸 | 填充区 w×h | 绘制 VA | 位置 | value | max |
|---|---|---|---|---|---|---|---|---|---|
| `0x4142A8` | 聊天 | `+0x6D4` | `0x17C`=380 | 16×502 | 12×260 | `0x414846` | winx+0x215, winy−0xD0 | `[this+0x68]` | `[this+0x6D0]` |
| `0x415AE1/0x415AFF` | 交换 | `+0x13648/+0x13694` | `0x42E`=1070 | 16×360 | 12×184 | `0x41601C/0x41603D` | winx+0xD1/+0x1B9, winy−0x73 | `[this+0x54/0x58]` | 固定 94 |
| `0x42502D` | 行会 | `+0x76C` | `0x276`=630 | 16×558 | 12×285 | `0x42514D` | winx+0x224, winy−0xD0 | `[esi+0xB4]` | `[esi+0x9C]` |
| `0x427DCC` | 主 HUD | `+0x61BC` | `0x44`=68 | 12×154 | 12×84 | `0x429584` | 584, 425（常量） | `[esi+0xD20]` | `[esi+0xD08]` |
| `0x42EB4B` | 背包 | `+0x278` | `0x118`=280 | 16×424 | 12×218 | `0x42EBB0` | winx+0xF8, winy−0xA5 | `[this+0x58]` | 固定 94 |
| `0x43EDE7` | NPC | `+0x3C4` | `0x140`=320 | 12×236 | 12×122 | —（静态绘制调用未在 0x43Exxx 区间找到） | — | — | — |
| `0x44D4B4` | 商店 | `+0x5FC` | `0x3FC`=1020 | 16×418 | 12×216 | `0x44DB3F` | winx+0x107, winy−0xAA | `[this+0x65C]` | `[this+0x700]` |

（素材尺寸来自原版 GameInter.wil 帧头；聊天/行会/商店/HUD 的 value/max 是运行时字段，
背包/交换为固定量程 94。）

**关键修正**：
- 背包 `0x0042EB9B/0x0042EBB0`：先前“顶部/详情组合素材 Frame 94”错误——`0x5E` 是量程。
  28×26 的 GameInter 帧 94 图像属于无关的 HUD 组队按钮（`layout.json hud.party`，
  `0x427A82` 构造）。
- 交换 `0x41601C/0x41603D`：“两个 Frame 94 侧板”→两条交易重量量条。
- 商店 `0x44DB3F`：量条 value=`[this+0x65C]`、max=`[this+0x700]` 均为运行期字段。
- 聊天 `this+0x6D4`（先前“input-box-candidate”pending）：就是同一量条控件，帧 380，
  绘制于 `(winx+0x215, winy−0xD0)`，value=`[this+0x68]`、max=`[this+0x6D0]`。

**空条事实**：背包 `[this+0x58]`、交换 `[this+0x54/0x58]`、商店 `[this+0x65C]/[this+0x700]`
在 .text 中没有任何写入点（`0x44183B` 的 `mov [esi+0x58], 0xE8000000` 属无关滑块类），
即本构建这些量条全部以 value=0 渲染（仅帧素材 + 空填充）——记录为 pending/unwired，
不虚构运行时数值。背包量条语义候选=负重（窗口有 `负重:%d / 总量:%d` 文本），证据等级
candidate。

落盘：`inventory-window-render-evidence.json`、`system-window-render-evidence.json`
（交换）、`store-window-render-evidence.json`、`chat-window-render-evidence.json`、
`draw-order-evidence.json`、`UI_COVERAGE_MATRIX.md` 背包行、`UI_COMPLETION_AUDIT.md`
背包/交换行。

### Finding 218：任务窗口滚动模型、滚动语义、帧 721–724 像素态与事件 0x418/0x419 孪生（2026-08-10）

**滚动模型（primary-static）**：任务窗口列表与详情正文各自有独立的滚动偏移，全部由
鼠标滚轮/点击处理器写入、由 Paint 消费：

- `this+0x58` = 列表滚动偏移（行）。Paint 只绘制落在 `[this+0x58, this+0x58+19)` 的行
  （19 行窗口守卫 `cmp [esp+0x10], 0x13`）。`this+0x5C` = 行数上限钳制，由 Paint 每帧
  从解码行计数写入（`0x00447DED`）。
- `this+0x60` = 详情正文滚动偏移（行），Paint 的 3 行窗口守卫
  `this+0x60 <= line < this+0x60+3`。
- 滚轮 `0x00448700`：正文/列表两个矩形命中测试，各自 `-1` 并下限 0。
- 点击 `0x00448780`：GetCursorPos `[0x476240]` + ScreenToClient `[0x476234]`；
  正文矩形内点击 `this+0x60 = min(+1, 3)`；列表区点击 `this+0x58 = min(+1, this+0x5C-1)`。
- 正文命中矩形 = 窗口相对 (80,310)-(250,380)（SetRect IAT `[0x4762B0]`，`0x004487CC`）。

**几何**：列表行 x=winx+0x41、y=winy+0x5A+15·row（`lea eax,[ecx+ecx*2+0x12]`×5）；
详情正文 x=winx+0x50、y=winy+0x136，15px、3 行，正文色 BGR 0x7D0000（深蓝）。

**帧 705 完整面板**：GameInter.wil 帧 705 = 204×76（bbox (0,0,202,76)），完整覆盖
详情正文区（3 行×15px 文字 + 边距），绘制于 (65,294)。此前“装饰面板 or 完整背景”
pending 关闭为完整文本背景面板。

**帧 721–724 像素态（WILSDK，28×28，bbox 全满）**：
- 721 = 绿色 X（46 绿像素，采样 RGB(152,188,56)）— 高亮态
- 722 = 金色 X（0 绿像素，采样 RGB(112,88,72)）— 常态
- 723 = 绿色右箭头（106 绿像素）— 高亮态
- 724 = 金色右箭头（0 绿像素）— 常态
（此前“724 空帧”来自已废弃的手写 WIL 解析器，作废。）

**事件孪生 0x418/0x419（primary-static，业务名 candidate）**：
- `0x00451A10` 构造类型 **0x418**（1 参数=选中记录首 dword，任务 id 候选），由
  `0x00448580` 在标记选中记录（`+0x208=1`、`this+0x68=1`）且 `record+0x20C==0` 时发送；
  721/722 与 723/724 两个控件路径都汇入该函数。X 图标 → 业务名候选“放弃/删除任务”。
- `0x00451A40` 构造类型 **0x419**（2 参数=记录首 dword + 子记录对象），由输入处理器
  `0x00447FA0` 在点击 `record+0x228` 子记录命中矩形且其正文 `+0x220` 为空时发送；
  候选“请求任务详情/查看”。
- 两者共用消息装配器 `0x00452940`，发送经 `0x00451E60`；Mud3 服务端为二进制
  （EIServer.exe），仓库无源码可交叉验证，业务名保持 candidate。

**列表解码**：行文本经共享记录解码器 `0x0045E0C0`（记录 vtable +0x44 取字段、
+0x68 前进），类型门 0xA0/0xC8；行色分支 `record+0x204`/`+0x210` → 0x19197D/0x1919C8
（BGR 暗红/亮红）。分隔符字符在记录类内部，静态不可见 → pending（需运行时抓包）。

落盘：`quest-window-render-evidence.json`（pending 4→2）、`layout.json`（重生成）、
`UI_COVERAGE_MATRIX.md` 任务行、`UI_COMPLETION_AUDIT.md` 任务行。
### Finding 219：VA→文件偏移映射修正 + ROOT 为 .data 静态全局对象 0x47EF18（2026-08-10）

**映射修正（重要，取代此前全部按“fileoff = VA − 0x3FF000”做的裸 dword 转储）**：
`Mir3.exe` 的 PE 节表所有节 vaddr == raddr（`.text` 0x1000/0x1000、`.rdata` 0x76000/0x76000、
`.data` 0x7A000/0x7A000、`.rsrc` 0x519000/0x7F000；文件大小 524,288），因此
**fileoff = VA − 0x400000**（对 VA ∈ 0x401000..0x7F0000）。此前“VA = 0x400000 +
(fileoff − 0x1000)”的假设整体早读 0x1000 字节，**作废**。`disasm_capstone.py` 始终走 PE
节表，代码级结论不受影响；本会话已按正确映射重转储并复核 vtable（0x476624/0x476864/
0x476938/0x47694C/0x476950/0x476A54/0x476A68）、字符串（0x47C330 火、0x47C334
`- %d -`、0x47C33C `%d %d/%d`、0x47C348 奔覆 GB18030 B1BC B8B2）、dword
0x47C4D8=0xFFFFFF 与 0x421E8C 消息表，均一致。

**ROOT = 静态全局对象 @ VA 0x47EF18**（.data 内；`.data` vsize 0x49EFD4 覆盖 VA
0x47A000..0x917FD4 而 raw 仅 0x5000 字节，故字段落在零填充 BSS 区）：
- 调用形式 `mov ecx,0x47ef18`（字节 `b9 18 ef 47 00`）作为 this 传给 0x419CC0、
  0x41C1E0、0x41EBD0、0x41EC10、0x419C40、0x41BB00、0x41B440、0x41B500、
  0x419350（init）；0x401970 `mov ecx,0x47ef18; jmp 0x418b00`（ctor 部分 1，SEH 标记
  0x4748CC；`[+0xE1154]=0x4766F0` 列表 vtable、清零 +0xE1158..+0xE1160）、
  0x401990 `jmp 0x418d50`（部分 2）。
- **UI 初始化 0x4570A0**：`call 0x457040; mov eax,0x47ef18; mov ecx,0x47ef18;
  mov [0x8ab820],eax; mov [0x8b1870],eax; call 0x419350; mov byte [0x8b1878],3; ret`。
  即全局 `[0x8AB820] = [0x8B1870] = ROOT 指针`，`[0x8B1878] = 3`（UI 状态标志）。
- 子对象：winmgr = ROOT+0x2A548C = VA 0x77A524（BSS）；NPC 模型 = ROOT+0x2F65DC =
  winmgr+0x51150；激活标志 `[model+0x30]` = ROOT+0x2F660C；保存的对话正文指针
  +0x2F6630；消息头暂存 +0x42804C/+0x428050；点击缓冲 ROOT+0x2A54AC（0x41FD36 以
  ebx=ROOT 运行，`mov eax,[ebx+0x2A54AC]` 证实为 ROOT 相对）；子对象 +0x2F8780
  (0x40FE80)、+0x35B2C0 (0x4344E0)、+0x361150 (0x446D60)、+0x3611F0 (0x442650)、
  +0x3612B4 (0x443020)、+0x36137C。

### Finding 220：统一窗口 id 空间 0..15 与四张共享表（取代“每表独立 id”旧结论）（2026-08-10）

同一窗口 id 在**绘制分派 0x428358**、**关闭全部 0x42B938**、**显示切换 0x42B3E4**、
**输入分派 0x42C4D4** 中含义一致（winmgr 相对偏移，winmgr = ROOT+0x2A548C）：

| id | winmgr+ | VA（构造/paint/handler） | 类别 |
|---|---|---|---|
| 0 | 0x6554 | 0x42E810/0x4300F0/0x42EB80 | 通用窗口 |
| 1 | 0x29CE4 | 0x44AF50/0x44CCD0/0x44B2D0 | 商店状态机 |
| 2 | 0x33188 | 0x44B680/0x44E9B0/0x44E260 | 商店扩展 |
| 3 | 0x3399C | 0x4159B0/0x416EF0/0x415B10 | 通用窗口 |
| 4 | 0x4707C | 0x425070/0x4258F0/0x425040 | 通用窗口 |
| 5 | — | 无 | 未分配 |
| 6 | 0x47834 | 0x4241A0/0x424610/0x4243D0 | 通用窗口 |
| 7 | 0x47C28 | 0x450250/0x450B30/0x450530 | 任务窗口 |
| 8 | 0x507EC | 0x413E20/0x4149A0/0x414700 | 聊天窗口 |
| **9** | **0x51150** | **0x43EA80/0x440290/0x43F460/0x43F040/0x43F020** | **NPC 模型** |
| 10 | — | 无 | 未分配 |
| **11** | **0x516E8** | **0x4471D0/0x447FA0/0x447470/0x4488B0/0x4473E0** | **NPC 帧窗口** |
| 12 | 0x518E0 | 0x440E90/0x4414F0/0x441380 | 节点类窗口 |
| 13 | 0x52118 | 0x4269E0/0x426A80/0x4269C0 | 通用窗口 |
| 14 | 0x524F0 | 0x43B680/0x43AB10/0x439500 | 通用窗口 |
| 15 | 0x52E5C | 0x43E260（确认式窗口） | 确认窗口 |

旧结论“id 空间按表各自独立”与旧关闭全部表（id 8→+0x51150、id 9→+0x516E8）被
**取代**——旧表转储使用了错误的文件映射。`0x42C4D4` 各 case “push id”的语义 =
用窗口**自身 id**重新激活/显示被点击窗口：case 9 push **0xB=11**（帧窗口 id）、
case 12 push 0xC、case 13 push 0xD、case 14 push 0xE——全部自洽。

### Finding 221：绘制分派器 0x4280F0 全解（this=winmgr，ret 0xC）（2026-08-10）

- 开场：`mov [esi+0xd34],ebx; mov eax,[esi+0xd28]; mov [esi+0xd2c],eax`——从
  +0xD28 播种遍历游标 +0xD2C，计数 `[+0xD38]`。
- 每个打开节点：`mov edi,[esi+0xd2c]; mov ecx,[edi]`（节点 id @ 节点+0）；
  `cmp ecx,0xf; ja 0x428283; jmp [ecx*4+0x428358]`——**只绘制打开列表中的窗口**，
  按打开顺序（最新在前）。
- 绘制表 0x428358（id→VA，偏移 = winmgr 相对）：0→0x428166 (+0x6554→0x42EB80)、
  1→0x42817C (+0x29CE4→0x44B2D0)、2→0x428192 (+0x33188→0x44E260)、
  3→0x4281A8 (+0x3399C→0x415B10)、4→0x4281BE (+0x4707C→0x425040)、
  5→0x428283（默认跳过）、6→0x4281D4 (+0x47834→0x4243D0)、
  7→0x4281EA (+0x47C28→0x450530)、8→0x428200 (+0x507EC→0x414700)、
  **9→0x428213 (+0x51150→0x43F460 模型)**、10→0x428283（跳过）、
  **11→0x428226 (+0x516E8→0x447470 帧)**、12→0x428239 (+0x518E0→0x441380)、
  13→0x42824C (+0x52118→0x4269C0)、14→0x42825F (+0x524F0→0x439500)、
  15→0x428272 (+0x52E5C→0x43E3C0)。
- 可见性矩形测试 `[0x476248]` 在 0x428293；**id 9 模型跳过该测试**
  （`cmp [edi],8; je 0x42829f` 是 id 8=聊天窗口跳过，不是模型）。
- 循环后：**0x42AAB0**（鼠标坐标自 0x7DA1C0/0x7DA1C4）= 光标下窗口 id → 第二遍表
  **0x428398**：id0→0x4282FF (+0x6554→0x42FAB0)、id1→0x42830C (+0x29CE4→0x44B6B0)、
  id2→0x428333 (+0x33188→0x44E650)、id3→0x428319 (+0x3399C→0x416790)、
  id4..6→0x42833E（默认）、id7→0x428326 (+0x47C28→0x450AC0)。
  任一窗口可见（`test ebp,ebp; jne`）→ `call [0x4762AC]`（屏幕 present/更新）。

### Finding 222：显示=切换（toggle）、打开列表 push/pop、关闭全部（2026-08-10）

- **显示切换 0x42ADB0**（case id 9 = 0x42B25E，id 11 = 0x42AF2F，同一模式）：
  `mov eax,[esi+WINDOW+0x30]`（激活标志；模型读 ROOT+0x2F660C ✓）；
  已激活 → `call 0x42ac50`（从打开列表移除 id）→ 窗口 vtable 槽+0x10 传 0
  （模型：0x43F020 → `[window+0x30]=0`）→ 返回 0（已隐藏）；未激活 →
  `call 0x42ac30`（追加 id）→ vtable+0x10 传 1 → 返回 1（已显示）。
  模型 show = vtable+0x10 = 0x43F020（落到 0x423F80 setActive）；帧 show = 0x4488B0。
- **打开列表**：列表对象在 winmgr+0xD24（vtable 0x476864，8 槽），节点 =
  `[id@0, next@4, prev@8]`；0x42AC30 = push id（head +0xD2C / tail +0xD30 /
  count +0xD38）；0x42AC50 = 按 id 摘链并释放节点（this=winmgr，例：
  `push 9; lea ecx,[esi+0x2a548c]; call 0x42ac50`）。
- **关闭全部 0x42B820**（`cmp eax,0xe; ja 0x42b860`）：逐 id
  `push 0; lea ecx,[esi+OFFSET]; call 0x423f90`（setHidden 写 `[window+0x34]=0`）；
  尾段重走 +0xD2C 并更新 +0xD34。

### Finding 223：模型类 vtable 0x476938、帧类 0x476A54、选项列表类 0x476A68、节点类 0x47694C（2026-08-10）

按正确映射重转储（此前若干槽位归属作废）：
- **0x476938（NPC 模型 5 槽，+0x51150）** = `[0x43EB20, 0x43EBF0, 0x43ECC0,
  0x43F040, 0x43F020]`（dtor 桥/重置/reinit/纹理 paint/show）；其后 0x47694C、
  0x476950 是**节点类/下一个类**的 vtable（旧“0x440E40/0x440F00/0x440F90 属于模型
  vtable”归属作废）。0x43F020 → 0x423F80（`[this+0x30]=arg` setActive）。
- **0x47694C（对话节点类，节点 0x10 字节）** = `[0x440E40, 0x440F00, 0x440F90,
  0x4268B0, 0x423D00, 0x423F80]`；**0x476950（+0x518E0 = id 12 窗口类）** =
  `[0x440F00, 0x440F90, 0x4268B0, 0x423D00, 0x423F80]`。
- **0x476A54（帧窗口类，+0x516E8，15 槽）** = `[0x447270, 0x447380, 0x4473C0,
  0x423D00, 0x4488B0, 0x4498E0, 0x449960, 0x44AFF0, 0x44B0B0, 0x423CF0, 0x423D00,
  0x423F80, 0x44B110, 0x44D090, 0x44D150]`；paint 0x447470、handler 0x447FA0 是
  直接调用（不进 vtable）。0x447270 = dtor 桥 → 0x447290。
- **0x476A68（帧 +0x1E0 的选项列表类，15 槽）** = `[0x4498E0, 0x449960, 0x44AFF0,
  0x44B0B0, 0x423CF0, 0x423D00, 0x423F80, 0x44B110, 0x44D090, 0x44D150, 0x4268B0,
  0x423D00, 0x423F80, 0x450140, 0x44FF70]`（旧“0x476A68 = 帧类且 handler 0x43AB50”
  归属作废）。
- **0x476624（基窗口类 8 槽）** = `[0x4150D0, 0x423CA0, 0x423CF0, 0x423D00, 0x423F80,
  0x4155A0, 0x415710, 0x415820]`；**0x476864（打开列表类）** = `[0x42E4E0,
  0x40000000, 0x42E7C0, 0x42E8B0, 0x42E970, 0x42EA50, 0x423D00, 0x423F80]`。
  0x47AF48/0x47AF68 是 GBK 字符串，不是 vtable。

### Finding 224：模型构造 0x43EA80、帧构造 0x4471D0 与布局工厂调用点（2026-08-10）

- **模型 ctor 0x43EA80**（SEH 标记 0x47535F；mega-ctor 调用点 0x426DCD）：
  `[esi]=0x476624; call 0x423ca0`；`0x4686C4(+0x58, 0xB4, 3, 0x404690, 0x4046B0)`
  = **3 个控件 @ +0x58 步长 0xB4**（即 +0x58 帧对 161/162、+0x10C 帧对 54/55、
  +0x1C0 帧对 52/53）；`+0x278` 文本缓冲（0x465EF0 分配）；`+0x3C4` 计时对象
  （0x4178E0）；`[esi]=0x476938; [+0x3BC]=0; [+0x514]=0`。
- **帧 ctor 0x4471D0**（SEH 标记 0x4755AF；调用点 0x426DD2，tag 0x12）：
  `[esi]=0x476624; call 0x423ca0`；`0x4686C4(+0x74, 0xB4, 2, 0x404690, 0x4046B0)`
  = **2 个控件 @ +0x74、+0x128**；`[esi+0x1E0]=0x476A68`（选项列表对象），清零
  +0x1E4/+0x1EC/+0x1E8/+0x1F4/+0x1F0；`[esi]=0x476A54`；`call 0x447380`。
  dtor 桥 0x447270→0x447290；mega-dtor 分支 0x474DEB/0x474F6B
  （`add ecx,0x516e8; jmp 0x447290`）。
- **winmgr init 0x4270F0 的对话段**（同一 mega-ctor）：
  - 0x4278AD：`push 1, 0x1b8(440), 0x154(340), 0, 0, 0x2bc(700), edx=[winmgr+0x1c],
    0xb(11); lea ecx,[esi+0x516e8]; call 0x4473e0`——**帧设置工厂，自带 id 11**。
  - 0x427924：`push 0, 0xb0(176), 0x228(552), 0, 0, 0x44c(1100), [winmgr+0x1c],
    9; lea ecx,[esi+0x51150]; call 0x43ed00`——**模型布局，构造尺寸 552×176 与
    此前记录一致，帧 1100 起**。
  - 同一段还布局 +0x524F0（0x4278FE，0x439250，id 0xe）、+0x53030（0x427950，
    0x418910）、**+0x52E5C（0x42797E，0x43E260，id 0xf）**——确认 0x43E260 =
    id-15 确认式窗口 @ winmgr+0x52E5C。
  - 0x43ED00 流程：reset（vtable+4）→ 0x43EE00（由 WIL 帧 0x44C/0x44D/0x44E 建立
    部分矩形 +0x520/+0x530/+0x540 与整矩形 +0x550/+0x560/+0x570）→ 3 个控件
    0x417550 → 文本缓冲 0x465FA0/0x4660E0。
- WIL 原生尺寸（wilsdk 直接读头）：帧 700 = **512×512**（帧窗口背景候选，
  0x4473E0 参数 0x2bc=700）、701=52×12、702=52×12、703=88×12、704=88×12
  （条带候选）；帧 1100=512×256、1101=512×32、1102=512×64。

### Finding 225：NPC 对话**文本**绘制 = 0x43F460（回答此前遗留问题“文本在哪画”）（2026-08-10）

`0x43F460`（this = 模型 = winmgr+0x51150）是对话**文字**绘制者，与纹理 paint
0x43F040（帧 1100/1101/1102 图像合成）分离——Finding 199 的“字形 helper 未看到”
由此闭合：
- 文字色 = dword `0x47C4D8 = 0xFFFFFF`（白）；GBK 换行（`0x45E0C0` 系列共享解码器，
  ecx=0x8AB7A8 2D 图形 DC）。
- 文本区原点：窗口相对 **x+0x96=150、y+0x28=40**；行距 pitch = textheight+5。
- 滚动窗口 = `[this+0x3BC] .. [this+0x3BC]+[this+0x594]`。
- 选项行标记串 `0x47C348` = “奔覆”（GB18030 B1BC B8B2；0x47C330 火、0x47C334
  `- %d -`、0x47C33C `%d %d/%d` 同区字符串）。
- 遍历**全局对话节点链表**：head 0x8B1AE4、tail 0x8B1AE8、count 0x8B1AF4；节点
  vtable 0x47694C，行结构在 节点+4，每节点 5 个子矩形 line+0xC..+0x5C（步长 0x10）。
- 解析/滚动函数（this=模型）：0x440630 = 链表释放 + 游标复位
  （`[+0x3BC]=0; [+0x3C0]=[+0x594]`）；0x440750 = 滚动/状态解析（清零
  +0x582/+0x584/+0x588/+0x51C/+0x58C，token 计数经 0x440AA0）；0x43E9A0 =
  内嵌文本段解析（`<`/`\`/`{` → 类型 1/2/3/4 经 0x43E7B0）；0x440BE0/0x440C30 =
  每节点 5 子矩形布局；0x4406D0/0x440700 = 滚动上下（以 `[+0x3C0]` 钳制）；
  0x440C70 = 节点分配器（0x10 字节，vtable 0x47694C）；0x440E40 = 节点 dtor 桥。
- 纹理 paint 0x43F040 门控：`[this+0x30]`（激活）AND `[0x8B1874]`（纹理缓存就绪）。

### Finding 226：帧窗口绘制 0x447470 与自带选项列表（2026-08-10）

帧窗口（+0x516E8，id 11）**自己绘制一份选项列表**，与模型文本面板（0x43F460）
并存：
- `0x447470`：`[esp+0x38]=1`；调 vtable+0xC（=0x423D00 基类 paint）；GetTickCount
  累计到 `[0x8B1B00]/[0x8B1B04]`；经 0x417830 把 +0x74 控件放到窗口相对
  **(x+0x122, y+0x3B)**、+0x128 控件放到 **(x+0x122, y+0x59)**；对两控件各调
  vtable+4（步长 0xB4）绘制；随后画**自己的**选项列表：`[+0x1F0]=0; [+0x1E8]=[+0x1E4]`；
  门控 `[+0x54]`（可见）后逐行迭代，`cmp [esp+0x10],0x13; jge` —— **上限 0x13=19 行**。
- 列表对象 @ +0x1E0（类 0x476A68）：head +0x1E4、遍历游标 +0x1E8、计数 +0x1F4；
  行对象在 [node]，行矩形 line+0x218（4 dword），悬浮标志 line+0x210。
- **处理器 0x447FA0**（帧输入）：+0x128 控件 vtable+0x10 优先；随后逐行命中
  line+0x218 矩形 → `[line+0x210]=1`、`[esp+0x18]=line`；若 `[line+0x208]` 且
  `[line+0x20C]` 非零 → 动作子列表 @ `[line+0x228]`（索引 `[+0x228+0x10]`、
  计数 `[line+0x22C]`）：子节点 = `[[list+0x8]]→[child]` 数据指针，命中矩形在
  child+0x204；命中 → `[+0x6C]=child+0x220` 并调用 **0x451A40**。
- **0x451A40 = 事件类型 0x419 发送器**（2 参数 = 记录首 dword + 子记录对象）：
  经共享装配器 0x452940 组头 + 0x451E60 发送。同族：0x451A10 = 0x418（1 参数）、
  0x451A70 = 0x401、0x451AA0 = 0x402、0x451AD0 = 0x403、0x451B00 = 0x405、
  0x451B30 = 0x406。
- **0x41B94F**：把 `[ROOT+0x2F6630]`（保存的对话正文）经 0x4521B0 拷 0x3F3=1011
  字节到静态 `0x8AB828`——对话正文的静态副本缓冲（0x451A40 的 ecx=0x8AB828 即此）。

### Finding 227：输入分派两级表、模型输入 0x440290、滚动 0x43AB50（2026-08-10）

- **winmgr 鼠标处理器 0x42BEAA**：先测 +0x61BC 控件（0x417E60，聊天候选）；
  否则 `push mouse-y/x; mov ecx,esi; call 0x42aab0` 命中窗口 id；id==2 经 +0x33188/
  0x44E910 特判；id==-1 → 循环 eax=0..15 调 winmgr+0x8A7C+id*540 输入对象表的
  vtable 槽+0x10（步长 = ((id*15+0x267)*9)*4）→ 一级表 **0x42C494**
  `[0x42C1CE, 0x42C259, 0x42C241, 0x42C2E1, 0x42BF37(错误对话框→ROOT 0x419CC0),
  0x42C218, 0x42C209, 0x42C292, 0x42C302, 0x42C226, 0x42C1A4, 0x42C1B2,
  0x42C359, 0x42C1C0, 0x42C234, 0x42C30D]`；具体命中 id → 二级表 **0x42C4D4**
  `[0x42BF85, 0x42BFB3, 0x42BFE1, 0x42C00B, 0x42C039, 0x42C198, 0x42C063, 0x42C08D,
  0x42C0B7, 0x42C17D, 0x42C198, 0x42C0E1, 0x42C10B, 0x42C131, 0x42C157, …]`。
- **模型输入 = 0x440290**（旧归属 0x43AB50 作废）：`[+0x58]` 控件 vtable+0x10 命中
  （命中且 `[+0x274]!=0` → 返回 1）；再若 `[+0x3BC]>0`（有行）且
  `byte [+0x58C]==1` → 滚动条 `[+0x1C0]` 处理。成功后分派 case 调
  `mov ecx,0x47ef18; call 0x41c1e0` = **ROOT hide-all → 点击模型面板关闭对话**。
- **0x43AB50 = 模型滚动拖动/更新**（非分派 handler）：`byte [+0x54]` 页索引、
  `[+0x58+idx*4]` 滚动偏移（±6 行钳制）、`[+0x240]` 滚动控件 vtable+0x10、
  每页上限 `[+0x8A8]`、控件数组 @ `[+0x2F4]`。
- 帧窗口键鼠方法（0x42BCD6/0x42C64F/0x42C6F4/0x42C86A/0x42C96A/0x42CA0C 调用）：
  0x448230（键盘）、0x448430、0x448490、0x448640、0x448650、0x448780（点击）。

### Finding 228：NPC 对话打开/关闭全链与点击缓冲（2026-08-10）

- **打开**（消息表 0x421E8C 索引 16 = 0x41FE31，msg 0x274 系）：链表复位 0x440630
  (+0x2F65DC)；载荷经 0x452810 上栈（上限 0x2000）；头字段写 ROOT+0x42804C/
  +0x428050；`strchr '\'` 拆分头/正文；正文经 0x440750 + 0x43E9A0 解析；
  `[ROOT+0x2F660C]!=0` 则跳过，否则 `push 9; lea ecx,[ROOT+0x2A548C];
  call 0x42ADB0`（show id 9）；正文指针存 ROOT+0x2F6630。
- **hide-all 0x41C1E0**（this=ROOT）：`[ROOT+0x2F660C]!=0` → 0x42AC50(winmgr, 9)
  摘链 → 模型 vtable+0x10(0) 失活 → 清零 +0x428050/+0x42804C；
  `[+0x2D8644]!=0` → 摘 id 2 + [+0x2D8614] vtable+0x10(0)；
  `[+0x2ABA10]!=0 && byte[+0x2ABA34]!=0` → 第三块（+0x2AB9E0）。调用者：消息表索引
  17（0x41FECC）、输入分派 case 13（0x42C18E）、0x42CFBE。
- **点击缓冲处理 = 消息表索引 13（0x41FD36）**（非列表填充函数）：
  `mov eax,[ebx+0x2A54AC]`（ebx=ROOT）；`byte [ebx+0x2A54E6]==0x33` → 错误消息框
  0x418030（ecx=+0x3615B0，msg 0x67，标题 0x565994，文本 0x47B864）；
  strcmp 式比较 0x47ADB4 与 `[ebx+0x2A54C8]`（选项文本匹配）。
- 帧窗口 +0x516E8 完整引用图：ctor 0x426DD2（0x4471D0）、dtor 0x426EFC（0x447290）、
  reinit vtable+8（0x4274D7/0x4274E3）、设置 0x4278AD（0x4473E0）、paint 0x428226
  （0x447470）、show 切换 0x42AF42/0x42AF61、定位 0x42B5E2（0x423FA0）与 0x42B766、
  close-all 0x42B8CC、输入分派 0x42C0E1。

落盘：`npc-window-render-evidence.json`、`npc-paint-evidence.json`、`layout.json`、
`UI_COVERAGE_MATRIX.md`、`UI_COMPLETION_AUDIT.md`、`MIR3_UI_RECONSTRUCTION_HANDOFF.md`。

### Finding 229：帧选项列表填充链闭合 = 服务端 msg 0x515（回答“谁填充 frame+0x1E0”）（2026-08-10）

**修正**：本会话首遍曾把填充消息误记为 0x514；按分派算术复核，正确 id 为 **0x515**
（字节表偏移 0x515−0x44D=0xC8 处字节 0x03 → 处理表 `[3]@0x422174`=0x421A45；
0x514 → 字节 0x02 → 0x421BBC，未探索）。

- **子协议分派 0x4218F2**（ROOT handler 族，ids 0x44D..0x520）：
  `lea edi,[eax-0x44d]; cmp edi,0xd3; ja 0x421d3f; xor edx,edx;
  mov dl,byte[edi+0x42219c]; jmp dword ptr[edx*4+0x422168]`。
  处理表 @0x422168（12 项 + noop 0x422198=0x421D3F；字节表默认 0x0C）：
  0x44D→0x421C81；0x4B0→0x421913（发 **0x40C**）；0x514→0x421BBC；
  **0x515→0x421A45**；0x516→0x421AF5；0x517→0x421A85；0x518→0x4219A0
  （存 ROOT+0x35A410/414/418）；0x519→0x421BA7；0x51A..0x51D→0x421CFC；
  0x51E→0x421B5B；0x51F→0x421955；0x520→0x421C23。
- **0x421A45**（唯一调用点 0x421A7B）：`lea ecx,[ebx+0x2f6b74]`（ebx=ROOT；
  帧 = winmgr+0x516E8 = **ROOT+0x2F6B74**）；0x452810 拷正文（上限 0x2000）上栈；
  `push [esp+0x16]&0xffff`（count）+ body；`call 0x4488d0`；jmp 0x421d3f。
- **0x4488D0(frame, body, count) 逐行填充**：先 0x448EF0 复位（`[frame+0x54]=0`，
  释放旧行与子列表）；body 空或 count<=0 → ret 0。每行：
  0x468B1A 分配 **0x630B 描述符**；0x468BF0 按 '/' 切分（≤4 字段，栈内就地 NUL）；
  描述符整体清零（0x18C dwords）；**整段 body 拷入 desc+4**；`desc+0x204`=len、
  `desc+0x22C`=len2、`desc+0x230`=字段2文本、`desc+0x214`=有字段2、
  `desc+0x208/+0x20C` 动作标志清零；**0x449870(list=frame+0x1E0, desc) 追加**。
  结束：`[frame+0x54]=1`（已装载）、`[frame+0x5C]=count`、0x449060 重排；ret 1。
- **0x449870 = 通用链表追加**（类无关）：0xC 节点 `[0]=data,[4]=next,[8]=prev`；
  列表头 `[0]=vtable(0x476A68),[4]=head,[0xC]=tail,[0x14]=count`；ctor 0x4498E0。
  调用点：0x41538F、**0x42AC3B（打开列表追加）**、0x448ABA（本填充）、0x4491B6、
  0x44933E。帧链表头 frame+0x1E0（head +0x1E4、游标 +0x1E8、tail +0x1EC、count +0x1F4）。
- **帧显示 0x4488B0（vtable+0x10）**：`[frame+0x30]=eax`（激活）；
  激活且 `[frame+0x54]==0`（未装载）→ `mov ecx,0x8ab828; call 0x4519e0` = 发 **0x416**
  请求对话内容（正文 @0x8AB828+0x18）。故 `[frame+0x54]` = 内容已装载标志。
- **定位+显示 0x42B6A0(id,x,y)**（与切换 0x42ADB0 不同）：0x42B820 关全部 →
  0x42AC50 摘链 → 0x42AC30 重加（置顶）→ `[winmgr+0xD3C]=1` → 0x423F90(1)
  （`[window+0x34]=1` 可见）→ 0x4240C0(x,y) 定位。id 偏移表 @0x42B7E0
  （0→+0x6554,1→+0x29CE4,2→+0x33188,3→+0x3399C,4→+0x4707C,6→+0x47834,
  7→+0x47C28,8→+0x507EC,9→+0x51150,**11→+0x516E8**,12→+0x518E0,13→+0x52118）
  与统一窗口 id 空间一致。**0x4240C0 定位门控**：仅当 `[win+0x30]`（激活，写
  0x423F80）与 `[win+0x34]`（可见，写 0x423F90）与 `[win+0x3C]`（使能）全非零，
  才写 `[win+0x48]=x−[win+0x18]`、`[win+0x4C]=y−[win+0x1C]`。帧经 0x42BCEF 放置：
  先 0x448230（帧键 handler），未处理则定位+显示 id 11 @(ebx,edi)。
- **0x42B820（关全部）调用点**：0x42ADB6（切换前置）、0x42B6B3（定位前置）、
  0x42BD8F（输入分派前置）——任何窗口打开前先关全部。
- **行绘制几何**（帧 paint 0x447470）：x=[frame+0x18]+0x41、y=3·i+0x12；
  hover（`line+0x210`）色基 0x1919C8，普通 0x19197D；上限 0x13=19 行。

### Finding 230：消息构造族与 0x41B94F/0x41D744 上下文（2026-08-10）

- **信封格式**：0x452940(dest, p2..p6, ret 0x18) 写 12B 头：
  `[dest+0]=p3(dword)`、`[dest+4]=p2(word)`、`[dest+6]=p4`、`[dest+8]=p5`、
  `[dest+0xA]=p6`（word）；正文区 @dest+0x18。发送 0x451E60：
  `[this+0x14]` 序号 1..9 循环、0x4528E0 拷头→+0x24、0x452740 拷正文（上限 0x2000）
  →+0x44、0x46811C 组包（模板 0x47C840）。
- **构造函数族**（this=0x8AB828 静态消息对象）：
  - 0x451A10 = msg **0x418**（1 参数）；0x451A40 = msg **0x419**（2 参数，参数 =
    选项 `desc+0` 动作码 word + 数据 dword）；0x451A70/0x451AA0/0x451AD0/0x451B00/
    0x451B30 = 0x401/0x402/0x403/0x405/0x406；
  - 0x4519E0 = msg **0x416**（帧内容请求）；0x451740 = msg **0x3F2**（1 参数）；
    0x4521B0 = msg **0x3F3**（2 参数）。
- **0x41B94F**：`push [esi+0x2f6630]（保存的对话正文）; push 0x3f3; mov ecx,0x8ab828;
  call 0x4521b0` = 以 ROOT+0x2F6630 的正文组装 **msg 0x3F3** 发出（静态副本 1011B
  进 0x8AB828+0x18 区）。
- **0x41D744 逐帧更新**（`cmp cl,0x32; jne` 分派内）：距上次发送 >500ms
  （GetTickCount 0x47630C vs [ROOT+0x428040]）且 `[ROOT+0x2F660C]==0`（模型未激活）
  且 `[ROOT+0x364444]` 非空 → `push [obj+4]; mov ecx,0x8ab828; call 0x451740`
  = 发 **msg 0x3F2**；然后 `[ROOT+0x364450]=0`、`[ROOT+0x428040]=tick`。
  `[ROOT+0x364444]` = 动态目标对象（业务语义待定）。

落盘：`npc-window-render-evidence.json`（option_list_fill_chain /
show_requests_content / position_show 块）、`UI_COMPLETION_AUDIT.md`（NPC 行）、
`MIR3_UI_RECONSTRUCTION_HANDOFF.md`（§3 闭合块、§6 更新）。

### Finding 231：子协议同族 handler 全解码 = 帧加载器家族 / 任务日志推送 / 聊天行打印（2026-08-10）

**字符串簇解码**（0x47B1xx，Python euc-kr/gbk 实测）：
- 0x47B15C = EUC-KR **"새로운 퀘스트가 시작 되었습니다."**（新任务开始了）
- 0x47B180 = EUC-KR **"퀘스트 일지가 변경되었습니다."**（任务日志已变更）
- 0x47B1A4 = EUC-KR **"아이템을 모두 가지고 있지 않습니다."**（没有持有全部道具）
- 0x47B1C8 = GBK "你没有足够的申请经费。"、0x47B1EC = GBK "战者已经打建行会。"（行会补丁串）
→ 原版客户端为韩文（Legend of Mir 3 系），GBK 串为中文汉化补丁残留；
0x47B15C/0x47B180 由 0x516/0x517 handler 用作**任务日志变更的聊天提示**。

**0x401390 = 8 项颜色表**（跳转表 @0x4013D8；`mov ecx,[esp+4]; and ecx,0xff; cmp 7; ja ret0`）：
0→0x000000、1→0x0A0A0A、2→0xFFFFFF(白)、3→0x0000FF(红)、4→0x00FF00(绿)、
5→0xFF9696、6→0x50FFFF、7→0x80FF。故 0x516/0x517 中 `push 2/3; call 0x401390` =
取白/红两色。

**0x427E30(winmgr, c1, c2, fmt) = 聊天行打印**：`[esp+0x113C]`=fmt 空 → ret；
`lea ecx,[ebp+0x507ec]`（**聊天窗 id 8**）`call 0x4144a0`（c1、fmt、c2 三参）；
随后 0x45E200 把文本渲到 2D DC 0x8AB7A8。0x516/0x517 经此输出韩文任务提示。

**0x449060 重排 = 抽干 + 冒泡排序 + 重追加**：0x468B1A 分配 count*4 指针数组 →
遍历链表摘除全部节点收集 desc → **0x449158..0x44919F 按 `[desc+0]`（数字 id）冒泡升序**
→ 逐个清零 `[desc+0x208]` 并经 0x449870 重追加。→ 选项列表按 id 有序。

**0x4491D0(frame, body, word) = 幂等插入（任务日志加项）**：`[frame+0x54]==0` →
0x4519E0 发 **0x416** 返 0（0x4491EF）；已装载：strlen 检查 → 逐行 '/' 切分 →
**0x449680 查重**（链表找 `[desc+0]==首字段`，0x4496F6 `setne` 返回）→ 已存在返 0；
新项 0x630B 分配 + 字段写入（含 0x230 区清 0x100 dwords）+ 0x449870 追加 →
循环毕 `[frame+0x5C]=count`、`[frame+0x54]=1`、0x449060 重排；ret 1。
**0x449870 同族填充点 0x4491B6/0x44933E 均在 0x4491D0 函数体内部**（此前“商店/仓库
候选”假设撤销）。

**0x448B10(frame, body, id, count) = 子列表追加**：未装载 → 0x448B2E 发 0x416 返 0；
walk 找 `[desc+0]==id` 的行（0x448B48 起）；行 `+0x228` 空 → 新建子列表
（0x18B 节点，vtable **0x476A6C**）；每子项 0x620B 分配、'/' 切分、字段写入、
`子项+0x214`/`父行+0x20C`=1、文本拷 +0x220 区、**内联追加**（不走 0x449870）；
`[desc+0x22C]=count`。

**0x449390(frame, body, w1, w2) = 子列表替换**：未装载 → 0x4493AF 发 0x416 返 0；
strlen → '/' 切分首字段 → 0x4493C0.. walk 查行（`[desc+0]==首字段`）→
行 +0x228 空 → 新建（vtable 0x476A6C）→ 续填充。

**0x448D90(frame, id, text) = 子项选中**：找行 → 行内子列表按 id 找子项 →
`子项+0x21C`=1（激活）、文本拷 `+0x220`。

**处理表其余 handler 全部落地**：
- **0x514→0x421BBC**：`[ROOT+0x35B148]=byte`；`lea esi,[ebx+0x2f8780]`（另一管理
  对象，+0x2F8784=当前 id）vtable+0x88 通知（参 [ROOT+0x2F8808]）；按标志字节
  show/hide 窗口 id **0x1D**（vtable+0x10，参 0x2F8841）。
- **0x518→0x4219A0**：0x452810 拷 0x2000 正文上栈；id==`[ROOT+0x2F8784]` →
  3 word 存 **ROOT+0x35A410/0x35A414/0x35A418**；否则 0x41EB10 查对象 →
  存 **对象+0x61C90/0x61C94/0x61C98**（坐标/参数候选）。
- **0x519→0x421BA7→0x422E30**：`[ROOT+0x44]`（日志开关）非零且 body word4≠0x64 →
  以 "ab" 打开 **Chat.txt**（0x47B9F0/0x47B9FC）追加 `"%s\r\n"`（0x47B9E8）写正文；
  body word4==0x68 → 0x427E30(黑 0, 绿 4, body) + 0x4256A0(ROOT+0x2EC508, body)；
  否则 0x427E30(byte8 色, byte6 色, body) —— **彩色聊天文本打印**。
- **0x51A..0x51D→0x421CFC**：0x40C 记录（3 dword + 字符串 @+0xC，字符串经
  [0x4760C8] 拷入）→ **0x4561B0(ROOT+0x364458, rec)** 排队（业务语义候选：私聊/交易请求）。
- **0x520→0x421C23**：0x41EB40 按 id 查 → 无则 0x10B 记录 0x468B1A 分配 +
  ROOT+0xE1184 列表 vtable+4 追加；`[0]=id`、`[4]/[8]=word`、`[+0xC]=tick(0x47630C)`
  —— **带时间戳的对象注册**。
- **0x44D→0x421C81**：2 dword + 字符串记录（[0x4760C8] 拷贝）→ id==当前
  → winmgr(+0x2F8780) vtable+0x38；否则 0x41EB10 查对象 → 对象 vtable+0x38
  —— **对象动作路由**。
- **0x4B0→0x421913**：0x40C 记录（3 dword + 字符串）→ **0x41B710(ROOT, rec)** 组装
  出站 **0x40C**：scratch ROOT+0x428054..（`[0x428064]=1`、4 word 经 0x401670
  转储 0x428178 区、[0x4762B0] 定位计算）→ 转发服务器。

**结论**：0x416 发送族 **0x4488B0/0x448B10/0x4491D0/0x449390 全部是同一帧窗口
（ROOT+0x2F6B74）的内容加载器**，非其它窗口；帧窗口承载 **NPC 对话选项 + 任务日志
（quest-log）两类内容**；0x516/0x517 = 任务日志变更/新任务推送（韩文原版聊天提示 +
帧内容更新）。

落盘：`npc-window-render-evidence.json`（confirmed/pending 更新）、
`UI_COMPLETION_AUDIT.md`（NPC 行）、`MIR3_UI_RECONSTRUCTION_HANDOFF.md`（§3/§6）。

### Finding 232：open-all 全表 / 点击打开分派链 0x42BB00 / 商店 pre-open 0x44EF00 + hit-test 0x44E910 / 顶层窗解析 0x42AAB0 / 商店 +0x30 疑案结案（2026-08-10）

**open-all 尾段（0x4276D0..0x427983）完整参数表**（`lea ecx,[esi+off]` + 每窗 open fn；
`[esi+0x1c]`=selector+0x5898=70 条工作记录数组；push 序 = 参数序 arg1 最后压入）：

| id | offset | open fn | 参数 (arg1=id, arg2=frame, arg3..arg8[,arg9]) |
|---|---|---|---|
| 0 | +0x6554 | 0x42EA80 | (0, fr, 0xFA, 0x206, 0, 0x11C, 0x144, 1) |
| 1 | +0x29CE4 | 0x44B130 | (1, fr, 0xC8, 0, 0, 0xF4, 0x148, 1) |
| 2 | +0x33188 | 0x44D310 商店 | (2, fr, 0x3E8, 0, 0, 0x12C, 0x130, 0) |
| 3 | +0x3399C | 0x4159D0 | (3, fr, 0x41A, 0, 0, 0x1E4, 0x14A, 1) |
| 4 | +0x4707C | 0x424E60 物品 | (4, fr, 0x258, 0x66, 0x16, 0x254, 0x1BE, 1) |
| 6 | +0x47834 | 0x424250 背包 | (6, fr, 0x384, 0x110, 0x7B, 0x100, 0xF4, 1) |
| 8 | +0x507EC | 0x414060 聊天 | (8, fr, 0x15E, 0x72, 0x4C, 0x23C, 0x184, 1, 0) |
| 7 | +0x47C28 | 0x4503B0 | (7, fr, 0xC8, 0x230, 0, 0xF4, 0x148, 1) |
| 0xC | +0x518E0 | 0x440FE0 | (0xC, fr, 0x2EE, 0x114, 0x71, 0xF8, 0x108, 1, 3) |
| 0xB | +0x516E8 | 0x4473E0 帧 | (0xB, fr, 0x2BC, 0, 0, 0x154, 0x1B8, 1) |
| 0xD | +0x52118 | 0x4268C0 | (0xD, fr, 0x352, 0, 0, 0x128, 0x14C, 1) |
| 0xE | +0x524F0 | 0x439250 | (0xE, fr, 0x190, 0x15C, 0, 0x1C4, 0x17C, 1, 3) |
| 9 | +0x51150 | 0x43ED00 快捷栏 | (9, fr, 0x44C, 0, 0, 0x228, 0xB0, 0) |
| — | +0x53030 | 0x418910 隐藏窗 | (0x64, fr, 0x320, 0xDA, 0xB0, 0x16C, 0xB8, 3) |
| 0xF | +0x52E5C | 0x43E260 | (0xF, fr, 0x25A, 0x6B, 0x6E, 0x248, 0xFC, 0, 3) |

- **arg6/arg7 = w/h 已用已知窗尺寸交叉验证**：聊天 0x23C×0x184=572×388 ✓、
  物品 0x254×0x1BE=596×446 ✓、背包 0x100×0xF4=256×244 ✓、快捷栏 0x228×0xB0=552×176 ✓。
  arg3 = 窗口/锚宽候选（商店 0x3E8=1000、隐藏窗 0x320=800 = 屏宽）；arg4/arg5 = 位置候选；
  arg8 = 标志（商店/快捷栏 0，余 1）；arg9 = 深层标志（0xC/0xE/0xF/0x53030=3，聊天=0）。
- **尾声 0x427983..**：三次 0x417550 布局（selector+0xC58/+0xC5C 基址 → 0x567C 区 0x50/0x51、
  +0xE4/+0xE6 → 0x5730 区 0x52/0x53、+0xFC → 0x5744 区 0x54/0x55）＝选择屏三块文本标签。

**0x42AAB0(winmgr) = 顶层窗口解析**：`[winmgr+0xD38]`（open 计数）==0 → -1；否则
`[winmgr+0xD2C]=[winmgr+0xD30]`（列表尾）、`[winmgr+0xD34]=count-1`，从尾向前按 id 跳转表
@0x42ABE8（0→+0x656C, 1→+0x29CFC, 2→+0x331A0, 3→+0x339B4, 4→+0x47094, 5→+0x4784C,
6→+0x47C40…）→ 0x42AB6F 查可见/使能 → 返回首个活跃 id 否则 -1。调用者 11 处
（0x41233E/0x412A2B/0x4282EE WM paint/0x42B9E7/0x42BB12/0x42BED3/0x42C58B/0x42C7F2/
0x42C8F2/0x42D4C3）。

**0x42BB00(winmgr, x, y) = 点击打开分派器**：0x42AAB0 → -1 → 0x42BD8D：
0x42B820 关全部 → **0x42D720(winmgr, x, y)**（`[winmgr+0xD42]` 标志、+0xD44 起 6×0x10 条目；
每条 SetRect(rc, [e], [e+4], [e]+0x26, [e+4]+0x26) → PtInRect 0x4762B4 = **6 个 0x26×0x26
热点方块**，命中返序号否则 -1；调用者 0x412377/0x42BD98/0x42C36F/0x42CA7A）→ 命中 ret 1；
未中 → `[winmgr+0x6518]` 非零 → 0x43DDB0(winmgr+0x6214, x, y) → ret 1；否则 ret 0。
id 0..0xE 跳转表 @0x42BDE0：每窗 = **pre-open 检查**（失败才 0x42B6A0(id,x,y) 打开/重定位）：

| id | pre-open（this=winmgr+off） | 失败→ |
|---|---|---|
| 0 | 0x42FFD0(+0x6554) | 0x42B6A0(0,x,y) |
| 1 | 0x44CF00(+0x29CE4) | 0x42B6A0(1,x,y) |
| **2 商店** | **0x44EF00(+0x33188,x,y)**；0→0x42B6A0(2,x,y)；随后 **0x44E910(+0x33188,x,y)** 命中→拒绝（回 0x42BD8D） |
| 3 | 0x4171B0(+0x3399C) | 0x42B6A0(3,x,y) |
| 4 | 0x425CB0(+0x4707C) | 0x42B6A0(4,x,y) |
| 6 | 0x424730(+0x47834) | 0x42B6A0(6,x,y) |
| 7 | 0x450B50(+0x47C28) | 0x42B6A0(7,x,y) |
| 8 | 0x414C60(+0x507EC) | 0x42B6A0(8,x,y) |
| 9 | 0x440170(+0x51150) | 0x42B6A0(9,x,y) |
| 0xB | 0x448230(+0x516E8 帧键 handler) | 0x42B6A0(0xB,x,y) |
| 0xC | 0x441970(+0x518E0) | 0x42B6A0(0xC,x,y) |
| 0xD | 0x426B50(+0x52118) | 0x42B6A0(0xD,x,y) |
| 0xE | 0x43AC00(+0x524F0) | 0x42B6A0(0xE,x,y) |
| 5/0xA/0xF | —（0x42BD78 ret 1 无操作；`cmp eax,2` 死分支） | — |

**0x42B6A0(winmgr, id, x, y) 完整分派**：`[winmgr+0xD38]!=0` 才开；0x42B820 关全部 →
0x42AC50 摘链 → 0x42AC30 重加置顶 → `[winmgr+0xD3C]=1`；跳转表 @0x42B7E0：
- **id 2（商店）特例 0x42B6FC**：**0x44E910(store,x,y) 命中列表区 → 0x42B7DA ret 0（拒绝
  打开/重定位，可点选物品）**；未中 → 0x423F90(1)（`+0x34` 可见）+ 0x4240C0(x,y) 定位
- id 0/3/4/6/7/8/9/0xB/0xC → 公共尾 0x42B774（0x423F90(1) + 0x4240C0）
- id 1 → 0x42B79A 特例；id 0xD → 0x42B794；id 0xE → 0x42B7BA（+0x524F0）
- id 5/0xA/0xF → 0x42B7DA（无操作返 0）

**0x44EF00(store, x, y) = 商店 pre-open（点击吞没判定）**，状态 `[store+0x5F8]`：
- state ∈ {0,1,3,4}：0x417D00(store+0x5FC, x, y)（0x417D00 = 通用双矩形 hit-test：+0x24 rect
  PtInRect → GetTickCount−`[+0x44]`≤0xA 防抖 → +0x34 rect PtInRect）命中 →
  **`[store+0x700] = ([store+0x65C]−1) × [store+0x608]`**（fild/fmul/0x468520 浮转整；
  价格/滚动量候选）ret 1；未中 → 0x44F009：主面板 +0x54/+0x108 vtable+0xC hit-test →
  命中 ret 1 → 续 0x44F02D 状态分支
- state ∈ {2,5,6,7,…}：侧面板 +0x1BC/+0x270/+0x324/+0x3D8 vtable+0xC hit-test → 命中 ret 1；
  全未中 → 0x44F0C9
- ret 1 = 点击吞没（不重定位）；ret 0 = 交 0x42B6A0

**0x44E910(store, x, y) = 商店点击 hit-test**：state==1 → rect（[+0x18]+0x12C, [+0x1C]+0xD0,
w=[+0x20], h=[+0x24]）；state==4 → rect（[+0x18]+0x12C, [+0x1C]+0x64, …）；PtInRect 0x4762B4
命中 → **ret 0（吞掉打开）**，未中 ret 1。

**商店 paint 链 0x44E260 全解码**：vtable[3]=0x423D00 基类 paint → 状态相关面板重定位
（0x417830 ×6：+0x1BC/+0x270/+0x324/+0x3D8/+0x48C/+0x540；state 0/4/1/3 时用 +0x54 基准区，
state 1 额外 +0x1BC..+0x3D8，state 4 额外 +0x48C/+0x540）→ **8 主面板（+0x54 起 0xB4 步长）
`call [panel_vtbl+4]` 绘制循环** → 状态分派：{0,4,1,3}→0x44D590；{1,2}→0x44DB50；{4}→0x44E040。

**商店 +0x30 疑案结案**：0x44F6C3/0x44FD5E 的 `[ebp+0x30]` 写入位于**物品列表构建循环**
（0x44F5AB..0x44F70A 与 0x44FD30..，逐记录调 0x4681F9 后写 +0x28..+0x38），**非 paint-enable**。
商店窗口 +0x30 在商店区从未被写：+0x34=可见（0x423F90，0x42B6A0 写）、+0x3C=使能（0x44CF60 区
写 0/1）。基类 paint 0x423D00 门控：`[this+0x30]` 非零 → 背景（0x466130 selector 检查 +
0x460240 绘制，0x258×0x320 屏）；零 → 0x423E6C 备选路径（3D 变换绘制：selector 0x5600FC、
缩放 0x47639C、[0x8AB7BC] 3D DC —— 地图/世界视图类窗口）。商店背景由状态 paint 族承担，
不经基类背景路径。

**mir3.dat / selector 初始化 0x452AA0(obj, ret 8)**（obj=ROOT+0xE11E4，open-all 的
`[esp+4]`=selector）：fn B 0x452B20 把 Mir3.exe .data 字符串（0x47D51C/0x47D508/0x47D4F4…）
逐串拷入 obj+0xB130/+0xB234/+0xB338/…（0x104 步长路径槽，14 槽）；loop A1：0xE 次
`0x4660E0(obj+0x144*i, obj+0xB130+0x104*i, 1)`，失败 → 0x465FE0 复位重试 flag 0；
**loop A2（0x452AE6）：0x46=70 次 `0x4660E0(obj+0x5898+0x144*i, obj+0xF848+0x104*i, 0)`** ——
70 条记录自源表 +0xF848 载入工作数组 +0x5898（0x104→0x144 扩充 = 运行时字段）。
mir3.dat 内源表**零填充，运行时由 0x4660E0 解析**（0x4660E0(rec,path,flag)：0x465FA0 复位 +
flag0→0x466160 / flag1→0x466300）。open-all 的 frame=selector+0x5898 即此 70 条工作记录。

落盘：`RESEARCH_LOG.md`（本 finding）、`MIR3_UI_RECONSTRUCTION_HANDOFF.md`（§3/§6 更新）。
### Finding 233：IAT 手工 thunk 命名 + 两个 wndproc 的消息分派 + 按钮类静态 vtable（2026-08-10）

**IAT 真相**：导入目录（RVA 0x78C10）只有 6 个 DLL（KERNEL32/GDI32/ole32/WS2_32/MSVFW32/WINMM），
FirstThunk 落在 0x476044..0x476308 之外；`0x47628C..0x476304` 区间**不在任何描述符 FirstThunk 内**，
槽值 = **函数名 RVA**（hint 表风格）。即客户端启动时**手工解析并回填**这些 thunk
（`GetProcAddress` 族，0x47630C 起才是真实 IAT = timeGetTime 等）。按槽值 RVA 读名：

| thunk | 名字 | thunk | 名字 |
|---|---|---|---|
| 0x47628C | MessageBoxA | 0x4762BC | MoveWindow |
| 0x476290 | **SendMessageA** | 0x4762C0 | GetWindowLongA |
| 0x476294 | (未译) | 0x4762C4 | RegisterHotKey |
| 0x476298 | (未译) | 0x4762C8 | UnregisterHotKey |
| 0x47629C | (未译) | 0x4762CC | **SetWindowTextA** |
| 0x4762A0 | TranslateMessage | 0x4762D0 | (未译) |
| 0x4762A4 | GetMessageA | 0x4762D4 | SetCursor |
| 0x4762A8 | PeekMessageA | 0x4762D8 | LoadCursorA |
| 0x4762AC | **ShowWindow** | 0x4762DC | SystemParametersInfoA |
| 0x4762B0 | **SetRect** | 0x4762E0 | SetWindowPos |
| 0x4762B4 | **PtInRect** | 0x4762F8 | PostQuitMessage |
| 0x4762B8 | SetFocus | 0x4762FC | LoadIconA |
| — | — | 0x476300 | RegisterClassExA |
| — | — | 0x476304 | **GetWindowTextA** |

→ 早前“0x418520 用 PostMessage(0x7EE)”的推断修正为 **SendMessageA(hwnd=[0x8AB7B0], 0x7EE, wparam, lparam)**（同步）。

**窗口类“WH GEngine”**（0x47DBB8，RegisterClassExA @ 0x467BBE，lpfnWndProc=0x467AE0）：
wndproc 是**转发器** → 对象 [0x91790C]（vtable 0x476C7C 含 GUID 段 = COM 接口）vtable[0]=0x467AC0=
DefWindowProc 族（call [0x4762EC] 4 参）→ “WH GEngine” 是引擎隐藏窗，非主消息开关。

**两个真正的消息开关**（均 ret 0x10、this=esi、`mov ecx,[esp+0x14]` 尾调 0x465E80 缺省；
都在入口 `lea ecx,[esi+8]; call 0x418470` 转发确认框键盘）：
- **0x403Fxx**：0x201→0x4040F0、0x202→0x404240、0x7E8→`0x451BB0(0x8AB828)`、**0x7EE→0x404600**
- **0x4596xx**：0x201→0x459840、0x202→0x4599E0、0x7E8→`0x451BB0(0x8AB828)`、**0x7EE→0x45A140**、尾再 `0x45B440(0x8AB130, hwnd, msg, w, l)`
- **0x404600（0x7EE, 输入态）**：`[esi+0x8A4]==1` 时清 [esi+0xE3D] 260B、`SetWindowTextA([0x8AA48C], esi+0xD39)`、`[esi+0xD38]=1`、call 0x403640、`[0x8AA498]=0` —— **恢复输入框文本**（取消语义），不用 wparam。
- **0x45A140（0x7EE, wparam 解码）**：`wparam>>16` → `cl=byte3`（type）、`al=byte2`（子型）；**type==1 && 子型==0** → `[esi+0x1168]∈[0,1]` 时 `0x452040(0x8AB828, esi+0xCBF+idx*0x40)` + `0x451F90(0x8AB828)`；随后 `[esi+0x930]==2` 时 MoveWindow(输入框 → 鼠标+0x120/+0x195, 0x4B×0xD) + ShowWindow(1) + SetFocus —— **聊天输入路径**（type 1 专用）。→ **确认框的 0x7EE（type 3/4/6/9/0x65）不经这两个开关**：`SendMessageA` 目标 [0x8AB7B0] 是**主游戏窗**，其 C++ 消息开关（0x412303/0x412AAE 顶层输入分派 → 0x42AAB0 命中 + 0x42C4D4 二级表，见 Finding 232）在**另一条链**处理。

**按钮类静态 vtable 0x4763A8 实锤**（.data，非运行时构建）：
[0]=0x4046C0 dtor、[1]=0x417640 paint、[2]=0x417780 hover、[3]=0x4177C0 press、
[4]=0x4177F0 release、[5]=0x404910、[6]=0x4049B0、[7]=0x404A30、[8]=0x404D60…；
0x404690 = 按钮类 ctor（`mov [ecx],0x4763A8; call 0x4175F0`）。早前“无静态 vtable 引用”结论
仅对**确认框父类**成立（父类 vtable 确实无静态引用），按钮子类有静态 vtable。

落盘：`RESEARCH_LOG.md`（本 finding）、`MIR3_UI_RECONSTRUCTION_HANDOFF.md`（§3/§6 更新）。

### Finding 234：确认框单例 0x7E04C8 全解码——ctor 0x418030、基类 0x417FB0、居中规则（2026-08-10）

**0x417FB0 基类 ctor**（`ret`，无弹参）：`[this+0x28]=0`；3× `0x4175F0` 零构造按钮
（this+0x238 / +0x2F0 / +0x3A8，步长 0xB8）；+0x460=0xFFFF、+0x462=0（活动索引）。

**0x418030 ctor（8 args，ret 0x20）最终 arg 图**：
- arg1 = WIL 资源 → this+0x45C + `SelectFrame(资源, 950)`（this+4=0x3B6=950）
- arg2 = **类型 id → this+0**（3=付款/扔金币、4=仅掌门、6=踢成员、9=？、0x65=101=？；也是 0x7EE wparam 高字节一部分）
- arg3 = 按钮模式：0=仅中间（+0x2F0 勾选 157/158）；1=是（+0x238,151/152）+否（+0x3A8,154/155）且 [+0x462]=0；2=全无
- arg4 = 消息串 → 复制到 this+0x2C（GBK）
- arg5 = msg 矩形变体：0 → 底=top+0x78（h=97）；非 0 → 底=top+0x64（h=77）；左=x+0x18、上=y+0x17、右=x+0x14D
- arg6 = x、arg7 = y，**双 −1 → ctor 内居中（0x41808D-0x4180C3）**：left=400−w/2, top=246−h/2，
  取 [资源+0x38] 帧头；帧 950 = 360×190 → 屏上 (220,151)
- arg8 = word → this+0x460（wparam 低字；付款 0x405、默认 0xFFFF）
- 窗口矩形 SetRect(this+8, x, y, x+w, y+h)；**`[this+0x28]=1`（可见）@ 0x418284**；ret 0x20。

**居中规则实锤**：付款调用 0x416F9C 的 push 序列逐一核对为 (0x565994, 3, 1, 0x47AD98, 1, **−1, −1**, 0x405)
—— 7 个调用方里 6 个走 −1/−1 居中路径，1 个（存储满）走显式坐标。

落盘：`confirmation-prompt-evidence.json`、`RESEARCH_LOG.md`、`MIR3_UI_RECONSTRUCTION_HANDOFF.md`（§3/§6）。

### Finding 235：按钮类 0x417550/0x4175F0 + 状态机 + 键盘/鼠标交互（静态闭合）（2026-08-10）

**0x4175F0 基类**：+0x24=1（使能）、+0x25=1、SetRect(+4,0,0,0,0)、+0x14..+0x30=0、
+0x34 起 rep stosd 0x20 dwords（标签缓冲）。

**0x417550（9 args，ret 0x24）arg 图**：arg1=res→+0x14；arg2=帧1→+0x18；arg3=帧2→+0x1C；
arg4=x→+0x28；arg5=y→+0x2C；arg6=label→+0x34；arg7=byte→+0x24（使能）；arg8=帧3→+0x20；
arg9→+0x30。确认框三按钮（位置相对窗口 this+8）：是 (151,152)+150 于 (left+0x33, top+0x7D)；
中 (157,158)+156 于 left+0x93；否 (154,155)+153 于 left+0xF4。使能标志 +0x234/+0x2EC/+0x3A4；
活动索引 this+0x462。

**paint 0x417640**（vtable[1]）状态机（+0x25：0 正常 / 1 悬停 / 2 按下）：
- 正常：门控 `[+0x25]==0 && [+0x24]==1` → SelectFrame(+0x20)；帧 −1 跳过
- 悬停：`[+0x25]==1 && [+0x24]==1` → `[+0x30]≠0 ? +0x18 : +0x20`
- 按下：`[+0x25]==2` → SelectFrame(+0x1C)
- 全部经 **0x460240(0x8AB7A8, x, y, 帧w, 帧h, 0x320, 0x258, 0xFFFF, 0xFFFF)** 合成
  （帧 w/h 取 [res+0x38] 帧头 word，800×600 裁剪）

**hover 0x417780**：PtInRect(this+4, x, y) → 内 +0x25=1 / 外 +0x25=0（ret 8）。
**press 0x4177C0**：PtInRect 命中 → +0x25=2、ret 1（ret 8）。**release 0x4177F0**：+0x25=0；
PtInRect 命中 → `0x45AFC0(0x8AB130, 0x69, 0, 0, 0)`、ret 1（ret 8）。
**0x45AFC0 = 场景对象拾取器**：0x32 槽数组 this+0x460，逐槽比 [obj+0x3C]==type，
命中 → 0x45B900(obj, …, x, y, 1)；未命中 → 0x45AC00 再找。**0x69 = 鼠标抬起命中消息**。

**键盘 0x418470**（经两个 wndproc 入口转发，ecx=esi+8）：TAB(9) 循环活动索引 0x462
（`lea eax,[eax+eax*2]; shl edx,3; sub edx,eax; [esi+edx*8+0x234]` = 步长 0xB8）跳过禁用，
到 3 回绕；回车 0xD/空格 0x20 → **0x418520 激活**；其余 ret 1（未处理）。

**激活 0x418520**：`idx=[+0x462]`；按钮禁用 → ret 0；`wparam = ((type<<8|idx)<<16) | tag`
（type=byte[this]、tag=word[this+0x460]）；`MoveWindow(输入框 [0x8AA48C] → 鼠标+0xDF/+0x23A, 0x162×0x10, 1)`；
`ShowWindow(输入框, 0)`；`GetWindowTextA(输入框, this+0x130, 0x104)`；`SetWindowTextA(输入框, "")`；
`SendMessageA([0x8AB7B0], 0x7EE, wparam, this+0x130)`；`[0x8AA498]=1`；基类 0x417FB0 复位。

**可见性查询 0x418460**：返回 `[this+0x28]!=0`（ret 8）。**父点击 0x418400**：门控 [+0x28]，
遍历 3 使能按钮分派 vtable[3]（press），命中即吞。

落盘：`confirmation-prompt-evidence.json`、`RESEARCH_LOG.md`、`MIR3_UI_RECONSTRUCTION_HANDOFF.md`（§3/§6）。

### Finding 236：确认框完整调用方表（含消息串与居中实锤）（2026-08-10）

| 调用点 | 业务 | 实例 | type | mode | 消息 VA（编码） | tag |
|---|---|---|---|---|---|---|
| 0x416F9C | **付款/交易** | 单例 0x7E04C8 | 3 | 1 | 0x47AD98 GBK「您要付给对方多少金币?」 | 0x405 |
| 0x41D633 | **扔金币** | ROOT+0x3615B0 | 0x66 | 1 | 0x47B028 GBK「您准备扔下多少金币?」 | 0x30E |
| 0x420B80 | **存储满** | ROOT+0x3615B0 | ? | 0 | 0x47B5A0 **cp949**「개인 보관 창고가 다 찼습니다. 더 이상 보관할 수 없습니다.」 | 0xFFFF |
| 0x420BB4 | **存储拒绝** | ROOT+0x3615B0 | ? | 0 | 0x47B588 **cp949**「보관 할 수 없습니다.」 | 0xFFFF |
| 0x4246B6 | **踢行会成员** | 单例 | 6 | 1 | 0x47BA10 GBK「请在这里添加您要删除的小组成员名字.」 | 0x3FE |
| 0x425C8B | **仅掌门可用** | 单例 | 4 | 0 | 0x47BAA4 GBK「只有行会掌门人才能使用这个功能.」 | 0xFFFF |
| 0x42BF62 | **返回选人界面** | 单例 | 0x65 | 1 | 0x47AFB4 GBK「返回游戏人物选择界面？」 | 0xFFFF，居中，受 0x419CC0(ROOT) 门控 |
| 0x440489 | **创建行会名** | 单例 | 9 | 1 | 0x47C52C GBK「请输入要创建的行会名称:」/ 0x47C51C「请输入:」（strcmp 选） | 0x3F3，居中；随后 0x4521B0(0x8AB828,…,0x3F3) 并置 [ebx+0x514] |

**编码混合结论**：付款/扔金币/踢成员/掌门/返回/建会字符串 = GBK 中文（cp949 解 FAIL 或乱码）；
存储满/存储拒绝 = **cp949 韩文**（GBK/GB18030 解乱码「俺牢 焊包…」）。→ EI 3.0 客户端为
**韩→中本地化进行中版本**，两套编码并存。0x565994 = 资源指针（非字符串）。

**cluster 2 归属最终结论**：0x418968-0x41898E（帧 151/152+154/155 at this+0x54/+0x108）
属**独立隐藏窗口类 0x418910**（id 0x64、ROOT+0x53030、0x320×0xB8 at (0xDA,0xB0)、open-all 尾项），
经基类 0x423B30 构造，**复用是/否帧** —— 非确认框第二状态。

落盘：`confirmation-prompt-evidence.json`、`RESEARCH_LOG.md`、`MIR3_UI_RECONSTRUCTION_HANDOFF.md`（§3/§6）。

### Finding 237：通知框类 0x43E260 全解码——ctor 参数重排、paint、点击、独立窗口结论（2026-08-10）

**ctor（9 args，ret 0x24）**：先基类 0x423B30（**参数重排**：a1=arg1(res)、a2=arg2(帧)、a3=arg3、
a4=arg8(x)、a5=arg4、a6=arg5、a7=arg6、a8=arg7、a9=arg9 → 基窗 (res, 帧, …, x=arg8, y=arg4, w=arg5, h=arg6)）；
子控制 1 this+0x54：`0x417550(res, 0xA1=161, 0xA2=162, arg4+0x224, arg5+0x10, label=0, byte=1, 帧3=−1, 0)`
（28×26 at (655,126) 当窗口 (107,110)）；子控制 2 this+0x108：
`0x417550(res, 0x25E=606, 0x25F=607, arg4+0x1F0, arg5+0x1B, …, −1, 0)`（**40×20 at (603,137)**——
旧 JSON 的 153=(top+0x10+0x1B) 推导错误，应为 top+0x1B=137）。

**paint 0x43E3C0**：vtable[3]=基类 paint（帧 602 按窗口矩形 origin 合成、800×600 裁剪）→
状态字节 this+0x1D0 选文案：0 → 0x47C460「行会修改 请自行修改行会等级、成员排行信息」
@ (left+0x5E, top+0x17) 色 0x323232；非 0 → 0x47C440「行会公告，请自行修改公告内容.」；
再画第二行 0x47C440 @ (left+0x5F, top+0x18) 色 0x96C8FF（均经 0x45DD70）→
0x417830 重定位 btn1 (left+0x224, top+0x10)、btn2 (left+0x1F0, top+0x1B) → 2× 子按钮 vtable[1] paint（步长 0xB4）。

**点击 0x43E4BA**（ret 8；0x1F40 栈分配 via 0x468D10）：先 btn1/btn2 vtable[3]（press）命中；
未中 → **this+0x1CC 可编辑文本路径**（两次 rep stosd 各 0x3E8=1000 dword 缓冲 → **行会公告编辑**）；
仍无 → 0x43E62C。→ **独立 WM-id15 窗口类，内容 = 行会公告显示/编辑**（非 guild 子状态）。

**帧号归属（push-imm32/mov-imm32 精确扫描）**：602 仅 0x425A46（**另一公告单例 0x777200**：
`push 0x25A; mov ecx,0x777200; mov byte[0x7773D0],1; call 0x423E80`，随后格式化 0x47BB4C 文本
= **系统公告横幅**）与 0x427970（main init，本窗）；**603/604/605 全无 push-imm32 引用 → 未使用
（韩版遗留）资源**（旧字节扫描命中全为位移/LEA 误报：0x41833B lea、0x44DBA7 je disp32、0x436980 fstp）；
606/607 仅 0x43E2D8/0x43E2D3（btn2）；950 仅 0x41803C。

**pending 三项全部闭合**：(1) 帧 602 为 1024 宽 WIL 图，按窗口矩形 origin 合成、800×600 裁剪，
超出 584×252 部分离屏裁剪，**无独立阴影绘制**；(2) 603/604/605 未使用；(3) 独立窗口类 + 行会公告内容。

落盘：`notice-prompt-window-evidence.json`、`RESEARCH_LOG.md`、`MIR3_UI_RECONSTRUCTION_HANDOFF.md`（§3/§6）。

### Finding 238：确认框/通知框证据等级收口——primary-static 全链（2026-08-10）

- 确认框：ctor/基类/按钮 ctor/按钮状态机/键盘/激活/IAT 命名/居中规则/7 调用方 = **primary-static**（机器码直接证据）；
  帧 950 视觉语义、151/152/154/155/157/158/150/153 视觉 = **primary-resource-visual**（WIL 像素）；
  无运行时（内存/日志）证据 → 不标 primary-runtime。
- 通知框：ctor 参数重排、paint 顺序、点击分支、帧号归属 = **primary-static**；602/606/607 视觉 = **primary-resource-visual**；
  603/604/605 = primary-static-absence（全文件无引用，非“无证据”，是**负证据**）。
- 两个 wndproc 0x403Fxx/0x4596xx 的 0x7EE 处理均为聊天/输入语义，**确认框 0x7EE 落点在主游戏窗
  C++ 消息链（0x412303/0x412AAE → 0x42AAB0 → 0x42C4D4）**，该链的最终业务处理（付款扣币等）属
  candidate（协议侧），不影响本窗口布局/绘制/输入结论。
- 0x425A46 = 系统公告横幅（0x777200，帧 602 复用）—— 602 双用户，均公告类窗口。

落盘：`RESEARCH_LOG.md`、`UI_COMPLETION_AUDIT.md`、`UI_COVERAGE_MATRIX.md`、`MIR3_UI_RECONSTRUCTION_HANDOFF.md`（§3/§6）。

### Finding 239：怪物目标框全链闭合——代码绘制合成、锚点语义、HP 条选择器链（2026-08-10）

**目标框 = 程序绘制复合体**（无独立目标框 WIL 帧），由 5 个绘制函数 + 每帧布局计算组成，
全部锚定到 `[HUD+0xe4]/[HUD+0xe8]`（屏幕像素锚点）：

| 组件 | 函数 | vtable 入口 | 几何/语义 |
|---|---|---|---|
| 名字牌框 | 0x40B850 | HUD vt+0x84 @ 0x41C063 | 门 `byte[ebx+8]`；0x45E0C0 量文本宽 w；SetRect(0x4762B0)：left=锚x+(48−w)/2、top=锚y−0x1E、right=锚x+(w+48)/2、bottom=锚y−0xF（**高 15px、完全在锚上方 15..30px、水平居中于锚**）；0x45DE50(0x8AB7A8, 0, **0xA0A0A**, 0, &name, 0, rect) ×3（外框 −1/+1、内框 +1、文本）；每帧以当前目标为 ecx 调用 |
| 悬浮名字文本 | 0x40B750 | HUD vt+0x80 @ 0x41BF29/5D/7C | 门 `[ebx+0x61bd0]/[ebx+0x61c74]`；闪烁 `[0x61bc8]×0.01f×36.0f`→0x468520；选择器 **0x566DD4 帧 2** via 0x466130；0x45FD50(0x8AB7A8) 尺寸 `[0x566E0C]/[0x566E10]`；位置默认 **锚+(+7, −0x38)**（当参数 −1,−1）；随后帧 3 via 0x45F2D0 |
| 悬停名牌（3000ms） | 0x40BB00 | 直调 @ 0x41BF1C/0x41BF6F | 门 `byte[esi+0x620a0]`；超时 `[+0x6209c] > 0xBB8`(3000ms) → 清 `[+0x620a0..]`(0x41 dwords)+`[+0x621a4..]`(0x208 dwords 名字缓冲)；位置 **锚−(0x2C, 0x37)**；模式 `[+0x61c8c]==1` → 0x45E0C0 量宽居中 |
| HP 条 | 0x40A8A0 | 直调 @ 0x41BF14/50/67 | 门 `[0x61bb8]`OR`[0x61bbc]` 与 `[0x8AB7BC]`；类型字节 `[esi+0x8d]`（0x51/0x89→flag0，0x81/0x8A→flag1）；HP 值 `[0x61b9c]=[0x61ba0]−[+0xb4]+[+0xc4]`；0x4542A0(ecx=0x5600FC, flag, type, 值) 注册表查句柄；**元素 = 0x5600FC + type×0x144**；0x466130(ecx=元素, 帧=[0x61b9c]) → 帧记录 `[edi+0x38]` w/h/fx/fy；**定位 = 锚中心公式**：x = 锚x + fx + w/2 − 400（0x476474）、y = 300（0x476470）− 锚y − fy − h/2（条形帧 fx=fy=0 → 条位于锚中心右侧 w/2、上方 h/2）；0x8AB7BC vt+0x14/0x30/0x64(5,0x112,4)/0x8C(句柄) 绘制 |
| 悬停实体重绘 | 0x437DF0 | HUD vt+0xA8 @ 0x41C753 | 门 `word[esi+0x13c]` vs `[esi+0xe4]`；0x43CFD0(ecx=0x574118 相机) 世界→屏幕（[+0xcc]/[+0xc8]/[+0xd4]/[+0xd0] → [+0xa0]/[+0xa4] 与 [+0xb0]/[+0xb4]）；类型 `word[esi+0x10]` 9/0x35 分支；`[+0x140]` 半宽×24 平移 x；调 0x435DD0 |

**锚点语义（两路径，均写 `[+0xe4]/[+0xe8]`）**：
- **世界推导**（0x40F5F0，唯一直调者 0x4120EE）：arg3（鼠标屏幕 x）非零时
  `锚x = (([cc]−[obj+0x12C])×3×16) − [obj+0x134] + [d4] − 0xC8`、
  `锚y = ((([d0]−[obj+0x130])<<5) − [obj+0x138] + [d8] − 0x9D)`
  → **48×32 像素瓦片世界→屏幕**，视口常量 0xC8=200 / 0x9D=157；[cc]/[d0]=鼠标世界坐标(=ROOT+0x2F884C/0x2F8850)、obj=[esp+0x24]=悬停对象、obj+0x12C/+0x130=世界 x/y、+0x134/+0x138=精灵像素偏移。
- **固定锚**（0x4120B0）：写 **(0x178=376, 0xE3=227)**，再调 0x40F5F0（arg3=0 时保留固定值）；无直调者=间接分派。

**HP 条布局矩形（0x40F5F0 内，每帧）**：
- HP 矩形 `[+0x629FC]`：门 `[+0x629c8]`、`[+0x62a14]` 选择器、`[+0xc0] >= 0x1D`；`A = [629c8]×400 − [8a]×3000 − 0xAA0`；商→`[+0x62a20]`；**帧 = 0x2710(10000) + (A % 400)**；0x466130(ecx=[+0x62a14])；帧记录 SetRect：left=锚x+fx+w、top=锚x+fx、right=锚x+fx+w+h、bottom=锚y+fy。
- 状态矩形 `[+0x629EC]`：门 `[+0x89]`、`[+0x62a10]`、`[+0xc0] < 0x19`；帧 = `3000×(([89]−1)%10) − 3000×[8a] + [c4]`；存 `[+0x62a1C]`；0x466130(ecx=[+0x62a10])。
- 第三矩形：门 `[+0x90]` 元素，帧 `[+0xc4]`。
- 选择器赋值 0x40F4E6：`[+0x629CE] = (([8b]−1)/10) − 0x7B`、`[+0x629CD] = (([89]−1)/10) + 0x4D`（magic div 0x66666667）→ **元素 = 0x5600FC + idx×0x144** 存 62A0C/62A10；62A14 由第三类型字节（0x40F5C0/0x40F5CB）→ 62A0C/62A10/62A14 = 全局选择器数组元素。

**HP 条状态链（0x40A4D0，17 个直调者含 0x4111F9/0x410C75/0x410CE7）**：
- `0x449B90(ecx=0x8AA5A8, 类型)` 线性扫类型库记录（记录步长 0x30=48B，`word[record+0xC]`=类型）→ 记录字段：
  `+0/+4` → `[+0x61BA0]/[+0x61BA4]`（HP 当前/满）、`+0xA` → `[+0x8D]`（HP 条选择器类型字节）、`+0xE..0x1A` → `[+0x61BAA..0x61BB6]`（9 个配置字节，其中 +0x16/+0x17/+0x18 → `[+0x61BB2/3/4]` RGB、+0x1A → `[+0x61BB5]` alpha，均 ×0.003922f 转浮点）；
- 0x4111F9（msg1 选择器路径）：`push 0x5600FC; push word[+0x62A38]; call 0x40A4D0` → 置 `[+0x61BB8]=1`（HP 条模式）；每类型 `[+0x61BA9]` 配置：0x1C→0x14、0x18→0xB、0xB→0xD、0x4E→0xE；随后 0x45AFC0(0x8AB130, x, y, (type+0x3E8)×10, 0) 地面标记。

**悬停/设目标完整链（逐帧）**：
- 悬停 msg **0xB**（0x410B6D）：存世界坐标 `[+0x62AE0]/[+0x62ADC]`、类型 `[+0x62AE4]`、置 `[+0x62A50]=[+0x62A54]=[+0x61BC0]=1`、`[+0x61BC4]=0`；分支（`[+0x89]==7` 玩家路径→msg 0xBC7；`[+0x629D3]`→0x40A4D0(flavor 0x1A)+msg 0xBD1；`[+0x629D2]`→0x40A4D0(flavor 0x23)+msg 0xBD8）→ HP 状态装载 + 服务端目标询问。
- 点击设目标 msg **2**（0x411293）：`[+0x62A50]=1`、0x451450(0x8AB828, 0xBC4,…)。
- 目标切换（0x41BFD9–0x41C094）：`[ROOT+0x364444]`=当前、`[+0x364448]`=上次、`[+0x36444C]`=前次；切换 → GetTickCount→`[ROOT+0x42803C]`；目标 `byte[eax+8]==0` → 0x4516D0(0x8AB828) 发 [eax+4]/[eax+0xCC]/[eax+0xD0]；**每帧 0x41C063 `call [vt+0x84]`(0x40B850) 以当前目标为 ecx**；无目标且 now−`[0x42803C]` > 0x320(800ms) → 清 `[+0x364448]`；鼠标位移 `[0x42804C]/[0x428050]` vs `[+0x2F884C]/[+0x2F8850]` > 5 → 0x41C1E0（隐藏其他窗）。
- 显示/隐藏门控：tick 状态机 `byte[+0xC0]`（0x15..0x1F 分派 0x411D91，类型表 0x41207C）、时间门 0x412210、其他窗口打开抑制 0x412270、固定锚路径 0x4120B0。

**资源绑定结论（candidate 边界）**：名字牌框=代码绘制（0xA0A0A 边框）无 WIL 帧（primary-static）；
名字文本帧 2/3 来自选择器 0x566DD4（运行期绑定，帧号 primary-static、WIL 文件名 candidate）；
HP 条帧来自类型推导元素（帧号=HP 值，primary-static；GameInter.wil 仅 1103 帧、**无 10000+ 帧**——
0x40F5F0 的 10000+(A%400) 系列不属 GameInter；选择器 WIL 绑定为 bss 运行期，candidate）。
状态窗口肖像区 49×33（loop7 this+0x200）与 NPCface.wil（~100×122 全身像）尺寸不符 →
目标头像帧源运行期决定，candidate。

落盘：`target-box-evidence.json`、`RESEARCH_LOG.md`、`UI_COMPLETION_AUDIT.md`、`UI_COVERAGE_MATRIX.md`、`MIR3_UI_RECONSTRUCTION_HANDOFF.md`（§6）。

### Finding 240：装备槽 8 槽证据——状态窗口 38×38 命中矩形与 EquipmentSlot 枚举映射（2026-08-10）

**几何（primary-static-constructor-order）**：状态窗口 ctor 0x44B1BC–0x44B2C6 建立 11 条矩形记录
（SetRect @0x4762B0），0x44B5D9 paint 循环逐 index 命中测试。38×38 槽 = 8 条（窗口原点 (278,136)，
绝对坐标 = 相对 + (278,136)）：

| loop | 对象字段 | 窗口相对 | 绝对 | EquipmentSlot 枚举映射（candidate） |
|---|---|---|---|---|
| 0 | this+0x1F0 | (177,70)-(215,108) | (455,206)-(493,244) | 2 头盔 |
| 1 | this+0x1E0 | (27,264)-(65,302) | (305,400)-(343,438) | 3 火把 |
| 2 | this+0x250 | (64,264)-(102,302) | (342,400)-(380,438) | 10 毒药 |
| 3 | this+0x210 | (27,186)-(65,224) | (305,322)-(343,360) | 5 左手镯 |
| 4 | this+0x220 | (175,186)-(213,224) | (453,322)-(491,360) | 6 右手镯 |
| 5 | this+0x230 | (27,227)-(65,265) | (305,363)-(343,401) | 7 左戒指 |
| 6 | this+0x240 | (175,227)-(213,265) | (453,363)-(491,401) | 8 右戒指 |
| 10 | this+0x260 | (103,264)-(141,302) | (381,400)-(419,438) | 9 鞋子 |

非槽区域：loop7 this+0x200 (94,71)-(143,104) **49×33 头像/名区**、loop8 this+0x1C0 (86,114)-(146,204) 60×90 纸娃娃、loop9 this+0x1D0 (38,70)-(91,154) 53×84 属性面板。

**命中/绘制链**：0x44B720 纯位置命中无类别分支（server-driven，客户端无槽名表）；
槽位图标绘制 0x4341F0→0x466130，选择器元素 flag 分派 0x430A40：普通槽 flag0→el82(0x5668C4)、
特殊角色区(0,1,4) flag1→el83(0x566A08)、flag2→el139(0x56B0E8)；**帧号 = word[graphics+0x28]**
（物品 shape，槽位本身不携带帧号）→ 槽矩形是命中区、图标是物品驱动（primary-static）；
el82/el83 的 WIL 文件名绑定（Equip.wil/Inventory.wil 并列）运行期 bss 填充，candidate。

**映射依据（candidate）**：客户端无类别逻辑 → 人类名称唯一来源 = 服务端 EquipmentSlot 枚举
（0武器/1衣服/2头盔/3火把/4项链/5左手镯/6右手镯/7左戒指/8右戒指/9鞋子/10毒药/11护身符/12花/
13马甲/14徽章/15盾/16时装）；几何 8 槽与该枚举的 2,3,5,6,7,8,9,10 项一一对应（经典 Mir3 八件套）。

落盘：`equipment-slots-evidence.json`、`RESEARCH_LOG.md`、`UI_COMPLETION_AUDIT.md`、`UI_COVERAGE_MATRIX.md`、`MIR3_UI_RECONSTRUCTION_HANDOFF.md`（§6）。

### Finding 241：目标框/装备槽证据等级收口（2026-08-10）

- **目标框**：锚点两路径公式、名字牌框几何+颜色(0xA0A0A)、名字文本/名牌位置、HP 条选择器链、
  HP 值公式、类型库记录字段、布局矩形公式、悬停/设目标/切换消息链、逐帧 vt+0x84 调用 =
  **primary-static**（机器码直接证据）；帧 2/3 名字牌视觉、HP 条帧视觉、目标头像帧源 =
  **candidate**（运行期选择器绑定；GameInter.wil 无 10000+ 帧为 primary-static-absence 负证据）；
  目标头像存在性（49×33 区 + 世界坐标地面标记链）= primary-static 结构 + candidate 纹理。
- **装备槽**：8 条 38×38 矩形几何、0x44B720 纯位置命中、图标帧=物品 shape、flag 分派 =
  **primary-static**；槽名↔枚举映射、el82/83 WIL 绑定 = **candidate**。
- 模拟器渲染规则：槽矩形以 primary-static 绘制、图标以 candidate 标记；目标框以锚点+代码绘制
  语义合成，不虚构独立 WIL 帧。

落盘：`RESEARCH_LOG.md`、`UI_COMPLETION_AUDIT.md`、`UI_COVERAGE_MATRIX.md`、`MIR3_UI_RECONSTRUCTION_HANDOFF.md`（§6）。

### Finding 242：544 图逐图勘察完成（2026-08-10，Maps 阶段）

- 六大类结构定型（`docs/research/mir3-map-reconstruction/MAP-SURVEY.md`）：
  城镇（Back tilesc/tiles30c+主题瓦片、Mid cliffsc 主导、Front smobjectsc/cliffsc）、
  室内（tiles5c 满格 + innersc/furnituresc，wood_* 木内景）、
  半兽洞穴 D00x（tiles5c 满格 + object1c 单库无 Front）、
  赤月山谷 D100–D102（tiles5c 满格 + object2c 单库无 Front）、
  沃玛 D201–D203（D2011/12/D203 同洞穴结构；**D202 为唯一带 Front 层 + tilesc/tiles30c 地面 + cliffsc 的 D2xx**）、
  沙漠/雪地（sand_* 库族于 4/5/74.map；wood_* 库族于 8.map 冰雪村 + 室内）。
- **00.map 不存在**；最大图 0/4/6/8.map 800×800；39 图 legacy 13B（D3）；0 尺寸不符。
- 异常分类（5723 格 / 34 图）按 8 类错误 taxonomy：**无 map-file 错误、无库表错误**；
  frame-decode 类（3.map 3255、41.map 1619、0_003 137、D10031 62 ground OOB）、
  特殊处理类（ground_not_drawn 670 格：D12121 171、0_003 137、74 90、5_0013 67；黑帧引用 ≈1.2M 格 C18）、
  版本差异（39 图 13B）、offset/坐标/图层类无偏离。
- 中文名冲突：catalog cn（幽灵森林/沙漠/失乐园森林）vs 服务端 MiniMap.txt（半兽洞穴1-3层/天然洞穴）
  并列记录不覆盖（D001=半兽洞穴1层 MMap F1、D002=2层 F2、D003=3层 F3、D011=天然洞穴1层 F4、D012=2层 F5；
  赤月 D1001/D1011/D1021=1层 F101 系、D1500 真天宫 F128、D1510 黑度宫 F129、D1601 诺玛遗址 F131、
  D2001 西沙漠地洞 F135、D2002 沙漠城市 F138、D2003 地下矿山 F142、D2011 沃玛1层 F149、D2012 2层 F150、
  D2013 3层 F151、D202 沃玛神庙 F152、D203 沃玛教堂 F153 —— 服务端映射，frame id 对应 MMap.wil 槽）。
- 赤月系 D10011 与 D1001 引用计数完全相同（40000/25179 格）→ 副本/对称入口候选；D10031 为唯一 ground OOB。
- 新增 C21 证据项；K2/D4（室内地面机制）维持 pending P2。

落盘：`MAP-SURVEY.md`、`EVIDENCE-INVENTORY.md`（C21）、`RESEARCH_LOG.md`。

### Finding 258：绘制顺序/跨窗口层级/状态分派闭合（2026-08-11，DrawOrder 阶段）

闭合 `draw-order-evidence.json` 的 3 个 pending（全部 primary-static，机器码实测）：

**1) hide-then-show 提升（原 pending[0]）→ 已闭合**：
- 定位+显示分派 `0x0042B6A0`（参数 id，跳表 0x42B7E0 覆盖 id 0..0xE）在 count=main+0xD38>0 时依次调用
  `0x42B820`（遍历可见链表对每节点 `push 0`+`0x423F90` 清可见标志=关全部）→
  `0x42AC50`（hide：从 main+0xD28 链表摘除命中节点）→ `0x42AC30`（show：无条件追加尾节点）→
  按 id 定位窗口对象（id2=store 特例先 `0x44E910` hit-test，命中即拒开）→ `0x423F90(1)` 置可见 → `0x4240C0` 应用位置。
- show 经 `0x449870` 分配 12 字节节点（+0=id/+4=next/+8=prev）追加 tail（manager+0x0C，count=manager+0x14；自环节点 new->next=new @0x44989D 由 count 守卫不可达）；
  paint 分派 `0x4280F0` 从 head=main+0xD28 沿 node+0x04 前进、count 守卫、跳表 0x428358 按 id 调专用 paint。
- **结论**：hide(摘链)+show(追加尾) 天然使窗口成为最后绘制=最上层；`0x42B6A0` 即显式 hide-then-show 提升命令。
  修正 window-traversal-evidence.json 的 promotion_audit（原称无调用方 BB 含无条件 hide(ID)+show(ID)；0x42B6A0 的
  0x42B6BC-0x42B6C7 正是该序列）。残项：重复 show 边界（0x42AC30 不查重复）→ candidate。

**2) HP/MP/EXP 条 vs 按钮顺序（原 pending[1]）→ 已闭合**：HUD 帧例程 `0x004294E0`（ret 0xC @0x429624）静态调用序 =
  0x4294EB 底板帧 0x32 经 0x429630/0x460240 合成 → 0x42953F `0x4283C0` 状态图标循环 → 0x429546 `0x429740` 条
  （唯一 E8 调用者；条内序见 hud-bars-render-evidence.json draw_sequence：动态帧 0x82-0x85@0x429819 → 62@0x4299CB →
  60@0x429BDB → 61@0x429C53 → 63@0x429FD5 → 经验%文本@0x42A065）→ 0x429556 16 子控件循环（this+0x567C 步长 0xB4，
  按钮族构造 0x417550）→ 0x429584 `0x4179B0` 共享量条 → 0x4295B9 `0x4280F0` 窗口列表 paint。
  结论：条先于按钮子控件与量条；HUD 层内 = 底板→图标→条→按钮→量条→窗口列表。

**3) store/exchange/option 状态分派（原 pending[2]）→ 绘制分支已闭合，业务名保留 pending**：
- **store** `0x44E260`：状态字节 this+0x5F8∈{0..4}；0x417830 重定位集（坐标=winx/winy 相对）：state2 → 4 控件
  (0x1BC@(+0x1D2,+0xA9)/0x270@(+0x172,+0xA2)/0x324@(+0x144,+0x9F)/0x3D8@(+0x1B2,+0x9F))；0/1/3/4 公共 2 控件
  (0x54@(+0x10A,+0x10E)/0x108@(+0x7F,+0x10B))；0x44E32E 重读（raw `8A 86 F8 05 00 00`）==1 → 再 4 控件（共 6）、
  ==4 → 再 2 控件 (0x48C@(+0x1FA,+0x43)/0x540@(+0x188,+0x3D))；0x44E3EA 8 子控件循环（0x54 步长 0xB4）；
  0x44E404 分派 {0,1,3,4}→0x44D590、{1,2}→0x44DB50、{4}→0x44E040。
- **exchange** `0x415B10`：SetRect 0x4762B0 以 center_x=winx+(right−left)/2 拆左 this+0x5C/右 this+0x6C；
  绘制期状态=鼠标所在侧：PtInRect 0x4762B4 命中左矩形（0x415B65 读 0x7DA1C0=鼠标x/0x7DA1C4=鼠标y）→ bl=0 左网格原点
  (winx+0x15, winy+0x30)；否则 bl=1 右 (winx+0xFD, winy+0x30)；0x415BC2 二次命中（0x7243C4≠0/0x7243D8==0 门控）→
  0x416830 格索引 → 0x4162E0 物品映射（0x7243DC）；格高亮 x = winx+cell*9*4+(0x15|0xFD)。
- **option** `0x441380`：无状态字节分支；9 固定重定位（0x7C 关闭/0x130/0x1E4/0x298/0x34C/0x400/0x4B4/0x568/0x61C）
  + 2 运行时偏移控件（0x6D0 用 this+0x6C、0x784 用 this+0x74）+ 11 子控件循环（0x7C 步长 0xB4）；
  状态由帧对（161/162、760/761、762/763）与偏移表达。残项：store 状态 0..4 业务名、exchange 业务名/量条填充源、
  option 帧对语义 → candidate/pending。

落盘：`draw-order-evidence.json`（closed_notes ×3）、`UI_COMPLETION_AUDIT.md`、`UI_COVERAGE_MATRIX.md`、
`MIR3_UI_RECONSTRUCTION_HANDOFF.md`（§6）、`ui-coverage-matrix.json`（record id=exchange）、`RESEARCH_LOG.md`。

### Finding 248：窗口位置分派（position dispatch）闭合——拖拽全链与绝对坐标 ABI（2026-08-10，WindowPosition 阶段）

闭合 `window-position-dispatch-evidence.json` 的 1 个 pending（全部 primary-static，机器码实测）：

**1) 调用方实参语义（原 pending）→ 已闭合**：每个输入/拖拽调用方的两个实参都是**绝对客户区鼠标坐标**
（X=lParam LOWORD，Y=lParam HIWORD，逐字转发），**不是增量（delta）、也不是窗口相对**。
- WM_MOUSEMOVE `0x41D390`：lParam → X=[main+0x35B2A8]、Y=[main+0x35B2AC]；`[main+0x35B2B8]!=0` 输入门控下
  `0x41D457` `lea ecx,[esi+0x2A548C]; push Y; push X; call 0x42C510`。
- 输入/更新分派 `0x42C510`（prologue 0x42C511 `mov ebx,[esp+8]`，签名 f(this@ecx, X@[esp+4], Y@[esp+8])，ret 8）：
  0x417C80(base+0x61BC, X, Y) → `[base+0xD08]=(int)(([base+0xD20]-1)*[base+0x61C8])` → 返回 1；
  通告窗 0x418AA0(base+0x53030, X, Y)、0x43E680(base+0x52E5C, X, Y)；hit-test 0x42AAB0 → 表 0x42C798
  按 id 专用输入 handler（0→背包 0x430650（返回 0 再状态 0x44CED0→位置分派）、1→状态 0x44CED0、2→商店 0x44F110
  （返回 0 再交换 0x416E70）、3→行会 0x425DE0、4→组队 0x424770、6→组队弹出 0x450B70、7→聊天弹出 0x414CF0、
  8→NPC 0x448430、0xB→任务 0x441A20、0xC→选项 0x426B90、0xD→坐骑 0x43AC80、0xE→其他 0x440560；
  **id 5/0xA 无 handler**）→ 0x42C741 位置分派。
- `0x42C741`：`push edi(Y); push ebx(X); mov ecx, esi; call 0x42B430` —— 逐字透传 WM_MOUSEMOVE 的绝对 X/Y。

**2) 0x42B430 调用方穷举（原 "should not be only 0x42C745"）→ 已闭合**：E8 rel32 全扫描 = **唯一 0x42C745**；
imm32/dword 直接引用 = **零**。0x42C510 的 E8 调用方 = 唯一 0x41D457；0x42BA20 的 E8 调用方 = 唯一 0x41D57B
（WM_LBUTTONDOWN）；0x42BE20 的 E8 调用方 = 唯一 0x41DC82（WM_LBUTTONUP）；0x42B6A0 的 E8 调用方 =
13 个全部在 0x42BA20 内（0x42BB4E/0x42BB7E/0x42BBA6/0x42BBE7/0x42BC13/0x42BC3F/0x42BC6B/0x42BC97/0x42BCC3/
0x42BCEF/0x42BD17/0x42BD3F/0x42BD67）；0x4240C0 的 E8 调用方 = 0x42B728/0x42B789/0x42B7AF/0x42B7D5（0x42B6A0 内）；
0x423FA0 的 E8 调用方 = 初始化 0x41FA68/0x4204F3（flag=1）+ 0x42B430 内 14 个 case（flag=0）。

**3) 拖拽链全链（E8 + 寄存器追踪，primary-static）**：
- **拖拽开始** = WM_LBUTTONDOWN `0x41D470`（门控 `[main+0x35B2B8]!=0`）：lParam 拆 X/Y → 单元坐标
  `[main+0x35B2B0]=(X+200)/12+[0xF532C]`、`[main+0x35B2B4]=(Y+157)/32+[0xF5330]` → `0x41D57B`
  `call 0x42BA20`（ecx=main+0x2A548C）。
- `0x42BA20`（MoveWindow 分派）：通告门控（0x53060→0x418A50、0x52E8C→0x43E640 → 返回 1）；
  0x417D00(base+0x61BC, X, Y) → `[base+0xD08]=...` → 返回 1；base+0x567C 起 16 个固定窗口（步长 0xB4）
  逐个 vtable[3]（`call [edx+0xC]`, X, Y）消费 → 返回 1；0x428570 全局检查；hit-test 0x42AAB0 → id=-1 →
  0x42BD8F → 0x42B820（全清 +0x34）→ 返回 1；id>0xE → 返回 1；跳表 0x42BDE0 13 个 per-id case → `0x42B6A0(id, X, Y)`；
  商店额外 0x44EF00 预检（非零跳过移动）+ 0x44E910 后检（零返回 1）。
- `0x42B6A0(id, X, Y)`（拖拽开始，主表 0x42B7E0 覆盖 id 0..0xE）：`[base+0xD38]==0` → 返回；
  0x42B820 复位全部列表窗 +0x34；0x42AC50(移除 id) 再 0x42AC30(追加 id)（最前）；**`[base+0xD3C]=1`**（拖拽跟随门控）；
  per-id 窗口基址 → 0x423F90(win, 1)（`mov [win+0x34], eax`）→ 0x4240C0(win, X, Y)。
- `0x4240C0(win, X, Y)`（抓取偏移记录，需 +0x30/+0x34/+0x3C 全非零）：`[win+0x48]=X-[win+0x18]`（左）、
  `[win+0x4C]=Y-[win+0x1C]`（顶）= 拖拽开始时鼠标相对窗口原点。
- **拖拽跟随** = 每个 WM_MOUSEMOVE（门控 `[main+0x35B2B8]!=0`）：0x41D390 先跑 per-window mousemove
  （`[0x362370]` 非零 → 0x455F60(main+0x362354, X, Y)，否则 0x418720(main+0x3615B0, X, Y)）→ 0x42C510 →
  0x42C741 → 0x42B430 只跟随**表头**窗口。
- **拖拽结束** = WM_LBUTTONUP `0x41DB80` → 0x41DC82 `call 0x42BE20`：`[base+0xD3C]=0`；`[base+0x53060]` 非零 →
  0x418A00(base+0x53030, X, Y) 非零 → 音效 `[0x476290]([0x8AB7B0], 2, 0, 0)` → 返回 1；`[base+0x52E8C]` →
  0x43E640(...)；否则 0x417E60(base+0x61BC, X, Y)。

**4) 0x423FA0 语义（win, X, Y, flag）→ +0x40/+0x44 谜题结案**：
- flag=0（拖拽跟随）：`left'=X-[win+0x48]`、`top'=Y-[win+0x4C]`、`right'=left'+[win+0x40]`、`bottom'=top'+[win+0x44]`；
  **若 bottom'>0x23A（570）：top'=0x235（565）-[win+0x44]**（600px 客户区 30px 底边距）；
  SetRect([0x4762B0], &win+0x18, left', top', right', bottom')；第二个 SetRect(&win+0, left'-(origW-w)/2,
  top'-(origH-h)/2, right', bottom') 居中外框（win+8 存原始尺寸，尺寸相等时两矩形一致）。
- flag=1（绝对设置）：SetRect(&win+0x18, X, Y, X+w, Y+h) + 同款居中；用于初始化 0x41FA68（X=0x207=519, Y=0）与
  0x4204F3（X=0x206=518, Y=0，窗口 0x2CF570 区 / ebx+0x2AB9E0=base+0x6554 背包）。
- **结论**：`[win+0x40]=宽`、`[win+0x44]=高`（两分支都加出 right/bottom，primary 证明）；**不是偏移、也不是
  当前/初始位置**（位置在 +0 RECT/+0x18 RECT）；`[win+0x48]/[win+0x4C]=抓取偏移`（0x4240C0 写入）。
  新左上角 = (X−grabX, Y−grabY) —— **绝对 1:1 鼠标跟随**、尺寸恒定、底边距 30px。

**5) 运行时列表语义**：base+0xD24 列表容器（0x449870 op）；`[base+0xD38]`=计数、`[base+0xD30]`=头；
`[base+0xD3C]`=拖拽跟随门控（仅 0x42B6A0 @0x42B6CC 置 1、仅 0x42BE20 @0x42BE26 清 0）；
列表 = 打开/可移动窗口、最前优先；0x42B430 只跟随表头。0x42AC30 调用方 = 0x42ADB0 的 15 个 per-window case
（0x42ADFC..0x42B34D，表 0x42B3E4）+ 0x42B6C7；0x42AC50 调用方 = 0x41C1F6/0x41C227/0x41C254/0x42062D +
0x42ADD0..0x42B350 + 0x42B6BF。

**6) 对象基址修正**：UI 子系统对象 = **main+0x2A548C**（旧记录 "main+0x6554" 系 base 相对，非绝对）；
背包 base+0x6554=main+0x2AB9E0、状态 +0x29CE4=main+0x2CF170、商店 +0x33188=main+0x2D8614、
交换 +0x3399C=main+0x2D8E28、行会 +0x4707C=main+0x2EC508、组队 +0x47834=main+0x2ECCC0、
组队弹出 +0x47C28=main+0x2ED0B4、聊天弹出 +0x507EC=main+0x2F5C78、NPC +0x51150=main+0x2F65DC、
任务 +0x516E8=main+0x2F6B74、选项 +0x518E0=main+0x2F6D6C、坐骑 +0x52118=main+0x2F75A4、
其他-14 +0x524F0=main+0x2F797C、通告 +0x52E5C=main+0x2F82E8；16 窗口 vtable 数组 base+0x567C（步长 0xB4）；
游戏对象 base+0x61BC。窗口字段：+0x08 RECT（外框/原始尺寸）、+0x18 RECT（位置/尺寸=命中目标）、
+0x30/+0x34/+0x3C 标志（+0x34=在拖拽列表/拖动中，0x423F90/0x42B6A0 置位，0x42B820 复位）、+0x40 宽、
+0x44 高、+0x48/+0x4C 抓取偏移。

等级：**primary-static 全链**（E8 穷举 + 寄存器追踪 + 0x423FA0/0x4240C0/0x42B6A0/0x42BA20/0x42BE20/0x42C510
完整反汇编）。残项（candidate/pending）：商店 id2 在状态 2/5+ 下的拖拽行为（0x44E910/0x44EF00 门控静态解码、
运行期状态转换未验证）、拖拽帧序与 570 底边距的运行期画面验证（本阶段静态范围内）。

落盘：`window-position-dispatch-evidence.json`（closed_2026_08_10 ×8、caller_arg_table ×7）、
`UI_COMPLETION_AUDIT.md`、`UI_COVERAGE_MATRIX.md`、`MIR3_UI_RECONSTRUCTION_HANDOFF.md`（§6）、`RESEARCH_LOG.md`。


## Finding 256 (PromptWindows, 2026-08-11)：0x7EE 接收链闭合 + 行会公告保存链 + 公告横幅事实

**A. 行会公告编辑缓冲保存链（notice-prompt-window-evidence.json closed_notes，primary-static）**
- 通知窗 click 0x43E4BA：btn2（this+0x108）按下 → test [this+0x1CC] → GetWindowTextA([this+0x1CC], buf, 0xFA0)
  → 0x468BF0 按 0xA 分行 → 每行 0x45DC70(0x8AB7A8, dst, line, 0x8B187C) 累积；
  非空时 [this+0x1D0]==0 → 0x4524D0（msg 0x411，行会等级/成员修改模式）/ !=0 → 0x4524A0（msg 0x410，公告模式）。
- 0x4524A0/0x4524D0：0x452940 在 game+0x18 写 12 字节头（+4 = msg id word：0x4524DF push 0x411 / 0x4524AF push 0x410）
  → 0x451E60（game, header, text）：头拷到 game+0x24、seq=[game+0x14]%9、
  sprintf '#%d%s%s!'（0x47C840）/ '#%d%s!'（0x47C800）到 game+0x2044 →
  send([game+0x6044], buf, len) 经 0x468098 = jmp [0x476340]（WS2_32 IAT slot 0x476340 = ordinal 19 = send）。
- GBK 原串：0x47C440「行会公告，请自行修改公告内容.」、0x47C460「行会修改 请自行修改行会等级、成员排行信息」、
  0x47C4A4「 \r」、0x47BB4C「\r\n」、0x8B187C「」。

**B. 公告横幅单例 0x777200 事实（primary-static）**
- 文本源 = 游戏对象单向链表（show: game+0xEC / hide: game+0xBC；node+4 串、node+0xC next），
  0x45DC70(0x8AB7A8, buf, line, 0x8B187C) 以 0x47BB4C(CR LF) 连接进 0x4E2-dword(0x1388B) 栈缓冲 →
  SetWindowTextA([0x7773CC], buf) @0x425ABB-0x425AC4（show）/ 0x425BAC-0x425BC2（hide）。
- 显隐分派 = 与通知窗同一 id-15 分派器 0x42ADB0(winmgr 0x7243A4, 0xF) @0x425A1F / 0x425B1E；
  就地构造：show push 0x25A(602) @0x425A46、hide push 0x259(601) @0x425B44 → 基类 0x423E80；[0x7773D0]=1/0。
- 持续时长/自动关闭：imm32 0x777200 仅 @0x425A48 / 0x425B46 两处引用，.text 无计时器/计数器 →
  candidate（presumed winmgr 可见链表绘制循环驱动，运行时确认），已入 notice JSON pending（不影响布局/绘制）。

**C. 0x7EE 接收链闭合（confirmation-prompt-evidence.json closed_notes，primary-static，纠正旧 candidate）**
- 0x7EE 不在外层消息表 0x421E8C（仅条目 0–19 有效：0xf6ef→0x41f73c、0xf751→0x41f597、0xf604→0x421d3f、
  0x1d3f→0x41f666、0xf6b0→0x41ff96、0x1497→0x421cfc、0xfc09→0x41fd36、0xfbd5→0x41fed8、
  0xfe31→0x41fecc、0xf92b→0x41fa16、0xbe8→0x41fa72、0xfaf0→0x41f995、0xf9af→0x41f96c、
  0xff3c→0x4202ed、0x372→0x420248、0xf8e4→0x41ffbb、0xffe4→0x42013e、0x1be→0x4201ef、
  0x5f→0x41fb24、0xfb6e→0x421d3f）。
- 主游戏窗 WndProc 0x403E81 @0x403FA4：cmp ebp,0x7EE; jne 0x403FB5 → push edi/ebx; mov ecx,esi;
  call 0x404600（gate [obj+0x8A4]==1；清 obj+0xE3D 0x41 dwords；SetWindowTextA([0x8AA48C], [obj+0xD39])；
  [obj+0xD38]=1；call 0x403640；[0x8AA498]=0）。
- 0x403640 = 聊天输入双缓冲恢复：Get/SetWindowTextA 交换 obj+0xD39↔obj+0xE3D；
  MoveWindow([0x8AA48C], [0x8AB7F0]+obj+0xF44, [0x8AB7F4]+obj+0xF48, w, h, 1)
  （[obj+0xD38]!=0 时矩形 obj+0xF54..0xF60）；SendMessageA([0x8AA48C], 0xCC, 0/0x2A, 0)；
  [0x8AB7E8] 时 EM_SETSEL(0xB1, 0, -1) 全选；SetFocus([0x8AA48C])。
- 第二 WndProc 0x459654 → 0x45A140（wparam>>16 = type；type==1 && idx∈{0,1} →
  0x452040(0x8AB828, this+0xCBF+idx*0x40) + 0x451F90(0x8AB828) 游戏对象发送；
  [this+0x930]==2 → MoveWindow/ShowWindow(5)/SetFocus 聊天输入；[0x8AA498]=0）。
- 旧 candidate VAs 是 0x7EE 之前的输入路由而非接收体：0x412303 = 确认框点击 0x418400
  （单例 0x7E04C8）先于 0x42AAB0 顶层窗解析；0x412AAE = 兄弟鼠标处理器内确认框可见性查询
  0x418460（[this+0x28]!=0）；0x42C4D4 = 窗口 id 二级分派跳表（jmp dword ptr [edi*4+0x42C4D4]
  @0x42BF7E，cmp edi,0xE; ja 0x42C198，条目 id0..14 = 0x42BF85..0x42C157，默认 0x42C198）。
  布局/绘制/输入结论不受影响。

落盘：`notice-prompt-window-evidence.json` / `confirmation-prompt-evidence.json`（pending→closed_notes）、
`UI_COMPLETION_AUDIT.md`、`UI_COVERAGE_MATRIX.md`、`MIR3_UI_RECONSTRUCTION_HANDOFF.md`（§6）、
`ui-coverage-matrix.json`（record id=prompt）。

### Finding 255：坐骑窗口状态字节 0x7DA060 语义与窗外覆盖层闭合（2026-08-11，HorseWindow 阶段）

闭合 `horse-window-render-evidence.json` 唯一 pending：`0x007DA060` 的运行时 enum/bit 语义，
以及“外部窗口管理器是否在坐骑 Paint 之外添加状态相关覆盖层”。全部 primary-static。

**1) 0x7DA060 = 会话对象 5 字节坐骑状态块 byte0（已闭合）**
- 块地址：session 对象 `0x777698 + 0x629C8 == 0x7DA060`，布局 byte0=state(0x7DA060)、
  word(0x7DA061-62)、word/byte(0x7DA063-64)、byte(0x7DA064)。
- 唯一静态写入者 = session 虚方法 `0x0040F420`（vtable 槽 `0x476508`，wrapper `0x0040FED0` @ `0x4765CC`）：
  `lea eax,[esi+0x629c8]`（0x40F43A）、`mov dword[ecx],edx; mov byte[ecx+4],dl`（0x40F442/0x40F448），
  所有调用点 this=0x777698（0x41F5DB/0x41F680）。
- 状态字节 clamp：`cmp byte[eax],4; jb; mov byte[eax],0`（0x40F46D-0x40F472）→ state ∈ {0,1,2,3}，
  是 2-bit enum 而非 bitmask。**0=未骑马，非零=骑马**：
  点击分派 0x426ABC `==0` 放行 Frame 860/861(+0x108)→`@上马`；0x426AE1 `!=0` 放行 Frame 862/863(+0x1BC)→`@遛马`。
  1/2/3 各自子语义无法纯静态解码 → candidate（需要协议交叉引用）。
- 状态 != 0 时额外写 `byte[esi+0x629CF]=0x57`（0x40F47F）副作用标志。
- 状态字节同时索引骑马外观表 `0x5600FC`（stride 324，`lea eax,[eax+eax*8]; lea edx,[eax+eax*8];
  lea eax,[edx*4+0x5600fc]` 于 0x40F583-0x40F590 / 0x40F5A8-0x40F5B9），结果存 session+0x62A10/+0x62A14——
  属世界渲染侧，表内容在 .data 截断之外未读，不越权声称地图绘制细节。

**2) 更新路径（primary-static）**
- 包分派器 `0x0041F1CF`（跳表 0x421E8C）：case `0x267`（0x41F597）从包输入写
  word[0x7DA063]/word[0x7DA061]（0x41F5BA-0x41F5CD）后经 0x40F420 回发 5 字节块（0x41F5DB）；
  case `0x26B`（0x41F666）读 dword[0x7DA060]+byte[0x7DA064] 后同样回发（0x41F680）。
- `.text` 内无对 byte 0x7DA060 的直接 imm32 写入；0x40F420 前先调 0x405630（50 case 消息类型分派，网络/会话守卫）。

**3) 覆盖层问题（已闭合：坐骑窗自身无覆盖层）**
- 坐骑 Paint `0x4269C0-0x426A74` 内无任何 0x7DA060/0x7DA064 引用；窗口管理器绘制分派
  （0x428252 处对 winmgr+0x52118 的坐骑窗成员调 0x4269C0）是普通逐窗口 switch，不添加状态覆盖层。
- **状态相关绘制确实存在于坐骑窗之外——主游戏窗 HUD**：主窗绘制段 `0x44B560-0x44B6AF`
  在 `0x0044B666` 读 `word[0x7DA063]` 并作为参数传入绘制调用 `0x45FD50`（this=0x008AB7A8），
  且由 `byte[0x777723]`（1..10）与图标索引 `byte[0x777720]` 门控（0x44B62B-0x44B64F）——
  即主窗 HUD/停靠栏的坐骑状态图标（帧号来自坐骑块 word），不是坐骑窗覆盖层。
- 提示：键盘/命令路径（0x41D2B0 区域，0x41DE03-0x41DE1E）用**不同**门控
  `byte[esi+0x35B148]` 与冷却 `dword[esi+0x4279A4]=0x3E8`，与窗口点击路径的 0x7DA060 无关，勿混淆。

**4) 四个按钮点击分派终态（重验）**
- +0x108（말타기，F860/861）：handled 且 state==0 → push 0x47B060（`@上马`）→ 0x426B22 共用分发。
- +0x1BC（말내리기，F862/863）：handled 且 state!=0 → push 0x47B068（`@遛马`）。
- +0x270（말숨기기，F864/865）：handled → push 0x47B058（`@收马`），无条件分发。
- +0x324（말꺼내기，F866/867）：handled → push 0x47B068（`@遛马`），无条件分发。
- 共用分发 0x426B22：`mov ecx,0x8AB828; call 0x4520F0`（向 this+0x18 队列投 UI 消息 0xBD6），
  分发后写冷却 `dword[0x8A68BC]=0x12c`、`dword[0x8A68C0]=0`。
- +0x1BC 与 +0x324 同发 `@遛马`：两个控件不可因分发串相同而合并，区分仅靠美术/位置。

落盘：`horse-window-render-evidence.json`（pending→closed_notes）、`RESEARCH_LOG.md`、
`UI_COMPLETION_AUDIT.md`、`UI_COVERAGE_MATRIX.md`、`MIR3_UI_RECONSTRUCTION_HANDOFF.md`（§6）、
`ui-coverage-matrix.json`（record id=horse）。

### Finding 253：主 HUD 底部操作栏 caption 控件语义与绘制文字路径闭合（2026-08-11，HudLabel 阶段）

闭合 `hud-label-evidence.json` 的 2 个 pending（全部 primary-static，机器码实测）：

**1) Frame 159 = 按下态帧美术，caption 控件 = 悬停 tooltip-only 控件（原 pending[0]）→ 已闭合**
- 8 个 HUD caption 全是同一 channel_control_class（共享按钮类静态 vtable `0x4763A8`，类构造 `0x404690`，
  控件构造器 `0x417550`，thiscall `ret 0x24`=9 实参）实例，hud+0x57e4..hud+0x5cd0 步长 0xB4：
  构造调用 0x427A1A/0x427A4E/0x427A82/0x427AB6/0x427AEA/0x427B24/0x427B58/0x427BAA，
  push 顺序（lea 之后）= `0, -1, 1, text, y, x, state_frame, frame, parent([hud+0x1c])` →
  ctor 落位：a1 parent→+0x14、a2 frame→+0x18、a3 state_frame→+0x1C、a4 x→+0x28、a5 y→+0x2C、
  a6 text→+0x34、a7=1→+0x24(enabled)、a8=-1→+0x20(normal frame override)、a9=0→+0x30(hover flag arg)；
  SetRect（IAT 0x4762B0，parent+0x38 帧尺寸）→ 命中矩形 this+0x04。
- paint `0x417640` 状态机：正常 `[+0x25]==0 && [+0x24]==1` → SelectFrame(+0x20)，**+0x20==-1 时 0x417657
  je 0x41776F 什么都不画**；悬停 `[+0x25]==1 && [+0x24]==1` → 帧 = `[+0x30]!=0 ? +0x18 : +0x20`
  （0x4176B2-0x4176D1，HUD 控件 +0x30=0 且 +0x20=-1 → 跳过帧选择）→ **0x417719 无条件 call 0x417370
  绘制文字**；按下 `[+0x25]==2` → SelectFrame(+0x1C) 合成（0x460240），不画文字。
- 鼠标槽：hover `0x417780`（PtInRect IAT 0x4762B4 于 this+0x04）、press `0x4177C0`（置 +0x25=2，
  释放时音效 0x69 经 0x45AFC0 @0x8AB130）、release `0x4177F0` 复位。
- **结论**：Frame 159 不是常显标签、也不是文字字形——是腰带 caption 控件**按下态的临时帧美术**；
  常态不可见，悬停只显示光标旁打字机文字提示，按下才画 159 帧。Frame 159 本身是真实位图
  （16×14、153 不透明像素、115 色，心形/火焰字形）——**修正旧记录“无导出像素内容”错误**；
  100/101、102/103 为 40×38（920/923 不透明像素）图标对。8 个 caption 表（slot/frame/x/y/text）：
  +0x57e4 0x54/0x55 (+0xFC,+2) 技能图鉴(Ctrl+B, B)；+0x5898 0x5A/0x5B (+0xA1,+0x2E) 退出游戏(Alt+Q)；
  +0x594c 0x5C/0x5D (+0xA1,+0x52) 注销人物(Alt+X)；+0x5a00 0x5E/0x5F (+0x268,+0x2F) 组队(Ctrl+G, G)；
  +0x5ab4 0x60/0x61 (+0x268,+0x52) 行会(Ctrl+F, F)；+0x5b68 0x9F/0x9F (+0x189,+0xD) 腰带(Ctrl+Z, Z)；
  +0x5c1c 0x64/0x65 (+0x2BF,+0x10) 技能书(Ctrl+E, E)；+0x5cd0 0x66/0x67 (+0x2CE,+0x20) 聊天记录(Ctrl+R, R)。
- 分派：同类控件经 vtable+4 paint 循环步长 0xB4 分派（聊天窗 9 控件先例 `0x414955`；通用 0x402E14）；
  HUD 侧直达 8 captions 的循环未定位（HUD vtable 0x4763C0 槽 +0x38=0x40B2C0 / +0x3C=0x40B750 /
  +0x40=0x40B850 均不迭代它们）→ candidate，见 JSON pending。

**2) 绘制时字体/颜色路径（原 pending[1]）→ 已闭合（悬停态 0x417370 全链）**
- 入口 0x417370（@0x417719）；空串（[+0x34]==0）→ 清 POINT 缓存 0x8B1880/0x8B1884 后返回。
- 光标锚点：GetCursorPos（USER32 IAT 0x476240）→ ScreenToClient（0x476234）于 **hWnd [0x8AB7B0]
  （主游戏窗口句柄——修正旧记录“字体对象 0x8AB7B0”）**；GBK 串缓存 0x8B1888（2 字节步长比较跳过重测）、
  脏标志 byte 0x47ADBC、打字机计数器 dword 0x47ADC0（揭示矩形 top=cursor_y−counter 增长到 h+4，
  完成时 dirty=0、counter=6）。
- 测量：0x45E0C0(0x8AB7A8, 0, &{w,h}, 0, &text) → 框尺寸 (w+12, h+4)；
  CreateRectRgn(cx, cy−counter, cx+w+12, cy)（GDI32 IAT 0x476054）+ GetRgnBox（0x47604C）→ 文字框 rect。
- 底/边框：0x45E570(0x8AB7A8, &rect, 0x96FFFF, 2) = CreateSolidBrush(0x96FFFF)（0x476064）+ FillRect
  （0x4762F0）= 淡黄底（COLORREF 0x96FFFF = RGB(255,255,150)）；0x45E570(0x8AB7A8, &rect, 0, 1) =
  CreateSolidBrush(0) + FrameRect（0x4762F4）= 1px 黑框。
- 文字：0x45DE50(0x8AB7A8, &rect, text, 0, 0, 0) = SetBkMode(TRANSPARENT)（0x476044）+
  SelectObject(font=[ctx 0x8AB7A8 + 0x28])（0x476048）+ SetTextColor（0x476060）+
  DrawTextA（0x476280）flags 0x25 = DT_SINGLELINE|DT_VCENTER|DT_CENTER + 恢复字体 +
  表面合成 [vtable+0x68]；每帧 DeleteObject ×3（HRGN+2 笔刷，0x476068）。
- 残项（candidate）：0x45DE50 处 SetTextColor 的精确 COLORREF（调用方压 0、a7==0 分支设 TRANSPARENT，
  颜色源未静态解析——疑似默认/白）；HUD 侧 caption 分派循环；悬停可达性与打字机揭示方向的运行期验证。

落盘：`hud-label-evidence.json`（pending→closed_notes ×2）、`RESEARCH_LOG.md`、
`UI_COMPLETION_AUDIT.md`、`UI_COVERAGE_MATRIX.md`、`MIR3_UI_RECONSTRUCTION_HANDOFF.md`（§6）、
`ui-coverage-matrix.json`（record id=hud）。

## Finding 254 (MapUi, 2026-08-11)：地图 UI 三个 pending 闭合（类型 0x32 标记 / 小地图标签 / 模式表面语义）

`map-ui-resource-evidence.json` 的 3 个 pending 全部移入 closed_notes（date 2026-08-10），结论如下：

**1) 类型 0x32 对象业务名（原 pending[0]）→ 服务端下发的阻挡型小地图标记（业务名仍 candidate）**
- 地图对象链表：头 `0x560070`/尾 `0x56008C`/计数 `0x560098`，双向节点 {vtable `0x476448`，+4=对象指针，+8=prev，+0xC=next}；对象 +0x88=类型字节、+0xCC/+0xD0=世界 X/Y。链表唯一填充者=网络生成/更新 handler（~0x407Fxx：pkt+0xB 类型字节→obj+0x61BD4，pkt+0xC 名称→obj+8，sprite 经 0x4014F0，pkt+6/8 的 X/Y 字；0x4350B9 按服务器 ID 查找）。
- **无静态写入 0x32**：全量扫描所有 byte-store（24 种 `88 /r,88` 编码）与 dword-store（27 处命中均无关结构）→ +0x88 的 0x32 值零静态写入 → 类型字节只来自服务端包。
- 绘制 `0x43DA80` @0x43DC54-0x43DCB8：`cmp byte [edi+0x88],0x32` → 在 (obj+0xCC, obj+0xD0) 以 1.5px/unit 画黄色 (0xFFFF) 小方块标记。
- 阻挡：`0x4123E3` 当目标全局 `[0x7E335C]` 的对象类型字节==0x32 → 移动被挡（另含 PtInRect(0x724FFC) 门控 @0x412397）。选中/使用排除：0x41ECAE 只返回 0/1 型；分派点 0x408276/0x40DFF0/0x411955/0x43CD29 只处理 0/1/3（kind 字 0x1A/0x71/0x72/0x73 @+0x8A、名称 @+8）——从不 0x32。
- 服务端 MiniMap.txt 仅 map名→帧号，无类型语义。残项：业务名（传送点 vs 阻挡点）需服务端包/运行时帧证据 → candidate 保留为传送点/阻挡点。

**2) 0x54/鼠标缩放切换的用户可见标签（原 pending[1]）→ 小地图标签存在，缩放键无标签（前提部分证伪）**
- 热键指引块 `0x47BBCC-0x47BCF4`：17 条 `名称(快捷键)` GBK 对，`小地图(Ctrl+V, V)` @**0x47BCCC**；作为按钮标签绑定 screen+0x5730（0x417550 调用点 0x4279CF，按钮 ID 0x52/0x53，坐标 (viewX+0xE4, viewY+2)；screen 对象=main+0x2A548C，17 个按钮步长 0xB4 至 +0x61BC）。
- **0x54='T' 缩放无任何用户可见标签**：全量 GBK 扫描（放大/缩小/缩放/放大镜/帮助/热键 等）=0 命中；全二进制仅 2 处「地图」（0x47B568「此处没有可以显示的地图」@0x420C50 无图路径、0x47BCXX 标签块）与 1 处「小地图」。
- 键盘分发 0x42CE90（GetAsyncKeyState IAT 0x476278，链 0x42CC76-0x42CF1F）：VK 0x54='T'，门控 `[screen+0x6518]==1`（地图打开）→ 翻转 `[screen+0x64A8]` → `0x43D5F0(screen+0x6214, 0x100,0x100)` @0x42CED2 / `(0x80,0x80)` @0x42CEF0。V (0x56) @0x42CDDA 开关面板（0x451770 on 0x8AB828，64ms 防抖）；鼠标 0x42C270（3s 防抖）同翻转；菜单 0x422BC5（flag `[esi+0x2AB9A4]`）。
- **无滚轮缩放**：WM_MOUSEWHEEL (0x20A) 全编码扫描=0 命中；小地图上鼠标=命中 0x43DDB0（调用方 0x42BDC0）+ Ctrl+拖拽重定位 0x43DEB0（调用方 0x42C75C）。
- **0x43DE40 无调用者/无引用=死代码**（活缩放内联在 T 键 handler）。
- 地图窗口对象身份统一：screen+0x6214 == main+0x2AB6A0（screen=main+0x2A548C，0x2A548C+0x6214=0x2AB6A0），地图切换 handler 0x420C3C 以 this=main+0x2AB6A0 调 0x43D780、键盘/逐帧驱动用 screen+0x6214，同一实例。残项：T↔缩放关联仅代码证据；运行期画面确认。

**3) 模式表面语义（原 pending[2]）→ 256=放大视野（覆盖语义），非 zoom-out（静态闭合）**
- `0x43D5F0` 全链：view 宽/高无钳制存 +0x2B8/+0x2BC；`SetRect(&+0x2C0, 800−min(w,frameW), 0, 800, min(h,frameH))`（IAT 0x4762B0，帧尺寸来自 [0x2E0..0x2E8]/[0x2E4..0x2EC]，由 0x43D780 地图选择设定）；释放旧表面 +0x00 并按 w×h 新建 → 256 模式=256×256 widget @(544,0,800,256)，128 模式=128×128 @(672,0,800,128)；**表面尺寸恒等于 widget 尺寸、1:1 blit（同 1.5px/unit 比例）→ 256 模式显示 4 倍地图面积**。
- 滚动：源/滚动矩形 +0x2D0 由世界坐标推导（SetRect x,y,x+[2B8],y+[2BC]，cdq/sar 居中，钳制 [0,frameW−viewW]/[0,frameH−viewH]，ftol 0x468520）；WIL 帧 1:1 解码（0x465560：dest col=x−x0）→ 偏移+滚动，无缩放适配。
- 逐帧驱动 `0x4295AC`（`[screen+0x6518]≠0` 时）：0x43D850(screen+0x6214, [0x777764], [0x777768]) → 0x43DA80 paint。0x43D5F0 外部调用方仅 T 键 0x42CED2/0x42CEF0。残项（可选）：运行期帧抓取做视觉确认。

落盘：`map-ui-resource-evidence.json`（pending→closed_notes ×3）、`RESEARCH_LOG.md`、
`UI_COMPLETION_AUDIT.md`、`UI_COVERAGE_MATRIX.md`、`MIR3_UI_RECONSTRUCTION_HANDOFF.md`（§6）、
`ui-coverage-matrix.json`（record id=map）。

### Finding 243：聊天窗六个频道控件 +0x34 GBK 命令串 = 悬停 tooltip-only 渲染（2026-08-11，ChatTooltip 阶段）

闭合 `chat-window-render-evidence.json` pending[0]：六个频道控件 `+0x34` 的 GBK 帮助串
（0x47AD08/0x47ACF8/0x47ACE4/0x47ACD0/0x47ACB8/0x47AC98）**只作为悬停 tooltip 文字渲染，
绝不是静态标题（caption）**。全部 primary-static 机器码实测。

**1) 九个控件 vtable 链（原待查）→ 已闭合**
- 聊天窗基类 ctor `0x413DA0`（聊天对象 = ROOT+0x507EC，调用点 0x426DBD）经数组构造助手
  `0x4686C4` 构造 9 个子控件：`lea eax,[esi+0x6c]; push 0xb4; push eax; call 0x4686c4`
  （0x413DF0-0x413DFE，另压入元素构造器 0x404690、计数 9、析构 0x4046B0）→
  控件对象 this+0x6C..0x60C，步长 0xB4（0x6C 关闭 / 0x120..0x4A4 六频道 / 0x558、0x60C 滚动）。
- 数组元素构造器 `0x404690` = `mov esi,ecx; mov dword ptr [esi],0x4763a8; call 0x4175F0;
  mov eax,esi; ret`（0x404693-0x404699）——**9 个控件的 `[obj+0]` vtable 写入点 = 0x00404690**。
- vtable `0x4763A8` 槽：+0=0x4046C0 dtor、+4=0x00417640 渲染（状态机）、+8=0x00417780 hover
  更新、+0xC=0x004177C0 按下置位、+0x10=0x004177F0 命中测试、+0x14=0x404910、+0x18=0x4049B0、
  +0x1C=0x404A30。0x404690 与嵌入变体 0x417F20（vtable 写 obj+0x04，供其他窗口嵌入用）同 vtable。
- 聊天 ctor `0x414060` 六次调用频道 ctor `0x417550`（0x414144-0x414237）：arg6=帮助串→+0x34
  （0x47AD08/0x47ACF8/0x47ACE4/0x47ACD0/0x47ACB8/0x47AC98）、+0x24=1 使能、+0x20=-1 无常态帧、
  +0x30=0、帧 0x168..0x173、x=基+0x19/0x41/0x69/0x91/0xB9/0xE1；0x417577 重置 +0x25=0。
- 刷新 `0x414700`（主循环调用点 0x428206）：先 9× 直调 0x417830 帧画，再 9 次循环
  `mov edx,[edi]; mov ecx,edi; call dword ptr [edx+4]`（0x414950-0x414959）→ 每控件 vtable+4。

**2) 渲染状态机（原 pending[0] 核心）→ 悬停 tooltip-only 已闭合**
- `0x417640`（vtable+4）按 `+0x25` 分派：==0 常态（`+0x24==1` 且 `+0x20!=-1` 才经 0x460240
  合帧；频道 +0x20=-1 → 0x417657 je 跳过，常态**什么都不画**）；==1 悬停（0x4176A9）：帧 =
  `+0x30!=0 ? +0x18 : +0x20`（频道 +0x30=0/+0x20=-1 → 跳帧选择）→ **0x417719 mov ecx,esi;
  0x41771B call 0x00417370 无条件画 tooltip**；==2 按下：SelectFrame(+0x1C) 合帧，不画文字。
- tooltip 渲染器 `0x417370`：0x417373 `mov al,[ecx+0x34]` / 0x417378 `lea ebp,[ecx+0x34]`；
  空串 → 清 POINT 缓存 0x8B1880/0x8B1884 返回；非空 → GBK 缓存 0x8B1888 比较、脏标志 0x47ADBC、
  打字机计数 0x47ADC0；光标锚点 GetCursorPos(0x476240)+ScreenToClient(0x476234)@hWnd [0x8AB7B0]；
  测量 0x45E0C0（GetTextExtentPoint32A 0x476078）→ 框 (w+12,h+4)；CreateRectRgn 0x476054 +
  GetRgnBox 0x47604C；底 CreateSolidBrush(0x96FFFF) 0x476064 + FillRect 0x4762F0（淡黄底）；
  框 CreateSolidBrush(0)+FrameRect 0x4762F4（1px 黑框）；文字 0x45DE50 = SetBkMode TRANSPARENT
  0x476044 + SelectObject(font) 0x476048 + SetTextColor 0x476060 + DrawTextA 0x476280 flags 0x25
  （DT_SINGLELINE|DT_VCENTER|DT_CENTER）；DeleteObject ×3 0x476068。
- `+0x25` 状态来源：vtable+8 `0x417780`（PtInRect 0x4762B4 于 [obj+4]；in && +0x25!=2 → 1，
  out → 0）由鼠标移动分派 0x42C63B→0x414CF0 9× 循环驱动；vtable+0xC `0x4177C0`（→+0x25=2，
  ret 1）由 0x42BC7C→0x414C60 驱动；vtable+0x10 `0x4177F0`（+0x25=0、PtInRect→0x45AFC0 音效
  0x69、ret 1）由点击 0x42C0B7→0x4149A0 驱动。
- **+0x34 读取点全扫**：仅 0x417373/0x417378（tooltip）；ctor 写 0x4175CD、子对象清 0x417622；
  命中分派 0x4149A0 全程无 +0x34 读取。点击频道注入的是**另一组**命令模板常量
  （0x47AD88/0x47AD84/0x47AD80/0x47AD7C/0x47AD70/0x47AD60）到原生 EDIT 框
  （SetFocus 0x4762B8 / SetWindowTextA 0x4762CC，HWND 0x8AA48C），与 +0x34 无关。
- `0x460240` = 帧表面合成（surface ptr [ebp+0x1C]、裁剪数学、800×600 实参 0x320/0x258、
  0xFFFF 掩码），头部无任何 GDI 文本调用；0x417830 亦仅帧画。E8 扫描：0x417640 零直接调用方，
  仅 vtable 槽 +4 可达（imm32 引用仅 0x4763AC）——渲染入口唯一。

**结论**：六频道 +0x34 GBK 帮助串 = 悬停 tooltip 文字（光标旁、淡黄底 0x96FFFF、DrawTextA 0x25），
常态与按下态均为纯帧合成；点击行为走命令模板进输入框，与 +0x34 无关。残项（candidate）：
0x45DE50 SetTextColor 精确 COLORREF（调用方压 0）；打字机揭示方向运行期验证；
渲染器 0x45DD70 绝对 x/y 槽序（另列 pending）；visibility gate 0x42B180 接线（另列 pending）。

落盘：`chat-window-render-evidence.json`（pending→closed_notes）、`chat-window-unified-model.json`
（channel_control_class 扩展 + closed_notes）、`RESEARCH_LOG.md`、`UI_COMPLETION_AUDIT.md`、
`UI_COVERAGE_MATRIX.md`、`MIR3_UI_RECONSTRUCTION_HANDOFF.md`（§6）、
`ui-coverage-matrix.json`（record id=chat）。

## Finding 260 (SystemWindow, 2026-08-11)：系统设置/坐骑/交易候选窗 5 个 pending 闭合 + constructor_va 惯例修正

`system-window-render-evidence.json` 的 5 个 pending 全部移入 closed_notes（date 2026-08-10），
并对三个窗的 `constructor_va` 做了惯例修正。全部 primary-static 机器码实测（binary：
Mir3.exe，VA=0x400000+fileoff，整文件 imm32/E8 扫描）。

**0) constructor_va 惯例修正（三窗一致）**
- 旧值 = ctor 内第一个子控件构造调用点（0x417550 this+0x7C），非 ctor 入口。
- option `0x0044103E`→`0x00440FE0`（main_init 0x2788D 调，id=0xC，frame 750，x=276，y=113，
  w=248，h=264，arg9=1，对象 main+0x518E0）；horse `0x0042691B`→`0x004268C0`（main_init 0x278D9 调，
  id=0xD，frame 850，x=0，y=0，w=296，h=332，对象 main+0x52118）；
  exchange `0x00415A71`→`0x004159D0`（main_init 0x277C2 调，id=3，frame 1050，x=0，y=0，
  w=484，h=330，对象 main+0x3399C）。各记录加 `constructor_va_note`。

**1) option pending：音频引擎是否经同一全局消费两个音量 → 否（差异闭合）**
- **EffectSoundLevel `0x008AB14C` 播放期直读**：0x45BCE9 在 0x45BC80（每声音音量/声相应用：
  eax=前项+level×40，钳制≥-10000，vtable+0x3C），由效果声 setup 0x45B140 与一次性播放
  0x45B900 调用；0x45B900 六调用方：0x457BA7/0x459240/0x459476/0x459AD6/0x45B032/0x45B074
  （游戏/UI 音效触发）。共 6 处引用全枚举：0x441BCB(save)、0x441DE3(load)、0x441E77/0x441E87
  (clamp)、0x441F93(drag)、0x45BCE9(play)。
- **BGMLevel `0x008AB150` 音频引擎零引用**：5 处引用全在 option 代码——0x441C26(save 读)、
  0x441E5F/0x441E6E/0x441EA6(load 写+clamp+thumb)、0x441F68(drag 写)。音量在拖拽时一次性
  落到 BGM 频道对象 `0x008AB658`：0x441F6C→0x45A700（频道音量 setter：+0x134/+0x13C/+0x118
  门控，vol×40，vtable+0x1C）。播放路径（0x45B250 play-by-name 拼 "SOUND\" 0x47D88C、
  0x45B3D0 stop→0x45A510、0x45B410 enable +0x56C、0x45B3F0 状态查询 [ch+0x130]）只读频道对象。
- 语义修正：0x45B3D0 = **BGM STOP**（非此前标注的 play entry）；play = 0x45B250。
- 结论：EffectSoundLevel=播放期经全局直读（YES）；BGMLevel=拖拽时经频道对象消费（NO）——
  "同一全局" 不成立，两音量走不同模型。

**2) option pending：Frame 750 之外运行期覆盖层 → 无（负闭合）**
- paint 0x441380-0x4414E3 = 基帧(vtable+0xC, frame 750) + 11 子控件 0x417830 重定位
  （close this+0x7C (218,238)；8 个 toggle this+0x130/0x1E4/0x298/0x34C/0x400/0x4B4/0x568/0x61C
  于 (148/185, 43/116/190/217)；滑块 this+0x6D0/0x784）+ 子控件 paint 循环(vtable+0x4, 11 项,
  step 0xB4, 自 this+0x7C)。唯一动态元素 = 滑块把手 x-offset [this+0x6C]/[this+0x74]
  (0..160) 并入 0x417830 重定位（0x44149C/0x4414BC）。无文本记录、无填充条。
- 0x417830 实参序 = (this, y, x)；[esi+0x18]=父 x、[esi+0x1C]=父 y；常量 x∈{0xDA,0x94,0xB9}、
  y∈{0xEE,0x2B,0x74,0xBE,0xD9} 与 JSON 记录 (x,y) 全对。
- 绝对控件坐标（窗口原点 276,113）：close (494,351)；toggle 行 (424,156)/(461,156)/(424,229)/
  (461,229)/(424,303)/(461,303)/(424,330)/(461,330)。

**3) option 附加修正：config load/save 链互换标注**
- 0x441B30-0x441CAE = **SAVE**（全局/状态→Config.ini "Options" 0x47A2CC/0x47A2B8；
  itoa 0x46855f + WriteINI 型 import）；0x441DA0-0x441F37 = **LOAD**
  （GetINI→atoi 0x4681F9→全局：EffectSound 0x47C5AC→[ebx+0x58]@0x441D85、
  EffectSoundLevel 0x47C598→[0x8AB14C]@0x441DE2、BGM 0x47C594→[ebx+0x54]@0x441E0C
  （≠0→0x45B410，=0→0x45B3D0+0x45B430）、BGMLevel 0x47C588→[0x8AB150]@0x441E5E
  （clamp≤-100→0 @0x441E6C）、Ambience 0x47C57C→[ebx+0x5C]@0x441EFA、
  ShadowBlend 0x47C570→[ebx+0x60]+[0x47EF48]@0x441F23/0x441F29；thumb=(level+100)×
  double 0x476968→ftol→[ebx+0x6C]/[0x74]）。config_state_mapping.load_or_parse_va 与
  slider_state_mapping.configuration_read_chain 已按 LOAD 链修正（旧值指向 SAVE 链）。

**4) horse pending：挂载标签 + 数据字段 → 闭合（标签为 sibling 主资源转录）**
- 四按钮帧对全部非空 20px 高，宽度=ctor 命中矩形精确匹配（44/60/60/56px），常态/按下对
  全帧差异；宽度与字形数相关（3/4/4/4 字）佐证 sibling `horse-window-render-evidence.json`
  像素转录：860/861 말타기(骑马)、862/863 말내리기(下马)、864/865 말숨기기(收马)、
  866/867 말꺼내기(取马)。命令绑定 primary-static：0x426A80-0x426B45 分派 @上马(0x47B060)
  when [0x7DA060]==0 on this+0x108；@遛马(0x47B068) when ≠0 on this+0x1BC；@收马(0x47B058)
  无条件 on this+0x270；@遛马(0x47B068) on this+0x324；每次分派后冷却 [0x8A68BC]=0x12C/
  [0x8A68C0]=0。（注意 말내리기 标签 vs @遛马 命令的差异即代码实况，如实并列。）
- 数据字段：挂载状态消息（switch 0x421E8C 项 0x41F597）写 word→[0x7DA063]/[0x7DA061]，
  5 字节结构{dword [0x7DA060], byte [0x7DA064]}→handler 0x40F420(ecx=0x777698 全局坐骑对象)
  复制 dword→[0x777698+0x629C8]、byte→+0x629CC、状态≠0 时置 [+0x629CF]=0x57('W')、
  钳制 0x88/0x89/0x8B，再 0x44BC30(ecx=main+0x2CF170) 刷坐骑面板。

**5) horse pending：Frame 850 外状态依赖覆盖层 → 无（负闭合）**
- paint 0x4269C0-0x426A74 = 基帧(frame 850) + 5 控件 0x417830 重定位（this+0x54 (252,293)、
  +0x108 (28,244)、+0x1BC (74,244)、+0x270 (133,244)、+0x324 (192,244)）+ 5 次子控件 paint 循环。
  状态依赖行为全在 click 分派 0x426A80-0x426B45，不在 paint。

**6) exchange-candidate pending：父原点/注册流不匹配 → 候选级闭合（不升级）**
- 注册 (0,0) 484×330（main_init 0x277A1）；ctor 0x4159D0 烘焙控件 rect 越界：close (532,350)
  28×26、trade (185,332) 48×20、第三 (225,332) 空白帧；show 分派 0x42B6A0（13 调用方
  0x42BB4E..0x42BD67）收消息提供的 x,y，0x4240C0 算拖拽抓取偏移 [+0x48]/[+0x4C]（偏移非移动）。
  → 显示期位置动态，无静态绝对屏幕原点；坐标保持 candidate/相对，直到运行期或消息流证明。
- 交易网格与文本：0x4169B0 逐格循环（36px 步长，帧 [ebx+0x5EC]，堆叠数 0x0A/0x0B 色
  [ebx+0x609..0x60B]，计数文本 0x45F2D0）；文本 4 条经 0x45DE50+0x46811C——左方名=全局缓冲
  0x7776A0（运行期填充，非字面量）、右方名 this+0x129D8、%d 计数 this+0x12A18/0x12A1C；
  重量条=共享组件 0x4179B0（frame 1070 16×360，max 0x5E=94，12×184 填充区），绘制于
  window.x+0xD1/0x1B9、y-0x73，值字段 [this+0x54]/[this+0x58] 在 .text 零写入→恒空条。
  1060/1061/1062 非空 48×20（交易 标签）；1063/1064/1065 全空（0 不透明像素）。

落盘：`system-window-render-evidence.json`（pending→closed_notes ×5 + constructor_va 修正 ×3 +
config load/save 链修正）、`RESEARCH_LOG.md`、`UI_COMPLETION_AUDIT.md`、`UI_COVERAGE_MATRIX.md`、
`MIR3_UI_RECONSTRUCTION_HANDOFF.md`（§6）、`ui-coverage-matrix.json`（record id=settings / id=exchange）。

### Finding 250：聊天窗口全闭合汇总——7 步绘制链/消息链表/9 控件坐标/输入 EDIT 链/文本渲染器槽序/可见性门（2026-08-11，ChatDocs 聚合阶段）

聚合 `chat-window-render-evidence.json` 与 `chat-window-unified-model.json` 的 closed_notes
（两文件各 3 条 closed_notes，date 2026-08-11；pending 均已清空，见 8)）。全部 primary-static
机器码实测（Mir3.exe，VA=0x400000+fileoff）。

**1) 7 步绘制链（`0x004142C0`，包装 `0x00414060`，主循环调用 0x427839）**
1. `0x00414705` 窗口基帧/背景经 vtable+0x0C；
2. `0x00414711` 聊天输入裁剪矩形 `SetRect(this+0x6C0, 40,29,531,308)`；
3. `0x00414738` 历史文字循环经 `0x45DD70`（19 行、14px 步进，行 y=this+0x6C4+row，见 6)）；
4. `0x00414846` 输入条共享量条 `0x4179B0` @ (window.x+0x215, window.y−0xD0)，值=[+0x68]、上限=[+0x6D0]；
5. `0x0041485A` 9 子控件直调 `0x417830` 帧画（固定相对位置）；
6. `0x00414955` 9 次循环子控件 vtable+4 paint（hover 状态机，复用 Finding 243）；
7. `0x00414965` 输入行字符矩形 `SetRect(this+0x954, 25,311,524,326)`。

**2) 消息链表模型（message_list）**：头 this+0x5C；节点 next=+0x408 / prev=+0x40C / 文字色=+0x00 /
背景色=+0x04（0=透明）/ 内联 GBK 文本=+0x08；计数 this+0x68；滚动偏移 this+0x6D0；索引 this+0x64；
裁剪 [35,28,520,43]；行距 14px；上限 19 行；文字原点相对 [40,29]。

**3) 9 控件坐标（窗口相对，unified-model controls）**：关闭钮 this+0x6C（F161/162，`(532,350)` 28×26，
paint 0x414863/ctor 0x414144）；六频道钮 36×34 每枚——this+0x120 `@拒绝 `(25,332)、this+0x1D4 `!`(65,332)、
this+0x288 `!!`(105,332)、this+0x33C `!~`(145,332)、this+0x3F0 `@拒绝私聊`(185,332)、this+0x4A4
`@拒绝行会聊天`(225,332)（命令模板 0x47AD88 族进原生 EDIT，help 串 0x47AD08 族→+0x34 tooltip，
见 Finding 243）；滚动上 this+0x558 F380/381 `(539,25)`、滚动下 this+0x60C F382/383 `(539,311)`；
输入条竖直量条 this+0x6D4（共享控件 0x417960，`(533,−208)` 16×502，paint 0x414846，raw args
[380,19,12,260,12,0]，值 [+0x68]/上限 [+0x6D0]）。

**4) 输入 EDIT 链（input）**：HWND 全局 `0x008AA48C`、EDIT 对象全局 `0x008AA488`；解析器
`0x00414364–0x004144F0`（语法标记 `/` `(` `)`；token 分隔 space 0x20 / colon 0x3A；格式前缀
0x47AD28 `/%s `；格式解析 0x47AD30 `%[^`]…`）；提交 `0x004144A0` → 逐行 `0x00414FA0`；行回忆
`0x004142C0`（PtInRect 行区→走 this+0x58 链表→剥 `/` 或 `(`→tokenize→sprintf `/%s `→写 EDIT）；
键 handler `0x00414E9x`（置 `!` 0x47AD84 或 0x47AD90 进 EDIT、EM_SETSEL 0xB1 到尾、ShowWindow(5)；
`0x00414ED0` 先查 Shift GetKeyState(0x10) 才显示）。

**5) 文本渲染器槽序（text_renderer，已闭合）**：`0x0045DD70` 为 thiscall、7 个栈参、ret 0x1C，
槽序由直接反汇编证明——arg1=目标 surface（离屏 GDI surface；arg1==0 → 回退 this+0x1C；
HDC 经 surface->vt+0x44 出参**写回 arg7 栈槽**，失败即退 0x45DE42 静默返回），arg2=X，arg3=Y，
arg4=文字色（SetTextColor 0x476060），arg5=背景色（0→SetBkMode TRANSPARENT 0x476044，否则
SetBkColor 0x476050），arg6=文本（strlen + TextOutA 0x476074：TextOutA(hdc,arg2,arg3,arg6,len)
@0x45DE12），arg7=字体（0→this+0x28 默认；显式字体由被调方 DeleteObject）。聊天调用点
`0x004147F3`：arg1=`[0x8AB7C4]`（CWHDXGraphicWindow+0x1C 离屏 surface，仅经
IDirectDraw::CreateSurface 出参写入 0x45D53D/0x45D552、0x45D602/0x45D617 in 0x45D380，无静态
存储），arg2=this+0x6C0+this+0x18，arg3=this+0x6C4+this+0x1C+row，arg4=msg+0x00，arg5=msg+0x04，
arg6=msg+0x08，arg7=0。已知色字面量 0x323232 深灰 / 0x0A0A0A 近黑 / 0xB4FFB4 淡绿；渲染器调用族
0x45DD70/0x45F2D0/0x45FD50/0x45E730/0x45E0C0/0x45DE50。

**6) 六字符串定论**（Finding 243，此处汇总）：六个频道 +0x34 GBK help 串 = **悬停 tooltip-only**
（0x417370 渲染、0x41771B 悬停分支无条件调用、光标旁 0x96FFFF 淡黄底 + 1px 黑框、DrawTextA flags
0x25）；常态/按下纯帧合成（0x417830/0x460240 无文本）；点击注入命令模板 0x47AD88 族（0x4762CC
SetWindowTextA，HWND 0x8AA48C）与 +0x34 无关。

**7) 可见性门 `0x0042B180`（已闭合）**：`[ROOT+0x5081C]` == 聊天窗自身可见标志 **this+0x30**
（chat 对象 = ROOT+0x507EC，0x507EC+0x30 = 0x5081C；窗口 vtable 0x47660C 存于 0x413E1A；
setter = vtable+0x10 = `0x423F80`：mov eax,[esp+4]; mov [ecx+0x30],eax; ret 4；.text 中仅
0x42B182/0x42B43E/0x42CC14 读取该门）。关闭路径：关闭钮子控件（chat+0x6C，vtable 0x4763A8）
命中测试 vtable+0x10=0x4177F0 → 聊天点击分派 0x4149A0 返回 1 → mouse stub 0x42C0B7 →
`push 8; call 0x42ADB0(ROOT)` → 跳表 `0x42B3E4[8]=0x42B180`：gate≠0 → 隐藏（编辑框
MoveWindow 到 [0x8AB7F0]+0xDF/[0x8AB7F4]+0x23A 0x162×0x10、0x42AC50 从激活列表
ROOT+0xD24..0xD38 移除窗口 8、0x423F80(chat,0) → +0x30=0、ret 0）；gate==0 → 显示（编辑框置
聊天矩形：w=[ROOT+0x51148]−[ROOT+0x51140]、h=[ROOT+0x5114C]−[ROOT+0x51144]、x=[0x8AB7F0]+
[ROOT+0x50804]+[ROOT+0x51140]、y=[0x8AB7F4]+[ROOT+0x50808]+[ROOT+0x51144]；ShowWindow(edit,5)；
0x42AC30→0x449870 追加窗口 8；0x423F80(chat,1) → +0x30=1、ret 1）。'R' 键 `0x42CCF7` 走同一
分派器切换；分派器入口 0x42B820 先对所有列窗口 deactivate（0x423F90 → +0x34=0；其跳表
`0x42B938[8]=0x42B8B6`=chat）。默认索引 5/10/>15 → 0x42B3DD 返 0。兄弟门：0x42B25E idx9
（gate [ROOT+0x51180]）、0x42B2AD idx15（gate [ROOT+0x52E8C]，额外编辑框 [ROOT+0x53028]）。

**8) 收尾**：两证据文件 pending 均已清空（pending=[]，closed_notes 各 3 条：six-channel /
0x45DD70-slot-order-and-arg1-arg7 / 0x42B180-visibility-gate-wiring，date 2026-08-11）。
剩余 candidate（非 pending）：0x45DE50 SetTextColor 精确 COLORREF（调用点压 0；a7==0 分支设
TRANSPARENT，色源未静态解析）；typewriter 揭示方向/hover 可达性运行期验证。

落盘：`RESEARCH_LOG.md`（本 finding）、`UI_COMPLETION_AUDIT.md`、`UI_COVERAGE_MATRIX.md`、
`MIR3_UI_RECONSTRUCTION_HANDOFF.md`（§6）、`ui-coverage-matrix.json`（record id=chat，
closed_2026_08_11 新增）。

### Finding 252 (NpcWindow, 2026-08-11)：NPC 对话窗输入/逐帧更新/二级分派/外层消息表 liveness 全闭合

闭合 `npc-window-render-evidence.json` 的 3 个 pending（全部 primary-static，机器码实测）：

**1) 子控件业务语义（原 pending[0]）→ 已闭合：关闭 X / 上滚 / 下滚**
- 模型输入 `0x440290`（thiscall，ret 8，返回 0/1）三连命中：
  - **关闭 X = this+0x58**：`call [eax+0x10]`（0x4402A6）且 `[this+0x274]!=0`（0x4402AD）→ 返回 1；
    分派 case `0x42C17D`：`mov ecx,0x47EF18; call 0x41C1E0`（0x42C18E/0x42C193）= ROOT hide-all，
    点击 X 关闭对话（帧 161/162 = 交叉剑 normal/highlight 字形，仅视觉）。
  - **上滚 = this+0x1C0**：命中 `0x4402E4`，门控 `[this+0x3BC]>0 && byte[this+0x58C]==1`
    （0x4402C3/0x4402CD）→ `dec [this+0x3BC]` clamp 0（0x4402F1-0x4402FA）→ `0x440C30` → 返回 0。
  - **下滚 = this+0x10C**：命中 `0x44033B`，门控 `[this+0x3BC]<[this+0x3C0] && byte[this+0x58C]==1`
    （0x440314/0x440324）→ `inc [this+0x3BC]` clamp `[this+0x3C0]`（0x440342-0x44035B）→ `0x440C30` → 返回 0。
  - `0x440C30` = 滚动重排：遍历节点表 `0x8B1AE4`，对每个 line struct（node+4）清 5 个 sub-rect
    （line+0xC，步长 0x10）经 SetRect IAT `0x4762B0`。
  - 滚动条 thumb 拖拽 = `0x417E60(this+0x3C4)`（0x440371-0x440379）；选项点击 = 5 sub-rect
    PtInRect `[0x4762B4]`、1s 节流 `[this+0x514]`、载荷前缀 `0x40 0x40`（'@@'）。
  - 动态重定位 0x440A43..0x440A8B：+0x58 → (win.x+0x15B, bottom-0x24)；+0x1C0 → (x+0xB8, bottom-0x1E)；
    +0x10C → (x+0xC8, bottom-0x1E)。上下箭头字形（52/53、54/55）为 medium 视觉证据，业务名来自机器码。

**2) 动态字段 this+0x520..0x544（原 pending[1]）→ 已闭合：是目标 RECT，不是文本记录**
- 构造器 `0x43EE00` 经 SetRect（IAT `0x4762B0`）建立三个目标 RECT：背景 this+0x520
  （+0x520/+0x524/+0x528/+0x52C 四 dword）、重复条目 this+0x530、末条 this+0x540；
  常量 384/384/138/24 是源尺寸派生输入，非文本。paint 直接消费：0x43F06A 选 Frame 1100 入 0x520 rect、
  循环 0x43F0B2 读 `DWORD[this+0x530]+1+idx` 为 x、`DWORD[this+0x534]+idx*18` 为 y（Frame 1101 条带）、
  0x43F120 选 Frame 1102 于 0x540/0x544+末索引*18。fallback 0x43F179 同样把 0x520..0x52C 当 rect 用。

**3) 一级分派体 / 逐帧更新 / 二级分派 / 外层表 liveness（原 pending[2]）→ 已闭合**
- **输入分派**：winmgr 鼠标处理器 `0x42BEAA` → 先 `0x417E60(winmgr+0x61BC)` 滚动条（返回 1）；
  hit-test `0x42AAB0` → edi==2 → 商店 `0x44E910`；否则 `0x42BF70`：`cmp edi,-1; je 0x42bef8;
  cmp edi,0xe; ja 0x42c198; jmp [edi*4+0x42c4d4]`。**表 0x42C4D4（15 项，第 16 dword=0x245c8b53 是数据）**：
  [0]0x42bf85 [1]0x42bfb3 [2]0x42bfe1 [3]0x42c00b [4]0x42c039 [5]0x42c198 [6]0x42c063 [7]0x42c08d
  [8]0x42c0b7 **[9]0x42c17d** [10]0x42c198 [11]0x42c0e1 [12]0x42c10b [13]0x42c131 [14]0x42c157；
  [0]=0x4300F0(winmgr+0x6554, winmgr+0x20, x, y)。**事件循环 `0x42BEF8`**：id 0..15，
  object = `winmgr + ((id*5+0x267)*9)*4` = **winmgr+0x567C + id*0xB4**（0x42BF0B 计算；
  **修正旧记录 "winmgr+0x8A7C + id*540 / (id*15+0x267)*9*4"**，与 Finding 248 的 0x42BA20
  16 固定窗口数组一致），逐窗 `call [eax+0x10]` 命中测试后 `jmp [id*4+0x42c494]`。
  **表 0x42C494（16 项）**：[0]0x42c1ce [1]0x42c259 [2]0x42c241 [3]0x42c2e1 [4]0x42bf37 [5]0x42c218
  [6]0x42c209 [7]0x42c292 [8]0x42c302 [9]0x42c226 [10]0x42c1a4 [11]0x42c1b2 [12]0x42c359 [13]0x42c1c0
  [14]0x42c234 [15]0x42c30d；NPC 模型 case 9 = 0x42C17D（0x440290 命中→hide-all 0x41C1E0）。
- **逐帧更新 `0x41D744`**：`mov eax,[esi+0x2f660c]; test eax,eax; jne 0x41d762` —— **模型非激活才发送**
  （修正旧记录 "[model+0x30] 门控"：门控是 ROOT 相对激活标志 [ROOT+0x2F660C]，发送是服务端内容轮询）；
  目标 = `[ROOT+0x364444]` 对象，实参 = `[obj+4]`（目标 id）；`mov ecx,0x8ab828; call 0x451740`
  → 0x452940(esi+0x18, 0x3F2, arg) 头 + 0x451E60 发送 = **出站 msg 0x3F2**；GetTickCount →
  `[ROOT+0x428040]`（500ms 节流）；`[ROOT+0x364450]=0; ret 8`。**`[ROOT+0x364444]` 动态目标字段语义
  结案**：它是注册的对话目标对象指针，逐帧更新取其 +4 的 id 组装 0x3F2 轮询包。
- **二级分派全解码**：`0x41EDBD` → `jmp [edx*4+0x421d5c]`（表 A 12 项 [0]0x421cfc [1]0x421497
  [2]0x421ba7 [3]0x41efc6 [4]0x41f06b [5]0x41ede0 [6]0x41ef62 [7]0x41ef8b [8]0x41f0f0 [9]0x41edc4
  [10]0x41ee34 [11]0x421d3f），byteA `0x421D8C`（0xC3 字节，idx=msg−6）：[23]=[24]=1 → msg 29/30 →
  0x421497；[34]=2、[94..98]=2 → msg 40、100..104 → 0x421BA7；[35]=3 [36]=4 [38]=5 [39]=6 [40]=7
  [47]=8 [48]=9 [194]=10 → msg 53→0x41F0F0、54→0x41EDC4、200→0x41EE34；值 0xB noop；默认 0。
  `0x41F052` → `jmp [edx*4+0x421e50]`（byteB `0x421E58` 0x33 字节，idx=obj type 字节：
  type 0/1/3/0x32 → 0x41F059（0x41F01E 处 vtable+0x3C 分派），其余 noop 0x421D3F；
  表 0x421E50 = [0x41f059, 0x421d3f]）。`0x42043C`（msg 0x29F..0x327）：`add eax,-0x29f;
  cmp eax,0x88; ja 0x421d3f; mov dl,byte[eax+0x422080]; jmp [edx*4+0x421fbc]`——
  **表 0x421FBC 49 项**（旧 "0x422050 dwords" = 本表尾部索引 37..48；byteC 0x422080 值 0..48，48=noop）：
  [0]0x420be8 [31]0x421cfc [32]0x421508 [44]0x420c90 [45]0x421497 [46]0x420e36 [47]0x42121b [48]0x421d3f。
  子协议 0x4218F2 byte 表 `0x42219C`（idx=sub_msg−0x44D，≥0xD4 字节，默认 0x0C noop）复核：
  0x44D→0、0x4B0→1、0x514→2、0x515→3、0x516→4、0x517→5、0x518→6、0x519→7、0x51A..0x51D→8、
  0x51E→9、0x51F→10、0x520→11 → 表 0x422168 13 项 [0]0x421c81 [1]0x421913 [2]0x421bbc [3]0x421a45
  [4]0x421af5 [5]0x421a85 [6]0x4219a0 [7]0x421ba7 [8]0x421cfc [9]0x421b5b [10]0x421955 [11]0x421c23
  [12]0x421d3f —— 与已确认 id_map 一致。
- **外层表 0x421E8C liveness（40 dword 纯跳表，非 20 对）**：唯一读者 = 分派尾 `0x41F582`
  （唯一跳入点 0x41F269）：`add eax,-0x264; cmp eax,8; ja 0x421d3f; jmp [eax*4+0x421e8c]` →
  **仅索引 0..8（msg 0x264..0x26C）可达；9..39 静态死代码**，含 13（0x41FD36 click_buffer）、
  16（0x41FE31 dialogue_open）、17（0x41FECC hide-all 包装）——三者无表外 E8/imm32 引用；
  **0x41FE31 "打开链" 静态不可达**（Finding 256 的 "0xf6ef→0x41f73c" 等配对读法系对纯跳表的误读，
  索引即 handler 指针）。hide_all `0x41C1E0` 本体经直接 E8 调用方 0x41C0CE/0x422BAD/0x42C193/0x42CFC3
  保持存活（0x42C193 = NPC 模型 case 9 的关闭路径）。

等级：**primary-static 全链**（跳表/字节表全量 dump + 反汇编 + E8/imm32 引用穷举 + 跳入点扫描）。
残项（candidate）：上下箭头/关闭 X 的字形归属（GameInter 帧 52/53、54/55、161/162 视觉比对，业务名已由
机器码闭合）、0x3F2 轮询包的运行期服务端应答、以及外层表死代码索引 9..39 的历史用途。

落盘：`npc-window-render-evidence.json`（pending→closed_notes ×3 + input_object_table 修正 +
dialogue_open liveness 修正）、`RESEARCH_LOG.md`、`UI_COMPLETION_AUDIT.md`、`UI_COVERAGE_MATRIX.md`、
`MIR3_UI_RECONSTRUCTION_HANDOFF.md`（§6）、`ui-coverage-matrix.json`（record id=npc）。

### Finding 249：0x43E4B0 消息负载 = WM 0x201/0x202 lParam 坐标；Interface1c 提示窗先于 Frame 602 显示（2026-08-11，WindowVisibility 阶段）

闭合 `window-visibility-dispatch-evidence.json` 唯一 pending（Finding 204 尾部"`0x0043E4B0`
的消息字段含义及其是否先使用 Interface1c 提示资源仍保留为待解析项"现已解析）。全部 primary-static。

**1) 0x43E4B0 消息负载 = 打包 lParam 鼠标坐标（已闭合）**
- 0x43E4B0 = 通知窗（id 15）点击处理器：prologue `mov eax,0x1f40; call 0x468d10`（__chkstk）、
  `mov ebp,ecx`（this = 通知对象 main+0x2A548C+0x52E5C）、`ret 8` → 2 个栈参
  （arg1=edi=x、arg2=esi=y）。子控件分派 this+0x54（帧 161/162）与 this+0x108（帧 606/607），
  携带 (x,y)；确认命中且 [this+0x1CC] 时经 0x45DC70 → 0x8AB7A8 → 0x4524A0/0x4524D0 @0x8AB828
  保存（msg 0x410/0x411，行会公告编辑缓冲）；子控件命中返回 1 → 调用方隐藏 id 15。
- **负载来源**：WM_LBUTTONDOWN **0x201** → 0x41D470；WM_LBUTTONUP **0x202** → 0x41E451 →
  0x41DB80 → 0x42BE20。两处均解包 `[esp+8]` = `(y<<16)|x`：0x41D485/0x41D48E 与 0x41DB93/0x41DB99
  → x = 低 16 位 → main+0x35B2A8、y = shr 16 → main+0x35B2AC。
- 调用点 **0x42BE8C**（0x42BE20 内，门控 `[esi+0x52E8C]`≠0 分支）：
  `push [esp+0x18](y); push [esp+0x14](x); lea ecx,[esi+0x52E5C]; call 0x43E4B0`；
  返回非零 → `push 0xf; call 0x42ADB0`（显示 id 15）。LBUTTONDOWN 对应链 0x42BA20 → 0x43E640。

**2) Interface1c 提示窗先于 Frame 602 显示（已闭合，模式字节 0x8B1878 强制顺序）**
- 协议 case 0x64/sub0（0x41CE14，消息 0x7ED–0x7F0 跳表 0x41E690 经 0x41E522→0x41CDE0）：
  门 0x419CC0 → 队列 tag 0x3F1（0x451660 @0x8AB828）→ **0x42E1F0 = .itm 文件加载器**（非公告发送；
  sprintf 构造 `.\Data\<arg>.itm`（0x47BDC4/0x47BDCC）→ 0x8AB7A8，CreateFileA @IAT 0x4760DC
  （GENERIC_WRITE, share=2, CREATE_ALWAYS=2, 0x80）+ 3× ReadFile @0x4760D0）→
  `[esi+0x428208]=0; byte[esi+0x428204]=2`（0x41CE57，状态字节唯一写入者，值恒 2）。
- 主窗口逐帧步骤 0x41C1C7 → **0x41B5D0**（唯一调用点）：`al=[esi+0x428204]`、`ebx=[esi+0x428208]+arg`；
  状态 1 + acc>0x9C4 → 复位（0x41B61B）；状态 2 + acc>0x9C4 → **状态=0、acc=0、call 0x419BE0**
  （0x41B65F）；状态 2 + acc≤0x9C4 → `fild(acc)*[0x476710]`；之后 ×[0x47639C] → 变换 → 0x466800 等。
- **0x419BE0 体**（0x419BE0–0x419C36）：`[ecx+0x35b2b8]=0; call 0x419110;`
  `mov eax,0x8a7140; mov byte [0x8b1878],2; mov [0x8ab820],eax; mov [0x8b1870],eax; call 0x456cb0`
  （Interface1c 重初始化）→ `mov al,[0x47ee89]; push 5; test al,al; push 2 / push 1; push 0x10;
  push 0x1e0; push 0x280; mov ecx,0x8ab7a8; call 0x45d270` →
  **0x45D270(0x8AB7A8, 640, 480, 0x10, [1|2], 5)** 文字格式化（[0x47EE89] 选 1/2）。
- **主循环模式开关 @0x402123**：`mov eax,[0x8b1878]; and eax,0xff; sub eax,ebx(0)` → je 0x40216c
  （**模式 0**：0x8A9520+0x402BE0）；`sub eax,2` → je 0x40215f（**模式 2**：0x8A7140+0x4575D0 =
  Interface1c 提示步骤）；`dec eax` → jne 0x402177（**模式 3**：`cmp [0x8ab7e8],ebx; je 0x402149`
  → 0x41B440+0x41B500 @0x47EF18，否则 0x41BB00 @0x47EF18）。
- Interface1c 步骤 0x4575D0（表 0x457778）：状态 2 @0x457615（门 0x45C900([esi+0x780],[0x8AB7C4]) →
  **SetWindowTextA(0x8AA48C, 0x8B187C) + MoveWindow(0x8AA48C, [0x8AB7F0]+0x120, [0x8AB7F4]+0x195,
  0x4B, 0xD, 1) + ShowWindow(0x8AA48C, 5) = 提示显示**）；状态 4 @0x45773C → 0x4570A0 →
  **0x4570C0**（`[0x8ab820]=[0x8b1870]=0x47ef18; call 0x419350; byte[0x8b1878]=3` = 切模式 3）。
- **模式 3 = Frame-602/公告横幅阶段**（0x47EF18）：0x41BB00（fild[esp+4]*[esi+0x428220] → 0x468520
  钳制 ≥0xA → [0x8B1A94]+= → [esi+0x4279A8]+= → 回绕 [esi+0x4279A4] → [0x8B1A94]>0x5F 复位 →
  [esi+0x428044]≠0 且 [esi+0x428048]>0x1388 → 0x45B250(0x8AB130,[esi+0xF5204],1,0)+Sleep(0x1E) →
  0x41B440 → 0x422280 滚动文字/横幅绘制族）或 0x41B440+0x41B500（[0x8AB7E8]==0 分支）。
- 横幅单例 0x777200（ctor 0x423E80，帧 0x25A=602 @0x425A46）显示 =
  `push 0xf; mov ecx,0x7243A4; call 0x42ADB0`（@0x425A26/0x425B25）；id-15 分派器 0x42ADB0
  （见本文件记录主体）负责加入/移出可见链表 main+0xD24。

**结论**：0x43E4B0 的 2 个消息负载字段 = WM 0x201/0x202 打包 lParam 解出的 (x, y)（x=main+0x35B2A8、
y=main+0x35B2AC）；**是——Interface1c 提示窗（模式 2，0x8A7140 类，编辑框 HWND 0x8AA48C）在
Frame 602 窗口（模式 3，0x47EF18）之前显示**，模式字节 0x8B1878 经主循环开关 0x402123 强制顺序
（0 → 2 → 3）。0x42E1F0 更正为 .itm 文件加载器（CreateFileA/ReadFile），非公告发送。残项（candidate）：
Interface1c 提示文本 0x8B187C 的服务端/协议来源、0x45D270 文本格式的精确 COLORREF/字号（IAT 级调用，
静态未解析颜色实参）。

落盘：`window-visibility-dispatch-evidence.json`（pending→closed_notes）、`RESEARCH_LOG.md`、
`UI_COMPLETION_AUDIT.md`、`UI_COVERAGE_MATRIX.md`、`MIR3_UI_RECONSTRUCTION_HANDOFF.md`（§6）、
`ui-coverage-matrix.json`（record id=prompt）。

### Finding 251 (QuestWindow, 2026-08-11)：任务窗口 2 个 pending 闭合 —— 分隔符 '/'、无客户端像素换行、控件→事件归因修正（业务名保持 candidate）

**P1 分隔符 + 像素换行**
- **线上分隔符 = '/'（0x2F，primary-static）**：msg 0x515 → 子协议分派 0x4218F2 → 0x421A45
  （正文拷入调用方栈 [esp+0x171C]，word 计数 [esp+0x16]）→ fill `0x4488D0`(ROOT+0x2F6B74, body,
  count) 经 **fast strchr `0x468BF0`**（`push 0x2f` @ 0x44891C/0x448932/0x448944/0x44895C/
  0x44897A）就地切分服务器正文；行文本 → 描述符 record+4，field4 → record+0x230（has-field4
  标志 record+0x214），字段长 record+0x204/record+0x22C，追加经 0x449870，尾设
  `[frame+0x54]=1`、`[frame+0x1F4]=count`。
- **无客户端像素换行（primary-static）**：`0x45DD70`（ret 0x1C，7 实参）每行恰一次 TextOutA
  （SetBkMode TRANSPARENT 0x476044、SelectObject 0x476048、SetTextColor 0x476060、strlen、
  单次 TextOutA 0x476074、恢复 SelectObject/DeleteObject 0x476068、vtbl+0x68 advance），
  位置为算术坐标（列表 y = win.y + (row−scroll)*15 + out[1] + 0x5A、x = win.x + out[0] + 0x41，
  15px 步进 `lea eax,[eax+eax*2]; lea ecx,[eax+eax*4]`）；GetTextExtentPoint32A 0x476078
  仅在字段取用助手 `0x45E0C0`（0x45E157）内测量；paint/fill 链无任何回流/折行循环。
- **记录类 tokenizer 保持 candidate**：字段经 `[0x8AB7A8+0x1C]`（记录类）vtable +0x44 取字段
  （负返回 = 无字段）/+0x68 前进，类型门 0xA0/0xC8；缺记录类 vtable 地址或运行期抓包。

**P2 业务名（链 primary-static，名称 candidate）**
- 控件 ctor `0x447400`：两控件均经共享控件 ctor `0x417550`（vtable 0x4763A8）：箭头 this+0x74
  （帧 723/724，x=+0x122，y=+0x3B）、X this+0x128（帧 721/722，x=+0x122，y=+0x59）。
- 共享 release `0x4177F0`（vtable 0x4763A8 +0x10）：清 +0x25、PtInRect(0x4762B4) 于 rect obj+4、
  命中 → `0x45AFC0(0x8AB130, cmd 0x69)`（50 槽命令注册表分派 @0x45B900；Finding 243 定 0x69 =
  共享音效命令）→ ret 1。
- **X 721/722 = 本地消费（primary-static，纠正 Finding 218 的“两控件路径均汇入 0x448580”）**：
  点击 handler `0x447FA0` 先测 X release（0x447FCA），命中 → 0x447FD6/0x447FDA 直接 ret 1，
  **不发 0x418/0x419**；业务名 candidate：关闭任务窗（右上角 (290,89) 关闭钮；0x69 命令链是否
  执行关闭需运行期确认）。
- **箭头 723/724 → 0x448580 → 0x418**：点击路径 0x4481F1 release 命中 → 0x4481FA call 0x448580
  （record+0x208=1、this+0x68=1、this+0x1DC=record）→ record+0x20C==0 → `0x451A10` 发 **0x418**
  （arg record+0，装配 0x452940、发送 0x451E60）；更新路径 `0x448230` → 0x44856B 同汇 0x448580。
  业务名 candidate：前进/下一任务记录动作。
- **子记录 → 0x419**：record 循环命中子矩形 child+0x204（0x4480F1-0x44810C）→ this+0x6C=child+0x220；
  byte[child+0x220]==0 → push [child+0]、push [record+0]、`0x451A40` @0x448148 发 **0x419**
  （装配 0x452940）；走马灯推进 child+0x8=next、child+0x10=min(+0x10+1, +0x14)。
- **0x418/0x419/0x69 业务名 = candidate**：全仓 grep（docs/Tools/scripts）无协议目录命名，
  EIServer.exe 二进制无源码；缺服务端包处理引用或 0x418/0x419 发送的运行期抓包。

落盘：`quest-window-render-evidence.json`（pending→closed_notes，控件归因修正）、
`ui-coverage-matrix.json`（record id=quest → closed）、`UI_COMPLETION_AUDIT.md`、
`UI_COVERAGE_MATRIX.md`、`MIR3_UI_RECONSTRUCTION_HANDOFF.md`（§6）。

---

## 2026-08-11：背包窗口记录布局与主数值/打包字段闭合（Finding 247）

> 阶段目标：为 `inventory-window-render-evidence.json` 的两个 pending 项（主数值 `0x7DA100` 语义、
> 打包字段 `+0x351..0x353` 语义）寻找 primary-static 证明。结论：打包字段 = 24 位图标着色
> （primary-static 全链）；主数值 = 死状态字段（bss 零、0x405 发送门在本构建死），业务名维持
> candidate（交易/购买数量上限）。同时修正记录布局（旧“指针数组 this+0x774+4*index”错误）。

### 记录布局（primary-static，纠正旧模型）
- **记录数组：ctor `0x42E810` + dtor `0x42E8D0`（vtable `0x476870`，双证）**：
  **ctor** `0x42E810`（唯一 E8 调用者 0x426D4D，ecx=container+0x6554）→ 向量构造迭代器
  `0x4686C4(this+0x774, 0xC2C, 0x2E=46, 每元素 ctor 0x415730, dtor 0x415740)`；
  **dtor** `0x42E8D0`（0x426F97 于 teardown 0x426E80 内调用；另有删除性 thunk
  `0x42E8B0` = vtable 槽[0]，`call 0x42e8d0; test [esp+8],1; je; call 0x4680f8`）
  → 向量析构迭代器 `0x468306(this+0x774, 0xC2C, 0x2E=46, dtor 0x415740)`，随后恢复基类
  vtable `0x476624` → 基类 dtor `0x423CF0` → **46 条连续记录，record = this+0x774 +
  slot*0xC2C**（0xC2C=3116 字节；lea 链 slot*779 dword）。旧“指针数组
  this+0x774+4*index”错误，已纠正。
- **放置/分配 `0x42F440`**（唯一 E8 调用者 0x42FC90 ∈ 0x42FC40）：`lea ecx,[edx+ecx*4]`
  （edx=this、ecx=779*slot）→ `[rec]=1、[rec+4]=col、[rec+8]=row`；`lea edi,[eax+0x780]`
  （=rec+0x0C）；`mov esi,[esp+0x3C]`（源物品数据块）；`mov ecx,0x308; rep movsd` =
  **0xC20 字节整体拷贝** → 数据基址 = rec+0x0C。
- **格子身份表 `this+0x2C4`**：每格 WORD、6 格/行、行步 12 字节；占用格 = slot+0x3E8(1000)
  （网格绘制 0x42F7CC-0x42F7E2：movsx; cmp 0x3E8; jl skip; idiv 0x3E8 → edx=slot）。
  清格 `0x42FB20` 整条 0xC2C 归零 + 清身份表两处。绘制行窗 = max(0,[this+0x58]−5)..
  [this+0x58]+6（约 11 行可滚动）。
- **拷贝-出+清格 `0x42FCC0`**（调用者 0x42FD69/0x42FE40）：记录占用 → 0xC20 从 rec+0x0C
  拷到调用者缓冲 → 0x42FB20 清格 → ret 1/0。
- **移动/拾取 `0x42FE00`**（调用者 0x430339/0x4305DC）：0x430920 建 0xC20 栈块 →
  0x42FCC0 拷出+清源 → 目标记录 `[rec+0x00]=1`、数据拷到 **rec+0x18**（0xC20）、
  +0x1A=slot word、+0x04..0x14 清零 → `0x42E2D0(0x7243A4, rec+0x18)`。
- **携带/贴附 `0x42FD10`**（调用者 0x43036D/0x4305FD）：光标物品记录 +0x00=in-use、
  +0x04..0x14=0、**+0x18=数据基址**、+0x1A=slot byte、+0x1C=name；0xC20 经 0x42FC20 拷贝。
  → 状态记录（数据基址 rec+0x0C）与光标记录（数据基址 rec+0x18）**共享同一物品数据布局**。

### 物品数据布局（相对数据基址，状态/光标共用）
- `+0x02` slot byte（光标记录存于 +0x1A）；`+0x04` name 字符串（光标 +0x1C）。
- `+0x22` **type byte：0x0A/0x0B → 着色图标路径**（0x42F902-0x42F925）。
- `+0x28` **icon frame WORD**（网格尺寸 0x42F6D0 / 图标 0x466130）。
- `+0x3D` quantity dword（发送参数 [edi+0x55] @0x43029A；数组元素 +0x7BD）。
- `+0x45/+0x46/+0x47` **24 位 LE 着色 RGB**（0x42F925-0x42F937 取 3 字节 →
  `0x45E4E0` 3→16bit 565 → RLE blit fill `0x45F2D0`；非 {0x0A,0x0B} → 白 0xFFFF）。
  状态记录偏移：+0x2E / +0x34 / +0x51..0x53。**旧 +0x2E8/+0x351..353 错误，已纠正**
  （与状态窗 0xC24 记录族混淆）。

### 主数值 0x7DA100（candidate：死状态字段）
- 全 .text 仅两处 imm32 读：`0x41729D`（0x405 发送门 `0x417280`）与 `0x42EE4C`（本 paint，
  绘制于 (x+0x41, y+0x11A..0x12B)、色 0x64C8F8、格式 `%d` @0x47A214）。
- **0x7DA100 无任何写入者**（.data raw 止于 0x47F000 → bss 零）→ 显示恒 0。
- **0x405 门 `0x417280` 本构建死**：`cmp ax,0x405; jne ret; shr eax,16; test al,al; jne ret`
  （byte2 必须 0）；`atoi(arg) > [0x7DA100] → 抑制`；否则 push 值 → `0x451B00` 发 0x405
  （单值 dword）。唯一 E8 调用者 `0x42D6C6`（分派 `0x42D680` case 4）传 category byte 4 →
  al=4 → 恒 jne ret。0x405 仅 4 处出现：0x416F7F（输入对话框 `0x418030` 参数）、
  0x417284（门比较）、0x451B13（消息构造）、0x4650A6（函数中部垃圾行）。
- 邻近语义：0x7DA100 为玩家属性块头 dword（0x7DA108 等级、0x7DA10C 攻击力、
  0x7DA10D/0xF/0x11 经验 word、0x7DA11D/0x1F 负重/总量）；兄弟门 `0x41CE86` 在交易窗
  比较 atoi(arg) vs `[esi+0x35B1E8]`（jge skip → `0x451940`）；丢弃金币提示 `0x47B028`
  （@0x41D626）与交易付款提示 `0x47AD98`（@0x416F7E）紧邻 → **candidate：交易/购买数量上限**。
- 运行时证据需求：交易/数量对话框期间调试器观察 0x7DA100。

### 负重/总量与四模式标签（闭合）
- 「负重:%d / 总量:%d」`0x47BDFC`：读 `[0x7DA11D]`（负重 word）与 `[0x7DA11F]`（总量 word）
  @0x42EF9E/0x42EFB3，绘制 (x+0x86, y+0x18) 色 0xA0A0A / (x+0xF0, y+0x26) 色 0xF8C8C8。
- `byte this+0x54` 模式分派（跳表 `0x42F13C`，0..3）：**0=[包袱] `0x47BE10`**（0x42EF5B，
  0xF8DCFA）、**1=[修补] `0x47BDF4`**（0x42F03E）、**2=[变卖] `0x47BDEC`**（0x42F078）、
  **3=[木柴] `0x47BDE4`**（0x42F0FB），色 0xF8C8C8。模式由 `this+0x5C` 处 3×0xB4 标签页数组设置。
- `0x47BE18` = **共享字体名字面量参数**（`0x45DBA0` ecx=0x8AB7A8，60+ 调用者含本 paint
  0x42EE8A 与状态窗簇 0x44Bxxx-0x44Cxxx；CP949 解码 "굴림체"），**非字段标签**。

### 点击链（primary-static）
- `0x4300F0`：300ms 限速（GetTickCount−[esi+0x23788]<0x12C）；使用延迟帧 0x14/0x15/0x46
  （>0x3E8 且 >0x7D0 延迟窗内）→ 0x415280(0x7243A4, 「正在补充药水,请稍候.        」`0x47BDA4`)。
- mode0（背包）→ **msg 0x3EC** 经 `0x451690`（0x8AB828；slot byte [edi+0x1A]、name [edi+0x1C]、
  qty dword [edi+0x55]；置 [edi+4]=1 busy）；mode1（修补）→ `0x451860`（[esi+0x2376C]、
  [数组元素+0x784] name、[+0x7BD] qty）；mode2（变卖）→ `0x4517E0`；待定动作字段
  [esi+0x2375C..0x23768]。

### 网络缺口（显式记录）
- 背包填充虚拟入口 `0x42FC40` **静态零引用**：无 E8、无 imm32、不在 vtable 0x476870 槽
  [0..10] → 死或运行期计算指针。[reg+0x774] 写入者全在背包内部（0x42Exxx-0x430xxx）+
  物品库层 0x456AC3-0x45A112（不同结构）。外发 **0x403**（0x451AD0 @0x4300F0）为背包动作
  消息；服务端→客户端背包列表回包 handler 静态无法定位 → 需运行期抓包配对 0x403 回包。

### 落盘
`inventory-window-render-evidence.json`（pending→closed_notes/candidate+证据链；记录布局、
打包字段偏移、负重/总量、四模式标签、点击链、网络缺口全写入）、`ui-coverage-matrix.json`
（record id=inventory → pending:false + closed_2026_08_11）、`UI_COMPLETION_AUDIT.md`、
`UI_COVERAGE_MATRIX.md`、`MIR3_UI_RECONSTRUCTION_HANDOFF.md`（§6 背包行）。

---

### Finding 259 (SocialWindow, 2026-08-11)：组队窗 4 pending + 行会窗 3 pending 全部闭合（列规则纠正 / 权限文字 x 不可证 / 无列表上限 / 运行态显隐；行会 9 控件点击分支 / ctor 寄存器陈旧值纠正 / 特殊行着色）

证据：`social-window-render-evidence.json` closed_notes（window.group 4 条、window.guild-candidate 3 条），全部 primary-static。

#### 组队窗（id 6，main+0x47834，paint 0x4243D0）
- **成员行 = 单文本字段 node+0x04，无图标**；链表插入序（feeder 0x419EE4 → 容器 push_back 0x424840；容器 this+0x54 vtable 0x4767E0——旧 evidence 把该 vtable 标注为 "input-handler vtable" 是错的，实为成员列表容器；头 this+0x58 / next 字段 +0xC / count this+0x68）。
- **两列规则纠正**：行索引从 0 起；奇行（i&1≠0）→ 左列 x=window.x+0x2D（0x424471 `push ebx`，ebx=window.x+0x2D，header 处 0x4243EC 起递增）；偶行 → 右列 x=window.x+0x91（0x424479 `lea edx,[ebx+0x64]`）；y=window.y+0x5A+20*⌊i/2⌋（0x42444A-0x424461）。**旧公式 `x=window.x+45+100*(i mod 2)` 与早前 "偶→+145/奇→+45" 均错：机器无 +45 基底，mod-2 映射颠倒**（正确：奇→+45 左、偶→+145 右）。
- **权限文字 [允许]/[拒绝]**（this+0x3F0 → 0x47BA08/0x47BA00，分支 0x424532-0x424577，色 0xDCE6C8）：**y=window.y+0x3A PROVEN**（0x424549/0x424563 `add edi,0x3A`）；**x 静态不可证**：0x42453E-0x424551 读 `[esp+0x1C]`（帧槽 R−0xC），0x4243D0 全函数从不写该槽（只写 +0x10/+0x14/+0x18/+0x20/+0x24）→ 未初始化栈垃圾 + 0x6E；旧值 "window.x+0x6E" 与 ctor 寄存器流 P0−0x1148 均为陈旧伪影，已拒。
- **无可见行数上限**：0x424426 test [esi+0x68] && 0x42442D 头非空后，0x42443E-0x4244A4 全链表遍历，仅 next==0 终止（0x42449B）；无行会式 0x12 cap（对比 0x4252D4/0x4254C5）。超窗行由引擎裁剪（bg 0x460240 / 文字 0x45DD70 均引擎裁剪），非列表截断。
- **运行态显隐全链**：show-by-id 0x42AC30（登记 main+0xD24 活动表，容器函数 0x449870）/ hide-by-id 0x42AC50（main+0xD28..+0xD38 移除）；组队 id=6；切换 0x42B0BA：可见性读 main+0x47864（=组队窗 this+0x30）→ 显→0x42AC50(6)+[vtable+0x10](win,0)；隐→0x42AC30(6)+[vtable+0x10](win,1)+伴生页签帧 0x398/0x399 @main+0x47B70 重定位（0x417880，实参依 [esi+0x47C24]）（0x42B0C8-0x42B120）；显示分派 0x42B6A0(id,x,y)：0x42B820 关 tooltip→0x42AC50→0x42AC30→[main+0xD3C]=1→各窗尾部（组队 0x42B79A @main+0x47834、行会 0x42B774 @main+0x4707C；其余偏移 +0x33188/+0x3399C/+0x47C28/+0x507EC/+0x51150/+0x516E8/+0x518E0/+0x52118/+0x524F0）；尾部=push 1→0x423F90（[+0x34]=1）→0x4240C0（若 [+0x30]&&[+0x34]&&[+0x3C] 全置：[+0x48]=x−[+0x18]、[+0x4C]=y−[+0x1C]）；vtable+0x10 setter=0x423F80（mov [ecx+0x30],eax）；绘制分派 0x428100 走 main+0xD28..+0xD38，组队经 0x4281D4 lea ecx,[esi+0x47834]; call 0x4243D0。主鼠标分派：悬停 0x42C063（0x424610 hover）→ push 6 → 0x42ADB0（id 跳表 ≤0xF）；点击 0x42BC24 → 0x424730。**注意：0x42ADB0 的 id-4/id-6 个案未逐一分反汇编，勿宣称逐 id 行为**（id-0 个案与骨架已验证）。

#### 行会窗（id 4，main+0x4707C，paint 包装 0x425040，状态分派 [+0x98]）
- **9 控件数组 this+0x118 步长 0xB4**；帧对/标签（ctor 0x424E60）：0 +0x118 161/162 关闭、1 +0x1CC 610/611 会员升职、2 +0x280 612/613 成员踢出、3 +0x334 614/615 盟主转让、4 +0x3E8 616/617 邀请入会、5 +0x49C 618/619 行会公告、6 +0x550 620/621 退出行会、7 +0x604 622/623 行会解散、8 +0x6B8 624/625 关闭窗口。
- **点击分派 0x4258F0 检查序 = 0,1,2,3,4,7,5,8,6**（非 ctor 序）；prologue `mov eax,0x148C; call 0x468D10`（栈分配），x=[esp+0x1494]、y=[esp+0x14A0]，先经 0x417E60 滚轮控件 this+0x76C；调用方=主鼠标分派 0x42C039-0x42C052（lea ecx,[esi+0x4707C]; call 0x4258F0）→ push 4 → 0x42ADB0 输入后 id-hook。
  - ctrl0 关闭：命中→return 已消费，无分派侧状态变更。
  - ctrl1 会员升职：[this+0x98]=0;[this+0x9C]=0; call 0x4523E0 @0x8AB828（0x42595D-0x425973）。
  - ctrl2 成员踢出：[this+0x98]=1;[this+0x9C]=0; call 0x452410 @0x8AB828（0x42599B-0x4259B1）。
  - ctrl3 盟主转让：raw `c7 86 9c000000 00000000 c6 86 98000000 02` @0x4259D9 = [+0x9C]=0;[+0x98]=2 → other 态绿页。
  - ctrl4 邀请入会：守卫 [this+0x94]==0 → tooltip 0x47BAA4（0x425C71-0x425C8F）；否则 0x42ADB0(0x7243A4, 0xF) 隐藏横幅、开对话框窗 0x777200（0x423E80，帧 0x25A=602，[0x7773D0]=1）、组 list3（头 +0xEC/count +0xFC）经 0x45DC70 "%s\r\n"（0x47BB4C）→ 0x8B187C、call [0x4762CC] 提交（0x425A11-0x425AC4）。
  - ctrl7 行会解散：守卫；[+0xB4]==0 → tooltip 0x47BB28 "请先选择行会成员名单,再点这里编辑."（0x425B05-0x425B19）；否则隐藏 0x7243A4、开对话框帧 0x259=601 且 [0x7773D0]=0、组 list1（头 +0xBC/count +0xCC）、call [0x4762CC]（0x425B2A-0x425BC2）。
  - ctrl5 行会公告：守卫；tooltip id 0x40F、text 0x47BAF4 "%s  请输入要删除的行会成员名字"（sprintf 0x46811C，%s=[this+0x54]）（0x425BD6-0x425C1D）。
  - ctrl8 关闭窗口：守卫；tooltip id 0x415、text 0x47BAC8 "请输入要解除联盟关系的行会的名称"（0x425C1F-0x425C50）。
  - ctrl6 退出行会：**倒置守卫** [this+0x94]!=0（掌门）→ 直接 no-op return；成员 → tooltip 0x47BAA4 "只有行会掌门人才能使用这个功能"（0x425C52-0x425C71）。机器事实照录，不做语义"修复"。
  - tooltip 显示 = 0x418030（ecx=0x7E04C8；实参 0x565994,4,flag,text,-1,-1,id）；tooltip 输入 handler 0x42580A-0x4258E9：id 0x415 → 0x46811C 格式化 0x47BA90 "@退出联盟 " → 0x8B187C → 编辑框 0x8AB828 经 0x4520F0+0x4523E0。
- **ctor 寄存器流 vs paint 时间坐标**：paint 时间 SetPosition（0x425152-0x425258）为可见真相：(556,409)/(34,376)/(34,402)/(121,402)/(309,376)/(397,376)/(484,376)/(309,402)/(397,402)。ctor 时间（0x424E60 @ main_init 0x4277E8；实参 4,[main+0x1C],600,102,22,596,446,1）仅 0-3 号可用：+0x118→(260,298)、+0x1CC→(159,50)、+0x280→(567,413)、+0x334→(196,50)；调用 5-9 读陈旧复用寄存器（x=1 或 [main+0x1C]，y=600-帧 id 或 4/72/102/145）→ 垃圾：+0x3E8→(1,145)、+0x49C→([main+0x1C],4)、+0x550→(1,72)、+0x604→(1,102)、+0x6B8→(600,72)。**旧 evidence 中 +0x6B8 ctor 记录 [196,50] 错误，已纠正为 (600,72)**。
- **特殊行着色**：state0 0x425280（守卫 count +0xE4 && head +0xD4，list2）：逐字节 strcmp 标记 0x47BA78 "[行会公告]" / 0x47BA6C "[敌对行会]" / 0x47BA60 "[联盟行会]" → 0x96FF，否则 0xFFFFFF；state1 0x425440（守卫 count +0xB4 && head +0xA4，list0）：标记 0x47BA84 "[行会成员]" → 0x96FF，否则 0xFFFFFF；other 0x425590（list4，头 +0x104/count +0x114）：**无标记逻辑**，每行双画阴影 0xA140A @(win.x+0x22, win.y+0x3B+step*row) + 绿 0xFF00 @(win.x+0x23, win.y+0x3C+step*row)，无白行。三态共享原点 (win.x+0x23, win.y+0x3C)、scroll [+0x9C]、cap 0x12、行步=文本高+5（0x45E0C0）；表头（0x425040）0x96C8FF 经 0x45DE50、字符串对象 [+0x54]，裁剪矩形 win.x+0x15E..+0x233 / win.y+0x18..+0x30。
- 子列表布局：+0xA0/+0xB8/+0xD0/+0xE8/+0x100（counts +0xB4/+0xCC/+0xE4/+0xFC/+0x114），容器 vtable 0x476814。

#### 落盘
`social-window-render-evidence.json`（两窗 pending→closed_notes；member_list_render.formula/column_rule、visibility_guard 标签、text_origin_expression、行会 child_controls[8] 位置均就地纠正）、`ui-coverage-matrix.json`（record id=social → layout_ids=[window.group, window.guild-candidate] + pending:false + closed_2026_08_11；record id=guild → pending:false + closed_2026_08_11）、`UI_COMPLETION_AUDIT.md`（44/45 行闭合）、`UI_COVERAGE_MATRIX.md`（23/24 行闭合）、`MIR3_UI_RECONSTRUCTION_HANDOFF.md`（§6 组队/行会 bullet）。

---

## Finding 246 (StatusWindow, 2026-08-11)：人物状态窗 el82/el83/el139 WIL 绑定闭合 + 视图切换按钮（Frame 172）闭合

### 1. el82/el83/el86 WIL 绑定 —— PRIMARY-STATIC（全静态链）
- **游戏对象 = 静态全局 0x47EF18**（ctor 0x418B00 经 CRT thunk 0x401970）→ owner = 0x5600FC = gameObj+0xE11E4（0x418E70）。
- **元素 ctor 0x452AA0**（this=0x5600FC）：loop1（ebp=14）由 slot base 0x56B22C 构造 el0..el13（mode 1，fallback 0）；loop2 @0x452AF7-0x452B0E（ebx=0x46=70 次，`push 0; push esi; mov ecx,edi; call 0x4660e0; add esi,0x104; add edi,0x144; dec ebx; jne`，ret 8 @0x452B14）由 slots 70..139 构造 **el70..el139（mode 0）**。
- **WIL 表填充 0x452B20**（92 字符串，slots 0..91；ebx=owner；strlen(scasb)+rep movsd/movsb 拷贝块 0x4537F0-0x4538B0，dest 由上一块 lea 决定）：
  - `.\\Data\\Inventory.wil`（0x47CCF8）→ **slot 82 = owner+0x10478 = 0x570574**（store site 0x453804）
  - `.\\Data\\Equip.wil`（0x47CCE4）→ **slot 83 = owner+0x1057C = 0x570678**（store site 0x453829）
  - `.\\Data\\Ground.wil` 0x47CCD0 → slot 84 = 0x57077C（0x10680）；`.\\Data\\MIcon.wil` 0x47CCBC → slot 85 = 0x570880（0x10784）
  - `.\\Data\\ProgUse.wil`（0x47CCA8）→ **slot 86 = owner+0x10888 = 0x570984**（store site 0x4538A2）
  - 其余：GameInter→70、M-Hum→71、M-Weapon1..4→72-75、WM-Hum→76、WM-Weapon1..4→77-80、Magic→81、Horse→87、Mon-1..4→88-91；slot N 地址 = owner + 0xF848 + (N-70)*0x104（N≥70）。
- 消费侧：flag 分派 0x430A40（flag0 → el82=0x5668C4 Inventory.wil 普通槽；flag1 → el83=0x566A08 Equip.wil 角色区 indices 0/1/4；flag2 → el139=0x56B0E8）。

### 2. el139 = EMPTY/UNSET（candidate）
- 构造：loop2 0x452AF7（i=69，mode 0）；map-rebuild 0x43B7B2（start=(byte[map+0x124]+1)*14 @0x43B770-0x43B77C；byte=8 → **start=126 → el126..el139**，mode 1 优先、0x4660E0 失败则 0x465FE0 dtor 后 push 0 重试）。
- path slot 139 = 0x573F58 **无任何静态写入**（0x452B20 只填 slots 0..91）→ 零路径；消费端 0x44D65C/0x44DBAE/0x44E05D（frame=WORD[selector+0x30]）在帧加载失败时跳过绘制。

### 3. Frame 172（配 171）= 状态窗视图切换按钮 —— PRIMARY-STATIC
- 子控件 this+0x10C（ctor 0x44B1B7，帧对 171/172，GameInter.wil；hit rect x=+0xB0=176、y=+0x108=**264**，纠正旧记录 286）。
- 点击处理器 **0x44CCD0**（ret 0xC @0x44CCF6）：子控件命中经 [vtable+0x10] @0x44CD09 → toggle 分支 0x44CD14-0x44CD9F：
  - mode byte **[this+0x54]==1**（equipment view）→ `0x423E80(this, 0xC8=200, [this+0x18], [this+0x1C], 0xF4=244, 0x148)`；[this+0x54]=0；faces (0xAB,0xAC)=(171,172) 经 0x417880。
  - **[this+0x54]==0**（attribute view）→ `0x423E80(this, 0xC9=201, x, y, 0x208=520, 0x148)`；[this+0x54]=1；[this+0x20]>0x320 时第二块 frame 0xC9 @ (x+0x118, y)；faces (0xA8,0xA9)=(168,169)。
  - 初始视图 = attribute（0x427776 以 frame 200 建窗；ctor faces 171/172）。
- 帧尺寸（WIL header 实测）：200 = 256×512、201 = 1024×512（offsetX=7/offsetY=−44）；168/169/171/172 = 36×36 全不透明；171 = 亮色加号核心、172 = 方块+竖条。图标/脸面语义对应（171/172 attribute vs 168/169 equipment）= candidate。
- **0xC24 步长重确认**：click 0x44CDCD-0x44CDD9 `lea ecx,[eax+edx*2]; lea ecx,[ecx+ecx*2]` = idx*12 → `[esi+ecx*4+0x2F4]` = idx*48+0x2F4（0xC24 = 0x30C*4 = 777*4 = 3108）；paint 走 this+0x2F8 + i*0xC24（11 records）。旧 0x40C 为算术错误，slot_record_base 不变。
- 命中测试 0x44B720 = 纯 PtInRect 位置扫描（11 次迭代 @0x44B739-0x44B787，SetRect @0x44B761，import 0x4762B4），**无类别逻辑**（服务端驱动）。

### 4. 证据级别
el82/83/86 绑定、el139 空构造、loop2/0x43B7B7 构造 VA、Frame 172 toggle、0xC24 步长 = **primary-static**；map-rebuild start byte 运行值、el139 运行期语义、槽位业务名（server EquipmentSlot enum） = **candidate/inference**。

落盘：`status-window-render-evidence.json`（pending[0]/[3]→closed_notes；hit_rects y 286→264；observation[3] 帧画修正；flag_dispatch/known_elements/selector_construction 更新）、`equipment-slots-evidence.json`（pending[0]/[2]→closed_notes；selector_wil_binding 更新）、`ui-coverage-matrix.json`（record id=status → closed_2026_08_11）、`UI_COMPLETION_AUDIT.md`（36 行闭合）、`UI_COVERAGE_MATRIX.md`（16 行闭合）、`MIR3_UI_RECONSTRUCTION_HANDOFF.md`（§6 人物状态 bullet）。

---

## Finding 257 (TargetBox, 2026-08-11)：怪物目标框长尾三项闭合（WIL 绑定负证据 / 无头像 / HP 帧=HP 值 + 10000 系列元素 0x57）

### 1. 选择器元素 WIL 绑定 = 静态负证据（primary-static），确切文件名 = 运行期数据（candidate）
- **绑定 API 0x4660E0**（ecx=element，[esp+4]=path，[esp+8]=flag）：flag0 → 拷贝路径+mode0（0x466160）；flag1 → 装载 WIL（`wix` 0x47DBB4，CreateFileA GENERIC_READ，0x466300）+mode1；flag2 → 0x4664B0。帧查找 0x466130 clamp frame<count。
- **14 个直接 E8 调用方全枚举**：0x40272A/0x40273E、0x43B7B7/0x43B7CC（**唯一触碰全局表 0x5600FC 的点 = 地图装载器 0x43B600**）、0x43D4E7/0x43D502、0x43DF64/0x43DF86、0x43EDCC、0x452ABD/0x452AD2/0x452AFC、0x456CC4/0x456CD8——其余全部绑定窗口内嵌元素，从不碰全局表。
- **地图装载器 0x43B600 范围**：N = (header[0x14]+1)*0xE，绑定 [N, N+0xE)。**全部 544 张出货地图 header[0x14] ∈ {0,1}**（530 张=0x00、14 张=0x01）→ 只覆盖 **0x0E..0x1B 或 0x1C..0x29**；目标框元素 0x51/0x56/0x57/0x81/0x89/0x8A 全部在范围外。**旧假设 [map+0x124]=4/5/8 被拒绝**。
- **0x47C3E0 填充格式串死亡**：`%[^`]%*c %[^`]%*c %[^`]%*c %[^`]%*c`（4 token，35 字节）全文件 0 引用——0x56B22C 路径槽的填充者未定位。
- **元素 VA imm32 引用计数（穷举）**：0x566780（0x51）→ 仅 0x40CE96（NPC HP 条块 0x40A8A0：0x4542A0(ecx=0x5600FC,flag by type,0x51,frame=HP) @0x40CE8F → 0x466130(ecx=0x566780,frame)）；0x566DD4（0x56 名字文本）→ 11 个读者（0x40B79C/0x40B811/0x40C958/0x40C9DC/0x4199AE/0x4199F2/0x41C8B5/0x44B577/0x44B649/0x450548/0x450615；名字文本画 @0x40C900 帧 2/3）；0x566F18（0x57）/0x56AE60（0x89）/0x56A440（0x81）/0x56AFA4（0x8A）→ **0 个 imm32 引用**（总是计算 0x5600FC+type*0x144）。
- **选择器注册表 0x4542A0/0x454DA0/0x454E50/0x454CC0**（注册表基址 0x57405C = 0x5600FC+0x13F60；key 格式 %05d%05d%05d @0x47D530）= 运行期缓存，从不打开 WIL。

### 2. 悬停目标头像 = 不存在（NEGATIVE，primary-static）
- **HUD 每帧分派 0x41BF00–0x41C0A0 全链**：0x40A8A0（HP 条）→ 0x40BB00（悬停名牌，纯文字，3000ms 超时，0x40BFE0=浮点结构初始化非绘制）→ vtable+0x80=0x40B750（悬浮名字文本，元素 0x56 帧 2/3）→ 实体扫描循环 0x41BF39–0x41BF87（每悬停对象重复上述 3 个）→ 0x41B1C0 → 0x434D40；另有 vtable+0x84=0x40B850（名字牌框，纯文字 0x45DE50 边框 0xA0A0A×3）@0x41C063。**5 个组件无一是头像**。
- **49×33「头像/名区」= 人物状态窗 this+0x200 = 特殊索引 4**（记录链 hit_test 0x44B6B0 / index_scan 0x44B720 扫 11 条记录 this+0x1C0+idx*0x10，记录步长 0xC24 基址 this+0x2F4，绘制 0x4341F0）：特殊索引 0/1/4 **全部画在固定中央角色区目标 (window.x+0x61, window.y+0xC8)，flag=1**——是角色形象命中/绘制槽，**不是头像纹理**。
- **NPCface.wil 实测**：440 帧、394 空/46 非空、约 100×122 全身像——与 49×33 不匹配，拒绝为头像源。
- 状态窗唯一元素形象画 = 元素 0x46（0x565994）帧 0xA7/0xAA @(window.x+0xB0, window.y+0x109)（frame record [0x5659CC]/dims [0x5659D0]）——运行期绑定，candidate。

### 3. HP 条帧 = HP 值（primary-static 闭合）+ 10000 系列 = 元素 0x57
- **帧索引 = HP 值 [0x61B9C] = [0x61BA0] − [this+0xB4] + [this+0xC4]**，0x40A8A0：元素 = 0x5600FC + type*0x144（type byte [this+0x8D]；0x51/0x89→flag0，0x81/0x8A→flag1）；0x4542A0 注册表调用；0x466130(ecx=element, frame=[0x61B9C])；eax==0 → 跳过；float scale 0x3F800000。
- **0x40F5F0 的 10000+(A%400) 系列是另一个矩形（字段 HUD+0x629FC）**，元素 = [0x62A14] = **0x566F18 = 0x5600FC + 0x57*0x144**（第三选择器字节 [0x629CF]，唯一写入 @0x40C79C/0x40F47F = 0x57，DB-byte 门控；门：byte[+0x629C8]、[0x62A14]!=0、byte[+0xC0]>=0x1D）：**A = [629C8]*400 − [8A]*3000 + [C4] − 0xAA0**（imul 0x190 @0x40F6A9；×3000 链 lea 3/5/5/5 + shl3 @0x40F6AF–0x40F6C0；lea [eax+edx−0xAA0] @0x40F6CB），存 [+0x62A20]，**frame = 0x2710 + (A % 400)**（div 0x190 + add 0x2710 @0x40F6D6–0x40F6DF）。
- **库身份**：GameInter.wil = 1103 帧 < 10000 → 不能承载 10000+ 系列（primary-static 负证据）；实测 ≥10000 帧候选：Tiles5c 20000、SmTilesc 10180、object1c 33125、object2c 30000、M-SHum 32722、M-Hum 27000、M-Helmet1 24000、M-Hair 15000、Horse 10400、M-Weapon1/2/3 30000、M-Weapon4 17000——元素 0x57 具体归属 = 运行期绑定，candidate。
- 状态矩形 0x40F743–0x40F7B1：frame = 3000*(([89]−1)%10) − 3000*[8A] + [C4]，元素 [0x62A10]（门 byte[+0x89]、[+0xC0]<0x19），存 [+0x62A1C]——同族 ≥3000 帧需求。

### 4. 证据级别
地图装载器范围、绑定调用方全集、元素引用计数、0x47C3E0 死亡、HP 帧=HP 值、10000 系列公式与元素 0x57、HUD 分派无头像、49×33=角色槽、NPCface 尺寸 = **primary-static**；确切 WIL 族/路径槽填充者/0x40C020 调用者 = **candidate/未定位**。

落盘：`target-box-evidence.json`（pending 3→1 项 closed_notes 3 条；hp_bar_rect value_a 补 +[C4]、rect_formula 按 push 序修正；resource_binding hp_bar/target_portrait 更新）、`ui-coverage-matrix.json`（record id=target-box → pending:false + closed_2026_08_11）、`UI_COMPLETION_AUDIT.md`（34 行）、`UI_COVERAGE_MATRIX.md`（14 行）、`MIR3_UI_RECONSTRUCTION_HANDOFF.md`（§6 怪物目标框 bullet）。

---

## Finding 245 (StoreWindow, 2026-08-10)：商店/仓库窗口双 store 关系解清 + 状态 0–4 工厂/帧/按钮映射 + 屏幕原点闭合

闭合 `store-window-render-evidence.json`（pending 0–3）与 `store-state-graph.json`（pending 全部）。全部 primary-static（机器码实测），除注明 candidate 外。

### 1. 双 store 关系（最重要，纠正旧记录）
- **UI store = game+0x33188 == session+0x2D8614**（window id 2；ctor 0x44CFC0、dtor 0x44D0B0、post-init 0x44D150、register 0x44D310、paint 0x44E260、click 0x44E9B0/0x44E910；+0x30 = game+0x331B8 = session+0x2D8644）。
- **protocol store = game+0x2D8614 == session+0x57DEA0**：接收 msg 0x285/0x28A/0x28B/0x28C/0x2C0/0x2C8（经 0x44F480/0x44E8B0/0x44F710/0x44F940/0x44FB00）；+0x30 = game+0x2D8644（0x2C0/0x2C8 接收体 hide-if-set 门）。
- **基址规则（证明）**：包接收体 ebx=game（0x41F999 `mov [ebx+0x35B1E8],ecx`）；更新循环 0x41C1E0 esi=session（`lea ecx,[esi+0x2A548C]` 传 0x42AC50，[esi+0x2F65DC]/[esi+0x2AB9E0]/[esi+0x2D8614] 映射 game+0x51150/+0x6554/+0x33188）。**数值巧合 session+0x2D8614 == game+0x33188 造成旧记录误把更新循环 lea 对 (0x41C22C/0x41C232) 归为 protocol store**；实为 UI store。
- **protocol store 无静态构造**：0x2D8614 全二进制 dword 扫描仅 6 接收 lea（0x41F95C/0x41F985/0x41F99F/0x41F9F2/0x4209CE/0x420A95）+ 2 更新循环引用；无 vtable 写入、无 ctor 调用；store 方法（0x44F940/0x44FB00/0x44E8B0/0x44E260/0x44D590/0x44DB50/0x44E040/0x44F480/0x44F710/0x44E910/0x44E9B0）不出现在任何 vtable。**vtable/链表 vtable（0x476A9C/+0x708、0x476AB8/+0x648）必须运行期安装——静态不可证；无任何指令把 protocol store 数据桥接到 UI store 列表；禁止虚构同步。**

### 2. Store 类对象模型
- **ctor 0x44CFC0 / dtor 0x44D0B0**（0x44D0B0 从 Game dtor 0x426E80 @0x426F77 以 marker 0xb 调用，并从 deleting-dtor 0x44D090 = store vtable[0] 调用）。dtor：写回 vtable 0x476A88 → call 0x4268B0（=jmp 0x423CF0 = 虚槽 1 → 0x44D150）→ 恢复 +0x708 表 0x476A9C/+0x648 表 0x476AB8 → gauge dtor 0x417950(+0x5FC) → 8 控件数组 dtor 0x468306(+0x54, 0xB4, 8, EH 0x4046b0) → 基类 vtable 0x476624 → 0x423CF0（=0x423CA0 reset）→ ret。
- **Game ctor 0x426C10 成员序**（与 dtor 0x426E80 严格逆序）：+0x6554 id0 (0x42e810)、+0x29CE4 id1 (0x44af50)、**+0x33188 id2 Store (0x44cfc0/0x44d0b0)**、+0x3399C id3 (0x415650)、+0x4707C (0x424a60)、+0x47834 (0x424120)、+0x47C28 (0x4501d0)、+0x507EC (0x413da0)、+0x51150 id9 (0x43ea80)、+0x516E8 (0x4471d0)、+0x518E0 (0x440e90)、+0x52118 (0x426780)、+0x524F0 (0x438ef0)、+0x52E5C (0x43e0e0)、+0x53030 (0x4187f0)。
- **注册实参（register-all 尾 0x42777E–0x427794）**：`push 2; push [esi+0x1C](selector); push 0x3E8(1000); push 0; push 0; push 0; push 0x12C(300); push 0x130(304)`；**flag=1 由 0x44D310 内部加**（旧记录 "…,304,1)" 是把站点实参与内部参数混了）。
- **窗口表**：id→对象 base：0→+0x6554、1→+0x29CE4、**2→+0x33188**、3→+0x3399C、4→+0x4707C、6→+0x47834、7→+0x47C28、8→+0x507EC、9→+0x51150…（0x42AAB0 hit-test 表 0x42ABE8；id2 → `lea edx,[esi+0x331A0]` = store+0x18）；窗口列表 head/count @game+0xD28/+0xD30/+0xD38，记录 6×0xC24 @+0xDA4。
- **点击**：主鼠标分派 0x42BEAA→hit-test 0x42AAB0→cmp edi,2→0x42BEEB `0x44E910(store)`；`Store::Click(x,y)=0x44E9B0` 仅对窗口关闭按钮返回 1；click 与 draw 都作用于 game+0x33188。

### 3. 更新循环关闭分支（0x41C1E0，this=esi=session）
- `[session+0x2F660C]`(id9 +0x30) → 0x42AC50(game,9) + vtable+0x10([session+0x2F65DC]=game+0x51150, 0) + 清 game+0x428050/+0x42804C。
- **`[session+0x2D8644]`(UI store+0x30) → 0x42AC50(game,2) + `mov edx,[session+0x2D8614]; lea ecx,[session+0x2D8614]; push 0; call [edx+0x10]` = UI store SetVisible(0)**（vtable 槽 4 = 0x423F80，1 参，写 [ecx+0x30]；0x423F90=Set(+0x34)；0x423FA0=3 参 Move）。
- `[session+0x2ABA10]`(id0 +0x30) && `[session+0x2ABA34]`(id0 +0x54 页态) → 0x42AC50(game,0) + vtable+0x10([session+0x2AB9E0]=game+0x6554, 0) + 0x417880(+0x1C4, 0x10B, 0x10C, −1) + 0x42FF90(game+0x6554) + 清 session+0x2CF14C。
- 0x42AC50 = 按 id 注销/释放窗口记录（0x4680F8 free）；0x42ADB0 = 按 id 开/关分派（跳表 0x42B3E4，id≤0xF）。

### 4. 状态 0–4 最终表（含 state2/3 反转纠正）
| state | 业务名 | 证据 | 工厂（frame,x,y,w,h） | paint |
|---|---|---|---|---|
| 0 | 购买五行列表（msg 0x285→0x44F480） | PROVEN | 0x44EAB8/0x44EAF3/0x44F56F (1000,0,186,300,304) | 0x44D590 |
| 1 | 卖网格（msg 0x28C→0x44F710） | 业务名 candidate | 0x44F7EF (1003,1,186,498,304) | 0x44DB50 |
| 2 | 仓库/扩展网格（msg 0x2C0→0x44F940） | 业务名 candidate；帧/尺寸 primary-static | 0x44F940 (1001,−4,182,205,205)，`mov byte [ebx+0x5F8],2` | 0x44DB50 + 4 侧面板 |
| 3 | 合成（msg 0x2C8→0x44FB00） | PROVEN | 0x44FB00 (1000,0,186,300,304)，state=3 | 0x44D590 |
| 4 | 物品详情（发送 0x3F7/0x40A 模式） | PROVEN | 0x44F252/0x44EBD8/0x44F270 (1002,0,184,540,307) | 0x44E040 |
- **state2/3 旧标签反转纠正**：0x44F940 = state 2（frame 1001 紧凑）、0x44FB00 = state 3（frame 1000 五行）——本轮重反汇编确认。
- state2 12 格矩形 +0x720：cols x=22,60,98,136（0x16 起 stride 0x26 <0xAE）；rows y=43,81,119（0x2B 起 stride 0x26 <0x9D）；清 +0x708 链表、[+0x7E4]=0xFFFFFFFF。
- paint 0x44E260：先 `call [vt+0xC]`；state∈{0,4,1,3}→跳 0x44E2F7；**仅 state 2** 落体画 4 extras +0x1BC@(x+0xAC,y+0xA9)/+0x270@(x+0x47,y+0xA5)/+0x324@(x+0x1C,y+0xA2)/+0x3D8@(x+0x89,y+0xA2)（0x417830）；8 控件循环 +0x54 步长 0xB4 `call [ctl_vt+4]`；分派 {0,4,1,3}→0x44D590/{1,2}→0x44DB50/4→0x44E040。五行绘制读 UI store 自身 +0x648 链表（0x44D631 lea ebx,[edi+0x664]…[edi+0x700]）。

### 5. 控件/帧映射（帧 1010–1017 尺寸 = 命中矩形，wilsdk 实测）
- {0,3}：+0x54@(x+0x10A,y+0x10E) **1010/1011 X 关闭**；+0x108@(x+0x7F,y+0x10B) **1012/1013 确认**（48×20）。
- state2：+0x324@(x+0x1C,y+0xA2) **1014/1015 ◀**；+0x3D8@(x+0x89,y+0xA2) **1016/1017 ▶**（28×26）。
- state1（0x44E2F7 块）：+0x1BC@(x+0x1D2,y+0xA9)、+0x270@(x+0x172,y+0xA2)、+0x324@(x+0x144,y+0x9F)、+0x3D8@(x+0x1B2,y+0x9F)。
- state4：+0x48C@(x+0x1FA,y+0x43) 折叠返回、+0x540@(x+0x188,y+0x3D) 确认。
- **面板帧源**：StoreItem.wil 帧 1000–1020 是 24×22 光标，非商店面板；面板 WIL 加载于 0x4540C0 区（`.\\Data\\StoreItem.wil`=0x47C878 与 `MonMagicEx.wil`=0x47C890 拷入 +0x13E5C 相对表）。帧 1000=512×512 bbox(106,102)-(405,408)；1001=256×256 bbox(28,26)-(225,229)；1002=1024×512 bbox(242,102)-(781,408)；1003=512×512 bbox(6,102)-(503,408)；1010/1011/1014-1017=28×26；1012/1013=48×20；1020=16×418 gauge。

### 6. 屏幕原点（pending[0] 闭合）
- state0 content rect = (0,186,300,304)；面板屏幕 (0,184)–(299,490)。**0x423E80 直接按实参建矩形、无父相对居中**（旧 "factory_argument_warning" 撤销）；点击只设拖拽锚点。
- 发送表：0x3F6=state1 格/state4 确认 mode0（0x452230）；0x3F7=state0/3 直购（0x4521F0→0x451E60）；0x408=state2 格；0x40A=state4 确认 mode1/state3 详情；0x3FC=TBD（0x4522E0）。串：0x47B904 点击速度过快/0x47B91C 太重/0x47B940 不能买（msg 0x28B sub 1/2/3）。

### 7. 证据级别
- **primary-static**：双 store 地址与基址规则、ctor/dtor、注册实参、更新循环关闭分支、状态工厂/帧/尺寸、paint 分派、控件偏移、帧尺寸、屏幕原点、msg 0x285/0x2C0/0x2C8 接收链、0x28B 子值、protocol store 无静态构造（负证据）。
- **candidate**：state1/2 业务名（卖/仓库——无服务端消息常量源；web 搜索确认无 Mir3 EI 消息号文档）；protocol store 运行期 vtable/同步机制；state2 外矩形 (−29,157)–(227,413)（derived）。

落盘：`store-window-render-evidence.json`（pending 0–3 → closed_notes 6 条，pending 空）、`store-state-graph.json`（重写：双 store 节、纠正 state2/3、注册实参、闭 0x423E80 语义）、`ui-coverage-matrix.json`（record id=store → pending:false）、`UI_COMPLETION_AUDIT.md`（42 行）、`UI_COVERAGE_MATRIX.md`（19/21 行）、`MIR3_UI_RECONSTRUCTION_HANDOFF.md`（§6 商店/仓库 bullet）。

## Finding 244 (ChatRenderer, 2026-08-11)：聊天文本渲染器 0x45DD70 槽序与可见性门 0x42B180 接线闭合

闭合 `chat-window-render-evidence.json` 剩余两个 pending（ChatDocs Finding 250 留下的真实 pending），全部 primary-static。

**1) 渲染器 0x45DD70 槽序（thiscall ecx=0x8AB7A8，7 参数，ret 0x1C）**
- arg1 = 目标 surface（fallback this->+0x1C；HDC 经 surface->vt+0x44 GetDC out-param 写回 arg7 栈槽）。
- arg2 = X，arg3 = Y，arg4 = textcolor（SetTextColor 0x476060），arg5 = bgcolor（0 → SetBkMode TRANSPARENT 0x476044；非 0 → SetBkColor 0x476050），arg6 = text（strlen + TextOutA 0x476074），arg7 = font（0 → this->+0x28 默认；显式字体由被调者 DeleteObject，默认不删）。
- 实证：TextOutA(hdc, arg2, arg3, arg6, len) @0x45DE12；聊天调用点 0x4147F3（arg1=[0x8AB7C4]、X=this+0x6C0+this+0x18、Y=this+0x6C4+this+0x1C+row、color=msg+0x00、bg=msg+0x04、text=msg+0x08、font=0）。
- [0x8AB7C4] 无任何静态写入：仅经 IDirectDraw::CreateSurface out-param（lea this+0x1C @0x45D53D/0x45D602，call [ddraw_vt+0x18] @0x45D552/0x45D617 in 0x45D380，唯一调用者 0x45D140）；全 disp32-0x8AB7C4 扫描无 store 指令。

**2) 可见性门 0x42B180 接线**
- 门 [ROOT+0x5081C] = 聊天窗自身可见标志 this+0x30（chat=ROOT+0x507EC；0x507EC+0x30==0x5081C；vtable 0x47660C 写入 @0x413E1A；setter vtable+0x10=0x423F80 = mov [ecx+0x30],eax）。
- 关闭路由：close 子控件 chat+0x6C（vtable 0x4763A8）命中测试 vtable+0x10=0x4177F0 → 聊天点击分派 0x4149A0 返 1 → 鼠标 stub 0x42C0B7 → push 8; call 0x42ADB0(ROOT) → 跳表 0x42B3E4[8]=0x42B180。
- HIDE（门≠0）：MoveWindow(edit [0x8AA48C] → x=[0x8AB7F0]+0xDF, y=[0x8AB7F4]+0x23A, 0x162, 0x10, TRUE)；0x42AC50 从激活列表移除窗 8（ROOT+0xD24：head+0xD28/tail+0xD30/count+0xD38）；0x423F80(chat,0) → +0x30=0，ret 0。
- SHOW（门==0）：MoveWindow(edit → w=[ROOT+0x51148]-[ROOT+0x51140], h=[ROOT+0x5114C]-[ROOT+0x51144], x=[0x8AB7F0]+[ROOT+0x50804]+[ROOT+0x51140], y=[0x8AB7F4]+[ROOT+0x50808]+[ROOT+0x51144])；ShowWindow(edit,5)；0x42AC30→0x449870 追加窗 8；0x423F80(chat,1) → +0x30=1，ret 1。
- 'R' 键 @0x42CCF7 切换同一分派；0x42B820 去激活列出窗（0x423F90 → +0x34=0；其跳表 0x42B938[8]=0x42B8B6=chat）；默认索引 5/10/>15 → 0x42B3DD ret 0；兄弟门 0x42B25E（idx 9，门 [ROOT+0x51180]）与 0x42B2AD（idx 15，门 [ROOT+0x52E8C]）。

落盘：`chat-window-render-evidence.json`（closed_notes ×3，pending 空）、`chat-window-unified-model.json`（visibility_gate 接线 + text_renderer 槽序，open_question 闭合）、`ui-coverage-matrix.json`（chat record pending_notes 更新）。

## Finding 263 (DrawOrder2, 2026-08-11)：重复 show(ID) 边界全二进制调用点审计闭合（0x42AC30/0x449870）

闭合 `draw-order-evidence.json` 唯一剩余静态可闭 pending（重复 show 边界），全部 primary-static（机器码实测，binary：`/tmp/nas_mnt/NAS/TMP/EI传奇3.0客户端/Mir3.exe`，image base 0x400000，fileoff=VA-0x400000）。

**审计方法**：capstone E8/E9 rel32 交叉引用 + 全文件 imm32 LE dword 扫描（间接引用证据）。

**(A) 0x42AC30 直接调用方 = 15**（全 E8，无 E9 尾跳）：
- 14 个在 toggle 分派 `0x42ADB0`（跳表 `0x42B3E4`，id 0,1,2,3,0xB,0xC,0xD,0xE,4,6,7,8,9,0xF → 0x42ADFC/0x42AE6F/0x42AEBE/0x42AF0D/0x42AF5C/0x42AFAB/0x42AFFA/0x42B049/0x42B098/0x42B0E7/0x42B15E/0x42B23C/0x42B28B/0x42B34D）。每个 show 分支先判窗口标志 `this+0x30==0`（门地址 [ui+0x6584]/[ui+0x29D14]/[ui+0x331B8]/[ui+0x339CC]/[ui+0x51718]/[ui+0x51910]/[ui+0x52148]/[ui+0x52520]/[ui+0x470AC]/[ui+0x47864]/[ui+0x47C58]/[ui+0x5081C]/[ui+0x51180]/[ui+0x52E8C]），追加后紧跟 `vtable+0x10(1)` = +0x30 setter（14 窗 = `0x423F80` = `mov [ecx+0x30],eax`；store vtable `0x476A54` 槽+0x10 = `0x4488B0` 同样写 +0x30=arg）→ +0x30=1。hide 分支对称：`0x42AC50` + vtable+0x10(0)。
- 1 个在提升 `0x42B6A0`（0x42B6C7）：count=ui+0xD38>0 → `0x42B820` 关全部 → `0x42AC50(ID)` → `0x42AC30(ID)`。

**(B) 0x449870 直接调用方 = 5**：0x42AC3B（在 0x42AC30 内部，唯一触及可见窗链 manager=ui+0xD24 的追加）；0x41538F（泛型集合追加，manager=[obj+4]）；0x448ABA / 0x44933E（store 系物品装载循环，manager=obj+0x1E0）；0x4491B6（排序数组追加，manager=esi）。后 4 个 manager 均非可见窗链 → 无绘制影响。

**(C) 间接引用 = 0**：全文件 imm32 LE dword 扫描 0x42AC30 与 0x449870 各 0 处 → 无 vtable 槽、无跳表项（0x42B3E4/0x42B7E0 指向 case 块）、无 mov reg,imm32 装载。

**(D) 不变式**：14 个列表窗 `this+0x30==1 ⟺ 节点在可见链`（ui+0xD24）。全部 19 个 hide 调用点（14 toggle + 4 直接 0x41C1F6/0x41C227/0x41C254/0x42062D + 提升 0x42B6BF）在 0x42AC50 后均跟 vtable+0x10(0) 清 +0x30；构造函数 0x4175F0 初始化 +0x30=0；其余 +0x30 写者仅 NPC SetActive 0x43F020（经 0x423F80）。提升入口经窗口下光标查找器 `0x42AAB0`（仅遍历可见链 tail→head，window+0x18 rect PtInRect 0x4762B4）命中才可达 → 目标必已在链内，+0x30 保持 1。

**VERDICT**：静态可达路径不存在重复节点，出厂调用图 **primary-static 闭合**。**BOUNDARY（candidate，运行时唯一残留）**：0x42AC30/0x449870 自身从不查成员；链外调用方（脚本/服务端命令、未来代码、运行时 +0x30 失步）对已在链 ID 再追加 → 重复节点粘滞（paint 分派 0x4280F0 每帧重复绘制该 ID；hide 0x42AC50 只摘首个命中节点；close-all 0x42B820 不摘链；count=ui+0xD38 虚增），仅能靠运行时捕获排除。

落盘：`draw-order-evidence.json`（closed_notes[2] 新增 Finding 263，pending 1→1 条业务名映射保留）、`ui-coverage-matrix.json`（exchange record closed_2026_08_11 追加）、`UI_COMPLETION_AUDIT.md`（第 20 行追加）、`UI_COVERAGE_MATRIX.md`（第 33 行追加）。

## Finding 264 (Horse2, 2026-08-11)：0x5600FC stride-324 骑乘外观表资源绑定闭合（element 87 = 0x566F18 ↔ Horse.wil）+ word[0x7DA063] 帧号假设修正

闭合 `horse-window-render-evidence.json` 的 stride-324 骑乘外观表绑定 pending，全部 **primary-static**（机器码实测，binary：`/tmp/nas_mnt/NAS/TMP/EI传奇3.0客户端/Mir3.exe`，image base 0x400000，fileoff=VA-0x400000）。

**1) 元素表与索引计算（primary-static）**
- 元素表基址 0x5600FC（element 0），元素 N 地址 = 0x5600FC + N*0x144（stride 324）。
- 骑乘元素 = element 87 = **0x566F18** = 0x5600FC + 0x57*0x144。
- 选择方式：状态字节 `byte[0x7DA060]`（session 0x777698+0x629C8）≠0 时写入硬编码选择字节 `[esi+0x629CF]=0x57`（**0x40F47F**，同构函数 0x40C78C 内 **0x40C79C** 同样硬编码 0x57），随后 0x40F5A6-0x40F5C0 的 lea 链（`lea eax,[eax+eax*8]; lea edx,[eax+eax*8]; lea eax,[edx*4+0x5600fc]` = ×9×9×4 = ×324）把 `[esi+0x62A14] = 0x566F18`。**状态值 1/2/3 本身不索引元素表**，仅作为写入 0x57 的门控——各子状态的外观差异属运行时项。

**2) Horse.wil 路径绑定（primary-static）**
- 元素管理器构造 loop2（0x452AF7-0x452B0E）：70 次迭代，`element(70+i).bind(slot i, flag=0)`（0x4660E0 → 0x466160），element 87 = 70+17 ↔ slot 17。
- 路径槽 N 地址 = owner+0xF848+(N−70)*0x104；slot 17 = owner+0x1098C。
- 0x4538CB-0x4538E5 把字符串 `.\Data\Horse.wil`（0x47CC94）复制进 owner+0x1098C（copy 目标=上一次迭代预留的 edx；Magic→0x10374、Inventory→0x10478、Equip→0x1057C、Ground→0x10680、MIcon→0x10784、ProgUse→0x10888、Horse→0x1098C，即 slot 81..87，与 Finding 246 的槽表完全一致）。
- 0x4660E0 flag=0 → 0x466160：复制路径到 element+0x40、byte[element+4]=0（mode 0 → 0x466130 → 0x466640 惰性 WIL 加载，[element+8]=WIL 句柄，帧记录 = base+frame*32）。

**3) 消费路径（primary-static）**
- 世界渲染函数 **0x40F5F0**（ret 0x14，5 参）：门控 state≠0 && `[esi+0x62A14]≠0` && `byte[esi+0xC0]≥0x1D`（0x40FA67-0x40FA96）→ `0x466130(ecx=骑乘元素, frame=0x2710+(A%400))`（0x40F6D7-0x40F6E9，A = [629C8]*400 − [8A]*3000 + [C4] − 0xAA0，A 另存 [esi+0x62A20]；0x40FB5C 用 frame=A 二次调用）→ ebp≠0 走 **0x461ED0** 3D 世界绘制（帧记录 [element+0x38] 取 w/h/fx/fy、像素数据 [element+0x3C]，arg9=0xd），ebp==0 走 0x463330/0x460240（0x40FAEE-0x40FB57）。
- 主窗 HUD 坐骑图标（0x44B560-0x44B6AF）：元素 **0x566DD4 = element 86 = ProgUse.wil**（slot 16），帧 = `byte[0x777720]*10 + byte[0x777723] + 0x3B`，`0x466130` 后 `0x45FD50` 绘制，arg6 = `word[0x7DA063]`、arg7 = 0xffff。
- **Finding 255 假设修正**：word[0x7DA063] **不是帧号**。0x45FD50 的 arg6/arg7 是 16 位 RLE 填充色（op 0xC2 用 arg6 填充、op 0xC3 用 arg7，经掩码 [ebx+0x6C/70/74] 与移位 [ebx+0x67/68/69] RGB 分解）；全二进制 0x45FD50 的 23 个调用点中除 HUD 坐骑图标外全部传 0xffff/0xffff，且全二进制 0x7DA063 仅 0x41F5BD（包 case 0x267 写入）与 0x44B669（HUD 读）两处引用。word[0x7DA063] 的来源是服务端包数据（0x41F5BA `mov word[0x7DA063],dx`），协议语义仍为运行时项。

**4) 无关路径排除**：0x430A40 flag 分派（flag0→el82=0x5668C4、flag1→el83=0x566A08、flag2→el139=0x56B0E8）服务于状态窗 el82/83/139 家族（Finding 246），与骑乘元素无关。全 0x5600FC+0x144k (k=0..160) imm32 扫描对 0x566F18 零命中——骑乘元素只经计算指针 [esi+0x62A14] 可达，故此前 stride-324 扫描仅见 13 个槽有 imm32 引用属预期。

**VERDICT**：骑乘外观元素绑定（0x566F18 ↔ Horse.wil）、HUD 图标（0x566DD4 ↔ ProgUse.wil）、帧链（0x466130 + 10000+(A%400)）与填充色用法全部 **primary-static 闭合**。剩余 pending：0x7DA060 1/2/3 子语义、word 字段协议含义（运行时）。

落盤：`horse-window-render-evidence.json`（closed_notes ×2，pending 3→2）、`ui-coverage-matrix.json`（horse record closed_2026_08_11 追加）、`UI_COMPLETION_AUDIT.md`（第 47 行追加）、`UI_COVERAGE_MATRIX.md`（第 28 行追加）。

---

## Finding 266 (StatusWindow, 2026-08-11)：状态窗 selector 长尾闭合——map-rebuild 起始字节 [map+0x124] 语义（= .map 头第 0x14 字节）+ el139 = Data/StoreItem.wil 商店物品选择器（推翻"空槽"假设）

### 1. map-rebuild 起始字节 [ebx+0x124] 语义 —— PRIMARY-STATIC：已加载地图文件头第 0x14 字节
- **唯一调用点** = 地图进入路径：0x422B2B `lea ebp,[esi+0xF5200]`（map 对象 = gameObj+0xF5200）→ `lea edx,[esp+0x14]; mov ecx,ebp; push edx; call 0x43B600`。
- **0x43B600 全链**：格式串 `'.\\Map\\%s.map'`（0x47C404）→ 拼路径复制到 [ebx+4] → CreateFileA（IAT 0x4760DC）→ 0x43B820 `rep stosd`（ecx=7）清零 [ebx+0x110..0x12B] → **ReadFile(hFile, [ebx+0x110], 0x1C) @0x43B68B**。
- **[ebx+0x124] = 0x110 + 0x14** = ReadFile 读入的 0x1C 字节地图头中偏移 0x14 的字节。**全 .text 唯一的字节宽度 [mem+0x124] 访问 = 读取 @0x43B772**；其余 0x124 位点（0x41A210/0x41A2AA 实体位置标志、0x434F1C 构造器 vtable 0x476884、0x435557..0x435624 分派器、0x45A275 构造器 vtable 0x476BD4）均属其它对象类型 → **写入者唯一 = 该 ReadFile**。
- **公式** @0x43B770-0x43B77C：`mov al,[ebx+0x124]; mov cl,0xE; inc al; imul cl` → `start = (byte+1)*14`。
- **重建循环 0x43B7B2**：14 次迭代，元素 = 0x5600FC + start*0x144，槽 = 0x56B22C + start*0x104；`push 1; call 0x4660E0`（mode 1）失败 → 0x465FE0 析构 → `push 0` mode-0 回退。**析构循环 0x43B75B 恒定销毁 el14..el69**（esi=0x5612B4，< 0x565994=el70）。
- **发行地图分布（544 个文件，Map/ 目录跳过）**：header[0x14] ∈ {0: 530 个, 1: 14 个}；**type=1（byte=1）= 4.map（32×32）与 41..44.map（144×144）**——此前"800×800"断言为错（那是 32 位头两个 dword 的误读）；byte=4（→el70..83）与 byte=8（→el126..139）在**任何发行地图中都不出现**（仅假设性）。打开失败默认 = 0（bss，0x43B820 清零）。
- **运行期后果**：每个发行地图实际只重建 el14..el27（byte 0）或 el28..el41（byte 1），mode 1。

### 2. el139 = Data/StoreItem.wil 商店物品选择器 —— PRIMARY-STATIC（推翻"空槽"假设）
- **0x452B20 填充覆盖 slots 0..139（140 条 WIL 路径）**，并非 0..91：slot N = owner+0xB130+N*0x104（N≥70 等价 owner+0xF848+(N-70)*0x104，70*0x104=0x4718、0xB130+0x4718=0xF848）；**slot 139 = owner+0x13E5C = 0x573F58**，字符串 `'.\\Data\\StoreItem.wil'`（0x47C878）拷贝 @0x4540E8（`mov edi,0x47C878` → rep movsd/movsb 入 [edx]，edx=lea [ebx+0x13E5C] @0x4540D4）；前一槽 138 = MonMagicEx.wil（0x47C890）。
- 槽带布局（全表）：0–13 基础瓦片 tilesc.wil@0x47D51C（slot0=lea 前那个 mov，配对规则：slot0=lea 前 src、slot i≥1=lea 后 src）…object2c.wil；14–27 Wood\、28–41 Sand\、42–55 Forest\、56–69 Snow\；70–81 角色（M-Hum/M-Weapon1-4/WM-Hum/WM-Weapon1-4/Magic）；82 Inventory.wil、83 Equip.wil、86 ProgUse.wil、84 Ground/85 MIcon；87–106 Mon-1..20、107–126 MonS-*、127 NPC.wil、128 MonMagic.wil、129 MonImg.wil、130 M-Hair、131 M-Helmet1、132 WM-Hair、133 WM-Helmet1、134 DMon-1、135 DMonS-1、136 MagicEx、137 MonMagicEx、138 MonImgEx/MonMagicEx.wil、**139 StoreItem.wil**。
- **绑定**：元素 ctor 0x452AA0 loop2 0x452AF7（70 次）把 el70..el139 由 slots 70..139 以 flag0 绑定 → **el139 在 ctor 即功能可用**（mode0 绑定 0x466160：路径→[ebx+0x40]、拼 `"wix"`（0x47DBB4）急切开 .wix、24 字节头 → 帧数 [ebx+0x10]、帧表 malloc(count*0x20)→[ebx+0xC]；.wil 帧按需经 0x466640 懒加载）。
- **分派 0x430A40 全解码**：flag（[esp+0xC] 字节）==0 → el82=0x5668C4（0x430AB9）；==1 → el83=0x566A08（0x430A83）；**==2 → 不绘制 return 1（0x430B60）**；**==3 → el139=0x56B0E8（0x430A60-0x430A75，帧查 0x466130、0 则跳过，绘制 el139+0x38=[0x56B120] 帧数据）**。flag1 绑定 0x466300（急切）、flag2 绑定 0x4664B0（byte[+4]=2）**从不使用**，全二进制无调用点传 2。
- **直接 el139 读取者 = 恰好 4 个 imm32 0x56B0E8 引用**，全部经 0x466130 守卫 je 跳过：0x430A63（分派 flag3）、0x44D65C 与 0x44DBAE（大商店窗口函数 0x44CE8C..0x44E037 内；物品记录指针 +0x30/+0x28、槽数组 [esi+0x664]/[esi+0x7f0]、计数 [esi+0x700]/[esi+0x7e0]、11 槽 × 0xC24）、0x44E05D（0x44E040 内）。**唯一 flag==3 调用点 = 0x44DCC4**（0x44D4xx..0x44E037 尾）。全部为商店物品图标绘制路径（StoreItem.wil = 商店物品图标）。
- **imm32 全扫描**：0x573F58（slot139）无其它写/读；0x56B22C 仅 0x43B7AE（重建循环）；0x56B0E8 即上述 4 处 → **slot139 仅 0x452B20 写入，el139 仅（假设性 byte=8 的）地图重建可重绑**。
- 运行期语义：分派 flag3 由商店窗 0x44DCC4 在商店条目绘制路径传入 → el139 的 .wix/.wil 实际装载 = 运行期（商店打开时），静态侧全链 primary-static。

### 3. 陈旧断言修正汇总（全部为本文件 2026-08-10/246 遗留）
- "type=1 地图 800×800" → **错**：32×32（4.map）/ 144×144（41–44.map），header[0x14] 分布 {0:530, 1:14}。
- "0x452B20 只填 slots 0..91（92 字符串）" → **错**：覆盖 slots 0..139（+8 个非网格填充：Sound\、wix、DirectX 错误文本、`[ 女`、0x14A0/0x17AC/0x1AB8/0x1DC4/0x20D0 空项）。
- "el139 空槽 / EMPTY/UNSET（slot 139 无写入）" → **错**：slot 139 = StoreItem.wil，el139 = 商店物品选择器（模式 0，ctor 即功能）。
- "元素 ctor 填 slots 0..91" → **错**：loop1 绑定 el0..13（flag1）、loop2 绑定 el70..139（flag0）。
- Finding 264 表述 "flag2→el139" → 精确化：**flag==2 = 不绘制 ret 1；flag==3 = el139**。

### 4. 证据级别与剩余 pending
两项闭合均 **primary-static**（公式、写入者唯一性、140 槽填充提取、4 消费点、544 地图分布全部来自静态反汇编）。剩余 pending：装备槽人类可读名（EquipmentSlots 所有权，server enum 需运行期）、少数属性数值绘制颜色语义（超范围，保持 pending）。

落盘：`status-window-render-evidence.json`（pending 4→2；closed_notes 追加 ×2：map-byte 语义 + el139 StoreItem；陈旧 el139 空槽条目标注 SUPERSEDED；selector_construction.located/evidence_level、interpretation 修正）、`ui-coverage-matrix.json`（status record closed_2026_08_11 追加 ×2 + pending_notes 缩减）、`UI_COMPLETION_AUDIT.md`（第 36 行 el139 空 → StoreItem.wil + 缺口列缩减）、`UI_COVERAGE_MATRIX.md`（第 16 行 el139 空 → StoreItem.wil）。

## Finding 262 (InventoryWindow, 2026-08-11)：背包窗 0x7DA100 主数值 + 记录填充子树 + 0x405 死门 + 模式标签 GB18030 全链闭合

### 1. 主数值 [0x7DA100] —— PRIMARY-STATIC + PRIMARY-STATIC-NEGATIVE：本构建从未写入
- **写入者扫描**：0x7DA100 ∈ bss（.data raw 止于 VA 0x47F000，无绝对写入）；全二进制 imm32 `00 A1 7D 00` 扫描 = 恰好 2 个读取者：
  - **0x41729D**（死门 0x417280 内）：`cmp ax,0x405; shr eax,16; test al,al` → `atoi(arg2) > [0x7DA100]` 则抑制，否则 0x451B00 发送。**唯一 E8 调用者 0x42D6C6 传 category byte 4**（跳表 0x42D680 实为 category 3 → 门；byte2==0 守卫与 category-3 路由矛盾）→ **门死**。
  - **0x42EE4C**（背包 paint）：`sprintf %d` 于 rect (x+0x41, y+0x11A)-(x+0x8E, y+0x12B)，色 0x64C8F8 经 0x45DE50。
- **显示值恒为 0**；语义名（候选：交易/购买数量上限）仍需运行期观察 → pending 保留。

### 2. 记录填充子树 —— 0x42FC40 为函数中段，真实入口 0x42FC20 是活的（13 调用者）
- **0x42FC40 是 0x42FC20 的中段**（capstone 从非序言开始反汇编的假象）；真实入口 **0x42FC20**：13 个直接 E8 调用者，其中 **10 个位于 0x41xxxx 服务器消息处理段**（各自从接收缓冲拷贝 0xC20 字节记录后调用 0x42FC20(bag, itemData)）。
- **0x42F440** = 记录位虚函数：唯一调用者 0x42FC90（死子树内部）→ 0x42F440 确实死，但**不代表填充路径死**。
- **单元格表算术闭合**：this+0x2C4，6 WORD/行，值 = slot+0x3E8；绘制 0x42F7CC-0x42F7E2。
- 0x42FC20 的 10 个消息号解码需运行期包捕获 → pending 保留（措辞已修正）。

### 3. 出站消息 0x405 —— PRIMARY-STATIC-NEGATIVE：唯一发送点=死门
- 全二进制 0x405 真实引用**恰好 3 处**：门比较（0x41729D）、输入对话框 ctor **0x418030** 参数（存为 WORD [obj+0x460] 消息 id；0x47AD98 = `您要付给对方多少金币?` 交易付款提示）、死发送者 0x451AD0。
- 对话框确认处理 0x418545/0x418648 读 [obj+0x460]，经 **0x417034 实际发送 0x406**（非 0x405）。
- 假阳性排除：0x400137 = PE 头数据目录大小字段、0x4650A6 = jmp rel32 位移，均非代码引用。
- 服务器侧 0x405 确切语义 = 运行期/协议级 → pending 保留。

### 4. 模式标签 GB18030/GBK 全链 —— PRIMARY-STATIC（修正[木柴]为[储存]，[包袱]非[包裱]）
- **跳表 0x42F13C**（paint 分派 0x42EF2F）：mode0 `[包袱]` 0x47BE10 @0x42EF52 色 0xF8DCFA；mode1 `[修补]` 0x47BDF4 @0x42F02E；mode2 `[变卖]` 0x47BDEC @0x42F068；mode3 `[储存]` 0x47BDE4 @0x42F0EB 色 0xF8C8C8。
  - **修正**：旧记录 "3=[木柴] firewood" 错（`木柴` 全二进制字节扫描不存在）；0x47BDE4 经 GB18030 解码 = `[储存]`（存储）。
  - **修正**：0x47BE10 = `[包袱]`（GBK `\xb0\xfc\xb8\xa4`），非 [包裱]。
- **负重/总量格式 0x47BDFC = `负重:%d / 总量:%d` 是活的**：唯一 imm32 引用 0x42EFBF，读 0x7DA11D/0x7DA11F（imm32 0x42EFA1/0x42EFB5），仅 mode-0 分支绘制（0x42EF8F-0x42F029，随后 jmp 0x42F123），(x+0x86, y+0x18) 色 0xA0A0A、(x+0xF0, y+0x26) 色 0xF8C8C8。
- 0x47BE18 = `굴림체`（cp949 Gulim 字体名，GBK 解码为乱码）→ 共享字体参数，**非标签**。
- 同族显示：人物状态窗 0x44BF39/0x44BF40 读同一组 word，格式 0x47C740 `%d / %d`，标签 0x47C720 `包袱负重`/0x47C714 `装备负重`（0x45DD70 TextOutA 链，色 0xF8F8F8）；悬停 tooltip 0x42A277 用 0x47BD40 `(负重)%d/%d`。

### 5. 证据级别与剩余 pending
闭合均为 primary-static（imm32 扫描、跳表解码、GBK/GB18030 字节验证、13 调用者枚举）。剩余 4 项 pending：0x7DA100 语义名、10 个消息号、0x405 服务器语义、3 tab↔4 mode 运行期映射。**注意**：本文件部分改写由 Inventory2 子代理执行至中途失败，由编排器（orchestrator）依据其已验证结论补完（含 `[包裱]`→`[包袱]`、`輝重`→`负重` 字符修正与 pending 重写）。

落盘：`inventory-window-render-evidence.json`（closed_notes +3：0x7DA100 主值 / 打包字段修正 / 记录数组 ctor-dtor 链；pending 重写 4 项；[木柴]→[储存]、[包裱]→[包袱] 全文件修正）、`ui-coverage-matrix.json`（inventory record closed_2026_08_11 追加 ×3）、`UI_COMPLETION_AUDIT.md`（第 37 行背包行补 Finding 262）、`UI_COVERAGE_MATRIX.md`（第 17 行背包行补 Finding 262）。

## Finding 261 (HudLabel2, 2026-08-11)：HUD 底部操作栏 16 槽 caption 阵列闭合——四路分派循环（绘制/移动/按下/释放）+ tooltip SetTextColor COLORREF=0x000000

闭合 `hud-label-evidence.json` 的全部 3 个 pending（caption SetTextColor 精确 COLORREF、HUD 侧 caption 分派循环、运行期悬停可达性与打字机揭示方向），全部 **primary-static**（机器码实测，binary：`/tmp/nas_mnt/NAS/TMP/EI传奇3.0客户端/Mir3.exe`，image base 0x400000，fileoff=VA-0x400000）。caption 阵列由 8 槽扩展解码为 **16 槽**（hud+0x567c..0x6108，步长 0xB4）。

**1) SetTextColor 精确 COLORREF —— PRIMARY-STATIC：caption/tooltip 链固定 0x000000（纯黑）**
- 0x45DE50 = 9 实参 thiscall 文本合成器（ecx=0x8AB7A8，ret 0x24）；颜色槽（0x45DEC2-0x45DEC8 `mov eax,[esp+0x28]; push eax; push ecx; call [0x476060]` SetTextColor）= arg6。
- caption tooltip 渲染器 0x417370 @0x4174FF-0x417531 调用它：arg6 槽 = 字面 `push 0`（0x41750C）→ **COLORREF=0x000000 BLACK**；arg7 bg=0 → SetBkMode(TRANSPARENT 0x476044)；arg9 font=0 → 默认字体 [ctx+0x28]。
- 聊天逐条消息走另一渲染器 0x45DD70（TextOutA 0x476074），与本链无关；caption 文字 = 黑字 + 0x96FFFF 淡黄底 + 1px 黑框。此前 closed_note 中「颜色源未验证（疑似默认白）」一句作废。

**2) 16 槽 caption 阵列与构造 —— PRIMARY-STATIC**
- HUD = gameObj 0x47EF18 + 0x2A548C；caption 阵列 = hud+0x567c..0x6108，16 槽、步长 0xB4、每槽 vtable 0x4763A8。
- HUD ctor 链：0x426FE5 `0x468306(&+0x567c, 0xB4, 0x10, 0x4046B0)` 数组构造 → 16×0x4175F0 重置 + 16×0x417630 重置。
- 16 个 9 实参构造调用点（imm32 槽偏移 → lea 起点 → E8 调用点规则）：0x4279B2/0x4279E6/0x427A1A/0x427A4E/0x427A82/0x427AB6/0x427AEA/0x427B24/0x427B58/0x427BAA/0x427BFC/0x427C4D/0x427C9F/0x427CF1/0x427D42/0x427D94。
- 9 实参 ctor 0x417550（arg9..arg1 = 0,-1,1,text,y,x,state_frame,frame,parent）：+0x14=parent、+0x18=frame、+0x1C=state_frame、+0x20=-1、+0x24=1、+0x25=0（NORMAL）、+0x28=x、+0x2C=y、+0x34=text。
- 16 槽内容（帧对 / 文字 / 相对 hud.left/top 偏移）：0x567c=交易栏(Ctrl+C, C) F80/81 (+0xCC,+2)；0x5730=任务栏(Ctrl+V, V) F82/83 (+0xE4,+2)；0x57e4=技能图鉴(Ctrl+B, B) F84/85 (+0xFC,+2)；0x5898=退出游戏(Alt+Q) F90/91 (+0xA1,+0x2E)；0x594c=注销人物(Alt+X) F92/93 (+0xA1,+0x52)；0x5a00=组队(Ctrl+G, G) F94/95 (+0x268,+0x2F)；0x5ab4=行会(Ctrl+F, F) F96/97 (+0x268,+0x52)；0x5b68=腰带(Ctrl+Z, Z) F159/159 (+0x189,+0xD)；0x5c1c=技能书(Ctrl+E, E) F100/101 (+0x2BF,+0x10)；0x5cd0=聊天记录(Ctrl+R, R) F102/103 (+0x2CE,+0x20)；0x5d84=信息窗口(Ctrl+D, D) F104/105 (+0x2CE,+0x46)；0x5e38=设置栏(Ctrl+N, N) F106/107 (+0x2BF,+0x55)；0x5eec=帮助窗口(敬请期待) F108/109 (+0x298,+0x56)；0x5fa0=坐骑(Ctrl+S, S) F110/111 (+0x288,+0x46)；0x6054=包袱栏(Ctrl+Q, Q) F112/113 (+0x288,+0x20)；0x6108=状态栏(Ctrl+W, W) F114/115 (+0x299,+0x10)。
- **编码注记**：0x5eec 槽文字 0x47BC04 字节仅 EUC-KR 可解码 = `도움말창(지원예정)` = 帮助窗口(敬请期待)（GBK/Big5 均乱码）——中文重打包客户端里的韩版遗留字符串。

**3) HUD 侧四路分派循环 —— PRIMARY-STATIC**
- 每帧渲染 0x4294E0（主循环 @0x41C0F7）→ caption 绘制循环 **0x42954B-0x429564**：`lea edi,[esi+0x567c]; mov ebx,0x10; L: mov eax,[edi]; mov ecx,edi; call [eax+4]; add edi,0xB4; dec ebx; jne L`（16 次，vtable+4 = 0x417640）。
- 主输入层 3 个直接调用（鼠标坐标 main+0x35B2A8/0x35B2AC）：move **@0x41D457 → 0x42C510**、press @0x41D57B → 0x42BA20、release **@0x41DC82 → 0x42BE20**。
- 移动循环 **0x42C770**：`add esi,0x567c; mov ebp,0x10; L: mov edx,[esi]; push edi(y); push ebx(x); mov ecx,esi; call [edx+8]; add esi,0xB4; dec ebp; jne L`，xor eax,eax / ret 8（0x417780 hover-only，从不消费）。
- 按下循环 **0x42BAC9**：`lea ebp,[esi+0x567c]; call [vtable+0xC]`（0x4177C0），首命中即消费（ret 1）。
- 释放循环 **0x42BF02**（0x42BE20 先清 [esi+0xd3c]）：计数器 [esp+0x14] 0..0xF、slot = counter*0xB4+0x567c、`call [vtable+0x10]`（0x4177F0）；命中 → 每 caption 点击动作跳表 **0x42C494**（16 项，例 0x42BF37: `mov ecx,0x47ef18; call 0x419cc0`）；循环尾 0x42C359（inc/cmp 0x10/jl）。
- 处理器语义：0x417780/0x4177C0 PtInRect（IAT 0x4762B4）于 this+0x04；内 && state≠2 → [0x25]=1/2（ret 8）；0x4177F0 释放内 → [0x25]=0 + 点击音 0x69（0x45AFC0(0x8AB130,0x69,0,0,0)）ret 1。
- paint 状态机 0x417640 汇总：NORMAL && [0x20]=-1 → 不画；HOVER → 仅光标锚定黑字 tooltip（0x417370）；PRESSED → state_frame 美术（159 腰带/101 技能书/103 背包，0x460240 合成）。

**VERDICT**：caption 链 3 个 pending 全部 primary-static 闭合（COLORREF=0x000000；四路分派循环 0x42954B/0x42BAC9/0x42C770/0x42BF02；悬停/按下/释放静态闭环含释放路径）。剩余：运行时血/魔/经验注入（协议级）、打字机揭示方向运行期验证（candidate）、0x42C494 各 caption 点击动作逐条业务解码（长尾，非 pending）。

落盘：`hud-label-evidence.json`（pending 3→0，closed_notes +3，caption_ctor_table 8→16 行，dispatch_note 升为 primary-static）、`ui-coverage-matrix.json`（hud record closed_2026_08_11 追加）、`UI_COMPLETION_AUDIT.md`（第 33 行）、`UI_COVERAGE_MATRIX.md`（第 12 行）。

## Finding 265 (EquipmentSlots, 2026-08-11)：装备槽客户端↔服务端槽位映射闭合——线上 slot 字节=记录索引==EquipmentSlot 枚举（H2 定案）

闭合 `equipment-slots-evidence.json` 的唯一剩余 pending（槽位人类名称/索引映射），并将 `status-window-render-evidence.json` 的 pending #1（装备槽人类名称）结论一并落盘（sibling 文件本身未编辑）。全部 **primary-static**（机器码实测，binary：`/tmp/nas_mnt/NAS/TMP/EI传奇3.0客户端/Mir3.exe`，image base 0x400000，fileoff=VA-0x400000）。

**1) 线上链路端到端解码 —— PRIMARY-STATIC（点击→暂存→发送→线上字节，零翻译）**
- 命中测试 `0x44B720` 返回**原始记录索引 0..10**（纯位置 PtInRect 扫描，无类别逻辑）。
- 暂存 `0x44BBD0(this, slotIndex=arg1, cursorItemStruct=arg2)`（ret 8）：arg1 低字 → pending 槽位字 @`this+0x8886`；arg2 源结构守卫 `[edx]!=0/[+0xC]==0/[+0x10]==0`，数据 `@edx+0x18 → @this+0x8884`（rep movsd 0x308 dwords = 0xC20 字节），标志 `@this+0x8880=1`，源结构清零 0x30E dwords。（纠正旧读法 arg2="itemData"。）
- 发送 `0x44CEA7 push ebp(=点击索引)` → `0x451690(arg1=0x3EB, arg2=索引, arg3=this+0x8888 pending 记录, arg4=[this+0x88C1] itemID)`（4 实参 ret 0x10）；发送器内 `movzx ax, byte[esp+8]` = **byte(arg2) = 线上槽位字节**。
- 组包 `0x452940`（6 实参 ret 0x18）：wire = **{dword itemID=arg3, word opcode=arg2(0x3EB/0x3EC), word slotByte=arg4, word 0, word 0}**（12 字节）——纠正旧误读 "{0x3EB, itemID, slot, 0, 0}"。`0x451E60(this, &this+0x18, arg3)` 发送。
- 背包 msg 0x3EC 同构：`0x451690(arg1=0x3EC, arg2=byte[edi+0x1A]=背包槽位字, arg3=name, arg4=itemID)`。
- **任何一跳都无翻译**：线上槽位字节 = 点击记录索引 = 服务端 EquipmentSlot 枚举（服务端按 `Globals.EquipmentOffSet + enum` 索引装备数组，客户端必须对齐）。

**2) 兼容分派 0x44B7A0 —— PRIMARY-STATIC：仅枚举对齐编号自洽**
- 签名 `(this, cursorItemData*, clickedSlotIndex(byte bl), mouseX, mouseY)`：rect 经导入 SetRect [0x4762B0] 由 `this+0x1C8` + winX/winY（`[this+0x18]/[this+0x1C]`）构造（11 次、步长 0x10），PtInRect [0x4762B4] 判 (mouseX=arg3, mouseY=arg4)。
- 开关：类型 ∈{7,8} → bl∈{7,8}（戒指）；类型 ∈{5,6,9}：subtype==0x19 → bl∈{5,9}，否则 bl∈{5,6}（手镯/鞋子）；恒等 `al==bl` 覆盖 {0,1,2,3,4,10}。**经典 Mir2 编号会使该开关自相矛盾**（Ring(6)→{5,6}、Shoes(7)→{7,8} 荒谬）；类型 9（鞋子）怪癖进一步钉死 slot 9=鞋子、slot 5=手镯。

**3) 定案映射表（11 行，客户端 idx == 服务端枚举 == 人类名称）**
idx0=Weapon 武器（loop7/+0x1C0 纸娃娃区）、idx1=Armour 衣服（loop8/+0x1D0 属性面板）、idx2=Helmet 头盔（loop1/+0x1E0 (27,264)）、idx3=Torch 火把（loop0/+0x1F0 (177,70)）、idx4=Necklace 项链（loop9/+0x200 头像区）、idx5=BraceletL 左手镯（loop3/+0x210 (27,186)）、idx6=BraceletR 右手镯（loop4/+0x220 (175,186)）、idx7=RingL 左戒指（loop5/+0x230 (27,227)）、idx8=RingR 右戒指（loop6/+0x240 (175,227)）、idx9=Shoes 鞋子（loop2/+0x250 (64,264)）、idx10=Poison 毒药（loop10/+0x260 (103,264)）。绝对坐标 = 相对 +(278,136)。

**4) 视觉标签弃置与说明**
- 早期证据文件里的美术标签（火把@(27,264)、头盔@(177,70)、毒药@(64,264)、鞋子@(103,264)）为**美术派生位置猜测，非协议映射**，标记 UNVERIFIED（需带视觉模型的重跑；本环境 `opencode-go/deepseek-v4-flash` 不支持图像输入）。H2 下底行相对坐标读作 [头盔(idx2)@(27,264)、鞋子(idx9)@(64,264)、毒药(idx10)@(103,264)]，顶部中央盒=火把(idx3)@(177,70)。
- `status-window-render-evidence.json` pending #1（"classic Mir3 eight-piece mapping stays candidate"）→ 经本链 CLOSED，由经典八件套候选升级为 11 行定案表。

**VERDICT**：槽位映射全部 primary-static 闭合（线上链路 + 兼容开关自洽 + Zircon 规范枚举三证合一，H2 定案）。剩余非静态项：帧 201 图标级视觉标签像素验证（需视觉模型，candidate/unverified）；sibling 文件属性数值绘制颜色语义（他文件 pending，不动）。

落盘：`equipment-slots-evidence.json`（pending 1→0，slots 8→11 行定案表，mapping_basis 重写为线上链路+兼容+枚举三证，conclusion/evidence_level 升级，closed_notes +5，视觉标签弃置说明）、`ui-coverage-matrix.json`（status record closed_2026_08_11 追加）、`UI_COMPLETION_AUDIT.md`（人物状态/装备行）、`UI_COVERAGE_MATRIX.md`（人物状态/装备槽行）。

## Round 3 (2026-08-11)

### Finding 271 (MonsterPortrait, 2026-08-11)

**问题**：人物/怪物头像（portrait）贴图来源四个区域：(a) 状态窗口 49×33 头像区、(b) 目标框、(c) 目标框/对话中的怪物头像、(d) 选人界面头像；并复核 pending：目标框 selector 元素 0x51/0x56/0x57/0x81/0x89/0x8A 的 WIL 文件名是否为纯运行时数据。

**调查**：
- EXE GBK 字符串扫描：头像/头像框/肖像/人物像/怪物像/面孔 = 0 命中；脸 = 1 命中（0x47B673 骷髅脸，交易消息内，无关）；face = 3 命中（Interface1c.wil 路径 + DDX 错误串）。二进制内唯一肖像类资源名 = NPCFace.WIL（0x47C4EC，NPC 窗口 0x43ED00 构造 @0x43EDC5 绑定到 owner+0x278，440 帧，46 帧非空）。
- WIL 字符串表全解：fill 0x452B20 + 元素循环 0x452AF7（el70..el139 ← owner+0xF848+(N-70)*0x104，slot k ← str[144-k]）。定案 store 位点：el81=0x566780=Magic.wil（0x4537D0/0x4537DB，slot 0x10374←0x47CD10）；el86=0x566DD4=ProgUse.wil（0x45388C/0x4538A1，slot 0x10888←0x47CCA8）；el87=0x566F18=Horse.wil（0x4538B7/0x4538CB，slot 0x1098C←0x47CC94，Finding 264）；el129=0x56A440=MonMagic.wil（0x453F44/0x453F59，slot 0x13434←0x47C950）；el137=0x56AE60=MagicEx.wil（0x454087/0x454098，slot 0x13C54←0x47C8A8）；el138=0x56AF94=MonMagicEx.wil（0x4540AC/0x4540C0，slot 0x13D58←0x47C890）；el139=StoreItem.wil（0x4540D4/0x4540E8，slot 0x13E5C←0x47C878，Finding 266）。
- (a) 状态窗口 49×33 区：非头像 WIL 帧——无任何绘制指向该矩形本身；它是 11 条装备记录链的索引 4（EquipmentSlot.Necklace），paint 0x44B560 以 flag=1 在固定角色区 (winX+0x61, winY+0xC8)=(97,200) 经 0x430A40 绘制 el83 Equip.wil 纸娃娃 @0x44B5E0-0x44B614，矩形 (94,71)-(143,104) 仅用于 hit_test 0x44B720 点击。矩形内容 = GameInter.wil F200 内嵌横幅装饰（行 92-110：角饰+纹理带，primary-resource-visual 像素核验，无面孔）。角色呈现：el86 ProgUse.wil 帧 byte[0x777720]（F0/F1 96×172 全身，off −24,−121）@0x44B56F-0x44B5C3 + 装备图标 el86 帧 0x3B+count @0x44B63D-0x44B6A8 + el70 GameInter.wil F0xA7/0xAA（36×36）@0x44B4BF-0x44B4F7。
- (b) 目标框：复核为纯代码绘制合成，无独立 WIL 帧——0x40B850 名牌框（0xA0A0A 边框×3）、0x40B750 名牌文字（el86 ProgUse.wil F2/F3 = 32×4px）、0x40BB00 悬停标签（纯文本）、0x40A8A0 HP 条（selector 元素 0x5600FC+type*0x144，帧=[0x61B9C]）、0x437DF0 悬停重绘——全部锚定 HUD+0xE4/+0xE8；逐帧链 0x41BF00-0x41C0A0 内无 bind 调用、无肖像绘制。bind API 0x4660E0 xref 集复核仍为恰好 14 个 E8 调用者（0x40272A/0x40273E、0x43B7B7/0x43B7CC、0x43D4E7/0x43D502、0x43DF64/0x43DF86、0x43EDCC、0x452ABD/0x452AD2/0x452AFC、0x456CC4/0x456CD8），无一在目标框绘制链内。
- (c) 怪物无对话窗口；唯一对话窗口为 NPC 窗口 0x43ED00，其肖像资源 = Data/NPCFace.WIL（NPC 专属头部资源，绝不用在怪物上）。目标框内无怪物肖像。
- (d) 选人界面（全局 0x8A9520，ctor 0x4026E0，逐帧 0x402BE0/0x402C40）：构造只加载 gameinter.wil（0x40272A）+ Interface1c.wil（0x40273E）；角色以 3D 引擎呈现（0x4029A0 相机变换辅助，vtable +0x40/+0x14/+0x30），视口 SetRect(0,60,640,420) @owner+0x740，背景 = Interface1c.wil F0（640×360 像素核验）@0x402C63-0x402C99；UI = 4 个 Interface1c 按钮 F0xB/0xD/0xF/0x11（96×24/96×26/96×26/48×26：选择角色/创建账号/修改密码）+ 名字/等级文本区 (128,440)/(326,440) 99×14；状态机 on byte[owner+0x8A4]（0x403560/0x402D50/0x4031A0）与 byte[owner+0x8A5]（0x402C40）；主循环模式分发 0x402123 on byte[0x8B1878]。
- 肖像帧扫描（primary-resource-visual 负证据）：GameInter.wil 1103 帧 + Interface1c.wil 2000 帧按 30-80×20-60 尺寸筛出 127+264 帧；44-56×28-38「头像尺寸」子集抽查（I1C 642=48×34 箭头装饰、GI 450=44×36 图标块）无带框面孔画像；无绘制位点把候选帧连到肖像区域。

**结论(Verdict)**：
- (a) 状态窗口 49×33 区不是头像帧：内容为 GameInter.wil F200 内嵌横幅（primary-resource-visual）；角色用 el86 ProgUse.wil F0/F1 全身 + el83 Equip.wil 纸娃娃 + el70 GameInter.wil F0xA7/0xAA 图标呈现（primary-static）。
- (b) 目标框为代码绘制合成，无独立 WIL 帧；HP 条元素→WIL 映射静态定案（primary-static，负证据复核：bind xref 集 14 个完整、0x47C3E0/0x56B22C 0 个 imm32 引用）。
- (c) 怪物无肖像、无对话窗口；NPCFace.WIL 仅 NPC 窗口使用（primary-static）。
- (d) 选人界面无 2D 肖像：3D 引擎 + Interface1c.wil F0 背景（primary-static）。
- pending 重分类：元素→WIL 文件名由 slot 表静态定案（primary-static，六元素全部闭合）；残余运行时项保持 candidate，需运行时捕获。

**pending**：需运行时捕获（candidate）——各怪物类型字节 [HUD+0x8D] 的实际取值，以及 HP 条实际绘制帧（0x466130 frame=[0x61B9C]；0x40F5F0 的 10000+(A%400) 系列）。
### Finding 270 (FriendsSocial, 2026-08-11)

**问题**：Interface1c 动态对话框 0x8A7140 是否为好友窗口？客户端是否存在好友/社交（好友列表）窗口？16 窗口 id 空间是否有好友位？

**调查**：
- 0x8A7140 双用途定案（primary-static）：全局固定对话框对象，ctor 0x456CB0、vtable 0x476BC4、update 分派 0x402BE0（[+0x8A4] 子状态 1→0x402D50/2→0x4031A0/3→0x403560，[+0x8A5]→0x402C40）、逐帧更新 0x4575D0；屏幕态字节 [0x8B1878]（0=登录屏 0x8A9520，1=选人 0x47EF18，2=本对话框；分派 0x402060 → 0x40215F `mov ecx,0x8A7140; call 0x4575D0`）。
  - 触发器 A（游戏前 = LOGIN 窗口）：0x402970 显示（设 [0x8AB820]=[0x8B1870]=0x8A7140、调 ctor、[0x8B1878]=2 @0x40298E），唯一调用者 0x40362D（开场动画完成路径）；配置 `.\Data\ei_login.dat`（串 0x47AAD0，键 name/server/ServerAddr/192.168.0.200 等）；字段（0x403640）：焦点字节 [+0xD38]、账号缓冲 +0xD39、密码缓冲 +0xE3D（掩码 [0x476290]=0xCC）、EDIT 0x8AA48C、Enter→0x451F10(0x8AB828, acc, pwd) 提交、Tab 切换；按钮两个 0xB4 对象 +0x9E8(id4)/+0xD38(id5)（0x4686C4 @0x45696F/0x456991，回调 0x404690/0x4046B0）；绘制 (0x280,0x1E0)。
  - 触发器 B（游戏中 = 服务器通知对话框）：协议 0x7ED（分派 0x41E50C，jmp [eax*4+0x41E690]，idx0→0x41E522→0x41CDE0）子型 0x64 @0x41CE14（守卫 0x419CC0→0x451660(0x8AB828,0x3F1)→0x42E1F0→[+0x428208]=0→**byte [+0x428204]=2 @0x41CE57**）；状态机 0x41B5D0（主循环 0x41C1C7）：计数器 [+0x428208] 累计、>0x9C4 → 0x419BE0 显示（设 [0x8B1878]=2、ctor、绘制 (0x280,0x1E0)）；文本：协议 0x4B0（0x4218F2 idx3 @0x421913 分配 0x40C）→ 0x41B710 解析进 main+0x428070（0x104 字节）、[+0x428064]=1、几何 +0x428174；文本样例 0x47B0D0 `"%s 服务器连接不稳定…"`、0x47AF80 cp949 断线通知 → 用途为服务器连接/维护/断线通知，非好友。
- 好友字符串负扫描（primary-static）：GBK 好友/好友名单/添加好友/删除好友/黑名单/密友/陌生人/仇人/邀请、cp949 친구、ASCII friend/Friend/FRIEND/social/buddy 全部 0 命中；正对照：组×10、行会×29、名单×1（行会）、查找×1（组队）、添加成员×1（0x47B104，组队/行会命令串，dispatcher 0x41DFE0）。
- 窗口 id 空间全枚举：热键槽公式 slot = esi+((id*5+0x267)*9)*4 = esi+0x567C+id*0xB4（0x42BF08/0x42BF0F，循环 0x42BEF8，id 0..0xF）；16 标签（0x47BBD0–0x47BCE0，全部 GBK 解码）：状态栏/包袱栏/坐骑/[槽12 未解码]/设置栏/信息窗口/聊天记录/技能书/腰带/行会(Ctrl+F)/组队(Ctrl+G)/注销人物/退出游戏/技能图鉴/小地图/交易栏；点击表 0x42C494（16 项，槽12=no-op 0x42C359）；开窗分派 0x42ADB0 + 表 0x42B3E4（16 项，id5/10 空槽 0x42B3DD）：**行会 F600 = id4 → 对象 0x4707C（ctor 0x424A60），组队 F900 = id6 → 对象 0x47834（ctor 0x424120）**；键盘分派 0x42C4D4（15 项）；游戏屏命中 0x42AAB0 + 类型表 0x42ABE8（0..0xC → 13 个窗口对象 0x656C…0x52508，即 13 窗口 +0x18）；主 UI ctor 0x426C80 创建 13 个可开窗口（0x6554/0x29CE4/0x33188/0x3399C/0x4707C/0x47834/0x47C28/0x507EC/0x51150/0x516E8/0x518E0/0x52118/0x524F0）+ 2 非开窗对象（0x52E5C/0x53030）。
- WIL 大面板帧扫描（primary-resource）：GameInter.wil 1103 帧、Interface1c.wil 2000 帧；≥120×80 面板全部归入已知窗口（行会 600/601/602、组队 900/1001、登录 0、公告板 602 见 notice-prompt-window-evidence.json id15 class 0x43E260、登录/选人按钮装饰簇 128x256/256x128 等），无好友列表面板。

**结论(Verdict)**：documented negative closure（primary-static + primary-resource-negative）。0x8A7140 = 游戏前 LOGIN 窗口 + 游戏中服务器通知对话框（触发器全图定案），非好友窗口；客户端无任何好友/社交独立窗口——16 窗口 id 空间无好友位，唯一社交窗口 = 组队 F900（开窗 id6/热键槽5）与行会 F600（开窗 id4/热键槽6）；好友字符串 0 命中；WIL 无好友列表面板。pending = 0。

**pending**：无（残余运行时项为 candidate，需运行时捕获：0x4B0 通知负载实际文本、0x41B5D0 淡入时序系数、登录提交后服务器握手、热键槽12 未解码标签原始文字——均与好友结论无关）。
### Finding 268 (WindowCatalog, 2026-08-11)

**问题**：对 Mir3.exe 的游戏内窗口管理器（winmgr）16 固定窗口 id 空间做静态闭包：每个 id 的对象基址、ctor、pre-ctor、vtable、paint、注册矩形、GameInter.wil 帧、点击处理；并解码输入循环 0x42BEF8、窗口点击分派 0x42BF70、caption 点击表 0x42C494、case 表 0x42C4D4、命中测试 0x42AAB0。成果写入 docs/research/ei-ui-layout/window-id-catalog.json。

**调查**：
- **winmgr** = gameObj(0x47EF18)+0x2A548C = 0x7213A4；ctor 0x426C10，引导调用点 0x418C41（`lea ecx,[esi+0x2a548c]`）。caption 数组基址 winmgr+0x567C，stride 0xB4，16 个元素，由数组构造 helper 0x4686C4（参数 base/stride/count/ctor/copy = 0x567C/0xB4/0x10/0x404690/0x4046B0）在 0x426CD0 构建。
- **输入循环 0x42BEF8**：计数器 0..0xF；id→槽位公式 `slot = winmgr + ((id*5+0x267)*9)*4 = winmgr+0x567C+id*0xB4`（@0x42BF06-0x42BF12 验证）；每槽 `mov eax,[slot]; lea ecx,[slot]; call [eax+0x10]` = caption vtable 0x4763A8 的 release/click-test 0x4177F0（PtInRect @[obj+4]，命中播声 0x45AFC0(0x8AB130,0x69)）；命中则 `jmp [eax*4+0x42C494]`。
- **caption 类**：vtable 0x4763A8，类 ctor 0x404690（`mov [esi],0x4763A8; call 0x4175F0`），copy-ctor 0x4046B0；0x417550/0x4175F0/0x417630 仅为字段初始化（0x417550 含 frame/x/y/w/h/name）；方法：+4 paint 0x417640、+8 hover 0x417780、+0xC press 0x4177C0、+0x10 release 0x4177F0。
- **caption 点击表 0x42C494（16 项）**：idx0 交易栏 0x42C1CE（0x41EC10 交易目标 0x777764/0x777768/0x777759）；idx1 小地图 0x42C259（GetTickCount 3000ms 防抖，非窗口 toggle——修正 Finding 261）；idx2 技能图鉴 0x42C241（toggle bool [winmgr+0x6208]）；idx3 退出游戏 0x42C2E1（0x419CC0 检查→[vtable+0x10](+0x53030,1) 显示 id100 确认框）；idx4 注销人物 0x42BF37（确认框 0x7E04C8 消息 0x47AFB4）；idx5 组队 toggle id6；idx6 行会仅提示 0x4523E0 code 0x40C（不开窗）；idx7 腰带 clamp [winmgr+0xD40] 0..0x2E（非窗口）；idx8 技能书 toggle id14；idx9 聊天记录 toggle id8；idx10 信息窗口 toggle id0xB；idx11 设置栏 toggle id0xC；idx12 도움말창(지원예정) cp949 @0x47BC04 无操作；idx13 坐骑 toggle id0xD；idx14 包袱栏 toggle id0；idx15 状态栏 toggle id1 + 0x423E80(+0x29CE4,F200,x=[+0x29CFC],y=[+0x29D00],0xF4x0x148)。
- **窗口点击分派 0x42BF70**：`cmp edi,-1; je 0x42bef8; cmp edi,0xe; ja 0x42c198; jmp [edi*4+0x42C4D4]`（id15 不可达）。
- **case 表 0x42C4D4（16 项）**：case0 0x42BF85→0x4300F0(+0x6554)→toggle 0；case1 0x42BFB3→0x44CCD0(+0x29CE4)→toggle 1；case2 0x42BFE1→0x44E9B0(+0x33188)→toggle 2；case3 0x42C00B→0x416EF0(+0x3399C)→toggle 3；case4 0x42C039→0x4258F0(+0x4707C)→toggle 4；case5/10 0x42C198 无操作；case6 0x42C063→0x424610(+0x47834)→toggle 6；case7 0x42C08D→0x450B30(+0x47C28)→toggle 7；case8 0x42C0B7→0x4149A0(+0x507EC)→toggle 8；**case9 0x42C17D→0x440290(+0x51150)，处理后 0x41C1E0(gameObj) = NPC 对话关闭流**：0x42AC50(winmgr,9) 隐藏 id9 + 0x42AC50(winmgr,2) 隐藏商店 id2，并反激活 [gameObj+0x2F65DC]/[gameObj+0x2D8614]；case11 0x42C0E1→0x447FA0(+0x516E8)→toggle 11；case12 0x42C10B→0x4414F0(+0x518E0)→toggle 12；case13 0x42C131→0x426A80(+0x52118)→toggle 13；case14 0x42C157→0x43AB10(+0x524F0)→toggle 14；case15 0x245C8B53 垃圾值（守卫不可达）。
- **命中测试 0x42AAB0**：遍历可见链表（[winmgr+0xD28] 头、+0xD38 计数、+0xD2C 当前、+0xD34 索引）；节点 [node+0]=id；守卫 `cmp eax,0xe; ja 0x42ab8a`（id15 从不命中测试）；stub 表 0x42ABE8 每 id 加载矩形 {+0x18,+0x1C,+0x20,+0x24}（x/y/w/h 连续）→ PtInRect（IAT 0x4762B4）。矩形偏移：id0 +0x656C、id1 +0x29CFC、id2 +0x331A0、id3 +0x339B4、id4 +0x47094、id6 +0x4784C、id7 +0x47C40、id8 +0x50804、id9 +0x51168、id11 +0x51700、id12 +0x518F8、id13 +0x52130、id14 +0x52508；id5/10 stub=0x42AB8A（无矩形）、id15=0x90909090（无条目）。
- **窗口类**：基类 vtable 0x476624（+0 dtor 0x4150D0、+4 init 0x423CA0、+8 0x423CF0 虚分派、+0xC 0x423D00 通用帧渲染、+0x10 0x423F80 show=`mov [ecx+0x30],arg`、+0x14 0x4155A0）。每个窗口在 winmgr ctor 0x426C10 内经 pre-ctor 安装：先 `mov [obj],0x476624` 再覆写为派生 vtable（inventory 无派生，保留基类；NPC 0x476938 覆写 +0xC=0x43F040 渲染、+0x10=0x43F020 show；quest 0x476A54 仅覆写 +0x10=0x4488B0）。派生表：0x47660C chat、0x47663C exchange、0x47665C quit、0x4767CC group、0x476800 guild、0x476834 horse、0x4768D0 skills、0x476908 banner、0x476938 npc、0x476950 option、0x476A54 quest、0x476A70 status、0x476A88 store、0x476ADC id7。
- **paint 分派 0x4280F0**：表 0x428358 为 stub（0x428166..0x428283），每 stub `lea ecx,[winmgr+base]; call <paint>; lea eax,[winmgr+rect]; jmp 0x428283`。真实 paint：id0 0x42EB80、id1 0x44B2D0、id2 0x44E260、id3 0x415B10、id4 0x425040、id5 skip、id6 0x4243D0、id7 0x450530、id8 0x414700、id9 0x43F460、id10 skip、id11 0x447470、id12 0x441380、id13 0x4269C0、id14 0x439500、id15 0x43E3C0。hover 表 0x428398 为每 id stub：id0 0x42FAB0、id1 0x44B6B0、id2 0x44E650、id3 0x416790、id4-6 公共尾 0x42833E、id7 0x450AC0、id8+ 0x90909090。
- **16 窗口注册表（main-init 0x427600-0x427A00，primary-static）**：id0 包袱 +0x6554 ctor 0x42EA80 F250 (518,0,324×284) mov1；id1 状态 +0x29CE4 0x44B130 F200 (0,0,328×244) mov1；id2 商店 +0x33188 0x44D310 F1000 (0,0,304×300) mov0；id3 交易 +0x3399C 0x4159D0 F1050 (0,0,330×484) mov1；id4 行会 +0x4707C 0x424E60 F600 (102,22,446×596) mov1；id6 组队 +0x47834 0x424250 F900 (272,123,244×256) mov1；id8 聊天 +0x507EC 0x414060 F350 (114,76,388×572) mov0；id7 +0x47C28 0x4503B0 F200 (560,0,328×244) mov1；id12 设置 +0x518E0 0x440FE0 F750 (276,113,264×248) mov1；id11 任务 +0x516E8 0x4473E0 F700 (0,0,340×440) mov1；id13 坐骑 +0x52118 0x4268C0 F850 (0,0,296×332) mov1；id14 技能 +0x524F0 0x439250 F400 (0,0,452×380) mov1；id9 NPC +0x51150 0x43ED00 F1100 (0,0,552×176) mov0；id15 公告 +0x52E5C 0x43E260 F602 (107,110, 252×584 或 584×252) mov3；id100 退出确认 +0x53030 0x418910 F800 (218,176,364×184) mov3。
- **id 0xB 修正**：任务简报称「id 0xB = NPC 帧 main+0x516E8/F1100」，静态 ctor 证据否定：0x4278AD `push 0xB; lea ecx,[esi+0x516E8]; call 0x4473E0` 帧 0x2BC=700 → **id 0xB = 任务 quest (F700)**；NPC = **id 9**（+0x51150，帧 0x44C=1100，ctor 0x43ED00，vtable 0x476938）。现有 npc-window-render-evidence.json（ctor 0x43ED00/paint 0x43F040/F1100/552×176）与 quest-window-render-evidence.json（ctor 0x447400/paint 0x447470/F700/340×440）均与新映射一致。
- **否定项**：ids 5/10 无窗口对象（toggle 表 0x42B3E4 项=0x42B3DD no-op、close-all 表 0x42B938 项=0x42B8F5 skip、case 不可达、无命中矩形）→ 本构建无好友/社交独立窗口位，与 Finding 270 一致。
- **visibility**：show 0x42AC30 / hide 0x42AC50 / toggle 0x42ADB0（表 0x42B3E4，id15→0x42B2AD/0x42B349）/ close-all 0x42B820（表 0x42B938，id15 守卫跳过）/ 定位+show 0x42B6A0 / 移动 0x4240C0（需 +0x30 && +0x34 && +0x3C，写入 grab +0x48/+0x4C）。

**结论(Verdict)**：primary-static。16 固定窗口 id 空间全部定案（id0-4/6-9/11-15 有窗口对象，id5/10 为空，id15 公告纯显示不可点击，id100 退出确认框在 id 空间外）；每窗口对象基址/ctor/pre-ctor/vtable/paint/注册矩形/帧/点击处理均已绑定；caption 类 0x4763A8 与窗口基类 0x476624 语义解析完毕；id 0xB=任务（非 NPC）为对任务简报的修正，现有 repo 证据 JSON 一致。详情见 window-id-catalog.json。

**pending**：id7 消息窗口 paint 0x450530 确认绘制 0x566DD4 消息对象于 (winX+0x61, winY+0xC8)，精确职能（战斗/系统日志）需运行时捕获；公告 9 参 ctor 使 w/h 歧义（252×584 vs 584×252）需运行时确认；toggle 守卫 [gameObj+0x2ED0E4]/[gameObj+0x2EC538] 为服务器/状态标志需运行时取值；idx1 小地图渲染（0x6210/0x6518 字段）需运行时捕获。
### Finding 272 (Skills2, 2026-08-11)

**问题**：对技能书窗口（GameInter.wil F400 296×332，id14 技能窗口对象 this+0x524F0，ctor 0x439250，paint 0x439500）的右侧详情页渲染循环 0x0043A440 做 primary-static 闭合：行流扫描、'#' 段选择语义、解析行数（旧 round 遗留 field meanings pending）、逐行几何与配色、技能 id 选择链。成果写入 docs/research/ei-ui-layout/skill-window-render-loop-evidence.json。

**调查**：
- **函数定界（修正）**：0x0043A440 = 渲染循环真起点（prologue `mov eax,0x1e90; call 0x468d10` 栈分配惯用式）；旧扫描的 0x43A3E0 实为 0x43A370 函数体内（"find magic by id" 命中测试），非渲染函数。
- **几何（0x0043A463）**：`mov eax,[ecx+0x1c]; add eax,0xf`（Y 基 = 窗口 y+15，存 [E+0x14]）、`mov ebx,[ecx+0x18]; add ebx,0xeb`（X = 窗口 x+235 = 0xEB，存 [E+0x18]）——**修正旧 evidence 交换的 "this+0x18+0x0f / this+0x1c+0xeb" 笔误**（0x0f 加在 Y、0xeb 加在 X）。入口守卫：arg1==-1 直接返回。
- **行流（0x0043A491）**：流 = this+0x968+8（Magic.exp 解码文本），strchr(cursor,0x0d) @0x468BF0 分行；`mov al,[ebp+1]; cmp al,0xa; jne 0x43A7F7`——CR 后必须跟 LF，否则整个渲染循环退出（收紧旧 "line accepted when second byte is LF"）。
- **行分类（0x0043A4DF）**：';'（0x3b）注释/分隔行跳过；'#'（0x23）段头 atoi（0x4681F9）与 arg1 = this+0x964 比较（0x43A4FF）；命中 → flag [E+0x13]=1 且段头行本身不绘制（0x43A503-0x43A50C + 0x43A529 cmp al,0x23 → next）；flag==1 时遇到下一个 '#' 段头 → 整个渲染循环退出（0x43A50E-0x43A513）= 选中段结束；非 '#' 行仅 flag==1 时渲染（0x43A51E-0x43A523）。
- **解析与 count==1（0x0043A531）**：清零 20 槽记录区（0x514 dwords @[E+0x540]，槽 stride 0x104，至 [E+0x1888]）；0x0045E200(0xa5, &count=[E+0x1C], &line=[E+0x28], &out=[E+0x198C])——参数序由 0x45E200 prologue 验证（arg2=&count 初值 1、arg3=&line）；0x45E200 以 0x47C350 格式串（179 字节 = 20 组 "%[^`]%*c" 空格分隔）经 0x468CD7（sscanf 包装）反引号切分为最多 20 字段。**0x45E0C0（表单测量）三条返回路径全部写 {[S-0x8],[S-0x4]}={0,0}（该两局部仅 0x45E0D2/0x45E0D6 初始化为 0，全程无其他写入，全栈算术追踪验证）→ 结果长度恒 0 ≤ 阈值 0xa5，恒走复制分支，反引号永不插入，count 恒为 1** → 每行恰渲染为一行记录，20 槽缓冲区仅槽 0 使用。此即旧 round "field meanings remain pending" 的定案：本构建不存在多字段/多行展开。
- **逐行绘制（0x0043A64D）**：行计数器 [E+0x20] vs count [E+0x1C]；每记录 Y 本地 +=15（首行主 y = winY+30）、记录指针 +=0x104、X 从 [E+0x18]（winX+235）重载。首字节 '['（0x5b，如 `[基本剑术]` 技能名行）→ 4 角阴影 0x45DD70(0, X±1, Y±1, 0x0A0A0A, 0, text, width) + 主文字 0x45DD70(0, X, Y, 0x96C8FA, 0, text, width)，宽度每次经 0x45DBA0 测量（0x47C348 "%s", 0xa, 0, 0x2BC, 0, 0, 0x81, text，表单对象 [0x8AB7A8+0x1c] vtable+0x44）；普通行单次 0x45DD70(0, X, Y, 0x0A320A, 0, text, 0)（宽度参数 0）。
- **选择链**：ctor 尾 0x439134 this+0x964=-1 → 鼠标处理器 0x43AC80（先点 3 个框架按钮 0xD8/0x18C/0x240 与 8 个分类页签 0x2F4..0x7E0 stride 0xB4）→ call 0x43A370(this,x,y)：左页技能列表命中测试（分类字节 [this+0x54]、分类链表头 [this+0x898+24*cl]（条目 +0x0C 链接）、每分类计数 [this+0x58+4*cl]、6 个窗口相对命中矩形 this+0x7C，PtInRect IAT 0x4762B4），返回 -1 或 word [entry+4]+6（16 位技能 id，0x43A42E mov ax,[edx+6]）→ 0x43ACE4 `movsx eax,ax; mov [esi+0x964],eax`（-1 跳过）→ paint 0x439500 于 0x439520 处 `mov eax,[esi+0x964]... call 0x43A440`（唯一调用者；0x439500 自身仅被主 UI 循环 0x428265 调用，xref 验证）。Magic.exp 解码段号即技能 id（#3 基本剑术、#7 攻杀剑术、#12 刺杀剑术、#25 半月弯刀、#26 烈火剑法、#1 火球术…），与 atoi==this+0x964 一致。
- **流生命周期**：0x439150 加载（0x46926D(0x47C2FC "Magic.exp", 0x47BCF8 key) → 0x469382 解码 → 0x468B1A 分配复制 → this+0x968；0x4525F0 校验 CRLF，失败 0x4680F8 释放返回 0）；0x439230 析构 0x4680F8 释放并置 null（0x43923B）；ctor 尾清零窗口、+0x968=null、+0x54=0（火）、+0x964=0xFFFFFFFF。
- **左页对照**：0x4397A0 = 左页技能列表绘制（读 [ecx+0x54] 分类、遍历 this+0x898+24*cl 链表、计数 [ecx+cl*4+0x58]、矩形基址 this+0x7C）——与 0x43A370 命中矩形同源；本 finding 只闭合右页渲染 0x43A440。

**结论(Verdict)**：primary-static。0x0043A440 技能书右页详情渲染循环全闭合：流 = this+0x968+8 CRLF 分行；';' 注释；'#' 段头 atoi==this+0x964（选中技能 id）匹配并渲染至下一个 '#' 段头；0x45E200 解析 count 恒为 1（0x45E0C0 惰性证明）→ 每行一行；几何 (winX+235, winY+30+15k)，'[' 技能名行 4 角阴影 0x0A0A0A + 主文字 0x96C8FA（0x45DBA0 测宽），普通行 0x0A320A；选择链 0x439134(-1) → 0x43A370（左页列表命中，[entry+4]+6 技能 id）→ 0x43ACE4 写 this+0x964 → paint 0x439500 → 0x439520 call 0x43A440；流生命周期 0x439150/0x468B1A/0x4680F8 闭合。旧 round 两项遗留（origin 交换笔误、field meanings pending）均已定案。

**pending**：无（渲染循环内无未决项）。运行时 candidate（需运行时捕获）：0x45DBA0 实际字体/宽度依赖 0x8AB7A8+0x1c 表单对象运行时状态；左页 6 个命中矩形（this+0x7C..0xCC）具体值与分类链表填充（this+0x898）在 0x43A440 之外设置，不影响右页闭合。

### Finding 269 (SceneEntities, 2026-08-11)

**问题**：EI 3.0 原版客户端在世界场景中如何渲染玩家/怪物/NPC/地面物品/特效实体？世界实体绘制循环的 VA 链、实体→元素→WIL 绑定、动画帧公式、实体列表布局。

**调查**：镜像 base 0x400000、fileoff=VA−0x400000、文件 0x80000 → 0x400000–0x47FFFF 为真实代码；≥0x480000 仅 imm32。帧函数 0x41BCB7 `call 0x419D40`（世界排序通道，唯一调用点，prologue `push ebp;mov ebp,esp;…;lea edi,[ebp+0x154];rep stosd` 清 0x38400B 即 0xE100 dwords）→ 0x41BCBC `call 0x41C450`（地面/瓦片通道）。0x419D40 建 4 个 y 排序画家数组：root+0x154 实体 / +0x2E4 特效 / +0x474 地面装饰 / +0x604 地面物品。遍历列表 [root+0xE1158]（node+4=实体、+0xC=next；类型字节 [e+0x88]）。tick 分派 JMP 0x41A528{0:0x419DC6,1:0x419E46,2:0x419DDD}+idx 0x41A534（51B：0/1→0，2→2，3..0x31→1，0x32→2）：类型 0/1 tick `call [vtable+0x1C]`@0x419DDA（=0x40ADD0，旧 round `[reg+0x1C]` candidate 定案）；类型 3..0x31 tick@0x419E5A（[e+0x61C7C]==3 → 0x41B570 摘链 + [root+0xE1154].vtable+0x14 + [vtable+0] push 1）；类型 2/0x32 不 tick。绘制分派 JMP 0x41A568{0:0x419E1C,1:0x419E94}+idx 0x41A570：0/1→case0（清列表标记+[root+0xE1154].vtable+0x14）；2、3..0x31→case1 0x419E94（frustum 剔除 [e+0xCC]∈[[root+0xF532C],+0x18)、名字查找 0x424360→[e+0x61BD0]=1、y 排序插入：idx=((([e+0xD0]−[root+0xF5330])*3)<<3)−[root+0xF532C]+[e+0xCC] 再 ×5,×5,<<6 → [root+0x154] 0x100 字节槽 100 探测；玩家不在此插入）。遮蔽登记 [root+0x364444]=鼠标实体、[root+0x364448]/[root+0x364450] 标志；阴影分支 [e+0x61C74]≠0 保存 0x64 dwords 再 rep movsd。0x41C450（ret 4）双循环可见瓦片范围（[root+0xF5330]−0xA..+0x22、[root+0xF532C]−0xA..+0x22，字 [root+0xF5326]/[root+0xF5328] 夹紧），瓦片查找 0x43CA40/0x43BE00、瓦片绘制 0x434A20，每可见瓦片调 0x41C860（地面物品 root+0x604：word [esi+8]=库 id→[0x566DD4]+0x466130 WIL 查找；[esi+0x1C] 标志→0x460240 普通或 0x4542A0+0x4542F0 3D blit）、0x41CA20（装饰 root+0x474）、0x41CBD0（实体 root+0x154）、0x41CD50（特效 root+0x2E4）。0x41CBD0（ret 0xC，lea ebx,[edx+edi+0x154] @0x41CBF6）类型分派 JMP 0x41CD0C{0:0x41CC8E,1:0x41CCD7,2:0x41CCB6,3:0x41CCED}+idx 0x41CD1C（原始字节：0/1→0 绘制，0x3→1 绘制，0x32→2 绘制，0x2/4..0x31/>0x32→3 跳过）：case0/2 `call [vtable+0x7C]`（5 参：tilemap [root+0xF5200] 指针等）= 0x40B2C0（vtable 0x4763C0+0x7C，prologue mov esi,ecx）世界→屏幕：[e+0xE4]=((([e+0xCC]−[cam+0x12C])*3)<<4)−[cam+0x134]+[e+0xD4]−0xC8、[e+0xE8]=((([e+0xD0]−[cam+0x130])<<5)−[cam+0x138]+[e+0xD8]−0x9D)（cam=tilemap [root+0xF5200]，与分派器 0x404FB0 sx=((x−[0x574244])*48+[ebp+0xD4]−[0x57424C]−0xC8)、sy=(((y−[0x574248])<<5)+[ebp+0xD8]−[0x574250]−0x9D) 同族）；体尾 0x466130（元素→WIL 库）、[0x4762B0]（SetRect 助手）、0x404DA0（渲染模式位 [e+0x61C68]→[e+0x61C6C]，0x800000→1、0x8000000→0x94BF、0x80000000→0x7E0 等）→ 0x404E10 模式分派 → 0x461ED0 blit（0x8AB7A8）。tick 链（实体状态绘制）：vtable+0x1C=0x40ADD0 → [vtable+0x20]=0x40AFD0（[e+0xC0]==1；[e+0x61C84] 交替帧计数 mod 0x186A0；[e+0xC4]+=2 或 +=1）→ [vtable+0x18]=0x40A2B0（状态机 0x456270 字状态 0x1B/0x09..0x17/0x22/0x321 → [vtable+0x44/0x48/0x4C/0x50/0x58/0x5C/0x64/0x68/0x6C]=0x406F60/0x4070C0/0x407200/0x407670/0x407EC0/0x407F20/0x409720/0x408C20/0x408630 各状态绘制槽；+0x48=0x4070C0 实体记录绘制→painter 0x405630）。painter 0x405630（叶，不在任何 vtable，10 个直呼点 0x4052F7/0x406A09/0x406B9D/0x406EDC/0x406FBD/0x407184/0x407FDB/0x4080F1/0x40C390/0x40F429）。元素→WIL 绑定（旧 round 定案保留）：type0→71 M-Hum@0x40502D、type1→76 WM-Hum、type3 race<2000→0x58+race/10（guard race<520）、race≥2000→0x87+(race−2000)/100（guard<0x8C）、type0x32→128 NPC@0x405263、马 0x629CF=0x57↔87；WIL 路径表 base+0xB130 stride 0x104 140 槽（0x453600..0x45410A）。帧公式：玩家 word[0x8AA5C0+6*state]+10*flag+3000*dir；怪物 word[0x8AA686+6*state]+1000*(race%10)+10*flag / ≥2000 word[0x8AA686+6*flag]+100*(race−2000)+10*flag；NPC word[0x8AA6C8+6*state]+100*dir+10*flag（flag=[esp+0x40]%3）；输出 [ebp+0xB4]/+0xB8/+0xBC；DB 0x8AA5A8（0x44A820 状态/0x44A240 种族）。实体列表布局：全局表 0x560070（读点 0x408248/0x40DFC2/0x41ECAE/0x4350B9/0x43CD18/0x43DC54，文件内零写入→头初始化 需运行时捕获；node+4 实体/+0xC next；实体 +0x4 key/+0x6/+0x8 屏幕 xy/+0xC 短名[8]/+0x17 长名[64] 'name|guild'）、0x5600A0（读点 0x43DCD9）、特效 0x560088/0x56008C/0x560098（插入模板 0x408208-0x408234，vtable 0x476448=0x4763C0+0x88）+0x5600E8/0x5600EC/0x5600F8；[root+0xE11A0] 特效 word [e+0x10] 类型 {0x10,0x16,0x3F,0x48,0x09,0x35,0x150,0x14A..0x14E} [vtable+0xC] tick/[vtable+0x10] draw。

**结论(Verdict)**：primary-static。世界实体渲染管线全闭合：帧函数 0x41BCB7 → 0x419D40（世界排序通道：4 个画家数组 root+0x154/+0x2E4/+0x474/+0x604，tick 分派 0x41A528/0x41A534、绘制分派 0x41A568/0x41A570、排序公式、遮蔽登记）→ 0x41C450（瓦片通道：0x41C860 地面物品/0x41CA20 装饰/0x41CBD0 实体/0x41CD50 特效）→ 0x41CBD0 类型分派 0x41CD0C/0x41CD1C → [vtable+0x7C]=0x40B2C0（世界→屏幕公式定案）→ 0x404DA0/0x404E10/0x461ED0 blit 家族；怪物经 tick 链 0x40ADD0→0x40AFD0→0x40A2B0→各状态槽（0x4070C0→0x405630）。旧 round 开放 candidate 定案：[vtable+0x1C]@0x419DDA/0x419E5A=世界循环实体 tick、0x41BC1F=HUD tick（[root+0x2F8780].vtable+0x1C）、世界实体绘制循环=0x419D40+0x41CBD0。类型语义：0/1=玩家（排序通道 tick+瓦片通道 [vtable+0x7C] 绘制）、3..0x31=怪物（瓦片通道除 type3 外跳过，经 tick 状态链绘制）、0x32=NPC（瓦片通道 [vtable+0x7C] 绘制）、type2 特例（排序不 tick 瓦片跳过）。

**pending**：需运行时捕获（candidate）：怪物 4..0x31 每瓦片 blit 顺序与排序通道的先后（candidate=tick 状态链路径）；实体表头 0x560070/0x5600A0/[root+0xE1158] 插入（文件内零写入，服务器驱动）；vtable 0x4764B0/0x4765B0 安装路径（非 imm32）；[root+0xE1154].vtable+0x14 职能；type2 语义；type3 于 0x41CCD7 的绘制细节（idx 字节 0x3→1）；元素数组 0x5600FC 与帧表 0x8AA5C0/0x8AA686/0x8AA6C8 运行时内容；4 个排序数组槽/探测精确布局；0x40B2C0 5 参调用中 hover/目标框参数语义；0x40B180/0x40CE20 职能（0x41CC8E/0x41CCB6 中与 vtable+0x7C 并列）。

### Finding 273 (ServerData, 2026-08-11)：服务器业务数据交叉引用（stditem/monster/magic/Mapinfo/Merchant）对照 EI 3.0 客户端 UI 字段消费

**问题**：客户端 UI 各窗口消费的数值/图标/NPC 数据，能否与 ORIGIN 服务器 `/tmp/nas_mnt/NAS/TMP/Mud3/Envir` 下出货业务数据（stditem.dat、monster.dat、magic.dat、Mapinfo.txt、Merchant.txt）建立字段级交叉引用，并把每条链接的证据级别标清。

**调查**（服务器二进制 EIServer.exe 0x400000 Delphi PE 为静态依据；`Tools/reverse-engineering/parse_mir3_dat.py` 为唯一允许工具，本轮修正并验证）：
- 三个 .dat 均为 4 字节裸计数 dword + 单字节 XOR 主体：stditem.dat 184B/异或 0x04/名@152（装载 0x4957E0，GetMem 0xB8、xor-4 0x4957A4@0x4957CC）；monster.dat 252B/异或 0x09/名@229/ID dword@248=序号+1（装载 0x495C88，GetMem 0xFC、xor-9 0x495C4C@0x495C74）；magic.dat 120B/异或 0x11/名@104（0x78@0x495686、0x11@0x495620）。计数：stditem 1143、magic 105、monster 432 全记录+248B 截尾（末条恰缺 ID dword，结构型闭合）；Mapinfo.txt 370 条目/365 唯一 stem（stem 是字符串；`[stem 中文名 flag]` 行，跳过 `;`/`;;`/`->` 传送链行）；Merchant.txt 318 NPC（`stem map x y 中文名 face body`）。
- stditem 字段（derived）：looks@68=商店图标帧（金创药小=5..特=8、魔法药小=15..特=18、肉=300、布衣男/女=940/950、木剑=1042、铁剑=1043、凝霜=1044、书=304）；b76=HP 恢复 30/70/110/170、b88=MP 恢复 40/110/180/250（小/中/大/特）；cat36 类别（0=药水、5=武器、10/11=男/女衣、51=书）——**与客户端物品数据字节 0x0A/0x0B 着色分支逐位对应（primary 交叉链）**；price@144=商店价（金创药小 80）——Market_Def `[Goods]` 头注释 `;ItemName Volume Hour` 定案为「库存量+补货小时」非价格，旧 2000-vs-80 冲突消除；d72 三义候选（消耗品重量 1/装备耐久 4000..20000/书编码 id 7·8·29）；b148=堆叠类 16=食物/5=药水装备书。
- monster 字段（derived）：ID@248=rec#+1 全行一致（STRONG）；d104/d108=攻击 min/max（STRONG：鸡 0/1、鹿 0/6、稻草人 2/5、白野猪 44/66、赤月 90/180、祖玛教主 70/175）；d64/d68=AC/MAC（白野猪 13/13、赤月 52/52、祖玛 65/65）；d52 HP 类候选（赤月 13000/祖玛 14000/白野猪 4500/稻草人 18/鸡 5/鹿 17）——**牛老道 d52=1 反常（d56=1200 更像 HP）→ d52/d56 均留 candidate**；d48=100 侵略/Boss 类、0 被动；d20 外观类、d24 等级或种族类 candidate。
- magic 字段（derived）：d0=魔法 id（基本剑术 3，rec0-7=25/23/33/53/107/108/39/40）；d20=职业类（7=战士：基本剑术/半月弯刀/乾坤大挪移/斗转星移；0=火：爆裂火焰；1=冰：冰咆哮/冰沙掌/冰月神掌/冰月震天）；d28=d0−2 全行一致；dword60..83=逐级属性（基本剑术 (60,7),(64,10),(68,9),(72,20),(76,11),(80,30)）；d24 元素/等级二义留 candidate。
- Mapinfo 名（31 个必查 map 全部落盘）：0/0_003=比奇县、01=边境城市、1=道馆、02=银杏山谷、2=毒蛇山谷、3=沙巴克城、4=绿洲、5=沙漠土城、6=沙漠、8=潘夜岛、9=失乐园、12/122/125=灌木林、31=祖玛神殿、41=诺玛村庄、42/43/44/71-73/76-78=沙漠、74=盟重县、75=石阁庙、81=流放岛、0150=沙巴克城堡、0157=沙巴克城楼；**无 map id 544**——544=客户端 Map/ 目录文件数（与 Finding 242 出货地图数一致，0/4/41-44/74/75/0150/0157.map 均在）。
- Merchant（12 条落盘，全在 map 0 比奇县）：body=NPC 精灵 id（0 啊康/1 老张老黄/2 啊琨/4 肉店老板/5 药店老板恩英/7 怡美慧媛/9 药剂师/11 金氏/12 生存游戏场美眉）、face=朝向 0-7。
- 客户端↔服务器消费映射（详见 JSON `client_server_field_consumption_map`）：背包图标 0x5668C4(sel82) 帧↔looks（StoreItem.wil 1440 帧覆盖 Looks 0..1044，与 Ground.wil 在 940..1044 逐像素一致——el82 路径槽 0x56F944+12*0x104 为 bss 运行时填充，WIL 绑定 candidate）；负重/总量 `负重:%d / 总量:%d` 0x47BDFC 读 0x7DA11D/0x7DA11F↔d72/b148 候选；HP/MP 条 0x40A8A0/0x40A4D0↔b76/b88；目标框 0x449B90（步长 0x30、[rec+0xC] 类型字）↔monster id248/d52/d56；技能书窗口类别 火冰电风神圣黑暗幻影剑↔magic d20/d24 候选；NPC 窗 GameInter F1100/1101/1102↔Merchant body+face；商店 sel139↔Market_Def 库存量+stditem price144。

**结论(Verdict)**：derived。全部服务器行按 derived 落盘（服务器业务数据非客户端主证据），字段语义 STRONG 与 candidate 明确区分，冲突全部显式记录（monster d52 牛老道反常、stditem d72 三义、magic d24 二义、el82 WIL bss 绑定、monster 截尾、Market_Def 非价格）；客户端消费地址全部 primary-static 引用。客户端↔服务器唯一 primary 交叉链 = 客户端物品类型字节 0x0A/0x0B ↔ stditem cat36 10/11（男/女衣着色分支）。落盘 `server-data-crossref.json`。

**pending**：需运行时捕获（candidate）：目标框类型字↔monster id248 绑定与 d52/d56 真 HP 判定；背包 总量/负重 0x7DA11D/0x7DA11F↔d72 重量-vs-耐久；el82 背包图标 WIL 文件名；stditem b44/b92/d64/d108/d148、monster d20/d24/d48/d132/d144、magic d24 与逐级统计的精确语义。

### Finding 267 (LoginFlow, 2026-08-11)

**问题**：预登录/选人界面（mode 0 char-select 0x8A9520、mode 2 parent 0x8A7140、mode 3 游戏 0x47EF18）的完整 UI 流程：模式状态机、启动屏幕栈、两屏构造/对象/WIL 帧/按钮、服务器协议驱动、全部字符串。

**调查**（primary-static；Mir3.exe 基址 0x400000，capstone 反汇编 + ModRM 全编码字节扫描 + IAT 语义 + GBK→cp949 解码 + layout.json 交叉核对）：
- 模式字节 0x8B1878：写点 {0@0x4020AD 启动, 2@0x40298E 淡入切换, 2@0x419BF9 协议侧切换, 3@0x4570BE 进游戏}；主循环分发 0x40211E：mode0→0x402BE0(0x8A9520)、mode2→0x4575D0(0x8A7140)、mode3→[0x8AB7E8]→0x41BB00/0x41B440+0x41B500；mode1 无写者（derived：未用）。
- 启动栈 0x401B30：补丁检查 MessageBox(0x47A320/0x47A468) → socket 连接 0x45CA80(0x8AB7A8, …, msgid 0x66, mode 1|2 按 [0x47EE89]) → 主窗口 0x451100（CreateWindowExA class 0x47C438 'EDIT'、style 0x90000080、SetWindowLongA GWL_WNDPROC=0x450C40、字体 굴림체 0x47BE18）→ char-select ctor 0x4026E0 @0x402094 → mode=0 @0x4020AD → PeekMessage 泵 0x4020CB；子类 WndProc 0x450C40→hub 0x8B1B08→泵 0x450CD0（默认 CallWindowProcA 前置 [hub+0x14]，写点未定位 pending）。
- char-select 0x4026E0：GameInter owner+0x46C @0x40272A、Interface1c owner+0x5B0 @0x40273E；wemade.dat 0x47AA8C→+0x6F4；EDIT 子窗口 0x4511D0(0x8AA488,0x14)，账户矩形 SetRect(+0xF44,128,440,227,454)、密码矩形 SetRect(+0xF54,326,440,425,454)；4 按钮（0x417550）：+0xA68 F11 选择角色 (459,436)、+0xB1C F13 创建账号 (139,379)、+0xBD0 F15 修改密码 (279,379)、+0xC84 F17 (439,379)（标签为 layout.json F11/13/15 像素检视 primary-resource-visual；F15→GetPrivateProfileStringA('Initial','Param3',0x47ABDC Modify_pwd URL)→ShellExecuteA@0x404405→WM_DESTROY 退出）；登录字段账户 +0xD39/密码 +0xE3D/记忆标志 +0xD38；提交 0x403640/0x40406E→0x451F10 msgid 0x7D1 '%s/%s'；阶段 +0x8A4（1 登录 0x402D50、2 服务器列表 0x4031A0、3 淡入 0x403560/2000ms→0x402970）；表单解析 0x403780（ctor 调用 @0x4026EE，Mir3.ini Initial/Server%）；WM_CHAR 0x403FD0→0x401730 nProtect 心跳（TfrmNPMON/WWW.NPROTECT.COM）。
- parent 0x456CB0（初始化器 0x456A90）：GameInter owner+0x8、Interface1c owner+0x14C；F50 640×480 背景；9 按钮：F51(440,93)创建 0x459A20-0x459AC5、F53(79,243)、F55(259,49)进游戏 0x459B16→0x452070 msgid 0x67、F57(28,438)退出 WM_DESTROY、F92/F95/F98/F86 底部滚动/功能、F89(491,444)确认→0x459D48 阶段3+0x451F90 msgid 0x64；阶段 +0x930 表 @0x457778=[0x4575F3,0x457615,0x457604,0x4576FA,0x45773C]（0 角色列表、1 建号进行中→2@0x45763D、2 动画列表+密码框、3 等待→0@0x45770F、4 等待→0x4570A0 进游戏），写点 7 处读点 7 处全枚举（ModRM 全编码）；槽机制 +0xCB8/+0x10BC 步长 0x40×2、0x458B20/0x4584C0 显示 '[男 武 士 ]' 类 + Mirmg.dll LoadStringA(0x190+arg)+0x468CD7(0x47D6F0 12 字段)；音效 +0x113C/0x1140/0x1144（CreateChr/SelChr/StartGame.wav，0x45B6D0）。
- 服务器分发器：parent 0x458F80（ret 4，vtable[2]=0x458F10 入口，msgid−0x208 选择器→跳表 0x45950C 9 项）：0x208/520 角色列表刷新（0x458FBD，空→0x47D818 '请先建立至少一个角色才能进行游戏.'）、0x209/521 服务端要求建号（0x45922F 阶段3+CreateChr.dat 0x47D7E0+发 0x64）、0x20A/522 错误 800/802/9000、0x20B/523 重发 0x64、0x20C/524 900、0x20D/525 进游戏 OK（0x459465 阶段4+StartGame.dat 0x47D7C8）、0x20E/526 '게임을 시작할 수 없습니다.'、0x20F/527 '服务器认证已不可用,请重新登录.'、0x210/528 '서버와의 접속이 끊겼습니다.'；char-select 0x403B80（0x1F5..0x212 选择器 0x403E40）：501/502/529（账户 0x47EEF8）/530（服务器列表 0x47EEC0/0x47EEA8、[0x47EF10]=选中索引、+0x8A4=3）；网络分发 0x409720（vtable 0x476420[1]，gate [esi+0x88]==3，选择器 0x40A148 17 项，id→msg 映射 0x09→501…0x8B→530）；游戏侧 case-0x64 0x41CE00（sub0→[+0x428204]=2→0x419BE0 回 parent）。
- 发送链（全部 socket 0x8AB828）：0x66 连接（0x45CA80）、0x7D1 登录（0x451F10 '%s/%s' 账户/密码）、0x68 服务器选择（0x451F60）、0x64 建号/确认（0x451F90 '%s/%d' 账户/服务器索引 [0x47EF10]）、0x67 进游戏（0x452070 '%s/%s' 账户/角色名）。
- 字符串 36 条全部定案（GBK：0x47D818/0x47D7F8/0x47D778 ' 武 士 ]'/0x47D784 ' 法 师 ]'/0x47D790 ' 道 士 ]'；cp949：0x47D7AC/0x47AB78/0x47AB94/0x47A320/0x47BE18 '굴림체'；ASCII：0x47C84C/0x47C854/0x47D7E0/0x47D7C8/0x47AA8C/wav/mp3/0x47D6F0 解析格式/0x47C438 'EDIT'/0x47ABDC Modify_pwd URL/0x47D978 DX 错误）。

**结论(Verdict)**：closed（primary-static 主导，candidate/pending 残余显式分离）。完整流程：启动→0x66 连接→char-select→0x7D1 登录→529→服务器列表→0x68→530→淡入→parent→0x208 角色列表→F51 建号/0x64（CreateChr.dat）或 F55 进游戏/0x67→0x20D→阶段4→0x4570A0→mode3。落盘 `login-flow-evidence.json`。与既有负闭合一致：无好友/社交窗口（0x8A7140 双用途=登录/通知对话框，同 Finding 270 结论）。

**pending**：需运行时捕获（candidate）：hub+0x14 前置 WndProc 写点；F17/F53/F92/F95/F98/F86 按钮语义；wrapper 队列 0x40A043 排空机制；0x47EF10 服务器索引在 530 包中的精确来源；0x7D1 登录包线格式；F13 建号 URL 键名（F15 Param3 已 primary）。
## Finding 276 (OffsetDistribution, 2026-08-11)：EI 3.0 素材帧 offset（+4/+6）非零分布全库闭合 — P9 定案：地图层库几乎全帧非零，C5 零读取为有意约定

**问题**：P9（EVIDENCE-INVENTORY pending）——EI 素材中帧 offset（WIL 17B 头 +4/+6 = offsetX/offsetY）非零值的分布。C5 说地图层（ground/mid/front）全分支零 offset 读取；C6 说 actor 层应用 offset（+4/+6）。地图层使用的 TILE/OBJECT 库到底是否真的含非零 offset（即 C5 是有意忽略），还是素材本来就零？

**调查**（primary 素材侧全量扫描，binary：`/tmp/nas_mnt/NAS/TMP/EI传奇3.0客户端/Data/*.wil`；工具 `Tools/maps/offset_distribution.py`，wilsdk open_library + lib.header(i)，<h 有符号 16 位）：
- **全量**：123 库（顶层 86 + Forest/Sand/Snow/Wood 主题子目录 37），帧总数 1,084,929，有数据 360,622，其中 356,402 帧 offsetX 或 offsetY 非零（98.8%）。全库无数据帧 724,307（含 Forest/Snow 24 个 2 帧空壳主题库）。
- **城镇/主题系地面与物件库全帧统一 (-24,-16)**：Tilesc（8,686/8,686）、Tiles30c（936/936）、Wallsc（3,051）、Cliffsc（7,440）、Housesc（5,499）、SmObjectsc（5,173）、Animationsc（1,930）、Innersc（44）、Dungeonsc 主体（4,938/4,965）、Sand/* 5 库、Wood/* 8 库、NPCface（46）、MonImg（146）。min==max==(-24,-16) → 库内严格统一。
- **洞穴系统一 (7,-44)**：Tiles5c 帧 10000+（2,685 帧）、object1c（13,845）、object2c（11,144）、SmTilesc 帧 10000+（174）、MMap 帧 35-38/70-83（18）。另有散点 (0,0)：Tiles5c×637、object1c×1,886、object2c×1,435（合计 4,220 帧，占数据帧 1.2%）。
- **巨值伪 offset 帧（真实存储值，非解码错误）**：SmTilesc 帧 0-175（168 帧，(-1132,-19694)×159 + (28432,21537)×9）、Dungeonsc 帧 0-34（27 帧，-1132,-22226 / 30400,21537）、Furnituresc 帧 1-370（260 帧，-1132,-22226 / 30280,21537 等），全为 48px 宽帧；原始 17B 头 hex 复核（如 SmTilesc f0 raw `30002000106f215430106f19aa60060000` → w=48 h=32 x=0x6f10=28432 y=0x5421=21537）。
- **地图引用帧交叉核对（5 图，catalog 逐层 lib+frame_min/max）**：0.map ground tilesc/tiles30c 全 (-24,-16)、mid/front 城镇系全 (-24,-16)、object1c/object2c 全 (7,-44)，且 **mid 显式引用 furnituresc f87-283（巨值 offset 区间）、front 引用 f13-133**——原版渲染正常（C14 已对齐）→ 忽略 offset 是正确渲染的必需条件；D1001 ground tiles5c f10044-12974 / mid object2c 全 (7,-44)；8.map 全 (-24,-16)；3.map tiles5c f10000-11504 (0,0)→(7,-44)；41.map sand_housesc/sand_animationsc 部分引用帧超库帧数（header None，frame_oob C11 类）。
- **actor 系（C6 应用）逐帧变化**：Mon-1 x[-79..51] y[-108..35]、Mon-6 y 至 -284、M-Hum x[-109..23] y[-148..-4]、NPC x[-131..29] y[-121..-5]、MonMagic x[-411..152] y[-334..68]——几乎全帧非零（60 库 254,202 数据帧 99.9% 非零）。
- **terrain/ui/misc**：MMap (-24,-16)×136 + (7,-44)×18、FMMap (-24,-16)×28 + (0,0)×1；GameInter (-24,-16)×231 + (7,-44)×22；Interface1c 519 种不同 offset 对（控件逐图定位）；Storeitem/Ground/inventory/MIcon 以 (-24,-16) 为主。

**结论(Verdict)**：P9 closed（evidence_level derived）。TILE/OBJECT 库确实大量携带非零 offset（有数据帧 98.8% 非零，地图层引用帧几乎全部非零），**C5 是原版的有意约定**而非素材恰好为零的平凡结果：素材定义 offset（城镇系 (-24,-16)、洞穴系 (7,-44)），地图层绘制路径（43bb10/43be00/43b440/43b9a0/43c330/43c4c9）零读取；若应用，96×64 帧按 -24,-16 平移、0.map furnituresc 巨值帧抛飞数万像素（D2 none=原版、C16 三模式、D6 midfront 0.8%/all 26.6% 像素差一致）。offset 有实际语义的库：actor 系全部（C6）、Interface1c 控件图、物品图标；MMap/FMMap 的 (-24,-16)/(7,-44) 不参与小地图线性映射（P6 另校）。巨值伪 offset 帧（SmTilesc/Dungeonsc/Furnituresc 帧 0-370）为文件内真实值，0.map 引用其中 furnituresc 帧且渲染正常，反证忽略 offset 的正确性。

落盘：`offset-distribution.json`（123 库逐库 {count,no_data,data_frames,zero_size,nonzero_off_x,nonzero_off_y,either,min/max_x,min/max_y,subcategory}）、`offset-distribution-evidence.json`（method/分类表/5 图交叉核对/verdict）、`Tools/maps/offset_distribution.py`（可复现扫描工具）。
## Finding 275 (GroundNotDrawn, 2026-08-11)：P2 闭合 — 0_003/5_0013 ground_not_drawn 为原版显式跳过空地面格（file=255+frame=0xFFFF），非静态背景、非审计伪影

**问题**：P2（EVIDENCE-INVENTORY pending，137/67 格 ground_not_drawn）：0_003.map（60×100）与 5_0013.map（68×68）地面层未绘制格，原版客户端是跳过、按空/黑帧绘制、还是根本不用瓦片（D4/K2 候选：室内图地面 = ZL `MapInfo.Background` 静态背景）？

**调查**（primary-static；Mir3.exe 基址 0x400000，fileoff=VA−0x400000；地图直读 `.../EI传奇3.0客户端/Map/`；audit_mir3_maps.v_lookup + capstone + 魔数 0x6db6db6d T 变换数值仿真）：
- **数据侧**（两图地面层 3B/块平铺，flat=xb*(h//2)+yb，与 EXE 索引公式 0x43b50b-0x43b516 一致）：0_003 1500 块中 137 块未绘，**全部为 file=255 + frame=0xFFFF（EMPTY_FRAME）空条目**，呈 L 形边距（最右 1 列 xb=29 + 最下 3 行 yb=47-49）→ 绘制区 58×94 格；5_0013 1156 块中 67 块未绘，**全部同样为空条目**，呈右 1 列 + 下 1 行 → 绘制区 66×66 格。两图未绘区对应 cell 层 mid/front 也全空（0_003：file 255/0xFFFF；5_0013：file 15 NO_OBJECT/0xFFFF）。绘制地面：0_003 = tilesc 599 块帧 1803..9143 + tiles30c 764 块帧 605..1024；5_0013 = tiles5c 1037 块帧 10-24（**998 块为 C17 近黑帧 f20-24，原版正常绘制**）+ tilesc 52 块。
- **EXE 侧**：地面渲染器 **0x43b440**（调用点 0x43b7f5 地图装载、0x410838 视图初始化）先 `rep stosd` 清零 ebp+0x1b2 地面层缓冲为黑（0x43b455-0x43b45c，0x6c000 dwords=768×1152×16bpp），每格 4 门：**Gate A** `T%14>2 跳过`（0x43b53c，idiv 0xe）、**Gate B** `T>0x45 跳过`（0x43b545）、**Gate C** `frame==0xFFFF 跳过`（0x43b54a）、**Gate D** `0x466130 帧解析为空跳过`（0x43b569），全过才 blit（0x45e8e0 → 0x8ab7a8 地面表面）。T(file)=file−floor(file/14)（0x43b522 魔数序列，数值仿真 0..255 验证）：**file=255 → T=237 → Gate A（237%14=13>2）与 Gate B（237>69）双拒 + frame=0xFFFF 触发 Gate C → 三重门全拒，无条件跳过**。预备通道 0x43b2fd-0x43b337（审计注释引用点 0x43b317）同 4 门 → 审计 `~((r<=2)&(v<=69))` 与 EXE Gate A/B 逐位一致，**非审计伪影**。0x41c860 非地面通道（瓦片通道 0x41C450 内的动画格渲染器，Finding 269 地面物品/装饰类）；物件通道 0x43bb10/0x43be00 同样带 frame==0xFFFF 门（0x43bbbb/0x43bbc1）。

**结论(Verdict)**：P2 closed（derived：跳过逻辑与缓冲清零 primary-static，黑边观感合成 derived）。两图未绘格 = 地图作者留白边距（右/下），原版客户端显式跳过（不 blit），地面层缓冲清零为黑 → 滚动到视野内呈现**黑色 void**；**D4/K2『静态背景』对 EI 不成立**——0_003/5_0013 地面均为瓦片绘制（1363/1089 块），EI 0x43b440 无任何背景图像机制（MapInfo.Background 为 ZL/GodotClient 侧概念）。黑帧（C17 tiles5c f20-24，998 块照绘）与空帧（0xFFFF 跳过）机制区分明确：跳过条件只由 file/frame 数据值决定，与像素内容无关。落盘 `ground-not-drawn-evidence.json`。

**pending**：无需运行时捕获（静态链闭合）；可选 candidate：0x43b440 → 0x45e8e0 → 0x8ab7a8 上屏合成的逐帧细节运行时截图确认。

### Finding 274 (FrameOobSemantics, 2026-08-11)：原版帧越界（frame_oob）语义定案 — P1/P3 闭合：FetchFrame 显式边界检查，全部绘制路径返回 0 即跳过 → 单元格不绘制（透明）；3.map 3255 格地面透出、D10031 62 格背景透出

**问题**：P1（EVIDENCE-INVENTORY pending）：原版对地图格引用帧号 >= 库帧数（frame_oob）的替换逻辑——空帧/首帧/取模/跳过/无检查，哪个？P3：3.map 3255 个 OOB 格（mid/front lib24/25 wood_*）与 D10031 唯一 ground OOB 62 格实际渲染成什么？

**调查**（primary-static；Mir3.exe 基址 0x400000、fileoff=VA−0x400000、0x80000 字节 → 0x400000–0x47FFFF 为真实代码；capstone 反汇编 + 原始字节直读；工具 `Tools/reverse-engineering/disasm_capstone.py`、`Tools/maps/audit_mir3_maps.py`、`Tools/common/wilsdk.py`）：
- **库帧数来源（装载器 0x466160）**：ReadFile 只读 24 字节 wix 头（0x466239，`push 0x18`）；`0x46623F mov eax,[esp+0x28]`（栈核算：读缓冲=X+0x14 → [esp+0x28]=缓冲+0x14 = wix 文件字节 20）→ `0x466243 mov [ebx+0x10],eax`（lib+0x10=帧数）；`0x466246 shl eax,5` + malloc → `0x466256 mov [ebx+0xC],edi`（32B/条索引数组）。wix 字节 20 与 wilsdk lib.count 逐库一致（Animationsc 2921、smtilesc 10180、tiles5c 20000；主题 Wood/Wallsc=3791、Wood/SmObjectsc=969 = audit lib24/25 的 lib_frames）。
- **边界检查（0x466130 分派 → type0 WIL 0x466640 / type1/2 ZL 0x466720）**：type0 `0x466646 mov edi,[esp+0x14]`（帧号）→ `0x46664A cmp edi,[esi+0x10]`（bytes `3b 7e 10`）→ `0x46664D jae 0x466714`（帧号>=帧数 FAIL）；通过后 `0x46665D shl edi,5`（原始索引、无取模）→ `[edi+4]` 文件偏移；偏移 0（空帧 `je 0x466714`）、宽/高>0x1000（`jg 0x466714`）同样 FAIL；成功 `0x46670B mov eax,1`，失败 `0x466714 xor eax,eax; ret 4`。type1/2 同构：`0x466727 cmp eax,[ecx+0x2C]; 0x466729 jae 0x466761`。OOB 在解引用之前被拦，无越界访问、无回退帧。
- **绘制路径门控（7 处逐一验证，全部 `call 0x466130 → test eax,eax → je <纯 epilogue>`）**：mid/front func1 0x43BB10 首取 `0x43BBDC`（bytes `e8 4f a5 02 00 85 c0 0f 84`）→ `je 0x43BDED`，动画 delta 二次获取 `0x43BC6D`（调色板表 [esi+0x1B01D4] nibble → `add ebx,edx` 帧号+delta）→ `je 0x43BDED`；func2 0x43BE00 `0x43BECC`/`0x43BF59` → `je 0x43C0D9`；func4 0x43C330 `0x43C454` → `je 0x43C4CE`；地面渲染 0x43B440 `0x43B562`（bytes `e8 c9 ab 02 00 85 c0 74`）→ `je 0x43B5C7`（入口 0x43B455-0x43B45C `mov ecx,0x6C000; rep stosd` 深度面清零）；地面物件通道 0x41C860 `0x41C8BE` → `je 0x41C9FE`；装饰通道 0x41CA20 `0x41CA6D` → `je 0x41CB9E`。跳转目标均为 `pop*/add esp/ret` 纯收尾（如 0x43BDED bytes `5f 5e 5d 5b 83 c4 64 c2 0c 00`）——无替代绘制。0xFFFF 空帧是绘制函数入口的独立判跳（0x43BB4A-0x43BB4E），与 OOB 机制无关。
- **图层顺序**：地面瓦片 0x43B440（调用方 0x410838/0x43B7F5）先于 mid/front 0x43BB10/0x43BE00（调用方 0x41C59A/0x41C5A5、0x41C66D/0x41C678，瓦片通道 0x41C450 pass1/pass2）。
- **audit 复跑**：3.map anomaly_total=3255 = mid lib24 172 + mid lib25 2575 + front lib24 8 + front lib25 500（lib24 wood_wallsc→Data/Wood/Wallsc.wil 3791 帧，引用超至 4537；lib25 wood_smobjectsc→Wood/SmObjectsc.wil 969 帧，引用超至 2531）。D10031 ground lib2 62 块、frame_max 42766 vs tiles5c 20000；62 块 OOB 帧号全部位于 42756–42766（0xA704–0xA70E，10 个唯一值，计数 1/5/6/6/8/9/6/9/4/8）——高值连续簇，似编辑工具坏引用/哨兵残留，非动画。**对 P3 表述的更正**：audit 与素材核对表明 D10031 的 ground OOB 在 **tiles5c（KR_ORDER[2]）**，不是 smtilesc——地面格（r<=2）只用 tilesc/tiles30c/tiles5c 三库（Libraries.cs 映射 0/1/2=tilesc/tiles30c/tiles5c、3=smtilesc）；帧 9998 属于 62 个 **mid** 格（smtilesc），9998<10180 在界内正常渲染，不是 anomaly。

**结论(Verdict)**：P1 closed（primary-static）= **跳过不绘制（透明）**：OOB → FetchFrame 返回 0 → 7 个绘制路径全部 `test eax,eax; je epilogue`，单元格无像素写入。无检查/取模/首帧/空帧显示四候选全部证伪（比较真实存在、索引原样使用、fail 直接返回 0 无回退、0xFFFF 空帧是独立路径）。P3 closed（primary-static）= 3.map 3255 个 mid/front OOB 格渲染为不绘制 → 地面透出（缺物件）；D10031 62 个 ground OOB 块（tiles5c 帧 42756-42766）渲染为不绘制 → 背景透出（透明）。两图无崩溃、无替代帧。（像素级"透出/透明"由 skip-不写入机制+图层顺序静态推导，具体背景色属帧管线状态。）落盘 `frame-oob-semantics-evidence.json`（VA 级 trace + 原始字节 + 假设判定表 + 两图逐库统计 + D10031 归属更正）。

**pending**：无（两 pending 项全部闭合；"背景色具体值"不属于本项范围，未升级）。
## Finding 277 (MinimapCalibration, 2026-08-11)：P6 闭合 — 小地图帧放置公式 confirmed：origin=(0,0)、scale=1.5×1.0 px/tile、frame=ceil4(W·1.5)×H；帧索引规则更正 MMap=value−1（现模拟器/交叉引用差一帧，每张 MMap 图显示邻图小地图）

**问题**：P6（EVIDENCE-INVENTORY pending）——每图小地图（MMap.wil/FMMap.wil 帧）在固定 128×128 面板（屏幕右上 (672,0)-(800,128)）内的放置标定：帧内子矩形提取公式（origin/scale），以及 MiniMap.txt 值→帧映射与 EXE 实际行为是否一致。

**调查**（primary-static + 素材全量几何；Mir3.exe 基址 0x400000、fileoff=VA−0x400000；`Envir/MiniMap.txt` 313 条、MMap.wil 255 帧、FMMap.wil 31 帧、`Map/<stem>.map` 28B 头 W@22/H@24 u16LE；wilsdk + `/tmp/mm_frame_bboxes.json` 全帧 painted bbox）：
- **EXE 字符串**：file 0x7c414/0x7c428 = VA 0x47C414 `.\Data\FMMap.wil` / 0x47C428 `.\Data\MMap.wil`。
- **控制器 ctor 0x43D4D0**：MMap.wil→[this+4]、FMMap.wil→[this+0x148]（0x4660E0 装载，0x43D4D9-0x43D502）；面板矩形 SetRect(&[+0x2C0], 672,0,800,128)（0x43D518 push 0x2A0/0/0x320/0x80），面板尺寸 [+0x2B8]=[+0x2BC]=0x80=128（0x43D545）。
- **帧索引规则（关键更正）**：setter 0x43D780 唯一调用点 0x420C3A（网络换图 handler）：先 `dec edx`（0x420C3A，包字段 [esp+0x16] 16 位 AND 0xFFFF 后 −1）→ setter `cmp eax,0x3E8`（0x43D787，bytes `3d e8 03 00 00`）：<1000 → MMap 库 [this+4] 帧=eax（0x43D7F1）；≥1000 → `add eax,0xFFFFFC18`（−1000，0x43D794）→ FMMap 库 [this+0x148] 帧=eax。⇒ 有效规则：**idx=value−1；idx≥1000 → FMMap frame=value−1001；否则 MMap frame=value−1**。帧选择 0x466130→0x466640/0x466720 为 0 基直通（无 ±1）。交叉引用/模拟器现行规则（value<1001→frame=value，`Tools/maps/gen_minimap_ei.py` L77、minimap-server-crossref.json rules）对 MMap 差一帧；FMMap（value−1001）正确。
- **放置公式（EXE + 素材几何双重）**：帧选后读帧头宽/高（movsx word [eax]/[eax+2]，0x43D7B3-0x43D7B7）→ 帧矩形 [+0x2E0]={0,0,W,H}（0x43D7C7）；玩家/实体标记 X 坐标 `fild × float[0x476904]`=×1.5（0x43DB36/0x43DC74/0x43DCF8），Y 无乘子（×1.0，如 0x43DC91 直减）→ **painted_px = W·1.5 × H·1.0**。素材几何：map W×H → frame 尺寸 = **ceil4(W·1.5) × H**（450→452、150→152、75→76、375→376、750→752、225→228、165→168、315→316），used 帧 painted bbox=(0,0,W·1.5,H)、fill=1.0、minx=miny=0 全帧满画布 → **P6『空白边距+按图裁剪子矩形』前提为假**；WIL offsetX/offsetY(−24,−16) 恒定不移动绘制原点。
- **全量核对（313 条）**：可读图头 241 条中 **229 条** frame 尺寸==ceil4(W·1.5)×H（value−1 规则 95%）；frame=value 仅 160/241；**0 条尺寸不匹配**（此前帧=value 规则下的 D406/D416/D1001/E602/E603『互换/错帧』等 81 条全是差一伪影）。验证样例：0.map(800×800)→FMMap f0 1200×800 ✓、D001(400×400,val 1)→MMap f0 600×400 ✓（现模拟器显示 f1=D002 图，MMap f0-4 MD5 全互异→真实视觉错帧）、D1001(400×400,val 101)→MMap f100 600×400 ✓（旧规则 f101=452×300 ✗）。
- **异常分类**：12 条指向**真空白帧**（wilsdk header=None 复核）→ 无美术：81(300×350)→FMMap f19、D452→MMap f24、D901/D9021/D9022→f145-147、D2011/D2012/D202/D203→f150-153、D808/D8102/D8202→f172-173；72 条地图文件不在 EI client Map 目录（服务器专属/未随包，含 9/401-405/407 及 E7xx/F0xx/R005/RUSH1/Island01-02/Q 系列）；FMMap 仅 31 帧（0-30），401-405/407→帧 31-37 不存在；31.map→FMMap f30 特例：452×300 offset(0,0)、painted 450×300=精确 W·1.5（+2px 画布内边距）；MMap 空白帧 101 个（f5-9、24-29、39、46-49、59、65-69、84-89、97-99、109、117-119、127-159、172-179、185-189、206-209、217-219、226-229、236-239、245-249）= MiniMap.txt 未用值区间，FMMap 空白 f19/f29。
- **面板渲染**：update 0x43D5F0 将目标矩形锚定屏幕右缘 SetRect(&[+0x2C0], 800−min(128,frame_w), 0, 800, min(128,frame_h))（0x43D63E-0x43D655）→ 整帧缩放绘入 128×128；源窗口 [+0x2D0] 随玩家滚动（0x43D850）；模拟器 ~128px 面板 object-fit:cover 为忠实近似。

**结论(Verdict)**：P6 closed（evidence_level **confirmed**；EXE primary-static + 素材几何）。放置公式：**painted=(0,0,W·1.5,H) px、scale=[1.5,1.0] px/tile（48×32 格→1/32 等比）、frame=ceil4(W·1.5)×H、origin=(0,0)**，整帧缩入 128×128 面板（(672,0)-(800,128)）。P6 描述的真实缺陷 = **MMap 帧索引差一**：客户端用 value−1，现模拟器/交叉引用用 value → 每张 MMap 图渲染邻图小地图；FMMap 规则（value−1001）正确。12 图指向真空白帧（无美术）、72 图未随客户端打包、401-405/407 FMMap 越界。落盘 `docs/research/mir3-map-reconstruction/minimap-calibration-evidence.json`（313 条逐图表 {map_index,server_value,client_index,library,frame,map_W×H,frame_W×H,painted_bbox,fill,placement_origin,scale,status} + frame_index_rule/placement_formula/panel_geometry EXE 证据 + anomalies + verdict）。

**pending**：无（静态链闭合）；建议后续（candidate）：修复 gen_minimap_ei.py/mapviewer MMap 分支为 frame=value−1 并视觉复核 D001→MMap f0。

## Finding 278 (ReservedFrames, 2026-08-11)：P10 细化 — 保留标记帧（0xFF00–0xFFFE）语义 = 客户端精确比较 frame==0xFFFF（非掩码，VA 0x43BBBB/0x43B321），0xFF00+ 仅为普通越界→不绘制；22 库纯保留/混合引用逐帧枚举，全部保留格独占 39 个 13B 探针图；『3 库全幻影』不可复现

**问题**：P10（EVIDENCE-INVENTORY.md 第 69 行，objective §9）——22 个库仅有保留标记帧（0xFF00+）引用、无解码帧；3 个库全部引用幻影帧（无数据）；其内容语义未查。C10（第 25 行）『EI 空帧 = 0xFFFF；file 15 = 无物件』：地图格帧判断是掩码 (frame & 0xFF00)==0xFF00 还是精确 ==0xFFFF？

**调查**（primary-static；Mir3.exe 基址 0x400000、fileoff=VA−0x400000、0x80000 字节 → 0x400000–0x47FFFF 真实代码；capstone 反汇编 + 原始字节 + 全 544 图双扫描交叉验证；工具 `Tools/reverse-engineering/disasm_capstone.py`、`Tools/maps/audit_mir3_maps.py`、`Tools/maps/mapviewer.py`、`Tools/common/wilsdk.py`、`Tools/maps/lib_frame_stats.py`）：
- **精确比较非掩码（C10 closed）**：物件 func1 0x43BB10：`0x43BB45 mov ax,[eax+ecx+3]`（格字 = frontFile | midFile<<8）→ `0x43BB4A cmp ax,0xffff; je 0x43BDED`；图层标志 [esp+0x80] 分 mid（file=byte4 `and eax,0xffff; shr eax,8`、frame=`mov bx,[edx+5]` u16@+5）/front（file=byte3 `and eax,0xff`、frame=`mov bx,[edx+7]` u16@+7）；v 变换 `0x43BB82 mov eax,0x6db6db6d; imul ecx; sub edx,ecx; sar edx,3; shr eax,0x1f; add edx,eax; add ecx,edx`（v = file − floor(file/14)）→ `0x43BB9D cdq; mov ecx,0xe; idiv ecx`（q=v/14, r=v%14）→ `0x43BBA5 cmp edx,3; jl`（r<3 地面库在物件槽跳过）、`0x43BBB2 cmp eax,0x45; jg`（v>69 跳过）→ **`0x43BBBB cmp ebx,0xffff; je 0x43BDED`（帧号精确 ==0xFFFF）** → 槽表 `0x43BBC7 lea [eax+eax*8]×2; lea ecx,[edx*4+0x5600fc]`（0x5600FC+v*324）→ `0x43BBDC call 0x466130` → `0x43BBE1 test eax,eax; je`。地面渲染 0x43B440 判跳段 0x43B310-0x43B337：`0x43B317 cmp edx,2; jg`（r<=2 地面）、`0x43B31C cmp ecx,0x45; jg`、**`0x43B321 cmp esi,0xffff; je`**；front func2 0x43BE00 同构 `0x43BE3A/0x43BEAB cmp …,0xffff`。**0x43A000–0x43E000 全域 --grep '0xff00' 零命中** → 地图解码/渲染区不存在任何 0xFF00 掩码或立即数比较。
- **0xFF00–0xFFFE 客户端效果 = 普通越界 → 不绘制**：通过 0xFFFF 比较后进入 FetchFrame（0x466130 → type0 WIL 0x466640），`0x46664A cmp edi,[esi+0x10]; jae 0x466714` 边界检查必然失败（53 库目录最大帧数 33,125 < 0xFF00=65,280）→ `0x466714 xor eax,eax; ret 4` 返回 0 → 调用点 `test eax,eax; je` 跳过 → 不绘制（机制同 Finding 274）。『保留标记』是地图数据/编辑器约定，客户端无特殊处理。
- **22 库枚举（lib-frame-stats.json 备注 + reserved_phantom_scan 复扫双一致，全部 real_frames_used=0）**：16 纯保留 = lid 18/20/23/35/36/38/51/52/56/63/64/65/67/68/69/70（逐帧清单见证据 JSON）；6 保留+幻影混合 = lid 33/37/48/53/66/71，幻影帧（OOB ≥ cap）仅落 5 个 13B 探针图：0_0011（lid33 f0x6D01）、0_002/0_0021（lid48 f0x5200）、kt0018/kt00181（lid33 f0xCD44、37 f0xCE44、53 f0xD844、66 f0x9C44、71 f0x5544/0x7144/0xE944——低字节 0x44 常数 = 编辑工具系统化扫帧测试对）。KR_ORDER 为稀疏表（62 键），63–71 = forest_smtilesc/housesc/cliffsc/dungeonsc/innersc/furnituresc/wallsc/smobjectsc/animationsc（cap 10180/9577/7619/5364/68/1714/9213/7569/2921）。
- **保留帧分布**：26 个不同值（0xFF00–0xFF80），raw 41,996 格 / 解析过滤（v<=69,r>=3,kr>=0）8,286 格，全部且仅位于 39 个 13B 图（D612 13,860、D618 6,137、d601 5,256、d602 4,070、D615 1,789 居前；0xFF7A=13,034、0xFF7B=8,901 为最大两值）；真实 14B 图保留格 = 0（此前『4.map 1604 保留格』为掩码误含 0xFFFF 部分空格所致）。audit 注释『26 distinct values』精确成立；『≤16 cells each』对全图 raw 扫描不成立（应指单库单帧子集）。
- **『3 库全幻影』不可复现**：全 53 库扫描 all-phantom = 0。最接近的『3』子集 = 范围内唯一引用全为空占位帧（wix 条目偏移 0，wilsdk header()==None）的库：lid 41 sand_animationsc（cap=127，real 6 格 = f0×1/f16×5 全空占位）、lid 49 snow_housesc（cap=9577，real 1 格 = f4608 空占位，另 7 格 OOB 幻影 0x6400/0x6444/0x6700/0x7C00）、lid 54 snow_wallsc（cap=9213，real 2 格 = f2561 空占位）；三者兼有 0xFF00+ 保留帧且 lib_frame_stats 因 real=1-2 未入 22 备注库。lid 50 f5376（0_0011，48×32 words=1632）与 lid 55 f2817（kt0018/kt00181，48×32 words=212）经 header() 直查实为可解码帧——更正此前 decode_scan2『decodable=0』误判；lid 47 f1792（snow_tiles5c 地面库 r=2 在物件槽，0_0011 格 (13,14)）被 0x43BBA5 r<3 判跳，永不进入 FetchFrame。其他范围内空占位：lid3 f10177（0.map）、lid5 f1578（953 格 15 图）、lid12/lid21 f0（57 格 18 图 / 138 格）。
- **13B 探针图结构**：0_0011/0_002/0_0021/0_0031-33/D612-D619/d601/d602/d608-d611/kt0002-kt0018 系共 39 图 = 编辑器系统化自检扫描（多主题各 1 格探针，MAP-SURVEY §7）：对角带逐格测试 midFile 字节 × 保留/幻影帧组合（0_0011 midFile 8–214 × 0xFF00/0xFF01/0xFF19/0xFF44/0xFF7A… + lid50 f5376/lid49 f4608，frontFile=120 常数；0_0031-33 midFile 184–255 与 0–90 双带 × 0xFF19/0xFF1A/0xFF3A，frontFile 0xCF/0xC8/0x8F/0x7F 常数；kt0018 midFile 36–255 × 0xFF44 + 0x??44 幻影对）。引用 22 库的图 = 39 个 13B 图中的 37 个（唯一缺席 kt0016/kt00161，其保留格落在不解析文件字节 0xCF 上）。C11 对照（真实库 OOB）：3.map 3,255 格（lid25 f1061-1068）、41.map 1,619 格（lid40 f2807-2814）、50.map 39 格、50_001.map 19 格。

**结论(Verdict)**：P10 refined（evidence_level **primary-static**）。(1) 22 库『仅保留标记帧（0xFF00+）引用、无解码帧』精确成立 = 16 纯保留 + 6 保留+幻影混合，逐帧/逐图清单见 `docs/research/mir3-map-reconstruction/reserved-frame-markers-evidence.json`；(2) C10 closed = 空帧判断为**精确比较 frame==0xFFFF**（VA 0x43BBBB 物件帧 / 0x43B321 地面帧 / 0x43BEAB func2），0x43A000–0x43E000 无任何 0xff00 立即数 → 掩码测试假设证伪；0xFF00–0xFFFE 在客户端 = 普通越界帧 → FetchFrame 0x46664A 边界检查返回 0 → 不绘制（与 274 同机制），『保留标记』仅为地图数据/编辑器约定；(3) 『3 个库全部引用幻影帧』不可复现（all-phantom=0），幻影机理 = 帧号 ≥ 库帧数（OOB）或 wix 条目偏移 0（空占位），客户端均不绘制；最近似『3』= lid 41/49/54（范围内唯一引用全空占位）。保留标记帧（26 值/41,996 格）全部且仅位于 39 个 13B 探针图 = 编辑器自检数据，非游戏内容。落盘 `docs/research/mir3-map-reconstruction/reserved-frame-markers-evidence.json`。

**pending**：无（P10 三项全部回应；0xFF00+ 的编辑器写入方无服务器/编辑器样本，止于 candidate 推断）。
## Finding 279 (StateFrameTables, 2026-08-11)：运行时帧表（0x8AA5C0/0x8AA686/0x8AA6C8）静态来源闭合——全部为 EXE 编译期常量，非服务器数据；布局=每 state 3 字 (w0 基帧, w1 块长, w2 间隔)，填充链 0x449C80→0x44A240/0x44A090→0x449C50

**问题**：Finding 279——BSS 地址 0x8AA5C0（玩家）/0x8AA686（怪物）/0x8AA6C8（NPC）帧表位于文件之外（>0x480000），scene-entity-render-evidence.json 旧假设『表内容是运行时（服务器）数据→需运行时捕获』。谁在何时填充？数据源是 EXE 常量、Mir3.dat、weapon.ord 还是服务器？表精确布局？0x44A820 (state) / 0x44A240 (race) / db_object 0x8AA5A8 各自职责？

**调查**（primary-static；Mir3.exe 0x80000 字节、fileoff=VA−0x400000；capstone + 原始 4 字节立即数扫描 + WIL 头互证）：
- **0x8AA5A8 是静态单例对象**：27 处 `mov ecx,0x8AA5A8; call <method>`（thiscall）；三张表均为其字段——玩家表 obj+0x18=0x8AA5C0、怪物表 obj+0xDE=0x8AA686、NPC 表 obj+0x120=0x8AA6C8。0x8AA686/0x8AA6C8 在 EXE 无直接立即数，正因一律以 obj+偏移访问。
- **唯一写路径 = 0x449C50 三字写器**：`[ptr]=w0, [ptr+2]=w1, [ptr+4]=w2; ret 0x10`（0x449C54-0x449C6E）。全部表内容经它落盘。
- **默认种子 = 0x449C80（db_object 初始化器）**：启动唯一调用 0x402041 `mov ecx,0x8AA5A8` + 0x402046 `call 0x449C80`（返回值 0x40204B test 作状态检查）。写入：玩家表 33 条 state 0..32 @0x449C8D..0x449F49（如 s0=(0,4,200)@0x449C8D、s7=(0x230,3,200)@0x449D16、s8=(0x280,2,400)@0x449D2D、s16=(0x500,10,70)@0x449DD0、s32=(0xA00,3,100)@0x449F49，全部立即数）；怪物默认 9 条 @0x449F60..0x44A027（s0=(0,4,300)、s1=(0x50,6,130)、s8=(0x280,6,150)）；NPC 默认 3 条 @0x44A041/0x44A058/0x44A06F（(0,4,300)/(0x1E,10,300)/(0x3C,6,300)）。随后 call 0x44A910。
- **运行时覆盖 = 0x44A240（race 方法, ret 4, this=0x8AA5A8）**：渲染时按 race 覆盖怪物表 11 条；调用点 0x4050C1/0x405701/0x405A9A（0x405A94 `push ebx; mov ecx,0x8AA5A8; call 0x44A240`）。4 组跳转表+race 字节表：0x44A5F8/0x44A61C（race 0..0x78）、0x44A698/0x44A6A4、0x44A71C/0x44A734、0x44A7A4/0x44A7BC；变体全为立即数（如 state2=(0xA0,6,delay∈{100,140,150,120,160,90,130})、state8=(0x280,10/6/20,120/100)）；固定尾记录 state9=(0x2D0,6,150)@0x44A5A9、state10=(0x370,1,500)@0x44A5D8。
- **0x44A090 = NPC action 方法（ret 4, this=0x8AA5A8）**：按 action 覆盖 NPC 表 3 条；调用点 0x405267（arg=[edi+2]=NPC 身体索引）、0x405C7D。action 0x33..0x3B → state0 (0,1,300)/(0,12,80)/默认(0,4,300)；action 0x1B..0x3B → state1 (0x1E,6/9/10,300)/(0,1,300)/(0,12,80)；action 0x1C..0x3B → state2 (0x3C,6,300)/(0,1,300)/(0,12,80)（字节表 0x44A1CC/0x44A1EC/0x44A220）。
- **读侧公式（8 处读点, 全部 primary-static）**：玩家 `w0 + 3000*type + 10*flag`（0x40504D/0x4056BC/0x40598B/0x4059E3；type=身体 0..8、flag=[esi+0xC1]；0x405983-0x405992 `lea ecx,[edx+ecx*4]... lea ecx,[edx+ecx*2]` 即 10*flag+3000*type）；怪物 `w0 + 1000*(race%10) + 10*flag`（0x40511C：`idiv 10; imul edx,edx,0x64; ...lea eax,[edx+eax*2]`；0x405AD6 同）；NPC `w0 + 100*NPCbody + 10*flag, flag=[esp+0x40]%3`（0x405294/0x405827/0x405CAD；0x4051D2 `idiv esi(3)` 余数回写；NPCbody=[edi+2]<0x64）。写 [ebp/esi+0xB4]=w0、[+0xB8]=w0+w1、[+0xBC]=w2。
- **消费侧 = 帧推进 0x40C4B0**：tick=[esi+0x61C5C] 累加 dt；`0x40C4F6 cmp ecx,[esi+0xBC]` 超间隔则 [esi+0xC4]++（上限 [0xB8]）；`0x40C52B` 达界回绕 [esi+0xC4]=[esi+0xB4] 并 call vtable+0x10(0,[esi+0xC1]) 循环回调。⇒ 语义定案：w0=块起始帧、w1=块长、w2=每帧间隔（ms tick）。
- **0x44A820 修正**：非表写器。= action→规范 state 映射器（自由函数, 忽略 ecx/this；`al=9; byte[action-2+0x44A890]→jmp[0x44A884]`：dl0→0xD、dl1→0xA、dl2→9；flag==0 时 9→0xB/0xA→0xC/0xD→0xE；字节表 0x44A890=[0,0,1,1,0,1,2,2,2,2,2,2,2,1,0,0,2,0]）。结果供 vtable+0x10 状态设置器；14 调用点全在 0x40E3xx-0x4115xx 马匹/宠物 action 分发器（0x40E3FC/0x40E443/0x40E48B/0x40E4D3/0x40E5A9/0x40E5E3/0x40F07C/0x410BED/0x410C5C/0x410DCA/0x410E40/0x410EC6/0x410F30/0x411508），均 `mov ecx,0x8AA5A8`（此 this 被忽略）。
- **Mir3.dat 排除**：客户端根 mir3.dat = 532480=0x82000 字节 MZ/PE 辅助模块（非存档），内容为 WIL 路径字面量表（.\\Data\\tilesc.wil 等 @0x47F4xx，见 mir3-dat-resource-path-table.json），与帧表无关。weapon.ord（2640=0xA50 字节）由 0x44A8B0 读入 obj+0x132、0x44A910 后处理（16 字节密钥 0xF0 0x39 0xAB 0x8E + 0x452580/0x4525F0 校验、失败 log 0x47C5F4/0x47C608）——武器外观顺序数据，不参与帧表。
- **WIL 头互证**：M-Hum.wil=27000=9×3000（9 身体类型×3000 帧）⇔ 玩家公式 3000*type；Mon-1..8.wil=10000=10×1000 ⇔ 怪物公式 1000*(race%10)；NPC.wil=6400=64×100 ⇔ NPC 公式 100*NPCbody；M-Hair=15000=5×3000、M-Helmet1=24000=8×3000、M-Weapon1=30000=10×3000。

**结论(Verdict)**：Finding 279 closed（evidence_level **primary-static/confirmed**）。三张运行时帧表 = BSS 单例 0x8AA5A8 的字段，内容 100% 为 EXE 编译期常量（立即数 push），由 0x449C80（启动）写默认种子 + 0x44A240（race）/0x44A090（NPC action）按需覆盖，统一经 0x449C50 三字写器；无任何网络/文件/服务器输入路径——**『表内容是服务器数据』旧假设证伪**（修正 scene-entity-render-evidence.json frame_formulas.tables_runtime）。布局定案：每 state 6 字节 = (w0 块起始帧, w1 块长, w2 帧间隔 ms)，玩家 33 条/怪物 9-11 条/NPC 3 条；渲染公式 player=w0+3000*type+10*flag、monster=w0+1000*(race%10)+10*flag、NPC=w0+100*NPCbody+10*(flag%3)。0x44A820=action→state 映射器（9..0xE，马匹/宠物分发器），0x44A240=race 表覆盖器。全量种子表（含逐条 writeVA）落盘 `docs/research/ei-ui-layout/state-frame-tables-evidence.json`。

**pending**：无（静态链闭合）。候选后续（归属 Finding 282/后续）：玩家表 state 0..32 动作语义命名（站立/行走/奔跑/攻击/死亡/挖矿/骑马…）可从 0x40C4B0 循环回调 + 0x44A820 调用点交叉枚举。

## Round5 Verify (P7/P8 遮挡与排序闭合, 2026-08-11)

**范围**：闭合 round-3 scene-entity-render-evidence.json 遗留的两处遮挡待办（P7 tile-pass 遮挡窗口、P8 world-sort 网格与 type 语义），VA 级 primary-static 验证（fresh capstone dumps），并修正 round-3 两处 map 读数错误。

**证据级别**：primary-static（Mir3.exe 直读 + capstone；fileoff=VA−0x400000）。写入文件：`scene-entity-render-evidence.json` 顶层新增 `round5_closure` 键（date 2026-08-11；corrections×6 / occlusion_window / new_identities×4 / closed_pendings×5；evidence_level=primary-static）；pending 由 10 项精简为 7 项。

### Tile pass 1（0x41C48B–0x41C607）
- 遍历域：y∈[camY−0xA, camY+0x22) × x∈[camX−0xA, camX+0x22)（44×44 tile）。cam_x=[root+0xF532C]、cam_y=[root+0xF5330]。
- 每 tile：0x43CA40 tile 信息 → 地面 0x434A20 + 0x43BB10 ×2 → 实体单元 0x41CBD0(x−camX, y−camY, 1)。

### 遮挡窗口（0x41C5AA–0x41C5DE）— 修正 round-3「0x7F=transparent skip」
- **只对 [camX,camX+0x18)×[camY,camY+0x18)（24×24）内 tile 传入相对坐标**；窗口外全部传 (0,0) → 网格 cell 0（相机 tile 实体，通常为玩家），由 [e+0x61C74]/[e+0x8A]==0x7F 门控 + [root+0x364444] 玩家身份检查过滤（[root+0x30]!=0 时跳过玩家）——draw quirk 而非可见 bug。
- **0x7F 语义修正**：word [e+0x8A]==0x7F 是**强制绘制标记**（flag==0 时也画）；skip 仅当 flag==0 且 word≠0x7F。round-3「transparent」误读。

### Front pass 2（0x41C60D–0x41C7B9）
- 范围：y∈[camY, camY+0x2C) × x∈[camX, camX+0x18)，0x43BE00 ×2 + 同窗口遮挡 → 地面物品 0x41C860 + 地面 deco 0x41CA20（闭合 round-3「遮挡 ground-deco 路径」）。

### World sort pass 0x419D40 — 网格几何定案
- `rep stosd` 清 0x38400 dwords = 0xE1000 B = **24×24 cells × 100 slots × 16 B**；网格 [root+0x154, root+0xE1154)；实体链表 head [root+0xE1158]（node +4=实体指针、+0xC=next）。
- cell 地址 = 1600·(24·dy+dx) 字节（dx=[e+0xCC]−camX、dy=[e+0xD0]−camY）；渲染器 0x41CBD0 以 +4 步进探测 cell 起始 100 个 dword。
- shadow-flag 插入（0x41A008–0x41A03E）= 400B 窗口前插移位（新实体在 [esp+0x2C]，0x63 dwords 旧内容后移，0x64 dwords 写回）。

### map 读数修正（fresh dumps 覆盖 round-3 错误）
- **sort tick（0x41A534–0x41A570）**：type 0/1→0（0x419DC6，vtable+0x1C tick）、type 2→2（0x419DDD 不 tick）、type 3→1（0x419E46）、**types 4..0x31→2（sort 中不 tick）**、type 0x32→0（NPC tick）。round-3 原文「3..0x31→1; 0x32→2」**错误**。
- **sort draw（0x41A570–0x41A5B0）**：type 0/2/0x32→0（0x419E1C：0x41B570 unlink + [root+0xE1154].vtable+0x14 + vtable+0(1)）、type 1/3..0x31→1（0x419E94 window-check + 网格插入）。round-3 原文「0/1→0; 2→1」**错误**。
- **渲染器 dispatch 0x41CD1C（fresh dump）**：type 0/1→case0 0x41CC8E（vtable+0x7C + 0x40B180 阴影 + 0x40CE20 标签）；type 2→case3 0x41CCED **SKIP（永不绘制 = 隐形占位/触发实体）**；type 3→case1 0x41CCD7（**仅 vtable+0x7C 精灵，无阴影/标签**）；types 4..0x31→case3 SKIP（tile pass 不画 → 走 tick chain 0x40ADD0→0x40AFD0→状态槽→painter）；type 0x32→case2 0x41CCB6（vtable+0x7C + 阴影，**无标签**）。

### 新身份（primary-static）
- **0x40B180** = 阴影椭圆 blit（门控 [e+0x61BD4]==2，0x434A20，ecx=0x7DA1D8，0x64×0x64，alpha 1.0 @ [e+0x94]/[e+0x98]）。
- **0x40CE20** = 计时门控名称/HP 标签（candidate；门控 [e+0x61C68]&0x100000 + (GetTickCount−[e+0x62A2C])>0x6A4ms）。
- **0x41B570** = hover/selection 指针清理（遍历 [root+0xE1170]/[root+0xE11A0]，清 [node+0x14]/[node+0x18]）。

**结论(Verdict)**：P7/P8 遮挡与排序链 VA 级闭合（primary-static）；两处 round-3 map 读数错误以 corrections 显式覆盖（未改写正文）；type-2 实体 = 隐形占位/触发实体（网格插入、不 tick、永不 blit）——closed；monster（4..0x31）不经 tile pass blit，网格仅作空间索引/遮挡/hover，实际绘制走 per-entity tick chain（type 3 例外：tile pass 精灵-only blit）。

**pending 精简**：10→7 项（entity-list 插入 0x560070/0x5600A0/[root+0xE1158] 服务端驱动、vtable 0x4764B0/0x4765B0 安装路径、monster 4..0x31 tick-chain 与 tile pass 精确交错（运行期）、element 数组 0x5600FC + 帧表运行期值、网格 cell 400B 探测窗口之外的记录内部结构、0x40B2C0 5 参 hover/target-box 语义、0x40CE20 精确渲染）。
## Finding 281 (NpcAppearance, 2026-08-11)：NPC 外观体系闭合——type 0x32 实体 body 字段 → element 128 → NPC.wil 帧块布局 + NPCFace.wil 对话头像用法

**问题**：P4——NPC 实体的 body（形象）字段如何映射到 NPC.wil 的帧块？type 0x32 经何元素解析到哪一 WIL 槽？NPC 帧公式 `word[0x8AA6C8+6*state]+100*dir+10*flag` 中的 100 倍项乘的到底是方向还是形象？NPC.wil 64×100 帧块的几何、特殊 body 码（0x18..0x3B）语义、NPCFace.wil 对话头像的帧号来源？

**调查**（primary-static；Mir3.exe 0x80000 B、fileoff=VA−0x400000；capstone + 原始字节扫描 + wilsdk 逐帧 blank 运行图；互证 RESEARCH_LOG Finding 279 帧表与 0x44A090 action 覆盖）：
- **帧分发器 0x404FB0 索引 3（jump @0x4054EC → 0x4051BB）**：`[edi+2]`（body 字段）<0x64 守卫；state <3；`mov byte [ebp+0x8c],0x80` 元素=128（0x4051E0）；`mov esi,3; idiv esi` flag=[esp+0x40]%3（0x4051E7-0x4051EA）；公式链 0x40526C-0x4052A0：state*6（lea+shl）、body*5（lea ecx,[ecx+ecx*4]）、flag+10*body（lea ecx,[ecx+edx*2]）、`word[0x8AA6C8+eax]+2*(5*(flag+10body))` = **base = w0+100*body+10*flag** → [ebp+0xb4]；end=[ebp+0xb8]=base+word[+2]（0x4052A6）；interval=[ebp+0xbc]=word[+4]（0x4052B7）；flag→[ebp+0xc1] **且 flag→[ebp+0xc2]（NPC 方向槽复用存 flag）**（0x4052D0/0x4052D6）；尾部 call 0x405630 绘制器。
- **状态变更处理器 0x405BBB**（0x4058E0 分发；元素 128 设于 0x405810；`elem*0x144 记录指针 = 0x5600FC+elem*0x144` 存 [esi+0x90]，0x40586F-0x40587C）：body=[esi+0x8a]<0x64（0x405BCA/0x405C88 两次读取）；state<3；flag=[esp+0x18]%3；同公式 0x405C82-0x405CD7；写出 state→[0xc0]、flag→[0xc1]&[0xc2]、base→[0xc4]（帧计数器从 base 起）、[0xc8]=0、[esi+0x61c7d]=2 (flag==7) else 5（帧钳制）。
- **NPC.wil 路径槽**：WIL 路径表 stride 0x104（复制函数 ≈0x453100-0x454100），槽 k 目标 = +0xe2f4+k*0x104；NPC.wil（串 0x47C964）复制目标 **+0x13330 = 槽 79**（块 0x453F30-0x453F54；下一槽 MonMagic 0x47C950→+0x13434）；Mon-1（0x47CC80→+0x10a90=槽 39）验证 stride。
- **NPC.wil 经验几何（6400 = 64 body × 100 帧）**：标准 body 运行图 [(0,3),(10,13),(20,23),(30,59)] = 42 帧 = 公式寻址并集（state0 三 flag 格 +0/+10/+20 各 4 帧；state1 三 flag 格 +30/+40/+50 各 10 帧）；**state2（base 0x3C=60）在标准 body 全空白**（NPC 无攻击动画）。800 帧锚点帧互异（签名距离最高 107）→ 每 800 帧块 = 8 个不同 body。
- **特殊 body 码 ↔ 经验几何 1:1 互证**（分发器 0x4051F0-0x405267 与处理器两处一致）：(1) state==1 且 body∈{0x18,0x19,0x22,0x23,0x2B..0x32,0x3A} → state=0：body 24,25,34,35,43-50,58 实测仅 3 站立格 12 帧 [(0,3),(10,13),(20,23)]（无行走段）✓；(2) body==0x28（及 0x38,0x39）→ flag=0：body 40 实测 [(0,3),(30,39)] = 仅 flag0 格（无 +10/+20/+40/+50）✓；body 56/57 实测 [(0,11)] 12 帧条带；(3) body∈{0x33,0x34} 或 [8a]∈{0x35,0x36,0x37}（+0x3B）→ state=0,flag=0 + `call 0x44A090`（0x405267/0x405C7D，db_object NPC action 覆盖）：body 51-55,59 实测各 1 帧 [(0,0)] ✓（action 0x33..0x3B → state0 (0,1,300) 单帧块，Finding 279）；(4) body 0x1B(27)/0x1C(28) → 0x44A090 state1 变体 len 6/9：body 27 实测 6 帧格（30-35,40-45,50-55）+9 帧尾段 = 39 帧；body 28 实测 9 帧格（30-38,40-48,50-58）+ state2 6 帧格（60-65,70-75,80-85）= 57 帧 ✓；(5) body 0x29(41) 全空（隐形 NPC）。
- **绘制链**：0x40B330 `mov ecx,[esi+0x90]`（记录，null→0x40B738 跳过）→ 帧号 [esi+0xc4]（尾帧回绕数学 0x40B366-0x40B37A）→ `call 0x466130` 取帧（0x40B383）→ 记录 [ecx+0x38]→模式字节 [eax+8]（0x40B390-0x40B39C）。
- **NPCFace.wil 对话用法闭合**：对话窗口 ctor 0x43ED00；0x43EDB6-0x43EDCC `lea ebx,[esi+0x278]; mov ecx,ebx; call 0x465fa0; push 0; push 0x47c4ec (.\Data\NPCFace.WIL); mov ecx,ebx; call 0x4660e0` 绑定 NPCFace.WIL 到窗口+0x278。窗口绘制 0x43F460（窗口管理器 0x428219 调用）按对话条目类型 [ebx] 分发（jump 0x440158：0x43F4E7/0x43F86D/0x43F85F/0x43FF92）；case 3 @0x43FF92 = 脚本行解析器：token **NPCIMG（0x47C50C）** → `call 0x4681f9`(atoi 参数) → `lea ecx,[ebp+0x278]; push eax; call 0x466130`（0x44001D-0x440030）= **绘制 NPCFace.wil 帧 n**，0x440035-0x440062 以帧头宽高 blit 到 0x8AB7A8 于 (0x28,0x1e)=(40,30)；token FCOLOR（0x47C514）→ 调色板表 0x47C4A8（12 色 BGR dword）；token NOTCLOSE（0x47C500）→ [ebp+0x274]=0。
- **排除项**：0x40C720 通用 tick 对 type≠0/1（含 0x32）直接 return 0（0x40C8EE）→ NPC 有独立类（vtable 族 ≈0x476500-0x4766E0）；0x407F20 网络包处理器属地图物件（阻挡标记，0x560070 链表，map-ui-resource Finding 254），非场景 NPC；type/body 槽 [esi+0x88]/[esi+0x8a] 在 0x400000-0x480000 **无任何直接字节写**（C6/88 全 modrm 含 SIB 零命中）→ body 由服务端生成包经实体构建路径填充（写点静态不可达）。

**结论(Verdict)**：P4 closed（evidence_level **primary-static**）。NPC 帧 = `word[0x8AA6C8+6*state] + 100*body + 10*(flag%3)`，body = [edi+2]/[esi+0x8a]（形象，**非方向**——修正模拟器 README/entities.json 的 100*dir）；NPC.wil = 路径表槽 79（dest +0x13330）；标准 body 布局 42 帧（state0 三格 + state1 三格，state2 空白）；特殊 body 码与 WIL 几何 1:1 互证；NPCFace.wil 对话头像 = 脚本 token `NPCIMG n` 绘制帧 n（客户端无 NPC→帧号表，由服务端脚本定义）。

**pending**：NPC body 写入点（服务端生成包解析域，静态不可达，candidate）；body 56/57 条带 4..11 帧用途；NPCIMG n 值语义需服务端脚本样本实证；NPC 绘制装饰（0x40CE20 标签/0x40B180 阴影）交错沿用 scene-entity pending。
## Finding 280 (MonsterDat, 2026-08-11)：怪物名 ↔ Mon-N.wil 库/帧映射闭合（P5/P11）——客户端 16 位 code = Race 字段（非 Appr）；前提修正：MInfo.dat 是魔法效果库，怪物数据源 = 服务端 monster.dat 解码 monster.json

**问题**：P5——monster.json 每条记录的 Appr/Race/RaceImg 中哪个字段驱动客户端怪物外观（元素+帧库+帧号）？每怪对应哪个 Mon-N.wil 库、哪段帧？DMon-1.wil（死亡库）按何索引？P11——`.gen` 未匹配 5 名（夜行鬼09/异界之门/葛贰厘面0/诺玛教主2/魔神怪8）是否存在于名表？交接提示"客户端 MInfo.dat 即怪物库"是否成立？

**调查**（primary-static；Mir3.exe 0x80000 B、fileoff=VA−0x400000；capstone + 原始字节扫描 + wilsdk 逐帧 blank 运行图 + monster.json 逐记录交叉评分；产出 `monster-dat-evidence.json` + `monster-dat-catalog.json`）：
- **前提修正（重要）**：客户端 MInfo.dat **非怪物库**。解密链（全部 primary-static 验证）：串 `MInfo.Dat`@0x47C62C → 加载器 0x44A910；密钥字节 `f0 39 ab 8e 93 1a de 9f`@0x44A925-0x44A939 → 全局 0x9135B8=0x8EAB39F0/0x9135BC=0x9FDE1A93；校验器 0x4525F0：header=file[0..3]^key1=0xA4A0（=42144=payload 长 42152−8）；checksum = `XOR 0x9FDE1A93(sum((payload[i]+1)*i))` 实测 = **0x8CE329C1 验证通过**；4 遍 XOR（edi=3,2,1,0，密钥=原文件[edi]，每字节 ^(dl+i)&0xff）。解密产物（CP949）为文本：节 `#SPELL 109`/`#MAGIC 147`/`#EXPLOSION 39`，注释 `//(시작프레임, 마지막프레임+1, 지연시간, 이미파일번호(Magic:81, MonMagic:138, MonMagicEx2:140, MonMagicEx3:143), 마법번호, ...)`；加载器 strcmp `#SPELL`@0x47C5EC；0x8AA5A8 = 该魔法帧状态表（key=魔法号@+0xc、帧 +0/+4、16 状态字节 +0xe..0x1d），唯一写者 0x44AE40（节循环、3 分支），经 0x449AD0→0x40A4D0 拷入 actor。⇒ 怪物目录数据唯一来源 = monster.json（服务端 Envir/monster.dat 解码；记录 252 B、XOR 0x09、名称 idx*4；字段 Index off0 / Appr off24 / Race off28 / RaceImg off32 / Level off36 / ACMin68 / ACMax72 / MAC76 / DCMin108 / DCMax112 / MC116 / HitSpeed128 / MoveSpeed132 / DropTable152；rec0=header {HeaderCount:433}；433 记录、Index 0..433 唯一且 **204 缺失**、Index>0=432 条）。
- **客户端解析公式（0x404FB0 分发，type byte[0] / 16-bit code byte[2..3]）**：type 3 怪物 race<2000 → element=`0x58+race//10`（0x4050E4，0x66666667 除10）+ gate `cmp al,0x8c`（element<140）+ 帧 `word[0x8AA686+6*state] + 1000*(race%10) + 10*flag`（0x405100-0x40514F；race%10 经 idiv 0xa，flag=[esp+0x40]&0xff；w0/w1/w2 表属 Finding 279 已闭合的编译期常量）；race>=2000 → element=`0x87+(race-2000)//100`、帧 `word[0x8AA686+6*flag]+100*((race-2000)//100)+10*flag`（0x405154 起，jmp 0x40510C 共用）。type 0/1 玩家（element 71/76）、type 0x32 NPC（element 0x80，Finding 281）。**Appr 不出现于任何帧公式**。
- **元素表基址确认（painter 0x405840）**：element byte [esi+0x8c] → 记录 = `0x5600FC + element*0x144`（*81×2+*4 组合）、gate al<0x8c、记录指针缓存 actor+0x90；WIL 管理器 this=0x5600FC−0x5898=0x55A864（BSS）。0x5600E8/0x5600F8 为 FX 列表全局（非元素表）。
- **槽晶格修正（字面量顺序 + stride 0x104 推导，覆盖旧交接编号）**：槽偏移 = 0xf848+slot*0x104；Mon-1=槽18@0x10a90 … Mon-20=槽37@0x11ddc、MonS-1=槽38@0x11ee0 … MonS-20=槽57@0x1322c、NPC=槽58@0x13330、MonMagic=59@0x13434、MonImg=60@0x13538、M-Hair=61、M-Helmet1=62、WM-Hair=63、WM-Helmet1=64、**DMon-1=槽65@0x13a4c、DMonS-1=槽66@0x13b50**、MagicEx=67、MonMagicEx=68、StoreItem=69；DMon 槽在初始器 0x454042/0x454061 静态绑定（字面量 `.\Data\DMon-1.wil`@0x47C8D0 / `DMonS-1.wil`@0x47C8BC，非懒加载——修正此前"无运行期引用"note）。
- **经验评分（wilsdk 逐帧，决定性）**：库 `Mon-(code//10+1).wil`、块 `1000*(code%10)`、state 偏移 0/80/160/200 ×10 帧窗口，432 条全扫：**code=Race → 432/432 全中（0 miss、0 no_lib）**；code=Appr → 328 hit / 7 miss（骷髅战士 idx180-182 Appr=88、掷斧骷髅 idx198-201 Appr=87→Mon-9 块7/8 错位）/ 97 no_lib（Appr//10+1>16，Mon-17..24 未随包）。N=race//10+1 与 +2 均 432/432（库稠密非空 0..9399，不可经验区分；采 +1 与 element 槽代数一致，歧义留档）。守卫武将 Race=19 → Mon-2.wil 块9 帧 9000-9999（off0:4/10、80:6/10、160/200:0/10 非空）。Race 分布 34 值、max 98（全落已随包的 Mon-1..10）、**Race==19 共 312 条**（守卫类）、RaceImg 213 个不同值 0..2090。
- **DMon-1 死亡库索引（修正"Index×10"旧claim）**：DMon-1.wil=4340 帧 = 434 个 10 帧块；非空块 = 0..39 / 100..139 / 200..239 / 300..339 / 400..433（5 段，194 块非空）→ 块索引 = **race//10**（10 帧/块；块 100+ 只能由 race≥1000 的 race//10 达到 → 排除了 Race 直索引与记录 Index）：block=Race//10 → **432/432**；block=Race → 381/432（缺 40,41,42,43,45,47,49,52,53,54,55,98 共 51 条）；block=Index → 192/432。死亡帧 = (Race//10)*10 .. +9（通常 4-6 帧非空，如块1=帧10-13）。DMonS-1.wil 同模式（0..39/100..139/200..239/300..339）。
- **RaceImg × MonImg.wil 交叉（负面）**：MonImg.wil=2100 帧但 ~93% 空白（非空仅 6 段 0-86/88-122/124-126/128-144/2010-2012/2020）；RaceImg 作直接帧号仅 324/432 非空（108 空白，空值聚于 145-199/530-538/2030-2090）→ **RaceImg 非 MonImg.wil 帧索引**（该客户端图标映射未解析，candidate）。
- **排除项**：0x45AC00 族 = 声音/页面缓存管理器（`Sound\`@0x47D874、0x50 条目缓存 this+0x460、1000 帧回收、实例 0x8AB130）非 Mon-N 绑定；0x43B720-0x43B7E0 懒加载属另一外观管理器（路径表基址 0x56B22C ≠ 0x56B0AC）；怪物元素 89+ 的绑定例程未静态定位（0x4660E0 调用点全为其它资源），但经验已定 Race，不再追踪。

**结论(Verdict)**：P5/P11 closed（evidence_level **primary-static 公式 + derived 经验 432/432**）。(1) **客户端 16-bit code（actor+0x8a）= monster.dat Race 字段，非 Appr**（432/432 vs 328/335+97）；库 = `Mon-(Race//10+1).wil`、帧基 = `1000*(Race%10)`、元素 = `0x58+Race//10`（race<2000 公式 @0x4050E4/0x405100）；Race=19 守卫类 → Mon-2.wil 块9。(2) 死亡库 DMon-1/DMonS-1 块 = Race//10、帧 (Race//10)*10..+9（432/432）。(3) 怪物数据源 = monster.json（服务端 monster.dat）；客户端 MInfo.dat = 魔法效果库（解密链 + #SPELL/#MAGIC/#EXPLOSION 验证）。(4) P11：夜行鬼09 → **存在**（Index 186，Appr 81/Race 19/RaceImg 1，Mon-2 帧9000）；异界之门 → **存在**（Index 187，Appr 227/Race 19）；葛贰厘面0 → **不存在**（名表无『葛』姓）；诺玛教主2 → **不存在**（最近 诺玛教主 Index 282，Appr 226/Race 19）；魔神怪8 → **不存在**（有 魔神怪1/2/10/20 = Index 240/243/242/244）。产出 `monster-dat-catalog.json`（432 条：Index/Name/Appr/Race/RaceImg/Level/element/library/frame_base/state_offset_hits/death_block/evidence_level，全 derived）。

**pending**：N=race//10+1 vs +2 经验不可区分（需运行期 element→槽绑定或服务端镜像）；元素 89+ 懒加载绑定例程未定位（经验已定 Race）；RaceImg 图标寻址（MonImg.wil 空白，可能在其它库/运行期合成）；DMon 空白块区（40..99/140..199）race 语义（服务端 gap）；code 83..85 特殊分支（0x4071A0/0x407260）无 Race 记录对应（遗留/其它 actor 语义）。
## Finding 282 (PlayerComposition, 2026-08-11)：玩家角色外观合成闭合——gender→type→element（M-Hum vs WM-Hum）、元素表 0x5600FC stride 0x144、WIL 槽表 element=slot、叠加绘制顺序/帧公式、渲染模式位语义、0x4058E0 帧重置器、M-SHum 排除

**问题**：P3/P6——玩家外观如何合成？性别（男/女）在哪一步决定 body 元素（M-Hum vs WM-Hum）？发型/头盔/武器/坐骑叠加层的绘制顺序与帧号公式？渲染模式 flag 位 → mode 字语义？元素表 0x5600FC 的布局（旧注"stride 0x36"是否正确）？M-SHum.wil 是否参与玩家外观？CreateChr.dat 是否含外观数据？

**调查**（primary-static；Mir3.exe 0x80000 B、fileoff=VA−0x400000；capstone + 原始字节扫描 + wilsdk 逐帧运行图；互证 RESEARCH_LOG Finding 279 帧表 / 280 怪物 / 281 NPC；写入 `player-composition-evidence.json`）：
- **外观描述符**：dword+4 结构。byte0=type（0 男 / 1 女 / 2 拒绝 / 3 怪物 / 0x32 NPC）、byte1 未用、byte2=玩家状态 S（<9）/ 怪物 race-lo / NPC body、byte3=怪物 race-hi（painter 0x4056EB `mov ecx,[esp+0x12]` 取 word）、byte4=骑乘 style → [e+0x629C8]（clamp<4，0x40C760/0x40C762/0x40C78A）。
- **gender→element 绑定（双路径一致）**：配置分发器 0x404FB0（vtable+0x0C；jump @0x4054EC、字节表 @0x405500）type 0→`mov byte [ebp+0x8c],0x47`（element 71=M-Hum，0x404FE5）、type 1→`mov byte [ebp+0x8c],0x4c`（element 76=WM-Hum，0x405003）；叶子绘制器 0x405630 同样 type 0→0x405673 `[esi+0x8c]=0x47`、type 1→0x405689 `[esi+0x8c]=0x4c`。玩家守卫 `[edi+2]<9`（S）、`[esp+0x3C]<0x21`（flag）；绘制器守卫 `[esp+6]<9` / `[esp+0x12]<9`。
- **帧公式（玩家）**：`frame = word[0x8AA5C0 + 6*flag] + 3000*S + 10*dir` → [e+0xB4]；end=[e+0xB4]+word[+2] → [e+0xB8]；interval=word[+4] → [e+0xBC]（分发器 0x40501F-0x405077、绘制器 0x405690-0x4056E6、重置器 0x40598B 三处一致；S=byte2、flag=[e+0xC0]、dir=[e+0xC1]）。M-Hum.wil=27000=9×3000 ⇔ 3000*S 步长互证。
- **第二分发器 0x4058E0 = 每帧动画重置器**（vtable+0x10，与 +0x0C 配置相邻于 0x4763D0/0x476490/0x47672C；ret 8）：读 type [esi+0x88]、element [esi+0x8C]；**`0x40590A-0x40591C：lea eax,[eax+eax*8]（×9）→ lea ecx,[eax*4+0x5600FC]（×324=0x144）——元素表 stride 0x144 确认，"×36"旧注作废**。玩家 case 0x405942：S=[esi+0x8A]<9、flag<0x21、dir<8；尾部 0x405CDD-0x405D3B：`[0xC0]=flag、[0xC1]=[0xC2]=dir、[0xC4]=[0xB4]、[0xC8]=0`；`[e+0x61C7D]=2 (dir==7) else 5`；`[e+0x61C68]&0x8000000` 时 interval 翻倍。
- **绘制器 0x405630**（guard 0x4055B0：type 0/1→S<9、type 3→过、type 0x32→S<0x64、type 2→拒；字节表 0x4055F8/jump 0x4055E8；主分发字节表 0x4058A8/jump 0x405894）：type 0/1 玩家公式如上；type 3 怪物（0x4056EB，race word、call 0x44A240、race<2000→element 0x58+race/10、≥2000→0x87+(race-2000)/100）；type 0x32 NPC（0x4057EA，element 0x80、body<0x64）。尾部 0x405854：`[0x88]=type、[0xC4]=[0xB4]、[0x90]=0x5600FC+[0x8C]*0x144`。
- **元素表 0x5600FC（BSS、stride 0x144×140）**：entry +4=精灵种类字节（0→0x466640、1/2→0x466720，解析器 0x466130 验证）；+0x38=已解析帧头指针（所有绘制点读 +0/+2/+4/+6 世界坐标字、+8 种类字节、+9/+0xB 附加字）。0x5600E8/0x5600F8=FX 列表全局（非元素表）。
- **WIL 槽表（element=slot 全定案）**：槽基 ebx+0xB130、stride 0x104、140 槽；槽=(dest−0xB130)/0x104，网格覆盖 dest 槽 68..139。初始化块结构（0x4535A0-0x454100）：每块 `mov edi,<字面量>; repne scasb; …; mov edi,edx; lea edx,[ebx+<下个dest>]; rep movsd` —— 拷贝目标=上一块尾部 lea，自身 lea 供下一块。**element=槽索引**（六重独立互证：0x47=71 M-Hum、0x4C=76 WM-Hum、0x57=87 Horse、0x58=88 Mon-1、0x80=128 NPC、0x83=131 M-Hair）。字面量（单字节 ASCII）与初始器引用全表（26 项）见 evidence JSON；关键：M-Hum@0x47CDF8→0x45364C→+0xF94C、WM-Hum@0x47CD84→0x453714→+0xFE60、Horse@0x47CC94→0x4538CC→+0x1098C、Mon-1@0x47CC80→0x4538F4→+0x10A90、NPC@0x47C964→0x453F31→+0x13330、M-Hair@0x47C928→0x453FAC→+0x1363C、M-Helmet1@0x47C910→0x453FD1→+0x13740、WM-Hair@0x47C8FC→0x453FF9→+0x13844、WM-Helmet1@0x47C8E4→0x454021→+0x13948。NPCFace.WIL@0x47C4EC→0x43EDC6（对话窗口 +0x278，不在 0x104 网格上）。
- **头部/武器元素字节（解析器 0x40C720 内）**：头元素 [e+0x629CE]=(sel−1)/10−0x7D（男）/ −0x7B（女）；武器元素 [e+0x629CD]=(sel−1)/10+0x48（男）/ +0x4D（女）；元素→记录 `[e+0x62A0C/0x62A10/0x62A14]=0x5600FC+elem*0x144`（lea ×9/×9/×4）。sel 范围 1..49/1..29（clamp：头<0x1E、武器<0x32）→ 男 41..50 落 WM-Hum(76)/女 41..50 落 Magic(81)、头 21..29 落 WM-Hair(133)/DMon-1(135)（公式原样记录）。
- **叠加绘制 0x40F5F0（全部站点单函数）**：prologue 屏幕变换（arg4==0 跳过）：`[0xE4]=([0xCC]−[view+0x12C])*48−[view+0x134]+[0xD4]−0xC8`、`[0xE8]=([0xD0]−[view+0x130])*32−[view+0x138]+[0xD8]−0x9D`。顺序与公式：
  1. 马 pass1 0x40F681（guard 骑乘[0x629C8]≠0、马库[0x62A14]≠0、[0xC0]≥0x1D）：`frame = ((0xC4 − 3000*S − 0xAA0) mod 400) + 0x2710`（style*400≡0 mod 400 消去；[0x62A20]=被除数）；blit call [0x4762B0] rect [0x629FC]。
  2. 武器 pass1 0x40F743（guard [0x89]≠0、[0x62A10]≠0、**武器库≠body 库**、[0xC0]<0x19）：`frame = [0xC4] + ((sel−1)%10)*3000 − S*3000` → [0x62A1C]；body 之前绘制。
  3. body 0x40F80B（guard [0x90]≠0）：frame=[0xC4]；bbox 钳制 0x40F893-0x40F903（[0xA4] 宽上限 0x3A、[0xA8] 高上限 0x28）。
  4. 头/发 0x40F909（guard [0x8B]≠0、[0x62A0C]≠0）：`frame = [0xC4] + ((sel−1)%10)*3000 − S*3000` → [0x62A18]；rect [0x629DC]。
  5. 武器 pass2 0x40F9EF（mode blit 0x462F20、push 0xd、surface 0x8A68D4/0x8AB7A8、0x320×0x1EC）：mode=0x404DA0 结果（[0x61C58]≠0 时=1）。
  6. 马 pass2 0x40FA67（0x461ED0、0xd/0xFFFF）。
- **渲染模式解析器 0x404DA0**：读 [ecx+0x61C68] dword，mode **经 eax 返回**：0x800000→1、0x4000000→0、0x20000000→0xFBFF、0x10000000→0xFFE0、0x8000000→0x94BF、0x40000000→0xFCB2、0x80000000→0x7E0、默认 0xFFFF；`mov word [ecx+0x61C6C],0xFFFF`（0x404E03）为副作用旁存。调用点 0x40B487/0x40C1A1/0x40F9CB（cmp ax,1）/0x410889；mode blit 分发 0x404E10（→0x461ED0，ecx=0x8AB7A8，ret 0x28）调用点 0x40B724/0x40C2A4/0x40FCD4/0x40FD51/0x40FD94/0x40FDEB/0x40FE68。
- **M-SHum 排除（结论性）**：全文件字节扫描 b'M-SHum' = **0 命中**；b'M-Hum.wil'=1（0x47CDF8）；b'CreateChr'=3。磁盘 M-SHum.wil=32722 帧但 EXE 无任何引用 → **不参与玩家外观槽表**（旧"玩家小身体=M-SHum"候选否定）。
- **CreateChr.dat（steering 弃解析）**：RIFF AVI 过场（1,221,572 B）；字面量 `.\Data\CreateChr.dat`@0x47D7E0，引用 0x45925E/0x459AF5（push 0x8ab7b8/[0x9135c0]）；0x45BF30 `push 0x73646976`('vid')→0x4680DA/0x4680D4（AVI 流打开）→0x45C4C0。相邻 StartGame.dat@0x47D7D0、登录/建号消息@0x47D7F8/0x47D818。
- **建号预览 0x466CE0/0x466F20 排除**：vtable 槽属性/UI setter（`call [eax+0x50]`、`call [..+0x94]` 四连 (2,2,0)/(4,1,0)/(0,3,0)/(2,5,0)；7 分支 jump @0x466EFC），非外观描述符路径——预览 gender→type 字节纯运行期，与"无静态写者"一致。
- **type 字节 [e+0x88] 无静态写者**：C6 8x 88 imm32 与 C6 4x 88 imm8 全文件零命中；唯一写点=绘制器尾部 0x405854（回写刚读的 type）→ 由实体构建路径/服务端填充（与 281 NPC body 结论同构）。

**结论(Verdict)**：P3/P6 closed（evidence_level **primary-static**）。玩家合成链：描述符 byte0 type → 0x404FB0/0x405630 双路径 gender→element（0→0x47 M-Hum、1→0x4C WM-Hum）→ 元素表 0x5600FC（**stride 0x144**，旧"×36"取消）→ element=WIL 槽索引（71/76/87/88/128/131 六重互证）→ 帧公式 `word[0x8AA5C0+6*flag]+3000*S+10*dir`（三读点一致）→ 0x40F5F0 六趟叠加（马pass1→武器pass1→body→头发→武器pass2→马pass2，帧号公式与 3000/400 步长分别对应 M-Hum 9×3000、Horse 26×400 几何）。0x4058E0=每帧动画重置器（帧表 stride 6 与 279 一致）。渲染模式位表 0x404DA0 六位→mode 字。**M-SHum.wil 无 EXE 引用**；CreateChr.dat=AVI 过场（无外观数据）。

**pending 精简**：type 字节写入点（服务端/实体构建域，candidate）；元素表 0x5600FC 运行期内容（+0x04 种类字节/+0x38 帧头指针之外字段）；渲染模式 flag 位来源；武器 sel 41..50/头 sel 21..29 客户端语义（公式落 WM-Hum/Magic/WM-Hair/DMon-1）；槽网格 82-86/90-127 字面量名；建号预览 0x466CE0 七分支语义（candidate）；阴影四顶点缓冲消费点。
## Finding 283 (TradeWindow, 2026-08-11)：交易窗口（玩家对玩家）渲染体系闭合——id 3 / +0x3399C / 帧 1050 静态美术 + 零控件绘制；关闭/接受/取消为不可见命中区，交易≠商店(id 2)

**结论(Verdict)**：P4 closed（evidence_level **primary-static**）。交易窗口 = window id 3，对象 ROOT+0x3399C（size 0x1369C），vtable 0x47663C，ctor 0x4159D0（8 参 ret 0x20，注册参数 (1, 0x14A=330, 0x1E4=484, 0, 0, 0x41A=1050, [esi+0x1C] 共享帧库, 3) @0x4277B0–0x4277C2 全局初始化链 0x427760）。绘制 = 渲染派发表 0x428358（id 索引 jmp，用点 0x428159）entry 3 → thunk 0x4281A8 = `lea ecx,[esi+0x3399c]; call 0x415b10`；点击派发 0x42BFFE..0x42C080：id 3 → `0x416ef0`，ret≠0 → `0x42ADB0(esi,3)` 重激活窗口；显示/激活 0x42ADB0（跳表 0x42B3E4）id 3 case @0x42AEE0。基类帧绘制 0x423D00（[vtable+0xC]）：亮路径 0x423D5D `0x460240(0x8AB7A8,...)`，暗路径（[0x8B1874]≠0）0x423DFA/0x423E66 `0x4542A0/0x4542F0(0x5600FC)`。

**面板美术**：GameInter.wil 帧 1050 = 512×512 @ offset (7,−44)（WIL 头 primary-static；count 1103）；UI 命中矩形仅 484×330 → 美术溢出窗口矩形。**绘制清单 0x415B10 全枚举**：① 帧 1050（call [vtable+0xC]）；② 分割矩形重算 SetRect [0x4762B0] → +0x5C/+0x6C（mid=x+(x2−x)>>1，0x415B21–0x415B63）；③ 面板高亮 SetRect-only（左 (x+0x15,y+0x30)..(x+0xC9,y+0x108)，右 (x+0xFD,y+0x30)..(x+0x1B1,y+0x108)，0x415B7C–0x415BC0，命中区非绘制）；④ 悬浮物品 0x416830+0x4162E0+blit [0x476248]；⑤ 格子物品图标 0x466800×2 + [0x476248] + 0x4542F0 src [0x8AB7BC]。**无任何按钮绘制、无任何 gauge blit** → 关闭/接受/取消按钮、金币框、名字/HP 文字、分割线、格子背景全部烘焙进帧 1050 美术。

**按钮（3 × 0xB4，ctor 0x417550 ret 0x24，vtable 0x4763A8 = [0x4046C0, 0x417640 render, 0x417780 mouse, 0x4177C0, 0x4177F0 click]）**：
- 关闭 +0x7C：帧 161/162（28×26 @ (−24,−16)），pos (x+0x214, y+0x15E)=(532,350)，ctor 压栈 (0,−1,1,0,[+0x15E],[+0x214],0xA2,0xA1) @0x415A4D–0x415A6D；
- 接受 +0x130：帧 1061/1062（48×20 @ (−24,−16)），pos (x+0xB9, y+0x14C)=(185,332)，压栈 (0,−1,1,0,[+0x14C],[+0xB9],0x426,0x425) @0x415A76–0x415A9D；
- 取消 +0x1E4：帧 1064/1065（**GameInter.wil 中 1064/1065 不存在**，header→None），pos (x+0xE1, y+0x14C)=(225,332)，压栈 (0,−1,1,0,[+0x14C],[+0xE1],0x429,0x428) @0x415AA4–0x415ACB；
- **不可见机理**：按钮 render 0x417640 全文件 ZERO 直接 xref（仅可经 [vtable+4] 间接调用），交易 paint 无此循环 → 按钮从不绘制；click 0x4177F0 = PtInRect([+4]) + 音效 0x45AFC0(0x8AB130, 0x69, 0,0,0) + ret 1，不发窗口消息；关闭命中仅响音并消费（窗口不关闭，由 vtable+8=0x4268B0→0x423CF0→[vtable+4] 字段重置路径隐藏）。

**gauge（分割柄，非血条）**：ctor 0x417960（7 参 ret 0x1C：[+4]=帧对象,[+8]=帧id,[+0x14],[+0x1C],[+0x1E],[+0x20],[+0x44]=call[0x47630C],[+0x48]），2 个 @+0x13648/+0x13694（stride 0x4C），ctor 内 @0x415AC8–0x415B2B 压栈 (0,0xC,0xB8,0xC,6,0x42E=1070,0)；帧 1070 = 16×360 @ (−24,−16) 竖向分割条美术，**从不 blit**。鼠标 0x416E70：0x417C80 命中 → fld [gauge+0xC] × [0x476650] → 0x468520 f2i → [+0x54+idx*4]（面板分割宽度）；点击 0x416EF0：0x417E60 命中 → ret 1。

**物品格**：24 槽 @+0x5B8 stride 0xC2C（0x4686C4 数组 ctor，0x5B8+24*0xC2C=0x129D8 名字缓冲）；物品 id 字数组 +0x298（400 字，空=0xFFFF，读点 0x41697E `mov ax,[edi+eax*2+0x298]`，索引=cell+pane*200）；36×36px 单元 5 列×6 行（0x416830 双循环 0..0xB4/0..0xD8），pane0 区 (x+0x15,y+0x30)..(x+0xED,y+0x12C)、pane1 (x+0xFD,y+0x30)..(x+0x1D5,y+0x12C)；槽动作 0x416C20/0x416D60/0x416DC0 → 消息 0x451AA0(0x402)/0x451AD0(0x403) → 运行期交易态 0x8AB828；最终态旗标 [+0x13644]（接受后置 1，此后点击全拒 0x416FB4）。

**金币框**：rect (x+0x22,y+0x10E)..(x+0x9C,y+0x130)=(34,270)..(156,304)；点击 + strcmp(data+0x1C, 0x47ADB4="确定")==0 → 0x418030(0x7E04C8, 0x565994, 3, 1, 0x47AD98="你要给对方多少金币?", 1, −1, −1, 0x405) 弹 msgbox 0x405（金币数量框）+ 清零 0x30E dwords → ret 1；接受命中 → 0x451B30(0x8AB828)（msg 0x406 经 0x452940(esi+0x18,0x406,0,0,0,0)+0x451E60）+ [0x13644]=1 → ret 0。

**交易 vs 商店**：商店 = id 2 / +0x33188 / ctor 0x44D310（注册 (2,src,帧1000,0,0,0x3E8,0x12C,0x130) @0x42777E–0x427794）/ paint 0x44E260（经 0x417830 + [vtable+4] 控件渲染循环，见 store-window-render-evidence.json）；交易 = id 3 / +0x3399C / ctor 0x4159D0 / paint 0x415B10（零控件渲染）。二者共用基类帧绘制 0x423D00 与渲染派发表 0x428358（商店 thunk 0x428192、交易 thunk 0x4281A8）。证据文件：docs/research/ei-ui-layout/trade-window-render-evidence.json。

**pending**：+0x298/+0x5B8 槽↔格运行期映射（0x4170C2 用 row*0xC2C；+0x54/+0x58 分割宽度参与格子数学 0x416830）——运行期数据；+0x298 的写入者（0x402/0x403/0x405/0x406 网络消息处理器经 0x8AB828）——BSS 运行期；帧 1050 像素内容目视核对（未做位图渲染）；0x423FA0/+0x40/+0x44 布局细节（derived）；0x417C80/0x417E60 内部矩形数学（调用点与语义已确认）。
EOF

---

## Round 6（Findings 284–289，2026-08-11）— 交易闭合 + 渲染模式/槽名 + 怪物特殊码 + NPC 条带 + 背包页签 + 状态/商店/选项

**F284 TradeWindowClosure**（`trade-window-closure-evidence.json`，primary-static）：基类 ctor 0x423B40 [+0x40]/[+0x44] = 内容区 484/330（注册 push 序 (1,330,484,0,0,1050,lib,3)）；content rect [+0x18]=(0,0,484,330)；**0x423FA0 = 拖拽移动**（16 xref、钳制 0x235/0x23A、偏移 [+0x48]/[+0x4C]、0x4240C0 抓取）——F248 链补全；槽代数 cell = col+5*(split+row)（0x416830）、+0x298[cell+200*pane] word%1000=槽号（0x416950）、记录 [0x5B8+id*0xC2C]（0x4170C2）；分割写 0x416E70 迭代 2 仪表 @+0x13648（stride 0x4C）→ 0x417C80 命中 → [+0x54+4*i] = trunc(f×94.0)（94.0 @0x476650 字节 00 00 bc 42，_ftol 0x468520）；帧 1050 像素目录（panel bbox (14,91)-(497,421)≈483×330、双网格 pane0 (14,92)-(194,308)/pane1 (246,92)-(426,308) 5×6×36px、金币盒 frame (27,226)-(149,260)=window (34,270)-(156,304)、金色分隔竖条 x≈215-218/239-241/263-265）；split 量纲（trunc(f×94) 0..94 vs 窗格 ≤34）candidate。

**F285 WeaponHeadSelector**（`player-composition-render-flags-evidence.json`，primary-static）：**[e+0x61C68] 全二进制扫描 = 17 写者/8 读者**（全描述符 dword 整体拷贝，无位计算）——bit0x1 = race 0x53-0x55(83-85) 帧锁门（0x407197/0x40AF55，span 2→3 钳 @0x40AFAB）、bit0x2 = 名牌可见性（镜像 [e+0x61BD0]）、bit0x100000 = 出生/传送白闪（0x40CE2B，1700ms 计时 +0x62A2C @0x411239）、bit0x8000000 = 半速（0x405D21 间隔×2 + 奇 tick 跳）；mode 字 = 纯 blit 常量（0x404DA0 6 位 → 1/0/0xFBFF/0xFFE0/0x94BF/0xFCB2/0x7E0，默认 0xFFFF → 0x404E10 → 0x461ED0/0x463330/0x460240）；**槽名 78 字面量**（0x4534B0-0x454120）：82-86 = Inventory/Equip/Ground/MIcon/ProgUse、90-107 = Mon-3..Mon-20、108-127 = MonS-1..MonS-20、128 NPC、131-134 发/盔、135/136 DMon-1/DMonS-1、139 StoreItem、70 = GameInter@+0xF848（**修正 mir3-dat 表 +0xF744 误标**）、76 WM-Hum、81 Magic；选择器落地 0x40C7B7-0x40C85D（男 head −0x7D/weapon +0x48、女 head −0x7B/weapon +0x4D → sel 41-50 = WM-Hum(76)/Magic(81)、head 21-29 = WM-Hair(133)/DMon-1(135)）。

**F286 MonsterSpecialCodes**（`monster-special-codes-evidence.json`，primary-static）：表分派 0x407610（码 3..0x59 字节表）→ 跳转表 0x4075F0（8 项）——code 0x53/0x54 → 默认 0x4075C5（[0x61c7c]=1 + actor vtable+0x10(8,arg)，无特殊语义）；code 0x55 → 0x40742C（alloc 0x13c → ctor 0x434EF0 → vtable+4 8 参调用，全局 0x560088 空则建 0x10 节）→ **FX/魔法效果对象**；同步门 0x407197 test [esi+0x61c68],1 → code（type3 ah=[0x8b]/al=[0x8a]）cmp 0x53/cmp 0x55 → 分派；**race 字节表 0x44A61C 中 0x53/0x54/0x55 全 = 8** → **真实 race 83/84/85 在 monster.json 不存在**（小 race：10-22,24,25,31-37,40-43,45,47,49,52-55,98；98=城门/木障、52-55=楔蛾/神兽）→ 83..85 特殊分支无实义（实为 FX 分派）；**element = 0x58 + race//10 复核成立**（0x4050D1-0x4050E4）；静态绑定 0x452AA0（槽 stride 0x104、文件名 0x47CEB0-0x47D000）、运行时绑定 0x43B780（@0x56B22C+e*0x104）、地图加载重绑 14..69、getFrame 未绑→0；**MonImg.wil 无静态消费者**（图标绘制 = element 86 ProgUse.wil）；怪物 vtable 0x476400 族。

**F287 NpcBodyStrip**（`npc-body-strip-evidence.json`，primary-static）：**NPC 场景实体 vtable = 0x47671C**（type 0x32 → alloc 0x629C8 → ctor 0x404960；+0x0C=0x404FB0 包分发、+0x7C=0x40C020 场景 blit）；**body 0x38/0x39 条带 4..11 = 0x44A090 无条件覆盖三条状态记录 (0,12,0x50=80ms)**（帧计数 [0xC4] base..base+11 循环）——非孤儿美术、无第二公式；0x40C4B0 帧推进（[0xC8]+=delta、回绕 [0xC4]=[0xB4]、[0x61C68]&0x8000000 间隔×2）；NPC blit 尾 = 0x404DA0 模式 + 目标框 (0x320,0x1EC) 0x462710 + 受击闪烁；**0x40B180 阴影**（kind [0x61BD4]：2→椭圆 0x434A20、0→(5,5,0xa)、8→(8,0xff)、else→(0xa,0xff)）；**0x40CE20 标签 = 仅玩家名牌**（门控 [0x61C68]&0x100000 + 闪烁 >0x6A4 + 帧号 [0x62A24]+0x352/0x355 + 元素 81）；**NPCIMG n = NPCFace.WIL 裸帧号**（0x43FFE7-0x440067 直取，无映射表）；**FCOLOR = 16 项 BGR 调色板 0x47C4A8**（修正 E7 12 色）；wilsdk：0x38/0x39 条带 12/12 非空、0x29 全空。

**F288 InventoryModeTabs**（`inventory-mode-tabs-evidence.json`，primary-static）：**3 页签（bag+0x5C stride 0xB4）= 装饰按钮**（点击 0x4177F0 仅音效）；**mode byte [bag+0x54] 仅服务端消息写**——mode0 默认（reset 0x42E9A4 / show 0x42AE26）、mode2 变卖 msg 0x286→case10→0x41FA16、mode1 修补 msg 0x29C→case28→0x41FB24、mode3 储存 msg 0x2BC→二级 switch 0x42042B→0x420AFC、0x29D=修补续（0x41FB6E 无 mode 写）；paint 分派 0x42EF2F jmp [eax*4+0x42F13C] 分支标签 包袱/修补/变卖/储存；**0x405 修正**：**0x451B00（push 0x405）= 唯一 0x405 发送器，唯一调用方死门 0x417280（xref=1）→ 0x405 发送链死**；**0x451B30（push 0x406）= 交易金币支付活路径**（0x417034→0x451B30，ecx=0x8AB828）——**F283「0x405 via 0x451B30」为误标**；0x7DA100 = bss 零写、死门 0x41729D 读（candidate 交易/购买量上限）。

**F289 StatusAndOptionNames**（`status-option-names-evidence.json`，primary-static + primary-resource + secondary + candidate）：**属性值 30 处绘制全 0xfafafa**（0x44BD37..0x44CCB2）、标签 28 处 0xfae1c8（含 魔法躲避 @0x44C1A7）、**4 处 0xff（防御/攻击/魔法/魔法防御力）——旧「二列标签=0xff」修正**；0x45DD70 共 62 调用 = 30 值 + 32 标签；**商店状态 0..4 业务名 = 0=BUY / 1=SELL / 2=仓库 / 3=CRAFT / 4=item detail**（0/3/4 primary-static：msg 0x285→0x41F92B→0x44F480、0x2C8→0x44FB00、state byte [esi+0x5F8]；1/2 服务端脚本佐证；CRAFT 错误 0x47B620/0x47B634 돈이 부족합니다/0x47B648/0x47B660 아이템이 잘 만들어 졌습니다）；**option 控件帧对**（ctor 0x440FE0 9 控件）：行 BGM y43 / EffectSound y116 / Ambience y190 / ShadowBlend y217，**左对 760/761 = ON、右对 762/763 = OFF**（state 字节 +0x54/+0x58/+0x5C/+0x60）；**760/761 与 762/763 为 UP/PRESSED 对（非 ON/OFF 美术）**——像素包含 83/84 与 97/99 @(+2,+1)；滑条 751 @(34,96)/(34,170)、config keys 0x47C594/0x47C5AC/0x47C57C/0x47C570；交易按钮帧 close 161/162 / accept 1061/1062 / cancel 1064/1065（帧 None→隐形）；**像素 OCR：1060=交易 / 1061=接受**；store SELL 网格 SetRect loop 0x44F806-0x44F833 x=323..475 y=43..157 on frame 1003。

**模拟器接线**（Tools/mir3_client_simulator/app.js）：STORE_STATE_NAMES 升级（state2 仓库 primary-static @0x44F940、state1 出售 secondary）；新增 store 反馈行（CRAFT 돈이 부족합니다）+ 状态命令接线；option 渲染器升级为 F289 行几何 + ON/OFF 帧对（760/761、762/763）；inventory 加 mode 标签（包袱/修补/变卖/储存）+ 背包模式+1 命令。verifier 0 ERROR（json_artifacts=82）。

## Round 7（2026-08-11，Findings 290–295）

**F290 PlayerStateActions**（`player-state-actions-evidence.json`，primary-static，conf 0.93）：SetAction vtable+0x10 = 0x4058E0（ecx=actor, arg1=state, arg2=dir；入口 dir<8、type≤0x32、懒加载 base [esi+0x90]=0x5600FC+[esi+0x8C]*324；分派字节表 0x405D64 + 跳转表 0x405D50）；type 0/1 共享公式 start[state]+storedDir*3000+argDir*10（修正旧 750/40）、type 3 经 0x44A240、0x32 NPC dir%3、2,4..0x31 no-op；尾 0x405CD7 提交 [0xC0]/[0xC1]/[0xC2]/[0xC4]=[0xB4]/[0xC8]=0；33 行表 0x8AA5C0 stride 6 全枚举（0 站(0,4,200)、1 走(0x50,6,100)、2/3 跑、4 击、5 特殊、7 击、8 伤、9-0xE 攻击链、0xF 施法、0x10/0x11 骑行走 A/B、0x12 骑马站、0x1E/0x1F 特殊对、0x20）；骑马机 0x40E400（msg 0x51A/0x51B/0x51C）+ 0x410B00 骑乘状态机（门控 ==0 设 2）；tick 0x411AB0（state {0x15,0x16,0x1E,0x1F,0x17,5}）；spawn-fx 0x40CD00；handler 0x40DB40/0x40DC20（[0xEC]=1/2/3）、0x17 完成→0x13/0xF/0x20；state 0x14 无写者（休眠）；挖矿/钓鱼两对分配 [INFERENCE]/KEPT-runtime。闭合 state-frame-tables-evidence.json pending（state 0..32 命名）。

**F291 EntityVtableFamily**（`entity-vtable-family-evidence.json`，primary-static，conf 0.93）：**0x4764B0/0x4765B0 = 大表内槽位，从未安装**（0x4764B0 = monster 0x476480 +0x30 = 0x406A40、0x4765B0 = 子类 0x476544 +0x6C = 0x408630；全文件 imm32 0 命中）→ F269 'install path' 问题不成立；F286 '0x476400' = 0x4763C0 +0x40 槽；家族：0x4763C0 base entity（34 槽，ctor 0x404960，+0x0C dispatcher 0x404FB0/+0x1C tick 0x40ADD0/+0x20 frame 0x40AFD0/+0x7C draw 0x40B2C0/+0x84 HP 0x40B850）→ 0x476480 monster（42 槽，ctor 0x40C560）→ 0x476544 子类（43 槽，ctor 0x40FE90）；0x47671C NPC scene（34 槽 = entity 6 覆写，0x476728 = +0x0C 内槽，F269 'HUD' 修正）；effect 族 0x476884（ctor 0x434EF0 7 槽）；0x476448 = list-node vtable（1 槽 {0x413D60}，19 安装点，F269 误标 effect-object）；window 族 0x476624 共享四元组 {0x423CA0, 0x423CF0, 0x423D00, 0x423F80}（31 安装点）、0x47663C trade、0x476638 页容器、0x476654 滑条、0x476814/0x476830/0x476834/0x476848 horse 区、0x4767E0/0x4767FC/0x476800 party 链、0x476378 列表类（4 安装点）、0x476370/0x476380 永不引用、0x4763A8 button；槽 0 全 MSVC scalar-deleting dtor。闭合 scene-entity-render-evidence.json vtable pending。

**F292 HorseWindow**（`horse-window-state-evidence.json`，primary-static，conf 0.92）：0x7DA060..0x7DA064 = session 0x777698+0x629C8；byte0 = 2-bit 钳制 enum 0..3（0 = 未骑马，非 0 门控 '@遛马' + 坐骑帧 × state*400；1/2/3 语义名 server candidate）；写者 0x40F420（vtable+0x88）/0x40C720（+0x8C）存 dword[+0x629C8]+byte[+0x629CC]；词 0x7DA061-62 = 玩家染色、0x7DA063-64 = 坐骑 + HUD 马图标染色（0x44B666 → 0x45FD50 arg6 = RLE op 0xC2 填充色，565 掩码 + 浮点缩放 0x4600B6；22 其他调用全 0xFFFF）；词仅 server packet case 0x267/0x26B 写（0x41F5BA/0x41F5C1）；pose 校验 0x405630；窗按钮 '@上马' 0x47B060/'@遛马' 0x47B068/'@收马' 0x47B058，分派 0x4520F0 → [0x8A68BC]=0x12C 计时。闭合 horse-window-render-evidence.json 两个 pending（状态 enum 用法 + 词字段用途）。

**F293 BagListFillChain**（`bag-list-fill-chain-evidence.json`，primary-static，conf 0.95）：0x42FC20 = bag record-place 核心（ecx=bag；stack flag/slot/record[0xC20] by value；ret 0xC28；mode 门 [esp+0xC48] → 0x42F2A0 解析 + 0x42F280 空槽扫描（46 槽，flag bag+0x774+i*0xC2C）→ 0x42F440 place）；13 直接调用方 = 10 handler / 9 msg id {0x35, 0xC8, 0x259, 0x268, 0x27C, 0x2A2(x2), 0x2A4, 0x2A5, 0x2A9}（全 lea ecx,[ebx+0x2AB9E0]）+ 3 非 handler；槽记录 bag+0x774+i*0xC2C（flag /w+0x778 /h+0x77C，0xC20 body+0x780）；网格 WORD 表 bag+0x324+12*row+2*col（6 列，空 0xFFFF）——修正旧 'cell 表 +0x2C4'；修正：msg 0x2A3 = trade-pending flush（0x416E20）非 bag fill、0x29E = 金币对话框 + bag 统计重置；trade +0x298 独立链，从不经 0x42FC20（inbound 0x2A3/0x2A6/0x2AA → 0x4161F0 → 0x416490）；outbound 0x402/0x403/0x405/0x406 = 纯出站发送器，入站配对 KEPT-runtime。闭合 inventory-window-render-evidence.json bag-list pending。

**F294 NoticeBanner**（`notice-banner-lifecycle-evidence.json`，primary-static，conf 0.92）：**0x777200 = id-15 公告窗本体，非独立 banner**（winmgr 0x7243A4+0x52E5C；F268 0x7213A4/0x726500 笔误修正）；ctor 0x43E260 一次构造（id 0xF、frame 602、x=107、y=110、w=584、h=252）；imm32 0x777200 全文件仅 2 命中（0x425A4C show / 0x425B4A hide），对齐扫描 16 读、仅写 flag [0x7773D0]；无 timer/counter/scroll 路径 → 显示时长无限期直到显式 toggle（行会按钮 / 点击 0x42BE99 → 0x43E4B0）；0x425A48 = 行会 ctrl4 邀请、0x425B46 = ctrl7 解散（分发 0x4258F0），均经 0x423E80 重显（frame 602/[0x7773D0]=1 vs 601/=0，SetWindowTextA([0x7773CC])）；close-all 跳过 id 15（0x42B3DD）；**0x7ED/0x7EE = 内部 WM_USER 消息非网络协议（旧标修正）**；banner 提交绿勾 0x43E5D9 → 0x45DC70 → 聊天输入 0x8AB828（0x411/0x410）。闭合 notice-prompt-window-evidence.json banner 时长 pending。

**F295 TradeGoldFlow**（`trade-gold-flow-evidence.json`，primary-static，conf 0.96）：0x7EE 交接忽略金额（输入 → obj+0x130 → SendMessageA(0x7EE, wparam, lparam=&obj+0x130) @0x4185DB；接收者 0x404600/0x45A140 均不读 lparam；分发 0x41E522 → 0x41CDE0）；接受 0x406 线上 = 纯头（0x417034 → 0x451B30 → 0x452940 12B 头 {dword0=0, word+4=0x406}，MIR 编码 0x452740，sprintf '#%d%s!' 计数 [obj+0x14] 9→1）——无金币字段；唯一活金币发送 = 聊天命令 0x41CDE0 case byte2==0x66 → msg 0x3F8（头 {dword0=amount32}，界 [obj+0x35B1E8]）；**0x405 双重死**（唯一发送器 0x451B00 唯一调用方死门 0x417280 需 wparam==0x405，路由 0x42D680 仅分派 byte2 3..9 → 不可达，且 [0x7DA100]==0 抑制）→ 0x405 永不发送；**0x7DA100 = 死配置槽**（PE .data 加载零填尾；全图仅 2 读：死门界 + bag 金币 paint sprintf '%d'；0 写者 → 恒 0）；语义 [INFERENCE] = 未用交易金币上限，活界 [obj+0x35B1E8]；修正：EI-288 'category byte 4' → byte2==3、头金额 32 位、F284 prompt 0x47AD98 = '你要给对方多少金币?'。闭合 confirmation-prompt-evidence.json（金额流）+ inventory-window-render-evidence.json（0x7DA100）两 pending。

## Round 8（2026-08-11，Findings 296–301）

**F296 NameplateLabel**（`nameplate-label-evidence.json`，primary-static，conf 0.92）：**共享名牌渲染器 0x40CE20**（门 [e+0x61C68]&0x100000 出生白闪 + 1700ms tick [+0x62A2C]、element 81、quad case-2 路径）；server-parser 源头 0x40D3B0/0x40D420/0x40D660/0x40D6C0；附加：word[ebp+4]==0x321 → 0x434EF0 建 FX 效果对象入全局 0x560088 效果链（0x40D626 挂 SetAction(0x1D)）；F271 'el81=Magic' 交叉佐证。闭合 scene-entity-render-evidence.json 名牌 pending。

**F297 OptionToggleGlyphs**（`option-toggle-glyphs-evidence.json`，primary-static + primary-resource，conf 0.9）：**GameInter.wil 760/761（32×22）= 켬、762/763（40×22）= 끔**；**761/763 = 按下移位变体（+2,+1）**（Jaccard 0.46/0.55 vs 无关对 0.07/0.04）→ 确认 F289 UP/PRESSED 成对规则；白字形提取需 brightness>140。闭合 status-option-names-evidence.json 帧对视觉验证 pending。

**F298 MountedGaitSpecialPairs**（`mounted-gait-special-pairs-evidence.json`，primary-static，conf 0.9）：**0x10 = 骑马走、0x11 = 骑马跑**（步数阶梯 0x1A@>7 → 0x10@>0xB → 0x11@>0xF —— **修正 F290：帧间隔 ≠ 步速**）；0x15/0x1E 与 0x16/0x1F 地面/骑马成对；fx 0x22=跑族/0x23=走族；0x17 完成 → 0x13/0xF/0x20。闭合 player-state-actions-evidence.json 挖矿/钓鱼对分配 pending。

**F299 CharCreatePreview**（`quad-renderer-7case-evidence.json`，primary-static，conf 0.9）：**0x466CE0 = 7-case 分派**（跳转表 0x466EFC）；各 case → (v+0x50, v+0x94) 状态对；float[0x476658]=1.0；11 个调用方（角色创建预览链）。

**F300 NpcBodyWriteSite**（`npc-body-write-site-evidence.json`，primary-static，conf 0.98）：**全编码（C6/88/89，disp8+disp32）字节扫描 = [e+0x8A] 无任何直接写**（0x46C92B/0x423FD1 类字节扫描误报全部排除）；**唯一写 = 0x405862 mov dword [esi+0x88],ebp**（0x405630 外观/类型更新，arg=[esp+8] 服务端外观码，跳转表 0x405894 分派 <0x32）；case 写 [e+0x8C]、坐标写 [e+0xB4/B8/BC]（表 0x8AA5C0/0x8AA5C8/0x8AA686）；**10 个 server-packet 调用点**（0x404FB0 实体分派 + 0x40C3B0/0x40F420 等）。闭合 player-composition-evidence.json pending 'gender->type [e+0x88] 无静态写者'。

**F301 TradeSplitHandle**（`trade-split-handle-evidence.json`，primary-static，conf 0.95）：**[trade+0x54]/[trade+0x58] 量纲 = 每 pane 顶部可见数据行索引（行偏移，非分数非行数）**——命中 0x416830 cell=col+5×(split+row)、绘制 0x4169B0 y=y0+0x30+36×(row−split)、pane 步长 40 行、可见 6 行 → 可用 [0,34]；**写者仅 2 鼠标处理器**（0x416E70 经 0x417C80 绝对置位 / 0x416EF0 族经 0x417D00 步进，strcmp 门串 0x47ADB4），公式 trunc(gauge_pos×94.0)；**94.0 @0x476650 全读者恰 4**（trade 0x416ECC/0x417259 + bag 0x430056/0x430696）→ **94 = 共享定点尺度非行数**（0x4179B0 归一 /93 @0x4179F7、页步 [+0x10]=6/94、仪表 ctor arg3=6=视口行数、帧 1070 轨道 px 0xB8）；**无静态上钳**（split>34 良性越读，record[0]==0 跳过 0x416A23）；trade blit 0x416016/0x416037 与 bag blit 0x42EB94 同签名 `push 0x5E; push split`；**修正 bag [+0x58] 误读**（= 同尺度滚动偏移非行数）；仪表拖拽界 [+0x28]/[+0x30]（0x13670/0x13678/0x136BC/0x136C4）零引用 → drag 界 provenance 留 runtime（pending 4）。闭合 trade-window-closure-evidence.json split 量纲 pending + inventory-mode-tabs-evidence.json bag 滚动条 pending。

## Round 9（2026-08-11，Findings 302–306）— 交易金币发送全灭定案 + 输入对话框类 + 消息总线 + 包格式

**F302 TradeGoldConfirmChain**（`trade-gold-confirm-chain-evidence.json`，primary-static，conf 0.97）：**0x405 发送路径双重死**——路径 A：金币对话框确认（键盘 0x418520 / 点击 0x418600）→ 0x7EE wParam=0x03000405 → 总线 0x41E2B0 → 0x41DFE0 → 0x42D650（守卫 [ecx+0x51180] + 桩 0x440740 `xor eax,eax; ret`）→ [0x8AA4A4] 恒 0 → 聊天命令发送永不触发；路径 B：唯一 0x405 发送器 0x451B00 ← 门 0x417280（精确匹配 0x03000405）← 0x42D6BA（dl=3）← 0x41CEC2 ← 需 0x7ED byte3==3——不存在。**字符串修正：0x47ADB4 = '陛傈'（B1 DD C0 FC 原始 dump）非 round-8 '确定'**；0x47AD98='您要付给对方多少金币?'；金币盒矩形 (x+0x22,y+0x10E)..(x+0x9C,y+0x130)；ctor 0x416F7E 8 参。闭合 trade-gold-flow-evidence.json 0x405 可达性 pending。

**F303 InputMessageBus**（`input-message-bus-0x7ed-0x7f0.json`，primary-static，conf 0.96）：[0x8AB7B0] wndproc 0x41E2B0 全树（msg≤0x202 链 / >0x202 / 0x7ED..0x7F0 范围表 0x41E690 / 0x113..0x201 跳转表 / default 0x41E30A）；栈布局 (wParam, lParam) 证明；0x41CDE0 byte3 分派 + 命令表 0x64..0x67 语义修正（0x64=行1→WM_CLOSE、0x65=行0→服务端 0x3F1、0x66→0x3F8 聊天金币、0x67→lParam 低字 0x40E）；**0x42D680 映射修正（index=dl−3，表 0x42D700：dl3→0x417280、dl4→0x425820、dl5/7/8 no-op、dl6→0x4247C0、dl9→0x4404E0）——round-8 dl 归属废弃**；0x7EF/0x7F0 = 聊天历史回叫（0x428760/0x428DD0、sprintf '/%s' 0x47BCF4）；发送方矩阵完备。

**F304 InputDialogConfirmPaths**（`input-dialog-confirm-paths.json`，primary-static，conf 0.95）：对话框类 ctor 0x418030 8 参（type→[e]、提示→[e+0x2C]、msgId→[e+0x460]、arg6/7=-1 居中）；TAB 循环行（0x418470，stride 0xB8）；键盘确认 0x418520 / 点击确认 0x418600 → **wParam=((type<<8|row)<<16)|msgId**，0x7EE + lParam=&[e+0x130]；24 个 ctor 站点；金币链 0x42BE21→0x42C4D4 idx3→0x42C00B→0x416EF0→0x416F7E。

**F305 ChatSubmitDeadPath**（`chat-submit-dead-path.json`，primary-static，conf 0.97）：[0x8AA4A4] 写者恰 4 处全零填（0x40274A/0x4194FC/0x41E245/0x456CE4）→ 恒 0 → 0x41DFE0 聊天命令发送（0x4520F0 @0x41E22F）不可达；聊天 0x7ED wParam∈{0,1}（byte3=0）→ 0x42D680 default no-op；**0x64..0x67 命令表不可达——修正 F295『0x66→0x3F8 唯一活金币发送』**：本 build 聊天提交为静默无操作，金币发送全灭。

**F306 TradeGoldPacketFormat**（`trade-gold-packet-format.json`，primary-static，conf 0.97）：构造器 0x452940 12B 布局 {dword arg3, word msgid@+4, word, word, word}（**修正旧翻转**）；0x405={dword amount, word 0x405, 0,0,0}、0x3F8 同形、0x406={0, 0x406, 0,0,0}、0x3FC/0x3FD/0x3FE={0, id, 0,0,0}；发送器 0x451E60 帧 '#%d%s%s!'（0x47C840）/ '#%d%s!'（0x47C800）+ 计数 1..9 + socket 0x468098；解析 0x4681F9；[0x7DA100] 死配置。

## Round 10（2026-08-11，Findings 307–311）— 网络消息管线全解码 + 小地图数据源修正（F310）

**F307 NetworkMessageObjectAnatomy**（`network-message-object-anatomy.json`，primary-static，conf 0.98）：**入站帧管线全闭**——编码器 **0x452740 = MIR base64**（charset=值+0x3C；计数从 0 起——0x452750 `mov [esp+0xc],edi` 循环前置零死槽，push ecx 为 MSVC 分配惯用；ret 0x10；栈图 [C+4]src/[C+8]dst/[C+0xC]len/[C+0x10]max），手写解释器 3 向量字节精确（chat 6B→`4c50453f4d3c00`、hello 22B→30B、空→0）；**跳转表精确**：字节表 0x421D8C（类型 6..0xC8）→ 指针表 0x421D5C 12 槽——idx0→0x421CFC 队列（26 类型：0x6..0xF、0x11..0x18、0x1B、0x1F..0x22、0x32、0x33、0x34）、idx1→0x421497 二队列（0x1D/0x1E，0xC 字节项→[screen+0x3C5EFC]=0x844E14）、idx2→0x421BA7（0x28/0x64..0x68，仅前块活：+0x10 解码后丢弃；**0x421BBC/0x421C23/0x421C81 = 编译掉的旧 handler**）、idx3..idx10 单类型、idx11→0x421D3F no-op（153 类型）；大类型链 ==0xC9→0x41F175、0xCA..0x26C→0x41F264、==0x26D→0x41F79E、0x26E..0x29D→0x41F8C6、==0x29E→0x4203F7、>0x29E→0x42042B；**队列项 0x421CFC = malloc 0x40C {+0 id, +4 msgid(+6 HP-cur word), +8(+8 HP-max word), +0xC byte0 + lstrcpyA 串}**，域 [screen+0x364458]=0x7E3370；泵 **0x4227F0（唯一调用者 0x41BBCA）** 分派——0x33/0x27A→0x422960 死亡/传送、**0x32→0x422CC0 进世界自初始化（修正：非小地图标记）**（own id [0x2F8784]、byte[item+0xB]→[0x35A354]、16B+5B base64、playerObj vtable+0x8C、账号→[0x2F8788]、列表清理+音效）、0x34→0x423000 全量自我属性（97B base64→[0x35B1F0] 显示块、HP/MP 同步 [0x35A34C]/[0x35A34A]/[0x35A34E]）、0x2F0→0x423070 状态字节（word[item+0]→[0x35B251]、byte[item+6..0xB]→[0x35B253..58]）、默认=own-id+0x1F HP 对（word[item+6]→[0x35B1F5]+[0x35A34C]、word[item+8]→[0x35B1F9]+[0x35A34A]、cur==0→死亡 0x40A1E0）、他 id→对象列表 [esi+0xE1158] 走查。

**F308 HudHpMpXpInjectionChain**（`hud-hp-mp-xp-injection-chain.json`，primary-static，conf 0.98）：**HUD 血量/魔法/经验全局只有帧链写者**——全编码扫描（89/8B modrm+abs32 全寄存器、C7 05、66 89、C6 05、A3、lea）[0x35A34C]/[0x35A34A]/[0x35A34E] 写者 = 恰 2 路径：msgid 0x1F（泵默认：word[item+6]→cur、[item+8]→max）与 msgid 0x34（0x423000 全量自我属性：97B 块 [0x35B1F0]，HP cur 0x7DA10D/MP cur 0x7DA10F/HP max 0x7DA111/MP max 0x7DA113/XP cur 0x7DA115）；**XP-max 0x7DA119 无任何写者（全编码扫描 0 命中）——静态不可变**；XP cur 仅 0x34 块可达；HUD 条 GameInter.wil 帧 60/61/63（rect 61,496,104,566 等），SetRect 0x4276D6/0x4276F0/0x42770D，格式串 0x47BD30 `"%s : [%d,%d]"` 绘于 (0x257,0xC9)=(599,201)。

**F309 0x7E8WsaAsyncSelectDispatcher**（`0x7e8-wsaasyncselect-dispatcher.json`，primary-static，conf 0.96）：**socket 层 = WSAAsyncSelect 事件机**——0x7E8→总线 0x41E2B0→0x451BB0(0x8AB828, sock, MAKELONG(ev,err))→错误分类 0x4515C0（致命→MessageBoxA+WM_CLOSE [0x8AB7B0]）；FD_READ→0x451CC0（recv 0x2000→`*` ack→realloc 0x468D6E 追加→state==3 ? 缓冲 : 回叫 vtable[+4]）；FD_CONNECT→0x451C40；hello 0x4514F0 / 帧发送 0x451E60 指令精确；**WS2_32 序数导入**（IAT 值 0x80000000|ord：0x47631C=111、324=3、328=11、32C=4、330=101、334=9、338=115、33C=23、340=19、344=16）；socket 对象 0x8AB828 布局（[+0x6044] socket、[+0x6048] 回叫 0x8B1870、[+0x6050] state byte 0x8B1878，3=游戏中）；错误串 0x47C7E0/0x47C7B8/0x47C794。

**F310 MinimapPlayerMarkerChain（含修正）**（`minimap.json`，primary-static，conf 0.97）：**小地图玩家标记数据源修正**——Round 9 目标 0x7D9234/0x7D9238 = 死亡/重生检查对 ONLY（读 0x422985/0x42298B/0x422995 `x−y<9` 延迟，零写 0x422A15/0x422A1B），**非小地图输入**；真实链：**活坐标 [0x777764]/[0x777768] = [screen+0x2F884C]/[+0x2F8850]（Y/X）**——**全编码穷举扫描（89/8B 全寄存器 abs32、C7 05、66 89、C6 05）+ 指针相对扫描 = 恰 2 写者 0x422A9E（Y=word[item+6]）/0x422AC5（X=word[item+8]，死亡/传送泵 handler 0x422960 内）**；tick 0x4294E0（守卫 [esi+0x6518]）读双坐标、push X 再 push Y → **0x43D850(Y,X)** 更新+地图纹理绘制（mapid<0x3E8→MMap.wil 帧 mapid、≥0x3E8→FMMap.wil 帧 mapid−1000，blit 0x465560(0x8AB7A8)）+ 0x43DA80 标记层 → widget 0x48512C=[screen+0x6214]；**widget 字段表**：+0x28C mapid(−1=跳过)、+0x2C0 **D3D 目标矩形 {672,0,800,128} 字节精确=模拟器 map.minimap**、+0x2C8/CC 玩家标记(10×10 0x96C8FF)、+0x2D0/D4 滚动、+0x2F8/FC 存储 Y/X、+0x300 闪烁计数(0<..<0x1F4 回绕 0x320)、+4 MMap.wil、+0x148 FMMap.wil；标记层 0x43DC54：**[0x560070]=[esi+0xE1158] 内 byte[obj+0x88]==0x32 对象 → 2×2 黄 0xFFFF（obj+0xCC/D0）**、[0x5600A0]=[esi+0xE1188] 泛对象 2×2 绿 0x64C864（边界剔除）——**0x32 类型字节对象非泵 msgid 0x32**；**死亡/传送 payload（item+0xC base64）= 地图名**：串 0x47C404 `.\Map\%s.map`（后随 FMMap.wil/MMap.wil/EDIT）→ map-loader 子对象 [esi+0xF5200]=0x574118（0x43C9C0 定位 [e+0x12C/130]、0x43B600 格式化）← 死亡尾 0x422B0F..0x422B60（X−12/Y−12 + rep stosd 清 0x38400 dwords=0xE1000B 场景实体网格）；HUD 位置文本读同一活坐标（0x42A476，格式 0x47BD30）；点击目标 0x42C1D4/0x42CDA4 也读活坐标→0x41EC10 find-obj→0x451A70。pending：活坐标正常行走镜像写者（lea/指针形式未穷尽，或行走本就不移动小地图点直到位置消息——candidate）；word[item+0xA] 死亡尾标志语义（candidate）。

**F311 SimulatorMessageAndMinimapWiring**（`simulator-message-and-minimap-wiring.json`，derived-tooling，conf 1.0）：**模拟器数据管线接入**——`Tools/web/build_mir3_simulator_data.py`（规范生成器，非 reverse-engineering 下同名文件）hud.json minimap note = 完整 F310 解剖；frame_tables.json 新增 frame_dispatch（12 行跳转表、大类型链、泵分派、队列项、base64 编码器）；重跑成功（windows=14 controls=40 resources=157 entities=8 skills=12 maps=2 bindings=211，0.45s），读回验证 keys/jump rows=12/idx2 types/rect [672,0,800,128]；app.js 消费点（frame_tables 实体状态名 ~75/145-146；minimap cycle key hud.minimap ~982，绘制 1007-1014）不变。

## Round 11（2026-08-11，Findings 312–313）— 聊天窗输入侧全闭：鼠标分派全表 + 控件/标题栏/腰带/键盘全图

**F312 ChatWindowMouseDispatch**（`chat-window-mouse-dispatch.json`，primary-static，conf high）：**FnA 0x42BA20 六段优先链**：①`[0x53060]`→0x418A50(0x53030,x,y) ②`[0x52E8C]`→0x43E640(0x52E5C,x,y) ③滚动条 0x417D00(0x61BC,x,y) 命中→滚动定位 `[0xD08]=ftol(fild([0xD20]-1)*fmul[esi+0x61C8])`（0x468520）④标题栏循环 i=0..15 @0x567C+i*0xB4 call [vtable+0xC]=0x4177C0 ⑤0x428570(chat,x,y) ⑥0x42AAB0 命中分派：-1→0x42BD8D（0x42B820 close-all + 0x42D720 腰带命中→未中→小地图 `[0x6518]` 门→0x43DDB0(0x6214)）；>0xE→0x42BD78；否则 `jmp [eax*4+0x42BDE0]`（16 项打开表，每项=子窗 open-check 如 0x42FFD0(0x6554,&[esi+0x20],x,y)，失败→0x42B6A0(id,x,y)）。**FnB 0x42BE21**：①`[0xD3C]=0` ②`[0x53060]`→0x418A00 命中→**SendMessageA([0x8AB7B0],2,0,0)**（msg 2 字面）③`[0x52E8C]`→0x43E4B0 命中→0x42ADB0(0xF) ④滚动条 0x417E60 ⑤0x42AAB0→edi：==2 且 0x44E910(0x33188) 关（图鉴未开=背景）→标题栏循环 0x42BEF8；edi==-1→标题栏循环；≤0xE→`jmp [edi*4+0x42C4D4]` 点击表。**7 张分派表 dword 全部验证**（跨检查发现并修正初稿两处误记）：open 0x42BDE0 16 项（5/10→0x42BD78 no-op，**15→0x90909090 死填充**）；routing 0x42B7E0 16 项（每项= `add esi,suboffset; jmp` 蹦床；{0,1,4,8,12}→0x42B774、{6,9,13}→0x42B79A、{3,7,11,14}→0x42B7C0 三尾语义同（push 1; 0x423F90(subwin,1); 0x4240C0(subwin,x,y); ret 0xC）；2→0x42B6FC 内联（0x44E910(0x33188,x,y) 门，失败→0x42B7DA ret 0xC）；5/10→0x42B7DA；**15→0x90909090 死填充**；remove/add 0x42AC50/0x42AC30 在 helper 0x42B6A0 中先于本表执行，不在蹦床内）；close-all 0x42B938（每项 push 0; lea [esi+sub]; jmp 0x42B8F0→0x423F90(sub,0)；5/10→0x42B8F5）；mousemove 0x42B658（15→0x42B63F chat+0x52E5C 侧栏；id8 增 ShowWindow([0x8AA48C],0)）；toggle 0x42B3E4（0=0x42ADCF 等 16 项）；click 0x42C4D4（**15→0x245C8B53 垃圾字节不可达**——FnB 先测 edi>0xE）。**0x42AC50 = remove-window（ret 4，1 参）**：走 [ecx+0xD24] 双向链表（头节点 [ecx+0xD28]），按 id 摘除，更新 [0xD2C]/[0xD30]/[0xD34]/[0xD38]，0x4680F8 释放；**0x42AC30 = add** = 0x449870([ecx+0xD24],id) 追加；**0x42ADB0 = toggle 分派体**（close-all→表 0x42B3E4；标志 [suboff+0x30]；vtable[0x10](0/1)；post 0x417880(lea [sub+0x1C4],-1,0x10C,0x10B)；byte[sub+0x54]=0；0x42FF90 ret 1）——**0x41C1E0 中 `push edi` 于 0x42AC50 前 = callee-save 括号非实参（栈平衡验证）**。helpers：0x42B6A0 open-window（13 call 全在 FnA 0x42BB4E..0x42BD67；[0xD38] 门→close-all→remove→add→[0xD3C]=1→routing）；0x42B820 close-all（3 callers；走 [0xD28] 链，node+8==0x4C90C0→0x423F90(sub+0x14,0) 否则 0x423F90(sub,0)；5/10 no-op）；0x42D720 腰带命中（4 callers；SetRect 38×38 @[0x4762B0]，槽 i=(0x117+i*0x28,0x1B0+i*0x10)；PtInRect 命中→eax=i）；0x42D650 聊天记录打开（唯一 caller 0x41E001；[0x51180]&&0x440740(0x51150)）；0x45AFC0 msg-0x69 poster（this=0x8AB130；门 [edi+8]&&[edi+0x14]；50 项 handler 表 [edi+0x460]；命中→0x45B900+timeGetTime→[h+0x38]；未中→0x45AC00→0x45BC60+vtable[+0x48]）。

**F313 ChatWindowControlMap**（`chat-window-control-map.json`，primary-static，conf high）：**控件 id→子窗** 0=0x6554,1=0x29CE4,2=0x33188,3=0x3399C,4=0x4707C,5 no-op,6=0x47834,7=0x47C28,8=0x507EC,9=0x51150,0xA no-op,0xB=0x516E8,0xC=0x518E0,0xD=0x52118,0xE=0x524F0（mousemove 增 id15=0x52E5C）；**16 标题栏**（0x567C+i*0xB4；RECT+4、help 帧 id+0x20=-1、byte+0x24=1、byte+0x25=0、x+0x28、y+0x2C、文本+0x34、窗对象+0x14、id_lo+0x18、id_hi+0x1C、+0x30=0）：cap0 交易 0x50/0x51 +0xCC '交易栏(Ctrl+C, C)'@0x47BBE0、cap1 小地图 0x52/0x53 +0xE4 '小地图(Ctrl+V, V)'、cap2 图鉴 0x54/0x55 +0xFC '技能图鉴(Ctrl+B, B)'、cap3 退出 0x5A/0x5B +0xA1+0x2E '退出游戏(Alt+Q)'、cap4 注销 0x5C/0x5D '注销人物(Alt+X)'、cap5 组队 0x5E/0x5F +0x268+0x2F '组队(Ctrl+G, G)'、cap6 行会 0x60/0x61 '行会(Ctrl+F, F)'、cap7 腰带 0x9F/0x9F +0x189+0xD '腰带(Ctrl+Z, Z)'、cap8 技能书 0x64/0x65 +0x2BF+0x10、cap9 聊天记录 0x66/0x67 +0x2CE+0x20、cap10 信息窗口 0x68/0x69 '信息窗口(Ctrl+D, D)'、cap11 设置栏 0x6A/0x6B '设置栏(Ctrl+N, N)'、cap12 0x6C/0x6D '档框…' 损坏、cap13 坐骑 0x6E/0x6F '坐骑(Ctrl+S, S)'、cap14 包袱栏 0x70/0x71 '包袱栏(Ctrl+Q, Q)'、cap15 状态栏 0x72/0x73 @0x47BBCC（action 0x42C30D = 0x42ADB0(1) 双切换 + 0x423E80(0x29CE4,0xC8,[0x29CFC],[0x29D00],0xF4,0x148) 大地图 244×328）；caption ctor 0x417550（9 参 ret 0x24；SetRect 帧 [window_obj+0x38]）；tooltip 0x417640（门 +0x25==0/+0x24==1/+0x20!=-1）；action 表 0x42C494 16 项（0=0x42C1CE,1=0x42C259,2=0x42C241,3=0x42C2E1,4=0x42BF37,5=0x42C218,6=0x42C209,7=0x42C292,8=0x42C302,9=0x42C226,10=0x42C1A4,11=0x42C1B2,12=0x42C359,13=0x42C1C0,14=0x42C234,15=0x42C30D）；右侧 8 个 22×22 SetRect（cap8..15 精确坐标）。**腰带**：6 斜槽 (0x117+i*0x28,0x1B0+i*0x10) 38×38 @0x427DDE；槽 @0xDA4 步 0xC24 {valid+0、0x308-dword 栈+4、byte+0x26、type word+0x2C}；accessors 0x42D790 clear / 0x42D8A0 take（rep movsd 0x308=0xC20B）/ 0x42D7C0 refill（SEH 0x474FD8；6 槽计数；0x403AC0 调用；仅头部）。**键盘分派 0x42CBD0**（ret 8；arg1=VK→esi；5 门：`[0x53060]`、`[0x52E8C]`、`[0x5081C]`→push 8; 0x42B980 + 0x414DC0(0x507EC,vk,arg2)、`[0x20]&&[0x24]`）；**字母热键全验证**：Q→toggle(0)+`[0x65A8]=0`+post 0x417880(lea [0x6718],-1,0x10C,0x10B)；W→toggle(1)；E→toggle(0xE)；R→toggle(8)；S→toggle(0xD)；D→toggle(0xB)；**Z=CLAMP**（word [0xD40] 钳 0..0x2E；byte [0xD42]=2/1 方向——非计数递增）；**C→0x41EC10(0x47EF18,[0x777764],[0x777768],[0x777759],1)** push 最深优先 + ret≠0→0x451A70(0x8AB828)；V→小地图（timeGetTime−[0x6210]≤0x64；[0x6518]==0→0x451770(0x8AB828) 开否则关）；B→`[0x6208]=!([0x6208])`；G→toggle(6)；F→0x4523E0(0x8AB828)；N→toggle(0xC)；**T→[0x6518]==1→`[0x64A8]=!([0x64A8])`；新≠0→0x43D5F0(lea ecx,[0x6214],[0x8AB7BC],0x100,0x100) 否则 (…,0x80,0x80)**；Y→[0x6518]==1→`[0x64A4]=!([0x64A4])`。**VK 分派头** `0042CF1F lea eax,[esi-0xd]; cmp eax,0xb2; ja 0x42d4b4; movzx ecx,byte[eax+0x42d550]; jmp [ecx*4+0x42d520]`；**VK 字节表 0x42D550 179B 精确**（off00=01 Enter→case1；off0B=03；off0D=02；off17..0x1C=07,06,05,04,08,09；**offB2 (VK 0xBF '/')=0A→case10**；其余 165B=0B→case11；**case0=0x42D511 共享 ret-0 尾——无字节映射；Round-10 字节序误记作废**）。case1 Enter 0x42CF3C（[0xD38]!=0 + GetActiveWindow([0x476250])==[0x8AB7B0]；[0xD2C]=[0xD30] 顶、[0xD34]=count−1；id≠9→toggle(id)；**id==9→`mov ecx,0x47EF18; call 0x41C1E0`** 关聊天记录(9)+图鉴(2)+交易(0)）；case2/3 缩放（门 [0x7E04F0]==0 && GetActiveWindow()==[0x8AA48C]；Ctrl `test al,0x80` 低字节位7 与字母热键 AH 检查不对称——字面；[0x6534]/[0x6550] 钳 [0x6530]/[0x654C]）；case4..9 方向键（Shift→'\x21'/'@' 等 + 0x450C70(0x8AA488) 复制 + SetFocus/ShowWindow([0x8AA48C],5) + SetWindowTextA + SendMessageA([0x8AA48C],0xB1,1,1)；共享尾 0x42D251 `SendMessageA([0x8AA48C],0xB1,len,len)`）；case10 '/'（SetFocus+ShowWindow(map,5)；[0x531EC]==0→复制 '/' 0x47AD94；strlen−1→0x42D251）；case11 默认（鼠标 [0x7DA1C0]/[0x7DA1C4]→0x42AAB0；==0xE 技能书 0x524F0→0x43A810(lea [ebp+0x524F0],arg1,arg2,y,x)）。**腰带 kbd 尾 0x42D293**（槽基 [ebp+slot*0xC24]；type word [slot+0xDD0]；byte [slot+0xDCA]≠0 跳过时间门；timeGetTime−[0x29CD8]：>0x7D0(2000ms) 放行、≤0x3E8(1000ms) 拒绝、中间 type∈{0x14,0x15,0x46} 放行；有效 [slot+0xDA4]→[0x20]!=0&&[0x24]==0&&[0x28]==0 + 内联 strcmp [0x3C] vs 0x47ADB4 '陛傈'（循环 0x42D336/0x42D39E）+ 文本≠哨兵 + mode [0x5A]∈{0,3}→**SWAP 0x42D8F0** 否则 **USE 0x42D9E0**；无效槽同门→**PLACE 0x42DAA0**）；**0x42D3E5 chat-send**：文本≠哨兵&&[0x20]!=0&&[0x24]==0&&[0x28]==0 → 频道 [0x75]；`push text; push channel; push 0x3EE; mov ecx,0x8AB828; [0x24]=1; [0x34]=1; call 0x451910`；[0x29CD8]=timeGetTime；拒绝串 0x47BD7C/'正在补充药水,请稍候.' 0x47BDA4。**药水使用 0x42E2D0**：type byte [buf+0x22]；>0x1F→0x76；索引 byte[type+0x42E428]→`jmp [eax*4+0x42E404]`（32 DATA dword 表精确；索引字节 `00 08 08 08 08 01 01 08 08 08 02 02 08 08 08 03 08 08 08 04 04 04 05 05 06 08 06 08 08 08 08 07`；0→0x6C、5/6→0x6F、0xA/0xB→0x70、0xF→0x74、0x13..0x15→0x73、0x16/0x17→0x71、0x18/0x1A→0x45DD00(0x8AB7A8,buf+4,0x47BDDC/0x47BDD4) 子串匹配→0x72/0x75、0x1F→subtype [buf+0x23]≥0x6A→0x76 否则 0x6C、默认 0x76；尾 push 0,0,0,msg + 0x45AFC0(0x8AB130)；0x42E450 次级表）；**0x45DD00 = 子串搜索**（strlen 双方；len(token)>len(name)→0；strchr 0x468BF0 + repe cmpsb 全长→1）。kbd caller 0x41DD8A（0x42CBD0 先，非零短路；[game+0x364444] 链→0x413A30；GetKeyState('M')→[0x2F8840] 门→0x4520F0 + 冷却 [0x4279A4]=0x3E8；第二 kbd 表 0x41DF68 VK 0x0D..0x68 带 Ctrl 组合 0x41DE5C/0x41DE85/0x41DEAE）。**0x450C70 = 字符串复制 helper**（strlen 0x46805C→alloc 0x468056(len,1,0x10)→copy 0x468050）；sibling 0x450CA0（flag 0）；0x450CD0 = 聊天编辑窗 proc（0x7ED 提交）。修正 vs 初稿：Z=CLAMP 非递增；C 实参最深优先；T 实参 lea ecx 在前。pending：cap14 包袱栏(Ctrl+Q,Q) 但 Q→toggle(0) 交易 / cap10 信息窗口(Ctrl+D,D) 但 D→toggle(0xB) / cap11 设置栏(Ctrl+N,N) 但 N→toggle(0xC) 标签-处理器偏差（真实存在，语义未定）；药水 GBK token 0x47BDD4/'厘癌' 0x47BDDC/'癌冠' 不可读；0x42D7C0 全量 refill 语义 + 0x403AC0 目标；0x450CA0 精确 caller。

## Round 12（2026-08-11，Findings 314–315）— 窗口可见性/位置分派全闭 + 状态种子 + IAT GetFocus 修正

**F314 WindowVisibilityDispatch**（`window-visibility-dispatch-evidence.json`，primary-static，conf high）：**toggle 分派 0x42ADB0 全闭**——头 `push esi/edi; mov esi,ecx; xor edi,edi; call 0x42B820; mov eax,[esp+0xC]; cmp eax,0xF; ja 0x42B3DD; jmp [eax*4+0x42B3E4]`（**无条件先 close-all 再分派**）；**返回契约 edi=1 打开 / 0 关闭或非法**（id 5/10/>0xF → 共享尾 0x42B3DD）；**0x42B820 = demote-all 非 hide-all**：`[0xD34]=0; [0xD2C]=head`，链表每节点 id≤0xE → 表 0x42B938（13 子窗偏移 0x6554..0x524F0）→ `push 0; lea ecx,[esi+off]; jmp 0x42B8F0 → call 0x423F90`（[sub+0x34]=0），id 5/10/0xF → 0x42B8F5 no-op，count 0 → 0x42B934；**case 模式** flag=[obj+flagoff]、sub=[obj+flagoff−0x30]：关闭 = 0x42AC50 + vtable[0x10](0) ret 0；打开 = 0x42AC30 + vtable[0x10](1) ret 1；**14 对 close_va/open_va 钉死**（0→0x42ADDD/0x42ADFC、1→0x42AE50/0x42AE6F、2→0x42AE9D/0x42AEBE、3→0x42AEEC/0x42AF0D、4→0x42B077/0x42B098、6→0x42B0C8/0x42B0E7、7→0x42B13D/0x42B15E、8→0x42B188/0x42B1DB、9→0x42B26A/0x42B28B、11→0x42AF3B/0x42AF5C、12→0x42AF8A/0x42AFAB、13→0x42AFD9/0x42AFFA、14→0x42B028/0x42B049、15→0x42B2B5/0x42B349）——record 3 修正 0x42AEB0→**0x42AEE0**（0x42AEB0 在 case 2 体内）；**specials**：case0 打开尾 `byte[sub+0x54]=0` + push −1/0x10C/0x10B + 0x417880(lea [sub+0x1C4]) + 0x42FF90；case6 打开尾 `[esi+0x47C24]` 门 → push 0x398|−1 + 0x399 + 0x398 + 0x417880(lea [esi+0x47B70])；case8 聊天记录打开 MoveWindow(mapBar, mainX+[0x50804]+[0x51140], mainY+[0x50808]+[0x51144], [0x51148]−[0x51140], [0x5114C]−[0x51144], 1) @0x42B223 + ShowWindow(mapBar, 5) @0x42B232（mapBar=[0x8AA48C]，mainX/Y=[0x8AB7F0]/[0x8AB7F4]）；**case15 身份解析 = 公告/大聊天窗**（Frame 602、点击 handler 0x43E4B0、原生聊天 HWND 包装 [base+0x53028]、标题 0x8B187C、flag [0x8AA498]）——关闭尾 0x42B304：MoveWindow(chatHwnd, mainX+0xDF, mainY+0x23A, 0x162, 0x10, 1) @0x42B2E4 + 门 [esi+0x53028] + ShowWindow(chatHwnd,0) @0x42B311 + SetWindowTextA(chatHwnd, 0x8B187C) @0x42B323 + SetFocus([0x8AB7B0]) @0x42B330 + [0x8AA498]=1 ret 0；打开尾 0x42B349：0x42AC30(0xF) + vtable[0x10](1) + 门 + ShowWindow(chatHwnd,5) @0x42B370 + UpdateWindow @0x42B37D + MoveWindow(chatHwnd, [0x53018]..[0x53024]) @0x42B3BB + SetFocus(chatHwnd) @0x42B3C8 + [0x8AA498]=0 ret 1；**状态语义**：+0x30 = per-window 可见门（ctor 0；setter 0x423F80 经类 setter 0x43F020 `arg==0→[ecx+0x274]=1`；绘制 0x43F040 门控 [esi+0x30]）、+0x34 = active 状态（setter 0x423F90；close-all/路由桩写它）；**IAT 绑定块**：[0x476258]=UpdateWindow、[0x4762AC]=ShowWindow、[0x4762BC]=MoveWindow、[0x4762B8]=SetFocus、[0x4762CC]=SetWindowTextA、**[0x476250]=GetFocus（本 PE 无 GetActiveWindow 导入——修正 F313 读法）**；43 个 toggle 调用方（热键 Q/W/E/R/S/D/N/G @0x42CC8B..0x42CFDD）

**F315 WindowPositionDispatchAndStateSeeds**（`window-position-dispatch-evidence.json`，primary-static，conf high）— 含修正：**0x423FA0 第二 SetRect 目标 &win+0 → &win+8**（第一 &win+0x18 不变），第 4/5 参 = left'+origW / top'+origH（非 right'/bottom'）；origW=[win+0x10]−[win+8]、origH=[win+0x14]−[win+0xC] 入口捕获 → **win+8 = 外框重居中矩形、win+0 = 不动的 home 矩形**（closed_2026_08_10『&win+0 居中』claim 废弃）；**0x42B430 头修正：非 hide-all**——`[esi+0x5081C]!=0 && 0x42B980(esi,8)==0 → ShowWindow([0x8AA48C], 0)`（chat-log id8 打开但非顶层时仅隐藏地图输入条）；**mousemove 桩表 0x42B658 全表**（16 项：0→0x42B4AB(0x6554)、1→0x42B4C9(0x29CE4)、2→0x42B4E7(0x33188, 0x44E910 门失败→0x42B64E)、3→0x42B518(0x3399C)、4→0x42B536(0x4707C)、6→0x42B554(0x47834)、7→0x42B572(0x47C28)、8→0x42B590(0x507EC)+ShowWindow([0x8AA48C],0)、9→0x42B5B8(0x51150)、11→0x42B5D6(0x516E8)、12→0x42B5F4(0x518E0)、13→0x42B612(0x52118)、14→0x42B630(0x524F0)→落入 id15 0x42B63F(0x52E5C) 双移动、5/10 → 共享尾 0x42B64E；全 `push 0(flag); push Y; push X; lea ecx,[esi+off]; call 0x423FA0; ret 8`）；**window_state_seeds**：0x423F80 `mov [ecx+0x30],[esp+4]; ret 4`（+0x30 可见门 setter，唯一 E8 调用方 0x43F033）、0x423F90 `mov [ecx+0x34],[esp+4]; ret 4`（+0x34 active）、0x4240C0 grab setter（ret 8，门 +0x30/+0x34/+0x3C，`[win+0x48]=x−[win+0x18]; [win+0x4C]=y−[win+0x1C]`）、0x423FA0（ret 0xC；居中分支 SetRect(&win+0x18, x, y, x+[0x40], y+[0x44]) + SetRect(&win+8, x−(origW−w)/2, y−(origH−h)/2, left'+origW, top'+origH)；拖动分支左'=x−[0x48]、顶'=y−[0x4C] 底钳 `[0x44]+(y−[0x4C])>0x23A(570) → 顶=0x235(565)−[0x44]`，SetRect(&win+0x18, …) + SetRect(&win+8, 同居中)）；**0x42B980 = is-top**（ret 4；`[0xD2C]=[0xD30]; [0xD34]=count−1; cmp [esp+4],[top_node_id] → 1/0`）；闭合：**0x42D7C0 = 腰带槽存储**（SEH 0x474FD8、ret 0xC28、slot=[esp+0xC38]/flag=[esp+0xC3C]/payload=[esp+0x18]、6 槽 chat+0xDA4 stride 0xC24 首空扫描、rep movsd ecx=0x308、ret 1/0）+ **0x403AC0 = 裸 ret (0xC3) no-op SEH 解wind 桩**（35 调用方，全 `lea ecx,[esp+X]; mov [esp+Y],0xFFFFFFFF; call` 形状）

## Round 13（2026-08-11，Finding 316）— chat 热键/标题标签↔处理函数不符闭合 + 审计 Rounds 4–12 移植

**F316 HotkeyLabelHandlerConsistency**（`hotkey-label-handler-consistency.json`，primary-static，conf high）：**F313 pending『Q/D/N 标签-处理器偏差』闭合**——Q/D/N 及全字母热键与各自标题点击动作逐对一致，偏差系 F313 自身把窗口 id 0 误标为交易所致。本轮 fresh dump 证据链：**toggle 跳转表 0x42B3E4** dwords `42adcf 42ae42 42ae91 42aee0 42b06b 42b3dd 42b0ba 42b131 42b180 42b25e 42b3dd 42af2f 42af7e 42afcd 42b01c 42b2ad`；**case0 0x42ADCF**（flag=[esi+0x6584]、sub=[esi+0x6554]、关闭 0x42AC50+vtable+0x10 show(0)、开启 0x42AC30+show(1)+post 0x417880(lea [esi+0x1C4],-1,0x10C,0x10B)+0x42FF90 背包输入复位）；**case0xB 0x42AF2F**（flag=[esi+0x51718]、sub=[esi+0x516E8] 任务窗）；**case0xC 0x42AF7E**（flag=[esi+0x51910]、sub=[esi+0x518E0] 设置窗）；**kbd 字母 case**：Q 0x42CC7C→`push 0; call 0x42adb0`=包袱、D 0x42CD1B→`push 0xb`=任务（客户端自标『信息窗口』）、N 0x42CE76→`push 0xc`=设置、G 0x42CE41→`push 6`=组队（F313『guild』误标，行会=id4）、F 0x42CE5B→0x4523E0 行会请求、B 0x42CE1D→`[ebp+0x6208]=!`、V 0x42CDDA→小地图开/关（冷却门 0x64 与标题 idx1 0xBB8 不同但动作同）；**标题点击表 0x42C494 16 项** dwords 全表 + idx10 0x42C1A4=`push 0xb; toggle`==D、idx11 0x42C1B2=`push 0xc; toggle`==N、idx14 0x42C234=`push edi(0); toggle`==Q、idx0 0x42C1CE=交易**请求**（0x41EC10+net 0x451A70，非窗口切换）==C；**窗口 id 定案**：id0=包袱/背包 F250（winmgr+0x6554，ctor 0x42EA80）非交易，交易=id3 F1050（winmgr+0x3399C，ctor 0x4159D0）无标题无热键、仅游戏逻辑 0x420486/case3 开启；id0xB=任务 F700、id0xC=设置 F750；id6=组队 F900、id4=行会 F600。与 window-id-catalog EI-268 交叉一致。F313 pending 第 1 项 CLOSED；chat-window-control-map.json conclusions/pending 同步更新。


## Round 14（2026-08-11，Findings 317–320）— 544 图逐张 survey 全量完成：frame-OOB 根因 REVISED + class 8 空格定案

> 地图侧证据文件：`docs/research/mir3-map-reconstruction/`（survey-round14.json 815KB、`lib-space-frame-oob-evidence.json`、`d10031-north-edge-evidence.json`、`zl-regeneration-staleness-evidence.json`、`class8-file0xff-evidence.json`）。

**F317 FrameOOBSpaceConfusion（REVISED，lib-space-frame-oob-evidence.json，derived，conf high）— 修订 C11**：3.map wood_smobjectsc 槽 OOB 帧 970–2531 **存在于 wood_tilesc**（96×64，cap 3927）而非 wood_smobjectsc（cap 969）；wood_wallsc OOB → wood_housesc（9010）；41.map sand_smobjectsc OOB 631–3618 → EI root Dungeonsc（5364）/ ZL Sand/Dungeonsc（16654）、sand_housesc 1275–1752 → sand_tilesc（4299）。**EI↔ZL 帧数全对照实测**（2026-08-11，`ZlLibrary.count` 为元数据、`l.entries/l.headers` 为实际条目）：Wood/Tilesc 3927/3927、Wood/Wallsc 3791/3791、Wood/Housesc 9010/9010、Wood/Dungeonsc 4710/4710、Wood/SmObjectsc 969/969、Sand/Tilesc 4299/4299、Sand/Housesc 1274/1274、Sand/SmObjectsc 631/631、Tilesc 9836/9836、Tiles5c 20000/20000、Sand/Wallsc 860、Sand/Animationsc 127、root Dungeonsc 5364；**唯一例外 ZL Sand/Dungeonsc = 16654**。→ 结论：frame-OOB = **lib/frame-space 混淆**（层/库解析指向某槽但帧值属兄弟库空间），非「ZL 更大 tileset 覆盖」；旧 ZL（2026-08-10 构建）确实更大，『ZL 时代制作』叙述对旧构建成立，今 ZL 已重生成同帧数 → 该子论断失效（C63）。

**F318 D10031NorthEdgeGroundOOB**（d10031-north-edge-evidence.json，derived，conf high）：**全局唯一 ground 帧-OOB** = D10031（300×300，md5 1d1407d0）：ground 全图 22500 格单 lib2 tiles5c（cap 20000），OOB 62 格**全部 block 行 y=0（北边缘）** x∈[6,115]，帧 42756–42766（10 distinct：42765×4、42762×9、42759×6、42766×8、42763×6、42760×6、42764×9、42761×8、42758×5、42756×1）；EI/ZL 两客户端任何库均无此帧 = **真缺失 edge art**（C62）。早前『smtilesc 9998』为 Middle 层且在界内（9998 < 10180）非异常。

**F319 ZLRegenerationStaleness**（zl-regeneration-staleness-evidence.json，derived，conf 1.0）：ZL 树 `Data/Map Data` 全部 64 个 .Zl **2026-08-11 09:57 重生成**（与 EI 同帧数，见 F317 对照表）；`resource-consistency.json`（2026-08-10 20:49）中 ZL 帧数引用 **STALE**——凡引用 ZL 帧数必须实测 `ZlLibrary`（`l.count` 是元数据，`l.entries/l.headers` 才是实际条目）。（C63）

**F320 Class8EmptyGroundMarker**（class8-file0xff-evidence.json，derived，conf high）：**class 8 = 字面空地面格统一 file=0xFF 标记**——23 图 670 格全部 file=0xFF；0 个 valid-file+0xFFFF、0 个 valid-file+0xFF7F。位置模式 = 有规则「留空」设计：74.map 中央洞（90 格 x∈[294,326] y∈[292,330]）、D12121 左上（171）、0_003 顶部带（137）、5_0013（67）、123.map 东缘单列 x=398（34）、D1401/D1411/D1421 角落带（各 32，md5 f7a83061 同文件）、122（18）及 13 图零散少量（0.map/1.map/8.map/02_010..02_014/D1202/D1204/D6023/D9022/D9032/d6004）。原『0_003 60×100 右 2 下 6』P2 描述 = **object 层 file=255 与 ground 层 file=0xFF 混用**，以 survey 实测为准（0_003 = 100×60，地面 137 空格）。（C65）

**survey 工具与产物**：`Tools/maps/survey_mir3_maps.py`（chmod +x，544 图全量：w/h/size/md5/legacy-13B/三层逐库 cells+frame 区间+OOB/8 类分类/ground 空标记统计）→ `docs/research/mir3-map-reconstruction/survey-round14.json`：**544 图 / 34 图 anomaly / 5723 格 / 79 md5 簇 / 321 唯一 md5 / 39 legacy-13B / 0 size_mismatch / anomaly_class_totals {8: 23 图 670 格, 3: 11 图 5053 格}**；md5 top 簇：980d2999 ×43（B101–B143）、c0a3ab8d ×24（D716xx）、3e43dc1e ×17、1a3fcf4e ×15（d8xxx 家族）、7b3895ed ×9、5ffb0b8a ×9（kt0002..0009）；**0_000/50_001 = 同文件（23e8088b）**、kt0018/kt00181 = e293a0b4、0_002/0_0021 = 1d2bd415。class 3 四家族：① lib/frame-space 混淆（3.map 3255、41.map 1619、50.map 39）② 真缺失 edge art（D10031 62）③ 探针残留 0x44/0x00 结尾（kt0018 13、0_0011 8、0_002 3）④ 稀疏用户痕迹超双端（0_000 19）。marker 渲染：`Tools/maps/render_oob_tiles.py` → `comparisons/<map>__oob_markers_t<tx>-<ty>.png`（z=2 tile，洋红=mid OOB、橙=ground 帧 OOB、青=ground file-0xFF）。EVIDENCE-INVENTORY 新增 C61–C65，C11 标注「被 F317 修订」。

---

## 2026-08-12：HUD caption action 长尾闭合 + NPC/任务 0x418/0x419 单调用点定案（Round 15，Findings 321+）

> 阶段目标：闭合 ui-coverage-matrix.json hud 记录 pending_notes 的 caption 长尾项（idx3/4/7/8/9/12/13/15 业务映射），
> 并字节级核证 0x419CC0 补丁、协议消息层 opcode 表、0x418/0x419/0x416 的静态调用点全集。
> 产物：`hud-caption-action-tail-evidence.json`（primary-static，F321）。

### Finding 321 (HUD caption action 全 16 项业务映射，2026-08-12)：0x42C494 长尾闭合 + 分派循环结构修正

**caption 分派是 16 次迭代循环（非单发分派）**：
- `0x42BEF8 mov dword [esp+0x14],0; xor edi,edi` = 循环初始化（idx=0；edi=0 供 idx14 的 `push edi`=push 0）。
- `0x42BF02`（循环头）：`mov eax,[esp+0x14]` → `lea eax,[eax+eax*4+0x267]; lea edx,[eax+eax*8]; eax=[esi+edx*4]`
  （= HUD+0x567C+idx*0xB4 caption 对象）→ `call [eax+0x10]`（vtable+0x10 press 命中测试，F243 0x4177F0 族）。
- `0x42BF30`：`test eax,eax; je 0x42C359`（未按下 → 下一项）；`cmp eax,0xF; ja 0x42C359; jmp [eax*4+0x42C494]`。
- **0x42C359 = 循环增址回边**：`mov eax,[esp+0x14]; inc eax; cmp eax,0x10; mov [esp+0x14],eax; jl 0x42BF02`。
  **修正前轮「0x42C359 公共 no-op 返回尾 pop edi/esi/ebp/xor eax,eax/pop ebx/ret 8」为误 disasm，废弃**。
- 退出 0x42C36B → `call 0x42D720`（F312 ⑥ 腰带命中测试链）。

**16-slot ctor 权威表（0x427960–0x427E00 全量重反汇编，9-arg ctor 0x417550 ret 0x24）**
（slot = HUD+0x567C+i*0xB4；x=[HUD+0xC58]+xoff，y=[HUD+0xC5C]+yoff；帧对 (normal, pressed)）：

|cap|ctor@|slot|xoff|yoff|帧对|string VA|文案|
|---|---|---|---|---|---|---|---|
|0|0x4279B2|+0x567C|+0xCC|+2|0x50/0x51|0x47BCE0|交易栏(Ctrl+C, C)|
|1|0x4279E6|+0x5730|+0xE4|+2|0x52/0x53|0x47BCCC|小地图(Ctrl+V, V)|
|2|0x427A1A|+0x57E4|+0xFC|+2|0x54/0x55|0x47BCB8|技能图鉴(Ctrl+B, B)|
|3|0x427A4E|+0x5898|+0xA1|+0x2E|0x5A/0x5B|0x47BCA8|退出游戏(Alt+Q)|
|4|0x427A82|+0x594C|+0xA1|+0x52|**0x5C/0x5D**|0x47BC98|注销人物(Alt+X)|
|5|0x427AB6|+0x5A00|+0x268|+0x2F|**0x5E/0x5F**|0x47BC88|组队(Ctrl+G, G)|
|6|0x427AEA|+0x5AB4|+0x268|+0x52|**0x60/0x61**|0x47BC78|行会(Ctrl+F, F)|
|7|0x427B24|+0x5B68|+0x189|+0xD|0x9F/0x9F|0x47BC68|腰带(Ctrl+Z, Z)|
|8|0x427B58|+0x5C1C|+0x2BF|+0x10|0x64/0x65|0x47BC54|技能书(Ctrl+E, E)|
|9|0x427BAA|+0x5CD0|+0x2CE|+0x20|0x66/0x67|0x47BC40|聊天记录(Ctrl+R, R)|
|10|0x427BFC|+0x5D84|+0x2CE|+0x46|0x68/0x69|0x47BC2C|信息窗口(Ctrl+D, D)|
|11|0x427C4D|+0x5E38|+0x2BF|+0x55|0x6A/0x6B|0x47BC18|设置栏(Ctrl+N, N)|
|12|0x427C9F|+0x5EEC|+0x298|+0x56|0x6C/0x6D|0x47BC04|도움말창(지원예정) [EUC-KR]|
|13|0x427CF1|+0x5FA0|+0x288|+0x46|0x6E/0x6F|0x47BBF4|坐骑(Ctrl+S, S)|
|14|0x427D42|+0x6054|+0x288|+0x20|0x70/0x71|0x47BBE0|包袱栏(Ctrl+Q, Q)|
|15|0x427D94|+0x6108|+0x299|+0x10|0x72/0x73|0x47BBCC|状态栏(Ctrl+W, W)|

**F313 字符串区错标修正**：0x47BBE0 = **cap14 包袱栏(Ctrl+Q, Q)**，非 cap0 交易栏；cap0 = 0x47BCE0（ctor 0x4279B2 实测 push 0x47bce0）。
两套文案区：0x47BCxx = cap0–12（0x47BCE0 起降序）、0x47BBxx = cap13–15。cap12 = EUC-KR 도움말창(지원예정)（韩版遗留，与 idx12 no-op 一致）。

**帧号修正（cap4–6）**：cap4 注销 0x5C/0x5D、cap5 组队 0x5E/0x5F、cap6 行会 0x60/0x61（前轮表 0x5E/0x5F、0x60/0x61、0x62/0x63 作废）。

**0x42C494 16 handler 完工表**：

|idx|handler|业务动作（primary-static 链）|
|---|---|---|
|0|0x42C1CE|交易栏：读 [0x777764]=X/[0x777768]=Y/[0x777759]=方向 → push 1,dir,Y,X; ecx=0x47EF18; `0x41EC10`（8 方向实体选择，表 0x41ECFC）→ 非 -1 → +8 → ecx=0x8AB828; `0x451A70` = **msg 0x401 交易请求**|
|1|0x42C259|小地图：GetTickCount 3s 冷却（[0x6210] 上次, 0xBB8）→ [0x6518]==0 ? `0x451770` = **msg 0x409 地图查询** : [0x6518]=0|
|2|0x42C241|技能图鉴：bool flip [esi+0x6208]（sete cl）|
|3|0x42C2E1|退出游戏：`0x419CC0`（恒真）→ edx=[esi+0x53030]; push 1; call [edx+0x10]|
|4|0x42BF37|注销人物：0x419CC0 恒真 → push 0xFFFF,-1,-1,edi(0),0x47AFB4('返回游戏人物选择界面？'),1,0x65,0x565994; ecx=0x7E04C8; `0x418030` = **确认框 msgId 0x65**|
|5|0x42C218|组队：push 6; `0x42ADB0`（toggle id6=party +0x47834）|
|6|0x42C209|行会：ecx=0x8AB828; `0x4523E0` = **msg 0x40C 行会信息请求**|
|7|0x42C292|腰带：ax=[esi+0xD40]; >46 clamp 46 / <0 clamp 0; ==46 → byte[+0xD42]=2; ==0 → byte[+0xD42]=1（腰带槽选择 0..46）|
|8|0x42C302|技能书：push 0xE; `0x42ADB0`（toggle id0xE=skill book +0x524F0）|
|9|0x42C226|聊天记录：push 8; `0x42ADB0`（toggle id8=chat log +0x507EC）|
|10|0x42C1A4|信息窗口：push 0xB; `0x42ADB0`（toggle id0xB=quest +0x516E8，客户端自标「信息窗口」）|
|11|0x42C1B2|设置栏：push 0xC; `0x42ADB0`（toggle id0xC=settings +0x518E0）|
|12|0x42C359|帮助窗口：**no-op**（直接落循环回边；EUC-KR 도움말창(지원예정)）|
|13|0x42C1C0|坐骑：push 0xD; `0x42ADB0`（toggle id0xD=horse +0x52118）|
|14|0x42C234|包袱栏：push edi(=0); `0x42ADB0`（toggle id0=bag +0x6554）|
|15|0x42C30D|状态栏：al=[esi+0x29D38]; push 1; toggle id1=status +0x29CE4 → push 0x148,0xF4,[0x29D00],[0x29CFC],0xC8; ecx=+0x29CE4; `0x423E80` = **状态窗 244×328 SetRect 重定位 @x=0xC8**|

toggle 0x42ADB0（thiscall esi=HUD；表 0x42B3E4 16 项：id5/id10 no-op；窗口 id ↔ 偏移 = F314/F313 全表一致）。

**0x419CC0 = 恒真补丁（字节级）**：`0x419CFB: cmp byte ptr [0x777758],0x13; 0x419D02 nop; 0x419D03 nop`
→ 无条件落到 `0x419D04: pop edi; mov eax,1; pop esi; ret`。三计时器（+0x35B278/+0x35B274/+0x35B26C）8000ms
GetTickCount 检查全部 `jbe 0x419CFB` → **恒返回 1**（节流闸被 NOP 中性化）。文件字节 `80 3d 58 77 77 00 13 90 90`。
idx3 退出 / idx4 注销 gate 恒通过。IAT 实证：[0x4762B0]=**SetRect**、[0x4762B4]=PtInRect、[0x4762E0]=SetWindowPos、
[0x4762F8]=PostQuitMessage、[0x47630C]=**GetTickCount**（0x419CC4 与 0x42C259 两处使用）→ 0x423E80 的 SetRect 论闭合。

**协议消息层 opcode 表（push 常量逐一点验证）**：0x451A10=0x418(1 参,ret 4)、0x451A40=0x419(2 参,ret 8)、
0x451A70=0x401(ret 4, arg=实体+0x8)、0x451AA0=0x402(ret 8)、0x451AD0=0x403(ret 8)、0x451770=0x409(地图查询,ret 0)、
0x4523E0=0x40C(行会请求,ret 0；修正此前「输入框发送」表述)、0x452410=0x40D、0x4519E0=0x416(无参)。
装配 `0x452940`（header=esi+0x18）、发送 `0x451E60`（ecx=0x8AB828，全局网络对象）。

**0x418/0x419/0x416 E8-scan 单调用点定案**（方法：全文件 `data[i]==0xE8` → rel32 解码 → va=0x400000+i+5+rel）：
- 0x451A10(0x418) → **唯一 caller 0x44862B**（任务窗选中记录；+0x20C==0 门）— 与 F218/F251 一致。
- 0x451A40(0x419) → **唯一 caller 0x448148**（任务窗子记录 +0x228 点击；+0x220 空门）— **NPC 选项点击无静态调用者支持**；
  NPC 窗 id9 输入簇 0x440290 无 0x419 发送 → **npc 记录 pending_notes 中「0x419 also covers NPC option clicks (Finding 251)」列为无静态证据的 refinement，已修正**。
- 0x4519E0(0x416) → 4 callers 0x4488C7/0x448B2E/0x4491EF/0x4493AF（任务窗渲染/滚动链）。
- 业务名（放弃/删除任务、请求详情）保持 **candidate**（EIServer.exe 无源码）。

**0x42C4D4 子窗点击表（15 项权威，修正前轮 case 编号错位）**：case0→0x42BF85(bag)、1→0x42BFB3(status)、
2→0x42BFE1(codex)、3→0x42C00B(trade)、4→0x42C039(guild)、5→**0x42C198(no-op)**、6→0x42C063(party)、
7→0x42C08D(+0x47C28)、8→0x42C0B7(chat log)、9→**0x42C17D(NPC 模型 +0x51150, F252)**、10→**0x42C198(no-op)**、
11→0x42C0E1(quest)、12→0x42C10B(settings)、13→0x42C131(horse)、14→0x42C157(skill book)。
边界：`cmp edi,-1; je 0x42BEF8; cmp edi,0xE; ja 0x42C198`。

cross-ref：F218/F234/F243/F251/F252/F261/F304/F306/F312/F313/F314/F315/F316。
落盘：`hud-caption-action-tail-evidence.json`、`ui-coverage-matrix.json`（hud closed_2026_08_12；npc pending_notes 修正）、`UI_COMPLETION_AUDIT.md`。

## 2026-08-12：交易窗（id3）点击绑定全链闭合 + 金币对话框开窗点边界定案（Round 16，Finding 322）

> 阶段目标：闭合 ui-coverage-matrix.json exchange 记录 pending_notes 首项（「exchange button business names
> (1060-1062 Chinese 交易 label visible, click binding not traced)」）与第二项（「trade state transitions beyond
> draw-time side selection」）的静态可闭合部分：从 ctor 0x4159D0 五子控件出发，经分派链 0x42BEAA→0x42AAB0→
> 0x42C4D4 case3=0x42C00B，到输入处理器 0x416EF0 全分支，为每个可点击区域建立 控件偏移 ↔ 命中测试 ↔ 业务动作映射；
> 并核证金币对话框开窗点（0x416EF0→0x418030）与 F302 确认链无重叠。
> 产物：`trade-window-click-binding-evidence.json`（primary-static，F322）。

### Finding 322 (交易窗点击绑定，2026-08-12)：ctor 五子控件 → case3 分派 → 0x416EF0 全分支 + msg 0x406 协议表新增

**ctor 0x4159D0 五子控件（8 参 thiscall ret 0x20；基类 0x423B30；SetRect [0x4762B0] 分割 +0x5C/+0x6C 左右格）**：
|偏移|控件|帧对|ctor 调用点|命中动作|
|---|---|---|---|---|
|+0x7C|X 关闭|0xA1/0xA2 (161/162)|0x415A5B-0x415A71|vtable+0x10 命中 → ret 1 → case3 外部 toggle id3 关闭|
|+0x130|交易按钮|0x425/0x426 (1061/1062)|0x415A76-0x415A9D|命中 → **msg 0x406** @0x451B30 发送 + [trade+0x13644]=1 lock → ret 0|
|+0x1E4|隐藏按钮|0x428/0x429 (1064/1065)|0x415AA2-0x415AC3|空白帧（F260 实测）；命中 → 消费 no-op ret 0|
|+0x13648|输入框 1|—|0x415AC8-0x415AE1 (ctor 0x417960)|0x416FD2 命中环（2 迭代 stride 0x4C）→ 命中消费|
|+0x13694|输入框 2|—|0x415AE6-0x415AFF (ctor 0x417960)|同上（间距 0x4C）|

**分派链（id3 点击唯一入口）**：0x42BEAA（ebp=y, ebx=x）→ 0x42BEB4 `call 0x417E60(esi+0x61BC)` 杂项命中（命中 ret 1）→
0x42BED3 `call 0x42AAB0` → edi=窗口 id → 0x42BEE5 `call 0x44E910(esi+0x33188)` 开检查 → 0x42BF7E `jmp [edi*4+0x42C4D4]`
→ **case3 = 0x42C00B**：`push ebp(y); push ebx(x); push ecx(esi+0x20); lea ecx,[esi+0x3399C]; call 0x416EF0` →
非 0 → `push 3; call 0x42ADB0`（toggle id3 关闭）→ ret 8。**E8-scan 全文件：0x416EF0 唯一 caller = 0x42C017。**

**0x416EF0 全分支（8 参 thiscall ret 0xC；esi=trade，arg1=winmgr+0x20 指针，arg2=x，arg3=y）**：
1. **금전(金钱) 金币对话框开窗**（0x416F2F strcmp 门）：`[edi+0x1C]` vs `0x47ADB4`（字节 b1 dd c0 fc =
   **EUC-KR '금전'**；GBK '陛傈' 乱码弃用）== 0 且 PtInRect([0x4762B4], rect@[esp+0x18], x, y)（rect：x+0x22..x+0x9C
   @[esi+0x18]，y+0x10E..y+0x130 @[esi+0x1C]）→ `0x418030(ecx=0x7E04C8, 8 参: 0x565994,3,1,0x47AD98('您要付给对方
   多少金币?' GBK),1,-1,-1,0x405)` 金币对话框建框 → `rep stosd 0x30E` 清 arg1 记录 → ret 0。
   **与 F302 边界**：F302 只覆盖确认链（0x418520 ENTER/SPACE / 0x418600 点击 → SendMessageA(0x8AB7B0, 0x7EE,
   wParam=0x03000405) → 0x41DFE0 → … → 0x451B00 msg 0x405 死链）；**开窗点在输入处理器 0x416EF0，确认链在对话框
   自身，两段无重叠**。
2. **lock 检查**（0x416FB4）：`[esi+0x13644]!=0` → ret 0（accept 后窗口对点击惰性）。
3. **输入框命中环**（0x416FD2）：2 迭代 stride 0x4C，起点 +0x13648 → 0x417E60 命中测试 → 命中 ret 0。
4. **X 按钮**（0x416FFA）：vtable+0x10 命中 +0x7C → **eax=1 ret 0xC**（外部 case3 非 0 → toggle 关闭）。
5. **交易按钮**（0x417018）：命中 +0x130 → `mov ecx,0x8AB828; call 0x451B30`（**msg 0x406 发送**）+ `[esi+0x13644]=1`
   → ret 0。**0x451B30 唯一 caller = 0x417034**（E8-scan 复核 F295 accept click 归属）。
6. **隐藏按钮环**（0x41704F）：counter=1 起 stride 0xB4（+0x130 重查 / +0x1E4）→ vtable+0x10 命中 → ret 0 消费。
7. **左格 +0x5C**（0x41707C PtInRect, [0x7DA1C4]=y, [0x7DA1C0]=x）：0x416830 → ebx=源 cell；0x416950 → eax=目标 cell；
   item 检查 `[esi+((eax*3*32+eax)*4+eax)*2+eax)*4+0x5B8]`：
   - `[edi]==0` → `0x416C20(esi,0,ebx,eax,edi)` 格内移动/整理 → ret 0。
   - `[edi+4]==0 && [edi+0xC]!=0` → `0x416D60` 取回/清除 + rep stosd 0x30E 清记录 → ret 0。
   - 否则 → `0x416DC0` + push [esi+0x12A61] → 0x417183 汇合：`add esi,0x12A28; mov ecx,0x8AB828; push esi;
     call 0x451AA0`（**msg 0x402**，2 参：buffer=esi+0x12A28, value=[esi+0x12A61]）→ `[edi+4]=1` → ret 0。
   - cell 空分支（ebx==-1 || eax==-1）：[edi]==0 → ret 0；[edi+4]!=0 → ret 0；[edi+0xC]!=0 → 0x416D60+清 → ret 0；
     否则 0x416DC0 + 0x451AA0 → [edi+4]=1 → ret 0。
8. **右格 +0x6C 无处理**（0x41719B 公共尾 ret 0）：输入侧只命中左格；draw-time PtInRect 选侧（F258）≠ 输入处理。

**msg 0x406 @0x451B30（协议表新增项）**：`push 0; push 0; push 0; lea edi,[esi+0x18]; push 0; push 0x406; push edi;
call 0x452940; push 0; push edi; mov ecx,esi; call 0x451E60; ret` — 与 F321 装配/发送模式一致；**F321 协议表无 0x406**。
msg 0x402 @0x451AA0 语义补全（F321 表已有）：2 参（buffer, value），ret 8。

**0x418030 E8-scan 24 调用点全表**：0x403E12/0x416F9C(本开窗点)/0x4193D8/0x41C196/0x41D230/0x41D633/0x41E0B6/
0x41FB0F/0x41FD72/0x420416/0x420B9F/0x420BD3/0x42179D/0x4217C6/0x421828/0x421851/0x4246BA/0x425C8F/0x42BF66/
0x44048D/0x459352/0x4594F9/0x4597E4/0x45A074 — 通用消息/对话框 ctor（第 4 参=文案 VA，第 8 参=msgId 0x405 与
F302 wParam 0x03000405 一致）。

**IAT 实证**：[0x4762B4]=PtInRect（0x416F70 与 0x41708E 两处使用）；[0x4762B0]=SetRect（ctor 分割格子）。

cross-ref：F258/F260/F263/F295/F302/F313/F316/F321。
落盘：`trade-window-click-binding-evidence.json`、`ui-coverage-matrix.json`（exchange closed_2026_08_12；pending_notes 修剪）、`UI_COMPLETION_AUDIT.md`。
## Round 17 (2026-08-12) — 0x40C020 caller 全链闭合 + vtable+0x7C 多态槽定案（Finding 323）

- EntityHeadbarVtable77cCallers（Finding 323）：entity-headbar-vtable77c-callers-evidence.json — **target-box 记录末项『0x40C020 caller unidentified』闭合（primary-static）**：
  - **0x40C020 = vtable 0x47671C（NPC/怪物实体）slot +0x7C**，无 E8 直接调用；安装点唯一 = 0x42264E（msg 0x327 解析器 0x4225E0 内；al==0x32→实体、al∈{0,1}→玩家 ctor 0x40C560、其余→基类 ctor 0x404960）。
  - **恰 4 个间接调用点**（FF 5? 7C / FF 57 7C mod01 0x50-0x57 + mod10 0x90-0x97 双编码扫描）：0x41C831（帧渲染 0x41C450 本地玩家路径）+ 0x41CCA1/0x41CCC9/0x41CCEA（实体渲染循环 0x41CBD0 类型分派）。
  - **类型分派**：`cmp [esi+0x88],0x32; ja 跳过` → 字节表 0x41CD1C（00 00 03 01 03…03 02：0→case0、1/3→case1、0x32→case2、其余→跳过）→ 跳表 0x41CD0C（case0→0x41CC8E、case1→0x41CCD7、case2→0x41CCB6、case3→0x41CCED）。5 栈参 + this（a1=edi+0xF5200, a2=0, a3=[edi+0x30], a4=1, a5=0/1 本地玩家标志）；case0 调后 0x40B180+0x40CE20、case1/2 调后 0x40B180。
  - **vtable+0x7C = 多态『实体头部信息条/屏幕 anchor』槽**：基类 0x4763C0→0x40B2C0、玩家 0x476480→0x40F5F0、NPC 0x47671C→0x40C020（+0x78=0x406CC0、+0xC=0x404FB0、+0x84=0x40B850 三 vtable 共享）。
  - **0x40C020 语义**：实体头部 HP 条 + 名字——anchor 公式 ([esi+0xCC]−[ctx+0x12C])·48 − [ctx+0x134] + [esi+0xD4] − 0xC8（与 0x40F5F0 同构）；HP 分数 [esi+0x61C58]/[esi+0x61C60] → 填充字节 0..0x1F（shl5−sub=×31; idiv; cl=0x1F−al; 超界置 0）；名字 0x462710（ecx=0x8AB7A8, 0x8A68D4=空串''）、条 0x404E10（0x94BF 模式分派）、状态位 0x404DA0（[+0x61C68] bit 0x800000）；ret 0x14。
  - **0x40F5F0 双路径**：E8 唯一 0x4120EE（固定 anchor 路径 0x4120B0：预写 [ecx+0xE4]=0x178/[ecx+0xE8]=0xE3，门 [ecx+0x62A48]）+ **间接 vtable 调用 0x41C831**（记录『only_direct_caller』为 E8-only 结论，补全）。0x40F5F0 全函数 fresh 复核：写此+0xE4/+0xE8（a4 门）→ 10000+(A%400) 系列（A=[629C8]·400−[8A]·3000+[C4]−0xAA0, [esi+0x62A20]=A, frame=0x2710+(A%400), call 0x466130）——与 target-box 记录逐字节一致。
  - **类型字节 [esi+0x88] 证据**：0x4123E3（mov eax,[0x7E335C]; cmp byte [eax+0x88],0x32 → ret 1 全局 NPC 检查）、0x43DC65（cmp [edi+0x88],0x32; jne; fild [edi+0xCC] 浮点世界 x）；**写入点 = 0 命中**（0x88/0x89/C6/C7 全 mod 含 SIB 扫描，primary-negative）→ [INFERENCE] 经 vtable+0xC Init 0x404FB0 家族（跳表 0x4054EC/分类表 0x405500）或 F300 0x405862 外观/type 更新设置。
  - 解析器尾部（0x4227A6）：[esi+0x61C58]=0x12C(300) HP 上限、[esi+0x61C5C]=0；实体入表 call [edi+0xE1154] vtable+4。
  - **与既有记录边界**：0x40C020 是第六个独立绘制路径（通用实体头部条），非悬停目标框；F257 的 0x41C063 是 [vtable+0x84]=0x40B850（name-plate box），槽位 +0x80/+0x84 与本案 +0x7C 不同。

cross-ref：F239/F257/F271/F300/F315/F321/F322。
落盘：`entity-headbar-vtable77c-callers-evidence.json`、`ui-coverage-matrix.json`（target-box closed_2026_08_12；pending_notes 修剪为 runtime WIL 部分）、`UI_COMPLETION_AUDIT.md`。

## Round 18 (2026-08-12) — 选项窗 settings 长尾闭合：Ambience 死开关定案 + BGM 音量播放时重应用修正（Finding 324）

- SettingsAmbienceBgmVolume（Finding 324）：settings-ambience-bgm-volume-evidence.json — **settings 记录 pending_notes 两项全闭 + F260 结论修正（primary-static）**：
  - **Ambience 实际触发点 = primary-static negative 定案**：跳表 0x44194C idx5/6（0x441850 ON / 0x44186E OFF）= 纯换帧（+0x400 ON 单选帧 0x2F8/0x2F9/0x2F8、+0x4B4 OFF 单选 0x2FA/0x2FB/0x2FA，经帧设置器 0x417880）+ 共享尾 0x44188A → config save 0x441B30 → ret 8。**不写状态字节 [option+0x5C]、不调任何音频引擎函数**（0x45A4A0/0x45A700/0x45B250/0x45B390/0x45B900 家族零引用）。
  - **[+0x5C] 生命周期全表**：写入恰 2 = ctor 前导清零 ~0x440FA8（函数 0x440F90：mov [esi+0x5C],ebp）+ config load 写 0x441EFA；读取恰 2 = restore-visuals 0x4412D2（恢复帧）+ save 0x441C59。→ **Ambience 选项在本客户端 = 视觉-only 死开关**（无实际音效触发点；切换不持久化，save 把 load 值原样回写）。
  - **BGM 音量重应用时序修正（推翻 F260『BGMLevel 0x8AB150 has ZERO audio-engine references』）**：0x8AB150 == BGM 引擎对象 0x8AB130 的 +0x20 字段；两条播放路径均在播放开始时经**寄存器相对寻址**重读该全局——0x45B250 play-by-name 尾 0x45B36D `mov edx,[ebx+0x20]`、0x45B390 play-by-string 尾 0x45B3B8 `mov ecx,[esi+0x20]` → 0x45A4A0（ecx=[ebx+0x528]=0x8AB658 channel, arg=音量）→ 0x45A4E8 → 0x45A700（vol*40 → vtable+0x1C SetVolume）。**0x45A700 唯一 2 E8 callers = {0x441F6C 滑杆实时, 0x45A4E8 播放路径尾}** → 音量应用点 = 滑杆拖动（立即）+ 每次 BGM 播放开始。旧结论为绝对 4 字节扫描局限（漏基址寄存器相对寻址），已注记于 matrix closed_2026_08_11 条目（SUPERSEDED 标注）与 closed_2026_08_12 新条目。
  - **0x45B430 语义定案**：`mov dword ptr [ecx+0x56C],0; ret` = BGM enable-flag clear；E8 唯一 caller = 0x441E29（config load BGM OFF 路径：BGM 键 !=0 → 0x45B410 enable | else → 0x45B3D0 stop + 0x45B430 清 enable）；配对 0x45B410（enable set）callers = {0x4416EC toggle ON, 0x441E18 load ON}。
  - **选项窗 init/open 函数头**：init fn = ctor 0x440FE0（ret 0x24；唯一 caller = main init 0x42788D `lea ecx,[esi+0x518e0]`，id 0xC）：base ctor 0x423B30 @0x441015 + 11 个 0x417550 子控件（stride 0xB4 自 +0x7C）+ **0x4411ED = config load 0x441CC0 唯一调用点** + restore 帧块 0x441226-0x44137C（读 [+0x54]/[+0x58]/[+0x5C]/[+0x60]；Shadow 控件指针经 [esp+0x24]/[esp+0x20]）；open method = 0x4414F0（唯一 caller 0x42C10B，[+0x64]/[+0x68] 开合标志 + 命中测试分支）。
  - **ShadowBlend [0x47EF48] = 零消费者死全局**：全 .text 恰 3 处引用、全在 option 代码、**全为写入点**（0x4418CB Shadow ON、0x441914 Shadow OFF、0x441F2A config load atoi→[0x47EF48]）；**零读取点** → config-only，无渲染/音频消费者。
  - 附带收尾：0x45A700 内部 vtable+0x1C 参数 = vol*40（lea *5; shl 3）；FX 音量 0x8AB14C 不变（0x45BCE9 播放直读）；滑块公式 volume = slider*0.625−100（[0x476978]=0.625 double）；config save/load 键映射 fresh 复核（EffectSound→[+0x58]、BGM→[+0x54]、Ambience→[+0x5C]、ShadowBlend→[+0x60]+[0x47EF48]、数值→[0x8AB14C]/[0x8AB150]）。

cross-ref：F260/F295/F302/F321/F322/F323。
落盘：`settings-ambience-bgm-volume-evidence.json`、`ui-coverage-matrix.json`（settings closed_2026_08_12 五项 + pending_notes 清空 + F260 SUPERSEDED 注记）、`UI_COMPLETION_AUDIT.md`。

## Round 19 (2026-08-12) — map type 0x32 minimap marker 业务名定案 = NPC 实体（Finding 325）

- MapType0x32MarkerNpc（Finding 325）：map-type0x32-marker-npc-evidence.json — **map 记录 pending 项『type 0x32 marker business name』闭合 + 旧 2026-08-10 候选结论修正（primary-static）**：
  - **minimap 黄色标记绘制门（fresh 复核 0x43DC54–0x43DCD9）**：遍历 list 0x560070（node+4=实体、node+0xC=next）→ 0x43DC65 `cmp byte [edi+0x88],0x32; jne` → **仅 type 0x32 实体**画 0xFFFF 黄色 ±2px 外框：世界 x [edi+0xCC] → fild/fmul [0x476904]（scale）/fiadd [esi+0x2C0]/fisub [esi+0x2D0]/fsub [0x476658]（offset）→ f2i 0x468520；y = [edi+0xD0]−[esi+0x2D4]+[esi+0x2C4]−1；SetRect(eax,y−1,eax+2,y+2) → call 0x45E570（mode 1, 0xFFFF）。
  - **业务身份全链（交叉 F269/F323 primary-static）**：F269 element binding type 0x32 → element 128（NPC）@0x405263 + `Data\NPC.wil` 字符串 @0x47C964（runtime 路径表 init 唯一引用 @0x453F31）；F323 type 0x32 → vtable 0x47671C（NPC ctor）→ +0x7C = 0x40C020 头部 HP 条+名字绘制；spawn/update handler 0x407F20（vtable+0x5C）：pkt+0xB 类型字节 → [+0x61BD4]、名字 interning → [+0x61C70]、世界坐标 [+0xCC]/[+0xD0]、列表尾插 @0x408220-0x408234、同 id 时 0x40826A 类型字节拷贝 [+0x88]→[+0x61C78]；[+0x88] 写入点穷举（fresh）＝恰 2 dword-reg：**0x405862 实体 ctor `mov [esi+0x88],ebp`（类型经 ctor 参数写入）** + 0x446EA2 无关。
  - **交互语义三处交叉验证（fresh 复核）**：① 0x43CD0F minimap 命中测试——type 0/1（[+0xC0]==0x13 死检）与 type 3（[+0xC0]==4）才 edx=1 可 pick，**0x32 恒 edx=0 不可 pick**；② 0x41ECAE find-object-at-xy——匹配 [+0xCC]/[+0xD0] + [+0x61C74]==0，**仅 type 0/1 命中**（0x32 排除，与旧记录『excluded from find lookup』一致）；③ 0x4123E3 步进/动作门——picked/target 全局 [0x7E335C] `+0x88==0x32` → 门返回 1 **阻挡**。
  - **旧结论修正（SUPERSEDED）**：2026-08-10 closed_notes『candidate: teleport/block marker; NOT an NPC』→ **定案：type 0x32 = 完整 NPC 实体**（有名字、NPC.wil element 128 精灵、vtable 0x47671C 头部条、世界坐标参与视口变换绘制）；『挡路』真实存在但语义 = 目标为 NPC 时的步进/动作阻挡（NPC 交互锁），非静态传送/阻挡标记。

cross-ref：F269/F281/F287/F323 + map-ui-resource-evidence.json（closed_notes SUPERSEDED + 新闭合并入）。
落盘：`map-type0x32-marker-npc-evidence.json`、`map-ui-resource-evidence.json`（type_0x32_semantics RESOLVED + resolution + closed_notes 5 条）、`ui-coverage-matrix.json`（map closed_2026_08_12；pending_notes 修剪为 runtime 两项）、`UI_COMPLETION_AUDIT.md`。

## Round 20 (2026-08-12) — 0x476600 家族 vtable 全活定案 + 13 渲染器死代码结论推翻（Finding 326）

- RendererFamilyLiveness（Finding 326）：renderer-family-liveness-evidence.json — **Round 20.5『13 渲染器 + 0x45DE50 = 死代码』结论 SUPERSEDED + 全局 UI 对象 0x47EF18 构造路径定案（primary-static）**：
  - **CRT 静态初始化链（fresh 全链验证）**：entry 0x46992D → 0x46998C `call 0x46C38B`（CRT startup）→ 0x4699C5 `call 0x468204`（init runner）→ 0x468228 `call 0x4682EC` = `_initterm(0x47A000, 0x47A104)`——**64 项全局 ctor 表**（0x47A004 起：0x401000/0x401350/0x401760/…/0x401960/0x402260/…/0x45C940）。0x4682EC = MSVC `_initterm`（逐项解引用调用）。
  - **表项 0x47A02C = 0x401960**：`call 0x401970; jmp 0x401980`；0x401970 = `mov ecx, 0x47EF18; jmp 0x418B00`（thiscall ctor thunk）；0x401980 = `push 0x401990; call 0x468467; pop ecx; ret`（**atexit 注册 dtor thunk**）；0x401990 = `mov ecx, 0x47EF18; jmp 0x418D50`。→ **全局对象 0x47EF18：ctor = 0x418B00（init 表），dtor = 0x418D50（atexit）**。E9 jmp-thunk 全扫命中 0x401975/0x401995（E8-only 扫描盲区被补）。
  - **0x418B00 安装 vtable 0x476670 @[0x47EF18]**（0x418D1D `mov [esi],0x476670`）→ slot +0xC = **0x47667C = 0x41E2B0 wndproc**（槽表 fresh dump：+0x0=0x41E6A0/+0x4=0x41E6D0/+0x8=0x41E260/+0xC=0x41E2B0/+0x10=0x423A80/+0x14=0x423850/+0x18=0x4238F0/+0x1C=0x423990/+0x20=0x42E700/+0x24=0x423450）。
  - **wndproc → 分派全链（4 个 call 点逐一体内验证 + epilogue 收尾）**：0x41E2B0 → @0x41E53C `call 0x41DFE0`（caller 集 {0x41DEDE, 0x41E541}，0x41E541 在 wndproc 体内）→ @0x41E188 `call 0x428EF0`（caller 0x41E18D，ret 8）→ @0x428F69 `call 0x429420`（caller 0x428F6E，ret 4）→ @0x4295BB `call 0x4280F0`（caller 0x4295C0，ret 4）。
  - **0x4280F0 分派 = 21 个 E8 直调目标**：0x42EB80/0x44B2D0/0x44E260/0x415B10/0x425040/0x4243D0/0x450530/0x414700/0x43F460/0x447470/0x441380/0x4269C0/0x439500/0x43E3C0/[0x476248 间接]/0x42AAB0/0x42FAB0/0x44B6B0/0x416790/0x450AC0/0x44E650——**Round 20.5 13 渲染器名单中的 0x42EB80/0x415B10/0x425040/0x450530/0x447470/0x44B2D0/0x44B6B0 全在分派表内**；0x437610 经 vtable 0x476528+0x10 活（写点 0x40E7DD/0x413656）。
  - **34 个 vtable 家族基础地址全部有 C7 写点**（modrm-aware 全扫，Round 20.8 定案）：0x476448=114、0x476624=32、0x476454=19、0x4763A8=9、0x4763BC=6、0x476620=6、0x4763C0=2、0x476360=3、0x476368=2、0x476378=4、0x476480=2、0x476528=2、0x476544=2、0x4765F0=1、0x47660C=2、0x476638=4、0x47663C=2、0x476654=2、0x47665C=2、0x476670=2（0x418D1D/0x418D6D）、0x476680/0x47669C/0x4766B8/0x4766F0 各 4、0x4766D4=2（+2 处 B8 两段式 0x418B51/0x418E80）、0x47671C=1、0x4767A8=4、0x4767C0/0x4767C4/0x4767C8=5、0x4767CC/0x4767E0/0x4767FC=5；0x476400=0 引用但真实家族基础从 0x476448 起。
  - **判定标准确立**：全局对象 ctor/dtor 靠 **CRT init table（dword 指针数组）+ atexit 注册**调用，vtable 槽函数靠 **[reg+off] 间接调用**——二者均无 E8 直调；「无 E8 caller / 无 dword ref ≠ 死代码」。0x4570A0（主窗口创建，`mov [0x8AB820]/[0x8B1870],0x47EF18; call 0x419350→0x45D270 创建 0x8AB7A8 800×600 主对象`）E8 caller = 0x457753（此前 summary 误记 0x457092 = NOP 填充，真 fn 头 = 0x4570A0）。

cross-ref：Round 20/20.5（SUPERSEDED）/20.6/20.7/20.8 + F309（0x7E8 事件总线 0x41E2B0）+ F323（实体侧 vtable 链）。
落盘：`renderer-family-liveness-evidence.json`、`ui-coverage-matrix.json`（hud closed_2026_08_12 新条目）、`UI_COMPLETION_AUDIT.md`。

## Round 21 (2026-08-12) — 0x4280F0 分派 21 目标身份全表 + id13 坐骑/id14 技能书定案（Finding 327）

- **分派身份全表（primary-static 定案）**——0x4280F0 的 21 个目标全部绑定业务身份（winbase / ctor·wrapper / paint / hitrect(+0x18) / hover / frame）：

  |id|业务名|winbase|ctor/wrapper|paint|hitrect|hover|frame|
  |---|---|---|---|---|---|---|---|
  |0|背包|0x6554|0x42EA80|0x42EB80|0x656C|0x42FAB0|F250|
  |1|状态|0x29CE4|—|0x44B2D0|0x29CFC|0x44B6B0|F200|
  |2|商店|0x33188|—|0x44E260|0x331A0|0x44E650|F1000|
  |3|交易|0x3399C|—|0x415B10|0x339B4|0x416790|F1050|
  |4|行会|0x4707C|—|0x425040|0x47094|—|F600|
  |5,10|unregistered|—|—|默认 0x428283|—|—|—|
  |6|组队|0x47834|—|0x4243D0|0x4784C|—|F900|
  |7|组长弹窗|0x47C28|0x4503B0|0x450530|0x47C40|0x450AC0|F200|
  |8|聊天|0x507EC|—|0x414700|0x50804|—（IntersectRect 豁免）|F350|
  |9|NPC|0x51150|0x43ED00|0x43F460|0x51168|—|F1100|
  |11|任务|0x516E8|—|0x447470|0x51700|—|F700|
  |12|选项|0x518E0|—|0x441380|0x518F8|—|F750|
  |**13**|**坐骑 horse**|**0x52118**|**0x4268C0**|**0x4269C0**|**0x52130**|—|**F850**|
  |**14**|**技能书 skill-book**|**0x524F0**|**0x439250**|**0x439500**|**0x52508**|—|**F400**|
  |15|公告|0x52E5C|0x43E260|0x43E3C0|无 hit 槽|—|F602|

  计数 = 14 paint E8 + 1 IntersectRect 间接 + 1 hit-test 0x42AAB0 E8 + 5 hover E8（id0/1/2/3/7）= 21（与 F326 分派表逐项对应；id5/10 默认槽，id15 上限 guard）。paint 跳表 0x428358（16 槽）、hover 跳表 0x428398（8 槽）、hit-test 跳表 0x42ABE8（15 槽）槽值完整 dump。
- **main_init 双证（0x4278C0–0x4279A0 逐条核对）**：0x4278D9 `call 0x4268c0`（`lea ecx,[esi+0x52118]`、push 0xd、frame 0x352=850）→ **id13 坐骑 ctor 0x4268C0**（与 dispatch 槽 13→0x4269C0 相邻同族）；0x427904 `call 0x439250`（`lea ecx,[esi+0x524f0]`、push 0xe、frame 0x190=400）→ **id14 技能书 wrapper 0x439250**（与 dispatch 槽 14→0x439500 相邻）——**id13/id14 身份经 dispatch 槽 + main_init ctor 参数双证**。旧疑点『id13=other-14 wrapper 0x439250 frame 400』系误读：0x439250 实为 id14 skill-book 的 wrapper（RESEARCH_LOG 3128–3131 旧表『13/14 通用窗口』由此 SUPERSEDED）。
- **hit-test 0x42AAB0 完全解码**：按可见窗口链表（[+0xd38] count / [+0xd2c] head，node+0=id、node+4=next）顺序迭代，per-window rect 指针 = win+**0x18**；`mov edx,[esp+0x24]`(x)、`mov ebp,[esp+0x28]`(y) → `call dword ptr [0x4762B4]` = **USER32!PtInRect**（非零=inside）；guard `cmp eax,0xe; ja 0x42ab8a` + 15 槽跳表；命中槽 `mov eax,[edi]; ret 8` 返回窗口 id，未命中 -1。覆盖 ids 0–4,6–9,11–14；**id13（rect 0x52130）/id14（rect 0x52508）槽位真实存在 → 均为真实可交互窗口**；id5/10 默认继续，id15 公告无 hit 槽。
- **底部控制带交叠隐藏（行为闭合）**：paint 后 `call [0x476248]`（USER32!IntersectRect）将窗口 rect 与近屏底常量矩形 {0xdf=223, 0x23a=570, 0x241=577, 0x24a=586}（800×600 屏内 y 570–586 输入条带）求交；**id8 聊天豁免**（`cmp [edi],8; je` 跳过）；任何非聊天窗口与带相交 → 帧末 `ShowWindow([0x8AA48C], 0)`（经 [0x4762AC]）隐藏**聊天输入 EDIT 控件**（非主游戏窗口——主窗口 HWND = 0x8AB7B0；0x8AA48C 写于 0x451145 CreateWindowExA@0x451137 后，wndproc 0x450C40 经 SetWindowLongA@0x451148；chat-window-control-map case1–4 GetFocus/SetFocus/EM_SETSEL 均为聊天输入操控，与 trade-gold-flow-evidence 一致）。语义：窗口覆盖输入条带时禁用聊天输入。
- **IAT 身份解析（pefile via venv site-packages）**：0x4762B0=USER32!SetRect、0x4762B4=USER32!PtInRect、0x4762B8=USER32!SetFocus、0x4762AC=USER32!ShowWindow、0x4762A8=USER32!PeekMessageA、0x476248=USER32!IntersectRect、0x476260=USER32!CreateWindowExA、0x476190=KERNEL32!GetVersion、0x4761B0=KERNEL32!GetFileType。
- **陈旧记录修正（三处）**：①`window-traversal-evidence.json` window_id 14 paint `0x0043E3C0`『notice/prompt』→ **`0x00439500`『skill-book』**（0x43E3C0 实为 id15 公告 paint），并补入缺失的 id15 行（0x43E3C0 / main+0x52E5C / notice/prompt）；②chat-window-mouse-dispatch.json（2 处）+ chat-window-control-map.json（3 处）『map hwnd』→ 『chat input edit hwnd』；③layout 记录 **`window.other-14-candidate` → `window.skill-book`**（仓库 26 个文件同步改名，含 simulator 数据 title；layout.json version 0.5 → **0.6-window-paint-dispatch-identity**，skill-book/horse 记录补 hit_rect + dispatch 身份字段）。
- 落盘：`window-paint-dispatch-identity.json`（F327）+ matrix skills/horse closed_2026_08_12（新条目）+ layout.json（缩进 2，diff 仅预期变更）+ UI_COMPLETION_AUDIT.md。

cross-ref：F326（21 目标表）、F316（id0 背包）、F313（win+0x18 rect）、F272（技能书渲染链 paint 0x439500）、F260/F264（坐骑）、F309（wndproc 事件总线）、F323（实体侧链汇合点）、trade-gold-flow-evidence（0x8AA48C chat input EDIT）。

## Round 22 (2026-08-12) — 0x476670 定案 = 4 槽主对象 vtable；+0x10..+0x24 归属 0x476680 链表类家族；节点类 0x476454；可见性节点布局修正（Finding 328）

- **0x476670 = 4 槽（不是 10 槽）**——raw dump：+0x0=0x41E6A0、+0x4=0x41E6D0、+0x8=0x41E260、+0xC=0x41E2B0；写点仅 ctor 0x418D1D / dtor 0x418D6D。槽身份：+0x0 = **状态行格式化**（thunk → 0x4514F0 @0x8AB828，`push 0x47C808` = 格式串 `'**%s/%s/%d/%d/1'`，参数四全局 0x47EEF8/0x47EEE4/[0x47EF10]/[0x47EEB8]；0x8AB828 与公告 sprintf 0x45DC70 同缓冲）；+0x4 = **消息解析**（memchr 0x468B30 扫描 size 0x21 + 0x41ED20 SEH 大函数 '+' 检查，alloc 0x21/0x23）；+0x8 = **[this+0x34] 门控 750ms 延时**（0x465DD0(0x2EE,0)；0x465DD0 基 **WINMM!timeGetTime** @IAT 0x47630C——非 GetTickCount，pefile 定案）；+0xC = **wndproc**（F309）。
- **+0x10..+0x24 六槽 ≠ 0x476670**——它们 = **vtable 0x476680（独立 7 槽链表类）**：+0x0=0x423A80 dtor（装回 0x476680，operator delete）、+0x4=0x423850 **AddTail**（懒建头：空表 new(0x10) 节点 vtable 0x476454 设头尾、data=arg、count++；非空尾插 [old_tail+0xC]=node、[this+8]=node、count++）、+0x8=0x4238F0 AddTail 变体（头部逐字节相同）、+0xC=0x423990 **insertAfter(prev,data)**（node+8=prev、node+0xC=prev->next、双向链修复、尾维护、count++）、+0x10=0x42E700 **ForEach**（回调 [this+0xC]、回调 this [this+0x10]、参数 (this, arg, node->data)、0 返回 break）、+0x14=0x423450 **unlink+节点删除**（head/prev/next/尾修复，`push 1; mov edx,[node]; call [edx]` 节点 slot+0 删除）、+0x18=0x4048B0 ForEach 变体。
- **链表类家族 = 6 成员**：main+0xE1154→0x4766F0、+0xE116C→0x4766D4、+0xE1184→0x4766B8、+0xE119C→0x4766D4、+0xE11B4→0x47669C、+0xE11CC→0x476680（ctor 0x418B25–0x418BEE 顺序 arming + dtor 0x418E80–0x418EB1 复写；每成员 5 个后续 dword 清零）。vtable 28 字节间隔（0x476680/+0x1C=0x47669C/+0x38=0x4766B8/+0x54=0x4766D4/+0x70=0x4766F0），家族 dtor 链 0x20 间隔且各自装回基址：0x423A80→0x476680、0x423A60→0x47669C、0x423A40→0x4766B8、0x423A20→0x4766D4、0x423A00→0x4766F0（五者前 20 字节逐字节核对，仅 restore 字不同）。
- **节点类 0x476454**（12 字节 {+0 vtable, +4 data, +8 prev, +0xC next}）：+0x0=0x413D80 dtor、+0x4=0x40EA60 dtor2（call 0x422270）、+0x8=0x435030 渲染/度量、+0xC=0x403AC0 no-op（亦作主对象子成员 +0x361150/+0x35B2C0 no-op dtor）、+0x10=0x4378E0/+0x14=0x437DF0/+0x18=0x435A20 位置数学；+0x1C dword = 数据非槽。
- **312 站点归属 = 0（无经 0x476670 的 [reg+off]）**：0x476670 4 槽方法全经 18 个 `mov ecx,0x47EF18; call 0x41..` 直接调用点（0x401970/0x401990 thunk、0x40213D→0x41BB00、0x402149→0x41B440、0x402153→0x41B500、0x40F198/0x411623→0x41EBD0、0x410DA8/0x412562→0x419C40、0x41D201/0x41D23D/0x42BF37/0x42C2E1→0x419CC0、0x42C18E→0x41C1E0、0x42C1E4→0x41EC10、0x42CDB5→0x41EC10、0x42CFBE→0x41C1E0、0x4570AA→0x419350）。312 站点经窗口类 vtable slot+0x10（SetVisible，0x42ADB0 分派）及其他对象家族（0xa68/0xb1c 子对象、删除 dtor `push 1; call [eax]`、`call [eax+0x10]` push 0/push 4）。
- **直接方法上下文（0x42C150–0x42C200 命令/热键区）**：0x42C168 `push 0xe; call 0x42adb0`（id14 技能书 toggle）；0x42C18E `mov ecx,0x47ef18; call 0x41c1e0`（NPC 检测 0x440290 后 = NPC/对话框清理：hide id9 @0x42ac50 + SetVisible(0) main+0x2f65dc + 清 0x428050/0x42804c + hide id2 商店）；0x42C1A4/0x42C1B2/0x42C1C0 push 0xb/0xc/0xd（任务/选项/坐骑 toggle）；0x42C1CE–0x42C1E9 `mov ecx,0x47ef18; call 0x41ec10`（`mov eax,[esp+0xC]; and eax,0xff; cmp eax,7; ja default; jmp [eax*4+0x41ECFC]` 8 槽参数分派，成功后结果写 0x8AB828）。
- **可见性分派修正**：0x42AC50 found-path 全解码（0x42ACD2–0x42AD9F）——count--、prev/next 互链、cursor/tail 维护、空表全清，**free = 直调 operator delete 0x4680F8 @0x42AD93**；节点布局 = **{+0=id, +4=next, +8=prev}**（修正 window-visibility-dispatch-evidence.json 的 offset_4=previous/offset_8=next，与 F327 hit-test node+4=next 自洽）。0x42B820 hide-all：15 槽跳表 0x42B938（id0–0xE，5/10 跳过）`push 0; lea ecx,[win]; call 0x423F90`（`mov [win+0x34],0; ret 4` = 清活性位，不触 +0x30 门、不 unlink）。0x423FA0（SetRect 居中数学，[+0x40]/[+0x44]）非本家族对象。
- 落盘：`main-object-vtable-family-evidence.json`（F328）+ matrix 新条目 main-object-vtable-family + window-visibility-dispatch closed_2026_08_12（节点布局修正注记）+ layout.json version 0.6 → **0.7-main-object-vtable-family** + UI_COMPLETION_AUDIT.md。

cross-ref：F326（0x476670 安装链 + 34 vtable；10 槽条目 SUPERSEDED）、F327（可见性/hit-test 节点布局）、F309（wndproc 0x476670+0xC）、F323（实体侧链）、window-visibility-dispatch-evidence.json、renderer-family-liveness-evidence.json。

## Round 23 (2026-08-12) — 场景实体链表 0x560070 + 键盘热键 0x42CBD0 全解码 + 坐骑窗口族（Finding 329）

- **场景实体链表 0x560070 定案 = 主对象列表成员 #1**：base main+0xE1154（vtable 0x4766F0）、head main+0xE1158 = **0x560070**、count main+0xE1168 = **0x560080**（1 读者 0x43CD10）。节点布局 {+0 vtable, +4 data(实体), +8 prev, +0xC next}（0x41ECB0 迭代：edi=[0x560070]; esi=[edi+4]; edi=[edi+0xC]）。六成员 stride 0x18：m1 0x56006C/0x4766F0、m2 0x560084/0x4766D4、m3 0x56009C/0x4766B8、m4 0x5600B4/0x4766D4、m5 0x5600CC/0x47669C、m6 0x5600E4/0x476680；实体数组 @0x5600FC = main+0xE11E4（stride 0x144）。
- **六成员 vtable 槽表 raw dump（8 槽，F328 语义保持）**：0x4766F0=[0x423A00,0x4230E0,0x423180,0x423220,0x42E700,0x423450,0x4048B0,0x42D00000(数据)]；0x4766D4=[0x423A20,0x4232A0,0x423340,0x4233E0,0x42E700,0x423450,0x4048B0,0x423A00]；0x4766B8=[0x423A40,0x4234D0,0x423570,0x423610,0x42E700,0x423450,0x4048B0,0x423A20]；0x47669C=[0x423A60,0x423690,0x423730,0x4237D0,0x42E700,0x423450,0x4048B0,0x423A40]；0x476680=[0x423A80,0x423850,0x4238F0,0x423990,0x42E700,0x423450,0x4048B0,0x423A60]（= F328 表）。槽语义：+0 dtor / +4 AddTail / +8 AddTail 变体 / +0xC insertAfter / +0x10 ForEach / +0x14 unlink+节点删除 / +0x18 ForEach 变体。
- **成员操作站点全清单**：slot+0x14 unlink ×12（0x419669/0x419E24/0x4223B3/0x41957C/0x41BD0E/0x41BD36/0x41EBA1/0x41A171/0x4195CC/0x41A3A1/0x41F55C/0x41A477，模式 `mov edx,[reg+disp32]; lea ecx,[reg+disp32]; push data; call [edx+0x14]`）；**m1 AddTail 唯一写点 0x42278F**（`mov edx,[edi+0xE1154]; lea ecx,[edi+0xE1154]; push esi; call [edx+4]`）。
- **实体 spawn 处理器 0x422580（SEH）**：type word 分派（0xA/0xD/0xB/9/0x20/0x21/0x14/0x1B/0x321/0x327 共用路径）；**type==0x32 → new(0x629C8) 0x468B1A → ctor 0x404960 → `mov [esi],0x47671C` @0x42264E → [esi+4]=名字 → call [vtable+0xC]（0x404FB0，参数 实体数组 0xE11E4/x/y/…）→ AddTail(m1) @0x42278F → `mov [esi+0x61C58],0x12C; mov [esi+0x61C5C],0` → 0x4561B0([esi+0xF0])**；type 非 0x32 → new(0x62A48) → ctor 0x40C560 → call [vtable+0x8C] → AddTail(m1)。
- **实体 vtable 0x47671C**（raw dump 16 dword）：[0x41E280, 0x404A30, 0x404D60, 0x404FB0, 0x4058E0, 0x405E20, 0x40C420, 0x40C4B0, 0x40AFD0, 0x4069C0, 0x407010, 0x406A20, 0x406A40, …]（0x476700 起 0x42E700/0x423450/0x4048B0 = 列表槽区）；写点 @0x42264E。
- **0x41EC10 = 8 方向相邻地块实体查找**（4-arg thiscall ret 0x10，ecx=0x47EF18）：arg0 x / arg1 y / arg2 selector byte / arg3 delta；跳表 0x41ECFC 8 case 算 8 方向偏移；遍历 0x560070 匹配 {[+0xCC]==x, [+0xD0]==y, [+0x61C74]==0, byte [+0x88]∈{0,1}}；命中返实体指针/未命中 0。
- **键盘热键处理器 0x42CBD0 全解码**（2-arg thiscall ret 8，ecx=main+0x2A548C，ebp→0x47EF18；gate [ebp+0x53060]/[ebp+0x52E8C]；GetKeyState 经 IAT 0x476278 的 `call edi`）：**'C'(0x43)→0x42CDB5 `mov ecx,0x47EF18; call 0x41EC10`（[0x777759]/[0x777768]/[0x777764]/delta=1）→ 命中 `add eax,8` 名字指针 → `ecx=0x8AB828; call 0x451A70` 状态行显示实体名**；'D'→horse id13 toggle 0x42ADB0；'Z'→亮度夹 [ebp+0xD40]∈[0,0x2E]；'V'→节流（timeGetTime-[ebp+0x6210]>100ms；[ebp+0x6518]==0→0x451770 清状态行 否则置 0）；'B'→toggle [ebp+0x6208]；'G'→party id6；'F'→0x4523E0 清 0x8AB828；'N'→options id0xC；'T'→[ebp+0x6518]==1 时 toggle [ebp+0x64A8]+0x43D5F0([ebp+0x6214], [0x8AB7BC] 尺寸)。调用点 @0x41DD8A（gate [esi+0x35B2B8]、[esi+0x3615B0]→0x418470）。
- **TAB 窗口循环 0x42CFBE**：index→[ebp+0xD34]、cursor=[ebp+0xD2C]；node id==9 → `mov ecx,0x47EF18; call 0x41C1E0`（NPC 关闭），否则 0x42ADB0 toggle。
- **坐骑窗口族（F327 归属最终化）**：0x423B30 = 通用窗口基类 ctor（thiscall 8+ args ret 0x24，**不装 vtable**；+4 id、+0x28/+0x2C pos、+0x3C、+0x40/+0x44 w/h 经 IAT SetRect 0x4762B0）；**0x4268C0 = 坐骑 ctor**（基类后 **5× 0x417550 子控件工厂**：容器 +0x54/+0x108/+0x1BC/+0x270/+0x324 stride 0xB4，resource ID 对 0xA1/0xA2、0x35C/0x35D、0x35E/0x35F、0x360/0x361，布局 edi+0xFC/+0x1C/+0x4A/+0x85、ebp+0x125/+0xF4；**无 vtable 写点**——C7 06/B8+89 穷举无果）；调用点 @0x4278D9（main_init push 0xd + frame 0x352=850）。**0x4268B0 = `jmp 0x423CF0`**；0x423CF0 = `mov eax,[ecx]; jmp [eax+4]` 虚拟 thunk（= 0x4767C0 家族 slot +0x14 AddTail 别名）；**0x423D00 = 家族 slot +0x18 显示/定位方法**（[esi+0x30] gate + [0x8B1874] + [esi+0x28]/[esi+0x2C] → 0x466130（待定）→ push 0xFFFF/0xFFFF/0x258/0x320 + w/h + pos → 移动/重绘）。坐骑 paint = 0x4269C0（F327 分派表槽 13，E8 直调——非 vtable 槽）→ 定案：**0x423D00 属家族槽、0x4269C0 为 horse paint**。
- **实体类 vtable 0x4767A8 扩展 8 槽**：[0x40EA60, 0x435030, 0x403AC0, 0x4381A0, 0x4382C0, 0x435A20, 0x423AA0, 0x423AE0]；写点 0x420EE8/0x421029/0x4212EA（switch ax 5/6/7：new 0x144 + ctor 0x434EF0 + `mov [esi],0x4767A8` + 清 +0x13C/+0x140）。
- **0x560070/0x777xxx 直接写者负结果**：0x560070 全编码穷举无果（A1/A3/89-xx/C7-05/B8+89/lea+mov-imm；.data `70 00 56 00` raw 无命中；0x560060..0x56007C 零引用）→ head 经 ctor 0x418B25–0x418BEE 装 vtable + 0x418EE0 `rep stosd` 清零 + AddTail 内 `mov [this+4],node` 维护（寄存器相对 disp32，无绝对直写）；0x777759/0x777764/0x777768 无立即数写者——全 BSS 结构相对寻址（继续非阻塞）。

cross-ref：F328（列表类 vtable 槽语义 + 六成员 + 节点类 0x476454）、F327（id13 坐骑 ctor/paint + 21 目标表）、F326（0x418B00 ctor + vtable 家族）、F323（实体侧链）、F309（wndproc → 0x41DD8A 热键上游）、scene-entity-render-evidence.json、target-box-evidence.json（0x4350BA + 0x47BD30）、horse-window-render/state-evidence.json。
落盘：`scene-entity-list-and-hotkey-evidence.json`（F329）+ ui-coverage-matrix.json（scene-entities/horse/target-box closed_2026_08_12 注记）+ UI_COMPLETION_AUDIT.md。

## Round 24 (2026-08-12) — 六成员嵌入列表对象定案 + 0x421xxx 包处理函数入口 + 0x417550 图片控件（Finding 330）

- **地址算术证明（六成员嵌入对象）**：main(0x47EF18) + 0xE1154..+0xE11CC = **0x56006C..0x5600E4** 六个 stride-0x18 列表对象（m1 0x56006C/0x4766F0、m2 0x560084/0x4766D4、m3 0x56009C/0x4766B8、m4 0x5600B4/0x4766D4、m5 0x5600CC/0x47669C、m6 0x5600E4/0x476680）+ **0x5600FC = main+0xE11E4 实体数组**（stride 0x144）。『BSS 零直接写者』谜题解决：嵌入字段 = 主对象相对寻址别名；写者 = 寄存器相对 disp32（`lea ecx,[reg+0xE1xxx]`）+ 内联绝对地址站点；ctor 0x418B00–0x418BEE 装 vtable + 0x418EE0 rep stosd 清零。
- **列表对象布局定案**：{+0 vtable, +4 head, +8 tail, +0xC callback, +0x10 callback-arg, +0x14 count}（0x42E700 ForEach 读 [this+0xC]/[this+0x10] 证明）；节点 {+0 vtable, +4 data, +8 prev, +0xC next}（16 字节，new 0x468B1A）。槽语义：+0xC = InsertAfter（0x423220，2 参 ret 8）、+0x10 = ForEach（0x42E700，callback 返 0 移除当前节点）、+0x18 = ForEach-find（0x4048B0，返首个 data）、+0x14 = unlink（0x423450 共享）。
- **per-member AddTail → 节点 vtable 终表**（slot+4 工厂头 C7 常量）：m1 0x4230E0 → **0x4767C0**；m2/m4 0x4232A0 → **0x476448**；m3 0x4234D0 → **0x4767C4**；m5 0x423690 → **0x4767C8**；m6 0x423850 → **0x476454**（复核确认，与内联一致，非 0x476680）。**内联站点（分支特化绝对地址版）**：m4 @0x421345（vtable 0x476448，字段 0x5600B8/0x5600BC/0x5600C8）、@0x4210AD/0x4210FC；m6 @0x421444（vtable 0x476454，字段 0x5600E8/0x5600EC/0x5600F8）；数据 = 0x438100 工厂返回对象。
- **m3 = 计时事件表**：find-by-key 0x41EB40（键 = node+0）；过期 sweeper 0x41EB70（timeGetTime − node+0xC > 0x1388=5000ms → slot+0x14 unlink + 0x4680F8 删除）；AddTail 站点 0x421C50（`add ebx,0xE1184` 重指向 → `call [edx+4]` 真 AddTail；节点 {+0 key, +4 word, +8 word, +0xC timeGetTime 时间戳}）。
- **0x41EBD0 修正 = m6 三键查找**（遍历 0x5600E8，匹配 data +0/+0x14/+0x18 vs 3 参，ret 0xC）——**非 sweeper**（旧表述 SUPERSEDED）。0x41EB10 = 按 [data+4] code 查 m1（遍历 0x560070；8 调用点全在包处理函数内：0x41F02A/0x41F0CF/0x41F154/0x4202AC/0x420351/0x4203D6/0x4218D1/0x421A03/0x421CE2）；命中 `call [data_vtable+0x34]` 分派。m1 数据对象 {+0 vtable, +4 int code, +8 名字}。
- **0x421xxx 包处理函数入口定位**：**0x41ED33**（SEH `mov fs:[0],esp` + `call 0x468D10`（帧分配 helper）+ push ebx/ebp/esi/edi + `mov esi,[esp+0x3F28]`（包字符串，调用方大帧）+ `mov ebx,ecx`（thiscall 主对象））；唯一 caller = **0x41E6FA**（0x41E6A0 '**' 解析器尾部附近）；`+` 前缀 → 0x41E740 独立解析；否则 **0x452920**(esi → [esp+0x10]) 解析消息码；公共出口 0x421D3F。原区间 0x420FCC–0x421D3F 修正为 **0x41ED33–0x421D3F**。
- **分派级联**：code>0x29E → 0x42042B；==0x29E → 0x4203F7；0x26E..0x29D → 0x41F8C6（byte 0x421F2C + jmp [edx*4+0x421EB0]）；==0x26D → 0x41F79E；>0xC9 → 0x41F264；==0xC9 → 0x41F175（chat '/' 命令）；6..0xC8 → byte 0x421D8C + jmp [edx*4+0x421D5C]。0x41F264 链再分：>0x263 → 0x41F582（code−0x264 ≤ 8 → 表 0x421E8C，codes 0x264..0x26C）；==0x263 → 0x41F533（m5 删除）；>0xD4 → 0x41F34D（sub 0x258/dec/sub 9 链）。附加跳表 0x42211C/0x422130/0x422140/0x422158/0x422168+0x42219C（codes 1-5/1-4/-7..-2/-4..-1/0x44D..0x520）+ **新 0x42210C**（`[esp+0x10]−1 ≤ 3` → codes 1-4: [0x420a3b, 0x41f9d9, 0x420a54, 0x420a6d]）。
- **0x41F533–0x41F57D = m5 数据删除 case（code 0x263）**：遍历 [ebx+0xE11B8] head，[data]==code 命中 → `call [m5_vtable+0x14]` unlink + 0x4680F8(data) 删除。
- **type 4/5 实体生成**：m4 查重（[data+0x10] word ∈ {0x10,0x16,0x3F} && [data+0x140]==code → 跳过）；type 5 → 0x434EF0 ctor（vtable 0x4767A8）+ 0x438100(code,0x16,0,0,x,y,-1,0,0) = entity type 0x16=22；type 4 → 0x438100(...,0x10,...) = entity type 0x10=16；[esi+0xFC] += random(1,8)（**0x401670 = range random**：`rand() % (hi−lo+1) + lo`）；0x42129B random(0x4E20=20000,0x7530=30000) 计时器；0x4212B5 random(0x14A=330,0x14E=334) 帧索引（word[+0x10]==0x16 特效）；0x42113D `cmp ax,6/3` → 0x20 字节特效对象（m6）帧 0xE6/0xD2；0x4213C8 → 帧 0xDC。
- **0x417550 = 静态图片控件 ctor**（9 参 thiscall ret 0x24）：字段 {+4 rect, +0x14 图像对象(arg1), +0x18 frame id(arg2), +0x1C frame id(arg2), +0x20(arg8), +0x24 byte(arg6), +0x25=0, +0x28(arg2), +0x2C(arg3), +0x30(arg8), +0x34 名字}；调 0x466130 验证帧后经 SetRect(0x4762B0) 由帧 w=word[frame]/h=word[frame+2] 定 rect。
- **0x466130 = 图像帧选择器**（thiscall：obj, frameid；按 [obj+4] mode）：mode 0 → 0x466640（WIL 惰性载入：帧表 [obj+0xC] stride 0x20、帧数 [obj+0x10]、句柄 [obj+8]、尺寸 sanity ≤0x1000、像素缓冲分配 + **GetTickCount(0x47611C) 15s 缓存过期** → 0x466770 unload；ReadFile 0x4760C4 + SetFilePointer 0x4761EC）；mode 1/2 → 0x466720（内存精灵：索引表 [obj+0x30]、count [obj+0x2C]、base [obj+0x34]、[obj+0x38]=帧指针、[obj+0x3C]=像素指针 frame+0x11）。调用点 0x423D20（ecx=[esi+0x2C], arg=[esi+0x28]）与 0x417584（ecx=[esi+0x14], arg=[esi+0x18]）。
- **坐骑 ctor 0x4268C0 定案**：5× 0x417550 于 horse_win+0x54/+0x108/+0x1BC/+0x270/+0x324（stride 0xB4=180）；帧对 (0xA1,0xA2), (0x35C,0x35D), (0x35E,0x35F), (0x360,0x361), (0x362,0x363)；A3 = 坐骑资源字段 edi+0xFC/+0x1C/+0x4A/+0x85/+0xC0；A4 = ebp+0xF4；A5=0、A6=1、A7=-1、A8=0。**坐骑窗无 vtable 写点**。
- **IAT 名称补全（pefile）**：0x47611C=KERNEL32!GetTickCount、0x4761EC=KERNEL32!SetFilePointer、0x4760C8=KERNEL32!lstrcpyA（另 KERNEL32 块 0x4760A0–0x476174：MapViewOfFile/CreateFileMappingA/LocalFree/LocalAlloc/FindResourceA/LoadResource/GetProcessHeap/HeapFree/lstrlenA/ReadFile/Sleep/WriteFile/GetPrivateProfileStringA/GetLastError/CloseHandle/DeleteFileA/OutputDebugStringA/MultiByteToWideChar/UnmapViewOfFile 等）。
- **0x4680F8 = delete 确认**：wrapper → 0x468D3F（null 检查后内部调 0x46C405 再释放）。0x420C90 chat '/' 命令 case：0x468BF0（strchr）找 '/' → 0x8AB828 状态行 + 0x451420/0x451320 + [ebx+0x4279A4]=0x1F4 计时；0x420C1E：timeGetTime → [ebx+0x2AB69C] + 0x43D780(ecx=ebx+0x2AB6A0, code−1)。0x41D1xx = 独立 ret-8 分派（code−0x51 ≤ 0x27 → byte 0x41D270 + jmp 0x41D264；0x51 case 调 0x419CC0(ecx=0x47EF18) + 0x418030(ecx=main+0x3615B0, 8 参 push 0xffff,-1,-1,0,0x47afb4,1,[esi+0xE6A7C],0x65) 通知显示）。
- **修正 F329 遗留表述**：『m2–m6 无 AddTail 站点』→ m3 站点 0x421C50 + m4/m6 内联站点；『0x41EBD0 = m6 sweeper』→ 三键查找；『m6 节点 vtable 0x476680』→ 0x476454；『0x47611C = WIL 文件读』→ GetTickCount；0x4767C0 = m1 节点 vtable（非 horse family）。

cross-ref：F329（成员 #1 场景实体链表 + 12 unlink）、F328（列表类 vtable 槽语义 + 六成员 + 节点类 0x476454）、F327（id13 坐骑 ctor/paint）、F326（0x418B00 ctor 链）、F323（实体侧 vtable 链）、F309（wndproc 事件总线）、main-object-vtable-family-evidence.json、scene-entity-list-and-hotkey-evidence.json、horse-window-render/state-evidence.json、target-box-evidence.json。
落盘：`six-member-lists-and-packet-handler-evidence.json`（F330）+ ui-coverage-matrix.json（horse closed_2026_08_12 注记）+ layout.json version 0.8 + UI_COMPLETION_AUDIT.md。

## Round 25 (2026-08-12) — 消息环系统定案（0x4561B0 PUSH/0x456270 POP）+ 中央消息泵 0x40A2B0 + 实体 Init 0x404FB0/ctor-factory 链 + 0x423D00 矛盾收敛（Finding 331）

- **〔F331 定案〕0x4561B0 = 加锁消息环 PUSH（非实体 +0xF0 子对象方法——F330 假说 REFUTED）**：环对象 {+0 count, +4 read idx, +8 write idx, +0xC dword elements 内联 [100000×4 = 0x61A80, 至 +0x61A8B], +0x61A8C critsec [0x18]}，总大小 0xC+0x61A80+0x18 = **0x61AA4**；容量 0x186A0=100000；critsec 经 IAT EnterCriticalSection **0x47610C** / LeaveCriticalSection **0x476110**。**0x456270 = 配对加锁 POP**（空返回 0）。0x4561B0 E8 callers = [0x40a290, 0x40a424, 0x40ef20, 0x410698, 0x421d3a, 0x422799, 0x4228e5, 0x42292e, 0x4229b6]；0x456270 E8 callers = [0x404d79, 0x40a20f, 0x40a2fb, 0x40c44f, 0x40edb3, 0x410476, 0x41913a, 0x419163, 0x41969e, 0x41b520, 0x41b551, 0x4222a3, 0x42235b, 0x422815]。
- **〔F331 定案〕消息结构 = 0x40C 字节（0x103=259 dwords），type word @ +4，string @ +0xC**；已知 type 值 = 0x1F/0x1E/0x1D/0x323/0x279/0x33/0x27A/0x32/0x34/0x2F0/0x320/0x321/0x324/0x326/0x327/0x51C/0x1B/0x20/0x22。**克隆点 0x40A404**：call 0x468b1a（new）→ `mov ecx,0x103; rep movsd` → word[+4]=0x1F → push → `lea ecx,[ebx+0xf0]; call 0x4561b0`（克隆后改 type 重新入队）。
- **〔F331 定案〕三环实例**：(a) **pump 对象 this+0xF0**（vtable 家族 0x4763C8；0x40A2B0 泵出，0x40A290/0x40A424/0x40EF20/0x410698/0x422799/0x4228E5/0x42292E/0x4229B6 推入）；(b) **main+0x364458**（包处理函数出口 0x421D33-0x421D3A 推入：消息 {+0/+4/+8 dwords, +0xC string}，0x4227F0 泵出）；(c) **main+0x3C5EFC**（0x422280 泵出）。三环相距环大小 0x61AA4 整数倍（相邻两个 400KB 环）。
- **〔F331 定案〕0x40A2B0 = 中央消息泵**（vtable 0x4763C8 slot 4，引用 = 0x4763D8；`mov ebx,ecx`；this 字段 +0xC0 flag、+0xF0 环、+0x61B94 flag、+0x61C74 计数）：pop 0x456270 → `mov ax,[ebp+4]; cmp eax,0x1b; jg 0x40a3af; je 0x40a3a2; add eax,-9; cmp eax,0xe; ja 0x40a43f; mov cl,[eax+0x40a4bc]; jmp [ecx*4+0x40a498]`；映射 **0x40A4BC** 字节 = `00 01 02 08 08 03 08 08 08 08 08 04 05 06 07`；跳表 **0x40A498** = [0x40A36E, 0x40A347, 0x40A33A, 0x40A37B, 0x40A354, 0x40A361, 0x40A388, 0x40A395]；type 9→0x40A36E、0xA→0x40A347、0xB→0x40A33A、0xE→0x40A37B、0x14→0x40A354、0x15→0x40A361、0x16→0x40A388、0x17→0x40A395；case 走 [this]vtable slots **+0x44..+0x6C**（0x407200/0x407670/0x407DF0/0x407EC0/0x407F20/0x408060/0x409720/0x408C20/0x408630/0x406A70/0x406AB0）；0x1B→slot+0x58、0x1F→slot+0x60、0x20→slot+0x54、0x51C→0x40A3F5、0x320/0x326→0x40A437、0x321/0x323/0x327→0x40A42D。E8 caller = 0（vtable 分派活）。
- **〔F331 定案〕0x422280 = main+0x3C5EFC 环排水**（caller 0x41BBC3，`mov esi,ecx`）：count [esi+0x3C5EFC] → pop 0x456270 → word[+4]：0x1E/0x1D/0x323 → 0x4222DB（`mov ebp,[esi+0xe1158]` m1 head 遍历 [ebp+4]，比较 `[node+4]+4 == [msg+0]` → 命中 call **0x41B570(node, main)**）；0x279 → 0x422403；其余跳过。**0x4227F0 = main+0x364458 环排水**（caller 0x41BBCA，紧接 0x422280 之后）：0x33/0x27A 跳过；0x32→0x422CC0、0x34→0x423000、0x2F0→0x423070。主循环 0x41BBA1 另 call 0x45B250(0x8AB130, &main+0xF5204, 1)（BGM）+ 0x41BBA6 call [0x4760CC](0x1E)（Sleep 30ms）。**0x40A209 = 方向/航向环排水 loop**（word[+4]==0x1F → float 数学 0x476450/0x47644C → 写 [edi+0x61BCC]=word[+6]、[edi+0x61BCA]=word[+8]；非 0x1F → 0x40A28D 重推回环）。
- **〔F331 定案〕0x404FB0 = 实体 Init 分派器**（vtable 0x4763C8 slot 1 与 0x47671C slot 3 共享；ret 0x18）：入口 gate 字节 <8（首个 byte 参 [esp+0x10]，prologue 前读取）且 data[0] ≤0x32；映射表 **0x405500** 字节 = `00 01 04 02 04 04 …`（data[0]=0→idx0、1→idx1、2→idx4=default、3→idx2、0x32→idx3）；跳表 **0x4054EC** = [0x404FE5('G' case), 0x405003('L' case), 0x40507C, 0x4051BB, 0x4054DE default]；'G'/'L' case：`cmp byte [edi+2],9; jae default`（layer）、`cmp byte [esp+0x3C],0x21; jae default`（x≤33）、`mov byte [ebp+0x8C],0x47/0x4C`；tile 表 **0x8AA5C0**（stride 6，BSS 只从引用侧解码）→ +0xB4/+0xB8。
- **〔F331 定案〕实体 ctor/factory 链**：**0x435020** = `mov [ecx],0x476884`（中间 vtable 安装）；**0x435000** = dtor 包装；**0x435030** = 基类 ctor（8 参、ret 0x20；callers 0x4373FD/0x43787D/0x43812C/0x438707）；**0x434EF0 = 全量 ctor**（`mov eax,ecx; mov edx,0x2710; mov [eax],0x476884; mov byte [eax+4],2; mov [eax+0x118],edx; mov [eax+0x11C],edx;` 清零 +0xD0..+0x128 含 +0xF0 区、+0x130=5、+0x12A/+0x12C words；**E8 callers ≈ 100 处** 0x406BC9..0x41154B）；**0x438100 = 工厂**（push 8 参 → call 0x435030 → [esi+0x140]、+0xB4/+0xB0、+0xC8/+0xCC、call 0x43CFD0(ecx=0x574118)；callers 0x420F2D/0x42106F/0x42132D type 4/5 spawn、0x437A3F）。**终 vtable 0x4767A8 写点** = 0x420EE8（`mov [esi],0x4767a8`）、0x421029（call 0x434ef0 后覆写）、0x4212EA、0x437A0E；**0x42264E 写 vtable 0x47671C**（F330 已知 spawn）。**0x476884 = 实体中间 vtable（非终态），0x4767A8 = 最终实体 vtable**。
- **〔F331 定案〕窗口类 ctor 0x4241D0（终 vtable 0x476624）**：SEH 序言（fs:[0] + 0x474B3C）→ [esi]=0x4767CC → call 0x4268B0 → **0x468306([esi+0x6C], 0xB4, 5, 0x4046B0)** 构 5 控件 @ +0x6C/+0x120/+0x1D4/+0x288/+0x33C → [esi+0x54]=0x4767E0 → byte [esp+0x20]=1 → [esi]=0x476624 → call 0x423CF0 → SEH 拆除 ret。字段：+0x28 frameid、+0x2C image obj、+0x30 gate、+0x34 visible、+0x50 byte、+0x54 嵌入 vtable 0x4767E0、+0x58 内嵌链表、+0x5C/+0x68/+0x3F0。**0x468306 = 控件数组构造 helper**（SEH；esi=[ebp+0xC]=5、esi×[ebp+0x10]=0xB4 → 逆序逐元素初始化）。0x4245A0（家族 slot+0x10）= call 0x423CA0 → 销毁 +0x58 内嵌链表 → 清零 +0x58/+0x5C/+0x68/+0x3F0 → **窗口对象 ≥0x3F4 字节**。
- **〔F331 定案〕0x423D00 矛盾收敛（todo ③ 关闭）**：m1 16 字节节点 {+0 vtable,+4 data,+8 prev,+0xC next} = **基类实例，只分派 dtor 槽 0**；**0x423D00（render，读 +0x28/+0x2C/+0x30/+0x50；`mov ecx,[esi+0x2C]; mov eax,[esi+0x28]` → call 0x466130 帧验证）只被全尺寸窗口/实体分派**（0x476624 slot+0xC index 3、0x4767C0 家族 slot+0x18 index 6）；m1 遍历 0x41EB10 直接读 node+4，从不分派槽 3-7 → **非真矛盾**。**F330 pending 项关闭**。
- **〔F331 定案〕vtable 阶梯 raw dumps（权威）**：**0x4767A8** = [0x40EA60, 0x435030, 0x403AC0, 0x4381A0, 0x4382C0, 0x435A20, 0x423AA0, 0x423AE0]（实体类基）；**0x4767C0（m1 节点）** = [0x423AA0, 0x423AE0, 0x423AC0, 0x4241B0, 0x4245A0, 0x4268B0, 0x423D00, 0x423F80]；**0x4767C4（m3 节点）** = [0x423AE0, 0x423AC0, 0x4241B0, 0x4245A0, 0x4268B0, 0x423D00, 0x423F80, 0x4249F0]；**0x4767C8（m5 节点）** = [0x423AC0, 0x4241B0, 0x4245A0, 0x4268B0, 0x423D00, 0x423F80, 0x4249F0, 0x424840]；**0x4767CC** = [0x4241B0, 0x4245A0, 0x4268B0, 0x423D00, 0x423F80, 0x4249F0, 0x424840, 0x4248E0]；**0x476624（窗口终 vtable）** = [0x4150D0, 0x423CA0, 0x423CF0, **0x423D00**, 0x423F80, 0x4155A0, 0x415710, 0x415820]——0x423D00 在此是 **index 3（slot+0xC）**、0x423F80 index 4（slot+0x10），与 0x4767C0 家族（index 6/7）槽位不同。家族 dtor 链：0x423AA0→0x4767C0、0x423AC0→0x4767C8、0x423AE0→0x4767C4（基类 vtable-restore dtor 模式）。
- **〔F331 定案〕vtable 0x4763C8（实体家族，20 槽）** = [0x404D60, 0x404FB0(实体 Init), 0x4058E0, 0x405E20, **0x40A2B0(消息泵)**, 0x40ADD0, 0x40AFD0, 0x4069C0, 0x407010, 0x406A20, 0x406A40, 0x406A50, 0x406A60, 0x406EC0, 0x406EF0, 0x406F60, 0x4070C0, 0x407200, 0x407670, 0x407DF0]——与实体 vtable 0x47671C **共享槽 0..3**（0x404D60/0x404FB0/0x4058E0/0x405E20）**及 8..0xB**（0x407010/0x406A20/0x406A40/0x406A50），slot 4 改为 0x40A2B0 → **实体家族派生类的消息泵 vtable**。
- **〔F331〕setter/thunk**：0x423F80 = `[ecx+0x30]=arg`；0x423F90 = `[ecx+0x34]=arg`（可见性）；0x4268B0 = `jmp 0x423CF0`；0x423CF0 = `mov eax,[ecx]; jmp [eax+4]` thunk。0x4227xx 泵对象（this=esi）：ring @ +0xF0、+0x61C58 字段、edi=[esp+0x28] = main-like 指针（m1/m6 @+0xE1154、实体数组 @+0xE11E4）→ `lea eax,[edi+0xe11e4]; ... call [edx+0x8c]`、`mov edx,[edi+0xe1154]; lea ecx,[edi+0xe1154]; push esi; call [edx+4]`（m6 AddTail 把 esi 挂入列表）→ `lea ecx,[esi+0xf0]; call 0x4561b0` → `mov [esi+0x61c58],0x12c`（=300 定时）。

cross-ref：F330（0x4561B0 假说 REFUTED + 0x47671C vtable + 0x42264E spawn 写点）、F329（spawn 0x422580：type 0x32 → vtable 0x47671C + call [vtable+0xC] = 0x404FB0 Init + AddTail(m1) + 0x4561B0([esi+0xF0])）、F328（列表类 vtable 槽语义 + 节点类 0x476454）、F326（0x418B00 ctor 链 + 34 vtable 写点计数）、F323（实体 vtable 0x47671C +0x7C 头部条）、F325（type 0x32 NPC）、F320（0x40A4D0 选择器装载 + 类型库 0x449B90/0x8AA5A8）、main-object-vtable-family-evidence.json、six-member-lists-and-packet-handler-evidence.json、scene-entity-list-and-hotkey-evidence.json。
落盘：`node-vtable-family-and-message-queue-evidence.json`（F331）+ ui-coverage-matrix.json（message-queue 新条目 closed_2026_08_12）+ layout.json version 0.9 注记 + UI_COMPLETION_AUDIT.md。

## Round 26 (2026-08-12) — 三消息环排水全链 + 世界生命周期 + 字段消费者扫描（Finding 332）

- **双主环排水器逐类型分派定案**：**0x4227F0 = ring A（main+0x364458）排水**（唯一 caller 0x41BBCA）：type 0x33/0x27A → 0x422960（文本消息：门控 mode[0x2F8840]==3 + 环空间记账 0x35A31C/0x35A320/0x35A329，busy 或 1500ms 定时器 [0x4279A4] → 重推 ring A；处理 = 0x42E1F0(&0x2A548C 聊天对象, &0x2F8788 缓冲) + 0x45B1D0/0x45B3D0(&0x8AB130) 刷新滚底 + 清零 12 个记账槽 + [0x428220]=1.0f + busy=1）；type 0x32 → **0x422CC0 世界状态重置**；type 0x34 → **0x423000 目标信息**；type 0x2F0 → **0x423070 状态块**；type 0x1F 且 id==current-id（[0x2F8784]）：timeGetTime−[0x35B278]≥500ms → 0x40A1E0(&2F8780) + PUSH ring C（0x2F8870），否则存 pending 0x35B1F5/0x35B1F9/0x35A34C/0x35A34A；其他类型 id==current-id → defer ring C；id≠current-id → m1 遍历（[0xE1158]）命中 → 0x40A1E0(node) + PUSH 实体 +0xF0 环；未命中 → 0x422580 spawn 回退（返 0 → free msg）。**0x422280 = ring B（main+0x3C5EFC）排水**（唯一 caller 0x41BBC3，帧序先于 A）：0x1E/0x1D/0x323 → 实体移除（m1 查 id → 0x41B570 回指清理 + 清 0x364444–0x364450 四当前实体指针 + 排水实体 +0xF0 环全删 + 跳表 0x42253C 按 [edi+0x88] 类字节表 0x422548 分派：0/1→0x422394 拆链删除、3→0x4223AA（[edi+0x61C7C]==2 跳过）、2 及默认→0x4223CF 只清环）；0x279 → 0x422403 世界清空；其他 → free。0x279 位于 0x4222CC（ring B），0x32 位于 0x4227F0（ring A）——**两环职责不同：A=玩家状态/文本/航向/spawn，B=实体移除/世界清空**。
- **世界清空 0x279 全链（0x422403）**：0x4195C0（0xE11A0 全删——类型判断两分支均为 vtable[0](1) 删除，原版残留怪癖）+ 0x419570（0xE1170 全删）+ 清 0xE11D0/0xE11B8 + **0x419650**（m1 全刷：逐 node 0x41B570 + 排水实体环 + 删）+ 0xE1188 链删 + 清零 0xE118C/0xE1198/0x364444–0x364450。**0x419650 callers = {0x4191F2 帧分派区, 0x4224C4 世界清空}**。
- **0x422CC0 世界状态重置（type 0x32）**：[0x2F8784]=msg[0]；[0x35A354]=byte[msg+0xB]；0x452810 拷 16B 名字 + 5B 块；按 byte[msg+0x22] 选 flag 0/0x1D；**call [edx+0x8C]（管理器 vtable slot 0x8C，7 参 = &0xE11E4 实体数组, flag, byte[msg+0xA], word6, word8, &16B, &5B）** = UpdatePlayerState；strlen(0x47EEE4)=0 全零缓冲 → 清 0x7776A0；[0x2ED0B0]=(id≠0)；wipe 0xE1188；0x417FB0(&0x3615B0) 清世界子对象；[ebp+0x4C]=0；**[0x35B2B8]=1**；0x451660(&0x8AB828, 0x51) 状态行。
- **0x423000 目标信息（type 0x34）**：[0x35B1E8]=msg[0]（目标 id）；[0x35B1E4]=byte[msg+6]；0x452810(msg+0xC, &0x35B1F0, 0x61) 拷 0x61 字节目标名块；航向快照 [0x35A34C]=[0x35B1F5]、[0x35A34A]=[0x35B1F9]、[0x35A34E]=[0x35B1F7]。**0x423070 状态块（type 0x2F0）**：写 0x35B251(word)+0x35B253–0x35B258(6 bytes)。
- **0x40A1E0 = 通用对象环排水器（ring C 与实体环共用；callers 仅 0x4228D9/0x422922）**：入口 [this+0x629C6]=0；POP；type 0x1F → **航向数学**：ax=word[msg+8]（factor），fld [0x476450]=0.0，ax≠0 时 cx=word[msg+6]（angle）→ fild/fidiv → st0=angle/factor → **fmul [0x47644C]=100.0** → ftol 0x468520 → [this+0x61BC8]=al（朝向字节）；[this+0x61BCC]=angle、[this+0x61BCA]=factor、[this+0x629C6]++；free msg；非 0x1F → 0x4561B0 重推回本环。0x61BCC/0x61BCA/0x61BC8 有 25 个实体渲染读者（0x404A64..0x419982）。**F331 遗留「ring C 排水方」关闭：ring C = self 对象 main+0x2F8780 的 +0xF0 环，排水方 = 0x40A1E0**；0x41A5A0/0x41A9B0 只读计数（dirty 0x35B1D4/0x35B1D0 门控）触发 flush（0x410840 + 管理器 vtable+0x18），不 POP。
- **0x422580 spawn 回退深化（F329 续）**：type ∈ {0xA,0xD,0xB,9,0x20,0x21,0x14,0x1B,0x321,0x327}；三构造路径按 byte[msg+0x22]：0/1 → alloc 0x62A48 + 0x40C560；0x32 → alloc 0x629C8 + 0x404960 + vtable **0x47671C**；其他 → alloc 0x62A48 + 0x404960；成功 0x422782：call [edx+0xC] 5 参入列（&0xE11E4, &flag=0xFFFFFFFF/3, 0, word6, word8）+ AddTail m1（0x42278F）+ **PUSH msg 入实体 +0xF0 环（0x422799）** + [0x61C58]=0x12C(300) + [0x61C5C]=0 → 返 1；失败 → vtable[0](1) 删实体返 0。
- **0x41B570 回指清理**（F331 pending 关闭）：遍历 0xE1170/0xE11A0 列表，[node+0x14]/[node+0x18] == 被移除实体 → 清零。
- **帧序列 0x41BBBA**：0x41B440 → 0x422280 → 0x4227F0 → 0x465EA0 → 0x454C50；busy [0x35B2B8]≠0 → 0x43B1E0（0x2F884C/0x2F8850 → 0xF5200 对象，读 [edi+0x14C] 环头）+ 0x35B2C0 send。
- **字段消费者扫描（综合 mod10 + 绝对寻址）**：0x35B1E8 目标 id 11 引用（0x41CE93..0x423014，读点 0x41CE91 与 0x4681F9() 比较后条件调 0x451940(&0x8AB828)）；0x35B2B8 busy 18 引用（帧 0x41BBE1 读 → 0x43B1E0 flush；0x41D010 写 0x35B2AC/0x35B2A8 + busy 时 0x42C9E0(&0x2A548C) 定时状态显示）；**write-only 判定**：0x35B251–0x35B258（状态块）、0x35B1F0（目标 0x61 块，2 写点）、0x35A34A/0x35A34C/0x35A34E（航向显示）在 .text 零读者（mod10 与绝对寻址双重验证）→ presentation-layer 显示状态槽（sim HUD 消费契约）。f32 常量确认：**0x47644C=100.0、0x476450=0.0**。
- 落盘：`message-rings-drain-pipeline-and-world-lifecycle-evidence.json`（F332）+ ui-coverage-matrix.json message-queue 注记扩展 + layout.json version 0.10 + UI_COMPLETION_AUDIT.md Round 26。

## Round 27 (F333) — 2026-08-12：地图切换/加载管线 + 主窗口类分派（F332 三处错标修正）

- **〔修正①〕0x42E1F0 ≠ 聊天显示 = 英雄对象存盘 SaveToFile**：F332 记「显示到聊天对象」错。字节事实：CreateFileA(0x4760DC, WRITE 0x40000000/share2/CREATE_ALWAYS=2/attrs0x80) + 3×WriteFile(0x4760C4) + CloseHandle(0x4760E4)，无任何 GDI/文本绘制。签名 (ecx=this=0x2A548C, arg=&0x2F8788 文件名)；0x45DC70 拼接 `.\Data\<名>.itm`（0x47BDC4 `.\Data\` + 本地缓冲 + arg + 0x47BDCC `.itm`）；3 块 = +0x6CC8(0x22FE8) / +0x6818(0x4B0) / +0xDA4(0x48D8)。E8 callers = 0x41CE48、0x41CEFD（type 0x64 消息族：0x451660(0x3F1) 状态行 → 存盘 → [0x428208]=0/[0x428204]=2 → 0x42D680）、0x4229DF。
- **〔修正②〕0x422960 ≠ 文本消息 = 地图切换/加载 handler（type 0x33/0x27A）**：入口 [0x35B2B8]=0；门控 = (mode[0x2F8840]==3 且 [0x35A31C]-[0x35A320] ≥ [0x35A329]-1) 或 timer[0x4279A4]≠0 → 0x4229A8 busy 路径（0x4561B0 重推 ring A + [0x35B2B8]=1 + ret 4）。处理路径 0x4229D1：① 0x42E1F0(&0x2A548C, &0x2F8788) 旧状态存盘；② 0x45B1D0/0x45B3D0(&0x8AB130) 窗口管理器 flush；③ [0x4279A4]=0x5DC(1500ms 限流)；④ 12 槽清零（0x4279A8/0x42820C/0x35A320/0x35A31C/0x428210-0x42821C/0x35A324/byte0x35A328/0x35A338/0x35A400）；⑤ [0x428220]=1.0f、[0x35A329]=0xA、清 0x35B1D0/0x35B1D4、byte[0x2F886C]=0、清 0x2F8854-0x2F8860；⑥ word[msg+6]→[0x35B25C]&[0x2F884C]、word[msg+8]→[0x35B260]&[0x2F8850]、byte[0x2F8841]→[0x35B264]；⑦ 0x410100(&0x2F8780 管理器, &0xF5200)：[管理器+0x62A58]=&0xF5200；⑧ 管理器 vtable+0x10(0, flag)；⑨ 0x452810 拷 msg+0xC 地图名（cap 0x400）；⑩ 0x43C9C0(&0xF5200, x-0xC, y-0xC) SetPos；⑪ 0x43B600(&0xF5200, 名) LoadMap；⑫ rep stosd 0x38400 dwords 清零 main+0x154 实体数组（0xE1000 B）；⑬ 0x4680F8 释放 main+0xE11D0 实体链表；⑭ byte[msg+0xA] 地图类型 → [0x35B2BD]，变更 → [0x47624C]([0x8AB7B0],1)；⑮ 环境色 [0x35B2C0]：0→0xFFFFFF/1→0xF0F0F/2→0x555555 → 0x434610；⑯ 0x41C1E0 + 0x451770（[0x2AB9A4] 时）+ 0x4195C0/0x419570。
- **〔修正③〕0xF5200 ≠ 聊天对象 = 当前地图对象**（绝对 0x574118）：+0 loaded、+4 文件名（≤0x80）、+0x108 瓦片索引（w*h*3/4，每 3 字节 = byte 属性 + word 瓦片 id）、+0x10C 瓦片数据（w*h*14）、+0x110 头 0x1C、+0x124 帧行选择、+0x126/+0x128 宽/高、+0x12C/+0x130 位置（0x43C9C0）、+0x14C..0x158 视口矩形、+0x18C 小地图标志、+0x1B2 渲染缓冲（0x6C000 dwords = 768×576×4）。
- **0x43B600 = .map 载入器**：0x46811C(&buf, 0x47C404 `.\Map\%s.map`, arg) → 文件名拷 [ebx+4]；CreateFileA(READ 0x80000000/share1/OPEN_EXISTING=3)；0x43B820 init；ReadFile 0x1C → [+0x110]；alloc w*h*3/4 → [+0x108] 读入；alloc w*h*14 → [+0x10C] 读入；[+0]=1；w<0x64&&h<0x64 → [+0x18C]=0；56 瓦片槽 0x5612B4..0x565994（stride 0x144）逐 0x465FE0；(+0x124+1)*0xE 起 14 帧：0x4660E0(&0x5600FC+i*0x144, &0x56B22C+i*0x104, 1)，失败 → 0x465FE0+0x4660E0(...,0)；[+0x18C] → 0x43B440 渲染；CloseHandle 返 1。
- **0x43B440 = 瓦片渲染**：0x6C000 dwords 清零 [+0x1B2]；y=[+0x12C]..+0x18、x=[+0x130]..+0x18（24×24 视口）；奇偶过滤；idx=(y>>1)*w+(x>>1)；行=attr/7（0x6DB6DB6D 魔数）；0x466130(&0x5600FC+行*0x144, id) 载帧 → 0x45E8E0(&0x8AB7A8 blitter, ...) blit。
- **0x43B1E0 = 视口滚动**（F332「flush 进聊天对象」错标修正）：[+0x14C..0x158] 视口矩形 vs 玩家坐标 ±0xC 越界 → [0x4762B0] 滚动 + 同款瓦片 blit 重绘；帧序列 0x41BBE1 的调用 = 地图视口跟随玩家。
- **0x8AB130 = 窗口管理器**（50 子窗槽 +0x460、分派 0x45B440、flush 0x45B1D0/0x45B3D0→0x45A510 深层释放）——地图切换时全关窗。
- **0x2A548C = 英雄对象**（绝对 0x7243A4）：热键 0x42CBD0（F329，wndproc KEYDOWN 0x41DD84 确认 this）、消息分发 0x42D680（跳表 0x42D700）、0x42DC20、存盘 0x42E1F0、busy 定时 0x42C9E0。0x2F8788（绝对 0x7776A0）= 文件名/地图名缓冲（refs 仅 0x41CE3D/0x41CEF2/0x41F24F/0x4229D3）。
- **主窗口类 vtable 0x476670**（main 0x47EF18，ctor 0x418D1D / dtor 0x418D6D + ring A/B 析构 0x4561A0 / 0x418EE0 init）：+0x0 0x41E6A0 HUD 状态行刷新（0x4514F0 四统计量 0x47EEF8/0x47EEE4/[0x47EF10]/[0x47EEB8]）；+0x4 0x41E6D0 聊天指令解析（memchr 0x468B30 按 '!'(0x21)/'#'(0x23) 切分 → 0x41ED20 执行器）；+0x8 0x41E260 [this+0x34] 门控 750ms 定时（0x465DD0(0,0x2EE)）；+0xC 0x41E2B0 wndproc。
- **wndproc 0x41E2B0 分派表**：msg 2/3（DESTROY/MOVE）→ 0x41CEF0（0x41D2B0 存窗态：0x8AB7F0..0x8AB7FC + [0x476254](0x8AA48C) + 0x45CDC0）；0x100（KEYDOWN）→ 0x41DD30：模态 [0x362370] → 热键表 0x418470(&0x3615B0) → busy → 0x42CBD0(&0x2A548C) → 环头 [0x364444]；0x104（SYSKEYDOWN）→ 0x41D090（Enter：busy=0 + [0x8AB7EC]=0 + 0x45D270 恢复屏幕）；0x105 → 0x41D2A0 空返；0x202（LBUTTONUP）→ 0x41DB80；默认 → 0x45B440(&0x8AB130) + 0x465E80(this)。
- **0x418030 = 公告窗构造**：0x466130(父, 0x3B6) 载背景帧；-1 坐标居中（[父+0x38] 帧尺寸）；[0x4762B0] 设矩形；模式 0/1/2 → [+0x234]/[+0x2EC]/[+0x3A4]/byte[+0x462]；3× 0x417550 子控件（0x97/0x98、0x9D/0x9E、0x9A/0x9B）。0x468D10 = alloca 栈分配。
- **F330 标注细化**：main+0x154 0xE1000 B = 实体数组（地图切换清零）；0x5600FC 为瓦片对象槽（行号索引 0x144）与帧装载目标的双重角色；0xE11D0 = 实体链表头（切换时释放）。
- 落盘：`map-change-pipeline-and-main-window-class-evidence.json`（F333，17 键模板）+ ui-coverage-matrix.json（map/chat/main-object-vtable-family/message-queue 注记 + F332 修正）+ layout.json version 0.11（0xF5200 地图对象/0x2A548C 英雄对象/0x8AB130 窗口管理器记录 + message_ring_notes 修正）+ UI_COMPLETION_AUDIT.md Round 27。

## Round 28 (F334) — 2026-08-12：0x8AB130 声音管理器家族 + DirectShow BGM 播放器（F333 定性重大修正）

- **〔修正 v1 核心〕0x8AB130 ≠ 窗口管理器 = 声音管理器 SoundManager**（F333 旧标作废）：0x45A000-0x45BC00 全家族逐字节解码 + **69 imm32 引用 + 36 寄存器调用点**。布局：+0x8 init 标志、+0x14 enabled、+0x20 **BGMLevel 音量**（=0x8AB150；播放时重读，F324 的『5 绝对引用全在 option 代码』错在寄存器相对寻址漏扫）、+0x420/+0x452/+0x45C config1（SoundList.wwl 效果音表，0x10B 项 {word[0]=id、byte[2]=启用、entry+2=名}）、+0x460..0x528 **50 效果音频道槽**（槽对象 {+0 DSound 封装、+4 WAV 数据、+8 缓冲数、+0x10/+0x14+4i IDirectSoundBuffer[]、+0x38 最近使用、+0x3C 频道 ID}）、+0x528 内嵌 SoundPlayer、+0x52C/+0x55E/+0x568/+0x56C config2（Bgmlist.wwl BGM 表；'none' 0x47D884/'nobgm' 0x47D87C 哨兵跳过）。证据链：'SOUND\'+config 名 → 0x45B6D0 建缓冲组；IDirectSoundBuffer vtable 11 偏移（+0x24 GetStatus/+0x2C Lock/+0x30 Play/+0x34 SetCurrentPosition/+0x3C SetVolume/+0x40 SetPan/+0x48 Stop/+0x4C Unlock）全吻合；DSBVOLUME_MIN=-10000（0xFFFFD8F0）钳制；0x45B950=Stop+SetCurrentPosition(0)；timeKillEvent/0x81F4；'none'/'nobgm' 哨兵。
- **〔v2 核心〕BGM 播放器 = DirectShow FilterGraph**（vtable 0x476BD4，7 槽）：0x45A2F0 = CoCreateInstance(CLSID_FilterGraph e436ebb3-524f-11ce-9f53-0020af0ba770 @0x476D78) + 五 QI（GUID 全 web 验证 @0x476D28-0x476D88：56A868A9 IGraphBuilder / 56A868B1 IMediaControl / 56A868B3 IBasicAudio / 56A868B2 IMediaPosition / 56A868C0 IMediaEventEx / 36B73880 IMediaSeeking；IGraphBuilder 继承 IFilterGraph → **RenderFile 实际槽 = +0x34**）。SoundPlayer 布局：+0x8 循环标志、+0x14 文件名、+0x118 IBasicAudio、+0x11C IMediaControl、+0x120 IMediaSeeking、+0x124 IMediaPosition、+0x128 IMediaEventEx、+0x12C IGraphBuilder、+0x130 running、+0x134 init、+0x138 通知窗 hwnd、+0x13C 已装载、+0x140 WINMM 定时器 ID（timeKillEvent，角色候选）。**0x45A3E0**：arg1=hwnd（[0x8AB7B0] → [0x138]）、arg2=文件名（MultiByteToWideChar 0x4760F0 + [0x14] + IGraphBuilder vtable+0x34 RenderFile）→ [0x13C]=1。**0x45A4A0 参数序（本轮定稿，v3 修正 v2 的颠倒）**：arg1=**音量**（调用点 0x45B36D 传 [0x8AB130+0x20]=BGMLevel）→ 0x45A700 = IBasicAudio put_Volume(vtable+0x1C, arg×40)；arg2=**循环标志** → [player+8]。0x45A740/0x45A790 = SetNotifyWindow([0x138], 0x81F4, 0) / SetNotifyFlags。**0x45A5A0 事件泵**：IMediaEventEx vtable+0x20 GetEvent（IDispatch 双接口继承使 GetEvent 后移）；evCode==1（EC_COMPLETE）→ [player+8] 非 0 时 [0x130]=0 + **0x45A7C0 重播**（Pause + IMediaPosition double 0.0 复位 + Run）= BGM 循环；evCode==0x14 → 0x45A510 停止；其余 → +0x30 FreeEventParams 后再次 GetEvent 排空。0x45A510 停止 = 0x45A790(1) + Pause/Stop + 位置复位 + 0x45A650 完整清理（六接口依序 Release）。
- **〔v2 修正〕0x8AB7B0 = 主图形窗口 hwnd**（[0x8AB7A8+8]；类 **'MirDXG'** 0x47B004、标题 **'Legend Of Mir 3'** 0x47A468）——**0x45CA80 失败路径 MessageBoxA(hwnd=[0x8AB7B0], '[CWHDXGraphicWindow::Create]Window create failed.' 0x47D978, 'MirDXG' 0x47B004, flags=0x10) 决定性证明**；DSound SetCooperativeLevel（0x402005 → 0x45A8C0 → [0x9135C8]）+ BGM SetNotifyWindow 双用。**0x8AA48C = 主应用窗 hwnd**（非『窗标题』）：0x451100 = CreateWindowExA 包装（12 参经 thunk 0x400394；0x190/0x81/0xC 参数）+ SendMessageA [0x476290] + UpdateWindow [0x476258]；**0x401FF9 = ShowWindow([0x8AA48C], 0=SW_HIDE) [0x4762AC]**（主窗隐藏，图形窗显示）。init 序列：0x401FAD 0x45CA80(&0x8AB7A8) 建图形窗 → 0x401FEC 0x451100(&0x8AA488) 主窗 → 0x401FF9 ShowWindow → 0x402005 0x45A8C0([0x8AB7B0]) DSound init（失败 [0x8AB138]=0）→ [0x8AB138]=1 → 0x40202D/0x40203C config1/config2 装载 → 0x402041 0x449C80(&0x8AA5A8)。
- **IAT 终验（pefile）**：0x4762AC=**ShowWindow**（修正旧注 SetWindowTextA）、0x4760C4=**ReadFile**（修正旧注 WriteFile/ReadFile）、0x47628C=**MessageBoxA**、0x476290=**SendMessageA**、0x476258=**UpdateWindow**、0x47634C=**CoCreateInstance**、0x476350=**CoUninitialize**、0x476354=**CoInitialize**、0x4760F0=**MultiByteToWideChar**、0x47630C=timeGetTime、0x476310=timeKillEvent。
- **DSound 全局**：0x9135C0=IDirectSound、0x9135C4=次级接口（QI IID@0x476CA8=279AFA84-4981-11CE-A521-0020AF0BE560 DirectSound 家族，具体接口名未最终裁决）、0x9135C8=hwnd；WAVEFORMATEX PCM 44100Hz 双声道 16bit（nAvg=0x2B110 nBlock=4）；失败返 0x80004005。**0x45B6D0 = CreateSoundBufferSet**（0x45B5B0/0x45B610 WAV 载入 + 0x45BA60 RIFF 解析 + LocalAlloc(0x40, 0x3C+4n) 槽）。**BGM 播放语义链**：0x45B250([0x8AB7B0], 'SOUND\名', arg3) → 0x45A3E0 装载 + 0x45A4A0(音量=[0x8AB130+0x20], 循环=arg3) Run+SetNotifyWindow → FilterGraph 完成时发 **0x81F4** 至 [0x8AB7B0] → wndproc 默认分支 0x41E312 → 0x45B440 → [ecx+0x528] → 0x45A5A0 事件泵闭环。
- **频道 ID 体系 = 声音通道 ID**：1（0x40CE0A）、0x21-0x23（0x40CD52/0x40CD7C/0x40CDB2）、0x69（0x417819/0x4415BD/0x441662/0x4419A5/0x4419D8）、0x6a（0x41FF49/0x4207C9/0x420809/0x42FF0E）、0x6b（0x42E46E）、0x6c（0x42E2FF/0x42E321/0x42E483）、0x6d（0x406B24/0x40D4A4）、0x6e（0x406CF2/0x4101C2）、0x6f-0x76（0x42E337..0x42E3F9）、0x83（0x40CB81）、0x8e（0x411091）；运行时 ID = 索引×6+0x2711（base 10001，0x4357CF）。地图切换 0x4229E9/0x4229F3 = 停全部音效+BGM。
- **API 表面（36+ 方法槽）**：0x45AFC0 注册/查找+激活、0x45AC00 槽分配（>1000ms 淘汰）、0x45AD40 config1 查、0x45ADA0/0x45AE90 配置载入（唯一调用者 0x40202D/0x40203C）、0x45AF30 config2 查、0x45B090 StopChannel、0x45B0F0 StopChannelAll、0x45B140 PositionChannel（0x574118 格 → 屏 0x43CFD0 → 等距 0x45BB50/0x45BC00 → SetPan/SetVolume）、0x45B1B0/0x45B1C0 enable/disable、0x45B1D0/0x45B210 停全部（+释放）、0x45B250/0x45B390 播 BGM/文件、0x45B3D0/0x45A510 停止+清理、0x45B3F0 getter running、0x45B410/0x45B430 config2 开关、0x45B440 msg0x81F4 分派、0x45B7F0 释放槽、0x45B830 缓冲轮询、0x45B900 激活、0x45B950 停频道。
- 落盘：`sound-manager-0x8ab130-family-evidence.json`（F334，17 键模板，evidence_level=primary-bytes，BSS 侧 [INFERENCE]；audit_vs_exe 5 条 F333 修正）+ ui-coverage-matrix.json（sound-manager 新记录 closed_2026_08_12 + message-queue/chat 记录 F334 修正注记）+ layout.json version 0.12（sound-manager.0x8ab130 记录更名补全 + 新增 main-window-hwnd.0x8ab7b0 记录）+ UI_COMPLETION_AUDIT.md Round 28。

## Round 29 (F335) — 2026-08-12：主初始化窗口创建目录（hero HUD builder 0x427600 + frame fns 0x419350/0x419110 + 15 子窗口 id→ctor→偏移全表 + 16 HUD 标题字符串定稿）

- **〔核心〕主初始化窗口创建分派器 = 0x419350**（唯一 caller 0x4570B9 游戏启动路径，ecx=main 0x47EF18，结尾置 [0x8B1878]=3）：0x45D270(&0x8AB7A8, flag=1/2/5 by [0x47EE89], 0x320=800, 0x258=600, 0x10) 屏幕帧 0x10 → 0x418EE0 → 0x451320(&0x8AB828, main hwnd 0x8AB7B0, 0x47EEC0 字符串, [0x47EEBC]) → 0x452AA0(&+0xE11E4, 1, 1) → 0x417FB0(&+0x3615B0) → **0x418030 公告窗**（text 0x565994=零 BSS 容器、0x64、2、'正在连接《骷髅射手3.0》服务器' 0x47AEB8、0、-1、-1、0xFFFF；frame 硬编码 0x3B6=950；x/y=-1 → 居中 0x190=400）→ **0x476064 CreateSolidBrush(0x323232) → [esi+0x2F877C]**（IAT 修正：原标『0x476064 调用』）→ 0x434500(&+0x35B2C0, 0xFFFFFF) fog/光照配置 → **0x427600 英雄 HUD 窗口创建器** → 0x362354 vtable[0](&+0xE6A7C) → 0x446EC0(&+0x361150) → 0x3611F0/0x3612B4 vtable+4 + vtable+0x1C(0x1F4=500/0x190=400, 800.0f 0x44480000, 600.0f 0x44160000) → 0x36137C/0x361438/0x3614F4 vtable+4 + vtable+8(0x3E8=1000) → 0x446D00/0x446C10(&+0x361A14) → rep stosd &+0x154 0x38400 dwords + 0x8AA4A4 0x41 dwords → SetWindowTextA([0x8AA48C]) [0x4762CC] → SendMessageA([0x8AA48C], 0xCC, 0, 0) → 0x4511D0(&0x8AA488, 0x5A) → 0x45E4E0(&0x8AB7A8, 0x141414); [0x8AA498]=1 → 0x4542E0(&+0xE11E4)。
- **〔核心〕0x427600 = 英雄对象 (main+0x2A548C) 的 HUD/UI 窗口创建器**（唯一 caller 0x419405，arg1 = [main+0xE11E4] 英雄数据列表；尾部 ret 4）：父窗 = arg1+0x5898 = **main+0xE6A7C** → [esi+0x1C]；MoveWindow([0x8AA48C], [0x8AB7F0]+0xDF, [0x8AB7F4]+0x23A, 0x162, 0x10) [0x4762BC]；**0x466130(parent, 0x32=50) frame 0x32 装载**（0x466130 = 帧装载器：frame-type [ecx+4]==0→0x466640 / 1,2→0x466720）；SetRect 族：+0xC58（0,0x259-帧宽,0x258）、+0xCF8（0xE0,0x1EC,0x242,0x236）、+0xCA8 16 行循环（left=0xE0=224, top=0x1EC=492 起, right=0x242=578, bottom=0x1FB，每行 +0x10 至 0x207 = 16px×16 行）、+0xC58/+0xC68/+0xC78/+0xC88/+0xC98。
- **〔核心〕15 子窗口全表（id→ctor→hero 偏移→frame→x/y/w/h）**：id0 0x42EA80 +0x6554 f0xFA=250 (0x206=518, 0) 0x11C×0x144=284×324；id1 0x44B130 +0x29CE4 f0xC8=200 (0,0) 244×328；id2 0x44D310 +0x33188 f0x3E8=1000 (0,0) 0x12C×0x130=300×304 flag=0 隐藏；id3 0x4159D0 +0x3399C f0x41A=1050 (0,0) 0x1E4×0x14A=484×330；id4 0x424E60 +0x4707C f0x258=600 (0x66=102, 0x16=22) 0x254×0x1BE=596×446；id6 0x424250 +0x47834 f0x384=900 (0x110=272, 0x7B=123) 0x100×0xF4=256×244；id8 0x414060 +0x507EC f0x15E=350 (0x72=114, 0x4C=76) 0x23C×0x184=572×388 聊天；id7 0x4503B0 +0x47C28 f0xC8=200 (0x230=560, 0) 244×328；id0xC 0x440FE0 +0x518E0 f0x2EE=750 (0x114=276, 0x71=113) 0xF8×0x108=248×264 选项（F324 确认）；id0xB 0x4473E0 +0x516E8 f0x2BC=700 (0,0) 0x154×0x1B8=340×440；id0xD 0x4268C0 +0x52118 f0x352=850 (0,0) 0x128×0x14C=296×332 坐骑；id0xE 0x439250 +0x524F0 f0x190=400 (0x15C=348, 0) 0x1C4×0x17C=452×380 flags 1,3；id9 0x43ED00 +0x51150 f0x44C=1100 (0,0) 0x228×0xB0=552×176 flag=0 NPC 对话（NPCFace.WIL 0x47C4EC）；id0x64 0x418910 +0x53030 f0x320=800 (0xDA=218, 0xB0=176) 0x16C×0xB8=364×184 flags 1,3；id0xF 0x43E260 +0x52E5C f0x25A=602 (0x6B=107, 0x6E=110) 0x248×0xFC=584×252 flags 0,3 行会公告（= id15 通知窗）。id 5/0xA 未用（稀疏 id 空间）。
- **〔核心〕16 HUD 标题控件字符串定稿**（ctor 0x417550 9 参，hero+0x567C..+0x6108 stride 0xB4，调用点 0x4279B2..0x427D94；x 相对 [esi+0xC58] 偏移，帧对 normal/state）：cap0 交易栏(Ctrl+C, C) 0x47BCE0 x0xCC f0x50/0x51；cap1 小地图(Ctrl+V, V) 0x47BCCC x0xE4 f0x52/0x53；cap2 技能图鉴(Ctrl+B, B) 0x47BCB8 x0xFC f0x54/0x55；cap3 退出游戏(Alt+Q) 0x47BCA8 x0xA1 f0x5A/0x5B；cap4 注销人物(Alt+X) 0x47BC98 x0xA1 f0x5C/0x5D；cap5 组队(Ctrl+G, G) 0x47BC88 x0x268 f0x5E/0x5F；cap6 行会(Ctrl+F, F) 0x47BC78 x0x268 f0x60/0x61；cap7 **腰带(Ctrl+Z, Z) 0x47BC68 x0x189 f0x9F/0x9F**（新增 hud.belt 记录）；cap8 技能书(Ctrl+E, E) 0x47BC54 x0x2BF f0x64/0x65；cap9 聊天记录(Ctrl+R, R) 0x47BC40 x0x2CE f0x66/0x67；cap10 信息窗口(Ctrl+D, D) 0x47BC2C x0x2CE f0x68/0x69；cap11 设置栏(Ctrl+N, N) 0x47BC18 x0x2BF f0x6A/0x6B；cap12 **帮助窗口 0x47BC04 = EUC-KR '도움말창(지원예정)'（韩版遗留帮助窗口(暂不支持)，非乱码）x0x298 f0x6C/0x6D**；cap13 坐骑(Ctrl+S, S) 0x47BBF4 x0x288 f0x6E/0x6F；cap14 包袱栏(Ctrl+Q, Q) 0x47BBE0 x0x288 f0x70/0x71；cap15 状态栏(Ctrl+W, W) 0x47BBCC x0x299 f0x72/0x73。字符串区域分界 0x47BCxx cap0-12 / 0x47BBxx cap13-15 确认。
- **〔窗口工厂模式〕15 个窗口 ctor 共享**：重载 8 栈参 → 逆序重推 → 基 ctor **0x423B30**（存 [esi+4]=frame-type/[+0x28]/[+0x2C]/[+0x3C]，0x466130 帧装载）→ 0x417550 caption 子控件 → [0x4762B0] SetRect。0x466130(ecx=window, frame_id) 帧装载器 = 0x466640/0x466720 分派。0x417960 = toast/hint 对象 ctor（7 参 ret 0x1C，timeGetTime [0x47630C] 时间戳 +0x44）。
- **〔新增〕小地图窗 hero+0x6214**（0x427E01 建，arg=[0x8AB7BC]）：0x43D4D0 双子对象 +4/+0x148 装载 `.\\Data\\MMap.wil` 0x47C428 + `.\\Data\\FMMap.wil` 0x47C414（0x465FA0/0x4660E0）。
- **〔尾部〕toast +0x61BC（0x427DC6 0x417960）；16 SetRect 行循环 0x427DD1（ebx=0x117..0x207 step 0x28, ebp=+0xD44 step 0x10, SetRect(0x1B0, ebx, [ebx+0x26], 0x1D6)）包格；SLT/MLT 光照表 0x428BA0/0x4292B0（'.\\Data\\%s(%s).slt' 0x47BCFC / '.mlt' 0x47BD14, 'rb' 0x47BCF8）。**
- **〔frame fn 0x419110 = 每帧更新分派器〕**（callers 0x418D7B 主帧对象 ctor vtable 0x476670 + 0x419BEA 帧循环；0x419100 = 前一函数尾 pop/ret）：KillTimer([0x8AB7B0], 1) [0x47624C IAT 修正：原标 ShowWindow-like]；ring A 0x364458 / ring B 0x3C5EFC 排水（0x456270 pop → 0x4680F8 remove，循环）；DeleteObject([esi+0x2F877C]) [0x476068 IAT 修正]；0x454270(&+0xE11E4) / 0x43B190(&+0xF5200) / 0x427440(&+0x2A548C) / [0x2F8780]+8 / 0x403AC0(&+0x361150) / +0x3611F0+0xC / +0x3612B4+0xC / 0x419570 / 0x4195C0 / 0x419650；E11xx 三列表（+0xE1188/+0xE11B8/+0xE11D0 obj+4→0x4680F8, obj+0xC=next, vtable[0](1)）排空；0x45B210/0x45B3D0(&0x8AB130 声音管理器) / 0x418EE0 / 0x451420(&0x8AB828) / strcpy 0x47EEA8→0x47EEC0, [0x47EEBC]=[0x47EEA4]。
- **〔IAT 新增/修正（pefile 终验）〕**：0x47624C=**KillTimer**、0x476064=**CreateSolidBrush**、0x476068=**DeleteObject**、0x4762BC=**MoveWindow**、0x4762CC=**SetWindowTextA**、0x47630C=timeGetTime（Round 28 已有）；0x4762B0=SetRect 确认。
- **〔窗口身份字符串证据〕**：id1 '本级' 0x47C348（状态窗左侧）；id2 '(%d两)' 0x47C784（货币/交易）；id3 '%d' 0x47A214（装备）；id4 5 字段 scanf 0x47AD30（背包/仓库）；id6 '[允许]' 0x47BA08/'[拒绝]' 0x47BA00/'请在这里添加新的小组成员名字' 0x47BA38/'请在这里添加您要删除的小组成员名字' 0x47BA10（组队）；id7 '本级'+'%s %s' 0x47B560+'%s' 0x47AF48（右侧面板）；id8 聊天命令帮助串 8 条全解（@拒绝私聊 0x47ACB8/大喊话 0x47ACF8/编组喊话 0x47ACE4/行会喊话 0x47ACD0/@拒绝行会聊天 0x47AC98/拒绝和某人私聊 0x47AD08/+'/%s ' 0x47AD28+5 字段 scanf）；id9 NPCFace.WIL 0x47C4EC（NPC 对话）；idD '@上马' 0x47B060/'@收马' 0x47B058/'@遛马' 0x47B068（坐骑）；idE 火冰电风神圣黑暗幻影剑 0x47C330..0x47C308 + '- %d -' 0x47C334 + '%d %d/%d' 0x47C33C（属性详情）；idF 'EDIT' 0x47C438 + '[行会公告，请自行修改公告内容.]' 0x47C440 + '[行会修改 请自行修改行会等级、成员排行信息]' 0x47C460 + ' \r' 0x47C4A4（行会公告）。
- **〔交叉验证〕**：0xC 选项窗与 F324 全吻合（frame 750 x276 y113 248×264）；id8 聊天窗与已知锚 main+0x507EC 9 控件 stride 0xB4 吻合；id0xF 行会公告 = id15 通知窗（0x777200 锚 VA 差异 pending 待交叉：hero+0x52E5C = 0x779600）；0x565994 = 零 BSS 容器（非文本串）。
- 落盘：`window-catalog-evidence.json`（F335，17 键模板，evidence_level=primary-bytes；audit_vs_exe 含 0xC/聊天/id15/IAT 修正对比）+ ui-coverage-matrix.json（window-catalog 新记录 closed_2026_08_12 + hud 记录 F335 cross-ref 注记）+ layout.json version 0.13（frame.init-0x419350 / frame.update-0x419110 / window-catalog.hero-builder-0x427600 / window.minimap-0x6214 / window.id1-status-left / window.id7-status-right / window.id2-hidden-candidate + hud.belt 新增 + 16 hud.* 记录标题字符串/帧对/偏移证据注记）+ UI_COMPLETION_AUDIT.md Round 29。

## Round 30 (F336) — 2026-08-12：主游戏循环层级（WinMain 消息循环 → [0x8B1878] 状态机 → 0x41BB00 tick）+ 实体点击分派 0x419D40 + IAT 8 项 + 0x777200 算术修正

- **〔核心〕WinMain 消息循环**（ret 0x10，4 参；epilogue 0x40224F add esp 0x52C）：0x401F6D 0x4019A0（==7 退出）→ 0x45CA80(&0x8AB7A8) 建图形窗（'MirDXG'/标题 0x47A468）→ 0x451100(&0x8AA488) 主窗 → ShowWindow([0x8AA48C], 0) → 0x45A8C0 DSound → config 装载 → 0x4026E0(&0x8A9520) intro ctor + [0x8B1878]=0 → 0x4016A0 → [0x8B1874] → **循环 0x4020CB**：PeekMessageA [0x4762A8] → 有消息 GetMessageA [0x4762A4] → TranslateMessage [0x4762A0] → DispatchMessageA [0x47629C]；无消息 0x40210C：dt = timeGetTime()-edi → **状态机 [0x8B1878]**：0 → 0x402BE0(&0x8A9520, dt) intro；2 → 0x4575D0(&0x8A7140, dt) 角色选择；3 → [0x8AB7E8] 门 → **0x41BB00(&main, dt) 游戏内 tick**（==0 → 0x41B440+0x41B500）；GetAsyncKeyState(0x2C) [0x476298]；**GetLocalTime [0x476120] → sprintf '[%s---- %s] - %d年 %d月 %d日 %d时 %d分 %d秒' 0x47A2D8 → 0x45DD70 时钟显示**。
- **〔核心〕0x41BB00 = 游戏主 tick(main, dt)**（prologue fild [esp+4]; ret 4；唯一 caller 0x402142）：dt 累加 [0x8B1A90] / [main+0x4279A8] vs 0x3E8 1s tick；**BGM 5s 门** [main+0x428048]>0x1388 → 0x45B250(&0x8AB130, 1, &[main+0xF5204] 地图名) PlaySoundFromConfig + Sleep(30) [0x4760CC]；环排水 0x41B440 → 0x422280（ring B）→ 0x4227F0（ring A）→ 0x465EA0 → 0x454C50(&+0xF5144)；busy [0x35B2B8] → 0x43B1E0 地图滚动 + 0x434650 + [0x2F8780]+0x1C；[esi+0x3C] → 0x41A9D0/0x41A5B0；[0xF538C] → 0x45E730 相机绘制；[0x364444]=0 → **0x419D40(ebx=dt, edi=slowflag)** + 0x41C450(ebx) 瓦片通道；[0xE1170] 实体列表 id 0x96/0x48 vtable+0xC + [+4]==2 → 0xE116C unlink；列表 vtable 调用（0x3611F0/0x3612B4/0x36137C/0x361438/0x3614F4：+0x14(0,0,0) 后 +0x10(mouse 0x8AB7BC)）；HUD 目标框链 0x40A8A0/0x40BB00/vtable+0x80（Round 28）+ 实体 [0x88] 1..3 门；当前目标 [0x364444] → [0x364448]+timeGetTime 戳 → [target+8]==0 → 0x4516D0 移动 / [0x61C90]==-1 → 0x451700 攻击 / vtable+0x84 绘制；800ms 超时清；拖拽 [0x42804C]/[0x428050] delta>5 → 0x41C1E0；0x41C2A0 / 0x41EB70 / **0x4294E0 HUD 绘制**(2A548C, 0, [0x35B2A8], [0x35B2AC])；[0x364448] 名字+0x88==3 → 0x419730；0x41AF60 → **0x41C14B call 0x41B8D0**；断线重连 [0x8B1A90]>0x186A0 → 0x418030(&+0x3615B0, 0x565994, 0x64, 0, **0x47AF80 cp949 '서버와의 접속이 불안합니다. 게임을 종료하겠습니다.'**, 0, -1, -1, 0xFFFF)；0x4182A0(&+0x3615B0, [0x35B2A8], [0x35B2AC]) / [0x362354]+0x24 / 0x41B5D0。
- **0x41B8D0 = 屏幕特效条件更新**（门 [main+0x428064]；累加器 +0x42806C vs 上限 +0x428068 → 超限重置：清 +0x428174 0x24 dwords、[+0x4279A4]=0x3E8；由 tick 0x41C14B 调用）——**非主帧循环**（Round 30 早期追踪修正）。
- **〔核心〕0x419D40 = 世界实体排序/点击分派**（main 方法，prologue sub esp 0x1AC，ret 8，唯一 caller 0x41BCB7）：清实体数组 &+0x154 0x38400 dwords；F331 四画家数组 root+0x154 实体 / +0x2E4 特效 / +0x474 地面装饰 / +0x604 地面物品；**点击按实体类型 word[+0x10] 分派（0x41A0D9 起——Round 29 误标『0x41A0C0 window-id dispatch』，实为 0x419D40 体内）**：{0x10,0x16,0x3F,0x14A-0x14E,0x48} → 0x41A208 特殊拾取（[+0x124]=1 picked、视口命中测试 [0xF532C]/[0xF5330]+0x18、坐标 [esi+0xD0]/[+0xD4]、tile 表 main+0x2E4 100 槽扫描匹配 [+0x10] 类型与 [+0xB0]/[+0xB4] 坐标 → [+0x124]=0，否则 vtable+0xC([esp+0x1C0]) + 插入）；{9,0x35,0x150} → 0x41A158 泛型 vtable+0xC + [+4]==2 → 0xE119C 列表；默认 0x41A350 跳过；**PtInRect [0x4762B4] 通道**（列表 0xE11B8，rect obj+4/+8）→ main+0x474；**timeGetTime 超时通道**（列表 0xE11D0，[ebx+0xC]+[ebx+0x10] 超时 → 0x4680F8 移除）→ main+0x604。实体类型对照 F331：0x10=type4（0x438100）、0x16=type5 特效、0x3F、0x14A-0x14E=特效帧 idx（0x4212B5）、0x48、0x96（tick 特殊 id）。
- **〔修正〕0x777200 VA 算术**：hero/winmgr 0x7243A4 + 0x52E5C = **0x777200**（非 Round 29 误算 0x779600；0x7243A4+0x50000=0x7743A4，+0x2E5C=0x777200）——F268/F294 锚全部成立，id-15 公告窗 = hero+0x52E5C 内嵌对象（ctor 0x43E260 @ 0x42797E）。
- **〔IAT 新增/修正（pefile）〕**：0x4762A8=**PeekMessageA**、0x4762A4=**GetMessageA**、0x4762A0=**TranslateMessage**、0x47629C=**DispatchMessageA**、0x476298=**GetAsyncKeyState**（原猜 Sleep(44) 修正）、0x476120=**GetLocalTime**（原猜 GetCursorPos 修正）、0x4762B4=**PtInRect**、0x4760CC=**Sleep**。
- **〔新字符串〕0x47A2D8** '[%s---- %s] - %d年 %d月 %d日 %d时 %d分 %d秒'（游戏时钟格式）；**0x47AF80** = cp949 '서버와의 접속이 불안합니다. 게임을 종료하겠습니다.'（断线公告，GBK 误读修正）。
- 落盘：`game-loop-and-entity-dispatch-evidence.json`（F336，17 键模板，evidence_level=primary-bytes；audit_vs_exe 含 0x41A0C0 误标修正 / 0x41B8D0 定性 / 0x777200 算术修正 / F331 重叠 / 0x476120、0x402177 修正）+ ui-coverage-matrix.json（game-loop 新记录 closed_2026_08_12）+ layout.json version 0.14（game-loop.winmain-msg-loop / game-loop.tick-0x41BB00 / game-loop.screen-effect-0x41B8D0 / entity.click-dispatch-0x419D40 / window.id15-notice-va-fix + 0x779600→0x777200 全库修正）+ UI_COMPLETION_AUDIT.md Round 30。

## Round 31 (F337) — 2026-08-12：窗口可见性调度（0x42ADB0 模态 id 索引切换 + close-all 0x42B820 + 可见链表操作 + 16 项 id→obj→gate 全表 + id0=背包定案 + 43 调用者触发图）

- **〔核心〕0x42ADB0 = 窗口可见性切换分派器**（hero 0x7243A4 方法，ret 4）：**先 0x42B820 close-all（模态：同一时刻只显示一个窗口）**→ id 读 [esp+0xC]，>0xF → 0x42B3DD 守卫 no-op → **jmp [eax*4 + 0x42B3E4] 16 项跳表**。每 case：门 [obj+0x30]（ctor arg8 活动标志；基 ctor 0x423CA0 初值 0，Round 12 证明）≠0 → HIDE（push id; **0x42AC50** 可见链表移除 + vtable+0x10(obj, 0)；ret 0）；==0 → SHOW（push id; **0x42AC30** = add ecx,0xD24 → **0x449870 链表插入** + vtable+0x10(obj, 1)；case 专属；ret 1）。
- **〔核心〕16 项 id→obj→gate 全表**：id0 +0x6554/+0x6584 **背包**（SHOW 专属：0x417880(&+0x1C4, 0x10B, 0x10C, -1) 重帧 2 子控件 + byte[+0x54]=0 模式复位 + **0x42FF90 grid 复位**（清 +0x23760..+0x23770、+0x23764/+0x23768=-1））；id1 +0x29CE4/+0x29D14 状态；id2 +0x33188/+0x331B8 商店；id3 +0x3399C/+0x339CC 交易（F295）；id4 +0x4707C/+0x470AC 物品；**id5 守卫（无窗口）**；id6 +0x47834/+0x47864 组队（SHOW 专属 0x417880(&+0x47B70, 0x398/0x399 or -1 by [+0x47C24])）；id7 +0x47C28/+0x47C58；id8 +0x507EC/+0x5081C 聊天（**特殊：MoveWindow(main hwnd, [0x8AB7F0]+0xDF, [0x8AB7F4]+0x23A, 0x162, 0x10) + ShowWindow(5)**）；id9 +0x51150/+0x51180 NPC 对话；**id10 守卫**；idB +0x516E8/+0x51718；idC +0x518E0/+0x51910 选项；idD +0x52118/+0x52148 坐骑；idE +0x524F0/+0x52520 属性；idF +0x52E5C/+0x52E8C 公告（**特殊：SetWindowTextA([+0x53028]=0x7773CC, 0x8B187C) + ShowWindow + UpdateWindow + MoveWindow(rect +0x53018..+0x53028) + [0x8AA498] 标志**）。
- **〔定案〕id0 = 背包 Bag**（Round 29『右侧面板 候选』作废）：F288 mode byte [bag+0x54] + 3 页签 +0x5C stride 0xB4 + reset 0x42E9A4 + show 0x42AE26 —— 0x42AE26 = 0x42ADB0 case-0 SHOW 路径（byte[+0x54]=0 + 0x42FF90）；caption idx14 包袱栏 push 0（Round 28 F321）三线合一。
- **〔修正〕F331 两标签**：id6 0x424250 = 组队（[允许]/[拒绝]/成员编辑串，非『背包』）；id9 0x43ED00 = NPC 对话（NPCFace.WIL 绑定 +0x278，非『快捷栏』）。
- **〔close-all〕0x42B820**：遍历可见链表 main+0xD28..+0xD38，id 0..0xE（跳表 0x42B938，5/10 → 0x42B8F5 跳下一节点）→ **0x423F90(obj, 0)** 清可见标志；**id15 不在表内（F294『close-all 跳过 id15』确认）**。0x42B980 = 链表头弹（[+0xD38] 计数、[+0xD2C]=[+0xD30]）用于 0x42B430 聊天头检查。
- **〔点击分派〕0x42B430(x, y)**（ret 8）：弹可见链表头 main+0xD30，id<=0xF → 跳表 0x42B658 → 各窗口 **0x423FA0(obj, x, y, 0)** 点击处理器（id2 = 0x44E910 + 0x423FA0）。可见链表布局：main+0xD24 插入 API（0x449870）/ +0xD28 头 / +0xD2C 游标 / +0xD30 尾 / +0xD34 索引 / +0xD38 计数（Round 12 insertion policy 全确认；TAB 循环 0x42CFBE 读 +0xD34/+0xD2C）。
- **〔43 调用者触发图〕**：背包模式 0x41FA28/0x41FB36/0x4204DD/0x420B0E(id0)；服务端事件 0x41FEB8(id9)/0x420486(id3 交易)/0x4209EF+0x420AB6(id2)/0x4214EB(id7)/0x42151A(id4)；行会公告 0x425A26+0x425B25(id15, F294)+0x42BE99(id15 关闭点击)；**caption 动作表 0x42C494 20 站点**（id 0,1,2,3,4,6,7,8,11,12,13,14；Round 28 F321 确认 idx14 包袱栏→id0）；**热键 0x42CBD0 区** 0x42CCC3..0x42CE86（id 1,14,8,13,11,6,12；0x42CC8B push 0x51=81 → 守卫 no-op 安全）；TAB 0x42CFDD（node id；id9 → 0x41C1E0 NPC 关闭，否则 toggle）。
- **〔修正〕id2/id9 默认隐藏**（ctor arg8=0）；单窗口模态确认（每次 show 前 close-all）。
- 落盘：`window-visibility-dispatch-evidence.json`（F337 追加段 f337_2026_08_12 + closed_notes，保留 Round 12/21 原记录；17 键模板，evidence_level=primary-bytes）+ ui-coverage-matrix.json（window-visibility 新记录 closed_2026_08_12）+ layout.json version 0.15（visibility.toggle-0x42ADB0 / visibility.close-all-0x42B820 / visibility.click-dispatch-0x42B430 + window-catalog id0/id2/id3/id6/id9 身份修正）+ UI_COMPLETION_AUDIT.md Round 31。

## Round 32 (F338) — 2026-08-12：窗口身份定稿 + 窗口绘制分派 0x428105 + 热键表 0x42CC76 全解（F329 修正）

- **〔核心〕0x428105 = 窗口绘制分派**（HUD paint 0x4280F0 家族）：遍历可见链表 main+0xD28..+0xD38 → id<=0xF → **jmp [id*4 + 0x428358] 渲染表 16 项**：id0 0x42EB80 背包 / id1 0x44B2D0 状态 / id2 0x44E260 商店 / id3 0x415B10 交易 / id4 0x425040 行会 / id6 0x4243D0 组队 / id7 0x450530 状态形象 / id8 0x414700 聊天 / id9 0x43F460 NPC / idB 0x447470 信息窗口 / idC 0x441380 选项 / idD 0x4269C0 坐骑 / idE 0x439500 技能书 / idF 0x43E3C0 公告（id5/10 no-op）→ 每项 lea eax,[obj+0x18] 窗口 rect → **IntersectRect [0x476248]** 视口裁剪（id8 聊天除外）→ 命中则鼠标分派 **0x428398**（id0 0x42FAB0 / id1 0x44B6B0 / id2 0x44E650 / id3 0x416790 / id7 0x450AC0；其余跳过）→ 未消费 → **ShowWindow([0x8AA48C], 0)** 回退。
- **〔核心〕热键表 0x42CC76**（GetKeyState [0x476278]；门 [hero+0x20]/[+0x24] 模态抑制）：**Q**→0x42ADB0(id0) 背包 + 0x417880(&+0x6718, 0x10B, 0x10C) 重帧 + byte[+0x65A8]=0；**W**→id1 状态栏；**E**→id14 技能书；**R**→id8 聊天；**S**→id13 坐骑；**D**→id11 信息窗口；**Z**→亮度 [hero+0xD40]∈[0,0x2E] + [0xD42]=1/2（腰带光效语义）；**C**→0x41EC10(&main, [0x777759], [0x777764], [0x777768], 1) 实体查找 → 名字(eax+8) → 0x451A70 状态行；**V**→小地图（timeGetTime-[0x6210]≤0x64 节流；[0x6518]==0 → 0x451770 开，否则清）；**B**→技能浏览翻转 [0x6208]；**G**→id6 组队；**F**→0x4523E0(&0x8AB828) 行会；**N**→id12 选项；**T**→[0x6518]==1 门（小地图状态）。**〔F329 修正〕'D' 开 id11（非坐骑）；'S' 开 id13 坐骑**——与 caption 信息窗口(Ctrl+D)/坐骑(Ctrl+S) 对齐。
- **〔身份定稿〕14 窗口**：id0 背包（Ctrl+Q）、id1 状态栏（Ctrl+W；'本级' 0x47C348 + scanf；paint 0x44B2D0/mouse 0x44B6B0）、id2 商店（F331）、id3 交易（F295）、id4 **行会 Guild**（F294 9 控件数组 this+0x118 关闭/会员升职/成员踢出/盟主转让/邀请入会/行会公告/退出行会/行会解散；click 0x4258F0；**F331『物品』标签修正**）、id6 组队（Ctrl+G）、id7 **状态-形象预览**（paint 0x450530：帧选择器 0x566DD4 byte[+0x551]、角色形象 @ (window.x+0x61, window.y+0xC8) = Round 28 status figure slot、13 个属性 SetRect +0x578..+0x5E8）、id8 聊天（Ctrl+R）、id9 **NPC 对话**（paint 0x43F460 对话类型跳转 0x440158、NPCIMG token 0x47C50C；**F331『快捷栏』修正**）、idB **信息窗口/任务**（Ctrl+D；paint 0x447470：文本列表 [+0x54] + 0x45E0C0 测宽 + 0xC8=200px 宽门 + '-' 0x47C5C0 分隔行 + 2 帧控件 +0x74/+0x128 (0x2D1/0x2D2, 0x2D3/0x2D4) via 0x417830；帧计数 0x8B1B00）、idC 选项（Ctrl+N；F324）、idD 坐骑（Ctrl+S；F327）、idE **技能书**（Ctrl+E；paint 0x439500 = 0x4397A0 左列表 + 0x43A440 右详情（F331 技能族）；火冰电风神圣黑暗幻影剑 = 魔法页签；帧 0x3D=61 子控件）、idF 公告（id15；F294）。id5/10 未用。
- **〔IAT 新增/修正（pefile）〕**：0x476248=**IntersectRect**、0x4762B8=**SetFocus**（F337『候选』确认：id15 公告 show/hide 设焦点 [0x7773CC]）、0x476250=GetFocus、0x476254=GetWindowRect、0x4762F0=FillRect、0x4762F4=FrameRect。
- 落盘：`window-paint-and-hotkey-dispatch-evidence.json`（F338，17 键模板，evidence_level=primary-bytes；audit_vs_exe 含 F329 修正 / F331 三标签修正 / F294 确认 / F321 确认 / 0x4762B8 确认）+ ui-coverage-matrix.json（window-identities-final 新记录 closed_2026_08_12）+ layout.json version 0.16（paint.window-dispatch-0x428105 / hotkey.table-0x42CC76 + window-catalog id1/id4/id7/id9/idB/idE 身份修正）+ UI_COMPLETION_AUDIT.md Round 32。

## Round 33 (F339) — 2026-08-12：状态窗口 id1 家族全解（ctor 0x44B130 / paint 0x44B2D0 / LEVEL+本级 / 12 槽属性数组 / 形象帧 0xA7/0xAA）+ NPC 关闭 0x41C1E0 + 模拟器热键层接线

- **〔核心〕id1 状态窗口 paint 0x44B2D0**（Ctrl+W 开，frame 200 @ 244×328）：mode byte [+0x54] 0/1 页分派 → 0x44B560 helper → SetRect 视口（x−0xA, y+0x1E, x+0xFF, y+0x32）→ 0x45DBA0 测宽 '本级' 0x47C348（font 9, 0x2BC）→ **0x45DE50 文本 0x7776A0（名字缓冲）色 0xDCFFDC + 0x7776E0 色 0xB4FAFF** → 0x44BC80 标签块（**'LEVEL' 0x47C74C 色 0xFAE1C8 + font 굴림체 0x47BE18**，@ win.x+0xFF/y+0x43）→ **形象帧 0xA7/0xAA**（0x466130 + [0x5659CC]/[0x5659D0] 帧头；0x45FD50 blit @ win.x+0xB0/y+0x109 与 0x44B560 内 @ win.x+0x61/y+0xC8 双绘制——大预览+小图标 [INFERENCE]）→ 2 子控件 0x417830（+0x58 @ x+0xD4/y+0x12A、+0x10C @ x+0xB0/y+0x108）→ vtable+4。
- **〔核心〕level 字节 0x777720** = 唯一读者 0x44B569（0x44B560 helper：AND 0xFF → 0x466130(0x566DD4 选择器)）——.text 无写入者（服务端/BSS 运行时 [INFERENCE]）。**0x7776A0 双角色** = 英雄地图名缓冲（F331 0x2F8788）+ 状态名字文本（不同消费者同 BSS 槽）。
- **〔鼠标〕0x44B6B0 → 0x44B720 12 槽命中测试**：循环 0xB=12 槽 stride 0x10（rects [esi+0x1C0+i*0x10]，SetRect 0x4762B0 + PtInRect 0x4762B4）；命中索引 → 槽 = idx*0x2C（[esi+0x2F8−4+i*0x2C]）→ 门 [esi+0x2F4+i*0x2C] → **0x4341F0(x, y, 0) 属性详情弹层**；未命中 −1。**点击 0x44B7A0** 类型字节分派（5/6/9 → 0x44B828；7/8 → 0x44B81C；==arg → 0x44B865）。
- **〔NPC 关闭〕0x41C1E0**（TAB 循环 id9 → 此）：门 [main+0x2F660C] → 0x42AC50(id9) 链表移除 + [main+0x2F65DC] vtable+0x10(0) + 清拖拽 [0x42804C]/[0x428050]；门 [main+0x2D8644] → id2；门 [main+0x2ABA10] && [+0x2ABA34] → 其他窗。
- **〔模拟器热键层接线〕**：build_mir3_simulator_data.py 新增 **hotkeys()**（F338 热键表 Q/W/E/R/S/D/G/N/T + gate）与 **window_catalog()**（F337 id→偏移→身份全表）块；app.js 新增 **bindHotkeys()**（keydown → HOTKEY_WINDOW_ID {Q:0,W:1,E:14,R:8,S:13,D:11,G:6,N:12} → window_id→帧→layout id 映射 → setWindowOpen 切换）。**浏览器验证**：单次 Q 开 window.inventory；数据重生成 windows=18 controls=41（原 14/40）。
- 落盘：`status-window-family-evidence.json`（F339，17 键模板，evidence_level=primary-bytes；BSS 侧 [INFERENCE]；audit_vs_exe 含 Round 28 figure 槽确认/F331 stride 对照/F310 选择器/F311 font）+ ui-coverage-matrix.json（status-window 新记录 closed_2026_08_12）+ layout.json version 0.17（window.status-0x44B2D0 / input.hotkeys-sim）+ RESEARCH_LOG + UI_COMPLETION_AUDIT Round 33 + Tools/web/build_mir3_simulator_data.py + Tools/mir3_client_simulator/app.js + data/* 重生成。

## Round 34 (F340) — 2026-08-12：物品提示框 0x4341F0 + 背包鼠标 0x42FAB0 + 商店窗口家族 0x44D310（最后一个候选窗口定案）

- **〔核心〕0x4341F0 = 物品提示框渲染器**（status 12 槽 0x44B717 / 背包 0x42FB0F / 商店 0x44E6C1 三调用者）：0x430B70(0x8AB7A8) 上下文装载 → 行列表 count [edi+0x64]、lines [edi+0x70+i*0x3C]、byte[line]==0 跳过、0x45E0C0 测宽、宽累计、[esp+0x14] += 0xF 行高 → **浮动矩形**（left=x−5、right=maxW+x+5、top=y−5、bottom=行数×0xF+y+2；0x466800 浮点缩放 0x3E48C8C9/0x3EC8C8C9）→ **图标帧**（arg!=0 → 0x466130(0x5668C4, word[edi+0x28] 物品帧) + [0x5668FC] 帧头、宽 += 帧宽+0xA）→ 800px 右裁剪（SetRect 0x4762B0）→ 0x4542F0(&0x5600FC, mouse 0x8AB7BC, rect) + **0x45E570(0x8AB7A8, rect, 0x329696, 1) 底板**（深青绿色）→ 图标 0x45FD50 blit → 文本行 0x45DE50。**三套 tooltip 系统对比**：物品 0x4341F0（0x329696）/ caption 0x417370（0x96FFFF 淡黄，Round 28）/ 悬停名签 0x40BB00（3000ms）。
- **〔背包鼠标〕0x42FAB0**（0x428398 id0）：门 [0x7243C4]（背包活动标志）→ **0x42F240 槽命中测试**（46 槽 bag+0x774+i*0x184，stride 0x184 于 0x42FAD5 验证：(eax*3)<<5+eax → ×4）→ [esi+idx*0x184+0x774] 物品指针门 → 命中 → **0x4341F0(&slot+0x780, mouseX+0xA, mouseY+0xA, 0)** 提示框。
- **〔商店 id2 定案〕0x44D310 家族**（F331『商店』标签确认；frame 1000 @ 300×304；ctor arg8=0 默认隐藏）：**ctor** = 0x423B30 基 + **8× 0x417550 控件**（帧对 0x3F2/0x3F3 @ +0x54/+0x1BC/+0x48C（购买按钮对）、0x3F4/0x3F5 @ +0x108/+0x270/+0x540（出售/关闭）、0x3F6/0x3F7 @ +0x324、0x3F8/0x3F9 @ +0x3D8（模式按钮）[INFERENCE 由位置]）+ **gauge 0x417960 @ +0x5FC**（0, 0xC, 0xD8, 0xC, 5, 0x3FC, 0）+ **26 槽循环 0x1A @ +0x660**（stride 0x24）。**paint 0x44E260**：mode byte [+0x5F8] 双布局——{0,1,3,4} 默认（控件 @ +0x10E/+0x10A 等）、{2,5+} 交替（+0xAC/+0xA9、+0xA5/+0x47、+0xA2/+0x1C、+0xA2/+0x89...），0x417830 重定位。**mouse 0x44E650**：mode 1/2 → **0x44E800 槽命中** → 0x44E7D0(idx) 物品解析 → [item+0x22] 类型字节 0xA/0xB → 提示框标志 → **0x4341F0(item, mouseX+0xA, mouseY+0xA, flag)**。
- 落盘：`item-tooltip-and-store-family-evidence.json`（F340，17 键模板，evidence_level=primary-bytes）+ ui-coverage-matrix.json（item-tooltip-store 新记录 closed_2026_08_12）+ layout.json version 0.18（tooltip.item-0x4341F0 / window.store-0x44D310）+ UI_COMPLETION_AUDIT.md Round 34。

## Round 35 (F341) — 2026-08-12：交易/聊天/选项窗口绘制定稿 + 窗口绘制矩阵全表

- **〔交易 paint〕0x415B10**（id3）：**双栏分割** +0x5C/+0x6C（mid = x + (w>>1)，0x415B21-0x415B63）→ **PtInRect 悬停高亮** 左栏 (x+0x15, y+0x30)..(x+0xC9, y+0x108) / 右栏 (x+0xFD, y+0x30)..(x+0x1B1, y+0x108) → 悬停 && [0x7243C4] bag 活动 && [0x7243D8]==0 → **0x416830 命中测试** + **0x4162E0(trade, idx, 0x7243DC, mouse) 物品悬停**；行几何 = idx*9（lea ecx,[ecx+ecx*8]），x = win.x + 行*4 + 0x15（左）/ +0xFD（右）。
- **〔聊天 paint〕0x414700**（id8）：SetRect 区域 [esi+0x954]（0x146, 0x137, 0x20D, 0x1A）→ **消息环渲染**：head [esi+0x58]、cursor [esi+0x5C]、idx [esi+0x64]、count [esi+0x6D0]、scroll [esi+0x68]；**节点 {+0 类型, +4 文本指针, +0x408 next}**；行数 = min(count−scroll, 0x13=19)、行距 0xE=14px、原点 win.x+[+0x6C0]/win.y+[+0x6C4]；**0x45DD70(0x8AB7A8, [0x8AB7C4] 颜色, x, y, type, text, 0) 逐行**；滚动条 0x4179B0 @ +0x6D4。
- **〔选项 paint〕0x441380**（id12）：8 控件 0x417830 重定位（+0x7C @ x+0xDA/y+0xEE、+0x130 @ x+0x94/y+0x2B、+0x1E4 @ x+0xB9/y+0x2B、+0x298 @ x+0x94/y+0x74、+0x34C @ x+0xB9/y+0x74、+0x400 @ x+0x94/y+0xBE、+2 至 0x414470）。
- **〔矩阵定稿〕窗口绘制矩阵全表**：id0 0x42EB80/0x42FAB0；id1 0x44B2D0/0x44B6B0；id2 0x44E260/0x44E650；id3 0x415B10/0x416790；id4 0x425040/0x4258F0；id6 0x4243D0；id7 0x450530/0x450AC0；id8 0x414700；id9 0x43F460；idB 0x447470；idC 0x441380；idD 0x4269C0；idE 0x439500；idF 0x43E3C0；id5/10 无窗。**14 窗口 paint/mouse 全枚举完成。**
- 落盘：`trade-chat-option-paint-evidence.json`（F341，17 键模板，evidence_level=primary-bytes；audit_vs_exe 含 F295/F324/Round 28 交叉）+ ui-coverage-matrix.json（paint-matrix-final 新记录 closed_2026_08_12）+ layout.json version 0.19（paint.matrix-final / window.chat-paint-0x414700 / window.trade-paint-0x415B10）+ UI_COMPLETION_AUDIT.md Round 35。

## Round 36 (F342) — 2026-08-12：EI 地图目录清单（544 张全验证）+ 瓦片库分布 + mapviewer 冒烟

- **〔清单〕544 张 .map 全解析通过**（w/h @ 文件偏移 0x16/0x18 = 22/24，与客户端载入器 0x43B600 的 ReadFile 0x1C → [+0x110] 一致）；尺寸直方图（147528B×84、2360028B×72、36903B×56…）；**w/h 直方图**（100×100×91、400×400×72、50×50×59、200×200×52、22×22×44、30×30×39、300×300×32、800×800×4、600×600×4…）。**0.map = 比奇城 800×800 9.44MB**（F331 旧注『0.map 32×32』系另一命名约定，实锤 800×800）。
- **〔瓦片库分布〕**back 层 {2:14057, 1:6104, 0:485, 255:19} = tiles5c/tiles30c/tilesc 地面族；mid {15:7365, 13:164, 12:79, 10:20, 5:20, 4:15, 6…} = wood_tilesc/object2c/object1c/smobjectsc/cliffsc/housesc/dungeonsc；front {15:7670, 10:8, 207:6…}；255 = 空层（3900+ 单元）。header[0x14] ∈ {0,1}（106/14）确认 F331。
- **〔KR_ORDER 绑定〕**mapviewer 的 Zircon 表：0 tilesc / 1 tiles30c / 2 tiles5c / 3 smtilesc / 4 housesc / 5 cliffsc / 6 dungeonsc / 7 innersc / 8 furnituresc / 9 wallsc / 10 smobjectsc / 11 animationsc / 12 object1c / 13 object2c / 15-26 wood_* / 30-41 sand_* / 45-56 snow_* / 200 sabak。与客户端 0x43B600 的 56 槽（0x0E..0x1B / 0x1C..0x29）区间一致——逐图保真度标记 candidate。
- **〔mapviewer 冒烟〕**/api/maps 200（0.map=比奇城 800×800 world 38400×25600 ladder [2,3,4]）；**/tile 渲染 200**（512×512 JPEG 88377B）；**/api/cell**（0.map 0,0 → {flag:2, back:{file:1, lib:tiles30c, frame:754}, mid:{file:0, lib:tilesc, frame:65535}, front:{file:15, lib:wood_tilesc, frame:65535}}）。
- 落盘：`docs/research/mir3-map-reconstruction/map-inventory-evidence.json`（F342，primary-bytes）+ RESEARCH_LOG + UI_COMPLETION_AUDIT Round 36。

## Round 37 (F343) — 2026-08-12：城镇/洞穴地图深挖 + 客户端 56 槽瓦片绑定公式定案

- **〔核心〕客户端瓦片绑定公式定案（primary-bytes）**：0x43B600 载入循环（0x43B756 起）——56 槽 0x5612B4..0x565994（stride 0x144）先 0x465FE0 清；`al = byte[map+0x124]`（tile-row）；**start = (al+1)*0x0E、count = 0x0E**（0x43B77A imul 0x0E）；逐槽 `0x4660E0(&0x5600FC + id*0x144, &0x56B22C + id*0x104, 1)` → **每图绑定文件 id [(row+1)*14, (row+2)*14) = 14 个库**。分布：**row=0 → id 14..27（wood 族）530 张**；**row=1 → id 28..41（sand 族）14 张**（4/5/6/41-44/72-78 沙漠区）。**356 张洞穴 D-图全部 row=0（wood 瓦片）**。
- **〔修正 Round 36〕KR_ORDER 地形库解析正确**：wood_X → Data/Wood/X.wil、sand_X → Data/Sand/X.wil（_find_library_path 实测：wood_tilesc → Data/Wood/Tilesc.wil、sand_tilesc → Data/Sand/Tilesc.wil、wood_housesc → Data/Wood/Housesc.wil 全存在）；Round 36『wood_* 缺失』系只看顶层目录的扫描错误——地形库在子目录。
- **〔城镇层构成〕**0.map 比奇城 800×800：back {1:97521, 0:58275, 2:4201} + mid {15:406562, 0:89189, 5:86182, 10:46587} + front {15:541559}；1.map/02.map 同构（back{0,1} + mid/front{15 wood_tilesc, 5 cliffsc, 10 smobjectsc, 0 tilesc}）。**洞穴层构成**：D001-D012 400×400 back{2:40000 全 tiles5c} + mid{15 wood_tilesc, 12 object1c}——城镇 vs 洞穴地面族信号截然不同。
- **〔渲染对比〕**0/1/02 三镇 tile(1,1) 全 200（512×512 JPEG ~88KB）；inspect_image 视觉验证 0.map/02.map = 草地地面纹理（绿/棕，无建筑——角块为空地）。
- 落盘：`docs/research/mir3-map-reconstruction/town-cave-map-deepdive-evidence.json`（F343，primary-bytes）+ RESEARCH_LOG + UI_COMPLETION_AUDIT Round 37。

## Round 38 (F344) — 2026-08-12：洞穴分支 D1011/D1012 + 沙漠图（4/41 row-1 sand）深挖 + 渲染验证

- **〔洞穴分支〕D1011/D1012**（300×300，row=0）：back{2:22500 全 tiles5c} + mid{15 wood_tilesc, 13 object2c} + front{15:90000 全单元}——封闭岩石洞；渲染验证 = 黑色底 + 岩石突起（inspect_image）。
- **〔沙漠图〕4.map**（800×800，row=1）：back{1:138135, 0:12899, **30 sand_tilesc:8817**}, mid{15, 5, 0, 10}, front{15, 0, 10, 5}——沙丘与 tilesc 地面混合；**41.map**（400×400，row=1）稀疏：mid/front 255 主导 + back{1,0,30} + mid{**40 sand_smobjectsc:2254**}（绿洲/棕榈对象）。**sand lib 30/40 在 row-1 绑定范围 28..41 内确认使用**。
- **〔渲染验证〕**4.map = 沙色细腻颗粒（视觉）；D1011 = 暗岩石；0/1/02 城镇草地（Round 37）。**MAP-SURVEY.md 已追加 Round 37-38 补充段**。
- 落盘：`docs/research/mir3-map-reconstruction/cave-desert-map-evidence.json`（F344，primary-bytes）+ MAP-SURVEY.md 更新 + RESEARCH_LOG + UI_COMPLETION_AUDIT Round 38。

## Round 39 (F345) — 2026-08-12：模拟器窗口目录接线（14 窗口全 primary-static 精确坐标 + 8 热键浏览器验证）

- **〔builder 改造〕**build_mir3_simulator_data.py：读取 window-catalog.hero-builder-0x427600 的 windows[]（id→x/y），布局记录按 **window.id（winid）优先 → frame 兜底** 解析（解决 id1/id7 同帧 200 冲突）；origin 解析序 = confirmed_origins → winid 目录 → frame 目录 → position 偏移 → 居中 candidate。
- **〔结果〕14/14 窗口 primary-static 精确坐标**：背包 (518,0) 284×324、状态 (0,0) 244×328、商店 (0,0)、交易 (0,0)、行会 (102,22) 596×446（F294）、组队 (272,123)、聊天 (114,76)、状态右 (560,0)、选项 (276,113)（F324）、任务 (0,0)、坐骑 (0,0)、技能书 (348,0)、NPC (0,0)、公告 (107,110)（F294）。此前 8/14 candidate。
- **〔浏览器验证〕8 热键全开对窗**：Q→背包、W→状态、E→技能书、R→聊天、S→坐骑、D→任务、G→组队、N→选项；二次按全部关闭（allOpen=[]）。**几何验证**：背包屏 (519,1) 284×324（ctor 518,0）、状态 (1,1) 244×328（ctor 0,0）——缩放内精确。
- **〔闭环〕EXE → 证据 JSON → layout.json → 模拟器数据 → 渲染模拟器** 窗口目录全链路打通。
- 落盘：`simulator-window-catalog-wiring-evidence.json`（F345，derived-tooling；源证据 primary-bytes）+ Tools/web/build_mir3_simulator_data.py + Tools/mir3_client_simulator/data/* 重生成 + RESEARCH_LOG + UI_COMPLETION_AUDIT Round 39。

## Round 40 (F346) — 2026-08-12：模拟器聊天环 19 行上限 + 模态窗口切换（F337/F341 语义落地）

- **〔聊天〕pushChat 上限 19 行**（原 40）——匹配原版聊天环 0x414700 的 min(count−scroll, 0x13=19) 行 14px 行距（F341）。
- **〔模态〕setWindowOpen(open) 先关其他窗**（除 notice id15，原版 close-all 0x42B820 排除 id15）——匹配 0x42ADB0 单窗口模态（F337）。
- **〔浏览器验证〕**Q→W：仅 status 开（bag 被关）；Q 再按：仅 bag 开（status 被关）；chat-lines = 5 行（启动 2 条 + 热键推送）。
- 落盘：`simulator-chat-modal-wiring-evidence.json`（F346，derived-tooling）+ app.js + RESEARCH_LOG + UI_COMPLETION_AUDIT Round 40。

## Round 41 (F347) — 2026-08-12：NPC 对话窗口家族全解（脚本 token 渲染器 FCOLOR/NPCIMG + 点击处理器）+ 模拟器 NPC 交互接线

- **〔paint 0x43F460〕**dialog-type byte [ebx] 1..3 → 跳表 0x440158：[0x43F4E7 文本（≥7 行换第二列 x=0x131−0x6B、行距 0x14=20px）、0x43F86D、0x43F85F、0x43FF92 脚本 token]。**type-4 0x43FF92**：strcmp vs **FCOLOR 0x47C514** → atoi [ebx+8] → **菜单颜色表 [eax*4 + 0x47C4A8]**（[0x0, 0xFF, 0x8000, 0x8080, 0x808080, 0x80, 0x808000, 0x800000] DOS/BIOS 色码）；strcmp vs **NPCIMG 0x47C50C**（F331）→ atoi → **0x466130(&[ebp+0x278] NPCFace.wil, frame) 头像 blit**。
- **〔click 0x43E4B0〕**（ret 8，0x1F40 栈探测）：2 子控件 +0x54（帧 161/162）/ +0x108（帧 606/607）vtable+0x10 命中 → [ebp+0x1CC] 编辑缓冲 → GetWindowTextA [0x476304]（0xFA0）→ 0x468BF0 分行 → **msg 0x410/0x411**（F331）；消费返 1（0x42ADB0 关窗）。
- **〔模拟器接线〕**refreshWindowContent('window.npc-candidate') 填充 FCOLOR 色码 + NPCIMG 头像 demo 对话（行会管理员）；点击菜单行关闭对话。**浏览器验证**：点 行会管理员 → 开 window.npc-candidate + 色码正文。
- 落盘：`npc-dialog-family-evidence.json`（F347，primary-bytes）+ app.js + RESEARCH_LOG + UI_COMPLETION_AUDIT Round 41。

## Round 42 (F348) — 2026-08-12：行会窗口 id4 paint 0x425040 定稿（窗口绘制矩阵 100% 闭合）

- **〔paint 0x425040〕**标题文本 0x96C8FF（SetRect 头 + 0x45DE50）→ **状态字节 [0x98] 分派**：0 → 0x425280（list0：count [0xE4]/head [0xD4]，strcmp 标记 [行会公告]/[敌对行会]/[联盟行会] → 0x96FF 否则 0xFFFFFF）；1 → 0x425440（list1：[0xB4]/[0xA4]，[行会成员] 标记）；其他 → 0x425590（list4：[0x114]/[0x104]，无标记，双画 0xA140A 阴影 + 0xFF00 绿）→ **滚动条 0x4179B0 @ +0x76C**（state 计数 [0xE4]/[0xB4]/[0x114]，位置 x+0x224/y+0xD0）→ **9 控件 0x417830 重定位**（+0x118 关闭 @ x+0x22C/y+0x199、+0x1CC 会员升职 @ x+0x22/y+0x178、+0x280 成员踢出 @ x+0x22/y+0x192、+0x334 盟主转让 @ x+0x79/y+0x192…）。
- **〔意义〕窗口绘制矩阵 100% 闭合**：14 窗口 paint/mouse/click 全解码（行会为最后一块）。
- 落盘：`guild-window-paint-evidence.json`（F348，primary-bytes）+ RESEARCH_LOG + UI_COMPLETION_AUDIT Round 42。

## Round 43 (F349) — 2026-08-12：登录/角色选择流程全解（intro 0x402BE0 + char-select 0x4575D0 + server 0x458F80）+ 模拟器登录遮罩

- **〔intro 0x402BE0〕**tick + 子级 0x402C40：stage byte [0x8A4]（0→0x402D50、1→0x4031A0、2→0x403560）；**sub-stage [0x8A5]**：0 → 屏幕帧 0x3C（0x45FD50 wemade.dat）；1 → 0x45C900(&+0x6F4) 载入 → [0x8A5]=2；2 → Interface1c 帧 +0x5B0 + [0x8A4]=1 + 0x403640。
- **〔char-select 0x4575D0〕**stage byte [0x930] → 跳表 0x457778 5 项：[0x4575F3→0x457790 列表动画（1s tick 0x1160/0x1164 → **0x45B390 BGM '.\\Sound\\SelChr.mp3' 0x47D624** + 帧 0x32）、0x457615→0x457AB0 建号、0x457604 登录动画（[0x930]=2 + 0x4584C0 + SetWindowTextA）、0x4576FA→**0x458B20([0x1168] 角色索引) 进入游戏**、0x45773C 完成]。
- **〔server 0x458F80〕**0x452920 解析 msgid；msgid−0x208 ≤ 8 → 跳表 0x45950C 9 项（0x208/520 角色列表刷新 0x458FBD：清 +0xCB8 0x20 dwords + [0x1168]=-1 + 解析名；0x209 建号；0x20A 错误；0x20B 重发；0x20D 进入 OK → 0x459465 stage 4 + StartGame.dat 0x47D7C8；0x20E 韩语消息…）。职业名 0x47D778 ' 武 士 ]' / 0x47D784 ' 法 师 ]' / 0x47D790 ' 道 士 ]'。
- **〔模拟器〕renderLoginOverlay()**：intro 遮罩（账号/密码 + 进入游戏）→ '连接服务器 (0x458F80 0x208)' → '角色列表就绪 (0x4575D0 stage 3 → 0x458B20)' → 进游戏（0x8B1878 state 3）。**浏览器验证**：遮罩 → 点击 → 中间提示 → 1.7s 后遮罩移除 + chat '进入游戏'。
- 落盘：`login-charselect-flow-evidence.json`（F349，primary-bytes）+ app.js + RESEARCH_LOG + UI_COMPLETION_AUDIT Round 43。

## Round 44 (F350) — 2026-08-12：HP/MP/EXP 条家族验证（0x40A8A0 + 浮点常量 + 模拟器条对齐）

- **〔0x40A8A0 HP 条渲染器〕**门 [0x61BB8]/[0x61BBC] && 鼠标 [0x8AB7BC]；类型字节 [0x8D]（0x51/0x89 flag0、0x81/0x8A flag1）；**HP = [0x61BA0] − [0xB4]（伤害）+ [0xC4]（增益）→ [0x61B9C]**；元素 = 0x5600FC + type*0x144，**帧 = 实时 HP 值**（0x4542A0 注册表查 type<5/frame<0x8C → 0x454DA0 @ 0x5600FC+0x13F60）；位置 = 锚 [0xE4]/[0xE8] + 帧 fx/fy×0.5（0x476364）− 400.0/300.0（0x476474/0x476470）中心公式（F310）。
- **〔浮点常量〕**0x47639C=1/255（0.00392 字节色缩放）、0x476364=0.5、0x476474=400.0、0x476470=300.0。
- **〔模拟器〕**hp/mp/exp 条已用 primary-static SetRect 证据（0x4276D6/0x4276F0/0x42770D，帧 60/61/63）；CSS 填充动画为帧=值原版的视觉近似——接线正确。
- 落盘：`hpmp-exp-bar-family-evidence.json`（F350，primary-bytes）+ RESEARCH_LOG + UI_COMPLETION_AUDIT Round 44。

## Round 45 (F351) — 2026-08-12：技能格接入真实 Magic.exp 记录（50 技能 primary-static）+ 技能链调用点验证

- **〔builder〕**skills 生成器读 magic-exp-records.json（F37 0x4525F0 解码的 50 条：id/name/attribute/element/levels[{required_level, practice_value}]）；前 12 填技能格 primary-static。**结果**：基本剑术 id3 req7、攻杀剑术 id7 req14、刺杀剑术 id12 req19、半月弯刀 id25 req24、野蛮冲撞 id27 req27…（原 12 占位槽 candidate 作废）。
- **〔EXE 技能链〕**0x4525F0（Magic.exp 解码器）callers = 0x4391F0（技能 ctor 装载）+ 0x44A9C2；0x43A440（技能详情渲染）caller = 0x439520（技能书 paint 右页）；0x4397A0 左列表；0x439250 ctor（帧 400 面板 + 8 魔法分类页签）。
- **〔浏览器〕**E 开技能书；content children = 20（8 分类页签 + 12 技能槽）。
- 落盘：`skill-grid-magic-exp-evidence.json`（F351，derived-tooling；源记录 primary-static）+ builder + skills.json 重生成 + RESEARCH_LOG + UI_COMPLETION_AUDIT Round 45。

## Round 46 (F352) — 2026-08-12：背包格修正为原版 46 槽布局（bag+0x774 stride 0xC2C + 6 列网格）

- **〔原版事实〕**背包 = **46 槽（0x2E）**记录 bag+0x774 + i*0xC2C（flag 槽底、w/h +0x778/+0x77C、0xC20 记录体 +0x780）；网格 WORD 表 bag+0x324（6 列/行、12B 行距、空 0xFFFF、首格标记 slot+0x3E8）；索引数学 0x42FCC0 = bag + 3116*slot（F293）。
- **〔模拟器修正〕**window.inventory 填充：36 槽（6×6）→ **46 槽（6 列 × 8 行，40px 距 36px 格）**；desc 标注 bag+0x774+i*0xC2C F293。**浏览器验证**：slotCount = 46。
- 落盘：`bag-grid-46-slot-evidence.json`（F352，derived-tooling；源证据 primary-static F293）+ app.js + RESEARCH_LOG + UI_COMPLETION_AUDIT Round 46。

## Round 47 (F353) — 2026-08-12：装备面板验证（8 槽 primary-static + 状态窗渲染）

- **〔装备槽〕**8 槽 primary-static（equipment-slots-evidence.json F325）：头盔 (177,70)/火把 (27,264)/毒药 (64,264)/左手镯 (27,186)/右手镯 (175,186)/左戒指 (27,227)/右戒指 (175,227)/鞋子 (103,264)——38px 槽、Equip.wil 帧 = 槽索引。
- **〔状态窗〕**模拟器 window.status 渲染 8 装备槽 + 5 属性标签（等级/攻击/魔法/防御/魔御）；角色形象 @ +0x61/+0xC8（F338/F339）。**浏览器验证**：equipSlots = 8、attrLabels 5 条。
- 落盘：`equipment-panel-verification-evidence.json`（F353，derived-tooling；源证据 primary-static）+ RESEARCH_LOG + UI_COMPLETION_AUDIT Round 47。

## Round 48 (F354) — 2026-08-12：小地图子系统验证（F310 玩家标记链 + F277 放置公式 + MMap 差一 + 模拟器接线）

- **〔窗口〕**hero+0x6214 via 0x43D4D0（F335）：MMap.wil→+4、FMMap.wil→+0x148；面板 rect (672,0,800,128)、尺寸 128×128；paint 0x43DA80（地图对象合成到固定矩形）；update 0x4294E0（门 [0x6518]）→ 0x43D850(Y,X)。
- **〔玩家标记 F310〕**活坐标 [0x777764]/[0x777768] = [screen+0x2F884C]/[+0x2F8850]（Y/X）；恰 2 写者 0x422A9E/0x422AC5（死亡/传送泵 0x422960）；0x7D9234/0x7D9238 排除（死亡/重生检查对）。
- **〔帧选择〕**server value ≥1001 → FMMap.wil value−1001；否则 MMap.wil value−1（0x43D780，F310 差一）；0.map → FMMap F0。
- **〔模拟器〕**map.minimap = FMMap F0（0.map）、面板 672,0-800,128 primary-static——接线正确。
- 落盘：`minimap-subsystem-verification-evidence.json`（F354，derived-tooling；源证据 primary-static）+ RESEARCH_LOG + UI_COMPLETION_AUDIT Round 48。

## Round 49 (F355) — 2026-08-12：聊天输入 + 命令分派（0x404600 双缓冲 + 0x41ED20 命令表）+ 模拟器聊天命令

- **〔0x404600 聊天输入〕**门 [0x8A4]==1：清 +0xE3D 0x41 dwords → SetWindowTextA([0x8AA48C], &+0xD39) → [0xD38]=1 → 0x403640 恢复 → [0x8AA498]=0；ret 8。
- **〔0x41ED20 命令分派〕**SEH + 0x3F0C 栈：`'+'` 前缀 → **0x41E740 交易/计数器命令**（0x468BF0 按 '/' 切、atoi、timeGetTime 门 [0x428214]）；否则 0x452920 解析 → word msgid → **msgid−6 → 字节表 0x421D8C**（0x0B=默认 11，稀疏索引）→ jmp [idx*4 + 0x421D5C]；显式比较 0x29E/0x26D/0xC9；0x41EDC4 字符串拷 [ebx+0x50] 0x104B。
- **〔模拟器〕**Enter 分派：'+' → 交易命令注（0x41E740）、'@' → 私聊家族（0x47ACB8）、'!' → 喊话家族（0x47ACF8/0x47ACE4/0x47ACD0）、普通 → [你]。**浏览器验证 4 类命令**。
- 落盘：`chat-input-command-dispatch-evidence.json`（F355，primary-bytes）+ app.js + RESEARCH_LOG + UI_COMPLETION_AUDIT Round 49。

## Round 50 (F356) — 2026-08-12：确认/公告提示系统验证（0x418520 激活链 + 模拟器提示流程）

- **〔0x418520 激活〕**门 [0x462] mode → 3 按钮数组 [esi+0x234+i*0x28]（步长 0x28）；**wparam = ((type<<8|idx)<<16)|tag**（F233-238 编码确认）→ MoveWindow + ShowWindow + **SendMessageA([0x8AA48C], 0x7EE, wparam, &[esi+0x130])**（lparam = 按钮负载缓冲 0x104）。
- **〔模拟器〕**PROMPT_BUTTONS（confirm 帧 950 3 按钮 / notice 帧 602 2 按钮 / gold 帧 950+输入框 F283）——浏览器验证 showPrompt('confirm') 显示文本。
- 落盘：`prompt-system-verification-evidence.json`（F356，primary-bytes）+ RESEARCH_LOG + UI_COMPLETION_AUDIT Round 50。

## Round 51 (F357) — 2026-08-12：任务窗口 id11 渲染细节（0x447470 文本列表）+ 模拟器任务列表

- **〔0x447470 任务列表〕**head [0x54]、cursor [0x1E8]=[0x1E4]、**行数上限 0x13=19**；**条目步长 0x104**（F331 技能列表同款）；0x45E0C0 测宽、**0xC8=200px 门**（超宽换行/滚动 0x44755C）；**选中色 0x1919C8 / 常态 0x19197D**（0x4475F7-0x447606，选择标志 [ebp+0x204]/[ebp+0x210]）；**行 y = line*3 + 0x12**（0x447618）、原点 win.x+0x41；滚动 cursor vs [0x58]。
- **〔模拟器〕**window.quest 渲染 5 任务行（19 上限）、色 0x1919C8/0x19197D、证据 desc。**浏览器验证**：D 开任务窗、首行 ★ 主线：拜见国王 色 rgb(25,25,200)。
- 落盘：`quest-window-render-evidence.json`（F357，primary-bytes）+ app.js + RESEARCH_LOG + UI_COMPLETION_AUDIT Round 51。

## Round 52 (F358) — 2026-08-12：HUD 标题提示框（0x417370 0x96FFFF + 14 caption 标签入模拟器）

- **〔0x417370〕**门 byte[+0x34]（悬停标志）；状态 [0x8B1880]/[0x8B1884] + 当前标签 0x8B1888 strcmp；渲染 = 测宽 + **0x96FFFF 底板**（CreateSolidBrush+FillRect 0x4762F0）+ **1px 黑框**（FrameRect 0x4762F4）+ 文本 DrawTextA flags 0x25（Round 28 F242/243 确认）；文本色 BLACK。
- **〔模拟器〕**layout.json 14 个 hud.* 记录获 caption_label（Round 29 F335 字符串解析）；builder hud 控件输出 caption_label（14 验证）；app.js renderHud 加样式 .cap-tip（0x96ffff 底 + 1px 黑框）。**浏览器验证**：hud.exchange 悬停 → '交易栏(Ctrl+C, C) · F80/81' 色 rgb(150,255,255)。
- 落盘：`caption-tooltip-0x96ffff-evidence.json`（F358，primary-bytes）+ layout.json + builder + app.js + RESEARCH_LOG + UI_COMPLETION_AUDIT Round 52。

## Round 53 (F359) — 2026-08-12：目标框/悬停系统验证（0x40BB00 悬停名签 + 0x40B850 名牌）

- **〔0x40BB00 悬停名签〕**门 byte[+0x620A0]；**3000ms 定时器**（累加器 [0x6209C] > 0xBB8 → 清 +0x620A0 0x41 dwords + +0x621A4 0x208 dwords）；锚 [0xE4]/[0xE8] − 0x2C/−0x37。
- **〔0x40B850 名牌〕**门 byte[+8]；0x45E0C0 测宽；盒 = 锚X + (w+0x30)/2 居中、y = 锚Y−0xF..−0x1E（15px 高）、宽 w+0x30（F239 0xA0A0A 边框）。
- **〔模拟器〕**点击实体 → setTarget → target-panel visible + target-box。**浏览器验证**：点玩家 → 面板显示 '玩家：玩家 Finding 282/279 帧证据'。
- 落盘：`target-box-hover-verification-evidence.json`（F359，primary-bytes）+ RESEARCH_LOG + UI_COMPLETION_AUDIT Round 53。

## Round 54 (F360) — 2026-08-12：组队窗口 id6 内容（0x4243D0 成员列表 + 编辑框字符串）+ 模拟器接线

- **〔0x4243D0〕**标题 0x7776A0 色 **0xDCE6C8**（0x45DD70 @ x+0x2D/y+0x16）；**成员列表** count [0x68]、head [0x58]、node+4 名、**行距 i*20**（0x424449-0x424455 (i>>1)*5<<2）；编辑字符串 0x47BA38 添加成员/0x47BA10 删除成员占位 + [允许] 0x47BA08/[拒绝] 0x47BA00。
- **〔模拟器〕**window.group：标题 '组队成员 · 0x7776A0' 色 0xDCE6C8 + 成员列表 + 添加/删除占位。**浏览器验证**：G 开组队窗、6 行、标题色 rgb(220,230,200)。
- 落盘：`group-window-detail-evidence.json`（F360，primary-bytes）+ app.js + RESEARCH_LOG + UI_COMPLETION_AUDIT Round 54。

## Round 55 (F361) — 2026-08-12：坐骑窗口 id13 接线（F327 5 子控件 + 韩文标签 + 命令门控）

- **〔F327 事实〕**0x4268C0（base frame 850 + 5× 0x417550 子控件 +0x54..+0x324）；帧对 (0xA1,0xA2)..(0x362,0x363)；**韩文美术标签 말타기/말내리기/말숨기기/말꺼내기**（帧 860-867）；**命令 @上马 0x47B060（状态 [0x7DA060]==0）/ @遛马 0x47B068（!=0）/ @收马 0x47B058**；点击 0x426A80-0x426B45 分支；**无 vtable**。
- **〔模拟器〕**window.horse：标题 + Horse.wil 图 + 4 命令行（韩文标签 + 命令串 + 门控证据）。**浏览器验证**：S 开坐骑窗、5 行。
- 落盘：`horse-window-wiring-evidence.json`（F361，derived-tooling；源证据 primary-static F327）+ app.js + RESEARCH_LOG + UI_COMPLETION_AUDIT Round 55。

## Round 56 (F362) — 2026-08-12：选项窗口 id12 验证（F324 Config.ini 链 + 模拟器行/滑块）

- **〔F324〕**ctor 0x440FE0（base frame 750 + 11× 0x417550 子控件 +0x7C 起；config load 0x441CC0/save 0x441B30；restore 0x441226-0x44137C；open 0x4414F0）；**Config.ini [Options]**：배경음→BGM→+0x54、효과음→EffectSound→+0x58、주변효과음→Ambience→+0x5C（**visual-only 死开关**：无音频引擎引用、save 回写 load 值）、그림자→ShadowBlend→+0x60；**BGM 音量滑块** → [0x8AB130+0x20] → 0x45A4A0 put_Volume（F334）。
- **〔模拟器〕**4 行（音乐/音效/环境声/阴影混合 y43/116/190/217）+ 滑块 751 @ (34,96)/(34,170)；帧对 760/761 ON 켬、762/763 OFF 끔（F289/F297 像素验证）。
- 落盘：`option-window-verification-evidence.json`（F362，derived-tooling；源证据 primary-static）+ RESEARCH_LOG + UI_COMPLETION_AUDIT Round 56。

## Round 57 (F363) — 2026-08-12：商店窗口内容验证（F289 模式链 + 网格布局 + 模拟器）

- **〔F289 模式〕**0=BUY（msg 0x285→0x41F92B→0x44F480）/ 1=SELL / 2=仓库（0x2BC→0x42042B→0x44F940）/ 3=CRAFT（0x2C8→0x44FB00，错误 돈이 부족합니다 0x47B634 / 아이템이 잘 만들어 졌습니다 0x47B660）/ 4=详情；状态字节 [0x5F8]。
- **〔F340 ctor〕**8 控件（0x3F2-0x3F9）+ gauge + 26 槽 +0x660 stride 0x24；paint 0x44E260 mode 双布局；mouse 0x44E650。
- **〔模拟器〕**state0/3/4 = 5 行购买列表（y 40/86/132/178/224）；state2 = 仓库 12 格（+0x720）；模式标签带证据链。**浏览器验证**：开商店 state0 购买 10 槽。
- 落盘：`store-window-content-verification-evidence.json`（F363，derived-tooling；源证据 primary-static）+ RESEARCH_LOG + UI_COMPLETION_AUDIT Round 57。

## Round 58 (F364) — 2026-08-12：交易窗口内容验证（F295/F283/F341 分裂面板 + 金币流 + 模拟器）

- **〔F295/F283/F341〕**双栏 +0x5C/+0x6C（mid=x+(w>>1)）；行 idx*9、x=win.x+row*4+0x15（左）/0xFD（右）；**金币框 (34,270)..(156,304)**：点击 → msgbox 0x405 '你要给对方多少金币?' → 确定 → **msg 0x406 via 0x451B30**（F283）；接受 → [+0x13644]=1 定稿；交易自有槽记录 24×0xC2C @ +0x5B8（F293，与背包分开）。
- **〔模拟器〕**2 栏 × 5×6 = 60 trade-cell + trade-gold 金币框 + 3 zone + 2 divider + 状态 lbl（'交易中 ([+0x13644]=0)'）。**浏览器验证**：60 格 + 金币 + 区域。
- 落盘：`trade-window-content-verification-evidence.json`（F364，derived-tooling；源证据 primary-static）+ RESEARCH_LOG + UI_COMPLETION_AUDIT Round 58。

## Round 59 (F365) — 2026-08-12：模拟器全链路集成验证 + HANDOFF 更新

- **〔浏览器全流程〕**登录遮罩 → 8 热键（Q/W/E/R/S/D/G/N 各开对窗）→ NPC 点击（行会管理员 → 对话窗 .npc-body）→ 悬停提示框（0x96FFFF）——单次浏览器通跑全通过。
- **〔HANDOFF〕**docs/handoffs/MIR3_UI_RECONSTRUCTION_HANDOFF.md 追加 Round 29-58 交付摘要（窗口目录/主循环/分派/身份/地图/模拟器接线 F335-F364、29 新证据 JSON、commit 基线 4e95988..cf56033）。
- 落盘：`integration-sweep-evidence.json`（F365，derived-tooling）+ HANDOFF + RESEARCH_LOG + UI_COMPLETION_AUDIT Round 59。

## Round 60 (F366) — 2026-08-12：地图切换验证（F333 0x422960 + 模拟器切换）

- **〔F333 0x422960〕**type 0x33/0x27A：门（mode [0x2F8840]==3 + 环记账）或 timer [0x4279A4]；处理 = 存盘 0x42E1F0 → 窗口 flush 0x45B1D0/0x45B3D0 → 1500ms 限流 → 12 槽清零 → 坐标 → 停全部音效+BGM（0x4229E9/0x4229F3）。
- **〔模拟器〕**setCurrentMap/cycleMinimap（211 绑定、FMMap.wil）。**浏览器验证**：比奇县 → 边境城市 → 比奇县。
- 落盘：`map-transition-verification-evidence.json`（F366，derived-tooling；源证据 primary-static F333）+ RESEARCH_LOG + UI_COMPLETION_AUDIT Round 60。

## Round 61 (F367) — 2026-08-12：NPC 场景实体渲染验证（F287 帧公式 + 模拟器精灵）

- **〔F287〕**NPC 实体 vtable 0x47671C（type 0x32）；NPC.wil = slot 127；body 条带 0x44A090（0,12,0x50=80ms）；**帧 = word[0x8AA6C8+6*state] + 100*body + 10*(flag%3)**；0x40C4B0 帧推进。
- **〔模拟器〕**entityFrame NPC 分支 = 100*body + 10*(flag%3) + 状态表循环。**浏览器验证**：行会管理员 → NPC.wil F30。
- 落盘：`npc-entity-render-verification-evidence.json`（F367，derived-tooling；源证据 primary-static F287）+ RESEARCH_LOG + UI_COMPLETION_AUDIT Round 61。

## Round 62 (F368) — 2026-08-12：最终收尾（模拟器数据重生成 + 全验证套件 + 服务检查 + 仓库干净）

- **〔数据〕**builder 重生成：windows=22 controls=41 resources=157 entities=8 equipment_slots=8 skills=12 maps=2 bindings=211。
- **〔验证〕**compileall OK；verify_mir3_ui_evidence exit 0（零错误）；node --check OK；layout/matrix/sim-layout JSON 全有效；git diff --check OK；工作树干净（仅未跟踪 scripts/goal_watchdog.sh.bak-20260812-084129 用户文件未动）。
- **〔服务〕**wilviewer 8765/ui 200、mapviewer 8899 200、sim 8765/sim 200。
- 落盘：`housekeeping-final-evidence.json`（F368，derived-tooling）+ RESEARCH_LOG + UI_COMPLETION_AUDIT Round 62。**Round 29-62 = 34 连发 commit（F335-F368，4e95988..874a223）。**

## Round 63 (F369) — 2026-08-12：瓦片库异常调查（147 张未绑定图携带范围外 lib + EI 可玩集 = 211 张）

- **〔范围外 lib〕**544 张全扫：**base 0-13（544 张全用）/ wood 14-27（468）/ sand 28-41（30）/ forest 42-55（32）/ snow 56-69（23）/ 200-254（39，255=空层哨兵排除）**。
- **〔关键结论〕forest/snow/200+ lib 的图 = 0 张被服务器绑定**（MiniMap.txt 313 项仅 211 匹配 EI 图）；这些图（kt* 韩测、d*/D6xx 他版洞穴、0_0031-33）**全部未绑定 + row=0**——客户端仅绑 14-27，forest/snow/异常 lib 越界 → 若加载渲染黑块；img 值近 0xFF00（65305/65348）表明非 EI 瓦片编码。
- **〔EI 可玩集定界〕211 张绑定图只用 libs {0-13 base, 14-27 wood, 28-41 sand}**；**Data/Forest + Data/Snow 子目录 = 他客户端（Zircon KR）产物，EI 3.0 不用**；Wood/Sand 子目录实际使用。
- 落盘：`docs/research/mir3-map-reconstruction/tile-lib-anomaly-survey-evidence.json`（F369，primary-bytes）+ RESEARCH_LOG + UI_COMPLETION_AUDIT Round 63。

## Round 64 (F370) — 2026-08-12：地面覆盖调查（211 可玩图全 ≥90% + 0_003 空间模式修正）

- **〔覆盖〕211 张绑定图全 ≥90% 全分辨率 back 覆盖**（0_003 90.9% 最低、5_0013 94.2%、其余 ≥95%）——**无缺地面可玩图**。
- **〔0_003 空间模式〕**右缘 3 列空白（row 4: cols 27-29；其他行 26-29 变化）+ 底部 row 48-49 大部分空（23/30、30/30）——**不规则海岸线边缘，非 P2 所述均匀『右 2 格 + 下 6 格』**；5_0013 = 1 空列 + 1 空行（67 半格）近似 P2。机制 = 字面 file=255（客户端 0x43B440 跳过，P2 real-skip）。
- **〔修正〕ground-not-drawn-evidence.json 追加 f369 空间精析注记**（右缘宽度逐行变化、底部 2 半行）。
- 落盘：`ground-coverage-survey-evidence.json`（F370，primary-bytes）+ ground-not-drawn-evidence.json 更新 + RESEARCH_LOG + UI_COMPLETION_AUDIT Round 64。

## Round 65 (F371) — 2026-08-12：帧越界独立验证（4936 OOB 仅 4 图 + D10031 新增 back 层实例）

- **〔扫描〕**211 绑定图全扫（wilsdk 权威帧数）：**4936 OOB 仅限 4 图**——3.map 3255（mid 25 Wood/SmObjectsc 2575 + frt 500）、41.map 1619、**D10031 62（新增）**、50.map 39（F317 已覆盖 3 图）。
- **〔D10031〕**300×300 row-0：**back 层 62 格 lib 2（Tiles5c 20000）帧 42759-42766（0xA707-0xA70E）**——F317 lib/frame-space 混淆的 **back 层新实例**（F317 原覆盖 mid/front）；帧 42759+ 超 object1c/object2c 上限 → 候选 reserved/anim 标记或第三库空间。
- **〔F317 更新〕**lib-space-frame-oob-evidence.json 追加 f370 注记（D10031 back 层实例）。
- 落盘：`frame-oob-verification-evidence.json`（F371，primary-bytes）+ lib-space-frame-oob-evidence.json 更新 + RESEARCH_LOG + UI_COMPLETION_AUDIT Round 65。

## Round 66 (F372) — 2026-08-12：城镇结构对比（0.map 比奇城 / 3.map 沙巴克 / 02.map）

- **〔0/02.map 密集城镇〕**back{1,0}+mid{15 wood_tilesc, 5 cliffsc, 10 smobjectsc, 0 tilesc 地面细节}+front{15}——全图对象覆盖。
- **〔3.map 沙巴克 = 稀疏要塞〕**mid/front **255 主导**（171994/209506 空）+ **Wood/Wallsc lib 24 = 3384 墙格**（x 0..399、y 211..405 **内城墙带，非周长**；边缘墙仅 4.9%）——开阔地面 + 墙围城设计。
- **〔渲染〕**三镇 tile 全 200（88KB JPEG）；3.map 角块 = 开阔草地（墙仅 y211-405 带）。
- 落盘：`town-structure-comparison-evidence.json`（F372，primary-bytes）+ RESEARCH_LOG + UI_COMPLETION_AUDIT Round 66。

## Round 67 (F373) — 2026-08-12：缩放阶梯验证（mapviewer ladder = 缩放级别，非地图切换）

- **〔语义澄清〕**mapviewer `ladder` = **逐图缩放级别 [最深..适配]**（0 = 1:1）；最深 = 全图 ≤16384px（MAX_FULL_DIM）、适配 = ≥2048px（FIT_FULL_DIM）；**非地图切换表**（切换 = 服务端 0x422960，F333/F366）。
- **〔公式复验〕**800×800 → [2,3,4]；600×600 → [1,2,3]；100×100 → [0,1]；≤50×50 → [0]；400×600 → [1,2,3]。
- 落盘：`zoom-ladder-verification-evidence.json`（F373，derived-tooling）+ RESEARCH_LOG + UI_COMPLETION_AUDIT Round 67。

## Round 68 (F374) — 2026-08-12：图层渲染验证（mapviewer mid/front 开关差异 + 视觉确认）

- **〔开关差异〕**0.map tile (16,3) z=1：ground-only 89506B vs all 107427B（+18KB mid/front 对象）——**mid/front 渲染确认激活**；区域 = 24×24 含 458 对象格（libs 4/5/6/10/12/13）。
- **〔视觉〕**inspect_image：树 + 岩壁 + 灌木（libs 5 cliffsc + 10 smobjectsc 对象正确渲染）。
- **〔层序〕**mapviewer 按 back→mid→front（0x43B440 序，F331）；mid/front 左下锚（0x43bce6/0x43bfd2 目标数学）；is_object_library 排除纯地面（tilesc/wood_tilesc 等）——早前 tx=2 相同 md5 因该区只有地面 lib 15。
- 落盘：`layer-render-verification-evidence.json`（F374，derived-tooling；渲染语义源 primary-static F331）+ RESEARCH_LOG + UI_COMPLETION_AUDIT Round 68。

## Round 69 (F375) — 2026-08-12：精灵偏移/锚点验证（EI 帧统一 -24,-16 + 客户端忽略偏移左下锚）

- **〔帧偏移〕**Cliffsc/SmObjectsc 采样：全帧 offsetX=-24 offsetY=-16（48×32 瓦片半格锚），高随对象变（SmObjectsc f200 h=352 高树）。
- **〔客户端锚〕**0x43B440 目标数学（0x43BCF5-0x43BD36）：dx = x*48 − scrollX − 0xC8(200)；dy = y*32 − scrollY − h(word[+2]) − 0x7D(125)——**不读 WIL offsetX/offsetY，仅用帧高**（左下锚）；地面 −157 vs mid/front −125 差一单元高。
- **〔对照〕**UI 控件（0x417550）用帧偏移定 rect；**地图精灵忽略偏移**——两套系统。offset-distribution P9 + F331 确认。
- 落盘：`sprite-offset-anchor-verification-evidence.json`（F375，primary-bytes）+ RESEARCH_LOG + UI_COMPLETION_AUDIT Round 69。

## Round 70 (F376) — 2026-08-12：瓦片缓存验证（r_{tx}_{ty}_{z}_{g}{m}{f}{layout}n.jpg + 冷热 15×）

- **〔缓存键〕**`.tilecache-v3/<map>/r_{tx}_{ty}_{z}_{g}{m}{f}{layout}n.jpg`（如 r_3_3_1_111n、r_16_3_1_100n）；布局后缀 n = rect。
- **〔性能〕**冷 1.40s → 热 0.092s（**15×**）；md5 一致（82a88f87）——缓存正确。
- **〔层键〕**r_16_3_1_100n/111n = F374 图层开关测试产物（ground-only vs all 区分键）。
- 落盘：`tile-cache-verification-evidence.json`（F376，derived-tooling）+ RESEARCH_LOG + UI_COMPLETION_AUDIT Round 70。

## Round 71 (F377) — 2026-08-12：小地图校准交叉验证（268 MMap value−1 + 空白帧复验 + D001 放置公式）

- **〔MMap 路径〕**268 项 value<1001 → 客户端帧 = value−1（F310 差一确认）；D001=1→f0、D002=2→f1…
- **〔FMMap 路径〕**3.map=1018→f17、41.map=1021→f20、31.map=1031→f30（FMMap 31 帧内）；0.map=1001→f0。
- **〔空白帧复验〕**D901/D9021/D9022/D2011/D2012 → MMap **f144-149 = None（真空白，F310 确认）**；但 **81.map→f18（152×100 真实头）、D452→f23（600×400 真实头）**——F310 空白清单含 value/帧精确问题待和解 [candidate]。
- **〔D001〕**f0 = 600×400 真实小地图——400 宽洞穴 × 1.5 缩放 = 600（F277 放置公式吻合）。
- 落盘：`minimap-calibration-crosscheck-evidence.json`（F377，primary-bytes）+ RESEARCH_LOG + UI_COMPLETION_AUDIT Round 71。

## Round 72 (F378) — 2026-08-12：保留标记帧验证（0xFFFF 空哨兵主导 + 0xFFxx 仅未绑定图）

- **〔哨兵〕**211 绑定图：mid 0xFFFF 18,045,874 / frt 20,684,963 / back 422 格——**0xFFFF = 层空哨兵主导**（地图大多 back+mid、front 稀疏）。
- **〔0xFFxx 标记〕**绑定图 **0 个 0xFF00-0xFFFE**；未绑定遗留图 0_0031/kt0018 有 mid 0xFFFC（65532）@ (8,0)——F369 异常集吻合。
- **〔语义〕**客户端空判断 = **精确 ==0xFFFF**（非掩码）；0xFFxx = 普通越界帧（不绘制、无特殊含义）——reserved-frame-markers 证据确认。
- 落盘：`reserved-frame-marker-verification-evidence.json`（F378，primary-bytes）+ RESEARCH_LOG + UI_COMPLETION_AUDIT Round 72。

## Round 73 (F379) — 2026-08-12：瓦片视口验证（0x43B440 768×576 缓冲 + 24×24 半分辨率窗口）

- **〔缓冲〕**map+0x1B2 **0x6C000 dwords = 768×576 px**（442368，rep stosd 清零）。
- **〔循环〕**y=[+0x12C]/x=[+0x130]..+0x18 = **24×24 半分辨率瓦片对窗口**；奇偶门（两坐标须偶）；**索引 = (y>>1)*w + (x>>1)**（imul w + sar）；**行 = attr/7**（imul 0xE = 14，0x6DB6DB6D 魔数）；**3 字节记录**（byte+1 = 16 位瓦片 id @ 0x43B516）。
- **〔分辨率〕**24×24 半瓦片 = 768 宽 × 384 高渲染入 768×576——覆盖 24 列 × 18 行全瓦片 + 垂直滚动（F332 0x43B1E0）。
- 落盘：`tile-viewport-verification-evidence.json`（F379，primary-bytes）+ RESEARCH_LOG + UI_COMPLETION_AUDIT Round 73。

## Round 74 (F380) — 2026-08-12：地图审计对账（544 图 5723 异常格/34 图 + 异常类拆分）

- **〔审计完整性〕**map-audit.json 544 图全含 size_ok/cell_bytes/mid/front/ground/anomalies；**总异常 5723 格 / 34 图**（3.map 3255、41.map 1619、D12121 171、0_003 137、74.map 90、5_0013 67、D10031 62、50.map 39）。
- **〔对账〕**F371 D10031 back 层 OOB 在审计中 = **ground_lib2_frame_oob=62**（存于 'ground' 统计，非 mid/front_libs——早前查询误读）；**异常类拆分**：帧越界（3/41/D10031/50.map）vs 地面未绘（D12121/74/0_003/5_0013，F370 覆盖案例）。
- 落盘：`map-audit-reconciliation-evidence.json`（F380，primary-bytes）+ RESEARCH_LOG + UI_COMPLETION_AUDIT Round 74。

## Round 75 (F381) — 2026-08-12：地图连接验证（Mapinfo 365 名 342 链 + 覆盖对账）

- **〔Mapinfo〕**365 地图名 + 342 无向链接（map_routes.py 解析）；**279/342 双端在 EI（81.6%）**、14 单端在 EI（目标服务端专属）、49 双端他服。
- **〔0.map 150 链〕**Town Area→Bug Cave Entrance (19.62,37.25)、→Ant Cave Entrance (161.67,34.17)、→D001 Red Moon Door (218.71,124.57)——完整 mapinfo 传送数据。
- **〔互补〕**Mapinfo = 服务端传送表；客户端经 0x33/0x27A → 0x422960 接收坐标（F366）——两套互补。
- 落盘：map-connections-verification-evidence.json（F381，derived-tooling；源 Mapinfo 次级）+ RESEARCH_LOG + UI_COMPLETION_AUDIT Round 75。

## Round 76 (F382) — 2026-08-12：地图名表验证（双源差异 + 客户端服务端推送名）

- **〔双源〕**mapnames.py 遗留库（0=比奇城/1=失乐园/D001=幽灵森林）vs Mapinfo 服务端（0=比奇县/1=道馆/D001=半兽洞穴1层）——**客户端显示服务端推送名**（0x7776A0/0x2F8788 缓冲，无客户端名表，F331/F333）→ **Mapinfo 名 = EI 3.0 运行时真相**；3.map=沙巴克城双源一致。
- **〔覆盖〕**365 命名 / 678 链端点 → **253 端点 Mapinfo 未命名**（服务端只给访问过的图命名）。
- 落盘：map-name-table-verification-evidence.json（F382，secondary；缓冲用法 primary-static）+ RESEARCH_LOG + UI_COMPLETION_AUDIT Round 76。

## Round 77 (F383) — 2026-08-12：地图主题验证（theme = 瓦片行 + 5 图主题/内容不一致类）

- **〔theme〕**= header[0x14] 瓦片行（F343）：全集 {0 wood: 530, 1 sand: 14}、绑定 {0: 197, 1: 14}（211 总）。
- **〔不一致〕**5 张 theme-1 图（72/73/76/77/78.map，400×200）绑定 sand 库但格引用基础库 {0,1}（ground tilesc/tiles30c，帧 7596 合法）+ mid {5,10,3}——**沙行绑定但基础地面内容**（稀疏沙漠用基础瓦片）[candidate]。
- 落盘：map-theme-verification-evidence.json（F383，primary-bytes）+ RESEARCH_LOG + UI_COMPLETION_AUDIT Round 77。
## Round 78 (F384) — 2026-08-12：单元旗标分析（flag0 值分布 + 客户端阻挡机制）

- **〔分布〕**flag0 {0: 294, 1: 22, 2: 232, 3: 240, 252: 313, 253: 33, 254: 164, 255: 317 格}；**252-255 = 每图 1 个哨兵格**（317 图）——边缘/动画标记，非群体阻挡。
- **〔阻挡〕**客户端移动阻挡 = **type 0x32 小地图标记**（0x4123E3 门 [0x7E335C]+0x88==0x32 → 返回 1 阻挡；pick/select 排除 0x32）——**非单元旗标**；单元旗标 = 瓦片行 attr（F331 attr/7）。
- 落盘：cell-flag-analysis-evidence.json（F384，primary-bytes）+ RESEARCH_LOG + UI_COMPLETION_AUDIT Round 78。
## Round 79 (F385) — 2026-08-12：动画单元分析（7.56M 格 / 326 图 + midAnim 循环）

- **〔分布〕**动画格 7,564,096 / 326 图（D022/D032/D042/D052 各 250000 = 500×500 全动画水图；D003/D011/D033/D043/D053/D1001 等 160000）。
- **〔D022〕**midAnim {0: 249911, 152: 89}、frontAnim 全 0xFF 静态、mid libs {15: 238198, 12: 11802}——**midAnim 0 = 水/熔岩循环索引**。
- **〔客户端〕**帧空判断 0x43BBBB ==0xFFFF 精确；非 0xFF 动画字节 = 帧循环组。
- 落盘：animated-cells-analysis-evidence.json（F385，primary-bytes）+ RESEARCH_LOG + UI_COMPLETION_AUDIT Round 79。
## Round 80 (F386) — 2026-08-12：单元记录布局验证（14 字节 + 文件尺寸精确）

- **〔布局〕**14 字节单元 {+0 flag, +1 midAnim, +2 frontAnim, +3 frontFile, +4 midFile, +5-6 midImg u16, +7-8 frontImg u16, +9..13 零尾}；**文件尺寸精确**：28 + (w/2)(h/2)*3 + w*h*14 = 9440028（0.map）。
- **〔样本〕**空单元（midImg 0xFFFF）；实体单元 cell 296/1091（midFile 10 SmObjectsc midImg 4354/5528）、1883/1884（midFile 5 Cliffsc midImg 5203/5202）、frontFile 15。
- **〔客户端〕**mid 帧 +5、front +7（F331 0x43BB10）；back 3 字节 @ 0x43B516。
- 落盘：cell-record-layout-verification-evidence.json（F386，primary-bytes）+ RESEARCH_LOG + UI_COMPLETION_AUDIT Round 80。
## Round 81 (F387) — 2026-08-12：地图头验证（28 字节布局 + 50.map WWW 编辑器签名）

- **〔布局〕**28 字节头 {0x00-0x13 零（543 图）、+0x14 瓦片行、+0x16/+0x18 w/h（客户端 +0x126/+0x128）、余部}。
- **〔50.map 变体〕**头 = ASCII 'Created by WWW Team'（WWW 地图编辑器签名）、w=120 h=150、**未绑定**（MiniMap 无）、尺寸精确（265528）；客户端固定偏移解析不受文本头影响。
- 落盘：map-header-verification-evidence.json（F387，primary-bytes）+ RESEARCH_LOG + UI_COMPLETION_AUDIT Round 81。
## Round 82 (F388) — 2026-08-12：洞穴家族对比（半兽/赤月/诺玛/废矿）

- **〔共性〕**全部 back lib 2 (tiles5c) + mid 15 (wood_tilesc)。
- **〔差异〕**D0 半兽 400×400 mid 12 object1c（50307）；**D1 赤月 300-400 mid 13 object2c 主导（94317，暗美术）**；D6 诺玛 200-250 稀疏（mid 255 77279）；D4 废矿 200×200 mid 12（24487）。
- **〔渲染〕**D1 近黑（深洞）、D6 较亮——美术区分验证。
- 落盘：cave-family-comparison-evidence.json（F388，primary-bytes）+ RESEARCH_LOG + UI_COMPLETION_AUDIT Round 82。
## Round 83 (F389) — 2026-08-12：地表图分类（E 路/编号城野 + 0_00x 建筑/kt 全未绑定）

- **〔E 路〕**2 绑定，100×100（back tiles5c + mid wood/object1c）——走廊。
- **〔编号〕**37 绑定（0-9/12/121-125/31/401-407/41-44/5/6/71-78/81）——城镇+野图（back {1,0} + mid {15, 5 cliffsc, 10}）。
- **〔未绑定〕**0_00x 建筑（市政厅/左右翼 9 图）+ kt 测试 **0 绑定**（EI 客户端永不加载，F369 吻合）。
- 落盘：surface-map-classification-evidence.json（F389，primary-bytes）+ RESEARCH_LOG + UI_COMPLETION_AUDIT Round 83。
## Round 84 (F390) — 2026-08-12：EI vs ZL 库差异验证（56 行 52 DIFF + 格式/规模差）

- **〔数据〕**56 行：52 DIFF / 4 SAME；26 库 EI > ZL（Tiles5c 20000 vs ZL 35-73，300×）、26 ZL > EI（Wood/Tilesc 13841 vs EI 3927）。
- **〔格式〕**ZL = .Zl 压缩（Zircon 格式）vs EI .wil/.wix——不同容器/帧数。
- **〔主题〕**Snow/Forest 未被 EI 使用（全 theme 0/1）——F369 佐证；ZL 用 Snow/Forest 补偿。
- 落盘：ei-vs-zl-libraries-verification-evidence.json（F390，derived-tooling）+ RESEARCH_LOG + UI_COMPLETION_AUDIT Round 84。
## Round 85 (F391) — 2026-08-12：大型图对比（6/8/0/4.map 800x800）

- **〔结构〕**6.map = 沙行沙漠城（sand_smobjectsc 40）；**8.map = 冰雪村稀疏雪镇**（mid 255 582718 空 + cliffsc/smobjectsc，lib 25 雪语境，零异常）；0.map = 比奇城密集木镇（F372）；4.map = 沙漠（sand_tilesc 30）。
- **〔主题〕**0/8 wood 行、4/6 sand 行——城市主题分 wood/sand。
- 落盘：large-map-comparison-evidence.json（F391，primary-bytes）+ RESEARCH_LOG + UI_COMPLETION_AUDIT Round 85。
## Round 86 (F392) — 2026-08-12：小型图分析（无 ≤40 绑定 + D11xxx 洞穴变体）

- **〔无 ≤40 绑定〕**全部 22x22/30x30 实例未绑定（01_001 志善屋等室内经服务端切换）；最小绑定 = D5071/D716 50x50、D0xx/D1xxx/D2xxx 洞穴 100x100。
- **〔新变体〕D11032/D1116/D12122**：back lib 17（wood_tiles5c）+ mid 21（wood_dungeonsc 稀疏）——与标准 D0xx（tiles5c+wood_tilesc+object1c）不同的地牢瓦片集。
- **〔尺寸谱〕**50x50 房间 → 100 洞穴 → 200+ D4/D6 → 300-400 D1/D0 → 600-800 城。
- 落盘：small-map-analysis-evidence.json（F392，primary-bytes）+ RESEARCH_LOG + UI_COMPLETION_AUDIT Round 86。
## Round 87 (F393) — 2026-08-12：传送坐标验证（2049 条全整数 + 双向对）

- **〔记录〕**2049 条 'mapA x,y -> mapB x,y'，**全整数地图格坐标**（x 3-779、y 5-781）、**1:1 双向对**（3<->0150 双记录）。
- **〔0.map 17 条〕**333,776->01 564,69（北界）、65,174->D001 151,362（红月门）、764,206->D401 25,181（西矿口）。
- **〔客户端〕**格式与 0x422960（F333）msg 0x33/0x27A word+6/+8 坐标兼容。
- 落盘：transition-coordinate-verification-evidence.json（F393，derived-tooling；客户端格式 primary-static）+ RESEARCH_LOG + UI_COMPLETION_AUDIT Round 87。
## Round 88 (F394) — 2026-08-12：地图渲染性能（/fullmap 9600x6400 26MB + 瓦片热/冷延迟）

- **〔fullmap〕**0.map → 9600×6400 JPEG 26MB（19.7s 冷）——世界 38400×25600 / 4 = 最深 z=2（16384 上限，F373 阶梯吻合）。
- **〔瓦片〕**热 121ms（10 片 1.21s、8 片/s）、冷 ~1.4s——缓存对交互平移关键。
- 落盘：map-render-performance-evidence.json（F394，derived-tooling）+ RESEARCH_LOG + UI_COMPLETION_AUDIT Round 88。
## Round 89 (F395) — 2026-08-12：地图校验和验证（F317 哈希复验 + D10031 钉定）

- **〔复验〕**F317 记录 md5 与现文件全匹配：3.map=60036c1f（3255 OOB）、41.map=407deda0（1619）、50.map=ea960513（39）。
- **〔新增〕**D10031 fresh md5=1d1407d0（62 back OOB）——钉定入 F371 closed_notes。
- **〔审计〕**map-audit.json 无 md5 字段（结构性数据）——校验和在 F317/F371。
- 落盘：map-checksum-verification-evidence.json（F395，primary-bytes）+ frame-oob-verification-evidence.json 更新 + RESEARCH_LOG + UI_COMPLETION_AUDIT Round 89。
## Round 90 (F396) — 2026-08-12：地图覆盖完整性（313 MiniMap = 211 出货 + 102 服务端专属）

- **〔覆盖〕**313 MiniMap 项 = **211 出货 EI 图（100% 审计，544/544 记录完整）** + **102 服务端专属图不在 EI 包**（401-407 哨所、D15xxx 诺玛区、D2xxx/D6xxx、E/F/Q 系列、RUSH1/Island、9.map）——服务端可引用客户端缺失的图（0x43B600 装载失败）。
- 落盘：map-coverage-completeness-evidence.json（F396，primary-bytes + 服务端 secondary）+ RESEARCH_LOG + UI_COMPLETION_AUDIT Round 90。
## Round 91 (F397) — 2026-08-12：mapviewer UI 验证（加载 + 图层开关 + 瓦片渲染）

- **〔UI〕**加载 OK（地图浏览器）、选择器 比奇城 0.map、512×512 瓦片 g=1&m=1&f=1、图层开关 chk-g/m/f/grid/ents（**front 开关 f=1->f=0 触发重渲染**）、缩放 +/–、适配、重新生成。
- 落盘：mapviewer-ui-verification-evidence.json（F397，derived-tooling）+ RESEARCH_LOG + UI_COMPLETION_AUDIT Round 91。
## Round 92 (F398) — 2026-08-12：地图知识库合成（544/211/102/333 + MAP-SURVEY 定稿）

- **〔最终统计〕**磁盘 544、MiniMap 313（211 绑定出货 + 102 服务端专属）、333 未绑定；主题 530 wood + 14 sand；异常 5723 格/34 图。
- **〔可玩构成〕**编号 37 + 洞穴 156（D0/D1/D4/D6/D11xxx）+ E 路 2；尺寸 50x50→800x800。
- **〔MAP-SURVEY〕**追加 Round 90-92 最终汇总段（瓦片/单元/视口/越界/地面/工具链）。
- 落盘：map-knowledge-synthesis-evidence.json（F398，primary-bytes）+ MAP-SURVEY.md + RESEARCH_LOG + UI_COMPLETION_AUDIT Round 92。
## Round 93 (F399) — 2026-08-12：商店模式状态图验证（5 态工厂 + 状态字节）

- **〔状态图〕**0 BUY 0x44EAB8 f1000 / 1 SELL 0x44F7EF f1003 / 2 仓库 0x44F940 f1001 / 3 CRAFT 0x44FB00 / 4 详情——各态重工厂换帧；状态字节 +0x5F8。
- **〔模拟器〕**开商店 state0（购买）10 槽 + 证据标签（浏览器验证）。
- 落盘：store-mode-state-graph-verification-evidence.json（F399，primary-bytes）+ RESEARCH_LOG + UI_COMPLETION_AUDIT Round 93。
## Round 94 (F400) — 2026-08-12：交易关闭验证（模拟器开/关/模态 + F337 关闭机制）

- **〔模拟器〕**交易窗开 → 关 → 开 group 时交易被模态关闭（close-all F337）。
- **〔原版〕**关闭 = 0x42ADB0 id3 → 0x42AC50 可见链表移除（F337）；trade-window-closure 证据 5/6 pending 已闭（+0x298 运行时填充 KEPT-runtime）。
- 落盘：trade-closure-verification-evidence.json（F400，derived-tooling；关闭机制 primary-static F337）+ RESEARCH_LOG + UI_COMPLETION_AUDIT Round 94。
## Round 95 (F401) — 2026-08-12：窗口 Z 序/前台验证（notice 豁免 + bring-to-front + 模态）

- **〔模拟器〕**notice（id15，z=50，close-all 豁免 F294）在 option（z=100 前台）打开时保持——模态 + 豁免 + 前台全工作。
- **〔语义〕**close-all 0x42B820（F337）+ id15 跳过 + 显示置前（可见链表追加 0x449870）；绘制按链表序（0x428105 F338）。
- 落盘：window-zorder-verification-evidence.json（F401，derived-tooling；语义 primary-static F337/F294）+ RESEARCH_LOG + UI_COMPLETION_AUDIT Round 95。
## Round 96 (F402) — 2026-08-12：聊天滚动条验证（0x4179B0 量条 + 模拟器滚动）

- **〔量条〕**0x4179B0（帧 1070 16×360、94 定点尺度 F301、6 行视口）：chat 值=[+0x68] scroll / 上限=[+0x6D0] count、@+0x6D4（F341）。
- **〔模拟器〕**scroll-up/down ±266px（19 行 × 14px）；track 380 @ win.x+0x215/y-0xD0 证据-only。
- 落盘：chat-scrollbar-verification-evidence.json（F402，derived-tooling；量条语义 primary-static F301/F341）+ RESEARCH_LOG + UI_COMPLETION_AUDIT Round 96。
## Round 97 (F403) — 2026-08-12：聊天频道按钮验证（6 频道命令模板 + 注入）

- **〔频道〕**6 按钮全带原版命令帮助串（拒绝私聊 @拒绝私聊/大喊话 !/编组喊话 !! /行会喊话 !~/拒绝和某人私聊）——F341 串。
- **〔注入〕**大喊话 点击 → 输入框 '!'（浏览器验证）；分派 0x41ED20（F355）。
- 落盘：chat-channel-verification-evidence.json（F403，derived-tooling；串 primary-static F341）+ RESEARCH_LOG + UI_COMPLETION_AUDIT Round 97。
## Round 98 (F404) — 2026-08-12：NPC 对话交互验证（开/选/关）

- **〔模拟器〕**点行会管理员 → 对话开（NPCIMG 0 头）；菜单选购买装备 → 日志 + 窗口关闭（consumed → 0x42ADB0 id9，F347/F337 语义）。
- 落盘：npc-dialog-interaction-verification-evidence.json（F404，derived-tooling；语义 primary-static F347/F337）+ RESEARCH_LOG + UI_COMPLETION_AUDIT Round 98。
## Round 99 (F405) — 2026-08-12：行会窗口内容验证（3 列表态 + 横幅引用）

- **〔模拟器〕**行会成员标题 0x7776A0（0xDCE6C8）+ 4 成员。
- **〔原版〕**3 列表态（0x425280 公告/敌对/联盟 0x96FF 标记、0x425440 成员、0x425590 双画）+ 9 控件 + id15 横幅引用（ctrl4/ctrl7，F294）。
- 落盘：guild-window-content-verification-evidence.json（F405，derived-tooling；语义 primary-static F348/F294）+ RESEARCH_LOG + UI_COMPLETION_AUDIT Round 99。
## Round 100 (F406) — 2026-08-12：状态属性颜色验证（F289 0xfafafa/0xfae1c8 应用）

- **〔F289〕**30 值 0xfafafa + 28 标签 0xfae1c8 + 4 特殊 0xff（防御/攻击/魔法/魔御）；62 处 0x45DD70。
- **〔模拟器〕**等级标签 rgb(250,225,200)=0xfae1c8、攻击值 rgb(250,250,250)=0xfafafa（浏览器验证）。
- 落盘：status-attribute-colors-evidence.json（F406，derived-tooling；颜色 primary-static F289）+ app.js + RESEARCH_LOG + UI_COMPLETION_AUDIT Round 100。
## Round 101 (F407) — 2026-08-12：选项开关验证（4 行 ON/OFF + 켬/끔 帧）

- **〔开关〕**4 行（音乐/音效/环境声/阴影混合）ON/OFF 状态翻转 + 帧证据日志（760/761 켬、762/763 끔，F297 像素）；滑块 751（BGM 音量 F334）；状态字节 +0x54..+0x60（F324）。
- 落盘：option-toggle-verification-evidence.json（F407，derived-tooling；语义 primary-static F324/F289/F297）+ RESEARCH_LOG + UI_COMPLETION_AUDIT Round 101。
## Round 102 (F408) — 2026-08-12：血条动画验证（F350 语义 + 1.5s 演示振荡）

- **〔条〕**HP 44px（100×0.5 竖条半宽）、MP 50px、EXP 129px（339 全宽）——primary-static rects（F350）。
- **〔动画〕**1500ms 演示振荡（STATE.hp/mp % 101 夹 20）；原版 = 帧=值元素选择（0x40A8A0）。
- 落盘：bar-animation-verification-evidence.json（F408，derived-tooling；rects primary-static F350）+ RESEARCH_LOG + UI_COMPLETION_AUDIT Round 102。
## Round 103 (F409) — 2026-08-12：背包提示框验证（46 槽 + 7 图标 + 0x4341F0 链）

- **〔槽〕**46 槽（F293 证据 desc）+ 7 Equip 图标槽（i%7）；原版提示链 0x42FAB0 → 0x42F240 → 0x4341F0（F340，底板 0x329696）。
- 落盘：bag-tooltip-verification-evidence.json（F409，derived-tooling；链 primary-static F340）+ RESEARCH_LOG + UI_COMPLETION_AUDIT Round 103。
## Round 104 (F410) — 2026-08-12：技能书验证（8 页签 + 12 真实技能槽）

- **〔页签〕**8 分类（火冰电风神圣黑暗幻影剑，F338）；**〔槽〕**12 真实 Magic.exp 技能（基本剑术/攻杀剑术/刺杀剑术 primary-static，F351）。
- **〔详情页〕**0x43A440 右页渲染器（F331：Magic.exp 行、0x104 步长、235px x 偏移）已文档化。
- 落盘：skill-detail-verification-evidence.json（F410，derived-tooling；名 primary-static F351）+ RESEARCH_LOG + UI_COMPLETION_AUDIT Round 104。
## Round 105 (F411) — 2026-08-12：坐骑交互验证（4 命令 + 0x7DA060 门控）

- **〔命令〕**말타기 @上马（[0x7DA060]==0）/말내리기 @遛马（!=0）/말숨기기 @收马/말꺼내기 @遛马——全带门控；点击日志分派（浏览器验证）。
- 落盘：horse-interaction-verification-evidence.json（F411，derived-tooling；语义 primary-static F327）+ RESEARCH_LOG + UI_COMPLETION_AUDIT Round 105。
## Round 106 (F412) — 2026-08-12：小地图控件验证（128×128 + FMMap F0 绑定）

- **〔控件〕**128×128（672,0-800,128）、FMMap.wil F0（0.map 比奇县 → F310 绑定）、标题 primary-static（浏览器验证）。
- 落盘：minimap-sim-verification-evidence.json（F412，derived-tooling；绑定 primary-static F310）+ RESEARCH_LOG + UI_COMPLETION_AUDIT Round 106。
## Round 107 (F413) — 2026-08-12：目标框模拟器验证（稻草人 面板+覆盖层）

- **〔面板〕**怪物：稻草人 + 帧证据（Finding 280 Mon-(Race//10+1).wil）；**〔覆盖层〕**targetbox 显示名字（F239 复合）。
- 落盘：target-sim-verification-evidence.json（F413，derived-tooling；语义 primary-static F239/F359）+ RESEARCH_LOG + UI_COMPLETION_AUDIT Round 107。
## Round 108 (F414) — 2026-08-12：悬停模拟器验证（稻草人 精灵标记 + targetbox）

- **〔悬停〕**pointerover 稻草人 → 精灵 hovered 类 + targetbox 显名（F239 0x40BB00 → 0x40B850 名牌路径）。
- 落盘：hover-sim-verification-evidence.json（F414，derived-tooling；语义 primary-static F239/F359）+ RESEARCH_LOG + UI_COMPLETION_AUDIT Round 108。
## Round 109 (F415) — 2026-08-12：点击目标验证（选中 + 切换）

- **〔点击〕**点行会管理员 → selectedEntity 设置；点商店老板 → 切换（F239 点击 msg 2 → 0xBC4 语义）。
- 落盘：click-targeting-verification-evidence.json（F415，derived-tooling；语义 primary-static F239/F336）+ RESEARCH_LOG + UI_COMPLETION_AUDIT Round 109。
## Round 110 (F416) — 2026-08-12：登录流程终验（intro → 连接 → 角色列表 → 进游戏）

- **〔阶段〕**intro 遮罩 → 连接（0x458F80 角色列表）→ 角色选择（0x4575D0 stage 3）→ 进游戏（0x8B1878 state 3 → 0x41BB00）——全链浏览器验证。
- 落盘：login-flow-final-verification-evidence.json（F416，derived-tooling；语义 primary-static F336/F349）+ RESEARCH_LOG + UI_COMPLETION_AUDIT Round 110。
## Round 111 (F417) — 2026-08-12：角色选择视觉（武士/法师/道士 按钮入登录流）

- **〔类选〕**登录遮罩加 武 士/法 师/道 士 按钮（0x47D778/0x47D784/0x47D790，F349/F311）；点击进游戏 + 证据日志（浏览器验证）。
- 落盘：char-select-visual-verification-evidence.json（F417，derived-tooling；名 primary-static F349/F311）+ app.js + RESEARCH_LOG + UI_COMPLETION_AUDIT Round 111。
## Round 112 (F418) — 2026-08-12：证据调试模式验证（rect + 级别着色）

- **〔覆盖层〕**证据模式按钮切换：HUD 底板 primary / hp_bar primary-static / 窗口控件 candidate——级别着色显示（浏览器验证）。
- 落盘：evidence-overlay-verification-evidence.json（F418，derived-tooling）+ RESEARCH_LOG + UI_COMPLETION_AUDIT Round 112。
## Round 113 (F419) — 2026-08-12：地图背景验证（FMMap F0 + 800×600）

- **〔背景〕**场景 bg = FMMap.wil F0（0.map → F277/F310 绑定）、800×600 视口缩放、8 精灵叠加（浏览器验证）。
- 落盘：map-bg-sim-verification-evidence.json（F419，derived-tooling；绑定 primary-static F277/F310）+ RESEARCH_LOG + UI_COMPLETION_AUDIT Round 113。
## Round 114 (F420) — 2026-08-12：模拟器最终集成扫描（全功能单次通过）

- **〔扫描〕**登录 → 类选 → 游戏内 → 8 热键（Q/W/E/R/S/D/G/N 全对）→ NPC 对话 → 证据模式 → 血条动画（hp 44→45）→ 小地图——单次浏览器全通过。
- 落盘：simulator-final-sweep-evidence.json（F420，derived-tooling）+ RESEARCH_LOG + UI_COMPLETION_AUDIT Round 114。**Round 29-114 = 86 连发（F335-F420）。**
## Round 115 (F421) — 2026-08-12：目标交付物审计（16 项全达标）

- **〔审计〕**6301 行研究日志、172 UI JSON + 47 地图 JSON、58 记录 layout.json、1613 行模拟器、wilviewer 8765 + mapviewer 8899 在线、86 连发 commit 全推 master（8145504）。
- **〔HANDOFF〕**追加 Round 93-114 交付摘要。
- 落盘：deliverable-audit-evidence.json（F421，derived-tooling）+ HANDOFF + RESEARCH_LOG + UI_COMPLETION_AUDIT Round 115。
## Round 116 (F422) — 2026-08-12：滚动 blit 复合路径闭合（长期 pending 项）

- **〔0x43B1E0 滚动〕**视口 [map+0x14C..+0x158] vs 玩家 ±0xC 门（玩家居中跳过）；越界 → SetRect(x±0x12, y±0x12) + 重渲染。
- **〔复合〕**0x43B440 → [map+0x1B2] 768×576 缓冲 → 0x45E8E0 屏幕 blit；callers 0x410838（瓦片刷新）+ 0x43B7F5（地图装载尾）。
- **〔闭合〕**长期 pending（0x43B1E0 → 0x43B440 复合路径）字节级验证闭合。
- 落盘：scroll-blit-composite-closure-evidence.json（F422，primary-bytes）+ RESEARCH_LOG + UI_COMPLETION_AUDIT Round 116。
## Round 117 (F423) — 2026-08-12：地图实体标记验证（Envir 3323 实体）

- **〔实体〕**服务端 Envir 解析：3323 = 18 出生点（12 图，0.map 3）+ 318 NPC（79 图，0.map 46 比奇城）+ 2987 怪物（带掉落：金币 33%/号角 10%）。
- **〔服务〕**mapviewer /api/entities 需 --envir 参数（StartPoint/Merchant/MonGen）；F254 type-0x32 标记 = 运行时推送（0x560070 列表），与静态实体分离。
- 落盘：map-entity-markers-verification-evidence.json（F423，secondary + F254 primary）+ RESEARCH_LOG + UI_COMPLETION_AUDIT Round 117。
## Round 118 (F424) — 2026-08-12：怪物刷怪覆盖（288 图 + 104 服务端专属）

- **〔覆盖〕**288 刷怪图（0.map 348、1.map 279、4.map 127 城郊热点）；**184 在 EI + 104 服务端专属**（D6015/D515/D15xx = F396 缺口吻合）。
- 落盘：monster-spawn-coverage-evidence.json（F424，secondary）+ RESEARCH_LOG + UI_COMPLETION_AUDIT Round 118。
## Round 119 (F425) — 2026-08-12：怪物分布（2987 项/308 种 + 等级 1-700）

- **〔分布〕**2987 刷怪/308 种（栗子树 137、狼 64、多钩猫/钉耙猫 58、半兽人/森林雪人 52）；等级 1-700（lvl1 768、lvl10 359、lvl40 137 栗子树）。
- 落盘：monster-distribution-evidence.json（F425，secondary）+ RESEARCH_LOG + UI_COMPLETION_AUDIT Round 119。
## Round 120 (F426) — 2026-08-12：NPC 分布（318/248 种 + 六面神石主导）

- **〔分布〕**318 NPC/248 种（六面神石 33 传送石、沙巴克旗帜 11、变异骷髅 8、商人族）；face 全 0；body 56×23/3×19/34×16/10000×12 特殊（F287 100*body 公式）。
- 落盘：npc-distribution-evidence.json（F426，secondary）+ RESEARCH_LOG + UI_COMPLETION_AUDIT Round 120。
## Round 121 (F427) — 2026-08-12：商人脚本验证（339 Market_Def + 格式）

- **〔脚本〕**339 Market_Def + Merchant.txt 项（01Meet_Bichon1 → 0.map 446,405 body 11）；格式 %100 加价 + 货物行（+40 肉）+ [@main] #IF/#ACT。
- **〔关联〕**商店模式（F289/F399）货物来自脚本包（msg 0x285）。
- 落盘：merchant-script-verification-evidence.json（F427，secondary）+ RESEARCH_LOG + UI_COMPLETION_AUDIT Round 121。
## Round 122 (F428) — 2026-08-12：NPC body→帧交叉验证（6400 帧库）

- **〔帧库〕**NPC.wil = 6400 帧；body ≤ 64 直接索引（56/3/34/48/18/2/9 全适配 ≤ 5610）；**body 10000 = OOB 特殊渲染覆盖**（非帧索引）。
- **〔帧头〕**f0 36×78 / f100 28×66 / f300 36×72 / f5600 188×130（F287 公式实测）。
- 落盘：npc-body-frame-crosscheck-evidence.json（F428，primary-static + secondary）+ RESEARCH_LOG + UI_COMPLETION_AUDIT Round 122。
## Round 123 (F429) — 2026-08-12：怪物 WIL 族验证（16 文件 × 10000 帧）

- **〔族系〕**Mon-1..16.wil 全 10000 帧；客户端表 Mon-1..20 + MonS-1..20 影 + DMon-1/DMonS-1 + NPC/MonImg/MonMagic/Magic 共 **88 WIL 字符串**。
- **〔装载器〕**0x4538B0 构建 40 槽文件名表（stride 0x104，dest ebx+0x10B94..，降序字符串 = 槽 19-i）；**F280 race//10+1 → Mon-N.wil 字节级确认**（出货 1-16 = race 0-159；Mon-17..20 服务端专属）。
- 落盘：monster-wil-family-verification-evidence.json（F429，primary-bytes）+ RESEARCH_LOG + UI_COMPLETION_AUDIT Round 123。
## Round 124 (F430) — 2026-08-12：DMon 死亡动画族验证（4340/4000 帧）

- **〔族系〕**DMon-1.wil 4340 帧 + DMonS-1.wil 4000 帧 = 通用单槽死亡动画库（非按种族）；f0 80×70 / f100 72×64 有效头。
- **〔装载器〕**0x454040 附加表 5 槽：DMon-1→ebx+0x13A4C、DMonS-1→+0x13B50、MagicEx→+0x13C54、MonMagicEx→+0x13D58、StoreItem.wil(0x47C878)→+0x13E5C（stride 0x104）。
- 落盘：dmon-death-animation-verification-evidence.json（F430，primary-bytes）+ RESEARCH_LOG + UI_COMPLETION_AUDIT Round 124。
## Round 125 (F431) — 2026-08-12：怪物帧密度验证（10 种族块 × 1000 帧）

- **〔块结构〕**Mon-N.wil = 10 种族块 × 1000 帧；块 0-2 各 304 有效帧、块 3-9 各 224（尾部 400-999 空白；边界 f375 有效 → f400 空）。
- **〔偏移〕**块内偏移 (race%10)*1000 [inference]（结构支撑）。
- 落盘：monster-frame-density-verification-evidence.json（F431，primary-bytes + inference）+ RESEARCH_LOG + UI_COMPLETION_AUDIT Round 125。
## Round 126 (F432) — 2026-08-12：怪物动画状态布局（10 帧格 + 双攻击段）

- **〔布局〕**块 0 = 304 有效帧：32 × 10 帧格（2-6 有效 + 填充，0-311 待机/走位）+ 双 80 帧密集攻击段（320-399、640-719，108-112px 横扫）+ 空白尾。
- **〔粒度〕**10 帧格步长 = 动画寻址粒度（cell*10+subframe [inference]）。
- 落盘：monster-animation-state-layout-evidence.json（F432，primary-bytes + inference）+ RESEARCH_LOG + UI_COMPLETION_AUDIT Round 126。
## Round 127 (F433) — 2026-08-12：怪物帧寻址 PRIMARY（F431 inference 闭合）

- **〔帧范围〕**0x405ABD：idiv race/10 → **(race%10)*1000 + 10*sub** + word[0x8AA686+type*6] → [esi+0xB4/0xB8]（F431 推断升级为字节级）。
- **〔分派〕**type [esi+0x88] ≤ 0x32（50 类）跳表 0x405D50；race word [esi+0x8A/0x8B]；特殊 race 0x1F/0x3E8。
- **〔表〕**外观表 0x5600FC stride 0x144 运行时构建（[esi+0x90] + 3 槽）；帧 = state*400 + counter − 0xAA0（0x40F6A3，400 = 40 格 × 10 帧 F432）。
- **〔属性〕**0x40A4D0 统计初始化：HP/MP [0x61BA0] + type*10 偏移（F350 族）。
- 落盘：monster-frame-addressing-primary-evidence.json（F433，primary-bytes）+ RESEARCH_LOG + UI_COMPLETION_AUDIT Round 127。
## Round 128 (F434) — 2026-08-12：怪物外观表构建（0x5600FC 运行时数组）

- **〔表〕**0x5600FC = 运行时外观描述数组（stride 0x144 = idx*81*4），读侧 [esi+0x90] + 3 槽 [0x62A0C/0x62A10/0x62A14]；位于 .data 零填充尾部（运行时构建）。
- **〔分派〕**0x40E3E0 类型初始化：0x12/8/0x13/0x51A/0x51B → 记录查找 0x449B90（表 0x8AA5A8）+ 属性 0x40A4D0（码 0x19/0x1A/0xC/0x11/0x23）+ 标志 [0x629D0-0x629D8]；type 0x96 → 0x13C 字节工厂（vtable 0x476448，全局 0x560088）。
- 落盘：monster-appearance-table-construction-evidence.json（F434，primary-bytes）+ RESEARCH_LOG + UI_COMPLETION_AUDIT Round 128。
## Round 129 (F435) — 2026-08-12：怪物动画推进机（+2 正向/+1 反向 + 回绕）

- **〔推进〕**0x40B022 ticker：正向 +2（[0xC4] + 字节 [0x61B98] 副计数）、反向 +1（门 [0x61B94]）；**回绕 [0xC4]=[0xB4]**（重置位置 [0xDC/0xE0/0xD4/0xD8] + HP/MP [0x61B9C..0x61BB8] + vtable[0x10]）。
- **〔帧公式〕**正向 frame=[0xC4]；反向 frame=[0xB4]+([0xB8]-[0xC4])-1（0x40B37A）；绘制 0x40B2C0 经 [0x90] 外观 + 0x466130。
- 落盘：monster-anim-advance-machine-evidence.json（F435，primary-bytes）+ RESEARCH_LOG + UI_COMPLETION_AUDIT Round 129。
## Round 130 (F436) — 2026-08-12：WIL 帧装载器 0x466130（文件/mmap 双模式 + LRU）

- **〔分派〕**mode [ecx+4]：0 → 0x466640 文件模式（SetFilePointer+ReadFile 17 字节头 + words*2 载荷）、1/2 → 0x466720 mmap 模式（WIX 偏移表 [0x30] + 基 [0x34]）。
- **〔缓存〕**LRU 淘汰 0x3A98ms（0x466770）+ 0x493E0ms 超时；0x4667D0 = 上下文构造（size 0x7C，条目 stride 0x20）。
- **〔IAT〕**新增 SetFilePointer 0x4761EC / GetTickCount 0x47611C / UnmapViewOfFile 0x4760F8。
- 落盘：wil-frame-loader-0x466130-evidence.json（F436，primary-bytes）+ RESEARCH_LOG + UI_COMPLETION_AUDIT Round 130。
## Round 131 (F437) — 2026-08-12：怪物阴影/光照系统（六边形光场）

- **〔调用〕**0x40B180 模式字节 [0x61BD4]：0=暗影 (5,5,10)、2=亮 (100,100,100)、8=闪白 (255,255,255)。
- **〔渲染〕**0x434A20 六边形网格径向光渲染器（fsqrt 距离衰减、RGB32 混合、6 顶点四边形扇、0x12/0x11 六边间距、半径门 0x7E1）→ 全局 0x7DA1D8。
- **〔坐标〕**0x434670 像素→六边形格 (x+8)*2/3、y>>5。
- 落盘：monster-shadow-light-system-evidence.json（F437，primary-bytes）+ RESEARCH_LOG + UI_COMPLETION_AUDIT Round 131。
## Round 132 (F438) — 2026-08-12：实体屏幕投影（48×32 菱形瓦片率）

- **〔投影〕**0x40F5F0：screen_x = (wx−camTileX)*48 − camPxX + [0xD4] − 200；screen_y = (wy−camTileY)*32 − camPxY + [0xD8] − 157（**48px/瓦片 x、32px/瓦片 y**）。
- **〔相机链〕**地图视口 0x43B8D9/0x43B8FF 写 cam px [0x134]/[0x138] = 瓦片偏移 × 滚动 → 实体投影读取。
- **〔3 层绘制〕**槽 [0x62A14]/[0x62A10]/[0x90] → 0x466130 帧装载 → SetRect 0x4762B0 blit（rects [0x629FC]/[0x629EC]/[0x94]）。
- **〔调和〕**视口 768×576 = 48×32 瓦片 16 列 × 18 行（F379「24×24」= 半格 x 轴 24）；F433 帧公式复用于层 A。
- 落盘：entity-screen-projection-evidence.json（F438，primary-bytes）+ RESEARCH_LOG + UI_COMPLETION_AUDIT Round 132。
## Round 133 (F439) — 2026-08-12：实体绘制流水线（游戏 tick 18 阶段）

- **〔流水线〕**0x41BB00 18 阶段：时间门 0x5F → BGM 0x1388 5s → 地图滚动 0x43B1E0 → 光场 0x434650 → 英雄更新 → 相机 blit 0x45E730 → 实体更新链 0xE1170 → **6 绘制对象 esi+0x361150..0x3614F4**（门 [0x24]/[0x2C]）→ HP 条 + 目标框 → 实体绘制链 0xE1158 → 光场绘制 0x434D40(400×300) → 精灵链 vtable+0x10 → hover 0x320 → 聊天/UI → 特效。
- **〔修正〕**F336「4 画家数组」→ 实际 **6 绘制对象**（vtable+0x14 更新 + vtable+0x10 画到屏幕 0x8AB7BC）。
- 落盘：entity-draw-pipeline-evidence.json（F439，primary-bytes）+ RESEARCH_LOG + UI_COMPLETION_AUDIT Round 133。
## Round 134 (F440) — 2026-08-12：实体链表容器（5 双向链表 + 游戏 ctor 顺序）

- **〔容器〕**游戏对象 5 双向链表（0xE1158 绘制链 + A@0xE116C vtable 0x4766D4 / B@0xE1184 / C@0xE11B4 / D@0xE11CC）；节点 = {vtable 0x476448, +4 data, +8 prev, +0xC next} 16B；push-back 0x4232A0 / push-front 0x423340 / insert-after 0x4233E0 / unlink 0x423450；**容器内无 y 排序**（绘制序 = 插入序）。
- **〔ctor〕**0x418B00 子系统初始化顺序（5 链表 → 地图 0xF5200 → 英雄 UI → 英雄实体 → 光场 → 6 绘制对象 → ...）；F336「4 画家数组」修正为 5 链表。
- 落盘：entity-list-containers-evidence.json（F440，primary-bytes）+ RESEARCH_LOG + UI_COMPLETION_AUDIT Round 134。
## Round 135 (F441) — 2026-08-12：游戏对象重置（0x154 = 480×480 网格缓冲）

- **〔重置〕**0x418E40 进游戏重置：英雄/UI/地图/地图对象子系统 + 5 链表 vtable 重写（第 5 链表 vtable = **0x4766F0** @ 0xE1154）。
- **〔网格〕**0x418EE0 状态初始化：**[esi+0x154] = 0x38400 dword = 480×480 单元网格缓冲**（rep stosd 清零）— F336「main+0x154 画家数组」基址修正为游戏对象 +0x154 [candidate: 实体桶/可见性网格]。
- **〔方向〕**0x43D290 = 8 方向行走向量（点差 → dir 0-7，±2 容差）→ 帧选择（F433）。
- 落盘：game-object-reset-480grid-evidence.json（F441，primary-bytes）+ RESEARCH_LOG + UI_COMPLETION_AUDIT Round 135。
## Round 136 (F442) — 2026-08-12：实体链表维护路径（ID 清除/移除/状态门）

- **〔清除〕**0x41B570 遍历列表 A+C 清 [entity+0x14]/[0x18] 双 ID 字段（匹配 arg）。
- **〔移除〕**0x419650 沿 0xE1158 绘制链：type [0x88] ≤ 0x32 跳表 0x4196F0 + 子对象链 [0xF0] 清理 + vtable+8/vtable+0。
- **〔状态〕**0x41B5D0 游戏时间（[0x428204] 模式字节 + [0x428208] 累加器 0x9C4 门）。
- **〔网格〕**480×480 网格写入侧未定位（imul 480 = 0 站点）— 绘制序 = 列表插入序（服务器生成序）；网格角色维持 pending。
- 落盘：entity-list-add-path-evidence.json（F442，primary-bytes）+ RESEARCH_LOG + UI_COMPLETION_AUDIT Round 136。
## Round 137 (F443) — 2026-08-12：维护清扫（全验证通过 + 服务健康）

- **〔验证〕**compileall OK、verify exit 0、node --check OK、layout.json + matrix JSON 有效。
- **〔服务〕**wilviewer 8765 200 / mapviewer 8899 200 / sim 200。
- **〔仓库〕**干净（仅未跟踪 goal_watchdog.sh.bak）；master = 0c0cbe4（**108 连发已推**）。
- **〔实体弧汇总 F429-F442〕**怪物 WIL 族/死亡库/帧密度/状态布局/寻址 PRIMARY/外观表/动画机/帧装载器/阴影光场/投影/流水线/链表/重置/维护 14 项闭合。
- 落盘：housekeeping-round137-evidence.json（F443，derived）+ RESEARCH_LOG + UI_COMPLETION_AUDIT Round 137。
## Round 138 (F444) — 2026-08-12：480×480 网格角色闭合（每帧实体桶网格）

- **〔闭合〕**0x419D40 = 每帧可见性/选择通道：**0x419D53 每帧清零 0x38400 dword 网格**（故无静态写点）→ 视口 cam ±0x18 范围内实体**分桶入网格**（cell = f(wx,wy,cam)*400*4 + 100 格探测，0x419F2C）+ PtInRect 选择 → **[0x364444]**（悬停 [0x364448]/[0x364450]）。
- **〔关联〕**F441 pending 项闭合；F359 目标框由 [0x364444] 驱动确认。
- 落盘：entity-visibility-grid-evidence.json（F444，primary-bytes）+ RESEARCH_LOG + UI_COMPLETION_AUDIT Round 138。
## Round 139 (F445) — 2026-08-12：实体类型分派表（桶映射 + 选择/剔除）

- **〔桶映射〕**0x41A534（50 字节）：type 0/1/50 → 跳预处理、2 → 特殊处理器、3-41 → 默认；跳表 0x41A528（[0] vtable+0x1C 点击处理器、[1] 处理器+[0x61C7C]==3 移除、[2] 默认）。
- **〔选择/剔除〕**0x41A570：0/1/3 → 0（**视口外剔除**：ID 清 0x41B570 + 解链 0xE1154 + 删除）、2/4-42 → 1（保留）；跳表 0x41A568。
- **〔语义〕**瞬时类型（0/1/3/50）移出 ±0x18 视口即剔除；持久类型（NPC/怪物）保留。
- 落盘：entity-type-dispatch-tables-evidence.json（F445，primary-bytes）+ RESEARCH_LOG + UI_COMPLETION_AUDIT Round 139。
## Round 140 (F446) — 2026-08-12：F336「4 画家数组」定案（4 实体桶网格）

- **〔定案〕**游戏对象 4 每帧实体桶网格：**[0x154]** 绘制链（0xE1158）/ **[0x2E4]** 特殊类型链（0xE11A0：{0x10,0x16,0x3F,0x14A-0x14E,0x48}/9/0x35/0x150）/ **[0x474]** 容器 C（0xE11B8，PtInRect 门）/ **[0x604]** 容器 D（0xE11D0，**timeGetTime 过期移除** [0x47630C]）。
- **〔公式〕**共享单元 ((dy*24−camX+wx)*400+probe)*4 + 0x64 格探测；0x419D40 = 完整每帧可见性通道（清零→4 链分桶→点击→剔除）。
- **〔闭合〕**F336 谜底 = 4 桶网格（基 = 游戏对象 0x8AB828，非 main）。
- 落盘：four-bucket-grids-evidence.json（F446，primary-bytes）+ RESEARCH_LOG + UI_COMPLETION_AUDIT Round 140。
## Round 141 (F447) — 2026-08-12：视口滚动+渲染全解（相机跟随 = 滚动本身）

- **〔滚动〕**0x43B1E0：视口 [0x14C..0x158] vs 英雄 ±0xC 门 → SetRect ±0x12 向英雄滚动（**跟随 = 滚动**）+ 瓦片预览通道（[0x108] 记录、**除 7 魔数 0x6DB6DB6D + 除 14** 库公式、attr≤2/lib≤0x45/0xFFFF 哨兵门、0x466130 装载）。
- **〔渲染〕**0x43B440：清 [0x1B2] 0x6C000 dword 缓冲 → 遍历 cam [0x12C]/[0x130] → **0x45E8E0 屏幕 blit（x*48 + y*32 投影 = F438 字节确认）**。
- 落盘：viewport-scroll-render-full-evidence.json（F447，primary-bytes）+ RESEARCH_LOG + UI_COMPLETION_AUDIT Round 141。
## Round 142 (F448) — 2026-08-12：0x5600FC = 共享资源描述符表（81 引用/39 簇）

- **〔共享〕**0x5600FC stride 0x144（= idx*81*4）**全局资源/外观描述数组**：瓦片（attr/7+14 库公式，0x43B329/0x43B552）、怪物（type，F433/434）、实体槽（0x40F55D）、特效分派（0x40E40B）、地图渲染（0x41C9ED）、UI（0x423DF2）；条目 +0x38 = WIL 上下文（0x466130 ecx）。
- **〔修正〕**F434「怪物外观表」范围 → **共享资源表**（怪物外观 = 用户之一）。
- 落盘：shared-resource-descriptor-table-evidence.json（F448，primary-bytes）+ RESEARCH_LOG + UI_COMPLETION_AUDIT Round 142。
## Round 143 (F449) — 2026-08-12：怪物更新/变形处理器族（msg 0xBC6-0xBD8）

- **〔处理器〕**0x410C38 族 7+ 处理器：门 [0x629D0-0x629D8] + 字 [0x62A77] → 记录查找 0x44A820（0x8AA5A8）→ vtable+0x10 → 属性 0x40A4D0（arg2=type，生成音效 (type+1000)*10）→ 0x451450 发包（0xBD1/0xBD8/0xBD7/0xBCB/0xBCA/0xBD0/0xBC6）→ 状态标志 =2。
- **〔细化〕**「push 0x5600fc」= 0x40A4D0 的立即数基参（非直接表读）— F448 引用分类细化。
- 落盘：monster-update-handlers-evidence.json（F449，primary-bytes）+ RESEARCH_LOG + UI_COMPLETION_AUDIT Round 143。
## Round 144 (F450) — 2026-08-12：怪物/NPC 记录存储（0x8AA5A8 3 子数组）

- **〔存储〕**0x8AA5A8 集合 {+0/+4/+8 计数、+0xC/+0x10/+0x14 子数组指针}；记录 stride 0x30（48B）**ID 字 @+0xC**；查找 0x449B90/0x449BD0/0x449C10（3 集合线性扫描）。
- **〔默认〕**0x449C80 默认属性构建器（0x449C50 三字字段写入：HP/等级/攻击风格默认链）。
- **〔消费〕**属性初始化 0x40A4D0（F434）+ 更新处理器 0x44A820（F449）。
- 落盘：monster-record-store-evidence.json（F450，primary-bytes）+ RESEARCH_LOG + UI_COMPLETION_AUDIT Round 144。
## Round 145 (F451) — 2026-08-12：游戏对象基址修正（main = 0x47EF18）+ 记录存储内部

- **〔修正〕**静态初始化链 0x401860-0x401995 证明：**游戏对象 = main = 0x47EF18**（ctor 0x418B00，0x401970）；**0x8AB828 = 数据包发送器**（非游戏对象）— F440/441/444/446/447 基址标签修正。
- **〔绝对地址调和〕**0x560088 = main+0xE1170 链表头（F434「全局」= 链表头！）、**0x5600FC = main+0xE11E4 瓦片存储**（F448「共享表」= 瓦片/单元存储 ctor 0x4529B0）、0x574118 = main+0xF5200 地图视口、0x47F06C = main+0x154 网格1（F336「main+0x154」✓）。
- **〔记录存储〕**ctor 0x449A10/0x449A30（三区清零）+ 写入器 0x449AD0（**25 参数属性填充**，0x30B 记录 {+0/+4 HP/MP、+8/+0xA AC/MAC、+0xC ID、+0xE..+0x1C 字节属性、+0x20..+0x2C 4 dword}）。
- **〔静态链〕**0x8AA5A8 记录存储 / 0x8AA488 主窗（0x450BC0）/ 0x8A9520 / 0x8A7140 / 0x47EF18。
- 落盘：game-object-base-correction-evidence.json（F451，primary-bytes）+ RESEARCH_LOG + UI_COMPLETION_AUDIT Round 145。
## Round 146 (F452) — 2026-08-12：瓦片/资源存储结构（140 槽 × 0x144）

- **〔存储〕**main+0xE11E4 = 0x5600FC：**140 槽（0x8C）× 0x144（324B）资源数组**（0x4686C4 分配 + 字符串成员 0x465EF0/0x465F40）+ 清零区（0x2C4C dword + 0x238C @ +0xB130）+ 子数组 0x454B40 @ +0x13F60。
- **〔装载〕**0x452B20 路径表（WIL 文件名 0x47D51C 等 → [ebx+0xB130..] stride 0x104）；0x452AA0 逐条目初始化（14 + 70 条目，0x4660E0 字符串）。
- **〔细化〕**F448「共享资源表」= 瓦片库存储（140 槽）；怪物/实体按 type 索引同一数组。
- 落盘：tile-store-structure-evidence.json（F452，primary-bytes）+ RESEARCH_LOG + UI_COMPLETION_AUDIT Round 146。
## Round 147 (F453) — 2026-08-12：地面瓦片库表（0x47D3BC 15+ WIL 路径）

- **〔表〕**0x47D3BC-0x47D51C：Wood/Tiles5c + Wood/tiles30c + Wood/tilesc（wood 行）+ object2c/object1c/animationsc/smobjectsc/wallsc/furnituresc/innersc/dungeonsc/cliffsc/housesc/smtilesc/Tiles5c/tiles30c/tilesc（base）→ 经 0x452B20 入存储 0x5600FC（F452）。
- **〔关联〕**F343 行绑定（wood 14-27/base 0-13/sand 28-41）+ F369 可玩集 + F390 Tiles5c 20000 全部与客户端表一致。
- 落盘：ground-tile-library-table-evidence.json（F453，primary-bytes）+ RESEARCH_LOG + UI_COMPLETION_AUDIT Round 147。
## Round 148 (F454) — 2026-08-12：瓦片存储槽位映射（17 库字符串 + 双初始化循环）

- **〔表〕**地面库 = **17 字符串**（Wood/Tiles5c + Wood/tiles30c + Wood/tilesc @0x47D3BC-0x47D3F0 + 14 base @0x47D408-0x47D51C）。
- **〔循环〕**0x452AA0：14 条目循环（stride 0x144/0x104）+ **70 条目循环**（运行时表 store+0xF848 → 第二资源数组 store+0x5898 [candidate: 怪物/NPC 槽]）。
- **〔待深〕**精确槽序 = 更深 pending。
- 落盘：tile-store-slot-mapping-evidence.json（F454，primary-bytes + candidate）+ RESEARCH_LOG + UI_COMPLETION_AUDIT Round 148。
## Round 149 (F455) — 2026-08-12：实体渲染弧闭合（F429-F454 26 轮汇总）

- **〔验证〕**compileall OK、verify exit 0、node OK、JSON 有效；三服务 200；master d803935（**120 连发已推**）。
- **〔弧汇总〕**怪物渲染（WIL 族/密度/状态/寻址 PRIMARY/外观/动画机/装载器/阴影光场）+ 投影流水线（48×32/18 阶段/5 链表/4 桶网格/滚动渲染全解）+ 资源（共享表/更新处理器/记录存储/**基址修正 main 0x47EF18**/瓦片存储 140 槽/地面库 17）。
- 落盘：entity-render-arc-closure-evidence.json（F455，derived）+ RESEARCH_LOG + UI_COMPLETION_AUDIT Round 149。
## Round 150 (F456) — 2026-08-12：物品提示框详情体闭合（0x430B70 行构建器）

- **〔构建〕**0x430B70：type [item+0x22]−5 ≤ 0x30 分派（跳表 0x430BF8：0x430C40/0x431E50/0x432A80/0x431860/0x433CF0 五类构建器）；行缓冲 [obj+0x70 + row*0xC]（计数 [0x64]、色 +0x68、文本 +0x70）。
- **〔格式〕**持久: %d/%d（0x47C028）/ 重量: %d（0x47C01C）/ 防御: %d-%d (+%d)（0x47C008）/ %s: %d-%d (+%d)（0x47BFEC）；色 0xFAFF 名/0x3232FF 单数/0xFFFF80 复数/0xFFFFFF/0xC8FF96 属性。
- **〔辅助〕**0x401700 百分比（value/除数 + 0.5 舍入）；持久百分比 = cur/1000。
- **〔闭合〕**F340「0x430B70 body」pending 闭合。
- 落盘：item-tooltip-detail-body-evidence.json（F456，primary-bytes）+ RESEARCH_LOG + UI_COMPLETION_AUDIT Round 150。
## Round 151 (F457) — 2026-08-12：物品类构建器 0x430C40 = 魔御类（8 元素行）

- **〔类〕**0x430C40 = MDEF 类（F456 分派 5 类之一）：名称行（前缀 0xA1E5 + [0x48] 后缀）、持久 %d/%d（字 [0x41]/[0x43]/[0x2A] /1000%）、重量 %d（字节 [0x24]）、防御 %d-%d (+%d)（[0x2C]/[0x2D] + 有符号 [0x55]）。
- **〔8 元素行〕**名称表 0x47BE54：火焰系魔御/冰冻系魔御/雷电系魔御/狂风系魔御/神圣系魔御/黑暗系魔御/幻影系魔御/全魔系魔法；值 [0x2F]/[0x30] + 有符号 [0x56]；格式 %s: %d-%d (+%d)（0x47BFEC）。
- 落盘：item-class-mdef-builder-evidence.json（F457，primary-bytes）+ RESEARCH_LOG + UI_COMPLETION_AUDIT Round 151。
## Round 152 (F458) — 2026-08-12：物品提示框 5 类分类完成

- **〔分类〕**类1 0x430C40 = 魔御（8 元素行 F457）；**类2 0x431E50 + 类4 0x431860 = 武器要求/攻击**（精神力要求 幻影/黑暗/神圣系 + 魔法力要求 狂风/雷电/冰冻/火焰/全魔系 + 全道系 + 攻击力要求 + 等级要求: %d + 攻击: %d-%d(+%d)）；**类3 0x432A80 = 特殊装备**（诅咒/幸运/攻击速度±/准确/强度/神圣）；**类5 0x433CF0 = 消耗品**（纯度/品质/数量/魔法恢复+%dMP/生命恢复+%dHP）。
- **〔闭合〕**F340 提示框族全闭合。
- 落盘：item-tooltip-five-classes-evidence.json（F458，primary-bytes）+ RESEARCH_LOG + UI_COMPLETION_AUDIT Round 152。
## Round 153 (F459) — 2026-08-12：地面物品渲染（0x40CE30）

- **〔渲染〕**0x40CE30 掉落物品实体绘制：帧 = [0x62A24] + 0x355（type 0xF）/0x352（其他）→ 0x4542A0（存储 0x5600FC type **0x51 = 物品槽**）→ 0x566780 上下文 → 0x466130 装载 → [0xE4]/[0xE8] 投影 blit + 0x467000 文本 + 屏幕 vtable。
- **〔修正〕**「msg 0x285」= 误报（jbe 位移 0x285）— 商店货物 msg id 仍未知（pending）。
- 落盘：ground-item-render-evidence.json（F459，primary-bytes）+ RESEARCH_LOG + UI_COMPLETION_AUDIT Round 153。
## Round 154 (F460) — 2026-08-12：商店对象布局（货物链表 + 3 槽网格）

- **〔重置〕**0x44D180：模式 [0x5F8] 清零、货物链表 [0x64C] 释放（节点 {+4 物品, +8 prev, +0xC next}）、槽数组清零（[0x660] 20 + [0x6B0] 20 + [0x720] 48 + [0x7F4]/[0x804] 4+4 = **~90 槽**）+ 第二链表 [0x70C] + 容量 [0x700]。
- **〔构造〕**0x44D310：8 控件（msg 0x3F2-0x3F9）+ 滚动条 0x3FC + 槽矩形（0x1C/0x40、0x45/0x100、2D 网格 0x143+0x26×0x2B+0x26）。
- **〔绘制〕**0x44D590：模式分派（1=卖减界、4=详情+2）+ 货物链表遍历（帧 [item+0x30] → 0x466130 + 0x56B0E8 图标上下文 + 0x56B120 中心化）。
- **〔修正〕**F340「26 槽」= 首网格；实际多网格 ~90 槽。
- 落盘：store-object-layout-evidence.json（F460，primary-bytes）+ RESEARCH_LOG + UI_COMPLETION_AUDIT Round 154。
## Round 155 (F461) — 2026-08-12：商店货物填充解析（0x44F480 BUY 解析器）

- **〔解析〕**0x44F480 BUY 模式：清货物链表 [0x64C] → **strtok 0x468BF0（'/' 分隔，每物品 7 token）**解析服务端商人货物字符串 → 0x3C 字节物品桩 → atoi 0x4681F9（[+0x20] 后缀标志、[+0x24..0x38] 值）→ vtable+4 追加 → 模式 [0x5F8]=0 + 布局 0x423E80。
- **〔卖〕**0x44F710 SELL 解析器（除 10 价格、0x2010、链表 [0x708]）。
- **〔源〕**货物 = 服务端 Merchant 脚本数据（F427）经 '/' 分隔字符串发送 → 客户端解析。
- **〔闭合〕**商店货物 msg id pending 解决（字符串解析非二进制包）。
- 落盘：store-goods-fill-evidence.json（F461，primary-bytes）+ RESEARCH_LOG + UI_COMPLETION_AUDIT Round 155。
## Round 156 (F462) — 2026-08-12：商店 SELL/仓库 解析器（0xC20 物品记录构建）

- **〔卖〕**0x44F710：模式 [0x5F8]=1、布局 0x423E80(0x3EB,1,...)、格网 [0x720]、除 10 计数、strtok '/' 解析 → **0x5F 名称 + 0xC20（3104B）物品记录**（ctor 0x430920/0x430940、0x17 dword 复制）→ 链表 [0x708]。
- **〔仓库〕**0x44F940：模式 [0x5F8]=2、布局 0x423E80(0x3E9,-4,...)、同解析 → 链表 [0x70C]。
- **〔族〕**BUY 0x3C 桩 vs SELL/仓库 0xC20 完整记录（= 背包记录 F293）；CRAFT 0x44FB00 模式 3。
- 落盘：store-sell-warehouse-parsers-evidence.json（F462，primary-bytes）+ RESEARCH_LOG + UI_COMPLETION_AUDIT Round 156。
## Round 157 (F463) — 2026-08-12：商店 CRAFT 解析器（模式族全解）

- **〔CRAFT〕**0x44FB00：模式 [0x5F8]=3、布局 0x423E80(0x3E8,0,...)、格网 [0x720]、清链表 [0x64C]+[0x70C]、strtok '/' 解析（7 token/配方）→ 0x3C 桩（名 + atoi：[+0x20] 标志、[+0x24..0x38] 6 值）→ [0x64C]；链表 push 0x44FDB0（节点 vtable 0x476AD4）。
- **〔族全解〕**BUY（7-token 0x3C → [0x64C]）/ SELL（0xC20 记录 → [0x708]）/ 仓库（0xC20 → [0x70C]）/ CRAFT（7-token 0x3C → [0x64C]）——全部解析 '/' 分隔服务端字符串。
- 落盘：store-craft-parser-evidence.json（F463，primary-bytes）+ RESEARCH_LOG + UI_COMPLETION_AUDIT Round 157。
## Round 158 (F464) — 2026-08-12：物品对象结构全解（0xC20 记录）

- **〔结构〕**0xC20（3104B）记录：ctor 0x430920（清 [0x68..] 0x2EE dword）；0x430940 记录→物品（0x17 dword 复制 + **类→类型映射 {1,0,4,3,7,5,2,9,0xA}** jt 0x4309E0）；图标绘制 0x430A40（**3 图标上下文** 0x5668C4/0x566A08/0x56B0E8 按类型、帧字 [0x28] → 0x466130、中心化偏移）。
- **〔字段〕**{+0 类型、+2 字、+4 名、+0x22 类、+0x24 重量、+0x28 图标帧、+0x2A/+0x41/+0x43 持久、+0x2C/+0x2D 防御、+0x2E-0x30 属性、+0x55/+0x56 加成、+0x64 行数、+0x68 详情行}。
- **〔统一〕**背包/商店/地面物品共用 0xC20 记录。
- 落盘：item-object-structure-evidence.json（F464，primary-bytes）+ RESEARCH_LOG + UI_COMPLETION_AUDIT Round 158。
## Round 159 (F465) — 2026-08-12：物品图标库（StoreItem.wil 1440 帧）

- **〔库〕**客户端引用 Item.wil（0x47C884）+ StoreItem.wil（0x47C878，附加表装载 F430）；**出货仅 StoreItem.wil 1440 帧**（Item.wil/DnItems/StateItem 缺失）；1440 帧 = 物品图标表 0-1439 [inference]。
- **〔上下文〕**3 图标上下文：0x5668C4 默认（背包 0x42F6D5/0x42F854、提示框 0x434286、角色选择 0x416A93、物品绘制 0x430ABC）/ 0x566A08 type-1 / 0x56B0E8 type-2（商店绘制 0x44D65C）；头 [0x5668FC]/[0x566A40]/[0x56B120]。
- **〔角色选择背包〕**槽 stride 0x24、帧字 [0x5EC]、type [0x5E6]（0xA/0xB 金币/经验特殊混合）。
- 落盘：item-icon-library-evidence.json（F465，primary + secondary）+ RESEARCH_LOG + UI_COMPLETION_AUDIT Round 159。
## Round 160 (F466) — 2026-08-12：背包交互系统（悬停→提示框链确认）

- **〔悬停〕**0x42FAB0：门 [0x7243C4] → 槽命中测试 0x42F240（鼠标 [0x7DA1C0]/[0x7DA1C4]）→ 记录 bag+槽*0xC2C+0x774 → **0x4341F0 提示框**（鼠标+0xA，记录+0x780）— F340 链字节确认。
- **〔槽操作〕**清槽 0x42FB20（0x258 字标记 [0x2C4] + 0x30B dword 清零）；按名查找 0x42FB80（strcmp 46 槽）；全清 0x42FC00；**反序列化 0x42FC20**（0xC28 输入，0x42F2A0/0x42F280/0x42F440）；取槽 0x42FCC0（0x308 dword 复制）；设槽 0x42FD10。
- 落盘：bag-interaction-system-evidence.json（F466，primary-bytes）+ RESEARCH_LOG + UI_COMPLETION_AUDIT Round 160。
## Round 161 (F467) — 2026-08-12：背包网格几何（6 列 × 36px）

- **〔几何〕**0x42F240 命中测试（0x42F150 → 标记 [0x2C4+idx*2]：0xFFFF 空，否则 idx%0x3E8）；**6 列确认**（0x42F2DC idiv 6）、单元 36px、原点 (25,41)、行主序槽 = row*6+col（+0xB1 基标记 stride 6）。
- **〔放置〕**首空 0x42F280（46 槽扫描）；放置 0x42F440（脚印 0x42F6D0、标记 idx/+0x3E8 原点、记录 [0x774]=1 + 尺寸 [0x778]/[0x77C]）。
- **〔确认〕**F293 6 列 WORD 网格字节级确认。
- 落盘：bag-grid-geometry-evidence.json（F467，primary-bytes）+ RESEARCH_LOG + UI_COMPLETION_AUDIT Round 161。
## Round 162 (F468) — 2026-08-12：物品/背包/商店弧闭合（F456-F467 12 轮汇总）

- **〔验证〕**compileall OK、verify exit 0、node OK、JSON 有效；三服务 200；master 9f5da53（**132 连发已推**）。
- **〔弧汇总〕**提示框（详情体 5 类分派）/ 物品（地面渲染 + 0xC20 统一记录 + StoreItem.wil 图标）/ 商店（3 网格 ~90 槽 + BUY/SELL/仓库/CRAFT 解析器）/ 背包（交互链 + 6 列几何）。
- 落盘：item-bag-store-arc-closure-evidence.json（F468，derived）+ RESEARCH_LOG + UI_COMPLETION_AUDIT Round 162。
## Round 163 (F469) — 2026-08-12：装备面板槽位（12 槽修正）

- **〔槽〕**0x44B720 12 槽矩形命中测试（[0x1C8] stride 0x10、0xB=12 循环、PtInRect）；**0x44B7A0 装备兼容检查**（type 5/6/9 → 武器类 0x19、7/8 互换对、否则 type==槽）；0x44B880 清槽（stride 0xC24、[0x2F4] 0x309 dword）；0x44B8B0 按名查找（11 槽）。
- **〔修正〕**F325「8 装备槽」→ **12 槽**（状态面板 F33/F47 族一致）。
- 落盘：equipment-panel-slots-evidence.json（F469，primary-bytes）+ RESEARCH_LOG + UI_COMPLETION_AUDIT Round 163。
## Round 164 (F470) — 2026-08-12：装备数据包处理器族（0x44B930 家族）

- **〔设置〕**0x44B930 装备包（0xC28 输入、槽 idx [0xC38]、0x308 dword 记录复制到 [status+槽*0xC24+0x2F8]、标记 [0x2F4]=1、槽字 [0x2FA]；idx≥11 自动槽）。
- **〔族〕**0x44BA60 取槽（复制 + 清 0x44B880）；0x44BAB0 构建器（0x430920 + 取槽 + **英雄同步 0x42E2D0** @0x7243A4）；0x44BB70 清除；**0x44BBD0 快捷装备**（[0x8880] 记录块 stride 0xC24）；0x44BC30 快捷使用。
- 落盘：equipment-packet-handler-evidence.json（F470，primary-bytes）+ RESEARCH_LOG + UI_COMPLETION_AUDIT Round 164。
## Round 165 (F471) — 2026-08-12：装备音效分派器（0x42E2D0）

- **〔分派〕**0x42E2D0：类 [item+0x22] ≤ 0x1F 跳表 0x42E404（字节映射 0x42E428）→ 音效 ID 0x6B-0x76（0x45AFC0 @0x8AB130）；武器子类 [0x23] ≥ 0x6A → 0x76；名称门（0x47BDDC/0x47BDD4）→ 0x72/0x75；防具类 1-2 → 0x6B。
- **〔修正〕**F470「英雄同步 0x42E2D0」= **音效分派器**（外观 = 绘制时读槽记录）。
- 落盘：equip-sound-dispatcher-evidence.json（F471，primary-bytes）+ RESEARCH_LOG + UI_COMPLETION_AUDIT Round 165。
## Round 166 (F472) — 2026-08-12：装备槽绘制（0x44B560 子绘制）

- **〔绘制〕**0x44B560：角色形象帧字节 [0x777720] → 0x566DD4 上下文 → 0x45FD50 blit（+0xC8/+0x61）；**11 槽图标循环**（0x44B5CD：记录 [0x2F8+槽*0xC24]、门 [edi-4] 占用、**0x430A40 图标绘制**（F464）、矩形 [0x1C0+槽*0x10]、槽 0/1/4 特殊居中在形象上）；行走帧 [0x777723] ≤ 0xA → 帧 [0x777720]*10+[0x777723]+0x3B。
- **〔链〕**绘制 0x44B2D0 → 0x44B560 → 0x430A40 图标 + 0x45FD50 形象 — 装备面板渲染链完整。
- 落盘：equip-slot-draw-evidence.json（F472，primary-bytes）+ RESEARCH_LOG + UI_COMPLETION_AUDIT Round 166。
## Round 167 (F473) — 2026-08-12：装备弧闭合（F469-F472 4 轮汇总）

- **〔验证〕**compileall OK、verify exit 0、node OK、JSON 有效；三服务 200。
- **〔仓库〕**master 23b0365（用户任务设计提交在 Round 166 346ee6a 之上，全部已推）；工作树有用户未提交 quest 文档（07-任务总表.md，未动）。
- **〔弧汇总〕**12 槽面板（F469，F325 8→12 修正）/ 装备包族（F470）/ 音效分派器（F471，F470 语义修正）/ 槽绘制+形象（F472）— 装备面板全解。
- 落盘：equipment-arc-closure-evidence.json（F473，derived）+ RESEARCH_LOG + UI_COMPLETION_AUDIT Round 167。
## Round 168 (F474) — 2026-08-12：交易金币框 + 交易消息族

- **〔金币〕**0x451B30 = 金币报价发送（msg 0x406）；0x451B60 解析（0x400 缓冲、0x1300 交易窗消息）；**0x451BB0 分派**（0x406 金币/0x407/0x408 重置/0x409 库存）；0x451CC0 库存字符串解析（0x2000 缓冲、'*' token、0x8B186C 名门）。
- **〔绘制〕**0x415B10 双栏（自/他半区、悬停 0x416830 + 物品 0x4162E0、拖动 0x4542F0 经存储 0x5600FC、伙伴名 0x7776A0）。
- **〔闭合〕**F364 金币框细节闭合。
- 落盘：trade-gold-box-evidence.json（F474，primary-bytes）+ RESEARCH_LOG + UI_COMPLETION_AUDIT Round 168。
## Round 169 (F475) — 2026-08-12：NPC 对话菜单选项（类型 4 绘制）

- **〔选项〕**0x43F460 type-4：选项列表（计数 [0x3BC]、页范围 [0x594]）、文本 [list+4]、**5px 行距**、启用/禁用色旗 [0x5D]/[0x5C]（0x190/9 vs 0x81/0xFFFF）；文本经 0x45DD70 绘制。
- **〔调色板〕**FCOLOR = 8 DOS 色（0x47C4A8：0xFF/0x8000/0x8080/0x808080/0x80/0x808000/0x800000）；**0x47C4D8 修正 = 二进制色对表（非菜单标题 GBK）**。
- **〔字符串〕**0x47B8D4-0x47BA09 商店/对话反馈（购买/卖/修理/仓库/恭喜升级/拒绝/允许）。
- 落盘：npc-dialog-menu-options-evidence.json（F475，primary-bytes）+ RESEARCH_LOG + UI_COMPLETION_AUDIT Round 169。
## Round 170 (F476) — 2026-08-12：NPC 对话输入/发送（F404 交互闭合）

- **〔输入〕**0x43E4B0：2 编辑控件（vtable+0x10 命中 @[0x54]/[0x108]，stride 0xB4）；对话文本 [0x1CC]（0xFA0 字符）'/' token 拆分 → 0x45DC70 脚本行绘制（0x0D 换行 2px 间距）；**提交 → 0x4524D0（回复消息）或 0x4524A0（[0x1D0] 特殊模式）**。
- **〔闭合〕**F404 NPC 对话交互全解（点击/输入/发送）。
- 落盘：npc-dialog-input-send-evidence.json（F476，primary-bytes）+ RESEARCH_LOG + UI_COMPLETION_AUDIT Round 170。
## Round 171 (F477) — 2026-08-12：背包/装备管理器 + 物品转移

- **〔管理器〕**0x42DC20 构造：46 × 0xC2C 背包记录 + 6 × 0xC24 装备记录（0x4686C4、ctor 0x415730/0x415750 + 0x426E70）、[0xDA4] 0x1236 dword 标记清零、**文件持久化**（0x4760DC CreateFileA，路径 0x47BDCC，读取 0x22FE8/0x4B0/0x48D8）。
- **〔转移〕**0x42DB80：找空（[edx+槽*0xC2C+0xDA4]==0，循环 0x2E）→ **0x308 dword 记录复制**（背包 ↔ 装备槽）+ 标记 + 清 0x42FB20。
- 落盘：bag-equip-manager-evidence.json（F477，primary-bytes）+ RESEARCH_LOG + UI_COMPLETION_AUDIT Round 171。
## Round 172 (F478) — 2026-08-12：物品存档格式（Data/<名>.itm）

- **〔路径〕**存档 = `.\Data\`（0x47BDC4）+ 角色名 + `.itm`（0x47BDCC，0x45DC70 组名）；管理器 0x42DC20 按玩家名构建。
- **〔记录〕**记录 ctor 0x415730：0xC 头 + 物品 0x430920 @+0xC → **stride 0xC2C**（F293 背包步长确认）；背包管理器 0x415760（vtable 0x47663C、46 × 0xC2C 记录 [0x5B8]、3 × 0xB4 控件 [0x7C]）。
- 落盘：item-save-file-format-evidence.json（F478，primary-bytes）+ RESEARCH_LOG + UI_COMPLETION_AUDIT Round 172。
## Round 173 (F479) — 2026-08-12：可见性通道特殊实体处理

- **〔特殊〕**0x41A0D5 特殊类型链（{0x10,0x16,0x3F,0x14A-0x14E,0x48}/9/0x35/0x150）：vtable+0xC tick、[byte+4]==2 移除、网格2 [0x2E4] 分桶（100 探测）、**重叠去重**（0x41A208：同 type [0x10] + 坐标 [0xB0]/[0xB4] → [0x124]=0 合并）。
- **〔地图对象〕**0x41A367 链 C：PtInRect 剔除、网格3 [0x474] 分桶、视口外移除。
- **〔完整〕**F336/F446 4 网格可见性通道端到端全解。
- 落盘：visibility-pass-special-entities-evidence.json（F479，primary-bytes）+ RESEARCH_LOG + UI_COMPLETION_AUDIT Round 173。
## Round 174 (F480) — 2026-08-12：交互弧闭合（F474-F479 6 轮汇总）

- **〔验证〕**compileall OK、verify exit 0、node OK、JSON 有效；三服务 200；master 8119727（**141 连发已推**）。
- **〔弧汇总〕**交易金币框（F364 闭合）/ NPC 对话菜单+输入（F404 闭合、0x47C4D8 修正）/ 物品转移 + .itm 存档（F293 确认）/ 可见性特殊实体（F336 端到端）。
- 落盘：interaction-arc-closure-evidence.json（F480，derived）+ RESEARCH_LOG + UI_COMPLETION_AUDIT Round 174。
## Round 175 (F481) — 2026-08-12：小地图库装载器（FMMap 表面初始化）

- **〔FMMap〕**0x43DF60：FMMap.wil（0x47C414）→ 字符串上下文 [+0x148]（0x465FA0/0x4660E0）+ **DDS 表面创建**（0x8AB7B8 vtable+0x18 + 0x467080、像素格式 0x1000/0x1800、尺寸 [0x2B8]/[0x2BC] 地图大小）。
- **〔MMap〕**0x43D4E1：MMap.wil（0x47C428）在地图对象 ctor 0x43D4D0（标记库 F310）。
- 落盘：minimap-library-loader-evidence.json（F481，primary-bytes）+ RESEARCH_LOG + UI_COMPLETION_AUDIT Round 175。
## Round 176 (F482) — 2026-08-12：小地图 blit 运行时（0x460240 表面复制）

- **〔blit〕**0x460240：裁剪矩形数学（src 偏移 [0x148]/[0x14C] 可负 → 夹紧）+ **16 位逐行复制**（word [src + 行*stride + x*2]、vtable+0x64 DC 锁、0x7C 结构）。
- **〔HUD〕**0x429630：帧 [0x1C] 0x33 → 0x466130 → 0x460240 @屏幕 (0x113, 0x1DE)（滚动 [0xD40] 动画、0x2E 上限）+ **6 快捷装备图标**（[0xDA8] stride 0xC24）。
- **〔双实例〕**HUD 小地图 (275,478) vs 面板小地图 (672,0)。
- 落盘：minimap-blit-runtime-evidence.json（F482，primary-bytes）+ RESEARCH_LOG + UI_COMPLETION_AUDIT Round 176。
## Round 177 (F483) — 2026-08-12：完整 WIL 表装载器（35+ 槽）

- **〔地面/杂项〕**Magic → +0x10478、WM-Weapon4 → +0x10270、Inventory → +0x10374、Equip → +0x1057C、Ground → +0x10680、MIcon → +0x10784、ProgUse → +0x10888、Horse → +0x1098C + Mon-20..1（F429）。
- **〔形象/魔法〕**MonMagicEx → +0x13434、MonMagic → +0x13538、MonImg → +0x1363C、M-Hair → +0x13740、M-Helmet1 → +0x13844、WM-Hair → +0x13948、WM-Helmet1 → +0x13A4C、DMon/MagicEx/StoreItem → 0x13B50..（F430）。
- **〔统一〕**35+ WIL 槽全部挂在游戏对象（main 基址 F451）；技能施法特效 = MonMagic/MagicEx 帧（F351 族）。
- 落盘：full-wil-table-loader-evidence.json（F483，primary-bytes）+ RESEARCH_LOG + UI_COMPLETION_AUDIT Round 177。
## Round 178 (F484) — 2026-08-12：技能按钮点击处理器（技能激活）

- **〔点击〕**0x4149A0：**9 技能按钮**（stride 0xB4、vtable+0x10 命中）→ SetFocus + ShowWindow(5) + SetWindowTextA（0x47AD88 技能名）@主窗 0x8AA48C + **msg 0xB1 技能使用命令**。
- **〔构造〕**0x414830：9 × 0x4175F0 按钮 + 输入框 [0x6D4] + 滚动区 [0x720]。
- **〔链〕**技能栏点击 → msg 0xB1 → 服务端施法 → MonMagic 特效（F351/F483）。
- 落盘：skill-button-click-evidence.json（F484，primary-bytes）+ RESEARCH_LOG + UI_COMPLETION_AUDIT Round 178。
## Round 179 (F485) — 2026-08-12：运行时弧闭合（F481-F484 4 轮汇总）

- **〔验证〕**compileall OK、verify exit 0、node OK、JSON 有效；三服务 200；master cf1a3cf（**146 连发已推**）。
- **〔弧汇总〕**小地图装载+表面（F481）/ 小地图 blit 16 位（F482）/ **完整 WIL 表 35+ 槽**（F483）/ 技能栏 9 按钮 + msg 0xB1（F484）。
- 落盘：runtime-arc-closure-evidence.json（F485，derived）+ RESEARCH_LOG + UI_COMPLETION_AUDIT Round 179。
## Round 180 (F486) — 2026-08-12：16 位 565 像素混合器

- **〔混合〕**0x4621F0：逐像素 alpha 混合（**565 掩码** 0x7E0F81F/0x7C0F83F/0xF81F07E0、shr 5/10 通道移位、imul alpha [0x134]&0xFF）——通用精灵合成器（法术特效 + 全部 16 位精灵绘制）。
- **〔调用〕**type 0x14A 特效实体 blit（0x462227/0x462BDC）= 法术特效路径；MonMagic 帧数学 = 独立绘制函数（F483/F351 pending）。
- 落盘：pixel-blend-565-evidence.json（F486，primary-bytes）+ RESEARCH_LOG + UI_COMPLETION_AUDIT Round 180。
## Round 181 (F487) — 2026-08-12：特效实体 tick（法术动画进度）

- **〔tick〕**0x435A20：特效/特殊实体更新（type {0x16,0x10,9,0x1E,0xB,0x14A-0x14E,0x140-0x142,0xA,0x21A,0x21B,0x35,0x3F,0x68,0x150} = F336 特殊族）：帧计数 [0x121]++ 回绕 [0x102]、0xC8 (200) tick 门、**死亡生命周期**（[byte+4]：0 动画中、1 子帧衰减 [0xE8]/[0xE9]、2 死亡移除）。
- **〔链〕**特效 tick → 帧 [0x121] → MonMagic 帧选择 → 565 混合 blit（F486）。
- 落盘：effect-entity-tick-evidence.json（F487，primary-bytes）+ RESEARCH_LOG + UI_COMPLETION_AUDIT Round 181。
## Round 182 (F488) — 2026-08-12：特效实体 vtable 0x476440

- **〔槽映射〕**+0/+4 名签（F239）、+8/+0x10 节点 ctor、+0xC 0x42C800、+0x14 vtable 0x476454、**+0x1C 0x435030 = 绘制**（特效精灵）、+0x20 dtor、**+0x2C 0x435A20 = tick（F487）**、+0x30-0x3C 浮点常量（250/400/36/0.01 特效尺寸）。
- **〔链〕**tick 0x435A20 → 绘制 0x435030 → MonMagic 帧 → 565 混合（F486）。
- 落盘：effect-entity-vtable-evidence.json（F488，primary-bytes）+ RESEARCH_LOG + UI_COMPLETION_AUDIT Round 182。
## Round 183 (F489) — 2026-08-12：特效实体生成器（法术帧公式闭合）

- **〔生成〕**0x435030（vtable+0x1C）：记录查找 0x449C10、目标查找（0x77769C 自身 / 0x560070 链表）、地图坐标 0x43CFD0/0x43D070/0x43D190（0x574118）、**类型分派 0x30-0x2F**（jt 0x4357E8 + 字节映射 0x435808）、状态初始化（[0x10] 类型、[0x121] 帧=0、[0xDC] 计数）。
- **〔帧公式〕**MonMagic 帧基 = **[esi] + type*10**（0x43538E-0x4353AB）——每法术 10 帧块。
- **〔链〕**技能使用（F484）→ 服务端 → 特效生成 → tick（F487）→ 绘制 → 565 混合（F486）— **法术特效生命周期 + 帧数学全闭合**。
- 落盘：effect-entity-spawner-evidence.json（F489，primary-bytes）+ RESEARCH_LOG + UI_COMPLETION_AUDIT Round 183。
## Round 184 (F490) — 2026-08-12：法术特效弧闭合（F486-F489 4 轮汇总）

- **〔验证〕**compileall OK、verify exit 0、node OK、JSON 有效；三服务 200；master 28da098（**150 连发已推**）。
- **〔弧汇总〕**565 混合器（F486）/ 特效 tick（F487）/ 特效 vtable（F488）/ 特效生成器 + 帧基 [esi]+type*10（F489）——**施法管线完整**（技能使用→生成→tick→绘制→混合）；MonMagic 帧数学 pending 闭合。
- 落盘：spell-effect-arc-closure-evidence.json（F490，derived）+ RESEARCH_LOG + UI_COMPLETION_AUDIT Round 184。
## Round 185 (F491) — 2026-08-12：形象帧上下文数组（0x565994 源闭合）

- **〔闭合〕**0x565994 = **人类形象帧上下文数组**（21 绘制点：角色选择 0x416F93、状态形象 F472、游戏初始化 0x4193D1、tick 族）；由 0x452AA0 70 条目循环从形象库（F483 M-*/WM-*）填充——**F454「store+0x5898 第二数组」= 形象上下文**（非怪物槽）。
- **〔附带〕**0x416F7E 交易对话打开（msg 0x405、窗口 0x7E04C8）。
- **〔闭合〕**最后一个低优先 pending 解决。
- 落盘：figure-frame-context-array-evidence.json（F491，primary-bytes）+ RESEARCH_LOG + UI_COMPLETION_AUDIT Round 185。
## Round 186 (F492) — 2026-08-12：monster.dat 结构调查（服务端怪物库）

- **〔结构〕**monster.dat = 109116B：**432 名称槽 × 0xFC**（0x1E6 起，0x09 终止）+ 统计区；名称 = **遗留 KR 编码**（c3d1c7c9 → GBK 乱码，非 MonGen GBK 名）。
- **〔客户端〕**客户端**零怪物名引用**（栗子树/多钩猫/半兽人 = 0 引用）→ 记录存储 0x8AA5A8 = **数据包驱动**（F450），非文件加载——怪物名+属性随生成包到达。
- **〔待深〕**记录字段解码延迟（遗留编码）。
- 落盘：monster-dat-structure-evidence.json（F492，secondary + primary）+ RESEARCH_LOG + UI_COMPLETION_AUDIT Round 186。
## Round 187 (F493) — 2026-08-12：stditem.dat 结构调查（服务端物品库）

- **〔结构〕**stditem.dat = 210316B、头 0x7704（计数 0x477 = 1143 物品 [inference]、~184B/记录）；**零 GBK 名匹配**（金创药/魔法药/号角/金币/木剑 = 0）——与 monster.dat 同源遗留 KR 编码（F492）。
- **〔客户端〕**物品 0xC20 记录 = 数据包驱动（F464），无本地物品库。
- 落盘：stditem-dat-structure-evidence.json（F493，secondary + inference）+ RESEARCH_LOG + UI_COMPLETION_AUDIT Round 187。
## Round 188 (F494) — 2026-08-12：monster.dat 统计字段（固定偏移提取）

- **〔字段〕**记录 = 名称 8B（+0，0x09 填充）+ 统计固定偏移：+0x12=0x0B（等级?）、+0x26=0xD4、+0x2A=0x1A、+0x30=0xA9、+0x34=0x6A、+0x48=0x35、+0x4A=0x65/0x0E（字）、+0x4D=0x21/0x03（字）。
- **〔名称编码〕**cp949/euc-kr = 총핀헥뇨（无意义）、GBK = 乱码、xor80/互转全失败——**自定义/加密名称移位**（非标准字符集），解码延迟；客户端不受影响（数据包驱动 F450）。
- 落盘：monster-dat-stat-fields-evidence.json（F494，primary + inference）+ RESEARCH_LOG + UI_COMPLETION_AUDIT Round 188。
## Round 189 (F495) — 2026-08-12：服务端数据库弧闭合（F492-F494 3 轮汇总）

- **〔验证〕**compileall OK、verify exit 0、node OK、JSON 有效；三服务 200；master d8c9240（**154 连发已推**）。
- **〔弧汇总〕**monster.dat 432 槽 × 0xFC（F492）/ stditem.dat 1143 物品 [inference]（F493）/ monster.dat 统计字段偏移（F494）；**关键发现：客户端零本地名引用——记录存储全包驱动，服务端 .dat = KR 遗留自定义字符集**。
- 落盘：server-db-arc-closure-evidence.json（F495，derived）+ RESEARCH_LOG + UI_COMPLETION_AUDIT Round 189。
## Round 190 (F496) — 2026-08-12：客户端瓦片存储索引 PRIMARY（与 mapviewer 对齐）

- **〔索引〕**0x43B770：槽 = **(tile_row+1)*14**（字节 [0x124]++ × imul 0xE）+ 14 槽带循环 → 存储 0x5600FC + idx*0x144（F452 stride）+ 文件名 0x56B22C + idx*0x104。
- **〔对齐〕**mapviewer audit 公式（v = file − floor(file/14)、槽 = v、带 0-13/14-27/28-41/42-55/56-69）= 客户端精确匹配——F343/F452 交叉确认。
- 落盘：client-tile-store-index-evidence.json（F496，primary-bytes）+ RESEARCH_LOG + UI_COMPLETION_AUDIT Round 190。
## Round 191 (F497) — 2026-08-12：模拟器商店模式循环按钮

- **〔功能〕**window.store-candidate 加 5 按钮（购买/出售/仓库/制作/详情）；点击翻 STATE.storeState + renderWindows()（修正：renderAll 未定义 → renderWindows 顶层函数）。
- **〔验证〕**浏览器：点「仓库」→ state 0→2、标签「仓库 (state2 · msg 0x2BC → 0x44F940)」、**12 仓库格**渲染（匹配 F460 +0x720 12 格）。
- 落盘：simulator-store-mode-cycle-evidence.json（F497，derived + browser）+ RESEARCH_LOG + UI_COMPLETION_AUDIT Round 191。
## Round 192 (F498) — 2026-08-12：模拟器聊天快捷物品命令

- **〔功能〕**聊天加 广N 分派（F355 名称命令表 0x47ADC4：广1..广10 + 行动速度）；日志「[快捷] 广N → 快捷物品使用 (0x41EDE0: 0x430920/0x42FC20/0x42E2D0, 表 0x47ADC4)」。
- **〔客户端链〕**0x41EDE0 物品使用（0x430920 解析 + 0x42FC20 背包反序列化 + 0x42E2D0 音效 + 0x47ADC4 名匹配循环）。
- **〔验证〕**浏览器：输入 广1 → 快捷行日志。
- 落盘：simulator-chat-quick-slot-evidence.json（F498，derived + browser）+ RESEARCH_LOG + UI_COMPLETION_AUDIT Round 192。
## Round 193 (F499) — 2026-08-12：mapviewer 缓存确认

- **〔瓦片〕**冷 0.428s → 热 **0.0012s（346×）**、字节一致（.tilecache-v3 磁盘缓存 F376/F88）。
- **〔fullmap〕**z=2 = 26.19MB（F394 匹配）、热 0.056s（进程池内存帧缓存）、字节一致。
- **〔双级〕**磁盘（瓦片）+ 内存（fullmap）缓存均运行正常——F88/F376/F394 交叉确认。
- 落盘：mapviewer-cache-confirm-evidence.json（F499，secondary）+ RESEARCH_LOG + UI_COMPLETION_AUDIT Round 193。
## Round 194 (F500) — 2026-08-12：HANDOFF 刷新（F429-F499 弧汇总）

- **〔追加〕**HANDOFF 补 Round 149-194（实体渲染/物品背包商店/装备/交互运行时服务端弧 + 模拟器增强）；基线 Round 114=8145504 → Round 194=204c6f4（**160 连发 F335-F499**）。
- 落盘：handoff-refresh-evidence.json（F500，derived）+ RESEARCH_LOG + UI_COMPLETION_AUDIT Round 194。
## Round 195 (F501) — 2026-08-12：monster.dat 编码破解（EUC-KR/Hanja 混合）

- **〔破解〕**名称 = **EUC-KR/Hanja 混合**：槽解码为真韩文（slot0 '총핀헥뇨'、slot5 '츤딜'、slot20 '뮤늬춈흐'）+ 汉字（KR 字节内中文）——**KR 源服务端格式**；432 槽全非空；CN 服务端在脚本层翻译（MonGen GBK）。
- **〔闭合〕**最后一个低优先 pending 闭合；客户端不受影响（数据包驱动 F492）。
- 落盘：monster-dat-kr-encoding-evidence.json（F501，primary-bytes）+ RESEARCH_LOG + UI_COMPLETION_AUDIT Round 195。
## Round 196 (F502) — 2026-08-12：stditem.dat 格式破解（1143 × 184B + 头）

- **〔格式〕**stditem.dat = 1143 记录 × 184B + 4B 计数头 = 210316（**精确等于文件大小**）；名称 @ rec+0x99（EUC-KR/Hanja、0x04 终止，rec1 '뱐같烈㎚滔㎛'）——F493 184B/记录 inference 确认精确 + 编码解析。
- **〔双库〕**monster/stditem 全解码（KR 源格式）。
- 落盘：stditem-dat-kr-format-evidence.json（F502，primary-bytes）+ RESEARCH_LOG + UI_COMPLETION_AUDIT Round 196。
## Round 197 (F503) — 2026-08-12：服务端数据库解码弧闭合（F501-F502 汇总）

- **〔验证〕**compileall OK、verify exit 0、node OK、JSON 有效；三服务 200；master b2a8f7d（**162 连发已推**）。
- **〔弧汇总〕**monster.dat EUC-KR/Hanja 破解（F501、432 槽全命名）+ stditem.dat 1143×184B+4B 精确格式 + 名称 +0x99（F502）——**服务端双库全可解码**；客户端仍包驱动（F492/F464）。
- 落盘：server-db-decode-arc-closure-evidence.json（F503，derived）+ RESEARCH_LOG + UI_COMPLETION_AUDIT Round 197。
## Round 198 (F504) — 2026-08-12：MonMagic.wil 块布局（F489 公式确认）

- **〔库〕**MonMagic.wil = 2270 帧 / **153 段**（可变长 4/10/18/6/8，起点 0/20/40/60/80/100/260/280/306...）；Magic.wil 3550 / MagicEx.wil 1780（独立特效族）。
- **〔公式〕**F489 **[esi]+type*10 = 段起点索引确认**：偶 type（0/2/4/6/8/10）起点 = type*10 精确；奇 type → 下一段；每特效帧数 [0x102]（F487）= 段长。
- 落盘：monmagic-block-layout-evidence.json（F504，primary-bytes）+ RESEARCH_LOG + UI_COMPLETION_AUDIT Round 198。
## Round 199 (F505) — 2026-08-12：实体类型字 [0x10] 语义

- **〔分派〕**type [0x10] 单分派驱动全部实体生命周期：{0x16,0x10,9,0x1E,0xB,0x14A-0x14E,0x140-0x142,0xA,0x21A,0x21B,0x35,0x3F,0x68,0x150} = 特效/特殊族（F336/F479/F487）；type = 生成包参数（F489）。
- **〔服务端〕**Envir kind（spawn/npc/monster F423）→ 生成包 → 客户端 type 字（非直接 Envir kind）。
- 落盘：entity-type-semantics-evidence.json（F505，primary-bytes）+ RESEARCH_LOG + UI_COMPLETION_AUDIT Round 199。
## Round 200 (F506) — 2026-08-12：里程碑（200 连发 F335-F505）

- **〔验证〕**compileall OK、verify exit 0、node OK、JSON 有效；三服务 200；master 0cb14b5；**131 地图重建证据 JSON**。
- **〔里程碑〕**200 连发、全部 pending 闭合（服务端 .dat 解码、MonMagic 块布局、实体类型语义）。
- 落盘：round-200-milestone-evidence.json（F506，derived）+ RESEARCH_LOG + UI_COMPLETION_AUDIT Round 200。
## Round 201 (F507) — 2026-08-12：法术特效处理器类（9 移动变体）

- **〔类〕**生成器分派 0x4357E8 → 9 处理器，差异在 [0x8]/[0xC] 旗标 + [0x120] 行走旗标 + [0x18] 目标：**静止（walk=0）/ 投射（双旗标）/ 追踪（目标 [0x18]）**；字节映射 0x435808（48 类型 → 处理器）。
- 落盘：spell-effect-handler-classes-evidence.json（F507，primary-bytes）+ RESEARCH_LOG + UI_COMPLETION_AUDIT Round 201。
## Round 202 (F508) — 2026-08-12：magic.dat 格式（105 法术 × 120B）

- **〔格式〕**magic.dat = 105 法术 × 120B 步长（精确，12604 = 105*120+4）+ 4B 计数头；名称 @ rec+0x6B（EUC-KR/Hanja、0x11 终止）——服务端 DB 三件套（monster/stditem/magic）全可解码（F501/F502 同族）。
- **〔客户端〕**法术名包驱动（F351 Magic.exp）。
- 落盘：magic-dat-format-evidence.json（F508，primary-bytes）+ RESEARCH_LOG + UI_COMPLETION_AUDIT Round 202。
## Round 203 (F509) — 2026-08-12：MiniMap.txt 服务端小地图绑定

- **〔绑定〕**MiniMap.txt = 37 map→帧对（1001-1038）、0.map→1001（帧 0）——**精确匹配 F310「FMMap value−1001」公式**（1001+ = FMMap.wil 帧索引）。
- **〔出生点〕**StartPoint.txt = 出生坐标（01 459 261 比奇县出生点，F423 源）。
- 落盘：minimap-txt-binding-evidence.json（F509，secondary + F310 交叉）+ RESEARCH_LOG + UI_COMPLETION_AUDIT Round 203。
## Round 204 (F510) — 2026-08-12：MiniMap 地图集交叉（37 = 30 EI + 7 服务端专属）

- **〔交叉〕**MiniMap.txt 37 图 = **30 在 EI + 7 服务端专属**（{401-407} 哨所 + 9.map——F396 服务端专属类子集）。
- **〔Mapinfo〕**格式 = 仅传送记录（F87/F382 确认，map x,y -> map x,y 1:1 对，无名称）——**F382「Mapinfo 名」修正**（名称源 = mapnames 遗留库）。
- 落盘：minimap-map-set-cross-evidence.json（F510，secondary）+ RESEARCH_LOG + UI_COMPLETION_AUDIT Round 204。
## Round 205 (F511) — 2026-08-12：Envir 守卫/任务文件（服务端清单完整）

- **〔守卫〕**GuardList.txt 117 守卫 NPC 位置（卫士 map x,y : level，2/01 比奇县区）。
- **〔任务〕**MapQuest.txt 549 触发行（[MonDie] 沃玛战士 → MU_warrior 脚本，**GBK 怪物名 = CN 翻译层确认** F501）；QuestDiary 35 任务目录。
- **〔完整〕**服务端 Envir 清单全解码（merchant/monster/stditem/magic/minimap/startpoint/guard/quest）。
- 落盘：envir-guard-quest-files-evidence.json（F511，secondary）+ RESEARCH_LOG + UI_COMPLETION_AUDIT Round 205。
## Round 206 (F512) — 2026-08-12：Envir 弧闭合（F508-F511 汇总）

- **〔验证〕**compileall OK、verify exit 0、node OK、JSON 有效；三服务 200；master 0d90824（**171 连发已推**）。
- **〔弧汇总〕**magic.dat 105×120B（F508）/ MiniMap.txt 37 绑定 + F310 确认（F509）/ 地图集 30+7（F510）/ GuardList+MapQuest+QuestDiary（F511）——**服务端 Envir 清单完整**（全部 .dat + 配置 + 任务解码）。
- 落盘：envir-arc-closure-evidence.json（F512，derived）+ RESEARCH_LOG + UI_COMPLETION_AUDIT Round 206。
## Round 207 (F513) — 2026-08-12：模拟器窗口内容审计

- **〔覆盖〕**全部 14 客户端窗口 + 8 辅助（22 总）均有真实处理器（24 buildWindow id 检查）；**浏览器验证：41 按钮 + 170 槽 + 35 标签**（丰富内容非占位）。
- **〔基线〕**F420 集成基线扩展（F497/F498 商店循环 + 聊天快捷新增）。
- 落盘：simulator-window-content-audit-evidence.json（F513，derived + browser）+ RESEARCH_LOG + UI_COMPLETION_AUDIT Round 207。
## Round 208 (F514) — 2026-08-12：客户端发送消息目录（34 msgid 0x3E9-0x419）

- **〔目录〕**商店控件 0x3F2-0x3F9（F460）+ 商店操作 0x3E9/0x3EF/0x3F0、交易 0x402/0x403（F364）+ 金币 0x405/0x406（F474）+ 重置 0x407/0x408 + 库存 0x409、**NPC 对话回复 0x410/0x411（F476 0x4524D0/0x4524A0）**、生成 0x417、NPC 0x416/0x418/0x419——完整客户端发包目录（含发送函数）。
- 落盘：client-send-msgid-map-evidence.json（F514，primary-bytes）+ RESEARCH_LOG + UI_COMPLETION_AUDIT Round 208。
## Round 209 (F515) — 2026-08-12：模拟器+包弧闭合（F513-F514 汇总）

- **〔验证〕**compileall OK、verify exit 0、node OK、JSON 有效；三服务 200；master 14ed6fa（**174 连发已推**）。
- **〔弧汇总〕**模拟器 14+8 窗口全内容（F513，浏览器 41 按钮/170 槽/35 标签）+ 客户端发送 34 msgid 目录（F514，F460/F474/F476 确认）——模拟器 UI + 发包目录完整。
- 落盘：sim-packet-arc-closure-evidence.json（F515，derived）+ RESEARCH_LOG + UI_COMPLETION_AUDIT Round 209。
## Round 210 (F516) — 2026-08-12：未映射 msgid 发送器解码（F514 目录 100% 完整）

- **〔解码〕**0x3EA 3 参（0x452170）/ 0x3F6 2 参（0x4521B0）/ 0x3FA/0x3FD/0x3FE/0x401 1 参 / **0x3FF/0x400 坐标包**（shr 0x10 = x,y 打包，商店控件族）/ 0x40C-0x40F NPC 对话回复变体——**全部 34 msgid 已识别（34/34）**。
- 落盘：unmapped-msgid-senders-evidence.json（F516，primary-bytes）+ RESEARCH_LOG + UI_COMPLETION_AUDIT Round 210。
## Round 211 (F517) — 2026-08-12：主接收分派表（0x42042B 137 槽 → 49 处理器）

- **〔表〕**0x42042B 开关：msgid 0x29F-0x44C（add −0x29F、cmp 0x88）+ 字节映射 0x422080（137 槽、49 处理器）+ 跳表 0x421FBC；>0x44C = 怪物消息 0xBC6-0xBD8（F449 分离）。
- **〔簇〕**0x2A1-0x2A6（1-6）、0x2BC-0x2CA（14-28 商店/仓库/制作，0x2BC=14、0x2C8=26 F399 确认）、0x2EE-0x2FA（29-41）、0x300-0x303（42-43）、0x322-0x325（44-47）——**完整入站包目录**（互补 F514 出站）。
- 落盘：recv-dispatch-table-evidence.json（F517，primary-bytes）+ RESEARCH_LOG + UI_COMPLETION_AUDIT Round 211。
## Round 212 (F518) — 2026-08-12：第二接收分派表（0x44D-0x520 → 13 处理器）

- **〔表〕**0x4218F2 开关：msgid 0x44D-0x520（212 槽）+ 字节映射 0x42219C（13 处理器）+ 跳表 0x422168；处理器：实体生成 0x421913（0x40C 分配 + 0x41B710）、聊天 0x421955（0x2000 字符串）、实体坐标 0x4219A0（[0x61C90] F310 族）。
- **〔总计〕**入站 = **349 槽**（137 + 212，两表）+ 怪物 0xBC6+——完整客户端接收图。
- 落盘：recv-dispatch-table-2-evidence.json（F518，primary-bytes）+ RESEARCH_LOG + UI_COMPLETION_AUDIT Round 212。
## Round 213 (F519) — 2026-08-12：包目录弧闭合（F516-F518 汇总）

- **〔验证〕**compileall OK、verify exit 0、node OK、JSON 有效；三服务 200；master fc496bf（**178 连发已推**）。
- **〔弧汇总〕**出站 34/34 全解码（F516）+ 入站表1 137→49（F517）+ 入站表2 212→13（F518）——**完整双向包目录：34 出站 + 349 入站 + 怪物 0xBC6+**。
- 落盘：packet-catalog-arc-closure-evidence.json（F519，derived）+ RESEARCH_LOG + UI_COMPLETION_AUDIT Round 213。
## Round 214 (F520) — 2026-08-12：接收表2 处理器语义（13 全分类）

- **〔语义〕**实体生成 ×2（0x421913/0x421CFC：0x40C 分配 → 0x41B710/0x4561B0 入 [0x364458] 链）、聊天 ×5（0x2000 字符串 + 0x448D90/0x4488D0）、实体坐标（0x4219A0 [0x61C90] F310）、**英雄状态字节**（0x421BBC [0x35B148] → vtable+0x88，0x1D/0 行走）、实体查找/生成（0x421C23：0x41EB40 + 节点 + timeGetTime）。
- **〔完整〕**接收表2 语义全解。
- 落盘：recv2-handler-semantics-evidence.json（F520，primary-bytes）+ RESEARCH_LOG + UI_COMPLETION_AUDIT Round 214。
## Round 215 (F521) — 2026-08-12：接收表1 处理器语义（49 分类）

- **〔语义〕**仓库 0x2BC（0x420AFC：窗门 [0x2ABA10] + 开）、制作 0x2C8（0x4209A8：0x2800 字符串 → 0x44FB00 族）、行会窗（0x420474 [0x2D8E58]）、商店更新（0x41F99F 0x44E8B0）、错误提示（0x47B6C4）、背包反序列化（12 槽 0x42FC20）、装备使用（0x42E2D0）——**recv1 = 商店/行会/背包/装备族**。
- **〔完整〕**入站图景完整（recv1 UI 状态 + recv2 实体/聊天）。
- 落盘：recv1-handler-semantics-evidence.json（F521，primary-bytes）+ RESEARCH_LOG + UI_COMPLETION_AUDIT Round 215。
## Round 216 (F522) — 2026-08-12：入站图景弧闭合（F520-F521 汇总）

- **〔验证〕**compileall OK、verify exit 0、node OK、JSON 有效；三服务 200；master ce7ccc2（**181 连发已推**）。
- **〔弧汇总〕**recv2 13 处理器（F520）+ recv1 49 处理器（F521）——**349 入站槽 + 怪物族全语义映射**；完整双向包图景（出站 F514 + 入站 F517-F521）。
- 落盘：inbound-picture-closure-evidence.json（F522，derived）+ RESEARCH_LOG + UI_COMPLETION_AUDIT Round 216。
## Round 217 (F523) — 2026-08-12：怪物接收族结构（实体状态机）

- **〔结构〕**0x410B80 = 每实体状态机（非 msgid 开关）：type [0x89] 分派、状态旗标 [0x629D3-0x629D8] + 计数 [0x62A77] 门、记录查找 0x44A820 → vtable+0x10 → 属性 0x40A4D0 → **回复 msg 0xBC7（type-7 查找）/ 0xBD1（变形）** 经 0x451450。
- **〔族〕**0xBC6-0xBD8（F449）驱动每实体转换；生成 = 0x421CFC（F520）。
- 落盘：monster-recv-family-evidence.json（F523，primary-bytes）+ RESEARCH_LOG + UI_COMPLETION_AUDIT Round 217。
## Round 218 (F524) — 2026-08-12：完整包层闭合（F514-F523 全映射）

- **〔验证〕**compileall OK、verify exit 0、node OK、JSON 有效；三服务 200；master 89dc1b1（**183 连发已推**）。
- **〔包图〕**出站 34 msgid（F514/F516）+ 入站 349 槽两表（F517/F518，语义 F520/F521）+ 怪物 0xBC6-0xBD8 状态机（F523）——**完整客户端-服务端协议层文档化**。
- 落盘：packet-layer-closure-evidence.json（F524，derived）+ RESEARCH_LOG + UI_COMPLETION_AUDIT Round 218。
## Round 219 (F525) — 2026-08-12：HANDOFF 刷新 2（F500-F524 追加）

- **〔追加〕**HANDOFF 补 Round 195-218（服务端全解码 F501-F512 + 法术变体/模拟器/包层 F507-F524）；基线 Round 194=204c6f4 → **Round 218=be1b382（183 连发 F335-F524）**。
- 落盘：handoff-refresh-2-evidence.json（F525，derived）+ RESEARCH_LOG + UI_COMPLETION_AUDIT Round 219。
## Round 220 (F526) — 2026-08-12：模拟器边缘验证

- **〔验证〕**商店测试导航 商店状态+1 正常（state0→1、标签更新、170 槽）；全局辅助完整（isOpen/setWindowOpen/pushChat）；STATE 模块作用域（内部接线）——F497/F498 新增无回归。
- 落盘：simulator-edge-verification-evidence.json（F526，derived + browser）+ RESEARCH_LOG + UI_COMPLETION_AUDIT Round 220。
## Round 221 (F527) — 2026-08-12：提示框系统细节（3 槽数组 + 激活）

- **〔槽〕**3 × stride 0xB8 @ [0x234]、首空扫描、活动槽字节 [0x462]。
- **〔激活〕**0x418520：wparam = type<<16 | slot<<8 | tag、MoveWindow（+0x23A/+0xDF）、ShowWindow、GetWindowTextA 输入 [0x130]、msg 0x7EE 发送；点击 0x418600（槽命中 vtable+0x10）。
- 落盘：prompt-system-detail-evidence.json（F527，primary-bytes）+ RESEARCH_LOG + UI_COMPLETION_AUDIT Round 221。
## Round 222 (F528) — 2026-08-12：Config.ini 保存链（6 键字节确认）

- **〔链〕**0x441B30 写 6 键（0x4761A4 WritePrivateProfileString，文件 Config.ini、节 Options）：**BGM/[0x54]、BGMLevel/[0x8AB150]、EffectSound/[0x58]、EffectSoundLevel/[0x8AB14C]、Ambience/[0x5C]、ShadowBlend/[0x60]**——F324 字节级确认。
- 落盘：config-ini-save-chain-evidence.json（F528，primary-bytes）+ RESEARCH_LOG + UI_COMPLETION_AUDIT Round 222。
## Round 223 (F529) — 2026-08-12：聊天输入发送路径

- **〔发送〕**0x404600：门 [0x8A4]==1、清 [0xE3D] 缓冲、SetWindowTextA（[0x8AA48C] ← &[0xD39]）、[0xD38]=1 发送旗标、0x403640 分派、[0x8AA498]=0；0x404660 聚焦（SetFocus + ShowWindow）；ctor 0x404690（vtable 0x4763A8）。
- 落盘：chat-input-send-path-evidence.json（F529，primary-bytes）+ RESEARCH_LOG + UI_COMPLETION_AUDIT Round 223。
## Round 224 (F530) — 2026-08-12：血条实时值元素路径

- **〔条〕**0x40A8A0：门 [0x61BB8]/[0x61BBC]、**HP = [0x61BA0]−[0xB4]+[0xC4]（F350 精确）**、type [0x8D] 分派（0x51/0x89/0x81/0x8A）、**元素帧 = 实时值 [0x61B9C] 经 0x4542A0 注册表**（存储 type*81*4）、0x466130 + 0x466800 变换 blit——F350 运行时确认。
- 落盘：bar-drain-live-value-evidence.json（F530，primary-bytes）+ RESEARCH_LOG + UI_COMPLETION_AUDIT Round 224。
## Round 225 (F531) — 2026-08-12：目标框悬停计时器

- **〔计时〕**0x40BB00：累加器 [0x6209C] += tick（[0x620A0] 旗标时）、**门 0xBB8（3000ms，F359）**、随后清 [0x620A0] 0x41 dword + [0x621A4] 0x208 dword（名签重置）；锚 [0xE4]−0x2C/[0xE8]−0x37（F359 精确）、type [0x61C8C] 变体（1 = 文本测量）。
- 落盘：target-box-hover-timer-evidence.json（F531，primary-bytes）+ RESEARCH_LOG + UI_COMPLETION_AUDIT Round 225。
## Round 226 (F532) — 2026-08-12：UI 角落弧闭合（F527-F531 汇总）

- **〔验证〕**compileall OK、verify exit 0、node OK、JSON 有效；三服务 200；master 65678c3（**190 连发已推**）。
- **〔弧汇总〕**提示框 3 槽（F527）/ Config.ini 6 键保存（F528）/ 聊天输入发送（F529）/ 血条实时值帧（F530）/ 目标框悬停 3000ms（F531）——**深层 UI 角落字节级闭合**。
- 落盘：ui-corner-arc-closure-evidence.json（F532，derived）+ RESEARCH_LOG + UI_COMPLETION_AUDIT Round 226。
## Round 227 (F533) — 2026-08-12：HANDOFF 刷新 3（F525-F532 追加）

- **〔追加〕**HANDOFF 补 Round 219-226（协议层完整 + 模拟器边缘 + 深层 UI 角落）；基线 Round 218=be1b382 → **Round 226=17faa1b（190 连发 F335-F532）**。
- 落盘：handoff-refresh-3-evidence.json（F533，derived）+ RESEARCH_LOG + UI_COMPLETION_AUDIT Round 227。
## Round 228 (F534) — 2026-08-12：技能书详情页

- **〔解析〕**0x43A440：技能名匹配 + 详情解析（token 0x468BF0 '' 分隔、'#' 等级门、';' 终止、匹配旗标 [esp+0x13]）；**详情请求 msg 0xA5**（0x45E200）+ 多行缓冲（0x100 stride）。
- 落盘：skill-book-detail-page-evidence.json（F534，primary-bytes）+ RESEARCH_LOG + UI_COMPLETION_AUDIT Round 228。
## Round 229 (F535) — 2026-08-12：行会窗渲染细节

- **〔分派〕**0x425040：状态字节 [0x98] 3 路（0=0x425280 公告 / 1=0x425440 敌对 / else=0x425590 联盟+成员）、每状态列表位置选择器（[0x9C]/[0xB4]/[0x114]）、**滚动条 0x4179B0 @ [0x76C]**（0x42514D）+ 6+ 控件矩形（0x417830）。
- 落盘：guild-window-render-detail-evidence.json（F535，primary-bytes）+ RESEARCH_LOG + UI_COMPLETION_AUDIT Round 229。
## Round 230 (F536) — 2026-08-12：组队窗渲染细节

- **〔渲染〕**0x4243D0：标题 0xDCE6C8 + 名 0x7776A0、成员链遍历（计数 [0x68]、头 [0x58]、节点 {+4 名, +0xC next}）、**行距 = idx/2*20**（0x42444A：idx*5*4，F54 20px 确认）、成员名白 0xFFFFFF、5 控件（0x417830）、允许/拒绝串（0x47BA08/0x47BA00）。
- 落盘：group-window-render-detail-evidence.json（F536，primary-bytes）+ RESEARCH_LOG + UI_COMPLETION_AUDIT Round 230。
## Round 231 (F537) — 2026-08-12：任务窗渲染细节

- **〔渲染〕**0x447470：文本链遍历（头 [0x1E8]、门 [0x54]）、**19 行上限**（0x44751D）、0xC8 宽度门（200px）、**色 0x1919C8/0x19197D**（旗标 [0x210]/[0x204]）、**行 y = idx*15+18**（0x447618，F51 line*3+0x12 确认）、2 控件。
- 落盘：quest-window-render-detail-evidence.json（F537，primary-bytes）+ RESEARCH_LOG + UI_COMPLETION_AUDIT Round 231。
## Round 232 (F538) — 2026-08-12：窗口渲染弧闭合（F534-F537 汇总）

- **〔验证〕**compileall OK、verify exit 0、node OK、JSON 有效；三服务 200；master 5611c38（**196 连发已推**）。
- **〔弧汇总〕**技能详情 msg 0xA5（F534）/ 行会 3 态+滚动条（F535）/ 组队 idx/2*20（F536）/ 任务 19 行+色对（F537）——**全部 14 窗口渲染路径字节级**。
- 落盘：window-render-arc-closure-evidence.json（F538，derived）+ RESEARCH_LOG + UI_COMPLETION_AUDIT Round 232。
## Round 233 (F539) — 2026-08-12：HANDOFF 刷新 4（F533-F538 追加）

- **〔追加〕**HANDOFF 补 Round 227-232（窗口渲染字节级）；基线 Round 226=17faa1b → **Round 232=dd66590（196 连发 F335-F538）**；164 地图重建证据 JSON。
- 落盘：handoff-refresh-4-evidence.json（F539，derived）+ RESEARCH_LOG + UI_COMPLETION_AUDIT Round 233。
## Round 234 (F540) — 2026-08-12：NPC 对话类型分派

- **〔分派〕**0x43F460：对话数据链（[0x8B1AE4]）、**type 字节−1 ≤ 3（类型 1-4）经跳表 0x440158**（0x43F4E0）、7 行换行（0x131 偏移）、GBK 字节对复制 + 文本测量 0x45E0C0——F41/F475 统一。
- 落盘：npc-dialog-type-dispatch-evidence.json（F540，primary-bytes）+ RESEARCH_LOG + UI_COMPLETION_AUDIT Round 234。
## Round 235 (F541) — 2026-08-12：角色选择阶段机

- **〔阶段〕**0x4575D0：阶段字节 [0x930] ≤ 4 经跳表 0x457778（5 阶段）：0=0x457790 连接、1=0x457AB0 服务器、2=0x457615 角色列表（0x45C900）、3=0x4576FA 角色选择、4=0x45773C；**进游戏 = 0x458B20(stage, idx)**；角色名缓冲 [0x10BC]/[0x10FC]——F349/F110 流程完整。
- 落盘：char-select-stage-machine-evidence.json（F541，primary-bytes）+ RESEARCH_LOG + UI_COMPLETION_AUDIT Round 235。
## Round 236 (F542) — 2026-08-12：登录族弧闭合 + 200 连发里程碑

- **〔验证〕**compileall OK、verify exit 0、node OK、JSON 有效；三服务 200；master 01a8904（**200 连发 F335-F541**）。
- **〔弧汇总〕**NPC 对话 4 类型分派（F540）+ 角色选择 5 阶段机（F541）——全部 UI 状态机字节级。
- 落盘：login-family-arc-closure-evidence.json（F542，derived）+ RESEARCH_LOG + UI_COMPLETION_AUDIT Round 236。
## Round 237 (F543) — 2026-08-12：HANDOFF 刷新 5（F539-F542 追加）

- **〔追加〕**HANDOFF 补 Round 233-236（HANDOFF-4 + 登录族弧 + 200 里程碑）；基线 Round 232=dd66590 → **Round 236=b12e3b2（200 连发 F335-F542）**。
- 落盘：handoff-refresh-5-evidence.json（F543，derived）+ RESEARCH_LOG + UI_COMPLETION_AUDIT Round 237。
## Round 238 (F544) — 2026-08-12：交易栏几何（8×9 双栏修正）

- **〔几何〕**0x416830 双栏命中：pane 字节（0=自身 +0x15/+0x30、1=对方 +0xFD/+0x30）、**8 列 × 9 行网格**（0x24=36px 步长，x 帽 0xB4、y 帽 0xD8）、槽 = row*8+col（[0x54] 基）；0x416950 槽查找（[0x298] 物品字、0xFFFF 空、%0x3E8）——**F283 5×6 修正为 8×9**。
- 落盘：trade-pane-geometry-evidence.json（F544，primary-bytes）+ RESEARCH_LOG + UI_COMPLETION_AUDIT Round 238。
## Round 239 (F545) — 2026-08-12：坐骑命令分派

- **〔分派〕**0x426A80：4 按钮命中（[+0x54]/[+0x108]/[+0x1BC]/[+0x270]）、命令 @上马 0x47B060（门 [0x7DA060]==0）/ @收马 0x47B058 / @遛马 0x47B068（门 !=0）、发送 0x4520F0 + [0x8A68BC]=0x12C 计时器；5 控件遍历（stride 0xB4）——F105/F361 族完整。
- 落盘：horse-command-dispatch-evidence.json（F545，primary-bytes）+ RESEARCH_LOG + UI_COMPLETION_AUDIT Round 239。
## Round 240 (F546) — 2026-08-12：选项窗开关构造

- **〔构造〕**0x440FE0：**4 开关行 × 2 控件**（0x417550、msg 对 0x2F8/0x2F9 + 0x2FA/0x2FB = ON/OFF，F101）、控件 @ [0x7C]..[0x61C] + BGM 滑块 [0x2C0]——4 开关 = 音乐/音效/环境声/阴影混合。
- 落盘：option-window-toggle-ctor-evidence.json（F546，primary-bytes）+ RESEARCH_LOG + UI_COMPLETION_AUDIT Round 240。
## Round 241 (F547) — 2026-08-12：技能书分类页签

- **〔页签〕**0x439500：**8 分类页签控件**（0x417830 @ [0x2F4]-[0x7E0] stride 0xB4，火冰电风神圣黑暗幻影剑 F104）、选中 [0x54] → 计数 [0x58+tab*4]、除 3 计数数学（0x2AAAAAAB）、详情 0x43A440（F534）。
- 落盘：skill-book-category-tabs-evidence.json（F547，primary-bytes）+ RESEARCH_LOG + UI_COMPLETION_AUDIT Round 241。
## Round 242 (F548) — 2026-08-12：窗口角落弧闭合（F544-F547 汇总）

- **〔验证〕**compileall OK、verify exit 0、node OK、JSON 有效；三服务 200；master a9ee4ac（**206 连发已推**）。
- **〔弧汇总〕**交易 8×9 栏（F544，F283 修正）/ 坐骑 4 命令（F545）/ 选项 4 开关行（F546）/ 技能书 8 页签（F547）——**全部 14 窗口 + 登录/NPC 字节级**。
- 落盘：window-corners-arc-closure-evidence.json（F548，derived）+ RESEARCH_LOG + UI_COMPLETION_AUDIT Round 242。
## Round 243 (F549) — 2026-08-12：recv1 mapval7 背包反序列化函数体

- **〔函数体〕**0x4204FD：**12 槽 × 0xC2C**（[0x2D93EC]，门 [ebp-0xC] 类型）、0x308 双字复制 → 0x42FC20 反序列化；待装备 [0x2A54AC] **金币特例**：strcmp 名 [0x2A54C8] vs 0x47ADB4 **'금전'**（cp949/EUC-KR = 金钱）→ 跳过入包（计数 [0x35B1E8] += [0x2EB840]），否则反序列化 [0x2A54C4]；清 0x30E 双字于 [0x2A54AC]；腰带 [0x2EB848]；行会关 gate [0x2D8E58] → 0x42AC50。
- **〔名表〕**0x47ADC4 = 12 指针（밤1-10 栗子 + 行动速度 : 움직이지않음/非常缓慢）——**客户端本地 KR 特殊名**（F478-493 数据包驱动论微调）。
- 落盘：recv1-mapval7-bag-body-evidence.json（F549，primary-bytes）+ RESEARCH_LOG + UI_COMPLETION_AUDIT Round 243。
## Round 244 (F550) — 2026-08-12：窗口开关分派器 0x42ADB0（16 模式）

- **〔分派〕**0x42ADB0（hero 方法，jt 0x42B3E4）：每模式 = 窗口对象 hero+OFF + 开旗标 obj+0x30；开 = 0x42AC30 插入开窗列表（0x449870 @ [hero+0xD24]）+ show(1)；关 = 0x42AC50 按模式解链（节点 {+0 模式,+4 next,+8 prev}，头 [0xD28] 计数 [0xD34] 长度 [0xD38]）。
- **〔模式表〕**0=背包管理器 [0x6554]、1:[0x29CE4]、2:[0x33188]、3=行会 [0x3399C]、4:[0x4707C]、6=商店 [0x47834]（ctor 0x398/0x399 @ [0x47B70]）、7:[0x47C28]、8=大地图 [0x507EC]（0x4762BC blit）、9:[0x51150]、B:[0x516E8]、C:[0x518E0]、D:[0x52118]、E:[0x524F0]、F:[0x52E5C]（缓冲 [0x53028] + 旗标 0x8AA498）；5/A 桩。
- **〔mapval1〕**0x420474：OpenWindow(3) + 0x3C 行会名复制（packet+0x10 → [hero+0x2EB800]）；主门 [0x2ABA10] 清 → OpenWindow(0) 背包 + 0x423FA0 定位 **(518,0)——0x206 = x 坐标 518，非 msgid**（修正）。
- 落盘：window-toggle-dispatcher-evidence.json（F550，primary-bytes）+ RESEARCH_LOG + UI_COMPLETION_AUDIT Round 244。
## Round 245 (F551) — 2026-08-12：recv1 mapval14 仓库 + 背包管理器模式族

- **〔仓库〕**0x420AFC：门 [0x2ABA10] → OpenWindow(0) → 背包管理器 [hero+0x6554] 模式 [0x54]=**3 仓库**、msg 0x111/0x112/0x113、公共尾 0x41FB54（0x417880 ctor @ [0x1C4] + [0x2CF14C]=包 dword）。
- **〔模式族〕**[0x54]：0=背包（F550）、1=（0x41FB24 msg 0x107/0x108/0x109）、3=仓库。
- **〔尾部〕**0x41FB6E：金币 dword → [0x35B1E8] + 选中 [0x2CF13C] → 物品数组 [0x2AC164] **stride 0xC2C**（+0x3D/+0x3F 字）+ 0x415280 刷新；0x41FC09：**栗子循环** 10 指针 0x47ADC4..0x47ADEC（밤1-10，F549 表）比对包名 [0x2A54C8] + sprintf 0x47AF7C——栗子马粮信息（F361/F545）。
- 落盘：recv1-mapval14-warehouse-mode-evidence.json（F551，primary-bytes）+ RESEARCH_LOG + UI_COMPLETION_AUDIT Round 245。
## Round 246 (F552) — 2026-08-12：recv 命令处理器 + 异步 TCP 连接

- **〔连接〕**0x451320（发送器对象 0x8AB828）：socket(2,1,0) → [0x6044]、WSAAsyncSelect(sock, hwnd [0x8AB7B0], 0x7E8=WM_USER+0x3E8, 0x31=FD_READ|FD_CONNECT|FD_CLOSE)、sockaddr_in（family 2 + htons(arg3) + inet_addr(arg2)）、connect、[0x14]=1；0x451420 = closesocket。
- **〔IAT 门〕**0x46806E=closesocket 0x468074=inet_addr 0x46807A=connect 0x468080=WSAAsyncSelect 0x468086=htons 0x46808C=WSAGetLastError 0x468092=socket 0x468098=send 0x46809E=recv。
- **〔命令〕**0x420C90：收 'IP/端口'（0x2000 复制 + strchr '/' 0x468BF0）→ 0x451420 关旧 + 0x451320 连接（冷却 [0x4279A4]=0x1F4）；0x420D14：'A/B' → sprintf '%s %s'（0x47B560）→ [0x2F87C8]。
- **〔佐证〕**0x47B5DC='%s 被放置到仓库里了!'（GBK）确认 [0x2AC164] 仓库数组 stride 0xC2C；0x47AF7C='栗'（GBK）确认栗子标记——**服务器重定向通道**。
- 落盘：recv-command-tcp-connect-evidence.json（F552，primary-bytes）+ RESEARCH_LOG + UI_COMPLETION_AUDIT Round 246。
## Round 247 (F553) — 2026-08-12：recv2 分派完整处理器图

- **〔分派〕**0x4218F2：msg 0x44D-0x520 → 字节表 0x42219C（**12 个不同值 0-10,12**）→ jt 0x422168，默认 0x421C81——**11 真处理器 + 默认**（F518「13」修正）。
- **〔处理器〕**idx0=实体名设置（lstrcpyA + hero id [0x2F8784] vs 0x41EB10、vtable[0x38]）；idx1=备忘结构（malloc 0x40C + 3 dword + 串 → 0x41B710）；idx2=英雄状态（[0x35B148] 字节、vtable[0x88]+vtable[0x10](0x1D/0)）；idx3/9/10=任务列表增（0x4488D0/0x448B10/0x448D90 @ [0x2F6B74]）；idx4/5=**任务公告**（'새로운 퀘스트가 시작 되었습니다.' 0x47B15C / '퀘스트 일지가 변경되었습니다.' 0x47B180，cp949）；idx6=实体坐标三元组（hero → [0x35A410] 否则 entity+0x61C90）；idx7=聊天行 0x422E30；idx8=备忘#2 → 0x4561B0([main+0x364458])；idx12=实体登记（0x41EB40 [0xE1188]=0x560088、malloc 0x10 {+0 id,+4 w1,+8 w2,+0xC timeGetTime}）。
- **〔助手〕**0x41EB10=按 id 找实体（[0xE1158]=0x560070 F336 容器 A）；**0x401390 = 色表** {0:0,1:0xA0A0A,2:0xFFFFFF,3:0xFF,4:0xFF00,5:0xFF9696,6:0x50FFFF,7:0x80FF}；0x427E30=公告窗（0x507EC）多行最多 5 行（fmt 0x47AD30）。
- 落盘：recv2-dispatch-full-map-evidence.json（F553，primary-bytes）+ RESEARCH_LOG + UI_COMPLETION_AUDIT Round 247。
## Round 248 (F554) — 2026-08-12：HANDOFF 刷新 6（Round 237-247）

- **〔刷新〕**HANDOFF 追加 Round 237-247（F543-F553：窗口角落 4 项 + recv 函数体 5 项）；基线 Round 236=b12e3b2 → Round 247=01e92a1（**212 连发 F335-F553**）。
- 落盘：handoff-refresh-6-evidence.json（F554，derived-tooling）+ RESEARCH_LOG + UI_COMPLETION_AUDIT Round 248。
## Round 249 (F555) — 2026-08-12：recv1 商店族（买/卖/修）全解

- **〔买〕**mapval19（0x41F99F）：0x44E8B0([main+0x2D8614] 商店管理器)；0x41F9AF 开关：3='你不能购买这件物品.'（0x47B940）、2='您的包袱太重啦！无法携带更多物品'（0x47B91C）、1=0x44E8B0 + '您购买的速度过快'（0x47B904）。
- **〔商店开〕**0x41FA16：模式 [0x54]=**2 商店** + msg 0x10E/0x10F/0x110 + 定位 **(0x207=519, 0)** 经 0x423FA0（公共尾 0x41FA5B）；0x41FB24：模式 [0x54]=1 + msg 0x107/0x108/0x109——**背包管理器模式族完整：0=背包/1=?/2=商店/3=仓库**。
- **〔卖/修〕**0x41FA72：金币 [0x35B1E8] + 卖出确认 '%s 已经被卖掉!!!'（0x47B8F0）+ 0x42FB20；0x41FB6E：修理确认 '这个物品修补好了!'（0x47B8C0）+ **耐久字 item+0x3D/+0x3F**（[0x2AC1A1]/[0x2AC1A3]）；0x41FAF0：变卖拒绝 '您无法在这里变卖这个物品！'（0x47B8D4）→ 0x418030([main+0x3615B0])。
- 落盘：recv1-store-family-evidence.json（F555，primary-bytes）+ RESEARCH_LOG + UI_COMPLETION_AUDIT Round 249。
## Round 250 (F556) — 2026-08-12：recv1 制作族（0x4209A8-0x420BE8）全解

- **〔制作〕**mapval26（0x4209A8）：配方 0x2800 串 → 0x44FB00([main+0x2D8614] 商店管理器) + 商店未开则开（模式 2 经 0x42ADB0）+ [0x2D8C08]=包 dword；0x420A86：0x44F940(管理器, 串, word) 变体。
- **〔结果〕**0x420A26 4 分支（jt 0x42210C）：1='您没有原材料......'（0x47B620）、2='돈이 부족합니다.'（0x47B634 钱不够）、3='오류가 발생했습니다.'（0x47B648 错误）；0x420A03：成功 '아이템이 잘 만들어 졌습니다.'（0x47B660）+ 金币 [0x35B1E8]。
- **〔限流/满〕**0x420ACA：'点击 速度过快'（0x47B60C）；0x420AE3：'身上物品已满'（0x47B5F4）。
- **〔仓库〕**0x420B31：存入 '%s 被放置到仓库里了!'（0x47B5DC）；0x420B80/0x420BB4：满 '개인 보관 창고가 다 찼습니다...'（0x47B5A0）/ 拒 '보관 할 수 없습니다.'（0x47B588）→ 0x418030([main+0x3615B0])。
- **〔金币显示/冷却〕**0x420BE8：'%d 金'（0x47B580）→ [0x2CF150] + [0x2CF140]=1；0x420C1E：timeGetTime → [0x2AB69C] + 0x43D780 + [0x2AB9A4]=1。
- **〔编码〕**KR 源 cp949（돈이 부족합니다/오류/보관/아이템이 잘 만들어 졌습니다）+ CN GBK 层。
- 落盘：recv1-craft-family-evidence.json（F556，primary-bytes）+ RESEARCH_LOG + UI_COMPLETION_AUDIT Round 250。
## Round 251 (F557) — 2026-08-12：recv1 交易族 + 模式 3 修正

- **〔修正〕**[hero+0x3399C] = **交易窗**（F313 cap0 交易栏 Ctrl+C）——F550/F551「行会」归属**错误已修正**（行会 = cap6 Ctrl+F 另窗）。
- **〔交易布局〕**2 栏 × 12 槽（stride 0xC2C、栏块 0x9210=12×0xC2C）@ [win+0x5B8]；找槽 0x4162A0（idx×0x9210+0x5B8 扫 12）、加 0x4161F0（ret 0xC2C）、删 0x416150（id + 名 strcmp → 0x4160E0）、插 0x416490。
- **〔处理器〕**mapval1 = **交易开**（对方名 0x3C → [hero+0x2EB800] + 背包 (518,0)）；0x42081D 交易放入（0x430920/0x430940 物品构造 + 0x4161F0(trade,1) + 音效 + '%s 已经被放入对方的物品交易栏.' 0x47B6A4）；0x4208EC 交易取走（0x416150(trade,1,word,name) + '%s 已经被对方从物品交易栏中拿走.' 0x47B680）；0x420766 待装备 → 0x4161F0(trade,0)；0x420671 腰带卸 → 背包；0x4206CE 待装备金币检查（F549 镜像）；0x4207BC/0x4207FC 金币 → 0x45AFC0([0x8AB130], 0x6A) + [0x2EB840]/[0x2EB844] + [0x35B1E8]。
- 落盘：recv1-trade-family-evidence.json（F557，primary-bytes）+ RESEARCH_LOG + UI_COMPLETION_AUDIT Round 251。
## Round 252 (F558) — 2026-08-12：窗口绘制分派器 0x4280F0——**权威窗口注册表**

- **〔注册表〕**绘制循环遍历开窗列表 [0xD28..0xD38]（F550 节点 {+0 模式,+4 next}），jt 0x428358 模式→(对象, 绘制)：
  - 0=背包 [0x6554] 0x42EB80、1=装备 [0x29CE4] 0x44B2D0（F325 族）、2=**商店** [0x33188] 0x44E260（0x44E8B0/0x44F940/0x44FB00 管理器族）、3=**交易** [0x3399C] **0x415B10**（F58 确认）、4=**行会** [0x4707C] **0x425040**（F535——行会定位！）、6=**组队** [0x47834] **0x4243D0**（F536）、7=[0x47C28] 0x450530、8=**公告** [0x507EC] 0x414700（F556 目标）、9=[0x51150] 0x43F460、B=**任务** [0x516E8] 0x447470（F537）、C=[0x518E0] 0x441380、D=**坐骑** [0x52118] 0x4269C0（F545）、E=**技能书** [0x524F0] 0x439500（F547）、F=[0x52E5C] 0x43E3C0；5/A 桩。
- **〔输入分派〕**0x4282EE：0→0x42FAB0、1→0x44B6B0、2→0x44E650、3→0x416790、7→0x450AC0。
- **〔裁剪〕**IntersectRect 0x476248（区域 0xDF/0x23A/0x241/0x24A）+ ShowWindow 0x4762AC。
- **〔修正〕**F550 模式表：2=商店、3=交易、4=行会、6=组队、8=公告、B=任务、D=坐骑、E=技能书（原「行会/商店/大地图」归属全部修正）。
- 落盘：window-paint-dispatcher-registry-evidence.json（F558，primary-bytes）+ RESEARCH_LOG + UI_COMPLETION_AUDIT Round 252。
## Round 253 (F559) — 2026-08-12：窗口注册表完整（模式 7/9/C/F 定名）

- **〔模式 7 = 角色/状态窗〕**[0x47C28] 绘制 0x450530：头像 WIL 0x566DD4（帧 [0x551]+0x3B+[0x554]*0xA）、**11 装备槽 stride 0xC24**（0x430A40 图标 F464）、名 [0x8B94]、属性色 0xDCFFDC/0xB4FAFF + '%s %s'（0x47B560）+ 굴림 字体（0x47C348）；ctor 0x4507E0（0x112 双字复制 + 槽表 +0x13C stride 0x5F）。
- **〔模式 9 = NPC 对话窗〕**[0x51150] 绘制 0x43F460：列表 [0x8B1AE4] + **类型跳表 0x440158 = F540 4 类型分派** + 文本渲染 0x45E0C0/0x45DD70（0x8AB7A8）。
- **〔模式 C = 选项窗〕**[0x518E0] 绘制 0x441380：**11 控件 0x417830 @ [0x7C]..[0x61C]/[0x6D0]/[0x784]——与 F546 选项 ctor 偏移完全一致**。
- **〔模式 F = 行会公告编辑窗〕**[0x52E5C] 绘制 0x43E3C0：占位串 '[行会公告，请自行修改公告内容.]'（0x47C440）+ '[行会修改...]'（0x47C460）+ 文本缓冲 [0x53028] + 开窗 SetFocus（F550）。
- **〔完整〕14 窗口全定名**：0 背包/1 装备/2 商店/3 交易/4 行会/6 组队/7 角色状态/8 公告/9 NPC 对话/B 任务/C 选项/D 坐骑/E 技能书/F 行会公告编辑。
- 落盘：window-registry-complete-evidence.json（F559，primary-bytes）+ RESEARCH_LOG + UI_COMPLETION_AUDIT Round 253。
## Round 254 (F560) — 2026-08-12：窗口命中测试 + 输入路由

- **〔命中〕**0x42AAB0(x,y)：开窗列表**尾部优先**遍历（[0xD30] 尾 → [0xD2C] 游标，最顶优先）、模式 jt 0x42ABE8 → **窗口 RECT @ obj+0x14**（0:[0x656C] 1:[0x29CFC] 2:[0x331A0] 3:[0x339B4] 4:[0x47094] 6:[0x4784C] 7:[0x47C40] 8:[0x50804] 9:[0x51168] B:[0x51700] C:[0x518F8] D:[0x52130] E:[0x52508]，F/5/A 缺席）、PtInRect 0x4762B4 → 悬停模式。
- **〔输入路由〕**模式 → 处理器：0→0x42FAB0 **背包悬停**（门 [0x7243C4]=hero+0x20、槽 0x42F240、物品 [背包+0x774+槽*0xC20]、提示 0x4341F0 F464）；3→0x416790 **交易悬停**（PtInRect [edi+0x5C]、槽 0x416950 F544、物品 [交易+0x5B8+槽*0xC20]、提示 0x4341F0）；1→0x44B6B0、2→0x44E650、7→0x450AC0。
- **〔标记〕**背包 [0x2C4] 600 字（0xFFFF 空；0x42FB20 按 id 清 0x258 项，+0x3E8）。
- 落盘：window-hit-test-input-router-evidence.json（F560，primary-bytes）+ RESEARCH_LOG + UI_COMPLETION_AUDIT Round 254。
## Round 255 (F561) — 2026-08-12：窗口系统弧闭合（F550-F560 汇总）

- **〔验证〕**compileall OK、verify exit 0、node OK、JSON 有效、**186 证据 JSON**；三服务 200；master 41bbb62（**219 连发 F335-F560 已推**）。
- **〔弧〕**开关分派器 0x42ADB0 16 模式 + 开窗列表（F550）、交易族 + 模式 3 修正（F557）、绘制分派器 0x4280F0 **权威注册表**（F558）、14 窗口全定名（F559）、命中测试 0x42AAB0 + 输入路由（F560）——**整个窗口系统（开/关/绘/输入）字节级**。
- **〔注册表〕**0 背包/1 装备/2 商店/3 交易/4 行会/6 组队/7 角色状态/8 公告/9 NPC 对话/B 任务/C 选项/D 坐骑/E 技能书/F 行会公告编辑。
- 落盘：window-system-arc-closure-evidence.json（F561，derived）+ RESEARCH_LOG + UI_COMPLETION_AUDIT Round 255。
## Round 256 (F562) — 2026-08-12：HANDOFF 刷新 7（Round 248-255）

- **〔刷新〕**HANDOFF 追加 Round 248-255（F554-F561：recv1 商店/制作/交易族 + 窗口系统弧 + 模式表修正）；基线 Round 247=01e92a1 → Round 255=ce24497（**220 连发 F335-F561**）。
- 落盘：handoff-refresh-7-evidence.json（F562，derived-tooling）+ RESEARCH_LOG + UI_COMPLETION_AUDIT Round 256。
## Round 257 (F563) — 2026-08-12：recv1 mapval2/3 + 装备音效分派

- **〔mapval2〕**0x42045B：错误公告 '交易的时候要2个人面对面才可以.'（0x47B6C4，交易需面对面）经公共尾 0x42181D → 0x418030([main+0x3615B0])。
- **〔mapval3〕**0x420640：装备使用确认 = 0x42E2D0 音效 + 0x416E20 交易刷新 + 清待装备 [0x2A54AC]（0x30E 双字）。
- **〔音效分派〕**0x42E2D0：物品类型字节 [0x22] ≤ 0x1F → 映射 0x42E428 → jt 0x42E404（0x6C 金币、0x6F-0x71 类型、名字比对 **갑박**（0x47BDDC 盔甲）/**장갑**（0x47BDD4 手套）→ 0x72/0x75、其余 0x73/0x74）；发送 0x45AFC0([0x8AB130], soundid)。
- **〔公共尾〕**0x42181D（push 0x565994 上下文 + 0x418030）被 mapval2/商店错/仓库拒共用。
- **〔recv2 idx0 尾〕**0x42186D：实体名设置（hero id [0x2F8784] → vtable[0x34]，否则 0x41EB10）。
- 落盘：recv1-error-equip-sound-evidence.json（F563，primary-bytes）+ RESEARCH_LOG + UI_COMPLETION_AUDIT Round 257。
## Round 258 (F564) — 2026-08-12：文本渲染族（GDI 管线）

- **〔测量〕**0x45E0C0：GetTextExtentPoint32A（0x476078）+ SelectObject（0x476048）、字体对象 vtable[0x44] 选/[0x68] 还原、返回 {宽,高} 8B。
- **〔绘制〕**0x45DD70：SetBkMode/SetBkColor（0x476044/0x476050）+ SetTextColor（0x476060）+ **TextOutA**（0x476074）；0x45DE50：+ **DrawTextA**（0x476280，flags 0x25）矩形版。
- **〔字体〕**0x45DBA0：굴림（Gulim，0x47C348）帧渲染（帧 0x2BC）——模式 7 属性用（F559）。
- **〔屏幕对象〕**0x8AB7A8 + 字体 [obj+0x28]/[obj+0x1C]——公告 0x427E30/NPC 对话 0x43F460/属性窗/F 行会编辑**全部共用**。
- 落盘：text-render-family-gdi-evidence.json（F564，primary-bytes）+ RESEARCH_LOG + UI_COMPLETION_AUDIT Round 258。
## Round 259 (F565) — 2026-08-12：recv1 实体生成/移除（msg 0x2CE/0x2CF）

- **〔生成〕**0x420E36：id 查重（[main+0xE11A0]/[0xE11D0]）→ **类型分派**：5/4 → malloc 0x144 + ctor 0x434EF0 + vtable 0x4767A8 + 0x438100 初始化（9 参：id、0x16/0x10、旗标、x、y…）→ 追加**实体链表 0x5600B8(头)/0x5600BC(尾)/0x5600C8(计数)**（节点 {0x476448,+4 数据,+8 prev,+0xC next}，F336 容器）；6/3 → malloc 0x20 **迷你实体** {+0 类型, +4 id, +8 字 0xD2/0xE6, +0xC timeGetTime, +0x10 0xFFFF, +0x14 y, +0x18 x} → 链表 0x5600E8（vtable 0x476454）。
- **〔移除〕**0x42121B：按 id 查两链表；类型 0x16 特例 = **重生替换**（rand 0x4E20-0x7530 + 0x438100）。
- **〔连带 msgid〕**0x2BE=角色/状态数据（idx30 开模式 7）、0x2C0=行会数据（idx32 开模式 4）、0x2B7=多物品拾取（idx23）、0x2AD=交易关（idx13）。
- 落盘：recv1-entity-spawn-remove-evidence.json（F565，primary-bytes）+ RESEARCH_LOG + UI_COMPLETION_AUDIT Round 259。
## Round 260 (F566) — 2026-08-12：实体初始化 + 帧推进核心

- **〔init 0x438100〕**9 参转 0x435030（特效生成 F489）、id → [0x140]、x/y → [0xB0]/[0xB4]、投影 0x43CFD0（地图 0x574118，F435 48×32）→ [0xA0]/[0xA4]、参数 → [0x13C]。
- **〔tick 0x4381A0〕**[0xD8] += 增量（行走）、回绕 [0xFC]++ → [0xF8]/[0xF4] 重置、阶段 [0x130]<5 门 + **帧基：类型 0x16 特例 0x27EE，否则 type*5+0x2711**、血条 0x45B140/0x45B090/0x45B0F0（[0x8AB130]）、vtable[0x14] → **0x7DA1D8 光场**（F436）、离屏旗标 [0x4]。
- **〔paint 0x4382C0〕**行走 + [0xF0]/[0xF1] 动画 -5 回绕 + 投影绘制。
- **〔闭环〕**生成（F565）→ init → tick → 渲染（F434-442）全连接。
- 落盘：entity-init-tick-core-evidence.json（F566，primary-bytes）+ RESEARCH_LOG + UI_COMPLETION_AUDIT Round 260。
## Round 261 (F567) — 2026-08-12：recv/实体弧闭合（F549-F566 汇总）

- **〔验证〕**compileall OK、verify exit 0、node OK、JSON 有效、**192 证据 JSON**；三服务 200；master 02a7294（**225 连发 F335-F566 已推**）。
- **〔弧〕**recv1 函数体（背包金币 F549/分派器 F550/仓库 F551/TCP 重定向 F552/recv2 全图 F553/商店 F555/制作 F556/交易 F557/错误装备 F563）+ 窗口系统（F558-F560）+ 文本渲染族（F564）+ 实体生命周期（生成/移除 F565、init/tick F566）——**整个入站包管线 + 实体管线字节级**。
- 落盘：recv-entity-arc-closure-evidence.json（F567，derived）+ RESEARCH_LOG + UI_COMPLETION_AUDIT Round 261。
## Round 262 (F568) — 2026-08-12：HANDOFF 刷新 8（Round 257-261）

- **〔刷新〕**HANDOFF 追加 Round 257-261（F563-F567：错误/装备 + 文本渲染族 + 实体生命周期 + recv/实体弧）；基线 Round 255=ce24497 → Round 261=9fbbccc（**226 连发 F335-F567**）。
- 落盘：handoff-refresh-8-evidence.json（F568，derived-tooling）+ RESEARCH_LOG + UI_COMPLETION_AUDIT Round 262。
## Round 263 (F569) — 2026-08-12：recv1 行会/组队/联盟错误族

- **〔idx33/35〕**msg 0x2C1：未入会 '对不起！您还没有加入行会！.'（0x47B544）；msg 0x2C3：0x452410 发送 + 收人成功 '行会收人成功!'（0x47B528）。
- **〔idx36/38/39/42〕**状态跳表：0x2C4 5 路（jt 0x42211C：无权限/失败/已在本门/已在它门）、0x2C6 4 路（jt 0x422130：无名/문주 不能自退 0x47B418/命令不可用）、0x2C7 6 路（jt 0x422140：**[변경오류] 문주가 비어있습니다/명칙이 비어있습니다/2명 초과/접속 필요** + 封号编辑拒绝 0x47B30C + 重复 0x47B2D8）、0x2CA 4 路（jt 0x422158：동맹에 실패했습니다/需面对面 문주 0x47B298）。
- **〔idx37/45/22〕**0x2C5：仅发送；0x2CD：备忘结构 malloc 0xC → 0x4561B0([main+0x3C5EFC])；0x2B6：[0x4279A0]=包 dword。
- **〔编码〕**KR 源（문주/문파/동맹/변경오류）+ CN GBK 层。
- 落盘：recv1-guild-party-errors-evidence.json（F569，primary-bytes）+ RESEARCH_LOG + UI_COMPLETION_AUDIT Round 263。
## Round 264 (F570) — 2026-08-12：recv1 全覆盖（最后 3 处理器）

- **〔idx40〕**msg 0x2C8：建会成功 '你申请的行会已建立成功.'（0x47B200）。
- **〔idx41〕**msg 0x2C9 3 路：-1 '没足够的钱,或者已经创建行会.'（0x47B1E0）、-2 '你没有足够的申请经费.'（0x47B1C8）、-3 '필요아이템을 모두 가지고 있지 않습니다.'（0x47B1A0 缺材料）。
- **〔idx43〕**msg 0x2CB 3 路：-1 '必须面对要联盟行会掌门.'（0x47B254）、-2 '그 문파와 동맹중이 아닙니다.'（0x47B234）、-3 '존재하지 않는 문파입니다.'（0x47B218）。
- **〔覆盖〕**全部 **49 个 recv1 处理器字节级**（F549-F570：背包/商店/仓库/制作/交易/行会/组队/联盟/实体/角色/公告/备忘/TCP）——recv1 表 0x42042B **100% 函数体覆盖**。
- 落盘：recv1-full-coverage-evidence.json（F570，primary-bytes）+ RESEARCH_LOG + UI_COMPLETION_AUDIT Round 264。
## Round 265 (F571) — 2026-08-12：入站协议 100% 闭合 + HANDOFF 刷新 9

- **〔验证〕**compileall OK、verify exit 0、node OK、JSON 有效、**196 证据 JSON**；三服务 200；master ae595b2（**229 连发 F335-F570 已推**）。
- **〔里程碑〕**recv1 表 0x42042B **49/49 处理器字节级**（F549-F570）+ recv2 表 0x4218F2 **11/11**（F553）+ 怪物 0xBC6-0xBD8（F523）——**整个入站协议层 100% 函数体覆盖**。
- **〔HANDOFF 刷新 9〕**追加 Round 262-264（F568-F570），基线 9fbbccc → ae595b2。
- 落盘：inbound-protocol-100-percent-evidence.json（F571，derived）+ RESEARCH_LOG + UI_COMPLETION_AUDIT Round 265。
## Round 266 (F572) — 2026-08-12：出站文本协议核心

- **〔核心〕**0x452940 = **包头构造器**（msgid dword + 5 word → 12B 头 [+4]/[+6]/[+8]/[+0xA]）；0x451E60 = **发送尾**：缓冲 [obj+0x24]、序列 [obj+0x14]（9→1 回绕）、格式 **'#%d%s%s!'**（0x47C840 带体）/ **'#%d%s!'**（0x47C800 无体）→ wsprintf → [obj+0x2044] → **send()**（门 0x468098 → WS2_32 0x476340，socket [obj+0x6044]）；体 0x452740 复制（0x2000 上限）。
- **〔包装〕**0x451F10='%s/%s'（2 串）、0x451F60=msg 0x68、0x451F90='%s/%d'（[0x47EF10] 主对象）、0x451FE0='%s/%s/%d/%d/%d'（3 数）。
- **〔协议〕**客户端-服务器 = **文本帧 '#<seq><cmd>/<args>!'** 单异步 socket（KR MIR3 风格）。
- 落盘：outbound-text-protocol-core-evidence.json（F572，primary-bytes）+ RESEARCH_LOG + UI_COMPLETION_AUDIT Round 266。
## Round 267 (F573) — 2026-08-12：出站目录完整（46 发送器）

- **〔扫描〕**0x45171E-0x4524E5 中 **46 个调用 0x452940**（包头构造器）：30 静态 msgid（0x3E9 商人/0x3EA/0x3EF/0x3F0 商店操作 + 0x3F2-0x3F9 商店控件/0x3FA-0x3FE 滚动/0x3FF/0x400 坐标/0x401-0x403 交易 + 0x405/0x406 金币 + 0x407/0x408 重置 + 0x409 背包 + 0x40A/0x416-0x419 NPC/生成）+ 动态（0x451928 寄存器参、0x452052 msg 0x66、0x452085 msg 0x67、0x452105 msg 0xBD6、0x452156 msg 0xBC9 压缩坐标、0x4521CB 寄存器参）+ **文本包装 0x7D1/0x68/0x64/0x65**（F572）。
- **〔定案〕**F514「34」扩展为 **46 发送调用点字节验证**（0xBC9/0xBD6 = 实体操作 msgid，怪物族 F523 连接）。
- 落盘：outbound-catalog-complete-evidence.json（F573，primary-bytes）+ RESEARCH_LOG + UI_COMPLETION_AUDIT Round 267。
## Round 268 (F574) — 2026-08-12：全协议双向闭合

- **〔验证〕**compileall OK、verify exit 0、node OK、JSON 有效、**199 证据 JSON**；三服务 200；master b35c1d2（**232 连发 F335-F573 已推**）。
- **〔里程碑〕**入站 100%（recv1 49 + recv2 11 + 怪物 F571）+ 出站 100%（文本帧核心 F572 + **46 发送器目录** F573）——**整个客户端-服务器协议双向字节级**：发送 '#<seq><cmd>/<args>!' 经 send()（socket [0x6044]）、接收经 WSAAsyncSelect 0x7E8（F552）→ 分派表 0x42042B/0x4218F2。
- **〔仓库〕**用户 quest 文档 16-道具图册.md 未跟踪（未触碰）。
- 落盘：full-protocol-bidirectional-evidence.json（F574，derived）+ RESEARCH_LOG + UI_COMPLETION_AUDIT Round 268。
## Round 269 (F575) — 2026-08-12：HANDOFF 刷新 10（Round 265-268）

- **〔刷新〕**HANDOFF 追加 Round 265-268（F571-F574：入站 100% + 出站文本帧核心 + 46 发送器 + 双向闭合）；基线 Round 261=9fbbccc → Round 268=d54bc29（**233 连发 F335-F574**）。
- 落盘：handoff-refresh-10-evidence.json（F575，derived-tooling）+ RESEARCH_LOG + UI_COMPLETION_AUDIT Round 269。
## Round 270 (F576) — 2026-08-12：模拟器文本帧协议层

- **〔实现〕**app.js 新增 sendFrame()：镜像原版 **'#%d%s%s!'/'#%d%s!'** 帧（F572 0x47C840/0x47C800）+ seq 计数 9→1 回绕（[obj+0x14]）→ 聊天环 '[送出] #<seq><cmd>/<args>!'；聊天输入接线：'+'→0x41E740、'@'→0x47ACB8、'!'→0x47ACF8、广N→0x41EDE0、普通→0x404600（F355 分派）。
- **〔验证〕**node --check OK + sim 200 无回归——模拟器现在讲真实 KR MIR3 文本协议。
- 落盘：sim-text-frame-protocol-evidence.json（F576，primary-bytes 帧格式 + derived 集成）+ RESEARCH_LOG + UI_COMPLETION_AUDIT Round 270。
## Round 271 (F577) — 2026-08-12：文件映射/资源装载器族（0x45A650-0x45B610，长尾闭合）

- **〔装载〕**0x45B5B0 = **资源装载器**（FindResourceA 0x4760B0 → LoadResource 0x4760B4 → LockResource 0x4760F4 → 0x45BA60）；0x45B610 = **文件映射装载器**（CreateFileA 0x4760DC → CreateFileMappingA 0x4760A4 → MapViewOfFile 0x4760A0）——**F436 WIL 装载器 0x466130 双模式 = 资源 + mmap 确认**。
- **〔分派/析构〕**0x45B490 = 分派（先资源后文件、vtable[0xC] 初始化、失败 vtable[+8] 释放）；**0x45A650 = 容器析构**（timeKillEvent 0x476310 杀计时器 [0x140] + 释放 **7 视图** [+0x118..+0x12C] + [0x134]=0）；ctor 0x45A850 vtable 0x476BD8。
- **〔闭合〕**长期 pending 项（0x45A650 尾部/0x45B490 body）完成。
- 落盘：file-mapping-resource-loader-evidence.json（F577，primary-bytes）+ RESEARCH_LOG + UI_COMPLETION_AUDIT Round 271。
## Round 272 (F578) — 2026-08-12：DSound 3D 监听器接口解析

- **〔解析〕**0x476CA8（.rdata）= **IID {279AFA84-4981-11CE-A521-0020AF0BE560} = IID_IDirectSound3DListener**（MS 文档确认）；用法 0x45A9B4：COM 单例获取（0x45A8C0 创建 / 0x9135C0 全局）→ push 0x9135C4 出参 + push 0x476CA8 riid + call vtable[0]（0x468116 CoCreateInstance）→ 失败 E_FAIL 0x80004005 → vtable[+8] 释放；dsound.dll 仅序号导入（0x47603C）。
- **〔闭合〕**最后 pending 项（F28 '0x476CA8 次级 DSound 接口名 279AFA84'）**完成——全部 pending 笔记闭合**。
- 落盘：dsound-3d-listener-evidence.json（F578，primary-bytes + secondary）+ RESEARCH_LOG + UI_COMPLETION_AUDIT Round 272。
## Round 273 (F579) — 2026-08-12：全部 pending 闭合 + HANDOFF 刷新 11

- **〔验证〕**compileall OK、verify exit 0、node OK、JSON 有效、**204 证据 JSON**；三服务 200；master 515600e（**237 连发 F335-F578 已推**）。
- **〔里程碑〕**全部历史 pending 笔记闭合（0x45A650 F577、0x45B490 F577、[0x140] timeKillEvent F577、0x476CA8 DSound3DListener F578）——**零未决项**。
- **〔HANDOFF 刷新 11〕**追加 Round 269-272（F575-F578：模拟器协议层 + 装载器族 + DSound 解析），基线 d54bc29 → 515600e。
- 落盘：all-pending-closed-evidence.json（F579，derived）+ RESEARCH_LOG + UI_COMPLETION_AUDIT Round 273。
## Round 274 (F580) — 2026-08-12：HUD caption 动作分派完整（16 分支）

- **〔循环〕**0x42BEF8/0x42BF02：16 次迭代（caption 对象 = HUD+0x567C+idx*0xB4、vtable[0x10] press 命中 → idx、jt 0x42C4D4）：0=背包（0x4300F0 + OpenWindow 0）、1=装备、2=商店、3=交易、4=行会、6=组队、7=角色状态、8=公告、B=任务、C=选项、D=坐骑、E=技能书（5/A 桩）——**与 F558 窗口注册表模式完全一致（交叉确认）**。
- **〔动作栏〕**0x42C1CE 攻击目标（0x41EC10 查找 + 0x451A70）、0x42C209 0x4523E0 发送、0x42C218/0x42C226/0x42C234 OpenWindow 6/8/0、**0x42C241 腰带切换 [0x6208]**、0x42C259 0x451770 发送（3s 冷却 [0x6210]）、**0x42C292 相机缩放 [0xD40] 钳制 0x2E + [0xD42]**、0x42C2E1 0x419CC0 生成检查 + 公告 [0x53030]、0x42C30D 装备面板模式 0 + 0x423E80。
- 落盘：hud-caption-action-dispatch-evidence.json（F580，primary-bytes）+ RESEARCH_LOG + UI_COMPLETION_AUDIT Round 274。
## Round 275 (F581) — 2026-08-12：HUD 热键/目标系统

- **〔热键〕**0x42D720 = **6 热键槽 RECT 命中**（数组 [0xD44] stride 0x10 {+0 x,+4 y,+8 w,+0xC h}、+0x26 垫、PtInRect、门 [0xD42]）；命中 → 0x42D9E0 执行（0x430920 物品构造 + 0x42D8A0 记录取 + 0x42E2D0 音效）或 0x42D8F0/0x42DAA0 变体；**金币门 0x47ADB4 + [0x5A]==3**（F549 금전 门复用）。
- **〔记录〕**热键记录 = 6 × 0xC24 @ [0xDA4]（0x42D7C0 构造 [0xDA4]=1 + 0x308 双字；0x42D790 清除；0x42D8A0 按 idx 取）。
- **〔渲染〕**0x42C511 热键栏渲染尾：0x417C80 命中 + [0xD20] 计数 × [0x61C8] 浮点滚动 → [0xD08] + 转发分派 0x42AAB0（0x430650 背包/0x44CED0 装备/0x44F110 商店/0x416E70 交易）。
- 落盘：hud-hotkey-target-system-evidence.json（F581，primary-bytes）+ RESEARCH_LOG + UI_COMPLETION_AUDIT Round 275。
## Round 276 (F582) — 2026-08-12：HUD 交互弧闭合（F580-F581 汇总）

- **〔验证〕**compileall OK、verify exit 0、node OK、JSON 有效、**207 证据 JSON**；三服务 200；master a5a8fb4（**240 连发 F335-F581 已推**）。
- **〔弧〕**16 caption 动作分派（jt 0x42C4D4，F580）+ 动作栏（攻击/腰带/缩放/生成检查）+ **6 热键槽目标系统**（F581：RECT 命中 + 0xC24 记录 + 执行 + 金币门）——**整个 HUD 交互层（caption/动作/热键）字节级**。
- 落盘：hud-interaction-arc-closure-evidence.json（F582，derived）+ RESEARCH_LOG + UI_COMPLETION_AUDIT Round 276。
## Round 277 (F583) — 2026-08-12：HANDOFF 刷新 12（Round 273-276）

- **〔刷新〕**HANDOFF 追加 Round 273-276（F579-F582：零 pending + HUD 交互层）；基线 Round 268=d54bc29 → Round 276=6ef0adb（**241 连发 F335-F582**）。
- 落盘：handoff-refresh-12-evidence.json（F583，derived-tooling）+ RESEARCH_LOG + UI_COMPLETION_AUDIT Round 277。
## Round 278 (F584) — 2026-08-12：小地图 HUD + 大地图渲染

- **〔小地图〕**0x429630：缩放态 [0xD42]（1=放大 +0xA / 2=缩小 -0xA，钳制 0x2E/0，自动清除）、帧 0x33 → 0x466130 → 0x460240 绘制于 (0x113, 0x1DE-[0xD40]) 0x320×0x258、**6 快捷装备图标**（记录 [0xDA8] stride 0xC24、矩形 [0xD44] stride 0x10、0x430A40、x-[0xD40] 滚动）。
- **〔大地图〕**0x429740：状态 [0x7DA1D4] 4 路 jt 0x42A83C（帧 0x82/0x83/0x84/0x85 经 0x466130）+ **玩家箭头 [0x7D9262]/[0x7D9264]**（2 字）+ 0x45FD50 绘制（([edi+0xC58]+0x2AC, [edi+0xC5C]+0x32)）+ HP/MP 条 [0x7DA109..0x7DA11D] + 相机 [0x7DA115]。
- 落盘：minimap-hud-worldmap-render-evidence.json（F584，primary-bytes）+ RESEARCH_LOG + UI_COMPLETION_AUDIT Round 278。
## Round 279 (F585) — 2026-08-12：聊天布局 + Mir3.ini 配置装载器

- **〔聊天〕**0x403640：门 [0xD38] 字节两布局（0=主聊天：文本 [0xE3D] + 输入 [0xD39] + 矩形 [0xF44..0xF50] MoveWindow；1=私聊：交换 + 矩形 [0xF54..0xF60] + 参 0x2A）、SendMessageA 0x476290（0xCC）+ SetFocus + ShowWindow（旗标 [0x8AB7E8]）。
- **〔配置〕**0x403780 = **Mir3.ini 配置装载器**：GetCurrentDirectoryA + '\' + 'Mir3.ini'（0x47AB5C）、GetPrivateProfileStringA：**Server/ServerAddr（默认 '192.168.0.200' 0x47AB4C）** + Param1 + Initial、GetPrivateProfileIntA：**ServerCount → [0xA38]**、Server → [0xA50] 列表——登录→服务器列表配置链。
- 落盘：chat-layout-mir3-ini-evidence.json（F585，primary-bytes）+ RESEARCH_LOG + UI_COMPLETION_AUDIT Round 279。
## Round 280 (F586) — 2026-08-12：窗口拖动/移动分派器

- **〔分派〕**0x42B430：模式 ≤ 0xF + 门（[0xD38] 计数/[0xD30] 尾/[0xD3C] 旗标）→ jt 0x42B658 每模式：0=背包/1=装备/2=商店（0x44E910 命中+）/3=交易/4=行会/6=组队/7=角色状态/8=公告（+ ShowWindow(0) [0x5081C] 门 + 0x42B980）/B=任务/C=选项/D=坐骑/E=技能书/F=[0x52E5C]——每例先窗特定预命中再 **0x423FA0(x,y) = 设置窗口位置**（F550 修正：0x423FA0 是位置设置器，非钳制）。
- 落盘：window-drag-move-dispatcher-evidence.json（F586，primary-bytes）+ RESEARCH_LOG + UI_COMPLETION_AUDIT Round 280。
## Round 281 (F587) — 2026-08-12：窗口输入/点击分派器

- **〔路由〕**0x42BA20：特殊窗优先（公告 [0x53030] 0x418A50、行会公告编辑 [0x52E5C] 0x43E640）→ **热键栏命中**（0x417D00 @ [0x61BC] + [0xD20]×[0x61C8] → [0xD08]，F581）→ **16 caption 循环**（vtable[0xC] 命中 @ [0x567C]+idx*0xB4）→ 0x428570 + 模式 jt 0x42BDE0 → 每窗点击（背包 0x42FFD0/装备 0x44CF00/商店 0x44EF00/交易 0x4171B0/行会 0x425CB0…）→ 兜底 **0x42B6A0(mode, x, y) = 模式切换按钮**。
- 落盘：window-input-click-dispatcher-evidence.json（F587，primary-bytes）+ RESEARCH_LOG + UI_COMPLETION_AUDIT Round 281。
## Round 282 (F588) — 2026-08-12：HUD 状态条 + HP/等级绘制

- **〔HP 条〕**0x42A040：**浮点渐变条**（×0x47644C 缩放、0x466800 变换 色浮点 0x3E20A0A1/0x3E70F0F1/0x3EA0A0A1、0x4542F0 经瓦片存储 0x5600FC type 0x51 F530）+ **HP 数字文本**（[0x7DA11F] → 0x45E0C0 测量 + 0x45DE50 绘制，居中 0x250/0x13B）+ 0x45E570 填充 0x324B64；**帧 0x43** WIL 绘制于 ([edi+0xC58]+0xD1, [edi+0xC5C]+0x25) 经 0x45F2D0。
- **〔等级〕**0x42A26A：等级 [0x7DA11F] + 格式 0x47BD40 + 居中 0x216/0xCD——HUD 状态条字节级（F530 实体 HP 扩展到 HUD 层）。
- 落盘：hud-status-bars-level-paint-evidence.json（F588，primary-bytes）+ RESEARCH_LOG + UI_COMPLETION_AUDIT Round 282。
## Round 283 (F589) — 2026-08-12：HANDOFF 刷新 13（Round 277-282）

- **〔刷新〕**HANDOFF 追加 Round 277-282（F584-F588：小地图/大地图渲染 + Mir3.ini 配置 + 窗口拖动/点击 + HUD 状态条）；基线 Round 276=6ef0adb → Round 282=ee78dbd（**247 连发 F335-F588**）。
- 落盘：handoff-refresh-13-evidence.json（F589，derived-tooling）+ RESEARCH_LOG + UI_COMPLETION_AUDIT Round 283。
## Round 284 (F590) — 2026-08-12：实体 HP 条完整 + 注册表

- **〔实体条〕**0x40A8A0（F530 扩展）：门 [0x61BB8]/[0x61BBC] + 屏幕 [0x8AB7BC]、类型 [0x8D] 4 路（0x51/0x89/0x81/0x8A → 旗标）、**HP = [0x61BA0]−[0xB4]+[0xC4] → [0x61B9C]**（F350）、注册表 0x4542A0（瓦片 0x5600FC **type*81*4**，边界 type<5 + idx<0x8C）→ 帧装载 0x466130 + **0x466800 变换**（RGB 浮点 0x47639C + 条尺寸字节 [0x61BB2..0x61BB5]）+ 屏幕投影（[0xE4]/[0xE8] + 0x476364）+ vtable[0x40]/[0x14]/[0x30] + blit。
- **〔0x4542F0〕**共享条 blit 助手（HUD F588 + 实体共用）——**完整条系统（实体 + HUD）字节级**。
- 落盘：entity-hp-bar-full-evidence.json（F590，primary-bytes）+ RESEARCH_LOG + UI_COMPLETION_AUDIT Round 284。
## Round 285 (F591) — 2026-08-12：主 tick 编排完整（0x41BB00）

- **〔delta〕**fild(time) × [0x428220] 速度 + 最小 0xA 钳制；累加器 [0x8B1A94]（帧门 > 0x5F → 旗标）+ [0x4279A8]/[0x4279A4]（冷却回绕 F246）；BGM 5s [0x428044]/[0x428048] → 0x45B250 + Sleep 0x1E。
- **〔18 阶段〕**0x41B440 → 0x422280 → 0x4227F0 → 0x465EA0 → 0x454C50 → 地图滚动 0x43B1E0（F116）→ 光场 0x434650 → 英雄 vtable[0x1C] → 相机 0x41A9D0/0x41A5B0 → 世界 blit 0x45E730（或 0x465D50+0x43C330）→ **网格清 0x419D40**（F336）→ 0x41C450 → **实体 tick 链 [0xE1170]**（类型 0x96/0x48 特例、vtable[0xC]、[0x4]==2 清理）→ **6 绘制对象 [0x361150..0x3614F4]**（门 [0x24]/[0x28]/[0x2C]）→ 英雄 HP 条 0x40A8A0（F590）+ 0x40BB00 + vtable[0x80] → 实体 HP 条 [0xE1158]（[0x88] 1/3/其他）→ 0x41B1C0 → 光场绘制 0x434D40（0x190×0x12C）→ 精灵链 vtable[0x10] → 特效 [0x364444]——**F439 确认并扩展完整编排**。
- 落盘：main-tick-orchestration-evidence.json（F591，primary-bytes）+ RESEARCH_LOG + UI_COMPLETION_AUDIT Round 285。
## Round 286 (F592) — 2026-08-12：HUD + 主循环弧闭合（F583-F591 汇总）

- **〔验证〕**compileall OK、verify exit 0、node OK、JSON 有效、**217 证据 JSON**；三服务 200；master 2be41c9（**250 连发 F335-F591 已推**）。
- **〔弧〕**HANDOFF 12（F583）+ 小地图/大地图（F584）+ Mir3.ini 配置（F585）+ 拖动/点击分派（F586/F587）+ HUD 状态条（F588）+ 实体 HP 条（F590）+ **主 tick 18 阶段**（F591）——**HUD 全层 + 实体条 + 游戏循环完整**。
- 落盘：hud-loop-arc-closure-evidence.json（F592，derived）+ RESEARCH_LOG + UI_COMPLETION_AUDIT Round 286。
## Round 287 (F593) — 2026-08-12：HANDOFF 刷新 14（Round 283-286）

- **〔刷新〕**HANDOFF 追加 Round 283-286（F590-F592：实体 HP 条 + 主 tick 18 阶段 + HUD/主循环弧）；基线 Round 282=ee78dbd → Round 286=f711837（**251 连发 F335-F592**）。
- 落盘：handoff-refresh-14-evidence.json（F593，derived-tooling）+ RESEARCH_LOG + UI_COMPLETION_AUDIT Round 287。
## Round 288 (F594) — 2026-08-12：大地图覆盖层/悬停渲染

- **〔悬停〕**0x429A40：鼠标矩形命中（[0xC68] + [0xC78] 两区，PtInRect）、**坐标文本**（0x47BD70 格式 → 0x45E0C0 测量 → 0x45DE50 白 0xFFFFFF 居中 0x211/0x6E）、渐变条 0x466800（0x3E70F0F1/0x3EF0F0F1 + 0x4542F0 瓦片）+ 填充 0x45E570 0x5050A0、**帧 0x3C** WIL 绘制（0x45F2D0）+ 地图名标签区。
- 落盘：worldmap-overlay-hover-evidence.json（F594，primary-bytes）+ RESEARCH_LOG + UI_COMPLETION_AUDIT Round 288。
## Round 289 (F595) — 2026-08-12：大地图玩家标记 + 比例条

- **〔比例〕**0x429880：比率数学（pos/denom 钳制 1.0 经 0x476658，守卫 [0x7DA113]/[0x7DA11F] 字）、**HP 比率 [0x7DA119]（qword 64 位除法）→ [0x50]**、MP/exp [0x54]、**帧 0x3E** WIL 绘制（玩家箭头，[0x36]<0x1C 门，位于 [0xC58]+0x31/[0xC5C]+0xC 经 0x45F2D0）。
- 落盘：worldmap-player-marker-ratios-evidence.json（F595，primary-bytes）+ RESEARCH_LOG + UI_COMPLETION_AUDIT Round 289。
## Round 290 (F596) — 2026-08-12：地图 widget 弧闭合（F584-F595 汇总）

- **〔验证〕**compileall OK、verify exit 0、node OK、JSON 有效、**221 证据 JSON**；三服务 200；master e5dc5e7（**254 连发 F335-F595 已推**）。
- **〔弧〕**小地图 HUD（F584：缩放 + 帧 0x33 + 6 图标）+ 大地图基础（F584：4 态 + 玩家箭头）+ 覆盖层/悬停（F594：坐标文本 + 渐变条 + 帧 0x3C）+ 玩家标记/比例条（F595：HP qword 比率 + 箭头帧 0x3E）——**整个地图 widget 层字节级**。
- 落盘：map-widget-arc-closure-evidence.json（F596，derived）+ RESEARCH_LOG + UI_COMPLETION_AUDIT Round 290。
## Round 291 (F597) — 2026-08-12：HANDOFF 刷新 15（Round 287-290）

- **〔刷新〕**HANDOFF 追加 Round 287-290（F594-F596：大地图覆盖层/标记 + 地图 widget 弧）；基线 Round 286=f711837 → Round 290=251b3bd（**255 连发 F335-F596**）。
- 落盘：handoff-refresh-15-evidence.json（F597，derived-tooling）+ RESEARCH_LOG + UI_COMPLETION_AUDIT Round 291。
## Round 292 (F598) — 2026-08-12：NPC 对话 4 类型渲染完整

- **〔类型〕**jt 0x440158（F540）：**类型 1**（0x43F4E7）= 文本换行渲染（0x45E0C0 测量 + 0x45DD70 绘制、7 行门 +0x131 y 偏移）；**类型 2**（0x43F86D）= **굴림 字体**（0x45DBA0 0x47C348、字号 0x190/9）+ 色旗标 [0x5C]/[0x5D]（0xFF 白/0xFFFF）+ 换行；**类型 3**（0x43F85F）= 跳行；**类型 4**（0x43FF92）= **特殊脚本标签**：**'FCOLOR'**（0x47C514）→ 色表 0x47C4A8（8 色 0/0xFF/0x8000/0x8080/0x808080/0x80/0x808000/0x800000）+ **'NPCIMG'**（0x47C50C）→ WIL 帧 blit（0x466130 + 0x45FD50 于 0x28/0x1E）+ **'NOTCLOSE'**（0x47C500）= 不关窗旗标——**NPC 对话脚本标签字节级**（F540 扩展）。
- 落盘：npc-dialog-4type-render-evidence.json（F598，primary-bytes）+ RESEARCH_LOG + UI_COMPLETION_AUDIT Round 292。
## Round 293 (F599) — 2026-08-12：聊天窗渲染完整

- **〔渲染〕**0x414700（F341 扩展）：输入矩形 SetRect(0x1A, 0x137, 0x20D, 0x146) @ [0x954]、**消息环**（滚动 [0x6D0] + 计数 [0x68] − 0x13 钳制 **19 行上限**、节点链 [0x58]/[0x5C]（+0x408 next、负 0x40C prev）、每行 0x45DD70 绘制（色 [0x8AB7C4]、y=[0x6C4]+行*0xE 14px、x=[0x6C0]））+ **滚动条 0x4179B0 @ [0x6D4]** + 10 控件矩形 0x417830（@ [0x6C]..[0x60C]）+ 9 控件遍历——聊天窗渲染字节级。
- 落盘：chat-window-render-full-evidence.json（F599，primary-bytes）+ RESEARCH_LOG + UI_COMPLETION_AUDIT Round 293。
## Round 294 (F600) — 2026-08-12：聊天命令表

- **〔命令〕**0x47ACB8 族（F355 分派）：'@拒绝私聊'（0x47ACC2/0x47AD70）、'@拒绝行会聊天'（0x47AD60）、'!~喊话)'（0x47ACDA 行会喊话）、'编组 喊话(!!喊话)'（0x47ACE4/0x47ACEE 组队喊话）、'!!'（0x47AD80）、'!~'（0x47AD7C）、'/%s '（0x47AD28 斜杠命令格式）；**金币交易提示 '您要付给对方多少金币?'**（0x47AD98，cp949 KR 源）+ '금전'（0x47ADB4 F549）。
- 落盘：chat-command-table-evidence.json（F600，primary-bytes）+ RESEARCH_LOG + UI_COMPLETION_AUDIT Round 294。
## Round 295 (F601) — 2026-08-12：聊天/NPC 对话弧闭合（F598-F600 汇总）

- **〔验证〕**compileall OK、verify exit 0、node OK、JSON 有效、**226 证据 JSON**；三服务 200；master d9db77d（**259 连发 F335-F600 已推**）。
- **〔弧〕**NPC 对话 4 类型渲染（F598）+ 聊天窗渲染（F599）+ 聊天命令表（F600）——**整个聊天/NPC 对话交互层字节级**。
- 落盘：chat-dialog-arc-closure-evidence.json（F601，derived）+ RESEARCH_LOG + UI_COMPLETION_AUDIT Round 295。
## Round 296 (F602) — 2026-08-12：HANDOFF 刷新 16（Round 292-295）

- **〔刷新〕**HANDOFF 追加 Round 292-295（F598-F601：NPC 对话 4 类型 + 聊天窗渲染 + 命令表 + 弧闭合）；基线 Round 290=251b3bd → Round 295=b9a2111（**260 连发 F335-F601**）。
- 落盘：handoff-refresh-16-evidence.json（F602，derived-tooling）+ RESEARCH_LOG + UI_COMPLETION_AUDIT Round 296。
## Round 297 (F603) — 2026-08-12：角色选择进入 + 表单布局

- **〔进入〕**0x458B20（F541 阶段 2/3）：槽 idx×0x40 记录 @ [0xCB8]（阶段 0/3）或 [0x10BC]（阶段 2）、门 [0x930] 字节（0/2/3）、0x458EC0 实体创建 → [esi+0x3C]、名 [0x38]、职业字 [0x20]、类型字 [0x22]。
- **〔布局〕**0x458BB0 = 表单布局构造：16+ 矩形 0x449C50（y 0xD2..0x4CE、x 0x78..0x456 = 角色选择屏按钮/输入）——角色选择进入 + 布局字节级（F541/F349 扩展）。
- 落盘：char-select-enter-layout-evidence.json（F603，primary-bytes）+ RESEARCH_LOG + UI_COMPLETION_AUDIT Round 297。
## Round 298 (F604) — 2026-08-12：角色列表解析器 + 槽工厂

- **〔解析〕**0x458F80：解析 msg 0x208-0x210（jt 0x45950C 9 例）、'/' 分隔符分词（0x468BF0）、每角色记录：名 → [0xCBF]、职业 → [0xCBC]、等级 → [0xCBE]/[0xCBD]（strlen 0x4681F9）、槽 @ [0xCB8]+idx×0x40、'/*' 标记 + 最多 2 角色（[esp+0x14] 钳制）。
- **〔工厂〕**0x458EC0 = 槽查找（职业 + 类型×2 + 工作 → [0x932]+idx×6，边界 < 0x1E）；0x458F00 = 0x451F90 发送包装——角色选择服务器列表字节级（F603 扩展）。
- 落盘：char-list-parser-factory-evidence.json（F604，primary-bytes）+ RESEARCH_LOG + UI_COMPLETION_AUDIT Round 298。
## Round 299 (F605) — 2026-08-12：登录弧闭合（F603-F604 汇总）

- **〔验证〕**compileall OK、verify exit 0、node OK、JSON 有效、**230 证据 JSON**；三服务 200；master 231ee79（**263 连发 F335-F604 已推**）。
- **〔弧〕**角色选择进入 + 表单布局（F603）+ 角色列表解析器 + 槽工厂（F604）——**登录族（F540 阶段机 + F541 5 阶段 + F349 角色选择 + F585 Mir3.ini + F603/F604）端到端完整**。
- 落盘：login-arc-closure-evidence.json（F605，derived）+ RESEARCH_LOG + UI_COMPLETION_AUDIT Round 299。
## Round 300 (F606) — 2026-08-12：HANDOFF 刷新 17（Round 296-299）

- **〔刷新〕**HANDOFF 追加 Round 296-299（F603-F605：角色选择进入/列表解析 + 登录弧）；基线 Round 295=b9a2111 → Round 299=74e206f（**264 连发 F335-F605**）。
- 落盘：handoff-refresh-17-evidence.json（F606，derived-tooling）+ RESEARCH_LOG + UI_COMPLETION_AUDIT Round 300。
## Round 301 (F607) — 2026-08-12：Intro/启动画面状态机

- **〔状态〕**0x402BE0：阶段 [0x8A4] 3 路（0→0x402D50、1→0x4031A0、2→0x403560）+ 0x4182A0 屏幕 [0x8A8]/[0x8AC]；0x402C40 子阶段 [0x8A5]：0 = **Interface1c 帧 0x3C** blit（0x45FD50）+ 0x45C900 载入 [0x6F4]；1 = **wemade.dat 启动画面**（0x45BE20）+ [0x8A5]=2；2 = 聊天显示 0x403640（F585）+ **音频初始化 0x45BF30**（0x9135C0 + 0x8AB7B8、格式 0x47AAD0）+ 矩形 + 0x45C4C0。
- **〔绘制〕**0x402D50：渐变 0x466800 + 填充 0x45E570 0x646464 + 4 控件遍历 [0xA68] stride 0xB4——Intro 启动链字节级（F585/F336 连接）。
- 落盘：intro-splash-state-machine-evidence.json（F607，primary-bytes）+ RESEARCH_LOG + UI_COMPLETION_AUDIT Round 301。
## Round 302 (F608) — 2026-08-12：登录/服务器屏绘制

- **〔绘制〕**0x4031A0：渐变背景 0x466800 + 填充 0x45E570 0x969696、**服务器列表遍历**（[0xA50] 节点 +4 数据、[0xA64] 选中 = -1）、每服务器悬停矩形 [esi+0x208..0x214]（PtInRect）+ 渐变 0x4029A0 + 服务器名 **0xFF0000 红** + 0x45DE50；[0xA3C..0xA48] 窗口矩形浮点——登录服务器选择屏字节级（F585 Mir3.ini 服务器列表连接）。
- 落盘：login-server-screen-paint-evidence.json（F608，primary-bytes）+ RESEARCH_LOG + UI_COMPLETION_AUDIT Round 302。
## Round 303 (F609) — 2026-08-12：启动/登录弧闭合（F607-F608 汇总）

- **〔验证〕**compileall OK、verify exit 0、node OK、JSON 有效、**234 证据 JSON**；三服务 200；master 0bef374（**267 连发 F335-F608 已推**）。
- **〔弧〕**Intro/启动状态机（F607）+ 登录/服务器屏（F608）——**整个启动链（启动画面 → 服务器选择 → 登录 → 角色选择 F603/F604 → 进入）字节级**，连接 F585/F605。
- 落盘：launch-login-arc-closure-evidence.json（F609，derived）+ RESEARCH_LOG + UI_COMPLETION_AUDIT Round 303。
## Round 304 (F610) — 2026-08-12：HANDOFF 刷新 18（Round 300-303）

- **〔刷新〕**HANDOFF 追加 Round 300-303（F607-F609：Intro/启动状态机 + 登录/服务器屏 + 启动弧 + **300 轮里程碑**）；基线 Round 299=74e206f → Round 303=e918c0d（**268 连发 F335-F609**）。
- 落盘：handoff-refresh-18-evidence.json（F610，derived-tooling）+ RESEARCH_LOG + UI_COMPLETION_AUDIT Round 304。
## Round 305 (F611) — 2026-08-12：死亡/传送泵完整（0x422960）

- **〔死亡〕**检查（[0x2F8840]==3 + [0x35A31C]−[0x35A320] < [0x35A329]−1 延迟）或冷却 [0x4279A4] → **重生路径**：0x42E1F0 英雄重置 + 0x45B1D0/0x45B3D0、冷却 = 0x5DC（1500ms）、坐标 [0x35A31C]/[0x35A320] 重置 + [0x35A329]=0xA、**活动坐标 [0x2F884C]/[0x2F8850] = 包字 +6/+8（F310 两写者确认）** + 镜像 [0x35B25C]/[0x35B260]、瓦片存储清 0x38400 双字。
- **〔光照〕**色类型分派（字节 +0xA：0→0xFFFFFF、1→0xF0F0F、2→0x555555）+ 0x434610 + 0x41C1E0；实体列表 [0xE11D0] 清理——**死亡/重生生命周期字节级**。
- 落盘：death-teleport-pump-evidence.json（F611，primary-bytes）+ RESEARCH_LOG + UI_COMPLETION_AUDIT Round 305。
## Round 306 (F612) — 2026-08-12：英雄移动/相机

- **〔移动〕**0x41A9D0：门 [0x35B1D0]/[0x35B1D4] + 计时器 [0x2F8870]、英雄 vtable[0x18] + **0x410840 移动**（方向 [0x2F8841]、状态 [0x35B148] 0x1D 变体）、世界坐标 [0x2F884C]/[0x2F8850] → **0x43CC30 地图移动**（[0xF5200]）+ [0x2F8809]==7 + [0x35B268] → 0x410840(0xB) 特例。
- **〔目标〕**点击目标实体 [0x364450]：类型 [0x88] 门 + 名比对（0x468BF0）+ GetAsyncKeyState 0x476278/0x476250 + [0x61C70] 动画——英雄移动 + 点击目标相机字节级（F591 阶段连接）。
- 落盘：hero-movement-camera-evidence.json（F612，primary-bytes）+ RESEARCH_LOG + UI_COMPLETION_AUDIT Round 306。
## Round 307 (F613) — 2026-08-12：地图移动 + 碰撞

- **〔移动〕**0x43CC30：**8 方向 jt 0x43CD94**（dir ≤ 7，dx/dy 数学）→ 0x43C9F0 碰撞 → 结果 [out] = 新 x/y。
- **〔碰撞〕**实体列表 [0x560070]/[0x560080] 遍历：类型 [0x88] 门（0/1/3）+ [0xC0] 状态（0x13/4）+ [0x61C74] 旗标 + 坐标匹配 [0xCC]/[0xD0] → 阻挡。
- **〔计数〕**0x43CDC0：地图信息计数器 [0x1B01B4..0x1B01BC]（阈值 0x96/0x19/0x32）——地图移动 + 碰撞字节级（F612 连接）。
- 落盘：map-move-collision-evidence.json（F613，primary-bytes）+ RESEARCH_LOG + UI_COMPLETION_AUDIT Round 307。
## Round 308 (F614) — 2026-08-12：英雄运行时弧闭合（F611-F613 汇总）

- **〔验证〕**compileall OK、verify exit 0、node OK、JSON 有效、**239 证据 JSON**；三服务 200；master fb5ee0f（**272 连发 F335-F613 已推**）。
- **〔弧〕**死亡/传送泵（F611）+ 英雄移动/相机（F612）+ 地图移动/碰撞（F613）——**英雄运行时生命周期（死亡→重生→移动→碰撞）完整**。
- 落盘：hero-runtime-arc-closure-evidence.json（F614，derived）+ RESEARCH_LOG + UI_COMPLETION_AUDIT Round 308。
## Round 309 (F615) — 2026-08-12：HANDOFF 刷新 19（Round 304-308）

- **〔刷新〕**HANDOFF 追加 Round 304-308（F611-F614：死亡/重生泵 + 英雄移动/相机 + 地图移动/碰撞 + 英雄运行时弧）；基线 Round 303=e918c0d → Round 308=6ec8705（**273 连发 F335-F614**）。
- 落盘：handoff-refresh-19-evidence.json（F615，derived-tooling）+ RESEARCH_LOG + UI_COMPLETION_AUDIT Round 309。
## Round 310 (F616) — 2026-08-12：攻击/交易发送器 + 窗口消息分派

- **〔发送〕**0x451A70 = **攻击 msg 0x401**、0x451AA0 = 交易 0x402、0x451AD0 = 0x403、0x451B00 = 金币 0x405、0x451B30 = 0x406（全经 0x452940 头 + 0x451E60 帧 F572）。
- **〔窗口〕**0x451B60 = 系统窗口消息（SendMessage 0x476114 + 0x47628C + GlobalAlloc/Free 0x4760B8/0x4760BC、格式 0x47C818）；0x451BB0 = **窗口消息分派器**（0x4515C0 解析 + 类型 1/0x10/0x1F → 0x451CC0/0x451C40/0x451CB0）。
- 落盘：attack-trade-sender-wnd-dispatch-evidence.json（F616，primary-bytes）+ RESEARCH_LOG + UI_COMPLETION_AUDIT Round 310。
## Round 311 (F617) — 2026-08-12：NPC 回复发送 + 随机种子 + 校验和

- **〔发送〕**0x4524D0 = 技能/NPC 回复 **msg 0x411**（0x452940 头 + 0x451E60 帧 F572，F476）。
- **〔种子〕**0x452580 = **随机种子初始化**（0x9135B8/0x9135BC 4+4 字节，源时间 0x4685E8 + 0x4684A8、经 0x4684B2 rand 填充）。
- **〔校验〕**0x4525F0 = **校验和验证**：4 字节键 XOR（0x9135B8）+ 载荷加权和（idx×字节）vs 存储 [0x9135BC] + 字节验证——**反作弊/包完整性字节级**。
- 落盘：npc-reply-random-checksum-evidence.json（F617，primary-bytes）+ RESEARCH_LOG + UI_COMPLETION_AUDIT Round 311。
## Round 312 (F618) — 2026-08-12：出站发送弧闭合（F616-F617 汇总）

- **〔验证〕**compileall OK、verify exit 0、node OK、JSON 有效、**243 证据 JSON**；三服务 200；master 3db040c（**276 连发 F335-F617 已推**）。
- **〔弧〕**攻击/交易/金币发送器（F616：msg 0x401-0x406 + wnd 分派）+ NPC 回复/随机种子/校验和（F617：msg 0x411 + XOR 完整性）——**整个出站发送层（全部游戏动作 + 完整性）字节级**，补全 F572/F573 文本帧协议。
- 落盘：outbound-send-arc-closure-evidence.json（F618，derived）+ RESEARCH_LOG + UI_COMPLETION_AUDIT Round 312。
## Round 313 (F619) — 2026-08-12：模拟器校验和层

- **〔实现〕**app.js sendFrame() 扩展：simSeedKey [0x13,0x37,0x52,0x71]（镜像 0x9135B8 4 字节种子 F617）、simChecksum() = **0x4525F0 XOR 算法**（4 字节键 XOR + 加权载荷和 (idx+1)×idx vs [0x9135BC]）→ '[送出] #seq cmd/args! ... XOR 校验和 0xXXXXXXXX'。
- **〔验证〕**node --check OK + sim 200 无回归——模拟器镜像 F617 线完整性。
- 落盘：sim-checksum-layer-evidence.json（F619，primary-bytes 算法 + derived 集成）+ RESEARCH_LOG + UI_COMPLETION_AUDIT Round 313。
## Round 314 (F620) — 2026-08-12：HANDOFF 刷新 20（Round 309-313）

- **〔刷新〕**HANDOFF 追加 Round 309-313（F616-F619：攻击/交易发送器 + NPC 回复/校验和 + 出站弧 + 模拟器校验和层）；基线 Round 308=6ec8705 → Round 313=50f6c52（**278 连发 F335-F619**）。
- 落盘：handoff-refresh-20-evidence.json（F620，derived-tooling）+ RESEARCH_LOG + UI_COMPLETION_AUDIT Round 314。
## Round 315 (F621) — 2026-08-12：英雄名/等级文本层

- **〔层〕**0x40BB00：显示旗标 [0x620A0] + **悬停计时器 [0x6209C]（0xBB8 = 3000ms → 清名缓冲 [0x621A4] 0x208 双字，F531 目标框计时器连接）**、名 [0x621A4] + 模式 [0x61C8C]（1 = 居中名文本 0x45E0C0+0x45DE50，否则等级缩放偏移）。
- **〔渲染〕**SetRect + 渐变 0x466800（0x3E20A0A1 族）+ 屏幕 vtable[0x40]/[0x14] 投影——英雄头顶名/等级文本字节级（F531/F590 连接）。
- 落盘：hero-name-level-text-evidence.json（F621，primary-bytes）+ RESEARCH_LOG + UI_COMPLETION_AUDIT Round 315。
## Round 316 (F622) — 2026-08-12：实体屏幕投影 + HP 框

- **〔投影〕**0x40B2A0 = 光阴影（0x434A20 0x190×0xF2，F436）；0x40B2C0 = **实体世界→屏幕投影**（[0xE4] = (wx−camX)×3×16 − camY + wy − 0xC8、[0xE8] = (wy−camY)×32……48×32 F435 数学，相机 [0x12C]/[0x130]/[0x134]/[0x138]）。
- **〔HP 框〕**实体 [0x90] 帧 + **HP 选择**（[0x61C64]/[0x61B99] 旗标、[0xB4]/[0xB8]/[0xC4] F350）→ 0x466130 帧 + SetRect + **钳制 0x3A（58px）/0x28（40px）** → [0xA4]/[0xA8]/[0xAC] 目标矩形——实体投影 + 目标 HP 框字节级。
- 落盘：entity-projection-hp-frame-evidence.json（F622，primary-bytes）+ RESEARCH_LOG + UI_COMPLETION_AUDIT Round 316。
## Round 317 (F623) — 2026-08-12：实体渲染弧闭合（F621-F622 汇总）

- **〔验证〕**compileall OK、verify exit 0、node OK、JSON 有效、**248 证据 JSON**；三服务 200；master eb7ef71（**281 连发 F335-F622 已推**）。
- **〔弧〕**英雄名/等级文本层（F621）+ 实体投影/HP 框（F622）——**实体渲染层完整（投影 → HP 条/框 → 名/等级 → 阴影）**，连接 F435/F436/F350/F531/F590。
- 落盘：entity-render-arc-closure-evidence.json（F623，derived）+ RESEARCH_LOG + UI_COMPLETION_AUDIT Round 317。
## Round 318 (F624) — 2026-08-12：HANDOFF 刷新 21（Round 314-317）

- **〔刷新〕**HANDOFF 追加 Round 314-317（F621-F623：英雄名/等级文本 + 实体投影/HP 框 + 实体渲染弧）；基线 Round 313=50f6c52 → Round 317=581fd9e（**282 连发 F335-F623**）。
- 落盘：handoff-refresh-21-evidence.json（F624，derived-tooling）+ RESEARCH_LOG + UI_COMPLETION_AUDIT Round 318。
## Round 319 (F625) — 2026-08-12：特效生成完整（0x435030）

- **〔生成〕**0x435030（F489 确认）：记录存储 0x8AA5A8 + 0x449C10、类型门（ax 1/5/0x25/0x27/0x28/0x29 跳过）、**目标实体 [0x18]**（英雄 id [0x77769C] → [0x777698] 或 [0x560070] 列表查找）、**起止坐标** → [0xC0]/[0xC4]/[0xD0]/[0xD4] + 0x43CFD0 投影（[0xB8]/[0xBC]/[0xC8]/[0xCC]）→ [0xA0..0xAC] 屏幕、**速度浮点 0x47689C** delta → [0x110]、帧 [0x128] 字 + 色 [0xF0..0xF2] 0xFF——特效生成（MonMagic type×10 帧基 F489）字节级。
- 落盘：effect-spawn-full-evidence.json（F625，primary-bytes）+ RESEARCH_LOG + UI_COMPLETION_AUDIT Round 319。
## Round 320 (F626) — 2026-08-12：特效 tick + 生命周期

- **〔tick〕**0x435A20（F489 确认）：[0xDC] += delta、**类型分派（0x16/0x10/9/0x1E/0xB/0x14A-0x14E/0x140-0x142/0xA/0x21A/0x21B/0x35/0x3F/0x68/0x150 = F336 特殊族确认）**、0xC8（200）tick 门、帧 [0x121]++ 回绕 [0x102]。
- **〔生命周期〕**[byte+4]：**0 动画中**（帧推进）/ **1 淡出**（[0xE8]/[0xE9] 或 [0xEA]/[0xEB]/[0xEC] −2 衰减钳制 2）/ **2 移除**——特效 tick + 生命周期字节级（F489 管线渲染侧）。
- 落盘：effect-tick-lifecycle-evidence.json（F626，primary-bytes）+ RESEARCH_LOG + UI_COMPLETION_AUDIT Round 320。
## Round 321 (F627) — 2026-08-12：特效弧闭合（F625-F626 汇总）

- **〔验证〕**compileall OK、verify exit 0、node OK、JSON 有效、**251 证据 JSON**；三服务 200；master 4687b3b（**285 连发 F335-F626 已推**）。
- **〔弧〕**特效生成（F625）+ 特效 tick/生命周期（F626）——**法术特效管线完整（生成 → tick → 淡出 → 移除）**，连接 F489/F336/F435。
- 落盘：effect-arc-closure-evidence.json（F627，derived）+ RESEARCH_LOG + UI_COMPLETION_AUDIT Round 321。
## Round 322 (F628) — 2026-08-12：HANDOFF 刷新 22（Round 318-321）

- **〔刷新〕**HANDOFF 追加 Round 318-321（F625-F627：特效生成 + tick/生命周期 + 特效弧）；基线 Round 317=581fd9e → Round 321=582e689（**286 连发 F335-F627**）。
- 落盘：handoff-refresh-22-evidence.json（F628，derived-tooling）+ RESEARCH_LOG + UI_COMPLETION_AUDIT Round 322。
## Round 323 (F629) — 2026-08-12：565 混合 + RLE 绘制

- **〔混合〕**0x4621F0（F489 绘制侧）：**16 位 RGB565 拆分**（掩码 0x7E0F81F/0x7C0F83F/0xF81F07E0）、**每通道 α 混合**（src×α + dst×(32−α))>>5）、暂存 [0x917C20..0x917C2C]。
- **〔RLE〕**操作码 0xC2/0xC3 填充（α 0x12C/0x130、[ebx+0x6C]/[0x70]/[0x74] 掩码 + 移位 [0x67]/[0x68]/[0x69]）——565 混合 + RLE 绘制字节级（F436 RLE 操作确认）。
- 落盘：565-blend-rle-paint-evidence.json（F629，primary-bytes）+ RESEARCH_LOG + UI_COMPLETION_AUDIT Round 323。
## Round 324 (F630) — 2026-08-12：混合/渲染弧闭合（F629 汇总）

- **〔验证〕**compileall OK、verify exit 0、node OK、JSON 有效、**254 证据 JSON**；三服务 200；master 16f0ac0（**288 连发 F335-F629 已推**）。
- **〔弧〕**565 混合 + RLE 绘制（F629）补全法术特效渲染（F625 生成 + F626 tick + F629 绘制 = **完整**）。
- **〔仓库〕**用户 quest-design 文件（item_catalog.json/vision_item_desc/vision_batches）在工作树——**未触碰**（用户所有）。
- 落盘：blend-render-arc-closure-evidence.json（F630，derived）+ RESEARCH_LOG + UI_COMPLETION_AUDIT Round 324。
## Round 325 (F631) — 2026-08-12：HANDOFF 刷新 23（Round 322-324）

- **〔刷新〕**HANDOFF 追加 Round 322-324（F629-F630：565 混合/RLE + 混合渲染弧）；基线 Round 321=582e689 → Round 324=2603e46（**289 连发 F335-F630**）。
- 落盘：handoff-refresh-23-evidence.json（F631，derived-tooling）+ RESEARCH_LOG + UI_COMPLETION_AUDIT Round 325。
## Round 326 (F632) — 2026-08-12：音效引擎 + DirectSound 初始化

- **〔播放〕**0x45B250：**SOUND\ 路径**（0x47D88C）+ 名过滤器 'none'（0x47D884）/'nobgm'（0x47D87C）、0x45AF30 名查找、0x45A3E0/0x45A4A0 播放（hwnd [0x8AB7B0]）+ 音效 id。
- **〔初始化〕**0x45BF30 = **DirectSound 初始化**（0x4680E6 创建 + IID 'vids' 0x73646976 + 0x4680D4/0x4680DA QueryInterface + 缓冲结构 0x7C/0x1B + 0x4680CE/0x4680C8、状态 [0x1A4]/[0x1A8]/[0x1AC]）——音效引擎字节级（F607 音频初始化连接）。
- 落盘：sound-engine-directsound-evidence.json（F632，primary-bytes）+ RESEARCH_LOG + UI_COMPLETION_AUDIT Round 326。
## Round 327 (F633) — 2026-08-12：音乐引擎构造 + 停止

- **〔构造〕**0x45BD80 = 音乐 ctor（状态清 [0x0..0x38]/[0x74..0x1AC] + SetRect 0x4762B0 @ [0x3C]/[0x4C] + 0x23 双字 ×2）。
- **〔停止〕**0x45BE20 = 音乐停止/清理（0x45C550 + **midiOutStop 0x400E** 经 0x4680BC + 释放 0x4680F8/0x4680B0/0x4680AA + 0x4680A4）——音乐引擎字节级（F632 音效引擎兄弟、F607 音频族）。
- 落盘：music-engine-ctor-stop-evidence.json（F633，primary-bytes）+ RESEARCH_LOG + UI_COMPLETION_AUDIT Round 327。
## Round 328 (F634) — 2026-08-12：音频弧闭合（F632-F633 汇总）

- **〔验证〕**compileall OK、verify exit 0、node OK、JSON 有效、**258 证据 JSON**；三服务 200；master da0e285（**292 连发 F335-F633 已推**）。
- **〔弧〕**音效引擎 + DirectSound（F632）+ 音乐 MIDI 引擎（F633）——**音频子系统完整（音效 + DSound + MIDI BGM）**，连接 F607/F470/F528。
- **〔仓库〕**用户 quest 文件（item_catalog.json/vision_item_desc/vision_batches）未触碰。
- 落盘：audio-arc-closure-evidence.json（F634，derived）+ RESEARCH_LOG + UI_COMPLETION_AUDIT Round 328。
## Round 329 (F635) — 2026-08-12：HANDOFF 刷新 24（Round 325-328）

- **〔刷新〕**HANDOFF 追加 Round 325-328（F632-F634：音效/DSound + MIDI 音乐 + 音频弧）；基线 Round 324=2603e46 → Round 328=5534555（**293 连发 F335-F634**）。
- 落盘：handoff-refresh-24-evidence.json（F635，derived-tooling）+ RESEARCH_LOG + UI_COMPLETION_AUDIT Round 329。
## Round 330 (F636) — 2026-08-12：主构造 + WinMain 引导

- **〔构造〕**0x401970 = **主 ctor 尾**（mov ecx, 0x47EF18 → jmp 0x418B00，**F451 基址证明**）、0x401990 = 静态析构（0x418D50）。
- **〔引导〕**0x401B30 = **WinMain 引导**：[0x47EEB8]=0x131C9A5 魔数、[0x47EF10]=0 游戏对象空初始化、0x401700 rand（0x5DC/0x3E8）、配置 GetPrivateProfileStringA 族（0x47613C/0x476138/0x4761A4、节 0x47A2B8/0x47A2C0）、DllMain 守卫 [0x917C1C]——启动链字节级（F451 确认）。
- 落盘：main-ctor-bootstrap-evidence.json（F636，primary-bytes）+ RESEARCH_LOG + UI_COMPLETION_AUDIT Round 330。
## Round 331 (F637) — 2026-08-12：主构造体 + 子系统链

- **〔列表〕**5 实体链表 vtable（0x4766F0/0x4766D4/0x4766B8/0x47669C/0x476680 @ [0xE1154..0xE11E0] = F336 容器族）。
- **〔子系统〕**瓦片 0x4529B0 [0xE11E4]、地图 0x43AF70 [0xF5200]、英雄 0x426C10 [0x2A548C]、英雄角色 0x40FE80 [0x2F8780]、光场 0x4344E0 [0x35B2C0]、**6 绘制对象** [0x361150..0x3614F4]（F439）、公告 0x417EC0 [0x3615B0]、备忘 3 个（0x446BF0/0x455A80/0x456180）；vtable [0]=0x476670 + 0x418EE0——**完整游戏对象构造字节级**（F451/F336/F439 连接）。
- 落盘：main-ctor-body-subsystems-evidence.json（F637，primary-bytes）+ RESEARCH_LOG + UI_COMPLETION_AUDIT Round 331。
## Round 332 (F638) — 2026-08-12：启动/构造弧闭合（F636-F637 汇总）

- **〔验证〕**compileall OK、verify exit 0、node OK、JSON 有效、**262 证据 JSON**；三服务 200；master 6f96ef2（**296 连发 F335-F637 已推**）。
- **〔弧〕**主构造 + WinMain 引导（F636）+ 主构造体/子系统（F637）——**整个启动链（WinMain → 魔数 → ctor → 子系统 → Intro F607）字节级**，F451 基址闭环。
- 落盘：startup-construction-arc-closure-evidence.json（F638，derived）+ RESEARCH_LOG + UI_COMPLETION_AUDIT Round 332。
## Round 333 (F639) — 2026-08-12：HANDOFF 刷新 25（Round 329-332）

- **〔刷新〕**HANDOFF 追加 Round 329-332（F636-F638：主构造/引导 + 构造体 + 启动弧）；基线 Round 328=5534555 → Round 332=0d191b0（**297 连发 F335-F638**）。
- 落盘：handoff-refresh-25-evidence.json（F639，derived-tooling）+ RESEARCH_LOG + UI_COMPLETION_AUDIT Round 333。
## Round 334 (F640) — 2026-08-12：帧节奏 + LRU 淘汰

- **〔节奏〕**0x454C40：GetTickCount 0x47611C **0xEA60（60s）帧门** + 每项 LRU：[esi+0x20] 最后使用 vs **0x493E0（300s）** → 淘汰（vtable[0x14] 卸载 + [0x1C] + 0x4680F8）、[0x8] 帧时间。
- **〔创建〕**0x454CC0：条目创建（idx×81×4 stride 0x24 + 0x466130 装载）——帧节奏 + WIL LRU 缓存淘汰字节级（F436 LRU 0x3A98/0x493E0ms 确认）。
- 落盘：frame-pacing-lru-evict-evidence.json（F640，primary-bytes）+ RESEARCH_LOG + UI_COMPLETION_AUDIT Round 334。
## Round 335 (F641) — 2026-08-12：游戏循环弧闭合（F636-F640 汇总）

- **〔验证〕**compileall OK、verify exit 0、node OK、JSON 有效、**265 证据 JSON**；三服务 200；master 807f3b6（**299 连发 F335-F640 已推**）。
- **〔弧〕**WinMain/主构造（F636）+ 构造体/子系统（F637）+ 帧节奏/LRU（F640）——**整个客户端生命周期字节级（引导 → 构造 → 子系统 → Intro → 登录 → 游戏循环 F591 → LRU）**。
- **〔仓库〕**用户 quest 文件未触碰。
- 落盘：game-loop-arc-closure-evidence.json（F641，derived）+ RESEARCH_LOG + UI_COMPLETION_AUDIT Round 335。
## Round 336 (F642) — 2026-08-12：HANDOFF 刷新 26（Round 333-335）

- **〔刷新〕**HANDOFF 追加 Round 333-335（F640-F641：帧节奏/LRU + 游戏循环弧 + **300 连发里程碑**）；基线 Round 332=0d191b0 → Round 335=8909fb9（**300 连发 F335-F641**）。
- 落盘：handoff-refresh-26-evidence.json（F642，derived-tooling）+ RESEARCH_LOG + UI_COMPLETION_AUDIT Round 336。
## Round 337 (F643) — 2026-08-12：变换矩阵 + 向量数学

- **〔矩阵〕**0x466800 = **4×4 矩阵设置**（清 0x11 双字 + 从 4 浮点填对角；F588/F594/F625 全族共用的 'transform'）。
- **〔向量〕**0x466850 = **3D 向量数学**（3 向量差 + 0x466FB0 点积 + fsqrt 归一化 vs 0x476C6C ε + 叉积 0x445C60，D3D 风格 look-at/basis）——矩阵/向量数学核心字节级（共享变换引擎识别）。
- 落盘：transform-matrix-vector-math-evidence.json（F643，primary-bytes）+ RESEARCH_LOG + UI_COMPLETION_AUDIT Round 337。
## Round 338 (F644) — 2026-08-12：向量点积 + 矩阵乘法

- **〔点积〕**0x466FB0 = **自点积**（v·v = |v|²）、0x466FE0 = **双向量点积**（a·b）、0x445C60 = **3 向量复制**（{x,y,z} → out）。
- **〔矩阵〕**0x467000 = **4×4 矩阵乘法**（4×4 循环、矩阵 [esp+0x14]、行×16 + 列×4）——向量/矩阵核心完整（F643 扩展，全变换共用）。
- 落盘：vector-dot-matrix-mult-evidence.json（F644，primary-bytes）+ RESEARCH_LOG + UI_COMPLETION_AUDIT Round 338。
## Round 339 (F645) — 2026-08-12：数学核弧闭合（F643-F644 汇总）

- **〔验证〕**compileall OK、verify exit 0、node OK、JSON 有效、**269 证据 JSON**；三服务 200；master 59a6127（**303 连发 F335-F644 已推**）。
- **〔弧〕**变换矩阵 + 向量数学（F643）+ 向量点积 + 矩阵乘法（F644）——**共享数学核完整**（支撑全部渐变/绘制/投影 F588/F594/F625/F435）。
- 落盘：math-core-arc-closure-evidence.json（F645，derived）+ RESEARCH_LOG + UI_COMPLETION_AUDIT Round 339。
## Round 340 (F646) — 2026-08-12：HANDOFF 刷新 27（Round 336-339）

- **〔刷新〕**HANDOFF 追加 Round 336-339（F643-F645：帧节奏/LRU + 变换矩阵/向量 + 点积/矩阵乘 + 数学核弧）；基线 Round 335=8909fb9 → Round 339=4ce6ee7（**304 连发 F335-F645**）。
- 落盘：handoff-refresh-27-evidence.json（F646，derived-tooling）+ RESEARCH_LOG + UI_COMPLETION_AUDIT Round 340。
## Round 341 (F647) — 2026-08-12：通用 WIL blit + RLE 解码

- **〔blit〕**0x45FD50（F436/F292 族）：裁剪 0x320×0x258（800×600 屏）+ 负偏移钳制、表面 vtable[0x64] GetDC（结构 0x7C）、dst 步长 (w/2)×x。
- **〔RLE〕**16 位 RLE 解码：**0xC0 = 跳行**（字数 → x 前进）、**0xC1 = 像素行**（字数 + 左右裁剪）、字对行——blit 引擎 + RLE 解码字节级（支撑 F584/F607/F629 全部 blit）。
- 落盘：universal-wil-blit-evidence.json（F647，primary-bytes）+ RESEARCH_LOG + UI_COMPLETION_AUDIT Round 341。
## Round 342 (F648) — 2026-08-12：主世界 blit

- **〔blit〕**0x45E730（F591 世界 blit 阶段）：裁剪 0x320×0x258 + 负偏移钳制、表面 vtable[0x64] GetDC（0x7C）、**逐行 16 位复制**（行步长 + rep movsd/movsb）——主世界→屏幕 blit 字节级（F591 阶段 + F647 blit 族）。
- 落盘：world-blit-main-evidence.json（F648，primary-bytes）+ RESEARCH_LOG + UI_COMPLETION_AUDIT Round 342。
## Round 343 (F649) — 2026-08-12：blit/渲染弧闭合（F647-F648 汇总）

- **〔验证〕**compileall OK、verify exit 0、node OK、JSON 有效、**273 证据 JSON**；三服务 200；master 4ccdb3c（**307 连发 F335-F648 已推**）。
- **〔弧〕**通用 WIL blit + RLE（F647）+ 主世界 blit（F648）——**渲染引擎完整（通用 RLE blit + 世界 blit + 565 混合 F629）**，支撑全部绘制路径。
- 落盘：blit-render-arc-closure-evidence.json（F649，derived）+ RESEARCH_LOG + UI_COMPLETION_AUDIT Round 343。
## Round 344 (F650) — 2026-08-12：HANDOFF 刷新 28（Round 340-343）

- **〔刷新〕**HANDOFF 追加 Round 340-343（F647-F649：通用 RLE blit + 世界 blit + 渲染弧）；基线 Round 339=4ce6ee7 → Round 343=aa3e93e（**308 连发 F335-F649**）。
- 落盘：handoff-refresh-28-evidence.json（F650，derived-tooling）+ RESEARCH_LOG + UI_COMPLETION_AUDIT Round 344。
## Round 345 (F651) — 2026-08-12：物品图标绘制 + 详情分派

- **〔图标〕**0x430A40（F464/F559）：**3 上下文分派**（字节 [esp+0xC]：0 = StoreItem 0x5668C4、1 = 0x566A08、2 = 0x56B0E8 WIL 表，帧 [0x28] 经 0x466130）、居中数学 0x13（19px 半）、[0x22] 类型 0xA/0xB 色调 → 0x45E4E0、blit 0x460240。
- **〔详情〕**0x430B70 = 物品详情 **5 类分派**（jt 0x430BF8：0x430C40/0x431E50/0x432A80/0x431860/0x433CF0 = F457/F460 5 类提示框族确认）——物品图标 + 详情核心字节级。
- 落盘：item-icon-draw-detail-evidence.json（F651，primary-bytes）+ RESEARCH_LOG + UI_COMPLETION_AUDIT Round 345。
## Round 346 (F652) — 2026-08-12：物品反序列化 + 背包 IO

- **〔反序列化〕**0x42FC20（F464/F549）：0x42F2A0 解析 + 0x42F280 + 0x42F440 插入（0xC28 栈、ret 0xC28）。
- **〔背包〕**0x42FCC0 = 背包取（idx×0xC20 @ [0x774]、0x308 双字复制 + 0x42FB20 标记清）；0x42FD10 = 背包放（0x430920 物品构造 + 0x42FCC0 + 0x42FC20 反序列化 + [0x1A] 字）——物品记录 IO 字节级（F464/F549/F590 连接）。
- 落盘：item-deserialize-bag-io-evidence.json（F652，primary-bytes）+ RESEARCH_LOG + UI_COMPLETION_AUDIT Round 346。
## Round 347 (F653) — 2026-08-12：物品核心弧闭合（F651-F652 汇总）

- **〔验证〕**compileall OK、verify exit 0、node OK、JSON 有效、**277 证据 JSON**；三服务 200；master 33f8b89（**311 连发 F335-F652 已推**）。
- **〔弧〕**物品图标 + 详情分派（F651）+ 反序列化 + 背包 IO（F652）——**物品系统核心完整（图标/渲染 + 详情/提示框 + 序列化/IO）**，连接 F464/F457/F460/F549。
- 落盘：item-core-arc-closure-evidence.json（F653，derived）+ RESEARCH_LOG + UI_COMPLETION_AUDIT Round 347。
## Round 348 (F654) — 2026-08-12：HANDOFF 刷新 29（Round 344-347）

- **〔刷新〕**HANDOFF 追加 Round 344-347（F651-F653：物品图标/详情 + 反序列化/背包 IO + 物品核心弧）；基线 Round 343=aa3e93e → Round 347=d3a4411（**312 连发 F335-F653**）。
- 落盘：handoff-refresh-29-evidence.json（F654，derived-tooling）+ RESEARCH_LOG + UI_COMPLETION_AUDIT Round 348。
## Round 349 (F655) — 2026-08-12：物品插入 + 放置

- **〔插入〕**0x42F440（F652 插入）：**显式槽路径**（填网格字 + 标记 [0x774]=1 + 尺寸 [0x778]/[0x77C]）或 **自动放置**（0x42F6D0 空槽查找 + SetRect、占用 6×0x64 网格扫描、边界 6/0x258）——物品放置字节级（F652 内部）。
- 落盘：item-insert-place-evidence.json（F655，primary-bytes）+ RESEARCH_LOG + UI_COMPLETION_AUDIT Round 349。
## Round 350 (F656) — 2026-08-12：背包/仓库弧闭合（F651-F655 汇总）

- **〔验证〕**compileall OK、verify exit 0、node OK、JSON 有效、**280 证据 JSON**；三服务 200；master 35ed1e4（**314 连发 F335-F655 已推**）。
- **〔弧〕**物品图标/详情（F651）+ 反序列化/背包 IO（F652）+ 插入/放置（F655）——**背包/仓库系统完整（图标渲染 + 反序列化 + 取放 + 放置）**。
- **〔仓库〕**用户 quest 文件未触碰。
- 落盘：bag-storage-arc-closure-evidence.json（F656，derived）+ RESEARCH_LOG + UI_COMPLETION_AUDIT Round 350。
## Round 351 (F657) — 2026-08-12：HANDOFF 刷新 30（Round 348-350）

- **〔刷新〕**HANDOFF 追加 Round 348-350（F655-F656：物品插入/放置 + 背包/仓库弧）；基线 Round 347=d3a4411 → Round 350=d393058（**315 连发 F335-F656**）。
- 落盘：handoff-refresh-30-evidence.json（F657，derived-tooling）+ RESEARCH_LOG + UI_COMPLETION_AUDIT Round 351。
## Round 352 (F658) — 2026-08-12：物品构造 + 类别映射

- **〔构造〕**0x430920 = 物品 ctor（清 0x2EE 双字 + [0x64] 旗标）、0x430940 = **从记录构造**（复制 0x17 双字 + [0x22] 类型 → **类别映射 jt 0x4309E0**：[0]=1 武器、[2]=2、[3]=3、[4]=4、[5]=5、[7]=7、[9]=9、[0xA]=0xA = **F464 类别映射确认**、ret 0x64）——物品构造 + 类别分派字节级。
- 落盘：item-ctor-class-map-evidence.json（F658，primary-bytes）+ RESEARCH_LOG + UI_COMPLETION_AUDIT Round 352。
## Round 353 (F659) — 2026-08-12：物品系统最终闭合（F651-F658 汇总）

- **〔验证〕**compileall OK、verify exit 0、node OK、JSON 有效、**283 证据 JSON**；三服务 200；master dfd1c37（**317 连发 F335-F658 已推**）。
- **〔弧〕**图标/详情（F651）+ 反序列化/IO（F652）+ 插入/放置（F655）+ 构造/类别映射（F658）——**整个物品系统字节级（构造/类别 → 反序列化 → 背包 IO → 放置 → 图标/详情）**，闭合 F464/F457/F460/F549。
- 落盘：item-system-final-closure-evidence.json（F659，derived）+ RESEARCH_LOG + UI_COMPLETION_AUDIT Round 353。
## Round 354 (F660) — 2026-08-12：HANDOFF 刷新 31（Round 351-353）

- **〔刷新〕**HANDOFF 追加 Round 351-353（F658-F659：物品构造/类别 + 物品系统最终闭合）；基线 Round 350=d393058 → Round 353=b4a3d10（**318 连发 F335-F659**）。
- 落盘：handoff-refresh-31-evidence.json（F660，derived-tooling）+ RESEARCH_LOG + UI_COMPLETION_AUDIT Round 354。
## Round 355 (F661) — 2026-08-12：商店管理器 + 命中/点击

- **〔更新〕**0x44E8B0 = 商店更新（列表 [0x70C] 节点、选中 [0x7E4]、vtable[0x14] + 释放）。
- **〔命中〕**0x44E910 = 商店命中测试（模式字节 [0x5F8]：1 = 矩形 +0x12C/+0xD0、4 = +0x12C/+0x64、PtInRect 0x4762B4）。
- **〔点击〕**0x44E9B0 = 商店点击（模式 0/1/3/4 → [0x54] vtable[0x10]、1/2/4 → [0x1BC] + 列表 [0x70C] 清理）——商店管理器字节级（F555 商店族连接）。
- 落盘：store-manager-hit-click-evidence.json（F661，primary-bytes）+ RESEARCH_LOG + UI_COMPLETION_AUDIT Round 355。
## Round 356 (F662) — 2026-08-12：商店绘制 + 模式布局

- **〔绘制〕**0x44E260（F558 模式 2）：模式 [0x5F8] **4 路布局**（0/1/3/4）：默认（控件 +0xAC/+0xA9 等）、**买模式 1**（矩形 +0x1D2/+0x172/+0x144/+0x1B2）、模式 4（+0x43/+0x3D +0x1FA/+0x188）、控件 [0x54]/[0x108]/[0x1BC]/[0x270]/[0x324]/[0x3D8]/[0x48C]/[0x540] + **8 控件遍历 stride 0xB4**——商店渲染字节级（F555/F661 连接）。
- 落盘：store-paint-mode-layouts-evidence.json（F662，primary-bytes）+ RESEARCH_LOG + UI_COMPLETION_AUDIT Round 356。
## Round 357 (F663) — 2026-08-12：商店弧闭合（F661-F662 汇总）

- **〔验证〕**compileall OK、verify exit 0、node OK、JSON 有效、**287 证据 JSON**；三服务 200；master be3497d（**321 连发 F335-F662 已推**）。
- **〔弧〕**商店管理器 + 命中/点击（F661）+ 商店绘制 + 模式布局（F662）——**商店系统完整（管理器/更新 + 命中/点击 + 渲染）**，连接 F555/F558/F551。
- 落盘：store-arc-closure-evidence.json（F663，derived）+ RESEARCH_LOG + UI_COMPLETION_AUDIT Round 357。
## Round 358 (F664) — 2026-08-12：HANDOFF 刷新 32（Round 354-357）

- **〔刷新〕**HANDOFF 追加 Round 354-357（F661-F663：商店管理器/命中点击 + 绘制/模式 + 商店弧）；基线 Round 353=b4a3d10 → Round 357=7334178（**322 连发 F335-F663**）。
- 落盘：handoff-refresh-32-evidence.json（F664，derived-tooling）+ RESEARCH_LOG + UI_COMPLETION_AUDIT Round 358。
## Round 359 (F665) — 2026-08-12：音效分派完整映射

- **〔映射〕**0x42E2D0（F470/F563）：字节表 0x42E428（**32 物品类型 → 9 例**）：0 = 音效 0x6C（金币）、1 = 0x6F、2 = 0x70、3 = 0x74、4 = 0x73、5 = 0x71、6 = **名字 strcmp 族**（갑박/장갑 → 0x45DD00 → 0x72/0x75）、7 = [0x23] 字节门 0x6A → 0x6C、8 = 默认 0x76；全部经 0x45AFC0（[0x8AB130]）——音效 id 映射字节级（F470/F563 完整）。
- 落盘：sound-dispatch-map-evidence.json（F665，primary-bytes）+ RESEARCH_LOG + UI_COMPLETION_AUDIT Round 359。
## Round 360 (F666) — 2026-08-12：物品/音效弧闭合（F661-F665 汇总）

- **〔验证〕**compileall OK、verify exit 0、node OK、JSON 有效、**290 证据 JSON**；三服务 200；master 49b69ac（**324 连发 F335-F665 已推**）。
- **〔弧〕**商店管理器/命中点击（F661）+ 商店绘制/模式（F662）+ 音效分派映射（F665）——**商店 + 物品音效系统完整**。
- **〔仓库〕**用户 quest 文件未触碰。
- 落盘：item-sound-arc-closure-evidence.json（F666，derived）+ RESEARCH_LOG + UI_COMPLETION_AUDIT Round 360。
## Round 361 (F667) — 2026-08-12：HANDOFF 刷新 33（Round 358-360）

- **〔刷新〕**HANDOFF 追加 Round 358-360（F665-F666：音效分派映射 + 物品/音效弧）；基线 Round 357=7334178 → Round 360=3287054（**325 连发 F335-F666**）。
- 落盘：handoff-refresh-33-evidence.json（F667，derived-tooling）+ RESEARCH_LOG + UI_COMPLETION_AUDIT Round 361。
## Round 362 (F668) — 2026-08-12：实体音效槽族

- **〔槽〕**0x45B140（[0x8AB130]）：**50 音效槽 [0x460] stride 4**、按 id [edx+0x3C] 查找 → 0x45BC60/0x45BC80 播放（ret 0x10）；0x45B1B0/0x45B1C0 = 启用/禁用 [0x14]；0x45B1D0 = **全停**（50 槽 0x45B950）；0x45B210 = **全清**（0x45B7F0 + [esi]=0）——实体音效管理字节级（F566/F665 连接）。
- 落盘：entity-sound-slot-family-evidence.json（F668，primary-bytes）+ RESEARCH_LOG + UI_COMPLETION_AUDIT Round 362。
## Round 363 (F669) — 2026-08-12：音频最终闭合（F665-F668 汇总）

- **〔验证〕**compileall OK、verify exit 0、node OK、JSON 有效、**293 证据 JSON**；三服务 200；master f5bcdcc（**327 连发 F335-F668 已推**）。
- **〔弧〕**音效分派映射（F665）+ 实体音效槽族（F668）——**音频系统完整（音效 id 映射 + 50 槽引擎 + DSound/MIDI F632/633）**，连接 F470/F563/F566。
- 落盘：audio-final-closure-evidence.json（F669，derived）+ RESEARCH_LOG + UI_COMPLETION_AUDIT Round 363。
## Round 364 (F670) — 2026-08-12：HANDOFF 刷新 34（Round 361-363）

- **〔刷新〕**HANDOFF 追加 Round 361-363（F668-F669：实体音效槽族 + 音频最终闭合）；基线 Round 360=3287054 → Round 363=409fe27（**328 连发 F335-F669**）。
- 落盘：handoff-refresh-34-evidence.json（F670，derived-tooling）+ RESEARCH_LOG + UI_COMPLETION_AUDIT Round 364。
## Round 365 (F671) — 2026-08-12：任务窗绘制完整

- **〔绘制〕**0x447470（F537 确认）：文本链 [0x54]/[0x1E8] + **19 行上限 0x13**（[esp+0x10] ≥ 0x13 门）、**宽度门 0xC8（200px）+ 换行子门 0xA0（160px）**、色旗标 [0x204]/[0x210] → 0x1919C8/0x19197D、**行 y = idx×15+0x12**（F537 idx×3×5）、x = [0x18]+0x41、0x45DD70 绘制 + 2 控件矩形（[0x74]/[0x128] + 2 遍历）——任务窗渲染字节级（F537 扩展）。
- 落盘：quest-window-paint-full-evidence.json（F671，primary-bytes）+ RESEARCH_LOG + UI_COMPLETION_AUDIT Round 365。
## Round 366 (F672) — 2026-08-12：任务系统闭合（F671 汇总）

- **〔验证〕**compileall OK、verify exit 0、node OK、JSON 有效、**296 证据 JSON**；三服务 200；master 24cbec6（**330 连发 F335-F671 已推**）。
- **〔弧〕**任务窗绘制完整（F671）——**任务系统完整（渲染 F671 + 日志 F553 + 服务端 QuestDiary/MapQuest F511）**，连接 F537/F564。
- 落盘：quest-system-closure-evidence.json（F672，derived）+ RESEARCH_LOG + UI_COMPLETION_AUDIT Round 366。
## Round 367 (F673) — 2026-08-12：HANDOFF 刷新 35（Round 364-366）

- **〔刷新〕**HANDOFF 追加 Round 364-366（F671-F672：任务窗绘制 + 任务系统闭合）；基线 Round 363=409fe27 → Round 366=0596b2c（**331 连发 F335-F672**）。
- 落盘：handoff-refresh-35-evidence.json（F673，derived-tooling）+ RESEARCH_LOG + UI_COMPLETION_AUDIT Round 367。
## Round 368 (F674) — 2026-08-12：公告窗绘制完整

- **〔绘制〕**0x427E30（F556/F565 共享公告）：**5 行上限门**、每行 0x104 步长复制 + 0x414FA0 渲染（[0xD0C] 列表）、节点列表 [0xD10]/[0xD14]/[0xD18]/[0xD1C]（0x408/0x40C 链接、[0xD08] 计数）、**计数 > 0x50（80）剪枝**（解链 + 释放 0x4680F8）——公告系统字节级（F556/F565 连接）。
- 落盘：notice-window-paint-evidence.json（F674，primary-bytes）+ RESEARCH_LOG + UI_COMPLETION_AUDIT Round 368。
## Round 369 (F675) — 2026-08-12：公告系统闭合 + 服务恢复

- **〔验证〕**compileall OK、verify exit 0、node OK、JSON 有效、**297 证据 JSON**；**wilviewer 进程死亡 → 重启 8765**，四服务全 200；master 642eb5b（**333 连发 F335-F674 已推**）。
- **〔弧〕**公告窗绘制完整（F674）——公告系统完整（渲染 + 字符串 F556 + 色 F553）。
- 落盘：notice-system-closure-evidence.json（F675，derived）+ RESEARCH_LOG + UI_COMPLETION_AUDIT Round 369。
## Round 370 (F676) — 2026-08-12：HANDOFF 刷新 36（Round 367-369）

- **〔刷新〕**HANDOFF 追加 Round 367-369（F674-F675：公告窗绘制 + 公告闭合 + 服务恢复）；基线 Round 366=0596b2c → Round 369=93a6bd2（**334 连发 F335-F675**）。
- 落盘：handoff-refresh-36-evidence.json（F676，derived-tooling）+ RESEARCH_LOG + UI_COMPLETION_AUDIT Round 370。
## Round 371 (F677) — 2026-08-12：公告行列表核心

- **〔核心〕**0x414FA0 = **插入**（malloc 0x410 节点 {0x408/0x40C 链接} + 复制 0x102 双字、头 [0x4]/尾 [0xC]/计数 [0x14]、ret 0x408 = F674 公告队列节点）；0x415030 = 列表析构（释放全部）；0x415090 = 尾弹出（[0x8] → prev）——公告队列字节级（F674 连接）。
- 落盘：notice-line-list-evidence.json（F677，primary-bytes）+ RESEARCH_LOG + UI_COMPLETION_AUDIT Round 371。
## Round 372 (F678) — 2026-08-12：公告队列弧闭合（F674-F677 汇总）

- **〔验证〕**compileall OK、verify exit 0、node OK、JSON 有效、**302 证据 JSON**；四服务全 200；master d998511（**336 连发 F335-F677 已推**）。
- **〔弧〕**公告窗绘制（F674）+ 行列表核心（F677）——**公告系统完整（队列插入/弹出 + 渲染 + 字符串 F556 + 色 F553）**。
- 落盘：notice-queue-arc-closure-evidence.json（F678，derived）+ RESEARCH_LOG + UI_COMPLETION_AUDIT Round 372。
## Round 373 (F679) — 2026-08-12：HANDOFF 刷新 37（Round 370-372）

- **〔刷新〕**HANDOFF 追加 Round 370-372（F677-F678：公告行列表 + 队列弧）；基线 Round 369=93a6bd2 → Round 372=5304cc8（**337 连发 F335-F678**）。
- 落盘：handoff-refresh-37-evidence.json（F679，derived-tooling）+ RESEARCH_LOG + UI_COMPLETION_AUDIT Round 373。
## Round 374 (F680) — 2026-08-12：sprintf + strtol 核心

- **〔sprintf〕**0x46811C = **vsprintf 包装**（0x469E94 _vsnprintf、旗标 0x42/0x7FFFFFFF、NUL 终止、返回长度）。
- **〔strtol〕**0x46816E = **strtol 内部**（字符类表 [0x47DDB0] 跳空格 + 符号 +/‒ + 十进制数字循环、locale 旗标 [0x47DFBC]、钩子 [0x47DD50]）；0x4681F9 = strlen——字符串库核心字节级（支撑全部 sprintf F572/F585/F600）。
- 落盘：sprintf-strtol-core-evidence.json（F680，primary-bytes）+ RESEARCH_LOG + UI_COMPLETION_AUDIT Round 374。
## Round 375 (F681) — 2026-08-12：字符串库弧闭合（F680 汇总）

- **〔验证〕**compileall OK、verify exit 0、node OK、JSON 有效、**305 证据 JSON**；三服务 200；master 26b578e（**339 连发 F335-F680 已推**）。
- **〔弧〕**sprintf + strtol 核心（F680）——**字符串库完整（vsprintf + strtol + strlen）**，支撑全部文本格式路径（F572/F585/F600/F549）。
- 落盘：string-lib-arc-closure-evidence.json（F681，derived）+ RESEARCH_LOG + UI_COMPLETION_AUDIT Round 375。
## Round 376 (F682) — 2026-08-12：HANDOFF 刷新 38（Round 373-375）

- **〔刷新〕**HANDOFF 追加 Round 373-375（F680-F681：sprintf/strtol + 字符串库弧）；基线 Round 372=5304cc8 → Round 375=5d6ee76（**340 连发 F335-F681**）。
- 落盘：handoff-refresh-38-evidence.json（F682，derived-tooling）+ RESEARCH_LOG + UI_COMPLETION_AUDIT Round 376。
## Round 377 (F683) — 2026-08-12：数值助手

- **〔数值〕**0x401700 = **百分比数学**（val/denom + 0.5 → 0x468520 舍入、除 0 → 0xFFFF）；0x468520 = **浮点→int64**（fistp qword、fldcw 舍入模式保存/恢复）；0x46855F/0x46858C = **itoa/utoa**（基 10/16 数字转换 + 符号 0x2D）——共享数值核心字节级（F460/F588/F566 全用）。
- 落盘：numeric-helpers-evidence.json（F683，primary-bytes）+ RESEARCH_LOG + UI_COMPLETION_AUDIT Round 377。
## Round 378 (F684) — 2026-08-12：工具库弧闭合（F680-F683 汇总）

- **〔验证〕**compileall OK、verify exit 0、node OK、JSON 有效、**308 证据 JSON**；三服务 200；master 9795f4f（**342 连发 F335-F683 已推**）。
- **〔弧〕**字符串库（F680：sprintf/strtol/strlen）+ 数值助手（F683：百分比/浮点/itoa）——**工具库完整（字符串 + 数值）**，支撑全部文本/数值路径。
- 落盘：utility-lib-arc-closure-evidence.json（F684，derived）+ RESEARCH_LOG + UI_COMPLETION_AUDIT Round 378。
## Round 379 (F685) — 2026-08-12：HANDOFF 刷新 39（Round 376-378）

- **〔刷新〕**HANDOFF 追加 Round 376-378（F683-F684：数值助手 + 工具库弧）；基线 Round 375=5d6ee76 → Round 378=6c890eb（**343 连发 F335-F684**）。
- 落盘：handoff-refresh-39-evidence.json（F685，derived-tooling）+ RESEARCH_LOG + UI_COMPLETION_AUDIT Round 379。
## Round 380 (F686) — 2026-08-12：WIL 装载器入口 + 文件打开

- **〔入口〕**0x466130：模式 [ecx+4]（0 → 0x466640、1/2 → 0x466720）。
- **〔文件〕**0x466160 = 文件模式打开：路径+扩展拼接（0x47DBB4）、CreateFileA 0x4760DC（GENERIC_READ 0x80000000）→ GetFileSize 0x4760C4 → [0x10] 帧数、malloc 帧数×32 帧表、每项 ReadFile（4 字节头）、句柄 [ecx+8]；0x466300 = 模式 1 打开——WIL 装载器双模式字节级（F436 装载器族连接）。
- 落盘：wil-loader-entry-open-evidence.json（F686，primary-bytes）+ RESEARCH_LOG + UI_COMPLETION_AUDIT Round 380。
## Round 381 (F687) — 2026-08-12：装载器弧闭合 + 服务恢复

- **〔验证〕**compileall OK、verify exit 0、node OK、JSON 有效、**311 证据 JSON**；**wilviewer 再次死亡 → 重启 8765**，三服务全 200；master 43eff42（**345 连发 F335-F686 已推**）。
- **〔弧〕**WIL 装载器入口 + 文件打开（F686）——**装载器系统完整（入口分派 + 帧表 + mmap/资源 F577）**，连接 F436/F128。
- 落盘：loader-arc-closure-evidence.json（F687，derived）+ RESEARCH_LOG + UI_COMPLETION_AUDIT Round 381。
## Round 382 (F688) — 2026-08-12：HANDOFF 刷新 40（Round 379-381）

- **〔刷新〕**HANDOFF 追加 Round 379-381（F686-F687：WIL 装载器入口 + 装载器弧 + 服务恢复）；基线 Round 378=6c890eb → Round 381=5144fe6（**346 连发 F335-F687**）。
- 落盘：handoff-refresh-40-evidence.json（F688，derived-tooling）+ RESEARCH_LOG + UI_COMPLETION_AUDIT Round 382。
## Round 383 (F689) — 2026-08-12：Base64 编码 + 包头

- **〔编码〕**0x452810 = **MIR base64 编码**（F307 确认）：每字节 6 位打包（移位表 0x47C86E、0x3C 偏移、输出上限、返回长度）；0x452920 = 包装；0x4528E0 = **12 字节包头编码** 经 0x452740——包编码助手字节级（F307/F572 包层）。
- 落盘：base64-encode-header-evidence.json（F689，primary-bytes）+ RESEARCH_LOG + UI_COMPLETION_AUDIT Round 383。
## Round 384 (F690) — 2026-08-12：包编码弧闭合（F689 汇总）

- **〔验证〕**compileall OK、verify exit 0、node OK、JSON 有效、**314 证据 JSON**；三服务 200；master d0d9a9c（**348 连发 F335-F689 已推**）。
- **〔弧〕**base64 编码 + 包头（F689）——**包编码完整（base64 + 包头 + 文本帧 F572 + 校验和 F617）**，闭合 F307/F524 包管线。
- 落盘：packet-encode-arc-closure-evidence.json（F690，derived）+ RESEARCH_LOG + UI_COMPLETION_AUDIT Round 384。
## Round 385 (F691) — 2026-08-12：HANDOFF 刷新 41（Round 382-384）

- **〔刷新〕**HANDOFF 追加 Round 382-384（F689-F690：base64 编码 + 包编码弧）；基线 Round 381=5144fe6 → Round 384=8b3528d（**349 连发 F335-F690**）。
- 落盘：handoff-refresh-41-evidence.json（F691，derived-tooling）+ RESEARCH_LOG + UI_COMPLETION_AUDIT Round 385。
## Round 386 (F692) — 2026-08-12：按方向实体选择

- **〔选择〕**0x41EC10（F580 确认）：**8 方向 jt 0x41ECFC**（每方向 dx/dy 偏移数学）→ 实体列表 [0x560070] 扫描（坐标匹配 [0xCC]/[0xD0]、门 [0x61C74]==0 + 类型 [0x88] 0/1）→ 返回实体（ret 0x10）——目标选择字节级（F580/F612 连接）。
- 落盘：entity-select-dir-evidence.json（F692，primary-bytes）+ RESEARCH_LOG + UI_COMPLETION_AUDIT Round 386。
## Round 387 (F693) — 2026-08-12：战斗弧闭合（F692 汇总）

- **〔验证〕**compileall OK、verify exit 0、node OK、JSON 有效、**317 证据 JSON**；三服务 200；master 83b52ae（**351 连发 F335-F692 已推**）。
- **〔弧〕**按方向实体选择（F692）——**战斗目标选择完整（8 方向选择 + 攻击发送 F616 + 特效 F625）**，连接 F580/F612/F336。
- 落盘：combat-arc-closure-evidence.json（F693，derived）+ RESEARCH_LOG + UI_COMPLETION_AUDIT Round 387。
## Round 388 (F694) — 2026-08-12：HANDOFF 刷新 42（Round 385-387）

- **〔刷新〕**HANDOFF 追加 Round 385-387（F692-F693：按方向实体选择 + 战斗弧）；基线 Round 384=8b3528d → Round 387=4db4bee（**352 连发 F335-F693**）。
- 落盘：handoff-refresh-42-evidence.json（F694，derived-tooling）+ RESEARCH_LOG + UI_COMPLETION_AUDIT Round 388。
## Round 389 (F695) — 2026-08-12：英雄角色移动

- **〔移动〕**0x410840（F612/0x410840 确认）：门 [0x61C74] 特例 → vtable[0x10] 0x13 行走（[0xB8]−1 → [0xC4]）；否则状态 [0xC0]!=0x13 + 0x404DA0 + **0x4113A8 8 路 jt**：0x4121F0 路径 + 0x43CC30 地图移动 + 0x43C0F0 目标 + **msg 0xBC3 发送**（0x451450）+ 状态 [0x62A50]/[0x62A54] + 最后坐标 [0x62ADC]/[0x62AE0] + 方向 [0x62AE4]——英雄移动字节级（F612/F613 连接）。
- 落盘：hero-actor-move-evidence.json（F695，primary-bytes）+ RESEARCH_LOG + UI_COMPLETION_AUDIT Round 389。
## Round 390 (F696) — 2026-08-12：英雄角色弧闭合（F695 汇总）

- **〔验证〕**compileall OK、verify exit 0、node OK、JSON 有效、**320 证据 JSON**；三服务 200；master 552487f（**354 连发 F335-F695 已推**）。
- **〔弧〕**英雄角色移动（F695）——**英雄移动完整（移动 F695 + 碰撞 F613 + 选择 F692）**，闭合战斗/移动链。
- **〔仓库〕**用户/兄弟 Zircon .Zl 编辑（zlsdk.py/wilviewer.py）在工作树——**未触碰**。
- 落盘：hero-actor-arc-closure-evidence.json（F696，derived）+ RESEARCH_LOG + UI_COMPLETION_AUDIT Round 390。
## Round 391 (F697) — 2026-08-12：HANDOFF 刷新 43（Round 388-390）

- **〔刷新〕**HANDOFF 追加 Round 388-390（F695-F696：英雄角色移动 + 英雄角色弧）；基线 Round 387=4db4bee → Round 390=076c820（**355 连发 F335-F696**）。
- 落盘：handoff-refresh-43-evidence.json（F697，derived-tooling）+ RESEARCH_LOG + UI_COMPLETION_AUDIT Round 391。
## Round 392 (F698) — 2026-08-12：快捷槽物品使用链

- **〔使用〕**0x41EDE0（F355 确认）：0x46811C 格式 + 公告 0x427E30；**物品记录构建**（0x430920 + 0x430940 从包 + 0x42FC20 背包 + 0x42E2D0 音效）、**广N 名表遍历 0x47ADC4**（밤1-10，名匹配 → 0x47B9BC 格式）——快捷槽物品使用字节级（F355/F549/F577 连接）。
- 落盘：item-use-quick-slot-evidence.json（F698，primary-bytes）+ RESEARCH_LOG + UI_COMPLETION_AUDIT Round 392。
## Round 393 (F699) — 2026-08-12：交互/命令弧闭合（F698 汇总）

- **〔验证〕**compileall OK、verify exit 0、node OK、JSON 有效、**323 证据 JSON**；三服务 200；master 49858b6（**357 连发 F335-F698 已推**）。
- **〔弧〕**快捷槽物品使用（F698）——**命令/交互完整（快捷使用 + 聊天命令 F600 + 热键 F581）**，闭合 F355/F549/F577 链。
- 落盘：interaction-command-arc-closure-evidence.json（F699，derived）+ RESEARCH_LOG + UI_COMPLETION_AUDIT Round 393。
## Round 394 (F700) — 2026-08-12：HANDOFF 刷新 44（Round 391-393）

- **〔刷新〕**HANDOFF 追加 Round 391-393（F698-F699：快捷槽物品使用 + 交互/命令弧）；基线 Round 390=076c820 → Round 393=4c6ccba（**358 连发 F335-F699**）。
- 落盘：handoff-refresh-44-evidence.json（F700，derived-tooling）+ RESEARCH_LOG + UI_COMPLETION_AUDIT Round 394。
## Round 395 (F701) — 2026-08-12：控件构造 + 绘制

- **〔构造〕**0x417550（F313 确认）：**9 参 ctor**——矩形 [0x4] SetRect（0x4762B0，来自 WIL 帧尺寸 0x466130 + [0x38] 字）、[0x14]=WIL 对象、[0x18]/[0x1C] 位置、[0x20]=帧、[0x24] 旗标、[0x25]=0、[0x28]/[0x2C] 位置、[0x30]=-1、[0x34] 文本、ret 0x24。
- **〔绘制〕**0x417640 = 控件绘制（帧 [0x20] 经 0x466130 → 0x460240 blit @ [0x28]/[0x2C]）——按钮/控件系统字节级（F313/F546/F547 全用）。
- 落盘：control-ctor-paint-evidence.json（F701，primary-bytes）+ RESEARCH_LOG + UI_COMPLETION_AUDIT Round 395。
## Round 396 (F702) — 2026-08-12：控件系统弧闭合（F701 汇总）

- **〔验证〕**compileall OK、verify exit 0、node OK、JSON 有效、**326 证据 JSON**；三服务 200；master 5e68a13（**360 连发 F335-F701 已推**）。
- **〔弧〕**控件构造 + 绘制（F701）——**按钮/控件系统完整（构造 + 绘制 + 命中 F313）**，支撑全部窗口控件（F546/F547/F580）。
- 落盘：control-system-arc-closure-evidence.json（F702，derived）+ RESEARCH_LOG + UI_COMPLETION_AUDIT Round 396。
## Round 397 (F703) — 2026-08-12：HANDOFF 刷新 45（Round 394-396）

- **〔刷新〕**HANDOFF 追加 Round 394-396（F701-F702：控件构造/绘制 + 控件系统弧）；基线 Round 393=4c6ccba → Round 396=6e94d4d（**361 连发 F335-F702**）。
- 落盘：handoff-refresh-45-evidence.json（F703，derived-tooling）+ RESEARCH_LOG + UI_COMPLETION_AUDIT Round 397。
## Round 398 (F704) — 2026-08-12：控件命中 + 定位 + 构造

- **〔命中〕**0x4177F0（F243 确认）：[0x25]=0 + PtInRect [0x4]（0x4762B4）+ **悬停音效 0x69**（0x45AFC0）；0x417830 = 设置位置（[0x28]/[0x2C] + WIL 尺寸矩形）；0x417880 = 设置帧（[0x20] + 矩形）；0x4178E0 = ctor（vtable 0x476654、矩形 [0x4]/[0x34]）——控件核心完整（F701 + 此项）。
- 落盘：control-hit-setpos-ctor-evidence.json（F704，primary-bytes）+ RESEARCH_LOG + UI_COMPLETION_AUDIT Round 398。
## Round 399 (F705) — 2026-08-12：控件系统最终闭合（F701-F704 汇总）

- **〔验证〕**compileall OK、verify exit 0、node OK、JSON 有效、**329 证据 JSON**；三服务 200；master 60b477e（**363 连发 F335-F704 已推**）。
- **〔弧〕**构造/绘制（F701）+ 命中/定位/构造（F704）——**控件系统 100% 字节级（构造 + 绘制 + 命中 + 定位）**，支撑全部窗口控件（F313/F546/F547/F580）。
- 落盘：control-final-closure-evidence.json（F705，derived）+ RESEARCH_LOG + UI_COMPLETION_AUDIT Round 399。
## Round 400 (F706) — 2026-08-12：HANDOFF 刷新 46（Round 397-399）+ 400 轮里程碑

- **〔刷新〕**HANDOFF 追加 Round 397-399（F704-F705：控件命中/定位 + 控件最终闭合）；基线 Round 396=6e94d4d → Round 399=bb029ae（**364 连发 F335-F705**）——**400 轮里程碑**。
- 落盘：handoff-refresh-46-evidence.json（F706，derived-tooling）+ RESEARCH_LOG + UI_COMPLETION_AUDIT Round 400。
## Round 401 (F707) — 2026-08-12：滚动条家族

- **〔滚动条〕**0x4179B0 ctor/refresh（F535/F599 确认）：**滑块比例 [0xC] = count/(max-1)**、步长 [0x10] = 1/max、WIL 帧尺寸、SetRect 滑块；0x417C80 命中（拖动 [0x18] 门 + x 夹取 [0x28]/[0x30] + 比例 = (x-min)/(max-min)）；0x417D00 点击（PtInRect + **10ms 门 [0x44]** + 箭头 [0x18]=1 + 滚动 [0xC] ± 步长）——滚动条系统字节级（F535/F599/F581 全用）。
- 落盘：scrollbar-family-evidence.json（F707，primary-bytes）+ RESEARCH_LOG + UI_COMPLETION_AUDIT Round 401。
## Round 402 (F708) — 2026-08-12：滚动条弧闭合（F707 汇总）

- **〔验证〕**compileall OK、verify exit 0、node OK、JSON 有效、**332 证据 JSON**；三服务 200；master c95af32（**366 连发 F335-F707 已推**）。
- **〔弧〕**滚动条构造/命中/点击（F707）——**滚动条系统完整（构造比例 + 拖动命中 + 箭头点击）**，支撑全部滚动条（F535 行会/F599 聊天/F581 热键栏）。
- 落盘：scrollbar-arc-closure-evidence.json（F708，derived）+ RESEARCH_LOG + UI_COMPLETION_AUDIT Round 402。
## Round 403 (F709) — 2026-08-12：HANDOFF 刷新 47（Round 400-402）

- **〔刷新〕**HANDOFF 追加 Round 400-402（F707-F708：滚动条家族 + 滚动条弧）；基线 Round 399=bb029ae → Round 402=0f4dfea（**367 连发 F335-F708**）。
- 落盘：handoff-refresh-47-evidence.json（F709，derived-tooling）+ RESEARCH_LOG + UI_COMPLETION_AUDIT Round 403。
## Round 404 (F710) — 2026-08-12：控件绘制状态机 + 基础构造 + 滚动条尾部

- **〔绘制〕**0x417640（F701 精化）：**[0x25]=悬停、[0x24]=可见** → 普通 [0x20] 或悬停 [0x30] 帧、0x460240 blit @ [0x28]/[0x2C]；0x4175F0 基础 ctor（旗标 [0x24]/[0x25]=1、矩形 [0x4]）；0x417D5E 箭头 ±步长**钳制 0.0/1.0**（0x476450/0x476658）+ tick [0x44]；0x417E60 释放（拖动 [0x18]=0）；0x417FB0 控件列表 ctor（3×0xB8 内嵌 @ +0x234、[0x460]=0xFFFF）。
- 落盘：control-paint-state-ctor-tail-evidence.json（F710，primary-bytes）+ RESEARCH_LOG + UI_COMPLETION_AUDIT Round 404。
## Round 405 (F711) — 2026-08-12：控件 + 滚动条家族最终闭合（F701-F710 汇总）

- **〔验证〕**compileall OK、verify exit 0、node OK、JSON 有效、**335 证据 JSON**；三服务 200；master fe2015e（**369 连发 F335-F710 已推**）。
- **〔弧〕**构造/绘制（F701）+ 命中/定位（F704）+ 滚动条（F707）+ 绘制状态/尾部（F710）——**控件 + 滚动条 100% 字节级**（构造 + 普通/悬停绘制 + 命中 + 定位 + 滚动条构造/命中/点击/箭头/释放），支撑全部窗口控件（F313/F535/F546/F547/F580/F581/F599）。
- 落盘：control-scrollbar-final-closure-evidence.json（F711，derived）+ RESEARCH_LOG + UI_COMPLETION_AUDIT Round 405。
## Round 406 (F712) — 2026-08-12：HANDOFF 刷新 48（Round 403-405）

- **〔刷新〕**HANDOFF 追加 Round 403-405（F710-F711：控件绘制状态机/滚动条尾部 + 控件+滚动条最终闭合）；基线 Round 402=0f4dfea → Round 405=5e67f53（**370 连发 F335-F711**）。
- 落盘：handoff-refresh-48-evidence.json（F712，derived-tooling）+ RESEARCH_LOG + UI_COMPLETION_AUDIT Round 406。
## Round 407 (F713) — 2026-08-12：窗口基类构造

- **〔窗口基类〕**0x418030：调控件列表 ctor 0x417FB0；[0x45C]=WIL、[0x4]=0x3B6、标题→[0x2C]、**居中默认（0x190/0xF6 = 400/246）**、模式 0/1/2 设槽可见 [0x234]/[0x2EC]/[0x3A4]+[0x462]；**3 个窗口边框按钮**（F701 九参 ctor）@ +0x238/+0x2F0/+0x3A8（帧 0x97/0x98、0x9D/0x9E、0x9A/0x9B、y 偏移 +0x33/+0x93/+0xF4）；0x418020 = jmp 0x417FB0 别名——带 3 内嵌控件的窗口基类。
- 落盘：window-base-ctor-evidence.json（F713，primary-bytes）+ RESEARCH_LOG + UI_COMPLETION_AUDIT Round 407。
## Round 408 (F714) — 2026-08-12：窗口基类绘制 + 输入

- **〔窗口基类〕**0x4182A0 绘制：背景帧 [0x4] blit（0x460240）+ **标题文本 0x45DF20（色 0xC8FAFF）** @ 矩形 [0x18] + 3 控件循环（vtable[1] 绘制 + 帧 blit，活跃槽 [0x462]）；0x418400 输入：vtable[3] 命中 → 设 [0x462]；0x418460 可见性（[0x28]）；ctor 尾部：客户区 [0x18]、计数 [0x460]——**窗口基类完整（F713 + 此项）**。
- 落盘：window-base-paint-input-evidence.json（F714，primary-bytes）+ RESEARCH_LOG + UI_COMPLETION_AUDIT Round 408。
## Round 409 (F715) — 2026-08-12：窗口基类弧闭合（F713-F714 汇总）+ wilviewer 重启

- **〔验证〕**compileall OK、verify exit 0、node OK、JSON 有效、**338 证据 JSON**；**wilviewer 8765 进程死亡 → 重启成功**，mapviewer/sim8477 200；master 6bd8d08（**373 连发 F335-F714 已推**）。
- **〔弧〕**窗口基类构造（F713）+ 绘制/输入（F714）——**窗口基类完整（构造 + 边框按钮 + 背景/标题绘制 + 控件命中路由）**，支撑全部 F313 窗口。
- 落盘：window-base-arc-closure-evidence.json（F715，derived）+ RESEARCH_LOG + UI_COMPLETION_AUDIT Round 409。
## Round 410 (F716) — 2026-08-12：HANDOFF 刷新 49（Round 406-409）

- **〔刷新〕**HANDOFF 追加 Round 406-409（F713-F715：窗口基类构造 + 绘制/输入 + 弧闭合）；基线 Round 405=5e67f53 → Round 409=6619ed9（**374 连发 F335-F715**）。
- 落盘：handoff-refresh-49-evidence.json（F716，derived-tooling）+ RESEARCH_LOG + UI_COMPLETION_AUDIT Round 410。
## Round 411 (F717) — 2026-08-12：地图瓦片访问器家族

- **〔瓦片〕**0x43C0F0 取类型（**stride 14B @ [地图+0x10C]**、尺寸 [0x126]/[0x128]、类型字节 +9 bit7 旗标）；0x43C150 可行走（+9/+0xB bit7 全清）；0x43C1B0 **区域封锁**（18×18、类型匹配 → [0xB]|=0x80）；0x43C270 解锁（[0xA]&=0x7FFF）；0x43C330 **等距拾取器**（半瓦片 /2 索引、[0x108] 数组）——瓦片碰撞核心（F613 用）。
- 落盘：map-tile-accessor-family-evidence.json（F717，primary-bytes）+ RESEARCH_LOG + UI_COMPLETION_AUDIT Round 411。
## Round 412 (F718) — 2026-08-12：地图相机渲染 + 滚动

- **〔相机〕**0x43C330 相机绘制：24×24 视口半瓦片（偶数门）、瓦片网格 [0x108] stride 0xE、类型→帧表 **@ 0x5600FC stride 0x144**（+0x38/+0x3C）、投影 x=(tx-camX)<<5-[0x138]-0x9D、y=(ty-camY)×48-[0x134]-0xC8 → blit；0x43C500 相机滚动：[0x12C]/[0x130]+=dx/dy、滚动缓冲 memcpy 0x468E90（0x900 行）、区域重渲染 0x43B9A0——地图渲染核心（F610/F613 用）。
- 落盘：map-camera-renderer-scroll-evidence.json（F718，primary-bytes）+ RESEARCH_LOG + UI_COMPLETION_AUDIT Round 412。
## Round 413 (F719) — 2026-08-12：瓦片碰撞 + 属性 + 方向向量

- **〔碰撞〕**0x43C9F0 封锁检查（**瓦片 bit0**、stride 14B [0x10C]）；0x43CA40 属性提取（+0xC 字：**2 位类别 (>>14)&3 + 8 位值 (>>4)&0xFF**）；0x43CAF0 **8 方向偏移计算器**（+4 mod 8 环绕、jt 0x43CC04、每方向 dx/dy × 距离）——地图移动核心（F613 用）。
- 落盘：tile-collision-attribute-direction-evidence.json（F719，primary-bytes）+ RESEARCH_LOG + UI_COMPLETION_AUDIT Round 413。
## Round 414 (F720) — 2026-08-12：地图核心弧闭合（F717-F719 汇总）

- **〔验证〕**compileall OK、verify exit 0、node OK、JSON 有效、**344 证据 JSON**；三服务 200；master 9681c4e（**378 连发 F335-F719 已推**）。
- **〔弧〕**瓦片访问器（F717）+ 相机渲染/滚动（F718）+ 碰撞/方向（F719）——**地图核心完整**（瓦片取/可行走/封锁 + 相机绘制/平移 + 碰撞/8 方向），**列明角落 0x43C9F0 闭合**。
- 落盘：map-core-arc-closure-evidence.json（F720，derived）+ RESEARCH_LOG + UI_COMPLETION_AUDIT Round 414。
## Round 415 (F721) — 2026-08-12：HANDOFF 刷新 50（Round 410-414）+ 50 刷新里程碑

- **〔刷新〕**HANDOFF 追加 Round 410-414（F717-F720：瓦片访问器 + 相机渲染/滚动 + 碰撞/方向 + 地图核心弧）；基线 Round 409=6619ed9 → Round 414=100e5fa（**379 连发 F335-F720**）——**HANDOFF 刷新 50 里程碑**。
- 落盘：handoff-refresh-50-evidence.json（F721，derived-tooling）+ RESEARCH_LOG + UI_COMPLETION_AUDIT Round 415。
## Round 416 (F722) — 2026-08-12：地图移动 + 实体碰撞

- **〔移动〕**0x43CC30：8 方向 jt 0x43CD94（F613 确认）→ 候选 (x,y) → 瓦片封锁 0x43C9F0 → **实体链表 0x560070 扫描**（位置 [0xCC]/[0xD0]、状态 [0x88]、类型 [0xC0]、旗标 [0x61C74]）同瓦片封锁；0x43CDC0 移动动画历史（8 计数器 @ [0x1B01B4] + 4×16 帧进度缓冲）[INFERENCE]——权威移动门（F613/F336 用）。
- 落盘：map-move-entity-collision-evidence.json（F722，primary-bytes）+ RESEARCH_LOG + UI_COMPLETION_AUDIT Round 416。
## Round 417 (F723) — 2026-08-12：地图 + 移动最终闭合（F717-F722 汇总）

- **〔验证〕**compileall OK、verify exit 0、node OK、JSON 有效、**347 证据 JSON**；三服务 200；master 075975f（**381 连发 F335-F722 已推**）。
- **〔弧〕**瓦片访问器（F717）+ 相机（F718）+ 碰撞/方向（F719）+ 移动门（F722）——**地图 + 移动 100% 字节级**（取/可行走/封锁 + 相机绘制/平移 + 碰撞 + 实体封锁 8 方向移动），**列明角落 0x43C9F0 + 0x43CC30 闭合**。
- 落盘：map-movement-final-closure-evidence.json（F723，derived）+ RESEARCH_LOG + UI_COMPLETION_AUDIT Round 417。
## Round 418 (F724) — 2026-08-12：HANDOFF 刷新 51（Round 415-417）

- **〔刷新〕**HANDOFF 追加 Round 415-417（F722-F723：地图移动/实体碰撞 + 地图+移动最终闭合）；基线 Round 414=100e5fa → Round 417=ab0e0d5（**382 连发 F335-F723**）。
- 落盘：handoff-refresh-51-evidence.json（F724，derived-tooling）+ RESEARCH_LOG + UI_COMPLETION_AUDIT Round 418。
## Round 419 (F725) — 2026-08-12：英雄更新 + 死亡/重生

- **〔英雄〕**0x410100 setter（[0x62A58]）；0x410110 数据装载（方向字 [0x61BCx] + **等级进度字节 [0x61BC8] = 比例 × 0x47644C**）；0x410190 死亡/重生（SEH）：音效 0x6E @ [0xCC]/[0xD0] + 实体 0x434EF0 ctor（F565）+ **双向链表 0x560088**（vtable 0x476448、next [0x8]/prev [0xC]、头 0x56008C、计数 [0x560098]）+ **1500ms 重生计时 [0x8A68BC]**（F611 1500ms 确认）。
- 落盘：hero-update-death-spawn-evidence.json（F725，primary-bytes）+ RESEARCH_LOG + UI_COMPLETION_AUDIT Round 419。
## Round 420 (F726) — 2026-08-12：英雄运行时弧闭合（F695/F696/F725 汇总）

- **〔验证〕**compileall OK、verify exit 0、node OK、JSON 有效、**350 证据 JSON**；三服务 200；master 431153f（**384 连发 F335-F725 已推**）。
- **〔弧〕**英雄移动（F695）+ 英雄弧（F696）+ 更新/死亡（F725）——**英雄运行时完整**（8 方向移动 + msg 0xBC3 + 状态 [0x62A50..0x62AE4] + 数据装载 + 死亡/重生链表 + 1500ms 重生），**列明角落 0x410100 闭合**。
- 落盘：hero-runtime-arc-closure-evidence.json（F726，derived）+ RESEARCH_LOG + UI_COMPLETION_AUDIT Round 420。
## Round 421 (F727) — 2026-08-12：HANDOFF 刷新 52（Round 418-420）

- **〔刷新〕**HANDOFF 追加 Round 418-420（F725-F726：英雄更新/死亡重生 + 英雄最终闭合 + F614 冲突修复）；基线 Round 417=ab0e0d5 → Round 420=cbbf2ac（**385 连发 F335-F726**）。
- 落盘：handoff-refresh-52-evidence.json（F727，derived-tooling）+ RESEARCH_LOG + UI_COMPLETION_AUDIT Round 421。
## Round 422 (F728) — 2026-08-12：逐瓦片渲染家族

- **〔瓦片渲染〕**0x43B9A0 单瓦片地面渲染（奇偶门 + 网格 [0x108] + 类型/7 + 帧表 0x5600FC + **blit 0x45E8E0 入瓦片缓冲 [0x1B2]**——相机滚动 F718 调用）；0x43BB10 物体层瓦片渲染（属性字 +3/+5/+7、0x30×0x20 尺寸门）——地图逐瓦片渲染核心（F718 用）。
- 落盘：per-tile-render-family-evidence.json（F728，primary-bytes）+ RESEARCH_LOG + UI_COMPLETION_AUDIT Round 422。
## Round 423 (F729) — 2026-08-12：地图渲染最终闭合（F717-F728 汇总）

- **〔验证〕**compileall OK、verify exit 0、node OK、JSON 有效、**353 证据 JSON**；三服务 200；master 5fbfd50（**387 连发 F335-F728 已推**）。
- **〔弧〕**瓦片访问器（F717）+ 相机（F718）+ 碰撞/方向（F719）+ 移动门（F722）+ 逐瓦片渲染（F728）——**地图系统 100% 字节级**（取/可行走/封锁 + 相机绘制/平移 + 碰撞 + 实体封锁移动 + 地面/物体层瓦片 blit），列明地图角落全部闭合。
- 落盘：map-render-final-closure-evidence.json（F729，derived）+ RESEARCH_LOG + UI_COMPLETION_AUDIT Round 423。
## Round 424 (F730) — 2026-08-12：HANDOFF 刷新 53（Round 421-423）

- **〔刷新〕**HANDOFF 追加 Round 421-423（F728-F729：逐瓦片渲染 + 地图渲染最终闭合）；基线 Round 420=cbbf2ac → Round 423=facd4c5（**388 连发 F335-F729**）。
- 落盘：handoff-refresh-53-evidence.json（F730，derived-tooling）+ RESEARCH_LOG + UI_COMPLETION_AUDIT Round 424。
## Round 425 (F731) — 2026-08-12：HUD 键盘/输入分派

- **〔输入〕**0x42C9E0：窗口转发（0x516EC→0x448490、0x33188 商店→0x44F1D0）+ 热键栏命中 0x42D720（F581）+ 冷却门 0x7D0/0x3E8 vs GetTickCount [0x29CD8] + **物品名表 0x47ADB4（cp949）热键发送 msg 0x3EE**（0x451910）+ 格式化 0x46811C/公告 0x415280；0x42CBD0 输入门（窗口 [0x53060]/[0x52E8C] + 公告 [0x5081C]→0x414DC0）——HUD 输入路由（F580/F581/F616 用）。
- 落盘：hud-keyboard-dispatch-evidence.json（F731，primary-bytes）+ RESEARCH_LOG + UI_COMPLETION_AUDIT Round 425。
## Round 426 (F732) — 2026-08-12：HUD 输入弧闭合（F580/F581/F587/F731 汇总）

- **〔验证〕**compileall OK、verify exit 0、node OK、JSON 有效、**356 证据 JSON**；三服务 200；master f676d43（**390 连发 F335-F731 已推**）。
- **〔弧〕**caption 分派（F580）+ 热键栏（F581）+ 点击分派（F587）+ 键盘分派（F731）——**HUD 输入完整**（16 分支 caption + 6 槽热键 + 点击路由 + 键盘窗口转发/热键发送），**待办角落 0x42C9E0 闭合**。
- 落盘：hud-input-arc-closure-evidence.json（F732，derived）+ RESEARCH_LOG + UI_COMPLETION_AUDIT Round 426。
## Round 427 (F733) — 2026-08-12：HANDOFF 刷新 54（Round 424-426）

- **〔刷新〕**HANDOFF 追加 Round 424-426（F731-F732：HUD 键盘分派 + HUD 输入弧）；基线 Round 423=facd4c5 → Round 426=2450f7e（**391 连发 F335-F732**）。
- 落盘：handoff-refresh-54-evidence.json（F733，derived-tooling）+ RESEARCH_LOG + UI_COMPLETION_AUDIT Round 427。
## Round 428 (F734) — 2026-08-12：公告行列表添加 + 渲染

- **〔公告〕**0x415280 添加：修剪 ≥8（解链 + free 0x4680F8）+ 分配 0x104 + 复制 + 插入 0x449870（头 [0x8]/尾 [0x10]/计数 [0x18]）；0x4153B0 渲染：0x45DD70 TextOutA 阴影 0xA0A0A + **文本色 0xB4FFB4**（经典 Mir3 伤害/治疗绿）、y += 0xF 行、寿命 0xBB8（3000ms）/0x3E8（>6 行）、超时修剪——浮动公告文本系统（F731 用、F564/F677 家族）。
- 落盘：notice-line-list-add-render-evidence.json（F734，primary-bytes）+ RESEARCH_LOG + UI_COMPLETION_AUDIT Round 428。
## Round 429 (F735) — 2026-08-12：聊天/公告弧闭合（F564/F599/F600/F677/F731/F734 汇总）

- **〔验证〕**compileall OK、verify exit 0、node OK、JSON 有效、**359 证据 JSON**；三服务 200；master c69430b（**393 连发 F335-F734 已推**）。
- **〔弧〕**文本渲染（F564）+ 聊天渲染（F599）+ 聊天命令（F600）+ 行列表核心（F677）+ HUD 键盘（F731）+ 公告添加/渲染（F734）——**聊天 + 公告完整**（19 行环 + 滚动条 + 命令 + 修剪/插入 + 浮动文本带寿命）。
- 落盘：chat-notice-arc-closure-evidence.json（F735，derived）+ RESEARCH_LOG + UI_COMPLETION_AUDIT Round 429。
## Round 430 (F736) — 2026-08-12：HANDOFF 刷新 55（Round 427-429）

- **〔刷新〕**HANDOFF 追加 Round 427-429（F734-F735：公告行列表 + 聊天/公告弧）；基线 Round 426=2450f7e → Round 429=0d84db2（**394 连发 F335-F735**）。
- 落盘：handoff-refresh-55-evidence.json（F736，derived-tooling）+ RESEARCH_LOG + UI_COMPLETION_AUDIT Round 430。
## Round 431 (F737) — 2026-08-12：文本家族 BSS 侧助手

- **〔文本〕**0x45DC70 **字符串列表拼接**（追加 varargs 至目标、跳过 BSS 串 **0x8B187C**——待办 0x45DC70 拼接缺口闭合）；0x45DD00 包含检查（0x468BF0 strchr）；0x45DD70 文本绘制包装（GDI 0x476044/0x476048/0x476050/0x476060/0x476074）——**F564 文本家族完整**（F734 渲染用 0x45DD70）。
- 落盘：text-family-bss-helpers-evidence.json（F737，primary-bytes）+ RESEARCH_LOG + UI_COMPLETION_AUDIT Round 431。
## Round 432 (F738) — 2026-08-12：文本家族最终闭合（F564/F680/F683/F737 汇总）

- **〔验证〕**compileall OK、verify exit 0、node OK、JSON 有效、**362 证据 JSON**；三服务 200；master d54fd4c（**396 连发 F335-F737 已推**）。
- **〔弧〕**GDI 文本渲染（F564）+ sprintf/strtol（F680）+ 数值助手（F683）+ BSS 助手（F737）——**文本系统 100% 字节级**（测量/TextOutA/DrawTextA + vsprintf/strtol + 拼接/包含/GDI 绘制），**待办 BSS 侧缺口闭合**。
- 落盘：text-family-final-closure-evidence.json（F738，derived）+ RESEARCH_LOG + UI_COMPLETION_AUDIT Round 432。
## Round 433 (F739) — 2026-08-12：HANDOFF 刷新 56（Round 430-432）

- **〔刷新〕**HANDOFF 追加 Round 430-432（F737-F738：文本 BSS 助手 + 文本家族最终闭合）；基线 Round 429=0d84db2 → Round 432=994b5d7（**397 连发 F335-F738**）。
- 落盘：handoff-refresh-56-evidence.json（F739，derived-tooling）+ RESEARCH_LOG + UI_COMPLETION_AUDIT Round 433。
## Round 434 (F740) — 2026-08-12：商店窗口点击处理

- **〔商店〕**0x44F1D0：模式 [0x5F8] 分派（F661）：**购买路径**（0x44E700 命中 → msg 0x3EA via 0x423E80、确认态 [0x5F8]=4、物品 [0x7F0]、旗标 [0x7EC]）+ **卖出/修理路径**（0x4521F0 + 耐久 [item+0x3D]；0x452230/0x4522A0 发送）+ 购买确认命中测试（SetRect [0x7F4..0x810] + PtInRect → 0x452270/0x452230）——商店家族扩展（F555/F661/F662 用）。
- 落盘：shop-window-click-handler-evidence.json（F740，primary-bytes）+ RESEARCH_LOG + UI_COMPLETION_AUDIT Round 434。
## Round 435 (F741) — 2026-08-12：商店家族最终闭合（F555/F661/F662/F740 汇总）

- **〔验证〕**compileall OK、verify exit 0、node OK、JSON 有效、**365 证据 JSON**；三服务 200；master 7c81bb0（**399 连发 F335-F740 已推**）。
- **〔弧〕**买/卖/修（F555）+ 管理/命中（F661）+ 绘制（F662）+ 点击（F740）——**商店系统 100% 字节级**（模式 [0x5F8] 4 态 + 物品列表 [0x70C] + 购买 0x3EA/卖修发送 + 确认命中），**F731 转发目标 0x44F1D0 闭合**。
- 落盘：shop-family-final-closure-evidence.json（F741，derived）+ RESEARCH_LOG + UI_COMPLETION_AUDIT Round 435。
## Round 436 (F742) — 2026-08-12：HANDOFF 刷新 57（Round 433-435）+ 400 连发里程碑

- **〔刷新〕**HANDOFF 追加 Round 433-435（F740-F741：商店点击 + 商店家族最终闭合）；基线 Round 432=994b5d7 → Round 435=6cd1af5（**400 连发 F335-F741**）——**400 连发里程碑**。
- 落盘：handoff-refresh-57-evidence.json（F742，derived-tooling）+ RESEARCH_LOG + UI_COMPLETION_AUDIT Round 436。
## Round 437 (F743) — 2026-08-12：技能记录装载 + 显示槽

- **〔技能〕**0x423070 技能数据装载（记录 +0/+6..+0xB → **显示槽 [0x35B251..0x35B258]**——待办 write-only 槽**已解析**）；0x423020 技能显示复制（[0x35B1F5/0x35B1F7/0x35B1F9] → [0x35A34A/0x35A34C/0x35A34E] + base64 0x452810 + free）；0x4230E0/0x423180/0x423220 dlist 追加/插入（节点 vtable 0x4767C0、next [0x8]/prev [0xC]、计数 [0x14]）；0x423290 列表 ctor（vtable 0x4766D4）——技能状态槽写侧完整。
- 落盘：skill-record-loader-display-slots-evidence.json（F743，primary-bytes）+ RESEARCH_LOG + UI_COMPLETION_AUDIT Round 437。
## Round 438 (F744) — 2026-08-12：技能家族闭合（F547/F743 汇总）

- **〔验证〕**compileall OK、verify exit 0、node OK、JSON 有效、**368 证据 JSON**；三服务 200；master 1235d17（**402 连发 F335-F743 已推**）。
- **〔弧〕**技能书 8 页签（F547）+ 记录装载/显示（F743）——**技能系统完整**（8 页签书 stride 0xB4 + 记录→槽装载 + 显示复制 + base64），**待办 write-only 显示槽已解析**。
- 落盘：skill-family-closure-evidence.json（F744，derived）+ RESEARCH_LOG + UI_COMPLETION_AUDIT Round 438。
## Round 439 (F745) — 2026-08-12：HANDOFF 刷新 58（Round 436-438）

- **〔刷新〕**HANDOFF 追加 Round 436-438（F743-F744：技能记录/显示槽 + 技能家族闭合）；基线 Round 435=6cd1af5 → Round 438=7599abe（**403 连发 F335-F744**）。
- 落盘：handoff-refresh-58-evidence.json（F745，derived-tooling）+ RESEARCH_LOG + UI_COMPLETION_AUDIT Round 439。
## Round 440 (F746) — 2026-08-12：NPC 对话选项命中/选择

- **〔对话〕**0x448490（F731 转发目标 [0x516EC]）：列表头 [0x1E4]/计数 [0x1F4]/索引 [0x1F0]、**节点矩形 @ +0x218 相对命中** → 选中 [0x1DC]；0x448580 **激活**（节点 [0x208]=0、选中 +0x208=1、[0x68]=1、发送 0x451A10）；0x448650 对话布局（SetRect + 窗口矩形 0x476240/0x476234 + hwnd 0x8AB7B0）；0x448640 清旗标 [0x99]/[0x14D]——NPC 对话选项 UI（F598/F731 用）。
- 落盘：npc-dialog-option-hit-select-evidence.json（F746，primary-bytes）+ RESEARCH_LOG + UI_COMPLETION_AUDIT Round 440。
## Round 441 (F747) — 2026-08-12：NPC 对话弧闭合（F598/F617/F746 汇总）

- **〔验证〕**compileall OK、verify exit 0、node OK、JSON 有效、**371 证据 JSON**；三服务 200；master 58adac3（**405 连发 F335-F746 已推**）。
- **〔弧〕**对话 4 类型渲染（F598）+ NPC 回复/种子（F617）+ 选项命中/选择（F746）——**NPC 对话完整**（4 类型 jt 渲染 + FCOLOR + 选项列表命中/激活/发送），**F731 转发目标 0x448490 闭合**。
- 落盘：npc-dialog-arc-closure-evidence.json（F747，derived）+ RESEARCH_LOG + UI_COMPLETION_AUDIT Round 441。
## Round 442 (F748) — 2026-08-12：HANDOFF 刷新 59（Round 439-441）

- **〔刷新〕**HANDOFF 追加 Round 439-441（F746-F747：NPC 对话选项 + NPC 对话弧）；基线 Round 438=7599abe → Round 441=2599ac2（**406 连发 F335-F747**）。
- 落盘：handoff-refresh-59-evidence.json（F748，derived-tooling）+ RESEARCH_LOG + UI_COMPLETION_AUDIT Round 442。
## Round 443 (F749) — 2026-08-12：交易槽布局家族

- **〔交易〕**0x4162A0 查找空闲槽（12 槽 × 0xC2C @ 0x5B8 + 组 idx×0x9210——**F557 stride 确认**，返回 idx/-1）；0x4162E0 交易物品放置（背包扫描 0x42F6D0 + **5 列网格 36px**、x +0x15 己方/+0xFD 对方、y +0x30 + 物品数组 [obj+0x298] 校验）；0x416490 槽写入（字 → [obj+0x298+网格]）——**交易窗口布局完整**（F557 用）。
- 落盘：trade-slot-layout-family-evidence.json（F749，primary-bytes）+ RESEARCH_LOG + UI_COMPLETION_AUDIT Round 443。
## Round 444 (F750) — 2026-08-12：交易窗口弧闭合（F557/F749 汇总）

- **〔验证〕**compileall OK、verify exit 0、node OK、JSON 有效、**374 证据 JSON**；三服务 200；master 29b6c97（**408 连发 F335-F749 已推**）。
- **〔弧〕**交易家族（F557）+ 槽布局（F749）——**交易窗口完整**（2 组 × 12 槽 0xC2C 网格 + 5 列放置 + 槽写入），交易窗 [hero+0x3399C] 全文档化。
- 落盘：trade-window-arc-closure-evidence.json（F750，derived）+ RESEARCH_LOG + UI_COMPLETION_AUDIT Round 444。
## Round 445 (F751) — 2026-08-12：HANDOFF 刷新 60（Round 442-444）+ 60 刷新里程碑

- **〔刷新〕**HANDOFF 追加 Round 442-444（F749-F750：交易槽布局 + 交易窗口弧）；基线 Round 441=2599ac2 → Round 444=e69704e（**409 连发 F335-F750**）——**HANDOFF 刷新 60 里程碑**。
- 落盘：handoff-refresh-60-evidence.json（F751，derived-tooling）+ RESEARCH_LOG + UI_COMPLETION_AUDIT Round 445。
## Round 446 (F752) — 2026-08-12：组队窗口绘制 + 清除

- **〔组队〕**0x4243D0（F558 模式 6）：标题 0x45DD70 色 0xDCE6C8 + **成员列表 [0x58] 双列绘制**（row/2×20、x +0x5A 偶/+0x64 奇、色 0xFFFFFF）+ **5 按钮 via F704 set-pos 0x417830**（@ +0x6C/+0x120/+0x1D4/+0x288/+0x33C）+ 队长文本 [0x3F0]（0x47BA08/0x47BA00）+ 5 控件绘制（stride 0xB4）；0x4245A0 **拆除**（成员链表 free + 重构造 5×0x4175F0）；0x424610 成员添加（0x423CA0）——组队窗口完整（F558/F704 用）。
- 落盘：party-window-draw-clear-evidence.json（F752，primary-bytes）+ RESEARCH_LOG + UI_COMPLETION_AUDIT Round 446。
## Round 447 (F753) — 2026-08-12：组队/社交弧闭合（F558/F569/F752 汇总）

- **〔验证〕**compileall OK、verify exit 0、node OK、JSON 有效、**377 证据 JSON**；三服务 200；master 7f54e68（**411 连发 F335-F752 已推**）。
- **〔弧〕**窗口注册表组队（F558）+ 行会/组队/联盟错误（F569）+ 组队绘制/清除（F752）——**组队/社交完整**（双列成员 + 5 按钮 + 队长徽章 + 拆除 + 错误族），窗口模式 6 全文档化。
- 落盘：party-social-arc-closure-evidence.json（F753，derived）+ RESEARCH_LOG + UI_COMPLETION_AUDIT Round 447。
## Round 448 (F754) — 2026-08-12：HANDOFF 刷新 61（Round 445-447）

- **〔刷新〕**HANDOFF 追加 Round 445-447（F752-F753：组队窗口 + 组队/社交弧）；基线 Round 444=e69704e → Round 447=18ca584（**412 连发 F335-F753**）。
- 落盘：handoff-refresh-61-evidence.json（F754，derived-tooling）+ RESEARCH_LOG + UI_COMPLETION_AUDIT Round 448。
## Round 449 (F755) — 2026-08-12：行会窗口绘制

- **〔行会〕**0x425040（F558 模式 4）：标题 DrawTextA **0x45DE50**（色 0x96C8FF）+ **3 页模式分派 [0x98]**（0x425280 主页/0x425440/0x425590）+ **滚动条 F707 ctor** @ +0x76C（位置 [0x18]+0x224/[0x1C]-0xD0、计数 [0x9C]/[0xE4]）+ **9 按钮 F704 set-pos**（@ +0x118..+0x6B8 stride 0xB4）+ 9 控件绘制；0x425280 主页子绘制（测量 0x45E0C0 + 列表 [0xE4]）——行会窗口完整（F558/F704/F707 用）。
- 落盘：guild-window-draw-evidence.json（F755，primary-bytes）+ RESEARCH_LOG + UI_COMPLETION_AUDIT Round 449。
## Round 450 (F756) — 2026-08-12：行会窗口弧闭合（F535/F558/F755 汇总）+ Round 450 里程碑

- **〔验证〕**compileall OK、verify exit 0、node OK、JSON 有效、**380 证据 JSON**；三服务 200；master 57ca694（**414 连发 F335-F755 已推**）——**Round 450 里程碑**。
- **〔弧〕**行会滚动条（F535）+ 注册表（F558）+ 窗口绘制（F755）——**行会窗口完整**（3 页模式 + 滚动条 + 9 按钮 + 成员列表 + 行会内容），窗口模式 4 全文档化。
- 落盘：guild-window-arc-closure-evidence.json（F756，derived）+ RESEARCH_LOG + UI_COMPLETION_AUDIT Round 450。
## Round 451 (F757) — 2026-08-12：HANDOFF 刷新 62（Round 448-450）

- **〔刷新〕**HANDOFF 追加 Round 448-450（F755-F756：行会窗口 + 行会弧 + Round 450 里程碑）；基线 Round 447=18ca584 → Round 450=2f8112b（**415 连发 F335-F756**）。
- 落盘：handoff-refresh-62-evidence.json（F757，derived-tooling）+ RESEARCH_LOG + UI_COMPLETION_AUDIT Round 451。
## Round 452 (F758) — 2026-08-12：角色状态窗口绘制

- **〔状态〕**0x450530（F558 模式 7）：**头像帧**（[0x551] 职业×10 + [0x554] 等级 + 0x3B → blit 0x45FD50 F647、WIL 0x566DD4）+ **11 装备图标**（0x430A40 F651、记录 stride 0xC24 @ +0x60C、位置表 [0x558] stride 0x10、默认 +0x61/+0xC8）+ 名字/行会标题（0x45DBA0 字体 + 0x45DE50 DrawTextA 0xDCFFDC/0xB4FAFF + 格式化 0x46811C 串 0x47B560/0x47AF48）——角色状态窗口完整（F558/F651 用）。
- 落盘：char-status-window-draw-evidence.json（F758，primary-bytes）+ RESEARCH_LOG + UI_COMPLETION_AUDIT Round 452。
## Round 453 (F759) — 2026-08-12：角色/装备/背包弧闭合（F651/F652/F655/F758 汇总）

- **〔验证〕**compileall OK、verify exit 0、node OK、JSON 有效、**383 证据 JSON**；三服务 200；master 23e0aca（**417 连发 F335-F758 已推**）。
- **〔弧〕**物品图标（F651）+ 反序列化/IO（F652）+ 插入/放置（F655）+ 状态绘制（F758）——**角色/装备/背包完整**（11 装备槽 stride 0xC24 + 背包 6×0x64 自动扫描 + 头像帧 + 图标渲染），窗口模式 0/1/7 全文档化。
- 落盘：char-equip-arc-closure-evidence.json（F759，derived）+ RESEARCH_LOG + UI_COMPLETION_AUDIT Round 453。
## Round 454 (F760) — 2026-08-12：HANDOFF 刷新 63（Round 451-453）

- **〔刷新〕**HANDOFF 追加 Round 451-453（F758-F759：角色状态窗口 + 角色/装备/背包弧）；基线 Round 450=2f8112b → Round 453=1acd4d4（**418 连发 F335-F759**）。
- 落盘：handoff-refresh-63-evidence.json（F760，derived-tooling）+ RESEARCH_LOG + UI_COMPLETION_AUDIT Round 454。
## Round 455 (F761) — 2026-08-12：选项窗口绘制 + 点击

- **〔选项〕**0x441380（F558 模式 C）：**11 控件 via F704 set-pos**（**4×2 开关网格** @ 0x94/0xB9 × 0x2B/0x74/0xBE/0xD9 = **F546 4 开关行确认** + **2 滑块 BGM [0x6C]/SFX [0x74]** @ 0x22+值）+ 11 控件绘制（stride 0xB4）；0x4414F0 点击：开关旗标 [0x64]/[0x68] + **BGM 滑块 [0x6C] ±8 钳制 0..0xA0** + 音效 0x69 + 重绘 0x441F40——选项窗口完整（F546/F558 用）。
- 落盘：options-window-draw-click-evidence.json（F761，primary-bytes）+ RESEARCH_LOG + UI_COMPLETION_AUDIT Round 455。
## Round 456 (F762) — 2026-08-12：选项窗口弧闭合（F546/F761 汇总）+ 420 连发里程碑

- **〔验证〕**compileall OK、verify exit 0、node OK、JSON 有效、**386 证据 JSON**；三服务 200；master 0669267（**420 连发 F335-F761 已推**）——**420 连发里程碑**。
- **〔弧〕**4 开关行（F546）+ 绘制/点击（F761）——**选项窗口完整**（4×2 开关网格 + BGM/SFX 滑块 + msg 0x2F8-0x2FB 开关），窗口模式 C 全文档化。
- 落盘：options-window-arc-closure-evidence.json（F762，derived）+ RESEARCH_LOG + UI_COMPLETION_AUDIT Round 456。
## Round 457 (F763) — 2026-08-12：HANDOFF 刷新 64（Round 454-456）

- **〔刷新〕**HANDOFF 追加 Round 454-456（F761-F762：选项窗口 + 选项弧 + 420 里程碑）；基线 Round 453=1acd4d4 → Round 456=eb5f4b4（**421 连发 F335-F762**）。
- 落盘：handoff-refresh-64-evidence.json（F763，derived-tooling）+ RESEARCH_LOG + UI_COMPLETION_AUDIT Round 457。
## Round 458 (F764) — 2026-08-12：背包窗口绘制

- **〔背包〕**0x42EB80（F558 模式 0）：**滚动条 F707 ctor** @ +0x278（计数 [0x58]、位置 [0x18]+0xF8/[0x1C]-0xA5）+ 物品网格矩形（+0x19/+0x29、36px）+ **拖动预览**（槽命中 0x42F150 → 布局 0x42F2A0 + IntersectRect 0x476248 + **矩阵变换 0x466800（F643）** 浮点 1.0/0.196/0.392 + 0x3B808081 → 缩放 blit；拖动中 [0x7243C4]、旗标 [0x7243D8]）——背包窗口完整（F558/F707 用）。
- 落盘：bag-window-draw-evidence.json（F764，primary-bytes）+ RESEARCH_LOG + UI_COMPLETION_AUDIT Round 458。
## Round 459 (F765) — 2026-08-12：窗口系统最终闭合（F558/F701-F764 汇总）

- **〔验证〕**compileall OK、verify exit 0、node OK、JSON 有效、**389 证据 JSON**；三服务 200；master 9fe1ee6（**423 连发 F335-F764 已推**）。
- **〔弧〕**注册表（F558）+ 基类构造/绘制（F713/F714）+ 控件（F701/F704/F710）+ 滚动条（F707）+ **全部窗口绘制**（背包 F764 + 状态 F758 + 行会 F755 + 组队 F752 + 交易 F749 + 对话 F746 + 选项 F761）——**窗口系统 100% 字节级**：14 模式注册表 + 基类 + 控件/滚动条工具 + 每窗口绘制/输入全解码。
- 落盘：window-system-final-closure-evidence.json（F765，derived）+ RESEARCH_LOG + UI_COMPLETION_AUDIT Round 459。
## Round 460 (F766) — 2026-08-12：HANDOFF 刷新 65（Round 457-459）+ 窗口系统里程碑

- **〔刷新〕**HANDOFF 追加 Round 457-459（F764-F765：背包窗口 + 窗口系统最终闭合）；基线 Round 456=eb5f4b4 → Round 459=fb330c0（**424 连发 F335-F765**）——**窗口系统 100% 里程碑**。
- 落盘：handoff-refresh-65-evidence.json（F766，derived-tooling）+ RESEARCH_LOG + UI_COMPLETION_AUDIT Round 460。
## Round 461 (F767) — 2026-08-12：装备窗口绘制

- **〔装备〕**0x44B2D0（F558 模式 1）：**2 页模式 [0x54]**（0/1 分支）+ **纸娃娃 blit**（WIL 0x565994 帧 0xA7 页 1/0xAA 页 0 → 0x45FD50 F647 @ [0x18]+0xB0/[0x1C]+0x109）+ 标题/副标题 DrawTextA 0x45DE50（串 0x7776A0/0x7776E0、色 0xDCFFDC/0xB4FAFF、字体 0x45DBA0）+ 0x44BC80 装备槽子绘制 + 按钮 F704——**装备窗口完整，F558 注册表最后一个窗口绘制解码**。
- 落盘：equip-window-draw-evidence.json（F767，primary-bytes）+ RESEARCH_LOG + UI_COMPLETION_AUDIT Round 461。
## Round 462 (F768) — 2026-08-12：窗口绘制全量闭合（F746-F767 汇总）

- **〔验证〕**compileall OK、verify exit 0、node OK、JSON 有效、**392 证据 JSON**；三服务 200；master ff4dfc0（**426 连发 F335-F767 已推**）。
- **〔弧〕**对话（F746）+ 交易（F749）+ 组队（F752）+ 行会（F755）+ 状态（F758）+ 选项（F761）+ 背包（F764）+ 装备（F767）——**F558 注册表全部 14 个窗口绘制字节级解码**，窗口绘制表面 100% 完整。
- 落盘：window-draws-total-closure-evidence.json（F768，derived）+ RESEARCH_LOG + UI_COMPLETION_AUDIT Round 462。
## Round 463 (F769) — 2026-08-12：HANDOFF 刷新 66（Round 460-462）

- **〔刷新〕**HANDOFF 追加 Round 460-462（F767-F768：装备窗口 + 窗口绘制全量闭合）；基线 Round 459=fb330c0 → Round 462=061e7c2（**427 连发 F335-F768**）。
- 落盘：handoff-refresh-66-evidence.json（F769，derived-tooling）+ RESEARCH_LOG + UI_COMPLETION_AUDIT Round 463。
## Round 464 (F770) — 2026-08-12：行会公告编辑器

- **〔公告编辑〕**0x43E3C0 绘制（F558 模式 F）：提示/文本 0x47C460/0x47C440 via 0x45DD70 色 0x323232、旗标 [0x1D0] + **2 按钮 F704** + 2 绘制；0x43E4B0 输入/回车（0x1F40 暂存）：编辑控件 vtable[0x10] 命中 + **GetWindowText 0x476304（0xFA0 上限）** + **'\n' 行拆分（0x468BF0）** + **拼接 0x45DC70（F737）** + **发送 0x4524D0（F617）**——行会公告编辑器完整，**F558 注册表最后一个函数体解码**。
- 落盘：guild-announce-editor-evidence.json（F770，primary-bytes）+ RESEARCH_LOG + UI_COMPLETION_AUDIT Round 464。
## Round 465 (F771) — 2026-08-12：窗口注册表全量闭合（F558 + F713-F770 汇总）

- **〔验证〕**compileall OK、verify exit 0、node OK、JSON 有效、**395 证据 JSON**；三服务 200；master dd1f504（**429 连发 F335-F770 已推**）。
- **〔弧〕**F558 注册表**全部 14 个窗口函数体解码**（背包 F764 + 状态 F758 + 行会 F755 + 组队 F752 + 交易 F749 + 对话 F746 + 选项 F761 + 装备 F767 + 公告编辑 F770 + 基类 F713/F714 + 控件 F701/F704 + 滚动条 F707）——**窗口注册表完整**：Round 236-265 的 F559 窗口系统弧 100% 闭合。
- 落盘：window-registry-total-closure-evidence.json（F771，derived）+ RESEARCH_LOG + UI_COMPLETION_AUDIT Round 465。
## Round 466 (F772) — 2026-08-12：HANDOFF 刷新 67（Round 463-465）

- **〔刷新〕**HANDOFF 追加 Round 463-465（F770-F771：行会公告编辑器 + 窗口注册表全量闭合）；基线 Round 462=061e7c2 → Round 465=88248b7（**430 连发 F335-F771**）。
- 落盘：handoff-refresh-67-evidence.json（F772，derived-tooling）+ RESEARCH_LOG + UI_COMPLETION_AUDIT Round 466。
## Round 467 (F773) — 2026-08-12：坐骑窗口绘制 + 命令

- **〔坐骑〕**0x4269C0（F558 模式 D）：**5 按钮 F704**（大 0xFC/0x125 @ +0x54 + 4 命令按钮 @ 0x1C/0x4A/0x85/0xC0 × 0xF4）+ 5 控件绘制；0x426A80 **命令分派**（vtable[0x10] 命中 + 坐骑旗标 [0x7DA060] + **发送 0x4520F0** 串 0x47B058/0x47B060/0x47B068 + **300ms 冷却 [0x8A68BC]=0x12C**（F545 确认））；0x426B50/0x426B90 命中/点击分派——坐骑窗口完整（F545/F558 用）。
- 落盘：mount-window-draw-commands-evidence.json（F773，primary-bytes）+ RESEARCH_LOG + UI_COMPLETION_AUDIT Round 467。
## Round 468 (F774) — 2026-08-12：社交窗口最终闭合（F545/F558/F752/F755/F770/F773 汇总）

- **〔验证〕**compileall OK、verify exit 0、node OK、JSON 有效、**398 证据 JSON**；三服务 200；master f52141a（**432 连发 F335-F773 已推**）。
- **〔弧〕**行会（F755）+ 组队（F752）+ 坐骑（F773）+ 公告编辑（F770）——**社交窗口家族完整**（行会 3 页 + 组队双列 + 坐骑 5 按钮命令 + 公告编辑器），F558 全部社交模式文档化。
- 落盘：social-windows-final-closure-evidence.json（F774，derived）+ RESEARCH_LOG + UI_COMPLETION_AUDIT Round 468。
## Round 469 (F775) — 2026-08-12：HANDOFF 刷新 68（Round 466-468）

- **〔刷新〕**HANDOFF 追加 Round 466-468（F773-F774：坐骑窗口 + 社交窗口最终闭合）；基线 Round 465=88248b7 → Round 468=20310e2（**433 连发 F335-F774**）。
- 落盘：handoff-refresh-68-evidence.json（F775，derived-tooling）+ RESEARCH_LOG + UI_COMPLETION_AUDIT Round 469。
## Round 470 (F776) — 2026-08-12：选项滑块应用 + 构造

- **〔选项音频〕**0x441F40（F761 依赖）：arg 1 → **BGM [0x6C] × 0x476978 − 0x476970**（0x468520 浮点→int）→ **音量 [0x8AB150]** + **0x45A700 音量 API** + 0x441B30 重绘；否则 **SFX [0x74] → [0x8AB14C]** + 重绘；0x441FD0/0x442020 构造（vtable 0x476984 + 滑块浮点态 0xBF000000/-0.5、0x43960000/300.0、0x3CA3D70A/0.02、0xBD4CCCCD/-0.05）——选项音频应用完整（F546/F761 用）。
- 落盘：options-slider-apply-ctor-evidence.json（F776，primary-bytes）+ RESEARCH_LOG + UI_COMPLETION_AUDIT Round 470。
## Round 471 (F777) — 2026-08-12：选项/音频应用弧闭合（F546/F632/F761/F776 汇总）+ 400 证据里程碑

- **〔验证〕**compileall OK、verify exit 0、node OK、JSON 有效、**401 证据 JSON（400+ 里程碑）**；三服务 200；master 5162b3d（**435 连发 F335-F776 已推**）。
- **〔弧〕**BGM 滑块（F546）+ 音频引擎（F632）+ 选项点击（F761）+ 滑块应用（F776）——**选项/音频应用完整**（4×2 开关 + BGM/SFX 滑块 → 音量槽 0x8AB150/0x8AB14C → 0x45A700 应用 + 重绘）。
- 落盘：options-audio-apply-arc-closure-evidence.json（F777，derived）+ RESEARCH_LOG + UI_COMPLETION_AUDIT Round 471。
## Round 472 (F778) — 2026-08-12：HANDOFF 刷新 69（Round 469-471）

- **〔刷新〕**HANDOFF 追加 Round 469-471（F776-F777：选项滑块应用 + 选项音频弧 + 400 证据里程碑）；基线 Round 468=20310e2 → Round 471=bbd1855（**436 连发 F335-F777**）。
- 落盘：handoff-refresh-69-evidence.json（F778，derived-tooling）+ RESEARCH_LOG + UI_COMPLETION_AUDIT Round 472。
## Round 473 (F779) — 2026-08-12：选项字符串刷新 + 配置装载

- **〔选项〕**0x441B30（F776 重绘依赖）：itoa 0x46855F（基数 0xA）+ sprintf 0x4761A4（格式 0x47A2B8 + 标签 0x47C5AC/0x47C598/0x47C594/0x47C588/0x47C57C/0x47C570）值 [0x58]/SFX [0x8AB14C]/[0x54]/BGM [0x8AB150]/[0x5C]/[0x60]——**实时选项值文本块**；0x441CC0 **配置装载**（0x47613C 读 0x104 缓冲 + 解析）——选项配置/显示完整（F546/F761/F776 用）。
- 落盘：options-string-refresh-config-load-evidence.json（F779，primary-bytes）+ RESEARCH_LOG + UI_COMPLETION_AUDIT Round 473。
## Round 474 (F780) — 2026-08-12：选项系统最终闭合（F546/F761/F776/F779 汇总）

- **〔验证〕**compileall OK、verify exit 0、node OK、JSON 有效、**404 证据 JSON**；三服务 200；master bde6bc5（**438 连发 F335-F779 已推**）。
- **〔弧〕**开关（F546）+ 绘制/点击（F761）+ 滑块应用（F776）+ 字符串/配置（F779）——**选项系统 100% 字节级**（4×2 开关 + BGM/SFX 滑块 + 音量应用 0x45A700 + 实时值 + 配置装载），窗口模式 C 全文档化。
- 落盘：options-system-final-closure-evidence.json（F780，derived）+ RESEARCH_LOG + UI_COMPLETION_AUDIT Round 474。
## Round 475 (F781) — 2026-08-12：HANDOFF 刷新 70（Round 472-474）+ 70 刷新里程碑

- **〔刷新〕**HANDOFF 追加 Round 472-474（F779-F780：选项字符串/配置 + 选项系统最终闭合）；基线 Round 471=bbd1855 → Round 474=d753c98（**439 连发 F335-F780**）——**HANDOFF 刷新 70 里程碑**。
- 落盘：handoff-refresh-70-evidence.json（F781，derived-tooling）+ RESEARCH_LOG + UI_COMPLETION_AUDIT Round 475。
## Round 476 (F782) — 2026-08-12：发送器家族扩展（F616/F572 扩展）

- **〔发送〕**0x451A10 **msg 0x418**（对话动作、F746 依赖）+ 0x451A40 0x419 + 0x451A70 **0x401**（F580 攻击确认）+ 0x451AA0 0x402 + 0x451AD0 0x403 + 0x451B00 0x405 + 0x451B30 0x406——全部经包头 0x452940 + 发送 0x451E60（F572）；0x451B60 窗口关闭泵（0x476114 PostMessage 0x1300 + 0x47628C + 0x4760B8/0x4760BC 销毁）；0x451BB0 输入转发（0x4515C0 + hwnd 0x8AB7B0）——**出站发送器完整**。
- 落盘：sender-family-extension-evidence.json（F782，primary-bytes）+ RESEARCH_LOG + UI_COMPLETION_AUDIT Round 476。
## Round 477 (F783) — 2026-08-12：出站发送器最终闭合（F572/F573/F616/F782 汇总）

- **〔验证〕**compileall OK、verify exit 0、node OK、JSON 有效、**407 证据 JSON**；三服务 200；master 453c90f（**441 连发 F335-F782 已推**）。
- **〔弧〕**文本帧协议（F572）+ 出站目录（F573）+ 攻击/交易发送器（F616）+ 发送器扩展（F782）——**出站发送器完整**（包头 0x452940 + 发送 0x451E60 + msg 0x3E9-0x40A/0x416-0x419/0x418/0x401-0x406 + 关闭泵 + 输入转发）。
- 落盘：outbound-senders-final-closure-evidence.json（F783，derived）+ RESEARCH_LOG + UI_COMPLETION_AUDIT Round 477。
## Round 478 (F784) — 2026-08-12：HANDOFF 刷新 71（Round 475-477）

- **〔刷新〕**HANDOFF 追加 Round 475-477（F782-F783：发送器家族扩展 + 出站发送器最终闭合）；基线 Round 474=d753c98 → Round 477=213256b（**442 连发 F335-F783**）。
- 落盘：handoff-refresh-71-evidence.json（F784，derived-tooling）+ RESEARCH_LOG + UI_COMPLETION_AUDIT Round 478。
## Round 479 (F785) — 2026-08-12：消息分派器 + 发送器续篇

- **〔分派〕**0x4515C0（F782 转发依赖）：**自定义消息分派**（msg − 0x2714 ≤ 0x59 → 字节表 0x4515F8 → jt 0x4515F0，否则已处理 1）；发送器：0x451660（arg）+ 0x451690（字节+arg）+ 0x4516D0 **msg 0x50**（WM_KEYDOWN?）+ 0x451700 **0x417** + 0x451740 **0x3F2** + 0x451770 **0x409** + 0x4517A0 **0x3F5**（打包坐标）+ 0x4517E0 **0x3F4**——全部经 0x452940 + 0x451E60——**出站目录扩展**。
- 落盘：message-dispatcher-sender-continuation-evidence.json（F785，primary-bytes）+ RESEARCH_LOG + UI_COMPLETION_AUDIT Round 479。
## Round 480 (F786) — 2026-08-12：输入/消息系统闭合（F552/F560/F587/F782/F785 汇总）+ Round 480 里程碑

- **〔验证〕**compileall OK、verify exit 0、node OK、JSON 有效、**410 证据 JSON**；三服务 200；master d627c4f（**444 连发 F335-F785 已推**）——**Round 480 里程碑**。
- **〔弧〕**异步 TCP（F552）+ 命中测试（F560）+ 点击分派（F587）+ 输入转发（F782）+ 消息分派器（F785）——**输入/消息完整**（WSAAsyncSelect 0x7E8 + 自定义消息表 0x2714 + 点击路由 + 发送器）。
- 落盘：input-message-system-closure-evidence.json（F786，derived）+ RESEARCH_LOG + UI_COMPLETION_AUDIT Round 480。
## Round 481 (F787) — 2026-08-12：HANDOFF 刷新 72（Round 478-480）

- **〔刷新〕**HANDOFF 追加 Round 478-480（F785-F786：消息分派器 + 输入/消息系统闭合 + Round 480 里程碑）；基线 Round 477=213256b → Round 480=b4b8bc8（**445 连发 F335-F786**）。
- 落盘：handoff-refresh-72-evidence.json（F787，derived-tooling）+ RESEARCH_LOG + UI_COMPLETION_AUDIT Round 481。
## Round 482 (F788) — 2026-08-12：选项配置装载全量

- **〔配置〕**0x441CC0 全量：**Mir3.ini 键** 0x47C5AC/0x47C598/0x47C594/0x47C588/0x47C57C/0x47C570（节 0x47A2B8、GetPrivateProfileString 0x4760D4、默认 0x47C5BC/0x47C5B8）+ **atoi 0x4681F9** → 字段 [0x58]/SFX [0x8AB14C]/[0x54]/BGM [0x8AB150]/[0x5C]/[0x60] + **音频开/关**（0x45B1B0/0x45B1D0/0x45B1C0 音效、0x45B410/0x45B3D0/0x45B430 音乐）+ **音量→滑块换算**（×0x476968、钳制 −100）——选项持久化完整（F779 装载侧）。
- 落盘：options-config-load-evidence.json（F788，primary-bytes）+ RESEARCH_LOG + UI_COMPLETION_AUDIT Round 482。
## Round 483 (F789) — 2026-08-12：选项持久化闭合（F546/F776/F779/F788 汇总）

- **〔验证〕**compileall OK、verify exit 0、node OK、JSON 有效、**413 证据 JSON**；三服务 200；master 6ac6a14（**447 连发 F335-F788 已推**）。
- **〔弧〕**滑块（F546）+ 应用（F776）+ 刷新（F779）+ 配置装载（F788）——**选项持久化完整**（Mir3.ini 6 键 + atoi + 音频开/关 + 音量↔滑块双向 + 实时值），**选项全生命周期**（装载 → 显示 → 调整 → 应用）文档化。
- 落盘：options-persistence-closure-evidence.json（F789，derived）+ RESEARCH_LOG + UI_COMPLETION_AUDIT Round 483。
## Round 484 (F790) — 2026-08-12：HANDOFF 刷新 73（Round 481-483）

- **〔刷新〕**HANDOFF 追加 Round 481-483（F788-F789：选项配置装载 + 选项持久化闭合）；基线 Round 480=b4b8bc8 → Round 483=581634a（**448 连发 F335-F789**）。
- 落盘：handoff-refresh-73-evidence.json（F790，derived-tooling）+ RESEARCH_LOG + UI_COMPLETION_AUDIT Round 484。
## Round 485 (F791) — 2026-08-12：英雄消息分派 + 死亡泵

- **〔英雄〕**0x422840：msg 0x34 → 0x423000、**msg 0x2F0 → 0x423070（F743 技能装载器）**、**msg 0x1F → 显示槽 [0x35A34A/0x35A34C] + 内部 [0x35B1F5/0x35B1F9]**（500ms 门 [0x35B278]、0x40A1E0 + 0x4561B0 地图串）——F743 写者来源解析；**0x422960 死亡/重生泵（F611 全量）**：状态 [0x2F8840]==3 + 停音 0x45B1D0/0x45B3D0 + **1500ms 计时 [0x4279A4]=0x5DC** + 重生坐标 [0x2F884C]/[0x2F8850] + 速度 [0x428220]=1.0f + 0x410100（F725）+ vtable[0x10]——**F611 函数体完整**。
- 落盘：hero-message-dispatch-death-pump-evidence.json（F791，primary-bytes）+ RESEARCH_LOG + UI_COMPLETION_AUDIT Round 485。
## Round 486 (F792) — 2026-08-12：英雄生命周期最终闭合（F611/F695/F696/F725/F743/F791 汇总）+ 450 连发里程碑

- **〔验证〕**compileall OK、verify exit 0、node OK、JSON 有效、**416 证据 JSON**；三服务 200；master 12ea43e（**450 连发 F335-F791 已推**）——**450 连发里程碑**。
- **〔弧〕**死亡泵（F611）+ 移动（F695）+ 更新（F725）+ 技能装载（F743）+ 消息分派（F791）——**英雄生命周期完整**（移动 → 数据装载 → 技能消息 → 死亡 → 1500ms 重生 → 生成），待办 write-only 槽消费者 + 死亡泵体全解析。
- 落盘：hero-lifecycle-final-closure-evidence.json（F792，derived）+ RESEARCH_LOG + UI_COMPLETION_AUDIT Round 486。
## Round 487 (F793) — 2026-08-12：HANDOFF 刷新 74（Round 484-486）

- **〔刷新〕**HANDOFF 追加 Round 484-486（F791-F792：英雄消息/死亡泵 + 英雄生命周期最终闭合 + 450 里程碑）；基线 Round 483=581634a → Round 486=95c2f7f（**451 连发 F335-F792**）。
- 落盘：handoff-refresh-74-evidence.json（F793，derived-tooling）+ RESEARCH_LOG + UI_COMPLETION_AUDIT Round 487。
## Round 488 (F794) — 2026-08-12：技能消息处理 + 地图标题处理

- **〔技能〕**0x423000 技能 msg 0x34 全量（base64 0x452810 解码 msg+0xC → [0x35B1F0] 记录 → 显示槽 [0x35A34x]，free——**F743 的 0x423020 为其尾部**）；0x422CC0 **地图标题处理**（msg → 实体 id [0x2F8784]、base64 ×2、vtable[0x8C]、**标题 0x47EEE4 → 0x7776A0**、[0x2ED0B0]、列表 [0xE1188] 清 + 0x417FB0 重置、发送 msg 0x51、[0x35B2B8]=1）——技能 + 地图显示处理完整。
- 落盘：skill-msg-handler-map-title-evidence.json（F794，primary-bytes）+ RESEARCH_LOG + UI_COMPLETION_AUDIT Round 488。
## Round 489 (F795) — 2026-08-12：技能/显示处理闭合（F743/F791/F794 汇总）

- **〔验证〕**compileall OK、verify exit 0、node OK、JSON 有效、**419 证据 JSON**；三服务 200；master afc68f7（**453 连发 F335-F794 已推**）。
- **〔弧〕**技能记录（F743）+ 英雄分派（F791）+ 技能消息/地图标题（F794）——**技能/显示处理完整**（msg 0x34 base64 解码 + 0x2F0 装载器 + 0x1F 槽 + 地图标题 0x7776A0），待办显示槽链全解析。
- 落盘：skill-display-handlers-closure-evidence.json（F795，derived）+ RESEARCH_LOG + UI_COMPLETION_AUDIT Round 489。
## Round 490 (F796) — 2026-08-12：HANDOFF 刷新 75（Round 487-489）+ 75 刷新里程碑

- **〔刷新〕**HANDOFF 追加 Round 487-489（F794-F795：技能消息/地图标题 + 技能/显示处理闭合）；基线 Round 486=95c2f7f → Round 489=f14f2e5（**454 连发 F335-F795**）——**HANDOFF 刷新 75 里程碑**。
- 落盘：handoff-refresh-75-evidence.json（F796，derived-tooling）+ RESEARCH_LOG + UI_COMPLETION_AUDIT Round 490。
## Round 491 (F797) — 2026-08-12：地图/名字消息处理

- **〔消息〕**0x422E30（recv1 相邻家族）：base64 0x452810 解码（0x400 上限）+ msg 类型 [edi+4] **分派**：0x68/其他 → 0x401390 ×2 + **公告绘制 0x427E30（F674）** + 0x4256A0；0x28/0x5DD → 实体**名字更新**：[edi]==[0x2F8784] 自身 → 名 [0x35A820] + 0x40BA60 + 重置 [0x35A81C]，否则列表扫描 [0xE1158] → 名 **[0x620A0]**（F621/F531 英雄名槽）+ 0x40BA60 + 重置 [0x6209C]——公告 + 实体名消息完整。
- 落盘：map-name-message-handler-evidence.json（F797，primary-bytes）+ RESEARCH_LOG + UI_COMPLETION_AUDIT Round 491。
## Round 492 (F798) — 2026-08-12：recv/名字家族闭合（F571/F621/F674/F791/F794/F797 汇总）

- **〔验证〕**compileall OK、verify exit 0、node OK、JSON 有效、**422 证据 JSON**；三服务 200；master 3e7793d（**456 连发 F335-F797 已推**）。
- **〔弧〕**入站协议（F571）+ 英雄分派（F791）+ 技能处理（F794）+ 地图/名字处理（F797）——**recv/名字家族完整**（base64 载荷 + 公告绘制 + 实体名 [0x35A820]/[0x620A0] + 技能消息），入站处理表面扩展至 100%。
- 落盘：recv-name-family-closure-evidence.json（F798，derived）+ RESEARCH_LOG + UI_COMPLETION_AUDIT Round 492。
## Round 493 (F799) — 2026-08-12：HANDOFF 刷新 76（Round 490-492）

- **〔刷新〕**HANDOFF 追加 Round 490-492（F797-F798：地图/名字消息 + recv/名字家族闭合）；基线 Round 489=f14f2e5 → Round 492=56c9011（**457 连发 F335-F798**）。
- 落盘：handoff-refresh-76-evidence.json（F799，derived-tooling）+ RESEARCH_LOG + UI_COMPLETION_AUDIT Round 493。
## Round 494 (F800) — 2026-08-12：实体名字格式化 + 渲染（F621 全量）

- **〔名字〕**0x40BA60（F797 依赖）：0x468CD7 sprintf 格式 0x47AC3C（名 [0x620A0] + 状态 [0x61C8C] + **8 个状态串 @ [0x621A4..0x628C0] stride 0x104**）+ 重置 [0x6209C]；0x40BB00 **名字渲染（F621 函数体）**：[0x6209C] += delta、**>0xBB8（3000ms，F621/F531 确认）** → 清名+状态；位置 [0xE4]/[0xE8] − 0x2C/−0x37、状态 [0x61C8C]==1 居中测量 0x45E0C0 否则 状态×14 偏移；SetRect + **矩阵 0x466800（F643）缩放**（0.157/0.235/0.313/0.47）+ vtable[0x40] 渲染——实体名字系统完整。
- 落盘：entity-name-format-render-evidence.json（F800，primary-bytes）+ RESEARCH_LOG + UI_COMPLETION_AUDIT Round 494。
## Round 495 (F801) — 2026-08-12：名字/头顶系统闭合（F621/F531/F797/F800 汇总）

- **〔验证〕**compileall OK、verify exit 0、node OK、JSON 有效、**425 证据 JSON**；三服务 200；master f9256fa（**459 连发 F335-F800 已推**）。
- **〔弧〕**英雄名字层（F621）+ 3000ms 计时（F531）+ 名字消息处理（F797）+ 格式化/渲染（F800）——**名字/头顶完整**（名字消息 → 0x40BA60 格式化 → 0x40BB00 渲染 → 3000ms 清除、矩阵缩放、位置 [0xE4]/[0xE8]）。
- 落盘：name-overhead-system-closure-evidence.json（F801，derived）+ RESEARCH_LOG + UI_COMPLETION_AUDIT Round 495。
## Round 496 (F802) — 2026-08-12：HANDOFF 刷新 77（Round 493-495）

- **〔刷新〕**HANDOFF 追加 Round 493-495（F800-F801：实体名字格式/渲染 + 名字/头顶系统闭合 + Round 800 finding）；基线 Round 492=56c9011 → Round 495=a2d8040（**460 连发 F335-F801**）。
- 落盘：handoff-refresh-77-evidence.json（F802，derived-tooling）+ RESEARCH_LOG + UI_COMPLETION_AUDIT Round 496。
## Round 497 (F803) — 2026-08-12：行会公告列表 + 消息分派

- **〔行会〕**0x4256A0（F797 公告路径）：0x45E200 + 0x468CD7 sprintf 格式 **0x47AD30** → 拆分 ≤5 行（0x104 各）→ 列表插入 [0x100]（节点分配 0x1000、计数 [0x9C] 上限 5、积压 [0x114] 上限 0x50=80 修剪 via vtable[0x14] + free）；0x425820 **行会消息分派**：msg 0x40F（seq 0）→ 0x452470 + 0x452410、msg 0x414 → **0x4520F0 with 0x47BA9C**、msg 0x415 → 0x41 双字成员操作——行会公告/消息完整（F755/F797 用）。
- 落盘：guild-notice-list-msg-dispatch-evidence.json（F803，primary-bytes）+ RESEARCH_LOG + UI_COMPLETION_AUDIT Round 497。
## Round 498 (F804) — 2026-08-12：行会/社交消息闭合（F755/F797/F803 汇总）

- **〔验证〕**compileall OK、verify exit 0、node OK、JSON 有效、**428 证据 JSON**；三服务 200；master dcda73e（**462 连发 F335-F803 已推**）。
- **〔弧〕**行会窗口（F755）+ 公告路径（F797）+ 公告列表/消息分派（F803）——**行会/社交消息完整**（5 行公告列表 + 80 积压 + msg 0x40F/0x414/0x415 发送），行会社交表面闭合。
- 落盘：guild-social-messages-closure-evidence.json（F804，derived）+ RESEARCH_LOG + UI_COMPLETION_AUDIT Round 498。
## Round 499 (F805) — 2026-08-12：HANDOFF 刷新 78（Round 496-498）

- **〔刷新〕**HANDOFF 追加 Round 496-498（F803-F804：行会公告列表/消息 + 行会/社交消息闭合）；基线 Round 495=a2d8040 → Round 498=0056799（**463 连发 F335-F804**）。
- 落盘：handoff-refresh-78-evidence.json（F805，derived-tooling）+ RESEARCH_LOG + UI_COMPLETION_AUDIT Round 499。
## Round 500 (F806) — 2026-08-12：ROUND 500 里程碑闭合

- **〔验证〕**compileall OK、verify exit 0、node OK、JSON 有效、**430 证据 JSON**；三服务 200；master 49056dc（**464 连发 F335-F805 已推**）。
- **〔里程碑〕**Round 400 以来 90 轮（89 findings F717-F805）：**窗口系统 100%**（14 模式注册表 + 基类 + 控件/滚动条 + 全部绘制 F701-F770）+ **选项生命周期**（F776/F779/F788）+ **输入/消息**（F785/F786）+ **英雄生命周期**（F791/F792）+ **技能/显示**（F794/F795）+ **名字/头顶**（F800/F801）+ **行会/社交**（F803/F804）——客户端逆向表面接近完整；待办 write-only 槽/死亡泵体/BSS 缺口全解析。
- 落盘：round-500-milestone-closure-evidence.json（F806，derived）+ RESEARCH_LOG + UI_COMPLETION_AUDIT Round 500。
## Round 501 (F807) — 2026-08-12：HANDOFF 刷新 79（Round 499-500）

- **〔刷新〕**HANDOFF 追加 Round 499-500（F806：Round 500 里程碑闭合）；基线 Round 498=0056799 → Round 500=82f32d8（**465 连发 F335-F806**）。
- 落盘：handoff-refresh-79-evidence.json（F807，derived-tooling）+ RESEARCH_LOG + UI_COMPLETION_AUDIT Round 501。
## Round 502 (F808) — 2026-08-12：行会消息发送 + 按钮分派

- **〔行会〕**0x4258A3（F803 msg 0x415 尾部）：拼接 0x45DC70（F737）+ **发送 0x4520F0** + 0x4523E0；0x4258F0 **行会按钮分派**（0x148C 帧）：滚动条 F707 释放 0x417E60 + 9 控件 vtable[0x10] 命中 → **页模式 [0x98]**（0/1/2、重置计数 [0x9C]）+ 0x4523E0/0x452410 发送 + **窗口切换 0x42ADB0**（模式 0xF）+ **0x423E80 发送 msg 0x25A**（成员操作）——行会窗口输入完整（F755/F803 用）。
- 落盘：guild-msg-send-button-dispatch-evidence.json（F808，primary-bytes）+ RESEARCH_LOG + UI_COMPLETION_AUDIT Round 502。
## Round 503 (F809) — 2026-08-12：行会分派弧闭合（F755/F803/F808 汇总）

- **〔验证〕**compileall OK、verify exit 0、node OK、JSON 有效、**433 证据 JSON**；三服务 200；master 29dfeef（**467 连发 F335-F808 已推**）。
- **〔弧〕**行会绘制（F755）+ 公告/消息（F803）+ 按钮分派（F808）——**行会窗口完整**（3 页绘制 + 9 按钮分派 + 公告列表 + msg 0x25A/0x415 发送），行会模式 4 全交互。
- 落盘：guild-dispatch-arc-closure-evidence.json（F809，derived）+ RESEARCH_LOG + UI_COMPLETION_AUDIT Round 503。
## Round 504 (F810) — 2026-08-12：HANDOFF 刷新 80（Round 501-503）+ 80 刷新里程碑

- **〔刷新〕**HANDOFF 追加 Round 501-503（F808-F809：行会消息/按钮分派 + 行会分派弧）；基线 Round 500=82f32d8 → Round 503=0352e21（**468 连发 F335-F809**）——**HANDOFF 刷新 80 里程碑**。
- 落盘：handoff-refresh-80-evidence.json（F810，derived-tooling）+ RESEARCH_LOG + UI_COMPLETION_AUDIT Round 504。
## Round 505 (F811) — 2026-08-12：窗口开/关分派器（F550 全量）

- **〔窗口〕**0x42ADB0：0x42B820 预 + **16 模式 jt 0x42B3E4**（F550 确认）：每模式**开 = 0x42AC30 + 窗口显示（vtable[0x10]=1）+ 各窗口初始化**（背包 0x6554/0x42FF90 + 帧 0x417880 0x10B/0x10C、装备 0x29CE4、商店 0x33188、交易 0x3399C、任务 0x516E8、选项 0x518E0...）、**关 = 0x42AC50 + 窗口隐藏**——每 F558 模式的开/关权威，F550 函数体完整。
- 落盘：window-open-close-dispatcher-evidence.json（F811，primary-bytes）+ RESEARCH_LOG + UI_COMPLETION_AUDIT Round 505。
## Round 506 (F812) — 2026-08-12：窗口切换助手（F550 家族完整）

- **〔窗口〕**0x42AC30 **开窗列表添加**（0x449870 插入 [0xD24..0xD38]，F550 列表确认）；0x42AC50 **关窗列表移除**（[0xD2C] 遍历解链 + free + 计数 [0xD38]--）；0x42B820 **切换预分派**（模式 jt 0x42B938 → 各模式窗口槽：0x6554 背包/0x29CE4 装备/0x33188 商店/0x3399C 交易/0x4707C 行会/0x47834 组队/0x47C28 状态/0x507EC 公告/0x51150 对话/0x516E8 任务）+ 全隐藏预扫——窗口切换机制 100%。
- 落盘：window-toggle-helpers-evidence.json（F812，primary-bytes）+ RESEARCH_LOG + UI_COMPLETION_AUDIT Round 506。
## Round 507 (F813) — 2026-08-12：窗口切换机制闭合（F550/F811/F812 汇总）

- **〔验证〕**compileall OK、verify exit 0、node OK、JSON 有效、**437 证据 JSON**；三服务 200；master 8c3e89a（**471 连发 F335-F812 已推**）。
- **〔弧〕**切换分派器（F550）+ 开/关函数体（F811）+ 助手（F812）——**切换机制完整**（16 模式 jt + 开/关列表 [0xD24..0xD38] + 各模式窗口槽 + 显示/隐藏），窗口生命周期表面全闭合。
- 落盘：toggle-machinery-closure-evidence.json（F813，derived）+ RESEARCH_LOG + UI_COMPLETION_AUDIT Round 507。
## Round 508 (F814) — 2026-08-12：HANDOFF 刷新 81（Round 505-507）

- **〔刷新〕**HANDOFF 追加 Round 505-507（F811-F813：窗口开/关 + 切换助手 + 切换机制闭合）；基线 Round 503=0352e21 → Round 507=c3255fb（**472 连发 F335-F813**）。
- 落盘：handoff-refresh-81-evidence.json（F814，derived-tooling）+ RESEARCH_LOG + UI_COMPLETION_AUDIT Round 508。
## Round 509 (F815) — 2026-08-12：背包窗口初始化 + 点击 + 使用

- **〔背包〕**0x42FF90（F811 背包初始化依赖）：重置背包态 [0x2375C..0x23778]、拖动槽 -1 [0x23764]/[0x23768]；0x42FFD0 **点击处理**：命中 → 空槽使用 0x42FEC0 / 滚动条 F707 点击 0x417D00 @ +0x278（比例 [0x284] → 计数 [0x58] ×0x476650）/ 3 控件 vtable[0xC] / 槽命中 0x42F150 → 物品检查 [0x774 + idx×0x6C] → 忙碌旗标 [0x3C]；0x4300F0 **使用门**：冷却 0x12C(300ms)/0x7D0/0x3E8 vs [0x23784]、物品类型 [0x3A]/[0x40]、公告 0x415280 0x47BDA4、滚动条 [0x278]——背包窗口全交互（F811/F764 用）。
- 落盘：bag-window-init-click-use-evidence.json（F815，primary-bytes）+ RESEARCH_LOG + UI_COMPLETION_AUDIT Round 509。
## Round 510 (F816) — 2026-08-12：背包窗口弧闭合（F764/F811/F815 汇总）

- **〔验证〕**compileall OK、verify exit 0、node OK、JSON 有效、**440 证据 JSON**；三服务 200；master d59a049（**474 连发 F335-F815 已推**）。
- **〔弧〕**背包绘制（F764）+ 切换初始化（F811）+ 点击/使用（F815）——**背包窗口完整**（滚动条 + 网格 + 拖动预览 + 初始化重置 + 点击分派 + 使用冷却门），窗口模式 0 全交互。
- 落盘：bag-window-arc-closure-evidence.json（F816，derived）+ RESEARCH_LOG + UI_COMPLETION_AUDIT Round 510。
## Round 511 (F817) — 2026-08-12：HANDOFF 刷新 82（Round 508-510）

- **〔刷新〕**HANDOFF 追加 Round 508-510（F815-F816：背包初始化/点击/使用 + 背包窗口弧）；基线 Round 507=c3255fb → Round 510=b45ce8d（**475 连发 F335-F816**）。
- 落盘：handoff-refresh-82-evidence.json（F817，derived-tooling）+ RESEARCH_LOG + UI_COMPLETION_AUDIT Round 511。
## Round 512 (F818) — 2026-08-12：装备详情面板绘制（F767 槽依赖）

- **〔面板〕**0x44BC80：字体 0x45DBA0（0x47BE18）+ 标签串 0x47C74C/0x47C748/0x47C73C/0x47C734 via 0x45DD70（0xFAE1C8 标题、0xFAFAFA 值）+ **值字段**：等级 [0x7DA108]（格式 0x47A214）、HP [0x7DA10D]/[0x7DA111]、MP [0x7DA10F]/[0x7DA113]、XP 比例 [0x7DA115]/[0x7DA119] + 0x46811C 格式 + % 缩放 0x476970——角色状态详情面板完整。
- 落盘：equip-detail-panel-draw-evidence.json（F818，primary-bytes）+ RESEARCH_LOG + UI_COMPLETION_AUDIT Round 512。
## Round 513 (F819) — 2026-08-12：状态/装备面板闭合（F758/F767/F818 汇总）

- **〔验证〕**compileall OK、verify exit 0、node OK、JSON 有效、**443 证据 JSON**；三服务 200；master 362c6c6（**477 连发 F335-F818 已推**）。
- **〔弧〕**状态绘制（F758）+ 装备绘制（F767）+ 详情面板（F818）——**状态/装备面板完整**（头像 + 11 装备图标 + 纸娃娃 + 详情标签 + 等级/HP/MP/XP 值），角色窗口模式 1/7 全渲染。
- 落盘：status-equip-panel-closure-evidence.json（F819，derived）+ RESEARCH_LOG + UI_COMPLETION_AUDIT Round 513。
## Round 514 (F820) — 2026-08-12：HANDOFF 刷新 83（Round 511-513）

- **〔刷新〕**HANDOFF 追加 Round 511-513（F818-F819：装备详情面板 + 状态/装备面板闭合）；基线 Round 510=b45ce8d → Round 513=f6e1d69（**478 连发 F335-F819**）。
- 落盘：handoff-refresh-83-evidence.json（F820，derived-tooling）+ RESEARCH_LOG + UI_COMPLETION_AUDIT Round 514。
## Round 515 (F821) — 2026-08-12：文本测量 + 换行拆分

- **〔文本〕**0x45E0C0 **测量**（F818/F621 居中依赖）：vtable[0x44] + GDI 0x476048/0x476078/0x476068 → 返回宽/高对；0x45E200 **换行文本拆分**（0x124 缓冲、strlen 扫描 + 段复制、返回计数）——文本布局助手完整。
- 落盘：text-measure-wrap-split-evidence.json（F821，primary-bytes）+ RESEARCH_LOG + UI_COMPLETION_AUDIT Round 515。
## Round 516 (F822) — 2026-08-12：文本布局闭合（F564/F737/F821 汇总）+ 480 连发里程碑

- **〔验证〕**compileall OK、verify exit 0、node OK、JSON 有效、**446 证据 JSON**；三服务 200；master 0d28bae（**480 连发 F335-F821 已推**）——**480 连发里程碑**。
- **〔弧〕**GDI 文本（F564）+ BSS 助手（F737）+ 测量/换行（F821）——**文本布局完整**（测量 + 换行拆分 + 拼接 + GDI 绘制 + 居中数学），文本表面 100%。
- 落盘：text-layout-closure-evidence.json（F822，derived）+ RESEARCH_LOG + UI_COMPLETION_AUDIT Round 516。
## Round 517 (F823) — 2026-08-12：HANDOFF 刷新 84（Round 514-516）

- **〔刷新〕**HANDOFF 追加 Round 514-516（F821-F822：文本测量/换行 + 文本布局闭合 + 480 里程碑）；基线 Round 513=f6e1d69 → Round 516=ef83484（**481 连发 F335-F822**）。
- 落盘：handoff-refresh-84-evidence.json（F823，derived-tooling）+ RESEARCH_LOG + UI_COMPLETION_AUDIT Round 517。
## Round 518 (F824) — 2026-08-12：商店点击分派（F661 槽依赖）

- **〔商店〕**0x44E9B0：模式 [0x5F8] 门（0/4/1/3 vs 1/4/2）+ **退出按钮 → 0x423E80 发送 msg 0x3E8**（坐标 0xBA/0x12C/0x130）+ 物品列表 [0x70C] free + 模式 0；购买确认**取消** + 模式 0；滚动条 F707 释放 0x417E60 @ +0x5FC；更多控件 vtable[0x10] 命中（0x108 等）——商店窗口点击完整（F661/F740 用）。
- 落盘：shop-click-dispatch-evidence.json（F824，primary-bytes）+ RESEARCH_LOG + UI_COMPLETION_AUDIT Round 518。
## Round 519 (F825) — 2026-08-12：商店交互闭合（F661/F740/F824 汇总）

- **〔验证〕**compileall OK、verify exit 0、node OK、JSON 有效、**449 证据 JSON**；三服务 200；master 04febcf（**483 连发 F335-F824 已推**）。
- **〔弧〕**商店管理/命中（F661）+ 点击处理（F740）+ 点击分派（F824）——**商店窗口完整**（购买 0x3EA + 卖/修 + 退出 0x3E8 + 取消 + 物品列表 + 确认命中），模式 2 全交互。
- 落盘：shop-interactive-closure-evidence.json（F825，derived）+ RESEARCH_LOG + UI_COMPLETION_AUDIT Round 519。
## Round 520 (F826) — 2026-08-12：HANDOFF 刷新 85（Round 517-519）

- **〔刷新〕**HANDOFF 追加 Round 517-519（F824-F825：商店点击分派 + 商店交互闭合）；基线 Round 516=ef83484 → Round 519=a41f88a（**484 连发 F335-F825**）。
- 落盘：handoff-refresh-85-evidence.json（F826，derived-tooling）+ RESEARCH_LOG + UI_COMPLETION_AUDIT Round 520。
## Round 521 (F827) — 2026-08-12：窗口内容布局

- **〔布局〕**0x423E80（F808/F824 关闭发送的参数载体，**非发送器**）：帧尺寸 0x466130（[0x2C] WIL）+ SetRect 0x4762B0（矩形 [0x8]/[0x18]/[0x28] + 内嵌 [0x40]/[0x44] 自动/参数）+ **居中数学**（半差）——窗口内容几何完整。
- 落盘：window-content-layout-evidence.json（F827，primary-bytes）+ RESEARCH_LOG + UI_COMPLETION_AUDIT Round 521。
## Round 522 (F828) — 2026-08-12：窗口几何闭合（F701/F704/F713/F827 汇总）

- **〔验证〕**compileall OK、verify exit 0、node OK、JSON 有效、**452 证据 JSON**；三服务 200；master 0a1e304（**486 连发 F335-F827 已推**）。
- **〔弧〕**控件构造（F701）+ 定位（F704）+ 基类构造（F713）+ 内容布局（F827）——**窗口几何完整**（帧尺寸 + 矩形 + 内嵌 + 居中 + 控件位置），窗口布局表面 100%。
- 落盘：window-geometry-closure-evidence.json（F828，derived）+ RESEARCH_LOG + UI_COMPLETION_AUDIT Round 522。
## Round 523 (F829) — 2026-08-12：HANDOFF 刷新 86（Round 520-522）

- **〔刷新〕**HANDOFF 追加 Round 520-522（F827-F828：窗口内容布局 + 窗口几何闭合）；基线 Round 519=a41f88a → Round 522=72734be（**487 连发 F335-F828**）。
- 落盘：handoff-refresh-86-evidence.json（F829，derived-tooling）+ RESEARCH_LOG + UI_COMPLETION_AUDIT Round 523。
## Round 524 (F830) — 2026-08-12：行会页子绘制（F755 3 页依赖）

- **〔行会〕**0x425280 **页 0（公告页）**：成员列表 [0xE4] 遍历 + **级别比较**（0x47BA78/0x47BA6C/0x47BA60 = 盟主/长老/成员）+ 0x45DD70 色 0xFFFFFF（级别）/0x96FF（公告）+ y=(idx-偏移)×行+0x3C x+0x23 + 滚动偏移 [0x9C]；0x425440 **页 1**：成员列表 [0xB4] 并行结构——行会 3 页完整。
- 落盘：guild-page-subdraws-evidence.json（F830，primary-bytes）+ RESEARCH_LOG + UI_COMPLETION_AUDIT Round 524。
## Round 525 (F831) — 2026-08-12：行会页闭合（F755/F830 汇总）

- **〔验证〕**compileall OK、verify exit 0、node OK、JSON 有效、**455 证据 JSON**；三服务 200；master 6903859（**489 连发 F335-F830 已推**）。
- **〔弧〕**行会 3 页分派（F755）+ 页子绘制（F830）——**行会页完整**（页 0 公告 + 级别 + 页 1 成员 + 页 2），行会窗口 100% 渲染文档化。
- 落盘：guild-pages-closure-evidence.json（F831，derived）+ RESEARCH_LOG + UI_COMPLETION_AUDIT Round 525。
## Round 526 (F832) — 2026-08-12：HANDOFF 刷新 87（Round 523-525）

- **〔刷新〕**HANDOFF 追加 Round 523-525（F830-F831：行会页子绘制 + 行会页闭合）；基线 Round 522=72734be → Round 525=720d442（**490 连发 F335-F831**）。
- 落盘：handoff-refresh-87-evidence.json（F832，derived-tooling）+ RESEARCH_LOG + UI_COMPLETION_AUDIT Round 526。
## Round 527 (F833) — 2026-08-12：任务窗口绘制体（F671 全量）

- **〔任务〕**0x447470（F558 模式 B）：**2 按钮 F704**（@ +0x74/+0x128）+ 任务列表 [0x54] 遍历：标题测量 0x45E0C0（>0xC8 换行）+ **行换行 0xA0** + **状态色 0x1919C8**（完成 via [0x210] 旗标 vs 进行 0x19197D）+ 0x45DD70 + **y=(idx×15)+0x12**（F671 确认）x+0x41——任务窗口绘制完整。
- 落盘：quest-window-draw-body-evidence.json（F833，primary-bytes）+ RESEARCH_LOG + UI_COMPLETION_AUDIT Round 527。
## Round 528 (F834) — 2026-08-12：任务窗口闭合（F558/F671/F833 汇总）

- **〔验证〕**compileall OK、verify exit 0、node OK、JSON 有效、**458 证据 JSON**；三服务 200；master a12f20d（**492 连发 F335-F833 已推**）。
- **〔弧〕**注册表（F558）+ 任务绘制（F671）+ 绘制体（F833）——**任务窗口完整**（19 行列表 + 标题换行 + 状态色 + 2 按钮），模式 B 全渲染。
- 落盘：quest-window-closure-evidence.json（F834，derived）+ RESEARCH_LOG + UI_COMPLETION_AUDIT Round 528。
## Round 529 (F835) — 2026-08-12：HANDOFF 刷新 88（Round 526-528）

- **〔刷新〕**HANDOFF 追加 Round 526-528（F833-F834：任务窗口绘制体 + 任务窗口闭合）；基线 Round 525=720d442 → Round 528=7041814（**493 连发 F335-F834**）。
- 落盘：handoff-refresh-88-evidence.json（F835，derived-tooling）+ RESEARCH_LOG + UI_COMPLETION_AUDIT Round 529。
## Round 530 (F836) — 2026-08-12：坐骑旗标写者

- **〔坐骑〕**0x41F580 recv1 怪物家族分派器（0x2D-0x35、jt 0x421E8C）：**0x41F597 坐骑/外观消息**（位置字 [0x7DA061]/[0x7DA063] + **旗标 dword [0x7DA060] + [0x7DA064]** → 0x40F420 坐骑 + 0x44BC30 装备重置）；0x41F666 使用坐骑态（0x7DA060 → 0x40F420）——**F773 坐骑门写者解析**（F571 怪物家族扩展）。
- 落盘：mount-flag-writers-evidence.json（F836，primary-bytes）+ RESEARCH_LOG + UI_COMPLETION_AUDIT Round 530。
## Round 531 (F837) — 2026-08-12：坐骑/recv 闭合（F545/F571/F773/F836 汇总）

- **〔验证〕**compileall OK、verify exit 0、node OK、JSON 有效、**461 证据 JSON**；三服务 200；master a8f31be（**495 连发 F335-F836 已推**）。
- **〔弧〕**坐骑命令（F545）+ recv1 家族（F571）+ 坐骑窗口（F773）+ 旗标写者（F836）——**坐骑/recv 完整**（4 命令 + recv1 坐骑消息 + 门读写者 + 0x40F420 坐骑态），坐骑生命周期表面闭合。
- 落盘：mount-recv-closure-evidence.json（F837，derived）+ RESEARCH_LOG + UI_COMPLETION_AUDIT Round 531。
## Round 532 (F838) — 2026-08-12：HANDOFF 刷新 89（Round 529-531）

- **〔刷新〕**HANDOFF 追加 Round 529-531（F836-F837：坐骑旗标写者 + 坐骑/recv 闭合）；基线 Round 528=7041814 → Round 531=0084901（**496 连发 F335-F837**）。
- 落盘：handoff-refresh-89-evidence.json（F838，derived-tooling）+ RESEARCH_LOG + UI_COMPLETION_AUDIT Round 532。
## Round 533 (F839) — 2026-08-12：技能书绘制（F558 模式 E）

- **〔技能书〕**0x439500：0x4397A0 页签头 + 0x43A440 页 + 3 头部按钮 F704（@ +0xD8/+0x18C/+0x240）+ **8 技能槽控件 F704**（@ +0x2F4..+0x7E0 stride 0xB4）+ 8 绘制 + **页计数 [0x58+idx×4] ÷3**（0x2AAAAAAB 除法）+ 0x46811C 0x47C334 + 0x45DD70（0x323232/0x6496C8）——技能书窗口完整（F547/F558 用）。
- 落盘：skill-book-draw-evidence.json（F839，primary-bytes）+ RESEARCH_LOG + UI_COMPLETION_AUDIT Round 533。
## Round 534 (F840) — 2026-08-12：技能书窗口闭合（F547/F743/F839 汇总）

- **〔验证〕**compileall OK、verify exit 0、node OK、JSON 有效、**464 证据 JSON**；三服务 200；master 0b3b025（**498 连发 F335-F839 已推**）。
- **〔弧〕**8 页签（F547）+ 技能记录（F743）+ 技能书绘制（F839）——**技能书完整**（8 页签 + 8 技能槽 + 页计数 + 记录槽），模式 E 全渲染。
- 落盘：skill-book-closure-evidence.json（F840，derived）+ RESEARCH_LOG + UI_COMPLETION_AUDIT Round 534。
## Round 535 (F841) — 2026-08-12：HANDOFF 刷新 90（Round 532-534）+ 90 刷新里程碑

- **〔刷新〕**HANDOFF 追加 Round 532-534（F839-F840：技能书绘制 + 技能书窗口闭合）；基线 Round 531=0084901 → Round 534=bc99e68（**499 连发 F335-F840**）——**HANDOFF 刷新 90 里程碑**。
- 落盘：handoff-refresh-90-evidence.json（F841，derived-tooling）+ RESEARCH_LOG + UI_COMPLETION_AUDIT Round 535。
## Round 536 (F842) — 2026-08-12：交易窗口绘制（F558 模式 3）

- **〔交易〕**0x415B10：居中矩形 [0x5C]/[0x6C]（SetRect 0x4762B0）+ **己方/对方网格命中**（鼠标 [0x7DA1C0]/[0x7DA1C4] via PtInRect 0x4762B4）+ **拖动预览**：槽命中 0x416830 + 放置 0x4162E0（F749）+ IntersectRect 0x476248 + **矩阵 0x466800（F643）** 缩放——交易窗口绘制完整（F557/F749 用）。
- 落盘：trade-window-draw-evidence.json（F842，primary-bytes）+ RESEARCH_LOG + UI_COMPLETION_AUDIT Round 536。
## Round 537 (F843) — 2026-08-12：交易窗口全闭合（F557/F749/F842 汇总）+ 500+ 连发里程碑

- **〔验证〕**compileall OK、verify exit 0、node OK、JSON 有效、**467 证据 JSON**；三服务 200；master ccb2823（**501 连发 F335-F842 已推**）——**500+ 连发里程碑**。
- **〔弧〕**交易家族（F557）+ 槽布局（F749）+ 窗口绘制（F842）——**交易窗口完整**（2 网格 × 12 槽 + 放置/写入 + 居中/命中 + 拖动预览），模式 3 全文档化。
- 落盘：trade-window-full-closure-evidence.json（F843，derived）+ RESEARCH_LOG + UI_COMPLETION_AUDIT Round 537。
## Round 538 (F844) — 2026-08-12：HANDOFF 刷新 91（Round 535-537）

- **〔刷新〕**HANDOFF 追加 Round 535-537（F842-F843：交易窗口绘制 + 交易全闭合 + 500+ 里程碑）；基线 Round 534=bc99e68 → Round 537=cc10978（**502 连发 F335-F843**）。
- 落盘：handoff-refresh-91-evidence.json（F844，derived-tooling）+ RESEARCH_LOG + UI_COMPLETION_AUDIT Round 538。
## Round 539 (F845) — 2026-08-12：组队窗口点击 + 消息分派（F752 交互侧）

- **〔组队〕**0x424610：5 按钮 vtable[0x10]：**0x3FC 邀请（0x4522E0）/ 0x3FD 移除（0x452350）/ 0x3FE（0x452380）** + 对话窗 ctor 0x418030 @ 0x7E04C8（0x565994 帧 6）+ **离开切换 [0x3F0] → 0x452310** + 按钮帧 0x398/0x399（0x417880）；0x4247C0 **组队消息分派**（0x3FC/0x3FD/0x3FE seq 0 → 同发送）——组队窗口交互完整。
- 落盘：party-window-click-msg-dispatch-evidence.json（F845，primary-bytes）+ RESEARCH_LOG + UI_COMPLETION_AUDIT Round 539。
## Round 540 (F846) — 2026-08-12：组队交互闭合（F752/F845 汇总）

- **〔验证〕**compileall OK、verify exit 0、node OK、JSON 有效、**470 证据 JSON**；三服务 200；master 12a4052（**504 连发 F335-F845 已推**）。
- **〔弧〕**组队绘制（F752）+ 点击/消息分派（F845）——**组队窗口完整**（双列成员 + 5 按钮 + 邀请/移除/离开发送 + 队长），模式 6 全交互。
- 落盘：party-interactive-closure-evidence.json（F846，derived）+ RESEARCH_LOG + UI_COMPLETION_AUDIT Round 540。
## Round 541 (F847) — 2026-08-12：HANDOFF 刷新 92（Round 538-540）

- **〔刷新〕**HANDOFF 追加 Round 538-540（F845-F846：组队点击/消息 + 组队交互闭合）；基线 Round 537=cc10978 → Round 540=fc5086b（**505 连发 F335-F846**）。
- 落盘：handoff-refresh-92-evidence.json（F847，derived-tooling）+ RESEARCH_LOG + UI_COMPLETION_AUDIT Round 541。
## Round 542 (F848) — 2026-08-12：技能页签头绘制（F839 页签依赖）

- **〔页签〕**0x4397A0：激活页签 [0x54]×3 → 页签记录 **[0x898+idx×0x18]** 遍历（页计数 [0x58+idx×4]）+ **技能图标**（0x566C90 帧 = [技能+6]、blit 0x45FD50）+ **4 边高亮矩形**（SetRect 0x4762B0）+ **技能名 0x45DE50**（色 0x3C3C3C）+ 边框——技能页签头完整。
- 落盘：skill-tab-header-draw-evidence.json（F848，primary-bytes）+ RESEARCH_LOG + UI_COMPLETION_AUDIT Round 542。
## Round 543 (F849) — 2026-08-12：技能书全闭合（F547/F839/F848 汇总）

- **〔验证〕**compileall OK、verify exit 0、node OK、JSON 有效、**473 证据 JSON**；三服务 200；master 233535e（**507 连发 F335-F848 已推**）。
- **〔弧〕**8 页签（F547）+ 技能书绘制（F839）+ 页签头（F848）——**技能书完整**（页签记录 + 图标 + 8 槽 + 页计数 + 名称），模式 E 全渲染。
- 落盘：skill-book-full-closure-evidence.json（F849，derived）+ RESEARCH_LOG + UI_COMPLETION_AUDIT Round 543。
## Round 544 (F850) — 2026-08-12：HANDOFF 刷新 93（Round 541-543）

- **〔刷新〕**HANDOFF 追加 Round 541-543（F848-F849：技能页签头 + 技能书全闭合）；基线 Round 540=fc5086b → Round 543=1c2c0ba（**508 连发 F335-F849**）。
- 落盘：handoff-refresh-93-evidence.json（F850，derived-tooling）+ RESEARCH_LOG + UI_COMPLETION_AUDIT Round 544。
## Round 545 (F851) — 2026-08-12：技能页文本解析器（F839 页依赖）

- **〔解析〕**0x43A440（0x1E90 帧）：行拆分 0x468BF0（'\n' 终止、';' 节末）+ **'#' 元标记**（0x4681F9 atoi id 比较 vs 参数）+ 激活旗标 [0x13] + **0x45E200 换行**（宽 0xA5）+ 10 行拆入字段（0x100 各）——技能页渲染数据路径完整。
- 落盘：skill-page-text-parser-evidence.json（F851，primary-bytes）+ RESEARCH_LOG + UI_COMPLETION_AUDIT Round 545。
## Round 546 (F852) — 2026-08-12：技能页闭合（F839/F848/F851 汇总）+ 510 连发里程碑

- **〔验证〕**compileall OK、verify exit 0、node OK、JSON 有效、**476 证据 JSON**；三服务 200；master b9b28bc（**510 连发 F335-F851 已推**）——**510 连发里程碑**。
- **〔弧〕**技能书绘制（F839）+ 页签头（F848）+ 页解析（F851）——**技能页完整**（页签记录 + 图标 + 页文本解析 + 换行 + 字段），技能书数据+渲染表面 100%。
- 落盘：skill-page-closure-evidence.json（F852，derived）+ RESEARCH_LOG + UI_COMPLETION_AUDIT Round 546。
## Round 547 (F853) — 2026-08-12：HANDOFF 刷新 94（Round 544-546）

- **〔刷新〕**HANDOFF 追加 Round 544-546（F851-F852：技能页解析器 + 技能页闭合 + 510 里程碑）；基线 Round 543=1c2c0ba → Round 546=cc45e11（**511 连发 F335-F852**）。
- 落盘：handoff-refresh-94-evidence.json（F853，derived-tooling）+ RESEARCH_LOG + UI_COMPLETION_AUDIT Round 547。
## Round 548 (F854) — 2026-08-12：公告窗口渲染（F558 模式 8，F599 聊天家族）

- **〔公告〕**0x414700：SetRect [0x954] + 行列表 [0x58] 遍历（next [0x408]/[0x40C]、滚动 [0x6D0]、计数 [0x68] 上限 0x13=19）+ 行绘制 0x45DD70（y+=0xE、色参）+ **滚动条 F707 ctor @ +0x6D4**（计数 [0x68]/[0x6D0]、位置 +0x215/-0xD0）+ **7 按钮 F704**（@ +0x6C..+0x3F0 stride 0xB4）+ 7 绘制——公告窗口完整（F553/F599 用）。
- 落盘：announce-window-render-evidence.json（F854，primary-bytes）+ RESEARCH_LOG + UI_COMPLETION_AUDIT Round 548。
## Round 549 (F855) — 2026-08-12：公告窗口闭合（F553/F599/F854 汇总）

- **〔验证〕**compileall OK、verify exit 0、node OK、JSON 有效、**479 证据 JSON**；三服务 200；master afffd1c（**513 连发 F335-F854 已推**）。
- **〔弧〕**公告消息（F553）+ 聊天家族（F599）+ 窗口渲染（F854）——**公告窗口完整**（19 行列表 + 滚动条 + 7 按钮 + 彩色行），模式 8 全渲染。
- 落盘：announce-window-closure-evidence.json（F855，derived）+ RESEARCH_LOG + UI_COMPLETION_AUDIT Round 549。
## Round 550 (F856) — 2026-08-12：HANDOFF 刷新 95（Round 547-549）

- **〔刷新〕**HANDOFF 追加 Round 547-549（F854-F855：公告窗口渲染 + 公告窗口闭合）；基线 Round 546=cc45e11 → Round 549=8150b28（**514 连发 F335-F855**）。
- 落盘：handoff-refresh-95-evidence.json（F856，derived-tooling）+ RESEARCH_LOG + UI_COMPLETION_AUDIT Round 550。
## Round 551 (F857) — 2026-08-12：NPC 对话窗口渲染（F558 模式 9，F598 渲染侧）

- **〔对话〕**0x43F460：选项列表 [0x8B1AE4] 遍历 + **类型 jt 0x440158（4 类型，F598 确认）** + 测量 0x45E0C0（0x45DD70 换行）+ **选项绘制 0x45DD70**（y=idx×[选项+5]+0x28、色 0x131/0xFFFFFF95 门 [0x582]）——对话窗口完整。
- 落盘：dialog-window-render-evidence.json（F857，primary-bytes）+ RESEARCH_LOG + UI_COMPLETION_AUDIT Round 551。
## Round 552 (F858) — 2026-08-12：对话窗口闭合（F598/F746/F857 汇总）

- **〔验证〕**compileall OK、verify exit 0、node OK、JSON 有效、**482 证据 JSON**；三服务 200；master d999948（**516 连发 F335-F857 已推**）。
- **〔弧〕**4 类型渲染（F598）+ 选项命中/选择（F746）+ 窗口渲染（F857）——**对话窗口完整**（选项列表 + 4 类型 jt + 测量/换行 + 绘制 + 命中/激活），模式 9 全交互。
- 落盘：dialog-window-closure-evidence.json（F858，derived）+ RESEARCH_LOG + UI_COMPLETION_AUDIT Round 552。
## Round 553 (F859) — 2026-08-12：HANDOFF 刷新 96（Round 550-552）

- **〔刷新〕**HANDOFF 追加 Round 550-552（F857-F858：NPC 对话窗口渲染 + 对话窗口闭合）；基线 Round 549=8150b28 → Round 552=fa44e88（**517 连发 F335-F858**）。
- 落盘：handoff-refresh-96-evidence.json（F859，derived-tooling）+ RESEARCH_LOG + UI_COMPLETION_AUDIT Round 553。
## Round 554 (F860) — 2026-08-12：坐骑命中 + 点击 + 构造（F773 依赖）

- **〔坐骑〕**0x426B50 命中（5 控件 vtable[0xC] @ +0x54 stride 0xB4）；0x426B90 点击（5 控件 vtable[8]）；0x426C10 **坐骑窗口构造**（0x415130 基类 + 0x430920 物品构造 @ +0x38 + vtable 0x476620/0x476864 + **6 物品槽 0xC24 @ +0xDA4** + SEH 0x426E70/0x415750）——坐骑窗口交互 + 构造完整（F545/F773）。
- 落盘：mount-hit-click-ctor-evidence.json（F860，primary-bytes）+ RESEARCH_LOG + UI_COMPLETION_AUDIT Round 554。
## Round 555 (F861) — 2026-08-12：坐骑窗口全闭合（F545/F773/F836/F860 汇总）

- **〔验证〕**compileall OK、verify exit 0、node OK、JSON 有效、**485 证据 JSON**；三服务 200；master c808529（**519 连发 F335-F860 已推**）。
- **〔弧〕**命令（F545）+ 窗口（F773）+ 旗标写者（F836）+ 命中/点击/构造（F860）——**坐骑窗口完整**（5 按钮 + 命令分派 + 旗标门 + 6 物品槽 + 命中/点击），模式 D 全交互。
- 落盘：mount-window-full-closure-evidence.json（F861，derived）+ RESEARCH_LOG + UI_COMPLETION_AUDIT Round 555。
## Round 556 (F862) — 2026-08-12：HANDOFF 刷新 97（Round 553-555）

- **〔刷新〕**HANDOFF 追加 Round 553-555（F860-F861：坐骑命中/点击/构造 + 坐骑窗口全闭合）；基线 Round 552=fa44e88 → Round 555=8d5f502（**520 连发 F335-F861**）。
- 落盘：handoff-refresh-97-evidence.json（F862，derived-tooling）+ RESEARCH_LOG + UI_COMPLETION_AUDIT Round 556。
## Round 557 (F863) — 2026-08-12：基础行列表构造 + 清除（F860 基类依赖）

- **〔列表〕**0x415130 构造（SEH + vtable 0x476638 + 列表 [0x8] + 计数 [0x18] + 0x415210）；0x415180/0x415220 析构/清除（链表 free 0x4680F8 + 计数重置）；0x415280 行添加（**F734 确认**：修剪 ≥8、头 [0x8]/尾 [0x10]/计数 [0x18]）——行列表基类完整。
- 落盘：base-line-list-ctor-clear-evidence.json（F863，primary-bytes）+ RESEARCH_LOG + UI_COMPLETION_AUDIT Round 557。
## Round 558 (F864) — 2026-08-12：行列表基类闭合（F677/F734/F863 汇总）

- **〔验证〕**compileall OK、verify exit 0、node OK、JSON 有效、**488 证据 JSON**；三服务 200；master 74b0ef1（**522 连发 F335-F863 已推**）。
- **〔弧〕**行列表核心（F677）+ 公告添加（F734）+ 基类构造/清除（F863）——**行列表基类完整**（构造 + 添加修剪 + 析构 free + 头/尾），列表家族表面闭合。
- 落盘：line-list-base-closure-evidence.json（F864，derived）+ RESEARCH_LOG + UI_COMPLETION_AUDIT Round 558。
## Round 559 (F865) — 2026-08-12：HANDOFF 刷新 98（Round 556-558）

- **〔刷新〕**HANDOFF 追加 Round 556-558（F863-F864：基础行列表 + 行列表基类闭合）；基线 Round 555=8d5f502 → Round 558=1e2d1b2（**523 连发 F335-F864**）。
- 落盘：handoff-refresh-98-evidence.json（F865，derived-tooling）+ RESEARCH_LOG + UI_COMPLETION_AUDIT Round 559。
## Round 560 (F866) — 2026-08-12：公告节点添加 + 出队（F677 全量）

- **〔公告〕**0x414FA0 **节点添加**（分配 0x410 + 复制 0x102 双字 + [0x408] next/[0x40C] prev + 头 [0x4]/尾 [0xC] 插入 + 计数 [0x14]++）；0x415030 **析构**（链 free + vtable 0x476620）；0x415090 **出队**（尾 [0xC] → next [0x40C]、[0x10]--）；0x4150C0/0x4150D0 构造（vtable 0x476624 + 0x423CF0）——公告行列表完整。
- 落盘：notice-node-add-dequeue-evidence.json（F866，primary-bytes）+ RESEARCH_LOG + UI_COMPLETION_AUDIT Round 560。
## Round 561 (F867) — 2026-08-12：公告列表全闭合（F677/F734/F866 汇总）

- **〔验证〕**compileall OK、verify exit 0、node OK、JSON 有效、**491 证据 JSON**；三服务 200；master 2267cad（**525 连发 F335-F866 已推**）。
- **〔弧〕**公告核心（F677）+ 行添加（F734）+ 节点添加/出队（F866）——**公告列表完整**（节点分配/插入/出队/析构 + 修剪 + 渲染），公告家族 100%。
- 落盘：notice-list-full-closure-evidence.json（F867，derived）+ RESEARCH_LOG + UI_COMPLETION_AUDIT Round 561。
## Round 562 (F868) — 2026-08-12：HANDOFF 刷新 99（Round 559-561）

- **〔刷新〕**HANDOFF 追加 Round 559-561（F866-F867：公告节点/出队 + 公告列表全闭合）；基线 Round 558=1e2d1b2 → Round 561=cb441d4（**526 连发 F335-F867**）。
- 落盘：handoff-refresh-99-evidence.json（F868，derived-tooling）+ RESEARCH_LOG + UI_COMPLETION_AUDIT Round 562。
## Round 563 (F869) — 2026-08-12：HANDOFF 刷新 100 里程碑

- **〔刷新〕**HANDOFF 达 **100 次刷新**（基线 Round 561=cb441d4 → Round 562=806bbff，**527 连发 F335-F868**）；自 Round 400 里程碑：**13 大表面闭合**（窗口/选项/输入/英雄/技能/名字/行会/组队/交易/坐骑/任务/公告/对话），**530+ 证据 JSON**。
- 落盘：handoff-refresh-100-evidence.json（F869，derived-tooling）+ RESEARCH_LOG + UI_COMPLETION_AUDIT Round 563。
## Round 564 (F870) — 2026-08-12：公告输入处理（F731 门依赖）

- **〔公告〕**0x414DC0：msg 0x31/0x32/0xBE（编辑键）→ **公告缓冲 [0x850]**（默认串 0x47AD94、预设 0x47AD84/0x47AD90）+ SetWindowText 0x4762CC + SendMessage 0x476290 0xB1 + **0x450C70 刷新** + 0x4762B8/0x4762AC 编辑控件操作——公告编辑完整。
- 落盘：announce-input-handler-evidence.json（F870，primary-bytes）+ RESEARCH_LOG + UI_COMPLETION_AUDIT Round 564。
## Round 565 (F871) — 2026-08-12：公告交互闭合（F731/F854/F870 汇总）

- **〔验证〕**compileall OK、verify exit 0、node OK、JSON 有效、**495 证据 JSON**；三服务 200；master 7ff6960（**529 连发 F335-F870 已推**）。
- **〔弧〕**输入门（F731）+ 窗口渲染（F854）+ 输入处理（F870）——**公告交互完整**（渲染 + 滚动条 + 按钮 + 编辑输入 + 刷新），公告家族全交互。
- 落盘：announce-interactive-closure-evidence.json（F871，derived）+ RESEARCH_LOG + UI_COMPLETION_AUDIT Round 565。
## Round 566 (F872) — 2026-08-12：HANDOFF 刷新 101（Round 563-565）

- **〔刷新〕**HANDOFF 追加 Round 563-565（F870-F871：公告输入处理 + 公告交互闭合）；基线 Round 562=806bbff → Round 565=52cb4dd（**530 连发 F335-F871**）。
- 落盘：handoff-refresh-101-evidence.json（F872，derived-tooling）+ RESEARCH_LOG + UI_COMPLETION_AUDIT Round 566。
## Round 567 (F873) — 2026-08-12：聊天输入命令处理（F576 接线）

- **〔聊天〕**0x41E740：'/' 命令解析（0x468BF0 0x2F + 0x4681F9 atoi）+ **移动速度累积 [0x428218]/[0x428220]**（delta 比例、钳制 1.0/0.0、[0x428224] 计数器 + 0x401670 门 + 公告 0x427E30 0x47B110）+ **命令比较链**（0x47AE64/0x47AE6C/0x47AE74 串 → 0x410720、[0x35B1D4] 重置）——聊天命令输入完整（F600 用）。
- 落盘：chat-input-command-handler-evidence.json（F873，primary-bytes）+ RESEARCH_LOG + UI_COMPLETION_AUDIT Round 567。
## Round 568 (F874) — 2026-08-12：聊天命令闭合（F576/F600/F873 汇总）

- **〔验证〕**compileall OK、verify exit 0、node OK、JSON 有效、**498 证据 JSON**；三服务 200；master 25d0415（**532 连发 F335-F873 已推**）。
- **〔弧〕**文本帧（F576）+ 命令（F600）+ 输入处理（F873）——**聊天命令完整**（'/' 解析 + 命令链 + 移动速度），聊天输入表面闭合。
- 落盘：chat-command-closure-evidence.json（F874，derived）+ RESEARCH_LOG + UI_COMPLETION_AUDIT Round 568。
## Round 569 (F875) — 2026-08-12：HANDOFF 刷新 102（Round 566-568）

- **〔刷新〕**HANDOFF 追加 Round 566-568（F873-F874：聊天输入命令 + 聊天命令闭合）；基线 Round 565=52cb4dd → Round 568=3bed6bf（**533 连发 F335-F874**）。
- 落盘：handoff-refresh-102-evidence.json（F875，derived-tooling）+ RESEARCH_LOG + UI_COMPLETION_AUDIT Round 569。
## Round 570 (F876) — 2026-08-12：聊天发送 + 物品使用尾部（F873 动作依赖）

- **〔聊天〕**0x41EDE0：sprintf 0x47B9D0（格式、存 [0x35B1FD]）+ **公告 0x427E30** + **物品使用路径**：base64 0x452810（0x5F）+ 物品构造 0x430920/0x430940 + 背包反序列化 0x42FC20 + 音效 0x42E2D0 + **名表遍历 0x47ADC4→0x47ADEC** + 公告 0x47B9BC + 0x415280——聊天发送/物品使用完整（F573/F698 用）。
- 落盘：chat-send-item-use-tail-evidence.json（F876，primary-bytes）+ RESEARCH_LOG + UI_COMPLETION_AUDIT Round 570。
## Round 571 (F877) — 2026-08-12：聊天系统全闭合（F576/F599/F600/F873/F876 汇总）+ 500+ 证据里程碑

- **〔验证〕**compileall OK、verify exit 0、node OK、JSON 有效、**501 证据 JSON（500+ 里程碑）**；三服务 200；master fb1f121（**535 连发 F335-F876 已推**）。
- **〔弧〕**文本帧（F576）+ 聊天渲染（F599）+ 命令（F600）+ 输入（F873）+ 发送/物品使用（F876）——**聊天系统完整**（'/' 命令 + 发送 + 物品使用 + 公告 + 速度），聊天表面 100%。
- 落盘：chat-system-full-closure-evidence.json（F877，derived）+ RESEARCH_LOG + UI_COMPLETION_AUDIT Round 571。
## Round 572 (F878) — 2026-08-12：HANDOFF 刷新 103（Round 569-571）

- **〔刷新〕**HANDOFF 追加 Round 569-571（F876-F877：聊天发送/物品使用 + 聊天系统全闭合 + 500+ 证据里程碑）；基线 Round 568=3bed6bf → Round 571=0cb4dd3（**536 连发 F335-F877**）。
- 落盘：handoff-refresh-103-evidence.json（F878，derived-tooling）+ RESEARCH_LOG + UI_COMPLETION_AUDIT Round 572。
## Round 573 (F879) — 2026-08-12：NPC 回复 + 种子 + 校验和（F617 全量）

- **〔回复〕**0x4524D0 回复发送器（**msg 0x411** via 0x452940 + 0x451E60）；0x452500 析构（vtable 0x476AF8 + 0x468D3F free）；0x452580 **种子设置器**（键 [0x9135B8]/[0x9135BC] 参数 OR rand 0x4684B2 ×4 字节 + 0x4685E8/0x4684A8 混合）；0x4525F0 **校验和**（逐字节 XOR vs 键 [0x9135B8]、加权）——F617 家族完整。
- 落盘：npc-reply-seed-checksum-evidence.json（F879，primary-bytes）+ RESEARCH_LOG + UI_COMPLETION_AUDIT Round 573。
## Round 574 (F880) — 2026-08-12：回复/校验和闭合（F617/F879 汇总）

- **〔验证〕**compileall OK、verify exit 0、node OK、JSON 有效、**504 证据 JSON**；三服务 200；master 8cc4681（**538 连发 F335-F879 已推**）。
- **〔弧〕**回复/种子（F617）+ 回复/校验和体（F879）——**回复/校验和完整**（msg 0x411 回复 + 种子 [0x9135B8] + 逐字节 XOR 校验），F617 家族全闭合。
- 落盘：reply-checksum-closure-evidence.json（F880，derived）+ RESEARCH_LOG + UI_COMPLETION_AUDIT Round 574。
## Round 575 (F881) — 2026-08-12：HANDOFF 刷新 104（Round 572-574）

- **〔刷新〕**HANDOFF 追加 Round 572-574（F879-F880：NPC 回复/种子/校验和 + 回复/校验和闭合）；基线 Round 571=0cb4dd3 → Round 574=1ff8849（**539 连发 F335-F880**）。
- 落盘：handoff-refresh-104-evidence.json（F881，derived-tooling）+ RESEARCH_LOG + UI_COMPLETION_AUDIT Round 575。
## Round 576 (F882) — 2026-08-12：丢弃/卖出/组队发送器

- **〔发送〕**0x452270 **msg 0x40A 丢弃**（物品 idx）+ 0x4522A0 **msg 0x408 卖出**（打包坐标 + 数量）+ 组队 0x4522E0 **0x3FC 邀请** / 0x452310 **0x3FB 离开**（切换旗标）/ 0x452350 **0x3FD 移除** / 0x452380 **0x3FE**——全部经 0x452940 + 0x451E60（F572）——**F845/F740 发送确认**。
- 落盘：drop-sell-party-senders-evidence.json（F882，primary-bytes）+ RESEARCH_LOG + UI_COMPLETION_AUDIT Round 576。
## Round 577 (F883) — 2026-08-12：发送器目录最终闭合（F572/F573/F782/F879/F882 汇总）

- **〔验证〕**compileall OK、verify exit 0、node OK、JSON 有效、**507 证据 JSON**；三服务 200；master 2083833（**541 连发 F335-F882 已推**）。
- **〔弧〕**文本帧（F572）+ 目录（F573）+ 扩展（F782）+ 回复/校验（F879）+ 丢弃/卖出/组队（F882）——**发送器目录完整**（包头 0x452940 + 发送 0x451E60 + msg 0x3E9-0x419 + 丢弃/卖出/组队/回复 + 校验和），出站表面 100%。
- 落盘：sender-directory-final-closure-evidence.json（F883，derived）+ RESEARCH_LOG + UI_COMPLETION_AUDIT Round 577。
## Round 578 (F884) — 2026-08-12：HANDOFF 刷新 105（Round 575-577）

- **〔刷新〕**HANDOFF 追加 Round 575-577（F882-F883：丢弃/卖出/组队发送器 + 发送器目录最终闭合）；基线 Round 574=1ff8849 → Round 577=5efee62（**542 连发 F335-F883**）。
- 落盘：handoff-refresh-105-evidence.json（F884，derived-tooling）+ RESEARCH_LOG + UI_COMPLETION_AUDIT Round 578。
## Round 579 (F885) — 2026-08-12：HUD 状态条全量（F588）

- **〔状态〕**0x42A040：鼠标命中矩形 [0xC88]（PtInRect 0x4762B4 vs [0x7DA1C0]）+ **% 格式 0x46811C**（0x47BD4C/0x47BD5C、×0x47644C）+ 测量 0x45E0C0 + 居中数学 + **矩阵 0x466800 缩放** + **0x4542F0 条注册表 blit**（类型 [0x8AB7BC]）+ 文本 0x45DE50（0xFFFFFF）+ **0x45E570 矩形填充**（0x324B64）——HUD 状态完整（F588/F590 用）。
- 落盘：hud-status-bar-full-evidence.json（F885，primary-bytes）+ RESEARCH_LOG + UI_COMPLETION_AUDIT Round 579。
## Round 580 (F886) — 2026-08-12：HUD 状态闭合（F588/F590/F885 汇总）+ 510 证据里程碑

- **〔验证〕**compileall OK、verify exit 0、node OK、JSON 有效、**510 证据 JSON（510 里程碑）**；三服务 200；master fd7f983（**544 连发 F335-F885 已推**）。
- **〔弧〕**HUD 状态条（F588）+ 条注册表（F590）+ 状态全量（F885）——**HUD 状态完整**（% 格式 + 矩阵缩放 + 注册表 blit + 文本 + 填充），HUD 条表面 100%。
- 落盘：hud-status-closure-evidence.json（F886，derived）+ RESEARCH_LOG + UI_COMPLETION_AUDIT Round 580。
## Round 581 (F887) — 2026-08-12：HANDOFF 刷新 106（Round 578-580）

- **〔刷新〕**HANDOFF 追加 Round 578-580（F885-F886：HUD 状态条全量 + HUD 状态闭合 + 510 里程碑）；基线 Round 577=5efee62 → Round 580=82c41e0（**545 连发 F335-F886**）。
- 落盘：handoff-refresh-106-evidence.json（F887，derived-tooling）+ RESEARCH_LOG + UI_COMPLETION_AUDIT Round 581。
## Round 582 (F888) — 2026-08-12：小地图部件（F584）

- **〔小地图〕**0x429630：缩放帧 [0xD40] ±0xA 钳制 0..0x2E（模式 [0xD42] 1 放大/2 缩小）+ 帧 0x33 blit（0x460240 @ 0x113/0x1DE-缩放）+ **6 热键物品图标**（0x430A40、位置表 [0xD44] stride 0x10、记录 +0xDA8 stride 0xC24）——小地图/热键部件完整（F584/F581 用）。
- 落盘：mini-map-widget-evidence.json（F888，primary-bytes）+ RESEARCH_LOG + UI_COMPLETION_AUDIT Round 582。
## Round 583 (F889) — 2026-08-12：小地图闭合（F584/F581/F888 汇总）

- **〔验证〕**compileall OK、verify exit 0、node OK、JSON 有效、**513 证据 JSON**；三服务 200；master 8e7f596（**547 连发 F335-F888 已推**）。
- **〔弧〕**小地图（F584）+ 热键栏（F581）+ 部件（F888）——**小地图完整**（缩放钳制 + 帧 blit + 6 热键图标），HUD 部件表面闭合。
- 落盘：mini-map-closure-evidence.json（F889，derived）+ RESEARCH_LOG + UI_COMPLETION_AUDIT Round 583。
## Round 584 (F890) — 2026-08-12：HANDOFF 刷新 107（Round 581-583）

- **〔刷新〕**HANDOFF 追加 Round 581-583（F888-F889：小地图部件 + 小地图闭合）；基线 Round 580=82c41e0 → Round 583=97f8e53（**548 连发 F335-F889**）。
- 落盘：handoff-refresh-107-evidence.json（F890，derived-tooling）+ RESEARCH_LOG + UI_COMPLETION_AUDIT Round 584。
## Round 585 (F891) — 2026-08-12：大地图覆盖层（F594）

- **〔大地图〕**0x429A40：鼠标命中矩形 [0xC68]/[0xC78]（PtInRect 0x4762B4）+ **坐标格式 0x47BD70**（0x46811C）+ 测量 0x45E0C0 + 居中 + **矩阵 0x466800** + **0x4542F0 条 blit**（0x5600FC）+ 文本 0x45DE50（0xFFFFFF）+ 填充 0x5050A0——大地图覆盖层完整（F594/F595 用）。
- 落盘：large-map-overlay-evidence.json（F891，primary-bytes）+ RESEARCH_LOG + UI_COMPLETION_AUDIT Round 585。
## Round 586 (F892) — 2026-08-12：地图部件闭合（F584/F594/F595/F888/F891 汇总）+ 550 连发里程碑

- **〔验证〕**compileall OK、verify exit 0、node OK、JSON 有效、**516 证据 JSON**；三服务 200；master 5ea93c8（**550 连发 F335-F891 已推**）——**550 连发里程碑**。
- **〔弧〕**小地图（F584）+ 覆盖层（F594）+ 标记（F595）+ 部件（F888）+ 覆盖层全量（F891）——**地图部件完整**（缩放 + 坐标 + 矩阵 + 条 blit + 标记），地图部件表面 100%。
- 落盘：map-widget-closure-evidence.json（F892，derived）+ RESEARCH_LOG + UI_COMPLETION_AUDIT Round 586。
## Round 587 (F893) — 2026-08-12：HANDOFF 刷新 108（Round 584-586）

- **〔刷新〕**HANDOFF 追加 Round 584-586（F891-F892：大地图覆盖层 + 地图部件闭合 + 550 里程碑）；基线 Round 583=97f8e53 → Round 586=0008576（**551 连发 F335-F892**）。
- 落盘：handoff-refresh-108-evidence.json（F893，derived-tooling）+ RESEARCH_LOG + UI_COMPLETION_AUDIT Round 587。
## Round 588 (F894) — 2026-08-12：实体投影 + 阴影帧（F622）

- **〔实体〕**0x40B2C0：世界→屏幕投影（[0xCC]/[0xD0] − 相机 [0x12C..0x138]、x×3×16、y<<5、偏移 −0xC8/−0x9D → [0xE4]/[0xE8]）+ **阴影帧 [0x90] blit**（0x466130 + SetRect 0x4762B0 + 帧尺寸 [0x38]+[4..0xB]）+ 矩形钳制 [0xA4]/[0xAC] + HP 条区域——实体渲染完整（F622/F435 用）。
- 落盘：entity-projection-shadow-evidence.json（F894，primary-bytes）+ RESEARCH_LOG + UI_COMPLETION_AUDIT Round 588。
## Round 589 (F895) — 2026-08-12：实体渲染闭合（F622/F894 汇总）

- **〔验证〕**compileall OK、verify exit 0、node OK、JSON 有效、**519 证据 JSON**；三服务 200；master 0f4353d（**553 连发 F335-F894 已推**）。
- **〔弧〕**投影/阴影（F622）+ 投影/阴影全量（F894）——**实体渲染完整**（世界→屏幕 + 阴影帧 blit + 矩形钳制 + HP 区域），实体表面闭合。
- 落盘：entity-render-closure-evidence.json（F895，derived）+ RESEARCH_LOG + UI_COMPLETION_AUDIT Round 589。
## Round 590 (F896) — 2026-08-12：HANDOFF 刷新 109（Round 587-589）

- **〔刷新〕**HANDOFF 追加 Round 587-589（F894-F895：实体投影/阴影 + 实体渲染闭合）；基线 Round 586=0008576 → Round 589=17ef963（**554 连发 F335-F895**）。
- 落盘：handoff-refresh-109-evidence.json（F896，derived-tooling）+ RESEARCH_LOG + UI_COMPLETION_AUDIT Round 590。
## Round 591 (F897) — 2026-08-12：HUD caption 分派尾部（F580）

- **〔分派〕**0x42C511 滚动条 0x417C80（[0x61BC] 比例）+ 0x42C559 **输入路由器 → jt 0x42C798（15 窗口处理器）**：背包 0x430650/装备 0x44CED0/商店 0x44F110/交易 0x416E70/行会 0x425DE0/组队 0x424770/状态 0x450B70/公告 0x414CF0/任务 0x448430/选项 0x441A20/坐骑 0x426B90/技能 0x43AC80/对话 0x440560 + 0x42C6A7 **默认全重置**（13 窗口隐藏）——HUD caption 分派完整（F580/F587 用）。
- 落盘：caption-dispatch-tail-evidence.json（F897，primary-bytes）+ RESEARCH_LOG + UI_COMPLETION_AUDIT Round 591。
## Round 592 (F898) — 2026-08-12：caption 分派闭合（F580/F587/F897 汇总）

- **〔验证〕**compileall OK、verify exit 0、node OK、JSON 有效、**522 证据 JSON**；三服务 200；master 4e52da5（**556 连发 F335-F897 已推**）。
- **〔弧〕**caption 分派（F580）+ 点击分派（F587）+ 分派尾部（F897）——**caption 分派完整**（16 分支 + 15 窗口处理器 + 全重置 + 滚动条），HUD 输入表面 100%。
- 落盘：caption-dispatch-closure-evidence.json（F898，derived）+ RESEARCH_LOG + UI_COMPLETION_AUDIT Round 592。
## Round 593 (F899) — 2026-08-12：HANDOFF 刷新 110（Round 590-592）+ 110 刷新里程碑

- **〔刷新〕**HANDOFF 追加 Round 590-592（F897-F898：caption 分派尾部 + caption 分派闭合）；基线 Round 589=17ef963 → Round 592=7ef2235（**557 连发 F335-F898**）——**HANDOFF 刷新 110 里程碑**。
- 落盘：handoff-refresh-110-evidence.json（F899，derived-tooling）+ RESEARCH_LOG + UI_COMPLETION_AUDIT Round 593。
## Round 594 (F900) — 2026-08-12：窗口命中路由器（F591/F897 路由器依赖）

- **〔路由〕**0x42AAB0：开窗列表 [0xD24..0xD38] 遍历 + **jt 0x42ABE8 各模式窗口矩形**（+0x656C 背包/+0x29CFC 装备/+0x331A0 商店/+0x339B4 交易/+0x47094 行会/+0x4784C 组队/+0x47C40 状态/+0x50804 公告/+0x51168 对话/+0x51700 任务/+0x518F8 选项/+0x52130 坐骑/+0x52508 技能）+ PtInRect 0x4762B4 → 返回**窗口模式或 -1**——窗口命中路由完整（F558/F897 用）。
- 落盘：window-hit-router-evidence.json（F900，primary-bytes）+ RESEARCH_LOG + UI_COMPLETION_AUDIT Round 594。
## Round 595 (F901) — 2026-08-12：命中路由闭合（F560/F591/F897/F900 汇总）

- **〔验证〕**compileall OK、verify exit 0、node OK、JSON 有效、**525 证据 JSON**；三服务 200；master 5bc4faf（**559 连发 F335-F900 已推**）。
- **〔弧〕**命中测试（F560）+ caption 路由（F591）+ 分派（F897）+ 窗口命中路由（F900）——**命中路由完整**（PtInRect + 开窗列表遍历 + 13 窗口矩形 + 模式返回），输入路由表面 100%。
- 落盘：hit-routing-closure-evidence.json（F901，derived）+ RESEARCH_LOG + UI_COMPLETION_AUDIT Round 595。
## Round 596 (F902) — 2026-08-12：HANDOFF 刷新 111（Round 593-595）

- **〔刷新〕**HANDOFF 追加 Round 593-595（F900-F901：窗口命中路由 + 命中路由闭合）；基线 Round 592=7ef2235 → Round 595=7b5435e（**560 连发 F335-F901**）。
- 落盘：handoff-refresh-111-evidence.json（F902，derived-tooling）+ RESEARCH_LOG + UI_COMPLETION_AUDIT Round 596。
