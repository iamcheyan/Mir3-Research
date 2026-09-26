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
