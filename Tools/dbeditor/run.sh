#!/usr/bin/env bash
# run.sh — 启动 dbeditor（FastAPI 后端 + 内嵌 Vue 前端，端口 8810）。
#
# 首次启动若工作区为空会自动做基线导出（SystemDbProbe --json，需要 dotnet）。
set -euo pipefail
cd "$(dirname "$BASH_SOURCE[0]")"

if [ ! -x venv/bin/python ]; then
    echo "[*] 创建 venv（uv）..."
    uv venv venv --python 3.13
    uv pip install --python venv/bin/python -r requirements.txt
fi

exec venv/bin/python app.py
