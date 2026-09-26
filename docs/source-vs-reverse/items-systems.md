# Preview 物品与玩法系统（itmunit + Guild/Castle/Tag/Relationship/Event）

> 证据源：`Source/GameServer/{itmunit,Guild,Castle,TagSystem,Relationship,Event,
> DragonSystem,UserSystem}.pas`。证据等级 `secondary-source`。

---

## 1. `itmunit.pas`（897 行）—— 装备升级与攻速

`TItemUnit = class`（`:10`）—— 物品工具类（全局单例）。

### 1.1 升级成功率：**两个公式**

**`GetUpgrade(count, ran)`（`:44-53`）—— 连乘式**

```pascal
for i := 0 to count-1 do begin
   if Random(ran) = 0 then Result := Result + 1
   else break;                       // ← 一旦失败立即中断
end;
```

**连乘语义**：连续成功 `count` 次的概率是 `(1/ran)^count`。
`Result` 是**实际连成次数**（0..count）。

**`GetUpgrade2(x, a)`（`:55-90`）—— 分段概率曲线**

```pascal
for i := x downto 1 do begin
   if i > x div 2 then
      iProb := Trunc((Sqrt(Power(a,2) - Power(i,2)) / (a*i + Power(i,2))) * 100)   // 低概率段
   else
      iProb := Trunc((Sqrt(1 - (Power(i,2)/Power(a,2))) * 100) / sqrt(i));          // 高概率段
   if Random(100) < iProb then begin
      Result := i div 3;             // ← 返回值是 i/3，不是 i
      break;
   end;
end;
```

**注意 `i > x div 2` 是分段点** —— 前一半（高 `i`）用**低概率**公式，
后一半用**高概率**公式。返回 `i div 3`。

**`GetUpgrade2` 里有两段被注释掉的旧公式**（`:61-62`、`:77-89`），
旧版用 `Sqrt(10000 - Power(x+a,2)) / (100 + Power(x,2))` —— 常量 10000 暗示
**假设 x+a ≤ 100**。说明升级概率公式**被改过至少两版**。

### 1.2 攻速模型（**有符号/无符号编码，最易搞错**）

```pascal
// 无符号 → 有符号（真实攻速，范围 -10..15）
function RealAttackSpeed(wAtkSpd: WORD): integer;
begin
   if wAtkSpd <= 10 then Result := -wAtkSpd        // 0..10  → 0..-10
   else                   Result := wAtkSpd - 10;  // 11..25 → 1..15
end;

// 有符号 → 无符号
function NaturalAttackSpeed(iAtkSpd: integer): WORD;
begin
   if iAtkSpd <= 0 then Result := -iAtkSpd         // 0..-10 → 0..10
   else                  Result := iAtkSpd + 10;   // 1..15  → 11..25
end;
```

**编码方案**（注释明确「-10~15」）：

| 存储值（无符号） | 真实攻速 |
|---:|---:|
| `0` | `0` |
| `1..10` | `-1..-10` |
| `11..25` | `1..15` |

即 **`10` 是零点**，`0..10` 表示负值、`11..25` 表示正值。
**`0` 和 `10` 都映射到「0 攻速」** —— 这是一个有损映射。

**`GetAttackSpeed(std, user)`（`:876-883`）**：
两者都转成有符号后**相加**，再转回无符号。
**`UpgradeAttackSpeed(user, upValue)`（`:887-894`）**：
`RealAttackSpeed(user) + iUpValue` 再转回。

**实测消费点（证明该编码是真实生效的）**：

| 位置 | 用途 |
|---|---|
| `itmunit.pas:592` | `std.MAC := MAKEWORD(LOBYTE(std.MAC), GetAttackSpeed(HIBYTE(std.MAC), ui.Desc[6]))` —— **攻速存在 `MAC` 的高字节**，用户升级值在 `Desc[6]` |
| `ObjBase.pas:9344` | `aabil.HitSpeed := aabil.HitSpeed + ItemMan.RealAttackSpeed(HIBYTE(std.MAC))` |
| `ObjBase.pas:20520` | `Result + _MAX(0, ItemMan.RealAttackSpeed(puSeedItem.Desc[6]))` —— **带 `_MAX(0,·)` 钳制** |
| `ObjBase.pas:21228-21229` | `iBaseValue := RealAttackSpeed(HIBYTE(pstd.MAC))`；`iUpgradeValue := RealAttackSpeed(pu.Desc[6])` |

→ **`HIBYTE(std.MAC)` = 物品基础攻速**、**`Desc[6]` = 用户升级攻速**，
两者都经 `RealAttackSpeed` 转有符号后相加。

> ⚠️ **做攻速相关工具时的硬约束**：`WAbil.AttackSpeed`/`std.MAC` 高字节/`Desc[6]`
> 都是**无符号存储**但**语义有符号**。直接比较或相加会出错，
> **必须先 `RealAttackSpeed`**。

### 1.3 装备升级的属性映射

`UpgradeRandomWeapon/Dress/Necklace/Barcelet/Necklace19/Rings/Rings23/Helmet`
（`:94-...`）—— **按装备类型分别随机加属性**。

关键注释（`:93`）：**「TUserItem 的 Desc 的升级映射 0:DC 1:MC 2:SC」**
即 `Desc[0..2]` = 破坏/魔法/道术 三种攻击属性。

`Desc[5]` = 需求（注释「필요(렙,파괴,마법,도력)」= 需要（等级/破坏/魔法/道术）），
`Desc[12]` = 敏捷（`:800`）。

**`GetUpgradeStdItem(ui, std)`（`:28`）**：把 `TUserItem` 的 `Desc[]` 数组
叠加到 `TStdItem` 上，得到**实际生效的物品属性**。
→ **这是「基础物品 + 升级加成」的合成点**。

---

## 2. `Guild.pas`（3,600 行）—— 行会

6 个类：`TGuild`（`:60`）/ `TGuildManager`（`:121`）/ `TGuildAgit`（`:139`）+ 3 个辅助。

**`TGuildAgit`（行会据点）** 与 `Envir.pas` 的 `GuildAgit` 地图标志
（`config.md` §3.2 的 `GUILDAGIT(<num>)`）配套。
`ObjNpc.pas:12` 的 `GUILDWARFEE = 60000` 是行会战费用。

---

## 3. `Castle.pas`（1,241 行）—— 攻城

**1 个类**：`TUserCastle`（`:45`）。
配置：`CASTLEFILENAME = 'Sabuk.txt'`（`:12/15`）、
`CASTLEATTACERS = 'AttackSabukWall.txt'`（`:18`）。
`LoadFromFile`（`:171`）/ `SaveToFile`（`:304`，注释「공성전 신청서를 저장한다」= 保存攻城申请书）。

**费用常量**（`ObjNpc.pas:14-17`）：

| 常量 | 值 | 语义 |
|---|---:|---|
| `CASTLEMAINDOORREPAREGOLD` | 1500000 | 主门修理费（注释显示原为 2000000） |
| `CASTLECOREWALLREPAREGOLD` | 400000 | 核心墙修理费（原 500000） |
| `CASTLEARCHEREMPLOYFEE` | 250000 | 雇佣弓箭手费（原 300000） |
| `CASTLEGUARDEMPLOYFEE` | 250000 | 雇佣守卫费（原 300000） |

**注意注释里保留了旧值** —— 说明**费用被下调过**，是版本演进痕迹。

---

## 4. `TagSystem.pas`（1,678 行）—— 标签/便签系统

2 个类：`TTagInfo`（`:17`）/ `TTagMgr`（`:45`），**都继承 `ICommand`**
（`CmdMgr.pas` 的命令接口）。

对应协议常量：`CM_TAG_ADD`/`CM_TAG_DELETE`/`CM_TAG_SETINFO`/`CM_TAG_LIST`/
`CM_TAG_NOTREADCOUNT`/`CM_TAG_REJECT_*`（`protocol.md` §3）。

**`CM_TAG_NOTREADCOUNT`** —— 「未读便签数」是独立消息（用于 UI 角标）。

---

## 5. `Relationship.pas`（471 行）—— 关系系统

2 个类：`TRelationShipInfo`（`:12`）/ `TRelationShipMgr`（`:44`）。

对应 `CM_LM_REQUEST`/`CM_LM_OPTION`/`CM_LM_DELETE`/`CM_LM_DELETE_REQ_OK/FAIL`
（`protocol.md` §3，`LM` = Love/Marriage？）。

与 `ObjBase.pas` 的 `MeetLoverDelayTime`（`//연인 만남 딜레이`= 恋人见面延迟，
sonmg 2005/09/01）、`CmdLoverCharSpaceMove`/`CmdBreakLoverRelation` 配套。

**任务条件里的 `QI_CHECKLOVERFLAG`(140)/`QI_CHECKLOVERRANGE`(141)/
`QI_CHECKLOVERDAY`(142)/`QI_CHECKRANGEONELOVER`(152)**
（`server.md` §12.3）正是查询这套关系数据。

---

## 6. `Event.pas`（323 行）—— 地图事件

6 个类，`TEvent`（`:11`）为基类：

| 类 | 行 | 语义 |
|---|---|---|
| `TEvent` | `:11` | 基类 |
| `TStoneMineEvent` | `:41` | 石矿 |
| `TPileStones` | `:52` | 石堆（注释「돌무더기(점 흡입)」= 石堆（点吸收）） |
| `THolyCurtainEvent` | `:58` | 圣幕 |

**事件类型常量**（`Grobal2.pas:2387-2395`）：

| 常量 | 值 | 语义 |
|---|---:|---|
| `ET_DIGOUTZOMBI` | 1 | 破土僵尸洞（注释「좀비가 땅속에 나오는 흔적」） |
| `ET_MINE` | 2 | 矿点（注释「광석이 매장되어 있음」= 埋有矿石） |
| `ET_PILESTONES` | 3 | 石堆 |
| `ET_HOLYCURTAIN` | 4 | 圣幕（계계 = 结界） |
| `ET_FIRE` | 5 | 火 |
| `ET_SCULPEICE` | 6 | 雕像碎片（注释「지역봉인의 돌기둥 조각」= 区域封印石柱碎片） |
| `ET_HEARTPALP` | 7 | 心跳（注释「현교인 오행(신수)병의 심수 고공」） |
| `ET_JUMAPEICE` | 9 | 주마편碎片（注释「지역봉인 马편 조각」） |

> ⚠️ **`ET_` 前缀在 `Grobal2.pas` 里被复用于多个命名空间**（实测）：
> - **事件类型**：`ET_DIGOUTZOMBI=1` … `ET_JUMAPEICE=9`（**序号跳过 8**，不要假设连续）
> - **拍卖行消息**：`ET_LIST=1068/828/11015`、`ET_SELL=1069`、`ET_BUY=1070`、
>   `ET_CANCEL=1071`、`ET_GETPAY=1072`、`ET_CLOSE=1073`、`ET_RESULT=829/11016`
> - **拍卖行分类**：`ET_TYPE_ALL=0`、`ET_TYPE_WEAPON=1` … `ET_TYPE_ETC=15`、
>   `ET_TYPE_ITEMNAME=16`、`ET_TYPE_SET=100`、`ET_TYPE_MINE=200`、`ET_TYPE_OTHER=300`
> - **拍卖行状态**：`ET_MODE_NULL=0`/`ET_MODE_BUY=1`/`ET_MODE_INQUIRY=2`/`ET_MODE_SELL=3`
> - **拍卖结果码**：`ET_CHECKTYPE_SELLOK=1` … `ET_CHECKTYPE_GETPAYFAIL=8`
> - **DB 侧类型**：`ET_DBSELLTYPE_SELL=1` … `ET_DBSELLTYPE_DELETE=20`
>
> → **`ET_` 不是「事件类型」的专属前缀**。按名字前缀判断语义会出错 ——
> 必须结合所在文件的上下文。**这是做常量索引时的又一个陷阱。**
>
> 另注意 `ET_TYPE_*` 与 `USERMARKET_TYPE_*`（§8）**是两套并存的分类**：
> `ET_TYPE_ARMOR=9`/`ET_TYPE_BELT=7`/`ET_TYPE_SHOES=8`/`ET_TYPE_BOOK=12` 等
> 比 `USERMARKET_TYPE_*`（只有 7 类）更细。

**`ET_DIGOUTZOMBI` 与地图标志联动**：`Envir.pas:4172` 的
`NeedHole` 地图要求 `EventMan.FindEvent(PEnvir, CX, CY, ET_DIGOUTZOMBI) <> nil`
才能过门（`server.md` §10.3）—— **这是「洞」机制的实现**。

---

## 7. `DragonSystem.pas`（604 行）—— 龙系统

`TDragonSystem = class(TObject)`（`:39`）单例。
配置 `DRAGONITEMFILE = 'DragonItem.txt'`（`:13`），
状态机式命令流格式（`config.md` §14.12）。
`svMain.pas:1167` 的 `gFireDragon.Initialize(...)` 是初始化入口。

---

## 8. 拍卖行（UserMarket）类型常量

`Grobal2.pas:2715-2721`：

| 常量 | 值 | 语义 |
|---|---:|---|
| `USERMARKET_TYPE_ALL` | 0 | 全部 |
| `USERMARKET_TYPE_WEAPON` | 1 | 武器 |
| `USERMARKET_TYPE_NECKLACE` | 2 | 项链 |
| `USERMARKET_TYPE_RING` | 3 | 戒指 |
| `USERMARKET_TYPE_BRACELET` | 4 | 手镯 |
| `USERMARKET_TYPE_CHARM` | 5 | 护身符 |
| `USERMARKET_TYPE_HELMET` | 6 | 头盔 |

对应 `CM_MARKET_LIST/SELL/BUY/CANCEL/GETPAY/CLOSE`（`Grobal2.pas:1775-1780`）
与 `SM_MARKET_LIST/RESULT`（`:1607-1608`）。
**注意 `RM_MARKET_*`（`:2011-2012`，值 11015/11016）是另一套前缀**
（`RM_` = Render Message？用于服务端→客户端的渲染层）。

---

## 9. 与 EI 证据 / Zircon 的对照

| 项 | 原版反编译 | 源码 | Zircon |
|---|---|---|---|
| 装备升级 | 未闭合 | `GetUpgrade`/`GetUpgrade2` 两公式 | `ItemInfo`/`UpgradeInfo` |
| 攻速编码 | 未闭合 | **有符号/无符号零点 10 的编码** | — |
| 属性叠加 | 未闭合 | `GetUpgradeStdItem`（`Desc[]` → `TStdItem`） | — |
| 攻城费用 | 未闭合 | 4 个常量（含旧值注释） | — |
| 事件类型 | 未闭合 | 8 个 `ET_*`（**跳过 8**） | — |
| 拍卖行分类 | 未闭合 | 7 个 `USERMARKET_TYPE_*` | — |

**分级**：源码结论均 `secondary-source`；原版无对应证据的标 `source-only`。

---

## 10. 未验证项

| 项 | 原因 |
|---|---|
| `Guild.pas`（3,600 行）实现主体 | 只读了类清单 |
| `Castle.pas`（1,241 行）实现主体 | 只读了常量与文件定位 |
| `TagSystem.pas`（1,678 行）实现主体 | 只读了类清单 |
| `Relationship.pas` 实现主体 | 只读了类清单 |
| `Event.pas` 各事件类的实现 | 只读了类清单与类型常量 |
| `DragonSystem.pas` 除 `DecodeStrInfo` 外的实现 | 只读了格式解析 |
| `UserSystem.pas`（153 行） | 未读 |
| `itmunit.pas` 的 8 个 `UpgradeRandom*` 实现 | 只读了签名与 `Desc[]` 映射 |
| `RealAttackSpeed` 的**实际影响**（攻速如何转成延迟） | 未追到消费点 |
