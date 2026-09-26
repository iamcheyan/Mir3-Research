# Preview 战斗与技能系统（Magic.pas 精读）

> 证据源：`Source/GameServer/Magic.pas`（1,756 行）。
> 证据等级 `secondary-source`。
> 机器可读：[`magic-dispatch.tsv`](magic-dispatch.tsv)（22 个 MagicId 分派）。
> 提取器：`Tools/source-read/extract_magic_dispatch.py`。

---

## 1. 结构总览

`TMagicManager = class`（`:12`）—— 全局单例技能管理器。
**55 个 `Mag*` 方法**，其中 `SpellNow`（`:891`）是**唯一入口**。

```
SpellNow(user, pum, xx, yy, target, spell)
  ├─ 内嵌助手: GetRPow / GetPower / GetPower13 / CanUseBujuk / UseBujuk
  └─ case pum.pDef.MagicId of    ← 22 个分支
        → 各自的 Mag* 函数
```

---

## 2. 伤害/威力模型（**三个公式，别混**）

### 2.1 `GetRPow`（`:892-898`）—— 16 位参数的随机化

```pascal
if Hibyte(pw) > Lobyte(pw) then
   Result := Lobyte(pw) + Random(Hibyte(pw) - Lobyte(pw) + 1)
else
   Result := Lobyte(pw);
```

**一个 16 位 word 打包了 `[min, max]` 区间**：高字节 = max、低字节 = min，
返回 `[min, max]` 的随机值。**这是本源码常用的「打包区间」手法**
（`MonGen` 的 `TX`/`TY` 等字段可能同源，待核）。

### 2.2 `GetPower`（`:899-903`）—— 标准威力

```pascal
Result := Round(pw / (pum.pDef.MaxTrainLevel+1) * (pum.Level+1))
          + (pum.pDef.DefMinPower + Random(pum.pDef.DefMaxPower - pum.pDef.DefMinPower));
```

注释「수련 0 단계에서는 1/4의 파워임」（**修炼 0 级时是 1/4 威力**）。

**结构**：`技能基础值 × (等级+1)/(最大修炼等级+1)` + `DefMinPower..DefMaxPower` 随机。
即**技能等级线性缩放基础值**，再加一段固定区间的随机。

### 2.3 `GetPower13`（`:904-912`）—— 保底 1/3

```pascal
p1 := pw / 3;
p2 := pw - p1;
Result := Round(p1 + p2 / (pum.pDef.MaxTrainLevel+1) * (pum.Level+1)
                + (pum.pDef.DefMinPower + Random(pum.pDef.DefMaxPower - pum.pDef.DefMinPower)));
```

注释「수련 0 단계에도 1/3의 파워가 남」（**修炼 0 级也保留 1/3 威力**）。

**与 `GetPower` 的区别**：把 `pw` 拆成 `1/3 固定 + 2/3 缩放`，
所以 0 级时有 `1/3` 保底而非 `1/(MaxTrainLevel+1)`。
→ **不同技能用不同公式**（部分技能 0 级不该完全无威力）。

### 2.4 `MPow`（`:64-67`）—— 简单随机

```pascal
Result := pum.pDef.MinPower + Random(pum.pDef.MaxPower - pum.pDef.MinPower);
```

**注意与 `GetPower` 的字段名不同**：`MPow` 用 `MinPower`/`MaxPower`，
`GetPower` 用 `DefMinPower`/`DefMaxPower`。**两套字段**，别混。

---

## 3. 符咒（부적）机制（`:913-...`）—— 技能消耗品

### 3.1 `CanUseBujuk`（`:913-939`）—— 检查是否有符咒

**检查顺序**（返回码表示用哪个槽）：

| 返回 | 槽位 | 条件 |
|---|---|---|
| `1` | `U_BUJUK`（符咒栏） | `StdMode = 25` 且 `Shape = 5` 且 `Dura/100 >= count-1` |
| `2` | `U_ARMRINGL`（左臂环） | 同上（**符咒可戴在臂环位**） |
| `0` | — | 都没有 |

**关键**：**符咒的「数量」用 `Dura` 表示**（`Dura/100`）——
与 `TakeItemFromUser`（`server.md` §12.6）的堆叠物品用 `Dura` 计数**同一手法**。

### 3.2 `UseBujuk`（`:940-...`）—— 消耗符咒

```pascal
if user.UseItems[U_BUJUK].Dura < 100 then begin   // 不足 100 = 最后一个
   user.UseItems[U_BUJUK].Dura := 0;
   hum.SendDelItem(...);                           // 通知客户端删除
   hum.SysMsg('부적이 다 닳았습니다.', 0);          // 「符咒用完了」
   user.UseItems[U_BUJUK].Index := 0;
end;
```

**`U_BUJUK`（符咒栏）是 2003/03/15 为 COPARK 扩展的装备位**
（注释「2003/03/15 COPARK 아이템 인벤토리 확장」）。

---

## 4. 技能分派表（**4 个 case 块 / 26 个 MagicId**）

**重要修正**：`Magic.pas` 里**有 4 处** `case pum.pDef.MagicId of`（不是 1 处）：

| 块 | 行 | 条目 | 上下文 |
|---|---:|---:|---|
| `blk1` | `:1008` | 20 | **`SpellNow` 主分派**（主动施法） |
| `blk2` | `:1349` | 2 | 另一上下文（`id 41`/`id 17`，无注释） |
| `blk3` | `:1397` | 3 | `폭살계`(13)/`항마진법`(14)/`저주술`(46) —— **领域型技能** |
| `blk4` | `:1584` | 1 | `신수소환`(30) —— **神兽召唤** |

完整表见 [`magic-dispatch.tsv`](magic-dispatch.tsv)（含 `block` 列区分上下文）。
**技能名是韩文**，`blk1` 的 20 个列出：

| MagicId | 韩文名 | 处理函数 | 推断 |
|---:|---|---|---|
| 1 | 화염장 | 内联 | 火炎掌 |
| 2 | 회복술 | 内联 | 恢复术 |
| 5 | 금강화염장 | 内联 | 金刚火炎掌 |
| 6 | 암연술 | 内联 | 暗炎术 |
| 8 | 화염풍 | `MagPushAround` | 火炎风（**击退**） |
| 9 | 염사장 | 内联 | 炎蛇掌 |
| 10 | 뢰인장 | 内联 | 雷印掌 |
| 11 | 강격 | 内联 | 强击 |
| 20 | 뢰혼격 | `MagLightingShock` | 雷魂击（**闪电震击**） |
| 21 | 아공행법 | `MagLightingSpaceMove` | 亚空行法（**闪电瞬移**） |
| 22 | 지염술 | `MagMakeFireCross` | 地炎术（**火十字**） |
| 23 | 폭열파 | `MagBigExplosion` | 爆热波（**大爆炸**） |
| 24 | 뢰설화 | `MagElecBlizzard` | 雷雪华（**电暴雪**） |
| 29 | 대회복술 | `MagBigHealing` | 大恢复术 |
| 31 | 주술의막 | `MagBubbleDefenceUp` | 咒术之幕（**护盾**） |
| 32 | 사자윤회 | `MagTurnUndead` | 狮子轮回（**驱邪/超度**） |
| 33 | 빙설풍 | `MagBigExplosion` | 冰雪风（**复用大爆炸**） |
| 35 | 멸천화 | 内联 | 灭天火 |
| 37 | 기공파 | 内联 | 气功波（注释「도사 밀기 무공」= **道士推击武功**） |
| 45 | 화룡기염 | `MagDragonFire` | 火龙气焰 |

**`blk3` 的三个「领域」技能**（`:1397`）：

| MagicId | 韩文名 | 处理函数 |
|---:|---|---|
| 13 | 폭살계 | 内联（**爆杀界**） |
| 14 | 항마진법 | `MagMakeDefenceArea`（**降魔阵法**，防御领域） |
| 46 | 저주술 | 内联（**诅咒术**） |

**`blk4`**：`신수소환`(30)（**神兽召唤**）。

> ⚠️ **修正记录**：先前版本的提取器只抓第一个 `case` 块，
> 且把**嵌套的 `case pstd.Shape of`**（毒粉形状分派，`:1247`）里的
> `1: //회색독가루: 중독`、`2: //황색독가루: 방어력감소`
> 误当成 MagicId 条目，导致出现「重复的 MagicId 1、2」。
> **已修正**：提取器现在跟踪嵌套 `case` 并只采集本层标签。
> 毒粉的 MagicId 归属需另查（它们是 `blk1` 里某个分支内的道具形状分派）。

### 4.1 `IsSwordSkill`（`:55-62`）—— 武功（近战技能）判定

```pascal
case mid of
   3, 4, 7, 12, 25, 26, 27, 34, 38: Result := TRUE;
end;
```

**9 个 MagicId 是「武功」**（近战系，非远程魔法）。
注释「2003/03/15 신규무공 추가」（2003/03/15 新增武功）。

> **对 Zircon / `Tools/magiclab` 的意义**：`IsSwordSkill` 给出了
> 「武功 vs 魔法」的**权威分类**，可用于校验
> `ClientData/magic-effects.json` 的分类。

---

## 5. 击退机制 `MagPushAround`（`:70-95`）—— 完整概率模型

```pascal
for i := 0 to user.VisibleActors.Count-1 do begin
   cret := ...;
   if (abs(user.CX-cret.CX) <= 1) and (abs(user.CY-cret.CY) <= 1) then   // 相邻 1 格
      if (not cret.Death) and (cret <> user) then
         if (user.Abil.Level > cret.Abil.Level) and (not cret.StickMode) then begin
            levelgap := user.Abil.Level - cret.Abil.Level;
            if (Random(20) < 6 + pushlevel*3 + levelgap) then begin       // ← 概率
               push := 1 + _MAX(0, pushlevel-1) + Random(2);             // ← 距离
               ndir := GetNextDirection(user.CX, user.CY, cret.CX, cret.CY);
               cret.CharPushed(ndir, push);
               Inc(cret.PushedCount);
            end;
         end;
end;
```

**击退概率** = `(6 + pushlevel*3 + 等级差) / 20`（`Random(20) <` 比较）。
即：基础 30%（6/20），每级修炼 +15%（3/20），**等级差每级 +5%**。
`pushlevel = 0..3`（`:69` 注释）。

**击退距离** = `1 + max(0, pushlevel-1) + Random(2)` —— 即 1..3 格。

**前置条件**：`user.Abil.Level > cret.Abil.Level`（**必须比对方等级高**）
且 `not cret.StickMode`（对方不处于「粘住」状态）。

**`PushedCount`** 被累加 —— 用于统计/反外挂（推人次数异常 = 可疑）。

---

## 6. 与 EI 证据 / Zircon 的对照

| 项 | 原版反编译 | 源码 | Zircon |
|---|---|---|---|
| 技能 ID 表 | 未闭合（原版有 `Magic.exp`） | 22 个分派 + `IsSwordSkill` 9 个 | `MagicInfo`（dbeditor） |
| 威力公式 | 未闭合 | `GetPower`/`GetPower13`/`MPow` 三式 | — |
| 符咒机制 | 未闭合 | `CanUseBujuk`/`UseBujuk` + `Dura/100` 计数 | — |
| 击退 | 未闭合 | `MagPushAround` 完整概率模型 | — |
| `Magic.exp` | `docs/research/ei-ui-layout/Magic.exp.decoded.txt`（已解） | 本源码未读 `.exp` 解析 | `ClientData/magic-effects.json` |

**分级**：以上源码结论均 `secondary-source`。
原版无对应证据的标 `source-only`。

---

## 7. 未验证项

| 项 | 原因 |
|---|---|
| 55 个 `Mag*` 方法的**实现主体** | 只读了 `SpellNow` 分派表 + `MagPushAround` |
| 毒粉的 MagicId 归属 | 它们在 `blk1` 某分支内的 `case pstd.Shape of`，未回溯到外层 MagicId |
| `MagDragonFire` / `MagLightingShock` / `MagTurnUndead` 等实现 | 未读 |
| `pDef`（`TMagicInfo`）的字段全集 | 未读（`MinPower`/`MaxPower`/`DefMinPower`/`DefMaxPower`/`MaxTrainLevel`/`MagicId` 已见） |
| `Magic.exp` 的解析（源码侧） | 未读 |
| 各技能的**冷却/延迟**机制 | 未读 |
| `MagCanHitTarget` / `MagPassThroughMagic` | 未读 |

---

## 8. `Mag*` 实现特征（Round 822）

> 机器可读：[`magic-implementations.tsv`](magic-implementations.tsv)（16 个函数）。
> 提取器：`Tools/source-read/extract_magic_impl.py`。

### 8.1 共同模式（**AoE 技能的统一骨架**）

实测 16 个 `Mag*` 中 **9 个是 AoE**，骨架完全一致：

```pascal
rlist := TList.Create;
user.GetMapCreatures (user.PEnvir, X, Y, WIDE, rlist);   // ← 取范围内实体
for i := 0 to rlist.Count-1 do begin
   cret := TCreature (rlist[i]);
   if user.IsProperTarget (cret) then begin
      user.SelectTarget (cret);                          // 选中（部分技能有）
      cret.SendMsg (user, RM_MAGSTRUCK, 0, PWR, 0, 0, '');  // ← 造成伤害
      Result := TRUE;
   end;
end;
rlist.Free;
```

**`wide` 是 AoE 半径**（传给 `GetMapCreatures`）。**伤害通过
`RM_MAGSTRUCK` 消息发送**，不直接改 HP —— 即**伤害计算在接收方**。

### 8.2 各技能实测参数

| 函数 | `wide` | 特殊条件 |
|---|---|---|
| `MagDragonFire`（火龙气焰） | **变量** | 距离 ≥2 时 **伤害 ×0.8** |
| `MagElecBlizzard`（雷雪华） | `2` | **非亡灵只受 1/10 伤害** |
| `MagBigExplosion`（爆热波） | **变量** | 无 |
| `MagBigHealing`（大恢复术） | `1` | 治疗 |
| `MagMakeHolyCurtain`（圣幕） | `1` | 概率 |
| `MagMakeGroupTransparent`（群体隐身） | `1` | 无 |
| `MagMakePrivateTransparent`（自身隐身） | `9` | 概率 |
| `MagMakePrivateClean`（净化） | `0` | 概率 |
| `MagWindCut`（风刃） | `1` | 方向/概率/鬼魂/技能等级 |
| `MagPushAround`（击退） | — | 方向/粘住状态/概率（见 §5） |
| `MagLightingShock`（雷魂击） | — | 概率 + **非亡灵 1/10** |
| `MagTurnUndead`（狮子轮回） | — | **只对亡灵** + 概率 |
| `MagLightingSpaceMove`（亚空行法） | — | 概率（瞬移） |
| `MagPullMon`（拉怪） | — | 方向/粘住/概率 |
| `MagBlindEye`（致盲） | — | 概率 |
| `MagMakeFireCross`（地炎术） | — | 无（特殊实现） |

### 8.3 **两个关键机制**

#### 8.3.1 亡灵特攻（`LA_UNDEAD`）

`MagElecBlizzard`（`:424-426`）**逐字**：

```pascal
if cret.LifeAttrib <> LA_UNDEAD then  //언데드 계열 몬스터에게 공격력이 있음
   acpwr := pwr div 10
else acpwr := pwr;
```

**注释「언데드 계열 몬스터에게 공격력이 있음」= 对亡灵系怪物有攻击力**。
即**雷系法术对非亡灵只造成 1/10 伤害，对亡灵全额**。

`LifeAttrib` 常量（`Grobal2.pas:2347-2348`）：`LA_CREATURE = 0`、**`LA_UNDEAD = 1`**。
`MagTurnUndead`（狮子轮回）是**只对亡灵**的技能（驱邪/超度）。

#### 8.3.2 距离衰减（`MagDragonFire`）

`:116-120`：

```pascal
if (abs(user.CX - cret.CX) >= 2) or (abs(user.CY - cret.CY) >= 2) then
   realpwr := (pwr * 8) div 10     // ← 距离 ≥2 格：伤害 ×0.8
else
   realpwr := pwr;
```

注释「화룡기염 무공수정」（火龙气焰武功修正）——
**只有这一个技能实测有距离衰减**。

### 8.4 与 EI 证据 / Zircon 的对照

| 项 | 原版反编译 | 源码 | Zircon |
|---|---|---|---|
| AoE 骨架 | 未闭合 | `GetMapCreatures` + `RM_MAGSTRUCK` | `ClientData/magic-effects.json` |
| 亡灵特攻 | 未闭合 | `LA_UNDEAD` 判定 | — |
| 距离衰减 | 未闭合 | `MagDragonFire` ×0.8 | — |
| AoE 半径 | 未闭合 | 各技能 `wide` 值（1/2/9/变量） | — |

**分级**：源码结论均 `secondary-source`。

### 8.5 未验证项（本节）

| 项 | 原因 |
|---|---|
| `MagMakeFireCross` / `MagPullMon` / `MagBlindEye` / `MagWindCut` 的完整实现 | 只提取了 `wide` 与关键词 |
| `RM_MAGSTRUCK` 在客户端的伤害处理 | 未读客户端对应分支 |
| `wide` 与「格数」的换算关系 | `GetMapCreatures(env, x, y, area, rlist)` 的 `area` 语义未核 |
| 其余 39 个 `Mag*`（共 55 个） | 本次只提取了 16 个（有独立实现的） |
