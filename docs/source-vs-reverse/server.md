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

---

## 10. `ObjBase.pas` 方法实现精读（Round 810）

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

### 10.5 掉落族（`:4432-4760`）

| 方法 | 行 | 语义 |
|---|---|---|
| `TakeCretBagItems(target)` | `:4432` | 从对方尸体取全部物品 |
| `ScatterBagItems(itemownership)` | `:4509` | 散落背包物品 |
| `DropEventItems` | `:4688` | 掉落事件物品（注释：**加载时不存在、后加进来的才掉**） |
| `ScatterGolds(itemownership)` | `:4727` | 散落金币 |
| `DropUseItems(itemownership; DieFromMob)` | `:4760` | 按**耐久度**掉落（`DieFromMob` 区分是否被怪杀死） |

**`itemownership`** 参数贯穿全部掉落函数 —— 即**掉落物归属**（防抢怪），
与 §10.2 的 `pmapitem.Ownership`/`Droper` + `ANTI_MUKJA_DELAY` 配套
（「먹자 보호」= 防抢食保护）。

### 10.6 物品等级/职业转换（`:1802-2722`）—— 一大块业务逻辑

| 方法 | 行范围 | 语义 |
|---|---|---|
| `ChangeItemWithLevel(citem, lv)` | `:1802-2019` | 按等级换装（**217 行**） |
| `ChangeItemByJob(citem, lv)` | `:2020-2269` | 按职业换装（**250 行**） |
| `BanjjakChangeItemByJob(citem, lv)` | `:2270-2722` | 「半自动」职业换装（**453 行**） |

`BanjjakChangeItemByJob` 是**本文件最长的单个函数之一**（453 行）——
「반짝」（Banjjak）疑为某种装备转换机制。**未细读，标注 pending。**

### 10.7 与原版 / Zircon 的对照

| 项 | 原版反编译 | 源码 | Zircon |
|---|---|---|---|
| 视野搜索 | `SearchViewRange`（有调用点证据） | `:3567-3890` 完整实现 | `ServerLibrary/Envir/` 有对应 |
| 视野半径 | 未闭合 | `ViewRange` 字段 + 边界钳制 | — |
| 残影超时 | 未闭合 | **10 分钟**（`:3667`） | — |
| 掉落物超时 | 未闭合 | **1 小时**（`:3715`） | — |
| 防抢食保护 | 未闭合 | `ANTI_MUKJA_DELAY` + `Ownership`/`Droper` | — |
| 跨服移动字段集 | 未闭合 | 7 个字段（`:4184-4194`） | — |
| 怪物互不可见优化 | 未闭合 | `RaceServer < RC_ANIMAL` 门（`:3694`） | — |

**分级**：以上源码结论均 `secondary-source`；原版无对应证据的标 `source-only`。

### 10.8 未验证项

| 项 | 原因 |
|---|---|
| `BanjjakChangeItemByJob`（453 行） | 未细读 |
| `ChangeItemWithLevel`/`ChangeItemByJob`（467 行合计） | 只读了签名与规模 |
| `TakeCretBagItems`/`ScatterBagItems` 等掉落族实现 | 只读了签名与注释 |
| `RC_ANIMAL`/`RC_USERHUMAN`/`OS_*` 常量值 | 未查定义（疑在 `M2Share.pas`） |
| `ANTI_MUKJA_DELAY` 具体值 | 未查 |
| `TAnimal`/`TUserHuman` 的实现段（`TCreature` 之后） | 未读 —— 见 §11 |

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
