"""mapedit — Mir3 地图查看/编辑器内核包（原 mapviewer.py 5612 行拆分而来）。

模块布局（E1 拆模块，行为不变，2026-08-15）：
  constants — 常量/路径/KR_ORDER 库名映射
  mapio     — .map 二进制解析（MapCell/parse_map/MapCache）
  frames    — WIL/ZL 图库帧池（FramePool）
  geom      — rect/iso 投影几何与缩放梯子
  render    — 瓦片/全图渲染 + 进程池并行解码
  minimap   — 游戏小地图库（MiniMap.Zl / FMMap/MMap.wil）
  templates — 前端 HTML（主界面/sim）
  data      — 数据装载（扫描/catalog/连接/workspace/atlas/Envir）
  api       — HTTP 服务（ViewerHandler 端点 + 进度状态）
  prewarm   — 后台预渲染守护线程

兼容层：`import mapviewer`（Tools/maps/mapviewer.py）继续暴露全部历史名字；
本包自身 import 时把 Tools/maps 塞进 sys.path，以便 wilsdk/zlsdk/mapnames
等平铺模块可导入（与拆分前行为一致）。
"""
import os
import sys

_HERE = os.path.dirname(os.path.abspath(__file__))
_PARENT = os.path.dirname(_HERE)
if _PARENT not in sys.path:
    sys.path.insert(0, _PARENT)
