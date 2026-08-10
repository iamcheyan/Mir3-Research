# EI 3.0 原版 UI 覆盖矩阵

本文只统计“20 年前 EI 3.0 客户端”证据，不把现代 Zircon 的布局代码当作原版事实。最近核对：2026-08-10。
状态含义：

- `已恢复`：已有原版机器码/资源的坐标或结构证据。
- `候选`：能绑定原版资源或构造路径，但业务语义、状态或运行时顺序仍未完全确认。
- `待追踪`：目前只有资源族/全局控件线索，尚未恢复完整构造或绘制路径。

| UI 类别 | 原版资源/入口 | 当前证据 | 状态 | 仍需完成 |
|---|---|---|---|---|
| 800×600 主 HUD | `GameInter.wil` F50，`0x00427600` | `layout.json`、主 HUD 15 个按钮 | 已恢复 | 运行时截图与最终 z-order |
| HP/MP/经验 | `GameInter.wil` F60/F61/F63 | 主 HUD 资源、固定 Rect、`0x00429740` 比例链、`0x00466800/0x004542F0` 合成调用 | 候选（比例链已恢复） | 运行时确认全局字段的 HP/MP/EXP 命名、精确纹理裁剪方向和最终 z-order |
| 怪物目标框/悬停目标 | 代码绘制合成体（无独立 WIL 帧），锚定 `HUD+0xE4/+0xE8` | `target-box-evidence.json`（Finding 239）：名字牌框 `0x40B850`（0xA0A0A 边框、宽=文本宽、高 15px、锚上方 15..30px、水平居中，每帧 `[HUD vt+0x84]` 以当前目标为 ecx @`0x41C063`）、名字文本 `0x40B750`（选择器 `0x566DD4` F2/F3，锚+(7,−0x38)）、悬停名牌 `0x40BB00`（3000ms）、HP 条 `0x40A8A0`（元素 `0x5600FC+[8D]*0x144`、帧=HP 值、400/300 中心公式）、悬停实体重绘 `0x437DF0`；布局矩形 HP `+0x629FC`/状态 `+0x629EC`（`0x40F5F0` 每帧）；锚点两路径：世界推导 48×32 瓦片公式（视口常量 0xC8/0x9D）或固定 (376,227) `0x4120B0`；悬停 msg 0xB → `0x40A4D0` 选择器装载（类型库 `0x449B90`/`0x8AA5A8`）→ 服务端目标询问 0xBC7/0xBD1/0xBD8；点击设目标 msg 2 → 0xBC4；切换 800ms 超时 + 鼠标位移 >5 门控；显示门控状态机 `0x411D91`（状态 0x15..0x1F） | 已恢复（结构/几何/公式 primary-static） | 名字帧 F2/F3 与 HP 条帧的选择器 WIL 运行期绑定（GameInter.wil 1103 帧、无 ≥10000 帧=负证据；Horse.wil max_end=10400 为 10000+(A%400) 系列唯一候选）、目标头像帧源（49×33 区存在性 primary-static、纹理 candidate） |
| 技能窗口/技能类别 | `Magic.exp`、GameInter F400/F410–465 | `skill-window-context.json`、`skill-window-render-loop-evidence.json`、`0x00439250/0x0043A440` | 候选（11 组控件帧对、固定相对位置、15px 行距、Magic.exp 读取链已恢复） | 运行时技能列表、文字字段与图标业务映射 |
| 人物状态/装备槽 | GameInter F200，11 条连续几何记录，**8 个装备槽 38×38 几何闭合（Finding 240）**：SetRect 链 `0x44B1BC-0x44B2C6`（loop0 头盔 (177,70)、loop1 火把 (27,264)、loop2 毒药 (64,264)、loop3 左手镯 (27,186)、loop4 右手镯 (175,186)、loop5 左戒指 (27,227)、loop6 右戒指 (175,227)、loop10 鞋子 (103,264)，绝对=+(278,136)）；非槽区 loop7 头像/名区 49×33、loop8 纸娃娃 60×90、loop9 属性面板 53×84 | `status-window-render-evidence.json`、`equipment-slots-evidence.json`、`0x0044B6B0/0x0044B720/0x004341F0`；图标帧=物品 shape `WORD[graphics+0x28]` 非槽位索引 | 已恢复（几何 primary-static） | 装备索引业务命名（服务端 EquipmentSlot 枚举 candidate：记录配对 2↔loop1/3↔loop0/9↔loop2/10↔loop10 vs 枚举语义 2=头盔/3=火把/9=鞋子/10=毒药 待运行时裁决）、el82/83/139 运行时 WIL 绑定 |
| 背包 | GameInter F250，6×6、36 px 网格；Interface1c F267/268 角色图候选；右侧竖直量条（共享控件 `0x4179B0`，GameInter F280=16×424，填充区 12×218，量程上限 `0x5E`=94，绘制于 `(winx+0xF8, winy-0xA5)`，填充值 `[this+0x58]` 本构建从未写入→空条） | `inventory-window-render-evidence.json`、`layout.json`、`0x0042F150/0x0042F2A0`、`0x0042EB4B/0x0042EBB0` | 候选（几何、动态字段和选中合成链已恢复；Frame 94 之谜已闭合=量条量程） | 主数值和打包字段的服务端语义；第三资源不是普通按钮 |
| 任务 | GameInter F700；列表 19 行/15px、行坐标 `(winx+0x41, winy+0x5A+15·row)`、滚动模型 `this+0x58`/`this+0x5C`/`this+0x60`（滚轮 `0x448700` 递减、点击 `0x448780` 递增、正文命中区 (80,310)-(250,380)）、详情 Frame 705=204×76 完整面板 @(65,294)、正文 3 行/15px/深蓝 0x7D0000、帧 721 绿X/722 金X/723 绿箭头/724 金箭头、事件孪生 0x418（标记选中、门控 `+0x20C==0`）/0x419（点击空正文子记录） | `quest-window-render-evidence.json`、`layout.json`、`0x00447470/0x0044760B/0x00448580/0x00448700/0x00448780/0x00451A10/0x00451A40` | 已恢复（滚动模型、几何、像素态与事件链闭合） | 0x418/0x419 业务名（Mud3 二进制无源码）、字段分隔符字符（记录类内部） |
| 商店/购买 | GameInter F1000、F1001–F1003；F1000 五行列表、F1001 紧凑网格、F1002 宽组合、F1003 当前副本空帧 | `store-window-render-evidence.json`、`store-state-graph.json`、`0x0044E9B0` 状态机、Mud3 商店 NPC 交叉表；**点击/打开/paint 全链已闭合（Finding 232）**：open-all `0x427600` 参数 `(2, fr=selector+0x5898, 0x3E8, 0, 0, 0x12C=300, 0x130=304, 0)`、点击分派 `0x42BB00` id2→pre-open `0x44EF00`（state∈{0,1,3,4}→+0x5FC 双矩形 hit-test 命中即 `[+0x700]=([+0x65C]−1)×[+0x608]`；state∈{2,5,…}→侧面板 +0x1BC/+0x270/+0x324/+0x3D8 hit-test）→`0x42B6A0` 商店特例 `0x44E910`（state1 rect(+0x18+0x12C,+0x1C+0xD0,+0x20,+0x24)、state4 rect(+0x18+0x12C,+0x1C+0x64,…)）命中列表区即拒开（可点选物品）；paint `0x44E260`（基类→0x417830×6 面板重定位→8 主面板 0xB4 步长循环→状态分派 {0,4,1,3}→0x44D590/{1,2}→0x44DB50/{4}→0x44E040）；商店 `+0x30` 从不被写（0x44F6C3/0x44FD5E 是物品列表构建循环记录字段），基类 paint 门控备选路径归地图类 | 各面板控件最终坐标与按钮业务名、通过客户端状态/协议参数区分 NPC 商店、仓库、买卖、选中物品和扩展面板 |
| 交换 | GameInter F1050 | `exchange-window-render-evidence.json`、`0x004159D0/0x00415B10` | 候选（左右分区与 6×5 格已恢复） | 确认按钮、协议状态和窗口最终原点 |
| 仓库/存取 | GameInter F1000、F1002/F1003 状态分支候选 | `store-window-render-evidence.json`、`store-state-graph.json`、`0x00423E80` 工厂调用、Mud3 `NPC_Storage` 交叉表；点击/打开链与商店共用（0x42BB00→0x44EF00→0x42B6A0→0x44E910，见商店行；open-all 尺寸 300×304） | 候选（服务端仓库入口、状态控件门控、选中记录链和点击打开链已确认） | 把 state 0–4 与客户端业务入口绑定，确认仓库屏幕原点和按钮语义 |
| NPC 对话 | GameInter F1100/F1101/F1102，`0x0043ED00/0x0043F040/0x0043F460`；Interface1c NPCFace.WIL | `npc-window-render-evidence.json`；`0x00440750–0x00440AA0` 已恢复 `\\`、`{}`、`@...>` token 解析、16 项上限、14/21 px 行距、共享布局字段和三个动态控件位置；**文字绘制已闭合**：`0x0043F460` 白 0xFFFFFF GBK 换行、窗口相对 (x+0x96, y+0x28)、行距 textheight+5、滚动窗 `[+0x3BC]..[+0x3BC]+[+0x594]`、全局节点链表 0x8B1AE4（vtable 0x47694C）；**对象模型已闭合**：ROOT=静态全局 0x47EF18，winmgr=ROOT+0x2A548C，统一窗口 id 空间（模型=id 9 @+0x51150、帧=id 11 @+0x516E8，绘制表 0x428358/关闭表 0x42B938/显示切换 0x42ADB0/输入分派 0x42C4D4 共用），显示=切换（`[window+0x30]`），模型输入 0x440290→ROOT hide-all 0x41C1E0 关闭对话，帧窗口 0x447470 自绘选项列表（≤19 行，+0x1E0 列表类 0x476A68），选项点击→0x451A40 事件 0x419；打开链 0x41FE31（消息表索引 16）；1102 当前副本为空 | 已恢复（文字绘制、窗口分派、显示/隐藏、输入与点击事件链闭合） | 帧选项列表的填充函数（0x41FE31 尾段/0x4473E0/逐开填充）、0x418/0x419 业务名（Mud3 二进制无源码）、三个控件按钮业务名、动态条目字段最终语义 |
| 组队 | GameInter F900，成员两列 100 px、行距 20 px | `social-window-render-evidence.json`、`0x004243D0` | 已恢复 | 成员字段文字/图标顺序与运行时上限 |
| 行会 | GameInter F600，单列最多 18 行、滚动行高由字体度量决定 | `social-window-render-evidence.json`、`0x00425280` | 候选 | 4 个控件寄存器流坐标、标签页语义、特殊行颜色 |
| 聊天 | GameInter F350 | `chat-window-render-evidence.json`；6 个固定频道/命令位置、GBK 字符串、文字起点 `(40,29)`、实际 `14px` 视觉行距，以及通用控件 `control+0x34` 字符串字段绑定已从绘制/构造链恢复 | 已恢复 | 共享控件究竟把频道字符串绘为标题、提示还是命令说明；字体颜色、滚动状态 |
| 好友/社交列表 | 当前 15 个通用窗口构造及主 HUD 控件清单中无独立好友窗口/按钮；行会 F600 与 Interface1c 动态簇仍是候选承载者 | `social-window-render-evidence.json` 的 `friend_entry_audit`、全局控件目录 | 静态范围已排除独立构造，功能入口待追踪 | 从行会页签、动态分配路径或 Interface1c 状态入口确认好友页 |
| 系统设置 | GameInter F750 | `system-window-render-evidence.json`、`0x00441B30/0x00441F40` | 已恢复 | 音频引擎其他播放路径是否复用两个音量全局；Frame 750 外的运行时覆盖层 |
| 坐骑 | GameInter F850、860–867 | `horse-window-render-evidence.json`、`0x004269C0/0x00426A80` | 候选（坐标、韩文标签、命令绑定和状态字节引用已恢复） | `0x007DA060` 的运行时枚举/位语义；窗口管理器是否叠加 Frame 850 外状态层；`@遛马` 的最终服务端语义 |
| 小地图/地图 | `MMap.wil`、`FMMap.wil`，`0x0043D4D0/0x0043D780`；服务器 `MiniMap.txt` 映射 | `map-ui-resource-evidence.json`、`minimap-server-crossref.json`；小地图 `(672,0)-(800,128)`；`0x0043DE40` 明确切换 `256×256/128×128` 表面模式；绿色/黄色标记分支已确认；地图 Paint 未发现独立 GameInter 边框调用；**绑定闭合（derived）**：`0x0043D780` 选择规则（map_id≥1000→FMMap.wil frame map_id−1000，否则 MMap.wil frame map_id）+ MiniMap.txt 交叉引用 182 行 → `map_bindings.json`；模拟器地图切换同源驱动 bg+minimap（`MAP-SURVEY.md` C21） | 候选→**derived**（资源、固定小地图 Rect、直接合成链、模式切换、颜色层、182 条 map→library/frame 绑定已恢复） | 运行时确认是否有外部/烘焙边框；完整地图专用 UI 容器、打开入口、缩放/滚动和切换命令语义；标记对象类型；小地图帧内留白逐图校准（P6） |
| 角色选择/创建 | Interface1c F50，`0x004026E0/0x00456CB0`；已直接读出 `选择角色/创建账号/修改密码/创建角色/删除角色/开始游戏` | `interface1c-*-context.json`，`/ui` 次级预览 | 候选（按钮文字已由原版像素确认） | 运行时状态转换、Frame 17/57 空资源差异和剩余按钮语义 |
| 公告/提示/确认框 | GameInter F602/F603/F604/F605–607、确认框 F950、`0x00418030`/`0x0043E260` | `notice-prompt-window-evidence.json`、`confirmation-prompt-evidence.json`；确认框单例 0x7E04C8 全解码（ctor 0x418030 8 参数、居中锚 400×246、三按钮、键盘/激活链 SendMessageA 0x7EE、7 调用方原串 GBK/cp949）；按钮类静态 vtable 0x4763A8 状态机；通知框 0x43E260（602 双用户含横幅单例 0x777200、603/604/605 负证据未使用、btn2 (603,137)）；公告父窗口 `(107,110)-(691,362)` 与 `[行会公告]/[行会修改]` 原版 GBK 文字由静态绘制调用闭合 | 已闭合（Finding 233–238） | 主游戏窗 0x7EE 最终业务处理（candidate，不影响布局/绘制/输入） |
| 普通/悬停/按下状态 | 各控件 frame pair | `layout.json`、控件资源交叉表 | 候选 | 运行时输入和状态切换验证 |
| 绘制层级 | `0x00423D00`、`0x004179B0`、`0x0043F040`、`0x004280F0` | `draw-order-evidence.json`；已确认窗口基类背景先于本窗口派生绘制/子控件，并确认可见窗口链表按 ID 分派专用 Paint 后逐节点前进 | 候选（跨窗口规则已恢复） | 真实运行时窗口列表样本与遮挡截图 |
| 交互式模拟器交付 | `Tools/mir3_client_simulator/`（`/sim`），数据模型 `data/*.json`（windows=14 controls=37 resources=157 equipment_slots=8，hud.target_box 已入模型） | `app.js`/`index.html`/`style.css`/`build_mir3_simulator_data.py`；证据模式覆盖层按等级着色；冒烟测试 33/35（2 项测试口径） | 已交付（candidate 几何显式标注） | 场景/商店/装备业务语义、未闭合窗口原点仍 pending |

## 当前硬性原则

1. 原始客户端目录只读；所有分析结果写入本目录的 JSON/Markdown。
2. `primary-static` 只表示机器码/资源直接证据，不等于运行时确认。
3. 坐标表达式异常、超出父窗口或寄存器复用不清时，保留原始表达式并降级状态。
4. 预览器的候选层可以帮助检查视觉布局，但不能反过来证明原版坐标。
5. 每完成一个类别，都要同步更新本矩阵、`RESEARCH_LOG.md` 和 `layout.json`。
