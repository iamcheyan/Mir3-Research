#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""build_wiki_images.py — 生成 /tmp/wiki_images.json (各板块条目 -> 图库/帧 映射)。

数据源:
  - GodotClient/Formats/MonsterLookup.cs  怪物枚举 -> (LibraryFile, shape)
  - /tmp/wiki_all.json (DbMigrationTool dump-all)  怪物/物品/NPC 的 Image 字段

输出 /tmp/wiki_images.json:
  {
    "monsters": { "Chicken": "Chicken" },        # 显示名 -> 枚举名 (ver_tags 用)
    "items":    { "Wood Sword": 126 },           # ItemName -> StoreItem.wil 帧号
    "skills":   { "Fencing": 0 },                # SkillName -> MIcon.wil 帧号
    "npcs":     { "Mr. Kang": {"image": 0, "face": 0} },  # NPCName -> NPC.Zl/NPCface.Zl 帧
    "companions": { "Chicken": {...} }           # 怪物名 -> 价格/可用 (CompanionInfo)
  }
"""
import json
import os
import re
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
ZIRCON = "/home/tetsuya/development/Zircon" if os.path.isdir("/home/tetsuya/development/Zircon") else ROOT
ALL = sys.argv[1] if len(sys.argv) > 1 else "/tmp/wiki_all.json"
OUT = sys.argv[2] if len(sys.argv) > 2 else "/tmp/wiki_images.json"

# ---------------- 0. 枚举数字 -> 枚举名 (Enum.cs MonsterImage) ----------------
ENUM_CS = os.path.join(ZIRCON, "LibraryCore", "Enum.cs")
enum_num_name = {}   # 数字 -> 枚举名
if os.path.exists(ENUM_CS):
    txt = open(ENUM_CS, encoding="utf-8").read()
    # 在 enum MonsterImage { ... } 块内: 名字 = 数字,
    m = re.search(r"enum MonsterImage\s*{(.*?)}", txt, re.S)
    if m:
        body = m.group(1)
        num = 0
        for line in body.splitlines():
            line = line.split("//")[0].strip()
            if not line:
                continue
            mm = re.match(r"(\w+)\s*(?:=\s*(\d+))?\s*,?\s*$", line)
            if mm:
                name = mm.group(1)
                if mm.group(2):
                    num = int(mm.group(2))
                if not name.startswith("NF_") and name != "None":
                    enum_num_name[num] = name
                num += 1
    print(f"Enum.cs MonsterImage: {len(enum_num_name)} 枚举数字映射")

# ---------------- 1. 怪物: MonsterLookup.cs 枚举 -> (lib, shape) ----------------
LOOKUP = os.path.join(ZIRCON, "GodotClient", "Formats", "MonsterLookup.cs")
mon_enum_lib = {}   # 枚举名 -> {"lib": "Mon-N.wil", "shape": N}
if os.path.exists(LOOKUP):
    txt = open(LOOKUP, encoding="utf-8").read()
    # 提取 "MonsterImage.Name, (LibraryFile.Mon_N, shape)"
    for m in re.finditer(
            r"MonsterImage\.(\w+),\s*\(LibraryFile\.(\w+),\s*(\d+)\)", txt):
        enum_name, lib_enum, shape = m.group(1), m.group(2), int(m.group(3))
        # LibraryFile.Mon_3 -> Mon-3.wil; CastleFlag 特例
        if lib_enum == "CastleFlag":
            lib = "CastleFlag.wil"
        elif lib_enum.startswith("Mon_"):
            lib = f"Mon-{lib_enum[4:]}.wil"
        else:
            continue
        mon_enum_lib[enum_name] = {"lib": lib, "shape": shape, "frame": 40 + shape * 1000}
    print(f"MonsterLookup: {len(mon_enum_lib)} 枚举映射")

# ---------------- 2. 载入 dump-all ----------------
d = json.load(open(ALL, encoding="utf-8"))
rows = lambda t: d.get(t, {}).get("rows", [])

# 怪物: MonsterName + Image(枚举名)
mon_img = {}      # MonsterName -> 枚举名
for r in rows("MonsterInfo"):
    img = r.get("Image")
    if isinstance(img, int):
        img = enum_num_name.get(img, img)
    mon_img[r.get("MonsterName")] = img

# 物品: ItemName -> Image 帧号
item_img = {}
for r in rows("ItemInfo"):
    item_img[r.get("ItemName")] = r.get("Image")

# NPC: NPCName -> {image, face}
npc_img = {}
for r in rows("NPCInfo"):
    npc_img[r.get("NPCName")] = {"image": r.get("Image"), "face": r.get("FaceImage")}

# 技能: MagicInfo -> {Name, Icon}
skill_img = {}
for r in rows("MagicInfo"):
    skill_img[r.get("Name")] = r.get("Icon")

# 宠物坐骑: CompanionInfo -> {Monster, Price, Available}
comp = {}
for r in rows("CompanionInfo"):
    comp[r.get("Monster") or r.get("Name")] = {
        "price": r.get("Price"),
        "available": r.get("Available"),
    }

out = {
    "monsters": mon_img,
    "items": item_img,
    "skills": skill_img,
    "npcs": npc_img,
    "companions": comp,
    "mon_enum_lib": mon_enum_lib,
    "_meta": {"script": "build_wiki_images.py"},
}
json.dump(out, open(OUT, "w", encoding="utf-8"), ensure_ascii=False)
print(f"输出 {OUT}: 怪物 {len(mon_img)} / 物品 {len(item_img)} / 技能 {len(skill_img)} / NPC {len(npc_img)} / 宠物 {len(comp)} / 枚举图库 {len(mon_enum_lib)}")
