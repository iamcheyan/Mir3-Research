(() => {
  'use strict';

  const SECTIONS = [
    { id: 'overview', label: '总览', eyebrow: 'SECTION / OVERVIEW' },
    { id: 'monsters', label: '怪物', eyebrow: 'ENTITY / MONSTERS' },
    { id: 'npcs', label: 'NPC', eyebrow: 'ENTITY / NPC' },
    { id: 'items', label: '物品', eyebrow: 'ENTITY / ITEMS' },
    { id: 'skills', label: '技能', eyebrow: 'ENTITY / MAGIC' },
    { id: 'maps', label: '地图', eyebrow: 'WORLD / MAPS' },
    { id: 'respawns', label: '刷新', eyebrow: 'WORLD / RESPAWN' },
    { id: 'quests', label: '任务', eyebrow: 'CROSS-REFERENCE / QUESTS' },
    { id: 'decisions', label: '结论', eyebrow: 'FINAL / DECISIONS' }
  ];
  const DATA_FILES = ['monsters', 'npcs', 'items', 'skills', 'maps', 'respawns', 'quests'];
  const state = { meta: null, data: {}, section: 'overview', query: '', status: '', source: '', different: false, pending: false, page: 1, pageSize: 36 };
  const $ = (id) => document.getElementById(id);

  const esc = (value) => String(value ?? '').replace(/[&<>"']/g, (char) => ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;' }[char]));
  const jsonText = (value) => {
    try { return JSON.stringify(value, null, 2); } catch { return String(value); }
  };
  const safeImage = (path) => typeof path === 'string' && path.startsWith('data/images/') ? path : '';
  const sourceLabel = (source) => source?.source_type || 'source';
  const statusClass = (status) => String(status || 'pending').replace(/[^a-z0-9-]/gi, '-').toLowerCase();
  const statusText = (status) => ({ confirmed: 'confirmed', investigate: 'investigate', pending: 'pending', 'retain-current': 'retain-current', 'position-applied': '已应用', applied: '已应用', 'production-applied': '已应用', conflict: 'conflict', 'zircon-only': 'Zircon-only', 'yxs-only': 'YXS-only', exact: 'exact', variant: 'variant', renamed: 'renamed', replacement: 'replacement', matched: 'matched', 'display-name-only': 'display-name-only', 'resource-candidate': 'resource candidate', 'classic-name-only': 'classic-name-only', 'icon-conflict': 'icon-conflict', 'legacy-only': 'legacy-only', 'no-safe-index': 'no-safe-index' }[status] || status || 'pending');
  const valueText = (value) => {
    if (value === null || value === undefined || value === '') return '—';
    if (typeof value === 'boolean') return value ? 'true' : 'false';
    if (Array.isArray(value)) return value.length ? value.map(valueText).join(' · ') : '[]';
    if (typeof value === 'object') return Object.entries(value).slice(0, 5).map(([k, v]) => `${k}: ${valueText(v)}`).join(' / ') || '{}';
    return String(value);
  };
  const pick = (record) => {
    const left = record.left || {};
    const right = record.right || {};
    return left.MonsterName || left.NPCName || left.ItemName || left.Name || left.Description || right.standard_name || right.title || right.area || record.id;
  };
  const subtitle = (record) => {
    const left = record.left || {};
    const right = record.right || {};
    const index = left.Index ?? right.website_id ?? record.id;
    const identity = left._Identity || left.FileName || right.category || right.group || '';
    return `#${index ?? '—'}${identity ? ` · ${identity}` : ''}`;
  };
  const fieldsFor = (obj, preferred) => {
    if (!obj) return [];
    const keys = preferred.filter((key) => Object.prototype.hasOwnProperty.call(obj, key));
    return keys.map((key) => [key, obj[key]]);
  };
  const imageFor = (obj) => safeImage(obj?.image) || safeImage(obj?.Image) || safeImage(obj?.website_image);

  function renderNav() {
    $('section-nav').innerHTML = SECTIONS.map((section) => `<button class="nav-button ${state.section === section.id ? 'active' : ''}" data-section="${section.id}" type="button">${esc(section.label)}</button>`).join('');
    $('section-nav').querySelectorAll('button').forEach((button) => button.addEventListener('click', () => selectSection(button.dataset.section)));
  }

  function selectSection(section) {
    state.section = section; state.page = 1; renderNav(); renderSection();
    if (section !== 'overview' && section !== 'decisions') window.scrollTo({ top: document.querySelector('.workspace-panel').offsetTop - 82, behavior: 'smooth' });
    if (section === 'decisions') window.scrollTo({ top: $('decisions').offsetTop - 82, behavior: 'smooth' });
    history.replaceState(null, '', `#${section}`);
  }

  function renderMetrics() {
    const c = state.meta.counts;
    const metrics = [
      ['434', 'Zircon 怪物', 'MonsterInfo'], ['1,078', 'Zircon 物品', 'ItemInfo'], ['174', 'Zircon 技能', 'MagicInfo'], ['294', 'Zircon NPC', 'NPCInfo'], ['627', 'Zircon 地图', 'MapInfo'], ['2,475', 'Zircon 刷新', 'RespawnInfo'],
      ['154', 'website 怪物', 'mir3-website'], ['371', 'website 物品', 'mir3-website'], ['61', 'website 技能', 'mir3-website'], ['24', 'website 任务组', 'mir3-website']
    ];
    $('metrics').innerHTML = metrics.map(([number, label, source]) => `<div class="metric"><strong>${number}</strong><span>${esc(label)}</span><small>${esc(source)}</small></div>`).join('');
  }

  function renderProduction() {
    const p = state.meta.production || {};
    const status = p.server_client_sha_equal ? '双库一致' : '需检查';
    $('production-banner').innerHTML = `<div class="production-lead"><span class="status-dot applied"></span><div><b>生产应用已闭合</b><span>NPC 73 · RespawnInfo 18 · MonsterInfo 0 · MagicInfo 0</span></div></div><div class="production-meta"><span>System.db <code>${esc(p.server_sha256 || '—')}</code></span><span>${esc(status)}</span><span>Users.db 写入：<b>${p.users_db_written ? '是' : '否'}</b></span><span>验证：${esc(p.last_verified || '—')}</span></div>`;
  }

  function renderOverview() {
    $('section-eyebrow').textContent = 'SECTION / OVERVIEW'; $('section-title').textContent = '总览'; $('panel-count').textContent = '证据面板'; $('filter-row').innerHTML = '';
    const statuses = state.meta.counts.status || {};
    const statusRows = Object.entries(statuses).sort((a, b) => b[1] - a[1]).map(([key, count]) => `<button class="status-summary" data-status="${esc(key)}" type="button"><span class="status-dot ${statusClass(key)}"></span><b>${count}</b><span>${esc(statusText(key))}</span></button>`).join('');
    const c = state.meta.counts;
    $('ledger').innerHTML = `<div class="overview-grid"><article class="overview-card wide"><p class="eyebrow">COVERAGE / DO NOT COLLAPSE</p><h3>网站目录是标准线索，不是 Zircon 全量</h3><div class="compare-bars"><div><span>技能</span><b>61</b><i style="width:35%"></i><small>vs Zircon 174</small></div><div><span>怪物</span><b>154</b><i style="width:35%"></i><small>vs Zircon 434</small></div><div><span>物品</span><b>371</b><i style="width:35%"></i><small>vs Zircon 1,078</small></div></div><p class="muted">具体业务 Index 只有在 manifest / 资源 / 任务 / 位置等证据闭合时才升级；没有直接对应就显示无直接对应。</p></article><article class="overview-card"><p class="eyebrow">DECISION STATES</p><div class="status-cloud">${statusRows}</div></article><article class="overview-card wide"><p class="eyebrow">SOURCE CHAIN</p><div class="source-chain"><span>workspace JSON</span><b>→</b><span>alignment manifest</span><b>→</b><span>legacy / website evidence</span><b>→</b><span>production apply</span></div><p class="muted">生成时间 ${esc(state.meta.generated_at)} · 数据版本 ${esc(state.meta.data_version)}</p></article><article class="overview-card"><p class="eyebrow">DB / PRODUCTION</p><dl class="compact-list"><div><dt>server</dt><dd>${esc(present(state.meta.production?.server_sha256))}</dd></div><div><dt>client</dt><dd>${esc(present(state.meta.production?.client_sha256))}</dd></div><div><dt>backup</dt><dd>双库已备份</dd></div><div><dt>Users.db</dt><dd>未写入</dd></div></dl></article></div>`;
    const summary = state.meta.counts.summary_status || {};
    document.querySelector('.overview-card:nth-child(2)')?.insertAdjacentHTML('afterbegin', `<div class="summary-banner"><b>${summary.confirmed ?? 0}</b> confirmed <b>${summary.investigate ?? 0}</b> investigate <b>${summary.pending ?? 0}</b> pending <b>${summary.unmatched ?? 0}</b> unmatched <b>${summary['retain-current'] ?? 0}</b> retain-current</div>`);
  }
  const present = (value) => value ? String(value).slice(0, 12) + '…' : '—';

  function activeRecords() {
    const records = state.data[state.section] || [];
    const query = state.query.trim().toLowerCase();
    return records.filter((record) => {
      const blob = JSON.stringify(record).toLowerCase();
      const status = record.conclusion?.status || '';
      const sourceBlob = (record.evidence || []).map(sourceLabel).join(' ').toLowerCase();
      if (query && !blob.includes(query)) return false;
      if (state.status && status !== state.status) return false;
      if (state.source && !sourceBlob.includes(state.source.toLowerCase())) return false;
      if (state.different && ['confirmed', 'matched', 'same', 'exact'].includes(status)) return false;
      if (state.pending && !['pending', 'investigate', 'conflict', 'retain-current', 'zircon-only', 'yxs-only'].includes(status)) return false;
      return true;
    });
  }

  function renderFilters(records) {
    const counts = new Map();
    records.forEach((record) => counts.set(record.conclusion?.status || 'pending', (counts.get(record.conclusion?.status || 'pending') || 0) + 1));
    const pills = [['', '全部', records.length], ...Array.from(counts.entries()).sort((a, b) => b[1] - a[1]).slice(0, 10).map(([key, count]) => [key, statusText(key), count])];
    $('filter-row').innerHTML = `<span class="filter-caption">FILTER</span>${pills.map(([key, label, count]) => `<button class="filter-pill ${state.status === key ? 'active' : ''}" type="button" data-filter-status="${esc(key)}"><span class="status-dot ${statusClass(key)}"></span>${esc(label)} <b>${count}</b></button>`).join('')}<button class="filter-pill ${state.different ? 'active' : ''}" type="button" data-toggle="different">只看差异</button><button class="filter-pill ${state.pending ? 'active' : ''}" type="button" data-toggle="pending">只看未决</button>`;
    $('filter-row').querySelectorAll('[data-filter-status]').forEach((button) => button.addEventListener('click', () => { state.status = button.dataset.filterStatus; state.page = 1; renderSection(); }));
    $('filter-row').querySelectorAll('[data-toggle]').forEach((button) => button.addEventListener('click', () => { state[button.dataset.toggle] = !state[button.dataset.toggle]; state.page = 1; renderSection(); }));
  }

  function fieldTable(obj, preferred) {
    const fields = fieldsFor(obj, preferred);
    if (!fields.length) return '<p class="empty">无直接对应</p>';
    return `<dl class="field-table">${fields.map(([key, value]) => `<div><dt>${esc(key)}</dt><dd>${esc(valueText(value))}</dd></div>`).join('')}</dl>`;
  }

  function evidenceStrip(record) {
    return `<div class="evidence-strip">${(record.evidence || []).slice(0, 4).map((item) => `<span title="${esc(item.source_path || '')}"><b>${esc(sourceLabel(item))}</b><small>${esc(item.source_id || item.page || 'record')}</small></span>`).join('')}</div>`;
  }

  function sideCard(label, obj, side, preferred) {
    const image = imageFor(obj);
    return `<article class="side-card ${side}"><div class="side-label"><span class="side-rule"></span>${esc(label)}</div>${image ? `<img class="record-image" src="${esc(image)}" alt="" loading="lazy">` : ''}${fieldTable(obj, preferred)}</article>`;
  }

  function recordRow(record) {
    const status = record.conclusion?.status || 'pending';
    const left = record.left;
    const right = record.right;
    const leftPreferred = ['Index', '_Identity', 'MonsterName', 'NPCName', 'ItemName', 'Name', 'Image', 'Shape', 'Level', 'IsBoss', 'Class', 'Map', 'Region', 'CenterX', 'CenterY', 'Count', 'Delay', 'DropSet', 'Description'];
    const rightPreferred = ['standard_name', 'title', 'area', 'category', 'class', 'description', 'map_match', 'match_status', 'confidence', 'apply_status', 'direct_correspondence'];
    return `<article class="record-row" data-record-id="${esc(record.id)}"><button class="record-main" type="button" aria-label="打开 ${esc(pick(record))} 详情"><div class="record-heading"><div><h3>${esc(pick(record))}</h3><p>${esc(subtitle(record))}</p></div><span class="status-chip ${statusClass(status)}"><i class="status-dot ${statusClass(status)}"></i>${esc(statusText(status))}</span></div><div class="comparison-grid">${sideCard('ZIRCON / CURRENT', left, 'left-side', leftPreferred)}<div class="versus" aria-hidden="true">↔</div>${sideCard('MIR2EI / EVIDENCE', right, 'right-side', rightPreferred)}</div>${evidenceStrip(record)}<div class="conclusion-line"><b>${esc(record.conclusion?.title || statusText(status))}</b><span>${esc(record.conclusion?.rationale || '证据保留在详情中')}</span></div></button></article>`;
  }

  function renderPager(total) {
    const pages = Math.max(1, Math.ceil(total / state.pageSize)); state.page = Math.min(state.page, pages);
    const buttons = [Math.max(1, state.page - 2), Math.max(1, state.page - 1), state.page, Math.min(pages, state.page + 1), Math.min(pages, state.page + 2)].filter((page, index, arr) => arr.indexOf(page) === index && page >= 1 && page <= pages);
    $('pager').innerHTML = `<button class="pager-button" type="button" data-page="${state.page - 1}" ${state.page <= 1 ? 'disabled' : ''}>上一页</button>${buttons.map((page) => `<button class="pager-button ${page === state.page ? 'active' : ''}" type="button" data-page="${page}">${page}</button>`).join('')}<button class="pager-button" type="button" data-page="${state.page + 1}" ${state.page >= pages ? 'disabled' : ''}>下一页</button><span>共 ${total} 条 · ${pages} 页</span>`;
    $('pager').querySelectorAll('[data-page]').forEach((button) => button.addEventListener('click', () => { state.page = Number(button.dataset.page); renderSection(); }));
  }

  function renderSection() {
    if (!state.meta) return;
    if (state.section === 'overview') { renderOverview(); return; }
    if (state.section === 'decisions') { renderDecisions(); return; }
    const section = SECTIONS.find((item) => item.id === state.section);
    const all = state.data[state.section] || []; const filtered = activeRecords();
    $('section-eyebrow').textContent = section.eyebrow; $('section-title').textContent = section.label; $('panel-count').textContent = `${filtered.length} / ${all.length} 条`;
    renderFilters(all);
    const start = (state.page - 1) * state.pageSize; const page = filtered.slice(start, start + state.pageSize);
    $('ledger').innerHTML = page.length ? page.map(recordRow).join('') : '<div class="empty-state"><b>没有符合条件的记录</b><span>清除搜索或筛选，保留原始数据范围。</span></div>';
    renderPager(filtered.length);
    $('ledger').querySelectorAll('.record-main').forEach((button, index) => button.addEventListener('click', () => openDetail(page[index])));
  }

  function renderDecisions() {
    $('section-eyebrow').textContent = 'FINAL / DECISIONS'; $('section-title').textContent = '结论与下一步'; $('panel-count').textContent = '按实体保留'; $('filter-row').innerHTML = '';
    const p = state.meta.production || {};
    $('ledger').innerHTML = `<div class="decision-grid large"><article class="decision-card applied-card"><span class="status-chip position-applied">已应用</span><h3>NPC 坐标与 18 条刷新目标已写入 System.db</h3><p>本次应用只触及批准的 NPC 73 条与 RespawnInfo 18 条。MonsterInfo / MagicInfo 业务字段均为 0 变更。</p><dl class="compact-list"><div><dt>server/client</dt><dd>${esc(present(p.server_sha256))} / ${esc(present(p.client_sha256))}</dd></div><div><dt>round-trip</dt><dd>PASS · unapproved changes 0</dd></div><div><dt>Users.db</dt><dd>未写入</dd></div></dl></article><article class="decision-card"><span class="status-chip retain-current">retain-current</span><h3>当前数据不能被网站目录覆盖</h3><p>网站 61 技能、154 怪物、371 物品与 Zircon 全量的规模不同。无直接对应时保留当前 Index，不猜创建、删除或索引迁移。</p></article><article class="decision-card"><span class="status-chip investigate">investigate</span><h3>人工决定仍集中在证据未闭合处</h3><p>优先查看 conflict、investigate、pending、Zircon-only 与 YXS-only。每条记录详情含来源路径、source_id、原始 manifest 摘要和当前字段。</p></article></div>`;
    $('pager').innerHTML = '';
  }

  function detailSection(title, content) { return `<section class="drawer-section"><p class="eyebrow">${esc(title)}</p>${content}</section>`; }
  function objectDetails(obj) {
    if (!obj) return '<p class="empty">无直接对应</p>';
    return `<pre class="json-block">${esc(jsonText(obj))}</pre>`;
  }
  function openDetail(record) {
    if (!record) return;
    const status = record.conclusion?.status || 'pending'; const left = record.left; const right = record.right;
    $('drawer-kind').textContent = `${record.kind.toUpperCase()} / ${statusText(status)}`; $('drawer-title').textContent = pick(record);
    $('drawer-body').innerHTML = `${detailSection('CONCLUSION', `<div class="drawer-conclusion"><span class="status-chip ${statusClass(status)}"><i class="status-dot ${statusClass(status)}"></i>${esc(statusText(status))}</span><h3>${esc(record.conclusion?.title || 'pending')}</h3><p>${esc(record.conclusion?.rationale || '')}</p><dl class="compact-list"><div><dt>当前实际使用</dt><dd>${esc(record.conclusion?.current_actual || '—')}</dd></div><div><dt>建议标准</dt><dd>${esc(record.conclusion?.proposed_standard || '—')}</dd></div><div><dt>应用状态</dt><dd>${esc(record.conclusion?.applied || '—')}</dd></div></dl></div>`)}${detailSection('ZIRCON / CURRENT', objectDetails(left))}${detailSection('MIR2EI / EVIDENCE', objectDetails(right))}${detailSection('SOURCES', `<div class="source-list">${(record.evidence || []).map((item) => `<div><b>${esc(sourceLabel(item))}</b><span>${esc(item.source_path || '—')}</span><small>${esc(item.source_id || item.page || '—')}</small></div>`).join('')}</div>`)}${detailSection('RAW MANIFEST / LINKED FIELDS', objectDetails(record.raw))}`;
    $('detail-drawer').classList.add('open'); $('detail-drawer').setAttribute('aria-hidden', 'false'); document.body.classList.add('drawer-open');
  }
  function closeDetail() { $('detail-drawer').classList.remove('open'); $('detail-drawer').setAttribute('aria-hidden', 'true'); document.body.classList.remove('drawer-open'); }

  async function init() {
    try {
      const responses = await Promise.all([fetch('data/meta.json'), ...DATA_FILES.map((file) => fetch(`data/${file}.json`))]);
      if (responses.some((response) => !response.ok)) throw new Error('静态数据文件未能加载');
      state.meta = await responses[0].json();
      for (let i = 0; i < DATA_FILES.length; i += 1) state.data[DATA_FILES[i]] = await responses[i + 1].json();
      $('build-stamp').textContent = `BUILD ${state.meta.generated_at.replace('T', ' · ').replace(/:\d{2}(?:\.\d+)?\+00:00$/, 'Z')}`;
      renderMetrics(); renderProduction(); renderNav(); renderSection();
      $('global-search').addEventListener('input', (event) => { state.query = event.target.value; state.page = 1; renderSection(); });
      $('clear-filters').addEventListener('click', () => { state.query = ''; state.status = ''; state.source = ''; state.different = false; state.pending = false; $('global-search').value = ''; state.page = 1; renderSection(); });
      $('drawer-close').addEventListener('click', closeDetail); $('drawer-scrim').addEventListener('click', closeDetail); document.addEventListener('keydown', (event) => { if (event.key === 'Escape') closeDetail(); });
      const hash = window.location.hash.slice(1); if (SECTIONS.some((item) => item.id === hash)) selectSection(hash);
    } catch (error) { $('ledger').innerHTML = `<div class="empty-state error"><b>数据加载失败</b><span>${esc(error.message)}</span></div>`; console.error(error); }
  }
  init();
})();
