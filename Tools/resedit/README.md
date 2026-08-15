# resedit — 资源编辑器工具集 (Goal E3)

> 目标: 消灭「动画帧表/纸娃娃公式」的 JS/C# 双份手工维护 (总纲 §7.1 任务 1)。
> 状态: **已完成** (2026-08-15)。ZL 帧写回为高风险后置项，未做 (见文末)。

## 组成

| 文件 | 作用 |
|---|---|
| `frameformulas.py` | 提取器: 从 Zircon C# 事实源反向导出 `frame-formulas.json` |
| `frame-formulas.json` | **单一数据源**: 94 帧表 560 项 / 221 MagicType / 攻击+魔法分派全表 / 纸娃娃层公式 / NPC 特例 23 项 / ArmourShift / 方向分组 |
| `legacy-frames-baseline.json` | 旧 webport frames.js 手抄表的机器导出基线 (提取器交叉核对桥, 防提取 bug) |
| `e3-verify.mjs` | webport 全链路验收 (真服: 注册→登录→建角→进图 + 数据面断言) |

## 事实源 → JSON 映射

| C# 源 | JSON 键 |
|---|---|
| `LibraryCore/FrameSet.cs` | `frameSets` (Players/DefaultMonster/DefaultNPC/DefaultItem + 90 张怪物/随从专属表) |
| `LibraryCore/Functions.cs` | `attackDispatch.rules` (8 条) + `magicDispatch.groups` (12 组) |
| `LibraryCore/Enum.cs` | `enums` (MirAction/MirAnimation/MirDirection/MirClass) + `magicTypes` (221) |
| `GodotClient/Scripts/PlayerRenderer.cs` | `armourShift` + `paperdoll` (层公式/shapeOffset/方向分组/藏武器套装) |
| `GodotClient/Scripts/ObjectRenderer.cs` | `npcSpecial` (23 项) + `objects` (怪物 1000/NPC 100/物品 0 bodyOffset) |

## 使用

```bash
# Zircon C# 改了帧表/分派 → 重跑提取器, webport + wilviewer 两侧同步变
python3 Tools/resedit/frameformulas.py           # 生成
python3 Tools/resedit/frameformulas.py --check   # CI 门禁: JSON 与源一致?

# webport 验收 (需 wsgateway:7001 + ServerCore:7000 + webport:8823)
node Tools/resedit/e3-verify.mjs
```

提取器全程断言解析 — Zircon 升级后 C# 格式漂移会在提取时炸 (而非静默产出错表);
`legacy-frames-baseline.json` 基线核对保证提取结果与 webport 已验证的手抄行为逐项一致。

## 消费方 (一处改两边变的"两边")

1. **webport** (`Tools/webport/`): `frames.js` 运行时 `ensureLoaded()` 读
   `serve.py /frame-formulas.json` (no-cache); `data.js` 帧公式收编为 frames.js 懒投影。
   手抄表已全删。
2. **wilviewer** (`Tools/web/wilviewer.py`): `/api/frame-formulas` (mtime 缓存);
   选帧详情弹窗显示反查结果 (帧号 → 动画表项/方向/帧内序号/ms/倒放 + 纸娃娃公式)。

## 验收记录 (2026-08-15, 82 机器)

- **数据面**: PLAYERS 42 动画 / MAGIC 221 / NPC_SPECIAL 23 / combat1 帧延迟覆盖
  [100,200,...] / monster hide 倒放 / 分派抽查 (Slaying→combat3, FullBloom(1250)→combat13,
  刺客默认→combat3, Hurricane→channellingStart, 未知魔法→combat1 容错) 全过
- **行为面 (真服全链路)**: 注册独立账号→登录→建角→进比奇, canvas 渲染正常
  (40% 采样点非空), 零 Runtime 异常零失败请求; `test-anims.mjs` 71/71 全绿
- **drift 实验**: `frame-formulas.json` walking.count 6→8 → 刷新页面 → 浏览器 fetch
  与 `PLAYERS.walking.count` 双读 8 (JS 零改动); 还原后 `--check` ✓
- **wilviewer 面板**: M-Hum#82→players.walking 第2/6帧 方向=上; NPC#5600→
  npcSpecial 特例(12帧200ms)+defaultNPC 绝对帧号; Mon-1#1682→Shape=1+hide 倒放
- **批量导出**: `/api/export?kind=webp` 无损 WebP ZIP (比 PNG 小 45%), PNG 路径无回归

截图/证据: `docs/resedit/proof/`

## 踩坑 (已回写总纲 §3.7)

1. **serve.py 中间件统一覆盖 Cache-Control**: 路由内设的 `no-cache` 会被
   `headers` 中间件的 `max-age=86400` 无条件覆盖 → 改 JSON 后浏览器吃缓存,
   drift 实验「未生效」假阴性。教训: 中间件管头时路由内设头无效, 条件要写在中间件里。
2. **ZL 库 header 无 shadow 字段**: wilviewer export 的 manifest 硬取
   `hdr["shadow"]`, 对 ZL 库必 KeyError (此前只对 WIL 用过)。
3. **C# switch 的连续 case 标签**: `case A: case B: <body>` 产生空段,
   分段解析需累积合并; 嵌套 `switch(@class)` 的 `default:` 会干扰外层分段, 先摘出再解析。
4. **MirClass 本 fork 无 Archer**: Enum.cs 只有 4 职业; webport `CLASS_ARCHER=4`
   是上游遗留兼容别名 (分派只特判刺客, 无行为影响)。
5. **webport 存在第三份帧公式手抄**: `data.js` 的 PLAYER_ANIMS/armourShift 残缺副本
   (armourShift 只有 6 项 vs 全表 37 项) — 已收编为 frames.js 投影, 否则只消灭两份
   仍留一处暗漂移。

## ZL 帧写回 (未做, 高风险后置)

总纲 §7.1 任务 4 允许不做。理由: ZL2 容器 (BC7/DXT 压缩纹理) 写回需重新编码压缩块 +
round-trip 字节级验证 + 原库备份链, 工作量与风险远超本期收益; 且当前无「改帧像素」的
产品需求 (编辑器场景改的是帧表/坐标, 不是贴图内容)。若要做: 参照 §5.2 map 写回纪律
(备份→副本→独立 parse round-trip→原子替换), 解码器复用 `Tools/item_icon_extractor`
的 BC7 路径。
