// itemstore.js — GameScene 物品/货币/技能/任务状态镜像 (D路 par-win)
// 对照: GameScene.cs FillItems(:6612) FillStorage(:6630) AddItems(:6743) OnItemMove(:6866)
//       OnItemChanged(:7114) OnItemsChanged(:7222) OnItemsGained(:6694) RefreshCurrency(:5425)
// 槽位协议 (Globals.cs:296-302): Inventory 0-47 / Equipment 1000+i / Storage 0-99 / Parts 2000+i
// 每个窗口通过 subscribe(fn) 订阅变更重绘 (Godot 里是 RefreshItemGrids 的职责)。

import { GRID, STAT, C } from './net.js';
import { D } from './data.js';

export const EQUIPMENT_OFF = 1000, PARTS_OFF = 2000;
export const INVENTORY_SIZE = 48, EQUIPMENT_SIZE = 22, STORAGE_SIZE = 100;
export const STAT_BAGWEIGHT = 71, STAT_WEARWEIGHT = 72, STAT_HANDWEIGHT = 73;

const key = (g, s) => g * 10000 + s;

// ---- conn 级登录仓库缓存 (S.Login.Items 在 select 阶段到达, 早于 GameScene) ----
const pendingStorage = new WeakMap();

export function stashLoginItems(conn, items) { pendingStorage.set(conn, items || []); }

export class ItemStore {
  constructor(conn, startInfo, opts = {}) {
    this.conn = conn;
    this.info = startInfo;
    this.chat = opts.chat ?? (() => {});          // (text, 'system'|'hint') 系统消息
    this.sendItemMove = opts.sendItemMove ?? null; // (fromGrid, toGrid, fromSlot, toSlot, merge)

    // GridType → Map(slot → ClientUserItem)
    this.grids = new Map();
    for (const g of [GRID.INVENTORY, GRID.EQUIPMENT, GRID.STORAGE]) this.grids.set(g, new Map());
    this.partsStorage = new Map();                 // PartsStorage (无独立 GridType, 移动时 2000+slot)

    this.locked = new Set();                       // "grid:slot" 提交中锁 (锁定格)
    this.saleSelected = new Set();                 // NPC 出售多选

    this.currencies = [];                          // [{currencyIndex, amount}]
    this.magics = new Map();                       // infoIndex → ClientUserMagic
    this.quests = new Map();                       // index → ClientUserQuest
    this.milestones = startInfo.milestones ?? [];
    this.guild = null;                             // ClientGuildInfo
    this.guildFunds = 0n;
    this.storageSize = Math.max(1, startInfo.storageSize || STORAGE_SIZE);

    this.stats = {};                               // Stat → value (StatsUpdate/StartInfo)
    this.hermitStats = {};
    this.hermitPoints = startInfo.hermitPoints ?? 0;
    this.level = startInfo.level ?? 1;
    this.bagWeight = 0; this.wearWeight = 0; this.handWeight = 0;
    this.hp = startInfo.currentHP ?? 0; this.mp = startInfo.currentMP ?? 0;
    this.observers = new Set();
    this.changeSeq = 0;

    // ---- 初值 (InitHudData GameScene.cs:4927) ----
    this.#fillItems(startInfo.items);
    const pend = pendingStorage.get(conn);
    if (pend) this.#fillStorage(pend);
    for (const m of startInfo.magics ?? []) if (m) this.magics.set(m.infoIndex, m);
    for (const q of startInfo.quests ?? []) if (q) this.quests.set(q.index, q);
    this.currencies = (startInfo.currencies ?? []).filter(Boolean).slice();

    this.#wire();
  }

  on(fn) { this.observers.add(fn); return () => this.observers.delete(fn); }
  #emit(kind) { this.changeSeq++; for (const fn of this.observers) { try { fn(kind); } catch { /* 窗口已关 */ } } }

  // ---- 静态数据 join (items.json) ----
  static itemInfo(infoIndex) { return D().itemsById?.[infoIndex] ?? null; }
  static itemZh(infoIndex) {
    const it = ItemStore.itemInfo(infoIndex);
    return it?.zh && it.zh !== it.name ? it.zh : (it?.name ?? '');
  }

  // ---- 槽位协议 ----
  #fillItems(items) {
    for (const it of items ?? []) {
      if (!it) continue;
      if (it.slot >= EQUIPMENT_OFF) {
        const s = it.slot - EQUIPMENT_OFF;
        if (s >= 0 && s < EQUIPMENT_SIZE) this.grids.get(GRID.EQUIPMENT).set(s, it);
      } else if (it.slot >= 0 && it.slot < INVENTORY_SIZE) {
        this.grids.get(GRID.INVENTORY).set(it.slot, it);
      }
    }
  }

  #fillStorage(items) {
    this.grids.get(GRID.STORAGE).clear();
    this.partsStorage.clear();
    for (const it of items ?? []) {
      if (!it) continue;
      if (it.slot >= PARTS_OFF) this.partsStorage.set(it.slot - PARTS_OFF, it);
      else if (it.slot >= 0 && it.slot < STORAGE_SIZE) this.grids.get(GRID.STORAGE).set(it.slot, it);
    }
  }

  item(g, slot) { return this.grids.get(g)?.get(slot) ?? null; }
  storageItem(slot) { return this.grids.get(GRID.STORAGE).get(slot) ?? null; }
  partItem(slot) { return this.partsStorage.get(slot) ?? null; }
  items(g) { return this.grids.get(g) ?? new Map(); }

  // ---- 货币 ----
  currency(type) {   // type: 0=Gold 1=GameGold (CurrencyType)
    return this.currencies.find(c => c.currencyIndex === type) ?? null;
  }
  gold() { return this.currency(0)?.amount ?? 0n; }
  gameGold() { return this.currency(1)?.amount ?? 0n; }

  // ---- 网络镜像 (GameScene S.* 处理器) ----
  #wire() {
    const c = this.conn;

    c.addEventListener('itemsGained', (e) => this.#onItemsGained(e.detail));      // :6743
    c.addEventListener('itemMove', (e) => this.#onItemMove(e.detail));            // :6866
    c.addEventListener('itemChanged', (e) => this.#onItemChanged(e.detail));      // :7114
    c.addEventListener('itemsChanged', (e) => this.#onItemsChanged(e.detail));    // :7222
    c.addEventListener('itemSort', (e) => this.#onItemSort(e.detail));            // S.ItemSort
    c.addEventListener('itemSplit', (e) => this.#onItemSplit(e.detail));
    c.addEventListener('itemDelete', (e) => this.#onItemDelete(e.detail));
    c.addEventListener('itemDurability', (e) => {
      const it = this.item(e.detail.gridType, e.detail.slot);
      if (it) { it.currentDurability = e.detail.currentDurability; this.#emit('items'); }
    });
    c.addEventListener('itemLock', (e) => {
      const it = this.item(e.detail.grid, e.detail.slot);
      if (it) { it.flags = e.detail.locked ? ((it.flags ?? 0) | 1) : ((it.flags ?? 0) & ~1); this.#emit('items'); }
    });
    c.addEventListener('storageSize', (e) => {
      this.storageSize = Math.max(1, e.detail.size || STORAGE_SIZE);
      this.#emit('storage');
    });
    c.addEventListener('currencyChanged', (e) => {   // OnCurrencyChanged :7294
      const d = e.detail;
      const cur = this.currencies.find(x => x.currencyIndex === d.currencyIndex);
      if (cur) cur.amount = d.amount;
      this.#emit('currency');
    });

    // 状态
    c.addEventListener('statsUpdate', (e) => {       // :5031
      const d = e.detail;
      if (d.stats?.values) for (const [k, v] of d.stats.values) this.stats[k] = v;
      if (d.hermitStats?.values) for (const [k, v] of d.hermitStats.values) this.hermitStats[k] = v;
      if (d.hermitPoints != null) this.hermitPoints = d.hermitPoints;
      this.#emit('stats');
    });
    c.addEventListener('weightUpdate', (e) => {
      this.bagWeight = e.detail.bagWeight; this.wearWeight = e.detail.wearWeight;
      this.handWeight = e.detail.handWeight;
      this.#emit('weight');
    });
    c.addEventListener('healthChanged', (e) => {
      if (!this.info || e.detail.objectID !== this.info.objectID) return;
      if (!e.detail.miss && !e.detail.block) this.hp = Math.max(0, this.hp + e.detail.change);
      this.#emit('hp');
    });
    c.addEventListener('manaChanged', (e) => {
      if (!this.info || e.detail.objectID !== this.info.objectID) return;
      this.mp = Math.max(0, this.mp + e.detail.change);
      this.#emit('mp');
    });
    c.addEventListener('levelChanged', (e) => {
      this.level = e.detail.level;
      this.#emit('level');
    });

    // 技能
    c.addEventListener('newMagic', (e) => {
      const m = e.detail?.magic;
      if (m) { this.magics.set(m.infoIndex, m); this.#emit('magics'); }
    });
    c.addEventListener('magicLeveled', (e) => {
      const m = this.magics.get(e.detail.infoIndex);
      if (m) { m.level = e.detail.level; m.experience = e.detail.experience; this.#emit('magics'); }
    });
    c.addEventListener('magicCooldown', (e) => this.#emit('magicCooldown'));

    // 任务
    c.addEventListener('questChanged', (e) => {
      const q = e.detail?.quest;
      if (q) { this.quests.set(q.index, q); this.#emit('quests'); }
    });
    c.addEventListener('questCancelled', (e) => {
      // index = QuestInfo.Index (ServerPackets QuestCancelled)
      for (const [i, q] of this.quests) if (q.questIndex === e.detail.index) this.quests.delete(i);
      this.#emit('quests');
    });
    c.addEventListener('userMilestones', (e) => {
      this.milestones = e.detail.milestones ?? [];
      this.#emit('milestones');
    });
    c.addEventListener('milestoneEarned', () => this.#emit('milestones'));

    // 行会
    c.addEventListener('guildInfo', (e) => {
      this.guild = e.detail.guild;
      if (this.guild) this.guildFunds = this.guild.guildFunds ?? 0n;
      this.#emit('guild');
    });
    c.addEventListener('guildUpdate', (e) => {   // ApplyGuildUpdate (字段 patch)
      const u = e.detail;
      if (!this.guild && u) {
        this.guild = { members: u.members ?? [], storage: [], notice: '' };
      }
      if (this.guild) {
        for (const k of ['memberLimit', 'storageLimit', 'guildFunds', 'dailyGrowth',
          'totalContribution', 'dailyContribution', 'tax', 'defaultRank', 'defaultPermission',
          'colour', 'flag']) {
          if (u[k] != null) this.guild[k] = u[k];
        }
        if (u.members) this.guild.members = u.members;
      }
      this.#emit('guild');
    });
    c.addEventListener('guildNoticeChanged', (e) => {
      if (this.guild) { this.guild.notice = e.detail.notice; this.#emit('guild'); }
    });
    c.addEventListener('guildMemberOnline', (e) => {
      const m = this.guild?.members?.find(x => x.index === e.detail.index);
      if (m) { m.objectID = e.detail.objectID; m.online = true; this.#emit('guild'); }
    });
    c.addEventListener('guildMemberOffline', (e) => {
      const m = this.guild?.members?.find(x => x.index === e.detail.index);
      if (m) { m.objectID = 0; m.online = false; this.#emit('guild'); }
    });
    c.addEventListener('guildFundsChanged', (e) => {
      this.guildFunds += e.detail.change;
      if (this.guild) this.guild.guildFunds = this.guildFunds;
      this.#emit('guild');
    });
    c.addEventListener('guildNewItem', (e) => {   // ApplyGuildNewItem — 行会仓库存入
      if (!this.guild) this.guild = { members: [], storage: [] };
      this.guild.storage ??= [];
      this.guild.storage[e.detail.slot] = e.detail.item;
      this.#emit('guild');
    });
    c.addEventListener('guildGetItem', (e) => {   // 行会仓库取出
      if (this.guild?.storage) { this.guild.storage[e.detail.slot] = null; this.#emit('guild'); }
    });
    c.addEventListener('guildDayReset', (e) => {  // 每日贡献/增长清零
      if (this.guild) {
        this.guild.dailyGrowth = 0;
        this.guild.dailyContribution = 0;
        for (const m of this.guild.members ?? []) { m.dailyContribution = 0; m.dailyGrowth = 0; }
        this.#emit('guild');
      }
      void e;
    });
  }

  // AddItems (GameScene.cs:6743): 叠加 → 首空格; slot 字段已由服务端写好 (走 else 分支兜底)
  #onItemsGained(d) {
    let touched = false;
    for (const it of d?.items ?? []) {
      if (!it) continue;
      const info = ItemStore.itemInfo(it.infoIndex);
      const inv = this.grids.get(GRID.INVENTORY);
      // 叠加 (StackSize>1): 找同 Info 未满堆
      if (info && info.stack > 1) {
        for (const [slot, ex] of inv) {
          if (ex.infoIndex === it.infoIndex && Number(ex.count) + Number(it.count) <= info.stack) {
            ex.count += it.count;
            touched = true;
            it.slot = slot;
            break;
          }
        }
        if (it.slot != null && inv.has(it.slot)) continue;
      }
      if (it.slot == null || (it.slot < INVENTORY_SIZE && inv.has(it.slot))) {
        // 首空格
        for (let s = 0; s < INVENTORY_SIZE; s++) {
          if (!inv.has(s)) { it.slot = s; break; }
        }
      }
      if (it.slot >= EQUIPMENT_OFF) this.grids.get(GRID.EQUIPMENT).set(it.slot - EQUIPMENT_OFF, it);
      else if (it.slot >= 0 && it.slot < INVENTORY_SIZE) inv.set(it.slot, it);
      touched = true;
    }
    if (touched) this.#emit('items');
  }

  // OnItemMove (:6866): 服务端权威 swap/merge
  #onItemMove(d) {
    this.#unlock(d.fromGrid, d.fromSlot);
    this.#unlock(d.toGrid, d.toSlot);
    if (!d.success) { this.#emit('items'); return; }
    const from = this.#resolveGrid(d.fromGrid), to = this.#resolveGrid(d.toGrid);
    if (!from || !to) return;
    const a = from.get(d.fromSlot), b = to.get(d.toSlot);
    from.delete(d.fromSlot); to.delete(d.toSlot);
    if (a) a.slot = d.toGrid === GRID.EQUIPMENT ? d.toSlot + EQUIPMENT_OFF : d.toSlot;
    if (b) b.slot = d.fromGrid === GRID.EQUIPMENT ? d.fromSlot + EQUIPMENT_OFF : d.fromSlot;
    if (d.mergeItem && a && b) {
      b.count += a.count;
      to.set(d.toSlot, b);
      if (from !== to || d.fromSlot !== d.toSlot) { /* a 消失 */ }
    } else {
      if (a) to.set(d.toSlot, a);
      if (b) from.set(d.fromSlot, b);
    }
    this.#emit('items');
  }

  // OnItemChanged (:7114): count==0 移除否则改 count (使用/拆分确认)
  #onItemChanged(d) {
    const link = d?.link;
    if (!link) return;
    this.#unlock(link.gridType, link.slot);
    if (!d.success) { this.#emit('items'); return; }
    const g = this.#resolveGrid(link.gridType);
    const it = g?.get(link.slot);
    if (!it) return;
    if (link.count === 0n) g.delete(link.slot);
    else it.count = link.count;
    this.#emit('items');
  }

  // OnItemsChanged (:7222): 批量消耗 (出售/修理/仓存/邮件/交易)
  #onItemsChanged(d) {
    for (const link of d?.links ?? []) {
      if (!link) continue;
      this.#unlock(link.gridType, link.slot);
      if (!d.success) continue;
      const g = this.#resolveGrid(link.gridType);
      const it = g?.get(link.slot);
      if (!it) continue;
      if (link.count >= it.count) g.delete(link.slot);
      else it.count -= link.count;
    }
    this.#emit('items');
  }

  #onItemSort(d) {
    if (!d.success) return;
    const g = this.#resolveGrid(d.grid);
    if (!g) return;
    g.clear();
    for (const it of d.items ?? []) {
      if (!it) continue;
      if (d.grid === GRID.EQUIPMENT) { it.slot += EQUIPMENT_OFF; g.set(it.slot - EQUIPMENT_OFF, it); }
      else g.set(it.slot, it);
    }
    this.#emit('items');
  }

  #onItemSplit(d) {
    if (!d.success) return;
    const g = this.#resolveGrid(d.grid);
    const src = g?.get(d.slot);
    if (src) src.count -= d.count;
    // newSlot 内容由后续 ItemsGained/ItemChanged 到达
    this.#emit('items');
  }

  #onItemDelete(d) {
    this.grids.get(d.grid)?.delete(d.slot);
    this.#emit('items');
  }

  #resolveGrid(g) {
    if (g === GRID.STORAGE) return this.grids.get(GRID.STORAGE);
    if (g === GRID.PARTS_STORAGE_FALLBACK) return this.partsStorage; // 见 sendItemMoveParts
    return this.grids.get(g) ?? null;
  }

  // ---- 锁 (提交中格) ----
  #unlock(g, slot) { this.locked.delete(`${g}:${slot}`); }
  lock(g, slot) { this.locked.add(`${g}:${slot}`); this.#emit('items'); }
  isLocked(g, slot) { return this.locked.has(`${g}:${slot}`); }

  // ---- 移动意图 (DXItemCell.MoveItem): 本地乐观 + 发包, 服务端 echo 校正 ----
  moveItem(fromGrid, fromSlot, toGrid, toSlot, merge = false) {
    if (this.sendItemMove) this.sendItemMove(fromGrid, toGrid, fromSlot, toSlot, merge);
    this.lock(fromGrid, fromSlot);
  }

  unlockPublic(g, slot) { this.locked.delete(`${g}:${slot}`); this.#emit('items'); }

  // ---- 负重 ----
  maxBagWeight() { return this.stats[STAT_BAGWEIGHT] ?? 0; }
  maxWearWeight() { return this.stats[STAT_WEARWEIGHT] ?? 0; }
  maxHandWeight() { return this.stats[STAT_HANDWEIGHT] ?? 0; }
  sumBagWeight() { return this.bagWeight; }   // S.WeightUpdate 权威; 本地不估算 (items.json 无 weight)
}

// PartsStorage 槽位 = slot + PARTS_OFF (2000) — 协议表达, 见 dxgrid/win-storage
