# DBImporter — dbeditor 工作区 → System.db 写回器

dbeditor「缓冲区工作流」的写库端：把 `Tools/dbeditor/workspace/*.json` 的受管表
差异校验后写回服务端 System.db，并复制到客户端 Data/System.db（双写）。

由 `Tools/dbeditor/sync.sh` 调用（dbeditor 后端 `POST /api/sync` → sync.sh → 本程序）。
编辑器本身的「保存」只落 JSON 工作区，绝不直接碰 .db。

## 用法

```bash
# 库信息（版本/md5/行数，JSON 输出）
dotnet run --project Tools/DBImporter -- --mode info

# 只校验不写库（差异汇总 + 引用完整性，报告写 workspace/sync_report.txt）
dotnet run --project Tools/DBImporter -- --mode check

# 全量同步（校验 → 备份 → 写库 → 双写客户端 → round-trip 读回验证）
bash Tools/dbeditor/sync.sh          # 或直接 --mode sync
```

可选参数：`--workspace <dir>`（默认 `Tools/dbeditor/workspace`）、
`--root <服务端Database目录>`（默认真实库）、`--client <客户端System.db路径>`。

## 退出码

| 码 | 含义 |
|---|---|
| 0 | 成功（sync）或校验通过（check） |
| 1 | 校验失败（报告见 `workspace/sync_report.txt`，未写库） |
| 2 | 服务端在跑（7000 端口有监听），拒绝同步 |
| 3 | 参数/其他错误 |

## 同步流程

1. **端口检测**：7000 有监听 → 退出码 2（仅对真实库根生效；/tmp 测试副本不受限，便于在服务端运行期间做 importer 测试）
2. 载入 System.db（`SessionMode.System`，**绝不碰 Users.db**）
3. **阶段A静态校验**：JSON 解析、enum 合法值、数值范围（`editor_config.json` 可配）、图像帧范围、必填引用结构
4. **应用差异**（内存）：删除（`DBObject.Delete()`，Aggregate 关联自动级联）→ 新增（`CreateNewObject()`，Index 与工作区不一致时经内部 setter 矫正）→ 修改（只写差异字段）
5. **阶段B引用完整性**：
   - 受管表 ref 字段目标必须存在（悬空引用 = 拒绝）
   - 反向引用扫描：被删除的记录若仍被任何表（含 QuestReward/NPCGood 等未受管表）引用 → 拒绝
   - 必填引用为空：与基线（`workspace/_baseline/`）对比，**库中原有的历史空引用放行，用户新引入的拒绝**
6. **备份**：`Database/Backup/dbeditor-<时间戳>/System.db` + 客户端 `Backup/dbeditor-<时间戳>/`（另有 MirDB Session 自带的 gzip 备份）
7. `session.Save(true)`：系统数据有变更时 MirDB 自动 bump `SystemDatabaseInfo.Version`（YYYY.MM.DD.N）
8. 服务端库复制到客户端 `Data/System.db`
9. **round-trip**：重新打开库，对全部受管表逐字段读回对比（新增/修改的行字段必须与工作区一致；工作区删除的行必须不存在）

任何一步失败都不写库（round-trip 失败除外——它发生在写库后，报告会给出备份路径用于恢复）。

## 受管表（P0 四类）

`ItemInfo, SetInfo, MonsterInfo, MagicInfo, ItemInfoStat, SetInfoStat, MonsterInfoStat, StoreInfo, RespawnInfo, GuardInfo, DropInfo`

父表在前子表在后（新增行的引用按此顺序解析）。第二期表加进 `workspace/editor_config.json`
的 `Managed` 列表即可，schema 天然按 meta.json 扩展。

## 基线感知校验

原始库本身存在历史脏数据（117 条 ItemInfoStat 孤儿、Image 帧号 >2364 的多图集编址、
Level=0 的 NPC 型怪物、Amount=0 的掉落行等）。校验器以 `workspace/_baseline/` 为参照：

- 数值/帧号范围按**实测数据边界**配置（如 ItemInfo.Image 0..6999，基线最大 6010）
- 历史空引用放行、新引入的空引用拒绝
- 显式悬空引用（指向不存在的 Index）无条件拒绝

## 测试记录（2026-08-13，/tmp/rt_db 副本）

- 修改 StoreInfo#30 Price 200→777：同步成功，版本 2026.08.13.4→5，round-trip 22272 条通过，双库 md5 一致
- 新增 ItemInfo#1168：1078→1079，版本→6，round-trip 通过
- 删除 ItemInfo#1168：1079→1078，版本→7，round-trip 通过
- 悬空引用（DropInfo→MonsterInfo#434000）：阶段A/应用阶段拒绝，报告精确到行字段，退出码 1
- 服务端运行中同步真实库路径：退出码 2 拒绝
