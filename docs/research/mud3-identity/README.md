# Mud3 ↔ Zircon 身份表（identity table）

> 目的：把 Mud3 EI2.0 服务端 DAT 的**官方中文名**与 Zircon `System.db` 的英文身份键
> 一对一挂上，驱动 `GodotClient/translations/db_names.json` 的显示名与后续数值/掉落迁移。
> 规则与证据优先级见 `Zircon/docs/pending/MUD3_CONTENT_AND_LEGACY_BAG_HANDOFF_2026-10-03.md` §1.4。
>
> **本目录只读产出，不改 `System.db` / 不改 `db_names.json` / 不改 Zircon C#。**

## 权威输入

| 侧 | 路径 | 说明 |
|---|---|---|
| Mud3 DAT（解码） | `Mir3-Research/docs/research/mud3-dat-decoded/{stditem,monster,magic}.json` | `records[].Name` 为 GBK 官方中文名；含价格/重量/耐久/等级等 |
| Zircon 当前库 | `/tmp/sysdb_probe.json/{ItemInfo,MonsterInfo,MagicInfo,RespawnInfo,DropInfo}.json` | 由 `SystemDbProbe --json` 从**当前** `System.db` 导出 |
| Mud3 刷怪/掉落 | `Mir3-Research/local-reference-data/yxs-mud3-2026-09-25/mud3/Envir/{Mon_Def,MonItems}/` | 共现证据 |
| 老对照表 | `mud3-dat-decoded/build_comparison.py` 的 `SKILL_MAP`/`ITEM_MAP`/`MONSTER_MAP`、`comparison.md` | 起点，非全表 |
| 图库尺寸 | `mir2ei/Data/*.Zl`，用 `Tools/common/zlsdk.py` 读帧尺寸 | 外观锚点 |

重建 Zircon 快照：

```bash
cd /home/tetsuya/development/Mir3-Research/Tools/SystemDbProbe
./bin/Debug/net10.0/SystemDbProbe /home/tetsuya/development/Zircon/Debug/ServerCore/Database --json /tmp/sysdb_probe.json
```

**禁止**用 `Tools/dbeditor/workspace/`（2026-08-14 快照）或 `docs/database/views/`（更旧，怪物记 309）
当作当前实况；当前库怪物 434 / 物品 1078 / 魔法 174。

## 输出格式

`<kind>.json`（kind = `monster` | `item` | `magic`）：

```json
{
  "kind": "monster",
  "generated_at": "2026-10-03",
  "sources": ["..."],
  "entries": [
    {
      "mud3_index": 12,
      "mud3_name": "祖玛教主",
      "kind": "monster",
      "zircon_index": 81,
      "zircon_en": "Zuma King",
      "confidence": "closed",
      "evidence": "HP 14000->21000 上调；Appr/Image 81；D201 刷怪共现"
    }
  ]
}
```

`<kind>.md`：按 `confidence` 分组的人审页（closed / pending / missing / zircon-only），
每条一行，带证据列。

### confidence 取值

| 值 | 含义 |
|---|---|
| `closed` | 1:1 且至少一条主证据（数值锚点 / 外观 或 刷怪掉落共现）闭合 |
| `pending` | 一对多或证据不足，**禁止自动在候选中挑一个 Index** |
| `missing` | Mud3 有、Zircon 当前库无 |
| `zircon-only` | Zircon 有、Mud3 无（中文可空或标「未开放」） |

### 证据优先级（高→低）

1. 已验证数值锚点（价格、重量、耐久、回复量、学习等级、HP/攻防/经验）
2. 外观：Mud3 `Looks` ↔ Zircon `Image`；Mud3 `Appr` ↔ Zircon `Image`
3. 刷怪 / 掉落共现（同 `Mon_Def` / 同 `MonItems` 组）
4. 网站 / 术语表：只做候选，不当唯一证据

### 已确认锚点（不得违反）

| Mud3 中文 | Zircon 身份 | Index |
|---|---|---|
| 半兽人 | `Oma` | 22 |
| 沃玛教主 | `Uma King` | 65 |
| 祖玛教主 | `Zuma King` | 81 |

`Uma King` 与 `Zuma King` 是两条不同怪，**不得都译成「祖玛王」**。

## 自检

- `closed + pending + missing` 覆盖 Mud3 全量行数（按 kind 的记录数）；
- `closed + pending + zircon-only` 覆盖 Zircon 全量行数；
- 无 `closed` 行出现 `zircon_index` 重复（1:1）；
- 抽 50 个经典名（金创药、木剑、布衣、半兽人、沃玛教主、祖玛教主、赤月恶魔、火球术、半月弯刀…）全部可判且 `Uma King ≠ Zuma King`。
