#!/usr/bin/env bash
# uishot.sh — 无头客户端逐窗口截图（uieditor 截图 underlay 生成器）
#
# 用法: ./uishot.sh [窗口类名 ...]   缺省截 8 个高频窗口
# 产出: shots/{类名}.png（整屏 1024x768）+ /tmp/ui_window_rects.json（窗口矩形）
# 原理: Xvfb :100 上跑客户端自动登录 → xdotool 发键开窗口 → scrot 截屏
set -uo pipefail

UIEDITOR="$(cd "$(dirname "$BASH_SOURCE[0]")" && pwd)"
SHOTS="$UIEDITOR/shots"
mkdir -p "$SHOTS"

DISPLAY=${DISPLAY:-:100}
GODOT="$HOME/.local/bin/godot-mono"
CLIENT=/home/tetsuya/development/zircon/GodotClient

# 窗口 → 开窗键（KeyBindManager 默认映射）
declare -A WINKEY=(
  [InventoryDialog]=w
  [CharacterDialog]=q
  [MagicDialog]=e
  [GuildDialog]=g
  [BigMapDialog]=b
  [ChatOptionsDialog]=ctrl+o
  [QuestDialog]=k
  [ConfigDialog]=o
  [BeltDialog]=z
  [DungeonFinderDialog]=j
  [CompanionDialog]=u
  [RankingDialog]=r
  [GroupDialog]=p
  [CommunicationDialog]=comma
  [HelpDialog]=h
  [MenuDialog]=n
  [FortuneCheckerDialog]=ctrl+r
  [CurrencyDialog]=ctrl+c
)
ORDER=(InventoryDialog CharacterDialog MagicDialog GuildDialog BigMapDialog
       ChatOptionsDialog QuestDialog ConfigDialog)

WINS=("$@")
[ ${#WINS[@]} -eq 0 ] && WINS=("${ORDER[@]}")

command -v xdotool >/dev/null || { echo "[!] 需要 xdotool"; exit 1; }
command -v scrot >/dev/null || { echo "[!] 需要 scrot"; exit 1; }

LOG=$(mktemp /tmp/uishot_client.XXXXXX.log)
echo "[*] 启动无头客户端 ($DISPLAY)，日志 $LOG"
DISPLAY=$DISPLAY "$GODOT" --path "$CLIENT" -- \
  --server 127.0.0.1 --port 7000 --user test@test.com --pass test123 \
  --char TestHero --window >"$LOG" 2>&1 &
CLIENT_PID=$!
trap 'kill $CLIENT_PID 2>/dev/null' EXIT

# 等进入游戏
for i in $(seq 1 60); do
  if grep -q "StartGame 成功" "$LOG" 2>/dev/null; then break; fi
  sleep 1
done
if ! grep -q "StartGame 成功" "$LOG"; then
  echo "[!] 登录超时，日志尾:"; tail -5 "$LOG"; exit 1
fi
sleep 6   # 等地图/HUD 稳定

WID=$(xdotool search --onlyvisible --name ZirconClient 2>/dev/null | head -1)
if [ -z "$WID" ]; then
  WID=$(xdotool getactivewindow 2>/dev/null)
fi
echo "[*] 窗口 id=$WID"

ok=0
for win in "${WINS[@]}"; do
  key=${WINKEY[$win]:-}
  if [ -z "$key" ]; then echo "[!] 无键位映射: $win，跳过"; continue; fi
  # 关掉已开窗口，回到干净基线
  xdotool key --window "$WID" Escape >/dev/null 2>&1
  sleep 0.6
  xdotool key --window "$WID" "$key" >/dev/null 2>&1
  sleep 1.4
  scrot -o "$SHOTS/$win.png" 2>/dev/null || DISPLAY=$DISPLAY scrot -o "$SHOTS/$win.png"
  if [ -s "$SHOTS/$win.png" ]; then
    echo "[+] $win → shots/$win.png ($(stat -c%s "$SHOTS/$win.png")B)"
    ok=$((ok+1))
  else
    echo "[!] $win 截图失败"
  fi
  # F12 顺手导出当前可见窗口矩形（最后一个窗口的矩形表最有价值）
done

# 窗口矩形（对每个窗口单独按 F12 获取 rect 不可行——一次 F12 导出当前全部可见窗口；
# 循环内逐窗口截屏前按 F12 让 /tmp/ui_window_rects.json 同步更新）
echo "[*] 完成 $ok/${#WINS[@]}"
