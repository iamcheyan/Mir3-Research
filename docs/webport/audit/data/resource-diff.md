# D. 资源对比:WebData WebP 帧 vs 原始 .Zl 帧

> 生成时间:2026-08-14 · 机器可读明细见同目录 `resource-diff.json`
> 样本来源:`Tools/webport/static/js/themes/zircon/{login,select,game}.js`、`dx.js`、`skin.js`
> 解码器:`Tools/common/zlsdk.py`(ZlLibrary)· WebP 源:`Debug/Client/WebData/sprites/`

## 结论(先行)

1. **像素质量无可挑剔**:49 个可比帧(53 个抽样中)全部 **PSNR=∞(黑底合成 MSE=0)**,无一帧 PSNR<45,无一帧 R/B 通道交换,无一帧 alpha 差异。WebP 采用 lossless 编码,视觉内容与 .Zl 解码结果**完全等价**。
2. **真正的问题在「预生成快照不完整」而非图像质量**:
   - 4 个抽样帧 **webp 文件缺失**(选人界面 Wizard-M/Assassin-M intro 动画首帧、法师/刺客职业图标);
   - WebData 92 个库中 **69 个缺 `manifest.json`**(含抽样涉及的 Mon-1、Mon-2、ProgUse、Storeitem)——纯静态部署下 skin.js 对这些库**整库返回 null**。
   - 两者在 serve.py 运行时均**可按需自愈**(webp 缺失时抽取,manifest 缺失时生成,见 serve.py:163-167/176-180);但首次访问有延迟,且脱离 serve.py 的静态快照不可用。
3. **帧号映射零错误**:所有已生成 manifest 的库,`{idx:[w,h,ox,oy]}` 与 zlsdk 解出的 header **逐帧一致**(尺寸/偏移 0 不一致),manifest 帧数与 .Zl 有效帧数完全相等,无「有 webp 无 manifest 条目」的孤儿文件。

## 总量与达标率

| 指标 | 值 |
|---|---|
| 抽样帧总数 | **53**(登录+选人 Interface1c 21 + Interface 9 + GameInter 13 + 怪物 5 + 物件/武器 icon 5) |
| 完全达标 (ok) | **42 / 53 = 79.2%** |
| 可像素比对(存在 webp) | 49 |
| 不可比(缺 webp) | 4 |
| 缺 manifest 库(抽样涉及) | 4(Mon-1、Mon-2、ProgUse、Storeitem) |

## PSNR 分布

| 统计 | 值 |
|---|---|
| PSNR=∞(合成 MSE=0) | **49 / 49(100%)** |
| PSNR<45(差异帧) | 0 |
| 有限 PSNR min / median / mean | 无有限值(全部逐位一致) |
| RGBA 全通道逐位一致 | 25 帧 |
| 仅 alpha=0 不可见像素 RGB 有差 | 24 帧(视觉零影响,见下) |

**关于 24 帧「不可见像素差异」**:DXT 解码对全透明 texel 的 RGB 产出是未定义垃圾值,WebP lossless 往返后这些 alpha=0 像素的 RGB 被归一。差异全部落在 `alpha=0` 的像素(已逐帧程序验证),合成到黑底后与原帧零差别。最大者为 Interface1c:2800(选人界面左光晕,1024×746 中 362,736 个透明像素 RGB 不同,可见像素 0 差异)。

## 调色核对

- **通道顺序**:0 帧检出 R/B 交换(逐帧比较「直接 MAE vs 交换 MAE」,全部直接匹配更优)。
- **alpha 通道**:0 帧 alpha 差异(`alpha_diff_ratio` 全部为 0)。
- **半透明边缘**:0 帧 `0<alpha<255` 像素占比差异。

## 异常帧清单(ok=false,共 11 帧)

### 缺帧(webp 不存在,4 帧)

| 库 | 帧 | 用途 | 说明 |
|---|---|---|---|
| Interface1c | 740 | select.js Wizard-M intro 动画 base(20 帧) | .Zl 有帧(256×512),manifest 有条目,仅 webp 未预生成 |
| Interface1c | 1740 | select.js Assassin-M intro 动画 base(25 帧) | 同上 |
| Interface | 28 | select.js 角色列表职业图标-法师 | .Zl 有帧(64×64),manifest 有条目,仅 webp 未预生成 |
| Interface | 30 | select.js 角色列表职业图标-刺客 | 同上 |

### 库级 manifest 缺失(像素完美但整库无元数据,7 帧)

| 库 | 抽样帧 | 像素结果 | 影响 |
|---|---|---|---|
| Mon-1 | 0、1 | RGBA 逐位一致 | 预生成快照整库无 manifest → skin.js frame() 返回 null |
| Mon-2 | 0 | RGBA 逐位一致 | 同上 |
| ProgUse | 220、260 | RGBA 逐位一致 | 同上 |
| Storeitem | 0、1000 | 合成 MSE=0 | 同上 |

WebData 全局:92 库中 69 库缺 manifest.json(Flag、M-Weapon×15、MagicEx×7、Mon-×35、ProgUse、Storeitem、WM-Hum 等;完整名单见 json `summary.webdata_libs_without_manifest_names`)。

## 帧号映射核对(库级)

| 库 | manifest 帧数 | .Zl 有效帧数 | 预生成 webp 数 | 尺寸/偏移不一致 | 孤儿 webp |
|---|---|---|---|---|---|
| Interface1c | 1488 | 1488 | 287 | 0 | 0 |
| Interface | 282 | 282 | 15 | 0 | 0 |
| GameInter | 2485 | 2485 | 13 | 0 | 0 |
| Mon-3 | 2208 | 2208 | 288 | 0 | 0 |
| M-Weapon1 | 6840 | 6840 | 2184 | 0 | 0 |
| Mon-1 / Mon-2 / ProgUse / Storeitem | —(缺) | 1830/1688/392/2370 | 201/192/2/734 | 无法核对 | — |

manifest 由 `webres.cmd_manifest` 直接抄录 `lib.header()` 的 w/h/ox/oy,与 zlsdk 同源,故已生成的映射零偏差属预期;风险仅在「未生成」。

## 体积

49 个可比帧:.Zl 帧载荷合计 2,434,074 B → WebP 合计 2,216,282 B(**0.91×**,压缩比 1.10×)。抽样以 UI/纯色帧为主,与 ESTIMATE.md 的实测区间一致;逐帧字节数见 json。

## 建议

1. 跑一次 `webres` 全库 manifest 批量生成,消除 69 库缺口(serve.py 已有按需路径,补齐仅是快照完整性问题);
2. 预生成 login/select 实际引用的帧(尤其 Interface1c 700-1999 intro 段与 Interface 27-30 职业图标),避免首访按需抽取卡顿;
3. 图像管线本身(lossless WebP + manifest 映射)**无需任何改动**。
