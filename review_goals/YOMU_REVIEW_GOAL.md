# Yomu 深度 Review Goal

> 仓库：`~/development/yomu`  
> 在线：https://yomu.iamcheyan.com  
> 审查日期：2026-08-14  
> 审查方式：静态代码走读 + 本地 `python3 -m http.server` 真机浏览器验证（桌面 800×457 / 手机 375×667）  
> 用户痛点对照：**书籍列表 / 搜索 / 分类 / 目录坏了，只有阅读界面对**

---

## 0. 一句话结论

Yomu 是「静态 SPA + 本地 JSON 书库 + Android WebView」的离线日语阅读器。  
**阅读器路径（打开已有 JSON → 分段渲染 → 进度/假名）基本可用**；  
**书库路径（书架布局、书库网格可见性、下载覆盖率、章节目录）存在多处 P0 级缺陷**，足以解释「列表/搜索/分类/目录都坏了」的体感。

---

## 1. 现状地图

### 1.1 产品定位

| 项 | 现状 |
|---|---|
| 形态 | 纯前端静态站（GitHub Pages）+ Android WebView APK |
| 内容源 | 青空文库公版；本地预解析 JSON，不再实时拉 `.txt` |
| 目标设备 | 墨水屏平板 / 手机 / 桌面浏览器 |
| 学习辅助 | 青空 ruby 内置假名、Kuromoji NLP 假名、段落级 AI 翻译（部分书） |
| 后端 | **无**；无搜索索引服务、无章节 API |

### 1.2 目录与职责

```text
index.html                 三视图壳：书架 / 書庫 / 阅读器 + 设置/模态框
css/style.css              墨水屏风格；body overflow:hidden（非阅读态）
js/app.js                  应用控制器：书架、书库、下载、路由、设置（~1466 行，上帝对象）
js/reader.js               阅读器：加载 JSON、分段渲染、进度、翻译切换、手势
js/storage.js              localStorage + IndexedDB + Android 外部存储桥
js/aozora.js               下载：本地 data/novels → GitHub raw 回退
js/tokenizer.js            Kuromoji 初始化 / 词典下载 / 假名渲染
data/books.json            首页精选 20 本
data/aozora_catalog_preview.json   书库首屏 100 条
data/aozora_catalog_compact.json   全量目录 15035 条（~6MB）
data/aozora_catalog.json           全量源（~7.3MB，前端不读）
data/novels/*.json         11041 部作品正文（无 chapters 字段）
data/dict/jmdict.json      空壳/未接线（前端 0 引用）
libs/kuromoji.js + dict/   形态素分析（Web 打包；Android 运行时下）
android/                   WebView + YomuNative 文件桥
scripts/                   目录同步、翻译、catalog 构建
docs/vertical-reading-mode-notes.md  竖排设想（未实现）
```

### 1.3 运行时视图与数据流

```text
                    ┌─────────────────────────────┐
  #library          │  book-list-view             │
  Yomu.showBookList │  books.json + downloaded    │
                    │  _renderBookList()          │
                    └─────────────┬───────────────┘
                                  │ openBook(id)
                    ┌─────────────▼───────────────┐
  #book/{id}        │  reader-view                │
                    │  IDB / novels/{id}.json     │
                    │  YomuReader.openBook()      │  ← 当前最稳路径
                    └─────────────────────────────┘
                                  ▲
                    ┌─────────────┴───────────────┐
  #store            │  store-view                 │
  Yomu.showStore    │  preview → compact catalog   │
                    │  filter/search/download     │  ← 布局 + 覆盖率重灾区
                    └─────────────────────────────┘
```

| 数据 | 条数 | 加载入口 | 用途 |
|---|---:|---|---|
| `books.json` | 20 | `YomuReader.init()` | 首页书架 |
| `aozora_catalog_preview.json` | 100 | `Yomu._loadStorePreviewCatalog()` | 书库秒开 |
| `aozora_catalog_compact.json` | 15035 | `Yomu._loadFullStoreCatalog()` | 搜索/筛选全集 |
| `data/novels/*.json` | 11041 | `openBook` / `YomuAozora.downloadBook` | 正文 |
| catalog ∩ novels | **~11011** | — | 可下载成功 |
| catalog − novels | **~4024 (26.8%)** | — | 必失败下载 |

### 1.4 模块调用关系（关键函数）

| 用户动作 | 调用链 |
|---|---|
| 启动 | `DOMContentLoaded` → `Yomu.init` → `Storage.init` → `Tokenizer.init` → `Reader.init` → `_renderBookList` |
| 书架翻页 | `nextHomePage` / `prevHomePage` → `_getFilteredLibraryBooks` → `_renderBookList` |
| 书架分类 | `setHomeFilter` → `_homeFilters` → `_renderBookList` |
| 打开书 | `openBook` → `YomuReader.openBook` → `Storage.getBookContent` 或 XHR `novels/{id}.json` → `_renderNextChunk` |
| 进书库 | `showStore` → `_loadStorePreviewCatalog` → `_renderStore` → `_loadFullStoreCatalog` |
| 书库搜索 | `input#store-search-input` → `filterStore` → `_getFilteredStoreBooks` → `_renderStore` |
| 书库筛选 | `setStoreFilter` → `_storeFilters` + `_bookCategory` → `_renderStore` |
| 下载 | `downloadBook` → `YomuAozora.downloadBook` → `Storage.saveBookContent` + `addDownloadedBook` |
| 返回 | `back` → `history.back` / `showBookList`；Android `onBackPressed` → `webView.goBack` |

### 1.5 各子系统健康度（审查实测）

| 子系统 | 状态 | 说明 |
|---|---|---|
| 阅读器打开/渲染/进度 | ✅ 可用 | 羅生門 50 段、滚动进度 8%、frontmatter 11 行均正常 |
| 翻译角标切换 | ⚠️ 半可用 |  bundled 20 本里约 7 本有非空翻译；XSS 风险 |
| 假名（内置 ruby） | ✅ 可用 | `_renderPara` 处理 `｜…《…》` |
| 假名（Kuromoji） | ⚠️ 依赖 | Web 有 `libs/dict`；Android 需下载 ~18MB |
| 书架列表 | ❌ 布局坏 | 短视口每页仅 2 本；移动端卡片被 `overflow:hidden` 裁切 |
| 书库网格 | ❌ 不可见 | 筛选面板过高 + body 禁滚 → 卡片/分页在视口外 |
| 书库搜索逻辑 | ⚠️ 逻辑 OK 体验差 | 15035 全量 `includes` ~70–110ms/键；结果不可见 |
| 书库分类逻辑 | ⚠️ 逻辑 OK 体验差 | fiction 8673 等计数正确，但结果同样不可见 |
| 下载 | ❌ 覆盖不足 | 26.8% 目录无本地/远端 JSON；错误文案误导为「网络」 |
| 章节目录 TOC | ❌ 缺失 | 样本 0/300 含 `chapters`；UI 无 TOC 面板 |
| 竖排 | ❌ 未做 | 仅有 docs 笔记 |
| 首页翻译筛选 | ❌ 死代码 | 引用不存在的 `#home-translation-select` |

---

## 2. Bug 清单（定位到函数级）

优先级：P0 = 直接导致「列表/搜索/分类/目录不可用」；P1 = 功能错误/数据一致性；P2 = 体验/安全/可维护。

### 2.1 书籍列表（书架 `book-list-view`）

| ID | 级 | 现象 | 根因（函数/位置） | 复现 |
|---|---|---|---|---|
| **L-01** | **P0** | 书架每页只有 2 本书，要翻 10+ 页 | `Yomu._calculatePageSize`（`app.js` ~396–414）：`minRowHeight=170`，短视口算出 `rows=1` → `_adaptivePageSize = rows*2 = 2`；`_renderBookList` 用该值切片 | 800×457：`pageInfo=1/10`，`cards=2` |
| **L-02** | **P0** | 移动端书架卡片被裁切，后半页看不见且无法滚动 | `css/style.css`：`html,body{overflow:hidden}` + `.home-adaptive-grid{overflow:hidden!important}`；`_calculatePageSize` 与真实卡片高度（含进度条）不一致，模板行高 160px 装不下内容 | 375×667：第 3、4 张 `clipped:true`，`scrollY` 锁死 0 |
| **L-03** | P1 | 书架无标题/作者搜索 | `index.html` 书架区只有分类 chips + 翻页，无 search input；仅书库有 `#store-search-input` | 打开首页即可见 |
| **L-04** | P1 | 「翻译筛选」永远不生效 | `_renderHomeFilters`（`app.js` ~500–503）读 `#home-translation-select`，**HTML 中不存在该元素**；`_homeFilters.translation` 永远是 `''` | 代码静态对照 |
| **L-05** | P1 | 书架分类大量依赖硬编码 ID，NDC 缺失 | `books.json` 20 本中仅 4 本有 `ndc`；`_bookCategory`（`app.js` ~908–925）对无 NDC 书：白名单 ID→否则有 title 就归 `fiction` | 实测：`羅生門` NDC K913 → **児童文学**；多数无 NDC 书全进小説 |
| **L-06** | P2 | 删除下载书后，若该书同时在 `books.json` 仍显示，但不标 isDownloaded | `_getLibraryBooks` 合并逻辑正确，但 bundled 与 store 双 ID 时可能残留孤儿进度 | 见 D-03 |

### 2.2 书库搜索 / 列表（`store-view`）

| ID | 级 | 现象 | 根因（函数/位置） | 复现 |
|---|---|---|---|---|
| **S-01** | **P0** | 书库打开后**看不到任何书卡与分页**，像「搜索/列表坏了」 | ① `body/html overflow:hidden`（非 reader）② `.store-view{overflow:hidden}` ③ 筛选面板（作者 12 + 分类 6 + 文字遣い 3）在小屏占满高度 ④ `#store-grid` 被挤到视口下方 ⑤ 文档高度 = 视口高度 → **无法滚动** | 375×667：`gridTop=756 > 667`，`nextBtnTop=775`，`scrollable=false`；800×457：`gridTop=477` 同样出屏 |
| **S-02** | **P0** | ~26.8%（4024/15035）条目点「オフライン保存」必失败，提示「接続を確認」 | `YomuAozora.downloadBook`（`aozora.js` ~8–23）只找 `data/novels/{fileId}.json` 与 GitHub raw 同路径；catalog 有而 novels 无 → 404；`downloadBook` catch（`app.js` ~1012–1018）统一网络错误文案 | 下载 `57975_txt_63036`（音楽に就いて）→ モーダル「エラー」 |
| **S-03** | P1 | 2265 条 `fileId` 为日文标题等非标准串（如 `クリスマス`），本地必无文件 | 上游 catalog 构建/`build_catalog.py` 从 URL 抽 fileId 失败时回填异常值；compact 原样带入 | 统计：`non-standard fileIds=2265` |
| **S-04** | P1 | 搜索每次全量扫 1.5 万条 + 重建筛选 chips | `filterStore` → `_getFilteredStoreBooks` → 每本 `_storeSearchText` join 10+ 字段；`_renderStoreFilters` 每次重扫全库计作者频次 | 桌面 `filterStore('夏目')` ~113ms；墨水屏/低端机更卡 |
| **S-05** | P1 | 去重键过粗，可能吞掉同名不同作品 | `_getFilteredStoreBooks`（`app.js` ~787–792）：`key = title\|author\|authorId`，不含 `workId/fileId` | 逻辑审查 |
| **S-06** | P2 | 书库分页固定 10，不响应高度；与书架 adaptive 不一致 | `_pageSize = 10`（`app.js` ~22）；`_renderStore` 用 `_pageSize` 而非 `_adaptivePageSize` | 对照 `_renderBookList` |
| **S-07** | P2 | 搜索框无防抖；输入即同步重渲染 | `index.html`：`oninput="Yomu.filterStore(this.value)"` 无 debounce | 快速输入可见卡顿 |
| **S-08** | P2 | 筛选 chips 每次 `innerHTML` 全量重建，焦点/滚动位置丢失 | `_renderStoreFilters` 整段重写 `#filter-authors` 等 | 点分类后作者区跳动 |

### 2.3 分类（书架 + 书库共用）

| ID | 级 | 现象 | 根因（函数/位置） | 复现 |
|---|---|---|---|---|
| **C-01** | P1 | NDC 规则把「K913」整类打成児童文学 | `_bookCategory`：`/NDC\s*K/` **优先于** `/NDC\s*913/`；羅生門 `NDC K913` → children | 书架点児童文学可见羅生門 |
| **C-02** | P1 | 大量作品无有效分类语义 | 无 NDC 且不在硬编码列表 → 有 title 就 `fiction`；书库 15035 里「小説」膨胀到 8673 | 书库分类计数实测 |
| **C-03** | P2 | 分类标签与青空 NDC 完整体系不对齐 | 仅 6 桶（fiction/children/essay/poetry/drama/foreign）；忽略哲学/历史等 | 产品设计缺口 |
| **C-04** | P2 | 书库作者 chip 只取 Top12，冷门作者只能靠搜索 | `_renderStoreFilters` `.slice(0, 12)` | UI 可见 |

### 2.4 目录（TOC / 章节）

| ID | 级 | 现象 | 根因（函数/位置） | 复现 |
|---|---|---|---|---|
| **T-01** | **P0** | **整个 App 没有章节目录 UI**（用户说的「目录坏了」的主因） | `index.html` / `app.js` / `reader.js` 均无 TOC 面板、无章节跳转入口 | 全文检索无 TOC/目次/chapter-nav |
| **T-02** | **P0** | 数据层无章节结构 | `data/novels/*.json` 统一 `paragraphs[]`（+ 可选 `translations`/`aozora_info`）；随机 300 本 **0 本含 `chapters`** | 数据抽样 |
| **T-03** | P1 | 阅读器预留了 chapters 分支，永远走不到 | `YomuReader.openBook`（`reader.js` ~113–130）：`if (bookData.chapters)` 死分支；实际全走 `paragraphs` | 代码 + 数据对照 |
| **T-04** | P1 | 长篇（如こころ 1346 段）只能线性滚，无法跳章 | 无 TOC + 无限滚动按段追加（`_chunkSize=50`），中后部跳转需连续 `_renderNextChunk` | 打开 `kokoro` / `773_ruby_5968` |
| **T-05** | P2 | 正文里残留青空「大見出し」标记，未升格为章节 | 例：こころ首段 `［＃２字下げ］上　先生と私［＃「上　先生と私」は大見出し］`；`_renderPara` 只删 `［＃...］`，**不解析为 header** | 打开こころ看首屏 |

### 2.5 下载 / ID / 打开链路

| ID | 级 | 现象 | 根因（函数/位置） | 复现 |
|---|---|---|---|---|
| **D-01** | P1 | 双 ID 体系：slug（`kokoro`）vs fileId（`773_ruby_5968`） | `books.json` 混用历史 slug 与 fileId；catalog 一律 fileId；磁盘上**两份相同正文**并存 | `kokoro.json` 与 `773_ruby_5968.json` 均 1346 段、首段相同 |
| **D-02** | P1 | 从书库再下「こころ」会变成另一条书架记录 | `downloadBook` 用 catalog `fileId`；`_getLibraryBooks` 按 `id` 去重，slug≠fileId → 双份 | 书库搜こころ再下载 |
| **D-03** | P1 | 进度/已读按 id 存，双 ID 进度不共享 | `YomuStorage.saveProgress(bookId, …)` key = 打开时 id | 分别打开两 id |
| **D-04** | P2 | Android 上 catalog/books 带 `?t=timestamp` 缓存破坏 | `_fetchLocalJson` / `Reader.init`：`path + '?t=' + Date.now()`；部分 WebView 对 `file:///android_asset/...?t=` 返回失败 | 风险点：Android 书架空列表（若 XHR 失败会落入硬编码 1 本 fallback） |
| **D-05** | P2 | `parseAozora` 死代码 | `aozora.js` ~43–93 从未被 `downloadBook` 调用；下载只吃预生成 JSON | 静态调用图 |
| **D-06** | P2 | 翻译 HTML 未转义 | `toggleTranslation`（`reader.js` ~515+）`transHtml` 直接拼 `t.text` / model 名 | 安全审查 |

### 2.6 布局 / 路由 / Android

| ID | 级 | 现象 | 根因 | 复现 |
|---|---|---|---|---|
| **U-01** | **P0** | 非阅读态全局禁滚 | `css/style.css` ~21–25：`html,body{height:100vh;overflow:hidden}`；仅 `.reader-active` 开滚 | 书库/书架溢出内容永久不可达 |
| **U-02** | P1 | 书库与书架共用 `home-adaptive-grid` 的 `overflow:hidden`，书库更不适合 | 书库内容（搜索+三组 filter+grid+pagination）远超一屏 | 见 S-01 |
| **U-03** | P2 | `showStore` 每次打开重置 `_storePage=0`，丢翻页位置 | `showStore` ~646 | 体验 |
| **U-04** | P2 | Android `onBackPressed` 只 `webView.goBack`，不调用 `Yomu.back()` | 设置面板/info card 打开时物理返回可能直接退出视图栈 | `MainActivity.java` ~330–337 |
| **U-05** | P2 | APK 只打包 20 本 + compact catalog；书库下载依赖网络拉 raw | `android/app/build.gradle` `bundledBookIds`；`YomuAozora.GITHUB_RAW` | 离线书库不可用 |

### 2.7 与用户痛点的映射

| 用户原话 | 主因 Bug | 次因 |
|---|---|---|
| 书籍列表坏了 | **L-01, L-02, U-01** | L-04, L-05 |
| 搜索坏了 | **S-01**（结果不可见） | S-04 卡顿、S-02 下了也打不开 |
| 分类坏了 | **S-01** + **C-01/C-02**（可见性 + 语义错） | L-05 |
| 目录坏了 | **T-01, T-02**（功能不存在） | T-04, T-05 |
| 只有阅读界面对 | 阅读器路径避开了 overflow 陷阱（`reader-active` 开滚） | 进度/假名相对完整 |

---

## 3. 架构问题

### 3.1 上帝对象 `Yomu`（app.js）

- 路由、书架、书库、下载、设置、模态框、HTML 转义全揉在一个 object。
- 无模块边界 → 改布局必碰筛选，改下载必碰路由。
- **建议**：拆 `LibraryView` / `StoreView` / `DownloadService` / `Router`（可先不换构建工具，用多文件 IIFE/全局命名空间）。

### 3.2 数据契约混乱

| 问题 | 影响 |
|---|---|
| 三套 ID：历史 slug / workId / fileId | 重复书、进度分裂、APK/Web 行为不一致 |
| `books.json` 字段 ⊂ catalog 字段（无 fileId/titleKana/orthography） | 书架分类/搜索能力弱于书库 |
| novels JSON 无 `chapters`，阅读器却写了 chapters 分支 | 死代码 + TOC 无法落地 |
| catalog 15035 vs novels 11041 不对齐 | 书库「可点不可下」 |
| 同文双文件（slug + fileId） | 仓库体积膨胀（novels 已 647MB 级） |

### 3.3 「分页网格 + 禁滚」伪自适应

- 设计意图：墨水屏一屏 N 本书、少滚动。
- 实现：`overflow:hidden` + 用容器高度反推 pageSize。
- 失败点：卡片真实高度 > 估算行高；书库筛选区高度未纳入计算；书库根本不该用同一套「无滚动一屏网格」。
- **结论**：书架可保留「一屏分页」，但必须测量真实 card 高度或给最小 pageSize 下限；书库应改为**可滚动列表**（或虚拟列表）。

### 3.4 无索引的客户端全量搜索

- 6MB JSON 一次进内存，每次 keyup 线性 filter + 重建 DOM。
- 无 Web Worker、无前缀索引、无 lunr/MiniSearch。
- 规模再涨或上墨水屏低端 CPU 会明显卡。

### 3.5 双端存储分叉

| 环境 | 设置/进度 | 书内容 | 词典 |
|---|---|---|---|
| Web | localStorage | IndexedDB | `libs/dict` 或 CDN |
| Android | localStorage + `/sdcard/Yomu/data/*.json` | IDB + 外部 `novels/` | 外部 `dict/` 运行时下 |

- 桥接 API 同步阻塞主线程写大 JSON 有 ANR 风险。
- `?t=` cache bust 与 `file://` 不兼容风险（D-04）。

### 3.6 构建与发布

- APK 通过 Gradle `syncWebAssets` 拷贝根目录；catalog compact 进包但 novels 仅 20 本 → 书库在 APK 内大部分条目离线不可用。
- Git 含全量 novels（pack ~408MB）→ clone/CI 重。
- 前端无打包/类型检查/测试；靠 `?v=N` 手动 cache bust。
- `scripts/build_catalog.py` 与线上 compact 字段需人工跑 `build_store_catalogs.py`，无 CI 校验 catalog↔novels 覆盖率。

### 3.7 安全与权限

- Android 申请 `MANAGE_EXTERNAL_STORAGE`（所有文件访问）— 对阅读器过重，上架/信任成本高。
- 翻译 HTML 未转义（D-06）。
- `evaluateJavascript` 拼接 filename/error 字符串（MainActivity 下载回调）— 路径含 `'` 可注入。

### 3.8 未接线能力 / 死资产

| 资产 | 状态 |
|---|---|
| `data/dict/jmdict.json` | 未引用 |
| `aozora.js parseAozora` | 死代码 |
| `data/aozora_catalog.json` | 仅脚本源，前端不读 |
| `docs/vertical-reading-mode-notes.md` | 未实现 |
| `reader.js` chapters 分支 | 无数据 |
| `#home-translation-select` | HTML 缺失 |

---

## 4. 功能增强建议（P0–P2）

### P0 — 必须先修（恢复「能浏览、能搜、能下、有目录」）

1. **修复全局滚动/书库布局（修 S-01 / U-01 / L-02）**  
   - 非 reader：允许 `store-view` 自身 `overflow-y:auto`，或取消 body 锁滚、改为内部滚动容器。  
   - 筛选区默认折叠（「絞り込み」一键展开）；默认只显示搜索框 + 结果列表。  
   - 书库**放弃** `home-adaptive-grid` 一屏分页，改连续列表 + 底部分页或无限滚动。

2. **修复书架 pageSize（修 L-01）**  
   - `_calculatePageSize`：提高下限（如至少 6–8 本）、按实测 card 高度计算、或移动端改单列可滚动。  
   - 去掉 `overflow:hidden !important` 对溢出卡片的静默裁切。

3. **目录覆盖率与下载诚实性（修 S-02 / S-03）**  
   - 构建期脚本：标记 `available:true/false`（本地 novels 是否存在）。  
   - UI：不可用条目灰显 / 隐藏「オフライン保存」/ 文案改为「本文データ未収録」。  
   - 清洗 2265 条非法 fileId；compact 与 novels 对齐报告进 CI。

4. **章节目录 MVP（修 T-01–T-05）**  
   - 解析路径（二选一或组合）：  
     a. 构建期从青空 `［＃…は大見出し］/中見出し` 生成 `chapters:[{title, startPara}]`；  
     b. 运行时扫描 paragraphs 启发式提取。  
   - 阅读器增加 TOC 抽屉：点击 → 确保渲染到目标段 → `scrollIntoView`。  
   - 长篇（こころ等）优先验证。

5. **统一 Book ID（修 D-01–D-03）**  
   - 规范：`id === fileId`（如 `773_ruby_5968`）；`books.json` 全部改 fileId；slug 作 `aliases[]` 仅兼容旧进度。  
   - 迁移：打开时若 progress 在 alias 下，合并到 canonical id。

### P1 — 体验与正确性

6. **搜索体验**  
   - input debounce 200–300ms；Web Worker 或预建 `{title,author,kana}` 小索引。  
   - 书架也加搜索（修 L-03）。  
   - 支持假名/罗马字已有字段，补「読み」高亮。

7. **分类校正**  
   - 修正 K913 规则：`K` 前缀表示児童向け，应 `children` 仅当主类为 K* 且非误伤；或 NDC 主表 + 副表分离。  
   - `books.json` 补全 ndc；去掉 title→fiction 兜底，改为「未分類」。  
   - 恢复首页翻译筛选 UI 或删除死代码（L-04）。

8. **下载与离线**  
   - APK：可选「完整书库包」分发（OBB/用户自选下载包），避免 26% 空洞。  
   - 下载进度显示真实 HTTP 状态；失败可重试。  
   - Android 去掉 `_fetchLocalJson` 的 `?t=`（D-04）。

9. **阅读器增强**  
   - 进度条可拖拽跳转（按段比例）。  
   - 书签。  
   - 翻译 `escapeHtml`；多模型翻译折叠。

10. **性能**  
    - catalog 字段再压（去掉 cardUrl 等到点击再补）。  
    - 书库虚拟列表（只挂载可见 DOM）。  
    - `_renderStoreFilters` 缓存 counts，filter 时不重扫。

### P2 — 中期演进

11. **竖排模式** — 按 `docs/vertical-reading-mode-notes.md` 做 MVP（仅 `#novel-content`）。  
12. **词典查词** — 接入或删除 `jmdict`；点词弹释义（与 Kuromoji token 结合）。  
13. **模块化与测试** — 最小 vite/esbuild；对 `_bookCategory` / filter / ID 迁移单测。  
14. **Android 权限收敛** — 用 App-specific storage 替代 `MANAGE_EXTERNAL_STORAGE`。  
15. **PWA** — Service Worker 缓存 novels；`manifest.json` 已有可增强。  
16. **仓库瘦身** — novels Git LFS 或发布物分离；clone 不带全文。

---

## 5. 建议修复顺序（执行路线）

```text
Phase A（1–2 天，解锁浏览）
  A1. CSS：store/library 可滚动；筛选默认折叠          → 消 S-01/U-01
  A2. _calculatePageSize 下限 + 真实高度                → 消 L-01/L-02
  A3. catalog 标记 available + 下载文案                  → 消 S-02 体感

Phase B（2–4 天，目录与 ID）
  B1. 构建脚本生成 chapters / 或运行时抽大見出し         → 消 T-*
  B2. TOC UI + 跳转
  B3. books.json 统一 fileId + 进度迁移                  → 消 D-01..03

Phase C（并行/随后）
  C1. 搜索 debounce + 索引
  C2. 分类规则 + 首页翻译筛选修/删
  C3. Android ?t= 与权限
  C4. 测试与 catalog↔novels CI 门禁
```

---

## 6. 验收标准

### 6.1 P0 验收（必须全部通过）

| # | 场景 | 通过条件 |
|---|---|---|
| A1 | 手机 375×667 打开書庫 | 首屏可见 ≥5 条书卡；搜索框可用；筛选不挡住列表 |
| A2 | 桌面 800×600 打开書庫 | 列表或分页控件在视口内，无需「猜」有没有数据 |
| A3 | 書庫搜索「夏目」 | 结果数 >0 且卡片可见；输入 300ms 内不永久卡死 UI |
| A4 | 書庫分类「小説 / 詩歌」 | 摘要件数变化且列表可见；与 filters 一致 |
| A5 | 书架首页 | 一屏 ≥6 本书（或可滚动看完当前页全部卡片，无裁切） |
| A6 | 下载「本地有 JSON」的书 | 成功进书架并可 `openBook` 读正文 |
| A7 | 下载「本地无 JSON」的书 | **不**显示假网络错误；明确「未収録」且不进入下载中状态 |
| A8 | 打开こころ（或任意长篇） | 存在可打开的 TOC；至少能跳到「上/中/下」或等效大見出し |
| A9 | 阅读器回归 | 打开羅生門：标题/作者/进度保存/返回书架 与现网一致不回退 |
| A10 | ID 统一后 | 书架上「こころ」仅一条；进度在书库入口与书架入口共享 |

### 6.2 P1 验收

| # | 场景 | 通过条件 |
|---|---|---|
| B1 | 书架搜索 | 按题名/作者过滤首页 20+ 已下载 |
| B2 | 分类羅生門 | 不再仅因 K913 误入児童文学（产品裁定后的正确桶） |
| B3 | 翻译筛选 | UI 存在则生效；不存在则代码无残留引用 |
| B4 | Android 冷启动 | `books.json` / catalog 100% 加载成功（无 `?t=` 坑） |
| B5 | 书库筛选性能 | 中端机输入搜索 P95 < 100ms（有 debounce 后的体感无连帧卡顿） |
| B6 | XSS | 翻译字段含 `<script>` 时以文本显示 |

### 6.3 P2 / 回归清单

- [ ] Web：Chrome / Firefox / Safari 书架↔书库↔阅读器路由（hash + 浏览器返回）
- [ ] Android WebView：音量键翻页、物理返回、词典下载、外部存储读写
- [ ] 墨水屏：无动画、对比度、全屏
- [ ] APK 体积：仍只默认打包精选书，不把 11041 本打进 debug APK（除非显式 full flavor）
- [ ] CI/脚本：`catalog.available` 覆盖率报告；非法 fileId = 0
- [ ] 竖排（若做）：仅正文区域，`docs/vertical-reading-mode-notes.md` 范围不扩大

### 6.4 非目标（本次 Goal 明确不做）

- 自建后端搜索服务  
- 完整出版级竖排/禁则  
- 替换青空源或引入版权非公版内容  
- 重写为 React/Vue（除非 P2 模块化阶段评估）

---

## 7. 关键文件速查

| 文件 | 为何关键 |
|---|---|
| `js/app.js` | 书架/书库/下载/分类/路由上帝对象 |
| `js/reader.js` | 阅读器；chapters 死分支；无 TOC |
| `js/aozora.js` | 下载路径与 GitHub 回退 |
| `js/storage.js` | 进度/已下载/IDB |
| `css/style.css` L21–25, L122–126 | overflow 锁滚 + adaptive grid 裁切 |
| `index.html` | 三视图结构；缺首页搜索与翻译 select |
| `data/books.json` | 20 本精选，ID/NDC 不完整 |
| `data/aozora_catalog_compact.json` | 15035 书库索引 |
| `data/novels/` | 11041 正文，无 chapters |
| `android/app/build.gradle` | APK 资源白名单 |
| `android/.../MainActivity.java` | YomuNative、返回键、权限 |
| `scripts/build_store_catalogs.py` | preview/compact 生成 |
| `docs/vertical-reading-mode-notes.md` | 竖排未实现说明 |

---

## 8. 审查环境与证据摘要

```text
本地服务: python3 -m http.server 8931
books.json: 20
catalog_compact: 15035
novels/*.json: 11041
catalog 缺本地文件: 4024 (26.8%)
非法/非标准 fileId: 2265
chapters 字段抽样: 0/300
书库分类计数: fiction 8673 / children 1338 / essay 3168 / poetry 1186 / drama 163 / foreign 507
桌面 800×457 书架: adaptivePageSize=2, page 1/10
手机 375×667 书库: gridTop=756, scrollable=false, body overflow hidden
下载成功样例: 59898_ruby_70679
下载失败样例: 57975_txt_63036 → 伪网络错误
阅读器样例: 18340_ruby_13244 羅生門 50 段, 进度可存
双 ID 样例: kokoro.json ≡ 773_ruby_5968.json (1346 段)
```

---

## 9. 给执行 Agent 的开工指令（可直接派工）

1. 先做 **Phase A**（纯 CSS + `_calculatePageSize` + catalog `available` 标记），用本文 **§6.1 A1–A7** 自测。  
2. 再做 **Phase B TOC + ID**，用 **A8–A10** 自测。  
3. 每个 PR 必须附：修改前后手机 375×667 书库截图或 DOM 量测（`gridTop < innerHeight`）。  
4. 禁止在未修 U-01 前做大范围 UI 美化；禁止引入重型框架作为 P0 依赖。  
5. 数据脚本改动须同步更新 `aozora_catalog_compact.json` / `preview`，并打印 novels 覆盖率。

---

*本文件为审查与修复 Goal，不包含具体 patch。实现时以仓库当前代码为准，函数行号随提交漂移时以符号名为准。*
