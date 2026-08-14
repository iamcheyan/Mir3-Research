# Miyako 深度 Review / 修复型 Goal

> 仓库：`~/development/miyako`  
> 审查日期：2026-08-14  
> 审查方式：静态代码走读、git 分支/构建产物核对、已有 APK 解包、PNG 资源分析。未修改 miyako 源码。  
> 目标：解释“偶发无图标”和“偶发卡顿”，并给出可直接派工的修复顺序与验收标准。

---

## 0. 一句话结论

Miyako 当前不是单一 bug，而是“两个 Android 壳/两条发布线 + 一个落后工作树 + 一条未经端到端验证的 Tauri Android 链路”。

- **图标**：仓库内 `src-tauri/icons/android`、当前 `src-tauri/gen/android` 和 `AndroidManifest.xml` 的静态资源是完整的；但是 `generate-icons.sh` 只调用 Tauri CLI，不保证生成物同步、没有 CI 校验，`tauri android init --ci` 又可能重新生成 `gen/android`。更严重的是当前工作树记录的 `android-test-app/app/build/outputs/apk/debug/app-debug.apk` 是陈旧 APK：解包后包名为 `com.nasmusic.test`、label 为 `NasMusicSync`，而当前源码是 `com.miyako.test`、产品名 `miyako`。因此“有时没图标”首先应按**构建了错误/旧壳或旧 APK**处理，而不是先判定 PNG 丢失。
- **卡顿**：最重的确定性根因是音频播放链路：Rust `read_audio_file` 把整首歌读入内存并 base64 返回，前端再复制成 binary string、`Uint8Array`、Blob；单首 FLAC/WAV 可造成多倍内存峰值和 WebView GC 卡顿，Blob URL 也没有 `URL.revokeObjectURL`。同步链路则是整文件 `Vec<u8>` 缓存、串行下载、每文件 `get_file_info + save_sync_state`、生产代码同步 TCP 调试上报；UI 还把每次进度都追加日志，并在音频 `timeupdate` 时重渲染整份 PlayerUI/播放列表。

---

## 1. 现状地图

### 1.1 仓库/壳/发布线

| 层 | 现状 | 风险 |
|---|---|---|
| Tauri 主工程 | `src/` React 18 + TS；`src-tauri/` Rust + Tauri 2 | 当前 HEAD 仅到 `0074521`（2026-05-31） |
| Tauri Android 壳 | `src-tauri/gen/android`，包名 `com.miyako.app`，`MainActivity.kt` 只 `enableEdgeToEdge()` | 是实际 Tauri 壳；前台播放/前台服务/原生音频桥均不存在 |
| 独立测试壳 | `android-test-app/`，传统 Android WebView，包名 `com.miyako.test` | 与 Tauri 壳并存，资源、Manifest、Web bundle、包名各自独立，极易把测试 APK 当正式 APK |
| 旧壳归档 | `src-tauri/gen/android.backup.20260531120122`，旧包名 `com.nasmusic.sync` | 不是可直接发布的备份；但仍被 git 跟踪，增加误选风险 |
| archive | `archive/history.json` + `archive/20260530-234413-nas-music-sync/{prd.json,progress.txt}` | Ralph 已完成 15 个 story 的历史快照，不是运行时资源；不应参与构建 |
| 领先工作分支 | `origin/ralph/github-actions-android-apk` 比当前 HEAD 多 73 个提交，含新的后台同步、file index、状态栏和播放器重构 | 用户若从该分支构建，行为和当前工作树并不相同；必须先锁定发布分支/commit |
| CI | 领先分支有 `.github/workflows/build-android.yml`，执行 `tauri android init --ci` 后 build 两个 ABI | 没有显式“图标资源校验/Manifest 解析/APK 解包验收”；找 APK 的 shell 表达式也有缺括号风险 |

### 1.2 数据流

```text
设置页 localStorage(smb-config)
        │
        ▼
SMB connect: server/share/user/password
        │  全局 Rust ConnectionManager(HashMap + Mutex)
        ▼
递归 smb_list_dir → RemoteFile[] → sync_compare
        │
        ▼
SyncAction[] → 串行 sync_download
  ├─ smb open/read 64 KiB chunks → Vec<u8> 整文件内存 → std::fs::write
  ├─ get_file_info（每个文件再一次 SMB 请求）
  ├─ save_sync_state（每个文件 JSON 重写）
  └─ WebView emit("sync-progress") → React append logs
        │
        ▼
sync_state.json → MusicLibrary 分组
        │
        ▼
PlayerUI → HTMLAudioElement
  └─ 当前 HEAD：read_audio_file → base64 → Blob URL → Audio
```

协议实际为 **SMB**；没有 WebDAV/HTTP 音乐源。远程浏览和同步都依赖同一个 Rust 全局连接管理器；播放只使用已下载的本地文件。

### 1.3 当前代码质量概览

- 组件按页面拆分，React Hooks 清理总体存在；但没有统一数据层、没有 query/cache 层、错误多数只 `console.error` 或 `alert`。
- `SyncPage`、`MusicLibrary`、`RemoteBrowser` 各自连接/读取，连接状态通过 `smbSession.ts` 共享，但 Rust 没有连接生命周期/超时/重连策略。
- `SyncState` 是完整 JSON 数组，扫描/比较/保存均随文件数线性增长；没有索引数据库、原子写、校验、迁移版本。
- `StorageManager` 与 `playbackStorage` 是两套持久化体系；播放历史代码存在但播放时没有接线。
- 列表全部 `.map()`，没有虚拟化；播放列表/歌曲列表/同步日志达到数百或数千项时会直接放大 WebView 渲染成本。

---

## 2. 图标问题：根因链与修复 Goal

### 2.1 已确认链路

```text
generate-icons.sh:19-57
  src-tauri/icons/icon.png（当前 512x512 RGBA）
  └─ npx @tauri-apps/cli icon "$SOURCE_ICON"
       ├─ src-tauri/icons/android/mipmap-*/ic_launcher*.png/xml
       └─ 其他桌面/iOS 图标

正式 Tauri Android 资源：
src-tauri/gen/android/app/src/main/AndroidManifest.xml:8
  android:icon="@mipmap/ic_launcher"
  └─ mipmap-anydpi-v26/ic_launcher.xml
       ├─ foreground @mipmap/ic_launcher_foreground
       └─ background @color/ic_launcher_background
  └─ 各密度 ic_launcher.png / ic_launcher_round.png / foreground.png

部署脚本：
deploy-android-test.sh:110-121
  src-tauri/icons/android/* → src-tauri/gen/android/app/src/main/res/*

deploy-android-test.sh:228-240
  sync icons → npx tauri android build → 找 APK
```

`tauri.conf.json:28-38` 的 bundle.icon 只列 32/128/桌面 icns/ico，**没有 Android 目录**；Android 是否生成/复制图标依赖 CLI init 生成物和部署脚本，不是配置文件单一真相。

独立 `android-test-app` 还有自己的：

- `android-test-app/app/src/main/AndroidManifest.xml:8-9`：`android:icon=@mipmap/ic_launcher`、`android:roundIcon=@mipmap/ic_launcher_round`；
- `android-test-app/app/src/main/res/mipmap-*`：只有 legacy PNG，没有 adaptive icon XML/foreground/background；
- `android-test-app/app/src/main/assets/www/`：手工/旧 Vite bundle。

这两套壳不能混用。正式发布只能从一个壳产出，APK applicationId 必须在发布脚本中强校验。

### 2.2 证据与结论

1. 当前 `src-tauri/gen/android` 的各密度 PNG 和 adaptive XML 都存在；`src-tauri/icons/android` 与 `gen/android/res` 的 PNG md5 相同。
2. 当前 Manifest 注册 `@mipmap/ic_launcher`，但没有显式 `android:roundIcon`；部分 Launcher 会回退，部分厂商会对 legacy/adaptive 处理不同。应同时声明 `roundIcon`，并保留兼容 legacy PNG。
3. adaptive background 为 `#fff`：`src-tauri/gen/android/app/src/main/res/values/ic_launcher_background.xml:3`。这不会导致“资源不存在”，但会造成在浅色/白色 launcher 上看起来像白板；必须用产品指定不变背景色并在深/浅/圆形 mask 下人工验收。
4. foreground 实际非透明 bbox 约为 `79,78–353,354`（432×432），安全区内仍有约 63% 可见图形；不是“全白/全透明”。PNG 视觉分析显示是黑底上的浅粉圆盘+深灰音符，应该可见，但 Android adaptive mask 可能裁掉边缘，需用真实 launcher screenshot 验证。
5. `generate-icons.sh:31-32` 使用 macOS `sips`，在 Debian/Ubuntu CI 上不可用；脚本 `set -e` 会在尺寸读取处直接退出，导致图标生成被条件跳过。CI 当前没有调用该脚本，但开发者按文档运行会出现平台差异。
6. `generate-icons.sh:55-57` 只生成 Tauri icons，不做 Android 资源复制；复制实际在 `deploy-android-test.sh:110-121`，且该脚本要求物理设备、硬编码 macOS `JAVA_HOME`/SDK fallback。CI 直接 `tauri android init --ci`，没有执行 `sync_android_icons`。
7. 领先分支 CI 的 `tauri android init --ci` 会生成/重置 `src-tauri/gen/android`，但工作流没有在 init 后把 `src-tauri/icons/android` 同步回 `gen/android/res` 的显式步骤，也没有检查最终 APK。这是最重要的竞态/条件跳过风险。
8. 本地已存在的 `android-test-app/app/build/outputs/apk/debug/app-debug.apk` 解包后包含五种密度的 `ic_launcher.png`/`ic_launcher_round.png`，说明“图标资源确实能进入 APK”；但二进制 Manifest 的包名是 `com.nasmusic.test`、label 是 `NasMusicSync`，与当前源码 `com.miyako.test`/`miyako` 不一致。该 APK 是陈旧构建产物，并且构建/中间产物被 git 跟踪（`android-test-app` 下约 454 个 build 文件），发布时很容易误装旧 APK。

### 2.3 图标修复 Goal（P0）

- 选定正式壳：推荐 `src-tauri/gen/android`；将 `android-test-app` 改名为明确的 `android-test-fixture` 或从发布文档/CI 中彻底排除。
- 让一个可重复脚本成为唯一入口：`generate-icons` 使用跨平台工具（ImageMagick/Python Pillow/Node），生成后立即同步 `src-tauri/icons/android → src-tauri/gen/android/app/src/main/res`；CI 先 init，再 sync，再 build。
- Manifest 同时声明 `android:icon="@mipmap/ic_launcher"` 和 `android:roundIcon="@mipmap/ic_launcher_round"`；确认 adaptive XML 的 foreground/background 在 `mipmap-anydpi-v26`、values 资源和全部 density 中一致。
- CI 必须对 APK 做机器验收：解析 applicationId/label/icon resource，列出 `mipmap-*/*ic_launcher*`，禁止包名 `com.nasmusic.test`、`com.nasmusic.sync`、label `NasMusicSync` 进入发布目录。
- 为 debug/release/arm64/armv7/universal 使用同一源图标；构建前清空旧 `outputs/apk`，不允许 `find | head` 从旧产物中选 APK。
- 将签名配置与版本配置集中化。当前 Tauri generated `build.gradle.kts` 的 release 使用 debug signing config，不能发布。
- 真机验收：Pixel/原生 Launcher、FiiO Launcher、深色/浅色壁纸、圆形/squircle mask、卸载重装/升级覆盖安装；若只在部分 launcher 复现，清 launcher cache 并记录是资源问题还是缓存问题。

---

## 3. 卡顿问题：根因按权重排序

### P0（确定性高，优先修）

#### A. 音频整文件复制链路（权重 30%）

- `src-tauri/src/lib.rs:20-25`：`fs::read` 整首文件后 base64；
- `src/lib/audioPlayer.ts:148-174`：invoke base64、`atob`、逐字节复制到 `Uint8Array`、Blob；
- `src/lib/audioPlayer.ts:191-203,231-247`：每次切歌/恢复都会重复执行；
- `URL.createObjectURL` 结果没有任何 `URL.revokeObjectURL`（全仓库搜索为 0）。

后果：大 FLAC/WAV 会同时存在 Rust buffer、base64 字符串、binary string、Uint8Array、Blob，造成内存峰值和 GC stop-the-world；连续切歌会泄漏旧 Blob URL。修复为 Tauri asset protocol/`convertFileSrc` 或原生 Android Media3 文件流；必要时增加受控资源 URL 生命周期。

#### B. SMB 下载整文件缓冲（权重 20%）

- `src-tauri/src/smb_client.rs:382-398`：`Vec::with_capacity(file_size)` + 全部 chunks push；
- `src-tauri/src/smb_client.rs:412-414`：全部读完才 `std::fs::write`。

网络慢或大文件时同时占用下载缓冲和 WebView/音频内存；异常中断还没有 `.part` 临时文件与断点续传。应远端 chunk → 本地异步文件流式写，进度按 bytes 节流。

#### C. 同步 UI 进度/日志风暴（权重 15%）

- `src-tauri/src/sync_engine.rs:342-359,435-438` 每 action emit 一次；
- `src-tauri/src/lib.rs:112-129` 每次回调同步 `window.emit`；
- `src/components/SyncPage.tsx:61-70` 每事件 `setProgress` + `setLogs(prev => [...prev, ...])`；
- `src/components/SyncPage.tsx:302-307` 全部 logs `.map()`；
- `src-tauri/src/sync_engine.rs:62-115` 和 `smb_client.rs:92-147` 在生产下载路径里同步 TCP connect/write 调试事件。

15 个文件尚可，但数百/数千文件会形成 IPC + React render + DOM append 风暴。应将进度按 100–250ms 或 bytes 阈值合并，日志只保留最近 N 条/环形 buffer，完整日志写文件；删除/feature-gate debug reporter，并设置 TCP timeout。

#### D. 并发同步/重入（权重 10%）

当前 HEAD 的 `SyncPage` 会阻止本页重复点击，但没有全局同步锁；领先分支后来增加了 `src/lib/syncCoordinator.ts`，说明后台同步与手动同步已成为实际风险。修复必须使用 Rust 侧 per-connection/per-library mutex + 前端 coordinator，禁止两个 `sync_download` 同时写同一目录/state。

### P1（高概率，需 profiling 验证）

#### E. PlayerUI 在 timeupdate 上重渲染整个播放列表（权重 8%）

- `src/components/PlayerUI.tsx:52-71` 订阅 `timeupdate`；
- `src/components/PlayerUI.tsx:219-234` 每次渲染全部 playlist rows；
- `src/lib/audioPlayer.ts:94-99` 原生 `timeupdate` 直接 emit。

进度更新通常每秒 4–10 次；如果 playlist 很大，全列表 reconciliation 成本高。拆成 ProgressBar 外部订阅、PlayerControls、虚拟化 Playlist；只在 track/index/play state 变化时更新列表。

#### F. 无虚拟化列表（权重 7%）

- `MusicLibrary.tsx:252-265,310-325`；
- `PlayerUI.tsx:219-234`；
- `RemoteBrowser.tsx:165-220`。

全量 `.map()`，没有分页/窗口化/搜索 debounce。验证 1k/10k 文件时的 FPS、JS heap、长任务；引入 `react-window` 或固定高度窗口列表。

#### G. SMB manager 长时间持有全局 Mutex（权重 5%）

- `src-tauri/src/smb_client.rs:224-250`、`323-360`、`462-486`：先拿 `manager.connections.lock().await`，再持锁做 SMB 网络 IO。

列表/下载/文件信息会串行阻塞其它命令；连接断开无法及时拿锁。改为存 `Arc<SmbConnection>`，锁内只 clone handle，网络 IO 在锁外执行；为每操作设置 timeout/cancel。

#### H. 同步状态重复 JSON 全量重写（权重 3%）

- `src-tauri/src/sync_engine.rs:401-420` 每个文件更新内存数组并 `save_sync_state`；
- `save_sync_state:299-315` pretty JSON 全量写。

文件数大时 I/O 和序列化为 O(n²) 体感。使用 SQLite/索引文件或批量 checkpoint，每 N 文件/每 1–5 秒原子写一次。

#### I. 网络字体阻塞/离线不稳定（权重 2%）

- `index.html:11-13` preconnect + Google Fonts。

应用定位是 NAS 离线音乐；WebView 无网时字体请求会延迟/失败，Material Symbols 也会产生布局变化。将字体打包到应用或使用本地 SVG/icon fallback。

### P2（中低概率/体验性）

- `src/components/SyncPage.tsx:38-40` 日志数组无限增长直到页面卸载；长时间同步会越积越多。
- `src/lib/mediaSession.ts:62-64,107-115` 每个 `timeupdate` 调 `setPositionState`，应节流到约 250–1000ms并检查 position 合法性。
- `src/components/MusicLibrary.tsx:155-157` 搜索每次按键立即全数组 filter，应 debounce/index。
- `src-tauri/src/sync_engine.rs:181-205` 递归扫描无深度/数量/取消保护，异常 NAS 大目录会长时间占用任务。
- `src-tauri/src/smb_client.rs:382-399` 没有读超时、取消 token、重试策略；“卡死”时用户只能等命令返回。
- 当前 HEAD 的 `src-tauri/src/sync_engine.rs:61-115` 读取 `.dbg/sync-download-stall.env` 并向 localhost 发调试 HTTP；生产包不应携带此路径/网络副作用。

### 3.1 已有下载卡死调查的延伸结论

`debug-sync-download-stall.md` 已确认两个旧根因：

1. 前端原先没有把 callback 回传成逐文件事件；
2. `~/Music/NasSync` 曾被当成字面路径，写入 `src-tauri/~/Music/NasSync`。

当前修复已在 `sync_engine.rs:125-141` 处理 `~/` 展开、`lib.rs:112-129` emit 进度，但留下更深层问题：

- 没有单文件/总任务 deadline；
- SMB read/close/get-info 失败不区分可重试与不可重试；
- 没有指数退避、重试上限、失败队列；
- 下载前不写 `.part`，中断后可能留下看似完整但大小错误的文件；
- `sync_download` 每个 action 后还会额外 `get_file_info`，增加 NAS RTT；
- callback 只发送 action index，不发送 bytes read/throughput/ETA；
- 状态写入不是原子 rename，崩溃可能损坏 `sync_state.json`。

---

## 4. 全量 Bug 清单（P0/P1/P2，带定位与复现）

### P0

| ID | 问题 | 位置 | 复现路径 | 修复目标 |
|---|---|---|---|---|
| P0-01 | 发布壳/包名不唯一，旧 APK 可被误装 | `android-test-app/app/build.gradle:7-14`；`src-tauri/gen/android/app/build.gradle.kts:13-20`；陈旧 APK | 同时执行独立壳和 Tauri build；从 `android-test-app/app/build/outputs/apk/debug/app-debug.apk` 安装；观察 label/package 与当前源码不符 | 单一发布壳；脚本验证 applicationId、version、commit；清理旧 outputs |
| P0-02 | Android CI init 后没有保证图标同步 | `.github/workflows/build-android.yml`（领先分支）；`deploy-android-test.sh:110-121` | CI `tauri android init --ci` 后直接 build；或只运行 `generate-icons.sh`；解包 APK 看 mipmap | init → sync → build → APK icon test，失败即 CI fail |
| P0-03 | 音频整文件 base64 导致 OOM/卡顿 | `src-tauri/src/lib.rs:20-25`；`src/lib/audioPlayer.ts:148-174` | 同步一首 100–500MB FLAC/WAV，连续切换 10 首，观察 WebView heap/GC/ANR | asset protocol/原生流式播放，零 base64 全文件复制 |
| P0-04 | 下载整文件入内存，失败无断点/临时文件 | `src-tauri/src/smb_client.rs:382-414` | NAS 上放 1GB 音频，弱 Wi‑Fi 下载或中途杀进程，观察内存和残留文件 | streaming `.part` + fsync/rename + resume |
| P0-05 | release 使用 debug signing | `src-tauri/gen/android/app/build.gradle.kts:43-64` | 执行 release build，检查 signing certificate；与正式 keystore/升级安装比较 | secrets/signing config 分离，release 禁止 debug key |

### P1

| ID | 问题 | 位置 | 复现路径 | 修复目标 |
|---|---|---|---|---|
| P1-01 | sync progress IPC/React 日志风暴 | `lib.rs:112-129`；`sync_engine.rs:342-359`；`SyncPage.tsx:61-70,302-307` | 1000 个文件同步；Chrome/WebView Performance 看长任务和 FPS | 100–250ms 节流、bytes 进度、日志环形 buffer |
| P1-02 | PlayerUI 每次 timeupdate 重渲染全 playlist | `PlayerUI.tsx:52-71,219-234` | 导入 1000 首，展开播放器播放 10 分钟 | Progress 与 playlist 拆分/虚拟化 |
| P1-03 | 列表无虚拟化、搜索无 debounce | `MusicLibrary.tsx:155-157,252-265,310-325`；`RemoteBrowser.tsx` 列表 | 10k 音乐文件，输入搜索/打开全部歌曲 | 窗口化列表、索引搜索 |
| P1-04 | 全局连接锁持有网络 IO | `smb_client.rs:224-294,323-431,462-520` | 同步进行时另开远程浏览/测试连接/断开 | Arc handle + 锁外 IO + timeout |
| P1-05 | 每个文件 get-info + 全量 JSON 保存 | `sync_engine.rs:381-420,451-462` | 1000 个小文件同步，测总时长和磁盘写放大 | 使用扫描元数据；批量 checkpoint/SQLite |
| P1-06 | Tauri asset protocol 配置与 `convertFileSrc` 未形成可验证闭环（领先分支） | 领先分支 `src/lib/audioPlayer.ts:377-390`；`src-tauri/tauri.conf.json` 无显式 assetProtocol | 构建领先分支，播放已同步本地文件 | CI 播放 smoke test；明确 protocol scope/permission |
| P1-07 | 领先分支后台同步与手动同步曾需额外全局锁 | 领先分支 `src/lib/backgroundSync.ts`、`src/lib/syncCoordinator.ts` | 5 分钟后台周期恰好撞上手动同步 | Rust/前端双层锁、取消/状态合并 |
| P1-08 | MediaSession 每次 timeupdate 更新 position | `mediaSession.ts:62-64,107-115` | 锁屏播放并观察 CPU/JS long task | 节流 + track change 即时更新 |

### P2

| ID | 问题 | 位置 | 复现路径 | 修复目标 |
|---|---|---|---|---|
| P2-01 | 没有前台服务/Media3，后台播放依赖 WebView | `src-tauri/gen/android/app/src/main/AndroidManifest.xml`；`MainActivity.kt` | 播放后锁屏、切后台、系统回收进程 | Media3 foreground service + notification/media controls |
| P2-02 | 没有 Android 音频焦点处理/duck/pause | `src/lib/mediaSession.ts:67-83` | 来电/导航/其它播放器抢焦点 | AudioFocus listener + resume policy |
| P2-03 | 权限/网络能力不完整，cleartext 配置仅 debug | `AndroidManifest.xml:4, usesCleartextTraffic=${usesCleartextTraffic}`；release 默认 false | NAS 使用 IP/SMB 环境，release 连接失败而 debug 正常 | 明确 TLS/cleartext 风险，按用户配置与 target SDK 测试 |
| P2-04 | `android-test-app` WebView 开启 UniversalAccessFromFileURLs | `android-test-app/.../MainActivity.java:30-31` | 独立壳加载异常页面/外部内容 | 删除不必要 file URL 跨域权限，禁止作为正式壳 |
| P2-05 | 文件协议/路径注入风险 | `sync_engine.rs:161-168`、storage commands `lib.rs:141-162` | 设置 localDir 或 filename 为 `../`，访问 app data 外 | canonicalize/拒绝 traversal/限制根目录 |
| P2-06 | 配置明文存储密码 | `src/lib/smbConfig.ts:15-44` localStorage | 检查 WebView storage/备份 | Android Keystore/安全存储；至少不把密码放普通 localStorage |
| P2-07 | 清理数据不删除实际 Music 目录 | `Settings.tsx:85-105` 只清 JSON/storage | 清理后检查 `~/Music/NasSync` 或 Android files | 明确“清状态”与“删媒体”两个动作并显示大小/确认 |
| P2-08 | 播放历史体系未接线 | `src/lib/storage.ts:63-94` 有 API，但 `MusicLibrary.tsx:128-140` 播放时未调用 | 播放歌曲后重启查看最近/历史 | 统一 playback/recent/history schema 并接线 |
| P2-09 | 网络字体使离线首屏不稳定 | `index.html:11-13` | 断网冷启动，观察字体请求/布局跳变 | 打包字体或本地 icon |
| P2-10 | `generate-icons.sh` macOS-only | `generate-icons.sh:31-49` | Debian/CI 运行脚本 | 跨平台图像尺寸检测和 CI test |
| P2-11 | release/CI 版本固定 0.1.0/1 | `package.json:4-5`；`tauri.conf.json:4-5`；Gradle 默认 versionCode | 覆盖安装两个 release，观察升级/缓存行为 | 单一版本源、递增 versionCode、产物 metadata |
| P2-12 | 前端大量错误只进 console/alert，无离线态模型 | `MusicLibrary.tsx:80-83`；`Settings.tsx:72-81`；`SyncPage.tsx:181-187` | 断 NAS、断网、权限失败后操作 | Offline/connecting/error/retry 状态统一呈现 |

---

## 5. 架构问题

1. **两个壳的边界没有文档化**：`android-test-app` 是独立 Java WebView，不能调用 Tauri commands；Tauri 壳由 generated Kotlin `TauriActivity` 管理 WebView/Rust IPC。两者都叫 miyako/NasMusicSync 的不同历史版本，发布入口必须只有一个。
2. **Rust 与前端协议缺乏版本契约**：命令名和 snake_case 字段手写在 `types/tauri-commands.ts`，没有生成 schema/contract test；领先分支已经增加 file-index 命令但仍靠手写接口。
3. **连接管理器不是并发安全的业务模型**：HashMap Mutex 既管理生命周期又包住 IO；没有 owner/page reference、idle timeout、reconnect、cancel。
4. **同步不是可恢复事务**：没有 manifest/index 作为 source of truth（领先分支才引入 file index），没有原子状态、部分文件校验、删除策略、冲突策略可视化。
5. **播放器依赖 WebView**：当前正式壳没有 Android foreground service/Media3；锁屏媒体会受 WebView/系统进程生命周期影响。
6. **安全边界过宽**：capability 含 `fs:read-all` + `fs:scope`，同时 Rust 自定义命令可读取任意传入路径；storage filename/dir 没有 traversal 校验；SMB 密码明文 localStorage。
7. **可观测性混入生产代码**：debug TCP reporter 是同步路径的一部分，且默认读取工作目录 `.dbg`；应替换为结构化日志/事件并在 release 构建剔除。
8. **构建产物污染仓库**：当前跟踪了 `android-test-app/.gradle`、`android-test-app/app/build` 大量中间物；这直接制造陈旧 APK 误装和“源码/包不一致”。

---

## 6. 功能增强建议

### P0（先让核心可靠）

- **断点续传/后台下载管理**：队列、暂停/继续、失败重试、单文件进度/速度/ETA、网络断开自动恢复；`.part` + checksum + atomic rename。
- **可靠播放**：asset protocol/Media3 流式播放；避免 base64；播放错误可重试，文件不存在能从 library 标记出来。
- **播放队列**：当前只有当前文件夹 playlist；需要跨文件夹队列、插队/移除/持久化。
- **清晰的 offline 状态**：离线仍可浏览已同步库和播放；NAS 只在需要同步/远程浏览时连接。
- **发布验收门禁**：icon、package、签名、versionCode、APK ABI、启动/播放 smoke test。

### P1

- **封面缓存策略**：从音频 metadata 提取封面到缩略图缓存，限制尺寸/磁盘配额，列表使用缩略图而非原图；当前代码尚未实现封面。
- **歌词**：本地 LRC/嵌入歌词，按播放时间节流更新；离线可用。
- **后台播放通知栏**：Media3 `MediaSessionService`、通知栏上一曲/播放/下一曲、耳机按键、音频焦点/duck。
- **大库索引**：SQLite/file index，增量扫描，按 artist/album/genre/tag 搜索；列表虚拟化。
- **同步冲突与删除策略**：NAS 删除是否同步删除本地、移动识别、文件更新校验、手动清理。

### P2

- **均衡器/DSP**：优先调用 Android AudioEffect，WebView fallback；预设、每设备保存。
- **播放统计/最近播放/收藏**：合并两套 storage schema，提供导出/迁移。
- **多 NAS profile**：多个服务器、凭据进入 Keystore、连接健康检查。
- **主题/本地化/字体包**：中英日、离线字体、无障碍字号与对比度。
- **测试工具**：fake SMB server、故障注入（超时/断线/损坏文件）、APK icon extractor、WebView perf harness。

---

## 7. 验收标准

### 7.1 图标

- [ ] CI 从干净 checkout 构建；不依赖历史 `gen/android`、旧 outputs 或本机缓存。
- [ ] 生成并同步后，所有 `mipmap-mdpi/hdpi/xhdpi/xxhdpi/xxxhdpi` 有 legacy `ic_launcher` 与 `ic_launcher_round`；API 26+ 有 adaptive XML + foreground + background。
- [ ] APK Manifest applicationId 必须为 `com.miyako.app`（正式 Tauri）或明确的测试 ID，绝不能出现 `com.miyako.test`/`com.nasmusic.sync`；label/version 与发布 metadata 一致。
- [ ] APK 解包自动断言 `ic_launcher` 资源存在；截图验证浅色/深色壁纸、圆形/squircle mask、FiiO/Pixel launcher。
- [ ] debug/release/arm64/armv7 图标像素 hash 与源资源一致；升级覆盖安装与卸载重装均可见。
- [ ] release 使用正式签名，versionCode 单调递增。

### 7.2 卡顿/同步

- [ ] 500MB FLAC 播放时不出现 base64 全文件 IPC；JS heap 峰值相对基线不超过 2×，连续切歌 20 次无 Blob URL 增长。
- [ ] 1GB 文件下载不把全文件载入内存；内存峰值不随文件大小线性增加；中断后可 resume，完成后 `.part` 消失。
- [ ] 1000 文件同步：progress IPC ≤ 4 次/秒，日志 DOM ≤ 200 行，UI 主线程长任务 < 50ms（目标），进度可见且不会停在“开始下载”。
- [ ] NAS RTT 100–300ms/弱 Wi‑Fi/断线重连：每文件有 timeout、重试上限、失败原因、继续/取消；不会无限卡死。
- [ ] 同步期间打开远程浏览/播放本地歌曲不阻塞；手动与后台同步不会并发写同一 state/目录。
- [ ] 10k 曲库列表滚动 FPS ≥ 50（中端 Android 设备目标），搜索输入不卡顿；列表采用虚拟化/分页。
- [ ] 锁屏播放 30 分钟、来电/其它播放器抢焦点、后台切换、系统回收后行为有明确定义并通过测试。

### 7.3 数据/安全/离线

- [ ] `../`、绝对路径、非法 filename 被拒绝；storage 只能访问 app data 根目录。
- [ ] NAS 密码不在普通 localStorage 明文保存；断网仍能浏览/播放已同步内容。
- [ ] 同步状态原子写、损坏可恢复，版本迁移有测试；清理操作明确区分“清状态”和“删文件”。

---

## 8. 分阶段实施顺序

### Phase 0：发布止血（半天–1 天）

1. 选定 `src-tauri/gen/android` 为唯一正式壳；锁定发布分支/commit，停止从当前落后 HEAD 和 `android-test-app` 直接发布。
2. 从 git 删除 build/.gradle/APK 中间物（只清构建产物，不改业务代码）；构建目录加入正确 `.gitignore`。
3. 修复 CI：init → icon sync → build → 清理旧 outputs → APK manifest/resource/signature 检查。
4. Manifest 补 `roundIcon`，统一产品名/identifier/versionCode；release 禁止 debug signing。
5. 真机做图标矩阵和冷启动验证。

### Phase 1：卡顿主因（1–3 天）

1. 音频切换到 `convertFileSrc`/asset protocol 或 Android Media3，去掉 `read_audio_file` base64 路径；处理 URL/Audio source 生命周期。
2. SMB 下载改流式写 `.part`，完成后 atomic rename；加 timeout/cancel/retry。
3. 删除生产 TCP debug reporter；改结构化、节流日志。
4. progress 按时间/bytes 节流，SyncPage 日志环形限制；为同步添加全局 coordinator + Rust lock。
5. 对 500MB 播放、1GB 下载、1000 文件同步做 profiler/heap/长任务基线。

### Phase 2：可用性与规模（3–7 天）

1. state 改原子/批量 checkpoint，考虑 SQLite/file index；加入文件校验、删除/移动/冲突策略。
2. PlayerUI 拆分订阅、播放列表虚拟化；MusicLibrary/RemoteBrowser 虚拟化，搜索 debounce/index。
3. MediaSession 节流；本地字体；统一 toast/offline/error/retry 状态。
4. Keystore 凭据、路径 traversal 防护、capability 最小权限审计。

### Phase 3：Android 原生播放与产品增强（1–2 周）

1. Media3 `MediaSessionService` + foreground notification + audio focus + headset controls。
2. 队列、歌词、封面缩略图缓存、后台下载通知/任务中心。
3. 均衡器、收藏/最近播放、多 NAS profile、故障注入测试。

---

## 9. 给执行 Agent 的开工指令

- 不要先“重画图标”或调 CSS；先锁发布 commit、清理陈旧 APK、加 APK 自动验收。
- 不要把 `android-test-app` 的 Manifest/资源复制进 Tauri 壳；两个壳要么明确用途，要么删除一个。
- 卡顿修复必须先有三个基线：500MB 播放、1GB 下载、1000 文件同步；每次修复记录 JS heap/RSS/长任务/IPC 频率。
- 每个 P0/P1 修复要有对应测试或可重复脚本；不能仅凭“本地能打开”。
- 任何 Android 构建都报告：源码 commit、applicationId、versionName/versionCode、签名指纹、ABI、APK SHA256、图标资源列表。

---

## 10. 审查证据摘要

- `generate-icons.sh` 在 Debian 主机上依赖 `sips`，跨平台失败风险已确认。
- 当前 `src-tauri/icons/android` 与 `src-tauri/gen/android/app/src/main/res` PNG md5 一致，资源静态存在。
- 当前可见旧 APK 解包成功，含 5 种 density 的 `ic_launcher`/`ic_launcher_round`；但二进制 Manifest 显示旧 `com.nasmusic.test`/`NasMusicSync`，证明陈旧产物误装路径真实存在。
- 无 Android SDK/JDK（当前 `java` 不存在），未执行 Tauri Gradle 正式构建；没有伪造构建结果。已有 APK 只做了解包/资源验证。
- 当前 HEAD 与 `origin/ralph/github-actions-android-apk` 不同：后者多 73 commits，已引入后台同步/file index/流式 `convertFileSrc` 方向，但仍保留整文件 SMB 缓冲和调试上报；后续修复必须明确针对哪个 commit。
