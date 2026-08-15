#!/usr/bin/env bash
# gen_caches.sh — /tmp 脆弱缓存三件套一键重建（总纲 §3.4 / §8.1，Goal E0）。
#
# 重建：
#   1. minimap_map.txt    2017 ZL 客户端小地图索引（SystemDbProbe --minimap，
#                         ⚠️ 必须用【客户端】System.db，服务端库与 MiniMap.Zl 不配套，见 §3.3）
#   2. minimap_map_ei.txt EI 客户端小地图索引（gen_minimap_ei.py，读 Mud3/Envir/MiniMap.txt）
#   3. map_cn_full.json   地图文件名 -> 中文名（dbeditor workspace MapInfo.json + mapnames 规则）
#   4.（可选 --thumbs）   总览缩略图 wiki_thumbs（thumb_gen.py，慢；mapviewer 启动时后台
#                         prewarm 也会补齐，非必需）
#
# 产物落点：Tools/cache/（入仓库，工具读取优先）+ /tmp/ 镜像（兜底仍硬编码 /tmp 的旧消费者）。
# mapviewer/dbviewer 用 @lru_cache 读这些文件 —— 重建后必须重启对应服务进程！
#
# 用法：
#   bash scripts/gen_caches.sh             # 三件套
#   bash scripts/gen_caches.sh --thumbs    # 三件套 + 总览缩略图（慢）
set -euo pipefail

REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$REPO"

PY="${PYTHON:-$HOME/mir3-venv/bin/python}"
[ -x "$PY" ] || PY=python3

# ---- 数据根目录（env 优先，82 机默认值兜底；见总纲 §9.4） ----
: "${MIR3_ZIRCON_ROOT:=/home/tetsuya/development/zircon}"
: "${MIR3_EI_ROOT:=/data/NAS/TMP/EI传奇3.0客户端}"
: "${MIR3_MUD3_ROOT:=/data/NAS/TMP/Mud3}"
export MIR3_ZIRCON_ROOT MIR3_EI_ROOT MIR3_MUD3_ROOT

CLIENT_DATA="$MIR3_ZIRCON_ROOT/Debug/Client/Data"
EI_MINIMAP_TXT="$MIR3_MUD3_ROOT/Envir/MiniMap.txt"

for d in "$MIR3_ZIRCON_ROOT" "$MIR3_EI_ROOT" "$MIR3_MUD3_ROOT" "$CLIENT_DATA"; do
    [ -e "$d" ] || { echo "[!] 数据源缺失: $d（检查 MIR3_*_ROOT 环境变量）" >&2; exit 1; }
done
[ -f "$EI_MINIMAP_TXT" ] || { echo "[!] 缺 $EI_MINIMAP_TXT" >&2; exit 1; }

mkdir -p Tools/cache /tmp/gen_caches
WORK="$(mktemp -d /tmp/gen_caches/XXXXXX)"
trap 'rm -rf "$WORK"' EXIT

step() { printf '\n[*] %s\n' "$*"; }

# ---- 1. ZL 客户端小地图索引（客户端 System.db 的 MapInfo.MiniMap 字段） ----
step "minimap_map.txt <- SystemDbProbe --minimap (客户端库 $CLIENT_DATA)"
dotnet run --project Tools/SystemDbProbe -- "$CLIENT_DATA" --minimap "$WORK/minimap_map.txt"
[ -s "$WORK/minimap_map.txt" ] || { echo "[!] minimap_map.txt 为空" >&2; exit 1; }
echo "    $(wc -l < "$WORK/minimap_map.txt") 条"

# ---- 2. EI 客户端小地图索引（服务器 Envir/MiniMap.txt + FMMap/MMap.wil 校验） ----
step "minimap_map_ei.txt <- gen_minimap_ei.py (EI: $MIR3_EI_ROOT)"
"$PY" Tools/maps/gen_minimap_ei.py "$EI_MINIMAP_TXT" "$MIR3_EI_ROOT/Map" "$MIR3_EI_ROOT/Data" \
    > "$WORK/minimap_map_ei.txt"
[ -s "$WORK/minimap_map_ei.txt" ] || { echo "[!] minimap_map_ei.txt 为空" >&2; exit 1; }
echo "    $(wc -l < "$WORK/minimap_map_ei.txt") 条"

# ---- 3. 地图中文名表（workspace MapInfo.json + mapnames 规则） ----
step "map_cn_full.json <- workspace MapInfo.json + mapnames.resolve"
"$PY" - "$WORK/map_cn_full.json" <<'PYEOF'
import json, os, sys
sys.path.insert(0, os.path.join("Tools", "maps"))
from mapnames import resolve as map_cn

src = os.path.join("Tools", "dbeditor", "workspace", "MapInfo.json")
payload = json.load(open(src, encoding="utf-8"))
out = {}
for r in payload.get("rows", []):
    fn = r.get("FileName")
    if not fn:
        continue
    cn = map_cn(fn, r.get("Description") or "")
    if cn and cn != fn:
        out[fn] = cn
with open(sys.argv[1], "w", encoding="utf-8") as f:
    json.dump(out, f, ensure_ascii=False)
print(f"    {len(out)} 条 <- {src}")
PYEOF
[ -s "$WORK/map_cn_full.json" ] || { echo "[!] map_cn_full.json 为空" >&2; exit 1; }

# ---- 发布：Tools/cache/（主）+ /tmp/（镜像兜底） ----
step "发布缓存文件"
for f in minimap_map.txt minimap_map_ei.txt map_cn_full.json; do
    install -m 644 "$WORK/$f" "Tools/cache/$f"
    install -m 644 "$WORK/$f" "/tmp/$f"
    echo "    Tools/cache/$f + /tmp/$f  ($(wc -c < "Tools/cache/$f") bytes)"
done

# ---- 4. 总览缩略图（可选，慢；mapviewer 后台 prewarm 可自愈） ----
if [ "${1:-}" = "--thumbs" ]; then
    step "wiki_thumbs <- thumb_gen.py（全量渲染，慢）"
    exec "$PY" Tools/maps/thumb_gen.py \
        --maps "$MIR3_ZIRCON_ROOT/Debug/Client/Map" \
        --data "$MIR3_ZIRCON_ROOT/Debug/Client/Data"
fi

cat <<'EOF'

[✓] 缓存重建完成。注意：
    - mapviewer/dbviewer 用 @lru_cache 读这些文件 → 必须【重启进程】才生效
      （services.sh restart mapviewer / make serve-mapviewer）
    - Tools/cache/ 已入仓库跟踪，git diff 可审阅内容变化
EOF
