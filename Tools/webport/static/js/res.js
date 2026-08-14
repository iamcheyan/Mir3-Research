// res.js — 资源加载器: 瓦片/精灵帧 (带 manifest 元数据缓存 + LRU 图像缓存)
import { TILE } from './data.js';

const imgCache = new Map();       // url -> Image (LRU 上限 4000)
const inflight = new Map();
const pendingTiles = new Set();

function cacheImage(url) {
  if (imgCache.has(url)) {
    const v = imgCache.get(url);
    imgCache.delete(url); imgCache.set(url, v);  // touch LRU
    return v;
  }
  let p = inflight.get(url);
  if (!p) {
    p = new Promise((res, rej) => {
      const im = new Image();
      im.onload = () => {
        imgCache.set(url, im);
        inflight.delete(url);
        if (imgCache.size > 4000) {
          const first = imgCache.keys().next().value;
          imgCache.delete(first);
        }
        res(im);
      };
      im.onerror = () => { inflight.delete(url); res(null); };  // 缺帧渲染为空, 不阻塞
      im.src = url;
    });
    inflight.set(url, p);
  }
  return p;
}

export function tileURL(stem, tx, ty) { return `/res/maps/${stem}/${tx}_${ty}.webp`; }
export function loadTile(stem, tx, ty) {
  const url = tileURL(stem, tx, ty);
  pendingTiles.add(url);
  const v = cacheImage(url);            // 命中=Image, 未命中=Promise<Image>
  return Promise.resolve(v).finally(() => pendingTiles.delete(url));
}
export function spriteURL(lib, frame) { return `/res/sprites/${lib}/${frame}.webp`; }

export function loadSprite(lib, frame) {
  return cacheImage(spriteURL(lib, frame));
}

// stem 给定时只数该地图的瓦片 (切图等待不被其他资源阻塞)
export function pendingCount(stem) {
  if (!stem) return pendingTiles.size + inflight.size;
  const pre = `/res/maps/${stem}/`;
  let n = 0;
  for (const u of pendingTiles) if (u.startsWith(pre)) n++;
  return n;
}

// 帧元数据 (锚点): {frame: [w,h,ox,oy]}
const metaCache = new Map();
export async function frameMeta(lib) {
  if (metaCache.has(lib)) return metaCache.get(lib);
  try {
    const r = await fetch(`/res/sprites/${lib}/manifest.json`);
    if (!r.ok) throw 0;
    const m = await r.json();
    metaCache.set(lib, m);
    return m;
  } catch {
    metaCache.set(lib, {});
    return {};
  }
}
