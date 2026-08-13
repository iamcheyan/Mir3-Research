/* dbeditor 前端 —— Vue 3 + Element Plus（本地 vendor，零构建）。
 * 视图：列表（分页/搜索/排序/批量）、详情（schema 驱动表单 + 子表行内编辑 +
 * 引用下拉 + 图标预览）、改动追踪（diff + 回滚）、同步（预览/执行/报告）。
 */
"use strict";

const { createApp, ref, reactive, computed, onMounted, watch } = Vue;
const { ElMessage, ElMessageBox } = ElementPlus;

const api = {
  async get(url) {
    const r = await fetch(url);
    if (!r.ok) throw (await r.json()).detail || r.status;
    return r.json();
  },
  async send(url, method, body) {
    const r = await fetch(url, { method, headers: { "Content-Type": "application/json" },
                                 body: body === undefined ? undefined : JSON.stringify(body) });
    const d = await r.json().catch(() => ({}));
    if (!r.ok) throw d.detail || JSON.stringify(d);
    return d;
  },
};

const NAME_KEYS = ["ItemName", "MonsterName", "Name", "SetName"];

function rowName(table, row) {
  for (const k of NAME_KEYS) if (row[k]) return String(row[k]);
  return row._Identity || `#${row.Index}`;
}

const app = createApp({
  template: window.APP_TEMPLATE,
  setup() {
    // ---------- 全局状态 ----------
    const view = ref("list");            // list | detail | changes
    const cats = ref([]);
    const activeCat = ref("ItemInfo");
    const status = ref({});
    const changeCount = ref(0);
    const loading = ref(false);
    // 移动端检测（≤768px）：手机卡片列表 + 单列表单，浏览为主
    const isMobile = ref(window.innerWidth <= 768);
    window.addEventListener("resize", () => { isMobile.value = window.innerWidth <= 768; });

    const rows = ref([]);
    const total = ref(0);
    const page = ref(1);
    const per = ref(50);

    const query = ref("");
    // ---- 分类筛选（facets）----
    const facetSel = reactive({});   // { 字段: Set(值) }，仅当前类目的轴生效
    const facetQuery = computed(() => {
      const parts = [];
      for (const [f, vals] of Object.entries(facetSel)) {
        if (vals && vals.size) parts.push(`${f}=${[...vals].join(",")}`);
      }
      return parts.join(";");
    });
    const activeFacets = computed(() => {
      const c = cats.value.find(x => x.key === activeCat.value);
      return Array.isArray(c && c.facets) ? c.facets : [];
    });
    const facetOpen = ref(false);
    const selectedFacetCount = computed(() =>
      Object.values(facetSel).reduce((n, s) => n + (s instanceof Set ? s.size : 0), 0));
    function toggleFacet(field, val) {
      if (!facetSel[field]) facetSel[field] = new Set();
      const s = facetSel[field];
      s.has(val) ? s.delete(val) : s.add(val);
      page.value = 1; loadTable();
    }
    const sortKey = ref("Index");
    const sortDir = ref("asc");
    const selection = ref([]);
    const meta = ref({});
    const metaCache = {};
    const optionsCache = {};
    const changesData = ref(null);
    const syncDialog = reactive({ visible: false, running: false, result: null });
    const bulkDialog = reactive({ visible: false, table: "", field: "", value: 0, fields: [] });
    const refOptions = ref({});
    const subMetas = ref({});
    const detail = reactive({ table: "", index: null, row: {}, subs: {}, dirty: false });

    const catZh = computed(() => {
      const c = cats.value.find(x => x.key === activeCat.value);
      return c ? c.zh : activeCat.value;
    });
    const subDefs = computed(() => {
      const c = cats.value.find(x => x.key === activeCat.value);
      return c ? c.subs : [];
    });

    // ---------- 启动 ----------
    onMounted(async () => {
      try {
        const [c, s] = await Promise.all([api.get("/api/categories"), api.get("/api/status")]);
        cats.value = c; status.value = s;
        await refreshCount();
        await loadTable();
      } catch (e) { ElMessage.error("初始化失败: " + e); }
    });

    async function refreshCount() {
      try {
        changesData.value = await api.get("/api/changes");
        const s = changesData.value.summary;
        changeCount.value = s.added + s.modified + s.deleted;
      } catch (e) { /* ignore */ }
    }

    // ---------- 列表 ----------
    async function loadTable() {
      loading.value = true;
      view.value = "list";
      try {
        let u = `/api/table/${activeCat.value}?page=${page.value}&per=${per.value}`
          + `&sort=${encodeURIComponent(sortKey.value)}&dir=${sortDir.value}`;
        if (query.value) u += `&q=${encodeURIComponent(query.value)}`;
        if (facetQuery.value) u += `&facet=${encodeURIComponent(facetQuery.value)}`;
        const d = await api.get(u);
        rows.value = d.rows; total.value = d.count;
        if (!metaCache[activeCat.value]) {
          metaCache[activeCat.value] = await api.get(`/api/meta?table=${activeCat.value}`);
        }
        meta.value = metaCache[activeCat.value];
      } catch (e) { ElMessage.error(String(e)); }
      loading.value = false;
    }

    async function getMeta(table) {
      if (!metaCache[table]) metaCache[table] = await api.get(`/api/meta?table=${table}`);
      return metaCache[table];
    }

    async function getOptions(table) {
      if (!optionsCache[table]) {
        try { optionsCache[table] = await api.get(`/api/options/${table}`); }
        catch (e) { optionsCache[table] = []; }
      }
      return optionsCache[table];
    }

    function switchCat(key) {
      activeCat.value = key; page.value = 1; query.value = ""; sortKey.value = "Index";
      Object.keys(facetSel).forEach(k => delete facetSel[k]);   // 切类目清空筛选
      loadTable();
    }
    function search() { page.value = 1; loadTable(); }
    function resort(col) {
      if (col.prop && col.prop !== "__name" && col.prop !== "__icon"
          && col.prop !== "__mon" && col.prop !== "__item") {
        sortKey.value = col.prop;
        sortDir.value = col.order === "descending" ? "desc" : "asc";
        loadTable();
      }
    }
    function zhName(row) {
      const name = rowName(activeCat.value, row);
      const z = row.__zh;
      return z && z !== name ? `${name}（${z}）` : name;
    }

    // 列表列（轻量定制 + 通用回退）
    const listCols = computed(() => {
      const cols = [{ prop: "Index", label: "#", width: 80, sortable: "custom" },
                    { prop: "__name", label: "名称", width: 250 }];
      if (activeCat.value === "ItemInfo") {
        cols.push({ prop: "__icon", label: "图标", width: 70 });
        cols.push({ prop: "ItemType", label: "类型", width: 130 });
        cols.push({ prop: "Price", label: "价格", width: 90, sortable: "custom" });
        cols.push({ prop: "Rarity", label: "稀有度", width: 110 });
      } else if (activeCat.value === "MonsterInfo") {
        cols.push({ prop: "__icon", label: "图标", width: 70 });
        cols.push({ prop: "Level", label: "等级", width: 80, sortable: "custom" });
        cols.push({ prop: "Health", label: "HP", width: 110 });
      } else if (activeCat.value === "MagicInfo") {
        cols.push({ prop: "__icon", label: "图标", width: 70 });
        cols.push({ prop: "Class", label: "职业", width: 90 });
        cols.push({ prop: "NeedLevel1", label: "需求等级", width: 90 });
      } else if (activeCat.value === "DropInfo") {
        cols.push({ prop: "__mon", label: "怪物", width: 210 });
        cols.push({ prop: "__item", label: "物品", width: 210 });
        cols.push({ prop: "Chance", label: "概率", width: 90, sortable: "custom" });
        cols.push({ prop: "Amount", label: "数量", width: 80 });
      }
      return cols;
    });

    function displayCell(row, prop) {
      if (prop === "__name") return zhName(row);
      if (prop === "__mon") return row.Monster ? row.Monster.Name : "-";
      if (prop === "__item") return row.Item ? row.Item.Name : "-";
      const v = row[prop];
      if (v === null || v === undefined) return "";
      if (typeof v === "object") return v.Name || JSON.stringify(v);
      return v;
    }

    const iconErr = new Set();
    // 图标图库按分类分发：物品=Storeitems.Zl、怪物=Mon-N.Zl（后端注入 __lib，来自
    // MonsterLookup 映射）、技能=MIcon.Zl（MagicInfo.Icon 直取）。
    // 帧号统一用后端同步注入的 __frame（货币物品换算/怪物 Shape*1000+40），无则回退 Image。
    function rowLib(row) {
      if (row.__lib) return row.__lib;
      if (activeCat.value === "MonsterInfo") return "MonImg";   // 兜底（无映射时不显示）
      return "Storeitems";
    }
    function rowIcon(row) {
      if (iconErr.has(row.Index)) return null;
      if (activeCat.value === "MagicInfo") {
        if (typeof row.Icon !== "number" || (!row.__frame && row.__frame !== 0)) return null;
        return `/zl/MIcon/${row.__frame ?? row.Icon}.png`;
      }
      if (typeof row.Image !== "number" && !row.__frame && row.__frame !== 0) return null;
      // 物品图标 = Storeitems.Zl（客户端 DXItemCell 默认图库）；货币物品的 Image 是假的，
      // 后端已在列表/详情注入真实帧号 __frame（客户端 CurrencyImage 同款逻辑）。
      // 怪物 = 后端注入 __lib(Mon-N) + __frame；无映射（Image 枚举不在 MonsterLookup）不显示。
      if (activeCat.value === "MonsterInfo" && !row.__lib) return null;
      const lib = activeCat.value === "MonsterInfo" ? row.__lib : "Storeitems";
      const frame = row.__frame ?? row.Image;
      if (typeof frame !== "number") return null;
      return `/zl/${lib}/${frame}.png`;
    }
    function iconError(row) { iconErr.add(row.Index); row.__noicon = true; }
    // 怪物详情页动作预览：站立 8 方向 + 行走/攻击/死亡序列（逐帧请求 /zl/）
    function monActionSrc(a) { return `/zl/${a.lib}/${a.frame}.png`; }

    // ---------- 详情 ----------
    async function openDetail(index) {
      loading.value = true;
      try {
        const d = await api.get(`/api/row/${activeCat.value}/${index}`);
        detail.table = activeCat.value;
        detail.index = index;
        detail.row = JSON.parse(JSON.stringify(d.row));
        detail.subs = {};
        for (const [t, v] of Object.entries(d.subs || {})) {
          detail.subs[t] = { ...v, rows: JSON.parse(JSON.stringify(v.rows || [])) };
        }
        detail.dirty = false;
        view.value = "detail";
        await prepareRefs();
      } catch (e) { ElMessage.error(String(e)); }
      loading.value = false;
    }

    // 主表字段分类
    const editFields = computed(() => {
      if (!meta.value || !meta.value.fields) return [];
      const out = [];
      for (const [key, fm] of Object.entries(meta.value.fields)) {
        if (key === "Index") continue;
        let kind = "readonly";
        if (["int", "bool", "float", "number", "enum", "string"].includes(fm.type)) kind = "edit";
        else if (fm.type === "ref") kind = "ref";
        else if (fm.type === "stats") kind = "stats";
        else if (fm.type === "reflist") kind = "reflist";
        out.push({ key, zh: fm.zh || key, type: fm.type, to: fm.to, kind });
      }
      return out;
    });
    const mainFields = computed(() => editFields.value.filter(f => f.kind !== "reflist"));

    async function prepareRefs() {
      for (const f of mainFields.value) {
        if (f.kind === "ref" && f.to) refOptions.value[f.key] = await getOptions(f.to);
        if (f.kind === "stats") {
          refOptions.value[f.key] = (meta.value.enums || {}).Stat || [];
        }
      }
      // 子表 meta + 子表内 ref/enum 字段下拉
      for (const t of Object.keys(detail.subs)) {
        const m = await getMeta(t);
        subMetas.value[t] = m;
        for (const [k, fm] of Object.entries(m.fields || {})) {
          if (fm.type === "ref" && fm.to) {
            refOptions.value[`${t}.${k}`] = await getOptions(fm.to);
          } else if (fm.type === "enum") {
            refOptions.value[`${t}.${k}`] = (m.enums || {})[fm.to]
              || (meta.value.enums || {})[fm.to] || [];
          }
        }
      }
    }

    function subEditableCols(t) {
      const m = subMetas.value[t];
      if (!m || !m.fields) return [];
      const def = subDefs.value.find(x => x.table === t);
      const pf = def ? def.parent_field : "";
      return Object.entries(m.fields)
        .filter(([k]) => k !== "Index" && k !== pf && k !== "_Identity")
        .map(([k, fm]) => ({ key: k, zh: fm.zh || k, type: fm.type, to: fm.to }));
    }

    function markDirty() { detail.dirty = true; }

    function subZh(t) {
      const s = subDefs.value.find(x => x.table === t);
      return s ? s.zh : t;
    }
    function subReadonly(t) {
      const s = subDefs.value.find(x => x.table === t);
      return !s || !!s.readonly;
    }

    function addSubRow(t) {
      detail.subs[t].rows.push({ Index: null });
      detail.dirty = true;
    }
    function delSubRow(t, i) {
      detail.subs[t].rows.splice(i, 1);
      detail.dirty = true;
    }

    async function saveDetail() {
      try {
        const payloadRow = JSON.parse(JSON.stringify(detail.row));
        const subs = {};
        for (const [t, v] of Object.entries(detail.subs)) {
          if (subReadonly(t)) continue;
          const def = subDefs.value.find(x => x.table === t);
          if (!def || def.parent_field.startsWith("@")) continue;
          subs[t] = v.rows.map(r => ({ ...r }));
        }
        const d = await api.send(`/api/row/${detail.table}/${detail.index}`, "PUT",
                                 { row: payloadRow, subs: Object.keys(subs).length ? subs : null });
        detail.dirty = false;
        await refreshCount();
        ElMessage.success("已保存（工作区 + git）");
        await openDetail(detail.index);
      } catch (e) { ElMessage.error("保存失败: " + e); }
    }

    async function rollbackRow(table, index) {
      try {
        await ElMessageBox.confirm(`回滚 ${table}#${index} 到基线版本？`, "确认", { type: "warning" });
      } catch { return; }
      try {
        await api.send("/api/rollback", "POST", { table, index });
        ElMessage.success("已回滚");
        await refreshCount();
        if (view.value === "changes") await openChanges();
      } catch (e) { ElMessage.error(String(e)); }
    }

    // ---------- 行操作 ----------
    async function duplicateRow(index) {
      try {
        const d = await api.send(`/api/row/${activeCat.value}/${index}/duplicate`, "POST");
        ElMessage.success(`已复制为 #${d.row.Index}`);
        await refreshCount(); await loadTable();
      } catch (e) { ElMessage.error(String(e)); }
    }

    async function deleteRow(index) {
      try {
        await ElMessageBox.confirm(`删除 ${activeCat.value}#${index}？子表行将级联删除。`,
          "确认删除", { type: "warning" });
      } catch { return; }
      try {
        await api.send(`/api/row/${activeCat.value}/${index}`, "DELETE");
        ElMessage.success("已删除");
        await refreshCount(); await loadTable();
      } catch (e) { ElMessage.error(String(e)); }
    }

    async function createRow() {
      try {
        const d = await api.send(`/api/row/${activeCat.value}`, "POST", { row: {} });
        ElMessage.success(`已新增 #${d.row.Index}`);
        await refreshCount(); await loadTable();
        openDetail(d.row.Index);
      } catch (e) { ElMessage.error(String(e)); }
    }

    // ---------- 批量 ----------
    function openBulk() {
      if (!selection.value.length) { ElMessage.warning("先勾选行"); return; }
      bulkDialog.table = activeCat.value;
      bulkDialog.fields = Object.entries(meta.value.fields || {})
        .filter(([k, f]) => ["int", "bool", "float", "number", "enum", "string"].includes(f.type))
        .map(([k, f]) => ({ key: k, zh: f.zh || k, type: f.type, to: f.to }));
      bulkDialog.field = ""; bulkDialog.value = 0;
      bulkDialog.visible = true;
    }
    const bulkFieldDef = computed(() => bulkDialog.fields.find(f => f.key === bulkDialog.field));
    const bulkEnums = computed(() =>
      (bulkFieldDef.value && meta.value.enums
        && meta.value.enums[bulkFieldDef.value.to]) || []);
    async function runBulk() {
      if (!bulkDialog.field) { ElMessage.warning("选字段"); return; }
      let val = bulkDialog.value;
      if (bulkFieldDef.value.type === "bool") val = !!val;
      else if (bulkFieldDef.value.type === "int") val = Number(val);
      try {
        await api.send(`/api/bulk/${bulkDialog.table}`, "POST",
          { indexes: selection.value.map(r => r.Index), patch: { [bulkDialog.field]: val }, dry: false });
        ElMessage.success(`已批量修改 ${selection.value.length} 行`);
        bulkDialog.visible = false;
        await refreshCount(); await loadTable();
      } catch (e) { ElMessage.error(String(e)); }
    }

    // ---------- 改动页 ----------
    async function openChanges() {
      view.value = "changes";
      changesData.value = await api.get("/api/changes");
      const s = changesData.value.summary;
      changeCount.value = s.added + s.modified + s.deleted;
    }
    function fmtVal(v) {
      if (v === null || v === undefined) return "∅";
      if (typeof v === "object") return v.Name !== undefined ? `${v.Name}#${v.Index}` : JSON.stringify(v);
      return String(v);
    }

    // ---------- 同步 ----------
    async function doSync() {
      try {
        await ElMessageBox.confirm(
          "同步会把工作区改动写入服务端与客户端 System.db（先自动备份）。确认服务端已停止？",
          "同步到数据库", { type: "warning", confirmButtonText: "开始同步" });
      } catch { return; }
      syncDialog.visible = true; syncDialog.running = true; syncDialog.result = null;
      try {
        syncDialog.result = await api.send("/api/sync", "POST");
        await refreshCount();
        status.value = await api.get("/api/status");
      } catch (e) { syncDialog.result = { ok: false, error: String(e) }; }
      syncDialog.running = false;
    }

    return {
      view, cats, activeCat, catZh, status, changeCount, loading,
      rows, total, page, per, query, selection, listCols,
      displayCell, rowIcon, iconError, switchCat, search, resort, zhName,
      isMobile, rowName, monActionSrc,
      facetSel, activeFacets, toggleFacet, facetOpen, selectedFacetCount,
 detail, mainFields, refOptions, subMetas, markDirty,
      saveDetail, subZh, subReadonly, subEditableCols, addSubRow, delSubRow,
      openDetail, duplicateRow, deleteRow, createRow,
      bulkDialog, openBulk, runBulk, bulkFieldDef, bulkEnums,
      changesData, openChanges, rollbackRow, fmtVal,
      syncDialog, doSync,
      enums: computed(() => meta.value.enums || {}),
    };
  },
});

app.use(ElementPlus, { locale: ElementPlusLocaleZhCn });
for (const [n, c] of Object.entries(ElementPlusIconsVue)) app.component(n, c);
app.mount("#app");
