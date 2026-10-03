#!/usr/bin/env python3
"""Build the Mud3 EI2.0 DAT <-> Zircon System.db *item* identity table.

Read-only generator.  It never opens System.db and never writes anything outside
this directory (``items.json`` / ``items.md``).

Contract: /home/tetsuya/development/Mir3-Research/docs/research/mud3-identity/README.md
Handoff:  Zircon/docs/pending/MUD3_CONTENT_AND_LEGACY_BAG_HANDOFF_2026-10-03.md §1.4

Confidence values
-----------------
closed      : 1:1 with a verified primary anchor (numeric price/weight/
              durability/recovery/level, or appearance Looks<->Image).
pending     : a plausible but unconfirmed pairing.  ``zircon_index`` is a
              *proposed* candidate only; the entry is never consumed as an
              identity and the evidence lists every alternative candidate.
missing     : Mud3 has the item, Zircon has no counterpart.
zircon-only : Zircon has the item, Mud3 has none (``mud3_name`` is null).

Bookkeeping (enforced by the coverage self-check at the end)
------------------------------------------------------------
One entry per Mud3 record; one entry per Zircon record (matched or zircon-only).
Exactly one ``closed``/``pending``/``missing`` entry per Mud3 row and exactly one
``closed``/``pending``/``zircon-only`` entry per Zircon row, therefore

    closed + pending + missing    == 1143
    closed + pending + zircon-only == 1078
    no duplicate zircon_index among closed rows

A ``pending`` row carries a single *proposed* index (human review required) and
lists the other candidates in evidence; it is never treated as an identity by
downstream tooling.  Where a Mud3 variant has no free Zircon counterpart (its
only candidates are already paired), it is reported as ``missing`` with those
candidates named.

Zircon indices are the current snapshot from ``SystemDbProbe --json``; the
2026-08-14 dbeditor workspace and ``docs/database/views`` are NOT used.
"""

from __future__ import annotations

import argparse
import json
import re
from collections import Counter, defaultdict
from pathlib import Path

# --------------------------------------------------------------------------
# Paths (defaults match the repository layout; all overridable by CLI)
# --------------------------------------------------------------------------
DEFAULT_MUD3_ITEM = Path(
    "/home/tetsuya/development/Mir3-Research/docs/research/mud3-dat-decoded/stditem.json"
)
DEFAULT_ZIRCON_SNAPSHOT = Path("/tmp/sysdb_probe.json")
DEFAULT_OUT_DIR = Path(
    "/home/tetsuya/development/Mir3-Research/docs/research/mud3-identity"
)
COMPARISON_PY = Path(
    "/home/tetsuya/development/Mir3-Research/docs/research/mud3-dat-decoded/build_comparison.py"
)
SKILLS_ZIRCON = Path(
    "/home/tetsuya/development/Mir3-Research/docs/research/mud3-dat-decoded/skills_zircon.json"
)

# --------------------------------------------------------------------------
# StdMode -> allowed Zircon ItemType(s).  Derived empirically from the
# image-independent exact matches (Price/Weight/Durability/RequiredAmount) and
# cross-checked with appearance matches.
# --------------------------------------------------------------------------
STDMODE_TYPES = {
    0: {"Consumable"},
    1: {"Meat", "Consumable"},
    2: {"Meat", "Consumable"},
    3: {"Consumable", "Torch", "Amulet", "Nothing"},
    4: {"Book"},  # 秘籍 (advanced manual)
    5: {"Weapon"},
    6: {"Weapon"},
    10: {"Armour"},
    11: {"Armour"},
    15: {"Helmet"},
    19: {"Necklace"},
    20: {"Necklace"},
    21: {"Necklace"},
    22: {"Ring"},
    23: {"Ring"},
    24: {"Bracelet"},
    25: {"Amulet", "Poison", "Consumable"},
    26: {"Bracelet"},
    30: {"Torch"},
    40: {"Meat", "Consumable", "Nothing"},
    41: {"Currency"},
    43: {"Ore"},
    44: {"Nothing", "DarkStone", "RefineSpecial", "ItemPart", "Ore"},
    45: {"Nothing"},
    46: {"Nothing"},
    47: {"Nothing"},
    50: {"Nothing", "System"},
    51: {"Book"},  # usable skill book
    52: {"Nothing"},
    53: {"Shoes"},
    54: {"Nothing", "System"},
    55: {"Nothing"},
    58: {"Nothing", "System", "Consumable"},
    59: {"Nothing"},
    60: {"Flower", "Nothing"},
    99: None,  # special/unclassified: search all types
}

# anchor weights (sum = evidence strength)
WEIGHTS = {"image": 4, "price": 2, "weight": 2, "dura": 3, "level": 1, "hp": 4, "mp": 4}

# A pairing is a *plausible candidate* when it has at least two independent
# anchors including appearance (score >= 6), or at least three numeric anchors
# without appearance, OR a Looks<->Image that is unique on BOTH sides (a pure
# appearance anchor is allowed by the evidence hierarchy when it is unambiguous).
CLOSED_MIN_SCORE = 6
PENDING_MIN_SCORE = 6

# --------------------------------------------------------------------------
# Verified manual anchors (task-provided + ITEM_MAP where independently
# re-verified against the fresh snapshot + newly closed by exact tuple).
# --------------------------------------------------------------------------
MANUAL_ANCHORS = {
    "金币": (1, "StdMode 41 currency; Mud3 price=1 (min unit) matches only Currency row 'Gold'"),
    "金创药（小）": (133, "price 80=80; image Looks5=Image5; Health 30=30"),
    "金创药（中）": (134, "price 200=200; image Looks6=Image6; Health 70=70"),
    "金创药（大）": (135, "price 500=500; image Looks7=Image7; Health 110=110"),
    "金创药（特）": (136, "price 1250=1250; image Looks8=Image8; Health 170=170"),
    "魔法药（小）": (143, "image Looks15=Image15; Mana 40=40; price 80->84 (tier)"),
    "魔法药（中）": (144, "image Looks16=Image16; Mana 110=110; price 200->210 (tier)"),
    "魔法药（大）": (145, "image Looks17=Image17; Mana 180=180; price 500->525 (tier)"),
    "魔法药（特）": (146, "image Looks18=Image18; Mana 250=250; price 1250->1375 (tier)"),
    "木剑": (126, "price 50=50; weight 5=5; dura 4000=4000; level 1=1; image Looks1042=Image1042"),
    "铁剑": (176, "price 1000=1000; weight 10=10; dura 10000=10000; level 7=7; image 1043=1043"),
    "青铜剑": (439, "price 500=500; weight 9=9; dura 8000=8000; level 5=5; image 1043=1043"),
    "布衣（男）": (127, "price 500=500; weight 5=5; dura 5000=5000; level 1=1; Looks940<->Image941"),
    "布衣（女）": (128, "price 500=500; weight 5=5; dura 5000=5000; level 1=1; Looks950<->Image951"),
    "金刚石": (544, "price 2500=2500; weight 4=4; dura 10000=10000; image 219=219"),
    "黑铁": (541, "price 1000=1000; weight 4=4; dura 10000=10000; image 214=214"),
    "井中月": (547, "price 28000=28000; weight 54=54; dura 26000=26000; level 35=35; image 1068=1068"),
    "太阳水": (153, "image Looks20=Image20; price 500=500; Health 70=70; Mana 110=110"),
    "强效太阳水": (154, "image Looks21=Image21; Health/Mana recovery match Rejuvenation Potion (II)"),
    "裁决之杖": (549, "price 40000=40000; weight 90=90; image Looks1069=Image1069"),
    "屠龙": (819, "price 80000=80000; weight 100=100; image Looks1070=Image1070"),
    "破山剑": (683, "price 100000=100000; dur 35000=35000; image Looks1041=Image1041"),
    "骨玉权杖": (550, "price 40000=40000; weight 15=15; image Looks1084=Image1084"),
}

# 秘籍 suffix used by StdMode 4 records
MISHU_RE = re.compile(r"（秘籍）$")


# --------------------------------------------------------------------------
# loading
# --------------------------------------------------------------------------
def load_json(path: Path):
    return json.loads(path.read_text(encoding="utf-8"))


def load_skill_map() -> dict[str, tuple[int, str]]:
    """Extract the reviewed SKILL_MAP from build_comparison.py (start point)."""
    src = COMPARISON_PY.read_text(encoding="utf-8")
    start = src.index("SKILL_MAP = {")
    end = src.index("# 老版物品名")
    block = src[start:end]
    ns: dict = {}
    exec(block, ns)  # noqa: S102 - trusted local research script, read-only
    return ns["SKILL_MAP"]


def load_zircon(snapshot: Path):
    items = load_json(snapshot / "ItemInfo.json")["rows"]
    return items


# --------------------------------------------------------------------------
# candidate scoring
# --------------------------------------------------------------------------
def stats_map(item: dict) -> dict[str, int]:
    return {s["Stat"]: s["Value"] for s in item.get("Stats", []) or []}


def anchors(mud: dict, zir: dict) -> list[str]:
    a: list[str] = []
    if mud["Looks"] and zir["Image"] == mud["Looks"]:
        a.append("image")
    if mud["Price"] and zir["Price"] == mud["Price"]:
        a.append("price")
    if mud["Weight"] and zir["Weight"] == mud["Weight"]:
        a.append("weight")
    if mud["DuraMax"] > 1 and zir["Durability"] == mud["DuraMax"]:
        a.append("dura")
    if mud["NeedLevel"] > 0 and zir["RequiredAmount"] == mud["NeedLevel"]:
        a.append("level")
    if mud["StdMode"] == 0:  # potions reuse AC/MAC fields for recovery
        st = stats_map(zir)
        if mud["ACMin"] and st.get("Health") == mud["ACMin"]:
            a.append("hp")
        if mud["MACMin"] and st.get("Mana") == mud["MACMin"]:
            a.append("mp")
    return a


def score_of(a: list[str]) -> int:
    return sum(WEIGHTS[x] for x in a)


def describe_anchors(mud: dict, zir: dict, a: list[str]) -> str:
    parts = []
    for x in a:
        if x == "image":
            parts.append(f"image {mud['Looks']}={zir['Image']}")
        elif x == "price":
            parts.append(f"price {mud['Price']}={zir['Price']}")
        elif x == "weight":
            parts.append(f"weight {mud['Weight']}={zir['Weight']}")
        elif x == "dura":
            parts.append(f"dura {mud['DuraMax']}={zir['Durability']}")
        elif x == "level":
            parts.append(f"level {mud['NeedLevel']}={zir['RequiredAmount']}")
        elif x == "hp":
            parts.append(f"HP {mud['ACMin']}={stats_map(zir).get('Health')}")
        elif x == "mp":
            parts.append(f"MP {mud['MACMin']}={stats_map(zir).get('Mana')}")
    return "; ".join(parts)


class Matcher:
    def __init__(self, mud3: list[dict], zircon: list[dict]):
        self.mud3 = mud3
        self.zircon = zircon
        self.by_type: dict[str, list[dict]] = defaultdict(list)
        for c in zircon:
            self.by_type[c["ItemType"]].append(c)
        self.mpool = self._pool()
        self.zpool = self._pool()
        self._cand_cache: dict[int, list] = {}
        # appearance uniqueness (Looks<->Image unambiguous on both sides)
        self.looks_mud: Counter = Counter(r["Looks"] for r in mud3 if r["Looks"])
        self.image_zir: Counter = Counter(c["Image"] for c in zircon if c["Image"])

    def _pool(self):
        return {r["Index"]: r for r in self.mud3}, {c["Index"]: c for c in self.zircon}

    def plausible(self, mud: dict, zir: dict, a: list[str]) -> bool:
        sc = score_of(a)
        if sc >= PENDING_MIN_SCORE:
            return True
        if (
            "image" in a
            and self.looks_mud[mud["Looks"]] == 1
            and self.image_zir[zir["Image"]] == 1
        ):
            return True
        return False

    def candidates(self, mud: dict) -> list[tuple[int, list[str], dict]]:
        """All plausible Zircon items for this Mud3 row (ranked)."""
        if mud["Index"] in self._cand_cache:
            return self._cand_cache[mud["Index"]]
        allow = STDMODE_TYPES.get(mud["StdMode"])
        if allow is None:
            pool = self.zircon
        else:
            pool = [c for t in allow for c in self.by_type.get(t, [])]
        out = []
        for c in pool:
            a = anchors(mud, c)
            if self.plausible(mud, c, a):
                out.append((score_of(a), a, c))
        out.sort(key=lambda x: (-x[0], x[2]["Index"]))
        self._cand_cache[mud["Index"]] = out
        return out


# --------------------------------------------------------------------------
# build
# --------------------------------------------------------------------------
def build(mud3: list[dict], zircon: list[dict], skill_map: dict, skill_names: dict):
    m = Matcher(mud3, zircon)
    zmud = {r["Index"]: r for r in mud3}
    zitr = {c["Index"]: c for c in zircon}

    # reverse candidate index (for mutual-unique determination)
    rcand: dict[int, list] = defaultdict(list)
    for r in mud3:
        for sc, a, c in m.candidates(r):
            rcand[c["Index"]].append((sc, a, r))

    entries: list[dict] = []
    used_mud: set[int] = set()
    used_zir: set[int] = set()
    assigned: dict[int, dict] = {}  # mud3 index -> entry (closed/pending)

    def entry(r, conf, zi, en, evidence):
        return {
            "mud3_index": r["Index"],
            "mud3_name": r["Name"],
            "kind": "item",
            "zircon_index": zi,
            "zircon_en": en,
            "confidence": conf,
            "evidence": evidence,
        }

    # 1) manual anchors (verified) -----------------------------------------
    by_name: dict[str, list[dict]] = defaultdict(list)
    for r in mud3:
        by_name[r["Name"]].append(r)
    for name, (zi, note) in MANUAL_ANCHORS.items():
        recs = [r for r in by_name.get(name, []) if r["Index"] not in used_mud]
        if not recs or zi not in zitr:
            continue
        # deterministic: lowest Mud3 index among duplicate names
        r = sorted(recs, key=lambda x: x["Index"])[0]
        if r["Index"] in used_mud or zi in used_zir:
            continue
        e = entry(r, "closed", zi, zitr[zi]["_Identity"], f"manual anchor (verified): {note}")
        entries.append(e)
        assigned[r["Index"]] = e
        used_mud.add(r["Index"])
        used_zir.add(zi)

    # 2) skill books (StdMode 51) via reviewed SKILL_MAP --------------------
    #    Each Mud3 book is handled here (closed / pending / missing) and thus
    #    never falls through to a generic book-by-image pairing.
    book_by_name: dict[str, list[dict]] = defaultdict(list)
    for c in zircon:
        if c["ItemType"] == "Book":
            book_by_name[c["_Identity"]].append(c)
    for r in mud3:
        if r["StdMode"] != 51 or r["Index"] in used_mud:
            continue
        base = MISHU_RE.sub("", r["Name"])
        info = skill_map.get(base)
        target = skill_names.get(info[0]) if info else None
        cands = book_by_name.get(target, []) if target else []
        if info and len(cands) == 1:
            c = cands[0]
            a = anchors(r, c)
            level_ok = r["DuraMax"] > 1 and c["RequiredAmount"] == r["DuraMax"]
            ev = (
                f"skill book: SKILL_MAP '{base}'->skill#{info[0]} '{target}'; "
                f"price {r['Price']}={c['Price']}; level(DuraMax {r['DuraMax']}="
                f"RequiredAmount {c['RequiredAmount']})"
            )
            if "price" in a and level_ok and c["Index"] not in used_zir:
                e = entry(r, "closed", c["Index"], c["_Identity"], ev)
                used_zir.add(c["Index"])
            else:
                e = entry(
                    r, "pending", c["Index"], c["_Identity"],
                    f"PROPOSED, human confirmation required; {ev}; "
                    "price/level anchor differs from the current Zircon book",
                )
                if c["Index"] in used_zir:
                    e = entry(
                        r, "missing", None, None,
                        f"skill book '{base}': mapped Zircon book #{c['Index']} "
                        f"{c['_Identity']} already used",
                    )
                else:
                    used_zir.add(c["Index"])
            entries.append(e)
            assigned[r["Index"]] = e
        else:
            entries.append(entry(
                r, "missing", None, None,
                f"skill book '{base}': no SKILL_MAP entry / no matching Zircon book",
            ))
        used_mud.add(r["Index"])

    # 3) auto 1:1 (mutual-unique top, strong) -------------------------------
    for r in mud3:
        if r["Index"] in used_mud:
            continue
        cl = m.candidates(r)
        if not cl:
            continue
        top = cl[0][0]
        if sum(1 for sc, _, _ in cl if sc == top) != 1:
            continue
        c = cl[0][2]
        a = cl[0][1]
        unique_img = (
            "image" in a
            and m.looks_mud[r["Looks"]] == 1
            and m.image_zir[c["Image"]] == 1
            and not c["_Identity"].startswith("!")  # deprecated placeholder
        )
        if top < CLOSED_MIN_SCORE and not unique_img:
            continue
        if c["Index"] in used_zir:
            continue
        rl = sorted(rcand[c["Index"]], key=lambda x: (-x[0], x[2]["Index"]))
        if not rl or rl[0][2]["Index"] != r["Index"]:
            continue
        if sum(1 for sc, _, _ in rl if sc == rl[0][0]) != 1:
            continue
        e = entry(
            r, "closed", c["Index"], c["_Identity"],
            f"1:1 mutual-unique; {describe_anchors(r, c, cl[0][1])}",
        )
        entries.append(e)
        assigned[r["Index"]] = e
        used_mud.add(r["Index"])
        used_zir.add(c["Index"])

    # 4) advanced manuals (StdMode 4) -- targeted through SKILL_MAP.  Zircon
    #    keeps a single book per spell, already closed to the StdMode 51 book,
    #    so the 秘籍 has no distinct Zircon counterpart -> `missing`.
    for r in mud3:
        if r["Index"] in used_mud or r["StdMode"] != 4:
            continue
        base = MISHU_RE.sub("", r["Name"])
        info = skill_map.get(base)
        tgt = skill_names.get(info[0]) if info else None
        bc = book_by_name.get(tgt, []) if tgt else []
        if info and len(bc) == 1:
            c = bc[0]
            ev = (
                f"advanced manual 秘籍: SKILL_MAP '{base}'->skill#{info[0]} '{tgt}'; "
                f"Zircon keeps one book per spell (already closed to the StdMode 51 "
                f"sibling as #{c['Index']} {c['_Identity']}) -- Mud3-only variant"
            )
        else:
            ev = "advanced manual 秘籍: no SKILL_MAP entry / no matching Zircon book"
        entries.append(entry(r, "missing", None, None, ev))
        used_mud.add(r["Index"])

    # 5) pending + missing -- deterministic global greedy best-match.  Exactly
    #    one entry per Mud3 record; the proposed index is NEVER treated as a
    #    closed identity and the alternatives are listed in evidence.  If no
    #    candidate is left free (one-to-many variant) the record is `missing`
    #    with the consumed candidates named.
    edges = []
    for r in mud3:
        if r["Index"] in used_mud:
            continue
        if MISHU_RE.search(r["Name"]):
            continue  # equipment-enchant manual variant -> missing below
        for sc, a, c in m.candidates(r):
            if c["Index"] in used_zir:
                continue
            edges.append((-sc, r["Index"], c["Index"], a))
    edges.sort()
    for neg, mi, zi, a in edges:
        if mi in used_mud or zi in used_zir:
            continue
        r, c = zmud[mi], zitr[zi]
        alts = [x for x in m.candidates(r) if x[2]["Index"] != zi]
        alts_txt = "; ".join(
            f"#{x[2]['Index']} {x[2]['_Identity']} [{describe_anchors(r, x[2], x[1])}]"
            for x in alts[:4]
        )
        ev = (
            f"PROPOSED, human confirmation required (never auto-closed); "
            f"anchors: {describe_anchors(r, c, a)}"
        )
        if alts_txt:
            ev += f"; alternatives: {alts_txt}"
        entries.append(entry(r, "pending", zi, c["_Identity"], ev))
        used_mud.add(mi)
        used_zir.add(zi)

    for r in mud3:
        if r["Index"] in used_mud:
            continue
        cl = m.candidates(r)
        if MISHU_RE.search(r["Name"]):
            ev = "equipment-enchant manual variant (秘籍); Zircon implements this via item affixes, no 1:1 item"
        elif cl:
            alts = "; ".join(
                f"#{c['Index']} {c['_Identity']}" for _, _, c in cl[:4]
            )
            ev = f"no free Zircon candidate (all plausible candidates consumed): {alts}"
        else:
            ev = "no Zircon counterpart under anchors (price/weight/dura/level/image)"
        entries.append(entry(r, "missing", None, None, ev))
        used_mud.add(r["Index"])

    # 6) zircon-only --------------------------------------------------------
    for c in zircon:
        if c["Index"] in used_zir:
            continue
        entries.append({
            "mud3_index": None,
            "mud3_name": None,
            "kind": "item",
            "zircon_index": c["Index"],
            "zircon_en": c["_Identity"],
            "confidence": "zircon-only",
            "evidence": "no Mud3 EI2.0 counterpart (late LOMCN / private-server addition)",
        })

    return entries


# --------------------------------------------------------------------------
# rendering
# --------------------------------------------------------------------------
ORDER = ["closed", "pending", "missing", "zircon-only"]


def render_json(entries: list[dict], sources: list[str]) -> str:
    ordered = sorted(
        entries,
        key=lambda e: (
            ORDER.index(e["confidence"]),
            e["mud3_index"] if e["mud3_index"] is not None else 10**9,
            e["zircon_index"] if e["zircon_index"] is not None else 10**9,
        ),
    )
    doc = {
        "kind": "item",
        "generated_at": "2026-10-03",
        "sources": sources,
        "entries": ordered,
    }
    return json.dumps(doc, ensure_ascii=False, indent=2)


def render_md(entries: list[dict]) -> str:
    counts = Counter(e["confidence"] for e in entries)
    lines: list[str] = []
    lines.append("# Mud3 ↔ Zircon 物品身份表（item identity）\n")
    lines.append("> 由 `build_item_identity.py` 只读生成，禁止手改。")
    lines.append("> Zircon 快照来自 `SystemDbProbe --json`（当前库 1078 物品）；")
    lines.append("> 老版来自 `stditem.json`（1143 记录）。\n")

    lines.append("## 计数\n")
    rows = len(entries)
    distinct_mud3 = len({e["mud3_index"] for e in entries if e["mud3_index"] is not None})
    distinct_zir = len({e["zircon_index"] for e in entries if e["zircon_index"] is not None})
    lines.append("| confidence | 行数 |")
    lines.append("|---|---:|")
    for k in ORDER:
        lines.append(f"| {k} | {counts.get(k, 0)} |")
    lines.append(f"| **total rows** | {rows} |")
    lines.append("")
    lines.append(f"- distinct Mud3 indices covered (closed/pending/missing): **{distinct_mud3}** / 1143")
    lines.append(f"- distinct Zircon indices covered (closed/pending/zircon-only): **{distinct_zir}** / 1078")
    lines.append("- `closed` rows are 1:1 (no duplicated zircon_index).")
    lines.append("")

    lines.append(
        "> **pending 语义**：每条 Mud3 记录只给**一个候选** `zircon_index`，"
        "它是人工复核的**提议**，**不是已确认身份**；evidence 里列出其它备选候选"
        "（`alternatives:`）。多候选时**不会**标记为 `closed`。下游工具"
        "（`db_names.json` 重写、掉落迁移）**不得**消费 pending 行。\n"
    )

    titles = {
        "closed": "closed — 1:1 已闭合",
        "pending": "pending — 候选，待人工确认",
        "missing": "missing — Mud3 有、Zircon 无",
        "zircon-only": "zircon-only — Zircon 有、Mud3 无",
    }
    for conf in ORDER:
        rows = [e for e in entries if e["confidence"] == conf]
        rows.sort(key=lambda e: (e["mud3_index"] if e["mud3_index"] is not None else 10**9,
                                 e["zircon_index"] if e["zircon_index"] is not None else 10**9))
        lines.append(f"## {titles[conf]}（{len(rows)}）\n")
        lines.append("| mud3_index | mud3_name | → zircon_index | zircon_en | evidence |")
        lines.append("|---:|---|---:|---|---|")
        for e in rows:
            mi = e["mud3_index"] if e["mud3_index"] is not None else ""
            mn = (e["mud3_name"] or "").replace("|", "\\|")
            zi = e["zircon_index"] if e["zircon_index"] is not None else ""
            ze = (e["zircon_en"] or "").replace("|", "\\|")
            ev = e["evidence"].replace("|", "\\|")
            lines.append(f"| {mi} | {mn} | {zi} | {ze} | {ev} |")
        lines.append("")
    return "\n".join(lines)


# --------------------------------------------------------------------------
# self-check
# --------------------------------------------------------------------------
def self_check(entries: list[dict], n_mud3: int, n_zircon: int):
    c = Counter(e["confidence"] for e in entries)
    closed = [e for e in entries if e["confidence"] == "closed"]
    dup = [k for k, v in Counter(e["zircon_index"] for e in closed).items() if v > 1]
    pair_zir = [
        e["zircon_index"] for e in entries if e["confidence"] in ("closed", "pending")
    ]
    dup_pair = [k for k, v in Counter(pair_zir).items() if v > 1]
    mud3_distinct = {
        e["mud3_index"] for e in entries
        if e["mud3_index"] is not None and e["confidence"] in ("closed", "pending", "missing")
    }
    zir_distinct = {
        e["zircon_index"] for e in entries if e["zircon_index"] is not None
    }
    checks = {
        "closed+pending+missing == mud3 (rows)": c["closed"] + c["pending"] + c["missing"] == n_mud3,
        "closed+pending+zircon-only == zircon (rows)": c["closed"] + c["pending"] + c["zircon-only"] == n_zircon,
        "no duplicate zircon among closed": not dup,
        "no duplicate zircon among closed+pending": not dup_pair,
        "distinct mud3 covered == mud3": len(mud3_distinct) == n_mud3,
        "distinct zircon covered == zircon": len(zir_distinct) == n_zircon,
        "manual anchors present": {"金币", "木剑", "铁剑", "布衣（男）"} <= {
            e["mud3_name"] for e in closed
        },
    }
    return checks, c


def main():
    ap = argparse.ArgumentParser(description="build Mud3<->Zircon item identity table")
    ap.add_argument("--mud3-item", type=Path, default=DEFAULT_MUD3_ITEM)
    ap.add_argument("--zircon-snapshot", type=Path, default=DEFAULT_ZIRCON_SNAPSHOT)
    ap.add_argument("--out-dir", type=Path, default=DEFAULT_OUT_DIR)
    args = ap.parse_args()

    stditem = load_json(args.mud3_item)
    mud3 = stditem["records"]
    zircon = load_zircon(args.zircon_snapshot)
    skill_map = load_skill_map()
    skill_names = {s["id"]: s["name"] for s in load_json(SKILLS_ZIRCON)}

    entries = build(mud3, zircon, skill_map, skill_names)

    sources = [
        str(args.mud3_item),
        str(args.zircon_snapshot / "ItemInfo.json"),
        str(COMPARISON_PY) + " (SKILL_MAP seed)",
        str(SKILLS_ZIRCON),
    ]
    args.out_dir.mkdir(parents=True, exist_ok=True)
    (args.out_dir / "items.json").write_text(render_json(entries, sources), encoding="utf-8")
    (args.out_dir / "items.md").write_text(render_md(entries), encoding="utf-8")

    checks, counts = self_check(entries, len(mud3), len(zircon))
    print("counts per confidence (rows):")
    for k in ORDER:
        print(f"  {k:12s} {counts.get(k, 0)}")
    mud3_distinct = len({e["mud3_index"] for e in entries if e["mud3_index"] is not None})
    zir_distinct = len({e["zircon_index"] for e in entries if e["zircon_index"] is not None})
    print(f"  total rows   {len(entries)}")
    print(f"  distinct mud3={mud3_distinct}  distinct zircon={zir_distinct}")
    print("self-check:")
    for k, v in checks.items():
        print(f"  [{'PASS' if v else 'FAIL'}] {k}")
    if not all(checks.values()):
        raise SystemExit("coverage self-check failed")


if __name__ == "__main__":
    main()
