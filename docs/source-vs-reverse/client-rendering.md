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

### 1.8 `TActor` 消息管线与主循环实现（Round 941）

#### 1.8.1 消息队列（`MsgList: TList` of `PTChrMsg`）

| 方法 | 行 | 语义 |
|---|---|---|
| `SendMsg` | `:1414` | `new(pmsg)` 填字段后 `MsgList.Add` |
| `UpdateMsg` | `:1430` | **自己是主角**：删除队列里所有**客户端消息**（`Ident 3000..3099`）与同 `Ident` 项，再入队；**别人**：只删第一个同 `Ident` 项再入队（合并同类动作） |
| `CleanUserMsgs` | `:1464` | 只删 `Ident 3000..3099` |
| `ProcMsg` | `:1748` | 逐条出队（**仅当 `CurrentAction=0`**）：`SM_STRUCK` 先记 `HiterCode:=msg.Sound` 再 `ReadyAction`；`SM_DEATH/NOWDEATH/SKELETON/ALIVE/CROSSHIT/TWINHIT/STONEHIT`/`SM_ACTION*`/`SM_DRAGON_LIGHTING..SM_LIGHTING_3`/`3000..3099` → `ReadyAction`；`SM_SPACEMOVE_HIDE(2)` → `TScrollHideEffect`+出音；`SM_SPACEMOVE_SHOW(2)` → `TCharEffect`+**转成 `SM_TURN` 再 `ReadyAction`**+入音 |
| `ProcHurryMsg` | `:1817` | **乱序扫描**：找 `SM_MAGICFIRE`（置 `CurMagic.ServerMagicCode:=111`、目标/类型/效果号）与 `SM_MAGICFIRE_FAIL`（`ServerMagicCode:=0`）并**从队列中间删除** |

#### 1.8.2 `ReadyAction`（`:1571-1746`）—— 消息→动作状态

1. 记录 `actbeforex/y`（供冲刺/回退复位）。
2. 非死亡时：移动类消息写 `Feature`/`State`；`STATE_OPENHEATH` 置 `BoOpenHealth`，
   否则查 `ViewList` 里是否有 `RecogId`（**组队显血**）。
3. **主角**（`self=Myself`）：`CM_WALK` 先 `PlayScene.CanWalk` 否则 `exit`；`CM_RUN` 先
   `CanRun`；`CM_TURN/WALK/SITDOWN/RUN/HIT/POWERHIT/LONGHIT/WIDEHIT/CROSSHIT/HEAVYHIT/BIGHIT`
   存 `RealActionMsg` 并把 `Ident-3000` 转成 `SM_*`；`CM_THROW` 解析目标指针；`CM_SPELL`
   取 `UseMagicInfo`。
4. `SM_STRUCK`：`struckframetime := max(80, 200 - Level*5)`（**等级越高受击动作越快**）；
   被自己/队友打且 `MaxHP<2000` → 60 s 显血（`BoInstanceOpenHealth`）。
5. `SM_SPELL`：`CurMagic := pmag^`、`ServerMagicCode:=-1`（**等服务器 `SM_MAGICFIRE`**）、
   记 `TargX/TargY`，`Dispose(pmag)`。
6. 其余消息：`XX/YY/Dir := msg.*`。
7. `CurrentAction := msg.Ident` + `CalcActorFrame`；`SM_DEATH/NOWDEATH` → 移出组队列表、
   `Death:=TRUE`、`PlayScene.ActorDied(self)`；最后 `RunSound`。

#### 1.8.3 `Run`（`:2875-3007`）—— **魔法需服务器确认才推进**

移动动作（WALK/BACKSTEP/RUN/RUSH/RUSHKUNG）由 `Move` 处理，`Run` 直接 `exit`。
核心是**施法门控**：

```
if BoUseMagic then
   if (CurEffFrame = SpellFrame-2) or MagicTimeOut(>3000ms) then
      if CurMagic.ServerMagicCode >= 0 then 推进帧   // 等服务器 SM_MAGICFIRE
   ...
if BoUseMagic and (CurEffFrame = SpellFrame-1) then  // 发射帧
   if CurMagic.ServerMagicCode > 0 then PlayScene.NewMagic(...) + 音效
```

→ **客户端施法动画会在「发射前 2 帧」停住等服务器回包**（`ProcHurryMsg` 把
`SM_MAGICFIRE` 乱序插队处理）。主角动作结束还需 `FrmMain.ServerAcceptNextAction`。

#### 1.8.4 `Move`（`:3009-3181`）—— 负重/减速/冲刺

- **主角**计算 `MoveSlowLevel`：超重 `Weight div MaxWeight`、超穿戴
  `WearWeight div MaxWearWeight`、`STATE` 位 `$08000000`（POISON_SLOW）额外 +5；
  `SkipTick < MoveSlowLevel` 时**跳过一帧**（变慢）。
- 脚步声：走路第 1、4 帧播 `footstepsound`/`+1`。
- `SM_WALK/RUN/RUSH/RUSHKUNG` 正播、`SM_BACKSTEP` 反播；`SM_RUSH` 结束给 300 ms
  `DizzyDelay`，`SM_BACKSTEP` 结束给 1000 ms；`SM_RUSHKUNG` 在末 3 帧**把位置还原到
  `actbeforex/y`**（冲锋回归）。
- 结束统一 `CurrentAction:=0` + `LockEndFrame:=TRUE` + `smoothmovetime:=now`。

#### 1.8.5 `Say`（`:3220-3277`）

按 `MAXWIDTH=150` 像素用 `FrmMain.Canvas.TextWidth` 折行；`byte(str[i])>=128` 时
**双字节字符成对处理**；最多 `MAXSAY` 行。

#### 1.8.6 `TNpcActor`（`:3285-3658`）—— NPC 只有 3 个方向

`Dir := Dir mod 3`（NPC 资源只有 0/1/2 三方向）。按 `Appearance` 硬编码：
33/34（시공석）、42-47（불항아리/탑불，**各有 ax/ay 位置修正**）、51（귀신 NPC）、
52（눈사람，`SM_DIGUP` 触发 `PlaySnow`+随机歌声 146..152）、61-65（비월신전 불꽃/모닥불）、
66（크리스마스트리）等；`Appearance in [35..41,48..50,52..55,57..65,69..74,78..80]` 强制 `Dir:=0`。
`LoadSurface` 从 `g_WNpcImg` 取；`DrawChr` 对 `[51..57,59,71..75,87]` **不画影子**。

#### 1.8.7 `THumActor`（`:3668-4739`）—— 人物分层渲染

- **偏移量**：`BodyOffset := HUMANFRAME*(Dress div 2)`；`HairOffset := HUMANFRAME*hair`
  （`hair<=1` 时 -1=无头发）；`WeaponOffset` 按武器号（254/101-200 特判）；`WingOffset`
  按礼服 18-23；`WeaponEffectOffset` 按武器 254/76/77。
- **`CalcActorFrame`**：用 `HA` 表；`SM_RUSH` **左右交替**（`RushDir` 0/1 切 `ActRushLeft/Right`）；
  `SM_RUN` `movestep:=2`；攻击动作（HIT/POWERHIT/LONGHIT/WIDEHIT/FIREHIT/CROSSHIT/TWINHIT）
  设 `BoHitEffect`+`MagLight:=2`+`HitEffectNumber 1..7`；`SM_SPELL` 按 `CurMagic.EffectNumber`
  特判（22 뢰설화 `SpellFrame=10`、26 탐기파연=20+`frametime div 2`、35 무극진기=15、
  43 사자후=20/70ms、44 공파섬=大击帧+`HitEffectNumber=8`+音效、45 화룡기염=10+`NE_FIRECIRCLE`、
  47 포승검=10），否则 `DEFSPELLFRAME`。
- **`RunFrameAction`**：`SM_HEAVYHIT` 第 5 帧且 `BoDigFragment` → `TMapEffect` +
  `s_strike_stone` + `ET_PILESTONES` 事件计数 +1；`SM_THROW` 第 3 帧 → `TFlyingAxe`
  （`FLYOMAAXEBASE`），之后 `BoHideWeapon`。
- **`Run`**：`GenAniCount`（120 ms）驱动「주술의막」泡泡动画；`BoWeaponEffect` 武器破碎动画；
  与 `TActor.Run` 同样的**施法服务器确认门控**；主角结束时记 `LatestSpellTime`。
- **`LoadSurface`**：本体 `g_WM_HumImg`/`g_WWM_HumImg`（按 `Sex`）；头发 `g_WM_Hair`/`g_WWM_Hair`；
  翅膀 `g_WGameInter1`（`Dress div 2 = 1`）；武器 `g_WM_Weapon[n]`/`g_WWM_Weapon[n]`
  （`n := (Weapon-1) div 10`，>9 用 `WeaponEx`，254 用 `[4]`）；武器特效 `g_WMonMagicEx[3]`。
- **`DrawChr` 绘制顺序**由 **`WORDER[Sex, currentframe]`**（`wpord`）决定：
  `wpord=0` 先武器后身体，`wpord=1` 先身体后武器（**按视角决定武器遮挡关系**）；
  武器用 `ceNone`（**不染色**）；`Dress in [24,25]` 不画头发；
  `STATE_BUBBLEDEFENCEUP ($00100000)` 画泡泡（`MAGBUBBLEBASE + GenAniCount mod 3`，
  受击时 `MAGBUBBLESTRUCKBASE + CurBubbleStruck`）；
  `BoHitEffect` 特效（**공파섬 `HitEffectNumber=8` 特判**：`g_WMagicEx[1]` 的
  `740+Dir*20+SKillCurrentFrame`；其余用 `GetEffectBase(..,1)`）；
  武器破碎 `WPEFFECTBASE + Dir*10 + CurWpEffect`（`g_WMagic`）。

### 1.9 `Shift` 的重复定义（已查明）

`:1910` 是**生效版本**；`:2093` 的第二个定义**被 `{ }` 块注释掉**（`:2092` 是 `{`）。
即**只有一个 `Shift` 生效**，不是重载。**读代码陷阱**：同文件里有被大括号注释掉的重复函数，
静态 grep 会看到两个。

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

✅ **已闭合**（Round 939，见 §8.3 全实现）。

---

## 5. 图库变体（`wmM2Zip` / `wmMyImage` / `wmUtil`）

### 5.1 已知（来自 `client-libraries.md`）

- `TWILType` 9 种格式（`WIL.pas:39`）：`t_wmM2Def`/`t_wmM2Def16`/`t_wmM2wis`/
  **`t_wmMyImage`（= `.Lib`）**/`t_wmM3Def`（= `.wil`）/`t_wmWoool`/`t_wm521g`/
  `t_wmM2Zip`/`t_wmM3Zip`
- `wmM3Zip.pas`（`.Zl` 压缩）已读：25B 索引头 + 17B 图头 + zlib
- `wmUtil.pas`（4,497 行）✅ **已闭合**（Round 942，见 `client-libraries.md §10`）—— 图像/压缩工具库

### 5.2 本阶段新增

| 文件 | 行数 | 状态 |
|---|---:|---|
| `wmM2Zip.pas` | 302 | ✅ 已闭合（Round 825，`client-libraries.md §9`） |
| `wmMyImage.pas` | 741 | ✅ 已闭合（Round 824，`client-libraries.md §8`） |
| `wmUtil.pas` | 4,497 | ✅ 已闭合（Round 942，`client-libraries.md §10`） |

**图库解析已全部闭合**。`wmMyImage.pas` 是 Preview 版**优先加载**的 `.Lib` 格式解析器。

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
| ~~`AxeMon.pas`（客户端怪物渲染）~~ | ✅ 已闭合（Round 940，§8.2） |
| ~~`HerbActor.pas`~~ | ✅ 已闭合（Round 939，§8.3） |
| ~~`wmM2Zip.pas` / `wmMyImage.pas` / `wmUtil.pas`（4,497 行）~~ | ✅ 已闭合（`client-libraries.md §8-10`） |
| ~~`TActor.Run`（`:2875`，主更新循环）~~ | ✅ 已闭合（Round 941，§1.8.3） |
| ~~`ReadyAction`（消息 → 动作状态）~~ | ✅ 已闭合（Round 941，§1.8.2） |
| ~~`THumActor`/`TNpcActor` 的特有实现~~ | ✅ 已闭合（Round 941，§1.8.6/§1.8.7） |
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

#### 8.2.1 帧基址常量（`:10-62`）

本文件把**大量特效帧基址硬编码为常量**，按怪物分组：
`DEATHEFFECTBASE=340`、`KUDEGIGASBASE=1445`、`COWMONFIREBASE=1800`、`COWMONLIGHTBASE=1900`、
`ZOMBILIGHTINGBASE=350`、`SCULPTUREFIREBASE=1680`、`MOTHPOISONGASBASE=DUNGPOISONGASBASE=3590`、
`SUPERIORGUARDEFFECTBASE=760`、`ELECTRONICSCOPIONEFFECTBASE=430`、`KINGBIGEFFECTBASE=860`、
`TOXICPOISONGASBASE=720`、`SAMURAIDIEBASE=350`、`SKELMUJANGDIEBASE=1160`、`SKELSOLDIERDIEBASE=1600`、
`BANYAGUARDRIGHTDIEBASE=2320`/`LEFTDIEBASE=2870`/`RIGHTHITBASE=2230`/`LEFTHITBASE=2780`/`LEFTFLYBASE=2960`、
`DEADCOWKINGHITBASE=3490`/`FLYBASE=3580`、`PBSTONE1IDLE/ATTACK/DIE=2490/2500/2530`、
`PBSTONE2*=2620/2630/2660`、`PBKINGATTACK1/2=3440/3520`、`PBKINGDIEBASE=3120`，
以及 `SKELETONKINGEFFECT1..8BASE=2980/3060/3140/3220/3300/3380/3400/3570`。

#### 8.2.2 `TSkeletonOma` 基类（`:326-698`）

- **`CalcActorFrame`**：按 `CurrentAction` 展开帧段；**大量按 `Race` 特判** ——
  93/100（환영한호/이무기）用 `SitDown`；107/108/109 站/走/受击**无方向**；111/112 攻击用
  `340+Dir*10`；23/81（백골）`SM_DIGUP` 无方向；55（신수1）`SM_DIGDOWN` 逆播 `ReverseFrame`；
  93/94 自定义帧速（200/150/110/130/160）。
- **`GetDefaultFrame`**：死亡时 `Appearance in [30..34,151]`（우면귀）置 `DownDrawLevel:=1`
  防尸体盖人；`SitDown` 时用 `420+Dir*10+cf`；`Race=110` 按 `TempState` 选 0/80/160/240/320 段；
  108/109/110 触发效果帧（1500+/1610+/1710+）。
- **`Run`**：帧推进；**`msgmuch`（消息队列 ≥2）时帧时长 ×2/3**（加速）；每帧调
  `RunActSound`+`RunFrameAction`；**`Race=92`（주마격뢰장）在 `SM_LIGHTING` 第 4 帧发
  `MAGIC_DUN_THUNDER` + 声音 8301**。
- **`DrawChr`**：`DrawBlendShadow` 画影子（死亡时偏移 +3/+2）+ `DrawEffSurface` 主体 + 效果。

#### 8.2.3 各派生类（要点）

| 类 | 机制 |
|---|---|
| `TDualAxeOma` | `Run` 在 `SM_FLYAXE` 第 `AXEMONATTACKFRAME-4`(=2) 帧发 `TFlyingAxe`；按 `Race` 选 `FlyImageBase`（15→`FLYOMAAXEBASE`、22→`THORNBASE`、111→2356、112→2786）与图库（默认 `g_WMon3Img`，111/112 用 `g_WMon24Img`） |
| `TWarriorElfMonster` | `RunFrameAction`：`SM_HIT` 第 5 帧建 `TMapEffect`（`WARRIORELFFIREBASE+10*Dir+1`，`g_WMon18Img`） |
| `TCatMon` | `DrawChr`：`Race=81`（월령）**不混合、无颜色效果**绘制 |
| `TArcherMon` | `Run` 在 `SM_FLYAXE` 第 4 帧发 `TFlyingArrow`（**新**：`mtFlyArrow`+`ARCHERBASE2`；**旧版注释保留**：`g_WMon5Img`+`ARCHERBASE`） |
| `TZombiDigOut` | `RunFrameAction`：`SM_DIGUP` 第 6 帧建 **`TClEvent` `ET_DIGOUTZOMBI`**（客户端「洞」事件） |
| `THuSuABi` | 攻击效果 `DEATHFIREEFFECTBASE=2860`（`g_WMon3Img`） |
| `TGasKuDeGi` | 大型毒气怪基类（见下 §8.2.4） |
| `TExplosionSpider` | 自爆效果 `730+`（`g_WMon14Img`） |
| `TFlyingSpider` | `SM_NOWDEATH` 建 `TNormalDrawEffect`（`g_WMon12Img` 1420，20 帧） |
| `TFireCowFaceMon`/`TCowFaceKing` | `Light`：有攻击效果时亮度 ≥2（**发光怪**） |
| `TSculptureMon` | `STATE_STONE_MODE` 石像；48/49 攻击效果 `SCULPTUREFIREBASE=1680`（`g_WMon7Img`）；**92（주마격뢰장）站姿自带 940+Dir*10 效果** |
| `TElectronicScolpionMon` | `Race=60`：`SM_LIGHTING` 用 `ELECTRONICSCOPIONEFFECTBASE=430`（`g_WMon19Img`） |
| `TBossPigMon` | `Race=61`：`KINGBIGEFFECTBASE=860`（`g_WMon19Img`） |
| `TKingOfSculpureKingMon` | `Race=62`：攻击/暴击/死亡三段效果（`KINGOFSCOLPTUREKINGATTACK/EFFECT/DEATHEFFECTBASE`，`g_WMon19Img`） |
| `TSkeletonKingMon` | `Race=63`：**8 套效果**（走/受击/近战/飞斧/召唤/死亡/飞行弹）用 `SKELETONKINGEFFECT1..8BASE`（`g_WMon20Img`）；`Run` 在 `SM_FLYAXE` 第 4 帧发 `TFlyingFireBall`（`mtFireBall`，`SKELETONKINGEFFECT8BASE`） |
| `TSkeletonArcherMon` | 死亡效果 `SKELARCHERDIEBASE=1600`（`g_WMon20Img`）；91/94/102 无死亡效果 |
| `TBanyaGuardMon` | 见下 §8.2.5 |
| `TStoneMonster` | `Race=75/77`（마계석）：待机/攻击/死亡效果 `PBSTONE1/2*`（`g_WMon22Img`），`Dir:=0` |
| `TPBOMA1Mon` | `SM_FLYAXE` 第 4 帧发 `TFlyingBug`（`g_WMon22Img` 350，爆炸 430） |
| `TPBOMA6Mon` | 同上发 `TFlyingAxe`（`mtFlyBolt`，`g_WMon22Img` 1989） |
| `TAngel` | **双图层**：`BodySurface` + `BodySurface2`（`1280+currentframe`，透明层）；`DrawChr` 先 `Drawblend` 本体再 `DrawEffSurface` 透明层（`AngelFastDraw` 时强制 `blend:=False`） |
| `TFireDragon` | 见下 §8.2.6 |
| `TDragonStatue` | `Race=84..89`（용석상）：效果 `310`/`330`（`g_WDragonImg`）；`SM_LIGHTING` 第 4 帧发 `MAGIC_FIREBURN`+声音 8222 |
| `TJumaThunderMon` | `Race=92`：走/站/攻击/受击/闪电各有帧段 `1020/940/1100/1180/1200+Dir*10`（`g_WMon23Img`）；石像模式停 `420+Dir*10` |

#### 8.2.4 `TGasKuDeGi` 基类（`:979-1346`）

攻击时**用 `GetFlyDirection16` 把目标屏幕坐标换成 16 方向**（`fire16dir`），
`effectend` 按 `Race=20` 特殊 +1；`LoadSurface` 按 `Race` 分派图库与基址：
24→`SUPERIORGUARDEFFECTBASE`(`g_WMonImg`)、16→`KUDEGIGASBASE`(`g_WMon3Img`)、
20→`COWMONFIREBASE`、21→`COWMONLIGHTBASE`、40→`ZOMBILIGHTINGBASE`(`g_WMon5Img`) 且带
`ZOMBIDIEBASE` 死亡效果、52/95→`MOTHPOISONGASBASE`、53→`DUNGPOISONGASBASE`、
64→`TOXICPOISONGASBASE`(`g_WMon20Img`)、65/66/67/68→各死亡效果。`Race=95` 死亡时**改用
`g_WMon4Img` 3580 混合绘制**。

#### 8.2.5 `TBanyaGuardMon`（`:2189-2771`）—— 后期 Boss 表现

- `LoadSurface` 的**死亡效果**按 `Race`：70/71（반야좌우사）、78（파황마신，`PBKINGDIEBASE`）、
  93（환영한호 1790）、100（황금이무기 2900）、103/104/105（비월여우 340，首帧播 10420）、
  108/109（호기연 1540/1650）——均 `g_WMon21/22/23/24Img`。
- **攻击效果/魔法**按 `Race` 分派（`Run` 中按帧触发）：
  70/81 强격（`MagicNum`）、71 화이어볼、72 마법진、78 地面范围、93 결빙장、
  94 音效、100 **멸천화 `MAGIC_SERPENT_1`**、103 暴击、104 **`MAGIC_FOX_FIRE1`**、
  105 **`MAGIC_FOX_CURSE`/`MAGIC_FOX_FIRE2`**（폭살계）、107 **`MAGIC_SIDESTONE_ATT1`**、
  117 **`MAGIC_TURTLE_WARTERATT`** —— 每个都配固定音效号。

#### 8.2.6 `TFireDragon`（`:3159-3872`）—— 唯一带 `TTimer` 的怪物

- `Create` 建 `LightningTimer`（`Race=83`→70ms，`110`→10ms），`Enabled:=False`。
- `LoadSurface` 用 **`g_WDragonImg`**（`Race=83`，本体帧 10/20/30/40+，效果 60/90/100/110+，
  且 `px/py/ax/ay` **整体 -14/-15**）、`g_WMon24Img`（`110` 1670+）、`g_WMon25Img`（`118` 1650+）。
- `CalcActorFrame`：`Race=110` 按 `TempState` 5 段；`118`（현무현신）有独立 340/420/500/580 攻击帧段。
- `Run`：`Race=118` 的 `SM_LIGHTING_1/2/3` 分别发 `MAGIC_KINGTURTLE_ATT1/ATT2(启 Timer)/ATT3`；
  `110` 发 `MAGIC_SOULBALL_ATT1/ATT2`；`83` 的 `SM_DRAGON_FIRE1/2/3` 发对应魔法 + 声音 8203。
- **`LightningTimerTimer`**：按 `Tag` 计数 0..7，`Race=83` 每次在自身周围随机发
  `SM_DRAGON_LIGHTING` 闪电（interval 递增 +15）；`110` 发 `MAGIC_SOULBALL_ATT3_*`（+100）；
  `118` 发 `MAGIC_KINGTURTLE_ATT2_*`（+200）；结束时复位 `Enabled:=False`。

### 8.3 `HerbActor.pas` —— 采集物与特殊对象（10 类，Round 939 全实现）

> 常量（`:10-14`）：`BEEQUEENBASE=600`、`DOORDEATHEFFECTBASE=120`、
> `WALLLEFTBROKENEFFECTBASE=224`、`WALLRIGHTBROKENEFFECTBASE=240`。

**顶层基类**（都继承 `TActor`）：`TKillingHerb`（`:19`，**可采集物基类**）、
`TBeeQueen`、`TCastleDoor`、`TWallStructure`、`TSoccerBall`。
**`TKillingHerb` 的派生**：`TMineMon`（矿）、`TCentipedeKingMon`（蜈蚣王）、
`TBigHeartMon`（大心怪）、`TSpiderHouseMon`（蜘蛛巢）、`TDragonBody`（火龙身）。

#### 8.3.1 `TKillingHerb.CalcActorFrame`（`:141-223`）—— 动作→帧段映射

按 `CurrentAction` 把 `pm.Act*` 段展开为 `startframe/endframe/frametime`：

| `CurrentAction` | 帧源 | 备注 |
|---|---|---|
| `SM_TURN` | `ActStand`（**无方向**） | `Race=106` 时随机取 `startframe+Random(3000) mod 4` |
| `SM_DIGUP` | `ActWalk`（无方向） | `maxtick/curtick/movestep` 用于位移 |
| `SM_HIT` | `ActAttack + Dir*(frame+skip)` | 置 `WarModeTime` |
| `SM_STRUCK` | `ActStruck + Dir*(...)` | 用 `struckframetime` |
| `SM_DEATH` | `ActDie + Dir*(...)` | **`startframe := endframe`**（停在最后一帧） |
| `SM_NOWDEATH` | `ActDie + Dir*(...)` | 从头播 |
| `SM_DIGDOWN` | `ActDeath`（无方向） | `Race<>106` 时 `BoDelActionAfterFinished:=TRUE`（**动作结束即删 actor**） |

`GetDefaultFrame`：死亡 → `ActDeath`（有骨架）或 `ActDie` 末帧；否则 `ActStand + currentdefframe`。

#### 8.3.2 各类实现要点

| 类 | 行 | 要点 |
|---|---|---|
| `TMineMon`（지뢰/矿） | `:249-358` | **强制 `Dir:=0`**；`SM_HIT`/`SM_STRUCK` 复用 `ActStand`（无攻击动画）；`DrawChr` **每 60 s 重调 `LoadSurface`** 防图库内存被释放，再 `Drawblend` |
| `TBeeQueen`（비막원충） | `:365-438` | 无 `SM_DIGUP`/`SM_DIGDOWN`；全部无方向 |
| `TCentipedeKingMon`（지네왕/촉룡신） | `:445-570` | `SM_HIT` 用 `ActCritical` + **特效**：`BoReadyEffect` 等 5 帧后转 `BoUseEffect`，`LoadEffectSurface` 从 `g_WMon24Img`（`Race=106`，基址 1410）或 `g_WMon15Img`（基址 100）取帧；`Run` 以 50 ms/帧推进 `effectframe` 0..9 |
| `TBigHeartMon`/`TSpiderHouseMon` | `:579-596` | 仅 `Dir:=0` + `inherited` |
| `TDragonBody`（화룡몸） | `:924-988` | `LoadSurface` 从 **`g_WDragonImg`**（按 `GetOffset(Appearance)`）；`CalcActorFrame` 固定 `startframe=0/endframe=1/frametime=400`；`DrawChr` 每 60 s 重载 |

#### 8.3.3 `TCastleDoor`（城门，`:604-784`）—— **客户端独立碰撞**

- `Create`：`Dir:=0`、`DownDrawLevel:=1`（注释「1셀 먼저 그림」= **先画 1 格**，
  防玩家头从门下滑出）。
- **`ApplyDoorState(dstate)`（`:612-637`）**：用 **`Map.MarkCanWalk`** 在客户端
  **独立标记 10+ 格的可通行性**（与服务端 `TCastleDoor.ActiveDoorWall` 的
  `GetMarkMovement` 是两套平行实现）—— 3 格门框恒不可走；开/关切其余格；开门时再封 3 格。
- `CalcActorFrame`：`SM_DIGUP`=开门→`ActAttack`+`dsOpen`；`SM_DIGDOWN`=关门→`ActCritical`+
  `dsClose`；`SM_NOWDEATH`/`SM_DEATH`→`ActDie`+`dsBroken`；否则 `Dir<3` 关（`ActStand+Dir`）
  或 `Dir>=3` 开（`ActCritical`）。
- `GetDefaultFrame` 按开/关设 `DownDrawLevel` 1/2；`Run` 在**镜头格变化时重刷门状态**；
  `DrawChr` 叠画 `DOORDEATHEFFECTBASE(120)+frame` 特效。

#### 8.3.4 `TWallStructure`（城墙，`:792-920`）—— 破损贴图 + 底部绘制

- `Dir∈0..7`；`LoadSurface`：死亡/受击时 `BodySurface := offset+deathframe`，
  另取 `BrokenSurface := offset+8+Dir`；特效基址按 `Appearance=901` 选
  `WALLLEFTBROKENEFFECTBASE(224)` 或 `WALLRIGHTBROKENEFFECTBASE(240)`。
- `Run`：按 `Death` 切 `Map.MarkCanWalk(XX,YY)`（**独立碰撞标记**），
  并 `PlayScene.SetActorDrawLevel(self, 0)`（**画在最底层**）；`DrawChr` 叠画 `BrokenSurface`+特效。

#### 8.3.5 `TSoccerBall`

空壳（`:103-106`），渲染完全走基类 `TActor`。

> **`TCastleDoor`/`TWallStructure` 是「攻城」的客户端表现** ——
> 与 `Castle.pas` 的 `CASTLEMAINDOORREPAREGOLD` 等费用常量（`items-systems.md` §3）
> 及服务端 `ObjMon2.pas` 的 `TCastleDoor`/`TWallStructure`（`monsters.md` §12.4）配套。
> ⚠️ **客户端与服务端各自维护一份门/墙通行位图**（`Map.MarkCanWalk` vs `PEnvir.GetMarkMovement`），
> 两者一致性未验证。

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
| ~~`AxeMon.pas` 各类的 `DrawEff`/`Run` 实现~~ | ✅ **已闭合**（Round 940，§8.2） |
| ~~`HerbActor.pas` 各类的实现~~ | ✅ **已闭合**（Round 939，§8.3） |
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
