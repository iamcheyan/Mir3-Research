// win-skill.js — 技能 MagicDialog.cs 移植 (D路 par-win)
// 系别页签 (SchoolTabIndex :272-289); 列表行距 59 高 54 (:350-354); 经验条 GameInter2 812;
// 键位绑定: 点图标=清除当前组键, 按 F1-F12+Shift 绑键 → C.MagicKey (SetKeyUpdate :447-455);
// 等级/经验: S.NewMagic/MagicLeveled; 职业头图 160-163 (HeaderIndex :262-270)。

import { getWindow } from './uitree.js';
import { WindowManager } from './windows.js';
import { DXControl, DXLabel, DXButton } from './dx.js';
import { skin } from './skin.js';
import { D } from './data.js';

// SchoolTabIndex (MagicDialog.cs:272-289)
const SCHOOL_TAB = {
  Active: 166, Passive: 168, Toggle: 170, Horse: 172,
  Fire: 174, Ice: 176, Lightning: 178, Wind: 180,
  Phantom: 182, Holy: 184, Dark: 186, Physical: 188,
  Atrocity: 190, Kill: 192, Assassination: 194,
};
const SCHOOL_ORDER = ['Active', 'Passive', 'Toggle', 'Fire', 'Ice', 'Lightning', 'Wind',
  'Phantom', 'Holy', 'Dark', 'Physical', 'Horse', 'Atrocity', 'Kill', 'Assassination'];
const SCHOOL_ZH = {
  Active: '主动', Passive: '被动', Toggle: '开关', Fire: '火', Ice: '冰', Lightning: '雷',
  Wind: '风', Phantom: '幻', Holy: '圣', Dark: '暗', Physical: '物理', Horse: '骑术',
  Atrocity: '暴虐', Kill: '击杀', Assassination: '刺杀',
};
const CLASS_KEYS = ['Warrior', 'Wizard', 'Taoist', 'Assassin'];

export async function winSkill(scene, store, reg) {
  const w = await getWindow('MagicDialog');
  if (!w) return null;

  // 职业头图 (HeaderIndex :262-270)
  const headerIdx = [160, 161, 162, 163][scene.info.class] ?? 160;
  const header = w.byPath.get('MagicDialog/0');
  if (header) header.index = headerIdx;

  // 页签区 (y=40)
  const tabStrip = new DXControl({ location: [0, 40], size: [419, 26], clip: true, isControl: false });
  w.addControl(tabStrip);
  tabStrip.el.style.zIndex = '2';

  // 列表 (15,70) 375x418 + 滚轮
  const listArea = new DXControl({ location: [15, 70], size: [375, 418], clip: true, isControl: false });
  w.addControl(listArea);
  const listInner = new DXControl({ location: [0, 0], size: [375, 418], isControl: false });
  listArea.addControl(listInner);

  let selectedSchool = null;
  let rows = [];
  let scroll = 0;
  let tabIndex = 0;   // 页签分页 (>5 个系别滚动)

  function magicSetKeys(m) {
    return [m.set1Key, m.set2Key, m.set3Key, m.set4Key];
  }
  function currentSetKey(m) {   // GameScene.MagicBarSpellSet (1-4) — 默认组1
    return m.set1Key ?? 0;
  }
  function spellKeyText(k) {    // SpellKeyText :526-537
    if (!k) return '';
    return k <= 12 ? `F${k}` : `Shift+F${k - 12}`;
  }

  function visibleMagics() {
    const D_ = D();
    const cls = CLASS_KEYS[scene.info.class] ?? 'Warrior';
    const magics = D_.magics ?? [];
    const infos = magics.filter(m => m.school && m.school !== 'None' && m.school !== 'Discipline');
    const learned = store.magics;
    const out = [];
    for (const info of infos) {
      const um = learned.get(info.id);
      // 未学技能只列本职业 (GetVisibleMagicInfos :324-348)
      if (!um && info.cls && info.cls !== 'All' && info.cls !== cls) continue;
      if (um || info.cls === 'All' || info.cls === cls) out.push({ info, um });
    }
    return out;
  }

  function refresh() {
    const all = visibleMagics();
    const schools = SCHOOL_ORDER.filter(s => all.some(m => m.info.school === s));
    if (!schools.includes(selectedSchool)) selectedSchool = schools[0] ?? null;

    // 页签按钮
    tabStrip.el.replaceChildren();
    const visible = schools.slice(tabIndex * 5, tabIndex * 5 + 5);
    visible.forEach((s, i) => {
      const b = new DXButton({
        text: SCHOOL_ZH[s] ?? s, fontSize: 8, library: 'Interface', index: -1,
        location: [56 + i * 62, 0], size: [60, 25],
        textColour: s === selectedSchool ? [255, 216, 77, 255] : [255, 255, 255, 255],
        onClick: () => { selectedSchool = s; scroll = 0; refresh(); },
      });
      tabStrip.addControl(b);
    });
    if (schools.length > 5) {
      const prev = new DXButton({ text: '<', fontSize: 9, library: 'Interface', index: -1,
        location: [0, 0], size: [24, 25], onClick: () => { tabIndex = Math.max(0, tabIndex - 1); refresh(); } });
      const next = new DXButton({ text: '>', fontSize: 9, library: 'Interface', index: -1,
        location: [30, 0], size: [24, 25], onClick: () => { tabIndex++; refresh(); } });
      tabStrip.addControl(prev, next);
    }

    // 行
    listInner.el.replaceChildren();
    rows = [];
    const list = all
      .filter(m => m.info.school === selectedSchool)
      .sort((a, b) => (a.info.needLevel1 ?? 0) - (b.info.needLevel1 ?? 0) || (a.info.name ?? '').localeCompare(b.info.name ?? ''));
    const y0 = 7 - scroll;
    list.forEach((m, i) => {
      const row = buildRow(m, 5, y0 + i * 59);
      listInner.addControl(row.ctl);
      rows.push(row);
    });
  }

  function buildRow({ info, um }, x, y) {
    const ctl = new DXControl({ location: [x, y], size: [369, 54], isControl: true });
    ctl.el.style.background = 'rgba(0,0,0,.25)';
    const learned = !!um;
    const canLearn = !learned && (scene.world?.player ? store.level >= (info.needLevel1 ?? 1) : true);
    if (!learned && !canLearn) ctl.el.style.opacity = '0.4';

    // 图标 (MIcon[icon]) 36x36 @(9,9) — 可点
    const icon = new DXControl({ location: [9, 9], size: [36, 36], isControl: true });
    icon.el.style.cssText += 'background-size:contain;background-repeat:no-repeat;image-rendering:pixelated;cursor:pointer;';
    skin.frame('MIcon', info.icon ?? 0).then(f => { if (f) icon.el.style.backgroundImage = `url(${f.url})`; });
    ctl.addControl(icon);

    // 名称 + 等级/状态
    const nameL = new DXLabel({ text: info.zh && info.zh !== info.name ? info.zh : (info.name ?? ''),
      fontSize: 9, textColour: [255, 255, 255, 255], drawOutline: true,
      location: [54, 6], size: [200, 16], isControl: false });
    ctl.addControl(nameL);
    const statL = new DXLabel({
      text: learned ? `等级: ${um.level}` : '未学习',
      fontSize: 8, textColour: learned ? [204, 204, 204, 255] : [255, 89, 89, 255],
      location: [54, 24], size: [110, 16], isControl: false });
    ctl.addControl(statL);

    // 经验条 (GameInter2 812) + 经验文本
    if (learned) {
      const req = um.level === 0 ? (info.experience1 ?? 100) : um.level === 1 ? (info.experience2 ?? 200)
        : um.level === 2 ? (info.experience3 ?? 300) : (um.level - 2) * 500;
      const maxed = um.level >= 3;
      const pct = maxed ? 1 : Math.min(1, Number(um.experience ?? 0) / Math.max(1, req));
      const bar = new DXControl({ location: [110, 38], size: [200, 10], clip: true, isControl: false });
      bar.el.style.background = 'rgba(0,0,0,.5)';
      const fill = document.createElement('div');
      fill.style.cssText = `position:absolute;left:0;top:0;bottom:0;width:${Math.round(pct * 100)}%;background:#7a9a3a;`;
      bar.el.appendChild(fill);
      ctl.addControl(bar);
      const expL = new DXLabel({
        text: maxed ? '经验: 已满级' : `经验: ${um.experience ?? 0}/${req}`,
        fontSize: 8, textColour: [255, 216, 77, 255],
        location: [200, 24], size: [169, 16], align: 'right', isControl: false });
      ctl.addControl(expL);
    } else {
      const needL = new DXLabel({ text: `所需等级: ${info.needLevel1 ?? 1}`,
        fontSize: 8, textColour: canLearn ? [102, 255, 102, 255] : [255, 89, 89, 255],
        location: [110, 38], size: [200, 16], isControl: false });
      ctl.addControl(needL);
    }

    // 当前组键位显示 (330,18) 金色
    const keyL = new DXLabel({ text: learned ? spellKeyText(currentSetKey(um)) : '',
      fontSize: 9, textColour: [255, 216, 77, 255], drawOutline: true, align: 'right',
      location: [310, 4], size: [55, 16], isControl: false });
    ctl.addControl(keyL);

    // 点击图标 = 清除当前组键 (ClearCurrentSetKey :393-411)
    icon.el.addEventListener('click', () => {
      if (!learned) return;
      const m = store.magics.get(info.id);
      if (!m) return;
      m.set1Key = 0;
      conn_sendKey(m);
      refresh();
    });
    // F1-F12+Shift 悬停绑定 (BindCurrentSetKey :413-437)
    icon.el.addEventListener('keydown', (ev) => {
      const m = /^F(\d{1,2})$/.exec(ev.code);
      if (!m || !learned) return;
      const k = parseInt(m[1], 10) + (ev.shiftKey ? 12 : 0);
      // 去重: 同组其它技能同键清掉
      for (const [, other] of store.magics) {
        if (other !== m && other.set1Key === k) other.set1Key = 0;
      }
      const um2 = store.magics.get(info.id);
      um2.set1Key = k;
      conn_sendKey(um2);
      refresh();
      ev.preventDefault();
    });
    icon.el.tabIndex = 0;
    return { ctl };
  }

  function conn_sendKey(um) {
    scene.conn.sendMagicKey(um.infoIndex, um.set1Key ?? 0, um.set2Key ?? 0, um.set3Key ?? 0, um.set4Key ?? 0);
  }

  // 滚轮 (listArea MouseWheel → scroll)
  listArea.el.addEventListener('wheel', (ev) => {
    const maxRows = Math.max(0, rows.length * 59 + 9 - 418);
    scroll = Math.max(0, Math.min(maxRows, scroll - Math.sign(ev.deltaY) * 54));
    refresh();
    ev.preventDefault();
  }, { passive: false });

  store.on((kind) => { if (kind === 'magics' || kind === 'level') refresh(); });
  refresh();

  reg.wins.set('skill', w);
  return {
    win: w,
    open: () => { refresh(); WindowManager.open(w, scene.hudLayer); },
    close: () => WindowManager.close(w),
    toggle: () => { if (w.visible) WindowManager.close(w); else { refresh(); WindowManager.open(w, scene.hudLayer); } },
    refresh,
  };
}
