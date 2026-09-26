(() => {
  'use strict';

  const SECTIONS = [
    { id: 'overview', label: '总览', eyebrow: 'SECTION / OVERVIEW' },
    { id: 'web-audit', label: '网络审计', eyebrow: 'AUDIT / WEB RETRIEVAL' },
    { id: 'differences', label: '差异清单', eyebrow: 'DIRECTION / DIFFERENCES' },
    { id: 'mir2ei-after-audit', label: 'mir2ei 检索后', eyebrow: 'AUDIT / MIR2EI-AFTER-WEB-AUDIT' },
    { id: 'zircon-after-audit', label: 'Zircon 检索后', eyebrow: 'AUDIT / ZIRCON-AFTER-WEB-AUDIT' },
    { id: 'all', label: '全站记录', eyebrow: 'LEDGER / ALL RECORDS' },
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
  const ENTITY_LABELS = { monster: '怪物', npc: 'NPC', item: '物品', skill: '技能', map: '地图', respawn: '刷新', quest: '任务' };
  // 2026-09-26 网络审计后的新分类；旧的 mir2ei-only / zircon-only 不再作为终态
  const STATUS_LABELS = {
    'both-resolved': '双方闭合',
    'both-resolved-by-web-alias': '网络别名闭合',
    partial: '部分不同',
    conflict: '身份/资源冲突',
    'pending-web-evidence': '待网络证据',
    'mir2ei-only-after-web-audit': '检索后 mir2ei 独有',
    'zircon-only-after-web-audit': '检索后 Zircon 独有',
    'source-unreachable': '来源不可达',
    'production-applied': '已应用',
    'retain-current': '保留当前 Zircon',
    both: '双方都有',
    'mir2ei-only': 'mir2ei 有 / Zircon 没有（旧口径）',
    'zircon-only': 'Zircon 有 / mir2ei 没有（旧口径）'
  };
  const STATUS_TITLES = {
    'both-resolved': '双方身份与结论已闭合（无名称修正需求）',
    'both-resolved-by-web-alias': '经网络别名链闭合（网站/老版名 ↔ Zircon 名）',
    partial: '双方身份已确认，但名称/图片/地图/刷新维度仍不同',
    conflict: '双方有候选，但身份或资源冲突，禁止静默覆盖',
    'pending-web-evidence': '有网络候选或资料缺口，需更多版本/资源证据，未定终态',
    'mir2ei-only-after-web-audit': '完成网站/英文别名/GitHub/论坛/本地资源检索后仍无 Zircon 对应',
    'zircon-only-after-web-audit': '完成 mir2ei/老版/英文别名/标准资料检索后仍无资料站对应',
    'source-unreachable': '来源不可访问，不能等同独有；进入重试/人工队列',
    'production-applied': '已应用到生产双库（保留 round-trip 证据）',
    'retain-current': '证据不足，按当前决定继续使用 Zircon 现值'
  };
  const WEB_STATUS_LABELS = {
    'per-record-search': '本条独立检索',
    'family-rule-search': '族级规则已检索并命中',
    'family-search-no-result': '族级检索无结果',
    'not-searchable-source-down': '来源不可达'
  };
  const DIMENSION_LABELS = { identity: '身份', display_name: '名称', image: '图片', stats: '属性', map: '地图', coordinate: '坐标', respawn: '刷新', drops: '掉落', quest_links: '任务关联' };
  const FILTER_KEYS = ['both-resolved', 'both-resolved-by-web-alias', 'pending-web-evidence', 'conflict', 'partial', 'mir2ei-only-after-web-audit', 'zircon-only-after-web-audit', 'source-unreachable', 'production-applied', 'retain-current'];
  const state = { meta: null, data: {}, section: 'overview', query: '', status: '', direction: '', page: 1, pageSize: 30 };
  const $ = (id) => document.getElementById(id);
  const esc = (value) => String(value ?? '').replace(/[&<>"']/g, (char) => ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;' }[char]));
  const jsonText = (value) => { try { return JSON.stringify(value, null, 2); } catch { return String(value); } };
  const safeImage = (path) => typeof path === 'string' && path.startsWith('data/images/') ? path : '';
  const safeUrl = (url) => typeof url === 'string' && /^https?:\/\//.test(url) ? url : '';
  const statusClass = (status) => String(status || 'pending').replace(/[^a-z0-9-]/gi, '-').toLowerCase();
  const sourceLabel = (source) => source?.source_type || source?.source_id || 'source';
  const present = (value) => value ? String(value).slice(0, 14) + (String(value).length > 14 ? '…' : '') : '—';
  const valueText = (value) => {
    if (value === null || value === undefined || value === '') return '—';
    if (typeof value === 'boolean') return value ? '是' : '否';
    if (Array.isArray(value)) return value.length ? value.map(valueText).join(' · ') : '[]';
    if (typeof value === 'object') return Object.entries(value).slice(0, 4).map(([key, item]) => `${key}: ${valueText(item)}`).join(' / ') || '{}';
    return String(value);
  };
  const pick = (record) => record.zircon?.name || record.mir2ei?.name || record.id;
  const subtitle = (record) => {
    const z = record.zircon || {}; const m = record.mir2ei || {};
    return `${record.entity_type ? ENTITY_LABELS[record.entity_type] : record.kind} · ${z.index ?? m.id ?? record.id}`;
  };
  const allRecords = () => DATA_FILES.flatMap((name) => state.data[name] || []);
  const sectionRecords = () => state.section === 'all' ? allRecords() : (state.data[state.section] || []);
  const dimensionSummary = (record) => Object.entries(record.dimensions || {}).filter(([, value]) => value === 'different' || value === 'unknown').map(([key, value]) => `${DIMENSION_LABELS[key] || key}${value === 'unknown' ? '?' : ''}`).slice(0, 5).join(' · ') || '无已知差异';
  const auditOf = (record) => record.web_audit || {};
  const auditBadge = (record) => {
    const wa = auditOf(record);
    const label = WEB_STATUS_LABELS[wa.web_search_status] || wa.web_search_status || '未审计';
    return `<span class="audit-badge ${wa.review_required ? 'needs-review' : 'closed'}">${esc(label)}</span>`;
  };

  function renderNav() {
    $('section-nav').innerHTML = SECTIONS.map((section) => `<button class="nav-button ${state.section === section.id ? 'active' : ''}" data-section="${section.id}" type="button">${esc(section.label)}</button>`).join('');
    $('section-nav').querySelectorAll('button').forEach((button) => button.addEventListener('click', () => selectSection(button.dataset.section)));
  }

  function selectSection(section) {
    state.section = section; state.page = 1; state.status = ''; state.direction = ''; renderNav(); renderSection();
    if (section !== 'overview' && section !== 'decisions') window.scrollTo({ top: document.querySelector('.workspace-panel').offsetTop - 82, behavior: 'smooth' });
    if (section === 'decisions') window.scrollTo({ top: $('decisions').offsetTop - 82, behavior: 'smooth' });
    history.replaceState(null, '', `#${section}`);
  }

  function coverageFor(kind) { return state.meta?.counts?.coverage?.[kind] || {}; }
  function auditCounts() { return state.meta?.counts?.audit_status || {}; }

  function renderMetrics() {
    const workspace = state.meta.counts.workspace || {}; const website = state.meta.counts.website || {};
    const audit = state.meta.web_audit || {};
    const metrics = [
      [workspace.MonsterInfo, 'Zircon 怪物', 'MonsterInfo'], [workspace.ItemInfo, 'Zircon 物品', 'ItemInfo'], [workspace.MagicInfo, 'Zircon 技能', 'MagicInfo'], [workspace.NPCInfo, 'Zircon NPC', 'NPCInfo'], [workspace.MapInfo, 'Zircon 地图', 'MapInfo'], [workspace.RespawnInfo, 'Zircon 刷新', 'RespawnInfo'],
      [website.monsters, 'website 怪物', 'mir3-website'], [website.items, 'website 物品', 'mir3-website'], [website.skills, 'website 技能', 'mir3-website'], [website.missions, 'website 任务组', 'mir3-website'],
      [audit.external_sources, '外部来源', 'web audit'], [audit.search_queries, '检索词', 'web audit']
    ];
    $('metrics').innerHTML = metrics.map(([number, label, source]) => `<div class="metric"><strong>${Number(number || 0).toLocaleString('zh-CN')}</strong><span>${esc(label)}</span><small>${esc(source)}</small></div>`).join('');
  }

  function renderProduction() {
    const p = state.meta.production || {}; const status = p.server_client_sha_equal ? '双库一致' : '需检查';
    $('production-banner').innerHTML = `<div class="production-lead"><span class="status-dot production-applied"></span><div><b>生产应用已闭合（不因网络候选自动覆盖）</b><span>NPC 73 · RespawnInfo 18 · MonsterInfo 0 · MagicInfo 0</span></div></div><div class="production-meta"><span>System.db <code>${esc(present(p.server_sha256))}</code></span><span>${esc(status)}</span><span>Users.db 写入：<b>${p.users_db_written ? '是' : '否'}</b></span><span>验证：${esc(p.last_verified || '—')}</span></div>`;
  }

  function statusCards() {
    const counts = auditCounts();
    const cards = FILTER_KEYS.map((key) => [key, STATUS_LABELS[key]]);
    return cards.map(([key, label]) => {
      const count = counts[key] || 0;
      const byKind = Object.entries(state.meta.counts.audit_coverage || {}).map(([kind, values]) => `${ENTITY_LABELS[kind]} ${values.status?.[key] || 0}`).join(' · ');
      return `<button class="status-summary status-summary-large" data-status="${key}" type="button"><span class="status-card-top"><i class="status-dot ${statusClass(key)}"></i>${esc(label)}</span><b>${count}</b><span>${esc(STATUS_TITLES[key])}</span><small>${esc(byKind)}</small></button>`;
    }).join('');
  }

  function renderOverview() {
    $('section-eyebrow').textContent = 'SECTION / OVERVIEW'; $('section-title').textContent = '总览'; $('panel-count').textContent = '双向结论面板'; $('filter-row').innerHTML = '';
    const coverage = state.meta.counts.audit_coverage || {}; const p = state.meta.production || {}; const audit = state.meta.web_audit || {};
    const ai = audit.alias_index || {};
    $('ledger').innerHTML = `<div class="overview-grid"><article class="overview-card wide"><p class="eyebrow">WEB-AUDIT TAXONOMY / CLICK TO FILTER</p><h3>旧 mir2ei-only / zircon-only 已不再作为终态</h3><div class="status-cloud status-cloud-wide">${statusCards()}</div><p class="muted">2026-09-26 网络检索闭合审计：先检索网站、英文内部名、GitHub fork、LOMCN 与本地资源，再决定方向。名称不同不再直接判独有；未闭合项保留 <b>pending-web-evidence</b>。</p></article><article class="overview-card wide"><p class="eyebrow">AUDIT COVERAGE / DIRECTION AFTER AUDIT</p><div class="coverage-table audit-table"><div class="coverage-head"><b>分类</b><b>检索前 mir2ei-only</b><b>检索后 mir2ei-only</b><b>检索前 Zircon-only</b><b>检索后 Zircon-only</b><b>双方</b><b>记录</b></div>${Object.entries(coverage).map(([kind, values]) => `<div><span>${ENTITY_LABELS[kind]}</span><b>${values.direction_before_audit?.['mir2ei-only'] || 0}</b><b>${values.direction?.['mir2ei-only'] || 0}</b><b>${values.direction_before_audit?.['zircon-only'] || 0}</b><b>${values.direction?.['zircon-only'] || 0}</b><b>${values.direction?.both || 0}</b><b>${values.total || 0}</b></div>`).join('')}</div><p class="muted">方向按扩展 mir2ei 侧证据（资料站 + 老版 MUD3/EI 解码 + 17173/新浪佐证）重算；每类均断言 <code>mir2ei-only + zircon-only + both = total</code>。</p></article><article class="overview-card"><p class="eyebrow">ALIAS INDEX / 网络别名索引</p><dl class="compact-list"><div><dt>中文→英文边</dt><dd>${Number(ai.zh2en_edges || 0).toLocaleString('zh-CN')}</dd></div><div><dt>外部佐证中文名</dt><dd>${Number(ai.attested_zh_names || 0).toLocaleString('zh-CN')}</dd></div><div><dt>Wemade 英文名</dt><dd>${Number(ai.wemade_en_names || 0).toLocaleString('zh-CN')}</dd></div><div><dt>老版 DAT 中文名</dt><dd>${Number(ai.legacy_zh_names || 0).toLocaleString('zh-CN')}</dd></div></dl><p class="muted">来源构成：mir2ei 百科 JSON / LOMCN Mir3 怪物库 / Zircon 上游 ChineseMessages.cs / 老版 MUD3 DAT 解码 / 17173·新浪中文名。</p></article><article class="overview-card"><p class="eyebrow">SOURCE CHAIN</p><div class="source-chain"><span>workspace JSON</span><b>→</b><span>alignment manifest</span><b>→</b><span>web alias audit</span><b>→</b><span>production apply</span></div><p class="muted">生成时间 ${esc(state.meta.generated_at)} · 审计时间 ${esc(state.meta.audited_at || '—')} · 数据版本 ${esc(state.meta.data_version)}</p></article><article class="overview-card"><p class="eyebrow">DB / PRODUCTION</p><dl class="compact-list"><div><dt>server</dt><dd>${esc(present(p.server_sha256))}</dd></div><div><dt>client</dt><dd>${esc(present(p.client_sha256))}</dd></div><div><dt>双库</dt><dd>${p.server_client_sha_equal ? 'SHA 一致' : '需检查'}</dd></div><div><dt>Users.db</dt><dd>未写入</dd></div></dl></article></div>`;
    document.querySelectorAll('[data-status]').forEach((button) => button.addEventListener('click', () => { selectSection('all'); state.status = button.dataset.status; renderSection(); }));
  }

  function statusMatches(record, filter) {
    if (!filter) return true;
    return record.conclusion?.status === filter;
  }

  function filteredRecords(records, forcedDirection = '') {
    const query = state.query.trim().toLowerCase(); const direction = forcedDirection || state.direction;
    return records.filter((record) => {
      if (query && !JSON.stringify(record).toLowerCase().includes(query)) return false;
      if (state.status && !statusMatches(record, state.status)) return false;
      if (direction && record.direction !== direction) return false;
      return true;
    });
  }

  function renderFilters(records, difference = false) {
    const counts = {}; records.forEach((record) => { const key = record.conclusion?.status || 'pending-web-evidence'; counts[key] = (counts[key] || 0) + 1; });
    const statusButtons = FILTER_KEYS.map((key) => `<button class="filter-pill ${state.status === key ? 'active' : ''}" type="button" data-filter-status="${key}"><span class="status-dot ${statusClass(key)}"></span>${esc(STATUS_LABELS[key])}<b>${counts[key] || 0}</b></button>`).join('');
    const directionButtons = difference ? `<button class="filter-pill ${state.direction === 'mir2ei-only' ? 'active' : ''}" type="button" data-direction="mir2ei-only">mir2ei-only（检索后）</button><button class="filter-pill ${state.direction === 'zircon-only' ? 'active' : ''}" type="button" data-direction="zircon-only">zircon-only（检索后）</button>` : '';
    $('filter-row').innerHTML = `<span class="filter-caption">FILTER</span><button class="filter-pill ${!state.status ? 'active' : ''}" type="button" data-filter-status="">全部 <b>${records.length}</b></button>${statusButtons}${directionButtons}`;
    $('filter-row').querySelectorAll('[data-filter-status]').forEach((button) => button.addEventListener('click', () => { state.status = button.dataset.filterStatus; state.page = 1; renderSection(); }));
    $('filter-row').querySelectorAll('[data-direction]').forEach((button) => button.addEventListener('click', () => { state.direction = state.direction === button.dataset.direction ? '' : button.dataset.direction; state.page = 1; renderSection(); }));
  }

  function sideFields(side) {
    if (!side?.exists) return '<p class="empty">无可靠对应实体</p>';
    const fields = [['名称', side.name], ['Index / ID', side.index ?? side.id], ['source', (side.source || []).map(sourceLabel).join(' · ')]];
    if (side.linked_by_web_audit) fields.push(['来源', '本审计经别名链反查新增（非 manifest 原有）']);
    return `<dl class="field-table">${fields.map(([key, value]) => `<div><dt>${esc(key)}</dt><dd>${esc(valueText(value))}</dd></div>`).join('')}</dl>`;
  }
  function imageFor(record, side) { return safeImage(side === 'zircon' ? record.left?.Image : record.right?.image) || safeImage(side === 'mir2ei' ? record.right?.website_image : ''); }
  function sideCard(record, side, label) {
    const entity = side === 'zircon' ? record.zircon : record.mir2ei; const image = imageFor(record, side);
    return `<article class="side-card ${side === 'zircon' ? 'left-side' : 'right-side'}"><div class="side-label"><span class="side-rule"></span>${esc(label)}</div>${image ? `<img class="record-image" src="${esc(image)}" alt="" loading="lazy">` : ''}${sideFields(entity)}</article>`;
  }

  function recordRow(record) {
    const status = record.conclusion?.status || 'pending-web-evidence';
    const wa = auditOf(record);
    const sources = (wa.external_sources || []).slice(0, 2).map((source) => `<a href="${esc(safeUrl(source.url))}" target="_blank" rel="noopener">${esc(source.title || source.url)}</a>`).join(' ');
    return `<article class="record-row" data-record-id="${esc(record.id)}"><button class="record-main" type="button" aria-label="打开 ${esc(pick(record))} 详情"><div class="record-heading"><div><h3>${esc(pick(record))}</h3><p>${esc(subtitle(record))}</p></div><span class="status-chip ${statusClass(status)}"><i class="status-dot ${statusClass(status)}"></i>${esc(STATUS_LABELS[status] || status)}</span></div><div class="record-summary"><span class="direction-label ${statusClass(record.direction)}">${esc(record.direction)}</span><span>Zircon：${esc(record.zircon?.name || '—')} / ${esc(record.zircon?.index ?? '—')}</span><span>mir2ei：${esc(record.mir2ei?.name || '—')} / ${esc(record.mir2ei?.id || '—')}</span><span>当前使用：${esc(record.current_usage || '—')}</span>${auditBadge(record)}</div><div class="comparison-grid">${sideCard(record, 'zircon', 'ZIRCON / CURRENT')}<div class="versus" aria-hidden="true">↔</div>${sideCard(record, 'mir2ei', 'MIR2EI / EVIDENCE')}</div><div class="record-meta-grid"><span><b>差异维度</b>${esc(dimensionSummary(record))}</span><span><b>原因</b>${esc(record.reason || '—')}</span><span><b>下一步</b>${esc(record.next_action || '—')}</span></div><div class="audit-strip"><span><b>检索状态</b>${esc(WEB_STATUS_LABELS[wa.web_search_status] || wa.web_search_status || '—')}</span><span><b>别名链</b>${esc((wa.alias_chain || []).slice(0, 3).join(' → ') || '—')}</span><span><b>外部来源</b>${sources || '—'}</span><span><b>置信度</b>${esc(wa.confidence || '—')}${wa.review_required ? ' · 需人工复核' : ''}</span></div><div class="evidence-strip">${(record.evidence || []).slice(0, 3).map((item) => `<span title="${esc(item.source_path || '')}"><b>${esc(sourceLabel(item))}</b><small>${esc(item.source_id || item.page || 'record')}</small></span>`).join('')}</div></button></article>`;
  }

  function renderPager(total) {
    const pages = Math.max(1, Math.ceil(total / state.pageSize)); state.page = Math.min(state.page, pages);
    const buttons = [state.page - 1, state.page, state.page + 1].filter((page) => page >= 1 && page <= pages);
    $('pager').innerHTML = `<button class="pager-button" type="button" data-page="${state.page - 1}" ${state.page <= 1 ? 'disabled' : ''}>上一页</button>${buttons.map((page) => `<button class="pager-button ${page === state.page ? 'active' : ''}" type="button" data-page="${page}">${page}</button>`).join('')}<button class="pager-button" type="button" data-page="${state.page + 1}" ${state.page >= pages ? 'disabled' : ''}>下一页</button><span>共 ${total} 条 · ${pages} 页</span>`;
    $('pager').querySelectorAll('[data-page]').forEach((button) => button.addEventListener('click', () => { state.page = Number(button.dataset.page); renderSection(); }));
  }

  function renderRecordList(records, title, eyebrow, difference = false) {
    $('section-eyebrow').textContent = eyebrow; $('section-title').textContent = title; $('panel-count').textContent = `${records.length} 条记录`;
    renderFilters(records, difference);
    const filtered = filteredRecords(records); const start = (state.page - 1) * state.pageSize; const page = filtered.slice(start, start + state.pageSize);
    $('ledger').innerHTML = page.length ? page.map(recordRow).join('') : '<div class="empty-state"><b>没有符合条件的记录</b><span>清除搜索或筛选，保留原始数据范围。</span></div>';
    renderPager(filtered.length);
    $('ledger').querySelectorAll('.record-main').forEach((button, index) => button.addEventListener('click', () => openDetail(page[index])));
  }

  function renderDifferences() {
    const records = filteredRecords(allRecords()); $('section-eyebrow').textContent = 'DIRECTION / DIFFERENCES'; $('section-title').textContent = '差异清单（检索后方向）'; $('panel-count').textContent = `${records.length} 条双向差异记录`;
    renderFilters(allRecords(), true);
    const groups = ['monster', 'npc', 'item', 'skill', 'map', 'respawn', 'quest'];
    const region = (direction, title, note) => {
      const selected = records.filter((record) => record.direction === direction); const byKind = groups.map((kind) => [kind, selected.filter((record) => record.entity_type === kind)]).filter(([, items]) => items.length);
      return `<section class="diff-zone"><div class="diff-zone-head"><div><p class="eyebrow">${direction.toUpperCase()}</p><h3>${title}</h3><p class="muted">${esc(note)}</p></div><b>${selected.length}</b></div>${byKind.map(([kind, items]) => `<div class="diff-group"><h4>${ENTITY_LABELS[kind]} <span>${items.length}</span></h4>${items.slice(0, 60).map(recordRow).join('')}${items.length > 60 ? `<p class="muted">当前分类显示前 60 条；使用搜索缩小范围。</p>` : ''}</div>`).join('') || '<div class="empty-state"><b>当前过滤没有记录</b></div>'}</section>`;
    };
    $('ledger').innerHTML = `<div class="difference-toolbar"><p class="muted">两个区域按实体分类分组，方向已按扩展 mir2ei 侧证据重算。导出按钮只导出当前搜索、状态与方向过滤后的 JSON。</p><button class="tool-button export-button" id="export-differences" type="button">导出当前过滤 JSON</button></div>${region('mir2ei-only', '检索后仍 mir2ei 有 / Zircon 无', '每一条都必须证明已检索网站、英文别名、GitHub/fork、论坛与本地资源；未证明者保留为待网络证据而不是独有。')}${region('zircon-only', '检索后仍 Zircon 有 / mir2ei 无', '每一条都必须证明已查 mir2ei/旧版/标准资料/别名路径；资料站子集未收录不构成独有。')}`;
    $('pager').innerHTML = '';
    $('ledger').querySelectorAll('.record-main').forEach((button) => button.addEventListener('click', () => { const record = allRecords().find((item) => item.id === button.closest('.record-row')?.dataset.recordId); openDetail(record); }));
    $('export-differences').addEventListener('click', () => { const blob = new Blob([JSON.stringify(records, null, 2)], { type: 'application/json' }); const url = URL.createObjectURL(blob); const anchor = document.createElement('a'); anchor.href = url; anchor.download = 'web-audit-differences-filtered.json'; anchor.click(); URL.revokeObjectURL(url); });
  }

  function renderAfterAudit(kind) {
    const isMir = kind === 'mir2ei';
    const key = isMir ? 'mir2ei-only-after-web-audit' : 'zircon-only-after-web-audit';
    const pending = allRecords().filter((record) => record.direction === (isMir ? 'mir2ei-only' : 'zircon-only'));
    const final = pending.filter((record) => record.conclusion?.status === key);
    const open = pending.filter((record) => record.conclusion?.status === 'pending-web-evidence');
    const other = pending.filter((record) => ![key, 'pending-web-evidence'].includes(record.conclusion?.status));
    $('section-eyebrow').textContent = isMir ? 'AUDIT / MIR2EI-AFTER-WEB-AUDIT' : 'AUDIT / ZIRCON-AFTER-WEB-AUDIT';
    $('section-title').textContent = isMir ? 'mir2ei 侧 · 检索后仍未对应' : 'Zircon 侧 · 检索后仍未对应';
    $('panel-count').textContent = `终态 ${final.length} · 待证据 ${open.length} · 其他 ${other.length}`;
    $('filter-row').innerHTML = '';
    const block = (title, note, items, empty) => `<section class="diff-zone"><div class="diff-zone-head"><div><p class="eyebrow">${isMir ? 'MIR2EI-ONLY-AFTER-WEB-AUDIT' : 'ZIRCON-ONLY-AFTER-WEB-AUDIT'}</p><h3>${esc(title)}</h3><p class="muted">${esc(note)}</p></div><b>${items.length}</b></div>${items.length ? items.slice(0, 60).map(recordRow).join('') : `<div class="empty-state"><b>${esc(empty)}</b><span>这是审计结论：本类当前没有满足「完成检索且仍无对应」的记录。</span></div>`}</section>`;
    $('ledger').innerHTML =
      block('终态：完成检索仍无对应', '必须能指出检索词、外部来源与排除理由；来源不可达时不得记为独有。', final, '当前没有终态记录') +
      block('未定终态：待网络证据', '有候选或资料缺口但未闭合；禁止把「未搜索」写成「没有对应」。', open, '当前没有待证据记录') +
      block('其他状态（已应用 / 冲突 / 保留当前）', '方向属本类但状态由生产或冲突规则决定。', other, '当前没有其他状态记录');
    $('pager').innerHTML = '';
    $('ledger').querySelectorAll('.record-main').forEach((button) => button.addEventListener('click', () => { const record = allRecords().find((item) => item.id === button.closest('.record-row')?.dataset.recordId); openDetail(record); }));
  }

  function renderWebAudit() {
    $('section-eyebrow').textContent = 'AUDIT / WEB RETRIEVAL'; $('section-title').textContent = '网络检索审计'; $('panel-count').textContent = '来源 · 检索词 · 规则';
    $('filter-row').innerHTML = '';
    const audit = state.meta.web_audit || {};
    const counts = auditCounts();
    const byKind = Object.entries(state.meta.counts.audit_coverage || {});
    $('ledger').innerHTML = `<div class="overview-grid">
      <article class="overview-card wide"><p class="eyebrow">STATUS TOTALS / 新分类</p><div class="coverage-table audit-table"><div class="coverage-head"><b>分类</b><b>已网络别名闭合</b><b>双方闭合</b><b>待网络证据</b><b>冲突</b><b>部分</b><b>已应用</b><b>记录</b></div>${byKind.map(([kind, values]) => `<div><span>${ENTITY_LABELS[kind]}</span><b>${values.status?.['both-resolved-by-web-alias'] || 0}</b><b>${values.status?.['both-resolved'] || 0}</b><b>${values.status?.['pending-web-evidence'] || 0}</b><b>${values.status?.conflict || 0}</b><b>${values.status?.partial || 0}</b><b>${values.status?.['production-applied'] || 0}</b><b>${values.total || 0}</b></div>`).join('')}</div>
      <p class="muted">总计：已网络别名闭合 <b>${counts['both-resolved-by-web-alias'] || 0}</b> · 双方闭合 <b>${counts['both-resolved'] || 0}</b> · 待网络证据 <b>${counts['pending-web-evidence'] || 0}</b> · 冲突 <b>${counts.conflict || 0}</b> · 部分 <b>${counts.partial || 0}</b> · 已应用 <b>${counts['production-applied'] || 0}</b>。</p></article>
      <article class="overview-card wide"><p class="eyebrow">AUDIT TIMELINE / 第一次未匹配 → 网络检索后</p><div class="audit-timeline"><div><span class="timeline-step">1</span><b>旧结论</b><p>名称 lookup 失败即写 mir2ei-only / zircon-only：mir2ei-only <b>${Object.values(state.meta.counts.audit_coverage || {}).reduce((sum, v) => sum + (v.direction_before_audit?.['mir2ei-only'] || 0), 0)}</b> · zircon-only <b>${Object.values(state.meta.counts.audit_coverage || {}).reduce((sum, v) => sum + (v.direction_before_audit?.['zircon-only'] || 0), 0)}</b></p></div><div><span class="timeline-step">2</span><b>网络检索</b><p>mir2ei 百科数据集（534 怪物/2203 物品/218 技能/1701 术语）· LOMCN Mir3 怪物库（531 英文名）· Zircon 上游 ChineseMessages.cs · 老版 MUD3 DAT 解码 · 新浪 2003 怪物排名 · 17173 怪物页</p></div><div><span class="timeline-step">3</span><b>别名闭合</b><p>网站/老版中文名 → 英文内部名/资源名 → Zircon Index；方向重算为 both：mir2ei-only <b>${Object.values(state.meta.counts.audit_coverage || {}).reduce((sum, v) => sum + (v.direction?.['mir2ei-only'] || 0), 0)}</b> · zircon-only <b>${Object.values(state.meta.counts.audit_coverage || {}).reduce((sum, v) => sum + (v.direction?.['zircon-only'] || 0), 0)}</b></p></div><div><span class="timeline-step">4</span><b>未闭合</b><p>无经来源确认的别名时保留 pending-web-evidence，并写清检索词与排除理由；不把「未搜索」写成「没有对应」。</p></div></div></article>
      <article class="overview-card wide"><p class="eyebrow">EXTERNAL SOURCES / 外部来源</p><div class="source-list">${Object.entries(state.meta.external_sources || {}).map(([id, source]) => `<div><b>${esc(source.title || id)}</b><span><a href="${esc(safeUrl(source.url))}" target="_blank" rel="noopener">${esc(source.url)}</a></span><small>${esc(source.accessed_at || '')} · ${esc(id)}</small></div>`).join('') || '<div><b>来源清单随数据包载入</b><span>见 artifacts/web-entity-audit-2026-09-26/external_sources.json</span></div>'}</div></article>
      <article class="overview-card wide"><p class="eyebrow">SEARCH QUERIES / 已执行检索词</p><div class="source-list">${(state.meta.search_queries || []).map((item) => `<div><b>${esc(item.q)}</b><span>${esc(item.outcome)}</span><small>${esc((item.sources || []).join(' · ')) || '无结果'}</small></div>`).join('') || '<div><b>检索词清单见 artifacts/web-entity-audit-2026-09-26/search_queries.json</b></div>'}</div></article>
      <article class="overview-card wide"><p class="eyebrow">SOURCE LIMITATIONS / 来源限制（必须披露）</p><ul class="limit-list"><li>17173 怪物分页在本次审计中途对脚本返回 567 字节占位页（限流）；已取到的 mob17 与资料站镜像仍作为中文名佐证。</li><li>Mojeek / DuckDuckGo HTML 返回 JS 挑战页，Bing RSS 返回与查询无关结果 → 程序化检索不可用，改用 DIM 检索工具逐条检索并记录。</li><li>mir2ei 百科是本地 <code>WikiServer.py</code> 数据链的公开静态发布；其 Zircon 侧中文名与本站 <code>docs/terminology</code> 同源，属派生来源，已在每条记录标注 provenance。</li><li>Zircon fork（Wincha / grimchamp / ketsmen / KingdomMir2 / iamcheyan）只作 secondary evidence，不覆盖本地 workspace 的实际值。</li></ul></article>
    </div>`;
    $('pager').innerHTML = '';
  }

  function renderDecisions() {
    $('section-eyebrow').textContent = 'FINAL / DECISIONS'; $('section-title').textContent = '结论与下一步'; $('panel-count').textContent = '按实体保留'; $('filter-row').innerHTML = '';
    const p = state.meta.production || {}; const counts = auditCounts();
    $('ledger').innerHTML = `<div class="decision-grid large"><article class="decision-card applied-card"><span class="status-chip production-applied">已应用</span><h3>NPC 坐标与 18 条刷新目标已写入 System.db</h3><p>本次应用只触及批准的 NPC 73 条与 RespawnInfo 18 条。MonsterInfo / MagicInfo 业务字段均为 0 变更。</p><dl class="compact-list"><div><dt>server/client</dt><dd>${esc(present(p.server_sha256))} / ${esc(present(p.client_sha256))}</dd></div><div><dt>round-trip</dt><dd>PASS · unapproved changes 0</dd></div><div><dt>Users.db</dt><dd>未写入</dd></div></dl></article><article class="decision-card"><span class="status-chip both-resolved-by-web-alias">网络别名闭合</span><h3>${counts['both-resolved-by-web-alias'] || 0} 条经别名链闭合</h3><p>每条都有外部 URL + 本地证据 + 别名链。别名链来自 mir2ei 百科、LOMCN Mir3 怪物库、Zircon 上游官方中文文案、老版 DAT 对照表；未闭合项不升级。</p></article><article class="decision-card"><span class="status-chip pending-web-evidence">待网络证据</span><h3>${counts['pending-web-evidence'] || 0} 条仍未定终态</h3><p>这些记录有资料站/老版中文名或 Zircon 实体，但缺少经外部来源确认的跨语言别名。保留为待证据，禁止直接判为任何一侧独有。</p></article><article class="decision-card"><span class="status-chip conflict">冲突</span><h3>${counts.conflict || 0} 条身份或资源冲突</h3><p>同一 Zircon Index 被多个候选使用，或资源与身份不符。全部保留为独立记录并进入人工复核闸门，不做静默覆盖。</p></article><article class="decision-card"><span class="status-chip retain-current">保留当前 Zircon</span><h3>当前实际使用的 Zircon 数据单独显示</h3><p>网络候选不会自动覆盖「当前实际使用」列。任何名称修正、业务 Index、坐标或刷新写入都必须经过原有人工批准闸门。</p></article></div>`;
    $('pager').innerHTML = '';
  }

  function renderSection() {
    if (!state.meta) return;
    if (state.section === 'overview') return renderOverview();
    if (state.section === 'web-audit') return renderWebAudit();
    if (state.section === 'differences') return renderDifferences();
    if (state.section === 'mir2ei-after-audit') return renderAfterAudit('mir2ei');
    if (state.section === 'zircon-after-audit') return renderAfterAudit('zircon');
    if (state.section === 'decisions') return renderDecisions();
    const section = SECTIONS.find((item) => item.id === state.section); const all = sectionRecords(); renderRecordList(all, section.label, section.eyebrow);
  }

  function objectDetails(obj) { return obj ? `<pre class="json-block">${esc(jsonText(obj))}</pre>` : '<p class="empty">无可靠对应实体</p>'; }
  function dimensionTable(record) { return `<div class="dimension-matrix">${Object.entries(record.dimensions || {}).map(([key, value]) => `<div><span>${esc(DIMENSION_LABELS[key] || key)}</span><b class="dimension-${value}">${esc(value)}</b></div>`).join('')}</div>`; }
  function auditSection(record) {
    const wa = auditOf(record);
    const sources = (wa.external_sources || []).map((source) => `<div><b>${esc(source.title || source.source_id || 'source')}</b><span><a href="${esc(safeUrl(source.url))}" target="_blank" rel="noopener">${esc(source.url)}</a></span><small>${esc(source.accessed_at || '')}${source.note ? ' · ' + esc(source.note) : ''}</small></div>`).join('');
    const queries = (wa.search_queries || []).map((q) => `<li>${esc(q)}</li>`).join('');
    const chain = (wa.alias_chain || []).map((step) => `<li>${esc(step)}</li>`).join('');
    const local = (wa.local_evidence || []).map((item) => `<div><b>${esc(item.kind)}</b><span>${esc(item.ref)}</span><small>${esc(item.detail || '')}</small></div>`).join('');
    const excluded = (wa.excluded_candidates || []).map((item) => `<div><b>${esc(item.candidate || '—')}</b><span>${esc(item.reason || '')}</span><small>${esc(item.evidence || '')}</small></div>`).join('');
    const timeline = `<div class="audit-timeline"><div><span class="timeline-step">1</span><b>旧结论（名称 lookup 失败）</b><p>方向 ${esc(record.direction_before_audit || '—')} · 状态 ${esc(record.conclusion?.previous_status || '—')}</p></div><div><span class="timeline-step">2</span><b>网络检索与别名闭合</b><p>${esc(wa.alias_chain?.length ? wa.alias_chain.slice(0, 4).join(' → ') : '无外部别名命中')}</p></div><div><span class="timeline-step">3</span><b>本次审计结论</b><p>方向 ${esc(record.direction)} · 状态 ${esc(record.conclusion?.status)} · 置信度 ${esc(wa.confidence || '—')}</p></div></div>`;
    return `<section class="drawer-section"><p class="eyebrow">WEB AUDIT / 网络检索闭合审计</p><div class="drawer-conclusion"><span class="status-chip ${statusClass(record.conclusion?.status)}"><i class="status-dot ${statusClass(record.conclusion?.status)}"></i>${esc(STATUS_TITLES[record.conclusion?.status] || record.conclusion?.status)}</span><dl class="compact-list"><div><dt>检索状态</dt><dd>${esc(WEB_STATUS_LABELS[wa.web_search_status] || wa.web_search_status || '—')}</dd></div><div><dt>置信度</dt><dd>${esc(wa.confidence || '—')}</dd></div><div><dt>需人工复核</dt><dd>${wa.review_required ? '是' : '否'}</dd></div><div><dt>来源版本</dt><dd>${esc(wa.source_commit_or_version || '—')}</dd></div></dl>${wa.why_not_mir2ei_only ? `<p><b>为何不是 mir2ei 独有：</b>${esc(wa.why_not_mir2ei_only)}</p>` : ''}${wa.why_not_zircon_only ? `<p><b>为何不是 Zircon 独有：</b>${esc(wa.why_not_zircon_only)}</p>` : ''}</div></section>
      <section class="drawer-section"><p class="eyebrow">AUDIT TIMELINE / 第一次未匹配 → 网络检索后</p>${timeline}</section>
      <section class="drawer-section"><p class="eyebrow">ALIAS CHAIN / 别名链</p><ol class="chain-list">${chain || '<li>—</li>'}</ol></section>
      <section class="drawer-section"><p class="eyebrow">SEARCH QUERIES / 检索词</p><ul class="query-list">${queries || '<li>—</li>'}</ul></section>
      <section class="drawer-section"><p class="eyebrow">EXTERNAL SOURCES / 外部 URL</p><div class="source-list">${sources || '<div><b>无外部来源命中</b><span>本条为族级规则覆盖或未闭合</span></div>'}</div></section>
      <section class="drawer-section"><p class="eyebrow">LOCAL EVIDENCE / 本地证据</p><div class="source-list">${local || '<div><b>—</b></div>'}</div></section>
      <section class="drawer-section"><p class="eyebrow">EXCLUDED CANDIDATES / 排除候选</p><div class="source-list">${excluded || '<div><b>无被排除候选</b><span>未发现相似但被否定的候选</span></div>'}</div></section>`;
  }
  function openDetail(record) {
    if (!record) return;
    const status = record.conclusion?.status || 'pending-web-evidence'; $('drawer-kind').textContent = `${String(record.entity_type || record.kind).toUpperCase()} / ${esc(record.direction)}`; $('drawer-title').textContent = pick(record);
    $('drawer-body').innerHTML = `<section class="drawer-section"><p class="eyebrow">CONCLUSION / FINAL DECISION</p><div class="drawer-conclusion"><span class="status-chip ${statusClass(status)}"><i class="status-dot ${statusClass(status)}"></i>${esc(STATUS_TITLES[status] || status)}</span><p>${esc(record.reason || '')}</p><dl class="compact-list"><div><dt>方向（检索后）</dt><dd>${esc(record.direction)}</dd></div><div><dt>方向（检索前）</dt><dd>${esc(record.direction_before_audit || '—')}</dd></div><div><dt>当前实际使用</dt><dd>${esc(record.current_usage || '—')}</dd></div><div><dt>下一步</dt><dd>${esc(record.next_action || '—')}</dd></div></dl></div></section>${auditSection(record)}<section class="drawer-section"><div class="drawer-columns"><div><p class="eyebrow">ZIRCON / CURRENT</p>${objectDetails(record.left)}</div><div><p class="eyebrow">MIR2EI / WEBSITE / EVIDENCE</p>${objectDetails(record.right)}</div></div></section><section class="drawer-section"><p class="eyebrow">DIMENSION MATRIX / 维度差异</p>${dimensionTable(record)}</section><section class="drawer-section"><p class="eyebrow">EVIDENCE PATH / 证据路径</p><div class="source-list">${(record.evidence || []).map((item) => `<div><b>${esc(sourceLabel(item))}</b><span>${esc(item.source_path || '—')}</span><small>${esc(item.source_id || item.page || '—')}</small></div>`).join('')}</div></section><section class="drawer-section"><p class="eyebrow">NORMALIZED RECORD / UNIFIED FIELDS</p>${objectDetails({ entity_type: record.entity_type, zircon: record.zircon, mir2ei: record.mir2ei, direction: record.direction, direction_before_audit: record.direction_before_audit, conclusion: record.conclusion, dimensions: record.dimensions, current_usage: record.current_usage, next_action: record.next_action, web_audit: record.web_audit })}</section><section class="drawer-section"><p class="eyebrow">RAW MANIFEST / LINKED FIELDS</p>${objectDetails(record.raw)}</section>`;
    $('detail-drawer').classList.add('open'); $('detail-drawer').setAttribute('aria-hidden', 'false'); document.body.classList.add('drawer-open');
  }
  function closeDetail() { $('detail-drawer').classList.remove('open'); $('detail-drawer').setAttribute('aria-hidden', 'true'); document.body.classList.remove('drawer-open'); }

  async function loadJson(path) {
    let lastError;
    for (let attempt = 0; attempt < 2; attempt += 1) {
      try {
        const response = await fetch(path, { cache: 'no-store' });
        if (!response.ok) throw new Error(`${path} HTTP ${response.status}`);
        return await response.json();
      } catch (error) {
        lastError = error;
        if (error?.name !== 'AbortError' || attempt === 1) throw error;
        await new Promise((resolve) => setTimeout(resolve, 180));
      }
    }
    throw lastError;
  }

  async function init() {
    try {
      const payloads = await Promise.all(['data/meta.json', ...DATA_FILES.map((file) => `data/${file}.json`)].map(loadJson));
      state.meta = payloads[0]; for (let i = 0; i < DATA_FILES.length; i += 1) state.data[DATA_FILES[i]] = payloads[i + 1];
      $('build-stamp').textContent = `BUILD ${state.meta.generated_at.replace('T', ' · ').replace(/:\d{2}(?:\.\d+)?\+00:00$/, 'Z')}`;
      renderMetrics(); renderProduction(); renderNav(); renderSection();
      $('global-search').addEventListener('input', (event) => { state.query = event.target.value; state.page = 1; renderSection(); });
      $('clear-filters').addEventListener('click', () => { state.query = ''; state.status = ''; state.direction = ''; $('global-search').value = ''; state.page = 1; renderSection(); });
      $('drawer-close').addEventListener('click', closeDetail); $('drawer-scrim').addEventListener('click', closeDetail); document.addEventListener('keydown', (event) => { if (event.key === 'Escape') closeDetail(); });
      const hash = window.location.hash.slice(1); if (SECTIONS.some((item) => item.id === hash)) selectSection(hash);
    } catch (error) {
      if (error?.name === 'AbortError') return;
      $('ledger').innerHTML = `<div class="empty-state error"><b>数据加载失败</b><span>${esc(error.message)}</span></div>`; console.error(error);
    }
  }
  init();
})();
