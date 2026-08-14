// win-quest.js — 任务 QuestDialog.cs 移植 (D路 par-win)
// 3 页签: 当前(0)/可接(1)/里程碑(3) (:65-68); 左列表+右详情 (RefreshDetail :381-424);
// 点击完成态任务=提交, 未完成=追踪切换 (C.QuestTrack), 右键=放弃确认;
// 里程碑页: C.MilestoneNotify(true/false) 订阅开关 + 领取 (C.MilestoneClaim) + 启停 (C.MilestoneActive)。
// 数据: ItemStore.quests (S.QuestChanged/Cancelled) + gamedb QuestInfo/Reward/Task。

import { getWindow } from './uitree.js';
import { WindowManager, setHint } from './windows.js';
import { DXControl, DXLabel, DXButton, DXCheckBox } from './dx.js';
import { D } from './data.js';
import { GameDB } from './gamedb.js';
import { C } from './net.js';

const TYPE_ORDER = { Story: 0, Account: 1, General: 2, Daily: 3, Weekly: 4, Repeatable: 5 };

function isQuestComplete(uq, questInfo) {
  // ClientUserQuest.IsComplete = Tasks 全部完成 (Globals.cs:1024-1025)
  if (!uq) return false;
  if (uq.completed) return true;
  const total = questInfo?._taskCount ?? null;
  void total;
  return (uq.tasks ?? []).every(t => t?.completed);
}
function taskDone(uqTask) { return uqTask?.completed; }

function subst(text, ctx) {   // GetQuestText 占位符 (GameScene.cs:188-199)
  return (text ?? '')
    .replaceAll('[PLAYERNAME]', ctx.player ?? '')
    .replaceAll('[STARTNAME]', ctx.start ?? '')
    .replaceAll('[FINISHNAME]', ctx.finish ?? '');
}

export async function winQuest(scene, store, reg) {
  const w = await getWindow('QuestDialog');
  if (!w) return null;
  const conn = scene.conn;

  let page = 0;
  let selected = null;         // {info, uq} 选中任务
  const bg = w.byPath.get('QuestDialog/0');

  // 页签 (65-68: 90x25 y=25)
  const tabDefs = [[0, '当前任务'], [1, '可接任务'], [3, '里程碑']];
  const tabs = tabDefs.map(([p, text], i) => {
    const b = new DXButton({ text, fontSize: 9, library: 'Interface', index: -1,
      location: [18 + i * 100, 25], size: [90, 25],
      textColour: page === p ? [255, 216, 77, 255] : [255, 255, 255, 255],
      onClick: () => selectPage(p) });
    w.addControl(b);
    return b;
  });
  // 角标 (GameInter 240 可接)
  const alertIcons = [null, newAlert(78), null];
  function newAlert(x) {
    void x;
    return null;   // 角标视觉由页签文本变化代替 (可接数量)
  }

  // 左列表 (18,58) 680x415 + 详情右栏 (380,5) 300x405
  const leftList = new DXControl({ location: [18, 58], size: [350, 415], clip: true, isControl: false });
  w.addControl(leftList);
  const leftInner = new DXControl({ location: [0, 0], size: [350, 415], isControl: false });
  leftList.addControl(leftInner);
  const detail = new DXControl({ location: [380, 5], size: [300, 405], isControl: false });
  detail.el.style.border = '1px solid rgba(120,96,48,.5)';
  w.addControl(detail);

  let leftScroll = 0;
  leftList.el.addEventListener('wheel', (ev) => {
    leftScroll = Math.max(0, leftScroll - Math.sign(ev.deltaY) * 30);
    renderList();
    ev.preventDefault();
  }, { passive: false });

  function selectPage(p) {
    if (page === 3 && p !== 3) conn.sendMilestoneNotify(false);   // 离开里程碑页取消订阅
    page = p;
    if (bg) bg.index = p === 3 ? 292 : 291;
    selected = null;
    tabs.forEach((b, i) => b.textColour = tabDefs[i][0] === p ? [255, 216, 77, 255] : [255, 255, 255, 255]);
    tabs.forEach((b, i) => b.applyText ? b.applyText() : null);
    if (p === 3) conn.sendMilestoneNotify(true);
    render();
  }

  // CanAcceptQuest (GameScene.cs:149-183): 6 类 Requirement 全量判定
  const CLASS_BIT = { None: 0, Warrior: 1, Wizard: 2, Taoist: 4, Assassin: 8, WarWizTao: 7, WizTao: 6, AssWar: 9, All: 15 };   // RequiredClass Enum.cs:65
  let reqRowCache = null;
  async function canAcceptQuest(info) {
    if (!info?.StartNPC || !info?.FinishNPC) return false;   // :151
    if ([...store.quests.values()].some(q => q.questIndex === info.Index)) return false;   // :152
    if (!info.Requirements?.length) return true;
    if (reqRowCache == null) {
      try { reqRowCache = await GameDB.questRequirements(); } catch { reqRowCache = []; }
    }
    const byIdx = new Map(reqRowCache.map(r => [r.Index, r]));
    for (const ref of info.Requirements) {
      const req = byIdx.get(ref?.Index);
      if (!req) continue;
      switch (req.Requirement) {
        case 'MinLevel': if (store.level < (req.IntParameter1 ?? 0)) return false; break;   // :157
        case 'MaxLevel': if (store.level > (req.IntParameter1 ?? 0)) return false; break;   // :158
        case 'NotAccepted':   // :160-162
          if (req.QuestParameter != null && [...store.quests.values()].some(q => q.questIndex === req.QuestParameter.Index)) return false;
          break;
        case 'HaveCompleted': {   // :163-166
          const uq = req.QuestParameter != null ? [...store.quests.values()].find(q => q.questIndex === req.QuestParameter.Index) : null;
          if (req.QuestParameter == null || !uq?.completed) return false;
          break;
        }
        case 'HaveNotCompleted': {   // :167-169
          const uq2 = req.QuestParameter != null ? [...store.quests.values()].find(q => q.questIndex === req.QuestParameter.Index) : null;
          if (req.QuestParameter != null && uq2?.completed) return false;
          break;
        }
        case 'Class': {   // :170-179: (requirement.Class & required) != required
          const reqBit = CLASS_BIT[req.Class] ?? 0;
          const mine = CLASS_BIT[store.info?.class] ?? 0;
          if (reqBit !== 0 && (reqBit & mine) !== mine) return false;
          break;
        }
      }
    }
    return true;
  }

  async function questRows() {
    const D_ = D();
    if (page === 1) {
      // 可接: 全部 QuestInfo 过 CanAcceptQuest (GameScene.cs:149)
      const all = await GameDB.allQuests();
      const out = [];
      for (const info of all) {
        if (!await canAcceptQuest(info)) continue;
        out.push({ info, uq: null });
      }
      return out.sort((a, b) =>
        (TYPE_ORDER[a.info.QuestType] ?? 99) - (TYPE_ORDER[b.info.QuestType] ?? 99)
        || (a.info.QuestName ?? '').localeCompare(b.info.QuestName ?? ''));
    }
    // 当前/完成
    const rows = [];
    for (const uq of store.quests.values()) {
      const info = await GameDB.questInfo(uq.questIndex);
      if (!info) continue;
      const complete = isQuestComplete(uq, info);
      if (page === 0 && uq.completed) continue;      // 完成态在 "当前" 隐藏? Godot: page2 才是 done —
      rows.push({ info, uq, complete });
    }
    return rows.sort((a, b) =>
      (TYPE_ORDER[a.info.QuestType] ?? 99) - (TYPE_ORDER[b.info.QuestType] ?? 99));
  }

  function mkLine(text, opts = {}) {
    const l = new DXLabel({ text, fontSize: opts.size ?? 9,
      textColour: opts.colour ?? [255, 255, 255, 255],
      drawOutline: true, location: [opts.x ?? 0, opts.y ?? 0],
      size: [opts.w ?? 340, 20], isControl: false });
    if (opts.onClick) { l.el.style.cursor = 'pointer'; l.el.addEventListener('click', opts.onClick); }
    return l;
  }

  async function render() { renderList(); renderDetail(); }
  let lastRows = [];
  async function renderList() {
    leftInner.el.replaceChildren();
    lastRows = await questRows();
    let y = 0 - leftScroll;
    if (page === 3) {
      // 里程碑页 (199-235)
      const ms = store.milestones ?? [];
      if (!ms.length) {
        leftInner.addControl(mkLine('(暂无里程碑数据)', { colour: [160, 160, 160, 255] }));
      }
      for (const m of ms.filter(Boolean)) {
        const info = await GameDB.questInfo(m.infoIndex);
        const title = `${info?.QuestName ?? `里程碑#${m.infoIndex}`} [${m.completed ? '完成' : '进行中'}]`;
        const row = mkLine(title, {
          y, colour: [255, 216, 77, 255],
          onClick: () => conn.sendMilestoneActive(m.index, !m.active),
        });
        setHint(row, '点击切换启停');
        leftInner.addControl(row);
        y += 20;
        if (info?.Description) {
          leftInner.addControl(mkLine(`  ${info.Description}`, { y, size: 8, colour: [200, 200, 200, 255] }));
          y += 16;
        }
        if (m.completed && !m.claimed) {
          const claim = mkLine('  [点击领取]', { y, colour: [95, 217, 122, 255],
            onClick: () => conn.sendMilestoneClaim(m.index) });
          leftInner.addControl(claim);
          y += 20;
        } else y += 4;
      }
      return;
    }
    if (!lastRows.length) {
      leftInner.addControl(mkLine(page === 1 ? '(没有可接的任务)' : '(没有进行中的任务)',
        { colour: [160, 160, 160, 255] }));
      return;
    }
    for (const r of lastRows) {
      const name = r.info.QuestName ?? `#${r.info.Index}`;
      const type = r.info.QuestType ?? '';
      let title, onClick, onRight;
      if (page === 1) {
        title = `[${type}] ${name}  [点击接取]`;
        onClick = () => conn.sendQuestAccept(r.info.Index);
      } else {
        const done = r.complete;
        title = `[${type}] ${name}` + (done ? ' (已完成, 点击提交)' : ' (左键追踪/右键放弃)');
        onClick = () => {
          if (done) { conn.sendQuestComplete(r.uq.index); return; }
          conn.sendQuestTrack(r.uq.index, !r.uq.track);
          r.uq.track = !r.uq.track;
          renderList();
        };
        onRight = (ev) => {
          ev.preventDefault();
          if (done) return;
          if (confirm(`确定放弃任务「${name}」吗?`)) conn.sendQuestAbandon(r.uq.index);
        };
      }
      const row = mkLine(title, { y, colour: page === 1 ? [255, 216, 77, 255] : [255, 255, 255, 255], onClick });
      if (onRight) row.el.addEventListener('contextmenu', onRight);
      leftInner.addControl(row);
      y += 20;
      // 任务进度行 (未完成 tasks)
      if (r.uq && !r.complete) {
        const tasks = await GameDB.questTasks(r.info.Index);
        for (let i = 0; i < (r.uq.tasks ?? []).length; i++) {
          const t = r.uq.tasks[i];
          if (!t || taskDone(t)) continue;
          const ti = tasks[i];
          const label = ti ? `${ti.Task} ${t.amount ?? 0}` : `进度 ${t.amount ?? 0}`;
          leftInner.addControl(mkLine(`    ${label}`, { y, size: 8, colour: [190, 190, 190, 255], w: 330 }));
          y += 16;
        }
      }
      y += 6;
    }
  }

  async function renderDetail() {
    detail.el.replaceChildren();
    if (page === 3) {
      detail.addControl(mkLine('里程碑页', { x: 8, y: 8, colour: [255, 216, 77, 255] }));
      return;
    }
    if (!selected) {
      detail.addControl(mkLine('在左侧选择一个任务查看详情', { x: 8, y: 8, colour: [160, 160, 160, 255], w: 280 }));
      return;
    }
    const { info, uq } = selected;
    const ctx = { player: scene.info?.name ?? '' };
    let y = 4;
    detail.addControl(mkLine(info.QuestName ?? '', { x: 8, y, colour: [255, 216, 77, 255], w: 285 }));
    y += 22;
    detail.addControl(mkLine('任务详情', { x: 8, y, colour: [200, 160, 90, 255] }));
    y += 16;
    const desc = subst(uq ? info.ProgressText : info.AcceptText, ctx);
    const dl = new DXLabel({ text: desc, fontSize: 8, location: [10, y], size: [285, 62], isControl: false });
    dl.el.style.whiteSpace = 'pre-wrap';
    detail.addControl(dl);
    y += 66;
    detail.addControl(mkLine('任务目标', { x: 8, y, colour: [200, 160, 90, 255] }));
    y += 16;
    const tasks = await GameDB.questTasks(info.Index);
    for (const t of tasks) {
      const label = t.Task === 'KillMonster'
        ? `消灭怪物 x${t.Amount}`
        : t.Task === 'GainItem'
          ? `收集 ${GameDB.itemZhSync(t.ItemParameter?.Index, D().itemsById)} x${t.Amount}`
          : `${t.Task} x${t.Amount ?? 1}`;
      detail.addControl(mkLine(`  ${label}`, { x: 10, y, size: 8, w: 285 }));
      y += 16;
    }
    y += 6;
    // 奖励 (QuestTabRewardsLabel)
    detail.addControl(mkLine('奖励', { x: 8, y, colour: [200, 160, 90, 255] }));
    y += 16;
    const rewards = await GameDB.questRewards(info.Index);
    let any = false;
    for (const rw of rewards.slice(0, 5)) {
      const zh = GameDB.itemZhSync(rw.Item?.Index, D().itemsById) || rw.Item?.Name || '';
      detail.addControl(mkLine(`  ${zh} x${rw.Amount}${rw.Choice ? ' (可选)' : ''}`,
        { x: 10, y, size: 8, colour: rw.Choice ? [255, 216, 77, 255] : [255, 255, 255, 255], w: 285 }));
      y += 15;
      any = true;
    }
    if (!any) { detail.addControl(mkLine('  无固定物品奖励', { x: 10, y, size: 8, colour: [160, 160, 160, 255] })); y += 15; }
    // 动作按钮 (411-421)
    y = 367;
    const actText = page === 1 ? '接取任务' : (selected.complete ? '提交任务' : '放弃任务');
    const act = new DXButton({ text: actText, fontSize: 9, library: 'Interface', index: -1,
      location: [194, y], size: [88, 27],
      onClick: () => {
        if (page === 1) conn.sendQuestAccept(info.Index);
        else if (selected.complete) conn.sendQuestComplete(uq.index);
        else if (confirm(`确定放弃任务「${info.QuestName}」吗?`)) conn.sendQuestAbandon(uq.index);
      } });
    detail.addControl(act);
  }

  // 列表行点击选中 → 详情
  leftInner.el.addEventListener('click', () => {
    // 选择由行 onClick 直接处理 (Godot: 左键=选中+动作)
  });

  store.on((kind) => {
    if (kind === 'quests' || kind === 'milestones') render();
  });
  selectPage(0);

  reg.wins.set('quest', w);
  return {
    win: w,
    open: () => { render(); WindowManager.open(w, scene.hudLayer); },
    close: () => { if (page === 3) conn.sendMilestoneNotify(false); WindowManager.close(w); },
    toggle: () => { if (w.visible) { if (page === 3) conn.sendMilestoneNotify(false); WindowManager.close(w); } else { render(); WindowManager.open(w, scene.hudLayer); } },
    selectPage, render,
  };
}
