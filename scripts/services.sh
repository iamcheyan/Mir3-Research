#!/usr/bin/env bash
# services.sh — 编辑器军团统一服务管理（总纲 §4.2 端口表 / §8.1，Goal E0）。
#
# 用法：
#   scripts/services.sh status                 # 全部服务状态
#   scripts/services.sh start   mapviewer …    # 启动（可多选；无参=全部）
#   scripts/services.sh stop    [name …]
#   scripts/services.sh restart [name …]
#   scripts/services.sh log     <name>          # 看日志尾部（tail -f 可自己来）
#
# 实现说明（§3.5 教训内嵌）：
#   - hub daemon 的 socket 协议对 shell 不公开（omp 无 hub 子命令），故本脚本
#     自治：nohup + pidfile（/tmp/mir3-services/<name>.pid）+ TCP 端口探测。
#     omp 会话内仍可用 hub 工具管理，两套互不冲突（端口被占即视为已运行）。
#   - dotnet 类服务用 bash -c "cd <目录> && exec …" 包装（cwd 相对路径不可靠）。
#   - 名字被坏记录卡住是 hub 的事，这里 pid 卡死则 kill -9 兜底。
set -u

REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
RUN="/tmp/mir3-services"
mkdir -p "$RUN"

PY="${PYTHON:-$HOME/mir3-venv/bin/python}"
[ -x "$PY" ] || PY=python3
SYS_PY=python3   # 纯标准库工具用系统 python

# ---- 数据根目录（env 优先，82 机默认值兜底） ----
: "${MIR3_ZIRCON_ROOT:=/home/tetsuya/development/zircon}"
: "${MIR3_EI_ROOT:=/data/NAS/TMP/EI传奇3.0客户端}"
: "${MIR3_MUD3_ROOT:=/data/NAS/TMP/Mud3}"
export MIR3_ZIRCON_ROOT MIR3_EI_ROOT MIR3_MUD3_ROOT

# ---- 服务注册表: name|port|ready超时秒|start命令 ----
# start 命令里相对路径一律相对 REPO（外层已 cd "$REPO"）。
SERVICES=(
    "zircon-core|7000|90|bash -c 'cd $MIR3_ZIRCON_ROOT/Debug/ServerCore && exec dotnet ServerCore.dll'"
    "wsgateway|7001|15|cd Tools/wsgateway && exec $PY wsgateway.py"
    "wilviewer|8765|25|exec $PY Tools/web/wilviewer.py --root '$MIR3_EI_ROOT' --port 8765"
    "dbviewer|8800|15|exec $SYS_PY Tools/dbviewer/dbviewer.py --data /tmp/dbviewer_data --port 8800"
    "dbeditor|8810|40|cd Tools/dbeditor && exec ./run.sh"
    "uieditor|8820|40|cd Tools/uieditor && exec ./run.sh"
    "webres|8821|20|cd Tools/webres && exec $PY serve.py"
    "webclient|8822|20|cd Tools/webclient && exec $PY serve.py"
    "webport|8823|25|exec $PY Tools/webport/serve.py"
    "portal|8840|15|exec $SYS_PY Tools/portal/portal.py --port 8840"
    "mapviewer|8899|40|exec $PY Tools/maps/mapviewer.py --port 8899"
)
ORDER=(zircon-core wsgateway wilviewer dbviewer dbeditor uieditor webres webclient webport portal mapviewer)

svc_line() {
    local name="$1" line
    for line in "${SERVICES[@]}"; do
        [[ "$line" == "$name|"* ]] && { printf '%s' "$line"; return 0; }
    done
    return 1
}

port_of()   { svc_line "$1" | cut -d'|' -f2; }
timeout_of(){ svc_line "$1" | cut -d'|' -f3; }
cmd_of()    { svc_line "$1" | cut -d'|' -f4-; }
port_pid() {  # 服务名 -> 端口实际监听进程 pid（ss+grep；mawk 不支持 match 三参）
    local port
    port="$(port_of "$1")" || return 1
    ss -tlnp 2>/dev/null | grep ":$port " | grep -o 'pid=[0-9]*' | head -1 | cut -d= -f2
}

port_open() {  # TCP 探测（bash 内建 /dev/tcp，无外部依赖）
    local host=127.0.0.1 port="$1"
    (exec 3<>"/dev/tcp/$host/$port") 2>/dev/null && { exec 3>&- 3<&-; return 0; }
    return 1
}


is_up() { port_open "$(port_of "$1")"; }

svc_start() {
    local name="$1"
    if is_up "$name"; then echo "[=] $name 已在运行（端口 $(port_of "$name")）"; return 0; fi
    local pre
    case "$name" in
        dbviewer)
            # 首次启动需要 SystemDbProbe 导出（dotnet，约 1 分钟）
            if [ ! -f /tmp/dbviewer_data/MapInfo.json ]; then
                echo "[*] $name: /tmp/dbviewer_data 缺失，先跑 export.sh …"
                bash Tools/dbviewer/export.sh || { echo "[!] 导出失败"; return 1; }
            fi ;;
        zircon-core)
            if [ ! -f "$MIR3_ZIRCON_ROOT/Debug/ServerCore/ServerCore.dll" ]; then
                echo "[!] $MIR3_ZIRCON_ROOT/Debug/ServerCore/ServerCore.dll 不存在，先编译服务端"; return 1
            fi ;;
    esac
    echo "[+] $name 启动中（端口 $(port_of "$name")）…"
    ( cd "$REPO" && setsid nohup bash -c "$(cmd_of "$name")" >>"$RUN/$name.log" 2>&1 </dev/null &
      disown; echo $! >"$RUN/$name.pid" )
    # 就绪等待（TCP 通即认为就绪；zircon-core 要等 DB 加载 ~11s+）
    local deadline=$(( SECONDS + $(timeout_of "$name") ))
    while (( SECONDS < deadline )); do
        local pid; pid="$(port_pid "$name")"
        [ -n "$pid" ] && echo "$pid" >"$RUN/$name.pid"   # 记真实监听 pid（$! 可能是包装子壳）
        if is_up "$name"; then echo "[✓] $name 就绪 :$(port_of "$name") (pid ${pid:-$(cat "$RUN/$name.pid" 2>/dev/null)})"; return 0; fi
        sleep 1
    done
    echo "[!] $name $(timeout_of "$name")s 内未就绪，看日志: $RUN/$name.log（尾部如下）"
    tail -n 5 "$RUN/$name.log" 2>/dev/null | sed 's/^/    /'
    return 1
}

svc_stop() {
    local name="$1" pid
    if ! is_up "$name" && ! pid_alive "$name"; then echo "[=] $name 未运行"; rm -f "$RUN/$name.pid"; return 0; fi
    for pid in "$(port_pid "$name")" "$(cat "$RUN/$name.pid" 2>/dev/null)"; do
        [ -n "${pid:-}" ] && kill "$pid" 2>/dev/null || true
    done
    local deadline=$(( SECONDS + 10 ))
    while (( SECONDS < deadline )) && is_up "$name"; do sleep 1; done
    if is_up "$name"; then
        echo "[!] $name 未在 10s 内退出，kill -9"
        for pid in "$(port_pid "$name")" "$(cat "$RUN/$name.pid" 2>/dev/null)"; do
            [ -n "${pid:-}" ] && kill -9 "$pid" 2>/dev/null || true
        done
        sleep 1
    fi
    rm -f "$RUN/$name.pid"
    echo "[-] $name 已停止"
}

svc_status() {
    local name="$1" port pid state
    port="$(port_of "$name" 2>/dev/null)" || { printf '%-14s ??\n' "$name"; return; }
    pid="$(port_pid "$name")"
    if port_open "$port"; then state="运行中"; else state="停止"; fi
    printf '%-14s %-6s %-8s %s\n' "$name" "$port" "$state" "${pid:+pid $pid}"
}

names_for() {  # 参数为空 → 全部（按 ORDER）；否则校验每个名字
    local n
    if [ $# -eq 0 ]; then printf '%s\n' "${ORDER[@]}"; return 0; fi
    for n in "$@"; do
        svc_line "$n" >/dev/null || { echo "[!] 未知服务: $n（可选: ${ORDER[*]}）" >&2; exit 2; }
    done
    printf '%s\n' "$@"
}

ACTION="${1:-status}"; shift || true
mapfile -t TARGETS < <(names_for "$@")
cd "$REPO"

case "$ACTION" in
    start)   for n in "${TARGETS[@]}"; do svc_start "$n"; done ;;
    stop)    for n in "${TARGETS[@]}"; do svc_stop  "$n"; done ;;
    restart) for n in "${TARGETS[@]}"; do svc_stop  "$n"; done
             for n in "${TARGETS[@]}"; do svc_start "$n"; done ;;
    status)  printf '%-14s %-6s %-8s %s\n' "SERVICE" "PORT" "STATE" "PID"
             for n in "${TARGETS[@]}"; do svc_status "$n"; done ;;
    log)     [ ${#TARGETS[@]} -eq 1 ] || { echo "用法: services.sh log <name>" >&2; exit 2; }
             tail -n "${LOG_LINES:-40}" "$RUN/${TARGETS[0]}.log" 2>/dev/null || echo "[!] 无日志 ${TARGETS[0]}" ;;
    *) echo "用法: services.sh <start|stop|restart|status|log> [name …]（name 省略=全部）" >&2; exit 2 ;;
esac
