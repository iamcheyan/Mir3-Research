#!/usr/bin/env bash
# export.sh — 用 SystemDbProbe --json 把 System.db 导出为 dbviewer 数据目录。
#
# 用法:
#   bash Tools/dbviewer/export.sh                # 导出到 /tmp/dbviewer_data（默认）
#   bash Tools/dbviewer/export.sh /path/outdir   # 指定输出目录
#
# 数据源: 仓库根副本 /home/tetsuya/development/zircon/System.db（只读，不影响运行中的服务器）。
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
OUT="${1:-/tmp/dbviewer_data}"
DB_SRC="${DB_SRC:-/home/tetsuya/development/zircon/System.db}"

# 库副本（probe 只读打开，但用副本最保险）
TMP_ROOT="$(mktemp -d /tmp/dbviewer_src.XXXXXX)"
trap 'rm -rf "$TMP_ROOT"' EXIT
cp "$DB_SRC" "$TMP_ROOT/System.db"

echo "[*] 数据源: $DB_SRC"
echo "[*] 输出目录: $OUT"

dotnet build "$ROOT/Tools/SystemDbProbe/SystemDbProbe.csproj" -v q
mkdir -p "$OUT"
dotnet run --project "$ROOT/Tools/SystemDbProbe" --no-build -- --json "$OUT/" "$TMP_ROOT/"

echo "[*] 导出完成。启动查看器：python3 $ROOT/Tools/dbviewer/dbviewer.py --data $OUT"
