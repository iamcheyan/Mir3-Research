# 网站标准实体对齐：完成分析（2026-09-26）

## 结论

本 Goal 已完成调查、manifest、独立验证、批准清单应用、双库 round-trip 和官方客户端 smoke。
本次只应用已批准的 NPC/RespawnInfo 位置清单；网站怪物/技能/物品证据已经整理，但没有把未经稳定 Index 闭合的显示/业务字段写入数据库。

## 实际应用

| 对象 | 结果 |
|---|---:|
| NPC 位置 | 73 条 |
| RespawnInfo | 18 条 |
| 新建 MapRegion | 0 条 |
| MonsterInfo 业务字段 | 0 条 |
| MagicInfo 业务字段 | 0 条 |
| Users.db | 0 写入 |
| pending/investigate/冲突项 | 全部 retain-current |

生产服务端和客户端 System.db 最终 SHA-256 一致：

```text
b6aaa4bf2912a8fcd66664981a28d556aa6e2256ce2c40ad307b3d6913b03bb9
```

后续快照备份：

```text
/home/tetsuya/.local/state/mir3-systemdb-backups/20260926-154701/
```

## 证据

- 总报告：`docs/research/ei-ui-layout/NPC_MONSTER_WEBSITE_ALIGNMENT_REPORT_2026-09-26.md`
- 生产证据：`docs/research/ei-ui-layout/artifacts/website-alignment-2026-09-26/production-apply-evidence-20260926.json`
- 最终目标字段：`final-production-targets-20260926.json`
- 官方客户端 smoke：`official-client-smoke-20260926.log`
- NPC 隔离地图 smoke：`isolated-map610-npc-smoke-20260926.log`
- Respawn 隔离地图 smoke：`isolated-map5-respawn-smoke-20260926.log`

## 已验证行为

- ServerCore 停止后完成备份和临时副本 apply。
- 临时副本 round-trip 通过，未批准变更为 0。
- 真实双库写入后服务端/客户端 SHA 一致。
- 官方 Godot 客户端收到 GoodVersion、LoginResult.Success、StartGame.Success 并进入 GameScene。
- 隔离副本验证了批准 NPC 和 RespawnInfo 的实际对象包。
- webport 登录断开是独立 webport 问题，不影响官方客户端 smoke。

## 保留的未决项

- 网站 154 怪物不是 Zircon 434 怪物全量；confirmed/investigate/pending 继续保留。
- 网站 61 技能不是 Zircon MagicInfo 174 条全量；只做证据和显示名计划。
- 网站 371 物品不是 Zircon ItemInfo 1078 条全量；未安全闭合的 Index 不猜。
- 网站 mob-6“蛤蟆”仍为 pending/retain-current。
- 这份完成分析不代表所有网站实体都已写入 Zircon；它只证明批准的位置应用完成。

## 关闭判定

本 Goal 的数据库应用目标已完成；后续网络别名全量匹配和对照网页双向差异属于新的后续任务，不回写本 Goal 的生产结论。
