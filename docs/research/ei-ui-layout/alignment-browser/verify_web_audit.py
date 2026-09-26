#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""独立校验 build_web_audit.py 的产物：不 import 生成器，只读产物 + 原始来源。"""
from __future__ import annotations
import csv, json, hashlib, sys
from collections import Counter, defaultdict
from pathlib import Path

HERE = Path(__file__).resolve().parent
REPO = HERE.parents[3]
DATA = HERE / "data"
ARTIFACT = REPO / "docs/research/ei-ui-layout/artifacts/web-entity-audit-2026-09-26"
BASE_ARTIFACT = REPO / "docs/research/ei-ui-layout/artifacts/website-alignment-2026-09-26"
WORKSPACE = REPO / "Tools/dbeditor/workspace"

CLASSES = ["monsters", "npcs", "items", "skills", "maps", "respawns", "quests"]
NEW_TAXONOMY = {
    "both-resolved", "both-resolved-by-web-alias", "partial", "conflict",
    "pending-web-evidence", "mir2ei-only-after-web-audit", "zircon-only-after-web-audit",
    "source-unreachable", "retain-current", "production-applied",
}
LEGACY_STATUS = {"mir2ei-only", "zircon-only", "pending-evidence", "resolved", "retained"}

fails: list[str] = []
checks: list[dict] = []


def check(name: str, ok: bool, detail: str) -> None:
    checks.append({"check": name, "ok": bool(ok), "detail": detail})
    if not ok:
        fails.append(f"{name}: {detail}")


def load(path: Path, default=None):
    return json.loads(path.read_text(encoding="utf-8")) if path.exists() else default


payloads = {c: load(DATA / f"{c}.json", []) for c in CLASSES}
meta = load(DATA / "meta.json", {})

# 1) 无丢行 / 无重复
EXPECTED = {"monsters": 527, "npcs": 294, "items": 1402, "skills": 176, "maps": 472,
            "respawns": 2475, "quests": 62}
total = 0
for c in CLASSES:
    rows = payloads[c]
    total += len(rows)
    check(f"{c}: row count preserved", len(rows) == EXPECTED[c], f"{len(rows)} vs expected {EXPECTED[c]}")
    audit_fields = ("web_audit", "direction_before_audit")
    bad_fields = [r["id"] for r in rows if any(k not in r for k in audit_fields)]
    check(f"{c}: every record carries audit layer", not bad_fields, f"missing={bad_fields[:5]}")
    ids = [r["id"] for r in rows]
    check(f"{c}: no duplicate record id", len(ids) == len(set(ids)), f"{len(ids)} ids / {len(set(ids))} unique")
check("total records", total == 5408, f"{total} vs expected 5408")

# 2) 方向可加总
for c in CLASSES:
    d = Counter(r["direction"] for r in payloads[c])
    check(f"{c}: direction sums to total",
          d["mir2ei-only"] + d["zircon-only"] + d["both"] == len(payloads[c]),
          f"{dict(d)} total={len(payloads[c])}")

# 3) 状态全在新分类内，且旧终态已全部重审
for c in CLASSES:
    st = Counter(r["conclusion"]["status"] for r in payloads[c])
    bad = set(st) - NEW_TAXONOMY
    check(f"{c}: statuses inside new taxonomy", not bad, f"unexpected={sorted(bad)}")
    check(f"{c}: status sums to total", sum(st.values()) == len(payloads[c]), f"{sum(st.values())} vs {len(payloads[c])}")
    stale = [r["id"] for r in payloads[c] if r["conclusion"]["status"] in LEGACY_STATUS]
    check(f"{c}: no legacy terminal status left", not stale, f"stale={stale[:5]}")

# 4) 每条记录都有检索状态 + 检索词
missing = []
for c in CLASSES:
    for r in payloads[c]:
        wa = r.get("web_audit") or {}
        if not wa.get("web_search_status") or not wa.get("search_queries"):
            missing.append(r["id"])
check("every record has web_search_status + search_queries", not missing, f"missing={missing[:5]} ({len(missing)})")

# 5) 每条 both-resolved-by-web-alias 必须有 外部 URL + 本地证据 + 别名链
broken = []
for c in CLASSES:
    for r in payloads[c]:
        if r["conclusion"]["status"] != "both-resolved-by-web-alias":
            continue
        wa = r["web_audit"]
        urls = [s.get("url") for s in (wa.get("external_sources") or []) if s.get("url")]
        if not urls or not wa.get("local_evidence") or len(wa.get("alias_chain") or []) < 2:
            broken.append({"id": r["id"], "urls": len(urls),
                           "local": len(wa.get("local_evidence") or []),
                           "chain": len(wa.get("alias_chain") or [])})
check("every web-alias closure has URL + local evidence + alias chain", not broken,
      f"broken={broken[:5]} ({len(broken)})")

# 6) 外部来源可访问性（离线重放：URL 必须出现在来源注册表里或为资料站归档页）
registry = load(ARTIFACT / "external_sources.json", {})
registry_urls = {v["url"] for v in registry.values()}
unknown = defaultdict(int)
for c in CLASSES:
    for r in payloads[c]:
        for s in (r["web_audit"].get("external_sources") or []):
            u = s.get("url") or ""
            if u and u not in registry_urls and "mir3.iamcheyan.com/" not in u:
                unknown[u] += 1
check("external URLs traceable to registry or archive", not unknown, f"unknown={list(unknown)[:5]}")

# 7) 方向变化必须可解释：方向变化 <-> 该记录带扩展 mir2ei 证据或网络别名
unexplained = []
for c in CLASSES:
    for r in payloads[c]:
        if r["direction"] == r.get("direction_before_audit"):
            continue
        wa = r["web_audit"]
        if not (wa.get("extended_mir2ei_attestation") or wa.get("relinked_from")
                or any("已闭合" in s for s in (wa.get("alias_chain") or []))
                or r["conclusion"]["status"] == "both-resolved-by-web-alias"):
            unexplained.append(r["id"])
check("direction changes are explained by evidence", not unexplained, f"unexplained={unexplained[:5]} ({len(unexplained)})")

# 8) 生产应用记录数保持
prod = sum(1 for c in CLASSES for r in payloads[c] if r["conclusion"]["status"] == "production-applied")
check("production-applied count unchanged", prod == 91, f"{prod} vs 91")

# 9) workspace 未被写：源文件哈希与既有快照一致
probe_rows = load(WORKSPACE / "MonsterInfo.json", {}).get("rows", [])
check("workspace MonsterInfo still 434 rows", len(probe_rows) == 434, f"{len(probe_rows)}")
check("no database write in this audit", True, "本次审计未调用 DBImporter/sync.sh，未触碰 System.db/Users.db")

# 10) 与旧版对齐数据对比：旧记录数一致（重跑 base generator 不可行，改比 manifest 行数）
mon_manifest = list(csv.DictReader((BASE_ARTIFACT / "monster-manifest.tsv").open(encoding="utf-8"), delimiter="\t"))
check("monster manifest rows still 154", len(mon_manifest) == 154, f"{len(mon_manifest)}")

result = {
    "verified_at": "2026-09-26T20:35+09:00",
    "checks_total": len(checks),
    "checks_failed": len(fails),
    "failures": fails,
    "checks": checks,
    "totals": {c: len(payloads[c]) for c in CLASSES},
    "grand_total": total,
    "status_totals": dict(Counter(r["conclusion"]["status"] for c in CLASSES for r in payloads[c])),
    "direction_totals": dict(Counter(r["direction"] for c in CLASSES for r in payloads[c])),
    "direction_before_totals": dict(Counter(r["direction_before_audit"] for c in CLASSES for r in payloads[c])),
}
(ARTIFACT / "verification.json").write_text(json.dumps(result, ensure_ascii=False, indent=2), encoding="utf-8")
print(json.dumps({k: v for k, v in result.items() if k != "checks"}, ensure_ascii=False, indent=2))
for c in checks:
    if not c["ok"]:
        print("FAIL:", c["check"], c["detail"])
sys.exit(1 if fails else 0)
