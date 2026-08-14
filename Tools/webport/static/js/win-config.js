// win-config.js — 设置 ConfigDialog.cs 移植 (D路 par-win)
// 5 页签 (:34-45): 画面/音效/游戏/网络/界面; 窗 364x416, 页 (8,62) 348x340, 超 340 接滚动 (:59-69)。
// 协议选项 (真实包): 隐藏头盔→C.HelmetToggle (:219), 允许观战→C.ObservableSwitch (:246),
//   语言→C.SelectLanguage (:211, 'CHINESE'/'ENGLISH'/'JAPANESE')。
// Web 实效: 全屏=requestFullscreen; 隐藏聊天栏=scene.chatLog/chatBox;
//   Esc 关闭所有=WindowManager 全关; 网络=localStorage (下次登录生效)。
// 其余视觉偏好 = localStorage 持久化 + window.__WEBPORT_CFG__ 供渲染路线消费 (对齐 Godot ClientSettings 语义)。
// 平台裁剪: 分辨率/显示器/垂直同步/限制帧率/限制鼠标 (浏览器 N/A) 不做。

import { getWindow } from './uitree.js';
import { WindowManager } from './windows.js';
import { DXControl, DXLabel, DXButton, DXTextInput } from './dx.js';

const LS_KEY = 'webport.config.v1';

const DEFAULTS = {
  // 画面 (ClientSettings)
  smoothMove: false, drawParticles: true, drawEffects: true, drawWeather: true,
  hideHelmet: false,
  // 音效 (webport 暂无音频管线 — 持久化待音频路线消费)
  soundInBackground: false,
  systemVolume: 70, musicVolume: 60, playerVolume: 80, monsterVolume: 80, magicVolume: 80,
  systemMuted: false, musicMuted: false, playerMuted: false, monsterMuted: false, magicMuted: false,
  // 游戏
  showItemNames: true, showMonsterNames: true, showPlayerNames: true,
  showUserHealth: true, showDamageNumbers: true, rightClickDeTarget: true,
  allowObservable: true,
  // 网络 (下次登录生效)
  useNetworkConfig: false, ipAddress: '127.0.0.1', port: '7000',
  // 界面
  hideChatBar: false, shiftOpenChat: true, escapeCloseAll: false, logChat: true,
  language: 'CHINESE',
};

export async function winConfig(scene, store, reg) {
  const w = await getWindow('ConfigDialog');
  if (!w) return null;
  const conn = scene.conn;

  let cfg = { ...DEFAULTS };
  try { cfg = { ...cfg, ...JSON.parse(localStorage.getItem(LS_KEY) ?? '{}') }; } catch { /* 损坏用默认 */ }
  function save() {
    localStorage.setItem(LS_KEY, JSON.stringify(cfg));
    globalThis.__WEBPORT_CFG__ = cfg;
  }
  globalThis.__WEBPORT_CFG__ = cfg;

  // S.GroupSwitch echo 时无; 允许观战无 echo (服务端静默) — 本地为源。

  // ---- 页签 (:34-45) ----
  const tabs = ['画面', '音效', '游戏', '网络', '界面'];
  const content = new DXControl({ location: [8, 62], size: [348, 340], clip: true, isControl: false });
  w.addControl(content);
  tabs.forEach((text, i) => {
    const b = new DXButton({ text, fontSize: 10, library: 'Interface', index: -1,
      location: [8 + i * 70, 37], size: [68, 25],
      textColour: i === 0 ? [255, 216, 77, 255] : [230, 204, 115, 255],
      onClick: () => selectTab(i) });
    b._tab = i;
    w.addControl(b);
  });

  // ---- 控件工厂 ----
  let yy = 0;
  function section(title) {
    const s = new DXControl({ location: [0, yy], size: [330, 24], isControl: false });
    content.addControl(s);
    s.addControl(new DXLabel({ text: title, fontSize: 10, textColour: [255, 216, 77, 255],
      drawOutline: true, location: [0, 0], size: [200, 20], isControl: false }));
    yy += 24;
    s._items = 0;
    s._x = 0; s._y = 24;
    return s;
  }
  function check(s, label, key, onChange) {
    const b = new DXButton({
      text: `${cfg[key] ? '☑' : '☐'} ${label}`, fontSize: 9,
      library: 'Interface', index: -1,
      location: [s._x, s._y], size: [162, 22], align: 'left',
      textColour: [255, 255, 255, 255],
      onClick: () => {
        cfg[key] = !cfg[key];
        b.text = `${cfg[key] ? '☑' : '☐'} ${label}`;
        save();
        onChange?.(cfg[key]);
      },
    });
    b._key = key; b._label = label;
    s.addControl(b);
    s._x += 166;
    if (s._x > 300) { s._x = 0; s._y += 26; }
    return b;
  }
  function syncCheck(b) {
    if (b?._key) b.text = `${cfg[b._key] ? '☑' : '☐'} ${b._label}`;
  }
  function input(s, label, key, width = 120, numeric = false) {
    const t = new DXTextInput({ location: [s._x, s._y], size: [width, 22], fontSize: 9, text: String(cfg[key] ?? '') });
    s.addControl(t);
    t.input.addEventListener('change', () => {
      cfg[key] = numeric ? (parseInt(t.text, 10) || 0) : t.text.trim();
      save();
    });
    s._x += width + 6;
    if (s._x > 300) { s._x = 0; s._y += 26; }
    return t;
  }

  // ---- 各页 (:54-58) ----
  function buildGraphics() {
    const disp = section('显示');
    check(disp, '全屏显示', '_fs', (v) => {
      if (v) document.documentElement.requestFullscreen?.().catch?.(() => {});
      else if (document.fullscreenElement) document.exitFullscreen?.();
    });
    disp._x = 0; disp._y += 26;
    const use = section('可用性');
    check(use, '流畅移动', 'smoothMove');
    check(use, '语言', '_lang', () => {
      cfg.language = cfg.language === 'CHINESE' ? 'ENGLISH' : cfg.language === 'ENGLISH' ? 'JAPANESE' : 'CHINESE';
      save();
      conn.sendSelectLanguage(cfg.language);   // C.SelectLanguage (:211)
      syncCheck(use.children.find(c => c._key === '_lang'));
      use.children.find(c => c._key === '_lang').text = `☐ 语言: ${cfg.language === 'CHINESE' ? '中文' : cfg.language === 'ENGLISH' ? 'English' : '日本語'}`;
    });
    use.children.find(c => c._key === '_lang').text = `☐ 语言: ${cfg.language === 'CHINESE' ? '中文' : cfg.language === 'ENGLISH' ? 'English' : '日本語'}`;
    const fx = section('特效');
    check(fx, '显示粒子', 'drawParticles');
    check(fx, '显示特效', 'drawEffects');
    check(fx, '显示天气与特效', 'drawWeather');
    check(fx, '隐藏头盔', 'hideHelmet', (v) => conn.sendHelmetToggle(v));   // (:219)
  }

  function buildSound() {
    const opt = section('选项');
    check(opt, '后台播放声音', 'soundInBackground');
    const vol = section('音量');
    for (const [label, vKey, mKey] of [
      ['系统音量', 'systemVolume', 'systemMuted'],
      ['音乐音量', 'musicVolume', 'musicMuted'],
      ['人物音量', 'playerVolume', 'playerMuted'],
      ['怪物音量', 'monsterVolume', 'monsterMuted'],
      ['魔法音量', 'magicVolume', 'magicMuted'],
    ]) {
      const row = new DXControl({ location: [0, vol._y], size: [330, 26], isControl: false });
      content.addControl(row);
      const lbl = document.createElement('div');
      lbl.textContent = `${label}: ${cfg[vKey]}%`;
      lbl.style.cssText = "font:12px 'Noto Sans CJK SC',sans-serif;color:#ffdb8e;text-shadow:1px 1px 0 #000;width:110px;";
      row.el.appendChild(lbl);
      const range = document.createElement('input');
      range.type = 'range'; range.min = '0'; range.max = '100'; range.value = String(cfg[vKey]);
      range.style.cssText = 'width:170px;accent-color:#c8942e;';
      range.addEventListener('input', () => {
        cfg[vKey] = parseInt(range.value, 10);
        lbl.textContent = `${label}: ${range.value}%`;
        save();
      });
      row.el.appendChild(range);
      const mute = document.createElement('button');
      mute.textContent = cfg[mKey] ? '🔇' : '🔊';
      mute.style.cssText = 'cursor:pointer;background:none;border:1px solid #8a6d35;color:#ffdb8e;font-size:11px;padding:1px 6px;';
      mute.onclick = () => { cfg[mKey] = !cfg[mKey]; mute.textContent = cfg[mKey] ? '🔇' : '🔊'; save(); };
      row.el.appendChild(mute);
      vol._y += 28; yy += 28;
    }
    yy += 28;
  }

  function buildGame() {
    const g = section('游戏设置');
    check(g, '显示物品名称', 'showItemNames');
    check(g, '显示怪物名称', 'showMonsterNames');
    check(g, '显示人物名称', 'showPlayerNames');
    check(g, '显示生命条', 'showUserHealth');
    check(g, '显示伤害数字', 'showDamageNumbers');
    check(g, '右键取消目标', 'rightClickDeTarget');
    check(g, '允许观战', 'allowObservable', (v) => conn.sendObservableSwitch(v));   // (:246)
    // 目标颜色 (:249-257) — 7 色
    const tc = section('目标颜色');
    const COLOURS = ['怪物:低', '怪物:同', '怪物:高', '怪物:友', '玩家:友', '玩家:敌', 'NPC'];
    COLOURS.forEach((name, i) => {
      const key = `targetColour${i}`;
      cfg[key] ??= ['#808080', '#ffff00', '#ff0000', '#00ff00', '#00ff00', '#ff0000', '#ffff00'][i];
      const c = document.createElement('input');
      c.type = 'color'; c.value = cfg[key];
      c.style.cssText = 'width:44px;height:22px;cursor:pointer;background:#000;border:1px solid #8a6d35;';
      c.addEventListener('input', () => { cfg[key] = c.value; save(); });
      const cell = new DXControl({ location: [tc._x, tc._y], size: [52, 24], isControl: false });
      cell.el.appendChild(c);
      content.addControl(cell);
      tc._x += 56;
      if (tc._x > 300) { tc._x = 0; tc._y += 26; yy += 26; }
    });
    yy += 26;
  }

  function buildNetwork() {
    const n = section('网络设置');
    check(n, '使用网络配置', 'useNetworkConfig');
    n._x = 0; n._y += 26;
    const addrLbl = new DXLabel({ text: '服务器地址', fontSize: 9, drawOutline: true,
      location: [0, n._y], size: [90, 20], isControl: false });
    content.addControl(addrLbl);
    n._x = 96;
    input(n, '', 'ipAddress', 160);
    n._x = 0; n._y += 26;
    const portLbl = new DXLabel({ text: '服务器端口', fontSize: 9, drawOutline: true,
      location: [0, n._y], size: [90, 20], isControl: false });
    content.addControl(portLbl);
    n._x = 96;
    input(n, '', 'port', 70, true);
    content.addControl(new DXLabel({ text: '(保存后下次登录生效)', fontSize: 8,
      textColour: [160, 160, 160, 255], drawOutline: true,
      location: [0, n._y + 26], size: [200, 18], isControl: false }));
  }

  function buildUi() {
    const u = section('界面设置');
    check(u, '隐藏聊天栏', 'hideChatBar', (v) => {
      if (scene.chatLog) scene.chatLog.visible = !v;
      if (scene.chatBox) scene.chatBox.visible = !v;
    });
    check(u, '按 Shift 打开聊天', 'shiftOpenChat');
    check(u, 'Esc 关闭所有窗口', 'escapeCloseAll', (v) => { globalThis.__WEBPORT_ESC_ALL__ = v; });
    globalThis.__WEBPORT_ESC_ALL__ = cfg.escapeCloseAll;
    check(u, '记录聊天', 'logChat');
    const kb = new DXButton({ text: '快捷键设置', fontSize: 9, library: 'Interface', index: -1,
      location: [0, u._y + 2], size: [120, 22],
      onClick: () => globalThis.__WEBPORT_KEYBINDS__?.open?.() });
    u.addControl(kb);
    // 聊天颜色 (:292-307) — 前景色 13 项
    const cc = section('聊天颜色 (前景)');
    const names = ['本地', 'GM密语', '收到密语', '发送密语', '组队', '行会', '喊话', '世界', '观察者', '提示', '系统', '获得', '公告'];
    names.forEach((name, i) => {
      const key = `chatColour${i}`;
      cfg[key] ??= ['#ffffff', '#ff4040', '#ff8040', '#ff8040', '#80ff80', '#8080ff', '#ffff40', '#40ffff', '#c0c0c0', '#ffffa0', '#ff00ff', '#ffffff', '#ffd700'][i];
      const c = document.createElement('input');
      c.type = 'color'; c.value = cfg[key];
      c.style.cssText = 'width:40px;height:20px;cursor:pointer;background:#000;border:1px solid #8a6d35;';
      c.addEventListener('input', () => { cfg[key] = c.value; save(); });
      const cell = new DXControl({ location: [cc._x, cc._y], size: [48, 22], isControl: false });
      cell.el.appendChild(c);
      cell.el.title = name;
      content.addControl(cell);
      cc._x += 52;
      if (cc._x > 300) { cc._x = 0; cc._y += 24; yy += 24; }
    });
    yy += 24;
  }

  const builders = [buildGraphics, buildSound, buildGame, buildNetwork, buildUi];
  function selectTab(i) {
    content.el.replaceChildren();
    yy = 0;
    w.children.forEach((c) => { if (c._tab != null) c.textColour = c._tab === i ? [255, 216, 77, 255] : [230, 204, 115, 255]; });
    builders[i]();
    // 超高接滚动 (:59-69)
    if (yy > 340) {
      const scroller = document.createElement('div');
      scroller.style.cssText = 'position:absolute;left:334px;top:0;width:14px;height:340px;overflow-y:scroll;';
      const inner = document.createElement('div');
      inner.style.height = `${yy}px`;
      scroller.appendChild(inner);
      scroller.addEventListener('scroll', () => { content.el.style.top = `${-scroller.scrollTop}px`; });
      content.el.style.position = 'relative';
      content.parent.el.appendChild(scroller);
    }
  }
  selectTab(0);

  // Esc 关闭所有 (界面设置开启时; game.js 的 Esc 处理器先问本开关)
  globalThis.__WEBPORT_CFG_ESCAPE__ = () => {
    if (!cfg.escapeCloseAll) return false;
    for (const win of [...WindowManager.OpenWindows]) WindowManager.close(win);
    return true;
  };

  reg.wins.set('config', w);
  return {
    win: w,
    open: () => WindowManager.open(w, scene.hudLayer),
    close: () => WindowManager.close(w),
    toggle: () => WindowManager.toggle(w, scene.hudLayer),
    cfg, save,
  };
}
