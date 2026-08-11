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
专项控件矩形：25
内容分类：21（新增 scene-entities 类，round 3）
JSON 证据文件：70（ei-ui-layout 口径，与 verifier json_artifacts 一致；round 3 新增 login-flow / window-id-catalog / scene-entity-render / server-data-crossref 4 个，扩展 social / target-box / skill-window-render-loop 3 个；round 4 新增 5 个地图语义证据于 mir3-map-reconstruction/，该目录共 9 个）
尚未完全闭合的证据项：14（round 4 闭合 P1/P2/P3/P6/P9/P10：18 → 14；剩余全为运行期/服务器协议/业务名级）
```

已经建立或完成初步证据的部分包括：

- 800×600 主视口和底部 HUD。
- GameInter.wil 的底部金属底板、血球、蓝球、经验条、罗盘和按钮资源。
- 窗口初始化、窗口显示/隐藏调度、绘制顺序和窗口提升关系（静态侧已闭合，Finding 258：0x42B6A0 提升命令、0x4280F0 链表序 paint、HUD 帧序 0x4294E0、store/exchange/option 状态分派，见 `draw-order-evidence.json` closed_notes）。
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
  为引擎隐藏窗 ≠。确认框 0x7EE 接收体已闭合（Finding 256，primary-static）：
  主 WndProc 0x403FA4→0x404600（输入双缓冲恢复 0x403640）、第二 WndProc 0x459654→0x45A140
  （type 门控游戏对象发送 0x452040/0x451F90）；0x412303/0x412AAE→0x42AAB0→0x42C4D4
  是 0x7EE 之前的输入路由（点击 0x418400 / 可见性 0x418460 / 顶层窗解析 / 窗口 id 二级分派跳表）。
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
  0x7EE 接收处理 = primary-static（Finding 256：0x403FA4→0x404600→0x403640、
  0x459654→0x45A140）；行会公告保存链 msg 0x410/0x411 = primary-static；
  横幅 0x777200 持续时长 = candidate（无计时器引用）。

仍未闭合（后续重点）：外层 40 项消息表 0x421E8C 未达索引；0x41D744 处
`[ROOT+0x364444]` 目标对象语义；一级分派体 0x42C1A4..0x42C30D；二级分派
0x41EDBD→0x421D5C/0x421D8C 与 0x41F052→0x421E50；0x418/0x419 业务名；
帧三个控件按钮业务名；横幅单例 0x777200 持续时长/自动关闭（candidate，运行时确认）。

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

- **NPC 帧窗口选项列表填充链 + 子协议同族已全闭合**（msg **0x515** → 0x4218F2 子协议分派 → 0x421A45 → 0x4488D0 → 0x449870 追加 frame+0x1E0；0x416 发送族 0x4488B0/0x448B10/0x4491D0/0x449390 均为同一帧加载器；0x4491B6/0x44933E 位于 0x4491D0 幂等插入体内；同族 handler 0x44D/0x4B0/0x514..0x520 全部解码，见 §3）。**输入/关闭/逐帧更新/外层表 liveness 全链闭合（Finding 252，`npc-window-render-evidence.json` closed_notes）**：模型输入 0x440290 三控件（关闭 X=+0x58 且 `+0x274`≠0 → 返回 1 → 分派 case 0x42C17D → ROOT hide-all 0x41C1E0；上滚=+0x1C0 门控 `[+0x3BC]>0 && byte[+0x58C]==1`；下滚=+0x10C 门控 `[+0x3BC]<[+0x3C0]`；滚动 thumb 拖拽 0x417E60(+0x3C4)、重排 0x440C30 清每行 5 sub-rect）；输入分派 winmgr 0x42BEAA→0x42AAB0 命中→0x42BF70→表 0x42C4D4（case 9=0x42C17D）/事件循环 0x42BEF8（16 固定窗 winmgr+0x567C+id*0xB4 = `((id*5+0x267)*9)*4` @0x42BF0B，表 0x42C494 16 项）；**`[ROOT+0x364444]` 动态目标字段语义闭合**：0x41D744 门控是 ROOT 相对激活标志 `[ROOT+0x2F660C]`（模型非激活才发送，纠正旧 "[model+0x30]"），取 `[obj+4]` 为 id、经 0x8AB828→0x452940(0x3F2, id)→0x451E60 发出站 msg 0x3F2 内容轮询包、500ms 节流 `[ROOT+0x428040]`、`[ROOT+0x364450]=0`；**外层表 0x421E8C liveness**：唯一读者 0x41F582（唯一跳入 0x41F269）`add eax,-0x264; cmp eax,8; ja` → 仅索引 0..8（msg 0x264..0x26C）可达，9..39 静态死（含 13 click_buffer / 16 dialogue_open / 17 hide-all 包装，无表外 E8/imm32 引用），hide-all 0x41C1E0 本体经 E8 调用方 0x41C0CE/0x422BAD/0x42C193/0x42CFC3 存活。剩余 candidate：0x418/0x419 业务名与选项点击语义（0x419 同时覆盖 NPC 选项点击，见 Finding 251）；帧三个控件按钮业务名（字形 52/53↑、54/55↓、161/162× 视觉比对）；0x3F2 轮询包运行期服务端应答。
- **外层 40 项消息表 0x421E8C 与 NPC 一级/二级分派体已闭合（Finding 252）**：见上条 NPC bullet——liveness（索引 0..8 可达、9..39 死）、表 0x42C4D4/0x42C494、二级分派 0x41EDBD→0x421D5C+byteA 0x421D8C、0x41F052→0x421E50+byteB 0x421E58、0x42043C→byteC 0x422080→0x421FBC（49 项，[31]=0x421CFC [32]=0x421508）、子协议 0x42219C→0x422168（13 项）全解码。
- **任务窗口证据闭合（Finding 251，`quest-window-render-evidence.json` closed_notes）**：线上分隔符 = '/'（0x2F，primary-static：msg 0x515 → 0x421A45 → fill 0x4488D0 经 fast strchr 0x468BF0（push 0x2f @0x44891C/0x448932/0x448944/0x44895C/0x44897A）就地切分；行文本→record+4、field4→record+0x230（标志 record+0x214）、字段长 record+0x204/record+0x22C）；无客户端像素换行（primary-static：0x45DD70 ret 0x1C 每行恰一次 TextOutA、固定 15px 步进；GetTextExtentPoint32A 仅在字段取用助手 0x45E0C0 内测量，paint/fill 无回流循环）；控件→事件链 primary-static：X 721/722（this+0x128）共享 release 0x4177F0（vtable 0x4763A8 +0x10，ctor 0x417550@0x44745E）→ PtInRect(0x4762B4) → 0x45AFC0(0x8AB130, cmd 0x69) → 0x447FD6/0x447FDA 本地消费、无消息（**纠正旧“两控件均汇入 0x448580”**）；箭头 723/724（this+0x74）→ 0x4481FA → 0x448580（record+0x208=1、this+0x68=1、this+0x1DC=record）→ record+0x20C==0 → 0x451A10 → **0x418**（arg record+0；更新路径 0x44856B 同汇）；子记录空正文点击（byte[child+0x220]==0）→ 0x448148 → 0x451A40 → **0x419**（参数 [child+0]/[record+0]）。剩余 candidate：0x418/0x419/0x69 业务名（本地无协议目录、EIServer.exe 无源码，缺服务端包处理引用或运行期抓包）；记录类 tokenizer（`[0x8AB7A8+0x1C]` vtable +0x44 取字段/+0x68 前进，门 0xA0/0xC8）。
- 外层 40 项消息表 0x421E8C 未达索引（9..15/17..39）；一级分派体 0x42C1A4..0x42C30D、二级分派 0x41EDBD→0x421D5C/0x421D8C、0x41F052→0x421E50。→ **已闭合（Finding 252，见上条 NPC bullet）**：索引 0..8 可达、9..39（含 16）静态死；两级分派与全部跳表/字节表解码。
- 0x41B94F（0x8AB828 静态 1011 字节正文副本）、0x41D744（按 `[model+0x30]` 门控的逐帧更新）、0x42B820 间接调用者、一级分派体 0x42C1A4..0x42C30D 上下文。→ **已闭合（Finding 252）**：0x41D744 逐帧更新（门控实为 `[ROOT+0x2F660C]`，非 [model+0x30]）与一级分派体 0x42C1A4..0x42C30D 全解码（见上条 NPC bullet）；0x42B820（关闭全部）E8 调用方 = 0x42ADB6（显示切换 0x42ADB0）/ 0x42B6B3（show 分派 0x42B6A0）/ 0x42BD8F（商店点击分派区），无 imm32 引用；**0x41B94F = msg 0x3F3 组装调用点（body 源 `[ROOT+0x2F6630]`，push 0x3F3; mov ecx,0x8AB828; call 0x4521B0）位于函数 0x41B8D0 体内，0x41B8D0 唯一 E8 调用方 = 0x41C14B（ROOT 主逐帧更新函数，同函数调 0x40A8A0 HP 条 / 0x40BB00 悬停名牌更新、处理对话目标字段 `[ROOT+0x364444/0x364448/0x36444C]`、遍历节点表 `[ROOT+0xE1170]`）→ 0x3F3 发送链存活，非死代码（0x41B94F 本身零引用是因其为函数内部标签，此前误判，已更正）**。
- **聊天窗口完整绘制和输入/滚动区域已闭合（Finding 243，`chat-window-render-evidence.json`/`chat-window-unified-model.json`）**：9 个子控件 vtable 链（基类 ctor `0x413DA0` 数组构造 9 控件 this+0x6C..0x60C 步长 0xB4，元素构造器 `0x404690` 写 `[obj+0]=0x4763A8`，槽 +4=`0x417640` 渲染 / +8=`0x417780` hover / +0xC=`0x4177C0` 按下 / +0x10=`0x4177F0` 命中）；频道 ctor `0x417550` 9 实参（arg6=GBK 帮助串→+0x34、+0x20=-1 无常态帧、+0x30=0）；**六频道 +0x34 命令串 = 悬停 tooltip-only**：+0x34 唯一读取点 0x417373/0x417378（tooltip 渲染器 `0x417370`），悬停分支 0x41771B 无条件调用 → 光标旁 DrawTextA flags 0x25（DT_SINGLELINE|DT_VCENTER|DT_CENTER）淡黄底 0x96FFFF + 1px 黑框；常态/按下为纯帧合成（0x417830、0x460240 无文本）；点击注入命令模板 0x47AD88 族到原生 EDIT 框（SetFocus 0x4762B8/SetWindowTextA 0x4762CC，HWND 0x8AA48C），与 +0x34 无关。**全链汇总（Finding 250）**：7 步绘制链 `0x4142C0`（基帧 vtable+0xC → 裁剪 SetRect(+0x6C0,40,29,531,308) → 历史文字 0x45DD70×19 行 14px → 输入条 0x4179B0 @(x+0x215,y−0xD0) 值[+0x68]/上限[+0x6D0] → 9 控件 0x417830 固定相对位 → 9 循环 vtable+4 → 输入行 SetRect(+0x954,25,311,524,326)）；消息链 head=this+0x5C（node next+0x408/prev+0x40C/色+0x00/背景+0x04/内联 GBK 文本+0x08、count+0x68、scroll+0x6D0、裁剪[35,28,520,43]、原点[40,29]）；9 控件坐标（关闭 F161/162(532,350) 28×26、频道 36×34×6 @x=25/65/105/145/185/225 y=332、滚动 F380/381(539,25)/F382/383(539,311)、输入量条 0x417960(533,−208) 16×502）；输入 EDIT 链（HWND 0x8AA48C/对象 0x8AA488、解析器 0x414364-0x4144F0 `/` `(` `)`、提交 0x4144A0→0x414FA0、行回忆 0x4142C0、键 0x414E9x+Shift 门 0x414ED0）；渲染器 0x45DD70 聊天槽序闭合（thiscall 7 栈参 ret 0x1C：arg1=目标离屏 surface（0→this+0x1C，HDC 经 surface->vt+0x44 出参写回 arg7 槽）、arg2=X、arg3=Y、arg4=文字色、arg5=背景色（0→TRANSPARENT）、arg6=文本、arg7=字体（0→this+0x28 默认）；聊天点 0x4147F3：arg1=[0x8AB7C4]=窗+0x1C 离屏 surface（仅 CreateSurface 出参写 in 0x45D380）、arg4=msg+0x00/arg5=msg+0x04/arg6=msg+0x08/arg7=0）；色字面量 0x323232/0x0A0A0A/0xB4FFB4；**visibility gate 0x42B180 接线闭合**：`[ROOT+0x5081C]`==chat this+0x30（vtable 0x47660C@0x413E1A，setter vtable+0x10=0x423F80），关闭钮命中 0x4177F0→0x4149A0→0x42C0B7→push 8→0x42ADB0→跳表 0x42B3E4[8]=0x42B180：隐藏（移编辑框、0x42AC50 移除激活列表、0x423F80(chat,0)）/显示（置聊天矩形、ShowWindow(edit,5)、0x42AC30→0x449870 加激活、0x423F80(chat,1)）；'R' 键 0x42CCF7 同分派器。剩余 candidate：0x45DE50 SetTextColor 精确 COLORREF、打字机揭示方向运行期验证。
- **地图与逐图勘察已闭合（Maps 阶段，`MAP-SURVEY.md`）**：544 图 catalog 完成；六大类结构定型（城镇/室内/半兽洞穴 D00x/赤月 D100–D102/沃玛 D201–D203/沙漠雪地），0 尺寸不符、00.map 不存在；34 图 5723 异常按 8 类错误分类（无 map-file/库表错误；frame-decode 3.map 3255 格 lib24/25、41.map 1619、D10031 唯一 ground OOB；特殊处理 ground_not_drawn 670 格；版本差异 39 图 13B）；投影/锚点/图层顺序/offset 规则引用 EVIDENCE-INVENTORY C3–C8/C16–C18。剩余：P1–P11（越界帧替换逻辑、室内地面机制、小地图留白逐图校准等）。→ **Round 4 已全闭合（Findings 274–278，见 EVIDENCE-INVENTORY C22–C27 与 §6 round-4 bullet）**：P1/P2/P3/P6/P9/P10 闭合，剩 P4/P5/P7/P8/P11/P12 运行期/业务级。
- **地图资源绑定已闭合（derived）**：客户端 primary-static 选择规则 `0x0043D780`（map_id≥1000 → FMMap.wil frame map_id−1000，否则 MMap.wil frame map_id）+ 服务端 MiniMap.txt 交叉引用（`minimap-server-crossref.json`，182 条 crossref-confirmed 行）→ 构建脚本发射 `map_bindings.json`；模拟器 `setCurrentMap` 同时切换 map.bg 与 map.minimap（128×128 widget (672,0) object-fit cover），聊天显示 `[地图] 比奇县 (0) → FMMap.wil F0`。**三个 pending 已闭合（Finding 254，`map-ui-resource-evidence.json`）**：(a) 类型 0x32=服务端下发的阻挡型小地图标记（绘制 `0x43DC54` 黄色 0xFFFF @1.5px/unit、移动阻挡 `0x4123E3`、排除选中/使用 `0x41ECAE`/分派 0/1/3；全量扫描确认零静态写入 → 类型只来自包；业务名仍 candidate：传送点 vs 阻挡点）；(b) 小地图标签「小地图(Ctrl+V, V)」=`0x47BCCC` 热键指引按钮（screen+0x5730，IDs 0x52/0x53，0x417550@0x4279CF）；缩放=T 键 VK 0x54 @`0x42CE90`（门控 `[screen+0x6518]`→翻转 `[screen+0x64A8]`→`0x43D5F0` 0x100/0x80）**无任何用户可见标签**（全量 GBK 扫描 0 命中；无 WM_MOUSEWHEEL handler；`0x43DE40`=死代码）；(c) 256 模式=widget 放大至 256×256 @(544,0)（1:1 无缩放=覆盖/放大视野，非 zoom-out；surface==widget，同 1.5px/unit；滚动 +0x2D0 独立钳制）。剩余 candidate：小地图帧内留白逐图校准（P6）；类型 0x32 业务名与 T 键视觉确认（可选运行期证据）。
- **地图语义批次闭合（Round 4，2026-08-11，Findings 274–278，5 个证据 JSON）**：(a) **帧越界语义**（274，primary-static，`frame-oob-semantics-evidence.json`）：FetchFrame 0x466130 → type0 0x466640 / type1-2 0x466720 解引用前边界检查（`0x46664A cmp edi,[esi+0x10]; jae 0x466714`、`0x466727 cmp eax,[ecx+0x2C]; jae 0x466761`），越界/空帧(offset 0)/宽>4096 → 返回 0 → 7 条绘制路径 `test eax,eax; je` 跳过（透明，无替换帧/取模/首帧——三假说排除）；3.map 3255 格与 D10031 越界格均透出背景（P1/P3 闭合，P3 更正为 tiles5c）；(b) **空地面格跳过**（275，derived，`ground-not-drawn-evidence.json`）：0x43B440 四重门控 `T%14<=2`/`T<=0x45`/`frame!=0xFFFF`/lookup 非空跳过 file=255+frame=0xFFFF 格，缓冲先 rep stosd 清零 → 黑边（K2 静态背景假说反驳；0_003 绘制 58×94/60×100、5_0013 66×66/68×68；P2 闭合）；(c) **offset 分布**（276，derived，`offset-distribution-evidence.json`+`offset-distribution.json`+`Tools/maps/offset_distribution.py`）：123 库 1,084,929 帧 98.8% offset 非零（城镇/主题 (−24,−16)、洞穴 (7,−44) 统一；4,220 帧 (0,0)），C5 零读取 = 有意约定（P9 闭合）；(d) **小地图校准**（277，confirmed，`minimap-calibration-evidence.json` 313 行）：painted (0,0,W·1.5,H)、1.5×1.0 px/tile、frame=ceil4(W·1.5)×H、panel 128×128 @(672,0)；**MMap 索引 = 值−1**（EXE 0x43D780 setter + 0x420C3A dec；off-by-one 修正：交叉引用 268 行、模拟器 map_bindings 182→211；P6 闭合）；(e) **保留帧**（278，primary-static，`reserved-frame-markers-evidence.json`）：精确 frame==0xFFFF 比较（0x43BB45/0x43BB4A 等 5 站点，非掩码），0xFF00+ 落入 FetchFrame 边界检查 → 不绘制；22 库引用全在 39 个 13B 探针图；『3 库全幻影』不可复现（41/49/54 = 空占位引用）（P10 细化）。剩余 P4/P5（NPC/怪物外观）、P7/P8（actor 渲染细节）、P11（4 掉落名）、P12（小地图滚动数学，candidate）。
- 任务、NPC 窗口的全部子控件和最终坐标；**状态窗子控件与 WIL 绑定已闭合（Finding 246，`status-window-render-evidence.json` closed_notes）**：子控件 this+0x58（帧 161/162 关闭钮，hit rect (212,298) 28×26）、this+0x10C（帧 171/172 = **视图切换按钮**，点击 `0x44CCD0` toggle `0x44CD14-0x44CD9F`：mode byte `[this+0x54]` 0=属性视图（帧 200=256×512，faces 171/172）/1=装备视图（帧 201=1024×512，faces 168/169），`0x423E80` 重设窗 + `0x417880` 换脸；hit rect (176,264) 36×36，旧 286 纠正）；**el82/83/86 WIL 绑定 primary-static**：el82=Inventory.wil（slot `0x570574`@`0x453804`）、el83=Equip.wil（slot `0x570678`@`0x453829`）、el86=ProgUse.wil（slot `0x570984`），WIL 表填充 `0x452B20`（**slots 0..139，非 0..91**——Finding 266）+ 元素 loop2 `0x452AF7`（el70..el139 mode0）；**el139=Data/StoreItem.wil 商店物品选择器（Finding 266，推翻"空槽"假设）**：slot 139=owner+0x13E5C=0x573F58，字符串 `.\Data\StoreItem.wil`（0x47C878）拷贝 @0x4540E8（lea [ebx+0x13E5C] @0x4540D4）；分派 0x430A40 flag==2=不绘制 ret 1、flag==3=el139（唯一调用点 0x44DCC4，全部为商店物品图标绘制路径：0x430A63/0x44D65C/0x44DBAE/0x44E05D，均经 0x466130 守卫）；记录步长 `0xC24` 重确认（click `0x44CDCD` idx*0xC24=3108）；**map-rebuild start byte 语义闭合（Finding 266）**：`[map+0x124]`=已加载 `.map` 文件头偏移 0x14 的字节（唯一写入者=ReadFile @0x43B68B，公式 start=(byte+1)*14 @0x43B770，重建循环 0x43B7B2；544 张发行地图 header[0x14]∈{0:530, 1:14}，byte=4/8 的 el70..83/el126..139 重建仅假设性）；**装备槽业务名定案（Finding 265）**：客户端槽索引==EquipmentSlot 枚举零翻译（idx2=头盔/3=火把/9=鞋子/10=毒药，见装备槽行）；剩余：少数属性数值绘制颜色语义（超范围）；**背包静态侧已闭合（Finding 247，`inventory-window-render-evidence.json` closed_notes）**：46×0xC2C 连续记录 @`this+0x774+slot*0xC2C`（ctor `0x42E810`→向量构造迭代器 `0x4686C4`、dtor `0x42E8D0`→向量析构迭代器 `0x468306`；纠正旧指针数组模型）、数据基址 rec+0x0C（0xC20 拷贝 `0x42F440`）、格子表 @`this+0x2C4`（WORD/格、6 格/行、占用=slot+0x3E8）、打包字段=24 位图标着色 rec+0x51..0x53（primary-static 全链：类型 rec+0x2E∈{0x0A,0x0B}→`0x45E4E0`→RLE `0x45F2D0`；纠正旧 +0x351..353）、负重/总量=「负重:%d / 总量:%d」`0x47BDFC` 读 `0x7DA11D/0x7DA11F`、四模式标签 [包袱]/[修补]/[变卖]/[木柴]（`this+0x54` 跳表 `0x42F13C`）、点击链 `0x4300F0`（mode0→0x3EC/`0x451690`、mode1→`0x451860`、mode2→`0x4517E0`）；主数值 `0x7DA100`=本构建从未写入（bss 零；仅 2 个 imm32 读取者=死门 0x41729D + 背包 paint 0x42EE4C sprintf %d 恒显 0），业务名 candidate（交易/购买数量上限）；**填充子树闭合（Finding 262）**：`0x42FC40` 是函数中段（非虚函数起点），真实入口 `0x42FC20` 活=13 个 E8 调用者（10 个服务器消息 handler 各拷 0xC20 字节记录）；`0x42F440` 记录位虚函数死（唯一调用者 0x42FC90 死子树内）；单元格表 this+0x2C4、6 WORD/行、值=slot+0x3E8；**0x405 门死因定案（Finding 262）**：跳表 0x42D680 category-3 路由与 byte2==0 守卫矛盾，唯一调用者 0x42D6C6 传 category 4；对话框 0x418030 存 msg-id WORD [obj+0x460]（0x47AD98=「您要付给对方多少金币?」）但确认经 0x417034 实发 0x406；**模式标签 GB18030 全链（Finding 262）**：mode0 `[包袱]`/1 `[修补]`/2 `[变卖]`/3 `[储存]`（修正旧[木柴]——二进制无此串），`负重:%d / 总量:%d`（0x47BDFC）活、仅 mode0 分支（0x42EF8F-0x42F029），0x47BE18=굴림체 字体非标签；剩余：0x42FC20 的 10 个消息号（0x403 回包抓包）、运行期模式标签页映射与左下区域视觉确认。
- 场景实体资源族。
- 商店/仓库所有状态的最终屏幕坐标、按钮命中区和状态切换。→ **已闭合（Finding 245，`store-state-graph.json`/`store-window-render-evidence.json` closed_notes）**：屏幕原点 state0 面板 (0,184)-(299,490)、content (0,186,300,304)，0x423E80 直接由实参建矩形（无父相对居中）；open-all 参数表、点击打开链 0x42BB00、pre-open 0x44EF00、hit-test 0x44E910、paint 0x44E260 状态分派见 §3；state2=frame 1001 205×205（0x44F940）、state3=frame 1000（0x44FB00）；帧 1010–1017 按钮映射与尺寸（1010/1011 X、1012/1013 确认、1014/1015 ◀、1016/1017 ▶）；双 store 关系（UI store=game+0x33188 vs protocol store=game+0x2D8614）；剩余：状态 1/2 具体按钮业务名（candidate，无服务端消息常量源）。
- 确认框/通知框已全闭合（构造器分类、按钮状态机、hover/click、键盘/激活链、帧归属、混合编码字符串，见 §3；`RESEARCH_LOG.md` Finding 233–238、256）。0x7EE 接收体 primary-static 闭合：主 WndProc 0x403FA4→0x404600（0x403640 输入恢复）、第二 WndProc 0x459654→0x45A140（0x452040/0x451F90 发送）；行会公告编辑缓冲经 msg 0x410/0x411（0x4524A0/0x4524D0→0x452940→0x451E60→WS2_32 send）保存；公告横幅 0x777200 文本源（链表→SetWindowTextA 0x7773CC）与 id-15 显隐分派已闭合。**可见性分派已闭合（Finding 249，`window-visibility-dispatch-evidence.json`）**：0x43E4B0 的消息负载 = WM 0x201/0x202 打包 lParam 坐标（x=main+0x35B2A8、y=main+0x35B2AC，解包点 0x41D485/0x41D48E、0x41DB93/0x41DB99；调用点 0x42BE8C，返回非零 → push 0xf → 0x42ADB0 显示 id 15）；**Interface1c 提示窗（模式 2，0x8A7140 类、编辑框 HWND 0x8AA48C）先于 Frame 602 窗口（模式 3，0x47EF18）显示**——模式字节 0x8B1878 经主循环开关 0x402123 强制 0→2→3（协议 case 0x64 置状态字节 2 @0x41CE57 → 0x41C1C7→0x41B5D0→0x419BE0（模式 2 + 0x456CB0 Interface1c 重初始化 + 0x45D270 文本格式）→0x4575D0 状态 2 @0x457615 SetWindowTextA/MoveWindow/ShowWindow(5) →0x4570C0 切模式 3 →0x41BB00/0x41B440+0x41B500 横幅/公告阶段）；0x42E1F0 更正 = .itm 文件加载器（CreateFileA @0x4760DC + 3× ReadFile @0x4760D0），非公告发送。剩余 candidate：横幅 0x777200 持续时长/自动关闭（无计时器引用，运行时确认）、Interface1c 提示文本 0x8B187C 协议来源。
- **全局窗口的 draw order 与 position dispatch 静态侧已闭合（Finding 258 + 248）**：绘制序 = 0x4280F0 链表按 id 分派、0x42B6A0 hide+show 提升、HUD 帧序 0x4294E0、store/exchange/option 状态→绘制分支映射（`draw-order-evidence.json`）；**position dispatch 全链（`window-position-dispatch-evidence.json` closed_notes，Finding 248）**：拖拽链 WM_LBUTTONDOWN 0x41D470→0x42BA20→0x42B6A0（重排列表、置 `[base+0xD3C]=1`、0x4240C0 记抓取偏移 +0x48/+0x4C）→WM_MOUSEMOVE 0x41D390→0x42C510→0x42C741→0x42B430（E8 调用方=唯一 0x42C745）→0x423FA0；实参=**绝对客户区鼠标 X/Y**（lParam 逐字转发，非 delta/非窗口相对），新左上角=(X−grabX, Y−grabY)、`[win+0x40/0x44]=宽/高`、570 底边距钳制、WM_LBUTTONUP→0x42BE20 清门控；UI 对象基址=main+0x2A548C。**重复 show(ID) 边界全二进制审计闭合（Finding 263，primary-static）**：无条件尾部追加 `0x42AC30` 的 15 个直接调用者=0x42ADB0 内 14 个 toggle 分支（各自门控 `this+0x30==0`，后接 vtable+0x10(1)=+0x30 setter 0x423F80 / store 0x4488B0）+ 1 个提升 0x42B6A0（hide 0x42AC50 后 show，仅对已列窗口可达）；`0x449870` 的 4 个调用者（0x41538F/0x448ABA/0x4491B6/0x44933E）使用不同管理器、非可见窗口链表 ui+0xD24；全二进制 imm32 扫描两地址 0 引用（无 vtable 槽/跳表项）；不变量 `this+0x30==1 ↔ 节点已列` 由 ctor 0x4175F0（+0x30=0）与全部 19 个 hide 位点维持 → **静态不可达重复节点**；残余边界（图外调用者重追加已列 ID→粘性重复：双绘制 0x4280F0、hide 只删首匹配、close-all 0x42B820 不摘链、计数 ui+0xD38 膨胀）仅运行期可捕获 → candidate。剩余：visibility dispatch 运行时路径样本（0x42B820/0x42B3E4）与真实运行时窗口列表/遮挡截图。
- **主 HUD 底部操作栏 8 个 caption 控件已闭合（Finding 253，`hud-label-evidence.json`）**：channel_control_class（共享按钮类静态 vtable 0x4763A8，类构造 0x404690，控件构造器 0x417550 `ret 0x24`=9 实参：parent→+0x14、frame→+0x18、state_frame→+0x1C、x→+0x28、y→+0x2C、text→+0x34、enabled=1→+0x24、frame_override=-1→+0x20、hover_arg=0→+0x30；SetRect IAT 0x4762B0 → 命中矩形 this+0x04）；paint 0x417640 状态机：HUD caption `+0x20=-1` → 常态不画、悬停只画文字（0x417719 call 0x417370）、按下 SelectFrame(+0x1C) 画帧 159/101/103；Frame 159=16×14 真实字形（153 不透明像素/115 色，修正旧“无像素内容”记录）；8 个 caption ctor 表（0x427A1A..0x427BAA，slot/frame/x/y/GBK 文字全列出）；文字绘制链 0x417370：空串早退→GetCursorPos(0x476240)+ScreenToClient(0x476234)@hWnd [0x8AB7B0]→GBK 缓存 0x8B1888 比较→测量 0x45E0C0（font=[ctx 0x8AB7A8+0x28]）→CreateRectRgn(0x476054) 打字机揭示（计数器 0x47ADC0/脏标志 0x47ADBC）+GetRgnBox(0x47604C)→FillRect 0x96FFFF+FrameRect 黑（0x45E570 模式 2/1）→DrawTextA(0x476280) flags 0x25（SetBkMode TRANSPARENT 0x476044+SelectObject 0x476048+SetTextColor 0x476060）→DeleteObject×3（0x476068）。**caption 数组 8→16 + COLORREF + 输入链全闭合（Finding 261，primary-static）**：hud+0x567C..0x6108 stride 0xB4（hud=gameObj 0x47EF18+0x2A548C），16 个 ctor 调用点全枚举；逐帧绘制循环 `0x42954B`（16 槽 call [vt+4]=0x417640，主循环 0x41C0F7→0x4294E0）；输入：move 0x42C510→0x42C770 call [vt+8]=0x417780（仅悬停不消费）、press 0x42BA20→0x42BAC9 首个命中消费 @0x42BDC9、release 0x42BE20→0x42BF02 call [vt+0x10]=0x4177F0（点击音 0x69 经 0x45AFC0）+ 每 caption 点击动作跳表 0x42C494（如 0x42BF37 mov ecx,0x47EF18; call 0x419CC0）；**COLORREF=0x000000 黑**：0x417370 tooltip 链 9 实参 @0x4174FF-0x417531，arg6 色=push 0 @0x41750C → 0x45DE50 arg6=[esp+0x28] → SetTextColor IAT 0x476060 @0x45DEC8；bg arg7=0 → SetBkMode TRANSPARENT；font arg9=0 → 默认 [ctx+0x28]。槽 12 文本 0x47BC04 = EUC-KR `도움말창(지원예정)`（韩版残留）。剩余（运行期）：HP/MP/EXP 数值注入、打字机揭示方向视觉确认、跳表 0x42C494 各 caption 业务映射（长尾）。
- **角色装备槽已闭合（Finding 240，`equipment-slots-evidence.json`）**：8 个槽 38×38 几何 primary-static（SetRect 链 `0x44B1BC–0x44B2C6`：loop0 头盔 (177,70)、loop1 火把 (27,264)、loop2 毒药 (64,264)、loop3 左手镯 (27,186)、loop4 右手镯 (175,186)、loop5 左戒指 (27,227)、loop6 右戒指 (175,227)、loop10 鞋子 (103,264)，窗口相对，绝对=+(278,136)）；非槽区 loop7 头像/名区 49×33、loop8 纸娃娃 60×90、loop9 属性面板 53×84；命中测试 `0x44B720` 纯位置、无类别逻辑（服务端驱动）；图标帧=物品 shape `WORD[graphics+0x28]` 非槽位索引。**槽位映射已定案（Finding 265，primary-static）**：客户端槽索引 == 服务端 EquipmentSlot 枚举，**零翻译**——idx0=Weapon武器、1=Armour衣服、2=Helmet头盔、3=Torch火把、4=Necklace项链、5=BraceletL左手镯、6=BraceletR右手镯、7=RingL左戒指、8=RingR右戒指、9=Shoes鞋子、10=Poison毒药。线上链：命中 `0x44B720` 原始索引 → 暂存 `0x44BBD0`（槽 word @this+0x8886）→ `0x44CEA7` → `0x451690` arg2 → 组包 `0x452940` struct+6 槽字节（msg 0x3EB/0x3EC；wire={dword itemID, word opcode, word slotByte, word 0, word 0}）；服务器按 Globals.EquipmentOffSet+enum 索引。兼容函数 `0x44B7A0` 仅枚举对齐自洽。**装备视图绘制的 8 槽 = idx {3,2,9,5,6,7,8,10}**（火把/头盔/鞋子/手镯×2/戒指×2/毒药）；武器/衣服/项链为纸娃娃与属性面板区域（flag=1 在角色身上绘制）。旧美术标签（火把@(27,264) 等）**否决**为协议映射（artifact 标签未验证）；模拟器 `equipment_slots.json` 已按 identity 重命名。剩余 candidate：el82/83/139 运行时 WIL 绑定、图标帧视觉像素验证（需 vision 模型）。
- **怪物目标框已闭合（Finding 239，`target-box-evidence.json`）**：代码绘制合成体（无独立 WIL 帧），锚定 `HUD+0xE4/+0xE8`：名字牌框 `0x40B850`（0xA0A0A 边框、宽=文本宽、15px 高、锚上方 15..30px、水平居中，每帧 `[HUD vt+0x84]` @`0x41C063`）、名字文本 `0x40B750`（选择器 `0x566DD4` F2/F3）、悬停名牌 `0x40BB00`（3000ms）、HP 条 `0x40A8A0`（元素 `0x5600FC+[8D]*0x144`、帧=HP 值、400/300 中心公式）、悬停实体重绘 `0x437DF0`；布局矩形 `0x629FC/0x629EC`（`0x40F5F0`）；锚点世界推导 48×32 瓦片公式或固定 (376,227) `0x4120B0`；悬停 msg 0xB → `0x40A4D0` → 服务端询问 0xBC7/0xBD1/0xBD8；点击 msg 2 → 0xBC4；显示门控状态机 `0x411D91`。**长尾三项闭合（Finding 257，primary-static 负证据为主）**：①选择器 WIL 绑定=静态负证据——绑定 API 0x4660E0 的 14 个直接调用方全枚举，唯一全局表 0x5600FC 绑定者=地图装载器 0x43B600，只覆盖 0x0E..0x1B 或 0x1C..0x29（全部 544 张出货地图 header[0x14]∈{0,1}），目标框元素 0x51/0x56/0x57/0x81/0x89/0x8A 无任何静态绑定，0x47C3E0 填充格式串 0 引用=死代码，确切 WIL 文件名=运行期数据（candidate）；②悬停头像=不存在——每帧分派 0x41BF00–0x41C0A0 仅 5 个文字/HP 组件，状态窗 49×33「头像区」=特殊索引 4 角色形象命中/绘制槽（固定目标 (x+0x61,y+0xC8)，flag=1），NPCface.wil 440 帧/约 100×122 不匹配；③HP 条帧=HP 值 [0x61B9C]（primary-static），0x40F5F0 的 10000+(A%400) 系列=元素 0x57（0x566F18）A=[629C8]*400−[8A]*3000+[C4]−0xAA0、帧=10000+(A%400)，GameInter 1103 帧<10000 排除，≥10000 帧候选 WIL 已实测（Tiles5c 20000/SmTilesc 10180/object1c 33125/object2c 30000/M-SHum 32722/M-Hum 27000/M-Helmet1 24000/M-Hair 15000/Horse 10400/M-Weapon1-4 30000/17000）。
- **人物/怪物头像已闭合（存在性 primary-static）**：状态窗 loop7 头像/名区 49×33（见装备槽行）；目标头像纹理源 candidate。
- **坐骑窗口已闭合（静态侧，Finding 255，`horse-window-render-evidence.json`）**：状态块 `0x7DA060` = session `0x777698+0x629C8` 的 5 字节坐骑状态块 byte0（layout byte0=state / word 0x7DA061-62 / word 0x7DA063-64 / byte 0x7DA064）；唯一静态写入者 = session 虚方法 `0x40F420`（vtable `0x476508`，wrapper `0x40FED0`@`0x4765CC`，this=0x777698），clamp `cmp byte[eax],4; jb; mov byte[eax],0` @0x40F46D-0x40F472 → state ∈{0,1,2,3}，0=未骑马/非零=骑马；点击门控：+0x108→`@上马`(0x47B060)、+0x1BC→`@遛马`(0x47B068)、+0x270→`@收马`(0x47B058)、+0x324→`@遛马`(0x47B068)，共用分发 `0x426B22`→`0x4520F0`(0x8AB828, msg 0xBD6)+冷却 `0x8A68BC=0x12C`；包路径 case 0x267/0x26B（分派器 0x41F1CF）写/读块并回发；**标签/覆盖层已闭合（Finding 260）**：860/861 말타기、862/863 말내리기、864/865 말숨기기、866/867 말꺼내기（sibling `horse-window-render-evidence.json` 像素转录；帧宽 44/60/60/56=ctor 命中矩形精确匹配、常态/按下全帧差异佐证）；Paint 0x4269C0-0x426A74=基帧 850+5 控件 0x417830 重定位+子控件循环→**无状态覆盖层（负闭合，与 winmgr 绘制分派 0x428252 无块引用一致）**；窗外状态绘制=主窗 HUD `0x44B666`（word[0x7DA063]→0x45FD50 this=0x8AB7A8，门控 byte[0x777723]/[0x777720]）。**外观表绑定已闭合（Finding 264，primary-static）**：元素表基址 0x5600FC、元素 N=0x5600FC+N*0x144；**坐骑元素=element 87=0x566F18**（0x5600FC+0x57*0x144），选择器字节 `[esi+0x629CF]=0x57`（仅当状态字节 0x7DA060≠0 时写入 @0x40F47F，兄弟 @0x40C79C；lea x9,x9,x4=x324 @0x40F5A6-0x40F5C0 → [esi+0x62A14]）；**状态值 1/2/3 不索引表**。element 87 绑定 WIL 槽 17=`.\Data\Horse.wil`（0x47CC94 拷贝 @0x4538CB-0x4538E5；loop2 0x452AF7-0x452B0E 绑 el70+i↔slot i，87=70+17）。消费：世界渲染 0x40F5F0 门（state≠0 && [62A14]≠0 && [0xC0]≥0x1D），帧=0x2710+(A%400)（A=[629C8]*400-[8A]*3000+[C4]-0xAA0 → [0x62A20]）→ 0x466130 → 0x461ED0/0x463330/0x460240。**HUD 坐骑图标=element 86=0x566DD4**（ProgUse.wil 槽 16），帧=byte[0x777720]*10+byte[0x777723]+0x3B。**修正（Finding 264）**：word[0x7DA063] 不是帧号——是 0x45FD50 填充色 arg6（RLE op 0xC2 fill；其余 22/23 调用者传 0xffff；唯一引用=0x41F5BD 写 + 0x44B669 读）；0x7DA060 块协议源=包 case 0x267 写 word[0x7DA063]=dx @0x41F5BA。剩余（运行期）：1/2/3 子语义、word 字段 0x7DA061-62/0x7DA063-64 协议含义、`@遛马` 服务端最终语义、말내리기 标签 vs @遛马 命令语义并列；键盘/命令路径门控 `byte[esi+0x35B148]`（0x41DE03-0x41DE1E）与窗口路径 0x7DA060 独立。
- **系统设置窗口已闭合（静态侧，Finding 260，`system-window-render-evidence.json`）**：ctor `0x440FE0`（main_init 0x2788D，id 0xC，Frame 750，注册 (276,113) 248×264，对象 main+0x518E0；旧值 0x44103E=ctor 内首个控件调用点，已修正）；paint `0x441380-0x4414E3`=基帧 750+11 子控件重定位（0x417830 实参序 (this,y,x)；close (218,238)、8 toggle (148/185, 43/116/190/217)、滑块把手 this+0x6D0/0x784 x=34+[+0x6C/0x74] 0..160）→ **无运行期覆盖层（负闭合）**；点击跳表 `0x44194C` 8 分支：BGM ON（0x45B410 enable + 0x45B250 play-by-name 拼 `SOUND\` 0x47D88C）/ OFF（0x45B3D0 stop→0x45A510，写 [0x8AB69C]=0）、EffectSound ON（0x45B1B0 [obj+0x14]=1）/ OFF（0x45B1D0 停 50 频道 + 0x45B1C0）、Ambience（0x441850）、ShadowBlend（[0x47EF48]）；**音频消费已闭合**：EffectSoundLevel `0x8AB14C` 播放期直读（0x45BCE9 于 0x45BC80，经 0x45B140 setup / 0x45B900 一次性播放，6 播放调用方 0x457BA7/0x459240/0x459476/0x459AD6/0x45B032/0x45B074），BGMLevel `0x8AB150` 音频引擎零引用（拖拽 0x441F6C→0x45A700 落频道对象 `0x8AB658`，播放路径 0x45B250/0x45B3D0 只读频道状态）；config load 链 `0x441DA0-0x441F37` / save 链 `0x441B30-0x441CAE`（Options/BGM/BGMLevel/EffectSound/EffectSoundLevel/Ambience/ShadowBlend；load_or_parse_va 已按 load 链修正）。剩余 candidate：Ambience 实际音效触发点、BGM 音量重放时点。
- **交换窗口文本/网格链已闭合、位置维持候选（Finding 260，`system-window-render-evidence.json`）**：网格循环 `0x4169B0` 36px 步长（帧 [ebx+0x5EC]、堆叠数 0x0A/0x0B 色 [ebx+0x609..0x60B]、计数文本 0x45F2D0）；4 条文本记录经 `0x45DE50`+`0x46811C`（左方名=全局缓冲 `0x7776A0` 运行期填充、右方名 this+0x129D8、`%d` 计数 this+0x12A18/0x12A1C）；位置流：注册 (0,0) 484×330 vs ctor 烘焙 (532,350)/(185,332)/(225,332) 越界 + show 分派 `0x42B6A0` 收消息动态 x,y（`0x4240C0`=拖拽偏移非移动）→ **无静态绝对原点，坐标维持 candidate**；ctor 入口修正 `0x4159D0`（旧值 0x15A71=首个控件调用点）。剩余 candidate：按钮业务名（1060-1062 中文 `交易` 标签已见）、协议状态、运行期窗口原点。
- 场景实体资源族。
- **组队/行会窗口已闭合（静态侧，Finding 259，`social-window-render-evidence.json` closed_notes）**：组队（id 6，main+0x47834，paint `0x4243D0`）成员行=单文本字段 node+0x04 无图标、链表插入序（0x419EE4→0x424840，容器 this+0x54 vtable 0x4767E0，头 this+0x58/count this+0x68）；两列=奇→win.x+45（0x424471 push ebx=win.x+0x2D）、偶→win.x+145（0x424479 lea edx,[ebx+0x64]），y=win.y+0x5A+20*⌊i/2⌋——**旧公式 mod-2 列映射颠倒已纠正**；允许/拒绝（this+0x3F0 → 0x47BA08/0x47BA00）y=win.y+0x3A 证明（0x424549 add edi,0x3A），x 读未初始化栈槽 [esp+0x1C]（0x42453E）=静态不可证；全链表遍历无 18 行上限（0x42449B next==0 终止，超窗引擎裁剪）；运行态显隐 0x42AC30/0x42AC50、切换 0x42B0BA（visibility=main+0x47864=win+0x30，伴生页签帧 0x398/0x399 @main+0x47B70）、显示分派 0x42B6A0 尾部 0x42B79A。行会（id 4，main+0x4707C，paint 包装 `0x425040`）9 控件数组 this+0x118 步长 0xB4（帧对 161/162、610..625）；点击分派 `0x4258F0` 检查序 0,1,2,3,4,7,5,8,6（主分派 0x42C039-0x42C052 后 id-hook push 4→0x42ADB0）；分支=会员升职→state0+0x4523E0@0x8AB828、成员踢出→state1+0x452410、盟主转让→state2（原始 c7 86 9c 00 00 00 00 c6 86 98 00 00 00 02 @0x4259D9）、邀请入会/行会解散→掌门守卫 [this+0x94]+对话框 602/601（list3/list1 经 0x45DC70 + [0x4762CC] 提交，空表 tooltip 0x47BB28）、行会公告→tooltip 0x40F/0x47BAF4（%s=[this+0x54]）、关闭窗口→tooltip 0x415/0x47BAC8、退出行会→**倒置守卫**（掌门 no-op/成员 tooltip 0x47BAA4）；tooltip 显示 0x418030（ecx=0x7E04C8），输入 0x8AB828 经 0x4520F0+0x4523E0（0x47BA90 "@退出联盟 "）；三态绘制=state0 标记 0x47BA78/0x47BA6C/0x47BA60、state1 标记 0x47BA84→0x96FF 余 0xFFFFFF，other 态全行阴影 0xA140A+绿 0xFF00 双画（0x4255C5/0x42563E），scroll this+0x9C、cap 0x12、行步=字体高+5（0x45E0C0）；9 控件 paint 真相 (556,409)/(34,376)/(34,402)/(121,402)/(309,376)/(397,376)/(484,376)/(309,402)/(397,402)，ctor 后 5 组坐标为陈旧寄存器垃圾、**+0x6B8 旧记录 [196,50] 纠正为 (600,72)**。剩余：允许/拒绝 x、组队成员文本内容来源（0x419EE4 数据链路）运行期确认。
- 原版资源的完整解码、索引、透明色/调色板/裁剪规则。
- **Round 3（Findings 267–273，2026-08-11）闭合摘要**：
  - **LoginFlow（267，`login-flow-evidence.json`，primary-static）**：模式字节 0x8B1878 全写点（0/2/3，mode1 未用）+ 启动栈（0x401B30→connect 0x66→主窗 0x451100 EDIT 类 굴림체→char-select 0x4026E0→mode0 泵）；char-select 0x8A9520 四按钮（F11 选角 (459,436) / F13 建号 (139,379) Mir3.ini URL / F15 改密 / F17 退出）、提交 0x7D1 `%s/%s`；parent 0x8A7140 九按钮（F50 背景/F51 建号→CreateChr.dat/F55 进入 0x67/F57 退出/F89 确认 0x64 `%s/%d`）、阶段机 +0x930（表 0x457778）、server 分发 0x458F80（msgid 表 0x45950C：0x208 角色列表/0x209 建号/0x20D 进入 OK→StartGame.dat/0x20E cp949 提示）；36 字符串全解码。layout.json `secondary_screen_candidates` 两条目已置 closure 段。
  - **WindowCatalog（268，`window-id-catalog.json`）**：16 固定窗全目录（winmgr+0x567C+id*0xB4 @0x42BF0B；caption vtable 0x4763A8；窗 vtable 0x476624 +0x10 show 0x423F80）；**id 0xB 修正=任务 F700**（NPC=id9）；id5/10 空槽、id15 公告仅显示、id100 退出确认框；无好友窗（与 270 一致）。
  - **SceneEntities（269，`scene-entity-render-evidence.json`）**：世界排序通道 0x419D40（4 painter 数组）+ 瓦片通道 0x41C450（地面 0x41C860/装饰 0x41CA20/实体 0x41CBD0/特效 0x41CD50）；**element 映射 type0→71 M-Hum、type1→76 WM-Hum、type3 race<2000→0x58+race/10、≥2000→0x87+(race−2000)/100、0x32→128 NPC、马 0x629CF=0x57→87**；WIL 路径表 base+0xB130 stride 0x104（140 槽，串 @0x47C878）；**idx = 139 − element 双重验证**。
  - **FriendsSocial（270，`social-window-render-evidence.json` 追加，pending=0 负闭合）**：0x8A7140=登录/服务通知双用途对话框（ei_login.dat @0x47AAD0；proto 0x7ED→0x41CDE0 subtype 0x64→[main+0x428204]=2→0x41B5D0→0x419BE0；文本 0x4B0→main+0x428070，样例 0x47B0D0 `服务器连接不稳定...`/0x47AF80 cp949 断线）；好友字符串 0 命中；16 id 空间全枚举（热键标签 0x47BBD0–0x47BCE0 仅行会 Ctrl+F/组队 Ctrl+G；13 窗 ctor 块 0x426C80）。**不是好友窗**。
  - **MonsterPortrait（271，`target-box-evidence.json` 追加）**：element→WIL 文件名 primary-static（el81=Magic/el86=ProgUse/el87=Horse/el129=MonMagic/el137=MagicEx/el138=MonMagicEx.wil；0x56B22C=slot 表基址非 HP-bar 资源）；头像四区裁定（状态窗 49×33=GameInter F200 横幅无脸 / 目标框=代码合成 / 怪物无肖像 / char-select 无 2D 头像 3D 引擎+Interface1c F0）；NPCFace.WIL（0x47C4EC，440 帧/46 非空）仅供 NPC 窗。
  - **Skills2（272，`skill-window-render-loop-evidence.json` 追加）**：技能书右页渲染循环 0x43A440 全闭合——CRLF 分行、`;` 注释、`#` 段头 atoi==this+0x964、20 槽反引号 sscanf 0x47C350、count 恒 1（0x45E0C0 三路径 {0,0}）、几何 (winX+235, winY+30+15k)、`[` 名行 0x96C8FA+4 角阴影、选择链 0x439134→0x43A370→0x43ACE4→paint 0x439500→0x439520；修正旧笔误（0x0f→Y this+0x1c、0xeb→X this+0x18）与 0x43A3E0 函数起点误判。渲染循环内 pending=0。
  - **ServerData（273，`server-data-crossref.json` + `Tools/reverse-engineering/parse_mir3_dat.py`，derived）**：stditem 27 行/monster 15/magic 9/mapinfo 31/merchant 12；monster.dat 记录 252B/xor9、ID@248=rec+1、d20=appearance（稻草人 83/鸡 31/鹿 52/白野猪 208）、d64/d68=AC/MAC；客户端唯一 primary 交叉链=item type 0x0A/0x0B↔stditem cat36 10/11；8 冲突注明（Market_Def [Goods]=Volume/Hour 库存非价等）。
  - **实体→WIL 绑定推导（整合）**：怪物 race→`Mon-(race/10+1).wil`（race<160）；`entities.json` 升级为证据绑定（player M-Hum.wil F0 / npc NPC.wil F0,F100 / 稻草人 Mon-6.wil F0 / 鸡 Mon-4.wil F0 / 鹿 Mon-4.wil F10 / 羊 Mon-7.wil F0 / drop Ground.wil F5=stditem looks68=5）；wilsdk 帧数验证：Mon-1..16 全 10000、NPC 6400、M-Hum 27000、DMon-1 4340、Ground 1440、Horse 10400。
- **实体外观 + 交易窗口批次闭合（Round 5，2026-08-11，Findings 279–283，6 个证据 JSON + P7/P8 自查闭合）**：
  - **StateFrameTables（279，primary-static，`state-frame-tables-evidence.json`）**：三张运行时帧表 0x8AA5C0（玩家 33 条）/0x8AA686（怪物 9–11 条）/0x8AA6C8（NPC 3 条）= **BSS 单例 0x8AA5A8 的字段**（obj+0x18/+0xDE/+0x120），内容 100% EXE 编译期常量——**「表=服务器数据」旧假设证伪**；填充链 0x449C80（33 玩家默认+9 怪物+3 NPC 种子）→0x44A240（race 覆盖 11 怪物）→0x44A090（NPC action），统一 3 字写器 0x449C50；每状态 6B=（w0 起始帧, w1 块长, w2 帧间隔 ms）；渲染公式：player=w0+3000*type+10*flag、monster=w0+1000*(race%10)+10*flag、NPC=w0+100*body+10*(flag%3)；0x44A820 = action→state 映射器；Mir3.dat = 辅助 PE（WIL 字面量）；weapon.ord（2640B）@obj+0x132 本安装未随附。
  - **MonsterDat（280，`monster-dat-evidence.json` + `monster-dat-catalog.json` 432 行）**：**怪物库映射 = Race 字段（非 Appr）**——库 = Mon-(Race//10+1).wil、帧基 = 1000*(Race%10)、element = 0x58+Race//10（race<2000；≥2000 门控 0x4050C6 → element=0x87+(race−2000)//100、帧=100*((race−2000)//100)）；wilsdk 实测 Race 432/432 命中 vs Appr 328/7/97；**MInfo.dat 前提修正 = 法术/魔法效果库**（4-pass XOR 解密链 0x44A910，checksum XOR 0x9FDE1A93(sum((payload[i]+1)*i))=0x8CE329C1 验证；#SPELL 109/#MAGIC 147/#EXPLOSION 39 节）——怪物名真源 = 服务端 monster.json（433 条）；**P11 定案**：夜行鬼09/异界之门 FOUND（Race 19→Mon-2 块 9），葛贰厘面0/诺玛教主2/魔神怪8 服务端缺失；死亡库 DMon-1.wil 块 = Race//10；WIL 槽格修正：槽偏移 = 0xf848+slot*0x104（Mon-1=18…Mon-20=37、MonS-1=38、NPC=58、MonImg=60、DMon-1=65、DMonS-1=66、MagicEx=67、MonMagicEx=68、StoreItem=69）；element 表 0x5600FC+0x144*elem 门控 <140。
  - **NpcAppearance（281，primary-static，`npc-appearance-evidence.json`）**：**NPC 帧 = word[0x8AA6C8+6*state] + 100*body + 10*(flag%3)**（body=[edi+2]/[esi+0x8A]<0x64）——round-3「100*dir」修正（方向槽 [0xC2] 复用存 flag）；NPC.wil 6400 帧 = 64 body × 100 几何；element 128 → 记录 0x5600FC+0x144*128 → [entity+0x90] → NPC.wil（槽 79）；特殊 body 码语义定案（0x18/0x19/0x22/0x23/0x2B..0x32/0x3A 仅站立、0x28/0x38/0x39 flag=0、0x33..0x37/0x3B 1 帧+action 覆盖、0x1B/0x1C 变体、0x29 隐形）；NPCFace.WIL 440 帧绑定对话窗 +0x278；NPCIMG 脚本 token（0x47C50C）→帧 n @(40,30)、FCOLOR 调色板、NOTCLOSE 禁关。
  - **PlayerComposition（282，primary-static，`player-composition-evidence.json`）**：gender→element 0x47（M-Hum）/0x4C（WM-Hum）双路径 0x404FE5/0x405003/0x405673/0x405689；元素表 0x5600FC stride **0x144**（九倍验证，旧 x36 取消）；WIL 槽表 stride 0x104、**element==槽索引**（六交叉验证 71/76/87/88/128/131）；**玩家帧 = word[0x8AA5C0+6*flag] + 3000*S + 10*dir**（M-Hum 27000=9×3000 一致）；叠加 0x40F5F0 六遍（坐骑/武器/身体/头发/头盔+模式 blit）；M-SHum.wil EXE 0 引用；CreateChr.dat = AVI 片头；0x404DA0 渲染模式 6 位 → mode 字。
  - **TradeWindow（283，primary-static，`trade-window-render-evidence.json`）**：交易窗 = **id 3** / ROOT+0x3399C / vtable 0x47663C / ctor 0x4159D0 / 注册 (1,330,484,0,0,F1050,src,3) / paint 0x415B10；**帧 1050（512×512 @(7,−44)）唯一静态美术，UI 命中 484×330 美术溢出**；按钮（关闭 161/162、接受 1061/1062、取消 1064/1065）**从不绘制**（0x417640 零 xref）→ 静默 PtInRect 命中区 + 音效 0x69；取消帧 1064/1065 在 GameInter.wil **不存在**（count 1103）→ 隐形设计；物品网格 24 槽 @+0x5B8 stride 0xC2C、item-id 词 @+0x298（空 0xFFFF）、36px 5×6/窗格；点击 → 0x416830/0x416950 → 协议 0x402/0x403（0x451AA0/0x451AD0）→ 0x8AB828；金币盒 (34,270)..(156,304) + '确定' → 0x405/0x406 → 0x451B30；分割把手 2 个 @+0x13648/+0x13694（帧 1070 = 16×360 竖条，从不 blit，鼠标 0x416E70 写 [+0x54]/[+0x58] 经 0x476650 → 0x468520）；**交易 ≠ 商店**（商店 = id 2 / +0x33188 / ctor 0x44D310 / paint 0x44E260 控件循环 0x417830）。
  - **P7/P8 VA 级自查闭合（`scene-entity-render-evidence.json` round5_closure，primary-static）**：tile pass 1 44×44（0x41C48B–0x41C607）；遮挡窗口 0x41C5AA–0x41C5DE **24×24 内传相对坐标**、(0,0) 外 → cell 0、[e+0x61C74]/[e+0x8A]==0x7F 门控、玩家过滤 [root+0x364444]；**0x7F = force-draw**（非 transparent）；front pass 2 0x41C60D–0x41C7B9；world-sort 0x419D40 网格 [root+0x154, root+0xE1154) = 24×24×1600B、cell = 1600·(24·dy+dx)、链头 [root+0xE1158]；shadow 前插 0x41A008；**map 读数修正**（sort tick 0x41A534：type 0/1→0、2→2、3→1、4..0x31→2、0x32→0；sort draw 0x41A570：type 0/2/0x32→0、1/3..0x31→1；renderer dispatch 0x41CD1C：type 2→SKIP、3→仅精灵、4..0x31→tick chain、0x32→vtable+0x7C+阴影）；新身份 0x40B180 阴影 / 0x40CE20 标签(candidate) / 0x41B570 指针清理；pending 10→7。
- **Round 6（Findings 284–289，2026-08-11，6 个证据 JSON）**：
  - **TradeWindowClosure（284，primary-static，`trade-window-closure-evidence.json`）**：基类 ctor 0x423B40 的 [+0x40]/[+0x44] = **内容区宽/高（484/330）**（注册现场 push 序 (1,330,484,0,0,1050,lib,3)；content rect [+0x18]=(0,0,484,330)）；**0x423FA0 = 拖拽移动**（16 xref、钳制 0x235/0x23A、偏移 [+0x48]/[+0x4C]、0x4240C0 抓取）——F248 position-dispatch 链补全；槽代数：**cell = col + 5*(split+row)**（0x416830，split=[+0x54+4*pane]）、**+0x298[cell+200*pane] word%1000=槽号**（0x416950，空 0xFFFF）、**记录 [0x5B8+id*0xC2C]**（0x4170C2）；分割写路径 0x416E70 迭代 2 仪表 @+0x13648（stride 0x4C）→ 0x417C80 命中 → **[+0x54+4*i] = trunc(f×94.0)**（94.0 @0x476650 字节 00 00 bc 42；_ftol 0x468520）；仪表族：0x417960 ctor / 0x4179B0 render / 0x417D00 步进 / 0x417E60 拖尾（清 [+0x18]）；paint 0x415B10 分派（+0x5C/+0x6C 半区 PtInRect → 0x416830）；**帧 1050 像素目录**（panel bbox (14,91)-(497,421)≈483×330、双网格 pane0 (14,92)-(194,308) / pane1 (246,92)-(426,308) 5×6×36px、金币盒 frame (27,226)-(149,260)=window (34,270)-(156,304)、分隔金色竖条 x≈215-218/239-241/263-265、金币字形簇、右侧装饰带）；split 量纲（行 vs px，trunc(f×94) 达 0..94 vs 窗格需 ≤34）candidate。
  - **WeaponHeadSelector（285，primary-static，`player-composition-render-flags-evidence.json`）**：**[e+0x61C68] 全二进制扫描 = 17 写者/8 读者（全描述符 dword 整体拷贝，无客户端位计算）**——bit0x1 = race 0x53-0x55(83-85) 帧锁门（0x407197/0x40AF55；span 2→3 钳 @0x40AFAB；F280 crossref）、bit0x2 = 名牌可见性（镜像 [e+0x61BD0]，0x40B75A/0x40C908 读）、bit0x100000 = 出生/传送白闪（0x40CE2B，1700ms 计时 +0x62A2C @0x411239 state 0x1F）、bit0x8000000 = 半速（0x405D21 间隔×2 + 奇 tick 跳 0x40AFFF/0x40D12D）；**mode 字 = 纯 blit 常量**（0x404DA0 6 位 → 1/0/0xFBFF/0xFFE0/0x94BF/0xFCB2/0x7E0，默认 0xFFFF；0x404E10 → 0x461ED0/0x463330/0x460240）；**槽名 78 字面量**（init 0x4534B0-0x454120）：82-86 = Inventory/Equip/Ground/MIcon/ProgUse、90-107 = Mon-3..Mon-20、108-127 = MonS-1..MonS-20、128 NPC、131-134 发/盔、135/136 DMon-1/DMonS-1、139 StoreItem、**70 = GameInter@+0xF848（修正 mir3-dat 表 +0xF744 误标：+0xF744 = Snow\object2c.wil）**、76 WM-Hum、81 Magic，element==槽；选择器落地 0x40C7B7-0x40C85D：男 head −0x7D/weapon +0x48、女 head −0x7B/weapon +0x4D → sel 41-50 = WM-Hum(76)/Magic(81)、head 21-29 = WM-Hair(133)/DMon-1(135)（sel>40 触发运行时）；player-composition pending 7→5（gender 写点/表运行期/预览 7-case/阴影 quad 保留）。
  - **MonsterSpecialCodes（286，primary-static，`monster-special-codes-evidence.json`）**：**表分派 0x407610（码 3..0x59 字节表）→ 跳转表 0x4075F0（8 项）**——code 0x53/0x54 → 字节 8 → 默认 0x4075C5（[0x61c7c]=1 + actor vtable+0x10(8,arg)，无特殊语义）；code 0x55 → 0x40742C（alloc 0x13c → ctor 0x434EF0 → vtable+4 8 参调用，参数来自 [edi+0xcc]/[edi+0xd0] + 立即 0x11，全局 0x560088 空则建 0x10 节）→ **FX/魔法效果对象**；同步闪烁门 0x407197：test [esi+0x61c68],1 / je → code（type3 时 ah=[0x8b] al=[0x8a] 高低组合，否则 movzx [0x8a]）cmp 0x53 jl / cmp 0x55 → 分派；**race 字节表 0x44A61C 中 0x53/0x54/0x55 全部 = 8**（默认记录 state9=(0x2D0,6,150) 之外）→ **真实 race 83/84/85 在 monster.json 中不存在**（小 race 表：10-22,24,25,31-37,40-43,45,47,49,52-55,98；98=城门/木障、52-55=楔蛾/神兽）→ 0x4071A0/0x407260 特殊分支无 83..85 实义（实为 FX 分派）；**怪物 element 公式复核成立：element = 0x58 + race//10**（0x4050D1-0x4050E4：imul 0x66666667 → sar edx,2 → add 0x58；gate cmp al,0x8c / jae → element≥2000 分支 0x40B4AE 表分拆）；**静态绑定 0x452AA0**（槽表 stride 0x104，文件名 0x47CEB0-0x47D000，复制对 0xF334-0xFF64 = 14 槽 + 70 槽两环）、**运行时绑定 0x43B780**（路径 @0x56B22C+e*0x104）、地图加载器重绑 14..69（自 [ebx+0x124]+1）、getFrame 未绑→0（无惰性绑定）；**MonImg.wil 无静态消费者**——图标绘制用 element 86 = ProgUse.wil（玩家状态图标，0x44B630/0x41F597，0x44B560 + word[0x7DA063] 填充）；monster vtable 0x476400 族；monster-dat pending 5→4（83..85 闭合、2 项细化）。
  - **NpcBodyStrip（287，primary-static，`npc-body-strip-evidence.json`）**：**NPC 场景实体类 vtable = 0x47671C**（非 0x476480/0x40B2C0；type 0x32 → alloc 0x629C8 @0x468B1A → ctor 0x404960 → mov [esi],0x47671C；+0x0C=0x404FB0 包分发读 [edi+2]、+0x7C=0x40C020 场景 blit，帧号直取 [esi+0xC4] 经 0x466130）；**body 0x38/0x39 条带 4..11 = 0x44A090 无条件覆盖三条状态记录 (0,12,0x50=80ms)**（state0 bt 0x44A1CC idx5/6→jt[1]=0x44A0C7、state1 bt 0x44A1EC idx29/30→jt[3]=0x44A131、state2 bt 0x44A220 idx28/29→jt[2]=0x44A18A；帧计数器 [0xC4] 以 80ms/帧 base..base+11 循环）——**非孤儿美术、无第二公式**；0x40C4B0 帧推进（[0xC8]+=delta、[0xC8]>[0xBC] 且 [0xC4]<[0xB8]→[0xC4]++、[0xC4]>=[0xB8]→[0xC4]=[0xB4] 回绕 + call vtable+0x10(0,flag)、间隔 [0x61C68]&0x8000000 时 ×2）；NPC blit 尾 0x40C020 = 0x404DA0 模式 + 目标框 (0x320,0x1EC) 0x462710 + 受击闪烁；**0x40B180 阴影**（arg=1、kind [0x61BD4]：2→0x434A20 椭圆、0→(5,5,0xa)、8→(8,0xff)、else→(0xa,0xff)）；**0x40CE20 标签 = 仅玩家名牌**（0x41CCAF/0x41C76C；门控 [0x61C68]&0x100000 + GetTickCount 闪烁 >0x6A4 + 帧号 [0x62A24]+0x352/0x355 if state==0xf + 元素 81 0x566780 经 0x4542A0/0x466130）；**NPCIMG n = NPCFace.WIL 裸帧号**（0x43FFE7-0x440067 直取 0x466130 + atoi 0x4681F9，无客户端映射表）；**FCOLOR = 16 项 BGR 调色板 0x47C4A8**（修正 E7 的 12 色）；0x44A820 action→state 仅玩家/怪物（14 调用点 0x40E3FC-0x411508），NPC 状态<3 来自包；wilsdk：0x38/0x39 条带 12/12 非空、0x29 全空、0x28 前 4 帧非空（验证默认 (0,4,0x12C)）；npc-appearance pending 4→2（body 写点/NPCIMG 服务端脚本保留）；scene-entity pending 0x40CE20 项闭合。
  - **InventoryModeTabs（288，primary-static，`inventory-mode-tabs-evidence.json`）**：**3 页签（bag+0x5C stride 0xB4）= 装饰按钮**（vtable 0x4177F0 点击仅音效；bag 点击 handler 0x4300F0 读 mode 永不写）；**mode byte [bag+0x54] 仅服务端消息写**——mode0 默认（reset 0x42E9A4 / show 0x42AE26）、**mode2 变卖 msg 0x286**（一级 switch 0x41F8C6 字节表 0x421F2C idx0x18→case10→跳表 0x421EB0→0x41FA16）、**mode1 修补 msg 0x29C**（idx0x2E→case28→0x41FB24 + tab2 帧 0x108/0x109/0x107）、**mode3 储存 msg 0x2BC**（二级 switch 0x42042B cmp 0x44C / add −0x29F / cmp 0x88 → 字节表 0x422080 idx0x1D→case14→0x420AFC）、msg 0x29D case29→0x41FB6E 修补续（无 mode 写）；paint 分派 0x42EF2F cmp 3 / jmp [eax*4+0x42F13C]，分支标签 包袱 0x47BE10 / 修补 0x47BDF4 / 变卖 / 储存；**0x405 修正**：**0x451B00（push 0x405 @0x451B12）= 唯一 0x405 发送器，唯一静态调用方 = 死门 0x417280**（xref 总 1 → 0x42D6C6 category byte 4）→ **0x405 发送链死**；**0x451B30（push 0x406 @0x451B3F）= 交易金币支付活路径**（0x417034→0x451B30，ecx=0x8AB828）——**F283「0x405 via 0x451B30」为误标**，对话框 0x418030 存的 0x405 tag 从不发送；0x7DA100 = bss 零写、读点死门 0x41729D（atoi(arg2)>[0x7DA100] 门）+ bag paint 0x42EE4C（sprintf %d 字体 0x47BE18）——candidate 交易/购买量上限（运行时 watch 需）；bag-list 填充 0x42FC20 13 E8 调用方（10 个 0x41xxxx server handlers）、0x42FC40 中函数、0x42F440 record-place 虚（唯一调用方 0x42FC90）——运行时配对 msg 0x403/0x451AD0 需；inventory pending 4→2。
  - **StatusAndOptionNames（289，primary-static + primary-resource + secondary + candidate，`status-option-names-evidence.json`）**：**属性值 30 处绘制全 0xfafafa**（0x44BD37..0x44CCB2：14 首列 + 16 二列）、标签 28 处 0xfae1c8（含 魔法躲避 @0x44C1A7）、**4 处 0xff（防御@0x44C41C/攻击@0x44C4A6/魔法@0x44C52B/魔法防御力@0x44C90F）——旧「二列标签=0xff」修正（18 中仅 4 红）**；0x45DD70 共 62 调用 = 30 值 + 32 标签；魔法/魔法防御力仅标签无值绘制（残留）；**商店状态 0..4 业务名 = 0=BUY / 1=SELL / 2=仓库 / 3=CRAFT(合成) / 4=item detail**（0/3/4 primary-static：msg 0x285→0x41F92B→0x44F480、0x2C8→0x44FB00 state4 frame1002、state byte [esi+0x5F8]；1/2 仅服务端脚本佐证 @NPC_Sell/@NPC_Storage + Merchant.txt；CRAFT 错误 0x47B620/0x47B634 cp949 돈이 부족합니다/0x47B648/0x47B660 아이템이 잘 만들어 졌습니다 via 跳表 0x42210C；BUY 错误 0x47B904/0x47B91C/0x47B940）；**option 控件帧对**（ctor 0x440FE0 9 控件）：行 BGM [+0x130/0x1E4] y43、EffectSound [+0x298/0x34C] y116、Ambience [+0x400/0x4B4] y190、ShadowBlend [+0x568/0x61C] y217；**左对 760/761 = ON、右对 762/763 = OFF**（ctor tail 0x441226/0x441281/0x4412D2/0x441328，state 字节 +0x54/+0x58/+0x5C/+0x60）；**760/761 与 762/763 为 UP/PRESSED 对（非 ON/OFF 美术）**——像素包含 83/84 与 97/99 @(+2,+1)，反驳 system-window vision note；滑条 751 @(34,96)/(34,170)、config keys 0x47C594/0x47C5AC/0x47C57C/0x47C570；交易按钮帧：close 161/162 @0x415A63/0x415A68 (+0x7C (532,350))、accept 1061/1062 @0x415A91/0x415A8C (+0x130 (185,332))、cancel 1064/1065 @0x415AB7/0x415AB2 (+0x1E4 (225,332) 帧 None→隐形)、帧 1060 未用美术；**像素 OCR：1060=交易 / 1061=接受**；store SELL 网格 SetRect loop 0x44F806-0x44F833 x=323..475 y=43..157 on frame 1003；status pending 1→prose（魔法/魔法防御力值绘制残留）、draw-order pending 1→prose（exchange 量条填充 0x8AB828 运行时、option 字形 켬/끔 candidate）。
- **Round 7（Findings 290–295，2026-08-11，6 个证据 JSON）**：
  - **PlayerStateActions（290，primary-static，`player-state-actions-evidence.json`）**：SetAction vtable+0x10 = **0x4058E0**（ecx=actor, arg1=state, arg2=dir；入口 dir<8、type≤0x32、懒加载 per-object base [esi+0x90]=0x5600FC+[esi+0x8C]*324；分派字节表 0x405D64 + 跳转表 0x405D50 5 项）；type 0/1 共享公式 start[state]+storedDir*3000+argDir*10（**修正旧 750/40 误读**）、type 3 经 0x44A240、type 0x32 NPC 0x8AA6C8（dir%3）、types 2,4..0x31 no-op；尾 0x405CD7 提交 [0xC0]=state/[0xC1]=[0xC2]=dir/[0xC4]=[0xB4] 动画重启/[0xC8]=0，慢速 [0x61C68]&0x8000000 间隔×2；**33 行表 0x8AA5C0 stride 6 全枚举**（0 站(0,4,200)、1 走(0x50,6,100)、2/3 跑(0xA0/0xF0,5,75)、4 击(0x140,1,100)、5 特殊(0x190,1,100)、7 击(0x230,3,200)、8 伤(0x280,2,400)、9-0xE 六 85ms 攻击链、0xF 施法(0x4B0,3,100)、0x10/0x11 骑行走 A/B(0x500/0x550,10,70/90)、0x12 骑马站(0x5A0,10,70)、0x1E/0x1F 特殊对(0x960/0x9B0,6,100)、0x20(0xA00,3,100)）；骑马机 0x40E400（msg 0x51A→SetAction(0x11)+fx0x22、0x51B→SetAction(0x10)+fx0x23、0x51C→SetAction(0x12)）、0x410B00 骑乘状态机（msg 0xBC7/0xBD1/0xBD8/0xBD7/0xBD0 门控 [0x629D3]/[0x629D2]/[0x629D1]==0 设 2）；tick 0x411AB0（state {0x15,0x16,0x1E,0x1F,0x17,5} 加速/结束恢复 0x410720+SetAction(7,[0xC1])、完成回调 0x4068B0）；spawn-fx 0x40CD00；handler 0x40DB40/0x40DC20（[0xEC]=1/2/3）、0x17 完成→0x13/0xF/0x20；state 0x14 无写者（休眠）；挖矿/钓鱼两对 0x15/0x16 vs 0x1E/0x1F 分配 [INFERENCE]/KEPT-runtime
  - **EntityVtableFamily（291，primary-static，`entity-vtable-family-evidence.json`）**：**0x4764B0/0x4765B0 = 大表内槽位，从未安装**（0x4764B0 = monster 0x476480 +0x30 = 0x406A40、0x4765B0 = 子类 0x476544 +0x6C = 0x408630；全文件 imm32 0 命中）→ F269 'install path' 问题不成立；F286 'monster vtable 0x476400' 实为 0x4763C0 +0x40 槽；家族：0x4763C0 base entity（34 槽，ctor 0x404960，+0x0C dispatcher 0x404FB0/+0x1C tick 0x40ADD0/+0x20 frame 0x40AFD0/+0x7C draw 0x40B2C0/+0x84 HP 0x40B850）→ 0x476480 monster（42 槽，ctor 0x40C560）→ 0x476544 子类（43 槽，ctor 0x40FE90）；0x47671C NPC scene（34 槽 = entity 6 覆写，0x476728 = +0x0C 内槽 dispatcher，F269 'HUD' 修正）；effect 族 0x476884（ctor 0x434EF0 7 槽）；**0x476448 = list-node vtable（1 槽 {0x413D60}，19 安装点，F269 误标）**；window 族 0x476624 共享四元组 {0x423CA0, 0x423CF0, 0x423D00, 0x423F80}（31 安装点）、0x47663C trade、0x476638 页容器、0x476654 滑条、0x476814/0x476830/0x476834/0x476848 horse 区、0x4767E0/0x4767FC/0x476800 party 链、0x476378 列表类（4 安装点）、0x476370/0x476380 永不引用、0x4763A8 button；槽 0 全 MSVC scalar-deleting dtor
  - **HorseWindow（292，primary-static，`horse-window-state-evidence.json`）**：0x7DA060..0x7DA064 = session 0x777698+0x629C8；**byte0 = 2-bit 钳制 enum 0..3**（0 = 未骑马，非 0 门控 '@遛马' + 坐骑帧 × state*400；1/2/3 语义名 = server candidate）；写者 0x40F420（vtable+0x88）/0x40C720（+0x8C）存 dword[+0x629C8]+byte[+0x629CC]，0x40FED0（+0x14C）包装、0x410080（+0x150）；**词 0x7DA061-62 = 玩家染色、0x7DA063-64 = 坐骑 + HUD 马图标染色**（0x40FD6E/0x40FDB0 → 0x404E10；0x44B666 → 0x45FD50 arg6 = RLE op 0xC2 填充色，565 掩码 + 浮点缩放 0x4600B6；22 其他调用全 0xFFFF）；**词仅 server packet case 0x267/0x26B 写**（0x41F5BA/0x41F5C1，byte0 从不在此改）；pose 校验 0x405630；窗按钮 '@上马' 0x47B060/'@遛马' 0x47B068/'@收马' 0x47B058，分派 0x4520F0 → [0x8A68BC]=0x12C 计时
  - **BagListFillChain（293，primary-static，`bag-list-fill-chain-evidence.json`）**：0x42FC20 = bag record-place 核心（ecx=bag；stack flag/slot/record[0xC20] by value；ret 0xC28；mode 门 [esp+0xC48] → 0x42F2A0 解析 + 0x42F280 空槽扫描（46 槽，flag bag+0x774+i*0xC2C，空 -1）→ 0x42F440 place）；**13 直接调用方 = 10 handler / 9 msg id {0x35, 0xC8, 0x259, 0x268, 0x27C, 0x2A2(x2), 0x2A4, 0x2A5, 0x2A9}**（全 lea ecx,[ebx+0x2AB9E0] 玩家背包，分派表原始字节验证）+ 3 非 handler；**槽记录 bag+0x774+i*0xC2C**（flag /w+0x778 /h+0x77C，0xC20 body+0x780）；**网格 WORD 表 bag+0x324+12*row+2*col（6 列，空 0xFFFF）——修正旧 'cell 表 +0x2C4'**；修正：**msg 0x2A3 = trade-pending flush（0x416E20）非 bag fill**、0x29E = 金币对话框 + bag 统计重置；**trade +0x298 独立链，从不经 0x42FC20**（inbound 0x2A3/0x2A6/0x2AA → 0x4161F0 → 0x416490 word 写）；outbound 0x402/0x403/0x405/0x406 = 纯出站发送器，入站配对 = KEPT-runtime
  - **NoticeBanner（294，primary-static，`notice-banner-lifecycle-evidence.json`）**：**0x777200 = id-15 公告窗本体，非独立 banner**（winmgr 0x7243A4+0x52E5C；F268 0x7213A4/0x726500 笔误修正）；ctor 0x43E260 一次构造（id 0xF、frame 602、x=107、y=110、w=584、h=252）；**imm32 0x777200 全文件仅 2 命中**（0x425A4C show / 0x425B4A hide），对齐扫描 16 读全读、仅写 flag [0x7773D0]；**无 timer/counter/scroll 路径 → 显示时长无限期直到显式 toggle**（行会按钮 / 点击 0x42BE99 → 0x43E4B0 → toggle）；0x425A48 = 行会 ctrl4 邀请、0x425B46 = ctrl7 解散（分发 0x4258F0），均经 0x423E80 重显（frame 602/[0x7773D0]=1 vs 601/=0，文本 SetWindowTextA([0x7773CC])）；close-all 跳过 id 15（守卫 0x42B3DD）；**0x7ED/0x7EE = 内部 WM_USER 消息非网络协议（旧标修正）**；banner 提交绿勾 0x43E5D9 → 0x45DC70 → 聊天输入 0x8AB828（0x411/0x410）
  - **TradeGoldFlow（295，primary-static，`trade-gold-flow-evidence.json`）**：**0x7EE 交接忽略金额**（输入 → obj+0x130 → SendMessageA(0x7EE, wparam, lparam=&obj+0x130) @0x4185DB；接收者 0x404600/0x45A140 均不读 lparam；分发 0x41E522 → 0x41CDE0）；**接受 0x406 线上 = 纯头**（0x417034 → 0x451B30 → 0x452940 12B 头 {dword0=0, word+4=0x406}，MIR 编码 0x452740，sprintf '#%d%s!' 计数 [obj+0x14] 9→1）——无金币字段；**唯一活金币发送 = 聊天命令 0x41CDE0 case byte2==0x66 → msg 0x3F8**（头 {dword0=amount32}，界 [obj+0x35B1E8]）；**0x405 双重死**（唯一发送器 0x451B00 唯一调用方死门 0x417280 需 wparam==0x405，路由 0x42D680 仅分派 byte2 3..9 → 不可达，且 [0x7DA100]==0 抑制）→ 0x405 永不发送；**0x7DA100 = 死配置槽**（PE .data 加载零填尾；全图仅 2 读：死门界 + bag 金币 paint sprintf '%d'；0 写者 → 恒 0）；语义 [INFERENCE] = 未用交易金币上限，活界 [obj+0x35B1E8]；修正：EI-288 'category byte 4' → byte2==3、头金额 32 位、F284 prompt 0x47AD98 = '你要给对方多少金币?'

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
