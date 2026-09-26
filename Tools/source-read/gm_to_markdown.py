#!/usr/bin/env python3
"""GM 命令表 → Markdown（供 server.md 引用）。

读 docs/source-vs-reverse/gm-commands.tsv，按动作类型分组输出。
"""
from __future__ import annotations

import csv
import os
import sys

REPO = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
TSV = os.path.join(REPO, "docs", "source-vs-reverse", "gm-commands.tsv")

# 按动作关键词归类
GROUPS = [
    ("移动/传送", ["Move", "Goto", "Recall", "PMove", "PositionMove", "Teleport", "Backstep", "이동", "소환", "맵소환", "캐릭터이동", "맵"]),
    ("刷怪/清理", ["Mob", "MonClear", "KingMob", "MobPlace", "RecallMob", "몹", "몬클리어", "왕몹", "탐색"]),
    ("等级/经验/点数", ["Level", "Exp", "Adjust", "LuckyPoint", "ContestPoint", "PKpoint", "IncPkPoint", "Training", "Hunger", "레벨", "렙", "내공", "명성", "운"]),
    ("物品/装备", ["Item", "Make", "DeleteItem", "Upgrade", "Dura", "Gift", "모든보옥", "모든신주", "무기제련", "복권"]),
    ("金币", ["Gold", "골드"]),
    ("行会/攻城", ["Guild", "Agit", "Sabuk", "Wallconquest", "문파", "장원", "사북성문", "동맹", "문원"]),
    ("聊天/禁言", ["Shutup", "Chat", "Whisper", "Cry", "Abuse", "채금", "귓속말", "귀엣말", "외치기", "차단", "교환거부", "줄공지"]),
    ("状态/外观", ["Superman", "Observer", "Stealth", "Transparency", "Gender", "Job", "Fame", "NameColor", "글자색", "무적", "감시자", "스텔스", "운영자", "부활", "Alive", "생일", "만남", "연인"]),
    ("任务", ["Mission", "Diary", "Quest", "퀘스트", "일지"]),
    ("GM/管理", ["Admin", "GameMaster", "Reload", "Ting", "Kick", "ReadAbuse", "Gsa", "setflag", "setopen", "setunit", "showopen", "showunit", "flag", "safezone", "attack", "whoare", "addfriend", "추방", "팅", "휴식", "출두", "누구", "친구등록"]),
    ("测试/调试", ["CMDTEST", "TESTTIME", "Debug", "Level0", "AdjustTestLevel", "DisableFilter"]),
]


def classify(row: dict) -> str:
    blob = (row["english"] + " " + row["korean_aliases"])
    for name, keys in GROUPS:
        for k in keys:
            if k.lower() in blob.lower():
                return name
    return "其他"


def main() -> int:
    rows = list(csv.DictReader(open(TSV, encoding="utf-8"), delimiter="\t"))
    by = {}
    for r in rows:
        by.setdefault(classify(r), []).append(r)

    print(f"# GM 命令表（{len(rows)} 个分派块）\n")
    for name, _ in GROUPS + [("其他", [])]:
        items = by.get(name)
        if not items:
            continue
        print(f"## {name}（{len(items)}）\n")
        print("| 行 | 英文命令 | 韩文别名 | 动作 |")
        print("|---|---|---|---|")
        for r in items:
            print(f"| {r['line']} | {r['english'] or '—'} | {r['korean_aliases'] or '—'} | {r['handler'] or '—'} |")
        print()
    return 0


if __name__ == "__main__":
    sys.exit(main())
