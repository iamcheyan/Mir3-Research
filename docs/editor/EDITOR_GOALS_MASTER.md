# 编辑器军团总纲 — 地图/数据/资源编辑器多 goal 并行作战文档

> **本文档是唯一任务书**：自包含、不依赖任何特定机器的运行状态。
> 目标读者：在 82 机器上执行的多个 omp goal 会话（每个 goal 拿到自己那一章当任务书）。
> 来源：2026-08-15 主会话全面摸底 + 实证修复（commit `62f6499` 及此前 parity 冲刺全量验收）。
> 仓库：`~/development/Mir3-Research`（工具+文档）+ `~/development/Zircon`（游戏本体）。
> **开工第一步：两个仓库 `git pull`，确认包含 Mir3-Research `62f6499`。**

---

## 0. 这份文档怎么用

1. 82 机器上准备环境（§4 环境引导，一次性）
2. 按 §5–§8 启动四个 goal（E0/E1/E2/E3），每个 goal 一个 tmux 会话 + omp 会话
3. 每个 goal 的初始 prompt = 本文档对应章节 + "完整阅读 docs/editor/EDITOR_GOALS_MASTER.md 中你的章节，严格按验收标准执行"
4. 注册 `scripts/goal_watchdog.sh` GOALS 数组（格式见 §9.1）
5. 冲突协议：各 goal 只写自己领地文件（§9.2），共享文件小改标 `[shared]`

**全局铁律（违反任何一条 = 工作无效）**：

- 数据约定先读原版源码确认，再写工具（尤其 .map 帧索引的 `+1/-1` 偏移，见 §3.4）
- 验证工具必须独立于生产工具实现（不能复用同一套解析逻辑自洽验假）
- 行为验证 ≥ 编译验证：编译通过只证明语法，不证明逻辑；改登录/渲染/数据必须跑真实流程
- 写 System.db 只经 dbeditor 的 sync.sh 管线（§6.2），服务端运行中绝不写库，双库同步写，写前备份，round-trip 读回验证
- 原版 `Client/` 源码只读（Zircon 仓库约定）
- commit 信息中文；推送 `fork`（iamcheyan/*），不是 origin

---

## 1. 背景与定位（为什么做编辑器）

### 1.1 webport 的角色：规格书，不是产品

webport（:8823 网页客户端）已完成行为级 parity 冲刺（`docs/webport/parity/PARITY_CHECKLIST.md` 全表 ✅，2026-08-15）。它的价值不是"在网页上玩游戏"，而是**把客户端逐行吃透后留下的可执行解剖报告**：

- `net.js` = `LibraryCore/Network/Packet.cs` 的 JS 移植（376 包全量 + packet_id_dump 反射表）
- `world.js`/`anims.js`/`frames.js` = `MapObjectNode.cs`/`PlayerObject.cs:578-803`/`Functions.cs` 逐行移植
- `dx.js`/`dxgrid.js`/`keybinds.js` = `GodotClient/Controls/*` 移植
- 每个文件头标注 C# 源行号 = 精确到行的知识索引

**webport 现状冻结**：不再投入新功能（EI 参考模式等长尾放弃）；只修影响参考价值的 bug。做编辑器时的查代码顺序：webport JS（快，有行号索引）→ Godot C# 源码（权威）。

### 1.2 编辑器是真正的产品线

三件套共享同一套底层知识，webport/工具链已消化大半：

| 编辑器 | 需要的底层知识 | 已有参考实现 |
|---|---|---|
| 地图编辑器 | .map 二进制格式、瓦片分层、帧索引 | `Tools/maps/mapviewer.py`（解析+渲染全有，缺写回）+ `webres.py` |
| 数据(NPC/Region)编辑器 | System.db 表关系、坐标约定 | `Tools/dbeditor/`（写回管线完整）+ mapviewer NPC 层（显示/跳转已有） |
| 资源编辑器 | WIL/ZL 库结构、帧锚点、纸娃娃公式 | `Tools/wilviewer/`(:8765) + `wilsdk.py`/`zlsdk.py` + webport `frames.js` |

---

## 2. 全景架构（共享 vs 重复，防止误解）

| 层 | 状态 | 说明 |
|---|---|---|
| 服务器逻辑 | **共享** | ServerCore :7000，战斗结算/移动校验全在服务端 |
| 素材（贴图/帧） | **共享数据** | 两端读同一份 .Zl 库；webport 消费 webres 转的 WebP（`Debug/Client/WebData/`，702M） |
| 线协议 | 双份手工维护 | 事实源 `LibraryCore/Network/Packet.cs`；webport `net.js` 是手抄本。**C# 加/删包类 → packet id 全表移位 → 必须重跑 packet_id_dump** |
| 动画帧表/公式 | 双份手工维护 | 事实源 `Functions.cs`/`PlayerObject.cs`；webport `frames.js`/`anims.js` |
| UI 布局 | 单向导出 | `GodotClient/UI/ui_tree.json`（UiTreeExporter 产物）→ webport 只读 |
| 渲染/输入 | 必然两份 | Godot 引擎节点 vs DOM/Canvas，运行时不同 |

原则：**编辑器要用的知识，优先从"已消化的参考实现"取，取不到读 C# 源码，读完把结论写回文档。**

---

## 3. 已实证的约定与坑（本节是全文档最值钱的部分）

### 3.1 坐标系约定总表

| 坐标系 | 定义 | 使用处 |
|---|---|---|
| 游戏格 | 整数格坐标 (x,y)，EI rect 布局，每格 **48×32 px** | System.db Region、服务器包、编辑器语义层 |
| 世界像素 | `cell.x*48, cell.y*32` | mapviewer 瓦片/overlay |
| mapviewer overlay | **内容坐标**（世界像素/缩放，**不减** scrollLeft/Top） | overlay 是滚动容器 `#viewport` 的子元素，随内容滚；剔除窗口 = `[scroll, scroll+viewport]`。违反 = 双重偏移，标记飞出屏幕（62f6499 修的就是这个） |
| webport 逻辑画布 | **固定 1024×768**（Godot `project.godot window/size`） | 世界 canvas + HUD 同画布；`UiScaler`（dx.js）整体 transform 缩放居中；`camera.setResolution(1024,768)` 固定。**禁止** `body.ingame` 用视口尺寸/废 transform（已删，见 style.css R34 注释） |
| minimap 帧索引 | 见 §3.3 | 两套规则，ZL/EI 客户端不同 |

### 3.2 `+1` 存储偏移教训（AGENTS.md 原文记录）

原版客户端 `MapControl.cs` 的地图帧索引存储带 **+1** 偏移。沙巴克移植时中层/前景 `-1/+1` 双重偏移出过"离线验证通过、实际游戏墙体缺口"的事故——因为验证工具复用了生产工具的同一错误约定。**规则：涉及 .map 帧索引的工具，先读 `Client/` 原版源码确认约定；校验用独立实现或对照真实游戏。**

### 3.3 小地图（minimap）索引规则（2026-08-15 实证）

- **2017 ZL 客户端**：`MiniMap.Zl` 库；帧号来自**客户端** `Debug/Client/Data/System.db` 的 `MapInfo.MiniMap` 字段（544 条，0=无图占位）。生成：`MIR3_ZIRCON_ROOT=… dotnet run --project Tools/SystemDbProbe -- <客户端Data目录> --minimap /tmp/minimap_map.txt`
- **⚠️ 不要用服务端 System.db 生成**：服务端索引与客户端库不配套（实证：244 条中 87 条指向空帧；公共条目 56/59 冲突）
- **EI 客户端**：`FMMap.wil`/`MMap.wil`；帧号来自 EI 服务器 `Envir/MiniMap.txt`：`value>=1001 → FMMap frame=value-1001`；`value<1001 → MMap frame=value-1`。生成：`python3 Tools/maps/gen_minimap_ei.py <Mud3>/Envir/MiniMap.txt <EI>/Map <EI>/Data > /tmp/minimap_map_ei.txt`
- mapviewer 按数据目录自动检测 ZL/EI 模式（`MiniMapSource._detect`）

### 3.4 /tmp 缓存三件套（脆弱点，E0 要消灭）

| 文件 | 生成器 | 丢失后果 |
|---|---|---|
| `/tmp/minimap_map.txt` | SystemDbProbe --minimap（客户端库） | 小地图全 404 |
| `/tmp/minimap_map_ei.txt` | gen_minimap_ei.py | EI 模式小地图缺 |
| `/tmp/map_cn_full.json` | workspace MapInfo.json + `Tools/maps/mapnames.py resolve` | 地图中文名全丢（"比奇城"变"0"） |
| `/tmp/wiki_thumbs` | mapviewer prewarm | 总览缩略图重建（慢，不致命） |

（E0 已固化：`bash scripts/gen_caches.sh` 或 `make cache` 一键重建，产物双写
`Tools/cache/`（入仓库，主）+ `/tmp/`（兜底镜像）；工具读取顺序
`MIR3_CACHE_DIR` > `Tools/cache/` > `/tmp`。重建后仍须重启进程——`@lru_cache`。）

### 3.4.1 82 机环境差异坑（E0 实证，2026-08-15）

- **NAS 路径**：82 机实际挂载在 **`/data/NAS`**（cifs）；旧机 `/home/tetsuya/NAS`
  是指向 `/tmp/nas_mnt/NAS` 的**悬空符号链接**。硬编码旧路径的工具在 82 上
  静默失败（mapviewer 甚至起不来）。已修：mapviewer 按
  `MIR3_NAS_TMP` env > `/data/NAS/TMP` > 旧路径 解析；脚本统一读
  `MIR3_EI_ROOT`/`MIR3_MUD3_ROOT`/`MIR3_ZIRCON_ROOT`（gen_caches.sh/services.sh 内置 82 默认值兜底）。
- **/tmp 是 7.9G tmpfs，常态接近满**：chrome 默认把 profile 写 /tmp，空间不足时
  渲染进程直接崩（puppeteer 报 "Session closed. Most likely the page has been closed"）。
  无头验收一律给 `userDataDir` 指到磁盘（如 `~/.cache/xxx-profile`）；大文件中转用
  /home 而不是 /tmp。
- **MirDB Session root 拼接**：`Session(SystemPath)` 是 `root + "System.db"` 字符串拼接，
  **root 无尾分隔符 → 打开 `…DataSystem.db`**，不存在时 0 表假成功（SystemDbProbe
  曾 0 条 minimap）。已在 SystemDbProbe 入口归一化尾分隔符；新工具照防。
- **mawk 不支持 `match($0, re, arr)` 三参**（gawk 扩展）：Debian 默认 awk 是 mawk，
  shell 脚本解析 `ss -tlnp` pid 用 `grep -o 'pid=[0-9]*'` 替代。

### 3.5 hub 服务管理教训

- hub daemon 的 cwd 参数对 `dotnet xxx.dll` 相对路径不可靠 → 用 `bash -c "cd <目录> && exec dotnet xxx.dll"` 包装
- daemon 名被 `pendingCompletion` 坏记录卡住时（start 报 unacknowledged），**换名启动**，别死磕
- 端口表见 §4.2

### 3.6 SystemDbProbe 的 csproj 引用约定

工具从 Zircon 抽到 Mir3-Research 后，csproj 用 `$(MIR3_ZIRCON_ROOT)` 环境变量解析 Zircon 源码引用（`Tools/SystemDbProbe/SystemDbProbe.csproj` 已改好，是模板；其它 `Tools/*.csproj` 断链时照此修）。**不要用根目录符号链接方案**——MSBuild 对物理路径/链接路径产生项目身份混乱，编译必炸。

（E0 已批量应用：11 个 `Tools/**.csproj` 于 2026-08-15 套此模板，构建全绿；硬编码
绝对路径形态一并统一为 env 解析。）

### 3.7 帧公式单一数据源的坑（E3 实证，2026-08-15）

- **FastAPI 中间件统一覆盖 Cache-Control**：路由 handler 里给 `FileResponse` 设的
  `no-cache` 头会被 `@app.middleware("http")` 末尾的无条件 `max-age=86400` **覆盖**。
  后果：`/frame-formulas.json` 被浏览器缓存 24h，重跑提取器后 webport「看不到变化」，
  drift 实验假阴性。规则：**凡中间件管响应头，路由内设同类头无效，条件全部写在中间件里**
  （webport serve.py 已把 `/frame-formulas.json` 加进 no-cache 白名单）。这与 §7 坑 3
  （异端缓存）同根：改数据不改 JS 时，第一怀疑响应头，第二才是进程。
- **ZL 库 header 无 shadow 元数据**：`zlsdk.header()` 只返回宽高+锚点；WIL 才有
  shadow/words。wilviewer export 的 manifest 硬取 `hdr["shadow"]` 对 ZL 库必
  KeyError（该路径此前只对 WIL 用过）——**WIL/ZL 双态工具所有 header 字段用 `.get()`**。
- **C# switch 源码解析**：连续 `case A: case B: <body>` 产生空段，分段要累积合并；
  嵌套 `switch(@class)` 的 `default:` 会干扰外层 case 分段，先摘出嵌套块再解析
  （frameformulas.py 的 `_split_cases`/`_balanced_block` 是现成实现）。
- **MirClass 本 fork 只有 4 职业**（Enum.cs 无 Archer）；webport `CLASS_ARCHER=4`
  是上游遗留别名，分派只特判刺客，无行为影响，但提取表时别指望枚举里有它。
- **webport 曾有第三份帧公式手抄**：`data.js` 的 PLAYER_ANIMS/armourShift 是残缺副本
  （armourShift 6 项 vs 全表 37 项）——消灭双份维护时必须 grep 全库找齐所有副本，
  只改 frames.js 会留暗漂移。现已全部收编（frames.js 读 JSON，data.js 投影 frames.js）。
- **565→888 换算两种流派**：zlsdk BC1 解码用等比 `(v*255)//31`，常见实现（含 GPU
  文档示例）用低位复制。写回工具最近邻索引重算若用低位复制，80 帧抽验只有 51 帧
  字节恒等；统一为解码同款等比公式后 100%。**编解码两侧色板数值必须逐位一致**。
- **zlsdk 的 `hdr.codec` 对 legacy ZL 库是假象**：`_parse_v1` 不解析 codec，值来自
  `ZlImageHeader` 构造默认 4 (Png)，而 decode legacy 分支按 `version` 选 BC1/BC3，
  根本不看 codec。统计库载荷格式要以 decode 实际路径为准，别信 header 字段。

### 3.8 写库窗口与多 goal 并发的坑（E5 实证，2026-08-15）

- **hub 管的服务会自愈复活**：`services.sh stop zircon-core` 只杀 pid，hub daemon 按 restart
  策略把它拉回来（`hub ps` 可见 `restarts` 计数）——sync.sh 的端口检测窗口正好撞上复活，
  白白 409 两次。**停 hub 管的服务必须用 `hub stop zircon-core`**（services.sh 停不住它；
  反过来 hub 停的 services.sh status 会正确显示停止）。
- **dbeditor `/api/rollback` 在 sync 成功后是空操作**：sync 成功即重置 baseline 为当前库，
  rollback 恢复的是「新 baseline」= 改动后状态，diff=0 → sync skipped。**回滚改动要显式
  PUT 旧值再 sync**，不要指望 rollback API。
- **dbeditor GET `/api/row` 返回注入字段**：`__zh`/`__frame` 等显示字段不在 schema，PUT
  回写前必须剔除（`k.startsWith('__')` 剔除），否则 400「字段不在 schema 中」。
- **多 goal 共享同一工作树的 git 互相踩**：并行会话在同一 checkout 直接 commit/merge，
  `git pull --rebase` 会把别人的提交排进自己的队列且在 dbeditor 自动提交（workspace 子树）
  上频繁冲突。经验：rebase 冲突即 `--abort` 改 merge；merge 前的未暂存变更（多数是别的
  会话活跃编辑）用整树 stash→merge→checkout stash 还原，**stash pop 不全时必须手动
  `git checkout stash@{0} -- <files>` 补齐**，否则丢别家未暂存编辑。
- **zircon git pull 后必须 dotnet build**（老坑新形态）：源码 fast-forward 到 8d1a6a3 后
  直接跑 `MapTestScene --light-render-audit`，跑的还是旧 dll——5 stage 只跑了 3。
  二进制行为与 git 状态脱钩，先 build 再验收。
- **llvmpipe 软渲染下探针阈值偏紧**：`--light-render-audit` 的 abyss 探针断言 0.5 在
  GPU 机器全 PASS，82 机 Xvfb+llvmpipe 读 0.369——同一份代码两种结果。无头验收结论
  要标注渲染器；断言阈值对软渲染偏紧不算产品 bug。

### 3.9 共享 mapviewer 代码与无头验收的坑（E1 实证，2026-08-15）

- **多会话热编辑同一文件互覆**：mapedit/api.py 在 E1 手里被重建 `_handle_edit` 三次——
  并发会话（E0）patch 同文件后保存，未提交的工作直接蒸发；事后 git log 显示"已提交"但
  实际缺函数。**规则：改共享热点文件后立刻 commit+push，验证以运行中进程为准，不信
  `git log`。**
- **共享 checkout 推送用 plumbing**：`GIT_INDEX_FILE=/tmp/xx + read-tree origin/master +
  update-index --cacheinfo + write-tree + commit-tree -p origin/master + push SHA:master`，
  完全不碰工作树与他人脏文件，避开 rebase 冲突（E5 §3.8 的根治版）。
- **/tmp 是 7.9G tmpfs 且多 goal 共享**：本轮被并行 goal 填到 100%，chromium 写不进
  profile 直接崩（Target closed）。**大文件/浏览器 profile 一律放 `~/.e1-scratch/`**
  （根盘 159G），别用 /tmp。
- **82 机 full chromium 起不来（GCM 后台网络挂死连 about:blank 都阻塞）**：用
  `chromium_headless_shell-1208/chrome-headless-shell` + `--remote-debugging-port` +
  puppeteer `connect()`（不要 `launch()`，launch 的 flag 组合会挂）。CLI
  `--dump-dom --timeout=20000` 可用但**千万别加 `--virtual-time-budget`**（挂起网络
  请求时虚拟时钟永不耗尽）。
- **headless 下 `alert()/confirm()` 阻塞整个页面的 CDP evaluate**：`?edit=1` 自启失败
  弹 alert → 渲染线程假死 180s 超时。**自动化可达路径上的用户交互只能 console.warn 或
  显式 dialog handler；自启/后台路径一律 quiet 模式。**
- **CDP `Input.dispatchMouseEvent`（puppeteer mouse.click）在本机 headless_shell 会
  卡死**：渲染进程 CPU≈0（非忙循环），是输入通道 wedge。**用 `evaluate()` 派发合成
  MouseEvent + `element.click()` 代替真实鼠标事件。**
- **HTML 里 span 容器与内部 select 撞 id**：`querySelector('#x').value` 取到 span 的
  undefined → Number()=NaN → JSON null → 后端 `int(None)` 500。容器 id 加 `-hold`
  后缀，控件独占语义 id。
- **回归基线要选"拆分前最后一个好提交"的干净树**（worktree 检出 879a05d 到
  `~/.e1-scratch/basewt`），不要用共享工作树跑基线——基线采集 11 分钟窗口内 E0 又
  改了 mapviewer（082baa1），对照就废了。
- **43 张发行图是截断文件**（尾部记录缺失）+ **+12 偏移是 Light`(b&0x0F)*2`**
  （§5.2 格式表已并入）。serialize 用模板补丁策略（template=原文件逐字节保留未建模
  字节）才让 A/C 检查全绿；重建式序列化对截断图必然字节级不等。

### 3.10 技能特效事实源与截图回归的坑（E4 实证，2026-08-16）

- **原版有两个 Spell 特效 switch**：release 段 `MapObject.cs:768`（`if (!MagicCast)
  break`）+ start 段 `:3603`（SetAction 内，无条件播）。只提一个会系统性漏 start 段
  起手特效（Godot 的 `Source`/`CastAtSource` 字段对应它）。union=138 技能有特效。
- **网页截图回归的指纹别用截图字节**：CDP `Page.captureScreenshot` 的 webp 编码在
  同一画面上有 ± 噪声（连拍同画面 hash 会漂）。**指纹用页面内
  `getImageData` 像素 hash**，截图只给人看画廊。
- **canvas 确定性 = 时间定点化 + 帧就绪探针 + 失败不缓存三件套**：`dt` 浮点累加会让
  特效帧号骑在 `idx` 边界 ±ε 抖动（取整 `Math.round(dt*1000)`）；`play()` 把 labT
  对齐固定相位（500ms）；异步 sprite 解码要 `framesReady()` 逐项轮询（特效/纸娃娃/
  木桩），且 **null/失败结果禁止进缓存**（否则一次 404 毒化整轮截图，且毒帧跨会话
  复现成"永远 changed"）。仍剩 ~1/30 冷启动闪失 → diff 不一致**当场复拍一次**自愈。
- **`ready` 判真后画布未必已画上**：解码刚完成当帧 rAF 还没跑。hash 采样前等 ≥2 帧
  （sleep 250ms）。
- **headless chrome 硬杀（kill -9）会损坏持久 user-data-dir**：下轮
  `SingletonLock` 残留 → 启动即 `FATAL: lab not ready`。一次性 profile
  (`/home/.../chrome-$$`) + 退出 `rmSync`。
- **裸 GameScene 反射驱动的运行时审计抓不到弹道 Arrival 段**：
  `_mapView==null` → `ComputeEffectScreenPos` 恒 Zero → 弹道 `duration==0` 同帧
  Complete，命中特效节点生命周期极短。Arrival 段断言走**表定义**三元组，运行时
  断言只覆盖非弹道承载段（MapTestScene `--magic-spot-audit` 的双层口径）。
- **`DirectionStartIndices` 只有 `ImpactDef` 有**：`CastEffect` 上同名属性不存在
  （CS0117）。需要方向帧表的主特效放进 `Source`（Source 非空时主特效自动跳过地面
  播放，见 LightningBeam 先例）。
- **`MirEffectNode` 不记录图库枚举**：审计要比 `(lib,start,count)` 三元组先补
  `public LibraryFile File`（Setup/SetupTarget 各赋值一次）。
- **`OriginalSpellCases` 白名单口径 = "原版 switch 有 case 且创建了特效"**：纯音效
  case（CombatKick/JudgementOfHeaven，只 `Play` 无 `MirEffect`）归
  `NoVisualSpellCases`，混进白名单会把覆盖率审计搞成假阳性。
---

## 4. 环境引导（82 机器，一次性）

### 4.1 前置检查

```bash
# 仓库就位（假定同布局；不同则全文搜索替换路径）
ls ~/development/Zircon/GodotClient/project.godot   # Zircon 本体
ls ~/development/Mir3-Research/Tools/maps/mapviewer.py
git -C ~/development/Mir3-Research log --oneline -1   # 应 ≥ 62f6499
# 环境变量（所有 shell / hub 启动都要带）
export MIR3_EI_ROOT=<EI传奇3.0客户端目录>
export MIR3_MUD3_ROOT=<Mud3 目录>
export MIR3_ZIRCON_ROOT=/home/<user>/development/Zircon
# NAS 资源（EI 客户端/Mud3 若在 82 上是别的路径，改 env 即可）
python3 -c "import sys; sys.path.insert(0,'Tools/maps'); import mapviewer"  # 依赖自检
```

### 4.2 服务端口表（需要哪个起哪个；hub 名称即下表）

| 端口 | hub 名 | 启动 | 用途 |
|---|---|---|---|
| 7000 | zircon-core | `bash -c "cd <Zircon>/Debug/ServerCore && exec dotnet ServerCore.dll"` | 游戏服务器（DB 加载 ~11s 才回 GoodVersion） |
| 7001 | wsgateway | `<venv>/python wsgateway.py`（cwd=Tools/wsgateway） | WS→TCP 透传网关 |
| 8823 | webport | `<venv>/python Tools/webport/serve.py` | 网页客户端（资源服务） |
| 8899 | mapviewer | `python3 Tools/maps/mapviewer.py --port 8899` | 地图查看/编辑器宿主 |
| 8810 | dbeditor | 见 Tools/dbeditor/run.sh | System.db 编辑器（写回管线） |
| 8800 | dbviewer | Tools/dbviewer/dbviewer.py | System.db 只读查看 |
| 8765 | wilviewer | Tools/wilviewer/ | WIL/ZL 资源查看 |
| 8822 | webclient | Tools/webclient/serve.py | 静态世界测试台（不连服） |

测试号：`test@test.com / test123 / TestHero`（GM，Admin=True）。webport 一键直进：`http://127.0.0.1:8823/?demo=1`。**共享账号并发登录会 `[Account in Use]`，多 goal 同时验收各自注册独立账号。**

### 4.3 缓存生成（E0 已做成一键）

见 §3.4 三条命令。生成后重启对应服务。

E0 落地后：`make cache`（= `scripts/gen_caches.sh`，产物入 `Tools/cache/` + `/tmp` 镜像），
服务起停用 `scripts/services.sh <start|stop|restart|status|log> [name…]` 或 Makefile
的 `serve-mapviewer` 等短路目标。services.sh 为 nohup+pidfile 自治实现（hub socket
对 shell 不公开，omp 会话内仍可用 hub 工具，两套按端口互认互不冲突）。

### 4.4 无头 Godot 对照配方（验收 UI/渲染用）

Xvfb `<display>` + `~/godot/Godot_v4.6.3-stable_mono_linux_arm64`（或 `godot-mono` in PATH）+ 截图工具（imagemagick `import` 可用）；ZIRCON_UI_SCALE=2 测 4K 缩放。参考 AGENTS.md「无头验证配方」。

---

## 5. Goal E1 — 地图编辑器（mapviewer 进化，最高优先级）

**一句话**：把 mapviewer 从"只读查看器"进化成"能改格、能写回、能验证"的地图编辑器。

**领地**：`Tools/maps/mapviewer.py`（如拆模块则 `Tools/maps/mapedit/` 新目录）、`Tools/maps/*.py` 新工具。

### 5.1 现状（已具备）

- `parse_map()`（mapviewer.py:376）：.map → `Cells[Width][Height]` 矩阵，`MapCache` LRU 缓存
- 完整渲染管线：三图层（back/mid/front）+ 缩放梯子 + 瓦片缓存 + fullmap 预生成
- overlay 体系（NPC/传送点/任务/热力/网格/拾取）已修为内容坐标（62f6499）
- 627 地图浏览、中文名、连通图谱、NPC 面板

### 5.2 .map 二进制格式（parse_map 实证，写回按此序列化）

```
Header (28B): …; u16 LE width @22; u16 LE height @24
Segment 1 — Back(地面) 半分辨率表: for x in w//2, for y in h//2:
    [u8 back_file][u16 LE back_img]  (3B/entry) → 写入 cells[x*2][y*2]
Segment 2 — 全分辨率格 (14B/格, 行优先按列: 第 i 格 → x=i//h, y=i%h):
    +0 u8 flag       (通行/阻挡标志)
    +1 u8 midAnim    (anim_a, 0xFF=无)
    +2 u8 frontAnim  (anim_b, 0xFF=无)
    +3 u8 frontFile  (255=无中层)
    +4 u8 midFile
    +5 u16 LE midImg
    +7 u16 LE frontImg
    +9..14 未用/填充
```

**⚠️ 写回前必做**：读原版 `Client/` 的 MapControl.cs 确认帧索引是否带 +1 存储（§3.2 教训）；确认填充 9..14 字节原样保留。

> **E1 完成状态（2026-08-15）**：mapviewer.py 已拆为 `Tools/maps/mapedit/` 包（12 模块，
> 垫片保持 `import mapviewer` 兼容）；`serialize_map` 模板补丁策略（未编辑字节零变化，
> 含 Light@+12 与截断布局）；`map_roundtrip.py` 独立验证 20/20（报告
> `docs/maps/edit-proof/roundtrip-report.json`）；编辑会话/保存管线/编辑 UI 全链路实测
> 通过（存证 edit-ui-cell.png / edit-ui-saved.png）。**E2 请直接在 mapedit 包上开发**
> （api.py 加端点、templates.py EDIT_UI_JS 加面板、editstate.py 加会话类型）。

### 5.3 任务分解

1. **序列化器 `serialize_map(w, h, cells) -> bytes`**：与 parse_map 严格互逆
2. **往返验证（独立实现！）**：`parse(serialize(parse(f)))` 与 `parse(f)` 语义相等 + 对原文件 `serialize(parse(f))` 字节级相等（允许填充字节差异则需论证）；抽 20 张图含动画格/边界尺寸
3. **编辑模式 UI**：
   - 进入编辑模式（URL `&edit=1` 或按钮）→ 格选中（点击）→ 侧栏显示该格六字段
   - 改层：back/mid/front 的 file+img 选择器（从图库清单选帧，实时预览渲染）
   - flag 切换（通行/阻挡），网格+flag 着色显示
   - 笔刷：区域涂抹（矩形/同值替换）
   - 撤销/重做（操作栈）
4. **保存管线**：改格 → serialize → 写**副本**（`<name>.map.new`）→ 独立 parse 验证 → 用户确认 → 备份原文件（`.bak-<date>`）→ 原子替换 → 刷新缓存。**写 Debug/Client/Map 前确认没有客户端/服务进程占用读该文件（读共享不冲突，只需备份纪律）**
5. **游戏内验证**：改一张图的明显格（如比奇城门口地面换帧）→ `@move 0` 实地查看（Godot 或 webport 均可）→ 截图存证 `docs/maps/edit-proof/`
6. **（可选后置）**帧浏览器模式：悬停格显示三图层各自贴图缩略图（复用 FramePool）

### 5.4 验收标准

- [ ] 往返验证脚本通过（20 张图字节级/语义级，脚本入库 `Tools/maps/map_roundtrip.py`）
- [ ] 编辑→保存→重读→显示一致
- [ ] 游戏内（webport 或 Godot）看到修改后的地图
- [ ] 原文件始终有备份，任何失败路径不损坏原文件
- [ ] 撤销/重做可用；编辑中途切图有未保存提醒

---

## 6. Goal E2 — NPC/Region 摆放编辑（dbeditor 管线复用）

**一句话**：在 mapviewer 上拖拽摆放/移动 NPC（及守卫、安全区、矿山 Region），经 dbeditor 既有管线安全写回 System.db。

**领地**：`Tools/maps/mapviewer.py` 的 NPC 编辑部分（与 E1 同文件！见 §9.2 冲突协议——E2 等 E1 拆模块后再动手，或先在独立分支）、`Tools/NpcMover/`（已有坐标修正工具，扩展它）。

### 6.1 现状（已具备）

- 读链路：`load_workspace_entities()`（mapviewer.py:4745 附近）= NPCInfo × MapRegion → PointRegion 质心（CenterX/CenterY，**EI 坐标系，NpcMover 修正后的值**）
- NPC 显示 + 列表面板 + 点击跳转（62f6499）
- **写链路完整**：dbeditor workspace（`Tools/dbeditor/workspace/*.json` 全表）→ `/api/sync` → `sync.sh` → C# DBImporter → 校验 → 备份双库 → 原子安装 → round-trip 报告（`sync_report.txt`）
- 写库纪律全套已在 sync.sh 固化（绝不直写 .db）

### 6.2 任务分解

1. **NpcMover 扩展**（优先，避免与 E1 同文件冲突）：命令行批量移动/新增/删除 NPC —— 读 workspace → 改 MapRegion.PointRegion（CenterX/CenterY）或新建 NPCInfo+Region → 写回 workspace JSON → 提示走 sync
2. **mapviewer 编辑 UI**（E1 拆模块后）：
   - 编辑模式下 NPC 标记可拖拽（格吸附）→ 松手写 workspace
   - 新建 NPC：输入 NPCName/Image/EntryPage → 生成 NPCInfo 行 + 绑定 Region
   - Region 面板：选中 Region 显示 Size（格数）可调
   - 变更列表：待 sync 的 diff 预览（当前 workspace vs baseline.json）
3. **sync 触发**：编辑完提示用户执行 sync（或提供按钮 POST dbeditor /api/sync——**服务端 zircon-core 必须先停**，sync.sh 已做端口检测）
4. **游戏内验证**：移动一个 NPC → sync → 起服 → webport/Godot 进图看 NPC 站位（服务器 NPCInfo 即权威，见 mapviewer NPC 层约定）

### 6.3 验收标准

- [ ] 拖拽移动 NPC → sync → 重启服务器 → 游戏内 NPC 位置与编辑一致（截图存证）
- [ ] 新建 NPC 全流程（含 EntryPage 绑定）可用
- [ ] baseline diff 正确；sync 失败时 workspace 可回滚
- [ ] 全程未直写 .db（sync_report.txt 为证）

---

## 7. Goal E3 — 资源编辑器（wilviewer 进化，最低优先级）

**一句话**：把 wilviewer(:8765) 从"查看"进化到"帧级检索 + 导出 + 帧公式对照"。

**领地**：`Tools/wilviewer/`、新文件 `Tools/resedit/`。

### 7.1 任务分解

1. 帧公式对照面板：选 WIL/ZL 帧 → 显示 webport `frames.js` 对应的纸娃娃/动作公式结论（换装分层、attack/magic 帧数表）——把 `frames.js` 的表反向导出成 JSON 供两侧共读（**顺手消灭一处双份维护**）
2. 批量导出：选中帧范围 → PNG/WebP 序列（复用 webres 管线）
3. 调色板/透明色检查（NoColourKey 机制对照）
4. （可选）帧替换写回 ZL——**高风险后置**，需先做 ZL 库往返验证，与 .map 同等纪律

### 7.2 验收标准

- [x] 帧公式 JSON 导出 + webport frames.js 改为读它（一处改两边变，验证 drift 消灭）
  —— E3 完成 2026-08-15：`Tools/resedit/frameformulas.py` 提取 94 表 560 项；
  webport frames.js/data.js 全部改读 JSON；drift 实验（JSON 6→8 → 页面双读 8）+
  真服全链路 + test-anims 71/71。wilviewer 帧公式对照面板 + WebP/PNG 批量导出同交付。
  详见 `Tools/resedit/README.md` 与 `docs/resedit/proof/`
- [x] 批量导出可用 —— `/api/export?kind=webp`（无损 WebP ZIP，较 PNG 小 45%）+
  选中条 WebP 按钮 + 面板「⤓ 区间」一键导出动全面帧

- [x] 调色板/透明色检查（任务 3）—— wilviewer 详情弹窗「透明键对照 Godot ZlReader 移植」
  四格面板（无键/特效键 32/天气键 96/雾键 192，连通 BFS + 逐像素键全移植），与 C#
  `ZlReader.BuildRgbaData` 原文独立编译比对**四模式字节级一致**；`/api/keystats` 给
  决策提示（暗色主体被误删 → 建议 NoColourKey=true）
- [x] （任务 4）ZL 帧写回 legacy DXT1 —— `Tools/resedit/zlwrite.py` 块级手术
  （未改块字节不动 → 零容器重排），4 库抽验 decode→重编码 100% 字节恒等，
  备份链 + 独立验证 + 原子替换 + 误差报告；ZL2（PNG 载荷）不做，论证见
  `Tools/resedit/README.md`「ZL 帧写回」节

## 8. Goal E0 — 基础设施（最先跑，半天量级）

**一句话**：消灭 /tmp 脆弱性 + 服务一键化，给其它三个 goal 铺路。

**领地**：新 `scripts/gen_caches.sh`、新 `scripts/services.sh`、`Makefile`、`docs/`。

### 8.1 任务分解

1. `scripts/gen_caches.sh`：§3.4 三件套 + wiki_thumbs 一次性重建；产物优先落仓库内 `Tools/cache/`（改 mapviewer/dbviewer 的路径常量 + `.gitignore`），退而求其次 `/tmp` 但脚本可重跑
2. `scripts/services.sh <start|stop|status|restart> [name…]`：统一封装 §4.2 端口表（hub 优先，无 hub 环境退化 nohup + pidfile）；内嵌 §3.5 教训（bash -c cd 包装、坏记录换名）
3. `Makefile`：`make cache` / `make serve-mapviewer` / `make roundtrip`（E1 的验证入口）等短路目标
4. csproj 修复模板化：把 §3.6 的 `$(MIR3_ZIRCON_ROOT)` 方案批量应用到其余断链 `Tools/*.csproj`（AccountProbe/CharacterEditor/MapFlagsProbe/ServerProbe/DBImporter 等，用到哪个修哪个）
5. 本文档同步：新坑写进 §3

### 8.2 验收标准

- [ ] `rm -rf /tmp/minimap* /tmp/map_cn*` 后 `make cache` + 重启服务，小地图/中文名全恢复
- [ ] `services.sh status` 正确报告全部服务
- [ ] 至少一个此前断链的 csproj 修复并实跑成功

---

## 9. 执行与协作约定

### 9.1 goal 注册（goal_watchdog.sh）

GOALS 数组每行：`<session-id>|<session.jsonl 绝对路径>|<tmux 会话名>|<workdir>|<中文标签>`。

建议四路：

```
E0 编辑器基础设施 | tmux: ed-infra   | workdir: ~/development/Mir3-Research
E1 地图编辑器     | tmux: ed-map     | workdir: ~/development/Mir3-Research
E2 NPC摆放编辑    | tmux: ed-npc     | workdir: ~/development/Mir3-Research   ← 等 E1 拆模块后启动
E3 资源编辑器     | tmux: ed-res     | workdir: ~/development/Mir3-Research
```

启动顺序：E0 先行 → E1/E3 并行 → E2 收尾阶段插入。

### 9.2 文件领地与冲突协议（沿用五路并行先例）

- 领地内随便写；领地外只读
- 共享文件（mapviewer.py / workspace JSON / 本文档）小改（加函数/加 case）直接改，commit 标 `[shared]`；大改先在 tmux 里吼一声（goal 会话间用 hub send 互通）
- **mapviewer.py 是 E1/E2 唯一交汇点**：E1 的第一任务就是把 5100 行拆成包（parse/render/api/ui/edit 模块化，行为不变，拆完跑全量截图回归对照），E2 在拆完的模块上做编辑 UI
- 每 30 分钟 commit+push（小步快跑），冲突以 Godot 源码行为仲裁

### 9.3 每个 goal 的完成定义

1. 验收清单全绿 + 证据（截图/报告/日志）落 `docs/**/`
2. 踩到的新坑回写本文档 §3（这是文档活着的方式）
3. 最终 commit 信息中文、推送 fork、goal 标记 complete（watchdog 自动回收）

### 9.4 环境 82 特别注意

- 路径若与本文不同（用户名/NAS 挂载点），以 env 变量替换，不要硬编码搜索替换路径常量
- 独立账号注册验收（test@test.com 会争用）
- ServerCore 启动 ~11s 才就绪，任何连服验收轮询 ≥60s
