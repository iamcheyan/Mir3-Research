// mouse.js — MouseWalker.cs 逐函数移植 (按住左键走 / 按住右键跑)
// 权威源: GodotClient/Scripts/MouseWalker.cs + GameScene.cs:970-987 (接线门控)。
// 方向算法 = 原版 22.5° 划分; 格步 600ms; 跑 = 相同 600ms 走 2 格 (骑马 3)。
// 世界像素系: CELL 48x32, 与 world.js camera 一致。

import * as data from './data.js';
import { directionFromPoint } from './frames.js';

const DIRS = [[0, -1], [1, -1], [1, 0], [1, 1], [0, 1], [-1, 1], [-1, 0], [-1, -1]];
const CELL_W = 48, CELL_H = 32;
const WALK_MS = 600.0, RUN_MS = 600.0;   // Globals.MoveTime / 跑=同节拍走 2 格
const shiftDir = (dir, i) => ((dir + i) % 8 + 8) % 8;  // Functions.ShiftDirection
const moveCell = (x, y, dir, d = 1) => [x + DIRS[dir][0] * d, y + DIRS[dir][1] * d];

export class MouseWalker {
  // deps: { world, canvas, mouseOverUi(), blockLeftWalk(), blockLeftMouse(),
  //         blockRightMouse(), getRunSteps(), canPlayerMove(), canPlayerTurn() }
  constructor(deps) {
    this.deps = deps;
    this.enabled = true;
    this.autoRun = false;          // D 键切换; 开启后左键也跑步 (GameScene.cs:9891-9893)
    this._nextSendMs = 0;
    this._suspendUntilRelease = false;
    this._lastDir = 4;             // MirDirection.Down
    this._leftDown = false;
    this._rightDown = false;
    this._mouse = { x: 0, y: 0 };  // client px

    const { canvas } = deps;
    canvas.addEventListener('mousedown', (ev) => {
      if (ev.button === 0) this._leftDown = true;
      if (ev.button === 2) this._rightDown = true;
    });
    // 全局抬起: 拖出画布也能复位 (DXWindow.cs:180 同理)
    addEventListener('mouseup', (ev) => {
      if (ev.button === 0) this._leftDown = false;
      if (ev.button === 2) this._rightDown = false;
    });
    addEventListener('mousemove', (ev) => { this._mouse.x = ev.clientX; this._mouse.y = ev.clientY; });
    addEventListener('blur', () => { this._leftDown = this._rightDown = false; });
  }

  // SuspendUntilInputRelease (MouseWalker.cs:60): 技能开始后中断, 须松开重按
  suspendUntilInputRelease() { this._suspendUntilRelease = true; }

  // AddMoveDelay (MouseWalker.cs:62-66): S.ObjectMove Slow
  addMoveDelay(ms) {
    if (ms <= 0) return;
    this._nextSendMs = Math.max(this._nextSendMs, performance.now() + ms);
  }

  // 世界像素 (与 world.js camera.worldToScreen 同一坐标系)
  #mouseWorld() {
    return this.deps.world.camera.screenToWorld(this._mouse.x, this._mouse.y);
  }
  #playerWorld() {
    const p = this.deps.world.player;
    // MouseWalker.cs:189 CellToScreen(cx,cy) + (CellWidth/2, CellHeight/2) — 格中心
    return { x: p.x * CELL_W + (p.offX ?? 0) + CELL_W / 2, y: p.y * CELL_H + (p.offY ?? 0) + CELL_H / 2 };
  }

  // ComputeDirection (MouseWalker.cs:186-215): 22.5° 划分
  computeDirection(mouseWorld) {
    const pw = this.#playerWorld();
    const dx = mouseWorld.x - pw.x, dy = mouseWorld.y - pw.y;
    const cellX = Math.floor((dx + CELL_W / 2) / CELL_W);
    const cellY = Math.floor((dy + CELL_H / 2) / CELL_H);
    // 近距离按格坐标取方向 (<=2 格)
    if (Math.max(Math.abs(cellX), Math.abs(cellY)) <= 2) {
      if (cellX === 0 && cellY === 0) return this._lastDir;
      this._lastDir = directionFromPoint(0, 0, cellX, cellY);
      return this._lastDir;
    }
    // 远距离像素角度; 48x32 比例不可归一化
    let angle = Math.atan2(dx, -dy) * 180 / Math.PI;
    if (angle < 0) angle += 360;
    angle += 22.5;
    if (angle >= 360) angle -= 360;
    this._lastDir = Math.floor(angle / 45);
    return this._lastDir;
  }

  // CanMove(x,y) (MouseWalker.cs:218-225): 地形 Flag + 动态阻挡
  #cellPassable(x, y) {
    const w = this.deps.world;
    const m = w.mapMeta;
    if (!m || x < 0 || y < 0 || x >= m.w || y >= m.h) return false;
    if (w.walk && !data.walkable(w.walk, x, y, m.w)) return false;
    // GameScene.cs:4669 IsMovementCellBlocked: 活着的怪物/NPC/玩家挡路, 物品不挡
    for (const o of w.objects.values()) {
      if (o.x === x && o.y === y && !o.dead && o !== w.player) return false;
    }
    return true;
  }

  // CanMove(dir, distance) (MouseWalker.cs:231-243): 途经格全查
  #pathClear(dir, distance) {
    const p = this.deps.world.player;
    for (let i = 1; i <= distance; i++) {
      const [x, y] = moveCell(p.x, p.y, dir, i);
      if (!this.#cellPassable(x, y)) return false;
    }
    return true;
  }

  // BestWalkDirection (MouseWalker.cs:250-266)
  #bestWalkDirection(target, mouseWorld) {
    if (this.#pathClear(target, 1)) return target;
    const pw = this.#playerWorld();
    let angle = Math.atan2(mouseWorld.x - pw.x, -(mouseWorld.y - pw.y)) * 180 / Math.PI;
    if (angle < 0) angle += 360;
    let best = Math.floor(angle / 45);
    if (best === target) best = shiftDir(target, 1);
    const next = shiftDir(target, -best + target);
    if (this.#pathClear(best, 1)) return best;
    if (this.#pathClear(next, 1)) return next;
    return target;
  }

  // IsMouseWithinCells (MouseWalker.cs:268-275)
  #mouseWithinCells(range) {
    const pw = this.#playerWorld();
    const mw = this.#mouseWorld();
    const x = Math.floor((mw.x - pw.x + CELL_W / 2) / CELL_W);
    const y = Math.floor((mw.y - pw.y + CELL_H / 2) / CELL_H);
    return Math.max(Math.abs(x), Math.abs(y)) <= range;
  }

  // _Process (MouseWalker.cs:91-180)
  tick(now) {
    const d = this.deps;
    const w = d.world;
    if (!this.enabled || !w?.player || !w.mapMeta) return;

    if (this._suspendUntilRelease) {
      if (!this._leftDown && !this._rightDown && !this.autoRun) this._suspendUntilRelease = false;
      else return;
    }

    const leftDown = this._leftDown, rightDown = this._rightDown, autoRun = this.autoRun;

    // 鼠标在游戏 UI 上 → 点击是界面操作 (原版 MouseControl == this; AutoRun 不受影响)
    if (!autoRun && d.mouseOverUi?.()) return;

    // Shift 按住 = 原地攻击, 不走
    if (!autoRun && (d.shift?.() ?? false)) return;

    // Alt+左 = 采集分支, 不走 (Alt+右保持跑)
    if (!autoRun && leftDown && (d.alt?.() ?? false)) return;

    // 无输入
    if (!leftDown && !rightDown && !autoRun) return;

    if (!autoRun && leftDown && d.blockLeftMouse?.()) return;
    if (!autoRun && rightDown && d.blockRightMouse?.()) return;

    // 左键悬停可点物体 (怪/NPC/物品) → 让点击逻辑处理, 不走
    if (!autoRun && leftDown && d.blockLeftWalk?.()) return;

    if (now < this._nextSendMs) return;
    // ServerTime 门控: 一段移动完成前不发下一段
    if (d.awaitingServer?.()) return;

    const mouseWorld = this.#mouseWorld();
    const target = this.computeDirection(mouseWorld);
    const run = rightDown || autoRun;
    const steps = d.getRunSteps?.() ?? 2;
    let distance = run ? steps : 1;
    const canMove = d.canPlayerMove?.() ?? true;
    const canTurn = d.canPlayerTurn?.() ?? canMove;

    // 右键在玩家附近 (<=2 格) 或不可移动 → 只转身
    if (rightDown && (this.#mouseWithinCells(2) || !canMove)) {
      if (canTurn) d.sendTurn?.(target);
      this._nextSendMs = now + WALK_MS;
      return;
    }
    if (!canMove) return;

    // 撞墙绕路 (MouseDirectionBest)
    let dir = target;
    if (!this.#pathClear(target, distance)) {
      const best = this.#bestWalkDirection(target, mouseWorld);
      if (best === target && !this.#pathClear(target, 1)) {
        if (canTurn) d.sendTurn?.(target);
        this._nextSendMs = now + WALK_MS;
        return;
      }
      dir = best;
      distance = 1;
    }
    d.sendMove(dir, distance, run && distance >= 2);
    this._nextSendMs = now + (run ? RUN_MS : WALK_MS);
  }
}

export { DIRS, shiftDir, moveCell };
