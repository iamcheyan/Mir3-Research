#!/usr/bin/env python3
"""生成 magics.json / magics.md：Mud3 EI2.0 magic.dat（105）↔ Zircon System.db MagicInfo（174）
的一对一身份表。

只读：不写 System.db、不写 db_names.json、不改任何 Zircon 源文件；只在本目录产出。

规则（见本目录 README.md 与
Zircon/docs/pending/MUD3_CONTENT_AND_LEGACY_BAG_HANDOFF_2026-10-03.md §1.4）：

- closed     ：1:1 且有主证据。主证据 = NeedLevel1/2/3 三元组完全一致（本任务对技能的首选锚点）。
- pending    ：三元组/位置可对应，但**语义身份不确定**，或一对多无法唯一定位；禁止当 closed。
- missing    ：Mud3 有、Zircon 当前库无。
- zircon-only：Zircon 有、Mud3 无（含刺客整棵树、后期强化技能）。

自检（硬性）：
  closed + pending + missing  == Mud3 记录数 (105)
  closed + pending + zircon-only == Zircon 行数 (174)
  closed 行内 zircon_index 无重复（1:1）

用法：
  python3 build_magic_identity.py
"""
from __future__ import annotations

import json
from datetime import date
from pathlib import Path

D = Path(__file__).resolve().parent

MUD3_MAGIC = Path("/home/tetsuya/development/Mir3-Research/docs/research/mud3-dat-decoded/magic.json")
ZIRCON_MAGIC = Path("/tmp/sysdb_probe.json/MagicInfo.json")
REGEN_CMD = (
    "cd /home/tetsuya/development/Mir3-Research/Tools/SystemDbProbe && "
    "./bin/Debug/net10.0/SystemDbProbe "
    "/home/tetsuya/development/Zircon/Debug/ServerCore/Database --json /tmp/sysdb_probe.json"
)

SOURCES = [
    str(MUD3_MAGIC) + " (records[].Name = GBK 官方中文名)",
    str(ZIRCON_MAGIC) + " (SystemDbProbe --json, 当前双库快照)",
    "Mir3-Research/docs/research/mud3-dat-decoded/build_comparison.py (SKILL_MAP 起点)",
    "Mir3-Research/docs/terminology/02-技能.md (仅作候选语境，非主证据)",
]

# ---------------------------------------------------------------------------
# closed：Mud3 官方中文名 -> Zircon Index。
# 全部满足 NeedLevel1/2/3 三元组与 Zircon 完全一致（见 verify_closed()）。note 为补充说明。
# 已剔除 4 条语义待定（诱惑之光/圣言术/异形换位/阴阳法环），它们进入 PENDING。
# ---------------------------------------------------------------------------
CLOSED: dict[str, tuple[int, str]] = {
    # 战士系（sch7）
    "基本剑术": (1, ""),
    "攻杀剑术": (3, ""),
    "刺杀剑术": (4, ""),
    "半月弯刀": (5, ""),
    "野蛮冲撞": (6, ""),
    "空拳刀法": (70, "Mud3 归战技系，Zircon 归道士 Combat Kick；跨职业重归类，三元组仍一致"),
    "烈火剑法": (7, ""),
    "翔空剑法": (8, "Zircon 英文 Dragon Rise 旧显示名误作龙影剑法，官方名为翔空剑法"),
    "莲月剑法": (9, ""),
    "十方斩": (10, "Zircon 英文 Destructive Surge 旧显示名误作破血狂杀，官方名为十方斩"),
    "乾坤大挪移": (11, ""),
    "铁布衫": (12, ""),
    "斗转星移": (13, "Zircon 英文 Beckon 旧显示名误作召唤，官方名为斗转星移"),
    "破血狂杀": (14, "Zircon 英文 Might 旧显示名误作蛮力，官方名为破血狂杀"),
    "精神力战法": (60, "Mud3 归战技系，Zircon 归道士 Spirit Sword；跨职业重归类，三元组仍一致"),
    # 法师系（sch0/1/2/3）
    "火球术": (23, ""),
    "霹雳掌": (24, ""),
    "冰月神掌": (25, ""),
    "风掌": (26, ""),
    "抗拒火环": (27, ""),
    "瞬息移动": (29, ""),
    "大火球": (30, "Zircon 英文 Adamantine Fire Ball 旧显示名误作金刚火球，官方名为大火球"),
    "雷电术": (31, ""),
    "冰月震天": (32, ""),
    "击风": (33, ""),
    "地狱火": (34, ""),
    "疾光电影": (35, ""),
    "冰沙掌": (36, ""),
    "风震天": (37, ""),
    "火墙": (38, ""),
    "魔法盾": (41, ""),
    "爆裂火焰": (42, ""),
    "地狱雷光": (43, ""),
    "冰咆哮": (44, ""),
    "龙卷风": (45, ""),
    "魄冰刺": (46, ""),
    "怒神霹雳": (47, ""),
    "焰天火雨": (48, ""),
    # 道士系（sch4/5）
    "治愈术": (59, ""),
    "施毒术": (61, ""),
    "灵魂火符": (62, ""),
    "月魂断玉": (63, ""),
    "隐身术": (64, ""),
    "幽灵盾": (65, ""),
    "集体隐身术": (66, ""),
    "月魂灵波": (67, ""),
    "神圣战甲术": (68, ""),
    "困魔咒": (69, ""),
    "强魔震法": (71, ""),
    "群体治愈术": (72, ""),
    "猛虎强势": (73, ""),
    "回生术": (74, ""),
    "云寂术": (75, ""),
    "妙影无踪": (76, ""),
    # 召唤系（sch6）
    "召唤骷髅": (130, ""),
    "召唤神兽": (133, ""),
    "超强召唤骷髅": (132, ""),
}

# ---------------------------------------------------------------------------
# pending：语义待定 / 位置可对但身份不确定。candidate 为三元组/位置候选，仅作人工勾选。
# ---------------------------------------------------------------------------
PENDING: dict[str, tuple[int | None, str]] = {
    "诱惑之光": (
        28,
        "三元组 13/15/17 与 Electric Shock(28) 一致，但语义不确定（Mud3 诱惑之光疑为魅惑系，"
        "Zircon Electric Shock 为闪电麻痹）；同一三元组另有 Explosive Talisman(62)",
    ),
    "圣言术": (
        39,
        "三元组 26/28/30 与 Expel Undead(39) 一致，但语义不确定（超度亡灵 vs 圣言术）；"
        "Zircon 侧另有译名亦作「圣言术」的 Celestial Light(77)",
    ),
    "异形换位": (
        40,
        "三元组 27/29/31 与 Geo Manipulation(40) 一致，但语义不确定（缩地术 vs 异形换位）",
    ),
    "阴阳法环": (
        49,
        "三元组 46/48/50 与 Renounce(49) 一致，但语义不确定（迷魂咒 vs 阴阳法环）；"
        "同一三元组另有 Celestial Light(77)",
    ),
    "凝血离魂": (
        77,
        "三元组 46/48/50 与 Celestial Light(77) 一致；该三元组 Mud3 两条 vs Zircon 两条，"
        "无法唯一定位（另一条为阴阳法环），语义亦不确定",
    ),
    "移花接玉": (
        18,
        "无三元组锚点（Mud3 38/41/44 vs Zircon 53/58/63）；Zircon Reflect Damage(18) 的既定中文译名"
        "为移花接玉且同为道士系，但仅有术语证据、非主证据，故 pending",
    ),
}

CONF_ORDER = ["closed", "pending", "missing", "zircon-only"]


def load() -> tuple[dict, dict]:
    if not ZIRCON_MAGIC.exists():
        raise SystemExit(
            f"缺少 Zircon 快照 {ZIRCON_MAGIC}\n请先生成：\n  {REGEN_CMD}"
        )
    mud3 = json.loads(MUD3_MAGIC.read_text(encoding="utf-8"))
    zircon = json.loads(ZIRCON_MAGIC.read_text(encoding="utf-8"))
    return mud3, zircon


def nl(r) -> str:
    return f"{r['NeedLevel1']}/{r['NeedLevel2']}/{r['NeedLevel3']}"


def is_equipment_variant(name: str, school: int) -> bool:
    if school != 99:
        return False
    for k in ("聚集", "连锁", "通天", "分散", "幽灵盾", "强魔震法", "魔防系术", "防御系术"):
        if k in name:
            return True
    return False


def build_entries(mud3: dict, zircon: dict) -> list[dict]:
    zrows = {r["Index"]: r for r in zircon["rows"]}
    mrows = mud3["records"]

    # --- closed 校验：三元组必须与 Zircon 完全一致 ---
    problems = []
    for name, (zi, _note) in CLOSED.items():
        mr = next((r for r in mrows if r["Name"] == name), None)
        if mr is None:
            problems.append(f"closed 名称在 Mud3 找不到：{name}")
            continue
        if zi not in zrows:
            problems.append(f"closed 目标 Index 不存在：{name}->{zi}")
            continue
        if nl(mr) != nl(zrows[zi]):
            problems.append(f"closed 三元组不一致：{name} {nl(mr)} vs {zrows[zi]['_Identity']}({zi}) {nl(zrows[zi])}")
    if problems:
        raise SystemExit("closed 校验失败：\n  " + "\n  ".join(problems))

    used_zircon: dict[int, str] = {}
    entries: list[dict] = []

    for mr in mrows:
        name = mr["Name"]
        zi = None
        conf = "missing"
        evidence = ""
        if name in CLOSED:
            zi, note = CLOSED[name]
            conf = "closed"
            zr = zrows[zi]
            evidence = (
                f"NeedLevel 三元组 {nl(mr)} 与 Zircon {zr['_Identity']}({zi}) 完全一致；"
                f"Mud3 sch{mr['MagicSchool']} → Zircon {zr['RequiredClass']}/{zr['School']}"
            )
            if note:
                evidence += "；" + note
        elif name in PENDING:
            zi, evidence = PENDING[name]
            conf = "pending"
        else:
            if is_equipment_variant(name, mr["MagicSchool"]):
                evidence = (
                    "装备附魔变体（MagicSchool=99，聚集/连锁/通天/分散/属性盾系）；"
                    "Zircon 以装备词缀实现，无 1:1 技能"
                )
            elif mr["MagicSchool"] == 99:
                evidence = "MagicSchool=99 特殊/未开放条目；Zircon 当前库无对应技能"
            else:
                evidence = "Mud3 独有，Zircon 当前库无对应技能"
        if zi is not None:
            used_zircon[zi] = conf
        zr = zrows.get(zi) if zi is not None else None
        entries.append(
            {
                "mud3_index": mr["Index"],
                "mud3_name": name,
                "kind": "magic",
                "zircon_index": zi,
                "zircon_en": zr["_Identity"] if zr else None,
                "confidence": conf,
                "evidence": evidence,
            }
        )

    # --- zircon-only ---
    for zr in zircon["rows"]:
        if zr["Index"] in used_zircon:
            continue
        note = ""
        if zr["RequiredClass"] == "Assa":
            note = "刺客技能树（传奇3 后期内容，Mud3 EI2.0 无）"
        elif zr["Index"] == 136:
            note = "占位条目 _Blank_（未使用）"
        else:
            note = "Zircon 后期/强化技能，Mud3 DAT 无"
        entries.append(
            {
                "mud3_index": None,
                "mud3_name": None,
                "kind": "magic",
                "zircon_index": zr["Index"],
                "zircon_en": zr["_Identity"],
                "confidence": "zircon-only",
                "evidence": f"{zr['RequiredClass']}/{zr['School']}；{note}",
            }
        )

    entries.sort(key=lambda e: (CONF_ORDER.index(e["confidence"]),
                                e["mud3_index"] if e["mud3_index"] is not None else 10**9,
                                e["zircon_index"] if e["zircon_index"] is not None else 10**9))
    return entries


def self_check(entries: list[dict], n_mud3: int, n_zircon: int) -> dict:
    from collections import Counter
    c = Counter(e["confidence"] for e in entries)
    closed_z = [e["zircon_index"] for e in entries if e["confidence"] == "closed"]
    dup = [i for i, k in Counter(closed_z).items() if k > 1]
    assert not dup, f"closed zircon_index 重复：{dup}"
    assert c["closed"] + c["pending"] + c["missing"] == n_mud3, "Mud3 覆盖自检失败"
    assert c["closed"] + c["pending"] + c["zircon-only"] == n_zircon, "Zircon 覆盖自检失败"
    return c


def write_json(entries: list[dict]) -> None:
    doc = {
        "kind": "magic",
        "generated_at": date.today().isoformat(),
        "sources": SOURCES,
        "entries": entries,
    }
    (D / "magics.json").write_text(json.dumps(doc, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")


def write_md(entries: list[dict], counts) -> None:
    out: list[str] = []
    w = out.append
    w("# Mud3 ↔ Zircon 魔法/技能身份表（magic）\n")
    w("> 只读产出，不改 `System.db` / `db_names.json` / Zircon C#。")
    w("> 权威契约见本目录 `README.md` 与 `Zircon/docs/pending/MUD3_CONTENT_AND_LEGACY_BAG_HANDOFF_2026-10-03.md` §1.4。")
    w(f"> 生成：`build_magic_identity.py`（{date.today().isoformat()}）。Mud3 {sum(counts.values()) - counts['zircon-only']} 条 / Zircon 174 行。\n")
    w("## 数量（按 confidence）\n")
    w("| confidence | 数量 |")
    w("|---|---:|")
    for k in CONF_ORDER:
        w(f"| {k} | {counts[k]} |")
    w("")
    w("自检：`closed+pending+missing == 105`，`closed+pending+zircon-only == 174`，`closed` 无重复 `zircon_index`。\n")
    heads = {
        "closed": "## closed（1:1，主证据闭合）",
        "pending": "## pending（语义待定，人工勾选；禁止当 closed）",
        "missing": "## missing（Mud3 有、Zircon 无）",
        "zircon-only": "## zircon-only（Zircon 有、Mud3 无）",
    }
    for k in CONF_ORDER:
        rows = [e for e in entries if e["confidence"] == k]
        w(heads[k] + "\n")
        w("| Mud3 Index | Mud3 中文名 | Zircon Index | Zircon 身份 | 证据 |")
        w("|---|---|---:|---|---|")
        for e in rows:
            w(
                f"| {e['mud3_index'] if e['mud3_index'] is not None else '—'} "
                f"| {e['mud3_name'] or '—'} "
                f"| {e['zircon_index'] if e['zircon_index'] is not None else '—'} "
                f"| {e['zircon_en'] or '—'} "
                f"| {e['evidence']} |"
            )
        w("")
    (D / "magics.md").write_text("\n".join(out), encoding="utf-8")


def main() -> None:
    mud3, zircon = load()
    entries = build_entries(mud3, zircon)
    counts = self_check(entries, len(mud3["records"]), len(zircon["rows"]))
    write_json(entries)
    write_md(entries, counts)
    print("mud3-identity/magics.json / magics.md 已生成")
    for k in CONF_ORDER:
        print(f"  {k:<12} {counts[k]}")
    print(f"  Mud3 合计   {counts['closed'] + counts['pending'] + counts['missing']}")
    print(f"  Zircon 合计 {counts['closed'] + counts['pending'] + counts['zircon-only']}")


if __name__ == "__main__":
    main()
