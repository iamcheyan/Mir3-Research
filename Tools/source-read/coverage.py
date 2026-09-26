#!/usr/bin/env python3
"""统计 CM_* 常量在服务端各分派层的覆盖情况。

服务端分派是**多层**的，只统计 GameServer 主 case 会得出错误差集
（例如 CM_FRIEND_EDIT/LIST 走 else 兜底 → UsrEngn 透传 → FriendSystem）。

层次（按数据流）：
  L1 GameServer/ObjBase.pas   主 case（TUserHuman.ProcessUserMessage）
  L2 GameServer/UsrEngn.pas   连接层前置过滤/透传
  L3 GameServer/UserMgr.pas   UserMgrEngine 二次分派
  L4 GameServer/FriendSystem.pas 等子系统内部 case
  L5 LoginServer/*/netlogingate.cpp   登录链路（C++ 表驱动）
  L6 DataBaseServer/DBSvr/netrungate.cpp 选角链路

用法: coverage.py [--json]
"""
from __future__ import annotations

import json
import os
import re
import sys

REPO = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
sys.path.insert(0, os.path.join(REPO, "Tools", "source-read"))
import read_src  # noqa: E402

SRC = os.path.join(REPO, "reference", "mir3-source", "Source")
TSV = os.path.join(REPO, "docs", "source-vs-reverse", "protocol-constants.tsv")

# 层定义: (标签, 相对路径, 提取模式说明)
LAYERS = [
    ("L1-ObjBase", "GameServer/ObjBase.pas"),
    ("L2-UsrEngn", "GameServer/UsrEngn.pas"),
    ("L3-UserMgr", "GameServer/UserMgr.pas"),
    ("L4-FriendSystem", "GameServer/FriendSystem.pas"),
    ("L4-Guild", "GameServer/Guild.pas"),
    ("L4-Castle", "GameServer/Castle.pas"),
    ("L4-Mission", "GameServer/Mission.pas"),
    ("L5-LoginGate", "LoginServer/LoginServer/netlogingate.cpp"),
    ("L5-LoginSvr", "LoginServer/LoginServer/netloginsvr.cpp"),
    ("L6-RunGate", "DataBaseServer/DBSvr/netrungate.cpp"),
    ("L6-DBServer", "DataBaseServer/DBSvr/netdbserver.cpp"),
]

# 提取所有 CM_ 出现（case 标签、逗号列表、表驱动项都算）
CM_RE = re.compile(r"\b(CM_[A-Z0-9_]+)\b")


def scan(rel: str) -> set[str]:
    path = os.path.join(SRC, rel)
    if not os.path.exists(path):
        return set()
    text, _ = read_src.read_text(path)
    found = set()
    for line in text.split("\n"):
        # 跳过纯注释行（避免把注释掉的常量算进来）
        stripped = line.strip()
        if stripped.startswith("//"):
            continue
        for m in CM_RE.finditer(line):
            found.add(m.group(1))
    return found


def main() -> int:
    # 客户端发出的 CM_ 全集
    cli = set()
    for fn in os.listdir(os.path.join(SRC, "Client")):
        if not fn.endswith(".pas"):
            continue
        text, _ = read_src.read_text(os.path.join(SRC, "Client", fn))
        for m in re.finditer(r"(?:MakeDefaultMsg|SendClientMessage|SendSocket)\s*\(?\s*(CM_[A-Z0-9_]+)", text):
            cli.add(m.group(1))

    per_layer = {tag: scan(rel) for tag, rel in LAYERS}

    # 合并 L1-L4（GameServer 侧全部）
    gs = set()
    for tag in per_layer:
        if tag.startswith(("L1", "L2", "L3", "L4")):
            gs |= per_layer[tag]

    # 合并 L5-L6（登录/选角链路）
    login = set()
    for tag in per_layer:
        if tag.startswith(("L5", "L6")):
            login |= per_layer[tag]

    all_srv = gs | login

    result = {
        "client_sends": len(cli),
        "server_game": len(gs),
        "server_login": len(login),
        "server_all": len(all_srv),
        "per_layer": {k: len(v) for k, v in per_layer.items()},
        "client_not_in_game": sorted(cli - gs),
        "client_not_in_login": sorted(cli - login),
        "client_nowhere": sorted(cli - all_srv),
        "server_game_only": sorted(gs - cli),
    }

    print(f"客户端发出的 CM_        : {result['client_sends']}")
    print(f"GameServer(L1-L4) 覆盖  : {result['server_game']}")
    print(f"登录/选角(L5-L6) 覆盖   : {result['server_login']}")
    print(f"服务端合计覆盖          : {result['server_all']}")
    print()
    print("分层明细:")
    for tag, _ in LAYERS:
        print(f"  {tag:20s} {len(per_layer[tag]):3d}")
    print()
    print(f"客户端发但 GameServer 无 : {len(result['client_not_in_game'])}")
    print(f"  {result['client_not_in_game']}")
    print()
    print(f"客户端发但登录链路也无   : {len(result['client_not_in_login'])}")
    print(f"  {result['client_not_in_login']}")
    print()
    print(f"客户端发但两层都无（异常）: {len(result['client_nowhere'])}")
    print(f"  {result['client_nowhere']}")
    print()
    print(f"GameServer 处理但客户端未发（服务端主动/内部）: {len(result['server_game_only'])}")
    print(f"  {result['server_game_only'][:40]}")

    if "--json" in sys.argv:
        out = os.path.join(REPO, "docs", "source-vs-reverse", "dispatch-coverage.json")
        with open(out, "w", encoding="utf-8") as f:
            json.dump(result, f, ensure_ascii=False, indent=2)
        print(f"\n已写 {os.path.relpath(out, REPO)}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
