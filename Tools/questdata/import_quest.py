#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""import_quest — 任务落地客户端（dbeditor POST /api/quest_apply）。

用法（mir3-venv）：
    Tools/questdata/import_quest.py samples/M3M_EP1_CONVERGE.json [--dry-run] [--url ...]

职责：读任务 JSON（手写样板或后续由 manifest 生成）→ POST dbeditor。
服务端负责全部校验（前置任务/物品/区域/怪物/NPC 存在、任务名冲突、枚举合法），
校验通过才写工作区 + git commit；同步到 System.db 仍由用户在 dbeditor 点「同步」。

任务 JSON 格式（quest_apply 载荷，snake_case）：
    {"quests": [{
        "quest_name": "望海楼之约（战士）",     # 必填，库内唯一
        "quest_type": "Story",                 # QuestType 枚举
        "accept_text"/"progress_text"/"completed_text"/"archive_text": str,
        "start_npc": {"Index": 155},           # NPCInfo 引用
        "finish_npc": {"Index": 155},
        "requirements": [                      # 引擎 AND 语义
            {"requirement": "Class", "class": "Warrior"},
            {"requirement": "MinLevel", "int_parameter1": 13},
            {"requirement": "HaveCompleted",
             "quest_parameter": {"quest_name": "M3M_PW4_MINERESCUE"}}],
        "tasks": [                             # 仅 KillMonster/GainItem/VisitRegion
            {"task": "VisitRegion", "region_parameter": {"Index": 1766},
             "amount": 1, "mob_description": "…"},
            {"task": "KillMonster", "amount": 6, "mob_description": "…",
             "monster_details": [{"monster": {"Index": 29}, "chance": 1, "amount": 1}]}],
        "rewards": [                           # 只发物品（引擎约束）
            {"item": {"Index": 1}, "amount": 5000, "bound": true}]
    }]}
"""
from __future__ import annotations

import argparse
import json
import sys
from pathlib import Path

import requests

DEFAULT_URL = "http://127.0.0.1:8810"


def load_quests(paths: list[str]) -> list[dict]:
    quests: list[dict] = []
    for p in paths:
        data = json.loads(Path(p).read_text(encoding="utf-8"))
        if isinstance(data, dict) and "quests" in data:
            quests.extend(data["quests"])
        elif isinstance(data, list):
            quests.extend(data)
        elif isinstance(data, dict):
            quests.append(data)
    return quests


def main() -> int:
    ap = argparse.ArgumentParser(description="任务落地客户端（→ dbeditor quest_apply）")
    ap.add_argument("configs", nargs="+", help="任务 JSON（可多个）")
    ap.add_argument("--url", default=DEFAULT_URL, help=f"dbeditor 地址（默认 {DEFAULT_URL}）")
    ap.add_argument("--dry-run", action="store_true", help="只校验不写工作区")
    args = ap.parse_args()

    quests = load_quests(args.configs)
    if not quests:
        print("[!] 未读到任何任务定义", file=sys.stderr)
        return 1
    print(f"[*] 载入 {len(quests)} 个任务，POST {args.url}/api/quest_apply"
          + ("（dry-run）" if args.dry_run else ""))

    try:
        r = requests.post(f"{args.url}/api/quest_apply",
                          json={"quests": quests, "dry_run": args.dry_run},
                          timeout=120)
    except requests.ConnectionError as e:
        print(f"[!] 连不上 dbeditor（{args.url}）：{e}\n"
              f"    先启动: {Path(__file__).resolve().parent.parent / 'dbeditor' / 'app.py'}",
              file=sys.stderr)
        return 1

    body = r.json()
    if r.status_code != 200 or not body.get("ok"):
        print(f"[✗] 校验失败（{body.get('error_count', 0)} 处），已拒绝写入：")
        for e in body.get("errors", []):
            print(f"    - {e}")
        return 1

    tag = "would_apply" if body.get("dry_run") else "applied"
    for q in body.get(tag, []):
        print(f"[✓] {q['quest_name']} → QuestInfo#{q['quest_index']}"
              f"（req {q['requirements']} / task {q['tasks']} / reward {q['rewards']}）")
    if not body.get("dry_run"):
        print("[✓] 已写工作区并 git commit。下一步：dbeditor「同步到数据库」(sync.sh)。")
    return 0


if __name__ == "__main__":
    sys.exit(main())
