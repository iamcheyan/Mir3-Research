/* uieditor app.js — Zircon UI 所见即所得编辑器前端
 *
 * 数据：/api/tree（窗口列表）、/api/window/{cls}（控件树）、/api/overlay（diff）。
 * 渲染：absolute 定位 DOM（1024x768 逻辑画布，可 0.5x/1x/2x 缩放），
 *       图片控件 <img src="/zl/{lib}/{frame}.png">（服务端 zlsdk 实时解码）。
 * 保存：只存 diff（未改控件不进 overlay），POST /api/overlay 原子写
 *       GodotClient/UI/ui_overlay.json → 游戏内 F12 热重载。
 */
"use strict";

const $ = (s) => document.querySelector(s);
const state = {
  tree: null,          // /api/tree 结果
  win: null,           // 当前窗口完整树 /api/window/{cls}
  overlay: {},         // 全量 diff（含其它窗口）
  sel: null,           // 当前选中控件节点（树对象）
  zoom: 1,
  gridSnap: false,
  edgeSnap: false,
  undo: [], redo: [],
  dirty: false,
  shots: [],
};

/* ---------------- 工具 ---------------- */
function toast(msg, err = false) {
  const t = $("#toast");
  t.textContent = msg;
  t.classList.toggle("err", err);
  t.classList.remove("hid");
  clearTimeout(t._h);
  t._h = setTimeout(() => t.classList.add("hid"), 2400);
}
function nodeByPath(path) {
  if (!state.win) return null;
  if (path === state.win.className) return state.win;
  let cur = state.win;
  for (const seg of path.split("/")) {
    const i = parseInt(seg, 10);
    if (isNaN(i)) continue; // 类名段跳过
    if (!cur.children || i < 0 || i >= cur.children.length) return null;
    cur = cur.children[i];
  }
  return cur;
}
function effProps(node) {
  // 原始属性 + overlay 覆盖 → 生效属性
  const base = {
    location: node.location, size: node.size, text: node.text ?? "",
    fontSize: node.fontSize, visible: node.visible,
    textColour: node.textColour ?? node.foreColour,
  };
  const ov = state.overlay[state.win.className]?.[node.path];
  return ov ? { ...base, ...ov } : base;
}
function isModified(path) {
  const ov = state.overlay[state.win?.className];
  return !!(ov && ov[path] && Object.keys(ov[path]).length);
}
async function selectWindow(cls) {
  if (state.dirty && !confirm("有未同步的改动，切换窗口将保留（已保存到内存）。继续？")) return;
  const raw = await (await fetch(`/api/window/${cls}`)).json();
  // 导出格式：根节点字段 + controls 数组；根节点没有 path —— 统一补上。
  state.win = { ...raw, path: raw.className, text: raw.title, children: raw.controls || [] };
  const walkFix = (n) => (n.children || []).forEach((c, i) => {
    if (!c.path) c.path = `${n.path}/${i}`;
    walkFix(c);
  });
  walkFix(state.win);
  state.sel = null;
  $("#win-sub").textContent = `${cls} · ${state.win.controlCount} 控件`;
  renderCanvas();
  renderTree();
  renderProps();
  renderWinList($("#win-filter").value);
  const shot = $("#underlay");
  const avail = state.shots.includes(cls);
  shot.src = avail ? `/shot/${cls}.png` : "";
  shot.style.opacity = $("#under-opacity").value;
  shot.classList.toggle("show", avail && $("#opt-under").checked);
}
function pushUndo(snapshot) {
  state.undo.push(snapshot);
  if (state.undo.length > 100) state.undo.shift();
  state.redo = [];
}
function overlaySnapshot() {
  return JSON.parse(JSON.stringify(state.overlay));
}
function markDirty() {
  state.dirty = true;
  $("#save-state").textContent = "未同步";
}

/* ---------------- 属性可编辑集（与 UiOverlay.cs 开放同一集合） ----------------
 * location / size / text / fontSize / visible / textColour
 * 其余（图库帧、事件、逻辑）一律只读展示。 */
function applyPropToOverlay(node, key, value) {
  const cls = state.win.className;
  state.overlay[cls] ??= {};
  const props = state.overlay[cls][node.path] ??= {};
  const isRoot = node.path === cls;
  const base = node;

  const sameAsBase = (v) => {
    switch (key) {
      case "location": return JSON.stringify(v) === JSON.stringify(base.location);
      case "size":     return JSON.stringify(v) === JSON.stringify(base.size);
      case "text":     return v === (base.text ?? "");
      case "fontSize": return v === base.fontSize;
      case "visible":  return v === base.visible;
      case "textColour": return JSON.stringify(v) === JSON.stringify(base.textColour ?? base.foreColour);
      default: return false;
    }
  };
  if (sameAsBase(value)) delete props[key];          // 回到原始值 → 移除 diff
  else props[key] = value;
  if (Object.keys(props).length === 0) delete state.overlay[cls][node.path];
  if (Object.keys(state.overlay[cls]).length === 0) delete state.overlay[cls];
  markDirty();
}

/* ---------------- 窗口列表 ---------------- */
async function loadTree() {
  state.tree = await (await fetch("/api/tree")).json();
  $("#win-count").textContent = state.tree.windowCount;
  state.shots = (await (await fetch("/api/shots")).json()).shots;
  renderWinList("");
}
function renderWinList(filter) {
  const ul = $("#win-list");
  ul.innerHTML = "";
  const f = filter.trim().toLowerCase();
  for (const w of state.tree.windows) {
    const hay = (w.className + " " + w.title).toLowerCase();
    if (f && !hay.includes(f)) continue;
    const li = document.createElement("li");
    li.dataset.cls = w.className;
    if (state.win && w.className === state.win.className) li.classList.add("on");
    if (state.overlay[w.className]) li.classList.add("has-diff");
    const shotAvail = state.shots.includes(w.className);
    li.innerHTML =
      `<span>${w.className}</span><span class="zh">${escapeHtml(w.title) || "·"}</span>` +
      `<span class="cnt">${w.controlCount}${shotAvail ? " 📷" : ""}</span>`;
    li.onclick = () => selectWindow(w.className);
    ul.appendChild(li);
  }
}
function escapeHtml(s) {
  return String(s).replace(/[&<>"']/g, c => ({ "&": "&amp;", "<": "&lt;", ">": "&gt;", '"': "&quot;", "'": "&#39;" }[c]));
}
function alignToCss(a) {
  return { Left: "flex-start", Center: "center", Right: "flex-end" }[a] || "flex-start";
}
function valignToCss(a) {
  return { Top: "flex-start", Center: "center", Bottom: "flex-end" }[a] || "center";
}
function isMobile() { return window.matchMedia("(max-width: 700px)").matches; }


function renderCanvas() {
  const root = $("#controls-root");
  root.innerHTML = "";
  const w = state.win;
  const div = renderNode(w, true);
  root.appendChild(div);
  applyZoom();
}
function renderNode(node, isRoot) {
  const p = isRoot ? { location: node.location, size: node.size } : effProps(node);
  const div = document.createElement("div");
  div.className = "ctl" + (isRoot ? " root" : "");
  div.dataset.path = node.path;
  div.style.left = p.location[0] + "px";
  div.style.top = p.location[1] + "px";
  div.style.width = Math.max(2, p.size[0]) + "px";
  div.style.height = Math.max(2, p.size[1]) + "px";
  if (p.visible === false) div.classList.add("dim");
  if (!isRoot && isModified(node.path)) div.classList.add("modified");

  if (node.image && node.image.index >= 0) {
    const img = document.createElement("img");
    img.src = `/zl/${node.image.library}/${node.image.index}.png`;
    img.draggable = false;
    div.appendChild(img);
  }
  if (node.text) {
    const lbl = document.createElement("div");
    lbl.className = "lbl";
    lbl.textContent = node.text;
    const fs = p.fontSize ?? 12;
    lbl.style.fontSize = Math.round(fs * 1.0) + "px";
    lbl.style.color = cssColor(p.textColour ?? node.textColour ?? node.foreColour);
    lbl.style.setProperty("--ha", alignToCss(node.align));
    lbl.style.setProperty("--va", valignToCss(node.valign));
    div.appendChild(lbl);
  }
  // 8 向手柄（仅选中时显示，CSS 控制）
  for (const h of ["nw","n","ne","e","se","s","sw","w"]) {
    const el = document.createElement("div");
    el.className = "handle " + h;
    el.dataset.dir = h;
    div.appendChild(el);
  }
  if (!isRoot) {
    div.addEventListener("mousedown", (e) => {
      e.stopPropagation();
      if (e.target.classList.contains("handle")) startResize(e, node, e.target.dataset.dir);
      else startDrag(e, node);
    });
  } else {
    div.addEventListener("mousedown", (e) => { /* 点空白 */ marqueeStart(e); });
  }
  div.addEventListener("click", (e) => { e.stopPropagation(); select(node); });

  for (const c of node.children || []) div.appendChild(renderNode(c, false));
  return div;
}
function cssColor(c) {
  if (!c) return "#fff";
  const [r, g, b, a] = c;
  return `rgba(${r},${g},${b},${(a ?? 255) / 255})`;
}
function select(node) {
  state.sel = node;
  document.querySelectorAll(".ctl.sel").forEach(el => el.classList.remove("sel"));
  const el = document.querySelector(`.ctl[data-path="${CSS.escape(node.path)}"]`);
  if (el) el.classList.add("sel");
  renderTree();
  renderProps();
}
function applyZoom() {
  const z = state.zoom;
  const c = $("#canvas");
  // scale 不改变布局盒尺寸：小屏时画布仍占 1024px 宽导致整页横向滚动。
  // 用 wrapper 占位（画布绝对居中于 wrapper，wrapper 尺寸 = 逻辑尺寸×缩放）。
  let wrap = document.getElementById("canvas-wrap");
  if (!wrap) {
    wrap = document.createElement("div");
    wrap.id = "canvas-wrap";
    wrap.style.position = "relative";
    wrap.style.margin = "0 auto";
    c.parentNode.insertBefore(wrap, c);
    wrap.appendChild(c);
  }
  c.style.transform = `scale(${z})`;
  c.style.transformOrigin = "0 0";
  c.style.position = "absolute";
  c.style.left = "0";
  c.style.top = "0";
  wrap.style.width = Math.round(1024 * z) + "px";
  wrap.style.height = Math.round(768 * z) + "px";
  wrap.style.margin = "24px auto";
  const vp = $("#canvas-viewport");
  vp.scrollLeft = 0; vp.scrollTop = 0;
  $("#zoom-label").textContent = Math.round(z * 100) + "%";
  document.querySelectorAll("#canvas-toolbar [data-zoom]").forEach(b =>
    b.classList.toggle("on", parseFloat(b.dataset.zoom) === z));
}
function snap(x, y, node) {
  if (state.gridSnap) {
    x = Math.round(x / 2) * 2;
    y = Math.round(y / 2) * 2;
  }
  if (state.edgeSnap) {
    // 吸附到兄弟控件边缘（±3px）
    const sibs = [];
    const collect = (n) => { for (const c of n.children || []) { if (c.path !== node.path) sibs.push(c); collect(c); } };
    collect(state.win);
    const th = 3 / state.zoom;
    for (const s of sibs) {
      const sp = effProps(s);
      const edges = [sp.location[0], sp.location[0] + sp.size[0]];
      for (const ex of edges) {
        if (Math.abs(x - ex) < th) x = ex;
        if (Math.abs((x + effProps(node).size[0]) - ex) < th) x = ex - effProps(node).size[0];
      }
      const edgesY = [sp.location[1], sp.location[1] + sp.size[1]];
      for (const ey of edgesY) {
        if (Math.abs(y - ey) < th) y = ey;
        if (Math.abs((y + effProps(node).size[1]) - ey) < th) y = ey - effProps(node).size[1];
      }
    }
  }
  return [Math.round(x), Math.round(y)];
}
function startDrag(e, node) {
  select(node);
  const before = overlaySnapshot();
  const el = e.currentTarget;
  const p0 = effProps(node);
  const sx = e.clientX, sy = e.clientY;
  const z = state.zoom;
  let moved = false;
  const move = (ev) => {
    moved = true;
    let [x, y] = snap(p0.location[0] + (ev.clientX - sx) / z, p0.location[1] + (ev.clientY - sy) / z, node);
    el.style.left = x + "px"; el.style.top = y + "px";
    el._pending = [x, y];
  };
  const up = () => {
    window.removeEventListener("mousemove", move);
    window.removeEventListener("mouseup", up);
    if (moved && el._pending) {
      pushUndo(before);
      applyPropToOverlay(node, "location", el._pending);
      renderProps(); renderTree();
    }
  };
  window.addEventListener("mousemove", move);
  window.addEventListener("mouseup", up);
  e.preventDefault();
}
function startResize(e, node, dir) {
  select(node);
  const before = overlaySnapshot();
  const el = e.currentTarget.parentElement;
  const p0 = effProps(node);
  const sx = e.clientX, sy = e.clientY;
  const z = state.zoom;
  let moved = false;
  const move = (ev) => {
    moved = true;
    const dx = (ev.clientX - sx) / z, dy = (ev.clientY - sy) / z;
    let x = p0.location[0], y = p0.location[1], w = p0.size[0], h = p0.size[1];
    if (dir.includes("e")) w = Math.max(4, p0.size[0] + dx);
    if (dir.includes("s")) h = Math.max(4, p0.size[1] + dy);
    if (dir.includes("w")) { w = Math.max(4, p0.size[0] - dx); x = p0.location[0] + (p0.size[0] - w); }
    if (dir.includes("n")) { h = Math.max(4, p0.size[1] - dy); y = p0.location[1] + (p0.size[1] - h); }
    [x, y] = state.gridSnap ? [Math.round(x/2)*2, Math.round(y/2)*2] : [Math.round(x), Math.round(y)];
    w = state.gridSnap ? Math.round(w/2)*2 : Math.round(w);
    h = state.gridSnap ? Math.round(h/2)*2 : Math.round(h);
    el.style.left = x+"px"; el.style.top = y+"px";
    el.style.width = Math.max(2,w)+"px"; el.style.height = Math.max(2,h)+"px";
    el._pending = { location: [x, y], size: [w, h] };
  };
  const up = () => {
    window.removeEventListener("mousemove", move);
    window.removeEventListener("mouseup", up);
    if (moved && el._pending) {
      pushUndo(before);
      applyPropToOverlay(node, "location", el._pending.location);
      applyPropToOverlay(node, "size", el._pending.size);
      renderProps(); renderTree();
    }
  };
  window.addEventListener("mousemove", move);
  window.addEventListener("mouseup", up);
  e.preventDefault();
  e.stopPropagation();
}

/* ---------------- 框选（画布空白处） ---------------- */
function marqueeStart(e) {
  if (e.button !== 0) return;
  const vp = $("#canvas");
  const rect = vp.getBoundingClientRect();
  const x0 = (e.clientX - rect.left) / state.zoom, y0 = (e.clientY - rect.top) / state.zoom;
  const mq = $("#marquee");
  const move = (ev) => {
    const x1 = (ev.clientX - rect.left) / state.zoom, y1 = (ev.clientY - rect.top) / state.zoom;
    const x = Math.min(x0,x1), y = Math.min(y0,y1), w = Math.abs(x1-x0), h = Math.abs(y1-y0);
    mq.style.left = x+"px"; mq.style.top = y+"px"; mq.style.width = w+"px"; mq.style.height = h+"px";
    mq.classList.remove("hid");
    mq._rect = {x, y, w, h};
  };
  const up = () => {
    window.removeEventListener("mousemove", move);
    window.removeEventListener("mouseup", up);
    mq.classList.add("hid");
    if (!mq._rect || mq._rect.w < 4 || mq._rect.h < 4) { clearSel(); return; }
    // 选中与框相交的控件（简单起见取第一个命中的顶层；多选后续按需）
    const r = mq._rect;
    const hits = [];
    document.querySelectorAll(".ctl").forEach(el => {
      const l = parseFloat(el.style.left), t = parseFloat(el.style.top);
      const w = parseFloat(el.style.width), h = parseFloat(el.style.height);
      if (l < r.x + r.w && l + w > r.x && t < r.y + r.h && t + h > r.y) {
        const node = nodeByPath(el.dataset.path);
        if (node) hits.push({ node, area: w * h });
      }
    });
    hits.sort((a, b) => a.area - b.area);
    if (hits.length) select(hits[0].node);
  };
  window.addEventListener("mousemove", move);
  window.addEventListener("mouseup", up);
}
function clearSel() {
  state.sel = null;
  document.querySelectorAll(".ctl.sel").forEach(el => el.classList.remove("sel"));
  renderProps(); renderTree();
}

/* ---------------- 控件树 ---------------- */
function renderTree() {
  const tree = $("#tree");
  tree.innerHTML = "";
  if (!state.win) return;
  const addNode = (node, depth) => {
    const row = document.createElement("div");
    row.className = "tnode" + (state.sel === node ? " sel" : "") + (isModified(node.path) ? " modified" : "");
    row.style.paddingLeft = (6 + depth * 14) + "px";
    const hasKids = node.children && node.children.length;
    row.innerHTML =
      `<span class="tw">${hasKids ? "▾" : ""}</span>` +
      `<span class="ttype">${node.type}</span>` +
      `<span class="tname">${escapeHtml(node.name || node.text || node.path.split("/").pop())}</span>`;
    row.onclick = () => select(node);
    tree.appendChild(row);
    for (const c of node.children || []) addNode(c, depth + 1);
  };
  addNode(state.win, 0);
}

/* ---------------- 属性面板 ---------------- */
function renderProps() {
  const box = $("#props");
  box.innerHTML = "";
  const node = state.sel;
  if (!node || !state.win) {
    box.innerHTML = `<div class="dim" style="padding:8px 2px">点击画布或树中的控件查看属性<br><br>
      拖拽移动 · 8 向手柄缩放 · 方向键 1px（Shift=10px）<br>Ctrl+Z 撤销 · Ctrl+Y 重做</div>`;
    $("#prop-path").textContent = "";
    return;
  }
  const p = effProps(node);
  const isRoot = node.path === state.win.className;
  $("#prop-path").textContent = node.path;

  const row = (label, inner) => {
    const r = document.createElement("div");
    r.className = "prow";
    r.innerHTML = `<label>${label}</label>` + inner;
    box.appendChild(r);
    return r;
  };
  const num = (v) => escapeHtml(String(v));

  row("类型", `<span>${node.type}</span>`);
  // Location
  const rLoc = row("Location", `<span class="pair">
    <input type="number" id="p-x" value="${num(p.location[0])}"><input type="number" id="p-y" value="${num(p.location[1])}">
    </span><span class="origin" id="o-loc">${node.location[0]},${node.location[1]}</span>`);
  rLoc.querySelectorAll("input").forEach(inp => inp.onchange = () => {
    const before = overlaySnapshot(); pushUndo(before);
    applyPropToOverlay(node, "location", [parseInt($("#p-x").value,10)||0, parseInt($("#p-y").value,10)||0]);
    refreshNode(node);
  });
  // Size
  const rSize = row("Size", `<span class="pair">
    <input type="number" id="p-w" value="${num(p.size[0])}"><input type="number" id="p-h" value="${num(p.size[1])}">
    </span><span class="origin" id="o-size">${node.size[0]},${node.size[1]}</span>`);
  rSize.querySelectorAll("input").forEach(inp => inp.onchange = () => {
    const before = overlaySnapshot(); pushUndo(before);
    applyPropToOverlay(node, "size", [Math.max(2, parseInt($("#p-w").value,10)||2), Math.max(2, parseInt($("#p-h").value,10)||2)]);
    refreshNode(node);
  });
  // Text
  if (node.text !== undefined || node.type.includes("Label") || node.type.includes("Button") || isRoot) {
    const rText = row("Text", `<input type="text" id="p-text" value="${escapeHtml(p.text ?? "")}"><span class="origin" id="o-text">${escapeHtml((node.text ?? "").slice(0, 8))}</span>`);
    rText.querySelector("input").onchange = () => {
      pushUndo(overlaySnapshot());
      applyPropToOverlay(node, "text", $("#p-text").value);
      refreshNode(node);
    };
  }
  // FontSize
  if (p.fontSize !== undefined) {
    const rFs = row("FontSize", `<input type="number" id="p-fs" value="${num(p.fontSize)}"><span class="origin" id="o-fs">${node.fontSize}</span>`);
    rFs.querySelector("input").onchange = () => {
      pushUndo(overlaySnapshot());
      applyPropToOverlay(node, "fontSize", parseInt($("#p-fs").value, 10) || 12);
      refreshNode(node);
    };
  }
  // 颜色（textColour 优先 foreColour）
  const col = p.textColour ?? node.textColour ?? node.foreColour;
  if (col) {
    const hex = rgbToHex(col);
    const rCol = row("文字颜色", `<input type="color" id="p-col" value="${hex}"><span class="origin" id="o-col">${node.textColour ? rgbToHex(node.textColour) : rgbToHex(node.foreColour)}</span>`);
    rCol.querySelector("input").oninput = (e) => {
      const [r, g, b] = hexToRgb(e.target.value);
      const newVal = [r, g, b, col[3] ?? 255];
      applyPropToOverlay(node, "textColour", newVal);
      refreshNode(node, true);
    };
  }
  // Visible
  const rVis = row("Visible", `<select id="p-vis"><option value="1">显示</option><option value="0">隐藏</option></select>`);
  rVis.querySelector("select").value = p.visible === false ? "0" : "1";
  rVis.querySelector("select").onchange = () => {
    pushUndo(overlaySnapshot());
    applyPropToOverlay(node, "visible", $("#p-vis").value === "1");
    refreshNode(node);
  };
  // 只读信息
  if (node.image) {
    row("贴图", `<span class="dim">${node.image.library}[${node.image.index}]</span>`);
  }
  if (node.hint) row("Hint", `<span class="dim">${escapeHtml(node.hint)}</span>`);
  row("abs 位置", `<span class="dim">${node.absLocation.join(", ")}</span>`);

  // reset 按钮
  const rr = document.createElement("div");
  rr.className = "prow";
  rr.innerHTML = `<button id="p-reset">撤销此控件改动</button>`;
  box.appendChild(rr);
  rr.querySelector("button").onclick = () => {
    if (!isModified(node.path)) return;
    pushUndo(overlaySnapshot());
    delete state.overlay[state.win.className][node.path];
    if (!Object.keys(state.overlay[state.win.className]).length) delete state.overlay[state.win.className];
    markDirty();
    refreshNode(node);
  };
}
function rgbToHex(c) {
  const h = (v) => v.toString(16).padStart(2, "0");
  return `#${h(c[0])}${h(c[1])}${h(c[2])}`;
}
function hexToRgb(hex) {
  const n = parseInt(hex.slice(1), 16);
  return [(n >> 16) & 255, (n >> 8) & 255, n & 255];
}
function refreshNode(node, keepSel = false) {
  // 局部重渲染单个控件 DOM（保持选择状态）
  const el = document.querySelector(`.ctl[data-path="${CSS.escape(node.path)}"]`);
  if (!el) return;
  const fresh = renderNode(node, node.path === state.win.className);
  fresh.classList.add("sel");
  el.replaceWith(fresh);
  renderTree();
  if (!keepSel) renderProps();
}

/* ---------------- 保存 / 同步 ---------------- */
async function saveOverlay() {
  try {
    const res = await fetch("/api/overlay", {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({ overlay: state.overlay }),
    });
    const data = await res.json();
    if (!res.ok) throw new Error(data.detail || res.status);
    state.dirty = false;
    $("#save-state").textContent = `已同步（${data.controls} 条）→ 游戏内按 F12`;
    toast(`已同步 ${data.windows} 窗口 / ${data.controls} 条改动。游戏内按 F12 热重载。`);
    renderWinList($("#win-filter").value);
  } catch (e) {
    toast("同步失败: " + e.message, true);
  }
}

/* ---------------- 键盘 ---------------- */
function onKeyDown(e) {
  if (e.target.tagName === "INPUT" || e.target.tagName === "SELECT" || e.target.tagName === "TEXTAREA") return;
  if ((e.ctrlKey || e.metaKey) && e.key.toLowerCase() === "z") { doUndo(); e.preventDefault(); return; }
  if ((e.ctrlKey || e.metaKey) && (e.key.toLowerCase() === "y" || (e.shiftKey && e.key.toLowerCase() === "z"))) { doRedo(); e.preventDefault(); return; }
  if ((e.ctrlKey || e.metaKey) && e.key.toLowerCase() === "s") { saveOverlay(); e.preventDefault(); return; }
  if (!state.sel) return;
  const step = e.shiftKey ? 10 : 1;
  let dx = 0, dy = 0;
  if (e.key === "ArrowLeft") dx = -step;
  else if (e.key === "ArrowRight") dx = step;
  else if (e.key === "ArrowUp") dy = -step;
  else if (e.key === "ArrowDown") dy = step;
  else return;
  e.preventDefault();
  const node = state.sel;
  const p = effProps(node);
  pushUndo(overlaySnapshot());
  applyPropToOverlay(node, "location", [p.location[0] + dx, p.location[1] + dy]);
  refreshNode(node);
}
function doUndo() {
  if (!state.undo.length) return;
  state.redo.push(overlaySnapshot());
  state.overlay = state.undo.pop();
  afterHistory();
}
function doRedo() {
  if (!state.redo.length) return;
  state.undo.push(overlaySnapshot());
  state.overlay = state.redo.pop();
  afterHistory();
}
function afterHistory() {
  markDirty();
  renderCanvas();
  if (state.sel) {
    const again = nodeByPath(state.sel.path);
    state.sel = again;
    if (again) {
      const el = document.querySelector(`.ctl[data-path="${CSS.escape(again.path)}"]`);
      if (el) el.classList.add("sel");
    }
  }
  renderTree(); renderProps();
}

/* ---------------- 启动 ---------------- */
async function boot() {
  // 移动端浏览模式默认 0.5x（画布 512x384 在 390px 屏可横向滚动浏览）
  if (isMobile()) state.zoom = 0.5;
  await loadTree();
  state.overlay = await (await fetch("/api/overlay")).json();
  $("#win-filter").oninput = (e) => renderWinList(e.target.value);
  document.querySelectorAll("#canvas-toolbar [data-zoom]").forEach(b =>
    b.onclick = () => { state.zoom = parseFloat(b.dataset.zoom); applyZoom(); });
  $("#opt-grid").onchange = (e) => state.gridSnap = e.target.checked;
  $("#opt-edge").onchange = (e) => state.edgeSnap = e.target.checked;
  $("#opt-under").onchange = (e) => {
    const shot = $("#underlay");
    shot.classList.toggle("show", e.target.checked && !!shot.src);
  };
  $("#under-opacity").onchange = (e) => $("#underlay").style.opacity = e.target.value;
  $("#btn-save").onclick = saveOverlay;
  $("#btn-undo").onclick = doUndo;
  $("#btn-redo").onclick = doRedo;
  $("#btn-reset").onclick = () => {
    if (!state.win) return;
    if (!state.overlay[state.win.className]) { toast("本窗口无改动"); return; }
    if (!confirm(`清除 ${state.win.className} 的全部改动？`)) return;
    pushUndo(overlaySnapshot());
    delete state.overlay[state.win.className];
    markDirty();
    renderCanvas(); renderTree(); renderProps();
    toast("已清除（记得同步）");
  };

  // ---- 移动端底部操作栏（UIE-P0-01）----
  const leftPanel = $("#left");
  const mbPanel = $("#mb-panel");
  if (mbPanel && leftPanel) {
    mbPanel.onclick = () => leftPanel.classList.toggle("open");
    // 选窗口后自动收起，让画布成为焦点
    const _renderWinList = renderWinList;
    renderWinList = function(q){ _renderWinList(q); };
    leftPanel.addEventListener("click", (e) => {
      const li = e.target.closest("#win-list li");
      if (li) setTimeout(() => leftPanel.classList.remove("open"), 150);
    });
  }
  const mb = { undo: $("#mb-undo"), redo: $("#mb-redo"), reset: $("#mb-reset"), save: $("#mb-save") };
  if (mb.undo) mb.undo.onclick = doUndo;
  if (mb.redo) mb.redo.onclick = doRedo;
  if (mb.save) mb.save.onclick = saveOverlay;
  if (mb.reset) mb.reset.onclick = () => $("#btn-reset").click();   // 复用桌面逻辑（含确认）

  // ---- 画布触控（UIE-P1-01）：单指平移 / 双指阶梯缩放 / 双击放大（桌面鼠标路径不变） ----
  if (window.WU && window.matchMedia && matchMedia("(pointer:coarse)").matches) {
    const cvp = $("#canvas-viewport");
    const ZOOMS = [0.5, 1, 2];
    WU.gesture(cvp, {
      pan: (dx, dy) => { cvp.scrollLeft -= dx; cvp.scrollTop -= dy; },
      pinch: (step) => {
        const cur = ZOOMS.indexOf(state.zoom);
        const next = Math.max(0, Math.min(ZOOMS.length - 1, (cur < 0 ? 1 : cur) + step));
        if (next !== cur) { state.zoom = ZOOMS[next]; applyZoom(); }
      },
      doubleTap: () => {
        const cur = ZOOMS.indexOf(state.zoom);
        state.zoom = ZOOMS[Math.min(ZOOMS.length - 1, (cur < 0 ? 1 : cur) + 1)];
        applyZoom();
      }
    });
  }
  window.addEventListener("keydown", onKeyDown);
  // 默认选中背包（无头验证主对象）
  const first = state.tree.windows.find(w => w.className === "InventoryDialog") || state.tree.windows[0];
  if (first) await selectWindow(first.className);
  $("#save-state").textContent = "";
}
boot().catch(e => { toast("加载失败: " + e.message, true); console.error(e); });
