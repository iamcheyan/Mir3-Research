// world.js — 共享世界控制器 (双 UI 模式共用): 对象系统/动画状态机/插值/战斗/渲染
// Phase2 移植自 GodotClient:
//   MapObjectNode.cs (帧推进/动作队列/移动插值), ObjectRenderer.cs (怪物/NPC/物品),
//   PlayerRenderer.cs (纸娃娃分层/帧公式), DamagePopupNode.cs (飘字),
//   CombatController.cs (自动攻击/追击/Shift 攻击), GameScene.cs (S.Object* 处理)
import * as data from './data.js';
import * as res from './res.js';
import { Camera } from './camera.js';
import {
  PLAYERS, DEFAULT_MONSTER, DEFAULT_NPC, DEFAULT_ITEM, NPC_SPECIAL, Frame,
  MAGIC, getAttackAnimation, getMagicAnimation, directionFromPoint, chebyshev,
  armourShift as assassinShift, CLASS_ASSASSIN,
  DIR_UP, DIR_UPRIGHT, DIR_RIGHT, DIR_DOWNRIGHT, DIR_DOWN, DIR_DOWNLEFT, DIR_LEFT, DIR_UPLEFT,
  MIR_ACTION,
} from './frames.js';
// [par-anim] 动作分派唯一权威 — PlayerObject.cs:578-803 / Functions.cs:119-346 逐行移植
import {
  AnimAction, PlayerAnimState, BUFF_DRAGON_REPULSE,
  actionFromRangeAttack, actionFromMagic, actionFromMining, actionFromFishing,
  actionFromTaming, actionFromDash,
} from './anims.js';
import { C, GRID } from './net.js';
import { MouseWalker } from './mouse.js';


const DIRS = [[0, -1], [1, -1], [1, 0], [1, 1], [0, 1], [-1, 1], [-1, 0], [-1, -1]];
export { DIRS };
const CLS_KEYS = ['Warrior', 'Wizard', 'Taoist', 'Assassin', 'Archer'];

// 一次性动作集合 (PlayerRenderer.cs:283-290)
const ONE_SHOT = new Set(['combat1', 'combat2', 'combat3', 'combat4', 'combat5', 'combat6',
  'combat7', 'combat8', 'combat9', 'combat10', 'combat11', 'combat12', 'combat13', 'combat14',
  'combat15', 'struck', 'pushed', 'harvest', 'fishingCast', 'fishingReel', 'tamingCast',
  'channellingStart', 'channellingEnd', 'dragonRepulseStart', 'dragonRepulseEnd', 'die', 'dead']);
// [par-anim] 钓鱼/驯兽等待态播完保持 (PlayerObject.cs:639/644 状态机)
const KEEP_ON_FINISH = new Set(['die', 'dead', 'channellingMiddle', 'dragonRepulseMiddle', 'fishingWait', 'tamingWait']);

// ---- 帧资源 (sprite + manifest 锚点, 同 webclient sprites.js) ----
const frameCache = new Map();
async function spriteFrame(lib, frame) {
  const key = lib + ':' + frame;
  if (frameCache.has(key)) return frameCache.get(key);
  const p = (async () => {
    const im = await res.loadSprite(lib, frame);
    if (!im) return null;
    const meta = await res.frameMeta(lib);
    const m = meta[frame];
    return { img: im, w: m ? m[0] : im.width, h: m ? m[1] : im.height, ox: m ? m[2] : 0, oy: m ? m[3] : 0 };
  })();
  frameCache.set(key, p);
  p.then(v => frameCache.set(key, v));   // 就地换 resolved 值, 加速下次同步取
  return p;
}
function drawFramed(ctx, fr, sx, sy, alpha = 1) {
  if (!fr) return;
  if (alpha < 1) ctx.globalAlpha = alpha;
  ctx.drawImage(fr.img, sx + fr.ox, sy + fr.oy, fr.w, fr.h);
  if (alpha < 1) ctx.globalAlpha = 1;
}

function argbToCss(v, fallback = '#fff') {
  if (v == null || v === 0 || v === -1) return fallback;
  const a = (v >>> 24) & 255, r = (v >>> 16) & 255, g = (v >>> 8) & 255, b = v & 255;
  if (a === 0) return fallback;
  return `rgba(${r},${g},${b},${(a / 255).toFixed(3)})`;
}

// ====================================================================
// MapObject — 帧状态机 + 移动插值 (MapObjectNode.cs)
// ====================================================================
class MapObject {
  constructor(world, objectID) {
    this.world = world;
    this.objectID = objectID;
    this.x = 0; this.y = 0; this.dir = DIR_DOWN;
    this.dead = false; this.poison = 0;
    this.tables = DEFAULT_MONSTER;         // 子类覆盖
    this.animName = 'standing';
    this.animStartMs = performance.now();
    this.actionQueue = [];                 // 一次性动作
    this.moveQueue = [];                   // {dist, dir}
    this.moving = false;
    this.moveStartMs = 0; this.moveDist = 1; this.startX = 0; this.startY = 0;
    this.moveDurMs = 600;
    this.offX = 0; this.offY = 0;
    this.nameColour = null; this.petOwner = '';
    this.hp = 0; this.maxHp = 0; this.showHpUntil = 0;
    this.chatText = null; this.chatUntil = 0;
    this._sx = 0; this._sy = 0; this._w = 0; this._h = 0;   // 上帧绘制包围盒 (命中测试)
    this._lastDrawn = [];
  }

  get isOneShot() { return ONE_SHOT.has(this.animName); }

  // SetAnimation (MapObjectNode.cs:104-119)
  setAnimation(name, immediate = false) {
    if (!this.tables[name]) name = 'standing';   // 缺表回退
    if (this.animName === name && !immediate && !this.isOneShot) return;
    this.animName = name;
    this.animStartMs = performance.now();
    if (name === 'walking' || name === 'running' || name === 'horseWalking' || name === 'horseRunning'
      || name === 'creepWalkFast' || name === 'creepWalkSlow') {
      this.moving = true;
    }
    this.animState && (this.animState.currentAnimation = name);   // [par-anim] 状态机跟随 (Fishing/Taming/DragonRepulse 依赖)
  }

  // 入队 (PlayerRenderer.cs:246-258): 忙碌时排队
  play(name) {
    if (this.isOneShot && !this.finished()) this.actionQueue.push(name);
    else this.setAnimation(name, true);
  }

  finished() {
    const f = this.tables[this.animName];
    if (!f) return true;
    return f.getFrame(this.animStartMs, performance.now(), this.actionQueue.length > 0) >= f.count;
  }

  // DoNextAction (MapObjectNode.cs:124-137)
  nextAction() {
    if (this.dead) { this.setAnimation('dead', true); return; }
    if (this.moveQueue.length) {
      const m = this.moveQueue.shift();
      this.startMove(m.dist, m.dir);
      return;
    }
    if (this.actionQueue.length) { this.setAnimation(this.actionQueue.shift(), true); return; }
    this.setAnimation(this.standAnim(), true);
  }
  standAnim() { return 'standing'; }

  // StartMove (MapObjectNode.cs:245-262): 权威格立即到终点 + Offset 回拉
  startMove(dist, dir) {
    this.dir = dir;
    const [dx, dy] = DIRS[dir];
    this.startX = this.x; this.startY = this.y;
    this.x += dx * dist; this.y += dy * dist;
    const walk = this.tables.walking ?? this.tables.standing;
    this.moveDurMs = Math.max(1, walk.sum);
    this.moveStartMs = performance.now();
    this.moveDist = dist;
    this.setAnimation(this.moveAnim(), true);
  }
  moveAnim() { return 'walking'; }

  // UpdateMoveOffset (MapObjectNode.cs:170-223)
  updateOffset(now) {
    if (!this.moving) { this.offX = 0; this.offY = 0; return; }
    const f = this.tables[this.animName];
    if (!f || f.count <= 1 || (this.animName !== 'walking' && this.animName !== 'running'
      && this.animName !== 'horseWalking' && this.animName !== 'horseRunning'
      && this.animName !== 'creepWalkFast' && this.animName !== 'creepWalkSlow'
      && this.animName !== 'combat8')) {   // [par-anim] 冲锋 Combat8 滑行 (StaticSpeed, PlayerObject.cs:614)
      this.moving = false; this.offX = 0; this.offY = 0; return;
    }
    const t = Math.min(1, Math.max(0, (now - this.moveStartMs) / this.moveDurMs));
    if (t >= 1) {
      this.moving = false; this.offX = 0; this.offY = 0;
      if (this.isOneShot && this.finished()) this.nextAction();
      return;
    }
    const k = 1 - t;
    let ox = -DIRS[this.dir][0] * data.CELL_W * this.moveDist * k;
    let oy = -DIRS[this.dir][1] * data.CELL_H * this.moveDist * k;
    ox -= ox % 2; oy -= oy % 2;   // 偶数像素对齐
    this.offX = ox; this.offY = oy;
  }

  // 播完后调度的钩子 (MapObjectNode._Process 215-235)
  tick(now) {
    this.updateOffset(now);
    // [par-anim] ChannellingStart(元素风暴起手) 播完 → 引导中段 (PlayerRenderer.cs:720-725)
    if (this.animState && this.animName === 'channellingStart' && this.finished()
      && this.animState.hasBuff(203)) {
      this.setAnimation('channellingMiddle', true);
    }
    // [par-anim] DragonRepulseStart 播完 → 中段 (buff 仍在时)
    if (this.animState && this.animName === 'dragonRepulseStart' && this.finished()
      && this.animState.hasBuff(408)) {
      this.setAnimation('dragonRepulseMiddle', true);
    }
    const interrupted = (this.animName === 'standing' || this.animName === 'dead')
      && (this.actionQueue.length || this.moveQueue.length);
    if (this.finished() || interrupted) {
      if (!KEEP_ON_FINISH.has(this.animName) || this.moveQueue.length || this.actionQueue.length) {
        this.nextAction();
      }
    }
  }

  // RenderY (MapObjectNode.cs:304-308): 移动向上时按起点行
  renderY() {
    if (this.moving && (this.dir === DIR_UP || this.dir === DIR_UPRIGHT || this.dir === DIR_UPLEFT)) {
      return this.y - DIRS[this.dir][1] * this.moveDist;
    }
    return this.y;
  }

  frameIndex(now) {
    const f = this.tables[this.animName];
    if (!f) return { f: null, i: 0 };
    let i = f.getFrame(this.animStartMs, now, this.actionQueue.length > 1);
    if (i >= f.count) i = f.count - 1;   // 非循环播完停末帧
    return { f, i };
  }

  // ---- 绘制 (子类覆盖 drawAt) ----
  async draw(ctx, ax, ay, now) { this._sx = ax; this._sy = ay; this._w = data.CELL_W; this._h = data.CELL_H; }

  drawName(ctx, ax, ay, now = performance.now()) {
    const name = this.displayName();
    if (!name) return;
    ctx.font = '12px "Noto Sans CJK SC","Noto Sans CJK",sans-serif';
    ctx.textAlign = 'center';
    const y = ay - this.nameBaseline();
    ctx.fillStyle = 'rgba(0,0,0,.75)';
    ctx.fillText(name, ax + 1, y + 1);
    ctx.fillStyle = this.nameCss();
    ctx.fillText(name, ax, y);
    // 中毒绿点 (ObjectRenderer.cs:596)
    if (this.poison) {
      ctx.fillStyle = 'rgba(89,255,89,.85)';
      ctx.beginPath(); ctx.arc(ax, ay - this.nameBaseline() - 12, 3, 0, Math.PI * 2); ctx.fill();
    }
    if (this.petOwner) {
      ctx.font = '10px "Noto Sans CJK SC"';
      ctx.fillStyle = 'rgba(0,0,0,.6)'; ctx.fillText(`(${this.petOwner})`, ax + 1, ay + 13);
      ctx.fillStyle = 'rgba(178,230,178,.9)'; ctx.fillText(`(${this.petOwner})`, ax, ay + 12);
    }
    if (this.chatText && now < this.chatUntil) {
      ctx.font = '11px "Noto Sans CJK SC"';
      ctx.fillStyle = 'rgba(0,0,0,.7)'; ctx.fillText(this.chatText, ax + 1, ay - this.nameBaseline() - 17);
      ctx.fillStyle = '#fff'; ctx.fillText(this.chatText, ax, ay - this.nameBaseline() - 18);
    }
  }
  nameBaseline() { return 42; }
  displayName() { return this.name ?? null; }
  nameCss() { return argbToCss(this.nameColour, '#fff'); }

  // 头顶血条 (MapObjectNode.cs:321-352 + GameScene.cs:4078-4107)
  drawHealthBar(ctx, ax, ay, now) {
    if (this.dead || this.maxHp <= 0 || now > this.showHpUntil) return;
    const bg = this.world.interfaceFrames[80], fill = this.world.interfaceFrames[79];
    if (!bg || !fill) return;
    const x = ax - bg.w / 2, y = ay - 55;
    ctx.drawImage(bg.img, x, y, bg.w, bg.h);
    const ratio = Math.min(1, Math.max(0, this.hp / this.maxHp));
    const sw = Math.min(fill.w, Math.max(1, Math.round(fill.w * ratio)));
    ctx.drawImage(fill.img, 0, 0, sw, fill.h, x + 1, y, sw, fill.h);
  }

  hitTest(px, py) {
    const h = this._h || data.CELL_H, w = Math.max(this._w || data.CELL_W, 40);
    return px >= this._sx - w / 2 && px <= this._sx + w / 2 && py >= this._sy - h && py <= this._sy;
  }
}

// ====================================================================
// MonsterObject (ObjectRenderer.cs:55-100)
// ====================================================================
class MonsterObject extends MapObject {
  constructor(world, p) {
    super(world, p.objectID);
    this.monsterIndex = p.monsterIndex;
    this.customName = p.customName;
    this.nameColour = p.nameColour;
    this.petOwner = p.petOwner;
    this.x = p.x; this.y = p.y; this.dir = p.direction;
    this.dead = p.dead; this.poison = p.poison;
    this.tables = DEFAULT_MONSTER;
    this.#resolveInfo();   // 数据可能晚于包到达, draw 时再补解析
    this.setAnimation(this.dead ? 'dead' : 'standing', true);
  }
  #resolveInfo() {
    const info = data.D().monstersById?.[this.monsterIndex];
    if (!info) return false;
    this.info = info;
    this.lib = info.lib;
    this.shape = info.shape;
    this.zhName = info.zh ?? info.name ?? '';
    this.name = this.customName || this.zhName;
    return true;
  }
  displayName() { return this.world.showMonsterNames ? this.name : null; }
  // BodyFrame = DrawFrame + Shape*1000 (ObjectRenderer.cs:391)
  bodyFrame(f, i) { return i + f.start + f.offset * this.dir + this.shape * 1000; }
  async draw(ctx, ax, ay, now) {
    if (!this.lib && !this.#resolveInfo()) return;
    const { f, i } = this.frameIndex(now);
    const fr = await spriteFrame(this.lib, this.bodyFrame(f, i));
    if (fr) {
      drawFramed(ctx, fr, ax, ay);
      this._w = fr.w + Math.abs(fr.ox); this._h = fr.h + Math.abs(fr.oy);
    }
    this._sx = ax; this._sy = ay;
    this._lastDrawn.push(fr);
  }
}

// ====================================================================
// NPCObject (ObjectRenderer.cs:103-141, 270-297)
// ====================================================================
class NPCObject extends MapObject {
  constructor(world, p) {
    super(world, p.objectID);
    const info = data.D().npcById?.get(p.npcIndex);
    this.info = info;
    this.name = info?.zh ?? info?.name ?? '';
    this.x = p.x; this.y = p.y; this.dir = p.direction ?? DIR_DOWN;
    const img = info?.image ?? 0;
    this.image = img;
    // 特例帧表 (ObjectRenderer.cs:270-297)
    const sp = NPC_SPECIAL.get(img);
    if (sp) {
      this.tables = sp.single
        ? { standing: new Frame(0, 1, 0, 3600000) }
        : { standing: new Frame(sp.start, sp.count, 0, sp.ms) };
    } else {
      this.tables = DEFAULT_NPC;
    }
    this.setAnimation('standing', true);
  }
  nameCss() { return 'rgb(102,255,102)'; }    // 固定绿 (0.4,1,0.4)
  nameBaseline() { return 36; }
  async draw(ctx, ax, ay, now) {
    const { f, i } = this.frameIndex(now);
    const fr = await spriteFrame('NPC', i + f.start + f.offset * this.dir + this.image * 100);
    if (fr) {
      drawFramed(ctx, fr, ax, ay);
      this._w = fr.w + Math.abs(fr.ox); this._h = fr.h + Math.abs(fr.oy);
    }
    this._sx = ax; this._sy = ay;
    this._lastDrawn.push(fr);
  }
}

// ====================================================================
// ItemObject (ObjectRenderer.cs:145-186, 537-549)
// ====================================================================
class ItemObject extends MapObject {
  constructor(world, p) {
    super(world, p.objectID);
    this.item = p.item;
    const info = data.D().itemsById?.[p.item?.infoIndex];
    this.info = info;
    this.name = info?.zh ?? info?.name ?? '';
    this.x = p.location.x; this.y = p.location.y;
    this.tables = DEFAULT_ITEM;
  }
  nameCss() { return argbToCss(this.info?.rarityColour, '#ccc'); }
  nameBaseline() { return 18; }   // 物品名 y=-18
  async draw(ctx, ax, ay, now) {
    if (this.info?.image == null) return;
    const fr = await spriteFrame('Ground', this.info.image);
    if (fr) {
      // 居中: ox=(48-w)/2, oy=(32-h)/2 (ObjectRenderer.cs:537-549)
      const dx = (data.CELL_W - fr.w) / 2, dy = (data.CELL_H - fr.h) / 2;
      ctx.drawImage(fr.img, ax - data.CELL_W / 2 + dx, ay - data.CELL_H + dy, fr.w, fr.h);
      this._w = fr.w; this._h = fr.h;
    }
    this._sx = ax; this._sy = ay;
    this._lastDrawn.push(fr);
  }
}

// ====================================================================
// PlayerObject (PlayerRenderer.cs) — 纸娃娃
// ====================================================================
class PlayerObject extends MapObject {
  constructor(world, p, isSelf = false) {
    super(world, p.objectID);
    this.isSelf = isSelf;
    this.name = p.name ?? '';
    this.caption = p.caption ?? '';
    this.guildName = p.guildName ?? '';
    this.nameColour = p.nameColour ?? null;
    this.x = p.x; this.y = p.y; this.dir = p.direction ?? DIR_DOWN;
    this.class = p.class; this.gender = p.gender;
    this.hairType = p.hairType ?? 0; this.hairColour = p.hairColour;
    this.weapon = p.weapon ?? -1; this.shield = p.shield ?? -1;
    this.armour = p.armour ?? 0; this.costume = p.costume ?? -1;
    this.armourColour = p.armourColour;
    this.helmet = p.helmet ?? -1;
    this.horse = p.horse ?? 0; this.horseShape = p.horseShape ?? 0;
    this.dead = p.dead ?? false; this.poison = p.poison ?? 0;
    this.level = p.level;
    this.tables = PLAYERS;
    // [par-anim] 动作分派状态 (PlayerObject.cs:578-803 逐行移植, 见 anims.js)
    this.animState = new PlayerAnimState();
    this.animState.horse = this.horse;
    if (Array.isArray(p.buffs)) {          // StartInformation: ClientBuffInfo[] (自带 index)
      this._buffTypes = new Map();
      for (const b of p.buffs) if (b) { this._buffTypes.set(b.index, b.type); this.animState.addBuff(b.type); }
    } else if (p.buffs) {                  // ObjectPlayer: Dictionary<BuffType,int>
      for (const t of Object.keys(p.buffs)) this.animState.addBuff(+t);
    }
    this.setAnimation(this.dead ? 'dead' : this.standAnim(), true);
    this.refreshLibs();
  }
  get isAssassin() { return this.class === CLASS_ASSASSIN; }
  refreshLibs() {
    this.libs = data.pickLibs({
      cls: CLS_KEYS[this.class] ?? 'Warrior',
      gender: this.gender === 1 ? 'F' : 'M',
      armourShape: this.armour, weaponShape: this.weapon, helmetShape: this.helmet,
    });
  }
  // ---- [par-anim] anims.js 分派接入 (唯一权威: PlayerObject.cs:578-803) ----
  syncAnimState() {
    this.animState.horse = this.horse;
    this.animState.currentAnimation = this.animName;
  }
  // 包/预测动作 → 全分派 (SetAnimation+SetFrame 合并语义; Attack/Spell 后 StanceTime=+3s)
  applyAnimAction(action) {
    action.cls = this.class;
    action.weaponShape = this.weapon;
    this.syncAnimState();
    const sel = this.animState.apply(action, performance.now());
    if (!sel) return null;
    this.setAnimation(sel.anim, true);
    return sel;
  }
  // Standing 分派 (PlayerObject.cs:585-605): 引导>龙威>骑马>潜行>Stance>普通
  standAnim() {
    this.syncAnimState();
    const sel = this.animState.selectAnimation(
      new AnimAction(MIR_ACTION.Standing, this.dir, { x: this.x, y: this.y }), performance.now());
    return sel ? sel.anim : 'standing';
  }
  // Moving 分派 (PlayerObject.cs:606-624): 冲锋Combat8 > 潜行步(CreepWalk) > 跑/走 > 骑马
  startMove(dist, dir, _running = false) {
    this.dir = dir;
    this.syncAnimState();
    const sel = this.animState.selectAnimation(
      new AnimAction(MIR_ACTION.Moving, dir, { x: this.x, y: this.y }, [dist, this._movingMagic ?? 0]), performance.now());
    this.animState.currentAnimation = sel.anim;
    const [dx, dy] = DIRS[dir];
    this.startX = this.x; this.startY = this.y;
    this.x += dx * dist; this.y += dy * dist;
    const tbl = this.tables[sel.anim] ?? this.tables.walking ?? this.tables.standing;
    this.moveDurMs = Math.max(1, tbl.sum);   // 位移时长=动画帧总长 (PlayerRenderer.cs:747)
    this.moveStartMs = performance.now();
    this.moveDist = dist;
    this._movingMagic = 0;
    this.setAnimation(sel.anim, true);
  }
  playCombat(magic = 0) {
    this.applyAnimAction(new AnimAction(MIR_ACTION.Attack, this.dir, { x: this.x, y: this.y }, [0, magic, 0]));
  }
  playStruck() {   // Struck 分派 (PlayerObject.cs:664-668): 骑马→HorseStruck
    this.syncAnimState();
    const sel = this.animState.selectAnimation(
      new AnimAction(MIR_ACTION.Struck, this.dir, { x: this.x, y: this.y }), performance.now());
    this.play(sel ? sel.anim : 'struck');
  }
  playDie() { this.dead = true; this.setAnimation('die', true); }

  // 帧公式 (PlayerRenderer.cs:808-845)
  #drawFrame(f, i) { return i + f.start + f.offset * this.dir; }
  #armourOffset() { return this.isAssassin ? 3000 : 5000; }
  async draw(ctx, ax, ay, now) {
    const { f, i } = this.frameIndex(now);
    const df = this.#drawFrame(f, i);
    const shift = assassinShift(this.animName, this.isAssassin);
    const aso = this.#armourOffset();
    const costumeBlock = this.costume >= 0 ? this.costume % 10 : null;
    const armourBlock = costumeBlock ?? (this.armour % 11);
    const wshape = this.weapon >= 1000 ? this.weapon - 1000 : this.weapon;
    const hideWeapon = this.animState.drawWeapon === false   // [par-anim] PoisonousCloud 施法藏武器 (PlayerObject.cs:657)
      || (costumeBlock != null && [6, 7, 8, 9, 10, 11, 12, 13, 16, 17, 18].includes(costumeBlock));

    const jobs = [];
    const backDirs = [DIR_UP, DIR_DOWNLEFT, DIR_LEFT, DIR_UPLEFT];
    const frontDirs = [DIR_UPRIGHT, DIR_RIGHT, DIR_DOWNRIGHT, DIR_DOWN];
    const layers = [];   // {fr, z}
    // ② 背武器
    if (this.weapon >= 0 && !hideWeapon && backDirs.includes(this.dir))
      layers.push([this.libs.weapon, df + (wshape % 10) * 5000, 0]);
    // ③ 背盾 (directions 1,2,3)
    if (this.shield >= 0 && [DIR_UPRIGHT, DIR_RIGHT, DIR_DOWNRIGHT].includes(this.dir))
      layers.push([this.libs.helmet ? this.libs.helmet : null, 0, -1]); // (盾库暂缺, 跳过)
    // ④ 身体
    layers.push([this.libs.body, df + armourBlock * aso + shift, 1]);
    // ⑤ 头: 盔 > 发
    if (this.helmet > 0)
      layers.push([this.libs.helmet, df + ((this.helmet - 1) % 10) * aso + shift, 2]);
    else if (this.hairType > 0)
      layers.push([this.libs.hair, df + (this.hairType - 1) * 5000, 2]);
    // ⑥ 前武器
    if (this.weapon >= 0 && !hideWeapon && frontDirs.includes(this.dir))
      layers.push([this.libs.weapon, df + (wshape % 10) * 5000, 3]);

    for (const [lib, frame, z] of layers) {
      if (!lib) continue;
      jobs.push(spriteFrame(lib, frame).then(fr => { if (fr) drawFramed(ctx, fr, ax, ay); }).catch(() => {}));
    }
    await Promise.all(jobs);
    this._sx = ax; this._sy = ay; this._w = 48; this._h = 100;
    this._lastDrawn = [];
  }
  nameBaseline() { return 46; }
  nameCss() { return argbToCss(this.nameColour, this.isSelf ? '#7fd4ff' : '#fff'); }
  drawName(ctx, ax, ay, now) {
    super.drawName(ctx, ax, ay, now);
    if (this.guildName) {
      ctx.font = '10px "Noto Sans CJK SC"';
      ctx.fillStyle = 'rgba(0,0,0,.65)'; ctx.fillText(this.guildName, ax + 1, ay - 33);
      ctx.fillStyle = 'rgba(204,204,102,.9)'; ctx.fillText(this.guildName, ax, ay - 34);
    }
  }
}

// ====================================================================
// 特效/弹道/飘字
// ====================================================================
class EffectNode {
  // MirEffectNode.cs: DrawFrame = i + start + dir*skip
  constructor(lib, start, count, ms, { skip = 10, dir = 0, x, y, alpha = 1, blend = null } = {}) {
    Object.assign(this, { lib, start, count, ms, skip, dir, x, y, alpha });
    this.t0 = performance.now();
    this.done = false;
  }
  frameIdx(now) { return Math.floor((now - this.t0) / this.ms); }
  async draw(ctx, ax, ay, now) {
    const i = this.frameIdx(now);
    if (i >= this.count) { this.done = true; return; }
    const fr = await spriteFrame(this.lib, this.start + i + this.dir * this.skip);
    if (fr) drawFramed(ctx, fr, ax, ay, this.alpha);
  }
}
class ProjectileNode {
  // MirProjectileNode.cs: 线性插值 + 追踪
  constructor(lib, start, count, ms, { skip = 10, dir = 0, from, to, delayMs = 0 } = {}) {
    Object.assign(this, { lib, start, count, ms, skip, dir, from, to, delayMs });
    this.t0 = performance.now();
    // duration = 等距 Chebyshev 距离 ms
    const px = Math.max(Math.abs(from.x - to.x) * data.CELL_W, Math.abs(from.y - to.y) * data.CELL_H);
    this.dur = Math.max(150, px);
    this.done = false;
  }
  async draw(ctx, now) {
    const t = (now - this.t0 - this.delayMs) / this.dur;
    if (t < 0) return;
    if (t >= 1) { this.done = true; return; }
    const wx = (this.from.x + (this.to.x - this.from.x) * t) * data.CELL_W + data.CELL_W / 2;
    const wy = (this.from.y + (this.to.y - this.from.y) * t + 1) * data.CELL_H;
    const cam = this.camera;
    const p = cam.worldToScreen(wx, wy);
    const i = Math.floor(((now - this.t0) / this.ms)) % this.count;
    const fr = await spriteFrame(this.lib, this.start + i + this.dir * this.skip);
    if (fr) drawFramed(ctx, fr, p.x, p.y);
  }
}
class DamagePopup {
  // DamagePopupNode.cs
  constructor(value, { miss, block, critical, resist } = {}) {
    this.t0 = performance.now();
    this.done = false;
    if (miss) { this.text = 'Miss'; this.colour = 'rgba(255,255,255,1)'; }
    else if (block) { this.text = 'Block'; this.colour = 'rgba(255,255,255,1)'; }
    else if (resist) { this.text = String(Math.abs(value)); this.colour = 'rgba(89,217,255,1)'; }
    else if (critical) { this.text = String(Math.abs(value)); this.colour = 'rgba(255,217,38,1)'; }
    else { this.text = String(Math.abs(value)); this.colour = 'rgba(255,89,64,1)'; }
    this.ax = 0; this.ay = 0;
  }
  draw(ctx, ax, ay, now) {
    const age = now - this.t0;
    if (age >= 900) { this.done = true; return; }
    const y = ay - 62 - (age / 1000) * 18;
    ctx.globalAlpha = 1 - age / 900;
    ctx.font = '11px "Noto Sans CJK SC",sans-serif';
    ctx.textAlign = 'center';
    ctx.fillStyle = 'rgba(0,0,0,.8)'; ctx.fillText(this.text, ax + 1, y + 1);
    ctx.fillStyle = this.colour; ctx.fillText(this.text, ax, y);
    ctx.globalAlpha = 1;
  }
}

// ====================================================================
// World
// ====================================================================
export class World {
  // hooks: {onChat, onPosChange, onMapChange, onStats, onHealth, onMana, onTarget}
  constructor(conn, startInfo, canvas, hooks = {}) {
    this.conn = conn;
    this.info = startInfo;
    this.canvas = canvas;
    this.hooks = hooks;
    this.objects = new Map();
    this.moveLock = false;
    this.camera = new Camera(canvas);
    this.camera.setResolution(innerWidth, innerHeight);
    this.camera.setZoom(1);
    addEventListener('resize', () => {
      this.camera.setResolution(innerWidth, innerHeight);
      this.camera.setZoom(1);
    });
    this.effects = [];         // EffectNode
    this.popups = [];          // DamagePopup (含锚定对象)
    this.showMonsterNames = true;
    this.showMonsterHealth = true;
    this.showDamageNumbers = true;
    this.target = null;        // 选中目标 (CombatController)
    this.mouseHeld = false;
    this.nextAttackMs = 0;
    this.lastChaseMs = 0;
    this.pickupTarget = null;
    this.interfaceFrames = {}; // 79/80 血条
    this.self = null;
    this.#wire();
    void this.#enterWorld();
  }

  addChat(text, type) { this.hooks.onChat?.(text, type); }

  async #enterWorld() {
    await data.loadAll();
    // 竞态修复: loadAll 前到达的 ObjectPlayer/PlayerObject 拿到 null-libs 骨架
    // (data.pickLibs 防护), 数据就绪后统一重解析 (par-keys R5 转来的启动竞态)
    for (const o of this.objects?.values?.() ?? []) if (o?.refreshLibs) o.refreshLibs();
    const maps = data.D().maps;
    let stem = null;
    for (const [s, m] of Object.entries(maps)) if (m.id === this.info.mapIndex) { stem = s; break; }
    if (!stem) { console.error('未知 MapIndex', this.info.mapIndex); return; }
    this.stem = stem;
    this.mapMeta = maps[stem];
    this.walk = await data.walkBits(stem);
    this.#applyLight();
    data.D().npcById = new Map((data.D().npcs ?? []).map(n => [n.id, n]));
    // 自己 (StartInformation → PlayerObject)
    this.player = new PlayerObject(this, {
      objectID: this.info.objectID, name: this.info.name, caption: this.info.caption,
      guildName: this.info.guildName, nameColour: null,
      x: this.info.locationX, y: this.info.locationY, direction: this.info.direction,
      class: this.info.class, gender: this.info.gender, level: this.info.level,
      hairType: this.info.hairType, hairColour: this.info.hairColour,
      weapon: this.info.weapon, shield: this.info.shield, armour: this.info.armour,
      costume: this.info.costume, armourColour: this.info.armourColour,
      helmet: this.info.helmet ?? -1, horse: this.info.horse, horseShape: this.info.horseShape ?? 0,
      dead: false, poison: 0, buffs: this.info.buffs,
    }, true);
    this.self = this.player;
    this.player.hp = this.info.hp; this.player.maxHp = this.info.hp;
    this.player.mp = this.info.mp; this.player.maxMp = this.info.mp;
    this.objects.set(this.player.objectID, this.player);
    this.camera.centerOn(this.player.x * data.CELL_W, this.player.y * data.CELL_H);
    this.hooks.onPosChange?.(this.player);
    // 回放竞态期缓存的 S.StatsUpdate (登录 burst 早于 enterWorld 完成)
    if (this._pendingStats) {
      const d = this._pendingStats; this._pendingStats = null;
      const s = d.stats;
      if (s?.values) for (const [k, v] of s.values) {
        if (k === 2) { this.player.hp = v; this.player.maxHp = Math.max(this.player.maxHp, v); }
        else if (k === 3) { this.player.mp = v; this.player.maxMp = Math.max(this.player.maxMp, v); }
        else if (k === 16) this.attackSpeed = v;
      }
      this.hooks.onStats?.(this.#selfStats());
      this.hooks.onRawStats?.(d);
    }
    // 血条贴图
    for (const n of [79, 80]) {
      spriteFrame('Interface', n).then(fr => { if (fr) this.interfaceFrames[n] = fr; });
    }
    this._startLoop();
    this.addChat(`欢迎来到 ${this.mapMeta.name_cn} (${stem})`, 'system');
    this.addChat('方向键/WASD 走路, 点击怪物攻击, 点击物品拾取, Enter 聊天', 'hint');
  }

  #selfStats() {
    const p = this.player;
    return { hp: p.hp ?? 0, maxHp: p.maxHp ?? 0, mp: p.mp ?? 0, maxMp: p.maxMp ?? 0 };
  }

  // ---- 网络事件 ----
  #wire() {
    const c = this.conn;
    const obj = id => this.objects.get(id);

    c.addEventListener('objectMove', (e) => this.#onObjectMove(e.detail));
    c.addEventListener('objectTurn', (e) => {
      const d = e.detail;
      const o = obj(d.objectID);
      if (o) { o.dir = d.direction; o.x = d.x; o.y = d.y; }
    });
    c.addEventListener('objectRemove', (e) => {
      const id = e.detail.objectID;
      if (this.target?.objectID === id) this.#setTarget(null);
      if (this.pickupTarget?.objectID === id) this.pickupTarget = null;
      this.objects.delete(id);
    });
    c.addEventListener('objectPlayer', (e) => {
      const p = e.detail;
      if (this.player && p.objectID === this.player.objectID) return;
      this.objects.set(p.objectID, new PlayerObject(this, p));
    });
    c.addEventListener('objectMonster', (e) => {
      const p = e.detail;
      this.objects.set(p.objectID, new MonsterObject(this, p));
    });
    c.addEventListener('objectNPC', (e) => {
      const p = e.detail;
      this.objects.set(p.objectID, new NPCObject(this, p));
    });
    c.addEventListener('objectItem', (e) => {
      const p = e.detail;
      if (!p.item) return;
      this.objects.set(p.objectID, new ItemObject(this, p));
    });
    c.addEventListener('userLocation', (e) => {
      const p = e.detail;
      if (!this.player) return;
      this.player.dir = p.direction;
      this.player.x = p.x; this.player.y = p.y;
      this.player.moving = false; this.player.offX = this.player.offY = 0;
      this.moveLock = false;
      this._moveServerLockUntil = 0;   // 服务端纠正(拒绝移动)同样解除门控 (GameScene.cs:1868)
      this.camera.centerOn(p.x * data.CELL_W, p.y * data.CELL_H);
      this.hooks.onPosChange?.(this.player);
    });
    c.addEventListener('chat', (e) => {
      // 头顶气泡 (GameScene.cs:2536 OnChat → ObjectRenderer.ChatText);
      // 日志渲染由 game.js #wireNet 唯一负责, 这里不再 addChat (双渲染根因)
      const p = e.detail;
      const o = obj(p.objectID);
      if (o && !p.overheadOnly) { o.chatText = p.text.length > 30 ? p.text.slice(0, 30) + '…' : p.text; o.chatUntil = performance.now() + 5000; }
    });
    c.addEventListener('mapChanged', async (e) => {
      if (!this.player) return;
      const maps = data.D().maps;
      for (const [s, m] of Object.entries(maps)) if (m.id === e.detail.mapIndex) {
        this.stem = s; this.mapMeta = m;
        this.walk = await data.walkBits(s);
        this.addChat(`进入 ${m.name_cn}`, 'system');
        this.objects.clear();
        this.effects.length = 0;
        this.#setTarget(null);
        this.objects.set(this.player.objectID, this.player);
        this.hooks.onMapChange?.(m);
      }
    });
    c.addEventListener('dayTime', (e) => {
      this.dayTime = Math.min(1, Math.max(0, e.detail));
      this.#applyLight();
    });
    c.addEventListener('disconnected', () => this.addChat('连接已断开', 'system'));

    // ---- 战斗 (GameScene.cs handlers) ----
    c.addEventListener('objectAttack', (e) => this.#onObjectAttack(e.detail));
    c.addEventListener('objectRangeAttack', (e) => this.#onObjectRangeAttack(e.detail));
    c.addEventListener('objectStruck', (e) => this.#onObjectStruck(e.detail));
    c.addEventListener('objectDied', (e) => this.#onObjectDied(e.detail));
    c.addEventListener('objectPushed', (e) => {
      const o = obj(e.detail.objectID);
      if (o) { o.dir = e.detail.direction; o.x = e.detail.location.x; o.y = e.detail.location.y; o.setAnimation('pushed', true); }
    });
    c.addEventListener('objectShow', (e) => {
      const o = obj(e.detail.objectID);
      if (o) { o.x = e.detail.location.x; o.y = e.detail.location.y; o.dir = e.detail.direction; o.setAnimation('show', true); }
    });
    c.addEventListener('objectHide', (e) => {
      const o = obj(e.detail.objectID);
      if (o) { o.x = e.detail.location.x; o.y = e.detail.location.y; o.dir = e.detail.direction; o.setAnimation('hide', true); }
    });
    c.addEventListener('objectIdle', (e) => {
      const o = obj(e.detail.objectID);
      if (o) { o.x = e.detail.location.x; o.y = e.detail.location.y; o.dir = e.detail.direction; o.setAnimation('standing', true); }
    });
    c.addEventListener('objectRevive', (e) => {
      const o = obj(e.detail.objectID);
      if (!o) return;
      o.dead = false;
      o.x = e.detail.location.x; o.y = e.detail.location.y;
      o.setAnimation(o === this.player ? o.standAnim() : 'standing', true);
    });
    c.addEventListener('objectHarvest', (e) => {
      const o = obj(e.detail.objectID);
      if (o) { o.x = e.detail.location.x; o.y = e.detail.location.y; o.dir = e.detail.direction; o.setAnimation('harvest', true); }
    });
    c.addEventListener('objectHarvested', (e) => {
      const o = obj(e.detail.objectID);
      if (o) { o.dead = true; o.x = e.detail.location.x; o.y = e.detail.location.y; o.dir = e.detail.direction; o.setAnimation('dead', true); }
    });
    c.addEventListener('objectPoison', (e) => {
      const o = obj(e.detail.objectID);
      if (o) o.poison = e.detail.poison;
    });
    c.addEventListener('objectMount', (e) => {   // [par-anim] Mount: 改 Horse 后走 Standing 分派 (CConnection.cs:1045-1067)
      const o = obj(e.detail.objectID);
      if (o instanceof PlayerObject) { o.horse = e.detail.horse; o.syncAnimState(); o.setAnimation(o.standAnim(), true); }
    });
    // ---- [par-anim] Mining/Fishing/Taming/Dash (CConnection.cs:1075-1297 各 Process) ----
    c.addEventListener('objectMining', (e) => {   // Mining → GetAttackAnimation(None) (PlayerObject.cs:632-634)
      const o = obj(e.detail.objectID);
      if (o instanceof PlayerObject) {
        o.x = e.detail.location.x; o.y = e.detail.location.y; o.dir = e.detail.direction;
        o.applyAnimAction(actionFromMining(e.detail));
      }
    });
    c.addEventListener('objectFishing', (e) => {  // Fishing Cast↔Wait↔Reel 状态机 (PlayerObject.cs:635-642)
      const o = obj(e.detail.objectID);
      if (o instanceof PlayerObject) {
        o.dir = e.detail.direction;
        o.applyAnimAction(actionFromFishing(e.detail));
      }
    });
    c.addEventListener('objectTaming', (e) => {   // Taming Cast→Wait 保持 (PlayerObject.cs:643-648)
      const o = obj(e.detail.objectID);
      if (o instanceof PlayerObject) {
        o.dir = e.detail.direction;
        o.applyAnimAction(actionFromTaming(e.detail));
      }
    });
    c.addEventListener('objectDash', (e) => {     // Dash: 距离>0 → StanceTime 3s + Moving(1, magic) (CConnection.cs:1218-1241)
      const o = obj(e.detail.objectID);
      if (!o) return;
      const d = e.detail;
      if (d.distance > 0 && o instanceof PlayerObject) {
        o.x = d.location.x; o.y = d.location.y; o.dir = d.direction;
        o._movingMagic = d.magic ?? 0;    // Moving Extra[1] (Combat8/Assault 特效)
        // 权威格已到终点, 从起点回拉 (StartMove 语义); 距离按包
        o.startMove(Math.max(1, d.distance), d.direction);
        o.applyAnimAction(actionFromDash(d));
      }
    });
    // ---- [par-anim] Buff 状态 → 动画 (GameScene.cs:5107-5159 OnBuffAdd/OnObjectBuffAdd) ----
    c.addEventListener('objectBuffAdd', (e) => {
      const o = obj(e.detail.objectID);
      if (o instanceof PlayerObject) {
        o.animState.addBuff(e.detail.type);
        // 龙威/引导立即切中段姿态; 潜行待 Stand 时生效 (PlayerObject.cs:591-603)
        if (e.detail.type === BUFF_DRAGON_REPULSE && o.animName === 'standing') o.setAnimation(o.standAnim(), true);
      }
    });
    c.addEventListener('objectBuffRemove', (e) => {
      const o = obj(e.detail.objectID);
      if (o instanceof PlayerObject) {
        o.animState.removeBuff(e.detail.type);
        // 龙威结束: 中段 → End (PlayerRenderer.cs:366-369 PlayDragonRepulseEnd)
        if (e.detail.type === BUFF_DRAGON_REPULSE && o.animName === 'dragonRepulseMiddle') o.setAnimation('dragonRepulseEnd', true);
      }
    });
    c.addEventListener('objectNameColour', (e) => {
      const o = obj(e.detail.objectID);
      if (o) o.nameColour = e.detail.colour;
    });
    c.addEventListener('objectLeveled', (e) => {
      const o = obj(e.detail.objectID);
      if (o === this.player) { this.addChat('恭喜升级!', 'system'); }
    });
    c.addEventListener('objectMagic', (e) => this.#onObjectMagic(e.detail));

    // ---- 自身状态 ----
    c.addEventListener('healthChanged', (e) => {
      const p = e.detail;
      const o = p.objectID === this.player?.objectID ? this.player : obj(p.objectID);
      if (!o) return;
      if (!p.miss && !p.block) o.hp = Math.max(0, o.hp + p.change);
      o.showHpUntil = performance.now() + 5000;
      if (this.showDamageNumbers && (p.change !== 0 || p.miss || p.block || p.resist)) {
        this.popups.push({ obj: o, popup: new DamagePopup(p.change, p) });
      }
      if (o === this.player) {
        this.hooks.onStats?.(this.#selfStats());
        if (!p.miss && !p.block && p.change < 0) this.player.playStruck();
      } else if (o instanceof PlayerObject) {
        if (!p.miss && !p.block && p.change < 0) o.playStruck();
      }
    });
    c.addEventListener('manaChanged', (e) => {
      if (e.detail.objectID !== this.player?.objectID) return;
      this.player.mp = Math.max(0, this.player.mp + e.detail.change);
      this.hooks.onStats?.(this.#selfStats());
    });
    c.addEventListener('statsUpdate', (e) => {
      if (!this.player) { this._pendingStats = e.detail; return; }  // 竞态: statsUpdate 早于 enterWorld → 缓存回放
      const s = e.detail.stats;
      if (s?.values) {
        for (const [k, v] of s.values) {
          if (k === 2) { this.player.hp = v; this.player.maxHp = Math.max(this.player.maxHp ?? 0, v); }   // STAT.HEALTH (InitHudData 语义: max 未知前取当前)
          else if (k === 3) { this.player.mp = v; this.player.maxMp = Math.max(this.player.maxMp ?? 0, v); } // STAT.MANA
          else if (k === 16) { this.attackSpeed = v; } // STAT.ATTACKSPEED
        }
      }
      this.hooks.onStats?.(this.#selfStats());
      this.hooks.onRawStats?.(e.detail);
    });
    // ---- [par-anim] 自身 Buff (S.BuffAdd/BuffRemove → PlayerRenderer 状态, GameScene.cs:5107-5159) ----
    c.addEventListener('buffAdd', (e) => {
      const b = e.detail.buff;
      if (!b || !this.player) return;
      this.player.animState.addBuff(b.type);
      (this.player._buffTypes ??= new Map()).set(b.index, b.type);
      if (b.type === BUFF_DRAGON_REPULSE && this.player.animName === 'standing') this.player.setAnimation(this.player.standAnim(), true);
    });
    c.addEventListener('buffRemove', (e) => {
      if (!this.player) return;
      const idx = e.detail.index;
      const type = this.player._buffTypes?.get(idx);
      if (type == null) return;
      this.player._buffTypes.delete(idx);
      this.player.animState.removeBuff(type);
      if (type === BUFF_DRAGON_REPULSE && this.player.animName === 'dragonRepulseMiddle') this.player.setAnimation('dragonRepulseEnd', true);
    });
    c.addEventListener('magicCooldown', (e) => {
      (this.magics ??= new Map());
      const m = this.magics.get(e.detail.infoIndex) ?? {};
      m.nextCast = performance.now() + Math.max(0, e.detail.delay);
      this.magics.set(e.detail.infoIndex, m);
      this.hooks.onMagicCooldown?.(e.detail);
    });
  }

  #onObjectMove(p) { // OnObjectMove + ShowUserLocation
    if (!this.player) return;
    if (p.objectID === this.player.objectID) {
      this.player.dir = p.direction;
      // 服务端确认: 校正预测 (距离>1 或不一致时瞬移)
      const dist = chebyshev(this.player.x, this.player.y, p.x, p.y);
      if (dist > 1 || p.mapChanged) { this.player.x = p.x; this.player.y = p.y; this.player.moving = false; }
      this._moveServerLockUntil = 0;   // GameScene.cs:3135 权威位置应用即解锁
      this.moveLock = false;
      this.hooks.onPosChange?.(this.player);
    } else {
      const o = this.objects.get(p.objectID);
      if (!o) return;
      const from = { x: o.x, y: o.y };
      const d = chebyshev(from.x, from.y, p.x, p.y);
      if (d === 0) { o.dir = p.direction; return; }
      // 权威格立即到终点 + Offset 从起点回拉 (MapObjectNode.cs:245-262)
      const dir = p.direction;
      o.x = p.x; o.y = p.y;
      o.moveDist = d;
      o.startX = from.x; o.startY = from.y;
      const saved = { x: o.x, y: o.y, sx: from.x, sy: from.y };
      o.startMove(d, dir);            // 置动画 + 时长 + 方向 (会再推进一格)
      o.x = saved.x; o.y = saved.y;   // 修正为包给的终点
      o.startX = saved.sx; o.startY = saved.sy;
      o.moveStartMs = performance.now();
    }
  }

  #onObjectAttack(p) { // OnObjectAttack (GameScene.cs:3013-3067)
    const atk = this.objects.get(p.objectID);
    if (atk) {
      atk.x = p.location.x; atk.y = p.location.y; atk.dir = p.direction;
      if (atk instanceof PlayerObject) {
        if (atk === this.player) this.player.playCombat(p.attackMagic);
        else atk.playCombat(p.attackMagic);
      } else if (atk instanceof MonsterObject) {
        atk.setAnimation('combat1', true);
      }
      // 攻击特效 (MagicEffectTable.GetAttack — 常用 None=MagicEx 1090,6)
      this.#spawnAttackEffect(atk, p.attackMagic, p.direction);
    }
    if (p.targetID) {
      const tgt = this.objects.get(p.targetID);
      if (tgt instanceof PlayerObject) tgt.playStruck();
      else if (tgt instanceof MonsterObject) tgt.setAnimation('struck', true);
    }
  }
  #ATTACK_FX = new Map([
    [0, ['MagicEx', 1090, 6]],
    [MAGIC.Slaying, ['Magic', 1350, 6]],
    [MAGIC.Thrusting, ['MagicEx3', 0, 6]],
    [MAGIC.HalfMoon, ['Magic', 230, 6]],
    [MAGIC.DestructiveSurge, ['MagicEx2', 1420, 6]],
    [MAGIC.FlamingSword, ['Magic', 1470, 6]],
    [MAGIC.DragonRise, ['Magic', 2185, 10]],
    [MAGIC.BladeStorm, ['MagicEx', 1780, 10]],
  ]);
  #spawnAttackEffect(atk, magic, dir) {
    const fx = this.#ATTACK_FX.get(magic) ?? this.#ATTACK_FX.get(0);
    const [lib, start, count] = fx;
    this.effects.push(new EffectNode(lib, start, count, magic === MAGIC.BladeStorm ? 60 : 100,
      { dir, x: atk.x, y: atk.y, alpha: 0.7 }));
  }

  #onObjectRangeAttack(p) { // GameScene.cs:3072-3148
    const atk = this.objects.get(p.objectID);
    if (atk) {
      atk.x = p.location.x; atk.y = p.location.y; atk.dir = p.direction;
      if (atk instanceof PlayerObject) atk.applyAnimAction(actionFromRangeAttack(p));  // [par-anim] RangeAttack→Combat1 (PlayerObject.cs:649-651)
      else atk.setAnimation('combat1', true);
      // Shuriken 弹道 (MagicEx 1270,3)
      if (p.attackMagic === MAGIC.Shuriken && atk !== this.player) {
        for (const tid of p.targets) {
          const tgt = this.objects.get(tid);
          if (tgt) {
            const pr = new ProjectileNode('MagicEx', 1270, 3, 100, {
              dir: p.direction, from: { x: atk.x, y: atk.y }, to: { x: tgt.x, y: tgt.y },
            });
            pr.camera = this.camera;
            this.effects.push(pr);
          }
        }
      }
    }
    for (const tid of p.targets) {
      const tgt = this.objects.get(tid);
      if (tgt instanceof PlayerObject) tgt.playStruck();
      else if (tgt instanceof MonsterObject) tgt.setAnimation('struck', true);
    }
  }

  #onObjectStruck(p) { // GameScene.cs:4187-4271
    const o = this.objects.get(p.objectID);
    if (!o) return;
    o.x = p.location.x; o.y = p.location.y; o.dir = p.direction;
    if (o instanceof PlayerObject) o.playStruck();
    else o.setAnimation('struck', true);
    // 元素命中特效 MagicEx 790+element*20 (GameScene.cs:4239-4271)
    const start = 790 + p.element * 20;
    this.effects.push(new EffectNode('MagicEx', start, 6, 100, { dir: p.direction, x: o.x, y: o.y, alpha: 0.7 }));
  }

  #onObjectDied(p) { // GameScene.cs:7476-7504
    const o = this.objects.get(p.objectID);
    if (!o) return;
    o.x = p.location.x; o.y = p.location.y; o.dir = p.direction;
    if (o instanceof PlayerObject) o.playDie();
    else { o.dead = true; o.setAnimation('die', true); }
    // 目标死亡保留选中 (CombatController.cs:262-264)
  }

  #onObjectMagic(p) { // GameScene.cs:3151-3204 (基础: 抬手动画 + 落点特效)
    const caster = this.objects.get(p.objectID);
    if (caster) {
      caster.x = p.location.x; caster.y = p.location.y; caster.dir = p.direction;
      if (caster instanceof PlayerObject)
        caster.applyAnimAction(actionFromMagic(p));   // [par-anim] Spell 全分派 (PlayerObject.cs:652-663)
      else
        caster.setAnimation('combat3', true);
    }
    if (!p.cast) return;   // 不播释放
    // 目标受击
    for (const tid of p.targets) {
      const t = this.objects.get(tid);
      if (t instanceof PlayerObject) t.playStruck();
      else if (t instanceof MonsterObject) t.setAnimation('struck', true);
    }
    // 落点特效: 常见技能映射 (完整 MagicEffectTable 见 docs; 此处覆盖主要弹道/落点)
    const fx = MAGIC_FX[p.type];
    if (fx && caster) {
      const dest = p.locations[0] ?? (p.targets[0] ? this.objects.get(p.targets[0]) : null) ?? caster;
      const dx = dest.x ?? dest.location?.x, dy = dest.y ?? dest.location?.y;
      if (fx.projectile) {
        const pr = new ProjectileNode(fx.projectile[0], fx.projectile[1], fx.projectile[2], 100, {
          dir: p.direction, from: { x: caster.x, y: caster.y }, to: { x: dx, y: dy },
        });
        pr.camera = this.camera;
        this.effects.push(pr);
        if (fx.impact) {
          const im = new EffectNode(fx.impact[0], fx.impact[1], fx.impact[2], 100, { x: dx, y: dy, alpha: 0.9 });
          im.delayMs = pr.dur;
          this.effects.push(im);
        }
      } else if (fx.impact) {
        this.effects.push(new EffectNode(fx.impact[0], fx.impact[1], fx.impact[2], 100, { x: dx, y: dy, alpha: 0.9 }));
      }
      if (fx.source) {
        this.effects.push(new EffectNode(fx.source[0], fx.source[1], fx.source[2], 100,
          { dir: p.direction, x: caster.x, y: caster.y, alpha: 0.9 }));
      }
    }
  }

  // ---- 光照 ----
  #applyLight() {
    const NIGHT = 0.25, TWILIGHT = 100 / 255;
    if (this.dayTime === undefined) this.dayTime = this.info?.dayTime ?? 1;
    const setting = this.mapMeta?.light ?? 'Default';
    let ambient;
    if (setting === 'Light') ambient = 1;
    else if (setting === 'Night') ambient = NIGHT;
    else if (setting === 'Twilight') ambient = TWILIGHT;
    else ambient = Math.min(1, Math.max(NIGHT, this.dayTime));
    this.lightAlpha = 1 - ambient;
  }

  // ---- 目标选择 (CombatController) ----
  #setTarget(o) {
    this.target = o ?? null;
    this.hooks.onTarget?.(o);
  }
  #pickObject(px, py) {
    // 逆渲染序 (上层优先): 玩家/怪 > 物品
    const list = [...this.objects.values()].filter(o =>
      Math.abs(o.x - this.player.x) <= 14 && Math.abs(o.y - this.player.y) <= 12)
      .sort((a, b) => b.renderY() - a.renderY());
    for (const o of list) {
      if (o === this.player) continue;
      if (o.hitTest(px, py)) return o;
    }
    return null;
  }

  // ---- 输入 (MouseWalker.cs + CombatController.cs 精确移植) ----
  #bindInput() {
    this.keys = new Set();
    this.mouseWalker = new MouseWalker({
      world: this,
      canvas: this.canvas,
      // GameScene.cs:970-987 接线
      mouseOverUi: () => this.#mouseOverUiAt(this._lastMouse),
      blockLeftWalk: () => {   // GameScene.cs:971-975: 鼠标下有可点物体 → 点击逻辑接管
        const m = this.mouseObject;
        return !!m && (m instanceof ItemObject
          || (!m.dead && !(m instanceof MonsterObject && m.petOwner)));
      },
      blockLeftMouse: () => false,
      blockRightMouse: () => false,
      getRunSteps: () => this.getRunSteps(),
      canPlayerMove: () => this.canPlayerMove(),
      canPlayerTurn: () => this.canPlayerTurn(),
      sendMove: (dir, dist, run) => this.stepMove(dir, dist, run),
      sendTurn: (dir) => this.mouseSendTurn(dir),
      awaitingServer: () => performance.now() < this._moveServerLockUntil,
      shift: () => this.shiftHeld ?? false,
      alt: () => this.altHeld ?? false,
    });
    this.mouseObject = null;      // CombatController.MouseObject (悬停)
    this._canRun = false;         // GameScene.cs:815 — 站立后第一段先走
    this._moveServerLockUntil = 0;
    this.autoRun = false;
    this.lastKeyStep = 0;         // 键盘连续走节流 (GameScene.cs:9902)

    addEventListener('keydown', (ev) => {
      // Godot 语义: 输入控件聚焦时键盘事件归控件 (ChatTextBox 打字), 不驱动移动
      const t = ev.target;
      if (t && (t.tagName === 'INPUT' || t.tagName === 'TEXTAREA' || t.isContentEditable)) return;
      this.keys.add(ev.code);
      this.shiftHeld = ev.shiftKey;
      this.altHeld = ev.altKey;
    });
    addEventListener('keyup', (ev) => {
      this.keys.delete(ev.code);
      this.shiftHeld = ev.shiftKey;
      this.altHeld = ev.altKey;
    });
    addEventListener('mousemove', (ev) => {
      this.shiftHeld = ev.shiftKey; this.altHeld = ev.altKey;
      this._lastMouse = { clientX: ev.clientX, clientY: ev.clientY };
      // 悬停物体 (CombatController._Process:198)
      this.mouseObject = this.#pickAtClient(ev.clientX, ev.clientY);
    });

    this.canvas.addEventListener('mousedown', (ev) => {
      if (!this.player) return;
      // 鼠标在 UI 上 → 点击是界面操作 (CombatController.cs:327)
      if (this.#mouseOverUi(ev)) return;
      if (ev.button === 0) this.#combatClick(ev);
      else if (ev.button === 2) this.#rightClick(ev);
    });
    addEventListener('mouseup', () => { this.mouseHeld = false; });
    this.canvas.addEventListener('contextmenu', (ev) => ev.preventDefault());

    // 悬停光标样式: 可点物体 → pointer (CheckCursor)
    this.canvas.addEventListener('mousemove', () => {
      this.canvas.style.cursor = this.mouseObject ? 'pointer' : 'default';
    });
  }

  #mouseOverUi(ev) {
    return this.#mouseOverUiAt(ev ? { clientX: ev.clientX, clientY: ev.clientY } : this._lastMouse);
  }

  #mouseOverUiAt(pos) {
    // GameScene.IsMouseOverUi: 悬停元素是 DX 控件 → true
    if (!pos) return false;
    const el = document.elementFromPoint(pos.clientX, pos.clientY);
    return !!el?.closest?.('.dxctl');
  }

  // CombatController._Input (左键) + GameScene._UnhandledInput (脚下拾取/NPC/物品)
  #combatClick(ev) {
    const hit = this.#pickAtClient(ev.clientX, ev.clientY);
    const rect = this.canvas.getBoundingClientRect();
    const w = this.camera.screenToWorld(ev.clientX, ev.clientY);
    const cell = [Math.floor(w.x / data.CELL_W), Math.floor(w.y / data.CELL_H)];
    const shift = ev.shiftKey;
    this.mouseHeld = true;

    // ShouldDeferForMapPickup: 非 Shift 点击玩家当前格 → 脚下拾取优先 (CombatController.cs:86-88)
    if (!shift && cell[0] === this.player.x && cell[1] === this.player.y) {
      this.conn.sendPickUp();
      return;
    }

    // Shift 且未选中 → 朝鼠标方向原地攻击 (CombatController.cs:240-244)
    if (shift && !this.target) {
      const dir = directionFromPoint(this.player.x, this.player.y, cell[0], cell[1]);
      this.#tryAttack(dir);
      return;
    }

    // CanAttackObject: 活着的怪物/玩家
    const attackable = hit && !hit.dead &&
      (hit instanceof MonsterObject || hit instanceof PlayerObject) && hit !== this.player;
    if (!attackable) {
      if (hit instanceof ItemObject) {
        // 掉落物: 相邻直接拾取, 否则走过去 (原版 PickUp 分支)
        if (chebyshev(this.player.x, this.player.y, hit.x, hit.y) <= 1) this.conn.sendPickUp();
        else this.pickupTarget = hit;
        return;
      }
      if (hit instanceof NPCObject) {
        // NPC: 按下记录, 相邻 NPCCall (GameScene.cs:10189-10199 + TrySendNpcCall 1s 节流)
        this._pendingNpcId = hit.objectID;
        if (chebyshev(this.player.x, this.player.y, hit.x, hit.y) <= 2) this.#tryNpcCall(hit.objectID);
        return;
      }
      // 空地 → 取消选中 (CanAttack 未通过)
      this.#setTarget(null);
      this._clearMagicLock?.();
      return;
    }
    this.pickupTarget = null;
    this.#setTarget(hit);   // 选中; 相邻攻击/追击由 _combatTick 驱动 (原版 _Process)
  }

  #rightClick(ev) {
    // GameScene.cs:10166-10187: Ctrl+右键 = 观察玩家 (2.5s 节流)
    const hit = this.#pickAtClient(ev.clientX, ev.clientY);
    if (ev.ctrlKey && hit instanceof PlayerObject && hit !== this.player) {
      const now = performance.now();
      if (now >= (this._nextInspectMs ?? 0)) {
        this._nextInspectMs = now + 2500;
        this.conn.send(C.Inspect(hit.characterIndex ?? 0, false));   // 观察玩家
      }
      return;
    }
    // RightClickDeTarget (CombatController.cs:388-398): 只清怪物目标
    if (this.target instanceof MonsterObject) {
      this.#setTarget(null);
      this._clearMagicLock?.();
    }
  }

  // TrySendNpcCall (GameScene.cs:10236-10244): 1s 节流
  #tryNpcCall(objectId) {
    const now = performance.now();
    if (now < (this._nextNpcCallMs ?? 0)) return;
    this.conn.sendNPCCall(objectId);
    this._nextNpcCallMs = now + 1000;
  }

  #pickAtClient(cx, cy) {
    const rect = this.canvas.getBoundingClientRect();
    const px = (cx - rect.left) * (this.canvas.width / rect.width);
    const py = (cy - rect.top) * (this.canvas.height / rect.height);
    return this.#pickObject(px, py);
  }

  #targetNearest() {
    let best = null, bd = 1e9;
    for (const o of this.objects.values()) {
      if (o === this.player || o.dead) continue;
      if (!(o instanceof MonsterObject) || o.petOwner) continue;
      const d = chebyshev(this.player.x, this.player.y, o.x, o.y);
      if (d < bd) { bd = d; best = o; }
    }
    this.#setTarget(best);
  }

  #dirIndex(dx, dy) {
    for (let i = 0; i < 8; i++) if (DIRS[i][0] === dx && DIRS[i][1] === dy) return i;
    return 0;
  }
  #stepTowards(tx, ty) {
    const p = this.player;
    let dx = Math.sign(tx - p.x), dy = Math.sign(ty - p.y);
    if (dx === 0 && dy === 0) return;
    this.stepMove(this.#dirIndex(dx, dy), 1, false);
  }

  // SendMouseMove (GameScene.cs:7847-7916): 发包即预测 — 权威格跳终点 + 起点反向偏移 + 插值。
  // running&&distance>=2 → 跑步动画 (相同 600ms 移 2 格)。
  stepMove(dir, distance = 1, running = false) {
    if (!this.player || this.player.dead) return false;
    if (performance.now() < this._moveServerLockUntil) return false;
    const p = this.player;
    p.startX = p.x; p.startY = p.y;
    // 跳到预测终点, 反向 Offset (原版 SetAction(Moving))
    const nx = p.x + DIRS[dir][0] * distance, ny = p.y + DIRS[dir][1] * distance;
    p.x = nx; p.y = ny;
    p.dir = dir;
    p.startMove(distance, dir, running && distance >= 2);
    p.offX = (p.startX - nx) * data.CELL_W;
    p.offY = (p.startY - ny) * data.CELL_H;
    p.moveStartMs = performance.now();
    this.conn.sendMove(dir, distance);
    // AttemptAction 末尾 ServerTime = Now+5s (GameScene.cs:7899)
    this._moveServerLockUntil = performance.now() + 5000;
    this._canRun = true;   // 发包后立即允许下一段 Run (原版语义)
    this.hooks.onPosChange?.(p);
    return true;
  }

  // GetRunSteps (GameScene.cs:7918-7935): 站立后第一段走; 未超重才跑; 骑马 3 格
  getRunSteps() {
    const gd = this.gameData;
    const bagOk = !gd || gd.bagWeight <= gd.maxBagWeight();
    const wearOk = !gd || gd.wearWeight <= gd.maxWearWeight();
    const steps = (this._canRun && bagOk && wearOk) ? 2 : 1;
    return (steps > 1 && this.player?.horse > 0) ? steps + 1 : steps;
  }

  // MouseWalker 发送回调 (MouseWalker._Process 178)
  mouseSendMove(dir, distance, running) { return this.stepMove(dir, distance, running); }
  mouseSendTurn(dir) { this.conn.sendTurn(dir); this.player.dir = dir; }
  canPlayerMove() {
    return !this.player?.dead && !this.player?.mountLock;
  }
  canPlayerTurn() { return !this.player?.dead; }

  // ---- 攻击 (CombatController.cs:216-231) ----
  #attackInterval() {
    // max(800, 1500 - AS*47) (GameScene.cs:1501-1508)
    const as = this.attackSpeed ?? 0;
    return Math.max(800, 1500 - as * 47);
  }
  #tryAttack(dir) {
    const now = performance.now();
    if (!this.conn || this.player.dead) return false;
    if (now < this.nextAttackMs) return false;
    this.nextAttackMs = now + this.#attackInterval();
    this.player.dir = dir;
    this.player.playCombat(0);            // 本地预测 (GameScene.cs:1003)
    this.conn.sendAttack(dir, 0);
    return true;
  }

  // ---- 技能释放 (GameScene.cs OnSpellInput → C.Magic) ----
  #magicTypeFor(infoIndex) { // MagicInfo.Index → MagicType 枚举值
    const rec = data.D().magics?.find(m => m.id === infoIndex);
    return rec ? (MAGIC[rec.key] ?? 0) : 0;
  }
  // UseMagicSlot (GameScene.cs:9650): F1-F12/Shift+F1-F12 → SpellKey → 当前 Set 绑定的技能
  useMagicSlot(slot) {
    if (slot < 0 || slot > 23) return false;
    if (!this.conn || !this.player || this.player.dead) return false;
    const key = slot + 1;   // Spell01 = 1
    const set = this.spellSet ?? 1;
    let magic = null;
    for (const m of (this.info?.magics ?? [])) {
      if (!m) continue;
      const k = set === 1 ? m.set1Key : set === 2 ? m.set2Key : set === 3 ? m.set3Key : m.set4Key;
      if (k === key) { magic = m; break; }
    }
    if (!magic) {
      this.addChat(`没有绑定按键 ${key} 的技能 (Set${set})`, 'hint');
      return false;
    }
    const type = this.#magicTypeFor(magic.infoIndex);
    if (!type) return false;
    return this.castMagic(type);
  }
  setSpellSet(n) {   // SpellSet01-04 (GameScene.cs:1883-1888)
    this.spellSet = n;
    this.addChat(`技能栏切换到 Set${n}`, 'hint');
  }
  spellSlots() { // 展示用: 当前 Set 绑定的 24 键位 → 技能
    const set = this.spellSet ?? 1;
    const out = new Array(24).fill(null);
    for (const m of (this.info?.magics ?? [])) {
      if (!m) continue;
      const k = set === 1 ? m.set1Key : set === 2 ? m.set2Key : set === 3 ? m.set3Key : m.set4Key;
      if (k >= 1 && k <= 24 && !out[k - 1]) {
        const rec = data.D().magics?.find(x => x.id === m.infoIndex);
        out[k - 1] = rec ? { index: m.infoIndex, name: rec.zh, type: MAGIC[rec.key] ?? 0, level: m.level } : null;
      }
    }
    return out;
  }
  castMagic(type, target = this.target) {
    if (!this.conn || !this.player || this.player.dead) return false;
    const tx = target?.x ?? this.player.x, ty = target?.y ?? this.player.y;
    const dir = directionFromPoint(this.player.x, this.player.y, tx, ty);
    this.player.applyAnimAction(new AnimAction(MIR_ACTION.Spell, dir,   // [par-anim] 本地预测: Spell 抬手全分派
      { x: this.player.x, y: this.player.y }, [type]));
    this.conn.sendMagic(dir, type, target?.objectID ?? 0, tx, ty);
    return true;
  }
  #combatTick(now) {
    // CombatController._Process (193-302) 逐分支移植
    if (!this.player || this.player.dead) return;

    // 拾取目标逼近 (原版 PickUp 分支的走近语义)
    if (this.pickupTarget) {
      const t = this.pickupTarget;
      if (!this.objects.has(t.objectID)) { this.pickupTarget = null; return; }
      const d = chebyshev(this.player.x, this.player.y, t.x, t.y);
      if (d <= 1) { this.conn.sendPickUp(); this.pickupTarget = null; }
      else if (now - this.lastChaseMs > 600) {
        this.lastChaseMs = now;
        this.#stepTowards(t.x, t.y);
      }
      return;
    }

    const t = this.target;
    if (!t) return;
    if (!this.objects.has(t.objectID)) { this.#setTarget(null); return; }
    if (t.dead) return;   // 目标死亡保留选中 (D15)
    const d = chebyshev(this.player.x, this.player.y, t.x, t.y);
    const isMonster = t instanceof MonsterObject;

    // 玩家/宠物目标: 未按 Shift 只选中不追击 (CombatController.cs:270-272)
    if (!isMonster && !this.shiftHeld) return;
    if (isMonster && t.petOwner && !this.shiftHeld) return;

    if (d <= 1) return;   // 相邻交给顶部自动攻击

    // 顶部自动攻击前置: 相邻(=1)已在下方处理 — 这里 d>1
    void d;

    // 追击: 600ms/段 (原版 NextActionTime; CombatController.cs:296-301)
    if (now - this.lastChaseMs > 600) {
      this.lastChaseMs = now;
      let dir = directionFromPoint(this.player.x, this.player.y, t.x, t.y);
      if (!this.#stepClear(dir)) {
        const best = this.#bestApproach(dir, t);
        if (best === dir) { this.conn.sendTurn(dir); return; }
        dir = best;
      }
      this.stepMove(dir, 1, false);
      this.nextAttackMs = now + 600;
    }
  }

  // 自动攻击: 目标相邻 && 冷却到 (CombatController.cs:217-231 顶部分支)
  #autoAttackTick(now) {
    const t = this.target;
    if (!t || t.dead || !this.objects.has(t.objectID)) return;
    if (!(t instanceof MonsterObject) && !this.shiftHeld) return;
    if (t instanceof MonsterObject && t.petOwner && !this.shiftHeld) return;
    const d = chebyshev(this.player.x, this.player.y, t.x, t.y);
    if (d !== 1 || now < this.nextAttackMs) return;
    const dir = directionFromPoint(this.player.x, this.player.y, t.x, t.y);
    this.#tryAttack(dir);
  }

  #stepClear(dir) {
    const nx = this.player.x + DIRS[dir][0], ny = this.player.y + DIRS[dir][1];
    if (this.walk && !data.walkable(this.walk, nx, ny, this.mapMeta.w)) return false;
    for (const o of this.objects.values()) {
      if (o.x === nx && o.y === ny && !o.dead && o !== this.player) return false;
    }
    return true;
  }

  // BestApproachDirection (CombatController.cs:419-433)
  #bestApproach(direct, t) {
    if (this.#stepClear(direct)) return direct;
    const angle0 = Math.atan2(t.x - this.player.x, -(t.y - this.player.y)) * 180 / Math.PI;
    let angle = angle0 < 0 ? angle0 + 360 : angle0;
    let best = Math.floor(angle / 45);
    if (best === direct) best = ((direct + 1) % 8 + 8) % 8;
    const next = ((direct - best + direct) % 8 + 8) % 8;
    if (this.#stepClear(best)) return best;
    if (this.#stepClear(next)) return next;
    return direct;
  }

  sendChat(text) { this.conn.sendChat(text); }

  // ---- 渲染循环 ----
  _startLoop() {
    this.#bindInput();
    requestAnimationFrame(() => this._frame());
  }
  _frame = () => {
    requestAnimationFrame(this._frame);
    const now = performance.now();
    if (!this.player) return;

    // MouseWalker (按住左键走 / 按住右键跑) — 每帧 tick
    if (this.mouseWalker) {
      this.mouseWalker.tick(now);
    }

    // 键盘方向键连续走 (GameScene.cs:9902-9915: 仅 Arrow 键; WASD 是窗口快捷键)
    if (this.walk) {
      const k = this.keys;
      let dir = null;
      if (k.has('ArrowUp')) dir = 0;
      else if (k.has('ArrowRight')) dir = 2;
      else if (k.has('ArrowDown')) dir = 4;
      else if (k.has('ArrowLeft')) dir = 6;
      if (dir !== null && now - this.lastKeyStep > 600) {
        if (this.stepMove(dir, 1, false)) this.lastKeyStep = now;
      }
    }

    // 战斗: 顶部自动攻击 + 追击 (CombatController._Process)
    this.#autoAttackTick(now);
    this.#combatTick(now);

    // 对象 tick
    for (const o of this.objects.values()) o.tick(now);
    // 相机跟随 (插值)
    const targetX = this.player.x * data.CELL_W + (this.player.offX ?? 0);
    const targetY = this.player.y * data.CELL_H + (this.player.offY ?? 0);
    this.camera.x += (targetX - this.camera.x) * 0.25;
    this.camera.y += (targetY - this.camera.y) * 0.25;
    this.camera.drawMap(this.stem, this.mapMeta.tiles);
    this.#drawObjects(now);
    this.#drawEffects(now);
    if (this.lightAlpha > 0.001) {
      const ctx = this.camera.ctx;
      ctx.fillStyle = `rgba(0,0,0,${this.lightAlpha})`;
      ctx.fillRect(0, 0, this.canvas.width, this.canvas.height);
    }
  };
  #anchor(o) {
    const wx = o.x * data.CELL_W + data.CELL_W / 2 + (o.offX ?? 0);
    const wy = (o.y + 1) * data.CELL_H + (o.offY ?? 0);
    return this.camera.worldToScreen(wx, wy);
  }

  #drawObjects(now) {
    const ctx = this.camera.ctx;
    const list = [...this.objects.values()].filter(o =>
      Math.abs(o.x - this.player.x) <= 15 && Math.abs(o.y - this.player.y) <= 13);
    list.sort((a, b) => a.renderY() - b.renderY() || (a === this.player ? -1 : b === this.player ? 1 : 0));
    const jobs = [];
    for (const o of list) {
      const a = this.#anchor(o);
      jobs.push(Promise.resolve(o.draw(ctx, a.x, a.y, now)).then(() => {
        o.drawName(ctx, a.x, a.y, now);
        o.drawHealthBar(ctx, a.x, a.y, now);
        // 目标高亮
        if (this.target === o) {
          ctx.strokeStyle = 'rgba(255,255,255,.7)';
          ctx.lineWidth = 1;
          ctx.strokeRect(a.x - 22, a.y - 60, 44, 62);
        }
      }));
    }
    // 飘字 (顶层)
    for (let i = this.popups.length - 1; i >= 0; i--) {
      const { obj, popup } = this.popups[i];
      const a = this.#anchor(obj);
      popup.draw(ctx, a.x, a.y, now);
      if (popup.done) this.popups.splice(i, 1);
    }
    return jobs;
  }

  #drawEffects(now) {
    const ctx = this.camera.ctx;
    for (let i = this.effects.length - 1; i >= 0; i--) {
      const e = this.effects[i];
      if (e.delayMs && now - e.t0 < e.delayMs) continue;
      if (e instanceof ProjectileNode) {
        e.draw(ctx, now);
      } else {
        const wx = e.x * data.CELL_W + data.CELL_W / 2, wy = (e.y + 1) * data.CELL_H;
        const a = this.camera.worldToScreen(wx, wy);
        e.draw(ctx, a.x, a.y, now);
      }
      if (e.done) this.effects.splice(i, 1);
    }
  }
}

// 常用技能特效表 (MagicEffectTable.cs 代表条目; start=[lib,idx,count])
const MAGIC_FX = {
  [MAGIC.FireBall]: { source: ['Magic', 1820, 8], projectile: ['Magic', 420, 5], impact: ['Magic', 580, 10] },
  [MAGIC.IceBolt]: { source: ['Magic', 2620, 6], projectile: ['Magic', 2700, 3], impact: ['Magic', 2860, 10] },
  [MAGIC.LightningBall]: { source: ['Magic', 2990, 6], projectile: ['Magic', 3070, 6], impact: ['Magic', 3230, 10] },
  [MAGIC.GustBlast]: { source: ['MagicEx', 350, 7], projectile: ['MagicEx', 430, 5], impact: ['MagicEx', 590, 10] },
  [MAGIC.FireBounce]: { source: ['Magic', 1560, 9], projectile: ['Magic', 1640, 6], impact: ['Magic', 1800, 10] },
  [MAGIC.IceBlades]: { source: ['Magic', 2880, 6], projectile: ['Magic', 2960, 6], impact: ['Magic', 2970, 10] },
  [MAGIC.EvilSlayer]: { source: ['Magic', 3250, 6], projectile: ['Magic', 3330, 6], impact: ['Magic', 3340, 10] },
  [MAGIC.GreaterEvilSlayer]: { source: ['Magic', 3360, 6], projectile: ['Magic', 3440, 6], impact: ['Magic', 3450, 10] },
  [MAGIC.ExplosiveTalisman]: { source: ['Magic', 2080, 6], projectile: ['Magic', 980, 3], impact: ['Magic', 1140, 10] },
  [MAGIC.ImprovedExplosiveTalisman]: { source: ['MagicEx2', 980, 6], impact: ['MagicEx2', 1160, 10] },
  [MAGIC.Heal]: { source: ['Magic', 660, 10], impact: ['Magic', 610, 10] },
  [MAGIC.MassHeal]: { source: ['Magic', 660, 10], impact: ['Magic', 670, 7] },
  [MAGIC.FireStorm]: { source: ['Magic', 940, 10], impact: ['Magic', 950, 7] },
  [MAGIC.IceStorm]: { source: ['Magic', 770, 10], impact: ['Magic', 780, 7] },
  [MAGIC.ThunderBolt]: { source: ['Magic', 1430, 12], impact: ['Magic', 1450, 3] },
  [MAGIC.MagicShield]: { source: ['Magic', 830, 19] },
  [MAGIC.PoisonDust]: { source: ['Magic', 60, 10], impact: ['Magic', 70, 10] },
};
