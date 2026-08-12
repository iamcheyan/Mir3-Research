# EI 3.0 原版 800×600 UI 完成审计

更新时间：2026-08-12（审计移植：Round 4–25 已并入，覆盖 Findings 274–331；Round 25/F331 见文末）
第一证据：`/tmp/nas_mnt/NAS/TMP/EI传奇3.0客户端/Mir3.exe`、`mir3.dat`、`Data/*.wil`、`Data/*.wix`

这份审计不把“已经有 JSON”当成“已经还原完成”。每个条目都区分：

- **已闭合**：原版二进制/资源已经给出可复现的资源、位置、尺寸或绘制调用。
- **候选可视化**：可以在 800×600 预览中画出，但仍有运行时语义、父窗口原点或透明边界未闭合。
- **待闭合**：不能用现代 Zircon 坐标或人工拖动代替，必须继续从原版调用链、运行时对象或资源交叉验证。

## 范围与统一产物

| 要求 | 当前证据/产物 | 状态 |
|---|---|---|
| 固定 800×600 视口 | `layout.json.viewport`、`Tools/web/wilviewer.py /ui` | 已闭合 |
| 原版资源与 Frame | `resource-family-catalog.json`、各窗口专项 JSON、WIL/WIX 分析 | 已闭合到资源级 |
| 统一布局/绘制记录 | `layout.json` 的 29 条窗口/按钮记录、22 条 `specialized_control_rects` 与 `normalized_draw_calls`（当前 57 条，保留 scope/order/evidence/source） | 已闭合到当前覆盖范围 |
| 证据等级与 pending 边界 | 各专项 JSON、`verify_mir3_ui_evidence.py` | 已闭合 |
| 原版绘制层级 | `draw-order-evidence.json`、`window-traversal-evidence.json`、`window-position-dispatch-evidence.json` | 已闭合（静态侧，Finding 258 + 248）：窗口基类背景先于派生绘制/子控件；可见链表 main+0xD24 头→尾按 id 分派专用 paint（0x4280F0/0x428358）；提升 = 0x42B6A0（关全部 0x42B820→hide 0x42AC50→show 0x42AC30 追加尾=最后绘制=置顶→0x423F90(1)→0x4240C0）；HUD 帧 0x4294E0 内底板→0x4283C0 图标→0x429740 条→16 按钮子控件→0x4179B0 量条→0x4280F0 窗口列表；store/exchange/option 状态→绘制分支全映射；**位置分派（Finding 248）**：拖拽链 0x42BA20→0x42B6A0→0x42B430→0x423FA0，实参=绝对客户区鼠标 X/Y（0x42B430 E8 调用方=唯一 0x42C745；WM_MOUSEMOVE 0x41D390→0x42C510→0x42C741），`[win+0x40/0x44]=宽/高`、`+0x48/+0x4C`=抓取偏移、570 底边距钳制、WM_LBUTTONUP→0x42BE20 收尾；**重复 show(ID) 边界全二进制审计（Finding 263）**：0x42AC30/0x449870 全部 15 个 show 调用点=14 toggle（this+0x30==0 门 + 追加后 vtable+0x10(1) 置 +0x30=1）+1 提升（hide→show）；0x449870 其余 4 调用方（0x41538F/0x448ABA/0x4491B6/0x44933E）为异 manager 泛型列表，非可见窗链；全文件 imm32 dword 扫描 0 处间接引用 → 静态路径重复节点不可达（primary-static），残留边界=链外调用方（脚本/服务端命令/运行时 +0x30 失步）需运行时捕获（candidate）；运行时可见链仍会变化 |
| 可视化装配预览 | `Tools/web/wilviewer.py`：HUD、14 个注册窗口、任务/NPC/技能/聊天/坐骑/商店状态等专项模式 | 已有；动态语义仍按专项 pending 标记 |
| 交互式客户端模拟器 | `Tools/mir3_client_simulator/`（`/sim` 路由）：800×600 固定画布 + 整数缩放、真实 WIL 贴图、14 窗口开/关/拖拽、确认框/公告、证据模式覆盖层、测试导航 | 已交付；场景/商店/装备等业务语义按 candidate/pending 标记 |
| 模拟器数据模型 | `Tools/web/build_mir3_simulator_data.py` → `data/*.json`（windows=14 controls=40 resources=157 entities=8 skills=12 maps=2 bindings=211），坐标不散落在 HTML/JS | 已闭合到当前覆盖范围 |
| 坐标差异叠加 | `/ui` 本地截图上传、透明度调节、状态保存 | 已有验证入口 |
| UI 状态记忆 | `localStorage` 与 HUD modal hash 状态 | 已有 |
| 专项控件统一目录 | `layout.json.specialized_control_rects`，当前 22 条，包含资源库、Frame 对、相对 Rect、证据等级和来源 | 已闭合到数值 Rect 范围 |
| 机器可读覆盖矩阵 | `ui-coverage-matrix.json`，22 个目标类别（Round 12 起），每项映射原版证据、布局 ID、预览模式和 pending | 已建立；pending 不等于完成 |

## 界面覆盖矩阵

| 界面 | 已恢复的原版事实 | 当前缺口 |
|---|---|---|
| 主 HUD/底部操作栏 | Frame 50、HUD 原点 `(0,465)`、动态血球/魔法/经验绘制链、按钮帧与命中区；**16 个底部操作栏 caption 控件已闭合（Finding 253 + Finding 261，`hud-label-evidence.json`）**：channel_control_class（vtable 0x4763A8，ctor 0x417550 9 实参）、paint 0x417640 状态机（HUD caption `+0x20=-1`→常态不画、悬停仅文字 0x417370、按下画帧 159/101/103）、Frame 159=16×14 真实字形（按下态美术）、文字绘制链 0x417370（GetCursorPos/ScreenToClient(hWnd 0x8AB7B0)→测量 0x45E0C0→CreateRectRgn 打字机→FillRect 0x96FFFF+FrameRect 黑→DrawTextA flags 0x25→DeleteObject×3）；Finding 261：caption 文字色=固定 0x000000 黑、四路分派循环=绘制 0x42954B/按下 0x42BAC9/移动 0x42C770/释放 0x42BF02（点击动作跳表 0x42C494，主输入 @0x41D457/0x41D57B/0x41DC82） | 运行时血量/魔法/经验注入；打字机揭示方向运行期验证（candidate） |
| 怪物目标框/悬停目标 | **全链闭合（Finding 239，`target-box-evidence.json`）**：代码绘制合成体（无独立 WIL 帧）锚定 `HUD+0xE4/+0xE8`；名字牌框 `0x40B850`（0xA0A0A 边框、宽=文本宽、高 15px、锚上方 15..30px、水平居中，每帧 `[HUD vt+0x84]` 以当前目标为 ecx @`0x41C063`）、名字文本 `0x40B750`（选择器 `0x566DD4` F2/F3，锚+(7,−0x38)）、悬停名牌 `0x40BB00`（3000ms 超时）、HP 条 `0x40A8A0`（元素 `0x5600FC+[8D]*0x144`、帧=HP 值、400/300 中心公式）、悬停实体重绘 `0x437DF0`；锚点两路径：世界推导 48×32 瓦片公式 `0x40F5F0`（视口常量 0xC8/0x9D）或固定 (376,227) `0x4120B0`；每帧布局矩形 HP `+0x629FC`/状态 `+0x629EC`/第三（`[+0x90]`）；悬停 msg 0xB → `0x40A4D0` 选择器装载（类型库 `0x449B90`/`0x8AA5A8` 记录 +0/+4/+0xA/+0xE..0x1A）→ 服务端目标询问（0xBC7/0xBD1/0xBD8）；点击设目标 msg 2 → `0xBC4`；切换 800ms 超时/鼠标位移 >5 门控；显示门控状态机 `0x411D91`（状态 0x15..0x1F） | **长尾三项闭合（Finding 257，primary-static）**：WIL 绑定=静态负证据（绑定 API 0x4660E0 14 调用方全枚举，唯一全局表绑定=地图装载器 0x43B600 仅覆盖 0x0E..0x1B/0x1C..0x29、544 张地图 header[0x14]∈{0,1}；目标框元素 0x51/0x56/0x57/0x81/0x89/0x8A 无静态绑定→确切文件名=运行期数据 candidate）；悬停头像=不存在（每帧分派 0x41BF00–0x41C0A0 仅 5 个文字/HP 组件；49×33=状态窗特殊索引 4 角色形象槽 @(x+0x61,y+0xC8) flag=1，NPCface.wil 440 帧/约 100×122 不匹配）；HP 条帧=HP 值 [0x61B9C]（primary-static）；10000+(A%400) 系列=元素 0x57（0x566F18）A=[629C8]*400−[8A]*3000+[C4]−0xAA0、帧=10000+(A%400)，GameInter 1103 帧<10000 排除、≥10000 帧候选已实测，运行期绑定 candidate |
| 小地图/地图 | MMap/FMMap 选择、地图 ID 映射、小地图目标 `(672,0)-(800,128)`、地图专用合成链；边框=程序绘制 1px 灰 `0x646464` 描边（CreatePen+MoveToEx/LineTo @`0x45E570`，`0x43DBD7`）；无独立地图对话框（地图对象唯一构造点 `0x427E08` → `main+0x2AB6A0`=screen+0x6214，screen 对象=main+0x2A548C）；T 键 `0x54`（键盘独占，`0x43DE40` 无调用者=死代码）经 `0x42CE90`→`0x43D5F0` 切换 128↔256 视图表面——256 模式=widget 自身 256×256 @(544,0)，同 1.5px/unit 1:1 无缩放（放大视野/覆盖语义，非 zoom-out）；鼠标路径=Ctrl+拖拽重定位 `0x43DEB0`，无滚轮缩放；小地图标签「小地图(Ctrl+V, V)」=`0x47BCCC` 热键指引按钮（screen+0x5730，0x417550@0x4279CF）；完整按键表 Q/W/E/R/S/D/Z/B/G/F/N/T/Y；对象链表布局 `0x560070`（entry `+0x88` 类型字节：0/1/2/3/0x32；`+0xCC/+0xD0` 世界坐标）与 `0x5600A0`（`+4/+8` 坐标）；**类型 0x32 闭合（Finding 254）**：全量扫描无任何静态写入→服务端包下发；小地图黄色 0xFFFF 标记（`0x43DC54`，1.5px/unit）+ 移动阻挡（`0x4123E3`）+ 排除于选中/使用（`0x41ECAE` 仅 0/1 型；分派 `0x408276/0x40DFF0/0x411955/0x43CD29` 仅 0/1/3）→ 非 NPC 的阻挡型地图标记（传送点/阻挡点候选）；**资源绑定闭合（derived，Maps 阶段）**：选择规则 `0x0043D780`（map_id≥1000 → FMMap.wil frame map_id−1000，否则 MMap.wil frame map_id）+ MiniMap.txt 交叉引用 182 行 → `map_bindings.json`；模拟器地图切换同源驱动 map.bg 与 map.minimap | 类型 `0x32` 业务名（传送点 vs 阻挡点，需服务端/运行时证据）；256 模式视觉帧确认（静态链已全）；T↔缩放关联仅代码证据；小地图帧内留白逐图校准（P6） |
| 人物状态/装备 | Frame 200、11 条构造 Rect、属性全局字段、装备资源选择器模式与绘制链；属性坐标闭合：第一列 label `(winx+0xFF, winy+0x43)`/行步 0xF、第二列 label `(winx+0x17F, winy+0x1E)`/数值 `+0x44`（复位重读 `[ebp+0x18/0x1C]`，非累计偏移，旧模型废止）；双位置字段注记（`[this+8/0xC]`=背景位置、`[this+0x18/0x1C]`=属性/装备基准）；全局 selector 数组 `0x5600FC+0x144k`（el82=`0x5668C4` flag0、el83=`0x566A08` flag1、el139=`0x56B0E8` flag2），构造循环 `0x43B7B2`（地图重建，14 元素、mode1→mode0 回退、start=(byte+1)*14：byte=4→el70..83、byte=8→el126..139）、析构循环 `0x43B75B`（14..69）；**WIL 绑定闭合（Finding 246，primary-static）**：主对象 loop2 `0x452AF7`（70 次 mode0）构造 el70..el139，WIL 表填充 `0x452B20`（slots 0..139，slot N=owner+0xB130+N*0x104、N≥70 即 owner+0xF848+(N-70)*0x104）静态写入 **el82=Inventory.wil**（slot `0x570574`@`0x453804`）、**el83=Equip.wil**（slot `0x570678`@`0x453829`）、**el86=ProgUse.wil**（slot `0x570984`）、**el139=StoreItem.wil（Finding 266，primary-static）**（slot 139 `0x573F58`=owner+0x13E5C、字符串 `0x47C878` 拷贝 @`0x4540E8`；`0x452B20` 实填 slots 0..139）；**视图切换按钮闭合（Finding 246）**：子控件 this+0x10C 帧 171/172，点击 `0x44CCD0` toggle 分支 `0x44CD14-0x44CD9F`——mode byte `[this+0x54]` 0=属性视图（帧 200=256×512，faces 171/172）/1=装备视图（帧 201=1024×512，faces 168/169），`0x423E80` 重设窗 + `0x417880` 换脸；hit rect 纠正 (176,264) 36×36（旧 286 误记）；记录步长 `0xC24` 重确认（click `0x44CDCD` idx*0xC24）；装备槽类别=server-driven（客户端 `0x44B720` 纯位置命中无类别分支）；**8 槽 38×38 几何闭合（Finding 240，`equipment-slots-evidence.json`）**：SetRect 链 `0x44B1BC-0x44B2C6` 相对矩形（loop0 头盔 (177,70)、loop1 火把 (27,264)、loop2 毒药 (64,264)、loop3 左手镯 (27,186)、loop4 右手镯 (175,186)、loop5 左戒指 (27,227)、loop6 右戒指 (175,227)、loop10 鞋子 (103,264)，绝对 = +(278,136)）；非槽区 loop7 头像/名区 49×33、loop8 纸娃娃 60×90、loop9 属性面板 53×84；图标帧=物品 shape `WORD[graphics+0x28]`（非槽位索引） | **槽位映射闭合（Finding 265，primary-static）**：客户端记录索引==服务端 EquipmentSlot 枚举，零翻译（命中 `0x44B720` 原始索引→暂存 `0x44BBD0` @+0x8886→`0x451690` arg2→组包 `0x452940` struct+6 线上字节；兼容分派 `0x44B7A0` 仅枚举对齐自洽：恒等 {0..4,10}、{7,8} 戒指、{5,6} 手镯、type9 鞋子 subtype 0x19→{5,9}）；11 行定案表 idx0=武器/1=衣服/2=头盔/3=火把/4=项链/5=左手镯/6=右手镯/7=左戒指/8=右戒指/9=鞋子/10=毒药（loop7/8/0/9/3/4/5/6/2/10 对应 +0x1C0/+0x1D0/+0x1F0/+0x200/+0x210/+0x220/+0x230/+0x240/+0x250/+0x260）；美术标签（火把@(27,264) 等）弃置为 UNVERIFIED；仅剩余：帧 201 图标级视觉标签像素验证（需视觉模型）、sibling 文件部分数值绘制颜色语义 |
| 背包 | Frame 250、6×6/36px 命中网格、右侧竖直量条（`0x4179B0` 共享量条，F280=16×424、填充 12×218、max=0x5E=94、`(winx+0xF8, winy-0xA5)`，`[this+0x58]` 仅复位清零→空条）、负重文字格式、物品记录字段；**记录布局闭合（Finding 247）**：46×0xC2C 连续记录 @`this+0x774+slot*0xC2C`（ctor `0x42E810`→向量构造迭代器 `0x4686C4`、dtor `0x42E8D0`→向量析构迭代器 `0x468306`，数据基址 rec+0x0C，0xC20 拷贝），单元格表 @`this+0x2C4`（WORD/格、6 格/行、占用=slot+0x3E8）；打包字段=24 位图标着色（`+0x51..0x53`，primary-static 全链：类型 `+0x2E`∈{0x0A,0x0B}→`0x45E4E0` 3→16bit→RLE `0x45F2D0`，否则白 0xFFFF）；负重文字=「负重:%d / 总量:%d」@`0x47BDFC` 读 `0x7DA11D/0x7DA11F`，四模式标签 [包袱]/[修补]/[变卖]/[木柴]（`this+0x54` 分派 `0x42F13C`）；主数值 `0x7DA100`=bss 零且唯一读取点 `0x41729D`（0x405 门，死代码）与 `0x42EE4C`（绘制）→显示恒 0，业务名 candidate（交易/购买数量上限）；点击链 `0x4300F0`：mode0→0x3EC（slot/name/qty，`0x451690`）、mode1→`0x451860`、mode2→`0x4517E0` | 主数值 `0x7DA100` 业务名（candidate：交易/购买数量上限，需运行时观察）；服务端→客户端背包填充 handler（**Finding 262 修正**：`0x42FC40` 为函数中段，真实入口 `0x42FC20` 活=13 调用者/10 个服务器消息 handler，0x403 回包抓包仅需定消息号）；0x405 消息协议语义（**Finding 262**：唯一发送点=死门 0x417280，对话框 0x418030 实际经 0x417034 发 0x406） |
| 技能窗口 | Frame 400、Magic.exp 读取链、11 组 410–465 控件帧对、15px 列表行距、0x104 记录步长 | Magic.exp 运行时解码字段与类别/图标业务映射 |
| 任务 | Frame 700、列表 19 行/15px、滚动模型（`this+0x58` 列表滚动/`this+0x5C` 行数钳制/`this+0x60` 正文 3 行滚动；滚轮 `0x448700` 递减下限 0、点击 `0x448780` 递增钳制；正文命中区 (80,310)-(250,380)）、详情 Frame 705=204×76 完整面板、正文深蓝 0x7D0000、帧像素态 721 绿X/722 金X/723 绿箭头/724 金箭头、事件孪生 0x418（标记选中记录、门控 `+0x20C==0`）/0x419（点击空正文子记录）；**分隔符 '/' 与无客户端换行闭合（Finding 251）**：msg 0x515→fill `0x4488D0` 经 fast strchr `0x468BF0`（push 0x2f @`0x44891C/0x448932/0x448944/0x44895C/0x44897A`）就地切分（行文本→record+4、field4→record+0x230/+0x214）、`0x45DD70` 每行单次 TextOutA 固定 15px 无回流；**控件归因修正**：仅箭头 723/724→`0x448580`→0x418（点击 `0x4481FA`/更新 `0x44856B`），X 721/722 本地消费（release `0x4177F0`→PtInRect→`0x45AFC0` cmd 0x69，`0x447FD6-0x447FDA` 无消息） | 0x418/0x419/0x69 业务名称 candidate（Mud3 无源码；链与图标 primary-static 已闭合，缺协议引用/运行期抓包）；记录类 tokenizer candidate（`[0x8AB7A8+0x1C]` vtable +0x44/+0x68，门 0xA0/0xC8） |
| 聊天 | Frame 350、历史区/输入区 Rect、19 行、视觉 14px、六种频道/拒聊命令、滚动控件；关闭钮 F161/162 `(532,350,28×26)`、频道钮 `36×34`×6、输入框控件 `this+0x6D4`；节点字段 `node+0x00=文字色 / +0x04=背景色(0=透明) / +0x08=内联文本`；渲染器 `0x0045DD70` 参数槽（色/背景/文本）；**六频道 +0x34 命令串渲染闭合（Finding 243）**：9 控件 vtable 链（`0x413DA0`→`0x4686C4`→`0x404690` 写 `[obj+0]=0x4763A8`，槽 +4=0x417640 渲染/+8=0x417780 hover/+0xC=0x4177C0 按下/+0x10=0x4177F0 命中）；+0x34 仅 tooltip 渲染器 0x417370 读取（0x417373/0x417378），悬停分支 0x41771B 无条件调用 → 光标旁 DrawTextA 0x25 淡黄底 0x96FFFF 文字；常态/按下纯帧合成（0x417830/0x460240 无文本）；点击注入的是命令模板 0x47AD88 族到原生 EDIT 框（SetWindowTextA 0x4762CC），与 +0x34 无关；**全链汇总（Finding 250）**：7 步绘制链 `0x4142C0`（基帧 vtable+0xC → 裁剪 SetRect(+0x6C0,40,29,531,308) → 历史文字 0x45DD70×19 行 14px → 输入条 0x4179B0 @(x+0x215,y−0xD0) 值[+0x68]/上限[+0x6D0] → 9 控件 0x417830 → 9 循环 vtable+4 → 输入行 SetRect(+0x954,25,311,524,326)）；消息链 head=this+0x5C（node next+0x408/prev+0x40C/色+0x00/背景+0x04/内联文本+0x08、count+0x68、scroll+0x6D0、裁剪[35,28,520,43]）；输入 EDIT 链 HWND 0x8AA48C/对象 0x8AA488、解析器 0x414364-0x4144F0（`/` `(` `)`、分隔 space/colon、前缀 0x47AD28 `/%s `）、提交 0x4144A0→逐行 0x414FA0、行回忆 0x4142C0；渲染器 `0x45DD70` 槽序闭合（Finding 250）=thiscall 7 栈参 ret 0x1C：arg1=目标离屏 surface（0→回退 this+0x1C；HDC 经 surface->vt+0x44 出参写回 arg7 槽）、arg2=X、arg3=Y、arg4=文字色（SetTextColor 0x476060）、arg5=背景色（0→SetBkMode TRANSPARENT 0x476044 否则 SetBkColor 0x476050）、arg6=文本（TextOutA 0x476074 @0x45DE12）、arg7=字体（0→this+0x28 默认）；聊天点 0x4147F3：arg1=[0x8AB7C4]=窗+0x1C 离屏 surface（仅 CreateSurface 出参写 0x45D53D/0x45D602 in 0x45D380）、arg2=this+0x6C0+0x18、arg3=this+0x6C4+0x1C+row、arg4=msg+0x00、arg5=msg+0x04、arg6=msg+0x08、arg7=0；**可见性门 `0x42B180` 闭合**：[ROOT+0x5081C]==chat this+0x30（窗口 vtable 0x47660C@0x413E1A、setter vtable+0x10=0x423F80）；关闭钮命中 0x4177F0→点击分派 0x4149A0→0x42C0B7→push 8→0x42ADB0→跳表 0x42B3E4[8]=0x42B180：隐藏（移编辑框+0x42AC50 移除激活+0x423F80(chat,0)）/显示（置聊天矩形+ShowWindow(edit,5)+0x42AC30→0x449870 加激活+0x423F80(chat,1)）；'R' 键 0x42CCF7 同路 | 0x45DE50 SetTextColor 精确 COLORREF（candidate）；typewriter 揭示方向运行期验证（candidate） |
| NPC 对话 | Frame 1100/1101/1102、18px 条带节奏、token 解析、16 项上限、14/21px 行距、动态控件重排；**文字绘制闭合**：`0x0043F460` 白 0xFFFFFF GBK 换行、窗口相对 (x+0x96, y+0x28)、行距 textheight+5、滚动窗 `[+0x3BC]..[+0x3BC]+[+0x594]`、全局节点链表 0x8B1AE4；**对象模型闭合**：ROOT=静态全局 0x47EF18、winmgr=ROOT+0x2A548C、统一窗口 id 空间（模型=id 9 @+0x51150、帧=id 11 @+0x516E8）、绘制分派 0x4280F0→0x428358、显示=切换 0x42ADB0、定位+显示 0x42B6A0（关全部→移除 0x42AC50→重加置顶 0x42AC30→0x423F90(1)→0x4240C0 仅当 `+0x30/+0x34/+0x3C` 全非零）、窗口状态 `+0x30` 激活(0x423F80)/`+0x34` 可见(0x423F90)/`+0x3C` 使能、关闭全部 0x42B820、模型输入 0x440290→ROOT hide-all 0x41C1E0、帧自绘选项列表 0x447470（≤19 行，类 0x476A68；行绘制 x=frame+0x18+0x41、y=3·i+0x12、hover 标志 `+0x210` 切换色基 0x19197D/0x1919C8）、点击→0x451A40 事件 0x419；**输入链闭合（Finding 252）**：winmgr 鼠标 0x42BEAA→hit-test 0x42AAB0→0x42BF70→表 0x42C4D4 case 9=0x42C17D→模型输入 0x440290 三控件命中（关闭 X=+0x58 且 `+0x274`≠0→返回 1→hide-all、上滚=+0x1C0 门控 `[+0x3BC]>0 && byte[+0x58C]==1`、下滚=+0x10C 门控 `[+0x3BC]<[+0x3C0]`）、滚动 thumb 拖拽 0x417E60(+0x3C4)、滚动重排 0x440C30；**打开链 0x41FE31（外层表索引 16）静态死**：分派尾 0x41F582（唯一跳入 0x41F269）边界 msg 0x264..0x26C→仅索引 0..8 可达，13/16/17 等 9..39 无表外引用；hide-all 0x41C1E0 经 E8 调用方 0x41C0CE/0x422BAD/0x42C193/0x42CFC3 存活；**选项列表填充链闭合**：服务端 msg **0x515** → 子协议分派 0x4218F2（ids 0x44D..0x520，字节表 0x42219C→处理表 0x422168，`[3]=0x421A45`）→ 0x421A45 → **0x4488D0(frame=ROOT+0x2F6B74, body, count)**：逐行 0x468B1A 分配 0x630B 描述符、0x468BF0 按 '/' 切分（≤4 字段）、整段 body 拷入 desc+4、**0x449870 追加到 frame+0x1E0 链表**（节点 12B `[data@0,next@4,prev@8]`，头/尾/计数 `+0x1E4/+0x1EC/+0x1F4`）、`[frame+0x54]=1`、`[frame+0x5C]=count`；描述符字段 `+0x204` len、`+0x208/+0x20C` 动作标志（填充清零）、`+0x210` hover、`+0x214` 有字段2、`+0x22C` len2、`+0x230` 字段2文本；帧显示 0x4488B0（vtable+0x10）：`[frame+0x30]=激活`，若 `[frame+0x54]==0` → 0x4519E0 发 **0x416** 请求内容（0x8AB828 消息构造对象）；**子协议同族全闭合**：0x416 发送族 0x4488B0/0x448B10/0x4491D0/0x449390 均为同一帧窗口内容加载器（0x449870 同族调用点 0x4491B6/0x44933E 位于 0x4491D0 幂等插入体内），0x449060 重排=抽干+按 `desc+0` 冒泡排序+重追加，0x4491D0=幂等插入（0x449680 查重）、0x448B10/0x449390=子列表追加/替换（子列表 vtable 0x476A6C）、0x448D90=子项选中（`+0x21C`=1、文本拷 `+0x220`）；0x401390=8 项颜色表（2=白/3=红）、0x427E30=聊天行打印（聊天窗 id 8 @+0x507EC→0x4144A0）、0x422E30=彩色聊天文本+Chat.txt 日志、0x514=标志位+窗口 0x1D 开关、0x518=对象 3 word 存储、0x51A..0x51D=记录排队 ROOT+0x364458、0x520=带时间戳对象注册、0x44D=对象动作路由、0x4B0=出站 0x40C 组装（ROOT+0x428054）；0x47B15C/0x47B180 = 韩文任务日志提示（EUC-KR），帧窗口承载 NPC 对话选项+任务日志两类内容 | 0x418/0x419 业务名与选项点击语义（candidate，0x419 语义同时覆盖 NPC 选项点击）、三控件按钮业务名（candidate：字形 52/53↑、54/55↓、161/162× 为视觉比对）、0x3F2 轮询包运行期服务端应答 |
| 商店/仓库 | Frame 1000–1003、状态 0–4、控件状态门控、选中记录前置条件；Paint 已闭合 clip→物品→选中描述→价格/数量→辅助文字；**点击打开全链闭合（Finding 232）**：open-all 参数 (2, fr=selector+0x5898, 0x3E8, 0, 0, 0x12C=300, 0x130=304, 0)、点击分派 0x42BB00 id2→pre-open 0x44EF00（state∈{0,1,3,4}→+0x5FC 双矩形 hit-test + `[+0x700]=([+0x65C]−1)×[+0x608]`；state∈{2,5,…}→侧面板 +0x1BC/+0x270/+0x324/+0x3D8 hit-test）→0x42B6A0 特例 0x44E910 hit-test（state1 rect(+0x18+0x12C,+0x1C+0xD0,+0x20,+0x24)、state4 rect(+0x18+0x12C,+0x1C+0x64,…)）命中即拒开；paint 0x44E260 全解码（基类→0x417830 面板重定位×6→8 主面板 0xB4 步长绘制循环→状态分派 {0,4,1,3}→0x44D590/{1,2}→0x44DB50/{4}→0x44E040）；商店 `+0x30` 从不被写（0x44F6C3/0x44FD5E 为物品列表构建循环记录字段），基类 paint 门控备选路径属地图类 | **已闭合（Finding 245，`store-state-graph.json`/`store-window-render-evidence.json` closed_notes）**：屏幕原点（state0 面板 (0,184)-(299,490)、content (0,186,300,304)；0x423E80 直接由实参建矩形、无父相对居中）；双 store 关系（UI store=game+0x33188 vs protocol store=game+0x2D8614，session+0x2D8614 数值巧合已解）；state2=frame 1001 205×205（0x44F940，msg 0x2C0）、state3=frame 1000（0x44FB00，msg 0x2C8）——旧 state2/3 标签反转已纠正；Store 类 ctor 0x44CFC0/dtor 0x44D0B0（Game dtor 0x426E80 逆序）；注册实参 (2,sel,1000,0,0,0,300,304)；帧 1010–1017 按钮映射（1010/1011 X、1012/1013 确认、1014/1015 ◀、1016/1017 ▶，尺寸 28×26/48×20 与命中矩形吻合）；状态 0=购买/3=合成/4=物品详情 PROVEN，1/2 业务名仍 candidate（无服务端消息常量源）；protocol store 无静态构造/无 vtable、运行期初始化（勿虚构同步桥） |
| 交换 | 双区结构、6×5 网格、窗口/资源调用链、分区→物品→文字/数值→两条交易重量量条（`0x41601C`/`0x41603D`，共享量条 F1070=16×360、填充 12×184、max=94、`(winx+0xD1, winy-0x73)`/`(winx+0x1B9, winy-0x73)`，填充字段 `[this+0x54/0x58]` 从未写入→空条） | **文本/网格链已闭合（Finding 260）**：0x4169B0 逐格循环 36px（帧 `[ebx+0x5EC]`、堆叠数 0x0A/0x0B 色 `[ebx+0x609..0x60B]`、计数文本 0x45F2D0）；4 条文本经 0x45DE50+0x46811C（左方名=全局缓冲 0x7776A0 运行期填充、右方名 this+0x129D8、`%d` 计数 this+0x12A18/0x12A1C）；**位置流已闭合（候选级，Finding 260）**：注册 (0,0) 484×330 vs ctor 烘焙 (532,350)/(185,332) 越界，show 分派 0x42B6A0 收消息动态 x,y（0x4240C0=拖拽偏移非移动）→ 无静态绝对原点，坐标维持 candidate。绘制期状态已闭合（Finding 258）：paint 0x415B10 SetRect 0x4762B0 按 center 拆左右矩形 this+0x5C/0x6C，PtInRect 0x4762B4 以鼠标全局 0x7DA1C0/C4 选侧 → bl=0 左网格原点 (winx+0x15,winy+0x30)/bl=1 右 (winx+0xFD,winy+0x30)，0x415BC2 二次命中→0x416830 格索引→0x4162E0 物品映射（0x7243C4≠0/0x7243D8==0 门控）；剩余 candidate：按钮业务名（1060-1062 中文 `交易` 标签已见）、运行期窗口原点 |
| 组队 | Frame 900、成员两列/20px、允许/拒绝状态文字、五个控件 | 已闭合（Finding 259）：成员行=单文本字段 node+0x04 无图标、链表插入序（0x419EE4→0x424840，容器 this+0x54 vtable 0x4767E0，头 this+0x58/count this+0x68）；两列=奇→win.x+45（0x424471 push ebx，ebx=win.x+0x2D）、偶→win.x+145（0x424479 lea edx,[ebx+0x64]），y=win.y+0x5A+20*⌊i/2⌋——旧公式 mod-2 列映射颠倒已纠正；允许/拒绝 y=win.y+0x3A 证明（0x424549/0x424563 add edi,0x3A），x 读未初始化栈槽 [esp+0x1C]（0x42453E）=静态不可证；全链表遍历无 18 行上限（0x42449B next==0 终止，超窗引擎裁剪）；运行态显隐 0x42AC30/0x42AC50、切换 0x42B0BA（id 6，visibility=main+0x47864=win+0x30，伴生页签帧 0x398/0x399 @main+0x47B70）、显示分派 0x42B6A0 尾部 0x42B79A（窗口 main+0x47834） |
| 行会 | Frame 600、滚动列表、18 行上限、三状态绘制、9 个控件及像素中文标签 | 已闭合（Finding 259）：9 控件数组 this+0x118 步长 0xB4；点击分派 0x4258F0 检查序 0,1,2,3,4,7,5,8,6（主鼠标分派 0x42C039-0x42C052 后 id-hook push 4→0x42ADB0）；分支=会员升职→state0+0x4523E0@0x8AB828、成员踢出→state1+0x452410、盟主转让→state2（原始 c7 86 9c 00 00 00 00 c6 86 98 00 00 00 02 @0x4259D9）、邀请入会→掌门守卫[this+0x94]+对话框 602(list3)+[0x4762CC]、行会解散→对话框 601(list1)+空表 tooltip 0x47BB28、行会公告→tooltip 0x40F/0x47BAF4（%s=[this+0x54]）、关闭窗口→tooltip 0x415/0x47BAC8、退出行会→**倒置守卫**（掌门 no-op/成员 tooltip 0x47BAA4）；tooltip 显示 0x418030（ecx=0x7E04C8），输入框 0x8AB828 经 0x4520F0+0x4523E0；三态绘制=state0 标记 0x47BA78/0x47BA6C/0x47BA60、state1 标记 0x47BA84→0x96FF 余 0xFFFFFF，other 态全行阴影 0xA140A+绿 0xFF00 双画（0x4255C5/0x42563E）；+0x6B8 ctor 记录 [196,50] 纠正为 (600,72)，paint 真相 9 控 (556,409)/(34,376)/(34,402)/(121,402)/(309,376)/(397,376)/(484,376)/(309,402)/(397,402) |
| 系统设置 | Frame 750、四组选项、Config.ini 键、两个音量滑块 | 已闭合（Finding 260）：EffectSoundLevel `0x8AB14C` 播放期直读（0x45BCE9 在 0x45BC80，经效果声 setup 0x45B140 / 一次性播放 0x45B900，6 播放调用方 0x457BA7/0x459240/0x459476/0x459AD6/0x45B032/0x45B074）；BGMLevel `0x8AB150` 音频引擎零引用——拖拽时经 0x441F6C→0x45A700 一次性落 BGM 频道对象 `0x8AB658`，播放路径（0x45B250 play-by-name / 0x45B3D0 stop→0x45A510 / 0x45B410 enable）只读频道状态；paint 0x441380-0x4414E3=帧 750+11 控件重定位，无运行期覆盖层（唯一动态=滑块把手 x 0..160）；load 链 0x441DA0-0x441F37 / save 链 0x441B30-0x441CAE（load_or_parse_va 已修正）；剩余 candidate：Ambience 实际音效触发点、BGM 音量重放时点 |
| 坐骑 | Frame 850、四个按钮韩文标签、状态字节门控、原版命令字面量 | **标签/覆盖层已闭合（Finding 260）**：860/861 말타기、862/863 말내리기、864/865 말숨기기、866/867 말꺼내기（sibling 像素转录 + 帧宽 44/60/60/56=ctor 命中矩形精确匹配、常态/按下全帧差异佐证）；paint 0x4269C0-0x426A74=基帧 850+5 控件 0x417830 重定位+子控件循环→**无状态覆盖层（负闭合）**。已闭合（静态侧，Finding 255）：状态块 0x7DA060（session 0x777698+0x629C8，byte0=state clamp 0..3，0=未骑马/非零=骑马；唯一写入者 0x40F420，包 case 0x267/0x26B 经 0x40FED0 回发）；点击门控 +0x108→`@上马`(0x47B060)、+0x1BC→`@遛马`(0x47B068)、+0x270→`@收马`(0x47B058)、+0x324→`@遛马`(0x47B068)，共用分发 0x426B22→0x4520F0(0x8AB828, msg 0xBD6)+冷却 0x8A68BC=0x12C；坐骑窗自身无覆盖层，主窗 HUD 0x44B666 读 word[0x7DA063] 作填充色 arg6→0x45FD50(0x8AB7A8) 为窗外状态图标（非帧号，Finding 264 修正）。已闭合（Finding 264，primary-static）：骑乘外观元素绑定 element 87=0x566F18=0x5600FC+0x57*0x144（选择字节 [0x629CF]=0x57 @0x40F47F/0x40C79C 硬编码门控 state≠0，lea ×9×9×4=×324 → [0x62A14]）↔ WIL slot 17 `.\Data\Horse.wil`（0x47CC94→owner+0x1098C；loop2 0x452AF7-0x452B0E element 70+i↔slot i）；世界渲染 0x40F5F0 门控（state≠0 && [62A14]≠0 && [0xC0]≥0x1D）帧=0x2710+(A%400)（A=[629C8]*400-[8A]*3000+[C4]-0xAA0）→0x466130→0x461ED0/0x463330/0x460240；HUD 图标=element 86 ProgUse.wil 帧 [0x777720]*10+[0x777723]+0x3B；word[0x7DA063]=0x45FD50 RLE 填充色 arg6（op 0xC2，23 调用点中其余 22 个全 0xffff/0xffff）。剩余 candidate：1/2/3 子语义、word 字段协议含义（运行时）、말내리기 标签 vs @遛马 命令的语义并列 |
| 确认/提示框 | Frame 950、`-1/-1` 居中规则（ctor 内锚 400×246）、三按钮命中 Rect、原版支付/丢金币/仓库等消息 | 已闭合（Finding 233–238）：单例 0x7E04C8、ctor 0x418030 全参数图、基类 0x417FB0、按钮类静态 vtable 0x4763A8 + 状态机（paint 0x417640/hover 0x417780/press 0x4177C0/release 0x4177F0）、键盘 TAB/回车→激活 0x418520（SendMessageA 0x7EE，wparam=((type<<8\|idx)<<16)\|tag）、7 调用方原串（GBK 中文 + cp949 韩文混合编码）、cluster2=独立隐藏窗 0x418910；0x7EE 接收体已闭合（Finding 256：0x403FA4→0x404600→0x403640、0x459654→0x45A140）；剩余 candidate：横幅 0x777200 持续时长/自动关闭 |
| 公告/全图 ID15 | Frame 602、固定 `(107,110)`/`584×252`、状态文字与控件、显示隐藏分派 | 已闭合（Finding 233–238）：帧 602 1024×256 全幅合成 + 800×600 裁剪（无独立阴影 pass）、602 双用户（本窗 0x427970 + 公告横幅单例 0x777200 @0x425A46）、603/604/605 全二进制无引用=未使用韩版遗留（负证据）、btn1 (655,126) 28×26 / btn2 (603,137) 40×20、click 0x43E4BA 含行会公告编辑缓冲 0x1CC、独立 WM-id15 窗口类=行会公告显示/编辑；公告保存链 msg 0x410/0x411→0x4524A0/0x4524D0→0x452940→0x451E60→WS2_32 send、横幅 0x777200 文本源（链表→SetWindowTextA [0x7773CC]）与 id-15 显隐分派已闭合（Finding 256）；**可见性分派已闭合（Finding 249，`window-visibility-dispatch-evidence.json`）**：0x43E4B0 负载=WM 0x201/0x202 打包 lParam 坐标（x=main+0x35B2A8/y=main+0x35B2AC，0x41DB80/0x42BE20→0x42BE8C）、**Interface1c 提示窗（模式 2，0x8A7140，编辑框 0x8AA48C）先于 Frame 602（模式 3，0x47EF18）显示**——模式字节 0x8B1878 经主循环开关 0x402123 强制 0→2→3（协议 case 0x64 置状态 2 → 0x41C1C7→0x41B5D0→0x419BE0→0x4575D0 显示提示→0x4570C0 切模式 3）；0x42E1F0 更正=.itm 文件加载器（CreateFileA/ReadFile），非公告发送 |
| 好友/社交 | 已做静态负范围审计；无独立好友窗口构造器 | 继续追动态对话/Interface1c 控件入口，不凭空新增面板 |

## 还原器必须遵守的规则

1. `SetRect`、`PtInRect`、WIL 头部尺寸和实际绘制调用优先于现代 C# Zircon 坐标。
2. 构造器的原始 `x/y`、窗口对象的最终原点、窗口相对控件位置必须分开保存。
3. 资源 Frame 的尺寸不自动等于窗口容器尺寸；透明像素边界也不能自动变成命中区。
4. `candidate`/`pending` 内容在预览中必须显示候选标识，不能伪装成原版确定值。
5. 截图差异只能验证/发现问题，不能反向手工改写一级坐标。
6. 原版客户端文件只读；新增结论进入 `docs/research/ei-ui-layout/` 并更新 `RESEARCH_LOG.md`。

## 每轮完成门槛

```text
python3 Tools/reverse-engineering/enrich_mir3_layout_evidence.py
python3 Tools/reverse-engineering/verify_mir3_ui_evidence.py
python3 -m py_compile Tools/web/wilviewer.py
git diff --check
```

模拟器交付后，每轮还需在浏览器验证 `/sim` 的贴图加载、窗口开关、控件状态与无 JS 错误（见 `Tools/mir3_client_simulator/README.md` 冒烟测试）。

只有专项 JSON 的 pending 项减少、统一 `layout.json` 同步、预览模式可访问且提交已推送，才算一轮有效进展。当前审计证明项目仍在进行中，不得调用 goal complete。

## Round 3 (2026-08-11)
- MonsterPortrait（Finding 271）：头像来源四区定案——状态窗口 49×33 区=GameInter.wil F200 内嵌横幅（非头像帧）、目标框=纯代码绘制无独立帧、怪物无肖像（NPCFace.WIL 仅 NPC 窗口）、选人界面=3D 引擎+Interface1c.wil F0 背景；目标框 selector 元素 0x51/0x56/0x57/0x81/0x89/0x8A 的 WIL 文件名经 slot 表定案（Magic/ProgUse/Horse/MonMagic/MagicEx/MonMagicEx.wil），pending 重分类为运行时残余。
- FriendsSocial（Finding 270）：好友/社交窗口文档化负闭合——0x8A7140 双用途对话框（游戏前 LOGIN：ei_login.dat/账号密码/Enter 提交；游戏中 0x7ED/0x64→[main+0x428204]=2→0x41B5D0 淡入→0x419BE0，文本 0x4B0→main+0x428070，为服务器连接/维护/断线通知）触发器全图定案；好友字符串 0 命中（GBK/cp949/ASCII 全负）；16 窗口 id 空间全枚举（0x42BEF8 槽公式、0x42C494/0x42B3E4/0x42C4D4/0x42ABE8 全表），唯一社交窗口=组队 F900（id6）与行会 F600（id4）；GameInter/Interface1c 大面板帧全归因无好友列表面板；pending=0（残余为 candidate）。
- WindowCatalog（Finding 268）：16 固定窗口 id 空间全量静态闭包——每 id 对象基址/ctor/pre-ctor/vtable/paint/注册矩形/GameInter.wil 帧/点击处理全部绑定（window-id-catalog.json）；caption 类 vtable 0x4763A8 与窗口基类 vtable 0x476624（+0x10 show 0x423F80 写 +0x30）语义解析，0x42C494 caption 表/0x42C4D4 case 表/0x42ABE8 命中矩形表全解码；case9 = NPC 对话关闭流（0x41C1E0 隐藏 id9+id2）；id 0xB 修正=任务 F700（非任务简报误标 NPC，NPC=id9 F1100，与既有 npc/quest evidence 一致）；id5/10 空槽、id15 公告纯显示不可点击（守卫 id>0xE）、id100 退出确认框空间外；pending 仅 id7 消息窗口职能/公告 w-h 歧义等运行时项。
- Skills2（Finding 272）：技能书窗口右页详情渲染循环 0x0043A440 全闭合（primary-static）——行流 this+0x968+8 CRLF 分行（CR 后必须 LF）；';' 注释、'#' 段头 atoi==this+0x964（选中技能 id）匹配并渲染至下一个 '#' 段头退出；0x45E200 解析 count 恒为 1（0x45E0C0 三条返回路径全返回 {0,0}，wrap 惰性）→ 每行恰一行记录，20 槽反引号缓冲区仅槽 0 使用（旧 round field meanings pending 定案）；几何 (winX+235, winY+30+15k)，'[' 技能名行 4 角阴影 0x0A0A0A+主文字 0x96C8FA（0x45DBA0 测宽），普通行 0x0A320A；选择链 0x439134(-1)→0x43A370 左页列表命中（[entry+4]+6 技能 id）→0x43ACE4 写 this+0x964→paint 0x439500→0x439520 call 0x43A440（唯一调用者）；流生命周期 0x439150/0x468B1A/0x4680F8 闭合；渲染循环内 pending=0（残余为运行时 candidate）。
- SceneEntities（Finding 269）：世界实体渲染管线 closed（primary-static）——帧函数 0x41BCB7→0x419D40 世界排序通道（4 个 y 排序画家数组 root+0x154 实体/+0x2E4 特效/+0x474 装饰/+0x604 地面物品；tick 分派 0x41A528/0x41A534、绘制分派 0x41A568/0x41A570；排序公式/剔除/名字查找/遮蔽登记 [root+0x364444]）→0x41C450 瓦片通道（每可见瓦片 0x41C860 地面物品（[0x566DD4]+0x466130 WIL 查找、0x460240/0x4542A0 blit）/0x41CA20 装饰/0x41CBD0 实体/0x41CD50 特效）→0x41CBD0 类型分派 0x41CD0C/0x41CD1C→[vtable+0x7C]=0x40B2C0（世界→屏幕 sx=(([e+0xCC]−[cam+0x12C])*3<<4)−[cam+0x134]+[e+0xD4]−0xC8、sy=(([e+0xD0]−[cam+0x130])<<5)−[cam+0x138]+[e+0xD8]−0x9D→[e+0xE4]/[e+0xE8]）→0x404DA0/0x404E10/0x461ED0 blit；怪物 tick 链 0x40ADD0→0x40AFD0→0x40A2B0→各状态槽→painter 0x405630；元素→WIL 绑定与帧公式定案；旧 candidate [vtable+0x1C]@0x419DDA/0x419E5A（世界循环 tick）、0x41BC1F（HUD tick）定案；pending=运行时项（怪物 4..0x31 每瓦片 blit 顺序、实体表头插入、0x4764B0/0x4765B0 安装、帧表内容等，需运行时捕获）。
- ServerData（Finding 273）：服务器业务数据交叉引用（derived，非客户端主证据）——stditem.dat 184B/xor04 1143 条（金创药/魔法药 小-特大全、药水 HP/MP 恢复、looks 图标帧、price 实价=80；Market_Def 定案为库存量非价格）、monster.dat 252B/xor09 432+截尾 1 条（ID@248=序号+1 STRONG、攻击/AC/MAC STRONG、d52 HP 候选含牛老道反常）、magic.dat 120B/xor11 105 条（d0 魔法 id、d20 职业类、d28=d0−2、逐级属性）；Mapinfo 370 条/365 stem（31 必查名全核对、无 id 544、544=Map/ 文件数）；Merchant 318 NPC（body 精灵 id+face）；客户端↔服务器映射 6 条（唯一 primary 链=物品类型 0x0A/0x0B↔cat36 10/11），candidate 留运行时捕获。
- LoginFlow（Finding 267）：预登录/选人 UI 全流程 closed（primary-static）——模式状态机 0x8B1878 全写点（0/2/3，mode1 未用）、启动栈（0x66 连接→主窗口 0x451100→char-select ctor→mode0→PeekMessage 泵）、char-select 4 按钮（F11 选择角色/F13 创建账号/F15 修改密码→Modify_pwd URL→退出/F17）与登录提交 0x7D1、parent 9 按钮（F51 建号/F55 进游戏 0x67/F57 退出/F89 确认 0x64）与阶段机 +0x930 全写读点、parent 分发器 0x458F80 9 消息 case（0x208 角色列表…0x210 断线）、char-select 分发器 0x403B80（501/502/529/530）、网络分发 0x409720 17 项 id→msg 映射、发送链 0x66/0x7D1/0x68/0x64/0x67、36 条字符串（GBK/cp949）全解码；残余 candidate/pending（hub+0x14 写点、F17/F53/F92/F95/F98/F86 语义、wrapper 队列排空、0x47EF10 包内来源、0x7D1 线格式、建号 URL 键名、密码框/淡入动画需运行时捕获）。

## Round 4 (2026-08-11) — 地图语义批次（Findings 274–278，源 = EVIDENCE-INVENTORY C22–C27，RESEARCH_LOG 无 Round 4 头）
- FrameOobSemantics（Finding 274）：FetchFrame 0x466130 — type0 WIL 路径 0x466640（cmp edi,[esi+0x10]; jae 0x466714）、type1/2 ZL 路径 0x466720（cmp eax,[ecx+0x2C]; jae 0x466761）——帧索引越界/空帧(offset 0)/宽高>4096 一律返回 0；7 条绘制路径全部 `test eax,eax; je` 跳过 → 该格不绘制（透明）；取模/首帧/空帧替换/不检查四假设全部排除。
- GroundNotDrawn（Finding 275）：地面 0x43B440 双重门控四道闸 — T%14<=2（0x43B53C，T=file−⌊file/14⌋）、T<=0x45（0x43B545）、frame!=0xFFFF（0x43B54A）、lookup 非空（0x43B569）；T(255)=237 被闸 A+B 拒、frame 0xFFFF 被闸 C 拒；地面缓冲先清空（0x43B455 rep stosd，0x1B0000 B）→ 空格渲染为纯黑。
- OffsetDistribution（Finding 276）：98.8% offset 非零 — 城镇族统一 (−24,−16)（Tilesc/Tiles30c/Wallsc/Cliffsc/Housesc/SmObjectsc/Animationsc/Innersc/Dungeonsc/Sand_*/Wood_*），洞穴族统一 (7,−44)（Tiles5c 10000+/object1c/object2c/SmTilesc 10000+），4,220 帧 (0,0)；furnituresc 垃圾 offset（30280,21537）但 0.map 正常渲染 → 零 offset 读取为有意约定（C5 闭）。
- MinimapCalibration（Finding 277）：小地图帧放置公式 painted rect=(0,0,W·1.5,H) — X 向 1.5 px/格、Y 向 1 px/格、帧尺寸=ceil4(W·1.5)×H、原点左上；面板 128×128 @ (672,0)–(800,128)，随玩家滚动源窗口；帧索引 = server 值−1（MMap.wil）或 −1001（FMMap.wil）；EXE setter 0x43D780（调用者 0x420C3A 做 dec）、float 1.5 @0x476904、帧 rect 0x43D7AD–0x43D7C7、面板 SetRect 0x43D518/0x43D545、lib 串 0x47C414/0x47C428。
- ReservedFrameMarkers（Finding 278）：frame==0xFFFF 精确比较（0x43BB45/0x43BB4A、0x43BBBB、0x43BE3A/0x43BEAB、0x43B321）非掩码；0xFF00–0xFFFE 过 0xFFFF 比较后在 FetchFrame 边界检查失败（0x46664A，lib 帧数最大 33,125 < 65,280）→ 返回 0 不绘制；「保留标记」= 地图数据/编辑器约定，客户端无特殊处理（0x43A000–0x43E000 区域 imm 0xff00 命中 0）；保留记号仅存在于 39 个 legacy 13B 探针图（每 lib 每主题 1 自检格），真实 14B 图保留格=0。

## Round 5 (2026-08-11) — 场景实体渲染闭合（Round5 Verify 无编号段 5195–5229 + Findings 279–283）
- Round5VerifyClosure：scene-entity-render-evidence.json `round5_closure`（corrections×6/occlusion_window/new_identities×4/closed_pendings×5，pending 10→7）— Tile pass1 0x41C48B–0x41C607：y∈[camY−0xA,camY+0x22) × x∈[camX−0xA,camX+0x22) 44×44 格；cam=[root+0xF532C]/[+0xF5330]；遮挡窗口 0x41C5AA–0x41C5DE 仅 [camX,camX+0x18)×[camY,camY+0x18) 24×24 传相对坐标，窗外全部 (0,0) → 网格 cell 0；**0x7F 语义修正：word [e+0x8A]==0x7F = 强制绘制标记**（Round 3「透明」误读；仅 flag==0 且 word≠0x7F 才跳过）；Front pass2 0x41C60D–0x41C7B9：y∈[camY,camY+0x2C) × x∈[camX,camX+0x18)；World sort 0x419D40：rep stosd 清 0x38400 dwords = 0xE1000 B = 24×24 cell × 100 槽 × 16 B；网格 [root+0x154, root+0xE1154)、实体链表头 [root+0xE1158]（node +4=实体、+0xC=next）、cell 地址=1600·(24·dy+dx) B；shadow-flag 插入 0x41A008–0x41A03E = 400B 窗口前插；map 读数修正 ×6（sort tick 0x41A534–0x41A570 类型 0/1→0、2→2、3→1、4..0x31→2、0x32→0；sort draw 0x419E1C 类型 0/2/0x32→0、1/3..0x31→1；renderer 分派 0x41CD1C 类型 0/1→case0 含 shadow 0x40B180 + 名牌 0x40CE20、类型2→case3 跳过、类型3→case1 纯 sprite）；新身份 0x40B180 阴影椭圆（gate [e+0x61BD4]==2）、0x40CE20 时间门控名牌/HP、0x41B570 悬停/选中指针清理。
- StateFrameTables（Finding 279）：运行时帧表（0x8AA5C0 玩家/0x8AA686 怪物/0x8AA6C8 NPC）= BSS 单例 0x8AA5A8 字段，**100% EXE 编译期常量**（server-data 假设证伪）；布局 = 每 state 3 字（基帧, 块长, 间隔）；填充链 0x449C80（启动种子）→ 0x44A240（race）/0x44A090（NPC 动作）→ 0x449C50 三字写入器；无网络/文件/server 输入。
- MonsterDat（Finding 280）：怪物名 ↔ Mon-N.wil lib/帧映射闭（P5/P11）— 客户端 16 位码 = monster.dat Race 字段（非 Appr）；MInfo.dat = 魔法效果库非怪物库（解密链 0x44A910，key f0 39 ab 8e 93 1a de 9f，头检查 0x4525F0）；公式 type3 怪物 race<2000 → element=0x58+race//10（0x4050E4）+ 帧 word[0x8AA686+6·state] + 1000·(race%10) + 10·flag（0x405100）；element 表基 0x5600FC + element·0x144，WIL 管理器 this=0x55A864；槽位格修正 slot offset = 0xf848+slot·0x104，Mon-1=slot18@0x10a90 … Mon-20=37、MonS-1=38…57、NPC=58@0x13330、MonMagic=59、MonImg=60；实测 432/432 Race 命中（0 误）vs Appr 328/7 误；DMon-1 死亡库块索引 = race//10（5 段，194 非空块）；RaceImg × MonImg.wil 负证（93% 空白）；排除 0x45AC00 = 音效/页缓存管理器。
- NpcAppearance（Finding 281）：NPC 外观系统闭 — type 0x32 body 字段 → element 128 → NPC.wil 帧块 + NPCFace.wil 对话框头像；帧分派 0x404FB0 index 3（jump @0x4054EC → 0x4051BB）：[edi+2] body<0x64 闸、state<3、element=128（0x4051E0）、flag=[esp+0x40]%3；公式 word[0x8AA6C8+6·state] + 100·body + 10·(flag%3) — **100× 是 BODY 非方向**（修正模拟器 README/entities.json 100*dir）；NPC.wil = 路径表 slot 79（dest +0x13330）；标准 body 布局 42 帧（state0 3 flag cell +0/+10/+20 × 4 帧；state1 +30/+40/+50 × 10；state2 基 0x3C=60 空白=无攻击动画）；特殊 body 码 1:1 几何（state==1 && body∈{0x18,0x19,0x22,0x23,0x2B..0x32,0x3A} → state=0；body==0x28/0x38/0x39 → flag=0）；绘制链 0x40B330；NPCFace.wil 对话框绑定（dialog ctor 0x43ED00 → window+0x278 @0x43EDB6）。
- PlayerComposition（Finding 282）：玩家外观组合闭 — gender→type→element（M-Hum vs WM-Hum），element 表 0x5600FC stride 0x144（旧 ×36 作废）、WIL 槽表 element=slot、overlay 绘制顺序/帧公式、render-mode 位语义、0x4058E0 帧重置器、M-SHum 排除；descriptor dword+4：byte0 type（0 男/1 女/2 拒/3 怪物/0x32 NPC）、byte2 state/race-lo/body、byte3 race-hi、byte4 mount 样式→[e+0x629C8]；type0→element 71 M-Hum（0x404FE5）、type1→76 WM-Hum（0x405003）；玩家帧公式 word[0x8AA5C0+6·flag] + 3000·S + 10·dir；0x4058E0 = 逐帧动画重置器（vtable+0x10）；stride 0x144 确认（lea ×9 → lea ×4+0x5600FC @0x40590A）；painter 0x405630；槽表 element=slot（slot 基 ebx+0xB130，stride 0x104，140 槽）；头 element [e+0x629CE]=(sel−1)/10−0x7D(男)/−0x7B(女)，武器 [e+0x629CD]=(sel−1)/10+0x48(男)/+0x4D(女)；overlay 6 遍 0x40F5F0（horse1 0x40F681, weapon1 0x40F743, body 0x40F80B, head 0x40F909, weapon2 0x40F9EF, horse2 0x40FA67）；render-mode 解析 0x404DA0；CreateChr.dat = RIFF AVI 过场（不解析）；type byte [e+0x88] 无静态写者（server 填充）。
- TradeWindow（Finding 283）：交易窗（PvP）渲染闭 — id 3 / +0x3399C / frame 1050 静态美术 + **零控件绘制**；关闭/接受/取消 = 不可见命中区；交易 ≠ 商店（id 2）；vtable 0x47663C、ctor 0x4159D0（8 参 ret 0x20，注册 (1, 0x14A=330, 0x1E4=484, 0, 0, 0x41A=1050, [esi+0x1C] 共享库, 3)）；面板帧 1050 = 512×512 @ offset (7,−44)（count 1103）；draw list 0x415B10 全枚举；按钮 3×0xB4（ctor 0x417550，vtable 0x4763A8）：close +0x7C 帧 161/162 (28×26) pos (532,350)；accept +0x130 帧 1061/1062 (48×20) pos (185,332)；cancel +0x1E4 帧 1064/1065 **GameInter.wil 不存在**（header→None）pos (225,332)；不可见机制：按钮渲染 0x417640 零直接 xref + trade paint 无控件循环 → 永不绘制；点击 0x4177F0 = PtInRect+音效+ret 1 无窗口消息；gauge（分割柄）ctor 0x417960（7 参）2 个 @+0x13648/+0x13694（stride 0x4C），帧 1070 = 16×360 @(−24,−16)；物品槽 24 @+0x5B8 stride 0xC2C，item id word 数组 +0x298（400 word，空=0xFFFF，index=cell+pane·200），36×36px 5×6；金币框 rect (34,270)..(156,304)，点击 + strcmp(data+0x1C, 0x47ADB4「确定」)==0 → 0x418030 msgbox 0x405 + 清零 0x30E dwords → ret 1；接受命中 → 0x451B30；商店 = id 2 / +0x33188 / ctor 0x44D310 / paint 0x44E260（经 0x417830 + [vtable+4] 控件渲染循环）；交易 = id 3 / ctor 0x4159D0 / paint 0x415B10（零控件绘制）。

## Round 6 (2026-08-11) — Findings 284–289
- TradeWindowClosure（Finding 284）：trade-window-closure-evidence.json — 基类 ctor 0x423B40 [+0x40]/[+0x44] = 内容区 484/330（注册压栈序 (1,330,484,0,0,1050,lib,3)）；内容 rect [+0x18]=(0,0,484,330)；0x423FA0 = 拖拽移动（16 xref，钳制 0x235/0x23A，偏移 [+0x48]/[+0x4C]，0x4240C0 抓取）；槽代数 cell=col+5·(split+row)（0x416830）、+0x298[cell+200·pane] word%1000=槽号（0x416950）、记录 [0x5B8+id·0xC2C]（0x4170C2）；分割写 0x416E70 遍历 2 gauge @+0x13648（stride 0x4C）→ 0x417C80 命中 → [+0x54+4·i]=trunc(f×94.0)（94.0 @0x476650，_ftol 0x468520）；帧 1050 像素目录（面板 bbox (14,91)–(497,421)≈483×330，双格 pane0 (14,92)–(194,308)/pane1 (246,92)–(426,308) 5×6×36px，金币框帧 (27,226)–(149,260)=窗口 (34,270)–(156,304)，分隔竖条 x≈215–218/239–241/263–265）。
- WeaponHeadSelector（Finding 285）：player-composition-render-flags-evidence.json — [e+0x61C68] 17 写者/8 读者（全 descriptor dword 整拷贝无位运算）；bit0x1 = race 0x53–0x55(83–85) 帧锁门（0x407197/0x40AF55，span 2→3 钳制 @0x40AFAB）；bit0x2 = 名牌可见性（镜像 [e+0x61BD0]）；bit0x100000 = 出生/传送白闪（0x40CE2B，1700ms 计时器 +0x62A2C @0x411239）；bit0x8000000 = 半速（0x405D21 间隔×2+奇 tick 跳过）；mode word = 纯 blit 常量（0x404DA0 6 位 → 1/0/0xFBFF/0xFFE0/0x94BF/0xFCB2/0x7E0，默认 0xFFFF → 0x404E10 → 0x461ED0/0x463330/0x460240）；槽名 78 字面量（0x4534B0–0x454120）：82–86=Inventory/Equip/Ground/MIcon/ProgUse，90–107=Mon-3..Mon-20，108–127=MonS-1..MonS-20，128=NPC，131–134=发/盔，135/136=DMon-1/DMonS-1，139=StoreItem，**70=GameInter@+0xF848**（修正 mir3-dat 表 +0xF744 误标），76=WM-Hum，81=Magic；selector 落点 0x40C7B7–0x40C85D。
- MonsterSpecialCodes（Finding 286）：monster-special-codes-evidence.json — 表分派 0x407610（码 3..0x59 字节表）→ 跳转表 0x4075F0（8 项）— 0x53/0x54→默认 0x4075C5（[0x61c7c]=1 + actor vtable+0x10(8,arg)，无特殊语义）；0x55→0x40742C（alloc 0x13c → ctor 0x434EF0）。
- NpcBodyStrip（Finding 287）：npc-body-strip-evidence.json — NPC 场景实体 vtable = 0x47671C（type 0x32 → alloc 0x629C8 → ctor 0x404960；+0x0C=0x404FB0 包分派、+0x7C=0x40C020 场景 blit）；body 0x38/0x39 条 4..11 帧 = 0x44A090 无条件覆写三条 state 记录 (0,12,0x50=80ms)。
- InventoryModeTabs（Finding 288）：inventory-mode-tabs-evidence.json — 3 页签（bag+0x5C stride 0xB4）= 装饰按钮（点击 0x4177F0 仅音效）；mode byte [bag+0x54] 仅 server 消息写 — mode0 默认（reset 0x42E9A4 / show 0x42AE26）、mode2 变卖 msg 0x286→case10→0x41FA16、mode1 修补 0x29C→case28→0x41FB24、mode3 储存 0x2BC→二级开关 0x42042B→0x420AFC、0x29D=修补续（0x41FB6E 不写 mode）；paint 分派 0x42EF2F jmp [eax·4+0x42F13C] 分支标签 包袱/修补/变卖/储存；0x405 修正：0x451B00（push 0x405）= 唯一 0x405 发送者、唯一调用者死门 0x417280（xref=1）→ 0x405 发送链死；0x451B30（push 0x406）= 交易金币支付活路径。
- StatusAndOptionNames（Finding 289）：status-option-names-evidence.json — 属性值 30 处绘制全 0xfafafa（0x44BD37..0x44CCB2），标签 28 处 0xfae1c8（含 魔法躲避 @0x44C1A7）、4 处 0xff（防御/攻击/魔法/魔法防御力）— 旧「两列 label=0xff」修正；商店状态 0=BUY/1=SELL/2=仓库/3=CRAFT/4=item detail；选项控件帧对（UP/PRESSED 规则，Round 7 F297 目视确认）。

## Round 7 (2026-08-11) — Findings 290–295
- PlayerStateActions（Finding 290）：player-state-actions-evidence.json — SetAction vtable+0x10 = 0x4058E0（ecx=actor，arg1=state，arg2=dir；入口 dir<8、type≤0x32、懒加载基 [esi+0x90]=0x5600FC+[esi+0x8C]·324；分派字节表 0x405D64 + 跳转表 0x405D50）；type 0/1 共享公式 start[state]+storedDir·3000+argDir·10（修正旧 750/40），type 3 经 0x44A240，0x32 NPC dir%3，2、4..0x31 no-op；尾部 0x405CD7 提交 [0xC0]/[0xC1]/[0xC2]/[0xC4]=[0xB4]/[0xC8]=0。
- EntityVtableFamily（Finding 291）：entity-vtable-family-evidence.json — 0x4764B0/0x4765B0 = 大表槽位**从未安装**（0x4764B0 = monster 0x476480+0x30 = 0x406A40，0x4765B0 = 子类 0x476544+0x6C = 0x408630；全文件 imm32 0 命中）→ F269「安装路径」问题无效；F286「0x476400」= 0x4763C0+0x40 槽；家族：0x4763C0 基实体（34 槽，ctor 0x404960，+0x0C 分派 0x404FB0/+0x1C tick 0x40ADD0/+0x20 帧 0x40AFD0）。
- HorseWindow（Finding 292）：horse-window-state-evidence.json — 0x7DA060..0x7DA064 = session 0x777698+0x629C8；byte0 = 2-bit 钳制枚举 0..3（0 = 未骑乘，非零门控「遛马」+ 骑乘帧 × state·400；1/2/3 语义 server 候选）；写者 0x40F420（vtable+0x88）/0x40C720（+0x8C）存 dword[+0x629C8]+byte[+0x629CC]；字 0x7DA061-62 = 玩家染色、0x7DA063-64 = 坐骑 + HUD 马图标染色（0x44B666 → 0x45FD50 arg6 = RLE op 0xC2 填充色，565 掩码 + float 缩放）。
- BagListFillChain（Finding 293）：bag-list-fill-chain-evidence.json — 0x42FC20 = 背包记录放置核心（ecx=bag；栈 flag/slot/record[0xC20] 按值；ret 0xC28；mode 门 [esp+0xC48] → 0x42F2A0 解析 + 0x42F280 空槽扫描（46 槽，flag bag+0x774+i·0xC2C）→ 0x42F440 放置）；13 直接调用者 = 10 handler / 9 msg id {0x35, 0xC8, 0x259, 0x268, 0x27C, 0x2A2(x2), 0x2A4, 0x2A5, 0x2A9}（全 lea ecx,[ebx+0x2AB9E0]）+ 3 非消息路径。
- NoticeBanner（Finding 294）：notice-banner-lifecycle-evidence.json — 0x777200 = id-15 公告窗本体，非独立横幅（winmgr 0x7243A4+0x52E5C；F268 0x7213A4/0x726500 笔误修正）；ctor 0x43E260 一次性（id 0xF，帧 602，x=107, y=110, w=584, h=252）；imm32 0x777200 全文件仅 2 命中（0x425A4C show / 0x425B4A hide），对齐扫描 16 读，仅写 flag [0x7773D0]；无计时器/计数/滚动路径 → 显示时长无限直至显式切换（行会按钮 / 点击 0x42BE99 → 0x43E4B…）。
- TradeGoldFlow（Finding 295）：trade-gold-flow-evidence.json — 0x7EE handoff 忽略金额（输入 → obj+0x130 → SendMessageA(0x7EE, wparam, lparam=&obj+0x130) @0x4185DB；接收者 0x404600/0x45A140 均不读 lparam；分派 0x41E522 → 0x41CDE0）；接受 0x406 在线 = 纯头（0x417034 → 0x451B30 → 0x452940 12B 头 {dword0=0, word+4=0x406}，MIR 编码 0x452740，sprintf '#%d%s!' count [obj+0x14] 9→1）— 无金币字段；唯一活金币发送 = 聊天命令 0x41CDE0 case byte2==0…（Round 9 F305 全灭定案）。

## Round 8 (2026-08-11) — Findings 296–301
- NameplateLabel（Finding 296）：nameplate-label-evidence.json — 共享名牌渲染器 0x40CE20（门 [e+0x61C68]&0x100000 出生白闪 + 1700ms tick [+0x62A2C]，element 81，quad case-2 路径）；server 解析源 0x40D3B0/0x40D420/0x40D660/0x40D6C0；word[ebp+4]==0x321 → 0x434EF0 创建 FX 特效对象入全局 0x560088 特效链（0x40D626 附加 SetAction(0x1D)）；F271「el81=Magic」交叉佐证；闭 scene-entity-render-evidence.json 名牌 pending。
- OptionToggleGlyphs（Finding 297）：option-toggle-glyphs-evidence.json — GameInter.wil 760/761 (32×22) = 开、762/763 (40×22) = 关；761/763 = 按下移位变体（+2,+1）（Jaccard 0.46/0.55 vs 无关对 0.07/0.04）→ 确认 F289 UP/PRESSED 帧对规则；白字形提取需亮度>140；闭 status-option-names-evidence.json 帧对目视 pending。
- MountedGaitSpecialPairs（Finding 298）：mounted-gait-special-pairs-evidence.json — 0x10 = 骑马走、0x11 = 骑马跑（步进阶梯 0x1A@>7 → 0x10@>0xB → 0x11@>0xF — 修正 F290：帧间隔 ≠ 步态速度）；0x15/0x1E 与 0x16/0x1F 地面/骑乘对；fx 0x22=跑家族/0x23=走家族；0x17 完成 → 0x13/0xF/0x20；闭 player-state-actions-evidence.json 挖矿/钓鱼对赋值 pending。
- CharCreatePreview（Finding 299）：quad-renderer-7case-evidence.json — 0x466CE0 = 7-case 分派（跳转表 0x466EFC）；每 case → (v+0x50, v+0x94) 状态对；float[0x476658]=1.0；11 调用者（建号预览链）。
- NpcBodyWriteSite（Finding 300）：npc-body-write-site-evidence.json — 全编码（C6/88/89, disp8+disp32）字节扫描 = [e+0x8A] 无直接写（0x46C92B/0x423FD1 假阳性排除）；唯一写 = 0x405862 mov dword [esi+0x88],ebp（0x405630 外观/type 更新，arg=[esp+8] server 外观码，跳转表 0x405894 分派 <0x32）；case 写 [e+0x8C]、坐标 [e+0xB4/B8/BC]（表 0x8AA5C0/0x8AA5C8/0x8AA686）；10 server 包调用点（0x404FB0 实体分派 + 0x40C3B0/0x40F420…）。
- TradeSplitHandle（Finding 301）：trade-split-handle-evidence.json — [trade+0x54]/[trade+0x58] 维度 = 每 pane 顶部可见数据行索引（行偏移，非比例非行数）— 命中 0x416830 cell=col+5·(split+row)，绘制 0x4169B0 y=y0+0x30+36·(row−split)，pane 步长 40 行、6 可见行 → 可用 [0,34]；仅 2 鼠标 handler 写者（0x416E70 经 0x417C80 绝对设 / 0x416EF0 家族经 0x417D00 步进，strcmp 门串 0x47ADB4），公式 trunc(gauge_pos×94.0)；94.0 @0x476650 全部读者恰 4（交易…）。

## Round 9 (2026-08-11) — Findings 302–306
- TradeGoldConfirmChain（Finding 302）：trade-gold-confirm-chain-evidence.json — 0x405 发送路径双重死亡 — 路径 A：金币对话框确认（键盘 0x418520 / 点击 0x418600）→ 0x7EE wParam=0x03000405 → 总线 0x41E2B0 → 0x41DFE0 → 0x42D650（门 [ecx+0x51180] + stub 0x440740 `xor eax,eax; ret`）→ [0x8AA4A4] 恒 0 → 聊天命令发送永不触发；路径 B：唯一 0x405 发送者 0x451B00 ← 门 0x417280（精确匹配 0x03000405）← 0x42D6BA（dl=3）← 0x41CEC2 ← 需 0x7ED byte3==3…（0x7ED byte3=0 恒）。
- InputMessageBus（Finding 303）：input-message-bus-0x7ed-0x7f0.json — [0x8AB7B0] wndproc 0x41E2B0 全树（msg≤0x202 链 / >0x202 / 0x7ED..0x7F0 范围表 0x41E690 / 0x113..0x201 跳转表 / 默认 0x41E30A）；栈布局 (wParam, lParam) 证明；0x41CDE0 byte3 分派 + 命令表 0x64..0x67 语义修正（0x64=row1→WM_CLOSE、0x65=row0→server 0x3F1、0x66→0x3F8 聊天金币、0x67→lParam 低字 0x40E）；0x42D680 映射修正（index=dl−3，表 0x42D700：dl3→0x417280、dl4→…）。
- InputDialogConfirmPaths（Finding 304）：input-dialog-confirm-paths.json — 对话框类 ctor 0x418030 8 参（type→[e]、prompt→[e+0x2C]、msgId→[e+0x460]、arg6/7=−1 居中）；TAB 循环行（0x418470，stride 0xB8）；键盘确认 0x418520 / 点击确认 0x418600 → wParam=((type<<8|row)<<16)|msgId、0x7EE + lParam=&[e+0x130]；24 ctor 点；金币链 0x42BE21→0x42C4D4 idx3→0x42C00B→0x416EF0→0x416F7E。
- ChatSubmitDeadPath（Finding 305）：chat-submit-dead-path.json — [0x8AA4A4] 写者恰 4 全清零（0x40274A/0x4194FC/0x41E245/0x456CE4）→ 恒 0 → 0x41DFE0 聊天命令发送（0x4520F0 @0x41E22F）不可达；聊天 0x7ED wParam∈{0,1}（byte3=0）→ 0x42D680 默认 no-op；0x64..0x67 命令表不可达 — 修正 F295「0x66→0x3F8 唯一活金币发送」：本构建聊天提交为静默 no-op，金币发送全灭。
- TradeGoldPacketFormat（Finding 306）：trade-gold-packet-format.json — 构造器 0x452940 12B 布局 {dword arg3, word msgid@+4, word, word, word}（修正旧翻转）；0x405={dword amount, word 0x405, 0,0,0}、0x3F8 同形、0x406={0, 0x406, 0,0,0}、0x3FC/0x3FD/0x3FE={0, id, 0,0,0}；发送者 0x451E60 帧 '#%d%s%s!' (0x47C840)/'#%d%s!' (0x47C800) + count 1..9 + socket 0x468098；解析 0x4681F9；[0x7DA100] 死配置。

## Round 10 (2026-08-11) — Findings 307–311
- NetworkMessageObjectAnatomy（Finding 307）：network-message-object-anatomy.json — 入站帧管线全闭 — 编码器 0x452740 = MIR base64（charset=value+0x3C；count 从 0 起 — 0x452750 `mov [esp+0xc],edi` 循环前预零死槽，push ecx = MSVC 分配惯用语；ret 0x10；栈图 [C+4]src/[C+8]dst/[C+0xC]len/[C+0x10]max），手写解释器 3 向量字节精确（chat 6B→`4c50453f4d3c00`、hello 22B→30B、空→0）；跳转表精确：字节表 0x421D8C（type 6..0xC8）→ 指针表 0x421D5C 12 槽 — idx0→0…。
- HudHpMpXpInjectionChain（Finding 308）：hud-hp-mp-xp-injection-chain.json — HUD HP/MP/XP 全局仅帧链写者 — 全编码扫描（89/8B modrm+abs32 全寄存器、C7 05、66 89、C6 05、A3、lea）[0x35A34C]/[0x35A34A]/[0x35A34E] 写者恰 2 路径：msgid 0x1F（pump 默认：word[item+6]→cur、[item+8]→max）与 msgid 0x34（0x423000 全自属性：97B 块 [0x35B1F0]，HP cur 0x7DA10D/MP cur 0x7DA10F/HP max 0x7DA111/MP max 0x7DA113/XP cur 0x7DA115）；XP-max…。
- WsaAsyncSelectDispatcher（Finding 309）：0x7e8-wsaasyncselect-dispatcher.json — socket 层 = WSAAsyncSelect 事件机 — 0x7E8→总线 0x41E2B0→0x451BB0(0x8AB828, sock, MAKELONG(ev,err))→错误分类 0x4515C0（致命→MessageBoxA+WM_CLOSE [0x8AB7B0]）；FD_READ→0x451CC0（recv 0x2000→`*` ack→realloc 0x468D6E 追加→state==3 ? 缓冲 : 回调 vtable[+4]）；FD_CONNECT→0x451C40；hello 0x4514F0 / 帧发送 0x451E60 指令精确；WS2_3…。
- MinimapPlayerMarkerChain（Finding 310）：minimap.json — 小地图玩家标记数据源修正 — Round 9 目标 0x7D9234/0x7D9238 = 死亡/复活检查对 ONLY（读 0x422985/0x42298B/0x422995 `x−y<9` 延迟，0x422A15/0x422A1B 零写）非小地图输入；真实链：实时坐标 [0x777764]/[0x777768] = [screen+0x2F884C]/[+0x2F8850]（Y/X）— 全编码穷举扫描（89/8B 全寄存器 abs32、C7 05、66 89、C6 05）+ 指针相对扫描恰 2 写者 0x422A9E（Y=word[item+6]）/0x422AC5（X=word[item+8]，…）。
- SimulatorMessageAndMinimapWiring（Finding 311）：simulator-message-and-minimap-wiring.json — 模拟器数据管线接线 — Tools/web/build_mir3_simulator_data.py（规范生成器，非 reverse-engineering 同名文件）hud.json minimap note = F310 完整解剖；frame_tables.json 增 frame_dispatch（12 行跳转表、big-type 链、pump 分派、队列项、base64 编码器）；重跑成功（windows=14 controls=40 resources=157 entities=8 skills=12 maps=2 bindings=211，0.45s），回读校验…。

## Round 11 (2026-08-11) — 聊天窗输入侧全闭（Findings 312–313）
- ChatWindowMouseDispatch（Finding 312）：chat-window-mouse-dispatch.json — FnA 0x42BA20 六级优先链：①[0x53060]→0x418A50(0x53030,x,y) ②[0x52E8C]→0x43E640(0x52E5C,x,y) ③滚动条 0x417D00(0x61BC,x,y) 命中→滚动定位 [0xD08]=ftol(fild([0xD20]−1)·fmul[esi+0x61C8])（0x468520）④caption 循环 i=0..15 @0x567C+i·0xB4 call [vtable+0xC]=0x4177C0 ⑤0x428570(chat,x,y) ⑥0x42AAB0 命中分派：−1→0x42BD8D（0x42B820 全关…
- ChatWindowControlMap（Finding 313）：chat-window-control-map.json — 控件 id→子窗 0=0x6554、1=0x29CE4、2=0x33188、3=0x3399C、4=0x4707C、5 no-op、6=0x47834、7=0x47C28、8=0x507EC、9=0x51150、0xA no-op、0xB=0x516E8、0xC=0x518E0、0xD=0x52118、0xE=0x524F0（mousemove 加 id15=0x52E5C）；16 caption（0x567C+i·0xB4；RECT+4、帮助帧 id+0x20=−1、byte+0x24=1、byte+0x25=0、x+0x28、y+0x2C、文本+0x34、窗口对象+0x14、id_lo+0x18、id_hi+0x1C、+0x30=0）：cap0 交易 0x50/0x51 +0xCC『交易栏(Ctrl+C, C)』@0x47BBE0、cap1 小地图 0x52/0x53 +0xE4『小地图(Ctrl+V, V)』、cap2 图鉴 0x54/0x55 +0xFC『技能图鉴(Ctrl+B, B)』、cap3 退出 0x5A/0x5B +0xA1+0x2E『退出游戏(Alt+Q)』、cap4 注销 0x5C/0x5D『注销人物(Alt+X)』、cap5 组队 0x5E/0x5F『组队(Ctrl+G, G)』、cap6 行会 0x60/0x61『行会(Ctrl+F, F)』、cap7 腰带 0x9F/0x9F +0x189+0xD『腰带(Ctrl+Z, Z)』、cap8 技能书 0x64/0x65 +0x2BF+0x10、cap9 聊天记录 0x66/0x67 +0x2CE+0x20、cap10 信息窗口 0x68/0x69『信息窗口(Ctrl+D, D)』、cap11 设置栏 0x6A/0x6B『设置栏(Ctrl+N, N)』、cap12 0x6C/0x6D『档框…』损坏、cap13 坐骑 0x6E/0x6F『坐骑(Ctrl+S, S)』、cap14 包袱栏 0x70/0x71『包袱栏(Ctrl+Q, Q)』、cap15 状态栏 0x72/0x73 @0x47BBCC（action 0x42C30D = 0x42ADB0(1) 双 toggle + 0x423E80(0x29CE4,0xC8,[0x29CFC],[0x29D00],0xF4,0x148) 大地图 244×328）；caption ctor 0x417550（9 参 ret 0x24；SetRect 帧 [window_obj+0x38]）；tooltip 0x417640（门 +0x25==0/+0x24==1/+0x20!=−1）；action 表 0x42C494 16 项（0=0x42C1CE、1=0x42C259、2=0x42C241、3=0x42C2E1、4=0x42BF37、5=0x42C218、6=0x42C209、7=0x42C292、8=0x42C302、9=0x42C226、10=0x42C1A4、11=0x42C1B2、12=0x42C359、13=0x42C1C0、14=0x42C234、15=0x42C30D）；右侧 8 个 22×22 SetRect（cap8..15 精确坐标）；腰带：6 斜槽（0x117+i·0x28, 0x1B0+i·0x10）38×38 @0x427DDE；槽 @0xDA4 stride 0xC24 {valid+0, 0x308-dword 栈+4, byte+0x26, type word+0x2C}；访问器 0x42D790 清空 / 0x42D8A0 取（rep movsd 0x308=0xC20B）/ 0x42D7C0 补充（SEH 0x474FD8；6 槽计数；0x403AC0 调用；仅头）；Kbd 分派 0x42CBD0（ret 8；arg1=VK→esi；5 门： [0x53060]、[0x52E8C]、[0x5081C]→push 8；0x42B980 + 0x414DC0(0x507EC,vk,arg2)、[0x20]&&[0x24]）；字母热键全验证：Q→toggle(0)+[0x65A8]=0+post 0x417880(lea [0x6718],−1,0x10C,0x10B)；W→toggle(1)；E→toggle(0xE)；R→toggle(8)；S→toggle(0xD)；D→toggle(0xB)；Z=CLAMP…；C→交易请求（0x41EC10([0x777764],[0x777768],[0x777759],1) 最深优先压栈 + ret≠0→0x451A70(0x8AB828)）；V→小地图（timeGetTime−[0x6210]≤0x64；[0x6518]==0→0x451770(0x8AB828) 开否则关）；B→[0x6208]=!([0x6208])；G→toggle(6)；F→0x4523E0(0x8AB828)；N→toggle(0xC)；T→[0x6518]==1→[0x64A8]=!([0x64A8])；new≠0→0x43D5F0(lea ecx,[0x6214],[0x8AB7BC],0x100,0x100) 否则 (…,0x80,0x80)；Y→[0x6518]==1→[0x64A4]=!([0x64A4])；VK 分派头 `0042CF1F lea eax,[esi-0xd]; cmp eax,0xb2; ja 0x42d4b4; movzx ecx,byte[eax+0x42d550]; jmp [ecx*4+0x42d520]`；VK 字节表 0x42D550 179B 精确（off00=01 Enter→case1；off0B=03；off0D=02；off17..0x1C=07,06,05,04,08,09；offB2 (VK 0xBF '/')=0A→case10；其余 165B=0B→case11；case0=0x42D511 共享 ret-0 尾）；case1 Enter（门 [0xD38]!=0 + GetFocus([0x476250])==[0x8AB7B0]；[0xD2C]=[0xD30] 顶、[0xD34]=count−1；id≠9→toggle(id)；id==9→mov ecx,0x47EF18; call 0x41C1E0 关 聊天记录(9)+图鉴(2)+交易(0)）；case2/3 缩放（门 [0x7E04F0]==0 && GetFocus()==[0x8AA48C]；Ctrl 测试 al,0x80 低位 bit7 与字母 AH 检查不对称 — 字面保留；[0x6534]/[0x6550] 钳制 [0x6530]/[0x654C]）；case4..9 方向键（Shift→'\x21'/'@' 等 + 0x450C70(0x8AA488) 拷贝 + SetFocus/ShowWindow([0x8AA48C],5) + SetWindowTextA + SendMessageA([0x8AA48C],0xB1,1,1)；共享尾 0x42D251 `SendMessageA([0x8AA48C],0xB1,len,len)`）；case10 '/'（SetFocus+ShowWindow(map,5)；[0x531EC]==0→拷 '/' 0x47AD94；strlen−1→0x42D251）；case11 默认（鼠标 [0x7DA1…]；腰带 kbd 尾 0x42D293（槽基 [ebp+slot·0xC24]；type word [slot+0xDD0]；byte [slot+0xDCA]≠0 跳时门；timeGetTime−[0x29CD8]：>0x7D0(2000ms) 过、≤0x3E8(1000ms) 拒、中间 type∈{0x14,0x15,0x46} 过；valid [slot+0xDA4]→[0x20]!=0&&[0x24]==0&&[0x28]==0 + 内联 strcmp [0x3C] vs 0x47ADB4『陛傈』（循环 0x42D336/0x42D39E）+ 文本≠哨兵 + mode [0x5A]∈{0,3}→SWAP 0x42D8F0 否则 USE 0x42D9E0；invalid 槽同门→PLACE 0x42DAA0）；0x42D3E5 聊天发送：文本≠哨兵&&[0x20]!=0&&[0x24]==0&&[0x28]==0 → 频道 [0x75]；push text; push channel; push 0x3EE; mov ecx,0x8AB828; [0x24]=1; [0x34]=1; call 0x451910; [0x29CD8]=timeGetTime；拒绝串 0x47BD7C/『正在补充药水,请稍候.』0x47BDA4；药水使用 0x42E2D0：type byte [buf+0x22] → >0x1F → 0x42E3EC msg 0x76；索引表 0x42E428 32B 精确；0x45DD00 = 子串搜索（strlen 双方；len(token)>len(name)→0；strchr 0x468BF0 + repe cmpsb 全→1）；kbd 调用者 0x41DD8A（0x42CBD0 优先非零短路；[game+0x364444] 链→0x413A30；GetKeyState('M')→[0x2F8840] 门→0x4520F0 + 冷却 [0x4279A4]=0x3E8；二级 kbd 表 0x41DF68 VK 0x0D..0x68 带 Ctrl 组…）；草稿修正：Z=CLAMP 非增量、C 参数最深优先、T 参数 lea ecx 在前。

## Round 12 (2026-08-11) — 窗口可见性/位置分派全闭 + IAT 修正（Findings 314–315）
- WindowVisibilityDispatch（Finding 314）：window-visibility-dispatch-evidence.json — toggle 分派 0x42ADB0 全闭 — 头 push esi/edi; mov esi,ecx; xor edi,edi; call 0x42B820; mov eax,[esp+0xC]; cmp eax,0xF; ja 0x42B3DD; jmp [eax*4+0x42B3E4]（无条件全降级再分派）；返回约定 edi=1 开 / 0 关或非法（id 5/10/>0xF → 共享尾 0x42B3DD）；0x42B820 = demote-all 非 hide-all：[0xD34]=0、[0xD2C]=head、链表走查每节点 id≤0xE → 表 0x42B938（13 子窗偏移 0x6554..0x524F0）→ push 0; lea ecx,[esi+off]; jmp 0x42B8F0 → call 0x423F90（[sub+0x34]=0），id 5/10/0xF → 0x42B8F5 no-op、count 0 → 0x42B934；case 模式 flag=[obj+flagoff]、sub=[obj+flagoff−0x30]…
- WindowPositionDispatchAndStateSeeds（Finding 315）：window-position-dispatch-evidence.json — 0x423FA0 第二 SetRect 目标 &win+0 → **&win+8**（第一 &win+0x18 不变），参数 4/5 = left'+origW / top'+origH（非 right'/bottom'）；origW=[win+0x10]−[win+8]、origH=[win+0x14]−[win+0xC] 入口捕获 → win+8 = 外框重居中 rect、win+0 = 不动 home rect（closed_2026_08_10「&win+0 重居中」声明作废）；0x42B430 头修正：非 hide-all — [esi+0x5081C]!=0 && 0x42B980(esi,8)==0 → ShowWindow([0x8AA48C], 0)（聊天记录 id8 开但非顶仅隐藏地图输入条）；mousemove stub 表 0x42B658 全表（16 项：0→0x42B4AB(0x6554)、1→0x42B4C9(0x29CE4)、2→0x42B…）；状态种子 0x423F80=+0x30 可见位 setter（唯一 E8 调用者 0x43F033）；0x423F90=+0x34 激活 setter；0x4240C0=抓取 setter；0x42B980=is-top（[0xD2C]=顶、[0xD34]=count−1、cmp 返回 1/0）；IAT [0x476250]=GetFocus 解析（无 GetActiveWindow import）。

## Round 13 (2026-08-11) — 聊天热键标签↔处理函数一致性（Finding 316）
- HotkeyLabelHandlerConsistency（Finding 316）：hotkey-label-handler-consistency.json — F313 pending「Q/D/N 标签↔处理函数不符」全闭（fresh primary-static dumps）— **窗口 id 定案：id0 = 包袱栏/背包 bag**（winmgr+0x6554、ctor 0x42EA80、F250、rect (518,0,324,284)、toggle flag [winmgr+0x6584]；旧注「trade」误标），**id3 = 交易 trade**（+0x3399C、ctor 0x4159D0、F1050、rect (0,0,330,484)、无 caption/无字母热键，仅游戏逻辑 0x420486 请求被接受时开），id0xB = 任务 quest（+0x516E8、ctor 0x4473E0、F700、rect (0,0,340,440)、flag 0x51718；客户端自标「信息窗口」— 命名事实非路由错配）、id0xC = 设置 option（+0x518E0、ctor 0x440FE0、F750、flag 0x51910）、id4 = 行会 guild（F600）、id6 = 组队 party（F900，F313「guild」误标）；toggle 跳转表 0x42B3E4（16 dwords）：42adcf 42ae42 42ae91 42aee0 42b06b 42b3dd 42b0ba 42b131 42b180 42b25e 42b3dd 42af2f 42af7e 42afcd 42b01c 42b2ad — case0=0x42ADCF（包袱）、case11=0x42AF2F（任务）、case12=0x42AF7E（设置）、case10→共享 0x42B3DD；统一模式 flag=[winmgr+off+0x30]、sub=[winmgr+off]、close=0x42AC50 移除+show(0)、open=0x42AC30+show(1)（case0 尾另含 0x417880 聊天输入 post + 0x42FF90 背包输入重置）；字母热键（GetKeyState edi=[0x476278] 取 **AH** 判按住 — 与 map-zoom AL bit7 不同）：Q@0x42CC7C→`push 0; call 0x42adb0` = toggle(0) 包袱、D@0x42CD1B→`push 0xb` = toggle(0xB) 任务、N@0x42CE76→`push 0xc` = toggle(0xC) 设置、G@0x42CE41→`push 6` = toggle(6) 组队、F@0x42CE5B→0x4523E0 行会请求、B@0x42CE1D→[ebp+0x6208]=!(…) 图鉴、V@0x42CDDA→小地图开/关（字母门 0x64=100ms vs caption 门 0xbb8=3000ms — 入口冷却差异，动作一致）；caption action 表 0x42C494（16 dwords）：idx10 信息窗口→0x42C1A4 `push 0xb; toggle` == D、idx11 设置栏→0x42C1B2 `push 0xc; toggle` == N、idx14 包袱栏→0x42C234 `push edi(0); toggle` == Q、idx5 组队→0x42C218 toggle(6) == G、idx6 行会→0x42C209 0x4523E0 == F、idx1 小地图→0x42C259（门 0xbb8）+0x451770/[0x6518]=0 == V、idx0 交易栏→0x42C1CE = 交易**请求**（[0x777764]/[0x777768]/[0x777759] + push 1 + ecx=0x47EF18 + call 0x41EC10 → 非零再 add eax,8 + ecx=0x8AB828 + call 0x451A70）非窗口开关；**结论：Q/D/N 三对 caption/hotkey 全部 pairwise consistent；F313 pending 系窗口 id 误标非真实不符**；EI-313 conclusions[5]/pending[0] 已就地 CORRECTED/CLOSED。


## Round 14 (2026-08-11) — 地图逐张 survey 全量收口（Findings 317–320，地图侧）
> 地图侧非 UI 窗口，但属 544 图坐标/渲染完整交付链：见 `docs/research/mir3-map-reconstruction/`（survey-round14.json + 4 个 evidence JSON + comparisons/ marker PNG）。

- FrameOOBSpaceConfusion（Finding 317）：lib-space-frame-oob-evidence.json — **C11 修订**：3.map/41.map/50.map frame-OOB = lib/frame-space 混淆（槽指向 smobject/wallsc 但帧值属同主题兄弟库 tile/house 空间），EI↔ZL 帧数实测全一致（Wood/Tilesc 3927/3927、Tiles5c 20000/20000、Tilesc 9836/9836…唯一例外 ZL Sand/Dungeonsc=16654）→ 两客户端均透明；sibling-lib 存在性表（wood_smobjectsc 2531 → Wood/Tilesc 2531、wood_wallsc 4537 → Wood/Housesc 4537、sand_smobjectsc 3618 → root/Sand Dungeonsc、sand_housesc 1752 → Sand/Tilesc）。
- D10031NorthEdgeGroundOOB（Finding 318）：d10031-north-edge-evidence.json — 全局唯一 ground 帧-OOB = D10031 ground tiles5c 62 格全在北边缘 block 行 y=0，帧 42756–42766 任何库均无 = 真缺失 edge art。
- ZLRegenerationStaleness（Finding 319）：zl-regeneration-staleness-evidence.json — ZL 64 个 .Zl 2026-08-11 09:57 重生成与 EI 同帧数；resource-consistency.json（8/10 20:49）ZL 帧数引用 STALE；l.count 是元数据、l.entries/l.headers 才是条目。
- Class8EmptyGroundMarker（Finding 320）：class8-file0xff-evidence.json — 23 图 670 格 ground 空格全部 file=0xFF 字面标记（0 个 valid-file+0xFFFF/FF7F）；位置模式 = 有规则留空（74 中央洞、D12121 左上、0_003 顶部带、123 东缘单列、D1401 系角落带）。

## Round 15 (2026-08-12) — HUD caption action 长尾闭合 + 0x418/0x419 单调用点定案（Findings 321+）

- HUDCaptionActionTail（Finding 321）：hud-caption-action-tail-evidence.json — **0x42C494 全 16 项 caption 业务映射闭合（primary-static）**；分派结构 = 16 次迭代循环 0x42BEF8→0x42BF02→handlers→0x42C359 回边→0x42D720（修正「0x42C359 公共 no-op 尾」误 disasm）；16 ctor 调用点（0x4279B2..0x427D94, ctor 0x417550）slot/偏移/帧对/字符串 VA 字节级核实（修正 cap4–6 帧号 0x5C/0x5D、0x5E/0x5F、0x60/0x61）；F313 字符串区错标修正（0x47BBE0=cap14 包袱栏，cap0 交易栏=0x47BCE0）；长尾业务映射 idx3 退出/idx4 注销（0x419CC0 恒真 gate→确认框 msgId 0x65）/idx7 腰带/idx8/9/13 技能书聊天坐骑 toggle/idx12 帮助 no-op/idx15 状态栏（SetRect 244×328）；0x419CC0 = 恒返回 1 补丁（`80 3d 58 77 77 00 13 90 90`，双分支槽 NOP）；协议消息层 opcode 表字节验证（0x418@0x451A10/0x419@0x451A40/0x401@0x451A70/0x409@0x451770/0x40C@0x4523E0 等，装配 0x452940+发送 0x451E60）；0x418/0x419/0x416 E8-scan：0x451A10→0x44862B 唯一、0x451A40→0x448148 唯一（任务窗专属，业务名 candidate）、0x4519E0→4 callers；npc 记录「0x419 also covers NPC option clicks」无静态证据已修正；0x42C4D4 15 case 编号修正（case5/10=no-op、case9=NPC 模型）。

## Round 16 (2026-08-12) — 交易窗点击绑定全链闭合（Finding 322）

- TradeWindowClickBinding（Finding 322）：trade-window-click-binding-evidence.json — **交易窗（id3）点击绑定全链闭合（primary-static）**；ctor 0x4159D0 五子控件表（+0x7C X 关闭 0xA1/0xA2、+0x130 交易按钮 0x425/0x426 交易 label、+0x1E4 隐藏按钮 0x428/0x429 空白帧、+0x13648/+0x13694 输入框 ctor 0x417960 stride 0x4C）；分派链 0x42BEAA→0x42AAB0→0x42C4D4 case3=0x42C00B→0x416EF0（唯一 caller 0x42C017）；0x416EF0 全分支：금전(金钱) EUC-KR 令牌 strcmp 门 + PtInRect → 金币对话框开窗 0x418030（prompt 0x47AD98『您要付给对方多少金币?』、msgId 0x405）——与 F302 确认链（0x418520/0x418600→0x7EE→死链）无重叠；lock 标志 [trade+0x13644]（accept 后点击惰性）；交易按钮 → **msg 0x406 @0x451B30（协议表新增项，唯一 caller 0x417034）** + lock=1；X 按钮 → ret 1 → toggle id3 关闭；隐藏按钮 → 消费 no-op；左格 +0x5C → 0x416830/0x416950 双 cell → 0x416C20 格内移动 / 0x416D60 取回 / 0x416DC0+0x451AA0（msg 0x402, buffer=+0x12A28, value=[+0x12A61]）转移；**右格 +0x6C 无点击绑定**（输入侧仅左格，draw-time 选侧 ≠ 输入处理）；0x418030 E8-scan 24 调用点全表。

## Round 17 (2026-08-12) — 0x40C020 caller 全链闭合 + vtable+0x7C 多态槽定案（Finding 323）

- EntityHeadbarVtable77cCallers（Finding 323）：entity-headbar-vtable77c-callers-evidence.json — **target-box 记录末项『0x40C020 caller unidentified』闭合（primary-static）**：
  - **0x40C020 = vtable 0x47671C（NPC/怪物实体）slot +0x7C** — 无 E8 直接调用；vtable 安装点唯一 = 0x42264E（msg 0x327 解析器 0x4225E0；al==0x32→实体 vtable、al∈{0,1}→玩家 ctor 0x40C560（vtable 0x476480）、其余→基类 ctor 0x404960（vtable 0x4763C0））。
  - **恰 4 个间接调用点**（`FF 5? 7C`/`FF 57 7C` 双编码扫描：mod01 0x50–0x57 + mod10 0x90–0x97）：**0x41C831**（帧渲染 0x41C450 本地玩家路径，此=玩家 → 0x40F5F0；调前 [player+0x61C58]=9/[+0x61C5C]=5 调后恢复 0）+ **0x41CCA1/0x41CCC9/0x41CCEA**（实体渲染循环 0x41CBD0 类型分派）。
  - **实体循环类型分派**：`mov dl,[esi+0x88]; cmp dl,0x32; ja → 跳过`；字节表 **0x41CD1C**（00 00 03 01 03…03 02：0→case0、1/3→case1、0x32→case2、2/4..0x31→跳过）→ 跳表 **0x41CD0C**（case0→0x41CC8E、case1→0x41CCD7、case2→0x41CCB6、case3→0x41CCED）；5 栈参 + this（a1=edi+0xF5200 tile ctx、a2=0、a3=[edi+0x30]、a4=1、a5=0/1 本地玩家标志）；case0 调后 0x40B180+0x40CE20、case1/2 调后 0x40B180。
  - **vtable+0x7C = 多态『实体头部信息条/屏幕 anchor』槽**：基类 0x4763C0→0x40B2C0、玩家 0x476480→0x40F5F0（target-box 记录 anchor 函数）、NPC 0x47671C→**0x40C020**；+0x78=0x406CC0、+0xC=0x404FB0（Init 分派）、+0x84=0x40B850 三 vtable 共享。
  - **0x40C020 语义（头部 HP 条+名字，ret 0x14）**：anchor 公式 ([esi+0xCC]−[ctx+0x12C])·48 − [ctx+0x134] + [esi+0xD4] − 0xC8（与 0x40F5F0 同构）；HP 分数 [esi+0x61C58]/[esi+0x61C60] → 填充字节 0..0x1F（shl 5 − sub = ×31；idiv；cl=0x1F−al；cmp cl,0x1F; jbe 超界置 0；[esp+0x20] 非零时加 0xFB/+5）；名字 0x462710（ecx=0x8AB7A8；0x8A68D4=空串 ''；~10 参含 record 字字段/0x320/0x1EC/0xD）— arg5==0 跳过（本地玩家名字走 0x41C831）；条 0x404E10（[esp+0x28] + and 0xFFFF; cmp 0x94BF 模式分派）；状态位 0x404DA0（[+0x61C68] bit 0x800000 → 1/0xFFFF）。
  - **0x40F5F0 双路径确认**：E8 唯一直接 caller = 0x4120EE（0x4120B0 固定 anchor 路径：预写 [ecx+0xE4]=0x178(376)/[ecx+0xE8]=0xE3(227)，门 [ecx+0x62A48]!=0，ret 0x10；0x40F5F0 的 a4=调用方 arg3 非零 → 覆盖 anchor）+ **间接 vtable 调用 0x41C831**（玩家路径）——target-box 记录『only_direct_caller』为 E8-only 结论，本证据补全间接调用。0x40F5F0 全函数 fresh 复核（0x40F5F0–0x40F6FC）：写此+0xE4/+0xE8 → [esi+0x629C8]!=0 && [esi+0x62A14]!=0 && [esi+0xC0]>=0x1D → A=[629C8]·400−[8A]·3000+[C4]−0xAA0、[esi+0x62A20]=A、div 0x190、frame=0x2710+(A%400)、call 0x466130——与记录『10000+(A%400) series on element 0x57 (0x566F18)』逐字节一致。
  - **类型字节 0x32=NPC 证据**：0x4123E3（mov eax,[0x7E335C]; cmp byte [eax+0x88],0x32 → ret 1 全局 NPC 检查）；0x43DC65（cmp [edi+0x88],0x32; jne; fild [edi+0xCC] 浮点取世界 x）。**[esi+0x88] 写入 = 0 命中**（0x88/0x89/C6/C7 全 mod 含 SIB disp8/disp32 穷举，primary-negative）→ [INFERENCE] 经 vtable+0xC Init 0x404FB0 家族（跳表 0x4054EC、分类字节表 0x405500 值域 0..0x32）或 F300 0x405862 外观/type 更新（跳表 0x405894）设置。
  - 解析器尾部（0x4227A6–0x4227BA）：[esi+0x61C58]=0x12C(300) HP 上限、[esi+0x61C5C]=0 HP 当前；实体入表 mov edx,[edi+0xE1154]; push esi; call [edx+4]。
  - **边界说明**：0x40C020 是第六个独立绘制路径（通用实体头部条），不在悬停目标框 5 函数（0x40B750/0x40B79C/0x40B811/0x40B850/0x40BB00）之列；F257 的 0x41C063 = call [edx+0x84]（=0x40B850 name-plate box），槽位 +0x80（0x40B750）vs +0x84（0x40B850）与本案 +0x7C 不同。

## Round 18 (2026-08-12) — 选项窗 settings 长尾闭合 + F260 修正（Finding 324）

- **Ambience 死开关（primary-static negative 定案）**：跳表 0x44194C idx5/6 = 纯换帧 + save，无 [+0x5C] 写、无音频调用；状态字节 [+0x5C] 生命周期 = ctor 清零（~0x440FA8）→ load 写（0x441EFA）→ 仅 2 读取（0x4412D2 restore、0x441C59 save）。选项在本客户端为视觉-only，无实际音效触发点。**matrix settings pending_notes 项『Ambience actual sound trigger point』闭合**。
- **BGM 音量播放时重应用（修正 F260）**：0x8AB150 = 引擎 0x8AB130 + 0x20；播放路径 0x45B250 @0x45B36D / 0x45B390 @0x45B3B8 经 [reg+0x20] 重读 → 0x45A4A0 → 0x45A700（SetVolume vol*40）；0x45A700 唯一 callers = {0x441F6C 滑杆, 0x45A4E8 播放尾}。旧『ZERO audio-engine references』为绝对扫描局限，已 SUPERSEDED 注记。**pending_notes 项『BGM volume re-apply timing』闭合**。
- 0x45B430 = BGM enable-flag clear，唯一 caller 0x441E29（load OFF 路径）；配对 0x45B410 enable callers {0x4416EC, 0x441E18}。
- 选项窗 init fn = ctor 0x440FE0（caller 0x42788D；config load 唯一调用点 0x4411ED→0x441CC0）；open = 0x4414F0（caller 0x42C10B）。
- ShadowBlend [0x47EF48] = 3 写入点零读取（config-only 死全局）。
- 落盘：`settings-ambience-bgm-volume-evidence.json` + matrix settings closed_2026_08_12（5 条）+ RESEARCH_LOG。

## Round 19 (2026-08-12) — map type 0x32 小地图标记业务名定案 = NPC 实体（Finding 325）

- **type 0x32 = NPC 实体（primary-static 定案，推翻 2026-08-10『teleport/block marker; NOT an NPC』候选）**：minimap 黄色 0xFFFF ±2px 外框标记绘制门 0x43DC65（list 0x560070 中仅 byte[+0x88]==0x32 实体，世界坐标 [+0xCC]/[+0xD0] 经 [0x476904]×[0x476658]+[0x2C0] 视口变换）；业务身份 = 完整 NPC（F269 element 128 NPC @0x405263 + NPC.wil @0x47C964；F323 vtable 0x47671C +0x7C = 0x40C020 头部条；spawn handler 0x407F20 名字 interning [+0x61C70] + 坐标 [+0xCC]/[+0xD0]；ctor 0x405862 类型参数写 [+0x88]）。
- **交互语义**：0x43CD0F minimap 命中测试 0x32 不可 pick（仅 0/1 死检 0x13、3 状态 4）；0x41ECAE find-xy 仅匹配 0/1；0x4123E3 picked target [0x7E335C] 为 0x32 → 步进/动作门返回 1（NPC 交互阻挡）。『挡路』= NPC 目标锁，非静态标记。
- **matrix map pending 项『type 0x32 marker business name』闭合**（closed_2026_08_12）；pending_notes 修剪为 runtime 两项（zoom-toggle runtime frame、key label strings absent）。
- 落盘：`map-type0x32-marker-npc-evidence.json` + map-ui-resource-evidence.json（SUPERSEDED 注记 + 新闭合并入）+ matrix map closed_2026_08_12 + RESEARCH_LOG Finding 325。

## Round 20 (2026-08-12) — 0x476600 家族 vtable 全活 + 13 渲染器死代码结论推翻（Finding 326）

- **CRT 静态初始化链（0x47A000–0x47A104，64 项 ctor 表）**：entry 0x46992D → 0x46998C `call 0x46C38B`（CRT startup）→ 0x4699C5 `call 0x468204`（init runner）→ 0x468228 `call 0x4682EC` = `_initterm(0x47A000, 0x47A104)`。全局对象 ctor 表为 **.data 立即数 dword 数组**（非 .rdata 指针表）——`push imm` 传参，E8 扫描与 raw-dword 扫描均不可见。
- **0x47A02C = 0x401960 thunk**：`call 0x401970; jmp 0x401980`；0x401970 = `mov ecx, 0x47EF18; jmp 0x418B00`（ctor thunk）；0x401980 = `push 0x401990; call 0x468467; pop ecx; ret`（**atexit 注册 dtor**）；0x401990 = `mov ecx, 0x47EF18; jmp 0x418D50`。→ **全局主 UI 对象 0x47EF18：ctor 0x418B00 / dtor 0x418D50，经 init 表 + atexit 活**——『0x418B00 无 E8 caller = 死』误判根因 = E8-only 扫描盲区（jmp-thunk 0x401975/0x401995 + init 表 dword 项）。
- **vtable 0x476670 安装 @[0x47EF18]**（0x418D1D，SEH ctor 0x418B00 内，handler 0x4748CC）→ slot +0xC = **0x47667C = 0x41E2B0 wndproc**（F309 事件总线）。槽表：+0x0=0x41E6A0/+0x4=0x41E6D0/+0x8=0x41E260/+0xC=0x41E2B0/+0x10=0x423A80/+0x14=0x423850/+0x18=0x4238F0/+0x1C=0x423990/+0x20=0x42E700/+0x24=0x423450。
- **wndproc → 窗口绘制分派全链（4 跳，全 call 点体内验证）**：0x41E2B0 → @0x41E53C `call 0x41DFE0` → @0x41E188 `call 0x428EF0` → @0x428F69 `call 0x429420` → @0x4295BB `call 0x4280F0`。**0x4280F0 = 窗口绘制分派，21 个 E8 直调目标**（0x42EB80/0x44B2D0/0x44E260/0x415B10/0x425040/0x4243D0/0x450530/0x414700/0x43F460/0x447470/0x441380/0x4269C0/0x439500/0x43E3C0/[0x476248 间接]/0x42AAB0/0x42FAB0/0x44B6B0/0x416790/0x450AC0/0x44E650）——**Round 20.5『13 渲染器 + 0x45DE50 = 死代码』SUPERSEDED**：13 名单中 7 个（0x42EB80/0x415B10/0x425040/0x450530/0x447470/0x44B2D0/0x44B6B0）在分派 E8 直调表内，0x437610 经 vtable 0x476528+0x10（写点 0x40E7DD/0x413656）活，0x40B850 经 vtable+0x84（F323）活；0x45DE50 早经 Round 20 核心链（E8 callers 0x40A280 等）验证。
- **34 个 vtable 家族基础地址全部有 C7 写点**（modrm-aware 全扫；0x476448=114、0x476624=32、0x476454=19、0x4763A8=9、0x4763BC=6、0x476620=6、0x4763C0=2、0x476360=3、0x476368=2、0x476378=4、0x476480=2、0x476528=2、0x476544=2、0x4765F0=1、0x47660C=2、0x476638=4、0x47663C=2、0x476654=2、0x47665C=2、0x476670=2、0x476680/0x47669C/0x4766B8/0x4766F0 各 4、0x4766D4=2、0x47671C=1、0x4767A8=4、0x4767C0/0x4767C4/0x4767C8=5、0x4767CC/0x4767E0/0x4767FC=5）——**无死 vtable 表**。
- **0x4570A0（fn start；0x457092–0x45709F = 14 NOP 填充）**：`call 0x457040; mov [0x8AB820],0x47EF18; mov [0x8B1870],0x47EF18; call 0x419350; mov [0x8B1878],3`；0x419350 → 0x45D270（创建 0x8AB7A8 800×600 主对象，深 0x10，模式 5/1 依 [0x47EE89]）；E8 caller @0x457753。
- **判定标准（正式确立）**：全局对象 ctor/dtor 靠 CRT init 表 + atexit 注册（非 E8）；vtable 槽函数靠 [reg+off] 间接调用（非 E8）；**『无 E8 caller / 无 dword ref ≠ 死代码』**。E9 jmp-thunk 扫描为 E8-only 盲区补全（本轮命中 0x401975/0x401995/0x401955）。
- 落盘：`renderer-family-liveness-evidence.json` + matrix hud closed_2026_08_12（新条目）+ RESEARCH_LOG Finding 326。

## Round 21 (2026-08-12) — 0x4280F0 分派 21 目标身份全表：id13 坐骑 / id14 技能书定案（Finding 327）

- **窗口分派身份全表闭合（primary-static）**：0x4280F0 的 14 个 paint E8 + 1 IntersectRect 间接 + 1 hit-test 0x42AAB0 + 5 个 hover E8 全部绑定业务身份——id0 背包 F250、id1 状态 F200、id2 商店 F1000、id3 交易 F1050、id4 行会 F600、id6 组队 F900、id7 组长弹窗 F200、id8 聊天 F350、id9 NPC F1100、id11 任务 F700、id12 选项 F750、**id13 坐骑 F850（paint 0x4269C0、ctor 0x4268C0 @main_init 0x4278D9、winbase 0x52118、hitrect 0x52130）**、**id14 技能书 F400（paint 0x439500、wrapper 0x439250 @main_init 0x427904、winbase 0x524F0、hitrect 0x52508）**、id15 公告 F602（paint 0x43E3C0、wrapper 0x43E260）；id5/10 未注册走默认槽。id13/id14 经 dispatch 槽 + main_init ctor 参数（id/frame）双证。
- **hit-test 0x42AAB0（USER32!PtInRect @[0x4762B4]，rect = win+0x18）** 覆盖 ids 0–4,6–9,11–14；**id13/id14 为真实可交互窗口**（id15 公告无 hit 槽）。hover 仅 id0/1/2/3/7（0x42FAB0/0x44B6B0/0x44E650/0x416790/0x450AC0），其余走默认 0x42833E。
- **底部输入条带交叠隐藏**：IntersectRect（常量带 {223,570,577,586}）命中且非 id8 聊天 → `ShowWindow([0x8AA48C],0)` 隐藏**聊天输入 EDIT 控件**（0x8AA48C 非主游戏窗口；主 HWND = 0x8AB7B0）。语义：非聊天窗口覆盖输入条带时禁用聊天输入。
- **记录修正**：window-traversal-evidence id14 paint 0x43E3C0 → 0x439500（+补 id15 行）；chat 文档『map hwnd』→『chat input edit hwnd』（5 处）；layout 记录 `window.other-14-candidate` → `window.skill-book`（26 文件同步，version 0.6-window-paint-dispatch-identity）。
- 落盘：`window-paint-dispatch-identity.json`（F327）+ matrix skills/horse closed_2026_08_12 + RESEARCH_LOG Round 21。

## Round 22 (2026-08-12) — 主对象 vtable 家族定案（Finding 328）

- **0x476670 = 4 槽**（非 10 槽）：+0x0 0x41E6A0 状态行格式化→0x8AB828（fmt '**%s/%s/%d/%d/1' @0x47C808）、+0x4 0x41E6D0 消息解析（memchr 0x468B30 + 0x41ED20）、+0x8 0x41E260 [this+0x34] 门控 750ms 延时（timeGetTime 基）、+0xC 0x41E2B0 wndproc（F309）。写点仅 ctor 0x418D1D / dtor 0x418D6D。
- **+0x10..+0x24 → vtable 0x476680 = 独立 7 槽链表类**（成员 main+0xE11CC）：dtor 0x423A80 / AddTail 0x423850+0x4238F0 / insertAfter 0x423990 / ForEach 0x42E700+0x4048B0 / unlink 0x423450。家族 6 成员 main+0xE1154..+0xE11CC，vtable 28 字节间隔 + 独立 dtor 链（0x423A00..0x423A80 装回各自基址）。
- **节点类 0x476454**：12 字节 {vtable, data, prev, next}；dtor 0x413D80/0x40EA60、渲染 0x435030、no-op 0x403AC0、位置 0x4378E0/0x437DF0/0x435A20。
- **312 站点无一经 0x476670**（4 槽方法全经 18 个 `mov ecx,0x47EF18; call 0x41..` 直接调用）。
- **可见性分派修正**：节点 {+0=id, +4=next, +8=prev}（0x42AC50 found-path 逐字节核对）；remove-by-id free = 直调 0x4680F8 @0x42AD93；hide-all 0x42B820 跳表 0x42B938 经 0x423F90 清 [win+0x34]。
- 落盘：`main-object-vtable-family-evidence.json`（F328）+ matrix main-object-vtable-family 新条目 + window-visibility-dispatch closed_2026_08_12 + layout.json version 0.7 + RESEARCH_LOG Round 22。

## Round 23 (2026-08-12) — 场景实体链表 + 键盘热键 + 坐骑窗口族（Finding 329）

- **场景实体链表 0x560070 定案**：= 主对象列表成员 #1（base main+0xE1154 / vtable 0x4766F0 / head main+0xE1158=0x560070 / count 0x560080）；六成员 stride 0x18（0x56006C..0x5600E4，vtable 0x4766F0/0x4766D4/0x4766B8/0x4766D4/0x47669C/0x476680）；节点 {+0 vtable,+4 data,+8 prev,+0xC next}；实体 {+0 vtable,+4/+8 名字,+0x88 state,+0xC0 type,+0xCC x,+0xD0 y,+0x61C74 flag}。AddTail 写点 0x42278F（spawn 0x422580：type 0x32 → new 0x629C8 → vtable 0x47671C @0x42264E）；unlink 站点 ×12（slot+0x14）。0x41EC10 = 8 方向相邻地块实体查找（跳表 0x41ECFC）。
- **键盘热键 0x42CBD0 全解码**：'C' → 0x41EC10（[0x777759]/[0x777768]/[0x777764]/delta=1）→ 实体名 → 状态行 0x8AB828（0x451A70）；'D' horse id13 / 'Z' 亮度 / 'V' 节流 / 'B' [ebp+0x6208] / 'G' party / 'F' 清状态行 / 'N' options / 'T' [ebp+0x64A8]。TAB 0x42CFBE = winmgr 循环（id9 → 0x41C1E0 NPC 关闭）。
- **坐骑窗口族**：0x423B30 基类 ctor（无 vtable）；0x4268C0 坐骑 ctor（+ 5× 0x417550 子控件工厂 +0x54..+0x324 stride 0xB4）；0x423CF0 = `jmp [eax+4]` 虚拟 thunk（slot+0x14 AddTail 别名）；0x423D00 = 家族 slot +0x18 显示/定位；paint 0x4269C0 = E8 分派槽 13（F327 归属最终化）。
- **0x560070/0x777xxx 直接写者负结果**：全编码穷举无果 → 寄存器相对 disp32 间接写 + ctor/rep-stosd 初始化；BSS 写者搜索继续非阻塞。
- 落盘：`scene-entity-list-and-hotkey-evidence.json`（F329）+ matrix scene-entities/horse/target-box closed_2026_08_12 + RESEARCH_LOG Round 23。

## Round 24 (2026-08-12) — 六成员嵌入列表对象 + 0x421xxx 包处理函数入口 + 0x417550 图片控件（Finding 330）

- **六成员嵌入列表对象定案（primary-static）**：地址算术 main(0x47EF18)+0xE1154..+0xE11CC = 0x56006C..0x5600E4 六个 stride-0x18 列表对象（vtable 0x4766F0/0x4766D4/0x4766B8/0x4766D4/0x47669C/0x476680），+0xE11E4 = 实体数组 0x5600FC（stride 0x144）。列表 {+0 vtable,+4 head,+8 tail,+0xC callback,+0x10 callback-arg,+0x14 count}；节点 {+0 vtable,+4 data,+8 prev,+0xC next}（0x42E700 ForEach 证明 callback 字段）。『BSS 零直接写者』= 嵌入字段相对寻址别名（寄存器相对 disp32 + 内联绝对地址站点），ctor 0x418B00–0x418BEE + rep stosd 清零。
- **per-member AddTail 节点 vtable 终表**：m1 0x4230E0→0x4767C0、m2/m4 0x4232A0→0x476448、m3 0x4234D0→0x4767C4、m5 0x423690→0x4767C8、m6 0x423850→0x476454（与内联站点一致）。m3 = 计时事件表（find 0x41EB40 / 5s sweeper 0x41EB70 / AddTail 0x421C50）；m4/m6 = 实体类列表（内联 AddTail @0x421345/@0x421444，字段 0x5600B8.. / 0x5600E8..）；m5 = 数据列表（删除 case 0x41F533）；0x41EBD0 = m6 三键查找（修正旧『sweeper』表述）。
- **0x421xxx 包处理函数入口 0x41ED33 + 分派级联（primary-static）**：SEH 序言 + 0x468D10 帧分配 + esi=[esp+0x3F28] 包字符串（唯一 caller 0x41E6FA）；`+` 前缀 → 0x41E740；否则 0x452920 解析消息码 → [esp+0x10] → 级联（>0x29E/==0x29E/0x26E..0x29D/==0x26D/>0xC9/==0xC9/6..0xC8）+ 0x41F264 再分链（>0x263/==0x263/>0xD4）+ 附加跳表 0x42210C/0x42211C/0x422130/0x422140/0x422158/0x422168；公共出口 0x421D3F。type 4/5 实体生成（0x438100 第 7 参 = entity type 0x10/0x16）、m5 删除、chat '/' 命令（strchr 0x468BF0）、0x420C1E timeGetTime → [ebx+0x2AB69C] + 0x43D780。
- **0x417550 = 静态图片控件 ctor（9 参 ret 0x24）+ 0x466130 帧选择器**：0x417550 字段全图（+0x14 图像对象/+0x18/+0x1C/+0x28 帧 id/+0x2C/+0x24 byte/+0x34 名字）；帧验证 0x466130 → SetRect 0x4762B0（w=word[frame]/h=word[frame+2]）；0x466130 按 [obj+4] mode 分派：mode 0 → 0x466640 WIL 惰性载入（帧表 stride 0x20 + GetTickCount 15s 缓存过期 + SetFilePointer/ReadFile），mode 1/2 → 0x466720 内存精灵（索引表 [obj+0x30]/count [obj+0x2C]/base [obj+0x34]/帧 [obj+0x38]/像素 [obj+0x3C]）。
- **坐骑窗 5 控件帧对终表**：0x4268C0 内 5× 0x417550 @+0x54/+0x108/+0x1BC/+0x270/+0x324（stride 0xB4），帧对 (0xA1,0xA2)/(0x35C,0x35D)/(0x35E,0x35F)/(0x360,0x361)/(0x362,0x363)；A3 = 坐骑资源字段 edi+0xFC/+0x1C/+0x4A/+0x85/+0xC0、A4 = ebp+0xF4、A5=0/A6=1/A7=-1/A8=0。**负闭合**：坐骑窗无 vtable 写点。
- **IAT 补名**：0x47611C=KERNEL32!GetTickCount、0x4761EC=KERNEL32!SetFilePointer、0x4760C8=KERNEL32!lstrcpyA（+KERNEL32 块 0x4760A0–0x476174 全名）；0x4680F8 = delete wrapper → 0x468D3F（null 检查 + 0x46C405 + 释放）。
- 落盘：`six-member-lists-and-packet-handler-evidence.json`（F330）+ matrix horse closed_2026_08_12（5 控件注记）+ layout.json version 0.7 → 0.8 + RESEARCH_LOG Round 24。

## Round 25 (2026-08-12) — 消息环系统 + 中央消息泵 0x40A2B0 + 实体 Init/ctor-factory + 0x423D00 收敛（Finding 331）

- **消息环系统定案（primary-static）**：**0x4561B0 = 加锁消息环 PUSH、0x456270 = 配对 POP**（F330『实体 +0xF0 子对象方法』假说 REFUTED）——环对象 {+0 count, +4 read, +8 write, +0xC elements[100000×4 = 0x61A80], +0x61A8C critsec[0x18]}，总 0x61AA4；IAT 0x47610C/0x476110（Enter/LeaveCriticalSection）。消息 = 0x40C 字节（0x103 dwords），type word @+4，string @+0xC；克隆点 0x40A404（new 0x468B1A + rep movsd 0x103 + type=0x1F + 重入队）。**三环实例**：pump 对象 this+0xF0（vtable 0x4763C8）/ main+0x364458（包处理出口 0x421D3A 推入）/ main+0x3C5EFC（0x422280 泵出）。
- **0x40A2B0 = 中央消息泵**（vtable 0x4763C8 slot 4，引用 0x4763D8）：pop → word[+4] type 分派——9..0x17 经映射 0x40A4BC（`00 01 02 08 08 03 …`）+ 跳表 0x40A498 → [this]vtable slots +0x44..+0x6C（0x407200/0x407670/0x407DF0/0x407EC0/0x407F20/0x408060/0x409720/0x408C20/0x408630/0x406A70/0x406AB0）；0x1B→slot+0x58、0x1F→slot+0x60、0x20→slot+0x54、0x51C/0x320/0x321/0x323/0x324/0x326/0x327 专用路径。**0x422280**（main+0x3C5EFC 环）：0x1E/0x1D/0x323 → 遍历 m1 head main+0xE1158 比较 `[node+4]+4 == [msg+0]` → call 0x41B570；0x279 → 0x422403。**0x4227F0**（main+0x364458 环）：0x32→0x422CC0、0x34→0x423000、0x2F0→0x423070（0x33/0x27A 跳过）。**0x40A209** = 方向/航向环排水（word[+4]==0x1F → float 数学 → [edi+0x61BCC]=word[+6]、[edi+0x61BCA]=word[+8]）。
- **实体 Init 0x404FB0 分派器**（0x4763C8 slot 1 / 0x47671C slot 3 共享）：gate 字节 <8 且 data[0] ≤0x32；映射 0x405500（`00 01 04 02 04 04…`：0→idx0、1→idx1、2→idx4 default、3→idx2、0x32→idx3）→ 跳表 0x4054EC = [0x404FE5 'G'、0x405003 'L'、0x40507C、0x4051BB、0x4054DE default]；'G'/'L' case：layer<9、x≤33 校验，写 [ebp+0x8C]=0x47/'L'；tile 表 0x8AA5C0（stride 6）→ +0xB4/+0xB8。
- **实体 ctor/factory 链**：0x435020（装 0x476884）→ 0x435030（8 参基类 ctor，ret 0x20）→ **0x434EF0 全量 ctor**（0x476884、+4=2、+0x118/+0x11C=0x2710、+0xF0 区清零、+0x130=5；~100 E8 callers）→ 生成点覆写终 vtable **0x4767A8**（0x420EE8/0x421029/0x4212EA/0x437A0E）/ **0x47671C**（0x42264E spawn）；**0x438100 = 工厂**（8 参 → 0x435030 + 0x43CFD0(0x574118)；callers 0x420F2D/0x42106F/0x42132D/0x437A3F）。**0x476884 = 中间 vtable，0x4767A8 = 最终实体 vtable**。
- **窗口类 ctor 0x4241D0 + vtable 0x476624**（primary-static）：SEH ctor → 0x4767CC → 0x4268B0 → **0x468306([esi+0x6C], 0xB4, 5, 0x4046B0)** = 控件数组构造 helper（5 控件 @+0x6C/+0x120/+0x1D4/+0x288/+0x33C）→ +0x54 嵌入 vtable 0x4767E0 → 终 vtable 0x476624 = [0x4150D0, 0x423CA0, 0x423CF0, **0x423D00**, 0x423F80, 0x4155A0, 0x415710, 0x415820]；0x4245A0（slot+0x10）= 销毁 +0x58 内嵌链表 + 清零至 +0x3F0 → 窗口对象 ≥0x3F4 字节。
- **0x423D00 矛盾收敛（F330 pending 关闭）**：m1 16 字节节点 = 基类实例只分派 dtor 槽 0；0x423D00（render，读 +0x28/+0x2C/+0x30/+0x50 → 0x466130 帧验证）只被全尺寸窗口/实体分派（0x476624 slot+0xC、0x4767C0 家族 slot+0x18）；m1 遍历 0x41EB10 从不分派槽 3-7 → **非真矛盾**。
- **vtable 阶梯权威化**：0x4767A8 = 实体类基 8 槽；0x4767C0（m1 节点）/0x4767C4（m3）/0x4767C8（m5）/0x4767CC 家族 8 槽 raw dump（0x423AA0 dtor 链 0x423AA0→0x4767C0、0x423AC0→0x4767C8、0x423AE0→0x4767C4）；**0x4763C8 = 实体家族派生类消息泵 vtable（20 槽）**，与 0x47671C 共享槽 0..3 与 8..0xB。
- 落盘：`node-vtable-family-and-message-queue-evidence.json`（F331）+ matrix message-queue 新条目 closed_2026_08_12 + layout.json version 0.8 → 0.9 + RESEARCH_LOG Round 25。

## Round 26 (2026-08-12) — 三消息环排水全链 + 世界生命周期 + 字段消费者扫描（Finding 332）

- **双主环排水器分派定案**：0x4227F0（ring A main+0x364458，caller 0x41BBCA）——0x33/0x27A→0x422960 文本消息（门控 0x2F8840/环空间记账，busy 或 1500ms 定时器重推；处理 = 0x42E1F0(&0x2A548C,&0x2F8788) + 0x45B1D0/0x45B3D0(&0x8AB130) + 12 记账槽清零 + [0x428220]=1.0f）；0x32→0x422CC0 世界重置；0x34→0x423000 目标信息；0x2F0→0x423070 状态块；0x1F→500ms 节流后 0x40A1E0(&2F8780)+PUSH ring C 或存 pending 槽；id≠current-id → m1 命中 → 0x40A1E0(node)+PUSH 实体 +0xF0；未命中 → 0x422580 spawn 回退。0x422280（ring B main+0x3C5EFC，caller 0x41BBC3）——0x1E/0x1D/0x323→实体移除（0x41B570 + 清 0x364444–0x364450 + 排水实体环 + 跳表 0x42253C/字节表 0x422548）；0x279→0x422403 世界清空；其他 free。**0x279 在 ring B（0x4222CC），0x32 在 ring A——两环职责不同**。
- **世界清空 0x422403 全链**：0x4195C0（0xE11A0 全删，类型判断两分支同为 vtable[0](1) 删除）+ 0x419570（0xE1170）+ 0xE11D0/0xE11B8 + 0x419650（m1 全刷：0x41B570 + 排水实体环 + 删；callers 0x4191F2/0x4224C4）+ 0xE1188 + 清零 0xE118C/0xE1198/0x364444–0x364450。
- **0x422CC0 世界重置（type 0x32）**：current-id=msg[0]、拷贝 16B+5B、管理器 vtable+0x8C 7 参 UpdatePlayerState（&0xE11E4 实体数组, flag, byte[+0xA], word6, word8, &16B, &5B）、清 0x7776A0（strlen 0x47EEE4=0）、wipe 0xE1188、0x417FB0 清子对象、[0x35B2B8]=1、0x451660(0x51) 状态行。**0x423000**：目标 id/byte/0x61 块 + 航向快照。**0x423070**：状态块 0x35B251–0x35B258。
- **0x40A1E0 通用对象环排水（ring C + 实体环；callers 0x4228D9/0x422922）**：type 0x1F 航向数学 angle/factor × 100.0（**0x47644C=100.0、0x476450=0.0 已确认**）→ ftol → [this+0x61BC8] 朝向字节，[+0x61BCC]=angle、[+0x61BCA]=factor、[+0x629C6]++；非 0x1F 重推。**F331「ring C 排水方」关闭 = 0x40A1E0**；0x41A5A0/0x41A9B0 仅读计数触发 flush（0x410840 + vtable+0x18）。
- **0x422580 spawn 三路径 + 成功链**（type 表 {0xA,0xD,0xB,9,0x20,0x21,0x14,0x1B,0x321,0x327}；0/1→0x40C560、0x32→0x404960+vtable 0x47671C、其他→0x404960；成功：vtable+0xC 5 参入列 + AddTail m1 + PUSH 实体环 + 0x61C58=0x12C）。
- **0x41B570 = 回指清理**（m2/m4 节点 +0x14/+0x18 指针清零）。**帧序列 0x41BBBA**：0x41B440→0x422280→0x4227F0→0x465EA0→0x454C50，busy→0x43B1E0 flush + 0x35B2C0 send。
- **字段消费者扫描**：0x35B1E8 目标 id 11 引用、0x35B2B8 busy 18 引用（帧 0x41BBE1 → 0x43B1E0）；**write-only 状态槽判定**：0x35B251–0x35B258、0x35B1F0（2 写点）、0x35A34A/0x35A34C/0x35A34E 零 .text 读者（mod10+绝对寻址双验证）→ presentation-layer 契约字段（sim HUD 消费）。
- 落盘：`message-rings-drain-pipeline-and-world-lifecycle-evidence.json`（F332）+ matrix message-queue 注记扩展 + layout.json version 0.10 + RESEARCH_LOG Round 26。

## Round 27 (2026-08-12) — 地图切换/加载管线 + 主窗口类分派（Finding 333，F332 三处错标修正）

- **〔修正①〕0x42E1F0 = 英雄对象存盘 SaveToFile（非聊天显示）**：字节事实 = CreateFileA(0x4760DC, WRITE 0x40000000/share2/CREATE_ALWAYS=2/attrs0x80) + 3× WriteFile(0x4760C4) + CloseHandle(0x4760E4)，无任何 GDI/文本绘制调用。签名 (ecx=this=0x2A548C, arg=&0x2F8788 文件名)；0x45DC70 拼 `.\Data\<名>.itm`（0x47BDC4 `.\Data\` / 0x47BDCC `.itm`）；3 块 = +0x6CC8(0x22FE8) / +0x6818(0x4B0) / +0xDA4(0x48D8)。callers = 0x41CE48、0x41CEFD（type 0x64 族：0x451660(0x3F1) → 存盘 → [0x428208]=0/[0x428204]=2 → 0x42D680）、0x4229DF。
- **〔修正②〕0x422960 = 地图切换/加载 handler（type 0x33/0x27A，非文本消息）**：入口 [0x35B2B8]=0；门控 = (mode[0x2F8840]==3 且 [0x35A31C]-[0x35A320] ≥ [0x35A329]-1) 或 timer[0x4279A4]≠0 → busy 路径 0x4229A8（0x4561B0 重推 ring A + busy=1）。处理路径 0x4229D1 全链 = 英雄存盘 0x42E1F0 → 窗口管理器 flush 0x45B1D0/0x45B3D0(&0x8AB130) → [0x4279A4]=0x5DC(1500ms 限流) → 12 槽清零 → [0x428220]=1.0f → 坐标 word[msg+6]/word[msg+8] → 0x35B25C/0x35B260 & 0x2F884C/0x2F8850 → 0x410100(&0x2F8780,&0xF5200) 地图对象指针槽 [管理器+0x62A58] → 管理器 vtable+0x10 → 0x452810 拷地图名（cap 0x400）→ 0x43C9C0 SetPos(x-12,y-12) → 0x43B600 LoadMap → rep stosd 0x38400 清实体数组 main+0x154 → 0x4680F8 释放 0xE11D0 链表 → 地图类型 byte[msg+0xA]（[0x47624C]([0x8AB7B0],1) 变更提示）→ 环境色 0x434610 → 0x41C1E0/0x451770/0x4195C0/0x419570 刷新。
- **〔修正③〕0xF5200 = 当前地图对象**（main+0xF5200 = 0x574118）：+0 loaded / +4 文件名 / +0x108 瓦片索引 w*h*3/4（byte 属性+word id）/ +0x10C 瓦片数据 w*h*14 / +0x110 头 0x1C / +0x124 帧行选择 / +0x126/+0x128 宽高 / +0x12C/+0x130 位置 / +0x14C..0x158 视口矩形 / +0x18C 小地图标志 / +0x1B2 渲染缓冲 0x1B0000 B（768×576×4）。
- **0x43B600 = .map 载入器**（fmt 0x47C404 `.\Map\%s.map`）：CreateFileA(READ 0x80000000/share1/OPEN_EXISTING=3) + 0x43B820 init + ReadFile 0x1C 头→+0x110 + alloc w*h*3/4→+0x108 + alloc w*h*14→+0x10C + [+0]=1 + w<0x64&&h<0x64→[+0x18C]=0 + 56 瓦片槽 0x5612B4..0x565994（stride 0x144）0x465FE0 + 14 帧 0x4660E0(&0x5600FC+i*0x144, &0x56B22C+i*0x104, 1)（失败重 init）+ [+0x18C]→0x43B440 渲染 + CloseHandle 返 1。
- **0x43B440 = 24×24 瓦片视口渲染**：清 +0x1B2 0x6C000 dwords；y=[+0x12C]..+0x18、x=[+0x130]..+0x18；奇偶半瓦片过滤；idx=(y>>1)*w+(x>>1)；行=attr/7（0x6DB6DB6D 魔数）；0x466130(&0x5600FC+行*0x144, id) 载帧 → 0x45E8E0(&0x8AB7A8 blitter, w,h,surface,0x480,0x300,xoff<<5,yoff*0x30,0xFFFF,0xFFFF)。
- **0x43B1E0 = 地图视口滚动重绘**（F332「flush 进聊天对象」错标修正）：[+0x14C..0x158] 视口矩形 vs 玩家坐标 ±0xC 越界 → [0x4762B0] 滚动 + 同款瓦片 blit；帧序列 0x41BBE1 busy → 0x43B1E0 = 视口跟随玩家。
- **0x8AB130 = 主体窗口管理器**（F332 仅作缓冲对象 → 修正）：+0x460 起 50 子窗指针槽（0x45B1D0 逐 0x45B950 释放）；0x45B3D0 → 0x45A510 深层释放（+0x134/+0x13C/+0x130 + [+0x11C] vtable+0x20）；0x45B440 = 通用分派（wndproc 默认分支）。地图切换全关窗。
- **0x2A548C = 英雄对象**（0x7243A4）：热键 0x42CBD0（KEYDOWN 0x41DD84 确认 this）/ 消息分发 0x42D680（跳表 0x42D700）/ 0x42DC20 / 存盘 0x42E1F0 / busy 定时 0x42C9E0。0x2F8788（0x7776A0）= 地图名/存盘名缓冲（refs 0x41CE3D/0x41CEF2/0x41F24F/0x4229D3）。
- **主窗口类 vtable 0x476670 终态**：+0x0 0x41E6A0 HUD 状态行（0x4514F0 四统计量 0x47EEF8/0x47EEE4/[0x47EF10]/[0x47EEB8]）；+0x4 0x41E6D0 聊天指令解析（memchr '!'/'#' → 0x41ED20）；+0x8 0x41E260 [this+0x34] 门控 750ms（0x465DD0）；+0xC 0x41E2B0 wndproc 分派表：2/3→0x41CEF0（0x41D2B0 窗态保存 0x8AB7F0..0x8AB7FC）；0x100→0x41DD30（模态 0x362370 → 热键表 0x418470(&0x3615B0) → busy → 0x42CBD0 → 环头 0x364444）；0x104→0x41D090（Enter busy=0+0x45D270 恢复屏幕）；0x105→0x41D2A0 空；0x202→0x41DB80；默认→0x45B440(&0x8AB130)+0x465E80。
- **0x418030 = 公告窗构造**（0x466130(父,0x3B6) 背景帧 + 居中 + 3× 0x417550 子控件 0x97/0x98、0x9D/0x9E、0x9A/0x9B + 模式 0/1/2 → [+0x234]/[+0x2EC]/[+0x3A4]/byte[+0x462]）；**0x468D10 = alloca 栈分配**（0x1000 页探测）。
- **F330 标注细化**：main+0x154 0xE1000 B = 实体数组（地图切换清零）；0x5600FC = 瓦片对象槽双重角色（行号索引 0x144 + 帧装载目标）；0xE11D0 = 实体链表头（切换释放）。
- 落盘：`map-change-pipeline-and-main-window-class-evidence.json`（F333）+ matrix map/chat/main-object-vtable-family/message-queue closed_2026_08_12 注记 + layout.json version 0.11 + RESEARCH_LOG Round 27。

## Round 28 (2026-08-12) — 0x8AB130 声音管理器家族 + DirectShow BGM 播放器（Finding 334，F333 定性重大修正）

- **〔核心修正〕0x8AB130 = 声音管理器 SoundManager（非窗口管理器）**：+0x460..0x528 = 50 效果音 IDirectSoundBuffer 频道槽（槽 {+0 DSound 封装、+4 WAV、+8 缓冲数、+0x10/+0x14+4i IDirectSoundBuffer[]、+0x38 最近使用、+0x3C 频道 ID}）；+0x528 = 内嵌 DirectShow BGM 播放器 SoundPlayer（vtable 0x476BD4）；+0x420/+0x452/+0x45C config1（SoundList.wwl 效果音表）、+0x52C..+0x56C config2（Bgmlist.wwl BGM 表）；+0x20 = BGMLevel 音量（=0x8AB150）。证据：'SOUND\'+config 名 → 0x45B6D0 建缓冲组；IDirectSoundBuffer vtable 11 偏移全吻合；DSBVOLUME_MIN=-10000 钳制；'none'/'nobgm' 哨兵。69 imm32 引用 + 36 寄存器调用点全景。
- **BGM 播放器 = DirectShow FilterGraph**：0x45A2F0 CoCreateInstance(CLSID_FilterGraph e436ebb3) + 五 QI（IGraphBuilder 56A868A9 / IMediaControl 56A868B1 / IBasicAudio 56A868B3 / IMediaPosition 56A868B2 / IMediaEventEx 56A868C0 / IMediaSeeking 36B73880，GUID 全 web 验证）；RenderFile = IGraphBuilder vtable+0x34（继承 IFilterGraph 偏移后移）。**事件链闭环**：播放完成 → 0x81F4 消息 → 主图形窗 [0x8AB7B0] → wndproc 默认 0x41E312 → 0x45B440（msg==0x81F4 分派）→ [0x528] → 0x45A5A0 事件泵：EC_COMPLETE(1) 且 [player+8] 循环标志非 0 → 0x45A7C0 Pause+IMediaPosition 0.0 复位+Run 重播；0x14 → 0x45A510 停止；其余 FreeEventParams 排空。
- **0x8AB7B0 = 主图形窗口 hwnd**（[0x8AB7A8+8]，类 'MirDXG' 0x47B004 / 标题 'Legend Of Mir 3' 0x47A468）：0x45CA80 失败路径 MessageBoxA(hwnd=[0x8AB7B0], '[CWHDXGraphicWindow::Create]Window create failed.', 'MirDXG', 0x10) 决定性证明；DSound SetCooperativeLevel（0x45A8C0）+ BGM SetNotifyWindow 双用。**0x8AA48C = 主应用窗 hwnd**（0x451100 CreateWindowExA 家族 + SendMessageA/UpdateWindow；0x401FF9 ShowWindow([0x8AA48C], 0=SW_HIDE)）。
- **0x45A4A0 参数序（定稿）**：arg1=音量（调用点 0x45B36D 传 [0x8AB130+0x20]）→ 0x45A700 = IBasicAudio put_Volume(+0x1C, arg×40)；arg2=循环标志 → [player+8]（0x45A5A0 EC_COMPLETE 时非 0 才重播）。
- **IAT 终验（pefile）**：0x4762AC=ShowWindow（旧注 SetWindowTextA 修正）、0x4760C4=ReadFile（旧注修正）、0x47628C=MessageBoxA、0x476290=SendMessageA、0x476258=UpdateWindow、0x47634C=CoCreateInstance、0x476350=CoUninitialize、0x476354=CoInitialize、0x4760F0=MultiByteToWideChar。
- **init 序列（证据定稿）**：0x401FAD 0x45CA80(&0x8AB7A8) 图形窗 → 0x401FEC 0x451100(&0x8AA488) 主窗 → 0x401FF9 ShowWindow(0) → 0x402005 0x45A8C0([0x8AB7B0]) DSound init（失败 [0x8AB138]=0）→ [0x8AB138]=1 → config1/config2 装载（0x45ADA0/0x45AE90）→ 0x449C80(&0x8AA5A8)。
- 落盘：`sound-manager-0x8ab130-family-evidence.json`（F334，primary-bytes）+ matrix sound-manager 新记录 + layout.json version 0.12（sound-manager.0x8ab130 更名补全 + main-window-hwnd.0x8ab7b0 新增）+ RESEARCH_LOG Round 28。

## Round 29 (2026-08-12) — 主初始化窗口创建目录（Finding 335：hero HUD builder 0x427600 + frame fns 0x419350/0x419110 + 15 子窗口 id→ctor→偏移全表）

- **〔核心〕主初始化窗口创建分派器 = 0x419350**（唯一 caller 0x4570B9 游戏启动路径，ecx=main 0x47EF18；结尾 [0x8B1878]=3）：屏幕帧 0x10@800×600（0x45D270(&0x8AB7A8, flag, 0x320, 0x258, 0x10)）→ 0x451320(&0x8AB828, hwnd, 0x47EEC0) → 0x452AA0(&+0xE11E4) → **0x418030 公告窗**（'正在连接《骷髅射手3.0》服务器' 0x47AEB8，frame 0x3B6=950，x/y=-1 居中）→ **CreateSolidBrush(0x323232) → [main+0x2F877C]**（0x476064）→ fog 0x434500(&+0x35B2C0, 0xFFFFFF) → **0x427600 英雄 HUD 创建器** → 列表方法 vtable 调用（500/400 + 800.0f/600.0f）→ 缓冲区清零（rep stosd 0x38400 + 0x41）→ SetWindowTextA/SendMessageA(0xCC) 主窗 → 0x45E4E0(&0x8AB7A8, 0x141414)。
- **〔核心〕0x427600 = 英雄对象 (main+0x2A548C) 的 HUD/UI 窗口创建器**（唯一 caller 0x419405，arg1=[main+0xE11E4]，ret 4）：父窗 = arg1+0x5898 = main+0xE6A7C → [esi+0x1C]；MoveWindow 主窗（0x4762BC）；**frame 0x32=50 装载**（0x466130）；SetRect 族（+0xC58 视口 / +0xCF8 / +0xCA8 16 行网格 224,492 起 16px 行高 / +0xC58..+0xC98）。
- **15 子窗口全表**：id0 0x42EA80 +0x6554 f250 (518,0) 284×324；id1 0x44B130 +0x29CE4 f200 (0,0) 244×328 状态(本级)；id2 0x44D310 +0x33188 f1000 (0,0) 300×304 货币('(%d两)'，flag=0 隐藏)；id3 0x4159D0 +0x3399C f1050 484×330 装备('%d')；id4 0x424E60 +0x4707C f600 (102,22) 596×446 背包/仓库(5 字段 scanf)；id6 0x424250 +0x47834 f900 (272,123) 256×244 组队([允许]/[拒绝]/成员编辑)；id7 0x4503B0 +0x47C28 f200 (560,0) 244×328 右侧面板(本级+%s %s)；id8 0x414060 +0x507EC f350 (114,76) 572×388 聊天(9 控件 stride 0xB4，8 命令帮助串全解)；id9 0x43ED00 +0x51150 f1100 552×176 NPC 对话(NPCFace.WIL)；id0xB 0x4473E0 +0x516E8 f700 340×440 候选；id0xC 0x440FE0 +0x518E0 f750 (276,113) 248×264 选项（F324 确认）；id0xD 0x4268C0 +0x52118 f850 296×332 坐骑(@上马/@收马/@遛马)；id0xE 0x439250 +0x524F0 f400 (348,0) 452×380 属性详情(火冰电风神圣黑暗幻影剑)；id0xF 0x43E260 +0x52E5C f602 (107,110) 584×252 行会公告(EDIT，= id15 通知窗)；id0x64 0x418910 +0x53030 f800 (218,176) 364×184 居中公告弹窗。id 5/0xA 未用。
- **16 HUD 标题字符串定稿**（ctor 0x417550，hero+0x567C..+0x6108，x 相对 [0xC58]，帧对 normal/state 0x50..0x73）：交易栏(Ctrl+C)/小地图(Ctrl+V)/技能图鉴(Ctrl+B)/退出游戏(Alt+Q)/注销人物(Alt+X)/组队(Ctrl+G)/行会(Ctrl+F)/腰带(Ctrl+Z 0x9F/0x9F)/技能书(Ctrl+E)/聊天记录(Ctrl+R)/信息窗口(Ctrl+D)/设置栏(Ctrl+N)/帮助窗口(도움말창(지원예정) EUC-KR 韩版遗留，非乱码)/坐骑(Ctrl+S)/包袱栏(Ctrl+Q)/状态栏(Ctrl+W)。字符串区域 0x47BCxx cap0-12 / 0x47BBxx cap13-15。
- **窗口工厂模式**：15 ctor 共享 8 参重载 → 基 ctor **0x423B30**（+4 frame-type/+0x28/+0x2C/+0x3C）→ 0x466130 帧装载（0x466640/0x466720 分派）→ 0x417550 子控件 → [0x4762B0] SetRect。0x417960 = toast ctor（7 参 ret 0x1C，timeGetTime 时间戳）。
- **小地图窗** hero+0x6214（0x43D4D0 @ 0x427E01，arg=[0x8AB7BC]）：+4/+0x148 双子对象装载 MMap.wil / FMMap.wil。
- **frame fn 0x419110 = 每帧更新分派器**（callers 0x418D7B + 0x419BEA）：KillTimer(main hwnd, 1) 0x47624C、ring A/B 排水、DeleteObject([+0x2F877C]) 0x476068、子对象更新 0x454270/0x43B190/0x427440/0x403AC0、E11xx 三列表排空、声音管理器 0x45B210/0x45B3D0、游戏对象 0x451420。
- **IAT 新增/修正（pefile）**：0x47624C=KillTimer（原标 ShowWindow-like 修正）、0x476064=CreateSolidBrush、0x476068=DeleteObject、0x4762BC=MoveWindow、0x4762CC=SetWindowTextA；0x4762B0=SetRect、0x47630C=timeGetTime 确认。
- **交叉验证**：0xC 选项窗 = F324 全吻合；id8 聊天 = 已知锚 main+0x507EC；id0xF 行会公告 = id15 通知窗（0x777200 锚 VA 差异 pending：hero+0x52E5C=0x779600）；0x565994 = 零 BSS 容器。
- 落盘：`window-catalog-evidence.json`（F335，primary-bytes）+ matrix window-catalog 新记录 + layout.json version 0.13（8 新记录 + hud.belt + 16 hud.* 字符串/帧对注记）+ RESEARCH_LOG Round 29。

## Round 30 (2026-08-12) — 主游戏循环层级 + 实体点击分派（Finding 336：WinMain 消息循环 → [0x8B1878] 状态机 → 0x41BB00 tick；0x419D40 点击分派；0x777200 算术修正）

- **〔核心〕WinMain 消息循环**（ret 0x10）：PeekMessageA 0x4762A8 → GetMessageA 0x4762A4 → TranslateMessage 0x4762A0 → DispatchMessageA 0x47629C；dt = timeGetTime 差；**状态机 [0x8B1878]**：0=intro 0x402BE0(&0x8A9520) / 2=角色选择 0x4575D0(&0x8A7140) / 3=游戏内 **0x41BB00(&main, dt)**（[0x8AB7E8] 门）；GetAsyncKeyState(0x2C)；GetLocalTime → 时钟 '[%s---- %s] - %d年 %d月 %d日 %d时 %d分 %d秒' → 0x45DD70。转移：=0@0x4020AD、=2@0x419BEA、=3@0x4570B9。
- **0x41BB00 = 游戏主 tick(dt)**：BGM 5s 门（[+0x428048]>0x1388 → 0x45B250 地图 BGM + Sleep(30)）；环排水 0x41B440→0x422280→0x4227F0→0x465EA0→0x454C50；busy → 0x43B1E0 地图滚动；实体点击 0x419D40 + 瓦片 0x41C450；列表 vtable 调用（mouse 0x8AB7BC）；HUD 目标框链（0x40A8A0/0x40BB00/vtable+0x80）；当前目标 → 0x4516D0 移动 / 0x451700 攻击；HUD 绘制 0x4294E0；效果更新 0x41B8D0；断线公告 0x418030（cp949 0x47AF80『서버와의 접속이 불안합니다…』）。
- **0x41B8D0 = 屏幕特效条件更新**（门 [+0x428064]，非主帧循环——Round 30 早期追踪修正）。
- **0x419D40 = 世界实体排序/点击分派**（F331 四画家数组 root+0x154/+0x2E4/+0x474/+0x604 确认）：点击按类型 word[+0x10] 分派 {0x10,0x16,0x3F,0x14A-0x14E,0x48} 特殊拾取（[+0x124]、视口命中、tile 表 +0x2E4 100 槽）；{9,0x35,0x150} 泛型 vtable+0xC；PtInRect 通道 +0x474；timeGetTime 超时通道 +0x604。**Round 29『0x41A0C0 window-id dispatch』误标修正：实为 0x419D40 体内 0x41A0D9 起。**
- **0x777200 算术修正**：hero 0x7243A4 + 0x52E5C = **0x777200**（Round 29 误算 0x779600 作废）；F268/F294 锚成立，id-15 公告窗 = hero+0x52E5C 内嵌（ctor 0x43E260）。
- **IAT 新增/修正（pefile）**：0x4762A8=PeekMessageA、0x4762A4=GetMessageA、0x4762A0=TranslateMessage、0x47629C=DispatchMessageA、0x476298=GetAsyncKeyState、0x476120=GetLocalTime、0x4762B4=PtInRect、0x4760CC=Sleep。
- 落盘：`game-loop-and-entity-dispatch-evidence.json`（F336，primary-bytes）+ matrix game-loop 新记录 + layout.json version 0.14（5 新记录 + 0x779600→0x777200 全库修正）+ RESEARCH_LOG Round 30。

## Round 31 (2026-08-12) — 窗口可见性调度（Finding 337：0x42ADB0 模态 id 索引切换 + close-all + 可见链表 + id0=背包定案）

- **〔核心〕0x42ADB0 = 窗口可见性切换分派器**（ret 4）：先 close-all 0x42B820（模态单窗口）→ id>0xF 守卫 → 16 项跳表 0x42B3E4；门 [obj+0x30]（ctor arg8 活动标志，0x423CA0 初 0）≠0 → HIDE（0x42AC50 链表移除 + vtable+0x10(0)）；==0 → SHOW（0x42AC30 插入 main+0xD24 → 0x449870 + vtable+0x10(1)）。
- **16 项 id→obj→gate 表**：id0 +0x6554 背包（F288 mode byte +0x54、grid reset 0x42FF90、caption Q 三线合一——Round 29『右侧面板』作废）；id1 +0x29CE4 状态；id2 +0x33188 商店（默认隐藏）；id3 +0x3399C 交易（F295）；id4 +0x4707C 物品；id6 +0x47834 组队（F331『背包』标签修正）；id7 +0x47C28；id8 +0x507EC 聊天（MoveWindow+ShowWindow(5) 特殊）；id9 +0x51150 NPC 对话（F331『快捷栏』修正）；idB +0x516E8；idC +0x518E0 选项；idD +0x52118 坐骑；idE +0x524F0 属性；idF +0x52E5C 公告（SetWindowTextA([+0x53028], 0x8B187C)/ShowWindow/UpdateWindow/MoveWindow + [0x8AA498] 特殊）；id5/10 未用（守卫）。
- **close-all 0x42B820**：ids 0..0xE 仅（跳表 0x42B938），0x423F90(obj,0)；id15 排除（F294 确认）。**点击分派 0x42B430**：链表头 → 跳表 0x42B658 → 各窗口 0x423FA0(obj, x, y, 0)。
- **43 调用者**：背包模式 4、服务端事件 6、行会公告 3、caption 动作表 20、热键 8、TAB 1、守卫安全（0x42CC8B push 81）。
- 落盘：`window-visibility-dispatch-evidence.json`（F337 追加段 + closed_notes，保留 Round 12/21 原记录）+ matrix window-visibility 新记录 + layout.json version 0.15（3 新记录 + window-catalog id0/id2/id3/id6/id9 修正）+ RESEARCH_LOG Round 31。

## Round 32 (2026-08-12) — 窗口身份定稿 + 绘制/热键分派（Finding 338：14 窗口身份全定 + 0x428105 渲染分派 + 热键表 0x42CC76）

- **〔核心〕0x428105 = 窗口绘制分派**：可见链表 → 渲染表 0x428358（16 项全映射）→ IntersectRect [0x476248] 视口裁剪（id8 除外）→ 鼠标分派 0x428398（id0/1/2/3/7）→ 未消费 ShowWindow(0) 回退。
- **〔核心〕热键表 0x42CC76 全解**：Q→id0 背包、W→id1 状态栏、E→id14 技能书、R→id8 聊天、S→id13 坐骑、D→id11 信息窗口、Z→亮度 [0xD40]、C→实体查找、V→小地图、B→技能浏览、G→id6 组队、F→行会、N→id12 选项、T→小地图门。**F329 修正：D→id11（非坐骑），S→id13。**
- **身份定稿**：id0 背包 / id1 状态栏 / id2 商店 / id3 交易 / id4 行会（F294，F331『物品』修正）/ id6 组队 / id7 状态-形象预览（角色形象 @ +0x61/+0xC8）/ id8 聊天 / id9 NPC 对话（F331『快捷栏』修正）/ idB 信息窗口-任务（文本列表 200px 宽门）/ idC 选项 / idD 坐骑 / idE 技能书（魔法页签）/ idF 公告；id5/10 未用。
- **IAT 新增**：0x476248=IntersectRect、0x4762B8=SetFocus（F337 候选确认）、0x476250=GetFocus、0x476254=GetWindowRect、0x4762F0=FillRect、0x4762F4=FrameRect。
- 落盘：`window-paint-and-hotkey-dispatch-evidence.json`（F338，primary-bytes）+ matrix window-identities-final 新记录 + layout.json version 0.16（2 新记录 + window-catalog 6 身份修正）+ RESEARCH_LOG Round 32。

## Round 33 (2026-08-12) — 状态窗口 id1 家族 + 模拟器热键层（Finding 339）

- **〔核心〕id1 状态窗口 paint 0x44B2D0**：mode byte [+0x54] 分派 → SetRect 视口 → '本级' 0x47C348 测宽 → 名字文本 0x7776A0 0xDCFFDC / 0x7776E0 0xB4FAFF → 'LEVEL' 0x47C74C 0xFAE1C8 + font 굴림체 0x47BE18 → 形象帧 0xA7/0xAA（选择器 0x566DD4 + [0x5659CC]，双 blit @ +0xB0/+0x109 与 +0x61/+0xC8）→ 2 子控件。
- **level 字节 0x777720** 唯一读者 0x44B569（BSS 运行时 [INFERENCE]）；0x7776A0 双角色（地图名缓冲 + 状态名字）。
- **鼠标 0x44B720 12 槽 PtInRect 命中** → 0x4341F0 属性详情；点击 0x44B7A0 类型分派（5/6/9 vs 7/8）。
- **NPC 关闭 0x41C1E0**：id9 + id2 + 其他窗口门控关闭链。
- **模拟器热键层**：builder 新增 hotkeys/window_catalog 块；app.js bindHotkeys（Q/W/E/R/S/D/G/N）；浏览器验证 Q 开 window.inventory；数据重生成 windows=18。
- 落盘：`status-window-family-evidence.json`（F339，primary-bytes）+ matrix status-window 新记录 + layout.json version 0.17（2 新记录）+ builder/app.js/data 更新 + RESEARCH_LOG Round 33。

## Round 34 (2026-08-12) — 物品提示框 + 商店窗口家族（Finding 340）

- **〔核心〕0x4341F0 = 物品提示框渲染器**：行列表（+0x64/+0x70 stride 0x3C、0xF 行高、0x45E0C0 测宽）→ 浮动矩形（0x466800 浮点缩放）→ 图标帧（0x5668C4 + word[+0x28]）→ 800px 裁剪 → 底板 0x329696（0x45E570）→ 文本 0x45DE50。调用者：status 12 槽 / 背包 / 商店。
- **背包鼠标 0x42FAB0**：门 [0x7243C4] → 0x42F240 46 槽命中（stride 0x184）→ 0x4341F0(&slot+0x780, mouse+0xA)。
- **商店 id2 定案**：ctor 0x44D310（8 控件帧对 0x3F2-0x3F9 + gauge + 26 槽）、paint 0x44E260（mode +0x5F8 双布局）、mouse 0x44E650（mode 1/2 → 0x44E800 → 0x4341F0，[item+0x22] 0xA/0xB 标志）。
- **三套 tooltip 系统**：物品 0x4341F0（0x329696）/ caption 0x417370（0x96FFFF）/ 悬停名签 0x40BB00。
- 落盘：`item-tooltip-and-store-family-evidence.json`（F340，primary-bytes）+ matrix item-tooltip-store 新记录 + layout.json version 0.18（2 新记录）+ RESEARCH_LOG Round 34。

## Round 35 (2026-08-12) — 交易/聊天/选项绘制定稿 + 窗口绘制矩阵全表（Finding 341）

- **交易 paint 0x415B10**：双栏分割 +0x5C/+0x6C → PtInRect 悬停高亮（左/右）→ 物品悬停 0x416830 + 0x4162E0（门 [0x7243C4]&&[0x7243D8]==0）；行几何 idx*9。
- **聊天 paint 0x414700**：消息环（head +0x58/cursor +0x5C/count +0x6D0/scroll +0x68，节点 {+0 type, +4 text, +0x408 next}）→ 19 行 × 14px → 0x45DD70 逐行（颜色 [0x8AB7C4]）→ 滚动条 0x4179B0 @ +0x6D4。
- **选项 paint 0x441380**：8 控件 0x417830 重定位。
- **窗口绘制矩阵定稿**：14 窗口 paint/mouse 全枚举（id5/10 无窗）。
- 落盘：`trade-chat-option-paint-evidence.json`（F341，primary-bytes）+ matrix paint-matrix-final 新记录 + layout.json version 0.19（3 新记录）+ RESEARCH_LOG Round 35。

## Round 36 (2026-08-12) — EI 地图目录清单（Finding 342：544 张全验证 + 瓦片库分布 + mapviewer 冒烟）

- **544 张 .map 全解析通过**（w/h @ 0x16/0x18 与载入器 0x43B600 一致）；0.map=比奇城 800×800；尺寸/尺寸直方图记录。
- **瓦片库分布**：back {0,1,2}=tiles 族；mid/front {4,5,6,10,12,13,15}=houses/cliffs/dungeons/objects/wood；255=空层。
- **mapviewer 冒烟**：/api/maps、/tile（512×512 JPEG）、/api/cell（lib 解析正确）全 200。
- 落盘：`docs/research/mir3-map-reconstruction/map-inventory-evidence.json`（F342，primary-bytes）+ RESEARCH_LOG Round 36。

## Round 37 (2026-08-12) — 城镇/洞穴地图深挖 + 瓦片绑定公式（Finding 343）

- **客户端 56 槽瓦片绑定公式定案**：map+0x124 tile-row → 绑定文件 id [(row+1)*14, (row+2)*14)（0x43B77A imul 0x0E）；row0=wood id14-27（530 张含全部城镇洞穴）、row1=sand id28-41（14 张沙漠）。
- **KR_ORDER 地形解析修正**：wood_X → Data/Wood/X.wil、sand_X → Data/Sand/X.wil（实测全存在）；Round 36『缺失』系顶层扫描错误。
- **城镇 vs 洞穴层构成**：城镇 back{0,1}+mid/front{15,5,10,0}；洞穴 back{2}+mid{15,12}。
- **三镇渲染对比**：0/1/02 全 200，视觉验证草地地面。
- 落盘：`town-cave-map-deepdive-evidence.json`（F343，primary-bytes）+ RESEARCH_LOG Round 37。

## Round 38 (2026-08-12) — 洞穴分支 + 沙漠图深挖（Finding 344）

- **D1011/D1012**（300×300）：back{2 tiles5c}+mid{15,13 object2c}+front{15}；渲染=暗岩石洞。
- **4.map**（800×800 row-1）：back{1,0,30 sand_tilesc}+mid{15,5,0,10}；**41.map** 稀疏 + mid{40 sand_smobjectsc}——sand lib 30/40 在绑定范围 28..41 内使用确认。
- **渲染验证**：4.map 沙地、D1011 洞穴岩石（inspect_image）；MAP-SURVEY.md 追加。
- 落盘：`cave-desert-map-evidence.json`（F344，primary-bytes）+ MAP-SURVEY.md + RESEARCH_LOG Round 38。

## Round 39 (2026-08-12) — 模拟器窗口目录接线（Finding 345：14 窗口全 primary-static + 8 热键验证）

- **builder 改造**：window-catalog windows[] id→x/y 按 winid 优先/frame 兜底解析；origin 解析序 5 级。
- **14/14 窗口 primary-static 精确坐标**（背包 518,0 / 状态 0,0 / 行会 102,22 / 选项 276,113 / 技能书 348,0 / 公告 107,110…）。
- **浏览器验证**：8 热键全开对窗 + 二次按全关；几何与 ctor 表一致。
- **闭环**：EXE → 证据 JSON → layout.json → 模拟器数据 → 渲染。
- 落盘：`simulator-window-catalog-wiring-evidence.json`（F345）+ builder/data 更新 + RESEARCH_LOG Round 39。

## Round 40 (2026-08-12) — 模拟器聊天环 + 模态切换（Finding 346）

- **聊天 19 行上限**（F341 0x414700 语义）；**模态切换**（F337 0x42ADB0 close-all，id15 除外）。
- **浏览器验证**：Q→W 仅 status 开、Q 再按仅 bag 开；chat ≤19 行。
- 落盘：`simulator-chat-modal-wiring-evidence.json`（F346）+ app.js + RESEARCH_LOG Round 40。

## Round 41 (2026-08-12) — NPC 对话窗口家族（Finding 347）

- **paint 0x43F460**：dialog-type 跳表（文本 2 列换行 / 菜单 / 脚本 token）；**FCOLOR 色码表 0x47C4A8**（8 色 DOS 调色板）+ **NPCIMG 头像**（NPCFace.wil +0x278）。
- **click 0x43E4B0**：2 子控件命中 + 编辑缓冲 → GetWindowTextA → msg 0x410/0x411。
- **模拟器接线**：NPC 点击 → 对话窗 + FCOLOR/NPCIMG demo 内容；浏览器验证（行会管理员）。
- 落盘：`npc-dialog-family-evidence.json`（F347，primary-bytes）+ app.js + RESEARCH_LOG Round 41。

## Round 42 (2026-08-12) — 行会窗口 id4 paint 定稿（Finding 348：窗口绘制矩阵 100% 闭合）

- **0x425040**：标题 0x96C8FF + 状态字节 [0x98] 三分派（list0 标记 [行会公告]/[敌对行会]/[联盟行会] / list1 [行会成员] / other 双画阴影绿）+ 滚动条 0x4179B0 @ +0x76C + 9 控件重定位。
- **窗口绘制矩阵 100% 闭合**（14 窗口 paint/mouse/click 全解码）。
- 落盘：`guild-window-paint-evidence.json`（F348，primary-bytes）+ RESEARCH_LOG Round 42。

## Round 43 (2026-08-12) — 登录/角色选择流程（Finding 349）

- **intro 0x402BE0**：3 级 stage（[0x8A4]/[0x8A5] sub-stage，wemade.dat + Interface1c 帧）。
- **char-select 0x4575D0**：5 级 stage（0x457778 表；SelChr.mp3 BGM；0x458B20 进入游戏）。
- **server 0x458F80**：msgid−0x208 → 9 项表（角色列表刷新/建号/进入 OK）；职业名 武士/法师/道士。
- **模拟器登录遮罩**：intro → 连接 → 角色列表 → 进游戏（浏览器验证）。
- 落盘：`login-charselect-flow-evidence.json`（F349，primary-bytes）+ app.js + RESEARCH_LOG Round 43。

## Round 44 (2026-08-12) — HP/MP/EXP 条家族（Finding 350）

- **0x40A8A0**：门 + 类型分派 + HP=cur−dmg+bonus；元素帧=实时值（0x4542A0 注册表）；位置 400/300 中心公式；常量 1/255、0.5、400、300。
- **模拟器条**：primary-static SetRect 证据（0x4276D6/0x4276F0/0x42770D）接线正确。
- 落盘：`hpmp-exp-bar-family-evidence.json`（F350，primary-bytes）+ RESEARCH_LOG Round 44。

## Round 45 (2026-08-12) — 技能格接入 Magic.exp（Finding 351）

- **模拟器技能格**：12 槽现用真实 Magic.exp 记录（基本剑术/攻杀剑术/刺杀剑术/半月弯刀…，primary-static）。
- **EXE 技能链**：0x4525F0 callers 0x4391F0/0x44A9C2；详情 0x43A440 ← 0x439520。
- **浏览器**：E 开技能书，20 内容元素（8 分类 + 12 技能）。
- 落盘：`skill-grid-magic-exp-evidence.json`（F351）+ builder/skills.json + RESEARCH_LOG Round 45。

## Round 46 (2026-08-12) — 背包 46 槽网格（Finding 352）

- **原版背包**：46 槽（0x2E）bag+0x774 stride 0xC2C（0xC20 记录体 +0x780）；网格 WORD 表 +0x324 6 列（F293）。
- **模拟器**：36 槽 → 46 槽（6 列 × 8 行）；浏览器验证 46。
- 落盘：`bag-grid-46-slot-evidence.json`（F352）+ app.js + RESEARCH_LOG Round 46。

## Round 47 (2026-08-12) — 装备面板验证（Finding 353）

- **8 装备槽 primary-static**（头盔/火把/毒药/手镯×2/戒指×2/鞋子，F325）。
- **模拟器状态窗**：8 槽 + 5 属性标签 + 角色形象（浏览器验证）。
- 落盘：`equipment-panel-verification-evidence.json`（F353）+ RESEARCH_LOG Round 47。

## Round 48 (2026-08-12) — 小地图子系统验证（Finding 354）

- **窗口**：hero+0x6214（MMap/FMMap + 128×128 面板）；paint 0x43DA80；update 0x43D850。
- **玩家标记 F310**：活坐标 + 2 写者；MMap value−1 差一。
- **模拟器**：0.map → FMMap F0、面板 672,0-800,128（接线正确）。
- 落盘：`minimap-subsystem-verification-evidence.json`（F354）+ RESEARCH_LOG Round 48。

## Round 49 (2026-08-12) — 聊天输入 + 命令分派（Finding 355）

- **0x404600**：双缓冲恢复（SetWindowTextA + [0xD38] + 0x403640）。
- **0x41ED20**：'+' → 0x41E740 交易；msgid−6 → 字节表 0x421D8C → 跳表 0x421D5C。
- **模拟器聊天命令**：+ / @ / ! / 普通 4 类分派（浏览器验证）。
- 落盘：`chat-input-command-dispatch-evidence.json`（F355，primary-bytes）+ app.js + RESEARCH_LOG Round 49。

## Round 50 (2026-08-12) — 确认/公告提示系统（Finding 356）

- **0x418520**：wparam = ((type<<8|idx)<<16)|tag；MoveWindow+ShowWindow+SendMessageA 0x7EE（F233-238）。
- **模拟器提示**：confirm/notice/gold 三型（帧 950/602/950+输入）；浏览器验证显示。
- 落盘：`prompt-system-verification-evidence.json`（F356，primary-bytes）+ RESEARCH_LOG Round 50。

## Round 51 (2026-08-12) — 任务窗口渲染（Finding 357）

- **0x447470**：文本列表（0x104 步长、19 行上限、200px 测宽门、色 0x1919C8/0x19197D、行距 0x12）。
- **模拟器任务列表**：浏览器验证（D 开窗、首行选中色）。
- 落盘：`quest-window-render-evidence.json`（F357，primary-bytes）+ app.js + RESEARCH_LOG Round 51。

## Round 52 (2026-08-12) — HUD 标题提示框（Finding 358）

- **0x417370**：0x96FFFF 底板 + 1px 黑框 + DrawTextA 0x25（F242/243）。
- **14 caption 标签入模拟器**：样式提示框浏览器验证（交易栏 F80/81 正确配色）。
- 落盘：`caption-tooltip-0x96ffff-evidence.json`（F358）+ builder/app.js + RESEARCH_LOG Round 52。

## Round 53 (2026-08-12) — 目标框/悬停系统（Finding 359）

- **0x40BB00**：3000ms 悬停名签（累加器 + 0x41/0x208 dword 清除）；**0x40B850**：名牌（居中 15px 盒）。
- **模拟器目标流**：点击实体 → 面板 + 目标框（浏览器验证）。
- 落盘：`target-box-hover-verification-evidence.json`（F359，primary-bytes）+ RESEARCH_LOG Round 53。

## Round 54 (2026-08-12) — 组队窗口内容（Finding 360）

- **0x4243D0**：标题 0x7776A0 色 0xDCE6C8 + 成员列表（head +0x58/count +0x68、行距 i*20）+ 编辑占位（0x47BA38/0x47BA10）+ 允许/拒绝。
- **模拟器组队窗**：浏览器验证（G 开窗、标题色正确）。
- 落盘：`group-window-detail-evidence.json`（F360，primary-bytes）+ app.js + RESEARCH_LOG Round 54。

## Round 55 (2026-08-12) — 坐骑窗口接线（Finding 361）

- **F327**：5 子控件、韩文标签（말타기/말내리기/말숨기기/말꺼내기）、命令（@上马/@遛马/@收马）、状态 0x7DA060 门控。
- **模拟器坐骑窗**：浏览器验证（S 键、4 命令）。
- 落盘：`horse-window-wiring-evidence.json`（F361）+ app.js + RESEARCH_LOG Round 55。

## Round 56 (2026-08-12) — 选项窗口验证（Finding 362）

- **F324**：Config.ini 4 开关（BGM/EffectSound/Ambience 死开关/ShadowBlend）+ 音量滑块 → 0x45A4A0。
- **模拟器选项窗**：4 行 + 滑块 + 켬/끔 帧对（F289/F297）。
- 落盘：`option-window-verification-evidence.json`（F362）+ RESEARCH_LOG Round 56。

## Round 57 (2026-08-12) — 商店窗口内容（Finding 363）

- **F289 模式链**：0-4（BUY/SELL/仓库/CRAFT/详情）+ msg 链 + 状态字节 +0x5F8。
- **模拟器商店**：5 行购买列表 / 12 格仓库 +0x720；浏览器验证 state0。
- 落盘：`store-window-content-verification-evidence.json`（F363）+ RESEARCH_LOG Round 57。

## Round 58 (2026-08-12) — 交易窗口内容（Finding 364）

- **F295/F283**：双栏 + 金币框（0x405/0x406）+ 接受定稿（+0x13644）。
- **模拟器交易窗**：60 格 + 金币框 + 区域（浏览器验证）。
- 落盘：`trade-window-content-verification-evidence.json`（F364）+ RESEARCH_LOG Round 58。

## Round 59 (2026-08-12) — 模拟器全链路集成验证（Finding 365）

- **浏览器全流程通过**：登录 → 8 热键 → NPC 对话 → 悬停提示框。
- **HANDOFF 更新**：Round 29-58 交付摘要（30 连发 commit 基线 4e95988..cf56033）。
- 落盘：`integration-sweep-evidence.json`（F365）+ HANDOFF + RESEARCH_LOG Round 59。

## Round 60 (2026-08-12) — 地图切换验证（Finding 366）

- **F333 0x422960**：地图切换 handler（门 + 存盘 + flush + 限流 + 12 槽清零 + 停音效）。
- **模拟器切换**：211 绑定循环（比奇县→边境城市，浏览器验证）。
- 落盘：`map-transition-verification-evidence.json`（F366）+ RESEARCH_LOG Round 60。

## Round 61 (2026-08-12) — NPC 场景实体渲染（Finding 367）

- **F287**：NPC vtable 0x47671C + NPC.wil slot 127 + body 条带 + 帧公式 100*body+10*(flag%3)。
- **模拟器精灵**：行会管理员 → NPC.wil F30（浏览器验证）。
- 落盘：`npc-entity-render-verification-evidence.json`（F367）+ RESEARCH_LOG Round 61。

## Round 62 (2026-08-12) — 最终收尾（Finding 368）

- **数据重生成**（22 窗/41 控件/157 资源）；**全验证套件 exit 0**；**三服务 200**；工作树干净。
- **Round 29-62 = 34 连发 commit（F335-F368）**。
- 落盘：`housekeeping-final-evidence.json`（F368）+ RESEARCH_LOG Round 62。

## Round 63 (2026-08-12) — 瓦片库异常调查（Finding 369）

- **EI 可玩集 = 211 张**（MiniMap 绑定），只用 base/wood/sand libs。
- **147 张未绑定图**携带 forest/snow/200+ lib（kt*/d*/D6xx/0_0031-33），客户端绑定范围外 → 黑块。
- **Forest/Snow 子目录 = 他客户端产物**（EI 3.0 不用）。
- 落盘：`tile-lib-anomaly-survey-evidence.json`（F369，primary-bytes）+ RESEARCH_LOG Round 63。

## Round 64 (2026-08-12) — 地面覆盖调查（Finding 370）

- **211 可玩图全 ≥90% back 覆盖**（0_003 90.9% / 5_0013 94.2% 最低；无缺地面图）。
- **0_003 空间模式修正**：不规则右缘 3 列 + 底部 2 半行（非 P2 均匀边距描述）。
- **ground-not-drawn 证据更新**（f369 精析注记）。
- 落盘：`ground-coverage-survey-evidence.json`（F370，primary-bytes）+ RESEARCH_LOG Round 64。

## Round 65 (2026-08-12) — 帧越界独立验证（Finding 371）

- **4936 OOB 仅 4 图**（3/41/D10031/50.map）；D10031 = back 层新实例（lib2 帧 42759-42766）。
- **F317 更新**（D10031 注记）。
- 落盘：`frame-oob-verification-evidence.json`（F371，primary-bytes）+ RESEARCH_LOG Round 65。

## Round 66 (2026-08-12) — 城镇结构对比（Finding 372）

- **0/02.map 密集城镇**（wood_tilesc 主导）；**3.map 沙巴克稀疏要塞**（255 主导 + Wood/Wallsc 3384 墙格 y211-405 内墙带）。
- **三镇渲染验证**（tile 200 + 视觉）。
- 落盘：`town-structure-comparison-evidence.json`（F372，primary-bytes）+ RESEARCH_LOG Round 66。

## Round 67 (2026-08-12) — 缩放阶梯验证（Finding 373）

- **ladder = 逐图缩放级别**（[最深..适配]，16384/2048 上限公式）——**非地图切换**。
- **公式复验**：800×800→[2,3,4]、600×600→[1,2,3]、≤50→[0]。
- 落盘：`zoom-ladder-verification-evidence.json`（F373）+ RESEARCH_LOG Round 67。

## Round 68 (2026-08-12) — 图层渲染验证（Finding 374）

- **mid/front 开关差异确认**（89506B vs 107427B）；视觉树/岩渲染正确。
- **层序 = back→mid→front**（F331 0x43B440 语义）。
- 落盘：`layer-render-verification-evidence.json`（F374）+ RESEARCH_LOG Round 68。

## Round 69 (2026-08-12) — 精灵偏移/锚点（Finding 375）

- **EI 帧统一 -24,-16 偏移**；客户端地图 blit **忽略偏移左下锚**（仅帧高，0x43B440 目标数学确认）。
- **P9 + F331 确认**。
- 落盘：`sprite-offset-anchor-verification-evidence.json`（F375，primary-bytes）+ RESEARCH_LOG Round 69。

## Round 70 (2026-08-12) — 瓦片缓存验证（Finding 376）

- **缓存键格式** r_{tx}_{ty}_{z}_{layers}n.jpg；冷 1.4s → 热 92ms（15×）、md5 一致。
- **F374 层键产物确认**。
- 落盘：`tile-cache-verification-evidence.json`（F376）+ RESEARCH_LOG Round 70。

## Round 71 (2026-08-12) — 小地图校准交叉验证（Finding 377）

- **268 MMap value−1 + FMMap value−1001 确认**；D901 族空白帧确认（f144-149 None）。
- **81/D452 有真实帧头**（F310 空白清单待 value 精确和解 [candidate]）；D001 f0 600×400 合 F277。
- 落盘：`minimap-calibration-crosscheck-evidence.json`（F377，primary-bytes）+ RESEARCH_LOG Round 71。

## Round 72 (2026-08-12) — 保留标记帧验证（Finding 378）

- **0xFFFF 空哨兵主导**（mid 18M/frt 20.7M 格）；**0xFFxx 仅未绑定遗留图**（0_0031/kt0018 0xFFFC）。
- **==0xFFFF 精确比较、0xFFxx 无特殊语义**确认。
- 落盘：`reserved-frame-marker-verification-evidence.json`（F378，primary-bytes）+ RESEARCH_LOG Round 72。

## Round 73 (2026-08-12) — 瓦片视口验证（Finding 379）

- **0x43B440**：0x6C000 dwords = 768×576 缓冲；24×24 半分辨率窗口（奇偶门 + (y>>1)*w+(x>>1) 索引 + attr/7 行选 + 3 字节记录）。
- 落盘：`tile-viewport-verification-evidence.json`（F379，primary-bytes）+ RESEARCH_LOG Round 73。

## Round 74 (2026-08-12) — 地图审计对账（Finding 380）

- **审计完整**（544 图、5723 异常格/34 图）；D10031 back OOB 确认在 ground 统计。
- **异常类拆分**：帧越界 vs 地面未绘。
- 落盘：`map-audit-reconciliation-evidence.json`（F380，primary-bytes）+ RESEARCH_LOG Round 74。

## Round 75 (2026-08-12) — 地图连接验证（Finding 381）

- **Mapinfo 365 名 + 342 链**；279 双端在 EI（81.6%）；0.map 150 传送记录。
- **Mapinfo（服务端表）与客户端 0x422960 互补**。
- 落盘：`map-connections-verification-evidence.json`（F381）+ RESEARCH_LOG Round 75。

## Round 76 (2026-08-12) — 地图名表验证（Finding 382）

- **双源差异**：mapnames.py 遗留库 vs Mapinfo 服务端；客户端显示服务端推送名（0x7776A0 缓冲）→ **Mapinfo = 运行时真相**。
- **覆盖**：365 命名 / 253 端点未命名。
- 落盘：`map-name-table-verification-evidence.json`（F382，secondary）+ RESEARCH_LOG Round 76。

## Round 77 (2026-08-12) — 地图主题验证（Finding 383）

- **theme = 瓦片行**（530 wood + 14 sand 全集 / 197+14 绑定）。
- **5 图主题/内容不一致**（72/73/76/77/78.map：沙行 + 基础地面库）——新不一致类。
- 落盘：`map-theme-verification-evidence.json`（F383，primary-bytes）+ RESEARCH_LOG Round 77。

## Round 78 (2026-08-12) — 单元旗标分析（Finding 384）

- **flag0 分布**（0-3 + 252-255 哨兵格）；**客户端阻挡 = type 0x32 标记（0x4123E3）非单元旗标**；单元旗标 = 瓦片行 attr。
- 落盘：`cell-flag-analysis-evidence.json`（F384，primary-bytes）+ RESEARCH_LOG Round 78。

## Round 79 (2026-08-12) — 动画单元分析（Finding 385）

- **7.56M 动画格 / 326 图**（D022 族全动画水图）；midAnim 0 = 水/熔岩循环；客户端 ==0xFFFF 帧检查。
- 落盘：`animated-cells-analysis-evidence.json`（F385，primary-bytes）+ RESEARCH_LOG Round 79。

## Round 80 (2026-08-12) — 单元记录布局验证（Finding 386）

- **14 字节单元布局**字节精确（+5 midImg/+7 frontImg）+ 文件尺寸公式精确匹配（9440028）。
- 落盘：`cell-record-layout-verification-evidence.json`（F386，primary-bytes）+ RESEARCH_LOG Round 80。

## Round 81 (2026-08-12) — 地图头验证（Finding 387）

- **28 字节头布局**确认（+0x14 瓦片行、+0x16/+0x18 w/h）；**50.map = WWW 编辑器文本头**（未绑定、客户端固定偏移解析）。
- 落盘：`map-header-verification-evidence.json`（F387，primary-bytes）+ RESEARCH_LOG Round 81。

## Round 82 (2026-08-12) — 洞穴家族对比（Finding 388）

- **四族差异**：D0/D4 = object1c 装饰密集；D1 赤月 = object2c 主导 + 暗美术；D6 诺玛 = 更小 + 稀疏。
- **共性**：back tiles5c + mid wood_tilesc。
- 落盘：`cave-family-comparison-evidence.json`（F388，primary-bytes）+ RESEARCH_LOG Round 82。

## Round 83 (2026-08-12) — 地表图分类（Finding 389）

- **E 路 2 绑定 + 编号 37 绑定**（城镇/野图）；**0_00x 建筑 + kt 全未绑定**。
- 落盘：`surface-map-classification-evidence.json`（F389，primary-bytes）+ RESEARCH_LOG Round 83。

## Round 84 (2026-08-12) — EI vs ZL 库差异（Finding 390）

- **52/56 库 DIFF**；EI 地面库远超 ZL（Tiles5c 20000 vs 35-73）；ZL .Zl 格式。
- **Snow/Forest 未被 EI 使用**（F369 佐证）。
- 落盘：`ei-vs-zl-libraries-verification-evidence.json`（F390）+ RESEARCH_LOG Round 84。

## Round 85 (2026-08-12) — 大型图对比（Finding 391）

- **6=沙漠城、8=冰雪村（稀疏雪镇）、0=比奇城密集、4=沙漠**；主题 wood/sand 分。
- 落盘：`large-map-comparison-evidence.json`（F391，primary-bytes）+ RESEARCH_LOG Round 85。

## Round 86 (2026-08-12) — 小型图分析（Finding 392）

- **无 ≤40 绑定**（实例全未绑定）；最小绑定 50x50。
- **D11xxx 洞穴变体**（wood_tiles5c + wood_dungeonsc 稀疏）——新瓦片集类。
- 落盘：`small-map-analysis-evidence.json`（F392，primary-bytes）+ RESEARCH_LOG Round 86。

## Round 87 (2026-08-12) — 传送坐标验证（Finding 393）

- **2049 条全整数地图格坐标 + 双向对**；0.map 17 条（北界/红月门/西矿口）。
- **与客户端 0x33/0x27A 格式兼容**（F333）。
- 落盘：`transition-coordinate-verification-evidence.json`（F393）+ RESEARCH_LOG Round 87。

## Round 88 (2026-08-12) — 地图渲染性能（Finding 394）

- **/fullmap 9600×6400 26MB**（最深 z=2 16384 上限）；热瓦片 121ms、冷 1.4s。
- 落盘：`map-render-performance-evidence.json`（F394）+ RESEARCH_LOG Round 88。

## Round 89 (2026-08-12) — 地图校验和验证（Finding 395）

- **F317 哈希复验全匹配**（3/41/50.map）；**D10031 钉定 1d1407d0**。
- 落盘：`map-checksum-verification-evidence.json`（F395，primary-bytes）+ F371 更新 + RESEARCH_LOG Round 89。

## Round 90 (2026-08-12) — 地图覆盖完整性（Finding 396）

- **313 MiniMap = 211 出货（100% 审计）+ 102 服务端专属**（客户端缺失，装载失败）。
- 落盘：`map-coverage-completeness-evidence.json`（F396）+ RESEARCH_LOG Round 90。

## Round 91 (2026-08-12) — mapviewer UI 验证（Finding 397）

- **UI 全功能**：选择器、512×512 瓦片、图层开关（f 触发重渲染）、缩放/适配/重建。
- 落盘：`mapviewer-ui-verification-evidence.json`（F397）+ RESEARCH_LOG Round 91。

## Round 92 (2026-08-12) — 地图知识库合成（Finding 398）

- **最终统计**（544/211/102/333、主题 530+14、异常 5723/34）；**MAP-SURVEY 定稿**。
- 落盘：`map-knowledge-synthesis-evidence.json`（F398）+ MAP-SURVEY + RESEARCH_LOG Round 92。

## Round 93 (2026-08-12) — 商店模式状态图（Finding 399）

- **5 态工厂链**（0x44EAB8/0x44F7EF/0x44F940/0x44FB00）+ 状态字节 +0x5F8；模拟器 state0 显示验证。
- 落盘：`store-mode-state-graph-verification-evidence.json`（F399，primary-bytes）+ RESEARCH_LOG Round 93。

## Round 94 (2026-08-12) — 交易关闭验证（Finding 400）

- **模拟器开/关/模态验证**；原版关闭 = 0x42ADB0 → 0x42AC50（F337）。
- 落盘：`trade-closure-verification-evidence.json`（F400）+ RESEARCH_LOG Round 94。

## Round 95 (2026-08-12) — 窗口 Z 序验证（Finding 401）

- **notice 豁免 + 前台 + 模态**全验证（z=50 保持 vs z=100 前台）。
- 落盘：`window-zorder-verification-evidence.json`（F401）+ RESEARCH_LOG Round 95。

## Round 96 (2026-08-12) — 聊天滚动条验证（Finding 402）

- **0x4179B0 量条语义**（94 尺度、6 行视口、value=[+0x68]/max=[+0x6D0]）；模拟器 ±266px 滚动。
- 落盘：`chat-scrollbar-verification-evidence.json`（F402）+ RESEARCH_LOG Round 96。

## Round 97 (2026-08-12) — 聊天频道验证（Finding 403）

- **6 频道命令模板全验证** + 大喊话注入 '!'（F341/F355）。
- 落盘：`chat-channel-verification-evidence.json`（F403）+ RESEARCH_LOG Round 97。

## Round 98 (2026-08-12) — NPC 对话交互（Finding 404）

- **开/选/关全验证**（NPCIMG 头、菜单选择关窗、F347/F337 语义）。
- 落盘：`npc-dialog-interaction-verification-evidence.json`（F404）+ RESEARCH_LOG Round 98。

## Round 99 (2026-08-12) — 行会窗口内容（Finding 405）

- **模拟器成员列表验证**；原版 3 列表态 + 横幅引用（F348/F294）。
- 落盘：`guild-window-content-verification-evidence.json`（F405）+ RESEARCH_LOG Round 99。

## Round 100 (2026-08-12) — 状态属性颜色（Finding 406）

- **F289 颜色应用**（等级 0xfae1c8、值 0xfafafa）浏览器验证。
- 落盘：`status-attribute-colors-evidence.json`（F406）+ app.js + RESEARCH_LOG Round 100。

## Round 101 (2026-08-12) — 选项开关（Finding 407）

- **4 行 ON/OFF + 켬/끔 帧验证**（F324/F289/F297）。
- 落盘：`option-toggle-verification-evidence.json`（F407）+ RESEARCH_LOG Round 101。

## Round 102 (2026-08-12) — 血条动画（Finding 408）

- **三条渲染 + 1.5s 振荡验证**（F350 rects）。
- 落盘：`bar-animation-verification-evidence.json`（F408）+ RESEARCH_LOG Round 102。

## Round 103 (2026-08-12) — 背包提示框（Finding 409）

- **46 槽 + 7 图标验证**；0x42FAB0 → 0x42F240 → 0x4341F0 链（F340）。
- 落盘：`bag-tooltip-verification-evidence.json`（F409）+ RESEARCH_LOG Round 103。

## Round 104 (2026-08-12) — 技能书验证（Finding 410）

- **8 页签 + 12 真实技能槽验证**（F351/F331）。
- 落盘：`skill-detail-verification-evidence.json`（F410）+ RESEARCH_LOG Round 104。

## Round 105 (2026-08-12) — 坐骑交互（Finding 411）

- **4 命令 + 0x7DA060 门控验证**（点击日志分派）。
- 落盘：`horse-interaction-verification-evidence.json`（F411）+ RESEARCH_LOG Round 105。

## Round 106 (2026-08-12) — 小地图控件（Finding 412）

- **128×128 + FMMap F0 绑定验证**（F310）。
- 落盘：`minimap-sim-verification-evidence.json`（F412）+ RESEARCH_LOG Round 106。

## Round 107 (2026-08-12) — 目标框模拟器（Finding 413）

- **稻草人 面板 + 覆盖层验证**（F239/F359）。
- 落盘：`target-sim-verification-evidence.json`（F413）+ RESEARCH_LOG Round 107。

## Round 108 (2026-08-12) — 悬停模拟器（Finding 414）

- **悬停精灵标记 + targetbox 显名验证**（F239/F359）。
- 落盘：`hover-sim-verification-evidence.json`（F414）+ RESEARCH_LOG Round 108。

## Round 109 (2026-08-12) — 点击目标（Finding 415）

- **选中 + 切换验证**（F239/F336）。
- 落盘：`click-targeting-verification-evidence.json`（F415）+ RESEARCH_LOG Round 109。

## Round 110 (2026-08-12) — 登录流程终验（Finding 416）

- **intro → 连接 → 角色列表 → 进游戏全链验证**（F336/F349）。
- 落盘：`login-flow-final-verification-evidence.json`（F416）+ RESEARCH_LOG Round 110。

## Round 111 (2026-08-12) — 角色选择视觉（Finding 417）

- **武士/法师/道士 按钮入登录流**（F349/F311）浏览器验证。
- 落盘：`char-select-visual-verification-evidence.json`（F417）+ app.js + RESEARCH_LOG Round 111。

## Round 112 (2026-08-12) — 证据调试模式（Finding 418）

- **rect + 级别着色覆盖层验证**（primary/primary-static/candidate）。
- 落盘：`evidence-overlay-verification-evidence.json`（F418）+ RESEARCH_LOG Round 112。

## Round 113 (2026-08-12) — 地图背景（Finding 419）

- **FMMap F0 背景 + 800×600 验证**（F277/F310）。
- 落盘：`map-bg-sim-verification-evidence.json`（F419）+ RESEARCH_LOG Round 113。

## Round 114 (2026-08-12) — 模拟器最终集成扫描（Finding 420）

- **全功能单次浏览器通过**（登录/类选/热键/NPC/证据/血条/小地图）。
- 落盘：`simulator-final-sweep-evidence.json`（F420）+ RESEARCH_LOG Round 114。

## Round 115 (2026-08-12) — 目标交付物审计（Finding 421）

- **16 项交付物全达标**（文档/证据/数据/地图/模拟器/双 viewer/commit）。
- 落盘：`deliverable-audit-evidence.json`（F421）+ HANDOFF + RESEARCH_LOG Round 115。

## Round 116 (2026-08-12) — 滚动 blit 复合闭合（Finding 422）

- **长期 pending 项闭合**：0x43B1E0 滚动（±0xC 门 + SetRect ±0x12）→ 0x43B440 缓冲（768×576）→ 0x45E8E0 屏幕 blit（0x410838 瓦片刷新）。
- 落盘：`scroll-blit-composite-closure-evidence.json`（F422，primary-bytes）+ RESEARCH_LOG Round 116。

## Round 117 (2026-08-12) — 地图实体标记（Finding 423）

- **Envir 3323 实体解析**（出生/NPC/怪物+掉落）；mapviewer --envir 服务；F254 标记运行时分离。
- 落盘：`map-entity-markers-verification-evidence.json`（F423）+ RESEARCH_LOG Round 117。

## Round 118 (2026-08-12) — 怪物刷怪覆盖（Finding 424）

- **288 刷怪图**（0.map 348 热点）；**184 EI + 104 服务端专属**（F396 缺口吻合）。
- 落盘：`monster-spawn-coverage-evidence.json`（F424）+ RESEARCH_LOG Round 118。

## Round 119 (2026-08-12) — 怪物分布（Finding 425）

- **2987 项/308 种 + 等级 1-700**（栗子树主导）。
- 落盘：`monster-distribution-evidence.json`（F425）+ RESEARCH_LOG Round 119。

## Round 120 (2026-08-12) — NPC 分布（Finding 426）

- **318/248 种**（六面神石 33 主导）；body → F287 公式。
- 落盘：`npc-distribution-evidence.json`（F426）+ RESEARCH_LOG Round 120。

## Round 121 (2026-08-12) — 商人脚本（Finding 427）

- **339 Market_Def + 格式验证**（%100 加价 + 货物 + #IF/#ACT）。
- 落盘：`merchant-script-verification-evidence.json`（F427）+ RESEARCH_LOG Round 121。

## Round 122 (2026-08-12) — NPC body→帧交叉（Finding 428）

- **6400 帧库验证 F287**；body 10000 = OOB 覆盖。
- 落盘：`npc-body-frame-crosscheck-evidence.json`（F428）+ RESEARCH_LOG Round 122。

## Round 123 (2026-08-12) — 怪物 WIL 族（Finding 429）

- **16×10000 帧 + 88 字符串表 + 0x4538B0 40 槽装载器**；F280 字节级确认。
- 落盘：`monster-wil-family-verification-evidence.json`（F429）+ RESEARCH_LOG Round 123。

## Round 124 (2026-08-12) — DMon 死亡动画族（Finding 430）

- **4340/4000 帧通用死亡库 + 0x454040 5 槽装载器**。
- 落盘：`dmon-death-animation-verification-evidence.json`（F430）+ RESEARCH_LOG Round 124。

## Round 125 (2026-08-12) — 怪物帧密度（Finding 431）

- **10 种族块 × 1000 帧**（304/224 有效 + 空白尾）。
- 落盘：`monster-frame-density-verification-evidence.json`（F431）+ RESEARCH_LOG Round 125。

## Round 126 (2026-08-12) — 怪物动画状态布局（Finding 432）

- **10 帧格 + 双 80 帧攻击段**（304 有效帧）。
- 落盘：`monster-animation-state-layout-evidence.json`（F432）+ RESEARCH_LOG Round 126。

## Round 127 (2026-08-12) — 怪物帧寻址 PRIMARY（Finding 433）

- **(race%10)*1000 公式字节级确认**；50 类跳表 + 0x5600FC 外观表。
- 落盘：`monster-frame-addressing-primary-evidence.json`（F433）+ RESEARCH_LOG Round 127。

## Round 128 (2026-08-12) — 怪物外观表构建（Finding 434）

- **0x5600FC 运行时数组 + 类型分派 + 0x96 工厂**。
- 落盘：`monster-appearance-table-construction-evidence.json`（F434）+ RESEARCH_LOG Round 128。

## Round 129 (2026-08-12) — 怪物动画推进机（Finding 435）

- **+2/+1 tick + 回绕 + 帧公式**（F433 范围消费）。
- 落盘：`monster-anim-advance-machine-evidence.json`（F435）+ RESEARCH_LOG Round 129。

## Round 130 (2026-08-12) — WIL 帧装载器（Finding 436）

- **文件/mmap 双模式 + LRU + 3 新 IAT**（HUD/怪物共用）。
- 落盘：`wil-frame-loader-0x466130-evidence.json`（F436）+ RESEARCH_LOG Round 130。

## Round 131 (2026-08-12) — 怪物阴影/光照（Finding 437）

- **六边形光场渲染器**（0x434A20 + 0x434670 + 模式 [0x61BD4]）。
- 落盘：`monster-shadow-light-system-evidence.json`（F437）+ RESEARCH_LOG Round 131。

## Round 132 (2026-08-12) — 实体屏幕投影（Finding 438）

- **48×32 投影 + 相机链 + 3 层绘制**（F379 调和）。
- 落盘：`entity-screen-projection-evidence.json`（F438）+ RESEARCH_LOG Round 132。

## Round 133 (2026-08-12) — 实体绘制流水线（Finding 439）

- **18 阶段 tick + 6 绘制对象**（F336 4→6 修正）。
- 落盘：`entity-draw-pipeline-evidence.json`（F439）+ RESEARCH_LOG Round 133。

## Round 134 (2026-08-12) — 实体链表容器（Finding 440）

- **5 双向链表 + ctor 顺序**（F336 4→5 修正）。
- 落盘：`entity-list-containers-evidence.json`（F440）+ RESEARCH_LOG Round 134。

## Round 135 (2026-08-12) — 游戏对象重置（Finding 441）

- **480×480 网格缓冲 + 第 5 链表 vtable 0x4766F0 + 8 方向向量**。
- 落盘：`game-object-reset-480grid-evidence.json`（F441）+ RESEARCH_LOG Round 135。

## Round 136 (2026-08-12) — 实体链表维护（Finding 442）

- **ID 清除/移除/状态门**；480 网格写入侧未定位。
- 落盘：`entity-list-add-path-evidence.json`（F442）+ RESEARCH_LOG Round 136。

## Round 137 (2026-08-12) — 维护清扫（Finding 443）

- **全验证通过 + 服务健康 + 108 连发**；实体弧 F429-F442 汇总。
- 落盘：`housekeeping-round137-evidence.json`（F443）+ RESEARCH_LOG Round 137。

## Round 138 (2026-08-12) — 实体可见性网格（Finding 444）

- **480×480 网格角色闭合**（每帧实体桶 + 选择 [0x364444]）。
- 落盘：`entity-visibility-grid-evidence.json`（F444）+ RESEARCH_LOG Round 138。

## Round 139 (2026-08-12) — 实体类型分派表（Finding 445）

- **桶映射 + 选择/剔除表**（瞬时类型视口外剔除）。
- 落盘：`entity-type-dispatch-tables-evidence.json`（F445）+ RESEARCH_LOG Round 139。

## Round 140 (2026-08-12) — 4 桶网格定案（Finding 446）

- **F336「4 画家数组」= 4 每帧实体桶网格**（+0x154/+0x2E4/+0x474/+0x604）。
- 落盘：`four-bucket-grids-evidence.json`（F446）+ RESEARCH_LOG Round 140。

## Round 141 (2026-08-12) — 视口滚动+渲染全解（Finding 447）

- **相机跟随 = 滚动；瓦片 48×32 blit**（F438 字节确认）。
- 落盘：`viewport-scroll-render-full-evidence.json`（F447）+ RESEARCH_LOG Round 141。

## Round 142 (2026-08-12) — 共享资源描述符表（Finding 448）

- **0x5600FC = 全局资源表**（81 引用；F434 范围修正）。
- 落盘：`shared-resource-descriptor-table-evidence.json`（F448）+ RESEARCH_LOG Round 142。

## Round 143 (2026-08-12) — 怪物更新处理器族（Finding 449）

- **7+ 处理器（msg 0xBC6-0xBD8）**；0x5600FC 立即参分类细化。
- 落盘：`monster-update-handlers-evidence.json`（F449）+ RESEARCH_LOG Round 143。

## Round 144 (2026-08-12) — 怪物记录存储（Finding 450）

- **0x8AA5A8 3 子数组 + 0x30 步长 + 线性查找**。
- 落盘：`monster-record-store-evidence.json`（F450）+ RESEARCH_LOG Round 144。

## Pending（未阻塞，持续队列）

- 0x5600FC 条目布局（0x144B 内 WIL 上下文 + 外观数据）— 低优先。
- 0x45DC70 拼接目标 0x8AB7A8 之后 BSS（0x8AB7A8/0x8B187C 内容不可读）→ 存盘路径全链仍缺 BSS 侧直读。
- 0x42C9E0 busy 定时状态显示的渲染侧（0x2A548C 方法，输出目标未解码）。
- write-only 显示状态槽（0x35B251–0x35B258 / 0x35B1F0 / 0x35A34A–0x35A34E）的渲染侧消费者推测在未解码渲染表/数据驱动 UI 中——sim HUD 层按契约消费。
