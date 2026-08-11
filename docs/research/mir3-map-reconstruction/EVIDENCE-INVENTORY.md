# Mir3 EI 地图重建 — 证据清单（confirmed / derived / candidate / pending）

分级定义：

- **[confirmed]** 直接证据（反汇编 / 二进制结构 / 运行中工具输出），可复现。
- **[derived]** 由 confirmed 事实推断，未运行原版客户端或缺少一端对照。
- **[candidate]** 有候选解释但证据不足，禁止标记为 confirmed。
- **[pending]** 已知未解问题，明确列档。

---

## confirmed

| # | 结论 | 证据 |
|---|---|---|
| C1 | `.map` = 28B 头 + 地面 2×2 块区 + 14B/格 cell（legacy 13B 为独立格式） | 二进制解析 + catalog 544 图全通过 |
| C2 | 库表槽号 = v 变换结果（KR_ORDER），地面/物件库引用按此解析 | audit_mir3_maps v_lookup + FramePool |
| C3 | 投影为 rect 等距：`destX=(x−viewX)·48−scrollX−200`、`destY=(y−viewY)·32−scrollY−h−125` | Mir3.exe 0x43bb10/0x43be00 |
| C4 | 地图层锚点全部格底/格左；ground 底 = mid/front 帧底 = −125 同线 | 锚点数学（destY+h） |
| C5 | 地图层（ground/mid/front）全分支**零 offset** 读取 | 43bb10/43be00/43b440/43b9a0/43c330/43c4c9 全分支 |
| C6 | actor 层读帧 offset（+4/+6）并加进 dest | 430aab/430aaf（0x430b00） |
| C7 | 绘制顺序 ground → mid → front → actor | per-cell 调用序 41c4xx → 41c59a/41c5a5/41c66d/41c678 → 0x430b00 |
| C8 | func1（43bb10）= 仅 48×32；func2（43be00）= 跳过 48×32 | 尺寸门控 43bed9 |
| C9 | 0x434a20 = 选区/足迹几何（fsqrt 半径 + u16 点对写 this+0x35b2c0），非绘制 | 0x434670 助手 + 0x468520 舍入，区段无 blit |
| C10 | EI 空帧 = 0xFFFF；file 15 = 无物件（不绘制） | catalog reserved/EMPTY_FRAME 统计 |
| C11 | 3.map 帧越界根因 = EI 素材帧数 < 地图引用（lib24/25 wood_*） | catalog frame_oob vs lib_frames |
| C12 | ZL 地面 alpha=4 根因；ZL 客户端不逐格画 Tilesc | ZL 客户端源码对照 |
| C13 | 模拟器实体数据源 = Mud3 服务端（Envir） | 服务器运行输出 |
| C14 | 544 图 catalog 与 800×800 rect 全图渲染对齐 | 10 图 z4 面板 + sim 帧 |
| C15 | catalog anomaly 统计口径与 audit 一致（5723 总 / 34 图） | 重建输出对比 |
| C16 | offset 三模式（none/all/midfront）按 om 参数加性应用 ×scale，缓存键含 om | render_tile/render_full_map 实现 + 像素差验证 |
| C17 | tiles5c 帧 20–24 资源本身近纯黑（mean≈2.7/std≈3.8），非解码错误；tiles5c f20 = 全库引用最多的帧（293,933 格，14B 解析 1.2M 格引用黑帧） | lib_frame_stats 全库 544 图重解析 + previews 蒙太奇目视 |
| C18 | 地图黑块根因 = 地图数据显式引用黑帧（约 1.2M 格），D201 类黑块为资源侧事实 | 14B 解析统计 + D1423 模拟帧 black-frac 0.204 |
| C19 | 模拟器图层（Back/Middle/Front）可独立开关渲染，缓存键含 g/m/f；/api/cell 逐格返回三层库/帧/flag/anim；/api/strip 导出三模式对比条带 | mapviewer 实现 + 浏览器实测（图层开关即时生效、tooltip 逐格数据） |
| C20 | Envir MonItems 掉落文件已接入模拟器：怪物点击 tooltip 显示 掉落 前5（如 半兽勇士 金币×4000 1/1） | load_drops 解析 280 个 MonItems 文件 + /api/entities 实测 |
| C21 | 544 图逐图勘察完成：城镇/室内/半兽洞穴/赤月山谷/沃玛/沙漠雪地六大类结构定型；34 图 5723 异常按 8 类错误分类（map-file/library/frame-decode/offset/坐标/图层/版本/特殊处理），无 map-file 与库表错误 | MAP-SURVEY.md 全表 + catalog/audit 统计 |
| C22 | 帧越界语义：FetchFrame（0x466130；type0 WIL 0x466640、type1/2 ZL 0x466720）在解引用前比较帧号 vs 库帧数——`0x46664A cmp edi,[esi+0x10]; 0x46664D jae 0x466714`（type0）、`0x466727 cmp eax,[ecx+0x2C]; 0x466729 jae 0x466761`（type1/2）→ 越界/空帧(offset 0)/宽高>4096 返回 0 → 全部 7 条绘制路径 `test eax,eax; je <纯尾声>` 跳过 → **单元格不绘制（透明）**；无取模/首帧/空帧替换/无检查四假说全部排除 | frame-oob-semantics-evidence.json（Finding 274，primary-static） |
| C23 | 空地面格跳过机制：ground 0x43b440 逐 2×2 块四重门控——`T%14<=2`（0x43b53c，T=file−⌊file/14⌋）、`T<=0x45`（0x43b545）、`frame!=0xFFFF`（0x43b54a）、lookup 非空（0x43b569）；T(255)=237 被门 A+B 拒、frame 0xFFFF 被门 C 拒；地面缓冲先清零（0x43b455 rep stosd，0x1B0000 B）→ 空档在原版渲染为**黑** | ground-not-drawn-evidence.json（Finding 275，primary-static） |
| C24 | offset 分布定案：地图层库（tiles/object 族）98.8% 数据帧 offset 非零——城镇/主题族统一 (−24,−16)（Tilesc/Tiles30c/Wallsc/Cliffsc/Housesc/SmObjectsc/Animationsc/Innersc/Dungeonsc/Sand_*/Wood_*）、洞穴族统一 (7,−44)（Tiles5c 10000+/object1c/object2c/SmTilesc 10000+），另 4,220 帧 (0,0)；furnituresc 含巨量垃圾 offset（如 30280,21537）且 0.map 正常渲染 → **C5 零 offset 读取为有意约定而非平凡零值**；需要 offset 的库 = actor（C6）与 Interface1c 控件（519 对） | offset-distribution-evidence.json（Finding 276，derived，123 库 1,084,929 帧全扫） |
| C25 | 小地图帧放置公式（confirmed）：painted rect=(0,0,W·1.5,H)、1.5 px/tile X / 1 px/tile Y、帧尺寸=ceil4(W·1.5)×H、原点左上；面板 128×128 @ (672,0)-(800,128)，客户端随玩家滚动源窗口；**帧索引规则：客户端索引 = server值−1（MMap.wil）或值−1001（FMMap.wil）**——EXE setter 0x43D780（调用者 0x420C3A 做 dec）、float 1.5 @0x476904、帧矩形 0x43D7AD-0x43D7C7、面板 SetRect 0x43D518/0x43D545、库串 0x47C414/0x47C428 | minimap-calibration-evidence.json（Finding 277，313 行全枚举 + 241 头可读比对，229 帧吻合公式） |
| C26 | 保留标记帧语义：客户端**精确比较** frame==0xFFFF（0x43BB45/0x43BB4A、0x43BBBB、0x43BE3A/0x43BEAB、0x43B321），**非掩码**——0x43A000–0x43E000 区 grep `0xff00` 立即数 0 命中；0xFF00–0xFFFE 通过 0xFFFF 比较后进入 FetchFrame 边界检查（0x46664A）必然失败（库帧数最大 33,125 < 65,280）→ 返回 0 → 不绘制；『保留标记』= 地图数据/编辑器约定，客户端无特殊处理 | reserved-frame-markers-evidence.json（Finding 278，primary-static） |
| C27 | 保留/幻影帧分布定案：22 库纯保留+混合引用全部集中在 **39 个 legacy 13B 探针图**（每主题每库 1 格自检格），真实 14B 图保留格 = 0（早前『4.map 1604』为 0xFFFF 误计）；『3 库全幻影』不可复现——最接近为 41/49/54 库仅有空占位引用（wix offset 0 = 空白）；26 个保留值 0xFF00–0xFF80，原始 41,996 格 / 解析后 8,286 格 | reserved-frame-markers-evidence.json（Finding 278，primary-static） |
| C28 | 遮挡窗口 + world-sort 网格闭合（VA 级 primary-static）：tile pass 1 遍历 [camY−0xA,camY+0x22)×[camX−0xA,camX+0x22)（44×44）；遮挡窗口 0x41C5AA–0x41C5DE **仅 [camX,camX+0x18)×[camY,camY+0x18)（24×24）传相对坐标**，窗口外全传 (0,0)→cell 0，由 [e+0x61C74]/[e+0x8A]==0x7F 门控 + 玩家身份过滤；**0x7F=强制绘制标记**（非 round-3「transparent」）；world-sort 网格 [root+0x154,root+0xE1154) = 24×24 cells × 100 slots × 16B（0x38400 dwords rep stosd），cell 偏移 1600·(24·dy+dx)，链表头 [root+0xE1158]；渲染器 dispatch：type 0/1→vtable+0x7C+阴影+标签、**type 2→SKIP（隐形占位/触发实体）**、type 3→仅精灵、type 4..0x31→SKIP（走 tick chain）、type 0x32→vtable+0x7C+阴影无标签；两处 round-3 map 读数错误修正（sort tick/draw type 分支） | scene-entity-render-evidence.json round5_closure（primary-static，date 2026-08-11） |
| C29 | 实体帧表静态源定案：0x8AA5C0（玩家 33 条）/0x8AA686（怪物 9–11 条）/0x8AA6C8（NPC 3 条）= BSS 单例 0x8AA5A8 的字段（obj+0x18/+0xDE/+0x120），内容 100% 编译期立即数（0x449C80 启动种子 + 0x44A240 race 覆盖 + 0x44A090 NPC action 覆盖，统一经 3 字写器 0x449C50）——**『表内容=服务器数据』旧假设证伪**；步长 6B=(w0 块起始帧, w1 块长, w2 帧间隔 ms)；渲染公式 player=w0+3000*type+10*flag、monster=w0+1000*(race%10)+10*flag、NPC=w0+100*body+10*(flag%3)；0x44A820 = action→状态映射器（非表写器）；Mir3.dat = 辅助 PE（仅 WIL 路径字面量）；weapon.ord = 武器外观顺序（0x44A8B0 载入 obj+0x132，本安装未随附） | state-frame-tables-evidence.json（Finding 279，primary-static） |
| C30 | 怪物名→库/帧映射闭合（P5）：客户端 16 位 code = monster.dat **Race** 字段（非 Appr）；库 = Mon-(Race//10+1).wil、帧基 = 1000*(Race%10)、element = 0x58+Race//10（race<2000）；race>=2000 → element=0x87+(race−2000)//100、帧 100*((race−2000)//100)；经验全扫 432/432 Race 命中（Appr 328/432）；DMon-1.wil 死亡块 = Race//10；**MInfo.dat 前提修正 = 魔法效果库**（#SPELL 109/#MAGIC 147/#EXPLOSION 39 节，4-pass XOR 解密链 0x44A910，校验和 XOR 0x9FDE1A93(sum((payload[i]+1)*i))=0x8CE329C1 验证）——怪物名数据源 = 服务端 monster.json；WIL 槽格修正：槽偏移 = 0xf848+slot*0x104（Mon-1=18…Mon-20=37、NPC=58、DMon-1=65、StoreItem=69）；P11 闭合：夜行鬼09/异界之门 FOUND（Race 19→Mon-2 块 9），葛贰厘面0/诺玛教主2/魔神怪8 服务端缺失 | monster-dat-evidence.json + monster-dat-catalog.json（Finding 280，432 行，derived/primary-static 混合） |
| C31 | NPC 外观体系闭合（P4）：type 0x32 → element 128（0x4051E0/0x405810）→ 记录 0x5600FC+0x144*elem → [entity+0x90] → NPC.wil（槽 79，dest +0x13330）；**NPC 帧 = word[0x8AA6C8+6*state] + 100*body + 10*(flag%3)**（body=[edi+2]/[esi+0x8A]<0x64，非 round-3「100*dir」——方向槽 [0xC2] 被复用存 flag）；NPC.wil 6400 帧 = 64 body × 100；特殊 body 码语义定案（0x18/0x19/0x22/0x23/0x2B..0x32/0x3A→仅站立、0x28/0x38/0x39→flag=0、0x33..0x37/0x3B→1 帧+0x44A090 action 覆盖、0x1B/0x1C→变体、0x29→隐形）；NPCFace.WIL 绑对话窗 +0x278，NPCIMG 脚本 token（0x47C50C）→ 帧 n @(40,30)，FCOLOR 调色板，NOTCLOSE 禁关 | npc-appearance-evidence.json（Finding 281，primary-static） |
| C32 | 玩家外观合成闭合：type byte0 → element 0x47（M-Hum）/0x4C（WM-Hum）（0x404FE5/0x405003/0x405673/0x405689 双路径）；元素表 0x5600FC stride **0x144**（0x40590A-0x40591C 九倍验证；旧 x36 取消）；WIL 槽表 base ebx+0xB130 stride 0x104，**element == 槽索引**（六交叉验证 71/76/87/88/128/131）；玩家帧 = word[0x8AA5C0+6*flag] + 3000*S + 10*dir（3 读点一致；M-Hum 27000=9×3000）；叠加 0x40F5F0 六遍（坐骑/武器/身体/头发/头盔 + 模式 blit）；M-SHum.wil EXE 0 引用（不在合成链）；CreateChr.dat = AVI 片头（1,221,572 B RIFF，非外观表）；0x404DA0 渲染模式 6 位 → mode 字 | player-composition-evidence.json（Finding 282，primary-static） |
| C33 | 交易窗口（玩家对玩家）渲染体系闭合：id 3 / ROOT+0x3399C（0x1369C B）/ vtable 0x47663C / ctor 0x4159D0 / 注册 (1,330,484,0,0,F1050,src,3) / paint 0x415B10 / 点击 0x416EF0→0x42ADB0 重激活；**帧 1050（512×512 @(7,−44)）唯一静态美术**，UI 命中 484×330 → 美术溢出；按钮（关闭 161/162、接受 1061/1062、取消 1064/1065）**从不绘制**（0x417640 零 xref）——静默 PtInRect 命中区 + 音效 0x69，1064/1065 帧在 GameInter.wil 不存在（count 1103）→ 隐形设计；物品网格 24 槽 @+0x5B8 stride 0xC2C、item-id 词 @+0x298（空 0xFFFF）、36px 5×6；金币盒 (34,270)..(156,304) + '确定' → 协议 0x405/0x406 → 0x8AB828；分割把手 2 个 @+0x13648/+0x13694（帧 1070 16×360，从不 blit，鼠标 0x416E70 写 [+0x54]/[+0x58]）；**交易 ≠ 商店**（商店 = id 2 / 0x44D310 / paint 0x44E260 渲染控件循环） | trade-window-render-evidence.json（Finding 283，primary-static） |

## derived

| # | 结论 | 依据 |
|---|---|---|
| D1 | EI 原版视觉 = 本项目 rect 基准（原版客户端无法本地运行） | 反汇编 C3-C8 |
| D2 | 原版 = `om=none`（零 offset）；`midfront` 近原版、`all` 破坏观感 | 10 图条带视觉 + diff stats（0.map nonevsall 70% 像素差） |
| D3 | 39 张 Snow/Forest 主题图 = legacy 13B，不可用 14B 解析器渲染 | catalog legacy 统计 |
| D4 | ~~室内图地面未绘制或与 ZL `MapInfo.Background` 机制同类~~ → **已反驳（C23）**：EI 室内地面为瓦片（0_003：tilesc/tiles30c 1363 块；5_0013：tiles5c/tilesc 1089 块），ground_not_drawn = 空地面格跳过 + 黑底，非静态背景图 | ground-not-drawn-evidence.json 0_003/5_0013 格级分析 |
| D5 | 图层顺序结论可直接用于模拟器/渲染器实现（ground 先、front 后、actor 最上） | C7 + mapviewer 实现 |
| D6 | midfront offset 对洞穴图（D1423）近无影响（0.8% 像素差），all 模式破坏地面（26.6%）→ 与原版 none 一致 | 800×1200 全图 diff：nonevsall (14.49,0.266) / nonevsmid (0.8,0.022) |
| D7 | 室内图未绘地面带在原版渲染为黑边（0_003 绘制区 58×94/60×100、5_0013 66×66/68×68） | C23 合成（缓冲清零 + 跳过） |

## candidate（未证实，勿升格）

| # | 候选解释 | 说明 |
|---|---|---|
| K1 | 越界帧替换逻辑 = 空帧显示 | 3.map 面板 EI 物件缺失；替换规则未反汇编 |
| K2 | 室内图地面 = 静态背景图而非瓦片 | D4 候选，需 MapInfo 证据 |

> Round-4 闭合：K1（越界帧替换=空帧显示）→ 排除，真机制 = 显式边界检查+跳过（C22）；K2（室内静态背景）→ 排除，真机制 = 空地面格跳过（C23）。

## pending

| # | 问题 | 备注 |
|---|---|---|
| P4 | ~~实体层 NPC 外观：body 字段 → NPC.wil 帧块精确布局~~ → **已闭合（C31）**：NPC 帧 = 表基 + 100*body + 10*(flag%3)，body<0x64，64 body × 100 帧几何 + 特殊码语义；NPCFace 对话头像经 NPCIMG 脚本 token | npc-appearance-evidence.json（Finding 281，primary-static） |
| P5 | ~~怪物名 → Mon-1.wil 库/帧映射（monster.dat 专有格式）~~ → **已闭合（C30）**：code = Race（非 Appr），库 = Mon-(Race//10+1).wil、帧基 = 1000*(Race%10)；MInfo.dat = 魔法库（非怪物库），怪物名数据源 = 服务端 monster.json；432 行 catalog | monster-dat-evidence.json + monster-dat-catalog.json（Finding 280） |
| P6 | ~~小地图 FMMap/MMap.wil 帧内地图间留白逐图校准~~ → **已闭合（C25）**：放置公式 + 帧索引规则（MMap=值−1）；交叉引用/模拟器已更新 | minimap-calibration-evidence.json（Finding 277） |
| P7 | ~~41c5aa-41c5de 遮挡窗口细节~~ → **已闭合（C28）**：仅 24×24 窗口内传相对坐标，0x7F=强制绘制标记，玩家身份过滤 | scene-entity-render-evidence.json round5_closure（primary-static） |
| P8 | ~~0x41cbd0 actor 渲染器体、0x419d40 身份~~ → **已闭合（C28）**：24×24×100×16B 网格 + 链头 0xE1158，type dispatch 定案（type 2 隐形占位、4..0x31 走 tick chain、3 仅精灵） | scene-entity-render-evidence.json round5_closure（primary-static） |
| P9 | ~~EI 素材中帧 offset（+4/+6）非零值的分布~~ → **已闭合（C24）**：地图层 98.8% 非零（统一常量），C5 零读取为有意约定 | offset-distribution-evidence.json（Finding 276） |
| P10 | ~~22 个库仅有保留标记帧（0xFF00+）引用、无解码帧；3 个库全部引用幻影帧（无数据）~~ → **已细化（C26/C27）**：0xFF00+ = 普通越界不绘制（精确 0xFFFF 比较）；22 库纯保留+混合引用全在 13B 探针图；『3 库全幻影』不可复现（空占位引用） | reserved-frame-markers-evidence.json（Finding 278） |
| P11 | ~~98 个 .gen 怪物名中 4 个无法匹配 MonItems（夜行鬼09/异界之门/葛贰厘面0/诺玛教主2/魔神怪8）~~ → **已闭合（C30）**：夜行鬼09（Index 186）/异界之门（Index 187）FOUND（Race 19 → Mon-2.wil 块 9）；葛贰厘面0/诺玛教主2（近邻 诺玛教主 Index 282）/魔神怪8（有 魔神怪1/2/10/20）服务端 monster.dat 缺失 = 服务器数据缺口 | monster-dat-evidence.json（Finding 280） |
| P12 | 小地图源窗口滚动（客户端随玩家滚动 128×128 面板内的源窗口）的精确 scroll 数学 | C25 面板/公式已定，scroll 偏移需运行时捕获（candidate） |

## 工具链

- `Tools/maps/audit_mir3_maps.py` — 结构审计（v 变换、库表、anomaly）
- `Tools/maps/build_map_catalog.py` — per-map JSON + per-lib 帧统计 + 汇总
- `Tools/maps/lib_frame_stats.py` — 全库帧直方图 + 每库抽样帧级像素统计 + 蒙太奇
- `Tools/maps/mapviewer.py` — 渲染器 /fullmap /tile /sim /api/cell /api/strip，offset 三模式、Back/Middle/Front 独立开关、实体（含掉落）层
- `Tools/maps/render_map_comparison.py` — EI vs ZL 面板与 offset 条带
- `Tools/maps/offset_distribution.py` — 全 Data/*.wil 帧 offset（+4/+6）非零分布扫描（Finding 276）
- `Tools/maps/gen_minimap_ei.py` — EI 小地图索引 dump（MMap = 值−1 修正后规则，Finding 277）
- 产物：`docs/research/mir3-map-reconstruction/{catalog,comparisons,lib-frames}`、
  `docs/research/mapviewer-investigation.md`、`LAYER-ORDER.md`、`OFFSET-EXPERIMENT.md`
