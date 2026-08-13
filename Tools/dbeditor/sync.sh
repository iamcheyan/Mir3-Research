#!/usr/bin/env bash
# sync.sh — dbeditor 工作区 JSON → System.db 同步入口。
#
# 由 dbeditor 后端 /api/sync 调用（cwd=Mir3-Research 仓库根），也可手动执行:
#   bash Tools/dbeditor/sync.sh
#
# 流程（详见 Tools/DBImporter/Program.cs）:
#   1. 端口检测: 7000 有监听 → 拒绝（退出码 2）
#   2. DBImporter --mode sync:
#      阶段A静态校验 → 应用差异 → 阶段B引用完整性校验
#      → 备份双库（Database/Backup/dbeditor-<时间戳>/ + 客户端 Backup/）
#      → 写服务端库（SystemDatabaseInfo.Version 自动 bump）→ 复制到客户端库
#      → round-trip 重新开库逐字段读回验证
#   3. 校验报告: workspace/sync_report.txt
#
# 退出码: 0=成功  1=校验失败  2=服务端在跑  3=其他错误
set -euo pipefail

HERE="$(cd "$(dirname "$BASH_SOURCE[0]")" && pwd -P)"     # Tools/dbeditor
REPO="$(cd "$HERE/../.." && pwd -P)"                       # Mir3-Research
WS="$HERE/workspace"

echo "[sync.sh] 构建 DBImporter..."
dotnet build "$HERE/../DBImporter/DBImporter.csproj" -v q -m:2

echo "[sync.sh] 执行同步（workspace=$WS）..."
dotnet "$HERE/../DBImporter/bin/Debug/net10.0/DBImporter.dll" \
    --mode sync --workspace "$WS"
