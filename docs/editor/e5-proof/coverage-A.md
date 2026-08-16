# E5 阶段 A 覆盖率对账报告

生成: 2026-08-16 12:03 · coverage_audit.py (独立解析, 不复用生成器)

## 1. FrameSet.cs ↔ frame-formulas.json frameSets
- FrameSet.cs 赋值字典: **94**; JSON frameSets: **94**; 另有 2 个声明未赋值的死声明 ['LobsterSpawn', 'ShinsuBig'] (原版即如此, 不入数据层)
- JSON 帧表项总数: 560
- ✓ 100% 双向覆盖 (camelCase 映射)

## 2. MagicEffectTable.cs ↔ magic-effects.json (godot 段)
- _table 条目: **146**; JSON godot 技能: **146**
- _attackTable 条目: **26**; JSON attackTable: **26**
- 原版段技能: 138; 双源共有: 136
- ✓ 100% 双向覆盖 (含 attackTable)

## 3. 三张音效 catalog ↔ sounds.json
- SoundCatalog 条目: 源 731 / JSON 731
- MagicSoundCatalog: (magic,phase) 源 159 / JSON 159; SoundSpec 源 160 / JSON 160
- MonsterSoundCatalog: 源 118 / JSON 118
- ✓ 100% 双向覆盖 (键集与规格数逐项相等)

## 结论
✓ 三组全部 100% — 阶段 A 覆盖率验收通过
