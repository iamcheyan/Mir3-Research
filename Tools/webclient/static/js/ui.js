// ui.js — 面板: GM / 技能 / 装备 / 设置 / 大地图 / 聊天 / 腰带 / 自动药水 / 对象信息
import { D } from './data.js';
import { spriteURL, loadSprite } from './res.js';

const CLASS_NAMES = { Warrior: '战士', Wizard: '法师', Taoist: '道士', Assassin: '刺客' };
const CLASSES = ['Warrior', 'Wizard', 'Taoist', 'Assassin'];
const RESOLUTIONS = [
  [1280, 720], [1600, 900], [1920, 1080], [2560, 1440], [3840, 2160],
];

export class UI {
  constructor(game) {
    this.game = game;
    this.$ = (id) => document.getElementById(id);
    this.belt = Array.from({ length: 8 }, () => ({ item: null, cdUntil: 0 }));
    this._bind();
  }

  _bind() {
    const g = this.game;
    document.querySelectorAll('.tb-btn[data-panel]').forEach((b) => {
      b.addEventListener('click', () => this.togglePanel(b.dataset.panel));
    });
    this.$('btn-bigmap').addEventListener('click', () => this.toggleBigmap());
    this.chatInput = this.$('chat-input');
    this.chat = this.$('chat');
    this.chatInput.addEventListener('keydown', (e) => {
      if (e.key === 'Enter') {
        const v = this.chatInput.value.trim();
        if (v) g.execCommand(v);
        this.chatInput.value = '';
      } else if (e.key === 'Escape') {
        this.chatInput.blur();
        this.chat.classList.remove('cmd-open');
      }
      e.stopPropagation();
    });
    document.querySelectorAll('.panel .close').forEach((b) => {
      b.addEventListener('click', () => b.closest('.panel').classList.add('hidden'));
    });
    document.querySelectorAll('.belt-slot').forEach((el, i) => {
      el.addEventListener('click', () => this.useBeltSlot(i));
    });
    const hp = this.$('ap-hp'), mp = this.$('ap-mp');
    hp.addEventListener('input', () => { this.$('ap-hp-v').textContent = hp.value + '%'; g.settings.autoPotHp = +hp.value; g.saveSettings(); });
    mp.addEventListener('input', () => { this.$('ap-mp-v').textContent = mp.value + '%'; g.settings.autoPotMp = +mp.value; g.saveSettings(); });
    this.$('ap-on').addEventListener('change', (e) => { g.settings.autoPot = e.target.checked; g.saveSettings(); });
    // 点击画布空白处关闭信息浮窗
    this.$('game').addEventListener('click', () => this.$('objinfo').classList.add('hidden'));
  }

  log(msg, cls = 'sys') {
    const el = document.createElement('div');
    el.className = cls;
    el.textContent = msg;
    const logEl = this.$('chat-log');
    logEl.appendChild(el);
    while (logEl.children.length > 80) logEl.removeChild(logEl.firstChild);
    logEl.scrollTop = logEl.scrollHeight;
  }

  toast(msg) {
    const t = this.$('pickup-toast');
    t.textContent = msg;
    t.style.opacity = 1;
    clearTimeout(this._toastT);
    this._toastT = setTimeout(() => { t.style.opacity = 0; }, 1600);
  }

  hideLoading() { this.$('loading-overlay').classList.add('done'); }
  setLoadingText(t) { this.$('loading-text').textContent = t; }

  togglePanel(name) {
    const el = this.$(`panel-${name}`);
    const btn = document.querySelector(`.tb-btn[data-panel="${name}"]`);
    const hidden = el.classList.contains('hidden');
    this.closeAll();
    if (hidden) {
      el.classList.remove('hidden');
      btn && btn.classList.add('active');
      if (name === 'gm' && !el.dataset.built) this.buildGM(el);
      if (name === 'skills' && !el.dataset.built) this.buildSkills(el);
      if (name === 'equip' && !el.dataset.built) this.buildEquip(el);
      if (name === 'settings' && !el.dataset.built) this.buildSettings(el);
    }
  }

  closeAll() {
    document.querySelectorAll('.panel').forEach((p) => p.classList.add('hidden'));
    document.querySelectorAll('.tb-btn').forEach((b) => b.classList.remove('active'));
    this.$('objinfo').classList.add('hidden');
  }

  // ---- GM 面板 ----
  buildGM(el) {
    el.dataset.built = 1;
    el.innerHTML = `
      <div class="panel-title">GM 命令面板 <button class="close">×</button></div>
      <div class="panel-body">
        <div class="gm-sec"><h4>传送 (@move)</h4>
          <div class="row"><input type="text" id="gm-search" placeholder="地图名/ID 搜索" style="flex:1">
          <button class="act" id="gm-move">传送</button></div>
          <div id="gm-map-results"></div>
          <div class="row">坐标 <input type="text" id="gm-x" style="width:52px" placeholder="x">
            <input type="text" id="gm-y" style="width:52px" placeholder="y">
            <span class="hint">(空=默认出生点)</span></div>
        </div>
        <div class="gm-sec"><h4>召唤怪物 (@spawn)</h4>
          <input type="text" id="gm-mon" placeholder="怪物名搜索 (全部 434)" style="width:100%">
          <div class="mon-list" id="gm-mon-list"></div>
        </div>
        <div class="gm-sec"><h4>刷物品 (@make)</h4>
          <input type="text" id="gm-item" placeholder="物品名搜索" style="width:100%">
          <div class="mon-list" id="gm-item-list"></div>
        </div>
        <div class="gm-sec"><h4>状态</h4>
          <div class="row">
            <button class="act" id="gm-invis">隐身</button>
            <button class="act" id="gm-pet1">召唤骷髅</button>
            <button class="act" id="gm-pet2">召唤神兽</button>
          </div>
          <label>加速 <input type="range" id="gm-speed" min="0.5" max="5" step="0.5" value="1">
            <span id="gm-speed-v">1.0x</span></label>
          <div class="row"><button class="act" id="gm-lvl">@level 255</button>
          <button class="act" id="gm-kill">清怪</button></div>
        </div>
        <div class="gm-sec"><h4>@命令对照表 (点击执行)</h4>
          <table class="cmd-table">
            <tr><td>@move 地图 x y</td><td>传送到指定地图坐标</td></tr>
            <tr><td>@spawn 怪物名 [数量]</td><td>在脚下召唤怪物</td></tr>
            <tr><td>@make 物品名</td><td>在脚下刷物品</td></tr>
            <tr><td>@level N</td><td>设置等级 (GM 255)</td></tr>
            <tr><td>@hide</td><td>隐身 (半透明)</td></tr>
            <tr><td>@speed N</td><td>移动加速 (0.5-5)</td></tr>
            <tr><td>@pet 骷髅|神兽</td><td>召唤伙伴跟随</td></tr>
            <tr><td>@where</td><td>显示当前坐标</td></tr>
          </table>
        </div>
      </div>`;
    el.querySelector('.close').addEventListener('click', () => el.classList.add('hidden'));
    const g = this.game;
    const search = el.querySelector('#gm-search');
    const results = el.querySelector('#gm-map-results');
    const doSearch = () => {
      const q = search.value.trim().toLowerCase();
      const maps = Object.entries(D().manifest.maps);
      const hits = q ? maps.filter(([stem, m]) =>
        stem.toLowerCase().includes(q) || m.name_cn.includes(q) ||
        m.name_en.toLowerCase().includes(q) || String(m.id) === q) : maps.slice(0, 30);
      results.innerHTML = hits.slice(0, 60).map(([stem, m]) =>
        `<div class="gm-map-row" data-stem="${stem}">
           <span class="cn">${m.name_cn}</span><span class="hint">${stem} (${m.w}×${m.h})</span>
         </div>`).join('') || '<div class="hint">无匹配</div>';
      results.querySelectorAll('.gm-map-row').forEach((row) => {
        row.addEventListener('click', () => {
          const x = parseInt(el.querySelector('#gm-x').value) || null;
          const y = parseInt(el.querySelector('#gm-y').value) || null;
          g.teleport(row.dataset.stem, x, y);
        });
      });
    };
    search.addEventListener('input', doSearch);
    el.querySelector('#gm-move').addEventListener('click', () => doSearch());
    doSearch();

    const monSearch = el.querySelector('#gm-mon');
    const monList = el.querySelector('#gm-mon-list');
    const doMon = () => {
      const q = monSearch.value.trim().toLowerCase();
      const pool = D().monsters.filter((m) => m.lib);
      const hits = (q ? pool.filter((m) => m.zh.includes(q) || m.name.toLowerCase().includes(q) || m.img.toLowerCase().includes(q))
                      : pool).slice(0, 80);
      monList.innerHTML = hits.map((m) =>
        `<div class="mon-row" data-id="${m.id}">
           <img src="${spriteURL(m.lib, m.shape * 1000 + 40)}" onerror="this.style.visibility='hidden'">
           <span class="zh">${m.zh}${m.boss ? ' [BOSS]' : ''}</span><span class="hint">Lv${m.level}</span>
         </div>`).join('');
      monList.querySelectorAll('.mon-row').forEach((row) => {
        row.addEventListener('click', () => {
          const p = g.world.player;
          g.world.summon(+row.dataset.id, p.x + 1, p.y);
          g.ui.log(`@spawn ${D().monstersById[+row.dataset.id].name}`, 'gm');
        });
      });
    };
    monSearch.addEventListener('input', doMon);
    doMon();

    const itemSearch = el.querySelector('#gm-item');
    const itemList = el.querySelector('#gm-item-list');
    const doItem = () => {
      const q = itemSearch.value.trim().toLowerCase();
      const hits = (q ? D().items.filter((i) => i.zh.includes(q) || i.name.toLowerCase().includes(q))
                      : D().items).slice(0, 80);
      itemList.innerHTML = hits.map((i) =>
        `<div class="mon-row" data-id="${i.id}">
           <img src="${spriteURL(D().appearance.icon_libs.store, i.image)}" onerror="this.style.visibility='hidden'">
           <span class="zh">${i.zh}</span><span class="hint">${i.type}</span>
         </div>`).join('');
      itemList.querySelectorAll('.mon-row').forEach((row) => {
        row.addEventListener('click', () => {
          const p = g.world.player;
          g.world.dropItem(+row.dataset.id, p.x, p.y + 1);
          g.ui.toast(`已放置: ${D().itemsById[+row.dataset.id].zh}`);
        });
      });
    };
    itemSearch.addEventListener('input', doItem);
    doItem();

    const invisBtn = el.querySelector('#gm-invis');
    invisBtn.addEventListener('click', () => {
      g.world.player.invis = !g.world.player.invis;
      invisBtn.classList.toggle('on', g.world.player.invis);
      this.log(`@hide ${g.world.player.invis ? 'on' : 'off'}`, 'gm');
    });
    const speed = el.querySelector('#gm-speed');
    speed.addEventListener('input', () => {
      g.world.player.speed = +speed.value;
      el.querySelector('#gm-speed-v').textContent = (+speed.value).toFixed(1) + 'x';
    });
    el.querySelector('#gm-pet1').addEventListener('click', () => g.world.addPet('skeleton'));
    el.querySelector('#gm-pet2').addEventListener('click', () => g.world.addPet('shinsoo'));
    el.querySelector('#gm-lvl').addEventListener('click', () => {
      g.world.player.level = 255; this.log('@level 255', 'gm');
    });
    el.querySelector('#gm-kill').addEventListener('click', () => {
      g.world.summons.length = 0;
      g.world.mons = [];
      this.log('已清理召唤物/怪物', 'gm');
    });
    el.querySelectorAll('.cmd-table td:first-child').forEach((td) => {
      td.addEventListener('click', () => {
        this.chatInput.focus();
        this.chat.classList.add('cmd-open');
        this.chatInput.value = td.textContent + ' ';
      });
    });
  }

  // ---- 技能面板 ----
  buildSkills(el) {
    el.dataset.built = 1;
    const groups = {};
    for (const m of D().magics) (groups[m.cls] ||= []).push(m);
    const zh = { Warrior: '战士', Wizard: '法师', Taoist: '道士', Assassin: '刺客', All: '通用' };
    el.innerHTML = `
      <div class="panel-title">技能 (${D().magics.length}) <button class="close">×</button></div>
      <div class="panel-body">
        <div class="hint">点击技能 → 施法 (悬停怪物/地面选目标) (${Object.keys(D().magicEffects || {}).length} 个接 ClientData 特效编排, 其余图标兜底)</div>
        <div class="magic-list">${Object.entries(groups).map(([cls, list]) => `
          <div class="magic-group"><h4>${zh[cls] || cls} (${list.length})</h4>
            ${list.map((m) => `
              <div class="magic-row" data-id="${m.id}">
                <img src="${spriteURL(D().appearance.icon_libs.magic, m.icon)}" onerror="this.style.visibility='hidden'">
                <span class="zh">${m.zh}</span><span class="en">${m.name}</span>
              </div>`).join('')}
          </div>`).join('')}
        </div>
      </div>`;
    el.querySelector('.close').addEventListener('click', () => el.classList.add('hidden'));
    el.querySelectorAll('.magic-row').forEach((row) => {
      row.addEventListener('click', () => {
        const m = D().magics.find((x) => x.id === +row.dataset.id);
        this.game.castMagic(m);
        el.querySelectorAll('.magic-row').forEach((r) => r.classList.remove('active'));
        row.classList.add('active');
      });
    });
  }

  // ---- 装备面板 (纸娃娃) ----
  buildEquip(el) {
    el.dataset.built = 1;
    const g = this.game;
    const slotDef = [
      { key: 'armourShape', label: '盔甲', type: 'Armour' },
      { key: 'weaponShape', label: '武器', type: 'Weapon' },
      { key: 'helmetShape', label: '头盔', type: 'Helmet' },
    ];
    const render = () => {
      const p = g.world.player;
      const worn = { Armour: p.armourShape, Weapon: p.weaponShape, Helmet: p.helmetShape };
      el.innerHTML = `
        <div class="panel-title">装备 / 纸娃娃 <button class="close">×</button></div>
        <div class="panel-body">
          <div class="row">${CLASSES.map((c) =>
            `<button class="act ${p.cls === c ? 'on' : ''}" data-cls="${c}">${CLASS_NAMES[c]}</button>`).join('')}
            <button class="act" data-gender="t">性别: ${p.gender === 'M' ? '男' : '女'}</button>
            <button class="act" data-hair="t">发型: ${p.hairType}</button>
          </div>
          <div class="eq-grid">${slotDef.map((s) => {
            const it = Object.values(D().itemsById).find((i) => i.type === s.type && i.shape === worn[s.type]);
            return `<div class="eq-slot ${worn[s.type] !== (s.type === 'Weapon' ? -1 : 0) ? 'worn' : ''}">
              ${it ? `<img src="${spriteURL(D().appearance.icon_libs.store, it.image)}" onerror="this.style.visibility='hidden'">` : ''}
              <span class="lbl">${s.label}</span></div>`;
          }).join('')}
            <div class="eq-slot"><span class="lbl">发型</span></div>
            <div class="eq-slot" id="eq-undress"><span class="lbl">全部脱下</span></div>
          </div>
          <div class="hint">装备不限职业 — 点击物品即穿上 (外观即时生效)</div>
          <div class="item-list" id="eq-items"></div>
        </div>`;
      el.querySelector('.close').addEventListener('click', () => el.classList.add('hidden'));
      el.querySelectorAll('[data-cls]').forEach((b) => b.addEventListener('click', () => {
        g.world.player.cls = b.dataset.cls; g.world.player.anim = 'standing'; render();
        g.ui.log(`职业切换 → ${CLASS_NAMES[b.dataset.cls]}`, 'sys');
      }));
      el.querySelector('[data-gender]').addEventListener('click', () => {
        g.world.player.gender = g.world.player.gender === 'M' ? 'F' : 'M'; render();
      });
      el.querySelector('[data-hair]').addEventListener('click', () => {
        g.world.player.hairType = g.world.player.hairType % 10 + 1; render();
      });
      el.querySelector('#eq-undress').addEventListener('click', () => {
        p.armourShape = 0; p.weaponShape = -1; p.helmetShape = 0; render();
      });
      const wearable = D().items.filter((i) => ['Armour', 'Weapon', 'Helmet'].includes(i.type) && i.shape >= 0);
      const listEl = el.querySelector('#eq-items');
      listEl.innerHTML = wearable.map((i) =>
        `<div class="item-row" data-id="${i.id}" data-type="${i.type}">
           <img src="${spriteURL(D().appearance.icon_libs.store, i.image)}" onerror="this.style.visibility='hidden'">
           <span class="zh">${i.zh}</span><span class="hint">${i.type}/${i.cls}</span>
         </div>`).join('');
      listEl.querySelectorAll('.item-row').forEach((row) => {
        row.addEventListener('click', () => {
          const it = D().itemsById[+row.dataset.id];
          const p2 = g.world.player;
          if (it.type === 'Armour') p2.armourShape = it.shape;
          if (it.type === 'Weapon') p2.weaponShape = it.shape;
          if (it.type === 'Helmet') p2.helmetShape = it.shape;
          g.ui.toast(`穿上: ${it.zh}`);
          render();
        });
      });
    };
    render();
  }

  // ---- 设置面板 (M7) ----
  buildSettings(el) {
    el.dataset.built = 1;
    const g = this.game;
    const s = g.settings;
    el.innerHTML = `
      <div class="panel-title">显示设置 <button class="close">×</button></div>
      <div class="panel-body">
        <label>分辨率
          <select id="set-res">${RESOLUTIONS.map(([w, h]) =>
            `<option value="${w}x${h}" ${s.resW === w && s.resH === h ? 'selected' : ''}>${w}×${h}</option>`).join('')}
          </select>
        </label>
        <div class="row">
          <button class="act" id="set-fullscreen">全屏切换 (F11)</button>
          <button class="act ${s.borderless ? 'on' : ''}" id="set-borderless">无边框</button>
        </div>
        <label>V-Sync <input type="checkbox" id="set-vsync" ${s.vsync ? 'checked' : ''}>
          <span class="hint" id="fps-hint"></span></label>
        <label>UI 缩放 <select id="set-uizoom">
          ${[0.75, 1, 1.5, 2].map((z) => `<option value="${z}" ${s.uiZoom === z ? 'selected' : ''}>${z}x</option>`).join('')}
        </select> <span class="hint">同 Godot UiScaler clamp(min(h/768,w/1024),1,2)</span></label>
        <label>游戏缩放 <input type="range" id="set-zoom" min="0.5" max="2" step="0.25" value="${s.zoom}">
          <span id="set-zoom-v">${s.zoom}x</span></label>
        <label class="chk"><input type="checkbox" id="set-effects" ${s.drawEffects ? 'checked' : ''}> 特效 (ClientSettings.DrawEffects)</label>
        <label class="chk"><input type="checkbox" id="set-particles" ${s.drawParticles ? 'checked' : ''}> 粒子 (DrawParticles)</label>
        <div class="row">
          <label class="chk"><input type="checkbox" id="set-npcnames" ${s.showNames ? 'checked' : ''}> 名称</label>
          <label class="chk"><input type="checkbox" id="set-npcs" ${s.showNpcs ? 'checked' : ''}> NPC</label>
          <label class="chk"><input type="checkbox" id="set-mons" ${s.showMons ? 'checked' : ''}> 怪物</label>
          <label class="chk"><input type="checkbox" id="set-exits" ${s.showExits ? 'checked' : ''}> 出口</label>
        </div>
        <div class="hint">所有设置即时生效并 localStorage 持久化</div>
      </div>`;
    el.querySelector('.close').addEventListener('click', () => el.classList.add('hidden'));
    const upd = () => { g.applySettings(); g.saveSettings(); };
    el.querySelector('#set-res').addEventListener('change', (e) => {
      const [w, h] = e.target.value.split('x').map(Number);
      s.resW = w; s.resH = h; upd();
    });
    el.querySelector('#set-fullscreen').addEventListener('click', () => {
      if (document.fullscreenElement) document.exitFullscreen();
      else document.documentElement.requestFullscreen();
    });
    el.querySelector('#set-borderless').addEventListener('click', (e) => {
      s.borderless = !s.borderless;
      e.target.classList.toggle('on', s.borderless);
      document.documentElement.classList.toggle('borderless', s.borderless);
      upd();
    });
    el.querySelector('#set-vsync').addEventListener('change', (e) => { s.vsync = e.target.checked; upd(); });
    el.querySelector('#set-uizoom').addEventListener('change', (e) => { s.uiZoom = +e.target.value; upd(); });
    const zoom = el.querySelector('#set-zoom');
    zoom.addEventListener('input', () => {
      s.zoom = +zoom.value; el.querySelector('#set-zoom-v').textContent = s.zoom + 'x'; upd();
    });
    el.querySelector('#set-effects').addEventListener('change', (e) => { s.drawEffects = e.target.checked; upd(); });
    el.querySelector('#set-particles').addEventListener('change', (e) => { s.drawParticles = e.target.checked; upd(); });
    el.querySelector('#set-npcnames').addEventListener('change', (e) => { s.showNames = e.target.checked; upd(); });
    el.querySelector('#set-npcs').addEventListener('change', (e) => { s.showNpcs = e.target.checked; upd(); });
    el.querySelector('#set-mons').addEventListener('change', (e) => { s.showMons = e.target.checked; upd(); });
    el.querySelector('#set-exits').addEventListener('change', (e) => { s.showExits = e.target.checked; upd(); });
  }

  setFps(fps) {
    const el = document.getElementById('fps-hint');
    if (el) el.textContent = ` ${fps} fps`;
  }

  // ---- 大地图 ----
  toggleBigmap() {
    const el = this.$('bigmap');
    if (!el.classList.contains('hidden')) { el.classList.add('hidden'); return; }
    el.classList.remove('hidden');
    this.game.renderBigmap(el);
  }

  // ---- 对象信息 ----
  showObjInfo(hit, e) {
    const el = this.$('objinfo');
    const info = hit.info;
    if (!info) return;
    const rows = hit.kind === 'mon'
      ? `<div class="${info.boss ? 'boss' : ''}">${info.zh}${info.boss ? ' [BOSS]' : ''}</div>
         <div class="meta">Lv ${info.level} · ${info.name} · ${info.img}</div>`
      : hit.kind === 'npc'
      ? `<h5>${info.zh}</h5><div class="meta">${info.name} · ${info.cat || ''}</div>
         <div class="meta">Image ${info.image}</div>`
      : `<h5>${info.zh}</h5><div class="meta">${info.name} · ${info.type}</div>`;
    el.innerHTML = rows + '<div class="hint">点击空白处关闭</div>';
    el.style.left = Math.min(e.clientX + 12, window.innerWidth - 270) + 'px';
    el.style.top = Math.min(e.clientY + 12, window.innerHeight - 120) + 'px';
    el.classList.remove('hidden');
  }

  // ---- 腰带 ----
  fillBelt() {
    const potions = D().items.filter((i) => i.type === 'Consumable').slice(0, 8);
    document.querySelectorAll('.belt-slot').forEach((el, i) => {
      const it = potions[i];
      this.belt[i].item = it || null;
      el.classList.toggle('empty', !it);
      el.innerHTML = `<span class="key">⇧${i + 1}</span>` +
        (it ? `<img src="${spriteURL(D().appearance.icon_libs.store, it.image)}" onerror="this.style.visibility='hidden'"><div class="cd"></div>` : '');
    });
  }

  useBeltSlot(i) {
    const slot = this.belt[i];
    if (!slot.item) { this.toast('腰带槽为空'); return; }
    const now = performance.now();
    if (now < slot.cdUntil) { this.toast('冷却中…'); return; }
    slot.cdUntil = now + 1500;
    const g = this.game;
    g.world.player.hp = Math.min(g.world.player.hpMax, g.world.player.hp + 50);
    g.world.player.mp = Math.min(g.world.player.mpMax, g.world.player.mp + 30);
    this.log(`使用 [${slot.item.zh}] HP+50 MP+30`, 'sys');
    const el = document.querySelectorAll('.belt-slot')[i];
    const cd = el.querySelector('.cd');
    if (cd) {
      cd.style.transition = 'none'; cd.style.transform = 'scaleY(1)';
      requestAnimationFrame(() => {
        cd.style.transition = 'transform 1.5s linear'; cd.style.transform = 'scaleY(0)';
      });
    }
  }

  updateOrbs() {
    const p = this.game.world.player;
    const hpEl = this.$('orb-hp'), mpEl = this.$('orb-mp');
    hpEl.querySelector('.fill').style.height = (p.hp / p.hpMax * 100) + '%';
    hpEl.querySelector('span').textContent = `HP ${p.hp}/${p.hpMax}`;
    mpEl.querySelector('.fill').style.height = (p.mp / p.mpMax * 100) + '%';
    mpEl.querySelector('span').textContent = `MP ${p.mp}/${p.mpMax}`;
  }

  setMapLabel(stem, m) {
    this.$('mapname').textContent = `${m.name_cn} (${stem})`;
    document.title = `${m.name_cn} — Mir3 浏览器测试台`;
  }

  setPos(x, y) { this.$('pos').textContent = `${x},${y}`; }
}

export { CLASS_NAMES, CLASSES, RESOLUTIONS };
