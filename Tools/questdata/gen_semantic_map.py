#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""gen_semantic_map.py —— 中文名 ↔ System.db 语义映射表生成器（D1）。

输入（全部只读）：
  - Tools/dbeditor/workspace/{ItemInfo,MonsterInfo,MagicInfo,NPCInfo,MapInfo,MapRegion}.json
    （dbeditor 基线导出：1078/434/174/294/627/5009 行）
  - zircon/GodotClient/translations/db_names.json（英文名→中文名，items/monsters/npcs/magics/maps）
  - docs/quest-design/data/item_catalog.json（1078 物品中文名+类型，物品 zh 权威）
  - docs/quest-design/{02,03,04,05,07,11,12}*.md（设计文档，扫描用词 → orphans/缺口清单）
  - docs/NAMING_RULES_2026-08-13.md（光通译名基准 → 别名表依据）

输出：
  - docs/quest-design/data/semantic_map.json
  - docs/quest-design/data/semantic_map_report.md（覆盖率 / 冲突 / orphans / 抽查）

词条结构（每词条必带 confidence）：
  {"Index": 42, "Name": "Flaming Sword", "zh": "烈火剑法", "type": "Book",
   "confidence": 1.0, "source": "db_names|item_catalog|alias|direct",
   "candidates": [...]   # confidence<1 时列出全部候选
   "aliases": [...]      # 指向本词条的其他叫法
  }
置信度：exact 唯一命中=1.0；多候选=0.5（列候选）；未命中=0（进 orphans）。

运行：/home/tetsuya/mir3-venv/bin/python Tools/questdata/gen_semantic_map.py
"""
from __future__ import annotations

import json
import re
import sys
from collections import Counter, defaultdict
from pathlib import Path

REPO = Path(__file__).resolve().parent.parent.parent
WS = REPO / "Tools" / "dbeditor" / "workspace"
DB_NAMES = Path("/home/tetsuya/development/zircon/GodotClient/translations/db_names.json")
ITEM_CATALOG = REPO / "docs" / "quest-design" / "data" / "item_catalog.json"
QD = REPO / "docs" / "quest-design"
OUT_JSON = REPO / "docs" / "quest-design" / "data" / "semantic_map.json"
OUT_REPORT = REPO / "docs" / "quest-design" / "data" / "semantic_map_report.md"

DESIGN_DOCS = [
    "02-主线任务详解-三线序章.md",
    "03-主线任务详解-共享主线.md",
    "04-主线任务详解-技能觉醒.md",
    "05-副线任务详解.md",
    "07-任务总表.md",
    "11-多人任务详解.md",
    "12-剧情大纲速览.md",
]

# ---------------------------------------------------------------- 别名表
# 设计文档用光通版叫法，DB 用国际版英文名。以下为已核实的高置信桥接
# （核实依据：RespawnInfo 怪物实际刷新地图 + NAMING_RULES §1.1/1.5/1.6/1.7）。
# 格式：{表: {设计文档叫法: DB 英文名}}。value 为 list 时=多候选(0.5)。
ALIASES: dict[str, dict[str, str | list[str]]] = {
    "monsters": {
        # 沃玛系 = Uma*（实证：Uma King/Uma Flame Thrower 刷新于「沃玛神殿1/2层」）
        "沃玛战士": "Uma Infidel",
        "沃玛卫士": "Uma Infidel",
        "火焰沃玛": "Uma Flame Thrower",
        "沃玛勇士": ["Uma Infidel", "Uma Flame Thrower"],
        "沃玛战将": ["Uma Flame Thrower", "Uma Anguisher"],
        "沃玛教主": "Uma King",
        # 半兽系 = Oma*（Mir2/3 光通 canon：Oma=半兽人；城镇周边低级怪）
        "半兽战士": "Oma Warrior",
        "半兽勇士": ["Oma", "Oma Hero"],
        "半兽人": "Oma",
        # 祖玛系 = Zuma*（Zuma King 刷新于「祖玛教主宫廷」）
        "祖玛弓箭手": "Zuma Sharpshooter",
        "祖玛卫士": "Zuma Guardian",
        "祖玛教主": "Zuma King",
        "祖玛雕像": ["Zuma Fanatic", "Zuma Keeper"],
        # 诺玛系 = Numa*
        "诺玛将士": ["Numa Grunt", "Numa Royal Guard"],
        "诺玛法老": ["Numa Mage", "Numa High Mage"],
        "大法老": "Great Pharaoh",
        # 蚂蚁/虫系
        "蚂蚁战士": "Ant Soldier",
        "山洞蝙蝠": "Cave Bat",
        "洞穴蝙蝠": "Cave Bat",
        "洞蛆": "Cave Maggot",
        "楔蛾": "Wedge Moth",
        "盔甲虫": ["Beetle", "Armoured Ant"],
        "红甲虫": ["Beetle"],
        "钳虫": ["Earwig"],
        "沙漠蜥蜴": ["Saw Tooth Lizard", "Raging Lizard"],
        "沙漠石人": ["Stone Golem", "Fierce Stone Man"],
        "沙漠风魔": ["Fierce Wind Demon"],
        # 骷髅系
        "骷髅士兵": "Bone Soldier",
        "骷髅弓箭手": "Bone Archer",
        "掷斧骷髅": "Skeleton Axe Thrower",
        "骷髅战将": ["Skeleton Warrior", "Skeleton Enforcer"],
        "骷髅精灵": ["Skeleton Lord"],
        "骷髅教主": ["Skeleton Lord"],
        # 僵尸/尸系
        "尸王": ["Fierce Corpse King"],
        # 蜘蛛系
        "毒蜘蛛": "Venom Spider",
        "喷毒蜘蛛": "Spitting Spider",
        "蜘蛛女王": "Arachnid Broodmother",
        # 蛇系
        "虎蛇": "Tiger Snake",
        "红蛇": ["Tiger Snake"],
        "蝎蛇": ["Claw Serpent", "Scorpion"],
        # 野猪/象/猴
        "红野猪": "Red Boar",
        "黑野猪": "Black Boar",
        "白野猪": ["Wild Boar"],
        "赤黄猪王": ["Tusk Lord"],
        "巨象兽": ["Wild Elephant", "Evil Elephant"],
        "猿猴战士": ["Wild Monkey", "Evil Monkey"],
        # 潘夜系 = Banya/Banyo*
        "潘夜牛魔王": ["Emperor Sa'Woo", "Flame Minotaur"],
        # 神舰/异界系 = Otherworld*
        "末日之爪": "Doom Claw",
        # 杂项
        "暗黑战士": ["Evil Spirit Warrior"],
        "守城大将铁盾": ["Sabuk Lord"],
    },
    "maps": {
        # 设计叫法 → DB 地图（Description / 中文描述）
        "比奇城": "Bichon Town",
        "比奇省": "Bichon Town",
        "新手村": "Bichon Town",
        "银杏村": "银杏山谷",
        "失乐园海边": "Lost Paradise",
        "沃玛神殿总殿": ["沃玛神殿", "沃玛神殿3层"],
        "祖玛大殿": ["祖玛神殿大厅", "祖玛神殿"],
        "盟重": "盟重县",
        "天然洞穴": ["天然洞穴1层", "半兽天然洞穴"],
        "石阁庙火池": "石阁庙",
        "赤月山谷": ["赤月山谷1层", "赤月山谷5层"],
        "潘夜神殿大殿": ["潘夜神殿", "潘夜神殿10层"],
        "潘夜神殿七层": ["潘夜神殿7层西部", "潘夜神殿7层东部"],
        "祖玛高塔": ["祖玛神殿4层", "祖玛神殿5层"],
        "真天黑度大殿": ["黑度宫4层"],
        "罪孽洞穴": ["罪孽洞穴1层"],
        "神舰甲板": ["神舰2层", "神舰1层"],
        "比奇城镖局": "Bichon Town",
        "银杏村村口": "银杏山谷",
    },
    "magics": {},   # db_names magics 174/174 全中文覆盖，无需别名
    "npcs": {},     # 设计 NPC 绝大多数是新增（13 号表规划），留给 orphans 清单
    "items": {   # 物品以 item_catalog 1078 zh 为权威；技能书派生键运行时生成
        "铁矿": "Iron Ore", "铜矿": "Copper Ore", "银矿": "Silver Ore",
        "金矿": "Gold Ore", "黑铁矿": "Black Iron Ore",
        "钥匙": ["David's Key", "Haylee's Key", "Kacy's Key"],
        "日记本": ["Gresham's Journal", "Isaac's Journal", "Henry's Journal"],
        "肉块": ["Chicken Meat", "Fresh Meat"],
    },
}

# 设计文档步骤/奖励列的实体抽取模式（D2 复用同一套）
RE_KILL = re.compile(
    r"(?:(?<=\A)|(?<=[\s;；,，。、/|｜:：（(]))杀\s*([^×;；,，)）(（\s]+?)\s*[×x]\s*(\d+)")
RE_GAIN = re.compile(r"GainItem\s*([^×;；,，)）(（\s]+)(?:\s*[×x]\s*(\d+))?")
RE_VISIT = re.compile(r"VisitRegion\s*([^;；,，)）(（\s。]+)")


def load_ws(table: str) -> list[dict]:
    return json.loads((WS / f"{table}.json").read_text(encoding="utf-8"))["rows"]


def has_zh(s: str) -> bool:
    return any("\u4e00" <= c <= "\u9fff" for c in s)


_ZH_NUM = {"一": "1", "二": "2", "三": "3", "四": "4", "五": "5",
           "六": "6", "七": "7", "八": "8", "九": "9", "十": "10"}


def zh_numeral_variants(zh: str | None) -> list[str]:
    """「沃玛神殿二层」↔「沃玛神殿2层」双索引（地图/区域层号写法不一）。"""
    if not zh:
        return []
    out = []
    if any(c in _ZH_NUM for c in zh):
        out.append("".join(_ZH_NUM.get(c, c) for c in zh))
    has_arabic = any(c.isdigit() for c in zh)
    if has_arabic:
        rev = {v: k for k, v in _ZH_NUM.items()}
        out.append("".join(rev.get(c, c) if c.isdigit() else c for c in zh))
    return [v for v in out if v != zh]


class SemanticMap:
    def __init__(self) -> None:
        self.db_names = json.loads(DB_NAMES.read_text(encoding="utf-8"))
        self.catalog = {e["en"]: e for e in json.loads(ITEM_CATALOG.read_text(encoding="utf-8"))}
        self.tables: dict[str, dict[int, dict]] = {}
        # 多键索引：表 -> key -> [Index...]
        self.index: dict[str, dict[str, list[int]]] = defaultdict(lambda: defaultdict(list))
        self.stats: dict[str, str] = {}
        self.build()

    # ------------------------------------------------ 建表

    def build(self) -> None:
        zh_items = self.db_names.get("items", {})
        zh_mon = self.db_names.get("monsters", {})
        zh_mag = self.db_names.get("magics", {})
        zh_npc = self.db_names.get("npcs", {})
        zh_map = self.db_names.get("maps", {})

        for r in load_ws("ItemInfo"):
            en = r["ItemName"]
            cat = self.catalog.get(en, {})
            zh = cat.get("zh") or zh_items.get(en, {}).get("zh") or en
            self._add("items", r["Index"], en, zh, cat.get("type"), source="item_catalog")
        for r in load_ws("MonsterInfo"):
            en = r["MonsterName"]
            zh = zh_mon.get(en, {}).get("zh") or en
            self._add("monsters", r["Index"], en, zh, None, source="db_names",
                      extra={"Level": int(r.get("Level") or 0),
                             "IsBoss": r.get("IsBoss") == "True"})
        for r in load_ws("MagicInfo"):
            en = r["Name"]
            zh = zh_mag.get(en, {}).get("zh") or en
            self._add("magics", r["Index"], en, zh, None, source="db_names",
                      extra={"Class": r.get("Class")})
        for r in load_ws("NPCInfo"):
            en = r["NPCName"]
            zh = zh_npc.get(en, {}).get("zh") or en
            self._add("npcs", r["Index"], en, zh, None, source="db_names",
                      extra={"Map": (r.get("Region") or {}).get("Name")})
        for r in load_ws("MapInfo"):
            en = r["Description"]
            zh = zh_map.get(en, {}).get("zh") or en
            self._add("maps", r["Index"], en, zh, None, source="db_names",
                      extra={"FileName": r.get("FileName")})
        # regions：键 = "地图中文/区域描述"
        for r in load_ws("MapRegion"):
            mref = r.get("Map") or {}
            m = self.tables["maps"].get(mref.get("Index"))
            if m is None:
                continue
            desc = r.get("Description") or ""
            self._add("regions", r["Index"], desc, desc, None, source="direct",
                      extra={"Map": m["zh"], "MapIndex": m["Index"],
                             "FileName": m.get("FileName")},
                      display_key=f'{m["zh"]}/{desc}')
        self._apply_aliases()
        self._apply_npc_doc13()
        self._build_stats()

    def _add(self, table: str, index: int, en: str, zh: str, typ: str | None, *,
             source: str, extra: dict | None = None, display_key: str | None = None) -> None:
        row = {"Index": index, "Name": en, "zh": zh, "confidence": 1.0,
               "source": source, "aliases": []}
        if typ:
            row["type"] = typ
        if extra:
            row.update(extra)
        row["_display"] = display_key or zh
        self.tables.setdefault(table, {})[index] = row
        ix = self.index[table]
        keys = [zh]
        if zh and ("（" in zh or "(" in zh):
            # 全/半角括号双索引（设计文档写「金创药(小)」，目录是「金创药（小）」）
            keys.append(zh.replace("（", "(").replace("）", ")"))
        for variant in zh_numeral_variants(zh):
            keys.append(variant)
        for k in keys:
            if k:
                ix[k].append(index)
        if en and en != zh:
            ix[en].append(index)

    def _apply_aliases(self) -> None:
        """别名表 → 指向既有词条；同时给被指向词条登记 aliases 反向链。"""
        for table, mapping in ALIASES.items():
            ix = self.index[table]
            rows = self.tables[table]
            for alias, target in mapping.items():
                targets = target if isinstance(target, list) else [target]
                hits: list[int] = []
                for t in targets:
                    en_hits = [i for i in ix.get(t, []) if rows[i]["Name"] == t]
                    zh_hits = [i for i in ix.get(t, []) if rows[i]["zh"] == t]
                    hits.extend(en_hits or zh_hits)
                if not hits:
                    print(f"[!] 别名悬空: {table} {alias!r} -> {targets}（DB 无此名）",
                          file=sys.stderr)
                    continue
                hits = sorted(set(hits))
                ix[alias] = hits                      # 设计叫法可直接命中
                for i in hits:
                    if alias not in rows[i]["aliases"]:
                        rows[i]["aliases"].append(alias)
        # 技能书派生键：技能「烈火剑法」→ 书物品键「烈火剑法书 / 技能书·烈火剑法」
        book_by_zh: dict[str, list[int]] = defaultdict(list)
        for i, r in self.tables["items"].items():
            if r.get("type") == "Book" and r["zh"] and has_zh(r["zh"]):
                book_by_zh[r["zh"]].append(i)
        for magic_zh in list(self.index["magics"].keys()):
            if not has_zh(magic_zh):
                continue
            for key in (f"{magic_zh}书", f"技能书·{magic_zh}"):
                if key not in self.index["items"]:
                    self.index["items"][key] = list(book_by_zh.get(magic_zh, []))

    def _apply_npc_doc13(self) -> None:
        """13-NPC总表.md 的「武侠名 | 英文原名」对照 → NPC 别名。

        表格式：| 武侠名 | 英文原名 | 坐标 | 贴图 | 状态 |（§三 各地图分节）。
        只收录英文原名确实存在于 NPCInfo 的行，避免把贴图建议误当映射。
        """
        p = QD / "13-NPC总表.md"
        if not p.exists():
            return
        rows = self.tables["npcs"]
        ix = self.index["npcs"]
        n = 0
        for line in p.read_text(encoding="utf-8").splitlines():
            m = re.match(r"^\|\s*([^|]+?)\s*\|\s*([A-Za-z][A-Za-z' .\-0-9]*?)\s*\|", line)
            if not m:
                continue
            zh, en = m.group(1).strip(), m.group(2).strip()
            if not has_zh(zh) or zh.startswith(("类别", "武侠名", "状态")):
                continue
            hits = [i for i in ix.get(en, []) if rows[i]["Name"] == en]
            if not hits:
                continue
            ix[zh] = hits
            for i in hits:
                if zh not in rows[i]["aliases"]:
                    rows[i]["aliases"].append(zh)
            n += 1
        print(f"[i] 13 号文档 NPC 别名 {n} 条")

    def _build_stats(self) -> None:
        self.stats = {
            "DC": "MaxDC", "攻击": "MaxDC", "MC": "MaxMC", "魔法": "MaxMC",
            "SC": "MaxSC", "道术": "MaxSC", "AC": "MaxAC", "防御": "MaxAC",
            "MAC": "MaxMR", "MR": "MaxMR", "魔御": "MaxMR", "HP": "Health",
            "MP": "Mana", "命中": "Accuracy", "敏捷": "Agility", "幸运": "Luck",
            "攻速": "AttackSpeed", "魔法防御": "MaxMR",
        }

    # ------------------------------------------------ 查询

    def lookup(self, table: str, term: str) -> dict | None:
        """term（中/英/别名）→ 词条；多候选时 confidence=0.5 并带 candidates。"""
        term = term.strip()
        if not term:
            return None
        ix = self.index.get(table, {})
        rows = self.tables.get(table, {})
        hits = sorted(set(ix.get(term, [])))
        if not hits:
            return None
        if len(hits) == 1:
            out = dict(rows[hits[0]])
            out.pop("_display", None)
            return out
        return {"Index": hits[0], "Name": rows[hits[0]]["Name"], "zh": term,
                "confidence": 0.5, "source": "multi",
                "candidates": [{"Index": i, "Name": rows[i]["Name"], "zh": rows[i]["zh"]}
                               for i in hits]}

    # ------------------------------------------------ 导出

    def export(self) -> dict:
        data: dict = {"items": {}, "monsters": {}, "magics": {}, "npcs": {},
                      "maps": {}, "regions": {}, "stats": self.stats}
        for table in ("items", "monsters", "magics", "npcs", "maps", "regions"):
            for key in self.index[table]:
                if not key:
                    continue
                e = self.lookup(table, key)
                if e is None:
                    continue
                data[table][key] = e
        return data


# ---------------------------------------------------------------- 文档扫描

def scan_design_docs(sm: SemanticMap) -> tuple[Counter, Counter]:
    """扫描设计文档中的实体提及 → (提及计数, 未命中计数)。"""
    mention: Counter = Counter()
    miss: Counter = Counter()

    def check(table: str, term: str) -> None:
        term = term.strip().rstrip("·")
        if not term or not has_zh(term):
            return
        mention[(table, term)] += 1
        if sm.lookup(table, term) is None:
            miss[(table, term)] += 1

    for doc in DESIGN_DOCS:
        p = QD / doc
        if not p.exists():
            continue
        text = p.read_text(encoding="utf-8")
        for m in RE_KILL.finditer(text):
            check("monsters", m.group(1))
        for m in RE_GAIN.finditer(text):
            check("items", m.group(1))
        for m in RE_VISIT.finditer(text):
            raw = m.group(1)
            # "沃玛神殿三层·火池残址" → 地图部分 + 整串都查（region 多为新增）
            check("maps", raw.split("·")[0])
            check("regions", raw)
    return mention, miss


def spot_check(sm: SemanticMap) -> list[tuple[str, str, bool, str]]:
    """验收抽查：任务文档 20 个高频名词。"""
    terms = [
        ("monsters", "骷髅"), ("monsters", "沃玛战士"), ("monsters", "祖玛弓箭手"),
        ("monsters", "沃玛教主"), ("monsters", "祖玛教主"), ("monsters", "森林雪人"),
        ("monsters", "毒蜘蛛"), ("monsters", "狼"), ("monsters", "鸡"),
        ("monsters", "半兽战士"), ("monsters", "蜈蚣"), ("monsters", "稻草人"),
        ("items", "鸡肉"), ("items", "铁矿"), ("items", "金创药(小)"),
        ("items", "烈火剑法书"), ("magics", "烈火剑法"), ("magics", "基本剑术"),
        ("maps", "比奇城"), ("maps", "沃玛神殿"), ("npcs", "万事通"),
    ]
    out = []
    for table, term in terms:
        e = sm.lookup(table, term)
        ok = e is not None and e["confidence"] >= 0.5
        desc = (f'#{e["Index"]} {e["Name"]} conf={e["confidence"]}' if e else "未命中")
        out.append((table, term, ok, desc))
    return out


# ---------------------------------------------------------------- 主流程

def main() -> None:
    sm = SemanticMap()
    data = sm.export()

    mention, miss = scan_design_docs(sm)
    orphans: dict[str, list[dict]] = {}
    for (table, term), n in sorted(miss.items(), key=lambda kv: -kv[1]):
        orphans.setdefault(table, []).append(
            {"term": term, "mentions": n, "total_mentions": mention[(table, term)]})
    data["orphans"] = orphans

    coverage = {}
    for table, rows in sm.tables.items():
        total = len(rows)
        indexed = sum(1 for r in rows.values() if r["zh"] or r["Name"])
        zh_named = sum(1 for r in rows.values() if has_zh(r["zh"]))
        coverage[table] = {
            "rows": total, "indexed": indexed,
            "indexed_pct": round(indexed / total * 100, 2),
            "zh_named": zh_named, "zh_pct": round(zh_named / total * 100, 2),
        }
    data["coverage"] = coverage
    data["meta"] = {
        "generated_by": "Tools/questdata/gen_semantic_map.py",
        "inputs": {
            "workspace": "Tools/dbeditor/workspace (dbeditor 基线导出)",
            "db_names": str(DB_NAMES),
            "item_catalog": str(ITEM_CATALOG.relative_to(REPO)),
        },
        "tables": {t: len(r) for t, r in sm.tables.items()},
        "alias_sources": [
            "NAMING_RULES_2026-08-13.md §1.1/1.5/1.6/1.7",
            "RespawnInfo 怪物→地图实证（沃玛神殿=Uma Temple 等）",
            "光通版 Mir3 常用叫法",
        ],
    }

    OUT_JSON.write_text(json.dumps(data, ensure_ascii=False, indent=1), encoding="utf-8")

    lines = [
        "# semantic_map 生成报告", "",
        f"- 输出：`{OUT_JSON.relative_to(REPO)}`",
        "- 词条规模：" + "、".join(f"{t} {len(sm.tables[t])}" for t in sm.tables),
        "- 置信度：1.0=唯一命中；0.5=多候选（candidates 列出）；0=未命中（orphans）",
        "", "## 覆盖率（验收线：五表 ≥95% 条目被索引）", "",
        "| 表 | 行数 | 被索引 | 覆盖率 | 中文名覆盖 |", "|---|---|---|---|---|",
    ]
    for t, c in coverage.items():
        lines.append(f"| {t} | {c['rows']} | {c['indexed']} | {c['indexed_pct']}% "
                     f"| {c['zh_pct']}% |")
    lines += ["", "## 设计文档名词抽查（验收：20 高频名词可查）", "",
              "| 表 | 名词 | 结果 | 详情 |", "|---|---|---|---|"]
    sp = spot_check(sm)
    for table, term, ok, desc in sp:
        lines.append(f"| {table} | {term} | {'✅' if ok else '❌'} | {desc} |")
    lines += ["", f"**抽查通过 {sum(1 for x in sp if x[2])}/{len(sp)}**", "",
              "## orphans（设计文档用到但库内没有 → 缺口4 自动清单）", ""]
    for table, items in orphans.items():
        lines.append(f"### {table}（{len(items)}）")
        lines.append("")
        lines.append("| 名词 | 提及次数 |")
        lines.append("|---|---|")
        for it in items:
            lines.append(f"| {it['term']} | {it['mentions']} |")
        lines.append("")
    OUT_REPORT.write_text("\n".join(lines), encoding="utf-8")

    print(f"[ok] {OUT_JSON.relative_to(REPO)} ({OUT_JSON.stat().st_size} bytes)")
    print(f"[ok] {OUT_REPORT.relative_to(REPO)}")
    for t, c in coverage.items():
        print(f"  {t}: {c['indexed']}/{c['rows']} = {c['indexed_pct']}%（zh {c['zh_pct']}%）")
    print(f"  抽查: {sum(1 for x in sp if x[2])}/{len(sp)}")
    n_orph = sum(len(v) for v in orphans.values())
    print(f"  orphans: {n_orph} 个名词 "
          f"({', '.join(f'{k}:{len(v)}' for k, v in orphans.items())})")


if __name__ == "__main__":
    main()
