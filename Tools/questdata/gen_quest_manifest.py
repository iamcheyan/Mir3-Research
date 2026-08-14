#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""gen_quest_manifest.py —— 341 个设计任务的机器可读清单（D2）。

来源（六篇文档 + 04 环表）：
  - 07-任务总表：M3M 44 + M3K 简单 26 + M3S 57 + M3P 16（行级表）
  - 04-技能觉醒：25 条史诗链的环级表（M3K_*_C1~CN，198 环）
  - 02/03/05 字段表（| 字段 | 值 |）：前置任务/等级/接取/交付/情感节点 增强
  - 02/03/04/05/12 的两难表：任务 → D/K/S 编号

每任务字段：id/名称/类型/职业线/等级段/环数/前置任务id/涉及NPC/涉及地图/
涉及怪物/涉及物品/奖励/情感点/两难抉择。缺失=null（绝不编造）；
解析不了的行进 parse_errors。

绑定：D1 semantic_map 把中文名尝试绑 DB Index（绑不上=index null + confidence 0）。

运行：/home/tetsuya/mir3-venv/bin/python Tools/questdata/gen_quest_manifest.py
"""
from __future__ import annotations

import json
import re
import sys
from collections import Counter
from pathlib import Path

HERE = Path(__file__).resolve().parent
sys.path.insert(0, str(HERE))
from gen_semantic_map import (  # noqa: E402
    QD, RE_GAIN, RE_KILL, RE_VISIT, SemanticMap, has_zh,
)

REPO = HERE.parent.parent
OUT_JSON = QD / "data" / "quest_manifest.json"
OUT_REPORT = QD / "data" / "quest_manifest_report.md"

QUEST_ID_RE = re.compile(r"M3[MSKP]_[A-Z0-9_]+")
# 环号中文数字 → 序号
RING_NUM = {"一": 1, "二": 2, "三": 3, "四": 4, "五": 5,
            "六": 6, "七": 7, "八": 8, "九": 9, "十": 10}

# 04 环表步骤用英文动作词：①KillMonster 火焰沃玛 ×6；①VisitRegion 祖玛神殿一层·塔门
RE_KILL_EN = re.compile(r"KillMonster\s*([^×;；,，)）(（\s]+?)\s*[×x]\s*(\d+)")
RE_VISIT_SUFFIX = re.compile(r"([^;；,，。、/|｜:：（(\s][^;；,，。/|｜:：（()）\s]*?)\s*VisitRegion")

DOC_TITLES = {
    "02": "02-主线任务详解-三线序章.md",
    "03": "03-主线任务详解-共享主线.md",
    "04": "04-主线任务详解-技能觉醒.md",
    "05": "05-副线任务详解.md",
    "07": "07-任务总表.md",
    "11": "11-多人任务详解.md",
    "12": "12-剧情大纲速览.md",
}

# ---------------------------------------------------------------- 通用表格解析


def md_tables(text: str) -> list[tuple[list[str], list[list[str]]]]:
    """markdown 文本 → [(表头, 数据行)...]。表头=第一条 | 行，跳过 |---| 分隔。"""
    tables: list[tuple[list[str], list[list[str]]]] = []
    cur: list[list[str]] = []
    for line in text.splitlines():
        s = line.strip()
        if s.startswith("|") and s.endswith("|"):
            cells = [c.strip() for c in s.strip("|").split("|")]
            if all(re.fullmatch(r":?-{2,}:?", c) for c in cells if c):
                continue
            cur.append(cells)
        else:
            if len(cur) >= 2:
                tables.append((cur[0], cur[1:]))
            cur = []
    if len(cur) >= 2:
        tables.append((cur[0], cur[1:]))
    return tables


def norm_header(h: str) -> str:
    return re.sub(r"[\s　]", "", h)


def find_col(headers: list[str], *names: str) -> int | None:
    """先精确匹配；再按包含匹配（如「步骤（QuestTaskType/参数/Chance）」含「步骤」）。"""
    want = [norm_header(n) for n in names]
    for i, h in enumerate(headers):
        nh = norm_header(h)
        if nh in want:
            return i
    for i, h in enumerate(headers):
        nh = norm_header(h)
        for w in want:
            if w and w in nh:
                return i
    return None


# ---------------------------------------------------------------- 实体抽取/绑定

class Binder:
    def __init__(self, sm: SemanticMap) -> None:
        self.sm = sm

    def bind(self, table: str, term: str) -> dict | None:
        term = (term or "").strip().rstrip("·").strip()
        if not term or not has_zh(term):
            return None          # 纯符号/数量片段（如「×2」）不是名词
        e = self.sm.lookup(table, term)
        if e is None:
            return {"zh": term, "Index": None, "Name": None, "confidence": 0.0}
        return {"zh": term, "Index": e["Index"], "Name": e["Name"],
                "confidence": e["confidence"]}

    def extract_kills(self, text: str) -> list[dict]:
        pats = list(RE_KILL.finditer(text)) + list(RE_KILL_EN.finditer(text))
        return [b for b in (self.bind("monsters", m.group(1)) for m in pats) if b]

    def extract_gains(self, text: str) -> list[dict]:
        return [b for b in (self.bind("items", m.group(1))
                            for m in RE_GAIN.finditer(text)) if b]

    def extract_rewards(self, text: str) -> list[dict]:
        """奖励列的「物品名×N」（金/声望/称号等非物品除外）。"""
        out = []
        for m in re.finditer(r"([一-龥A-Za-z0-9·（）()]+?)\s*[×x]\s*\d+", text or ""):
            term = m.group(1).strip()
            if re.fullmatch(r"(金|金币|声望|狩猎币|经验|行会声望|同心值|★+)", term):
                continue
            b = self.bind("items", term)
            if b:
                out.append(b)
        return out

    def extract_visits(self, text: str) -> tuple[list[dict], list[dict]]:
        """两种写法都收：①VisitRegion 沃玛神殿三层·X（前缀）/ 毒蛇山谷 VisitRegion（后缀）。"""
        raws = [m.group(1) for m in RE_VISIT.finditer(text)]
        raws += [m.group(1) for m in RE_VISIT_SUFFIX.finditer(text)]
        maps_, regions = [], []
        for raw in raws:
            b = self.bind("maps", raw.split("·")[0])
            if b:
                maps_.append(b)
            b = self.bind("regions", raw)
            if b:
                regions.append(b)
        return maps_, regions


def dedup(seq: list[dict]) -> list[dict]:
    out: list[dict] = []
    seen: set[tuple] = set()
    for e in seq:
        if not e:
            continue
        k = (e.get("zh"), e.get("Index"), e.get("Name"))
        if k in seen:
            continue
        seen.add(k)
        out.append(e)
    return out


# ---------------------------------------------------------------- 各文档解析

def class_line_of(qid: str, hint: str | None = None) -> str | None:
    if hint:
        if "战士" in hint:
            return "战士"
        if "法师" in hint:
            return "法师"
        if "道士" in hint:
            return "道士"
        if "任意" in hint or "行会" in hint or "多人" in hint:
            return "通用"
    if "_PW" in qid:
        return "战士"
    if "_PM" in qid:
        return "法师"
    if "_PT" in qid:
        return "道士"
    if qid.startswith("M3K_WAR"):
        return "战士"
    if qid.startswith("M3K_MAG"):
        return "法师"
    if qid.startswith("M3K_TAO"):
        return "道士"
    if "_PRE_WAR" in qid:
        return "战士"
    if "_PRE_MAG" in qid:
        return "法师"
    if "_PRE_TAO" in qid:
        return "道士"
    if "_PRE_ALL" in qid:
        return "通用"
    return None


def quest_type_default(qid: str, explicit: str | None) -> str | None:
    if explicit:
        m = re.search(r"(Story|Daily|Weekly|Repeatable|General|Account)", explicit)
        if m:
            return m.group(1)
        for zh, en in (("每日", "Daily"), ("周常", "Weekly"), ("可重复", "Repeatable"),
                       ("剧情", "Story"), ("一次性", "Story")):
            if zh in explicit:
                return en
    if qid.startswith(("M3M_", "M3K_")):
        return "Story"
    return None


def parse_07(quests: dict[str, dict], errors: list[str]) -> None:
    text = (QD / DOC_TITLES["07"]).read_text(encoding="utf-8")
    for headers, rows in md_tables(text):
        id_col = find_col(headers, "ID", "任务 ID", "链 ID 前缀")
        if id_col is None:
            continue
        # -- 技能总表（| 技能 | 等级 | 任务形态 | 已学处理 | 任务 ID |）无行级
        #    任务数据，跳过（明细表才是行级来源）
        if find_col(headers, "任务形态") is not None:
            continue
        # -- 环级行表（| 环 | 环名 | ID | 步骤 | ...）在 parse_04 处理
        if find_col(headers, "环名") is not None:
            continue
        # -- 史诗链汇总表（| 链 ID 前缀 | 技能 | 等级 | 环数 | ...）
        if norm_header(headers[0]) == "链ID前缀":
            for r in rows:
                if len(r) <= max(find_col(headers, "环数") or 0, id_col or 0):
                    errors.append(f"07 链汇总行残缺: {r}")
                    continue
                prefix = QUEST_ID_RE.search(r[id_col])
                if not prefix:
                    errors.append(f"07 链汇总无 ID: {r}")
                    continue
                skill_col = find_col(headers, "技能")
                lvl_col = find_col(headers, "等级")
                ring_col = find_col(headers, "环数")
                quests[f"__chain__{prefix.group(0)}"] = {
                    "chain_prefix": prefix.group(0),
                    "skill": r[skill_col] if skill_col is not None else None,
                    "level": r[lvl_col] if lvl_col is not None else None,
                    "rings": int(re.search(r"\d+", r[ring_col]).group(0)) if ring_col is not None else None,
                }
            continue
        # -- 行级任务表：必须有名称列与步骤/奖励列，防把总表当明细
        name_col = find_col(headers, "名称", "任务名")
        step_col = find_col(headers, "关键步骤", "步骤")
        reward_col = find_col(headers, "奖励")
        if name_col is None or (step_col is None and reward_col is None):
            continue
        type_col = find_col(headers, "类型")
        lvl_col = find_col(headers, "等级")
        start_col = find_col(headers, "接取NPC", "接取")
        finish_col = find_col(headers, "交任务NPC", "交付NPC")
        branch_col = find_col(headers, "分支")
        skill_col = find_col(headers, "技能")
        cls_col = find_col(headers, "职业建议")
        boss_col = find_col(headers, "BOSS/目标")
        map_col = find_col(headers, "地图")
        for r in rows:
            if len(r) < 2:
                continue
            m = QUEST_ID_RE.search(r[id_col] if id_col < len(r) else "")
            if not m:
                continue
            qid = m.group(0)
            if qid in quests:
                errors.append(f"07 重复任务行: {qid}")
            g = lambda c: (r[c] if c is not None and c < len(r) else "") or ""
            quests[qid] = {
                "id": qid,
                "name": g(name_col) or None,
                "type": quest_type_default(qid, g(type_col)),
                "source": "07-任务总表",
                "_start_npc_raw": g(start_col),
                "_finish_npc_raw": g(finish_col),
                "_steps_raw": g(step_col) + ("；" + g(boss_col) if boss_col is not None else ""),
                "_map_raw": g(map_col),
                "_reward_raw": g(reward_col),
                "_branch_raw": g(branch_col),
                "_skill_raw": g(skill_col),
                "_class_hint": g(cls_col) or None,
                "level_range": g(lvl_col) or None,
            }


def parse_04_rings(quests: dict[str, dict], chains: dict, errors: list[str]) -> None:
    text = (QD / DOC_TITLES["04"]).read_text(encoding="utf-8")
    sec_re = re.compile(
        r"^###\s+\d+\.\d+\s+(.+?)（(M3K_[A-Z_]+?)(?:，(\d+)\s*环史诗链)?）", re.M)
    sections = list(sec_re.finditer(text))
    for i, m in enumerate(sections):
        end = sections[i + 1].start() if i + 1 < len(sections) else len(text)
        body = text[m.end():end]
        prefix, is_epic = m.group(2), bool(m.group(3))
        # 字段表（| 字段 | 值 |）
        fields: dict[str, str] = {}
        for headers, rows in md_tables(body):
            if headers and norm_header(headers[0]) == "字段":
                for r in rows:
                    if len(r) >= 2:
                        fields[r[0].strip()] = r[1].strip()
        prev_raw = fields.get("前置条件", "")
        prev = QUEST_ID_RE.findall(prev_raw)
        emotion = fields.get("情感节点")
        # 环级表（| 环 | 环名 | ID | 步骤 | 完成条件 | 奖励 |）
        ring_tbl = None
        for headers, rows in md_tables(body):
            if headers and find_col(headers, "环名") is not None \
                    and find_col(headers, "ID") is not None:
                ring_tbl = (headers, rows)
                break
        if not is_epic or ring_tbl is None:
            if not is_epic and prefix in quests:
                # 简单觉醒：字段表增强（前置/情感）
                q = quests[prefix]
                q["prev_quests"] = prev or q.get("prev_quests")
                q["emotion_points"] = emotion or q.get("emotion_points")
            continue
        headers, rows = ring_tbl
        id_col = find_col(headers, "ID")
        name_col = find_col(headers, "环名")
        step_col = find_col(headers, "步骤", "QuestTaskType/参数/Chance")
        reward_col = find_col(headers, "奖励")
        cond_col = find_col(headers, "完成条件")
        for r in rows:
            mid = QUEST_ID_RE.search(r[id_col] if id_col < len(r) else "")
            if not mid:
                errors.append(f"04 环表行无 ID（{prefix}）: {r[:3]}")
                continue
            qid = mid.group(0)
            g = lambda c: (r[c] if c is not None and c < len(r) else "") or ""
            quests[qid] = {
                "id": qid,
                "name": g(name_col) or None,
                "type": "Story",
                "source": "04-技能觉醒·史诗链环表",
                "level_range": re.search(r"\d+", (chains.get(prefix) or {}).get("level") or
                                         fields.get("技能/等级") or "").group(0)
                if re.search(r"\d+", (chains.get(prefix) or {}).get("level") or
                             fields.get("技能/等级") or "") else None,
                "chain": {"prefix": prefix,
                          "ring": RING_NUM.get(r[0].strip()),
                          "rings": int(m.group(3))},
                "prev_quests": prev,       # C1 前置=链前置；C2+ 运行时补
                "_steps_raw": g(step_col) + ("；" + g(cond_col) if cond_col else ""),
                "_reward_raw": g(reward_col),
                "_skill_raw": (chains.get(prefix) or {}).get("skill") or m.group(1),
                "emotion_points": emotion,
            }


def parse_field_tables(quests: dict[str, dict], doc_key: str, errors: list[str]) -> None:
    """02/03/05 的 | 字段 | 值 | 分节增强：前置任务/等级/接取/交付/情感。"""
    text = (QD / DOC_TITLES[doc_key]).read_text(encoding="utf-8")
    for sec in re.split(r"^###\s+", text, flags=re.M)[1:]:
        title, _, body = sec.partition("\n")
        ids = QUEST_ID_RE.findall(title)
        fields: dict[str, str] = {}
        for headers, rows in md_tables(body):
            if headers and norm_header(headers[0]) == "字段":
                for r in rows:
                    if len(r) >= 2:
                        fields[r[0].strip()] = r[1].strip()
        if not fields:
            continue
        prev = None
        for k, v in fields.items():
            if "前置" in k:
                found = QUEST_ID_RE.findall(v)
                if found:
                    prev = found
                elif "无" in v:
                    prev = []
        for qid in ids:
            q = quests.get(qid)
            if q is None:
                continue
            if prev is not None and not q.get("prev_quests"):
                q["prev_quests"] = prev
            if fields.get("等级") and not q.get("level_range"):
                q["level_range"] = fields["等级"]
            if not q.get("emotion_points"):
                for k, v in fields.items():
                    if "情感" in k:
                        q["emotion_points"] = v
            # 接取/交付 NPC（02/03/05 字段表比 07 更全）
            for key, tag in (("接取NPC", "_start_npc_raw"), ("交付NPC", "_finish_npc_raw")):
                v = fields.get(key)
                if v and not q.get(tag):
                    q[tag] = v


def parse_dilemmas(quests: dict[str, dict]) -> dict[str, str]:
    """两难表：| 任务ID | D4 ... | 或 | D1 | ...（M3M_PW1）... | → quest → D 编号。"""
    out: dict[str, str] = {}
    for doc in ("02", "03", "04", "05", "12"):
        p = QD / DOC_TITLES[doc]
        if not p.exists():
            continue
        text = p.read_text(encoding="utf-8")
        # 形式1：| M3M_EP1_CONVERGE | D4 信还是半信半疑 | ...
        for m in re.finditer(r"^\|\s*(M3[MSKP]_[A-Z0-9_]+)\s*\|\s*([DKS]\d+)", text, re.M):
            out.setdefault(m.group(1), m.group(2))
        # 形式2：| D1 | 序章·战士线初级任务（M3M_PW1）：...
        for m in re.finditer(r"^\|\s*([DKS]\d+)\s*\|[^|\n]*?（(M3[MSKP]_[A-Z0-9_]+)）", text, re.M):
            out.setdefault(m.group(2), m.group(1))
    for qid, d in out.items():
        if qid in quests:
            quests[qid]["dilemma"] = d
    return out


# ---------------------------------------------------------------- NPC 解析

RE_NPC_SPLIT = re.compile(r"[；;/、]")


def parse_npc_cell(cell: str, binder: Binder) -> list[dict]:
    """「镖局师傅·赵四海（比奇）」→ [{zh:镖局师傅·赵四海, ...}]；多 NPC 拆分。"""
    if not cell:
        return []
    out = []
    for part in RE_NPC_SPLIT.split(cell):
        part = part.strip()
        if not part or not has_zh(part):
            continue
        # 去掉括号备注（地点/条件）
        name = re.sub(r"（[^）]*）|\([^)]*\)", "", part).strip().rstrip("·")
        if not name:
            continue
        b = binder.bind("npcs", name)
        if b:
            out.append(b)
    return out


# ---------------------------------------------------------------- 主流程

def finalize(quests: dict[str, dict], binder: Binder) -> None:
    # 链内前置补全：C2+ 的前置 = C1..C(N-1) 中的 C(i-1)
    by_prefix: dict[str, list[dict]] = {}
    for q in quests.values():
        if isinstance(q.get("chain"), dict):
            by_prefix.setdefault(q["chain"]["prefix"], []).append(q)
    for prefix, rings in by_prefix.items():
        rings.sort(key=lambda q: (q["chain"]["ring"] or 0))
        for i, q in enumerate(rings):
            if i == 0:
                continue
            q["prev_quests"] = [rings[i - 1]["id"]]

    for q in quests.values():
        if not isinstance(q.get("id"), str) or q["id"].startswith("__chain__"):
            continue
        npcs = parse_npc_cell(q.pop("_start_npc_raw", "") or "", binder)
        npcs += parse_npc_cell(q.pop("_finish_npc_raw", "") or "", binder)
        steps = q.pop("_steps_raw", "") or ""
        map_raw = q.pop("_map_raw", "") or ""
        monsters = binder.extract_kills(steps)
        reward_raw = q.pop("_reward_raw", "") or ""
        items = binder.extract_gains(steps)
        items += binder.extract_rewards(reward_raw)
        maps_, regions = binder.extract_visits(steps)
        if map_raw:
            b = binder.bind("maps", map_raw.split("（")[0])
            if b:
                maps_.append(b)
        q.pop("_branch_raw", None)
        q.pop("_skill_raw", None)
        q.pop("_class_hint", None)
        q["npcs"] = dedup(npcs)
        q["maps"] = dedup(maps_)
        q["monsters"] = dedup(monsters)
        q["items"] = dedup(items)
        q["regions"] = dedup(regions)
        q["rewards_raw"] = reward_raw or None
        q.setdefault("name", None)
        q.setdefault("type", None)
        q.setdefault("level_range", None)
        q.setdefault("prev_quests", None)
        q.setdefault("emotion_points", None)
        q.setdefault("dilemma", None)
        q.setdefault("chain", None)
        q["rings"] = (q["chain"] or {}).get("rings") if q.get("chain") else 1
        q["class_line"] = class_line_of(q["id"], None)


FIELDS = ["id", "name", "type", "class_line", "level_range", "rings",
          "prev_quests", "npcs", "maps", "monsters", "items",
          "rewards_raw", "emotion_points", "dilemma"]


def main() -> None:
    sm = SemanticMap()
    binder = Binder(sm)
    quests: dict[str, dict] = {}
    errors: list[str] = []

    parse_07(quests, errors)
    chains = {v["chain_prefix"]: v for k, v in quests.items()
              if k.startswith("__chain__")}
    for k in list(quests):
        if k.startswith("__chain__"):
            del quests[k]
    parse_04_rings(quests, chains, errors)
    parse_field_tables(quests, "02", errors)
    parse_field_tables(quests, "03", errors)
    parse_field_tables(quests, "05", errors)
    dilemmas = parse_dilemmas(quests)

    finalize(quests, binder)

    by_prefix = Counter(q["id"].split("_")[0] + "_" for q in quests.values())
    # 字段完整度矩阵
    matrix = {f: sum(1 for q in quests.values() if q.get(f) not in (None, [], ""))
              for f in FIELDS}
    core_ok = sum(1 for q in quests.values()
                  if all(q.get(f) not in (None, "", []) for f in
                         ("id", "name", "type", "level_range", "rings")))
    # 绑定率
    def bind_rate(field: str) -> tuple[int, int]:
        tot = hit = 0
        for q in quests.values():
            for e in q.get(field) or []:
                tot += 1
                if e.get("Index") is not None:
                    hit += 1
        return hit, tot

    data = {
        "quests": sorted(quests.values(), key=lambda q: q["id"]),
        "stats": {
            "total": len(quests),
            "by_prefix": dict(by_prefix),
            "target": {"M3M_": 44, "M3K_": 224, "M3S_": 57, "M3P_": 16,
                       "total": 341},
            "field_completeness": matrix,
            "core_fields_ok": core_ok,
            "parse_errors": len(errors),
            "dilemma_bound": len(dilemmas),
            "binding": {f: bind_rate(f) for f in ("npcs", "maps", "monsters", "items", "regions")},
        },
        "parse_errors": errors,
        "meta": {
            "generated_by": "Tools/questdata/gen_quest_manifest.py",
            "sources": [DOC_TITLES[k] for k in ("02", "03", "04", "05", "07", "12")],
        },
    }
    OUT_JSON.write_text(json.dumps(data, ensure_ascii=False, indent=1), encoding="utf-8")

    # ---------------- 报告
    lines = [
        "# quest_manifest 生成报告", "",
        f"- 输出：`{OUT_JSON.relative_to(REPO)}`",
        f"- 任务总数：**{len(quests)}/341**（验收线 ≥330）",
        f"- 分布：" + "、".join(f"{k} {v}" for k, v in sorted(by_prefix.items())),
        f"- 核心五字段（id/名称/类型/等级段/环数）齐全：**{core_ok}/{len(quests)}**",
        f"- 两难绑定：{len(dilemmas)} 个任务",
        f"- parse_errors：{len(errors)}",
        "", "## 字段完整度矩阵", "",
        "| 字段 | 非空数 | 占比 |", "|---|---|---|",
    ]
    for f in FIELDS:
        n = matrix[f]
        lines.append(f"| {f} | {n} | {round(n / len(quests) * 100, 1)}% |")
    lines += ["", "## DB 绑定率（semantic_map）", "",
              "| 字段 | 绑上 Index | 总提及 | 绑定率 |", "|---|---|---|---|"]
    for f in ("npcs", "maps", "monsters", "items", "regions"):
        hit, tot = bind_rate(f)
        pct = round(hit / tot * 100, 1) if tot else 0
        lines.append(f"| {f} | {hit} | {tot} | {pct}% |")
    if errors:
        lines += ["", "## parse_errors（人工复核）", ""]
        lines += [f"- {e}" for e in errors[:50]]
    OUT_REPORT.write_text("\n".join(lines), encoding="utf-8")

    print(f"[ok] {OUT_JSON.relative_to(REPO)} ({OUT_JSON.stat().st_size} bytes)")
    print(f"[ok] {OUT_REPORT.relative_to(REPO)}")
    print(f"  任务: {len(quests)}/341  分布: {dict(by_prefix)}")
    print(f"  核心五字段齐全: {core_ok}  parse_errors: {len(errors)}")
    for f in ("npcs", "maps", "monsters", "items", "regions"):
        hit, tot = bind_rate(f)
        print(f"  绑定 {f}: {hit}/{tot}")


if __name__ == "__main__":
    main()
