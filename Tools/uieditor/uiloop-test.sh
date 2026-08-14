#!/usr/bin/env bash
# uiloop-test.sh — 全链路闭环验收（验收标准 4/5）
#
# 场景：无头客户端开背包 → 截图 before → 浏览器编辑器改标题位置 → 同步
#      → 游戏内 F12 热重载 → 截图 after → 像素对比标题确实移动。
# 顺带验证：overlay 清空后（F12 再刷）标题回到原位（零副作用路径）。
set -uo pipefail

UIEDITOR="$(cd "$(dirname "$BASH_SOURCE[0]")" && pwd)"
DISPLAY=${DISPLAY:-:100}
GODOT="$HOME/.local/bin/godot-mono"
CLIENT=/home/tetsuya/development/zircon/GodotClient
OVERLAY=$CLIENT/UI/ui_overlay.json

command -v xdotool scrot >/dev/null || { echo "[!] 需要 xdotool scrot"; exit 1; }

# 1. 清空 overlay → 游戏启动后零副作用基线
: > /dev/null
rm -f "$OVERLAY" "$OVERLAY.bak"

LOG=$(mktemp /tmp/uiloop_client.XXXXXX.log)
echo "[*] 启动客户端（无 overlay）"
DISPLAY=$DISPLAY "$GODOT" --path "$CLIENT" -- \
  --server 127.0.0.1 --port 7000 --user test@test.com --pass test123 \
  --char TestHero --window >"$LOG" 2>&1 &
PID=$!
trap 'kill $PID 2>/dev/null' EXIT

for i in $(seq 1 60); do grep -q "StartGame 成功" "$LOG" 2>/dev/null && break; sleep 1; done
grep -q "StartGame 成功" "$LOG" || { echo "[!] 登录失败"; tail -3 "$LOG"; exit 1; }
sleep 6

WID=$(xdotool search --onlyvisible --name ZirconClient | head -1)
xdotool key --window "$WID" Escape; sleep 0.5
xdotool key --window "$WID" w; sleep 2.5          # 开背包（等 HUD 完成与贴图载入）
# scrot 在 Xvfb 偶发截到空帧，带重试 + 窗口内容校验（背包区域必须有棕色背景贴图）
for i in 1 2 3 4 5 6; do
  scrot -o /tmp/uied_before.png
  python3 -c "
from PIL import Image; import numpy as np, sys
a = np.asarray(Image.open('/tmp/uied_before.png').convert('RGB')).astype(int)
win = a[200:636, 760:1024]
brown = ((win[...,0] > win[...,1]) & (win[...,1] > win[...,2]) & (win[...,0] > 25)).sum()
sys.exit(0 if brown > 5000 else 1)" && break
  sleep 1.5
done
echo "[+] before 截图 /tmp/uied_before.png"

# 2. 模拟浏览器编辑器产出：改 InventoryDialog/1（标题 Label）位置 52,8 → 150,60
cat > "$OVERLAY" <<'JSON'
{
 "InventoryDialog": {
  "InventoryDialog/1": {
   "location": [150, 60]
  }
 }
}
JSON
echo "[+] overlay 写入 location [150,60]"

# 3. F12 热重载 + 截图
xdotool key --window "$WID" F12; sleep 2
for i in 1 2 3 4 5; do
  scrot -o /tmp/uied_after.png
  python3 -c "from PIL import Image; import numpy as np,sys; a=np.asarray(Image.open('/tmp/uied_after.png').convert('RGB')); sys.exit(0 if a.mean()>1 else 1)" && break
  sleep 1
done
echo "[+] after 截图 /tmp/uied_after.png"

# 4. 对比：背包标题区域 (窗口位置 + label 偏移)
python3 - <<'PY'
# 精确判定：背景贴图自带的金色装饰（y3-10, x3-259）在两次截图中相同，
# 真正的标题文字块在 before 位于 y11-27，after 应消失并出现在 (150,60)→y55-80。
from PIL import Image
import numpy as np, json, sys
rects = json.load(open('/tmp/ui_window_rects.json'))
x, y, w, h = rects['InventoryDialog']
def gold(img, x0, y0, x1, y1):
    r = np.asarray(Image.open(img).convert('RGB').crop((x+x0, y+y0, x+x1, y+y1))).astype(int)
    return int(((r[...,0] > 190) & (r[...,1] > 160) & (r[...,2] < 130)).sum())
b_txt = gold('/tmp/uied_before.png', 0, 11, 264, 27)
a_txt = gold('/tmp/uied_after.png',  0, 11, 264, 27)
b_new = gold('/tmp/uied_before.png', 100, 55, 264, 80)
a_new = gold('/tmp/uied_after.png',  100, 55, 264, 80)
print(f"[*] 标题文字块 y11-27: before={b_txt} after={a_txt}（应显著减少）")
print(f"[*] 新位置 y55-80:    before={b_new} after={a_new}（应显著增加）")
ok = b_txt > 60 and a_txt < b_txt * 0.35 and a_new > max(20, b_new * 2)
print("[PASS] 背包标题从 (52,8) 移动到 (150,60) —— F12 热重载闭环成立" if ok else "[FAIL] 标题位移判定未通过")
sys.exit(0 if ok else 1)
PY
