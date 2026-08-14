#!/usr/bin/env bash
# sync.sh —— dbeditor 同步全流程：
#   端口检测 → DBImporter（校验+写临时副本）→ probe 重导出 → 语义对比
#   → 备份双库 → 安装双库 → 重置基线 → 报告落盘 workspace/sync_report.txt
# 任一步失败即中止（原库不动）。绝不直接改原库——先写临时副本验证再原子安装。
set -euo pipefail

DBEDITOR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO="$(cd "$DBEDITOR/../.." && pwd)"
WS="$DBEDITOR/workspace"
ZIRCON="/home/tetsuya/development/zircon"
SERVER_DB="$ZIRCON/Debug/ServerCore/Database/System.db"
CLIENT_DB="$ZIRCON/Debug/Client/Data/System.db"
BACKUP_DIR="$ZIRCON/Debug/ServerCore/Database/Backup/System"
REPORT="$WS/sync_report.txt"

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
if python3 -c "
import socket, sys
try:
    socket.create_connection(('127.0.0.1', 7000), timeout=0.5)
    sys.exit(0)
except OSError:
    sys.exit(1)
"; then
  echo "[X] 服务端正在运行（端口 7000）。停止服务端后再同步。"
  exit 10
fi
echo "[1/7] 端口检测通过（服务端已停止）"

# ---------- 2) 导入器：校验 + 写临时副本 ----------
build_retry "$DBEDITOR/importer/DBImporter.csproj"
rm -f "$REPORT.importer"
dotnet run --project "$DBEDITOR/importer" --no-build -- \
  --workspace "$WS" --src "$SERVER_DB" --report "$REPORT.importer"
echo "[2/7] 导入器执行完成"
if grep -q "NO_CHANGES=1" "$REPORT.importer"; then
  echo "[=] 工作区无改动，什么都不做。"
  rm -f "$REPORT.importer"
  exit 0
fi
DB_OUT="$(grep -oP '(?<=^DB_OUT=).*' "$REPORT.importer" | tail -1)"
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

# ---------- 5) 备份双库 ----------
STAMP="$(date '+%Y-%m-%d %H-%M')"
mkdir -p "$BACKUP_DIR"
gzip -c "$SERVER_DB" > "$BACKUP_DIR/System $STAMP.db.gz"
gzip -c "$CLIENT_DB" > "$BACKUP_DIR/System-client $STAMP.db.gz"
echo "[5/7] 已备份：Backup/System/System $STAMP.db.gz（含客户端副本）"

# ---------- 6) 安装双库 ----------
OLD_MD5="$(md5sum "$SERVER_DB" | cut -d' ' -f1)"
install -m 0644 "$DB_OUT" "$SERVER_DB"
install -m 0644 "$DB_OUT" "$CLIENT_DB"
NEW_MD5="$(md5sum "$SERVER_DB" | cut -d' ' -f1)"
echo "[6/7] 已安装双库：server=$NEW_MD5 client=$(md5sum "$CLIENT_DB" | cut -d' ' -f1)"

# ---------- 7) 重置基线（工作区 = 新库状态） ----------
for f in "$WS"/*.json; do
  case "$(basename "$f")" in baseline.json|meta.json|state.json) continue;; esac
  cp "$f" "$WS/_baseline/$(basename "$f")"
done
NEWVER="$(grep -oP '(?<=^\[\*\] 新版本: ).*' "$REPORT.importer" | tail -1)"
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
