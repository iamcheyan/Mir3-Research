# YXS / Mud3 原始文本参考源（2026-09-25）

## 用途

这组文本资料用于 NPC/怪物全地图对齐，作为英雄杀地图基准、原版 NPC 位置、怪物名称映射和刷新点研究的可复核来源。

当前目标：

- 英雄杀地图 `MapInfo.txt`
- 英雄杀 NPC 位置 `Merchant.txt`
- 英雄杀刷新入口 `Mongen.txt`
- 英雄杀怪物区域刷新定义 `Mon_Def/*.gen`
- Mud3 原版 `Mapinfo.txt`、`Merchant.txt`、`MonGen.txt`、`Mon_Def/*.gen`

## 仓库路径

文本源已版本化保存于：

```text
Mir3-Research/docs/research/ei-ui-layout/sources/hero-kill-mud3-2026-09-25/
```

目录结构：

```text
hero-kill-mud3-2026-09-25/
├── yxs/Envir/
│   ├── MapInfo.txt
│   ├── Merchant.txt
│   ├── Mongen.txt
│   └── Mon_Def/*.gen
└── mud3/Envir/
    ├── Mapinfo.txt
    ├── Merchant.txt
    ├── MonGen.txt
    └── Mon_Def/*.gen
```

原始二进制 `monster.dat` 没有放入公开仓库；本机私有副本仍位于：

```text
/home/tetsuya/mir3-reference/2026-09-25/mud3/Envir/monster.dat
```

## 原始来源

来源均来自本机 NAS 的对应目录：

```text
/data/NAS/TMP/EI3.0英雄杀服务端/Mud3/Envir/
/data/NAS/TMP/Mud3/Envir/
```

复制日期：2026-09-25。

关键源文件 SHA-256：

```text
YXS MapInfo.txt   20c3b6fa4cdc71bb00884335019d1709631a78cd55718321248e3da09613dcdf
YXS Merchant.txt 5f6bf99f1e0bf655ec9ef5b56d49b8adaaa65d112b33a5a3222474cc425a95e
YXS Mongen.txt   ca110f71cfbcf3f4c1028dd3a4398294e12dfef7b52b5fc763b55d926798534f
Mud3 Mapinfo.txt 见源文件清单/复制记录
Mud3 Merchant.txt 见源文件清单/复制记录
Mud3 MonGen.txt 见源文件清单/复制记录
Mud3 monster.dat 3d05751be493b30ab944d8d451b3762f4bcd8b3744fb6213067126766228dd74（仅本机私有）
```

## 编码和读取规则

这些文件来自旧版 Mud3/EI 环境：

- `Merchant.txt`、`Mapinfo.txt`、`MonGen.txt`、`.gen` 可能是 GB18030、CP949、ISO-8859 或混合旧编码；
- 读取前必须以字节方式探测/按文件来源尝试编码；
- 不得用系统默认 UTF-8 直接读取后把乱码当作怪物/NPC 名称；
- 解析结果必须保留原始行号、源文件和编码判定；
- 改写/规范化后的 UTF-8 manifest 与原始文本分开保存。

## 后续使用规则

### 怪物映射

优先联合使用：

1. 本目录的英雄杀/Mud3 文本；
2. `docs/legacy-atlas/content/catalog-mud3.html` 的 433 条老版怪物目录及 `old-only/current-only/both/changed/unverified` 分类；
3. `docs/research/mud3-dat-decoded/monsters_zircon.json`；
4. `docs/research/ei-ui-layout/monster-dat-catalog.json`；
5. Zircon `MonsterInfo`、`LibraryCore/Enum.cs` 和 `GodotClient/Formats/MonsterLookup.cs` 的图片/shape/frame 信息。

不要只按模糊中文名映射；半兽人、祖玛、白野猪、Boss/变体必须记录四方证据和冲突。

### NPC 映射

- `Merchant.txt` 用作原版位置和地图归属来源；
- 当前 Zircon NPC 身份/业务保留；
- 英雄杀地图对应关系先经过 `exact/renamed/variant/replacement/pending` 判断；
- 没有原版地图/NPC对应的 Zircon NPC 先计算候选位置，不自动删除；
- 所有候选写入 manifest 和人工复核清单。

### 刷新点

- `Mongen.txt`/`MonGen.txt` 和 `Mon_Def/*.gen` 作为刷新计划来源；
- 必须保留地图、坐标、数量、范围、刷新间隔、怪物身份、源文件和原始行号；
- 源配置缺少逐点 range 时明确标记 `range_pending`，不能伪造范围后写库；
- 写库前必须完成 dry-run、地图可行走和重叠检查。

## 公开仓库边界

本目录只放用户确认可公开的文本资料；不放：

- `monster.dat` 等二进制；
- `.exe/.dll/.wil/.wix/.map/.db`；
- 凭据、日志和运行缓存。

本机完整复制目录 `local-reference-data/` 已加入 `.gitignore`，用于保留原始来源和未来重新校验。
