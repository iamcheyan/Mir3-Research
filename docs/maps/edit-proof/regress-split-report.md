# E1 拆分回归对照报告（2026-08-15）

- 基线: 879a05d 单体 mapviewer.py（干净树 ~/.e1-scratch/basewt，端口 18998）
- 新码: master 拆分后 mapedit 包（端口 18997）
- 采集: regress_capture.py Tier-1 808 图全量 + Tier-2 渲染抽样，3306 entries/侧

## 结果: 3292/3306 字节级一致；14 处差异全部归因，无一为拆分引入:

| 差异 | 归因 | 证据 |
|---|---|---|
| / (1) | E1 编辑 UI 注入（EDIT_UI_JS，预期功能） | 设计如此 |
| /api/{graph,overview,npc_audit,entities} (4) | 两次采集窗口间 E0/dbeditor 写库改 workspace（MapInfo/MapRegion） | workspace 数据同步进基线树后两侧活进程字节级一致 ✓ |
| /api/map_links_v2.json (1) | 仅 _meta.generated 时间戳（服务启动时重生成） | 剔除 _meta 后内容相等 ✓ |
| /thumb ×8 (8) | 两侧同因 --no-prewarm-thumbs 返回 500，错误页含各自 thumbs 目录路径 | 路径归一化后错误页字节级相等 ✓ |

## 同数据活进程 A/B 复核（数据同步后）
/api/graph /api/overview /api/npc_audit /api/entities /api/cell /tile /fullmap 全部 sha256 一致；
渲染端点（/tile 0.map 首瓦片 287915B、/fullmap 3.map z2 5134784B）字节级一致 = 渲染管线行为不变。

结论：mapviewer.py → mapedit/ 包拆分行为中性，达成验收标准。
