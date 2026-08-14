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
import { DXControl, DXLabel, DXButton, DXImageControl, DXTextInput } from './dx.js';
import { WindowManager } from './windows.js';
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
  // S.RefineList 由服务端在打开页面/精炼完成后主动推 (PlayerObject.cs:1110/12531);
  // 刷新按钮只重渲染本地行 (RequestNPCRefineList→RebuildRetrieveRows :543, 不发包);
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
  // ---------- R19: 精炼系回包反馈 (GameScene.cs:2691-2752 对照) ----------
  // 物品消耗由 itemstore itemsChanged 通道统一处理 (ConsumeNpcLinks→OnItemsChanged 同源);
  // 这里只做聊天反馈 + 面板态同步。
  conn.addEventListener('npcRefineResult', (e) => {   // OnNPCRefine :2699-2704
    completeNpcLinks([...(e.detail?.ores ?? []), ...(e.detail?.items ?? []), ...(e.detail?.specials ?? [])]);
    scene.addChat(e.detail?.success ? '精炼请求已受理，请稍后取回' : '精炼请求被拒绝', 'system');
  });
  conn.addEventListener('npcMasterRefineResult', (e) => {   // OnNPCMasterRefine :2706-2711
    completeNpcLinks([...(e.detail?.fragment1s ?? []), ...(e.detail?.fragment2s ?? []),
      ...(e.detail?.fragment3s ?? []), ...(e.detail?.stones ?? []), ...(e.detail?.specials ?? [])]);
    scene.addChat(e.detail?.success ? '大师精炼成功' : '大师精炼失败', 'system');
  });
  conn.addEventListener('npcRefinementStoneResult', (e) => {   // OnNPCRefinementStone :2691-2697
    completeNpcLinks([...(e.detail?.ironOres ?? []), ...(e.detail?.silverOres ?? []),
      ...(e.detail?.diamondOres ?? []), ...(e.detail?.goldOres ?? []), ...(e.detail?.crystal ?? [])]);
    scene.addChat('精炼石制作请求已受理', 'system');
  });
  conn.addEventListener('npcWeaponCraftResult', (e) => {   // OnNPCWeaponCraft :2734-2739
    completeNpcLinks(['template', 'yellow', 'blue', 'red', 'purple', 'green', 'grey'].map(k => e.detail?.[k]));
    scene.addChat(e.detail?.success ? '武器打造成功' : '武器打造失败', 'system');
  });
  conn.addEventListener('npcAccessoryLevelUpResult', (e) => {   // OnNPCAccessoryLevelUp :2713-2719 (ReleaseNpcLinksWithoutConsuming)
    completeNpcLinks([e.detail?.target, ...(e.detail?.links ?? [])]);
  });
  conn.addEventListener('npcAccessoryUpgradeResult', (e) => {   // OnNPCAccessoryUpgrade :2721-2722 (无 ItemsChanged)
    completeNpcLinks([e.detail?.target]);
    scene.addChat(e.detail?.success ? '饰品强化成功' : '饰品强化失败', 'system');
  });
  conn.addEventListener('npcRefineRetrieveResult', (e) => {   // OnNPCRefineRetrieve :2741-2746 RemoveRefine
    const idx = e.detail?.index;
    if (idx != null) refineList = refineList.filter(x => x.index !== idx);
    if (retrievePanel.visible) renderRetrieve();
    scene.addChat(`精炼物品 #${idx} 已取回`, 'system');
  });

  // ---------- 单链接面板 (NPCAdvancedPanels.cs:621-633 BuildSingleGrid/Target + SubmitSingle:997) ----------
  // ItemFragment(多格)/AccessoryReset/WeddingRing/AccessoryUpgrade — 背包拖入或点击导入, 提交发真包。
  const singlePanel = new DXControl({ location: [0, 204], size: [404, 220], visible: false, isControl: true });
  const singleBox = document.createElement('div');
  singleBox.style.cssText = 'position:absolute;left:9px;top:30px;right:9px;bottom:40px;overflow-y:auto;';
  singlePanel.el.appendChild(singleBox);
  const singleLabel = new DXLabel({ text: '', fontSize: 9, textColour: [255, 216, 77, 255],
    drawOutline: true, location: [9, 8], size: [380, 18], isControl: false });
  const singleImport = new DXButton({ text: '从背包导入', fontSize: 9, library: 'Interface', index: -1,
    location: [9, 182], size: [100, 22], onClick: () => importSingle() });
  const singleSubmit = new DXButton({ text: '提交', fontSize: 9, library: 'Interface', index: -1,
    location: [120, 182], size: [70, 22], onClick: () => submitSingle() });
  let singleMode = null;          // 'ItemFragment' | 'AccessoryReset' | 'WeddingRing' | 'AccessoryRefineUpgrade'
  let singleLinks = [];           // CellLinkInfo[]
  const SINGLE_DEFS = {   // (title, 最大格数, 提交动作)
    ItemFragment: ['分解物品 (可多件)', 20, (links) => conn.sendNPCFragment(links)],
    AccessoryReset: ['重置饰品 (放入 1 件)', 1, (links) => conn.sendNPCAccessoryReset(links[0])],
    WeddingRing: ['制作结婚戒指 (放入 1 枚戒指)', 1, (links) => conn.sendMarriageMakeRing(links[0].slot)],
    AccessoryRefineUpgrade: ['强化饰品 (放入 1 件)', 1, (links) => conn.sendNPCAccessoryUpgrade(links[0], 0)],   // RefineType.None=0, 页面选单 P3
  };
  function importSingle() {
    if (!singleMode) return;
    const max = SINGLE_DEFS[singleMode][1];
    singleLinks = [];
    for (const [slot, it] of [...store.items(GRID.INVENTORY).entries()].sort((a, b) => a[0] - b[0])) {
      if (!it) continue;
      singleLinks.push({ gridType: GRID.INVENTORY, slot, count: it.count ?? 1 });
      if (singleLinks.length >= max) break;
    }
    renderSingle();
  }
  const renderSingle = async () => {
    singleBox.replaceChildren();
    if (!singleMode) return;
    singleLabel.text = SINGLE_DEFS[singleMode][0];
    for (const l of singleLinks) {
      const it = store.items(l.gridType).get(l.slot);
      const nm = it ? (D().itemsById?.[it.infoIndex]?.zh ?? D().itemsById?.[it.infoIndex]?.name ?? `物品#${it.infoIndex}`) : '?';
      const d = document.createElement('div');
      d.textContent = `· ${nm} x${it?.count ?? 1}`;
      d.style.cssText = 'padding:2px 6px;font:12px/1.7 \'Noto Sans CJK SC\',sans-serif;color:#eee;text-shadow:1px 1px 0 #000;cursor:pointer;';
      d.title = '点击移除';
      d.onclick = () => { singleLinks = singleLinks.filter(x => x !== l); if (!pendingNpcLinks.some(p => p.gridType === l.gridType && p.slot === l.slot)) store.unlockPublic(l.gridType, l.slot); renderSingle(); };   // CancelLinks 解锁 (提交锁除外)
      singleBox.appendChild(d);
    }
    if (!singleLinks.length) singleBox.textContent = '（点"从背包导入"或稍后拖入）';
    singleSubmit.enabled = singleLinks.length > 0;
  };
  // ---- 提交锁 (BeginSubmit :1039-1060 / CompleteLinks :1062 / CancelLinks :560 对照) ----
  // 提交期锁背包来源格 (拖不动), S 回包 (CompleteLinks) 或面板重配 (CancelLinks) 解锁;
  // 服务端 ParseLinks 失败静默 return 时锁保留至重配 — 与 Godot 行为一致。
  let pendingNpcLinks = [];
  function beginNpcSubmit(groups) {
    if (pendingNpcLinks.length) return null;   // 提交中禁重复 (:1041)
    const flat = groups.flat().filter(Boolean);
    const links = [...new Map(flat.map(l => [`${l.gridType}:${l.slot}`, l])).values()];
    if (!links.length) return null;
    pendingNpcLinks = links;
    for (const l of links) store.lock(l.gridType, l.slot);
    return links;
  }
  function completeNpcLinks(links) {
    const arr = (links ?? []).filter(Boolean);
    const keys = new Set(arr.map(l => `${l.gridType}:${l.slot}`));
    pendingNpcLinks = pendingNpcLinks.filter(l => !keys.has(`${l.gridType}:${l.slot}`));
    for (const l of arr) store.unlockPublic(l.gridType, l.slot);
  }
  function cancelNpcLinks() { completeNpcLinks(pendingNpcLinks.slice()); }

  function submitSingle() {
    const links = beginNpcSubmit([singleLinks]);
    if (!links) return;
    SINGLE_DEFS[singleMode][2](links);
    singleLinks = [];
    renderSingle();
  }
  singlePanel.addControl(singleLabel, singleImport, singleSubmit);
  w.addControl(singlePanel);

  // ---------- 精炼面板 (NPCAdvancedPanels.cs:383-429 BuildRefine) ----------
  // 黑铁矿×5 + 饰品×3 + 特殊×1 → 选 RefineType(9 单选) → 品质循环(Rush..Precise) → 提交。
  const refinePanel = new DXControl({ location: [0, 204], size: [404, 220], visible: false, isControl: true });
  const REFINE_TYPES = [   // (RefineType enum: None,0 Durability,1 DC,2 SpellPower,3 Fire,4 Ice,5 Lightning,6 Wind,7 Holy,8 Dark,9 Phantom,10)
    [2, '攻击 DC'], [3, '法术'], [4, '火'], [5, '冰'], [6, '雷'], [7, '风'], [8, '神圣'], [9, '暗'], [10, '幻影'],
  ];
  const REFINE_QUALITIES = ['Rush 立即', 'Quick 30分', 'Standard 1时', 'Careful 6时', 'Precise 1天'];   // RefineQuality 0-4
  const REFINE_SLOTS = [
    ['ores', '黑铁矿', 5], ['items', '饰品', 3], ['specials', '特殊', 1],
  ];   // GridType 7/8/9, 上限对照 AddGrid 行×列
  let refineType = 0;      // RefineType.None
  let refineQuality = 0;   // Rush
  const refineLinks = { ores: [], items: [], specials: [] };
  const refineTypeBtns = [];
  REFINE_TYPES.forEach(([val, label], i) => {
    const col = i % 3, row = Math.trunc(i / 3);
    const b = new DXButton({ text: '', fontSize: 9, library: 'Interface', index: -1,
      location: [10 + col * 120, 6 + row * 22], size: [110, 20],
      onClick: () => {
        refineType = val;
        refineTypeBtns.forEach((o, j) => { o.text = REFINE_TYPES[j][1]; });
        b.text = '● ' + label;
        refineSubmit.enabled = true;
      } });
    b.text = label;
    refineTypeBtns.push(b);
    refinePanel.addControl(b);
  });
  const refineQualityBtn = new DXButton({ text: REFINE_QUALITIES[0], fontSize: 9, library: 'Interface', index: -1,
    location: [376, 6], size: [100, 20], onClick: () => {   // CycleQuality (:936-944)
      refineQuality = (refineQuality + 1) % REFINE_QUALITIES.length;
      refineQualityBtn.text = REFINE_QUALITIES[refineQuality];
    } });
  const refineListBox = document.createElement('div');
  refineListBox.style.cssText = 'position:absolute;left:9px;top:76px;right:9px;bottom:36px;overflow-y:auto;';
  refinePanel.el.appendChild(refineListBox);
  const refineImport = new DXButton({ text: '从背包导入', fontSize: 9, library: 'Interface', index: -1,
    location: [9, 186], size: [100, 22], onClick: () => importRefine() });
  const refineSubmit = new DXButton({ text: '开始精炼', fontSize: 9, library: 'Interface', index: -1,
    location: [120, 186], size: [90, 22], onClick: () => {
      if (!refineType) return;
      const links = beginNpcSubmit([refineLinks.ores, refineLinks.items, refineLinks.specials]);
      if (!links) return;   // 空组或提交中不发
      conn.sendNPCRefine(refineType, refineQuality, refineLinks.ores, refineLinks.items, refineLinks.specials);
      refineLinks.ores = []; refineLinks.items = []; refineLinks.specials = [];
      renderRefine();
    } });
  const renderRefine = async () => {
    refineListBox.replaceChildren();
    for (const [key, label] of REFINE_SLOTS.map(([k, l]) => [k, l])) {
      const arr = refineLinks[key];
      const head = document.createElement('div');
      head.textContent = `${label} (${arr.length})`;
      head.style.cssText = 'padding:2px 6px;font:11px "Noto Sans CJK SC",sans-serif;color:#ffd94d;text-shadow:1px 1px 0 #000;';
      refineListBox.appendChild(head);
      for (const l of arr) {
        const it = store.items(l.gridType).get(l.slot);
        const nm = it ? (D().itemsById?.[it.infoIndex]?.zh ?? D().itemsById?.[it.infoIndex]?.name ?? `物品#${it.infoIndex}`) : '?';
        const d = document.createElement('div');
        d.textContent = `· ${nm} x${it?.count ?? 1}`;
        d.style.cssText = 'padding:2px 6px 2px 18px;font:12px/1.6 \'Noto Sans CJK SC\',sans-serif;color:#eee;text-shadow:1px 1px 0 #000;cursor:pointer;';
        d.title = '点击移除';
        d.onclick = () => { refineLinks[key] = refineLinks[key].filter(x => x !== l); if (!pendingNpcLinks.some(p => p.gridType === l.gridType && p.slot === l.slot)) store.unlockPublic(l.gridType, l.slot); renderRefine(); };   // CancelLinks 解锁 (提交锁除外)
        refineListBox.appendChild(d);
      }
    }
  };
  function importRefine() {
    const caps = Object.fromEntries(REFINE_SLOTS.map(([k, , n]) => [k, n]));
    for (const k of Object.keys(refineLinks)) refineLinks[k] = [];
    const ACCESSORY = new Set(['Necklace', 'Bracelet', 'Ring', 'Amulet']);   // ItemType 6/7/8/11
    for (const [slot, it] of [...store.items(GRID.INVENTORY).entries()].sort((a, b) => a[0] - b[0])) {
      if (!it) continue;
      const info = D().itemsById?.[it.infoIndex];
      const bucket = info?.type === 'Ore' ? 'ores'
        : info?.type === 'RefineSpecial' ? 'specials'
        : ACCESSORY.has(info?.type) ? 'items' : null;
      if (bucket && caps[bucket] > refineLinks[bucket].length)
        refineLinks[bucket].push({ gridType: GRID.INVENTORY, slot, count: it.count ?? 1 });
    }
    renderRefine();
  }
  refinePanel.addControl(refineQualityBtn, refineImport, refineSubmit);
  w.addControl(refinePanel);

  // ---------- 多桶面板引擎 (RefinementStone :324 / MasterRefine :431 / AccessoryLevel :686 / WeaponCraft :801) ----------
  // 各面板共享: 桶列表 + 可选单选组 + 可选金币输入 + 动作按钮; 分类由 match(info,item) 决定。
  function buildMultiBucket(cfg) {
    const panel = new DXControl({ location: [0, 204], size: [404, 232], visible: false, isControl: true });
    const links = Object.fromEntries(cfg.buckets.map(([k]) => [k, []]));
    let radioVal = 0, goldVal = 0;
    const radioBtns = [];
    let yCursor = 6;
    if (cfg.radio) {
      cfg.radio.forEach(([val, label], i) => {
        const col = i % 4, row = Math.trunc(i / 4);
        const b = new DXButton({ text: label, fontSize: 9, library: 'Interface', index: -1,
          location: [10 + col * 98, 6 + row * 22], size: [92, 20], onClick: () => {
            radioVal = val;
            radioBtns.forEach((o, j) => { o.text = cfg.radio[j][1]; });
            b.text = '● ' + label;
            refreshBtns();
          } });
        radioBtns.push(b);
        panel.addControl(b);
      });
      yCursor = 6 + Math.ceil(cfg.radio.length / 4) * 22 + 4;
    }
    let goldInput = null;
    if (cfg.gold) {
      goldInput = new DXTextInput({ text: '0', location: [10, yCursor], size: [120, 19] });
      panel.addControl(goldInput);
      panel.addControl(new DXLabel({ text: '金币投入:', fontSize: 9, location: [134, yCursor], size: [80, 18], isControl: false }));
      goldInput.onTextChanged?.(() => { goldVal = Number(goldInput.text) || 0; });
      yCursor += 24;
    }
    const listBox = document.createElement('div');
    listBox.style.cssText = `position:absolute;left:9px;top:${yCursor}px;right:9px;bottom:36px;overflow-y:auto;`;
    panel.el.appendChild(listBox);
    const btns = [];
    const refreshBtns = () => { if (initialized) for (const b of btns) b.enabled = b.check(); };
    const render = () => {
      listBox.replaceChildren();
      for (const [key, label] of cfg.buckets.map(([k, l]) => [k, l])) {
        const arr = links[key];
        const head = document.createElement('div');
        head.textContent = `${label} (${arr.length})`;
        head.style.cssText = 'padding:2px 6px;font:11px "Noto Sans CJK SC",sans-serif;color:#ffd94d;text-shadow:1px 1px 0 #000;';
        listBox.appendChild(head);
        for (const l of arr) {
          const it = store.items(l.gridType).get(l.slot);
          const nm = it ? (D().itemsById?.[it.infoIndex]?.zh ?? D().itemsById?.[it.infoIndex]?.name ?? `物品#${it.infoIndex}`) : '?';
          const d = document.createElement('div');
          d.textContent = `· ${nm} x${it?.count ?? 1}`;
          d.style.cssText = 'padding:2px 6px 2px 18px;font:12px/1.6 \'Noto Sans CJK SC\',sans-serif;color:#eee;text-shadow:1px 1px 0 #000;cursor:pointer;';
          d.title = '点击移除';
          d.onclick = () => { links[key] = links[key].filter(x => x !== l); if (!pendingNpcLinks.some(p => p.gridType === l.gridType && p.slot === l.slot)) store.unlockPublic(l.gridType, l.slot); render(); };   // CancelLinks 解锁 (提交锁除外)
          listBox.appendChild(d);
        }
      }
      refreshBtns();
    };
    const doImport = () => {
      const caps = Object.fromEntries(cfg.buckets.map(([k, , n]) => [k, n]));
      for (const k of Object.keys(links)) links[k] = [];
      for (const [slot, it] of [...store.items(GRID.INVENTORY).entries()].sort((a, b) => a[0] - b[0])) {
        if (!it) continue;
        const info = D().itemsById?.[it.infoIndex];
        const hit = cfg.buckets.find(([, , , match]) => match?.(info, it));
        if (hit && caps[hit[0]] > links[hit[0]].length)
          links[hit[0]].push({ gridType: GRID.INVENTORY, slot, count: it.count ?? 1 });
      }
      render();
    };
    const importBtn = new DXButton({ text: '从背包导入', fontSize: 9, library: 'Interface', index: -1,
      location: [9, 198], size: [100, 22], onClick: doImport });
    panel.addControl(importBtn);
    cfg.buttons.forEach(([label, dx, check, act], i) => {
      const b = new DXButton({ text: label, fontSize: 9, library: 'Interface', index: -1,
        location: [118 + i * 92, 198], size: [86, 22], onClick: () => {
          if (!b.enabled) return;
          if (!beginNpcSubmit([Object.values(links).flat()])) return;   // 提交锁 (BeginSubmit)
          act();
          for (const k of Object.keys(links)) links[k] = [];
          render();
        } });
      b.enabled = false;
      b.check = check;
      btns.push(b);
      panel.addControl(b);
    });
    let initialized = false;   // 构造期 check() 闭包引用外层 const — TDZ 前不刷新
    render();
    initialized = true;
    return {
      panel, links,
      radio: () => radioVal,
      gold: () => goldVal,
      render,
      reset() {
        radioVal = 0;
        radioBtns.forEach((o, j) => { o.text = cfg.radio[j][1]; });
        if (goldInput) { goldInput.text = '0'; goldVal = 0; }
        for (const k of Object.keys(links)) links[k] = [];
        render();
      },
      route(cell) {   // TryRouteItem (NPCDialog.cs:161 → advanced): 右键物品入桶 (面板可见时)
        if (!panel.visible || !w.visible || !cell?.item) return false;
        const info = D().itemsById?.[cell.item.infoIndex];
        const hit = cfg.buckets.find(([, , , match]) => match?.(info, cell.item));
        if (!hit) return false;
        const [key, , cap] = hit;
        if (links[key].length >= cap) return false;
        if (links[key].some(l => l.gridType === cell.gridType && l.slot === cell.slot)) return false;
        links[key].push({ gridType: cell.gridType, slot: cell.slot, count: cell.item.count ?? 1 });
        store.lock(cell.gridType, cell.slot);
        render();
        return true;
      },
    };
  }

  // R18-1 精炼石 (BuildRefinementStone :324-352)
  const stonePanel = buildMultiBucket({
    buckets: [
      ['iron', '铁矿石', 4, (info) => info?.name === 'Iron Ore'],
      ['silver', '银矿石', 4, (info) => info?.name === 'Silver Ore'],
      ['diamond', '钻石', 4, (info) => info?.name === 'Diamond'],
      ['goldOre', '金矿石', 2, (info) => info?.name === 'Gold Ore'],
      ['crystal', '水晶', 1, (info) => info?.name === 'Crystal'],
    ],
    gold: true,
    buttons: [['制作', 0,
      () => Object.values(stonePanel.links).some(a => a.length > 0),
      () => conn.sendNPCRefinementStone(stonePanel.links.iron, stonePanel.links.silver,
        stonePanel.links.diamond, stonePanel.links.goldOre, stonePanel.links.crystal, stonePanel.gold())]],
  });
  w.addControl(stonePanel.panel);

  // R18-2 大师精炼 (BuildMasterRefine :431-478 + SubmitMaster :479-516)
  const REFINE_TYPE_OPTS = [[2, '攻击'], [3, '法术'], [4, '火'], [5, '冰'], [6, '雷'], [7, '风'], [8, '神圣'], [9, '暗'], [10, '幻影']];
  const masterPanel = buildMultiBucket({
    buckets: [
      ['f1', '碎片（一）', 1, (info) => info?.name === 'Fragment'],
      ['f2', '碎片（二）', 1, (info) => info?.name === 'Fragment (II)'],
      ['f3', '碎片（三）', 1, (info) => info?.name === 'Fragment (III)'],
      ['stone', '精炼石', 1, (info) => info?.name === 'Refinement Stone'],
      ['special', '特殊材料', 1, (info) => info?.type === 'RefineSpecial'],
    ],
    radio: REFINE_TYPE_OPTS,
    buttons: [
      ['评估', 0, () => masterPanel.radio() > 0 && !!masterValidate(false), () => masterSend(true)],
      ['精炼', 1, () => masterPanel.radio() > 0 && !!masterValidate(false), () => masterSend(false)],
    ],
  });
  function masterValidate(chat = true) {   // SubmitMaster :487-506 逐项校验
    const L = masterPanel.links;
    const fail = (msg) => { if (chat) scene.addChat(msg, 'hint'); return null; };
    if (!L.f1.length || L.f1[0].count !== 10) return fail('需要 碎片(一) x10 才能大师精炼');
    if (!L.f2.length || L.f2[0].count !== 10) return fail('需要 碎片(二) x10 才能大师精炼');
    if (!L.f3.length) return fail('需要至少 1 个 碎片(三) 才能大师精炼');
    if (!L.stone.length) return fail('需要精炼石 x1 才能进行大师精炼');
    return true;
  }
  function masterSend(evaluate) {
    const L = masterPanel.links;
    const t = masterPanel.radio();
    if (evaluate) conn.sendNPCMasterRefineEvaluate(t, L.f1, L.f2, L.f3, L.stone, L.special);
    else conn.sendNPCMasterRefine(t, L.f1, L.f2, L.f3, L.stone, L.special);
  }
  w.addControl(masterPanel.panel);

  // R18-3 饰品升级 (BuildAccessoryLevel :686-711)
  const ACCESSORY_TYPES = new Set(['Necklace', 'Bracelet', 'Ring', 'Amulet']);
  const accLevelPanel = buildMultiBucket({
    buckets: [
      ['target', '目标饰品', 1, (info) => ACCESSORY_TYPES.has(info?.type)],
      ['mats', '材料饰品', 21, (info) => ACCESSORY_TYPES.has(info?.type)],
    ],
    buttons: [['升级', 0,
      () => accLevelPanel.links.target.length > 0 && accLevelPanel.links.mats.length > 0,
      () => conn.sendNPCAccessoryLevelUp(accLevelPanel.links.target[0], accLevelPanel.links.mats)]],
  });
  w.addControl(accLevelPanel.panel);

  // R18-4 武器打造 (BuildWeaponCraft :801-829 + CycleClass :946)
  const CRAFT_CLASSES = ['全部', '战士', '法师', '道士', '刺客'];   // RequiredClass 0-4
  let craftClassIdx = 0;
  const craftClassBtn = new DXButton({ text: '职业: 全部', fontSize: 9, library: 'Interface', index: -1,
    location: [10, 6], size: [100, 20], onClick: () => {   // CycleClass (:946-951)
      craftClassIdx = (craftClassIdx + 1) % CRAFT_CLASSES.length;
      craftClassBtn.text = '职业: ' + CRAFT_CLASSES[craftClassIdx];
    } });
  const craftPanel = buildMultiBucket({
    buckets: [
      ['template', '模板武器', 1, (info) => info?.type === 'Weapon'],
      ['yellow', '黄宝石', 1, (info) => info?.name === 'Jewel'],
      ['blue', '蓝宝石', 1, (info) => info?.name === 'Jewel'],
      ['red', '红宝石', 1, (info) => info?.name === 'Jewel'],
      ['purple', '紫宝石', 1, (info) => info?.name === 'Jewel'],
      ['green', '绿宝石', 1, (info) => info?.name === 'Jewel'],
      ['grey', '灰宝石', 1, (info) => info?.name === 'Jewel'],
    ],
    buttons: [['打造', 0,
      () => craftPanel.links.template.length > 0,
      () => {
        const L = craftPanel.links;
        conn.sendNPCWeaponCraft(craftClassIdx, L.template[0],
          L.yellow[0] ?? null, L.blue[0] ?? null, L.red[0] ?? null,
          L.purple[0] ?? null, L.green[0] ?? null, L.grey[0] ?? null);
      }]],
  });
  craftPanel.panel.addControl(craftClassBtn);
  w.addControl(craftPanel.panel);

  // R18-5 伙伴寄存 (NPCCompanionStorageDialog.cs — dtype 5 → OpenNPCCompanionStorage)
  const companionPanel = new DXControl({ location: [0, 204], size: [404, 160], visible: false, isControl: true });
  const companionBox = document.createElement('div');
  companionBox.style.cssText = 'position:absolute;left:9px;top:30px;right:9px;bottom:36px;overflow-y:auto;';
  companionPanel.el.appendChild(companionBox);
  let companionSel = -1;
  const renderCompanions = () => {
    companionBox.replaceChildren();
    const list = store.info?.companions ?? [];
    list.forEach((c, i) => {
      if (!c) return;
      const d = document.createElement('div');
      d.textContent = `${i === companionSel ? '●' : '○'} ${c.name}  Lv.${c.level}  饥饿${c.hunger}`;
      d.style.cssText = 'padding:3px 6px;font:12px/1.7 \'Noto Sans CJK SC\',sans-serif;color:#eee;text-shadow:1px 1px 0 #000;cursor:pointer;';
      d.onclick = () => { companionSel = i; renderCompanions(); };
      companionBox.appendChild(d);
    });
    if (!companionBox.children.length) companionBox.textContent = '（无伙伴 — 先在驯兽师处领养）';
  };
  const selIdx = () => {
    const list = store.info?.companions ?? [];
    return companionSel >= 0 && companionSel < list.length && list[companionSel] ? list[companionSel].index : -1;
  };
  ['寄存|sendCompanionStore', '取回|sendCompanionRetrieve', '放生|sendCompanionRelease'].forEach((spec, i) => {
    const [label, fn] = spec.split('|');
    companionPanel.addControl(new DXButton({ text: label, fontSize: 9, library: 'Interface', index: -1,
      location: [9 + i * 92, 130], size: [86, 22], onClick: () => {
        const idx = selIdx();
        if (idx >= 0) conn[fn](idx);   // Release 原版有 ConfirmDialog — web 端点击即确认 (headless 无二次确认路径)
      } }));
  });
  w.addControl(companionPanel);
  // R19: 伙伴结果同步 (OnCompanionRetrieve/Release GameScene.cs:2612-2627 对照)
  conn.addEventListener('companionRetrieveResult', (e) => {
    const idx = e.detail?.index;
    const list = store.info?.companions ?? [];
    if (idx != null) store.info.companion = idx;   // GameScene.Companion = Companions.FirstOrDefault(Index)
    companionSel = list.findIndex(c => c?.index === idx);
    if (companionPanel.visible) renderCompanions();
    scene.addChat(`伙伴 #${idx} 已取回`, 'system');
  });
  conn.addEventListener('companionReleaseResult', (e) => {   // RemoveAll + RemoveCompanion
    const idx = e.detail?.index;
    const list = store.info?.companions ?? [];
    const at = list.findIndex(c => c?.index === idx);
    if (at >= 0) list.splice(at, 1);
    if (store.info.companion === idx) store.info.companion = 0;
    companionSel = -1;
    if (companionPanel.visible) renderCompanions();
    scene.addChat(`伙伴 #${idx} 已放生`, 'system');
  });
  // ---------- 右键快路由注册 (NPCDialog.cs:155-162 TryRouteItem 对照) ----------
  // repair 在下方单独注册; 此处: 单链接面板 (SubmitSingle 本地校验 :1002-1003) +
  // 精炼三桶 (importRefine 同分类) + 4 个 multi-bucket 面板。
  reg.routeHandlers.push((cell) => {   // 单链接: WeddingRing=Ring / AccessoryReset=Ring|Bracelet|Necklace
    if (!singlePanel.visible || !w.visible || !singleMode || !cell?.item) return false;
    const max = SINGLE_DEFS[singleMode][1];
    if (singleLinks.length >= max) return false;
    if (singleLinks.some(l => l.gridType === cell.gridType && l.slot === cell.slot)) return false;
    const info = D().itemsById?.[cell.item.infoIndex];
    if (singleMode === 'AccessoryReset' && !['Ring', 'Bracelet', 'Necklace'].includes(info?.type)) return false;
    if (singleMode === 'WeddingRing' && info?.type !== 'Ring') return false;
    singleLinks.push({ gridType: cell.gridType, slot: cell.slot, count: cell.item.count ?? 1 });
    store.lock(cell.gridType, cell.slot);
    renderSingle();
    return true;
  });
  reg.routeHandlers.push((cell) => {   // 精炼: ItemType 分桶 (importRefine 同源)
    if (!refinePanel.visible || !w.visible || !cell?.item) return false;
    const info = D().itemsById?.[cell.item.infoIndex];
    const ACCESSORY = new Set(['Necklace', 'Bracelet', 'Ring', 'Amulet']);
    const bucket = info?.type === 'Ore' ? 'ores'
      : info?.type === 'RefineSpecial' ? 'specials'
      : ACCESSORY.has(info?.type) ? 'items' : null;
    if (!bucket) return false;
    const cap = { ores: 5, items: 3, specials: 1 }[bucket];
    if (refineLinks[bucket].length >= cap) return false;
    if (refineLinks[bucket].some(l => l.gridType === cell.gridType && l.slot === cell.slot)) return false;
    refineLinks[bucket].push({ gridType: cell.gridType, slot: cell.slot, count: cell.item.count ?? 1 });
    store.lock(cell.gridType, cell.slot);
    renderRefine();
    return true;
  });
  for (const p of [stonePanel, masterPanel, accLevelPanel, craftPanel]) {
    reg.routeHandlers.push((cell) => p.route(cell));
  }

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

    if (!selling) { reg.handlers.get('inventory')?.normalMode?.(); cancelNpcLinks(); }   // EndInventoryNpcSale (:55) + CancelLinks (Configure 对照)

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
    // 单链接面板 (BuildSingleGrid/Target: dtype 6/10/11/13)
    singlePanel.visible = false;
    const singleModeName = { 6: 'WeddingRing', 10: 'ItemFragment', 11: 'AccessoryRefineUpgrade', 13: 'AccessoryReset' }[dtype];
    if (singleModeName) {
      singleMode = singleModeName;
      singleLinks = [];
      singlePanel.location = [0, w.size[1]];
      singlePanel.visible = true;
      renderSingle();
    }
    // 精炼面板 (BuildRefine: dtype 3)
    refinePanel.visible = false;
    if (dtype === 3) {
      refineType = 0;
      refineQuality = 0;
      refineQualityBtn.text = REFINE_QUALITIES[0];
      refineLinks.ores = []; refineLinks.items = []; refineLinks.specials = [];
      refineSubmit.enabled = false;
      refinePanel.location = [0, w.size[1]];
      refinePanel.visible = true;
      renderRefine();
    }
    // R18 批次 (dtype 7/8/12/14 + 5)
    const MULTI_MAP = { 7: stonePanel, 8: masterPanel, 12: accLevelPanel, 14: craftPanel };
    for (const p of Object.values(MULTI_MAP)) p.panel.visible = false;
    if (MULTI_MAP[dtype]) {
      MULTI_MAP[dtype].panel.location = [0, w.size[1]];
      MULTI_MAP[dtype].panel.visible = true;
      MULTI_MAP[dtype].reset();
    }
    // 伙伴寄存 (dtype 5 → OpenNPCCompanionStorage GameScene.cs:479)
    companionPanel.visible = false;
    if (dtype === 5) {
      companionSel = -1;
      companionPanel.location = [0, w.size[1]];
      companionPanel.visible = true;
      renderCompanions();
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
