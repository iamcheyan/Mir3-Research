// gamedb.js — 静态 DB 数据访问 (NPCPage/QuestInfo/NPCGood/ItemInfo/MagicInfo/CurrencyInfo)
// 数据源: Tools/dbeditor/workspace/*.json 经 serve.py /res/data/db/{table}.json 下发 (只读快照)。
// Godot 侧等价: Globals.NPCPageList / QuestInfoList / ItemInfoList / MagicInfoList (System.db 绑定)。

let cache = new Map();
const loading = new Map();

async function table(name) {
  if (cache.has(name)) return cache.get(name);
  if (loading.has(name)) return loading.get(name);
  const p = fetch(`/res/data/db/${name}.json`).then(r => {
    if (!r.ok) throw new Error(`${name}.json ${r.status}`);
    return r.json();
  }).then(d => {
    const rows = d?.rows ?? [];
    const byIndex = new Map();
    for (const row of rows) if (row.Index != null) byIndex.set(row.Index, row);
    const out = { rows, byIndex };
    cache.set(name, out);
    return out;
  }).catch(err => {
    console.warn('[gamedb] 加载失败', name, err.message);
    const out = { rows: [], byIndex: new Map() };
    cache.set(name, out);
    return out;
  });
  loading.set(name, p);
  return p;
}

function refIndex(v) {   // 工作区 JSON 的外键形如 {"Index":9,"Name":"..."} 或裸 int
  if (v == null) return null;
  if (typeof v === 'number') return v;
  if (typeof v === 'object') return v.Index ?? null;
  return null;
}

export const GameDB = {
  async npcPage(index) { return (await table('NPCPage')).byIndex.get(index) ?? null; },
  async questInfo(index) { return (await table('QuestInfo')).byIndex.get(index) ?? null; },
  async itemInfo(index) { return (await table('ItemInfo')).byIndex.get(index) ?? null; },
  async magicInfo(index) { return (await table('MagicInfo')).byIndex.get(index) ?? null; },
  async magicRows() { return (await table('MagicInfo')).rows; },
  async disciplineRows() { return (await table('DisciplineInfo')).rows; },
  async currencyList() { return (await table('CurrencyInfo')).rows; },
  async companionList() { return (await table('CompanionInfo')).rows; },
  async instanceList() { return (await table('InstanceInfo')).rows.filter(i => i.ShowOnDungeonFinder); },

  async npcGoods(pageIndex) {
    const t = await table('NPCGood');
    return t.rows.filter(g => refIndex(g.Page) === pageIndex)
      .sort((a, b) => (a.GoodsIndex ?? 0) - (b.GoodsIndex ?? 0));
  },

  async questRewards(questIndex) {
    const t = await table('QuestReward');
    return t.rows.filter(r => refIndex(r.Quest) === questIndex)
      .sort((a, b) => (a.Index ?? 0) - (b.Index ?? 0));
  },
  async questTasks(questIndex) {
    const t = await table('QuestTask');
    return t.rows.filter(r => refIndex(r.Quest) === questIndex)
      .sort((a, b) => (a.Index ?? 0) - (b.Index ?? 0));
  },

  // CurrencyInfo: Index→Row (0=Gold,1=GameGold …; Type 用于物品货币 DropItem)
  async currencies() { return (await table('CurrencyInfo')).rows; },
  // NPCInfo: Index → row (StartQuests/FinishQuests 外键数组)
  async npcInfo(index) { return (await table('NPCInfo')).byIndex.get(index) ?? null; },

  // NPCInfo: 找 NPC 的 StartQuests/FinishQuests ( quests 反向索引)
  async npcInfoByQuest(questIndex) {
    const [st, fi] = await Promise.all([table('QuestInfo'), table('NPCInfo')]);
    void st;
    const out = [];
    for (const n of fi.rows) {
      const starts = (n.StartQuests ?? []).map(refIndex);
      const finishes = (n.FinishQuests ?? []).map(refIndex);
      if (starts.includes(questIndex)) out.push({ npc: n, kind: 'start' });
      if (finishes.includes(questIndex)) out.push({ npc: n, kind: 'finish' });
    }
    return out;
  },

  // 全部任务 (QuestDialog 可接任务页)
  async allQuests() { return (await table('QuestInfo')).rows; },
  async questRequirements() { return (await table('QuestRequirement')).rows; },

  itemZhSync(index, itemsById) {   // 不走缓存的同步兜底 (data.js items.json 已有)
    const it = itemsById?.[index];
    return it?.zh && it.zh !== it.name ? it.zh : (it?.name ?? '');
  },
};
