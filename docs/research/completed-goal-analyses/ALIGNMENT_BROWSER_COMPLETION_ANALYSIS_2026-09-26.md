# Zircon ↔ mir2ei 双向对照网页：完成分析（2026-09-26）

## 结论

最终对照网页已经生成并完成双向差异分类：

- `mir2ei 有 / Zircon 没有`
- `Zircon 有 / mir2ei 没有`
- 双方都有但不同
- resolved / partial / conflict / pending-evidence / retain-current / production-applied

页面入口：

```text
http://192.168.3.82:8890/
```

静态服务只读运行，不修改数据库。

## 页面内容

分类包括：

- 总览
- 怪物
- NPC
- 物品
- 技能
- 地图
- Respawn
- 任务交叉引用
- 最终结论
- 双向差异清单

详情页面左右显示：

- 左：当前 Zircon workspace/生产证据
- 右：mir2ei、mir3-website、Legacy Atlas、旧版资源证据
- 下方：身份、名称、图片、属性、地图、坐标、刷新、掉落、任务关系等维度矩阵

## 数据范围

- Zircon MonsterInfo：434
- Zircon MagicInfo：174
- Zircon ItemInfo：1078
- Zircon NPCInfo：294
- Zircon MapInfo：627
- Zircon RespawnInfo：2475
- 网站怪物：154
- 网站技能：61
- 网站物品：371
- 网站任务：24 组
- 网站地图组：3 组、22 个区域图

网页明确区分网站子集与 Zircon 全量，避免把“网站没有页面”直接判定为 Zircon 错误。

## 修复和验证

- favicon 已加入，HTTP 200。
- 静态 JSON 全部 HTTP 200。
- `app.js` 语法检查通过。
- 静态数据使用 `cache: no-store`。
- AbortError 单次重试，不再把浏览器导航/扩展 abort 当页面致命错误。
- cache-bust 版本：`20260926.3`。
- 桌面截图：1280×800、1920×800。
- 手机截图：390×844，无横向溢出。

## 交付提交

```text
993928d9 新增 Zircon 与 mir2ei 数据对照网页
71c72c67 细化对照网页双向差异结论
```

网页目录：

```text
docs/research/ei-ui-layout/alignment-browser/
```

## 关闭判定

网页功能和双向差异展示已完成。后续网络别名全量审计会继续更新数据，但属于新的网络匹配 Goal，不改变本网页的审计结构和来源追踪规则。
