#!/usr/bin/env python3
"""生成 monsters.json / monsters.md：Mud3 EI2.0 monster.dat（433 条）
↔ Zircon System.db MonsterInfo（434 行）的一对一身份表。

只读：不写 System.db、不写 db_names.json、不改任何 Zircon 源文件；只在本目录产出。

规则（见本目录 README.md 与
Zircon/docs/pending/MUD3_CONTENT_AND_LEGACY_BAG_HANDOFF_2026-10-03.md §1.4）：

- closed     ：1:1 且至少一条主证据。主证据 = 数值锚点（Mud3 Level/HP/Exp 与 Zircon
               Level/Health/Experience 完全一致）、外观、刷怪/掉落共现，或本目录既有的
               已审锚点（monster_identity_manifest 的 verified/high 条目 + 三个强制锚点）。
- pending    ：一对多或证据不足。**禁止当作已定案的映射**；`zircon_index` 只是候选
               （人工勾选用），严禁据此写库 / 写 db_names.json。
- missing    ：Mud3 有、Zircon 当前库无。含变体记录（后缀 0/9/61/96+ 等）——它们与基础
               物种同源，Zircon 没有独立条目，按 handoff §1.4「变体默认不建新怪」不单独导入。
- zircon-only：Zircon 有、Mud3 无（后期私服原创 / 强化系列）。

自检（硬性）：
  closed + pending + missing     == Mud3 记录数 (433)
  closed + pending + zircon-only == Zircon 行数 (434)
  closed 行内 zircon_index 无重复（1:1）
  #pending 与 #closed 引用的 zircon_index 亦互不重复（否则 Zircon 覆盖会重复计数）

候选来源（仅候选、非主证据）：
  Tools/NpcMover/website_alignment.py 的 WEBSITE_MONSTER_TO_INDEXES 与
  WEBSITE_RESOURCE_ALIASES（后者按 Zircon `Image` 反查行）。

用法：
  python3 build_monster_identity.py
"""
from __future__ import annotations

import ast
import json
from collections import Counter
from datetime import date
from pathlib import Path

D = Path(__file__).resolve().parent
ROOT = Path("/home/tetsuya/development/Mir3-Research")

MUD3_MONSTER = ROOT / "docs/research/mud3-dat-decoded/monster.json"
ZIRCON_MONSTER = Path("/tmp/sysdb_probe.json/MonsterInfo.json")
WEBSITE_ALIGNMENT = ROOT / "Tools/NpcMover/website_alignment.py"
REGEN_CMD = (
    "cd /home/tetsuya/development/Mir3-Research/Tools/SystemDbProbe && "
    "./bin/Debug/net10.0/SystemDbProbe "
    "/home/tetsuya/development/Zircon/Debug/ServerCore/Database --json /tmp/sysdb_probe.json"
)

SOURCES = [
    str(MUD3_MONSTER) + " (records[].Name = GBK 官方中文名; 433 条)",
    str(ZIRCON_MONSTER) + " (SystemDbProbe --json, 当前双库快照; 434 行)",
    str(WEBSITE_ALIGNMENT) + " (WEBSITE_MONSTER_TO_INDEXES / WEBSITE_RESOURCE_ALIASES, 仅候选)",
    "Mir3-Research/docs/research/ei-ui-layout/artifacts/npc-monster-alignment-2026-09-25/"
    "monster_identity_manifest.json (既有已审锚点 41 条)",
    "Mir3-Research/docs/research/mud3-dat-decoded/build_comparison.py (MONSTER_MAP 起点)",
    "Mir3-Research/docs/terminology/08-怪物.md (仅作候选语境, 非主证据)",
]

# ---------------------------------------------------------------------------
# 强制锚点（README「已确认锚点（不得违反）」）
# ---------------------------------------------------------------------------
MANDATORY = {"半兽人": 22, "沃玛教主": 65, "祖玛教主": 81}
assert MANDATORY["沃玛教主"] != MANDATORY["祖玛教主"]

# ---------------------------------------------------------------------------
# closed：Mud3 官方中文名(精确) -> Zircon Index。
# 主证据 = 数值锚点(Level/HP/Exp 完全一致，由 verify 自动核对) 或既有的已审锚点。
# note 为「已审锚点」来源说明（这类无自动数值锚点也必须闭合）。
# ---------------------------------------------------------------------------
CLOSED: dict[str, tuple[int, str]] = {
    # --- 强制锚点 ---
    "半兽人": (22, "强制锚点 Oma（README 不得违反）"),
    "沃玛教主": (65, "强制锚点 Uma King（README 不得违反）"),
    "祖玛教主": (81, "强制锚点 Zuma King（README 不得违反）"),
    # --- 既有已审锚点（monster_identity_manifest verified/high）---
    "赤月恶魔": (75, "已审锚点 Red Moon The Fallen（manifest verified-alias）"),
    "火焰狮子": (448, "已审锚点 Flame Lion（manifest high）"),
    "霸王教主": (115, "已审锚点 Emperor Sa'Woo（manifest verified, 老版 20000→21000 最近）"),
    "大法老": (399, "已审锚点 Great Pharaoh（manifest high, 名=Great Pharaoh）"),
    "触角神魔": (421, "已审锚点 Otherworld Tentacle Demon（manifest medium, 异界触手族）"),
    "地牢女神1": (395, "已审锚点 Dungeon Goddess 1（manifest high）"),
    "地牢女神2": (396, "已审锚点 Dungeon Goddess 2（manifest high）"),
    "骨鬼将": (404, "已审锚点 Corpse Bone Spirit（manifest high）"),
    "黑野猪": (127, "已审锚点 Black Boar（manifest high）"),
    "红野猪": (125, "已审锚点 Red Boar（manifest high）"),
    "鸡": (8, "已审锚点 Chicken（manifest high）"),
    "角蝇": (472, "已审锚点 Fly（manifest high）"),
    "骷髅教主": (121, "已审锚点 Arch Lich Taedu（manifest medium, 老版 10000→15000）"),
    "猪": (9, "已审锚点 Pig（manifest high；Zircon 另有 Lv0 宠物版 189）"),
    "诺玛斧兵": (89, "已审锚点 Numa Grunt（manifest medium）"),
    "诺玛抛石兵": (163, "已审锚点 Numa Stone Thrower（manifest high）"),
    "诺玛突击队长": (166, "已审锚点 Numa Assault Captain（manifest high；与 286 同候选取此条）"),
    "诺玛装甲兵": (165, "已审锚点 Numa Armored Soldier（manifest high）"),
    "潘夜牛魔王": (113, "已审锚点 Flame Minotaur（manifest verified, 潘夜系）"),
    "潘夜战士": (186, "已审锚点 Banyo Warrior（manifest high）"),
    "石像狮子": (484, "已审锚点 Stone Lion（manifest high）"),
    "楔蛾": (124, "已审锚点 Wedge Moth（manifest high；Level 30 同）"),
    "羊": (12, "已审锚点 Sheep（manifest high；Zircon 另有 Lv0 宠物版 195）"),
    "牛": (11, "已审锚点 Cow（manifest high）"),
    # 冰宫/北境系列（manifest high，Zircon 后期移植，名称一一对应）
    "冰宫射手": (374, "已审锚点 Ice Palace Archer（manifest high，名一一对应）"),
    "冰城帝王": (372, "已审锚点 Ice City Emperor（manifest high）"),
    "冰宫巫师": (375, "已审锚点 Ice Palace Wizard（manifest high）"),
    "冰原勇士": (485, "已审锚点 Ice Plain Warrior（manifest high）"),
    "冰宫骑士": (377, "已审锚点 Ice Palace Knight（manifest high）"),
    "冰原狼王": (369, "已审锚点 Ice Plain Wolf King（manifest high）"),
    "冰原雪狼": (371, "已审锚点 Ice Plain Snow Wolf（manifest high）"),
    "冰原战士": (486, "已审锚点 Ice Plain Soldier（manifest high）"),
    "冰宫法师": (376, "已审锚点 Ice Palace Mage（manifest high）"),
    "冰宫守卫": (373, "已审锚点 Ice Palace Guard（manifest high）"),
    "冰原豪猪": (370, "已审锚点 Ice Plain Boar（manifest high）"),
    "寒冰守护神": (403, "已审锚点 Frost Guardian God（manifest high）"),
    # --- 数值锚点（Level / HP 完全一致，verify_closed 自动核对）---
    "狼": (14, ""),
    "多钩猫": (13, ""),
    "毒蜘蛛": (20, ""),
    "食人花": (17, ""),
    "稻草人": (21, ""),
    "森林雪人": (15, ""),
    "栗子树": (16, ""),
    "山洞蝙蝠": (24, ""),
    "蝎子": (25, ""),
    "洞蛆": (31, ""),
    "半兽战士": (18, ""),
    "虎蛇": (19, ""),
    "骷髅": (27, ""),
    "骷髅战士": (29, ""),
    "骷髅战将": (26, ""),
    "掷斧骷髅": (28, ""),
    "盔甲虫": (43, ""),
    "大老鼠": (79, ""),
    "巨象兽": (85, ""),
    "祖玛弓箭手": (76, ""),
    "祖玛卫士": (78, ""),
    "火焰沃玛": (63, ""),
    "蝎蛇": (126, ""),
    "沙漠树魔": (95, ""),
    "沙鬼": (93, ""),
}

# ---------------------------------------------------------------------------
# 人工候选（仅 pending 用）。用于 website alignment 未覆盖、但家族明确的中文名。
# 值 = (候选 Zircon Index 列表, 说明)。分配器取第一个未被占用的候选。
# ---------------------------------------------------------------------------
CURATED_PENDING: dict[str, tuple[list[int], str]] = {
    "不死雄狮": ([176, 128], "狮子/野猪系，无唯一候选（Wild Boar 176）"),
    "白野猪": ([128, 176], "石墓 Boss 系（Tusk Lord 128，资源图候选；Wild Boar 176 备选）"),
    "僧侣僵尸": ([58, 57], "僵尸系（Decaying/Rotting Ghoul）"),
    "僵尸王": ([60, 57], "僵尸王（Blood Thirsty Zombie 60）"),
    "八脚首领": ([73, 67], "蛛形首领（Arachnid Broodmother 73）"),
    "单腿诺玛": ([91, 90], "诺玛系（Numa Elite 91）"),
    "小诺玛": ([91, 90], "诺玛系（Numa Elite 91）"),
    "独臂诺玛": ([91, 90], "诺玛系（Numa Elite 91）"),
    "雌诺玛": ([91, 90], "诺玛系（Numa Elite 91）"),
    "雄诺玛": ([91, 90], "诺玛系（Numa Elite 91）"),
    "卫士": ([1, 364], "城镇守卫；Zircon 仅 Guard(1) 一条，体系已重做"),
    "变异丑蜥": ([106, 99], "变异蜥蜴系（Mutant Lizard 106）"),
    "变异利爪蜥": ([99, 106], "变异蜥蜴系（Saw Tooth Lizard 99）"),
    "变异刺骨蜥": ([97, 106], "变异蜥蜴系（Raging Lizard 97）"),
    "变异毒蜥": ([101, 100], "变异蜥蜴系（Sonic Lizard 101）"),
    "变异迅猛蜥": ([102, 103], "变异蜥蜴系（Giant/Crazed Lizard）"),
    "变异骷髅": ([30, 120], "骷髅系强化（Skeleton Lord 30）"),
    "地天灭王": ([231, 232], "龙渊系 Boss（Dragon Queen/Lord）"),
    "异界之门": ([96], "异界之门 = Netherworld Gate(96)，仅名称证据"),
    "恶形鬼": ([105], "鬼系 Boss（Death Lord Jichon 105，仅猜测）"),
    "沃玛护卫": ([64, 62], "沃玛系（Uma Anguisher 64）"),
    "沙漠威思而小虫": ([47, 46], "小虫系（Poisonous Mutant Flea 47）"),
    "灰血恶魔": ([69, 70], "赤月系守卫（Red Moon Guardian 69）"),
    "牛老道": ([57, 58], "僵尸系（Rotting Ghoul 57）"),
    "疯狂魔神盗": ([245, 246], "萨玛系刀客（Sama Cursed Bladesman 245）"),
    "神兽": ([146, 140], "召唤兽（Shinsu 146）"),
    "诺玛司令": ([164, 166], "诺玛系（Numa Royal Guard 164；166 已被突击队长占用）"),
    "诺玛巡逻队长": ([164, 161], "诺玛系（Numa Royal Guard 164）"),
    "诺玛教主": ([98, 166], "诺玛系首领（Numa Elder Shaman 98）"),
    "诺玛王": ([98], "诺玛系首领（Numa Elder Shaman 98）"),
    "诺玛骑兵": ([161, 165], "诺玛骑兵 = Numa Cavalry(161)"),
    "赤血恶魔": ([70, 69], "赤月系护卫（Red Moon Protector 70）"),
    "雪人": ([276, 15], "雪人 = Frost Yeti(276)"),
    "雷电僵尸": ([58, 57], "僵尸系（Decaying Ghoul 58）"),
    "震天兽": ([199, 139], "真天系（Jinchon Devil 199）"),
    "震天神兵": ([199, 139], "真天系（Jinchon Devil 199）"),
    "震天首将": ([139, 199], "真天系战将（Jinchon Warlord 139）"),
    "震天魔神": ([139, 199], "真天系（Jinchon Warlord 139）"),
    "骷髅武将": ([120, 30], "骷髅系（Skeleton Enforcer 120）"),
    "骷髅精灵": ([30, 120], "骷髅系（Skeleton Lord 30）"),
    "骷髅士兵": ([119, 117], "骷髅系（Bone Soldier 119）"),
    "骷髅武士": ([117, 119], "骷髅系（Bone Bladesman 117）"),
    "骷髅弓箭手": ([116, 28], "骷髅弓手（Bone Archer 116）"),
    "沙漠战士": ([152, 147], "沙漠/神舰系（Light Armed Soldier 152）"),
    "阿龙怪": ([128, 176], "石墓 Boss 系（Tusk Lord 128，仅猜测）"),
    "陀大怪": ([231, 232], "龙渊系（Dragon Queen 231，仅猜测）"),
    "蜈蚣": ([51, 183], "蜈蚣 = Centipede(51)，仅名称证据"),
}

# 明确 Mud3 独有 / 无对应（补充说明；未列出的默认也走 missing）
MISSING_NOTE: dict[str, str] = {
    "钉耙猫": "RakingCat 仅有资源图，无 MonsterInfo 身份行",
    "七点白蛇": "RedSnake 仅有资源图，无 MonsterInfo 身份行",
    "千年毒蛇": "RedSnake 仅有资源图，无 MonsterInfo 身份行",
    "红蛇": "RedSnake/TigerSnake 均已被占用或仅资源图",
    "猎鹰": "SkyStinger 仅有资源图，无 MonsterInfo 身份行",
    "蛤蟆": "Zircon 无青蛙类身份行",
    "白马": "坐骑在 Zircon 是物品，无怪物身份",
    "黑马": "坐骑在 Zircon 是物品，无怪物身份",
    "褐色马": "坐骑在 Zircon 是物品，无怪物身份",
    "练功师": "练功假人，Zircon 无对应身份",
    "木障": "地图障碍物，非怪物身份",
    "弩车": "守城器械，Zircon 无对应身份",
    "投石车": "守城器械，Zircon 无对应身份",
    "弓箭手": "泛用弓手，Mud3 独有（Zircon 用 Bone/Goru Archer）",
    "弓箭守卫": "泛用弓卫，Mud3 独有",
    "图书馆护卫": "任务守卫，Zircon 无对应身份",
    "诺玛城门": "城门物件，非怪物身份",
    "诺玛卫士": "诺玛守卫，Zircon 诺玛系无对应名",
    "沙巴克城门": "城门物件，非怪物身份",
    "圣诞树": "节日活动怪，Zircon 无对应身份",
    "超级圣诞树": "节日活动怪，Zircon 无对应身份",
    "圣诞鹿": "节日活动怪，Zircon 无对应身份",
    "柴三郎": "NPC/任务，Zircon 无对应身份",
    "玲花": "NPC/任务，Zircon 无对应身份",
    "魔石狂热者": "魔石系，Zircon 无对应身份",
    "魔石咆哮者": "魔石系，Zircon 无对应身份",
    "魔石守护神": "魔石系，Zircon 无对应身份",
    "霸群雕像": "雕像物件，非怪物身份",
    "超强骷髅": "召唤兽强化版，Zircon 无独立身份",
    "守卫武将": "Zircon 城镇守卫体系重做，无直接对应（manifest 已审 old-only）",
    "守卫狮子": "Zircon 城镇守卫体系重做，无直接对应",
    "守卫血魔": "Zircon 城镇守卫体系重做，无直接对应",
    "守卫沃玛": "Zircon 城镇守卫体系重做，无直接对应",
    "守卫右狮": "Zircon 城镇守卫体系重做，无直接对应",
    "守卫神将": "Zircon 城镇守卫体系重做，无直接对应",
    "守卫虫": "守卫类，Zircon 无对应身份",
    "护卫武士": "守卫类，Zircon 无对应身份",
    "署箭": "任务/守卫类，Zircon 无对应身份",
}

CONF_ORDER = ["closed", "pending", "missing", "zircon-only"]


# ---------------------------------------------------------------------------
def load_hints() -> tuple[dict[str, list[int]], dict[str, str]]:
    """从 website_alignment.py 提取候选字典（只读，literal_eval）。"""
    if not WEBSITE_ALIGNMENT.exists():
        return {}, {}
    text = WEBSITE_ALIGNMENT.read_text(encoding="utf-8")

    def grab(var: str):
        i = text.index(var)
        j = text.index("{", i)
        depth = 0
        for k in range(j, len(text)):
            if text[k] == "{":
                depth += 1
            elif text[k] == "}":
                depth -= 1
                if depth == 0:
                    return ast.literal_eval(text[j : k + 1])
        raise SystemExit(f"无法解析 {var}")

    return grab("WEBSITE_MONSTER_TO_INDEXES"), grab("WEBSITE_RESOURCE_ALIASES")


def load():
    if not ZIRCON_MONSTER.exists():
        raise SystemExit(f"缺少 Zircon 快照 {ZIRCON_MONSTER}\n请先生成：\n  {REGEN_CMD}")
    mud3 = json.loads(MUD3_MONSTER.read_text(encoding="utf-8"))
    zircon = json.loads(ZIRCON_MONSTER.read_text(encoding="utf-8"))
    return mud3, zircon


def health(zr: dict):
    for s in zr.get("Stats", []):
        if s["Stat"] == "Health":
            return s["Value"]
    return None


def zstat(zr: dict, name: str):
    for s in zr.get("Stats", []):
        if s["Stat"] == name:
            return s["Value"]
    return None


def verify_closed(mrows_by_name: dict, zrows: dict) -> None:
    """closed 必须存在；非「已审锚点」的必须有数值锚点，否则报错。"""
    problems = []
    for name, (zi, note) in CLOSED.items():
        mr = mrows_by_name.get(name)
        if mr is None:
            problems.append(f"closed 名称在 Mud3 找不到：{name}")
            continue
        if zi not in zrows:
            problems.append(f"closed 目标 Index 不存在：{name}->{zi}")
            continue
        zr = zrows[zi]
        anchored = note.startswith(("强制锚点", "已审锚点"))
        if not anchored:
            lvl = mr["Level"] == zr["Level"]
            hp = mr["HP"] == health(zr) and mr["HP"] is not None
            exp = mr["Exp"] == zr["Experience"] and mr["Exp"] is not None
            if not (lvl or hp or exp):
                problems.append(
                    f"closed 无数值锚点且非已审：{name} Mud3(L{mr['Level']},HP{mr['HP']},E{mr['Exp']})"
                    f" vs {zr['_Identity']}({zi})(L{zr['Level']},HP{health(zr)},E{zr['Experience']})"
                )
    if problems:
        raise SystemExit("closed 校验失败：\n  " + "\n  ".join(problems))


def numeric_evidence(mr: dict, zr: dict) -> str:
    parts = []
    if mr["Level"] == zr["Level"]:
        parts.append(f"Level {mr['Level']}={zr['Level']}")
    if mr["HP"] == health(zr) and mr["HP"] not in (None,):
        parts.append(f"HP {mr['HP']}={health(zr)}")
    if mr["Exp"] == zr["Experience"] and mr["Exp"] not in (None,):
        parts.append(f"Exp {mr['Exp']}={zr['Experience']}")
    return "；".join(parts)


def build_entries(mud3: dict, zircon: dict) -> list[dict]:
    zrows = {r["Index"]: r for r in zircon["rows"]}
    zimage_to_idx: dict[str, list[int]] = {}
    for r in zircon["rows"]:
        if r.get("Image"):
            zimage_to_idx.setdefault(r["Image"], []).append(r["Index"])
    hint_monster, hint_alias = load_hints()
    mrows = mud3["records"]
    mrows_by_name = {r["Name"]: r for r in mrows}

    verify_closed(mrows_by_name, zrows)

    used: set[int] = set()
    status: dict[int, tuple[str, int | None, str]] = {}  # mud3 index -> (conf, zi, evidence)

    # --- pass 1: closed（先占位，保证 1:1）---
    for mr in mrows:
        name = mr["Name"]
        if name in CLOSED:
            zi, note = CLOSED[name]
            zr = zrows[zi]
            ev = f"数值锚点：{numeric_evidence(mr, zr)}" if numeric_evidence(mr, zr) else ""
            if note:
                ev = (ev + "；" if ev else "") + note
            status[mr["Index"]] = ("closed", zi, ev)
            used.add(zi)

    # --- pass 2: pending / missing ---
    def candidates_for(name: str):
        if name in CURATED_PENDING:
            cands, note = CURATED_PENDING[name]
            return [i for i in cands if i in zrows], note
        if name in hint_monster:
            return [i for i in hint_monster[name] if i in zrows], "website alignment 候选（仅候选）"
        if name in hint_alias:
            imgs = zimage_to_idx.get(hint_alias[name], [])
            return list(imgs), f"资源图别名 {hint_alias[name]}→Image 反查（仅候选）"
        return [], ""

    def try_pending(mr: dict) -> bool:
        cands, note = candidates_for(mr["Name"])
        free = [i for i in cands if i not in used]
        if not free:
            return False
        zi = free[0]
        used.add(zi)
        zr = zrows[zi]
        status[mr["Index"]] = (
            "pending",
            zi,
            f"{note or '候选'}；候选 {cands}（未定案，禁止据此写库）；当前列首位 {zr['_Identity']}({zi})",
        )
        return True

    # 2a: 人工候选优先占位，避免被弱别名抢走自然候选
    for mr in mrows:
        if mr["Index"] in status or mr["Name"] not in CURATED_PENDING:
            continue
        try_pending(mr)

    # 2b: website alignment 提示
    for mr in mrows:
        if mr["Index"] in status:
            continue
        if mr["Name"] in hint_monster or mr["Name"] in hint_alias:
            try_pending(mr)

    # 2c: 其余 -> missing
    for mr in mrows:
        if mr["Index"] in status:
            continue
        name = mr["Name"]
        cands, _note = candidates_for(name)
        if name == "":
            ev = "头部占位记录（raw 首 u32=433 明文，非怪物；无身份）"
        elif name in MISSING_NOTE:
            ev = MISSING_NOTE[name]
        elif cands:
            ev = (
                f"候选 {cands} 均已被其它条目占用，Zircon 无独立条目可分配；"
                "按一对多处理但无空闲候选 → missing（需人工决定合并或新增）"
            )
        elif name and name[-1].isdigit():
            b = _strip_variants(name)
            bstat = _base_status(b, mrows_by_name)
            ev = f"变体记录（后缀）；基础物种「{b}」{bstat}；Zircon 无独立变体条目，按 handoff 不建新怪"
        else:
            ev = "Mud3 独有 / 无 Zircon 对应身份"
        status[mr["Index"]] = ("missing", None, ev)

    entries: list[dict] = []
    for mr in mrows:
        conf, zi, ev = status[mr["Index"]]
        zr = zrows.get(zi) if zi is not None else None
        entries.append(
            {
                "mud3_index": mr["Index"],
                "mud3_name": mr["Name"],
                "kind": "monster",
                "zircon_index": zi,
                "zircon_en": zr["_Identity"] if zr else None,
                "confidence": conf,
                "evidence": ev,
            }
        )

    # --- zircon-only ---
    for zr in zircon["rows"]:
        if zr["Index"] in used:
            continue
        entries.append(
            {
                "mud3_index": None,
                "mud3_name": None,
                "kind": "monster",
                "zircon_index": zr["Index"],
                "zircon_en": zr["_Identity"],
                "confidence": "zircon-only",
                "evidence": _zircon_only_note(zr),
            }
        )

    entries.sort(
        key=lambda e: (
            CONF_ORDER.index(e["confidence"]),
            e["mud3_index"] if e["mud3_index"] is not None else 10**9,
            e["zircon_index"] if e["zircon_index"] is not None else 10**9,
        )
    )
    return entries


def _strip_variants(name: str) -> str:
    i = len(name)
    while i > 0 and name[i - 1].isdigit():
        i -= 1
    return name[:i] if i > 0 else name


def _base_status(base: str, mrows_by_name: dict) -> str:
    if base in CLOSED:
        zi, _ = CLOSED[base]
        return f"已闭合到 Zircon Index {zi}"
    if base in CURATED_PENDING or base in MISSING_NOTE:
        return "在本表中为 pending 或有说明"
    return "在本表中未闭合"


def _zircon_only_note(zr: dict) -> str:
    ident = zr["_Identity"]
    if zr["Index"] in (189, 190, 191, 192, 193, 194, 195, 196, 197, 198):
        return "宠物/坐骑伴随兽（Level 0，AI=-2），Mud3 DAT 无"
    if zr["AI"] == -1:
        return "系统守卫/NPC 类，Mud3 DAT 无"
    if "Otherworld" in ident or "Moon River" in ident or "Demon Horde" in ident:
        return "异界/后期地图怪，Mud3 EI2.0 DAT 无"
    if "Sama" in ident or ident in {"Azog", "Urukhia", "Chubarak", "Sumerian",
                                     "Sumerian King", "Enheduanna", "Quadishtu", "Puabi",
                                     "Sacrifice"}:
        return "萨玛/苏美尔私服原创，Mud3 DAT 无"
    if "Taoyuan" in ident or "Mafa" in ident or "Qin " in ident or "Heavenly King" in ident:
        return "后期扩展地图怪，Mud3 EI2.0 DAT 无"
    if "Ice " in ident or "Heartless" in ident or "Fierce " in ident:
        return "后期/强化系列，Mud3 DAT 无独立条目"
    return "Zircon 后期/强化行，Mud3 DAT 无"


def self_check(entries: list[dict], n_mud3: int, n_zircon: int) -> Counter:
    c = Counter(e["confidence"] for e in entries)
    closed_z = [e["zircon_index"] for e in entries if e["confidence"] == "closed"]
    dup = [i for i, k in Counter(closed_z).items() if k > 1]
    assert not dup, f"closed zircon_index 重复：{dup}"
    allz = [e["zircon_index"] for e in entries if e["zircon_index"] is not None]
    dup2 = [i for i, k in Counter(allz).items() if k > 1]
    assert not dup2, f"closed/pending zircon_index 重复：{dup2}"
    assert c["closed"] + c["pending"] + c["missing"] == n_mud3, "Mud3 覆盖自检失败"
    assert c["closed"] + c["pending"] + c["zircon-only"] == n_zircon, "Zircon 覆盖自检失败"
    return c


def write_json(entries: list[dict]) -> None:
    doc = {
        "kind": "monster",
        "generated_at": date.today().isoformat(),
        "sources": SOURCES,
        "entries": entries,
    }
    (D / "monsters.json").write_text(
        json.dumps(doc, ensure_ascii=False, indent=2) + "\n", encoding="utf-8"
    )


def write_md(entries: list[dict], counts: Counter, n_mud3: int, n_zircon: int) -> None:
    out: list[str] = []
    w = out.append
    w("# Mud3 ↔ Zircon 怪物身份表（monster）\n")
    w("> 只读产出，不改 `System.db` / `db_names.json` / Zircon C#。")
    w("> 权威契约见本目录 `README.md` 与 `Zircon/docs/pending/MUD3_CONTENT_AND_LEGACY_BAG_HANDOFF_2026-10-03.md` §1.4。")
    w(f"> 生成：`build_monster_identity.py`（{date.today().isoformat()}）。Mud3 {n_mud3} 条 / Zircon {n_zircon} 行。\n")
    w("## 强制锚点（不得违反）\n")
    w("| Mud3 中文 | Zircon 身份 | Index |")
    w("|---|---|---:|")
    w("| 半兽人 | `Oma` | 22 |")
    w("| 沃玛教主 | `Uma King` | 65 |")
    w("| 祖玛教主 | `Zuma King` | 81 |")
    w("")
    w("`Uma King` 与 `Zuma King` 是两条不同怪，不得都译成「祖玛王」。\n")
    w("## 数量（按 confidence）\n")
    w("| confidence | 数量 |")
    w("|---|---:|")
    for k in CONF_ORDER:
        w(f"| {k} | {counts[k]} |")
    w("")
    w(
        f"自检：`closed+pending+missing == {n_mud3}`，"
        f"`closed+pending+zircon-only == {n_zircon}`，"
        "`closed` 无重复 `zircon_index`，`closed/pending` 引用亦无重复。\n"
    )
    w("> **pending 的 `zircon_index` 只是候选（人工勾选用），不是定案映射，禁止据此写库。**\n")
    heads = {
        "closed": "## closed（1:1，主证据闭合）",
        "pending": "## pending（候选/一对多，人工勾选；禁止当 closed）",
        "missing": "## missing（Mud3 有、Zircon 无 / 变体记录）",
        "zircon-only": "## zircon-only（Zircon 有、Mud3 无）",
    }
    for k in CONF_ORDER:
        rows = [e for e in entries if e["confidence"] == k]
        w(heads[k] + f"（{len(rows)}）\n")
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
    (D / "monsters.md").write_text("\n".join(out), encoding="utf-8")


def main() -> None:
    mud3, zircon = load()
    entries = build_entries(mud3, zircon)
    counts = self_check(entries, len(mud3["records"]), len(zircon["rows"]))
    write_json(entries)
    write_md(entries, counts, len(mud3["records"]), len(zircon["rows"]))
    print("mud3-identity/monsters.json / monsters.md 已生成")
    for k in CONF_ORDER:
        print(f"  {k:<12} {counts[k]}")
    print(f"  Mud3 合计   {counts['closed'] + counts['pending'] + counts['missing']}")
    print(f"  Zircon 合计 {counts['closed'] + counts['pending'] + counts['zircon-only']}")


if __name__ == "__main__":
    main()
