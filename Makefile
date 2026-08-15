# Makefile — 编辑器军团短路目标（总纲 §8.1，Goal E0）
# make / make help 列出全部目标。

PY ?= $(HOME)/mir3-venv/bin/python

.PHONY: help cache serve-mapviewer serve-dbeditor serve-dbviewer serve-webport \
        serve status stop restart-service roundtrip probe

help: ## 显示本说明
	@grep -E '^[a-zA-Z_-]+:.*?## ' $(MAKEFILE_LIST) | awk 'BEGIN{FS=":.*?## "}{printf "  \033[36m%-18s\033[0m %s\n",$$1,$$2}'

cache: ## 一键重建 /tmp 脆弱缓存三件套（Tools/cache/ + /tmp 镜像；完成后重启 mapviewer）
	bash scripts/gen_caches.sh

serve-mapviewer: ## 启动 mapviewer (:8899，会先等就绪)
	bash scripts/services.sh start mapviewer

serve-dbeditor: ## 启动 dbeditor (:8810)
	bash scripts/services.sh start dbeditor

serve-dbviewer: ## 启动 dbviewer (:8800，数据缺失时先自动导出)
	bash scripts/services.sh start dbviewer

serve-webport: ## 启动 webport (:8823)
	bash scripts/services.sh start webport

serve: ## 启动编辑器常用组合（dbeditor+dbviewer+mapviewer+webport）
	bash scripts/services.sh start dbeditor dbviewer mapviewer webport

status: ## 全部服务状态
	bash scripts/services.sh status

stop: ## 停止全部服务（或 make STOP=mapviewer stop）
	bash scripts/services.sh stop $(STOP)

restart-service: ## 重启服务：make S=mapviewer restart-service
	bash scripts/services.sh restart $(S)

roundtrip: ## E1 地图往返验证入口（map_roundtrip.py 落地后可用）
	@test -f Tools/maps/map_roundtrip.py || { echo "[!] E1 的 Tools/maps/map_roundtrip.py 尚未落地"; exit 1; }
	$(PY) Tools/maps/map_roundtrip.py

probe: ## SystemDbProbe 快速统计（当前客户端库）
	dotnet run --project Tools/SystemDbProbe -- $(MIR3_ZIRCON_ROOT)/Debug/Client/Data/

.DEFAULT_GOAL := help
