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
（`protocol.md` §3；前缀用于恋人关系命令，缩写展开未由源码证明）。

与 `ObjBase.pas` 的 `MeetLoverDelayTime`（`//연인 만남 딜레이`= 恋人见面延迟，
sonmg 2005/09/01）、`CmdLoverCharSpaceMove`/`CmdBreakLoverRelation` 配套。

**任务条件里的 `QI_CHECKLOVERFLAG`(140)/`QI_CHECKLOVERRANGE`(141)/
`QI_CHECKLOVERDAY`(142)/`QI_CHECKRANGEONELOVER`(152)**
（`server.md` §12.3）正是查询这套关系数据。

---

## 6. `Event.pas`（323 行）—— 地图事件

`TEvent` 基类、4 个派生事件类及独立管理器（共 6 个类声明；`Event.pas` 全文见 §17.5）：

| 类 | 行 | 语义 |
|---|---|---|
| `TEvent` | `:11` | 基类：可见地图事件与时限 |
| `TStoneMineEvent` | `:41` | 矿点对象；由地图矿点表维护 |
| `TPileStones` | `:52` | 石堆（注释「돌무더기(점 흡입)」= 石堆（点吸收）） |
| `THolyCurtainEvent` | `:58` | 圣幕 |
| `TFireBurnEvent` | `:64` | 火焰伤害事件 |
| `TEventManager` | `:73` | 定时事件与关闭对象管理 |

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
| `DragonSystem.pas` 除 `DecodeStrInfo` 外的实现 | 只读了格式解析 |
| `UserSystem.pas`（153 行） | 未读 |
| `itmunit.pas` 的 8 个 `UpgradeRandom*` 实现 | 只读了签名与 `Desc[]` 映射 |
| `RealAttackSpeed` 的**实际影响**（攻速如何转成延迟） | 未追到消费点 |

---

## 11. `Guild.pas` 实现精读（Round 827；全文件复核 Round 834）

> 3,600 行。Round 827 只读类清单、常量与模型；Round 834 已读实现主体并追调用链，见 §17.1。

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
| **`DeclareGuildWar`** | `:99-100` | 接口注释写「3 小时」；实际有效时长以活动实现为准（§17.1） |
| **`MakeAllyGuild`** | `:104-105` | 接口注释要求会长面对面；调用方检查，方法体只加同盟并保存（§17.1） |

**两个关键业务规则**：
1. 活动实现将行会战设为 **6 小时**（`GUILDWARTIME=6`，每单位 1 小时）；接口注释和已注释旧实现写 3 小时，不能代替活动代码。
2. 同盟由 `ServerGetGuildMakeAlly` 检查双方会长相对站位、会长身份、对方允许同盟及双方无战争；`MakeAllyGuild` 本身仅查重、添加、保存。

### 11.4 行会战（TeamFight）方法族（`:111-115`）

`TeamFightStart` / `TeamFightEnd` / `TeamFightAdd(whostr)` /
`TeamFightWhoWinPoint(whostr, point)` / `TeamFightWhoDead(whostr)`

→ **按玩家名记分**（`MatchPoint`），有死亡记录。

### 11.5 持久化（`:77-82`）

`LoadGuild` / `LoadGuildFile(flname)` / **`BackupGuild(flname)`** /
`SaveGuild` / `GuildInfoChange` / `CheckSave`

`GuildInfoChange` 设 `dosave`/时间戳后**立即调用 `SaveGuild`**；`CheckSave` 在 30 秒后还会再次保存并清 `dosave`。因此不是「只延迟保存」。

**`TGuildManager`（`:121-`）**：`GuildList: TList` +
`LoadGuildList`/`SaveGuildList`/`GetGuild(gname)`/
**`GetGuildFromMemberName(who)`**（按成员名反查行会）/`AddGuild(gname, mastername)`。

### 11.6 与 EI 证据 / Zircon 的对照

| 项 | 原版反编译 | 源码 | Zircon |
|---|---|---|---|
| 行会数据 | EI primary-static：Guild 窗 3 个列表态/9 控件，不是持久化证据 | `TGuild` 列表与文本文件（§17.1） | `GuildInfo`/`GuildMemberInfo` MirDB 对象关联 |
| 行会战 | F803 静态消息分派不证明时长 | 活动时长 6 小时；战争记录与超时扫描（§17.1） | `GuildWarInfo` 有两端行会和 `Duration` 字段 |
| 同盟 | 控件/消息识别不能证明会长资格 | ObjBase 调用方执行面对面/权限/战争检查 | 已读模型字段未建立 Preview 同盟约束对应 |
| 据点/公告板 | EI 行会窗证据不证明据点租约或 SQL 公告板 | 租约、装饰与 SQL 公告板实现（§17.1） | `GuildInfo.Castle` 是城堡关联；非据点租约对应 |
| `$` 宏数据源 | — | ✅ 已闭合（§11.1） | — |

**分级**：源码结论均 `secondary-source`。

### 11.7 覆盖状态与环境边界

| 项 | 原因 |
|---|---|
| `TGuild`/`TGuildManager`/`TGuildAgit`/公告板方法 | ✅ 全文件 1–3600 行已读（Round 834，§17.1） |
| `PTGuildRank` 与职位更新验证 | ✅ 实现主体已读（Round 834，§17.1） |
| `DeclareGuildWar` 活动时长 | ✅ 活动 6 小时；3 小时为旧注释/注释掉的代码 |
| `MakeAllyGuild` 面对面条件 | ✅ 调用方与方法体均已追读；前者校验，后者不校验 |
| `AgitDecoMon.txt` 的部署实例 | Mud3-Config 中未找到；实际运行目录是否有该文件未验证 |

---

## 12. `Castle.pas` —— 沙巴克（사북성）攻城系统（Round 829；全文件复核 Round 834）

> 1,241 行。Round 829 已覆盖常量与时序；Round 834 已读完整实现主体及调用链，见 §17.2。

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
| **每日开战检查** | **20 时这一小时内首次命中的 `Run`**（只判断 `ahour=20`，不检查分钟） | `:542-555` |
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

### 12.6 已闭合内容与剩余未验证项

| 项 | 原因 |
|---|---|
| `Sabuk.txt` 与 `AttackSabukWall.txt` 读写主体 | ✅ 全文件 1–1241 行已读；服务服写入门禁及 INI/攻击者列表路径见 §17.2 |
| `CheckCastleWarWinCondition` | ✅ 已读：开战 10 分钟后扫描内城范围，候选行会外的存活实体会阻止占领 |
| `ChangeCastleOwner`/`FinishCastleWar` | ✅ 已读：城主变更与结束清理路径见 §17.2 |
| 主门/核心墙维修 | ✅ 已读：实际时间门槛为 1 分钟；源注释仍写 10 分钟/1 小时 |
| 韩国版城堡名 `'哥굇냘'` 的编码与原始字节 | 未验证 |

---

## 13. `TagSystem.pas` —— 游戏内**邮件（쪽지）系统**（Round 829；全文件复核 Round 834）

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

**状态 2「不可删除」**只证明 `Delete` 会拒绝删除；该状态由谁发出、是否专用于 GM/系统消息，本文件未证明。

`FDBSaved`（DB 状态）与 `FClient`（客户端投递状态）字段在 `TTagInfo` 中声明；该单元没有据此证明“两条持久化路径”或其一致性保证。投递流程见 §17.3。

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
| `DB_TAG_*` 的 DB 侧落库、事务与确认语义 | GameServer 请求端已读；DataBaseServer 的存储实现未读 |
| `CM_TAG_NOTREADCOUNT` 的正常客户端响应 | GameServer 的转发列表与 `TUserMgr` 允许列表不一致，细节见 §17.3 |
| EI 原版便条窗口及消息处理行为 | 当前检索到的 EI primary-static 证据未闭合此系统 |

---

## 14. `Relationship.pas` —— 恋人/关系系统（Round 829）

> 471 行。**`MAX_LOVERCOUNT = 1`（`:9`）** —— **每人最多 1 个恋人**。

**`TRelationShipInfo`（`:12-41`）**：`Ownner`（소유자 拥有者）/
`Name`（등록자 登记者）/ **`State`(BYTE) 注册状态** / `Level`(BYTE) 等级 /
**`Sex`(BYTE) 性别** / `Date`（등록날짜）/ `ServerDate`（서버날짜）/
`MapInfo`（맵정보）。

**字段编码边界**：`BYTE` 类型是源码事实；“为紧凑序列化”仅属推测，未由协议/存储布局证明。`MapInfo` 被序列化到关系列表，但本地 `Add` 调用可传空值，不能据此称关系绑定地图。

`Ownner` 是源字段的双 `n` 拼写。活动 `Add` 拒绝空用户名或 `Level=0`，按 `Other_` 查重，但本地管理器自身不执行 `MAX_LOVERCOUNT` 限制；配对请求处理器才检查双方许可与容量。`GetLoverName`/`GetLoverDays` 取列表首项，不检查其 `State`。

**尚未验证**：`GetDayNow` 的系统区域设置/时区边界；DB/跨服关系加载完整链路。

---

## 15. `Event.pas` —— 地图事件（Round 829；全文件复核 Round 834）

> 323 行。**`TEvent`（`:11-38`）是地图上「限时出现物」的基类**。

**字段**：`Check` / `PEnvir` / `X,Y` / **`EventType`** / **`EventParam`** /
`OpenStartTime`（열린시간 开启时刻）/ **`ContinueTime`**（열여있을 시간 存在时长）/
`CloseTime` / `Closed` / `Damage` / **`OwnCret: TCreature`**（归属者）/
`runstart` / `runtick` / `IsAddToMap` / `FVisible`（맵에 보인다）/ `Active`。

**分派**：`Run` 为 `dynamic`；`TFireBurnEvent.Run` 覆盖它。`TEventManager.Run` 只在事件 `Active` 且距上次调度超过 `runtick=500ms` 时调用事件。

**时限与可见性**：一般事件由构造器写入地图并以 `ContinueTime` 判断关闭；可见事件关闭时从地图移除。`TEventManager` 将关闭事件先放入 `ClosedList`，超过 5 分钟后每轮最多释放一个。`TStoneMineEvent` 是例外：初始时间为 0、`Active=false`，由地图矿点表维护，不加入定时事件列表。

**所有权/伤害边界**：`TFireBurnEvent` 用 `OwnCret.IsProperTarget` 筛目标，再发 `RM_MAGSTRUCK_MINE` 和 `Damage`；这里没有事件怪归属/击杀累计机制。`EventType`/`EventParam` 是整数字段，但本单元未证明由脚本驱动。

### 15.1 未验证项

| 项 | 原因 |
|---|---|
| EI primary-static 是否给出这些服务端事件语义 | 未由已读 UI/渲染证据证明；见 §17.5 |
| 与 Zircon 地图限时对象的一对一映射 | 未建立；当前读到的是配置化 trigger/action 事件与独立 `ConquestWar` |
| `TFireBurnEvent.ticktime` 首次命中时刻 | 构造器未赋值；运行时首次伤害时刻未实测 |

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

## 17. 五个系统的实现主体与跨仓库对照（Round 834）

本轮用 `Tools/source-read/read_src.py` 顺序读完 `Guild.pas` 1–3600、`Castle.pas` 1–1241、`TagSystem.pas` 1–1678、`Relationship.pas` 1–471、`Event.pas` 1–323。下面记录实现、调用链、EI primary-static 对照、Zircon 当前结构及未闭合边界。源码证据均为 Preview 社区源码的 `secondary-source`；EI 二进制证据不推定服务端同源。

### 17.1 `Guild.pas`：行会、据点、装饰、SQL 公告板

**行会与落盘**（`Guild.pas:60-750,993-1200,1389-1411`）：

- `TGuild` 持有公告、敌对战争、同盟、职位/成员列表和行会战状态；`SaveGuild` 写行会文本数据，`BackupGuild` 负责备份。`GuildInfoChange` 立即调用 `SaveGuild`，`CheckSave` 在标记后 30 秒再写一次并清标记，不能简化为「延迟保存」。
- 职位更新先校验成员集合未变、会长数不超过 2、至少一名会长在线、名称非空且职位编号唯一并落在 1–99；随后更新在线玩家并保存。返回码区分未变化、缺会长、标题空、会长过多、会长不在线、成员集不匹配、重复/越界职位等。
- `DeclareGuildWar` 活动代码以 `GUILDWARTIME=6`、`timeunit=60*60*1000` 建立或续期战争；仅剩余时间整除小时数 `<=1` 才续期。由于整数除法，该表达式允许剩余 `<2` 小时，不等价于注释字面上的「不足 1 小时」。DEBUG 下时间单位改成分钟。此前 3 小时规则留在已注释旧实现和接口注释中，不是活动路径。
- 调用链：`ObjNpc.pas:5741-5759` 检查目标行会、金币并扣 `GUILDWARFEE=60000`；`ObjBase.pas:19767-19825` 限行会会长且仅 `ServerIndex=0`，再对双方分别登记战争；`UsrEngn.pas:3331` 每 10 秒调用 `GuildMan.CheckGuildWarTimeOut`，按 tick 清除超时战争。
- `MakeAllyGuild` 的方法体（`Guild.pas:1147-1159`）只查重、添加并保存，而且成功添加后未将 `Result` 设为 `TRUE`；当前调用方不依赖该返回值。面对面与权限不是此方法的保证：`ObjBase.pas:28867-28905` 要求对方为正前方玩家且反向面向当前玩家、双方都是会长、对方开放同盟、双方均无战争，再对两边各调用一次。
- `TGuild.IsRushAllyGuild` 在找到同盟后执行 `Result := TRUE`；前面的 `RushGuildList` 比较不控制这次赋值。另一个 `TUserCastle.IsRushAllyCastleGuild` 有独立列表检查，不能把两方法视为同一实现。

**据点与装饰**（`Guild.pas:1415-2975`；入口 `UsrEngn.pas:3314-3342`）：

- `TGuildAgitManager` 从带版本字段的文本表装载租约；只有主服务器 `ServerIndex=0` 写回并备份。每分钟维护租约，过期租约驱逐据点内成员；到期但有足够捐款时可自动扣续期费续 1 期；售出等待结束后切换行会所有权并清空售卖状态。
- 源码常量给出默认 7 天周期、1 天售卖等待、最多 100 个据点、注册费 1,000 万、续期费 100 万、据点资金上限 1 亿。`CheckGuildAgitTimeOut` 每分钟扫描；`gaCount=0` 时另刷新会长，调用方每分钟循环 0–9，因此会长刷新每 10 分钟一次。
- 装饰物列表走 `AgitDecoMon.txt`，每据点装饰数上限 50；`UsrEngn` 每小时降一次装饰耐久（DEBUG 分支额外每 10 分钟降）。该文件在 Mud3-Config 未找到，运行目录实例未验证。

**据点 SQL 公告板**（`Guild.pas:2979-3595`，SQL 队列见 `SqlEngn.pas:34-43,1114-1251`、数据库调用见 `DBSQL.pas:830-1040`）：

- `TGuildAgitBoardManager` 缓存每个行会板的数据库响应；列表/新增/删除/编辑通过 `SQLEngine.Request*` 异步提交，完成后再重载用户列表。
- 固定 3 条公告永远放在每页顶部；名义每页 10 条，所以普通文章每页最多 7 条。普通文章上限 73。文章编号由 `OrgNum/SrcNum1/SrcNum2/SrcNum3` 编码原文与最多 3 层回复；新公告插到首位并淘汰第 4 条旧公告，普通文章超限时移除最旧项。
- 玩家协议路径：`UsrEngn.pas:3497-3505` 转发 `CM_GABOARD_*`；`ObjBase.pas:25245-25251,30052-30234,31208-31267` 执行读写/分页及回复；数据库工作线程处理 SQL 请求。

**EI primary-static 对照**：`guild-window-paint-evidence.json`（F348）直接确认 EI 主窗口有 3 个列表绘制态、9 个控件和滚动条；`RESEARCH_LOG.md` Round 497/F803 记录公告/同盟消息分派。它们闭合的是客户端绘制/消息入口，不证明 Preview 服务端的战争时长、文本落盘、据点租约或 SQL 公告板内部。

**Zircon 当前对照**：`zircon/ServerLibrary/DBModels/GuildInfo.cs:13-390` 以 MirDB 对象表达会名、税、资金、权限、城堡、成员和仓库；`GuildMemberInfo.cs:10-174` 是独立成员对象；`GuildWarInfo.cs:8-54` 记录两端行会和 `Duration`。这是对象关联模型，与 Preview 的文本行会文件、独立据点文本表和 SQL 公告板不是一一对应。

### 17.2 `Castle.pas`：沙巴克运行态与申请链

**初始化与服务归属**（`Castle.pas:138-300,302-513`）：读取 `Sabuk.txt` 与 `AttackSabukWall.txt`；只有 `CastleMapName` 所属的 `ServerIndex` 创建城门、三面墙、卫兵、弓箭手并绑定内城门。`SaveToFile` 同样限定归属服务器写入，其他服读取；保存城堡状态与攻击者申请表是分开的路径。

**申请和战斗**（`Castle.pas:517-689,962-1188`；NPC 入口 `ObjNpc.pas:5801-5849,5851-5873`）：

- 行会会长在非城主行会身份下、持有 `__ZumaPiece` 才能申请；`ProposeCastleWar` 拒绝重复行会，并把日期设为 3 天后。申请时消耗道具、记日志并通知跨服。
- `Run` 只在城堡所属服运行。它每 10 秒由 `UsrEngn` 调用；每日 20 时这一小时内首次命中（实现只比较小时、不比较分钟）检查日期等于当天的攻击申请。开战后城主行会也加入 `RushGuildList`，广播并关主门。
- 城堡战 3 小时结束，10 分钟前提示并逐分钟倒数；结束时 `FinishCastleWar` 清攻击状态，把非城主行会玩家随机送回家并扣声望（会长 5000、其他成员 500），城主成员留场并加声望（会长 10000、其他成员 1000）。
- 胜利检查需先过 10 分钟，再扫描 `CorePEnvir` 中以 `(0,0)` 为中心、半径 1000 的实体；只有没有存活实体的 `MyGuild` 不等于候选攻击行会时才返回胜利。`ObjBase.pas:24801-24805` 随后变更城主并发跨服同步。
- `IsCastleWarArea` 只认城堡主地图且 `abs(dx)<100 && abs(dy)<100`；内城/地下室分支已注释。税率是商品价 10%，日税收上限 500 万、金库上限 1 亿。金库存取仅城主会长可操作。
- 城门/墙维修期间要求未攻城、未死亡结构并等待源码表达式 `>1*60*1000`；非致命损伤与完全损毁分支都以 1 分钟判断，注释仍分别写 10 分钟和 1 小时。

**EI primary-static 对照**：本轮引用的 F348 行会窗证据只覆盖客户端 UI；没有据此声称 EI 二进制证明沙巴克定时、税率或胜负逻辑。

**Zircon 当前对照**：`zircon/LibraryCore/SystemModels/CastleInfo.cs:6-181` 将城堡绑定地图、开始时间/持续时间、区域、旗帜/城门/守卫与目标怪物；`zircon/ServerLibrary/Models/ConquestWar.cs:13-197` 管理参战行会、起止时间、目标、开始/结束广播、玩家传送及首领生成/销毁。结构上是多城堡数据驱动的 `ConquestWar`，不是 Preview 的单个 `Sabuk.txt` 运行态；行为细节不做等价推断。

### 17.3 `TagSystem.pas`：便条投递、页协议和分派缺口

**所有者/入口**：`UserMgr.pas:146-160` 在用户子系统打开时创建 `TTagMgr` 并加载拒收名单；`:451-564` 按 opcode 把消息转给用户的 `FTag`。`UsrEngn.pas:3544-3571` 把一般便条命令送入 `UserMgrEngine`；据点便条另经 `ObjBase.pas:25231-25243` 变成内部 `CM_TAG_ADD_DOUBLE`，`TUserMgr` 允许列表和 `TTagMgr.OnCmdChange` 都处理该内部命令。

**状态/流转**（`TagSystem.pas:1-300,303-707,712-1102,1111-1678`）：

- 每用户最多 30 条，拒收名单上限 20；`GenerateSendDate` 是本机当前时间到秒的 `yymmddhhnnss`，`Add` 按容量加入但不查同号。多个发送在同一秒会得到相同日期键；冲突影响未在运行时测量。
- 客户端请求列表时若未就绪，服务端记下页码并发 DB list 请求；收到 `DBR_TAG_LIST` 后重建内存列表、置就绪，再回发缓存页。发件人若在线，另经 `ISM_TAG_SEND` 即时送达；无论在线与否，原路径都会发 `DB_TAG_ADD`。接收方拒收名单命中则不加便条。
- 页面大小常量为 10，但 `endnum := startnum+10` 且倒序循环 `endnum downto startnum`，所以完整页可含 11 条。
- 删除状态 2 被拒；单条成功删除先将状态写 3、发 DB delete 与客户端状态，再释放内存。模式 1「删除所有已读」分支为空，虽然 `OnCmdDBDeleteAll` 存在。删除未读条目不减 `FNotReadCount`。
- `SetInfo` 从未读变为其他状态时先减未读数；请求状态 4（解锁删除）被转换为已读 1。重复收到 DB 列表会先 `RemoveAll`，但 `RemoveAll` 不重置 `FNotReadCount`，之后 `Add` 再累计，可能使未读数变大。
- `CM_TAG_REJECT_ADD` 仅在目标当前在线时成功；空拒收列表时 `OnMsgRejectList` 直接返回，不发空列表。
- **已验证的路由缺口**：`UsrEngn` 把 `CM_TAG_NOTREADCOUNT` 转发给 `UserMgrEngine`，`TTagMgr.OnCmdChange` 有处理器，但 `TUserMgr.OnCmdChange` 的 per-user `case` 列表没有该 opcode，因此此常规路径不会调用 `FTag.OnCmdChange`。数据库计数回复和新便条通知仍有各自处理器。

**EI primary-static 对照**：当前 EI 证据集含 group/guild 窗体的绘制记录；没有从这些 primary-static 记录证明便条 UI、拒收或 DB 投递语义。协议常量与 Preview 服务端实现是不同证据层。

**Zircon 当前对照**：`zircon/ServerLibrary/DBModels/MailInfo.cs:9-157` 是账户关联的持久化邮件对象，字段含发件人、日期、主题、正文、打开状态、附件标志和物品列表。它比 Preview `TTagInfo` 的发件人/秒级日期/正文/状态记录多邮件主题与附件关系；未在本轮读取 Zircon 邮件命令完整链，故不对在线投递/分页等行为作结论。

### 17.4 `Relationship.pas`：请求握手与双边恋人记录

`ObjBase.pas:25190-25222` 分派 `CM_LM_*`；`ServerGetRelationRequest`（`:29062-29227`）要求目标位于正前方且反向面向请求者、目标是玩家，双方等级至少 22、性别不同、都开启恋人许可且各自可加入。请求与应答保存在双方 `ReqSequence`；同意后各自在自己的 `TRelationShipMgr` 加入对方、发送关系列表/结果，并由一方发 `RM_LM_DBADD` 请求保存。`MAX_LOVERCOUNT=1` 在请求检查中执行；`TRelationShipMgr.Add` 自身只查空名、等级 0 和对方名字重复，不作容量上限检查。

`TRelationShipInfo` 默认 `Date` 与 `ServerDate` 都取 `yymmddhhnn`；`Add` 可覆盖 `Date`，但不写 `ServerDate`。列表序列化为 `state:name:level:sex:date:serverdate:mapinfo/`。`GetDayNow` 解析日期前 6 位后计算 `Trunc(serverdate-date)+1`；本地日期区域/时区解析结果未运行验证。删除会按 `State` 维护恋人计数；等级变更要求新等级大于 0。

**EI primary-static 对照**：EI group window 是组队窗口，不等同恋人系统；本轮没有发现可证明 `CM_LM` 生命周期或服务端配对条件的 primary-static 证据。

**Zircon 当前对照**：`zircon/ServerLibrary/DBModels/CharacterInfo.cs:511-524,717-731` 存储 `MarriageTeleportTime` 并以 `Partner` 关联另一角色，名称与 Preview 的 `RsState_Lover`/每用户列表不同。此处只比较数据模型字段，未读 Zircon 婚姻请求/离婚处理器。

### 17.5 `Event.pas`：定时地图事件与采矿例外

- `TEvent` 构造时记录 tick、坐标、类型、参数、时长及可见性；可见事件入地图。`Run` 超过 `ContinueTime` 后关闭；`TEventManager.Run` 按事件的 500ms 门槛调度，转移关闭对象到 `ClosedList`，关闭满 5 分钟后每轮释放至多一个。主计时器在 `svMain.pas:1683-1695` 调用 `EventMan.Run`。
- `svMain.pas:1530-1554` 在带矿点标志的地图逐格构造 `TStoneMineEvent`，不加入 `EventMan`；事件 `Active=false`，存入不可移动格的地图对象表。`ObjBase.pas:18543-18579` 处理挖矿：矿量减少、成功时创建/增大 5 分钟石堆；矿量耗尽后超过 10 分钟才在再次挖掘时补充。
- `TPileStones.EventParam` 从 1 增至 5；`Magic.pas:309-328` 以 8 个 `THolyCurtainEvent` 形成结界；`:338-367` 在十字 5 格创建 `TFireBurnEvent`。火事件每次间隔超过 3 秒，对格内通过 `OwnCret.IsProperTarget` 的实体发 `RM_MAGSTRUCK_MINE`，再走基类过期检查。

**Zircon 当前对照**：`zircon/ServerLibrary/Envir/Events/EventInfoHandler.cs:10-75,374-409` 用 trigger/action 类型注册配置化事件；`ConquestWar` 是另一套带 `StartTime/EndTime` 的战役对象。两者与 Preview 的地图格事件/采矿对象生命周期不是同一接口。本轮未验证 EI primary-static 对上述服务端事件语义的映射。
