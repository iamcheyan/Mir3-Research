#!/usr/bin/env bash
# run.sh — 启动 uieditor（FastAPI :8820，Zircon Godot 客户端 UI 所见即所得编辑器）。
# 数据源：zircon/GodotClient/UI/ui_tree.json（--ui-export 产出）。
set -euo pipefail
cd "$(dirname "$BASH_SOURCE[0]")"

if [ ! -x venv/bin/python ]; then
    echo "[*] 创建 venv（uv）..."
    uv venv venv --python 3.13
    uv pip install --python venv/bin/python -r requirements.txt
fi

exec venv/bin/python app.py
