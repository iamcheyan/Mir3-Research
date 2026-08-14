/* gesture.js — Mir3 工具集共享触控手势（Phase 1，Goal §3.1）
 *
 * 统一“单指平移 / 双指缩放 / 双击放大”契约（Goal §3.2 规则 5）。
 * 只处理 touch/pen 指针；鼠标完全走宿主页面的原有路径，桌面零回归。
 *
 * 用法：
 *   WU.gesture(el, {
 *     pan:       (dx, dy) => {},          // 单指拖动增量（屏幕像素）
 *     pinch:     (step, cx, cy) => {},    // step=+1 放大 / -1 缩小；cx,cy 为相对 el 的手势锚点
 *     doubleTap: (x, y) => {},            // 双击（相对 el 坐标）
 *     tap:       (x, y) => {},            // 单击（280ms 内无第二击才触发）
 *   });
 *
 * 注意：宿主需在 CSS 中对 el 设置 touch-action:none（通常限定在
 * @media (pointer:coarse) 下），否则浏览器会先接管手势并发 pointercancel。
 */
(function () {
  "use strict";
  const WU = window.WU = window.WU || {};

  const TAP_MS = 300;        // 双击间隔
  const TAP_SLOP = 12;       // 判定为 tap 的最大位移 px
  const PINCH_STEP = 1.3;    // 距离比值跨过该阈值进一档

  WU.gesture = function (el, handlers) {
    if (!el || !el.addEventListener) return;
    const h = handlers || {};
    const ptrs = new Map();          // pointerId -> {x, y}
    let pinchBase = 0;               // 当前档位的两指距离
    let downInfo = null;             // 首指按下信息（tap 检测）
    let lastTap = null;              // {x, y, t}
    let tapTimer = null;

    const midOf = () => {
      const pts = [...ptrs.values()];
      const r = el.getBoundingClientRect();
      return [ (pts[0].x + pts[1].x) / 2 - r.left,
               (pts[0].y + pts[1].y) / 2 - r.top ];
    };
    const distOf = () => {
      const pts = [...ptrs.values()];
      return Math.hypot(pts[0].x - pts[1].x, pts[0].y - pts[1].y);
    };

    el.addEventListener("pointerdown", (e) => {
      if (e.pointerType === "mouse") return;      // 桌面鼠标：原路径
      e.preventDefault();                          // 抑制合成鼠标事件，避免与宿主 mousedown 冲突
      try { el.setPointerCapture(e.pointerId); } catch (err) {}
      ptrs.set(e.pointerId, { x: e.clientX, y: e.clientY });
      if (ptrs.size === 1) {
        downInfo = { x: e.clientX, y: e.clientY, t: performance.now(), moved: 0 };
      } else if (ptrs.size === 2) {
        pinchBase = distOf();
        downInfo = null;
        clearTimeout(tapTimer); tapTimer = null;
      }
    });

    el.addEventListener("pointermove", (e) => {
      if (!ptrs.has(e.pointerId)) return;
      const prev = ptrs.get(e.pointerId);
      const dx = e.clientX - prev.x, dy = e.clientY - prev.y;
      ptrs.set(e.pointerId, { x: e.clientX, y: e.clientY });

      if (ptrs.size === 1) {
        if (downInfo) {
          downInfo.moved += Math.abs(dx) + Math.abs(dy);
          if (downInfo.moved > TAP_SLOP) downInfo = null;   // 拖动不再是 tap
        }
        if (h.pan) h.pan(dx, dy);
      } else if (ptrs.size === 2 && pinchBase > 0) {
        const d = distOf();
        const ratio = d / pinchBase;
        if (ratio >= PINCH_STEP || ratio <= 1 / PINCH_STEP) {
          const step = ratio > 1 ? 1 : -1;
          pinchBase = d;
          if (h.pinch) h.pinch(step, ...midOf());
        }
      }
    });

    const release = (e) => {
      if (!ptrs.has(e.pointerId)) return;
      ptrs.delete(e.pointerId);
      if (ptrs.size < 2) pinchBase = 0;
      if (ptrs.size === 0 && downInfo) {
        const dt = performance.now() - downInfo.t;
        if (dt < 400) {
          const r = el.getBoundingClientRect();
          const x = downInfo.x - r.left, y = downInfo.y - r.top;
          const now = performance.now();
          if (lastTap && now - lastTap.t < TAP_MS &&
              Math.hypot(downInfo.x - lastTap.x, downInfo.y - lastTap.y) < 32) {
            lastTap = null;
            clearTimeout(tapTimer); tapTimer = null;
            if (h.doubleTap) h.doubleTap(x, y);
          } else {
            lastTap = { x: downInfo.x, y: downInfo.y, t: now };
            if (h.tap) {
              clearTimeout(tapTimer);
              tapTimer = setTimeout(() => { tapTimer = null; h.tap(x, y); }, 280);
            }
          }
        }
        downInfo = null;
      }
    };
    el.addEventListener("pointerup", release);
    el.addEventListener("pointercancel", release);
  };
})();
