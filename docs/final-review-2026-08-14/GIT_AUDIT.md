# Git 全仓库收尾一致性审计 — 2026-08-14

机器: 82服务器 · 审计人: git-audit subagent · 范围: ~/development 下 7 仓库

## 审计结论总表

| 仓库 | 分支 | 远程 | 状态 | 审计时发现 | 动作 | 敏感发现 |
|------|------|------|------|-----------|------|---------|
| zircon | master | github.com:iamcheyan/Zircon.git | 工作区脏 + 追踪缓存过期 | 3 个 BotRunner 源码改动未提交; 8 个 Godot .cs.uid / BotRunner.82.json / Config//verify_doc_citations.py 未跟踪; 2 个本地备份残留 | ✅ 已提交 a85c3a9(源码) + 7d95d8e(收录配置+ignore 备份) + push | 无 |
| Mir3-Research | master | git@github.com:iamcheyan/Mir3-Research.git | 工作区脏 | watchdog 新 goal 条目 + 44 个 dbeditor 实况图标未跟踪; **5 个 .bak 备份文件今天误入库** | ✅ 已提交 01cf988(watchdog+图标) + 0f5e80b(git rm --cached .bak + ignore *.bak) + 审计报告 | 无 |
| svc-dashboard | main | origin (HTTPS) | ✅ 干净·同步 | — | 无需动作 | 无 |
| yomu | main | origin (HTTPS) | ✅ 干净·同步 | 今日 81ac88a3 含 6.6MB data/aozora_catalog_compact.json(已跟踪目录数据的常规更新, js/app.js 直接消费) → 判定非误提交 | 无需动作 | 无 |
| fudoki | master | origin (HTTPS) | ✅ 干净·同步 | login.html 硬编码 Firebase Web config(apiKey/projectId fudoki-f370e) — 2025-10 起就存在, 非今日引入; Firebase Web apiKey 设计上公开(配安全规则防滥用), AGENTS.md 已立红线 | 仅记录, 不动历史 | ⚠️ 见「敏感扫描」 |
| miyako | ralph/nas-music-sync | origin (HTTPS) | ✅ 干净·同步 | 今日 CI 提交含签名骨架, 密码全部走 System.getenv, 无 keystore 文件入库 | 无需动作 | 无 |
| oh-my-desktop | main | origin (HTTPS) | ✅ 干净·同步 | — | 无需动作 | 无 |

## 本地 HEAD vs 远程 (git ls-remote 实测)

| 仓库 | 本地 HEAD | 远程 SHA | 结论 |
|------|-----------|----------|------|
| zircon | 7bcde598 | 7bcde598 | 一致(追踪缓存过期致假性 ahead 1, fetch 后 0/0; 审计新增 2 commit 后已重新 push) |
| Mir3-Research | bafebc49 | bafebc49 | 一致(审计新增 3 commit 后已 push) |
| svc-dashboard | c8467e32 | c8467e32 | 一致 |
| yomu | cc2633a9 | cc2633a9 | 一致 |
| fudoki | 9a9d81fd | 9a9d81fd | 一致 |
| miyako | 0ce46bc9 | 0ce46bc9 | 一致 |
| oh-my-desktop | fd5fec51 | fd5fec51 | 一致 |

无任何仓库落后远程; 无 stash 残留(7/7 均 0 stash); 无 force push 任何分支。

## 敏感扫描

- 扫描对象: 7 仓库 2026-08-14 全部 **106 个 commit** 的全部新增行(共 ~11.2M 字符), 另做全历史 -G 抽查。
- 模式: `sk-`、`gh[pousr]_`、AWS `AKIA`、`AIza`、`xox*`(Slack)、`BEGIN PRIVATE KEY`、`api[_-]?key/secret/token/password = <20+ 字符>`。
- **结果: 0 命中**(占位符/示例值已排除)。全历史抽查同样 0 命中。
- ⚠️ 唯一备注: fudoki `login.html:1195` 硬编码 Firebase Web apiKey(Firebase Web API 密钥按设计是公开标识符, 安全靠 Firestore 规则; 该行 2025-10-13 已存在, 今日 diff 只是 AGENTS.md 交接文档描述了它)。**未触碰远程历史**, 维持 AGENTS.md 红线约定。
- zircon `BotRunner.82.json` Password=bot123456: 与已入库的 BotRunner/BotRunner.json 同款本地测试 bot 密码, 非真实凭据, 且仓库为公开镜像复刻(上游同款文件同样公开)。

## 大文件检查 (>5MB)

| 仓库 | 文件 | 大小 | 判定 |
|------|------|------|------|
| yomu | data/aozora_catalog_compact.json (81ac88a3) | 6.6MB | ✅ 正常: 已跟踪目录索引的例行数据刷新, app.js/sw.js 直接消费, 与 aozora_catalog.json(7.6MB) 同族 |
| yomu | assets/fonts/*.woff2 (aac166d1) | 4×1.0-1.9MB | ✅ 已知有意提交(日文字体内置, OFL) |
| 其余 5 仓库 | — | — | 今日 commit 最大单文件 2.42MB(MapRegion.json, Mir3-Research workspace 基线) — 无违规 |

## 今天误入库文件的清理

- Mir3-Research 1322639 (07:34) 顺手 `git add` 了 4 个 `*.bak-0814` + 68119dc 的 watchdog `.bak-20260812`: 已用 **git rm --cached**(保留磁盘文件, 不改历史) + `.gitignore` 补 `*.bak` / `*.bak-*`, commit 0f5e80b。
- zicorn 本地备份 `BotRunner.82.json.before-*` / `Tools.pre-pull-*/` 留盘不入库: `.gitignore` 已补规则, commit 7d95d8e。

## 审计期间新增提交(本报告产物)

| 仓库 | commit | 内容 |
|------|--------|------|
| zircon | a85c3a9 | BotRunner 源码收尾(护符优先/黑名单TTL/供给优先/A*诊断) |
| zircon | 7d95d8e | chore: 82 运行配置 + Godot .cs.uid + 引用校验脚本 + gitignore 备份 |
| Mir3-Research | 01cf988 | dbeditor 实况图标缓存补全 + watchdog 注册 botgoal |
| Mir3-Research | 0f5e80b | chore: 移除误入库 .bak(git rm --cached) + gitignore |
| Mir3-Research | (本 commit) | docs: GIT_AUDIT.md 全仓库收尾审计 |

## 遗留(不阻塞)

- `docs/final-review-2026-08-14/` 内 svc-dashboard 走查截图与 `review_goals/{fudoki_evidence,yomu_audit_0814}/` 为兄弟审计 agent 的产物, 审计时仍在产出中 — 未代为提交, 留给总收尾统一入库。
