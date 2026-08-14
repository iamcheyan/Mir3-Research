// shot.js — 验收截图序列辅助, 挂 window.WC (浏览器控制台/自动化驱动)
(() => {
  const WC = {};

  WC.grab = () => document.getElementById('game').toDataURL('image/png');

  WC.wait = (ms) => new Promise((r) => setTimeout(r, ms));

  WC.waitForTiles = async (timeout = 8000) => {
    const t0 = performance.now();
    while (performance.now() - t0 < timeout) {
      let pending = 0;
      for (const v of game.cam.tileImgs.values()) if (v && v.then) pending++;
      if (pending === 0) return true;
      await new Promise((r) => requestAnimationFrame(r));
    }
    return false;
  };

  WC.teleport = async (stem, x, y) => {
    await game.teleport(stem, x, y);
    await WC.waitForTiles();
    await WC.wait(400);
  };

  WC.setClass = (cls) => { game.world.player.cls = cls; game.world.player.anim = 'standing'; };
  WC.wear = (type, shape) => {
    const p = game.world.player;
    if (type === 'Armour') p.armourShape = shape;
    if (type === 'Weapon') p.weaponShape = shape;
    if (type === 'Helmet') p.helmetShape = shape;
  };

  // 数据清单 (data.js D() 不导出到 window; 经 fetch 直取)
  let _magics = null;
  WC.magics = async () => {
    if (!_magics) _magics = await (await fetch('/res/data/magics.json')).json();
    return _magics;
  };
  WC.cast = async (nameOrZh) => {
    const rec = (await WC.magics()).find((x) => x.name === nameOrZh || x.zh === nameOrZh);
    if (rec) game.castMagic(rec);
    return rec || null;
  };

  window.WC = WC;
})();
