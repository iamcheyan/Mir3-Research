# EI 技能书差异矩阵（2026-09-25）

范围：Zircon `ui/legacy-layout-lab` 的 `MagicDialog` / `MagicBar` / 入口键位，与 EI 原版 `window.skill-book` 对照。运行资源只使用 `/home/tetsuya/mir2ei/Data`；研究工件源文件路径仅作为证据来源，不作为运行时资源。

## 证据裁决

- `skill-window-context.json`、`skill-window-render-loop-evidence.json` 的 2026-08/09 primary-static 记录优先于旧模拟器摘要中把 8 个类别控件称作 8 个技能格的描述。
- 原版已确认：F400 书本帧、8 个纵向类别按钮、3 个额外控件、6 个左页命中 RECT 的选择链、右页 `Magic.exp` 段落渲染。
- 原版未闭合：6 个左页 RECT 的具体运行时写入值、完整类别链表成员/排序、F440/441 的业务动作、F1-F12 在技能书内的绑定语义、F400 根 RECT 与主初始化 296×332/包装器 452×380 的冲突。
- F400 本机 EI 资源帧事实：512×512 画布；当前 Zircon 用有效绘制区配准为根 452×380、图片原点 (-30,-67)。这不等同于已证明最终根 RECT。

## 矩阵

| 区域/状态 | 原版证据 | 当前实现 | 差异与修复 | 运行验收 | 等级 |
|---|---|---|---|---|---|
| 根窗口、裁剪 | `window-initialization-evidence.json` id14/F400 记录 296×332；`layout.json` 派生记录 452×380；本机 F400 512×512 与 alpha 配准证据 | `MagicDialog.ApplyLegacyEiLayout()` 根 452×380，F400(-30,-67)，`Clip=true`；关闭 F161/162 | 保留 452×380 作为当前资源配准，显式记录 296×332 冲突；不得把二者伪合并 | 当前提交构建 `skill-book-current-audit-2026-09-25.png` 的 1024×768 像素审计仍得到非背景 bbox `(572,0)-(1024,378)`；可见书页被 viewport 右边界裁到 x=1024，未将像素 bbox 伪称窗口 RECT；296×332 vs 452×380 仍需对象级导出 | primary-static + runtime pixel audit |
| 左页类别列 | `skill-window-context.json.category_labels`：火/冰/电/风/神圣/黑暗/幻影/剑，位置 (5,21)…(2,266)，帧 450/452/454/456/458/460/462/464；命中 RECT 44/48×36 | 8 个 `DXButton` 使用上述帧/位置，顺序固定为 `LegacySchoolOrder` | 静态几何已按 primary 证据闭合；业务成员仍来自当前 `MagicInfo`，不是 EI `Magic.exp` 分类链表 | `skill-book-initial-2026-09-25.png`、`skill-book-ice-2026-09-25.png`、`skill-book-physical-category-2026-09-25.png` 实屏确认类别纵列不横移，切换后页码归 1 | primary-static + runtime visual |
| 左页技能行 | `skill-window-render-loop-evidence.json`：`0x43A370` 遍历 6 个 RECT；`skill-book-category-tabs-evidence.json` 确认类别 byte/list 关系 | 旧 12 格 F410..F421 候选已移除；建立 6 行 `LegacySkillRowView`，位置按 F400 行槽配准 `(61,51+i*37)`，位置标为 candidate | 修复已确认导航帧冒充技能图标；6 行数量匹配 hit-test 上限，但具体 RECT/记录排序仍未闭合 | Fire 主页/第二页与 Physical 少于一页已实屏：`skill-book-initial-2026-09-25.png`、`skill-book-page2-2026-09-25.png`、`skill-book-physical-category-2026-09-25.png`；中心点击选中链通过 | primary count; runtime visual |
| 左页行状态 | `0x4397A0` 记录技能图标、名称、4 边高亮框；`0x43A370` 返回技能 ID | 行绘制 EI MIcon 运行时纹理、名称、已学习/未学习状态；选中绘制半透明高亮和边框 | 当前选中链已写入 Godot 状态并刷新右页；原版颜色/确切文本基线仍需实屏对照 | `skill-book-selected-2026-09-25.png` 显示 Fire Ball 选中边框、图标和名称；悬停/不可用颜色仍未单独闭合 | primary render role; runtime selected |
| 右页名称/详情 | `skill-window-render-loop-evidence.json` Finding 272：选中 ID `this+0x964`；X=winX+235，首行 winY+30，行距 15；名称四角阴影 0x0A0A0A + 0x96C8FA，普通行 0x0A320A | `LegacySkillDetailView` 按所选 `MagicInfo` 绘制名称、属性、元素、状态/等级、修炼值、说明；名称阴影/颜色/15px 行距 | 右页从空白补为可选详情；字段来源为当前 DB `MagicInfo`，需与目标 EI `Magic.exp` ID/名称映射交叉核对 | `skill-book-selected-2026-09-25.png` 实屏显示 `[火球术]`、属性/元素/等级/修炼值/说明；空详情见初始图 | primary-static geometry/style; runtime visual |
| 右页换行/裁剪 | 旧 parser 工件记 wrap 宽度 0xA5；较新 Finding 272 证明本构建 formatter 路径 count 恒 1、每行一条记录。两者存在语义冲突 | `LegacySkillDetailView` 按 165px 宽度逐字符测量换行，最多绘制到 y=290；父窗 Clip | 选择符合用户验收的 165px 行宽换行，同时把“原版实际是否扩展行”列为证据冲突；不声称 byte parity | `skill-book-selected-2026-09-25.png` 中英文说明分两行且没有越过右页；更长描述/底边截断仍需专门数据态 | primary geometry; wrap conflict |
| 翻页按钮与计数 | F410/411 `(61,303)`、F412/413 `(366,303)`；页码候选 x117/y299、x118/y309；F440/441 `(399,340)` 业务未决 | F410/F412 映射前后页，按 6 行分页；F440/441 静态显示为不可交互辅助控件；计数由详情控件绘制 | 前后页边界 clamp；F440/441 不伪造动作。分页总数按当前运行列表，不能证明 EI `/3` 记录算法完全相同 | `skill-book-page2-2026-09-25.png` 日志 `page=2/2 school=Fire`，页码/箭头状态实屏通过；前翻与边界未单独截图 | primary geometry; runtime page |
| 分类数量/职业 | EI 分类顺序 primary；`Magic.exp` 50 条 ID/名称/属性/元素/等级/说明，职业仅 semantic candidate；当前 `MagicInfo.Class/School` | 仍按当前 DB `Class` 过滤、按 `NeedLevel1/Name` 排序；所有 8 类按钮恒显示 | 移除固定 12 格；仍缺目标 EI 逐职业分类链表和排序的独立交叉证据 | Fire/ Ice/Phantom/Physical 实屏切换成功并记录 count；本次未切换职业，职业差异仍 pending | primary source records; runtime partial |
| 技能图标映射 | `skill-tab-header-draw-evidence.json`：原版类别图标帧 `[skill+6]`，MIcon/WIL 0x566C90；本机 MIcon.wil/wix | 行/现代栏使用 `MirSkin.GetTexture(MagicIcon, info.Icon)`，legacy 资源根读 `/home/tetsuya/mir2ei/Data/MIcon.wil`；已导出当前 DB 174 条记录、164 个唯一帧的 header offset/尺寸/alpha bbox（见 `magic-icon-metadata-2026-09-25.json`） | 当前 Zircon 的 `MagicInfo.Icon`→MIcon 资源链已逐项可复现；这不是 EI `Magic.exp` 的 `[skill+6]` 逐项证明，禁止把现代同号帧宣称为原版帧 | 当前提交构建 `skill-book-current-selected-audit-2026-09-25.png` 与日志 `MagicIcon -> /home/tetsuya/mir2ei/Data/MIcon.wil (1106 frames)` 显示真实 MIcon；EI 逐项 ID/帧仍阻塞 | primary source + current-resource metadata; runtime visual |
| 常驻快捷栏关系 | `skill-button-click-evidence.json` 描述独立 9-button skill bar；技能书是 id14/F400，二者不是同一窗口 | `MagicBar` 是独立 Control，当前仍显示现代 12/24 槽栏；技能书不再把导航帧当快捷栏图标 | 不把 `MagicBar` 伪装成技能书组成部分；是否在 EI 模式隐藏/改成 9 槽仍需产品/原版运行证据 | 初始、关闭、重开截图均同时显示独立快捷栏；书页关闭后快捷栏继续可见，层级关系通过 | primary distinct-object; runtime visual |
| 键位入口 | `window-paint-and-hotkey-dispatch-evidence.json`：裸 E/Ctrl+E→id14；F1-F12 原版技能动作证据与书内绑定仍未闭合 | legacy GameScene 预处理裸 E/Ctrl+E 打开技能书；MagicDialog 选中后处理 F1-F12/Shift+F1-F12；Ctrl/Alt 排除；Ctrl+F1..F4 在开窗时由 GameScene 先切栏组 | 修复 parent/hover 双目标绑定；Ctrl+F1..F4 不再被书内绑定吞掉；F1-F12 仍是当前实现推断，不声称 EI 等价 | 裸 E 打开/关闭实屏通过；日志记录 `bind skill=Ice Bolt ... Spell01`；Shift/Ctrl+F1..F4 代码路径已审查但截图/日志证据不足 | primary entrance; runtime partial |
| 关闭/重开 | 原版窗口初始 hidden；选择 ID ctor 初始 -1；关闭/状态复位完整调用链未闭合 | close button、Esc、E/Ctrl+E 均走 WindowManager；选中/类别/页状态存于窗口实例，刷新时失效项清理 | 保留窗口实例状态，切类别/页清空选中；实屏重开保留类别、重置选中/页 | `skill-book-closed-2026-09-25.png` 与 `skill-book-reopen-2026-09-25.png`：书页关闭/重开有效，Ice 类页1重建且无旧详情；Esc 未单独截图 | primary lifecycle; runtime visual |
| 滚动/现代列表 | 原版证据是 6 个 RECT + 类别分页/页计数，不支持现代垂直滚动窗 | legacy 隐藏 `_list` 与 `_scrollBar`，使用 6 行/前后页 | 已移除 legacy 滚动路径；现代非 legacy 列表保留，不混入 EI 书 | 所有技能书截图无现代滚动条；Fire 两页使用箭头、Physical 三条使用空槽 | primary distinction; runtime visual |

## 已实现项（实屏已验收的部分）

- 删除 F410..F421 12 格伪图标与 legacy 现代列表混入。
- 增加 6 行 EI 左页候选布局、选中态、空状态、按类别/页刷新。
- 增加右页详情、名称四角阴影、颜色、15px 行距、165px 换行与裁剪。
- 映射 F410/F412 前后页控件，保留 F440/F441 静态不可交互控件。
- 清除分类/分页后的残留选中项，阻止 legacy `MagicCellView` 抢 F 键。
- 允许 Ctrl+F1..F4 在技能书打开时切换快捷栏组。
- 本地 1024×768 实屏已验证：打开、选择、详情、翻页、类别切换、少于一页、关闭、重开；构建后最终复核为 `skill-book-final-open-recheck-2026-09-25.png` 与 `skill-book-final-selected-recheck-2026-09-25.png`，完整截图索引见 Zircon `.artifacts/ui-acceptance-2026-09-24/SKILL_BOOK_ACCEPTANCE_2026-09-25.md`。

## 阻塞项

1. F400 最终根 RECT：296×332 primary initializer 与 452×380 派生/资源配准冲突；需目标 EI 运行时窗口对象或更深的 0x423B30 分支证据。
2. 六个左页 hit RECT 的具体写入值、真实分类链表成员/排序、三控件 click handler 尚未闭合。
3. EI `Magic.exp` 的 `[skill+6]` 与当前 `MagicInfo.Icon` 的逐项 ID/帧对应仍未证明；当前 Zircon 资源链的 174 条映射、164 个唯一帧及 header offset/alpha bbox 已导出到 `magic-icon-metadata-2026-09-25.json`，不能冒充 EI 对照。
4. `Magic.exp` 详情 wrap 的“165px intended”与“实际 count 恒1”静态记录冲突；当前实现采用 165px 安全裁剪，不能称像素级原版。
5. 原版书内 F1-F12/Shift/Ctrl 绑定链和重开状态复位仍需实机/输入路径证据。
