# Zircon System.db 在线编辑器（dbeditor）— 完整任务目标

## 一、任务背景

你是 Zircon 私服项目的开发智能体。游戏世界数据库 `System.db`（.NET BinaryFormatter 序列化，非 SQL）目前只能用 dbviewer（只读 Web 查看器）浏览、用 /tmp/dumpdb 临时工程手写 C# 改数据——编辑体验差、无版本管理、无校验。

你的任务：**实现一个 FastAPI + Vue 的 Web 在线编辑器（dbeditor），带 JSON 缓冲区工作流**——编辑保存只落 JSON 工作区（git 留痕、攒改动、可回滚），用户显式点「同步到数据库」才经 C# importer 校验写回 System.db（服务端+客户端双库），最终游戏内实测验收。

这是大型自主任务：写代码、构建、起服务、无头浏览器实测、游戏内验证、写文档，全部自己完成，不要做一半就停。

## 二、先读这些文件（权威参考）

1. **dbviewer（只读查看器，你的架构基础和代码起点）**
   - `/home/tetsuya/development/Mir3-Research/Tools/dbviewer/dbviewer.py` + `template.html` + `export.sh` + `README.md`
   - 纯标准库 http.server + 单文件前端；JSON 数据在 `/tmp/dbviewer_data/`（SystemDbProbe --json 导出的 77 表）
   - dbeditor **复用它的数据层思路**（全量载入+倒排索引+关联跳转），但后端换 FastAPI、前端换 Vue（CDN 引入亦可，避免本机 npm 全家桶——机器 4核15GB，若 npm 可用则用 Vite 脚手架，不可用则 Vue3 CDN 模式，自行判断并在文档说明选择）
2. **SystemDbProbe（C# 导出器，--json 模式已有）**
   - `/home/tetsuya/development/Mir3-Research/Tools/SystemDbProbe/Program.cs`
   - `--json <outdir>` 已能导出全部集合为扁平 JSON
3. **写库代码模式（importer 的参考）**
   - `/tmp/dumpdb/Program.cs`：`new Session(SessionMode.Both, root)` + `session.Initialize(两个程序集)` + `GetCollection<T>().Binding` 改属性 + `session.Save(true)`——翻译任务已验证此写法可无损写回
   - `/tmp/rttest/Program.cs`：round-trip 测试工程（注意：Session root 尾斜杠 + `SystemPath => Root + "System" + Extension`，副本目录测试用）
   - ⚠️ MirDB 写回是**全量重写**，不存在增量；写前必须备份
4. **数据库结构**
   - `/tmp/dbviewer_data/meta.json`（77 表中文名+字段类型+引用关系 meta）
   - `/home/tetsuya/development/Mir3-Research/docs/database/_summary.md`
5. **库文件位置（写回目标）**
   - 服务端：`/home/tetsuya/development/zircon/Debug/ServerCore/Database/System.db`
   - 客户端副本：`/home/tetsuya/development/zircon/Debug/Client/Data/System.db`（**必须双写**，否则 ToolTip/对话与逻辑分叉）
   - 备份目录：`Database/Backup/`（写前自动带时间戳备份到这）

## 三、核心工作流（产品定义）

```
浏览器编辑（表单/表格）
   ↓ 保存 = 只写 JSON 工作区 + git commit（自动）
JSON 工作区（/home/tetsuya/development/Mir3-Research/Tools/dbeditor/workspace/*.json）
   ↓ 用户显式点「同步到数据库」
importer（C#，校验 → 备份 → 双库写入）
   ↓ 提示重启服务端
重启 → 游戏内验证
```

**关键行为**：
- 编辑器任何"保存"都**绝不直接碰 .db 文件**
- 「同步到数据库」按钮：先展示待同步 diff 汇总（几条新增/修改/删除、影响哪些表）→ 用户确认 → 执行
- 同步时若检测到 7000 端口有监听（服务端在跑）→ **拒绝执行**，提示先停服务端
- 同步前引用完整性校验（见 §5）
- 每次同步自动备份双库到 Backup/（时间戳命名），并 bump `SystemDatabaseInfo.Version`（沿用 MirDB 现有版本机制）

## 四、管理范围（P0 四类，子表嵌进父表）

| 分类 | 主表 | 子表（嵌套编辑） | 数据量 |
|---|---|---|---|
| 物品 | ItemInfo(1078) | ItemInfoStat(3196)、SetInfo/SetInfoStat(套装)、StoreInfo(92 商店上架) | ~4600 行 |
| 怪物 | MonsterInfo(434) | MonsterInfoStat(4117)、RespawnInfo(2475 刷怪点)、GuardInfo(94) | ~7100 行 |
| 技能 | MagicInfo(174) | — | 174 行 |
| 掉落 | DropInfo(10382) | — （但 UI 按"怪物"组织，见下） | 10382 行 |

30 张空表（Castle/Instance/Fishing/Help/活动系）不显示。MapInfo/NPC/Quest 等其余表第二期，本期不做编辑页但 JSON 工作区结构要**预留**（schema 可扩展）。

## 五、功能需求

### 5.1 编辑核心
- **列表页**：每类一张表，分页/搜索（中文名+英文名+Index）/排序，列显示中文名（数据源 `/tmp/dbviewer_data/` 的翻译对照或 `GodotClient/translations/db_names.json`）
- **详情编辑页**（核心）：基本信息表单（全字段，字段旁中文说明，来自 meta.json）+ 子表行内编辑（物品属性行/怪物成长行/刷怪点行，可增删改）+ 引用字段用**下拉选择器**（如 RespawnInfo.Monster 选怪物、StoreInfo.Item 选物品，选项显示中文名+Index，搜索过滤）
- **新增/复制/删除记录**（新增物品、复制一只怪改数值——复制是高频策划操作）
- **图标预览**：ItemInfo.Image / MonsterInfo.Image 字段旁显示对应贴图帧（图标源：`/home/tetsuya/development/zircon/GodotClient/` 项目可访问的 `Debug/Client/Data/*.Zl`；预提取的 PNG 在 `~/development/Mir3-Research/docs/quest-design/data/assets/item-icons/`——后端直接静态伺服这些 PNG，前端按 Image 值引用）
- **掉落双向视图**：怪物详情页内嵌"掉落列表"（该怪全部 DropInfo 行：物品名+图标+概率+幸运约束，行内增删改）；物品详情页内嵌"被谁掉落"反向列表（只读）
- **批量操作**：多选行 → 批量改字段（如选中 20 个物品 Price +10%）；预览影响后执行
- **数值范围校验**：meta.json 里的类型约束（int 范围、enum 合法值）前端即时提示，保存时后端再验

### 5.2 JSON 缓冲区（产品灵魂）
- 工作区目录：`Tools/dbeditor/workspace/`，结构按表一个 JSON 文件（ItemInfo.json 等），git 管理
- **首次启动**：若工作区为空 → 调 SystemDbProbe --json 全量导出作为基线 → 记录基线库版本（SystemDatabaseInfo.Version）+ 双库 md5
- **保存**：写 JSON + `git add workspace && git commit -m "dbeditor: 改动描述"`（自动，描述从表单变更摘要生成）
- **改动追踪页**：列出工作区相对基线的全部改动（表/记录/字段/旧值/新值），支持**按记录回滚**（单条恢复基线值）
- **同步前 diff 汇总**：新增 N / 修改 M / 删除 K，按表分组列出，确认后才执行
- 冲突策略（用户已拍板）：**不管**。但同步时打印当前库版本号供人工过目即可

### 5.3 importer（C# 写回器）
- 新工程 `/home/tetsuya/development/Mir3-Research/Tools/DBImporter/`（参考 /tmp/dumpdb 的 Session 模式）
- 输入：workspace JSON → 反序列化为 MirDB 对象 → 与库中现值 diff → 只应用差异 → `session.Save(true)`
- **双库写入**：服务端库写完后，把同一份新库复制到客户端 Data/System.db（先备份客户端旧库）
- **引用完整性校验**（同步前跑，任何一条失败则整体拒绝）：
  - DropInfo.Item / StoreInfo.Item / QuestReward 等引用的 ItemIndex 必须存在于 ItemInfo
  - RespawnInfo.Monster / DropInfo.Monster 必须存在于 MonsterInfo
  - ItemInfo.Image ∈ Inventory.Zl 帧范围（0..2364，meta 可配）
  - MonsterInfo.Image ∈ MonImg.Zl 帧范围
  - enum 字段值合法（Rarity/ItemType 等）
  - 数值字段无负值越界（Price≥0、Chance 0..1 等）
- 校验报告输出到 workspace/sync_report.txt
- **进程检测**：importer 启动时检查 7000 端口，有监听直接退出码 2 + 提示

### 5.4 同步后验证（自动化）
- 同步完成后自动跑 round-trip 校验：重新打开库 → 验证每条改动已生效（读回对比）→ 打印结果
- **游戏内验收**（最终验收标准，必须真做）：
  1. 挑一个商店物品（StoreInfo 里有 NPC 关联的）改 Price
  2. 同步 → 重启服务端（`cd /home/tetsuya/development/zircon && hub` 管理的 zircon-server，或直接 `Debug/ServerCore/dotnet ServerCore.dll`；同步前必须已停）
  3. 无头客户端验证：`Xvfb :101 + openbox`（**必须 openbox 当 WM**，裸 Xvfb 视口不生效）+ godot-mono 登录 test@test.com/test123/TestHero 进游戏找该 NPC 打开商店
  4. 截图为证（scrot），确认商店里价格已变
  5. 全流程文档化（命令+截图路径）
  - 无头游戏操作参考：`/home/tetsuya/.hermes/skills/gamedev/mir3-project/SKILL.md` 的"GodotClient 无头验证"节（xdotool 键鼠、截图、GM 命令 @move/@make 可用）

### 5.5 技术栈与部署
- 后端：FastAPI（Python venv，`Tools/dbeditor/venv/`，requirements.txt 固定版本）
- 前端：Vue3（CDN 单文件模式或 Vite——**先探测本机 npm/npx 可用性再定**，文档说明理由）；UI 组件可引 Element Plus CDN 减少手写量
- 端口 8810（mapviewer 8899 / dbviewer 8800 已占用）
- 启动脚本 `Tools/dbeditor/run.sh`（venv 激活 + uvicorn）；README 写清启动/同步/备份/回滚操作手册
- importer 构建脚本 `Tools/dbeditor/sync.sh`（调 DBImporter + 前后校验串联）

## 六、验收标准（全部满足才算完成）

1. ✅ FastAPI 后端 + Vue 前端启动无错，浏览器可访问 :8810
2. ✅ 四类数据（物品/怪物/技能/掉落）列表+详情+编辑+新增+复制+删除全通
3. ✅ 保存只落 JSON 工作区 + git 自动 commit，.db 文件 mtime 不变
4. ✅ 改动追踪页正确显示 diff，按记录回滚可用
5. ✅ 同步按钮：diff 汇总 → 确认 → 校验 → 备份 → 双库写入 → round-trip 读回验证通过
6. ✅ 服务端在跑时同步被拒绝（端口检测生效）
7. ✅ 引用校验：故意造一条悬空 DropInfo → 同步被拒且报告指出该行
8. ✅ **游戏内实测**：改商店价格 → 同步 → 重启服务端 → 无头客户端进商店截图确认新价格
9. ✅ README + 操作手册完整（启动/编辑/同步/回滚/故障排查）
10. ✅ 全部代码提交到 Mir3-Research 仓库（中文 commit）

## 七、边界与约束

- **绝不写 Users.db**（玩家数据，编辑器只管 System.db）
- **绝不绕过缓冲区直写 .db**（测试用的临时库副本除外，如 /tmp/rt_db/）
- 服务器可能在跑：读库永远走副本或只读；写库只在用户显式同步且服务端已停时
- 机器 4核15GB：构建用 `dotnet build -m:2` 限并发；uvicorn 单进程够用
- 系统 Python 3.11 无 pip → venv 用 `python3.13 -m venv` 或 uv（本机 uv 已装）
- 完成后不清理 venv/workspace（用户要长期用）

## 八、交付物清单

1. `Tools/dbeditor/`：FastAPI 后端 + Vue 前端 + run.sh + README.md
2. `Tools/DBImporter/`：C# importer 工程 + 构建产物
3. `Tools/dbeditor/workspace/`：JSON 工作区（含基线导出）
4. 操作手册（README 内）：工作流图、同步流程、回滚方法、验收记录
5. 游戏内验收截图（存 `docs/` 或 screenshots/，路径写进 README）
6. Mir3-Research 仓库提交记录（中文 commit 信息）

## 九、建议实施顺序（自主调整也行）

1. 读参考文件 + 探测 npm 可用性 → 定前端方案
2. FastAPI 骨架 + 工作区基线导出 + git 自动 commit
3. 四类表的列表页 + 详情编辑页（先物品打通全链路）
4. importer + 校验 + 双库写入 + round-trip
5. 同步按钮全流程 + 端口检测
6. 无头游戏内验收
7. README + 提交
