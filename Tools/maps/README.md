# 地图工具

这里负责 `.map` 解析、WIL/ZL 地图资源映射、地图审计、等距渲染、小地图和地图对比。

```bash
# 默认读取当前 Zircon 客户端 Debug/Client/Map + Data/Map Data
python3 Tools/maps/mapviewer.py --port 8766

# 生成一张静态 JPG（坐标仍按游戏 48×32 格计算）
python3 Tools/maps/render_client_map.py 3.map

# 导出当前 System.db 中的地图区域/传送关系
python3 Tools/maps/export_map_connections.py

# 如需查看 EI 资源，仍可显式指定客户端根目录
python3 Tools/maps/mapviewer.py \
  --client-root /home/tetsuya/NAS/TMP/EI传奇3.0客户端 \
  --port 8899
python3 Tools/maps/audit_mir3_maps.py --help
python3 Tools/maps/render_map_comparison.py --help
```

查看器启动后会从 JPG 静态整图工作；鼠标坐标由整图像素按原版
`cell_x = floor(world_x / 48)`、`cell_y = floor(world_y / 32)`反算。默认会加载
`docs/database/data/map-connections.json`，在当前地图上以虚线和端点标出
`MovementInfo` 的出口；端点悬停可看到目标地图、区域和目标区域名称。

地图调查结果写入 `docs/research/mir3-map-reconstruction/`，运行时缓存继续放在被忽略的本地目录。
