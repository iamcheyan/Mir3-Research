# GitHub 账号仓库清理审计 + 描述补全 — 完整任务目标

## 一、任务背景

GitHub 账号 **iamcheyan** 有约 146 个公开仓库 + 若干私有仓库，长期积累后：
- 很多项目没有 description（GitHub 页面上显示在仓库名下面那一行简介）
- 分叉/自有混杂，难以分辨
- 部分长期未维护、部分压根无意义
- 用户想清理，需要一份**完整审计报告**辅助决策

你的任务：**对账号下全部仓库做完整审计报告**，并对**缺 description 的仓库补上英文描述**。

## 二、数据源与工具

- CLI：`gh` 已登录（iamcheyan），有读写权限
- 列全部仓库（含私有）：
  ```bash
  gh repo list iamcheyan --limit 500 --json name,description,isFork,isArchived,isPrivate,isTemplate,stargazerCount,forkCount,updatedAt,pushedAt,createdAt,url,primaryLanguage,parent,defaultBranchRef
  ```
  注意 `gh repo list` 默认只列 30，必须 `--limit 500`；若仍不够用
  `gh api user/repos --paginate` 翻页
- 上游仓库信息：fork 的 `parent` 字段
- 是否有未合并的 upstream 更新：
  ```bash
  gh api repos/iamcheyan/<name>/compare/<upstream-owner>:<default-branch>...HEAD --jq '.status,.ahead_by,.behind_by'
  ```
  （fork 才做，非 fork 跳过）
- 设置描述：
  ```bash
  gh repo edit iamcheyan/<name> --description "English description here"
  ```

## 三、审计维度（每个仓库都要）

| 字段 | 来源 | 说明 |
|---|---|---|
| name | API | 仓库名 |
| url | API | 链接 |
| isPrivate | API | 公/私 |
| isFork | API | 是否分叉 |
| parent | API | 上游 owner/name（fork 才有） |
| isArchived | API | 是否已归档 |
| description | API | 当前描述（空=缺） |
| stars / forks | API | 人气 |
| language | API | 主语言 |
| createdAt | API | 创建时间 |
| pushedAt | API | 最近 push |
| updatedAt | API | 最近更新（含非代码） |
| daysSincePush | 计算 | 今天 - pushedAt |
| behindUpstream | API compare | fork 落后上游几个提交（-1=查失败/非fork） |
| hasReadme | API contents | 根目录是否有 README |
| suggestedAction | 你判断 | keep / archive / delete-candidate / unfork-keep / describe-only |
| reason | 你判断 | 一句话理由 |
| newDescription | 你写 | 若 description 空，写英文描述（≤ 120 字符，清晰说明做什么） |

## 四、分类规则（suggestedAction 判定）

按优先级套：

1. **keep（活跃维护）**：30 天内有 push，或 stars≥10，或是用户明确核心项目：
   - 核心清单（强制 keep）：`Zircon`、`Mir3-Research`、`mir3-website`、`mir2ei`、
     `Clawtter`、`chezmoi`、`dotfiles`、`hermes-backup`、`oh-my-desktop`、
     `sumika-*`、`svc-dashboard`、`terebi`、`rime`、`musubi`、`madobe`、`shirabe`、
     `sasayaki`、`pi-opencode-config-reader`
2. **unfork-keep（有价值的 fork）**：isFork=true 且（behindUpstream 不大 或 本地有 commits ahead）且近期有 push——保留但建议加 description 标明"fork of X with Y changes"
3. **archive（长期不维护但有历史价值）**：180-730 天未 push，有一定 stars/内容，不建议删
4. **delete-candidate（建议删除）**：满足任一：
   - 730 天+ 未 push 且 stars=0 且无实质 README
   - 空仓库（size≈0 / 无 commit）
   - 明显测试/一次性实验（名字含 test/tmp/demo/scratch/old）且长期不动
   - fork 且从未 push 过自己的 commit（纯镜像，可用 upstream）
5. **describe-only**：活跃或有价值，但 description 为空——只补描述，不改其他

**注意：本任务只给建议，不执行 delete/archive**（危险操作留给用户手动确认）。
唯一自动执行的写操作是：给缺 description 的仓库补英文描述。

## 五、描述撰写规范

- **语言：英文**（GitHub 国际惯例；用户明确要求英文）
- 长度：40-120 字符
- 内容：一句话说清"这是什么 + 关键特性"，不要空洞的 "My project" / "WIP"
- fork 仓库：以 "Fork of <upstream> — <你的改动/用途>" 格式
- 中文项目可在描述末尾加中文关键词（可选），但主体英文
- 示例：
  - `Clawtter` → "Event-driven personal worklog publisher: Markdown → static HTML → GitHub Pages"
  - `Zircon` → "Fork of Suprcode/Zircon (Legend of Mir 3 private server) with Godot client, EI map pack, and CN localization"
  - `chezmoi` → "Personal chezmoi-managed dotfiles and machine bootstrap configs (Linux + Asahi)"

## 六、交付物

1. **完整报告**（Markdown）：`~/development/Mir3-Research/docs/GITHUB_REPO_AUDIT_2026-08-13.md`
   结构：
   ```
   # GitHub iamcheyan 仓库审计报告 (2026-08-13)
   ## 0. 总览
      - 总数 / 公开 / 私有 / fork / 自有 / 已归档
      - 缺 description 数量（补前/补后）
      - 建议 keep / archive / delete-candidate / unfork-keep 数量
   ## 1. 建议删除 (delete-candidate)  — 表格
   ## 2. 建议归档 (archive)          — 表格
   ## 3. 有价值的 fork (unfork-keep)  — 表格（含 upstream 与 behind 数）
   ## 4. 活跃自有项目 (keep)          — 表格
   ## 5. 本次补全的 description       — 表格（仓库名 | 旧描述 | 新描述）
   ## 6. 完整清单（所有仓库一张大表，按 pushedAt 降序）
   ## 7. 操作建议（用户下一步可手动执行的 gh 命令清单，注释掉的 delete/archive）
   ```
2. **机器可读 JSON**：同目录 `GITHUB_REPO_AUDIT_2026-08-13.json`（数组，每仓库一个对象，含全部字段）
3. **已执行的 description 补全**：用 `gh repo edit` 真实写入，报告 §5 列出前后对比
4. **提交**：报告+JSON 提交到 Mir3-Research 仓库（中文 commit），push

## 七、执行步骤

1. 拉全量仓库列表（含私有）→ 存 `/tmp/gh_repos_raw.json`
2. 对每个 fork 查 compare 状态（并发控制 ≤5，避免 rate limit；遇 403 限速 sleep）
3. 检查 README 存在性（`gh api repos/iamcheyan/<n>/contents/README.md -q .name` 失败=无）
4. 套分类规则，生成 suggestedAction + reason
5. 对 description 为空的：写英文描述 → `gh repo edit --description "..."` → 记录成功/失败
6. 生成 Markdown 报告 + JSON
7. 提交 push 到 Mir3-Research
8. 最终汇报（中文）：总数、补了多少描述、建议删/归档各多少、最值得关注的 10 个决策点

## 八、边界与安全

- **禁止**：`gh repo delete`、`gh repo archive`、改 visibility、改仓库名、force push
- **唯一写操作**：`gh repo edit --description`（补描述）
- 私有仓库也要审计进报告，但报告本身 push 到**公开的** Mir3-Research 时：
  **私有仓库名可以列，但不要暴露私有仓库的具体内容/敏感描述**
  （如 hermes-backup 只写 "private backup repo" 即可）
- Rate limit：`gh api rate_limit` 监控；剩余 <100 时降速
- 不要 clone 仓库（太慢太占盘）；元数据 API 足够

## 九、验收标准

1. ✅ 报告覆盖账号下**全部**仓库（公开+私有），数量与 `gh repo list --limit 500` 一致
2. ✅ 每个缺 description 的非 archived 仓库都尝试补了英文描述（失败的在报告注明原因）
3. ✅ 分类建议合理（核心清单强制 keep；空/测试/僵尸 fork 进 delete-candidate）
4. ✅ JSON + Markdown 已提交 push 到 Mir3-Research
5. ✅ 最终中文汇报含：数字总览 + 建议删除 Top 10 名单 + 补描述成功数
