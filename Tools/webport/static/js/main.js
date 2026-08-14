// main.js — 场景流转 (LoginScene → SelectScene → GameScene, 对照各 Scene.cs)
// 双 UI 参考模式 (总纲 §一): 按 localStorage 选择主题; 逻辑层 (ws/net/data/world) 两模式共用。
import { GameConnection } from './ws.js';
import { getMode } from './mode.js';
import { mountModeSwitcher } from './shell.js';

const stage = document.getElementById('stage');

let conn = null;
let current = null;
let theme = null;        // { LoginScene, SelectScene, GameScene }
let uiScaler = null;     // Zircon 模式的 1024x768 逻辑画布缩放器

async function loadTheme() {
  const mode = getMode();
  document.body.dataset.uimode = mode;
  if (mode === 'ei') {
    theme = await import('./themes/ei/index.js');
  } else {
    theme = await import('./themes/zircon/index.js');
    const dx = await import('./dx.js');
    uiScaler = dx.UiScaler;
  }
}

function mountScene(sceneEl) {
  stage.replaceChildren(sceneEl);
}

function enterLogin() {
  if (!conn || !conn.ws) {
    conn = new GameConnection();
    conn.connect().catch(err => {
      console.error('网关连接失败:', err);
      alert(`无法连接游戏网关 (ws://...:7001):\n${err.message}\n\n请确认 wsgateway 已启动`);
    });
  }
  const login = new theme.LoginScene(conn, (characters) => {
    conn.stage = 'select';
    enterSelect(characters);
  });
  current = login;
  mountScene(login.root);
  applyScale();
}

function enterSelect(characters) {
  const select = new theme.SelectScene(conn, characters, (startInfo) => {
    conn.stage = 'game';
    enterGame(startInfo);
  });
  current = select;
  mountScene(select.root);
  applyScale();
  // ?demo=1: 选人后 1.2s 自动开始第一个角色
  if (DEMO && characters.length > 0) {
    setTimeout(() => {
      if (current === select) conn.sendStartGame(characters[0].characterIndex);
    }, 1200);
  }
}

function enterGame(startInfo) {
  const game = new theme.GameScene(conn, startInfo);
  current = game;
  // GameScene 全屏世界 (canvas 铺视口) + HUD 层挂逻辑画布缩放
  document.body.classList.add('ingame');
  mountScene(game.root);
  if (game.hud) stage.appendChild(game.hud);   // Zircon 模式: HUD 覆盖 canvas
  applyScale();
}

function applyScale() {
  if (uiScaler) uiScaler.apply(stage);
}

addEventListener('resize', applyScale);

// 全局 F5 提示 (避免误刷新断线)
addEventListener('keydown', (ev) => {
  if (ev.key === 'F5' && document.body.classList.contains('ingame')) {
    ev.preventDefault();
  }
});

window.__WEBPORT = {
  get conn() { return conn; },
  get current() { return current; },
  get log() { return conn?.log ?? []; },
  get mode() { return getMode(); },
};

mountModeSwitcher();
loadTheme().then(enterLogin);

// ?demo=1 一键直进: 自动登录测试号并选第一个角色 (仅测试便利, 不改协议层)
const DEMO = new URLSearchParams(location.search).has('demo');
if (DEMO) {
  const DEMO_EMAIL = 'test@test.com', DEMO_PASS = 'test123';
  const waitLogin = setInterval(() => {
    if (!conn?.ws || conn.ws.readyState !== 1) return;      // 等网关连上
    if (current?.btnLogin?.enabled === false) return;        // 等登录按钮就绪
    clearInterval(waitLogin);
    console.log('[webport] demo 模式: 自动登录', DEMO_EMAIL);
    setTimeout(() => {
      current.emailInput.text = DEMO_EMAIL;
      current.passwordInput.text = DEMO_PASS;
      current.btnLogin.onClick?.();          // 走正式登录按钮路径
    }, 400);
  }, 300);
}
