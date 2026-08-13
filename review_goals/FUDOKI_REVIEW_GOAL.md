# Fudoki（フドキ）PWA 深度 Review Goal

> 仓库：`~/development/fudoki`（origin: https://github.com/iamcheyan/fudoki）  
> 线上：https://fudoki.iamcheyan.com  
> Review 日期：2026-08-14  
> 性质：浏览器端日语文本分析 + TTS + 多文档笔记 PWA（Firebase Auth/Firestore 同步）  
> 本文档供后续修复 / 重构 / 功能迭代作为**唯一验收基准**。

---

## 0. 一句话定位

**Fudoki** 是一款纯前端（+ Firebase 后端）的日语学习工具：用 Kuromoji.js 做形态素分析，用 Kuroshiro 做假名/罗马音，用 Web Speech API 朗读，用 JMdict 分片词典查释义；支持多文档、Markdown 编辑（EasyMDE）、暗色/多主题、三语文案（ja/en/zh）、PWA 离线缓存、Google 登录与 Firestore 双向同步。

---

## 1. 现状地图（As-Is Map）

### 1.1 目录与体量

| 路径 | 角色 | 规模 |
|---|---|---|
| `index.html` | 主应用壳 + Firebase Auth 门禁 + 清除缓存脚本 | ~836 行 / 52KB |
| `login.html` | Google 登录页 + 同样的清除缓存脚本 | ~1402 行 / 40KB |
| `service-worker.js` | PWA SW：cache-first 静态 + network-first 导航 + 消息协议 | 324 行 |
| `manifest.json` | PWA 清单 | 29 行 |
| `static/main-js.js` | **核心巨石**：文档/UI/TTS/同步/i18n/PWA/主题 | **8291 行 / 317KB** |
| `static/segmenter.js` | Kuromoji + Kuroshiro 封装 | 401 行 |
| `static/styles.css` | 主题变量 + 桌面布局 | 5510 行 |
| `static/mobile.css` | ≤768px 移动端覆盖 | 625 行 |
| `static/js/tts.js` | TTS 模块（**与 main-js 重复实现**） | 572 行 |
| `static/js/i18n.js` | 三语词典 `I18N` | 396 行 |
| `static/js/dictionary.js` | 技术术语覆盖 + 词性解析 `FudokiDict` | 472 行 |
| `static/js/ui-utils.js` | 通知 / 删除确认 | 259 行 |
| `static/libs/dict/dictionary-service.js` | JMdict 分片加载 + 线性查找 | 274 行 |
| `static/libs/dict/*.dat.gz` | Kuromoji 字典 | ~16MB |
| `static/libs/dict/chunks/jmdict_chunk_*.json` | JMdict 分片（213,554 词） | **~109MB** |
| `static/libs/dict/jmdict-eng-*.json.zip` | **未使用的旧 zip** | **~11MB** |
| `static/libs/{kuromoji,kuroshiro*,easymde}/*` | 第三方库（vendored） | — |
| `static/samples.json` | 示例文章种子 | — |
| `static/pwa-assets.json` | SW 预缓存清单 | — |
| `package.json` | 仅 `python3 -m http.server` 启动脚本；vite 未用 | 28 行 |
| `CLEAR_CACHE.md` | `?clear=1` 使用说明 | — |
| `CNAME` | `fudoki.iamcheyan.com`（GitHub Pages） | — |

**总量约 211MB（工作树）/ pack 66.55 MiB；业务 JS+CSS+HTML ≈ 19k 行。**

### 1.2 运行时架构（逻辑分层）

```
┌─────────────────────────────────────────────────────────────┐
│ Browser (PWA / standalone)                                  │
│  login.html ──Google Popup──► Firebase Auth                 │
│       │ onAuthStateChanged                                   │
│       ▼                                                      │
│  index.html                                                  │
│   ├─ Firebase Auth 门禁 (未登录 → login.html)                │
│   ├─ EasyMDE (Markdown 编辑)                                 │
│   ├─ DocumentManager (localStorage: texts/activeId)          │
│   ├─ JapaneseSegmenter (Kuromoji + Kuroshiro)                │
│   ├─ DictionaryService (JMdict chunks, 全量内存)             │
│   ├─ TTS (Web Speech API, ja voices)                         │
│   ├─ i18n (ja/en/zh) + 6 主题                                │
│   ├─ PWA Installer (SW message: CACHE_ASSETS)                │
│   └─ Firestore Sync (users/{uid}/documents|folders)          │
│                                                              │
│  service-worker.js                                           │
│   ├─ Navigation: network-first → index.html fallback         │
│   └─ Same-origin GET: cache-first (fudoki-cache-v1)          │
└─────────────────────────────────────────────────────────────┘
```

### 1.3 核心功能清单（已实现）

| 域 | 能力 | 状态 |
|---|---|---|
| 形态素分析 | 分词 / 品词色 / 假名 / 罗马音 / 词卡详情 | ✅ 可用 |
| 词典 | JMdict 英文 gloss + 技术术语覆盖 + 中文词源字段 | ⚠️ 全量线性扫描，首查慢 |
| TTS | 全文/行/词；暂停/继续；语速 0.5–2.0；音量；进度条；改设置中途重播 | ⚠️ 双实现 + 状态分裂风险 |
| 编辑 | EasyMDE Markdown；字号/字体；自动分析（失焦/结构变化） | ✅ |
| 文档 | 多文档、星标、排序、搜索模态、示例文章、默认锁定文档 | ⚠️ 文件夹同步半残 |
| 同步 | 登录后 2s 初同；改动后 5min 延迟；10min 周期；隐藏页立即同 | ⚠️ 无 tombstone，删除不云删 |
| 认证 | Google Popup only；localStorage `fudoki_user` | ⚠️ 无匿名/访客模式 |
| PWA | manifest + SW + 可控预缓存 + toast 进度 | ⚠️ 缓存版本钉死 v1；清单不完整 |
| 主题/i18n | 6 主题 + auto；ja/en/zh | ⚠️ 部分 UI 硬编码日/中混杂 |
| 清除缓存 | `?clear=1` 保留文档键 | ⚠️ 与备份键前缀不一致 |
| 数据导入导出 | JSON 备份 | ❌ 读写键与运行时键不一致（**失效**） |

### 1.4 数据模型（本地）

```js
// localStorage
texts        // Document[]  — DocumentManager 实际使用
activeId     // string
activeFolder // 'all' | 'favorites' | 'samples' | <userFolderId>
lang, theme, rate, voiceURI, volume, showKana, showRomaji, ...
fudoki_user  // { uid, email, displayName, photoURL }

// Document
{
  id, content: string | string[],
  title?, folderId?, folder?, // folder==='samples' 为示例
  favorite: boolean, locked: boolean,
  createdAt: number, updatedAt: number
}

// Firestore
users/{uid}/documents/{docId}  // content 强制 string
users/{uid}/folders/{folderId}
```

### 1.5 技术债速览（Top）

1. **`static/main-js.js` 8291 行巨石** + 过早 `})();`（L6940）后仍有 1350 行依赖闭包内符号的代码。
2. **TTS 双重实现**：`static/js/tts.js` 挂 `window.*`，`main-js.js` 内又有同名局部实现，`PLAY_STATE` / `isPlaying` 不共享。
3. **HTML 重复 ID**：`userProfileContainer` / `userAvatarBtn` / `logoutBtn` 等整块复制两份（index.html ~L287 与 ~L396）。
4. **导入/导出键名错误**：备份读写 `fudoki_texts` / `fudoki_activeId` / `fudoki_theme`，运行时用 `texts` / `activeId` / `theme`。
5. **词典 O(n) 全表扫描** 21 万词，无索引；JMdict 约 109MB 常驻内存。
6. **仓库含 11MB 未用 zip + 两张 ~2MB logo PNG**；无 LICENSE 文件（README 称 MIT）。
7. **Firebase 配置硬编码**于 HTML；仓库无 `firestore.rules`。
8. **无构建管线**：vite 在 package.json 但未配置；无测试、无 lint、无 CI。
9. **README 引用不存在的 `MARKDOWN_README.md`**。
10. **强制登录**：无访客/本地-only 模式，与「纯浏览器工具」定位冲突。

---

## 2. Bug 清单（按严重度）

### 2.1 P0 — 正确性 / 数据安全（必须先修）

| ID | 标题 | 证据 | 影响 |
|---|---|---|---|
| **B-P0-01** | **导入/导出读写错误的 localStorage 键** | `main-js.js` `collectBackupPayload` / `applyBackup` 使用 `fudoki_texts` / `fudoki_activeId`；`DocumentManager` 使用 `LS.texts='texts'` / `LS.activeId='activeId'`；设置备份键 `fudoki_theme`/`fudoki_lang` 与运行时 `theme`/`lang` 不一致 | **导出内容为空或与真实文档脱节；导入后 DocumentManager 读不到；设置不恢复** |
| **B-P0-02** | **index.html 用户菜单整块 DOM 重复（重复 ID）** | `userProfileContainer`、`userAvatarBtn`、`userDropdownMenu`、`syncDataBtn`、`logoutBtn`、`userExportBtn`、`userImportFile` 等均出现两次（约 L287–393 与 L396–501） | `getElementById` 永远拿到第一份；第二份幽灵 DOM；事件绑定不确定；a11y 失效；样式/点击诡异 |
| **B-P0-03** | **main-js.js IIFE 在 L6940 提前结束** | 文件以 `(() => {` 开头，L6940 `})();` 后仍有 `initUserProfile` / 同步 / 导入导出 / 主题子菜单等 ~1350 行，缩进仍像在闭包内，但已是**脚本顶层** | 顶层代码调用闭包内 `t()` / `setThemePreference` / `setLanguage` / `applyI18n` 时会 `ReferenceError`（部分路径被 `try/catch` 吞掉 → **静默失败**）；PWA 安装 toast 文案回退为 key |
| **B-P0-04** | **云同步不处理本地删除（无 tombstone）** | `performDataSync`：本地无 + 云端有 → **重新下载**；从未 `deleteDoc` 用户主动删的文档 | 用户删除文档后，自动/手动同步会把云端副本拉回来 → **删不掉** |
| **B-P0-05** | **文件夹同步单向且读 `documentManager.folders`（常为 undefined）** | 同步只 `setDoc` 本地 folders；从不 `getDocs` 云端 folders；代码 `window.documentManager.folders \|\| []`，类上未见持久化 `this.folders` | **自定义文件夹跨设备不同步 / 永远不同步** |
| **B-P0-06** | **TTS 双实现导致状态分裂** | `tts.js` 写 `window.isPlaying` / `window.PLAY_STATE` / `window.speakWithPauses`；`main-js.js` 有局部 `let isPlaying` / `let PLAY_STATE` 与局部 `speakWithPauses`/`playSegments`；`playAllText` 走局部，`tts.js` 的 restart 看 `window.*` | 改语速/音色中途重启、暂停按钮、进度条可能与真实播放状态不一致；按钮图标不更新 |

### 2.2 P1 — 功能缺陷 / 安全 / 体验阻断

| ID | 标题 | 证据 | 影响 |
|---|---|---|---|
| **B-P1-01** | 文档列表标题 XSS（属性注入） | `docItem.innerHTML` 中 `title="${cleanTitle}"` 与截断标题未 HTML escape；`stripMarkdown` 不去 `<>"'&` | 恶意文档标题可注入属性/HTML |
| **B-P1-02** | 词卡 `data-token` / 翻译 HTML 拼接缺统一 escape | `loadTranslation` 等处 `innerHTML = ...${mainTranslation}`；词典 gloss 来自 JSON 相对可信，但 token surface 来自用户文本 | 用户文本含 `<` 时破坏 DOM 或注入 |
| **B-P1-03** | 词典查找 O(n) 全表扫描 | `dictionary-service.js` `lookup` 线性遍历最多 213k 词条，每次点击词卡 | 首次/每次查找卡顿 100ms–数秒（低端机更甚）；主线程阻塞 |
| **B-P1-04** | JMdict ~109MB JSON 全量进内存 | 两 chunks 合并为 `allWords[]` | 移动端易 OOM / 标签被杀；首包与离线缓存巨大 |
| **B-P1-05** | 仓库跟踪无用 11MB zip | `jmdict-eng-3.6.1+202****2529.json.zip`；代码只读 chunks | 克隆/部署体积虚高；Pages 带宽浪费 |
| **B-P1-06** | SW `CACHE_VERSION = 'v1'` 永不 bump；`pwa-assets.json` 缺关键资源 | 缺 `login.html`、`mobile.css`、`static/js/*`、`easymde`、`samples.json`、`manifest.json` | 发版后用户长期命中旧 JS/CSS；离线缺文件；「下载离线包」不完整 |
| **B-P1-07** | `?clear=1` 与 CLEAR_CACHE.md 声称保留文档，但 clear 后仍登出并跳转 login | 逻辑先 preserve `texts`/`activeId`，再清 SW 与 `fudoki_user` 并 login | 文档虽在，用户必须重登；与「排查缓存」心智部分冲突；且 clear 脚本在 body 前跑时 `document.body.appendChild` 可能抛错（login 页有 body 等待，index 页直接 append） |
| **B-P1-08** | Firebase 配置（apiKey/appId/projectId）明文写在两个 HTML | `index.html` L757+、`login.html` L1138+ | 属客户端常态但缺 App Check / 仓库无 rules 快照 → 滥用风险不透明 |
| **B-P1-09** | 强制 Google 登录，无本地访客模式 | `onAuthStateChanged` 无 user → `login.html` | 纯分词/朗读场景也要账号；隐私敏感用户流失；离线首次无法用 |
| **B-P1-10** | `appDrawer` 无入口 | `initAppDrawer` 依赖 `#appIcon`，index 中不存在该 id | 应用抽屉死代码；相关 i18n 无效 |
| **B-P1-11** | 登录仅 Google Popup | 无 redirect 回退、无邮箱、无匿名 | 企业策略/内嵌 WebView/部分移动浏览器 Popup 失败即无法用 |
| **B-P1-12** | `authCheckCompleted` 使 Auth 状态只处理一次 | index/login 均 `if (authCheckCompleted) return` | 同页会话内后续 auth 变化（他处登出）不响应 |
| **B-P1-13** | 同步冲突仅比 `updatedAt` 数值；云端 `serverTimestamp` 与本地 `Date.now` 混用 | 本地 ms 与 Firestore Timestamp.toMillis | 时钟偏移/未写 updatedAt 时误判；数组 content 上传时 join，下载变 string → 结构漂移 |
| **B-P1-14** | EasyMDE 与「结构签名自动分析」耦合脆弱 | blur/structure signature 触发 `analyzeText` | 大文档每次失焦全量分析 → UI 卡顿；Markdown 语法噪声进入分词 |

### 2.3 P2 — 质量 / 可维护 / 次要 UX

| ID | 标题 | 说明 |
|---|---|---|
| **B-P2-01** | README 引用缺失的 `MARKDOWN_README.md` | 三语 README 均链接失效 |
| **B-P2-02** | 无根目录 `LICENSE` 文件 | README 写 MIT，GitHub 许可证识别可能失败 |
| **B-P2-03** | `package.json` 声明 vite/kuromoji 等依赖但应用不走 npm 构建 | 依赖与运行时脱节；`npm install` 无意义 |
| **B-P2-04** | i18n 不完整 | 多处硬编码中文/日文（删除确认按钮「取消/删除」、toast、空状态、部分 label）；`applyI18n` 与 data-i18n 覆盖不全 |
| **B-P2-05** | PWA icon `purpose: "any maskable"` 合并且 logo 613×594 非方 | 安装图标裁切差；缺 192/512 规范尺寸分离 |
| **B-P2-06** | 无独立 offline / 404 页 | SW 离线失败仅 `503 Offline` 文本 |
| **B-P2-07** | `console.log` 刷屏（~79 处） | 生产噪声；可能泄漏路径 |
| **B-P2-08** | `tts.js` 与 `main-js` 重复 + `window.LS` / `FudokiGetText` 从未赋值 | tts 模块读 `window.LS.volume` 常失败，靠 fallback |
| **B-P2-09** | `login.html` 1400+ 行内联 CSS/JS | 与主应用双份 clear 脚本；难维护 |
| **B-P2-10** | 示例文档 `content` 为 `string[]`，用户文档多为 string | 全代码多处 `Array.isArray` 分支，易漏 |
| **B-P2-11** | 无障碍：部分按钮缺名；弹层焦点陷阱/Esc 不统一；对比度未系统检查 | — |
| **B-P2-12** | 移动端 `user-scalable=no`（login） | 无障碍与 iOS 指南不友好 |
| **B-P2-13** | Star History / 外链图片依赖第三方 | README 隐私与可用性 |
| **B-P2-14** | CNAME 提交但 Pages 部署流程未文档化 | — |

---

## 3. 架构问题（Architecture Findings）

### 3.1 巨石前端 + 假模块化

- 「模块」`tts.js` / `dictionary.js` / `ui-utils.js` / `i18n.js` 只是 **IIFE 挂 window**，无 ES module、无打包、无依赖图。
- `main-js.js` 仍承载：DOM 查询、文档 CRUD、分析流水线、TTS、PWA、Firebase 同步、主题、搜索、阅读模式、设置弹窗……
- **过早闭合 IIFE** 说明文件是多次粘贴演进，缺少边界审查。

**目标形态（建议）：**

```
src/
  main.js                 # 组装
  app/auth.js
  app/sync/firestore.js
  app/documents/store.js  # 单一真相源 + 适配 localStorage
  app/documents/ui.js
  features/analyze/segmenter.js
  features/analyze/display.js
  features/dict/service.js + index (Map)
  features/tts/engine.js
  features/pwa/register.js
  ui/i18n.js
  ui/theme.js
  ui/toast.js
```

用 Vite 构建；开发 `npm run dev`，产物 `dist/` 部署 Pages。

### 3.2 状态与存储键无单一 schema

- 运行时键、备份键、文档键、clear 保留键三套命名（`texts` vs `fudoki_texts`）。
- 设置键散落：`lang`/`theme`/`rate`/… 无版本号、无迁移函数。
- **建议**：`fudoki:v1` 命名空间 + `migrations[]`；导入导出只认版本化 payload。

### 3.3 同步模型不完整

当前是「穷举 id 双向 upsert」，缺：

- 删除向量 / tombstone / `deletedAt`
- 文件夹双向
- 冲突 UI（现在静默选较新）
- 增量（每次全量 getDocs）
- 同步状态机（idle/syncing/error）与按钮 disable 一致

### 3.4 词典架构不适合浏览器主线程

- 109MB JSON + 线性查找是移动端杀手。
- **建议方向（择一）**：
  1. 预构建 `Map` 索引（kanji/kana → entryId[]）+ 按需 load entry 分片；或
  2. IndexedDB 持久化 + Web Worker 查询；或
  3. 换精简词典（如常用 2–5 万词）+ 在线 API 回退。

### 3.5 TTS 架构

- 应 **唯一** `TtsEngine` 类：状态机 `idle|playing|paused`，单一 `PLAY_STATE`，UI 只订阅。
- 删除 main-js 内重复实现；`tts.js` 用正式模块导出而非 window 灌污染。

### 3.6 安全与信任边界

- XSS：一切用户文档字段进 HTML 必须 escape / `textContent`。
- Firebase：仓库应有 `firestore.rules`（仅 `request.auth.uid == userId`）；启用 App Check。
- 鉴权：支持「本地模式」跳过 Firebase，数据不上传。

### 3.7 PWA / 缓存

- 版本号与 git SHA 或 package version 绑定；activate 时删旧缓存。
- precache 清单由构建生成，勿手写遗漏。
- navigation preload / 跳过 waiting UI（“新版本可用，点击刷新”）。

### 3.8 工程化缺失

- 无测试、无 CI、无格式化、无类型（JSDoc/TS）、无 bundle 分析。
- 第三方库 vendored 进 git，升级困难。

---

## 4. 功能增强建议（P0–P2）

### 4.1 P0 — 修复与稳固（1–2 周可闭环）

| ID | 项 | 说明 | 验收要点 |
|---|---|---|---|
| **F-P0-01** | 删除重复用户菜单 DOM | index.html 只保留一份 user profile | 无重复 id；菜单开关/同步/导入导出/登出均绑定有效 |
| **F-P0-02** | 统一 localStorage schema | 全部键前缀 `fudoki:`；写迁移：旧 `texts`→新键；备份读写同一套 | 导出含真实文档；导入后列表立即可见；主题/语言恢复 |
| **F-P0-03** | 修复 IIFE 边界 | 要么整文件一个 IIFE，要么顶层不用闭包私有函数；`t/setLanguage/...` 显式导出到 `window` 或改 ES module | 登出/安装 PWA/改语言无 `ReferenceError`；控制台零红错 |
| **F-P0-04** | 同步删除语义 | 本地删除写入 `deletedIds` 或云端 `deletedAt`；同步时对端删除 | 设备 A 删除 → 同步 → 设备 B 文档消失且不回魂 |
| **F-P0-05** | TTS 单一实现 | 删除重复；状态机 + 单一 PLAY_STATE | 播放中改语速续播正确；暂停/继续/停止图标一致 |
| **F-P0-06** | HTML escape 工具 | `escapeHtml` 用于一切 innerHTML 插值；标题用 textContent | 标题 `"><img onerror=alert(1)>` 无执行 |
| **F-P0-07** | 去掉未用 zip / 压缩 logo | git 移除 11MB zip；logo 提供 192/512 | 仓库明显瘦身；manifest icons 合规 |
| **F-P0-08** | SW 版本与清单 | CACHE_VERSION 可 bump；pwa-assets 含 js/css/login/manifest/samples/easymde | 发版后强制更新；离线可打开主流程 |

### 4.2 P1 — 体验与架构升级（2–4 周）

| ID | 项 | 说明 | 验收要点 |
|---|---|---|---|
| **F-P1-01** | 访客 / 本地模式 | 未登录可用分析+TTS+本地文档；横幅提示「登录以同步」 | 无 Google 账号可完成「输入→分析→朗读」 |
| **F-P1-02** | 词典索引 + Worker | 启动建索引或预生成；lookup 进 Worker | 词卡点击 p95 < 50ms（桌面）；主线程长任务 < 50ms |
| **F-P1-03** | Vite 工程化 | 拆模块、dev server、build、资源 hash | `npm run build` 产出 dist；Pages 部署文档 |
| **F-P1-04** | 文件夹双向同步 | folders CRUD + 云端合并 | 两设备文件夹名一致 |
| **F-P1-05** | 同步状态 UI | 按钮旋转/上次同步时间/错误可重试；冲突列表 | 用户能感知同步成败 |
| **F-P1-06** | Auth 增强 | Google redirect 回退；可选匿名登录 | Popup 被拦仍可登录 |
| **F-P1-07** | 设置页完整 i18n | 扫硬编码字符串 | ja/en/zh 切换无中文残片（除用户内容） |
| **F-P1-08** | 分析防抖与 Worker | 输入防抖 + 可选 Worker 分词 | 5k 字文档输入不卡死输入 |
| **F-P1-09** | firestore.rules 入库 + 文档 | rules 测试 | 未授权读写拒绝 |
| **F-P1-10** | 新版本提示 | SW `waiting` → toast「刷新更新」 | 用户不用手清缓存 |

### 4.3 P2 — 产品增值（按需）

| ID | 项 | 说明 |
|---|---|---|
| **F-P2-01** | 生词本 / 收藏词 | 点击词卡「加入生词本」；导出 Anki/CSV |
| **F-P2-02** | 语法高亮增强 | 助词/活用更细；可选依赖信息 |
| **F-P2-03** | 朗读跟读模式 | 逐句高亮 + 间隔 + 录音对比（若 WebAudio 允许） |
| **F-P2-04** | 日中/日英 gloss 切换 | JMdict 多语资源或外部 API |
| **F-P2-05** | OPFS/IndexedDB 大文档 | 避免 localStorage 5MB 上限 |
| **F-P2-06** | 多端实时同步 | Firestore onSnapshot（注意流量） |
| **F-P2-07** | 插件化 App Drawer | 修复入口；深链 Terebi/Kotoba SSO |
| **F-P2-08** | 无障碍 AA | 焦点、对比度、读屏词性 |
| **F-P2-09** | 电子书/字幕导入 | srt/txt/epub 切片成文档 |
| **F-P2-10** | 单元测试 + Playwright | segmenter、sync 合并、escape、关键 UX 路径 |
| **F-P2-11** | 国际化学习向导 | 首跑 onboarding |
| **F-P2-12** | 性能预算 | 主包 < 200KB gzip（不含词典）；LCP < 2.5s（不含词典懒加载） |

---

## 5. 验收标准（Definition of Done）

### 5.1 P0 修复验收（发布门禁）

必须 **全部** 满足：

1. **DOM 唯一性**：`document.querySelectorAll('[id]')` 无重复 id（至少 user* / logout / sync / import 相关）。
2. **备份往返**：
   - 创建 2 篇文档 → 导出 JSON → clear 站点数据 → 导入 → 两篇标题与正文一致，active 文档正确，主题/语言恢复。
3. **删除同步**：
   - A 设备删文档并同步 → B 设备同步后该 id 不存在；再同步 A 也不会复活。
4. **控制台**：主路径（登录→打开文档→分析→播放→暂停→改语速→导出→登出）无未捕获异常。
5. **XSS**：文档标题与正文含 `<>"'&` 与简单 payload，列表与词卡无脚本执行。
6. **TTS**：全文播放 → 暂停 → 继续 → 停止；播放中拖动语速，从当前段附近续播；按钮图标与 `speechSynthesis.speaking` 一致。
7. **PWA**：`CACHE_VERSION` 变更后旧缓存被 activate 清理；离线（DevTools Offline）可打开已预缓存的 index 与核心静态资源。
8. **仓库**：不再跟踪无用 jmdict zip；README 不链死链（或补上 MARKDOWN 文档）。

### 5.2 P1 验收（阶段目标）

1. 访客模式：无登录完成分析+朗读+本地保存；登录后可选择合并本地→云端。
2. 词典：桌面 Chrome 词卡查询 p95 < 50ms；iPhone Safari 不因词典 OOM 崩页（可懒加载/降级提示）。
3. `npm run dev` / `npm run build` 可用；构建产物部署说明写入 README。
4. ja/en/zh 切换后，设置/toast/对话框/侧栏无「语言碎片」。
5. `firestore.rules` 存在且文档化；未登录读 users/* 失败。

### 5.3 回归测试清单（手工 / E2E）

| # | 场景 | 期望 |
|---|---|---|
| R1 | 空库首次登录 | 默认文档或示例可见；自动同步不报错 |
| R2 | 输入「今日は良い天気ですね。」失焦 | 词卡分词、助词「は」读音可配置、品词色 |
| R3 | 点击「天気」 | 释义弹出；无卡死 |
| R4 | 播放全文 / 行 / 词 | 有声；进度条单调递增；停止即停 |
| R5 | 切换主题 Dark/Sakura | 立即生效并持久化 |
| R6 | 切换语言 en | UI 英文化；再切回 ja |
| R7 | 新建/星标/删除/搜索文档 | 列表与内容一致 |
| R8 | 导出→导入 | 见 5.1.2 |
| R9 | 两浏览器账号同步 | 新增/编辑/删除收敛 |
| R10 | `?clear=1` | 缓存清、需重登、文档策略符合文档说明 |
| R11 | 安装 PWA（Desktop Chrome） | 独立窗口；重启后仍登录态（Firebase） |
| R12 | 移动宽度 ≤480 | 侧栏抽屉、播放条可用，无水平死滚 |
| R13 | 无日语 voice 环境 | 友好提示，不白屏 |
| R14 | 离线 | 已缓存资源可用；同步失败有 toast |

### 5.4 非功能指标（建议基线）

| 指标 | 目标 |
|---|---|
| 主路径 JS（不含词典） | 打包后 gzip < 200KB |
| 首屏可交互（已登录，不含词典） | < 3s（宽带桌面） |
| 词典就绪 | 显式进度；失败可重试；不阻塞分词 |
| localStorage 文档上限 | 接近配额时警告并建议导出 |
| Lighthouse PWA | installable + 离线基础通过 |
| 无障碍 | 关键按钮有 accessible name；弹层 Esc 关闭 |

---

## 6. 建议实施顺序（给执行 Agent）

```
Phase 0  止血（0.5–1d）
  ├─ F-P0-01 去重 DOM
  ├─ F-P0-02 统一存储键 + 修备份
  ├─ F-P0-03 修 IIFE / 导出全局
  ├─ F-P0-06 escapeHtml
  └─ F-P0-07 删 zip、修 README 死链

Phase 1  同步与 TTS（1–2d）
  ├─ F-P0-04 删除语义
  ├─ F-P0-05 TTS 合并
  └─ F-P0-08 SW 版本与清单

Phase 2  结构（3–5d）
  ├─ F-P1-03 Vite 拆模块
  ├─ F-P1-01 访客模式
  ├─ F-P1-02 词典索引/Worker
  └─ F-P1-09 rules

Phase 3  产品（按需）
  └─ P2 生词本 / 跟读 / E2E ...
```

每完成一个 Phase：跑 §5.3 回归表，更新本文件「修复状态」列（可在 PR 描述勾选）。

---

## 7. 风险与约束

| 风险 | 缓解 |
|---|---|
| 改存储键导致老用户「文档消失」 | 启动时迁移 + 保留一版本双读 |
| 词典改造影响查词 UX | 特性开关；失败回退旧线性（仅桌面） |
| Firebase 规则收紧误伤 | 先 staging 项目验证 |
| SW 强更新导致半更新状态 | activate skipWaiting + 客户端 reload 提示 |
| 大 PR 难审 | 严格按 Phase 拆 PR |

---

## 8. 参考命令（本地）

```bash
cd ~/development/fudoki
python3 -m http.server 8000
# http://localhost:8000/login.html
# http://localhost:8000/?clear=1
```

线上：https://fudoki.iamcheyan.com  
Issues：https://github.com/iamcheyan/fudoki/issues

---

## 9. Review 元数据

| 项 | 值 |
|---|---|
| 仓库路径 | `/home/tetsuya/development/fudoki` |
| 默认分支 | `master` @ `1fe7e7f`（Merge PR #2） |
| 主要语言 | JavaScript（浏览器）、HTML、CSS |
| 后端 | Firebase Auth + Firestore（无自有服务器） |
| 部署 | GitHub Pages（CNAME） |
| Reviewer | Hermes Agent 深度静态审查（未做真机 Firebase 联调） |
| 局限 | 未跑浏览器 E2E；Firestore 规则与配额以控制台实况为准；TTS 依赖 OS 语音包 |

---

**下一步**：按 §6 Phase 0 开修；每项对应 §2 Bug ID 与 §5 验收勾选。完成后在本目录可追加 `FUDOKI_REVIEW_PROGRESS.md` 跟踪。
