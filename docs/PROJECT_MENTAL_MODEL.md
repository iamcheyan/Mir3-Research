# MIR3/ZIRCON 项目心智模型 — 主会话理解总账

> **本文档的用途**：记录主会话（和用户直接对话的那个 omp 会话）对整个项目生态的完整理解，
> 供未来任何会话（包括新的主会话）快速恢复上下文。每次主会话产生新的重要理解/决策/教训，
> 都应该更新本文档。
> 创建：2026-08-15 主会话（从 minimap 修复到编辑器军团到 Magic Lab 的完整一天）。
> 维护纪律：**新会话开工先读本文**；重大理解变化随手更新；文档即记忆。

---

## 一、项目的真实目标（用户视角，最重要的一节）

用户（tetsuya）做这一整套东西的**根本目的不是做网页游戏**：

1. **webport 网页客户端是理解工具/规格书**，不是产品。通过逐行移植把客户端吃透，
   产生的知识反哺工具链。parity 冲刺已全表 ✅（2026-08-15），**现状冻结**——
   不再投入新功能，只修影响参考价值的 bug。
2. **真正的产品线是编辑器三件套**：地图编辑器（mapviewer 进化）、NPC/数据摆放编辑
   （dbeditor 管线）、资源编辑器（wilviewer 进化）+ 第四件技能实验室（Magic Lab）。
3. 用户的核心哲学：**"内容一份，两个壳"**——素材/数据/协议/帧表/特效定义应该是
   单一事实源，改一处两端变；只有渲染/输入壳允许两份。历史上因为走了"手工移植"
   捷径造成多处双份维护，现在的所有工作都在把它拉回单一事实源模型
   （frames.js JSON 导出、magic-effect-table.json 都是这个方向）。
4. 工作方式：**主会话（对话）负责摸透+对齐+写超详细 goal 文档 → goal 会话
   （82 机器，tmux+omp+watchdog）无人值守长跑执行**。goal 文档必须自包含。

## 二、四仓生态与角色

| 仓库/机器 | 角色 | 关键路径 |
|---|---|---|
| `~/development/Zircon`（本机大写/82 小写 zircon） | 游戏本体：Godot 客户端 + ServerCore + LibraryCore | `GodotClient/`、`ServerLibrary/`、`LibraryCore/`、`Debug/{Client,ServerCore}`；原版 `Client/` 只读 |
| `~/development/Mir3-Research` | 工具+文档+研究：全部 web 工具、goal 体系、逆向研究 | `Tools/`、`docs/`、`scripts/goal_watchdog.sh` |
| NAS（本机 `/home/tetsuya/NAS/TMP/`，82 `/data/NAS/TMP/`） | 原版资源：EI 传奇3.0客户端、Mud3 服务端 | `MIR3_EI_ROOT` / `MIR3_MUD3_ROOT` |
| 82 机器（192.168.3.82，debian） | goal 军团执行机：tmux + omp + cron watchdog | 会话 ed-infra/ed-map/ed-res（E0/E1/E3）|

环境变量约定（AGENTS.md）：`MIR3_EI_ROOT` / `MIR3_MUD3_ROOT` / `MIR3_ZIRCON_ROOT`。
测试号 test@test.com/test123/TestHero（GM）。webport `?demo=1` 直进。

## 三、架构分层真相（用户问过、必须永远记住的）

| 层 | 共享状态 | 事实源 | 备注 |
|---|---|---|---|
| 服务器逻辑 | **共享** | ServerCore :7000 | 瘦客户端架构，战斗/移动全在服务端 |
| 素材（贴图/帧） | **共享数据** | .Zl/.wil 库 | webport 消费 webres 转的 WebP（Debug/Client/WebData，702M）|
| 线协议 | **双份手工** | `LibraryCore/Network/Packet.cs` | webport `net.js` 手抄；**C# 加删包类 → packet id 全表移位**，靠 packet_id_dump 反射表对齐 |
| 动画帧表 | **双份手工→正在合并** | `Functions.cs`/`PlayerObject.cs` | webport `frames.js`/`anims.js`（逐行移植，最准的 JS 版）；E3 正在做 JSON 事实源 |
| UI 布局 | 单向导出 | `GodotClient/UI/ui_tree.json` | UiTreeExporter 产物，webport 只读 |
| 技能特效 | **三份手工→E4 合并中** | 原版 `Client/Models/MapObject.cs:768` 巨型 switch | MagicInfo 表**没有**特效字段！Godot MagicEffectTable.cs（697 行，95 技能+白名单）是手工提取 |
| 渲染/输入 | 必然两份 | — | Godot 引擎 vs DOM，运行时不同 |

## 四、坐标系与渲染约定（一天里踩过两次的雷）

| 坐标系 | 定义 | 谁用 |
|---|---|---|
| 游戏格 | EI rect 布局，**48×32 px/格** | System.db Region、服务器包、编辑器语义 |
| 世界像素 | `x*48, y*32` | mapviewer 瓦片 |
| mapviewer overlay | **内容坐标**（不减 scrollLeft/Top）| overlay 是滚动容器子元素，随内容滚；剔除窗口 `[scroll, scroll+vp]`。减了就是双重偏移（62f6499 修的 bug）|
| webport 逻辑画布 | **固定 1024×768** | Godot project.godot window/size；世界 canvas+HUD 同画布，UiScaler 整体 transform 缩放；`camera.setResolution(1024,768)` 固定。曾因 `body.ingame{transform:none!important}` 全盘错位（已修）|
| minimap 索引 | ZL 客户端：**客户端** System.db MapInfo.MiniMap（544 条，0=占位；服务端库 87/244 空帧不可用）；EI：Envir/MiniMap.txt（≥1001→FMMap v-1001；<1001→MMap v-1）| 两个 dump 在 /tmp，重启服务才生效（lru_cache）|

`.map` 格式（mapviewer `parse_map` 实证）：28B 头（w@22,h@24 u16 LE）+ 半分辨率地面表 3B/entry + 全分辨率 14B/格（flag/animA/animB/frontFile/midFile/midImg u16/frontImg u16/+5B 填充）。**写回前必读原版 MapControl.cs 确认 +1 偏移**（沙巴克事故教训：验证工具不得与生产工具共用同一错误）。

## 五、服务与端口（hub 名称即启动名）

| 端口 | 名 | 用途 |
|---|---|---|
| 7000 | zircon-core | 游戏服（DB 加载 ~11s 才就绪；hub 起 dotnet 必须 `bash -c "cd <目录> && exec dotnet xxx.dll"` 包装）|
| 7001 | wsgateway | WS→TCP 透传（纯透传，服务器没起则登录即断）|
| 8823 | webport | 网页客户端（资源服务）|
| 8899 | mapviewer | 地图查看/编辑器宿主 |
| 8810/8800/8765/8822 | dbeditor/dbviewer/wilviewer/webclient | DB 编辑（写回管线）/DB 查看/资源查看/静态世界测试台 |

坑：hub daemon 名被 `pendingCompletion` 坏记录卡死 → **换名**别死磕；
/tmp 缓存三件套（minimap×2、map_cn_full.json）被清 = 小地图/中文名全丢，
生成命令见总纲 §3.4。

## 六、写库纪律（绝对红线）

- **绝不直写 .db**。唯一写路径：dbeditor workspace JSON → `/api/sync` → `sync.sh`
  → C# DBImporter → 校验 → 备份双库（Server+Client）→ 原子安装 → round-trip 报告
- 服务端运行中绝不写 System.db（sync.sh 自带端口检测）
- 写前备份；round-trip 读回验证；失败路径原库不动

## 七、Goal 军团体系（82 机器）

- 结构：tmux 会话（ed-infra/ed-map/ed-res）+ `omp --auto-approve "$(cat prompt)"` 启动
  + cron `*/5` 跑 `scripts/goal_watchdog.sh`（HEALTHY/RUNNING/PAUSED/STALLED/DEAD/
  COMPLETED 判定，卡住发「继续」，死了 `omp --resume --auto-approve` 拉起，完成自动
  kill-switch 回收，记 ~/.omp/logs/goal-completed.log）
- GOALS 数组行格式：`<session-id>|<jsonl绝对路径>|<tmux名>|<workdir>|<中文标签>`
- 现役：E0 基础设施（ed-infra）/ E1 地图编辑器（ed-map）/ E3 资源编辑器（ed-res）；
  E2 NPC 摆放等 E1 拆完 mapviewer 模块再插；E4 Magic Lab 待启动（文档已就绪）
- 任务书：`docs/editor/EDITOR_GOALS_MASTER.md`（E0-E3）+ `docs/magiclab/MAGIC_LAB_GOAL.md`（E4）
- 冲突协议：文件领地制；mapviewer.py 是 E1/E2 交汇点（E1 先拆模块）；共享文件小改标 `[shared]`

## 八、E4 Magic Lab 摘要（2026-08-15 定案，详见其 goal 文档）

诊断：特效对不上的根因 = MagicInfo 无特效字段，特效由原版 MapObject.cs:768 巨型
switch 决定，Godot/webport/webclient 三份手抄各自漂移，无系统验证循环所以
"调一个坏一个"。方案（用户拍板）：webclient(:8822) 改造为实验室基底 +
原版 switch 提取 `magic-effect-table.json` 唯一事实源 + Godot 表生成/校验闭环 +
174 技能批量截图画廊回归。P0 提取 JSON（含 Godot 表对账报告）→ P1 实验室 UI
（四职业技能列表+木桩+慢放/逐帧/轨迹）→ P2 回归画廊 → P3 Godot 闭环 →
P4 伤害预览（二期）。

## 九、方法论（用户认可的工作节奏）

1. 主会话摸透：读代码/实证（跑起来看）→ 形成诊断
2. 与用户对齐：方向性选择用 ask 拍板（推荐选项要给理由）
3. 产出自包含 goal 文档（铁律：数据约定先读原版源码、验证工具独立实现、
   行为验证≥编译验证）
4. 82 goal 军团执行；主会话只监控（tmux attach / watchdog 日志 / git log）
5. 知识沉淀：新坑回写文档；重要结论进 zdocs/docs

## 十、会话保存与恢复（用户问的"如何保存这次对话"）

omp 会话即文件，三层保存法：
1. **自动**：本会话 transcript 在 `~/.omp/agent/sessions/<workdir-slug>/<时间戳>_<id>.jsonl`
   ——永久保存，永不丢失
2. **恢复继续聊**：`omp --resume <会话ID前缀>`（交互选择器）或 `omp -c`（最近会话）；
   即便不 resume，新会话先读本文档即可恢复全部理解
3. **跨会话记忆锚点 = 本文档**：commit 进 Mir3-Research 仓库（fork 远端备份），
   任何机器/任何会话 `git pull` 即得。AGENTS.md 已被 omp 自动加载，可在其开头
   加一行指向本文档（见下方"待办"）

## 十一、当前状态快照（2026-08-15 会话末）

- 本机已推 fork：`62f6499`（mapviewer NPC 面板+overlay 修复、webport UiScaler 修复、
  csproj 修复）、`eae891d`（编辑器总纲）、`880771b`（Magic Lab goal）
- 82 已跑：E0/E1/E3 三 goal（ed-infra/ed-map/ed-res），watchdog 已注册
- E4 Magic Lab：文档就绪未启动（等用户指令或 82 直接开）
- webport：冻结，UI 错位已修（R34）
- 待办：E2（等 E1 拆模块）；AGENTS.md 加指向本文档的行；vision 模型
  openai-codex/gpt-5.6-luna 已配好
