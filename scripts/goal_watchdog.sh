#!/usr/bin/env bash
# goal_watchdog.sh — keep the Mir3 EI reverse-engineering goal session alive.
#
# Cron-driven (every 5 min) watchdog. State machine over the goal agent:
#
#   HEALTHY    process alive + transcript fresh (age <= STALL_SECONDS)
#   RUNNING    a tool call may be in flight (last tool_execution_start within
#              TOOL_WINDOW) — never nudge while RUNNING
#   STALLED    alive, no new transcript entries for STALL_SECONDS, and no
#              recent tool activity — send "继续" to the goal pane
#   DEAD       no goal omp process — relaunch `omp --resume <id> --auto-approve`
#   COMPLETED  goal status no longer "active" — auto-disable (kill-switch)
#   FAILED     MAX_FAILS consecutive failed recoveries — halt for HALT_AFTER,
#              then retry one fresh round (never spams)
#
# Goal-pane discovery: a tmux pane is "the goal pane" when
#   ~/.omp/agent/terminal-sessions/<tty>  maps to the goal session jsonl.
# Pane indexes shift when panes die, so we never hardcode an index; the tty
# mapping is the primary key (pane id %0 only as fallback).
#
# Modes:
#   --check     read-only diagnostics (no side effects)
#   --status    human-readable judgment + recent log
#   --dry-run   simulate actions; prints what would run, no side effects
#
# Log:   ~/.omp/logs/goal-watchdog.log
# State: ~/.omp/goal-watchdog.state
# Kill-switch: touch ~/.omp/mir3-goal-watchdog.off to disable entirely.

set -u
export PATH=/usr/local/bin:/usr/bin:/bin:/home/tetsuya/.bun/bin

# Kill-switch: touch this file to stop the watchdog entirely (goal completed).
OFF_FILE=/home/tetsuya/.omp/mir3-goal-watchdog.off
if [ -f "$OFF_FILE" ]; then
  exit 0
fi

OMP=/home/tetsuya/.bun/bin/omp
WORKDIR=/home/tetsuya/development/Mir3-Research
TMUX_SESSION=zircon
GOAL_PANE_ID="zircon:%0"                  # stable pane id of the goal pane (fallback)
TERM_SESS_DIR=/home/tetsuya/.omp/agent/terminal-sessions
SESSION_DIR=/home/tetsuya/.omp/agent/sessions/-development-Mir3-Research
GOAL_ID=019feb87-4104-7000-8548-3a0adb440578
GOAL_SESSION_FILE="$SESSION_DIR/2026-08-10T11-55-37-604Z_$GOAL_ID.jsonl"
LOG=/home/tetsuya/.omp/logs/goal-watchdog.log
STATE=/home/tetsuya/.omp/goal-watchdog.state
PY=/home/tetsuya/mir3-venv/bin/python3

STALL_SECONDS=${STALL_SECONDS:-1200}      # no new transcript entry for this long => stalled
TOOL_WINDOW=${TOOL_WINDOW:-400}           # tool_execution_start younger than this => RUNNING
                                          # (single tool timeout is 300s; 400 keeps margin)
STALL_RESTART_SECONDS=${STALL_RESTART_SECONDS:-1800}  # transcript frozen longer than this
                                          # (and not RUNNING) => hard restart (kill + resume)
MAX_FAILS=${MAX_FAILS:-4}                 # consecutive failed recoveries before halting
HALT_AFTER=${HALT_AFTER:-3600}            # freeze automatic recovery for this long when halted

CHECK_ONLY=0
DRY_RUN=0
[ "${1:-}" = "--check" ] && CHECK_ONLY=1
[ "${1:-}" = "--dry-run" ] && DRY_RUN=1
[ "${1:-}" = "--status" ] && CHECK_ONLY=1

mkdir -p /home/tetsuya/.omp/logs

log() { printf '%s %s\n' "$(date '+%F %T')" "$*" >> "$LOG"; }
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

probe_out=$(probe_jsonl 2>/dev/null)
last_tool=$(printf '%s\n' "$probe_out" | sed -n 's/^last_tool=//p')
goal_status=$(printf '%s\n' "$probe_out" | sed -n 's/^goal_status=//p')

# --- goal pane tty: pane whose terminal-sessions mapping names the goal file ---
# ps reports the tty as "pts/1"; tmux pane_tty as "/dev/pts/1"; the
# terminal-sessions dir names files "pts-1". Normalize to "pts-<N>".
ttykey() { printf 'pts-%s' "${1##*/}"; }

goal_ttybase=""
# terminal-sessions/<tty> holds two lines: cwd, then the session jsonl path.
session_of_tty() { awk 'END{print}' "$TERM_SESS_DIR/$1" 2>/dev/null; }
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
  echo "=== goal watchdog status $(date '+%F %T') ==="
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
  tail -n 8 "$LOG" 2>/dev/null || echo "(no log yet)"
  exit 0
fi

if [ "$CHECK_ONLY" = 1 ]; then
  echo "goal_pid=${goal_pid:-none} goal_tty=${goal_ttybase:-none} goal_status=${goal_status:-unknown}"
  echo "goal_session_file=$GOAL_SESSION_FILE age=${age:-n/a}s tool_age=${tool_age:-n/a}s"
  echo "threshold=${STALL_SECONDS}s tool_window=${TOOL_WINDOW}s"
  echo "last_run=$(st_get LAST_RUN) last_action=$(st_get LAST_ACTION) last_ts=$(st_get LAST_TS)"
  echo "restart_fails=$(st_get RESTART_FAILS) nudge_fails=$(st_get NUDGE_FAILS)"
  exit 0
fi

# --- goal completed? then stop ourselves, never touch it again -----------------
# Goal status is omp's own bookkeeping: "active" while running, "paused" when
# the user (or agent) paused it. Only a *terminal* status (complete, blocked,
# error, ...) means the goal engine stopped driving it — restarting or nudging
# would be wrong. Auto-disable via the kill-switch.
# "paused" is NOT terminal: the process is alive but idle; let the STALLED
# logic below take over (nudge, then kill+resume if frozen past threshold).
if [ -n "$goal_status" ] && [ "$goal_status" != "active" ] && [ "$goal_status" != "paused" ]; then
  log "goal status='$goal_status' (not active); disabling watchdog"
  touch "$OFF_FILE"
  exit 0
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
# fallback: 无 tty 映射时优先命中 %0(goal pane 惯例)。注意 pane id 目标必须
# 单独使用(-t %0),不能拼成 "session:%0"(tmux 会当 window 名解析而失败)。
[ -z "$target_pane" ] && tmux has-session -t "$TMUX_SESSION" 2>/dev/null \
  && tmux list-panes -t "$TMUX_SESSION" -F '#{pane_id}' 2>/dev/null | grep -qx '%0' \
  && target_pane="%0"

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
   tmux send-keys -t "$pane" "cd $WORKDIR && $OMP --resume $gid --auto-approve" Enter 2>>"$LOG"
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
  local gid=$GOAL_ID
  if [ -n "$goal_ttybase" ]; then
    local b cand
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
      exit 0
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
  exit 0
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
        exit 0
      fi
      log "restart freeze expired; starting a fresh round"
      rf=0
    fi
    if [ -z "$target_pane" ]; then
      log "goal stuck (pid=$goal_pid age=${age}s) but no pane to restart in; skipping"
      exit 0
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
    exit 0
  fi
  # 2b. 普通 nudge
  nf=$(st_get NUDGE_FAILS); [ -z "$nf" ] && nf=0
  nh=$(st_get NUDGE_HALT_UNTIL); [ -z "$nh" ] && nh=0
  if [ "$nf" -ge "$MAX_FAILS" ]; then
    if [ "$now" -lt "$nh" ]; then
      log "nudge halted (${nf} consecutive fails; resume $(date -d "@$nh" '+%F %T'))"
      st_set   # heartbeat only, preserve halt state
      exit 0
    fi
    log "nudge freeze expired; starting a fresh round"
    nf=0
  fi
  if [ -z "$target_pane" ]; then
    log "goal stalled (pid=$goal_pid age=${age}s) but no pane to nudge; skipping"
    exit 0
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
  exit 0
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

exit 0
