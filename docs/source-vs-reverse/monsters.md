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
| 71 个类的**各自构造函数**（属性初始化） | 只读了基类与主要分支 |
| `TATMonster.Run` 的完整实现 | 只读了注释 |
| `ObjMon3.pas`（18 类） | 未逐个读 |
| `MakeClone`（怪物克隆/召唤） | 未读 |
| `RecalcAbilitys`（属性重算） | 未读 |
| `TSuperGuard`（`ObjGuard.pas`，继承 `TNormNpc`） | 未读 |
| `TSoccerBall` / `TMineMonster`（特殊玩法怪） | 未读 |
| 怪物与 `MonGen.txt` 的 `MonName` 匹配机制 | 未读（`MonName` → 类实例化的分派点） |
| `Monster.dat` 的二进制表解析 | 未读 |
