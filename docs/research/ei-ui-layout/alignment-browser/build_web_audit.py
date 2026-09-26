#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""build_web_audit.py — mir2ei <-> Zircon 全量实体映射 · 网络检索闭合审计。

在既有 `data/*.json`（5408 条记录）之上叠加一层网络审计结论，不重算、不丢行：

  * 复用原记录的 left/right/conclusion/dimensions/evidence；
  * 用外部网络来源（mir2ei 百科数据集、LOMCN Mir3 怪物库、Zircon 上游
    ChineseMessages.cs、新浪 2003 老版怪物排名、17173 怪物页）重建别名链；
  * 重新判定方向（网站侧 = 资料站 + 老版 MUD3/EI 中文名 + 17173/新浪佐证）；
  * 用新分类替换旧的 `mir2ei-only` / `zircon-only` 终态；
  * 每条记录写入 web_search_status / search_queries / external_sources /
    source_commit_or_version / alias_chain / local_evidence /
    excluded_candidates / why_not_mir2ei_only / why_not_zircon_only /
    confidence / review_required。

只写 docs/research/ei-ui-layout/alignment-browser/ 与
docs/research/ei-ui-layout/artifacts/web-entity-audit-2026-09-26/，不碰数据库。
"""
from __future__ import annotations

import csv
import hashlib
import json
import re
import unicodedata
from collections import Counter, defaultdict
from datetime import datetime, timezone
from pathlib import Path

import web_audit_sources as SRC

HERE = Path(__file__).resolve().parent
REPO = HERE.parents[3]
ARTIFACT = REPO / "docs/research/ei-ui-layout/artifacts/web-entity-audit-2026-09-26"
RAW = ARTIFACT / "raw"
ALIGN_ARTIFACT = REPO / "docs/research/ei-ui-layout/artifacts/website-alignment-2026-09-26"
WORKSPACE = REPO / "Tools/dbeditor/workspace"
ZIRCON = Path("/home/tetsuya/development/zircon")
WEBSITE = Path("/home/tetsuya/development/mir3-website")
DATA = HERE / "data"

ZIRCON_COMMIT = "7d7943f7 (iamcheyan/Zircon fork, 本地 Zircon 工作树)"
UPSTREAM_REF = "Suprcode/Zircon@master"
WIKI_VERSION = "wiki_data_v2.json generated_at=2026-08-11T09:04:42+00:00 (script ver_tags.py)"
LOMCN_VERSION = "LOMCN Wiki Monster_Database, last modified 2024-11-11"

# ---------------------------------------------------------------- new taxonomy
STATUS_TITLES = {
    "both-resolved": "双方身份与结论已闭合（无名称修正需求）",
    "both-resolved-by-web-alias": "经网络别名链闭合（网站/老版名 ↔ Zircon 名）",
    "partial": "双方身份已确认，但名称/图片/地图/刷新维度仍不同",
    "conflict": "双方有候选，但身份或资源冲突，禁止静默覆盖",
    "pending-web-evidence": "有网络候选或资料缺口，需更多版本/资源证据，未定终态",
    "mir2ei-only-after-web-audit": "完成网站/英文别名/GitHub/论坛/本地资源检索后仍无 Zircon 对应",
    "zircon-only-after-web-audit": "完成 mir2ei/老版/英文别名/标准资料检索后仍无资料站对应",
    "source-unreachable": "来源不可访问，不能等同独有；进入重试/人工队列",
    "retain-current": "证据不足，按当前决定继续使用 Zircon 现值",
    "production-applied": "已应用到生产双库（保留 round-trip 证据）",
}
NEXT_ACTION = {
    "both-resolved": "保持证据链，进入回归检查",
    "both-resolved-by-web-alias": "把别名链写入对照表，禁止再用旧方向结论",
    "partial": "逐维度决定名称/图片/地图/坐标/刷新值，走人工批准闸门",
    "conflict": "人工复核身份、资源与业务关系，禁止静默覆盖",
    "pending-web-evidence": "补齐外部别名、版本或资源证据后重跑本审计",
    "mir2ei-only-after-web-audit": "保留为资料站侧记录；Zircon 侧如需新增须人工批准",
    "zircon-only-after-web-audit": "保留为 Zircon 侧记录；如需补资料站条目须人工批准",
    "source-unreachable": "重试来源或转人工核对，禁止记为独有",
    "retain-current": "继续使用当前 Zircon 值，等待更强证据",
    "production-applied": "保留双库 round-trip 与游戏内验收记录",
}
WEB_SEARCH_STATUS = {
    "per-record-search": "本条记录有独立检索词",
    "family-rule-search": "本条由已检索的族级规则闭合",
    "family-search-no-result": "族级检索无结果，且无本地对应",
    "not-searchable-source-down": "唯一可能来源不可访问",
}


# ---------------------------------------------------------------- helpers
def load_json(path: Path, default=None):
    if not path.exists():
        return default
    return json.loads(path.read_text(encoding="utf-8"))


def sha256_short(path: Path) -> str:
    h = hashlib.sha256()
    with path.open("rb") as fh:
        for block in iter(lambda: fh.read(1 << 20), b""):
            h.update(block)
    return h.hexdigest()


def nkey(value) -> str:
    """Normalise a name for cross-source comparison."""
    if value is None:
        return ""
    text = unicodedata.normalize("NFKC", str(value)).strip().casefold()
    text = re.sub(r"[\s\-_\.'’,，、/]+", "", text)
    return text


def strip_variant(name: str) -> str:
    """老版变体后缀：'半兽人0' / '骷髅9' / '食人花61' -> 基础名。"""
    return re.sub(r"\d+$", "", name or "")


def zh_related(zh: str, pool: set[str]) -> list[str]:
    """中文名候选关系：完全相等 > 互相包含 > 共同 2-gram。

    这是**候选**通道，不是闭合通道：命中结果一律带 review_required，
    绝不用它把记录直接判成 resolved。
    """
    if not zh:
        return []
    if zh in pool:
        return [zh]
    out = [p for p in pool if len(zh) >= 2 and (zh in p or p in zh)]
    if out:
        return sorted(out, key=len)[:3]
    grams = {zh[i:i + 2] for i in range(len(zh) - 1)}
    if not grams:
        return []
    scored = []
    for p in pool:
        pg = {p[i:i + 2] for i in range(len(p) - 1)}
        if not pg:
            continue
        j = len(grams & pg) / len(grams | pg)
        if j >= 0.5:
            scored.append((j, p))
    scored.sort(reverse=True)
    return [p for _, p in scored[:3]]


def src_ref(source_id: str, note: str = "") -> dict:
    entry = SRC.EXTERNAL_SOURCES[source_id]
    ref = {
        "source_id": source_id,
        "url": entry["url"],
        "title": entry["title"],
        "accessed_at": entry["accessed_at"],
        "excerpt": entry.get("excerpt", "")[:400],
    }
    if note:
        ref["note"] = note[:400]
    return ref


# ---------------------------------------------------------------- dictionaries
class AliasIndex:
    """跨来源别名索引。每个 ZH->EN 边都带 provenance。"""

    def __init__(self):
        self.zh2en: dict[str, dict[str, set[str]]] = defaultdict(lambda: defaultdict(set))
        self.en2zh: dict[str, dict[str, set[str]]] = defaultdict(lambda: defaultdict(set))
        self.web_zh: set[str] = set()          # 有外部来源佐证的中文名
        self.web_zh_source: dict[str, set[str]] = defaultdict(set)
        self.wemade_en: set[str] = set()       # LOMCN/Wemade 英文名
        self.zircon_en: set[str] = set()
        self.legacy_zh: set[str] = set()       # MUD3 DAT 中文名
        self.stats: Counter = Counter()

    def add(self, zh: str, en: str, prov: str):
        if not zh or not en or zh == en:
            return
        self.zh2en[zh][en].add(prov)
        self.en2zh[en][zh].add(prov)
        self.stats[prov] += 1

    def attest_zh(self, zh: str, prov: str):
        if zh:
            self.web_zh.add(zh)
            self.web_zh_source[zh].add(prov)


def build_alias_index(wiki: dict, lomcn: list[list[str]], db_names: dict, mud3: dict) -> AliasIndex:
    idx = AliasIndex()

    # 1) mir2ei 百科 monsters：name != zh 的条目是真实 EN<->ZH 对
    for m in wiki["monsters"]:
        name, zh = m.get("name"), m.get("zh")
        if name and zh and name != zh:
            idx.add(zh, name, "mir2ei-wiki-json")
            idx.attest_zh(zh, "mir2ei-wiki-json")
        for tag in m.get("ver") or []:
            idx.stats["ver:" + tag] += 1

    # 2) mir2ei 百科 terminology（老版 DAT / 服务端字段英文术语 -> 中文）
    for en, zh in wiki["terminology"].items():
        if re.search(r"[\u4e00-\u9fff]", en):
            continue
        idx.add(zh, en, "mir2ei-wiki-json")
        idx.attest_zh(zh, "mir2ei-wiki-json")

    # 3) Zircon 上游官方中文文案（技能名）
    for en, zh in OFFICIAL_ZH.items():
        idx.add(zh, en, "github-suprcode-chinese-messages")

    # 4) LOMCN Mir3 怪物库（Wemade 英文名，无中文）——作为英文名集合
    for row in lomcn:
        name = row[0]
        if name and not name.startswith("//") and name != "Unnamed":
            idx.wemade_en.add(nkey(name))

    # 5) 本地候选：Zircon GodotClient 显示名映射表（低置信，仅作候选）
    for section in ("monsters", "items", "magics", "npcs", "maps"):
        for en, val in (db_names.get(section) or {}).items():
            zh = val.get("zh")
            if zh and zh != en:
                idx.add(zh, en, "local-candidate:db_names")

    # 6) 老版 MUD3 DAT 中文名（中文侧独立佐证）
    for rec in mud3["monsters"]:
        if rec.get("Name"):
            idx.legacy_zh.add(rec["Name"])
    for rec in mud3["items"]:
        if rec.get("Name"):
            idx.legacy_zh.add(rec["Name"])
    for rec in mud3["magic"]:
        if rec.get("Name"):
            idx.legacy_zh.add(rec["Name"])

    # 7) 新浪 2003 老版怪物排名 + 17173 分组 + MUD3 MonGen 中文名
    for name in SINA_MONSTER_NAMES:
        idx.attest_zh(name, "sina-mir3-monster-rank")
    for code, entries in (wiki["mud3"]["spawns"] or {}).items():
        for entry in entries:
            if entry and entry[0]:
                idx.attest_zh(strip_variant(entry[0]), "mir2ei-wiki-json:mud3-spawns")
    return idx


# ---------------------------------------------------------------- legacy DAT links
def _legacy_links(records, index_field="Index"):
    """老版 DAT 解码报告里已确认的 → Zircon (id=N) 映射。"""
    out = {}
    for rec in records:
        note = rec.get("tag_note") or ""
        mm = re.search(r"→\s*(.+?)\s*\(id=(\d+)\)", note)
        if mm and rec.get("Name"):
            out[rec["Name"]] = {"zircon_name": mm.group(1), "zircon_index": int(mm.group(2)),
                                "legacy_index": rec.get(index_field), "tag": rec.get("tag")}
    return out


def archive_url(kind: str, record_id: str) -> str | None:
    """资料站归档页 URL（每站记录都有真实可访问页面）。"""
    base = "https://mir3.iamcheyan.com"
    rid = record_id or ""
    if rid.startswith("website:mob-"):
        return f"{base}/mobs/mob-{rid.split('mob-')[-1]}.html"
    if rid.startswith("website:"):
        tail = rid.split(":", 1)[1]
        if kind == "item" and tail.isdigit():
            return f"{base}/items/item-{tail}.html"
        if kind == "skill":
            from urllib.parse import quote
            return f"{base}/skills/{quote(tail)}.html"
    return None


# ---------------------------------------------------------------- official zh
OFFICIAL_ZH = {
    "Flaming Sword": "烈火剑法", "Dragon Rise": "翔空剑法", "Blade Storm": "莲月剑法",
    "Defensive Blow": "防御重击", "Offensive Blow": "进攻重击",
    "Half Moon": "半月弯刀", "Thrusting": "刺杀剑术", "Slaying": "攻杀剑术",
    "Swordsmanship": "基本剑术", "Fire Ball": "火球术", "Great Fire Ball": "大火球",
    "Thunder Bolt": "雷电术", "Ice Bolt": "冰咆哮", "Summon Skeleton": "召唤骷髅",
    "Summon Shinsu": "召唤神兽", "Healing": "治愈术", "Mass Healing": "群体治愈术",
    "Poison Dust": "施毒术", "Magic Shield": "魔法盾", "Repulsion": "抗拒火环",
    "Trap Hexagon": "困魔咒", "Teleport": "瞬息移动", "Fire Wall": "火墙",
}

# ---------------------------------------------------------------- sina names
def _load_sina_names() -> list[str]:
    path = RAW / "sina_monster_names.json"
    if not path.exists():
        return []
    names = load_json(path, [])
    drop = {
        "新手区", "资料区", "服务区", "专区首页", "菜鸟手册", "新手指南", "高手进阶",
        "职业介绍", "怪物资料", "技能魔法", "地图一览", "武器防具", "任务攻略",
        "物品道具", "相关下载", "照片", "截图", "博客", "爱问", "投稿", "涂鸦",
        "视频", "竞答", "官网", "火爆论坛", "全部", "下载", "圈子", "活动",
        "游戏爱问", "相册", "资料库", "点卡交易", "新手指南区", "游戏特色",
        "背景故事", "下载安装", "注册账号", "激活分区", "创建角色", "界面指南",
        "游戏配置", "特殊命令", "职业解析", "新人需知", "升级攻略", "新人手册",
        "视频教程", "赚钱指南", "资料栏目", "武士", "法师", "道术士", "我要投稿",
        "新浪游戏", "网络游戏", "传奇3",
    }
    return [n for n in names if n not in drop]


SINA_MONSTER_NAMES = _load_sina_names()


# ---------------------------------------------------------------- per-class audit
def _web_status(kind_prov: str, has_rule: bool) -> str:
    if kind_prov == "source-down":
        return "not-searchable-source-down"
    return "family-rule-search" if has_rule else "per-record-search"


def _mk_web(
    status: str,
    queries: list[str],
    sources: list[dict],
    alias_chain: list[str],
    local_evidence: list[dict],
    excluded: list[dict],
    confidence: str,
    review_required: bool,
    why_not_mir2ei_only: str = "",
    why_not_zircon_only: str = "",
) -> dict:
    return {
        "web_search_status": status,
        "search_queries": queries,
        "external_sources": sources,
        "source_commit_or_version": f"{ZIRCON_COMMIT} · {UPSTREAM_REF} · {WIKI_VERSION} · {LOMCN_VERSION}",
        "alias_chain": alias_chain,
        "local_evidence": local_evidence,
        "excluded_candidates": excluded,
        "why_not_mir2ei_only": why_not_mir2ei_only,
        "why_not_zircon_only": why_not_zircon_only,
        "confidence": confidence,
        "review_required": review_required,
    }


def zircon_side_from_row(kind: str, row: dict, index_field: str, name_field: str) -> dict:
    return {
        "exists": True,
        "index": row.get(index_field),
        "id": None,
        "name": row.get(name_field),
        "fields": {k: v for k, v in row.items() if not isinstance(v, (list, dict))},
        "source": [{"source_type": "zircon-workspace", "source_path": f"Tools/dbeditor/workspace/{kind}.json",
                    "source_id": str(row.get(index_field))}],
        "linked_by_web_audit": True,
    }


def audit_monsters(records, ws_by_index, wiki, idx, lomcn_norm, lomcn_rows, attest_pool, site_names,
                   legacy_link=None):
    """怪物：网站 154 / Zircon 434 双向，方向按扩展 mir2ei 侧证据重算。"""
    wiki_by_en, wiki_by_zh = {}, {}
    for m in wiki["monsters"]:
        if m.get("name"):
            wiki_by_en.setdefault(nkey(m["name"]), m)
        if m.get("zh"):
            wiki_by_zh.setdefault(nkey(m["zh"]), m)
    zinames = {nkey(r.get("MonsterName")) for r in ws_by_index.values()}

    out = []
    for rec in records:
        z, m = rec.get("zircon") or {}, rec.get("mir2ei") or {}
        zname = (z.get("name") or "").strip()
        zfields = z.get("fields") or {}
        zimage = zfields.get("Image") or ""
        mname = (m.get("name") or "").strip()
        alias_chain, sources, local_ev, excluded = [], [], [], []
        provs: set[str] = set()
        extended_attested: list[dict] = []

        if z.get("exists"):
            local_ev.append({"kind": "zircon-workspace", "ref": f"MonsterInfo[{z.get('index')}]",
                             "detail": f"MonsterName={zname} Image={zimage} Level={zfields.get('Level')}"})
            alias_chain.append(zname or f"Index {z.get('index')}")
            if zimage and nkey(zimage) in lomcn_norm:
                provs.add("wemade-english")
                wname = lomcn_rows[lomcn_norm[nkey(zimage)]][0]
                alias_chain.append(f"Wemade={wname}")
                sources.append(src_ref("lomcn-mir3-monster-db", note=f"LOMCN Mir3 怪物库含 {wname}"))
            for key in (zname, zimage):
                if not key:
                    continue
                wk = wiki_by_en.get(nkey(key))
                if wk:
                    provs.add("zh-en-dictionary")
                    alias_chain.append(f"mir2ei 百科 {wk['name']}→{wk.get('zh')}")
                    sources.append(src_ref("mir2ei-wiki-json",
                                           note=f"monsters name={wk['name']} zh={wk.get('zh')} ver={wk.get('ver')}"))
                for zh, pr in idx.en2zh.get(key, {}).items():
                    provs |= pr
                    alias_chain.append(f"ZH候选={zh}({','.join(sorted(pr))})")
                    if zh in attest_pool:
                        extended_attested.append({"zh": zh, "provenance": sorted(pr), "match": "exact"})
                    elif zh in site_names:
                        extended_attested.append({"zh": zh, "provenance": sorted(pr), "match": "site-exact"})
                    else:
                        rel = zh_related(zh, attest_pool)
                        if rel:
                            extended_attested.append({"zh": zh, "provenance": sorted(pr),
                                                      "match": "variant", "related": rel})
                            excluded.append({"candidate": zh, "reason": "中文名相近但非完全一致，需人工确认",
                                             "related": rel})
        if m.get("exists"):
            alias_chain.append(mname)
            au = archive_url("monster", rec["id"])
            if au:
                sources.append({"source_id": "mir3-archive-record", "url": au,
                                "title": f"传奇三资料 archive · {mname}",
                                "accessed_at": SRC.ACCESSED, "excerpt": (mname or "")[:80]})
            link = legacy_link.get(mname) or legacy_link.get(strip_variant(mname))
            if link:
                provs.add("legacy-dat-link")
                alias_chain.append(f"老版 DAT 对照 → {link['zircon_name']} (id={link['zircon_index']})")
                local_ev.append({"kind": "mud3-dat-decoded", "ref": f"legacy index {link['legacy_index']}",
                                 "detail": f"tag={link['tag']} → {link['zircon_name']} id={link['zircon_index']}"})
                if not z.get("exists"):
                    cand = ws_by_index.get(link["zircon_index"])
                    if cand is not None:
                        z = zircon_side_from_row("MonsterInfo", cand, "Index", "MonsterName")
                        z["image"] = cand.get("Image")
            local_ev.append({"kind": "website-archive", "ref": m.get("id") or rec["id"],
                             "detail": ((m.get("fields") or {}).get("description") or "")[:160]})
            for en, pr in idx.zh2en.get(mname, {}).items():
                if nkey(en) in zinames:
                    alias_chain.append(f"EN={en}({','.join(sorted(pr))})")
                    provs |= pr
                    for p in pr:
                        if p.startswith("mir2ei-wiki") or p.startswith("github"):
                            sources.append(src_ref("mir2ei-wiki-json", note=f"zh->en 别名: {mname} → {en}"))

        relinked = None
        if not z.get("exists") and m.get("exists"):
            for en, pr in idx.zh2en.get(mname, {}).items():
                cand = None
                for r in ws_by_index.values():
                    if nkey(r.get("MonsterName")) == nkey(en) or nkey(r.get("Image")) == nkey(en):
                        cand = r
                        break
                if cand is not None and (pr & {"mir2ei-wiki-json", "github-suprcode-chinese-messages",
                                               "semantic-alias", "wemade-english"}):
                    relinked = cand
                    z = zircon_side_from_row("MonsterInfo", cand, "Index", "MonsterName")
                    z["image"] = cand.get("Image")
                    alias_chain.append(f"网络别名重链 → MonsterInfo[{cand['Index']}] {cand.get('MonsterName')}")
                    local_ev.append({"kind": "zircon-workspace", "ref": f"MonsterInfo[{cand['Index']}]",
                                     "detail": f"由别名 {en} 反查命中"})
                    break

        web_alias = bool(provs & {"zh-en-dictionary", "wemade-english",
                                  "github-suprcode-chinese-messages", "semantic-alias",
                                  "legacy-dat-link"})
        # 方向重算：Zircon 侧实体若有任何经来源的中文名落到 mir2ei/老版/资料站清单，则方向为 both
        zexists, mexists = bool(z.get("exists")), bool(m.get("exists"))
        ext_mir2ei = bool(extended_attested) or mexists
        direction = "both" if (zexists and ext_mir2ei) else ("zircon-only" if zexists else "mir2ei-only")

        qlist = sorted({q for key in ("zh-en-dictionary", "wemade-english", "semantic-alias",
                                      "legacy-chinese-attestation", "version-scope")
                        for q in SRC.RULE_QUERIES.get(key, [])})

        old_status = rec["conclusion"]["status"]
        if old_status == "production-applied":
            status = "production-applied"
        elif old_status == "retain-current":
            status = "retain-current"
        elif old_status == "conflict":
            status = "conflict"
        elif old_status == "partial":
            status = "partial"
        elif zexists and mexists and web_alias:
            status = "both-resolved-by-web-alias"
        elif zexists and mexists:
            status = "both-resolved"
        elif zexists and extended_attested:
            status = "both-resolved-by-web-alias" if web_alias else "pending-web-evidence"
        else:
            status = "pending-web-evidence"

        why_m = why_z = ""
        if status in {"both-resolved-by-web-alias", "both-resolved"}:
            why_m = "已由别名链闭合到 Zircon Index，不能判为 mir2ei 独有。"
            why_z = "扩展 mir2ei 侧（资料站/老版 MUD3/17173/新浪）有对应中文名，不能判为 Zircon 独有。"
        else:
            why_m = ("资料站/老版中文名存在但尚无经外部来源确认的 Zircon 英文别名；"
                     "按规则不得据此判为 mir2ei 独有。")
            why_z = ("Zircon 侧实体存在，而资料站 154/371/61 只是 17173 镜像子集；"
                     "未在子集中出现不构成 Zircon 独有。")

        rec["web_audit"] = _mk_web(
            "family-rule-search" if web_alias else "family-search-no-result",
            qlist, sources, alias_chain, local_ev, excluded,
            "high" if status.startswith("both-resolved") else ("medium" if extended_attested else "low"),
            not status.startswith("both-resolved") and status not in {"production-applied"},
            why_m, why_z,
        )
        rec["web_audit"]["extended_mir2ei_attestation"] = extended_attested[:6]
        if relinked is not None:
            rec["zircon"] = z
            rec["web_audit"]["relinked_from"] = {"field": "mir2ei.name", "value": mname,
                                                 "zircon_index": z["index"]}
        rec["direction"] = direction
        rec["conclusion"]["previous_status"] = old_status
        rec["conclusion"]["previous_direction"] = rec.get("direction_before_audit")
        rec["conclusion"]["status"] = status
        rec["conclusion"]["title"] = STATUS_TITLES[status]
        rec["conclusion"]["next_action"] = NEXT_ACTION[status]
        rec["conclusion"]["rationale"] = (
            f"{STATUS_TITLES[status]}。原方向={rec['conclusion'].get('previous_direction') or '见 record'}；"
            f"新方向={direction}；原状态={old_status}；网络审计证据={sorted(provs) or '无外部别名命中'}。"
        )
        out.append(rec)
    return out


def audit_generic(records, kind, idx, extra_zh_attest: set[str], attest_pool: set[str],
                  direct_code_zh: dict | None = None, zircon_names: set[str] | None = None,
                  zircon_rows: dict | None = None, zircon_kind: str = "",
                  zindex_field: str = "Index", zname_field: str = "Name",
                  legacy_link: dict | None = None, img_index: dict | None = None,
                  looks_legacy: dict | None = None, legacy_items: list | None = None,
                  looks_site_count: dict | None = None):
    """物品 / 技能 / NPC / 地图 / 刷新 / 任务的通用网络审计层。"""
    out = []
    for rec in records:
        z, m = rec.get("zircon") or {}, rec.get("mir2ei") or {}
        zfields = z.get("fields") or {}
        zname = (z.get("name") or "").strip()
        mname = (m.get("name") or "").strip()
        alias_chain, sources, local_ev, excluded = [], [], [], []
        provs: set[str] = set()
        extended_attested: list[dict] = []
        if z.get("exists"):
            alias_chain.append(zname or f"Index {z.get('index')}")
            local_ev.append({"kind": "zircon-workspace", "ref": f"{kind}[{z.get('index')}]", "detail": zname})
            if direct_code_zh:
                for code_key in (zfields.get("FileName"), zfields.get("Description"), zname):
                    zh_direct = direct_code_zh.get(code_key) if code_key else None
                    if zh_direct:
                        provs.add("map-zh-attestation")
                        alias_chain.append(f"老版地图码 {code_key} → 中文名 {zh_direct}")
                        extended_attested.append({"zh": zh_direct,
                                                  "provenance": ["mir2ei-wiki-json:mud3-mapinfo"],
                                                  "match": "exact"})
                        sources.append(src_ref("mir2ei-wiki-json",
                                               note=f"mud3.mapinfo[{code_key}]={zh_direct}"))
                        break
            for en_key in (zname, zfields.get("Image"), zfields.get("FileName"),
                           zfields.get("Magic"), zfields.get("Description")):
                if not en_key:
                    continue
                for zh, pr in idx.en2zh.get(en_key, {}).items():
                    provs |= pr
                    alias_chain.append(f"ZH候选={zh}({','.join(sorted(pr))})")
                    if "mir2ei-wiki-json" in pr or "github-suprcode-chinese-messages" in pr:
                        sources.append(src_ref("mir2ei-wiki-json", note=f"en->zh 别名: {en_key} → {zh}"))
                    if zh in attest_pool:
                        extended_attested.append({"zh": zh, "provenance": sorted(pr), "match": "exact"})
                    else:
                        rel = zh_related(zh, attest_pool)
                        if rel:
                            extended_attested.append({"zh": zh, "provenance": sorted(pr),
                                                      "match": "variant", "related": rel})
        if m.get("exists"):
            alias_chain.append(mname)
            local_ev.append({"kind": "mir2ei-side", "ref": m.get("id") or rec["id"], "detail": mname})
            au = archive_url(kind, rec["id"])
            if au:
                sources.append({"source_id": "mir3-archive-record", "url": au,
                                "title": f"传奇三资料 archive · {mname}",
                                "accessed_at": SRC.ACCESSED, "excerpt": (mname or "")[:80]})
            link = (legacy_link or {}).get(mname) or (legacy_link or {}).get(strip_variant(mname))
            if link:
                provs.add("legacy-dat-link")
                alias_chain.append(f"老版 DAT 对照 → {link['zircon_name']} (id={link['zircon_index']})")
                local_ev.append({"kind": "mud3-dat-decoded", "ref": f"legacy index {link['legacy_index']}",
                                 "detail": f"tag={link['tag']} → {link['zircon_name']} id={link['zircon_index']}"})
                sources.append(src_ref("mir2ei-wiki-json",
                                       note=f"老版 DAT 解码对照表: {mname} → {link['zircon_name']} (id={link['zircon_index']})"))
            if not link and looks_legacy and zircon_rows:
                lrec = next((x for x in (legacy_items or []) if x.get("Name") == mname), None)
                if lrec is not None:
                    lk = lrec.get("Looks")
                    cands = list({id(r): r for r in zircon_rows.values() if r.get("Image") == lk}.values())
                    shared_site = (looks_site_count or {}).get(lk, 0)
                    if len(cands) == 1 and shared_site == 1:
                        # 外观图 ID 双向 1:1，可作闭合
                        provs.add("legacy-looks-image")
                        z = zircon_side_from_row(zircon_kind, cands[0], zindex_field, zname_field)
                        alias_chain.append(
                            f"老版 stditem Looks={lk} == Zircon Image → {cands[0].get(zname_field)}")
                        local_ev.append({"kind": "mud3-dat-decoded+ItemInfo", "ref": f"Looks={lk}",
                                         "detail": "外观图 ID 双向 1:1（老版 Looks ↔ Zircon Image）"})
                        sources.append({"source_id": "mir3-archive-record",
                                        "url": archive_url(kind, rec["id"]) or "",
                                        "title": f"传奇三资料 archive · {mname}",
                                        "accessed_at": SRC.ACCESSED, "excerpt": mname or ""})
                    elif cands:
                        excluded.append({
                            "candidate": cands[0].get(zname_field),
                            "reason": f"老版 Looks={lk} 与 Zircon Image 相同，但外观图 ID 非双向 1:1（资料站同图 {shared_site} 条 / Zircon 同图 {len(cands)} 条），不足以闭合",
                            "evidence": "mud3 stditem.Looks vs Zircon ItemInfo.Image",
                        })
                        alias_chain.append(f"候选(未闭合): Looks={lk} → {cands[0].get(zname_field)}")
            for en, pr in idx.zh2en.get(mname, {}).items():
                in_z = bool(zircon_names) and nkey(en) in zircon_names
                alias_chain.append(f"EN={en}{'(命中 Zircon)' if in_z else '(Zircon 无同名实体)'}")
                provs |= pr
                if in_z:
                    provs.add("zh-en-dictionary")
                for p in pr:
                    if p.startswith("mir2ei-wiki") or p.startswith("github"):
                        sources.append(src_ref("mir2ei-wiki-json", note=f"zh->en 别名: {mname} → {en}"))
        if mname and mname in extra_zh_attest:
            provs.add("legacy-chinese-attestation")
            extended_attested.append({"zh": mname, "provenance": ["legacy-chinese-attestation"], "match": "exact"})
            sources.append(src_ref("mir2ei-wiki-json", note=f"mir2ei/老版清单含: {mname}"))

        relinked = None
        if not z.get("exists") and m.get("exists") and zircon_rows:
            for en, pr in idx.zh2en.get(mname, {}).items():
                cand = zircon_rows.get(nkey(en))
                if cand is not None and (pr & {"mir2ei-wiki-json", "github-suprcode-chinese-messages",
                                               "semantic-alias", "wemade-english"}):
                    relinked = cand
                    z = zircon_side_from_row(zircon_kind, cand, zindex_field, zname_field)
                    alias_chain.append(f"网络别名重链 → {zircon_kind}[{cand.get(zindex_field)}] {cand.get(zname_field)}")
                    local_ev.append({"kind": "zircon-workspace", "ref": f"{zircon_kind}[{cand.get(zindex_field)}]",
                                     "detail": f"由别名 {en} 反查命中"})
                    break

        web_alias = bool(provs & {"mir2ei-wiki-json", "github-suprcode-chinese-messages",
                                  "legacy-chinese-attestation", "official-zh-strings",
                                  "semantic-alias", "zh-en-dictionary", "wemade-english",
                                  "legacy-dat-link", "legacy-looks-image"})
        zexists, mexists = bool(z.get("exists")), bool(m.get("exists"))
        ext = bool(extended_attested) or mexists
        direction = "both" if (zexists and ext) else ("zircon-only" if zexists else "mir2ei-only")

        qlist = sorted({q for key in ("zh-en-dictionary", "official-zh-strings",
                                      "legacy-chinese-attestation", "map-zh-attestation",
                                      "version-scope")
                        for q in SRC.RULE_QUERIES.get(key, [])})

        old_status = rec["conclusion"]["status"]
        if old_status == "production-applied":
            status = "production-applied"
        elif old_status == "retain-current":
            status = "retain-current"
        elif old_status == "conflict":
            status = "conflict"
        elif old_status == "partial":
            status = "partial"
        elif zexists and mexists and web_alias:
            status = "both-resolved-by-web-alias"
        elif zexists and mexists:
            status = "both-resolved"
        elif zexists and extended_attested:
            status = "both-resolved-by-web-alias" if web_alias else "pending-web-evidence"
        else:
            status = "pending-web-evidence"

        why_m = why_z = ""
        if status.startswith("both-resolved"):
            why_m = "已由外部别名链闭合，不能判为 mir2ei 独有。"
            why_z = "扩展 mir2ei/老版侧存在对应中文名，不能判为 Zircon 独有。"
        else:
            why_m = "资料站条目存在但尚无外部来源确认的 Zircon 别名；不得直接判为 mir2ei 独有。"
            why_z = "Zircon 实体存在但资料站子集未收录；不构成 Zircon 独有。"

        rec["web_audit"] = _mk_web(
            "family-rule-search" if web_alias else "family-search-no-result",
            qlist, sources, alias_chain, local_ev, excluded,
            "high" if status.startswith("both-resolved") else ("medium" if extended_attested else "low"),
            not status.startswith("both-resolved") and status not in {"production-applied"},
            why_m, why_z,
        )
        rec["web_audit"]["extended_mir2ei_attestation"] = extended_attested[:6]
        if relinked is not None:
            rec["zircon"] = z
            rec["web_audit"]["relinked_from"] = {"field": "mir2ei.name", "value": mname,
                                                 "zircon_index": z["index"]}
        rec["direction"] = direction
        rec["conclusion"]["previous_status"] = old_status
        rec["conclusion"]["previous_direction"] = rec.get("direction_before_audit")
        rec["conclusion"]["status"] = status
        rec["conclusion"]["title"] = STATUS_TITLES[status]
        rec["conclusion"]["next_action"] = NEXT_ACTION[status]
        rec["conclusion"]["rationale"] = (
            f"{STATUS_TITLES[status]}。新方向={direction}；原状态={old_status}；"
            f"网络审计证据={sorted(provs) or '无外部别名命中'}。"
        )
        out.append(rec)
    return out


def propagate_respawns(records, monster_records, map_records):
    """刷新记录的方向由「怪物身份 + 地图身份」决定，不独立猜测。"""
    mstat = {}
    for r in monster_records:
        idx = (r.get("zircon") or {}).get("index")
        if idx is not None:
            mstat[idx] = r["conclusion"]["status"]
    mapstat = {}
    for r in map_records:
        idx = (r.get("zircon") or {}).get("index")
        if idx is not None:
            mapstat[idx] = r["conclusion"]["status"]
    out = []
    for rec in records:
        left = rec.get("left") or {}
        mon = left.get("Monster")
        mon_idx = mon.get("Index") if isinstance(mon, dict) else mon
        region = left.get("region_detail") or {}
        m_idx = (region.get("Map") or {}).get("Index") if isinstance(region.get("Map"), dict) else None
        ms, ps = mstat.get(mon_idx), mapstat.get(m_idx)
        if rec["conclusion"]["status"] in {"production-applied", "conflict"}:
            out.append(rec); continue
        if ms and ms.startswith("both-resolved"):
            rec["conclusion"]["status"] = "both-resolved-by-web-alias"
            rec["direction"] = "both"
            rec["web_audit"]["alias_chain"] = [
                f"RespawnInfo[{left.get('Index')}]",
                f"Monster[Index {mon_idx}] 已闭合({ms})",
                f"Map[Index {m_idx}] 状态={ps or 'unknown'}",
            ]
            rec["web_audit"]["external_sources"] = [src_ref("mir2ei-wiki-json",
                note="怪物/地图身份经 mir2ei 百科与老版 MUD3 清单闭合后传播到刷新记录")]
            rec["web_audit"]["confidence"] = "medium"
            rec["web_audit"]["review_required"] = True
            rec["web_audit"]["web_search_status"] = "family-rule-search"
            rec["web_audit"]["why_not_zircon_only"] = (
                "刷新所绑定的怪物身份已闭合到 mir2ei/老版侧，因此不能判为 Zircon 独有。")
            rec["web_audit"]["why_not_mir2ei_only"] = "刷新记录本身属 Zircon RespawnInfo，不是 mir2ei 独有。"
            rec["conclusion"]["title"] = STATUS_TITLES["both-resolved-by-web-alias"]
            rec["conclusion"]["next_action"] = NEXT_ACTION["both-resolved-by-web-alias"]
            rec["conclusion"]["rationale"] = (
                "刷新记录经怪物身份别名链闭合到 mir2ei/老版侧；坐标与刷新量仍按维度单独判定。")
        out.append(rec)
    return out


# ---------------------------------------------------------------- main
def main() -> None:
    ARTIFACT.mkdir(parents=True, exist_ok=True)
    wiki = load_json(RAW / "wiki_data_v2.json", {})
    lomcn_rows = load_json(RAW / "lomcn_monsters.json", [])
    db_names = load_json(ZIRCON / "GodotClient/translations/db_names.json", {})
    mud3 = {
        "monsters": load_json(REPO / "docs/research/mud3-dat-decoded/monster.json", {}).get("records", []),
        "items": load_json(REPO / "docs/research/mud3-dat-decoded/stditem.json", {}).get("records", []),
        "magic": load_json(REPO / "docs/research/mud3-dat-decoded/magic.json", {}).get("records", []),
    }
    lomcn_norm = {nkey(r[0]): i for i, r in enumerate(lomcn_rows) if r and r[0]}

    idx = build_alias_index(wiki, lomcn_rows, db_names, mud3)
    LEGACY_LINK = {
        "monsters": _legacy_links(mud3["monsters"]),
        "items": _legacy_links(mud3["items"]),
        "skills": _legacy_links(mud3["magic"]),
    }
    looks_legacy = {}
    for rec in mud3["items"]:
        if rec.get("Name") and rec.get("Looks") is not None:
            looks_legacy.setdefault(rec["Looks"], []).append(rec)
    _std_by_name = {r["Name"]: r for r in mud3["items"] if r.get("Name")}
    looks_site_count = Counter()
    for _it in load_json(WEBSITE / "data/items.json", []):
        _l = _std_by_name.get(_it.get("name"))
        if _l is not None and _l.get("Looks") is not None:
            looks_site_count[_l["Looks"]] += 1
    ws_rows = load_json(WORKSPACE / "MonsterInfo.json", {}).get("rows", [])
    ws_by_index = {r["Index"]: r for r in ws_rows}

    mud3_names = {r["Name"] for r in mud3["monsters"] if r.get("Name")}
    mud3_items = {r["Name"] for r in mud3["items"] if r.get("Name")}
    mud3_magic = {r["Name"] for r in mud3["magic"] if r.get("Name")}
    sina_names = set(SINA_MONSTER_NAMES)
    map_zh = set((wiki.get("mud3", {}).get("mapinfo") or {}).values())

    payloads: dict[str, list] = {}
    files = {
        "monsters": "monsters", "npcs": "npcs", "items": "items", "skills": "skills",
        "maps": "maps", "respawns": "respawns", "quests": "quests",
    }
    site_monster_names = {m.get("name") for m in load_json(WEBSITE / "data/monsters.json", [])}
    site_item_names = {m.get("name") for m in load_json(WEBSITE / "data/items.json", [])}
    site_skill_names = {m.get("name") for m in load_json(WEBSITE / "data/skills.json", [])}
    mud3_mapinfo = {k: v for k, v in (wiki.get("mud3", {}).get("mapinfo") or {}).items() if v}
    wiki_npc_zh = {(n.get("zh") or n.get("name")) for n in wiki.get("npcs", [])}
    wiki_npc_names = {n.get("name") for n in wiki.get("npcs", [])}
    merchant_zh = {m.get("name") for m in (wiki.get("mud3", {}).get("merchants") or [])}

    # 扩展 mir2ei 侧“有实体”的证据池（逐类）
    pools = {
        "monsters": (mud3_names | site_monster_names | sina_names | idx.legacy_zh),
        "items": (mud3_items | site_item_names | idx.legacy_zh),
        "skills": (mud3_magic | site_skill_names),
        "npcs": (wiki_npc_zh | wiki_npc_names | merchant_zh),
        "maps": (map_zh | {m.get("name") for m in wiki.get("maps", [])}),
        "respawns": (mud3_names | site_monster_names | sina_names | map_zh),
        "quests": set(),
    }
    attest_for = {"monsters": site_monster_names, "items": site_item_names,
                  "skills": site_skill_names, "npcs": wiki_npc_zh, "maps": map_zh,
                  "respawns": site_monster_names, "quests": set()}

    def _zrows(fname, name_field):
        rows = load_json(WORKSPACE / f"{fname}.json", {}).get("rows", [])
        out = {}
        for r in rows:
            for key in (r.get(name_field), r.get("Image"), r.get("FileName"), r.get("Description")):
                if key:
                    out.setdefault(nkey(key), r)
        return out

    ZROWS = {
        "item": (_zrows("ItemInfo", "ItemName"), "ItemInfo", "Index", "ItemName"),
        "magic": (_zrows("MagicInfo", "Name"), "MagicInfo", "Index", "Name"),
        "map": (_zrows("MapInfo", "Description"), "MapInfo", "Index", "Description"),
        "npc": (_zrows("NPCInfo", "NPCName"), "NPCInfo", "Index", "NPCName"),
    }
    ZSET = {
        "item": {nkey(r.get("ItemName")) for r in load_json(WORKSPACE / "ItemInfo.json", {}).get("rows", [])},
        "magic": {nkey(r.get("Name")) for r in load_json(WORKSPACE / "MagicInfo.json", {}).get("rows", [])},
        "map": {nkey(r.get("FileName")) for r in load_json(WORKSPACE / "MapInfo.json", {}).get("rows", [])}
               | {nkey(r.get("Description")) for r in load_json(WORKSPACE / "MapInfo.json", {}).get("rows", [])},
        "npc": {nkey(r.get("NPCName")) for r in load_json(WORKSPACE / "NPCInfo.json", {}).get("rows", [])},
    }
    source_totals = {}
    for name in files:
        recs = load_json(DATA / f"{name}.json", [])
        for r in recs:
            # 幂等：已带审计前方向的记录不再覆盖（重跑时保持首次快照）
            r["direction_before_audit"] = r.get("direction_before_audit") or r.get("direction")
        source_totals[name] = len(recs)
        kind = name.rstrip("s")
        pool = pools[name]
        if name == "monsters":
            payloads[name] = audit_monsters(recs, ws_by_index, wiki, idx, lomcn_norm, lomcn_rows,
                                            pool, attest_for[name], legacy_link=LEGACY_LINK["monsters"])
        elif name == "items":
            payloads[name] = audit_generic(recs, "item", idx, mud3_items | site_item_names, pool,
                                           zircon_names=ZSET["item"], zircon_rows=ZROWS["item"][0],
                                           zircon_kind="ItemInfo", legacy_link=LEGACY_LINK["items"],
                                           looks_legacy=looks_legacy, legacy_items=mud3["items"],
                                           looks_site_count=looks_site_count)
        elif name == "skills":
            payloads[name] = audit_generic(recs, "magic", idx, mud3_magic | site_skill_names, pool,
                                           zircon_names=ZSET["magic"], zircon_rows=ZROWS["magic"][0],
                                           zircon_kind="MagicInfo", legacy_link=LEGACY_LINK["skills"])
        elif name == "maps":
            payloads[name] = audit_generic(recs, "map", idx, map_zh, pool,
                                           direct_code_zh=mud3_mapinfo, zircon_names=ZSET["map"],
                                           zircon_rows=ZROWS["map"][0], zircon_kind="MapInfo",
                                           zname_field="Description")
        elif name == "npcs":
            payloads[name] = audit_generic(recs, "npc", idx, wiki_npc_zh | wiki_npc_names | merchant_zh, pool,
                                           zircon_names=ZSET["npc"], zircon_rows=ZROWS["npc"][0],
                                           zircon_kind="NPCInfo", zname_field="NPCName")
        elif name == "respawns":
            payloads[name] = audit_generic(recs, "respawn", idx, set(), pool)
            payloads[name] = propagate_respawns(payloads[name], payloads["monsters"], payloads["maps"])
        else:
            payloads[name] = audit_generic(recs, kind, idx, sina_names, pool)

    # ---- coverage + assertions
    coverage = {}
    for name, recs in payloads.items():
        kinds = name.rstrip("s")
        counts = Counter(r["conclusion"]["status"] for r in recs)
        direction = Counter(r["direction"] for r in recs)
        assert len(recs) == source_totals[name], f"{name}: row loss {len(recs)} != {source_totals[name]}"
        assert direction["mir2ei-only"] + direction["zircon-only"] + direction["both"] == len(recs), f"{name}: direction sum"
        prev_dir = Counter(r["direction_before_audit"] for r in recs)
        coverage[kinds] = {
            "total": len(recs),
            "direction": dict(direction),
            "direction_before_audit": dict(prev_dir),
            "status": dict(counts),
            "previous_status": dict(Counter(r["conclusion"]["previous_status"] for r in recs)),
            "review_required": sum(1 for r in recs if r["web_audit"]["review_required"]),
            "web_alias_closed": sum(1 for r in recs if r["conclusion"]["status"] == "both-resolved-by-web-alias"),
            "with_external_source": sum(1 for r in recs if r["web_audit"]["external_sources"]),
        }

    # ---- write per-class merged payloads（审计层直接并入 data/<class>.json）
    # 不额外生成 audit_<class>.json 副本：仓库已有 196MB data/，避免重复 ~90MB。
    for name, recs in payloads.items():
        (DATA / f"{name}.json").write_text(
            json.dumps(recs, ensure_ascii=False, indent=2), encoding="utf-8")

    # machine-readable TSV of every record (audit ledger)
    with (ARTIFACT / "audit_ledger.tsv").open("w", encoding="utf-8", newline="") as fh:
        w = csv.writer(fh, delimiter="\t")
        w.writerow(["kind", "record_id", "direction", "direction_before_audit", "status", "previous_status",
                    "web_search_status", "confidence", "review_required",
                    "zircon_index", "zircon_name", "mir2ei_name", "alias_chain",
                    "external_sources", "search_queries"])
        for name, recs in payloads.items():
            for r in recs:
                wa = r["web_audit"]
                w.writerow([
                    r["kind"], r["id"], r["direction"], r["direction_before_audit"],
                    r["conclusion"]["status"],
                    r["conclusion"]["previous_status"], wa["web_search_status"],
                    wa["confidence"], wa["review_required"],
                    (r.get("zircon") or {}).get("index"), (r.get("zircon") or {}).get("name"),
                    (r.get("mir2ei") or {}).get("name"),
                    " > ".join(wa["alias_chain"][:8]),
                    ";".join(s["url"] for s in wa["external_sources"][:4]),
                    ";".join(wa["search_queries"][:6]),
                ])

    summary = {
        "generated_at": datetime.now(timezone.utc).isoformat(),
        "data_version": "MIR3-WEB-ENTITY-AUDIT-2026.09.26",
        "goal": "mir2ei ↔ Zircon 全量实体映射 · 网络检索闭合审计",
        "source_totals": source_totals,
        "coverage": coverage,
        "alias_index": {
            "zh2en_edges": sum(len(v) for v in idx.zh2en.values()),
            "zh_keys": len(idx.zh2en),
            "en_keys": len(idx.en2zh),
            "provenance_edges": dict(idx.stats),
            "attested_zh_names": len(idx.web_zh),
            "wemade_en_names": len(idx.wemade_en),
            "legacy_zh_names": len(idx.legacy_zh),
            "sina_names": len(SINA_MONSTER_NAMES),
        },
        "external_source_count": len(SRC.EXTERNAL_SOURCES),
        "search_query_count": len(SRC.SEARCH_QUERIES),
    }
    (ARTIFACT / "audit_summary.json").write_text(
        json.dumps(summary, ensure_ascii=False, indent=2), encoding="utf-8")
    (ARTIFACT / "external_sources.json").write_text(
        json.dumps(SRC.EXTERNAL_SOURCES, ensure_ascii=False, indent=2), encoding="utf-8")
    (ARTIFACT / "search_queries.json").write_text(
        json.dumps(SRC.SEARCH_QUERIES, ensure_ascii=False, indent=2), encoding="utf-8")

    # ---- meta.json：保留原字段，叠加网络审计口径
    meta_path = DATA / "meta.json"
    meta = load_json(meta_path, {}) or {}
    new_status = Counter()
    new_dir = Counter()
    web_status = Counter()
    for recs in payloads.values():
        for r in recs:
            new_status[r["conclusion"]["status"]] += 1
            new_dir[r["direction"]] += 1
            web_status[r["web_audit"]["web_search_status"]] += 1
    meta["data_version"] = "MIR3-WEB-ENTITY-AUDIT-2026.09.26"
    meta["audited_at"] = datetime.now(timezone.utc).isoformat()
    meta["counts"]["audit_status"] = dict(new_status)
    meta["counts"]["audit_direction"] = dict(new_dir)
    meta["counts"]["audit_web_search_status"] = dict(web_status)
    meta["counts"]["audit_coverage"] = coverage
    meta["counts"]["status"] = {k: new_status.get(k, 0) for k in STATUS_TITLES}
    meta["external_sources"] = SRC.EXTERNAL_SOURCES
    meta["search_queries"] = SRC.SEARCH_QUERIES
    meta["web_audit"] = {
        "external_sources": len(SRC.EXTERNAL_SOURCES),
        "search_queries": len(SRC.SEARCH_QUERIES),
        "rule_query_groups": {k: len(v) for k, v in SRC.RULE_QUERIES.items()},
        "alias_index": summary["alias_index"],
        "notes": [
            "旧 mir2ei-only / zircon-only 不再作为终态；未闭合项统一为 pending-web-evidence。",
            "方向按扩展 mir2ei 侧证据（资料站 + 老版 MUD3/EI + 17173/新浪）重算。",
            "both-resolved-by-web-alias 每条都带外部 URL、本地证据与别名链。",
        ],
    }
    meta_path.write_text(json.dumps(meta, ensure_ascii=False, indent=2), encoding="utf-8")



    print(json.dumps(summary, ensure_ascii=False, indent=2))


if __name__ == "__main__":
    main()
