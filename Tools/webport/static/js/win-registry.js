// win-registry.js — par-win 窗口注册表 (D路)
// 每窗口一个 win-*.js 模块; 本文件统一 install, 对外:
//   Windows.open/close/toggle(name) / Windows.win(name) / Windows.wins / Windows.handlers
//   installWindows(scene) → Windows
// game.js 接口: window.__WEBPORT_WIN(type, scene) → DXWindow (par-win 单例; 开/关窗
//   副作用经 showWindow/close 装饰: h.onShow/h.onHide — 组队 C.GroupNotify、NPC C.NPCClose)。
// Godot 对照: GameScene.CreateHud (:4305-4404 单例构造) + HandleKeyBind (:1890-2028)。
// routeHandlers: 背包右键快路由链 (修理格/交易格 注册处理函数, 首个返回 true 止)。

import { WindowManager } from './windows.js';
import { ItemStore } from './itemstore.js';
import { GRID } from './net.js';
import { winInventory } from './win-inventory.js';
import { winChar } from './win-char.js';
import { winSkill } from './win-skill.js';
import { winQuest } from './win-quest.js';
import { winGuild } from './win-guild.js';
import { winParty } from './win-party.js';
import { winNpc, npcDialogs } from './win-npc.js';
import { winStorage } from './win-storage.js';
import { winTrade } from './win-trade.js';
import { winConfig } from './win-config.js';
import { winGm } from './win-gm.js';
import { winComm } from './win-comm.js';

const MODULES = {
  inventory: winInventory,     // 背包 (InventoryDialog.cs)
  char: winChar,               // 角色 (CharacterDialog.cs)
  skill: winSkill,             // 技能 (MagicDialog.cs)
  quest: winQuest,             // 任务 (QuestDialog.cs)
  guild: winGuild,             // 行会 (GuildDialog.cs)
  party: winParty,             // 组队 (GroupDialog.cs)
  npc: winNpc,                 // NPC对话+商店+修理+任务 (NPCDialog.cs 系)
  storage: winStorage,         // 仓库 (StorageDialog.cs)
  trade: winTrade,             // 交易 (TradeDialog.cs)
  config: winConfig,           // 设置 (ConfigDialog.cs)
  gm: winGm,                   // GM面板 (@命令 GUI; 仅 isGM)
  comm: winComm,               // 通信 (CommunicationDialog.cs 好友/邮件/屏蔽)
};

// game.js MainPanel 按钮名 → 本注册表窗口名
const TYPE_MAP = {
  character: 'char', inventory: 'inventory', spell: 'skill', quest: 'quest',
  group: 'party', guild: 'guild', trade: 'trade', config: 'config',
  storage: 'storage', options: 'config', gm: 'gm', mail: 'comm',
};

// showWindow/close 装饰: 模块声明的 onShow/onHide 副作用在 WindowManager 开关时触发
// (game.js 直接 WindowManager.toggle(w) 也能发对包)
function decorate(h) {
  const win = h.win;
  if (!win) return;
  if (h.onShow) {
    const orig = win.showWindow.bind(win);
    win.showWindow = (parent) => { h.onShow(); return orig(parent); };
  }
  if (h.onHide) {
    const orig = win.close.bind(win);
    win.close = () => { h.onHide(); return orig(); };
  }
}

export const Windows = {
  scene: null,
  itemStore: null,
  wins: new Map(),           // name → DXWindow 单例 (各模块 reg.wins.set)
  handlers: new Map(),       // name → module handler
  routeHandlers: [],         // (cell) => boolean 背包右键快路由链
  npcDialogs,

  async install(scene) {
    this.scene = scene;
    // ItemStore: scene 已建则复用, 否则自建 (conn + startInfo)
    this.itemStore = scene.itemStore ?? new ItemStore(scene.conn, scene.info, {
      chat: (t) => scene.addChat?.(t, 'hint'),
      sendItemMove: (fg, tg, fs, ts, m) => scene.conn.sendItemMove(fg, tg, fs, ts, m),
    });
    scene.itemStore = this.itemStore;

    for (const [name, mod] of Object.entries(MODULES)) {
      try {
        const h = await mod(scene, this.itemStore, this);
        if (h) {
          this.handlers.set(name, h);
          decorate(h);
        }
      } catch (err) {
        console.warn(`[win] 模块 ${name} 安装失败:`, err);
      }
    }

    // game.js #openWindow 接口 (覆盖式: par-win 注册过的类型优先, 其余走 fallback)
    globalThis.__WEBPORT_WIN = (type, sc) => {
      const name = TYPE_MAP[type];
      const h = name && this.handlers.get(name);
      if (!h || sc !== scene) return null;   // 非本场景 (双 UI 切换) 不接管
      return h.win;
    };
    return this;
  },

  win(name) { return this.wins.get(name) ?? null; },
  handler(name) { return this.handlers.get(name) ?? null; },

  open(name, ...args) {
    const h = this.handlers.get(name);
    return h ? h.open(...args) : null;
  },
  close(name) {
    const h = this.handlers.get(name);
    if (h?.close) return h.close();
    const w = this.wins.get(name);
    if (w) WindowManager.close(w);
    return null;
  },
  toggle(name, ...args) {
    const h = this.handlers.get(name);
    if (!h) return null;
    if (h.toggle) return h.toggle(...args);
    const w = this.wins.get(name);
    if (w?.visible) return this.close(name);
    return this.open(name, ...args);
  },

  GRID,
};

export async function installWindows(scene) {
  return Windows.install(scene);
}
