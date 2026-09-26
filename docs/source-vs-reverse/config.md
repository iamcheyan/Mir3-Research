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

## 7. 未破译项

`Envir3/QuestDiary/NQ_BASE/MonQuest/` 的 3 个 `.txt`
（`Nm_Chiken.txt`/`Nm_Cow.txt`/`Nm_OmaJunsa.txt`，342–881 B）
**非 GB18030/cp949 文本**，`iconv` 在首字节即失败；字节呈
`… 72 6c 6e 6c 6a 6c … 0e 0c 0a 0c 0e 0c …` 的**定长对模式**
（每对低字节低位恒为 `0xC`），疑 Mir3 MonQuest 私有编码。

**本轮未破译，保持未解状态**（不猜测）。

---

## 8. 待办

| 项 | 说明 |
|---|---|
| `MonGen.txt` 格式（`Envir3` 版） | 未读解析器 |
| `Merchant.txt` / `Npcs.txt` 格式 | 未读解析器 —— 与 `TNormNpc` 能力标志的映射是重点 |
| `MakeItem.txt` / `DragonItem.txt` / `DecoItem.txt` | 未读 |
| `StartPoint.txt` / `SafePoint.txt` | 已看内容（`地图 x y`），未读解析器 |
| `Envir3/QuestDiary/` 脚本语法 | 未读 —— 与 `ObjNpc.pas` 的 `CheckNpcSayCommand` 对照 |
| MonQuest 私有编码 | 未破译 |
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
