# Preview 服务端配置与数据（Envir / Envir3）

> 证据源：`reference/mir3-source/Mud3-Config/`（2,193 文件 / 约 6 MB）+ 解析代码
> `Source/GameServer/{LocalDB,svMain,Envir,ObjNpc}.pas`。
> 证据等级 `secondary-source`。
>
> **编码**：`Mud3-Config/**` 是 **GB18030**，读前必须
> `iconv -f gb18030 -t utf-8`（或 `Tools/source-read/read_src.py`）。

---

## 1. 两套配置目录的实测对比（**本轮最重要的发现**）

| | `Envir/` | `Envir3/` |
|---|---:|---:|
| 文件数 | **391** | **1,802** |
| 总字节 | 850,307 | 5,279,416 |
| **空文件数** | **9** | 3 |
| 源码引用 | ✅ `EnvirDir` 默认 `.\Envir\` | ❌ **全仓 grep `Envir3` 命中 0 次** |

### 1.1 `Envir/` 的 9 个空文件（严重）

```
Castle/AttackSabukWall.txt
GenMsg.txt
GuardList.txt
MapQuest.txt
Market_Def/Light-D2083.txt
MerChant.txt
MonGen.txt
Npcs.txt
StartUp/StartupQuest.txt
```

**而 `Envir3/` 里同名文件是有内容的**：

| 文件 | `Envir` | `Envir3` |
|---|---:|---:|
| `guardlist.txt` | **0** | 4,703 |
| `mapquest.txt` | **0** | 59,726 |
| `merchant.txt` | **0** | 41,074 |
| `mongen.txt` | **0** | 1,915 |

**结论**：`Envir/` 是一个**被抽空的骨架** —— 地图表（`Mapinfo.txt` 110 KB）和
商店脚本（`Market_Def/`）是完整的，但**NPC 列表、刷怪表、守卫表、地图任务表
全被清空**。`Envir3/` 才有这些内容。

> ⚠️ **对研究的影响**：`reference/mir3-source/README.md` §4 称「`Envir/` 才是源码
> 真正读的那套」—— 这话在**代码层面正确**（`EnvirDir` 默认 `.\Envir\`），
> 但**数据层面 `Envir/` 是空的**。想研究 NPC/刷怪/任务的实际内容，
> **必须用 `Envir3/`**，同时清楚「本版源码不读它」这个矛盾。
> 二者合起来才是一份完整配置。

### 1.2 两份 `Mapinfo.txt` 并存

`Envir/Mapinfo.txt`（110,269 B）与 `Envir/1MapInfo.txt`（99,820 B）
**内容不同** —— 后者是手工保留的备用地图表（文件名带字面 `1`，非大小写冲突）。
另有 `Envir3/MapInfo.txt`（80,340 B），三者都不同。

---

## 2. 源码实际读取的 19 个配置文件（已逐条验证）

按名读取的字符串常量（grep `Source/GameServer/`）：

| 常量 | 出现次数 | 内容 |
|---|---:|---|
| `'AdminList.txt'` | 3 | GM 名单 |
| `'MapInfo.txt'` | 1 | 地图表（`LocalDB.pas:13` `MAPDEFFILE`） |
| `'MiniMap.txt'` | 2 | 小地图索引表（`LocalDB.pas:32` `MINIMAPFILE`） |
| `'MonGen.txt'` | 2 | 刷怪表 |
| `'Merchant.txt'` | 1 | 商人表（**注意首字母大写 M**） |
| `'Npcs.txt'` | 1 | NPC 表 |
| `'GuardList.txt'` | 1 | 守卫表 |
| `'MapQuest.txt'` | 2 | 地图任务表 |
| `'MakeItem.txt'` | 2 | 制作表 |
| `'DecoItem.txt'` | 2 | 装饰品表 |
| `'DragonItem.txt'` | 1 | 龙物品表 |
| `'GenMsg.txt'` | 2 | 通用消息 |
| `'UnbindList.txt'` | 2 | 解绑表 |
| `'StartPoint.txt'` | 2 | 出生点 |
| `'SafePoint.txt'` | 2 | 安全点 |
| `'StartupQuest.txt'` | 1 | 启动任务 |
| `'AttackSabukWall.txt'` | 1 | 沙巴克攻城 |
| `'Sabuk.txt'` | 2 | 沙巴克 |
| `'enckey.txt'` | 1 | ⚠️ 见 §5 |

---

## 3. `MapInfo.txt` 格式（权威解析器已定位）

**解析器**：`LocalDB.pas:529` 起，`MAPDEFFILE = 'MapInfo.txt'`（`:13`）。

### 3.1 行格式

```
[<地图名> <中文标题> <服务器号>] <标志1> <标志2> ...
```

解析流程（`:542-556`）：

```pascal
if str[1] = '[' then begin
   str := ArrestStringEx (str, '[', ']', map);          // 取出括号内容
   maptitle := GetValidStrCap (map, map, [' ', ',', #9]); // 第一个 token = 地图名
   if maptitle[1] = '"' then ArrestStringEx (maptitle, '"', '"', maptitle);
   servernum := Trim(GetValidStr3 (maptitle, maptitle, [' ', ',', #9])); // 服务器号
   svindex := Str_ToInt (servernum, 0);
```

即 `[D4301 洞穴海岸 0] DAY` 解析为：地图名 `D4301`、标题 `洞穴海岸`、
服务器号 `0`、标志 `DAY`。

### 3.2 完整标志位表（`LocalDB.pas:593-659`，逐条实测）

| 标志 | 源码变量 | 语义 |
|---|---|---|
| `SAFE` | `law` | 治安区（杀人即被通缉） |
| `DARK` | `dark` | 黑暗 |
| `DAWN` | `dawn` | 黎明 |
| `FIGHT` | `fight` | 比武场 |
| `FIGHT2` | `fight2` | 比武狩猎场 |
| `FIGHT3` | `fight3` | 可复活 3 次 |
| `FIGHT4` | `fight4` | — |
| `DAY` | `sunny` | 白天 |
| `QUIZ` | `quiz` | 禁止喊话 |
| `NORECONNECT(<地图>)` | `norecon` + `backmap` | 断线不回；括号内是回退地图，**空则 `Result := -11`** |
| `CHECKQUEST(<npc>)` | `npc` | 进图前先过该 NPC 的任务（**只能一个条件**） |
| `NEEDSET_ON(<num>)` | `setval=1` + `setnum` | 需变量开启 |
| `NEEDSET_OFF(<num>)` | `setval=0` + `setnum` | 需变量关闭 |
| `NEEDHOLE` | `needhole` | 需要洞 |
| `NORECALL` | `norecall` | 禁止召唤 |
| `NORANDOMMOVE` | `norandommove` | 禁止随机移动 |
| `NOESCAPEMOVE` | `NoEscapeMove` | 禁止逃脱移动（sonmg） |
| `NOTELEPORTMOVE` | `NoTeleportMove` | 禁止瞬移（sonmg） |
| `NODRUG` | `nodrug` | 禁止用药 |
| `MINE` / `MINE2` / `MINE3` | `minemap` = 1/2/3 | 矿区等级 |
| `NOPOSITIONMOVE` | `nopositionmove` | 禁止位置移动 |
| `THUNDER` | `autoattack=1` | 自动攻击（雷） |
| `FIRE` | `autoattack=2` | 自动攻击（火） |
| `NOMAPXY` | `autoattack=3` | sonmg 2005/03/14 |
| `GUILDAGIT(<num>)` | `GuildAgit` | 行会据点号（并跟踪最小/最大号） |
| `NOCHAT` | `nochat` | 禁止聊天（2004/10/12） |
| `NOGROUP` | `nogroup` | 禁止组队 |
| `NOTHROWITEM` | `nothrowitem` | 禁止丢弃物品（2005/03/14） |
| `NODROPITEM` | `nodropitem` | 死亡不掉落 |

### 3.3 实测：`Mapinfo.txt` 里的标志使用频率

| 标志 | 出现次数 |
|---|---:|
| `DARK` | 436 |
| `NORECALL` | 162 |
| `NORECONNECT` | 143 |
| `DAY` | 102 |
| `NOPOSITIONMOVE` | 95 |
| `NORANDOMMOVE` | 94 |
| `FIGHT` | 57 |
| `SAFE` | 34 |
| `MINE` | 18 |
| `NEEDHOLE` | 16 |
| `MINE2` | 3 |
| `NODRUG` | 1 |

> **注意**：源码支持 28 个标志，实际配置只用了 12 个 ——
> 其余 16 个（`DAWN`/`FIGHT2-4`/`QUIZ`/`CHECKQUEST`/`NEEDSET_*`/`MINE3`/
> `THUNDER`/`FIRE`/`NOMAPXY`/`GUILDAGIT`/`NOCHAT`/`NOGROUP`/`NOTHROWITEM`/
> `NODROPITEM`）在这份配置里**未使用**。

---

## 4. `MiniMap.txt` —— 闭合 `CM_WANTMINIMAP` 的最后一环

**解析器**：`LocalDB.pas:1389-1415`，`MINIMAPFILE = 'MiniMap.txt'`（`:32`）。

```pascal
for i:=0 to strlist.Count-1 do begin
   str := strlist[i];
   if str <> '' then begin
      if str[1] <> ';' then begin                  // ';' 开头是注释
         str := GetValidStr3 (str, smap, [' ', #9]);   // 地图名
         str := GetValidStr3 (str, idxstr, [' ', #9]); // 小地图号
         index := Str_ToInt(idxstr, 0);
         if index > 0 then
            MiniMapList.AddObject (smap, TObject(index));
      end;
   end;
end;
```

格式：`<地图名> <小地图号>`，`;` 开头是注释。

实测内容（`Envir/MiniMap.txt`，4 KB）：
```
;;海メ盗
D4301 691
D4302 692
D4303 693
...
```

### 4.1 与 `CM_WANTMINIMAP` 的完整链路（**端到端闭合**）

```
服务端启动: LocalDB.LoadMiniMapInfos 读 MiniMap.txt → MiniMapList[地图名 → 小地图号]
                                          │
                                          └─ 赋值给 TEnvirnoment.MiniMap（Envir.pas:155）
                                                    │
客户端点击小地图按钮 → 发 CM_WANTMINIMAP(0x409) ────────┘
                    ← SM_READMINIMAP_OK(710)  Param = PEnvir.MiniMap
                    ← SM_READMINIMAP_FAIL(711) 若 MiniMap <= 0
                                          │
客户端: ClientGetReadMiniMap(Param) → MiniMapIndex := Param - 1
        BoDrawMiniMap := True; DMiniMapDlg.Visible := True
```

**这是 Round 802 的 `0x409` 结论的完整数据侧补充**：
小地图号的**数据源是 `MiniMap.txt`**，由服务端加载后随地图对象持有，
客户端只负责请求和显示（`MiniMapIndex := Param - 1` 的 `-1` 偏移已确认）。

> 对本仓库 `minimap-server-crossref.json` 的意义：
> 该文件正是这张 `MiniMap.txt` 交叉表，**现在有了权威的格式解析依据**。

---

## 5. `enckey.txt` —— 确认**未被使用**（闭合 Round 803 的疑问）

`svMain.pas:1273`：

```pascal
//      if LoadPublicKey( EnvirDir + 'enckey.txt' ) then
```

**整行被注释掉**。这**直接证实**了 Round 803 的结论：
公钥**不是**从配置文件读取，而是登录期动态协商
（`LoginServer → DataBaseServer → GameServer → 客户端`，
见 `wire-format.md` §5）。

→ `reference/mir3-source/README.md` §4 把 `enckey.txt` 列入
「源码实际按名读取的配置」是**不准确的** —— 它在代码里存在但**被禁用**。

---

## 6. `Envir3/` 的内容结构（真正有数据的部分）

| 目录 | 内容 |
|---|---|
| `QuestDiary/` | **任务脚本树**（最大：`QT_TODAY/4Grade.txt` 188 KB、`Event/DiceGame/Dice.txt` 148 KB、`Make_Item/AtomItem.txt` 139 KB、`Teleport/mapinfo.txt` 105 KB） |
| `Mon_Def/` | 69 个 `.gen` 刷怪定义 |
| `Market_Def/` | 商店脚本 |
| `MonItems/` | 怪物掉落表 |
| `Convert_Def/` | 转换定义（1,791 个文件，多数仅 Envir3 有） |
| `Flag_Def/` `GM_Def/` | 标志/GM 定义 |

**注意**：`Envir3/QuestDiary/QT_TODAY/QT_TODAY/` 存在**嵌套同名目录**
（`4thClass.txt` 在两层各有一份，171,184 vs 171,253 字节，**内容略有不同**）——
说明该配置树有**版本叠加**痕迹，取用时要确认是哪一层。

### 6.1 与 `Tools/questdata` 的关系

`QuestDiary/` 是任务脚本树，`QuestDiary/System/Message/content.txt` 是空文件。
结合 `server.md` §4.1 的结论（任务引擎在 `ObjNpc.pas` 的 `TQuestRecord`），
**任务的三要素**是：

1. **结构**：`ObjNpc.pas` 的 `TQuestRecord` / `TQuestRequire`
2. **内容**：`Envir3/QuestDiary/` 的脚本树
3. **入口**：`MapInfo.txt` 的 `CHECKQUEST(<npc>)` 标志 + `MapQuest.txt`

> 本仓库 `Tools/questdata` 目前主要基于 `System.db` 的 `QuestInfo`。
> 源码给出的这三个要素可作为**独立的交叉验证源**。

---

## 7. ~~未破译项~~ → **已破译（2026-09-26 更新）**

`Envir3/QuestDiary/NQ_BASE/MonQuest/` 的 3 个 `.txt`
（`Nm_Chiken.txt`/`Nm_Cow.txt`/`Nm_OmaJunsa.txt`，342–881 B）
**曾**被登记为「非 GB18030/cp949 的私有编码，未破译」。

**现已破译：它们是 WEMADE 加密**（`Source/Common/EDCode.pas:465-522`
的 `Decrypt` 算法），**已全部成功解密为合法 GB18030 任务脚本**。

| 项 | 内容 |
|---|---|
| 识别线索 | 文件头 `f0 39 aa c0 …` 与 `EDCode.Decrypt` 的硬编码种子 `F0 39 AB 8E` **前 2 字节相同** |
| 长度验证 | `ProcLen` 按**大端**解释 = `334`，恰等于文件大小 342 − 8 ✅ |
| 算法 | 头 8 字节（种子 XOR 长度 + 校验和）+ 正文 **4 轮递增 CRC XOR** |
| ⚠️ 坑 1 | `ProcLen` 是**大端**（源码 `MakeLong`/`MakeWord` 嵌套写法易误判为小端） |
| ⚠️ 坑 2 | **校验和字段不可信** —— 3 个文件的 `data[4..7]` 与源码公式算出的都不匹配，但正文仍能正确解密。实用结论：**跳过校验、只做 XOR** |
| 扫描结果 | `QuestDiary/` 全树 443 个文件中**只有这 3 个**是加密的，全部已破译 |
| 工具 | `Tools/source-read/wemade_decrypt.py`（`--scan` 可扫目录） |

**三处独立证据交叉一致**：源码 opcode 表（`server.md` §12）↔ 明文脚本（§12.9）↔
解密脚本。解密出的内容含 `[@main]`/`#IF`/`#ACT`/`check [164] 1`/
`goto @dark`/`random 2`/`give 鸡血` —— 完全符合 §12 解出的语法。

→ **`Envir3/QuestDiary/` 的 443 个脚本现已全部可读**（440 明文 + 3 解密）。
详见 `server.md` §13.10。

---

## 8. 待办

| 项 | 说明 |
|---|---|
| `MonGen.txt` 格式（`Envir3` 版） | 未读解析器 |
| `Merchant.txt` / `Npcs.txt` 格式 | 未读解析器 —— 与 `TNormNpc` 能力标志的映射是重点 |
| `MakeItem.txt` / `DragonItem.txt` / `DecoItem.txt` | 未读 |
| `StartPoint.txt` / `SafePoint.txt` | 已看内容（`地图 x y`），未读解析器 |
| `Envir3/QuestDiary/` 脚本语法 | ✅ **已解**（`server.md` §12.9/§13.10） |
| ~~MonQuest 私有编码~~ | ✅ **已破译**（见 §7） |
| `Envir/` 为何被抽空 | 未知（是否原作者有意清理？） |


---

## 9. 复核方式

```bash
# 两套配置对比（文件数/空文件/同名对照）
python3 Tools/source-read/env_compare.py

# 读 GB18030 配置
python3 Tools/source-read/read_src.py show Mud3-Config/Envir/MiniMap.txt --start 1 --end 12
iconv -f gb18030 -t utf-8 reference/mir3-source/Mud3-Config/Envir/Mapinfo.txt | head -30

# 标志位统计
iconv -f gb18030 -t utf-8 reference/mir3-source/Mud3-Config/Envir/Mapinfo.txt \
  | grep -oE '\b(SAFE|DARK|FIGHT[0-9]?|DAY|MINE[0-9]?|NORECALL)\b' | sort | uniq -c | sort -rn

# 源码侧解析器
python3 Tools/source-read/read_src.py show Source/GameServer/LocalDB.pas --start 529 --end 660
python3 Tools/source-read/read_src.py show Source/GameServer/LocalDB.pas --start 1389 --end 1415
```

---

## 14. 配置解析器全表（Round 813）

> 全部解析器集中在 `Source/GameServer/LocalDB.pas`（2,649 行）。
> 机器可读：[`config-parsers.tsv`](config-parsers.tsv)（19 个函数 / 94 个字段读取点）。
> 提取器：`Tools/source-read/extract_config_parsers.py`。

### 14.1 文件名常量全表（`LocalDB.pas:11-39`）

| 常量 | 值 | 目录/文件 |
|---|---|---|
| `ZENFILE` | `MonGen.txt` | 刷怪表 |
| `ZENMSGFILE` | `GenMsg.txt` | 刷怪公告 |
| `MAPDEFFILE` | `MapInfo.txt` | 地图表 |
| `MONBAGDIR` | `MonItems\` | **掉落表目录** |
| `ADMINDEFFILE` | `AdminList.txt` | GM 名单 |
| `CHATLOGFILE` | `ChatLog.txt` | 聊天日志 |
| `MERCHANTFILE` | `Merchant.txt` | 商人表 |
| `MARKETDEFDIR` | `Market_Def\` | **商店脚本目录** |
| `MARKETSAVEDDIR` | `.\Envir\Market_Saved\` | 市场存档 |
| `MARKETPRICESDIR` | `.\Envir\Market_Prices\` | 市场价目 |
| `MARKETUPGRADEDIR` | `.\Envir\Market_Upg\` | 市场升级 |
| `GUARDLISTFILE` | `GuardList.txt` | 守卫表 |
| `MAKEITEMFILE` | `MakeItem.txt` | 制作表 |
| `NPCLISTFILE` | `Npcs.txt` | NPC 表 |
| `NPCDEFDIR` | `Npc_def\` | **NPC 对话脚本目录** |
| `STARTPOINTFILE` | `StartPoint.txt` | 出生点 |
| `SAFEPOINTFILE` | `SafePoint.txt` | 安全点 |
| `DECOITEMFILE` | `DecoItem.txt` | 装饰品 |
| `MINIMAPFILE` | `MiniMap.txt` | 小地图索引 |
| `UNBINDFILE` | `UnbindList.txt` | 解绑表 |
| `MAPQUESTFILE` | `MapQuest.txt` | 地图任务 |
| `MAPQUESTDIR` | `MapQuest_def\` | 地图任务脚本目录 |
| `QUESTDIARYDIR` | `QuestDiary\` | **任务脚本树目录** |
| `QUESTDEFINEDIR` | `Defines\` | 定义目录 |
| `STARTUPDIR` | `Startup\` | 启动目录 |
| `STARTUPQUESTFILE` | `StartupQuest` | 启动任务（无扩展名） |

**三个脚本目录的分工**（此前文档未区分）：

| 目录 | 内容 | 引用者 |
|---|---|---|
| `Market_Def\` | 商店脚本 | `Merchant.txt` 的 `MarketName` |
| `Npc_def\` | NPC 对话脚本 | `Npcs.txt` 的 NPC 名 |
| `QuestDiary\` | **任务脚本树**（443 个 `.txt`） | `MapQuest.txt` 的 `qFile` + NPC 脚本 |

### 14.2 `MonGen.txt` 格式（`LoadZenLists`，`:385-458`）

**12 个字段**，是**字段最多**的配置：

```
<地图名>  <X>  <Y>  "<怪物名>"  <范围>  <数量>  <刷怪时间(分)>  <小刷率>  <TX>  <TY>  <喊话类型>  <喊话内容>
```

| # | 变量 | 记录字段 | 解析 | 语义 |
|---|---|---|---|---|
| 1 | `data` | `pz.MapName` | `GetValidStr3` + **`UpperCase`** | 地图名 |
| 2 | `data` | `pz.X` | `Str_ToInt(...,0)` | X 坐标 |
| 3 | `data` | `pz.Y` | `Str_ToInt(...,0)` | Y 坐标 |
| 4 | `data` | `pz.MonName` | `GetValidStrCap`（支持 `"引号"`） | 怪物名 |
| 5 | `data` | `pz.Area` | `Str_ToInt(...,0)` | 刷新范围 |
| 6 | `data` | `pz.Count` | `Str_ToInt(...,0)` | 数量 |
| 7 | `data` | `pz.MonZenTime` | `Str_ToInt(data,-1)` **× 60 × 1000** | 刷怪间隔（**分钟 → 毫秒**） |
| 8 | `data` | `pz.SmallZenRate` | `Str_ToInt(...,0)` | 小刷率 |
| 9 | `data` | `pz.TX` | `Str_ToInt(...,0)` | 事件目标 X（2003/06/20 加） |
| 10 | `data` | `pz.TY` | `Str_ToInt(...,0)` | 事件目标 Y |
| 11 | `data` | `pz.ZenShoutType` | `Str_ToInt(...,0)` | 喊话类型 |
| 12 | `data` | `pz.ZenShoutMsg` | `Str_ToInt(...,0)` | 喊话消息 |

**三个关键点**：
1. **刷怪时间单位是分钟**，代码里 `× 60 × 1000` 转毫秒（`:427`）。
2. **有效性校验**（`:441`）：`MapName <> ''` **且** `MonName <> ''`
   **且** `MonZenTime <> 0` 才注册，且地图必须存在
   （`ServerGetEnvir(ServerIndex, MapName) <> nil`）。
3. **末尾追加一条空记录**（`:450-454`）：`MapName := ''`、`MonName := ''`，
   注释「마지막은 운영자가 만드는 몬스터...」（最后一条是运营者创建的怪物）
   —— 即**给 GM 动态刷怪留的槽位**。

### 14.3 `Merchant.txt` 格式（`LoadMerchants`，`:891-940`）

```
<市场名>  <地图>  <X>  <Y>  "<商人名>"  <脸型>  <外观>  <城堡管理>
```

| # | 变量 | 字段 | 语义 |
|---|---|---|---|
| 1 | `marketname` | `merchant.MarketName` | 市场名（指向 `Market_Def\` 脚本） |
| 2 | `map` | `merchant.MapName` | 地图（**`UpperCase`**） |
| 3-4 | `xstr`/`ystr` | `merchant.CX`/`CY` | 坐标 |
| 5 | `seller` | `merchant.UserName` | 商人名（`GetValidStrCap` + 引号） |
| 6 | `facestr` | `merchant.NpcFace` | 脸型 |
| 7 | `apprstr` | `merchant.Appearance` | 外观 |
| 8 | `castlestr` | → `BoCastleManage := TRUE` | 非 0 即城堡管理 |

**校验**（`:920`）：`marketname`、`map`、`apprstr` **三者非空**。
**被注释掉的字段**（`:931-932`）：`StorageItem`、`RepairItem` ——
即早期版本用字段控制仓库/修理功能，后来改成 `Market_Def\` 脚本里的
`@storage`/`@repair` 命令（见 §14.8）。

**`ReloadMerchants`（`:942-`）的增量更新模式**（**值得学习的实现**）：

```pascal
// 1. 先把所有现存商人的 NpcFace 置 255（标记「待验证」）
for i := 0 to UserEngine.MerchantList.Count-1 do
   TMerchant(UserEngine.MerchantList[i]).NpcFace := 255;
// 2. 重新读文件，命中的商人重置 NpcFace
// 3. 仍为 255 的视为已删除，清理
```

注释原文：「기존에 있는 npc의 npcface를 모두 255로 변경한 후 업데이트를 시키고
255로 남아 있는 것은 삭제된 것으로 간주」（先把现存 NPC 的 npcface 全改成 255，
更新后再把仍是 255 的视为已删除）。**热重载不重启的经典手法。**

### 14.4 `Npcs.txt` 格式（`LoadNpcs`，`:1044-`）

```
"<NPC名>"  <种族>  <地图>  <X>  <Y>  <脸型>  <外观>
```

7 个字段：`nname`(UserName) / `racestr` / `map`(MapName,`UpperCase`) /
`xstr`(CX) / `ystr`(CY) / `facestr`(NpcFace) / `body`(Appearance)。
**注意第 2 个字段 `racestr` 被读但未见赋值** —— 可能是种族（用于 `TAnimal` 派生）。

### 14.5 `GuardList.txt` 格式（`LoadGuards`，`:1211-1252`）

```
"<守卫名>"  <地图>  <X>  <Y>  <朝向>
```

5 个字段。**分隔符与其他不同**（`:1235-1237`）：

```pascal
str := GetValidStr3 (str, xstr, [' ', ',']);       // 逗号也算分隔
str := GetValidStr3 (str, ystr, [' ', ',', ':']);  // 逗号+冒号
str := GetValidStr3 (str, dirstr, [' ', ':']);
```

→ **守卫表支持 `X,Y:Dir` 或 `X Y Dir` 两种写法**。

### 14.6 `StartPoint.txt` / `SafePoint.txt`（`:1296-` / `:1327-`）

格式相同：`<地图>  <X>  <Y>  [<范围>]`（4 字段，第 4 个可选）。

实测内容：
```
01 439 304
02 265 207
0  458 398
```

### 14.7 `DecoItem.txt`（`:1358-`）与 `MakeItem.txt`（`:1252-`）

**`DecoItem.txt`**：`<编号>  <名称>  <类型>  <价格>`，**分隔符含 `-`**
（`:1374-1377` `[' ', '-', #9]`）→ 支持 `1-名称-类型-价格` 连字符写法。

**`MakeItem.txt`**：用 `ArrestStringEx(str, '[', ']', makeitemname)` 取方括号内的
**制作配方名**（`:1275`），然后 `GetValidStr3` 取物品名 ——
即格式为 `[配方名] 物品名`。

### 14.8 `Market_Def\` 脚本与 NPC 功能命令（**与 §4.2 能力标志的桥**）

`LoadMarketDef` 解析商店脚本，从中提取**功能命令**。
这些命令正是 `TNormNpc` 的 `CanSell`/`CanBuy`/`CanStorage`/`CanRepair` 等
能力标志（`server.md` §4.2）的**激活来源**：

| 脚本命令 | 激活的能力 |
|---|---|
| `@buy` | `CanBuy` |
| `@sell` | `CanSell` |
| `@storage` | `CanStorage` |
| `@getback` | `CanGetBack` |
| `@repair` | `CanRepair` |
| `@s_repair` | `CanSpecialRepair` |
| `@t_repair` | `CanTotalRepair` |
| `@makedrug` | `CanMakeDrug` |
| `@upgrade` / `@upgradenow` | `CanUpgrade` |
| `@makeitem` / `@makestuff` / `@makeetc` / `@makefood` / `@makegem` / `@makepotion` | `CanMakeItem` |
| `@market_*` | `CanItemMarket` |
| `@agitbuy` / `@agitreg` / `@agitextend` / `@agittrade` | `CanAgitUsage`/`CanAgitManage` |
| `@ga_decoitem_buy` | `CanBuyDecoItem` |

→ **`ActivateNpcUtilitys(saystr)`（`ObjNpc.pas:136`）就是从脚本字符串里
识别这些 `@命令` 来打开对应功能的**（其注释
「상인이 할 수 있는 기능 제어, 판매, 구입, 맡기기 등...」= 控制商人能做什么）。

**这一条闭合了「配置文件 → 运行时能力」的转换链**：
`Merchant.txt` 给出 `MarketName` → `Market_Def\<MarketName>.txt` 里的
`@命令` → `ActivateNpcUtilitys` 打开 `TNormNpc` 的能力标志 → NPC 可交易。

### 14.9 `MonItems\` 掉落表（`LoadMonItems`，`:174-227`）

按怪物名读 `MonItems\<怪物名>.txt`，产出 `ilist`（掉落列表）。
`MONBAGDIR = 'MonItems\'`（`:14`）。

**实测**：`Envir/MonItems/` 与 `Envir3/MonItems/` 都有，
且 `config.md` §1.1 已记录两版**同名文件内容不同**
（`稻草人0.txt` 329 vs 387 字节、`蛤蟆.txt` 230 vs 424 字节）。

### 14.10 与 Zircon / dbeditor 的对照

| 源码配置 | Zircon 对应 | 说明 |
|---|---|---|
| `MonGen.txt` | `RespawnInfo`（dbeditor workspace） | 字段需逐项对齐 |
| `Merchant.txt` + `Npcs.txt` + `GuardList.txt` | `NPCInfo`（294 行） | 三类 NPC 合一 |
| `MapInfo.txt` | `MapInfo` / `MapRegion` | 地图标志位 |
| `MiniMap.txt` | `minimap-server-crossref.json` | 已在 §13.8/`config.md` §4 闭合 |
| `MonItems\` | `MonsterInfo.DropInfo`（候选） | 未对齐 |
| `MakeItem.txt` | `ItemInfo`（制作配方） | 未对齐 |
| `DecoItem.txt` | 装饰物品 | 未对齐 |
| `Market_Def\` | `NPCPage`（候选） | 未对齐 |

> ⚠️ 上表的 Zircon 列是**待验证的对应关系**，不是已证结论。
> 逐项对齐需要读 Zircon 的 `LibraryCore`/`ServerLibrary` 模型类 ——
> 超出本 Goal（只读 Preview 源码）范围，标注为**后续工作**。

### 14.11 未验证项

| 项 | 原因 |
|---|---|
| `LoadMarketDef` / `LoadQuestDiary` 的完整实现 | 只提取了字段序列，未读全函数 |
| `LoadStdItems` / `LoadMonsters` / `LoadMagic` | 读的是 `.dat` 二进制表（非文本配置），未读 |
| `LoadChatLogFiles` | 未读 |
| `LoadAdminFiles` 的三层 `GetValidStrCap` 嵌套含义 | 只读了字段序列 |
| `Envir3/Mon_Def/*.gen` 的 `.gen` 格式 | 未读解析器 |
| Zircon 侧的逐项字段对齐 | 超出本 Goal 范围 |

### 14.12 两个「不在 `LocalDB.pas`」的配置解析器（**实测修正**）

先前版本的本节曾写「`DragonItem.txt` 与 `Sabuk.txt`/`AttackSabukWall.txt`
的解析器未找到」。**实测已定位**：

| 配置文件 | 解析位置 | 常量 |
|---|---|---|
| `DragonItem.txt` | **`DragonSystem.pas:13`** + `:147` `FInitFileName` | `DRAGONITEMFILE` |
| `Sabuk.txt` | **`Castle.pas:12/15`** + `:171` `LoadFromFile` | `CASTLEFILENAME` |
| `AttackSabukWall.txt` | **`Castle.pas:18`** + `:314` | `CASTLEATTACERS` |

即：**配置解析不集中在 `LocalDB.pas`** —— 子系统各管自己的配置。
`svMain.pas:1167` 的 `gFireDragon.Initialize(EnvirDir + DRAGONITEMFILE, IsSuccess)`
是龙的初始化入口。

#### `DragonItem.txt` 格式（`DragonSystem.DecodeStrInfo`，`:195-`）

**不是「一行一记录」，而是「状态机式命令流」**：

```
!LEVEL <等级>          ← 切换当前等级上下文（CurrentLevel）
!EXP <经验>            ← 设置该等级掉落经验（写入 FLevelInfo[CurrentLevel-1].DropExp）
...（其他 !命令）
```

**关键点**：
1. **`!` 前缀是命令**（`:228` `if infostr = '!'`），非 `!` 行是数据。
2. **状态累积**：`!LEVEL` 改变 `CurrentLevel` 后，后续数据行归属该等级
   —— 这是**上下文相关格式**，不能逐行独立解析。
3. **范围校验**：`CurrentLevel` 必须 `1..DRAGON_MAX_LEVEL`，
   越界返回错误字符串（**带行号**，`:239` `'['+IntToStr(i+1)+'] '`）。
4. **默认值**：`CurrentLevel := 1`、`CurrentExp := 10000`（`:215-216`）。

> 这是本源码里**唯一的「命令式状态机」配置格式** ——
> 其余配置（`MonGen`/`Merchant`/`Npcs` 等）都是「一行一记录 + 空格分隔」。
> 做解析器时必须区别对待。
