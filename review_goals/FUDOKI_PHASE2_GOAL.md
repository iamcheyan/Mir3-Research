# FUDOKI Phase 2 深度 Review → 功能增强 Goal 文档

> 生成：2026-08-14 · 基于 :8831 无头浏览器实测 + 全量代码走查
> 仓库：~/development/fudoki（纯静态 PWA，GitHub Pages 部署）
> 用户画像：日语学习者，在日工作，日常用 fudoki 读日文材料 + 查词 + 跟读
> 红线：Firebase 后端（login.html:1188 配置 / index.html:643 module）只可谨慎增强，不可重写架构。

---

## 一、现状快照（实测证据）

### 1.1 架构事实
| 项 | 现状 | 证据 |
|---|---|---|
| 词典数据 | JMdict 3.6.1，2 分片 JSON（81MB+28MB=109MB），213,554 词条 | static/libs/dict/chunks/，metadata |
| 词典加载 | 首次查询触发**全量** fetch+parse，setTimeout 节流合并（每 1 万词 yield） | dictionary-service.js:63-98 |
| 词典查询 | **线性扫描全表**，命中 10 条早停；未命中词全扫 213K | dictionary-service.js:124-155 |
| 登录门禁 | 仅 Google 登录；index.html 用 onAuthStateChanged（gstatic CDN module）拦截未登录 | login.html:1334, index.html:643 |
| 访客模式 | **不存在**（无 UI 入口、无 flag） | login.html 全文无 guest/offline |
| localStorage | `fudoki:` 命名空间统一 + 30 键迁移表 + 备份导入共用键表（今日完成，质量好） | main-js.js:80-160 |
| 备份 | v2 payload（排除 samples/locked），设置弹窗+用户菜单双入口 | main-js.js:251-330 |
| 文档存储 | 全部文档序列化进 `fudoki:texts` 单键 | main-js.js:302 |
| 分词 | kuromoji 本地 .dat.gz（~17MB），分析快（21 tokens <1s） | segmenter.js |
| TTS | Web Speech API 单实现（今日已收敛），底部迷你控制条 | static/js/tts.js (2KB) |

### 1.2 性能实测（:8831 本地服务，Chrome 145 headless）
| 指标 | 实测值 | 评价 |
|---|---|---|
| 启动→主应用可交互（本地模式） | ~6-8s | 可接受 |
| analyzeText（21 token 短文） | <1s（kuromoji 就绪后） | 优 |
| 词典全量加载 | 进入页面后后台拉 109MB，实测 2 分钟观察窗内完成，期间 UI **零进度提示** | 差 |
| lookup('天気')（命中早停） | 48.5ms | 勉强 |
| getDetailedInfo（console 直调） | 31.5ms | 勉强 |
| lookup 未命中词（最坏） | 全扫 213K 条，估 500ms-2s/次，每次点击都重扫 | 差 |
| 内存 | 109MB JSON → JS 对象约 3-5x 放大（估 300-500MB heap），未精确测量 → 列为待测项 | 风险（移动端） |

### 1.3 体验断点清单（按严重度）
| # | 严重度 | 断点 | 实测证据 |
|---|---|---|---|
| B1 | 🔴 P0 | **token 翻译卡死**：点分词后详情面板永远"正在分析文本..."，词典 ready 后也不更新；重点击后面板仍显示旧 token（点テンキ显示テスト）。console 直调 service 31ms 正常 → UI 链路断（loadTranslation main-js.js:4867 / 占位符 dictionary.js:460 / i18n.js:308） | 124s 轮询 + 重点击 30s 轮询截图 |
| B2 | 🔴 P0 | **首查=等 109MB 全量加载**：无进度条、无懒加载、无按需分片；慢网络下 2-5 分钟"翻译:正在分析文本..." | dictSvcReady 轮询从 false→true 跨越 ~2min |
| B3 | 🔴 P0 | **离线/被墙时登录页静默死机**：Firebase module 加载失败 → Google 按钮点击无任何 handler、无错误提示 | Network.setBlockedURLs 屏蔽 gstatic 后点击实测 |
| B4 | 🟠 P1 | **"本地模式"不可达**：主应用本地功能完整（文档/分析/词典全可用，实测），但在线时未登录用户被门禁弹回 login.html，无"不登录直接用"入口 | 屏蔽 gstatic 后 index.html 一切正常 vs 正常网络未登录被弹回 |
| B5 | 🟠 P1 | 查询无索引：未命中词全表扫描，每次点击重复扫描，无缓存 | dictionary-service.js 线性扫 |
| B6 | 🟡 P2 | 加载文案误导：i18n `loading` = "正在分析文本..." 被用作词典加载占位 | i18n.js:308 |
| B7 | 🟡 P2 | texts 单键存全部文档：5MB localStorage 配额，大文档/多文档 QuotaExceeded 会静默丢数据（catch 吞掉） | main-js.js:302 |
| B8 | 🟡 P2 | 备份仅手动：无自动提醒、无定期导出；恢复流程代码完备但本轮 E2E 未跑完（待验收项） | main-js.js:6549 |

---

## 二、功能增强提案（P0/P1/P2）

> 工作量：S=半天内 M=1-3天 L=3天+。每项含用户故事/实现要点/验收标准。

### P0（修核心：不修完别做新功能）

**F-P0-01 修复 token 翻译卡死 + 详情面板刷新**
- 用户故事：学习者点任何分词，1 秒内看到翻译（或明确的加载/失败态），再点别的词面板正确切换。
- 实现要点：① 复现 loadTranslation 断链（怀疑：详情面板被移动到 body 后 `element.querySelector('.translation-content')` 取不到 → activeTokenDetails 回溯条件 `element===` 不成立；或 await init 期间面板被重建导致引用悬空）；② 修复后加防御：查词结果按 token surface+timestamp 对账，过期结果丢弃；③ 面板内容必须跟随最新点击。
- 工作量：S-M
- 验收：冷加载（清 cache）状态下点词 → 词典加载期间显示真实进度 → 加载完自动填充翻译；连点 3 个不同词，面板内容依次正确。E2E 断言 `.translation-content` 文本最终 ≠ 占位符。

**F-P0-02 词典内存索引（quick win）**
- 用户故事：查过的词秒开；没查过的词不再全表扫描。
- 实现要点：加载完成后一遍构建 `Map<headword, entryIndex[]>`（kanji+kana 两种键），查询 O(1)；结果缓存 LRU（100 条）；构建期间 UI 显示进度。
- 工作量：S-M（不换数据文件，纯 runtime）
- 验收：lookup 未命中词 <5ms；命中 <1ms；内存增量 <150MB；首次索引构建 <3s 且有进度提示。

**F-P0-03 离线降级 + 访客模式入口（谨慎增强，不动 Firebase 架构）**
- 用户故事：① 无网/被墙时打开 login.html，看到"离线模式，本地使用"按钮而非死按钮；② 在线但不想登录的用户可点"跳过登录"直接进主应用，云同步按钮置灰并提示登录后可用。
- 实现要点：login.html 加次按钮，设置 `localStorage['fudoki:guest']='1'`；index.html 门禁 module 的 `onAuthStateChanged(!user)` 分支先检查该 flag，有则留在主应用（**不删任何 Firebase 代码**，只在跳转处加一个条件）；门禁 module 加载失败（catch/timeout）时同样检查 flag 放行；登出时清 flag。SDK 加载失败时给 login 页按钮降级提示（"网络不可用，可离线使用"）。
- 工作量：M（含 Firebase 域名失败的 promise 超时处理）
- 验收：屏蔽 gstatic 情况下 login 可点"离线使用"进主应用；正常在线访客可跳过登录；已登录用户行为完全不变（回归）。

### P1（学习者核心价值）

**F-P1-01 词汇本 + SRS 间隔重复复习**
- 用户故事：查过的词一键进词汇本（默认自动收藏可开关）；每天打开 fudoki 先过一遍到期复习卡（词→回想义→翻面看答案+例句读音，SM-2 评级）。
- 实现要点：新 LS 键 `fudoki:vocab`（注意 texts 单键教训——词汇量大时评估 IndexedDB）；数据结构 {surface, lemma, reading, gloss, addedAt, srs:{ease,interval,due,reps,lapses}, srcDocId}；复习 UI 用现有 token-pill 风格；云同步走现有 Firestore 链路增量集合（红线内：新增 collection 不改已有模型）。
- 工作量：M-L
- 验收：查词→收藏→复习→到期日正确推进（SM-2 单元测试）；卸载重装后词汇本随备份导出/恢复。

**F-P1-02 词典按需分片加载（109MB 索引方案，重点）**
见「三、性能优化清单」PERF-02，此处不重复。

**F-P1-03 JLPT 分级着色 + 词频分层显示**
- 用户故事：读文章时一眼看出哪些词是 N5-N1 级，生词密度高的段落重点对待。
- 实现要点：开源 JLPT 词表（如 elzup/jlpt-word-list 或 JMdict 无此数据，需另挂 ~8K 词小文件）；分析时对每 token 标注级别；UI：可选按 N 级高亮/下划线；图例。
- 工作量：M
- 验收：示例文段 N5/N3/N1 词正确着色（抽样 20 词人工校对）；开关即时生效。

**F-P1-04 高频词统计 + 阅读难度概览**
- 用户故事：分析完成后看面板：本文总词数/唯一词数/各级占比/Top20 高频词（点击可查）。
- 实现要点：analyzeText 结果聚合（已 tokenize，零额外成本）；难度分 = 加权 JLPT 分布；渲染进现有分析面板。
- 工作量：S-M
- 验收：与 F-P1-03 联动；对 3 篇不同难度样本文输出合理梯度。

**F-P1-05 TTS 跟读模式（shadowing）**
- 用户故事：段落播放→自动暂停→我录音跟读→回放对比（原声/我的）。
- 实现要点：现有 TTS 分段队列上加"跟读模式"开关：utterance.onend 后开 MediaRecorder（getUserMedia 权限），录音存 Blob（IndexedDB），双播放器对比 UI；无麦克风权限降级为纯暂停复读。
- 工作量：M
- 验收：原声-录音-原声流程走通；拒绝权限时不报错、降级可用。

**F-P1-06 例句支持**
- 用户故事：查词看到 2-3 条真实例句（带读音和翻译）。
- 实现要点：Tanaka Corpus（JMdict 配套 sentences，~200K 句）离线切片成「词→例句索引」小 JSON（构建期生成，按词首分片）；词卡内嵌例句区。
- 工作量：M-L（含数据构建脚本）
- 验收：常见动词/名词命中 ≥2 例句；索引按需加载不拖慢首查。

### P2（锦上添花）

**F-P2-01 动词变位还原查询**：kuromoji 已输出 lemma，词典查不到 surface 时自动用 lemma（部分已有，main-js.js 别名映射可推广为形变表）→ 补齐 conjugation→dictionary form 映射兜底。S。
**F-P2-02 音→汉字反向查询**：词典 UI 加"读音查词"tab，索引 kana→entries（F-P0-02 索引天然支持反向）。S。
**F-P2-03 中日方向词典**：JMdict gloss 英文为主；方案：挂 CC-CEDICT 转换的日中词表（社区有 JMdict→中文 gloss 数据，如 JMdict-cn），或 Sense 的 languageSource(chi) 已有少量中文（formatEntry 已解析 chineseSource）。M。
**F-P2-04 EPUB 导入分析**：epub.js（MIT）解包 → 抽纯文本章节 → 逐章塞进新文档；大书按章拆多文档。M。
**F-P2-05 本地文件夹导入**：`showDirectoryPicker()`（Chrome 系）遍历 .md/.txt 批量建文档。S。
**F-P2-06 只读分享（静态站约束）**：三档：① 小文档：内容 deflate+base64 编进 URL hash（`#share=...`，index 加载时解码建临时只读文档）零后端；② 正式方案：Firestore 增 `sharedDocs` 只读集合 + 短 ID（红线内增量）；③ 降级：导出 .fudoki.json 文件直接发。M。
**F-P2-07 语法点标注（TEG/CHiP 评估结论）**：TEG（Tsukuba Web Treebank）/CHiP 均无公开稳定免费 API，学术语料需申请；可行替代：本地规则库（助词搭配/句型模式 ~50 条常见 N3-N1 语法点正则+词性序列匹配）标注，准确率有限，定位"提示"而非"教学"。M，可砍。
**F-P2-08 TTS 语速分段控制**：段落列表每段独立 rate 覆盖全局。S。
**F-P2-09 文档存储迁移 IndexedDB**：解 B7 配额风险；保 localStorage 兼容双写一版。M。

---

## 三、性能优化清单（109MB 词典是重点）

**PERF-01 内存 Map 索引（=F-P0-02）**：加载后建 headword→indices Map。收益：查询 O(1)、未命中不再全扫。代价：额外 ~100-150MB 内存、构建 1-3s。S-M。

**PERF-02 构建期按需分片（目标态，=F-P1-02）**：
- 现状问题根源：109MB 全量拉取是为查 1 个词。
- 方案 B（推荐）：构建脚本把 JMdict 按 **headword 读音首字符（五十音 + 英数）切 ~70-120 片**，每片 0.5-3MB；另生成全局小索引 `headword→片号`（Map 序列化，~3-5MB，或同样按首字符拆分零全量）。查询流程：词→片号→fetch 单片→Map 内 O(1)。首查网络量从 109MB → ~3MB。缓存：IndexedDB 存已拉分片 + ETag。
- 方案 C（进阶可选）：SQLite WASM + HTTP Range（sqljs-httpvfs），GitHub Pages 支持 Range 请求；零全量、真按页读取；工程量 L，作为方案 B 落地后的演进项。
- 收益指标（验收）：首查网络传输 <5MB；首查延迟（本地盘）<500ms；常查 50 词后总下载 <15MB；heap 峰值 <150MB。
- 工作量：M-L（数据构建脚本 + service 改造 + IndexedDB 缓存层）。

**PERF-03 查询缓存**：LRU 100 条 surface→result（sessionStorage 或内存），重复点击零开销。S。

**PERF-04 加载体验**：词典初始化期间 token 面板显示真实进度（"词典 35% (74/213K)"），完成后自动补填当前悬停/点击词。S。（依赖 F-P0-01）

**PERF-05 移除 setTimeout 节流合并**：PERF-02 后单片 parse 无需分批 yield。S。

**PERF-06 启动测量基线**：补 heap 快照 + Performance API 埋点（本轮内存未精测，作为 Phase A 首项，先立基线再优化）。S。

---

## 四、Phase A/B/C 实施顺序

**Phase A（修复与地基，~1 周）**
1. F-P0-01 翻译卡死修复（最高优先：核心流程不可用）
2. F-P0-02 内存 Map 索引 + PERF-03 缓存 + PERF-04 加载进度
3. F-P0-03 离线降级 + 访客入口（Firebase 红线内条件分支）
4. PERF-06 基线埋点 + B8 备份恢复 E2E 补验收
> 出口标准：冷启动→点词→1s 内出翻译（或进度条）；离线可用；未命中查询 <5ms。

**Phase B（学习者价值，~2 周）**
1. PERF-02 按需分片（替换全量加载，含构建脚本 + IndexedDB 缓存）
2. F-P1-01 词汇本 + SRS（云同步走增量 collection）
3. F-P1-03 JLPT 着色 + F-P1-04 高频词/难度面板
4. F-P1-05 跟读模式
> 出口标准：首查 <5MB 网络；复习流程闭环；难度面板对样本梯度正确。

**Phase C（扩展与生态）**
F-P1-06 例句 → F-P2-04 EPUB → F-P2-06 分享 → F-P2-09 IndexedDB 迁移 → 其余 P2 按需。语法点标注（F-P2-07）确认为低性价比，默认不做。

---

## 五、Top 5 推荐 + 先做哪个

1. **F-P0-01 修 token 翻译卡死**——核心流程（查词）现在等于坏的，一切功能价值以此为基础
2. **PERF-02 词典按需分片（+F-P0-02 索引先行）**——首查 109MB→<5MB，移动端内存风险一并解除，是最大的体验杠杆
3. **F-P0-03 访客/离线模式**——解锁"本地优先工具"的产品定位，改动小（门禁加一个条件分支）
4. **F-P1-01 词汇本 + SRS**——对"在日工作的学习者"价值最大的新功能，把查词行为沉淀为学习资产
5. **F-P1-03/04 JLPT 着色 + 难度/高频词面板**——tokenize 结果已现成，性价比最高的"学习感"功能

**先做：F-P0-01**。理由：B1 是唯一"功能存在但完全不可用"的断点，实测复现稳定、定位线索齐（main-js.js:4867 loadTranslation / dictionary.js:460 占位 / 面板移位后引用悬空假说），半天到一天可修；修完立刻让"词典查词"这个主打流程恢复可用，也为 PERF-04 进度填充铺路。