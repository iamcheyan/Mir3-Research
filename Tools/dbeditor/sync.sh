#!/usr/bin/env bash
# sync.sh —— dbeditor 同步全流程：
#   端口检测 → DBImporter（校验+写临时副本）→ probe 重导出 → 语义对比
#   → 备份双库 → 安装双库 → 重置基线 → 报告落盘 workspace/sync_report.txt
# 任一步失败即中止（原库不动）。绝不直接改原库——先写临时副本验证再原子安装。
set -euo pipefail

DBEDITOR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO="$(cd "$DBEDITOR/../.." && pwd)"
WS="$DBEDITOR/workspace"
# ---- 平台适配（Linux 与 macOS 通用）----
# md5sum 是 GNU 工具，macOS 只有 md5 -q；封装一层保证两条路径都能用。
if command -v md5sum >/dev/null 2>&1; then
  md5of() { md5sum "$1" | cut -d' ' -f1; }
else
  md5of() { md5 -q "$1"; }
fi
# 仓库根：优先显式 $ZIRCON，其次 MIR3_ZIRCON_ROOT（AGENTS.md 约定），再试本机常见位置。
if [ -z "${ZIRCON:-}" ]; then
  for cand in "${MIR3_ZIRCON_ROOT:-}" "$HOME/development/zircon" \
              "$HOME/development/Zircon" "$HOME/Development/Zircon"; do
    [ -n "$cand" ] && [ -f "$cand/ServerCore/ServerCore.csproj" -o -f "$cand/ServerLibrary/ServerLibrary.csproj" ] && { ZIRCON="$cand"; break; }
  done
fi
[ -n "${ZIRCON:-}" ] || { echo "[X] 找不到 Zircon 仓库根：请 export ZIRCON=<仓库根> 或 MIR3_ZIRCON_ROOT=<仓库根>"; exit 1; }
echo "[0/7] Zircon 仓库根：$ZIRCON"
# 导入器/探针的 csproj 通过 MIR3_ZIRCON_ROOT 找 Zircon 源码（见 AGENTS.md），
# 未设置时会把 ZirconRoot 回落到错误路径，编译报 CS0246: 未找到 Library。
export MIR3_ZIRCON_ROOT="$ZIRCON"
SERVER_DB="$ZIRCON/Debug/ServerCore/Database/System.db"
CLIENT_DB="$ZIRCON/Debug/Client/Data/System.db"
BACKUP_DIR="$ZIRCON/Debug/ServerCore/Database/Backup/System"
REPORT="$WS/sync_report.txt"
# 解析真实物理路径，并收集"实际存在的库副本"：
#  - macOS：Debug/ServerCore/Database、Debug/Client 都是指向 ~/mir2ei/{Database,Data} 的
#    软链 → 4 条逻辑路径只对应 2 个实体文件；
#  - Linux(debian)：Debug/ServerCore/Database 是实体目录，另有 <repo>/System.db 与
#    ~/mir2ei/Database/System.db → 4 个实体文件（AGENTS.md 的"4 处一致"）。
# 一律 realpath 去重后逐个写入：既保证每一份都更新，又不会把软链替换成实体文件。
realpath_of() { python3 -c 'import os,sys;print(os.path.realpath(sys.argv[1]))' "$1" 2>/dev/null || printf '%s' "$1"; }
DB_COPIES=()
add_db_copy() {
  local p="$1" rp existing
  [ -f "$p" ] || return 0
  rp="$(realpath_of "$p")"
  for existing in ${DB_COPIES[@]+"${DB_COPIES[@]}"}; do
    [ "$existing" = "$rp" ] && return 0
  done
  DB_COPIES+=("$rp")
}
add_db_copy "$SERVER_DB"
add_db_copy "$CLIENT_DB"
add_db_copy "$HOME/mir2ei/Database/System.db"
add_db_copy "$ZIRCON/System.db"
[ "${#DB_COPIES[@]}" -gt 0 ] || { echo "[X] 没找到任何 System.db 副本（SERVER_DB=$SERVER_DB）"; exit 1; }
echo "[0/7] 库副本 ${#DB_COPIES[@]} 份（realpath 去重后将被一并写入）："
for p in "${DB_COPIES[@]}"; do echo "      - $p"; done

main() {
echo "==================== 同步 $(date '+%F %T') ===================="
# 构建重试：同机并发 dotnet build（兄弟会话）会偶发 CS0006 ref 程序集竞态
build_retry() {
  local i
  for i in 1 2 3 4 5; do
    if dotnet build "$1" -v q; then return 0; fi
    echo "[!] 构建失败（第 $i 次），10s 后重试：$1"
    sleep 10
  done
  echo "[X] 构建最终失败：$1"
  return 1
}

# ---------- 1) 端口检测 ----------
# 只看"是否真的服务端在监听"：macOS 上 7000 常被 AirPlay 接收器(ControlCenter)占用，
# 仅凭"端口可连"会误报。用 lsof 取监听进程名，非 dotnet/ServerCore 一律不算运行中。
probe_port() {
python3 - "$1" <<'PY'
import socket, sys
try:
    socket.create_connection(('127.0.0.1', int(sys.argv[1])), timeout=0.5)
except OSError:
    sys.exit(1)
PY
}
port_listener() { lsof -nP -iTCP:"$1" -sTCP:LISTEN -Fc 2>/dev/null | sed -n 's/^c//p' | head -1; }
SERVER_RUNNING=0
for probe in 7000 7001; do
  if probe_port "$probe"; then
    lname="$(port_listener "$probe" || true)"
    case "$lname" in
      *dotnet*|*Dotnet*|*ServerCore*|*servercore*)
        SERVER_RUNNING=1
        echo "[!] 提示：服务端正在运行（端口 $probe，进程 ${lname}）。将同步磁盘数据库，新数据在下一次重启服务端后生效。"
        break ;;
      *)
        echo "[1/7] 端口 $probe 被 ${lname:-其它进程} 占用（非服务端，忽略）" ;;
    esac
  fi
done
[ "$SERVER_RUNNING" = 1 ] || echo "[1/7] 端口检测通过（未发现服务端监听）"

# ---------- 2) 导入器：校验 + 写临时副本 ----------
build_retry "$DBEDITOR/importer/DBImporter.csproj"
rm -f "$REPORT.importer"
IMPORTER_EXTRA=()
if [ "$SERVER_RUNNING" = 1 ]; then :; else IMPORTER_EXTRA+=(--no-port-check); fi
dotnet run --project "$DBEDITOR/importer" --no-build -- \
  --workspace "$WS" --src "$SERVER_DB" --report "$REPORT.importer" ${IMPORTER_EXTRA[@]+"${IMPORTER_EXTRA[@]}"}
echo "[2/7] 导入器执行完成"
if grep -q "NO_CHANGES=1" "$REPORT.importer"; then
  echo "[=] 工作区无改动，什么都不做。"
  rm -f "$REPORT.importer"
  exit 0
fi
DB_OUT="$(sed -n 's/^DB_OUT=//p' "$REPORT.importer" | tail -1)"
[ -n "$DB_OUT" ] || { echo "[X] 导入器未产出数据库"; exit 11; }

# ---------- 3) probe 重导出写出的库 ----------
build_retry "$REPO/Tools/SystemDbProbe/SystemDbProbe.csproj"
RT_DIR="$(mktemp -d /tmp/dbeditor_rt.XXXXXX)"
trap 'rm -rf "$RT_DIR"' EXIT
cp "$DB_OUT" "$RT_DIR/System.db"
dotnet run --project "$REPO/Tools/SystemDbProbe" --no-build -- \
  --json "$RT_DIR/out/" "$RT_DIR/" >/dev/null
echo "[3/7] round-trip 导出完成"

# ---------- 4) 语义对比 ----------
python3 "$DBEDITOR/compare_sync.py" "$WS" "$RT_DIR/out" "$REPORT.importer"
echo "[4/7] round-trip 语义对比通过"

# ---------- 5) 备份全部副本 ----------
STAMP="$(date '+%Y-%m-%d %H-%M')"
mkdir -p "$BACKUP_DIR"
bi=0
for p in "${DB_COPIES[@]}"; do
  bi=$((bi+1))
  gzip -c "$p" > "$BACKUP_DIR/System-copy${bi} $STAMP.db.gz"
done
echo "[5/7] 已备份 ${#DB_COPIES[@]} 份副本 → $BACKUP_DIR/System-copy* $STAMP.db.gz"

# ---------- 6) 安装：写入全部实体副本（软链保持完好） ----------
OLD_MD5="$(md5of "${DB_COPIES[0]}")"
for p in "${DB_COPIES[@]}"; do install -m 0644 "$DB_OUT" "$p"; done
NEW_MD5="$(md5of "${DB_COPIES[0]}")"
echo "[6/7] 已安装 ${#DB_COPIES[@]} 份库：$OLD_MD5 → $NEW_MD5"
for p in "${DB_COPIES[@]}"; do echo "[6/7]   $(md5of "$p")  $p"; done

# ---------- 7) 重置基线（工作区 = 新库状态） ----------
for f in "$WS"/*.json; do
  case "$(basename "$f")" in baseline.json|meta.json|state.json) continue;; esac
  cp "$f" "$WS/_baseline/$(basename "$f")"
done
NEWVER="$(sed -n 's/^\[\*\] 新版本: //p' "$REPORT.importer" | tail -1)"
python3 -c "
import hashlib, json, time
from pathlib import Path
ws = Path('$WS')
def md5(p):
    return hashlib.md5(p.read_bytes()).hexdigest()
b = json.loads((ws / 'baseline.json').read_text(encoding='utf-8'))
b.update({
    'version': '$NEWVER',
    'server_md5': md5(Path('$SERVER_DB')),
    'client_md5': md5(Path('$CLIENT_DB')),
    'rebased_at': time.strftime('%Y-%m-%d %H:%M:%S'),
})
(ws / 'baseline.json').write_text(json.dumps(b, ensure_ascii=False, indent=2), encoding='utf-8')
"
echo "[7/7] 基线已重置（版本 $NEWVER，下次 diff 从新库算起）"
rm -f "$REPORT.importer"
echo "同步成功：$OLD_MD5 → $NEW_MD5"
}

main 2>&1 | tee "$REPORT"
if grep -q "同步成功" "$REPORT"; then
  exit 0
fi
exit 1
