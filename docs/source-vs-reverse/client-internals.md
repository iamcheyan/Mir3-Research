# Preview 客户端控件内部与主循环（DWinCtl + PlayScn）

> 证据源：`Source/Client/DWinCtl.pas`（7,804 行）、`PlayScn.pas`（3,043 行）。
> 证据等级 `secondary-source`。
> 前置：`client-controls.md`（类层次与输入优先级）已读；本文补内部实现。

---

## 1. `TDButton` —— **四态渲染**（`DWinCtl.pas:1841-1890`）

```pascal
if Assigned(FOnDirectPaint) then
   FOnDirectPaint(self, dsurface)          // 自定义绘制优先
else if WLib <> nil then begin
   if not FEnabled then begin              // ① 禁用
      d := WLib.Images[FaceIndex + 3];  FColor := FDFEnabledColor;
   end else if Downed then begin           // ② 按下
      d := WLib.Images[FaceIndex + 2];  FColor := FDFDownColor;
   end else if MouseEntry = msIn then begin// ③ 悬停
      d := WLib.Images[FaceIndex + 1];  FColor := FDFMoveColor;
   end else begin                          // ④ 常态
      d := WLib.Images[FaceIndex];      FColor := FDFColor;
   end;
   // 文字居中
   TextOutEx(SurfaceX(Left) + (Width - TextWidth(Caption)) div 2,
             SurfaceY(Top) + (Height - TextHeight(Caption)) div 2, Caption, FColor);
end;
// 递归绘制子控件，最后 FOnEndDirectPaint
```

### 1.1 **帧号偏移规则**

`TDButton.DirectPaint` 按状态取 `FaceIndex + N`：

| 状态 | 帧 | 颜色字段 |
|---|---|---|
| 常态 | `FaceIndex` | `FDFColor` |
| **悬停** | `FaceIndex + 1` | `FDFMoveColor` |
| **按下** | `FaceIndex + 2` | `FDFDownColor` |
| **禁用** | `FaceIndex + 3` | `FDFEnabledColor` |

`SetImgIndex(Lib, index)` 的实现（`:1722-1730`）直接
`FaceIndex := index`，**不做任何帧对齐/取整** ——
即「一个按钮占 4 个连续帧」这个约束**由资源制作者保证**，代码不校验。

### 1.2 **实测：主 HUD 按钮的帧间距是 2，不是 4**（重要修正）

源码 `TFrmDlg.Initialize` 里主 HUD 按钮的帧号（`FState.pas:2212-2267`）：

```
DBotTrade    1170      DBotMiniMap  1172      DBotSkillBar 1174
DBotExit     1176      DBotLogout   1178      DBotGroup    1180
DBotGuild    1182      DMyMagic     1184      DOption      1188
```

**帧间距是 2**（`1170→1172→1174…`），**不是 4**。若真是 4 帧制，
`1172` 会与 `1170` 的 `+2`（按下态）**冲突**。

→ **结论：这些主 HUD 按钮实际只用了 2 个状态帧（常态/悬停）**，
不是 4 个。即：
- `1170` = `DBotTrade` 常态，`1171` = 悬停
- `1172` = `DBotMiniMap` 常态，`1173` = 悬停
- …以此类推

**`+2`/`+3` 分支在这批按钮上取到的帧属于「下一个按钮的常态/悬停」**
—— 即**代码支持 4 帧制，但资源只为这些按钮提供了 2 帧**。
（`DOption` 与 `DMyMagic` 之间有 **`1186` 的空缺**，进一步说明帧号是人工分配的。）

> ⚠️ **这是与原版对照的关键**：原版 `secondary-source-catalog.md` 记录的
> 「帧对」（`80/81`、`82/83`、`84/85`…**步长也是 2**）与源码这批按钮
> **步长一致** —— 说明**两版都采用「2 帧/按钮」的资源布局**。
> 源码的 `TDButton` 支持 4 帧，但实际资源是 2 帧。
>
> **做帧对照时的正确假设是 2 帧/按钮**，除非有证据表明某按钮用了 4 帧。

### 1.3 例外：`DBotGroup` 有自定义绘制

`DBotGroupDirectPaint`（`FState.pas:5302`）覆盖了默认绘制 ——
即 `FOnDirectPaint` 分支（`:1847-1848`）**优先于**帧号逻辑。
**有自定义绘制的按钮不走 `FaceIndex + N` 规则**，
做帧对照时需先确认哪些按钮注册了 `OnDirectPaint`。

**绘制顺序**：`FOnDirectPaint`（自身）→ 子控件（正序）→ `FOnEndDirectPaint`（收尾）。
`FOnEndDirectPaint` 用于「画在自己之上但在子控件之下」的叠加层。

### 1.2 按下/抬起的状态机（`:1892-1926`）

```pascal
// MouseDown
if inherited MouseDown(...) and FEnabled then
   if (not Background) and (MouseCaptureControl = nil) then begin
      Downed := TRUE;
      SetDCapture(self);          // ← 捕获鼠标
   end;

// MouseUp
if inherited MouseUp(...) and FEnabled then begin
   ReleaseDCapture;
   if not Background then
      if Downed and InRange(X, Y) then begin     // ← 必须在范围内抬起
         if Assigned(FOnClickSound) then FOnClickSound(self, FClickSound);
         if Assigned(FOnClick) then FOnClick(self, X, Y);
      end;
   Downed := FALSE;
end;
```

**三个要点**：
1. **`SetDCapture`/`ReleaseDCapture`** —— 按下时捕获鼠标，
   **拖出按钮范围再抬起不会触发点击**（`InRange(X,Y)` 检查）。
2. **`Background` 属性的按钮不参与按下/点击**（只作背景）。
3. **音效在点击之前触发**（`FOnClickSound` → `FOnClick`）。

---

## 2. `TDGrid` —— 格子控件（`:1930-2039`）

### 2.1 默认值（`:1930-1944`）

```pascal
FColCount := 8;    FRowCount := 5;      // 默认 8×5
FColWidth := 36;   FRowHeight := 32;    // 默认 36×32
FColoffset := 0;   FRowoffset := 0;
FSelectCell.X := -1;  FSelectCell.Y := -1;
```

> ⚠️ **注意：`FColCount := 8` 与 `FRowCount := 5` 的赋值顺序与命名顺序相反**
> （先 Col 后 Row，但值是 8 和 5）。默认 8 列 5 行。

### 2.2 格子命中 `GetColRow`（`:1946-1960`）

```pascal
if InRange(x, y) then begin
   nX := x - Left;   nY := y - Top;
   acol := nX div (FColWidth + FColoffset);
   arow := nY div (FRowHeight + FRowoffset);
   // 双重检查：确保落在格子内而非间隙
   if (nX - (FColWidth+FColoffset)*acol - FColWidth <= 0) and
      (nY - (FRowHeight+FRowoffset)*arow - FRowHeight <= 0) then
      Result := TRUE;
end;
```

**`FColoffset`/`FRowoffset` 是格子间的**间隙**（不是偏移）——
分母是 `ColWidth + Coloffset`，即**格子 + 间隙**的步进。

### 2.3 拖拽选择语义（`:1962-2013`）

```pascal
// MouseDown: 记录按下格 FSelectCell + DownPos，捕获鼠标
// MouseUp:   只有抬起格 == 按下格 才触发 FOnGridSelect
if (FSelectCell.X = acol) and (FSelectCell.Y = arow) then begin
   Col := acol;  Row := arow;
   FOnGridSelect(Self, X, Y, acol, arow, Shift);
end;
ReleaseDCapture;
FSelectCell.X := -1;  FSelectCell.Y := -1;   // 清空
```

→ **「按下与抬起在同一格」才算选中** —— 拖拽跨格会取消。
`FOnGridMouseMove` 则在移动时持续触发（用于拖拽预览）。

### 2.4 绘制（`:2021-2039`）

```pascal
for i := 0 to FRowCount-1 do
   for j := 0 to FColCount-1 do begin
      rc.Top  := Top  + i*FRowHeight + i*FRowoffset;
      rc.Left := Left + j*FColWidth  + j*FColoffset;
      rc.Right := rc.Left + FColWidth;   rc.Bottom := rc.Top + FRowHeight;
      if (FSelectCell.Y = i) and (FSelectCell.X = j) then
         FOnGridPaint(self, j, i, rc, [gdSelected], dsurface)
      else
         FOnGridPaint(self, j, i, rc, [], dsurface);
   end;
```

**绘制只委托给 `FOnGridPaint` 回调** —— `TDGrid` 自己不画任何东西，
完全由使用方决定每格画什么。**这是「数据驱动」的极简设计**。

---

## 3. **背包格子几何（重要对照）**

### 3.1 `DItemGrid` 的真实尺寸（**DFM 里，不在代码里**）

实测 `FState.dfm` 的 `TDGrid` 属性：

| 控件 | ColCount | RowCount | ColWidth | RowHeight |
|---|---:|---:|---:|---:|
| **`DItemGrid`（背包）** | **6** | **8** | **38** | **38** |
| `DDRGrid`（交易对方） | 5 | 2 | 36 | 32 |
| `DDGrid`（交易己方） | 5 | 2 | 36 | 32 |
| `DMakeitemGrid`（制作） | 6 | 1 | 36 | 32 |

**代码里从不设置这些属性**（`grep '\.ColWidth\s*:='` 零命中）——
**全部来自 DFM**。这与 `client-windows.md` §2.2「DFM 是编辑期布局」的结论
**不矛盾**：**DFM 的坐标会被运行时覆盖，但 DFM 的控件属性（格子数/格子尺寸）
不会**。这是一个需要区分的边界。

### 3.2 与运行时几何的精确吻合（**验证通过**）

`FState.pas:2122-2125`：

```pascal
DItemGrid.Left   := 133;
DItemGrid.Top    := 81;
DItemGrid.Width  := 228;
DItemGrid.Height := 304;
```

**算术验证**：

```
6 列 × 38px = 228  ✅ 恰好等于 DItemGrid.Width
8 行 × 38px = 304  ✅ 恰好等于 DItemGrid.Height
```

→ **背包格子几何完全自洽**：`6 列 × 8 行 @ 38×38`，网格区 228×304。

### 3.3 与原版对照

| | 原版（`primary-static`） | Preview 源码 |
|---|---|---|
| 列数 | **6** ✅ | **6** ✅ |
| 行数 | 6 | **8**（多 2 行） |
| 格子尺寸 | 36 px | **38 px** |
| 总槽数 | **36** | **48** |

**「6 列」一致**，但**行数（6 vs 8）、格子尺寸（36 vs 38）、总槽数（36 vs 48）不同**。
→ **两版背包布局同构但不同规模**（源码版多 12 格）。

### 3.4 背包索引的 `+6` 偏移（**易错点**）

`FState.pas:6294/6321/6436/6516` 四处都有：

```pascal
idx := ACol + ARow * DItemGrid.ColCount + 6{벨트공간};
```

**注释 `{벨트공간}` = 「腰带空间」** —— 即**背包索引前面有 6 个槽位留给腰带**。

**完整槽位映射**：

| 索引 | 用途 |
|---|---|
| `0..5` | **腰带 6 格**（`DBelt1..DBelt6`，见 `client-runtime-layout.tsv`） |
| `6..53` | **背包 48 格**（`6 + 6列×8行 = 54`） |

→ **做背包/物品索引换算时必须加这个 `+6`**，否则整体错位 6 格。

---

## 4. `PlayScn.pas`（3,043 行）—— 主游戏场景

> 本阶段只读了结构与关键调用点（`client.md` §2 的场景状态机已记录
> `stPlayGame → PlayScene`）。**完整主循环未读，标注 pending。**

已知（来自前序阶段的调用点）：
- `PlayScn.pas:2927/2930` —— 切图后 `FrmMain.SendWantMiniMap`
  （`server.md` §13.8 的小地图链路）
- `PlayScn.pas:281` —— `if CurrentScene = PlayScene then ...`（绘制分支）

---

## 5. 与 EI 证据 / Zircon 的对照

| 项 | 原版反编译 | 源码 | Zircon |
|---|---|---|---|
| 按钮帧制 | 观察到「帧对」（80/81 等） | **4 帧制**（常态/悬停/按下/禁用） | — |
| 按钮点击 | 共享 release 处理器 | `Downed + InRange` 状态机 | `DXButton` |
| 背包格子 | 6×6 @36px = 36 槽 | **6×8 @38px = 48 槽** | `DXGrid` |
| 背包索引偏移 | 未闭合 | **`+6`（腰带空间）** | — |
| 格子选择 | 未闭合 | 「按下与抬起同格」 | — |

**分级**：源码结论均 `secondary-source`。

---

## 6. 未验证项

| 项 | 原因 |
|---|---|
| `PlayScn.pas`（3,043 行）主循环 | 只读了结构与调用点 |
| `TDWindow` 移动/关闭逻辑（`:2043-2170`） | 未读 |
| `TDModalWindow`（`:7348-`）模态机制 | 未读 |
| `TDMemo`/`TDEdit` 输入与 IME | 未读 |
| `TDTreeView`（原版无对应） | 未读 |
| `TDPopUpMemu`（右键菜单） | 未读 |
| `TDListView` / `TDComboBox` | 未读 |
| 其他 `TDGrid` 实例（`DDRGrid`/`DDGrid`/`DMakeitemGrid`）的运行时几何 | 未查 |
| 背包 48 槽与原版 36 槽的**业务差异**（是否源码版扩展了） | 未追 |

---

## 7. `PlayScn.pas` 主渲染管线（Round 823）

> `Source/Client/PlayScn.pas`（3,043 行）。`TPlayScene = class(TScene)`（`:132`）。

### 7.1 **五层 Surface 架构**（核心设计）

| 层 | 方法 | 行 | 内容 |
|---|---|---|---|
| 1 | `BackgroundSurface` | `:1388` | **背景**（`g_WProgUse.Images[570]`） |
| 2 | `PlaySurface` | `:836` | **主游戏层**（地形/物件/角色/掉落物/特效） |
| 3 | `LightSurface` | `:1331` | **光照层** |
| 4 | `WeatherSurface` | `:1422` | **天气层**（每 100ms 换帧） |
| 5 | `MagicSurface` | `:1457` | **魔法特效层**（带 `ScreenBright` 调色） |

**`PlaySurface` 是最大的一层**（`:836-1330`，约 **495 行**）——
地形瓦片、物件、角色、掉落物、魔法特效全在这里绘制。

### 7.2 `PlaySurface` 的绘制要素（`:845-861` 变量声明即清单）

| 变量 | 类型 | 内容 |
|---|---|---|
| `nObjFileIdx`/`nImgIdx`/`bObjAni` | integer | **物件文件索引/图索引/动画标记** |
| `pd: PTDropItem` | — | **掉落物** |
| `evn: TClEvent` | — | **客户端事件** |
| `actor: TActor` | — | **角色** |
| `meff: TMagicEff` | — | **魔法特效** |
| `blend`/`movetick`/`bBlend` | Boolean | 混合与移动节拍 |
| `cLightSizeType`/`cLightColorType` | integer | 光照尺寸/颜色类型 |
| `drawingbottomline` | integer | 绘制底线（初始 `g_FScreenHeight`） |

**`CheckOverlappedObject(myrc, obrc)`**（`:837-844`）是**内嵌的矩形重叠判定** ——
用于对象遮挡/排序。

**视野雾（Fog）逻辑**（`:868-875`）：
```pascal
if NoDarkness or (Myself.Death) then ViewFog := FALSE;   // 免暗或死亡 → 关雾
if ViewFog then ClearLightMap;                            // 否则清光照图
```
→ **死亡时自动取消视野雾**（便于观察/复活）。

### 7.3 光照系统（**最复杂的子系统**）

#### 7.3.1 光照尺寸表（`:42-49`）

```pascal
LightSizes : array[0..MAXLIGHT] of integer = (
   34496, 161280, 327360, 405920, 542976, 713632
);
```
**6 档光照尺寸**（递增）。配套 `LightMask0..N` 二维 `shortint` 表
（`:51-`，如 `LightMask0` 是 3×3、`LightMask1` 是 5×5），
中心值 3/4、边缘 0 —— 是**光照扩散的衰减掩码**。

#### 7.3.2 光照图（`LightMap`）

`LightMap[i, j]` 是**屏幕格**（`LMX × LMY`），每格含
`light`/`shiftx`/`shifty`/`cLightColorType`。

**`AddLight`（`:1712-1728`）—— 一般光源**：
```pascal
lx := x - Myself.Rx + LMX div 2;   // 世界坐标 → 屏幕格
ly := y - Myself.Ry + LMY div 2;
if (lx >= 1) and (lx < LMX) and (ly >= 1) and (ly < LMY) then
   if LightMap[lx, ly].light < light then            // ← 只接受更强的光
      if not CheckOverLight(lx, ly, light) or nocheck then
         UpdateBright(lx, ly, light);
         LightMap[lx, ly].light := light;
```

**`AddMapLight`（`:1730-1751`）—— 地图固有光源**：
条件不同 —— `(LightMap[lx,ly].light <= light) or (LightMap[lx,ly].light = 256)`
（**`<=` 而非 `<`，且 256 是特殊值**），并额外记录 `cLightColorType`。

**地图光照来源**（`:1187-1191`）：
```pascal
cLightSizeType := (Map.MArrOb[i, j].wLigntNEvent and $C000) shr 14;  // 高 2 位
AddMapLight (i+Map.BlockLeft, j+Map.BlockTop, 0, 0, cLightSizeType, cLightColorType, FALSE);
```
→ **光照类型编码在物件字段 `wLigntNEvent` 的高 2 位**（`$C000 >> 14`，取值 0-3）。

#### 7.3.3 ⚠️ **`ApplyLightMap` 整个函数被注释掉**（`:1753-1783`）

```pascal
procedure TPlayScene.ApplyLightMap;
begin
   ...
   for i := 1 to LMX-1 do
      for j := 1 to LMY-1 do begin
         light := LightMap[i, j].light;
         if light >= 0 then begin
            ...
//            FogCopy (Lights[light].PFog, ...);   ← 实际绘制被注释
//            inc (lcount);
         end;
      end;
end;
```

**函数体完整但唯一的绘制调用 `FogCopy` 被注释** ——
即**光照数据被计算和存储，但不由这个函数绘制**。
`DrawLightEffect`（`:1785-`）同样整段注释。

→ **光照实际绘制在别处**（疑在 `LightSurface`，`:1331`）。
**这是读代码时的重大陷阱**：`ApplyLightMap` 名字像主入口，实际是**空转**。

### 7.4 其他关键方法

| 方法 | 行 | 语义 |
|---|---|---|
| `Initialize`/`Finalize` | `:345`/`:403` | 场景生命周期 |
| `OpenScene`/`CloseScene` | `:431`/`:445` | 开关（`client.md` §2 的状态机） |
| `Lost`/`Recovered` | `:464`/`:484` | **设备丢失/恢复**（DirectX 必需） |
| `SetAniTileFrame` | `:504` | **动画瓦片帧** |
| `BeginScene` | `:577` | 场景开始 |
| `DrawObjOneCellTile`/`DrawObjTile` | `:771`/`:831` | 物件瓦片绘制 |
| `CanDrawTileMap` | `:1475` | 可否绘制地形 |
| `RefreshScene`/`CleanObjects` | `:1484`/`:1493` | 刷新/清理对象 |
| `ClearLightMap` | `:1598` | 清光照图 |
| `UpdateBright`/`CheckOverLight` | `:1608`/`:1653` | 亮度更新/过曝检查 |
| `SoundOnTimer` | `:322` | 音效定时器 |
| `EdChatKeyPress` | `:328` | 聊天按键 |

**`Lost`/`Recovered`（`:464`/`:484`）** —— DirectX 设备丢失处理，
是**客户端渲染的标准必需项**（切全屏/最小化时触发）。

### 7.5 与 EI 证据 / Zircon 的对照

| 项 | 原版反编译 | 源码 | Zircon |
|---|---|---|---|
| 渲染分层 | 未闭合 | **5 层 Surface** | `RenderingCore/` |
| 光照 | 原版有光照研究（`docs/RENDERING_*`） | 6 档 `LightSizes` + `LightMask` 掩码 | Godot 光照层 |
| 光照编码 | 未闭合 | 物件字段 `wLigntNEvent` 高 2 位 | — |
| 视野雾 | 未闭合 | `ViewFog` + 死亡时关闭 | — |
| 设备丢失 | 未闭合 | `Lost`/`Recovered` | Godot 自动 |

> **对本仓库的意义**：`docs/` 里有既有的 Godot 光照研究
> （`RENDERING_REGRESSION_LIGHT_LAYER_*`、`GODOT_WEATHER_DAYLIGHT_GUIDE.md`）。
> **本节的 `LightSizes` 6 档表与 `LightMask` 掩码是原版光照的权威参数**，
> 可用于校验 Godot 侧的光照实现 —— **标注为后续工作**。

### 7.6 未验证项

| 项 | 原因 |
|---|---|
| `PlaySurface` 主体（`:836-1330`，495 行） | 只读了入口与变量清单 |
| `LightSurface`（`:1331-1387`）实现 | 只读了开头 |
| `LightMask0..N` 的完整表 | 只读了前两个 |
| `LightSizes` 的 6 个值与「格数」的换算 | 未核（是像素面积？） |
| `UpdateBright`/`CheckOverLight` 实现 | 未读 |
| `SetAniTileFrame`（动画瓦片） | 未读 |
| `Lost`/`Recovered` 实现 | 未读 |
| 光照实际绘制位置（`ApplyLightMap` 被注释后的替代者） | **未定位** |
