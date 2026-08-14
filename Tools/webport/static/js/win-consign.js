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
  const nameInput = new DXTextInput({ location: [8, 28], size: [200, 20], fontSize: 9 });
  const btnSearch = new DXButton({ text: '搜索', fontSize: 9, library: 'Interface', index: -1,
    location: [216, 28], size: [60, 20], onClick: () => conn.sendMarketPlaceSearch(nameInput.text ?? '', false, 0, 0) });
  body.addControl(nameInput); body.addControl(btnSearch);
  const searchCount = new DXLabel({ text: '', fontSize: 9, textColour: [255, 213, 115, 255], location: [284, 28], size: [120, 18], isControl: false });
  body.addControl(searchCount);

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

  // ---- 行渲染 (行点击=选中 :选中态高亮, 底部按钮启用) ----
  const rowEl = (text, onClick) => {
    const d = document.createElement('div');
    d.textContent = text;
    d.style.cssText = ROW_CSS;
    if (onClick) d.onclick = onClick;
    return d;
  };

  let results = [];      // MarketPlaceSearch.results
  let mine = [];         // MarketPlaceConsign.consignments
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
    btnRemove.el.style.display = page === 'mine' ? '' : 'none';
    btnConsign.el.style.display = page === 'mine' ? '' : 'none';
    guildCheck.disabled = !store.guild;   // :132/:164 Enabled = HasGuild
    searchBox.replaceChildren();
    if (page === 'search') {
      searchCount.text = results.length ? `${results.length} 件在售` : '输入名字搜索';
      for (let i = 0; i < results.length; i++) {
        const r0 = results[i];
        const nm = r0.item ? await itemName(r0.item.infoIndex) : '?';
        const d = rowEl(`${nm} x${r0.item?.count ?? 1}  ${r0.price.toLocaleString()} 金`);
        if (i === selectedSearch) d.style.cssText += SEL_CSS;
        d.onclick = () => { selectedSearch = i; btnBuy.enabled = true; render(); };   // 选中 → Buy 启用 (:126)
        searchBox.appendChild(d);
      }
    }
    mineBox.replaceChildren();
    if (page === 'mine') {
      for (let i = 0; i < mine.length; i++) {
        const c = mine[i];
        const nm = c.item ? await itemName(c.item.infoIndex) : '?';
        const d = rowEl(`${nm} x${c.item?.count ?? 1}  ${c.price.toLocaleString()} 金`);
        d.onclick = () => { selectedConsign = i; btnRemove.enabled = true; render(); };   // 选中 → Remove 启用 (:161)
        mineBox.appendChild(d);
      }
      if (!mine.length) mineBox.textContent = '无寄售记录';
    }
  };

  // ---- S 包 ----
  conn.addEventListener('marketPlaceSearch', (e) => { results = e.detail?.results ?? []; selectedSearch = -1; btnBuy.enabled = false; render(); });
  conn.addEventListener('marketPlaceSearchCount', (e) => { searchCount.text = `共 ${e.detail?.count ?? 0} 件`; });
  conn.addEventListener('marketPlaceConsign', (e) => {
    mine = e.detail?.consignments ?? [];
    selectedConsign = -1; btnRemove.enabled = false;
    if (pendingConsignLink) {   // 库存回包 → 解锁来源格 (寄售确认锁的解除)
      store.unlockPublic(pendingConsignLink.gridType, pendingConsignLink.slot);
      pendingConsignLink = null;
    }
    render();
  });

  renderTabs();
  render();
  shared = { win, open: () => WindowManager.open(win, scene.hudLayer), refresh: render };
  return shared;
}

export function consignDialog() { return shared; }
