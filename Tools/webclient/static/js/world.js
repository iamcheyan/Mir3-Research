// world.js — 世界状态: 玩家/实体/地图切换/移动/拾取
import { CELL_W, CELL_H, D, walkable, walkBits, pickLibs } from './data.js';
import { loadSprite } from './res.js';

export class World {
  constructor(game) {
    this.game = game;
    this.map = '0';
    this.walk = null;
    this.mapW = 0; this.mapH = 0;
    this.player = {
      x: 0, y: 0, dir: 4, moving: false, anim: 'standing', animT: 0, animFrame: 0,
      cls: 'Warrior', gender: 'M', level: 255,
      armourShape: 0, weaponShape: -1, helmetShape: 0, hairType: 1,
      invis: false, speed: 1,
      hp: 255, hpMax: 255, mp: 255, mpMax: 255,
    };
    this.libs = null;
    this.npcs = [];         // 当前地图 NPC
    this.mons = [];         // 当前地图怪物 (respawn 采样)
    this.items = [];        // GM 刷的物品
    this.summons = [];      // GM 召唤物
    this.pets = [];         // 伙伴 (骷髅/神兽)
    this.effects = [];      // 施法特效实例
    this.transitioning = false;
    this.onMapChange = null;
  }

  currentLook() {
    const p = this.player;
    const libs = pickLibs({ cls: p.cls, gender: p.gender, armourShape: p.armourShape,
                            weaponShape: p.weaponShape, helmetShape: p.helmetShape });
    return { cls: p.cls, gender: p.gender, armourShape: p.armourShape,
             weaponShape: p.weaponShape, helmetShape: p.helmetShape, hairType: p.hairType, libs,
             ver: this._lookVer || 0 };
  }

  touchLook() { this._lookVer = (this._lookVer || 0) + 1; }

  async enterMap(stem, x = null, y = null) {
    const m = D().manifest.maps[stem];
    if (!m) throw new Error(`未知地图: ${stem}`);
    this.map = stem;
    this.mapW = m.w; this.mapH = m.h;
    this.walk = await walkBits(stem);
    if (x == null || y == null) {
      const sp = D().manifest.spawn;
      x = sp.map === stem ? sp.x : m.w >> 1;
      y = sp.map === stem ? sp.y : m.h >> 1;
    }
    if (!walkable(this.walk, x, y, m.w)) {
      // 找最近可行走格: 只扫半径 r 的环 (非全方块), 半径上限 120
      outer: for (let r = 1; r <= 120; r++) {
        for (let a = 0; a < r * 8; a++) {
          // 8r 个采样点近似环
          const ang = a / (r * 8) * Math.PI * 2;
          const nx = x + Math.round(Math.cos(ang) * r), ny = y + Math.round(Math.sin(ang) * r);
          if (nx >= 0 && ny >= 0 && nx < m.w && ny < m.h && walkable(this.walk, nx, ny, m.w)) {
            x = nx; y = ny; break outer;
          }
        }
      }
    }
    this.player.x = x; this.player.y = y;
    this._spawnEntities();
    if (this.onMapChange) this.onMapChange(stem, m);
  }

  _spawnEntities() {
    const d = D();
    this.npcs = d.npcs.filter((n) => n.map === this.map);
    // 怪物: RespawnInfo 按区域摆放; 每区域一个代表怪 (避免 2475 只全画)
    const reps = d.respawns[this.map] || [];
    this.mons = reps.map((r) => {
      const mon = d.monstersById[r.mid];
      if (!mon || mon.shape < 0) return null;
      return { mon, x: r.x, y: r.y, animT: Math.random() * 2000, frame: 0 };
    }).filter(Boolean);
    this.items = [];
    this.summons = [];
    this.effects = [];
  }

  canWalk(x, y) {
    if (x < 0 || y < 0 || x >= this.mapW || y >= this.mapH) return false;
    return walkable(this.walk, x, y, this.mapW);
  }

  // 踏上出口检测
  exitAt(x, y) {
    const m = D().manifest.maps[this.map];
    if (!m) return null;
    for (const e of m.exits) {
      if (Math.abs(x - e.x) <= e.r && Math.abs(y - e.y) <= e.r) return e;
    }
    return null;
  }

  // 帧推进: 移动/动画
  update(dt) {
    const p = this.player;
    p.animT += dt * p.speed;
    const animLen = { standing: 500, walking: 600, running: 600, combat2: 500, struck: 300, die: 1000 }[p.anim] || 500;
    if (p.animT >= animLen / 6) {
      p.animT -= animLen / 6;
      p.animFrame = (p.animFrame + 1) % 6;
      if (p.anim === 'combat2' && p.animFrame === 0) p.anim = 'standing';
    }
    for (const mo of this.mons) {
      mo.animT += dt;
      if (mo.animT >= 125) { mo.animT -= 125; mo.frame = (mo.frame + 1) % 4; }
    }
  }

  // GM: 召唤怪物
  summon(monId, x, y) {
    const mon = D().monstersById[monId];
    if (!mon || mon.shape < 0) return;
    this.summons.push({ mon, x, y, animT: Math.random() * 1000, frame: 0 });
  }

  // GM: 刷物品
  dropItem(itemId, x, y) {
    const it = D().itemsById[itemId];
    if (!it) return;
    this.items.push({ it, x, y, t: 0 });
  }

  // 拾取: 玩家所在格物品
  pickupAt() {
    const p = this.player;
    const i = this.items.findIndex((d) => d.x === p.x && d.y === p.y);
    if (i < 0) return null;
    return this.items.splice(i, 1)[0].it;
  }

  // 伙伴 (M8): 骷髅/神兽 — Mon 库帧跟随
  async addPet(kind) {
    const d = D();
    const zhName = kind === 'shinsoo' ? '神兽' : '骷髅';
    // Skeleton: MonsterInfo Image=Skeleton; Shinsu: Image=Shinsu
    const mon = d.monsters.find((m) => m.img === (kind === 'shinsoo' ? 'Shinsu' : 'Skeleton'));
    if (!mon) return;
    this.pets.push({ mon, x: this.player.x, y: this.player.y + 1,
                     animT: 0, frame: 0, name: zhName });
  }
}
