# 网页客户端 vs Godot 客户端 像素级一致性审计 — 完整任务目标

## 一、使命（用户拍板）

最终目标：**网页客户端与 Godot 客户端一模一样，不能有任何差异**。
本 goal 是一次**深度审计**：把 webport(:8823) 与 Godot 客户端做穷尽式对比，
产出一字节级/像素级/行为级的**差异清单**（不是修完——是查全、量化、分级），
作为后续"零差异"迭代的唯一事实依据。

## 二、对比方法论（必须严格执行）

### A. 场景级并排截图对比（核心证据）
1. **Godot 端**：无头配方跑真客户端——`Xvfb :100 + openbox`，`/tmp/godot-mono`
   跑 `GodotClient`（参数在 `--` 之后），`ZIRCON_UI_SCALE=1`，scrot 截图。
   场景：登录页→服务器列表→角色选择→进比奇（出生点）→走路/攻击/开背包/开技能/
   NPC 对话/小地图，每个状态一张（分辨率 1024x768 原生逻辑分辨率）。
   测试号 test@test.com/test123/TestHero(GM)；ServerCore 已在 :7000 跑。
2. **Web 端**：无头浏览器（CDP）同分辨率 1024x768 视口、deviceScaleFactor=1，
   `http://127.0.0.1:8823/`，**Zircon 模式**（默认），逐个复现 Godot 同款状态截图
   （截图前等资源加载完，等待逻辑用轮询 document.fonts/网络空闲）。
3. 每对截图存 `docs/webport/audit/screenshots/{场景}_godot.png / {场景}_web.png`。
4. **逐对像素对比**：Python PIL `ImageChops.difference` + diff 区域框注图
   （{场景}_diff.png）；量化：差异像素占比、最大差异区块位置。

### B. UI 树结构对比
- Godot：`--ui-export` 的 `ui_tree.json`（最新版，若旧先重导出）
- Web：加载后 dump DOM 布局（每个窗口的 x/y/w/h/贴图 frame/文字内容/字号/颜色，
  JS 遍历渲染树输出 JSON）
- 脚本对比两棵树：坐标差 >1px、贴图帧号不同、文字/字号/颜色不同——全部列出
  （表格：控件路径 | Godot 值 | Web 值 | 差异类型）

### C. 行为对比（逐事件）
登录流程包序列（C.AccountLogin→…→StartGame）、走路（按住 W/点击移动的步频、
格移动平滑）、对象同步（玩家/NPC/怪物出现消失）、聊天、背包操作——Web 端
每步对照 zdocs 协议文档 + GodotClient 源码（Network/Packet.cs、GameScene.cs）
核对时序与表现，浏览器 console 记录包收发。

### D. 资源对比
WebData 的 Interface/物件/怪物贴图帧 vs Godot 实际用的 Zl 帧：抽样 50 帧
（登录界面全量+游戏内高频），帧号映射、WebP 质量（PSNR ≥45dB 视为无损级）、
调色（通道顺序/透明度边缘）。

## 三、产出（唯一交付物：审计报告）

`docs/webport/audit/AUDIT_REPORT.md`（中文，穷尽式）：

1. **执行摘要**：总差异计数（像素/结构/行为/资源四类），整体一致性 %（按场景加权）
2. **逐场景差异表**：场景|截图对|像素差%|结构差数|行为差数|评级（S=<1%像素差+0结构差 /
   A=<5% / B=<15% / C=≥15%）
3. **结构差异全清单**（B 节表格全量）
4. **行为差异全清单**（每条：预期[Godot 源码引用文件:行号] vs 实际[web 表现/截图]）
5. **资源差异全清单**
6. **修复优先级**：P0=一眼假（布局错位/贴图错帧）/P1=交互差异/P2=细节打磨，
   每条带工作量估计
7. **附录**：截图对索引、复现命令

## 四、纪律

- 只审计不修改（webport 代码一行不动；发现的小 bug 记报告）
- Godot 端截图必须真实运行客户端（不拿旧截图/设计稿充数）
- 每个结论都要证据（截图/diff 图/JSON/源码行号），禁止"看起来差不多"
- 区分"Phase1 范围外未实现"（如技能面板没做）与"实现了但有差异"——
  未实现的单独列「未实现清单」不算差异，但必须列全
- 磁盘预算：截图/中间产物 <500MB，放 docs/webport/audit/
- 报告+截图 commit+push；AGENTS.md 的 webport 节追加审计报告索引

## 五、边界

- 不碰 System.db/服务端；不重启 ServerCore（已在跑）
- webport serve.py(:8823) 保持运行（审计期间别动它）
- Xvfb :100 若被占先清理残留（pkill 旧 Xvfb :100）
