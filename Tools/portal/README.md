# portal — Mir3 工具门户与健康检查

- **端口**：8840（`python3 Tools/portal/portal.py`，纯标准库）
- **职责**：五个工具（dbviewer/dbeditor/uieditor/wilviewer/mapviewer）的健康状态、
  数据源概要、只读/可写、移动端支持等级；未启动服务给出可复制的启动命令。
- **共享壳**：静态资源来自 `Tools/common/webui/`（`/_webui/*`）。
- **API**：`GET /api/health` → `{tools:[{id,name,port,url,up,ro,detail,start,...}]}`；
  探针超时 8s，探针失败不影响 up 判定（TCP 探测独立）。
- 依据：`review_goals/TOOLS_MOBILE_ENHANCE_GOAL.md` §3.3。
