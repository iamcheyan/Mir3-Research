// input.js — 键盘/指针输入: 8 方向移动 / 点击实体 / 大地图 / 聊天 / 面板快捷键
import { CELL_W, CELL_H } from './data.js';

const KEY_DIRS = {
  ArrowUp: 0, ArrowRight: 2, ArrowDown: 4, ArrowLeft: 6,
  w: 0, s: 4, a: 6, d: 2,
};
// 8 方向: 方向键两键组合 = 斜向; dir 枚举 0=Up 1=UpRight 2=Right 3=DownRight 4=Down 5=DownLeft 6=Left 7=UpLeft
function resolveDir(pressed) {
  let vert = null, horiz = null;
  for (const k of pressed) {
    if (k in KEY_DIRS) {
      const d = KEY_DIRS[k];
      if (d === 0 || d === 4) vert = d;
      else horiz = d;
    }
  }
  if (vert === null && horiz === null) return null;
  if (vert !== null && horiz !== null) {
    if (vert === 0) return horiz === 2 ? 1 : 7;   // 上+右/左
    return horiz === 2 ? 3 : 5;                    // 下+右/左
  }
  return vert !== null ? vert : horiz;
}

const STEP = { 0: [0, -1], 1: [1, -1], 2: [1, 0], 3: [1, 1], 4: [0, 1], 5: [-1, 1], 6: [-1, 0], 7: [-1, -1] };

export class Input {
  constructor(game) {
    this.game = game;
    this.keys = new Set();
    this.moveTimer = 0;
    this.lastMove = 0;
    this.repeatMs = 110;   // 步频 (跑动 ~9格/s)
  }

  bind() {
    const g = this.game;
    window.addEventListener('keydown', (e) => this.onKey(e, true));
    window.addEventListener('keyup', (e) => this.onKey(e, false));
    const cv = g.cam.canvas;
    cv.addEventListener('mousemove', (e) => this.onHover(e));
    cv.addEventListener('click', (e) => this.onClick(e));
    cv.addEventListener('contextmenu', (e) => e.preventDefault());
  }

  onKey(e, down) {
    const g = this.game;
    const k = e.key;
    if (down && k === 'Enter') {
      if (document.activeElement !== g.ui.chatInput) {
        g.ui.chatInput.focus();
        g.ui.chat.classList.add('cmd-open');
      }
      e.preventDefault();
      return;
    }
    if (document.activeElement === g.ui.chatInput) {
      if (down && (k === 'Escape' || (k === 'Enter' && e.target === g.ui.chatInput))) {
        if (k === 'Escape') { g.ui.chatInput.blur(); g.ui.chat.classList.remove('cmd-open'); }
      }
      return;   // 输入框内不触发游戏键
    }
    if (down) {
      switch (k) {
        case 'b': case 'B': g.ui.toggleBigmap(); return;
        case 'g': case 'G': g.ui.togglePanel('gm'); return;
        case 's': case 'S': g.ui.togglePanel('skills'); return;
        case 'e': case 'E': g.ui.togglePanel('equip'); return;
        case 'Escape': g.ui.closeAll(); return;
        case 'F11': return;   // 浏览器原生
      }
      // 腰带 Shift+1..8
      if (e.shiftKey && k >= '1' && k <= '8') { g.ui.useBeltSlot(+k - 1); e.preventDefault(); return; }
    }
    const dirKeys = [...KEY_DIRS, ...KEY_DIRS.map((x) => x.toUpperCase() ? x : x)];
    if (k in KEY_DIRS || k.toLowerCase() in KEY_DIRS) {
      down ? this.keys.add(k.toLowerCase() === k ? k : k.toLowerCase()) : this.keys.delete(k.toLowerCase());
      // 归一化: ArrowUp 与 w 同义
      e.preventDefault();
    }
  }

  cellFromEvent(e) {
    const g = this.game;
    const rect = g.cam.canvas.getBoundingClientRect();
    const sx = (e.clientX - rect.left) * (g.cam.canvas.width / rect.width);
    const sy = (e.clientY - rect.top) * (g.cam.canvas.height / rect.height);
    const w = g.cam.screenToWorld(sx, sy);
    return { x: Math.floor(w.x / CELL_W), y: Math.floor(w.y / CELL_H) };
  }

  onHover(e) {
    this.game.hoverCell = this.cellFromEvent(e);
    this.game.hoverEnt = this.game.hitTest(e) || null;   // E5/C3: 施法目标 (实体优先)
  }

  onClick(e) {
    const g = this.game;
    const cell = this.cellFromEvent(e);
    // 优先点实体 (渲染缓存 _sx/_sy 在 render.js frame() 写入)
    const hit = g.hitTest(e);
    if (hit) { g.ui.showObjInfo(hit, e); return; }
    // 否则朝该格走一步 (简单直接移动; 未寻路)
    const p = g.world.player;
    const dx = cell.x - p.x, dy = cell.y - p.y;
    if (Math.abs(dx) <= 6 && Math.abs(dy) <= 6) {
      let dir;
      if (dx === 0 && dy === 0) return;
      if (dx === 0) dir = dy < 0 ? 0 : 4;
      else if (dy === 0) dir = dx > 0 ? 2 : 6;
      else if (dx > 0) dir = dy < 0 ? 1 : 3;
      else dir = dy < 0 ? 7 : 5;
      g.world.player.dir = dir;
      g.tryStep(dir);
    }
  }

  update(dt) {
    const g = this.game;
    if (g.world.transitioning) return;
    const dir = resolveDir(this.keys);
    if (dir === null) {
      if (g.world.player.anim !== 'standing' && !g.world.player.inCombat) {
        g.world.player.anim = 'standing';
        g.world.player.animFrame = 0;
      }
      return;
    }
    this.moveTimer += dt * 1000;
    const interval = this.repeatMs / g.world.player.speed;
    if (this.moveTimer - this.lastMove >= interval) {
      this.lastMove = this.moveTimer;
      g.world.player.dir = dir;
      g.tryStep(dir);
    }
  }
}

export { STEP };
