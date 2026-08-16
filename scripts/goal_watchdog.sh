#!/usr/bin/env bash
# goal_watchdog.sh — keep multiple omp goal sessions alive (multi-goal version).
#
#   HEALTHY    process alive + transcript fresh (age <= STALL_SECONDS)
#   RUNNING    a tool call may be in flight (last tool_execution_start within
#              TOOL_WINDOW) — never nudge while RUNNING
#   PAUSED     goal_status == "paused" (omp idle at end of a turn) — nudge
#              "继续" immediately so the agent never idles unless the goal is
#              truly done. Only a *terminal* goal status is allowed to stop.
#   STALLED    alive, goal_status active but no new transcript entries for
#              STALL_SECONDS, and no recent tool activity — send "继续"
#   DEAD       no goal omp process — relaunch `omp --resume <id> --auto-approve`
#   COMPLETED  goal status terminal (complete/blocked/error/…) — auto-disable
#   FAILED     MAX_FAILS consecutive failed recoveries — halt for HALT_AFTER,
#              then retry one fresh round (never spams)
#
# Multi-goal: 每个 goal 一行配置(见 GOALS 数组),各 goal 独立 state 文件与
# kill-switch;一个 goal 完成/禁用不影响其它 goal。全局 kill-switch
# ~/.omp/mir3-goal-watchdog.off 仍然有效(禁用所有)。
#
# Goal-pane discovery: a tmux pane is "the goal pane" when
#   ~/.omp/agent/terminal-sessions/<tty>  maps to the goal session jsonl.
# Pane indexes shift when panes die, so we never hardcode an index; the tty
# mapping is the primary key (first pane of the tmux session as fallback).
#
# Modes:
#   --check     read-only diagnostics (no side effects)
#   --status    human-readable judgment + recent log
#   --dry-run   simulate actions; prints what would run, no side effects
#
# Log:   ~/.omp/logs/goal-watchdog.log
# State: ~/.omp/goal-watchdog.<GOAL_ID 前8位>.state (每 goal 独立)
# Kill-switch per goal: touch ~/.omp/mir3-goal-watchdog.<前8位>.off
# Kill-switch global:   touch ~/.omp/mir3-goal-watchdog.off

set -u
export PATH=/usr/local/bin:/usr/bin:/bin:/home/tetsuya/.bun/bin

# 全局 kill-switch: touch 此文件禁用所有 goal 的 watchdog。
GLOBAL_OFF_FILE=/home/tetsuya/.omp/mir3-goal-watchdog.off
if [ -f "$GLOBAL_OFF_FILE" ]; then
  exit 0
fi

OMP=/home/tetsuya/.bun/bin/omp
TERM_SESS_DIR=/home/tetsuya/.omp/agent/terminal-sessions
LOG=/home/tetsuya/.omp/logs/goal-watchdog.log
PY=/home/tetsuya/mir3-venv/bin/python3

STALL_SECONDS=${STALL_SECONDS:-1200}      # no new transcript entry for this long => stalled
TOOL_WINDOW=${TOOL_WINDOW:-400}           # tool_execution_start younger than this => RUNNING
                                          # (single tool timeout is 300s; 400 keeps margin)
STALL_RESTART_SECONDS=${STALL_RESTART_SECONDS:-1800}  # transcript frozen longer than this
                                          # (and not RUNNING) => hard restart (kill + resume)
MAX_FAILS=${MAX_FAILS:-4}                 # consecutive failed recoveries before halting
HALT_AFTER=${HALT_AFTER:-3600}            # freeze automatic recovery for this long when halted
PAUSED_NUDGE_SECONDS=${PAUSED_NUDGE_SECONDS:-20}  # goal_status==paused 且转录停更超过此时长
                                         # => 立即 nudge「继续」(paused 是 omp 回合结束
                                         # 的正常 idle,不是卡死,故用短阈值快速驱动;
                                         # 仅终态 goal 才允许真正停下)

# ── Goal 配置 ──────────────────────────────────────────────────────────────
# 每行一个 goal,字段以 | 分隔:
#   GOAL_ID | SESSION_FILE | TMUX_SESSION | WORKDIR | STATE_FILE
# 新增 goal: 复制一行,填新会话 ID / jsonl 路径 / tmux 会话名 / 工作目录。
# STATE_FILE 建议 ~/.omp/goal-watchdog.<GOAL_ID 前8位>.state
GOALS=(
  # ---- 2026-08-15 编辑器军团（旧 goal 已完结，条目归档于 git 历史）----
  # [archived 2026-08-15 E1完成] "01a00412-74a4-7000-bd16-37667d96da85|/home/tetsuya/.omp/agent/sessions/-development-Mir3-Research/2026-08-15T06-18-33-508Z_01a00412-74a4-7000-bd16-37667d96da85.jsonl|ed-map|/home/tetsuya/development/Mir3-Research|编辑器E1地图编辑器"
  # [archived 2026-08-16 E4完成] "01a0041d-7c61-7000-aeaa-019ff9f8d404|/home/tetsuya/.omp/agent/sessions/-development-Mir3-Research/2026-08-15T06-30-36-385Z_01a0041d-7c61-7000-aeaa-019ff9f8d404.jsonl|ed-magic|/home/tetsuya/development/Mir3-Research|编辑器E4技能实验室"
  # [archived 2026-08-16 E2完成] "01a005d1-6557-7000-82be-86b96d3a7d36|/home/tetsuya/.omp/agent/sessions/-development-Mir3-Research/2026-08-15T14-26-44-183Z_01a005d1-6557-7000-82be-86b96d3a7d36.jsonl|ed-npc|/home/tetsuya/development/Mir3-Research|编辑器E2NPC摆放编辑"
  # [archived] "01a0007a-e0db-7000-aa8c-7ff6380acb67|/home/tetsuya/.omp/agent/sessions/-development-yomu/2026-08-14T13-34-08-091Z_01a0007a-e0db-7000-aa8c-7ff6380acb67.jsonl|yomudesign|/home/tetsuya/development/yomu|Yomu无框单页视觉重构"
  # [archived] "01a00239-3d0a-7000-bb94-9c32abee22ac|/home/tetsuya/.omp/agent/sessions/-development-fudoki/2026-08-14T21-41-40-746Z_01a00239-3d0a-7000-bb94-9c32abee22ac.jsonl|fudokiredesign|/home/tetsuya/development/fudoki|Fudoki本地化+Linear式UI重构"
  # [archived] "01a0006d-4e8b-7000-833d-ca644ca86904|/home/tetsuya/.omp/agent/sessions/-development-Mir3-Research/2026-08-14T13-19-18-667Z_01a0006d-4e8b-7000-833d-ca644ca86904.jsonl|par-win|/home/tetsuya/development/Mir3-Research|webport窗口系统"
  # [archived] "019ffff2-a2d7-7000-9dcb-0943df61bbaf|/home/tetsuya/.omp/agent/sessions/-development-svc-dashboard/2026-08-14T11-05-19-319Z_019ffff2-a2d7-7000-9dcb-0943df61bbaf.jsonl|svcglass|/home/tetsuya/development/svc-dashboard|iOS玻璃重构"
  # [archived] "019fffa6-769b-7000-8202-c1ea6d10c204|/home/tetsuya/.omp/agent/sessions/-development-svc-dashboard/2026-08-14T09-42-07-259Z_019fffa6-769b-7000-8202-c1ea6d10c204.jsonl|svcfile|/home/tetsuya/development/svc-dashboard|文件浏览器"
  # [archived] "019fffa3-62ad-7000-a861-af664e6f24f5|/home/tetsuya/.omp/agent/sessions/-development-Mir3-Research/2026-08-14T09-38-45-549Z_019fffa3-62ad-7000-a861-af664e6f24f5.jsonl|webaudit|/home/tetsuya/development/Mir3-Research|webport像素审计"
  # [archived] "019fff5a-3510-7000-9fb4-1612ba008826|/home/tetsuya/.omp/agent/sessions/-development-svc-dashboard/2026-08-14T08-18-49-744Z_019fff5a-3510-7000-9fb4-1612ba008826.jsonl|svcui2|/home/tetsuya/development/svc-dashboard|面板UI改造二批"
  # [archived] "019fff0e-cd73-7000-a336-2771e3ba262b|/home/tetsuya/.omp/agent/sessions/-development-Mir3-Research/2026-08-14T06-56-28-019Z_019fff0e-cd73-7000-a336-2771e3ba262b.jsonl|webport|/home/tetsuya/development/Mir3-Research|网页客户端Phase1"
  # [archived] "019ffbaf-4c8d-7000-a36c-76336908116a|/home/tetsuya/.omp/agent/sessions/-development-zircon/2026-08-13T15-13-17-453Z_019ffbaf-4c8d-7000-a36c-76336908116a.jsonl|botgoal|/home/tetsuya/development/zircon|机器人拟真行为"
  # [archived] "019ffeb7-4306-7000-97c7-d29d1d9be29c|/home/tetsuya/.omp/agent/sessions/-development-svc-dashboard/2026-08-14T05-20-50-950Z_019ffeb7-4306-7000-97c7-d29d1d9be29c.jsonl|svctools|/home/tetsuya/development/svc-dashboard|运维全家桶"
  # [archived] "019ffea9-735a-7000-a536-241dc099e4f2|/home/tetsuya/.omp/agent/sessions/-development-miyako/2026-08-14T05-05-45-818Z_019ffea9-735a-7000-a536-241dc099e4f2.jsonl|miyako2|/home/tetsuya/development/miyako|miyako第二轮收尾"
  # [archived] "019ffe6a-aa56-7000-9ba2-587f4b39cf5b|/home/tetsuya/.omp/agent/sessions/-development-svc-dashboard/2026-08-14T03-57-11-126Z_019ffe6a-aa56-7000-9ba2-587f4b39cf5b.jsonl|svcux|/home/tetsuya/development/svc-dashboard|主界面UX重构"
  # [archived] "019ffe3c-a41c-7000-b880-f7fd740e0355|/home/tetsuya/.omp/agent/sessions/-development-miyako/2026-08-14T03-06-54-876Z_019ffe3c-a41c-7000-b880-f7fd740e0355.jsonl|miyako|/home/tetsuya/development/miyako|miyako修复"
  # [archived] "019ffe2f-ed77-7000-91fa-53a750b53425|/home/tetsuya/.omp/agent/sessions/-development-svc-dashboard/2026-08-14T02-53-01-687Z_019ffe2f-ed77-7000-91fa-53a750b53425.jsonl|svcmobile|/home/tetsuya/development/svc-dashboard|面板移动端深度适配"
  # [archived] "019ffe1e-bf33-7000-99cf-97f6773c73d0|/home/tetsuya/.omp/agent/sessions/-development-Mir3-Research/2026-08-14T02-34-15-731Z_019ffe1e-bf33-7000-99cf-97f6773c73d0.jsonl|questdata|/home/tetsuya/development/Mir3-Research|任务落地资料补齐"
  # [archived] "019ffdd7-af02-7000-9ecc-bbfdcc701201|/home/tetsuya/.omp/agent/sessions/-development-Mir3-Research/2026-08-14T01-16-38-530Z_019ffdd7-af02-7000-9ecc-bbfdcc701201.jsonl|webclient|/home/tetsuya/development/Mir3-Research|静态Web客户端测试台"
  # [archived] "019ffdbd-da15-7000-9426-3ceb79d1c4c6|/home/tetsuya/.omp/agent/sessions/-development-zircon/2026-08-14T00-48-25-621Z_019ffdbd-da15-7000-9426-3ceb79d1c4c6.jsonl|webspike|/home/tetsuya/development/zircon|Web移植阶段0-Spike"
  # [archived] "019ffdb4-9539-7000-a81a-1d090a03bc99|/home/tetsuya/.omp/agent/sessions/-development-zircon/2026-08-14T00-38-18-169Z_019ffdb4-9539-7000-a81a-1d090a03bc99.jsonl|uieditor|/home/tetsuya/development/zircon|UI-Web编辑器"
  # [archived] "019ffda1-0b2b-7000-81db-949ad4ccf0ce|/home/tetsuya/.omp/agent/sessions/-development-Mir3-Research/2026-08-14T00-16-57-643Z_019ffda1-0b2b-7000-81db-949ad4ccf0ce.jsonl|mvtoolkit|/home/tetsuya/development/Mir3-Research|mapviewer六大增强"
  # [archived] "019ffd85-2226-7000-b58b-774658f3b1b2|/home/tetsuya/.omp/agent/sessions/-development-svc-dashboard/2026-08-13T23-46-28-518Z_019ffd85-2226-7000-b58b-774658f3b1b2.jsonl|svcdash|/home/tetsuya/development/svc-dashboard|svc-dashboard智能化改造"
  # [archived] "019ffd58-c268-7000-9c80-7ce51a62cce3|/home/tetsuya/.omp/agent/sessions/-development-oh-my-desktop/2026-08-13T22-58-00-424Z_019ffd58-c268-7000-9c80-7ce51a62cce3.jsonl|omd|/home/tetsuya/development/oh-my-desktop|OMD-KNOWN-K1-K8收尾"
  # [archived] "019ff331-5ca2-7000-869c-ab301d561150|/home/tetsuya/.omp/agent/sessions/-development-Mir3-Research/2026-08-11T23-38-46-306Z_019ff331-5ca2-7000-869c-ab301d561150.jsonl|dbviewer|/home/tetsuya/development/Mir3-Research|/home/tetsuya/.omp/goal-watchdog.019ff331.state"
  # [archived] "019ff34c-b48e-7000-b3f9-0bf36fa2ad54|/home/tetsuya/.omp/agent/sessions/-development-mir3-website/2026-08-12T00-42-14-194Z_019ff34c-b48e-7000-b3f9-0bf36fa2ad54.jsonl|mir3site|/home/tetsuya/development/mir3-website|/home/tetsuya/.omp/goal-watchdog.019ff34c.state"
  # [archived] "019ff444-b5f7-7000-af5b-3288f2608d49|/home/tetsuya/.omp/agent/sessions/-development-Mir3-Research/2026-08-12T04-39-31-575Z_019ff444-b5f7-7000-af5b-3288f2608d49.jsonl|questdesign|/home/tetsuya/development/Mir3-Research|/home/tetsuya/.omp/goal-watchdog.019ff444.state"
  # [archived] "019ff47d-4e2e-7000-9d9b-008f5e47c431|/home/tetsuya/.omp/agent/sessions/-development-Mir3-Research/2026-08-12T05-41-20-558Z_019ff47d-4e2e-7000-9d9b-008f5e47c431.jsonl|questv2|/home/tetsuya/development/Mir3-Research|/home/tetsuya/.omp/goal-watchdog.019ff47d.state"
  # [archived] "019ff4a1-be55-7000-abbc-751c955fb272|/home/tetsuya/.omp/agent/sessions/-development-Mir3-Research/2026-08-12T06-21-08-565Z_019ff4a1-be55-7000-abbc-751c955fb272.jsonl|questv3|/home/tetsuya/development/Mir3-Research|/home/tetsuya/.omp/goal-watchdog.019ff4a1.state"
  # [archived] "019ffb10-2bc7-7000-9ba0-49352606156b|/home/tetsuya/.omp/agent/sessions/-development-Mir3-Research/2026-08-13T12-19-28-839Z_019ffb10-2bc7-7000-9ba0-49352606156b.jsonl|dbeditor|/home/tetsuya/development/Mir3-Research|/home/tetsuya/.omp/goal-watchdog.019ffb10.state"
  # [archived] "019ffba6-950c-7000-be7c-358ead847cb8|/home/tetsuya/.omp/agent/sessions/-development-Mir3-Research/2026-08-13T15-03-46-188Z_019ffba6-950c-7000-be7c-358ead847cb8.jsonl|zircon|/home/tetsuya/development/Mir3-Research|/home/tetsuya/.omp/goal-watchdog.019ffba6.state"
  # [archived] "019ffd44-2ca2-7000-afa0-5c4b34b5d047|/home/tetsuya/.omp/agent/sessions/-development-zircon/2026-08-13T22-35-31-362Z_019ffd44-2ca2-7000-afa0-5c4b34b5d047.jsonl|zdocs|/home/tetsuya/development/zircon|Zircon全代码文档化"
  # [archived] "019ffbbb-cff3-7000-8893-29882c9c7c6f|/home/tetsuya/.omp/agent/sessions/-development-Mir3-Research/2026-08-13T15-26-57-523Z_019ffbbb-cff3-7000-8893-29882c9c7c6f.jsonl|ghaudit|/home/tetsuya/development/Mir3-Research|/home/tetsuya/.omp/goal-watchdog.019ffbbb.state"
  # [archived] "01a00412-62a0-7000-b4a4-04d0853ab6b8|/home/tetsuya/.omp/agent/sessions/-development-Mir3-Research/2026-08-15T06-18-28-896Z_01a00412-62a0-7000-b4a4-04d0853ab6b8.jsonl|ed-infra|/home/tetsuya/development/Mir3-Research|编辑器E0基础设施"
  # [archived] "01a00412-74a4-7000-bd16-37667d96da85|/home/tetsuya/.omp/agent/sessions/-development-Mir3-Research/2026-08-15T06-18-33-508Z_01a00412-74a4-7000-bd16-37667d96da85.jsonl|ed-map|/home/tetsuya/development/Mir3-Research|编辑器E1地图编辑器"
  # [archived] "01a00412-8721-7000-acd4-2f2e7932b250|/home/tetsuya/.omp/agent/sessions/-development-Mir3-Research/2026-08-15T06-18-38-241Z_01a00412-8721-7000-acd4-2f2e7932b250.jsonl|ed-res|/home/tetsuya/development/Mir3-Research|编辑器E3资源编辑器"
  "01a00878-9625-7000-a1a0-4efc341cb9cb|/home/tetsuya/.omp/agent/sessions/-development-Mir3-Research/2026-08-16T02-48-35-621Z_01a00878-9625-7000-a1a0-4efc341cb9cb.jsonl|e5-data|/home/tetsuya/development/Mir3-Research|编辑器E5参数数据层化"
  # [archived 2026-08-16 E6完成] "01a0088b-76a3-7000-be68-9a857beba360|/home/tetsuya/.omp/agent/sessions/-development-Mir3-Research/2026-08-16T03-09-12-739Z_01a0088b-76a3-7000-be68-9a857beba360.jsonl|e6-fix|/home/tetsuya/development/Mir3-Research|编辑器E6审计问题修复"
)

CHECK_ONLY=0
DRY_RUN=0
[ "${1:-}" = "--check" ] && CHECK_ONLY=1
[ "${1:-}" = "--dry-run" ] && DRY_RUN=1
[ "${1:-}" = "--status" ] && CHECK_ONLY=1

mkdir -p /home/tetsuya/.omp/logs

log() { printf '%s [%s] %s\n' "$(date '+%F %T')" "${GOAL_TAG:-?}" "$*" >> "$LOG"; }
st_get() { grep "^$1=" "$STATE" 2>/dev/null | cut -d= -f2-; }
st_set() {
  local last last_ts rf nf lr rh nh
  last=$(st_get LAST_ACTION); last_ts=$(st_get LAST_TS)
  rf=$(st_get RESTART_FAILS); nf=$(st_get NUDGE_FAILS)
  lr=$(date +%s)                          # heartbeat: refresh on EVERY run
  rh=$(st_get RESTART_HALT_UNTIL); nh=$(st_get NUDGE_HALT_UNTIL)
  [ -z "$lr" ] && lr=$(date +%s)
  [ -z "$rf" ] && rf=0; [ -z "$nf" ] && nf=0
  [ -z "$rh" ] && rh=0; [ -z "$nh" ] && nh=0
  case "${1:-}" in
    restart) last=restart; last_ts=$(date +%s) ;;
    nudge)   last=nudge;   last_ts=$(date +%s) ;;
    recover) last=recover; rf=0; nf=0; rh=0; nh=0 ;;
    warn)    : ;;
  esac
  [ -n "${2:-}" ] && rf=$2
  [ -n "${3:-}" ] && nf=$3
  [ -n "${4:-}" ] && nh=$4
  [ -n "${5:-}" ] && rh=$5
  printf 'LAST_RUN=%s\nLAST_ACTION=%s\nLAST_TS=%s\nRESTART_FAILS=%s\nNUDGE_FAILS=%s\nRESTART_HALT_UNTIL=%s\nNUDGE_HALT_UNTIL=%s\n' \
    "$lr" "$last" "$last_ts" "$rf" "$nf" "$rh" "$nh" > "$STATE"
}

if [ "$DRY_RUN" = 1 ]; then
  log() { :; }        # dry-run: no log writes, no state writes
  st_set() { :; }
fi

# --- probe the session JSONL for goal state --------------------------------
# The omp transcript records tool calls as custom events:
#   {"type":"custom","customType":"tool_execution_start",
#    "data":{"toolCallId":..., "startedAt":"ISO", "toolName":...}, ...}
# There is NO paired end/tool_result event persisted, so "a tool may still be
# running" is inferred from recency of the last tool_execution_start.
# Goal status lives on the latest mode_change event:
#   {"type":"mode_change","data":{"goal":{"id":..., "status":"active", ...}}}
probe_jsonl() {
  "$PY" - "$GOAL_SESSION_FILE" <<'PYEOF'
import json, sys, datetime
path = sys.argv[1]
last_tool = None
goal_status = None
try:
    with open(path, encoding='utf-8') as f:
        for line in f:
            line = line.strip()
            if not line:
                continue
            try:
                ev = json.loads(line)
            except Exception:
                continue
            t = ev.get('type')
            if t == 'custom' and ev.get('customType') == 'tool_execution_start':
                last_tool = ev.get('data', {}).get('startedAt')
            elif t == 'mode_change':
                g = ev.get('data', {}).get('goal')
                if g and g.get('status'):
                    goal_status = g['status']
except Exception:
    pass
def to_epoch(s):
    if not s:
        return ''
    try:
        return str(int(datetime.datetime.fromisoformat(s.replace('Z', '+00:00')).timestamp()))
    except Exception:
        return ''
print('last_tool=' + to_epoch(last_tool))
print('goal_status=' + (goal_status or ''))
PYEOF
}

# --- goal pane tty: pane whose terminal-sessions mapping names the goal file ---
# ps reports the tty as "pts/1"; tmux pane_tty as "/dev/pts/1"; the
# terminal-sessions dir names files "pts-1". Normalize to "pts-<N>".
ttykey() { printf 'pts-%s' "${1##*/}"; }

# session_of_tty: terminal-sessions/<tty> holds two lines: cwd, then the jsonl path.
session_of_tty() { awk 'END{print}' "$TERM_SESS_DIR/$1" 2>/dev/null; }

# ── 单 goal 监测逻辑 ────────────────────────────────────────────────────────
# 依赖全局变量(由主循环设置): GOAL_ID / GOAL_SESSION_FILE / TMUX_SESSION /
# WORKDIR / STATE / GOAL_TAG
watch_one_goal() {
  local probe_out last_tool goal_status
  local goal_ttybase="" goal_pid="" now age tool_age
  local target_pane="" gid rf rh nf nh

  probe_out=$(probe_jsonl 2>/dev/null)
  last_tool=$(printf '%s\n' "$probe_out" | sed -n 's/^last_tool=//p')
  goal_status=$(printf '%s\n' "$probe_out" | sed -n 's/^goal_status=//p')

  goal_ttybase=""
  if tmux has-session -t "$TMUX_SESSION" 2>/dev/null; then
    for panetty in $(tmux list-panes -t "$TMUX_SESSION" -F '#{pane_tty}' 2>/dev/null); do
      key=$(ttykey "$(basename "$panetty")")
      if [ -f "$TERM_SESS_DIR/$key" ] && [ "$(session_of_tty "$key")" = "$GOAL_SESSION_FILE" ]; then
        goal_ttybase=$key; break
      fi
    done
  fi

  # --- goal process: omp running on that tty (fallback: any omp whose tty maps ---
  # --- to the goal session, e.g. mapping survived but pane tty query failed) -----
  goal_pid=""
  for p in $(pgrep -f '/home/tetsuya/\.bun/bin/omp' 2>/dev/null); do
    t=$(ps -o tty= -p "$p" 2>/dev/null | tr -d ' ')
    [ -z "$t" ] || [ "$t" = "?" ] && continue
    t=$(ttykey "$t")
    [ -z "$t" ] && continue
    if { [ -n "$goal_ttybase" ] && [ "$t" = "$goal_ttybase" ]; } || \
       { [ -z "$goal_ttybase" ] && [ -f "$TERM_SESS_DIR/$t" ] && [ "$(session_of_tty "$t")" = "$GOAL_SESSION_FILE" ]; }; then
      goal_pid=$p; [ -z "$goal_ttybase" ] && goal_ttybase=$t
      break
    fi
  done

  # --- stall age: seconds since the goal transcript file was last appended -------
  now=$(date +%s)
  age=""
  if [ -f "$GOAL_SESSION_FILE" ]; then
    mt=$(stat -c %Y "$GOAL_SESSION_FILE" 2>/dev/null || echo 0)
    age=$(( now - mt ))
  fi

  # tool_age: seconds since the last tool_execution_start ('' if none ever)
  tool_age=""
  if [ -n "$last_tool" ]; then
    tool_age=$(( now - last_tool ))
  fi

  # --- --status / --check --------------------------------------------------------
  if [ "${1:-}" = "--status" ]; then
    echo "=== goal watchdog status $(date '+%F %T') goal=${GOAL_TAG} ==="
    echo "goal_pid=${goal_pid:-none} goal_tty=${goal_ttybase:-none}"
    echo "goal_status=${goal_status:-unknown}"
    if [ -n "$goal_pid" ] && [ -n "$age" ] && [ "$age" -le "$STALL_SECONDS" ]; then
      echo "JUDGMENT: HEALTHY (agent alive, transcript age ${age}s)"
    elif [ -n "$goal_pid" ]; then
      if [ -n "$tool_age" ] && [ "$tool_age" -le "$TOOL_WINDOW" ]; then
        echo "JUDGMENT: RUNNING (tool call ${tool_age}s ago, within ${TOOL_WINDOW}s window)"
      else
        echo "JUDGMENT: STALLED (alive but transcript age ${age}s > ${STALL_SECONDS}s)"
      fi
    else
      echo "JUDGMENT: DEAD (no goal omp process)"
    fi
    echo "last_run=$(st_get LAST_RUN) last_action=$(st_get LAST_ACTION) last_ts=$(st_get LAST_TS)"
    echo "restart_fails=$(st_get RESTART_FAILS) nudge_fails=$(st_get NUDGE_FAILS)"
    echo "restart_halt_until=$(st_get RESTART_HALT_UNTIL) nudge_halt_until=$(st_get NUDGE_HALT_UNTIL)"
    echo "--- recent log ---"
    grep "\[${GOAL_TAG}\]" "$LOG" 2>/dev/null | tail -n 8 || echo "(no log yet)"
    return 0
  fi

  if [ "$CHECK_ONLY" = 1 ]; then
    echo "goal=${GOAL_TAG} pid=${goal_pid:-none} tty=${goal_ttybase:-none} status=${goal_status:-unknown}"
    echo "  session_file=$GOAL_SESSION_FILE age=${age:-n/a}s tool_age=${tool_age:-n/a}s"
    echo "  threshold=${STALL_SECONDS}s tool_window=${TOOL_WINDOW}s state=$STATE"
    echo "  last_run=$(st_get LAST_RUN) last_action=$(st_get LAST_ACTION) last_ts=$(st_get LAST_TS)"
    echo "  restart_fails=$(st_get RESTART_FAILS) nudge_fails=$(st_get NUDGE_FAILS)"
    return 0
  fi

  # --- goal completed? then stop ourselves, never touch it again -----------------
  # Goal status is omp's own bookkeeping: "active" while running, "paused" when
  # the user (or agent) paused it. Only a *terminal* status (complete, blocked,
  # error, ...) means the goal engine stopped driving it — restarting or nudging
  # would be wrong. Auto-disable via the per-goal kill-switch.
  # "paused" is NOT terminal: process alive but idle — case 1.5 below drives it
  # with "继续" immediately (short PAUSED_NUDGE_SECONDS), so the agent never
  # stops unless the goal reaches a truly terminal status.
  if [ -n "$goal_status" ] && [ "$goal_status" != "active" ] && [ "$goal_status" != "paused" ]; then
    # --- 自动清理已完成的 goal：杀进程 + 杀 tmux + 记录回看日志 -----------------
    # 资源回收: terminal 状态的 goal 不再需要 omp 进程(bun ~4% 内存/个)和 tmux。
    # 转录 jsonl 保留(omp 自己的会话历史,可 --resume 回看),只回收运行时资源。
    cleanup_completed() {
      local gid="$1" sess="$2" label="$3"
      local ts
      ts=$(date '+%F %T')
      # 找该 goal 的 omp 进程
      local pids
      pids=$(pgrep -f "omp.*--resume $gid" 2>/dev/null)
      if [ -n "$pids" ]; then
        echo "$pids" | while read -r p; do kill "$p" 2>/dev/null; done
        log "cleanup: killed omp pid(s) [$pids] for completed goal $gid"
      fi
      # 杀 tmux 会话(只有该会话属于此 goal 时;会话名在 GOALS 里登记过)
      if [ -n "$sess" ] && tmux has-session -t "$sess" 2>/dev/null; then
        tmux kill-session -t "$sess" 2>/dev/null
        log "cleanup: killed tmux session '$sess' for completed goal $gid"
      fi
      # 记录到完成日志(追加,便于回看)
      local done_log=/home/tetsuya/.omp/logs/goal-completed.log
      {
        echo "[$ts] goal=$gid label=${label:-$sess} status=$goal_status"
        echo "  transcript=$(basename "$GOAL_SESSION_FILE")"
        echo "  workdir=$WORKDIR"
        echo "  resume_cmd: $OMP --resume $gid --auto-approve"
        echo ""
      } >> "$done_log"
      log "cleanup: recorded completed goal $gid in $done_log"
    }
    # 只在第一次检测到终态时清理一次(state 里记 marker 防重复)
    local already
    already=$(st_get CLEANED)
    if [ "$already" != "1" ]; then
      if [ "$DRY_RUN" = 1 ]; then
        echo "TEST would cleanup: goal=$gid session=$TMUX_SESSION (status=$goal_status)"
      else
        cleanup_completed "$GOAL_ID" "$TMUX_SESSION" "$LABEL"
        st_set CLEANED 1
      fi
    fi
    log "goal status='$goal_status' (terminal); disabling watchdog for this goal"
    touch "$GOAL_OFF_FILE"
    return 0
  fi

  # --- resolve the pane to act on ------------------------------------------------
  # pane_tty 形如 /dev/pts/1,ttykey 归一化为 pts-1;逐 pane 匹配拿 pane_id。
  pane_of_ttykey() {
    tmux list-panes -t "$TMUX_SESSION" -F "#{pane_tty}|#{pane_id}" 2>/dev/null \
      | awk -F'|' -v k="$1" '{ split($1, a, "/"); if (("pts-" a[length(a)]) == k) { print $2; exit } }'
  }
  target_pane=""
  if [ -n "$goal_ttybase" ]; then
    target_pane=$(pane_of_ttykey "$goal_ttybase")
  fi
  # fallback: 无 tty 映射时优先命中该 tmux 会话的第一个 pane。
  [ -z "$target_pane" ] && tmux has-session -t "$TMUX_SESSION" 2>/dev/null \
    && target_pane=$(tmux list-panes -t "$TMUX_SESSION" -F '#{pane_id}' 2>/dev/null | head -1)

  # --- case 0: no tmux session at all (e.g. reboot) -> recreate detached ---------
  if ! tmux has-session -t "$TMUX_SESSION" 2>/dev/null; then
    log "tmux session '$TMUX_SESSION' missing; recreating detached"
    if [ "$DRY_RUN" = 1 ]; then
      echo "TEST would run: tmux new-session -d -s $TMUX_SESSION -c $WORKDIR"
    else
      tmux new-session -d -s "$TMUX_SESSION" -c "$WORKDIR" 2>>"$LOG"
    fi
    sleep 2
    target_pane="$TMUX_SESSION:0.0"
  fi

  # --- resume helper: kill-stuck / dead-restart both call this ---------------------
  # resume 只是把会话恢复到暂停前的状态,agent 不会自动继续执行;必须再发一条
  # 「继续」驱动它跑下去(否则看门狗下一轮又会判定 STALLED)。
  do_resume() {
    local pane=$1 gid=$2
    if [ "$DRY_RUN" = 1 ]; then
      echo "TEST would run: tmux send-keys -t $pane C-c"
      echo "TEST would run: tmux send-keys -t $pane 'cd $WORKDIR && $OMP --resume $gid --auto-approve' Enter"
      echo "TEST would run: (wait for omp boot) tmux send-keys -t $pane '继续' Enter"
      return
    fi
    tmux send-keys -t "$pane" C-c 2>/dev/null
    tmux send-keys -t "$pane" "cd $WORKDIR && PATH=/home/tetsuya/.bun/bin:\$PATH $OMP --resume $gid --auto-approve" Enter 2>>"$LOG"
    # 等 omp 进程起来(bun 冷启动 + 加载大 transcript 需要数秒),再多等几秒让
    # TUI 就绪,否则「继续」会被启动期吞掉或落进 shell 缓冲。
    for _ in 1 2 3 4 5 6 7 8 9 10 11 12 13 14 15; do
      sleep 2
      pgrep -f "/home/tetsuya/.bun/bin/omp.*--resume $gid" >/dev/null 2>&1 && break
    done
    sleep 3
    tmux send-keys -t "$pane" '继续' Enter 2>>"$LOG"
    log "resumed $gid in $pane; sent '继续' to drive agent"
  }
  resolve_gid() {
    local gid=$GOAL_ID b cand
    if [ -n "$goal_ttybase" ]; then
      b=$(basename "$(session_of_tty "$goal_ttybase")" .jsonl)
      cand=${b##*_}
      [ "${#cand}" -ge 8 ] && gid=$cand
    fi
    printf '%s' "$gid"
  }

  # --- case 1: goal process dead -> relaunch by resuming its session -------------
  if [ -z "$goal_pid" ]; then
    rf=$(st_get RESTART_FAILS); [ -z "$rf" ] && rf=0
    rh=$(st_get RESTART_HALT_UNTIL); [ -z "$rh" ] && rh=0
    if [ "$rf" -ge "$MAX_FAILS" ]; then
      if [ "$now" -lt "$rh" ]; then
        log "restart halted (${rf} consecutive fails; resume $(date -d "@$rh" '+%F %T'))"
        st_set   # heartbeat only, preserve halt state
        return 0
      fi
      log "restart freeze expired; starting a fresh round"
      rf=0
    fi
    if [ -z "$target_pane" ]; then
      log "goal dead and no goal pane found; creating window 'goal'"
      if [ "$DRY_RUN" = 1 ]; then
        echo "TEST would run: tmux new-window -t $TMUX_SESSION -n goal -c $WORKDIR"
      else
        tmux new-window -t "$TMUX_SESSION" -n goal -c "$WORKDIR" 2>>"$LOG"
      fi
      target_pane="$TMUX_SESSION:goal.0"
    fi
    gid=$(resolve_gid)
    log "goal process dead; relaunching: omp --resume $gid in $target_pane"
    do_resume "$target_pane" "$gid"
    rf=$((rf+1))
    nh=$(st_get NUDGE_HALT_UNTIL); [ -z "$nh" ] && nh=0
    [ "$rf" -ge "$MAX_FAILS" ] && rh=$((now + HALT_AFTER))
    st_set restart "$rf" "" "$nh" "$rh"
    return 0
  fi

  # --- case 1.5: PAUSED — omp idle at end of a turn, drive it immediately -------
  # 用户要求:goal 未最终完成前绝不许停下。omp 在一个回合结束会把 goal 置为
  # "paused"(进程活着、idle 等输入)。这不是卡死,无需等 STALL_SECONDS 确认。
  # paused 是 omp 明确声明的 idle 态,故不加 RUNNING guard(tool_age 只反映停更
  # 前最后一次工具开始,paused 后无新工具,用它挡会误判);只要转录停更超过
  # PAUSED_NUDGE_SECONDS(默认 20s)立刻 nudge「继续」驱动下一轮。
  # 失败计数复用 nudge 计数器:连续 MAX_FAILS 次 nudge 后仍 paused 才进入冷却。
  if [ "$goal_status" = "paused" ] && [ -n "$age" ] && [ "$age" -gt "$PAUSED_NUDGE_SECONDS" ]; then
    nf=$(st_get NUDGE_FAILS); [ -z "$nf" ] && nf=0
    nh=$(st_get NUDGE_HALT_UNTIL); [ -z "$nh" ] && nh=0
    if [ "$nf" -ge "$MAX_FAILS" ]; then
      if [ "$now" -lt "$nh" ]; then
        log "paused-nudge halted (${nf} consecutive fails; resume $(date -d "@$nh" '+%F %T'))"
        st_set   # heartbeat only, preserve halt state
        return 0
      fi
      log "paused-nudge freeze expired; starting a fresh round"
      nf=0
    fi
    if [ -z "$target_pane" ]; then
      log "goal paused (pid=$goal_pid age=${age}s) but no pane to nudge; skipping"
      return 0
    fi
    log "goal paused: pid=$goal_pid age=${age}s; driving with '继续' -> $target_pane"
    if [ "$DRY_RUN" = 1 ]; then
      echo "TEST would run: tmux send-keys -t $target_pane '继续' Enter"
    else
      tmux send-keys -t "$target_pane" '继续' Enter 2>>"$LOG"
    fi
    nf=$((nf+1))
    rh=$(st_get RESTART_HALT_UNTIL); [ -z "$rh" ] && rh=0
    [ "$nf" -ge "$MAX_FAILS" ] && nh=$((now + HALT_AFTER))
    st_set nudge "" "$nf" "$nh" "$rh"
    return 0
  fi

  # --- case 2: alive but stalled -> nudge with "继续" -----------------------------
  # RUNNING guard: if the last tool_execution_start is within TOOL_WINDOW a tool
  # may still be executing (single tool timeout is 300s). Never nudge then — the
  # typed "继续" would sit in the editor and block omp's own auto-continuation.
  if [ -n "$age" ] && [ "$age" -gt "$STALL_SECONDS" ] && \
     { [ -z "$tool_age" ] || [ "$tool_age" -gt "$TOOL_WINDOW" ]; }; then
    # 2a. 卡死升级:转录停更超过 STALL_RESTART_SECONDS(默认 30min)且 nudge 无力回天
    #     -> 杀掉卡死进程,resume 重启(v1 只 nudge 的已知缺陷,见 GOAL_WATCHDOG.md)。
    if [ -n "$age" ] && [ "$age" -gt "$STALL_RESTART_SECONDS" ]; then
      rf=$(st_get RESTART_FAILS); [ -z "$rf" ] && rf=0
      rh=$(st_get RESTART_HALT_UNTIL); [ -z "$rh" ] && rh=0
      if [ "$rf" -ge "$MAX_FAILS" ]; then
        if [ "$now" -lt "$rh" ]; then
          log "restart halted (${rf} consecutive fails; resume $(date -d "@$rh" '+%F %T'))"
          st_set   # heartbeat only, preserve halt state
          return 0
        fi
        log "restart freeze expired; starting a fresh round"
        rf=0
      fi
      if [ -z "$target_pane" ]; then
        log "goal stuck (pid=$goal_pid age=${age}s) but no pane to restart in; skipping"
        return 0
      fi
      gid=$(resolve_gid)
      log "goal stuck: pid=$goal_pid age=${age}s (>= ${STALL_RESTART_SECONDS}s); kill + resume $gid in $target_pane"
      if [ "$DRY_RUN" = 1 ]; then
        echo "TEST would kill pid $goal_pid"
      else
        kill "$goal_pid" 2>/dev/null
        sleep 3
        kill -9 "$goal_pid" 2>/dev/null
        sleep 1
      fi
      do_resume "$target_pane" "$gid"
      rf=$((rf+1))
      nh=$(st_get NUDGE_HALT_UNTIL); [ -z "$nh" ] && nh=0
      [ "$rf" -ge "$MAX_FAILS" ] && rh=$((now + HALT_AFTER))
      st_set restart "$rf" "" "$nh" "$rh"
      return 0
    fi
    # 2b. 普通 nudge
    nf=$(st_get NUDGE_FAILS); [ -z "$nf" ] && nf=0
    nh=$(st_get NUDGE_HALT_UNTIL); [ -z "$nh" ] && nh=0
    if [ "$nf" -ge "$MAX_FAILS" ]; then
      if [ "$now" -lt "$nh" ]; then
        log "nudge halted (${nf} consecutive fails; resume $(date -d "@$nh" '+%F %T'))"
        st_set   # heartbeat only, preserve halt state
        return 0
      fi
      log "nudge freeze expired; starting a fresh round"
      nf=0
    fi
    if [ -z "$target_pane" ]; then
      log "goal stalled (pid=$goal_pid age=${age}s) but no pane to nudge; skipping"
      return 0
    fi
    log "goal stalled: pid=$goal_pid age=${age}s tool_age=${tool_age:-n/a}s; sending nudge to $target_pane"
    if [ "$DRY_RUN" = 1 ]; then
      echo "TEST would run: tmux send-keys -t $target_pane '继续' Enter"
    else
      tmux send-keys -t "$target_pane" '继续' Enter 2>>"$LOG"
    fi
    nf=$((nf+1))
    rh=$(st_get RESTART_HALT_UNTIL); [ -z "$rh" ] && rh=0
    [ "$nf" -ge "$MAX_FAILS" ] && nh=$((now + HALT_AFTER))
    st_set nudge "" "$nf" "$nh" "$rh"
    return 0
  fi

  # --- case 3: healthy — agent alive and transcript growing -----------------------
  # Closed loop: a prior action succeeded only if we now see a live process and a
  # fresh transcript. Reset failure counters/halts on recovery so the next WARN
  # is meaningful.
  last=$(st_get LAST_ACTION)
  if [ "$last" = restart ] || [ "$last" = nudge ]; then
    if [ "$(st_get RESTART_FAILS)" -gt 0 ] || [ "$(st_get NUDGE_FAILS)" -gt 0 ]; then
      log "recovered: agent healthy again (pid=$goal_pid age=${age}s)"
    fi
    st_set recover
  else
    st_set   # heartbeat: refresh LAST_RUN only
  fi
  return 0
}

# ── 主循环:遍历所有 goal ────────────────────────────────────────────────────
for goal_line in "${GOALS[@]}"; do
  IFS='|' read -r GOAL_ID GOAL_SESSION_FILE TMUX_SESSION WORKDIR F5 LABEL <<< "$goal_line"
  # 第5字段两种历史形态: 旧式=state 文件路径(/开头), 新式=label(中文任务名)。
  # label 形态时 STATE 用标准路径, 否则熔断计数写进 ~/中文文件名(2026-08-15 实测事故)。
  if [[ "$F5" == /* ]]; then STATE="$F5"; LABEL=${LABEL:-$F5};
  else STATE="/home/tetsuya/.omp/goal-watchdog.${GOAL_ID:0:8}.state"; LABEL=${LABEL:-$F5}; fi
  GOAL_TAG=${GOAL_ID:0:8}
  GOAL_OFF_FILE="/home/tetsuya/.omp/mir3-goal-watchdog.$GOAL_TAG.off"
  # 每 goal kill-switch: touch 此文件禁用该 goal 的 watchdog。
  if [ -f "$GOAL_OFF_FILE" ]; then
    continue
  fi
  watch_one_goal "${1:-}"
done

exit 0
