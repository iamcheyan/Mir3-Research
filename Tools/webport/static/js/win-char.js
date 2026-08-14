// win-char.js — 角色 CharacterDialog.cs 移植 (D路 par-win)
// 3 页签 (角色/心法/内功 :128-130) 背景图 110/112/111; 17 装备格 (SlotPositions :76-94);
// 属性 7 子页 (攻/防/重/其他/元素攻击/优势/劣势 :456-527); 内功 8 按钮 → C.Hermit;
// 心法提升 → C.IncreaseDiscipline; 体重 "Weight {wear} / Hand {hand}"。
// 数据: StatsUpdate (轮询刷新 — Godot _Process :665-680)。

import { getWindow } from './uitree.js';
import { WindowManager } from './windows.js';
import { DXControl, DXLabel, DXButton, DXImageControl } from './dx.js';
import { DXItemGrid } from './dxgrid.js';
import { GRID, STAT, STAT_NAMES, CLASS_NAMES } from './net.js';
import { skin } from './skin.js';
import { GameDB } from './gamedb.js';

// SlotPositions (CharacterDialog.cs:76-94) — [x, y]
const SLOT_POS = [
  [58, 122], [120, 123], [140, 90], [10, 196], [10, 157],      // 武器/衣服/头盔/火把/项链
  [244, 157], [283, 157], [244, 196], [283, 196], [10, 235],   // 左右镯/左右戒/鞋
  [244, 274], [283, 235], [244, 235], [283, 118], [244, 118],  // 毒符/花/马甲/徽章
  [170, 170], [10, 118],                                        // 盾/时装
];
const HIDDEN_SLOTS = new Set([0, 1, 2, 15]);   // 武器/衣服/头盔/盾 → PaperDoll 画 (这里隐藏)

export async function winChar(scene, store, reg) {
  const w = await getWindow('CharacterDialog');
  if (!w) return null;

  // ---- 页签 (SelectTab :273-289) ----
  let tab = 0;   // 0 角色 / 1 心法 / 2 内功
  const bg = w.byPath.get('CharacterDialog/0');   // 背景图
  const mkTab = (text, x, i) => {
    const b = new DXButton({
      text, fontSize: 9, library: 'Interface', index: -1,
      location: [x, 18], size: [56, 22],
      onClick: () => selectTab(i),
    });
    w.addControl(b);
    return b;
  };
  const tabs = [mkTab('角色', 8, 0), mkTab('心法', 70, 1), mkTab('内功', 132, 2)];

  // ---- 内容面板容器 ----
  const content = new DXControl({ location: [0, 45], size: [331, 443], clip: true, isControl: true });
  w.addControl(content);
  content.el.style.zIndex = '2';

  // ---- 角色页: 装备格 ----
  const equipPanel = new DXControl({ location: [0, 0], size: [331, 443], isControl: true });
  content.addControl(equipPanel);
  const grid = new DXItemGrid({
    cols: 1, rows: 1, gridType: GRID.EQUIPMENT, store,
    location: [0, 0], size: [331, 443], readOnly: true,   // 自定义布局: 逐格摆位
  });
  equipPanel.addControl(grid);
  // 清掉 1x1 默认格, 直接用 DXItemCell 逐个摆 (不走 grid 布局)
  const equipCells = [];
  for (const c of [...grid.cells]) grid.removeControl(c);
  grid.cells = [];
  // 直接用 DXItemCell 逐个摆 (不走 grid 布局)
  const { DXItemCell } = await import('./dxgrid.js');
  for (let i = 0; i < 17; i++) {
    const cell = new DXItemCell({
      grid, slot: i, location: SLOT_POS[i], size: [36, 36],
    });
    cell.visible = !HIDDEN_SLOTS.has(i);
    grid.cells[i] = cell;
    grid.addControl(cell);
    equipCells.push(cell);
  }

  // 名字/行会 (RefreshMarriageAndGuild :705-723)
  const nameLabel = new DXLabel({
    fontSize: 15, textColour: [222, 255, 222, 255], drawOutline: true, align: 'center',
    location: [97, 0], size: [137, 18], isControl: false,
  });
  const guildLabel = new DXLabel({
    fontSize: 11, textColour: [235, 235, 190, 255], drawOutline: true, align: 'center',
    location: [97, 18], size: [137, 18], isControl: false,
  });
  equipPanel.addControl(nameLabel, guildLabel);

  // 属性面板 (0,364) 331x124 — 7 子页
  const statsPanel = new DXControl({ location: [0, 364], size: [331, 124], clip: true, isControl: false });
  equipPanel.addControl(statsPanel);
  const statTabs = ['攻击', '防御', '负重', '其他', '元素攻击', '元素优势', '元素劣势'];
  const statPages = [];
  for (let i = 0; i < 7; i++) {
    const b = new DXButton({
      text: statTabs[i], fontSize: 7, library: 'Interface', index: -1,
      location: [21 + i * 44, 0], size: [43, 20],
      onClick: () => selectStatsPage(i),
    });
    statsPanel.addControl(b);
    const page = new DXControl({ location: [0, 21], size: [331, 103], isControl: false });
    statsPanel.addControl(page);
    statPages.push(page);
  }
  let statsPage = 0;
  function selectStatsPage(i) { statsPage = i; statPages.forEach((p, j) => p.visible = j === i); }
  selectStatsPage(0);

  // 属性绑定 (valueLabel, Stat, minStat) — RefreshStatsPanel :633-637
  const mkStatRow = (page, title, stat, minStat, x, y, fmt) => {
    const t = new DXLabel({ text: `${title}:`, fontSize: 8, location: [x, y], size: [70, 16], isControl: false });
    const v = new DXLabel({ text: '0', fontSize: 8, align: 'right', location: [x + 70, y], size: [60, 16], isControl: false });
    page.addControl(t); page.addControl(v);
    return { v, stat, minStat, fmt };
  };
  const S = STAT;
  const bindings = [
    // 攻击页
    mkStatRow(statPages[0], '攻击', S.MAXDC, S.MINDC, 15, 6, 'range'),
    mkStatRow(statPages[0], '魔法', S.MAXMC, S.MINMC, 15, 28, 'range'),
    mkStatRow(statPages[0], '道术', S.MAXSC, S.MINSC, 15, 50, 'range'),
    mkStatRow(statPages[0], '命中', S.ACCURACY, null, 168, 6, 'int'),
    mkStatRow(statPages[0], '攻速', S.ATTACKSPEED, null, 168, 28, 'int'),
    mkStatRow(statPages[0], '幸运', S.LUCK, null, 168, 50, 'int'),
    mkStatRow(statPages[0], '暴击', S.CRITICALCHANCE, null, 168, 72, 'int'),
    // 防御页
    mkStatRow(statPages[1], '防御', S.MAXAC, S.MINAC, 15, 6, 'range'),
    mkStatRow(statPages[1], '魔御', S.MAXMR, S.MINMR, 15, 28, 'range'),
    mkStatRow(statPages[1], '敏捷', S.AGILITY, null, 168, 6, 'int'),
    mkStatRow(statPages[1], '吸血', S.LIFESTEAL, null, 168, 28, 'int'),
    // 负重页 (WearWeight/HandWeight + BagWeight)
    mkStatRow(statPages[2], '穿戴负重', S.WEARWEIGHT, null, 15, 6, 'weight'),
    mkStatRow(statPages[2], '手持负重', S.HANDWEIGHT, null, 15, 28, 'weight'),
    // 其他
    mkStatRow(statPages[3], '回复', S.COMFORT, null, 15, 6, 'int'),
    mkStatRow(statPages[3], '拾取范围', S.PICKUPRADIUS, null, 15, 28, 'int'),
    mkStatRow(statPages[3], '爆率', S.DROPRATE, null, 168, 6, 'int'),
    mkStatRow(statPages[3], '经验加成', S.EXPERIENCERATE, null, 168, 28, 'int'),
    // 元素攻击 (mode1: +N 蓝色)
    mkStatRow(statPages[4], '火', S.FIREATTACK, null, 15, 6, 'elem+'),
    mkStatRow(statPages[4], '冰', S.ICEATTACK, null, 15, 28, 'elem+'),
    mkStatRow(statPages[4], '雷', S.LIGHTNINGATTACK, null, 15, 50, 'elem+'),
    mkStatRow(statPages[4], '风', S.WINDATTACK, null, 15, 72, 'elem+'),
    mkStatRow(statPages[4], '圣', S.HOLYATTACK, null, 168, 6, 'elem+'),
    mkStatRow(statPages[4], '暗', S.DARKATTACK, null, 168, 28, 'elem+'),
    mkStatRow(statPages[4], '幻', S.PHANTOMATTACK, null, 168, 50, 'elem+'),
    // 优势/劣势 (元素抗性)
    ...[S.FIRERESISTANCE, S.ICERESISTANCE, S.LIGHTNINGRESISTANCE, S.WINDRESISTANCE,
        S.HOLYRESISTANCE, S.DARKRESISTANCE, S.PHANTOMRESISTANCE].map((st, i) =>
      mkStatRow(statPages[5], STAT_NAMES[st] ?? `抗${i}`, st, null, i < 4 ? 15 : 168, 6 + (i % 4) * 22, 'resist')),
  ];

  const weightLabel = new DXLabel({
    fontSize: 9, textColour: [255, 255, 255, 255], drawOutline: true,
    location: [15, 395], size: [301, 18], isControl: false,
  });
  equipPanel.addControl(weightLabel);

  // ---- 心法页 (BuildAttributePanel :384-456 / RefreshDiscipline :804-819) ----
  const discPanel = new DXControl({ location: [0, 0], size: [331, 443], isControl: false, visible: false });
  content.addControl(discPanel);
  const discImage = new DXImageControl({ library: 'Interface', index: 215, location: [37, 64], isControl: false, fixedSize: true, size: [257, 193] });   // Index=215+clamp(level,0,20) (:810)
  discPanel.addControl(discImage);
  const discLevelHint = mkLabel(discPanel, '等级', 13, 313);
  const discLevel = mkLabel(discPanel, '0', 116, 314);   // _disciplineLevelValue (:397)
  const discExpHint = mkLabel(discPanel, '经验', 13, 336);
  const discExp = mkLabel(discPanel, '0/0', 14, 336);   // _disciplineExperienceLabel (:410)
  const discLabel = mkLabel(discPanel, '未修炼心法', 14, 358);   // _disciplineLabel (:422)
  discLabel.el.classList.add('__discLabel');   // 探针锚点 (避开 ui_tree 原生同名文本)
  discExp.el.classList.add('__discExp');
  discLevel.el.classList.add('__discLevel');
  discLevelHint.el.style.opacity = discExpHint.el.style.opacity = '.8';
  const btnImprove = new DXButton({
    text: '提升心法', fontSize: 9, library: 'Interface', index: -1,
    location: [182, 266], size: [120, 27],
    onClick: () => scene.conn.sendIncreaseDiscipline(),   // SendIncreaseDiscipline (:425)
  });
  btnImprove.enabled = false;
  discPanel.addControl(btnImprove);
  // 4 心法技能格 (BuildAttributePanel :429-443: MagicIcon 36x36, 点击清快捷键 ClearDisciplineMagic :790)
  const discMagicIcons = [];
  for (let i = 0; i < 4; i++) {
    const icon = new DXControl({ location: [51 + i * 62, 380], size: [36, 36], isControl: true });
    icon.el.style.cssText += 'background-size:contain;background-repeat:no-repeat;image-rendering:pixelated;cursor:pointer;border:1px solid rgba(255,255,255,.15);';
    icon.el.addEventListener('click', async () => {   // ClearDisciplineMagic :790-802
      const info = icon.__magicInfo;
      if (!info) return;
      const m = store.magics.get(info.Index);
      if (!m) return;
      m.set1Key = 0; m.set2Key = 0; m.set3Key = 0; m.set4Key = 0;   // SpellKey.None
      scene.conn.sendMagicKey(info.Magic, 0, 0, 0, 0);
      scene.addChat(`已清除心法技能 ${info.zh ?? info.Name ?? info.Index} 的快捷键`, 'system');
    });
    discPanel.addControl(icon);
    discMagicIcons.push(icon);
  }
  // RefreshDiscipline (:804-819) + RefreshDisciplineMagicIcons (:770-788)
  async function refreshDiscipline() {
    const disc = store.info?.discipline ?? null;
    const level = disc?.level ?? 0;
    let next = null, disciplineRows = [];
    try { disciplineRows = await GameDB.disciplineRows(); } catch { /* 表缺失 → Max 语义 */ }
    next = disciplineRows.find(x => x.Level === level + 1) ?? null;
    discImage.index = 215 + Math.min(Math.max(level, 0), 20);
    discLevel.text = String(level);
    discExp.text = next == null ? `${Number(disc?.experience ?? 0)}/Max` : `${Number(disc?.experience ?? 0)}/${next.RequiredExperience}`;
    discLabel.text = next == null
      ? (disc == null ? '未修炼心法' : `心法等级 ${level} 当前经验 ${Number(disc.experience)}`)
      : `需要: 等级 ${next.RequiredLevel} 经验 ${next.RequiredExperience} 金币 ${next.RequiredGold}`;
    btnImprove.enabled = next != null && (store.level ?? 0) >= next.RequiredLevel;   // :818
    // 心法技能图标: School=Discipline+职业过滤, NeedLevel1 排序, 取 4 (:773-777)
    let magics = [];
    try {
      magics = (await GameDB.magicRows())
        .filter(x => x.School === 'Discipline' && (x.Class == null || x.Class === store.info?.class))
        .sort((a, b) => (a.NeedLevel1 ?? 0) - (b.NeedLevel1 ?? 0));
    } catch { /* MagicInfo 缺失 → 空格 */ }
    for (let i = 0; i < discMagicIcons.length; i++) {
      const icon = discMagicIcons[i];
      const info = i < magics.length ? magics[i] : null;
      icon.__magicInfo = info ?? null;
      icon.el.style.backgroundImage = '';
      if (info?.Icon != null) skin.frame('MIcon', info.Icon).then(f => { if (f) icon.el.style.backgroundImage = `url(${f.url})`; });
      icon.el.style.filter = info && store.magics.has(info.Index) ? '' : 'grayscale(1) brightness(0.5)';   // learned 高亮 (:784)
    }
  }
  refreshDiscipline();
  store.on((kind) => { if (kind === 'stats' || kind === 'magics') refreshDiscipline(); });   // DisciplineUpdate/magic key 变化

  // ---- 内功页 (BuildHermitPanel :438-454) ----
  const hermitPanel = new DXControl({ location: [0, 0], size: [331, 443], isControl: false, visible: false });
  content.addControl(hermitPanel);
  const HERMIT_STATS = [
    [S.MAXAC, '最大防御'], [S.MAXMR, '最大魔御'], [S.HEALTH, '生命'], [S.MANA, '魔力'],
    [S.MAXDC, '最大攻击'], [S.MAXMC, '最大魔法'], [S.MAXSC, '最大道术'], [S.WEAPONELEMENT, '武器元素'],
  ];
  const hermitCounts = {};
  HERMIT_STATS.forEach(([st, name], i) => {
    const b = new DXButton({
      text: `内功 ${name}`, fontSize: 7, library: 'Interface', index: -1,
      location: [18 + (i % 4) * 82, 225 + Math.floor(i / 4) * 26], size: [78, 23],
      onClick: () => {
        hermitCounts[st] = (hermitCounts[st] ?? 0) + 1;
        b.text = `内功 ${name} +${hermitCounts[st]}`;
        scene.conn.sendHermit(st);
      },
    });
    hermitPanel.addControl(b);
  });
  const hermitPoints = mkLabel(hermitPanel, '剩余点数: -', 18, 195);
  store.on((kind) => { if (kind === 'stats') hermitPoints.text = `剩余点数: ${store.hermitPoints}`; });

  // ---- 页签切换 ----
  function selectTab(i) {
    tab = i;
    if (bg) bg.index = [110, 112, 111][i];
    equipPanel.visible = i === 0;
    discPanel.visible = i === 1;
    hermitPanel.visible = i === 2;
    statsPanel.visible = i === 0;
    weightLabel.visible = i === 0;
    refresh();
  }

  function mkLabel(parent, text, x, y) {
    const l = new DXLabel({ text, fontSize: 9, textColour: [255, 255, 255, 255], drawOutline: true,
      location: [x, y], size: [300, 18], isControl: false });
    parent.addControl(l);
    return l;
  }
  // ---- 刷新 (_Process 轮询语义 → 事件驱动) ----
  function refresh() {
    nameLabel.text = `${scene.info.name ?? ''} Lv.${store.level} ${CLASS_NAMES[scene.info.class] ?? ''}`;
    guildLabel.text = scene.info.guildName ?? '';
    weightLabel.text = `负重 ${store.wearWeight} / ${store.handWeight}`;
    // 属性
    for (const b of bindings) {
      const v = store.stats[b.stat] ?? 0;
      if (b.fmt === 'range') {
        const min = b.minStat != null ? (store.stats[b.minStat] ?? 0) : 0;
        b.v.text = `${min}-${v}`;
      } else if (b.fmt === 'weight') {
        b.v.text = `${v}`;
      } else if (b.fmt === 'elem+') {
        b.v.text = v > 0 ? `+${v}` : '0';
      } else if (b.fmt === 'resist') {
        b.v.text = String(v);
      } else b.v.text = String(v);
    }
    for (const c of equipCells) c.refreshItem();
    // 心法 (Discipline: startInfo.discipline)
    const d = scene.info.discipline;
    if (d) {
      discLevel.text = `等级: ${d.level}`;
      discExp.text = `经验: ${d.experience}`;
    }
    hermitPoints.text = `剩余点数: ${store.hermitPoints}`;
  }
  store.on((kind) => {
    if (['stats', 'weight', 'level', 'items'].includes(kind)) refresh();
  });
  refresh();

  reg.wins.set('char', w);
  return {
    win: w,
    open: () => { selectTab(0); WindowManager.open(w, scene.hudLayer); },
    close: () => WindowManager.close(w),
    toggle: () => { if (w.visible) WindowManager.close(w); else { selectTab(0); WindowManager.open(w, scene.hudLayer); } },
    refresh,
  };
}
