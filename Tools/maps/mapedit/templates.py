#!/usr/bin/env python3
"""mapedit.templates — 前端 HTML 模板（主界面 / sim）。"""
from __future__ import annotations
SIM_TEMPLATE = """<!DOCTYPE html>
<html lang="zh-CN">
<head>
<meta charset="utf-8">
<title>Mir3 EI 原版 800×600 模拟器</title>
<style>
    html, body { margin:0; padding:0; background:#222; overflow:hidden; font-family:sans-serif; }
    #stage { position:relative; width:800px; height:600px; margin:0 auto; background:#000;
             box-shadow:0 0 30px rgba(0,0,0,.8); overflow:hidden; }
    /* world view: the full-map render is positioned so the requested cell is centered */
    #world { position:absolute; left:0; top:0; width:800px; height:600px; overflow:hidden; }
    #world img { position:absolute; display:block; image-rendering:pixelated; }
    /* original HUD bottom bar (0,465)-(800,600) — semi-transparent over the world */
    #hud { position:absolute; left:0; top:465px; width:800px; height:135px;
           background:rgba(12,12,16,.88); border-top:2px solid #4a3a1a; box-sizing:border-box; }
    #hud .cell-label { position:absolute; left:10px; top:6px; font-size:12px; color:#d8c890;
                       font-family:ui-monospace,monospace; text-shadow:1px 1px 0 #000; }
    #hud .stats { position:absolute; left:10px; top:26px; font-size:11px; color:#9aa;
                  font-family:ui-monospace,monospace; line-height:1.5; }
    #hud .cell-nav { position:absolute; left:10px; top:88px; font-size:11px; color:#887; }
    #hud .cell-nav b { color:#dd8; cursor:pointer; }
    #hud .cell-nav b:hover { color:#ffd; }
    #hud .oob { position:absolute; right:10px; top:6px; font-size:11px; color:#f86; font-family:ui-monospace,monospace; }
    /* original minimap widget: fixed (672,0)-(800,128) */
    #mm { position:absolute; left:672px; top:0; width:128px; height:128px;
          background:rgba(8,10,14,.85); border-left:1px solid #3a3a46; border-bottom:1px solid #3a3a46;
          box-sizing:border-box; }
    #mm img { width:128px; height:128px; image-rendering:pixelated; display:block; }
    #mm .mm-label { position:absolute; left:3px; top:2px; font-size:10px; color:#ffe; opacity:.8;
                    text-shadow:1px 1px 0 #000; }
    #mm .mm-zoom { position:absolute; right:3px; bottom:2px; font-size:10px; color:#ffe; opacity:.9; }
    /* HUD buttons from the static evidence (GameInter.wil frames at hud.left+offset) */
    .hud-btn { position:absolute; background:rgba(60,50,30,.55); border:1px solid #6a5a30;
               box-sizing:border-box; }
    /* entity layer: sprites + name tags, positioned over the world view */
    #ents { position:absolute; left:0; top:0; width:800px; height:600px; pointer-events:none; }
    .ent { position:absolute; transform:translate(-50%,-100%); pointer-events:auto;
           cursor:pointer; }
    .ent img { display:block; image-rendering:pixelated; filter:drop-shadow(2px 2px 0 rgba(0,0,0,.5)); }
    .ent .tag { position:absolute; left:50%; top:100%; transform:translateX(-50%);
                font-size:10px; color:#fff; background:rgba(0,0,0,.55); border:1px solid #555;
                padding:0 3px; white-space:nowrap; border-radius:2px; pointer-events:none; }
    .ent.npc img { border:1px solid rgba(120,200,120,.35); }
    .ent.monster img { border:1px solid rgba(230,80,60,.4); }
    .ent.player img { border:1px solid rgba(120,180,255,.6); }
    .ent.player .tag { color:#8cf; border-color:#46a; }
    .ent:hover .tag { background:rgba(255,220,90,.92); color:#000; }
    .ent.target { outline:2px solid #ffd23d; outline-offset:1px; }
    .ent .info { display:none; position:absolute; left:50%; bottom:calc(100% + 6px);
                 transform:translateX(-50%); background:rgba(10,12,18,.94); color:#ddd;
                 border:1px solid #6a5a30; border-radius:3px; padding:5px 8px;
                 font-size:11px; min-width:150px; white-space:nowrap; z-index:5; }
    .ent:hover .info { display:block; }
    #mm .mm-box { position:absolute; border:1px solid #ffd23d; background:rgba(255,210,61,.25);
                  box-sizing:border-box; }
    /* title bar / toolbar outside the stage */
    #bar { width:800px; margin:6px auto 4px; display:flex; gap:8px; align-items:center;
           color:#ccc; font-size:12px; }
    #bar select { background:#333; color:#eee; border:1px solid #555; border-radius:3px; padding:2px 6px; }
    #bar label { cursor:pointer; }
    #bar button { background:#333; color:#eee; border:1px solid #555; border-radius:3px; cursor:pointer; }
    #tip { width:800px; margin:0 auto; font-size:11px; color:#777; font-family:ui-monospace,monospace; }
</style>
</head>
<body>
<div id="bar">
    <span>地图:</span><select id="sel-map"></select>
    <img id="map-thumb" alt="" style="height:22px;border:1px solid #555;border-radius:2px;display:none;">
    <span>中心格:</span><span id="sel-cell" style="font-family:ui-monospace,monospace;">—</span>
    <label><input type="checkbox" id="chk-g" checked> Back</label>
    <label><input type="checkbox" id="chk-m" checked> Middle</label>
    <label><input type="checkbox" id="chk-f" checked> Front</label>
    <span>offset:</span><select id="sel-off" title="WIL 帧 offset 实验模式；原版 Mir3.exe 地图层从不读取 offset（none）">
        <option value="none" selected>none 原版</option>
        <option value="all">all 全层</option>
        <option value="midfront">mid/front</option>
    </select>
    <button id="btn-strip" title="导出三模式 offset 对比条带 PNG（新标签页）">导出对比图</button>
    <button id="btn-hud" title="切换原版 HUD 显示">HUD 开/关</button>
    <button id="btn-mm" title="T 键 128/256 小地图">小地图 128/256</button>
    <button id="btn-back">← 返回浏览器</button>
</div>
<div id="stage">
    <div id="world"><img id="wimg" alt=""></div>
    <div id="ents"></div>
    <div id="cell-info" style="display:none;position:absolute;z-index:50;pointer-events:none;
        background:rgba(10,10,14,.92);border:1px solid #666;border-radius:4px;
        color:#d8e6ff;font:11px ui-monospace,monospace;padding:5px 7px;white-space:pre;"></div>
    <div id="mm"><img id="mimg" alt=""><span class="mm-label" id="mm-name"></span>
        <span class="mm-zoom" id="mm-zoom">128</span><div class="mm-box" id="mm-box"></div></div>
    <div id="hud">
        <div class="cell-label" id="hud-map">—</div>
        <div class="stats" id="hud-stats"></div>
        <div class="cell-nav">方向键/WASD 移动 1 格 · <b>←</b> <b>↑</b> <b>↓</b> <b>→</b> 箭头移动 · Ctrl+滚轮缩放 · T 切换小地图 · H 切换 HUD</div>
        <div class="oob" id="hud-oob"></div>
    </div>
</div>
<div id="tip">Mir3 EI 原版 800×600 模拟 · 世界画面 rect 投影 · 小地图固定 (672,0)-(800,128) · 底部 HUD (0,465)-(800,600)（原版静态证据 layout.json）</div>
<script>
const stage = document.getElementById("stage");
const wimg = document.getElementById("wimg");
const mimg = document.getElementById("mimg");
const selMap = document.getElementById("sel-map");
const selOff = document.getElementById("sel-off");
const selCell = document.getElementById("sel-cell");
const hudMap = document.getElementById("hud-map");
const hudStats = document.getElementById("hud-stats");
const hudOob = document.getElementById("hud-oob");
const mmName = document.getElementById("mm-name");
const mmZoom = document.getElementById("mm-zoom");
let maps = [], curName = null, cat = null;
let cx = 0, cy = 0, z = 0;            // center cell + zoom ladder level
let mm = 128;                          // minimap surface: 128 or 256 (T key)
let showHud = true;
let ents = [], target = null;          // entities on the current map; clicked target
let player = { x: -1, y: -1 };         // player cell (spawn point when available)

const entStyle = {
    player:   { src: "/sprite?lib=M-Hum.wil&frame=0&scale=1", label: "我" },
    npc:      { src: "/sprite?lib=NPC.wil&frame=0&scale=1",    label: "" },
    guard:    { src: "/sprite?lib=Mon-3.wil&frame=6040&scale=1", label: "" },
    monster:  { src: "/sprite?lib=Mon-1.wil&frame=0&scale=1", label: "" },
};

async function init() {
    const res = await fetch("/api/maps");
    maps = await res.json();
    // hash: #sim=3.map&c=200,300&z=2
    let target = maps[0] && maps[0].name;
    const h = location.hash.match(/sim=([^&]+)/);
    if (h && maps.some(m => m.name === decodeURIComponent(h[1]))) target = decodeURIComponent(h[1]);
    selMap.value = target;
    const cm = location.hash.match(/c=(\\d+),(\\d+)/);
    if (cm) { cx = +cm[1]; cy = +cm[2]; }
    const zm = location.hash.match(/z=(\\d+)/);
    if (zm) z = +zm[1];
    const om = location.hash.match(/om=([a-z]+)/);
    if (om && ["none", "all", "midfront"].includes(om[1])) selOff.value = om[1];
    pick(target);
}
function pick(name) {
    curName = name;
    const mi = maps.find(m => m.name === name);
    if (!mi) return;
    // default center: map middle; player: spawn point if this map has one
    if (!location.hash.match(/c=/)) { cx = Math.floor(mi.w / 2); cy = Math.floor(mi.h / 2); }
    const maxZ = mi.ladder.length - 1;
    const minZ = mi.ladder[0] ?? 0;   // server clamps z up to ladder[0]; client must match
    z = Math.min(Math.max(z, minZ), maxZ);
    loadEntities(mi);
    loadCat(mi);
    loadThumb();
    loadImg();
    loadMini();
    updateHash();
}
async function loadEntities(mi) {
    ents = []; target = null;
    const box = document.getElementById("ents");
    box.innerHTML = "";
    try {
        const res = await fetch("/api/entities?map=" + encodeURIComponent(mi.name));
        const d = await res.json();
        if (d.ok) ents = d.entities;
    } catch (e) { ents = []; }
    const spawn = ents.find(e => e.kind === "spawn");
    if (spawn) player = { x: spawn.x, y: spawn.y };
    else player = { x: Math.floor(mi.w / 2), y: Math.floor(mi.h / 2) };
    renderEnts();
}
function renderEnts() {
    const mi = maps.find(m => m.name === curName);
    const box = document.getElementById("ents");
    box.innerHTML = "";
    const s = 1 << z;
    const cxw = cx * 48 + 24, cyw = cy * 32 + 16;
    // visible filter: cell within screen + margin
    const visX = 800 / 48 * s + 2, visY = 600 / 32 * s + 2;
    const all = [{ x: player.x, y: player.y, kind: "player", name: "玩家", info: "" }];
    for (const e of ents) {
        if (e.kind === "spawn") continue;   // spawn point is the player start, not an entity
        all.push(e);
    }
    for (const e of all) {
        if (Math.abs(e.x - cx) > visX || Math.abs(e.y - cy) > visY) continue;
        const st = entStyle[e.kind];
        const div = document.createElement("div");
        div.className = "ent " + e.kind;
        if (target && target.x === e.x && target.y === e.y && target.kind === e.kind) div.classList.add("target");
        div.style.left = (400 + (e.x * 48 + 24 - cxw) / s) + "px";
        div.style.top = (300 + (e.y * 32 + 16 - cyw) / s) + "px";
        const img = document.createElement("img");
        img.src = st.src; img.alt = "";
        div.appendChild(img);
        const tag = document.createElement("div");
        tag.className = "tag";
        tag.textContent = (e.kind === "player" ? "我" : (e.name || e.kind));
        div.appendChild(tag);
        const info = document.createElement("div");
        info.className = "info";
        let t = e.kind === "player" ? "玩家" : (e.kind === "npc" ? "NPC" : "怪物");
        info.innerHTML = `<b>${t}</b> ${e.name || ""}<br>格 ${e.x},${e.y}${e.kind === "npc" ? " · face " + (e.face ?? 0) + " · body " + (e.body ?? 0) : ""}${e.kind === "monster" ? " · Lv " + (e.level ?? 0) + (e.count && e.count > 1 ? " · ×" + e.count : "") : ""}`;
        if (e.kind === "monster" && Array.isArray(e.drops) && e.drops.length) {
            const fmtCh = (d) => (d.chance < 1 ? "1/" + Math.round(1 / d.chance) : "1/1");
            const top = e.drops.slice(0, 5).map(d => `${d.item}${d.count > 1 ? "×" + d.count : ""}(${fmtCh(d)})`).join(" ");
            info.innerHTML += `<br><span style="color:#ffd27f;">掉落: ${top}${e.drops.length > 5 ? " …" : ""}</span>`;
        }
        div.appendChild(info);
        div.addEventListener("click", () => {
            target = { x: e.x, y: e.y, kind: e.kind, name: e.name };
            renderEnts(); renderHud(); renderMiniBox();
        });
        box.appendChild(div);
    }
    renderMiniBox();
}
function renderMiniBox() {
    const mi = maps.find(m => m.name === curName);
    const bb = document.getElementById("mm-box");
    if (!mi) { bb.style.display = "none"; return; }
    const size = 128;   // fixed display size; `mm` = render surface (128/256)
    const bw = Math.max(3, 128 / mi.w * size), bh = Math.max(3, 128 / mi.h * size);
    const px = player.x / mi.w * size, py = player.y / mi.h * size;
    bb.style.display = "block";
    bb.style.width = bw + "px"; bb.style.height = bh + "px";
    bb.style.left = (px - bw / 2) + "px"; bb.style.top = (py - bh / 2) + "px";
}
async function loadCat(mi) {
    try {
        const res = await fetch("/api/catalog?map=" + encodeURIComponent(mi.name));
        const d = await res.json();
        cat = d.ok ? d.catalog : null;
    } catch (e) { cat = null; }
    renderHud();
}
function loadImg() {
    const mi = maps.find(m => m.name === curName);
    if (!mi) return;
    const s = 1 << z;
    const onload = () => {
        // center world px on stage center (400, 300)
        const cxw = cx * 48 + 24, cyw = cy * 32 + 16;   // rect anchor
        const left = 400 - cxw / s, top = 300 - cyw / s;
        wimg.style.left = left + "px";
        wimg.style.top = top + "px";
        renderHud();
    };
    wimg.onload = onload;
    wimg.src = "/fullmap?map=" + encodeURIComponent(mi.name) + "&z=" + z +
               "&g=" + (document.getElementById("chk-g").checked ? 1 : 0) +
               "&m=" + (document.getElementById("chk-m").checked ? 1 : 0) +
               "&f=" + (document.getElementById("chk-f").checked ? 1 : 0) +
               "&om=" + selOff.value;
}
function loadMini() {
    const mi = maps.find(m => m.name === curName);
    if (!mi) return;
    mimg.src = "/minimap?map=" + encodeURIComponent(mi.name);
    mmName.textContent = (mi.cn || "") + " " + mi.name;
}
function renderHud() {
    const mi = maps.find(m => m.name === curName);
    if (!mi) return;
    hudMap.textContent = (mi.cn || "") + " " + mi.name + " | 中心格 " + cx + "," + cy + " | 缩放 1:" + (1 << z);
    selCell.textContent = cx + "," + cy;
    if (cat) {
        const ev = (cat.evidence && cat.evidence.level) || "derived";
        let s = `主题 ${cat.theme_name || "base"} · ${cat.w}×${cat.h} · ${cat.cell_bytes}B/格 · 证据 ${ev}`;
        const gl = Object.keys(cat.ground || {}).length;
        const ml = Object.keys(cat.mid || {}).length;
        const fl = Object.keys(cat.front || {}).length;
        s += ` · 库 g${gl}/m${ml}/f${fl}`;
        if (cat.animated_cells) s += " · 动画格 " + cat.animated_cells;
        if (target) s += ` · 目标: ${target.kind === "npc" ? "NPC" : target.kind === "monster" ? "怪物" : "玩家"} ${target.name || ""} @${target.x},${target.y}`;
        hudStats.textContent = s;
        hudOob.textContent = cat.anomaly_total ? `⚠ ${cat.anomaly_total} 帧越界 (${Object.keys(cat.anomalies || {}).length} 项)` : "";
    } else {
        hudStats.textContent = "（无 catalog 数据）";
        hudOob.textContent = "";
    }
    const scale = mm === 128 ? "128" : "256";
    mmZoom.textContent = scale;
    document.getElementById("hud").style.display = showHud ? "block" : "none";
}
function move(dx, dy) {
    cx += dx; cy += dy;
    const mi = maps.find(m => m.name === curName);
    if (mi) { cx = Math.max(0, Math.min(cx, mi.w - 1)); cy = Math.max(0, Math.min(cy, mi.h - 1)); }
    loadImg();
    renderEnts();
    updateHash();
}
function updateHash() {
    history.replaceState(null, "", `#sim=${encodeURIComponent(curName)}&c=${cx},${cy}&z=${z}&om=${selOff.value}`);
}
selMap.addEventListener("change", () => { cx = Math.floor((maps.find(m => m.name === selMap.value) || {}).w / 2) || 0;
    cy = Math.floor((maps.find(m => m.name === selMap.value) || {}).h / 2) || 0; pick(selMap.value); });
document.getElementById("chk-g").addEventListener("change", loadImg);
document.getElementById("chk-m").addEventListener("change", loadImg);
document.getElementById("chk-f").addEventListener("change", loadImg);
selOff.addEventListener("change", () => { updateHash(); loadImg(); });
document.getElementById("btn-strip").addEventListener("click", () => {
    const mi = maps.find(m => m.name === curName);
    if (!mi) return;
    const g = document.getElementById("chk-g").checked ? 1 : 0;
    const m = document.getElementById("chk-m").checked ? 1 : 0;
    const f = document.getElementById("chk-f").checked ? 1 : 0;
    window.open("/strip?map=" + encodeURIComponent(mi.name) + "&z=2&g=" + g + "&m=" + m + "&f=" + f, "_blank");
});
function loadThumb() {
    const mi = maps.find(m => m.name === curName);
    const t = document.getElementById("map-thumb");
    if (!mi) { t.style.display = "none"; return; }
    t.src = "/thumb?map=" + encodeURIComponent(mi.name);
    t.style.display = "inline-block";
}
document.getElementById("btn-hud").addEventListener("click", () => { showHud = !showHud; renderHud(); });
document.getElementById("btn-mm").addEventListener("click", () => { mm = mm === 128 ? 256 : 128; renderHud(); });
document.getElementById("btn-back").addEventListener("click", () => { location.href = "/"; });
window.addEventListener("keydown", (e) => {
    const k = e.key;
    if (k === "ArrowLeft" || k === "a" || k === "A") move(-1, 0);
    else if (k === "ArrowRight" || k === "d" || k === "D") move(1, 0);
    else if (k === "ArrowUp" || k === "w" || k === "W") move(0, -1);
    else if (k === "ArrowDown" || k === "s" || k === "S") move(0, 1);
    else if (k === "t" || k === "T") { mm = mm === 128 ? 256 : 128; renderHud(); }
    else if (k === "h" || k === "H") { showHud = !showHud; renderHud(); }
    else return;
    e.preventDefault();
});
window.addEventListener("wheel", (e) => {
    if (!e.ctrlKey) return;
    e.preventDefault();
    const mi = maps.find(m => m.name === curName);
    if (!mi) return;
    const maxZ = mi.ladder.length - 1;
    const minZ = mi.ladder[0] ?? 0;
    if (e.deltaY < 0 && z > minZ) z--;
    else if (e.deltaY > 0 && z < maxZ) z++;
    else return;
    loadImg(); renderEnts(); updateHash();
}, { passive: false });

// hover: cell under cursor -> /api/cell (per-layer file/frame/flag/animation)
const cellInfo = document.getElementById("cell-info");
let cellTimer = null;
wimg.addEventListener("mousemove", (e) => {
    if (!curName) return;
    const s = 1 << z;
    const wx = Math.floor(e.offsetX * s / 48);
    const wy = Math.floor(e.offsetY * s / 32);
    if (wx < 0 || wy < 0) { cellInfo.style.display = "none"; return; }
    clearTimeout(cellTimer);
    cellTimer = setTimeout(async () => {
        try {
            const r = await fetch("/api/cell?map=" + encodeURIComponent(curName) +
                                  "&x=" + wx + "&y=" + wy);
            const d = await r.json();
            if (!d.ok) { cellInfo.style.display = "none"; return; }
            const fmt = (o) => o.frame !== undefined ? `${o.frame}` : "—";
            cellInfo.textContent =
                `格 ${d.x},${d.y}  flag=${d.flag} anim=${d.anim[0]},${d.anim[1]}\n` +
                `Back  : ${d.back.lib} [${d.back.file}] f${fmt(d.back)}\n` +
                `Middle: ${d.mid.lib} [${d.mid.file}] f${fmt(d.mid)}\n` +
                `Front : ${d.front.lib} [${d.front.file}] f${fmt(d.front)}`;
            cellInfo.style.left = Math.min(e.clientX + 14, window.innerWidth - 260) + "px";
            cellInfo.style.top = Math.max(6, e.clientY - 90) + "px";
            cellInfo.style.display = "block";
        } catch (_) { cellInfo.style.display = "none"; }
    }, 60);
});
wimg.addEventListener("mouseleave", () => { cellInfo.style.display = "none"; });
init();
</script>
</body>
</html>
"""

HTML_TEMPLATE = """<!DOCTYPE html>
<html lang="zh-CN">
<head>
    <meta charset="utf-8">
    <meta name="viewport" content="width=device-width, initial-scale=1, viewport-fit=cover">
    <title>Zircon / Mir3 EI 地图浏览器</title>
    <link rel="stylesheet" href="/_webui/tokens.css">
    <link rel="stylesheet" href="/_webui/mobile-shell.css">
    <style>
        body { margin:0; padding:0; background:#111; color:#eee; font-family:sans-serif; overflow:hidden; user-select:none; }
        #toolbar { height:40px; background:#222; display:flex; align-items:center; padding:0 10px; gap:10px; border-bottom:1px solid #333; }
        #toolbar button { font-size:13px; padding:4px 8px; }
        .tb-ico { min-width:30px !important; width:30px; height:28px; padding:0 !important;
            display:inline-flex; align-items:center; justify-content:center; border-radius:4px; }
        #toolbar label { font-size:12px; gap:3px; display:inline-flex; align-items:center; }
        #map-sel-btn { max-width:220px; }
        #viewport { position:absolute; top:40px; left:0; right:0; bottom:0; overflow:auto; background:#0b0b0f; cursor:grab; }
        #viewport.dragging { cursor:grabbing; }
        #map-img { display:block; background:#000; }
        #grid-canvas { position:absolute; top:40px; left:0; pointer-events:none; }
        #route-svg { position:absolute; pointer-events:none; z-index:4; overflow:visible; }
        #ent-layer { position:absolute; pointer-events:none; z-index:5; overflow:visible; }
        #tile-layer { position:absolute; left:0; top:0; z-index:1; pointer-events:none; }
        #tile-layer img { position:absolute; image-rendering:pixelated; }
        #ent-layer .ent { position:absolute; transform:translate(-50%,-100%); text-align:center; cursor:default; }
        #ent-layer .ent .ent-icon { display:block; width:28px; height:28px; margin:0 auto; image-rendering:pixelated; }
        #ent-layer .ent .ent-icon.hide { display:none; }
        #ent-layer .ent .ent-sprite { display:block; margin:0 auto; image-rendering:pixelated;
            filter:drop-shadow(0 2px 3px rgba(0,0,0,.55)); }
        #ent-layer .ent.target .ent-sprite { filter:drop-shadow(0 0 0 2px #ffd23d) drop-shadow(0 0 8px #ffd23d); }
        #ent-layer .ent .ent-label { font-size:11px; color:#fff; text-shadow:0 1px 2px #000, 0 0 3px #000; background:rgba(0,0,0,.45); border-radius:2px; padding:0 3px; white-space:nowrap; }
        #ent-layer .ent.spawn .ent-icon { filter:drop-shadow(0 0 3px rgba(255,213,74,.9)); }
        #ent-layer .ent.npc .ent-label { color:#8cf; }
        #ent-layer .ent.spawn .ent-label { color:#ffd54a; }
        #ent-layer .ent.target .ent-icon { box-shadow:0 0 0 3px #ffd23d, 0 0 10px #ffd23d !important; }
        #ent-layer .ent.target .ent-label { color:#ffd23d; background:rgba(64,48,0,.75); }
        #cat-panel { position:fixed; left:10px; bottom:10px; width:330px; max-height:46vh; overflow:auto;
            background:rgba(10,12,16,.92); border:1px solid #3a3a46; border-radius:6px; padding:8px 10px;
            font-size:12px; color:#c8c8d2; z-index:60; display:none; line-height:1.45; }
        #cat-panel h4 { margin:0 0 6px; font-size:13px; color:#ffd54a; }
        #cat-panel .row { display:flex; justify-content:space-between; gap:10px; }
        #cat-panel .k { color:#8a8a98; }
        #cat-panel .v { color:#e8e8f0; font-family:ui-monospace,monospace; }
        #cat-panel .warn { color:#ff8f6b; }
        #cat-panel .lib { font-family:ui-monospace,monospace; }
        #cat-panel .lib .oob { color:#ff8f6b; }
        #cat-panel::-webkit-scrollbar { width:8px; } #cat-panel::-webkit-scrollbar-thumb { background:#3a3a44; border-radius:4px; }
        #conn-panel { position:fixed; left:10px; top:50px; width:300px; max-height:60vh; overflow:auto;
            background:rgba(10,12,16,.92); border:1px solid #3a3a46; border-radius:6px; padding:8px 10px;
            font-size:12px; color:#c8c8d2; z-index:70; display:none; line-height:1.5; }
        #conn-panel h4 { margin:0 0 6px; font-size:13px; color:#3de88a; }
        #conn-panel .conn-row { display:flex; gap:8px; align-items:baseline; padding:2px 0; }
        #conn-panel .conn-row.link { cursor:pointer; }
        #conn-panel .conn-row.link:hover { background:#2a2e38; border-radius:3px; }
        #conn-panel .conn-name { color:#e8e8f0; flex:1; overflow:hidden; text-overflow:ellipsis; white-space:nowrap; }
        #cat-panel { position:fixed; left:10px; bottom:10px; width:330px; max-height:46vh; overflow:auto;
            background:rgba(10,12,16,.92); border:1px solid #3a3a46; border-radius:6px; padding:8px 10px;
            font-size:12px; color:#c8c8d2; z-index:60; display:none; line-height:1.45; }
        #ent-layer .ent.npc .ent-icon { filter:drop-shadow(0 0 3px rgba(114,214,255,.8)); }
        #conn-panel { position:fixed; left:10px; top:50px; width:300px; max-height:60vh; overflow:auto;
            background:rgba(10,12,16,.92); border:1px solid #3a3a46; border-radius:6px; padding:8px 10px;
            font-size:12px; color:#c8c8d2; z-index:70; display:none; line-height:1.5; }
        #conn-panel .conn-dir { color:#ffd54a; font-family:ui-monospace,monospace; font-size:11px; }
        #conn-panel .conn-file { color:#6a6a75; font-family:ui-monospace,monospace; font-size:11px; }
        #conn-panel .conn-empty { color:#6a6a75; }
        #conn-panel::-webkit-scrollbar { width:8px; } #conn-panel::-webkit-scrollbar-thumb { background:#3a3a44; border-radius:4px; }
        /* 右侧面板列：小地图(#minimap) 与状态栏之间，NPC 面板贴底、刷新面板在其上 */
        #right-panels { position:fixed; right:10px; bottom:44px; top:212px; display:flex; flex-direction:column;
            justify-content:flex-end; gap:8px; z-index:70; pointer-events:none; }
        #right-panels > div { pointer-events:auto; min-height:0; }
        #npc-panel { position:static; width:280px; max-height:42vh; overflow:auto; flex-shrink:1;
            background:rgba(10,12,16,.92); border:1px solid #3a3a46; border-radius:6px; padding:8px 10px;
            font-size:12px; color:#c8c8d2; display:none; line-height:1.5; }
        #npc-panel h4 { margin:0 0 6px; font-size:13px; color:#8cf; }
        #npc-panel .npc-row { display:flex; gap:8px; align-items:baseline; padding:2px 0; cursor:pointer; }
        #npc-panel .npc-row:hover { background:#2a2e38; border-radius:3px; }
        #npc-panel .npc-name { color:#e8e8f0; flex:1; overflow:hidden; text-overflow:ellipsis; white-space:nowrap; }
        #npc-panel .npc-xy { color:#8cf; font-family:ui-monospace,monospace; font-size:11px; }
        #npc-panel .npc-en { display:block; color:#6a6a75; font-size:10px; }
        #npc-panel .npc-empty { color:#6a6a75; }
        #npc-panel::-webkit-scrollbar { width:8px; } #npc-panel::-webkit-scrollbar-thumb { background:#3a3a44; border-radius:4px; }
        #resp-panel { position:static; width:280px; max-height:42vh; overflow:auto; flex-shrink:1;
            background:rgba(10,12,16,.92); border:1px solid #3a3a46; border-radius:6px; padding:8px 10px;
            font-size:12px; color:#c8c8d2; display:none; line-height:1.5; }
        #resp-panel h4 { margin:0 0 6px; font-size:13px; color:#ff9b6b; }
        #resp-panel .resp-row { display:flex; gap:8px; align-items:baseline; padding:2px 0; cursor:pointer; }
        #resp-panel .resp-row:hover { background:#2a2e38; border-radius:3px; }
        #resp-panel .resp-name { color:#e8e8f0; flex:1; overflow:hidden; text-overflow:ellipsis; white-space:nowrap; }
        #resp-panel .resp-meta { color:#ffd54a; font-family:ui-monospace,monospace; font-size:11px; }
        #resp-panel .resp-xy { color:#6a6a75; font-family:ui-monospace,monospace; font-size:11px; }
        #resp-panel .resp-empty { color:#6a6a75; }
        #resp-panel::-webkit-scrollbar { width:8px; } #resp-panel::-webkit-scrollbar-thumb { background:#3a3a44; border-radius:4px; }
        #info { font-size:12px; color:#aaa; white-space:nowrap; }
        #status { margin-left:auto; font-size:12px; color:#e90; white-space:nowrap; }
        button { font-size:14px; min-width:32px; padding:4px 9px; white-space:nowrap; cursor:pointer; background:#333; color:#eee; border:1px solid #555; border-radius:3px; }
        button:disabled { opacity:.35; cursor:default; }
        label { font-size:13px; cursor:pointer; white-space:nowrap; }
        #minimap { position:fixed; top:48px; right:10px; background:rgba(0,0,0,.75); border:1px solid #444; border-radius:4px; padding:4px; z-index:50; box-shadow:0 2px 8px rgba(0,0,0,.5); }
        #minimap .mm-title { font-size:11px; color:#aaa; margin-bottom:3px; }
        #mm-box { position:relative; cursor:crosshair; }
        #mm-img { display:block; width:172px; background:#000; border-radius:2px; }
        #mm-rect { position:absolute; border:1.5px solid #ffd54a; background:rgba(255,213,74,.10); pointer-events:none; }
        #statusbar { position:fixed; right:10px; bottom:8px; background:rgba(0,0,0,.78); border:1px solid #3a3a46;
            border-radius:5px; padding:5px 11px; font-size:12px; color:#c8c8d2; z-index:90; display:flex; gap:14px;
            font-family:ui-monospace,monospace; pointer-events:none; }
        #statusbar #coord-info { color:#8cf; }
        #statusbar #zoom-info { color:#ffd54a; }
        #statusbar #map-info { color:#9a9; }
        #legend-panel { position:fixed; left:10px; bottom:38px; background:rgba(10,12,16,.92); border:1px solid #3a3a46;
            border-radius:6px; padding:9px 12px; font-size:12px; color:#c8c8d2; z-index:80; line-height:1.7; }
        #legend-panel .lg-row { display:flex; align-items:center; gap:8px; }
        #legend-panel .lg-dot { width:11px; height:11px; border-radius:50%; display:inline-block; }
        #port-tooltip { position:fixed; background:rgba(10,12,16,.95); border:1px solid #3de88a; border-radius:6px;
            padding:8px 10px; font-size:12px; color:#e8e8f0; z-index:120; pointer-events:none; max-width:240px; line-height:1.5;
            box-shadow:0 4px 16px rgba(0,0,0,.6); }
        #port-tooltip img { display:block; max-width:200px; margin:4px auto 0; border-radius:3px; border:1px solid #333; }
        #ent-tooltip { position:fixed; background:rgba(10,12,16,.95); border:1px solid #72d6ff; border-radius:5px;
            padding:5px 9px; font-size:12px; color:#cfe; z-index:120; pointer-events:none; box-shadow:0 3px 12px rgba(0,0,0,.6); }
        /* custom map selector */
        #resp-panel::-webkit-scrollbar { width:8px; } #resp-panel::-webkit-scrollbar-thumb { background:#3a3a44; border-radius:4px; }
        /* 面板拖拽：标题即手柄；拖拽中半透明浮起 */
        #npc-panel h4, #resp-panel h4, #conn-panel h4, #cat-panel h4,
        #quest-panel h4, #legend-panel h4, #minimap .mm-title { cursor:move; user-select:none; }
        #npc-panel h4::after, #resp-panel h4::after, #conn-panel h4::after,
        #cat-panel h4::after, #quest-panel h4::after, #legend-panel h4::after {
            content:" ⠿"; color:#55555f; font-size:10px; }
        .panel-dragging { opacity:.85 !important; box-shadow:0 10px 28px rgba(0,0,0,.65) !important; }
        /* 传送点详情弹窗（两段式点击：选中 → 对面小地图 → 再点跳转） */
        #port-detail { position:fixed; z-index:95; width:208px; cursor:pointer;
            background:rgba(10,12,16,.94); border:1px solid #3a3a46; border-radius:6px;
            padding:8px; font-size:12px; color:#c8c8d2; line-height:1.45; }
        #port-detail .pd-head { color:#3de88a; font-weight:700; margin-bottom:4px; }
        #port-detail .pd-close { float:right; color:#888; padding:0 3px; }
        #port-detail .pd-close:hover { color:#fff; }
        #port-detail img { width:100%; border-radius:4px; display:block; margin:4px 0; background:#000; }
        #port-detail .pd-meta { color:#8a8a98; font-family:ui-monospace,monospace; font-size:11px; }
        #map-sel-btn { background:#2b2b31; color:#eee; border:1px solid #4a4a55; border-radius:4px; padding:4px 9px; cursor:pointer; font-size:13px; }
        #port-detail { position:fixed; z-index:9000; width:208px; cursor:pointer;
            background:rgba(10,12,16,.94); border:1px solid #3a3a46; border-radius:6px;
            padding:8px; font-size:12px; color:#c8c8d2; line-height:1.45; }
        #map-sel-label { flex:1; overflow:hidden; text-overflow:ellipsis; white-space:nowrap; text-align:left; }
        .msel { position:relative; }
        #map-sel-filter { width:100%; box-sizing:border-box; padding:7px 9px; background:#1c1c21; color:#eee;
            border:none; border-bottom:1px solid #3a3a44; outline:none; font-size:13px; }
        .msel-tabs { display:flex; gap:4px; padding:6px 8px 4px; flex-wrap:wrap; background:#1e1e24; border-bottom:1px solid #2e2e36; }
        .msel-tab { font-size:11px !important; padding:3px 8px !important; min-width:0 !important; height:auto !important;
            border-radius:10px; background:#26262c; border:1px solid #3a3a44; color:#9a9aa5; }
        .msel-tab.active { background:#2f6a44; border-color:#3de88a; color:#d2ffe4; }
        .msel-tab i { font-style:normal; opacity:.65; font-size:10px; }
        .msel-npcdot { width:6px; height:6px; border-radius:50%; background:#3de88a; display:inline-block;
            box-shadow:0 0 4px #3de88a; flex:none; align-self:center; }
        .msel-pop { position:absolute; top:calc(100% + 4px); left:0; min-width:280px; max-width:380px; background:#232329;
            border:1px solid #4a4a55; border-radius:6px; box-shadow:0 8px 24px rgba(0,0,0,.6); z-index:10000; overflow:hidden; }
        #map-sel-filter { width:100%; box-sizing:border-box; padding:7px 9px; background:#1c1c21; color:#eee;
            border:none; border-bottom:1px solid #3a3a44; outline:none; font-size:13px; }
        #map-sel-filter::placeholder { color:#6a6a75; }
        .msel-list { max-height:340px; overflow-y:auto; }
        .msel-item { padding:6px 10px; cursor:pointer; font-size:13px; color:#d5d5dd; display:flex; gap:8px; align-items:baseline; }
        .msel-item .msel-cn { color:#9a9aa5; }
        .msel-item:hover, .msel-item.active { background:#3a3a44; color:#fff; }
        .msel-item.empty { color:#6a6a75; cursor:default; }
        .msel-item.empty:hover { background:none; }
        .msel-cat { padding:5px 12px 3px; font-size:11px; color:#8bc34a; font-weight:600; border-bottom:1px solid #2e2e36; background:#1e1e24; position:sticky; top:0; }
        .msel-list::-webkit-scrollbar { width:8px; }
        .msel-list::-webkit-scrollbar-thumb { background:#3a3a44; border-radius:4px; }

        /* Toast Notifications */
        #toast-container { position:fixed; top:54px; right:20px; z-index:999999; display:flex; flex-direction:column; gap:10px; pointer-events:none; }
        .toast { pointer-events:auto; background:rgba(22, 26, 36, 0.95); border:1px solid #3de88a; border-left:4px solid #3de88a; border-radius:6px; padding:12px 16px; box-shadow:0 8px 24px rgba(0,0,0,0.5); backdrop-filter:blur(8px); min-width:280px; max-width:420px; transform:translateX(120%); transition:transform 0.35s cubic-bezier(0.18, 0.89, 0.32, 1.28), opacity 0.35s; opacity:0; }
        .toast.show { transform:translateX(0); opacity:1; }
        .toast-title { font-size:14px; font-weight:600; color:#3de88a; margin-bottom:4px; display:flex; align-items:center; gap:6px; }
        .toast-body { font-size:12px; color:#c5c5d0; line-height:1.4; word-break:break-all; }

        /* Custom Modal Dialog */
        #custom-modal-overlay { display:none; position:fixed; top:0; left:0; width:100vw; height:100vh; background:rgba(0,0,0,0.7); backdrop-filter:blur(4px); z-index:999999; align-items:center; justify-content:center; }
        .modal-card { background:#1e222d; border:1px solid #3de88a; border-radius:8px; width:400px; max-width:90vw; padding:20px; box-shadow:0 12px 32px rgba(0,0,0,0.7); display:flex; flex-direction:column; gap:14px; }
        .modal-header { font-size:16px; font-weight:600; color:#3de88a; display:flex; align-items:center; gap:8px; }
        .modal-body { font-size:13px; color:#ccc; line-height:1.5; }
        .modal-actions { display:flex; justify-content:flex-end; gap:10px; margin-top:6px; }
        .btn-modal { padding:6px 16px; font-size:13px; border-radius:4px; cursor:pointer; font-weight:500; }
        .btn-modal-cancel { background:#2a2e3a; color:#aaa; border:1px solid #444; }
        .btn-modal-cancel:hover { background:#343948; color:#eee; }
        .btn-modal-confirm { background:#183828; color:#85ffc7; border:1px solid #3de88a; }
        .btn-modal-confirm:hover { background:#1f4834; }

        /* Spinner & Overlay */
        @keyframes spin { 0% { transform:rotate(0deg); } 100% { transform:rotate(360deg); } }
        #loading-overlay { display:none; position:fixed; top:0; left:0; width:100vw; height:100vh;
            background:rgba(12, 14, 18, 0.85); backdrop-filter:blur(6px); -webkit-backdrop-filter:blur(6px);
            z-index:99999; flex-direction:column; align-items:center; justify-content:center; color:#fff; }
        .spinner { width:52px; height:52px; border:4px solid rgba(61,232,138,0.15); border-top-color:#3de88a;
            border-radius:50%; animation:spin 0.8s linear infinite; box-shadow:0 0 16px rgba(61,232,138,0.3); }

        /* ---- 地图工坊六大增强 ---- */
        #view-tabs { display:flex; gap:2px; background:#1a1a20; border:1px solid #3a3a46; border-radius:5px; padding:2px; }
        .vtab { font-size:12px; min-width:0; padding:3px 9px; border-radius:4px; background:transparent; border:none; color:#9a9aa5; }
        .vtab.active { background:#2f6a44; color:#d2ffe4; }
        #heat-canvas { position:absolute; top:0; left:0; pointer-events:none; z-index:3; }
        #quest-svg, #pick-svg { position:absolute; left:0; top:0; pointer-events:none; z-index:4; overflow:visible; }
        #route-svg circle.port { pointer-events:auto; cursor:pointer; }   /* 父层 pointer-events:none 会继承，出口圆点需显式恢复 */
        @keyframes qpulse { 0% { r:6; opacity:1; } 50% { r:11; opacity:.55; } 100% { r:6; opacity:1; } }
        #quest-svg circle.qkill { animation:qpulse 1.2s ease-in-out infinite; }
        #heat-tooltip { position:fixed; background:rgba(10,12,16,.95); border:1px solid #ff8f6b; border-radius:6px;
            padding:6px 9px; font-size:12px; color:#ffe; z-index:130; pointer-events:none; max-width:280px;
            line-height:1.6; box-shadow:0 4px 16px rgba(0,0,0,.6); display:none; }
        #quest-panel { position:fixed; right:10px; top:250px; width:250px; max-height:44vh; overflow:auto;
            background:rgba(10,12,16,.92); border:1px solid #ffd54a; border-radius:6px; padding:8px 10px;
            font-size:12px; color:#c8c8d2; z-index:75; display:none; line-height:1.5; }
        #quest-panel h4 { margin:0 0 6px; font-size:13px; color:#ffd54a; }
        #quest-panel .qstep { margin:4px 0; padding:4px 6px; border-left:3px solid #555; background:#171922; border-radius:3px; }
        #quest-panel .qstep.kill { border-color:#ff5b5b; }
        #quest-panel .qstep.visit { border-color:#ffd54a; }
        #quest-panel .qstep.item { border-color:#e8963d; }
        #quest-panel .qstep.current { background:#26314a; border-left-color:#72d6ff; box-shadow:0 0 0 1px #72d6ff inset; }
        #quest-panel .qstep .qplay { float:right; background:#1d3a4a; border:1px solid #72d6ff; color:#cfe;
            border-radius:3px; cursor:pointer; font-size:11px; padding:1px 7px; }
        #quest-panel .qstep .qplay:hover { background:#2a4a5e; }
        #quest-panel .qnav { display:flex; gap:6px; margin:8px 0 4px; }
        #quest-panel .qnav button { flex:1; font-size:12px; padding:4px 0; }
        #quest-panel .qmap { color:#8cf; cursor:pointer; text-decoration:underline; padding:1px 0; display:inline-block; }
        #quest-panel .qmap:hover { color:#bff; }
        #pick-panel { position:fixed; left:10px; bottom:64px; background:rgba(10,12,16,.93); border:1px solid #72d6ff;
            border-radius:6px; padding:8px 12px; font-size:13px; color:#cfe; z-index:85; display:none;
            font-family:ui-monospace,monospace; line-height:1.7; box-shadow:0 4px 12px rgba(0,0,0,.5); }
        #pick-panel .pick-copy { font-size:12px; padding:2px 10px; margin-left:8px; background:#1d3a4a; border-color:#72d6ff; color:#cfe; }
        #pick-panel .pick-dist { color:#ffd54a; }
        #pick-panel .pick-hint { color:#6a6a75; font-size:11px; }
        #overview-view, #graph-view { position:absolute; top:40px; left:0; right:0; bottom:0; overflow:auto;
            background:#0b0b0f; display:none; padding:12px; }
        #ov-filters { display:flex; gap:6px; flex-wrap:wrap; align-items:center; margin-bottom:10px; position:sticky; top:0;
            background:#0b0b0f; padding:6px 0; z-index:5; }
        .ov-chip { font-size:12px; padding:3px 11px; border-radius:12px; background:#232329; color:#aaa;
            border:1px solid #3a3a46; cursor:pointer; }
        .ov-chip.active { background:#2f6a44; color:#d2ffe4; border-color:#3de88a; }
        #ov-grid { display:grid; grid-template-columns:repeat(auto-fill, minmax(148px, 1fr)); gap:10px; }
        .ov-card { background:#15161c; border:1px solid #2a2b33; border-radius:6px; overflow:hidden; cursor:pointer; }
        .ov-card:hover { border-color:#5a8f6a; }
        .ov-thumb { position:relative; aspect-ratio:4/3; background:#0d0e12; display:flex; align-items:center;
            justify-content:center; overflow:hidden; }
        .ov-thumb img { width:100%; height:100%; object-fit:contain; image-rendering:pixelated; }
        .ov-thumb .ph { color:#3c3d46; font-size:22px; }
        .ov-thumb .ov-crown { position:absolute; top:3px; right:5px; font-size:14px; text-shadow:0 1px 2px #000; }
        .ov-thumb .ov-nofile { position:absolute; bottom:2px; left:4px; font-size:10px; color:#e8963d; }
        .ov-name { font-size:12px; color:#e8e8f0; padding:4px 7px 1px; white-space:nowrap; overflow:hidden; text-overflow:ellipsis; }
        .ov-name .ov-id { color:#6a6a75; font-family:ui-monospace,monospace; font-size:10px; }
        .ov-meta { font-size:10.5px; color:#8a8a98; padding:0 7px 5px; }
        .ov-meta .lv { font-weight:600; }
        .tier-low { color:#8fce8f; } .tier-mid { color:#e8d95a; } .tier-high { color:#f0a05a; }
        .tier-max { color:#f07575; } .tier-none { color:#7a7a85; }
        .ov-card .ov-bar { height:3px; }
        .bar-low { background:#7a9a78; } .bar-mid { background:#d9c34a; } .bar-high { background:#e8963d; }
        .bar-max { background:#e05555; } .bar-none { background:#3a3a44; }
        #ov-audit { margin-top:16px; }
        #ov-audit h3 { color:#3de88a; font-size:14px; margin:12px 0 6px; }
        #audit-table { width:100%; border-collapse:collapse; font-size:12px; background:#13141a; border-radius:6px; }
        #audit-table th, #audit-table td { padding:5px 9px; border-bottom:1px solid #23242c; text-align:left; }
        #audit-table th { color:#8a8a98; font-weight:600; position:sticky; top:0; background:#1a1b22; }
        .audit-miss { color:#ff5b5b; font-weight:700; }
        .audit-ok { color:#8fce8f; }
        #graph-view svg { display:block; }
        #graph-stats { font-size:12px; color:#8a8a98; margin-bottom:6px; }
        #graph-stats b { color:#e8e8f0; }
        #graph-stats .g-isl { color:#ff5b5b; } #graph-stats .g-cut { color:#ffd54a; }
        .gnode { cursor:pointer; } .gnode text { font-size:9px; fill:#9a9aa5; paint-order:stroke; stroke:#0b0b0f; stroke-width:2px; }
        #legend-panel .lg-block { display:inline-block; width:14px; height:9px; border-radius:2px; margin-right:6px; vertical-align:middle; }
        /* ---- 移动端共享壳接入（桌面 fine-pointer/宽屏零影响，Goal MAP-P0-01） ---- */
        #layer-group { display:contents; }            /* 桌面：包裹不改变工具栏 flex 布局 */
        #layer-group .lg-title { display:none; }
        #btn-layers { display:none; }
        @media (max-width:640px) {
            html, body { height:100%; }
            body { display:flex; flex-direction:column; height:100dvh; }
            #toolbar { position:static; height:auto; min-height:44px; flex:none; order:0;
                       flex-wrap:wrap; padding:6px 8px; gap:6px 8px; }
            #map-lbl { display:none; }
            #viewport, #overview-view, #graph-view {
                position:relative; top:auto; left:auto; right:auto; bottom:auto;
                flex:1 1 auto; order:1; min-height:0;
                margin-bottom:calc(54px + var(--safe-bottom,0px));
            }
            /* 视图切换 → 底部导航（≥44px 触控目标） */
            #view-tabs { position:fixed; left:0; right:0; bottom:0; z-index:95; margin:0;
                         background:rgba(16,18,24,.97); border-top:1px solid #3a3a46;
                         border-radius:0; padding:4px 6px calc(4px + var(--safe-bottom,0px)); }
            .vtab { flex:1; min-height:48px; font-size:13px; border-radius:8px; }
            /* 图层/任务/图例控件 → 底部抽屉 */
            #btn-layers { display:inline-flex; align-items:center; gap:4px; }
            #layer-group { display:none; position:fixed; left:0; right:0; bottom:0; z-index:96;
                           max-height:70dvh; overflow-y:auto; flex-wrap:wrap; gap:8px 10px; align-items:center;
                           background:rgba(16,18,24,.98); border-top:1px solid #3a3a46;
                           border-radius:14px 14px 0 0; padding:12px 14px calc(14px + var(--safe-bottom,0px)); }
            #layer-group.open { display:flex; }
            #layer-group .lg-title { display:block; flex-basis:100%; color:#ffd54a; font-size:13px; }
            .msel-pop { min-width:240px; max-width:calc(100vw - 24px); }
            /* 固定面板收口：不允许超出 390px 视口 */
            #cat-panel, #conn-panel, #quest-panel, #legend-panel, #pick-panel, #statusbar {
                max-width:calc(100vw - 20px); }
            #right-panels { left:8px; right:8px; top:auto; bottom:calc(60px + var(--safe-bottom,0px)); max-height:40dvh; }
            #npc-panel, #resp-panel { width:auto; }
            #legend-panel{ bottom:calc(60px + var(--safe-bottom,0px)); }
            #pick-panel  { bottom:calc(60px + var(--safe-bottom,0px)); }
            #conn-panel  { top:calc(52px + var(--safe-top,0px)); }
            #quest-panel { top:auto; right:8px; bottom:calc(60px + var(--safe-bottom,0px)); max-height:40dvh; }
            #statusbar   { bottom:calc(58px + var(--safe-bottom,0px)); right:8px; flex-wrap:wrap; gap:4px 10px; }
            #toast-container { top:calc(52px + var(--safe-top,0px)); right:8px; left:8px; }
            .toast { min-width:0; max-width:100%; }
            #minimap { display:none; }
            #overview-view { padding:6px; }
            #ov-grid { grid-template-columns:repeat(auto-fill, minmax(108px, 1fr)); gap:6px; }
        }
        @media (pointer:coarse) {
            #viewport { touch-action:none; }   /* 手势由 gesture.js 接管（MAP-P0-02） */
            #toolbar button, #toolbar select { min-height:44px; }
            #toolbar label { min-height:44px; display:inline-flex; align-items:center; padding:0 6px; }
            .ov-chip { min-height:40px; display:inline-flex; align-items:center; }
        }
    </style>
</head>
<body class="wu-shell">
    <!-- Toast 通知容器 -->
    <div id="toast-container"></div>

    <!-- 自定义 Modal 对话框 -->
    <div id="custom-modal-overlay">
        <div class="modal-card">
            <div class="modal-header" id="modal-title">⚡ 提示</div>
            <div class="modal-body" id="modal-msg">确定要进行此操作吗？</div>
            <div class="modal-actions">
                <button class="btn-modal btn-modal-cancel" id="btn-modal-cancel">取消</button>
                <button class="btn-modal btn-modal-confirm" id="btn-modal-confirm">确认</button>
            </div>
        </div>
    </div>

    <!-- 全屏客户端切换加载蒙版遮罩 -->
    <div id="loading-overlay">
        <div class="spinner"></div>
        <div id="loading-title" style="margin-top:18px; font-size:17px; font-weight:600; color:#3de88a; letter-spacing:0.5px;">正在切换客户端资源库…</div>
        <div id="loading-detail" style="margin-top:8px; font-size:13px; color:#aaa; font-family:monospace;">正在加载新客户端数据...</div>
    </div>

    <div id="toolbar">
        <div id="view-tabs" title="视图切换">
            <button class="vtab active" data-view="map" type="button">地图</button>
            <button class="vtab" data-view="overview" type="button">总览</button>
            <button class="vtab" data-view="graph" type="button">连通</button>
        </div>
        <div class="msel" id="map-sel">
            <button id="map-sel-btn" type="button" title="选择地图">
                <span id="map-sel-label">加载中…</span><span class="msel-caret">▾</span>
            </button>
            <div class="msel-pop" id="map-sel-pop" hidden>
                <div class="msel-tabs" id="msel-tabs"></div>
                <input id="map-sel-filter" type="text" placeholder="搜索地图文件名或中文名…" autocomplete="off">
                <div class="msel-list" id="map-sel-list"></div>
            </div>
        </div>
        <button id="btn-zoom-out" class="tb-ico" title="缩小 (-)">－</button>
        <button id="btn-zoom-in" class="tb-ico" title="放大 (+)">＋</button>
        <button id="btn-fit" class="tb-ico" title="适配全图窗口大小">⛶</button>
        <button id="btn-layers" class="tb-ico" type="button" title="图层与叠加">☰</button>
        <div id="layer-group">
            <div class="lg-title">图层 / 叠加</div>
        <label title="地面层"><input type="checkbox" id="chk-g" checked> 底</label>
        <label title="中层"><input type="checkbox" id="chk-m" checked> 中</label>
        <label title="前景层"><input type="checkbox" id="chk-f" checked> 前</label>
        <label><input type="checkbox" id="chk-grid"> 网格</label>
        <label><input type="checkbox" id="chk-ents" checked title="显示 NPC/卫士/传送点"> NPC</label>
        <label><input type="checkbox" id="chk-resp" title="怪物刷新热力图层"> 刷怪</label>
        <select id="quest-sel" title="任务叠加模式" style="max-width:150px; font-size:12px; background:#2b2b31; color:#eee; border:1px solid #4a4a55; border-radius:4px; padding:3px 5px;">
            <option value="">📜 任务叠加…</option>
        </select>
        <button id="btn-legend" class="tb-ico" title="图例说明">❓</button>
        </div>
        <span id="status"></span>

        <!-- 后台预生成实时进度条 -->
        <div id="progress-box" style="display:none; background:#141d18; border:1px solid #3de88a; border-radius:6px; padding:3px 10px; font-size:12px; color:#3de88a; align-items:center; gap:8px;">
            <span>⚡ 预生成:</span>
            <div style="width:140px; height:8px; background:#2a2e38; border-radius:4px; overflow:hidden;">
                <div id="progress-bar-fill" style="width:0%; height:100%; background:linear-gradient(90deg, #3de88a, #e8a33d); transition:width 0.3s;"></div>
            </div>
            <span id="progress-text" style="font-family:monospace;">0% (0/0)</span>
        </div>

        <button id="btn-clear-cache" class="tb-ico" style="background:#4a2e18; border-color:#e8a33d; color:#ffd899;" title="清除全部缓存并重新生成">🔄</button>
    </div>
    <div id="layer-backdrop" class="wu-backdrop"></div>
    <div id="viewport"><img id="map-img" draggable="false" alt=""><div id="tile-layer"></div><svg id="route-svg" aria-hidden="true"></svg><canvas id="heat-canvas" width="0" height="0"></canvas><svg id="quest-svg" aria-hidden="true"></svg><svg id="pick-svg" aria-hidden="true"></svg><canvas id="grid-canvas" width="0" height="0"></canvas><div id="ent-layer"></div></div>
    <div id="overview-view">
        <div id="ov-filters">
            <span style="color:#8a8a98;">📋 全库地图总览</span>
            <span class="ov-chip active" data-f="all">全部</span>
            <span class="ov-chip" data-f="town">城镇</span>
            <span class="ov-chip" data-f="cave">洞穴</span>
            <span class="ov-chip" data-f="boss">👑 BOSS</span>
            <span class="ov-chip" data-f="hasmob">有怪</span>
            <span class="ov-chip active" data-c="lvl">按等级染色</span>
            <span class="ov-chip" data-c="npc">按 NPC 数染色</span>
        </div>
        <div id="ov-grid"></div>
        <div id="ov-audit"><h3>🏪 NPC 功能覆盖审计</h3><div id="audit-table-box">加载中…</div></div>
    </div>
    <div id="graph-view">
        <div id="graph-stats">加载连通图谱中…</div>
        <div id="graph-box"></div>
    </div>
    <div id="cat-panel"></div>
    <div id="conn-panel"></div>
    <div id="right-panels">
        <div id="resp-panel"></div>
        <div id="npc-panel"></div>
    </div>
    <div id="minimap">
        <div class="mm-title">全图</div>
        <div id="mm-box"><img id="mm-img" draggable="false" alt=""><div id="mm-rect" style="display:none"></div></div>
    </div>
    <div id="statusbar"><span id="coord-info"></span><span id="zoom-info"></span><span id="map-info"></span></div>
    <div id="legend-panel" style="display:none"></div>
    <div id="port-detail" style="display:none"></div>
    <div id="port-tooltip" style="display:none"></div>
    <div id="ent-tooltip" style="display:none"></div>
    <div id="heat-tooltip"></div>
    <div id="quest-panel"></div>
    <div id="pick-panel"></div>
    <script>

        // Static full-map viewer: the server pre-renders the whole map at each
        // zoom ladder level once (disk-cached JPEG); the browser only displays
        // images. No tile requests, no canvas compositing.
        const vp = document.getElementById("viewport");
        const imgEl = document.getElementById("map-img");
        const mselBtn = document.getElementById("map-sel-btn");
        const mselLabel = document.getElementById("map-sel-label");
        const mselPop = document.getElementById("map-sel-pop");
        const mselFilter = document.getElementById("map-sel-filter");
        const mselList = document.getElementById("map-sel-list");
        const infoEl = document.getElementById("map-info");
        const statusEl = document.getElementById("status");
        const mmImg = document.getElementById("mm-img");
        const mmBox = document.getElementById("mm-box");
        const mmRect = document.getElementById("mm-rect");

        let maps = [], cur = -1, scaleLadder = [0,1,2,3,4,5,6,7], worldW = 0, worldH = 0;
        const MAP_CN = /*__MAP_CN__*/;
        let version = 0;            // render generation; ignore stale loads
        let anchorX = 0, anchorY = 0; // world px at viewport center
        let dragging = false, dragX = 0, dragY = 0, scX = 0, scY = 0;
        let miniReady = false, miniDrag = false;
        let tileLayer = document.getElementById("tile-layer");

        let curName = null;
        const curMap = () => maps.find(m => m.name === curName);
        const curZ = () => scaleLadder[cur];
        const curScale = () => 1 << curZ();
        const isTileMode = () => curZ() <= 1;   // 1:1 / 1:2 -> tiles; 1:4+ -> fullmap
        const gOn = () => document.getElementById("chk-g").checked ? 1 : 0;
        const mOn = () => document.getElementById("chk-m").checked ? 1 : 0;
        const fOn = () => document.getElementById("chk-f").checked ? 1 : 0;

        function fmt(mi, z) {
            const s = 1 << z;
            const iw = Math.ceil(worldW / s), ih = Math.ceil(worldH / s);
            return (mi.cn ? mi.cn + " · " : "") + mi.name + " | " + mi.w + "×" + mi.h +
                   " 格 | 1:" + s + " | " + iw + "×" + ih + "px";
        }

        function setAnchorFromView() {
            anchorX = (vp.scrollLeft + vp.clientWidth / 2) * curScale();
            anchorY = (vp.scrollTop + vp.clientHeight / 2) * curScale();
        }

        function applyAnchor() {
            const s = curScale();
            const maxX = Math.max(0, worldW / s - vp.clientWidth);
            const maxY = Math.max(0, worldH / s - vp.clientHeight);
            vp.scrollLeft = Math.max(0, Math.min(anchorX / s - vp.clientWidth / 2, maxX));
            vp.scrollTop  = Math.max(0, Math.min(anchorY / s - vp.clientHeight / 2, maxY));
        }

        // ---- tile mode: dynamically load /tile images covering the viewport ----
        // 增量瓦片管理: 以 URL 为键复用已存在的 <img>, 只增删变化的瓦片,
        const tileEls = new Map();   // url -> <img>
        let tileSpacer = null;
        function tileUrl(mi, tx, ty, z) {
            return "/tile?map=" + encodeURIComponent(mi.name) + "&tx=" + tx + "&ty=" + ty +
                   "&z=" + z + "&g=" + gOn() + "&m=" + mOn() + "&f=" + fOn();
        }
        function clearTiles() {
            tileLayer.innerHTML = "";
            tileEls.clear();
            tileSpacer = null;
        }
        function drawTiles() {
            const mi = curMap();
            if (!mi || !isTileMode()) { clearTiles(); return; }
            const s = curScale();
            const z = curZ();
            const TILE = 512 / s;   // tile size in screen px at this zoom
            // world px visible in viewport (scroll position is screen px at 1:1 of current scale)
            const vx0 = vp.scrollLeft * s, vy0 = vp.scrollTop * s;
            const vx1 = vx0 + vp.clientWidth * s, vy1 = vy0 + vp.clientHeight * s;
            const M = 1;  // preload margin ring (tiles) so drags reveal instantly
            const tx0 = Math.floor(vx0 / 512) - M, ty0 = Math.floor(vy0 / 512) - M;
            const tx1 = Math.floor(vx1 / 512) + M, ty1 = Math.floor(vy1 / 512) + M;
            const tileH = Math.ceil(worldH / 512);   // ceil: 整除时无幻影空块
            const tileW = Math.ceil(worldW / 512);
            const v = version;
            const layer = tileLayer;
            layer.style.width = (worldW / s) + "px";
            layer.style.height = (worldH / s) + "px";
            // spacer: makes viewport scrollable to the full world at this zoom
            if (!tileSpacer || !tileSpacer.isConnected) {
                tileSpacer = document.createElement("div");
                tileSpacer.style.width = (worldW / s) + "px";
                tileSpacer.style.height = (worldH / s) + "px";
                tileSpacer.style.position = "absolute";
                tileSpacer.style.left = "0"; tileSpacer.style.top = "0";
                layer.appendChild(tileSpacer);
            } else {
                tileSpacer.style.width = (worldW / s) + "px";
                tileSpacer.style.height = (worldH / s) + "px";
            }
            const need = new Set();
            for (let ty = ty0; ty <= ty1; ty++) {
                if (ty < 0 || ty >= tileH) continue;
                for (let tx = tx0; tx <= tx1; tx++) {
                    if (tx < 0 || tx >= tileW) continue;
                    const url = tileUrl(mi, tx, ty, z);
                    need.add(url);
                    if (tileEls.has(url)) continue;      // already on screen/loading
                    const img = document.createElement("img");
                    img.style.left = (tx * 512 / s) + "px";
                    img.style.top = (ty * 512 / s) + "px";
                    img.style.width = TILE + "px";
                    img.style.height = TILE + "px";
                    img.onload = () => { if (v !== version) { img.remove(); tileEls.delete(url); } };
                    img.onerror = () => {
                        if (v !== version) { img.remove(); tileEls.delete(url); return; }
                        // [E6 P0-1] 服务端 503/超预算：占位纹理 + 退避重试（最多 2 次），
                        // 之后保留占位等下次滚动/切图重触发，绝不再打服务
                        const tries = (img.__tries = (img.__tries || 0) + 1);
                        img.style.background =
                            "repeating-linear-gradient(45deg,#1a1c22 0 8px,#23252d 8px 16px)";
                        if (tries <= 2) {
                            img.removeAttribute("src");
                            setTimeout(() => {
                                if (v === version && tileEls.get(url) === img) img.src = url;
                            }, 800 * tries);
                        }
                    };
                    img.src = url;
                    layer.appendChild(img);
                    tileEls.set(url, img);
                }
            }
            for (const [url, img] of tileEls) {
                if (!need.has(url)) { img.remove(); tileEls.delete(url); }
            }
        }

        function render(keepAnchor) {
            const mi = curMap();
            if (!mi) return;
            const z = curZ();
            const v = ++version;
            if (!keepAnchor) setAnchorFromView();
            statusEl.textContent = "加载中…";
            document.getElementById("btn-zoom-in").disabled = cur <= 0;
            document.getElementById("btn-zoom-out").disabled = cur >= scaleLadder.length - 1;
            if (isTileMode()) {
                // tile mode: hide fullmap img, show tiles
                imgEl.style.display = "none";
                imgEl.src = "";
                tileLayer.style.display = "block";
                drawTiles();          // 先建 spacer（可滚动域）再落点
                applyAnchor();        // hash 深链/锚点在 tile 模式同样生效（此前漏掉 → 深链落在左上角）
                drawQuest();          // 按新视口重算任务标记（剔除逻辑依赖 scroll）
                drawTiles();          // 滚动后按新视口补瓦片（scroll 事件亦会触发）
                drawMini();
                drawGrid();
                drawRoutes();
                drawEntities();
                statusEl.textContent = "就绪";
                hideLoading();
                return;
            }
            // fullmap mode
            imgEl.style.display = "";
            tileLayer.style.display = "none";
            const img = new Image();
            img.onload = () => {
                if (v !== version) return;
                imgEl.src = img.src;
                statusEl.textContent = "就绪";
                applyAnchor();
                drawMini();
                drawGrid();
                drawRoutes();
                drawEntities();
                updateStatusBar();
                hideLoading();
            };
            img.onerror = () => {
                if (v === version) {
                    statusEl.textContent = "生成失败";
                    showToast("地图渲染失败", `${mi.name} 无法生成整图。可能图库资源缺失或地图数据异常。<br>可尝试点击右上角「重新生成」清除缓存。`);
                    hideLoading();
                }
            };
            img.src = "/fullmap?map=" + encodeURIComponent(mi.name) + "&z=" + z +
                      "&g=" + gOn() + "&m=" + mOn() + "&f=" + fOn();
        }

        function loadMap() {
            const mi = curMap();
            if (!mi) return;
            worldW = mi.world_w || (mi.w + mi.h + 3) * 24;
            worldH = mi.world_h || (mi.w + mi.h + 2) * 16;
            // default: 100% (1:1, game view)
            cur = 0;
            anchorX = worldW / 2; anchorY = worldH / 2;
            version++;
            imgEl.src = "";
            clearTiles();
            loadMini();
            loadRoutes(mi);
            loadEntities(mi);
            render(true);
        }

        function loadMini() {
            const mi = curMap();
            if (!mi) return;
            miniReady = false;
            mmRect.style.display = "none";
            mmImg.onload = () => { miniReady = true; drawMini(); };
            mmImg.onerror = () => { miniReady = false; };
            mmImg.src = "/minimap?map=" + encodeURIComponent(mi.name);
        }

        function drawMini() {
            if (!miniReady || !worldW || !worldH || !mmBox.clientWidth) return;
            const s = curScale();
            const bw = mmBox.clientWidth, bh = mmBox.clientHeight;
            mmRect.style.display = "block";
            mmRect.style.left   = (vp.scrollLeft * s / worldW * bw) + "px";
            mmRect.style.top    = (vp.scrollTop  * s / worldH * bh) + "px";
            mmRect.style.width  = Math.max(2, Math.min(vp.clientWidth  * s / worldW * bw, bw)) + "px";
            mmRect.style.height = Math.max(2, Math.min(vp.clientHeight * s / worldH * bh, bh)) + "px";
        }

        function miniPan(cx, cy) {
            anchorX = cx; anchorY = cy;
            applyAnchor();
            drawMini();
            if (isTileMode()) drawTiles();
        }

        // ---- grid overlay (rect layout: cell = 48x32 world px) ----
        const gridCanvas = document.getElementById("grid-canvas");
        const gridCtx = gridCanvas.getContext("2d");
        const gridOn = () => document.getElementById("chk-grid").checked;

        function drawGrid() {
            const s = curScale();
            if (!gridOn() || !imgEl.naturalWidth) { gridCanvas.width = 0; gridCanvas.height = 0; return; }
            // canvas 是 #viewport(滚动容器) 的子元素：需用内容坐标（视口相对 +
            // scroll 偏移）才能与地图图像永久对齐，滚动后无需重绘。
            const vpRect = vp.getBoundingClientRect();
            const imgRect = imgEl.getBoundingClientRect();
            const ox = imgRect.left - vpRect.left + vp.scrollLeft;
            const oy = imgRect.top - vpRect.top + vp.scrollTop;
            gridCanvas.style.left = ox + "px";
            gridCanvas.style.top = oy + "px";
            const cw = imgRect.width, ch = imgRect.height;
            if (cw <= 0 || ch <= 0) return;
            gridCanvas.width = cw * (window.devicePixelRatio || 1);
            gridCanvas.height = ch * (window.devicePixelRatio || 1);
            gridCanvas.style.width = cw + "px";
            gridCanvas.style.height = ch + "px";
            const ctx = gridCtx;
            ctx.setTransform(1, 0, 0, 1, 0, 0);
            ctx.clearRect(0, 0, gridCanvas.width, gridCanvas.height);
            ctx.scale(window.devicePixelRatio || 1, window.devicePixelRatio || 1);
            const cwPx = 48 / s, chPx = 32 / s;   // world->screen at this zoom
            if (cwPx < 2 || chPx < 2) return;      // too dense to draw
            ctx.strokeStyle = "rgba(255,213,74,0.35)";
            ctx.lineWidth = 1;
            ctx.beginPath();
            for (let x = 0; x <= cw; x += cwPx) { ctx.moveTo(x, 0); ctx.lineTo(x, ch); }
            for (let y = 0; y <= ch; y += chPx) { ctx.moveTo(0, y); ctx.lineTo(cw, y); }
            ctx.stroke();
        }

        // ---- map connections (game-cell coordinates, not screen coordinates) ----
        const routeSvg = document.getElementById("route-svg");
        const portTooltip = document.getElementById("port-tooltip");
        let routeCache = {};
        function drawRoutes() {
            const mi = curMap();
            const routes = routeCache[mi?.name] || [];
            if (!mi) { routeSvg.innerHTML = ""; return; }
            const s = curScale();
            // overlay 是 #viewport(overflow:auto) 的子元素，随内容滚动 —— 必须用
            // 内容坐标（cell*48/s），不能减 scrollLeft（否则双重偏移飞出视口）。
            const px = p => Number(p.x) * 48 / s;
            const py = p => Number(p.y) * 32 / s;
            routeSvg.style.left = "0px";
            routeSvg.style.top = "0px";
            routeSvg.setAttribute("width", vp.clientWidth);
            routeSvg.setAttribute("height", vp.clientHeight);
            const vw = vp.clientWidth, vh = vp.clientHeight;
            const sl = vp.scrollLeft, st = vp.scrollTop;
            const hereStem = mi.name.replace(/\\.map$/i, "");
            // 聚合：同 (方向, 对面地图, icon) 的多条 movement（如逐格排列的传送门）
            // 合成一个出口标记，位置取本图端点质心 —— 否则地图边缘会出现几十个
            // 重叠圆点。movement 源数据 = System.db MovementInfo (workspace 最新)。
            const groups = {};
            for (const r of routes) {
                if (!r.source || !r.destination) continue;
                const sourceHere = String(r.source.map).replace(/\\.map$/i, "") === hereStem;
                const destHere = String(r.destination.map).replace(/\\.map$/i, "") === hereStem;
                if (!sourceHere && !destHere) continue;
                const here = sourceHere ? r.source : r.destination;
                const other = sourceHere ? r.destination : r.source;
                if (here.x == null) continue;   // 本图端点无坐标，无法定位出口
                const otherStem = String(other.map).replace(/\\.map$/i, "");
                const dir = sourceHere ? "O" : "I";
                const key = dir + "|" + otherStem + "|" + (r.icon || "None");
                const g = groups[key] = groups[key] || {
                    dir, otherStem, icon: r.icon || "None",
                    sx: 0, sy: 0, n: 0, ox: other.x, oy: other.y, hasO: other.x != null,
                };
                g.sx += Number(here.x); g.sy += Number(here.y); g.n++;
                if (other.x != null) { g.ox = other.x; g.oy = other.y; }
            }
            routeSvg.innerHTML = Object.values(groups).map(g => {
                const cx = px({ x: g.sx / g.n }), cy = py({ y: g.sy / g.n });
                if (cx < sl - 60 || cy < st - 60 || cx > sl + vw + 60 || cy > st + vh + 60) return "";
                const tcn = MAP_CN[g.otherStem] || g.otherStem;
                // color by icon type: Cave/Down=red, Building=green, Exit/Up=blue, Province=yellow
                let color = "#72d6ff";
                if (/Cave|Down/.test(g.icon)) color = "#ff6b6b";
                else if (/Building/.test(g.icon)) color = "#7CFF7C";
                else if (/Province/.test(g.icon)) color = "#ffd54a";
                const arrow = g.dir === "O" ? "→" : "←";   // 出口/入口方向
                const label = g.otherStem === hereStem
                    ? `本图内传送 · ${g.n} 处`
                    : `${g.dir === "O" ? "通往" : "来自"} ${tcn} · ${g.n} 处`;
                const dstAttr = (g.ox != null)
                    ? ` data-dstmap="${g.otherStem}" data-dstx="${Math.round(g.ox)}" data-dsty="${Math.round(g.oy)}" data-dstcn="${encodeURIComponent(tcn)}"`
                    : "";
                const keyAttr = ` data-key="${g.dir}|${g.otherStem}|${g.icon}"`;
                const selRing = (window.__hlPort === g.dir + "|" + g.otherStem + "|" + g.icon)
                    ? `<circle cx="${cx}" cy="${cy}" r="13" fill="none" stroke="#fff" stroke-width="2.5" pointer-events="none"><animate attributeName="r" values="11;15;11" dur="1.2s" repeatCount="indefinite"/></circle>` : "";
                return `${selRing}<g class="port-wrap"><circle class="port"${keyAttr}${dstAttr} cx="${cx}" cy="${cy}" r="7" fill="${color}" stroke="#111" stroke-width="2" opacity=".92"><title>${label}${g.ox != null ? ` · 对面格 ${Math.round(g.ox)},${Math.round(g.oy)}` : ""} · 点击查看对面小地图</title></circle>` +
                    `<text x="${cx}" y="${cy + 4}" text-anchor="middle" font-size="10" fill="#fff" pointer-events="none">${arrow}</text></g>`;
            }).join("");
            positionPortDetail();
        }
        // hover portal -> show destination map thumbnail
        routeSvg.addEventListener("mouseover", (e) => {
            const c = e.target.closest("circle.port");
            if (!c || !c.dataset.dstmap) { portTooltip.style.display = "none"; return; }
            const dst = c.dataset.dstmap, dx = c.dataset.dstx, dy = c.dataset.dsty, cn = decodeURIComponent(c.dataset.dstcn || dst);
            const dstName = dst + ".map";
            portTooltip.innerHTML = `<b>${cn}</b> · 格 ${dx},${dy}<br><img src="/thumb?map=${encodeURIComponent(dstName)}" alt="">`;
            portTooltip.style.display = "block";
            const r = e.clientX, b = e.clientY;
            portTooltip.style.left = Math.min(r + 14, window.innerWidth - 260) + "px";
            portTooltip.style.top = Math.min(b + 14, window.innerHeight - 200) + "px";
        });
        routeSvg.addEventListener("mouseout", (e) => {
            if (!e.target.closest("circle.port")) portTooltip.style.display = "none";
        });
        // click portal -> 两段式：第一次选中并展示对面小地图，第二次跳转
        let portSelKey = null;
        const portDetail = document.getElementById("port-detail");
        function hidePortDetail() {
            portDetail.style.display = "none";
            portSelKey = null;
            window.__hlPort = null;
        }
        function showPortDetail(c) {
            const dst = c.dataset.dstmap, cn = decodeURIComponent(c.dataset.dstcn || dst);
            portDetail.innerHTML =
                `<div class="pd-head">🚩 ${cn}<span class="pd-close" title="关闭">✕</span></div>` +
                `<img src="/thumb?map=${encodeURIComponent(dst + ".map")}" alt="">` +
                `<div class="pd-meta">对面格 ${c.dataset.dstx},${c.dataset.dsty}</div>` +
                `<div class="pd-meta" style="color:#ffd54a;">再点一次传送点 · 跳转过去</div>`;
            portDetail.dataset.dstmap = dst;
            portDetail.dataset.dstx = c.dataset.dstx || 0;
            portDetail.dataset.dsty = c.dataset.dsty || 0;
            portDetail.style.display = "block";
            positionPortDetail();
        }
        function positionPortDetail() {
            if (!portDetail || portDetail.style.display === "none" || !portSelKey) return;
            const c = document.querySelector('#route-svg circle.port[data-key="' + (window.CSS && CSS.escape ? CSS.escape(portSelKey) : portSelKey) + '"]');
            if (!c) return;
            const r = c.getBoundingClientRect();
            portDetail.style.left = Math.min(r.x + 18, window.innerWidth - 240) + "px";
            portDetail.style.top = Math.min(r.y + 18, window.innerHeight - 280) + "px";
        }
        // 自动关闭：鼠标移出标记/弹窗 250ms 后消失（缓冲让鼠标能移进弹窗），
        // 点击空白处立即消失。
        let pdHideTimer = null;
        function schedulePdHide() {
            clearTimeout(pdHideTimer);
            pdHideTimer = setTimeout(() => {
                if (portDetail.style.display !== "none") { hidePortDetail(); drawRoutes(); }
            }, 250);
        }
        function cancelPdHide() { clearTimeout(pdHideTimer); }
        portDetail.addEventListener("mouseenter", cancelPdHide);
        portDetail.addEventListener("mouseleave", schedulePdHide);
        document.addEventListener("click", (e) => {
            if (portDetail.style.display === "none") return;
            if (portDetail.contains(e.target)) return;
            if (e.target.closest && e.target.closest("circle.port")) return;
            hidePortDetail();
            drawRoutes();
        });
        // 悬停关闭改用 document mousemove 探测：showPortDetail 后 drawRoutes 重建了
        // SVG，原 circle 被销毁导致 mouseout 不会触发 —— 必须以坐标实时判定。
        document.addEventListener("mousemove", (e) => {
            if (portDetail.style.display === "none") return;
            if (portDetail.contains(e.target)) { cancelPdHide(); return; }
            const c = e.target.closest && e.target.closest("circle.port");
            if (c && portSelKey && c.dataset.key === portSelKey) { cancelPdHide(); return; }
            schedulePdHide();
        });
        vp.addEventListener("scroll", () => {   // 滚动后弹窗与标记错位，直接关
            if (portDetail.style.display !== "none" && !pdHideTimer) hidePortDetail(), drawRoutes();
        });
        portDetail.addEventListener("click", (e) => {
            if (e.target.classList.contains("pd-close")) { hidePortDetail(); drawRoutes(); return; }
            const dst = portDetail.dataset.dstmap;
            if (dst && maps.some(m => m.name === dst + ".map")) {
                hidePortDetail();
                history.replaceState(null, '', `#map=${encodeURIComponent(dst + ".map")}&cur=0&x=${Math.round(Number(portDetail.dataset.dstx) * 48)}&y=${Math.round(Number(portDetail.dataset.dsty) * 32)}&g=1&m=1&f=1`);
                init();
            }
        });
        routeSvg.addEventListener("click", (e) => {
            const c = e.target.closest("circle.port");
            if (!c) { if (portSelKey) { hidePortDetail(); drawRoutes(); } return; }
            if (!c.dataset.dstmap) return;
            if (portSelKey && portSelKey === c.dataset.key) {
                // 第二次点击：跳转对面
                const dst = c.dataset.dstmap;
                hidePortDetail();
                if (maps.some(m => m.name === dst + ".map")) {
                    history.replaceState(null, '', `#map=${encodeURIComponent(dst + ".map")}&cur=0&x=${Math.round(Number(c.dataset.dstx || 0) * 48)}&y=${Math.round(Number(c.dataset.dsty || 0) * 32)}&g=1&m=1&f=1`);
                    init();
                }
                return;
            }
            portSelKey = c.dataset.key;      // 第一次点击：选中 + 对面小地图
            window.__hlPort = c.dataset.key;
            showPortDetail(c);
            drawRoutes();
        });
        async function loadRoutes(mi) {
            try {
                const res = await fetch("/api/connections?map=" + encodeURIComponent(mi.name));
                const data = await res.json(); routeCache[mi.name] = data.links || [];
            } catch (e) { routeCache[mi.name] = []; }
            drawRoutes();
            renderConnPanel(mi);
        }
        // ---- 连接列表面板：本图 ↔ 哪些图互连（中文地图名，点击跳转） ----
        function renderConnPanel(mi) {
            const panel = document.getElementById("conn-panel");
            if (!panel) return;
            const hereStem = mi.name.replace(/\\.map$/i, "");
            const routes = routeCache[mi.name] || [];
            // 与 drawRoutes 同一聚合键（dir|otherStem|icon）：一行 ↔ 一个出口标记
            const groups = {};
            for (const r of routes) {
                if (!r.source || !r.destination) continue;
                const sourceHere = String(r.source.map).replace(/\\.map$/i, "") === hereStem;
                const destHere = String(r.destination.map).replace(/\\.map$/i, "") === hereStem;
                if (!sourceHere && !destHere) continue;
                const here = sourceHere ? r.source : r.destination;
                const other = sourceHere ? r.destination : r.source;
                const otherStem = String(other.map).replace(/\\.map$/i, "");
                const dir = sourceHere ? "O" : "I";
                const key = dir + "|" + otherStem + "|" + (r.icon || "None");
                const g = groups[key] = groups[key] || {
                    key, dir, otherStem, out: 0, in: 0,
                    sx: 0, sy: 0, n: 0, hasL: false,
                    ox: other.x, oy: other.y, hasO: other.x != null,
                };
                if (sourceHere) g.out++; else g.in++;
                if (here.x != null) { g.sx += Number(here.x); g.sy += Number(here.y); g.n++; g.hasL = true; }
                if (other.x != null) { g.ox = other.x; g.oy = other.y; g.hasO = true; }
            }
            const rows = Object.values(groups).sort((a, b) => (b.out + b.in) - (a.out + a.in));
            const cn = st => MAP_CN[st] || st;
            let html = `<h4>🔗 ${cn(hereStem)} · 传送点 (${rows.length})</h4>`;
            if (!rows.length) {
                html += `<div class="conn-empty">无连接数据</div>`;
            } else {
                for (const g of rows) {
                    const exists = maps.some(m => m.name === g.otherStem + ".map");
                    const lx = g.hasL ? Math.round(g.sx / g.n) : null;
                    const ly = g.hasL ? Math.round(g.sy / g.n) : null;
                    // 有本图端点 -> 点击跳到本图出口格并选中标记（再点标记两下过去）；
                    // 无本图坐标 -> 兜底直接跳对面。
                    let attr = "", tail;
                    if (lx != null) {
                        attr = ` data-lx="${lx}" data-ly="${ly}" data-pkey="${g.key}"`;
                        tail = `<span class="conn-file" title="本图出入口格">⇩ ${lx},${ly}</span>`;
                    } else if (exists && g.hasO) {
                        attr = ` data-jump="${g.otherStem}" data-x="${Math.round(g.ox)}" data-y="${Math.round(g.oy)}"`;
                        tail = `<span class="conn-file">${g.otherStem}</span>`;
                    } else {
                        tail = `<span class="conn-file">${g.otherStem !== hereStem ? g.otherStem : "本图内"}</span>`;
                    }
                    const dirs = [];
                    if (g.out) dirs.push(`→${g.out}`);
                    if (g.in) dirs.push(`←${g.in}`);
                    html += `<div class="conn-row${attr ? " link" : ""}"${attr}>` +
                        `<span class="conn-name">${cn(g.otherStem)}</span>` +
                        `<span class="conn-dir">${dirs.join(" ")}</span>` +
                        tail + `</div>`;
                }
            }
            panel.innerHTML = html;
            panel.style.display = "block";
            panel.querySelectorAll(".conn-row.link").forEach(row => {
                row.addEventListener("click", () => {
                    if (row.dataset.lx != null) {
                        // 跳到本图出口格 + 高亮标记；不预置 portSelKey——
                        // 用户点标记第 1 次看对面小地图，第 2 次才跳转
                        jumpToCell(row.dataset.lx, row.dataset.ly, null);
                        window.__hlPort = row.dataset.pkey;
                        window.__hlName = null;
                        drawRoutes();
                    } else if (row.dataset.jump) {
                        history.replaceState(null, '',
                            `#map=${encodeURIComponent(row.dataset.jump + ".map")}&cur=0&x=${Math.round(Number(row.dataset.x) * 48)}&y=${Math.round(Number(row.dataset.y) * 32)}&g=1&m=1&f=1`);
                        init();
                    }
                });
            });
        }

        // ---- entities (NPC / spawn / monsters) from Mud3 Envir ----
        const entLayer = document.getElementById("ent-layer");
        const entTooltip = document.getElementById("ent-tooltip");
        let entCache = {};
        function entColor(kind, name) {
            if (kind === "spawn") return "#ffd54a";
            if (kind === "monster") return "#ff6b6b";
            if (kind === "guard") return "#ff9b3d";
            const n = name || "";
            // merchant / storage / function NPC -> green, else blue
            if (/仓|商|卖|买|功能|保管|商店|铺|店/.test(n)) return "#7CFF7C";
            return "#8cf";
        }
        function entShape(kind) {
            if (kind === "monster") return "border-radius:2px;";
            return "border-radius:50%;";
        }
        function drawEntities() {
            const mi = curMap();
            const ents = entCache[mi?.name] || [];
            if (!mi) { entLayer.innerHTML = ""; return; }
            if (!document.getElementById("chk-ents").checked) { entLayer.innerHTML = ""; return; }
            const s = curScale();
            entLayer.style.left = "0px";
            entLayer.style.top = "0px";
            entLayer.style.width = vp.clientWidth + "px";
            entLayer.style.height = vp.clientHeight + "px";
            // 内容坐标（cell*48/s）：ent-layer 随 #viewport 内容滚动，减 scrollLeft 会双重偏移
            const vw = vp.clientWidth, vh = vp.clientHeight;
            const sl = vp.scrollLeft, st = vp.scrollTop;
            const hlName = window.__hlName || null;
            entLayer.innerHTML = ents.map(e => {
                const px = Number(e.x) * 48 / s;
                const py = Number(e.y) * 32 / s;
                // wide culling: entities are few, keep visible beyond viewport edges
                if (px < sl - 200 || py < st - 200 || px > sl + vw + 200 || py > st + vh + 200) return "";
                const kind = e.kind || "npc";
                const color = entColor(kind, e.name);
                const shape = entShape(kind);
                const label = e.name || "";
                const d = e.drops ? ` · 掉落 ${e.drops.length} 种` : "";
                const hlCls = (hlName && e.name === hlName) ? " target" : "";
                let icon = `<span class="ent-icon" style="background:${color};box-shadow:0 0 4px ${color};${shape}"></span>`;
                if (kind === "npc" && e.img != null) {
                    const fr = Number(e.img) * 100;
                    icon = `<img class="ent-sprite" src="/sprite?lib=NPC&frame=${fr}" alt="" style="zoom:${1 / s}"` +
                        ` onerror="this.style.display='none';this.nextElementSibling.classList.remove('hide')">` +
                        `<span class="ent-icon hide" style="background:${color};box-shadow:0 0 4px ${color};${shape}"></span>`;
                }
                if (kind === "guard" && e.lib && e.frame != null) {
                    // 卫士：帧已按朝向算好（shape*1000 + 10*dir），库由服务端给出
                    icon = `<img class="ent-sprite" src="/sprite?lib=${encodeURIComponent(e.lib)}&frame=${e.frame}" alt="" style="zoom:${1 / s}"` +
                        ` onerror="this.style.display='none';this.nextElementSibling.classList.remove('hide')">` +
                        `<span class="ent-icon hide" style="background:${color};box-shadow:0 0 4px ${color};${shape}"></span>`;
                }
                return `<div class="ent ${kind}${hlCls}" data-name="${label.replace(/"/g, "&quot;")}" data-x="${e.x}" data-y="${e.y}" data-kind="${kind}"` +
                    (e.npc_index != null ? ` data-npc="${e.npc_index}"` : '') +
                    (e.region != null ? ` data-region="${e.region}"` : '') +
                    (e.guard_index != null ? ` data-guard="${e.guard_index}"` : '') +
                    ` style="left:${px}px;top:${py}px">${icon}<span class="ent-label">${label}</span></div>`;
            }).join("");
        }
        // hover entity -> tooltip
        entLayer.addEventListener("mouseover", (e) => {
            const d = e.target.closest(".ent");
            if (!d) { entTooltip.style.display = "none"; return; }
            entTooltip.textContent = `${d.dataset.name} · 格 ${d.dataset.x},${d.dataset.y}`;
            entTooltip.style.display = "block";
            entTooltip.style.left = Math.min(e.clientX + 12, window.innerWidth - 200) + "px";
            entTooltip.style.top = Math.max(4, e.clientY - 28) + "px";
        });
        entLayer.addEventListener("mouseout", (e) => {
            if (!e.target.closest(".ent")) entTooltip.style.display = "none";
        });
        async function loadEntities(mi) {
            try {
                const res = await fetch("/api/entities?map=" + encodeURIComponent(mi.name));
                const d = await res.json();
                entCache[mi.name] = d.ok ? d.entities : [];
            } catch (e) { entCache[mi.name] = []; }
            // 首次打开且用户未指定视点时，默认居中到 NPC/出生点质心（城镇区），
            // 而不是地图几何中心（大图中心常是无人区，NPC 标记全在视口外）。
            if (!window.__userAnchor && entCache[mi.name] && entCache[mi.name].length) {
                let sx = 0, sy = 0, n = 0;
                for (const e of entCache[mi.name]) {
                    if (e.kind === "npc" || e.kind === "spawn") { sx += Number(e.x); sy += Number(e.y); n++; }
                }
                if (n > 0) {
                    anchorX = (sx / n) * 48 + 24;
                    anchorY = (sy / n) * 32 + 16;
                    applyAnchor();
                    if (isTileMode()) drawTiles();
                    drawRoutes();
                    drawEntities();
                    drawGrid();
                    drawMini();
                    updateUrlHash();
                }
            }
            drawEntities();
            renderNpcPanel(mi);
        }

        // ---- NPC 列表面板：服务端 NPCInfo 位置直读，点击跳转 + 高亮 ----
        function jumpToCell(x, y, hlName) {
            window.__userAnchor = true;         // 用户显式指定视点，停用质心自动居中
            window.__hlRegion = null;           // 刷新区高亮随新跳转清除
            if (typeof portSelKey !== "undefined" && portSelKey) hidePortDetail();
            anchorX = Number(x) * 48 + 24;      // 格中心（与 applyAnchor/URL hash 同一约定）
            anchorY = Number(y) * 32 + 16;
            if (hlName) window.__hlName = hlName;
            applyAnchor();
            if (isTileMode()) drawTiles();
            drawRoutes(); drawEntities(); drawGrid(); drawMini();
            updateUrlHash();
        }
        function renderNpcPanel(mi) {
            const panel = document.getElementById("npc-panel");
            if (!mi) { panel.style.display = "none"; return; }
            const npcs = (entCache[mi.name] || []).filter(e => {
                const k = e.kind || "npc";
                return k === "npc" || k === "guard";   // NPC + 城镇卫士
            });
            const cn = st => MAP_CN[st] || st;
            const stem = mi.name.replace(/\\.map$/i, "");
            const nGuard = npcs.filter(e => e.kind === "guard").length;
            let html = `<h4>🏪 ${cn(stem)} · NPC ${npcs.length - nGuard} · 卫士 ${nGuard}</h4>`;
            if (!npcs.length) {
                html += `<div class="npc-empty">本图无 NPC 数据</div>`;
            } else {
                npcs.sort((a, b) => String(a.name).localeCompare(String(b.name), "zh"));
                for (const e of npcs) {
                    const nm = String(e.name || "").replace(/"/g, "&quot;");
                    const en = e.name_en && e.name_en !== e.name
                        ? `<span class="npc-en">${String(e.name_en).replace(/</g, "&lt;")}</span>` : "";
                    html += `<div class="npc-row" data-name="${nm}" data-x="${e.x}" data-y="${e.y}">` +
                        `<span class="npc-name">${nm}${en}</span>` +
                        `<span class="npc-xy">${e.x},${e.y}</span></div>`;
                }
            }
            panel.innerHTML = html;
            panel.style.display = "block";
            panel.querySelectorAll(".npc-row").forEach(row => {
                row.addEventListener("click", () => {
                    jumpToCell(row.dataset.x, row.dataset.y, row.dataset.name);
                });
            });
        }

        // ---- 怪物刷新面板：respCache 分组区域列表，点击跳转 + 热力高亮 ----
        function renderRespPanel(mi) {
            const panel = document.getElementById("resp-panel");
            if (!panel) return;
            if (!mi || !chkResp || !chkResp.checked) { panel.style.display = "none"; return; }
            const d = respCache[mi.name];
            if (!d || !d.groups || !d.groups.length) { panel.style.display = "none"; return; }
            const cn = st => MAP_CN[st] || st;
            const stem = mi.name.replace(/\\.map$/i, "");
            let html = `<h4>👾 ${cn(stem)} · 刷新区 (${d.groups.length})</h4>`;
            const groups = [...d.groups].sort((a, b) =>
                b.entries.reduce((s, e) => s + (e.count || 0), 0) -
                a.entries.reduce((s, e) => s + (e.count || 0), 0));
            for (const g of groups) {
                const total = g.entries.reduce((s, e) => s + (e.count || 0), 0);
                const names = g.entries.map(e => e.mc || e.m || "?");
                const lv = Math.max(...g.entries.map(e => e.level || 0));
                const boss = g.entries.some(e => e.boss) ? " 👑" : "";
                const main = names[0] + (names.length > 1 ? ` 等${names.length}种` : "");
                html += `<div class="resp-row" data-x="${g.x}" data-y="${g.y}" data-half="${g.half}"` +
                    ` title="${names.join(" / ")}">` +
                    `<span class="resp-name">${main}${boss} <span style="color:#6a6a75;">Lv${lv}</span></span>` +
                    `<span class="resp-meta">×${total}</span>` +
                    `<span class="resp-xy">${g.x},${g.y}</span></div>`;
            }
            panel.innerHTML = html;
            panel.style.display = "block";
            panel.querySelectorAll(".resp-row").forEach(row => {
                row.addEventListener("click", () => {
                    jumpToCell(row.dataset.x, row.dataset.y, null);
                    window.__hlRegion = row.dataset.x + "," + row.dataset.y + "," + row.dataset.half;
                    window.__hlName = null;
                    drawHeat();
                });
            });
        }

        // ---- cursor cell coordinate readout (rect: world px -> cell) ----
        vp.addEventListener("scroll", () => { drawRoutes(); drawEntities(); drawHeat(); drawQuest(); });
        window.addEventListener("resize", () => { drawGrid(); drawRoutes(); drawEntities(); });

        // ---- catalog info panel ----
        let catCache = {};   // map_name -> catalog doc

        function cellFlag(cat, x, y) {
            // flag byte lives at cell offset +0; catalog doesn't store the
            // full matrix, so report only when the flag histogram says 1s exist.
            return "";
        }

        function fmtLibRow(layer, entries) {
            const rows = [];
            for (const [lid, info] of Object.entries(entries)) {
                const oob = info.frame_oob ? `<span class="oob"> OOB ${info.frame_oob}</span>` : "";
                rows.push(`<div class="row"><span class="k">${layer} ${lid} ${info.lib}</span><span class="v">${info.cells}格 ≤${info.frame_max}${oob}</span></div>`);
            }
            return rows.join("");
        }

        async function loadCatalog(mi) {
            if (catCache[mi.name]) { renderCat(mi); return; }
            try {
                const res = await fetch("/api/catalog?map=" + encodeURIComponent(mi.name));
                const data = await res.json();
                if (data.ok) catCache[mi.name] = data.catalog;
                else catCache[mi.name] = null;
            } catch (e) { catCache[mi.name] = null; }
            renderCat(mi);
        }

        function renderCat(mi) {
            const panel = document.getElementById("cat-panel");
            const cat = catCache[mi.name];
            if (!cat) { panel.style.display = "none"; return; }
            const anom = cat.anomaly_total || 0;
            const warn = anom ? `<span class="warn"> ⚠ ${anom} 帧越界</span>` : "";
            let html = `<h4>${cat.name}${cat.display ? " · MiniMap " + cat.display : ""}${warn}</h4>
<div class="row"><span class="k">主题</span><span class="v">${cat.theme_name || "base"}</span></div>
<div class="row"><span class="k">尺寸</span><span class="v">${cat.w}×${cat.h} · ${cat.cell_bytes}B/格${cat.legacy_13b ? " · legacy" : ""}</span></div>
<div class="row"><span class="k">动画格</span><span class="v">${cat.animated_cells || 0}</span></div>`;
            for (const layer of ["ground", "mid", "front"]) {
                const e = cat[layer];
                if (e && Object.keys(e).length) html += `<div class="lib"><b>${layer}</b>${fmtLibRow(layer, e)}</div>`;
            }
            panel.innerHTML = html;
            panel.style.display = "block";
        }

        // ---- custom map dropdown ----
        function mselLabelOf(m) { return m ? (m.cn ? m.cn + " — " : "") + m.name : "加载中…"; }
        function mselOpen() {
            mselPop.hidden = false; mselFilter.value = ""; renderMselTabs(); renderMselList(); mselFilter.focus();
            ensureNpcSet().then(renderMselList);   // NPC 小点懒加载完成后重绘
        }
        function mselClose() { mselPop.hidden = true; }
        let mselCat = "all";                       // 分类标签筛选（all/town/cave/room/other）
        let npcMapSet = null;                      // 有 NPC 的地图 stem 集合（懒加载）
        async function ensureNpcSet() {
            if (npcMapSet) return npcMapSet;
            npcMapSet = new Set();
            try {
                const d = await (await fetch("/api/npc_audit")).json();
                for (const row of (d.rows || [])) {
                    if (row.npcs && row.npcs.length) npcMapSet.add(row.map);
                }
            } catch (e) {}
            return npcMapSet;
        }
        function mselFiltered() {
            const q = mselFilter.value.trim().toLowerCase();
            return maps.filter(m =>
                (mselCat === "all" || (m.cat || "other") === mselCat) &&
                (!q || m.name.toLowerCase().includes(q) || (m.cn || "").toLowerCase().includes(q)));
        }
        const CAT_LABEL = { town: "🏘️ 城镇", cave: "⛰️ 洞穴/地牢", room: "🚪 小房间/建筑", other: "📦 其他" };
        const mselItem = (m) => {
            const stem = m.name.replace(/\\.map$/i, "");
            const dot = npcMapSet && npcMapSet.has(stem) ? '<span class="msel-npcdot" title="有 NPC"></span>' : "";
            return '<div class="msel-item" data-name="' + m.name.replace(/"/g, "&quot;") + '">' +
                dot + '<span class="msel-cn">' + (m.cn || "") + '</span><span>' + m.name + '</span></div>';
        };
        function renderMselTabs() {
            const tabs = document.getElementById("msel-tabs");
            if (!tabs) return;
            const counts = { all: maps.length };
            for (const m of maps) { const c = m.cat || "other"; counts[c] = (counts[c] || 0) + 1; }
            tabs.innerHTML = [["all", "全部"]].concat(Object.keys(CAT_LABEL).map(c => [c, CAT_LABEL[c]]))
                .map(([c, label]) =>
                    `<button type="button" class="msel-tab${mselCat === c ? " active" : ""}" data-cat="${c}">${label}${counts[c] ? ` <i>${counts[c]}</i>` : ""}</button>`)
                .join("");
            tabs.querySelectorAll(".msel-tab").forEach(t => t.addEventListener("click", () => {
                mselCat = t.dataset.cat;
                renderMselTabs(); renderMselList();
            }));
        }
        function renderMselList() {
            const items = mselFiltered();
            if (items.length === 0) {
                mselList.innerHTML = '<div class="msel-item empty">没有匹配的地图</div>';
                return;
            }
            if (npcMapSet) {
                // 有 NPC 的排前（同类内），方便扫一眼
                items.sort((a, b) => (npcMapSet.has(b.name.replace(/\\.map$/i, "")) ? 1 : 0) -
                                     (npcMapSet.has(a.name.replace(/\\.map$/i, "")) ? 1 : 0));
            }
            mselList.innerHTML = items.map(mselItem).join("");
            const cur = mselList.querySelector('.msel-item[data-name="' + curName + '"]');
            if (cur) { cur.classList.add("active"); cur.scrollIntoView({ block: "nearest" }); }
        }
        function mselPick(name) {
            const mi = maps.find(m => m.name === name);
            if (!mi) return;
            curName = name;
            mselLabel.textContent = mselLabelOf(mi);
            mselClose();
            loadMap();
            loadCatalog(mi);
        }
        mselBtn.addEventListener("click", (e) => {
            e.stopPropagation();
            if (mselPop.hidden) mselOpen(); else mselClose();
        });
        mselFilter.addEventListener("input", renderMselList);
        mselFilter.addEventListener("keydown", (e) => {
            if (e.key === "Enter") {
                const first = mselList.querySelector('.msel-item[data-name]');
                if (first) mselPick(first.dataset.name);
            } else if (e.key === "ArrowDown" || e.key === "ArrowUp") {
                e.preventDefault();
                const items = [...mselList.querySelectorAll('.msel-item[data-name]')];
                if (!items.length) return;
                let idx = items.findIndex(i => i.classList.contains("active"));
                idx = e.key === "ArrowDown" ? (idx + 1) % items.length : (idx - 1 + items.length) % items.length;
                items.forEach(i => i.classList.remove("active"));
                items[idx].classList.add("active");
                items[idx].scrollIntoView({ block: "nearest" });
            } else if (e.key === "Escape") { mselClose(); }
        });
        mselList.addEventListener("click", (e) => {
            const it = e.target.closest('.msel-item[data-name]');
            if (it) mselPick(it.dataset.name);
        });
        window.addEventListener("click", (e) => {
            if (!mselPop.hidden && !e.target.closest("#map-sel")) mselClose();
        });
        window.addEventListener("keydown", (e) => {
            if (e.key === "Escape" && !mselPop.hidden) mselClose();
        });
        // ---- Hash & State Memory ----
        function updateUrlHash() {
            if (!curMap()) return;
            const s = curScale();
            const ax = Math.round(anchorX || (vp.scrollLeft + vp.clientWidth / 2) * s);
            const ay = Math.round(anchorY || (vp.scrollTop + vp.clientHeight / 2) * s);
            const g = document.getElementById("chk-g").checked ? 1 : 0;
            const m = document.getElementById("chk-m").checked ? 1 : 0;
            const f = document.getElementById("chk-f").checked ? 1 : 0;
            const hash = `#map=${encodeURIComponent(curMap().name)}&cur=${cur}&x=${ax}&y=${ay}&g=${g}&m=${m}&f=${f}` +
                (window.__hlName ? `&hl=${encodeURIComponent(window.__hlName)}` : "");
            history.replaceState(null, '', hash);
            saveState();
        }

        // ---- Toast System ----
        function showToast(title, body, duration = 5000) {
            const container = document.getElementById("toast-container");
            const toast = document.createElement("div");
            toast.className = "toast";
            toast.innerHTML = `<div class="toast-title"><span>🎉</span> ${title}</div><div class="toast-body">${body}</div>`;
            container.appendChild(toast);
            requestAnimationFrame(() => toast.classList.add("show"));
            setTimeout(() => {
                toast.classList.remove("show");
                setTimeout(() => toast.remove(), 400);
            }, duration);
        }

        // ---- Custom Confirm Modal ----
        function showConfirm(title, message) {
            return new Promise((resolve) => {
                const modal = document.getElementById("custom-modal-overlay");
                const mTitle = document.getElementById("modal-title");
                const mMsg = document.getElementById("modal-msg");
                const btnCancel = document.getElementById("btn-modal-cancel");
                const btnConfirm = document.getElementById("btn-modal-confirm");

                mTitle.textContent = title || "⚡ 提示";
                mMsg.textContent = message || "确定要执行此操作吗？";
                modal.style.display = "flex";

                function cleanup(result) {
                    modal.style.display = "none";
                    btnCancel.onclick = null;
                    btnConfirm.onclick = null;
                    resolve(result);
                }

                btnCancel.onclick = () => cleanup(false);
                btnConfirm.onclick = () => cleanup(true);
            });
        }

        const overlay = document.getElementById("loading-overlay");
        const loadingTitle = document.getElementById("loading-title");
        const loadingDetail = document.getElementById("loading-detail");

        function showLoading(title, detail) {
            if (title) loadingTitle.textContent = title;
            if (detail) loadingDetail.textContent = detail;
            overlay.style.display = "flex";
        }
        function hideLoading() {
            overlay.style.display = "none";
        }

        // ---- init ----
        const STATE_KEY = "zircon-map-viewer-v1";
        function saveState() {
            try {
                const mi = curMap();
                if (!mi) return;
                localStorage.setItem(STATE_KEY, JSON.stringify({
                    map: mi.name,
                    cur: cur,
                    ax: Math.round(anchorX), ay: Math.round(anchorY),
                    g: gOn(), m: mOn(), f: fOn(),
                    // 图层开关与面板布局一并记住（"记住最后状态"）
                    ents: document.getElementById("chk-ents").checked,
                    resp: document.getElementById("chk-resp").checked,
                    grid: document.getElementById("chk-grid").checked,
                    panels: loadPanelLayoutRaw(),
                }));
            } catch (e) {}
        }
        function loadState() {
            try {
                const raw = localStorage.getItem(STATE_KEY);
                return raw ? JSON.parse(raw) : null;
            } catch (e) { return null; }
        }

        // ---- 面板拖拽：按住标题拖动，8px 网格对齐，位置持久化 ----
        const DRAG_PANELS = ["conn-panel", "cat-panel", "quest-panel", "legend-panel",
                             "pick-panel", "npc-panel", "resp-panel", "minimap"];
        const DRAG_GRID = 8;
        const _snap = v => Math.round(v / DRAG_GRID) * DRAG_GRID;
        function _dragHandle(el, panel) {
            if (!el) return false;
            if (panel.id === "minimap") return el.classList && el.classList.contains("mm-title");
            return el.tagName === "H4";
        }
        function loadPanelLayoutRaw() {
            const L = {};
            for (const id of DRAG_PANELS) {
                const p = document.getElementById(id);
                if (p && p.style.position === "fixed" && p.style.left) {
                    L[id] = { l: p.style.left, t: p.style.top };
                }
            }
            return L;
        }
        function savePanelLayout() {
            try {
                const st = loadState() || {};
                st.panels = loadPanelLayoutRaw();
                localStorage.setItem(STATE_KEY, JSON.stringify(st));
            } catch (e) {}
        }
        function applyPanelLayout(L) {
            for (const id in (L || {})) {
                const p = document.getElementById(id);
                const v = L[id];
                if (p && v && v.l && v.t) {
                    p.style.position = "fixed";
                    p.style.left = v.l; p.style.top = v.t;
                    p.style.right = "auto"; p.style.bottom = "auto";
                    p.style.zIndex = 100;
                }
            }
        }
        function _panelDragStart(ev) {
            const panel = ev.currentTarget;
            if (!_dragHandle(ev.target, panel)) return;
            if (ev.button !== undefined && ev.button !== 0) return;
            const touch = ev.touches && ev.touches[0];
            if (ev.type === "touchstart" && ev.touches.length > 1) return;
            const cx = touch ? touch.clientX : ev.clientX;
            const cy = touch ? touch.clientY : ev.clientY;
            const r = panel.getBoundingClientRect();
            const offX = cx - r.left, offY = cy - r.top;
            panel.classList.add("panel-dragging");
            const move = (e2) => {
                const t = e2.touches && e2.touches[0];
                const x = t ? t.clientX : e2.clientX, y = t ? t.clientY : e2.clientY;
                panel.style.position = "fixed";     // 脱离原布局（含 flex 面板列）
                panel.style.left = _snap(Math.max(0, Math.min(window.innerWidth - r.width, x - offX))) + "px";
                panel.style.top = _snap(Math.max(0, Math.min(window.innerHeight - 40, y - offY))) + "px";
                panel.style.right = "auto";
                panel.style.bottom = "auto";
                panel.style.zIndex = 100;
                if (t) e2.preventDefault();
            };
            const up = () => {
                panel.classList.remove("panel-dragging");
                document.removeEventListener("mousemove", move);
                document.removeEventListener("mouseup", up);
                document.removeEventListener("touchmove", move);
                document.removeEventListener("touchend", up);
                savePanelLayout();
            };
            document.addEventListener("mousemove", move);
            document.addEventListener("mouseup", up);
            document.addEventListener("touchmove", move, { passive: false });
            document.addEventListener("touchend", up);
            ev.preventDefault();
        }
        for (const id of DRAG_PANELS) {
            const p = document.getElementById(id);
            if (p) { p.addEventListener("mousedown", _panelDragStart); p.addEventListener("touchstart", _panelDragStart, { passive: false }); }
        }

        async function init() {
            const res = await fetch("/api/maps");
            maps = await res.json();
            if (!maps.length) return;

            // Parse Hash params: #map=0.map&cur=1&x=1200&y=800 (hash wins over saved state)
            let targetMap = maps[0].name;
            let targetCur = null;
            let targetX = null;
            let targetY = null;
            const st = loadState();
            const hasHash = !!location.hash;
            window.__hlName = null;
            window.__userAnchor = false;   // 用户显式指定视点后不再自动居中到 NPC 质心
            if (hasHash) {
                const matchMap = location.hash.match(/map=([^&]+)/);
                const matchCur = location.hash.match(/cur=(\\d+)/);
                const matchX   = location.hash.match(/x=(\\d+)/);
                const matchY   = location.hash.match(/y=(\\d+)/);
                const matchHl  = location.hash.match(/hl=([^&]+)/);
                if (matchMap) {
                    const parsed = decodeURIComponent(matchMap[1]);
                    if (maps.some(m => m.name.toLowerCase() === parsed.toLowerCase())) {
                        targetMap = parsed;
                    }
                }
                if (matchCur) targetCur = parseInt(matchCur[1]);
                if (matchX) targetX = parseInt(matchX[1]);
                if (matchY) targetY = parseInt(matchY[1]);
                if (matchHl) window.__hlName = decodeURIComponent(matchHl[1]);
            } else if (st && maps.some(m => m.name === st.map)) {
                targetMap = st.map;
                targetCur = st.cur;
                targetX = st.ax;
                targetY = st.ay;
            }
            // 恢复 UI 状态（面板布局 + 图层开关），与 hash 深链不冲突
            if (st) {
                applyPanelLayout(st.panels);
                if (typeof st.ents === "boolean") document.getElementById("chk-ents").checked = st.ents;
                if (typeof st.resp === "boolean") document.getElementById("chk-resp").checked = st.resp;
                if (typeof st.grid === "boolean") document.getElementById("chk-grid").checked = st.grid;
            }

            mselPick(targetMap);

            if (targetCur !== null && targetCur >= 0 && targetCur < scaleLadder.length) {
                cur = targetCur;
            }
            if (targetX !== null && targetY !== null) {
                anchorX = targetX;
                anchorY = targetY;
                window.__userAnchor = true;
            }
            render(true);
            updateUrlHash();   // 立即用实际加载的地图/坐标回写 URL(自愈坏 hash)
            saveState();
        }
        init();

        // 轮询后台预生成进度
        async function pollProgress() {
            try {
                const res = await fetch("/api/progress");
                const data = await res.json();
                const box = document.getElementById("progress-box");
                if (data.running) {
                    box.style.display = "inline-flex";
                    document.getElementById("progress-bar-fill").style.width = data.percent + "%";
                    document.getElementById("progress-text").textContent = `${data.percent}% (${data.current}/${data.total} · 生成中 ${data.current_map})`;
                } else if (data.total > 0 && data.done + data.failed >= data.total) {
                    box.style.display = "inline-flex";
                    document.getElementById("progress-bar-fill").style.width = "100%";
                    document.getElementById("progress-text").textContent = `100% (全库 ${data.total} 张地图预生成完毕！)`;
                } else {
                    box.style.display = "none";
                }
            } catch (e) {}
        }
        setInterval(pollProgress, 1000);
        pollProgress();

        window.addEventListener("hashchange", () => {
            if (!location.hash) return;
            const matchMap = location.hash.match(/map=([^&]+)/);
            if (matchMap) {
                const parsed = decodeURIComponent(matchMap[1]);
                const mi = curMap();
                if (mi && mi.name.toLowerCase() !== parsed.toLowerCase()) {
                    init();
                }
            }
        });

        vp.addEventListener("scroll", () => {
            drawTiles();
            drawMini();
            drawGrid();
            setAnchorFromView();
            updateUrlHash();
        });

        document.getElementById("btn-zoom-in").addEventListener("click", () => {
            if (cur <= 0) return; setAnchorFromView(); cur--; render(true); updateUrlHash(); saveState();
        });
        document.getElementById("btn-zoom-out").addEventListener("click", () => {
            if (cur >= scaleLadder.length - 1) return; setAnchorFromView(); cur++; render(true); updateUrlHash(); saveState();
        });
        document.getElementById("btn-fit").addEventListener("click", () => {
            // fit whole map into viewport: pick smallest scale that fits
            let fitCur = 0;
            for (let i = 0; i < scaleLadder.length; i++) {
                const s = 1 << scaleLadder[i];
                if (worldW / s <= vp.clientWidth * 0.98 && worldH / s <= vp.clientHeight * 0.98) {
                    fitCur = i; break;
                }
            }
            cur = fitCur;
            anchorX = worldW / 2; anchorY = worldH / 2;
            render(true);
            updateUrlHash();
            saveState();
        });
        document.getElementById("btn-clear-cache").addEventListener("click", async () => {
            const ok = await showConfirm("🔄 重新生成", `确定要清除全部缓存并重新生成全库 ${maps.length} 张地图吗？\n\n将删除磁盘 tile 缓存，后台并行重新预生成所有地图（4 线程）。\n\n生成过程约需 10-30 分钟，期间可正常浏览，顶部进度条实时更新。`);
            if (!ok) return;
            statusEl.textContent = "正在清除缓存并触发全库预生成…";
            try {
                await fetch("/api/rebuild_all", { method: "POST" });
            } catch (e) {}
            // force the current map to re-render from scratch
            version++;
            imgEl.src = "";
            render(true);
            showToast("缓存清除完成", `已清空全部缓存，后台正在并行重新预生成 ${maps.length} 张地图。<br>顶部进度条实时更新。`);
            saveState();
        });

        document.getElementById("chk-g").addEventListener("change", () => { render(); updateUrlHash(); saveState(); });
        document.getElementById("chk-m").addEventListener("change", () => { render(); updateUrlHash(); saveState(); });
        document.getElementById("chk-f").addEventListener("change", () => { render(); updateUrlHash(); saveState(); });
        document.getElementById("chk-ents").addEventListener("change", () => { drawEntities(); saveState(); });
        document.getElementById("chk-grid").addEventListener("change", () => { drawGrid(); saveState(); });
        document.getElementById("btn-legend").addEventListener("click", () => {
        document.getElementById("legend-panel").innerHTML =
            '<div class="lg-row"><span class="lg-dot" style="background:#8cf;box-shadow:0 0 4px #8cf;"></span> NPC（db_names 中文名）</div>' +
            '<div class="lg-row"><span class="lg-dot" style="background:#7CFF7C;box-shadow:0 0 4px #7CFF7C;"></span> 商店类 NPC / 建筑 (Building)</div>' +
            '<div class="lg-row"><span class="lg-dot" style="background:#ffd54a;box-shadow:0 0 4px #ffd54a;"></span> 出生点 / 省际传送 (Province)</div>' +
            '<div class="lg-row"><span class="lg-dot" style="background:#ff6b6b;box-shadow:0 0 4px #ff6b6b;"></span> 怪物刷新 / 洞穴入口 (Cave/Down)</div>' +
            '<div class="lg-row"><span class="lg-dot" style="background:#72d6ff;box-shadow:0 0 4px #72d6ff;"></span> 城镇出口 (Exit/Up)</div>' +
            '<div class="lg-row"><span style="color:#aaa;font-size:11px;">→ 出口（通往对面图） · ← 入口（从对面图来）<br>圆点可点击跳转对面地图 · 左上面板=连接列表</div>';
        });

        // ---- right-bottom status bar: coord + zoom + map ----
        const coordEl = document.getElementById("coord-info");
        const zoomEl = document.getElementById("zoom-info");
        const mapInfoEl = document.getElementById("map-info");
        function updateStatusBar(cx, cy) {
            const mi = curMap();
            if (!mi) return;
            const s = curScale();
            const pct = (100 / s).toFixed(0) + "%";
            zoomEl.textContent = "比例 " + pct;
            mapInfoEl.textContent = (mi.cn ? mi.cn + " · " : "") + mi.name.replace(".map", "");
            if (cx !== undefined && cy !== undefined && cx >= 0 && cy >= 0) {
                coordEl.textContent = "格 " + cx + "," + cy;
            } else {
                coordEl.textContent = "格 —,—";
            }
        }
        // mouse move -> coord (game-accurate 48x32)
        vp.addEventListener("mousemove", (e) => {
            const mi = curMap();
            if (!mi) return;
            const s = curScale();
            const rect = vp.getBoundingClientRect();
            const wx = (vp.scrollLeft + e.clientX - rect.left) * s;
            const wy = (vp.scrollTop + e.clientY - rect.top) * s;
            const cx = Math.floor(wx / 48), cy = Math.floor(wy / 32);
            updateStatusBar(cx, cy);
        });
        vp.addEventListener("mouseleave", () => updateStatusBar(-1, -1));
        vp.addEventListener("scroll", () => { drawTiles(); updateStatusBar(); saveState(); });

        // G/M/F hotkeys toggle layers
        window.addEventListener("keydown", (e) => {
            if (e.target.tagName === "INPUT" || e.target.tagName === "TEXTAREA") return;
            const k = e.key.toLowerCase();
            if (k === "g") { const c = document.getElementById("chk-g"); c.checked = !c.checked; c.dispatchEvent(new Event("change")); }
            else if (k === "m") { const c = document.getElementById("chk-m"); c.checked = !c.checked; c.dispatchEvent(new Event("change")); }
            else if (k === "f") { const c = document.getElementById("chk-f"); c.checked = !c.checked; c.dispatchEvent(new Event("change")); }
            else if (k === "e") { const c = document.getElementById("chk-ents"); c.checked = !c.checked; c.dispatchEvent(new Event("change")); }
        });

        // Drag to pan
        vp.addEventListener("mousedown", (e) => {
            dragging = true; vp.classList.add("dragging");
            dragX = e.clientX; dragY = e.clientY;
            scX = vp.scrollLeft; scY = vp.scrollTop;
            e.preventDefault();
        });
        window.addEventListener("mousemove", (e) => {
            if (!dragging) return;
            vp.scrollLeft = scX - (e.clientX - dragX);
            vp.scrollTop  = scY - (e.clientY - dragY);
            drawMini();
            drawTiles();
        });
        window.addEventListener("mouseup", () => { dragging = false; vp.classList.remove("dragging"); });

        // Ctrl + 滚轮: zoom around the mouse point (swap ladder level)
        window.addEventListener("wheel", (e) => {
            if (!e.ctrlKey) return;
            e.preventDefault();
            const rect = vp.getBoundingClientRect();
            const mx = e.clientX - rect.left, my = e.clientY - rect.top;
            const s = curScale();
            anchorX = (vp.scrollLeft + mx) * s;
            anchorY = (vp.scrollTop + my) * s;
            let changed = false;
            if (e.deltaY < 0 && cur > 0) { cur--; changed = true; }
            else if (e.deltaY > 0 && cur < scaleLadder.length - 1) { cur++; changed = true; }
            if (changed) { render(true); updateUrlHash(); }
        }, { passive: false });

        // Minimap click/drag -> pan main view
        mmBox.addEventListener("mousedown", (e) => {
            miniDrag = true;
            const r = mmBox.getBoundingClientRect();
            miniPan((e.clientX - r.left) / r.width * worldW,
                    (e.clientY - r.top) / r.height * worldH);
            e.preventDefault();
        });
        window.addEventListener("mousemove", (e) => {
            if (!miniDrag) return;
            const r = mmBox.getBoundingClientRect();
            miniPan((e.clientX - r.left) / r.width * worldW,
                    (e.clientY - r.top) / r.height * worldH);
        });
        window.addEventListener("mouseup", () => { miniDrag = false; });

        // ============================================================ 地图工坊
        // 六大增强：刷怪热力 / 任务叠加 / 等级总览 / 连通图谱 / NPC 审计 / 坐标拾取

        // ---- 视图切换（地图 / 总览 / 连通） ----
        const viewTabs = document.querySelectorAll(".vtab");
        let curView = "map";
        const ovView = document.getElementById("overview-view");
        const gvView = document.getElementById("graph-view");
        const mapOnlyEls = () => ["#minimap", "#statusbar", "#cat-panel", "#conn-panel", "#npc-panel", "#resp-panel", "#quest-panel",
            "#pick-panel", "#port-tooltip", "#port-detail", "#ent-tooltip", "#heat-tooltip"].map(s => document.querySelector(s));
        function showView(v) {
            curView = v;
            viewTabs.forEach(t => t.classList.toggle("active", t.dataset.view === v));
            vp.style.display = v === "map" ? "" : "none";
            ovView.style.display = v === "overview" ? "block" : "none";
            gvView.style.display = v === "graph" ? "block" : "none";
            if (v !== "map") {
                mapOnlyEls().forEach(el => { if (el) el.style.display = "none"; });
            } else {
                document.getElementById("statusbar").style.display = "flex";
                document.getElementById("minimap").style.display = "";
                if (questData) questPanel.style.display = "block";
                if (pickA) pickPanel.style.display = "block";
                for (const id of ["cat-panel", "conn-panel", "npc-panel"]) {
                    const el = document.getElementById(id);
                    if (el && el.innerHTML.trim()) el.style.display = "block";
                }
                renderRespPanel(curMap());   // 刷新面板按开关/数据状态恢复
            }
            if (v === "overview") { initOverview(); }
            if (v === "graph") { initGraph(); }
        }
        viewTabs.forEach(t => t.addEventListener("click", () => showView(t.dataset.view)));

        const heatCanvas = document.getElementById("heat-canvas");
        const heatCtx = heatCanvas.getContext("2d");
        const heatTooltip = document.getElementById("heat-tooltip");
        const chkResp = document.getElementById("chk-resp");
        const HEAT_FILL = { t1: "rgba(96,210,96,.26)", t2: "rgba(255,213,74,.28)",
                            t3: "rgba(255,140,50,.30)", t4: "rgba(255,60,60,.32)" };
        const HEAT_EDGE = { t1: "rgba(96,210,96,.7)", t2: "rgba(255,213,74,.75)",
                            t3: "rgba(255,140,50,.8)", t4: "rgba(255,60,60,.85)" };
        let respCache = {};      // map name -> {groups:[{x,y,half,entries[]}], raw}
        async function loadRespawns(mi) {
            if (respCache[mi.name]) { drawHeat(); renderRespPanel(mi); return; }
            try {
                const res = await fetch("/api/respawns?map=" + encodeURIComponent(mi.name));
                const d = await res.json();
                if (!d.ok) { chkResp.disabled = true; chkResp.title = "刷怪数据不可用（workspace RespawnInfo 缺失）"; respCache[mi.name] = null; return; }
                // 同 Region 的多条 respawn 合成一个色块（tier 取最高），tooltip 列全部怪物
                const gmap = {};
                for (const r of d.respawns) {
                    const k = r.x + "," + r.y + "," + r.half;
                    const g = gmap[k] = gmap[k] || { x: r.x, y: r.y, half: r.half, entries: [] };
                    g.entries.push(r);
                }
                const groups = Object.values(gmap).map(g => {
                    const best = g.entries.reduce((a, b) => a.count >= b.count ? a : b);
                    return { ...g, tier: best.tier };
                });
                respCache[mi.name] = { groups, raw: d.respawns };
            } catch (e) { respCache[mi.name] = null; }
            drawHeat();
            renderRespPanel(mi);
        }
        function drawHeat() {
            const mi = curMap();
            const d = mi ? respCache[mi.name] : null;
            if (!chkResp.checked || !d) { heatCanvas.width = 0; heatCanvas.height = 0; return; }
            const s = curScale();
            const dpr = window.devicePixelRatio || 1;
            const w = vp.clientWidth, h = vp.clientHeight;
            // canvas 随内容滚动，钉在可视区（left/top=scroll），内容保持视口相对坐标；
            // 滚动事件里重绘（见 vp scroll 监听）。
            heatCanvas.style.left = vp.scrollLeft + "px";
            heatCanvas.style.top = vp.scrollTop + "px";
            heatCanvas.width = w * dpr; heatCanvas.height = h * dpr;
            heatCanvas.style.width = w + "px"; heatCanvas.style.height = h + "px";
            const ctx = heatCtx;
            ctx.setTransform(dpr, 0, 0, dpr, 0, 0);
            ctx.clearRect(0, 0, w, h);
            // Region 方块：质心 (x,y) ± half 格（世界格 -> 屏幕：x*48/s, y*32/s）
            for (const g of d.groups) {
                const cx = g.x * 48 / s - vp.scrollLeft, cy = g.y * 32 / s - vp.scrollTop;
                const bw = g.half * 2 * 48 / s, bh = g.half * 2 * 32 / s;
                if (cx + bw / 2 < 0 || cy + bh / 2 < 0 || cx - bw / 2 > w || cy - bh / 2 > h) continue;
                ctx.fillStyle = HEAT_FILL[g.tier]; ctx.strokeStyle = HEAT_EDGE[g.tier];
                ctx.lineWidth = 1;
                ctx.fillRect(cx - bw / 2, cy - bh / 2, bw, bh);
                ctx.strokeRect(cx - bw / 2, cy - bh / 2, bw, bh);
                if (window.__hlRegion === g.x + "," + g.y + "," + g.half) {
                    // 面板点击的刷新区：白框高亮
                    ctx.strokeStyle = "#ffffff"; ctx.lineWidth = 3;
                    ctx.strokeRect(cx - bw / 2, cy - bh / 2, bw, bh);
                }
            }
        }
        // 悬停命中检测（世界格坐标 -> 最近 Region 方块）
        vp.addEventListener("mousemove", (e) => {
            if (!chkResp.checked || curView !== "map") { heatTooltip.style.display = "none"; return; }
            const mi = curMap();
            const d = mi ? respCache[mi.name] : null;
            if (!d) { heatTooltip.style.display = "none"; return; }
            const rect = vp.getBoundingClientRect();
            const s = curScale();
            const wx = (vp.scrollLeft + e.clientX - rect.left) * s;
            const wy = (vp.scrollTop + e.clientY - rect.top) * s;
            const cx = wx / 48, cy = wy / 32;
            let best = null;
            for (const g of d.groups) {
                if (Math.abs(cx - g.x) <= g.half && Math.abs(cy - g.y) <= g.half) {
                    if (!best || g.half < best.half) best = g;
                }
            }
            if (!best) { heatTooltip.style.display = "none"; return; }
            heatTooltip.innerHTML = "<b>👹 刷新区</b> " + MAP_CN[mi.name.replace(/\\.map$/i, "")] +
                "<br>" + best.entries.map(r =>
                    `${r.mc} ×${r.count} · 刷新延迟 ${r.delay}s · DropSet ${r.dropset}` +
                    (r.boss ? " · 👑BOSS" : "")).join("<br>");
            heatTooltip.style.display = "block";
            heatTooltip.style.left = Math.min(e.clientX + 14, window.innerWidth - 300) + "px";
            heatTooltip.style.top = Math.max(4, e.clientY - 20) + "px";
        });
        vp.addEventListener("mouseleave", () => { heatTooltip.style.display = "none"; });
        chkResp.addEventListener("change", () => { drawHeat(); renderRespPanel(curMap()); });

        // ---- 2. 任务叠加模式（VisitRegion 金框 / KillMonster·GainItem 红色脉冲） ----
        const questSvg = document.getElementById("quest-svg");
        const questPanel = document.getElementById("quest-panel");
        const questSel = document.getElementById("quest-sel");
        let questList = null, questData = null;   // questData = 当前选中任务覆盖层
        async function loadQuests() {
            if (questList) return;
            try {
                const res = await fetch("/api/quests");
                const d = await res.json();
                if (!d.ok) {
                    questSel.innerHTML = '<option value="">📜 任务数据不可用</option>';
                    questSel.disabled = true; questSel.title = "workspace QuestInfo 缺失";
                    return;
                }
                questList = d.quests;
                for (const q of questList) {
                    const opt = document.createElement("option");
                    opt.value = q.id;
                    opt.textContent = `📜 ${q.name} (${q.kinds.join("+")})`;
                    questSel.appendChild(opt);
                }
            } catch (e) { questSel.innerHTML = '<option value="">📜 任务数据不可用</option>'; questSel.disabled = true; }
        }
        questSel.addEventListener("change", async () => {
            const id = questSel.value;
            if (!id) { questData = null; drawQuest(); questPanel.style.display = "none"; return; }
            try {
                const res = await fetch("/api/quest?id=" + encodeURIComponent(id));
                const d = await res.json();
                questData = d.ok ? d : null;
            } catch (e) { questData = null; }
            drawQuest(); renderQuestPanel();
        });
        function drawQuest() {
            const mi = curMap();
            questSvg.setAttribute("width", vp.clientWidth);
            questSvg.setAttribute("height", vp.clientHeight);
            if (!mi || !questData) { questSvg.innerHTML = ""; return; }
            const s = curScale();
            const hereStem = mi.name.replace(/\\.map$/i, "");
            const px = v => v * 48 / s;   // 内容坐标：svg 随 #viewport 内容滚动
            const py = v => v * 32 / s;
            let html = "";
            // VisitRegion -> 金色描边 + 半透明填充
            for (const r of (questData.regions || [])) {
                if (String(r.map) !== hereStem) continue;
                const bw = r.half * 2 * 48 / s, bh = r.half * 2 * 32 / s;
                const x = px(r.x) - bw / 2, y = py(r.y) - bh / 2;
                html += `<rect x="${x}" y="${y}" width="${bw}" height="${bh}" fill="rgba(255,213,74,.18)" stroke="#ffd54a" stroke-width="2.5"><title>任务区域：${r.desc || r.idx}</title></rect>`;
            }
            // KillMonster/GainItem 怪物点位 -> 红色/橙色脉冲
            for (const m of (questData.monsters || [])) {
                const color = m.kind === "KillMonster" ? "#ff4b4b" : "#ff9b3d";
                for (const p of (m.points || [])) {
                    if (String(p.map) !== hereStem) continue;
                    const cx = px(p.x), cy = py(p.y);
                    if (cx < vp.scrollLeft - 40 || cy < vp.scrollTop - 40 || cx > vp.scrollLeft + vp.clientWidth + 40 || cy > vp.scrollTop + vp.clientHeight + 40) continue;
                    html += `<g class="qmarker"><circle class="qkill" data-jmap="${p.map}" data-x="${p.x}" data-y="${p.y}" cx="${cx}" cy="${cy}" r="7" fill="${color}" stroke="#fff" stroke-width="1.5" opacity=".95"><title>${m.m} ×${p.count}${m.item ? " · 掉 " + m.item : ""}</title></circle></g>`;
                }
            }
            questSvg.innerHTML = html;
        }
        questSvg.addEventListener("click", (e) => {
            const c = e.target.closest("circle.qkill");
            if (c) e.stopPropagation();
        });
        // 步骤序列（MAP-P1-01）：monster 步骤 + region 步骤展开成可播放单元
        let questSteps = [], questStepIdx = -1;
        function questStepList() {
            // 与面板 .qstep 行一一对应：每个 monster 取首个有图文件的点，每个 region 一步
            const hasMap = st => maps.some(x => x.name === String(st) + ".map");
            const steps = [];
            for (const m of (questData.monsters || [])) {
                const p = (m.points || [])[0];   // 与面板 ▶定位 按钮同一判定
                if (p && hasMap(p.map)) steps.push({ kind: m.kind, label: (m.item || m.m) + " ×" + m.amount, map: String(p.map), x: +p.x, y: +p.y });
            }
            for (const r of (questData.regions || []))
                if (hasMap(r.map)) steps.push({ kind: "VisitRegion", label: "探访 " + (MAP_CN[r.map] || r.map), map: String(r.map), x: +r.x, y: +r.y });
            return steps;
        }
        function gotoQuestStep(i) {
            if (!questSteps.length) return;
            questStepIdx = (i + questSteps.length) % questSteps.length;   // 循环播放
            const st = questSteps[questStepIdx];
            showView("map");
            history.replaceState(null, "", `#map=${encodeURIComponent(st.map + ".map")}&cur=0&x=${Math.round(st.x * 48)}&y=${Math.round(st.y * 32)}&g=1&m=1&f=1`);
            init();
            markCurrentStep();
        }
        function markCurrentStep() {
            questPanel.querySelectorAll(".qstep").forEach(el => {
                el.classList.toggle("current", el.dataset.step !== undefined && +el.dataset.step === questStepIdx);
            });
        }
        function renderQuestPanel() {
            if (!questData) { questPanel.style.display = "none"; return; }
            const q = questData.quest;
            const kindLabel = { KillMonster: "讨伐", GainItem: "收集", VisitRegion: "探访" };
            let html = `<h4>📜 ${q.name}</h4>`;
            html += `<div class="qnav"><button id="qprev" type="button">⏮ 上一步</button>` +
                `<button id="qplay-all" type="button">▶ 逐步播放</button>` +
                `<button id="qnext" type="button">下一步 ⏭</button></div>`;
            let stepNo = 0;
            for (const m of (questData.monsters || [])) {
                const byMap = {};
                for (const p of (m.points || [])) (byMap[p.map] = byMap[p.map] || []).push(p);
                const spots = Object.keys(byMap).map(st => {
                    const exists = maps.some(x => x.name === st + ".map");
                    const jump = exists ? ` class="qmap" data-jmap="${st}" data-x="${byMap[st][0].x}" data-y="${byMap[st][0].y}"` : "";
                    return `<span${jump}>${MAP_CN[st] || st}${exists ? "" : " (无图文件)"}</span>`;
                }).join(" · ");
                const firstPt = (m.points || [])[0];
                const playable = firstPt && maps.some(x => x.name === String(firstPt.map) + ".map");
                const playBtn = playable ? `<button class="qplay" type="button" data-step="${stepNo}">▶ 定位</button>` : "";
                html += `<div class="qstep ${m.kind === "KillMonster" ? "kill" : "item"}"${playable ? ` data-step="${stepNo}"` : ""}>${playBtn}` +
                    `<b>${m.item || m.m}</b> ${kindLabel[m.kind] || m.kind} ×${m.amount}` +
                    `<br><span style="color:#8a8a98">怪物：</span>${m.m}` +
                    (spots ? `<br><span style="color:#8a8a98">位置：</span>${spots}` : "（无刷新点数据）") + `</div>`;
                stepNo++;
            }
            for (const r of (questData.regions || [])) {
                const exists = maps.some(x => x.name === String(r.map) + ".map");
                const playBtn = exists ? `<button class="qplay" type="button" data-step="${stepNo}">▶ 定位</button>` : "";
                html += `<div class="qstep visit"${exists ? ` data-step="${stepNo}"` : ""}>${playBtn}<b>探访区域</b>：${MAP_CN[r.map] || r.map} · ${r.desc || r.idx}</div>`;
                stepNo++;
            }
            if (!questData.monsters.length && !questData.regions.length) html += '<div class="qstep">该任务无地理步骤</div>';
            questPanel.innerHTML = html;
            questPanel.style.display = "block";
            questSteps = questStepList();
            // 播放控制
            const prev = questPanel.querySelector("#qprev"), next = questPanel.querySelector("#qnext"), playAll = questPanel.querySelector("#qplay-all");
            if (prev) prev.addEventListener("click", () => gotoQuestStep(questStepIdx < 0 ? 0 : questStepIdx - 1));
            if (next) next.addEventListener("click", () => gotoQuestStep(questStepIdx + 1));
            if (playAll) playAll.addEventListener("click", () => {
                if (window.__qTimer) { clearInterval(window.__qTimer); window.__qTimer = null; playAll.textContent = "▶ 逐步播放"; return; }
                gotoQuestStep(0);
                playAll.textContent = "⏸ 停止";
                window.__qTimer = setInterval(() => gotoQuestStep(questStepIdx + 1), 4000);
            });
            questPanel.querySelectorAll(".qplay").forEach(b =>
                b.addEventListener("click", (e) => { e.stopPropagation(); if (window.__qTimer) { clearInterval(window.__qTimer); window.__qTimer = null; } gotoQuestStep(+b.dataset.step); }));
            markCurrentStep();
            questPanel.querySelectorAll(".qmap").forEach(el => el.addEventListener("click", () => {
                showView("map");
                history.replaceState(null, "", `#map=${encodeURIComponent(el.dataset.jmap + ".map")}&cur=0&x=${Math.round(Number(el.dataset.x) * 48)}&y=${Math.round(Number(el.dataset.y) * 32)}&g=1&m=1&f=1`);
                init();
            }));
        }

        // ---- 6. 坐标拾取器（点击取格坐标 / Shift 双点曼哈顿距离） ----
        const pickSvg = document.getElementById("pick-svg");
        const pickPanel = document.getElementById("pick-panel");
        let pickA = null, pickB = null, pickDown = null;
        vp.addEventListener("mousedown", (e) => { pickDown = [e.clientX, e.clientY]; });
        vp.addEventListener("click", (e) => {
            if (pickDown && (Math.abs(e.clientX - pickDown[0]) + Math.abs(e.clientY - pickDown[1])) > 5) return;  // 拖拽后的 click
            const mi = curMap();
            if (!mi) return;
            const rect = vp.getBoundingClientRect();
            const s = curScale();
            const cx = Math.floor((vp.scrollLeft + e.clientX - rect.left) * s / 48);
            const cy = Math.floor((vp.scrollTop + e.clientY - rect.top) * s / 32);
            if (e.shiftKey) { pickB = [cx, cy]; if (!pickA) pickA = [cx, cy]; }
            else { pickA = [cx, cy]; pickB = null; }
            renderPick();
        });
        function renderPick() {
            pickSvg.setAttribute("width", vp.clientWidth);
            pickSvg.setAttribute("height", vp.clientHeight);
            const s = curScale();
            const dot = (p, label, color) => {
                const x = p[0] * 48 / s + 24, y = p[1] * 32 / s + 16;   // 内容坐标：svg 随内容滚动
                return `<circle cx="${x}" cy="${y}" r="8" fill="none" stroke="${color}" stroke-width="2.5"><title>${label} (${p[0]},${p[1]})</title></circle>` +
                    `<text x="${x + 11}" y="${y + 4}" font-size="12" font-weight="700" fill="${color}" style="paint-order:stroke;stroke:#000;stroke-width:2px">${label}</text>`;
            };
            pickSvg.innerHTML = (pickA ? dot(pickA, "A", "#72d6ff") : "") + (pickB ? dot(pickB, "B", "#3de88a") : "") +
                ((pickA && pickB) ? `<line x1="${pickA[0] * 48 / s + 24}" y1="${pickA[1] * 32 / s + 16}" x2="${pickB[0] * 48 / s + 24}" y2="${pickB[1] * 32 / s + 16}" stroke="#ffd54a" stroke-dasharray="5 4" stroke-width="1.5" opacity=".8"/>` : "");
            if (!pickA) { pickPanel.style.display = "none"; return; }
            const copyBtn = (t, label) => `<button class="pick-copy" data-copy="${t}">复制${label || ""}</button>`;
            let html = `🎯 拾取 A: <b>(${pickA[0]}, ${pickA[1]})</b>${copyBtn(pickA[0] + ", " + pickA[1])}`;
            if (pickB) {
                const dist = Math.abs(pickB[0] - pickA[0]) + Math.abs(pickB[1] - pickA[1]);
                html += `<br>🎯 拾取 B: <b>(${pickB[0]}, ${pickB[1]})</b>${copyBtn(pickB[0] + ", " + pickB[1])}` +
                    `<br><span class="pick-dist">📏 曼哈顿距离：${dist} 格${copyBtn(String(dist), "距离")}</span>`;
            }
            html += `<br><span class="pick-hint">点击取 A · Shift+点击取 B 测距 · 双击清除</span>`;
            pickPanel.innerHTML = html;
            pickPanel.style.display = "block";
            attachCopy(pickPanel);
        }
        vp.addEventListener("dblclick", () => { pickA = pickB = null; renderPick(); });

        // ---- 3. 等级分层总览 + 5. NPC 审计 ----
        let ovData = null, ovAudit = null, ovFilter = "all", ovColorMode = "lvl", ovObserver = null;
        const NPC_TIERS = [
            { max: 0, cls: "none", label: "0" }, { max: 5, cls: "low", label: "1-5" },
            { max: 15, cls: "mid", label: "6-15" }, { max: 10000, cls: "high", label: "16+" }];
        function attachCopy(panel) {
            panel.querySelectorAll(".pick-copy").forEach(b => b.addEventListener("click", () => {
                const t = b.dataset.copy;
                const done = () => { b.textContent = "✅ 已复制"; setTimeout(() => b.textContent = "复制", 1200); };
                if (navigator.clipboard && window.isSecureContext) {
                    navigator.clipboard.writeText(t).then(done, () => fallbackCopy(t, done));
                } else fallbackCopy(t, done);
            }));
        }
        function fallbackCopy(text, done) {
            const ta = document.createElement("textarea");
            ta.value = text; ta.style.position = "fixed"; ta.style.opacity = "0";
            document.body.appendChild(ta); ta.select();
            try { document.execCommand("copy"); } catch (e) {}
            ta.remove(); if (done) done();
        }
        async function initOverview() {
            if (!ovData) {
                try {
                    const res = await fetch("/api/overview");
                    const d = await res.json();
                    ovData = d.ok ? d.maps : [];
                } catch (e) { ovData = []; }
                document.querySelector("#ov-filters span").textContent =
                    `📋 全库地图总览（${ovData.length} 张，缩略图后台生成中）`;
            }
            renderOvGrid();
            if (!ovAudit) {
                const box = document.getElementById("audit-table-box");
                try {
                    const res = await fetch("/api/npc_audit");
                    const d = await res.json();
                    ovAudit = d.ok ? d.rows : [];
                    const funcs = d.funcs || ["药店", "仓库", "修理", "传送"];
                    let html = '<table id="audit-table"><tr><th>地图</th><th>NPC数</th>';
                    for (const f of funcs) html += `<th>${f}</th>`;
                    html += "</tr>";
                    for (const r of ovAudit) {
                        if (!r.total) continue;
                        html += `<tr><td>${r.cn} <span style="color:#6a6a75">${r.map}</span></td><td>${r.total}</td>`;
                        for (const f of funcs) {
                            const names = (r.funcs || {})[f] || [];
                            html += `<td>${names.length
                                ? `<span class="audit-ok">✓ ${names.slice(0, 2).join("、")}${names.length > 2 ? "…" : ""}</span>`
                                : `<span class="audit-miss">✗ 缺</span>`}</td>`;
                        }
                        html += "</tr>";
                    }
                    box.innerHTML = html + "</table>";
                } catch (e) { box.textContent = "NPC 审计数据不可用"; }
            }
        }
        function renderOvGrid() {
            const grid = document.getElementById("ov-grid");
            const items = ovData.filter(m => {
                if (ovFilter === "boss") return m.boss;
                if (ovFilter === "hasmob") return m.resp > 0;
                if (ovFilter === "town" || ovFilter === "cave") return m.cat === ovFilter;
                return true;
            });
            if (ovObserver) ovObserver.disconnect();
            ovObserver = new IntersectionObserver((ents) => {
                for (const en of ents) {
                    if (en.isIntersecting) {
                        const img = en.target.querySelector("img[data-src]");
                        if (img) { img.src = img.dataset.src; delete img.dataset.src; }
                        ovObserver.unobserve(en.target);
                    }
                }
            }, { root: ovView, rootMargin: "500px 0px" });
            const LVL_LABEL = { low: "Lv1-15", mid: "Lv16-30", high: "Lv31-50", max: "Lv51+", none: "无怪" };
            grid.innerHTML = items.map(m => {
                let cls;
                if (ovColorMode === "npc") {
                    const t = NPC_TIERS.find(t => m.npcs <= t.max);
                    cls = t.cls;
                } else cls = m.tier;
                const meta = ovColorMode === "npc"
                    ? `NPC <span class="tier-${cls}">${m.npcs}</span> · 怪 ${m.resp}`
                    : `<span class="lv tier-${m.tier}">${LVL_LABEL[m.tier]}${m.lvl != null ? " · 均" + m.lvl : ""}</span> · 怪 ${m.resp} · NPC ${m.npcs}`;
                return `<div class="ov-card" data-map="${m.id}" data-file="${m.file ? 1 : 0}">` +
                    `<div class="ov-thumb">${m.file
                        ? `<img data-src="/thumb?map=${encodeURIComponent(m.id + ".map")}" alt="" loading="lazy">`
                        : `<span class="ph">🗺️</span><span class="ov-nofile">无图文件</span>`}` +
                    (m.boss ? `<span class="ov-crown" title="BOSS 刷新点">👑</span>` : "") + `</div>` +
                    `<div class="ov-name" title="${m.cn} (${m.id})">${m.cn} <span class="ov-id">${m.id}</span></div>` +
                    `<div class="ov-meta">${meta}</div>` +
                    `<div class="ov-bar bar-${cls}"></div></div>`;
            }).join("");
            grid.querySelectorAll(".ov-card").forEach(card => {
                ovObserver.observe(card);
                card.addEventListener("click", () => {
                    if (card.dataset.file !== "1") return;
                    showView("map");
                    history.replaceState(null, "", `#map=${encodeURIComponent(card.dataset.map + ".map")}&cur=0&g=1&m=1&f=1`);
                    init();
                });
            });
        }
        document.querySelectorAll("#ov-filters .ov-chip").forEach(chip => {
            chip.addEventListener("click", () => {
                if (chip.dataset.f) {
                    ovFilter = chip.dataset.f;
                    document.querySelectorAll('#ov-filters .ov-chip[data-f]').forEach(c => c.classList.toggle("active", c === chip));
                } else {
                    ovColorMode = chip.dataset.c;
                    document.querySelectorAll('#ov-filters .ov-chip[data-c]').forEach(c => c.classList.toggle("active", c === chip));
                }
                if (ovData) renderOvGrid();
            });
        });

        // ---- 4. 连通性图谱（力导向 + 孤岛红标 + 割点黄标） ----
        let graphInit = false;
        async function initGraph() {
            if (graphInit) return;
            const statsEl = document.getElementById("graph-stats");
            const box = document.getElementById("graph-box");
            let d;
            try { d = await (await fetch("/api/graph")).json(); } catch (e) { d = null; }
            if (!d || !d.ok) { statsEl.textContent = "连通数据不可用（workspace MovementInfo 缺失）"; return; }
            graphInit = true;
            const nodes = new Map(d.nodes.map(n => [n.id, n]));
            const linked = d.nodes.filter(n => !n.isolated);
            const isolated = d.nodes.filter(n => n.isolated);
            // FR 力导向（有边节点）；孤岛节点外圈环形排布
            const W = 1600, H = 1100;
            const pos = new Map();
            linked.forEach((n, i) => {
                const a = i * 2.399963;   // 黄金角散布
                const r = 60 + 90 * Math.sqrt(i / Math.max(1, linked.length));
                pos.set(n.id, [W / 2 + r * Math.cos(a) * 2.2, H / 2 + r * Math.sin(a)]);
            });
            const adj = new Map(d.nodes.map(n => [n.id, new Set()]));
            for (const [a, b] of d.edges) {
                if (a === b || !adj.has(a) || !adj.has(b)) continue;
                adj.get(a).add(b); adj.get(b).add(a);
            }
            const k = Math.sqrt(W * H / Math.max(1, linked.length)) * 0.16;
            for (let it = 0; it < 260; it++) {
                const disp = new Map(linked.map(n => [n.id, [0, 0]]));
                for (let i = 0; i < linked.length; i++) {
                    for (let j = i + 1; j < linked.length; j++) {
                        const a = linked[i].id, b = linked[j].id;
                        let dx = pos.get(a)[0] - pos.get(b)[0], dy = pos.get(a)[1] - pos.get(b)[1];
                        let dist = Math.max(1, Math.hypot(dx, dy));
                        const f = k * k / dist;
                        disp.get(a)[0] += dx / dist * f; disp.get(a)[1] += dy / dist * f;
                        disp.get(b)[0] -= dx / dist * f; disp.get(b)[1] -= dy / dist * f;
                    }
                }
                for (const [a, nbrs] of adj) {
                    for (const b of nbrs) {
                        if (!pos.has(a) || !pos.has(b)) continue;
                        let dx = pos.get(a)[0] - pos.get(b)[0], dy = pos.get(a)[1] - pos.get(b)[1];
                        let dist = Math.max(1, Math.hypot(dx, dy));
                        const f = dist * dist / k;
                        if (disp.has(a)) { disp.get(a)[0] -= dx / dist * f; disp.get(a)[1] -= dy / dist * f; }
                    }
                }
                const t = Math.max(2, 30 * (1 - it / 260));
                for (const [id, dp] of disp) {
                    const p = pos.get(id);
                    const dl = Math.max(1, Math.hypot(dp[0], dp[1]));
                    p[0] = Math.min(W, Math.max(0, p[0] + dp[0] / dl * Math.min(dl, t)));
                    p[1] = Math.min(H, Math.max(0, p[1] + dp[1] / dl * Math.min(dl, t)));
                }
            }
            isolated.forEach((n, i) => {
                const a = i * 2.399963;
                pos.set(n.id, [W / 2 + (W * 0.62) * Math.cos(a), H / 2 + (H * 0.62) * Math.sin(a)]);
            });
            // 渲染 SVG
            const islands = d.nodes.filter(n => n.island).length;
            const cuts = d.nodes.filter(n => n.cut).length;
            statsEl.innerHTML = `<b>${d.nodes.length}</b> 节点 · <b>${d.edges.length}</b> 边 · ` +
                `<span class="g-isl">孤岛(入度0) ${islands}</span> · <span class="g-cut">割点(必经) ${cuts}</span>` +
                ` · 拖拽平移 / 滚轮缩放 · 点击节点跳转`;
            let svg = `<svg id="graph-svg" viewBox="0 0 ${W} ${H}" style="width:100%; height:calc(100vh - 120px); cursor:grab; touch-action:none;">`;
            for (const [a, b] of d.edges) {
                if (!pos.has(a) || !pos.has(b)) continue;
                svg += `<line x1="${pos.get(a)[0]}" y1="${pos.get(a)[1]}" x2="${pos.get(b)[0]}" y2="${pos.get(b)[1]}" stroke="#3a4a5a" stroke-width="1" opacity=".8"/>`;
            }
            for (const n of d.nodes) {
                const p = pos.get(n.id);
                const fill = n.island ? "#ff5b5b" : (d.spawn_stems || []).includes(n.id) ? "#3de88a" : "#5a8fd0";
                const stroke = n.cut ? "#ffd54a" : "#111";
                const sw = n.cut ? 3 : 1.5;
                const r = n.isolated ? 3 : (n.indeg + n.outdeg > 8 ? 8 : 5);
                svg += `<g class="gnode" data-id="${n.id}" data-file="${n.file ? 1 : 0}">` +
                    `<circle cx="${p[0]}" cy="${p[1]}" r="${r}" fill="${fill}" stroke="${stroke}" stroke-width="${sw}">` +
                    `<title>${n.cn} (${n.id}) · 入${n.indeg}/出${n.outdeg}${n.island ? " · 孤岛" : ""}${n.cut ? " · 割点(必经之路)" : ""}${n.file ? "" : " · 无图文件"}</title></circle>` +
                    `${r > 4 ? `<text x="${p[0] + 9}" y="${p[1] + 3}">${n.cn}</text>` : ""}</g>`;
            }
            svg += "</svg>";
            box.innerHTML = svg;
            const gsvg = document.getElementById("graph-svg");
            let vb = [0, 0, W, H], gDrag = null;
            gsvg.addEventListener("wheel", (e) => {
                e.preventDefault();
                const f = e.deltaY > 0 ? 1.15 : 0.87;
                vb = [vb[0] + vb[2] * (1 - f) / 2, vb[1] + vb[3] * (1 - f) / 2, vb[2] * f, vb[3] * f];
                gsvg.setAttribute("viewBox", vb.join(" "));
            }, { passive: false });
            gsvg.addEventListener("mousedown", (e) => { gDrag = [e.clientX, e.clientY, ...vb]; });
            window.addEventListener("mousemove", (e) => {
                if (!gDrag) return;
                const sc = vb[2] / gsvg.clientWidth;
                vb = [gDrag[2] - (e.clientX - gDrag[0]) * sc, gDrag[3] - (e.clientY - gDrag[1]) * sc, gDrag[4], gDrag[5]];
                gsvg.setAttribute("viewBox", vb.join(" "));
            });
            window.addEventListener("mouseup", () => { gDrag = null; });
            if (window.WU && window.matchMedia && matchMedia("(pointer:coarse)").matches) {
                WU.gesture(gsvg, {
                    pan: (dx, dy) => {
                        const sc = vb[2] / gsvg.clientWidth;
                        vb = [vb[0] - dx * sc, vb[1] - dy * sc, vb[2], vb[3]];
                        gsvg.setAttribute("viewBox", vb.join(" "));
                    },
                    pinch: (step, cx, cy) => {
                        const f = step > 0 ? 1 / 1.15 : 1.15;
                        const sx = vb[0] + cx / gsvg.clientWidth * vb[2];
                        const sy = vb[1] + cy / gsvg.clientHeight * vb[3];
                        vb = [sx - (sx - vb[0]) * f, sy - (sy - vb[1]) * f, vb[2] * f, vb[3] * f];
                        gsvg.setAttribute("viewBox", vb.join(" "));
                    }
                });
            }
            gsvg.addEventListener("click", (e) => {
                const g = e.target.closest(".gnode");
                if (!g || g.dataset.file !== "1") return;
                showView("map");
                history.replaceState(null, "", `#map=${encodeURIComponent(g.dataset.id + ".map")}&cur=0&g=1&m=1&f=1`);
                init();
            });
        }

        // ---- 钩子：地图渲染/滚动/缩放时同步重绘三个叠加层 ----
        const _renderBase = render;
        render = function (keepAnchor) {
            _renderBase(keepAnchor);
            drawHeat(); drawQuest(); renderPick();
        };
        vp.addEventListener("scroll", () => { drawHeat(); drawQuest(); renderPick(); });
        window.addEventListener("resize", () => { drawHeat(); drawQuest(); renderPick(); });
        const _loadMapBase = loadMap;
        loadMap = function () {
            _loadMapBase();
            const mi = curMap();
            if (mi) { loadRespawns(mi); drawQuest(); renderQuestPanelSafe(); }
        };
        function renderQuestPanelSafe() {
            if (questData) questPanel.style.display = "block"; else questPanel.style.display = "none";
        }
        loadQuests();

        // 图例补充：热力分级 + 任务标记 + 拾取
        const legendPanel = document.getElementById("legend-panel");
        legendPanel.innerHTML +=
            '<hr style="border-color:#2e2e36;">' +
            '<div class="lg-row"><span class="lg-block" style="background:rgba(96,210,96,.5);"></span>刷怪 &lt;10</div>' +
            '<div class="lg-row"><span class="lg-block" style="background:rgba(255,213,74,.55);"></span>刷怪 10-49</div>' +
            '<div class="lg-row"><span class="lg-block" style="background:rgba(255,140,50,.55);"></span>刷怪 50-149</div>' +
            '<div class="lg-row"><span class="lg-block" style="background:rgba(255,60,60,.55);"></span>刷怪 ≥150</div>' +
            '<div class="lg-row"><span class="lg-dot" style="background:#ff4b4b;box-shadow:0 0 6px #ff4b4b;"></span> 任务讨伐怪物刷新点（脉冲）</div>' +
            '<div class="lg-row"><span class="lg-dot" style="background:#ff9b3d;"></span> 任务收集掉落怪物点位</div>' +
            '<div class="lg-row"><span class="lg-block" style="background:rgba(255,213,74,.3);border:1px solid #ffd54a;"></span> 任务探访区域</div>' +
            '<div class="lg-row"><span style="color:#aaa;font-size:11px;">🎯 点击地图拾取格坐标 · Shift+点击测距</div>';

        // ---- 移动端：图层抽屉 + 触控手势（MAP-P0-01/02；桌面鼠标/滚轮路径不变） ----
        (function () {
            const layerGroup = document.getElementById("layer-group");
            const layerBackdrop = document.getElementById("layer-backdrop");
            const btnLayers = document.getElementById("btn-layers");
            if (!layerGroup || !btnLayers) return;
            const layerSheet = (open) => {
                layerGroup.classList.toggle("open", open);
                layerBackdrop.classList.toggle("open", open);
            };
            btnLayers.addEventListener("click", (e) => {
                e.stopPropagation();
                layerSheet(!layerGroup.classList.contains("open"));
            });
            layerBackdrop.addEventListener("click", () => layerSheet(false));
            window.addEventListener("keydown", (e) => { if (e.key === "Escape") layerSheet(false); });

            // 单指平移（滚动手感）/ 双指阶梯缩放 / 双击放大 —— 锚点逻辑与 Ctrl+滚轮一致
            if (window.WU && window.matchMedia && matchMedia("(pointer:coarse)").matches) {
                const zoomAt = (step, cx, cy) => {
                    anchorX = (vp.scrollLeft + cx) * curScale();
                    anchorY = (vp.scrollTop + cy) * curScale();
                    if (step > 0 && cur > 0) cur--;
                    else if (step < 0 && cur < scaleLadder.length - 1) cur++;
                    else return;
                    render(true); updateUrlHash(); saveState();
                };
                WU.gesture(vp, {
                    pan: (dx, dy) => { vp.scrollLeft -= dx; vp.scrollTop -= dy; },
                    pinch: (step, cx, cy) => zoomAt(step, cx, cy),
                    doubleTap: (x, y) => zoomAt(+1, x, y)
                });
            }
        /*__EDIT_UI__*/
        })();
    </script>
</body>
</html>
"""


# ---------------------------------------------------------------------------
# 编辑模式 UI（E1）：注入主模板闭包的 JS 模块。api.py 在服务 "/" 时把
# /*__EDIT_UI__*/ 替换为本常量。功能：格选中/六字段侧栏/三图层帧选择器
# （/sprite 实时预览）/flag 着色网格/笔刷（单格·矩形·同值替换）/撤销重做/
# 未保存提醒/保存管线调用（副本→独立验证→备份→原子替换）。
EDIT_UI_JS = r"""
        // ============================ 编辑模式 (E1) ============================
        const LIB_NAMES = __LIB_JSON__;

        let editOn = false, editSess = null;   // {w,h,dirty,undo,redo}
        let editSel = null;                     // {x,y}
        let editBrush = 'cell';                 // cell | rect | same
        let editRectA = null, editRectB = null; // rect 拖拽角点
        let editSameSrc = null;                 // same 模式源格
        let editRev = 0;                        // 客户端瓦片 URL 换新计数
        let editFlags = null;                   // Uint8Array flag 图

        function editPanel() {
            let p = document.getElementById('edit-panel');
            if (!p) {
                p = document.createElement('div');
                p.id = 'edit-panel';
                p.style.cssText = 'position:fixed;right:10px;top:50px;width:308px;max-height:82vh;overflow:auto;'
                    + 'background:rgba(10,12,16,.94);border:1px solid #3a3a46;border-radius:6px;'
                    + 'padding:8px 10px;font-size:12px;color:#c8c8d2;z-index:90;line-height:1.5';
                document.body.appendChild(p);
            }
            return p;
        }

        async function editPost(op, payload) {
            const r = await fetch('/edit/' + op, {
                method: 'POST', headers: {'Content-Type': 'application/json'},
                body: JSON.stringify(Object.assign({map: curName}, payload || {}))
            });
            return r.json();
        }

        async function editLoadFlags() {
            const r = await fetch('/edit/flags?map=' + encodeURIComponent(curName));
            const d = await r.json();
            if (d.ok) {
                const bin = atob(d.flags);
                editFlags = new Uint8Array(bin.length);
                for (let i = 0; i < bin.length; i++) editFlags[i] = bin.charCodeAt(i);
            } else editFlags = null;
        }

        function editScreenToCell(e) {
            const rect = vp.getBoundingClientRect();
            const s = curScale();
            return {
                x: Math.floor((vp.scrollLeft + e.clientX - rect.left) * s / 48),
                y: Math.floor((vp.scrollTop + e.clientY - rect.top) * s / 32)
            };
        }

        function editDrawOverlay() {
            let c = document.getElementById('edit-canvas');
            if (!c) {
                c = document.createElement('canvas');
                c.id = 'edit-canvas';
                c.style.cssText = 'position:absolute;left:0;top:0;z-index:5;pointer-events:none;';
                vp.appendChild(c);
            }
            c.width = vp.clientWidth; c.height = vp.clientHeight;
            const ctx = c.getContext('2d');
            const s = curScale(), sx = s / 48, sy = s / 32;
            const x0 = Math.floor(vp.scrollLeft * sx), y0 = Math.floor(vp.scrollTop * sy);
            const x1 = Math.ceil((vp.scrollLeft + vp.clientWidth) * sx);
            const y1 = Math.ceil((vp.scrollTop + vp.clientHeight) * sy);
            const toScr = (gx, gy) => [Math.floor(gx * 48 / s - vp.scrollLeft), Math.floor(gy * 32 / s - vp.scrollTop)];
            // flag 着色：不可通行格红色薄层（服务器判定 flag&3!=3 即阻挡）
            if (editFlags && curMap()) {
                const mi = curMap();
                ctx.fillStyle = 'rgba(255,48,48,.30)';
                for (let gx = Math.max(0, x0); gx < Math.min(mi.w, x1); gx++) {
                    for (let gy = Math.max(0, y0); gy < Math.min(mi.h, y1); gy++) {
                        if ((editFlags[gx * mi.h + gy] & 3) !== 3) {
                            const [px, py] = toScr(gx, gy);
                            ctx.fillRect(px, py, Math.ceil(48 / s), Math.ceil(32 / s));
                        }
                    }
                }
            }
            // 网格（z<=1 才画，避免高级别过密）
            if (curZ() <= 1) {
                ctx.strokeStyle = 'rgba(255,255,255,.14)';
                ctx.lineWidth = 1;
                ctx.beginPath();
                for (let gx = Math.max(0, x0); gx <= x1; gx++) {
                    const [px] = toScr(gx, 0);
                    ctx.moveTo(px + .5, 0); ctx.lineTo(px + .5, c.height);
                }
                for (let gy = Math.max(0, y0); gy <= y1; gy++) {
                    const [, py] = toScr(0, gy);
                    ctx.moveTo(0, py + .5); ctx.lineTo(c.width, py + .5);
                }
                ctx.stroke();
            }
            // 选中格
            const box = (cell, color, label) => {
                const [px, py] = toScr(cell.x, cell.y);
                ctx.strokeStyle = color; ctx.lineWidth = 2;
                ctx.strokeRect(px + 1, py + 1, Math.ceil(48 / s) - 2, Math.ceil(32 / s) - 2);
                if (label) { ctx.fillStyle = color; ctx.font = '11px ui-monospace'; ctx.fillText(label, px + 3, py + 12); }
            };
            if (editSameSrc) box(editSameSrc, '#ffb84d', '源');
            if (editRectA && editRectB) {
                const a = {x: Math.min(editRectA.x, editRectB.x), y: Math.min(editRectA.y, editRectB.y)};
                const b = {x: Math.max(editRectA.x, editRectB.x), y: Math.max(editRectA.y, editRectB.y)};
                const [px, py] = toScr(a.x, a.y);
                ctx.strokeStyle = '#3de88a'; ctx.lineWidth = 2;
                ctx.strokeRect(px + 1, py + 1, (b.x - a.x + 1) * 48 / s - 2, (b.y - a.y + 1) * 32 / s - 2);
            }
            if (editSel && !(editBrush === 'same' && editSameSrc && editSel.x === editSameSrc.x && editSel.y === editSameSrc.y))
                box(editSel, '#72d6ff');
        }

        function editRefreshTiles() {
            editRev++;
            document.querySelectorAll('#tile-layer img').forEach(img => {
                const u = new URL(img.src, location.href);
                if (u.searchParams.get('e') !== String(editRev)) {
                    u.searchParams.set('e', String(editRev));
                    img.src = u.pathname + '?' + u.searchParams.toString();
                }
            });
        }

        function editLibSel(id, val) {
            const sel = document.createElement('select');
            sel.id = id;
            const keys = Object.keys(LIB_NAMES).map(Number).sort((a, b) => a - b);
            for (const k of keys) {
                const o = document.createElement('option');
                o.value = k; o.textContent = k === 255 ? '255 无' : k + ' ' + LIB_NAMES[k];
                sel.appendChild(o);
            }
            sel.value = String(val);
            return sel;
        }

        async function editShowCell(cell) {
            editSel = cell;
            const r = await fetch('/api/cell?map=' + encodeURIComponent(curName)
                + '&x=' + cell.x + '&y=' + cell.y);
            const d = await r.json();
            if (!d.ok) { editRenderPanel(); return; }
            editCellData = d;
            editRenderPanel();
        }

        let editCellData = null;

        function editFieldRow(name, label, val, isNum) {
            return '<div class="ef-row"><span>' + label + '</span>'
                + '<input id="ef-' + name + '" type="number" value="' + val + '"></div>';
        }

        function editRenderPanel() {
            const p = editPanel();
            if (!editOn) { p.style.display = 'none'; return; }
            p.style.display = 'block';
            const mi = curMap() || {name: curName};
            let h = '<div style="display:flex;justify-content:space-between;align-items:center">'
                + '<b style="color:#ffd54a">编辑模式</b><span>'
                + (editSess && editSess.dirty ? '<span style="color:#ff8f6b">未保存 ' + editSess.dirty + '</span>' : '<span style="color:#3de88a">无改动</span>')
                + '</span></div>'
                + '<div style="color:#8a8a98;font-size:11px">' + mi.name + (mi.cn ? ' · ' + mi.cn : '') + '</div>';
            // 工具行
            h += '<div class="ef-row" style="margin-top:6px"><span>笔刷</span><select id="ef-brush">'
                + '<option value="cell"' + (editBrush === 'cell' ? ' selected' : '') + '>单格</option>'
                + '<option value="rect"' + (editBrush === 'rect' ? ' selected' : '') + '>矩形</option>'
                + '<option value="same"' + (editBrush === 'same' ? ' selected' : '') + '>同值替换</option>'
                + '</select></div>';
            h += '<div class="ef-row"><span>操作</span>'
                + '<button id="ef-undo">↶撤销(' + (editSess ? editSess.undo : 0) + ')</button>'
                + '<button id="ef-redo">↷重做(' + (editSess ? editSess.redo : 0) + ')</button></div>';
            if (editBrush === 'same')
                h += '<div style="color:#ffb84d;font-size:11px">先点源格(黄框)，再涂抹目标区域：只替换与源格三图层相同的格</div>';
            if (editBrush === 'rect')
                h += '<div style="color:#8a8a98;font-size:11px">拖拽画矩形后点「应用矩形」</div>';
            // 选中格信息
            if (editCellData && editSel) {
                const d = editCellData;
                const passable = (d.flag & 3) === 3;
                h += '<hr style="border-color:#333;margin:6px 0">'
                    + '<div><b>格 (' + d.x + ',' + d.y + ')</b> · '
                    + '<span style="color:' + (passable ? '#3de88a' : '#ff8f6b') + '">'
                    + (passable ? '通行' : '阻挡') + '</span>'
                    + ' <button id="ef-flag" style="margin-left:6px">切换</button></div>';
                for (const layer of ['back', 'mid', 'front']) {
                    const L = d[layer];
                    h += '<div class="ef-layer">' + layer.toUpperCase()
                        + ': <span class="lib">' + (L.lib || '') + '</span> #' + L.frame + '</div>'
                        + '<div class="ef-row"><span>' + layer + ' 库</span><span id="ef-' + layer + '-file-hold"></span>'
                        + '<input id="ef-' + layer + '-img" type="number" style="width:70px" value="' + L.frame + '"'
                        + (layer === 'back' ? '' : '') + '>'
                        + '<img id="ef-' + layer + '-prev" style="height:40px;max-width:52px;object-fit:contain;background:#222">'
                        + '</div>';
                }
                h += '<div class="ef-row"><span>anim_a/anim_b</span>'
                    + '<input id="ef-aa" type="number" style="width:52px" value="' + d.anim[0] + '">'
                    + '<input id="ef-ab" type="number" style="width:52px" value="' + d.anim[1] + '"></div>';
                h += '<button id="ef-apply" style="width:100%;margin-top:4px">应用到此格</button>';
            } else {
                h += '<hr style="border-color:#333;margin:6px 0"><div style="color:#8a8a98">点击地图格查看/编辑</div>';
            }
            if (editRectA && editRectB) {
                h += '<button id="ef-rectapply" style="width:100%;margin-top:4px">应用矩形 ' 
                    + '(' + Math.min(editRectA.x, editRectB.x) + ',' + Math.min(editRectA.y, editRectB.y) + ')-('
                    + Math.max(editRectA.x, editRectB.x) + ',' + Math.max(editRectA.y, editRectB.y) + ')</button>';
            }
            h += '<hr style="border-color:#333;margin:6px 0">'
                + '<button id="ef-save" style="width:100%">保存（副本→验证→备份→原子替换）</button>'
                + '<button id="ef-discard" style="width:100%;margin-top:4px">放弃修改</button>';
            p.innerHTML = h;
            // 事件
            p.querySelector('#ef-brush').onchange = (e) => { editBrush = e.target.value; editRectA = editRectB = null; editRenderPanel(); };
            p.querySelector('#ef-undo').onclick = () => editOp('undo');
            p.querySelector('#ef-redo').onclick = () => editOp('redo');
            const fl = p.querySelector('#ef-flag');
            if (fl) fl.onclick = () => {
                const d = editCellData;
                const nf = ((d.flag & 3) === 3) ? (d.flag & ~3) : (d.flag | 3);
                editApply([{x: d.x, y: d.y, fields: {flag: nf & 255}}]);
            };
            for (const layer of ['back', 'mid', 'front']) {
                const holder = p.querySelector('#ef-' + layer + '-file-hold');
                if (holder) {
                    holder.appendChild(editLibSel('ef-' + layer + '-file', editCellData[layer].file));
                    const imgIn = p.querySelector('#ef-' + layer + '-img');
                    const upd = () => editPreview(layer,
                        Number(p.querySelector('#ef-' + layer + '-file').value), Number(imgIn.value));
                    p.querySelector('#ef-' + layer + '-file').onchange = upd;
                    imgIn.onchange = upd;
                    upd();
                }
            }
            const ap = p.querySelector('#ef-apply');
            if (ap) ap.onclick = () => {
                const d = editCellData;
                const fields = {};
                for (const layer of ['back', 'mid', 'front']) {
                    const f = Number(p.querySelector('#ef-' + layer + '-file').value);
                    const i = Number(p.querySelector('#ef-' + layer + '-img').value);
                    const cur = d[layer];
                    if (f !== cur.file || i !== cur.frame) {
                        fields[layer + '_file'] = f; fields[layer + '_img'] = i;
                    }
                }
                const aa = Number(p.querySelector('#ef-aa').value), ab = Number(p.querySelector('#ef-ab').value);
                if (aa !== d.anim[0]) fields.anim_a = aa;
                if (ab !== d.anim[1]) fields.anim_b = ab;
                if (!Object.keys(fields).length) return;
                editApply([{x: d.x, y: d.y, fields}]);
            };
            const ra = p.querySelector('#ef-rectapply');
            if (ra) ra.onclick = () => {
                const d = editCellData;
                const x0 = Math.min(editRectA.x, editRectB.x), x1 = Math.max(editRectA.x, editRectB.x);
                const y0 = Math.min(editRectA.y, editRectB.y), y1 = Math.max(editRectA.y, editRectB.y);
                if ((x1 - x0 + 1) * (y1 - y0 + 1) > 20000) { alert('矩形过大（>20000 格）'); return; }
                const fields = {};
                if (d) {
                    for (const layer of ['back', 'mid', 'front']) {
                        const f = p.querySelector('#ef-' + layer + '-file');
                        if (!f) continue;
                        const fv = Number(f.value), iv = Number(p.querySelector('#ef-' + layer + '-img').value);
                        if (fv !== d[layer].file || iv !== d[layer].frame) {
                            fields[layer + '_file'] = fv; fields[layer + '_img'] = iv;
                        }
                    }
                    const aa = Number(p.querySelector('#ef-aa').value), ab = Number(p.querySelector('#ef-ab').value);
                    if (aa !== d.anim[0]) fields.anim_a = aa;
                    if (ab !== d.anim[1]) fields.anim_b = ab;
                }
                editRectApply(x0, y0, x1, y1, fields);
            };
            p.querySelector('#ef-save').onclick = editSave;
            p.querySelector('#ef-discard').onclick = () => {
                if (editSess && editSess.dirty && !confirm('放弃全部未保存修改？')) return;
                editOp('discard').then(() => { editRefreshTiles(); editDrawOverlay(); });
            };
        }

        async function editPreview(layer, file, img) {
            const el = document.getElementById('ef-' + layer + '-prev');
            if (!el) return;
            if (file === 255 || !(img > 0) || img >= 65535) { el.src = ''; el.style.visibility = 'hidden'; return; }
            el.style.visibility = 'visible';
            el.src = '/sprite?lib=' + encodeURIComponent(LIB_NAMES[file])
                + '&frame=' + img + '&e=' + editRev;
        }

        async function editOp(op) {
            const d = await editPost(op);
            if (d.ok) {
                editSess = d;
                if (op === 'discard') { editSess = {dirty: 0, undo: 0, redo: 0}; editFlags = null; await editLoadFlags(); }
                if (editCellData && op !== 'discard') await editShowCell(editSel);
                else editRenderPanel();
                editRefreshTiles();
                editDrawOverlay();
            } else alert('操作失败: ' + (d.error || '?'));
        }

        async function editApply(edits) {
            const d = await editPost('set', {edits});
            if (!d.ok) { alert('编辑被拒绝: ' + (d.error || '?')); return; }
            editSess = d;
            await editLoadFlags();          // flag 变化重取着色
            if (editSel) await editShowCell(editSel);
            editRefreshTiles();
            editDrawOverlay();
        }

        async function editRectApply(x0, y0, x1, y1, fields) {
            const payload = {x0, y0, x1, y1, fields};
            if (editBrush === 'same' && editSameSrc) payload.src = editSameSrc;
            const d = await editPost('brush', payload);
            if (!d.ok) { alert(d.error === 'no_match' ? '无匹配格' : '笔刷失败: ' + (d.error || '?')); return; }
            editSess = {dirty: d.dirty, undo: d.undo, redo: d.redo};
            await editLoadFlags();
            editRefreshTiles();
            editDrawOverlay();
            editRenderPanel();
        }

        async function editSave() {
            if (!editSess || !editSess.dirty) { alert('没有未保存的修改'); return; }
            if (!confirm('保存将写入地图文件（自动备份原文件）。继续？')) return;
            const d = await editPost('save', {confirm: true});
            if (d.ok) {
                editSess.dirty = 0;
                alert('已保存\\n备份: ' + d.backup + '\\n字节数: ' + d.bytes);
                await editLoadFlags();
                editRefreshTiles();
                editRenderPanel();
                render(true);
            } else alert('保存失败: ' + (d.error || '?'));
        }

        async function editStart(quiet) {
            editOn = true;
            const d = await editPost('open');
            if (!d.ok) {
                editOn = false;
                if (quiet) console.warn('editStart:', d.error || '?');   // 自启失败不 alert（headless 会阻塞）
                else alert('打开编辑会话失败: ' + (d.error || '?'));
                return;
            }
            editSess = d;
            await editLoadFlags();
            editRenderPanel();
            editDrawOverlay();
        }

        function editStop() {
            editOn = false;
            const c = document.getElementById('edit-canvas');
            if (c) c.remove();
            editPanel().style.display = 'none';
        }

        // ---- 挂接：工具栏按钮 / 视口事件 / 滚动重绘 / 切图提醒 ----
        if (!document.getElementById('edit-panel-style')) {
            const st = document.createElement('style');
            st.id = 'edit-panel-style';
            st.textContent = '#edit-panel .ef-row{display:flex;align-items:center;gap:6px;margin:2px 0}'
                + '#edit-panel .ef-row>span:first-child{color:#8a8a98;min-width:64px}'
                + '#edit-panel .ef-layer{font-size:11px;color:#d8e6ff}'
                + '#edit-panel .lib{font-family:ui-monospace,monospace;color:#72d6ff}'
                + '#edit-panel button{background:#333;color:#eee;border:1px solid #555;border-radius:3px;cursor:pointer;padding:2px 8px}'
                + '#edit-panel input[type=number]{width:80px;background:#222;color:#eee;border:1px solid #444;border-radius:3px;padding:1px 4px}'
                + '#edit-panel select{background:#333;color:#eee;border:1px solid #555;border-radius:3px;padding:1px 4px;max-width:150px}';
            document.head.appendChild(st);
        }
        const editBtn = document.createElement('button');
        editBtn.textContent = '编辑地图';
        editBtn.title = '进入/退出编辑模式（E1 地图编辑器）';
        editBtn.style.cssText = 'background:#4a3810;color:#ffd54a;border:1px solid #7a6020;border-radius:3px;cursor:pointer;';
        document.getElementById('toolbar').appendChild(editBtn);
        editBtn.addEventListener('click', async (e) => {
            e.stopPropagation();
            if (!editOn) await editStart();
            else {
                if (editSess && editSess.dirty && !confirm('有未保存修改，退出编辑模式？（修改保留在服务器会话，重进可继续）')) return;
                editStop();
            }
        });

        vp.addEventListener('scroll', () => { if (editOn) editDrawOverlay(); });
        vp.addEventListener('mousedown', (e) => {
            if (!editOn || e.button !== 0) return;
            const cell = editScreenToCell(e);
            if (!curMap() || cell.x < 0 || cell.y < 0 || cell.x >= curMap().w || cell.y >= curMap().h) return;
            if (editBrush === 'rect') {
                editRectA = editRectB = cell;
                const mv = (ev) => { editRectB = editScreenToCell(ev); editDrawOverlay(); };
                const up = () => {
                    vp.removeEventListener('mousemove', mv);
                    vp.removeEventListener('mouseup', up);
                    editDrawOverlay(); editRenderPanel();
                };
                vp.addEventListener('mousemove', mv);
                vp.addEventListener('mouseup', up);
                editDrawOverlay();
                return;
            }
            if (editBrush === 'same') {
                if (!editSameSrc || e.shiftKey) { editSameSrc = cell; editShowCell(cell); editDrawOverlay(); return; }
                // 点击即以当前面板值替换该格（若匹配源格）
                editRectApply(cell.x, cell.y, cell.x, cell.y, editPanelFields());
                return;
            }
            editShowCell(cell);
            editDrawOverlay();
        });
        function editPanelFields() {
            const p = editPanel();
            const fields = {};
            for (const layer of ['back', 'mid', 'front']) {
                const f = p.querySelector('#ef-' + layer + '-file');
                if (!f) continue;
                fields[layer + '_file'] = Number(f.value);
                fields[layer + '_img'] = Number(p.querySelector('#ef-' + layer + '-img').value);
            }
            return fields;
        }

        // 切图未保存提醒：包一层 loadMap（主模板的切图入口；pick 是 /sim 的）
        {
            const _origLoad = loadMap;
            loadMap = function () {
                if (editOn && editSess && editSess.dirty
                    && !confirm('当前图有未保存修改，切换地图将保留在会话（不丢失）。继续切换？'))
                    return;
                if (editOn) { editFlags = null; editCellData = null; editSel = null; editSameSrc = null; editRectA = editRectB = null; }
                return _origLoad();
            };
        }
        window.addEventListener('beforeunload', (e) => {
            if (editOn && editSess && editSess.dirty) { e.preventDefault(); e.returnValue = ''; }
        });
        // URL ?edit=1 直进编辑模式（等地图真加载完再开，自启失败只 console.warn）
        if (/[?&]edit=1\b/.test(location.search)) {
            const waitMap = () => curName && curName.endsWith('.map')
                ? editStart(true)
                : setTimeout(waitMap, 300);
            waitMap();
        }
        // ============================ NPC 摆放 (E2) ============================
        let npcArmed = false;            // 待放置：下一次点图 = 新建 NPC 落点
        let npcSel = null;                // 点击选中的 NPC/卫士 {kind,index,name,region,x,y}
        let npcPageMap = {};              // EntryPage datalist: 显示名 -> Index

        function npcPanel() {
            let p = document.getElementById('npc-edit-panel');
            if (!p) {
                p = document.createElement('div');
                p.id = 'npc-edit-panel';
                p.style.cssText = 'position:fixed;right:10px;top:50px;width:308px;max-height:82vh;overflow:auto;'
                    + 'background:rgba(10,12,16,.94);border:1px solid #3a5a3a;border-radius:6px;'
                    + 'padding:8px 10px;font-size:12px;color:#c8c8d2;z-index:89;line-height:1.5';
                document.body.appendChild(p);
            }
            return p;
        }

        async function npcPost(op, payload) {
            const r = await fetch('/npc/' + op, {
                method: 'POST', headers: {'Content-Type': 'application/json'},
                body: JSON.stringify(payload || {})
            });
            return r.json();
        }

        async function npcRefresh() {
            const mi = curMap();
            if (!mi) return;
            await loadEntities(mi);       // 重取 /api/entities（服务端已刷新 workspace）
            drawEntities();
            renderNpcPanel(mi);
            npcDiffRender();
        }

        // ---- 拖拽移动（NPC / 卫士），格吸附 ----
        if (!document.getElementById('npc-edit-style')) {
            const st = document.createElement('style');
            st.id = 'npc-edit-style';
            st.textContent = '#ent-layer.npc-edit .ent{pointer-events:auto;cursor:grab}'
                + '#ent-layer.npc-edit .ent:active{cursor:grabbing}'
                + '#npc-edit-panel button{background:#333;color:#eee;border:1px solid #555;border-radius:3px;cursor:pointer;padding:2px 8px}'
                + '#npc-edit-panel input,#npc-edit-panel select{background:#222;color:#eee;border:1px solid #444;border-radius:3px;padding:1px 4px}'
                + '#npc-ghost{position:absolute;z-index:6;pointer-events:none;outline:2px dashed #3de88a;outline-offset:2px;opacity:.85}';
            document.head.appendChild(st);
        }
        entLayer.addEventListener('mousedown', (e) => {
            const el = e.target.closest('.ent');
            if (!editOn || !el || !entLayer.classList.contains('npc-edit')) return;
            const kind = el.dataset.kind;
            if (kind !== 'npc' && kind !== 'guard') return;
            e.stopPropagation();          // 不触发 E1 的选格
            const idx = Number(kind === 'npc' ? el.dataset.npc : el.dataset.guard);
            if (!idx) return;
            const name = el.dataset.name || '';
            const sx = e.clientX, sy = e.clientY;
            const ox = el.offsetLeft, oy = el.offsetTop;
            let moved = false;
            const ghost = el.cloneNode(true);
            ghost.id = 'npc-ghost';
            const mv = (ev) => {
                if (!moved && Math.hypot(ev.clientX - sx, ev.clientY - sy) < 4) return;
                if (!moved) { moved = true; entLayer.appendChild(ghost); el.style.visibility = 'hidden'; }
                ghost.style.left = (ox + ev.clientX - sx) + 'px';
                ghost.style.top = (oy + ev.clientY - sy) + 'px';
            };
            const up = async (ev) => {
                document.removeEventListener('mousemove', mv);
                document.removeEventListener('mouseup', up);
                ghost.remove();
                el.style.visibility = '';
                if (!moved) { npcShowDetail({kind, index: idx, name, region: el.dataset.region}); return; }
                const cell = editScreenToCell(ev);
                const mi = curMap();
                if (!mi || cell.x < 0 || cell.y < 0 || cell.x >= mi.w || cell.y >= mi.h) return;
                const op = kind === 'npc' ? 'move' : 'guard_move';
                const key = kind === 'npc' ? 'npc' : 'guard';
                const d = await npcPost(op, {[key]: idx, x: cell.x, y: cell.y});
                if (!d.ok) { alert('移动失败: ' + (d.error || '?')); return; }
                await npcRefresh();
            };
            document.addEventListener('mousemove', mv);
            document.addEventListener('mouseup', up);
        });

        function npcShowDetail(sel) {
            npcSel = sel;
            npcRenderPanel();
        }

        async function npcEnsurePages() {
            if (npcPageMap.__loaded) return;
            const d = await (await fetch('/npc/pages')).json();
            if (d.ok) {
                npcPageMap = {__loaded: true};
                const dl = document.getElementById('npc-page-list');
                if (dl) dl.innerHTML = d.pages.map(p => {
                    npcPageMap['#' + p.Index + ' ' + p.Name] = p.Index;
                    return `<option value="#${p.Index} ${p.Name}">`;
                }).join('');
            }
        }

        async function npcDiffRender() {
            const el = document.getElementById('npc-diff-box');
            if (!el) return;
            let d;
            try { d = await (await fetch('/npc/diff')).json(); } catch (e) { return; }
            const s = d.summary || {added: 0, modified: 0, deleted: 0};
            const total = s.added + s.modified + s.deleted;
            let h = `<b style="color:#ffd54a">待同步变更</b> `
                + (total ? `<span style="color:#ff8f6b">+${s.added} ~${s.modified} -${s.deleted}</span>` : '<span style="color:#3de88a">无</span>');
            for (const [table, entries] of Object.entries(d.tables || {})) {
                h += `<div style="margin-top:3px"><b>${table}</b>`
                    + ` <button data-rt="${table}" style="float:right">回滚表</button>`;
                for (const en of entries.slice(0, 6)) {
                    const fl = en.fields ? Object.keys(en.fields).join(',') : '';
                    h += `<div style="color:#8a8a98;font-size:11px"> #${en.index} ${{
                        added: '新增', modified: '改 ' + fl, deleted: '删除'}[en.op]}</div>`;
                }
                if (entries.length > 6) h += `<div style="color:#8a8a98;font-size:11px"> …等 ${entries.length} 条</div>`;
                h += '</div>';
            }
            if (total) h += '<div style="color:#8a8a98;font-size:11px;margin-top:4px">落库：停服后 dbeditor「同步」或 bash Tools/dbeditor/sync.sh</div>'
                + '<button id="npc-rollback-all" style="width:100%;margin-top:4px">回滚全部至基线</button>';
            el.innerHTML = h;
            el.querySelectorAll('[data-rt]').forEach(b => b.onclick = async () => {
                if (!confirm(`回滚表 ${b.dataset.rt} 至基线？（连带撤销该表上所有人的未同步改动，含其它会话）`)) return;
                const d2 = await npcPost('rollback', {table: b.dataset.rt});
                if (d2.ok) npcRefresh(); else alert('回滚失败: ' + (d2.error || '?'));
            });
            const ra = el.querySelector('#npc-rollback-all');
            if (ra) ra.onclick = async () => {
                if (!confirm('回滚全部工作区改动至基线？（含其它会话的未同步改动）')) return;
                const d2 = await npcPost('rollback', {});
                if (d2.ok) npcRefresh(); else alert('回滚失败: ' + (d2.error || '?'));
            };
        }

        function npcRenderPanel() {
            const p = npcPanel();
            if (!editOn) { p.style.display = 'none'; entLayer.classList.remove('npc-edit'); return; }
            // 表单值跨重渲染保留（armed 切换会重建 innerHTML）
            const keep = {};
            for (const id of ['npc-new-name', 'npc-new-img', 'npc-new-page']) {
                const el = document.getElementById(id);
                if (el) keep[id] = el.value;
            }
            p.style.display = 'block';
            entLayer.classList.add('npc-edit');
            const mi = curMap() || {name: curName, cn: ''};
            let h = '<div style="display:flex;justify-content:space-between;align-items:center">'
                + '<b style="color:#7ee88a">NPC 摆放</b>'
                + (npcArmed ? '<span style="color:#ff8f6b">点击地图放置…</span>' : '')
                + '</div>'
                + '<div style="color:#8a8a98;font-size:11px">' + mi.name + ' · 拖拽 NPC/卫士移动，单击看详情</div>';
            // 选中详情
            if (npcSel) {
                h += '<hr style="border-color:#333;margin:6px 0">'
                    + `<div><b>${npcSel.kind === 'guard' ? '卫士' : 'NPC'}</b> #${npcSel.index} ${npcSel.name}</div>`
                    + (npcSel.region ? `<div style="color:#8a8a98;font-size:11px">Region #${npcSel.region}</div>` : '')
                    + (npcSel.kind === 'npc'
                        ? '<button id="npc-del" style="margin-top:4px;color:#ff8f6b">删除 NPC</button>' : '');
            }
            // 新建
            h += '<hr style="border-color:#333;margin:6px 0"><b>新建 NPC</b>'
                + '<div class="ef-row"><span>名称</span><input id="npc-new-name" style="flex:1" placeholder="如：铁匠师傅"></div>'
                + '<div class="ef-row"><span>Image</span><input id="npc-new-img" type="number" value="0" style="width:60px">'
                + '<span style="color:#8a8a98;font-size:11px">体型(帧=Image×100)</span></div>'
                + '<div class="ef-row"><span>对话页</span><input id="npc-new-page" list="npc-page-list" style="flex:1" placeholder="搜索 EntryPage…">'
                + '<datalist id="npc-page-list"></datalist></div>'
                + `<button id="npc-arm" style="width:100%;margin-top:4px">${npcArmed ? '取消放置' : '点图放置新 NPC'}</button>`;
            h += '<hr style="border-color:#333;margin:6px 0"><div id="npc-diff-box"></div>';
            p.innerHTML = h;
            for (const [id, v] of Object.entries(keep)) {
                const el = document.getElementById(id);
                if (el && v != null && v !== '') el.value = v;
            }
            const del = p.querySelector('#npc-del');
            if (del) del.onclick = async () => {
                if (!confirm(`删除 NPC #${npcSel.index} ${npcSel.name}？（Region 若无他人引用一并删）`)) return;
                const d = await npcPost('delete', {npc: npcSel.index});
                if (d.ok) { npcSel = null; npcRefresh(); } else alert('删除失败: ' + (d.error || '?'));
            };
            p.querySelector('#npc-arm').onclick = () => { npcArmed = !npcArmed; npcEnsurePages(); npcRenderPanel(); };
            p.querySelector('#npc-new-page').onfocus = npcEnsurePages;
            npcDiffRender();
        }

        // 点图放置（armed）挂在 vp 捕获阶段，先于 E1 选格
        vp.addEventListener('mousedown', async (e) => {
            if (!editOn || !npcArmed || e.button !== 0) return;
            const p = npcPanel();
            const name = (p.querySelector('#npc-new-name') || {}).value || '';
            const img = Number((p.querySelector('#npc-new-img') || {}).value || 0);
            const pageRaw = (p.querySelector('#npc-new-page') || {}).value || '';
            const pageIdx = npcPageMap[pageRaw] != null ? npcPageMap[pageRaw]
                : (pageRaw.startsWith('#') ? Number(pageRaw.slice(1).split(' ')[0]) : null);
            const cell = editScreenToCell(e);
            const mi = curMap();
            if (!mi || !name.trim()) { alert('先填 NPC 名称'); return; }
            const mapStem = curName.replace(/\.map$/i, '');
            const d = await npcPost('create', {map: mapStem, x: cell.x, y: cell.y,
                name: name.trim(), image: img, entry_page: Number.isFinite(pageIdx) ? pageIdx : null});
            if (!d.ok) { alert('创建失败: ' + (d.error || '?')); return; }
            npcArmed = false;
            npcRefresh();
        }, true);

        // 编辑模式开关联动 E1（editStart/editStop 是函数声明，可重绑）
        {
            const _start = editStart, _stop = editStop;
            editStart = async function (q) { await _start(q); npcRenderPanel(); };
            editStop = function () { _stop(); npcArmed = false; npcSel = null; npcRenderPanel(); };
        }
        // ========================== NPC 摆放结束 ==========================

        // ========================== 编辑模式结束 ==========================
"""
