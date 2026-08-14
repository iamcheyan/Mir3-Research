// accept.mjs — 验收截图序列 (puppeteer-core + 本地 chrome)
// 产物: /tmp/wc_*.png + /tmp/wc_report.json
// 运行: node Tools/webclient/accept.mjs   (需 serve.py :8822 已启动)
import { createRequire } from 'module';
import fs from 'fs';
const require = createRequire('/home/tetsuya/.bun/install/global/node_modules/');
const puppeteer = require('puppeteer-core');

const BASE = 'http://127.0.0.1:8822';
const OUT = '/tmp';
const CHROME = '/home/tetsuya/.omp/puppeteer/chrome/linux-150.0.7871.24/chrome-linux64/chrome';

const log = (...a) => console.log('[accept]', ...a);
const sleep = (ms) => new Promise((r) => setTimeout(r, ms));

const browser = await puppeteer.launch({
  executablePath: CHROME,
  headless: 'new',
  args: ['--no-sandbox', '--disable-dev-shm-usage', '--enable-unsafe-swiftshader'],
});
const page = await browser.newPage();
await page.setViewport({ width: 1440, height: 900, deviceScaleFactor: 1 });
const errs = [];
page.on('pageerror', (e) => errs.push(String(e)));
page.on('console', (m) => { if (m.type() === 'error') errs.push(m.text()); });

await page.goto(BASE, { waitUntil: 'domcontentloaded', timeout: 30000 });

// 首屏加载计时
const t0 = Date.now();
await page.waitForFunction(() => window.game && window.WC && !document.getElementById('loading-overlay').classList.contains('done'), { timeout: 30000 });
await page.waitForFunction(() => (window.game.renderer.lastEnts?.length || 0) > 0, { timeout: 20000 });
await page.evaluate(() => WC.waitForTiles());
await sleep(700);
const firstLoadMs = Date.now() - t0;
log('首屏加载', firstLoadMs, 'ms');

const report = { firstLoadMs, switchMs: [], errors: errs };

// 等画布真正更新: 至少 advance 个主循环帧被绘制 (低 fps 下 sleep 不可靠)
async function shot(name, advance = 4) {
  if (advance > 0) {
    await page.evaluate((n) => new Promise((res) => {
      const d0 = window.game.renderer.lastFrameStats.draw;
      const t0 = performance.now();
      const check = () => {
        if (window.game.renderer.lastFrameStats.draw - d0 >= n
            || performance.now() - t0 > 4000) res();
        else requestAnimationFrame(check);
      };
      check();
    }), advance).catch(() => {});
  }
  await page.screenshot({ path: `${OUT}/wc_${name}.png` });
  log('shot', name);
}

// ---- 1. 比奇 → 3 张邻接图切换 ----
const exits = await page.evaluate(async () => {
  const d = await (await fetch('/res/data/maps_manifest.json')).json();
  return d.maps[game.world.map].exits.slice(0, 4);
});
await shot('map_0_bichon');

let prev = '0';
for (let i = 0; i < 3 && i < exits.length; i++) {
  const e = exits[i];
  const sw = await page.evaluate(async (to, tx, ty) => {
    const t0 = performance.now();
    await game.teleport(to, tx, ty);
    await WC.waitForTiles();
    return Math.round(performance.now() - t0);
  }, e.to, e.tx, e.ty);
  report.switchMs.push({ from: prev, to: e.to, ms: sw });
  prev = e.to;
  await sleep(500);
  await shot(`map_${i + 1}_${e.to.replace(/[^\w]/g, '_')}`);
}
log('切图耗时', report.switchMs);

await page.evaluate(() => WC.teleport('0'));

// ---- 2. 四职业外观 (代表盔甲: 战=幽灵铠甲1 法=火焰法袍4 道=铁板甲6 刺=M-HumA) ----
const classLooks = [
  { cls: 'Warrior', armour: 1 },
  { cls: 'Wizard', armour: 4 },
  { cls: 'Taoist', armour: 6 },
  { cls: 'Assassin', armour: 1 },
];
for (let i = 0; i < classLooks.length; i++) {
  await page.evaluate((c) => {
    WC.setClass(c.cls);
    WC.wear('Armour', c.armour);
    game.world.player.dir = 4;
  }, classLooks[i]);
  // 等该外观的玩家精灵真正就绪 (低 fps 下 sleep 不可靠)
  await page.evaluate(() => new Promise((res) => {
    const t0 = performance.now();
    const p = window.game.world.player;
    const want = `player:${p.cls}${p.gender}:${p.armourShape}`;
    const check = () => {
      for (const [k, v] of game.renderer.entitySpr) if (k.startsWith(want) && v) return res(true);
      if (performance.now() - t0 > 3000) return res(false);
      requestAnimationFrame(check);
    };
    check();
  })).catch(() => {});
  await shot(`class_${i + 1}_${classLooks[i].cls}`);
}

// ---- 3. 技能施法特效 (db 名带空格) ----
const castPicks = ['Fire Ball', 'Lightning Ball', 'Ice Bolt'];
for (let i = 0; i < castPicks.length; i++) {
  await page.evaluate(async (nm) => { await WC.cast(nm); }, castPicks[i]);
  // 等特效实例出现, 再推进 5 帧让特效帧预取→绘制
  await page.waitForFunction(
    () => window.game?.world?.effects?.length > 0, { timeout: 2500 }).catch(() => {});
  await shot(`magic_${i + 1}_${castPicks[i].replace(/ /g, '')}`, 5);
  await sleep(1200);
}

// ---- 4. 纸娃娃穿/脱 ----
await page.evaluate(() => { WC.setClass('Warrior'); WC.wear('Armour', 0); WC.wear('Weapon', -1); WC.wear('Helmet', 0); });
await sleep(300);
await shot('doll_1_bare');
const picks = await page.evaluate(async () => {
  const items = await (await fetch('/res/data/items.json')).json();
  const armour = items.find((i) => i.type === 'Armour' && i.cls !== 'Assassin' && i.shape > 0);
  const weapon = items.find((i) => i.type === 'Weapon' && i.cls !== 'Assassin' && i.shape > 0);
  const helmet = items.find((i) => i.type === 'Helmet' && i.shape > 0);
  return { armour, weapon, helmet };
});
await page.evaluate((p) => {
  WC.wear('Armour', p.armour.shape); WC.wear('Weapon', p.weapon.shape); WC.wear('Helmet', p.helmet.shape);
}, picks);
await sleep(300);
await shot('doll_2_armour');
await page.evaluate(() => { game.world.player.dir = 0; });
await sleep(300);
await shot('doll_3_weapon_back');
report.doll = { armour: picks.armour?.zh, weapon: picks.weapon?.zh, helmet: picks.helmet?.zh };


// ---- 5. GM 面板: 传送 3 张 + 摆怪 + 刷物 ----
await page.click('[data-panel="gm"]');
await sleep(500);
await shot('gm_1_panel');
const gmPicks = ['3', '1', 'D1001'];
for (let i = 0; i < gmPicks.length; i++) {
  await page.evaluate(async (stem) => { await WC.teleport(stem); }, gmPicks[i]);
  await sleep(400);
  await shot(`gm_2_tp${i + 1}_${gmPicks[i]}`);
}
await page.evaluate(() => WC.teleport('0'));
await page.evaluate(async () => {
  const mons = await (await fetch('/res/data/monsters.json')).json();
  const items = await (await fetch('/res/data/items.json')).json();
  const chicken = mons.find((m) => m.img === 'Chicken');
  const wolf = mons.find((m) => m.img === 'Wolf');
  const pot = items.find((i) => i.type === 'Consumable');
  const p = game.world.player;
  game.world.summon(chicken.id, p.x + 2, p.y);
  game.world.summon(wolf.id, p.x + 3, p.y + 1);
  game.world.dropItem(pot.id, p.x, p.y + 1);
});
await sleep(600);
await shot('gm_3_spawn_item');
await page.evaluate(() => { game.world.player.invis = true; game.world.player.speed = 3; });
await sleep(300);
await shot('gm_4_invis_speed');

// ---- 6. 4K + 2x UI / 特效开关 ----
await page.evaluate(() => {
  game.settings.resW = 3840; game.settings.resH = 2160;
  game.settings.uiZoom = 2; game.applySettings();
});
await sleep(900);
await shot('set_4k_ui2x');
// 特效开关对比回 720p 做 (swiftshader 下 4K 帧率过低, 截图时机不可控)
await page.evaluate(() => {
  game.settings.resW = 1280; game.settings.resH = 720; game.settings.uiZoom = 1;
  game.applySettings();
});
await sleep(300);
await page.evaluate(async () => {
  game.settings.drawEffects = false; game.settings.drawParticles = false;
  game.applySettings();
  await WC.cast('Fire Ball');
});
// fx_off: 特效关闭 → 直接截 (应无施法特效, 仅 UI)
await shot('set_fx_off', 2);
await page.evaluate(async () => {
  game.settings.drawEffects = true; game.settings.drawParticles = true;
  game.applySettings();
  await WC.cast('Fire Ball');
});
// fx_on: 等特效实际绘制 (effects 存在且推进 5 帧)
await page.waitForFunction(
  () => window.game?.world?.effects?.length > 0, { timeout: 2500 }).catch(() => {});
await shot('set_fx_on', 5);
await sleep(800);

// ---- 7. 大地图 + 聊天 + 腰带 + 伙伴 ----
await page.evaluate(() => WC.teleport('0'));
await sleep(500);
await page.keyboard.press('b');
await sleep(1800);
await shot('ui_1_bigmap');
await page.keyboard.press('b');
await sleep(300);
await page.keyboard.down('Shift');
await page.keyboard.press('1');
await page.keyboard.up('Shift');
await sleep(300);
await page.keyboard.press('Enter');
await page.type('#chat-input', '@where');
await page.keyboard.press('Enter');
await sleep(300);
await shot('ui_2_chat_belt');
await page.evaluate(async () => {
  await game.world.addPet('skeleton');
  await game.world.addPet('shinsoo');
});
await sleep(600);
await shot('ui_3_pets');
// fpsE2E: 复位演示实体 (召唤/伙伴/特效) 后采样 — 代表稳态交互帧率
await page.evaluate(() => {
  const w = game.world;
  w.summons.length = 0; w.pets.length = 0; w.effects.length = 0;
  w.player.invis = false; w.player.speed = 1;
});
await sleep(300);
report.fpsE2E = await page.evaluate(() => new Promise((res) => {
  let n = 0, t0 = 0;
  const cb = () => {
    if (!t0) { t0 = performance.now(); }   // 丢弃启动首帧
    else n++;
    if (performance.now() - t0 < 2000) requestAnimationFrame(cb);
    else res(Math.round(n * 1000 / (performance.now() - t0)));
  };
  requestAnimationFrame(cb);
}));
report.fpsEngine = await page.evaluate(() => new Promise((res) => {
  const d0 = game.renderer.lastFrameStats.draw;
  const t0 = performance.now();
  setTimeout(() => res(Math.round((game.renderer.lastFrameStats.draw - d0) * 1000 / (performance.now() - t0))), 1500);
}));
report.fps = report.fpsE2E;
report.errors = errs.slice(0, 10);

await page.evaluate(() => WC.teleport('0'));
await sleep(400);
await shot('final_bichon');

fs.writeFileSync(`${OUT}/wc_report.json`, JSON.stringify(report, null, 2));
log('report:', JSON.stringify(report, null, 2));
await browser.close();
