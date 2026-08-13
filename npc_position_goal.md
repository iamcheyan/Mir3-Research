# Zircon NPC 位置全面修正（EI 地图坐标系对齐）— 完整任务目标

## 一、任务背景

Zircon 私服的地图已替换为 20 年前 EI（传奇3）版地图（0=比奇县, 01=边境城市, 02=银杏山谷, 2=Banya Village, 74=盟重县…），
但 **System.db 里 294 个 NPC 的位置还是原版 Zircon 坐标系**——除了沙巴克（3=Sabuk Keep，地图本身用的 Z 版所以位置正确）。
结果：NPC 全都站在错误位置（房子里/墙上/地图外），玩家找不到铁匠药店，游戏没法玩。

你的任务：**把全部 NPC（除沙巴克）的位置修正到 EI 地图坐标系**。验收标准：**至少一大半（≥150/294）NPC 站在合理位置**（店铺内/城镇广场/房间内/任务区边缘）。

## 二、数据源（已调查好，直接用）

### 2.1 原版 NPC 坐标（权威源，两个版本交叉验证）

1. **Mud3 原版 Merchant.txt**（318 条 NPC 坐标）：
   - 源文件：`~/NAS/TMP/Mud3/Envir/Merchant.txt`（GB18030 编码，iconv 转 UTF-8）
   - **已解析好：`/tmp/mud3_merchant.json`**（script/map/x/y/name，318 条）
   - 格式：`脚本名 地图ID X Y 显示名`，如 `02Weapon_Bichon1  0  402 356  啊康`
2. **EI3.0英雄杀版 Merchant.txt**（89 条，可交叉验证）：
   - 源文件：`~/NAS/TMP/EI3.0英雄杀服务端/Mud3/Envir/Merchant.txt`
   - **已解析好：`/tmp/yxs_merchant.json`**（89 条）
   - 注：英雄杀版加了很多自定义功能 NPC（泡点/VIP/钻石抽奖），这些 Zircon 没有，忽略；但它对原版 NPC 的坐标可作第二意见
3. **Mapinfo.txt**（EI 地图定义，查地图尺寸用）：`~/NAS/TMP/Mud3/Envir/Mapinfo.txt`（GB18030）

### 2.2 Zircon 侧现状

- **NPC 表**：System.db 的 NPCInfo（294 条）。当前导出快照 `/tmp/dbviewer_data/NPCInfo.json`
  （注意此快照是旧的，写库前要用 dumpdb 模式重新读库）
- **位置机制**：NPC 挂在 MapRegion（点区域，PointRegion.CenterX/CenterY 即坐标）下。
  修位置 = 改 MapRegion 的 PointRegion 坐标（或必要时换 Map 到正确的图再设坐标）
- **当前分布**（旧 Z 坐标系下的地图分布，仅参考）：Lost Paradise 33 / Bichon Town 24 / 银杏山谷 24 / 边境城市 21 / Banya Village 13 / 盟重县 13 / 诺玛沙漠 12 / Numa Village 11 / 沙漠泥堡 10 / Banya Island 10 / Sabuk Keep 9（沙巴克不动！）…
- **名字匹配现状**：294 个 NPC 里 **119 个 NPCName 与 Mud3 脚本名完全一致**（如 02Weapon_DoGwan、04Potion_Bichon1）——这批直接搬坐标即可

### 2.3 关键事实（mir3-project skill 已验证，勿重查）

- NPC 名匹配铁律：NPCName 是 Korean 脚本名（01Meet_Kugkyung 式），其 Region 显示名（"0 / Weapon Store"）
  里斜杠后是店铺类型；光通经典版中文显示名见 `Mir3-Research/references/npc-name-localization.md`（如 01Meet_Kugkyung=肉店金老板）
- 同一 NPCName 可能多条不同显示名（04Potion_SinGiSun=花仙/火龙/火风/火天），按 NPCInfo 行序对应 Merchant 行序
- **沙巴克（Map 3, Sabuk Keep）的 9 个 NPC 不动**（地图就是 Z 版的，位置本来对）
- 地图文件在 `zircon/Debug/Client/Map/*.map`；MapRegion 点坐标必须在对应地图的可行走区域内

## 三、匹配策略（按优先级）

1. **精确匹配**（119 个）：NPCName == Mud3 脚本名 → 直接用 Mud3 的 (map,x,y)
2. **语义匹配**（其余 ~100 个）：
   - 脚本名前缀分类（01Meet=杂货/肉类, 02Weapon=武器店, 03Armor/03Shoes=防具, 04Potion=药店,
     05Make=药剂/杂货制作, 14Quest=任务NPC…）+ Region 显示名里的店型 + 地图归属
   - 例：Zircon "Mr. Kang"（Region "0 / Weapon Store"）→ Mud3 里 0 图的武器店 `02Weapon_Bichon1/2` 取其一坐标
   - EI 的 NPC 中文名可辅助判断（药店老板/肉店老板/铁匠铺…）
3. **推算兜底**（剩余）：
   - 城镇 NPC（店型 Region）→ 放对应城镇地图中心附近的可行走格子（比奇县中心约 (400,300) 附近密集区，
     参考同图其他 NPC 坐标聚簇）
   - 任务 NPC → 城镇边缘/郊区/洞窟入口（参考 Mud3 中 14Quest_* 系列的分布规律）
   - **必须验证坐标在地图范围内且可行走**（用 Tools/maps 的 .map 解析；Mir3-Research 有 mapviewer/zlsdk 现成代码）
4. **同一 NPC 多实例**（同 NPCName 多条）：按行序对齐 Merchant 里的多行（如 14Quest_WoomaPalace 有 3 行不同坐标）

## 四、写库方式（重要，别写坏）

- 参考现有工具：`/tmp/dumpdb/Program.cs`、`/tmp/bgmfill/Program.cs`（**bgmfill 是今天刚验证可用的模板**）：
  `new Session(SessionMode.Both, root)` + `session.Initialize(LibraryCore程序集, ServerLibrary程序集)` +
  改对象属性 + `session.Save(true)`
- ⚠️ Session root 必须是**带尾斜杠的绝对路径**；`Initialize` 要传**两个程序集**（typeof(ItemInfo) + typeof(CharacterInfo) 的）
- **写库前必须：服务端已停**（检查 7000 端口无监听）+ 备份双库（服务端 Database/System.db 和 Debug/Client/Data/System.db）
- **双库都要写**（或写服务端库后复制到客户端路径）
- 工具代码放 `Mir3-Research/Tools/NpcMover/`（新工程，参考 bgmfill 的 csproj：ProjectReference 指向
  zircon 的 LibraryCore.csproj + ServerLibrary.csproj，net10.0）
- 干跑模式先行：先打印全部"NPC → 新坐标"映射清单，人工过目（写入 goal 最终报告）再 apply

## 五、验收（必须真做）

1. 干跑清单：294 个 NPC 每个的 旧位置 → 新位置 → 匹配方式（精确/语义/推算）→ 数据来源
2. 写库后 round-trip：重新读库验证坐标已更新
3. **游戏内验证**（无头）：Xvfb :101(4K)+openbox 起客户端（测试账号 test@test.com/test123/TestHero，
   GM 权限），`@move 0` 到比奇县截图——主城 NPC 群应聚在城区（不再散落地图各处）；
   再抽 2-3 张城镇（01/02/2）截图。截图存 `~/development/zircon/screenshots/`（编号续接）并 push
4. 统计报告：精确匹配 N 个 / 语义 M 个 / 推算 K 个 / 保持不动（沙巴克9个+特殊）J 个；**合理位置率 ≥ 50%**
5. 提交：NpcMover 工具 + 截图 push 到 Mir3-Research（工具）和 zircon（截图），中文 commit

## 六、边界

- 不动 Users.db；不动 NPCInfo 的非位置字段（名字/对话/商店绑定）
- 沙巴克（Map 3）9 个 NPC 原样保留
- 贴图（Image/FaceImage）不动——只修位置
- 机器 4核15GB：dotnet build 加 `-m:2`；编译/起客户端错峰（先 build 完再启动）
- 如果某 NPC 在两个版本里坐标冲突（Mud3 vs 英雄杀），取 Mud3（更原版）；都拿不到就推算并标注

## 七、实施顺序建议

1. 读 §二 数据源 → 写匹配脚本（Python，纯离线对 JSON）→ 产出三档映射表
2. NpcMover C# 工程：干跑打印 → 检查（特别抽查 20 个知名 NPC：比奇武器店/药店/杂货、边境铁匠…）
3. 停服检查+备份 → apply 写双库 → round-trip 验证
4. 无头客户端游戏内截图验收（比奇/边境/银杏各一张 + 全图缩略）
5. 报告 + 提交
