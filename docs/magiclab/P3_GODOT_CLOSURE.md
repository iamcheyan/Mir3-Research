# P3 Godot 闭环 — 验收证据

日期：2026-08-15/16。跨仓改动已在 tmux（ed-magic）声明后执行。

## 改动

Zircon 仓（commit `0dc1321`，推 origin=iamcheyan/Zircon master）：

- `GodotClient/Scripts/MagicEffectTable.cs`
  - `OriginalSpellCases` := 原版有特效 case 全集（136；纯音效 CombatKick/JudgementOfHeaven 归 `NoVisualSpellCases`）
  - 参数修正：AdamantineFireBall 1640×6 弹道 + 1800×10 命中（原误抄 FireBall 420/580）；ImprovedExplosiveTalisman Source 库 MagicEx2#980（原误 Magic）；SummonSkeleton/SummonJinSkeleton 740×10@60ms（原 750）
  - 补 5 条缺失条目：CrushingWave（MagicEx6#100×6）、FrostBite（MagicEx5#500×16@60）、Rake（MagicEx4#1200×9 + 8 方向帧表）、SeismicSlam（MagicEx5#4900×6）、Spiritualism（MagicEx2#1580×11）
- `GodotClient/Scripts/MapTestScene.cs`：新增 `--magic-spot-audit`（仿 DeadTargetAudit 反射先例）
- `GodotClient/Scripts/MirEffectNode.cs`：`File` 字段（Setup/SetupTarget 记录，审计比对用）

Mir3-Research 仓：`Tools/magiclab/gen_cs_table.py`（校验/修复闭环，独立解析 C# 表，不复用 extractor 代码）。

## 校验闭环

```
$ python3 Tools/magiclab/gen_cs_table.py --check
OK: _table 146 条, 白名单 136 == 原版 switch 138; 共有 136 技能三元组全一致 (可接受差异 7)
```

修复前同命令：`CHECK FAIL (66 违规)`（5 缺失条目 + 4 组参数错配 + 57 白名单口径差）。
可接受差异（`ACCEPTABLE`）：ScortchedEarth/MonsterScortchedEarth（原版动态随机帧）、AugmentPoisonDust/ThunderStrike（Godot 补画）、DoomClaw×2/GreenSludgeBall（怪物第二段）。

## 验证

1. `dotnet build GodotClient/ZirconClient.csproj` → **0 错误**
2. 无头 Godot 抽测（`--magic-spot-audit`，反射驱动真实 `RenderObjectMagicStart`/`RenderObjectMagic`）：

```
[MagicSpotAudit] PASS FireBall 表=(Magic, 1820, 8) (Magic, 420, 5) (Magic, 580, 10) 运行时=(Magic, 1820, 8) (Magic, 420, 5)
[MagicSpotAudit] PASS AdamantineFireBall 表=(Magic, 1560, 9) (Magic, 1640, 6) (Magic, 1800, 10) 运行时=(Magic, 1560, 9) (Magic, 1640, 6)
[MagicSpotAudit] PASS SummonSkeleton 表=(Magic, 740, 10) 运行时=(Magic, 740, 10)
[MagicSpotAudit] PASS FrostBite 表=(MagicEx5, 500, 16) 运行时=(MagicEx5, 500, 16)
[MagicSpotAudit] PASS Rake 表=(MagicEx4, 1200, 9) 运行时=(MagicEx4, 1200, 9)
[MagicSpotAudit] PASS 5/5 技能: 表定义 ⊇ 事实源三元组, 运行时 ⊇ 非弹道承载段
```

口径：双层断言——(a) 表定义三元组 ⊇ 事实源（JSON start/release 全段合并）；(b) 运行时节点 ⊇ 非弹道承载段。弹道承载的 Arrival 命中段（580/1800）在裸场景 `_mapView==null` → `duration==0` → CompleteAction 同帧触发后节点生命周期极短，同步收集不稳定，故走 (a)；运行时帧范围/锚定/回退链路由 `MagicFrameAudit` + `DeadTargetAudit` 覆盖。

3. 既有审计回归（`--action-audit --skip-sound-audit`）：

```
[MagicCoverageAudit] castConfigured=146 attackOnly=6 missingOriginalSpell=0 noMapEffect=68
[MagicFrameAudit] PASS skills=146 originalResourceExceptions=1 (GreenSludgeBall impact dir0-only verified)
[SpellTimingAudit] PASS animation=Combat1 releaseDelay=400ms total=600ms
```

`missingOriginalSpell=0`：白名单口径修正的直接收益（原 90 → 136，与 `MagicInfo` 原版 switch 全集对齐）。

## 已知预先存在问题（非本轮引入）

`--dead-target-audit` 在本轮改动前的 HEAD 上同样失败（基线落点 Impact 数=0 期望=1；尸体锚定 cell=0），stash 对照验证过；属于 ElectricShock 条目与该审计期望的历史分叉，与本轮特效表修正无关，留待后续 goal。

## 复现命令

```bash
# 校验（CI 语义: 违规退出码 1）
/home/tetsuya/mir3-venv/bin/python Tools/magiclab/gen_cs_table.py --check
# 幂等修复
/home/tetsuya/mir3-venv/bin/python Tools/magiclab/gen_cs_table.py --fix
# 无头抽测
cd ~/development/zircon && dotnet build GodotClient/ZirconClient.csproj
godot-mono --headless --path GodotClient res://Scenes/MapTestScene.tscn -- --magic-spot-audit
```
