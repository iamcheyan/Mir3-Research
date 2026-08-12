/* Mir3 EI 3.0 原版客户端模拟器 — interactive engine.
 *
 * Fixed 800x600 logical canvas. Real textures are decoded by the wilviewer
 * server via /api/image (WIL -> PNG). All geometry is consumed from the
 * unified data model (data/*.json, built by Tools/web/build_mir3_simulator_data.py
 * from docs/research/ei-ui-layout/). Nothing here hard-codes coordinates.
 *
 * Evidence levels are carried through: primary / derived / candidate / pending.
 * Candidate geometry is drawn with the candidate marker, never as primary fact.
 */
"use strict";

const VIEW_W = 800;
const VIEW_H = 600;

const STATE = {
  data: null,          // unified bundle
  scale: 1,
  evidence: false,
  testnav: false,
  selectedEntity: null, // {id, kind, name}
  hoveredEntity: null,
  openWindows: new Set(),
  foregroundWindow: null,
  storeState: 0,
  currentMapIndex: 0,
  currentMap: { name: "", map: "" },
  hp: 62, mp: 71, exp: 38,      // demo live values (bars driven by rects)
  chatLines: [],
  prompt: null,                 // {kind:'confirm'|'notice'|'gold', text, cb}
  pressed: null,                // control id currently pressed
  tradeGold: 0,                 // gold box value (Finding 283, msg 0x405/0x406)
  storeFeedback: "",            // Finding 289 CRAFT/BUY result line (0x42210C)
  inventoryMode: 0,             // Finding 288 mode byte [bag+0x54]: 0 default / 1 修补 / 2 变卖 / 3 储存
  tradeFinalized: false,        // [+0x13644]: 0 trading, 1 finalized (accept)
  tradeSplit: [0, 0],           // [+0x54]/[+0x58] = top visible DATA ROW per pane (Finding 301: row offset, not px; 94-scale, usable [0,34])
  loginStage: 0,                // Round 43 (F349): [0x8B1878]-style stage machine - 0 intro / 1 char-select / 2 in-game
  charStage: 0,                 // [0x930] char-select stage (0 list, 1 creating, 2 login anim, 3 enter, 4 anim done)
};

const $ = (sel) => document.querySelector(sel);
const stage = $("#stage");
const sceneEl = $("#scene");
const hudEl = $("#hud");
const winEl = $("#windows");
const promptEl = $("#prompts");
const evEl = $("#evidence-overlay");
const targetboxEl = $("#targetbox");

/* ------------------------------------------------------------ texture url */
function imgUrl(lib, frame, scale = 1) {
  if (frame == null || frame < 0) return null;
  const f = String(frame);
  return `/api/image?f=${encodeURIComponent(lib)}&i=${f}&scale=${scale}&bg=transparent`;
}

function makeImg(lib, frame, scale = 1) {
  const url = imgUrl(lib, frame, scale);
  const el = document.createElement("img");
  if (url) el.src = url;
  el.alt = `${lib} F${frame}`;
  return el;
}

/* ------------------------------------------------------------ entity frame formula */
// Round 5 (Findings 279/280/281/282, primary-static). The three frame tables
// are compile-time constants (0x8AA5C0 player 33 / 0x8AA686 monster 9 /
// 0x8AA6C8 npc 3), each record (w0 start, w1 block len, w2 interval ms).
// Anchor = w0 + formula offset, cycle advances within [w0, w0+w1) at w2 ms
// (frame advance 0x40C4B0 wraps to [e+0xB4]).
//   player:  + 3000*S + 10*dir   (S = body selector <9, dir 0..7)
//   monster: + 1000*(race%10) + 10*flag
//   npc:     + 100*body + 10*(flag%3)
function entityFrame(e, now) {
  const a = e.appearance;
  if (!a) return e.frame;
  const tab = STATE.data && STATE.data.frame_tables ? STATE.data.frame_tables[a.table] : null;
  const rec = tab && tab[a.state] ? tab[a.state] : [0, 1, 300];
  const w0 = rec[0], w1 = rec[1], w2 = rec[2];
  let base = w0;
  if (a.table === "player") base += 3000 * a.S + 10 * a.dir;
  else if (a.table === "monster") base += 1000 * (a.race % 10) + 10 * (a.flag || 0);
  else base += 100 * a.body + 10 * ((a.flag || 0) % 3);
  const t = Math.floor(now / w2);
  return base + (t % Math.max(1, w1));
}

/* ------------------------------------------------------------ data model */
async function loadData() {
  const r = await fetch("data/layout.json");
  if (!r.ok) throw new Error(`data fetch failed: ${r.status}`);
  return r.json();
}

/* ------------------------------------------------------------ scale */
function applyScale() {
  const wrap = $("#stage-wrap");
  const availW = wrap.clientWidth - 24;
  const availH = wrap.clientHeight - 24;
  const s = Math.max(1, Math.floor(Math.min(availW / VIEW_W, availH / VIEW_H)));
  STATE.scale = s;
  stage.style.transform = `scale(${s})`;
  stage.style.margin = "auto";
  $("#scale-label").textContent = `${VIEW_W}×${VIEW_H} 逻辑 · 缩放 ×${s}`;
}
window.addEventListener("resize", applyScale);

/* ------------------------------------------------------------ scene layer */
function renderScene() {
  sceneEl.innerHTML = "";
  const maps = STATE.data.maps || [];
  const bg = maps.find((m) => m.id === "map.bg");
  if (bg) {
    const im = makeImg(bg.library, bg.frame);
    im.className = "hud-img";
    // evidence C3 projection: world 48px x / 32px y -> 800x600 viewport stretch.
    // Tile aspect is 48:32 = 3:2, matching the 800x600 viewport.
    im.style.cssText = "left:0;top:0;width:800px;height:600px;object-fit:fill;opacity:.9";
    im.dataset.evidence = bg.evidence_level;
    im.dataset.rect = "0,0,800,600";
    im.dataset.desc = `${bg.library} F${bg.frame} · ${bg.note || ""}`;
    sceneEl.appendChild(im);
  }
  for (const e of STATE.data.entities || []) {
    const spr = document.createElement("div");
    spr.className = `sprite ${e.kind}`;
    spr.dataset.entity = e.id;
    spr.style.left = e.x + "px";
    spr.style.top = e.y + "px";
    const im = makeImg(e.library, entityFrame(e, performance.now()));
    // sprite frames are large; constrain to a plausible in-world size
    im.style.cssText = "max-width:60px;max-height:80px;width:auto;height:auto";
    if (e.appearance) {
      im.dataset.frame = entityFrame(e, performance.now());
      spr.dataset.anim = 1;   // ticker advances the cycle (0x40C4B0)
    }
    spr.appendChild(im);
    const name = document.createElement("div");
    name.className = "nameplate";
    name.textContent = e.name;
    name.title = "Finding 296: 共享名牌渲染器 0x40CE20 (element 81) — 门 [e+0x61C68]&0x100000 出生白闪 + 1700ms tick；type==0x321 → 0x434EF0 FX 入 0x560088 效果链";
    spr.appendChild(name);
    spr.dataset.rect = `${e.x - 20},${e.y - 60},40,70`;
    spr.dataset.evidence = e.evidence_level;
    const f0 = entityFrame(e, performance.now());
    // Finding 290: player state semantics (0..32) appended to the frame table.
    const pn = STATE.data.frame_tables && STATE.data.frame_tables.player_names
      ? STATE.data.frame_tables.player_names[e.appearance && e.appearance.table === "player" ? e.appearance.state : -1]
      : null;
    spr.dataset.desc = `${e.library} F${f0} · ${e.note || ""}${pn ? ` · ${pn}` : ""}`;
    sceneEl.appendChild(spr);
  }
}

/* ------------------------------------------------------------ HUD layer */
function renderHud() {
  hudEl.innerHTML = "";
  const hud = STATE.data.hud;
  const bg = makeImg(hud.resource_library, hud.background_frame);
  bg.className = "hud-img";
  bg.style.cssText = `left:${hud.origin[0]}px;top:${hud.origin[1]}px;width:800px;height:135px`;
  bg.dataset.evidence = "primary-static";
  bg.dataset.rect = `${hud.origin[0]},${hud.origin[1]},800,135`;
  bg.dataset.desc = "GameInter F50 主 HUD 底板";
  hudEl.appendChild(bg);

  // HP / MP / EXP bars
  const bars = [
    { key: "hp_bar", cls: "hp", val: STATE.hp, color: "#d4352c" },
    { key: "mp_bar", cls: "mp", val: STATE.mp, color: "#2b6bd4" },
    { key: "exp_bar", cls: "exp", val: STATE.exp, color: "#3fae4a" },
  ];
  for (const b of bars) {
    const meta = hud[b.key];
    if (!meta) continue;
    const [l, t, r, bot] = meta.rect;
    const w = r - l, h = bot - t;
    const fill = document.createElement("div");
    fill.className = `bar-fill ${b.cls}`;
    const bw = Math.max(0, Math.min(100, b.val)) / 100;
    const base = b.cls === "exp" ? w : w * 0.5; // exp is horizontal, hp/mp vertical
    let fw = w, fh = h;
    if (b.cls === "exp") { fw = Math.round(base * bw); fh = h; }
    else { fh = Math.round(h * bw); fw = w; }
    fill.style.cssText = `left:${l}px;top:${t + (b.cls === "exp" ? 0 : h - fh)}px;width:${fw}px;height:${fh}px;background:${b.color}`;
    fill.dataset.evidence = meta.evidence_level;
    fill.dataset.rect = meta.rect.join(",");
    fill.dataset.desc = meta.note || "";
    hudEl.appendChild(fill);
    // numeric label overlay
    const num = document.createElement("div");
    num.className = "lbl";
    num.dataset.bar = b.cls;
    num.style.cssText = `left:${l}px;top:${t}px;font:10px monospace;color:#fff;text-shadow:1px 1px 0 #000;z-index:3`;
    const label = b.cls === "hp" ? `血量 ${Math.round(b.val)}/100` : b.cls === "mp" ? `魔法 ${Math.round(b.val)}/100` : `经验 ${Math.round(b.val)}/100`;
    num.textContent = label;
    hudEl.appendChild(num);
  }

  // HUD controls (buttons) — from unified data model
  for (const c of STATE.data.controls) {
    if (c.window_id !== "hud") continue;
    const [x, y, w, h] = c.rect;
    const btn = document.createElement("div");
    btn.className = "control";
    btn.style.cssText = `left:${x}px;top:${y}px;width:${w}px;height:${h}px`;
    const im = makeImg(c.resource_library, c.frame_pair[0]);
    btn.appendChild(im);
    btn.dataset.control = c.id;
    btn.dataset.rect = c.rect.join(",");
    btn.dataset.evidence = c.evidence_level;
    btn.dataset.desc = c.id;
    btn.title = `${c.id} · F${c.frame_pair[0]} · ${c.evidence_level}`;
    btn.addEventListener("pointerdown", (ev) => {
      ev.stopPropagation();
      btn.classList.add("pressed");
      STATE.pressed = c.id;
    });
    btn.addEventListener("pointerup", (ev) => {
      ev.stopPropagation();
      btn.classList.remove("pressed");
      if (STATE.pressed === c.id) {
        STATE.pressed = null;
        onHudControl(c.id);
      }
    });
    btn.addEventListener("pointerleave", () => btn.classList.remove("pressed"));
    hudEl.appendChild(btn);
  }

  // minimap widget
  const mm = hud.minimap;
  const mmEl = document.createElement("div");
  mmEl.className = "minimap";
  mmEl.style.cssText = `left:${mm.rect[0]}px;top:${mm.rect[1]}px;width:${mm.rect[2] - mm.rect[0]}px;height:${mm.rect[3] - mm.rect[1]}px`;
  const mapMm = STATE.data.maps.find((q) => q.id === "map.minimap");
  const mmImg = makeImg(mapMm ? mapMm.library : "FMMap.wil", mapMm ? mapMm.frame : 0);
  mmImg.style.cssText = "width:100%;height:100%;object-fit:cover"; // panel = 128x128 crop window over 1.5/1.0 px/tile surface (Finding 277)
  mmEl.style.overflow = "hidden";
  mmEl.appendChild(mmImg);
  mmEl.dataset.evidence = mm.evidence_level;
  mmEl.dataset.rect = mm.rect.join(",");
  mmEl.dataset.desc = "固定小地图 (672,0)-(800,128)";
  mmEl.title = `小地图 · ${STATE.currentMap.name || ""} · ${mapMm ? mapMm.library + " F" + mapMm.frame : ""} · ${mm.evidence_level}`;
  hudEl.appendChild(mmEl);

  // chat region
  const chat = hud.chat_region;
  const chatEl = document.createElement("div");
  chatEl.className = "text-panel";
  chatEl.style.cssText = `left:${chat.rect[0]}px;top:${chat.rect[1]}px;width:${chat.rect[2] - chat.rect[0]}px;height:${chat.rect[3] - chat.rect[1]}px`;
  chatEl.dataset.evidence = chat.evidence_level;
  chatEl.dataset.rect = chat.rect.join(",");
  chatEl.dataset.desc = "聊天/文本总区域 (224,492)-(578,566)";
  const lines = document.createElement("div");
  lines.className = "chat-lines";
  lines.id = "chat-lines";
  chatEl.appendChild(lines);
  hudEl.appendChild(chatEl);

  // target info panel
  const tgt = hud.target_info;
  const tp = document.createElement("div");
  tp.className = "target-panel";
  tp.id = "target-panel";
  tp.style.cssText = `left:${tgt.rect[0]}px;top:${tgt.rect[1]}px;width:${tgt.rect[2] - tgt.rect[0]}px;height:${tgt.rect[3] - tgt.rect[1]}px`;
  hudEl.appendChild(tp);

  pushChat("[系统] 欢迎使用 Mir3 EI 3.0 原版客户端模拟器");
  pushChat("[系统] 点击场景中的怪物/NPC 设置目标，底部按钮打开窗口");
}

function pushChat(line) {
  STATE.chatLines.push(line);
  // Round 35 (F341): original chat ring renders min(count-scroll, 0x13=19) lines
  // at 14px row stride (0x414700); keep the sim ring at the same cap.
  if (STATE.chatLines.length > 19) STATE.chatLines.shift();
  const el = $("#chat-lines");
  if (el) el.textContent = STATE.chatLines.join("\n");
}

function setTarget(entity) {
  STATE.selectedEntity = entity;
  // clear targeting marks
  document.querySelectorAll("#scene .sprite.targeted").forEach((n) => n.classList.remove("targeted"));
  if (entity) {
    const spr = document.querySelector(`#scene .sprite[data-entity="${entity.id}"]`);
    if (spr) spr.classList.add("targeted");
  }
  updateTargetPanel();
  updateTargetBox();
}

function updateTargetPanel() {
  const tp = $("#target-panel");
  if (!tp) return;
  const e = STATE.selectedEntity;
  if (!e) { tp.classList.remove("visible"); return; }
  tp.classList.add("visible");
  const kind = e.kind === "monster" ? "怪物" : e.kind === "npc" ? "NPC" : "玩家";
  tp.textContent = `${kind}：${e.name}\n${e.note || ""}`;
}

function updateTargetBox() {
  // Evidence-based composite (target-box-evidence.json, Finding 239):
  // anchor = entity screen position; name-plate box 0x40B850 (0xA0A0A border,
  // width = text width, 15px tall, 15..30px above anchor, centered on anchor_x),
  // name text 0x40B750, HP bar 0x40A8A0 (fill proportional to HP value).
  const e = STATE.selectedEntity || STATE.hoveredEntity;
  if (!e || e.kind === "drop") { targetboxEl.classList.add("hidden"); return; }
  const spr = document.querySelector(`#scene .sprite[data-entity="${e.id}"]`);
  if (!spr) { targetboxEl.classList.add("hidden"); return; }
  const r = spr.getBoundingClientRect();
  const sr = stage.getBoundingClientRect();
  const ax = (r.left - sr.left + r.width / 2) / STATE.scale; // anchor x = entity center
  const ay = (r.top - sr.top + r.height) / STATE.scale;      // anchor y = entity feet
  const nameW = Math.max(24, estimateTextWidth(e.name) + 8);
  const BOX_H = 15;        // 0x40B850: bottom-top = (ay-0xF)-(ay-0x1E) = 15
  const BOX_TOP = 30;      // box sits 15..30px above anchor (top=ay-0x1E, bottom=ay-0xF)
  const HP_H = 4;
  const maxHp = e.maxHp || 100;
  const hp = Math.max(0, Math.min(1, (e.hp != null ? e.hp : 62) / maxHp));

  targetboxEl.innerHTML = "";
  const box = document.createElement("div");
  box.className = "tb-box";
  box.style.cssText = `left:${Math.round(ax - nameW / 2)}px;top:${Math.round(ay - BOX_TOP)}px;width:${nameW}px;height:${BOX_H}px`;
  const name = document.createElement("div");
  name.className = "tb-name";
  name.textContent = e.name;
  box.appendChild(name);
  const hpEl = document.createElement("div");
  hpEl.className = "tb-hp";
  hpEl.style.cssText = `left:${Math.round(ax - nameW / 2)}px;top:${Math.round(ay - BOX_TOP + BOX_H)}px;width:${nameW}px;height:${HP_H}px`;
  const fill = document.createElement("div");
  fill.className = "tb-hp-fill";
  fill.style.width = Math.round(nameW * hp) + "px";
  hpEl.appendChild(fill);
  targetboxEl.appendChild(box);
  targetboxEl.appendChild(hpEl);
  targetboxEl.classList.remove("hidden");
}

function estimateTextWidth(text) {
  // cheap proxy for the client's 0x45E0C0 text measurement (no canvas needed)
  let w = 0;
  for (const ch of text) w += ch.charCodeAt(0) > 0x7f ? 11 : 6;
  return w;
}

/* ------------------------------------------------------------ windows */
const WINDOW_TITLES = {
  "window.inventory": "背包",
  "window.status": "人物状态",
  "window.store-candidate": "商店/仓库",
  "window.exchange-candidate": "交易 (玩家间)",
  "window.guild-candidate": "行会",
  "window.group": "组队",
  "window.chat-pop": "聊天",
  "window.group-pop-candidate": "队伍信息",
  "window.option": "系统设置",
  "window.quest": "任务",
  "window.horse": "坐骑",
  "window.skill-book": "技能",
  "window.npc-candidate": "NPC 对话",
  "window.notice-prompt-candidate": "公告",
};

function renderWindows() {
  winEl.innerHTML = "";
  for (const w of STATE.data.windows) {
    const [x, y, ww, hh] = w.rect;
    const box = document.createElement("div");
    box.className = "win closed";
    box.dataset.window = w.id;
    box.style.cssText = `left:${x}px;top:${y}px;width:${ww}px;height:${hh}px`;
    // background frame
    const bg = makeImg(w.resource_library, w.frame);
    bg.className = "win-bg";
    if (w.id === "window.exchange-candidate") {
      // Finding 283 (primary-static): trade frame 1050 is 512x512 drawn at
      // (7,-44) relative to the 484x330 window — art overflows the hit rect
      // (registered (1,330,484,0,0,F1050,src,3) @0x4277B0-0x4277C2). The
      // client does not clip window art, so the spill is visible.
      bg.style.cssText = "left:7px;top:-44px;width:512px;height:512px";
    } else {
      bg.style.objectFit = "fill";
    }
    box.appendChild(bg);
    // title bar (drag)
    const tb = document.createElement("div");
    tb.className = "win-titlebar";
    tb.title = `${WINDOW_TITLES[w.id] || w.id} · ${w.evidence_level}`;
    box.appendChild(tb);
    // content host
    const content = document.createElement("div");
    content.className = "win-content";
    content.dataset.windowContent = w.id;
    box.appendChild(content);
    // close button (frame pair from evidence where available)
    // chat-pop has an evidence-positioned close at rel (532,350) — rendered in
    // fillWindowContent from the specialized control, so skip the generic one.
    if (w.id !== "window.chat-pop") {
      const close = document.createElement("div");
      close.className = "close-btn";
      close.style.cssText = `right:4px;top:4px;width:28px;height:26px`;
      const closeImg = makeImg("GameInter.wil", 161);
      close.appendChild(closeImg);
      close.title = "关闭";
      close.addEventListener("click", (ev) => { ev.stopPropagation(); setWindowOpen(w.id, false); });
      box.appendChild(close);
    }
    winEl.appendChild(box);
    fillWindowContent(w);
    bindWindowDrag(box);
  }
}

function fillWindowContent(w) {
  const content = winEl.querySelector(`[data-window-content="${w.id}"]`);
  if (!content) return;
  content.innerHTML = "";
  const id = w.id;

  if (id === "window.status") {
    // equipment slots from data model + attribute labels
    for (const s of STATE.data.equipment_slots) {
      const slot = document.createElement("div");
      slot.className = "slot equip-empty";
      slot.style.cssText = `left:${s.x}px;top:${s.y}px;width:${s.w}px;height:${s.h}px`;
      const im = makeImg(s.library, s.frame);
      slot.appendChild(im);
      slot.dataset.slot = s.id;
      slot.dataset.evidence = s.evidence_level;
      slot.dataset.rect = `${s.x},${s.y},${s.w},${s.h}`;
      slot.dataset.desc = `${s.name} · ${s.library} F${s.frame}`;
      slot.title = `${s.name} · ${s.evidence_level}`;
      slot.addEventListener("click", () => selectSlot(slot, s));
      content.appendChild(slot);
    }
    const attrs = ["等级 1", "攻击 5-10", "魔法 3-8", "防御 2-5", "魔御 1-4"];
    attrs.forEach((a, i) => {
      const lbl = document.createElement("div");
      lbl.className = "lbl";
      lbl.style.cssText = `left:160px;top:${20 + i * 22}px`;
      lbl.textContent = a;
      content.appendChild(lbl);
    });
  } else if (id === "window.inventory") {
    // Round 46 (F352): original bag = 46 slot records (0x2E) at bag+0x774
    // stride 0xC2C (flag/w/h, 0xC20 body at +0x780), grid WORD cell table
    // bag+0x324 6 cols/row 12B pitch (bag-list-fill-chain-evidence F293).
    for (let i = 0; i < 46; i++) {
      const col = i % 6, row = Math.floor(i / 6);
      const x = 8 + col * 40, y = 8 + row * 40;
      const slot = document.createElement("div");
      slot.className = "slot";
      slot.style.cssText = `left:${x}px;top:${y}px;width:36px;height:36px`;
      slot.dataset.slot = `bag.${i}`;
      slot.dataset.rect = `${x},${y},36,36`;
      slot.dataset.evidence = "primary-static";
      slot.dataset.desc = `背包格 ${i + 1} · 46 槽 · bag+0x774+i*0xC2C · F293`;
      slot.title = `背包格 ${i + 1} · primary-static`;
      // place a few real item icons from Equip.wil
      if (i % 7 === 0) {
        const im = makeImg("Equip.wil", Math.min(i, 124));
        slot.appendChild(im);
      }
      slot.addEventListener("click", () => selectSlot(slot, { id: `bag.${i}` }));
      content.appendChild(slot);
    }
    // weight label
    const lbl = document.createElement("div");
    lbl.className = "lbl";
    lbl.style.cssText = "left:8px;top:256px;width:200px";
    lbl.textContent = "负重 12/30";
    content.appendChild(lbl);
    // Finding 288 (primary-static): mode byte [bag+0x54] written ONLY by
    // server msgs — mode0 default (reset 0x42E9A4 / show 0x42AE26), mode2 变卖
    // msg 0x286→0x41FA16, mode1 修补 msg 0x29C→0x41FB24, mode3 储存 msg 0x2BC→
    // 0x420AFC; paint dispatch 0x42EF2F jmp [eax*4+0x42F13C] branch labels
    // 包袱/修补/变卖/储存. 3 tab child controls (bag+0x5C stride 0xB4) are
    // decorative (click 0x4177F0 = sound only).
    const INVENTORY_MODES = ["包袱 (mode0)", "修补 (mode1)", "变卖 (mode2)", "储存 (mode3)"];
    const modeBar = document.createElement("div");
    modeBar.className = "lbl";
    modeBar.style.cssText = "left:8px;top:268px;width:260px;color:#9fd4ff";
    modeBar.id = "inventory-mode-label";
    modeBar.textContent = INVENTORY_MODES[STATE.inventoryMode] || INVENTORY_MODES[0];
    content.appendChild(modeBar);
  } else if (id === "window.exchange-candidate") {
    // Round 5 (Finding 283, primary-static): window id 3 = PLAYER-TO-PLAYER
    // TRADE. Frame 1050 (512x512 @ (7,-44)) is the only static art; the
    // buttons are NEVER drawn (render 0x417640 has zero xrefs; cancel frames
    // 1064/1065 don't exist in GameInter.wil count 1103) - silent hit zones.
    tradeContent(content);
  } else if (id === "window.skill-book" || id === "window.store-candidate") {
    // skill grid (skills.json) / store slots
    const src = id === "window.skill-book" ? STATE.data.skills : storeGridSlots();
    if (id === "window.skill-book") {
      // 8 magic-category labels — primary-static redraw positions + frame pairs
      // (skill-window-context.json: 火/冰/电/风/神圣/黑暗/幻影/剑, EXE 0x00439500)
      const cats = [
        ["火", 5, 21, 450], ["冰", 3, 56, 452], ["电", 4, 91, 454], ["风", 2, 126, 456],
        ["神圣", 2, 161, 458], ["黑暗", 2, 196, 450], ["幻影", 1, 231, 452], ["剑", 2, 266, 454],
      ];
      for (const [txt, cx, cy, cf] of cats) {
        const cl = document.createElement("div");
        cl.className = "slot skill-cat";
        cl.style.cssText = `left:${cx}px;top:${cy}px;width:40px;height:32px`;
        const im = makeImg("GameInter.wil", cf);
        cl.appendChild(im);
        cl.dataset.evidence = "primary-static";
        cl.dataset.rect = `${cx},${cy},40,32`;
        cl.dataset.desc = `技能分类「${txt}」· GameInter F${cf}/${cf + 1} · 0x00439500`;
        cl.title = `分类「${txt}」· F${cf}/${cf + 1} · primary-static`;
        content.appendChild(cl);
      }
    }
    for (const s of src) {
      const slot = document.createElement("div");
      slot.className = "slot";
      slot.style.cssText = `left:${s.x}px;top:${s.y}px;width:${s.w}px;height:${s.h}px`;
      const im = makeImg(s.library, s.frame);
      slot.appendChild(im);
      slot.dataset.slot = s.id;
      slot.dataset.rect = `${s.x},${s.y},${s.w},${s.h}`;
      slot.dataset.evidence = s.evidence_level;
      slot.dataset.desc = `${s.name} · ${s.library} F${s.frame}`;
      slot.title = `${s.name} · ${s.evidence_level}`;
      slot.addEventListener("click", () => selectSlot(slot, s));
      content.appendChild(slot);
    }
    if (id === "window.store-candidate") {
      const stateLbl = document.createElement("div");
      stateLbl.className = "lbl";
      stateLbl.style.cssText = "left:8px;top:278px;width:280px";
      stateLbl.id = "store-state-label";
      stateLbl.textContent = STORE_STATE_NAMES[STATE.storeState] || `商店状态 ${STATE.storeState}`;
      content.appendChild(stateLbl);
      // Finding 289: CRAFT result/error strings (cp949) via jump table 0x42210C:
      //   돈이 부족합니다 (0x47B634, not enough money) / 아이템이 잘 만들어 졌습니다
      //   (0x47B660, crafted ok); BUY errors 0x47B904/0x47B91C/0x47B940.
      const fb = document.createElement("div");
      fb.className = "lbl";
      fb.style.cssText = "left:8px;top:294px;width:280px;color:#ffd27a";
      fb.id = "store-feedback";
      fb.textContent = STATE.storeFeedback || "";
      content.appendChild(fb);
    }
  } else if (id === "window.chat-pop") {
    // chat pop window: history + channel toggles + scroll buttons + input.
    // Geometry is window-relative from chat-window-render-evidence.json
    // (unified model); specialized controls carry primary-static ctor/paint VAs.
    const hist = document.createElement("div");
    hist.className = "text-panel";
    hist.style.cssText = "left:40px;top:29px;width:491px;height:279px;overflow-y:auto;scrollbar-width:thin";
    const hl = document.createElement("div");
    hl.className = "chat-lines";
    hl.style.cssText = "font:12px/1.35 monospace;color:#d8e4f0;white-space:pre-wrap;text-shadow:1px 1px 0 #000;padding:2px";
    hl.textContent = STATE.chatLines.join("\n");
    hist.appendChild(hl);
    content.appendChild(hist);

    // specialized controls: close / 6 channel toggles / scroll up+down / track
    const chatCtrls = (STATE.data.controls || []).filter(
      (c) => c.window_id === "window.chat-pop" && c.relative_rect);
    for (const c of chatCtrls) {
      const [cx, cy, cw, ch] = c.relative_rect;
      const btn = document.createElement("div");
      btn.className = "slot chan-btn";
      btn.style.cssText = `left:${cx}px;top:${cy}px;width:${cw}px;height:${ch}px`;
      const role = c.role || "";
      if (c.chat_command) {
        // channel toggle: click injects the command template into the edit box
        // (client click dispatch: SetWindowTextA + EM_SETSEL(0xB1) + ShowWindow(5))
        btn.title = `${c.chat_help || "频道"} · ${c.id}\n点击注入命令：${c.chat_command}`;
        btn.addEventListener("click", () => {
          const inp = content.querySelector(".chat-input");
          if (inp) { inp.value = c.chat_command; inp.focus(); }
          pushChat(`[频道] 注入命令 ${c.chat_command}`);
        });
      } else if (role === "scroll-up") {
        btn.title = "向上滚动 · scroll-up";
        btn.addEventListener("click", () => { hist.scrollTop -= 266; });
      } else if (role === "scroll-down") {
        btn.title = "向下滚动 · scroll-down";
        btn.addEventListener("click", () => { hist.scrollTop += 266; });
      } else if (role.startsWith("scrollbar-track")) {
        // frame 380 (16x502) anchored window.x+0x215 / window.y-0xD0 (0x00414846);
        // mostly off-screen at the default origin — evidence-only, non-interactive.
        btn.title = "滚动条轨道 · frame 380 16×502 · 0x00414846";
        btn.style.pointerEvents = "none";
      } else if (role === "close-button") {
        btn.title = "关闭";
        btn.addEventListener("click", (ev) => { ev.stopPropagation(); setWindowOpen("window.chat-pop", false); });
      }
      const im = makeImg(c.resource_library || "GameInter.wil", (c.frame_pair || [])[0]);
      btn.appendChild(im);
      btn.dataset.evidence = c.evidence_level;
      btn.dataset.rect = `${cx},${cy},${cw},${ch}`;
      btn.dataset.desc = `${c.id} · F${(c.frame_pair || [])[0]}/${(c.frame_pair || [])[1]} · ${c.source || ""}`;
      content.appendChild(btn);
    }

    const input = document.createElement("input");
    input.className = "chat-input";
    // input edit rect: SetRect(0x954, 0x1A, 0x137, 0x20D, 0x146) -> (26,311)-(525,326)
    input.style.cssText = "position:absolute;left:26px;top:311px;width:499px;height:15px;background:#0a0f14;color:#d8e4f0;border:1px solid #2a3a4c;font:12px monospace";
    input.placeholder = "输入聊天内容…";
    input.addEventListener("keydown", (ev) => {
      if (ev.key === "Enter" && input.value) {
        pushChat(`[你] ${input.value}`);
        input.value = "";
        const hl2 = content.querySelector(".chat-lines");
        if (hl2) hl2.textContent = STATE.chatLines.join("\n");
      }
    });
    content.appendChild(input);
  } else if (id === "window.quest") {
    const quests = ["主线：拜见国王", "支线：收集草药", "活动：讨伐稻草人", "任务 4：护送商队", "任务 5：击杀骷髅"];
    quests.forEach((q, i) => {
      const lbl = document.createElement("div");
      lbl.className = "lbl";
      lbl.style.cssText = `left:24px;top:${50 + i * 22}px;width:260px`;
      lbl.textContent = (i === 0 ? "★ " : "○ ") + q;
      content.appendChild(lbl);
    });
  } else if (id === "window.npc-candidate") {
    const npcLbl = document.createElement("div");
    npcLbl.className = "lbl";
    npcLbl.style.cssText = "left:16px;top:16px;width:500px";
    npcLbl.textContent = "你好，勇士！有什么可以帮你？";
    content.appendChild(npcLbl);
    const opts = ["购买物品", "存取仓库", "修理装备", "离开"];
    opts.forEach((o, i) => {
      const btn = document.createElement("div");
      btn.className = "slot";
      btn.style.cssText = `left:${16 + i * 130}px;top:120px;width:120px;height:24px;border:none;background:rgba(0,0,0,.25)`;
      btn.textContent = o;
      btn.style.cssText += ";font:12px monospace;color:#e8eef5;text-align:center;line-height:24px";
      btn.addEventListener("click", () => {
        pushChat(`[NPC] 你选择了「${o}」`);
        if (o === "购买物品" || o === "存取仓库") setWindowOpen("window.store-candidate", true);
      });
      content.appendChild(btn);
    });
  } else if (id === "window.option") {
    // Finding 289 (primary-static): ctor 0x440FE0 9 controls; rows BGM [+0x130/0x1E4]
    // y43, EffectSound [+0x298/0x34C] y116, Ambience [+0x400/0x4B4] y190, ShadowBlend
    // [+0x568/0x61C] y217; left pair 760/761 = ON, right pair 762/763 = OFF (UP/PRESSED,
    // not ON/OFF art); sliders 751 @(34,96)/(34,170); state bytes +0x54/+0x58/+0x5C/+0x60.
    // Finding 297 (primary-resource): GameInter.wil 760/761 (32×22) = 켬, 762/763 (40×22)
    // = 끔; 761/763 = pressed-shift variants (+2/+1) — F289 UP/PRESSED pairing confirmed.
    const OPT_ROWS = [
      ["音乐", 43], ["音效", 116], ["环境声", 190], ["阴影混合", 217],
    ];
    const OPT_STATE = { "音乐": true, "音效": true, "环境声": false, "阴影混合": true };
    OPT_ROWS.forEach(([name, y]) => {
      const lbl = document.createElement("div");
      lbl.className = "lbl";
      lbl.style.cssText = `left:16px;top:${y + 4}px;width:90px`;
      lbl.textContent = name;
      content.appendChild(lbl);
      const on = document.createElement("div");
      on.className = "slot";
      on.style.cssText = `left:110px;top:${y}px;width:26px;height:22px;border:1px solid ${OPT_STATE[name] ? "#7ad47a" : "#3a4a5c"};background:rgba(0,0,0,.25)`;
      on.textContent = "ON";
      on.style.cssText += ";font:9px monospace;color:#e8eef5;text-align:center;line-height:22px";
      on.addEventListener("click", () => {
        OPT_STATE[name] = true;
        on.style.borderColor = "#7ad47a";
        off.style.borderColor = "#3a4a5c";
        pushChat(`[设置] ${name} ON · frame 760/761 (0x440FE0)`);
      });
      const off = document.createElement("div");
      off.className = "slot";
      off.style.cssText = `left:140px;top:${y}px;width:26px;height:22px;border:1px solid ${OPT_STATE[name] ? "#3a4a5c" : "#7ad47a"};background:rgba(0,0,0,.25)`;
      off.textContent = "OFF";
      off.style.cssText += ";font:9px monospace;color:#e8eef5;text-align:center;line-height:22px";
      off.addEventListener("click", () => {
        OPT_STATE[name] = false;
        on.style.borderColor = "#3a4a5c";
        off.style.borderColor = "#7ad47a";
        pushChat(`[设置] ${name} OFF · frame 762/763 (0x440FE0)`);
      });
      content.appendChild(on);
      content.appendChild(off);
    });
  } else if (id === "window.group" || id === "window.guild-candidate") {
    const members = id === "window.group" ? ["玩家", "队友·法师", "队友·道士"] : ["行会会长", "长老", "成员 1", "成员 2"];
    members.forEach((m, i) => {
      const lbl = document.createElement("div");
      lbl.className = "lbl";
      lbl.style.cssText = `left:16px;top:${30 + i * 24}px;width:220px`;
      lbl.textContent = (id === "window.group" ? "▸ " : "▪ ") + m;
      content.appendChild(lbl);
    });
  } else if (id === "window.horse") {
    const horseLbl = document.createElement("div");
    horseLbl.className = "lbl";
    horseLbl.style.cssText = "left:16px;top:20px;width:260px";
    horseLbl.textContent = "坐骑：枣红马\n状态：健康\n命令：召唤 / 喂食 / 遛马";
    content.appendChild(horseLbl);
    const hIm = makeImg("Horse.wil", 0);
    hIm.style.cssText = "position:absolute;left:60px;top:80px;max-width:180px;image-rendering:pixelated";
    content.appendChild(hIm);
  }
}

const STORE_STATE_NAMES = [
  "购买 (state0 · msg 0x285 → 0x41F92B → 0x44F480, primary-static)",
  "出售 (state1 · 服务端 @NPC_Sell + Merchant.txt 佐证, secondary)",
  "仓库 (state2 · msg 0x2BC → 二级 switch 0x42042B → 0x420A9B → 0x44F940, primary-static)",
  "制作 (state3 · msg 0x2C8 → 0x44FB00, frame 1002, primary-static)",
  "物品详情 (state4 · primary-static)",
];

function storeGridSlots() {
  // store states from store-state-graph evidence (Finding 245)
  const st = STATE.storeState;
  const rows = [];
  if (st === 2) {
    // warehouse grid: 12 cells at +0x720, cols 22/60/98/136 x rows 43/81/119
    const cols = [22, 60, 98, 136], rws = [43, 81, 119];
    let n = 0;
    for (const ry of rws) for (const cx of cols) {
      rows.push({
        id: `store.${n}`, name: `仓库格 ${n + 1}`,
        x: cx, y: ry, w: 38, h: 38, library: "Equip.wil", frame: n % 124,
        evidence_level: "candidate",
        note: "state2 warehouse grid · +0x720 · cols 22/60/98/136 × rows 43/81/119 · 0x44F940",
      });
      n++;
    }
    return rows;
  }
  // state0 buy five-row list / state3 craft / state4 detail: shared 5-row grid
  const rowsY = [40, 86, 132, 178, 224];
  for (let i = 0; i < 10; i++) {
    rows.push({
      id: `store.${i}`, name: st === 3 ? `配方 ${i + 1}` : st === 4 ? `详情 ${i + 1}` : `物品 ${i + 1}`,
      x: 12 + (i % 2) * 130, y: rowsY[Math.floor(i / 2)],
      w: 42, h: 42, library: "Equip.wil", frame: i % 124,
      evidence_level: st === 3 ? "primary-static" : "candidate",
      note: `store state${st} grid · frame ${st === 3 ? 1000 : 1001} · 0x44F480/0x44FB00`,
    });
  }
  return rows;
}

// Round 5 (Finding 283, primary-static): trade window (id 3) content.
//   - 24 slots @+0x5B8 stride 0xC2C; item-id words @+0x298 (empty 0xFFFF),
//     index = cell + pane*200 (0x416950); clicks -> 0x416830/0x416950 ->
//     protocol 0x402/0x403 via 0x451AA0/0x451AD0 to runtime trade state 0x8AB828.
//   - cells 36px (stride 0x24), 5 cols x 6 rows per pane (0x416830); pane0
//     grid area (21,48)..(237,300), pane1 (253,48)..(469,300); hit zones
//     (21,48)..(201,264) / (253,48)..(433,264) (0x415B7C-0x415BC0).
//   - gold box (34,270)..(156,304) (0x416F05): click -> msgbox 0x405
//     '你要给对方多少金币?' (0x418030); accept -> msg 0x406 via 0x451B30.
//   - buttons invisible: close 161/162 @(532,350), accept 1061/1062 @(185,332),
//     cancel 1064/1065 @(225,332) (frames MISSING in WIL); hit -> sound 0x69
//     (0x4177F0), accept also sends 0x406 + [+0x13644]=1 finalized.
//   - split dividers: gauges @+0x13648/+0x13694 (frame 1070 16x360, NEVER
//     blitted); mouse 0x416E70 writes split widths [+0x54]/[+0x58].
function tradeContent(content) {
  const COLS = 5, ROWS = 6, CELL = 36;
  const paneX = [21, 253];   // pane0 / pane1 origins (window-relative)
  const paneY = 48;
  // demo icons are candidate: real item-id words are runtime 0x8AB828 state
  const demo = {
    "L0": { f: 0, n: "金创药（小）" }, "L6": { f: 3, n: "魔法药（小）" },
    "R12": { f: 6, n: "随机传送卷" },
  };
  for (let pane = 0; pane < 2; pane++) {
    for (let row = 0; row < ROWS; row++) {
      for (let col = 0; col < COLS; col++) {
        const x = paneX[pane] + col * CELL, y = paneY + row * CELL;
        const key = (pane ? "R" : "L") + (row * COLS + col);
        const slot = document.createElement("div");
        slot.className = "slot trade-cell";
        slot.style.cssText = `left:${x}px;top:${y}px;width:${CELL}px;height:${CELL}px`;
        slot.dataset.slot = `trade.${key}`;
        slot.dataset.rect = `${x},${y},${CELL},${CELL}`;
        slot.dataset.evidence = "primary-static";
        const d = demo[key];
        slot.dataset.desc = d
          ? `演示物品 ${d.n} · 图标 candidate (item-id 词=运行期 0x8AB828) · 槽+0x5B8/${row * COLS + col + pane * 25}`
          : `交易格 ${key} · item-id 词 +0x298 = 0xFFFF (空) · 槽+0x5B8/${row * COLS + col + pane * 25}`;
        slot.title = d ? `${d.n} · 图标 candidate` : `交易格 ${key} · primary-static`;
        if (d) slot.appendChild(makeImg("Equip.wil", d.f));
        slot.addEventListener("click", () => {
          if (STATE.tradeFinalized) { pushChat("[交易] 已接受/完成 — 点击无效 ([+0x13644]=1, 0x416FB4)"); return; }
          pushChat(d
            ? `[交易] 放入 ${d.n} → 协议 0x402 (0x451AA0 → 0x8AB828)`
            : `[交易] 空格 (item-id 0xFFFF) 点击无动作 (0x416950)`);
        });
        content.appendChild(slot);
      }
    }
  }
  // gold box: (34,270)..(156,304) rel; '确定' click flow -> 0x405 -> 0x406
  const gold = document.createElement("div");
  gold.className = "trade-gold";
  gold.style.cssText = "left:34px;top:270px;width:122px;height:34px";
  gold.dataset.evidence = "primary-static";
  gold.dataset.rect = "34,270,156,304";
  gold.dataset.desc = "金币盒 (34,270)-(156,304) · 0x416F05；点击 → msgbox 0x405 '你要给对方多少金币?' (0x418030)";
  gold.title = "金币盒 · primary-static · 点击输入金币";
  gold.addEventListener("click", () => {
    if (STATE.tradeFinalized) { pushChat("[交易] 已接受/完成 — 金币盒无效 (0x416FB4)"); return; }
    showPrompt("gold", "你要给对方多少金币？", (ok, _btn, value) => {
      if (ok) {
        STATE.tradeGold = Math.max(0, parseInt(value || "0", 10) || 0);
        if (STATE.tradeStateUpdater) STATE.tradeStateUpdater();
        pushChat(`[交易] 送出金币 ${STATE.tradeGold} → msg 0x405/0x406 (0x418030 → 0x451B30)`);
      }
    });
  });
  content.appendChild(gold);
  // invisible buttons — hit zones only (render 0x417640 never called by trade
  // paint; cancel frames 1064/1065 missing in WIL count 1103 => invisible by design)
  const zones = [
    { id: "trade.close", x: 532, y: 350, w: 28, h: 26,
      note: "关闭 (帧 161/162) → 音效 0x69 + consumed, 窗口保持 (0x4177F0/0x42ADB0 重激活)" },
    { id: "trade.accept", x: 185, y: 332, w: 48, h: 20,
      note: "接受 (帧 1061/1062) → 0x451B30 msg 0x406 + [+0x13644]=1 交易完成 (0x416EF0)" },
    { id: "trade.cancel", x: 225, y: 332, w: 64, h: 20,
      note: "取消 (帧 1064/1065 不存在) → 音效 0x69 仅命中 (0x4177F0)" },
  ];
  for (const z of zones) {
    const btn = document.createElement("div");
    btn.className = "trade-zone";
    btn.style.cssText = `left:${z.x}px;top:${z.y}px;width:${z.w}px;height:${z.h}px`;
    btn.dataset.evidence = "primary-static";
    btn.dataset.rect = `${z.x},${z.y},${z.x + z.w},${z.y + z.h}`;
    btn.dataset.desc = z.note;
    btn.title = z.note;
    btn.addEventListener("click", (ev) => {
      ev.stopPropagation();
      if (z.id === "trade.accept") {
        if (STATE.tradeFinalized) return;
        STATE.tradeFinalized = true;
        if (STATE.tradeStateUpdater) STATE.tradeStateUpdater();
        pushChat("[交易] 接受 → msg 0x406 (0x451B30) · 交易完成 ([+0x13644]=1)");
      } else {
        pushChat(`[音效 0x69] ${z.id} 命中 (0x4177F0) · 窗口保持`);
      }
    });
    content.appendChild(btn);
  }
  // split dividers: gauges @+0x13648/+0x13694, frame 1070 (16x360) never
  // blitted; invisible draggable handles. Finding 301: [+0x54]/[+0x58] =
  // top visible DATA ROW per pane (row offset, NOT pixel width); writers
  // 0x416E70 (absolute via 0x417C80 gauge set) / 0x416EF0 (stepper via
  // 0x417D00, strcmp gate 0x47ADB4) both store trunc(gauge_pos * 94.0).
  // Gauge thumb px = track px (0xB8=184) * pos_float, pos_float = split/93
  // (normalization 0x4179F7); drag maps lx -> pos=lx/184 clamped [0,1] ->
  // split = round(pos*94) in [0,93] (usable [0,34]: pane 40 rows, 6 visible).
  const TRACK_PX = 0xB8; // 184, trade gauge track width word[+0x1E] (ctor 0x417960)
  for (let i = 0; i < 2; i++) {
    const h = document.createElement("div");
    h.className = "trade-divider";
    const draw = () => {
      const x = paneX[i] + Math.round(TRACK_PX * (STATE.tradeSplit[i] / 93));
      h.style.cssText = `left:${x - 4}px;top:${paneY}px;width:8px;height:${ROWS * CELL}px`;
    };
    draw();
    h.dataset.evidence = "primary-static";
    h.dataset.rect = `divider ${i}`;
    h.dataset.desc = `分割把手 gauge @+0x${(0x13648 + i * 0x4C).toString(16)} (帧 1070 16×360, 从不 blit)；Finding 301：[+0x${(0x54 + i * 4).toString(16)}] = 顶部可见数据行 (行偏移, 94 定点尺度, 可用 [0,34])；写者 0x416E70/0x416EF0 → trunc(gauge_pos×94.0)`;
    h.title = `分割把手 ${i + 1} · 行偏移 [+0x${(0x54 + i * 4).toString(16)}] · 拖拽调滚动行`;
    let dragging = false;
    h.addEventListener("pointerdown", (ev) => { ev.stopPropagation(); dragging = true; });
    window.addEventListener("pointermove", (ev) => {
      if (!dragging) return;
      const cr = content.getBoundingClientRect();
      const lx = (ev.clientX - cr.left) / STATE.scale - paneX[i];
      const pos = Math.max(0, Math.min(1, lx / TRACK_PX)); // gauge set clamp [0,1]
      STATE.tradeSplit[i] = Math.round(pos * 94);           // trunc(gauge_pos * 94.0)
      draw();
    });
    window.addEventListener("pointerup", () => { dragging = false; });
    content.appendChild(h);
  }
  // trade state label ([+0x13644])
  const st = document.createElement("div");
  st.className = "lbl";
  st.id = "trade-state-label";
  st.style.cssText = "left:8px;top:304px;width:300px;font:10px monospace;color:#ffd77a";
  st.textContent = "交易中 ([+0x13644]=0) · 玩家间交易 · Finding 283";
  content.appendChild(st);
  const upd = () => {
    st.textContent = STATE.tradeFinalized
      ? "交易完成 ([+0x13644]=1) · 点击无效"
      : `交易中 ([+0x13644]=0) · 金币 ${STATE.tradeGold}`;
  };
  STATE.tradeStateUpdater = upd;
}

function selectSlot(el, meta) {
  document.querySelectorAll("#windows .slot.selected").forEach((n) => n.classList.remove("selected"));
  el.classList.add("selected");
  pushChat(`[选中] ${meta.id || meta.name || "格子"}`);
  if (meta.id && meta.id.startsWith("skill.")) pushChat(`[技能] ${meta.name}`);
  if (meta.id && meta.id.startsWith("slot.")) pushChat(`[装备] ${meta.name}`);
  if (meta.id && meta.id.startsWith("bag.")) pushChat(`[背包] 第 ${parseInt(meta.id.split(".")[1], 10) + 1} 格`);
}

/* ------------------------------------------------------------ window open/close/drag */
function setWindowOpen(id, open) {
  const box = winEl.querySelector(`[data-window="${id}"]`);
  if (!box) return;
  if (open) {
    // Round 31 (F337): original is modal - 0x42ADB0 runs close-all 0x42B820
    // before showing the requested window (single active window at a time).
    // Notice window id15 is excluded from close-all in the original.
    winEl.querySelectorAll(".win:not(.closed)").forEach((w) => {
      const wid = w.dataset.window;
      if (wid === id || wid === "window.notice-prompt-candidate") return;
      w.classList.add("closed");
      STATE.openWindows.delete(wid);
    });
    box.classList.remove("closed");
    STATE.openWindows.add(id);
    bringToFront(id);
    refreshWindowContent(id);
  } else {
    box.classList.add("closed");
    STATE.openWindows.delete(id);
    if (STATE.foregroundWindow === id) STATE.foregroundWindow = null;
  }
}

function bringToFront(id) {
  STATE.foregroundWindow = id;
  winEl.querySelectorAll(".win").forEach((w) => w.classList.remove("foreground"));
  const box = winEl.querySelector(`[data-window="${id}"]`);
  if (box) box.classList.add("foreground");
}

function refreshWindowContent(id) {
  if (id === "window.store-candidate") {
    // re-fill so the grid follows the state machine (state0 buy / 2 warehouse / 3 craft)
    const w = STATE.data.windows.find((q) => q.id === id);
    if (w) fillWindowContent(w);
  }
  if (id === "window.npc-candidate") {
    // Round 41 (F347): NPC dialog script renderer - type-4 tokens FCOLOR/NPCIMG
    // (0x43FF92), menu color table 0x47C4A8. Fill a demo dialog: portrait +
    // text lines with FCOLOR palette.
    const box = winEl.querySelector(`[data-window="${id}"]`);
    if (!box) return;
    const e = STATE.selectedEntity;
    const lines = [
      { t: `[NPCIMG 0] ${e ? e.name : "比奇武器商"}`, c: 0x808080 },
      { t: "FCOLOR 0 你好，勇士！", c: 0x0 },
      { t: "FCOLOR 2 购买装备 (frame 0x3F2)", c: 0x8000 },
      { t: "FCOLOR 4 出售物品 (frame 0x3F4)", c: 0x808080 },
      { t: "FCOLOR 6 修理装备", c: 0x808000 },
    ];
    let body = box.querySelector(".npc-body");
    if (!body) {
      body = document.createElement("div");
      body.className = "npc-body";
      body.style.cssText = "position:absolute;left:8px;top:8px;right:8px;bottom:8px;font-size:11px;line-height:16px;overflow:auto;";
      box.appendChild(body);
    }
    body.innerHTML = lines.map((l) =>
      `<div style="color:#${(l.c & 0xFFFFFF).toString(16).padStart(6, "0")}">${l.t}</div>`
    ).join("");
    // click a menu line -> close dialog (original: consumed -> 0x42ADB0 close)
    body.querySelectorAll("div").forEach((d, i) => {
      d.style.cursor = i >= 2 ? "pointer" : "default";
      d.addEventListener("click", () => {
        pushChat(`[NPC] 选择: ${d.textContent}`);
        setWindowOpen(id, false);
      });
    });
  }
}

function bindWindowDrag(box) {
  const tb = box.querySelector(".win-titlebar");
  let dragging = false, dx = 0, dy = 0;
  tb.addEventListener("pointerdown", (ev) => {
    ev.preventDefault();
    bringToFront(box.dataset.window);
    dragging = true;
    const r = box.getBoundingClientRect();
    const sr = stage.getBoundingClientRect();
    dx = (ev.clientX - r.left) / STATE.scale;
    dy = (ev.clientY - r.top) / STATE.scale;
    box.classList.add("dragging");
  });
  window.addEventListener("pointermove", (ev) => {
    if (!dragging) return;
    const sr = stage.getBoundingClientRect();
    let x = (ev.clientX - sr.left) / STATE.scale - dx;
    let y = (ev.clientY - sr.top) / STATE.scale - dy;
    x = Math.max(-50, Math.min(VIEW_W - 60, x));
    y = Math.max(0, Math.min(VIEW_H - 40, y));
    box.style.left = x + "px";
    box.style.top = y + "px";
    // update data model so evidence mode stays consistent
    const w = STATE.data.windows.find((q) => q.id === box.dataset.window);
    if (w) { w.rect[0] = x; w.rect[1] = y; }
  });
  window.addEventListener("pointerup", () => {
    dragging = false;
    box.classList.remove("dragging");
  });
}

/* ------------------------------------------------------------ HUD control actions */
function onHudControl(id) {
  switch (id) {
    case "hud.status": setWindowOpen("window.status", !isOpen("window.status")); break;
    case "hud.inventory": setWindowOpen("window.inventory", !isOpen("window.inventory")); break;
    case "hud.skill": case "hud.skill-entry":
      setWindowOpen("window.skill-book", !isOpen("window.skill-book")); break;
    case "hud.chat": setWindowOpen("window.chat-pop", !isOpen("window.chat-pop")); break;
    case "hud.quest": setWindowOpen("window.quest", !isOpen("window.quest")); break;
    case "hud.option": setWindowOpen("window.option", !isOpen("window.option")); break;
    case "hud.store": setWindowOpen("window.store-candidate", !isOpen("window.store-candidate")); break;
    case "hud.party": case "hud.group":
      setWindowOpen("window.group", !isOpen("window.group")); break;
    case "hud.guild": setWindowOpen("window.guild-candidate", !isOpen("window.guild-candidate")); break;
    case "hud.exchange": setWindowOpen("window.exchange-candidate", !isOpen("window.exchange-candidate")); break;
    case "hud.minimap": cycleMinimap(); break;
    case "hud.logout":
      showPrompt("confirm", "确定要返回人物选择吗？", () => {
        pushChat("[系统] 已断开连接（模拟）");
        STATE.hp = 0; renderHud();
      });
      break;
    case "hud.exit":
      showPrompt("confirm", "确定要退出游戏吗？", () => {
        pushChat("[系统] 退出游戏（模拟）");
      });
      break;
  }
}

function isOpen(id) {
  const box = winEl.querySelector(`[data-window="${id}"]`);
  return box && !box.classList.contains("closed");
}

function setCurrentMap(index) {
  const binds = STATE.data.map_bindings || [];
  if (!binds.length) return;
  STATE.currentMapIndex = ((index % binds.length) + binds.length) % binds.length;
  const b = binds[STATE.currentMapIndex];
  const mm = STATE.data.maps.find((q) => q.id === "map.minimap");
  const bg = STATE.data.maps.find((q) => q.id === "map.bg");
  if (mm) { mm.library = b.library; mm.frame = b.frame; }
  if (bg) { bg.library = b.library; bg.frame = b.frame; }
  STATE.currentMap = { name: b.name, map: b.map };
  renderScene();
  const mmEl = hudEl.querySelector(".minimap img");
  const mmBox = hudEl.querySelector(".minimap");
  if (mmEl) mmEl.src = imgUrl(b.library, b.frame);
  const t = `小地图 · ${b.name} · ${b.library} F${b.frame} · derived`;
  if (mmEl) mmEl.title = t;
  if (mmBox) mmBox.title = t;
  const wh = (b.w && b.h) ? ` ${b.w}×${b.h}` : "";
  pushChat(`[地图] ${b.name} (${b.map}${wh}) → ${b.library} F${b.frame}`);
}

function cycleMinimap() {
  setCurrentMap((STATE.currentMapIndex || 0) + 1);
}

/* ------------------------------------------------------------ prompts */
const PROMPT_BUTTONS = {
  confirm: {
    background: { lib: "GameInter.wil", frame: 950, w: 360, h: 190 },
    center: [400, 246],
    buttons: [
      { id: "ok", rel: [51, 125, 44, 20], frames: [151, 152], label: "确定" },
      { id: "cancel", rel: [147, 125, 64, 20], frames: [157, 158], label: "取消" },
      { id: "alt", rel: [244, 125, 44, 20], frames: [154, 155], label: "其他" },
    ],
    text: { rel: [20, 30, 320, 80] },
  },
  notice: {
    background: { lib: "GameInter.wil", frame: 602, w: 584, h: 252 },
    center: [107, 110],
    buttons: [
      { id: "ok", rel: [520, 220, 28, 26], frames: [161, 162], label: "确定" },
      { id: "alt", rel: [540, 160, 28, 26], frames: [606, 607], label: "其他" },
    ],
    text: { rel: [23, 94, 400, 60] },
  },
  gold: {
    // trade gold input (Finding 283): msgbox 0x405 '你要给对方多少金币?'
    // (0x418030) — input + 确定; 确定 -> msg 0x406 (0x451B30) finalize.
    background: { lib: "GameInter.wil", frame: 950, w: 360, h: 190 },
    center: [400, 246],
    buttons: [
      { id: "ok", rel: [51, 125, 44, 20], frames: [151, 152], label: "确定" },
      { id: "cancel", rel: [147, 125, 64, 20], frames: [157, 158], label: "取消" },
    ],
    text: { rel: [20, 24, 320, 40] },
    input: { rel: [20, 72, 320, 28] },
  },
};

function showPrompt(kind, text, cb) {
  const spec = PROMPT_BUTTONS[kind];
  const [cx, cy] = spec.center;
  const [bw, bh] = [spec.background.w, spec.background.h];
  const x = Math.round(cx - bw / 2), y = Math.round(cy - bh / 2);
  const box = document.createElement("div");
  box.className = "prompt visible";
  box.dataset.prompt = kind;
  box.style.cssText = `left:${x}px;top:${y}px;width:${bw}px;height:${bh}px`;
  const bg = makeImg(spec.background.lib, spec.background.frame);
  bg.className = "p-bg";
  box.appendChild(bg);
  const pt = document.createElement("div");
  pt.className = "p-text";
  const [tl, tt, tw, th] = spec.text.rel;
  pt.style.cssText = `left:${tl}px;top:${tt}px;width:${tw}px;height:${th}px`;
  pt.textContent = text;
  box.appendChild(pt);
  let inputEl = null;
  if (spec.input) {
    inputEl = document.createElement("input");
    const [il, it, iw, ih] = spec.input.rel;
    inputEl.className = "p-input";
    inputEl.type = "number";
    inputEl.min = "0";
    inputEl.placeholder = "输入金币数量";
    inputEl.style.cssText = `left:${il}px;top:${it}px;width:${iw}px;height:${ih}px`;
    box.appendChild(inputEl);
    inputEl.focus();
  }
  const result = { ok: false };
  for (const b of spec.buttons) {
    const btn = document.createElement("div");
    btn.className = "p-btn";
    const [bl, bt, bww, bhh] = b.rel;
    btn.style.cssText = `left:${bl}px;top:${bt}px;width:${bww}px;height:${bhh}px`;
    const im = makeImg("GameInter.wil", b.frames[0]);
    btn.appendChild(im);
    btn.title = b.label;
    btn.addEventListener("click", (ev) => {
      ev.stopPropagation();
      result.ok = b.id === "ok";
      box.remove();
      STATE.prompt = null;
      if (cb) cb(result.ok, b.id, inputEl ? inputEl.value : null);
    });
    box.appendChild(btn);
  }
  // clicking backdrop cancels for confirm
  box.addEventListener("click", (ev) => {
    if (ev.target === box) {
      box.remove();
      STATE.prompt = null;
      if (cb) cb(false, "backdrop");
    }
  });
  promptEl.appendChild(box);
  STATE.prompt = { kind, box };
  pushChat(`[提示] ${text}`);
}

/* ------------------------------------------------------------ scene interaction */
function bindSceneInteraction() {
  sceneEl.addEventListener("pointerover", (ev) => {
    const spr = ev.target.closest(".sprite");
    sceneEl.querySelectorAll(".sprite.hovered").forEach((n) => n.classList.remove("hovered"));
    if (spr) {
      spr.classList.add("hovered");
      STATE.hoveredEntity = STATE.data.entities.find((e) => e.id === spr.dataset.entity) || null;
      // hover -> show target box (client hover msg 0xB chain, see target-box-evidence.json)
      updateTargetBox();
    } else {
      STATE.hoveredEntity = null;
      updateTargetBox();
    }
  });
  sceneEl.addEventListener("pointerout", (ev) => {
    if (ev.target.closest(".sprite")) {
      STATE.hoveredEntity = null;
      updateTargetBox();
    }
  });
  sceneEl.addEventListener("click", (ev) => {
    const spr = ev.target.closest(".sprite");
    if (!spr) return;
    const e = STATE.data.entities.find((q) => q.id === spr.dataset.entity);
    if (!e) return;
    if (e.kind === "npc") {
      setTarget(e);
      setWindowOpen("window.npc-candidate", true);
      pushChat(`[NPC] 你点击了 ${e.name}`);
    } else if (e.kind === "player") {
      // click player -> character info (status window shows equipment)
      setTarget(e);
      setWindowOpen("window.status", true);
      pushChat(`[人物] 你点击了 ${e.name}，打开人物资料`);
    } else if (e.kind === "drop") {
      // click drop -> pick up demo (Ground.wil item)
      setTarget(e);
      pushChat(`[拾取] 你捡起了 ${e.name}`);
      const spr = sceneEl.querySelector(`.sprite[data-entity="${e.id}"]`);
      if (spr) spr.remove();
      // picked-up drop is no longer a valid target (0x40B850 name-plate needs
      // a live entity sprite); clear selection so hover takes over cleanly
      STATE.selectedEntity = null;
      updateTargetPanel();
      updateTargetBox();
    } else {
      setTarget(e);
      pushChat(`[目标] 怪物：${e.name}`);
      // demo: damage feedback
      pushChat(`[战斗] 你对 ${e.name} 造成 8 点伤害`);
    }
  });
}

/* ------------------------------------------------------------ evidence mode */
function renderEvidenceOverlay() {
  evEl.innerHTML = "";
  if (!STATE.evidence) return;
  const layer = evEl;
  const add = (rect, lvl, label, extra) => {
    const d = document.createElement("div");
    d.className = `ev ${lvl}`;
    d.style.cssText = `left:${rect[0]}px;top:${rect[1]}px;width:${Math.max(1, rect[2] - rect[0])}px;height:${Math.max(1, rect[3] - rect[1])}px`;
    const tag = document.createElement("div");
    tag.className = "ev-tag";
    tag.innerHTML = `${label} <span class="lvl">[${lvl}]</span> ${extra || ""}`;
    d.appendChild(tag);
    layer.appendChild(d);
  };
  // HUD
  const hud = STATE.data.hud;
  add(hud.origin.concat([hud.origin[0] + 800, hud.origin[1] + 135]), "primary", "HUD 底板 F50");
  for (const b of ["hp_bar", "mp_bar", "exp_bar"]) {
    const m = hud[b];
    add(m.rect, m.evidence_level, b, m.note ? "" : "");
  }
  // controls
  for (const c of STATE.data.controls) {
    add(c.rect, c.evidence_level, c.id, `F${c.frame_pair[0]}`);
  }
  // windows
  for (const w of STATE.data.windows) {
    add(w.rect, w.evidence_level, w.id, `F${w.frame}`);
  }
  // entities
  for (const e of STATE.data.entities) {
    add([e.x - 20, e.y - 60, e.x + 20, e.y], e.evidence_level, e.id, e.library);
  }
  // equipment slots (window-relative -> absolute via status window origin 278,136)
  const sw = STATE.data.windows.find((w) => w.id === "window.status");
  if (sw) {
    for (const s of STATE.data.equipment_slots || []) {
      add([sw.rect[0] + s.x, sw.rect[1] + s.y, sw.rect[0] + s.x + s.w, sw.rect[1] + s.y + s.h],
        s.evidence_level, s.id, s.library);
    }
  }
  // trade window internals (Finding 283, primary-static): cells, gold box,
  // invisible button zones, split dividers
  const tw = STATE.data.windows.find((w) => w.id === "window.exchange-candidate");
  if (tw) {
    const [wx, wy] = tw.rect;
    for (let pane = 0; pane < 2; pane++) {
      const px = wx + (pane ? 253 : 21);
      for (let r = 0; r < 6; r++) {
        for (let c = 0; c < 5; c++) {
          add([px + c * 36, wy + 48 + r * 36, px + c * 36 + 36, wy + 48 + r * 36 + 36],
            "primary-static", `trade.cell ${pane ? "R" : "L"}${r * 5 + c}`, "槽+0x5B8");
        }
      }
    }
    add([wx + 34, wy + 270, wx + 156, wy + 304], "primary-static", "trade.gold", "0x416F05");
    add([wx + 185, wy + 332, wx + 233, wy + 352], "primary-static", "trade.accept", "F1061/1062 隐形");
    add([wx + 225, wy + 332, wx + 289, wy + 352], "primary-static", "trade.cancel", "F1064/1065 不存在");
    add([wx + 532, wy + 350, wx + 560, wy + 376], "primary-static", "trade.close", "F161/162 隐形");
    add([wx + 21 + 90, wy + 48, wx + 21 + 90 + 4, wy + 264], "primary-static", "trade.divider.0", "gauge +0x13648");
    add([wx + 253 + 90, wy + 48, wx + 253 + 90 + 4, wy + 264], "primary-static", "trade.divider.1", "gauge +0x13694");
    // frame 1050 overflow (7,-44) 512x512 — the only static art
    add([wx + 7, wy - 44, wx + 7 + 512, wy - 44 + 512], "primary-static", "trade.frame.1050", "512×512 @(7,−44)");
  }

  // target box: code-drawn composite, fixed-anchor path 0x4120B0 writes (376,227)
  if (hud.target_box) {
    add([374, 225, 378, 229], hud.target_box.evidence_level, "target_box fixed-anchor 0x4120B0", "");
  }
}

function setEvidence(on) {
  STATE.evidence = on;
  evEl.classList.toggle("hidden", !on);
  $("#nav button[data-act=evidence]").classList.toggle("active", on);
  renderEvidenceOverlay();
}

/* ------------------------------------------------------------ test nav */
function renderTestNav() {
  const grid = $("#testnav-grid");
  grid.innerHTML = "";
  for (const w of STATE.data.windows) {
    const btn = document.createElement("button");
    btn.textContent = WINDOW_TITLES[w.id] || w.id;
    btn.addEventListener("click", () => setWindowOpen(w.id, !isOpen(w.id)));
    grid.appendChild(btn);
  }
  const extra = [
    ["confirm 确认框", () => showPrompt("confirm", "确认框演示：是否继续？", (ok) => pushChat(ok ? "[确认] 继续" : "[确认] 取消"))],
    ["notice 公告", () => showPrompt("notice", "[行会公告，请自行修改公告内容.]", (ok) => pushChat("[公告] 已读"))],
    ["商店状态+1", () => { STATE.storeState = (STATE.storeState + 1) % 5; setWindowOpen("window.store-candidate", true); STATE.storeFeedback = STATE.storeState === 3 ? "돈이 부족합니다 (0x47B634)" : ""; pushChat(`[商店] ${STORE_STATE_NAMES[STATE.storeState] || "状态 " + STATE.storeState}`); }],
    ["商店状态-1", () => { STATE.storeState = (STATE.storeState + 4) % 5; setWindowOpen("window.store-candidate", true); STATE.storeFeedback = ""; pushChat(`[商店] ${STORE_STATE_NAMES[STATE.storeState] || "状态 " + STATE.storeState}`); }],
    ["背包模式+1", () => { STATE.inventoryMode = (STATE.inventoryMode + 1) % 4; const m = document.getElementById("inventory-mode-label"); if (m) m.textContent = ["包袱 (mode0)", "修补 (mode1)", "变卖 (mode2)", "储存 (mode3)"][STATE.inventoryMode]; pushChat(`[背包] mode${STATE.inventoryMode} · 0x42EF2F`); }],
    ["切换场景", () => setCurrentMap((STATE.currentMapIndex || 0) + 1)],
  ];
  for (const [label, fn] of extra) {
    const btn = document.createElement("button");
    btn.textContent = label;
    btn.addEventListener("click", fn);
    grid.appendChild(btn);
  }
  $("#testnav").classList.toggle("hidden", !STATE.testnav);
}

/* ------------------------------------------------------------ hotkeys (Round 32 F338) */
// Maps layout window record id -> data-window box id. Hotkey table 0x42CC76:
// Q->id0 bag, W->id1 status, E->id14 skill book, R->id8 chat, S->id13 horse,
// D->id11 quest, G->id6 group, N->id12 option (primary-bytes).
const HOTKEY_WINDOW_ID = {
  Q: 0, W: 1, E: 14, R: 8, S: 13, D: 11, G: 6, N: 12,
};
function bindHotkeys() {
  // map window_id -> data.windows layout record by frame (frames are unique per window class)
  const frameToLayout = {};
  for (const w of STATE.data.windows || []) {
    if (typeof w.frame === "number") frameToLayout[w.frame] = w.id;
  }
  document.addEventListener("keydown", (ev) => {
    const k = ev.key.toUpperCase();
    if (ev.ctrlKey || ev.altKey || ev.metaKey) return; // original uses raw GetKeyState on plain keys
    const wid = HOTKEY_WINDOW_ID[k];
    if (wid === undefined) return;
    ev.preventDefault();
    const frame = FRAME_BY_ID[wid];
    const boxId = frameToLayout[frame];
    if (!boxId) { pushChat(`[热键] ${k}: id${wid} (帧 ${frame} 未在布局中)`); return; }
    const box = winEl.querySelector(`[data-window="${boxId}"]`);
    const open = box ? !box.classList.contains("closed") : false;
    setWindowOpen(boxId, !open);
    pushChat(`[热键] ${k} → ${open ? "关闭" : "打开"} ${boxId} (id${wid})`);
  });
}
const FRAME_BY_ID = { 0: 250, 1: 200, 2: 1000, 3: 1050, 4: 600, 6: 900, 7: 200, 8: 350, 9: 1100, 11: 700, 12: 750, 13: 850, 14: 400, 15: 602 };

/* ------------------------------------------------------------ login flow (Round 43 F349) */
// Original: [0x8B1878] stage machine (F336) - 0 intro 0x402BE0@0x8A9520 /
// 2 char-select 0x4575D0@0x8A7140 / 3 in-game 0x41BB00@main. Char-select
// stages [0x930] (F349): 0 list / 1 creating / 2 login anim + SelChr.mp3
// (0x47D624) / 3 enter 0x458B20 / 4 done. Server dispatch 0x458F80:
// msgid-0x208 -> 9-entry table 0x45950C (0x208 char list refresh etc).
function renderLoginOverlay() {
  if (document.getElementById("login-overlay")) return;
  const ov = document.createElement("div");
  ov.id = "login-overlay";
  ov.style.cssText = "position:absolute;left:0;top:0;width:100%;height:100%;background:rgba(0,0,0,0.85);display:flex;flex-direction:column;align-items:center;justify-content:center;z-index:99;color:#fff;font-family:sans-serif;";
  ov.innerHTML = `
    <h2 style="letter-spacing:4px;color:#96C8FF;text-shadow:0 0 12px rgba(150,200,255,0.8);">传奇 3.0</h2>
    <p style="color:#808080;font-size:12px;margin:4px 0 16px;">Mir3 EI 3.0 原版客户端模拟器</p>
    <div id="login-account" style="margin:4px;font-size:12px;color:#0f0;">账号: <input style="width:140px"></div>
    <div style="margin:4px;font-size:12px;color:#0f0;">密码: <input type="password" style="width:140px"></div>
    <button id="login-btn" style="margin-top:16px;padding:6px 24px;background:#444;color:#fff;border:1px solid #96C8FF;cursor:pointer;">进入游戏</button>
    <p id="login-note" style="font-size:11px;color:#666;margin-top:8px;">原版流程: 选择服务器 → 角色列表 (0x458F80 分派) → 进入游戏</p>`;
  document.getElementById("stage-wrap").appendChild(ov);
  document.getElementById("login-btn").addEventListener("click", () => {
    // stage 0 intro -> 1 char-select (list) -> 2 in-game (0x458B20 enter)
    ov.querySelector("#login-note").textContent = "正在连接服务器... (0x458F80: 0x208 角色列表)";
    setTimeout(() => {
      ov.querySelector("#login-note").textContent = "角色列表就绪 - 选择角色进入 (0x4575D0 stage 3 → 0x458B20)";
      setTimeout(() => {
        ov.remove();
        STATE.loginStage = 2;
        pushChat("[系统] 进入游戏 (0x8B1878 state 3 → 0x41BB00 tick)");
      }, 800);
    }, 700);
  });
}

/* ------------------------------------------------------------ boot */
async function boot() {
  try {
    STATE.data = await loadData();
    if ((STATE.data.map_bindings || []).length) {
      STATE.currentMap = {
        name: STATE.data.map_bindings[0].name,
        map: STATE.data.map_bindings[0].map,
      };
    }
  } catch (e) {
    $("#status").textContent = `数据加载失败: ${e.message}`;
    return;
  }
  renderScene();
  renderHud();
  renderWindows();
  bindHotkeys();
  bindSceneInteraction();
  renderEvidenceOverlay();
  renderTestNav();
  renderLoginOverlay();
  applyScale();
  $("#status").textContent = "就绪";
  const counts = {
    windows: STATE.data.windows.length,
    controls: STATE.data.controls.length,
    entities: STATE.data.entities.length,
    resources: STATE.data.resources.length,
  };
  $("#evidence-summary").textContent =
    `windows=${counts.windows} controls=${counts.controls} entities=${counts.entities} resources=${counts.resources} · 数据源 layout.json`;

  // demo: periodic HP/MP oscillation
  setInterval(() => {
    STATE.hp = Math.max(20, (STATE.hp + 0.7) % 101);
    STATE.mp = Math.max(20, (STATE.mp + 0.4) % 101);
    updateBars();
  }, 1500);

  // entity sprite animation: cycles the closed state-table formulas
  // (Findings 279-282). Each entity advances at its own w2 interval.
  setInterval(() => {
    const now = performance.now();
    for (const e of STATE.data.entities || []) {
      if (!e.appearance) continue;
      const im = sceneEl.querySelector(`.sprite[data-entity="${e.id}"] img`);
      if (!im) continue;
      const f = entityFrame(e, now);
      if (f !== im.dataset.frame) {
        im.dataset.frame = f;
        im.src = imgUrl(e.library, f);
        im.alt = `${e.library} F${f}`;
      }
    }
  }, 100);
}

function updateBars() {
  const bars = [
    { key: "hp_bar", cls: "hp", val: STATE.hp, label: "血量" },
    { key: "mp_bar", cls: "mp", val: STATE.mp, label: "魔法" },
    { key: "exp_bar", cls: "exp", val: STATE.exp, label: "经验" },
  ];
  for (const b of bars) {
    const meta = STATE.data.hud[b.key];
    const [l, t, r, bot] = meta.rect;
    const w = r - l, h = bot - t;
    const fill = hudEl.querySelector(`.bar-fill.${b.cls}`);
    if (!fill) continue;
    const bw = Math.max(0, Math.min(100, b.val)) / 100;
    const base = b.cls === "exp" ? w : w * 0.5;
    if (b.cls === "exp") {
      fill.style.width = Math.round(base * bw) + "px";
    } else {
      fill.style.height = Math.round(h * bw) + "px";
    }
    // keep the numeric label in sync with the animated fill
    const lbl = hudEl.querySelector(`.lbl[data-bar="${b.cls}"]`);
    if (lbl) lbl.textContent = `${b.label} ${Math.round(b.val)}/100`;
  }
}

document.addEventListener("DOMContentLoaded", () => {
  document.querySelectorAll("#nav button").forEach((btn) => {
    btn.addEventListener("click", () => {
      const act = btn.dataset.act;
      if (act === "evidence") setEvidence(!STATE.evidence);
      else if (act === "testnav") { STATE.testnav = !STATE.testnav; renderTestNav(); }
      else if (act === "reset") resetScene();
    });
  });
  document.querySelector('[data-act="close-testnav"]').addEventListener("click", () => {
    STATE.testnav = false;
    renderTestNav();
  });
  boot();
});

function resetScene() {
  // reset windows closed, clear target, reset store state, reload scene
  STATE.openWindows.clear();
  winEl.querySelectorAll(".win").forEach((w) => w.classList.add("closed"));
  STATE.selectedEntity = null;
  STATE.hoveredEntity = null;
  STATE.storeState = 0;
  STATE.tradeGold = 0;
  STATE.tradeFinalized = false;
  STATE.tradeSplit = [0, 0];
  targetboxEl.classList.add("hidden");
  const tp = $("#target-panel");
  if (tp) tp.classList.remove("visible");
  renderScene();
  pushChat("[系统] 场景已重置");
}
