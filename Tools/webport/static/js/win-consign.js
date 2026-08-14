// win-consign.js — ConsignmentDialog (寄售行, ConsignmentDialog.cs)
// 入口: NPC 页面 DialogType=Consignment → GameScene.OpenConsignmentDialog (NPCDialog.cs:116)。
// 搜索购买 (选中行→数量+总价确认→Buy) / 我的寄售 (选中行→数量+确认→CancelConsign;
// 寄售弹窗 ConsignItemDialog.cs :531-589: 物品格+单价+±5000+二次确认)。
// 服务器全是原版 MarketPlace* 包, 不在客户端伪造结果 (铁律)。
import { DXControl, DXLabel, DXButton, DXTextInput } from './dx.js';
import { DXWindow, WindowManager } from './windows.js';
import { GameDB } from './gamedb.js';
import { GRID } from './net.js';

import { D } from './data.js';

const itemName = async (infoIndex) => {
  const d = D().itemsById?.[infoIndex];   // webres items.json (带 zh)
  if (d?.zh || d?.name) return d.zh && d.zh !== d.name ? d.zh : d.name;
  const info = await GameDB.itemInfo(infoIndex);   // dbeditor 快照兜底 (字段 ItemName)
  return info?.ItemName ?? `物品#${infoIndex}`;
};

let shared = null;   // 单例 (GameScene _consignmentDialog 语义)

const ROW_CSS = 'padding:2px 6px;font:12px/1.7 \'Noto Sans CJK SC\',sans-serif;color:#eee;text-shadow:1px 1px 0 #000;cursor:pointer;';
const SEL_CSS = 'background:rgba(120,180,255,.25);';
const BOX_CSS = 'position:absolute;left:50%;top:50%;transform:translate(-50%,-50%);background:rgba(20,24,40,.97);border:1px solid #6bf;padding:10px 12px;min-width:250px;font:12px/1.7 \'Noto Sans CJK SC\',sans-serif;color:#eee;z-index:2;';
const MBTN_CSS = 'margin:4px 6px 0 0;padding:3px 14px;background:#2a4;border:1px solid #7d7;cursor:pointer;';
const INPUT_CSS = 'background:#111;color:#fff;border:1px solid #567;padding:2px 4px;';

export async function winConsign(scene) {
  if (shared) { WindowManager.open(shared.win, scene.hudLayer); return shared; }

  const conn = scene.conn;
  const store = scene.itemStore;
  const win = new DXWindow({ title: '寄售行', size: [420, 330] });
  const body = new DXControl({ location: [8, 26], size: [404, 296], isControl: false });
  win.addControl(body);

  // ---- 页切换 ----
  let page = 'search';
  const tabs = [];
  const mkTab = (label, name) => {
    const b = new DXButton({ text: label, fontSize: 9, library: 'Interface', index: -1,
      location: [8 + tabs.length * 90, 0], size: [84, 22],
      onClick: () => { page = name; selectedSearch = -1; selectedConsign = -1; renderTabs(); render(); } });
    tabs.push({ b, name });
    body.addControl(b);
  };
  mkTab('搜索购买', 'search');
  mkTab('我的寄售', 'mine');
  const renderTabs = () => { for (const t of tabs) t.b.el.style.opacity = t.name === page ? '1' : '.55'; };

  // ---- 搜索页 ----
  const searchBox = document.createElement('div');
  searchBox.style.cssText = 'position:absolute;top:54px;left:0;right:0;bottom:56px;overflow-y:auto;';
  body.el.appendChild(searchBox);
  // 排序 (Godot :91-92: Newest↔LowestPrice 二态切换; MarketPlaceSort int 序列化)
  let sortMode = 0;   // 0=Newest 3=LowestPrice (Enum.cs:1642)
  const btnSort = new DXButton({ text: '最新', fontSize: 9, library: 'Interface', index: -1,
    location: [8, 8], size: [72, 20], onClick: () => {
      sortMode = sortMode === 0 ? 3 : 0;
      btnSort.text = sortMode === 0 ? '最新' : '最低价格';
      doSearch();
    } });
  body.addControl(btnSort);
  // 类型过滤 (BuildTypeFilter :306-328: 全部+ItemType 37 项; ItemType byte 序列化)
  let typeFilter = null;   // null=全部 (AddTypeButton null 语义)
  const typeSel = document.createElement('select');
  typeSel.style.cssText = 'position:absolute;left:88px;top:30px;font:11px \'Noto Sans CJK SC\',sans-serif;background:#1b2233;color:#eee;border:1px solid #567;padding:1px 2px;';
  const TYPE_ZH = { 1: '消耗品', 2: '武器', 3: '护甲', 4: '火把', 5: '头盔', 6: '项链', 7: '手镯', 8: '戒指', 9: '鞋', 10: '毒药', 11: '护身符', 12: '肉', 13: '矿石', 14: '书', 15: '卷轴', 16: '暗石', 17: '精炼特殊', 18: '马甲', 19: '花', 20: '伙伴食品', 21: '伙伴包', 22: '伙伴头饰', 23: '伙伴背饰', 24: '系统', 25: '物品部件', 26: '勋章', 27: '盾牌', 28: '时装', 29: '鱼钩', 30: '鱼漂', 31: '鱼饵', 32: '寻物器', 33: '渔线轮', 34: '货币', 35: '捆绑包', 36: '战利品箱', 37: '宝石' };
  const optAll = document.createElement('option');
  optAll.value = ''; optAll.textContent = '全部类型';
  typeSel.appendChild(optAll);
  for (const [v, zh] of Object.entries(TYPE_ZH)) {
    const o = document.createElement('option');
    o.value = v; o.textContent = zh;
    typeSel.appendChild(o);
  }
  typeSel.onchange = () => { typeFilter = typeSel.value === '' ? null : parseInt(typeSel.value, 10); doSearch(); };   // AddTypeButton → BuildTypeFilter+Search
  body.el.appendChild(typeSel);
  const doSearch = () => conn.sendMarketPlaceSearch((nameInput.text ?? '').trim(), typeFilter != null, typeFilter ?? 0, sortMode);   // Search() :294-304
  const nameInput = new DXTextInput({ location: [216, 8], size: [150, 20], fontSize: 9 });
  const btnSearch = new DXButton({ text: '搜索', fontSize: 9, library: 'Interface', index: -1,
    location: [372, 8], size: [60, 20], onClick: () => doSearch() });
  body.addControl(nameInput); body.addControl(btnSearch);
  const searchCount = new DXLabel({ text: '', fontSize: 9, textColour: [255, 213, 115, 255], location: [8, 30], size: [80, 18], isControl: false });
  body.addControl(searchCount);
  // 成交记录 (history :129 → ShowHistory :497: 选中行物品开 MarketHistoryDialog)
  const btnHistory = new DXButton({ text: '成交记录', fontSize: 9, library: 'Interface', index: -1,
    location: [76, 272], size: [90, 22], visible: false, onClick: () => showHistory() });
  btnHistory.enabled = false;
  body.addControl(btnHistory);

  // ---- 我的寄售页 ----
  const mineBox = document.createElement('div');
  mineBox.style.cssText = 'position:absolute;top:54px;left:0;right:0;bottom:56px;overflow-y:auto;display:none;';
  body.el.appendChild(mineBox);

  // ---- 底部动作区 (Godot ActionButton 行 :125-166: Buy/Remove/GuildFunds/Consign) ----
  const btnBuy = new DXButton({ text: '购买', fontSize: 9, library: 'Interface', index: -1,
    location: [8, 272], size: [60, 22], onClick: () => buySelected() });
  btnBuy.enabled = false;   // :126 (选中行才可用)
  body.addControl(btnBuy);
  const btnRemove = new DXButton({ text: '下架', fontSize: 9, library: 'Interface', index: -1,
    location: [8, 272], size: [60, 22], visible: false, onClick: () => removeSelected() });
  btnRemove.enabled = false;   // :161
  body.addControl(btnRemove);
  const btnConsign = new DXButton({ text: '寄售物品', fontSize: 9, library: 'Interface', index: -1,
    location: [76, 272], size: [96, 22], visible: false, onClick: () => openConsignPopup() });   // OpenConsignPopup :258
  body.addControl(btnConsign);
  // 公会资金勾选 (:132/:164: Enabled = HasGuild)
  const guildWrap = document.createElement('label');
  guildWrap.style.cssText = 'position:absolute;left:184px;top:276px;font:12px \'Noto Sans CJK SC\',sans-serif;color:#ddd;cursor:pointer;';
  const guildCheck = document.createElement('input');
  guildCheck.type = 'checkbox';
  guildWrap.appendChild(guildCheck);
  guildWrap.appendChild(document.createTextNode(' 公会资金'));
  body.el.appendChild(guildWrap);

  // ---- 弹窗层 (ItemAmountDialog / ConfirmDialog / ConsignItemDialog 的 Web 承载) ----
  const modalLayer = document.createElement('div');
  modalLayer.style.cssText = 'position:absolute;inset:0;z-index:50;display:none;';
  body.el.appendChild(modalLayer);
  const openModal = () => { modalLayer.style.display = ''; modalLayer.replaceChildren(); return modalLayer; };
  const closeModal = () => { modalLayer.style.display = 'none'; modalLayer.replaceChildren(); popupOpen = false; };
  let popupOpen = false;

  // 数量+确认两段弹窗 (BuySelected :462-474 / RemoveSelected :510-518)
  function amountConfirm(title, max, summary, onConfirm) {
    const layer = openModal();
    const box = document.createElement('div');
    box.style.cssText = BOX_CSS;
    const t = document.createElement('div');
    t.textContent = title;
    t.style.color = '#ffd54f';
    const row = document.createElement('div');
    const inp = document.createElement('input');
    inp.type = 'number'; inp.value = '1'; inp.min = '1'; inp.max = String(max);
    inp.style.cssText = INPUT_CSS + 'width:70px;';
    const cnt = document.createElement('span');
    cnt.textContent = ` / ${max}`;
    const sum = document.createElement('div');
    sum.style.cssText = 'color:#9cf;white-space:pre-line;';
    const upd = () => {
      const c = Math.max(1, Math.min(max, parseInt(inp.value || '1', 10) || 1));
      sum.textContent = summary(c);
    };
    inp.oninput = upd;
    const btns = document.createElement('div');
    const ok = document.createElement('button');
    ok.textContent = '确认';
    ok.style.cssText = MBTN_CSS;
    ok.onclick = () => {
      const c = parseInt(inp.value, 10);
      if (!(c >= 1 && c <= max)) return;
      closeModal(); onConfirm(c);
    };
    const cancel = document.createElement('button');
    cancel.textContent = '取消';
    cancel.style.cssText = MBTN_CSS.replace('#2a4', '#444').replace('#7d7', '#888');
    cancel.onclick = closeModal;
    row.appendChild(inp); row.appendChild(cnt);
    btns.appendChild(ok); btns.appendChild(cancel);
    box.appendChild(t); box.appendChild(row); box.appendChild(sum); box.appendChild(btns);
    layer.appendChild(box);
    upd();
  }

  // 寄售弹窗 (ConsignItemDialog :531-589: 1x1 物品格+单价+±5000+确认)
  function openConsignPopup() {
    if (popupOpen) return;   // :260 已开则聚焦
    popupOpen = true;
    const layer = openModal();
    const box = document.createElement('div');
    box.style.cssText = BOX_CSS + 'min-width:290px;';
    const t = document.createElement('div');
    t.textContent = '寄售物品';
    t.style.cssText = 'color:#ffd54f;text-align:center;';
    let sel = null;   // { gridType, slot, item }
    const nameLbl = document.createElement('div');   // _itemName (:553)
    nameLbl.style.cssText = 'color:#9cf;min-height:18px;';
    const list = document.createElement('div');   // 1x1 linked grid 的 Web 等价: 背包列表点击=拖入
    list.style.cssText = 'max-height:110px;overflow-y:auto;border:1px solid #345;margin:4px 0;';
    const renderList = async () => {
      list.replaceChildren();
      const inv = store.items(GRID.INVENTORY);   // GRID.INVENTORY=1 (net.js:204)
      const entries = [...inv.entries()].filter(([, it]) => it).sort((a, b) => a[0] - b[0]);
      if (!entries.length) list.textContent = '（背包为空）';
      for (const [slot, it] of entries) {
        const nm = await itemName(it.infoIndex);
        const d = document.createElement('div');
        d.textContent = `· ${nm} x${it.count ?? 1}`;
        d.style.cssText = ROW_CSS + (sel?.slot === slot ? SEL_CSS : '');
        d.onclick = () => {   // ItemChanged → _itemName (:566)
          sel = { gridType: GRID.INVENTORY, slot, item: it };
          nameLbl.textContent = nm;
          renderList();
        };
        list.appendChild(d);
      }
    };
    const priceRow = document.createElement('div');
    priceRow.appendChild(document.createTextNode('单价: '));
    const priceInp = document.createElement('input');   // _price (:556)
    priceInp.type = 'text'; priceInp.value = '1000';
    priceInp.style.cssText = INPUT_CSS + 'width:110px;';
    priceRow.appendChild(priceInp);
    const plus = document.createElement('button');   // :558-559
    plus.textContent = '+5000';
    plus.style.cssText = MBTN_CSS + 'padding:1px 6px;margin:0 2px;';
    plus.onclick = () => { priceInp.value = String((parsePrice()) + 5000); };
    const minus = document.createElement('button');   // :560-561
    minus.textContent = '-5000';
    minus.style.cssText = plus.style.cssText;
    minus.onclick = () => { priceInp.value = String(Math.max(0, parsePrice() - 5000)); };
    const parsePrice = () => { const v = parseInt(priceInp.value.trim(), 10); return Number.isFinite(v) && v > 0 ? v : 0; };   // ParsePrice :569
    priceRow.appendChild(plus); priceRow.appendChild(minus);
    const btns = document.createElement('div');
    const ok = document.createElement('button');
    ok.textContent = '确认';
    ok.style.cssText = MBTN_CSS;
    ok.onclick = () => confirmConsign();   // Confirm() :571
    const cancel = document.createElement('button');
    cancel.textContent = '取消';
    cancel.style.cssText = MBTN_CSS.replace('#2a4', '#444').replace('#7d7', '#888');
    cancel.onclick = closeModal;
    btns.appendChild(ok); btns.appendChild(cancel);
    box.appendChild(t); box.appendChild(list); box.appendChild(nameLbl);
    box.appendChild(priceRow); box.appendChild(btns);
    layer.appendChild(box);
    renderList();

    function confirmConsign() {
      if (!sel) { scene.addChat('错误：未选择物品。', 'system'); return; }   // :575
      const price = parsePrice();
      if (price <= 0) { scene.addChat('错误：价格无效。', 'system'); return; }   // :580
      const fee = 0;   // Globals.MarketPlaceFee = 0 (Globals.cs:109)
      // ConfirmDialog 二次确认 (:585)
      const layer2 = openModal();
      const box2 = document.createElement('div');
      box2.style.cssText = BOX_CSS;
      box2.textContent = `寄售 ${nameLbl.textContent} x${sel.item.count ?? 1}，单价 ${price.toLocaleString()}，手续费 ${fee.toLocaleString()}？`;
      const btns2 = document.createElement('div');
      const ok2 = document.createElement('button');
      ok2.textContent = '确认';
      ok2.style.cssText = MBTN_CSS;
      ok2.onclick = () => {
        closeModal();
        const gf = guildCheck.checked;
        conn.sendMarketPlaceConsign({ gridType: sel.gridType, slot: sel.slot, count: sel.item.count ?? 1 }, price, '', gf);   // SendMarketConsign :266
        store.lock(sel.gridType, sel.slot);   // source.Locked = true (:268)
        pendingConsignLink = { gridType: sel.gridType, slot: sel.slot };   // (:270) 待 S 库存回包解锁
        guildCheck.checked = false;
      };
      const cancel2 = document.createElement('button');
      cancel2.textContent = '取消';
      cancel2.style.cssText = MBTN_CSS.replace('#2a4', '#444').replace('#7d7', '#888');
      cancel2.onclick = closeModal;
      btns2.appendChild(ok2); btns2.appendChild(cancel2);
      box2.appendChild(btns2);
      layer2.appendChild(box2);
    }
  }

  // ---- 购买 (BuySelected :456-475) ----
  async function buySelected() {
    const info = results[selectedSearch];
    if (!info?.item) return;
    const nm = await itemName(info.item.infoIndex);
    amountConfirm(`购买 ${nm}`, Math.max(1, info.item.count ?? 1),
      c => `单价: ${info.price.toLocaleString()}\n总价: ${(c * info.price).toLocaleString()}`,
      c => {
        btnBuy.enabled = false;   // :468 防重复
        const gf = guildCheck.checked;
        guildCheck.checked = false;   // :470
        conn.sendMarketPlaceBuy(info.index, c, gf);
      });
  }

  // ---- 下架 (RemoveSelected :504-520) ----
  async function removeSelected() {
    const info = mine[selectedConsign];
    if (!info?.item) return;
    const nm = await itemName(info.item.infoIndex);
    amountConfirm(`下架 ${nm}`, Math.max(1, info.item.count ?? 1),
      c => `确定下架 x${c}？`,
      c => conn.sendMarketPlaceCancelConsign(info.index, c));
  }

  // ---- 成交记录 (ShowHistory :497-502 → MarketHistoryDialog.cs ShowFor :37-50) ----
  let histItemIndex = -1, histDisplay = 0;
  async function showHistory() {
    const info = results[selectedSearch];
    if (!info?.item) return;   // :499 未选中直接 return
    histItemIndex = info.item.infoIndex;
    histDisplay++;   // _display++ (Apply 防串扰 :53)
    const layer = openModal();
    const box = document.createElement('div');
    box.style.cssText = BOX_CSS + 'min-width:220px;';
    const nm = await itemName(histItemIndex);
    const mk = (label, val) => {
      const d = document.createElement('div');
      d.textContent = val == null ? label : `${label} ${val}`;
      if (val != null) d.style.color = '#9cf';
      return d;
    };
    box.appendChild(mk(nm));
    const sales = mk('查询销量中…'); box.appendChild(sales);
    const last = mk(''); box.appendChild(last);
    const avg = mk(''); box.appendChild(avg);
    const closeB = document.createElement('button');
    closeB.textContent = '关闭';
    closeB.style.cssText = MBTN_CSS.replace('#2a4', '#444').replace('#7d7', '#888');
    closeB.onclick = closeModal;
    box.appendChild(closeB);
    layer.appendChild(box);
    histRefs = { sales, last, avg };
    conn.sendMarketPlaceHistory(histItemIndex, histDisplay, 0);   // SendMarketHistory (:50; PartIndex=AddedStats 物品部件, web 无 AddedStats → 0)
  }
  let histRefs = null;
  conn.addEventListener('marketPlaceHistory', (e) => {   // Apply :52-57: index+display 双门闩
    const d = e.detail;
    if (!histRefs || d.index !== histItemIndex || d.display !== histDisplay) return;
    histRefs.sales.textContent = `销量: ${d.saleCount}`;
    histRefs.last.textContent = `最近成交: ${Number(d.lastPrice).toLocaleString()}`;
    histRefs.avg.textContent = `平均价: ${Number(d.averagePrice).toLocaleString()}`;
  });

  // ---- 行渲染 (行点击=选中 :选中态高亮, 底部按钮启用) ----
  const rowEl = (text, onClick) => {
    const d = document.createElement('div');
    d.textContent = text;
    d.style.cssText = ROW_CSS;
    if (onClick) d.onclick = onClick;
    return d;
  };

  let results = [];      // ApplySearch 语义: 前段实数据 + null 占位到 count (索引即服务端 index, 不可压缩 :337-339)
  let mine = [];         // MarketPlaceConsign.consignments
  const requestedSearchIndexes = new Set();   // _requestedSearchIndexes (:43) — 每索引只请求一次
  let selectedSearch = -1;
  let selectedConsign = -1;
  let pendingConsignLink = null;   // _pendingConsignLink (:270)

  const render = async () => {
    searchBox.style.display = page === 'search' ? '' : 'none';
    mineBox.style.display = page === 'mine' ? '' : 'none';
    nameInput.el.style.display = page === 'search' ? '' : 'none';
    btnSearch.el.style.display = page === 'search' ? '' : 'none';
    searchCount.el.style.display = page === 'search' ? '' : 'none';
    btnBuy.el.style.display = page === 'search' ? '' : 'none';
    btnHistory.el.style.display = page === 'search' ? '' : 'none';
    btnRemove.el.style.display = page === 'mine' ? '' : 'none';
    btnConsign.el.style.display = page === 'mine' ? '' : 'none';
    guildCheck.disabled = !store.guild;   // :132/:164 Enabled = HasGuild
    searchBox.replaceChildren();
    if (page === 'search') {
      searchCount.text = results.length ? `${results.length} 件在售` : '输入名字搜索';
      for (let i = 0; i < results.length; i++) {
        const r0 = results[i];
        if (!r0 || !r0.item) {   // null 槽或售罄 item=null (:445 加载中标签); 仅纯 null 槽请求 (:451 条件 info==null)
          const d = rowEl('加载中…');
          if (!r0 && !requestedSearchIndexes.has(i)) {
            requestedSearchIndexes.add(i);
            conn.sendMarketPlaceSearchIndex(i);
          }
          searchBox.appendChild(d);
          continue;
        }
        const nm = r0.item ? await itemName(r0.item.infoIndex) : '?';
        // :446 name xcount price 金币 seller \n message
        const d = rowEl(`${nm} x${r0.item?.count ?? 1}  ${r0.price.toLocaleString()} 金币  ${r0.seller ?? '未知'}${r0.message ? '\n' + r0.message : ''}`);
        d.style.whiteSpace = 'pre-line';
        if (i === selectedSearch) d.style.cssText += SEL_CSS;
        d.onclick = () => { selectedSearch = i; btnBuy.enabled = true; btnHistory.enabled = true; render(); };   // 选中 → Buy/History 启用 (:126/:129)
        searchBox.appendChild(d);
      }
    }
    mineBox.replaceChildren();
    if (page === 'mine') {
      for (let i = 0; i < mine.length; i++) {
        const c = mine[i];
        const nm = c.item ? await itemName(c.item.infoIndex) : '?';
        const dt = c.consignDate ? new Date(c.consignDate / 10000 - 62135596800000).toLocaleDateString() : '';
        const d = rowEl(`${nm} x${c.item?.count ?? 1}  ${c.price.toLocaleString()} 金币  ${dt}`);   // :447 Lang 格式含 ConsignDate
        d.onclick = () => { selectedConsign = i; btnRemove.enabled = true; render(); };   // 选中 → Remove 启用 (:161)
        mineBox.appendChild(d);
      }
      if (!mine.length) mineBox.textContent = '无寄售记录';
    }
  };

  // ---- S 包 ----
  conn.addEventListener('marketPlaceSearch', (e) => {   // ApplySearch :334-346
    results = (e.detail?.results ?? []).slice();
    while (results.length < (e.detail?.count ?? 0)) results.push(null);
    requestedSearchIndexes.clear();
    selectedSearch = -1; btnBuy.enabled = false; btnHistory.enabled = false;
    render();
  });
  conn.addEventListener('marketPlaceSearchCount', (e) => {   // ApplySearchCount :348-356
    const count = e.detail?.count ?? 0;
    while (results.length < count) results.push(null);
    if (results.length > count) results.length = count;
    selectedSearch = -1; btnBuy.enabled = false; btnHistory.enabled = false;
    searchCount.text = `共 ${count} 件`;
    render();
  });
  conn.addEventListener('marketPlaceSearchIndex', (e) => {   // ApplySearchIndex :358-366
    const { index, result } = e.detail ?? {};
    if (!(index >= 0)) return;
    while (results.length <= index) results.push(null);
    results[index] = result;
    selectedSearch = -1; btnBuy.enabled = false; btnHistory.enabled = false;
    render();
  });
  conn.addEventListener('marketPlaceConsign', (e) => {   // AddConsignments :368-382: 按 Index 合并 (登录全量/寄售单条增量共用)
    const items = (e.detail?.consignments ?? []).filter(Boolean);
    for (const info of items) {
      const i = mine.findIndex(x => x?.index === info.index);
      if (i >= 0) mine[i] = info; else mine.push(info);
    }
    selectedConsign = -1; btnRemove.enabled = false;
    if (pendingConsignLink) {   // 库存回包 → 解锁来源格 (寄售确认锁的解除)
      store.unlockPublic(pendingConsignLink.gridType, pendingConsignLink.slot);
      pendingConsignLink = null;
    }
    render();
  });
  conn.addEventListener('marketPlaceConsignChanged', (e) => {   // ApplyConsignChanged :385-394
    const { index, count } = e.detail ?? {};
    const item = mine.find(x => x?.index === index);
    if (!item) return;
    if (!(count > 0)) mine = mine.filter(x => x !== item); else item.item.count = Number(count);
    selectedConsign = -1; btnRemove.enabled = false;
    render();
  });
  conn.addEventListener('marketPlaceBuy', (e) => {   // ApplyBuy :396-411
    const { index, count, success } = e.detail ?? {};
    if (!success) {
      btnBuy.enabled = selectedSearch >= 0 && selectedSearch < results.length && !!results[selectedSearch]?.item;
      return;
    }
    const item = results.find(x => x?.index === index);
    if (!item) return;
    if (!(count > 0)) item.item = null; else item.item.count = Number(count);   // 售罄保留空槽不移位 (:405-407)
    selectedSearch = -1; btnBuy.enabled = false;
    render();
  });

  renderTabs();
  render();
  shared = { win, open: () => WindowManager.open(win, scene.hudLayer), refresh: render };
  return shared;
}

export function consignDialog() { return shared; }
