# Preview 客户端角色渲染与图库（Actor / magiceff / wm*）

> 证据源：`Source/Client/{Actor,AxeMon,HerbActor,magiceff}.pas` +
> `{wmM2Zip,wmMyImage,wmUtil}.pas`。证据等级 `secondary-source`。
> 机器可读：[`actor-frames.tsv`](actor-frames.tsv)（46 表 / 329 项）。
> 提取器：`Tools/source-read/extract_actor_frames.py`。

---

## 1. `Actor.pas`（4,743 行）—— 角色渲染核心

### 1.1 类层次（3 类）

```
TActor      (:911)   ← 所有可见实体
├── TNpcActor (:1111)  NPC
└── THumActor (:1129)  人物
```

> **注意：怪物不在 `Actor.pas`** —— 客户端怪物渲染在 `AxeMon.pas`（见 §3）。

### 1.2 动作帧表结构（**渲染系统的核心**）

`TMonsterAction`（`:61-70`）/ `THumanAction` 都是 **7 个 `TActionInfo`**：

```pascal
TMonsterAction = record
   ActStand:      TActionInfo;   // 注释标了 1
   ActWalk:       TActionInfo;   // 8
   ActAttack:     TActionInfo;   // 6
   ActCritical:   TActionInfo;   // 6
   ActStruck:     TActionInfo;   // 3
   ActDie:        TActionInfo;   // 4
   ActDeath:      TActionInfo;
end;
```

`TActionInfo` 五字段：`start` / `frame` / `skip` / `ftime` / `usetick`。

### 1.3 **动作帧计算公式**（`CalcActorFrame`，`:1481-1569`）

```pascal
startframe := pm.ActXxx.start + Dir * (pm.ActXxx.frame + pm.ActXxx.skip);
endframe   := startframe + pm.ActXxx.frame - 1;
frametime  := pm.ActXxx.ftime;
```

**这是整个客户端渲染的基石公式**：

| 字段 | 语义 |
|---|---|
| `start` | 该动作的**起始帧号** |
| `frame` | 该动作的**帧数** |
| **`skip`** | **方向间的间隔帧数**（8 方向 × (frame+skip) 的步进） |
| `ftime` | **每帧毫秒数**（帧时长） |
| `usetick` | 移动节拍（`maxtick`/`curtick` 用） |

**`skip` 的含义**：一个动作在资源库里按**8 个方向**排列，
每个方向占 `frame + skip` 帧 —— 即**每方向帧之间有空隙**。
`Dir * (frame + skip)` 就是「跳到第 Dir 个方向」的偏移。

**实例验证（`HA.ActStand`：`start=0, frame=4, skip=6`）**：

| Dir | startframe |
|---:|---:|
| 0 | `0 + 0*10 = 0` |
| 1 | `0 + 1*10 = 10` |
| 2 | `20` |
| … | … |
| 7 | `70` |

即站立动作占 `0..3, 10..13, 20..23, …, 70..73`。

### 1.4 `CurrentAction` 到动作表的映射（`:1493-1568`）

| `CurrentAction` | 用哪个 `Act*` | 备注 |
|---|---|---|
| `SM_TURN` | `ActStand` | 转向 = 播站立帧 |
| `SM_WALK`/`SM_RUSH`/`SM_RUSHKUNG`/`SM_BACKSTEP` | `ActWalk` | **4 个消息共用走动作** |
| `SM_HIT` | `ActAttack` | 攻击 |
| `SM_STRUCK` | `ActStruck` | 被击 |
| `SM_DEATH` | `ActDie` | **`startframe := endframe`（倒放！）** |
| `SM_NOWDEATH` | `ActDie` | 正放 |
| `SM_SKELETON` | `ActDeath` | 尸体/骷髅态 |

**三个关键点**：
1. **`SM_DEATH` 倒放**（`:1550` `startframe := endframe;`）——
   死亡动画从最后一帧往回播（「倒地」效果）。
   `SM_NOWDEATH` 是**正放**版本（立即死亡，不播倒地过程）。
2. **走/跑/后退共用 `ActWalk`** —— 由消息类型区分语义，动作帧相同。
3. **`SM_BACKSTEP` 用 `Shift(GetBack(Dir), ...)`** —— **方向反转**
   （`GetBack(Dir)` 返回反向）。

### 1.5 人物动作表 `HA`（`:73-89`，14 项）

| 动作 | start | frame | skip | ftime | 说明 |
|---|---:|---:|---:|---:|---|
| `ActStand` | 0 | 4 | 6 | 200 | 站立 |
| `ActWalk` | 1680 | 6 | 4 | 90 | 行走 |
| `ActRun` | 1760 | 6 | 4 | 120 | 奔跑 |
| `ActRushLeft` | 128 | 3 | 5 | 120 | 冲刺左 |
| `ActRushRight` | 131 | 3 | 5 | 120 | 冲刺右 |
| `ActWarMode` | 560 | 3 | 7 | 200 | 战斗姿态 |
| **`ActHit`** | **720** | 6 | 4 | **85** | 攻击 |
| `ActHeavyHit` | 800 | 6 | 4 | 85 | 重击 |
| `ActBigHit` | 880 | 6 | 4 | 85 | 大击 |
| `ActFireHitReady` | 192 | 6 | 4 | **70** | 火击准备 |
| `ActSpell` | 240 | 5 | 5 | **75** | 施法 |
| `ActSitdown` | 640 | 2 | 8 | **400** | 坐下（最慢） |
| `ActStruck` | 1200 | 3 | 7 | 100 | 被击 |
| `ActDie` | 1520 | 10 | 0 | 120 | 死亡（**skip=0**，10 帧） |

**⚠️ `ActHit` 有两个定义**（`:80` 的 `start=200,frame=5,skip=3,ftime=140`
**被注释掉**，`:81` 的 `start=720` 生效）—— **攻击动作被改过**。
本工具已排除注释行。

**`ActDie` 的 `skip=0`** —— 死亡动画**只有 1 个方向**（不需要 8 方向）。

### 1.6 怪物动作表（46 个表 / 329 项）

`MA9` … `MA62` 共 **45 个怪物动作表**（`MA9` 注释「축구공」= 足球，
即 `TSoccerBall` 用的）。**大部分是 7 项**（标准 7 动作），
`MA19`/`MA57` 是 **9-15 项**（有额外动作）。

> **对 `Tools/magiclab` / `ClientData/frame-formulas.json` 的意义**：
> `actor-frames.tsv` 是**帧公式的权威表**。本仓库既有的
> `ClientData/frame-formulas.json` 应与它逐项对照 —— **标注为后续工作**。

### 1.7 其他关键方法

| 方法 | 行 | 语义 |
|---|---|---|
| `SendMsg`/`UpdateMsg` | `:1414`/`:1430` | 发送/更新实体消息 |
| `CleanUserMsgs` | `:1464` | 清理用户消息 |
| `ReadyAction` | `:1571` | **准备动作**（消息 → 动作状态） |
| `ProcMsg`/`ProcHurryMsg` | `:1748`/`:1817` | 处理消息/紧急消息（注释「빠르게 처리하는 메시지」） |
| `Shift` | `:1910`/`:2093` | **两个同名重载**（一个是方向偏移） |
| `DrawEffSurface` | `:2329` | 绘制特效面（带 `blend`/`ceff`） |
| `DrawWeaponGlimmer` | `:2356` | 武器闪光 |
| `GetDrawEffectValue` | `:2378` | 绘制特效值 |
| `DefaultMotion` | `:2499` | 默认动作（注释「동작 없음, 기본 자세」= 无动作、基本姿态） |
| `SetSound` | `:2511` | 音效 |
| `Run` | `:2875` | **主更新循环** |
| `MoveFail`/`CancelAction` | `:3183`/`:3201` | 移动失败/取消动作 |
| `Say` | `:3220` | 说话 |

> ✅ **`Shift` 的重复定义已查明**：`:1910` 是**生效版本**；
> `:2093` 的第二个定义**被 `{ }` 块注释掉**（`:2092` 是 `{`，块延伸到其后）。
> 即**只有一个 `Shift` 生效**，不是重载。**读代码时的陷阱**：
> 同文件里有被大括号注释掉的重复函数，静态 grep 会看到两个。

---

## 2. `magiceff.pas` —— 魔法特效

**未读**（标注 pending）。已知它在 `Mir3.dpr` 的 uses 列表里（`client.md` §1）。

---

## 3. `AxeMon.pas`（客户端怪物渲染）

> ⚠️ **与 `Source/GameServer/ObjAxeMon.pas` 是不同文件** ——
> 前者是**客户端渲染**，后者是**服务端怪物类**（`monsters.md` §1）。

**未读**（标注 pending）。

---

## 4. `HerbActor.pas`（采集对象）

**未读**（标注 pending）。

---

## 5. 图库变体（`wmM2Zip` / `wmMyImage` / `wmUtil`）

### 5.1 已知（来自 `client-libraries.md`）

- `TWILType` 9 种格式（`WIL.pas:39`）：`t_wmM2Def`/`t_wmM2Def16`/`t_wmM2wis`/
  **`t_wmMyImage`（= `.Lib`）**/`t_wmM3Def`（= `.wil`）/`t_wmWoool`/`t_wm521g`/
  `t_wmM2Zip`/`t_wmM3Zip`
- `wmM3Zip.pas`（`.Zl` 压缩）已读：25B 索引头 + 17B 图头 + zlib
- `wmUtil.pas`（4,497 行）**未读** —— 是图像/压缩工具库

### 5.2 本阶段新增

| 文件 | 行数 | 状态 |
|---|---:|---|
| `wmM2Zip.pas` | — | **未读**（Mir2 压缩变体） |
| `wmMyImage.pas` | — | **未读**（`.Lib` 格式解析器） |
| `wmUtil.pas` | 4,497 | **未读** |

**这三个是图库解析的最后缺口**。`wmMyImage.pas` 尤其重要 ——
它解析的是 Preview 版**优先加载**的 `.Lib` 格式。

---

## 6. 与 EI 证据 / Zircon 的对照

| 项 | 原版反编译 | 源码 | Zircon |
|---|---|---|---|
| 动作帧公式 | 未闭合 | **`start + Dir*(frame+skip)`** | `FrameSet`（`ClientData`） |
| 人物动作数 | 未闭合 | 14 项（`HA`） | — |
| 怪物动作表 | 未闭合 | 45 个 `MA*` 表 | `FrameSet` |
| 死亡倒放 | 未闭合 | `SM_DEATH` 用 `startframe := endframe` | — |
| 8 方向布局 | 未闭合 | 每方向占 `frame+skip` 帧 | — |
| `.Lib` 格式 | 未闭合 | `wmMyImage.pas`（**未读**） | — |

**分级**：源码结论均 `secondary-source`。

---

## 7. 未验证项

| 项 | 原因 |
|---|---|
| `magiceff.pas` | 未读 |
| `AxeMon.pas`（客户端怪物渲染） | 未读 |
| `HerbActor.pas` | 未读 |
| `wmM2Zip.pas` / `wmMyImage.pas` / `wmUtil.pas`（4,497 行） | 未读 |
| `TActor.Run`（`:2875`，主更新循环） | 未读 |
| `ReadyAction`（消息 → 动作状态） | 未读 |
| `THumActor`/`TNpcActor` 的特有实现 | 未读 |
| `actor-frames.tsv` 与 `ClientData/frame-formulas.json` 的对照 | 超出本 Goal（Zircon 侧） |

---

## 8. 客户端渲染类层次（AxeMon / HerbActor / magiceff）（Round 826）

> 机器可读：[`client-render-classes.tsv`](client-render-classes.tsv)（60 类）。
> 提取器：`Tools/source-read/extract_render_classes.py`。

### 8.1 三文件的类分布

| 文件 | 类数 | 内容 |
|---|---:|---|
| `AxeMon.pas`（4,217 行） | **35** | 客户端怪物渲染（骷髅/猫/蝎/僵尸/毒气怪…） |
| `HerbActor.pas`（993 行） | **10** | 采集物/特殊对象（矿/蜂王/蜈蚣王/城门/城墙/足球…） |
| `magiceff.pas`（1,621 行） | **15** | 魔法特效 |

**继承深度**：1 层 19 / 2 层 29 / 3 层 6 / 4 层 1 / **5 层 4** / **6 层 1**（最深）。

### 8.2 `AxeMon.pas` —— **客户端怪物渲染**（35 类）

> ⚠️ **与 `GameServer/ObjAxeMon.pas` 是不同文件** ——
> 前者是**客户端渲染**，后者是**服务端怪物类**（`monsters.md` §1）。

**两个顶层基类**：

| 基类 | 行 | 派生数 |
|---|---:|---:|
| **`TSkeletonOma` : `TActor`** | `:65` | 最多（见下） |
| `TGasKuDeGi` : `TActor` | `:121` | — |

**`TSkeletonOma` 的主要派生**（`:81-120`）：
`TDualAxeOma`（注释「두번찍지는 놈」= 两连击的家伙）、
`TCatMon` → `TArcherMon`（弓手）/ `TScorpionMon`（蝎子）、
`THuSuABi`、`TZombiDigOut`（破土僵尸）、`TZombiZilkin`、`TWhiteSkeleton`。

**注意与 `monsters.md` §1 的服务端类对照**：
服务端有 `TMonster`/`TATMonster`/`TWhiteSkeleton`/`TDigOutZombi` 等，
客户端有 `TSkeletonOma`/`TCatMon`/`TZombiDigOut` 等 ——
**两边类名与层次结构不同**（各自独立实现，只共享 `Race`/`Appearance` 数值约定）。

### 8.3 `HerbActor.pas` —— 采集物与特殊对象（10 类）

**顶层基类**（都继承 `TActor`）：`TKillingHerb`（`:19`，**可采集物基类**）、
`TBeeQueen`、`TCastleDoor`、`TWallStructure`、`TSoccerBall`。

**`TKillingHerb` 的派生**（`:28-108`）：`TMineMon`（矿）、
`TCentipedeKingMon`（蜈蚣王）、`TBigHeartMon`（大心怪）、
`TSpiderHouseMon`（蜘蛛巢）、**`TDragonBody`**（注释「화룡몸 FireDragon」= 火龙身体）。

**独立类**：`TCastleDoor`（城门）、`TWallStructure`（城墙结构）、
`TSoccerBall`（足球）。

> **`TCastleDoor`/`TWallStructure` 是「攻城」的客户端表现** ——
> 与 `Castle.pas` 的 `CASTLEMAINDOORREPAREGOLD` 等费用常量
> （`items-systems.md` §3）配套。

### 8.4 `magiceff.pas` —— 魔法特效运行时（15 类）

#### 8.4.1 `TMagicEff` 基类（`:118-165`）—— **双坐标系**

| 字段组 | 字段 | 语义 |
|---|---|---|
| 状态 | `Active`/`Blend`/`ServerMagicId` | 激活/混合/服务端技能 ID |
| 关联 | `MagOwner`/`TargetActor` | 施法者/目标 |
| 资源 | `ImgLib: TWMImages`/`EffectBase`/`MagExplosionBase` | **图库 + 两个帧基址** |
| **屏幕坐标** | `px`/`py`/`FlyX`/`FlyY`/`OldFlyX`/`OldFlyY` | 像素位置 |
| **地图坐标** | `RX`/`RY`（注释「맵의 좌표로 환산한 좌표」= 换算成地图坐标） | 格坐标 |
| 目标 | `TargetX`/`TargetY`（**屏幕**）/ `TargetRx`/`TargetRy`（**地图**） | 双份 |
| 插值 | **`FlyXf`/`FlyYf: Real`** | **浮点位置**（平滑移动） |
| 方向 | `Dir16`/`OldDir16: byte` | **16 方向** |
| 行为 | `Repetition`（动画重复）/`FixedEffect`（固定动画）/`MagicType`/`NextEffect` | |
| 时间 | `NextFrameTime`/`RepeatUntil`（注释「2003/07/15 시간제 이펙트」= 限时特效） | |
| 其他 | `Light`/`ExCase`（`0: 일반, 1,2..:예외사항` = 0 普通、1,2..例外）/`FireDir` | |

**`Dir16`（16 方向）** 与角色的 8 方向（`client-rendering.md` §1.3 的 `Dir`）不同
—— **特效用更细的 16 方向**。

#### 8.4.2 `Run`（`:820-827`）—— **10 秒硬超时**

```pascal
function TMagicEff.Run: Boolean;
begin
   Result := Shift;
   if Result then
      if GetTickCount - starttime > 10000 then   // ← 注释：//2000 then
         Result := FALSE                          // 超时销毁
      else Result := TRUE;
end;
```

**注释 `//2000 then` 说明超时曾被设为 2 秒，后改为 10 秒**（`10000`）。
→ **特效最长存活 10 秒**，超时自动销毁。

#### 8.4.3 `DrawEff`（`:829-865`）—— **飞行 vs 爆炸两种绘制**

```pascal
if Active and ((Abs(FlyX-fireX) > 15) or (Abs(FlyY-fireY) > 15) or FixedEffect) then begin
   shx := (Myself.RX*UNITX + Myself.ShiftX) - FireMyselfX;   // 施法者屏幕偏移
   shy := (Myself.RY*UNITY + Myself.ShiftY) - FireMyselfY;

   if not FixedEffect then begin          // ← 飞行类
      if ExCase = 1 then img := EffectBase        // FireDragon 特例
      else img := EffectBase + FLYBASE + Dir16 * 10;   // ← Dir16 * 10
      d := ImgLib.GetCachedImage (img + curframe, px, py);
      DrawBlend (surface, FlyX + px - UNITX div 2 - shx, ...);
   end else begin                          // ← 爆炸类
      img := MagExplosionBase + curframe;
      d := ImgLib.GetCachedImage (img, px, py);
      DrawBlend (surface, FlyX + px - UNITX div 2, ...);
   end;
end;
```

**四个关键点**：
1. **触发条件**：距发射点 >15 像素**或** `FixedEffect`（固定特效立即显示）。
2. **`Dir16 * 10`** —— 飞行特效**每方向占 10 帧**
   （与角色动作的 `frame + skip` 不同，这里是固定 10）。
3. **`ExCase = 1` 是 FireDragon 特例**（直接用 `EffectBase`，不偏移）。
4. **飞行类减 `shx`/`shy`（跟随施法者），爆炸类不减** ——
   即**飞行特效跟随施法者滚动，爆炸特效固定在世界坐标**。

#### 8.4.4 `GetFlyXY`（`:807-818`）—— **速度按 ms 归一化**

```pascal
stepx := Round ((firedisX/900) * ms);
stepy := Round ((firedisY/900) * ms);
fx := fireX + stepx;
fy := fireY + stepy;
```

**`/900` 是归一化除数** —— `firedisX`/`firedisY` 是总位移，
除以 900 再乘实际耗时 `ms` → **900ms 走完全程**（即飞行特效标准时长 0.9 秒）。

#### 8.4.5 15 个特效类的基类分布

| 基类 | 派生 |
|---|---|
| `TMagicEff`（直接派生） | `TFlyingAxe`（飞斧）/`TFlyingBug`（飞虫）/`TCharEffect`/`TMapEffect`/`TLightingEffect`/`TFireGunEffect`/`TThuderEffect`/`TThuderEffectEx`/`TLightingThunder`/`TExploBujaukEffect`/`TBujaukGroundEffect`/`TNormalDrawEffect` |
| `TFlyingAxe` | **`TFlyingArrow`**（箭）/ **`TFlyingFireBall`**（火球） |
| `TMapEffect` | `TScrollHideEffect`（卷轴隐身） |

**`TFlyingAxe` 是飞行物的实用基类**（箭/火球都从它派生）——
构造函数（`:872-877`）设 `FlyImageBase := FLYOMAAXEBASE`、`ReadyFrame := 65`。

### 8.5 与 EI 证据 / Zircon 的对照

| 项 | 原版反编译 | 源码 | Zircon |
|---|---|---|---|
| 客户端怪物类 | 未闭合 | 35 类（`AxeMon.pas`） | `ClientData/frame-formulas.json` |
| 服务端怪物类 | 未闭合 | 71 类（`monsters.md`） | `MonsterInfo` |
| **两套类名不同** | — | 客户端 `TSkeletonOma`/`TCatMon` vs 服务端 `TMonster`/`TATMonster` | — |
| 特效方向 | 未闭合 | **`Dir16`（16 方向）** | — |
| 特效帧布局 | 未闭合 | **`Dir16 * 10`（每方向 10 帧）** | — |
| 特效时长 | 未闭合 | **10 秒硬超时**（曾为 2 秒） | — |
| 飞行速度 | 未闭合 | **900ms 走完全程** | — |

**分级**：源码结论均 `secondary-source`。

### 8.6 未验证项

| 项 | 原因 |
|---|---|
| `AxeMon.pas` 各类的 `DrawEff`/`Run` 实现 | 只读了类层次 |
| `HerbActor.pas` 各类的实现 | 只读了类层次 |
| `magiceff.pas` 其余 12 个特效类的实现 | 只读了基类 + `TFlyingAxe` 构造 |
| `FLYBASE`/`EXPLOSIONBASE`/`FLYOMAAXEBASE` 常量值 | 未查 |
| `TMagicType` 枚举 | 未读 |
| `DrawBlend` 的实现 | 未读 |
| ~~`UNITX`/`UNITY` 常量值~~ | ✅ **已查**：`Grobal2.pas:1214-1215` **`UNITX = 48`、`UNITY = 32`** |

### 8.7 【重要】`UNITX = 48` / `UNITY = 32`（已核实）

`Common/Grobal2.pas:1214-1215`：

```pascal
UNITX = 48;
UNITY = 32;
```

**这是等距（isometric）瓦片的屏幕尺寸**：X 方向 48 像素、Y 方向 32 像素。

**⚠️ 这直接确认了本仓库 mapviewer 的坐标换算依据** ——
AGENTS.md §七.5 记录的「实体坐标 ×48/32 换算成像素」
**与源码常量完全一致**。即：

```
屏幕X = 地图X * 48
屏幕Y = 地图Y * 32
```

`magiceff.pas:838-839` 的用法印证：
`shx := (Myself.RX*UNITX + Myself.ShiftX) - FireMyselfX`
—— **`RX * 48` 得屏幕 X，再加滚动偏移 `ShiftX`**。

> **对本仓库的价值**：这是**原版等距瓦片尺寸的权威常量**，
> 可用于校验 `Tools/maps/mapviewer.py` 与 webport 的坐标换算
> —— **标注为后续工作**（与 `client-runtime-layout.tsv` 的逐窗对照同批）。
