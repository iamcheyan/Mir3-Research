// camera.js — 镜头/画布管理: 瓦片拼接渲染 + 分辨率档位缩放
import { TILE } from './data.js';
import { loadTile } from './res.js';

export class Camera {
  constructor(canvas) {
    this.canvas = canvas;
    this.ctx = canvas.getContext('2d');
    this.x = 0; this.y = 0;            // 中心世界坐标 (px)
    this.zoom = 1;
    this.resW = 1280; this.resH = 720; // 分辨率档位 (canvas 物理像素)
    this.dirty = true;
    this.tileImgs = new Map();         // "stem:tx:ty" -> Image
    this._req = [];
    this._requestId = 0;
  }

  setResolution(w, h) {
    this.resW = w; this.resH = h;
    this.canvas.width = Math.round(w * this.zoom);
    this.canvas.height = Math.round(h * this.zoom);
    this.dirty = true;
  }

  setZoom(z) {
    this.zoom = z;
    this.canvas.width = Math.round(this.resW * z);
    this.canvas.height = Math.round(this.resH * z);
    this.dirty = true;
  }

  viewSize() { return { w: this.resW, h: this.resH }; }

  centerOn(wx, wy) { this.x = wx; this.y = wy; this.dirty = true; }

  worldToScreen(wx, wy) {
    return {
      x: (wx - this.x) * this.zoom + this.canvas.width / 2,
      y: (wy - this.y) * this.zoom + this.canvas.height / 2,
    };
  }

  screenToWorld(sx, sy) {
    return {
      x: (sx - this.canvas.width / 2) / this.zoom + this.x,
      y: (sy - this.canvas.height / 2) / this.zoom + this.y,
    };
  }

  drawMap(stem, tiles, worldW, worldH) {
    const [nx, ny] = tiles;
    const half = { w: this.canvas.width / 2, h: this.canvas.height / 2 };
    const x0 = this.x - half.w / this.zoom, x1 = this.x + half.w / this.zoom;
    const y0 = this.y - half.h / this.zoom, y1 = this.y + half.h / this.zoom;
    const tx0 = Math.max(0, Math.floor(x0 / TILE)), tx1 = Math.min(nx - 1, Math.floor(x1 / TILE));
    const ty0 = Math.max(0, Math.floor(y0 / TILE)), ty1 = Math.min(ny - 1, Math.floor(y1 / TILE));
    const missing = [];
    const ctx = this.ctx;
    ctx.imageSmoothingEnabled = false;
    // 黑底
    ctx.fillStyle = '#101014';
    ctx.fillRect(0, 0, this.canvas.width, this.canvas.height);
    const z = this.zoom;
    const toScr = (wx, wy) => ({ x: (wx - this.x) * z + half.w, y: (wy - this.y) * z + half.h });
    for (let ty = ty0; ty <= ty1; ty++) {
      for (let tx = tx0; tx <= tx1; tx++) {
        const key = `${stem}:${tx}:${ty}`;
        let img = this.tileImgs.get(key);
        if (img === undefined) {
          const p = loadTile(stem, tx, ty).then((im) => {
            // resolve 后回填缓存, 后续帧直接用 Image
            this.tileImgs.set(key, im);
            return im;
          });
          this.tileImgs.set(key, p);
          img = p;
        }
        if (img && typeof img.then === 'function') {
          missing.push(img);
          img = null;   // 本帧占位, resolve 后下一帧生效
        }
        if (img) {
          const p = toScr(tx * TILE, ty * TILE);
          const sz = Math.ceil(TILE * z) + 1;
          ctx.drawImage(img, p.x, p.y, sz, sz);
        } else {
          // 占位 (等待中)
          const p = toScr(tx * TILE, ty * TILE);
          ctx.fillStyle = '#16161c';
          ctx.fillRect(p.x, p.y, Math.ceil(TILE * z) + 1, Math.ceil(TILE * z) + 1);
        }
      }
    }
    // LRU 裁剪: 每次切图后清理不在当前视野的项
    if (this.tileImgs.size > 400) {
      for (const k of this.tileImgs.keys()) {
        if (this.tileImgs.size <= 300) break;
        if (!k.startsWith(stem + ':')) this.tileImgs.delete(k);
      }
    }
    return missing;
  }
}
