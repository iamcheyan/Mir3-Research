/* dbeditor 模板 —— 以 JS 字符串提供（绕开 in-DOM 模板的自闭合/大小写限制） */
window.APP_TEMPLATE = `
<div class="layout">
  <div class="topbar">
    <h3 style="margin:0">System.db 编辑器</h3>
    <el-tag size="small" type="info">基线 v{{ status.baseline && status.baseline.version ? status.baseline.version : '?' }}</el-tag>
    <el-tag size="small" :type="status.server_running ? 'danger' : 'success'">
      {{ status.server_running ? '服务端运行中（禁同步）' : '服务端已停止（可同步）' }}
    </el-tag>
    <div class="spacer"></div>
    <el-badge v-if="!isMobile" :value="changeCount" :hidden="!changeCount" type="warning">
      <el-button @click="openChanges">改动追踪</el-button>
    </el-badge>
    <el-button v-if="!isMobile" type="primary" @click="doSync" :disabled="!!status.server_running">同步到数据库</el-button>
  </div>
  <div class="layout-body">
    <div class="sidebar">
      <div v-for="c in cats" :key="c.key" class="cat"
           :class="{ active: activeCat === c.key }" @click="switchCat(c.key)">
        <span>{{ c.zh }}</span><el-tag size="small" type="info">{{ c.count }}</el-tag>
      </div>
    </div>

    <div class="main" v-loading="loading">
      <!-- 列表 -->
      <template v-if="view === 'list'">
        <div class="toolbar" style="display:flex; gap:10px; margin-bottom:10px; align-items:center">
          <el-input v-model="query" placeholder="搜索：名称 / 中文名 / Index" clearable
                    style="width:320px" @keyup.enter="search" @clear="search">
            <template #append><el-button @click="search"><el-icon><search /></el-icon></el-button></template>
          </el-input>
          <el-button @click="createRow" type="success" plain>新增</el-button>
          <el-button @click="openBulk" type="warning" plain>批量修改</el-button>
          <div style="flex:1"></div>
          <span class="hint" style="color:#909399; font-size:12px">
            {{ total }} 行 · 保存只写 JSON 工作区 + git，写库须点「同步到数据库」
          </span>
        </div>
        <!-- 分类筛选：所有可用轴（物品=类型/稀有度/职业…，怪物=BOSS/不死/AI…，技能=职业/系别…） -->
        <div v-if="activeFacets.length" class="facet-bar" :class="{ 'facet-collapsed': isMobile && !facetOpen }">
          <button v-if="isMobile" class="facet-toggle" type="button" @click="facetOpen = !facetOpen">
            筛选({{ selectedFacetCount }}) <span>{{ facetOpen ? '▴' : '▾' }}</span>
          </button>
          <div v-show="!isMobile || facetOpen" class="facet-content">
            <div v-for="fc in activeFacets" :key="fc.field" class="facet-group">
              <div class="facet-title">{{ fc.zh }}</div>
              <div class="facet-values">
                <span v-for="pair in (fc.values || []).slice(0, 24)" :key="pair[0]"
                      class="facet-chip" :class="{ on: facetSel[fc.field] && facetSel[fc.field].has(pair[0]) }"
                      @click="toggleFacet(fc.field, pair[0])">
                  {{ pair[0] }}<i v-if="pair[1]" style="opacity:.55; font-style:normal; font-size:10px"> {{ pair[1] }}</i>
                </span>
              </div>
            </div>
          </div>
        </div>

        <el-table v-if="!isMobile" :data="rows" border stripe @sort-change="resort" height="calc(100vh - 190px)"
                  @selection-change="s => selection = s">
          <el-table-column type="selection" width="42"></el-table-column>
          <el-table-column v-for="c in listCols" :key="c.prop" :prop="c.prop"
                           :label="c.label" :width="c.width" :sortable="c.sortable">
            <template #default="scope">
              <img v-if="c.prop === '__icon' && rowIcon(scope.row) && !scope.row.__noicon"
                   :src="rowIcon(scope.row)" class="cell-icon"
                   @error="iconError(scope.row)" />
              <span v-else-if="c.prop === '__icon'" style="color:#c0c4cc">—</span>
              <span v-else-if="c.prop === '__name'" class="clickable"
                    @click="openDetail(scope.row.Index)">{{ displayCell(scope.row, c.prop) }}</span>
              <span v-else>{{ displayCell(scope.row, c.prop) }}</span>
            </template>
          </el-table-column>
          <el-table-column label="操作" width="180" fixed="right">
            <template #default="scope">
              <el-button size="small" @click="openDetail(scope.row.Index)">编辑</el-button>
              <el-button size="small" @click="duplicateRow(scope.row.Index)">复制</el-button>
              <el-button size="small" type="danger" @click="deleteRow(scope.row.Index)">删</el-button>
            </template>
          </el-table-column>
        </el-table>
        <!-- 手机卡片列表：图标 + 英文名 + 中文名，点击进详情（只看效果优先） -->
        <div v-else class="card-list">
          <div v-for="r in rows" :key="r.Index" class="card-item" @click="openDetail(r.Index)">
            <img v-if="rowIcon(r) && !r.__noicon" :src="rowIcon(r)" @error="iconError(r)" />
            <img v-else src="" style="display:none" />
            <div class="ci-main">
              <div class="ci-name">{{ rowName(activeCat, r) }}</div>
              <div class="ci-zh" v-if="r.__zh && r.__zh !== rowName(activeCat, r)">{{ r.__zh }}</div>
            </div>
            <div class="ci-idx">#{{ r.Index }}</div>
          </div>
        </div>
        <el-pagination style="margin-top:10px" :small="isMobile"
          v-model:current-page="page" :page-size="per" :total="total"
          :layout="isMobile ? 'prev, pager, next' : 'total, prev, pager, next, jumper'"
          @current-change="loadTable" />
      </template>

      <!-- 详情 -->
      <template v-else-if="view === 'detail'">
        <div class="detail-bar" style="display:flex; align-items:center; gap:10px; margin-bottom:12px">
          <el-button v-if="!isMobile" @click="backToList">← 返回</el-button>
          <h3 style="margin:0">{{ catZh }} #{{ detail.index }}</h3>
          <el-tag v-if="detail.dirty" type="warning">未保存</el-tag>
          <div style="flex:1"></div>
          <el-button v-if="!isMobile" type="primary" @click="saveDetail" :disabled="!detail.dirty">保存</el-button>
        </div>

        <div v-if="detail.table === 'ItemInfo' && rowIcon(detail.row)"
             style="display:flex; align-items:center; gap:10px; margin-bottom:10px">
          <img :src="rowIcon(detail.row)" @error="iconError(detail.row)" class="big-icon" />
          <span style="color:#909399; font-size:12px">Image = {{ detail.row.Image }}</span>
        </div>

        <!-- 怪物详情：大图 + 动作帧预览（站立/行走/攻击，Mon-N.Zl 按 MonsterLookup 映射） -->
        <div v-if="detail.table === 'MonsterInfo' && rowIcon(detail.row)"
             style="margin-bottom:10px">
          <div style="display:flex; align-items:center; gap:10px; margin-bottom:8px">
            <img :src="rowIcon(detail.row)" @error="iconError(detail.row)" class="big-icon"
                 style="width:64px; height:64px; image-rendering:pixelated; background:#111; border-radius:6px; object-fit:contain" />
            <span style="color:#909399; font-size:12px">
              {{ detail.row.Image }} → {{ detail.row.__lib }} 帧 {{ detail.row.__frame }}（站立·正面）
            </span>
          </div>
          <div v-if="detail.row.__actions && detail.row.__actions.length"
               style="display:flex; gap:4px; flex-wrap:wrap; align-items:flex-end;
                      background:#111; padding:8px; border-radius:6px; max-width:640px">
            <img v-for="(a, i) in detail.row.__actions" :key="i"
                 :src="monActionSrc(a)" :title="a.label" @error="e => e.target.style.display='none'"
                 style="width:40px; height:48px; image-rendering:pixelated; object-fit:contain" />
          </div>
          <div style="color:#909399; font-size:11px; margin-top:4px">动作序列：站立4帧·8方向 → 行走6帧·8方向 → 攻击6帧·8方向</div>
        </div>

        <!-- 技能详情：大图（MIcon.Zl） -->
        <div v-if="detail.table === 'MagicInfo' && rowIcon(detail.row)"
             style="display:flex; align-items:center; gap:10px; margin-bottom:10px">
          <img :src="rowIcon(detail.row)" @error="iconError(detail.row)" class="big-icon"
               style="width:64px; height:64px; image-rendering:pixelated; background:#111; border-radius:6px; object-fit:contain" />
          <span style="color:#909399; font-size:12px">Icon = {{ detail.row.Icon }}（MIcon.Zl）</span>
        </div>

        <el-form label-width="180px" label-position="left">
          <el-row>
            <el-col v-for="f in mainFields" :key="f.key" :span="8">
              <el-form-item>
                <template #label>
                  <span :title="f.key">{{ f.zh }}</span>
                  <div class="field-label-zh">{{ f.key }}</div>
                </template>
                <el-input-number v-if="f.type === 'int' || f.type === 'float' || f.type === 'number'"
                                 v-model="detail.row[f.key]" :controls="false" style="width:100%"
                                 @change="markDirty" />
                <el-switch v-else-if="f.type === 'bool'" v-model="detail.row[f.key]" @change="markDirty" />
                <el-select v-else-if="f.type === 'enum'" v-model="detail.row[f.key]"
                           filterable allow-create default-first-option style="width:100%" @change="markDirty">
                  <el-option v-for="m in (enums[f.to] || [])" :key="m" :label="m" :value="m"></el-option>
                </el-select>
                <el-select v-else-if="f.kind === 'ref'" v-model="detail.row[f.key].Index"
                           filterable style="width:100%" @change="markDirty">
                  <el-option v-for="o in (refOptions[f.key] || [])" :key="o.Index"
                             :label="o.Name + (o.zh && o.zh !== o.Name ? '（' + o.zh + '）' : '') + ' #' + o.Index"
                             :value="o.Index"></el-option>
                </el-select>
                <div v-else-if="f.kind === 'stats'" class="stat-editor" style="width:100%">
                  <div v-for="(s, i) in (detail.row[f.key] || [])" :key="i"
                       style="display:flex; gap:6px; margin-bottom:4px">
                    <el-select v-model="s.Stat" filterable style="flex:1" @change="markDirty">
                      <el-option v-for="m in (refOptions[f.key] || [])" :key="m" :label="m" :value="m"></el-option>
                    </el-select>
                    <el-input-number v-model="s.Value" :controls="false" style="width:110px" @change="markDirty" />
                    <el-button @click="detail.row[f.key].splice(i, 1); markDirty()">✕</el-button>
                  </div>
                  <el-button size="small" @click="detail.row[f.key].push({Stat: 'MaxHP', Value: 0}); markDirty()">+ 属性</el-button>
                </div>
                <el-input v-else-if="f.type === 'string'" v-model="detail.row[f.key]" @input="markDirty" />
                <span v-else class="mono">{{ JSON.stringify(detail.row[f.key]) }}</span>
              </el-form-item>
            </el-col>
          </el-row>
        </el-form>

        <template v-for="(v, t) in detail.subs" :key="t">
          <div class="sub-title">
            <h4>{{ subZh(t) }}
              <el-tag size="small" type="info">{{ v.rows.length }}</el-tag>
            </h4>
            <el-button v-if="!subReadonly(t)" size="small" @click="addSubRow(t)">+ 行</el-button>
          <div class="sub-table-wrap">
          <el-table :data="v.rows" border size="small" max-height="360">
            <el-table-column type="index" width="42" label="#"></el-table-column>
            <el-table-column v-for="c in subEditableCols(t)" :key="c.key"
                             :label="c.zh" min-width="130">
              <template #default="scope">
                <template v-if="v.readonly">
                  <span v-if="scope.row[c.key] !== null && scope.row[c.key] !== undefined">
                    {{ typeof scope.row[c.key] === 'object'
                        ? (scope.row[c.key].Name !== undefined ? scope.row[c.key].Name : JSON.stringify(scope.row[c.key]))
                        : scope.row[c.key] }}
                  </span>
                </template>
                <el-select v-else-if="c.type === 'ref'" v-model="scope.row[c.key].Index"
                           filterable size="small" @change="markDirty">
                  <el-option v-for="o in (refOptions[t + '.' + c.key] || [])" :key="o.Index"
                             :label="o.Name + (o.zh && o.zh !== o.Name ? '（' + o.zh + '）' : '') + ' #' + o.Index"
                             :value="o.Index"></el-option>
                </el-select>
                <el-select v-else-if="c.type === 'enum'" v-model="scope.row[c.key]"
                           filterable allow-create default-first-option size="small" @change="markDirty">
                  <el-option v-for="m in (refOptions[t + '.' + c.key] || [])" :key="m" :label="m" :value="m"></el-option>
                </el-select>
                <el-switch v-else-if="c.type === 'bool'" v-model="scope.row[c.key]" size="small" @change="markDirty" />
                <el-input-number v-else-if="c.type === 'int'" v-model="scope.row[c.key]"
                                 :controls="false" size="small" style="width:100%" @change="markDirty" />
                <el-input v-else-if="c.type === 'string'" v-model="scope.row[c.key]"
                          size="small" @input="markDirty" />
                <span v-else class="mono">{{ JSON.stringify(scope.row[c.key]) }}</span>
              </template>
            </el-table-column>
            <el-table-column v-if="!v.readonly" label="操作" width="70">
              <template #default="scope">
                <el-button size="small" type="danger" @click="delSubRow(t, scope.$index)">✕</el-button>
              </template>
            </el-table-column>
          </el-table>
          </div>
        </template>
      </template>

      <!-- 改动 -->
      <template v-else-if="view === 'changes'">
        <div style="display:flex; align-items:center; gap:10px; margin-bottom:12px">
          <el-button v-if="!isMobile" @click="backToList">← 返回</el-button>
          <h3 style="margin:0">改动追踪</h3>
          <el-tag type="danger">新增 {{ changesData ? changesData.summary.added : 0 }}</el-tag>
          <el-tag type="warning">修改 {{ changesData ? changesData.summary.modified : 0 }}</el-tag>
          <el-tag type="info">删除 {{ changesData ? changesData.summary.deleted : 0 }}</el-tag>
        </div>
        <template v-for="(entries, t) in (changesData ? changesData.tables : {})" :key="t">
          <div class="sub-table-wrap">
          <el-table :data="entries" border size="small">
            <el-table-column prop="index" label="Index" width="100"></el-table-column>
            <el-table-column prop="op" label="操作" width="90">
              <template #default="scope">
                <el-tag size="small"
                        :type="scope.row.op === 'added' ? 'danger' : (scope.row.op === 'deleted' ? 'info' : 'warning')">
                  {{ scope.row.op === 'added' ? '新增' : (scope.row.op === 'deleted' ? '删除' : '修改') }}
                </el-tag>
              </template>
            </el-table-column>
            <el-table-column label="字段变化">
              <template #default="scope">
                <div v-if="scope.row.fields">
                  <div v-for="(ch, k) in scope.row.fields" :key="k" class="mono">
                    <b>{{ k }}</b>：
                    <span class="diff-old">{{ fmtVal(ch.old) }}</span>
                    <span class="diff-new">{{ fmtVal(ch.new) }}</span>
                  </div>
                </div>
                <span v-else style="color:#909399">
                  {{ scope.row.op === 'added' ? '（整行新增）' : '（整行删除）' }}
                </span>
              </template>
            </el-table-column>
            <el-table-column label="操作" width="110">
              <template #default="scope">
                <el-button size="small" @click="rollbackRow(t, scope.row.index)">回滚</el-button>
              </template>
          </el-table>
          </div>
        </template>
        <el-empty v-if="!changeCount" description="工作区与基线一致，无改动"></el-empty>
      </template>
    </div>

  <!-- 手机底部常驻操作栏（DBE-P0-01：保存/撤销/同步 390px 下始终可见） -->
  <div v-if="isMobile" class="mobile-actions">
    <template v-if="view === 'detail'">
      <el-button class="ma-btn" @click="backToList">← 返回</el-button>
      <el-tag v-if="detail.dirty" type="warning" class="ma-dirty">未保存</el-tag>
      <div style="flex:1"></div>
      <el-button class="ma-btn" type="primary" @click="saveDetail" :disabled="!detail.dirty">保存</el-button>
    </template>
    <template v-else-if="view === 'changes'">
      <el-button class="ma-btn" @click="backToList">← 返回列表</el-button>
    </template>
    <template v-else>
      <el-button class="ma-btn" @click="openChanges">改动追踪 ({{ changeCount }})</el-button>
      <el-button class="ma-btn" type="primary" @click="doSync" :disabled="!!status.server_running">同步到数据库</el-button>
    </template>
  </div>
  </div>
</div>

<el-dialog v-model="bulkDialog.visible" title="批量修改" width="460px">
  <el-form label-width="90px">
    <el-form-item label="目标字段">
      <el-select v-model="bulkDialog.field" filterable>
        <el-option v-for="f in bulkDialog.fields" :key="f.key"
                   :label="f.zh + ' (' + f.key + ')'" :value="f.key"></el-option>
      </el-select>
    </el-form-item>
    <el-form-item v-if="bulkFieldDef" label="新值">
      <el-switch v-if="bulkFieldDef.type === 'bool'" v-model="bulkDialog.value" />
      <el-select v-else-if="bulkFieldDef.type === 'enum'" v-model="bulkDialog.value"
                 filterable allow-create default-first-option>
        <el-option v-for="m in bulkEnums" :key="m" :label="m" :value="m"></el-option>
      </el-select>
      <el-input v-else-if="bulkFieldDef.type === 'string'" v-model="bulkDialog.value" />
      <el-input-number v-else v-model="bulkDialog.value" :controls="false" style="width:200px" />
    </el-form-item>
  </el-form>
  <template #footer>
    <el-button @click="bulkDialog.visible = false">取消</el-button>
    <el-button type="primary" @click="runBulk">应用（{{ selection.length }} 行）</el-button>
  </template>
</el-dialog>

<el-dialog v-model="syncDialog.visible" title="同步到数据库" width="720px">
  <div v-if="syncDialog.running" v-loading="true" style="height:120px"
       element-loading-text="导入器执行中：校验 → 备份 → 双库写入 → 读回验证…"></div>
  <template v-else-if="syncDialog.result">
    <el-result v-if="syncDialog.result.ok && !syncDialog.result.skipped"
               icon="success" title="同步完成"></el-result>
    <el-result v-else-if="syncDialog.result.skipped" icon="info"
               :title="'跳过：' + syncDialog.result.skipped"></el-result>
    <el-result v-else icon="error" title="同步失败"
               :sub-title="syncDialog.result.error || syncDialog.result.stderr"></el-result>
    <pre v-if="syncDialog.result.report" class="mono report">{{ syncDialog.result.report }}</pre>
  </template>
</el-dialog>
`;
