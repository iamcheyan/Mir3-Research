# Mir3 EI 3.0 原版客户端 UI 还原工程交接文档

更新时间：2026-08-10

## 1. 工程目标

本工程不是单纯制作一个静态截图，也不是只还原底部操作栏。最终目标是：

1. 以 20 年前 EI 3.0 原版 Mir3 客户端为唯一主要事实来源，恢复完整的 800×600 客户端 UI。
2. 通过原版 EXE 反汇编、WIL/WIX 贴图、DAT 数据和运行时/静态调用关系，推导真实窗口坐标、控件坐标、图层顺序、素材帧、按钮状态和显示条件。
3. 在 Zircon 中逐步实现可运行的原版布局。
4. 同时交付一个独立可打开的 HTML 网页模拟器：固定 800×600 逻辑画布，使用真实原版贴图和已推导坐标，模拟整个客户端的视觉布局和基本操作手感。

网页模拟器必须能表现：人物、怪物、地图、底部 HUD、血蓝、经验、罗盘、聊天、技能、背包、装备、人物状态、任务、NPC、商店/仓库、提示框、系统窗口等。鼠标指向怪物时应显示目标头像/目标信息；点击人物或打开人物窗口时应显示人物装备；窗口、按钮、背包格、技能格和地图区域都应可点击或产生明确反馈。

## 2. 重要事实来源

原版客户端：

```text
/home/tetsuya/NAS/TMP/EI传奇3.0客户端/Mir3.exe
/home/tetsuya/NAS/TMP/EI传奇3.0客户端/mir3.dat
/home/tetsuya/NAS/TMP/EI传奇3.0客户端/Data/GameInter.wil
/home/tetsuya/NAS/TMP/EI传奇3.0客户端/Data/GameInter.wix
/home/tetsuya/NAS/TMP/EI传奇3.0客户端/Data/Interface1c.wil
/home/tetsuya/NAS/TMP/EI传奇3.0客户端/Data/Interface1c.wix
```

项目研究资料：

```text
docs/research/ei-ui-layout/
Tools/reverse-engineering/extract_mir3_ui_layout.py
Tools/reverse-engineering/enrich_mir3_layout_evidence.py
Tools/reverse-engineering/verify_mir3_ui_evidence.py
Tools/web/wilviewer.py
```

不要把现代 C# Zircon 的坐标直接当作原版事实。Zircon 代码只能作为待修改目标、名称线索或功能参考；原版坐标必须标记来源和证据等级。

## 3. 当前已完成成果

当前验证基线：

```text
核心原版文件：6/6（verify 统计口径；8 个核心文件实测在场，含 MMap.wil/FMMap.wil）
布局记录：29
标准化绘制调用：60
专项控件矩形：22
内容分类：18
JSON 证据文件：63
尚未完全闭合的证据项：36
```

已经建立或完成初步证据的部分包括：

- 800×600 主视口和底部 HUD。
- GameInter.wil 的底部金属底板、血球、蓝球、经验条、罗盘和按钮资源。
- 窗口初始化、窗口显示/隐藏调度、绘制顺序和窗口提升关系。
- 技能窗口的 11 组按钮帧及相对位置。
- NPC 对话文本扫描、换行、颜色/模式和文本区域布局。
- 商店/仓库 0～4 状态图、状态切换和部分控件帧。
- 聊天、马匹、背包、人物状态、任务、NPC、技能等窗口的资源层预览。
- 社交/角色选择/部分 Interface1c 资源族。
- ID15 通知/提示窗口候选资源和位置。
- 确认框调用者，包括支付金币、丢弃金币、连接断开、返回人物选择、行会提示等。
- 机器可读的 `layout.json`、`ui-coverage-matrix.json` 和各窗口 evidence JSON。

NPC 对话窗口对象模型（2026-08-10 会话闭合，`RESEARCH_LOG.md` Finding 219–228）：

- **VA 映射修正**：PE 节表 vaddr==raddr，fileoff = VA − 0x400000；旧的 `fileoff = VA − 0x3FF000` 作废（disasm 工具始终走节表，代码结论不受影响）。
- **ROOT = 静态全局对象 @ 0x47EF18**（.data/BSS），UI 初始化 0x4570A0 把 ROOT 指针写入 `[0x8AB820]/[0x8B1870]`，`[0x8B1878]=3`。
- **统一窗口 id 空间 0..15**：模型 = id 9（winmgr+0x51150）、帧窗口 = id 11（winmgr+0x516E8）；绘制表 0x428358、关闭全部 0x42B938、显示切换 0x42B3E4、输入分派 0x42C4D4 共用同一 id。旧的“每表独立 id”与旧关闭表（id 8→+0x51150）作废。
- **对话文字绘制 = 0x43F460**（this=winmgr+0x51150）：白 0xFFFFFF（0x47C4D8）、GBK 换行、窗口相对 (x+0x96, y+0x28)、行距 textheight+5、滚动窗 `[+0x3BC]..[+0x3BC]+[+0x594]`、遍历全局节点链表 0x8B1AE4（节点 vtable 0x47694C）。纹理 paint 0x43F040 只管帧 1100/1101/1102 图像合成。
- **显示 = 切换（toggle）**：0x42ADB0 读 `[window+0x30]`（模型 = ROOT+0x2F660C）决定加入/移出打开列表（0x42AC30/0x42AC50）并调 vtable+0x10（模型 0x43F020→0x423F80；帧 0x4488B0）。
- **绘制分派 0x4280F0**（this=winmgr）：只画打开列表中的窗口，id 分派表 0x428358，之后 0x42AAB0 鼠标命中 → 第二遍表 0x428398；任一可见 → `[0x4762AC]` present。
- **输入分派**：0x42BEAA → 0x42AAB0 命中 id → 0x42C4D4 二级表；模型 handler 0x440290（滚动/面板），成功后 `mov ecx,0x47ef18; call 0x41c1e0` = ROOT hide-all 关闭对话；0x43AB50 = 模型滚动拖动（非 handler，旧归属作废）。
- **帧窗口**：ctor 0x4471D0（2 控件 +0x74/+0x128）、paint 0x447470 自绘选项列表（+0x1E0，类 vtable 0x476A68，≤19 行）、handler 0x447FA0（选项行悬浮/点击）→ 0x451A40 事件 **0x419**（装配 0x452940、发送 0x451E60）；打开链 0x41FE31（消息表 0x421E8C 索引 16，show id 9）；点击缓冲 = 索引 13（0x41FD36）。
- **vtable 重转储**：0x476938（模型 5 槽）、0x47694C（节点）、0x476950（id-12 类）、0x476A54（帧 15 槽）、0x476A68（选项列表）、0x476624（基类）、0x476864（打开列表）。

**帧选项列表填充链闭合（同会话）**——服务端消息 **0x515**：

- **子协议分派 0x4218F2**：ids 0x44D..0x520；`lea edi,[eax-0x44d]; cmp edi,0xd3; ja noop; mov dl,byte[edi+0x42219c]; jmp [edx*4+0x422168]`。字节表 0x42219C（默认 0x0C=noop 0x421D3F）→ 处理表 0x422168 12 项：0x44D→0x421C81、0x4B0→0x421913（发 **0x40C**）、0x514→0x421BBC、**0x515→0x421A45**、0x516→0x421AF5、0x517→0x421A85、0x518→0x4219A0（存 ROOT+0x35A410/414/418）、0x519→0x421BA7、0x51A..0x51D→0x421CFC、0x51E→0x421B5B、0x51F→0x421955、0x520→0x421C23。
- **0x421A45（唯一调用点 0x421A7B）**：`lea ecx,[ebx+0x2f6b74]`（帧=winmgr+0x516E8=ROOT+0x2F6B74）；0x452810 拷 0x2000 正文到栈；`push count; push body; call 0x4488d0`。
- **0x4488D0(frame, body, count) 逐行填充**：0x468B1A 分配 0x630B 描述符 → 0x468BF0 按 '/' 切分（≤4 字段，栈内就地 NUL 截断）→ 整段 body 拷入 desc+4 → 描述符字段 `+0x204` len、`+0x22C` len2、`+0x230` 字段2文本、`+0x214` 有字段2 标志、`+0x208/+0x20C` 动作标志清零、`+0x210` hover → **0x449870(list=frame+0x1E0, desc) 追加** → 结束后 `[frame+0x54]=1`（已装载）、`[frame+0x5C]=count`、0x449060 重排。
- **0x449870 = 通用链表追加**（类无关）：0xC 节点 `[0]=data,[4]=next,[8]=prev`；共享调用点 0x41538F / 0x42AC3B（打开列表追加）/ 0x448ABA / 0x4491B6 / 0x44933E；列表 ctor 0x4498E0 写 `[list]=0x476A68`；帧链表头 `+0x1E0`（头 `+0x1E4`、游标 `+0x1E8`、尾 `+0x1EC`、计数 `+0x1F4`），重置/销毁 0x448EF0。
- **帧显示 0x4488B0（vtable+0x10）**：`[frame+0x30]=激活标志`；激活且 `[frame+0x54]==0`（未装载）→ 0x4519E0 发 **0x416** 请求内容（0x8AB828 消息构造对象，正文 @+0x18）。
- **定位+显示 0x42B6A0(id,x,y)**：0x42B820 关全部 → 0x42AC50 移除 → 0x42AC30 重加（置顶）→ `[winmgr+0xD3C]=1` → 0x423F90(1) 可见 → 0x4240C0(x,y) 定位；**0x4240C0 仅当 `+0x30`(激活,写 0x423F80)/`+0x34`(可见,写 0x423F90)/`+0x3C`(使能) 全非零**才写 `+0x48/+0x4C` 相对偏移；id 偏移表 @0x42B7E0 与统一窗口 id 空间一致；帧经 0x42BCEF（先 0x448230 帧键 handler，未处理则定位+显示 id 11）。
- **0x448120–0x448190 尾段**：悬浮行描述符 → `[frame+0x6C]=desc+0x220`（显示文本指针）；文本空（`byte[+0x220]==0`）→ 0x448148 调 0x451A40 发 **0x419**（参数 `[desc+0]` 动作码、`[[frame+0x1E8]→[0]]` 数据）；游标推进 `[frame+0x1E8]=next-node`；子列表 `[desc+0x228]`（`[+8]`→首节点、`[+0x10]` 逐帧自增=走马灯）。
- **消息构造族**：0x452940 头装配（dest+0 dword、+4..+0xA 5 word）、0x451E60 发送（++0x14 序号循环 1..9、0x4528E0 头→+0x24、0x46811C 组包）；0x451A40=msg **0x419**、0x4519E0=msg **0x416**、0x451740=msg **0x3F2**（0x41D744 每 500ms 节流、模型未激活且 `[ROOT+0x364444]` 非空时发）、0x4521B0=msg **0x3F3**（0x41B94F：从 ROOT+0x2F6630 保存正文发）。
- **0x42B820 调用点**：0x42ADB6（显示切换前置）、0x42B6B3（定位+显示前置）、0x42BD8F（输入分派前置）——即任何窗口打开前先关全部。

**窗口状态模型（三标志）**：`+0x30` 激活（0x423F80）、`+0x34` 可见（0x423F90）、`+0x3C` 使能；paint 0x4280F0 只画打开列表成员，0x4240C0 定位要求三标志齐备。

**点击打开全链闭合（同会话续，`RESEARCH_LOG.md` Finding 232）**：

- **open-all 尾段全表**（0x4276D0..0x427983，`[esi+0x1c]`=selector+0x5898=70 条工作记录）：
  id 0 +0x6554→0x42EA80、id 1 +0x29CE4→0x44B130、**id 2 商店 +0x33188→0x44D310
  (2,fr,0x3E8,0,0,0x12C,0x130,0)**、id 3 +0x3399C→0x4159D0、id 4 物品 +0x4707C→0x424E60
  (4,fr,0x258,0x66,0x16,0x254,0x1BE,1)、id 6 背包 +0x47834→0x424250、id 8 聊天
  +0x507EC→0x414060(8,fr,0x15E,0x72,0x4C,0x23C,0x184,1,0)、id 7 +0x47C28→0x4503B0、
  id 0xC +0x518E0→0x440FE0、id 0xB 帧 +0x516E8→0x4473E0、id 0xD +0x52118→0x4268C0、
  id 0xE +0x524F0→0x439250、id 9 快捷栏 +0x51150→0x43ED00、隐藏窗 +0x53030→0x418910
  (id 0x64,fr,0x320,0xDA,0xB0,0x16C,0xB8,3)、id 0xF +0x52E5C→0x43E260；**arg6/arg7=w/h
  已用已知窗尺寸交叉验证**（聊天 572×388、物品 596×446、背包 256×244、快捷栏 552×176）。
- **0x42AAB0 = 顶层窗口解析**：`[winmgr+0xD38]` 计数、从列表尾向前按 id 跳转表 @0x42ABE8
  查可见/使能，返首个活跃 id 或 -1；调用者 11 处（含 WM paint 0x4282EE）。
- **0x42BB00(winmgr,x,y) = 点击打开分派器**：-1 → 关全部 + **0x42D720 热点方块 hit-test**
  （`[winmgr+0xD42]` 标志、+0xD44 起 6×0x10，每条 SetRect(rc,[e],[e+4],[e]+0x26,[e+4]+0x26)
  → PtInRect = 6 个 0x26×0x26 方块）+ `[winmgr+0x6518]`→0x43DDB0(+0x6214) 兜底；
  id 0..0xE 跳转表 @0x42BDE0 = 每窗 **pre-open 检查**（0→0x42FFD0、1→0x44CF00、
  **2→0x44EF00 商店 pre-open**、3→0x4171B0、4→0x425CB0、6→0x424730、7→0x450B50、
  8→0x414C60、9→0x440170、0xB→0x448230 帧键 handler、0xC→0x441970、0xD→0x426B50、
  0xE→0x43AC00；失败才 0x42B6A0(id,x,y) 打开/重定位）。
- **0x42B6A0 商店特例**：id 2 先 **0x44E910(store,x,y)** 命中列表区 → 拒绝打开（可点选
  物品不重定位）；未中 → 0x423F90(1) + 0x4240C0 定位。
- **0x44EF00 = 商店 pre-open**：state∈{0,1,3,4} → 0x417D00(+0x5FC) 双矩形 hit-test
  （+0x24/+0x34 rect、GetTickCount−[+0x44]≤0xA 防抖）命中 → `[store+0x700]=([store+0x65C]−1)
  ×[store+0x608]` ret 1，未中 → 主面板 +0x54/+0x108 hit-test；state∈{2,5,…} → 侧面板
  +0x1BC/+0x270/+0x324/+0x3D8 hit-test。**0x44E910**：state==1 rect(+0x18+0x12C,
  +0x1C+0xD0,+0x20,+0x24)、state==4 rect(+0x18+0x12C,+0x1C+0x64,…) PtInRect。
- **商店 paint 0x44E260 全解码**：基类 paint → 状态面板重定位（0x417830 ×6，+0x54 基准区
  0xB4 步长 8 主面板）→ `call [panel_vtbl+4]` 绘制循环 → 状态分派 {0,4,1,3}→0x44D590、
  {1,2}→0x44DB50、{4}→0x44E040。
- **商店 +0x30 疑案结案**：0x44F6C3/0x44FD5E 的 `[ebp+0x30]` 是**物品列表构建循环**
  （0x44F5AB..0x44F70A/0x44FD30..，逐记录 0x4681F9）的记录字段，非 paint-enable；商店
  +0x30 从不被写（基类 paint 门控 → 0x423E6C 备选 3D 路径为地图类窗口），商店背景由
  状态 paint 族承担。
- **selector 初始化 0x452AA0**：fn B 0x452B20 拷 Mir3.exe .data 串（0x47D51C/0x47D508/
  0x47D4F4…）→ +0xB130 起 14 路径槽（0x104 步长）；loop A1 0xE 次 0x4660E0(+0x144*i,
  +0xB130+0x104*i,1)；**loop A2 0x46=70 次 0x4660E0(+0x5898+0x144*i, +0xF848+0x104*i,0)**
  —— 70 条记录源表 +0xF848 → 工作数组 +0x5898；mir3.dat 内源表零填充、运行时解析。

**子协议同族全闭合（同会话续）**——0x416 发送族与全部同族 handler 解码：

- **0x416 发送族 = 同一帧窗口的加载器家族**：0x4488B0（显示，vtable+0x10）、
  0x448B10（子列表追加）、0x4491D0（幂等插入）、0x449390（子列表替换）全部以
  ROOT+0x2F6B74 为 this，未装载（`[frame+0x54]==0`）时经 0x4519E0 发 0x416 请求内容；
  **0x449870 同族填充点 0x4491B6/0x44933E 位于 0x4491D0 幂等插入函数体内部**——
  先前“商店/仓库/交易候选”假设撤销。
- **0x449060 重排**：抽干链表 → 按 `[desc+0]`（数字 id）冒泡升序（0x449158..0x44919F）
  → 清零 `[desc+0x208]` → 0x449870 重追加；选项列表按 id 有序。
- **0x4491D0 = 幂等插入**（任务日志加项）：逐行 '/' 切分 → 0x449680 链表查重
  （`[desc+0]==首字段`）→ 已存在返 0；新 0x630B 描述符 → 0x449870 → 重排；
  `[frame+0x5C]=count`、`[frame+0x54]=1`。
- **0x448B10 = 子列表追加**（行 `+0x228` 子列表，vtable **0x476A6C**，子项 0x620B
  内联追加）；**0x449390 = 子列表替换**（按首字段查行，无子列表则建）；**0x448D90 =
  子项选中**（`子项+0x21C`=1、文本拷 `+0x220`）。
- **0x401390 = 8 项颜色表**（跳转表 @0x4013D8）：0/0x0A0A0A/白/红/绿/0xFF9696/
  0x50FFFF/0x80FF。**0x427E30(winmgr, c1, c2, fmt) = 聊天行打印**：聊天窗 id 8
  （winmgr+0x507EC）→ 0x4144A0(c1, fmt, c2)，文本经 0x45E200 渲到 DC 0x8AB7A8。
- **0x47B1xx 字符串簇**：0x47B15C/0x47B180/0x47B1A4 = **EUC-KR 韩文**（"새로운
  퀘스트가 시작 되었습니다." / "퀘스트 일지가 변경되었습니다." / "아이템을 모두
  가지고 있지 않습니다."），0x47B1C8/0x47B1EC = GBK 中文补丁（行会）→ 原版为韩文
  客户端，0x516/0x517 = **任务日志变更/新任务推送**（韩文聊天提示 + 帧内容更新）；
  帧窗口承载 NPC 对话选项 + 任务日志两类内容。
- **其余 handler 全解码**：0x514→标志字节 ROOT+0x35B148 + winmgr(+0x2F8780)
  vtable+0x88 通知 + 窗口 id 0x1D 开关；0x518→对象 3 word 存储（对象+0x61C90 或
  ROOT+0x35A410）；0x519→0x422E30 彩色聊天文本（`[ROOT+0x44]` 日志开关，
  Chat.txt "ab" 追加 "%s\r\n"）+ 0x4256A0(ROOT+0x2EC508)；0x51A..0x51D→0x40C
  记录排队 ROOT+0x364458（0x4561B0）；0x520→带时间戳对象注册 ROOT+0xE1184
  （tick 0x47630C）；0x44D→对象动作路由（id==当前 → winmgr vtable+0x38，否则
  0x41EB10 查对象 → 对象 vtable+0x38）；0x4B0→0x41B710 出站 **0x40C** 组装
  （scratch ROOT+0x428054，`[0x428064]=1`，4 word 经 0x401670 转储 0x428178 区）。

**确认框/通知框全闭合（同会话续，`RESEARCH_LOG.md` Finding 233–238）**：

- **确认框单例 0x7E04C8**：ctor 0x418030（8 args，ret 0x20）；基类 0x417FB0；
  参数图：arg1=res→+0x45C + SelectFrame(950)、arg2=类型 id→this+0（3=付款/扔金币、
  4=仅掌门、6=踢成员、9=建会、0x65=返回选人）、arg3=按钮模式（0=仅中 157/158、
  1=是(151/152)+否(154/155)、2=全无）、arg4=消息→+0x2C、arg5=msg 矩形变体
  （0→底 y+0x78 / 非0→y+0x64）、arg6/7=x,y（**双 −1 → ctor 内居中 0x41808D-0x4180C3，
  锚 400×246，帧 950=360×190 → 屏 (220,151)**）、arg8=word→+0x460（wparam 低字）。
  `[+0x28]=1`（可见）@0x418284。基类：3× 0x4175F0 按钮（+0x238/+0x2F0/+0x3A8，
  步长 0xB8）、+0x460=0xFFFF、+0x462=0（活动索引）。
- **按钮类 = 静态 vtable 0x4763A8**（父确认框 vtable 才是运行时构建）：[0]=0x4046C0 dtor、
  [1]=0x417640 paint、[2]=0x417780 hover、[3]=0x4177C0 press、[4]=0x4177F0 release。
  字段：+0x14=res、+0x18=hover 帧、+0x1C=pressed 帧、+0x20=normal 帧、+0x24=enabled、
  +0x25=state{0,1,2}、+0x28=x、+0x2C=y、+0x30=悬停标志、+0x34=label。
  paint 0x417640：正常 `[+0x25]==0 && [+0x24]==1` → SelectFrame(+0x20)；
  悬停 `[+0x30]!=0 ? +0x18 : +0x20`；按下 → +0x1C；全经 0x460240(0x8AB7A8, x, y,
  帧w, 帧h, 0x320, 0x258, 0xFFFF, 0xFFFF) 合成（帧 w/h 取 [res+0x38] 帧头）。
  release → `0x45AFC0(0x8AB130, 0x69, 0, 0, 0)`；**0x45AFC0=场景对象拾取器**
  （this+0x460 起 0x32=50 槽，[obj+0x3C] 匹配 → 0x45B900 分派 + 回写），非确认动作处理器。
- **键盘 0x418470**（经两个 wndproc 入口转发，ecx=this+8）：TAB 循环 0x462（步长 0xB8）
  跳过禁用；回车/空格 → **0x418520 激活**：`wparam = ((type<<8|idx)<<16) | tag`；
  MoveWindow/ShowWindow(`[0x8AA48C]` 输入框，鼠标+0xDF/+0x23A，0x162×0x10) →
  GetWindowTextA(→this+0x130, 0x104) → SetWindowTextA("") →
  **SendMessageA(`[0x8AB7B0]`, 0x7EE, wparam, this+0x130)**（同步，非 PostMessage）
  → `[0x8AA498]=1` → 基类复位。IAT 手工 thunk 全命名（0x47628C..0x476304）：
  MessageBoxA/SendMessageA/TranslateMessage/GetMessageA/PeekMessageA/ShowWindow/
  SetRect/PtInRect/SetFocus/MoveWindow/GetWindowLongA/RegisterHotKey/
  UnregisterHotKey/SetWindowTextA/SetCursor/LoadCursorA/SystemParametersInfoA/
  SetWindowPos/PostQuitMessage/LoadIconA/RegisterClassExA/GetWindowTextA。
- **0x7EE 排查**：两个 wndproc 0x403Fxx（0x201→0x4040F0、0x202→0x404240、0x7E8→
  0x451BB0、0x7EE→0x404600=输入恢复）与 0x4596xx（0x7EE→0x45A140=聊天输入，
  type==1 专用）；"WH GEngine" 类（0x47DBB8、wndproc 0x467AE0→[0x91790C] COM
  对象 vtable 0x476C7C、[0]=0x467AC0=DefWindowProc 包装、RegisterClassExA @0x467B40）
  为引擎隐藏窗 ≠。确认框 0x7EE 落点在主游戏窗 C++ 消息链
  （0x412303/0x412AAE → 0x42AAB0 → 0x42C4D4，candidate 级）。
- **7 个调用方 + 原串**：0x416F9C 付款「您要付给对方多少金币?」(type3, tag0x405, 居中)、
  0x41D633 扔金币「您准备扔下多少金币?」(0x66, 0x30E)、0x420B80 存储满 / 0x420BB4 存储拒绝
  （**cp949 韩文**「개인 보관 창고가 다 찼습니다…」「보관 할 수 없습니다.」）、
  0x4246B6 踢行会成员「请在这里添加您要删除的小组成员名字.」(6, 0x3FE)、
  0x425C8B 仅掌门「只有行会掌门人才能使用这个功能.」(4)、0x42BF62 返回选人
  「返回游戏人物选择界面？」(0x65, 居中, 0x419CC0 门控)、0x440489 创建行会
  「请输入要创建的行会名称:」/「请输入:」(9, 0x3F3, strcmp 选, 随后 0x4521B0 发 0x3F3)。
  对话框串 = GBK 中文、存储串 = cp949 韩文 → **混合编码本地化进行中客户端**。
- **cluster 2 结案**：0x418968-0x41898E 属独立隐藏窗类 0x418910（id 0x64、ROOT+0x53030、
  0x320×0xB8 @(0xDA,0xB0)、open-all 尾项、经基类 0x423B30 构造、复用是/否帧）——非确认框第二状态。
- **通知框 0x43E260（WM id15）**：ctor 9 args ret 0x24、基类 0x423B30 **参数重排**
  （a4=arg8(x)、a5=arg4(y)、a6=arg5(w)、a7=arg6(h)）；子控件 1 this+0x54 = 帧 161/162
  (28×26 @(left+0x224, top+0x10))、子控件 2 this+0x108 = 帧 606/607 (40×20
  @(left+0x1F0, **top+0x1B=137**))；paint 0x43E3C0（帧 602 全幅合成 800×600 裁剪 →
  状态字节 +0x1D0 选 0x47C460/0x47C440（0x323232）→ 第二行 0x47C440（0x96C8FF）
  @(+0x5F,+0x18) → 0x417830 重定位 btn1/btn2 → 2× vtable[1] paint 步长 0xB4）；
  click 0x43E4BA（btn press → this+0x1CC 行会公告编辑缓冲（2×1000 dword）→ 0x43E62C）。
  **帧 602 双用户**：本窗（0x427970）+ 公告横幅单例 0x777200（0x425A46，ctor 0x423E80，
  [0x7773D0]=1，0x4E2 dword 缓冲，文本 0x47BB4C）；**603/604/605 全二进制无引用
  = 未使用韩版遗留**；btn2 绝对屏位 = (603,137)（旧 153 推导作废）。
- **证据等级**：确认框/通知框构造、绘制、输入、激活、帧归属、字符串 = primary-static
  + primary-resource-visual；603/604/605 = primary-static-absence（负证据）；
  0x7EE 主窗业务处理 = candidate（不影响布局/绘制/输入结论）。

仍未闭合（后续重点）：外层 40 项消息表 0x421E8C 未达索引；0x41D744 处
`[ROOT+0x364444]` 目标对象语义；一级分派体 0x42C1A4..0x42C30D；二级分派
0x41EDBD→0x421D5C/0x421D8C 与 0x41F052→0x421E50；0x418/0x419 业务名；
帧三个控件按钮业务名；主游戏窗 0x7EE 最终业务处理（candidate）。

## 4. 证据规则

每一项结论必须记录：

- 原始文件和绝对路径。
- EXE 虚拟地址、反汇编地址或资源帧编号。
- 坐标的坐标系：屏幕绝对坐标、窗口相对坐标、父控件相对坐标或素材内部坐标。
- 宽高、锚点、偏移、裁剪方式和缩放方式。
- 证据等级：`primary`（原版二进制/资源直接证明）、`derived`（由多个 primary 推导）、`candidate`（合理候选）、`pending`（尚未确认）。
- 解码编码和不确定性。不能因为字符串看起来合理就伪造确定结论。

坐标恢复优先级：

1. 反汇编中的静态构造参数、SetRect/SetPos/绘制调用。
2. 原版资源尺寸、资源族和窗口基类绘制关系。
3. EXE 中的父窗口偏移、子控件偏移和固定 800×600 锚点。
4. 原版客户端运行时观察或截图。
5. 手动视觉估计只能作为 candidate，不能升级为 primary。

## 5. HTML 模拟器最终规格

建议新建独立目录，例如：

```text
Tools/mir3_client_simulator/
```

要求：

- 纯 HTML/CSS/JavaScript 即可本地打开，最好同时支持 `python3 -m http.server`。
- 逻辑画布始终为 800×600；浏览器窗口变大时只做整数或等比缩放，不能改变逻辑坐标。
- 贴图必须由 WIL/WIX 解码结果生成或直接引用已解出的 PNG/WebP；不要用占位色块替代已有素材。
- 所有控件从统一数据模型读取，不要在 HTML 中散落重复坐标。
- 每个控件至少包含：`id`、`rect`、`frame/resource`、`state`、`zIndex`、`hitTest`、`evidence`。
- 支持窗口打开/关闭、拖动或固定定位、按钮 normal/hover/pressed/disabled、背包格选择、技能选择、目标选择、聊天输入、提示框确认/取消。
- 场景层至少支持地图背景、人物精灵、怪物精灵、NPC 精灵、目标框、人物装备纸娃娃和掉落物。
- 鼠标悬停实体显示名称/头像/目标框；点击实体将其设为当前目标。
- 人物面板显示装备槽和对应原版装备贴图；背包和技能窗口显示可点击格子。
- 提供“证据模式”：显示控件 ID、矩形、素材帧、证据等级和来源。
- 提供窗口导航或测试面板，能逐个打开 HUD、状态、背包、技能、任务、聊天、NPC、商店、仓库、地图、系统、社交、提示等界面。
- 预览中明确区分“已证实”和“候选模拟”，不能把未确认的内容伪装成原版事实。

推荐数据文件：

```text
simulator/data/layout.json
simulator/data/resources.json
simulator/data/entities.json
simulator/data/windows.json
simulator/index.html
simulator/app.js
simulator/style.css
```

## 6. 尚未完成的重点

重点闭合以下 evidence，而不是只继续美化预览：

- **NPC 帧窗口选项列表填充链 + 子协议同族已全闭合**（msg **0x515** → 0x4218F2 子协议分派 → 0x421A45 → 0x4488D0 → 0x449870 追加 frame+0x1E0；0x416 发送族 0x4488B0/0x448B10/0x4491D0/0x449390 均为同一帧加载器；0x4491B6/0x44933E 位于 0x4491D0 幂等插入体内；同族 handler 0x44D/0x4B0/0x514..0x520 全部解码，见 §3）。剩余：0x418/0x419 业务名；帧三个控件按钮业务名；`[ROOT+0x364444]` 动态目标字段语义。
- 外层 40 项消息表 0x421E8C 未达索引（9..15/17..39）；一级分派体 0x42C1A4..0x42C30D、二级分派 0x41EDBD→0x421D5C/0x421D8C、0x41F052→0x421E50。
- 0x41B94F（0x8AB828 静态 1011 字节正文副本）、0x41D744（按 `[model+0x30]` 门控的逐帧更新）、0x42B820 间接调用者、一级分派体 0x42C1A4..0x42C30D 上下文。
- 聊天窗口完整绘制和输入/滚动区域。
- 地图、小地图、地图按钮及地图资源的准确对应。
- 状态、背包、任务、NPC 窗口的全部子控件和最终坐标。
- 商店/仓库所有状态的最终屏幕坐标、按钮命中区和状态切换。（状态图已闭合：open-all 参数表、点击打开链 0x42BB00、pre-open 0x44EF00、hit-test 0x44E910、paint 0x44E260 状态分派，见 §3；剩余：各面板控件最终坐标与具体按钮业务名。）
- 确认框/通知框已全闭合（构造器分类、按钮状态机、hover/click、键盘/激活链、帧归属、混合编码字符串，见 §3；`RESEARCH_LOG.md` Finding 233–238）。剩余 candidate：主游戏窗 0x7EE 最终业务处理。
- 全局窗口的实际 draw order、visibility dispatch 和 position dispatch。
- 角色装备槽、怪物目标框、人物/怪物头像、场景实体资源族。
- 原版资源的完整解码、索引、透明色/调色板/裁剪规则。

## 7. 工作纪律与交付

这是一个需要持续运行十几个小时的大工程。接手智能体应自主运行，不因小的不确定性中断，不向用户反复询问。遇到无法证明的内容，记录为 pending/candidate，继续推进其他可验证部分。

每完成一个实质性发现：

1. 更新对应 JSON/Markdown 文档。
2. 更新 `UI_COMPLETION_AUDIT.md` 或 `ui-coverage-matrix.json`。
3. 运行 `python3 Tools/reverse-engineering/enrich_mir3_layout_evidence.py`。
4. 运行 `python3 Tools/reverse-engineering/verify_mir3_ui_evidence.py`。
5. 运行 `git diff --check` 和必要的编译/网页 smoke test。
6. 进行小而清晰的 commit，并推送到当前远程分支。

不要删除或覆盖用户已有的无关改动，特别是工作树中可能存在的未跟踪文件 `\\Config\\ExperienceList.txt`。

最终交付必须包括：

- 完整研究文档和证据 JSON。
- 坐标、资源、绘制顺序和窗口状态的统一数据模型。
- Zircon 侧的可继续实现的布局基础。
- 可本地运行的完整 800×600 HTML 客户端模拟器。
- 运行说明、已完成/候选/待确认清单。
- 最终验证报告、commit hash 和远程推送结果。
