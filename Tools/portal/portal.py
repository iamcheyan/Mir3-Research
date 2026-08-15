#!/usr/bin/env python3
"""Mir3 工具门户与健康检查（Phase 1，Goal §3.3 / WIL-P0-02）

用法：
    python3 Tools/portal/portal.py            # 默认 0.0.0.0:8840
    python3 Tools/portal/portal.py --port 8850

职责：
  - 列出五个工具（dbeditor/dbviewer/mapviewer/wilviewer/uieditor）的健康状态、
    端口、只读/可写、移动端支持等级；
  - 服务未启动时展示可执行的启动命令（手机用户不再只看到连接拒绝）；
  - 服务已启动时附加数据源概要（wilviewer 库/帧数、mapviewer 地图数）。

纯标准库，无第三方依赖。健康检查在服务端做 TCP 探测 + 本机 HTTP 探针，
避免浏览器跨域 fetch 无法区分“未启动”与“CORS 拒绝”。
"""
from __future__ import annotations

import argparse
import json
import socket
import sys
import urllib.request
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from pathlib import Path

WEBUI_DIR = Path(__file__).resolve().parents[1] / "common" / "webui"
HOST = "127.0.0.1"

# 门户注册表：port/name/desc/ro(只读)/mob(移动端等级)/start(启动命令)
# mob 值对应 mobile-shell.css 的 wu-badge 徽标类。
TOOLS = [
    {
        "id": "dbviewer", "name": "dbviewer 数据浏览器", "port": 8800,
        "desc": "System.db 只读浏览（分类树/关联跳转）",
        "ro": True, "mob": "mobile-ok", "mobLabel": "✅ 已适配",
        "start": "bash Tools/dbviewer/export.sh && python3 Tools/dbviewer/dbviewer.py --data /tmp/dbviewer_data --port 8800",
    },
    {
        "id": "dbeditor", "name": "dbeditor 数据编辑器", "port": 8810,
        "desc": "System.db 工作区编辑 + 显式同步（写库须停服）",
        "ro": False, "mob": "mobile-part", "mobLabel": "⚠️ 部分",
        "start": "cd Tools/dbeditor && ./run.sh",
    },
    {
        "id": "uieditor", "name": "uieditor UI 编辑器", "port": 8820,
        "desc": "Godot 客户端 UI 所见即所得编辑",
        "ro": False, "mob": "mobile-part", "mobLabel": "⚠️ 部分",
        "start": "cd Tools/uieditor && ./run.sh",
    },
    {
        "id": "wilviewer", "name": "wilviewer 图库浏览器", "port": 8765,
        "desc": ".WIL/.Zl 图库帧预览 / 动画 / 导出",
        "ro": True, "mob": "mobile-ok", "mobLabel": "✅ 已适配",
        "start": "mir3-venv/bin/python Tools/web/wilviewer.py --root $MIR3_EI_ROOT --port 8765",

    },
    {
        "id": "mapviewer", "name": "mapviewer 地图浏览器", "port": 8899,
        "desc": "627 张地图瓦片渲染 / 任务叠加 / 连通图谱",
        "ro": True, "mob": "mobile-ok", "mobLabel": "✅ 已适配",
        "start": "mir3-venv/bin/python Tools/maps/mapviewer.py <Map目录> --data <Data目录> --port 8899",
    },
]


def tcp_up(port: int, timeout: float = 0.8) -> bool:
    try:
        with socket.create_connection((HOST, port), timeout=timeout):
            return True
    except OSError:
        return False


def http_json(url: str, timeout: float = 8.0):
    try:
        with urllib.request.urlopen(url, timeout=timeout) as r:
            return json.loads(r.read().decode("utf-8"))
    except Exception:
        return None


def probe_detail(tool: dict) -> str:
    """服务已启动时的数据源概要（失败不影响健康状态）。"""
    tid, port = tool["id"], tool["port"]
    try:
        if tid == "wilviewer":
            d = http_json(f"http://{HOST}:{port}/api/files")
            if d and "libs" in d:
                libs = d["libs"]
                frames = sum(l.get("count", 0) for l in libs)
                sounds = len(d.get("sounds", []))
                return f"{len(libs)} 库 · {frames} 帧 · {sounds} 音效"
        elif tid == "mapviewer":
            d = http_json(f"http://{HOST}:{port}/api/maps")
            if isinstance(d, list):
                return f"{len(d)} 张地图"
            if d and isinstance(d.get("maps"), list):
                return f"{len(d['maps'])} 张地图"
        elif tid == "dbviewer":
            d = http_json(f"http://{HOST}:{port}/api/stats")
            if isinstance(d, list) and d:
                total = sum(x.get("count", 0) for x in d if isinstance(x, dict))
                return f"{len(d)} 个分类 · {total} 行"
    except Exception:
        pass
    return ""


def display_host(fallback: str | None = None) -> str:
    """浏览器可见主机名: 取请求 Host 头, 缺省回退本机局域网 IP (本机探测 HOST 仍为 127.0.0.1)。"""
    if fallback:
        return fallback.rsplit(":", 1)[0] or HOST
    try:
        with socket.socket(socket.AF_INET, socket.SOCK_DGRAM) as s:
            s.connect(("10.255.255.255", 1))
            return s.getsockname()[0]
    except OSError:
        return HOST


def health_payload(host: str | None = None) -> dict:
    shown = display_host(host)
    tools = []
    for t in TOOLS:
        up = tcp_up(t["port"])
        entry = {
            "id": t["id"], "name": t["name"], "port": t["port"],
            "url": f"http://{shown}:{t['port']}/", "up": up,
            "ro": t["ro"], "desc": t["desc"],
            "mob": t["mob"], "mobLabel": t["mobLabel"], "start": t["start"],
        }
        if up:
            entry["detail"] = probe_detail(t)
        tools.append(entry)
    return {"ok": True, "host": shown, "tools": tools}


PAGE_HTML = r"""<!DOCTYPE html>
<html lang="zh-CN">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1, viewport-fit=cover">
<title>Mir3 工具门户</title>
<link rel="stylesheet" href="/_webui/tokens.css">
<link rel="stylesheet" href="/_webui/mobile-shell.css">
<style>
  :root { --wu-bg:#101318; --wu-panel:#1a1f27; --wu-line:#2d3540; }
  body { background:var(--wu-bg); color:var(--wu-fg,#d7dde6);
         font:14px/1.5 "PingFang SC","Microsoft YaHei",sans-serif;
         margin:0; min-height:100dvh; padding:calc(14px + var(--safe-top)) 14px calc(20px + var(--safe-bottom)); }
  header { max-width:1080px; margin:0 auto 14px; display:flex; align-items:baseline; gap:12px; flex-wrap:wrap; }
  header h1 { font-size:20px; color:var(--wu-acc,#e8a33d); margin:0; }
  header .sub { color:var(--wu-dim,#8b95a3); font-size:12px; }
  #refresh { margin-left:auto; padding:6px 12px; background:var(--wu-panel);
             border:1px solid var(--wu-line); color:var(--wu-fg,#d7dde6);
             border-radius:6px; cursor:pointer; }
  #recent { max-width:1080px; margin:0 auto 10px; color:var(--wu-dim,#8b95a3); font-size:12px; }
  #recent a { color:#8cf; text-decoration:none; margin-right:10px; }
  #tools { max-width:1080px; margin:0 auto; display:grid; gap:12px;
           grid-template-columns:repeat(auto-fill, minmax(300px, 1fr)); }
  .tool-card { display:flex; flex-direction:column; gap:8px; }
  .tool-card.down { opacity:.85; border-style:dashed; }
  .tool-head { display:flex; align-items:center; gap:8px; flex-wrap:wrap; }
  .tool-head b { font-size:15px; }
  .tool-desc { color:var(--wu-dim,#8b95a3); font-size:12.5px; }
  .wu-card-open { color:var(--wu-ok,#3de88a); text-decoration:none; font-size:13px; }
  .wu-card-hint { font-size:12px; color:var(--wu-warn,#ffcf70); word-break:break-all; }
  .wu-card-hint code { background:#0d1014; border:1px solid var(--wu-line);
                       border-radius:4px; padding:2px 6px; font-size:11px;
                       user-select:all; cursor:pointer; }
  #stamp { max-width:1080px; margin:12px auto 0; color:var(--wu-dim,#8b95a3); font-size:11px; text-align:right; }
  @media (max-width:480px) {
    #tools { grid-template-columns:1fr; }
  }
</style>
</head>
<body class="wu-shell">
  <header>
    <h1>Mir3 工具门户</h1>
    <span class="sub">健康检查 · 数据源 · 只读/可写 · 移动端等级</span>
    <button id="refresh" type="button">↻ 刷新</button>
  </header>
  <div id="recent"></div>
  <div id="tools"><div class="tool-card wu-card">检查中…</div></div>
  <div id="stamp"></div>
<script src="/_webui/portal.js"></script>
<script>
  async function refresh() {
    const box = document.getElementById("tools");
    try {
      const d = await (await fetch("/api/health")).json();
      WU.portal.renderHealth(box, d);
      document.getElementById("stamp").textContent =
        "检测时间 " + new Date().toLocaleTimeString("zh-CN", {hour12:false});
    } catch (e) {
      box.innerHTML = '<div class="wu-card tool-card">门户 API 不可用：' + e.message + '</div>';
    }
    const rec = document.getElementById("recent");
    const list = WU.portal.recent();
    rec.innerHTML = list.length
      ? "最近使用：" + list.map(v => `<a href="${v.url}" target="_blank" rel="noopener">${v.name}</a>`).join("")
      : "";
  }
  document.getElementById("refresh").addEventListener("click", refresh);
  refresh();
  setInterval(refresh, 30000);
</script>
</body>
</html>
"""

CTYPES = {
    ".css": "text/css; charset=utf-8",
    ".js": "application/javascript; charset=utf-8",
    ".html": "text/html; charset=utf-8",
    ".json": "application/json; charset=utf-8",
}


class PortalHandler(BaseHTTPRequestHandler):
    server_version = "Mir3Portal/1.0"

    def log_message(self, fmt, *args):
        pass  # quiet

    def _send(self, data: bytes, ctype: str, status: int = 200):
        try:
            self.send_response(status)
            self.send_header("Content-Type", ctype)
            self.send_header("Content-Length", str(len(data)))
            self.send_header("Cache-Control", "no-cache")
            self.end_headers()
            self.wfile.write(data)
        except (BrokenPipeError, ConnectionResetError):
            pass

    def do_GET(self):  # noqa: N802
        path = self.path.split("?", 1)[0]
        if path == "/":
            self._send(PAGE_HTML.encode("utf-8"), "text/html; charset=utf-8")
            return
        if path == "/api/health":
            req_host = (self.headers.get("Host") or "").rsplit(":", 1)[0] or None
            self._send(json.dumps(health_payload(req_host), ensure_ascii=False).encode("utf-8"),
                       "application/json; charset=utf-8")
            return
        if path.startswith("/_webui/"):
            name = path[len("/_webui/"):]
            if "/" in name or ".." in name or not name:
                self._send(b"forbidden", "text/plain", 403)
                return
            f = WEBUI_DIR / name
            if not f.is_file():
                self._send(b"not found", "text/plain", 404)
                return
            ctype = CTYPES.get(f.suffix, "application/octet-stream")
            self._send(f.read_bytes(), ctype)
            return
        self._send(b"not found", "text/plain", 404)


def main():
    ap = argparse.ArgumentParser(description="Mir3 tools portal & health check")
    ap.add_argument("--host", default="0.0.0.0")
    ap.add_argument("--port", type=int, default=8840)
    args = ap.parse_args()

    srv = ThreadingHTTPServer((args.host, args.port), PortalHandler)
    print(f"[portal] serving on http://127.0.0.1:{args.port}/ (Ctrl-C to stop)")
    try:
        srv.serve_forever()
    except KeyboardInterrupt:
        pass


if __name__ == "__main__":
    sys.exit(main())
