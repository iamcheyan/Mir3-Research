// win-npc.js — NPC 对话 NPCDialog.cs + 商店 NPCGoodsPanel.cs + 修理 NPCRepairPanel.cs
//               + NPC 任务列表/详情 NPCQuestDialogs.cs 移植 (D路 par-win)
// S.NPCResponse{objectID,index,values} → 本地 NPCPage (GameDB, 与服务端同源 System.db 快照)
//   → ShowPage 状态机 (:50-139):
//   <id:default> 值替换 (:56-62); [文本:id] 内联文字按钮 (id0=关闭);
//   动态高度 rowCount=clamp((h-124)/20,0,6) (77-87) + GameInter[381] 行背景;
//   BuySell→商品面板 (0,Size.Y) (:93-94); Repair→修理面板 (:109-111);
//   DialogType=None→任务列表 (:118-119)。
// 关闭 = 隐藏必发 C.NPCClose (:184-188), 经 onHide 钩子 (registry 装饰)。
// 商品 = NPCGood 表 (Page 外键, Rate=价格); 任务发现 = NPCInfo.StartQuests/FinishQuests
//   (OpenFor :41-73 三桶: 完成/可接/进行中); 接取/交还 = C.QuestAccept/QuestComplete。

import { getWindow } from './uitree.js';
import { WindowManager } from './windows.js';
import { DXControl, DXLabel, DXButton, DXImageControl } from './dx.js';
import { skin } from './skin.js';
import { D } from './data.js';
import { GRID } from './net.js';
import { GameDB } from './gamedb.js';
import { DXItemGrid, itemAmountDialog } from './dxgrid.js';
import { winConsign } from './win-consign.js';

// NPCDialogType (Enum.cs:564+)
const DIALOG_TYPE = ['None', 'BuySell', 'Repair', 'Refine', 'RefineRetrieve', 'CompanionManage',
  'WeddingRing', 'RefinementStone', 'MasterRefine', 'WeaponReset', 'ItemFragment',
  'AccessoryRefineUpgrade', 'AccessoryRefineLevel', 'AccessoryReset', 'WeaponCraft',
  'AccessoryRefine', 'RollDie', 'RollYut', 'Consignment', 'Socketing', 'SocketCombine'];

export const npcDialogs = { currentNpcObjectID: 0 };

export async function winNpc(scene, store, reg) {
  const w = await getWindow('NPCDialog');
  if (!w) return null;
  const conn = scene.conn;
  const D_ = D();

  // ---- 树节点: /3 文本区 /4 滚动 /5 商品宿主 ----
  const textArea = w.byPath.get('NPCDialog/3');
  const treeScroll = w.byPath.get('NPCDialog/4');
  const goodsHost = w.byPath.get('NPCDialog/5');
  textArea.clip = true;
  textArea.applyBase();
  const textInner = document.createElement('div');
  textInner.style.cssText =
    "position:absolute;left:0;top:0;width:340px;font:12px/1.5 'Noto Sans CJK SC','Noto Sans CJK',sans-serif;" +
    'color:#eee;text-shadow:1px 1px 0 #000;white-space:pre-wrap;';
  textArea.el.appendChild(textInner);

  // 行背景 (GameInter 381) — 动态增删 (:81-87)
  const rowBgs = [];

  // ---- 修理面板 (动态挂窗, NPCDialog 树无此节点) ----
  const repairPanel = new DXControl({ location: [0, 204], size: [404, 300], visible: false, isControl: true });
  repairPanel.el.style.zIndex = '1';
  w.addControl(repairPanel);
  let repairLinks = new Map();      // hostSlot → {gridType, slot, count}
  let repairSpecial = false;
  let repairTypes = [];

  // ---------- NPCTextControl 内联引擎 ([文本:id] 按钮 + {文本:颜色} 染色) ----------
  const COLOURS = { red: '#ff5555', green: '#55ff55', blue: '#6a8fd8', yellow: '#ffd94d',
    orange: '#ff8c1a', white: '#ffffff' };
  function renderNpcText(raw) {
    textInner.innerHTML = '';
    const frag = document.createDocumentFragment();
    const re = /\[(?<bt>[^\[\]:]+):(?<bid>[^\[\]]+?)\]|\{(?<ct>[^\{\}:]+):(?<cc>[^\{\}]+?)\}/g;
    let last = 0, m;
    const addText = (t, cls) => {
      if (!t) return;
      const span = document.createElement('span');
      span.textContent = t;
      if (cls) span.style.color = cls;
      frag.appendChild(span);
    };
    while ((m = re.exec(raw)) !== null) {
      addText(raw.slice(last, m.index));
      if (m.groups.bt != null) {
        const b = document.createElement('span');
        b.textContent = m.groups.bt;
        b.style.cssText = 'color:#ffd94d;cursor:pointer;text-decoration:underline;';
        const id = parseInt(m.groups.bid, 10);
        b.addEventListener('mouseenter', () => b.style.color = '#ff5555');
        b.addEventListener('mouseleave', () => b.style.color = '#ffd94d');
        b.addEventListener('click', () => {
          if (id === 0) WindowManager.close(w);          // id0 = 关闭 (NPCTextControl)
          else conn.sendNPCButton(id);                   // C.NPCButton
        });
        frag.appendChild(b);
      } else {
        addText(m.groups.ct, COLOURS[m.groups.cc?.toLowerCase()] ?? m.groups.cc);
      }
      last = m.index + m[0].length;
    }
    addText(raw.slice(last));
    textInner.appendChild(frag);
    return textInner.scrollHeight;
  }

  // ---------- 商品面板 (NPCGoodsPanel.cs) ----------
  function buildGoods(page) {
    goodsHost.el.replaceChildren();
    goodsHost.size = [245, 42];
    goodsHost.visible = false;
    GameDB.npcGoods(page.Index).then((goods) => {
      if (!goods.length) return;
      goodsHost.addControl(new DXLabel({ text: '购买', fontSize: 9, textColour: [255, 216, 77, 255],
        drawOutline: true, location: [9, 8], size: [220, 18], isControl: false }));
      const listArea = new DXControl({ location: [9, 37], size: [227, 215], clip: true, isControl: false });
      goodsHost.addControl(listArea);
      goods.forEach((g, i) => {
        if (i >= 5) return;
        const itemIdx = g.Item?.Index ?? g.Item;
        const info = D_.itemsById?.[itemIdx];
        const cost = g.Rate ?? 0;
        const row = new DXControl({ location: [0, i * 43 + 1], size: [204, 40], isControl: true });
        row.el.style.cssText += 'border:1px solid rgba(120,96,48,.3);cursor:pointer;';
        const icon = document.createElement('div');
        icon.style.cssText = 'position:absolute;left:2px;top:2px;width:36px;height:36px;background-size:contain;background-repeat:no-repeat;background-position:center;image-rendering:pixelated;';
        if (info?.image > 0) skin.frame('Storeitem', info.image).then(f => { if (f) icon.style.backgroundImage = `url(${f.url})`; });
        row.el.appendChild(icon);
        const name = document.createElement('div');
        name.textContent = info ? (info.zh && info.zh !== info.name ? info.zh : info.name) : `#${itemIdx}`;
        name.style.cssText = 'position:absolute;left:41px;top:3px;font:12px "Noto Sans CJK SC",sans-serif;color:#eee;text-shadow:1px 1px 0 #000;';
        row.el.appendChild(name);
        const price = document.createElement('div');
        price.textContent = cost.toLocaleString();
        price.style.cssText = `position:absolute;left:60px;top:21px;font:12px "Noto Sans CJK SC",sans-serif;color:${cost <= Number(store.gold()) ? '#ffd94d' : '#ff5555'};text-shadow:1px 1px 0 #000;`;
        row.el.appendChild(price);
        row.el.addEventListener('click', () => buyGood(g, info, cost));
        listArea.addControl(row);
      });
      goodsHost.size = [245, Math.min(goods.length, 5) * 43 + 60];
      goodsHost.location = [0, w.size[1]];
      goodsHost.visible = true;
    });
  }
  function buyGood(g, info, cost) {   // BuySelected :300-356 (数量分支)
    const gold = Number(store.gold());
    const maxByGold = cost > 0 ? Math.floor(gold / cost) : 1;
    if (maxByGold <= 0) { scene.addChat('你没有足够的金币购买', 'hint'); return; }
    if (info && info.stack > 1) {
      itemAmountDialog(`购买 ${info.zh ?? info.name} (单价 ${cost.toLocaleString()})`,
        Math.min(maxByGold, info.stack), 1,
        (n) => conn.sendNPCBuy(g.Index ?? 0, BigInt(n), false));
    } else {
      conn.sendNPCBuy(g.Index ?? 0, 1n, false);
    }
  }

  // ---------- 修理面板 (NPCRepairPanel.cs) ----------
  const repairGrid = new DXItemGrid({
    cols: 11, rows: 5, gridType: GRID.REPAIR, store,
    location: [9, 37], size: [11 * 37 + 1, 5 * 37 + 1], linked: true,
  });
  const repairVirtual = new Map();
  repairGrid.virtualGrid = repairVirtual;
  repairGrid.onUnlink = (cell) => {   // 点击/拖出已放入格 = 取出 (:141-148)
    const link = repairLinks.get(cell.slot);
    if (!link) return;
    repairLinks.delete(cell.slot);
    repairVirtual.delete(cell.slot);
    store.unlockPublic(link.gridType, link.slot);
    repairGrid.refreshGrid();
    updateRepairCost();
  };
  repairGrid.onOffer = (srcCell, targetCell) => {   // 拖入 = 建立链接
    if (!canAcceptRepair(srcCell.item)) return;
    if (repairLinks.has(targetCell.slot)) return;
    const link = { gridType: srcCell.gridType, slot: srcCell.slot, count: srcCell.item.count };
    repairLinks.set(targetCell.slot, link);
    repairVirtual.set(targetCell.slot, srcCell.item);
    store.lock(link.gridType, link.slot);
    repairGrid.refreshGrid();
    updateRepairCost();
  };
  function canAcceptRepair(it) {   // CanAcceptSource :150-163
    if (!it) return false;
    if (it.flags & 2) return false;                       // Marriage 不可修
    if (it.maxDurability <= 0 || it.currentDurability >= it.maxDurability) return false;
    const info = D_.itemsById?.[it.infoIndex];
    if (repairTypes.length && !repairTypes.includes(info?.type)) return false;
    return true;
  }
  const repairCost = new DXLabel({ text: '修理费用: 0', fontSize: 9, drawOutline: true,
    location: [9, 224], size: [200, 18], isControl: false });
  const repairSubmit = new DXButton({ text: '修理', fontSize: 9, library: 'Interface', index: -1,
    location: [315, 222], size: [70, 26], onClick: submitRepair });
  const repairSpecialBtn = new DXButton({ text: '特殊修理: 关', fontSize: 8, library: 'Interface', index: -1,
    location: [200, 222], size: [105, 24], onClick: () => {
      repairSpecial = !repairSpecial;
      repairSpecialBtn.text = `特殊修理: ${repairSpecial ? '开' : '关'}`;
      updateRepairCost();
    } });
  const importRow = new DXControl({ location: [9, 252], size: [380, 40], isControl: false });
  const srcBtn = (text, g, x) => {
    const b = new DXButton({ text, fontSize: 8, library: 'Interface', index: -1,
      location: [x, 0], size: [80, 24], onClick: () => importRepairables(g) });
    importRow.addControl(b);
  };
  repairPanel.addControl(new DXLabel({ text: '修理物品 (拖入或从背包导入)', fontSize: 9,
    textColour: [255, 216, 77, 255], drawOutline: true, location: [9, 10], size: [380, 18], isControl: false }));
  repairPanel.addControl(repairGrid, repairCost, repairSpecialBtn, repairSubmit, importRow);
  srcBtn('背包', GRID.INVENTORY, 0);
  srcBtn('装备', GRID.EQUIPMENT, 84);
  srcBtn('仓库', GRID.STORAGE, 168);
  repairSubmit.enabled = false;

  function importRepairables(g) {   // ImportCells :174-192 — 清空重填可修物品
    for (const [, link] of repairLinks) store.unlockPublic(link.gridType, link.slot);
    repairLinks = new Map();
    repairVirtual.clear();
    let host = 0;
    for (const [slot, it] of [...store.items(g).entries()].sort((a, b) => a[0] - b[0])) {
      if (!canAcceptRepair(it)) continue;
      repairLinks.set(host, { gridType: g, slot, count: it.count });
      repairVirtual.set(host, it);
      store.lock(g, slot);
      host++;
      if (host >= 55) break;
    }
    repairGrid.refreshGrid();
    updateRepairCost();
  }
  function updateRepairCost() {
    let cost = 0;
    for (const it of repairVirtual.values()) {
      cost += Math.max(0, it.maxDurability - it.currentDurability) * 2;   // 展示值; 服务端权威
    }
    repairCost.text = `修理费用${repairSpecial ? '(特殊)' : ''}: ${cost.toLocaleString()}`;
    repairSubmit.enabled = repairLinks.size > 0;
  }
  function submitRepair() {   // Submit :183-214 — C.NPCRepair{Links,Special,GuildFunds}
    if (!repairLinks.size) return;
    conn.sendNPCRepair([...repairLinks.values()], repairSpecial, false);
    repairVirtual.clear();
    repairLinks = new Map();
    repairGrid.refreshGrid();
    updateRepairCost();
  }

  // ---------- 精炼取回面板 (NPCAdvancedPanels.cs:518-527 BuildRetrieve) ----------
  // S.RefineList → 列表渲染; 刷新=C.NPCCall(重复对话, 服务端推 RefineList);
  // 取回=C.NPCRefineRetrieve{Index} (ClientPackets.cs:328)。
  const retrievePanel = new DXControl({ location: [0, 204], size: [404, 300], visible: false, isControl: true });
  const retrieveBox = document.createElement('div');
  retrieveBox.style.cssText = 'position:absolute;left:9px;top:37px;width:491px;height:302px;overflow-y:auto;';
  retrievePanel.el.appendChild(retrieveBox);
  const retrieveLabel = new DXLabel({ text: '', fontSize: 9, textColour: [255, 216, 77, 255],
    drawOutline: true, location: [9, 10], size: [380, 18], isControl: false });
  const refreshBtn = new DXButton({ text: '刷新', fontSize: 9, library: 'Interface', index: -1,
    location: [110, 155], size: [80, 24], onClick: () => renderRetrieve() });
  const retrieveBtn = new DXButton({ text: '取回选中', fontSize: 9, library: 'Interface', index: -1,
    location: [214, 155], size: [90, 24], onClick: () => {
      if (retrieveSelected != null) conn.sendNPCRefineRetrieve(retrieveSelected);
    } });
  let refineList = [];       // ClientRefineInfo[] (S.RefineList)
  let retrieveSelected = null;
  const renderRetrieve = async () => {
    retrieveBox.replaceChildren();
    retrieveSelected = null;
    refineList.forEach((rf) => {
      const nm = rf.weapon ? (D().itemsById?.[rf.weapon.infoIndex]?.zh ?? D().itemsById?.[rf.weapon.infoIndex]?.name ?? `物品#${rf.weapon.infoIndex}`) : '?';
      const readyTxt = rf.readyTime ? '' : ' (精炼中)';
      const d = document.createElement('div');
      d.textContent = `${nm}  品质${rf.quality} 成功率 ${rf.chance}/${rf.maxChance}${readyTxt}`;
      d.style.cssText = 'padding:3px 6px;font:12px/1.7 \'Noto Sans CJK SC\',sans-serif;color:#eee;text-shadow:1px 1px 0 #000;cursor:pointer;';
      d.onclick = () => {
        retrieveSelected = rf.index;
        for (const c of retrieveBox.children) c.style.background = '';
        d.style.background = 'rgba(120,180,255,.25)';
      };
      retrieveBox.appendChild(d);
    });
    if (!refineList.length) retrieveBox.textContent = '（无精炼记录 — 点刷新）';
    retrieveLabel.text = `精炼物品取回 (${refineList.length})`;
  };
  conn.addEventListener('refineList', (e) => {
    refineList = e.detail?.list ?? [];
    if (retrievePanel.visible) renderRetrieve();
  });
  retrievePanel.addControl(retrieveLabel, refreshBtn, retrieveBtn);
  w.addControl(retrievePanel);   // 挂载 (与 repairPanel 同位)

  // ---------- 任务列表/详情 (NPCQuestDialogs.cs) ----------
  const questListWin = await getWindow('NPCQuestListDialog');
  const questDetailWin = await getWindow('NPCQuestDialog');
  const qlList = questListWin?.byPath.get('NPCQuestListDialog/3');
  const qdTitle = questDetailWin?.byPath.get('NPCQuestDialog/2');
  const qdDesc = questDetailWin?.byPath.get('NPCQuestDialog/3');
  const qdTasks = questDetailWin?.byPath.get('NPCQuestDialog/4');
  const qdRewards = questDetailWin?.byPath.get('NPCQuestDialog/5');
  const questActionBtns = [];

  function closeQuestDialogs() {
    if (questListWin?.visible) WindowManager.close(questListWin);
    if (questDetailWin?.visible) WindowManager.close(questDetailWin);
  }
  if (questListWin?.closeButton) questListWin.closeButton.onClick = closeQuestDialogs;
  if (questDetailWin?.closeButton) questDetailWin.closeButton.onClick = closeQuestDialogs;

  async function openQuestList(objectID) {   // OpenFor :41-73
    if (!questListWin || !qlList) return;
    const npcObj = scene.world?.objects?.get(objectID);
    const npcIndex = npcObj?.info?.id;
    const npcRow = npcIndex != null ? await GameDB.npcInfo(npcIndex) : null;
    const refIdx = (v) => (typeof v === 'number' ? v : v?.Index ?? null);
    const starts = (npcRow?.StartQuests ?? []).map(refIdx).filter(v => v != null);
    const finishes = (npcRow?.FinishQuests ?? []).map(refIdx).filter(v => v != null);
    if (!starts.length && !finishes.length) return;

    const buckets = { complete: [], available: [], current: [] };
    for (const qi of new Set(finishes)) {   // FinishQuests: 完成/进行中
      const info = await GameDB.questInfo(qi);
      if (!info) continue;
      const uq = [...store.quests.values()].find(q => q.questIndex === qi);
      if (!uq) continue;
      const done = (uq.tasks ?? []).every(t => t?.completed);
      (done ? buckets.complete : buckets.current).push({ info, uq });
    }
    for (const qi of new Set(starts)) {     // StartQuests: 可接 (未接)
      const info = await GameDB.questInfo(qi);
      if (!info) continue;
      if ([...store.quests.values()].some(q => q.questIndex === qi)) continue;
      buckets.available.push({ info, uq: null });
    }
    const rows = [...buckets.complete, ...buckets.available, ...buckets.current];
    if (!rows.length) return;

    qlList.el.replaceChildren();
    rows.forEach((r, i) => {
      const done = buckets.complete.includes(r);
      const l = new DXLabel({ text: r.info.QuestName ?? '', fontSize: 9,
        textColour: done ? [95, 217, 122, 255] : r.uq ? [255, 255, 255, 255] : [255, 216, 77, 255],
        drawOutline: true, location: [2, i * 22], size: [340, 20], isControl: true });
      l.el.style.cursor = 'pointer';
      l.el.addEventListener('click', () => openQuestDetail(r));
      qlList.addControl(l);
    });
    // 位置: NPC 对话正下方 (GameScene OpenNPCQuestList)
    questListWin.location = [w.location[0], w.location[1] + w.size[1]];
    WindowManager.open(questListWin, scene.hudLayer);
  }

  async function openQuestDetail({ info, uq }) {
    if (!questDetailWin) return;
    const done = uq && (uq.tasks ?? []).every(t => t?.completed);
    if (qdTitle) qdTitle.text = info.QuestName ?? '';
    if (qdDesc) qdDesc.text = subst(uq ? info.ProgressText : info.AcceptText);
    // 任务目标 (QuestTask 表)
    const tasks = await GameDB.questTasks(info.Index);
    const taskLines = [];
    for (const t of tasks) {
      const ipIdx = t.ItemParameter?.Index ?? (typeof t.ItemParameter === 'number' ? t.ItemParameter : null);
      const zh = ipIdx != null ? (D_.itemsById?.[ipIdx]?.zh ?? D_.itemsById?.[ipIdx]?.name ?? '') : '';
      const label = t.Task === 'GainItem' ? `收集 ${zh}`
        : t.Task === 'KillMonster' ? (t.MobDescription || '消灭怪物')
        : (t.Task ?? '');
      taskLines.push(`· ${label} x${t.Amount ?? 1}`);
    }
    if (qdTasks) qdTasks.text = taskLines.join('\n');
    // 奖励 (QuestReward 表)
    const rewards = await GameDB.questRewards(info.Index);
    const rewardLines = [];
    for (const rw of rewards.slice(0, 6)) {
      const idx = rw.Item?.Index ?? rw.Item;
      const zh = D_.itemsById?.[idx]?.zh ?? D_.itemsById?.[idx]?.name ?? rw.Item?.Name ?? '';
      rewardLines.push(`${rw.Choice ? '◆ 选一: ' : '· '}${zh} x${rw.Amount ?? 1}`);
    }
    if (qdRewards) {
      qdRewards.text = rewardLines.join('\n');
      qdRewards.location = [10, 270];
      qdRewards.size = [334, 140];
    }

    // 动作按钮 (:96-147): 接取 / 交还
    for (const c of questActionBtns.splice(0)) questDetailWin.removeControl(c);
    if (!uq || done) {
      const btn = new DXButton({ text: uq ? '交还任务' : '接取任务', fontSize: 9,
        library: 'Interface', index: -1, location: [130, 440], size: [100, 26] });
      btn.onClick = () => {
        if (uq) conn.sendQuestComplete(uq.index, 0);
        else conn.sendQuestAccept(info.Index);
        closeQuestDialogs();
      };
      questDetailWin.addControl(btn);
      questActionBtns.push(btn);
    }
    questDetailWin.location = [questListWin.location[0] + questListWin.size[0] + 4, questListWin.location[1]];
    WindowManager.open(questDetailWin, scene.hudLayer);
  }
  function subst(text) {
    return (text ?? '')
      .replaceAll('[PLAYERNAME]', scene.info?.name ?? '')
      .replaceAll('[STARTNAME]', '')
      .replaceAll('[FINISHNAME]', '');
  }

  // ---------- ShowPage 状态机 (:50-139) ----------
  async function showPage(response) {
    const page = await GameDB.npcPage(response.index);
    if (!page) { scene.addChat(`NPC 页面 #${response.index} 不在本地 DB`, 'hint'); return; }
    npcDialogs.currentNpcObjectID = response.objectID ?? 0;
    const dtype = DIALOG_TYPE.indexOf(page.DialogType ?? 'None');
    const types = [];   // 工作区快照 NPCPage 无 Types 链接列 → 不按类型过滤
    const selling = dtype === 1 && types.length > 0;

    if (!selling) reg.handlers.get('inventory')?.normalMode?.();   // EndInventoryNpcSale (:55)

    // 值替换 <id:default> (:56-62)
    const raw = (page.Say ?? '').replace(/<(?<id>\d+):(?<def>[^<>]+?)>/g, (whole, id, def) => {
      const v = (response.values ?? []).find(x => String(x.id) === id);
      return v ? v.value : def;
    });

    const textH = renderNpcText(raw);
    const rowCount = Math.max(0, Math.min(6, Math.trunc((textH - 124) / 20)));   // (:78)
    const footerY = 140 + rowCount * 20;
    w.size = [380, footerY + 64];
    w.updateClientArea();
    for (const r of rowBgs.splice(0)) w.removeControl(r);
    for (let i = 0; i < rowCount; i++) {
      const row = new DXImageControl({ library: 'GameInter', index: 381, fixedSize: true,
        location: [0, 140 + i * 20], size: [380, 20], isControl: false });
      row.el.style.zIndex = '0';
      w.addControl(row);
      rowBgs.push(row);
    }
    const footer = w.byPath.get('NPCDialog/1');
    if (footer) footer.location = [0, footerY];
    textArea.size = [350, Math.max(0, w.size[1] - 59)];
    if (treeScroll) {
      treeScroll.size = [14, Math.max(0, w.size[1] - 59)];
      treeScroll.location = [350, 45];
    }

    // 商品面板 (:93-94): BuySell 且有商品
    goodsHost.visible = false;
    if (dtype === 1) buildGoods(page);
    // 修理面板 (:109-111)
    repairPanel.visible = false;
    if (dtype === 2) {
      repairTypes = types;
      repairPanel.location = [0, w.size[1]];
      repairPanel.visible = true;
    }
    // 精炼取回面板 (NPCAdvancedPanels.cs:190-192 Configure → BuildRetrieve)
    retrievePanel.visible = false;
    if (dtype === 4) {
      retrievePanel.location = [0, w.size[1]];
      retrievePanel.visible = true;
      renderRetrieve();
    }
    WindowManager.open(w, scene.hudLayer);
    if (dtype === 19) { await winConsign(scene); }   // Consignment → OpenConsignmentDialog (NPCDialog.cs:116)
    if (dtype === 0) await openQuestList(response.objectID);   // (:118-119)
    else closeQuestDialogs();
  }

  // ---------- 关闭 (Close override :184-188: 隐藏必发 C.NPCClose) ----------
  // registry 装饰 onHide: normalMode + sendNPCClose + 关任务子窗

  // ---------- S 包 ----------
  conn.addEventListener('npcResponse', (e) => showPage(e.detail));
  conn.addEventListener('npcClose', () => {
    WindowManager.close(w);
    closeQuestDialogs();
    reg.handlers.get('inventory')?.normalMode?.();
  });
  // S.ItemsChanged → 解锁 pending 链接格
  conn.addEventListener('itemsChanged', (e) => {
    for (const link of e.detail?.links ?? []) {
      if (link?.gridType != null && link?.slot != null) store.unlockPublic(link.gridType, link.slot);
    }
    repairGrid.refreshGrid();
  });

  // ---------- 快路由 (背包右键 → 修理格) ----------
  reg.routeHandlers.push((cell) => {
    if (!repairPanel.visible || !w.visible) return false;
    if (!canAcceptRepair(cell.item)) return false;
    for (let host = 0; host < 55; host++) {
      if (!repairLinks.has(host)) {
        repairLinks.set(host, { gridType: cell.gridType, slot: cell.slot, count: cell.item.count });
        repairVirtual.set(host, cell.item);
        store.lock(cell.gridType, cell.slot);
        repairGrid.refreshGrid();
        updateRepairCost();
        return true;
      }
    }
    return false;
  });

  reg.wins.set('npc', w);
  return {
    win: w,
    open: () => WindowManager.open(w, scene.hudLayer),
    close: () => WindowManager.close(w),
    toggle: () => WindowManager.toggle(w, scene.hudLayer),
    onHide: () => {   // CloseNpc :181-188
      reg.handlers.get('inventory')?.normalMode?.();
      conn.sendNPCClose();
      closeQuestDialogs();
      npcDialogs.currentNpcObjectID = 0;
    },
    showPage,
    importRepairables,
  };
}
