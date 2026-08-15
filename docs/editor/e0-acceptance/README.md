# Goal E0 验收证据 — 编辑器基础设施（2026-08-15）

> 验收标准出处：`docs/editor/EDITOR_GOALS_MASTER.md` §8.2。
> 机器：82（NAS 挂载 `/data/NAS`，zircon `~/development/zircon`）。
> 本 goal 的 commit：`082baa1` → `5c78564` → `6475f77` →（本文件）。

## ✅ 1. `rm -rf /tmp/minimap* /tmp/map_cn*` → `make cache` → 重启 mapviewer，小地图/中文名全恢复

```console
$ rm -rf /tmp/minimap* /tmp/map_cn* /tmp/gen_caches
$ make cache
[*] minimap_map.txt <- SystemDbProbe --minimap (客户端库 …/Debug/Client/Data)
MiniMap 映射 -> …/minimap_map.txt (627 条)
[*] minimap_map_ei.txt <- gen_minimap_ei.py (EI: /data/NAS/TMP/EI传奇3.0客户端)
    200 条
[*] map_cn_full.json <- workspace MapInfo.json + mapnames.resolve
    627 条 <- Tools/dbeditor/workspace/MapInfo.json
[*] 发布缓存文件
    Tools/cache/minimap_map.txt + /tmp/minimap_map.txt  (5439 bytes)
    Tools/cache/minimap_map_ei.txt + /tmp/minimap_map_ei.txt  (3592 bytes)
    Tools/cache/map_cn_full.json + /tmp/map_cn_full.json  (15841 bytes)
```

重启 mapviewer（:8899）。**注意**：验收时 E1（ed-map）正在并行拆分 mapviewer 为
`mapedit/` 包，工作区里的 `mapedit/api.py` 处于中间态（SyntaxError），因此本次验收
的 :8899 进程从 E0 自己的 commit `77221fa` 经 `git archive` 提取到 `/tmp/e0-mv`
运行——不动 E1 的工作区，也不阻塞验收。E1 合入后用 `services.sh start mapviewer`
即走主树。

HTTP 级验证（curl + 无头 Chrome DOM 探针，脚本见本目录 `verify_mapviewer.mjs`
的等价内联版）：

```console
$ curl -s http://127.0.0.1:8899/api/maps | python -c '…'
maps: 808
0.map cn = '比奇城'
maps with cn: 808            ← 中文名全量恢复

$ curl -s -o /dev/null -w '%{http_code} %{size_download}B' 'http://127.0.0.1:8899/minimap?map=0.map'
200 387986B                 ← 小地图恢复（EI 模式 FMMap.wil）
200 204303B                 ← 1.map 同样恢复
```

无头 Chrome（puppeteer-core + playwright chromium，userDataDir 指到磁盘，见
总纲 §3.4.1 /tmp 坑）DOM 级断言：

```json
{
  "apiMaps": 808,
  "cn0": "比奇城",
  "mmSrc": "http://127.0.0.1:8899/minimap?map=0.map",
  "mmNatural": "1200x800",
  "mmNonEmptyPixels": true,
  "hudText": "…比奇城 · 0"
}
```

截图：`mapviewer-0-recovered.png`（1440×900，比奇城主视图 + 右上「全图」小地图）。

## ✅ 2. `services.sh status` 正确报告全部服务

```console
$ bash scripts/services.sh status
SERVICE        PORT   STATE    PID
zircon-core    7000   运行中 pid 1557945
wsgateway      7001   运行中 pid 1558192
wilviewer      8765   停止
dbviewer       8800   停止
dbeditor       8810   停止
uieditor       8820   停止
webres         8821   停止
webclient      8822   停止
webport        8823   运行中 pid 1557960
portal         8840   停止
mapviewer      8899   运行中 pid 1557677
```

其中 zircon-core / wsgateway / webport 是**其它 goal 会话自己起的**——services.sh
按端口探测正确识别了非本脚本启动的服务（设计目标：与 hub 工具互认互不冲突）。
start/restart/stop 路径均实测（mapviewer start 两次、stop 一次，见下）。

## ✅ 3. 至少一个此前断链的 csproj 修复并实跑成功

批量把 11 个 `Tools/*.csproj` 套上 SystemDbProbe 的 `$(MIR3_ZIRCON_ROOT)` 模板
（断链相对路径 `..\..\LibraryCore\…` 与硬编码绝对路径两种形态统一替换）：

| 工程 | 构建 | 备注 |
|---|---|---|
| AccountProbe / CharacterEditor / MapFlagsProbe / ServerProbe | ✅ | 原为断链 `..\..\` |
| ClientProbe / AccountSetup | ✅ | 原为断链（单引用） |
| BotProvisioner | ✅ | ProjectReference + ServerLibrary.dll HintPath 一并模板化 |
| NpcMover / questdata/QuestProbe / dbeditor/importer | ✅ | 原为硬编码绝对路径，改 env 可移植 |
| Tools/DBImporter（根目录遗留副本） | ❌ | **HEAD 既有 Program.cs 语法损坏**（缺 `}`，与本修复无关）；sync.sh 实际用的是 `Tools/dbeditor/importer`（✅ 构建），遗留副本待主会话决定删除 |

实跑（对**隔离副本**运行，未触碰运行中服务器的活库）：

```console
$ cp …/Debug/ServerCore/Database/{System,Users}.db /home/tetsuya/tmp/e0-dbprobe/
$ export MIR3_ZIRCON_ROOT=/home/tetsuya/development/zircon
$ dotnet run --project Tools/AccountProbe --no-build -- /home/tetsuya/tmp/e0-dbprobe/ test
COLL AccountInfo: 310
COLL AutoPotionLink: 4
COLL BaseStat: 360
…（test 账号 4 条字段全量打印，Banned=False 等）
```

（AccountProbe 曾因 `..\..\LibraryCore` 断链无法编译——本次为修复后首跑。）

## 交付物清单

| 文件 | 作用 |
|---|---|
| `scripts/gen_caches.sh` | 三件套一键重建（`--thumbs` 连缩略图），双写 `Tools/cache/` + `/tmp` |
| `scripts/services.sh` | `start/stop/restart/status/log`，11 服务注册表，nohup+pidfile 自治（含 zircon-core/dotnet 的 bash -c cd 包装） |
| `Makefile` | `make cache / serve-mapviewer / serve / status / stop / roundtrip / probe` 短路目标 |
| `Tools/cache/` | 三件套入库（读取优先级：`MIR3_CACHE_DIR` > `Tools/cache` > `/tmp`） |
| mapviewer/dbviewer/webres | 路径健壮化：`MIR3_NAS_TMP` env + `/data/NAS` 探测 + Tools/cache 优先 |
| 11 × `Tools/**/**.csproj` | `$(MIR3_ZIRCON_ROOT)` 模板 |
| SystemDbProbe/Program.cs | root 参数尾分隔符归一化（防 `DataSystem.db` 0 表假成功） |
| 总纲 §3.4/§3.4.1/§4.3 | 新坑回写（NAS 路径 / tmpfs 满 / MirDB root 拼接 / mawk） |

## 遗留与移交

- `Tools/DBImporter`（根目录遗留副本）HEAD 即损坏，建议删除（另有一说留作历史）——主会话定夺。
- E1 拆分 `mapedit/` 合入后：`make serve-mapviewer` 直接走主树；`make roundtrip` 的
  `Tools/maps/map_roundtrip.py` 入口已留好（E1 落地文件即可用）。
- :8899 验收进程在验收完成后已停止，端口交还 E1。
