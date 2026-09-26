# Preview 图库加载与解码（WIL/Zl）—— 与仓库工具链对照

> 证据源：`Source/Client/{WIL.pas,uWilFile.pas,wmM3Zip.pas,wmM2Zip.pas}`（Delphi）。
> 对照对象：本仓库 `Tools/common/wilsdk.py`、`Tools/common/zlsdk.py`。
> 证据等级 `secondary-source`（源码侧）/ `primary-resource`（实测文件侧）。
>
> 实测样本：`/home/tetsuya/mir2ei/Data/MagicEx.{wil,wix}`（原版 EI 客户端资源）。

---

## 1. 源码侧的 9 种图库格式

`WIL.pas:39`：

```pascal
TWILType = (t_wmM2Def, t_wmM2Def16, t_wmM2wis, t_wmMyImage,
            t_wmM3Def, t_wmWoool, t_wm521g, t_wmM2Zip, t_wmM3Zip);
```

| 枚举值 | 含义（推断） |
|---|---|
| `t_wmM2Def` | Mir2 默认格式 |
| `t_wmM2Def16` | Mir2 16 位色 |
| `t_wmM2wis` | Mir2 WIS |
| `t_wmMyImage` | 自研格式（`wmMyImage.pas`） |
| `t_wmM3Def` | **Mir3 默认（.wil/.wix 分离）** |
| `t_wmWoool` | 传奇世界 |
| `t_wm521g` | 521g 变体 |
| `t_wmM2Zip` | Mir2 压缩（`wmM2Zip.pas`） |
| `t_wmM3Zip` | **Mir3 压缩（`.Zl`，`wmM3Zip.pas`）** |

**关键**：`uWilFile.pas` 里客户端**优先加载 `.Lib`，失败才回退 `.wil`**
（`:189-201`，条件是 `AWMImages.WILType in [t_wmMyImage]`）：

```pascal
if (not AWMImages.Initialize()) and (AWMImages.FileName <> '')
   and (AWMImages.WILType in [t_wmMyImage]) then
begin
  sFileName := ChangeFileExt(AWMImages.FileName, '.wil');   // .Lib -> .wil
  AWMImages := CreateWMImages(t_wmM3Def);                    // 换成 M3 默认格式
  ...
end;
```

即 **`.Lib` = `t_wmMyImage`（自研），`.wil` = `t_wmM3Def`**。原版 EI 客户端
用的是 `.wil/.wix`（`t_wmM3Def`）—— 两套是**同一引擎的不同封装**。

---

## 2. `wmM3Zip.pas` 的容器结构（`.Zl` / 压缩格式）

### 2.1 索引文件（`TWMIndexHeader`，`wmM3Zip.pas:28-32`）

```pascal
TWMIndexHeader = packed record
  Title     : string[20];   // 21 字节（1 长度前缀 + 20 内容）
  IndexCount: Integer;      // 4 字节
end;
```

`LoadIndex`（`:189-214`）：

```pascal
FileSeek(fHandle, 0, 0);
FileRead(fhandle, FIdxHeader, sizeof(TWMIndexHeader));      // 25 字节
if FIdxHeader.IndexCount > MAXIMAGECOUNT then exit;         // 上限 10000000
GetMem(pvalue, 4 * FIdxHeader.IndexCount);
if FileRead(fhandle, pvalue^, 4 * FIdxHeader.IndexCount) = (4 * FIdxHeader.IndexCount) then
  for i := 0 to FIdxHeader.IndexCount - 1 do begin
    value := PInteger(integer(pvalue) + 4 * i)^;             // 每个 4 字节偏移
    FIndexList.Add(pointer(value));
  end;
```

→ **索引文件 = 25 字节头 + N 个 int32 偏移**（`MAXIMAGECOUNT = 10,000,000`）。

### 2.2 图像头（`TWMImageInfo`，`:16-25`）

```pascal
TWMImageInfo = packed record
  nWidth       : SmallInt;   // 2
  nHeight      : SmallInt;   // 2
  Px           : SmallInt;   // 2
  Py           : SmallInt;   // 2
  ShadowPX     : SmallInt;   // 2
  ShadowPY     : SmallInt;   // 2
  Shadow       : Byte;       // 1
  CompressedLen: Integer;    // 4
end;                          // 合计 17 字节
```

`LoadDxImage`（`:136-187`）流程：

```
Seek(position) → Read(TWMImageInfo, 17)
  尺寸守卫: MAXIMAGESIZE=4096, MINIMAGESIZE=1
  nLen := WidthBytes(16, nWidth)          // 每行 16 位对齐
  Read(inBuffer, 6)                        // ← 先读 6 字节
  Read(inBuffer, CompressedLen - 6)        // ← 再读剩余
  DecompressBuf(...)                       // zlib 解压
  MakeDXImageTexture(w, h, WILFMT_A8R8G8B8)
  CopyImageDataToTexture(outBuffer, ..., nLen, nHeight)
```

**注意 `Read(inBuffer, 6)` 后紧跟 `Read(inBuffer, CompressedLen - 6)`** ——
前 6 字节被**读进去又被覆盖**（因为两次 `Read` 都从 `inBuffer^` 起始写）。
这是**原作者的 bug 或刻意跳过**：6 字节可能是某种头/校验，被丢弃。
**做解码器时必须保留这 6 字节的偏移**，否则解压数据错位。

### 2.3 像素格式转换

`LineR5G6B5_A8R8G8B8`（`:54-64`）：

```pascal
r := ((Source and $f800) shr 8);   // 5 位红 -> 8 位（左移 3 位等效）
g := ((Source and $07e0) shr 3);   // 6 位绿 -> 8 位
b := ((Source and $001f) shl 3);   // 5 位蓝 -> 8 位
Dest := (Alpha shl 24) or (r shl 16) or (g shl 8) or b;
```

→ **R5G6B5 → A8R8G8B8 的直接位扩展**（不做抖动/插值）。

`WIL.pas:12` 的 4 种色格式：
```pascal
TWILColorFormat = (WILFMT_A4R4G4B4, WILFMT_A1R5G5B5, WILFMT_R5G6B5, WILFMT_A8R8G8B8);
```
对应 D3D 格式（`:26`）：
```pascal
ColorFormat: array[TWILColorFormat] of TD3DFormat =
  (D3DFMT_A4R4G4B4, D3DFMT_A1R5G5B5, D3DFMT_R5G6B5, D3DFMT_A8R8G8B8);
```

`WIL.pas:9` 有 **`{$INCLUDE BitChange.inc}`** —— 即 `reference/mir3-source/README.md`
§5.1 里被排除的 **479 KB 色彩转换 LUT**（`X8_A1R5G5B5: array[Byte] of Word`）。
**这份 LUT 被三处引用**（`Client/`、`Tools/MapEdit/Wil/`、`Tools/ImageEditor/`），
是 A1R5G5B5 转换的性能优化表。**它未入库，做逐像素精确对照时需要取回。**

---

## 3. 实测：真实 `.wil/.wix` 的结构（`primary-resource`）

### 3.1 `.wix` = 纯偏移表

```
文件: /home/tetsuya/mir2ei/Data/MagicEx.wix  (7,144 B)
布局: [20 字节全 0 头] + [1781 × int32 偏移]  = 20 + 7124 = 7144 ✓
偏移值范围: 0 .. 27,652,185   ← **超出 .wix 自身大小**
```

**`.wix` 里的偏移指向的是 `.wil` 文件内的位置**，不是 `.wix` 自身。
实测 1781 个偏移里 915 个落在同名 `.wil`（27,652,718 B）范围内。
（前几个偏移较小、后段出现 `0`，说明索引表是**按帧号排布但含空槽**。）

> ⚠️ 这修正了一个常见误解：`.wix` 不是「索引 + 数据」，而是**纯索引**，
> 数据全在 `.wil`。`wmM3Zip.pas` 的 `LoadIndex` 读法与之吻合
> （只读偏移表，`LoadDxImage` 再从 `FFileStream` 定位 —— 但源码里
> `FFileStream` 是 **`.wil`**，`FIdxFile` 是 **`.wix`**，见 `:38` `FIdxFile: string`）。

### 3.2 `.wil` 头（实测 `MagicEx.wil`）

```
偏移 0-1:   01 00
偏移 2-19:  'ILIB v1.0-WEMADE\0\0'      ← WEMADE 官方签名
偏移 20-23: 00 00 11 00
偏移 24-25: f4 06        = 1780 (int16)  ← **图像数**
偏移 26-29: 00 00 10 00
偏移 30-31: 10 00        = 16
偏移 32-33: 10 00        = 16
偏移 34+:   索引表，每项 16 字节
```

### 3.3 用本仓库 `wilsdk.py` 交叉验证 —— **通过**

```python
>>> import wilsdk
>>> lib = wilsdk.WilLibrary('/home/tetsuya/mir2ei/Data/MagicEx.wil')
>>> lib.count
1780                                   # ← 与文件头 @24 的 int16 一致
>>> lib.header(0)
{'index': 0, 'width': 16, 'height': 16, 'offsetX': 4, 'offsetY': -14,
 'shadow': True, 'shadowX': 7, 'shadowY': -44, 'words': 152, 'bytes': 304}
>>> lib.header(1)
{'index': 1, 'width': 16, 'height': 16, 'offsetX': 0, 'offsetY': -16, ...}
>>> lib.header(2)
{'index': 2, 'width': 32, 'height': 32, 'offsetX': -3, 'offsetY': -18, ...}
```

→ **`wilsdk.py` 对真实 EI `.wil` 的解析正确**（count 与文件头自洽、
宽高/偏移/阴影字段齐全）。这是本阶段最有价值的**正向验证**：
仓库既有工具链在真实资源上无误。

---

## 4. 源码格式 vs 真实格式 —— 结论

| | `wmM3Zip.pas`（Preview 源码） | 真实 `MagicEx.wil/.wix`（EI 原版） |
|---|---|---|
| 索引文件头 | `Title:string[20] + IndexCount:int32` = **25 B** | **20 B 全 0** + 偏移表 |
| 图像数位置 | 索引文件 `@21` | `.wil` `@24`（int16） |
| 图像头 | `TWMImageInfo` = **17 B**（含 `CompressedLen`） | `wilsdk` 解析为 16 B 项 |
| 压缩 | zlib（`DecompressBuf`） | `wilsdk` 正常读出（未解压失败） |
| 签名 | 无 | `ILIB v1.0-WEMADE` |

**判定**：**两套是不同的 WIL 变体**。
Preview 源码的 `wmM3Zip` 是**它自己那一套**（25 B 头 + 17 B 图头 + zlib），
真实 EI 资源是 `ILIB v1.0-WEMADE` 签名的那一套。
两者**不能互相解析**。

→ **再次印证贯穿本 Goal 的结论**：Preview 版与原版是**同引擎不同构建**，
资源容器、帧号、UI 布局三者都不通用。**原版资源仍必须以 `wilsdk.py`/`zlsdk.py`
为唯一权威解析器**（实测正确），源码只用于**理解设计意图**。

---

## 5. 本轮对仓库工具链的净收益

| 收益 | 内容 |
|---|---|
| ✅ 正向验证 | `wilsdk.py` 在真实 EI `.wil` 上解析正确（count/宽高/偏移/阴影齐全） |
| ✅ 格式谱系 | 9 种 `TWILType` 枚举，明确了 `.Lib`=`t_wmMyImage` / `.wil`=`t_wmM3Def` 的分工 |
| ✅ 回退规则 | `uWilFile.pas:189-201` 给出 `.Lib → .wil` 的精确回退条件 |
| ✅ 色转换 | `LineR5G6B5_A8R8G8B8` 的位运算公式（5/6/5 → 8/8/8，无抖动） |
| ⚠️ 缺口确认 | `BitChange.inc`（479 KB A1R5G5B5 LUT）被 `WIL.pas:9` 引用但**未入库** |
| ⚠️ 阅读陷阱 | `wmM3Zip.pas:156-160` 两次 `Read` 都写同一 `inBuffer^`，前 6 字节被覆盖 —— 解码器必须保留该偏移 |
| ✅ `.wix` 语义 | 实测确认为**纯偏移表**（指向 `.wil`），不是「索引+数据」 |

---

## 6. 待办

| 项 | 说明 |
|---|---|
| `BitChange.inc` | 需从原 rar 取回才能做 A1R5G5B5 的逐像素精确对照 |
| `wmM2Zip.pas`（Mir2 压缩变体） | 未读 |
| `wmMyImage.pas`（`.Lib` 格式） | 未读 —— 这是 Preview 版 `.Lib` 的解析器 |
| `wilsdk.py` 是否支持 `.wix` 的 20 字节 0 头变体 | 本阶段只测了 `.wil` 侧 |
| `zlsdk.py` 对真实 `.Zl` 的验证 | **本机没有 `.Zl` 文件**（`mir2ei` 与 EI 客户端目录均无），未能实测 |
| `wmUtil.pas`（4497 行，图像/压缩工具） | 未读 |

---

## 7. 复核方式

```bash
# 源码侧
python3 Tools/source-read/read_src.py show Source/Client/WIL.pas --start 9 --end 40
python3 Tools/source-read/read_src.py show Source/Client/wmM3Zip.pas --start 136 --end 214
python3 Tools/source-read/read_src.py show Source/Client/uWilFile.pas --start 184 --end 203

# 真实资源侧（本仓库工具链）
python3 -c "
import sys; sys.path.insert(0,'Tools/common')
import wilsdk
lib = wilsdk.WilLibrary('/home/tetsuya/mir2ei/Data/MagicEx.wil')
print('count', lib.count); print(lib.header(0)); print(lib.header(2))
"
```

---

## 8. `.Lib` 格式（`wmMyImage.pas`）—— **Preview 优先加载的格式**（Round 824）

> `Source/Client/wmMyImage.pas`（741 行）。
> **这是 `uWilFile.pas` 优先加载、失败才回退 `.wil` 的那个格式**
> （§1 已记录 `WILType in [t_wmMyImage]` 的回退条件）。

### 8.1 三个格式常量（`:7-10`）

```pascal
HEADERNAME = 'Mir3 Library';   // ← Title 字段的内容（16 字节）
CHECKENSTR = 'lom2com';        // ← 加密校验串
MYFILEEXT  = '.Lib';           // ← 扩展名
```

> **`lom2com`** 与 `reference/mir3-source/README.md` §1 记录的
> SVN 出处 `code.lom2.com/svn/Mir2` **同源** —— 这是 LOM2 社区自己加的格式。

### 8.2 `TWMImageHeader` = **56 字节**（`:13-25`）

| 字段 | 偏移 | 大小 | 说明 |
|---|---:|---:|---|
| `Title` | 0 | 16 | 应为 `'Mir3 Library'` |
| `sEnStr` | 16 | **7** | 加密校验区（加密时存 `lom2com` 的密文） |
| `nVer` | 23 | 1 | **版本；`nVer = 1` 表示启用加密**（`:232`） |
| `ImageCount2` | 24 | 4 | 加密时的图像数（`:261` 用它覆盖 `ImageCount`） |
| `IndexOffset1` | 28 | 4 | — |
| `IndexOffset2` | 32 | 4 | — |
| `OffsetSize` | 36 | 4 | 索引区压缩后大小（`> 0` 表示索引被 ZIP 压缩） |
| `ImageCount` | 40 | 4 | 图像数 |
| `UpDateTime` | 44 | 8 | `TDateTime`（Double） |
| `IndexOffset` | 52 | 4 | 索引区偏移 |
| **合计** | | **56** | |

### 8.3 `TWMImageInfo` = **18 字节**（`:27-31`）

| 字段 | 大小 | 说明 |
|---|---:|---|
| `DXInfo: TDXTextureInfo` | **13** | `nWidth(2) nHeight(2) px(2) py(2) bShadow(1) shShadowPX(2) shShadowPY(2)` |
| `btImageFormat: TWILColorFormat` | 1 | 色格式（4 种，见 §1） |
| `nDataSize: Integer` | 4 | 数据大小 |
| **合计** | **18** | |

> ⚠️ **与 `.Zl`（`wmM3Zip.pas`）的 `TWMImageInfo` 是 17 字节不同**
> （§2.2 记录的是 17 字节）—— **两个格式的图头不一样，别混用**。

### 8.4 加密机制（`:232-238`）

```pascal
FboEncryVer := FHeader.nVer = 1;                    // 版本 1 = 加密版
FCanEncry := FboEncryVer and (FPassword <> '');     // 还需提供密码
if FCanEncry then begin
   DecryBuffer(FPassword, @FHeader.sEnStr[0], @sEnStr[0], 8, 8);
   if sEnStr <> CHECKENSTR then                     // 校验解密结果
      FCanEncry := False;
end;
```

**三重要点**：
1. **加密由 `nVer = 1` 标记**，且**必须有 `FPassword`**（密码来自外部）。
2. **校验方式是解密 `sEnStr`（7 字节）后比对 `'lom2com'`** ——
   **密码错误则 `FCanEncry := False`，静默降级为不加密读取**。
3. `DecryBuffer` 来自 `DES` 单元（`:5` `uses ... DES`）——
   **是 DES 加密**，不是 `EDCode.pas` 的 WEMADE 算法。

> ⚠️ **与 WEMADE 加密（`server.md` §13.10）是两套不同机制**：
> - **`.Lib` 加密** = **DES**（`DecryBuffer` + `lom2com` 校验）
> - **QuestDiary 文本加密** = **WEMADE**（`EDCode.Decrypt` + `F0 39 AB 8E` 种子）

### 8.5 索引区读取（`LoadIndex`，`:246-295`）

```
Seek(FHeader.IndexOffset)
if FHeader.OffsetSize > 0 then          // ← 索引被压缩
   Read(pvalue, OffsetSize)
   OffsetSize := ZIPDecompress(pvalue, OffsetSize, ImageCountSize, OffsetBuffer)
   if OffsetSize = ImageCountSize + 10*4 then       // ← 校验解压大小
      Move(OffsetBuffer[10*SizeOf(Integer)], FIndexList.List^, ImageCountSize)
      //                  ↑ 跳过 10 个 int32 的头部
else                                     // ← 索引未压缩
   Read(OffsetBuffer, ImageCountSize)
   Move(OffsetBuffer^, FIndexList.List^, ImageCountSize)
```

**两个关键点**：
1. **索引区可选 ZIP 压缩**（由 `OffsetSize > 0` 标记）。
2. **压缩时解压结果前有 10 个 int32 的头部**（40 字节）需跳过 ——
   且解压大小必须**恰好等于 `ImageCountSize + 40`**，否则判为无效。

**防御性检查**：`OffsetSize > 1024*1024*50`（50 MB）直接放弃（`:258`）。

### 8.6 与其他格式的关系（更新 §1 的格式谱系）

| 格式 | 解析器 | 头部 | 图头 | 压缩 | 加密 |
|---|---|---:|---:|---|---|
| **`.Lib`** | `wmMyImage.pas` | **56 B**（`Mir3 Library`） | **18 B** | 索引可选 ZIP | **DES**（`nVer=1`） |
| `.wil/.wix` | `WIL.pas`（`t_wmM3Def`） | 实测 `ILIB v1.0-WEMADE` | 16 B | 无 | 无 |
| `.Zl` | `wmM3Zip.pas`（`t_wmM3Zip`） | 25 B 索引头 | **17 B** | zlib | 无 |
| Mir2 压缩 | `wmM2Zip.pas` | 未读 | 未读 | 未读 | 未读 |

→ **三种容器的头部/图头/压缩/加密全都不同** ——
**做解码器时必须先识别容器类型，不能假设统一格式**。

### 8.7 未验证项

| 项 | 原因 |
|---|---|
| `DecryBuffer` 的 DES 具体实现 | 在 `DES` 单元（未读） |
| `FPassword` 的来源 | 未追（`uWilFile.pas` 有 `AWMImages.Password`） |
| `FormatHeader`/`FormatImageInfo`/`FormatDataBuffer` 的加密写出 | `{$IFDEF WORKFILE}` 条件编译，客户端不启用 |
| `IndexOffset1`/`IndexOffset2` 的用途 | 未追（只读了 `IndexOffset`） |
| `wmM2Zip.pas`（Mir2 压缩变体） | 未读 |
| `wmUtil.pas`（4,497 行） | 未读 |
| 用真实 `.Lib` 文件验证 | **本机无 `.Lib` 文件**（`mir2ei` 与 EI 客户端目录只有 `.wil/.wix`） |
