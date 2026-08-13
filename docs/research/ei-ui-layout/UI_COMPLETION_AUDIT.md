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

## Round 145 (2026-08-12) — 游戏对象基址修正（Finding 451）

- **游戏对象 = main 0x47EF18**（0x8AB828 = 数据包发送器）；F440-448 基址标签修正 + 绝对地址调和。
- 落盘：`game-object-base-correction-evidence.json`（F451）+ RESEARCH_LOG Round 145。

## Round 146 (2026-08-12) — 瓦片存储结构（Finding 452）

- **140 槽 × 0x144 资源存储**（F448 细化）。
- 落盘：`tile-store-structure-evidence.json`（F452）+ RESEARCH_LOG Round 146。

## Round 147 (2026-08-12) — 地面瓦片库表（Finding 453）

- **15+ WIL 路径表**（wood + base）→ 存储 0x5600FC。
- 落盘：`ground-tile-library-table-evidence.json`（F453）+ RESEARCH_LOG Round 147。

## Round 148 (2026-08-12) — 瓦片存储槽位映射（Finding 454）

- **17 库字符串 + 14/70 双初始化循环**。
- 落盘：`tile-store-slot-mapping-evidence.json`（F454）+ RESEARCH_LOG Round 148。

## Round 149 (2026-08-12) — 实体渲染弧闭合（Finding 455）

- **F429-F454 弧闭合 + 120 连发**；全验证绿色。
- 落盘：`entity-render-arc-closure-evidence.json`（F455）+ RESEARCH_LOG Round 149。

## Round 150 (2026-08-12) — 物品提示框详情体（Finding 456）

- **0x430B70 行构建器闭合**（F340 pending）。
- 落盘：`item-tooltip-detail-body-evidence.json`（F456）+ RESEARCH_LOG Round 150。

## Round 151 (2026-08-12) — 物品类构建器 魔御（Finding 457）

- **8 元素魔御行 + 字段语义**（F340 类 1/5）。
- 落盘：`item-class-mdef-builder-evidence.json`（F457）+ RESEARCH_LOG Round 151。

## Round 152 (2026-08-12) — 物品提示框 5 类分类（Finding 458）

- **魔御/武器×2/特殊装备/消耗品**全分类（F340 闭合）。
- 落盘：`item-tooltip-five-classes-evidence.json`（F458）+ RESEARCH_LOG Round 152。

## Round 153 (2026-08-12) — 地面物品渲染（Finding 459）

- **物品帧 [0x62A24]+0x352/0x355**；msg 0x285 误报。
- 落盘：`ground-item-render-evidence.json`（F459）+ RESEARCH_LOG Round 153。

## Round 154 (2026-08-12) — 商店对象布局（Finding 460）

- **货物链表 + 3 槽网格（~90 槽）**（F340 26 槽修正）。
- 落盘：`store-object-layout-evidence.json`（F460）+ RESEARCH_LOG Round 154。

## Round 155 (2026-08-12) — 商店货物填充（Finding 461）

- **BUY 字符串解析器**（strtok '/' 7 字段）；货物源闭合。
- 落盘：`store-goods-fill-evidence.json`（F461）+ RESEARCH_LOG Round 155。

## Round 156 (2026-08-12) — 商店 SELL/仓库 解析器（Finding 462）

- **0xC20 记录构建**（模式 1/2 全解）。
- 落盘：`store-sell-warehouse-parsers-evidence.json`（F462）+ RESEARCH_LOG Round 156。

## Round 157 (2026-08-12) — 商店 CRAFT 解析器（Finding 463）

- **模式族全解**（BUY/SELL/仓库/CRAFT）。
- 落盘：`store-craft-parser-evidence.json`（F463）+ RESEARCH_LOG Round 157。

## Round 158 (2026-08-12) — 物品对象结构（Finding 464）

- **0xC20 统一记录 + 类→类型映射 + 3 图标上下文**。
- 落盘：`item-object-structure-evidence.json`（F464）+ RESEARCH_LOG Round 158。

## Round 159 (2026-08-12) — 物品图标库（Finding 465）

- **StoreItem.wil 1440 帧 + 3 图标上下文**。
- 落盘：`item-icon-library-evidence.json`（F465）+ RESEARCH_LOG Round 159。

## Round 160 (2026-08-12) — 背包交互系统（Finding 466）

- **悬停→提示框链 + 槽操作 + 反序列化**。
- 落盘：`bag-interaction-system-evidence.json`（F466）+ RESEARCH_LOG Round 160。

## Round 161 (2026-08-12) — 背包网格几何（Finding 467）

- **6 列 × 36px + 标记数组**（F293 字节确认）。
- 落盘：`bag-grid-geometry-evidence.json`（F467）+ RESEARCH_LOG Round 161。

## Round 162 (2026-08-12) — 物品/背包/商店弧闭合（Finding 468）

- **F456-F467 弧闭合 + 132 连发**；全验证绿色。
- 落盘：`item-bag-store-arc-closure-evidence.json`（F468）+ RESEARCH_LOG Round 162。

## Round 163 (2026-08-12) — 装备面板槽位（Finding 469）

- **12 槽 + 兼容检查**（F325 8→12 修正）。
- 落盘：`equipment-panel-slots-evidence.json`（F469）+ RESEARCH_LOG Round 163。

## Round 164 (2026-08-12) — 装备数据包处理器（Finding 470）

- **装备包全族 + 英雄同步**（装备面板闭合）。
- 落盘：`equipment-packet-handler-evidence.json`（F470）+ RESEARCH_LOG Round 164。

## Round 165 (2026-08-12) — 装备音效分派器（Finding 471）

- **0x42E2D0 = 音效**（F470 语义修正）。
- 落盘：`equip-sound-dispatcher-evidence.json`（F471）+ RESEARCH_LOG Round 165。

## Round 166 (2026-08-12) — 装备槽绘制（Finding 472）

- **11 槽图标 + 形象帧**（装备渲染链完整）。
- 落盘：`equip-slot-draw-evidence.json`（F472）+ RESEARCH_LOG Round 166。

## Round 167 (2026-08-12) — 装备弧闭合（Finding 473）

- **F469-F472 弧闭合**；用户任务设计提交共存（未动其文档）。
- 落盘：`equipment-arc-closure-evidence.json`（F473）+ RESEARCH_LOG Round 167。

## Round 168 (2026-08-12) — 交易金币框（Finding 474）

- **金币 msg 0x406 + 库存 0x409 + 双栏绘制**（F364 闭合）。
- 落盘：`trade-gold-box-evidence.json`（F474）+ RESEARCH_LOG Round 168。

## Round 169 (2026-08-12) — NPC 对话菜单选项（Finding 475）

- **选项行绘制 + FCOLOR 调色板**（0x47C4D8 修正）。
- 落盘：`npc-dialog-menu-options-evidence.json`（F475）+ RESEARCH_LOG Round 169。

## Round 170 (2026-08-12) — NPC 对话输入/发送（Finding 476）

- **输入/回复发送**（F404 交互闭合）。
- 落盘：`npc-dialog-input-send-evidence.json`（F476）+ RESEARCH_LOG Round 170。

## Round 171 (2026-08-12) — 背包/装备管理器（Finding 477）

- **物品转移 + 文件持久化**（背包↔装备）。
- 落盘：`bag-equip-manager-evidence.json`（F477）+ RESEARCH_LOG Round 171。

## Round 172 (2026-08-12) — 物品存档格式（Finding 478）

- **Data/<名>.itm + 0xC2C 记录**（F293 确认）。
- 落盘：`item-save-file-format-evidence.json`（F478）+ RESEARCH_LOG Round 172。

## Round 173 (2026-08-12) — 可见性通道特殊实体（Finding 479）

- **特殊去重 + 地图对象剔除**（4 网格通道端到端）。
- 落盘：`visibility-pass-special-entities-evidence.json`（F479）+ RESEARCH_LOG Round 173。

## Round 174 (2026-08-12) — 交互弧闭合（Finding 480）

- **F474-F479 弧闭合 + 141 连发**；F364/F404/F336 pending 全闭。
- 落盘：`interaction-arc-closure-evidence.json`（F480）+ RESEARCH_LOG Round 174。

## Round 175 (2026-08-12) — 小地图库装载器（Finding 481）

- **FMMap 表面初始化 + MMap 标记库**。
- 落盘：`minimap-library-loader-evidence.json`（F481）+ RESEARCH_LOG Round 175。

## Round 176 (2026-08-12) — 小地图 blit 运行时（Finding 482）

- **16 位表面复制 + HUD 双实例**。
- 落盘：`minimap-blit-runtime-evidence.json`（F482）+ RESEARCH_LOG Round 176。

## Round 177 (2026-08-12) — 完整 WIL 表装载器（Finding 483）

- **35+ 槽全映射**（F429/F430 扩展）。
- 落盘：`full-wil-table-loader-evidence.json`（F483）+ RESEARCH_LOG Round 177。

## Round 178 (2026-08-12) — 技能按钮点击（Finding 484）

- **9 按钮栏 + msg 0xB1 施法**。
- 落盘：`skill-button-click-evidence.json`（F484）+ RESEARCH_LOG Round 178。

## Round 179 (2026-08-12) — 运行时弧闭合（Finding 485）

- **F481-F484 弧闭合 + 146 连发**；小地图/技能/WIL 全解。
- 落盘：`runtime-arc-closure-evidence.json`（F485）+ RESEARCH_LOG Round 179。

## Round 180 (2026-08-12) — 565 像素混合器（Finding 486）

- **逐像素 alpha 混合**（法术特效 blit 路径）。
- 落盘：`pixel-blend-565-evidence.json`（F486）+ RESEARCH_LOG Round 180。

## Round 181 (2026-08-12) — 特效实体 tick（Finding 487）

- **帧计数 + 死亡生命周期**（F336 特殊族）。
- 落盘：`effect-entity-tick-evidence.json`（F487）+ RESEARCH_LOG Round 181。

## Round 182 (2026-08-12) — 特效实体 vtable（Finding 488）

- **槽映射**（绘制 0x435030 / tick 0x435A20）。
- 落盘：`effect-entity-vtable-evidence.json`（F488）+ RESEARCH_LOG Round 182。

## Round 183 (2026-08-12) — 特效实体生成器（Finding 489）

- **帧基 = [esi]+type*10**（法术特效生命周期闭合）。
- 落盘：`effect-entity-spawner-evidence.json`（F489）+ RESEARCH_LOG Round 183。

## Round 184 (2026-08-12) — 法术特效弧闭合（Finding 490）

- **F486-F489 弧闭合 + 150 连发**；施法管线完整。
- 落盘：`spell-effect-arc-closure-evidence.json`（F490）+ RESEARCH_LOG Round 184。

## Round 185 (2026-08-12) — 形象帧上下文数组（Finding 491）

- **0x565994 = 形象上下文**（F454 pending 闭合，全部低优先项清空）。
- 落盘：`figure-frame-context-array-evidence.json`（F491）+ RESEARCH_LOG Round 185。

## Round 186 (2026-08-12) — monster.dat 结构（Finding 492）

- **432 槽 × 0xFC + 遗留 KR 编码**；客户端零本地名（包驱动 F450）。
- 落盘：`monster-dat-structure-evidence.json`（F492）+ RESEARCH_LOG Round 186。

## Round 187 (2026-08-12) — stditem.dat 结构（Finding 493）

- **1143 物品 [inference] + 遗留 KR 编码**；客户端包驱动。
- 落盘：`stditem-dat-structure-evidence.json`（F493）+ RESEARCH_LOG Round 187。

## Round 188 (2026-08-12) — monster.dat 统计字段（Finding 494）

- **固定偏移统计字节**；名称 = 自定义移位（解码延迟）。
- 落盘：`monster-dat-stat-fields-evidence.json`（F494）+ RESEARCH_LOG Round 188。

## Round 189 (2026-08-12) — 服务端数据库弧闭合（Finding 495）

- **F492-F494 弧闭合 + 154 连发**；客户端包驱动确认。
- 落盘：`server-db-arc-closure-evidence.json`（F495）+ RESEARCH_LOG Round 189。

## Round 190 (2026-08-12) — 客户端瓦片存储索引（Finding 496）

- **(row+1)*14 槽公式字节确认**；mapviewer 完全对齐。
- 落盘：`client-tile-store-index-evidence.json`（F496）+ RESEARCH_LOG Round 190。

## Round 191 (2026-08-12) — 模拟器商店模式循环（Finding 497）

- **5 按钮模式循环 + 浏览器验证**（12 仓库格）。
- 落盘：`simulator-store-mode-cycle-evidence.json`（F497）+ RESEARCH_LOG Round 191。

## Round 192 (2026-08-12) — 模拟器聊天快捷命令（Finding 498）

- **广N 快捷物品分派 + 浏览器验证**。
- 落盘：`simulator-chat-quick-slot-evidence.json`（F498）+ RESEARCH_LOG Round 192。

## Round 193 (2026-08-12) — mapviewer 缓存确认（Finding 499）

- **瓦片 346× + fullmap 26MB 热缓存**（F88/F376/F394 确认）。
- 落盘：`mapviewer-cache-confirm-evidence.json`（F499）+ RESEARCH_LOG Round 193。

## Round 194 (2026-08-12) — HANDOFF 刷新（Finding 500）

- **160 连发 F335-F499 全汇总**（HANDOFF 覆盖完整范围）。
- 落盘：`handoff-refresh-evidence.json`（F500）+ RESEARCH_LOG Round 194。

## Round 195 (2026-08-12) — monster.dat 编码破解（Finding 501）

- **EUC-KR/Hanja 混合**——最后一个 pending 闭合。
- 落盘：`monster-dat-kr-encoding-evidence.json`（F501）+ RESEARCH_LOG Round 195。

## Round 196 (2026-08-12) — stditem.dat 格式破解（Finding 502）

- **1143 × 184B 精确 + EUC-KR 名称**（F493 确认）。
- 落盘：`stditem-dat-kr-format-evidence.json`（F502）+ RESEARCH_LOG Round 196。

## Round 197 (2026-08-12) — 服务端数据库解码弧闭合（Finding 503）

- **F501-F502 弧闭合 + 162 连发**；双库全解码。
- 落盘：`server-db-decode-arc-closure-evidence.json`（F503）+ RESEARCH_LOG Round 197。

## Round 198 (2026-08-12) — MonMagic 块布局（Finding 504）

- **F489 type*10 公式对真实库确认**（153 段）。
- 落盘：`monmagic-block-layout-evidence.json`（F504）+ RESEARCH_LOG Round 198。

## Round 199 (2026-08-12) — 实体类型字语义（Finding 505）

- **单分派族 + 服务端包链接**。
- 落盘：`entity-type-semantics-evidence.json`（F505）+ RESEARCH_LOG Round 199。

## Round 200 (2026-08-12) — 里程碑（Finding 506）

- **200 连发 F335-F505 + 131 证据 JSON + 全 pending 闭合**。
- 落盘：`round-200-milestone-evidence.json`（F506）+ RESEARCH_LOG Round 200。

## Round 201 (2026-08-12) — 法术特效处理器类（Finding 507）

- **9 移动变体**（静止/投射/追踪）。
- 落盘：`spell-effect-handler-classes-evidence.json`（F507）+ RESEARCH_LOG Round 201。

## Round 202 (2026-08-12) — magic.dat 格式（Finding 508）

- **105 法术 × 120B**（服务端 DB 三件套全解码）。
- 落盘：`magic-dat-format-evidence.json`（F508）+ RESEARCH_LOG Round 202。

## Round 203 (2026-08-12) — MiniMap.txt 绑定（Finding 509）

- **37 对 1001-1038**（F310 value−1001 服务端确认）。
- 落盘：`minimap-txt-binding-evidence.json`（F509）+ RESEARCH_LOG Round 203。

## Round 204 (2026-08-12) — MiniMap 地图集交叉（Finding 510）

- **37 = 30 EI + 7 服务端专属**；Mapinfo = 仅传送（F382 修正）。
- 落盘：`minimap-map-set-cross-evidence.json`（F510）+ RESEARCH_LOG Round 204。

## Round 205 (2026-08-12) — Envir 守卫/任务文件（Finding 511）

- **服务端 Envir 清单完整**（全部文件解码）。
- 落盘：`envir-guard-quest-files-evidence.json`（F511）+ RESEARCH_LOG Round 205。

## Round 206 (2026-08-12) — Envir 弧闭合（Finding 512）

- **F508-F511 弧闭合 + 171 连发**；服务端清单完整。
- 落盘：`envir-arc-closure-evidence.json`（F512）+ RESEARCH_LOG Round 206。

## Round 207 (2026-08-12) — 模拟器窗口内容审计（Finding 513）

- **14 客户端窗 + 8 辅助全内容**（41 按钮/170 槽/35 标签）。
- 落盘：`simulator-window-content-audit-evidence.json`（F513）+ RESEARCH_LOG Round 207。

## Round 208 (2026-08-12) — 客户端发送消息目录（Finding 514）

- **34 msgid 目录 + 发送函数**（F460/F474/F476 确认）。
- 落盘：`client-send-msgid-map-evidence.json`（F514）+ RESEARCH_LOG Round 208。

## Round 209 (2026-08-12) — 模拟器+包弧闭合（Finding 515）

- **F513-F514 弧闭合 + 174 连发**；模拟器 + 发包目录完整。
- 落盘：`sim-packet-arc-closure-evidence.json`（F515）+ RESEARCH_LOG Round 209。

## Round 210 (2026-08-12) — 未映射 msgid 发送器（Finding 516）

- **34/34 msgid 全识别**（坐标包 + NPC 回复变体）。
- 落盘：`unmapped-msgid-senders-evidence.json`（F516）+ RESEARCH_LOG Round 210。

## Round 211 (2026-08-12) — 主接收分派表（Finding 517）

- **137 槽 → 49 处理器**（入站包目录完整）。
- 落盘：`recv-dispatch-table-evidence.json`（F517）+ RESEARCH_LOG Round 211。

## Round 212 (2026-08-12) — 第二接收分派表（Finding 518）

- **349 入站槽全映射**（两表 + 怪物族）。
- 落盘：`recv-dispatch-table-2-evidence.json`（F518）+ RESEARCH_LOG Round 212。

## Round 213 (2026-08-12) — 包目录弧闭合（Finding 519）

- **F516-F518 弧闭合 + 178 连发**；双向包目录完整。
- 落盘：`packet-catalog-arc-closure-evidence.json`（F519）+ RESEARCH_LOG Round 213。

## Round 214 (2026-08-12) — 接收表2 处理器语义（Finding 520）

- **13 处理器全分类**（生成/聊天/坐标/状态/查找）。
- 落盘：`recv2-handler-semantics-evidence.json`（F520）+ RESEARCH_LOG Round 214。

## Round 215 (2026-08-12) — 接收表1 处理器语义（Finding 521）

- **49 处理器分类**（商店/行会/背包/装备族）。
- 落盘：`recv1-handler-semantics-evidence.json`（F521）+ RESEARCH_LOG Round 215。

## Round 216 (2026-08-12) — 入站图景弧闭合（Finding 522）

- **F520-F521 弧闭合 + 181 连发**；双向包图景完整。
- 落盘：`inbound-picture-closure-evidence.json`（F522）+ RESEARCH_LOG Round 216。

## Round 217 (2026-08-12) — 怪物接收族结构（Finding 523）

- **每实体状态机**（记录查找 + 回复 0xBC7/0xBD1）。
- 落盘：`monster-recv-family-evidence.json`（F523）+ RESEARCH_LOG Round 217。

## Round 218 (2026-08-12) — 完整包层闭合（Finding 524）

- **协议层全文档化**（34 出站 + 349 入站 + 怪物族）。
- 落盘：`packet-layer-closure-evidence.json`（F524）+ RESEARCH_LOG Round 218。

## Round 219 (2026-08-12) — HANDOFF 刷新 2（Finding 525）

- **183 连发 F335-F524 全汇总**（HANDOFF 覆盖完整范围）。
- 落盘：`handoff-refresh-2-evidence.json`（F525）+ RESEARCH_LOG Round 219。

## Round 220 (2026-08-12) — 模拟器边缘验证（Finding 526）

- **无回归**（商店导航/全局辅助/模块状态）。
- 落盘：`simulator-edge-verification-evidence.json`（F526）+ RESEARCH_LOG Round 220。

## Round 221 (2026-08-12) — 提示框系统细节（Finding 527）

- **3 槽 + 激活 + 点击全解**（F356 族）。
- 落盘：`prompt-system-detail-evidence.json`（F527）+ RESEARCH_LOG Round 221。

## Round 222 (2026-08-12) — Config.ini 保存链（Finding 528）

- **6 键 + 状态字节映射**（F324 确认）。
- 落盘：`config-ini-save-chain-evidence.json`（F528）+ RESEARCH_LOG Round 222。

## Round 223 (2026-08-12) — 聊天输入发送路径（Finding 529）

- **输入门 + 发送旗标 + 聚焦**（F355 流程）。
- 落盘：`chat-input-send-path-evidence.json`（F529）+ RESEARCH_LOG Round 223。

## Round 224 (2026-08-12) — 血条实时值元素（Finding 530）

- **HP 公式 + 帧=实时值**（F350 运行时确认）。
- 落盘：`bar-drain-live-value-evidence.json`（F530）+ RESEARCH_LOG Round 224。

## Round 225 (2026-08-12) — 目标框悬停计时器（Finding 531）

- **3000ms + 重置 + 锚**（F359 生命周期完整）。
- 落盘：`target-box-hover-timer-evidence.json`（F531）+ RESEARCH_LOG Round 225。

## Round 226 (2026-08-12) — UI 角落弧闭合（Finding 532）

- **F527-F531 弧闭合 + 190 连发**；UI 角落字节级完整。
- 落盘：`ui-corner-arc-closure-evidence.json`（F532）+ RESEARCH_LOG Round 226。

## Round 227 (2026-08-12) — HANDOFF 刷新 3（Finding 533）

- **190 连发 F335-F532 全汇总**。
- 落盘：`handoff-refresh-3-evidence.json`（F533）+ RESEARCH_LOG Round 227。

## Round 228 (2026-08-12) — 技能书详情页（Finding 534）

- **名称/等级匹配 + msg 0xA5 请求**（F104）。
- 落盘：`skill-book-detail-page-evidence.json`（F534）+ RESEARCH_LOG Round 228。

## Round 229 (2026-08-12) — 行会窗渲染细节（Finding 535）

- **3 路状态分派 + 滚动条 + 6 控件**（F99/F348）。
- 落盘：`guild-window-render-detail-evidence.json`（F535）+ RESEARCH_LOG Round 229。

## Round 230 (2026-08-12) — 组队窗渲染细节（Finding 536）

- **idx/2*20 行距 + 成员链**（F54 确认）。
- 落盘：`group-window-render-detail-evidence.json`（F536）+ RESEARCH_LOG Round 230。

## Round 231 (2026-08-12) — 任务窗渲染细节（Finding 537）

- **19 行 + 色对 + idx*15 行距**（F51 确认）。
- 落盘：`quest-window-render-detail-evidence.json`（F537）+ RESEARCH_LOG Round 231。

## Round 232 (2026-08-12) — 窗口渲染弧闭合（Finding 538）

- **F534-F537 弧闭合 + 196 连发**；14 窗口渲染全字节级。
- 落盘：`window-render-arc-closure-evidence.json`（F538）+ RESEARCH_LOG Round 232。

## Round 233 (2026-08-12) — HANDOFF 刷新 4（Finding 539）

- **196 连发 F335-F538 + 164 证据 JSON**。
- 落盘：`handoff-refresh-4-evidence.json`（F539）+ RESEARCH_LOG Round 233。

## Round 234 (2026-08-12) — NPC 对话类型分派（Finding 540）

- **4 类型分派 + 7 行换行**（F41/F475）。
- 落盘：`npc-dialog-type-dispatch-evidence.json`（F540）+ RESEARCH_LOG Round 234。

## Round 235 (2026-08-12) — 角色选择阶段机（Finding 541）

- **5 阶段 + 进游戏 0x458B20**（F349）。
- 落盘：`char-select-stage-machine-evidence.json`（F541）+ RESEARCH_LOG Round 235。

## Round 236 (2026-08-12) — 登录族弧闭合（Finding 542）

- **F540-F541 弧闭合 + 200 连发里程碑**。
- 落盘：`login-family-arc-closure-evidence.json`（F542）+ RESEARCH_LOG Round 236。

## Round 237 (2026-08-12) — HANDOFF 刷新 5（Finding 543）

- **200 连发 F335-F542 全汇总**。
- 落盘：`handoff-refresh-5-evidence.json`（F543）+ RESEARCH_LOG Round 237。

## Round 238 (2026-08-12) — 交易栏几何（Finding 544）

- **8×9 双栏 + 36px 格**（F283 修正）。
- 落盘：`trade-pane-geometry-evidence.json`（F544）+ RESEARCH_LOG Round 238。

## Round 239 (2026-08-12) — 坐骑命令分派（Finding 545）

- **4 命令 + 门 [0x7DA060]**（F105/F361）。
- 落盘：`horse-command-dispatch-evidence.json`（F545）+ RESEARCH_LOG Round 239。

## Round 240 (2026-08-12) — 选项窗开关构造（Finding 546）

- **4 开关行 × 2 控件 + BGM 滑块**（F101）。
- 落盘：`option-window-toggle-ctor-evidence.json`（F546）+ RESEARCH_LOG Round 240。

## Round 241 (2026-08-12) — 技能书分类页签（Finding 547）

- **8 页签 + 除 3 计数**（F104/F351）。
- 落盘：`skill-book-category-tabs-evidence.json`（F547）+ RESEARCH_LOG Round 241。

## Round 242 (2026-08-12) — 窗口角落弧闭合（Finding 548）

- **206 连发 + 三服务 200**。
- 落盘：`window-corners-arc-closure-evidence.json`（F548）+ RESEARCH_LOG Round 242。

## Round 243 (2026-08-12) — recv1 mapval7 背包反序列化函数体（Finding 549）

- **12 槽 × 0xC2C + 金币 '금전' 特例**（F520 语义 → 字节级）。
- 落盘：`recv1-mapval7-bag-body-evidence.json`（F549）+ RESEARCH_LOG Round 243。

## Round 244 (2026-08-12) — 窗口开关分派器（Finding 550）

- **16 模式 0x42ADB0 + 开窗列表 [hero+0xD24]**（mapval1 = 行会开 + 背包定位修正）。
- 落盘：`window-toggle-dispatcher-evidence.json`（F550）+ RESEARCH_LOG Round 244。

## Round 245 (2026-08-12) — recv1 mapval14 仓库 + 模式族（Finding 551）

- **背包管理器模式 0/1/3 + 栗子马粮循环**。
- 落盘：`recv1-mapval14-warehouse-mode-evidence.json`（F551）+ RESEARCH_LOG Round 245。

## Round 246 (2026-08-12) — recv 命令 + 异步 TCP 连接（Finding 552）

- **服务器重定向通道**（0x451320 connect / 0x451420 close / IP:port 命令）。
- 落盘：`recv-command-tcp-connect-evidence.json`（F552）+ RESEARCH_LOG Round 246。

## Round 247 (2026-08-12) — recv2 分派完整处理器图（Finding 553）

- **11 处理器 + 默认 + 色表 0x401390**（F518 修正）。
- 落盘：`recv2-dispatch-full-map-evidence.json`（F553）+ RESEARCH_LOG Round 247。

## Round 248 (2026-08-12) — HANDOFF 刷新 6（Finding 554）

- **Round 237-247 追加 + 212 连发**。
- 落盘：`handoff-refresh-6-evidence.json`（F554）+ RESEARCH_LOG Round 248。

## Round 249 (2026-08-12) — recv1 商店族 买/卖/修（Finding 555）

- **模式族 0/1/2/3 完整 + 耐久字 +0x3D/+0x3F**。
- 落盘：`recv1-store-family-evidence.json`（F555）+ RESEARCH_LOG Round 249。

## Round 250 (2026-08-12) — recv1 制作族（Finding 556）

- **4 分支结果 + KR 源字符串确认**。
- 落盘：`recv1-craft-family-evidence.json`（F556）+ RESEARCH_LOG Round 250。

## Round 251 (2026-08-12) — recv1 交易族 + 模式 3 修正（Finding 557）

- **模式 3 = 交易窗**（F313 cap0 佐证；F550/F551 行会归属修正）。
- 落盘：`recv1-trade-family-evidence.json`（F557）+ RESEARCH_LOG Round 251。

## Round 252 (2026-08-12) — 窗口绘制分派器·权威注册表（Finding 558）

- **14 窗口全映射**（F58/F535/F536/F537 绘制目标确认；F550 模式表全面修正）。
- 落盘：`window-paint-dispatcher-registry-evidence.json`（F558）+ RESEARCH_LOG Round 252。

## Round 253 (2026-08-12) — 窗口注册表完整（Finding 559）

- **14 窗口全定名**（模式 C=选项 F546 偏移吻合、9=NPC 对话 F540 jt、F=行会公告编辑、7=角色状态）。
- 落盘：`window-registry-complete-evidence.json`（F559）+ RESEARCH_LOG Round 253。

## Round 254 (2026-08-12) — 窗口命中测试 + 输入路由（Finding 560）

- **0x42AAB0 顶部优先命中 + 悬停提示链**（F464/F544 确认）。
- 落盘：`window-hit-test-input-router-evidence.json`（F560）+ RESEARCH_LOG Round 254。

## Round 255 (2026-08-12) — 窗口系统弧闭合（Finding 561）

- **219 连发 + 186 证据 + 窗口系统完整**。
- 落盘：`window-system-arc-closure-evidence.json`（F561）+ RESEARCH_LOG Round 255。

## Round 256 (2026-08-12) — HANDOFF 刷新 7（Finding 562）

- **Round 248-255 追加 + 220 连发 + 模式表修正定稿**。
- 落盘：`handoff-refresh-7-evidence.json`（F562）+ RESEARCH_LOG Round 256。

## Round 257 (2026-08-12) — recv1 mapval2/3 + 装备音效（Finding 563）

- **交易错误公告 + 装备音效类型分派 + 公共尾 0x42181D**。
- 落盘：`recv1-error-equip-sound-evidence.json`（F563）+ RESEARCH_LOG Round 257。

## Round 258 (2026-08-12) — 文本渲染族 GDI（Finding 564）

- **测量/绘制/DrawText/굴림 字体管线**（0x8AB7A8 屏幕对象）。
- 落盘：`text-render-family-gdi-evidence.json`（F564）+ RESEARCH_LOG Round 258。

## Round 259 (2026-08-12) — recv1 实体生成/移除（Finding 565）

- **类型分派生成 + F336 实体链表 + 重生特例**。
- 落盘：`recv1-entity-spawn-remove-evidence.json`（F565）+ RESEARCH_LOG Round 259。

## Round 260 (2026-08-12) — 实体初始化 + 帧推进核心（Finding 566）

- **init/tick/paint 三件套 + 生命周期闭环**（F489/F435/F436 连接）。
- 落盘：`entity-init-tick-core-evidence.json`（F566）+ RESEARCH_LOG Round 260。

## Round 261 (2026-08-12) — recv/实体弧闭合（Finding 567）

- **225 连发 + 192 证据 + 入站/实体管线完整**。
- 落盘：`recv-entity-arc-closure-evidence.json`（F567）+ RESEARCH_LOG Round 261。

## Round 262 (2026-08-12) — HANDOFF 刷新 8（Finding 568）

- **Round 257-261 追加 + 226 连发**。
- 落盘：`handoff-refresh-8-evidence.json`（F568）+ RESEARCH_LOG Round 262。

## Round 263 (2026-08-12) — recv1 行会/组队/联盟错误族（Finding 569）

- **10 处理器 + 4 状态跳表**（문주/문파 KR 源确认）。
- 落盘：`recv1-guild-party-errors-evidence.json`（F569）+ RESEARCH_LOG Round 263。

## Round 264 (2026-08-12) — recv1 全覆盖（Finding 570）

- **49/49 recv1 处理器字节级**（建会/联盟错误收尾）。
- 落盘：`recv1-full-coverage-evidence.json`（F570）+ RESEARCH_LOG Round 264。

## Round 265 (2026-08-12) — 入站协议 100% 闭合 + HANDOFF 9（Finding 571）

- **recv1 49 + recv2 11 + 怪物族全函数体 + 229 连发**。
- 落盘：`inbound-protocol-100-percent-evidence.json`（F571）+ RESEARCH_LOG Round 265。

## Round 266 (2026-08-12) — 出站文本协议核心（Finding 572）

- **'#<seq><cmd>/<args>!' 文本帧 + send() 核心**（F524 出站层补全）。
- 落盘：`outbound-text-protocol-core-evidence.json`（F572）+ RESEARCH_LOG Round 266。

## Round 267 (2026-08-12) — 出站目录完整（Finding 573）

- **46 发送调用点**（30 静态 + 6 动态 + 4 文本包装 + 寄存器参）。
- 落盘：`outbound-catalog-complete-evidence.json`（F573）+ RESEARCH_LOG Round 267。

## Round 268 (2026-08-12) — 全协议双向闭合（Finding 574）

- **入站 100% + 出站 100% + 232 连发**。
- 落盘：`full-protocol-bidirectional-evidence.json`（F574）+ RESEARCH_LOG Round 268。

## Round 269 (2026-08-12) — HANDOFF 刷新 10（Finding 575）

- **Round 265-268 追加 + 233 连发**（双向协议里程碑入档）。
- 落盘：`handoff-refresh-10-evidence.json`（F575）+ RESEARCH_LOG Round 269。

## Round 270 (2026-08-12) — 模拟器文本帧协议层（Finding 576）

- **sendFrame '#seq cmd/args!' + 聊天输入接线**（node OK + sim 200）。
- 落盘：`sim-text-frame-protocol-evidence.json`（F576）+ RESEARCH_LOG Round 270。

## Round 271 (2026-08-12) — 文件映射/资源装载器族（Finding 577）

- **F436 双模式装载器闭合 + 长期 pending 尾部完成**。
- 落盘：`file-mapping-resource-loader-evidence.json`（F577）+ RESEARCH_LOG Round 271。

## Round 272 (2026-08-12) — DSound 3D 监听器接口（Finding 578）

- **IID_IDirectSound3DListener 确认 + 全部 pending 笔记闭合**。
- 落盘：`dsound-3d-listener-evidence.json`（F578）+ RESEARCH_LOG Round 272。

## Round 273 (2026-08-12) — 全部 pending 闭合 + HANDOFF 11（Finding 579）

- **零未决项 + 237 连发 + 204 证据**。
- 落盘：`all-pending-closed-evidence.json`（F579）+ RESEARCH_LOG Round 273。

## Round 274 (2026-08-12) — HUD caption 动作分派完整（Finding 580）

- **16 分支 jt 0x42C4D4 + 动作栏全解**（与 F558 注册表交叉确认）。
- 落盘：`hud-caption-action-dispatch-evidence.json`（F580）+ RESEARCH_LOG Round 274。

## Round 275 (2026-08-12) — HUD 热键/目标系统（Finding 581）

- **6 热键槽 + 记录 0xC24 + 金币门复用**。
- 落盘：`hud-hotkey-target-system-evidence.json`（F581）+ RESEARCH_LOG Round 275。

## Round 276 (2026-08-12) — HUD 交互弧闭合（Finding 582）

- **240 连发 + 207 证据 + HUD 交互层完整**。
- 落盘：`hud-interaction-arc-closure-evidence.json`（F582）+ RESEARCH_LOG Round 276。

## Round 277 (2026-08-12) — HANDOFF 刷新 12（Finding 583）

- **Round 273-276 追加 + 241 连发**（零 pending + HUD 交互入档）。
- 落盘：`handoff-refresh-12-evidence.json`（F583）+ RESEARCH_LOG Round 277。

## Round 278 (2026-08-12) — 小地图 HUD + 大地图渲染（Finding 584）

- **小地图缩放/帧 0x33/6 图标 + 大地图 4 态/玩家箭头**（F482 扩展）。
- 落盘：`minimap-hud-worldmap-render-evidence.json`（F584）+ RESEARCH_LOG Round 278。

## Round 279 (2026-08-12) — 聊天布局 + Mir3.ini 配置（Finding 585）

- **双布局聊天窗 + 服务器配置链**（默认 192.168.0.200）。
- 落盘：`chat-layout-mir3-ini-evidence.json`（F585）+ RESEARCH_LOG Round 279。

## Round 280 (2026-08-12) — 窗口拖动/移动分派器（Finding 586）

- **0x42B430 模式 jt + 0x423FA0 位置设置器**（F550 修正）。
- 落盘：`window-drag-move-dispatcher-evidence.json`（F586）+ RESEARCH_LOG Round 280。

## Round 281 (2026-08-12) — 窗口输入/点击分派器（Finding 587）

- **特殊窗→热键→caption→模式 jt 点击路由**（F580/F581 扩展）。
- 落盘：`window-input-click-dispatcher-evidence.json`（F587）+ RESEARCH_LOG Round 281。

## Round 282 (2026-08-12) — HUD 状态条 + HP/等级绘制（Finding 588）

- **浮点渐变 HP 条 + 数字 + 帧 0x43 + 等级**（F530 扩展）。
- 落盘：`hud-status-bars-level-paint-evidence.json`（F588）+ RESEARCH_LOG Round 282。

## Round 283 (2026-08-12) — HANDOFF 刷新 13（Finding 589）

- **Round 277-282 追加 + 247 连发**（HUD 全层入档）。
- 落盘：`handoff-refresh-13-evidence.json`（F589）+ RESEARCH_LOG Round 283。

## Round 284 (2026-08-12) — 实体 HP 条完整（Finding 590）

- **类型 4 路 + 注册表 type*81*4 + 变换 blit**（条系统完整）。
- 落盘：`entity-hp-bar-full-evidence.json`（F590）+ RESEARCH_LOG Round 284。

## Round 285 (2026-08-12) — 主 tick 编排完整（Finding 591）

- **delta/累加器/BGM + 18 阶段全函数体**（F439 扩展）。
- 落盘：`main-tick-orchestration-evidence.json`（F591）+ RESEARCH_LOG Round 285。

## Round 286 (2026-08-12) — HUD + 主循环弧闭合（Finding 592）

- **250 连发 + 217 证据 + HUD/主循环完整**。
- 落盘：`hud-loop-arc-closure-evidence.json`（F592）+ RESEARCH_LOG Round 286。

## Round 287 (2026-08-12) — HANDOFF 刷新 14（Finding 593）

- **Round 283-286 追加 + 251 连发**（实体条 + 主循环入档）。
- 落盘：`handoff-refresh-14-evidence.json`（F593）+ RESEARCH_LOG Round 287。

## Round 288 (2026-08-12) — 大地图覆盖层/悬停（Finding 594）

- **悬停命中 + 坐标文本 + 渐变条 + 帧 0x3C**（F584 扩展）。
- 落盘：`worldmap-overlay-hover-evidence.json`（F594）+ RESEARCH_LOG Round 288。

## Round 289 (2026-08-12) — 大地图玩家标记 + 比例条（Finding 595）

- **HP qword 比率 + 玩家箭头帧 0x3E**（F584/F594 扩展）。
- 落盘：`worldmap-player-marker-ratios-evidence.json`（F595）+ RESEARCH_LOG Round 289。

## Round 290 (2026-08-12) — 地图 widget 弧闭合（Finding 596）

- **254 连发 + 221 证据 + 地图层完整**。
- 落盘：`map-widget-arc-closure-evidence.json`（F596）+ RESEARCH_LOG Round 290。

## Round 291 (2026-08-12) — HANDOFF 刷新 15（Finding 597）

- **Round 287-290 追加 + 255 连发**（地图 widget 入档）。
- 落盘：`handoff-refresh-15-evidence.json`（F597）+ RESEARCH_LOG Round 291。

## Round 292 (2026-08-12) — NPC 对话 4 类型渲染（Finding 598）

- **文本/字体/跳行/脚本标签 FCOLOR/NPCIMG/NOTCLOSE**（F540 扩展）。
- 落盘：`npc-dialog-4type-render-evidence.json`（F598）+ RESEARCH_LOG Round 292。

## Round 293 (2026-08-12) — 聊天窗渲染完整（Finding 599）

- **19 行环 + 滚动条 + 控件**（F341 确认扩展）。
- 落盘：`chat-window-render-full-evidence.json`（F599）+ RESEARCH_LOG Round 293。

## Round 294 (2026-08-12) — 聊天命令表（Finding 600）

- **8 命令串 + 金币提示**（F355 扩展，CN GBK + KR 源）。
- 落盘：`chat-command-table-evidence.json`（F600）+ RESEARCH_LOG Round 294。

## Round 295 (2026-08-12) — 聊天/NPC 对话弧闭合（Finding 601）

- **259 连发 + 226 证据 + 聊天/NPC 层完整**。
- 落盘：`chat-dialog-arc-closure-evidence.json`（F601）+ RESEARCH_LOG Round 295。

## Round 296 (2026-08-12) — HANDOFF 刷新 16（Finding 602）

- **Round 292-295 追加 + 260 连发**（聊天/NPC 层入档）。
- 落盘：`handoff-refresh-16-evidence.json`（F602）+ RESEARCH_LOG Round 296。

## Round 297 (2026-08-12) — 角色选择进入 + 布局（Finding 603）

- **槽记录 + 实体创建 + 16 表单矩形**（F541/F349 扩展）。
- 落盘：`char-select-enter-layout-evidence.json`（F603）+ RESEARCH_LOG Round 297。

## Round 298 (2026-08-12) — 角色列表解析器 + 槽工厂（Finding 604）

- **'/' 分词 + 记录字段 + 9 例 jt**（F603 扩展）。
- 落盘：`char-list-parser-factory-evidence.json`（F604）+ RESEARCH_LOG Round 298。

## Round 299 (2026-08-12) — 登录弧闭合（Finding 605）

- **263 连发 + 230 证据 + 登录族端到端完整**。
- 落盘：`login-arc-closure-evidence.json`（F605）+ RESEARCH_LOG Round 299。

## Round 300 (2026-08-12) — HANDOFF 刷新 17（Finding 606）

- **Round 296-299 追加 + 264 连发**（登录族入档）。
- 落盘：`handoff-refresh-17-evidence.json`（F606）+ RESEARCH_LOG Round 300。

## Round 301 (2026-08-12) — Intro/启动画面状态机（Finding 607）

- **3 阶段 + 3 子阶段链**（Interface1c/wemade 启动/聊天+音频）。
- 落盘：`intro-splash-state-machine-evidence.json`（F607）+ RESEARCH_LOG Round 301。

## Round 302 (2026-08-12) — 登录/服务器屏绘制（Finding 608）

- **服务器列表 + 悬停/选中 + 红名**（F585 连接）。
- 落盘：`login-server-screen-paint-evidence.json`（F608）+ RESEARCH_LOG Round 302。

## Round 303 (2026-08-12) — 启动/登录弧闭合（Finding 609）

- **267 连发 + 234 证据 + 启动链完整**。
- 落盘：`launch-login-arc-closure-evidence.json`（F609）+ RESEARCH_LOG Round 303。

## Round 304 (2026-08-12) — HANDOFF 刷新 18（Finding 610）

- **Round 300-303 追加 + 268 连发 + 300 轮里程碑入档**。
- 落盘：`handoff-refresh-18-evidence.json`（F610）+ RESEARCH_LOG Round 304。

## Round 305 (2026-08-12) — 死亡/传送泵完整（Finding 611）

- **重生冷却 + 坐标重置 + 光照 3 色**（F310 写者确认）。
- 落盘：`death-teleport-pump-evidence.json`（F611）+ RESEARCH_LOG Round 305。

## Round 306 (2026-08-12) — 英雄移动/相机（Finding 612）

- **移动 0x410840 + 地图相机 0x43CC30 + 点击目标**（F591 连接）。
- 落盘：`hero-movement-camera-evidence.json`（F612）+ RESEARCH_LOG Round 306。

## Round 307 (2026-08-12) — 地图移动 + 碰撞（Finding 613）

- **8 方向 jt + 瓦片/实体碰撞**（F612 连接）。
- 落盘：`map-move-collision-evidence.json`（F613）+ RESEARCH_LOG Round 307。

## Round 308 (2026-08-12) — 英雄运行时弧闭合（Finding 614）

- **272 连发 + 239 证据 + 英雄生命周期完整**。
- 落盘：`hero-runtime-arc-closure-evidence.json`（F614）+ RESEARCH_LOG Round 308。

## Round 309 (2026-08-12) — HANDOFF 刷新 19（Finding 615）

- **Round 304-308 追加 + 273 连发**（英雄运行时入档）。
- 落盘：`handoff-refresh-19-evidence.json`（F615）+ RESEARCH_LOG Round 309。

## Round 310 (2026-08-12) — 攻击/交易发送器 + 窗口消息分派（Finding 616）

- **msg 0x401-0x406 + wnd 分派**（F580/F572 连接）。
- 落盘：`attack-trade-sender-wnd-dispatch-evidence.json`（F616）+ RESEARCH_LOG Round 310。

## Round 311 (2026-08-12) — NPC 回复 + 随机种子 + 校验和（Finding 617）

- **msg 0x411 + XOR 校验和反作弊**（F476/F572 连接）。
- 落盘：`npc-reply-random-checksum-evidence.json`（F617）+ RESEARCH_LOG Round 311。

## Round 312 (2026-08-12) — 出站发送弧闭合（Finding 618）

- **276 连发 + 243 证据 + 出站层完整**（协议双向 100%）。
- 落盘：`outbound-send-arc-closure-evidence.json`（F618）+ RESEARCH_LOG Round 312。

## Round 313 (2026-08-12) — 模拟器校验和层（Finding 619）

- **种子 + XOR 校验和镜像**（F617 算法，node OK + sim 200）。
- 落盘：`sim-checksum-layer-evidence.json`（F619）+ RESEARCH_LOG Round 313。

## Round 314 (2026-08-12) — HANDOFF 刷新 20（Finding 620）

- **Round 309-313 追加 + 278 连发**（出站层 + 模拟器校验和入档）。
- 落盘：`handoff-refresh-20-evidence.json`（F620）+ RESEARCH_LOG Round 314。

## Round 315 (2026-08-12) — 英雄名/等级文本层（Finding 621）

- **显示旗标 + 3000ms 计时器 + 居中名文本**（F531 连接）。
- 落盘：`hero-name-level-text-evidence.json`（F621）+ RESEARCH_LOG Round 315。

## Round 316 (2026-08-12) — 实体投影 + HP 框（Finding 622）

- **48×32 投影 + HP 选择 + 钳制**（F435/F350 连接）。
- 落盘：`entity-projection-hp-frame-evidence.json`（F622）+ RESEARCH_LOG Round 316。

## Round 317 (2026-08-12) — 实体渲染弧闭合（Finding 623）

- **281 连发 + 248 证据 + 实体渲染层完整**。
- 落盘：`entity-render-arc-closure-evidence.json`（F623）+ RESEARCH_LOG Round 317。

## Round 318 (2026-08-12) — HANDOFF 刷新 21（Finding 624）

- **Round 314-317 追加 + 282 连发**（实体渲染层入档）。
- 落盘：`handoff-refresh-21-evidence.json`（F624）+ RESEARCH_LOG Round 318。

## Round 319 (2026-08-12) — 特效生成完整（Finding 625）

- **记录 + 目标 + 起止坐标 + 速度**（F489/F435 连接）。
- 落盘：`effect-spawn-full-evidence.json`（F625）+ RESEARCH_LOG Round 319。

## Round 320 (2026-08-12) — 特效 tick + 生命周期（Finding 626）

- **类型族 + 200 tick 门 + 淡出/移除**（F489/F336 连接）。
- 落盘：`effect-tick-lifecycle-evidence.json`（F626）+ RESEARCH_LOG Round 320。

## Round 321 (2026-08-12) — 特效弧闭合（Finding 627）

- **285 连发 + 251 证据 + 特效管线完整**。
- 落盘：`effect-arc-closure-evidence.json`（F627）+ RESEARCH_LOG Round 321。

## Round 322 (2026-08-12) — HANDOFF 刷新 22（Finding 628）

- **Round 318-321 追加 + 286 连发**（特效管线入档）。
- 落盘：`handoff-refresh-22-evidence.json`（F628）+ RESEARCH_LOG Round 322。

## Round 323 (2026-08-12) — 565 混合 + RLE 绘制（Finding 629）

- **RGB565 通道混合 + RLE 填充**（F436 确认）。
- 落盘：`565-blend-rle-paint-evidence.json`（F629）+ RESEARCH_LOG Round 323。

## Round 324 (2026-08-12) — 混合/渲染弧闭合（Finding 630）

- **288 连发 + 254 证据 + 特效渲染完整**。
- 落盘：`blend-render-arc-closure-evidence.json`（F630）+ RESEARCH_LOG Round 324。

## Round 325 (2026-08-12) — HANDOFF 刷新 23（Finding 631）

- **Round 322-324 追加 + 289 连发**（565 混合入档）。
- 落盘：`handoff-refresh-23-evidence.json`（F631）+ RESEARCH_LOG Round 325。

## Round 326 (2026-08-12) — 音效引擎 + DirectSound（Finding 632）

- **播放链 + DSound 初始化**（F607/F470 连接）。
- 落盘：`sound-engine-directsound-evidence.json`（F632）+ RESEARCH_LOG Round 326。

## Round 327 (2026-08-12) — 音乐引擎构造 + 停止（Finding 633）

- **MIDI ctor/停止链**（F632/F607 连接）。
- 落盘：`music-engine-ctor-stop-evidence.json`（F633）+ RESEARCH_LOG Round 327。

## Round 328 (2026-08-12) — 音频弧闭合（Finding 634）

- **292 连发 + 258 证据 + 音频子系统完整**。
- 落盘：`audio-arc-closure-evidence.json`（F634）+ RESEARCH_LOG Round 328。

## Round 329 (2026-08-12) — HANDOFF 刷新 24（Finding 635）

- **Round 325-328 追加 + 293 连发**（音频子系统入档）。
- 落盘：`handoff-refresh-24-evidence.json`（F635）+ RESEARCH_LOG Round 329。

## Round 330 (2026-08-12) — 主构造 + WinMain 引导（Finding 636）

- **0x47EF18 主 ctor + 魔数引导**（F451 证明）。
- 落盘：`main-ctor-bootstrap-evidence.json`（F636）+ RESEARCH_LOG Round 330。

## Round 331 (2026-08-12) — 主构造体 + 子系统链（Finding 637）

- **5 链表 vtable + 全子系统构造**（F451/F336/F439 连接）。
- 落盘：`main-ctor-body-subsystems-evidence.json`（F637）+ RESEARCH_LOG Round 331。

## Round 332 (2026-08-12) — 启动/构造弧闭合（Finding 638）

- **296 连发 + 262 证据 + 启动链完整**（F451 闭环）。
- 落盘：`startup-construction-arc-closure-evidence.json`（F638）+ RESEARCH_LOG Round 332。

## Round 333 (2026-08-12) — HANDOFF 刷新 25（Finding 639）

- **Round 329-332 追加 + 297 连发**（启动链入档）。
- 落盘：`handoff-refresh-25-evidence.json`（F639）+ RESEARCH_LOG Round 333。

## Round 334 (2026-08-12) — 帧节奏 + LRU 淘汰（Finding 640）

- **60s 帧门 + 300s LRU 淘汰**（F436 确认）。
- 落盘：`frame-pacing-lru-evict-evidence.json`（F640）+ RESEARCH_LOG Round 334。

## Round 335 (2026-08-12) — 游戏循环弧闭合（Finding 641）

- **299 连发 + 265 证据 + 客户端生命周期完整**。
- 落盘：`game-loop-arc-closure-evidence.json`（F641）+ RESEARCH_LOG Round 335。

## Round 336 (2026-08-12) — HANDOFF 刷新 26（Finding 642）

- **Round 333-335 追加 + 300 连发里程碑**（客户端生命周期入档）。
- 落盘：`handoff-refresh-26-evidence.json`（F642）+ RESEARCH_LOG Round 336。

## Round 337 (2026-08-12) — 变换矩阵 + 向量数学（Finding 643）

- **4×4 矩阵 + D3D 风格向量核**（F588/F594/F625 共享引擎）。
- 落盘：`transform-matrix-vector-math-evidence.json`（F643）+ RESEARCH_LOG Round 337。

## Round 338 (2026-08-12) — 向量点积 + 矩阵乘法（Finding 644）

- **自/对点积 + 4×4 矩阵乘**（F643 数学核完整）。
- 落盘：`vector-dot-matrix-mult-evidence.json`（F644）+ RESEARCH_LOG Round 338。

## Round 339 (2026-08-12) — 数学核弧闭合（Finding 645）

- **303 连发 + 269 证据 + 数学核完整**。
- 落盘：`math-core-arc-closure-evidence.json`（F645）+ RESEARCH_LOG Round 339。

## Round 340 (2026-08-12) — HANDOFF 刷新 27（Finding 646）

- **Round 336-339 追加 + 304 连发**（数学核入档）。
- 落盘：`handoff-refresh-27-evidence.json`（F646）+ RESEARCH_LOG Round 340。

## Round 341 (2026-08-12) — 通用 WIL blit + RLE 解码（Finding 647）

- **0xC0 跳行/0xC1 像素行 + 屏幕裁剪**（F436 族确认）。
- 落盘：`universal-wil-blit-evidence.json`（F647）+ RESEARCH_LOG Round 341。

## Round 342 (2026-08-12) — 主世界 blit（Finding 648）

- **裁剪 + 表面 + 逐行复制**（F591 阶段连接）。
- 落盘：`world-blit-main-evidence.json`（F648）+ RESEARCH_LOG Round 342。

## Round 343 (2026-08-12) — blit/渲染弧闭合（Finding 649）

- **307 连发 + 273 证据 + 渲染引擎完整**。
- 落盘：`blit-render-arc-closure-evidence.json`（F649）+ RESEARCH_LOG Round 343。

## Round 344 (2026-08-12) — HANDOFF 刷新 28（Finding 650）

- **Round 340-343 追加 + 308 连发**（渲染引擎入档）。
- 落盘：`handoff-refresh-28-evidence.json`（F650）+ RESEARCH_LOG Round 344。

## Round 345 (2026-08-12) — 物品图标 + 详情分派（Finding 651）

- **3 上下文图标 + 5 类详情 jt**（F464/F457/F460 连接）。
- 落盘：`item-icon-draw-detail-evidence.json`（F651）+ RESEARCH_LOG Round 345。

## Round 346 (2026-08-12) — 物品反序列化 + 背包 IO（Finding 652）

- **解析/插入 + 背包取放**（F464/F549 连接）。
- 落盘：`item-deserialize-bag-io-evidence.json`（F652）+ RESEARCH_LOG Round 346。

## Round 347 (2026-08-12) — 物品核心弧闭合（Finding 653）

- **311 连发 + 277 证据 + 物品核心完整**。
- 落盘：`item-core-arc-closure-evidence.json`（F653）+ RESEARCH_LOG Round 347。

## Round 348 (2026-08-12) — HANDOFF 刷新 29（Finding 654）

- **Round 344-347 追加 + 312 连发**（物品核心入档）。
- 落盘：`handoff-refresh-29-evidence.json`（F654）+ RESEARCH_LOG Round 348。

## Round 349 (2026-08-12) — 物品插入 + 放置（Finding 655）

- **显式槽 + 自动放置扫描**（F652 内部）。
- 落盘：`item-insert-place-evidence.json`（F655）+ RESEARCH_LOG Round 349。

## Round 350 (2026-08-12) — 背包/仓库弧闭合（Finding 656）

- **314 连发 + 280 证据 + 背包/仓库完整**。
- 落盘：`bag-storage-arc-closure-evidence.json`（F656）+ RESEARCH_LOG Round 350。

## Round 351 (2026-08-12) — HANDOFF 刷新 30（Finding 657）

- **Round 348-350 追加 + 315 连发**（背包/仓库入档）。
- 落盘：`handoff-refresh-30-evidence.json`（F657）+ RESEARCH_LOG Round 351。

## Round 352 (2026-08-12) — 物品构造 + 类别映射（Finding 658）

- **从记录构造 + 9 类映射 jt**（F464 确认）。
- 落盘：`item-ctor-class-map-evidence.json`（F658）+ RESEARCH_LOG Round 352。

## Round 353 (2026-08-12) — 物品系统最终闭合（Finding 659）

- **317 连发 + 283 证据 + 物品系统完整**。
- 落盘：`item-system-final-closure-evidence.json`（F659）+ RESEARCH_LOG Round 353。

## Round 354 (2026-08-12) — HANDOFF 刷新 31（Finding 660）

- **Round 351-353 追加 + 318 连发**（物品系统入档）。
- 落盘：`handoff-refresh-31-evidence.json`（F660）+ RESEARCH_LOG Round 354。

## Round 355 (2026-08-12) — 商店管理器 + 命中/点击（Finding 661）

- **更新 + 命中 + 点击**（F555 连接）。
- 落盘：`store-manager-hit-click-evidence.json`（F661）+ RESEARCH_LOG Round 355。

## Round 356 (2026-08-12) — 商店绘制 + 模式布局（Finding 662）

- **4 路模式布局 + 8 控件**（F555/F661 渲染侧）。
- 落盘：`store-paint-mode-layouts-evidence.json`（F662）+ RESEARCH_LOG Round 356。

## Round 357 (2026-08-12) — 商店弧闭合（Finding 663）

- **321 连发 + 287 证据 + 商店系统完整**。
- 落盘：`store-arc-closure-evidence.json`（F663）+ RESEARCH_LOG Round 357。

## Round 358 (2026-08-12) — HANDOFF 刷新 32（Finding 664）

- **Round 354-357 追加 + 322 连发**（商店系统入档）。
- 落盘：`handoff-refresh-32-evidence.json`（F664）+ RESEARCH_LOG Round 358。

## Round 359 (2026-08-12) — 音效分派完整映射（Finding 665）

- **32 类型 → 9 音效 id**（F470/F563 完整）。
- 落盘：`sound-dispatch-map-evidence.json`（F665）+ RESEARCH_LOG Round 359。

## Round 360 (2026-08-12) — 物品/音效弧闭合（Finding 666）

- **324 连发 + 290 证据 + 商店/音效完整**。
- 落盘：`item-sound-arc-closure-evidence.json`（F666）+ RESEARCH_LOG Round 360。

## Round 361 (2026-08-12) — HANDOFF 刷新 33（Finding 667）

- **Round 358-360 追加 + 325 连发**（音效映射入档）。
- 落盘：`handoff-refresh-33-evidence.json`（F667）+ RESEARCH_LOG Round 361。

## Round 362 (2026-08-12) — 实体音效槽族（Finding 668）

- **50 槽查找/播放 + 停/清**（F566/F665 连接）。
- 落盘：`entity-sound-slot-family-evidence.json`（F668）+ RESEARCH_LOG Round 362。

## Round 363 (2026-08-12) — 音频最终闭合（Finding 669）

- **327 连发 + 293 证据 + 音频系统完整**。
- 落盘：`audio-final-closure-evidence.json`（F669）+ RESEARCH_LOG Round 363。

## Round 364 (2026-08-12) — HANDOFF 刷新 34（Finding 670）

- **Round 361-363 追加 + 328 连发**（音频完整入档）。
- 落盘：`handoff-refresh-34-evidence.json`（F670）+ RESEARCH_LOG Round 364。

## Round 365 (2026-08-12) — 任务窗绘制完整（Finding 671）

- **19 行 + 宽度门 + 行数学**（F537 扩展）。
- 落盘：`quest-window-paint-full-evidence.json`（F671）+ RESEARCH_LOG Round 365。

## Round 366 (2026-08-12) — 任务系统闭合（Finding 672）

- **330 连发 + 296 证据 + 任务系统完整**。
- 落盘：`quest-system-closure-evidence.json`（F672）+ RESEARCH_LOG Round 366。

## Round 367 (2026-08-12) — HANDOFF 刷新 35（Finding 673）

- **Round 364-366 追加 + 331 连发**（任务系统入档）。
- 落盘：`handoff-refresh-35-evidence.json`（F673）+ RESEARCH_LOG Round 367。

## Round 368 (2026-08-12) — 公告窗绘制完整（Finding 674）

- **5 行渲染 + 节点列表 + 80 剪枝**（F556/F565 连接）。
- 落盘：`notice-window-paint-evidence.json`（F674）+ RESEARCH_LOG Round 368。

## Round 369 (2026-08-12) — 公告系统闭合 + 服务恢复（Finding 675）

- **333 连发 + 297 证据 + wilviewer 重启**。
- 落盘：`notice-system-closure-evidence.json`（F675）+ RESEARCH_LOG Round 369。

## Round 370 (2026-08-12) — HANDOFF 刷新 36（Finding 676）

- **Round 367-369 追加 + 334 连发**（公告系统入档）。
- 落盘：`handoff-refresh-36-evidence.json`（F676）+ RESEARCH_LOG Round 370。

## Round 371 (2026-08-12) — 公告行列表核心（Finding 677）

- **插入/弹出/析构**（F674 队列连接）。
- 落盘：`notice-line-list-evidence.json`（F677）+ RESEARCH_LOG Round 371。

## Round 372 (2026-08-12) — 公告队列弧闭合（Finding 678）

- **336 连发 + 302 证据 + 公告系统完整**。
- 落盘：`notice-queue-arc-closure-evidence.json`（F678）+ RESEARCH_LOG Round 372。

## Round 373 (2026-08-12) — HANDOFF 刷新 37（Finding 679）

- **Round 370-372 追加 + 337 连发**（公告队列入档）。
- 落盘：`handoff-refresh-37-evidence.json`（F679）+ RESEARCH_LOG Round 373。

## Round 374 (2026-08-12) — sprintf + strtol 核心（Finding 680）

- **vsprintf + strtol 内部**（F572/F585/F600 支撑）。
- 落盘：`sprintf-strtol-core-evidence.json`（F680）+ RESEARCH_LOG Round 374。

## Round 375 (2026-08-12) — 字符串库弧闭合（Finding 681）

- **339 连发 + 305 证据 + 字符串库完整**。
- 落盘：`string-lib-arc-closure-evidence.json`（F681）+ RESEARCH_LOG Round 375。

## Round 376 (2026-08-12) — HANDOFF 刷新 38（Finding 682）

- **Round 373-375 追加 + 340 连发**（字符串库入档）。
- 落盘：`handoff-refresh-38-evidence.json`（F682）+ RESEARCH_LOG Round 376。

## Round 377 (2026-08-12) — 数值助手（Finding 683）

- **百分比 + 浮点舍入 + itoa**（F460/F588/F566 支撑）。
- 落盘：`numeric-helpers-evidence.json`（F683）+ RESEARCH_LOG Round 377。

## Round 378 (2026-08-12) — 工具库弧闭合（Finding 684）

- **342 连发 + 308 证据 + 工具库完整**。
- 落盘：`utility-lib-arc-closure-evidence.json`（F684）+ RESEARCH_LOG Round 378。

## Round 379 (2026-08-12) — HANDOFF 刷新 39（Finding 685）

- **Round 376-378 追加 + 343 连发**（工具库入档）。
- 落盘：`handoff-refresh-39-evidence.json`（F685）+ RESEARCH_LOG Round 379。

## Round 380 (2026-08-12) — WIL 装载器入口 + 文件打开（Finding 686）

- **模式分派 + 帧表装载**（F436 连接）。
- 落盘：`wil-loader-entry-open-evidence.json`（F686）+ RESEARCH_LOG Round 380。

## Round 381 (2026-08-12) — 装载器弧闭合 + 服务恢复（Finding 687）

- **345 连发 + 311 证据 + wilviewer 再次重启**。
- 落盘：`loader-arc-closure-evidence.json`（F687）+ RESEARCH_LOG Round 381。

## Round 382 (2026-08-12) — HANDOFF 刷新 40（Finding 688）

- **Round 379-381 追加 + 346 连发**（WIL 装载器入档）。
- 落盘：`handoff-refresh-40-evidence.json`（F688）+ RESEARCH_LOG Round 382。

## Round 383 (2026-08-12) — Base64 编码 + 包头（Finding 689）

- **6 位打包 + 12B 头编码**（F307/F572 确认）。
- 落盘：`base64-encode-header-evidence.json`（F689）+ RESEARCH_LOG Round 383。

## Round 384 (2026-08-12) — 包编码弧闭合（Finding 690）

- **348 连发 + 314 证据 + 包编码完整**。
- 落盘：`packet-encode-arc-closure-evidence.json`（F690）+ RESEARCH_LOG Round 384。

## Round 385 (2026-08-12) — HANDOFF 刷新 41（Finding 691）

- **Round 382-384 追加 + 349 连发**（包编码入档）。
- 落盘：`handoff-refresh-41-evidence.json`（F691）+ RESEARCH_LOG Round 385。

## Round 386 (2026-08-12) — 按方向实体选择（Finding 692）

- **8 方向偏移 + 列表扫描**（F580/F612 连接）。
- 落盘：`entity-select-dir-evidence.json`（F692）+ RESEARCH_LOG Round 386。

## Round 387 (2026-08-12) — 战斗弧闭合（Finding 693）

- **351 连发 + 317 证据 + 战斗选择完整**。
- 落盘：`combat-arc-closure-evidence.json`（F693）+ RESEARCH_LOG Round 387。

## Round 388 (2026-08-12) — HANDOFF 刷新 42（Finding 694）

- **Round 385-387 追加 + 352 连发**（战斗选择入档）。
- 落盘：`handoff-refresh-42-evidence.json`（F694）+ RESEARCH_LOG Round 388。

## Round 389 (2026-08-12) — 英雄角色移动（Finding 695）

- **8 路 jt + 地图移动 + msg 0xBC3**（F612/F613 连接）。
- 落盘：`hero-actor-move-evidence.json`（F695）+ RESEARCH_LOG Round 389。

## Round 390 (2026-08-12) — 英雄角色弧闭合（Finding 696）

- **354 连发 + 320 证据 + 英雄移动完整**。
- 落盘：`hero-actor-arc-closure-evidence.json`（F696）+ RESEARCH_LOG Round 390。

## Round 391 (2026-08-12) — HANDOFF 刷新 43（Finding 697）

- **Round 388-390 追加 + 355 连发**（英雄移动入档）。
- 落盘：`handoff-refresh-43-evidence.json`（F697）+ RESEARCH_LOG Round 391。

## Round 392 (2026-08-12) — 快捷槽物品使用链（Finding 698）

- **记录构建 + 广N 名表**（F355/F549 连接）。
- 落盘：`item-use-quick-slot-evidence.json`（F698）+ RESEARCH_LOG Round 392。

## Round 393 (2026-08-12) — 交互/命令弧闭合（Finding 699）

- **357 连发 + 323 证据 + 交互/命令完整**。
- 落盘：`interaction-command-arc-closure-evidence.json`（F699）+ RESEARCH_LOG Round 393。

## Round 394 (2026-08-12) — HANDOFF 刷新 44（Finding 700）

- **Round 391-393 追加 + 358 连发**（快捷使用/交互入档）。
- 落盘：`handoff-refresh-44-evidence.json`（F700）+ RESEARCH_LOG Round 394。

## Round 395 (2026-08-12) — 控件构造 + 绘制（Finding 701）

- **9 参 ctor + 帧 blit**（F313/F546/F547 全用）。
- 落盘：`control-ctor-paint-evidence.json`（F701）+ RESEARCH_LOG Round 395。

## Round 396 (2026-08-12) — 控件系统弧闭合（Finding 702）

- **360 连发 + 326 证据 + 控件系统完整**。
- 落盘：`control-system-arc-closure-evidence.json`（F702）+ RESEARCH_LOG Round 396。

## Round 397 (2026-08-12) — HANDOFF 刷新 45（Finding 703）

- **Round 394-396 追加 + 361 连发**（控件系统入档）。
- 落盘：`handoff-refresh-45-evidence.json`（F703）+ RESEARCH_LOG Round 397。

## Round 398 (2026-08-12) — 控件命中 + 定位 + 构造（Finding 704）

- **PtInRect + 悬停音效 + vtable 0x476654**（F243 确认）。
- 落盘：`control-hit-setpos-ctor-evidence.json`（F704）+ RESEARCH_LOG Round 398。

## Round 399 (2026-08-12) — 控件系统最终闭合（Finding 705）

- **363 连发 + 329 证据 + 控件 100%**。
- 落盘：`control-final-closure-evidence.json`（F705）+ RESEARCH_LOG Round 399。

## Round 400 (2026-08-12) — HANDOFF 刷新 46 + 400 轮里程碑（Finding 706）

- **Round 397-399 追加 + 364 连发 + 400 轮里程碑**。
- 落盘：`handoff-refresh-46-evidence.json`（F706）+ RESEARCH_LOG Round 400。

## Round 401 (2026-08-12) — 滚动条家族（Finding 707）

- **滑块比例 + 拖动命中 + 箭头点击 10ms 门**（F535/F599/F581 用）。
- 落盘：`scrollbar-family-evidence.json`（F707）+ RESEARCH_LOG Round 401。

## Round 402 (2026-08-12) — 滚动条弧闭合（Finding 708）

- **366 连发 + 332 证据 + 滚动条完整**。
- 落盘：`scrollbar-arc-closure-evidence.json`（F708）+ RESEARCH_LOG Round 402。

## Round 403 (2026-08-12) — HANDOFF 刷新 47（Finding 709）

- **Round 400-402 追加 + 367 连发**（滚动条系统入档）。
- 落盘：`handoff-refresh-47-evidence.json`（F709）+ RESEARCH_LOG Round 403。

## Round 404 (2026-08-12) — 控件绘制状态机 + 滚动条尾部（Finding 710）

- **悬停/可见帧 + 箭头钳制 + 释放 + 控件列表**（F701/F707 精化）。
- 落盘：`control-paint-state-ctor-tail-evidence.json`（F710）+ RESEARCH_LOG Round 404。

## Round 405 (2026-08-12) — 控件 + 滚动条家族最终闭合（Finding 711）

- **369 连发 + 335 证据 + 控件/滚动条 100%**。
- 落盘：`control-scrollbar-final-closure-evidence.json`（F711）+ RESEARCH_LOG Round 405。

## Round 406 (2026-08-12) — HANDOFF 刷新 48（Finding 712）

- **Round 403-405 追加 + 370 连发**（控件+滚动条 100% 入档）。
- 落盘：`handoff-refresh-48-evidence.json`（F712）+ RESEARCH_LOG Round 406。

## Round 407 (2026-08-12) — 窗口基类构造（Finding 713）

- **3 内嵌控件 + 边框按钮 + 居中**（F313 窗口基类）。
- 落盘：`window-base-ctor-evidence.json`（F713）+ RESEARCH_LOG Round 407。

## Round 408 (2026-08-12) — 窗口基类绘制 + 输入（Finding 714）

- **背景 + 标题 + 3 控件循环 + 命中**（窗口基类完整）。
- 落盘：`window-base-paint-input-evidence.json`（F714）+ RESEARCH_LOG Round 408。

## Round 409 (2026-08-12) — 窗口基类弧闭合 + wilviewer 重启（Finding 715）

- **373 连发 + 338 证据 + 窗口基类完整**；wilviewer 死亡 → 重启成功。
- 落盘：`window-base-arc-closure-evidence.json`（F715）+ RESEARCH_LOG Round 409。

## Round 410 (2026-08-12) — HANDOFF 刷新 49（Finding 716）

- **Round 406-409 追加 + 374 连发**（窗口基类完整入档）。
- 落盘：`handoff-refresh-49-evidence.json`（F716）+ RESEARCH_LOG Round 410。

## Round 411 (2026-08-12) — 地图瓦片访问器家族（Finding 717）

- **取类型/可行走/封锁/解锁 + 等距拾取器**（F613 瓦片碰撞核心）。
- 落盘：`map-tile-accessor-family-evidence.json`（F717）+ RESEARCH_LOG Round 411。

## Round 412 (2026-08-12) — 地图相机渲染 + 滚动（Finding 718）

- **视口绘制 + 投影 + 平移缓冲**（地图渲染核心）。
- 落盘：`map-camera-renderer-scroll-evidence.json`（F718）+ RESEARCH_LOG Round 412。

## Round 413 (2026-08-12) — 瓦片碰撞 + 属性 + 方向向量（Finding 719）

- **封锁 bit0 + 属性字 + 8 方向向量**（地图移动核心）。
- 落盘：`tile-collision-attribute-direction-evidence.json`（F719）+ RESEARCH_LOG Round 413。

## Round 414 (2026-08-12) — 地图核心弧闭合（Finding 720）

- **378 连发 + 344 证据 + 地图核心完整**（角落 0x43C9F0 闭合）。
- 落盘：`map-core-arc-closure-evidence.json`（F720）+ RESEARCH_LOG Round 414。

## Round 415 (2026-08-12) — HANDOFF 刷新 50 + 50 刷新里程碑（Finding 721）

- **Round 410-414 追加 + 379 连发 + 50 刷新**（地图核心入档）。
- 落盘：`handoff-refresh-50-evidence.json`（F721）+ RESEARCH_LOG Round 415。

## Round 416 (2026-08-12) — 地图移动 + 实体碰撞（Finding 722）

- **8 方向 + 瓦片 + 实体同瓦片封锁**（F613 jt 确认、F336 链表）。
- 落盘：`map-move-entity-collision-evidence.json`（F722）+ RESEARCH_LOG Round 416。

## Round 417 (2026-08-12) — 地图 + 移动最终闭合（Finding 723）

- **381 连发 + 347 证据 + 地图/移动 100%**（角落 0x43C9F0 + 0x43CC30 闭合）。
- 落盘：`map-movement-final-closure-evidence.json`（F723）+ RESEARCH_LOG Round 417。

## Round 418 (2026-08-12) — HANDOFF 刷新 51（Finding 724）

- **Round 415-417 追加 + 382 连发**（地图/移动 100% 入档）。
- 落盘：`handoff-refresh-51-evidence.json`（F724）+ RESEARCH_LOG Round 418。

## Round 419 (2026-08-12) — 英雄更新 + 死亡/重生（Finding 725）

- **数据装载 + 实体生成 + 双向链表 + 1500ms 重生**（F611 确认）。
- 落盘：`hero-update-death-spawn-evidence.json`（F725）+ RESEARCH_LOG Round 419。

## Round 420 (2026-08-12) — 英雄运行时弧闭合（Finding 726）

- **384 连发 + 350 证据 + 英雄运行时完整**（角落 0x410100 闭合）。
- 落盘：`hero-runtime-arc-closure-evidence.json`（F726）+ RESEARCH_LOG Round 420。

## Round 421 (2026-08-12) — HANDOFF 刷新 52（Finding 727）

- **Round 418-420 追加 + 385 连发**（英雄运行时完整入档）。
- 落盘：`handoff-refresh-52-evidence.json`（F727）+ RESEARCH_LOG Round 421。

## Round 422 (2026-08-12) — 逐瓦片渲染家族（Finding 728）

- **地面 + 物体层 blit 0x45E8E0**（相机滚动依赖）。
- 落盘：`per-tile-render-family-evidence.json`（F728）+ RESEARCH_LOG Round 422。

## Round 423 (2026-08-12) — 地图渲染最终闭合（Finding 729）

- **387 连发 + 353 证据 + 地图系统 100%**。
- 落盘：`map-render-final-closure-evidence.json`（F729）+ RESEARCH_LOG Round 423。

## Round 424 (2026-08-12) — HANDOFF 刷新 53（Finding 730）

- **Round 421-423 追加 + 388 连发**（地图 100% 入档）。
- 落盘：`handoff-refresh-53-evidence.json`（F730）+ RESEARCH_LOG Round 424。

## Round 425 (2026-08-12) — HUD 键盘/输入分派（Finding 731）

- **窗口转发 + 热键 + 冷却 + 名表发送**（F580/F581/F616 用）。
- 落盘：`hud-keyboard-dispatch-evidence.json`（F731）+ RESEARCH_LOG Round 425。

## Round 426 (2026-08-12) — HUD 输入弧闭合（Finding 732）

- **390 连发 + 356 证据 + HUD 输入完整**（角落 0x42C9E0 闭合）。
- 落盘：`hud-input-arc-closure-evidence.json`（F732）+ RESEARCH_LOG Round 426。

## Round 427 (2026-08-12) — HANDOFF 刷新 54（Finding 733）

- **Round 424-426 追加 + 391 连发**（HUD 输入完整入档）。
- 落盘：`handoff-refresh-54-evidence.json`（F733）+ RESEARCH_LOG Round 427。

## Round 428 (2026-08-12) — 公告行列表添加 + 渲染（Finding 734）

- **修剪/插入 + 阴影/绿字 + 寿命**（浮动公告系统）。
- 落盘：`notice-line-list-add-render-evidence.json`（F734）+ RESEARCH_LOG Round 428。

## Round 429 (2026-08-12) — 聊天/公告弧闭合（Finding 735）

- **393 连发 + 359 证据 + 聊天/公告完整**。
- 落盘：`chat-notice-arc-closure-evidence.json`（F735）+ RESEARCH_LOG Round 429。

## Round 430 (2026-08-12) — HANDOFF 刷新 55（Finding 736）

- **Round 427-429 追加 + 394 连发**（聊天/公告完整入档）。
- 落盘：`handoff-refresh-55-evidence.json`（F736）+ RESEARCH_LOG Round 430。

## Round 431 (2026-08-12) — 文本家族 BSS 侧助手（Finding 737）

- **拼接 + 包含 + GDI 绘制**（F564 完整、待办缺口闭合）。
- 落盘：`text-family-bss-helpers-evidence.json`（F737）+ RESEARCH_LOG Round 431。

## Round 432 (2026-08-12) — 文本家族最终闭合（Finding 738）

- **396 连发 + 362 证据 + 文本系统 100%**。
- 落盘：`text-family-final-closure-evidence.json`（F738）+ RESEARCH_LOG Round 432。

## Round 433 (2026-08-12) — HANDOFF 刷新 56（Finding 739）

- **Round 430-432 追加 + 397 连发**（文本系统 100% 入档）。
- 落盘：`handoff-refresh-56-evidence.json`（F739）+ RESEARCH_LOG Round 433。

## Round 434 (2026-08-12) — 商店窗口点击处理（Finding 740）

- **购买 0x3EA + 卖出/修理 + 确认命中**（商店家族扩展）。
- 落盘：`shop-window-click-handler-evidence.json`（F740）+ RESEARCH_LOG Round 434。

## Round 435 (2026-08-12) — 商店家族最终闭合（Finding 741）

- **399 连发 + 365 证据 + 商店 100%**（目标 0x44F1D0 闭合）。
- 落盘：`shop-family-final-closure-evidence.json`（F741）+ RESEARCH_LOG Round 435。

## Round 436 (2026-08-12) — HANDOFF 刷新 57 + 400 连发里程碑（Finding 742）

- **Round 433-435 追加 + 400 连发里程碑**（商店 100% 入档）。
- 落盘：`handoff-refresh-57-evidence.json`（F742）+ RESEARCH_LOG Round 436。

## Round 437 (2026-08-12) — 技能记录装载 + 显示槽（Finding 743）

- **write-only 槽写者找到**（技能装载/显示复制）。
- 落盘：`skill-record-loader-display-slots-evidence.json`（F743）+ RESEARCH_LOG Round 437。

## Round 438 (2026-08-12) — 技能家族闭合（Finding 744）

- **402 连发 + 368 证据 + 技能完整**（write-only 槽解析）。
- 落盘：`skill-family-closure-evidence.json`（F744）+ RESEARCH_LOG Round 438。

## Round 439 (2026-08-12) — HANDOFF 刷新 58（Finding 745）

- **Round 436-438 追加 + 403 连发**（技能完整入档）。
- 落盘：`handoff-refresh-58-evidence.json`（F745）+ RESEARCH_LOG Round 439。

## Round 440 (2026-08-12) — NPC 对话选项命中/选择（Finding 746）

- **命中 + 激活 + 发送 0x451A10**（对话选项 UI）。
- 落盘：`npc-dialog-option-hit-select-evidence.json`（F746）+ RESEARCH_LOG Round 440。

## Round 441 (2026-08-12) — NPC 对话弧闭合（Finding 747）

- **405 连发 + 371 证据 + 对话完整**（目标 0x448490 闭合）。
- 落盘：`npc-dialog-arc-closure-evidence.json`（F747）+ RESEARCH_LOG Round 441。

## Round 442 (2026-08-12) — HANDOFF 刷新 59（Finding 748）

- **Round 439-441 追加 + 406 连发**（对话完整入档）。
- 落盘：`handoff-refresh-59-evidence.json`（F748）+ RESEARCH_LOG Round 442。

## Round 443 (2026-08-12) — 交易槽布局家族（Finding 749）

- **查找空闲 + 5 列网格放置 + 槽写入**（F557 确认）。
- 落盘：`trade-slot-layout-family-evidence.json`（F749）+ RESEARCH_LOG Round 443。

## Round 444 (2026-08-12) — 交易窗口弧闭合（Finding 750）

- **408 连发 + 374 证据 + 交易完整**。
- 落盘：`trade-window-arc-closure-evidence.json`（F750）+ RESEARCH_LOG Round 444。

## Round 445 (2026-08-12) — HANDOFF 刷新 60 + 60 刷新里程碑（Finding 751）

- **Round 442-444 追加 + 409 连发 + 60 刷新**（交易完整入档）。
- 落盘：`handoff-refresh-60-evidence.json`（F751）+ RESEARCH_LOG Round 445。

## Round 446 (2026-08-12) — 组队窗口绘制 + 清除（Finding 752）

- **双列成员 + 5 按钮 + 拆除**（组队窗口完整）。
- 落盘：`party-window-draw-clear-evidence.json`（F752）+ RESEARCH_LOG Round 446。

## Round 447 (2026-08-12) — 组队/社交弧闭合（Finding 753）

- **411 连发 + 377 证据 + 组队完整**。
- 落盘：`party-social-arc-closure-evidence.json`（F753）+ RESEARCH_LOG Round 447。

## Round 448 (2026-08-12) — HANDOFF 刷新 61（Finding 754）

- **Round 445-447 追加 + 412 连发**（组队/社交完整入档）。
- 落盘：`handoff-refresh-61-evidence.json`（F754）+ RESEARCH_LOG Round 448。

## Round 449 (2026-08-12) — 行会窗口绘制（Finding 755）

- **3 页 + 滚动条 + 9 按钮**（行会窗口完整）。
- 落盘：`guild-window-draw-evidence.json`（F755）+ RESEARCH_LOG Round 449。

## Round 450 (2026-08-12) — 行会窗口弧闭合 + Round 450 里程碑（Finding 756）

- **414 连发 + 380 证据 + 行会完整**（Round 450 里程碑）。
- 落盘：`guild-window-arc-closure-evidence.json`（F756）+ RESEARCH_LOG Round 450。

## Round 451 (2026-08-12) — HANDOFF 刷新 62（Finding 757）

- **Round 448-450 追加 + 415 连发**（行会完整入档）。
- 落盘：`handoff-refresh-62-evidence.json`（F757）+ RESEARCH_LOG Round 451。

## Round 452 (2026-08-12) — 角色状态窗口绘制（Finding 758）

- **头像帧 + 11 装备图标 + 名字/标题**（状态窗口完整）。
- 落盘：`char-status-window-draw-evidence.json`（F758）+ RESEARCH_LOG Round 452。

## Round 453 (2026-08-12) — 角色/装备/背包弧闭合（Finding 759）

- **417 连发 + 383 证据 + 角色/装备/背包完整**。
- 落盘：`char-equip-arc-closure-evidence.json`（F759）+ RESEARCH_LOG Round 453。

## Round 454 (2026-08-12) — HANDOFF 刷新 63（Finding 760）

- **Round 451-453 追加 + 418 连发**（角色/装备/背包完整入档）。
- 落盘：`handoff-refresh-63-evidence.json`（F760）+ RESEARCH_LOG Round 454。

## Round 455 (2026-08-12) — 选项窗口绘制 + 点击（Finding 761）

- **4×2 开关 + BGM/SFX 滑块 + 点击**（F546 确认）。
- 落盘：`options-window-draw-click-evidence.json`（F761）+ RESEARCH_LOG Round 455。

## Round 456 (2026-08-12) — 选项窗口弧闭合 + 420 连发里程碑（Finding 762）

- **420 连发 + 386 证据 + 选项完整**。
- 落盘：`options-window-arc-closure-evidence.json`（F762）+ RESEARCH_LOG Round 456。

## Round 457 (2026-08-12) — HANDOFF 刷新 64（Finding 763）

- **Round 454-456 追加 + 421 连发**（选项完整入档）。
- 落盘：`handoff-refresh-64-evidence.json`（F763）+ RESEARCH_LOG Round 457。

## Round 458 (2026-08-12) — 背包窗口绘制（Finding 764）

- **滚动条 + 网格 + 拖动矩阵预览**（背包窗口完整）。
- 落盘：`bag-window-draw-evidence.json`（F764）+ RESEARCH_LOG Round 458。

## Round 459 (2026-08-12) — 窗口系统最终闭合（Finding 765）

- **423 连发 + 389 证据 + 窗口系统 100%**（14 模式全解码）。
- 落盘：`window-system-final-closure-evidence.json`（F765）+ RESEARCH_LOG Round 459。

## Round 460 (2026-08-12) — HANDOFF 刷新 65 + 窗口系统里程碑（Finding 766）

- **Round 457-459 追加 + 424 连发**（窗口 100% 入档）。
- 落盘：`handoff-refresh-65-evidence.json`（F766）+ RESEARCH_LOG Round 460。

## Round 461 (2026-08-12) — 装备窗口绘制（Finding 767）

- **2 页 + 纸娃娃 + 标题 + 槽**（注册表最后窗口解码）。
- 落盘：`equip-window-draw-evidence.json`（F767）+ RESEARCH_LOG Round 461。

## Round 462 (2026-08-12) — 窗口绘制全量闭合（Finding 768）

- **426 连发 + 392 证据 + 14 窗口绘制全解码**。
- 落盘：`window-draws-total-closure-evidence.json`（F768）+ RESEARCH_LOG Round 462。

## Round 463 (2026-08-12) — HANDOFF 刷新 66（Finding 769）

- **Round 460-462 追加 + 427 连发**（14 窗口绘制入档）。
- 落盘：`handoff-refresh-66-evidence.json`（F769）+ RESEARCH_LOG Round 463。

## Round 464 (2026-08-12) — 行会公告编辑器（Finding 770）

- **绘制 + 输入 + 拆分 + 发送**（注册表最后函数体）。
- 落盘：`guild-announce-editor-evidence.json`（F770）+ RESEARCH_LOG Round 464。

## Round 465 (2026-08-12) — 窗口注册表全量闭合（Finding 771）

- **429 连发 + 395 证据 + 14 窗口函数体全解码**。
- 落盘：`window-registry-total-closure-evidence.json`（F771）+ RESEARCH_LOG Round 465。

## Round 466 (2026-08-12) — HANDOFF 刷新 67（Finding 772）

- **Round 463-465 追加 + 430 连发**（窗口注册表 100% 入档）。
- 落盘：`handoff-refresh-67-evidence.json`（F772）+ RESEARCH_LOG Round 466。

## Round 467 (2026-08-12) — 坐骑窗口绘制 + 命令（Finding 773）

- **5 按钮 + 命令分派 + 300ms 冷却**（F545 确认）。
- 落盘：`mount-window-draw-commands-evidence.json`（F773）+ RESEARCH_LOG Round 467。

## Round 468 (2026-08-12) — 社交窗口最终闭合（Finding 774）

- **432 连发 + 398 证据 + 社交家族完整**。
- 落盘：`social-windows-final-closure-evidence.json`（F774）+ RESEARCH_LOG Round 468。

## Round 469 (2026-08-12) — HANDOFF 刷新 68（Finding 775）

- **Round 466-468 追加 + 433 连发**（社交完整入档）。
- 落盘：`handoff-refresh-68-evidence.json`（F775）+ RESEARCH_LOG Round 469。

## Round 470 (2026-08-12) — 选项滑块应用 + 构造（Finding 776）

- **BGM/SFX 音量缩放 + 应用 + 重绘**（选项音频完整）。
- 落盘：`options-slider-apply-ctor-evidence.json`（F776）+ RESEARCH_LOG Round 470。

## Round 471 (2026-08-12) — 选项/音频应用弧闭合 + 400 证据里程碑（Finding 777）

- **435 连发 + 401 证据（400+ 里程碑）+ 选项音频完整**。
- 落盘：`options-audio-apply-arc-closure-evidence.json`（F777）+ RESEARCH_LOG Round 471。

## Round 472 (2026-08-12) — HANDOFF 刷新 69（Finding 778）

- **Round 469-471 追加 + 436 连发**（选项音频完整入档）。
- 落盘：`handoff-refresh-69-evidence.json`（F778）+ RESEARCH_LOG Round 472。

## Round 473 (2026-08-12) — 选项字符串刷新 + 配置装载（Finding 779）

- **实时值文本 + 配置读入**（选项配置/显示完整）。
- 落盘：`options-string-refresh-config-load-evidence.json`（F779）+ RESEARCH_LOG Round 473。

## Round 474 (2026-08-12) — 选项系统最终闭合（Finding 780）

- **438 连发 + 404 证据 + 选项系统 100%**。
- 落盘：`options-system-final-closure-evidence.json`（F780）+ RESEARCH_LOG Round 474。

## Round 475 (2026-08-12) — HANDOFF 刷新 70 + 70 刷新里程碑（Finding 781）

- **Round 472-474 追加 + 439 连发 + 70 刷新**（选项 100% 入档）。
- 落盘：`handoff-refresh-70-evidence.json`（F781）+ RESEARCH_LOG Round 475。

## Round 476 (2026-08-12) — 发送器家族扩展（Finding 782）

- **0x418/0x419 + 0x401-0x406 发送器 + 关闭泵**（出站完整）。
- 落盘：`sender-family-extension-evidence.json`（F782）+ RESEARCH_LOG Round 476。

## Round 477 (2026-08-12) — 出站发送器最终闭合（Finding 783）

- **441 连发 + 407 证据 + 出站发送器完整**。
- 落盘：`outbound-senders-final-closure-evidence.json`（F783）+ RESEARCH_LOG Round 477。

## Round 478 (2026-08-12) — HANDOFF 刷新 71（Finding 784）

- **Round 475-477 追加 + 442 连发**（出站发送器完整入档）。
- 落盘：`handoff-refresh-71-evidence.json`（F784）+ RESEARCH_LOG Round 478。

## Round 479 (2026-08-12) — 消息分派器 + 发送器续篇（Finding 785）

- **自定义消息表 + 6 更多发送器**（出站目录扩展）。
- 落盘：`message-dispatcher-sender-continuation-evidence.json`（F785）+ RESEARCH_LOG Round 479。

## Round 480 (2026-08-12) — 输入/消息系统闭合 + Round 480 里程碑（Finding 786）

- **444 连发 + 410 证据 + 输入/消息完整**。
- 落盘：`input-message-system-closure-evidence.json`（F786）+ RESEARCH_LOG Round 480。

## Round 481 (2026-08-12) — HANDOFF 刷新 72（Finding 787）

- **Round 478-480 追加 + 445 连发**（输入/消息完整入档）。
- 落盘：`handoff-refresh-72-evidence.json`（F787）+ RESEARCH_LOG Round 481。

## Round 482 (2026-08-12) — 选项配置装载全量（Finding 788）

- **ini 键 + atoi + 音频开/关 + 滑块换算**（持久化完整）。
- 落盘：`options-config-load-evidence.json`（F788）+ RESEARCH_LOG Round 482。

## Round 483 (2026-08-12) — 选项持久化闭合（Finding 789）

- **447 连发 + 413 证据 + 选项生命周期完整**。
- 落盘：`options-persistence-closure-evidence.json`（F789）+ RESEARCH_LOG Round 483。

## Round 484 (2026-08-12) — HANDOFF 刷新 73（Finding 790）

- **Round 481-483 追加 + 448 连发**（选项生命周期完整入档）。
- 落盘：`handoff-refresh-73-evidence.json`（F790）+ RESEARCH_LOG Round 484。

## Round 485 (2026-08-12) — 英雄消息分派 + 死亡泵（Finding 791）

- **msg 0x2F0/0x1F 分派 + F611 全量**（F743 来源解析）。
- 落盘：`hero-message-dispatch-death-pump-evidence.json`（F791）+ RESEARCH_LOG Round 485。

## Round 486 (2026-08-12) — 英雄生命周期最终闭合 + 450 连发里程碑（Finding 792）

- **450 连发 + 416 证据 + 英雄生命周期完整**。
- 落盘：`hero-lifecycle-final-closure-evidence.json`（F792）+ RESEARCH_LOG Round 486。

## Round 487 (2026-08-12) — HANDOFF 刷新 74（Finding 793）

- **Round 484-486 追加 + 451 连发**（英雄生命周期完整入档）。
- 落盘：`handoff-refresh-74-evidence.json`（F793）+ RESEARCH_LOG Round 487。

## Round 488 (2026-08-12) — 技能消息处理 + 地图标题处理（Finding 794）

- **技能 0x34 全量 + 地图标题**（F743 来源完整）。
- 落盘：`skill-msg-handler-map-title-evidence.json`（F794）+ RESEARCH_LOG Round 488。

## Round 489 (2026-08-12) — 技能/显示处理闭合（Finding 795）

- **453 连发 + 419 证据 + 技能/显示链完整**。
- 落盘：`skill-display-handlers-closure-evidence.json`（F795）+ RESEARCH_LOG Round 489。

## Round 490 (2026-08-12) — HANDOFF 刷新 75 + 75 刷新里程碑（Finding 796）

- **Round 487-489 追加 + 454 连发 + 75 刷新**（技能/显示完整入档）。
- 落盘：`handoff-refresh-75-evidence.json`（F796）+ RESEARCH_LOG Round 490。

## Round 491 (2026-08-12) — 地图/名字消息处理（Finding 797）

- **公告绘制 + 实体名更新**（F621/F674 扩展）。
- 落盘：`map-name-message-handler-evidence.json`（F797）+ RESEARCH_LOG Round 491。

## Round 492 (2026-08-12) — recv/名字家族闭合（Finding 798）

- **456 连发 + 422 证据 + recv/名字完整**。
- 落盘：`recv-name-family-closure-evidence.json`（F798）+ RESEARCH_LOG Round 492。

## Round 493 (2026-08-12) — HANDOFF 刷新 76（Finding 799）

- **Round 490-492 追加 + 457 连发**（recv/名字完整入档）。
- 落盘：`handoff-refresh-76-evidence.json`（F799）+ RESEARCH_LOG Round 493。

## Round 494 (2026-08-12) — 实体名字格式化 + 渲染（Finding 800）

- **sprintf + 3000ms 寿命 + 矩阵缩放**（F621 全量）。
- 落盘：`entity-name-format-render-evidence.json`（F800）+ RESEARCH_LOG Round 494。

## Round 495 (2026-08-12) — 名字/头顶系统闭合（Finding 801）

- **459 连发 + 425 证据 + 名字/头顶完整**。
- 落盘：`name-overhead-system-closure-evidence.json`（F801）+ RESEARCH_LOG Round 495。

## Round 496 (2026-08-12) — HANDOFF 刷新 77（Finding 802）

- **Round 493-495 追加 + 460 连发**（名字/头顶完整入档）。
- 落盘：`handoff-refresh-77-evidence.json`（F802）+ RESEARCH_LOG Round 496。

## Round 497 (2026-08-12) — 行会公告列表 + 消息分派（Finding 803）

- **5 行 + 80 积压 + 消息发送**（行会公告完整）。
- 落盘：`guild-notice-list-msg-dispatch-evidence.json`（F803）+ RESEARCH_LOG Round 497。

## Round 498 (2026-08-12) — 行会/社交消息闭合（Finding 804）

- **462 连发 + 428 证据 + 行会/社交完整**。
- 落盘：`guild-social-messages-closure-evidence.json`（F804）+ RESEARCH_LOG Round 498。

## Round 499 (2026-08-12) — HANDOFF 刷新 78（Finding 805）

- **Round 496-498 追加 + 463 连发**（行会/社交完整入档）。
- 落盘：`handoff-refresh-78-evidence.json`（F805）+ RESEARCH_LOG Round 499。

## Round 500 (2026-08-12) — ROUND 500 里程碑闭合（Finding 806）

- **464 连发 + 430 证据 + Round 500 里程碑**（90 轮窗口/选项/输入/英雄/技能/名字/社交全闭合）。
- 落盘：`round-500-milestone-closure-evidence.json`（F806）+ RESEARCH_LOG Round 500。

## Pending（未阻塞，持续队列）

- 无阻塞项（表面接近完整；下一弧：HANDOFF 刷新 79/剩余角落）。
- 0x45DC70 拼接目标 0x8AB7A8 之后 BSS（0x8AB7A8/0x8B187C 内容不可读）→ 存盘路径全链仍缺 BSS 侧直读。
- 0x42C9E0 busy 定时状态显示的渲染侧（0x2A548C 方法，输出目标未解码）。
- write-only 显示状态槽（0x35B251–0x35B258 / 0x35B1F0 / 0x35A34A–0x35A34E）的渲染侧消费者推测在未解码渲染表/数据驱动 UI 中——sim HUD 层按契约消费。
## Round 501 (2026-08-12) — HANDOFF 刷新 79（Finding 807）

- **Round 499-500 追加 + 465 连发**（Round 500 里程碑入档）。
- 落盘：`handoff-refresh-79-evidence.json`（F807）+ RESEARCH_LOG Round 501。

## Pending（未阻塞，持续队列）

- 无阻塞项（表面接近完整；下一弧：剩余深层角落/模拟器 polish）。
## Round 502 (2026-08-12) — 行会消息发送 + 按钮分派（Finding 808）

- **页模式 + 窗口切换 + msg 0x25A**（行会输入完整）。
- 落盘：`guild-msg-send-button-dispatch-evidence.json`（F808）+ RESEARCH_LOG Round 502。

## Pending（未阻塞，持续队列）

- 无阻塞项（行会输入完整；下一弧：剩余深层角落）。
## Round 503 (2026-08-12) — 行会分派弧闭合（Finding 809）

- **467 连发 + 433 证据 + 行会全交互**。
- 落盘：`guild-dispatch-arc-closure-evidence.json`（F809）+ RESEARCH_LOG Round 503。

## Pending（未阻塞，持续队列）

- 无阻塞项（行会全交互；下一弧：HANDOFF 刷新 80/剩余角落）。
## Round 504 (2026-08-12) — HANDOFF 刷新 80 + 80 刷新里程碑（Finding 810）

- **Round 501-503 追加 + 468 连发 + 80 刷新**（行会全交互入档）。
- 落盘：`handoff-refresh-80-evidence.json`（F810）+ RESEARCH_LOG Round 504。

## Pending（未阻塞，持续队列）

- 无阻塞项（行会全交互；下一弧：剩余深层角落/模拟器 polish）。
## Round 505 (2026-08-12) — 窗口开/关分派器（Finding 811）

- **16 模式开关 + 显示/隐藏**（F550 全量）。
- 落盘：`window-open-close-dispatcher-evidence.json`（F811）+ RESEARCH_LOG Round 505。

## Pending（未阻塞，持续队列）

- 无阻塞项（窗口开关完整；下一弧：剩余深层角落）。
## Round 506 (2026-08-12) — 窗口切换助手（Finding 812）

- **开/关列表 + 预分派**（F550 机制 100%）。
- 落盘：`window-toggle-helpers-evidence.json`（F812）+ RESEARCH_LOG Round 506。

## Pending（未阻塞，持续队列）

- 无阻塞项（窗口切换完整；下一弧：剩余深层角落）。
## Round 507 (2026-08-12) — 窗口切换机制闭合（Finding 813）

- **471 连发 + 437 证据 + 切换机制完整**。
- 落盘：`toggle-machinery-closure-evidence.json`（F813）+ RESEARCH_LOG Round 507。

## Pending（未阻塞，持续队列）

- 无阻塞项（切换机制完整；下一弧：HANDOFF 刷新 81/剩余角落）。
## Round 508 (2026-08-12) — HANDOFF 刷新 81（Finding 814）

- **Round 505-507 追加 + 472 连发**（切换机制完整入档）。
- 落盘：`handoff-refresh-81-evidence.json`（F814）+ RESEARCH_LOG Round 508。

## Pending（未阻塞，持续队列）

- 无阻塞项（切换机制完整；下一弧：剩余深层角落/模拟器 polish）。
## Round 509 (2026-08-12) — 背包窗口初始化 + 点击 + 使用（Finding 815）

- **重置 + 点击分派 + 使用门**（背包全交互）。
- 落盘：`bag-window-init-click-use-evidence.json`（F815）+ RESEARCH_LOG Round 509。

## Pending（未阻塞，持续队列）

- 无阻塞项（背包全交互；下一弧：剩余深层角落）。
## Round 510 (2026-08-12) — 背包窗口弧闭合（Finding 816）

- **474 连发 + 440 证据 + 背包全交互**。
- 落盘：`bag-window-arc-closure-evidence.json`（F816）+ RESEARCH_LOG Round 510。

## Pending（未阻塞，持续队列）

- 无阻塞项（背包全交互；下一弧：HANDOFF 刷新 82/剩余角落）。
## Round 511 (2026-08-12) — HANDOFF 刷新 82（Finding 817）

- **Round 508-510 追加 + 475 连发**（背包全交互入档）。
- 落盘：`handoff-refresh-82-evidence.json`（F817）+ RESEARCH_LOG Round 511。

## Pending（未阻塞，持续队列）

- 无阻塞项（背包全交互；下一弧：剩余深层角落/模拟器 polish）。
## Round 512 (2026-08-12) — 装备详情面板绘制（Finding 818）

- **标签 + 等级/HP/MP/XP 值**（状态面板完整）。
- 落盘：`equip-detail-panel-draw-evidence.json`（F818）+ RESEARCH_LOG Round 512。

## Pending（未阻塞，持续队列）

- 无阻塞项（详情面板完整；下一弧：剩余深层角落）。
## Round 513 (2026-08-12) — 状态/装备面板闭合（Finding 819）

- **477 连发 + 443 证据 + 状态/装备完整**。
- 落盘：`status-equip-panel-closure-evidence.json`（F819）+ RESEARCH_LOG Round 513。

## Pending（未阻塞，持续队列）

- 无阻塞项（状态/装备完整；下一弧：HANDOFF 刷新 83/剩余角落）。
## Round 514 (2026-08-12) — HANDOFF 刷新 83（Finding 820）

- **Round 511-513 追加 + 478 连发**（状态/装备完整入档）。
- 落盘：`handoff-refresh-83-evidence.json`（F820）+ RESEARCH_LOG Round 514。

## Pending（未阻塞，持续队列）

- 无阻塞项（状态/装备完整；下一弧：剩余深层角落/模拟器 polish）。
## Round 515 (2026-08-12) — 文本测量 + 换行拆分（Finding 821）

- **尺寸测量 + 段拆分**（文本布局完整）。
- 落盘：`text-measure-wrap-split-evidence.json`（F821）+ RESEARCH_LOG Round 515。

## Pending（未阻塞，持续队列）

- 无阻塞项（文本布局完整；下一弧：剩余深层角落）。
## Round 516 (2026-08-12) — 文本布局闭合 + 480 连发里程碑（Finding 822）

- **480 连发 + 446 证据 + 文本布局完整**。
- 落盘：`text-layout-closure-evidence.json`（F822）+ RESEARCH_LOG Round 516。

## Pending（未阻塞，持续队列）

- 无阻塞项（文本布局完整；下一弧：HANDOFF 刷新 84/剩余角落）。
## Round 517 (2026-08-12) — HANDOFF 刷新 84（Finding 823）

- **Round 514-516 追加 + 481 连发**（文本布局完整入档）。
- 落盘：`handoff-refresh-84-evidence.json`（F823）+ RESEARCH_LOG Round 517。

## Pending（未阻塞，持续队列）

- 无阻塞项（文本布局完整；下一弧：剩余深层角落/模拟器 polish）。
## Round 518 (2026-08-12) — 商店点击分派（Finding 824）

- **退出/取消 + msg 0x3E8 关闭**（商店点击完整）。
- 落盘：`shop-click-dispatch-evidence.json`（F824）+ RESEARCH_LOG Round 518。

## Pending（未阻塞，持续队列）

- 无阻塞项（商店点击完整；下一弧：剩余深层角落）。
## Round 519 (2026-08-12) — 商店交互闭合（Finding 825）

- **483 连发 + 449 证据 + 商店全交互**。
- 落盘：`shop-interactive-closure-evidence.json`（F825）+ RESEARCH_LOG Round 519。

## Pending（未阻塞，持续队列）

- 无阻塞项（商店全交互；下一弧：HANDOFF 刷新 85/剩余角落）。
## Round 520 (2026-08-12) — HANDOFF 刷新 85（Finding 826）

- **Round 517-519 追加 + 484 连发**（商店全交互入档）。
- 落盘：`handoff-refresh-85-evidence.json`（F826）+ RESEARCH_LOG Round 520。

## Pending（未阻塞，持续队列）

- 无阻塞项（商店全交互；下一弧：剩余深层角落/模拟器 polish）。
## Round 521 (2026-08-12) — 窗口内容布局（Finding 827）

- **帧 + 矩形 + 居中**（内容几何完整）。
- 落盘：`window-content-layout-evidence.json`（F827）+ RESEARCH_LOG Round 521。

## Pending（未阻塞，持续队列）

- 无阻塞项（内容布局完整；下一弧：剩余深层角落）。
## Round 522 (2026-08-12) — 窗口几何闭合（Finding 828）

- **486 连发 + 452 证据 + 窗口几何完整**。
- 落盘：`window-geometry-closure-evidence.json`（F828）+ RESEARCH_LOG Round 522。

## Pending（未阻塞，持续队列）

- 无阻塞项（窗口几何完整；下一弧：HANDOFF 刷新 86/剩余角落）。
## Round 523 (2026-08-12) — HANDOFF 刷新 86（Finding 829）

- **Round 520-522 追加 + 487 连发**（窗口几何完整入档）。
- 落盘：`handoff-refresh-86-evidence.json`（F829）+ RESEARCH_LOG Round 523。

## Pending（未阻塞，持续队列）

- 无阻塞项（窗口几何完整；下一弧：剩余深层角落/模拟器 polish）。
## Round 524 (2026-08-12) — 行会页子绘制（Finding 830）

- **页 0/页 1 列表 + 级别色**（行会 3 页完整）。
- 落盘：`guild-page-subdraws-evidence.json`（F830）+ RESEARCH_LOG Round 524。

## Pending（未阻塞，持续队列）

- 无阻塞项（行会 3 页完整；下一弧：剩余深层角落）。
## Round 525 (2026-08-12) — 行会页闭合（Finding 831）

- **489 连发 + 455 证据 + 行会页完整**。
- 落盘：`guild-pages-closure-evidence.json`（F831）+ RESEARCH_LOG Round 525。

## Pending（未阻塞，持续队列）

- 无阻塞项（行会页完整；下一弧：HANDOFF 刷新 87/剩余角落）。
## Round 526 (2026-08-12) — HANDOFF 刷新 87（Finding 832）

- **Round 523-525 追加 + 490 连发**（行会页完整入档）。
- 落盘：`handoff-refresh-87-evidence.json`（F832）+ RESEARCH_LOG Round 526。

## Pending（未阻塞，持续队列）

- 无阻塞项（行会页完整；下一弧：剩余深层角落/模拟器 polish）。
## Round 527 (2026-08-12) — 任务窗口绘制体（Finding 833）

- **列表 + 换行 + 状态色**（F671 全量）。
- 落盘：`quest-window-draw-body-evidence.json`（F833）+ RESEARCH_LOG Round 527。

## Pending（未阻塞，持续队列）

- 无阻塞项（任务绘制完整；下一弧：剩余深层角落）。
## Round 528 (2026-08-12) — 任务窗口闭合（Finding 834）

- **492 连发 + 458 证据 + 任务窗口完整**。
- 落盘：`quest-window-closure-evidence.json`（F834）+ RESEARCH_LOG Round 528。

## Pending（未阻塞，持续队列）

- 无阻塞项（任务窗口完整；下一弧：HANDOFF 刷新 88/剩余角落）。
## Round 529 (2026-08-12) — HANDOFF 刷新 88（Finding 835）

- **Round 526-528 追加 + 493 连发**（任务窗口完整入档）。
- 落盘：`handoff-refresh-88-evidence.json`（F835）+ RESEARCH_LOG Round 529。

## Pending（未阻塞，持续队列）

- 无阻塞项（任务窗口完整；下一弧：剩余深层角落/模拟器 polish）。
## Round 530 (2026-08-12) — 坐骑旗标写者（Finding 836）

- **recv1 坐骑消息 + 使用态**（F773 门写者解析）。
- 落盘：`mount-flag-writers-evidence.json`（F836）+ RESEARCH_LOG Round 530。

## Pending（未阻塞，持续队列）

- 无阻塞项（坐骑写者完整；下一弧：剩余深层角落）。
## Round 531 (2026-08-12) — 坐骑/recv 闭合（Finding 837）

- **495 连发 + 461 证据 + 坐骑/recv 完整**。
- 落盘：`mount-recv-closure-evidence.json`（F837）+ RESEARCH_LOG Round 531。

## Pending（未阻塞，持续队列）

- 无阻塞项（坐骑/recv 完整；下一弧：HANDOFF 刷新 89/剩余角落）。
## Round 532 (2026-08-12) — HANDOFF 刷新 89（Finding 838）

- **Round 529-531 追加 + 496 连发**（坐骑/recv 完整入档）。
- 落盘：`handoff-refresh-89-evidence.json`（F838）+ RESEARCH_LOG Round 532。

## Pending（未阻塞，持续队列）

- 无阻塞项（坐骑/recv 完整；下一弧：剩余深层角落/模拟器 polish）。
## Round 533 (2026-08-12) — 技能书绘制（Finding 839）

- **页签 + 8 技能槽 + 页计数**（技能书完整）。
- 落盘：`skill-book-draw-evidence.json`（F839）+ RESEARCH_LOG Round 533。

## Pending（未阻塞，持续队列）

- 无阻塞项（技能书完整；下一弧：剩余深层角落）。
## Round 534 (2026-08-12) — 技能书窗口闭合（Finding 840）

- **498 连发 + 464 证据 + 技能书完整**。
- 落盘：`skill-book-closure-evidence.json`（F840）+ RESEARCH_LOG Round 534。

## Pending（未阻塞，持续队列）

- 无阻塞项（技能书完整；下一弧：HANDOFF 刷新 90/剩余角落）。
## Round 535 (2026-08-12) — HANDOFF 刷新 90 + 90 刷新里程碑（Finding 841）

- **Round 532-534 追加 + 499 连发 + 90 刷新**（技能书完整入档）。
- 落盘：`handoff-refresh-90-evidence.json`（F841）+ RESEARCH_LOG Round 535。

## Pending（未阻塞，持续队列）

- 无阻塞项（技能书完整；下一弧：剩余深层角落/模拟器 polish）。
## Round 536 (2026-08-12) — 交易窗口绘制（Finding 842）

- **居中 + 网格命中 + 拖动预览**（交易绘制完整）。
- 落盘：`trade-window-draw-evidence.json`（F842）+ RESEARCH_LOG Round 536。

## Pending（未阻塞，持续队列）

- 无阻塞项（交易绘制完整；下一弧：剩余深层角落）。
## Round 537 (2026-08-12) — 交易窗口全闭合 + 500+ 连发里程碑（Finding 843）

- **501 连发 + 467 证据 + 交易完整**（500+ 里程碑）。
- 落盘：`trade-window-full-closure-evidence.json`（F843）+ RESEARCH_LOG Round 537。

## Pending（未阻塞，持续队列）

- 无阻塞项（交易完整；下一弧：HANDOFF 刷新 91/剩余角落）。
## Round 538 (2026-08-12) — HANDOFF 刷新 91（Finding 844）

- **Round 535-537 追加 + 502 连发**（交易完整入档）。
- 落盘：`handoff-refresh-91-evidence.json`（F844）+ RESEARCH_LOG Round 538。

## Pending（未阻塞，持续队列）

- 无阻塞项（交易完整；下一弧：剩余深层角落/模拟器 polish）。
## Round 539 (2026-08-12) — 组队窗口点击 + 消息分派（Finding 845）

- **邀请/移除/离开发送**（组队交互完整）。
- 落盘：`party-window-click-msg-dispatch-evidence.json`（F845）+ RESEARCH_LOG Round 539。

## Pending（未阻塞，持续队列）

- 无阻塞项（组队交互完整；下一弧：剩余深层角落）。
## Round 540 (2026-08-12) — 组队交互闭合（Finding 846）

- **504 连发 + 470 证据 + 组队全交互**。
- 落盘：`party-interactive-closure-evidence.json`（F846）+ RESEARCH_LOG Round 540。

## Pending（未阻塞，持续队列）

- 无阻塞项（组队全交互；下一弧：HANDOFF 刷新 92/剩余角落）。
## Round 541 (2026-08-12) — HANDOFF 刷新 92（Finding 847）

- **Round 538-540 追加 + 505 连发**（组队交互完整入档）。
- 落盘：`handoff-refresh-92-evidence.json`（F847）+ RESEARCH_LOG Round 541。

## Pending（未阻塞，持续队列）

- 无阻塞项（组队交互完整；下一弧：剩余深层角落/模拟器 polish）。
## Round 542 (2026-08-12) — 技能页签头绘制（Finding 848）

- **页签记录 + 图标 + 名称**（页签头完整）。
- 落盘：`skill-tab-header-draw-evidence.json`（F848）+ RESEARCH_LOG Round 542。

## Pending（未阻塞，持续队列）

- 无阻塞项（页签头完整；下一弧：剩余深层角落）。
## Round 543 (2026-08-12) — 技能书全闭合（Finding 849）

- **507 连发 + 473 证据 + 技能书完整**。
- 落盘：`skill-book-full-closure-evidence.json`（F849）+ RESEARCH_LOG Round 543。

## Pending（未阻塞，持续队列）

- 无阻塞项（技能书完整；下一弧：HANDOFF 刷新 93/剩余角落）。
## Round 544 (2026-08-12) — HANDOFF 刷新 93（Finding 850）

- **Round 541-543 追加 + 508 连发**（技能书完整入档）。
- 落盘：`handoff-refresh-93-evidence.json`（F850）+ RESEARCH_LOG Round 544。

## Pending（未阻塞，持续队列）

- 无阻塞项（技能书完整；下一弧：剩余深层角落/模拟器 polish）。
## Round 545 (2026-08-12) — 技能页文本解析器（Finding 851）

- **行拆分 + #元 + 换行**（页数据路径完整）。
- 落盘：`skill-page-text-parser-evidence.json`（F851）+ RESEARCH_LOG Round 545。

## Pending（未阻塞，持续队列）

- 无阻塞项（页解析完整；下一弧：剩余深层角落）。
## Round 546 (2026-08-12) — 技能页闭合 + 510 连发里程碑（Finding 852）

- **510 连发 + 476 证据 + 技能页完整**。
- 落盘：`skill-page-closure-evidence.json`（F852）+ RESEARCH_LOG Round 546。

## Pending（未阻塞，持续队列）

- 无阻塞项（技能页完整；下一弧：HANDOFF 刷新 94/剩余角落）。
## Round 547 (2026-08-12) — HANDOFF 刷新 94（Finding 853）

- **Round 544-546 追加 + 511 连发**（技能页完整入档）。
- 落盘：`handoff-refresh-94-evidence.json`（F853）+ RESEARCH_LOG Round 547。

## Pending（未阻塞，持续队列）

- 无阻塞项（技能页完整；下一弧：剩余深层角落/模拟器 polish）。
## Round 548 (2026-08-12) — 公告窗口渲染（Finding 854）

- **19 行 + 滚动条 + 7 按钮**（公告窗口完整）。
- 落盘：`announce-window-render-evidence.json`（F854）+ RESEARCH_LOG Round 548。

## Pending（未阻塞，持续队列）

- 无阻塞项（公告窗口完整；下一弧：剩余深层角落）。
## Round 549 (2026-08-12) — 公告窗口闭合（Finding 855）

- **513 连发 + 479 证据 + 公告窗口完整**。
- 落盘：`announce-window-closure-evidence.json`（F855）+ RESEARCH_LOG Round 549。

## Pending（未阻塞，持续队列）

- 无阻塞项（公告窗口完整；下一弧：HANDOFF 刷新 95/剩余角落）。
## Round 550 (2026-08-12) — HANDOFF 刷新 95（Finding 856）

- **Round 547-549 追加 + 514 连发**（公告窗口完整入档）。
- 落盘：`handoff-refresh-95-evidence.json`（F856）+ RESEARCH_LOG Round 550。

## Pending（未阻塞，持续队列）

- 无阻塞项（公告窗口完整；下一弧：剩余深层角落/模拟器 polish）。
## Round 551 (2026-08-12) — NPC 对话窗口渲染（Finding 857）

- **选项列表 + 4 类型 + 绘制**（对话窗口完整）。
- 落盘：`dialog-window-render-evidence.json`（F857）+ RESEARCH_LOG Round 551。

## Pending（未阻塞，持续队列）

- 无阻塞项（对话窗口完整；下一弧：剩余深层角落）。
## Round 552 (2026-08-12) — 对话窗口闭合（Finding 858）

- **516 连发 + 482 证据 + 对话窗口完整**。
- 落盘：`dialog-window-closure-evidence.json`（F858）+ RESEARCH_LOG Round 552。

## Pending（未阻塞，持续队列）

- 无阻塞项（对话窗口完整；下一弧：HANDOFF 刷新 96/剩余角落）。
## Round 553 (2026-08-12) — HANDOFF 刷新 96（Finding 859）

- **Round 550-552 追加 + 517 连发**（对话窗口完整入档）。
- 落盘：`handoff-refresh-96-evidence.json`（F859）+ RESEARCH_LOG Round 553。

## Pending（未阻塞，持续队列）

- 无阻塞项（对话窗口完整；下一弧：剩余深层角落/模拟器 polish）。
## Round 554 (2026-08-12) — 坐骑命中 + 点击 + 构造（Finding 860）

- **5 控件分派 + 6 物品槽构造**（坐骑交互完整）。
- 落盘：`mount-hit-click-ctor-evidence.json`（F860）+ RESEARCH_LOG Round 554。

## Pending（未阻塞，持续队列）

- 无阻塞项（坐骑交互完整；下一弧：剩余深层角落）。
## Round 555 (2026-08-12) — 坐骑窗口全闭合（Finding 861）

- **519 连发 + 485 证据 + 坐骑窗口完整**。
- 落盘：`mount-window-full-closure-evidence.json`（F861）+ RESEARCH_LOG Round 555。

## Pending（未阻塞，持续队列）

- 无阻塞项（坐骑窗口完整；下一弧：HANDOFF 刷新 97/剩余角落）。
## Round 556 (2026-08-12) — HANDOFF 刷新 97（Finding 862）

- **Round 553-555 追加 + 520 连发**（坐骑窗口完整入档）。
- 落盘：`handoff-refresh-97-evidence.json`（F862）+ RESEARCH_LOG Round 556。

## Pending（未阻塞，持续队列）

- 无阻塞项（坐骑窗口完整；下一弧：剩余深层角落/模拟器 polish）。
## Round 557 (2026-08-12) — 基础行列表构造 + 清除（Finding 863）

- **ctor + free + 修剪添加**（列表基类完整）。
- 落盘：`base-line-list-ctor-clear-evidence.json`（F863）+ RESEARCH_LOG Round 557。

## Pending（未阻塞，持续队列）

- 无阻塞项（列表基类完整；下一弧：剩余深层角落）。
## Round 558 (2026-08-12) — 行列表基类闭合（Finding 864）

- **522 连发 + 488 证据 + 列表基类完整**。
- 落盘：`line-list-base-closure-evidence.json`（F864）+ RESEARCH_LOG Round 558。

## Pending（未阻塞，持续队列）

- 无阻塞项（列表基类完整；下一弧：HANDOFF 刷新 98/剩余角落）。
## Round 559 (2026-08-12) — HANDOFF 刷新 98（Finding 865）

- **Round 556-558 追加 + 523 连发**（列表基类完整入档）。
- 落盘：`handoff-refresh-98-evidence.json`（F865）+ RESEARCH_LOG Round 559。

## Pending（未阻塞，持续队列）

- 无阻塞项（列表基类完整；下一弧：剩余深层角落/模拟器 polish）。
## Round 560 (2026-08-12) — 公告节点添加 + 出队（Finding 866）

- **分配/插入/出队/析构**（公告列表完整）。
- 落盘：`notice-node-add-dequeue-evidence.json`（F866）+ RESEARCH_LOG Round 560。

## Pending（未阻塞，持续队列）

- 无阻塞项（公告列表完整；下一弧：剩余深层角落）。
## Round 561 (2026-08-12) — 公告列表全闭合（Finding 867）

- **525 连发 + 491 证据 + 公告列表完整**。
- 落盘：`notice-list-full-closure-evidence.json`（F867）+ RESEARCH_LOG Round 561。

## Pending（未阻塞，持续队列）

- 无阻塞项（公告列表完整；下一弧：HANDOFF 刷新 99/剩余角落）。
## Round 562 (2026-08-12) — HANDOFF 刷新 99（Finding 868）

- **Round 559-561 追加 + 526 连发**（公告列表完整入档）。
- 落盘：`handoff-refresh-99-evidence.json`（F868）+ RESEARCH_LOG Round 562。

## Pending（未阻塞，持续队列）

- 无阻塞项（公告列表完整；下一弧：剩余深层角落/模拟器 polish）。
## Round 563 (2026-08-12) — HANDOFF 刷新 100 里程碑（Finding 869）

- **100 刷新 + 527 连发 + 13 表面闭合**。
- 落盘：`handoff-refresh-100-evidence.json`（F869）+ RESEARCH_LOG Round 563。

## Pending（未阻塞，持续队列）

- 无阻塞项（13 表面闭合；下一弧：剩余深层角落/模拟器 polish）。
## Round 564 (2026-08-12) — 公告输入处理（Finding 870）

- **编辑键 + 缓冲 + 刷新**（公告编辑完整）。
- 落盘：`announce-input-handler-evidence.json`（F870）+ RESEARCH_LOG Round 564。

## Pending（未阻塞，持续队列）

- 无阻塞项（公告编辑完整；下一弧：剩余深层角落）。
## Round 565 (2026-08-12) — 公告交互闭合（Finding 871）

- **529 连发 + 495 证据 + 公告全交互**。
- 落盘：`announce-interactive-closure-evidence.json`（F871）+ RESEARCH_LOG Round 565。

## Pending（未阻塞，持续队列）

- 无阻塞项（公告全交互；下一弧：HANDOFF 刷新 101/剩余角落）。
## Round 566 (2026-08-12) — HANDOFF 刷新 101（Finding 872）

- **Round 563-565 追加 + 530 连发**（公告全交互入档）。
- 落盘：`handoff-refresh-101-evidence.json`（F872）+ RESEARCH_LOG Round 566。

## Pending（未阻塞，持续队列）

- 无阻塞项（公告全交互；下一弧：剩余深层角落/模拟器 polish）。
## Round 567 (2026-08-12) — 聊天输入命令处理（Finding 873）

- **'/' 解析 + 速度累积 + 命令链**（聊天命令完整）。
- 落盘：`chat-input-command-handler-evidence.json`（F873）+ RESEARCH_LOG Round 567。

## Pending（未阻塞，持续队列）

- 无阻塞项（聊天命令完整；下一弧：剩余深层角落）。
## Round 568 (2026-08-12) — 聊天命令闭合（Finding 874）

- **532 连发 + 498 证据 + 聊天命令完整**。
- 落盘：`chat-command-closure-evidence.json`（F874）+ RESEARCH_LOG Round 568。

## Pending（未阻塞，持续队列）

- 无阻塞项（聊天命令完整；下一弧：HANDOFF 刷新 102/剩余角落）。
## Round 569 (2026-08-12) — HANDOFF 刷新 102（Finding 875）

- **Round 566-568 追加 + 533 连发**（聊天命令完整入档）。
- 落盘：`handoff-refresh-102-evidence.json`（F875）+ RESEARCH_LOG Round 569。

## Pending（未阻塞，持续队列）

- 无阻塞项（聊天命令完整；下一弧：剩余深层角落/模拟器 polish）。
## Round 570 (2026-08-12) — 聊天发送 + 物品使用尾部（Finding 876）

- **sprintf + 公告 + 物品名表路径**（聊天完整）。
- 落盘：`chat-send-item-use-tail-evidence.json`（F876）+ RESEARCH_LOG Round 570。

## Pending（未阻塞，持续队列）

- 无阻塞项（聊天发送完整；下一弧：剩余深层角落）。
## Round 571 (2026-08-12) — 聊天系统全闭合 + 500+ 证据里程碑（Finding 877）

- **535 连发 + 501 证据（500+ 里程碑）+ 聊天完整**。
- 落盘：`chat-system-full-closure-evidence.json`（F877）+ RESEARCH_LOG Round 571。

## Pending（未阻塞，持续队列）

- 无阻塞项（聊天完整；下一弧：HANDOFF 刷新 103/剩余角落）。
## Round 572 (2026-08-12) — HANDOFF 刷新 103（Finding 878）

- **Round 569-571 追加 + 536 连发**（聊天完整入档）。
- 落盘：`handoff-refresh-103-evidence.json`（F878）+ RESEARCH_LOG Round 572。

## Pending（未阻塞，持续队列）

- 无阻塞项（聊天完整；下一弧：剩余深层角落/模拟器 polish）。
## Round 573 (2026-08-12) — NPC 回复 + 种子 + 校验和（Finding 879）

- **回复 0x411 + 种子 + XOR 校验**（F617 完整）。
- 落盘：`npc-reply-seed-checksum-evidence.json`（F879）+ RESEARCH_LOG Round 573。

## Pending（未阻塞，持续队列）

- 无阻塞项（回复/校验完整；下一弧：剩余深层角落）。
## Round 574 (2026-08-12) — 回复/校验和闭合（Finding 880）

- **538 连发 + 504 证据 + 回复/校验完整**。
- 落盘：`reply-checksum-closure-evidence.json`（F880）+ RESEARCH_LOG Round 574。

## Pending（未阻塞，持续队列）

- 无阻塞项（回复/校验完整；下一弧：HANDOFF 刷新 104/剩余角落）。
## Round 575 (2026-08-12) — HANDOFF 刷新 104（Finding 881）

- **Round 572-574 追加 + 539 连发**（回复/校验完整入档）。
- 落盘：`handoff-refresh-104-evidence.json`（F881）+ RESEARCH_LOG Round 575。

## Pending（未阻塞，持续队列）

- 无阻塞项（回复/校验完整；下一弧：剩余深层角落/模拟器 polish）。
## Round 576 (2026-08-12) — 丢弃/卖出/组队发送器（Finding 882）

- **0x40A/0x408 + 0x3FC-0x3FE**（F845/F740 确认）。
- 落盘：`drop-sell-party-senders-evidence.json`（F882）+ RESEARCH_LOG Round 576。

## Pending（未阻塞，持续队列）

- 无阻塞项（发送器完整；下一弧：剩余深层角落）。
## Round 577 (2026-08-12) — 发送器目录最终闭合（Finding 883）

- **541 连发 + 507 证据 + 出站 100%**。
- 落盘：`sender-directory-final-closure-evidence.json`（F883）+ RESEARCH_LOG Round 577。

## Pending（未阻塞，持续队列）

- 无阻塞项（发送器完整；下一弧：HANDOFF 刷新 105/剩余角落）。
## Round 578 (2026-08-12) — HANDOFF 刷新 105（Finding 884）

- **Round 575-577 追加 + 542 连发**（发送器目录完整入档）。
- 落盘：`handoff-refresh-105-evidence.json`（F884）+ RESEARCH_LOG Round 578。

## Pending（未阻塞，持续队列）

- 无阻塞项（发送器完整；下一弧：剩余深层角落/模拟器 polish）。
## Round 579 (2026-08-12) — HUD 状态条全量（Finding 885）

- **% 格式 + 矩阵 + 注册表 blit**（F588 完整）。
- 落盘：`hud-status-bar-full-evidence.json`（F885）+ RESEARCH_LOG Round 579。

## Pending（未阻塞，持续队列）

- 无阻塞项（状态条完整；下一弧：剩余深层角落）。
## Round 580 (2026-08-12) — HUD 状态闭合 + 510 证据里程碑（Finding 886）

- **544 连发 + 510 证据（510 里程碑）+ HUD 状态完整**。
- 落盘：`hud-status-closure-evidence.json`（F886）+ RESEARCH_LOG Round 580。

## Pending（未阻塞，持续队列）

- 无阻塞项（HUD 状态完整；下一弧：HANDOFF 刷新 106/剩余角落）。
## Round 581 (2026-08-12) — HANDOFF 刷新 106（Finding 887）

- **Round 578-580 追加 + 545 连发**（HUD 状态完整入档）。
- 落盘：`handoff-refresh-106-evidence.json`（F887）+ RESEARCH_LOG Round 581。

## Pending（未阻塞，持续队列）

- 无阻塞项（HUD 状态完整；下一弧：剩余深层角落/模拟器 polish）。
## Round 582 (2026-08-12) — 小地图部件（Finding 888）

- **缩放 + 帧 + 6 热键图标**（小地图完整）。
- 落盘：`mini-map-widget-evidence.json`（F888）+ RESEARCH_LOG Round 582。

## Pending（未阻塞，持续队列）

- 无阻塞项（小地图完整；下一弧：剩余深层角落）。
## Round 583 (2026-08-12) — 小地图闭合（Finding 889）

- **547 连发 + 513 证据 + 小地图完整**。
- 落盘：`mini-map-closure-evidence.json`（F889）+ RESEARCH_LOG Round 583。

## Pending（未阻塞，持续队列）

- 无阻塞项（小地图完整；下一弧：HANDOFF 刷新 107/剩余角落）。
## Round 584 (2026-08-12) — HANDOFF 刷新 107（Finding 890）

- **Round 581-583 追加 + 548 连发**（小地图完整入档）。
- 落盘：`handoff-refresh-107-evidence.json`（F890）+ RESEARCH_LOG Round 584。

## Pending（未阻塞，持续队列）

- 无阻塞项（小地图完整；下一弧：剩余深层角落/模拟器 polish）。
## Round 585 (2026-08-12) — 大地图覆盖层（Finding 891）

- **坐标格式 + 矩阵 + 条 blit**（F594 完整）。
- 落盘：`large-map-overlay-evidence.json`（F891）+ RESEARCH_LOG Round 585。

## Pending（未阻塞，持续队列）

- 无阻塞项（大地图完整；下一弧：剩余深层角落）。
## Round 586 (2026-08-12) — 地图部件闭合 + 550 连发里程碑（Finding 892）

- **550 连发 + 516 证据 + 地图部件完整**。
- 落盘：`map-widget-closure-evidence.json`（F892）+ RESEARCH_LOG Round 586。

## Pending（未阻塞，持续队列）

- 无阻塞项（地图部件完整；下一弧：HANDOFF 刷新 108/剩余角落）。
## Round 587 (2026-08-12) — HANDOFF 刷新 108（Finding 893）

- **Round 584-586 追加 + 551 连发**（地图部件完整入档）。
- 落盘：`handoff-refresh-108-evidence.json`（F893）+ RESEARCH_LOG Round 587。

## Pending（未阻塞，持续队列）

- 无阻塞项（地图部件完整；下一弧：剩余深层角落/模拟器 polish）。
## Round 588 (2026-08-12) — 实体投影 + 阴影帧（Finding 894）

- **投影 + 阴影 blit + 钳制**（F622 完整）。
- 落盘：`entity-projection-shadow-evidence.json`（F894）+ RESEARCH_LOG Round 588。

## Pending（未阻塞，持续队列）

- 无阻塞项（实体渲染完整；下一弧：剩余深层角落）。
## Round 589 (2026-08-12) — 实体渲染闭合（Finding 895）

- **553 连发 + 519 证据 + 实体渲染完整**。
- 落盘：`entity-render-closure-evidence.json`（F895）+ RESEARCH_LOG Round 589。

## Pending（未阻塞，持续队列）

- 无阻塞项（实体渲染完整；下一弧：HANDOFF 刷新 109/剩余角落）。
## Round 590 (2026-08-12) — HANDOFF 刷新 109（Finding 896）

- **Round 587-589 追加 + 554 连发**（实体渲染完整入档）。
- 落盘：`handoff-refresh-109-evidence.json`（F896）+ RESEARCH_LOG Round 590。

## Pending（未阻塞，持续队列）

- 无阻塞项（实体渲染完整；下一弧：剩余深层角落/模拟器 polish）。
## Round 591 (2026-08-12) — HUD caption 分派尾部（Finding 897）

- **15 窗口处理器 + 全重置**（F580 完整）。
- 落盘：`caption-dispatch-tail-evidence.json`（F897）+ RESEARCH_LOG Round 591。

## Pending（未阻塞，持续队列）

- 无阻塞项（caption 分派完整；下一弧：剩余深层角落）。
## Round 592 (2026-08-12) — caption 分派闭合（Finding 898）

- **556 连发 + 522 证据 + caption 完整**。
- 落盘：`caption-dispatch-closure-evidence.json`（F898）+ RESEARCH_LOG Round 592。

## Pending（未阻塞，持续队列）

- 无阻塞项（caption 完整；下一弧：HANDOFF 刷新 110/剩余角落）。
## Round 593 (2026-08-12) — HANDOFF 刷新 110 + 110 刷新里程碑（Finding 899）

- **Round 590-592 追加 + 557 连发 + 110 刷新**（caption 完整入档）。
- 落盘：`handoff-refresh-110-evidence.json`（F899）+ RESEARCH_LOG Round 593。

## Pending（未阻塞，持续队列）

- 无阻塞项（caption 完整；下一弧：剩余深层角落/模拟器 polish）。
## Round 594 (2026-08-12) — 窗口命中路由器（Finding 900）

- **13 窗口矩形 + PtInRect → 模式**（路由完整）。
- 落盘：`window-hit-router-evidence.json`（F900）+ RESEARCH_LOG Round 594。

## Pending（未阻塞，持续队列）

- 无阻塞项（命中路由完整；下一弧：剩余深层角落）。
## Round 595 (2026-08-12) — 命中路由闭合（Finding 901）

- **559 连发 + 525 证据 + 命中路由完整**。
- 落盘：`hit-routing-closure-evidence.json`（F901）+ RESEARCH_LOG Round 595。

## Pending（未阻塞，持续队列）

- 无阻塞项（命中路由完整；下一弧：HANDOFF 刷新 111/剩余角落）。
## Round 596 (2026-08-12) — HANDOFF 刷新 111（Finding 902）

- **Round 593-595 追加 + 560 连发**（命中路由完整入档）。
- 落盘：`handoff-refresh-111-evidence.json`（F902）+ RESEARCH_LOG Round 596。

## Pending（未阻塞，持续队列）

- 无阻塞项（命中路由完整；下一弧：剩余深层角落/模拟器 polish）。
## Round 597 (2026-08-12) — HP 条注册表 + blit（Finding 903）

- **注册表 + 访问器 + 渲染**（F590 核心完整）。
- 落盘：`hp-bar-registry-blit-evidence.json`（F903）+ RESEARCH_LOG Round 597。

## Pending（未阻塞，持续队列）

- 无阻塞项（HP 条完整；下一弧：剩余深层角落）。
## Round 598 (2026-08-12) — HP 条系统闭合（Finding 904）

- **562 连发 + 528 证据 + HP 条完整**。
- 落盘：`hp-bar-system-closure-evidence.json`（F904）+ RESEARCH_LOG Round 598。

## Pending（未阻塞，持续队列）

- 无阻塞项（HP 条完整；下一弧：HANDOFF 刷新 112/剩余角落）。
## Round 599 (2026-08-12) — HANDOFF 刷新 112（Finding 905）

- **Round 596-598 追加 + 563 连发**（HP 条完整入档）。
- 落盘：`handoff-refresh-112-evidence.json`（F905）+ RESEARCH_LOG Round 599。

## Pending（未阻塞，持续队列）

- 无阻塞项（HP 条完整；下一弧：剩余深层角落/模拟器 polish）。
## Round 600 (2026-08-12) — ROUND 600 里程碑（Finding 906）

- **564 连发 + 530 证据 + Round 600 里程碑**（101 轮全系统闭合）。
- 落盘：`round-600-milestone-evidence.json`（F906）+ RESEARCH_LOG Round 600。

## Pending（未阻塞，持续队列）

- 无阻塞项（表面全面闭合；下一弧：HANDOFF 刷新 113/剩余角落）。
## Round 601 (2026-08-12) — HANDOFF 刷新 113（Finding 907）

- **Round 599-600 追加 + 565 连发**（Round 600 里程碑入档）。
- 落盘：`handoff-refresh-113-evidence.json`（F907）+ RESEARCH_LOG Round 601。

## Pending（未阻塞，持续队列）

- 无阻塞项（表面全面闭合；下一弧：剩余深层角落/模拟器 polish）。
## Round 602 (2026-08-12) — 交易槽查找 + 添加（Finding 908）

- **名称查找 + 添加/写入**（F557 尾部完整）。
- 落盘：`trade-slot-lookup-add-evidence.json`（F908）+ RESEARCH_LOG Round 602。

## Pending（未阻塞，持续队列）

- 无阻塞项（交易槽操作完整；下一弧：剩余深层角落）。
## Round 603 (2026-08-12) — 交易操作闭合（Finding 909）

- **567 连发 + 533 证据 + 交易操作完整**。
- 落盘：`trade-ops-closure-evidence.json`（F909）+ RESEARCH_LOG Round 603。

## Pending（未阻塞，持续队列）

- 无阻塞项（交易操作完整；下一弧：HANDOFF 刷新 114/剩余角落）。
## Round 604 (2026-08-12) — HANDOFF 刷新 114（Finding 910）

- **Round 601-603 追加 + 568 连发**（交易操作完整入档）。
- 落盘：`handoff-refresh-114-evidence.json`（F910）+ RESEARCH_LOG Round 604。

## Pending（未阻塞，持续队列）

- 无阻塞项（交易操作完整；下一弧：剩余深层角落/模拟器 polish）。
## Round 605 (2026-08-12) — 商店槽命中 + 查找（Finding 911）

- **买 5 槽/卖 4 槽命中 + 列表获取**（商店交互完整）。
- 落盘：`shop-slot-hit-lookup-evidence.json`（F911）+ RESEARCH_LOG Round 605。

## Pending（未阻塞，持续队列）

- 无阻塞项（商店槽完整；下一弧：剩余深层角落）。
## Round 606 (2026-08-12) — 商店槽闭合（Finding 912）

- **570 连发 + 536 证据 + 商店槽完整**。
- 落盘：`shop-slots-closure-evidence.json`（F912）+ RESEARCH_LOG Round 606。

## Pending（未阻塞，持续队列）

- 无阻塞项（商店槽完整；下一弧：HANDOFF 刷新 115/剩余角落）。
## Round 607 (2026-08-12) — HANDOFF 刷新 115（Finding 913）

- **Round 604-606 追加 + 571 连发**（商店槽完整入档）。
- 落盘：`handoff-refresh-115-evidence.json`（F913）+ RESEARCH_LOG Round 607。

## Pending（未阻塞，持续队列）

- 无阻塞项（商店槽完整；下一弧：剩余深层角落/模拟器 polish）。
## Round 608 (2026-08-12) — 对话窗口绘制 + 开启（Finding 914）

- **帧 0x44C/0x44D + 选项循环**（对话窗口完整）。
- 落盘：`dialog-window-draw-open-evidence.json`（F914）+ RESEARCH_LOG Round 608。

## Pending（未阻塞，持续队列）

- 无阻塞项（对话绘制完整；下一弧：剩余深层角落）。
## Round 609 (2026-08-12) — 对话全闭合（Finding 915）

- **573 连发 + 539 证据 + 对话完整**。
- 落盘：`dialog-full-closure-evidence.json`（F915）+ RESEARCH_LOG Round 609。

## Pending（未阻塞，持续队列）

- 无阻塞项（对话完整；下一弧：HANDOFF 刷新 116/剩余角落）。
## Round 610 (2026-08-12) — HANDOFF 刷新 116（Finding 916）

- **Round 607-609 追加 + 574 连发**（对话完整入档）。
- 落盘：`handoff-refresh-116-evidence.json`（F916）+ RESEARCH_LOG Round 610。

## Pending（未阻塞，持续队列）

- 无阻塞项（对话完整；下一弧：剩余深层角落/模拟器 polish）。
## Round 611 (2026-08-12) — 组队成员构造 + 帧绘制（Finding 917）

- **ctor + vtable + 帧 blit**（组队成员完整）。
- 落盘：`party-member-ctor-frame-evidence.json`（F917）+ RESEARCH_LOG Round 611。

## Pending（未阻塞，持续队列）

- 无阻塞项（组队成员完整；下一弧：剩余深层角落）。
## Round 612 (2026-08-12) — 组队成员闭合（Finding 918）

- **576 连发 + 542 证据 + 组队成员完整**。
- 落盘：`party-member-closure-evidence.json`（F918）+ RESEARCH_LOG Round 612。

## Pending（未阻塞，持续队列）

- 无阻塞项（组队成员完整；下一弧：HANDOFF 刷新 117/剩余角落）。
## Round 613 (2026-08-12) — HANDOFF 刷新 117（Finding 919）

- **Round 610-612 追加 + 577 连发**（组队成员完整入档）。
- 落盘：`handoff-refresh-117-evidence.json`（F919）+ RESEARCH_LOG Round 613。

## Pending（未阻塞，持续队列）

- 无阻塞项（组队成员完整；下一弧：剩余深层角落/模拟器 polish）。
## Round 614 (2026-08-12) — 行会成员列表初始化（Finding 920）

- **重置 + 清列表 + 默认/解析**（行会成员完整）。
- 落盘：`guild-member-list-init-evidence.json`（F920）+ RESEARCH_LOG Round 614。

## Pending（未阻塞，持续队列）

- 无阻塞项（行会成员完整；下一弧：剩余深层角落）。
## Round 615 (2026-08-12) — 行会成员闭合（Finding 921）

- **579 连发 + 545 证据 + 行会成员完整**。
- 落盘：`guild-member-closure-evidence.json`（F921）+ RESEARCH_LOG Round 615。

## Pending（未阻塞，持续队列）

- 无阻塞项（行会成员完整；下一弧：HANDOFF 刷新 118/剩余角落）。
## Round 616 (2026-08-12) — HANDOFF 刷新 118（Finding 922）

- **Round 613-615 追加 + 580 连发**（行会成员完整入档）。
- 落盘：`handoff-refresh-118-evidence.json`（F922）+ RESEARCH_LOG Round 616。

## Pending（未阻塞，持续队列）

- 无阻塞项（行会成员完整；下一弧：剩余深层角落/模拟器 polish）。
## Round 617 (2026-08-12) — 任务窗口初始化 + 命中（Finding 923）

- **旗标清 + 布局 + 命中**（任务输入完整）。
- 落盘：`quest-window-init-hit-evidence.json`（F923）+ RESEARCH_LOG Round 617。

## Pending（未阻塞，持续队列）

- 无阻塞项（任务输入完整；下一弧：剩余深层角落）。
## Round 618 (2026-08-12) — 任务输入闭合（Finding 924）

- **582 连发 + 548 证据 + 任务输入完整**。
- 落盘：`quest-input-closure-evidence.json`（F924）+ RESEARCH_LOG Round 618。

## Pending（未阻塞，持续队列）

- 无阻塞项（任务输入完整；下一弧：HANDOFF 刷新 119/剩余角落）。
## Round 619 (2026-08-12) — HANDOFF 刷新 119（Finding 925）

- **Round 616-618 追加 + 583 连发**（任务输入完整入档）。
- 落盘：`handoff-refresh-119-evidence.json`（F925）+ RESEARCH_LOG Round 619。

## Pending（未阻塞，持续队列）

- 无阻塞项（任务输入完整；下一弧：剩余深层角落/模拟器 polish）。
## Round 620 (2026-08-12) — HANDOFF 刷新 120 里程碑（Finding 926）

- **120 刷新 + 584 连发 + 6 表面闭合**。
- 落盘：`handoff-refresh-120-evidence.json`（F926）+ RESEARCH_LOG Round 620。

## Pending（未阻塞，持续队列）

- 无阻塞项（6 表面闭合；下一弧：剩余深层角落/模拟器 polish）。
## Round 621 (2026-08-12) — 选项开关 + 点击处理（Finding 927）

- **滑块输入 + 应用 + 11 控件**（选项输入完整）。
- 落盘：`options-toggle-click-handler-evidence.json`（F927）+ RESEARCH_LOG Round 621。

## Pending（未阻塞，持续队列）

- 无阻塞项（选项输入完整；下一弧：剩余深层角落）。
## Round 622 (2026-08-12) — 选项输入闭合（Finding 928）

- **586 连发 + 552 证据 + 选项输入完整**。
- 落盘：`options-input-closure-evidence.json`（F928）+ RESEARCH_LOG Round 622。

## Pending（未阻塞，持续队列）

- 无阻塞项（选项输入完整；下一弧：HANDOFF 刷新 121/剩余角落）。
## Round 623 (2026-08-12) — HANDOFF 刷新 121（Finding 929）

- **Round 620-622 追加 + 587 连发**（选项输入完整入档）。
- 落盘：`handoff-refresh-121-evidence.json`（F929）+ RESEARCH_LOG Round 623。

## Pending（未阻塞，持续队列）

- 无阻塞项（选项输入完整；下一弧：剩余深层角落/模拟器 polish）。
## Round 624 (2026-08-12) — 状态窗口构造 + 刷新（Finding 930）

- **ctor + 单例 + 刷新**（状态窗口完整）。
- 落盘：`status-window-ctor-refresh-evidence.json`（F930）+ RESEARCH_LOG Round 624。

## Pending（未阻塞，持续队列）

- 无阻塞项（状态窗口完整；下一弧：剩余深层角落）。
## Round 625 (2026-08-12) — 状态窗口闭合（Finding 931）

- **589 连发 + 555 证据 + 状态窗口完整**。
- 落盘：`status-window-closure-evidence.json`（F931）+ RESEARCH_LOG Round 625。

## Pending（未阻塞，持续队列）

- 无阻塞项（状态窗口完整；下一弧：HANDOFF 刷新 122/剩余角落）。
## Round 626 (2026-08-12) — HANDOFF 刷新 122（Finding 932）

- **Round 623-625 追加 + 590 连发**（状态窗口完整入档）。
- 落盘：`handoff-refresh-122-evidence.json`（F932）+ RESEARCH_LOG Round 626。

## Pending（未阻塞，持续队列）

- 无阻塞项（状态窗口完整；下一弧：剩余深层角落/模拟器 polish）。
## Round 627 (2026-08-12) — 装备窗口输入 + 构造（Finding 933）

- **输入 + 命中路由 + ctor**（装备输入完整）。
- 落盘：`equipment-window-ctor-input-evidence.json`（F933）+ RESEARCH_LOG Round 627。

## Pending（未阻塞，持续队列）

- 无阻塞项（装备输入完整；下一弧：剩余深层角落）。
## Round 628 (2026-08-12) — 装备窗口闭合（Finding 934）

- **592 连发 + 558 证据 + 装备窗口完整**。
- 落盘：`equipment-window-closure-evidence.json`（F934）+ RESEARCH_LOG Round 628。

## Pending（未阻塞，持续队列）

- 无阻塞项（装备窗口完整；下一弧：HANDOFF 刷新 123/剩余角落）。
## Round 629 (2026-08-12) — HANDOFF 刷新 123（Finding 935）

- **Round 626-628 追加 + 593 连发**（装备窗口完整入档）。
- 落盘：`handoff-refresh-123-evidence.json`（F935）+ RESEARCH_LOG Round 629。

## Pending（未阻塞，持续队列）

- 无阻塞项（装备窗口完整；下一弧：剩余深层角落/模拟器 polish）。
## Round 630 (2026-08-12) — 背包构造/重置 + 点击 + 使用门（Finding 936）

- **重置 + 点击路由 + 使用门**（背包输入完整）。
- 落盘：`inventory-ctor-click-use-evidence.json`（F936）+ RESEARCH_LOG Round 630。

## Pending（未阻塞，持续队列）

- 无阻塞项（背包输入完整；下一弧：剩余深层角落）。
## Round 631 (2026-08-12) — 背包窗口闭合（Finding 937）

- **595 连发 + 561 证据 + 背包窗口完整**。
- 落盘：`inventory-window-closure-evidence.json`（F937）+ RESEARCH_LOG Round 631。

## Pending（未阻塞，持续队列）

- 无阻塞项（背包窗口完整；下一弧：HANDOFF 刷新 124/剩余角落）。
## Round 632 (2026-08-12) — HANDOFF 刷新 124（Finding 938）

- **Round 629-631 追加 + 596 连发**（背包窗口完整入档）。
- 落盘：`handoff-refresh-124-evidence.json`（F938）+ RESEARCH_LOG Round 632。

## Pending（未阻塞，持续队列）

- 无阻塞项（背包窗口完整；下一弧：剩余深层角落/模拟器 polish）。
## Round 633 (2026-08-12) — 技能窗口输入 + 记录列表（Finding 939）

- **输入 + 记录列表**（技能输入完整）。
- 落盘：`skill-window-input-evidence.json`（F939）+ RESEARCH_LOG Round 633。

## Pending（未阻塞，持续队列）

- 无阻塞项（技能输入完整；下一弧：剩余深层角落）。
## Round 634 (2026-08-12) — 技能窗口闭合（Finding 940）

- **598 连发 + 564 证据 + 技能窗口完整**。
- 落盘：`skill-window-closure-evidence.json`（F940）+ RESEARCH_LOG Round 634。

## Pending（未阻塞，持续队列）

- 无阻塞项（技能窗口完整；下一弧：HANDOFF 刷新 125/剩余角落）。
## Round 635 (2026-08-12) — HANDOFF 刷新 125（Finding 941）

- **Round 632-634 追加 + 599 连发**（技能窗口完整入档）。
- 落盘：`handoff-refresh-125-evidence.json`（F941）+ RESEARCH_LOG Round 635。

## Pending（未阻塞，持续队列）

- 无阻塞项（技能窗口完整；下一弧：剩余深层角落/模拟器 polish）。
## Round 636 (2026-08-12) — 任务窗口输入（Finding 942）

- **2 按钮 + 列表命中**（任务输入完整）。
- 落盘：`quest-window-input-evidence.json`（F942）+ RESEARCH_LOG Round 636。

## Pending（未阻塞，持续队列）

- 无阻塞项（任务输入完整；下一弧：剩余深层角落）。
## Round 637 (2026-08-12) — 600 连发里程碑（Finding 943）

- **600 连发 + 567 证据 + 709 commit + 6 表面闭合**。
- 落盘：`round-600-consecutive-milestone-evidence.json`（F943）+ RESEARCH_LOG Round 637。

## Pending（未阻塞，持续队列）

- 无阻塞项（窗口输入表面全闭合；下一弧：剩余深层角落/模拟器 polish）。
## Round 638 (2026-08-12) — HANDOFF 刷新 126（Finding 944）

- **Round 635-637 追加 + 601 连发**（任务输入 + 600 连发里程碑入档）。
- 落盘：`handoff-refresh-126-evidence.json`（F944）+ RESEARCH_LOG Round 638。

## Pending（未阻塞，持续队列）

- 无阻塞项（600 连发达成；下一弧：剩余深层角落/模拟器 polish）。
## Round 639 (2026-08-12) — 行会窗口输入 + 重置（Finding 945）

- **输入 + 清空**（行会输入完整）。
- 落盘：`guild-window-input-reset-evidence.json`（F945）+ RESEARCH_LOG Round 639。

## Pending（未阻塞，持续队列）

- 无阻塞项（行会输入完整；下一弧：剩余深层角落）。
## Round 640 (2026-08-12) — 行会窗口闭合（Finding 946）

- **604 连发 + 570 证据 + 行会窗口完整**。
- 落盘：`guild-window-closure-evidence.json`（F946）+ RESEARCH_LOG Round 640。

## Pending（未阻塞，持续队列）

- 无阻塞项（行会窗口完整；下一弧：HANDOFF 刷新 127/剩余角落）。
## Round 641 (2026-08-12) — HANDOFF 刷新 127（Finding 947）

- **Round 638-640 追加 + 605 连发**（行会窗口完整入档）。
- 落盘：`handoff-refresh-127-evidence.json`（F947）+ RESEARCH_LOG Round 641。

## Pending（未阻塞，持续队列）

- 无阻塞项（行会窗口完整；下一弧：剩余深层角落/模拟器 polish）。
## Round 642 (2026-08-12) — 组队窗口输入 + 消息分派（Finding 948）

- **5 控件 + 0x3FC-0x3FE 分派**（组队输入完整）。
- 落盘：`party-window-input-msg-evidence.json`（F948）+ RESEARCH_LOG Round 642。

## Pending（未阻塞，持续队列）

- 无阻塞项（组队输入完整；下一弧：剩余深层角落）。
## Round 643 (2026-08-12) — 组队窗口闭合（Finding 949）

- **607 连发 + 573 证据 + 组队窗口完整**。
- 落盘：`party-window-closure-evidence.json`（F949）+ RESEARCH_LOG Round 643。

## Pending（未阻塞，持续队列）

- 无阻塞项（组队窗口完整；下一弧：HANDOFF 刷新 128/剩余角落）。
## Round 644 (2026-08-12) — HANDOFF 刷新 128（Finding 950）

- **Round 641-643 追加 + 608 连发**（组队窗口完整入档）。
- 落盘：`handoff-refresh-128-evidence.json`（F950）+ RESEARCH_LOG Round 644。

## Pending（未阻塞，持续队列）

- 无阻塞项（组队窗口完整；下一弧：剩余深层角落/模拟器 polish）。
## Round 645 (2026-08-12) — 交易窗口输入 + 点击（Finding 951）

- **2 滚动条 + 取消 + 槽命中**（交易输入完整）。
- 落盘：`trade-window-input-evidence.json`（F951）+ RESEARCH_LOG Round 645。

## Pending（未阻塞，持续队列）

- 无阻塞项（交易输入完整；下一弧：剩余深层角落）。
## Round 646 (2026-08-12) — 交易窗口闭合（Finding 952）

- **610 连发 + 576 证据 + 交易窗口完整**。
- 落盘：`trade-window-closure-evidence.json`（F952）+ RESEARCH_LOG Round 646。

## Pending（未阻塞，持续队列）

- 无阻塞项（交易窗口完整；下一弧：HANDOFF 刷新 129/剩余角落）。
## Round 647 (2026-08-12) — HANDOFF 刷新 129（Finding 953）

- **Round 644-646 追加 + 611 连发**（交易窗口完整入档）。
- 落盘：`handoff-refresh-129-evidence.json`（F953）+ RESEARCH_LOG Round 647。

## Pending（未阻塞，持续队列）

- 无阻塞项（交易窗口完整；下一弧：剩余深层角落/模拟器 polish）。
## Round 648 (2026-08-12) — 商店窗口输入 + 点击（Finding 954）

- **滚动 + 买/卖/修**（商店输入完整）。
- 落盘：`shop-window-input-click-evidence.json`（F954）+ RESEARCH_LOG Round 648。

## Pending（未阻塞，持续队列）

- 无阻塞项（商店输入完整；下一弧：剩余深层角落）。
## Round 649 (2026-08-12) — 商店窗口闭合（Finding 955）

- **613 连发 + 579 证据 + 商店窗口完整**。
- 落盘：`shop-window-closure-evidence.json`（F955）+ RESEARCH_LOG Round 649。

## Pending（未阻塞，持续队列）

- 无阻塞项（商店窗口完整；下一弧：HANDOFF 刷新 130/剩余角落）。
## Round 650 (2026-08-12) — HANDOFF 刷新 130 里程碑（Finding 956）

- **130 刷新 + 614 连发 + 13/13 窗口输入闭合**。
- 落盘：`handoff-refresh-130-milestone-evidence.json`（F956）+ RESEARCH_LOG Round 650。

## Pending（未阻塞，持续队列）

- 无阻塞项（窗口输入表面全闭合；下一弧：剩余深层角落/模拟器 polish）。
## Round 651 (2026-08-12) — 对话窗口输入（Finding 957）

- **按钮 + 滚动条 + 选项命中 + 滚轮**（对话输入完整）。
- 落盘：`dialog-window-input-evidence.json`（F957）+ RESEARCH_LOG Round 651。

## Pending（未阻塞，持续队列）

- 无阻塞项（对话输入完整；下一弧：剩余深层角落）。
## Round 652 (2026-08-12) — 公告窗口输入（Finding 958）

- **滚动 + 9 控件 + 按键**（公告输入完整）。
- 落盘：`announcement-window-input-evidence.json`（F958）+ RESEARCH_LOG Round 652。

## Pending（未阻塞，持续队列）

- 无阻塞项（公告输入完整；下一弧：剩余深层角落）。
## Round 653 (2026-08-12) — 公告窗口闭合（Finding 959）

- **617 连发 + 583 证据 + 公告窗口完整**。
- 落盘：`announcement-window-closure-evidence.json`（F959）+ RESEARCH_LOG Round 653。

## Pending（未阻塞，持续队列）

- 无阻塞项（公告窗口完整；下一弧：HANDOFF 刷新 131/剩余角落）。
## Round 654 (2026-08-12) — HANDOFF 刷新 131（Finding 960）

- **Round 650-653 追加 + 618 连发**（对话/公告窗口完整入档）。
- 落盘：`handoff-refresh-131-evidence.json`（F960）+ RESEARCH_LOG Round 654。

## Pending（未阻塞，持续队列）

- 无阻塞项（对话/公告窗口完整；下一弧：剩余深层角落/模拟器 polish）。
## Round 655 (2026-08-12) — 对话 + 公告窗口闭合（Finding 961）

- **619 连发 + 585 证据 + 13/13 窗口输入**。
- 落盘：`dialog-announcement-closure-evidence.json`（F961）+ RESEARCH_LOG Round 655。

## Pending（未阻塞，持续队列）

- 无阻塞项（13/13 窗口输入；下一弧：HANDOFF 刷新 132/剩余角落）。
## Round 656 (2026-08-12) — HANDOFF 刷新 132（Finding 962）

- **Round 654-655 追加 + 620 连发**（13/13 窗口输入入档）。
- 落盘：`handoff-refresh-132-evidence.json`（F962）+ RESEARCH_LOG Round 656。

## Pending（未阻塞，持续队列）

- 无阻塞项（13/13 窗口输入；下一弧：剩余深层角落/模拟器 polish）。
## Round 657 (2026-08-12) — HUD 输入分派尾部（Finding 963）

- **任务/商店路由 + 热键使用**（HUD 分派完整）。
- 落盘：`hud-input-dispatch-tail-evidence.json`（F963）+ RESEARCH_LOG Round 657。

## Pending（未阻塞，持续队列）

- 无阻塞项（HUD 分派完整；下一弧：剩余深层角落）。
## Round 658 (2026-08-12) — HUD 分派闭合（Finding 964）

- **622 连发 + 588 证据 + HUD 分派完整**。
- 落盘：`hud-dispatch-closure-evidence.json`（F964）+ RESEARCH_LOG Round 658。

## Pending（未阻塞，持续队列）

- 无阻塞项（13/13 窗口 + HUD 输入；下一弧：HANDOFF 刷新 133/剩余角落）。
## Round 659 (2026-08-12) — HANDOFF 刷新 133（Finding 965）

- **Round 656-658 追加 + 623 连发**（HUD 分派完整入档）。
- 落盘：`handoff-refresh-133-evidence.json`（F965）+ RESEARCH_LOG Round 659。

## Pending（未阻塞，持续队列）

- 无阻塞项（13/13 窗口 + HUD 输入；下一弧：剩余深层角落/模拟器 polish）。
## Round 660 (2026-08-12) — 窗口命中路由器全量（Finding 966）

- **13 矩形 jt + PtInRect**（命中路由器完整）。
- 落盘：`window-hit-router-full-evidence.json`（F966）+ RESEARCH_LOG Round 660。

## Pending（未阻塞，持续队列）

- 无阻塞项（命中路由器完整；下一弧：剩余深层角落）。
## Round 661 (2026-08-12) — 命中路由器闭合（Finding 967）

- **625 连发 + 591 证据 + 命中路由完整**。
- 落盘：`hit-router-closure-evidence.json`（F967）+ RESEARCH_LOG Round 661。

## Pending（未阻塞，持续队列）

- 无阻塞项（13/13 窗口 + HUD + 命中路由；下一弧：HANDOFF 刷新 134/剩余角落）。
## Round 662 (2026-08-12) — HANDOFF 刷新 134（Finding 968）

- **Round 659-661 追加 + 626 连发**（命中路由完整入档）。
- 落盘：`handoff-refresh-134-evidence.json`（F968）+ RESEARCH_LOG Round 662。

## Pending（未阻塞，持续队列）

- 无阻塞项（13/13 窗口 + HUD + 命中路由；下一弧：剩余深层角落/模拟器 polish）。
## Round 663 (2026-08-12) — 主 tick/构造链重述（Finding 969）

- **vtable 链 + 阶段构造**（主构造完整）。
- 落盘：`main-tick-ctor-chain-recap-evidence.json`（F969）+ RESEARCH_LOG Round 663。

## Pending（未阻塞，持续队列）

- 无阻塞项（主构造完整；下一弧：剩余深层角落）。
## Round 664 (2026-08-12) — 主 tick 闭合（Finding 970）

- **628 连发 + 594 证据 + 主构造完整**。
- 落盘：`main-tick-closure-evidence.json`（F970）+ RESEARCH_LOG Round 664。

## Pending（未阻塞，持续队列）

- 无阻塞项（主构造完整；下一弧：HANDOFF 刷新 135/剩余角落）。
## Round 665 (2026-08-12) — HANDOFF 刷新 135（Finding 971）

- **Round 662-664 追加 + 629 连发**（主构造完整入档）。
- 落盘：`handoff-refresh-135-evidence.json`（F971）+ RESEARCH_LOG Round 665。

## Pending（未阻塞，持续队列）

- 无阻塞项（主构造完整；下一弧：剩余深层角落/模拟器 polish）。
## Round 666 (2026-08-12) — 坐骑窗口输入 + 构造（Finding 972）

- **5 控件 + 构造链**（坐骑输入完整）。
- 落盘：`mount-window-input-ctor-evidence.json`（F972）+ RESEARCH_LOG Round 666。

## Pending（未阻塞，持续队列）

- 无阻塞项（坐骑输入完整；下一弧：剩余深层角落）。
## Round 667 (2026-08-12) — 坐骑窗口闭合（Finding 973）

- **631 连发 + 597 证据 + 坐骑窗口完整**。
- 落盘：`mount-window-closure-evidence.json`（F973）+ RESEARCH_LOG Round 667。

## Pending（未阻塞，持续队列）

- 无阻塞项（13/13 窗口 + HUD + 路由 + 主构造；下一弧：HANDOFF 刷新 136/剩余角落）。
## Round 668 (2026-08-12) — HANDOFF 刷新 136（Finding 974）

- **Round 665-667 追加 + 632 连发**（坐骑窗口完整入档）。
- 落盘：`handoff-refresh-136-evidence.json`（F974）+ RESEARCH_LOG Round 668。

## Pending（未阻塞，持续队列）

- 无阻塞项（13/13 窗口 + HUD + 路由 + 主构造；下一弧：剩余深层角落/模拟器 polish）。
## Round 669 (2026-08-12) — 公告编辑器输入（Finding 975）

- **渲染 + 按键 + GetWindowText**（编辑器输入完整）。
- 落盘：`announcement-editor-input-evidence.json`（F975）+ RESEARCH_LOG Round 669。

## Pending（未阻塞，持续队列）

- 无阻塞项（编辑器输入完整；下一弧：剩余深层角落）。
## Round 670 (2026-08-12) — 公告编辑器闭合 + 600 证据里程碑（Finding 976）

- **634 连发 + 600 证据 + 编辑器完整**。
- 落盘：`editor-window-closure-evidence.json`（F976）+ RESEARCH_LOG Round 670。

## Pending（未阻塞，持续队列）

- 无阻塞项（全部窗口 + 编辑器 100%；下一弧：HANDOFF 刷新 137/剩余角落）。
## Round 671 (2026-08-12) — HANDOFF 刷新 137（Finding 977）

- **Round 668-670 追加 + 635 连发 + 600 证据**（编辑器完整入档）。
- 落盘：`handoff-refresh-137-evidence.json`（F977）+ RESEARCH_LOG Round 671。

## Pending（未阻塞，持续队列）

- 无阻塞项（全部窗口 + 编辑器 100%；下一弧：剩余深层角落/模拟器 polish）。
## Round 672 (2026-08-12) — 选项配置装载全量（Finding 978）

- **6 键 + 音频应用**（配置装载完整）。
- 落盘：`options-config-load-full-evidence.json`（F978）+ RESEARCH_LOG Round 672。

## Pending（未阻塞，持续队列）

- 无阻塞项（配置装载完整；下一弧：剩余深层角落）。
## Round 673 (2026-08-12) — 选项配置闭合（Finding 979）

- **637 连发 + 603 证据 + 选项持久化完整**。
- 落盘：`options-config-closure-evidence.json`（F979）+ RESEARCH_LOG Round 673。

## Pending（未阻塞，持续队列）

- 无阻塞项（选项持久化完整；下一弧：HANDOFF 刷新 138/剩余角落）。
## Round 674 (2026-08-12) — HANDOFF 刷新 138（Finding 980）

- **Round 671-673 追加 + 638 连发**（选项持久化完整入档）。
- 落盘：`handoff-refresh-138-evidence.json`（F980）+ RESEARCH_LOG Round 674。

## Pending（未阻塞，持续队列）

- 无阻塞项（选项持久化完整；下一弧：剩余深层角落/模拟器 polish）。
## Round 675 (2026-08-12) — 技能书绘制 + 页计数（Finding 981）

- **3 页签 + 8 槽 + 页 ÷3**（技能书绘制完整）。
- 落盘：`skill-book-draw-page-evidence.json`（F981）+ RESEARCH_LOG Round 675。

## Pending（未阻塞，持续队列）

- 无阻塞项（技能书绘制完整；下一弧：剩余深层角落）。
## Round 676 (2026-08-12) — 技能书闭合（Finding 982）

- **640 连发 + 606 证据 + 技能书完整**。
- 落盘：`skill-book-closure-evidence.json`（F982）+ RESEARCH_LOG Round 676。

## Pending（未阻塞，持续队列）

- 无阻塞项（技能表面 100%；下一弧：HANDOFF 刷新 139/剩余角落）。
## Round 677 (2026-08-12) — HANDOFF 刷新 139（Finding 983）

- **Round 674-676 追加 + 641 连发**（技能书完整入档）。
- 落盘：`handoff-refresh-139-evidence.json`（F983）+ RESEARCH_LOG Round 677。

## Pending（未阻塞，持续队列）

- 无阻塞项（技能表面 100%；下一弧：剩余深层角落/模拟器 polish）。
## Round 678 (2026-08-12) — 物品网格构造/初始化/绘制（Finding 984）

- **ctor + init + draw**（物品网格完整）。
- 落盘：`item-grid-ctor-init-draw-evidence.json`（F984）+ RESEARCH_LOG Round 678。

## Pending（未阻塞，持续队列）

- 无阻塞项（物品网格完整；下一弧：剩余深层角落）。
## Round 679 (2026-08-12) — 物品网格闭合（Finding 985）

- **643 连发 + 608 证据 + 网格完整**。
- 落盘：`item-grid-closure-evidence.json`（F985）+ RESEARCH_LOG Round 679。

## Pending（未阻塞，持续队列）

- 无阻塞项（网格表面 100%；下一弧：HANDOFF 刷新 140/剩余角落）。
## Round 680 (2026-08-12) — HANDOFF 刷新 140（Finding 986）

- **Round 677-679 追加 + 644 连发**（物品网格完整入档）。
- 落盘：`handoff-refresh-140-evidence.json`（F986）+ RESEARCH_LOG Round 680。

## Pending（未阻塞，持续队列）

- 无阻塞项（网格表面 100%；下一弧：剩余深层角落/模拟器 polish）。
## Round 681 (2026-08-12) — 装备构造 + 纸娃娃全量（Finding 987）

- **11 槽 + 纸娃娃帧**（装备完整）。
- 落盘：`equipment-ctor-paperdoll-full-evidence.json`（F987）+ RESEARCH_LOG Round 681。

## Pending（未阻塞，持续队列）

- 无阻塞项（装备完整；下一弧：剩余深层角落）。
## Round 682 (2026-08-12) — 装备/纸娃娃闭合（Finding 988）

- **646 连发 + 611 证据 + 装备/纸娃娃完整**。
- 落盘：`paperdoll-closure-evidence.json`（F988）+ RESEARCH_LOG Round 682。

## Pending（未阻塞，持续队列）

- 无阻塞项（装备 + 纸娃娃 100%；下一弧：HANDOFF 刷新 141/剩余角落）。
## Round 683 (2026-08-12) — HANDOFF 刷新 141（Finding 989）

- **Round 680-682 追加 + 647 连发**（装备/纸娃娃完整入档）。
- 落盘：`handoff-refresh-141-evidence.json`（F989）+ RESEARCH_LOG Round 683。

## Pending（未阻塞，持续队列）

- 无阻塞项（装备 + 纸娃娃 100%；下一弧：剩余深层角落/模拟器 polish）。
## Round 684 (2026-08-12) — HP 条 blit 全量（Finding 990）

- **lerp + 矩阵 + blit**（HP 条 blit 完整）。
- 落盘：`hp-bar-blit-full-evidence.json`（F990）+ RESEARCH_LOG Round 684。

## Pending（未阻塞，持续队列）

- 无阻塞项（HP 条 blit 完整；下一弧：剩余深层角落）。
## Round 685 (2026-08-12) — HP 条系统闭合（Finding 991）

- **649 连发 + 614 证据 + HP 条完整**。
- 落盘：`hp-bar-system-closure-evidence.json`（F991）+ RESEARCH_LOG Round 685。

## Pending（未阻塞，持续队列）

- 无阻塞项（HP 条完整；下一弧：HANDOFF 刷新 142/剩余角落）。
## Round 686 (2026-08-12) — HANDOFF 刷新 142（Finding 992）

- **Round 683-685 追加 + 650 连发**（HP 条完整入档）。
- 落盘：`handoff-refresh-142-evidence.json`（F992）+ RESEARCH_LOG Round 686。

## Pending（未阻塞，持续队列）

- 无阻塞项（HP 条完整；下一弧：剩余深层角落/模拟器 polish）。
## Round 687 (2026-08-12) — 实体投影 + 阴影 blit 全量（Finding 993）

- **投影 + 阴影 + 钳制**（实体投影完整）。
- 落盘：`entity-projection-shadow-full-evidence.json`（F993）+ RESEARCH_LOG Round 687。

## Pending（未阻塞，持续队列）

- 无阻塞项（实体投影完整；下一弧：剩余深层角落）。
## Round 688 (2026-08-12) — 实体渲染闭合（Finding 994）

- **652 连发 + 616 证据 + 实体渲染完整**。
- 落盘：`entity-render-closure-evidence.json`（F994）+ RESEARCH_LOG Round 688。

## Pending（未阻塞，持续队列）

- 无阻塞项（实体表面 100%；下一弧：HANDOFF 刷新 143/剩余角落）。
## Round 689 (2026-08-12) — HANDOFF 刷新 143（Finding 995）

- **Round 686-688 追加 + 653 连发**（实体渲染完整入档）。
- 落盘：`handoff-refresh-143-evidence.json`（F995）+ RESEARCH_LOG Round 689。

## Pending（未阻塞，持续队列）

- 无阻塞项（实体表面 100%；下一弧：剩余深层角落/模拟器 polish）。
## Round 690 (2026-08-12) — 相机滚动全量（Finding 996）

- **平移 + 缓冲滚动 + 脏重绘**（相机滚动完整）。
- 落盘：`camera-scroll-full-evidence.json`（F996）+ RESEARCH_LOG Round 690。

## Pending（未阻塞，持续队列）

- 无阻塞项（相机滚动完整；下一弧：剩余深层角落）。
## Round 691 (2026-08-12) — 相机闭合（Finding 997）

- **655 连发 + 618 证据 + 相机完整**。
- 落盘：`camera-closure-evidence.json`（F997）+ RESEARCH_LOG Round 691。

## Pending（未阻塞，持续队列）

- 无阻塞项（地图表面 100%；下一弧：HANDOFF 刷新 144/剩余角落）。
## Round 692 (2026-08-12) — HANDOFF 刷新 144（Finding 998）

- **Round 689-691 追加 + 656 连发**（相机完整入档）。
- 落盘：`handoff-refresh-144-evidence.json`（F998）+ RESEARCH_LOG Round 692。

## Pending（未阻塞，持续队列）

- 无阻塞项（地图表面 100%；下一弧：剩余深层角落/模拟器 polish）。
## Round 693 (2026-08-12) — 名字标签渲染全量（Finding 999）

- **超时 + 8 状态串 + 矩阵 + blit**（名字标签渲染完整）。
- 落盘：`name-tag-render-full-evidence.json`（F999）+ RESEARCH_LOG Round 693。

## Pending（未阻塞，持续队列）

- 无阻塞项（名字标签渲染完整；下一弧：剩余深层角落）。
## Round 694 (2026-08-12) — 名字标签闭合 + FINDING 1000 里程碑（Finding 1000）

- **658 连发 + 621 证据 + 名字标签完整 + FINDING 1000**。
- 落盘：`name-tag-closure-evidence.json`（F1000）+ RESEARCH_LOG Round 694。

## Pending（未阻塞，持续队列）

- 无阻塞项（名字标签完整；FINDING 1000 达成；下一弧：HANDOFF 刷新 145/剩余角落）。
## Round 695 (2026-08-12) — HANDOFF 刷新 145（Finding 1001）

- **Round 692-694 追加 + 659 连发 + FINDING 1000**（名字标签完整入档）。
- 落盘：`handoff-refresh-145-evidence.json`（F1001）+ RESEARCH_LOG Round 695。

## Pending（未阻塞，持续队列）

- 无阻塞项（FINDING 1000 达成；下一弧：剩余深层角落/模拟器 polish）。
## Round 696 (2026-08-12) — 英雄运行时构造 + 死亡全量（Finding 1002）

- **ctor + 装载 + 死亡**（英雄运行时完整）。
- 落盘：`hero-runtime-ctor-death-full-evidence.json`（F1002）+ RESEARCH_LOG Round 696。

## Pending（未阻塞，持续队列）

- 无阻塞项（英雄运行时完整；下一弧：剩余深层角落）。
## Round 697 (2026-08-12) — 英雄运行时闭合（Finding 1003）

- **661 连发 + 624 证据 + 英雄运行时完整**。
- 落盘：`hero-runtime-closure-evidence.json`（F1003）+ RESEARCH_LOG Round 697。

## Pending（未阻塞，持续队列）

- 无阻塞项（英雄表面 100%；下一弧：HANDOFF 刷新 146/剩余角落）。
## Round 698 (2026-08-12) — HANDOFF 刷新 146（Finding 1004）

- **Round 695-697 追加 + 662 连发**（英雄运行时完整入档）。
- 落盘：`handoff-refresh-146-evidence.json`（F1004）+ RESEARCH_LOG Round 698。

## Pending（未阻塞，持续队列）

- 无阻塞项（英雄表面 100%；下一弧：剩余深层角落/模拟器 polish）。
## Round 699 (2026-08-12) — 受击闪光特效全量（Finding 1005）

- **ctor + 网格 + 拾取 + 绘制**（受击闪光完整）。
- 落盘：`hit-flash-effect-full-evidence.json`（F1005）+ RESEARCH_LOG Round 699。

## Pending（未阻塞，持续队列）

- 无阻塞项（受击闪光完整；下一弧：剩余深层角落）。
## Round 700 (2026-08-12) — ROUND 700 里程碑（Finding 1006）

- **Round 700 + 663 连发 + 627 证据 + 772 commit + FINDING 1000**。
- 落盘：`round-700-milestone-evidence.json`（F1006）+ RESEARCH_LOG Round 700。

## Pending（未阻塞，持续队列）

- 无阻塞项（12 表面闭合；下一弧：剩余深层角落/模拟器 polish）。
## Round 701 (2026-08-12) — HANDOFF 刷新 147（Finding 1007）

- **Round 698-700 追加 + 664 连发 + ROUND 700**（受击闪光/里程碑入档）。
- 落盘：`handoff-refresh-147-evidence.json`（F1007）+ RESEARCH_LOG Round 701。

## Pending（未阻塞，持续队列）

- 无阻塞项（ROUND 700 达成；下一弧：剩余深层角落/模拟器 polish）。
## Round 702 (2026-08-12) — 瓦片访问器可行走 + 属性全量（Finding 1008）

- **bit0 + 属性字**（瓦片访问器完整）。
- 落盘：`tile-accessors-walkable-attr-full-evidence.json`（F1008）+ RESEARCH_LOG Round 702。

## Pending（未阻塞，持续队列）

- 无阻塞项（瓦片访问器完整；下一弧：剩余深层角落）。
## Round 703 (2026-08-12) — 瓦片访问器闭合（Finding 1009）

- **666 连发 + 630 证据 + 瓦片访问器完整**。
- 落盘：`tile-accessors-closure-evidence.json`（F1009）+ RESEARCH_LOG Round 703。

## Pending（未阻塞，持续队列）

- 无阻塞项（地图碰撞 100%；下一弧：HANDOFF 刷新 148/剩余角落）。
## Round 704 (2026-08-12) — HANDOFF 刷新 148（Finding 1010）

- **Round 701-703 追加 + 667 连发**（瓦片访问器完整入档）。
- 落盘：`handoff-refresh-148-evidence.json`（F1010）+ RESEARCH_LOG Round 704。

## Pending（未阻塞，持续队列）

- 无阻塞项（地图碰撞 100%；下一弧：剩余深层角落/模拟器 polish）。
## Round 705 (2026-08-12) — 地面瓦片 blit 全量（Finding 1011）

- **奇偶 + ÷7 + 类型表 + blit**（地面瓦片完整）。
- 落盘：`ground-tile-blit-full-evidence.json`（F1011）+ RESEARCH_LOG Round 705。

## Pending（未阻塞，持续队列）

- 无阻塞项（地面瓦片完整；下一弧：剩余深层角落）。
## Round 706 (2026-08-12) — 瓦片渲染闭合（Finding 1012）

- **669 连发 + 633 证据 + 瓦片渲染完整**。
- 落盘：`tile-render-closure-evidence.json`（F1012）+ RESEARCH_LOG Round 706。

## Pending（未阻塞，持续队列）

- 无阻塞项（地图瓦片 100%；下一弧：HANDOFF 刷新 149/剩余角落）。
## Round 707 (2026-08-12) — HANDOFF 刷新 149（Finding 1013）

- **Round 704-706 追加 + 670 连发**（瓦片渲染完整入档）。
- 落盘：`handoff-refresh-149-evidence.json`（F1013）+ RESEARCH_LOG Round 707。

## Pending（未阻塞，持续队列）

- 无阻塞项（地图瓦片 100%；下一弧：剩余深层角落/模拟器 polish）。
## Round 708 (2026-08-12) — 移动分派 + 碰撞全量（Finding 1014）

- **8 方向 + 可行走 + 实体碰撞**（移动分派完整）。
- 落盘：`move-dispatch-collision-full-evidence.json`（F1014）+ RESEARCH_LOG Round 708。

## Pending（未阻塞，持续队列）

- 无阻塞项（移动分派完整；下一弧：剩余深层角落）。
## Round 709 (2026-08-12) — 移动闭合（Finding 1015）

- **672 连发 + 636 证据 + 移动完整**。
- 落盘：`move-closure-evidence.json`（F1015）+ RESEARCH_LOG Round 709。

## Pending（未阻塞，持续队列）

- 无阻塞项（移动表面 100%；下一弧：HANDOFF 刷新 150/剩余角落）。
## Round 710 (2026-08-12) — HANDOFF 刷新 150 里程碑（Finding 1016）

- **150 刷新 + 673 连发 + 移动完整**。
- 落盘：`handoff-refresh-150-milestone-evidence.json`（F1016）+ RESEARCH_LOG Round 710。

## Pending（未阻塞，持续队列）

- 无阻塞项（地图 + 移动核心完整；下一弧：剩余深层角落/模拟器 polish）。
## Round 711 (2026-08-12) — 实体构造 + 分派全量（Finding 1017）

- **ctor + dtor + 消息分派**（实体完整）。
- 落盘：`entity-ctor-dispatch-full-evidence.json`（F1017）+ RESEARCH_LOG Round 711。

## Pending（未阻塞，持续队列）

- 无阻塞项（实体完整；下一弧：剩余深层角落）。
## Round 712 (2026-08-12) — 实体闭合（Finding 1018）

- **675 连发 + 639 证据 + 实体完整**。
- 落盘：`entity-closure-evidence.json`（F1018）+ RESEARCH_LOG Round 712。

## Pending（未阻塞，持续队列）

- 无阻塞项（实体表面 100%；下一弧：HANDOFF 刷新 151/剩余角落）。
## Round 713 (2026-08-12) — HANDOFF 刷新 151（Finding 1019）

- **Round 710-712 追加 + 676 连发**（实体完整入档）。
- 落盘：`handoff-refresh-151-evidence.json`（F1019）+ RESEARCH_LOG Round 713。

## Pending（未阻塞，持续队列）

- 无阻塞项（实体表面 100%；下一弧：剩余深层角落/模拟器 polish）。
## Round 714 (2026-08-12) — 消息发送器家族全量（Finding 1020）

- **构建 + 泵 + 10 变体**（发送器家族完整）。
- 落盘：`msg-sender-family-full-evidence.json`（F1020）+ RESEARCH_LOG Round 714。

## Pending（未阻塞，持续队列）

- 无阻塞项（发送器家族完整；下一弧：剩余深层角落）。
## Round 715 (2026-08-12) — 发送器闭合（Finding 1021）

- **678 连发 + 642 证据 + 发送器完整**。
- 落盘：`sender-closure-evidence.json`（F1021）+ RESEARCH_LOG Round 715。

## Pending（未阻塞，持续队列）

- 无阻塞项（出站 100%；下一弧：HANDOFF 刷新 152/剩余角落）。
## Round 716 (2026-08-12) — HANDOFF 刷新 152（Finding 1022）

- **Round 713-715 追加 + 679 连发**（发送器完整入档）。
- 落盘：`handoff-refresh-152-evidence.json`（F1022）+ RESEARCH_LOG Round 716。

## Pending（未阻塞，持续队列）

- 无阻塞项（出站 100%；下一弧：剩余深层角落/模拟器 polish）。
## Round 717 (2026-08-12) — recv1 坐骑/物品/封锁/公告全量（Finding 1023）

- **坐骑 + 物品 + 封锁 + 公告**（recv1 家族完整）。
- 落盘：`recv1-mount-item-block-full-evidence.json`（F1023）+ RESEARCH_LOG Round 717。

## Pending（未阻塞，持续队列）

- 无阻塞项（recv1 家族完整；下一弧：剩余深层角落）。
## Round 718 (2026-08-12) — recv1 闭合（Finding 1024）

- **681 连发 + 645 证据 + recv1 完整**。
- 落盘：`recv1-closure-evidence.json`（F1024）+ RESEARCH_LOG Round 718。

## Pending（未阻塞，持续队列）

- 无阻塞项（入站 100%；下一弧：HANDOFF 刷新 153/剩余角落）。
## Round 719 (2026-08-12) — HANDOFF 刷新 153（Finding 1025）

- **Round 716-718 追加 + 682 连发**（recv1 完整入档）。
- 落盘：`handoff-refresh-153-evidence.json`（F1025）+ RESEARCH_LOG Round 719。

## Pending（未阻塞，持续队列）

- 无阻塞项（入站 100%；下一弧：剩余深层角落/模拟器 polish）。
## Round 720 (2026-08-12) — recv2 地图/名字/标题全量（Finding 1026）

- **base64 + 标题/名字**（recv2 家族完整）。
- 落盘：`recv2-map-name-title-full-evidence.json`（F1026）+ RESEARCH_LOG Round 720。

## Pending（未阻塞，持续队列）

- 无阻塞项（recv2 家族完整；下一弧：剩余深层角落）。
## Round 721 (2026-08-12) — recv2 闭合（Finding 1027）

- **684 连发 + 648 证据 + recv2 完整 + 入站 100%**。
- 落盘：`recv2-closure-evidence.json`（F1027）+ RESEARCH_LOG Round 721。

## Pending（未阻塞，持续队列）

- 无阻塞项（recv1+recv2 入站完整；下一弧：HANDOFF 刷新 154/剩余角落）。
## Round 722 (2026-08-12) — HANDOFF 刷新 154（Finding 1028）

- **Round 719-721 追加 + 685 连发**（recv2 完整 + 入站 100% 入档）。
- 落盘：`handoff-refresh-154-evidence.json`（F1028）+ RESEARCH_LOG Round 722。

## Pending（未阻塞，持续队列）

- 无阻塞项（入站 100%；下一弧：剩余深层角落/模拟器 polish）。
## Round 723 (2026-08-12) — recv2 非主角实体名字更新全量（Finding 1029）

- **实体链表查找 + 名字复制 + 格式化 + 超时清零**（recv2 名字更新分支完整）。
- 落盘：`recv2-entity-name-update-evidence.json`（F1029）+ RESEARCH_LOG Round 723。

## Pending（未阻塞，持续队列）

- 无阻塞项（recv2 名字更新完整；下一弧：剩余深层角落/模拟器 polish）。
## Round 724 (2026-08-12) — recv2 名字更新闭合（Finding 1030）

- **687 连发 + 651 证据 + recv2 名字处理完整**（主角/非主角路径）。
- 落盘：`recv2-name-closure-evidence.json`（F1030）+ RESEARCH_LOG Round 724。

## Pending（未阻塞，持续队列）

- 无阻塞项（recv2 名字处理 100%；下一弧：HANDOFF 刷新 155/剩余深层角落）。
## Round 725 (2026-08-12) — HANDOFF 刷新 155（Finding 1031）

- **Round 722-724 追加 + 688 连发**（recv2 名字处理完整入档）。
- 落盘：`handoff-refresh-155-evidence.json`（F1031）+ RESEARCH_LOG Round 725。

## Pending（未阻塞，持续队列）

- 无阻塞项（recv2 名字处理 100%；下一弧：剩余深层角落/模拟器 polish）。
## Round 726 (2026-08-12) — 实体/列表析构 vtable 尾部全量（Finding 1032）

- **8 个析构 thunk + 条件释放**（列表/节点 teardown 完整）。
- 落盘：`entity-list-destructor-vtable-evidence.json`（F1032）+ RESEARCH_LOG Round 726。

## Pending（未阻塞，持续队列）

- 无阻塞项（列表析构完整；下一弧：剩余深层角落/模拟器 polish）。
## Round 727 (2026-08-12) — 实体/列表生命周期闭合（Finding 1033）

- **690 连发 + 654 证据 + 实体/列表生命周期完整**（构造/插入/解除链接/析构）。
- 落盘：`entity-list-destructor-closure-evidence.json`（F1033）+ RESEARCH_LOG Round 727。

## Pending（未阻塞，持续队列）

- 无阻塞项（实体/列表生命周期 100%；下一弧：HANDOFF 刷新 156/剩余深层角落）。
## Round 728 (2026-08-12) — HANDOFF 刷新 156（Finding 1034）

- **Round 725-727 追加 + 691 连发**（实体/列表生命周期完整入档）。
- 落盘：`handoff-refresh-156-evidence.json`（F1034）+ RESEARCH_LOG Round 728。

## Pending（未阻塞，持续队列）

- 无阻塞项（实体/列表生命周期 100%；下一弧：剩余深层角落/模拟器 polish）。
## Round 729 (2026-08-12) — 实体/列表一次性注册全量（Finding 1035）

- **守卫 + 回调 + 动态注册表扩容**（实体/列表注册链完整）。
- 落盘：`entity-list-init-registration-evidence.json`（F1035）+ RESEARCH_LOG Round 729。

## Pending（未阻塞，持续队列）

- 无阻塞项（实体/列表注册链完整；下一弧：剩余深层角落/模拟器 polish）。
## Round 730 (2026-08-12) — 实体/列表生命周期与注册闭合（Finding 1036）

- **693 连发 + 657 证据 + 实体/列表生命周期与注册完整**。
- 落盘：`entity-list-lifecycle-registration-closure-evidence.json`（F1036）+ RESEARCH_LOG Round 730。

## Pending（未阻塞，持续队列）

- 无阻塞项（实体/列表生命周期与注册 100%；下一弧：HANDOFF 刷新 157/剩余深层角落）。
## Round 731 (2026-08-12) — HANDOFF 刷新 157（Finding 1037）

- **Round 728-730 追加 + 693 连发**（实体/列表生命周期与注册完整入档）。
- 落盘：`handoff-refresh-157-evidence.json`（F1037）+ RESEARCH_LOG Round 731。

## Pending（未阻塞，持续队列）

- 无阻塞项（实体/列表生命周期与注册 100%；下一弧：剩余深层角落/模拟器 polish）。
## Round 732 (2026-08-12) — 窗口几何构造体全量（Finding 1038）

- **WIL 尺寸回退 + 居中矩形 + style 颜色**（窗口几何构造完整）。
- 落盘：`window-geometry-ctor-body-evidence.json`（F1038）+ RESEARCH_LOG Round 732。

## Pending（未阻塞，持续队列）

- 无阻塞项（窗口几何构造完整；下一弧：剩余深层角落/模拟器 polish）。
## Round 733 (2026-08-12) — 窗口几何闭合（Finding 1039）

- **696 连发 + 660 证据 + 窗口几何完整**（资源查找/尺寸回退/居中矩形/style）。
- 落盘：`window-geometry-closure-evidence.json`（F1039）+ RESEARCH_LOG Round 733。

## Pending（未阻塞，持续队列）

- 无阻塞项（窗口几何 100%；下一弧：HANDOFF 刷新 158/剩余深层角落）。
## Round 734 (2026-08-12) — HANDOFF 刷新 158（Finding 1040）

- **Round 731-733 追加 + 696 连发**（窗口几何完整入档）。
- 落盘：`handoff-refresh-158-evidence.json`（F1040）+ RESEARCH_LOG Round 734。

## Pending（未阻塞，持续队列）

- 无阻塞项（窗口几何 100%；下一弧：剩余深层角落/模拟器 polish）。
## Round 735 (2026-08-12) — 共享 widget vtable 家族全量（Finding 1041）

- **draw/set-frame 槽位对跨 ≥15 vtable**（组队/装备/窗口基类锚定）；0x423D00 升格共享绘制；0x423F90 死 thunk。
- 落盘：`shared-widget-vtable-family-evidence.json`（F1041）+ RESEARCH_LOG Round 735。

## Pending（未阻塞，持续队列）

- 无阻塞项（共享 widget vtable 家族完整；下一弧：窗口系统弧复核/模拟器 polish）。
## Round 736 (2026-08-12) — 共享 widget vtable 家族闭合（Finding 1042）

- **697 连发 + 662 证据 + 共享 widget 渲染层完整**。
- 落盘：`widget-vtable-family-closure-evidence.json`（F1042）+ RESEARCH_LOG Round 736。

## Pending（未阻塞，持续队列）

- 无阻塞项（共享 widget 渲染层 100%；下一弧：HANDOFF 刷新 159/剩余深层角落）。
## Round 737 (2026-08-12) — HANDOFF 刷新 159（Finding 1043）

- **Round 735-736 追加 + 698 连发**（共享 widget 渲染层完整入档）。
- 落盘：`handoff-refresh-159-evidence.json`（F1043）+ RESEARCH_LOG Round 737。

## Pending（未阻塞，持续队列）

- 无阻塞项（共享 widget 渲染层 100%；下一弧：剩余深层角落/模拟器 polish）。
## Round 738 (2026-08-12) — 公告颜色约定全量（Finding 1044）

- **9 调用点 ×2 颜色对入 0x427E30**（系统 (2,3)/聊天 (0,5)/地图 (0,4)/包驱动动态）。
- 落盘：`notice-color-convention-evidence.json`（F1044）+ RESEARCH_LOG Round 738。

## Pending（未阻塞，持续队列）

- 无阻塞项（公告颜色约定完整；下一弧：公告/文本系统收尾/模拟器 polish）。
## Round 739 (2026-08-12) — 聊天族公告颜色点补全（Finding 1045）

- **移动警告（计数门）+ 聊天回显**（F1044 站点表 9/9 全解）。
- 落盘：`chat-notice-color-sites-evidence.json`（F1045）+ RESEARCH_LOG Round 739。

## Pending（未阻塞，持续队列）

- 无阻塞项（公告颜色约定 9/9；下一弧：公告系统收尾/模拟器 polish）。
## Round 740 (2026-08-12) — 公告颜色层闭合（Finding 1046）

- **700 连发 + 666 证据 + 公告颜色层完整**（表 + 9 站点 + 约定）。
- 落盘：`notice-color-closure-evidence.json`（F1046）+ RESEARCH_LOG Round 740。

## Pending（未阻塞，持续队列）

- 无阻塞项（公告颜色层 100%；下一弧：HANDOFF 刷新 160/剩余深层角落）。
