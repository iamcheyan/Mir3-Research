# Goal E6 — E1/E2 审计问题修复：mapviewer 稳定性 + tile sprite 通道 + 编辑 UI 回归

> 来源：2026-08-16 主会话派出的 E1E2Audit 只读审计代理（痕迹 `/tmp/audit-e1e2/`）+ 主会话独立复核（curl/代码级），结论双源一致。
> 本文是 E6 唯一任务书。总纲 `docs/editor/EDITOR_GOALS_MASTER.md` §0 铁律、§3 坑表、§9 协作约定适用。
> 领地：`Tools/maps/mapedit/*`、`Tools/maps/mapviewer.py`、`scripts/services.sh`（如需）。**不碰** `Tools/webclient|webres|magiclab|resedit`（E5 领地）、不碰 zircon 仓库。
> 与 E5 并行：E5 正在改 `Tools/magiclab/extract_effect_table.py`、`gen_cs_table.py`、删 `Tools/magiclab/magic-effect-table.json` 与 `Tools/resedit/frame-formulas.json`（迁往 zircon/ClientData）——这些文件你只读不写。

---

## 0. 背景：两个 goal 的审计判定

| Goal | 判定 | 依据 |
|---|---|---|
| E2 NPC 摆放 | **delivered_as_claimed** | move/guard_move/create/delete/拖拽/阻挡格校验（阻挡格拒绝、force 旁路、通行格接受）/rollback/diff=0 全部实测通过且已还原（sandbox z014.map，`.bak-20260816-115520` 在案） |
| E1 地图编辑器 | **partially_delivered** | 保存管线/往返/撤销/笔刷真实可用；但存在 1 个 blocker（服务稳定性）+ 3 个 UI 回归 + 若干小项 |

用户原话背景："我刚刚试了一下，跟我想的完全不一样，问题特别多。"

## 1. 问题清单（全部已复现/已定位根因，执行时先复现再修）

### P0-1【blocker·E1】mapviewer 服务实例级死锁：prewarm 全局 import 锁 + 进程池雪崩
- 症状：mapviewer(:8899) 服务一段时间后对所有请求 hang（浏览器表现"打不开/一直转"——用户感知的第一个"完全不一样"）。py-spy 实证（`/tmp/audit-e1e2/pyspy-31829*.txt`）。
- 根因（两层叠加）：
  1. **子进程在 import 锁上串行**：`mapedit/render.py:194 render_tile → frames.py:97 → zlsdk.py:439 decode → PIL Image.open → importlib._lock_unlock_module`——ProcessPoolExecutor 的 worker 进程首次解码时才 lazy import PIL 插件，全部卡在解释器全局 import 锁上排队。
  2. **每请求 `os.fork` 新进程池**（api.py:998 do_GET 路径，栈里 `process_request_thread → ProcessPoolExecutor → _launch_processes`）：并发请求各自起进程池，`tile-prewarm` 后台线程（prewarm.py:102）又与请求侧争同一慢池——NAS 上 I/O 慢时彻底雪崩。
- 复现：起 mapviewer → 浏览器开 `/?edit=1` 连续快速切 3-4 张地图 → 服务开始 hang。
- 修复方向（按序）：
  1. render/frames/zlsdk 在服务启动时**预 import**（warm-up 一帧解码），消灭 lazy import 锁；
  2. 全局唯一 ProcessPoolExecutor（模块级单例，`max_workers` 固定 2-4），请求侧只 submit 不建池；禁止 per-request `_start_executor_manager_thread`；
  3. tile 请求超时保护：单个 tile render submit 设 timeout（如 20s），超时返回 503 + 前端占位，不再无限 hang；
  4. 验证：并发 20 请求打 `/tile`（不同地图），全部 <2s 返回且服务存活；py-spy 复查无 import 锁栈。
- 注意：审计期间代理已重启 mapviewer（当前 pid 324608+，正常服务中）。修复验证时用 `scripts/services.sh restart mapviewer` 统一管理。

### P0-2【blocker·E1】`/sprite?lib=Tile&...` 全 404 → 编辑 UI 的"file+帧选择器 sprite 实时预览"残废
- 症状：curl `http://localhost:8899/sprite?lib=Tile&frame=0` → 404；`Mon-5` → 200。编辑面板三图层的 tile 类库（Tile/SmTiles/Objects 等）预览图全部裂图。
- 根因：`mapedit/api.py:751 /sprite` 端点只在**单个 data_dir** 下探测 `<lib>.Zl` / `<lib>.wil`。ZL 客户端 data_dir（`zircon/Debug/Client/Data/`）有 `Mon-*.Zl` 没有 `Tile*`；Tile 类库只在 **EI 客户端**（`/data/NAS/TMP/EI传奇3.0客户端/Data/Tiles30c.wil` 等命名也带版本后缀）。而渲染层（render.py 中图层）另有自己的库解析（mapviewer 主类构造时按 layout/客户端类型配置多库），/sprite 端点没有复用它——同一服务里两条路径的库可见性不一致。
- 修复方向：
  1. /sprite 复用渲染层的库解析（或共享一张 lib_id→库文件路径映射表：ZL data_dir + EI data_dir 联合探测，含 `Tiles*.wil` 模糊匹配）；
  2. 支持 `lib=Tile`/`lib=SmTiles`/`lib=Objects` 等编辑器逻辑名 → 物理 `Tiles30c.wil` 等的实际映射（与 render.py 图层用同一张表，杜绝两份）；
  3. 验证：`/sprite?lib=Tile&frame=0`、`lib=SmTiles`、`lib=Objects`、`lib=Mon-5`、`lib=NPC` 全 200；编辑 UI 面板预览图全部显示（浏览器实测截图）。

### P1-1【major·E1】`/_webui/*` 404 → 移动端壳样式丢失（templates.py:388-389 引用）
- 根因：templates.py 引用 `/_webui/tokens.css`、`/_webui/mobile-shell.css`，api.py:440 端点按 `parent.parent/common/webui/` 找文件——但**当前 mapviewer 进程的 cwd/sys.path 上下文里该路径解析不到**（`Tools/common/webui/` 目录与四个文件实际存在）。审计日志（11:12 与 11:16 两次）均 404。
- 修复：先 curl 复现；按 `__file__` 相对定位（api.py 的 `_P(__file__).resolve().parent.parent / "common" / "webui"` 实际算出来是 `Tools/maps/common/webui`——**路径少了一层**，正确应为 `parent.parent.parent / "Tools" / "common" / "webui"`，即 Tools/ 下的 common）。修正后 curl 两个 CSS 全 200。
- 注：若这两个 CSS 只服务移动端壳且当前桌面版根本没用到，可改为「按需 204 + 桌面模板不再引用」，二选一，以模板实际引用为准。

### P1-2【major·E1】`/npc/list` 404 → E2 的 NPC 摆放 UI 入口不可达
- 根因：E2 交付的 `/npc/*` 全是 POST 动作端点（move/create/delete/guard_move/safezone_move/region_size/rollback），**没有 GET 列表端点**；而编辑 UI（templates.py）期望有 NPC 实体列表拉取（日志里浏览器确实请求了 `/npc/list` 404）。E2 会话自述"端到端实测通过"走的是 curl POST + webport 游戏内验证，没测过 UI 面板拉列表这条链路。
- 修复：mapedit/api.py 加 `GET /npc/list?map=<stem>`（从 db_workspace 的 NPCInfo/当前 workspace 读该图 NPC 实体：id/name/x/y/face/body）；确认编辑 UI 的 NPC 面板显示、选中、高亮联动正常（浏览器实测）。

### P1-3【major·E1】切图取消后状态错位（审计代理实测发现）
- 症状：编辑模式快速切图并中途取消，地图切换到 B 但编辑会话（editstate）还停在 A 的未保存状态，后续保存可能写错目标（未验证到写错盘，但状态不一致已实测）。
- 修复：editstate 会话与地图切换的事务边界——切图（含取消路径）必须显式关闭/确认当前编辑会话；未保存更改时先弹确认。写测试：编辑 A → 切 B → 取消 → 检查 editstate 指向与 UI 提示一致。

### P2（minor，顺手修）
- `/favicon.ico` 404：返回 204 或给个占位。
- mapviewer 启动时 NAS cache 挂载检查报错信息（`/home/tetsuya/NAS/TMP` 不可用时的 usage 文案）应给人话提示（当前是 argparse usage dump）——见 deadlock-log 头部。
- prewarm 598179 tiles 全量预热对 NAS 压力大：prewarm 线程 nice 已有，但应加"服务端口就绪先于 prewarm 完成"保证（当前已是后台线程，确认端口先通即可，别让 prewarm 抢占请求线程的 I/O——与 P0-1 的池改造一并解决）。

## 2. 交付与验收标准

- [ ] P0-1：并发 20 tile 请求 <2s 全返回、服务不 hang；py-spy 无 import 锁；连续切图 10 次服务存活
- [ ] P0-2：Tile/SmTiles/Objects/Mon/NPC 五类 lib 的 /sprite 全 200；编辑面板预览无裂图（截图）
- [ ] P1-1：/_webui 两 CSS 200（或模板去引用，二选一落地）
- [ ] P1-2：/npc/list 200 且 UI NPC 面板列表/选中/高亮正常（截图）
- [ ] P1-3：切图取消场景 editstate 一致性测试通过
- [ ] P2：favicon 204；启动报错人话化
- [ ] E2 回归：修 P1-2 时不得破坏既有 POST /npc/* 行为（move/rollback curl 抽测 + workspace diff=0 收尾）
- [ ] 证据（截图/报告）落 `docs/editor/e6-proof/`；每个 P 项一个 commit（中文），即时 push origin
- [ ] 不越领地：不碰 E5 文件；zircon 仓库不动

## 3. 约束与协作
- `scripts/services.sh restart mapviewer` 管理服务；调试进程用完收净
- E5 并行中：若 git 操作遇到 E5 的在途文件（magiclab/resedit），只跳过不合并
- 踩坑回写总纲 §3；完成后 watchdog 三件套归档（.off + 数组行注释 + goal-completed.log）
