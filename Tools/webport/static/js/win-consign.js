// win-consign.js — ConsignmentDialog (寄售/摆摊, ConsignmentDialog.cs) P2 长尾
// 入口: NPC 页面 DialogType=Consignment → GameScene.OpenConsignmentDialog (NPCDialog.cs:116)。
// 两页: 搜索购买 (MarketPlaceSearch/Buy) + 我的寄售 (MarketPlaceConsign 列表/CancelConsign/Consign)。
// 服务器全是原版 MarketPlace* 包, 不在客户端伪造结果 (铁律)。
import { DXControl, DXLabel, DXButton, DXTextInput } from './dx.js';
import { DXWindow, WindowManager } from './windows.js';
import { GameDB } from './gamedb.js';

const itemName = async (infoIndex) => {
  const info = await GameDB.itemInfo(infoIndex);
  return info ? (info.zh && info.zh !== info.name ? info.zh : info.name) : `物品#${infoIndex}`;
};

let shared = null;   // 单例 (GameScene _consignmentDialog 语义)

export async function winConsign(scene) {
  if (shared) { WindowManager.open(shared.win, scene.hudLayer); return shared; }

  const conn = scene.conn;
  const win = new DXWindow({ title: '寄售行', size: [420, 330] });
  const body = new DXControl({ location: [8, 26], size: [404, 296], isControl: false });
  win.addControl(body);

  // ---- 页切换 ----
  let page = 'search';
  const tabs = [];
  const mkTab = (label, name) => {
    const b = new DXButton({ text: label, fontSize: 9, library: 'Interface', index: -1,
      location: [8 + tabs.length * 90, 0], size: [84, 22],
      onClick: () => { page = name; renderTabs(); render(); } });
    tabs.push({ b, name });
    body.addControl(b);
  };
  mkTab('搜索购买', 'search');
  mkTab('我的寄售', 'mine');
  const renderTabs = () => { for (const t of tabs) t.b.el.style.opacity = t.name === page ? '1' : '.55'; };

  // ---- 搜索页 ----
  const searchBox = document.createElement('div');
  searchBox.style.cssText = 'position:absolute;top:28px;left:0;right:0;bottom:30px;overflow-y:auto;';
  body.el.appendChild(searchBox);
  const nameInput = new DXTextInput({ location: [8, 28], size: [200, 20], fontSize: 9 });
  const btnSearch = new DXButton({ text: '搜索', fontSize: 9, library: 'Interface', index: -1,
    location: [216, 28], size: [60, 20], onClick: () => conn.sendMarketPlaceSearch(nameInput.text ?? '', false, 0, 0) });
  body.addControl(nameInput); body.addControl(btnSearch);
  const searchCount = new DXLabel({ text: '', fontSize: 9, textColour: [255, 213, 115, 255], location: [284, 28], size: [120, 18], isControl: false });
  body.addControl(searchCount);

  // ---- 我的寄售页 ----
  const mineBox = document.createElement('div');
  mineBox.style.cssText = 'position:absolute;top:28px;left:0;right:0;bottom:56px;overflow-y:auto;display:none;';
  body.el.appendChild(mineBox);
  const btnConsign = new DXButton({ text: '寄售背包物品', fontSize: 9, library: 'Interface', index: -1,
    location: [8, 276], size: [120, 20], visible: false,
    onClick: async () => {
      // 从背包第一格物品寄售 (Web 子集: 全格子 UI 属 P3; 这里 prompt 价格)
      const inv = [...(scene.itemStore?.grids?.get(0)?.values?.() ?? [])].filter(Boolean);
      const it = inv[0];
      if (!it) { scene.addChat('背包为空, 无法寄售', 'hint'); return; }
      const nm = await itemName(it.infoIndex);
      const price = prompt(`寄售 ${nm} 的单价:`, '1000');
      if (!price || !(parseInt(price, 10) > 0)) return;
      conn.sendMarketPlaceConsign({ gridType: 0, slot: it.slot, count: it.count ?? 1 }, parseInt(price, 10), '');   // cellLink: GridType+Slot+Count
    } });
  body.addControl(btnConsign);

  const consignCount = new DXLabel({ text: '', fontSize: 9, textColour: [255, 213, 115, 255], location: [132, 278], size: [200, 16], isControl: false, visible: false });
  body.addControl(consignCount);

  // ---- 行渲染 ----
  const rowEl = (text, onClick, onRc) => {
    const d = document.createElement('div');
    d.textContent = text;
    d.style.cssText = 'padding:2px 6px;font:12px/1.7 \'Noto Sans CJK SC\',sans-serif;color:#eee;text-shadow:1px 1px 0 #000;cursor:pointer;';
    if (onClick) d.onclick = onClick;
    if (onRc) d.oncontextmenu = (ev) => { ev.preventDefault(); onRc(); };
    return d;
  };

  let results = [];      // MarketPlaceSearch.results
  let mine = [];         // MarketPlaceConsign.consignments

  const render = async () => {
    searchBox.style.display = page === 'search' ? '' : 'none';
    mineBox.style.display = page === 'mine' ? '' : 'none';
    nameInput.el.style.display = page === 'search' ? '' : 'none';
    btnSearch.el.style.display = page === 'search' ? '' : 'none';
    searchCount.el.style.display = page === 'search' ? '' : 'none';
    btnConsign.el.style.display = page === 'mine' ? '' : 'none';
    consignCount.el.style.display = page === 'mine' ? '' : 'none';

    searchBox.replaceChildren();
    if (page === 'search') {
      searchCount.text = results.length ? `${results.length} 件在售` : '输入名字搜索';
      for (const r0 of results) {
        const nm = r0.item ? await itemName(r0.item.infoIndex) : '?';
        searchBox.appendChild(rowEl(
          `${nm} x${r0.item?.count ?? 1}  ${r0.price.toLocaleString()} 金`,
          () => {
            const cnt = prompt(`购买几个 ${nm}?`, '1');
            if (cnt && parseInt(cnt, 10) > 0) conn.sendMarketPlaceBuy(r0.index, parseInt(cnt, 10), false);
          }));
      }
    }
    mineBox.replaceChildren();
    if (page === 'mine') {
      consignCount.text = mine.length ? `我的寄售 ${mine.length} 件` : '无寄售记录';
      for (const c of mine) {
        const nm = c.item ? await itemName(c.item.infoIndex) : '?';
        mineBox.appendChild(rowEl(
          `${nm} x${c.item?.count ?? 1}  ${c.price.toLocaleString()} 金  (右键下架)`,
          null,
          () => { conn.sendMarketPlaceCancelConsign(c.index, c.item?.count ?? 1); }));
      }
    }
  };

  // ---- S 包 ----
  conn.addEventListener('marketPlaceSearch', (e) => { results = e.detail?.results ?? []; render(); });
  conn.addEventListener('marketPlaceSearchCount', (e) => { searchCount.text = `共 ${e.detail?.count ?? 0} 件`; });
  conn.addEventListener('marketPlaceConsign', (e) => { mine = e.detail?.consignments ?? []; render(); });

  renderTabs();
  render();
  shared = { win, open: () => WindowManager.open(win, scene.hudLayer), refresh: render };
  return shared;
}

export function consignDialog() { return shared; }
