# dbeditor — Zircon System.db 在线编辑器

FastAPI + Vue3 的 System.db 在线编辑器，核心是 **JSON 缓冲区工作流**：

```
浏览器编辑（表单/表格/子表/批量）
   ↓ 「保存」= 只写 JSON 工作区 + 自动 git commit（绝不碰 .db）
Tools/dbeditor/workspace/*.json（git 留痕、攒改动、可按记录回滚）
   ↓ 用户显式点「同步到数据库」（服务端必须在停止状态）
importer 校验（引用完整性/枚举/范围）→ 备份双库 → 写服务端库 + 客户端库
   → round-trip 读回验证 → 提示重启服务端
重启服务端 → 游戏内实测
```

## 组件

| 组件 | 位置 | 说明 |
|---|---|---|
| 后端 | `Tools/dbeditor/app.py` | FastAPI（venv，端口 8810）。工作区 CRUD、校验、diff/回滚、批量、git 自动提交、同步入口 |
| 前端 | `Tools/dbeditor/static/` | Vue3 + Element Plus（本地 vendor，无构建步骤）。列表/详情/子表行内编辑/图标预览/改动追踪/同步向导 |
| 工作区 | `Tools/dbeditor/workspace/` | 每表一个 JSON（SystemDbProbe 导出格式），`_baseline/` 基线快照，git 管理 |
| importer | `Tools/DBImporter/` | C# 写回器（详见其 README）：校验 → 备份 → 双库写入 → round-trip |
| 同步脚本 | `Tools/dbeditor/sync.sh` | 端口检测 → DBImporter（写临时副本）→ probe 重导出语义对比 → 备份 → 原子安装双库 → 重置基线 |

## 技术选型

- **前端 Vue3 CDN 单文件模式**（本地 vendor 目录）：本机虽有 npm，但避免 node_modules/Vite
  构建链——工具类项目优先零构建、可直接 `python app.py` 跑起来。Element Plus 全量本地化。
- **后端 uv venv + Python 3.13**（系统 3.11 无 pip）。`requirements.txt` 固定版本。
- **端口 8810**（mapviewer 8899 / dbviewer 8800 已占用）。

## 启动 / 停止

```bash
cd Tools/dbeditor && ./run.sh          # http://127.0.0.1:8810/
```

首次启动若工作区为空会自动做基线导出（调 SystemDbProbe --json，需 dotnet）。
单实例守卫：`workspace.lock` 被占用时拒绝启动。

## 日常操作手册

### 编辑（只落 JSON，安全）
- 左侧选分类（物品/怪物/技能/掉落/商店上架…）→ 列表页搜索（中文名/英文名/Index）、排序、分页
- 点行进详情：全字段表单（字段旁中文说明来自 meta.json）+ 子表行内增删改
  （物品→属性加成/掉落来源；怪物→成长行/刷怪点/掉落列表；掉落双向：怪物页嵌掉落、物品页嵌被谁掉落）
- 引用字段是下拉选择器（中文名+Index，可搜索）；ItemInfo.Image 旁有图标预览（`/icons/<n>.png`）
- 新增 / 复制 / 删除：删除会先级联删本记录拥有的子表行，再查悬空引用，有则拒绝
- 批量：列表多选 → 批量改字段（先 dry-run 预览）
- 每次保存自动 `git commit`（提交信息含表/记录/变更摘要），.db 文件 mtime 不变

### 改动追踪 / 回滚
- 「改动」页列出工作区 vs 基线的全部差异（表/记录/字段/旧值→新值，新增/删除/修改分组）
- 每条记录可单独「回滚至基线」

### 同步到数据库（显式操作）
1. **先停服务端**（同步前端口 7000 有监听会被拒绝，双端校验：API 409 + importer 退出码 2）
2. 编辑器点「同步」→ 先看 diff 汇总（新增 N / 修改 M / 删除 K，按表分组）→ 确认
3. importer 执行：
   - 阶段A静态校验（JSON 解析/枚举合法值/数值范围/图像帧范围/必填引用）
   - 应用差异 → 阶段B引用完整性（悬空引用、被删记录的反向引用，基线感知：库中原有的历史空引用放行）
   - 任何校验失败 → 整体拒绝，未写库，报告见 `workspace/sync_report.txt`
   - 备份双库（`Database/Backup/dbeditor-<时间戳>/` + 客户端 `Data/Backup/…`，另有 MirDB 自带 gzip 备份）
   - 写服务端库（`SystemDatabaseInfo.Version` 自动 bump，如 2026.08.13.4 → .5）
   - 复制到客户端 `Data/System.db`（**双写**，防 ToolTip/逻辑分叉）
   - round-trip：重新开库逐字段读回验证
4. 重启服务端生效

### 恢复 / 故障排查
- **同步后想撤销**：取 `Debug/ServerCore/Database/Backup/dbeditor-<时间戳>/System.db` 覆盖服务端库
  和客户端库（服务端须停止），重启服务端
- **round-trip 失败**（极小概率）：报告会给出备份路径，按上面方法恢复
- **工作区乱了**：`git log -- Tools/dbeditor/workspace` 找任意历史点 `git checkout <sha> -- Tools/dbeditor/workspace`，或逐记录回滚
- **dbeditor 起不来**：`workspace.lock` 被占 → 杀掉旧实例；venv 缺 → `./run.sh` 自动重建
- **同步被拒**：看 `sync_report.txt` 首行（端口占用 or 校验错误清单，精确到 表#Index.字段）

## 边界（硬约束）

- **绝不写 Users.db**（玩家数据）；importer 用 `SessionMode.System` 只开 System.db
- **绝不绕过缓冲区直写 .db**（测试副本除外，如 /tmp/rt_db/）
- 读库永远走只读（副本/只读 Session）；写库只在显式同步且服务端已停时

## 验收记录（2026-08-13，全部通过）

| # | 项 | 结果 |
|---|---|---|
| 1 | FastAPI+Vue 启动，:8810 可访问 | ✅ `GET / → 200` |
| 2 | 四类数据 列表+详情+编辑+新增+复制+删除 | ✅ API/页面全通（MagicInfo 复制→#176、ItemInfo#6 改名+子表 9 行、StoreInfo#30 改价） |
| 3 | 保存只落 JSON + git 自动 commit，.db mtime 不变 | ✅ mtime 1786599583 前后一致；commit `dbeditor: 修改 StoreInfo#30…` |
| 4 | 改动追踪 diff + 按记录回滚 | ✅ `/api/changes` 正确显示 Price 200→4321；回滚 MagicInfo#1 成功 |
| 5 | 同步：diff 汇总→校验→备份→双库→round-trip | ✅ 版本 2026.08.13.4→.5→.6；双库 md5 一致；22,272 条读回验证通过 |
| 6 | 服务端在跑时同步被拒 | ✅ API 409 + importer 退出码 2 |
| 7 | 悬空 DropInfo 被拒且报告指出该行 | ✅ `DropInfo#16282.Monster: 引用 MonsterInfo#434000 无法解析` |
| 8 | 游戏内实测 | ✅ 见下 |

### 游戏内实测（验收标准 8）

1. 目标：`StoreInfo#30`（Mark Of Destruction [T]，商城 Y 键商品），初始 Price=200
2. dbeditor 改价 200 → 4321 →（并发测试改 12345）→ 同步（版本 .5→.6，双库 md5 `b2a9f64a…`）
3. 重启服务端 + 无头客户端（Xvfb :99 + openbox + godot-mono，`DBEDITOR_VERIFY_ITEM` 钩子自动翻到目标页）
4. 证据：
   - 改前日志：`[GameStore] 列表: 30 Mark Of Destruction [T] | 显示价: 200`
   - 改后日志：`[GameStore] 行渲染: Mark Of Destruction [T] | 显示价: 12,345`
   - 截图（docs/dbeditor-acceptance/）：
     - `docs/dbeditor-acceptance/dbed_01_before_price200.png`（改动前大厅）
     - `docs/dbeditor-acceptance/dbed_02_after_price12345.png`（改动后商城全屏）
     - `docs/dbeditor-acceptance/dbed_03_price_zoom_12345.png`（价格区放大，橙色 5 位数字 = 12,345）
     - `docs/dbeditor-acceptance/dbed_04_mall_dialog.png`（商城对话框裁剪）
     - `docs/dbeditor-acceptance/gamelog-evidence.txt`（日志摘录）+ `dbed_05_fresh_log_run.png`（复测截屏）
   - 像素佐证：价格标签橙色数字为 **5 段**（"12,345"），改前为 3 位（"200"）

无头验证操作要点：`xdotool windowfocus --sync <WID>` 后按键才进游戏；鼠标点击用 XTEST
（`/tmp/xlibenv/flow99.py`）；商城在按名称排序第 4 页（诊断日志 `对话框屏幕区域` 给出坐标基准）。
