# Preview 服务端精读（对象模型 / 世界模型 / 玩法系统）

> 证据源：`reference/mir3-source/Source/GameServer/`（Delphi，79,769 行）。
> 证据等级 `secondary-source`。
> 读源码：`python3 Tools/source-read/read_src.py show Source/GameServer/<文件> --start N --end M`

---

## 1. 文件规模与分组（实测）

| 文件 | 行数 | 职责 |
|---|---:|---|
| **`ObjBase.pas`** | **31,768** | 最大文件：`TCreature`/`TAnimal`/`TUserHuman` 对象基类 |
| `ObjNpc.pas` | 6,409 | NPC 脚本引擎 |
| `UsrEngn.pas` | 3,696 | 连接层（消息前置过滤/透传） |
| `Guild.pas` | 3,600 | 行会 |
| `ObjMon3.pas` | 3,197 | 怪物（第三组） |
| `ObjMon.pas` | 3,097 | 怪物（第一组） |
| `LocalDB.pas` | 2,649 | 本地库 |
| `svMain.pas` | 1,880 | 主窗体/启动 |
| `ObjMon2.pas` | 1,817 | 怪物（第二组） |
| `Magic.pas` | 1,756 | 魔法/技能 |
| `TagSystem.pas` | 1,678 | 标签（邮件/便签）系统 |
| **`Envir.pas`** | **1,540** | **世界环境/地图/刷怪** |
| `SqlEngn.pas` | 1,268 | SQL 引擎 |
| `Castle.pas` | 1,241 | 攻城 |
| `RunSock.pas` | 1,209 | RunGate 套接字 |
| `DBSQL.pas` | 1,050 | DB SQL |
| `FriendSystem.pas` | 988 | 好友 |
| `InterServerMsg.pas` | 927 | 服间消息 |
| `itmunit.pas` | 897 | 物品 |
| `M2Share.pas` | 771 | 共享常量 |
| `UserMgr.pas` | 726 | 用户管理 |
| `CmdMgr.pas` | 629 | GM 命令 |

---

## 2. 对象模型（`ObjBase.pas`）—— 只有三层

```pascal
TCreature = class                      // :305   所有可移动实体基类
TAnimal   = class (TCreature)          // :944   生物（有 AI/移动）
TUserHuman = class (TAnimal)           // :966   玩家
```

**只有 3 层**，比预想的浅。怪物类不在 `ObjBase.pas` 里，而在
`ObjMon.pas`/`ObjMon2.pas`/`ObjMon3.pas` 三个文件（合计 8,111 行）——
按怪物组拆分，不是按继承深度。

### 2.1 `TCreature` 的关键字段（`:305-400`）

**持久化字段**（注释「저장되는 변수」= 会被保存的变量）：

| 字段 | 类型 | 说明 |
|---|---|---|
| `MapName` | `string[16]` | 地图名 |
| `UserName` | `string[14]` | 角色名（**上限 14 字节**） |
| `CX`/`CY` | integer | 坐标 |
| `Dir` | byte | 朝向 |
| `Sex`/`Hair` | byte | 性别/发型 |
| **`HairColorR/G/B`** | byte | ⚠️ 见下 |
| **`Job`** | byte | **`0:전사(战士) 1:술사(法师) 2:도사(道士)`** |
| `Gold` | integer | 金币 |
| `Abil` | `TAbility` | 能力值 |
| `StatusArr` | `array[0..STATUSARR_SIZE-1] of word` | **各状态剩余秒数** |
| `HomeMap/HomeX/HomeY` | | 回城点 |
| `NeckName` | `string[20]` | 称号 |
| `PlayerKillingPoint` | integer | PK 值 |
| `QuestIndexOpenStates` | `array[0..MAXQUESTINDEXBYTE-1] of byte` | **任务开启状态位图** |
| `QuestIndexFinStates` | `array[0..MAXQUESTINDEXBYTE-1] of byte` | **任务完成状态位图** |
| `QuestStates` | `array[0..MAXQUESTBYTE-1] of byte` | 任务状态 |

> 🔍 **`HairColorR/G/B` 是假的颜色字段**。源码注释（`:314-316`）：
> ```
> HairColorR: byte;    //머리색깔이 아님. 각종 Bit Flag로 사용. (sonmg 2005/03/17)
>                      //（不是头发颜色。用作各种 Bit Flag）
> HairColorG: byte;    //Empty
> HairColorB: byte;    //Empty
> ```
> 即 `HairColorR` 被**挪用为位标志**，G/B 是**空占位**。
> **这是做字段映射时最容易踩的坑** —— 按名字理解会完全错。
> 三个职业只有 `Job` 0/1/2（战士/法师/道士），与原版 EI 三职业一致。

**非持久化字段**（注释「저장안되는 변수」= 不保存的变量，`:357-400`）：
`WAbil`（等级/经验）、`AddAbil`、`ViewRange`、`StatusValue`/`StatusTimes`、
`ExtraAbil`/`ExtraAbilFlag`/`ExtraAbilTimes`、`Appearance`、`AccuracyPoint`、
`HitPowerPlus`、`HitDouble`、`AntiPoison`/`PoisonRecover`/`AntiMagic`、`Luck` 等。

**战斗/状态细节**：
- `HitDouble: byte; //10 = +100%  25는 +250%`（`:374`）—— **1 单位 = 10%**
- `RedPoisonLevel: byte; //빨독에 중독되었을때의 강도(0~256)`（`:399`）—— 红毒强度 0–256
- `PoisonLevel: byte; //중독되었을때 독의 강도 (0..3) (0~256)`（`:400`）
- `BodyLuck: Real`（`:344`）—— 怪物幸运值，**用浮点**

### 2.2 `TCreature` 的方法（`:606-698`）

**消息发送族**（5 个变体，`:660-669`）：
```pascal
SendFastMsg / SendMsg / SendDelayMsg / UpdateDelayMsg
UpdateDelayMsgCheckParam1 / UpdateMsg / SendRefMsg
```
—— 区分「快速/普通/延迟/更新/广播」五种发送语义。
`SendRefMsg`（`:669`）是**广播给视野内所有实体**的（对应原版反编译里
「视野内消息分发」）。

**视野/可见性**（`:667-673`）：
```pascal
GetMapCreatures(penv, x, y, area, rlist)
GetObliqueMapCreatures(penv, x, y, area, dir, rlist)   // 斜向
UpdateVisibleGay / UpdateVisibleItems / UpdateVisibleEvents
SearchViewRange
```
—— 原版反编译里的 `SearchViewRange`（视野搜索）在此有完整实现。

**移动族**（`:690-694`）：`Walk` / `Turn` / `RunTo` / `WalkTo` / `EnterAnotherMap`。

**通知族**（`:695-698`）：`Say`（附近说话）/ `SysMsg`（系统消息）/
`BoxMsg`（弹框）/ `NilMsg`。

---

## 3. 世界模型（`Envir.pas`）

### 3.1 `TEnvirnoment`（`:148-227`）—— 单张地图的完整状态

**地图级规则开关**（这是本文件最有价值的部分）：

| 字段 | 语义 |
|---|---|
| `MiniMap: integer` | **小地图索引** ← 正是 `CM_WANTMINIMAP` 回包的内容 |
| `Server: integer` | 所属服务器 |
| `NeedLevel: integer` | 进入等级限制 |
| `Darkness`/`Dawn`/`DayLight` | 光照状态 |
| `BoCanGetItem` | 可否拾取 |
| `LawFull` | 是否守法区（PK 惩罚） |
| `FightZone`/`Fight2Zone`/`Fight3Zone`/`Fight4Zone` | 战斗区（`Fight3Zone` 注释「3번까지 다시 살아난다」= 可复活 3 次） |
| `QuizZone` | 禁止喊话 |
| `NoReconnect`/`NoRecall`/`NoRandomMove`/`NoEscapeMove`/`NoTeleportMove` | 各类禁用 |
| `NoDrug`/`NoThrowItem`/`NoDropItem` | 物品限制 |
| `NoChat`/`NoGroup` | 聊天/组队限制 |
| `MineMap: integer` | 矿区标记 |
| `BackMap: string` | 回退地图 |
| `NeedSetNumber`/`NeedSetValue` | 进入条件（变量匹配） |
| `GuildAgit: integer` | 行会据点 |
| **`MapQuest: TObject`** | **`<> nil` 时进图前先过任务** |
| `MapQuestList: TList` | 地图任务列表 |
| `MapQuestParams: array[0..9] of integer` | **地图局部变量 ×10**（2004/08/27 加） |

> 这解释了 `Mud3-Config/Envir/MapInfo.txt` 里那一长串地图标志位的含义。

### 3.2 `.map` 文件格式（**本轮最有价值的产出**）

结构定义在 `Envir.pas:49-77`：

```pascal
TMIR3MapHeader = packed record        // :50  合计 28 字节
  bhDesc          : array[0..19] of Byte;  // 20
  bhAttribut      : Word;                  //  2
  bhWidth         : Word;                  //  2
  bhHeight        : Word;                  //  2
  bhEventFileIdx  : Byte;                  //  1
  bhFogColor      : Byte;                  //  1
end;

TMIR3MapTileHeader = packed record    // :60  合计 3 字节
  thTileTextureFile : Byte;               // 1
  thTileTextureID   : Word;               // 2
end;

TMIR3MapCellHeader = packed record    // :66  合计 14 字节
  chCellBlock          : Byte;            //  1
  chCellBackAnimation  : Byte;            //  1
  chCellTopAnimation   : Byte;            //  1
  chCellTopFile        : Byte;            //  1
  chCellBackFile       : Byte;            //  1
  chCellBackImg        : Word;            //  2
  chCellTopImg         : Word;            //  2
  chCellDoorIndex      : Byte;            //  1
  chCellDoorOffset     : Word;            //  2
  chCellLight          : Word;            //  2
end;
```

**加载流程**（`LoadMap`，`:393-479`）：

```
1. Read(TMIR3MapHeader, 28)                    → MapWidth/MapHeight
2. FileSeek((MapWidth*MapHeight div 4) * 3, 1)  ← **跳过** tile 区（每格 3 字节，四分之一分辨率）
3. Read(TMIR3MapCellHeader × W × H, 14)         → 单元格数组
4. 逐格解析:
     chCellBlock: 3→MoveAttr=0(不可走)
                  0,252→MoveAttr=1(可走)
                  1,2,254→MoveAttr=2(不可走且不可飞)
     chCellDoorIndex & $80 != 0 → 有门
       nDoor := chCellDoorIndex and $7F         ← **低 7 位是门号，高位是标志**
       同门合并: 坐标差 ≤10 且门号相同 → 共享 pCore
```

**文件大小公式**：`28 + (W*H/4)*3 + W*H*14`

### 3.3 实测验证（**决定性**）

| 文件 | 尺寸 | 实测大小 | 公式预测 | 结果 |
|---|---|---|---|---|
| `0_000.map` | 70×70 | 72,303 B | 28+3675+68600 = 72,303 | ✅ **精确吻合** |
| `D614.map` | 100×100 | 137,528 B | 28+7500+140000 = 147,528 | ❌ 差 10,000 |
| `0.map` | 800×800 | 448,028 B | — | ✅ 完整 |

**差异原因已查明**：`D614.map` 与 `0_002.map` 等 6 个文件的**单元格区被截断**，
实际每格只有 13 字节（少 1 字节）。用本仓库 `Tools/maps/map_roundtrip.py`
的独立解析器验证：

```python
>>> m = MR.indep_parse('Map/0.map')
>>> m.w, m.h, m.n, m.n_records
(800, 800, 640000, 640000)          # 完整
>>> m = MR.indep_parse('Map/0_002.map')
>>> m.w, m.h, m.n, m.n_records
(20, 20, 400, 371)                  # 截断，缺 29 格
```

**结论**：**仓库既有工具链 `map_roundtrip.py` 已正确处理这个截断情形**
（按 `(len(data) - 28 - seg1) // 14` 算实际记录数，而非按 W×H 硬算）。
200 个抽样文件里 194 个是 C=14（完整）、6 个是 C=13（截断）。

→ **源码的 `TMIR3MapCellHeader` 定义（14 字节）是正确的权威结构**，
截断是**数据文件的缺陷**而非格式变体。

---

## 4. 玩法系统文件索引

| 文件 | 行数 | 对应原版窗口/功能 | 对应本仓库工具 |
|---|---:|---|---|
| `Magic.pas` | 1,756 | 技能窗口（F400） | `Tools/magiclab`、`ClientData/magic-effects.json` |
| `itmunit.pas` | 897 | 背包/装备/商店 | dbeditor 的 `ItemInfo` |
| `ObjNpc.pas` | 6,409 | **NPC 对话窗 + 任务脚本引擎** | `NPCPage`、`Tools/questdata`、`Mud3-Config/Envir3/QuestDiary/` |
| `TagSystem.pas` | 1,678 | 便签/邮件 | — |
| `Guild.pas` / `Castle.pas` | 3,600 / 1,241 | 行会/攻城 | — |
| `FriendSystem.pas` | 988 | 好友窗 | Round 802 已追 |
| `DragonSystem.pas` | 604 | 龙系统 | — |
| `Relationship.pas` | 471 | 关系（师徒/恋人） | — |
| `Event.pas` | 323 | 事件 | — |
| `Envir.pas` | 1,540 | 地图/小地图/刷怪 | `Tools/maps/mapviewer.py`、dbeditor `MapRegion` |
| **`Mission.pas`** | **63** | ⚠️ **空壳，见 §4.1** | — |

### 4.1 `Mission.pas` 是**未实现的空壳**（重要发现）

`Mission.pas` 只有 63 行，`TMission` 类的核心方法**全是空的**：

```pascal
function TMission.LoadMissionFile (flname: string): Boolean;
begin
   strlist := TStringList.Create;
   strlist.LoadFromFile (flname);
   // ← 读进来直接丢弃，什么都没解析
   strlist.Free;
   Result := TRUE;          // ← 无条件返回成功
end;

procedure TMission.Run;
begin
   // ← 完全空
end;
```

配套常量 `MISSIONBASE = '.\MissionBase\'`（`:11`）。

**结论**：**任务逻辑不在 `Mission.pas`**。真正的任务实现在
**`ObjNpc.pas`** —— 它有 `CheckQuestCondition(pq: PTQuestRecord)`（`:757`）、
`GotoQuest(num)`（`:1409`），以及记录结构：

```pascal
TQuestRecord = record            // ObjNpc.pas:83-88
   BoRequire: Boolean;           // 是否需要条件（否则走基本对话）
   LocalNumber: integer;
   QuestRequireArr: array[0..MAXREQUIRE-1] of TQuestRequire;
   SayingList: TList;            // list of PTSayingRecord
end;
```

NPC 的 `Sayings: TList`（`:96`）就是 **`PTQuestRecord` 的列表** ——
即**「NPC 对话」与「任务」在数据模型上是同一个东西**：
每条 NPC 对话记录都带可选的前置条件数组。

> **对 `Tools/questdata` 的意义**：任务的权威语义源是 `ObjNpc.pas` 的
> `TQuestRecord` + `CheckQuestCondition`，**不是** `Mission.pas`。
> 阶段 5 做差异对照时应以此为准。

### 4.2 `TNormNpc` / `TMerchant` 的能力标志（原版「NPC 功能」的权威枚举）

`TNormNpc`（`:92-148`）用一组 **Boolean 能力标志**描述 NPC 能做什么
（`:103-122`）—— 这正是 `Mud3-Config/Envir/Merchant.txt` 等配置里
NPC 类型字段的语义来源：

| 标志 | 功能 |
|---|---|
| `CanSell` / `CanBuy` | 卖 / 买 |
| `CanStorage` / `CanGetBack` | 存仓 / 取回 |
| `CanRepair` | 修理 |
| `CanSpecialRepair` / `CanTotalRepair` | 特修 / 全修 |
| `CanMakeDrug` | 制药 |
| `CanUpgrade` | 升级（强化） |
| `CanMakeItem` | 制作物品 |
| `CanItemMarket` | 拍卖行 |
| `CanAgitUsage` / `CanAgitManage` / `CanBuyDecoItem` | 行会据点使用/管理/购买装饰 |
| `CanDoingEtc` | 其他 |

**`TMerchant`**（`:150-`，仅卖东西的商人）额外有：
`MarketName`、`MarketType`、**`PriceRate: integer; //물가, 100:보통, 100보다 크면 비싸다`
（物价，100 = 正常，大于 100 则更贵）**、`NoSeal`、`BoCastleManage`、
`BoHiddenNpc`、`CreateIndex`（`//부하 분산에 이용한다` = 用于负载均衡）。

**关键方法**：`ActivateNpcUtilitys(saystr)`（`:136`）——
注释「상인이 할 수 있는 기능 제어, 판매, 구입, 맡기기 등...」
（控制商人能做什么：出售、购买、寄存等）。这是**从 NPC 脚本字符串
激活功能**的入口，即配置文本 → 运行时能力的转换点。

**NPC 对话方法族**（`:140-143`）：
`NpcSay` / `ChangeNpcSayTag`（替换对话标签）/ `NpcSayTitle` /
`CheckNpcSayCommand`（**解析对话里的命令**，如 `@move` 之类）。

---

## 5. 待办（**2026-09-26 全量精读后更新**）

| 项 | 状态 |
|---|---|
| `ObjBase.pas` 主体（31,768 行） | ✅ **已读方法实现**（§10：视野/移动/消息族/掉落族/GM 命令表）；物品转换族（`:1802-2722`）与 `TUserHuman` 其余仍 pending |
| `ObjNpc.pas` 任务引擎 | ✅ **已读**（§12：五层模型/`CheckQuestCondition`/`CheckSayingCondition`/53+75 opcode/`GotoQuest`/`TakeItemFromUser`）；`NpcSay` 族与 `TMerchant` 实现 pending |
| `TQuestRequire` 结构 | ✅ **已读**（§12.1，`RandomCount`/`CheckIndex`/`CheckValue`，`MAXREQUIRE=10`） |
| `Magic.pas` 技能计算 | ✅ **已读**（`magic.md`：4 块 26 条分派/三伤害公式/符咒/击退）；55 个 `Mag*` 实现主体 pending |
| `ObjMon*.pas`（8,111 行） | ✅ **已读类层次与 AI 核心**（`monsters.md`：71 类/`Think`/`AttackTarget`/`Run`）；各构造与 `ObjMon3` 实现 pending |
| 怪物 AI / 寻路 | ✅ **已定案**：`astar.h` 是**死代码**（无 `#include`），寻路是 `TAnimal.GotoTargetXY` 贪心 8 方向 |
| `CmdMgr.pas` GM 命令表（629 行） | ✅ **已读**（§11：`TCmdMsg`/`ICommand`/`TCmdMgr`）；**GM 命令 131 条已提取**（`gm-commands.tsv`） |
| `svMain.pas` 启动流程与 `EnvirDir` | ⚠️ **部分**（`:619` `EnvirDir` 读取点）；完整启动链 pending |
| 服务端是否读 `Envir3/` | ✅ **已独立复验**：全仓 grep `Envir3` **零命中**（Round 809） |
| `Envir.pas` 剩余方法 | ✅ **已读**（§13：`CanWalk`/`AddToMap`/门/`MapQuest`/`TEnvirList`）；`GetItemEx`/`MoveToMovingObject`/`DeleteFromMap` pending |

---

## 6. 复核方式

```bash
# 对象模型
python3 Tools/source-read/read_src.py show Source/GameServer/ObjBase.pas --start 305 --end 400
grep -an '= class' reference/mir3-source/Source/GameServer/ObjBase.pas

# 世界模型与 .map 格式
python3 Tools/source-read/read_src.py show Source/GameServer/Envir.pas --start 49 --end 100
python3 Tools/source-read/read_src.py show Source/GameServer/Envir.pas --start 393 --end 479

# 实测验证 .map 格式
python3 -c "
import sys; sys.path.insert(0,'Tools/maps')
import map_roundtrip as MR
for p in ('Map/0.map','Map/0_002.map'):
    m = MR.indep_parse(p)
    print(p.split('/')[-1], m.w, m.h, m.n, m.n_records)
"
```

---

## 10. `ObjBase.pas` 方法实现精读（Round 810 / 926 / 927 / 928 / 929 / 930 / 931 / 946 / 947 / 948 / 949 / 950 / 951 / 952 / 953 / 954 / 955 / 956 / 957 / 958 / 959 / 960 / 961 / 962 / 963 / 964 / 965 / 966）

> 31,768 行，前序阶段只读了类声明与字段（§2）。本节读实现段。
> 函数索引：`grep -anE '^(procedure|function|constructor|destructor) ' ObjBase.pas`

### 10.1 实现段结构（1,418 – 31,768 行）

`TCreature` 的方法实现从 `:1422` `Create` 起，覆盖：对象生命周期、物品操作、
消息发送族、视野、状态、移动、掉落。**`TAnimal`/`TUserHuman` 的实现散在其后**。

### 10.2 `SearchViewRange`（`:3567-3890`）—— 视野算法核心

**这是服务端最热的循环**，直接决定「谁看得见谁」。

**入口与边界钳制**（`:3597-3607`）：

```pascal
stx := CX-ViewRange;  enx := CX+ViewRange;
sty := CY-ViewRange;  eny := CY+ViewRange;
if(stx < 0) then stx := 0;
if(enx > PEnvir.MapWidth-1)  then enx := PEnvir.MapWidth-1;
if(sty < 0) then sty := 0;
if(eny > PEnvir.MapHeight-1) then eny := PEnvir.MapHeight-1;
```

**标记-清除模式**（`:3631-3635`）：先把所有 `VisibleItems`/`VisibleEvents`/
`VisibleActors` 的 `Check` 置 0，扫完再清理 `Check` 仍为 0 的（本帧未复见 = 已离开视野）。

**双层循环遍历矩形**（`:3642-3643`）：`for i := stx to enx do for j := sty to eny do`
→ `PEnvir.GetMapXY(i, j, pm)` → 遍历该格的 `pm.ObjList`。

**⚠️ 循环变量名反直觉**：外层是 `i`（对应 **X**），内层是 `j`（对应 **Y**），
但坐标访问是 `GetMapXY(i, j, pm)`。且 `Envir.pas:419` 的 `LoadMap` 用的是
`C := X * MapHeight`（**列优先**）。两处索引约定必须分清。

**三类对象的处理分支**：

| 对象形状 | 常量 | 处理 |
|---|---|---|
| 生物 | `OS_MOVINGOBJECT` | 残影超时删除（**10 分钟**，`:3667` 注释「2003/01/22 时间 5 分改 10 分，防 NPC 闪烁」）→ 可见性过滤 → `UpdateVisibleGay(cret)` |
| 物品 | `OS_ITEMOBJECT` | 超时删除（**1 小时**，`:3715`）→ `UpdateVisibleItems(i, j, pmapitem)` |
| 装饰物品 | `STDMODE_OF_DECOITEM` + `SHAPE_OF_DECOITEM` | **不参与 1 小时清理**（`:3720`，行会据点装饰保留） |

**可见性过滤规则**（`:3687-3703`）—— 最复杂的一段：

```pascal
if (cret <> nil) and
   (not cret.BoGhost) and          // 不是鬼魂
   (not cret.HideMode) and         // 不是隐身
   (not cret.BoSuperviserMode)     // 不是管理员模式
then begin
   if (RaceServer < RC_ANIMAL) or   // 自己不是怪物
      (Master <> nil) or            // 或有主人
      (BoCrazyMode) or              // 或狂暴
      (BoGoodCrazyMode) or          // 或善狂暴
      (WantRefMsg) or               // 或需要消息
      ((cret.Master <> nil) and (abs(cret.CX-CX) <= 3) and (abs(cret.CY-CY) <= 3)) or  // 有主怪物近距离
      (cret.RaceServer = RC_USERHUMAN)  // 或对方是玩家
      and (not hmcheck)
   then UpdateVisibleGay (cret);
```

**语义**：怪物之间**默认不互相可见**（性能优化）—— 只有当「自己不是怪物」
或满足若干例外条件时才建立可见关系。**玩家永远互相可见**
（`cret.RaceServer = RC_USERHUMAN`）。

**⚠️ 运算符优先级陷阱**：`and` 比 `or` 优先级高，所以最后一个 `and (not hmcheck)`
**只作用于 `(cret.RaceServer = RC_USERHUMAN)` 这一项**，不是整个 or 链。
原作者的缩进（`:3701` 的注释行插在 or 链中间）会让读者误以为它作用于全部。
**这是本文件最容易读错的一段。**

**被禁用的视野扩展优化**（`:3612-3629` 整块被 `{ }` 注释）：
原设计「每 10 次搜索做 1 次全屏扩展」+ `RefObjCount` 计数，
**已停用**（2004/04/21 的改动，最终未启用）。

**防御性编程**：`:3653-3661` 用 `try/except` 包住对象形状读取，
**访问违例的对象直接从 `ObjList` 删除**并记日志
`DELOBJ-WRONG MEMORY:<地图>,<X>,<Y>`。这是 2003-09-15 加的（注释 `PDS`）。

**`down` 变量**：全程用 `down := N` 做**阶段标记**，异常处理器打印
`down` 值来定位崩溃点（`:3637` `'ObjBase SearchViewRange 0'`）。
这是一个原始但有效的调试手法 —— 读代码时 `down` 的赋值**不代表逻辑分支**。

### 10.3 `Walk`（`:4105-4215`）—— 移动与过门

**流程**：

```
1. 取当前格 GetMapXY(CX, CY, pm)
2. 遍历该格 ObjList，找:
     OS_GATEOBJECT → pgate（传送门）
     OS_EVENTOBJECT 且 OwnCret <> nil → event（事件，如地雷）
     OS_MAPEVENT / OS_DOOR / OS_ROON → 空分支（{???} 注释，未实现）
3. 若有 event 且 event.OwnCret.IsProperTarget(self)
     → SendMsg(event.OwnCret, RM_MAGSTRUCK_MINE, 0, event.Damage, 0, 0, '')
4. 若有 pgate:
     仅玩家可过（NPC 不出门，:4168 注释「npc 는 문밖으로 안 나감」）
     AroundDoorOpened(CX, CY) 检查门是否开
       特殊地图 NeedHole（如食尸鬼房）需 EventMan.FindEvent(ET_DIGOUTZOMBI) 存在
     同服务器 → EnterAnotherMap(目标环境, EnterX, EnterY)
     跨服务器 → Disappear(1) 成功后设置
        ChangeMapName/ChangeCX/ChangeCY/BoChangeServer/ChangeToServerNumber
        EmergencyClose := TRUE; SoftClosed := TRUE（不使认证过期）
     距上次掉落 >1000ms 才允许（:4180，防跨服刷屏）
5. 无门 → SendRefMsg(msg, Dir, CX, CY, 0, '') 广播移动
```

**`goto needholefinish`**（`:4173`/`:4203`）：Delphi 的 `label`/`goto` 用法 ——
条件不满足时**跳过整个过门逻辑**，落到 `needholefinish` 标签，
再走 `end; //문이 잠김 Result=true 정상`（门锁着时 Result 保持 true = 正常）。

**跨服移动的完整字段集**（`:4184-4194`）—— 这是服务端分线/分服的实现：

| 字段 | 用途 |
|---|---|
| `SpaceMoved := TRUE` | 标记已跨空间 |
| `ChangeMapName` / `ChangeCX` / `ChangeCY` | 目标位置 |
| `BoChangeServer := TRUE` | 换服标志 |
| `ChangeToServerNumber` | 目标服号 |
| `EmergencyClose := TRUE` | 强制断开 |
| `SoftClosed := TRUE` | **但不使认证过期**（可重连） |
| `FAlreadyDisapper := TRUE` | 已消失标志 |

### 10.4 消息发送族（`:3034-3200`）—— 5 个变体的区别

| 方法 | 行 | 语义 |
|---|---|---|
| `SendFastMsg` | `:3034` | 快速发送（不排队） |
| `SendMsg` | `:3064` | 普通发送 |
| `SendDelayMsg` | `:3095` | 延迟发送（`delay` ms） |
| `UpdateDelayMsg` | `:3126` | 更新式延迟（**替换**同 Ident 的待发消息） |
| `UpdateDelayMsgCheckParam1` | `:3151` | 同上，但比对 `Param1` 决定是否替换 |
| `UpdateMsg` | `:3176` | 立即更新式 |
| `SendRefMsg` | `:3363` | **广播给视野内所有实体** |

**`SendRefMsg`**（`:3363`）是视野系统的出口 —— `SearchViewRange` 建立的
`VisibleActors` 列表在这里被用来分发消息。

### 10.5 掉落、尸体与归属（Round 927；`:4416-4896`, `:12679-12933`）

| 方法 | 位置 | 实现 |
|---|---|---|
| `ApplyMeatQuality` | `:4416` | 把尸体 `MeatQuality` 写入 `StdMode=40` 肉类的 `Dura` |
| `TakeCretBagItems(target)` | `:4432` | 屠宰完成后转移目标 `ItemList`；计数物品先尝试叠加 |
| `ScatterBagItems(itemownership)` | `:4509` | 按实体类型、PK 等级、版本和事件标记散落背包 |
| `DropEventItems` | `:4688` | 仅掉落 `TAIWANEVENTITEM`；实际调用在断线/登出且非换服路径 |
| `ScatterGolds(itemownership)` | `:4727` | 每次最多生成 17 堆、每堆至多 2,000 金币 |
| `DropUseItems(itemownership, DieFromMob)` | `:4760` | 玩家死亡时处理装备栏掉落、事件饰品和 `IDC_DIEANDBREAK` |
| `GetDropPosition` / `DropItemDown` / `DropGoldDown` | `:12679` / `:12756` / `:12882` | 选择落点、创建地面对象并写归属/掉落时间 |

#### 10.5.1 屠宰与尸体物品转移

活跃 `ServerGetButch` 为 `:26873-26908`；此前 `:26839-26871` 是被注释掉的旧版。
对前方两格内已死亡、未成骨且 `BoAnimal` 的目标，每次屠宰随机减少
`BodyLeathery` 5–20、`MeatQuality` 100–300（下限 0）。当 `BodyLeathery <= 0`，
特定 `RC_ANIMAL <= RaceServer < RC_MONSTER` 的动物变骨架并调用 `ApplyMeatQuality`；
随后调用 `TakeCretBagItems`，无可取物时提示，尸体韧性重置为 50，并刷新 `DeathTime`。
`ApplyMeatQuality` 只对 `StdMode=40` 写 `Dura := MeatQuality`。

`TakeCretBagItems` 从目标列表首项反复处理：计数物品且 `Dura>0` 时先以
`UserCounterItemAdd` 合并，成功后删除尸体列表项；`Dura=0` 会先改成 1；未合并的物品
走 `AddItem`，失败即停止，成功后从尸体列表移除。它不是一般死亡掉落，而是本轮追到的
屠宰转移路径。

#### 10.5.2 背包与装备掉落

`ScatterBagItems` 先消费并清除一次性 `DontBagItemDrop`。玩家落点搜索宽度为 2，
非玩家为 3；非玩家默认全掉，玩家在 `PKLevel >= 2` 时全掉，否则常规分支按区域
以 `Random(3)=0` 或 Philippines `Random(6)=0` 掷骰。台湾事件用户走单独分支，只尝试
`TAIWANEVENTITEM`。装饰袋不掉，玩家 `UniqueItem & $04` 物品不掉。堆叠物品复制一部分
再落地，只有 `DropItemDown` 成功才扣原堆数量；普通非堆叠物品落地成功后才从列表删除。
非玩家的 `StdMode=43` 矿石先写入 `GetPurity`。玩家侧用 `RM_DELITEMS` 同步被移除项。
圣诞硬编码掉落位于整段注释中，不执行。

`DropUseItems` 的 `DontUseItemDrop` 是独立的一次性退出门。对启用 fame system 的玩家，
高 fame grade 有 50% 全部装备保护；较低 grade 用源码公式
`((_MAX(0, FameGrade-10) div 3)+1)*10`（百分比）判定，触发时还设置
`DontBagItemDrop`，让后续背包掉落也被跳过。韩版/菲律宾版特定巧克力、糖果、幸运勺等
饰品只在被怪物击杀时消失；`IDC_DIEANDBREAK` 装备同样只在 `DieFromMob` 时清除。
其余装备逐槽按 `PKLevel >= 3 ? Random(15) : Random(30)` 掷骰；低于 PK 3 的武器再过
一次 50% 跳过门。玩家 `IDC_NEVERLOSE` 物品排除；地面创建成功才清空装备槽并发送删除表。

`Die` 中掉落总路径受非 `FightZone`、非 `Fight3Zone`、非动物、非 `LawFull` 外门限制。
玩家路径另受 `Fight2Zone`/`NoDropItem` 限制；`Fight4Zone` 且击杀者是玩家时跳过本分支。
怪物击杀且非任务怪时调用 `DropUseItems(nil, TRUE)`；无击杀者调用 `DropUseItems(nil, FALSE)`；
玩家击杀不调用装备掉落，但仍可能走 `ScatterBagItems`。任务怪击杀同时抑制背包掉落。
非玩家尸体的背包/金币掉落还要求无 `Master` 且非 `BoNoItem`，金币另要求
`RaceServer >= RC_ANIMAL`。

#### 10.5.3 事件物品、金币与地面对象

`DropEventItems` 在连接关闭且 `not BoChangeServer` 时调用（`:26272-26289`），发生在
`KillAllSlaves` 之后；反向遍历玩家背包，只对事件物品调用 `DropItemDown`，归属参数为
`nil`、掉落者为自己，成功后删除背包项并发 `RM_DELITEMS`。
`ScatterGolds` 消费一次性 `DontBagGoldDrop`；否则以最多 17 次循环、每堆最多 2,000
扣减金币，落地失败会返还当前堆并停止，最后调用 `GoldChanged`。超过 34,000 的余额
不会由单次循环全部散出。

`GetDropPosition` 按半径从近到远扫描可放置格，遇空格即选；找不到空格时，优先用已有
物品数少于 8 的最少堆叠格，否则回退到中心坐标。`DropItemDown` 对 `StdMode=40` 肉类
先把 `Dura` 减 2,000 并钳到 0；创建 `TMapItem` 时记录 `Ownership`、`Droptime`、
`Droper`，装饰物则把 `Ownership` 改为 `droper`。只有 `AddToMap` 返回新对象自身才算
成功。`DropGoldDown` 也记录归属与时间，固定用宽度 3 找位置；金币扣减由调用者负责。
`ANTI_MUKJA_DELAY = 2*60*1000`；`SearchViewRange` 和 `Guild` 的物品遍历在超过
120,000 ms 后清除 `Ownership`/`Droper`，更早遇到鬼魂实体时也会分别清理引用。
源码注释把 `itemownership` 描述为怪物掉落的可拾取者；本轮确认了字段写入/清理，没有
追到拾取请求端的完整资格判定，故不把这些字段单独等同于完整拾取策略。

### 10.6 物品等级/职业转换（Round 926；`:1802-2722`）

| 方法 | 位置 | 职责 |
|---|---|---|
| `ChangeItemWithLevel(citem, lv)` | `:1802-2017` | 按翼装外形/武器物品索引改写待发 `TClientItem.S` |
| `ChangeItemByJob(citem, lv)` | `:2020-2268` | 普通龙装备、守护石/奖牌、PBKing 衣服的职业字段改写 |
| `BanjjakChangeItemByJob(citem, lv)` | `:2270-2721` | “반짝 이벤트 3차”翼装/武器的职业与等级改写 |
| `ApplyItemParameters(uitem, aabil)` | `:9321-9545` | 先合成升级后物品副本，再把字段并入服务器能力值 |
| `ApplyItemParametersByJob` / `BanjjakApplyItemParametersByJob` | `:9549-10262` | 与客户端改写并行的服务器职业参数路径 |

#### 10.6.1 `ChangeItemWithLevel`：名称索引与等级档

入口先以 `UserEngine.GetStdItemIndex(citem.S.Name)` 得到 `ItemIndex`。翼装分支要求
`Shape = DRESS_SHAPE_WING`（9）且 `StdMode` 为男/女衣服；物品索引 700/701 用独立档，
其他翼装走通用档。两档在 `lv < 30` 均不加下列属性；700/701 的源码门是 `lv >= 20`，
但 20–29 仍只保留基础值。

| 翼装档 | 等级 | DC | MC / SC | AC | MAC |
|---|---:|---|---|---|---|
| 索引 700/701 | 30–39 | `+MakeWord(0,1)` | 各 `+MakeWord(0,2)` | `+MakeWord(2,4)` | `+MakeWord(1,3)` |
| 索引 700/701 | ≥40 | `+MakeWord(0,2)` | 各 `+MakeWord(0,4)` | `+MakeWord(5,7)` | `+MakeWord(2,4)` |
| 其他翼装 | 30–39 | `+MakeWord(0,1)` | 各 `+MakeWord(0,2)` | `+MakeWord(2,3)` | `+MakeWord(0,2)` |
| 其他翼装 | 40–49 | `+MakeWord(0,3)` | 各 `+MakeWord(0,4)` | `+MakeWord(5,5)` | `+MakeWord(1,2)` |
| 其他翼装 | ≥50 | `+MakeWord(0,5)` | 各 `+MakeWord(0,6)` | `+MakeWord(9,7)` | `+MakeWord(2,4)` |

武器分支要求 `StdMode` 5/6，并只处理名称索引 692、693、694、697、698、699；**695/696
没有相应分支**。这些活动分支在 `PKLevel >= 2` 时都向 `MAC` 加 `MakeWord(10,0)`；
等级 30–39、≥40 时分别改写重量与攻击字段。693/698 另在 `<30` 时分别增加
`SpecialPwr` 1/2；源码注释将其标为“反짝”装备。实际 DB 行名与基础值未在本轮解析，
因此不把索引推断成具体 EI 装备名。

#### 10.6.2 `ChangeItemByJob`：龙装备与其他职业专属字段

`Job` 分支注释映射为 0=战士、1=술사、2=道士。识别条件使用物品 `StdMode/Shape`：
龙戒（22/198）、龙手镯（26/199）、龙项链（19/200）、龙衣（10/11 与 10）、
龙头盔（15/201）、龙武器（5/6 与 37）；此外还有 `StdMode=53` 的棒棒糖/奖牌，
以及 `StdMode=10/11, Shape=11` 的 PBKing 衣服。

每个职业分支会清零非本职业的 DC/MC/SC 字段，并对龙武器等改写 DC、AC、MAC；
例如战士龙武器增加 DC 并清零 MC/SC，道士分支增加 DC、清零 MC，并调整 AC 低字节。
龙手镯/龙衣/PBKing 衣服还改写 AC/MAC、准确/敏捷或 HpAdd/MpAdd。**此函数体不读取
形参 `lv`**；等级变化不由 `ChangeItemByJob` 实施。服务器对应的
`ApplyItemParametersByJob` 在 `:9549-9803` 对升级后的 `TStdItem` 副本按同一
`Job` 与 `StdMode/Shape` 分支改写；两处源码注释明确要求数值保持一致，但没有自动
一致性校验。

#### 10.6.3 `BanjjakChangeItemByJob`：活动代码与等级/职业档

函数内两段 `{ ... }` 注释屏蔽旧戒指/手镯/项链/头盔及守护石/奖牌/PBKing 分支；
当前可执行的职业转换仅覆盖龙衣外形（`StdMode` 10/11、`Shape=10`）与龙武器外形
（`StdMode` 5/6、`Shape=37`）。调用方按 `TUserItem.Index` 706/707/708 选择
`Banjjak...` helper，helper 本身再按 `StdMode/Shape` 过滤。

龙衣三个职业都在 `lv < 50` 时清除 `EFFTYPE_HP_MP_ADD`（值 5）的两个效果槽及其
rate/value；职业决定保留 DC、MC、SC 中的一类，另两类清零。`lv < 30` 保持基础攻击；
30–39、40–49、≥50 时，职业主攻字段依次增加：

| Job | 主攻字段 | 30–39 | 40–49 | ≥50 |
|---:|---|---|---|---|
| 0 | DC | `MakeWord(0,1)` | `MakeWord(1,2)` | `MakeWord(1,3)` |
| 1 | MC | `MakeWord(0,2)` | `MakeWord(1,4)` | `MakeWord(1,6)` |
| 2 | SC | `MakeWord(0,2)` | `MakeWord(1,4)` | `MakeWord(1,6)` |

龙衣的 AC/MAC 档对三个职业相同：30–39 加 `MakeWord(2,3)`/`MakeWord(1,3)`；
40–49 加 `MakeWord(5,6)`/`MakeWord(2,4)`；≥50 加 `MakeWord(8,9)`/`MakeWord(2,7)`。

龙武器同样按 `Job` 清零/保留主攻字段，`PKLevel >= 2` 时先给 MAC 加
`MakeWord(10,0)`。战士 DC 档为 `<30: MakeWord(-1,11)`、30–39 `(0,17)`、
40–49 `(1,24)`、≥50 `(2,32)`；술사在 `<30` 不加 DC/MC，之后按 30–39
DC/MC `(1,1)/(1,2)`、40–49 `(2,2)/(1,4)`、≥50 `(3,4)/(2,7)`；道士在 `<30`
DC 为 `(1,-2)`，之后 DC/SC 为 30–39 `(2,2)/(0,2)`、40–49 `(3,6)/(1,3)`、
≥50 `(4,12)/(2,6)`。其中括号均为 `MakeWord(低字节增量, 高字节增量)`，原始
`-1/-2` 运算按源码记录；字节转换后的边界结果未运行验证。
三职业的 AC/MAC 附加调整另有边界：战士/道士始终将 AC 低字节减 2；술사始终将 MAC 高字节减 12（低于等于 12 时置 0），而战士/道士只在 `lv < 50` 时做该 MAC 调整；술사也只在 `lv < 50` 时另将 AC 低字节减 2。

`BanjjakApplyItemParametersByJob`（`:9805-10262`）复制同一活动衣服/武器规则到服务器
能力值计算；其注释同样要求与 `BanjjakChangeItemByJob` 一致。重复实现形成维护约束，
但本轮未构建 Delphi 程序或运行数值夹具。

#### 10.6.4 调用链与服务器/客户端边界

- `RecalcAbilitys` 的装备循环 `:8173-8204` 遍历 `UseItems[0..U_CHARM]`。耐久为 0
  的物品只累计重量并跳过 `ApplyItemParameters`；其他物品先调用
  `ApplyItemParameters` 与 `ApplyItemParametersEx`。前者在 `:9321-9545` 复制
  `TStdItem`、调用 `ItemMan.GetUpgradeStdItem`，按索引 706–708 选 Banjjak helper，
  其余选普通职业 helper，随后按 `StdMode` 将属性累计进 `TAddAbility`。
- `SendUseItems` 与 `ServerQueryUserState` 都在组装客户端 `TClientItem` 副本后，
  仅在衣服槽先调用 `ChangeItemWithLevel`，随后按索引分派职业转换；前者发
  `SM_SENDUSEITEMS`，后者把 `TUserStateInfo` 发为 `SM_SENDUSERSTATE`。
  `SendUpdateItem`/`SendUpdateItemByJob` 分派普通或 Banjjak 职业转换；
  `SendUpdateItemWithLevel` 只调用等级 helper。
- `ServerGetTakeOnItem` 在 `:26550-26573` 先 `RecalcAbilitys`、发送能力更新，
  再按翼装形状/武器索引发送改写物品。`SendUpdateItemByJob(ui, lv)` 的 Banjjak
  分支传 `Abil.Level`，普通分支传 `lv`；普通 `ChangeItemByJob` 不读取该形参。

源码内 `ChangeItemWithLevel` 的直接调用均在客户端物品副本构造/发送路径；上述
`RecalcAbilitys` 循环走 `ApplyItemParameters`，没有调用此等级 helper。因此本轮只确认
等级档会出现在服务器发送的 `TClientItem.S` 中，**不据此断言它也进入服务器数值能力**；
这一区分的游戏内实际效果仍未验证。

### 10.7 与原版 / Zircon 的对照

| 项 | 原版反编译 | Preview 源码 | Zircon |
|---|---|---|---|
| 视野搜索 | `SearchViewRange`（有调用点证据） | `:3567-3890` 完整实现 | `ServerLibrary/Envir/` 有对应 |
| 视野半径 | 未闭合 | `ViewRange` 字段 + 边界钳制 | — |
| 残影超时 | 未闭合 | **10 分钟**（`:3667`） | — |
| 掉落物超时 | 未闭合 | **1 小时**（`:3715`） | — |
| 防抢食归属 | 未闭合 | `Ownership`/`Droper` 写入；`ANTI_MUKJA_DELAY=120,000ms` 扫描清理；拾取资格判定未闭合 | — |
| 跨服移动字段集 | 未闭合 | 7 个字段（`:4184-4194`） | — |
| 怪物互不可见优化 | 未闭合 | `RaceServer < RC_ANIMAL` 门（`:3694`） | — |
| 物品职业/等级转换 | 本轮未找到能证明服务端数值公式的 EI `primary-static` 证据 | `ObjBase.pas:1802-2721` 客户端副本改写；`:9321-10262` 服务器能力副本改写 | `PlayerObject.RefreshStats`（`:2214-2517`）累加 `ItemInfo.Stats`、`UserItem.Stats` 与 socket stats；SetInfoStat 另按 class/level 门控，属于数据驱动模型，未证明与 Preview 公式等价 |
| 怪物/尸体袋掉落 | 未闭合 | `ScatterBagItems` 对现有背包按版本、PK 与实体类型处理；地面对象带归属/掉落者指针 | `MonsterObject.Die → YieldReward → Drop` 按 `DropInfo`、owner/account、`NeedHarvest` 生成当前版战利品；不是同一实现 |
| 玩家死亡掉落 | 未闭合 | `DropUseItems` 掉装备；`ScatterBagItems` 独立处理背包，任务/地图门控不同 | `PlayerObject.Die` 受安全区/Fight 与 `Stats[DeathDrops]` 门控；`DeathDrop` 按可掉标记随机处理背包、宠物背包及一件装备 |
| 地面拾取归属 | 未闭合 | Preview 写 `Ownership`/`Droper` 并由遍历超时清理；拾取判定本轮未追全 | `ItemObject.CanPickUpItem` 按 `Account` 与配置给予本人/队伍/行会/其他人的拾取门限（2/5/10 分钟）；模型与 Preview 指针字段不等价 |
| 死亡主路径与击杀归因 | 未闭合 | `TCreature.Run` 在 HP=0 时检查复活能力后调用 `Die`；`ExpHiter`/`LastHiter` 分别影响经验和击杀归因 | Zircon `PlayerObject.Die` 与 `MonsterObject.Die` 分流；没有直接行为等价证据 |
| 实体周期状态与中毒 | 本轮未核实 EI `primary-static` 定时规则 | `TCreature.Run` `:14394-14940` 覆盖恢复、状态到期、hitter 清理与毒伤；`UsrEngn` `:3012-3175` 调度怪物/NPC/商人 | — |
| 动态消息与延迟魔法 | 本轮未核实 EI `primary-static` 消息语义 | `TCreature.RunMsg` `:14174-14352` 路由魔法伤害、治疗与毒；selected `Magic.pas` callers 先做友方/目标检查；派生 `RunMsg` 改写部分事件 | — |
| 目标资格与魔法通路 | 本轮未找到 EI `primary-static` 对照 | `CheckAttackRule2`、`_IsProperTarget`、动态 `IsProperTarget`；魔法另有 `MagCanHitTarget`，`TGuardUnit` 覆写独立规则 | — |

装备等级/职业转换仍保持 `primary-static` 原版证据缺口、Preview `secondary-source` 的边界。
Zircon 装备属性精读只覆盖 `PlayerObject.RefreshStats`；本轮另选读死亡掉落、地面物品归属
和怪物奖励路径，不据局部实现声称完整跨版本等价。

### 10.8 未验证项

| 项 | 原因 |
|---|---|
| EI 原版对应的等级/职业服务端公式 | 客户端 EXE 静态证据不能代替服务器实现；本轮未找到对应 primary-static 证据 |
| 物品索引 692–701、706–708 的 EI DB 名称/基础属性 | 只读了转换源码，未解析权威 ItemInfo 数据行 |
| `ChangeItemWithLevel` 等级改写是否影响服务器最终数值能力 | helper 直接调用只落在客户端物品副本；无运行期证据，不判断是否为缺失或设计边界 |
| EI 原版掉落规则/掉落保护 | 未找到能证明本轮 Preview 服务端细节的 `primary-static` 证据；Zircon 对照不代替 EI 证据 |
| `ScatterBagItems` 堆叠数为 1 时的 `Random(0)` 边界 | 静态上参数可达；Delphi `Random(0)` 运行语义与实际掉落未执行验证 |
| Preview `Ownership`/`Droper` 的拾取请求资格判定 | 本轮核对了字段写入与扫描清理，未追完拾取命令分支 |
| `RC_ANIMAL`/`RC_USERHUMAN`/`OS_*` 常量值 | 未查定义（疑在 `M2Share.pas`） |
| `TAnimal`/`TUserHuman` 的其余实现段 | Round 831 仅覆盖选定实现；本轮补读屠宰调用路径，不构成完整方法覆盖 |
| 红名死亡且 `LastHiter=nil` 时的 fame 分支 | `ENABLE_FAME_SYSTEM` 下 `LastHiter.IncFamePoint` 无局部 nil 守卫；异常由 `Die 2` 捕获；可达性未运行验证 |
| 派生怪物 `Die` 覆写 | 搜索发现 `ObjMon`/`ObjMon2`/`ObjMon3` 的 `inherited Die` 调用；本轮未逐一读覆写体 |
| EI 原版死亡/红名处罚/复活规则 | 未找到可证明 Preview 对应服务端行为的 `primary-static` 证据 |
| `TCreature.Run` 的派生类有效行为 | 本轮完整读基类与 `TAnimal.Run` 的 inherited 路径；`ObjMon`/`ObjNpc` 等动态覆写未逐类审查，也没有运行验证 |
| `TCreature.RunMsg` 的全部生产者与派生覆写 | 本轮覆盖基类、`TAnimal`、`TMonster`、`TGoldenImugi` 和选定 Magic/ObjBase 调用；其他怪物/NPC 覆写与全量生产者未逐一审查，也无运行验证 |
| EI 原版 PvP/召唤物/守卫目标资格与魔法通路 | 未找到可证明 Preview 这些服务端细节的 `primary-static` 证据；Preview 特殊事件标志、城堡守卫分支和射线边界也未运行验证 |

### 10.9 死亡、经验归属与 PK 合法性（Round 928；`:4898-5486`）

#### 10.9.1 运行入口与死亡状态

`TCreature.Run`（`:14394-14493`）先排空消息队列并调用 `RunMsg`，再处理恢复和死亡：
`NeverDie` 每轮把 HP/MP 置满；存活实体 HP 归零时，若有复活能力且距上次复活超过
60 秒，则损耗复活戒指、恢复满 HP 并发状态消息；仍为 0 才调用 `Die`。已死亡实体
超过 3 分钟调用 `MakeGhost(5)`。`TCreature.Die` 另有两道早退：非红名玩家在安全区把
`Abil.HP`/`WAbil.HP` 设为 1；`NeverDie` 实体直接返回。其余实体才置 `Death`、更新时间、
清除旧 PK hitter 列表；有 `Master` 时清空 `ExpHiter`/`LastHiter`。生日特权设置
`DontBagItemDrop` 与 `DontUseItemDrop`。

死亡体分为三个各自 `try/except` 的阶段：经验/地图任务（`Die 1`）、PK 处罚（`Die 2`）、
掉落/战场记分/日志/`RM_DEATH`（`Die 3`）。单阶段异常被记录后，控制流继续到下一阶段；
该阶段剩余语句则不会继续执行。`Alive`（`:5362-5374`）把 HP 最低补到 1、清 `Death`、
发送复活效果与 `RM_ALIVE`，但 `RecalcAbilitys` 调用留在注释中，只发送光照变更。

#### 10.9.2 经验与地图任务

怪物死亡且有 `LastHiter` 时，首选 `ExpHiter`：玩家直接获得按怪物等级/战斗经验计算的
经验；若首攻者是召唤实体且有 `Master`，召唤物获得 `GainSlaveExp`、主人获得经验。
没有 `ExpHiter` 时，才回退给玩家 `LastHiter`。`BoVentureServer` 下跳过经验入账。
地图任务仅在 `ExpHiter` 分支处理：本人或队长的同组成员必须存活、同一 `PEnvir`，
并与经验归属者在 X/Y 两轴各不超过 12；任务 NPC 对队长/组员分别传 `bogroupcall`。
只剩 `LastHiter` 的回退经验分支没有同样的地图任务调用。

#### 10.9.3 击杀归属与善恶判定

`SetLastHiter`（`:5376-5394`）总是更新最后击中者及时间；若 hitter 有主人，
`LastHiterRace` 记主人种族。`ExpHiter` 仅在原值为 nil 时初始化，同一 hitter 后续命中
只刷新 `ExpHitTime`。受击伤害路径 `StruckDamage`、玩家 `RM_STRUCK`/中毒消息、
`Magic` 的中毒/石化路径和 `TAnimal.RunMsg(RM_STRUCK)` 都能更新这两个归属或 PK 标记。

当前 `AddPkHiter` 不再维护旧的逐人 `PKHiterList`（列表逻辑在注释中）：双方
`PKLevel<2`、不在四类战斗地图且攻击者尚未非法时，给攻击者设置 `BoIllegalAttack`、
`TCreature.Run` 每 5 秒仅对 `RaceServer=RC_USERHUMAN` 的实体调用 `CheckTimeOutPkHiterList`；
60 秒清除并恢复名字颜色。`IsGoodKilling(target)` 的有效实现只返回
`target.BoIllegalAttack`，注释里的 PKHiterList 搜索已停用。因此死亡时的正当防卫判断
依赖被杀目标当前非法攻击标志，而不是历史列表。

`Die` 仅在非冒险服且不处于四种 Fight 区时计算普通 PK 处罚；受害者必须是
`PKLevel<2` 玩家并有击杀者才进入 `boBadKill`。台湾事件用户对普通玩家击杀有例外；
召唤物攻击会改用其人类主人。行会战关系或城战范围会把该次死亡视为战斗击杀；
否则 `IsGoodKilling(self)` 决定合法防卫。非法击杀可扣双方 fame、给击杀者加 100 PK
点、通知恋人并降低幸运；另有武器解锁/诅咒随机分支。击杀红名玩家另走 fame 转移分支。

**静态边界**：红名受害者进入 `PKLevel>=2` fame 分支时，代码直接调用
`LastHiter.IncFamePoint(100)`，该行无 nil 检查；若 `LastHiter=nil` 且
`ENABLE_FAME_SYSTEM` 为真，异常会被 `Die 2` 捕获并中止该 PK 阶段余下处理。源码可证
该空指针路径的守卫缺失，但本轮没有运行验证其可达性。`CmdOneKillMob` 另可对前方
`RaceServer>=RC_ANIMAL` 目标直接调用动态 `Die`；多个怪物类也覆写 `Die` 并调用 inherited，
这些覆写体不在本轮范围。

### 10.10 实体周期状态与调度（Round 929；`ObjBase.pas:14394-14940`、`UsrEngn.pas:3012-3175`）

`TCreature.Run` 声明为 `dynamic`（`:683`），以下是基类路径，不代表每个派生实体最终执行完全相同的 tick。已读 `TAnimal.Run` 只调用 `inherited Run`（`:17243-17246`）。入口先排空消息队列并逐条调用 `RunMsg`；恢复、引用清理、计时器、状态到期和毒伤分处独立 `try/except`，分别记 `Run 0` 至 `Run 6`。某阶段异常会跳过该阶段剩余语句，但外层后续阶段仍可执行。

#### 10.10.1 恢复与引用清理

存活实体按 `ticksec` 的 `GetTickCount` 差累计 `HealthTick`/`SpellTick`：普通装备按 20ms 单位（注释 50 次/秒），指定活动服装按 13ms 单位（注释 75 次/秒）。达到门限后，HP 每次恢复 `MaxHP div 75 + 1` 再按 `HealthRecover` 加成，MP 恢复 `MaxMP div 18 + 1` 再按 `SpellRecover` 加成；另有 `IncHealth`/`IncSpell`/`IncHealing` 的分段恢复队列。若 `HealthTick < -HEALTHFILLTICK` 且 HP 大于 1，则每轮扣 1 HP。死亡实体不走自然恢复。

目标与击杀归属有不同失效期限：`TargetCret` 在焦点超过 30 秒、目标死亡/消失或任一坐标轴相差超过 15 格时清空；`LastHiter` 对非玩家 30 秒、玩家 60 秒过期，且死亡/消失时清空；`ExpHiter` 超过 6 秒、死亡、`BoGoodCrazyMode` 或消失时清空。毒伤分支内原本清 `LastHiter` 的语句已注释，因此该分支本身不重置击杀归属。

`Master` 死亡/消失后，召唤体在 1 秒后把 HP 置 0；主人是正在换服的人类时等待 15 秒。每 10 秒检查主人忠诚期限，过期时从主人 `SlaveList` 移除、清空 `Master`、HP 降为十分之一并改名；非零 `SlaveLifeTime` 超过 12 小时则置 HP=0 并设 `BoDisapear`。同一周期也清理死亡/消失的从属对象；30 秒周期清理失效队长、组员和交易对象并调用 `VerifyMapTime`。

#### 10.10.2 状态、毒伤与周期计时

`StatusArr` 只对 `0 < value < 60000` 的状态按每秒递减；到期时按状态清除防御/魔防提升、隐身或魔法泡泡等标志，必要时调用 `RecalcAbilitys` 并发送 `RM_ABILITY`。`ExtraAbil` 到期会清值和标志、触发重算；防御类状态及多数额外能力有 10 秒到期提示。

每 2.5 秒处理中毒：动物的 `MeatQuality` 另减 1000；其余按 `1 + PoisonLevel` 调 `DamageHealth`，随后清零 HP/MP 恢复累积并发状态更新。仅当实体为人类、`LastHiter=nil` 且 `LastHiterRace=RC_USERHUMAN` 时传 `minimum=1`（源码注释为避免该路径毒死角色）；其他情况传 0。

| 周期门限 | 基类动作 |
|---|---|
| 1 秒 | 人类 `UseLamp`；状态数组另按秒扣减 |
| 5 秒 | 仅人类调用 `CheckTimeOutPkHiterList`；非法攻击标记满 60 秒后清除 |
| 10 秒 | 检查主人忠诚期限与 12 小时召唤寿命 |
| 30 秒 | 清理组队/交易引用并验证当前地图时间 |
| 2 分钟 | `PlayerKillingPoint>0` 时调用 `DecPkPoint(1)` |
| 1 小时 | 人类发送计时账号检查（测试服外、指定 `AvailableMode` 且 `FExpireCount=0`），并显示已在线小时数；旧注释中的 4 小时倍数已禁用 |

#### 10.10.3 调度器边界

`UsrEngn.ProcessMonsters`、`ProcessMerchants`、`ProcessNpcs` 以 `GetCurrentTime - RunTime > RunNextTick` 门控，更新 `RunTime` 后按 `SearchRate` 调 `SearchViewRange`，再通过动态 `cret.Run` 分派。怪物列表另受 `MonLimitTime` 时间片限制，以 `MonCur`/`MonSubCur` 续跑；处理器异常会从出生点列表删除该对象（对应 `Free` 仍为注释），幽灵怪物 5 分钟后删除并释放。商人/NPC 使用 `NpcLimitTime` 和各自游标；它们的异常由整个处理器的外层捕获。`TAnimal.Run` 显式先调用基类，但其他怪物/NPC 覆写未逐一核实，不能把基类 tick 直接等同所有派生体行为。

### 10.11 动态消息分派与延迟战斗处理（Round 930；`ObjBase.pas:14174-14352`）

`TCreature.RunMsg` 是 `dynamic`（声明 `:681`），由 `TCreature.Run` 的队列循环调用。该循环的 `try/except` 包在整个 `while GetMsg` 外，而非逐消息捕获：一个 handler 异常会终止本次剩余队列处理，记录 `Run 0`；`Run` 后续独立阶段仍可继续。

#### 10.11.1 延迟魔法与伤害

`RM_DELAYMAGIC` 从 `wParam` 取魔法强度，从 `lParam1` 拆出中心坐标、`lParam2` 取范围、`lParam3` 取目标指针。龙/龙身目标在施法者与目标的 X/Y 各差不超过 8 时，先收到 1–3 点 `RM_DRAGON_EXP`；随后先计算目标魔抗伤害是否大于 0，再对 `RaceServer>=RC_ANIMAL` 将强度乘 1.2，最后要求目标与存储中心的两个轴差均不超过范围才投递 `RM_MAGSTRUCK`。所读 Magic 1/5 路径在排队前已有 `MagCanHitTarget`、`IsProperTarget`、抗魔随机和命中坐标门控，延迟为 600ms。

`RM_MAGSTRUCK` 与 `RM_MAGSTRUCK_MINE` 共用处理：从发送者取 `PlusFinalDamage`；普通 `RM_MAGSTRUCK` 对非 RushMode、等级低于上限门且 `RaceServer>=RC_ANIMAL` 的受击者增加 800–1799ms `WalkTime`。伤害再由 `GetMagStruckDamage(nil, lParam1)` 计算；为正时选中发送者、调用 `StruckDamage`、更新血魔和发送 `RM_STRUCK_MAG`。非人类另降低动物肉质并收到带击中者指针的 `RM_STRUCK`；该分支不给人类投递这条额外消息。

#### 10.11.2 治疗与中毒消息

`RM_MAGHEALING` 把 `lParam1` 累加到 `IncHealing`，上限 300，并设 `PerHealing=5`；实际 HP 由 `TCreature.Run` 的分段恢复队列处理。所读恢复术检查 `IsProperFriend` 且目标未满 HP 后才排队，延迟 800ms；范围治疗扫描 1 格内对象并逐个做友方检查。

`RM_MAKEPOISON` 从 `lParam2` 取 hitter；非空时先用 `IsProperTarget` 门控选中目标及一条等级小于 60 的归属更新，但之后的人类互击/召唤主人归属分支与最终 `MakePoison` 位于该门控之外；空 hitter 也直接调用 `MakePoison`。所读 Magic 暗烟术在发送前已有 `IsProperTarget`、毒袋耐久、成功率与抗毒门控，并对玩家互击/召唤主人另记 PK/hitter；`StruckDamage` 的物品中毒路径也位于 `IsProperTarget(targ)` 分支内。因此此处只记录基类消息处理的门控边界，不据此断言可由未授权调用触发。

#### 10.11.3 派生分派与其他消息

`TAnimal.RunMsg` 对 `RM_STRUCK` 只在 `msg.Sender=self` 且 `lParam3<>0` 时记录 hitter、调用 `Struck`、打断 Holy Seize；若有主人且击中者为非主人的人类，则给主人 `AddPkHiter`。该 case 不调用 inherited，其他消息才进入基类。`TMonster.RunMsg` 直接 inherited；`TGoldenImugi.RunMsg` 收到中毒消息时先清 `DontAttack` 再 inherited。基类还路由 `RM_REFMESSAGE`、透明/随机移动、开放生命、引用计数、龙经验和诅咒等消息；其他类覆写尚未逐一核对。

### 10.12 目标资格、PK规则与魔法路径（Round 931；`ObjBase.pas:13814-13839/14943-15149`、`ObjMon2.pas:917-1077`）

#### 10.12.1 `IsProperTarget`：玩家攻击模式与分支优先级

`_IsProperTarget`（`:14985-15118`）先拒绝 nil/self。玩家攻击模式按种族、组队和行会关系筛目标：`HAM_ALL` 排除 NPC/和平 NPC；`HAM_PEACE` 仅接受 `RaceServer>=RC_ANIMAL`；`HAM_GROUP` 排除 NPC 与组员；`HAM_GUILD` 排除 NPC、同会及城战区盟会；`HAM_PKATTACK` 排除 NPC，并按玩家 PK 级别只允许红白名相互攻击。`BoNonPKServer` 另对 `HAM_ALL/GROUP/GUILD/PKATTACK` 的人类目标调用非 PK 规则：默认禁止非战斗区目标，城堡被攻且攻击者处于 Free-PK/城战范围或行会关系满足条件时才允许；`HAM_PEACE` 不走这层规则。非人类且 `RaceServer<RC_ANIMAL` 的攻击者在该分支直接获准。

怪物/召唤物规则另行判断。带 `Master` 的召唤物会按主人 `LastHiter`、`ExpHiter`、`TargetCret` 及目标当前指向关系选择候选；普通门控还检查同主人、Holy Seize、主人 `BoSlaveRelax`、目标 `BoGoodCrazyMode`、人类安全区和地图名。随后 `BoCrazyMode` 可把此前结果重新设为允许；`BoGoodCrazyMode` 再禁止人类与召唤目标、允许其他目标。无主动物可攻击人类、攻击型 NPC 与召唤物。最终基类检查拒绝 `BoSysopMode`、`BoStoneMode`、`HideMode` 目标。

人类对人类目标在基类合法后才调用 `CheckAttackRule2`（`:14943-14982`）：任一方在安全区则拒绝；非 Free-PK 目标下，等级大于 10 的红名不能攻击 10 级及以下白名，反向也拒绝；任一方 `MapMoveTime<3s` 亦拒绝。旧 ApprovalMode 检查已注释。`IsProperTarget` 随后对带 `BoTaiwanEventUser` 的非 nil 目标无条件设 `Result=true`，可覆盖 `_IsProperTarget` 的 self/隐藏/保护拒绝及双方 PK 检查；设置条件、可达性和事件意图未运行核实，不据静态分支断言漏洞。人类攻击召唤物时另以 `_IsProperTarget(target.Master)` 检查主人并补安全区门控，不复用主人对人类目标的完整 `IsProperTarget`/`CheckAttackRule2` 路径。

#### 10.12.2 `MagCanHitTarget`：有限步路径门控

`:13814-13839` 对非 nil 目标记录初始 Manhattan 距离，最多尝试 13 步：逐步取 `GetNextDirection`/`GetNextPosition`，遇到不能前进或 `CanFireFly` 为 false 即退出；到达目标坐标或当前 Manhattan 距离大于初始值时返回 true，否则最终为 false。`olddis` 在循环中不更新，因此比较始终针对初始距离；这不是单独的 `IsProperTarget` 替代门。所读 Magic 三个 `MagCanHitTarget` 调用路径还各自做 `IsProperTarget` 检查。该路径没有运行测试，拐路/超 13 步情形的实战表现未验证。

#### 10.12.3 `TGuardUnit` 的独立覆盖

`TGuardUnit.IsProperTarget`（`ObjMon2.pas:926-991`）不调用 inherited，直接覆盖基类规则。有关联 `Castle` 时，允许 LastHiter；`BoCrimeforCastle` 的代码窗为 2 分钟（源码注释写 5 分钟），过期清标记；目标本身有关联城堡时清其标记并拒绝。城堡被攻时放开候选，之后仍拒绝 NPC/和平 NPC、自身、同城堡目标，并按主人行会/盟会关系过滤。`TGuardUnit.Struck` 在有城堡时给 hitter 设 `BoCrimeforCastle` 及时间。

无 `Castle` 时，候选仅由“曾被该守卫击中”“正在攻击弓箭守卫”或 `PKLevel>=2` 放行，随后仍拒绝 Sysop、Stone 与自身；此分支没有基类的安全区、`HideMode` 或玩家攻击模式门控。`TArcherGuard.Create` 将 `Castle` 置 nil；`Run` 遍历 `VisibleActors`，按距离选择通过覆写谓词的目标并调用 `ShotArrow`。覆盖体无 nil 守卫，但所读调用点先解引用候选并检查死亡状态；nil 是否可进入该列表未验证。未运行守卫/城战场景，不能把静态规则推为实战可达行为。

### 10.13 构造/销毁、可视列表与套装属性（Round 946；`ObjBase.pas:1422-1800/3241-3566/7982-9299`）

#### 10.13.1 `TCreature.Create`（`:1422-1695`）—— 实体字段总初始化

一次性初始化 **约 200 个字段**。关键默认值：
- `RaceServer := RC_ANIMAL`（默认是动物，人类/怪物由工厂覆盖）、`ViewRange := 5`、
  `HomeMap := '0'`、`Dir := DR_DOWN`、`HoldPlace := TRUE`；
- `Abil` 初值：`Level=1`、`AC/MAC=0`、`DC=MakeWord(1,4)`、`MC=SC=MakeWord(1,2)`、
  `HP=MP=MaxHP=MaxMP=15`、`MaxExp=50`、`MaxWeight=100`；
- 命中/闪避 `AccuracyPoint := DEFHIT`、`SpeedPoint := DEFSPEED`；`LifeAttrib := LA_CREATURE`；
- 时间片：`RunNextTick=250`、`SearchRate=2000+Random(2000)`、`NextWalkTime=1400`、
  `NextHitTime=3000`；`RunTime := GetCurrentTime + Random(1500)`；
- **创建 15 个容器**：`MsgList`/`MsgTargetList`/`PKHiterList`/`VisibleActors`/`VisibleItems`/
  `VisibleEvents`/`ItemList`/`DealList`/`MagicList`/`SaveItems`/`GroupMembers`/
  `WhisperBlockList`/`SlaveList` 等；
- **`UseItems` 为 13 槽**（`FillChar(UseItems, sizeof(TUserItem)*13)`，注释 `9->13` 记录扩容）；
- `MeltArea := 2`；`QuestStates`/`QuestIndexOpenStates`/`QuestIndexFinStates` 清零。

#### 10.13.2 `TCreature.Destroy`（`:1697-1763`）—— 按消息类型释放附加内存

遍历 `MsgList` 逐条释放：`RM_DELITEMS` 的 `lparam1`（`TStringList`）、
`RM_MAKE_SLAVE` 的 `lparam1`（`PTSlaveInfo`）、`descptr`，再 `Dispose` 消息本身；
随后释放 `PKHiterList` 的 `PTPkHiterInfo`、`VisibleActors` 的 `PTVisibleActor`、
`VisibleItems`、`ItemList`/`DealList`/`MagicList`/`SaveItems` 的指针、以及各 `TStringList`/`TList`。
**整段包在 `try..except` 里**，异常只打 `[Exception] TCreature.Destroy <name>`。

#### 10.13.3 小工具（`:1765-1800`）

- `SetBoInFreePKArea`：值变化时置 `AreaStateOrNameChanged`（触发区域状态重发）。
- `GetNextHitTime`/`GetNextWalkTime`：`StatusArr[POISON_SLOW] > 0` 时**额外 +50%**
  （`NextHitTime + NextHitTime div 2`）—— 即减速状态直接放大出手/走路的间隔。
- `IsMoveAble`：`not BoGhost and not Death` 且 `POISON_STONE/ICE/STUN/DONTMOVE` 全为 0。

#### 10.13.4 区域取物与可视列表（`:3241-3566`）

- `GetMapCreatures(penv, x, y, area, rlist)`：按 `(x±area, y±area)` 方框遍历 `ObjList`，
  收集 `Shape=OS_MOVINGOBJECT` 且非 `BoGhost` 的实体。
- `GetObliqueMapCreatures(..., dir, ...)`：只对**对角方向** 1/3/5/7 生效，
  用 `abs((x-i)∓(y-j)) <= area` 做菱形裁剪；其它方向直接返回。
- `UpdateVisibleGay`：可见列表里已有则 `check:=1`（更新），否则 `check:=2`（新增）并
  **`Inc(cret.RefObjCount)`**（玩家除外、死亡除外）。
- `UpdateVisibleItems`/`UpdateVisibleEvents`：同构的 `check` 标记机制。

#### 10.13.5 `RecalcAbilitys`（`:7982-9299`）—— **套装系统核心**

先重置 `AddAbil`、把 `WAbil := Abil`（保留 HP/MP）、清零 `Weight/WearWeight/HandWeight`、
`AntiPoison/PoisonRecover/HealthRecover/SpellRecover/Luck/HitSpeed := 0`、**`AntiMagic := 1`**
（注释「기본 10% => 2%」），清一批 `BoAbil*` 与 `ManaToHealthPoint`/`SuckupEnemyHealth*`。

然后**遍历 13 个装备槽**（`for i:=0 to U_CHARM`）：
- `UseItems[i].Dura = 0` 时**只算重量不算属性**（`continue`）；
- `ApplyItemParameters(UseItems[i], AddAbil)` + `ApplyItemParametersEx(UseItems[i], WAbil)`；
- 按 `pstd.Shape` 累积**几十种套装标志**（每件装备只标记自己属于哪套）；
- 武器/左右手戒指：`SpecialPwr` 负值映射到 `AddAbil.UndeadPower`
  （`-1..-50` 加 `-pstd.SpecialPwr`，`-51..-100` 加 `pstd.SpecialPwr+50`）。

最后**按套装组合给加成**（本文件最密集的一段），主要套装：

| 套装 | 组成 | 加成 |
|---|---|---|
| 천지합일 | 천(戒指)+지(项链)+합(手镯)+일(头盔) 4 件 | `BoCGHIEnable := TRUE` |
| 적난（마력→체력） | 项链+手镯+戒指 | `ManaToHealthPoint + 50` |
| 밀화（吸血） | 项链+手镯+戒指 | `AddAbil.HIT + 2` |
| 세륜/녹취/도부 | 手镯+戒指 | HP+50 / MP+50 / HP+30&MP+30 |
| 오현 | 项链+手镯+戒指 | `HP += MaxHP*30%`、`AC += 2/2` |
| 초혼 | 武器+项链+戒指+头盔+手镯 5 件 | `HitSpeed+4`、`DC+2/5`、置 `BoOldVersionUser_Italy` |
| 파쇄/환마석/영령옥 | 项链+手镯+戒指 | 各给 DC/AC/MAC/UndeadPower/SC 加成 |
| 뼈다귀/벌레/백금/연옥/홍옥 + 강화版 | 3–5 件 | 各给 AC/DC/MC/SC/MAC/抗性/负重加成 |
| 용 세트 | 10 件（戒指×2/手镯×2/项链/衣/头盔/武器/靴/腰带） | 全套加成 |
| 반짝이 이벤트 | 武器 692–694、697–699；衣服 700/701 | 特殊标记 |
| 수정갑옷 | `DRESS_SHAPE_CRYSTAL` 衣服 | `crystal_dress` |

- 特殊戒指用 `Shape` 判定并置能力标志：透明（`STATE_TRANSPARENT=60000`+`BoHumHideMode`）、
  瞬移、石化、复活、火球、治疗、愤怒能量、魔法盾、超强力量。
- 项链/手镯/戒指的 `ManaToHealth`/`SuckHealth` 用 `pstd.AniCount` 累积。
- 复魂石（`StdMode=53`+`SHAPE_OF_LUCKYLADLE`）使 `AddAbil.Luck + 1`。

> ⚠️ **做数值/工具时的硬约束**：套装判定依赖 **`StdItem.Shape` 常量**（`PSET_RING_SHAPE`
> 等，定义在别处）；同一 `Shape` 在不同装备位上含义不同；**`RecalcAbilitys` 每换装/状态变化都会全量重算**，
> 不做增量。`RaceServer=RC_USERHUMAN` 才走套装分支（怪物不享受套装）。

**未验证**：所有 `*_SHAPE` 常量值与其对应的 EI `StdItem` 数据行未解析；
`AntiMagic := 1` 的百分比语义（注释自相矛盾）未核实；套装加成顺序/叠加关系未运行验证。

### 10.14 伤害计算与近战攻击链（Round 947；`ObjBase.pas:6442-6760/10694-11164`）

#### 10.14.1 伤害减免与扣血（`:6442-6760`）

- **`GetHitStruckDamage`（`:6442`）/`GetMagStruckDamage`（`:6462`）**：
  `armor := Lobyte(AC|MAC) + Random(Hibyte(AC|MAC) - Lobyte(...) + 1)`（**区间随机减伤**，旧版用
  `ShortInt` 已被 `Integer` 版替换，注释保留）；`damage := _MAX(0, damage - armor)`；
  若受击者 `LifeAttrib=LA_UNDEAD` 且 hitter 非 nil → `damage += hiter.AddAbil.UndeadPower`；
  若 `BoAbilMagBubbleDefence` → `damage := Round(damage/100 * (MagBubbleDefenceLevel+2) * 8)` + `DamageBubbleDefence`。
- **`DamageHealth(damage, minimum)`（`:6713`）**：`BoMagicShield` 时**先用 MP 抵**（`spdam := Round(damage*1.5)`，
  MP 不足则扣完转回 HP）；`damage>0` 且 HP-damage>0 直接扣，否则 `Result := HP-minimum`、
  `HP := _MAX(minimum,0)`（**保底 minimum，防一次打死**）；`damage<0` 为治疗，钳到 `MaxHP`。
- **`DamageSpell(val)`（`:6751`）**：`val>0` 扣 MP、`val<0` 回 MP，均钳制。

#### 10.14.2 `StruckDamage`（`:6481-6709`）—— 受击总入口

1. **闪避**：`MissProbability > Random(100)` 直接 `exit`。
2. `SetLastHiter(hiter)`（记录最后一击）。
3. **装备耐久**：`wdam := Random(10)+5`；`POISON_DAMAGEARMOR` 时 `wdam`/`damage` 按
   `(10+RedPoisonLevel)/10` 放大；`POISON_STUN` 时 `damage × 1.2`。
   衣服**每次都掉耐久**；其余 `1..11` 槽在 `Random(8)=0` 时掉，**左臂的 `StdMode=25`（符/毒粉）不掉**、
   `U_BUJUK` 不掉。耐久归零时 `SysMsg` + `RM_DURACHANGE` + `bocalc:=TRUE` →
   重算 `RecalcAbilitys` 并发 `RM_ABILITY`/`RM_SUBABILITY`。
4. **分身（`RC_CLONE`）**：主人 `MP` 按 `damage div 5` 扣除（不足则清零）。
5. 非人类且 `POISON_DONTMOVE > 1` → 降为 1（被打解石化）。
6. `realdam := DamageHealth(damage, 0)`；`FeedbackProbability > Random(100)` 时
   `AroundAttack(realdam * FeedbackRatio div 100)`（**反伤**，只打 3×3 内非人类）。
   整段包 `try..except` 打 `'EXCEPTION CLON HP CACULATE'`。

#### 10.14.3 `_Attack`（`:10694-11164`）—— 近战/剑法总入口

内部函数：
- `DirectAttack`：安全区（双方人类且任一在安全区）直接放弃；`IsProperTarget` +
  `Random(target.SpeedPoint) < AccuracyPoint` 命中判定；`target.StruckDamage` + `RM_STRUCK`（500 ms），
  **非人类目标额外直发 `RM_STRUCK`**（注释「몬스터한테는 직접전달해야 함」）。
- `DirectStoneAttack`：`damage>0` 且 `target.Level < self.Level+4` 且 `< 60` → `POISON_DONTMOVE`（麻痹）。
- `StoneAttack`：5×5 内对非人类逐个 `DirectStoneAttack`。
- `SwordLongAttack`（어검）：正前 **2 格**；`SwordWideAttack`（반월）：`(Dir+{7,1,2}) mod 8` 3 方向 1 格；
  `SwordCrossAttack`（광풍참）：`(Dir+{7,1,2,3,4,5,6}) mod 8` **7 方向**，对人类目标伤害 ×0.8。

主流程：
- 基础伤害 `GetAttackPower(Lobyte(DC), Hibyte(DC)-Lobyte(DC))`；`MultiplyTargetLevelMin/Max>0` 时
  按目标等级缩放。
- `HM_POWERHIT`+`BoAllowPowerHit` → `dam += HitPowerPlus`；`HM_FIREHIT`+`BoAllowFireHit` →
  `dam += Round(dam/100 * (HitDouble*10))`。
- **命中附加减速/中毒**（`IsProperTarget` 且 `target.Level<60`）：`AddAbil.Slowdown`/`Poison` 概率门
  + `Random(50) > targ.AntiMagic`；等级差 `Gap` 钳 ±10；人类 `MoC=2`；满足则
  `MakePoison(POISON_SLOW, Dur+1, 1)`（`Dur=(900*Slowdown+3300) div 1000`）或
  延迟 `RM_MAKEPOISON`（`POISON_DECHEALTH`，5 s）。
- **剑法第二段**：`HM_LONGHIT`/`HM_WIDEHIT`/`HM_CROSSHIT` 的 `seconddam` 按对应技能
  `Round(dam / (MaxTrainLevel+2|+10|+11) * (Level+2|+2|+3))`，非人类 `seconddam := dam`；
  分别调 `SwordLongAttack`/`SwordWideAttack`/`SwordCrossAttack`。
- `HM_TWINHIT`（쌍룡참）：`dam += HitPowerPlus` + `DirectAttack`；`Random(50) > AntiMagic` 且
  概率 `5*(Level+1)`（怪）/`2*(Level+1)`（人）→ `POISON_STUN`（`Dur = 1.5 + 0.8*Level`）；
  `BoAllowTwinHit` 从 1 变 2（**只能用一次**）。
- `HM_STONEHIT`（사자후）：按 `PStoneHitSkill.Level` 0/1/2/3 → `seconddam := 5/6/7/8` 秒，
  `StoneAttack(seconddam)`，命中则 `dam := 0`。
- 最终 `dam := targ.GetHitStruckDamage(self, dam)`；`PlusFinalDamage` 叠加；
  `weapondamage := Random(5)+2 - AddAbil.WeaponStrong`（**强度高的武器耐久掉得少**）。
- 命中后：`SuckupEnemyHealthRate>0`（밀화）累积 `dam/100*rate`，≥2 时转 `DamageHealth(-n,0)` 回血；
  **8 种剑法各自训练**（`TrainSkill` + `CheckMagicLevelup`，未升级发 `RM_MAGIC_LVEXP`）：
  剑术/예도검법/어검술/반월검법/염화결/광풍참/쌍룡참/사자후；
  `DoDamageWeapon(weapondamage)` 扣武器耐久。
- 整体 `try..except` 打 `'[Exception] TCreature._Attack:<test>'`。

**未验证**：`GetAttackPower`/`DoDamageWeapon`/`TrainSkill`/`CheckMagicLevelup`/`MakePoison` 实现未逐一读；
`Random(target.SpeedPoint)` 与 `AccuracyPoint` 的实战命中率、`MissProbability`/`FeedbackProbability` 设置点未核实；
无运行期验证。

### 10.15 拾取与使用物品（Round 948；`ObjBase.pas:13267-13698`）

#### 10.15.1 `PickUp`（`:13267-13469`）

- 交换中（`BoDealing`）不能捡；取脚下 `PEnvir.GetItem(CX,CY)`。
- **归属门**：`GetTickCount - pmi.droptime > ANTI_MUKJA_DELAY`（120 s）→ `ownership := nil`；
  `canpickup`（owner 为 nil 或自己）或 `cangrouppickup`（owner 在 `GroupOwner.GroupMembers` 里）才可捡，
  否则 `SysMsg('일정시간 동안 줍지 못합니다.')`。
- **金币**（`NAME_OF_GOLD`）：`DeleteFromMap` 成功 → `IncGold(pmi.Count)` → `RM_ITEMHIDE`；
  **≥500 才写用户日志码 `4`（줍기/拾取）**；`GoldChanged`；`Dispose(pmi)`。
- **计数物品**（`StdMode.OverlapItem >= 1`）：先 `UserCounterItemAdd(StdMode, Looks, Dura, Name, FALSE)` 合并，
  成功即 `Dispose` 返回；失败则放回地图。
- **普通物品**：`IsEnoughBag` 才继续。
  - **庄园装饰袋**（`StdMode=STDMODE_OF_DECOITEM & Shape=SHAPE_OF_DECOITEM`）：
    无主时**只有行会会长**能捡、有主时只有主能捡 → `GuildAgitMan.DeleteAgitDecoMon` + 保存。
  - `DeleteFromMap` → `new(pu); pu^ := pmi.UserItem`；按 `OverlapItem` 算重量；
    `AddItem(pu)`；**地图任务检查**：`PEnvir.HasMapQuest` 时用掉落者名 `GetMapQuest` 找 NPC 并 `UserCall`；
    非廉价物品写日志码 `4`；`SendAddItem` 同步客户端；
    **台湾事件物品**（`StdMode=TAIWANEVENTITEM`）→ 置 `BoTaiwanEventUser`、`STATE_BLUECHAR=60000`、
    重算状态/光照并广播 `RM_CHANGELIGHT`、`UserNameChanged`。

#### 10.15.2 `EatItem`（`:13471-13698`）—— 按 `StdMode`/`Shape` 分派

`PEnvir.NoDrug` 地图直接拒绝。分派：

| `StdMode` | 类型 | 行为 |
|---|---|---|
| 0 | 시약（药剂） | `FASTFILL_ITEM`（선화수）→ `IncHealthSpell(AC, MAC)` + `MaxHP/MaxMP * DC/MC %`；`FREE_UNKNOWN_ITEM` → `BoNextTimeFreeCurseItem`；否则 `IncHealth += AC`、`IncSpell += MAC`（各封顶 1000） |
| 1 | 고기（肉） | 直接 `Result := TRUE` |
| 2 | 식당 음식 | `SHAPE_BUNCH_OF_FLOWERS` → `RM_LOOPNORMALEFFECT`（花束特效） |
| 3 | 스크롤（卷轴） | `INSTANTABILUP_DRUG`（属性药）→ `EnhanceExtraAbility` 提升 DCUP/MCUP/SCUP/HITSPEEDUP/HPUP/MPUP（支持百分比 `HIBYTE(MC)`），再 `RecalcAbilitys`；`INSTANT_EXP_DRUG`（经验药）→ `WinExp`（按 `AC/MAC` 组合公式 ×100）；`SHAPE_COUPLE_ALIVE_STONE`（연인부활석）→ 需**高级情侣戒指 + 交往 ≥365 天 + 与恋人相邻 1 格 + 恋人已死** → 恋人以 10% HP 复活、自己 HP/MP 各 ÷10；否则 `UseScroll(Shape)` |
| 8 | 사용 아이템 | `SHAPE_OF_INVITATION`（초대장）→ 有效期检查后 `CmdGuildAgitFreeMove(pu.Dura)`（按庄园号传送）；`SHAPE_OF_TELEPORTTAG`（왕방마패）→ `UserSpaceMove(Reference, HpAdd, MpAdd)`；`SHAPE_OF_GIFTBOX` → `GetGiftFromBox`；`SHAPE_OF_OLDBOX` → `GetGiftFromOldBox` |

**未验证**：`IncHealthSpell`/`EnhanceExtraAbility`/`WinExp`/`UseScroll`/`GetGiftFromBox`/
`GetGiftFromOldBox`/`UserSpaceMove` 实现未逐一读；`FASTFILL_ITEM` 等 `Shape` 常量值未查；
无运行期验证。

### 10.16 卷轴、武器强化/修理与抽奖（Round 949；`ObjBase.pas:5826-6381`）

#### 10.16.1 `UseScroll(Shape)`（`:5826-5998`）—— 卷轴按 `Shape` 分派

| `Shape` | 道具 | 行为 |
|---:|---|---|
| 1 | 순간이동주문서 | 回 0 号图（`UserSpaceMove(HomeMap)`）；`NoEscapeMove/NoTeleportMove` 地图禁用；台湾事件用户禁用 |
| 2 | 아공도약서 | 当前图随机跳（`UserSpaceMove(MapName)`）；`NoRandomMove/NoTeleportMove` 禁用；**城堡核心图被攻时 10 s 冷却**（`LatestSpaceScrollTime`） |
| 3 | 귀환주문서 | 回 `HomeX/Y`；**`PKLevel>=2` 改送 `BADMANHOMEMAP/BADMANSTARTX/Y`**（红名专用回城点） |
| 4 | 축복의기름 | `MakeWeaponGoodLock`（加幸运/减诅咒） |
| 5 | 사북귀환주문서 | 行会占领沙巴克时传送城堡起点；否则无效 |
| 6 | 귀환전서 | 回行会庄园（`CmdGuildAgitFreeMove`）；无庄园则退化为「回城」 |
| 9 | 수리기름 | `RepaireWeaponNormaly`（一般修理） |
| 10 | 무신의기름 | `RepaireWeaponPerfect`（完全修理） |
| 11 | 복권 | `UseLotto`（抽奖） |

#### 10.16.2 `MakeWeaponGoodLock`（`:6000-6102`）—— 武器幸运/诅咒

- `difficulty := abs(HIBYTE(pstd.DC) - LOBYTE(pstd.DC)) div 5`（**武器随机幅度越大越难加幸运**）。
- `Random(20)=1` → `MakeWeaponUnlock`（**中诅咒**，`Delta := -1`）。
- 否则按诅咒/幸运分层：有诅咒（`Desc[4]>0`）先 **-1 诅咒**；否则加幸运 `Desc[3]`：
  `<1` 必成、`<3` 需 `Random(6+difficulty)=1`、`<7` 需 `Random(30+difficulty*5)=1`。
- 成功后 `RecalcAbilitys` + `SendUpdateItem` + `RM_ABILITY`/`RM_SUBABILITY`；写日志码 `29`（축기/祝福）。
  ⚠️ 源码注释 `// if Delta <> 0 then` 已被注释掉 → **即使无效也写日志**（2005/04/13 改动）。

#### 10.16.3 修理（`:6104-6259`）

- **`RepaireWeaponNormaly`（`:6104`）**：`UniqueItem and $02` → 不可修；
  `repair := _MIN(5000, _MAX(0, DuraMax - Dura))`；`DuraMax -= repair div 30`（**修理会永久降低上限**）；
  `Dura += repair` 钳到 `DuraMax`；写日志码 `36` 类型 3。
- **`RepaireWeaponPerfect`（`:6167`）**：`Dura := DuraMax`（**不降上限**）；日志码 `36` 类型 4。
- **`RepairItemNormaly(psSeed, puSeed)`（`:6217`）**：对任意装备同「一般修理」公式（`DuraMax -= repair div 30`）。

#### 10.16.4 `UseLotto`（`:6262-6381`）—— 抽奖

`Random(30000)` 分档：`0..4999`→500（6 等）、`14000..15999`→1000（5 等）、
`16000..16149`→10000（4 等）、`16150..16169`→100000（3 等）、`16170..16179`→200000（2 等）、
`18000`→1000000（1 等）。**每档都有 `LottoSuccess < LottoFail` 门**（**保底/概率补偿**：
`LottoFail` 每次未中奖 +500）。中奖 `IncGold`，背包满则 `DropGoldDown` 落地。

#### 10.16.5 `MakeHolySeize`（`:6384-6390`）

置 `BoHolySeize` + `HolySeizeStart/Time`，并 `ChangeNameColor`。

**未验证**：`MakeWeaponUnlock`/`UserSpaceMove`/`GuildAgitMan`/`UserCastle`/`IncGold` 实现未逐一读；
`LottoSuccess/LottoFail` 初值与持久化未追；无运行期验证。

### 10.17 `TUserHuman.Operate`（Round 950；`ObjBase.pas:24626-26325`）—— 玩家主循环

`Operate` 是玩家每轮调度函数（由 `UsrEngn` 调用），结构 = **周期检查 → 消息分派 → 登出处理 → `inherited Run`**。

#### 10.17.1 周期检查（`:24646-24902`）

- `BoDealing` 时若对面不是 `DealCret`（或自身/nil）→ `BrokeDeal`（**修「面壁交易复制金钱」漏洞**）。
- `CheckExpiredTime`；`BoAccountExpired` → 提示 + `EmergencyClose`（消息只发一次）。
- `BoAllowFireHit` 超 20 s 自动清并 `+UFIR`；`BoAllowTwinHit=2` → 0 并 `+UTWN`。
- `BoTimeRecall(Group)` 到点 `SpaceMove` 回 `TimeRecallMap/X/Y`。
- 每 20 s：台湾事件用户 `CryCry` 广播自己坐标。
- 每 3 s：`CheckHomePos`；**重叠推挤**（`GetDupCount>=3` 持续 3 s 或 `=2` 持续 10 s → `CharPushed(Random(8),1)`）；城堡战期间 `BoInFreePKArea := UserCastle.IsCastleWarArea`。
- 每 1 s：夜间优惠边界写连接日志 + 每 2 h 写一次 `WriteConLog`；行会战安全区变化 → `ChangeNameColor`；
  **城堡核心占领判定**：在 `CorePEnvir` 内、行会为进攻方且 `CheckCastleWarWinCondition` 成立 →
  `UserCastle.ChangeCastleOwner` + `UserEngine.SendInterMsg(ISM_CHANGECASTLEOWNER, ...)`，
  进攻方只剩 1 个时 `FinishCastleWar`；`AreaStateOrNameChanged` → `SendAreaState`+`UserNameChanged`；
  向同图组员/召唤物发 `RM_GROUPPOS` + `RM_HEALTHSPELLCHANGED`。
- 每 500 ms：台湾事件物品在背包中消失则清 `BoTaiwanEventUser`/`STATE_BLUECHAR`。

#### 10.17.2 `CM_*`（客户端→服务端）分派（`:24907-25262`）

- **移动/攻击回执**：`CM_TURN/WALK/RUN` → `TurnXY/WalkXY/RunXY`，回 `'+GOOD/'+GetTickCount` 或 `'+FAIL/'`；
  攻击族 `CM_HIT/HEAVYHIT/BIGHIT/POWERHIT/LONGHIT/WIDEHIT/CROSSHIT/TWINHIT/FIREHIT` → `HitXY`，
  回 `'+GOOD/'+GetTickCount+'/'+HitSpeed`（**把攻速回给客户端做反外挂核对**）。
- `CM_SPELL` → `SpellXY`；`CM_SITDOWN` → `SitdownXY`；`CM_SAY` → `Say`。
- 物品：`CM_DROPITEM`/`CM_DROPCOUNTITEM` → `UserDropItem/UserDropCountItem` + `SM_DROPITEM_SUCCESS/FAIL`；
  `CM_PICKUP`（**需 `CX=lParam2 and CY=lParam3`**）→ `PickUp`；`CM_EAT`/`CM_BUTCH`/`CM_TAKEONITEM`/`CM_TAKEOFFITEM`；
  `CM_UPGRADEITEM` → `CmdUpgradeItem`（try/except 打 `UPGRADE ERROR`）。
- NPC/商店：`CM_CLICKNPC`/`CM_MERCHANTDLGSELECT`/`CM_MERCHANTQUERYSELLPRICE`/`...REPAIRCOST`/
  `CM_USERSELLITEM`/`CM_USERREPAIRITEM`/`CM_USERSTORAGEITEM`/`CM_USERGETDETAILITEM`/`CM_USERBUYITEM`/
  `CM_USERTAKEBACKSTORAGEITEM`/`CM_USERMAKEDRUGITEM`/`CM_USERMAKEITEMSEL`/`CM_USERMAKEITEM`。
- 组队/交易/行会/师徒/市场/庄园：`CM_CREATEGROUP*`/`CM_ADDGROUPMEMBER*`/`CM_DELGROUPMEMBER`/
  `CM_DEAL*`/`CM_OPENGUILDDLG`/`CM_GUILD*`/`CM_LM_*`/`CM_MARKET_*`/`CM_GUILDAGIT*`/`CM_GABOARD_*`/`CM_DECOITEM_BUY`。
- 杂项：`CM_CANCLOSE`（`ExistAttackSlaves` 时 `RM_CANCLOSE_FAIL`，否则 OK）；
  `CM_SOFTCLOSE`（回选人）；`CM_GROUPMODE`；`CM_WANTMINIMAP`；`CM_QUERYUSERSTATE`；`CM_ADJUST_BONUS`；
  `CM_SPEEDHACKUSER`（记日志）；`CM_FRIEND_ADD` → **`UserMgrEngine.ExternSendMsg(stInterServer, ...)` 跨服转发**；
  `CM_TEST`/`CM_EXCHGTAKEONITEM`（空）。

#### 10.17.3 `RM_*`（服务端内部→客户端）分派（`:25266-26264`）

把内部消息编码成对应 `SM_*` 发出。关键：
- **`RM_LOGON`**：按地图 `Darkness/Dawn/Bright/DayLight` 算亮度 `n`，发 `SM_NEWMAP`（`MakeWord(LOBYTE(n), LOBYTE(PEnvir.AutoAttack))`）+ `SendLogon` + `GetQueryUserName` + `SendAreaState` + `SM_MAPDESCRIPTION` + **`SM_CHECK_CLIENTVALID`（3 个客户端校验和）**。
- **`RM_CHANGEMAP`**：`NoGroup` 地图自动解散队伍；发 `SM_CHANGEMAP`。
- 移动族 `RM_TURN/PUSH/RUSH/RUSHKUNG/WALK/RUN/FOXSTATE` → 对应 `SM_*`，带 `GetRelFeature`/`CharStatus`/`GetThisCharColor`。
- 攻击族 `RM_HIT/.../PULLMON/SUCKBLOOD` → `SM_*`（仅非 self）。
- 施法 `RM_SPELL`/`RM_MAGICFIRE`/`RM_MAGICFIRE_FAIL`。
- **`RM_STRUCK`/`RM_STRUCK_MAG`**：自己被打时 `AddPkHiter`+`SetLastHiter`（**正当防卫记录**）；`PKLevel>=2` 记 `HumStruckTime`（红名不能重连）；打自己行会城堡成员 → `BoCrimeforCastle`；`HealthTick/SpellTick := 0`、`Dec(PerHealth/PerSpell)`。
- 死亡/复活/变身 `RM_DEATH`（`lparam3=1` 用 `SM_NOWDEATH`）/`RM_SKELETON`/`RM_ALIVE`/`RM_CHANGEFACE`。
- 传送族 `RM_SPACEMOVE_SHOW(_NO/2)/HIDE(_2)`；`RM_DIGUP`（`lTag1` 事件被强制置 0）/`RM_DIGDOWN`；`RM_SHOWEVENT`/`RM_HIDEEVENT`。
- 特效/战斗视觉 `RM_FLYAXE`/`RM_LIGHTING(_1/_2/_3)`/`RM_DRAGON_FIRE1-3`/`RM_NORMALEFFECT`/`RM_LOOPNORMALEFFECT`。
- 显血 `RM_OPENHEALTH/CLOSEHEALTH/INSTANCEHEALGUAGE`；`RM_BREAKWEAPON`；`RM_GROUPPOS`。
- 名字/颜色 `RM_CHANGENAMECOLOR`/`RM_USERNAME`。
- 经验/等级 `RM_WINEXP`/`RM_CHANGEFAMEPOINT`/`RM_LEVELUP`（连发 `SM_ABILITY`+`SM_SUBABILITY`）/`RM_POWERUP`。
- **聊天族** `RM_HEAR/CRY/WHISPER/GMWHISPER/LM_WHISPER/SYSMESSAGE(2/3)/SYSMSG_BLUE/PINK/GREEN/REMARK/GROUPMESSAGE/GUILDMESSAGE/MERCHANTSAY`：每种映射到**固定颜色对**（如 `RM_HEAR→MakeWord(0,255)`、`RM_CRY→MakeWord(0,151)`、`RM_GMWHISPER→MakeWord(249,255)`）。
- 商店/市场/物品/行会/庄园/门/使用品/魔法/重量/金币/特性/状态/清屏/魔法经验/声音/耐久/光照/灯油/计数/组取消/改名/建会/捐献/菜单/一次性密码/任务/掷骰/猜拳 → 对应 `SM_*`。
- **`RM_WEIGHTCHANGED` 校验和**：`(((W+Wear+Hand) xor $3A5F) xor $1F35) xor $aa21`（与客户端 `SM_WEIGHTCHANGED` 的校验互为逆）。
- 未匹配 → `inherited RunMsg(msg)`。

#### 10.17.4 登出 / 换服（`:26272-26311`）

`EmergencyClose/UserRequestClose/UserSocketClosed` 时：非换服则 `KillAllSlaves` + 通知恋人（本服 `RM_LM_LOGOUT`，跨服 `ISM_LM_LOGOUT`）+ `DropEventItems`；`MakeGhost(6)`；
换服则用 `ChangeMapName/ChangeCX/CY`；`UserRequestClose` 发 `SM_OUTOFCONNECTION`；非 `SoftClosed` 时
`FrmIDSoc.SendUserClose(UserId, Certification)` 通知 ID 服。整体 `try..except` 打
`[Exception] Operate 2 #<name> Identback/Ident/Sender/wP/lP1-3`。

**未验证**：`TurnXY/WalkXY/RunXY/HitXY/SpellXY/SitdownXY`（移动/攻击合法性核心）未逐一读；
`UserCastle.*`/`UserMgrEngine.ExternSendMsg`/`FrmIDSoc` 实现未追；颜色对数值的业务含义未核实；
无运行期验证。

### 10.18 外观、出现/消失、行走与换图（Round 951；`ObjBase.pas:3891-4414`）

#### 10.18.1 外观与状态（`:3891-4045`）

- **`GetRelFeature(who)`（`:3896-3980`）**：人类 → `MakeFeature(0, Dress, Weapon, Face)`，
  其中 `dress := pstd.Shape*2 + Sex`（男女衣服分开）、`weapon := pstd.Shape`、`face := Hair`；
  **分身（`RC_CLONE`）→ `MasterFeature`**（显示主人外观）；其余 → `MakeFeatureAp(RaceImage, DeathState, Appearance)`。
  旧的意大利旧版本映射逻辑整段被注释。
- **`GetCharStatus`（`:3982`）**：遍历 `StatusArr`，`>0` 的位设 `$80000000 shr i`，再或上
  `CharStatusEx and $0000FFFF`。
- `Initialize`（`:4000`）：`InitValues`（`WAbil := Abil`）→ 魔法等级钳到 0..3 → `Appear`（记录 `ErrorOnInit`）
  → `GetCharStatus` → `AddBodyLuck(0)`。`Finalize` 空。
- `FeatureChanged`/`CharStatusChanged`：分别广播 `RM_FEATURECHANGED`/`RM_CHARSTATUSCHANGED`。
- `Appear`（`:4047`）：`PEnvir.AddToMap` 成功即返回真，非 `HideMode` 时广播 `RM_TURN`。
- `Disappear(num)`（`:4061`）：`FAlreadyDisapper` 时直接返回（**防跨服重复消失**）；
  `DeleteFromMap` 失败打日志，成功广播 `RM_DISAPPEAR`。
- `KickException`（`:4086`）：人类回 `HomeMap/HomeX/HomeY` + `EmergencyClose`；
  非人类 `Death := TRUE` + `MakeGhost(3)`。

#### 10.18.2 `Walk(msg)`（`:4105-4215`）—— 行走与过门/换服

1. 扫描当前格的 `ObjList`：找 `OS_GATEOBJECT`（门）与 `OS_EVENTOBJECT`（事件）。
2. 事件 `OwnCret.IsProperTarget(self)` → `SendMsg(event.OwnCret, RM_MAGSTRUCK_MINE, ...)`
   （**踩到别人放的地雷/事件受伤**）。
3. 有门时**只有人类**能通过（NPC 不许出门）；`AroundDoorOpened` 为真才过；
   **`NeedHole` 地图必须有 `ET_DIGOUTZOMBI` 事件**（`EventMan.FindEvent`），否则 `goto needholefinish`（不换图）。
4. **同服** → `EnterAnotherMap(EnterEnvir, EnterX, EnterY)`；
   **跨服** → `Disappear(1)` + 设 `ChangeMapName/CX/CY`、`BoChangeServer`、`ChangeToServerNumber`、
   `EmergencyClose`、`SoftClosed`（**不使认证失效**）、`FAlreadyDisapper`（**由 `Operate` 的登出分支完成实际换服**）。
   跨服前有 1 s `LatestDropTime` 冷却。
5. 无门 → `SendRefMsg(msg, Dir, CX, CY, ...)` 正常广播移动。整段 `try..except` 打 `down` 断点。

#### 10.18.3 `EnterAnotherMap`（`:4217-4342`）—— 地图切换总入口

- 门槛：`Abil.Level >= enterenvir.NeedLevel`；`MapQuest` 非 nil 时 `TMerchant.UserCall(self)`；
  `NeedSetNumber >= 0` 时 `GetQuestMark(NeedSetNumber) = NeedSetValue`；
  `CorePEnvir`（沙巴克内城）→ `UserCastle.CanEnteranceCoreCastle`。
- `Disappear(2)` → 清 `MsgTargetList`/`VisibleItems`/`VisibleEvents`/`VisibleActors`（每步独立 try/except）
  → `RM_CLEAROBJECTS`。
- 切 `PEnvir/MapName/CX/CY` → `RM_CHANGEMAP`（带 `GetGuildAgitRealMapName`）→ `Appear` 成功则
  `MapMoveTime := now`、`SpaceMoved := TRUE`；失败则**还原**旧环境并重新 `AddToMap`。
- `Fight3Zone` 进出变化 → `UserNameChanged`（**行会战区域名字变色**）。

#### 10.18.4 说话与幽灵（`:4344-4414`）

- `Turn(dir)` 广播 `RM_TURN`；`Say` 广播 `RM_HEAR`（`UserName + ': ' + str`）。
- `SysMsg(str, mode)`：**非人类直接返回**（不给怪物发系统消息）；`mode` 映射
  `1→RM_SYSMESSAGE2`、`2→RM_SYSMSG_BLUE`、`3→RM_SYSMESSAGE3`、`4→RM_SYSMSG_REMARK`、
  `5→RM_SYSMSG_PINK`、`6→RM_SYSMSG_GREEN`、否则 `RM_SYSMESSAGE`。
- `BoxMsg`→`RM_MENU_OK`（仅人类）；`GroupMsg`→组员 `RM_GROUPMESSAGE`（前缀 `-`）；
  `NilMsg`→`RM_HEAR`（sender=nil）。
- `MakeGhost(num)`：`BoGhost := TRUE` + `GhostTime` + `Disappear(3)`，失败打 `Not MakeGhost` 日志。

**未验证**：`AroundDoorOpened`/`CanEnteranceCoreCastle`/`EventMan.FindEvent`/`MakeFeature(Ap)` 实现未逐一读；
跨服换服的实际握手（`ChangeToServerNumber` 消费点）未追；无运行期验证。

### 10.19 近战封装、击退、毒、召唤、组队与移动（Round 952；`ObjBase.pas:11167-12365`）

#### 10.19.1 `HitHit` / `HitMotion` / `HitHit2`（`:11167-11356`）

- `HitHit(target, hitmode, dir)`：`HM_WIDEHIT`/`HM_CROSSHIT`/`HM_TWINHIT` 先扣 MP
  （`DamageSpell(GetSWSpell(skill) + skill.pDef.DefSpell)`，`MP=0` 则**降级为 `RM_HIT`**）；
  `Dir := dir`；`target=nil` 时 `GetFrontCret`；持武器时 `CheckWeaponUpgradeResult`；
  `_Attack` 成功则 `SelectTarget`；按 `hitmode` 把 `msg` 映射到 `RM_HIT/HEAVYHIT/BIGHIT/POWERHIT/LONGHIT/WIDEHIT/FIREHIT/CROSSHIT/TWINHIT`；`HitMotion` 广播。
- **`CheckWeaponUpgradeResult`/`IdentifyWeapon`（`:11168-11225`）**：`Desc[10]`（**鉴定标记**）
  `10..13/20..23/30..33` 分别给 `Desc[0]/[1]/[2]` 加成；`=1` → **武器破碎**（`Index:=0`）；
  `Desc[0]+[1]+[2] < 20` 才鉴定，否则直接 `Index:=0`。成功写日志码 `20`（업성/升级成功）、
  失败写 `21`（업실/升级失败）并 `RM_BREAKWEAPON`。
- `HitHit2` = `HitHitEx2(target, RM_HIT, hitpwr, magpwr, all)`（`:11327`）：
  `HitHitEx2` 对目标格 `GetAllCreature` 内每个 `IsProperTarget` 目标算
  `GetHitStruckDamage(hitpwr) + GetMagStruckDamage(magpwr)`，`StruckDamage` + `RM_STRUCK`（200 ms），
  再 `SendRefMsg(rmmsg, ...)`（**范围物理+魔法混合伤害**，怪物 AI 常用）。

#### 10.19.2 击退与冲刺（`:11359-11634`）

- **`CharPushed(ndir, pushcount)`（`:11359`）**：朝 `ndir` 逐格 `GetFrontPosition` + `CanWalk(不重叠)`
  + `MoveToMovingObject`；每成功一格 `RM_PUSH(GetBack(ndir), ...)`；动物（`RaceServer>=RC_ANIMAL`）
  `WalkTime += 800`（**被推后出手变慢**）；返回实际推动格数。
- **`CharRushRush(ndir, rushlevel, isHumanSkill)`（`:11392`）—— 무태보/推人**：
  `CanPush(cret)` = 等级更高 + 非 `StickMode` + `Random(20) < 6+rushlevel*3+levelgap` + `IsProperTarget`；
  `rushlevel>=3` 时还会推前方第 2 格的目标；命中目标 `CharPushed(Dir,1)` + `Inc(PushedCount)`
  （**`TPushedMon` 的计数来源**）；`RM_RUSH`；撞墙 → `RM_RUSHKUNG` + `SysMsg('밀어낼 힘이 달립니다.')`；
  `isHumanSkill` 时按 `(1+damagelevel)*4 + Random((1+damagelevel)*5)` 对被推者和自己造成伤害。
- **`CharDrawingRush`（`:11514`）**：与 `CharRushRush` 同构，但**有目标的推人循环整段被 `{ }` 注释掉**
  （只剩无目标的前进分支）—— 注释标「포승검 수정」（**当前实际是空实现的有目标分支**）。

#### 10.19.3 毒、周围实体与召唤（`:11636-11943`）

- `SiegeCount`：1 格内存活实体数；`SiegeLockCount`：8 邻格中**不可走**的格数（**被围程度**，
  `TCowKingMonster` 用它触发脱围）。
- **`MakePoison(poison, sec, poisonlv)`（`:11667`）**：`sec -= PoisonRecover`，`<=0` 直接返回；
  `StatusArr[poison]` 取较大值；`POISON_DAMAGEARMOR` 设 `RedPoisonLevel`、否则 `PoisonLevel`；
  `PlusPoisonFactor<>0` 时**乘 `(PlusPoisonFactor div 100)`**；`CharStatusChanged`；人类提示「중독되었습니다」。
- `ClearPoison`；`GetFrontCret`/`GetBackCret`（前方/后方格实体）；`CretInNearXY`（3×3 内找指定实体）。
- **`MakeSlave(sname, slevel, max_slave, royaltysec)`（`:11769`）**：天使/护卫额外 +1 名额；
  `SlaveList.Count < max_slave+AddPlus` 时 `AddCreatureSysop` + 设 `Master/MasterRoyaltyTime/
  SlaveMakeLevel/SlaveExpLevel/MasterFeature` + `RecalcAbilitys` + HP 补到中间值 + `ChangeNameColor` + 入列。
- `ClearAllSlaves`（`BoDisapear`+`MakeGhost(4)`）/`KillAllSlaves`（HP:=0）/`ExistAttackSlaves`
  （**有正在攻击人类的召唤物则不能登出**）/`GetExistSlave`（按名找存活召唤物）。
- **`EnableRecallMob(TargetMob, SkillLevel)`（`:11879`）—— 驯服**：`NoMaster`/`LA_CREATURE`/
  非分身/非天使/`Level < MAXKINGLEVEL-1`；护卫/弓箭护卫不可驯；目标 `Level>=50` 时**每有一只 ≥50 的
  召唤物，成功率按 `Random(3*count)` 递减**；환영한호（鬼虎）唯一；上限 `2 + SkillLevel + AddPlus`。

#### 10.19.4 组队（`:11949-12071`）

`IsGroupMember`/`CheckGroupValid`（成员 ≤1 时解散 + `RecalcAbilitys`）/
`DelGroupMember`（队长退出则全队解散 + `RM_GROUPCANCEL`）/`EnterGroup`/`LeaveGroup`/`DenyGroup`。
`EnterGroup`/`LeaveGroup` 都调 `RecalcAbilitys`（**情人节情侣组队加成**）。

#### 10.19.5 攻击范围判定（`:12078-12170`）

- **`TargetInAttackRange`**：目标在 **1 格八邻域**（不含自身格）→ 按相对位置定 `DR_*` 方向。
- **`TargetInSpitRange`**：2 格内；相邻（|dx|,|dy|≤1）走 `TargetInAttackRange`，否则映射到
  `SpitMap[targdir, ny, nx]` 的 5×5 模板（**喷吐型攻击的形状表**）。
- **`TargetInCrossRange`**：同上，用 `CrossMap`（**十字/广域攻击形状表**）。

#### 10.19.6 `WalkTo` / `RunTo`（`:12173-12359`）

- **`WalkTo(dir, allowdup)`**：`BoHolySeize` 时**不能移动**；按 `dir` 算下一格；边界检查；
  `BoFearFire` 时要求 `CanSafeWalk`（**怕火怪避火**）；有主人时**不挡主人正前方**；
  `MoveToMovingObject` 成功后 `Walk(RM_WALK)`；`Walk` 失败则回退到原格并重新 `AddToMap`；
  移动时若 `BoFixedHideMode` → **破隐身**（`STATE_TRANSPARENT := 1`）。
- **`RunTo(dir, allowdup)`**：一次移动 **2 格**，要求两格都可走；`Walk(RM_RUN)`；失败回退原格。
- `IsEnoughBag`：`Itemlist.Count < MAXBAGITEM`。

**未验证**：`MoveToMovingObject`/`CanSafeWalk`/`GetNextPosition`/`GetAllCreature` 实现未逐一读；
`CharDrawingRush` 注释掉的推人分支是否为有意禁用未核实；`MAXKINGLEVEL` 值未查；无运行期验证。

### 10.20 经验、等级与召唤物成长（Round 953；`ObjBase.pas:6763-7179`）

#### 10.20.1 经验计算与分配（`:6763-6854`）

- **`CalcGetExp(targlevel, targhp)`（`:6763`）**：`self.Level < targlevel+10` 时全额 `targhp`；
  否则按 `targhp - Round((targhp/15) * (self.Level-(targlevel+10)))` **递减**（**越级打怪经验惩罚**），
  下限 1。
- **`GainExp(exp)`（`:6781`）—— 组队经验分配**：`bonus[0..GROUPMAX]` 数组
  （1/2/3…11 人 → 1.2/1.3/…/2.2，注释给出完整表）；统计**存活 + 同环境 + 12 格内**的组员数与等级和；
  `dexp := Round(exp*bonus[n])`；每名符合条件组员得 `Round(dexp/sumlv * 自己等级)`（**不超过 exp**）；
  队长生日额外 +10%；无有效组队则 `WinExp(exp)`。
- `GainSlaveExp`（`:6826`）：分身/天使不吸收；`SlaveExp += exp`；`NextExp = 100 + Level*15 + slaveupexp[SlaveExpLevel]`
  （`slaveupexp = (0,0,50,100,200,300,600)`）；升级上限 `SlaveMakeLevel*2+1`，升级后 `RecalcAbilitys`+`ChangeNameColor`。

#### 10.20.2 召唤物等级加成 `ApplySlaveLevelAbilitys`（`:6857-6932`）

按种族/名字分派：
- 백골/신수（`RC_WHITESKELETON`/`RC_ELFMON`/`RC_ELFWARRIORMON`）：
  `WAbil.DC` 高字节 `+= Round(3*(0.3+SlaveExpLevel*0.1)*SlaveExpLevel)`；`MaxHP` 按 `Abil.MaxHP*(0.3+…)*level` 放大。
- **호위병**（护卫）：`DC += 2*SlaveExpLevel`、`MaxHP = _MIN(Abil.MaxHP+240*SlaveExpLevel, 3000)`、**`MAC := 0`**（驯服怪怕魔法）。
- **궁수호위병**（弓箭护卫）：`DC += 8*SlaveExpLevel`、`MaxHP = _MIN(Abil.MaxHP+60*SlaveExpLevel, chp)`。
- 其它驯服怪：`DC += 2*SlaveExpLevel`、`MaxHP = _MIN(Abil.MaxHP+60*SlaveExpLevel, chp)`。
- 统一 `AccuracyPoint := 15`（**召唤/驯服物命中固定 15**）。

#### 10.20.3 `WinExp(exp)`（`:6935-7121`）—— 经验入账与升级

1. `exp` 先钳到 **60000**；`ExpRate := 300`（测试服）否则 100；`InstantExpDoubleTime` 有效时 **×2**。
2. 按 `ExpRate` 分档累加 `Abil.Exp`（100/120/130/150/200 各有公式），`exptotal` 钳到 **65000**。
3. **PAIN 系列（苦痛）装备**（项链/左右手镯/左右戒指/护身石，`Shape=PAIN_SERIES_SHAPE`）：
   把 `exptotal/2` 累积到 `ItemExpPoint`；达 `MAXITEMEXPPOINT=200000` 时对应 `UseItems[i].Desc[10] += 1`
   （**鉴定进度**）并 `SendUpdateItem`；同时**玩家实得经验减半**；只作用于一件。
4. `RM_WINEXP` 通知客户端；`ENABLE_FAME_SYSTEM` 时按 `exptotal*1%` 加 fame（18 级封顶）。
5. `AddBodyLuck(exp*0.002)`；`Abil.Exp >= MaxExp` → 扣减、`Level++`、`HasLevelUp`、
   `AddBodyLuck(100)`、写日志码 `12`（렙업/升级）、`IncHealthSpell(2000,2000)`（**升级回满**）。

#### 10.20.4 `HasLevelUp` / `GetNextLevelExp` / `ChangeLevel`（`:7123-7179`）

- `HasLevelUp(prevlevel)`：`MaxExp := GetNextLevelExp(Level)`；`RecalcLevelAbilitys`；
  `{$IFDEF FOR_ABIL_POINT}` 下按 `GetBonusPoint(Job, Level)` 加 `BonusPoint` 并发 `RM_ADJUST_BONUS`
  （等级跳变时整表重算）；`RecalcAbilitys`；`RM_LOOPNORMALEFFECT(NE_LEVELUP)` + `RM_LEVELUP`；
  **体验模式（`ApprovalMode=1`）超过 `EXPERIENCELEVEL` 则强制断线**。
- `GetNextLevelExp(lv)`：查 `NEEDEXPS[lv]` 常量表（1..MAXLEVEL），否则 `$7FFFFFFF`。
- `ChangeLevel`：只接受 `1..40`。

**未验证**：`NEEDEXPS`/`GROUPMAX`/`MAXLEVEL`/`EXPERIENCELEVEL`/`PAIN_SERIES_SHAPE` 常量值未查；
`GetBonusPoint`/`GetLevelBonusSum`/`RecalcLevelAbilitys` 实现未逐一读；无运行期验证。

### 10.21 魔法学习、施放与防御/诅咒（Round 954；`ObjBase.pas:13700-14168`）

#### 10.21.1 魔法学习与施放（`:13700-13775`）

- `IsMyMagic(magid)`：在 `MagicList` 里按 `MagicId` 查找。
- **`ReadBook(std)`（`:13713`）**：`GetDefMagic(std.Name)`；若未学且 `(pdm.Job=99 或 =自己 Job)` 且
  `Level >= pdm.NeedLevel[0]` → `new(pum)`（`Level=0`/`CurTrain=0`/`Key=#0`）+ `MagicList.Add` +
  `RecalcAbilitys` + `SendAddMagic`。
- **`GetSpellPoint(pum)`（`:13742`）**：`Round(pDef.Spell/(MaxTrainLevel+1)*(Level+1)) + pDef.DefSpell`
  （注释「클라이언트와 일치시켜야 함」）。
- **`DoSpell(pum, xx, yy, target)`（`:13750`）**：剑法（`MagicMan.IsSwordSkill`）直接返回；
  `spell = GetSpellPoint`，`MP >= spell` 才 `DamageSpell(spell)`（**MagicId=42 分身术**特殊：
  扣蓝后单独 `HealthSpellChanged`）；`MagicMan.SpellNow(self, pum, xx, yy, target, spell)`。

#### 10.21.2 穿透直线与命中（`:13782-13839`）

- **`MagPassThroughMagic(sx,sy,tx,ty,ndir,magpwr,undeadattack)`（`:13782`）**：从 `(sx,sy)` 朝目标
  逐格前进**最多 13 步**，每格取实体；`IsProperTarget` 且 `AntiMagic <= Random(50)`（**魔法闪避门**）
  → `SendDelayMsg(RM_MAGSTRUCK, ..., 600)`；`undeadattack` 时伤害 ×1.5；返回命中数。
- `MagCanHitTarget`（`:13814`）：13 步内要求 `CanFireFly` 且到达目标或 Manhattan 距离变大（详见 §10.12.2）。

#### 10.21.3 防御/泡泡/诅咒/增益（`:13841-14113`）

- **`MagDefenceUp`/`MagMagDefenceUp(sec, value)`（`:13841`/`:13861`）**：设 `STATE_DEFENCEUP`/
  `STATE_MAGDEFENCEUP` 的秒数与 `StatusValue`（≤255），`RecalcAbilitys` + `RM_ABILITY`。
- `MagBubbleDefenceUp(mlevel, sec)`（`:13881`）：仅在未挂时设 `STATE_BUBBLEDEFENCEUP` +
  `BoAbilMagBubbleDefence` + `MagBubbleDefenceLevel`；`DamageBubbleDefence` 每次受击扣 3 s。
- **`MagMakeDefenceArea(xx,yy,range,sec,BoMag)`（`:13913`）**：范围内 `IsProperFriend` 的实体
  按 `LOBYTE(SC)/9 + Random(HIBYTE(SC)/9)` 加防/魔防，返回命中数。
- **`MagMakeCurseArea(xx,yy,range,sec,pwr,skilllevel,BoMag)`（`:13950`）**：范围诅咒。
  `BoMag=false`（怪魔法）与 `BoMag=true`（人魔法）两套概率公式；`targetsec` 人类 = `sec/6 - PoisonRecover`、
  怪（≥60 级）= `sec/4`、普通怪 = `sec`；命中后 `RM_CURSE`（延迟 1200 ms）+ 对目标 `RM_STRUCK`。
- `MagDcUp(sec, pwr)`（`:14044`）：给自己和所有召唤物加 `EABIL_DCUP`（+MCUP）限时增益。
- `MagCurse(sec, pwrrate)`（`:14088`）：`POISON_SLOW` + `EABIL_PWRRATE`（攻击力百分比，<100 降、>100 升）。

#### 10.21.4 技能升级与每日任务（`:14115-14168`）

- **`CheckMagicLevelup(pum)`（`:14115`）**：`CurTrain >= MaxTrain[Level]` 时 `Level+1`、
  `RM_MAGIC_LVEXP`（延迟 800 ms）、`CheckMagicSpecialAbility`。
- `CheckMagicSpecialAbility`（`:14138`）：**MagicId=28（탐기파연）等级 ≥2 → `BoAbilSeeHealGauge := TRUE`**
  （**看破血量**）。
- `GetDailyQuest`/`SetDailyQuest`（`:14148`/`:14161`）：用 `month*31 + day` 作日期键，
  跨日/未设置返回 0。

**未验证**：`MagicMan.IsSwordSkill`/`SpellNow`/`GetDefMagic`/`IsProperFriend` 实现未逐一读；
概率公式的实际命中率未运行验证；无运行期验证。

### 10.22 友方判定、名声、矿石纯度与额外能力（Round 955；`ObjBase.pas:15152-15392/17126-17196`）

#### 10.22.1 `IsProperFriend`（`:15152-15214`）

**与 `IsProperTarget` 相对**，用于治疗/增益的友方判定：
- 自己 `RaceServer >= RC_ANIMAL`（生物）：目标也是生物 → 友方；**目标有 `Master`（召唤物）则拒绝**
  （注释「소환몹은 힐,등이 안된다」= 召唤物不能被治疗）。
- 自己非生物（NPC）：`RC_USERHUMAN` 时按 `HumAttackMode` 的 `IsFriend`（`HAM_ALL/PEACE` 全部、
  `HAM_GROUP` 自己+组员、`HAM_GUILD` 自己+同会+盟会、`HAM_PKATTACK` 同红白名）判定；
  目标有 `Master` 时改判主人；非人类 NPC 一律友方。

#### 10.22.2 目标与名声（`:15216-15392`）

- `SelectTarget`/`LoseTarget`：设 `TargetCret` + `TargetFocusTime` / 置 nil。
- **`GetPurity`（`:15227`）—— 矿石纯度**：人类且**武器 Dura=0** → `1000+Random(5000)`；
  否则 `3000+Random(13000)`，**1/20 概率再 +`Random(10000)`**；体验模式上限 10000；
  怪物掉落 → `3000+Random(11000)` + 1/20 加值。
- **名声 `IncFamePoint(point, onlyFameCur)`（`:15262`）**：`point` 钳 10000；溢出检查；
  上限 **4000 万**；`FameCur += point`；若 `FameCur > FameBase` 则 `onlyFameCur` 时把 `FameCur` 压回 `FameBase`
  （**只涨当前值**），否则 `FameBase := FameCur`；发 `RM_CHANGEFAMEPOINT`（带称号）。
- `DecFamePoint`（先扣 `FameBase`，`FameCur` 不超过 `FameBase`）/`ZeroFamePoint`/`UseCurrentFamePoint`。
- **`DecWeaponBadLuck`（`:15374`）**：武器 `Desc[4] - Desc[3] > 0`（有诅咒）时 `Desc[4] -= 1`，
  重算能力 + 提示「무기의 저주가 감소되었습니다.」。

#### 10.22.3 `EnhanceExtraAbility(kind, amount, min, sec)`（`:17126-17196`）

- `ExtraAbil[kind] := _MIN(255, amount)` —— ⚠️ **是覆盖而非取最大值**（注释 `//수정(sonmg 2006/02/14)`
  表明从 `_MAX(旧值, amount)` 改成了直接覆盖）。
- `ExtraAbilTimes[kind] := _MAX(旧值, now + min*60000 + sec*1000)`（**时间取较大值**）。
- 人类按 `kind` 输出提示（DCUP/MCUP/SCUP/HITSPEEDUP/HPUP/MPUP），未知类型用通用文案。

**未验证**：`GetFameName`/`IsMember`/`IsAllyGuild` 实现未逐一读；名声上限/称号表未解析；
`ExtraAbil` 的 `EABIL_*` 常量值与消费点（`RecalcAbilitys`）已部分读；无运行期验证。

### 10.23 安全区、名字颜色、PK 与金币/负重（Round 956；`ObjBase.pas:7182-7611`）

#### 10.23.1 安全区（`:7182-7244`）

- **`InSafeZone`**：地图 `Lawfull`；或 `BADMANHOMEMAP` 内 `BADMANSTART ±10`；
  或落在 `StartPoints`/`SafePoints` 的范围内（**范围来自 `MapInfo.txt` 的 `/n` 后缀，默认 10**）。
- `InGuildWarSafeZone`：`Lawfull` 或 `StartPoints ±60`（**行会战禁战区**）。

#### 10.23.2 PK 与名字颜色（`:7246-7412`）

- **`PKLevel := PlayerKillingPoint div 100`**（≥1 黄名、≥2 红名）。
- `MyColor`：默认 `DefNameColor`；`PKLevel=1 → 251`（黄）、`≥2 → 249`（红）。
- **`GetThisCharColor(cret)`（`:7272`）—— 关系色**（`self` 看 `cret` 的颜色）：
  - 人类：`BoIllegalAttack` → 47（棕）；行会关系 1/3 → 180（蓝，己方）、2 → 69（橙）；
    `Fight3Zone`（行会比武场）同/异会 → 180/69；**攻城战**中双方都在 Free-PK 区 → 221（绿），
    再按守方/攻方/盟会细分 180/69。
  - 怪物：分身 → 主人色；`SlaveExpLevel` 色表 `(255,254,147,154,229,168,180,252)`；
    狂暴 249（红）、善狂 253（紫）、HolySeize 125。
- `GetGuildRelation`：0 无关系 / 1 本会 / 2 敌对 / 3 同盟；**行会战安全区返回 0**；
  有 `KillGuilds` 时置 `BoGuildWarArea`。
- `IsGuildMaster`（Rank=1）/`IsMyGuildMaster`（Rank=1 且当前图庄园号=本会庄园号）/
  `GetGuildNameHereAgit`/`GetGuildMasterNameHereAgit`。

#### 10.23.3 PK 点、幸运与金币（`:7450-7571`）

- `IncPKPoint`：上限 **1,000,000**；跨档且 `PKLevel<=2` 时 `ChangeNameColor`。
  `DecPKPoint`：下限 0，跨档 `0<old<=2` 时改名色。
- `GetPKTimeMin`：`Round(PlayerKillingPoint*2/60)` 小时（**1 PK 点≈2 分钟衰减**）。
- **`AddBodyLuck(r)`（`:7498`）**：`BodyLuck` 钳在 `±5*BODYLUCKUNIT`；`BodyLuckLevel = Trunc(BodyLuck/BODYLUCKUNIT)` 钳 `-10..5`。
- `IncGold`/`DecGold`：以 `AvailableGold` 为上限（`Int64` 防溢出）；单次 `>= EXORBITANT_GOLD`
  写日志码 `45`（금전/金钱，带等级十位）。
- **负重**：`CalcBagWeight`（`OverlapItem=1` → `Dura/10`；`≥2` → `Dura*Weight`；否则 `Weight`）；
  `CalcWearWeightEx(windex)`（除指定槽与武器/右手外累加）。

**未验证**：`StartPoints`/`SafePoints`/`AvailableGold`/`EXORBITANT_GOLD`/`BODYLUCKUNIT` 常量值未查；
颜色码的客户端业务名未核实；无运行期验证。

### 10.24 `TUserHuman.Initialize` / `Finalize`（Round 957；`ObjBase.pas:17610-18059`）—— 玩家上下线

#### 10.24.1 `Initialize`（`:17610-17996`）—— 登录初始化

1. **反作弊/异常检查**：`FirstGold := Gold`；**1 级却持巨额金币**写 `MainOutMessage`+`AddUserConAlarmLog`；
   测试服补 `TestLevel/TestGold`；`BoServiceMode` 调整 `ApprovalMode`。
2. **物品清洗**（逐项 `Dispose`+`Delete`）：
   - 名字已不存在的物品（`GetStdItemName = ''`）；
   - `OverlapItem>=1` 且 `Dura=0` 的堆叠物品（背包 + 仓库）；
   - **重复 `MakeIndex`** 的物品；
   - 台湾事件物品：**新登录**直接删除，**换服登录**保留并置 `BoTaiwanEventUser`+`STATE_BLUECHAR`+`RM_CHANGELIGHT`；
   - 装备槽非法（`IsTakeOnAvailable` 为假）→ 退回背包。
3. 状态时间复位；`CharStatus := GetCharStatus`。
4. `FrmIDSoc.SendPremiumCheck`/`SendEventCheck`（**付费/活动资格跨服查询**）；`RM_LOGON`。
5. **人群密度**：`Abil.Level <= EXPERIENCELEVEL` 且 `GetUserMassCount >= 80` → `RandomSpaceMoveInRange(0,15,30)`；
   `MustRandomMove`（行会比武场幸存）→ `RandomSpaceMove`。
6. `UserDegree := GetMyDegree`；`CheckHomePos`（红名回红名点）。
7. **首次连接**发放蜡烛/基础药/木剑/平民衣（按性别）。
8. `RecalcLevelAbilitys`+`RecalcAbilitys`；`MaxExp := GetNextLevelExp`；`FreeGulityCount=0` 时清 PK 点；
   金币上限 `BAGGOLD*2`。
9. **版本/校验和验证**（非换服）：`ClientVersion < VERSION_NUMBER` 或 `ClientVersion <> LoginClientVersion`
   或三个 `ClientCheckSumValue` 都不符 → 提示 + `EmergencyClose`（`BoClientTest` 豁免）。
10. 攻击模式提示、测试服人数限制、**体验模式**（`AvailableGold := 500000`、超 `EXPERIENCELEVEL` 断线）、
    冒险服提示。
11. `Bright := MirDayTime`；发 `RM_ABILITY`/`RM_SUBABILITY`/`RM_DAYCHANGING`/`RM_SENDUSEITEMS`/`RM_SENDMYMAGIC`。
12. **行会**：`GuildMan.GetGuildFromMemberName` → `MemberLogin`（取 Rank）、行会战提示、
   庄园逾期提示、行会消息 + `ISM_GUILDMSG` 跨服。
13. `CmdGuildAgitExpulsionMyself`（无庄园却在庄园图则强制移出）；`SendDecoItemList`。
14. `PLongHitSkill` 存在则发 `+LNG`（**解锁远程攻击**）。
15. `NoReconnect` 图 → `RandomSpaceMove(BackMap)`。
16. **恢复换服前召唤物**（`PrevServerSlaves` → `RmMakeSlaveProc`）。
17. `RM_DOSTARTUPQUEST`；定量账号 `FrmIDSoc.SendCheckTimeAccount`；未读便签 `RM_TAG_ALARM`；
    师徒数据 `RM_LM_DBWANTLIST`。

#### 10.24.2 `Finalize`（`:17998-18035`）—— 下线

`ReadyRun` 时 `Disappear(5)`；固定隐身/Taiwan 状态清除；**退组**（自己是队长则解散）；
行会 `MemberLogout`；`WriteConLog`。

#### 10.24.3 `WriteConLog`（`:18037-18059`）

只有**付费（ApprovalMode=2）或测试服**记录在线秒数；`AddConLog` 写
`地址/账号/角色/在线秒/登录时间/登出时间/AvailableMode`。旧的按时长计费上报已注释。

**未验证**：`IsTakeOnAvailable`/`GetMyDegree`/`CheckHomePos`/`MemberLogin`/`GuildMan`/`FrmIDSoc.*`
实现未逐一读；`EXPERIENCELEVEL`/`TestLevel`/`TestGold`/`VERSION_NUMBER` 常量值未查；无运行期验证。

### 10.25 等级能力、命中/技能、道具魔法与复活戒指（Round 958；`ObjBase.pas:7618-7979`）

#### 10.25.1 `RecalcLevelAbilitys`（`:7618-7751`）—— 两套公式

本函数有 **`{$IFDEF FOR_ABIL_POINT}` 两个版本**（开关决定用哪套）：
- **ABIL_POINT 版**（`:7618`）：`mlevel := _MIN(Level, ADJ_LEVEL)`；按 `Job` 0/1/2 算
  `MaxWeight/MaxWearWeight/MaxHandWeight/MaxHP/MaxMP/DC/MC/SC/AC/MAC`，最后**叠加 `BonusAbil`**。
- **普通版**（`:7688`）：用**完整 Level**，按 `Job` 0/1/2 算；`MaxHP := 14 + Round((Level/4+4.5+Level/20)*Level)`（战士）、
  `Level/15+1.8`（法师）、`Level/6+2.5`（道士）；`MaxWeight` 战士 `/3`、法师 `/5`、道士 `/4`；
  `DC/MC/SC` 用 `Level div 7` 派生；道士 `MAC := MakeWord(n div 2, n+1)`。

> ⚠️ **两个版本不能混读**：公式注释里保留了旧系数（如 `/18`、`/13`），
> **以未被注释的行 + `{$IFDEF}` 开关为准**。

#### 10.25.2 `RecalcHitSpeed`（`:7758-7844`）—— 命中与剑法绑定

重置 `AccuracyPoint := DEFHIT + BonusAbil.Hit`、`HitPowerPlus/HitDouble := 0`；
`SpeedPoint := DEFSPEED + BonusAbil.Speed`（**道士额外 +3**）；清 9 个 `P*Skill` 指针；
然后遍历 `MagicList` 按 `MagicId` 绑定技能并给加成：

| `MagicId` | 技能 | 效果 |
|---:|---|---|
| 3 | 외수검법（战士基础） | `PSwordSkill`；`Accuracy += Round(9/3*Level)` |
| 4 | 일광검법（道士基础） | `PSwordSkill`；`Accuracy += Round(8/3*Level)` |
| 7 | 예도검법 | `PPowerHitSkill`；`Accuracy += Round(3/3*Level)`；`HitPowerPlus := 5+Level`；`AttackSkillCount := 7-Level`、`AttackSkillPointCount := Random(...)` |
| 12 | 어검술 | `PLongHitSkill` |
| 25 | 반월검법 | `PWideHitSkill` |
| 26 | 염화결 | `PFireHitSkill`；**`HitDouble := 4 + Level*4`（+40%~+160%）** |
| 34 | 광풍참 | `PCrossHitSkill`；`HitPowerPlus := 5+Level` |
| 38 | 쌍룡참 | `PTwinHitSkill`；`HitPowerPlus := Level` |
| 43 | 사자후 | `PStoneHitSkill`；`HitPowerPlus := Level` |

→ **`_Attack` 的 `HitPowerPlus`/`HitDouble` 就来自这里**（配合 `HM_POWERHIT/FIREHIT`）。

#### 10.25.3 道具魔法 `AddMagicWithItem`/`DelMagicWithItem`（`:7846-7915`）

- `AddMagicWithItem(AM_FIREBALL/AM_HEALING)`：按 `AM_*` 找 `DefMagic`（韩/非韩名不同），
  未学则加入 `MagicList`（`Level=1`）+ `SendAddMagic`。
- `DelMagicWithItem`：**职业不符则删除**（`Job<>1` 删火球、`Job<>2` 删治疗），非人类直接返回。

#### 10.25.4 `ItemDamageRevivalRing`（`:7918-7979`）

遍历装备槽，左右戒指中 `Shape=RING_REVIVAL_ITEM`（**复活戒指**）每次使用 `Dura -= 1000`：
- 归零 → 销毁 + `SendDelItem` + 提示 + **日志码 `16`（죽파/戒指损毁）** + `RecalcAbilitys`；
- 未归零 → **日志码 `11`（사용/使用）**；耐久变化发 `RM_DURACHANGE`。

**未验证**：`ADJ_LEVEL`/`DEFHP`/`DEFMP`/`DEFHIT`/`DEFSPEED`/`AM_FIREBALL`/`AM_HEALING`/`RING_REVIVAL_ITEM`
常量值未查；`FOR_ABIL_POINT` 是否启用未核实；无运行期验证。

### 10.26 `RecalcAbilitys` 尾段与最终能力合成（Round 959；`ObjBase.pas:8620-9299`）

#### 10.26.1 套装加成续（`:8620-8765`）

- **强化版套装**：강화백금（DC+0/3、HP+30、HitSpeed+2、MaxWearWeight+2）、
  강화연옥（SC+0/2、HP+15、MP+20、UndeadPower+1、HIT+1、SPEED+1）、
  강화홍옥（MC+0/2、MP+40、SPEED+2）。
- **용 세트（龙套）** 分两大分支：
  - **全套 10 件**：AC+1/4、MAC+1/4、Luck+2、HitSpeed+2、AntiMagic+6、AntiPoison+6、
    MaxHandWeight+34、MaxWearWeight+27、MaxWeight+120、MaxHP+70、MaxMP+80、SPEED+1、
    DC+1/4、MC+1/3、SC+1/3。
  - 否则 **Type B**（衣+头+武+靴+带 → B-3；衣+靴+带 → B-2；衣+头+武 → B-1）与
    **Type A**（五件饰品 A-6 起，按戒指/手镯/项链组合递减到 A-1）两套独立加成。

#### 10.26.2 事件装备与特殊甲（`:8772-8978`）

- **반짝천의（banjjak2_dress）**：`Level>=20` 起，按 `<30`/`<40`/`40+` 三档给 DC/MC/SC/AC/MAC。
- **천의무봉（dset_wingdress）**：同上，四档（`<30`/`<40`/`<50`/`50+`）。
- **반짝 무기 692/693/694**（`banjjak_weapon38/39/40`）：`Level>20` 生效，**红名（`PKLevel>=2`）额外 `UnLuck+10`（诅咒）**；
  按等级档给 DC/SC/MC 与手部负重（如 38 号 30–39 级 `HandWeight+25`、40+ `+50`）。
- **반짝 2차 武器 697/698/699**（`banjjak2_weapon0/1/2`）：同构，红名诅咒，负重更大。
- **수정갑옷（crystal_dress）**：`MissProbability := 2`、`FeedbackProbability := 30`、`FeedbackRatio := 50`
  （**2% 闪避 + 30% 概率反伤 50%**）。

#### 10.26.3 最终合成（`:8982-9097`）

- `WAbil.Weight := CalcBagWeight`。
- 隐身：`BoFixedHideMode + STATE_TRANSPARENT` → `BoHumHideMode`，状态变化时 `CharStatusChanged`。
- **攻速折半**（`sonmg`）：`AddAbil.HitSpeed >= 0` 时 `div 2`，负数时 `(x-1) div 2`（**向下取整偏小**），
  再 `_MIN(15, ...)` 封顶。
- `Light := GetMyLight`，变化则广播 `RM_CHANGELIGHT`。
- **叠加 `AddAbil` 到最终值**：`SpeedPoint/AccuracyPoint/AntiPoison/PoisonRecover/HealthRecover/
  SpellRecover/AntiMagic/Luck`（`Luck -= AddAbil.UnLuck`）、`HitSpeed`；
  `MaxHP/MaxMP := Abil + AddAbil`；`AC/MAC/DC/MC/SC := MakeWord(_MIN(255, AddAbil+Abil))`。
- `STATE_DEFENCEUP`/`MAGDEFENCEUP` 用**新公式**（`HIBYTE += Level div 7 + StatusValue[]`）。
- `ExtraAbil[EABIL_DCUP/MCUP/SCUP/HITSPEEDUP/HPUP/MPUP]` 叠加（`:9099-9299` 收尾）。

**未验证**：所有 `*_SHAPE`/`banjjak_weapon*` 物品索引对应的 EI 数据行未解析；
`GetMyLight`/`ApplyItemParameters`/`ApplyItemParametersEx` 已部分读；无运行期验证。

### 10.27 装备/卸装/捆绑服务端处理（Round 960；`ObjBase.pas:26475-26683`）

#### 10.27.1 `ServerGetTakeOnItem(where, svindex, itmname)`（`:26475-26584`）

按 `MakeIndex` + 名字在背包定位目标，然后三重校验：
1. **`IsTakeOnAvailable(where, ps)`**：装备位是否匹配（如刀不能穿在衣服位）。
2. `std := ps^` 后 **`ItemMan.GetUpgradeStdItem(targpu^, std)`**（叠加升级属性）。
3. **`CanTakeOn(where, @std)`**：性别/等级/职业是否达标。

若目标槽已有装备，先做**不可脱下检查**：
- `StdMode in [15,19,20,21,22,23,24,26,52,53,54]` 且 `Desc[7] <> 0` → 不可脱；
- `ItemDesc and IDC_UNABLETAKEOFF <> 0` → 不可脱（`BoNextTimeFreeCurseItem` 可豁免）；
- `ItemDesc and IDC_NEVERTAKEOFF <> 0` → 绝对不可脱。
以上任一命中 → `SysMsg('아이템이 빠지지 않습니다.')` + 失败码 **-4**。

成功后：未知属性（`Desc[8]`）**穿上即解明**置 0；`UseItems[where] := targpu^`；`DelItemIndex`；
旧装备 `AddItem` + `SendAddItem`；`RecalcAbilitys` + `SM_TAKEON_OK`（带 `Feature`）+ `FeatureChanged`；
**按装备类型选择同步**：翅膀/龙衣/破天衣 → `SendUpdateItemWithLevel`；破天/龙衣 → `SendUpdateItemByJob`；
**반짝武器 692-694/697-699 → `SendUpdateItemWithLevel`**；否则 `SendUpdateItem`。
失败码：-1 `CanTakeOn` 失败、-2 `IsTakeOnAvailable` 失败。

#### 10.27.2 `ServerGetTakeOffItem(where, svindex, itmname)`（`:26586-26654`）

`not BoDealing` 且 `where in [0..12]` 才可脱；`UseItems[where]` 已装备且 `MakeIndex` 匹配；
**同样的不可脱下三重检查**（-4）；`AddItem` 成功才清槽 + `SM_TAKEOFF_OK` + `RecalcAbilitys` + `FeatureChanged`；
**苦痛（PAIN）系列脱下时 `ItemExpPoint := 0`**（临时累积清零）。失败码：-1 状态不符、-2 未装备、-3 背包满。

#### 10.27.3 `BindPotionUnit(Shape, Count)`（`:26657-26683`）

把散装药捆成捆装：**符（`SHAPE_AMULET_BUNCH`）不可捆**；按 `GetStdItemNameByShape(31, Shape)`
找捆装物品（`StdMode=31`），`CopyToUserItemFromName` 成功则入包 + `SendAddItem`。

**未验证**：`IsTakeOnAvailable`/`CanTakeOn`/`CopyToUserItemFromName`/`GetStdItemNameByShape` 实现未逐一读；
`DRESS_STDMODE_*`/`WEAPON_STDMODE*`/`SHAPE_AMULET_BUNCH` 常量值未查；无运行期验证。

### 10.28 礼物箱/彩蛋/旧匣掉落表（Round 961；`ObjBase.pas:15396-17125`）

三个「开箱」函数都是 `if RaceServer<>RC_USERHUMAN exit` + 背包未满（`ItemList.Count < MAXBAGITEM`）
+ **单个 `case Random(N)` 巨表**，命中则 `CopyToUserItemFromName(名, pi^)` 入包 + `WeightChanged` + `SendAddItem`。
**概率 = 区间宽度 / N**（区间外 = 空）。

#### 10.28.1 `GetGiftFromBox`（선물상자，`:15396-16181`，`Random(250000)`）

| 区间 | 物品 | 概率≈ |
|---|---|---:|
| 1..12 | 12 种「신주」（용맹/마성/선계/질풍/회피/집중/혹한/각성/인내/수호/제마/강화）各 1 点 | 1/250000 |
| 13..122 | 11 种「보옥」（질풍/회피/집중/혹한/각성/인내/용맹/마성/선계/수호/제마/강화）10 点档 | ~4/10万 |
| 123..632 | 축복의기름（祝福油） | 510/250000 |
| 633..3132 | 무신의기름（武神油，完全修理） | 2500/250000 |
| 3133..5632 | 흑철（黑铁） | — |
| 5633..10632 | 금광석（金矿石） | — |
| 10633..40632 | 六种「석(대/중/소)」按**大/中/小**三档（적린/청운/지심/청람/목청/녹마） | 各 2500 或 1250 |
| 40633..40813 | 20 种饰品（사신의장갑/청동장갑/주술의팔찌/용사의팔찌/룡아륜/제마륜/룡주환/상형환/금룡환/파극의반지/뇌력환/태극환/호아목걸이/뢰명/천형수경/녹옥/마성의방울/사방령의목걸이…）各 10 点 | 10/250000 |
| 40814..100813 | 연풍수/선계수/마성수/용맹수（四种「수」，各 15000 点） | 6%/种 |
| 100814..130813 | 체력회복약(특) | 12% |
| 130814..160813 | 마력회복약(특) | 12% |
| 160814..188313 | 체력약묶음 | — |
| 188314..215813 | 마력약묶음 | — |
| 215814..235841 | 선화수(중) | ~8% |

#### 10.28.2 `GetGiftFromEgg`（彩蛋，`:16182-16687`，`Random(300000)`）

48 项：12 种 신주/보옥（1..96）→ 축복의기름（97..6095）→ 백금/금광석（6096..15094）→
六种「석(대)」（15095..33094）→ 饰品（33095..75093：사신의장갑/청동장갑/주술의팔찌/묵철팔찌/수양의반지/
주술의반지/산호석반지/퇴마반지/청옥석목걸이/화경/죽적）→ 체력/마력약묶음(특)（75094..102093）→
노끈（102094..120093，**绳**）→ 체력/마력약묶음（120094..165093）→ 무신의기름（165094..171843）→
체력/마력회복약(특/대)（171844..219093）→ 선화수(중)（219094..246093）→ **복권（246094..249093）**。
> 区间 249094..299999 = **空**。

#### 10.28.3 `GetGiftFromOldBox`（낡은궤짝，`:16688-17125`，`Random(250000)`）

39 项：11 种 보옥（1..132）→ 축복의기름（133..633）→ 무신의기름（634..2634）→
**10 种「마패」（马牌，3835..13443：파황마신/사우천왕/해골반왕/주마왕/흑천마왕/우면귀왕/촉룡신/
적월마/부룡금사…，各 1200 点）** → 용맹수/마성수（13444..18445）→ 솔잎（18446..20946，松叶）→
선계수/연풍수（20947..25948）→ 달콤한사탕（25949..28449，糖果）→ **이벤트응모권（28450..33450，活动抽奖券）** →
체력/마력약묶음（33451..43452）→ 체력/마력회복약(특/대)（43453..129456）→ 선화수(중)（129457..159457）→
만년설삼（159458..189458，万年雪参）→ 인삼（189459..224459，人参）。
> 区间 224460..249999 = **空**。

**未验证**：物品名对应的 EI `StdItem` 数据行未解析；`MAXBAGITEM` 值未查；
`CopyToUserItemFromName` 失败（物品不存在）时的行为已在源码 `Dispose` 处理；无运行期验证。

### 10.29 造物与装备强化（제련）系统（Round 962；`ObjBase.pas:19089-21107`）

#### 10.29.1 `CmdMakeItem(itmname, count)`（`:19089-19195`）

GM/脚本造物：
- `count > MAX_OVERLAPITEM` 直接 exit；逐件造，背包满 `MAXBAGITEM` 停。
- **价格门槛**：`StdItem.Price >= 15000` 的物件**只有 `UD_SUPERADMIN` 或测试服**能造。
- `Random(10)=0` → `RandomUpgradeItem`（造出来自带强化）。
- **未知系列**（`StdMode in [15,19,20,21,22,23,24,26,52,53,54]` 且 `Shape` 为 `RING/BRACELET/HELMET_OF_UNKNOWN`）→ `RandomSetUnknownItem`（随机鉴定属性）。
- **邀请函**（`StdMode=8` + `Shape=SHAPE_OF_INVITATION`）→ 必须 `GuildAgitInvitationItemSet`（只限该庄园成员）。
- **祥现袋/DecoItem**（`StdMode=STDMODE_OF_DECOITEM` + `Shape=SHAPE_OF_DECOITEM`）→ `GuildAgitDecoItemSet`。
- 计数物品（`OverlapItem>=1`）`Dura:=count`，只造 1 次；矿石（`StdMode=43`）`Dura:=GetPurity`（纯度）。
- `BoEcho` 时输出 + 日志 `'5'`（운만_，造物）。

#### 10.29.2 `CheckSeedItem(psSeed, psJewelry)`（`:20375-20499`）——强化材料判定

返回码：`0` 不可用 / `1` 属性冲突 / `2` 可强化 / `3` 唯一物品不可强化 / `10/11` 修理 / `20/21` 捆绑。
- **针（`StdMode=61`,`Shape=SHAPE_OF_NEEDLE`）**：可修 衣/盔/鞋/腰带（`StdMode in [10,11,15,52,54]`）→ 11，否则 10。
- **骨锤（`Shape=SHAPE_OF_HAMMER`）**：可修 项链/戒指/手镯（`[19,20,21,22,23,24,26]`）→ 11。
- **绳（`StdMode=7`,`Shape=SHAPE_OF_CORD`）**：`CheckUnbindItem` 通过 → 21（可捆），否则 20。
- 基底必须 `StdMode in [5,6,10,11,15,19,20,21,22,23,24,26,52,54]` 才 `Result:=2`，否则 0。
- **唯一物品**：`UniqueItem and $01 <> 0` → `3`（连升级也不行）。
- **属性冲突表**（每种装备位禁用的宝石属性不同，如武器禁 `AC/MAC/Accurate/Agility/MgAvoid/ToxAvoid`，衣服禁 `DC/MC/SC/Accurate/AtkSpd/Slowdown/Tox`，戒指 23/手镯 24 特意去掉 `AC/MAC`）→ 冲突则 `1`。

#### 10.29.3 `CheckJewelryItem(StdMode)`（`:20502`）

可作强化媒介：`7`（绳）/`60`（보옥 宝石）/`61`（신주 神酒）。

#### 10.29.4 `SumOfOptions(puSeedItem, psSeedItem)`（`:20511-20596`）——「옵션합」iSum

按装备位把该位**有效 `Desc[]` 槽**相加（武器另加 `RealAttackSpeed(Desc[6])`；19/20/21/22/23 项链戒指另加 `Desc[9]` 攻速），
再加 **耐久超额** `max(0, (pu.DuraMax - ps.DuraMax)/2000)`（注释：2003-11-07 从 /1000 改 /2000）。
→ iSum 被夹在 `[0,10]`，是概率表行号。

#### 10.29.5 `CalcUpgradeProbability(...)`（`:20600-20838`）——核心概率

**`UpProb[0..10]` 表**（`iBase=10000`；`iValue[0..2]` = 보옥 三档，`iValue[3..5]` = 신주 三档 = 보옥 ×`MFactor/DFactor` = ×2，注释「原值 4，临时改 1.5 倍」）：

| iSum | v0(보옥/武器) | v1(보옥/手鞋) | v2(보옥/项链·其它) | 신주 = ×2 |
|---:|---:|---:|---:|---:|
| 0 | 5000 | 5000 | 5000 | 10000/10000/10000 |
| 1 | 4500 | 3000 | 4000 | 9000/6000/8000 |
| 2 | 4000 | 1000 | 3000 | 8000/2000/6000 |
| 3 | 3500 | 500 | 1000 | 7000/1000/2000 |
| 4 | 3000 | 100 | 500 | 6000/200/1000 |
| 5 | 1500 | 25 | 100 | 3000/50/200 |
| 6 | 400 | 5 | 25 | 800/10/50 |
| 7 | 100 | 5 | 5 | 200/10/10 |
| 8 | 25 | 5 | 5 | 50/10/10 |
| 9 | 5 | 5 | 5 | 10/10/10 |
| 10 | 0 | 0 | 0 | 0（不可强化） |

**成功值公式**（`iSucceed = min(iBase, Round(v * |系数| / 30))`）：
- **武器**：系数 = `29 + BodyLuckLevel + (LOBYTE(seed.AC) + seedDesc[3] − LOBYTE(seed.MAC) − seedDesc[4]) / 2`
 （`seed.AC` 低字节 = 武器**幸运**，`seed.MAC` 低字节 = **诅咒**；`BodyLuckLevel` = 角色体运）。
- **衣服**：`29 + BodyLuckLevel`。
- **手镯/鞋（24,26,52）** 用 `iValue[1]`；**项链 19** 与**其它**用 `iValue[2]`。
- 若媒介 `Shape=9`（攻速宝石）→ `iSucceed := iSucceed*60 div 100`（打 6 折）。
- **보옥（StdMode=60）**：`iFail := Round((iBase − iSucceed) * 0.7)`（注释「临时改 0.65」）→ 三态：`< iSucceed` 成功(2)、`< iSucceed+iFail` 不变(1)、否则**损坏(0)**。
- **신주（StdMode=61）**：**不会碎** → `< iSucceed` 成功(2)，否则不变(1)。
- `fRetProb := iSucceed / iBase`；`iExecCount>1` 时打印概率测试统计（调试用）。
- 返回 `Result ∈ {0 破坏, 1 不变, 2 成功}`。

#### 10.29.6 `CmdUpgradeItem(seedname, jewelryname, seedindex, jewelryindex, ExecCount)`（`:20842-21107`）

- `seedindex/jewelryindex = 0` 视为**运营者命令**（按名字找背包里第一个）；否则按 `MakeIndex` 定位。
- `CheckJewelryItem` 通过后 `CheckSeedItem` 定分支：
 - `2`：`CalcUpgradeProbability` → `GetTotalValueOfOption` 取强化前后总值 →
 `2` 成功：`DoUpgradeItem` 写入属性 + 删宝石 + `SysMsg`「상승」+ 日志 `'31'`(업후_)；失败返回 0 则「업그레이드할 수 없는 속성」。
 - `1` 不变：删宝石 + 「아무런 변화도 일어나지 않았습니다」。
 - `0` 破坏：删宝石 + `DeletePItemAndSendWithFlag(seed, true)`（**带破坏特效包**）+ 「아이템이 파괴되었습니다」。
 - 三态均 `SendDefMessage(SM_UPGRADEITEM_RESULT, seedindex, iResult, ...)` 回客户端。
 - `1` 属性冲突 / `3` 唯一不可强化 / `11` 走 `RepairItemNormaly` 修装备 / `21` 走 `FindItemToBindFromBag`+`BindPotionUnit`（绳捆药） / `10/20` 报错。

**未验证**：`DoUpgradeItem`/`GetTotalValueOfOption`/`RealAttackSpeed`/`RandomUpgradeItem`/`RandomSetUnknownItem`/`UpgradeResultToStr`
实现未逐一读；`MAX_OVERLAPITEM`/`MAXBAGITEM`/`UD_SUPERADMIN`/`STDMODE_OF_DECOITEM`/`SHAPE_OF_*` 常量值未查；无运行期验证。

### 10.30 物品/魔法同步包（Round 963；`ObjBase.pas:22664-22974`）

统一的物品编码：`TClientItem = {S: TStdItem; MakeIndex; Dura; DuraMax; UpgradeOpt}`。
`ItemMan.GetUpgradeStdItem(ui, std)` 把强化属性并入 `std`，`UpgradeOpt` 单独回传。

| 函数 | 包 | 载荷/特判 |
|---|---|---|
| `SendAddItem` | `SM_ADDITEM`（param=self，count=1） | 商品券 `StdMode=50` → `Name + ' #' + Dura`；**未鉴定**：`StdMode in [15,19,20,21,22,23,24,26,52,53,54]` 时按 `Desc[8]` 置/清 `IDC_UNIDENTIFIED` |
| `SendUpdateItem` | `SM_UPDATEITEM` | Index 706/707/708 → `BanjjakChangeItemByJob`（3 期闪烁活动），否则 `ChangeItemByJob`（龙物品按职业变属性） |
| `SendUpdateItemWithLevel(ui, lv)` | `SM_UPDATEITEM` | `ChangeItemWithLevel`（天衣无缝按等级变） |
| `SendUpdateItemByJob(ui, lv)` | `SM_UPDATEITEM` | 同上 706/707/708 分支 + `ChangeItemByJob(lv)` |
| `SendDelItem` | `SM_DELITEM`（param2=0） | 同上商品券/编码 |
| `SendDelItemWithFlag(ui, wBreakdown)` | `SM_DELITEM`（**param2=wBreakdown**） | 强化破坏特效包 |
| `SendDelItems(ilist)` | `SM_DELITEMS` | `name/makeindex/` 串接 |
| `SendBagItems` | `SM_BAGITEMS`（count=ItemList.Count） | 整包编码每个 `TClientItem` 用 `/` 分隔 |
| `SendUseItems` | `SM_SENDUSEITEMS` | 遍历 `0..U_CHARM`（注释 8→12），**只发 `Index>0` 的槽**，前缀 `槽号/`；`U_DRESS` 走 `ChangeItemWithLevel`，其余按职业变 |

**魔法**：`TClientMagic = {Key, Level, CurTrain, Def: TMagic}`。
- `SendAddMagic` → `SM_ADDMAGIC`（1 条）；`SendDelMagic` → `SM_DELMAGIC`（param1=`MagicId`）。
- `SendMyMagics` → `SM_SENDMYMAGIC`（count=MagicList.Count），**param1 = `(Σ DelayTime xor $773F1A34) xor $4BBC2255`**（校验和/混淆，防止客户端伪造魔法表）。

**未验证**：`GetUpgradeStdItem`/`ChangeItemByJob`/`BanjjakChangeItemByJob`/`ChangeItemWithLevel` 实现未读；
`U_CHARM`/`U_DRESS` 槽位编号、`IDC_UNIDENTIFIED` 位值未逐一核实；无运行期验证。

### 10.31 `TUserHuman.Say` 聊天与 `@` 命令分派（Round 964；`ObjBase.pas:23190-24574`）

#### 10.31.1 管理员密码提升（`:23199-23258`）

- `BoReadyAdminPassword` 状态下输入 `GET_A_PASSWD` → `UserDegree := UD_ADMIN`。
- `BoReadySuperAdminPassword` → 按版本分支比对**硬编码口令**（`KOREANVERSION` 测试服 `wemade09`、韩正式 `wjstjfofa1fm@#`；
 `CHINAVERSION`/`ENGLISHVERSION` = `Le&end0f#ir`；`TAIWANVERSION` = `TGL&S0ftW0rld`；`PHILIPPINEVERSION` = `PL2g&OfMir2`）→ `UD_SUPERADMIN`。
 > **安全注意**：口令明文写死在源码，且韩正式服口令与源码库同源泄露。

#### 10.31.2 `@` 命令分派（`:23278-24445`）

`saystr[1]='@'` → 以 `[' ', ',', ':']` 切出 `cmd` 与 `param1..param7`，按 `UserDegree` 分四级：

**所有人**（`:23298-23621`）：귓속말거부/허용、차단（封多个）、외치기거부、교환거부、문파가입、동맹허용/동맹/동맹파기（文派主）、문파전음차단、H/HELP、
내공（`EFFECTIVE_HIGHLEVEL` 以上开关 50 级内功特效 + `RecalcAbilitys`）、일지（测试任务日志）、
공격방식（循环 `HAM_ALL/PEACE/GROUP/GUILD/PKATTACK`）、휴식（`BoSlaveRelax` 主仆休/攻）、
비밀번호/gsa（转密码态）、사북성문（仅城主文派）、
**이동**（瞬移戒指 `BoAbilSpaceMove`，10s CD，`PEnvir.NoPositionMove` 禁）、**탐색**（探查项链，10s CD）、
천지합일거부/허용、소환거부/허용、**천지합일**（群体召唤，`BoCGHIEnable`，3min CD，仅 `GroupOwner`，成员可拒）、
**MeetCouple/만남**（需 `fLover` 满 100 天 + 戴 `SHAPE_COUPLERING`，20min CD）、**HappyBirthDay/생일축하**（`PremiumBirthDay`，30s CD，全屏粉色广播）。

**`UD_OBSERVER` 以上**（`:23624-23643`）：`@!` 全服公告、`@$` 本服公告、`@#` 本地图公告。

**`UD_SYSOP`**（`:23646-23891`）：ReloadLineNotice、Move/이동、PositionMove/PMove/자유이동、Stealth/스텔스、
Info/렙、MobLevel、KingMob、MobCount、Human、Map、Kick、Ting、SuperTing、Shutup/ReleaseShutup/ShutupList、
ReloadChatLog/AddChatLog/ReleaseChatLog/ChatLogList、GameMaster、Observer、Superman/무적、Level（≤40）、
SabukWallGold、Recall/소환、RecallMap/맵소환、flag/showopen/showunit（查任务标记）、addfriend、
CharMove/캐릭터이동、Goto/출두、ContestPoint/StartContest/EndContest/Announcement（文派战）、
누구/whoare、안전/safezone、PKpoint、ChangeJob、ChangeGender、LuckyPoint。

**`UD_ADMIN`**（`:23895-24444`）：attack、Mob、RecallMob、복권（抽奖统计）、ReloadGuild、ReadAbuseInformation、Backstep、
무태보、FreePenalty、IncPkPoint、ChangeLuck、Hunger、hair、Training、DeleteSkill、NameColor、Mission、MobPlace、
Transparency/tp、DeleteItem、Level0、퀘스트초기화、setflag/setopen/setunit、Reconnection、
DisableFilter、CHGUSERFULL、CHGZENFASTSTEP、`GET_INFO_PASSWD`（时长卡统计）、CHG_ECHO_PASSWD、
`KIL_SERVER_PASSWD`（**随机 1/4 触发停服/公告定时**）、OXQuizRoom（空）、TESTTIME、외치기범위。

**`UD_SUPERADMIN`/测试服**（`:24196-24443`）：Make、DelGold、AddGold、`TEST_GOLD_Change~`、무기제련、
ReloadAdmin、MarketOpen/MarketClose（SQL 寄售开关）、ReloadNpc、ReloadMonItems、ReloadDiary、
AdjustLevel、AdjustExp、AddGuild、DelGuild、ChangeSabukLord、ForcedWallconquestWar、
AddToItemEvent/AsPieces/ItemEventList/StartingGiftNo/DeleteAllItemEven/StartItemEvent/ItemEventTerm（**物品事件**）、
AdjustTestLevel、OPTraining、OPDeleteSkill、ChangeWeaponDura（≤65）、Upgrade、모든보옥/모든신주、
ReloadMakeItemList、글자색（DEBUG）、Alive、스핵체크（`g_SpeedHackCheck`）、AgitDecoMonCount/Here、
FamePoint/FameName、UserMarketDebug、연인해제；另 ReloadGuildAgit、OneKill（测试）、MonClear。

#### 10.31.3 普通聊天（`:24446-24573`）

- `PEnvir.NoChat` 地图禁言。
- **防刷屏（도배）**：同串 3s 内重复 → `BombSayCount++`，≥2 → **禁言 1 分钟**（`BoShutUpMouse`）；
 **高速聊天**：2s 内连发 → ≥5 → **禁言 30 秒**。
- 运营者 `ShutUpList` 命中 → 禁言。
- `/名字 内容` → `Whisper`（SYSOP 额外 `/who`，ADMIN `/total`）。
- `!!` 组队、`!~` 文派（+ 跨服 `ISM_GUILDMSG`）、`!` 外喊（需 ≥8 级，10s CD；**文派主无 CD 走 `GuildAgitCry` 50 格**，普通 `g_CryWide`）、`♡` 恋人私聊。
- 否则 `inherited Say`（普通聊天）。

### 10.32 `ThinkEtc` / `ReadySave`（Round 964；`ObjBase.pas:24576-24586`）

- `ThinkEtc`：`Bright <> MirDayTime` 时更新并 `SendMsg(RM_DAYCHANGING)`（昼夜变化）。
- `ReadySave`：`Abil.HP := WAbil.HP`（存档前同步）。

**未验证**：`GetValidStr3`/`CryCry`/`GuildAgitCry`/`UserSpaceMove`/`Cmd*` 各实现未逐一读；
`GET_A_CMD`/`GET_A_PASSWD`/`GET_SA_CMD`/`EFFECTIVE_HIGHLEVEL`/`g_CryWide` 常量值未查；无运行期验证。

### 10.33 使用/屠宰/商店/仓库处理（Round 965；`ObjBase.pas:26685-27468`）

#### 10.33.1 `ServerGetEatItem(svindex, itmname)`（`:26685-26837`）

死亡时禁用。按 `MakeIndex` 定位，按 `StdMode` 分派：
- `0,1,2,3`（试药/肉/食物/卷轴）→ `EatItem`，删除 + `SM_EAT_OK`；`StdMode=3` 且 `Shape<>2` 才记日志。
- `4`（书）→ `ReadBook`；学会后按技能开 `+LNG`（어검술 御剑）/`+WID`（반월검법 半月）/`+CRS`（광풍참 狂风）远程/范围攻击标志。
- `8`（可食/使用，如邀请函 `SHAPE_OF_INVITATION`）→ `EatItem`。
- `31`（捆绑药）→ 需背包空间 `ItemList.Count+6-1 <= MAXBAGITEM` → `UnbindPotionUnit(GetUnbindItemName(Shape), 6)` 拆成 6 个。
- 结果 `SM_EAT_OK`/`SM_EAT_FAIL`；日志 `'11'`（사용_）。

#### 10.33.2 `ServerGetButch(animal, x, y, ndir)`（`:26873-26908`）

屠宰（新版权重 `IsValidFrontCreature`，旧版 `IsValidCreature` 已注释）：
- 目标须 `abs(x-CX)<=2 and abs(y-CY)<=2`，且 `Death and not BoSkeleton and BoAnimal`。
- `BodyLeathery -= 5+Random(16)`（皮革度）、`MeatQuality -= 100+Random(201)`（肉质量，下限 0）。
- `BodyLeathery<=0`：若 `RaceServer in [RC_ANIMAL, RC_MONSTER)` → `BoSkeleton:=TRUE` + `ApplyMeatQuality` + `RM_SKELETON`；`TakeCretBagItems` 掉落；`BodyLeathery:=50`（防连发消息）。
- `DeathTime := GetTickCount`（屠宰中尸体不消失）；广播 `RM_BUTCH`。

#### 10.33.3 NPC 交互与商店（`:26910-27468`）

- `ServerGetMagicKeyChange`：改魔法热键。
- `ServerGetClickNpc` / `ServerGetMerchantDlgSelect`：交易中禁止；商人在同图且 `|dx|,|dy|<=15`（或 `BoInvisible` 地图任务 NPC）→ `UserCall`/`UserSelect`。
- 询价/修理价/卖出：按 `MakeIndex`+名定位，`TMerchant.QueryPrice/QueryRepairCost/UserSellItem/UserRepairItem`。
 **台湾活动物品（`TAIWANEVENTITEM`）不可卖**；计数物品（`OverlapItem>=1`）可按 `sellcnt` 部分卖。
- `ServerGetUserMenuBuy`（`CM_USERBUYITEM`/`CM_USERGETDETAILITEM`）、`ServerGetMakeDrug`/`MakeItemSel`/`MakeItem`（制造）。

#### 10.33.4 仓库（`:27087-27406`）

- `ServerSendStorageItemList(npcid)`：按 **50 件/页**分页发 `SM_SAVEITEMLIST`（param=npcid，param2=页码）；未鉴定物品按 `Desc[8]` 隐藏属性。
- `ServerGetUserStorageItem`（存）：**体验模式 `ApprovalMode=1` 禁用**；台湾活动物品不可存；
 计数物品（`OverlapItem>=1`）在仓库内**合并**（`SaveCountItemAdd`，同 `StdMode`+`Looks`+名，上限 1000）；`SaveItems.Count < MAXSAVELIMIT`；
 结果 `SM_STORAGE_OK`（param2=剩余量）/`SM_STORAGE_FULL`/`SM_STORAGE_FAIL`；日志 `'1'`（보관_）。
- `ServerGetTakeBackStorageItem`（取）：**重量预检**——`OverlapItem=1` 时 `Weight + Weight*(cnt div 10)`，`>=2` 时 `Weight*cnt`，否则 `Weight`；
 计数物品可部分取；`SM_TAKEBACKSTORAGEITEM_OK`/`_FULLBAG`/`_FAIL`；日志 `'0'`（찾기_）。

**未验证**：`EatItem`/`ReadBook`/`TMerchant.*`/`TakeCretBagItems`/`UserCounterItemAdd` 实现未读；
`MAXBAGITEM`/`MAXSAVELIMIT`/`TAIWANEVENTITEM`/`ApprovalMode` 值未查；无运行期验证。

### 10.34 组队与交易（Round 966；`ObjBase.pas:27471-28528`）

#### 10.34.1 组队（`:27471-27879`）

**两步握手**（请求者 → 被邀请者确认）：
- `ServerGetCreateGroup(withwho)`：自身无组、对方存在且非己、双方 `PEnvir.NoGroup=FALSE`、双方 `LoginSign`、
 对方无组、`AllowGroup`；`GroupRequester` + `GroupRequestTime`（**40s 超时自动清空**）；失败码 `-1..-5`；
 发 `SM_CREATEGROUPREQ`。
- `ServerGetCreateGroupRequestOk`：重校验后建组 `GroupMembers.AddObject` + `EnterGroup` + `SM_CREATEGROUP_OK` + `RefreshGroupMembers`。
- `ServerGetCreateGroupRequestFail`：清请求 + 通知请求者。
- `ServerGetAddGroupMember`：仅 `GroupOwner` 可加；`GroupMembers.Count >= GROUPMAX` 失败 `-5`；重复成员补丁（遍历比对 + nil 检查）；同上两步握手发 `SM_ADDGROUPMEMBERREQ`。
- `ServerGetDelGroupMember`：仅队长；`SM_GROUPDELMEM_OK/FAIL`。
- `RefreshGroupMembers`：把成员名 `/` 串接发 `SM_GROUPMEMBERS` 给每个成员，并 `RecalcAbilitys` + `RM_ABILITY`（**情人节情侣组队加成**）。

#### 10.34.2 交易（`:27881-28528`）

- `ServerGetDealTry`：需**面对面**（`GetFrontCret` 互指）+ 双方非 `BoDealing` + 对方 `BoExchangeAvailable`；
 **庄园交易**（`BoGuildAgitDealTry`）要求**双方都是文派主**；成功 `StartDeal` 双向。
- `StartDeal`：`BoDealing:=TRUE`，发 `SM_DEALMENU`（或 `SM_GUILDAGITDEALMENU`）。
- 加/删物品：`AddDealItem`/`DelDealItem` 发 `SM_DEALADDITEM_OK`/`SM_DEALDELITEM_OK`，并向对方发 `SM_DEALREMOTEADDITEM`/`SM_DEALREMOTEDELITEM`（含 `TClientItem`，未鉴定物品按 `Desc[8]` 隐藏）；计数物品走 `SM_COUNTERITEMCHANGE`。
- `ServerGetDealAddItem`：**`UniqueItem and $08` 不可交易**（注释 2005/03/14）；**台湾活动物品不可交易**；`DealList.Count < MAXDEALITEM`；计数物品 `count` 上限 `MAX_OVERLAPITEM`，可部分上架。
- `BrokeDeal`：取消时归还 `DealList` 物品（计数物品 `UserCounterItemAdd` 合并）+ `IncGold(DealGold)`；`SM_DEALCANCEL`；双向递归取消；`BoDealEnding` 时禁止取消。
- `ResetDeal`：清 `DealList` 回背包 + 金币回补。
- `IsReservedMakingSlave`：`PrevServerSlaves.Count > 0`（服务器迁移待召唤的随从）。

**未验证**：`EnterGroup`/`DelGroupMember`/`UserCounterDealItemAdd`/`ServerGetDealChangeGold`/`ServerGetDealEnd` 未逐一读；
`GROUPMAX`/`MAXDEALITEM`/`MAX_OVERLAPITEM` 值未查；无运行期验证。

---

## 11. GM 命令表（Round 810，**完整提取**）

> 位置：`ObjBase.pas:23291-24440`（`TUserHuman` 的聊天命令分派链）。
> 机器可读：[`gm-commands.tsv`](gm-commands.tsv)（161 个分派块）。
> 提取器：`Tools/source-read/extract_gm_commands.py` + `gm_to_markdown.py`。

### 11.1 分派机制

GM 命令**不是查表**，而是一条**长 `CompareText` 链**（`ObjBase.pas:23291` 起）：

```pascal
if (CompareText(cmd, 'PositionMove') = 0) or (CompareText(cmd, 'PMove') = 0)
   or (CompareText(cmd, '자유이동') = 0) then begin
   CmdFreeSpaceMove (param1, param2, param3);
   exit;
end;
```

**三个关键点**：

1. **每条命令可有多别名** —— 英文（`PositionMove`/`PMove`）+ 韩文（`자유이동`），
   用 `or` 串联。实测 **131 个英文命令 + 90 个韩文别名**。
2. **`CompareText` 大小写不敏感**。
3. **`exit` 提前返回** —— 顺序敏感，先匹配的先执行。

**命令来自聊天输入**：`cmd` 是聊天文本去掉前导符后的第一个 token，
`param1`/`param2`/`param3` 是后续 token。**与 `@move` 这类原版命令同源。**

### 11.2 命令分组统计


## 移动/传送（13）

| 行 | 英文命令 | 韩文别名 | 动作 |
|---|---|---|---|
| 23460 | — | 이동 | SendRefMsg / SysMsg |
| 23502 | — | 소환거부 / 소환허용 | BoEnableAgitRecall / SysMsg / BoCGHIEnable |
| 23653 | Move | 이동 | CmdFreeSpaceMove |
| 23660 | PositionMove / PMove | 자유이동 | CmdFreeSpaceMove |
| 23693 | Map | 맵 | CmdKickUser |
| 23769 | Recall | 소환 | CmdRecallMan |
| 23774 | RecallMap | 맵소환 | CmdRecallMap |
| 23821 | CharMove | 캐릭터이동 | CmdCharMove |
| 23826 | Goto | 출두 | CmdCharSpaceMove |
| 23907 | RecallMob | — | CmdCallMakeSlaveMonster |
| 23932 | Backstep | — | CmdRushAttack |
| 24124 | AgitMove | 장원이동 | CmdGuildAgitAutoMove |
| 24140 | AgitRecall | 문원소환 | CmdGuildAgitRecall |

## 刷怪/清理（7）

| 行 | 英文命令 | 韩文别名 | 动作 |
|---|---|---|---|
| 23479 | — | 탐색 | SysMsg |
| 23674 | MobLevel | 몹레벨 | CmdSendMonsterLevelInfos |
| 23678 | KingMob | 왕몹 | CmdSendKingMonsterInfos |
| 23682 | MobCount | 몹수 | SysMsg |
| 23903 | Mob | — | CmdCallMakeMonster |
| 23979 | MobPlace | — | CmdCallMakeMonsterXY |
| 24437 | MonClear | 몬클리어 | CmdMonClear |

## 等级/经验/点数（17）

| 行 | 英文命令 | 韩文别名 | 动作 |
|---|---|---|---|
| 23385 | — | 내공 | BoHighLevelEffect / SysMsg |
| 23670 | Info | 렙 | CmdSendUserLevelInfos |
| 23742 | GameMaster | 운영자 | BoSysopMode / SysMsg / BoSuperviserMode |
| 23760 | Level | 레벨조정 | SysMsg |
| 23832 | ContestPoint | — | CmdGetGuildMatchPoint |
| 23871 | PKpoint | — | CmdSendPKPoint |
| 23886 | LuckyPoint | — | SysMsg / BodyLuck / BodyLuckLevel |
| 23944 | IncPkPoint | — | BodyLuck |
| 23953 | Hunger | — | SendMsg |
| 23963 | Training | — | CmdMakeFullSkill |
| 23995 | Level0 | — | — |
| 24255 | AdjustLevel | — | CmdManLevelChange |
| 24259 | AdjustExp | — | CmdManExpChange |
| 24329 | AdjustTestLevel | — | CmdMakeOtherChangeSkillLevel |
| 24334 | OPTraining | — | CmdMakeOtherChangeSkillLevel |
| 24400 | FamePoint | 명성치 | CmdAdjustFamePoint |
| 24404 | FameName | 명성 | CmdGetFameName |

## 物品/装备（17）

| 行 | 英文命令 | 韩文别名 | 动作 |
|---|---|---|---|
| 23911 | — | 복권 | SysMsg |
| 23991 | DeleteItem | — | CmdEraseItem |
| 24197 | Make | — | CmdMakeItem |
| 24216 | — | 무기제련 | CmdRefineWeapon |
| 24245 | ReloadMonItems | — | SysMsg |
| 24285 | AddToItemEvent | — | SysMsg |
| 24293 | AddToItemEventAsPieces | — | SysMsg |
| 24301 | ItemEventList | — | SysMsg |
| 24308 | StartingGiftNo | — | SysMsg |
| 24313 | DeleteAllItemEven | — | SysMsg / BoUniqueItemEvent |
| 24318 | StartItemEvent | — | BoUniqueItemEvent / SysMsg |
| 24324 | ItemEventTerm | — | SysMsg |
| 24341 | ChangeWeaponDura | — | SendMsg |
| 24351 | Upgrade | — | CmdUpgradeItem |
| 24355 | — | 모든보옥 | CmdMakeAllJewelryItem |
| 24359 | — | 모든신주 | CmdMakeAllJewelryItem |
| 24363 | ReloadMakeItemList | — | SendInterMsg / SysMsg |

## 金币（3）

| 行 | 英文命令 | 韩文别名 | 动作 |
|---|---|---|---|
| 23765 | SabukWallGold | — | CmdRecallMan |
| 24201 | DelGold | — | CmdDeleteUserGold |
| 24205 | AddGold | — | CmdAddUserGold |

## 行会/攻城（25）

| 行 | 英文命令 | 韩文别名 | 动作 |
|---|---|---|---|
| 23327 | — | 문파가입 | SysMsg |
| 23333 | — | 동맹허용 | SysMsg |
| 23341 | — | 동맹 | — |
| 23347 | — | 동맹파기 | — |
| 23353 | — | 문파탈퇴 | BoHearGuildMsg / SysMsg |
| 23357 | — | 문파전음차단 / 문파전음거부 | BoHearGuildMsg / SysMsg |
| 23448 | — | 사북성문 | CmdOpenCloseUserCastleMainDoor |
| 23923 | ReloadGuild | — | CmdReloadGuild |
| 24048 | Wallconquestwarmode | — | BoCastleWarMode / SysMsg |
| 24120 | AgitReg | 장원대여 | CmdGuildAgitRegistration |
| 24128 | AgitDel | 장원반환 | CmdGuildAgitDelete |
| 24132 | AgitExtend | 장원연장 | CmdGuildAgitExtendTime |
| 24136 | AgitRemain | 장원기간 | CmdGuildAgitRemainTime |
| 24147 | AgitSale | 장원판매 | CmdGuildAgitSale |
| 24151 | AgitSaleCancel | 장원판매취소 | CmdGuildAgitSaleCancel |
| 24155 | AgitBuy | 장원구입 | CmdGuildAgitBuy |
| 24159 | AgitTrade | 장원거래 | CmdTryGuildAgitTrade |
| 24263 | AddGuild | — | CmdCreateGuild |
| 24267 | DelGuild | — | CmdDeleteGuild |
| 24271 | ChangeSabukLord | — | CmdChangeUserCastleOwner |
| 24275 | ForcedWallconquestWar | — | BoCastleUnderAttack |
| 24392 | AgitDecoMonCount | 꾸미기개수 | CmdAgitDecoMonCount |
| 24396 | AgitDecoMonCountHere | 상현개수 | CmdAgitDecoMonCountHere |
| 24423 | ReloadGuildAll | — | CmdReloadGuildAll |
| 24428 | ReloadGuildAgit | — | CmdReloadGuildAgit |

## 聊天/禁言（15）

| 行 | 英文命令 | 韩文别名 | 动作 |
|---|---|---|---|
| 23298 | — | 귓속말거부 / 귀엣말거부 | BoHearWhisper / SysMsg |
| 23304 | — | 귓속말허용 / 귀엣말허용 | BoHearWhisper / SysMsg / BlockWhisper |
| 23309 | — | 차단 | BlockWhisper / BoHearCry |
| 23315 | — | 외치기거부 / 외치기차단 | BoHearCry / SysMsg / BoExchangeAvailable |
| 23321 | — | 교환거부 | BoExchangeAvailable / SysMsg |
| 23647 | ReloadLineNotice | 줄공지적용 | SysMsg |
| 23709 | Shutup | 채금 | CmdAddShutUpList |
| 23713 | ReleaseShutup | 채금해제 | CmdDelShutUpList |
| 23717 | ShutupList | 채금자 | CmdSendShutUpList |
| 23722 | ReloadChatLog | 채팅로그재적용 | CmdAddChatLogList |
| 23729 | AddChatLog | 채팅로그추가 | CmdAddChatLogList |
| 23733 | ReleaseChatLog | 채팅로그삭제 | CmdDelChatLogList |
| 23737 | ChatLogList | 채팅로그자 | CmdSendChatLogList |
| 23927 | ReadAbuseInformation | — | SysMsg |
| 24112 | — | 외치기범위 | CmdSetCryWide |

## 状态/外观（13）

| 行 | 英文命令 | 韩文别名 | 动作 |
|---|---|---|---|
| 23536 | — | 부활 | — |
| 23564 | MeetCouple | 만남 | — |
| 23610 | HappyBirthDay | 생일축하 | SendRefMsg |
| 23665 | Stealth | 스텔스 | CmdStealth |
| 23748 | Observer / Ob | 감시자 | BoSuperviserMode / SysMsg |
| 23754 | Superman | 무적 | SysMsg |
| 23875 | ChangeJob | — | CmdChangeJob |
| 23881 | ChangeGender | — | CmdChangeSex |
| 23971 | NameColor | — | CmdMissionSetting |
| 23983 | Transparency / tp | — | BoHumHideMode |
| 24372 | — | 글자색 | CmdLetterColor |
| 24377 | Alive | — | — |
| 24415 | — | 연인해제 | CmdBreakLoverRelation |

## 任务（4）

| 行 | 英文命令 | 韩文别名 | 动作 |
|---|---|---|---|
| 23400 | — | 일지 | CmdSendTestQuestDiary |
| 23976 | Mission | — | CmdMissionSetting |
| 24000 | — | 퀘스트초기화 | — |
| 24250 | ReloadDiary | — | CmdManLevelChange |

## GM/管理（19）

| 行 | 英文命令 | 韩文别名 | 动作 |
|---|---|---|---|
| 23291 | admins | — | SysMsg |
| 23370 | — | 추방 | SysMsg |
| 23417 | — | 휴식 | BoSlaveRelax / SysMsg |
| 23433 | gsa | — | SendMsg / SysMsg / BoReadySuperAdminPassword |
| 23697 | Kick | — | CmdKickUser |
| 23701 | Ting | 팅 | CmdTingUser |
| 23705 | SuperTing | 왕팅 | CmdTingRangeUser |
| 23778 | flag | — | SysMsg |
| 23789 | showopen | — | SysMsg |
| 23800 | showunit | — | SysMsg |
| 23813 | addfriend | 친구등록 | SendMsg |
| 23849 | whoare | 누구 | CmdViewAllCharacterList |
| 23852 | safezone | 안전 | SysMsg |
| 23896 | attack | — | CmdCallMakeMonster |
| 24004 | setflag | — | SetQuestMark / SysMsg |
| 24017 | setopen | — | SetQuestOpenIndexMark / SysMsg |
| 24030 | setunit | — | SetQuestFinIndexMark / SysMsg |
| 24222 | ReloadAdmin | — | SendInterMsg / SysMsg |
| 24240 | ReloadNpc | — | CmdReloadNpc |

## 测试/调试（4）

| 行 | 英文命令 | 韩文别名 | 动作 |
|---|---|---|---|
| 23860 | CMDTEST | — | — |
| 24056 | DisableFilter | — | BoEnableAbusiveFilter / SysMsg |
| 24104 | TESTTIME | — | CmdTestTimeDebug |
| 24409 | UserMarketDebug | — | CmdUserMarketDebug |

## 其他（24）

| 行 | 英文命令 | 韩文别名 | 动作 |
|---|---|---|---|
| 23405 | — | 공격방식 | SysMsg |
| 23496 | — | 천지합일거부 / 천지합일허용 | BoEnableRecall / SysMsg / BoEnableAgitRecall |
| 23508 | — | 천지합일 | — |
| 23689 | Human | — | SysMsg |
| 23836 | StartContest | — | CmdStartGuildMatch |
| 23840 | EndContest | — | CmdEndGuildMatch |
| 23844 | Announcement | — | CmdAnnounceGuildMembersMatchPoint |
| 23936 | — | 무태보 | CmdRushAttack |
| 23940 | FreePenalty | — | CmdDeletePKPoint |
| 23948 | ChangeLuck | — | BodyLuck / SendMsg |
| 23967 | DeleteSkill | — | CmdEraseMagic |
| 24043 | Reconnection | — | CmdReconnection |
| 24098 | OXQuizRoom | — | CmdTestTimeDebug |
| 24165 | GaBoardList | 게시판목록 | CmdGaBoardList |
| 24169 | GaBoardRead | 게시판읽기 | — |
| 24173 | GaBoardAdd | 게시판쓰기 | — |
| 24178 | GaBoardDel | 게시판삭제 | — |
| 24182 | GaBoardEdit | 게시판수정 | — |
| 24186 | GTBoardInit | 게시판초기화 | — |
| 24228 | MarketOpen | — | SendInterMsg / SysMsg |
| 24234 | MarketClose | — | CmdReloadNpc |
| 24338 | OPDeleteSkill | — | CmdThisManEraseMagic |
| 24382 | — | 스핵체크 | SysMsg / MainOutMessage |
| 24433 | OneKill | — | CmdOneKillMob |

---

## 12. `ObjNpc.pas` 任务引擎精读（Round 811）

> 6,409 行。前序阶段只读了 `TQuestRecord`/`TNormNpc` 结构（§4.1）。
> 机器可读：[`quest-opcodes.tsv`](quest-opcodes.tsv)（128 条：53 条件 + 75 动作）。
> 提取器：`Tools/source-read/extract_quest_opcodes.py`。

### 12.1 任务数据模型（`ObjNpc.pas:28-90`）—— 五层结构

```pascal
TQuestRequire = record           // :41-45   前置条件（最多 MAXREQUIRE=10 个）
   RandomCount: integer;         //   随机门槛（>0 时 Random(RandomCount) 必须为 0）
   CheckIndex: word;             //   变量索引
   CheckValue: byte;             //   期望值（注释：0, 1）
end;

TQuestConditionInfo = record     // :58-65   脚本条件
   IfIdent: integer;             //   条件 opcode（QI_*）
   IfParam: string;  IfParamVal: integer;
   IfTag:   string;  IfTagVal:   integer;
end;

TQuestActionInfo = record        // :47-55   脚本动作
   ActIdent: integer;            //   动作 opcode（QA_*）
   ActParam: string;  ActParamVal: integer;
   ActTag:   string;  ActTagVal:   integer;
   ActExtra: string;  ActExtraVal: integer;
end;

TSayingProcedure = record        // :67-74   一条「对话分支」
   ConditionList: TList;         //    条件列表（全部满足才走这个分支）
   ActionList: TList;            //    满足时的动作
   Saying: string;               //    满足时说的话
   ElseActionList: TList;        //    不满足时的动作
   ElseSaying: string;           //    不满足时说的话
   AvailableCommands: TStringList;  // 该分支可用的命令
end;

TSayingRecord = record           // :77-80   一个「对话标题」
   Title: string;                //    标题（如 '@main'）
   Procs: TList;                 //    list of PTSayingProcedure
end;
```

**层级关系**：`TNormNpc.Sayings: TList` → `PTSayingRecord`（按 `Title` 索引）
→ `Procs: TList` → `PTSayingProcedure`（条件+动作+文本）。
**`TQuestRecord`（§4.1）再包一层**：`BoRequire` + `QuestRequireArr` + `SayingList`。

→ **四层嵌套：NPC → QuestRecord → SayingRecord → SayingProcedure**。
**「NPC 对话」与「任务」共用同一套数据结构**，区别只在 `BoRequire` 是否为真。

### 12.2 `CheckQuestCondition`（`:757-776`）—— 前置条件判定

```pascal
Result := TRUE;
if pq.BoRequire then begin
   for i := 0 to MAXREQUIRE-1 do begin
      if pq.QuestRequireArr[i].RandomCount > 0 then
         if Random(pq.QuestRequireArr[i].RandomCount) <> 0 then begin
            Result := FALSE; break;         // 随机门槛未过
         end;
      if who.GetQuestMark(pq.QuestRequireArr[i].CheckIndex)
         <> pq.QuestRequireArr[i].CheckValue then begin
         Result := FALSE; break;            // 变量值不匹配
      end;
   end;
end;
```

**两个要点**：
1. **`RandomCount > 0` 时是「概率门槛」** —— `Random(N) = 0` 才通过，
   即通过率 `1/N`。用于随机任务/随机掉落类对话。
2. **`GetQuestMark(CheckIndex)` 查任务变量** —— 与
   `TCreature.QuestIndexOpenStates`/`QuestIndexFinStates`/`QuestStates`
   （`ObjBase.pas:353-355`）对应。

### 12.3 `CheckSayingCondition`（`:837-...`）—— 脚本条件判定（条件 opcode 全表）

逐条 `case pqc.IfIdent of`，**53 个条件 opcode**。核心模式：

```pascal
QI_CHECK:                      // 任务标记（GetQuestMark）
   n := who.GetQuestMark(param);
   if n = 0 then begin if tag <> 0 then Result := FALSE; end
   else            if tag = 0 then Result := FALSE;
QI_CHECKOPENUNIT:  → who.GetQuestOpenIndexMark(param)   // 开启状态
QI_CHECKUNIT:      → who.GetQuestFinIndexMark(param)    // 完成状态
QI_RANDOM:         if Random(pqc.IfParamVal) <> 0 then Result := FALSE;
QI_GENDER:         'MAN' → who.Sex <> 0 则 FALSE
```

**注意三兄弟的区别**（最容易混）：

| opcode | 查询函数 | 语义 |
|---|---|---|
| `QI_CHECK`(1) | `GetQuestMark` | 任务变量（`QuestStates`） |
| `QI_CHECKOPENUNIT`(5) | `GetQuestOpenIndexMark` | **开启**状态（`QuestIndexOpenStates`） |
| `QI_CHECKUNIT`(6) | `GetQuestFinIndexMark` | **完成**状态（`QuestIndexFinStates`） |

**完整条件 opcode 表**（53 个，见 `quest-opcodes.tsv`）分组：

| 组 | opcode | 语义 |
|---|---|---|
| 标记/状态 | `QI_CHECK`(1) `QI_CHECKOPENUNIT`(5) `QI_CHECKUNIT`(6) `QI_IFGETDAILYQUEST`(40) `QI_CHECKDAILYQUEST`(41) | 任务变量与每日任务 |
| 随机 | `QI_RANDOM`(2) `QI_RANDOMEX`(42) | 概率门槛（`RANDOMEX` 支持百分比，注释「5 100 → 5%」） |
| 角色 | `QI_GENDER`(3) `QI_CHECKLEVEL`(7) `QI_CHECKJOB`(8) `QI_ISEXPUSER`(139) | 性别/等级/职业/体验账号 |
| 时间 | `QI_DAYTIME`(4) `QI_DAYOFWEEK`(26) `QI_TIMEHOUR`(27) `QI_TIMEMIN`(28) | 昼夜/星期/时/分 |
| 物品 | `QI_CHECKITEM`(20) `QI_CHECKITEMW`(21) `QI_CHECKGOLD`(22) `QI_ISTAKEITEM`(23) `QI_CHECKDURA`(24) `QI_CHECKDURAEVA`(25) `QI_CHECKBAGGAGE`(34) `QI_CHECKBAGREMAIN`(44) `QI_CHECKGRADEITEM`(50) `QI_CHECKITEMWVALUE`(154) | 持有/装备/金币/耐久/背包容量/物品品质 |
| 怪物 | `QI_CHECKMON_MAP`(31) `QI_CHECKMON_AREA`(32) `QI_CHECKMON_NORECALLMOB_MAP`(43) `QI_CHECKCHILDMOB`(150) | 某地图/区域是否有怪 |
| 数值比较 | `QI_EQUALVAR`(51) `QI_EQUAL`(135) `QI_LARGE`(136) `QI_SMALL`(137) | 变量 `=`/`>`/`<` |
| 社交 | `QI_ISGROUPOWNER`(138) `QI_CHECKLOVERFLAG`(140) `QI_CHECKLOVERRANGE`(141) `QI_CHECKLOVERDAY`(142) `QI_CHECKRANGEONELOVER`(152) `QI_CHECKGROUPJOBBALANCE`(151) | 队长/恋人/组队职业平衡 |
| 声望 | `QI_CHECKFAMEGRADE`(143) `QI_CHECKFAMEPOINT`(144) `QI_CHECKFAMEBASEPOINT`(145) | 声望等级/当前/基础 |
| 行会/攻城 | `QI_CHECKDONATION`(146) `QI_ISGUILDMASTER`(147) | 捐献/会长 |
| 其他 | `QI_CHECKPKPOINT`(29) `QI_CHECKLUCKYPOINT`(30) `QI_CHECKHUM`(33) `QI_CHECKNAMELIST`(35) `QI_CHECKANDDELETENAMELIST`(36) `QI_CHECKANDDELETEIDLIST`(37) `QI_CHECKWEAPONBADLUCK`(148) `QI_CHECKPREMIUMGRADE`(149) `QI_EVENTCHECK`(153) | PK/幸运/人物/名单/武器诅咒/会员/活动 |

> **`QI_CHECKNAMELIST`(35) / `QI_CHECKANDDELETENAMELIST`(36) /
> `QI_CHECKANDDELETEIDLIST`(37)** 三个是「检查名单并在满足时**删除**」——
> 即有**副作用**的条件。做任务脚本分析时要区分纯判定与带副作用的判定。

### 12.4 动作 opcode（75 个，`QA_*`）

见 `quest-opcodes.tsv`。核心几个：

| opcode | 脚本关键字 | 语义 |
|---|---|---|
| `QA_TAKE`(2) | `TAKE` | 收取物品 |
| `QA_GIVE`(3) | `GIVE` | 给予物品 |
| `QA_TAKEW`(4) | `TAKEW` | 收取**已装备**的物品 |
| `QA_CLOSE`(5) | `CLOSE` | 关闭对话窗 |
| `QA_OPENUNIT`(7) | | 开启任务单元 |

### 12.5 `GotoQuest` / `GotoSay`（`:1409-1424`）—— 对话跳转

```pascal
procedure GotoQuest (num: integer);
begin
   for i := 0 to Sayings.Count-1 do
      if PTQuestRecord(Sayings[i]).LocalNumber = num then begin
         PTQuestRecord(TUserHuman(who).CurQuest) := PTQuestRecord(Sayings[i]);
         TUserHuman(who).CurQuestNpc := self;
         NpcSayTitle (who, '@main');
         break;
      end;
end;

procedure GotoSay (saystr: string);  →  NpcSayTitle (who, saystr);
```

**两个跳转方式**：
- `GotoQuest(num)` —— 按 **`LocalNumber`** 跳到某条任务记录，
  并设置 `who.CurQuest` / `who.CurQuestNpc`，然后显示 `'@main'`。
- `GotoSay(title)` —— 按 **`Title` 字符串**跳到某个对话标题。

**`@main` 是硬编码的默认入口标题**（`:1417`）—— 这与
`Mud3-Config/Envir3/QuestDiary/` 脚本里的 `[@main]` 对应。

### 12.6 `TakeItemFromUser`（`:1425-...`）—— 收取物品的完整实现

**金币特判**（`:1433`）：`CompareText(iname, NAME_OF_MONEY) = 0` → `who.DecGold(count)`。

**物品分支**：从 `who.ItemList` **倒序**遍历（`:1449` `downto 0`，
便于边遍历边删除），按 `StdItem.Name` 匹配。

**堆叠物品（`OverlapItem >= 1`）** 用 `pu.Dura` 当**数量**（`:1469-1480`）：
`pu.Dura := pu.Dura - count`，减到 ≤0 则删除物品并发 `SendDelItem`，
否则发 `RM_COUNTERITEMCHANGE`（携带 `MakeIndex`/`Dura`/名称）。

**审计日志**：每次收取都写 `AddUserLog`，格式为
`'10'#9 + 地图 + 坐标 + 用户名 + 物品索引/名 + 数量 + '1'#9 + NPC名`，
注释「판매 와 같이씀」（与出售共用）。**`'10'` 是日志类型码**。

> **对 `Tools/questdata` 的直接意义**：任务奖励/收取的**物品数量语义**是
> 「堆叠物品用 `Dura` 字段计数」，不是独立数量字段 —— 这与 `System.db` 的
> `ItemInfo` 表示可能不同，做映射时必须注意。

### 12.7 与 `Tools/questdata` / EI 证据的对照

| 项 | 源码 | 本仓库现状 | 判定 |
|---|---|---|---|
| 任务条件 | 53 个 `QI_*` opcode | `Tools/questdata` 基于 `QuestInfo` 表 | ⚠️ **需交叉** |
| 任务动作 | 75 个 `QA_*` opcode | 同上 | ⚠️ |
| 脚本关键字 | 116 个有映射（`LocalDB.pas`） | 未对照 | **新增可对照物** |
| 任务入口 | `MapInfo.txt` 的 `CHECKQUEST(<npc>)` | 已在 `config.md` §3.2 记录 | ✅ |
| 对话标题 | `@main` 硬编码默认入口 | — | **新增** |
| 堆叠物品计数 | `Dura` 字段 | — | **新增（易错点）** |
| 有副作用的条件 | `QI_CHECKANDDELETE*`(36/37) | — | **新增** |

**分级**：以上均 `secondary-source`。EI 原版反编译证据里**没有**任务脚本语言的
opcode 表（原版只到「任务窗发 0x418/0x419」这一层），所以这批是
**`source-only` 新增语义**，不能标 `source-corroborated`。

### 12.8 未验证项

| 项 | 原因 |
|---|---|
| `QA_*` 75 个动作的**执行实现** | 只提取了 opcode 表，未逐个读执行分支 |
| `NpcSayTitle` / `NpcSay` / `ChangeNpcSayTag` 实现 | 未读 |
| `CheckNpcSayCommand`（脚本内命令解析） | 未读 —— 与 `Envir3/QuestDiary/` 语法的对照是下一步 |
| `ActivateNpcUtilitys`（商店功能激活） | 只读了签名 |
| `LoadNpcInfos` / `ClearNpcInfos` / `LoadMemorialCount` | 未读 |
| `TMerchant` 的 `RefillGoods` / 价格计算 | 未读 |
| `TUpgradeInfo`（武器炼制）相关实现 | 未读 |
| `MAXREQUIRE=10` 之外的常量（`GUILDWARFEE=60000`、`CASTLEMAINDOORREPAREGOLD=1500000` 等） | 已记录值，未追用法 |

### 12.9 任务脚本语言实证（**源码 ↔ `Envir3/QuestDiary/` 交叉验证**）

**这是本 Goal 最重要的交叉验证之一** —— 用真实任务脚本验证源码提取的 opcode 表。

样本：`Mud3-Config/Envir3/QuestDiary/MU_warrior/mute.txt`（GB18030）

```
[@mugong_mute_explan_mugi]          ← 对话标题（对应 TSayingRecord.Title）
{
#IF                                 ← 条件段开始
check [508] 1                       ← 条件脚本关键字（对应 QI_CHECK）
#SAY                                ← 满足时的文本（对应 Saying）
叫野蛮冲撞的武功请找黄河大侠。。\ \
<结束/@exit>                        ← <显示文本/跳转目标>
#ACT                                ← 动作段
break                               ← 动作脚本关键字
#IF
checklevel 27                       ← 对应 QI_CHECKLEVEL
#SAY
...<谢谢！战士.../@mugong_mute_explan_mugi_next>
```

**验证结果**：

| 源码结构 | 脚本语法 | 判定 |
|---|---|---|
| `TSayingRecord.Title` | `[@mugong_mute_explan_mugi]` | ✅ 吻合 |
| `TSayingProcedure.ConditionList` | `#IF` 段 | ✅ 吻合 |
| `TSayingProcedure.Saying` | `#SAY` 段 | ✅ 吻合 |
| `TSayingProcedure.ActionList` | `#ACT` 段 | ✅ 吻合 |
| `QI_CHECK`(1) | `check [508] 1` | ✅ 吻合（含 `[]` 变量索引语法） |
| `QI_CHECKLEVEL`(7) | `checklevel 27` | ✅ 吻合 |
| `GotoSay(title)` | `<文本/@目标标题>` | ✅ 吻合（`@` 前缀即跳转） |
| `@main` 默认入口 | `[@main]` | ✅ 吻合 |

**新增确认的语法要素**（源码里不直观、脚本里才看清）：

1. **`#IF` / `#SAY` / `#ACT` 三段式** —— 对应
   `ConditionList` / `Saying` / `ActionList`。
   **`#ELSEACT`/`#ELSESAY` 应对应 `ElseActionList`/`ElseSaying`**（样本中未出现，待验）。
2. **条件用 `[]` 表示变量索引**：`check [508] 1` —— 即 `CheckIndex=508`、`CheckValue=1`。
3. **`<显示文本/跳转目标>`** 是超链接语法，`/@xxx` 跳转、`/@exit` 是**退出**。
   → `@exit` 应对应 `QA_CLOSE`(5)（`CLOSE`，关闭对话窗）。
4. **`\` 是换行符**（行尾的 `\ \` 表示空行）。
5. **`break` 动作** —— 中断当前分支。

**结论**：源码提取的 `quest-opcodes.tsv`（53 条件 + 75 动作）
与真实脚本语法**一一对应**。这批 opcode 表可直接用于
解析 `Envir3/QuestDiary/` 的全部脚本树（1,729 个 `.txt`）。

> **对 `Tools/questdata` 的价值**：现在有了「脚本关键字 → opcode」的完整映射
> （116 条，`quest-opcodes.tsv` 的 `keyword` 列），可以写一个
> **QuestDiary 脚本解析器**，与 `System.db` 的 `QuestInfo` 做双向对照 ——
> 这是本仓库此前没有的能力。

---

## 13. `Envir.pas` 剩余方法精读（Round 812）

> 1,540 行。前序阶段读了 `TEnvirnoment` 字段表（§3.1）与 `.map` 格式（§3.2-3.3）。
> 本节读对象注册、移动门、门、地图任务。

### 13.1 移动属性常量（`Grobal2.pas:2090-2092`）

```pascal
MP_CANMOVE  = 0;    // 可走
MP_WALL     = 1;    // 墙
MP_HIGHWALL = 2;    // 高墙（不可走且不可飞）
```

**与 `.map` 的 `chCellBlock` 映射**（`Envir.pas:429-436`）：

| `chCellBlock` | `MoveAttr` | 语义 |
|---|---|---|
| `3` | `0` (MP_CANMOVE) | **可走** |
| `0`, `252` | `1` (MP_WALL) | 墙 |
| `1`, `2`, `254` | `2` (MP_HIGHWALL) | 高墙 |

> ⚠️ **注意映射是「反」的**：`.map` 里的 `3` 才是可走。
> 这与直觉（0 = 空 = 可走）相反，是**做地图工具时最容易搞错的一点**。

### 13.2 `CanWalk`（`:754-787`）—— 移动门

```pascal
if (pm.MoveAttr = MP_CANMOVE) then begin
   Result := TRUE;
   if not allowdup then
      for i := 0 to pm.ObjList.Count-1 do
         if Shape = OS_MOVINGOBJECT then begin
            cret := TCreature(...);
            if (not cret.BoGhost) and
               (cret.HoldPlace) and          // 자리 차지（占位）
               (not cret.Death) and
               (not cret.HideMode) and       // 隐身
               (not cret.BoSuperviserMode)   // 管理员模式
            then begin Result := FALSE; break; end;
         end;
end;
```

**`HoldPlace`（占位）** 是关键字段 —— 只有标记占位的生物才阻挡移动。
**鬼魂 / 死亡 / 隐身 / 管理员模式都不阻挡**。

**`allowdup`** 参数：`TRUE` 时忽略占位（允许重叠）——
`WalkTo`/`RunTo` 调用时传 `FALSE`，某些 NPC 移动传 `TRUE`。

**`CanFireFly`（`:789-803`）**：只检查 `MP_HIGHWALL` ——
**飞行单位可过墙（`MP_WALL`）但不可过高墙**。

### 13.3 `AddToMap`（`:967-1052`）—— 对象注册与堆叠规则

**金币堆叠**（`:988-1008`）：找同格已有的 `OS_ITEMOBJECT` 且 `Name = NAME_OF_GOLD`，
`cnt := pmitem.Count + PTMapItem(obj).Count`，若 `cnt <= BAGGOLD` 则**合并**
（更新 `Count`/`Looks`/`AniCount`/`Reserved`，重置 `ATime`），返回已有对象指针。

**装饰物品（상현주머니）不堆叠**（`:1011-1021`）：`STDMODE_OF_DECOITEM` +
`SHAPE_OF_DECOITEM` 时，同格**已有 1 个就拒绝**。

**普通物品最多 5 个/格**（`:1029`）：`ItemObjCount >= 5` 则 `Result := nil`。

**`TAThing` 包装**（`:1040-1045`）：
```pascal
New(pthing);
pthing.Shape := objtype;      // OS_MOVINGOBJECT / OS_ITEMOBJECT / ...
pthing.AObject := obj;        // 指向真实对象
pthing.ATime := GetTickCount; // 加入地图的时间（用于超时清理）
pm.ObjList.Add(pthing);
```

→ **`PTAThing` 是「地图格上的对象条目」**，`Shape` 区分类型、
`AObject` 指向真实对象、`ATime` 供 `SearchViewRange` 的超时清理用。
**这解释了 §10.2 里「残影 10 分钟 / 物品 1 小时」是怎么实现的** ——
就是 `ATime` 与 `GetTickCount` 的差值。

### 13.4 门（`:1184-1257`）

| 方法 | 行 | 语义 |
|---|---|---|
| `VerifyMapTime` | `:1184` | 校验地图时间 |
| `ApplyDoors` | `:1212` | 应用门状态 |
| `FindDoor(x, y)` | `:1226` | 按坐标找门 |
| `AroundDoorOpened(x, y)` | `:1239` | **检查周围门是否开启**（`Walk` 里用） |

门的核心结构 `PTDoorInfo` / `PTDoorCore`（`LoadMap:448-468` 创建）：
`DoorOpenState` / `Lock` / `LockKey`（注释「비밀 번호가 없음」= 无密码时 0）/
`OpenTime`。**同门合并规则**：坐标差 ≤10 且 `DoorNumber` 相同 → 共享 `pCore`。

### 13.5 `MapQuest` 机制（`:1258-1358`）—— **`MapInfo.txt` 与任务引擎的桥**

**`AddMapQuest(set1, val1, monname, itemname, qfile, enablegroup)`（`:1258`）**：

```pascal
new(mqi);
mqi.SetNumber := set1;
if val1 > 1 then val1 := 1;       // 值被钳制到 0/1
mqi.Value := val1;
if monname = '*' then monname := '';
if itemname = '*' then itemname := '';
if qfile = '*' then qfile := '';
mqi.EnableGroup := enablegroup;

npc := TMerchant.Create;           // ← 创建一个「隐形商人」作为任务载体
npc.MapName := '0';
npc.CX := 0;  npc.CY := 0;
npc.UserName := qfile;             // ← 脚本文件名当 NPC 名
npc.NpcFace := 0;  npc.Appearance := 0;
npc.DefineDirectory := MAPQUESTDIR;
npc.BoInvisible := TRUE;           // ← 不可见
npc.BoUseMapFileName := FALSE;
UserEngine.NpcList.Add(npc);
mqi.QuestNpc := npc;
MapQuestList.Add(mqi);
```

**这是本文件最关键的一段** —— 它解释了 `MapInfo.txt` 的
`CHECKQUEST(<npc>)` 标志（`config.md` §3.2）如何工作：

1. 地图任务被建模为一个**不可见的 `TMerchant` NPC**（`BoInvisible := TRUE`，
   `MapName := '0'` 不在任何真实地图上）。
2. `qfile`（脚本文件名）被存进 `npc.UserName`。
3. `SetNumber`/`Value` 是**进入条件**（对应 `MapInfo.txt` 的
   `NEEDSET_ON`/`NEEDSET_OFF`）。
4. `MonName`/`ItemName` 是**触发条件**（杀某怪 / 交某物）。
5. `EnableGroup` 允许组队共享。

**`GetMapQuest(who, monname, itemname, groupcall)`（`:1302`）**：
遍历 `MapQuestList` 匹配怪物名/物品名，返回对应的任务 NPC。

**`HasMapQuest`（`:1296`）**：`MapQuestList.Count > 0`。

> **对本仓库的意义**：`Tools/questdata` 与 dbeditor 的 `MapRegion`/`QuestInfo`
> 此前不知道「地图任务 = 隐形 NPC」这个建模。**`MAPQUESTDIR` 常量**指向
> 脚本目录，`MapInfo.txt` 的 `CHECKQUEST(名字)` 里的「名字」就是
> **脚本文件名（无扩展名）**。这给了「地图 ↔ 任务」的完整链接路径。

### 13.6 `TEnvirList`（`:1359-1540`）—— 地图集合管理

| 方法 | 行 | 语义 |
|---|---|---|
| `InitEnvirnoments` | `:1369` | 初始化全部地图 |
| `AddEnvir(mapname, title, serverindex, needlevel, ...)` | `:1383` | **新增地图**（参数与 `MapInfo.txt` 行对应） |
| `AddGate(map, x, y, entermap, enterx, entery)` | `:1457` | **新增传送门**（参数与 `MapInfo.txt` 的 `NORECONNECT`/门定义对应） |
| `GetEnvir(mapname)` | `:1484` | 按名取地图 |
| `ServerGetEnvir(server, mapname)` | `:1502` | 按服号+名取地图 |
| `GetServer(mapname)` | `:1521` | 按地图名取服号 |

**`AddEnvir` 的参数列表与 `MapInfo.txt` 行格式一一对应**：
`[地图名 标题 服务器号] 标志...` → `AddEnvir(mapname, title, serverindex, needlevel, ...)`。

### 13.7 未验证项

| 项 | 原因 |
|---|---|
| `GetItemEx` / `GetDupCount` / `MoveToMovingObject` 实现 | 未读 |
| `AddToMapMineEvnet` / `AddToMapTreasure` | 未读（矿区/宝箱专用注册） |
| `DeleteFromMap` | 未读 |
| `ApplyDoors` / `VerifyMapTime` 的门时间逻辑 | 未读 |
| `GetGuildAgitRealMapName` | 未读 |
| `MAPQUESTDIR` 常量值 | 未查 |
| `BAGGOLD` / `STDMODE_OF_DECOITEM` / `SHAPE_OF_DECOITEM` 值 | 未查 |
| `CanFly` / `CanSafeWalk` 的完整分支 | 只读了 `CanFireFly` |

### 13.8 `MapQuest.txt` 格式完整解出（**本轮最重要产出**）

**解析器**：`LocalDB.pas:1454-1517`，`MAPQUESTFILE = 'MapQuest.txt'`（`:34`）。

**格式**（源码逐字段验证）：

```
<地图名>  [<SetNumber>]  <Value>  [<Situation>]  <怪物名>  <物品名>  <qFile>  [<qPosition>]  [GROUP]
```

| 字段 | 源码变量 | 解析方式 | 语义 |
|---|---|---|---|
| 地图名 | `mapstr` | `GetValidStr3` | 所属地图（`GetEnvir` 查表，**不存在则报错**） |
| 条件1 | `constr1` | `ArrestStringEx('[',']')` → `set1` | **`SetNumber`**（对应 `NEEDSET_ON/OFF` 的变量号） |
| 条件2 | `constr2` | `Str_ToInt` → `val1` | **`Value`**（钳制到 0/1，见 §13.5） |
| 情况 | `monname` 前 | `GetValidStrCap` | **`Situation`**：`[Enter]`/`[Leave]`/`[Die]`/`[GetItem]`/`[MonGen]`/`[MonDie]` |
| 怪物名 | `monname` | `GetValidStrCap`（支持 `"引号"`） | 触发怪物（`*` = 任意） |
| 物品名 | `iname` | `GetValidStrCap`（支持 `"引号"`） | 触发物品（`*` = 任意） |
| 脚本 | `qfile` | `GetValidStr3` | **脚本相对路径**（如 `NQ_BASE\MonQuest\Nm_Chiken`） |
| 位置 | — | （源码未单独取，在 `qPosition` 列） | 对话入口标题（实测都是 `[@main]`） |
| 组队 | `gflag` | `CompareLStr(gflag, 'GROUP', 2)` | `GROUP` 前缀 = 组队共享 |

**校验**（`:1491`）：`mapstr`、`monname`、`qfile` **三者都非空**才处理，否则
`Result := -i`（**负值 = 第 i 行出错**，`break` 终止加载）。

**`Situation` 六种取值**（来自文件头注释，`MapQuest.txt` 自带文档）：

| Situation | 触发时机 |
|---|---|
| `[Enter]` | 进入地图 |
| `[Leave]` | 离开地图 |
| `[Die]` | 死亡 |
| `[GetItem]` | 获得物品 |
| `[MonGen]` | 怪物生成 |
| `[MonDie]` | 怪物死亡 |

**实测数据**（`Envir3/MapQuest.txt`，共 100+ 条）：

```
1        [104]    1   [MonDie]  鸡          *   [NQ_BASE\MonQuest\Nm_Chiken]   [@main]
0        [267]    1   [MonDie]  钉耙猫      *   [NQ_BASE\MonQuest\Nm_kalgi]    [@main]
D001_001 [185]    1   [MonDie]  半兽勇士61  *   [NQ_BASE\MonQuest\Nm_OmaWarrior] [@main]
01_001   [0]      0   [Enter]    *           *   [NQ_BASE\MapQuest\Na_JiSun]     [@main]
```

→ **两种典型模式**：
- **`[MonDie]` + 怪物名**：杀指定怪触发任务（如杀 鸡 → `Nm_Chiken`）
- **`[Enter]` + `*`**：进图即触发（如进 `01_001` → `Na_JiSun`）

**脚本文件位置（实测修正）**：`qFile` 是**相对路径**，实测其解析目标是
`Envir3/QuestDiary/` **而非** `MapQuest_def/`：

| 证据 | 内容 |
|---|---|
| `MapQuest.txt` 引用的 `qFile` | `NQ_BASE\MonQuest\Nm_Chiken`、`MU_taoist\MonQuest\holy1`、`Event\SnowBattle\Monquest\SnowMan` |
| 实际存在的文件 | `Envir3/QuestDiary/NQ_BASE/MonQuest/Nm_Chiken.txt` ✅ |
| `Envir/MapQuest_Def/` 内容 | 只有 10 个 `Q1*/Q6*` 文件，**与 `MapQuest.txt` 的引用不匹配** |

→ **`DefineDirectory := MAPQUESTDIR`（`'MapQuest_def\'`）是代码里的默认值，
但实际脚本走 `QuestDiary/` 树**。`MapQuest_def/` 的 10 个 `Q1*/Q6*` 文件
是另一套（早期/备用）地图任务，当前 `MapQuest.txt` 未引用它们。

> ⚠️ **这修正了 §13.5 的表述**：`MapQuest_def\` 常量存在但**不是实际脚本目录**；
> 地图任务脚本与 NPC 对话脚本**共用 `QuestDiary/` 树**（只是子目录不同：
> `MonQuest/` 用于 `[MonDie]` 触发，`MapQuest/` 用于 `[Enter]` 触发）。

**这解释了 §6 的「未破译项」**：`Envir3/QuestDiary/NQ_BASE/MonQuest/` 的
3 个私有编码 `.txt`（`Nm_Chiken`/`Nm_Cow`/`Nm_OmaJunsa`）——
**它们正是 `MapQuest.txt` 里 `[MonDie]` 条目引用的脚本**。
该目录另有可正常读取的 `Nm_1000Doksa.txt`/`Nm_Bubgi.txt`/`Nm_kalgi.txt` 等，
→ **同一目录下「部分文件正常、3 个文件私有编码」**，说明不是目录级问题，
而是**这 3 个文件本身被特殊处理**（可能是某种加密/压缩变体）。
这个对比显著缩小了破译范围。

### 13.9 `LoadStartupQuest`（`:1519-...`）—— 启动任务

```pascal
if not DirectoryExists(EnvirDir + StartupDir) then CreateDir(EnvirDir + StartupDir);
if FileExists(EnvirDir + StartupDir + STARTUPQUESTFILE + '.txt') then begin
   npc := TMerchant.Create;
   npc.MapName := '0';        // ← 同样用隐形 NPC 建模
   ...
```

**与 `MapQuest` 同一套机制**（隐形 `TMerchant` + `MapName := '0'`），
对应 `config.md` 里 `Envir/StartUp/StartupQuest.txt`（**该文件在 `Envir/` 里是空的**，
见 `config.md` §1.1）。

### 13.10 【破译】WEMADE 加密的 3 个任务脚本（**本轮重大突破**）

**此前状态**：`config.md` §7 把 `Envir3/QuestDiary/NQ_BASE/MonQuest/` 的
`Nm_Chiken.txt`/`Nm_Cow.txt`/`Nm_OmaJunsa.txt` 登记为「**未破译的私有编码**」
（「非 GB18030/cp949，字节呈定长对模式」）。

**本轮已破译**：它们是 **WEMADE 加密** —— 即 `Source/Common/EDCode.pas:465-522`
的 `Decrypt(FName)` 函数所用的同一套算法。

#### 13.10.1 破译线索链（过程记录）

1. 文件头 8 字节 = `f0 39 aa c0 5b 93 4a 8d`。
2. **`EDCode.Decrypt` 的硬编码种子是 `CrypToSeed = F0 39 AB 8E`**
   （`:485-488`）—— **前 2 字节 `f0 39` 完全相同**。
3. 按源码 `ProcLen = seed[i] ^ data[i]` 计算，**大端解释得 `334`，
   恰好等于文件大小 342 − 8** ✅ —— 长度字段验证通过。
4. 校验和按源码公式算**不匹配**（`0x9FAEAD34` vs 存储 `0x8D4A935B`），
   但**跳过校验、直接做 4 轮递增 CRC XOR 后，正文完美解密**为合法 GB18030 任务脚本。

#### 13.10.2 算法（`EDCode.pas:465-522` 逐字）

```
CrypToSeed     = F0 39 AB 8E
CrypToSeedLong = 0x9FDE1A93

ProcLen = big-endian( seed[i] ^ data[i] for i in 0..3 )
          ⚠️ 实测是大端。源码用 MakeLong(MakeWord(b3^d3, b2^d2),
             MakeWord(b1^d1, b0^d0)) 的嵌套写法，容易误判为小端。

校验和 = sum( (data[8+i] + 1) * i ) ^ CrypToSeedLong   ，与 data[4..7] 比对

解密 = for j in 0..3:
          crc = data[3 - j]              # 依次取第 4/3/2/1 字节
          for i in 0..ProcLen-1:
              data[8+i] ^= crc & 0xFF
              crc += 1
```

#### 13.10.3 两个必须记住的坑

1. **`ProcLen` 是大端**。源码的 `MakeLong`/`MakeWord` 嵌套写法
   （`MakeLong(MakeWord(a,b), MakeWord(c,d))`）读起来像小端，
   实际按大端解释才得到「文件大小 − 8」这个合理值。
   **判据**：`ProcLen == len(data) - 8`。
2. **校验和字段不可信**。实测 3 个文件的 `data[4..7]` 与源码公式算出的值
   **都不匹配**，但正文仍能正确解密。推测该校验和字段被另一种方式写坏/加密，
   或这份源码的校验公式与加密时用的版本不同。
   → **实用结论：跳过校验和验证，只做 4 轮 XOR。**

#### 13.10.4 解密结果

```
[@main]
;-----------------------------------------------------
#IF
check [164] 1
#ACT
break
#IF
check [104] 1
#ACT
goto @dark
[@dark]
#IF
random 2
#ACT
give 鸡血
```

**完全符合 §12.9 解出的脚本语法**（`[@标题]` / `#IF` / `#ACT` /
`check [n] v` / `goto @x` / `random n` / `give 物品名`）。
→ **三处独立证据交叉一致**：源码 opcode 表 ↔ 明文脚本 ↔ 解密脚本。

#### 13.10.5 扫描结论

`Tools/source-read/wemade_decrypt.py --scan Envir3/QuestDiary`：

```
扫描 443 个文件，识别出 3 个 WEMADE 加密文件
✅ NQ_BASE/MonQuest/Nm_Chiken.txt  (342B)
✅ NQ_BASE/MonQuest/Nm_Cow.txt     (822B)
✅ NQ_BASE/MonQuest/Nm_OmaJunsa.txt(881B)
```

→ **整个 `QuestDiary/` 树只有这 3 个加密文件**，全部已破译。
**「未破译项」从 `config.md` §7 移除。**

#### 13.10.6 工具

`Tools/source-read/wemade_decrypt.py`：

```bash
# 解密单文件
python3 Tools/source-read/wemade_decrypt.py <file> [--out X] [--strict]

# 扫描目录，找出所有 WEMADE 加密文件
python3 Tools/source-read/wemade_decrypt.py --scan Envir3/QuestDiary
```

> **对 `Tools/questdata` 的价值**：现在 `Envir3/QuestDiary/` 的 **443 个脚本
> 全部可读**（440 明文 + 3 解密），结合 §12 的 opcode 表，
> **可以完整解析整个任务脚本树**。

---

## 14. NPC 对话宏系统（Round 821）

> 证据源：`Source/GameServer/ObjNpc.pas` 的 `CheckNpcSayCommand`（`:476-620`）。
> 机器可读：[`npc-say-macros.tsv`](npc-say-macros.tsv)（28 个 `$` 宏）、
> [`quest-macros-coverage.tsv`](quest-macros-coverage.tsv)（脚本↔源码交叉）。
> 提取器：`Tools/source-read/extract_npc_macros.py`、
> `verify_quest_macros.py`。

### 14.1 `$` 宏机制（`CheckNpcSayCommand`，`:476-620`）

```pascal
procedure TNormNpc.CheckNpcSayCommand (hum: TUserHuman; var source: string; tag: string);
begin
   if tag = '$OWNERGUILD' then begin
      data := UserCastle.OwnerGuildName;
      if data = '' then data := 'GameManagerconsultation';
      source := ChangeNpcSayTag (source, '<$OWNERGUILD>', data);
   end;
   if tag = '$USERNAME' then
      source := ChangeNpcSayTag (source, '<$USERNAME>', hum.UserName);
   ...
```

**机制**：脚本里的 `<$NAME>` 占位符在**运行时**被替换为实际值。
`ChangeNpcSayTag(src, orgstr, chstr)`（`:462-474`）是纯字符串替换
（`pos` + `Copy` 拼接）。

**实测提取出 28 个 `$` 宏**（完整表见 `npc-say-macros.tsv`）：

| 组 | 宏 |
|---|---|
| 行会/攻城 | `$OWNERGUILD` `$LORD` `$GUILDWARFEE` `$GUILDWARTIME` `$CASTLEWARDATE` `$LISTOFWAR` `$CASTLEGOLD` `$TODAYINCOME` `$CASTLEDOORSTATE` `$REPAIRDOORGOLD` `$REPAIRWALLGOLD` `$GUARDFEE` `$ARCHERFEE` `$GUARDRULE` |
| 据点 | `$GUILDAGITREGFEE` `$GUILDAGITEXTENDFEE` `$GUILDAGITMAXGOLD` `$AGITGUILDNAME` `$AGITGUILDMASTER` |
| 玩家 | `$USERNAME` `$PKTIME` `$SAVEITEM` `$REMAINSAVEITEM` `$MAXSAVEITEM` `$USERWEAPON` |
| 商店 | `$PRICERATE` `$UPGRADEWEAPONFEE` |
| 其他 | `$MEMORIALCOUNT` |

**注意 `$CASTLEWARDATE`/`$LISTOFWAR` 有硬编码兜底文案**（`:508-515`、`:524-526`），
且分 KOREA/非 KOREA 两版 —— 注释「가까운 시일 안에는 공성전이 없다네」
（近期没有攻城战）。

**`NpcSay`（`:456-460`）**：

```pascal
str := ReplaceChar (str, '\', char($a));        // '\' → 换行
target.SendMsg (self, RM_MERCHANTSAY, 0, 0, 0, 0, UserName + '/' + str);
```

注释「점차 안 쓰임... 하드코딩 하지 않는 것이 좋음」
（**逐渐不用了…最好不要硬编码**）—— 作者自己标注这是**遗留 API**。
消息体格式 `NPC名 + '/' + 文本`，`RM_MERCHANTSAY` 是渲染层消息。

### 14.2 ★ **重大发现：脚本用了 43 个宏，源码只实现 1 个** ★

用 `verify_quest_macros.py` 交叉验证 `Envir3/QuestDiary/`（440 个可读文件）
与整个 `Source/` 树：

```
扫描 QuestDiary 文件: 440
脚本用到的宏（去重）: 43
源码里出现的宏（去重）: 62（其中绝大多数是 C++ 类型名/格式符的误报）

脚本用了但源码里找不到的宏: 42
  {}FCOLOR          1257 次
  {}NPCIMG           373 次
  {}RENTFARE          44 次
  {}FARE              27 次
  {}DESTINATION       26 次
  ...（共 42 个）

脚本用了且源码里有的宏:
  $USERNAME           13 次   GameServer/ObjNpc.pas:531   ← 只有这一个
```

#### 14.2.1 两套宏风格

| 风格 | 例子 | 脚本用量 | 源码实现 |
|---|---|---|---|
| `<$NAME>` | `<$USERNAME>` | 少（4 种） | ✅ 28 个（`CheckNpcSayCommand`） |
| **`{NAME}`** | `{FCOLOR/10}`、`{NPCIMG/5}` | **多（39 种，`FCOLOR` 1257 次）** | ❌ **零实现** |

#### 14.2.2 高频 `{}` 宏（实测）

| 宏 | 次数 | 推断语义 |
|---|---:|---|
| `{FCOLOR/N}` | 1257 | **字体颜色**（N = 颜色索引） |
| `{NPCIMG/N}` | 373 | **NPC 头像/图片**（N = 图号） |
| `{RENTFARE}` | 44 | 租金 |
| `{FARE}` | 27 | 车费 |
| `{DESTINATION}` / `{POSITION}` | 26 / 26 | 目的地 / 位置 |
| `{WEDDING}` / `{WEDDING_TUDI}` | 24 / 22 | 婚礼 |
| `{TIME}` / `{RENTHOUR}` | 23 / 22 | 时间 / 租时 |
| `{GOLD}` | 15 | 金币 |
| `{EVENT}` | 14 | 事件 |
| `{SHIFUNAME}` / `{SHIFU}` | 10 / 8 | 师父（师徒系统） |
| `{TUDINAME}` / `{TUDI}` / `{TRY_TUDI}` / `{START_TUDI}` / `{TIME_TUDI}` / `{INPUTTUDINAME}` | 6-9 | 徒弟（师徒系统） |
| `{MAN}` / `{MANNAME}` / `{GIRL}` / `{GIRLNAME}` / `{INPUTGIRLNAME}` | 4-6 | 男/女（**结婚系统**） |
| `{TRY}` / `{FINISH}` / `{START}` / `{WAITOUT}` / `{WAITINGTIMEOUT}` / `{OPEN}` / `{AI}` | 5-9 | 状态标记 |
| `{ANSWER}` / `{COUNT}` / `{PROB}` / `{TYPE}` / `{ATOM}` | 2-3 | 问答/计数/概率 |
| `{USERCOUNT}` / `{USERNANE}` | 1 / 1 | 用户数（**注意 `USERNANE` 是拼写错误**） |

**`$` 风格里脚本用了但源码没有的 3 个**：
`$GUILD`（4 次，`CastleWar/Flag.txt`：「挑战行会 '<$GUILD>' 行会占领了沙巴克城。」）、
`$INPUTSTR`（1 次，`Refine/...`：刻武器名）、
`$CS_SABUK_OWNER`（1 次，沙巴克城主名）。

#### 14.2.3 结论与边界

1. **`{NAME}` 宏在整份源码里零实现** —— 它们应由**另一个（更新的）服务端构建**
   处理，本版源码不含。
2. **`$GUILD`/`$INPUTSTR`/`$CS_SABUK_OWNER` 同样零实现**。
3. → **本版源码的宏系统是不完整的**（只覆盖 `$` 风格 28 个，
   而脚本实际用到 43 个）。
4. ⚠️ **`verify_quest_macros.py` 的误报**：源码侧「62 个宏」绝大多数是
   **C++ 类型名**（`{_D3DVIEWPORT9}`、`{_D3DMATRIX}` 等来自
   `Plug/MyDirect9/`）与 **Delphi 格式符**（`{%X}`、`{%S}` 等来自
   `Format()` 调用）—— **不是对话宏**。判据应以**脚本侧 43 个**为准。

> **对 `Tools/questdata` 的价值**：做 QuestDiary 脚本解析器时，
> **必须能识别 `{}` 与 `<$>` 两种宏并原样保留**（因为 42 个宏的语义
> 在本源码里查不到），**不能假设宏可解析**。

### 14.3 与 EI 证据 / Zircon 的对照

| 项 | 原版反编译 | 源码 | Zircon |
|---|---|---|---|
| 对话宏 | 未闭合 | `$` 风格 28 个实现 | `NPCPage` 文本处理 |
| `{}` 风格宏 | 未闭合 | **零实现**（在别的构建里） | — |
| `RM_MERCHANTSAY` | 未闭合 | `NpcSay` 用此消息 | — |

**分级**：源码结论均 `secondary-source`；脚本侧统计为 `primary-config`
（直接读真实配置文件）。

### 14.4 未验证项

| 项 | 原因 |
|---|---|
| 42 个未实现宏的**语义** | 源码里零实现，**不能猜** |
| `{FCOLOR/N}` 的 N 值范围与调色板 | 同上 |
| `{NPCIMG/N}` 与 `NPCFace` 字段的关系 | 同上（可能相关但无代码证据） |
| `$GUILD`/`$INPUTSTR`/`$CS_SABUK_OWNER` 的处理位置 | 全仓零命中 |
| `RM_MERCHANTSAY` 的客户端处理 | 未读客户端对应分支 |

---

## 16. `ObjBase.pas` 全量 API 地图（Round 830）

> **31,768 行 —— 全仓最大文件**。接口段 `:305-1411` 声明了
> **3 类 / 526 方法**；`implementation` 从 `:1411` 起。
> 机器可读：[`objbase-methods.tsv`](objbase-methods.tsv)。
> 提取器：`Tools/source-read/extract_objbase_api.py`。

### 16.1 三个类

| 类 | 行 | 方法 | 过程/函数 | 可见性 |
|---|---:|---:|---|---|
| **`TCreature`** | `:305` | **244** | 114 proc / 128 func | public 243 / private 1 |
| **`TAnimal`** | `:944` | 12 | 10 proc / 1 func | public 12 |
| **`TUserHuman`** | `:966` | **270** | 230 proc / 38 func | **private 94** / public 176 |

**`TAnimal` 只有 12 个方法** —— 但**不是薄中间层，而是「怪物 AI 层」**：
`RunMsg`/`Run`/`GetNearMonster`/`MonsterNormalAttack`/`MonsterDetecterAttack`/
`SetTargetXY`/`GotoTargetXY`/`Wondering`（游荡）/`Attack`/`Struck`/`LoseTarget`。

→ **`TCreature` → `TAnimal`（怪物行为）→ `TUserHuman`（玩家）** 三级继承。
玩家**继承自怪物类**（复用 `RunMsg`/`Attack`/`Struck` 骨架，再覆盖）。
「`TAnimal` 方法少」是因为**怪物 AI 主体在 `ObjMon2.pas`/`ObjMon`**，
`ObjBase.pas` 只放基类骨架。

**字段规模**：`TCreature` 约 **290** 字段、`TUserHuman` 约 **88** 字段。

**可见性差异有意义**：`TCreature` 几乎全 public（243/244），
`TUserHuman` 有 **94 个 private** —— **玩家对象封装更严**（防外部误改）。

### 16.2 `TCreature` 方法族（244 个）

| 族 | 代表方法 |
|---|---|
| **消息** | `SendMsg`/`SendFastMsg`/`SendDelayMsg`/`UpdateDelayMsg`/`UpdateMsg`/`GetMsg`/`SendRefMsg` |
| **视野** | `SearchViewRange`/`GetMapCreatures`/**`GetObliqueMapCreatures`**（斜向）/`UpdateVisibleGay`/`UpdateVisibleItems`/`UpdateVisibleEvents` |
| **移动** | `Walk`/`Run`/`Turn`/**`RunTo`**/**`WalkTo`**/`SpaceMove`/`RandomSpaceMove(InRange)`/`EnterAnotherMap`/`UserSpaceMove` |
| **战斗** | `Die`/`Alive`/`SetLastHiter`/`AddPkHiter`/`CheckTimeOutPkHiterList`/`ClearPkHiterList`/**`IsGoodKilling`**/**`SetAllowLongHit`**/**`SetAllowWideHit`**/**`SetAllowFireHit`**/**`SetAllowCrossHit`**/**`SetAllowTwinHit`**/`GetNextHitTime`/`GetNextWalkTime` |
| **状态** | `Feature`/`GetRelFeature`/`GetCharStatus`/`InitValues`/`Initialize`/`Finalize`/`GetMasterRace` |
| **死亡掉落** | `ScatterBagItems`/`DropEventItems`/`ScatterGolds`/`TakeCretBagItems`/`DropUseItems`/`ApplyMeatQuality` |
| **特殊状态** | `MakeGhost`/`MakeHolySeize`/`BreakHolySeize`/**`MakeCrazyMode`**/**`MakeGoodCrazyMode`**/`BreakCrazyMode`/`UseLamp` |
| **装备维护** | `MakeWeaponGoodLock`/`RepaireWeaponNormaly`/`RepaireWeaponPerfect`/`RepairItemNormaly` |
| **移动障碍** | `SetBoInFreePKArea`（**自由 PK 区**标记） |

**五种命中形状**（`SetAllowLongHit`/`Wide`/`Fire`/`Cross`/`Twin`）——
**攻击判定按形状而非单格**，与 `magic.md` §8 的 AoE 骨架对应。

**两种疯狂模式**：`MakeCrazyMode`（普通）vs **`MakeGoodCrazyMode`**（「善」疯狂）
—— 可能是**只打怪不打人**的变体。

### 16.3 `TUserHuman` 方法族（270 个）—— 按协议前缀

**`ServerGet*` = 处理客户端请求**（`ServerGet` 而非 `ClientGet`，
命名是「服务端获取（客户端要的）」）：

| 域 | 方法 |
|---|---|
| **移动** | `TurnXY`/`WalkXY`/`RunXY`/`HitXY`/`SpellXY`/`SitdownXY` |
| **挖矿** | `DigUpMine`/**`GetRandomMineral`**/**`GetRandomMineral3`**/**`GetRandomGems`** |
| **物品** | `ServerGetTakeOnItem`/`TakeOffItem`/`EatItem`/`Butch`/`AddToBagItem`/`DeleteFromBagItem`/`IsFullBagCount` |
| **背包/仓库** | `ServerSendStorageItemList`/`ServerGetUserStorageItem`/`ServerGetTakeBackStorageItem` |
| **商店** | `ServerGetMerchantDlgSelect`/`QuerySellPrice`/`QueryRepairPrice`/`ServerGetUserSellItem`/`ServerGetUserRepairItem`/`ServerGetUserMenuBuy` |
| **制作** | `ServerGetMakeDrug`/`ServerGetMakeItemSel`/`ServerGetMakeItem`/**`IsReservedMakingSlave`**/`RmMakeSlaveProc` |
| **组队** | `ServerGetCreateGroup(Request)`/`ServerGetAddGroupMember(Request)`/`ServerGetDelGroupMember`/`RefreshGroupMembers` |
| **交易** | `ServerGetDealTry`/`DealAddItem`/`DealDelItem`/`DealChangeGold`/`DealEnd`/`ServerGetDealCancel`/`StartDeal`/`BrokeDeal`/`ResetDeal`/`AddDealCounterItem` |
| **行会** | `ServerGetOpenGuildDlg`/`GuildHome`/`GuildMemberList`/`GuildAddMember`/`GuildDelMember`/`GuildUpdateNotice`/`GuildUpdateRanks`/`GuildMakeAlly`/`GuildBreakAlly`/`SendChangeGuildName`/`GuildSecession` |
| **据点** | `ServerGetGuildAgitList`/`GuildAgitTag`/`ExecuteGuildAgitTrade`/`CmdBuyDecoItem`/`SendDecoItemList` |
| **据点公告板** | `ServerGetGaBoardList`/`Read`/`Add`/`Del`/`CmdGaBoardList`/`CmdGaBoardDelAll`/`CmdReloadGaBoardList` |
| **关系（恋人）** | `ServerGetRelationOptionChange`/`Request`/`Delete`/`ServerSetRelationDBWantList`/`Add`/`Edit`/`Delete`/`GetList`/**`ServerGetLoverLogout`**/`RelationShipDeleteOther` |
| **耳语** | `Whisper`/**`LoverWhisper`**/`WhisperRe`/`LoverWhisperRe`/**`BlockWhisper`**/**`IsBlockWhisper`** |
| **玩家市场** | `ServerGetMarketList`/`Sell`/`Buy`/`Cancel`/`GetPay`/`Close` + `Require*UserMarket` 族 + `SellUserMarket`/`BuyUserMarket`/`CancelUserMarket`/`GetPayUserMarket`/`GetMarketData`/`IsEnableUseMarket` |
| **升级/鉴定** | `CmdUpgradeItem`/**`CalcUpgradeProbability`**/`DoUpgradeItem`/`CmdMakeAllJewelryItem`/**`CheckSeedItem`**/**`CheckJewelryItem`**/`SumOfOptions`/`GetTotalValueOfOption`/`UserUnifyItem` |
| **任务** | **`DoStartupQuestNow`**/`CmdSendTestQuestDiary`/`Operate`/`RunNotice`/`GetGetNotices`/`SendLoginNotice`/`ServerGetNoticeOk` |
| **登录/存档** | `ReadySave`/`SendLogon`/`SendAreaState`/`GetStartX`/`GetStartY`/**`CheckHomePos`**/`RequireLoadRefresh`/`SetExpiredTime`/`CheckExpiredTime` |
| **杂项** | `GetQueryUserName`/`ServerGetQueryUserState`/`ServerGetAdjustBonus`/`ServerSendAdjustBonus`/**`CmdLetterColor`**/`SendMyMagics`/`GetMagic`/`GetFameName`/`BindPotionUnit`/**`CmdSendTestQuestDiary`** |

### 16.4 关键发现

**① 玩家市场是独立子系统**（约 25 个方法）——
`ServerGetMarket*`（列表/卖/买/取消/取款/关闭）+ `Require*UserMarket`
（**两套前缀**）+ `GetMarketName`/`GetMarketData`/`IsEnableUseMarket`。

**② `LoverWhisper`（恋人耳语）是独立信道** ——
`Whisper` / `LoverWhisper` 各有 `Re`（回复）版本 →
**恋人关系解锁专用私聊**（对照 §14 `Relationship.pas`）。

**③ 屏蔽耳语**：`BlockWhisper`/`IsBlockWhisper` —— **可屏蔽他人私聊**。

**④ `GetRandomMineral` / `GetRandomMineral3`** ——
**数字后缀 `3`** 暗示版本迭代（`Mineral3` 可能是 Mir3 专用矿），
配合 `GetRandomGems`（宝石）与 `DigUpMine`。

**⑤ 升级有概率计算**：`CalcUpgradeProbability` + `SumOfOptions`/
`GetTotalValueOfOption` → **升级成功率受附加属性影响**。

**⑥ 任务入口只有 `DoStartupQuestNow` 一个** ——
与既有结论一致（`Mission.pas` 是 63 行 stub，真逻辑在 `ObjNpc.pas` 的
`TQuestRecord`）；`CmdSendTestQuestDiary` 是**测试用**命令。

**⑦ 三套「文档/公告」并存**：`RunNotice`/`GetGetNotices`/`SendLoginNotice`
（登录公告）vs `GaBoard*`（据点公告板）vs `TagSystem`（便条，§13）。

### 16.5 未验证项

| 项 | 原因 |
|---|---|
| 526 方法的**实现主体**（`:1411-31768`，约 30,357 行） | **仅读了接口段**；实现是后续重点 |
| `TCreature` 的 290 字段明细 | 未逐字段读 |
| `TAnimal` 各方法的实现（游荡/索敌算法） | 未读（疑在 `ObjMon2.pas`） |
| `ServerGet*` 的 opcode 映射 | 需与 `Grobal2.pas` 对照（部分已在 `verification.md`） |
| `GetRandomMineral3` 的 `3` 语义 | 未追 |
| `MakeGoodCrazyMode` vs `MakeCrazyMode` | 未读实现 |
| `CalcUpgradeProbability` 的公式 | 未读实现 |
| `TUserHuman` 94 个 private 方法名 | 未展开 |

---

## 17. `TUserHuman` 对象内部机制（Round 831）

> `ObjBase.pas` 的 `TUserHuman` 构造/析构与关键实现。

### 8.1 **反作弊 / 防加速体系**（`:17474-17486`）

构造时初始化了一整套**时间监控计数器**：

| 字段 | 语义 |
|---|---|
| `ClientMsgCount` | 客户端消息计数 |
| **`ClientSpeedHackDetect`** | **加速外挂检测标志** |
| `LatestSpellTime` / **`LatestSpellDelay`** | 最近施法时刻 / 延迟 |
| `LatestHitTime` | 最近攻击时刻 |
| `LatestWalkTime` | 最近行走时刻 |
| `LatestDropTime` | 最近丢物时刻 |
| `HitTimeOverCount` / `HitTimeOverSum` | **攻击间隔超限次数/累计** |
| `SpellTimeOverCount` | **施法间隔超限次数** |
| `WalkTimeOverCount` / `WalkTimeOverSum` | **行走间隔超限次数/累计** |
| `SpeedHackTimerOverCount` | **加速计时器超限次数** |

**四类操作（攻击/施法/行走/丢物）各自计时**，超限**累计**（`*Sum`）而非直接踢。
另：`PriviousCheckCode` / **`CrackWanrningLevel`**（原文拼写 `Wanrning`）
—— 注释「패킷 duplication같은 장난을 치는지 여부..」
（**是否在玩包重放之类的花样**）。

### 8.2 **广播炸弹防护**（`:17492-17496`）

```pascal
LatestSayStr := '';
BombSayCount := 0;
BombSayTime := GetTickCount;
BoShutUpMouse := FALSE;      // 鼠标禁言
ShutUpMouseTime := GetTickCount;
```

`BombSayCount`（喊话炸弹计数）+ **`BoShutUpMouse`（鼠标禁言）** ——
**高频重复喊话会被禁言**。

### 8.3 **存档节流（2003-08-08 改动）**（`:17442-17445`）

```pascal
// 2003-08-08 :PDS
// 사람이 몰릴때 대비 저장시간을 5분간격으로 랜덤 조정한다.
// 처음접속한 사람은 15분까지 저장타임이 늘어날수 있다. 그후에는 10분에 한번씩 저장
LastSaveTime := GetTickCount + LongWord( Random( 5 * 60 * 1000 ) );
```

**⏱ 带日期的改动记录**：为应对拥挤，**存档时间按 5 分钟间隔随机打散**；
**首次连接可延长到 15 分钟**，此后**每 10 分钟存一次**。
→ **存档是随机抖动 + 分级频率**，避免全服同时落盘。

### 8.4 关键运行参数（`:17458-17462`）

| 参数 | 值 | 语义 |
|---|---:|---|
| `RunTime` | `GetCurrentTime` | 运行基准 |
| **`RunNextTick`** | **250** | **逻辑帧间隔（ms）** |
| **`SearchRate`** | **1000** | **视野搜索周期（ms）** |
| **`ViewRange`** | **12** | **视野半径（格）** |

→ **每 250ms 跑一次逻辑、每 1000ms 搜一次视野、视野 12 格**。

### 8.5 跨服与延迟机制（`:17489-17507`）

- **`// 2003/06/12 슬레이브 패치`**（**从属补丁**）+
  `PrevServerSlaves: TList`（「서버 이동하면서 옮겨다니는 부하」=
  **随服务器迁移的从属物**）→ **宠物/召唤物的跨服携带**。
- `BoChangeServer` / `BoChangeServerNeedDelay` / `WriteChangeServerInfoCount`
  → **换服需要延迟**（防抖）。
- `FirstClientTime` / `FirstServerTime` → **客户端/服务端时钟对表**（用于测速）。

### 8.6 子系统装配（`:17513-17526`）

```pascal
fLover := TRelationShipMgr.Create;   // 연인 사제  ← 恋人
//   fMaster := TRelationShipMgr.Create;   ← 师傅（被注释）
FUserMarket := TMarketItemManager.Create;;   // 玩家市场（注意双分号）
```

**⚠️「师徒系统」被注释掉** —— 只保留了**恋人**（`fMaster`/`fMaster.Free` 均注释）。
→ 印证 §14：`MAX_LOVERCOUNT = 1`，**关系系统只实现了恋人，师徒未启用**。

`GetUserMassCount`（`:17550-17553`）：`GetAreaUserCount(PEnvir, CX, CY, 10)`
→ **以自身为中心 10 格内的玩家人数**（用于拥挤判定/经验分配？）。

### 8.7 `ResetCharForRevival`（`:17555-17559`）—— 复活状态重置

```pascal
FillChar (StatusArr, sizeof(word)*STATUSARR_SIZE, #0);
FillChar (StatusValue, sizeof(byte)*STATUSARR_SIZE, #0);  //상태 리셋 추가(sonmg 2005/06/03)
```

**⏱ 带日期/人名的改动**：**`sonmg` 于 2005/06/03 追加了 `StatusValue` 重置** ——
说明 `StatusArr`（word）与 `StatusValue`（byte）是**两套并行状态数组**，
早期只重置前者，是 bug 后补。

### 8.8 `CheckHomePos`（`:26399-26422`）—— 回城点判定

```pascal
for i:=0 to StartPoints.Count-1 do begin
   if PEnvir.MapName = GetStartPointMapName(i) then begin
      if (Abs(CX - Loword(integer(StartPoints.Objects[i]))) < 50) and
         (Abs(CY - Hiword(integer(StartPoints.Objects[i]))) < 50) then begin
         HomeMap := ...; HomeX := Loword(...); HomeY := Hiword(...);
      end;
   end;
end;
if PKLevel >= 2 then begin  //빨갱이는 빨갱이 마을로
   HomeMap := BADMANHOMEMAP; HomeX := BADMANSTARTX; HomeY := BADMANSTARTY;
end;
```

**两个机制**：
1. **回城点 = 出生点 50 格内**（`< 50`），坐标**打包进一个 integer**
   （`Loword`=X / `Hiword`=Y）—— **Mir2 经典的坐标打包技巧**。
2. **红名（PK）强制改回城点**：`PKLevel >= 2` →
   `BADMANHOMEMAP = '3'`（`:52`）、`BADMANSTARTX = 845`、`BADMANSTARTY = 674`（`:53-54`）。
   注释「**빨갱이는 빨갱이 마을로**」= **红名回红名村**。

**`PKLevel` 阈值全集**（全文件唯一值）：`= 1`、`< 2`、`<= 2`、`>= 2`、`< 3`、`>= 3`
→ **三档 PK 等级**，**2 是红名分界**、3 是更高档。

另 `:4528` 注释：「**빨간색은 1/3확률로 떨어진다**」（红名 1/3 概率掉落）——
`if PKLevel < 2 then boDropall := FALSE;` → **红名死亡掉全部物品的 1/3 概率**。

### 8.9 `GetQueryUserName`（`:26427-26440`）—— 名字+称号

```pascal
uname := target.GetUserName + '/' + TUserHuman(target).GetFameName(FameGrade);
```

**名字与称号用 `/` 拼接一起发**（注释「명성호칭 붙여서 보냄」= 附上声望称号发送）
→ **称号是名字的一部分**（对照 `GetFameName`）。
`CretInNearXY` 失败则回 `SM_GHOST`。

### 8.10 `ServerSendAdjustBonus`（`:26443-26457`）—— **三职业分支**

```pascal
case Job of
   0: str := EncodeBuffer(@WarriorBonus, ...) + '/' + EncodeBuffer(@CurBonusAbil, ...) + '/' + ...;
   1: str := EncodeBuffer(@WizzardBonus, ...) + ...
   2: str := EncodeBuffer(@PriestBonus, ...)  + ...
end;
```

**职业映射**：`0 = Warrior`（战士）/ `1 = Wizzard`（原文**双 z** 拼写，法师）/
`2 = Priest`（道士/祭司）。

**三个 `TNakedAbility` 结构体**：职业加成 + 当前加成 + 奖励加成，
用 `/` 分隔、`EncodeBuffer` 编码。`EncodeBuffer` 即**加密传输**。

### 8.11 未验证项

| 项 | 原因 |
|---|---|
| `ClientSpeedHackDetect` 的触发阈值与处置 | 未读（阈值判定在别处） |
| `CrackWanrningLevel` 的升级与封号逻辑 | 未读 |
| `BombSayCount` 的限流阈值 | 未读 |
| `StatusArr` vs `StatusValue` 的语义分工 | 未读（只见到双数组） |
| `TNakedAbility` 结构字段 | 未读 |
| `GetFameName` 的称号分级表 | 未读 |
| `RunNextTick`/`SearchRate`/`ViewRange` 是否被运行时覆盖 | 未读 |

---

## 18. **NPC 脚本语言全表**（`LocalDB.pas` 解析器 + `Grobal2.pas` 常量）（Round 833）

> 解析器：`LocalDB.pas` 的 `DecodeConditionStr`（`:1742`）/ `DecodeActionStr`（`:1859`）；
> 常量：`Grobal2.pas:2445-2599`。
> 机器可读：[`npc-script-commands.tsv`](npc-script-commands.tsv)（128 行）。
> 提取器：`Tools/source-read/extract_npc_script.py`。

### 18.1 **128 条命令**（53 条件 + 75 动作）

| | 数量 | 值域 | 重复值 | 空缺值 |
|---|---:|---|---|---|
| **`QI_*`（条件）** | **53** | **1..154** | **无** | **101 个** |
| **`QA_*`（动作）** | **75** | **1..133** | **无** | **59 个** |

**⚠️ 关键观察**：
1. **无重复值** —— 与协议 opcode（§`verification.md`，474 常量有 31 个跨前缀重复）
   **形成鲜明对比** → **脚本命令空间是干净的**。
2. **大量空缺值** —— `QI_` 在 1..154 里只用了 53 个（**空缺 101 个**），
   `QA_` 在 1..133 里只用了 75 个（**空缺 59 个**）。
   → **ID 空间预留了 2-3 倍，实际命令数远少于设计容量**，
   说明有**被删除或从未发布的命令**。

### 18.2 条件命令（53 个）

**基础判定**：`CHECK`（含 `[101]` 形式）/ `RANDOM` / `RANDOMEX` /
`GENDER` / `DAYTIME` / `DAYOFWEEK` / `HOUR` / `MIN`

**角色属性**：`CHECKLEVEL` / `CHECKJOB` / `CHECKGOLD` / `CHECKPKPOINT` /
`CHECKLUCKYPOINT` / `CHECKWEAPONBADLUCK` / `CHECKPREMIUMGRADE` /
`CHECKFAMEGRADE` / `CHECKFAMEPOINT` / `CHECKFAMEBASEPOINT` / `CHECKDONATION`

**物品**：`CHECKITEM` / `CHECKITEMW` / `CHECKITEMWVALUE` / `ISTAKEITEM` /
`CHECKDURA` / `CHECKDURAEVA` / `CHECKGRADEITEM` / `CHECKBAGREMAIN` /
`CHECKBAGGAGE`

**地图/怪物**：`CHECKMONMAP` / **`CHECKMONMAPNORECALL`** / `CHECKMONAREA` /
`CHECKCHILDMOB` / `CHECKHUM` / `CHECKUNIT`

**名单**：`CHECKNAMELIST` / **`CHECK_DELETE_NAMELIST`** / **`CHECK_DELETE_IDLIST`**

**组队/行会**：`ISGROUPOWNER` / **`CHECKGROUPJOBBALANCE`**（队伍职业平衡）/
`ISGUILDMASTER`

**任务**：`CHECKDAILYQUEST` / `IFGETDAILYQUEST`

**关系（恋人）**：`CHECKLOVERFLAG` / `CHECKLOVERRANGE` / `CHECKLOVERDAY` /
**`CHECKRANGEONELOVER`**

**比较**：`EQUAL` / `EQUALVAR` / `LARGE` / `SMALL`

**其他**：`CHECKOPEN` / `ISEXPUSER` / `EVENTCHECK`

**✅ 两种书写形式（非笔误）**：`CHECKLOVERFLAG` 有**两条** `if` 分支 ——
`:1760` 是**带参数形式**（解析 `[xxx]`，非法则 `ident := 0`），
`:1822` 是**裸形式**（`then ident := QI_CHECKLOVERFLAG;`）。
→ **同一个关键字支持「带参数」与「不带参数」两种写法**，后者是简写。
> 而 §14 已确认 `{NAME}` 类宏 42/43 未实现 —— **脚本命令与文本宏是两套东西**：
> **命令有 128 个真实现，宏几乎全无**。

### 18.3 动作命令（75 个）

**变量**：`SET` / `RESET` / `MOV` / `INC` / `DEC` / `SUM` / **`MOVR`**（随机移动？）

**物品**：`TAKE` / `GIVE` / `TAKEW` / `TAKECHECKITEM` / `TAKEGRADEITEM` /
**`UNIFYITEM`**（统一物品）

**传送**：`MAPMOVE` / `MAP` / `MOVEALLMAP` / `MOVEALLMAPGROUP` /
`EXCHANGEMAP` / `RECALLMAP` / `RECALLMAPGROUP` / `GOTO`

**定时召回**：`TIMERECALL` / **`TIMERECALLGROUP`** / `BREAKTIMERECALL`

**怪物**：`MONGEN` / **`MONGENAROUND`** / `MONCLEAR` / **`RECALLMOB`**

**批量**：`ADDBATCH` / `BATCHDELAY` / `BATCHMOVE` / `ADDNAMELIST` / `DELNAMELIST`

**赌博/随机**：`PLAYDICE`（掷骰）/ **`PLAYROCK`**（猜拳？）/ `RANDOMSETDAILYQUEST`

**任务**：`SETDAILYQUEST` / `GOQUEST` / `ENDQUEST`

**PK/武器**：`INCPKPOINT` / `DECPKPOINT` / `WEAPONUPGRADE` / `DECWEAPONBADLUCK` /
`DECDONATION` / `USEFAMEPOINT`

**恋人**：`SETLOVERFLAG`（**出现两次**）/ `MOVETOLOVER` / `BREAKLOVER` / `GIVETOLOVER`

**纪念**：`INCMEMORIALCOUNT` / `DECMEMORIALCOUNT` / `SAVEMEMORIALCOUNT`

**增益**：**`INSTANTPOWERUP`** / **`INSTANTEXPDOUBLE`** / `HEALING` / `GIVEEXP`

**地图/单位**：`SETALLINMAP` / `SETUNIT` / `RESETUNIT` / `SETOPEN`

**界面/音效**：`CLOSE` / `CLOSENOINVEN` / `SOUND` / `SOUNDALL` / `SHOWEFFECT`

**其他**：`KICK` / `CHANGEGENDER` / `GUILDSECESSION` / `PARAM1`~`PARAM4`

**✅ 同理 `SETLOVERFLAG`**：`:1878` 带参数形式 + `:1976` 裸形式
（`then ident := QA_SETLOVERFLAG;`）—— 同样是**双写法**。

**⚠️ 常量已定义、解析器未实现**：`Grobal2.pas` 有
**`QA_MISSION = 132`**（注释「맵에 설치」= 地图上设置）/ **`QA_MOBPLACE = 133`**
（注释「맵에 배치」= 地图上放置），
但**解析器里搜不到 `MISSION`/`MOBPLACE` 关键字**（已核实为空）
→ **两条命令的常量已分配，脚本解析器不支持**。

### 18.4 脚本结构（`ObjNpc.pas` 四级嵌套）

```
TQuestRecord                     ← 一个 NPC 的对话段
├── BoRequire: Boolean           ← 요구조건이 있는지 (无则走默认对话)
├── LocalNumber: integer
├── QuestRequireArr[0..MAXREQUIRE-1]  ← MAXREQUIRE = 10 (ObjNpc.pas:20)
└── SayingList: TList            ← list of PTSayingRecord
    └── TSayingRecord
        ├── Title: string
        └── Procs: TList         ← list of PTSayingProcedure
            └── TSayingProcedure
                ├── ConditionList: TList   ← PTQuestConditionInfo
                ├── ActionList: TList      ← PTQuestActionInfo（#ACT）
                ├── Saying: string
                ├── ElseActionList: TList  ← #ELSEACT
                ├── ElseSaying: string     ← #ELSESAY
                └── AvailableCommands: TStringList
```

**`TQuestConditionInfo`**（`:58-64`）：
`IfIdent: integer` / `IfParam: string` / `IfParamVal: integer` /
`IfTag: string` / `IfTagVal: integer`
→ **每个条件最多 2 个参数（各带字符串+整数双表示）**。

**`TQuestActionInfo`**（`:47-55`）：
`ActIdent` / `ActParam` / `ActParamVal` / `ActTag` / `ActTagVal` /
**`ActExtra`** / **`ActExtraVal`**
→ **动作比条件多一组参数（3 组 vs 2 组）**。

**四段式脚本**：`#IF`（条件）→ `#SAY`（说）→ `#ACT`（做）→
**`#ELSEACT`/`#ELSESAY`**（否则分支）—— **条件不满足时走 else 分支**，
这是**完整的 if-else 结构**。

**`AvailableCommands`**（`:73`）：由 `AddAvailableCommands`（`:1713-1727`）
用 `ArrestStringEx(str, '@', '>', capture)` **从说辞里扫出所有 `@xxx>` 命令**
→ **NPC 对话里的 `@链接` 是自动提取的**，用于生成菜单。

**⚠️ 内存管理注释**（`ObjNpc.pas:351`）：
「PTQuestRecord 는 반드시 Free하지 않음 (원에 해제함)」
（**PTQuestRecord 故意不 Free，统一释放**）—— 配合 `ClearNpcInfos`（`:2604`）
四级嵌套全 `Dispose`。

**脚本文件命名**（`ObjNpc.pas:2639-2649`）：
```pascal
if BoUseMapFileName then
   FrmDB.LoadNpcDef (self, DefineDirectory, UserName + '-' + MapName)
else
   FrmDB.LoadNpcDef (self, DefineDirectory, UserName);
```
**`BoUseMapFileName`（`:99` 注释「파일이름에 '-D001'처럼 맵이름이 따라 붙는지」）**
→ **同一个 NPC 可为每张地图配不同脚本**（`NPC名-地图名`）。

### 18.5 与 EI 证据 / Zircon 的对照

| 项 | 原版反编译 | 源码 | 说明 |
|---|---|---|---|
| 脚本命令数 | 未闭合 | **128**（53+75） | **首个完整清单** |
| 命令 ID 空间 | — | QI 1..154 / QA 1..133 | **无重复，大量空缺** |
| 脚本结构 | 未闭合 | **四级嵌套 + 四段式** | if-else 完整 |
| 文本宏 | `{NAME}` 42/43 未实现 | 命令 128 个真实现 | **两套机制，勿混** |
| `@链接` 菜单 | 未闭合 | `AddAvailableCommands` 自动扫 | — |

### 18.6 未验证项

| 项 | 原因 |
|---|---|
| `QI_*`/`QA_*` 各值的**具体语义** | 只提取了值与注释（部分注释为韩文） |
| `QA_MISSION`/`QA_MOBPLACE` 是否真的无解析 | 未逐条核对解析器（已见常量存在） |
| `QA_MISSION`/`QA_MOBPLACE` 的实现位置 | 解析器无关键字；疑在别处或废弃 |
| `MOVR` / `PLAYROCK` 的语义 | 未读实现 |
| `MAXREQUIRE = 10` 之外的任务上限 | 未读 |
| `CheckQuestCondition`（`:757`）的求值实现 | 未读 |
| 脚本文件的**实际目录与文件名格式** | 未核（`NPCDEFDIR` 常量未追） |
