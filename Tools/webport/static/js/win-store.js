// win-store.js — GameStoreDialog (GameStoreDialog.cs :12-468) 商城
// 布局: 800×515, 左分类树 (Filter 标签+类型), 右 2 列商品 10/页, 右侧热销 Top5, 底翻页。
// 排序 4 态 (MarketPlaceStoreSort) / 搜索 / 数量 1-10 / 买 (确认弹窗) / 赠送 / 收藏 (S 回包确认)。
// 数据: /res/data/store.json (webres StoreInfo 快照) + S.GameStoreData favourites/topItems。
import { DXControl, DXLabel, DXButton } from './dx.js';
import { DXWindow, WindowManager } from './windows.js';
import { confirmDialog } from './dxgrid.js';
import { ItemStore } from './itemstore.js';

const CSS_LBL = "font:11px 'Noto Sans CJK SC',sans-serif;color:rgb(255,217,115);text-shadow:1px 1px 0 #000;";
const CSS_TXT = "font:9px 'Noto Sans CJK SC',sans-serif;color:#fff;text-shadow:1px 1px 0 #000;";

// 分类判定 (:285-287)
const EQUIP = new Set(['Weapon', 'Armour', 'Torch', 'Helmet', 'Necklace', 'Bracelet', 'Ring', 'Shoes', 'Amulet', 'HorseArmour', 'ItemPart', 'Emblem', 'Shield']);
const CONS = new Set(['Consumable', 'Poison', 'Meat', 'Book', 'Scroll', 'DarkStone', 'RefineSpecial', 'Flower', 'CompanionFood', 'Bait', 'Currency', 'Bundle', 'LootBox']);
const COSM = new Set(['Costume', 'CompanionHead', 'CompanionBack']);

let shared = null;

export async function winStore(scene, itemStore, reg) {
  if (shared) { WindowManager.open(shared.win, scene.hudLayer); return shared; }
  const conn = scene.conn;
  const store = itemStore ?? scene.itemStore;

  const win = new DXWindow({ title: '商城', hasTitle: false, size: [800, 515] });

  let rows = [];                 // StoreInfo 快照
  let favourites = new Set();    // S.GameStoreData / GameStoreFavouriteChanged
  let topItems = [];
  let sortMode = 0;              // 0 Alphabetical / 1 Highest / 2 Lowest / 3 Favourite (MarketPlaceStoreSort)
  let category = 'All';          // GameStoreCategory
  let itemTypeFilter = null;
  let storeFilter = null;
  let requiresStoreFilter = false;
  let useHuntGold = false;
  let pageIndex = 0;
  let itemTypes = [];            // items.json type (快照侧 ItemType)

  try { rows = (await (await fetch('/res/data/store.json')).json()) ?? []; } catch { rows = []; }
  itemTypes = new Map(rows.map(r => [r.item, r.type ?? null]));
  const zhName = (r) => ItemStore.itemZh(r.item) || r.name;

  // ---- 顶栏: 标题/排序/搜索 (:51/:70-98) ----
  const title = new DXLabel({ text: '商城', fontSize: 10, location: [0, 8], size: [800, 18] }); win.addControl(title);
  const sortLbl = new DXLabel({ text: '排序:', fontSize: 9, location: [225, 44] }); win.addControl(sortLbl);
  const SORT_NAMES = ['名称', '价格从高到低', '价格从低到高', '收藏'];
  const sortBtn = new DXButton({ text: SORT_NAMES[0], fontSize: 9, location: [270, 39], size: [108, 25] });
  let sortMenu = null;
  sortBtn.onClick = () => {
    if (!sortMenu) {
      sortMenu = new DXControl({ location: [270, 64], size: [108, 80], border: true, visible: false });
      SORT_NAMES.forEach((n, i) => {
        const b = new DXButton({ text: n, fontSize: 9, location: [1, 1 + i * 19], size: [106, 19], onClick: () => {
          sortMode = i; sortBtn.el.textContent = n; sortMenu.visible = false; pageIndex = 0; refresh();
        } });
        sortMenu.addControl(b);
      });
      win.addControl(sortMenu);
    }
    sortMenu.visible = !sortMenu.visible;
  };
  win.addControl(sortBtn);
  const search = document.createElement('input');
  search.type = 'text';
  search.placeholder = '搜索商品';
  search.style.cssText = 'position:absolute;left:385px;top:39px;width:132px;height:20px;background:#111;color:#fff;border:1px solid #567;';
  win.el.appendChild(search);
  const searchBtn = new DXButton({ text: '搜索', fontSize: 10, location: [530, 38], size: [68, 25],
    onClick: () => { pageIndex = 0; refresh(); } });
  win.addControl(searchBtn);

  // ---- 左: 分类树 (:53-68 + BuildCategoryTree :200-250) ----
  const catPanel = new DXControl({ location: [10, 38], size: [170, 305], clip: true });
  const catContent = new DXControl({ size: [168, 305] });
  catPanel.addControl(catContent);
  win.addControl(catPanel);
  const catLbl = new DXLabel({ text: '分类', fontSize: 9, location: [10, 354], size: [172, 20] }); win.addControl(catLbl);
  const currencyLbl = new DXLabel({ text: '', fontSize: 10, location: [14, 375], size: [164, 18] }); win.addControl(currencyLbl);
  const rechargeBtn = new DXButton({ text: '充值', fontSize: 10, location: [10, 410], size: [172, 27],
    onClick: () => scene.addChat?.('充值页面暂不可用 (OpenRechargePage)', 'system') });
  win.addControl(rechargeBtn);
  const currencyBtn = new DXButton({ text: '切换货币', fontSize: 10, location: [10, 438], size: [172, 27],
    onClick: () => { useHuntGold = !useHuntGold; buildCategoryTree(); refresh(); } });
  win.addControl(currencyBtn);

  // ---- 中: 商品列表 (:100) ----
  const list = new DXControl({ location: [199, 67], size: [409, 432], clip: true });
  win.addControl(list);

  // ---- 右: 热销 (:102-104) ----
  const topLbl = new DXLabel({ text: '热销', fontSize: 11, location: [614, 37] }); win.addControl(topLbl);
  const topPanel = new DXControl({ location: [614, 65], size: [174, 425], clip: true });
  win.addControl(topPanel);

  // ---- 底: 翻页 (:105-109) ----
  const prevBtn = new DXButton({ text: '◀', fontSize: 9, location: [321, 477], size: [28, 25],
    onClick: () => { if (pageIndex > 0) { pageIndex--; refresh(); } } });
  win.addControl(prevBtn);
  const pageLbl = new DXLabel({ text: '1 / 1', fontSize: 10, location: [349, 473], size: [106, 20] }); win.addControl(pageLbl);
  const nextBtn = new DXButton({ text: '▶', fontSize: 9, location: [464, 477], size: [28, 25],
    onClick: () => { if (pageIndex + 1 < pageCount()) { pageIndex++; refresh(); } } });
  win.addControl(nextBtn);

  // ---- 逻辑 ----
  const effPrice = (r) => useHuntGold && r.huntGoldPrice > 0 ? r.huntGoldPrice : r.price;   // :272
  const typeOf = (r) => {
    if (r.type) return r.type;
    const info = ItemStore.itemInfo(r.item);
    return info?.type ?? 'Nothing';
  };
  let topSelect = null;   // SelectTopItem :439 的 _storeIndexFilter 等价
  const matchesCategory = (r) => {   // :160-179
    if (topSelect !== null) return r.id === topSelect;
    if (storeFilter !== null) {
      return (r.filter ?? '').split(',').map(s => s.trim()).some(x => x.toLowerCase() === storeFilter.toLowerCase());
    }
    if (requiresStoreFilter) return !!(r.filter ?? '').trim();
    const t = typeOf(r);
    switch (category) {
      case 'Favourites': return favourites.has(r.id);
      case 'NewItems': return newItems().includes(r.id);
      case 'Equipment': return EQUIP.has(t);
      case 'Consumables': return CONS.has(t);
      case 'Cosmetics': return COSM.has(t);
      case 'Other': return !EQUIP.has(t) && !CONS.has(t) && !COSM.has(t);
      default: return true;
    }
  };
  const newItems = () => [...rows].sort((a, b) => b.id - a.id).slice(0, 10).map(r => r.id);
  const sortKey = (r) => {   // :181-190
    switch (sortMode) {
      case 1: return String(2 ** 31 - effPrice(r)).padStart(10, '0');
      case 2: return String(effPrice(r)).padStart(10, '0');
      case 3: return `${favourites.has(r.id) ? 0 : 1}:${zhName(r)}`;
      default: return zhName(r);
    }
  };
  const filtered = () => rows.filter(r => r.available !== false && effPrice(r) > 0)
    .filter(matchesCategory)
    .filter(r => !search.value.trim() || zhName(r).toLowerCase().includes(search.value.trim().toLowerCase()) || r.name.toLowerCase().includes(search.value.trim().toLowerCase()))
    .sort((a, b) => sortKey(a) < sortKey(b) ? -1 : sortKey(a) > sortKey(b) ? 1 : 0);
  const pageCount = () => Math.max(1, Math.ceil(filtered().length / 10));

  function setFilter(cat, itemType = null, filter = null, requiresFilter = false) {   // :263
    category = cat; itemTypeFilter = itemType; storeFilter = filter; requiresStoreFilter = requiresFilter;
    topSelect = null;
  }

  function buildCategoryTree() {   // :200-250
    catContent.el.replaceChildren();
    let y = 0;
    const add = (text, action, indent = 0) => {
      const b = new DXButton({ text: `${'  '.repeat(indent)}${text}`, fontSize: 9, location: [0, y], size: [168, 20],
        onClick: () => { action(); pageIndex = 0; refresh(); } });
      catContent.addControl(b);
      y += 21;
    };
    if (favourites.size > 0) add('收藏', () => setFilter('Favourites'));
    const filters = [...new Set(rows.flatMap(r => (r.filter ?? '').split(',').map(s => s.trim()).filter(Boolean)))].sort((a, b) => a.localeCompare(b));
    for (const f of filters) add(f, () => setFilter('All', null, f, true), 1);
    if (rows.length) add('新商品', () => setFilter('NewItems'));
    add('全部', () => setFilter('All'));
    add('装备', () => setFilter('Equipment'));
    addTypeFilters(EQUIP, add);
    add('消耗品', () => setFilter('Consumables'));
    addTypeFilters(CONS, add);
    add('外观', () => setFilter('Cosmetics'));
    addTypeFilters(COSM, add);
    add('其他', () => setFilter('Other'));
    catContent.size = [168, Math.max(305, y)];
  }
  function addTypeFilters(set, add) {   // :252-261
    const types = [...new Set(rows.map(typeOf).filter(t => set.has(t)))].sort();
    for (const t of types) add(t, () => setFilter('All', t), 1);
  }

  function createRow(r, rowIndex) {   // :289-384
    const row = new DXControl({ location: [(rowIndex % 2) * 202, Math.floor(rowIndex / 2) * 80], size: [200, 78] });
    const cell = document.createElement('div');   // 物品图标格 (:306)
    cell.style.cssText = 'position:absolute;left:19px;top:18px;width:36px;height:36px;background:rgba(0,0,0,.3);border:1px solid #456;display:flex;align-items:center;justify-content:center;';
    const nm = zhName(r);
    cell.title = nm;
    cell.textContent = nm.slice(0, 2);
    row.el.appendChild(cell);
    const nameLbl = new DXLabel({ text: nm, fontSize: 9, location: [65, 8], size: [128, 17] }); row.addControl(nameLbl);
    const priceLbl = new DXLabel({ text: r.available === false ? 'Unavailable' : effPrice(r).toLocaleString(),
      fontSize: 9, location: [7, 59], size: [58, 16] }); row.addControl(priceLbl);
    let quantityValue = 1;
    const quantity = new DXButton({ text: '1', fontSize: 8, location: [72, 30], size: [117, 20] });
    row.addControl(quantity);
    const buy = new DXButton({ text: '购买', fontSize: 8, location: [83, 51], size: [30, 22],
      onClick: () => {   // :316-324
        if (r.available === false) return;
        const total = effPrice(r) * quantityValue;
        const cur = useHuntGold ? '狩猎金币' : '元宝';
        confirmDialog(`购买 ${nm} ×${quantityValue}, 单价 ${effPrice(r).toLocaleString()} ${cur}, 合计 ${total.toLocaleString()} ${cur}?`, '购买确认', () => {
          conn.sendGameStoreBuy(r.id, quantityValue, useHuntGold);
        });
      } });
    row.addControl(buy);
    const gift = new DXButton({ text: '赠送', fontSize: 8, location: [116, 51], size: [30, 22],
      onClick: () => {   // :326-333 CanAttemptGift :452
        if (quantityValue < 1 || quantityValue > 10) return;
        const rec = prompt('赠送对象角色名:');
        if (rec && rec.trim()) conn.sendGameStoreGift(r.id, quantityValue, useHuntGold, rec.trim());
      } });
    row.addControl(gift);
    const fav = new DXButton({ text: favourites.has(r.id) ? '★' : '☆', fontSize: 9, location: [151, 51], size: [24, 22],
      onClick: () => conn.sendGameStoreFavouriteToggle(r.id) });   // :341 只发请求, S 回包驱动 UI
    row.addControl(fav);
    // 数量下拉 1-10 (:344-382)
    const quantityMenu = new DXControl({ location: [72, 10], size: [117, 190], border: true, visible: false });
    for (let v = 1; v <= 10; v++) {
      const option = new DXButton({ text: String(v), fontSize: 8, location: [1, 1 + (v - 1) * 18], size: [115, 18],
        onClick: () => { quantityValue = v; quantity.el.textContent = String(v); quantityMenu.visible = false; } });
      quantityMenu.addControl(option);
    }
    quantity.onClick = () => { quantityMenu.visible = !quantityMenu.visible; };
    row.addControl(quantityMenu);
    return row;
  }

  function refresh() {   // :116-158
    const items = filtered();
    pageIndex = Math.min(pageIndex, pageCount() - 1);
    list.el.replaceChildren();
    for (let i = 0; i < 10; i++) {
      const idx = pageIndex * 10 + i;
      if (idx >= items.length) break;
      list.addControl(createRow(items[idx], i));
    }
    pageLbl.el.textContent = `${pageIndex + 1} / ${pageCount()}`;
    prevBtn.enabled = pageIndex > 0;
    nextBtn.enabled = pageIndex < pageCount() - 1;
    const amount = useHuntGold ? Number(store.gameGold?.() ?? 0) : Number(store.gameGold?.() ?? 0);   // HuntGold=type2 / GameGold=type1 (:154-156)
    currencyLbl.el.textContent = `${useHuntGold ? '狩猎金币' : '元宝'}: ${amount.toLocaleString()}`;
  }

  function refreshTop() {   // SetTopItems :401-437
    topPanel.el.replaceChildren();
    const infos = topItems.slice(0, 5).map(id => rows.find(r => r.id === id)).filter(Boolean);
    if (!infos.length) {
      topPanel.el.appendChild(Object.assign(document.createElement('div'), { textContent: '暂无热销商品', style: 'position:absolute;left:0;top:5px;width:174px;text-align:center;' + CSS_TXT }));
      return;
    }
    infos.forEach((r, i) => {
      const row = new DXControl({ location: [0, 5 + i * 87], size: [174, i === 4 ? 73 : 78], onClick: () => {   // SelectTopItem :439
        category = 'All'; storeFilter = null; requiresStoreFilter = false; search.value = ''; pageIndex = 0;
        topSelect = r.id; refresh();
      } });
      const rank = document.createElement('div');
      rank.textContent = ['第1名', '第2名', '第3名', '第4名', '第5名'][i];
      rank.style.cssText = 'position:absolute;left:2px;top:2px;' + CSS_TXT;
      row.el.appendChild(rank);
      const cell = document.createElement('div');
      cell.style.cssText = 'position:absolute;left:19px;top:26px;width:36px;height:36px;background:rgba(0,0,0,.3);border:1px solid #456;display:flex;align-items:center;justify-content:center;' + CSS_TXT;
      cell.textContent = zhName(r).slice(0, 2);
      row.el.appendChild(cell);
      const nm = document.createElement('div');
      nm.textContent = zhName(r);
      nm.style.cssText = 'position:absolute;left:60px;top:30px;width:110px;' + CSS_TXT;
      row.el.appendChild(nm);
      topPanel.addControl(row);
    });
  }
  topSelect = null;

  // ---- S 事件 ----
  conn.addEventListener('gameStoreData', (e) => {   // 登录下发
    favourites = new Set((e.detail?.favourites ?? []).filter(Boolean));
    topItems = (e.detail?.topItems ?? []).filter(Boolean);
    buildCategoryTree(); refresh(); refreshTop();
  });
  conn.addEventListener('gameStoreTopItems', (e) => {   // 购买后刷新
    topItems = (e.detail?.items ?? []).filter(Boolean);
    refreshTop();
  });
  conn.addEventListener('gameStoreFavouriteChanged', (e) => {   // :394 收藏由服务端确认
    const { index, favourited } = e.detail ?? {};
    if (favourited) favourites.add(index); else favourites.delete(index);
    buildCategoryTree(); refresh();
  });

  buildCategoryTree();
  refresh();
  refreshTop();
  reg.wins.set('store', win);
  shared = { win, open: () => WindowManager.open(win, scene.hudLayer), refresh, setFavourites: (v) => { favourites = new Set(v); buildCategoryTree(); refresh(); } };
  return shared;
}
