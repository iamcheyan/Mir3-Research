# C7 编辑闭环验收（E5 终态交付）

日期: 2026-08-16 · 全链路浏览器实测 (headless Chromium + CDP)

## 闭环演示: 网页改 FireBall 帧号 → 保存 → 双端可见

1. `/lab` 选中 FireBall → 参数编辑器渲染 4 行（起1 Magic#1820 effect /
   放1-2 Magic#420 projectile / 放3 Magic#580 hitEffect），全字段输入就位。
2. 起手段 `frame: 1820 → 1816` 输入 → **400ms 去抖自动重放**（`S.lastPlay=FireBall`
   确认重放、`table.FireBall.start.effects[0].frame=1816` 确认内存生效）。
3. 点「保存到 ClientData」→ serve.py `POST /lab/save`:
   - 写 `zircon/ClientData/magic-effects.json` original 段（frame:1816）
   - **godot 段自动同步**（`source.startIndex: 1820→1816`，三元组按位映射）
   - `.bak` 备份落盘
   - 重读回显校验 + `gen_cs_table.py --check --skip-runtime` 自检 → **pass**
   - 浏览器状态条: `✓ 已写入 zircon/ClientData/magic-effects.json (自检过, 4 三元组)`
4. `git -C zircon diff` 可见 ClientData/magic-effects.json 变更（frame/startIndex
   双段联动变化）→ **Godot 启动即用新参数**（B 阶段 DataLayer 直读该文件）。
5. 改回 1820 再存 → 自检过、数值还原 → `git checkout` 丢弃残留键序 diff。

## 负向验证

- 空 effects POST → 400「空 effects, 拒绝保存」
- 端点未重启时 → 404（serve.py 是旧进程；services.sh restart 后 400/200 正常）
- 白名单字段清洗：`_SAVE_TOP_KEYS`/`_SAVE_EXTRA_KEYS` 之外字段不落盘；
  三元组数量变化 → 422 拒绝（增删特效不支持，防白名单口径破坏）
- 自检失败自动回滚（代码路径: except → 写回 .bak → rolled_back:true）

## 证据

- 保存成功截图链: 浏览器 evaluate 返回值（本文档步骤 2/3 内嵌）
- zircon 侧 diff 输出（步骤 4，恢复前采集）:
  `ClientData/magic-effects.json | 20 ++++++++--------`（含 original frame 与
  godot startIndex 两处 1820→1816）
