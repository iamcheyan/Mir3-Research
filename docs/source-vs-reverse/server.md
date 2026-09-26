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
>>> m = MR.indep_parse('/home/tetsuya/mir2ei/Map/0.map')
>>> m.w, m.h, m.n, m.n_records
(800, 800, 640000, 640000)          # 完整
>>> m = MR.indep_parse('/home/tetsuya/mir2ei/Map/0_002.map')
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

## 5. 待办

| 项 | 说明 |
|---|---|
| `ObjBase.pas` 主体（31,768 行） | 本阶段只读了类声明与字段，方法实现未读 |
| `ObjNpc.pas` 任务引擎 | 只读了 `TQuestRecord`/`TNormNpc` 结构，`CheckQuestCondition`/`GotoQuest` 实现未读 |
| `TQuestRequire` 结构 | 未读（任务前置条件的字段定义） |
| `Magic.pas` 技能计算 | 未读 |
| `ObjMon*.pas`（8,111 行） | 未读 |
| 怪物 AI / 寻路 | 未读（`_Oranze Library/astar.h` 有 A* 实现） |
| `CmdMgr.pas` GM 命令表（629 行） | 未读 —— 可与原版 `@move` 等命令对照 |
| `svMain.pas` 启动流程与 `EnvirDir` | 部分读过（`:619`），完整启动链未读 |
| 服务端是否读 `Envir3/` | README 称 grep 命中 0 次；本阶段未独立复验 |

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
for p in ('/home/tetsuya/mir2ei/Map/0.map','/home/tetsuya/mir2ei/Map/0_002.map'):
    m = MR.indep_parse(p)
    print(p.split('/')[-1], m.w, m.h, m.n, m.n_records)
"
```
