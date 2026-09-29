# Preview 怪物系统（ObjMon*.pas 精读）

> 证据源：`Source/GameServer/{ObjMon,ObjMon2,ObjMon3,ObjAxeMon,ObjGuard}.pas`
> （合计约 8,300 行）。证据等级 `secondary-source`。
> 机器可读：[`monster-classes.tsv`](monster-classes.tsv)（71 个类）。
> 提取器：`Tools/source-read/extract_monster_classes.py`。

---

## 1. 类层次（71 个类，最深 5 层）

| 文件 | 类数 | 内容 |
|---|---:|---|
| `ObjMon.pas` | 32 | 主要怪物族（鸡鹿/蝎子/蜘蛛/僵尸/骷髅/精灵…） |
| `ObjMon2.pas` | 17 | 特殊怪物（粘怪/蜂王/蜈蚣王/大树/蜘蛛巢/守卫/矿怪…） |
| `ObjMon3.pas` | 18 | 第三组怪物 |
| `ObjAxeMon.pas` | 3 | 斧怪 |
| `ObjGuard.pas` | 1 | `TSuperGuard`（继承 `TNormNpc`，**不是 TAnimal**） |

**继承深度分布**：1 层 11 个 / 2 层 17 个 / **3 层 34 个** / 4 层 8 个 / 5 层 1 个。

**顶层基类**（`parent` 不在本表内）：

```
TMonster        : TAnimal      (ObjMon.pas:12)    ← 绝大多数怪物的基类
TStickMonster   : TAnimal      (ObjMon2.pas:14)   ← 「粘住」类，独立分支
TBeeQueen       : TAnimal      (ObjMon2.pas:31)
TBigHeartMonster: TAnimal      (ObjMon2.pas:56)
TBamTreeMonster : TAnimal      (ObjMon2.pas:65)
TSpiderHouseMonster : TAnimal  (ObjMon2.pas:79)
TGuardUnit      : TAnimal      (ObjMon2.pas:103)
TSoccerBall     : TAnimal      (ObjMon2.pas:159)
TMineMonster    : TAnimal      (ObjMon2.pas:167)
TSuperGuard     : TNormNpc     (ObjGuard.pas:12)  ← 唯一继承 NPC 的「怪物」
```

> ⚠️ **`TGuardUnit` 与 `TSuperGuard` 是两个不同的守卫体系**：
> `TGuardUnit` 继承 `TAnimal`（`ObjMon2.pas:103`，其下有 `TArcherGuard`），
> `TSuperGuard` 继承 **`TNormNpc`**（`ObjGuard.pas:12`）。
> **做 NPC/怪物分类时不能只看名字。**

### 1.1 重要派生分支

```
TAnimal
├── TMonster                        (ObjMon.pas:12)
│   ├── TChickenDeer                (:29)  鸡鹿
│   ├── TATMonster                  (:36)  ← 远程攻击基类（AT = Attack Type?）
│   │   ├── TSlowATMonster          (:45)
│   │   ├── TScorpion               (:50)  蝎子
│   │   ├── TSpitSpider             (:56)  喷吐蜘蛛
│   │   │   ├── THighRiskSpider     (:65)
│   │   │   ├── TBigPoisionSpider   (:70)  大毒蜘蛛
│   │   │   └── TElfWarriorMonster  (:199)
│   │   ├── TGasAttackMonster       (:75)  毒气攻击
│   │   │   ├── TGasMothMonster     (:176)
│   │   │   └── TGasDungMonster     (:183)
│   │   ├── TCowMonster             (:83)  牛
│   │   ├── TMagCowMonster          (:88)
│   │   ├── TZilKinZombi            (:130)
│   │   ├── TWhiteSkeleton          (:141)
│   │   ├── TCriticalMonster        (:211) 暴击怪
│   │   │   └── TDoubleCriticalMonster (:218)
│   │   └── TSkeletonSoldier        (:240)
│   ├── TLightingZombi              (:113) 闪电僵尸（注释：被雷劈死的）
│   ├── TDigOutZombi                (:122) 破土僵尸
│   ├── TScultureMonster            (:153) 石像怪
│   │   └── TScultureKingMonster    (:162)
│   │       ├── TSkeletonKingMonster(:227)
│   │       │   ├── TDeadCowKingMonster (:249)
│   │       │   │   └── TPBKingMonster  (:272)
│   │       │   └── TBanyaGuardMonster  (:257)
│   └── TStoneMonster               (:266) 石头怪
├── TStickMonster                   (ObjMon2.pas:14)
│   └── TCentipedeKingMonster       (:44)  蜈蚣王
└── TGuardUnit                      (ObjMon2.pas:103)
    └── TArcherGuard                (:110)
```

**`TCowKingMonster : TAtMonster`**（`ObjMon.pas:96`）—— **注意大小写**：
`TAtMonster` 而非 `TATMonster`。Delphi **标识符大小写不敏感**，
所以这是同一个类，只是**拼写不一致**（同一代码库里两种写法并存）。

---

## 2. `TMonster` AI 核心（`ObjMon.pas:12-27`）

```pascal
TMonster = class (TAnimal)
private
   thinktime: longword;          // Think 节流
protected
   RunDone: Boolean;
   DupMode: Boolean;             // 位置重复模式
   function  AttackTarget: Boolean; dynamic;   // ← 可覆写
public
   function  MakeClone (mname: string; src: TCreature): TCreature;
   procedure RunMsg (msg: TMessageInfo); override;
   procedure Run; override;      // ← AI 主循环
   function  Think: Boolean;     // ← 3 秒节流的位置去重
   procedure RecalcAbilitys; override;
end;
```

### 2.1 `Think`（`:382-408`）—— **3 秒节流的位置去重**

```pascal
if GetTickCount - ThinkTime > 3000 then begin        // ← 3 秒才想一次
   ThinkTime := GetTickCount;
   if PEnvir.GetDupCount(CX, CY) >= 2 then           // 同格 ≥2 个对象
      DupMode := TRUE;
   if not IsProperTarget(TargetCret) then
      TargetCret := nil;                              // 目标失效则清空
end;

// 位置重复时避让（固定怪不避让）
if DupMode and (not BoDontMove) then begin
   oldx := self.CX;  oldy := self.CY;
   WalkTo (Random(8), FALSE);                         // ← 随机 8 方向试走
   if (oldx <> self.CX) or (oldy <> self.CY) then begin
      DupMode := FALSE;  Result := TRUE;
   end;
end;
```

**三个要点**：
1. **`Think` 是 3 秒节流**（`3000ms`）—— 不是每帧跑。
2. **`GetDupCount(CX,CY) >= 2`** 触发避让 —— 防止怪物堆叠。
   这是 `Envir.GetDupCount`（`Envir.pas:712`）的用途。
3. **`BoDontMove` 的怪不避让**（固定怪，如石像/植物）。

### 2.2 `AttackTarget`（`:410-433`）—— 攻击决策

```pascal
if TargetCret <> nil then
   if (not TargetCret.Death) and IsProperTarget(TargetCret) then
      if TargetInAttackRange (TargetCret, targdir) then begin
         if GetCurrentTime - HitTime > GetNextHitTime then begin   // ← 攻速门
            HitTime := GetCurrentTime;
            TargetFocusTime := GetTickCount;
            Attack (TargetCret, targdir);
            BreakHolySeize;                                        // ← 打破圣缚
         end;
         Result := TRUE;
      end else begin
         if TargetCret.MapName = self.MapName then
            SetTargetXY (TargetCret.CX, TargetCret.CY)             // ← 追击
         else
            LoseTarget;   // 注释：<!!주의> TargetCret := nil로 바뀜（注意：会被置 nil）
      end;
```

**要点**：
- **攻速门** `GetCurrentTime - HitTime > GetNextHitTime`
  —— `GetNextHitTime`（`ObjBase.pas:1773`）是攻速计算入口。
- **跨地图目标自动放弃**（`MapName` 不等 → `LoseTarget`）。
- **`BreakHolySeize`** —— 攻击时打破「圣缚」（道士的定身？）。
- ⚠️ 注释明确警告 **`LoseTarget` 会把 `TargetCret` 置 nil** ——
  调用后不能再用该指针（本函数靠 `else` 分支规避）。

### 2.3 `Run`（`:435-...`）—— AI 主循环

```pascal
if not HideMode and not BoStoneMode and IsMoveAble then begin
   if Think then begin           // 位置重复 → 避让后直接返回
      inherited Run;
      exit;
   end;
   // 行走等待模式（走 N 步后停一会儿）
   if BoWalkWaitMode then
      if Integer(GetTickCount - WalkWaitCurTime) > WalkWaitTime then
         BoWalkWaitMode := FALSE;

   if not BoWalkWaitMode and (GetCurrentTime - WalkTime > GetNextWalkTime) then begin
      WalkTime := GetCurrentTime;
      Inc (WalkCurStep);
      if WalkCurStep > WalkStep then begin     // ← 走够 WalkStep 步
         WalkCurStep := 0;
         BoWalkWaitMode := TRUE;               // ← 进入等待
         WalkWaitCurTime := GetTickCount;
      end;

      if not BoRunAwayMode then
         if not NoAttackMode then
            if TargetCret <> nil then
               if AttackTarget then begin
                  // 攻击中若主人强制召唤 → 回到主人身后
                  if (Master <> nil) and ForceMoveToMaster then begin
                     ForceMoveToMaster := false;
                     GetBackPosition (Master, bx, by);
                     ...
```

**状态字段全景**（怪物 AI 的可调参数）：

| 字段 | 语义 |
|---|---|
| `HideMode` / `BoStoneMode` | 隐身 / 石化（都不行动） |
| `BoWalkWaitMode` / `WalkWaitTime` / `WalkWaitCurTime` | **走 N 步停一会儿**的节奏控制 |
| `WalkCurStep` / `WalkStep` | 步数计数 / 每轮步数 |
| `BoRunAwayMode` | 逃跑模式 |
| `NoAttackMode` | 不攻击模式 |
| `Master` / `ForceMoveToMaster` | 主人 / 主人强制召唤 |
| `BoDontMove` | 固定不动 |

> **`WalkStep`/`WalkWaitTime` 是「怪物节奏」的两个核心参数** ——
> 决定了怪物是「走几步停一下」还是「连续移动」。
> 这解释了为什么不同怪物的移动观感差别很大。

---

## 3. `TATMonster`（`:36-43`）—— 远程攻击怪

```pascal
TATMonster = class (TMonster)
   procedure Run; override;
end;
```

`TATMonster.Run`（`:751`）注释「가장 가까운 놈에게 공격한다.」
（**向最近的家伙攻击**）—— 即远程怪会主动找最近目标，
与近战怪的「等目标进范围」不同。

**`TSpitSpider`（喷吐蜘蛛）族**是最多派生的一支（`THighRiskSpider`/
`TBigPoisionSpider`/`TElfWarriorMonster`），说明「喷吐」是一种可复用的
攻击模式基类。

---

## 4. 与 EI 证据 / Zircon 的对照

| 项 | 原版反编译 | 源码 | Zircon |
|---|---|---|---|
| 怪物种类数 | `monster-dat-catalog.json`（已解） | 71 个类 | `MonsterInfo`（dbeditor） |
| 怪物 AI | 未闭合 | `TMonster.Run/Think/AttackTarget` | `ServerLibrary` 有对应 |
| 寻路 | 未闭合 | **贪心 8 方向**（`TAnimal.GotoTargetXY`，见 `server.md` §10.2） | — |
| 避让 | 未闭合 | `Think` 的 `GetDupCount >= 2` + 3 秒节流 | — |
| 移动节奏 | 未闭合 | `WalkStep`/`WalkWaitTime` | — |
| 远程怪 | 未闭合 | `TATMonster`（找最近目标） | — |

**分级**：源码结论均 `secondary-source`；原版无对应证据的标 `source-only`。

> ⚠️ **`_Oranze Library/astar.h` 未被任何源码引用**（`server.md` §10.2 已证，
> 本轮再次全仓复核）：
> - `grep -rl 'include.*astar\|"astar.h"'` → **零命中**（无任何 `#include`）
> - 仅在**工程文件**里被列出：`LoginServer/_Oranze Library/_Oranze Library.vcproj:540`、
>   `DataBaseServer/_Oranze Library/_Oranze Library.dsp:184`
>   （即**编译进项目但代码从未使用**）
> - `GameServer/ObjBase.pas` 里唯一命中是**误报**（`HasTargetedCount` 的韩文注释
>   里恰好含 `astar` 子串）
>
> 怪物寻路是 `TAnimal.GotoTargetXY` 的**贪心 8 方向 + 最多 7 次试转**
> （`server.md` §10.2）。**A\* 在这份源码里是死代码。**

---

## 5. 未验证项

| 项 | 原因 |
|---|---|
| ~~`ObjMon.pas` 32 类构造与实现~~ | **已闭合**（Round 935，§11） |
| ~~`TATMonster.Run` 的完整实现~~ | **已闭合**（Round 935，§11.2） |
| ~~`MakeClone`（怪物克隆/召唤）~~ | **已闭合**（Round 935，§11.1） |
| ~~`RecalcAbilitys`（属性重算）~~ | **已闭合**（Round 935，§11.1） |
| ~~`TSuperGuard`（`ObjGuard.pas`，继承 `TNormNpc`）~~ | **已闭合**（Round 933，§10.2） |
| ~~`ObjMon2.pas`（17 类）~~ | **已闭合**（Round 936，§12） |
| ~~`ObjMon3.pas`（18 类）~~ | **已闭合**（Round 937，§13） |
| ~~`TSoccerBall` / `TMineMonster`（特殊玩法怪）~~ | **已闭合**（Round 936，§12.5 / §12.1） |
| 怪物与 `MonGen.txt` 的 `MonName` 匹配机制 | 未读（`MonName` → 类实例化的分派点） |
| `Monster.dat` 的二进制表解析 | 未读 |

---

## 9. `TAnimal` 怪物 AI 实现（Round 831）

> `ObjBase.pas` 的 `TAnimal` 实现段。这是**全源码里唯一一处 AI 实现**
> （`astar.h` 的 A* 是死代码，从未被 `#include`）。

### 9.1 两个索敌函数（唯一差别：隐身检查）

**`MonsterNormalAttack`（`:17303-17322`）** 与
**`MonsterDetecterAttack`（`:17324-17343`）** 结构完全相同，逐行对照：

```pascal
for i:=0 to VisibleActors.Count-1 do begin
   cret := TCreature (PTVisibleActor(VisibleActors[i]).cret);
   if (not cret.Death) and (IsProperTarget(cret)) and (not cret.BoHumHideMode or BoViewFixedHide) then begin
      d := abs(CX-cret.CX) + abs(CY-cret.CY);   // 曼哈顿距离
      if d < dis then begin dis := d; nearcret := cret; end;
   end;
end;
if nearcret <> nil then SelectTarget (nearcret);
```

| | `MonsterNormalAttack` | `MonsterDetecterAttack` |
|---|---|---|
| 隐身检查 | ✅ `not cret.BoHumHideMode or BoViewFixedHide` | ❌ **无** |

→ **唯一区别**：普通索敌**看不见隐身玩家**，探测型索敌**无视隐身**。
`BoViewFixedHide`（**固定隐身可见**）是豁免开关 ——
即某些怪物（或状态）能看破隐身。

**距离度量是曼哈顿距离**（`abs(dx)+abs(dy)`，非欧氏、非切比雪夫），
初始 `dis := 999`。

### 9.2 `GotoTargetXY` —— **贪心步进寻路**（`:17351-17409`）

**不是 A\***。算法：

1. **方向选择**（`while TRUE` + `break` 的展开式 if 链）：
   先比 X 再比 Y —— 目标在右侧则 `DR_RIGHT`，右上则 `DR_UPRIGHT`，依此类推。
   8 方向判定，**优先走对角线**。
2. `WalkTo(wantdir, FALSE)` 走一步。
3. **卡墙处理**（`:17397-17407`）—— 最多重试 **7 次**：

```pascal
rand := Random (3);
for i:=1 to 7 do begin
   if (oldx = self.CX) and (oldy = self.CY) then begin
      {앞이 막혀 있음}                        // 前方被挡
      if rand <> 0 then Inc (wantdir)         // 2/3 概率：顺时针转向
      else if wantdir > 0 then Dec (wantdir)  // 1/3 概率：逆时针转向
      else wantdir := 7;                      // 下溢回绕
      if wantdir > 7 then wantdir := 0;       // 上溢回绕
      WalkTo (wantdir, FALSE);
   end else break;
end;
```

**关键**：`rand := Random(3)` **在循环外**，所以**整个重试过程转向方向一致**
（不会来回抖）。→ **怪物绕墙是「沿固定方向转圈找路」**，
本质是**贪心 + 随机旋向**，没有全局路径规划。

`FindPathTime := GetCurrentTime`（`:17363`）—— 记录了寻路时刻，
且上方**注释掉了节流判断**（`//if GetCurrentTime - FindPathTime > FindPathRate`）。

### 9.3 `Wondering`（游荡，`:17411-17424`）—— 极简

```pascal
if Random(20) = 0 then begin          // 每 tick 5% 概率
   if Random(4) = 1 then Turn (Random(8))   // 25%：原地随机转向
   else WalkTo (self.Dir, FALSE);           // 75%：沿当前方向走一步
end;
```

**每 tick 5% 概率动一次**，动的时候 3/4 概率直走、1/4 概率转 8 方向。
→ **游荡完全无目的性**，不避障（卡住就卡住）。

### 9.4 `SetTargetXY` / `TargetX`/`TargetY`

最简 setter（`:17345-17349`）。配合 `GotoTargetXY` 使用 ——
**AI 的移动目标只是一个坐标对**，没有路径缓存。

### 9.5 与既有结论的对照

| 项 | 结论 |
|---|---|
| A*（`astar.h`） | **死代码**（从未 `#include`）—— 本节**再次印证**：真寻路是贪心步进 |
| 怪物 AI 位置 | `ObjBase.pas` 只有**基类骨架**；主体在 `ObjMon2.pas`/`ObjMon` |
| `IsProperTarget` | 敌我判定钩子（未读实现） |

### 9.6 未验证项

| 项 | 原因 |
|---|---|
| `IsProperTarget` 实现 | 未读（敌我/阵营判定核心） |
| `BoViewFixedHide` 的设置点 | 未读 |
| `SelectTarget` 实现 | 未读 |
| `TAnimal.Attack`/`Struck`/`LoseTarget` 实现 | 未读 |
| `ObjMon2.pas` 的具体怪物 AI | 未读（后续） |
| `FindPathRate` 常量值 | 未找到定义（节流被注释掉） |

---

## 10. `ObjAxeMon.pas`（190 行）与 `ObjGuard.pas`（101 行）实现（Round 933）

### 10.1 `ObjAxeMon.pas` —— 远程「飞斧」怪物族（3 类）

```
TMonster
└── TDualAxeMonster      (:12)  RC_DUALAXESKELETON=87  「쌍도끼해골 / 双斧骷髅」
    ├── TThornDarkMonster(:26)  RC_THORNDARK=93        ChainShotCount=3
    └── TArcherMonster   (:31)  RC_ARCHERMON=104       「마궁사 / 魔弓手」ChainShotCount=6
```

**工厂分派**：`UsrEngn.AddCreature`（`:841`）按 `race` 建对象 ——
`:931 RC_DUALAXESKELETON→TDualAxeMonster`、`:962 RC_THORNDARK→TThornDarkMonster`、
`:1034 RC_ARCHERMON→TArcherMonster`。**这三类不在 `ObjMon*.pas` 里，而是独立单元。**

**`TDualAxeMonster.Create`（`:41-52`）**：`ViewRange:=5`、`RunNextTick:=250`、
`SearchRate:=3000`、`ChainShot:=0`、`ChainShotCount:=2`（默认 2 连发）。

**`FlyAxeAttack(targ)`（`:59-83`）—— 飞斧核心**：

1. `PEnvir.CanFly(CX,CY,targ.CX,targ.CY)` 做**弹道遮挡检查**（不能穿墙）；
2. 伤害 = `Lobyte(DC) + Random(SmallInt(Hibyte(DC)-Lobyte(DC))+1)`（DC 低/高字节区间随机）；
3. **原来的护甲减法被整段注释掉**（`:70-73`），改为 `targ.GetHitStruckDamage(self, dam)`；
4. `targ.StruckDamage(dam, self)` + `SendDelayMsg(RM_STRUCK, ..., 600 + max(|dx|,|dy|)*50 ms)`
   —— **延迟随距离线性增长**（切比雪夫距离）；
5. `SendRefMsg(RM_FLYAXE, Dir, CX, CY, Integer(targ), '')` 让客户端播放飞斧动画。

**`AttackTarget`（`:85-114`）—— 连发 + 追击 + 丢失**：

- 门 `GetCurrentTime-HitTime > GetNextHitTime`（继承的 `Run` 会重设 `HitTime`）；
- **7 格方框内**：`ChainShot < ChainShotCount-1` 时 `Inc(ChainShot)` 并再飞一斧；
  否则 `Random(5)=0` 才把 `ChainShot` 清零 —— 即**连发之间要 1/5 概率才重新开始**，
  实际是「打满 N 发后等一个 1/5 门再重置」，不是每 N 发固定重置；
- **8–11 格方框**且同图：`SetTargetXY` 追击；**不同图**：`LoseTarget`（注释提醒 `TargetCret` 会被置 nil）。

**`Run`（`:116-161`）—— 覆盖基类**：注释掉的旧门（`Death/RunDone/BoGhost/中毒状态`）被
`if not RunDone and IsMoveAble` 取代。每 5 秒扫描 `VisibleActors` 选**曼哈顿最近**合法目标
（条件同 `TAnimal` 索敌：非死亡 + `IsProperTarget` + 隐身可见门）。4 格内**逃跑**：
≤2 格时 1/5 概率逃、3–4 格必逃（`GetBackPosition`）—— **这是「保持距离的远程 AI」**。
最后 `inherited Run`。

> **要点**：这是全源码里少见的「**风筝型（kiting）远程怪**」——
> 连发、追击、贴脸逃跑、弹道遮挡、延迟随距离，都在一个 190 行单元里。
> 与客户端 `Source/Client/AxeMon.pas`（4,217 行，仅渲染）**不是同一文件**（见 `client-rendering.md`）。

### 10.2 `ObjGuard.pas` —— `TSuperGuard`（唯一继承 NPC 的「怪物」）

`TSuperGuard = class(TNormNpc)`（`:12`），`RC_DOORGUARD=11`（문지기 경비병 / 门卫）。
工厂：`UsrEngn.AddCreature:854 RC_DOORGUARD→TSuperGuard.Create`。
属性：`ViewRange:=7`、`Light:=2`。**它不是 `TAnimal`，没有 AI 移动/攻击基类逻辑**，
`Run`/`AttackTarget` 全部自实现。

**`AttackTarget`（`:47-76`）—— 瞬移突刺**：

```
ox:=CX; oy:=CY; olddir:=Dir;              // 记住原位
GetBackPosition(TargetCret, CX, CY);       // 瞬移到目标旁
Dir := GetNextDirection(...);
SendRefMsg(RM_HIT, ...); _Attack(HM_HIT, TargetCret);   // 「점프해서 공격」= 跳劈
TargetCret.SetLastHiter(self);
TargetCret.ExpHiter := nil;                // 注释「경험치를」未写完
CX:=ox; CY:=oy; Dir:=olddir; Turn(Dir);    // 回到原位
BreakHolySeize;
```

→ 门卫的攻击是**视觉上的瞬移跳劈**：真身回到原格，只有攻击结算落在目标身上。
`TargetCret.PEnvir <> PEnvir` 时 `LoseTarget`。**无 nil 守卫**（`TargetCret` 由调用点保证非 nil）。

**`Run`（`:78-98`）—— 选敌**：每 `GetNextHitTime` 周期扫描 `VisibleActors`，
选第一个 `PKLevel>=2`（红名）**或** `RaceServer>=RC_MONSTER 且非 BoHasMission`（无任务的怪）的目标，
`SelectTarget` 后 `break`；有目标则 `AttackTarget`；最后 `inherited Run`。

> ⚠️ **`TSuperGuard` vs `TGuardUnit`/`TArcherGuard`（`ObjMon2.pas`）**：
> 后者是 `TAnimal` 系（Round 931 已读，`IsProperTarget` 按城堡/犯罪标记选目标）；
> `TSuperGuard` 是 `TNormNpc` 系，按红名/无任务怪选目标。**两套守卫语义不同，不可混用。**

### 10.3 与 EI / Zircon 对照与未验证项

| 项 | 原版反编译 | 源码 | 结论 |
|---|---|---|---|
| 飞斧弹道/延迟 | 未闭合 | `CanFly` + `600+max(dx,dy)*50 ms` | `source-only` |
| 门卫跳劈 | 未闭合 | `GetBackPosition` 后回位 | `source-only` |
| 连发重置概率 | 未闭合 | `Random(5)=0` | `source-only` |

未验证：`GetHitStruckDamage`/`GetNextHitTime`/`CanFly` 的具体实现与运行期数值；
`ChainShot` 状态在目标切换时是否复位（源码未见复位点）；Zircon 对应实现未比对。

---

## 11. `ObjMon.pas` 实现精读（Round 935，3,097 行 / 32 类）

### 11.1 `TMonster` 基类实现（`:12-682`）

- **`Create`（`:321-332`）**：`ViewRange:=5`、`RunNextTick:=250`、
  `SearchRate:=3000+Random(2000)`、`RaceServer:=RC_MONSTER`；`DupMode/RunDone:=FALSE`。
- **`MakeClone(mname, src)`（`:339-368`）**：在 `src` 坐标 `AddCreatureSysop` 造一只，
  复制 `Master`/`MasterRoyaltyTime`/`SlaveMakeLevel`/`SlaveExpLevel`，`RecalcAbilitys`+`ChangeNameColor`，
  加入 `Master.SlaveList`，再**整块复制** `WAbil`/`StatusArr`/`StatusValue`/`TargetCret`/
  `TargetFocusTime`/`LastHiter`/`LastHitTime`/`Dir`。→ **「召唤克隆」的通用实现**（神兽变身用它）。
- **`Think`（`:382-408`）**：每 3 s 检查一次；`PEnvir.GetDupCount(CX,CY)>=2`（**格子上重叠≥2**）→
  `DupMode`；`not IsProperTarget(TargetCret)` → 清目标。`DupMode and not BoDontMove` 时
  `WalkTo(Random(8))` 一步，走开则 `DupMode:=FALSE`。→ **防止怪物叠在同一格的「挤开」逻辑**。
- **`AttackTarget`（`:410-433`）**：目标存活 + `IsProperTarget` + `TargetInAttackRange`，
  过 `GetCurrentTime-HitTime > GetNextHitTime` 门 → `Attack` + `BreakHolySeize`；
  不在范围则 `SetTargetXY` 追或 `LoseTarget`。
- **`Run`（`:435-549`）**：门 `not HideMode and not BoStoneMode and IsMoveAble`。
  `Think` 为真则先 `inherited Run` 退出。`WalkCurStep/WalkStep/WalkWaitTime` 实现**走走停停**。
  非逃跑模式：攻击成功时若 `Master<>nil` 且 `ForceMoveToMaster` → 瞬移到主人身后；
  否则跟主人（`GetBackPosition(Master)`，超过 20 格/换图/强制 → `SpaceMove`）；
  `BoHasMission` 时走向 `Mission_X/Y`；`TargetX<>-1` → `GotoTargetXY`，否则
  `TargetCret=nil 且 (RefObjCount>0 or HideMode)` → `Wondering`。
  ⚠️ **静态缺陷**（`:492`）：`if (abs(TargetX-bx) > 1) or (abs(TargetY-bx) > 1)` ——
  **Y 分量误用了 `bx`**（应为 `by`），导致「跟随主人」的位移判定在 Y 轴恒等于 X 轴差值。
- **`RecalcAbilitys`（`:551-682`）**：`AddAbil` 清零；`WAbil:=Abil` 但保留 HP/MP；重量清零；
  `AntiPoison/PoisonRecover/HealthRecover/SpellRecover/Luck/HitSpeed:=0`，**`AntiMagic:=1`**
  （注释「기본 10% => 2%」自相矛盾）；清一批 `BoAbil*`；按 `BoFixedHideMode+STATE_TRANSPARENT`
  重算隐身；`RecalcHitSpeed`；把 `AddAbil` 的 SPEED/HIT/抗性/幸运叠加；`MaxHP/MaxMP:=Abil+AddAbil`；
  `AC/MAC/DC/MC/SC := MakeWord(低+低, 高+高)`；
  `STATE_DEFENCEUP/MAGDEFENCEUP` 用**新公式** `_MIN(255, 高字节 + Level div 7 + StatusValue[])`
  （旧公式注释保留）；`ExtraAbil[DCUP/MCUP/SCUP/HITSPEEDUP/HPUP/MPUP]` 叠加；
  `RaceServer>=RC_ANIMAL` → `ApplySlaveLevelAbilitys`。

### 11.2 按类实现一览（32 类）

| 类 | 行 | 机制要点 |
|---|---|---|
| `TChickenDeer` | `:687-736` | **纯逃跑**：扫描可见目标 → `BoRunAwayMode`；6 格内朝反方向跑 |
| `TATMonster` | `:740-763` | 远程攻击基类，`SearchRate:=1500+Random(1500)`；每 8 s（无目标 1 s）`MonsterNormalAttack` |
| `TSlowATMonster`/`TScorpion` | `:768-783` | `TScorpion` 置 `BoAnimal`（可屠宰出蝎尾） |
| `TSpitSpider` | `:790-872` | `BoUsePoison`；`SpitAttack` 用 **`SpitMap[dir]` 5×5 方向模板**逐格判定；命中门 `Random(cret.SpeedPoint)<AccuracyPoint`；走**魔法防御** `GetMagStruckDamage`；毒 `POISON_DECHEALTH 30`（1/`20+AntiPoison`）；`AttackTarget` 用 `TargetInSpitRange` |
| `THighRiskSpider`/`TBigPoisionSpider` | `:881-898` | 前者不动物不毒；后者动物+毒 |
| `TGasAttackMonster` | `:906-981` | `GasAttack` 打**正前方一格** `GetFrontCret`；`RC_TOXICGHOST`→`POISON_DECHEALTH`，否则 `POISON_STONE 5`（**麻痹**） |
| `TCowMonster`/`TMagCowMonster` | `:988-1060` | 后者 `MagicAttack` 命中门是 **`cret.AntiMagic <= Random(50)`**（魔法回避），非 SpeedPoint |
| `TCowKingMonster` | `:1067-1144` | `RushMode`；每 30 s 若 `SiegeLockCount>=5`（被 5 人围）**瞬移脱围**；`CrazyCount:=7-HP/(MaxHP/7)`，≥2 进 8 s `CrazyReadyMode`（`NextHitTime:=10000`）再 8 s `CrazyKingMode`（`NextHitTime:=500`/`NextWalkTime:=400`）；`Attack` 是 `HitHit2(target, pwr div 2, pwr div 2, TRUE)` |
| `TLightingZombi` | `:1150-1216` | `LightingAttack` 发 `RM_LIGHTING` + `MagPassThroughMagic`（**穿透直线 9 格**）；4 格内后撤、6 格内攻击 |
| `TDigOutZombi` | `:1223-1282` | `HideMode`；`ComeOut` 建 **`ET_DIGOUTZOMBI` 事件（5 min）** 后现身（`server.md §10.3` 的「洞」机制）；3 格内有目标才出土 |
| `TZilKinZombi` | `:1289-1329` | **复活僵尸**：`LifeCount` 1/3 概率 1+Random(3)；`Die` 后 (4+Random(20))s 复活，`MaxHP/=2`、`FightExp/=2`、满血 |
| `TWhiteSkeleton` | `:1336-1375` | 召唤物；`ResetSkeleton` 用 `SlaveMakeLevel` 缩短出手/走间隔（`3000-Level*600`） |
| `TScultureMonster` | `:1381-1452` | **石像怪**：初始 `BoStoneMode`/`STATE_STONE_MODE`/不可动；目标进 `MeltArea=2` → `MeltStoneAll`（连同 7 格内同类一起解石） |
| `TScultureKingMonster` | `:1459-1582` | `DangerLevel=5`；`MeltStone` 建 **`ET_SCULPEICE` 事件**；`CallFollower` 造 6+Random(6) 只 `__ZumaMonster1..4`（上限 30）；HP 每跌 1/5 触发一次召唤（5 次），满血重置 |
| `TGasMothMonster` | `:1588-1628` | 用 **`MonsterDetecterAttack`（可看破隐身）**；毒气 1/3 概率破隐身（`STATE_TRANSPARENT:=1`） |
| `TGasDungMonster` | `:1634-1638` | 同上模板（麻痹毒） |
| `TElfMonster` / `TElfWarriorMonster` | `:1644-1793` | **神兽两形态互变**：无目标/主人无目标时 `MakeClone(__ShinSu1/__ShinSu)` 变身，`Master:=nil`+`KickException`；死后 2 s `MakeGhost`（无尸体）；变身后 800 ms 延迟、60 s 才能再变 |
| `TCriticalMonster` | `:1800-1820` | 每击 `criticalpoint++`；`>5 或 Random(10)=0` → 暴击 `pwr := Round(pwr*(Abil.MaxMP/10))`，走 `RM_LIGHTING`（`HitHitEx2`） |
| `TDoubleCriticalMonster` | `:1827-1888` | 同上，但暴击是 **`SpitMap` 5×5 范围**（`DoubleCriticalAttack`） |
| `TSkeletonSoldier` | `:1891-1950` | 5×5 范围物理攻击（`HitHit2`），`TargetInSpitRange` 判定 |
| `TSkeletonKingMonster` | `:1952-2069` | `ChainShotCount=6`；`CallFollower` 造 4+Random(4) 只（韩版「해골무장/궁수/병졸」，非韩版 BoneCaptain/Archer/Spearman，上限 20）；`RangeAttack` = **飞斧式**（`CanFly`+`RM_FLYAXE`+延迟 `600+max(|dx|,|dy|)*50`）；7 格内近战/连射、8–11 格追击 |
| `TBanyaGuardMonster` | `:2072-2156` | `BoCallFollower:=FALSE`；`RangeAttack` 闪电直线 + **目标格范围伤害**（800 ms）；近战需 `Random(3)<>0` |
| `TDeadCowKingMonster` | `:2159-2277` | 「사우천왕」：`Attack` 打**自身 3×3**（200 ms）；`RangeAttack` 打**目标 5×5**（800 ms） |
| `TStoneMonster` | `:2280-2352` | 「마계석」`StickMode`；每 5 s 给 3 格内**非玩家/非召唤**怪上 buff：`RC_PBMSTONE1`→`EABIL_DCUP=15`（15.1 s），否则 `STATE_DEFENCEUP/MAGDEFENCEUP=8`；`RecalcAbilitys` |
| `TPBKingMonster` | `:2355-2580` | 「파황마신」：`Run` 在贴图边（`CX<50 / CX>W-70 / CY<40 / CY>H-70`）**瞬移回内圈**防被引到角落杀；`Attack` 5×5 魔法伤害 + 1/10 石化毒 + **按方向推人**（`Random(20)<4+(60-Level)` → `CharPushed(dir,3+Random(3))`）；`RangeAttack` = 父类 + **视野内所有玩家/召唤掉 1/4 HP**（`DamageHealth`）；`AttackTarget` 12 格内、1/3 随机换目标 |
| `TGoldenImugi` | `:2583-2995` | 「황금이무기/부룡금사」**双子 Boss**（详见 §11.3） |
| `TPhisicalFarAttackMonster` | `:2998-3094` | 物理远程；`RangeAttack` 伤害可**按目标等级缩放**（`MultiplyTargetLevelMin/Max`）；5 格内打、≤2 格 1/3 后撤、>5 格 1/2 靠近 |

### 11.3 `TGoldenImugi` 双子 Boss 机制（`:2583-2995`）

- **孪生维持**：每 3 s 全图扫描 `RC_GOLDENIMUGI`。`>2` 只 → 多余 `MakeGhost(8)`；
  `=2` 且相距 ≥10 → **`WarpTime` 较旧的一只瞬移到另一只旁**；≤2 格 → 1/3 概率分开。
  `=1` 只且 `TwinGenDelay<=0` → `AddCreatureSysop(__GoldenImugi)` **复活伴侣**（HP=2/3 Max，
  特效 `NE_SN_RELIVE`）；复活期间广播 `RM_CRY`。
- **休眠/苏醒**：`DontAttack` 初始 TRUE；被 `Struck` 或收到 `RM_MAKEPOISON` → FALSE。
  `AttackState`/`InitialState` 切换 `BoDontMove` 与 `RM_TURN`/`RM_DIGDOWN` 动画。
- **白蛇联动**：统计名为 `__WhiteSnake` 的存活怪，`HealthRecover := snakecount*2`（**回血随白蛇数**）；
  HP≤50% 一次性召唤 2 条白蛇；HP≤10% 一次性 `MagDefenceUp(60,20)`+`MagMagDefenceUp(60,20)`、
  `LoseTarget`、`RandomSpaceMoveInRange(0,30,80)` 随机传送（`FinalWarp`）。
- **攻击三态**：近战 `SpitMap` 5×5；`RangeAttack` 单格范围魔法（`RM_LIGHTING_1`，800 ms）；
  `RangeAttack2` 全视野玩家/召唤 `MakePoison(POISON_DAMAGEARMOR,60,5)` + `NE_POISONFOG`。
  目标锁定有 4–7 s 记忆（`OldTargetCret`/`TargetTime`），8 s 后随机换目标。
- **死亡掉落**：`Die` 时若只剩自己（`imugicount=1`）→ `BoNoItem:=FALSE`（**最后一只才掉物品**）。

### 11.4 与 EI / Zircon 对照与未验证项

| 项 | 原版反编译 | 源码 | 结论 |
|---|---|---|---|
| 石像解石/召唤 | 未闭合 | `ET_SCULPEICE`/`ET_DIGOUTZOMBI` 事件 | `source-only` |
| 双子 Boss 孪生维持 | 未闭合 | `WarpTime` 比较 + 复活 | `source-only` |
| 远程怪风筝 | 未闭合 | 见 `ObjAxeMon`/`TPhisicalFarAttackMonster` | `source-only` |

未验证：`SpitMap`/`TargetInSpitRange`/`TargetInAttackRange`/`GetBackPosition`/`CharPushed`/
`MagPassThroughMagic`/`AddCreatureSysop` 的具体实现（在 `ObjBase.pas`/`Envir.pas`）；
`__ZumaMonster*`/`__GoldenImugi`/`__WhiteSnake`/`__ShinSu*` 的常量值与 `MonGen.txt` 的
`MonName`→类映射（工厂在 `UsrEngn.AddCreature`，本轮未逐行核对）；无 Delphi/运行期验证。

---

## 12. `ObjMon2.pas` 实现精读（Round 936，1,817 行 / 17 类）

> 种族常量（`Grobal2.pas`）：`RC_KILLINGHERB=85`（식인초）、`RC_MINE=141`（지뢰）、
> `RC_STICKBLOCK=153`（호혼석）、`RC_ARCHERGUARD=112`、`RC_ARCHERPOLICE=20`、`RC_PBMSTONE1=138`。

### 12.1 「潜地」族：`TStickMonster` / `TMineMonster`（`:14-429`）

- `TStickMonster`（`TAnimal` 派生）：`HideMode+StickMode`、`DigupRange/DigdownRange=4`。
  `CheckComeOut` 玩家进入 `DigupRange` → `ComeOut`（`RM_DIGUP`）；目标超出 `DigdownRange` → `ComeDown`
  （`RM_DIGDOWN`，并**手动 `Dispose` 掉 `VisibleActors` 里每个 `PTVisibleActor` 再 `Clear`**）。
- `TMineMonster`（地雷，`RC_MINE`）：`AttackTarget` **直接把 `WAbil.HP:=0`** ——
  踩到即自爆（与 `TExplosionSpider` 同类效果，但无范围伤害代码，靠 `Die` 结算）。

### 12.2 巢穴/召唤族

| 类 | 行 | 机制 |
|---|---|---|
| `TBeeQueen`（비막원충/蜂巢） | `:435-508` | `StickMode`；`MakeChildBee` 发延迟 `RM_ZEN_BEE`（500 ms）→ `AddCreatureSysop(__Bee)` 并 `SelectTarget(TargetCret)`；上限 15；每轮清理死亡子体 |
| `TSpiderHouseMonster`（거미집/蜘蛛巢） | `:754-834` | 同上，产 `__Spider`，**位置固定在 `CY+1`** 且 `CanWalk` 才生 |
| `TCentipedeKingMonster`（지네왕/촉룡신） | `:515-630` | 潜地 10 s 后才出土；`ComeOut` **回满 HP**；`AttackTarget` 对 `ViewRange` 内**所有**目标发 `RM_DELAYMAGIC`（range 2），1/4 概率附带 `POISON_DECHEALTH 60` 或 `POISON_STONE 5`；出土 3 s 后才攻击、10 s 无目标再入地 |
| `TBigHeartMonster`（적월마/심장怪） | `:636-691` | `ViewRange=16`；对视野内**所有**目标发 `RM_DELAYMAGIC`（range 1）+ `NE_HEARTPALP` 特效（原「脚印事件」已注释） |

### 12.3 特殊耐久/掉落

- `TBamTreeMonster`（밤나무）：`Run` 每轮把 `WAbil.HP` 拉满；**只有 `StruckCount >= DeathStruckCount`
  才置 HP=0** —— `DeathStruckCount` 在首次 `Run` 时捕获为 `WAbil.MaxHP`，
  即**「砍够 MaxHP 次才倒」的计数式血条**（伤害数值无关）。
- `TMonsterBox`（몬스터박스）：`Die` 后 1/10 概率 `AddCreatureSysop('사슴')`（鹿）。
- `TExplosionSpider`（자폭거미）：目标进范围即 `DoSelfExplosion`（HP=0 + 3×3 内
  `GetHitStruckDamage(pwr/2)+GetMagStruckDamage(pwr/2)`）；或**出生 60 s 后自爆**。

### 12.4 守卫 / 城门 / 城墙（`:103-1390`）

- `TGuardUnit.Struck`（`:917-924`）：被打时给 `hiter` 打上 **`BoCrimeforCastle`+时间**
  （城堡犯罪标记，`IsProperTarget` 见 `server.md §10.12`；源码注释「2 分钟」但写「5분」）。
- `TArcherGuard`（궁수경비，`RC_ARCHERGUARD`）：`Castle:=nil`、`OriginDir:=-1`；
  `ShotArrow` = 飞斧式（`GetHitStruckDamage`、`ExpHiter:=nil`、延迟 `600+max(|dx|,|dy|)*50`）；
  `Run` 选曼哈顿最近合法目标，无目标时 `Turn(OriginDir)` 复位朝向。
- `TArcherMaster`（궁수호위병，`TATMonster`）：`ShotArrow` 伤害**按目标等级缩放**
  （`MultiplyTargetLevelMin/Max`）；`Run` 贴脸 1/3 后撤、>5 格 1/2 靠近。
- `TArcherPolice`（궁수경찰，`RC_ARCHERPOLICE`）：注释「평화모드로 공격이 안되게」。
- `TCastleDoor`（성문）：`BoOpenState`；`Dir` 由 `3 - Round(HP/MaxHP*3)` 得到 **0/1/2 三档破损外观**；
  `ActiveDoorWall` 用 `PEnvir.GetMarkMovement` **标记 10 个格子的可通行性**（开门时留 3 格不可走=门框）；
  `OpenDoor`/`CloseDoor` 切 `BoStoneMode`（不可被攻击）与 `HoldPlace`（占位）；
  `Die` → `ActiveDoorWall(dsBroken)`；`Run` 死亡时不断刷 `DeathTime`（**尸体不消失**）、`HealthTick:=0`（**不回血**）。
- `TWallStructure`（성벽）：同理，但用 `BoBlockPos` 记录是否已标记阻挡；`Dir` 0..4 五档。

### 12.5 玩法怪

- `TSoccerBall`（축구공，`:1396-1456`）：`NeverDie`；`Struck` 把球沿**攻击者朝向**踢出，
  `GoPower += 4+Random(4)` 封顶 20；`Run` 撞墙按**固定镜像表**反弹
  （`0↔4,1↔7,2↔6,3↔5`），到点停。
- `TStickBlockMonster`（호혼석/魂石，`:1461-1814`）—— **最复杂的小怪**：
  - `CallFollower` 在目标周围 3×3 生成 8 只：**正交位 = 自己的 `UserName`**、
    **对角位 = `'11'`（透明不可见）**；子体 `BoCallFollower:=FALSE`、`Caller:=self`。
  - `RunMsg`：主怪被玩家 `RM_STRUCK` 时，若**没有任何子体先被打**（`FirstStruck`）→
    **主怪立即 `Die`**（「必须先打小的才打大的」机制）；子体被打则**回满 HP** 并把主怪切攻击态。
  - `Run`：出土 10 s 后瞬移到目标旁再召唤；目标消失 15 s 后再 10 s → 主怪自杀。
  - `Die`：连同子体一起死，子体 `LastHiter/ExpHiter:=nil`、`BoNoitem:=TRUE`（**不掉物品**）。

### 12.6 与 EI / Zircon 对照与未验证项

| 项 | 原版反编译 | 源码 | 结论 |
|---|---|---|---|
| 城门 HP→外观三档 | 未闭合 | `3 - Round(HP/MaxHP*3)` | `source-only` |
| 计数式树怪 | 未闭合 | `StruckCount >= MaxHP` | `source-only` |
| 魂石「先小后大」 | 未闭合 | `RunMsg` 主怪秒死 | `source-only` |

未验证：`RC_ARCHERMON`/`RC_ARCHERGUARD`/`RC_ARCHERPOLICE` 在 `MonGen.txt` 的实际用法、
`__Bee`/`__Spider`/`'11'` 的常量值与客户端外观、`GetMarkMovement` 的通行位图语义、
`TGuardUnit.IsProperTarget` 的完整分支（见 `server.md §10.12`）；无 Delphi/运行期验证。

---

## 13. `ObjMon3.pas` 实现精读（Round 937，3,197 行 / 18 类）

> 本文件是**后期扩展怪物/Boss 集**（大量 `sonmg` 注释与 `2003–2005` 时间戳），
> 含神兽/狐狸系列、龙系列、多个地图 Boss。

### 13.1 召唤物：`TAngelMon`（천녀/月령）与 `TCloneMon`（분신/分身）

- `TAngelMon`（`:278-438`，`RC_ANGEL`）：`BeforeRecalcAbility` 按 `SlaveMakeLevel`
  设 `MaxHP 150/200/300/450`、AC、MC；`RangeAttackTo` 是**魔法**（`GetMagStruckDamage`，
  对 `LA_UNDEAD` ×1.5）；`AttackTarget` 要求 `Master<>nil` 且 `TargetCret<>Master`，
  且恒置 `BoLoseTargetMoment:=TRUE`（打完立刻放弃目标，**支援型**）。
- `TCloneMon`（`:445-673`，`RC_CLONE`）：玩家分身。`AfterRecalcAbility` 把
  `WAbil.MaxHP/HP` 复制主人、`AC/MAC` 取主人 `×2/3`。`Run` 的关键机制：
  - `Master.SpellTick := 0`（**主人不回蓝**）、`Self.WAbil.HP := Master.WAbil.HP`（**同步血量**）；
  - 每 `MPSpendTickTime = 600×30` 抽主人 MP：
    `plus := MaxMP div 18 + 1`；`finalplus := -((1+SlaveMakeLevel div 2)*64) + plus + (plus*SpellRecover div 10)`，
    正负分别钳制后写回主人 MP；主人 MP<200 → 分身消失。
  - 死亡 1.5 s 后 `MakeGhost(8)`（无尸体）。

### 13.2 龙系列（화룡/파천마룡）

| 类 | 行 | 机制 |
|---|---|---|
| `TDragon`（화룡/파천마룡，`RC_FIREDRAGON`） | `:676-916` | `ResetLevel` 按 **42 格 `bodypos` 阵列**（近似菱形龙身）生成 42 个 `'00'` 身体怪；`RangeAttack` 按方向发 `RM_DRAGON_FIRE1/2/3`，伤害 `random(HIBYTE(DC))+LOBYTE(DC)+random(LOBYTE(MC))` ×`random(2)+1`，打**目标 5×5**，延迟 `600+max(|dx|,|dy|)*70`；`AttackAll`（1/5 概率）发 `RM_LIGHTING` 打 **21×21**、伤害 ×`random(5)+1`；`AttackTarget` 打完即 `LoseTarget`；`Struck` 在 8 格内给 `RM_DRAGON_EXP`（1–3，见 `items-systems.md §7`） |
| `TDragonBody`（용몸，`RC_DRAGONBODY`） | `:919-976` | `ViewRange=0`、不可动、`AttackTarget` 恒 false；只作为**龙身部位**，被打同样给 `RM_DRAGON_EXP` |
| `TDragonStatue`（용석상，`RC_DRAGONSTATUE`） | `:979-1095` | 固定炮台；`RangeAttack` 打目标 5×5 魔法 |

### 13.3 后期远程怪（`sonmg` 加）

| 类 | 行 | 机制 |
|---|---|---|
| `TEyeProg`（안구충） | `:1098-1170` | `RangeAttack` **把直线上的玩家「吸过来」**（`rushDir=(Dir+4) mod 8`、`rushDist=min(|dx|,|dy|)`、`CharRushRush`）+ `POISON_DECHEALTH`；命中门 `Random(40) > AntiMagic*5 + HIBYTE(AC) div 2`；5 格内近战 |
| `TStoneSpider`（석거미） | `:1173-1274` | `RangeAttack` **闪电直线 13 步**（`RM_MAGSTRUCK` 延迟 600）；近战 1/3 概率附加 `POISON_DECHEALTH` |
| `TGhostTiger`（귀호/鬼虎） | `:1277-1466` | **隐身虎**：每 9–12 s 切换 `STATE_TRANSPARENT`（60000）；冰系 `POISON_SLOW`（时长 `dam div 10`）；`Master.BoSlaveRelax` 或无目标时进入「坐/站」循环（`RM_DIGDOWN`/`RM_TURN` 切 `BoDontMove`） |
| `TJumaThunder`（주마뇌） | `:1470-1574` | `TScultureMonster` 派生、`MeltArea=5`；`RangeAttack` 红色闪电打目标 3×3 |

### 13.4 狐狸系列（비월여우，2005 扩展）

- `TFoxWarrior`（비월여우 전사）：5×5 `SpitMap` 物理；20% 概率 `CriticalMode`（伤害 ×2）；
  `HP < MaxHP/4` → `CrazyKingMode` **60 s 内攻速/移速翻倍**（`oldhittime*2 div 5`、`oldwalktime div 2`）。
- `TFoxWizard`（술사）：近战/`RangeAttack`（直线+范围魔法）；**被打时 30% 概率瞬移**（`RandomSpaceMoveInRange(2,4,4)`，`NE_FOX_MOVEHIDE/SHOW`）。
- `TFoxTaoist`（도사）：`RangeAttack` = **`MagMakeCurseArea` 诅咒**（半径 2、60 s、pwr 70、技能 3）；
  `RangeAttack2` = 直线+范围魔法；**HP≤50% 一次性召唤 4 只狐狸**（`비월흑호`×2 / `비월적호`×2，
  非韩版 `BlackFoxFolks`/`RedFoxFolks`）。
- `TFoxPillar`（호혼기석）：`NeverDie`、固定；`FindTarget` 只选玩家（已锁定后 1/2 概率换目标）；
  `RangeAttack` **把 12 格内目标全部拉过来**（`NE_SIDESTONE_PULL`）；`Attack` 打自身 5×5 魔法。
- `TFoxBead`（비월천주）：**按 HP 分 5 段变身**（`BodyState 1..5`，DC/AC/MAC 递增 10%~80%，发 `RM_FOXSTATE`）；
  `AttackTarget` 随机选招：10% **召唤**（把 30 格内远处玩家拉到身边）、40% **초필살**、
  40% 中心攻击、否则远程；`RangeAttack` 目标 5×5、`RangeAttack2` 全视野诅咒+麻痹+双重魔法；
  `Attack` 自身 7×7 **三连击**（300/600/900 ms）；
  ⚠️ **`Die` 会把全地图所有怪 `NeverDie:=FALSE` 且 `HP:=0`**（**全图清场**，最终 Boss 收尾）。

### 13.5 `TPushedMon`（호기연）与 `TBossTurtle`（거북왕/현무）

- `TPushedMon`（`:2230-2358`）：`AttackWide∈{1,3}` 决定攻击范围；**`DeathCount`=5 或 7**
  （`Initialize`），`Run` 中 `PushedCount >= DeathCount` 才 `Die`；`Struck`/`RunMsg` 恒把
  `WAbil.HP` 拉满 —— 即**「被推动/推击 N 次才死」的计数怪**（`PushedCount` 的递增点不在本文件，
  疑在 `ObjBase`/`CharPushed` 侧，**未验证**）。
- `TBossTurtle`（`:2874-3194`，`ViewRange=17`）：**按血量加权随机选招** ——
  HP≥50%：28% 全体 / 40% 物理A / 30% 物理B / 2% 治疗；HP<50%：43% / 30% / 20% / 7%。
  全体 = 目标 **15×15**（`GetCreatureInRange(targ,7)`）；物理A = 自身 **5×5**；
  物理B = 目标 **3×3**（`GetCreatureInRange(targ,1)`）；治疗 = `IncHealthSpell(1000,0)`。
  伤害统一 `GetAttackPower(DC) + Random(LOBYTE(MC))` 后 ×2。**召唤**：每损失 10% HP
  （`RecallStep` 9→0）发 `RM_LIGHTING_3` 并在上下各 3 格召唤 `갑석귀수`/`갑철귀수` 共 6 只
  （`NE_KINGTURTLE_MOBSHOW`）。

### 13.6 与 EI / Zircon 对照与未验证项

| 项 | 原版反编译 | 源码 | 结论 |
|---|---|---|---|
| 分身抽主人 MP | 未闭合 | `finalplus` 公式 | `source-only` |
| 龙身 42 格阵列 | 未闭合 | `bodypos[42]` | `source-only` |
| Boss 加权选招 | 未闭合 | `Random(10000)` 分档 | `source-only` |
| 全图清场 | 未闭合 | `TFoxBead.Die` | `source-only` |

未验证：`PushedCount` 的递增点、`MagMakeCurseArea`/`CharRushRush`/`IncHealthSpell`/
`RandomSpaceMoveInRange`/`BodyState`（`RM_FOXSTATE`）的完整实现与客户端表现；
`'00'`/`갑석귀수` 等 `MonGen` 名称映射；无 Delphi/运行期验证。
