# Mir3 Research

辅助开发、原版客户端逆向研究、资源解码、地图审计、UI 证据和 HTML 模拟器仓库。

本仓库不包含原版客户端、WIL/MAP/DAT 大型资源或 `Debug/`、`Resource/` 运行时目录。资源通过环境变量从 NAS 提供：

```bash
export MIR3_EI_ROOT=/home/tetsuya/NAS/TMP/EI传奇3.0客户端
export MIR3_MUD3_ROOT=/home/tetsuya/NAS/TMP/Mud3
export MIR3_ZIRCON_ROOT=/home/tetsuya/development/Zircon
```

在 82 服务器上，NAS 挂载点是 `/tmp/nas_mnt/NAS`，对应环境变量应改为：

```bash
export MIR3_EI_ROOT=/tmp/nas_mnt/NAS/TMP/EI传奇3.0客户端
export MIR3_MUD3_ROOT=/tmp/nas_mnt/NAS/TMP/Mud3
export MIR3_ZIRCON_ROOT=/home/tetsuya/development/Zircon
```

主要目录：

- `Tools/reverse-engineering/`：EXE、DAT、WIL/WIX 和 UI 证据工具
- `Tools/maps/`：地图解析、渲染、审计和小地图工具
- `Tools/common/`：共享解码库和通用脚本
- `Tools/web/`、`Tools/mir3_client_simulator/`：网页工具和 800×600 模拟器
- `docs/research/`：研究证据、目录和日志
- `docs/handoffs/`：长期任务交接文档

常用验证：

```bash
python3 Tools/reverse-engineering/verify_mir3_ui_evidence.py --client "$MIR3_EI_ROOT"
python3 Tools/reverse-engineering/enrich_mir3_layout_evidence.py
python3 -m compileall -q Tools
```
