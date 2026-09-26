# 独立验证记录（源码精读 Goal 阶段 6）

> 纪律（本仓库既定）：**验证工具不得与生产工具共用同一错误** ——
> 校验脚本若复用生产工具的解析逻辑，错误会被「自洽」掩盖。
> 本文记录每一项产出**用什么独立路径**验证、结果如何、以及**哪些没验**。

---

## 1. 协议常量表（474 条）—— ✅ PASS

| 项 | 内容 |
|---|---|
| 生产工具 | `Tools/source-read/extract_protocol_constants.py`（**逐行正则** `^\s*NAME = VALUE;`） |
| 验证工具 | `Tools/source-read/verify_protocol_constants.py`（**分号切语句**再抠 `NAME = VALUE`） |
| 路径差异 | 完全不同的解析策略：行级 vs 语句级 |
| 结果 | 两套独立解析在 **474 条**上完全一致 → `VERIFY PASS` |

### 1.1 验证过程中抓出的两个真 bug（有价值的过程记录）

1. **分号片段可能以上一行行尾注释开头**：
   ```
   ' //교환하는 돈이 변경됨\r\n   CM_DEALEND              = 1030'
   ```
   若先 `split('//')[0]` 会得到空串，**把真正的名字一起丢掉** →
   首轮验证报「TSV 474 vs 独立解析 266」。修正为「在整段里找完整的
   `NAME = VALUE` 模式」后一致。
2. **必须排除被注释掉的整行定义**：
   ```
   //SM_READYFIREHIT         = 1000;  //클라이언트에서만 쓰임
   ```
   这类是历史遗留/未启用常量。生产工具（逐行 `^\s*NAME`）天然排除，
   验证器也必须排除，否则误报 5 条「缺失」。
   修正后 474 = 474。

> 这两个 bug 恰好证明**独立实现的价值** —— 若验证器复用生产解析逻辑，
> 两个错误都不会暴露。

### 1.2 编码混合性的独立验证

`Grobal2.pas:419` 的 `//防御上限`（GB18030 字节 `b7c0 d3f9 c9cf cfde`）
在整文件 CP949 判定下会变乱码 `렝徒龜龜`。验证方法：**直接读原始字节**
（`read_src.py` 走逐行计分 + 混合行重解），确认该行能正确解出中文，
同时同文件 `:1748` 的韩文 `// 친구설명 변경` 不受影响。

---

## 2. 线格式参考实现 —— ✅ SELFTEST PASS（10 项）

`Tools/source-read/edcode.py selftest`：

| # | 测试项 | 结果 |
|---|---|---|
| 1 | 6bit 往返（空/单字节/ASCII/全 256 字节/全零） | ✅ |
| 2 | 非零公钥往返（含真实默认 `0x6501`） | ✅ |
| 2b | `key_xor` 必须是 `HIBYTE+LOBYTE`（**加法**）→ `0x6501` → `0x66` | ✅ |
| 3 | 编码输出必须落在可打印区间 `[0x3C, 0x3C+64]` | ✅ |
| 4 | 非法字符导致整包作废（返回空） | ✅ |
| 5 | `TDefaultMessage` 线长必须 16 字节 | ✅ |
| 6 | 消息往返（固定 RandKey 保证确定性） | ✅ |
| 7 | `Etc` 低字节 = `RandKey ^ 8` | ✅ |
| 8 | `Etc` 高字节 = `(校验和 ^ key ^ randkey) & 0xFF` | ✅ |
| 9 | `MakeDefaultMsg` 的 hid 掩码：`hid=200` → `Etc=0xD2`/`Etc2=0x41` | ✅ |
| 9b | hid 高 16 位参与 `Etc`（HIWORD 分支生效） | ✅ |
| 10 | `old_checksum` 与 `checksum` 在 key=0 时相同 | ✅ |

### 2.1 一处**测试期望值错误**的修正记录

初版测试写 `hid=200` 应得 `(0x5A, 0x69)` —— 那是**手算猜的**，实际逐字翻译
`Grobal2.pas:2848-2849` 得 `(0xD2, 0x41)`。**实现是对的，测试期望是错的**。
已改为按公式重算的 `0xD2/0x41`，并补了 9b 验证 HIWORD 分支。

> 记录此事的价值：说明本 Goal 的验证**不假设自己正确**，
> 冲突时回到源码公式逐字核对。

### 2.2 端到端实测（`key=0x6501`）

```
输入: Recog=12345 Ident=1033 Param=1 Tag=2 Series=3 RandKey=0x5A
校验和 = 0x7187
高字节 = (0x7187 ^ 0x6501 ^ 0x5A) & 0xFF = 0xDC
低字节 = 0x5A ^ 0x08 = 0x52
Etc    = 0xDC52     ← 与参考实现输出一致
解码回读: Ident/Recog 一致 ✅
```

---

## 3. 帧号空间 —— ✅ 已用原版元数据独立交叉

| 项 | 内容 |
|---|---|
| 生产工具 | `Tools/source-read/extract_client_windows.py`（正则抓 `SetImgIndex`/`Images[N]`） |
| 验证工具 | `Tools/source-read/frame_overlap.py`（独立重抓 + 与**原版元数据文件**求交） |
| 外部基准 | `docs/research/ei-ui-layout/gameinter-frame-metadata.json` 的 `library_count: 1103`（来源：真实 EI `GameInter.wil`） |
| 结果 | 91 个唯一帧号；落在 0–1102 的 **10 个**；与已详查 37 帧**交集为空** |

**这是「用外部基准验证」而非「自洽验证」** —— 基准来自原版资源文件，
与源码无任何共同来源。

---

## 4. `.map` 格式 —— ✅ 已用两个独立路径验证

| 路径 | 方法 | 结果 |
|---|---|---|
| A：源码结构定义 | `Envir.pas:49-77` 的 `TMIR3MapHeader`/`TileHeader`/`CellHeader` 逐字翻译 | 28 + (W·H/4)·3 + W·H·14 |
| B：仓库既有工具 | `Tools/maps/map_roundtrip.py` 的 `indep_parse`（**手工字节索引，不用 struct/MapCell**） | `0.map` → 800×800 完整；`0_002.map` → 20×20 **缺 29 格** |

**交叉结论**：
- `0_000.map`（70×70）实测 72,303 B = A 公式预测 72,303 B → ✅ **精确吻合**
- `D614.map`（100×100）实测 137,528 B ≠ 147,528 B → 差异查明为**数据截断**
- B 路径独立确认 6/200 个文件是 C=13（截断），**且仓库工具已正确处理**

> ⚠️ 注意 B 路径的注释自述「不复用 mapedit 的 struct.unpack_from + MapCell 对象模型」
> —— 这正是本仓库纪律的体现，本次直接受益。

---

## 5. WIL 格式 —— ✅ 已用真实资源验证

| 项 | 内容 |
|---|---|
| 生产工具 | `Tools/common/wilsdk.py`（仓库既有，**不是本 Goal 新增**） |
| 验证方式 | 用真实 EI 资源 `/home/tetsuya/mir2ei/Data/MagicEx.wil` 实跑 |
| 结果 | `count = 1780`，与文件头 `@24` 的 int16 **自洽**；`header(0)` = 16×16 offset(4,-14) shadow(7,-44) words=152 bytes=304；`header(2)` = 32×32 offset(-3,-18) |

**这是正向验证**：证明仓库既有工具链在真实资源上无误。
同时**反向证明**了 Preview 源码的 `wmM3Zip.pas` 格式与真实资源**不兼容**
（25B 头 vs 20B 全 0 头；`ILIB v1.0-WEMADE` 签名等）。

---

## 6. 配置对比 —— ✅ 脚本可复现

`Tools/source-read/env_compare.py` 统计 `Envir/` vs `Envir3/`：
文件数（391 vs 1802）、总字节、空文件清单、同名文件大小对照、仅 Envir3 有者。

结果可复现，且**空文件清单是逐文件 `os.path.getsize` 实测**，不是推断。

---

## 7. ❌ **未验证**项（明确列出，不假装已验）

| 项 | 为什么没验 |
|---|---|
| `zlsdk.py` 对真实 `.Zl` | **本机没有 `.Zl` 文件**（`mir2ei` 与 EI 客户端目录均无） |
| 那 10 个共同范围内帧号是否同图 | 需同时具备原版 WIL 与 Preview 版 WIL 做逐帧像素比对 |
| `BitChange.inc` 的 A1R5G5B5 转换表 | **文件未入库**（需先找回 53 MB 原件 rar） |
| `CM_ADDNEWUSER`/`CM_CHANGEPASSWORD`/`CM_UPDATEUSER` 的接收端 | 全仓未找到 `case`，**可能是本源码包不完整**，未做进一步推断 |
| `Envir3/QuestDiary/` 脚本语法 | 未读解析器 |
| MonQuest 私有编码 | 未破译 |
| DFM 字符串属性 | 长度前缀异常，仅几何属性可靠（已在文档中标注边界） |
| `ObjBase.pas` 方法实现（31,768 行） | 只读了类声明与字段 |
| 服务端是否读 `Envir3/` | README 称 grep 0 次；本 Goal 复验结果**同样是 0 次**（grep 全仓 `Envir3` 无命中），但未穷尽所有间接引用方式 |

---

## 8. 复核命令汇总

```bash
cd /home/tetsuya/development/Mir3-Research

# 1. 协议常量表（生成 + 独立校验）
python3 Tools/source-read/extract_protocol_constants.py --check
python3 Tools/source-read/verify_protocol_constants.py        # 期望 VERIFY PASS

# 2. 线格式参考实现
python3 Tools/source-read/edcode.py selftest                   # 期望 EDCODE SELFTEST PASS

# 3. 帧号空间
python3 Tools/source-read/extract_client_windows.py
python3 Tools/source-read/frame_overlap.py

# 4. 分派覆盖
python3 Tools/source-read/coverage.py

# 5. 配置对比
python3 Tools/source-read/env_compare.py

# 6. DFM 解析
python3 Tools/source-read/dfm_parse.py list reference/mir3-source/Source/Client/FState.dfm

# 7. .map 格式（仓库既有独立解析器）
python3 -c "
import sys; sys.path.insert(0,'Tools/maps')
import map_roundtrip as MR
for p in ('/home/tetsuya/mir2ei/Map/0.map','/home/tetsuya/mir2ei/Map/0_002.map'):
    m = MR.indep_parse(p); print(p.split('/')[-1], m.w, m.h, m.n, m.n_records)
"

# 8. WIL 真实资源
python3 -c "
import sys; sys.path.insert(0,'Tools/common')
import wilsdk
lib = wilsdk.WilLibrary('/home/tetsuya/mir2ei/Data/MagicEx.wil')
print('count', lib.count); print(lib.header(0))
"

# 9. 全量 git 检查
git diff --check
```
