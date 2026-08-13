#!/usr/bin/env bash
# omd_decision_watch.sh — OMD goal 决策回传
# 监控 DECISIONS_PENDING.md：出现 WAITING 决策且内容变化时，打印摘要（cron/watchdog 可投递）。
# 用法：bash omd_decision_watch.sh
set -euo pipefail
FILE="/home/tetsuya/development/oh-my-desktop/docs/reviews/DECISIONS_PENDING.md"
STATE="/home/tetsuya/.omp/omd-decisions.state"
mkdir -p "$(dirname "$STATE")"

if [[ ! -f "$FILE" ]]; then
  exit 0
fi

# 仅当有 WAITING 时才可能报警
if ! grep -q '状态：WAITING\|\*\*状态\*\*：WAITING\|status: WAITING' "$FILE" 2>/dev/null; then
  exit 0
fi

hash=$(md5sum "$FILE" | awk '{print $1}')
prev=""
[[ -f "$STATE" ]] && prev=$(cat "$STATE")
if [[ "$hash" == "$prev" ]]; then
  exit 0  # 无变化
fi
echo "$hash" > "$STATE"

echo "【需要决策】OMD goal 有待拍板项（docs/reviews/DECISIONS_PENDING.md）"
echo "----"
# 抽出 WAITING 块标题
awk '
  /^## DEC-/ { title=$0; block=1; waiting=0; buf=$0"\n"; next }
  block && /WAITING/ { waiting=1 }
  block { buf=buf $0 "\n" }
  block && /^## DEC-/ && NR>1 { }
  /^## DEC-/ && waiting { print title; waiting=0 }
  END { if (waiting) print title }
' "$FILE" 2>/dev/null || true
grep -n 'WAITING\|## DEC-' "$FILE" | head -40
echo "----"
echo "请回复例如：DEC-001 选 A"
