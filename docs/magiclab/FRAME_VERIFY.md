# Magic Lab — 帧可解码性交叉验证报告

- 事实源: `Tools/magiclab/magic-effect-table.json`
- 基准帧检查点: 536 个（每特效首/尾帧硬校验）
- 库目录: `/home/tetsuya/development/zircon/Debug/Client/Data`
- 结果: ✅ 全部通过
- 原版资源现状（非提取错误）: 7 个基准帧空白 + 257 个方向偏移帧空白/越界——原版播放到这些帧同样不绘制，行为一致
全部声明基准帧在真实 .Zl 库中存在且在库界内。

## 基准帧空白明细（原版资源现状，提取与原版一致）

- DoomClawLeftPinch/start MonMagicEx19#2660
- DoomClawRightPinch/start MonMagicEx19#2640
- Repulsion/start Magic#99
- SwiftBlade/release MagicEx2#2345
- TheNewBeginning/start MagicEx4#2207
- WraithGrip/release MagicEx4#1440
- WraithGrip/release MagicEx4#1453