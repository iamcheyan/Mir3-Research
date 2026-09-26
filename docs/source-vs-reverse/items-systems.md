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

---

## 11. `Guild.pas` 实现精读（Round 827）

> 3,600 行。前序阶段只读了类清单（§2）。本节读常量与数据模型。

### 11.1 常量全表（`:10-27`）

| 常量 | 值 | 语义 |
|---|---:|---|
| **`DEFRANK`** | **99** | **行会最低等级** |
| `GUILDAGIT_DAYUNIT` | 7 | 据点周期（**7 天**） |
| `GUILDAGIT_SALEWAIT_DAYUNIT` | 1 | 出售等待（**1 天**） |
| `MAXGUILDAGITCOUNT` | 100 | 最大据点号 |
| `GABOARD_NOTICE_LINE` | 3 | 公告行数 |
| `GABOARD_COUNT_PER_PAGE` | 10 | 每页行数 |
| `GABOARD_MAX_ARTICLE_COUNT` | **73** | **最大文章数**（非整数倍，是硬上限） |
| `AGITDECOMONFILE` | `'AgitDecoMon.txt'` | **据点装饰清单文件** |
| `MAXCOUNT_DECOMON_PER_AGIT` | 50 | 每据点最大装饰数 |
| **`GUILDAGITMAXGOLD`** | **100,000,000** | **据点金额上限（1 亿）** |
| **`GUILDAGITREGFEE`** | **10,000,000** | **据点注册费（1000 万）** |
| `GUILDAGITEXTENDFEE` | 1,000,000 | 据点续期费（100 万） |
| **`GUILDWARTIME`** | **6** | **行会战时间单位**（注释「문파전 시간 단위」） |

> ⚠️ **`AGITDECOMONFILE = 'AgitDecoMon.txt'` 是本源码里唯一提到但
> `Mud3-Config/` 里没有的配置文件** —— 待核（可能在运行目录）。
>
> 这些常量正是 `server.md` §14.1 的 `$` 宏 `$GUILDAGITREGFEE`/
> `$GUILDAGITEXTENDFEE`/`$GUILDAGITMAXGOLD`/`$GUILDWARFEE`/`$GUILDWARTIME`
> 的数据源 —— **宏系统与常量的对应关系闭合**。

### 11.2 `TGuild` 数据模型（`:60-118`）

```pascal
TGuild = class
   GuildName: string;
   NoticeList: TStringList;       // 公告
   KillGuilds: TStringList;       // 敌对行会
   AllyGuilds: TStringList;       // 同盟行会
   MemberList: TList;             // list of PTGuildRank
   MatchPoint: integer;           //문파대전때의 점수（行会战得分）
   BoStartGuildFight: Boolean;
   FightMemberList: TStringList;  //문파대전시 우리편 리스트（行会战时我方名单）
   AllowAllyGuild: Boolean;       //동맹 허용 여부（是否允许同盟）
end;
```

**四个字符串列表 + 两个成员列表**：
`NoticeList`（公告）/`KillGuilds`（敌对）/`AllyGuilds`（同盟）/`FightMemberList`（战时报方）。

### 11.3 职位与行会战机制（注释原文）

| 方法 | 行 | 注释/语义 |
|---|---|---|
| `AddGuildMaster` | `:87` | 「처음에 문파 생성될때만 사용」（**仅创建行会时用**） |
| `DelGuildMaster` | `:88` | 「마지막 문주나가면 문파 깨짐」（**最后一个会长退出则行会解散**） |
| `BreakGuild` | `:89` | 「강제로 문파가 없어짐. (주의)」（**强制解散，注意**） |
| **`DeclareGuildWar`** | `:99-100` | 「상대방 문파와 문파쌈을 건다. **3시간동안 유효, 아무때나 할 수 있다.**」 |
| **`MakeAllyGuild`** | `:104-105` | 「상대방 문파와 동맹을 결성한다. **문주끼리 서로 마주보며 할 수 있다.**」 |

**两个关键业务规则**：
1. **行会战有效期 3 小时**（`DeclareGuildWar` 注释），且**随时可宣战**。
2. **同盟需要双方会长面对面**（「문주끼리 서로 마주보며」）——
   即**有距离/朝向约束**（不是纯命令）。

### 11.4 行会战（TeamFight）方法族（`:111-115`）

`TeamFightStart` / `TeamFightEnd` / `TeamFightAdd(whostr)` /
`TeamFightWhoWinPoint(whostr, point)` / `TeamFightWhoDead(whostr)`

→ **按玩家名记分**（`MatchPoint`），有死亡记录。

### 11.5 持久化（`:77-82`）

`LoadGuild` / `LoadGuildFile(flname)` / **`BackupGuild(flname)`** /
`SaveGuild` / `GuildInfoChange` / `CheckSave`

**`CheckSave`（`:484`）+ `guildsavetime`/`dosave` 字段** ——
**延迟保存机制**（改动标记 `dosave`，定期 `CheckSave` 落盘），
避免每次改动都写盘。

**`TGuildManager`（`:121-`）**：`GuildList: TList` +
`LoadGuildList`/`SaveGuildList`/`GetGuild(gname)`/
**`GetGuildFromMemberName(who)`**（按成员名反查行会）/`AddGuild(gname, mastername)`。

### 11.6 与 EI 证据 / Zircon 的对照

| 项 | 原版反编译 | 源码 | Zircon |
|---|---|---|---|
| 行会数据 | 未闭合 | `TGuild` 4 列表 + 2 成员列表 | `GuildInfo` |
| 行会战 | 未闭合 | 3 小时有效期 + `MatchPoint` | — |
| 同盟 | 未闭合 | 需双方会长面对面 | — |
| 据点 | 未闭合 | 7 天周期 / 1000 万注册费 / 1 亿上限 | — |
| `$` 宏数据源 | — | ✅ 已闭合（§11.1） | — |

**分级**：源码结论均 `secondary-source`。

### 11.7 未验证项

| 项 | 原因 |
|---|---|
| `TGuild` 各方法实现主体 | 只读了声明与常量 |
| `PTGuildRank` 结构（成员记录） | 未读 |
| `TGuildAgit`（`:139`）实现 | 未读 |
| `DeclareGuildWar` 的 3 小时判定实现 | 未读（注释已给语义） |
| `MakeAllyGuild` 的「面对面」判定 | 未读 |
| `AgitDecoMon.txt` 是否存在 | 未核（`Mud3-Config/` 里没找到） |

---

## 12. `Castle.pas` —— 沙巴克（사북성）攻城系统（Round 829）

> 1,241 行。机器可读见 §12.6。

### 12.1 常量（`:10-26`）

| 常量 | 值 | 语义 |
|---|---|---|
| **`CASTLEFILENAME`** | `'Sabuk.txt'` | **城堡存档**（注意文件名是 **Sabuk** 拼音，非 `Castle`） |
| `CASTLENAMEDEF` | `'SabukWall'`（非韩国版）/ `'哥굇냘'`（韩国版） | 城堡默认名 |
| **`CASTLEATTACERS`** | `'AttackSabukWall.txt'` | **攻方列表存档**（注意原文拼写 `ATTACERS`，少一个 `K`） |
| **`CASTLEMAXGOLD`** | **100,000,000** | 城堡金库上限（1 亿） |
| **`TODAYGOLD`** | **5,000,000** | **当日税收上限（500 万）** |
| `COREDOORX` / `COREDOORY` | 631 / 274 | 内城核心坐标 |
| `MAXARCHER` | 12 | 弓箭手上限 |
| `MAXGUARD` | 4 | 卫兵上限 |

**`Sabuk`（沙巴克）** 是 Mir 系列传统攻城城的名字 —— 本源码沿用 Mir2 命名。
`CASTLECOREMAP`/`CASTLEBASEMAP` **被注释掉**（`:21-22`），改用 `COREDOORX/Y`。

### 12.2 **税收规则（`PayTax` `:790-829`）**

```pascal
// 2003/07/15 사북 세금 상향 조절 0.05 -> 0.10
tax := Round (goodsprice * 0.1);  //세금은 5%로 조정   0.05
```

**⏱ 带日期的改动记录**：**2003/07/15 把税率从 5% 上调到 10%**。
（注释里「세금은 5%로 조정」是**过时残留**，与代码 `* 0.1` 矛盾 —— 以代码为准。）

**双重封顶**：
1. `TodayIncome + tax <= TODAYGOLD`（当日 500 万）；超限则 `tax` 被截断到剩余额度，
   已满则为 0。
2. `int64(TotalGold) + tax <= CASTLEMAXGOLD`（1 亿）；超限则**直接置为上限**。

**每 10 分钟自动存档**（`:813`）并写 `AddUserLog('23'...)` 审计日志
（`'autosave'`/`'Autosaving'` 随 `KOREA` 条件切换）。

### 12.3 **攻城战时序（`Run` `:517-620`，每 10 秒一次）**

| 项 | 值 | 出处 |
|---|---|---|
| **每日检查时刻** | **20:00**（`ahour := 20`「오후8시」） | `:547`,`:553` |
| 检查标志 | `BoCastleWarChecked`（**一天只检查一次** `:554` 注释「한번만 검사함」） | `:543`,`:554` |
| **攻城持续** | **3 小时** | `:615` |
| **结束前警告** | **10 分钟**（`BoCastleWarTimeOut10min`） | `:615-618` |
| 战场判定范围 | `abs(CastleStartX-x) < 100` 且 `abs(CastleStartY-y) < 100` | `:1084` |
| 战场中心 | `CastleStartX=644`, `CastleStartY=290`, `CastleMap='3'` | `:141-143` |

**`IsCastleWarArea`（`:1080-1090`）**：**距中心 ±100 格的矩形**即战场。
**`CorePEnvir`/`BasementEnvir`（内城/地下室）的判定被注释掉**（`:1087-1089`）——
**只保留了城堡主地图**。

**`StartCastleWar`（`:1061-1074`）**：取中心 100 格内所有玩家调 `UserNameChanged`
（注释掉的 `ChangeNameColor`）→ **开战即刷新名字颜色**（敌我识别）。

### 12.4 防御单位与攻守模型（`:29-80`）

```pascal
TDefenseUnit = record
   X, Y: integer;  UnitName: string;
   BoDoorOpen: Boolean;   //TCastleDoor 인 경우
   HP: integer;
   UnitObj: TCreature;    //TWallStructure or TSolder
end;
```

**固定布防**：`MainDoor`（城门）+ `LeftWall`/`CenterWall`/`RightWall`（三面墙）
+ `Guards[0..3]`（4 卫兵）+ `Archers[0..11]`（12 弓箭手）。

**攻方模型**：`AttackerList`（**申请攻城的行会**）/ `RushGuildList`（**正在攻城的行会**）
—— **申请与实战分离**。
`ProposeCastleWar`/`IsAttackGuild`/`GetNextWarDateTimeStr`/`GetListOfWars`
→ **申请制**，有「下一次攻城时间」与列表查询。

**金库操作**（`:105-106`）返回码注释（`:832-835`）：
`-1` 非城主 / `-2` 钱不够 / `-3` 携带超重 / `1` 成功。

**⚠️ 多服共享注释（`:135-136`）**：
「사북성의 저장은 사북성이 있는 서버에서만 저장되고 다른 서버에서는 읽기만 한다.」
→ **城堡存档只在拥有城堡的服务器写，其他服务器只读** —— **跨服只读同步**。

### 12.5 与 `Guild.pas` 的关系

`Castle` **依赖** `Guild`（`uses ... Guild, ...` `:8`）：`OwnerGuild: TGuild`、
`IsOurCastle(g: TGuild)`、`IsRushCastleGuild(aguild)`、
`IsRushAllyCastleGuild(aguild)` → **行会同盟关系直接决定攻城中的敌我**。

> 对照 §11：行会战（`GUILDWARTIME = 6`）与城堡战（**3 小时**）是**两套独立机制**，
> 时间单位不同。

### 12.6 未验证项

| 项 | 原因 |
|---|---|
| `SaveToFile`/`LoadFromFile`（`Sabuk.txt` 格式） | 未读 |
| `AttackerList` 存档格式 | 未读 |
| `CheckCastleWarWinCondition`（胜负判定） | 未读 |
| `ChangeCastleOwner`/`FinishCastleWar` 实现 | 未读 |
| `RepairCastleDoor`/`RepairCoreCastleWall` | 未读 |
| 韩国版城堡名 `'哥굇냘'` 的编码 | 疑混入 GB18030 |

---

## 13. `TagSystem.pas` —— 游戏内**邮件（쪽지）系统**（Round 829）

> 1,678 行。**这不是「标签系统」而是「短信/便条系统」** —— 韩文 쪽지 = 便条/短信。

### 13.1 常量（`:9-13`）

| 常量 | 值 | 语义 |
|---|---:|---|
| **`MAX_TAG_COUNT`** | **30** | **最多便条数**（「최대 쪽지 개수」） |
| **`MAX_TAG_PAGE_COUNT`** | **10** | **每页便条数**（「페이지당 쪽지 개수」） |
| **`MAX_REJECTER_COUNT`** | **20** | **最多拒收人数**（「최대 거부자 수」） |

### 13.2 `TTagInfo`（`:17-41`）—— 单条便条

`FSender`（전송자 发件人）/ `FSendDate`（전송날짜，**同时是主键**，
`GenerateSendDate` 生成）/ `FMsg`（전송 내용）/ `FState` / `FDBSaved` / `FClient`。

**`FState` 四态（注释原文 `:22`）**：
`읽지않음(0)` 未读 / `읽음(1)` 已读 / **`삭제불가(2)` 不可删除** / `삭제됨(3)` 已删除。

→ **状态 2「不可删除」** —— 说明存在**系统发的、玩家不能删的便条**（如 GM 通知/系统公告）。

**双持久化标记**：`FDBSaved`（DB 存否）+ `FClient`（已发客户端否）——
**DB 与客户端两条投递路径独立跟踪**。

### 13.3 `TTagMgr`（`:45-`）—— 管理器

**四个「握手」标志位**（客户端拉取模式）：

| 标志 | 语义 |
|---|---|
| `FIsTagListSendAble` | 便条列表**是否已备好**可发 |
| `FWantTagListFlag` | **客户端想拉列表** |
| `FWantTagListPage` | 客户端要**第几页** |
| `FClientGetList` | 客户端**已持有**列表 |
| `FIsRejectListSendAble` | 拒收列表备好否 |
| `FWantRejectListFlag` | 客户端想拉拒收列表 |

→ **典型的分页拉取协议**（服务端标记就绪 → 客户端请求页 → 服务端发页）。

**方法**：`OnUserOpen`/`OnUserClose`、`GenerateSendDate`（生成便条号）、
`GetTagCount`、`IsTagAddAble`、`Find(SendDate)`、`Add`/`Delete`/`SetInfo`/
`RemoveInfo(Date)`、`FNotReadCount`（未读数，用于 UI 红点）。

**存储**：`FItems: TList`（注释显示**原为 `TElHashList`**）/ `FRejecter: TStringList`。
→ **哈希表被换成线性 TList**（`:47-48` 注释 `//TElHashList`），
与 `Guild.pas` 用 `TStringList` 同类的**简化痕迹**。

### 13.4 未验证项

| 项 | 原因 |
|---|---|
| `Add`/`Delete`/`SetInfo` 实现主体 | 只读声明与常量 |
| 便条是否跨服/离线投递 | 未读 |
| `GenerateSendDate` 的编号算法 | 未读 |
| 与 DB 的读写路径 | 未读 |

---

## 14. `Relationship.pas` —— 恋人/关系系统（Round 829）

> 471 行。**`MAX_LOVERCOUNT = 1`（`:9`）** —— **每人最多 1 个恋人**。

**`TRelationShipInfo`（`:12-41`）**：`Ownner`（소유자 拥有者）/
`Name`（등록자 登记者）/ **`State`(BYTE) 注册状态** / `Level`(BYTE) 等级 /
**`Sex`(BYTE) 性别** / `Date`（등록날짜）/ `ServerDate`（서버날짜）/
`MapInfo`（맵정보）。

**⚠️ 字段用 `BYTE` 而非 `integer`** —— 与 `TTagInfo` 的 `Integer` 不同，
说明这套结构**面向紧凑序列化**（可能是 SQL 表列类型驱动）。

**`MapInfo` 字段**：记录**注册时的地图信息** —— 关系可能**绑定地点**。

**未验证**：`Ownner` 的拼写（原文**双 n**，非 `Owner`）；`State` 取值；
`GetNowDate` 格式；关系是否双向；471 行里的其余类。

---

## 15. `Event.pas` —— 地图事件基类（Round 829）

> 323 行。**`TEvent`（`:11-38`）是地图上「限时出现物」的基类**。

**字段**：`Check` / `PEnvir` / `X,Y` / **`EventType`** / **`EventParam`** /
`OpenStartTime`（열린시간 开启时刻）/ **`ContinueTime`**（열여있을 시간 存在时长）/
`CloseTime` / `Closed` / `Damage` / **`OwnCret: TCreature`**（归属者）/
`runstart` / `runtick` / `IsAddToMap` / `FVisible`（맵에 보인다）/ `Active`。

**方法**：`AddToMap`（**`virtual`**）/ `Run`（**`dynamic`**）/ `Close`。
→ **`virtual` + `dynamic` 混用**：`AddToMap` 用静态虚表，`Run` 用动态分派。

**`ContinueTime` + `CloseTime` 双时间戳** → **限时事件**（如限时宝箱/传送门）。

**`OwnCret`（归属者）+ `Damage`** → **归属/伤害累计机制**（如事件怪被谁打死的）。

**`EventType`/`EventParam` 整数对** → **事件由整数类型 + 参数描述**，
便于从脚本/配置驱动。

### 15.1 未验证项

| 项 | 原因 |
|---|---|
| `EventType` 取值表 | 未读 |
| 派生类（是否有 `TEvent` 子类） | 未在 `Event.pas` 内见到 `class(TEvent)` |
| `Run` 的 `dynamic` 重载点 | 未读 |

---

## 16. 物品升级概率系统（`CalcUpgradeProbability`）（Round 832）

> `ObjBase.pas:20600-20820`。**这是全源码里数值最密集的一段**。

### 16.1 三段式结果

| `Result` | 含义 | 触发条件 |
|---:|---|---|
| **2** | **성공（成功）** | `iRandom < iSucceed` |
| **1** | **불변（不变）** | `iSucceed <= iRandom < iSucceed + iFail` |
| **0** | **파손（破碎）** | 其余 |

**「不变」是独立结果** —— 升级失败不一定毁装备，有中间档。

### 16.2 **属性选项总和 → 概率档**（`:20719`）

```pascal
iSum := _MIN( 10, _MAX(0, SumOfOptions(puSeedItem, psSeedItem)) );
```

**`SumOfOptions` 被钳制到 `[0, 10]`** → **`UpProb[0..10]` 共 11 档**。
注释：「옵션합 10 이상은 무시. 옵션합 0이하는 0로 만든다.」
（选项和 ≥10 忽略，≤0 归零）

### 16.3 **完整概率表**（`iBase = 10000` 定标）

`iValue[0..2]` = **보옥（宝珠）**；`iValue[3..5]` = **신주（神酒）**，且
**`신주 = 보옥 × MFactor(4) / DFactor(2) = 보옥 × 1.5`**（临时改动）。

| 档 | `보옥[0]` 武器 | `[1]` 手镯/鞋 | `[2]` 项链/其他 | `신주[3]` | `[4]` | `[5]` |
|---:|---:|---:|---:|---:|---:|---:|
| **0** | 5000 | 5000 | 5000 | 7500 | 7500 | 7500 |
| 1 | 4500 | 3000 | 4000 | 6750 | 4500 | 6000 |
| 2 | 4000 | 1000 | 3000 | 6000 | 1500 | 4500 |
| 3 | 3500 | 500 | 1000 | 5250 | 750 | 1500 |
| 4 | 3000 | 100 | 500 | 4500 | 150 | 750 |
| 5 | 1500 | 25 | 100 | 2250 | 37 | 150 |
| 6 | 400 | 5 | 25 | 600 | 7 | 37 |
| 7 | 100 | 5 | 5 | 150 | 7 | 7 |
| 8 | 25 | 5 | 5 | 37 | 7 | 7 |
| **9** | **5** | **5** | **5** | 7 | 7 | 7 |
| **10** | **0** | **0** | **0** | 0 | 0 | 0 |

**概率 = `iValue / 10000`**。例：档 0 武器 `5000/10000 = 50%`；
档 9 全部 `5/10000 = 0.05%`；**档 10 恒为 0（必失败）**。

**⚠️ 临时改动未回退**（`:20613`）：
```pascal
MFactor := 4;  //보옥의 1.5배로 수정(임시), 원래값 4
DFactor := 2;
//임시 1.5배로 수정
```
**注释自相矛盾**（「1.5 倍修改（临时），原值 4」—— 原值就是 4），
且 `//임시`（临时）**从未移除** → **线上跑的是临时加强值**。

### 16.4 **装备类型 → 使用哪一列**（`:20739-20750`）

| `StdMode` | 装备 | 用 `iValue` |
|---|---|---|
| **5, 6** | **무기（武器）** | `[0]` |
| **10, 11** | **옷（衣服）** | `[0]` |
| **24, 26, 52** | **팔찌, 신발（手镯、鞋）** | `[1]` |
| **19** | **목걸이（项链）** | `[2]` |
| 其他 | 기타 | `[2]` |

**`StdMode` 值表**：`5/6`=武器、`10/11`=衣服、`19`=项链、`24/26/52`=手镯/鞋。

### 16.5 **幸运值修正（核心公式）**（`:20741`）

**武器**（唯一带装备属性修正的）：
```pascal
iSucceed := iValue[0] * ABS( (29 + BodyLuckLevel
              + (LOBYTE(psSeedItem.AC) + puSeedItem.Desc[3]
                 - LOBYTE(psSeedItem.MAC) - puSeedItem.Desc[4]) / 2 ) / 30 );
```

**其余装备**：
```pascal
iSucceed := iValue[k] * ABS( (29 + BodyLuckLevel) / 30 );
```

**基准是 `29 + BodyLuckLevel`** ——
**`BodyLuckLevel = 1` 时正好 `30/30 = 1.0`（不修正）**；
幸运越高越容易成功（>30 超过基准）。

**武器额外项**：`(AC + Desc[3] - MAC - Desc[4]) / 2`
→ **武器自身的 AC/MAC 与两个 `Desc` 字节参与修正**（正负属性抵消）。

**⚠️ `ABS()` 包住整个比值** —— **幸运低于基准（<29）时绝对值反而让概率回升**
（`|负值|` = 正值）。**这可能是 bug**：本意应是「幸运低则概率低」，
但取绝对值后**幸运 0 与幸运 58 得到相同的修正**。待验证。

### 16.6 **攻速特例（`sonmg 2003/12/22`）**（`:20752-20756`）

```pascal
// 공속 확률 따로 적용.(sonmg 2003/12/22)
if psJewelryItem.Shape = 9 then
   iSucceed := (iSucceed * 60) div 100;   // ×0.6
```

**`Shape = 9` 的饰品（攻速类）成功率打 6 折** —— **⏱ 带日期/人名改动**。

### 16.7 **两种饰品（`StdMode` 60 vs 61）**

| `StdMode` | 名称 | 失败处理 |
|---:|---|---|
| **60** | **보옥（宝珠）** | **可能破碎**（`iFail = (iBase - iSucceed) * 0.7`） |
| **61** | **신주（神酒）** | **不破碎**（`iFail` 计算**被注释掉** `:20786`），只有成功/不变 |

**神酒用 `iValue[3..5]`（= 宝珠 × 1.5），且注释「신주 깨지지 않음」（神酒不碎）**
—— **神酒 = 更贵、更安全、成功率更高**。

**⚠️ 又一次临时值未回退**（`:20758`）：
```pascal
iFail := Round( (iBase - iSucceed) {* 0.65}* 0.7 );  //임시 0.65로 수정, 원래값 0.7
```
注释说「临时改为 0.65，原值 0.7」，但**代码里 `0.65` 被注释、实际用 `0.7`**
→ **注释与代码相反**。

### 16.8 **批量执行与概率回传**

`iExecCount`（执行次数，`< 1` 则置 1）+ `testSucceed`/`testNoChange`/`testFail`
（**批量模拟计数**）+ `fRetProb := iSucceed / UpProb[iSum].iBase`（**回传实际概率**）。

→ **支持「模拟 N 次」的测试模式**，与 `CmdSendTestQuestDiary` 同类调试设施。

### 16.9 未验证项

| 项 | 原因 |
|---|---|
| `SumOfOptions` 的实现 | 未读（选项和算法） |
| `BodyLuckLevel` 的来源与范围 | 未读 |
| `Desc[3]`/`Desc[4]` 的语义 | 未读（疑 AC/MAC 的附加项） |
| `ABS()` 是否确为 bug | **未验证** —— 需实测或对照其他版本 |
| `UpgradeResultToStr`（结果转字符串） | 未读 |
| `DoUpgradeItem`/`CmdUpgradeItem` 的调用侧 | 未读 |
| `TUpgradeProb` 结构定义 | 未读（字段名 `iBase`/`iValue[]` 已知） |
