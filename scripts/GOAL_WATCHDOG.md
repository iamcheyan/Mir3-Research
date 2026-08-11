# Mir3 逆向 goal 任务守护脚本(goal_watchdog.sh)实现文档

> 目标:让长期逆向还原任务(Mir3 EI 3.0)在无人值守下持续运行数天,
> 自动处理 agent 自己停下、进程死掉、tmux 会话丢失、任务完成四种情况。
>
> v2 整合了另一份设计稿(`OMP_GOAL_WATCHDOG_DESIGN.md`)的思路:
> 引入 RUNNING 检测防线、goal 状态检测(COMPLETED 自动停用)、失败止损(halt)。

## 1. 背景与问题

- 用户有一个长期 goal 任务(omp goal mode),跑在 tmux 会话 `zircon` 的 pane `%0` 上。
- omp 的 goal 模式虽有自动续跑逻辑(`#j0`,由 `goal.continuationModes` 等控制),
  但实际观察它会随机停下,表现为转录文件里出现连续的 `assistant []` 空条目,等待用户输入。
- 之前用户只能手动在 pane 里输入「继续」来唤醒(4 次:11:59Z / 12:03Z / 12:55Z / 13:22Z),
  停摆时长 20~50 分钟。本脚本把这件事自动化。

## 2. 总体设计

cron 每 5 分钟跑一次脚本,每次运行对 goal 任务做状态判定:

| 状态 | 判定条件 | 动作 |
|---|---|---|
| HEALTHY | 进程存活 且 转录新鲜(age ≤ STALL_SECONDS) | 无操作,仅刷新心跳 |
| RUNNING | 最近 TOOL_WINDOW 秒内有工具调用开始 | **绝不 nudge**(防线) |
| STALLED | 进程存活 且 转录超过 STALL_SECONDS 未更新 且 非 RUNNING | 向 goal pane 发送「继续」;若转录停更超过 STALL_RESTART_SECONDS(默认 30min)→ **升级为 kill + resume 重启** |
| PAUSED | goal status = "paused"(omp 回合结束的 idle,进程活着但等输入) | **立即驱动**:转录停更超 `PAUSED_NUDGE_SECONDS`(默认 20s)即发「继续」nudge,不等 STALL_SECONDS。失败 MAX_FAILS 次才冷却。仅终态 goal 才允许真正停下 |
| DEAD | 找不到 goal 的 omp 进程 | `omp --resume <id> --auto-approve` 重启 |
| COMPLETED | goal status 为**终止态**(complete/blocked/error,≠ active 且 ≠ paused) | 自动停用(kill-switch) |
| FAILED | MAX_FAILS 次连续恢复失败 | halt 冻结 HALT_AFTER 秒,再试一轮 |

### 关键安全约束

同一 tmux 会话 `zircon` 里有**两个** pane:
- `%0`(tty `pts/1`)= goal 任务,只能操作它;
- `%2`(tty `pts/2`)= 助手自己的 omp 会话,**绝不能碰**。

因此脚本**从不**按进程名盲杀/盲启 `bun`/`omp`,一切定位都走 tty 映射(见下)。

## 3. 目标 pane 定位(核心机制)

### 为什么不能硬编码 pane 索引

tmux 的 pane **索引**(`0.0`/`0.1`)会在 pane 被销毁时重排;硬编码索引曾解析到
助手自己的 pane(实测 bug)。pane **id**(`%0`)虽稳定,但只靠它不够(会话重建后可能变化)。

### 定位链路:tty → 会话文件

omp 在 `~/.omp/agent/terminal-sessions/<tty>` 写入两行:
第 1 行是 cwd,第 2 行是当前会话的 jsonl 路径。

```
pts-1 的内容:
/home/tetsuya/development/Mir3-Research
/home/tetsuya/.omp/agent/sessions/-development-Mir3-Research/2026-08-10T11-55-37-604Z_019feb87-....jsonl
```

「goal pane = tty 映射文件末行等于 goal 会话 jsonl 的 pane」。

三种 tty 表示法统一归一化成 `pts-<N>`:
- `ps -o tty=` → `pts/1`
- tmux `#{pane_tty}` → `/dev/pts/1`
- terminal-sessions 文件名 → `pts-1`

```bash
ttykey() { printf 'pts-%s' "${1##*/}"; }
```

### 检测流程

1. 列出 `zircon` 的所有 pane,取各自 `pane_tty`,转 `pts-<N>`,
   查 terminal-sessions 映射,末行 == goal 会话文件 → 得到 `goal_ttybase`。
2. `pgrep -f '/home/tetsuya/\.bun/bin/omp'` 拿所有 omp 进程,
   逐个 `ps -o tty=`,转 `pts-<N>`,匹配 `goal_ttybase` → 得到 `goal_pid`。
   (兜底:若 pane 扫描失败,直接用「进程 tty 的映射末行 == goal 文件」反推。)
3. 停滞判定:`stat -c %Y` 取 goal jsonl 的 mtime,`age = now - mtime`。
   goal 每次写转录都会更新文件,所以 mtime 新鲜度 ≈ agent 活跃度。

## 4. JSONL 信号探测(probe_jsonl)

用 `~/.omp/agent/terminal-sessions` 之外,脚本还会解析 goal 转录 JSONL
(用 `/home/tetsuya/mir3-venv/bin/python3`,兼容 3.13),提取两个信号:

1. **last_tool** — 最后一个 `custom.customType == "tool_execution_start"` 事件的
   `data.startedAt`(转 epoch)。**注意:JSONL 里没有配对的 end/tool_result 事件**
   (实测 333 个 start、0 个 end),所以「工具可能还在跑」只能靠 start 事件的**新近度**推断。
2. **goal_status** — 最后一个 `mode_change` 事件的 `data.goal.status`(当前 `"active"`)。
   这是 omp 自己的记账,任何非 active 值(complete/blocked/...)都意味着 goal 引擎已停止驱动。

### RUNNING 防线(借鉴设计稿)

如果 `now - last_tool <= TOOL_WINDOW`(默认 400s,单次工具超时 300s + 余量),
视为可能有工具正在执行,**绝不发送「继续」**。原因(实测):
- 若在 agent 长操作期间发送,「继续」会**排进编辑器**,反而阻塞 omp 的自动续跑
  (`editor.getText()` 非空检查);
- JSONL 无 end 事件,只能用新近度窗口近似。

### COMPLETED 自动停用(借鉴设计稿)

```
goal_status 为终止态(complete/blocked/error,≠ active 且 ≠ paused)
  →  log + touch OFF_FILE + exit
```

任务真完成时不再无限重启(这是 v1 的已知缺陷),而是自动写入 kill-switch 停用。
(注:设计稿要求「完成 + 交付验收」才停;本脚本只认 omp 的 status 字段,
 交付验收仍靠用户/独立脚本,见 §7。)

**实测修复(2026-08-11)**:paused 曾与 complete 一起被当作「非 active → 停用」,
导致用户手动暂停 goal 测试看门狗时,下一次 cron 就把看门狗永久 touch 停用了
(「看门狗没生效」的元凶之一)。修复:只有**终止态**(complete/blocked/error)才停用;
`paused` 是进程存活但空闲,不自杀,而是**视作 STALLED** 走 nudge/重启恢复——
暂停本来就是「任务还没做完,需要被重新激活」的合法状态。

## 5. 动作细节

### STALLED → 发送「继续」

```bash
tmux send-keys -t <pane> '继续' Enter
```

「继续」是已被用户手动验证有效的唤醒词。nudge 后**不**立刻重发——
下次 cron 运行检查转录是否恢复增长,若仍停滞则失败计数 +1。

### STALLED 升级 → 卡死重启(kill + resume)

转录停更超过 `STALL_RESTART_SECONDS`(默认 1800s = 30 分钟)且非 RUNNING 时,
nudge 已无力回天(进程活着但 agent 内核卡死),升级为硬重启(走 `do_resume`):

```bash
kill <goal_pid>; sleep 3; kill -9 <goal_pid>   # 进程未死透时兜底
tmux send-keys -t <pane> 'cd … && omp --resume <GOAL_ID> --auto-approve' Enter
# 轮询等 omp 进程起来(≤30s),再多等 3s 让 TUI 就绪,然后:
tmux send-keys -t <pane> '继续' Enter          # 驱动 agent 真正执行
```

- 与 DEAD 分支共用 `do_resume`,走同一套 RESTART_FAILS / HALT 冻结计数。
- 触发条件严格晚于普通 nudge(STALL_RESTART > STALL),先给 nudge 一轮机会。

### DEAD → resume 重启

```bash
cd /home/tetsuya/development/Mir3-Research && /home/tetsuya/.bun/bin/omp \
  --resume <GOAL_ID> --auto-approve
```

- 先 `C-c` 清掉 pane 里可能的残留输入。
- goal 模式在 resume 时自动恢复(源码确认:`h.mode==="goal"` 会写回 goal mode state)。
- 会话 id 优先从 tty 映射的 jsonl 文件名解析,取不到才用硬编码的 `GOAL_ID`。

**实测修复(2026-08-11)**:`omp --resume` 只是把会话恢复到暂停前的状态,
agent **不会自动继续执行**——它停在那里等输入(实测:resume 后 TUI 显示
`(Go)` 但转录不增长)。必须 resume 命令回车后,轮询等 omp 进程出现(冷启动 +
加载 48MB transcript 需数秒),再等 3s 让 TUI 就绪,然后发一条「继续」驱动它。
这个「等就绪 + 发继续」流程已内置进 `do_resume`,DEAD 与 STALLED 升级共用。

### 失败止损 halt(借鉴设计稿)

连续 `MAX_FAILS=4` 次(约 20 分钟)动作无效 → 该动作类型冻结 `HALT_AFTER=3600`s
(1 小时),期间 cron 照跑但只刷心跳 + 记日志;**冻结到期后自动开始新的一轮**。
这取代了 v1「无限刷 nudge」的行为。restart 与 nudge 各自独立计数/冻结。

## 6. 闭环验证与「如何判断成功」

每次运行(除被 kill-switch/COMPLETED 提前退出)都会写状态文件
`~/.omp/goal-watchdog.state`:

```
LAST_RUN=<epoch>            # 心跳:每次运行都刷新(含 halt 期间),证明 cron 活着
LAST_ACTION=<restart|nudge|recover|(空)>
LAST_TS=<epoch>             # 最近一次动作时间
RESTART_FAILS=<n>           # 连续失败的重启次数
NUDGE_FAILS=<n>             # 连续失败的 nudge 次数
RESTART_HALT_UNTIL=<epoch>  # 重启冻结截止(0=未冻结)
NUDGE_HALT_UNTIL=<epoch>    # nudge 冻结截止(0=未冻结)
```

- **动作成功的判定**:动作后不立即声称成功,而是等下一次运行(≤5 分钟后)重新检测。
  若进程存活且转录新鲜 → 视为恢复,记 `recover`,清零失败计数和冻结;
  若仍停滞/死亡 → 对应失败计数 +1。
- **失败升级**:计数 ≥ MAX_FAILS → 冻结;冻结到期自动重试一轮。
- **`--status` 自助检查**:打印 `JUDGMENT: HEALTHY|RUNNING|STALLED|DEAD`、
  goal_status、失败计数、冻结截止、最近日志。
- **心跳**:`LAST_RUN` 必须每 5 分钟更新(v2 修复:v1 的 bug 是 LAST_RUN 只写一次
  不刷新,导致无法证明 cron 在跑)。若它不动,说明 cron 或脚本本身挂了。

## 7. 使用方式

```bash
# 手动看一眼当前判断
bash scripts/goal_watchdog.sh --status

# 无副作用演练(打印将执行的动作,不真发按键/不写状态)
STALL_SECONDS=1 TOOL_WINDOW=0 bash scripts/goal_watchdog.sh --dry-run

# 干跑检测(打印检测结果,无副作用)
bash scripts/goal_watchdog.sh --check
```

cron 条目(已安装):

```
*/5 * * * * /home/tetsuya/development/Mir3-Research/scripts/goal_watchdog.sh
```

- 日志:`~/.omp/logs/goal-watchdog.log`
- 状态:`~/.omp/goal-watchdog.state`
- **kill-switch**:`touch ~/.omp/mir3-goal-watchdog.off` 永久停用(任务完成后
  脚本也会在 COMPLETED 时自动 touch);删除该文件重新启用。
- 调阈值(环境变量):`STALL_SECONDS`(默认 1200)、`TOOL_WINDOW`(默认 400)、
  `STALL_RESTART_SECONDS`(默认 1800)、`PAUSED_NUDGE_SECONDS`(默认 20)、`MAX_FAILS`(默认 4)、`HALT_AFTER`(默认 3600)。

## 8. 文件与路径速查

| 项 | 值 |
|---|---|
| 脚本 | `/home/tetsuya/development/Mir3-Research/scripts/goal_watchdog.sh` |
| 本文档 | `/home/tetsuya/development/Mir3-Research/scripts/GOAL_WATCHDOG.md` |
| 设计稿(参考) | `/home/tetsuya/development/Mir3-Research/docs/project/OMP_GOAL_WATCHDOG_DESIGN.md` |
| goal 会话 id | `019feb87-4104-7000-8548-3a0adb440578` |
| goal 转录 | `~/.omp/agent/sessions/-development-Mir3-Research/2026-08-10T11-55-37-604Z_019feb87-....jsonl` |
| goal 进程 | 运行在 tmux `zircon` pane `%0`(tty `pts/1`)的 `omp` |
| 助手自身会话 | pane `%2`(tty `pts/2`),**永不触碰** |
| omp 可执行 | `/home/tetsuya/.bun/bin/omp`(symlink 到 pi-coding-agent dist) |
| JSONL 探测 | `/home/tetsuya/mir3-venv/bin/python3` |
| 日志 | `~/.omp/logs/goal-watchdog.log` |
| 状态 | `~/.omp/goal-watchdog.state` |
| kill-switch | `~/.omp/mir3-goal-watchdog.off` |

## 9. 已知边界与风险

- **RUNNING 是近似**:JSONL 无工具结束事件,只能靠 start 事件新近度 + 400s 窗口近似。
  若工具超时恰好 >400s 且转录不增长,可能误判 STALLED → nudge 排队阻塞自动续跑。
  阈值可调,默认值覆盖实测最长单次 bash 调用 300s 超时。
- **COMPLETED 仅看 status 字段**:未做设计稿要求的交付验收(验证脚本/git 状态)。
  omp 若误标 complete 会提前停用——目前以 status 为准,验收靠用户。
- **paused ≠ 完成(2026-08-11 实测)**:omp 的 `paused` 状态(回合结束 idle)
  曾被误当「完成」→ 看门狗自杀停用。现在明确:**只有终止态才停用**;
  paused 走 **case 1.5 快速驱动**——转录停更超 `PAUSED_NUDGE_SECONDS`(默认 20s)
  即发「继续」nudge,不等 STALL_SECONDS(那是 active 卡死的兜底)。
  设计理由:paused 是 omp 明确声明的 idle(不是卡死),无需用 STALL_SECONDS 确认;
  也不加 RUNNING guard(tool_age 只反映停更前最后一次工具开始,paused 后无新工具,
  用它挡会误判)。实测:`tmux send-keys -t '%0' '继续'` 对 paused 的 omp 有效
  (转录立即增长、agent 启动下一 round)。若未来 omp 新增其他「非终止」status,
  需在 COMPLETED 判定处同步排除(当前白名单:active、paused)。
- **resume 不自动继续(2026-08-11 实测)**:`omp --resume` 恢复会话但停在等待输入,
  必须补发「继续」。`do_resume` 已内置「等进程起来 → 等 TUI 就绪 → 发继续」,
  但等待是定时轮询(15×2s+3s),若机器极慢或 transcript 超大,可能 TUI 未就绪
  就发「继续」导致消息落进 shell 缓冲——届时表现为「resume 了但没跑」,
  看门狗下一轮会再走 STALLED 升级,属可自愈但延迟一次周期。
- **nudge 输入残留**:若 nudge 时 agent 恰在长操作,「继续」会留在输入框;
  RUNNING 防线 + 大阈值缓解;重启分支会先 `C-c`。
- **tty 映射依赖**:所有定位依赖 `terminal-sessions/` 映射文件,omp 改格式需同步。
- **API 层故障**:实测 `http-400-requests/` 里全是
  `reasoning_content must be passed back` 的网关 400——这类故障会让回合中断、
  转录停更。v2 起:转录停更超 `STALL_RESTART_SECONDS` 且非 RUNNING 时,看门狗会
  **kill + resume 硬重启**根除(而不只是 nudge + 冻结)。若重启后仍立即复发,走
  RESTART_FAILS 冻结止损;彻底根除需修 omp 的请求组装或换模型。
