# uieditor — Zircon UI 所见即所得 Web 编辑器（:8820）

浏览器里 1:1 还原 Godot 客户端全部 UI 窗口（46 个 DXWindow），拖拽调整
位置/大小/文字/颜色，保存为 JSON overlay；游戏内按 **F12**（或聊天输入
`@uiReload`）热重载——**零重启迭代**。

## 架构

```
[GodotClient --ui-export] → UI/ui_tree.json（46 窗口控件树，1024x768 逻辑坐标）
        ↓
[uieditor :8820] 画布渲染（贴图 /zl/{lib}/{frame}.png 实时解码，zlsdk）
        ↓ 「同步」按钮（原子写 + .bak 备份）
[GodotClient/UI/ui_overlay.json] ← 只存 diff（未改控件不进 overlay）
        ↓ 游戏内 F12 / @uiReload
[UiOverlay.cs] 按 path（子索引链）应用视觉覆盖
```

## 启动

```bash
./run.sh          # uv venv + FastAPI :8820
```

数据源需要先在 zircon 仓库导出（客户端代码变更后重跑一次）：

```bash
cd /home/tetsuya/development/zircon
godot-mono --path GodotClient res://Scenes/UITestScene.tscn -- --ui-export
# 产出 GodotClient/UI/ui_tree.json（46 窗口 / ~2400 控件 / 图库 manifest）
```

## 编辑器功能

- 左侧窗口列表（类名+中文名过滤）｜中间 1024x768 画布（0.5x/1x/2x）
  ｜右侧控件树 + 属性面板（与 UiOverlay.cs 开放同一属性集）
- 点选、框选、拖拽移动、8 向手柄缩放、方向键微调（1px，Shift=10px）
- 2px 网格吸附 / 控件边缘吸附（开关）
- Undo/Redo（Ctrl+Z / Ctrl+Y），Ctrl+S 同步
- 截图 underlay（半透明真实游戏截图垫底，所见即所得对位）
- 移动端 390px 浏览模式（右栏收起，0.5x 画布）

## 红线

- overlay 只改视觉属性（location/size/text/fontSize/visible/颜色），
  **永不动逻辑/事件绑定**
- 坐标一律逻辑画布 1024x768 基准（UiScaler 缩放前的值）

## 辅助脚本

- `uishot.sh [窗口名...]` — 无头客户端（Xvfb :100）逐窗口截图到 `shots/`，
  作为编辑器 underlay（覆盖背包/角色/技能/行会/大地图/聊天/任务/设置等）
- `uiloop-test.sh` — 全链路闭环验收：无 overlay 基线 → 写 overlay →
  F12 → 像素级验证标题移动（/tmp/uied_before.png、/tmp/uied_after.png）

## 游戏端改动（zircon 仓库）

| 文件 | 作用 |
|---|---|
| `GodotClient/Scripts/UiTreeExporter.cs` | `--ui-export` 导出器 |
| `GodotClient/Controls/UiOverlay.cs` | overlay 加载/按 path 应用/热重载 |
| `DXWindow.cs` | `_Ready` 尾部 deferred 应用 overlay |
| `GameScene.cs` | 启动 Load、CreateHud 后 ApplyAll、F12 热重载 + 截图 + 窗口矩形导出、`@uiReload` 拦截 |

端口约定：8810 dbeditor / 8899 mapviewer / 8765 wilviewer / **8820 uieditor**。
