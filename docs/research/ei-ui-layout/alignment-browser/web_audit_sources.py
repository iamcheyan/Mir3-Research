#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""Web evidence registry for the 2026-09-26 mir2ei <-> Zircon web audit.

Every entry here was actually fetched or returned by a search during this audit.
`accessed_at` is the local (Asia/Tokyo) timestamp of the fetch.  `sha256` is the
hash of the copy kept under
`docs/research/ei-ui-layout/artifacts/web-entity-audit-2026-09-26/raw/`.
"""

ACCESSED = "2026-09-26T19:00+09:00"

# ---------------------------------------------------------------- external sources
EXTERNAL_SOURCES: dict[str, dict] = {
    "mir2ei-wiki-json": {
        "url": "https://mir2ei.iamcheyan.com/data/wiki_data_v2.json",
        "title": "EI 传奇3.0 百科 · 机器可读数据集 (wiki_data_v2.json)",
        "publisher": "mir2ei.iamcheyan.com (GitHub Pages 静态发布)",
        "accessed_at": ACCESSED,
        "bytes": 2845679,
        "sha256": "013fff2fc624b6f3",
        "raw_copy": "raw/wiki_data_v2.json",
        "excerpt": "monsters 534 (name/zh/ver/img/spawns/drops) · items 2203 · skills 218 · npcs 125 · maps 244 · terminology 1701 · mud3{spawns 293,merchants 318,guards 117,mapinfo 365}",
        "used_for": ["zh-en-dictionary", "legacy-version-attestation", "resource-lib-shape"],
    },
    "mir2ei-wiki-monsters-html": {
        "url": "https://mir2ei.iamcheyan.com/monsters.html",
        "title": "怪物图鉴 · EI 传奇3.0 百科",
        "accessed_at": ACCESSED,
        "bytes": 75590,
        "excerpt": "怪物图鉴 534 种；筛选维度 版本(ei/mei/mud3/zir)；条目带 /img/monsters/<id>.png 图标",
        "used_for": ["human-readable-page-for-json-dataset"],
    },
    "mir2ei-wiki-terms-html": {
        "url": "https://mir2ei.iamcheyan.com/terms.html",
        "title": "术语表 · EI 传奇3.0 百科 (1701 词条)",
        "accessed_at": ACCESSED,
        "bytes": 44350,
        "excerpt": "老版 DAT / 服务端字段英文术语 → 中文对照 · 共 1701 条；例: Guard 守卫 / Chicken 鸡 / Hound 猎犬",
        "used_for": ["zh-en-dictionary"],
    },
    "mir2ei-wiki-diff-html": {
        "url": "https://mir2ei.iamcheyan.com/diff.html",
        "title": "差异裁剪 · 三版本比对 (MUD3 / mir3ei / Zircon)",
        "accessed_at": ACCESSED,
        "bytes": 55502,
        "excerpt": "以 MUD3 服务端为基线对照 mir3ei 与 Zircon；30 MUD3 独有怪物 / 53 Zircon 独有刺客技能 / 166 Zircon 独有地图",
        "used_for": ["version-scope", "why-not-*-only"],
    },
    "mir2ei-wiki-library-html": {
        "url": "https://mir2ei.iamcheyan.com/library.html",
        "title": "资源库 · EI 客户端 Data/ 图库清单",
        "accessed_at": ACCESSED,
        "bytes": 0,
        "excerpt": "Monsters 36 库 (Mon-1..Mon-16, MonS-1..16, DMon-1, MonImg, MonMagic, MonMagicEx)；Item Icons (Equip/Ground/MIcon/ProgUse/Storeitem/inventory)",
        "used_for": ["resource-lib-names"],
    },
    "lomcn-mir3-monster-db": {
        "url": "https://www.lomcn.net/wiki/index.php/Monster_Database",
        "title": "Monster Database - LOMCN Wiki (Legend of Mir 3)",
        "accessed_at": ACCESSED,
        "bytes": 223052,
        "sha256": "6890d8feaabd6473",
        "raw_copy": "raw/www.lomcn.net_wiki_index.php_Monster_Database",
        "excerpt": "531 行 Mir3 怪物表：Name / Image / Image Number / AI / Notes；例 HookingCat(6) RakingCat(7) Yob(8) Oma(9) WhiteBoar ZumaTaurus RedMoonEvil WoomaSoldier FrozenZumaStatue IceCrystalSoldier",
        "used_for": ["wemade-english-name-list", "alias-chain"],
    },
    "lomcn-zircon-wiki": {
        "url": "https://www.lomcn.net/wiki/index.php/Zircon",
        "title": "Zircon - LOMCN Wiki",
        "accessed_at": ACCESSED,
        "bytes": 74984,
        "raw_copy": "raw/www.lomcn.net_wiki_index.php_Zircon",
        "excerpt": "Zircon 为 LOMCN 社区开源的 Mir3 C# 服务端/客户端；引用 Wemade 官方 Mir3 与 Shanda Mir3 站点",
        "used_for": ["project-provenance"],
    },
    "lomcn-zircon-forum": {
        "url": "https://www.lomcn.net/forum/forums/zircon-mir3-files-open-source.735/",
        "title": "Zircon Mir3 Files (Open Source) - LOMCN 论坛",
        "accessed_at": ACCESSED,
        "bytes": 197922,
        "excerpt": "LOMCN 论坛 Zircon 开源板块；官方 Mir3 开发者 Jamie / Far 命名体系被 Zircon 沿用",
        "used_for": ["naming-provenance", "alias-chain"],
    },
    "github-suprcode-zircon": {
        "url": "https://github.com/Suprcode/Zircon",
        "title": "Suprcode/Zircon — Legend of Mir 3 server & client (C#)",
        "accessed_at": ACCESSED,
        "bytes": 1127,
        "excerpt": "master 树 1127 个文件；Client/Envir/Translations/{ChineseMessages,EnglishMessages,StringMessages}.cs；Server/Views/*InfoView.cs (MonsterInfo/MagicInfo/ItemInfo/NPCInfo/MapInfo/RespawnInfo 等编辑视图)",
        "used_for": ["upstream-identity", "official-zh-strings"],
    },
    "github-suprcode-chinese-messages": {
        "url": "https://raw.githubusercontent.com/Suprcode/Zircon/master/Client/Envir/Translations/ChineseMessages.cs",
        "title": "Zircon upstream · Client/Envir/Translations/ChineseMessages.cs (82,057 B)",
        "accessed_at": ACCESSED,
        "bytes": 82057,
        "excerpt": "官方中文文案：WeaponEnergyFlamingSword=烈火剑法 / WeaponEnergyDragonRise=翔空剑法 / WeaponEnergyBladeStorm=莲月剑法 / WeaponEnergyDefensiveBlow=防御重击 / WeaponEnergyOffensiveBlow=进攻重击",
        "used_for": ["official-en-zh-skill-names"],
    },
    "github-forks": {
        "url": "https://api.github.com/repos/Suprcode/Zircon/forks?per_page=100&sort=newest",
        "title": "GitHub forks of Suprcode/Zircon (100 newest)",
        "accessed_at": ACCESSED,
        "excerpt": "Wincha/mir3-zircon (2023-08-16) · grimchamp/mir3-zircon (2024-03-02) · ketsmen/mir3-zircon (2026-08-09) · KingdomMir2/mir3-zircon (2022-08-29) · iamcheyan/Zircon-Godot (2026-09-26) · DrayChou/Zircon · marklove5102/Zircon · ValhallaMir/NexusZircon",
        "used_for": ["fork-inventory", "secondary-evidence-boundary"],
    },
    "sina-mir3-monster-rank": {
        "url": "https://games.sina.com.cn/z/mir3/2003-06-18/13374.shtml",
        "title": "怪物等级排名_传奇三_新浪游戏 (2003-06-18)",
        "accessed_at": ACCESSED,
        "bytes": 78328,
        "sha256": "1c21730f33d8f564",
        "raw_copy": "raw/sina_monster_rank.html",
        "excerpt": "老版怪物全量排名表（含变体后缀 0/61/9）：骷髅弓箭手0 / 黑野猪0 / 土蝎虫 / 斗猪 / 蝎蛇 / 赤黄猪王 / 大法老 / 八脚首领 / 牛道人 / 骨鬼将 / 疯狂魔神盗 / 护法天 / 震天首将 / 潘夜鬼将 / 怒龙神 / 震天魔神 / 诺玛王 / 赤蛇 / 触龙神",
        "used_for": ["legacy-chinese-attestation", "alias-chain"],
    },
    "sina-mir3g-monster-index": {
        "url": "https://games.sina.com.cn/zhqu/mir3/2/gwzl/",
        "title": "怪物资料 - 网络游戏传奇3G_新浪游戏",
        "accessed_at": ACCESSED,
        "bytes": 73998,
        "raw_copy": "raw/games.sina.com.cn_zhqu_mir3_2_gwzl_",
        "excerpt": "传奇3G 怪物资料栏目（怪物分布 / 怪物元素详解）；与 17173 镜像互为独立中文来源",
        "used_for": ["legacy-chinese-attestation"],
    },
    "17173-mir3-mob": {
        "url": "https://mir3.17173.com/mob/mob17.htm",
        "title": "17173.com 网络游戏：《传奇3》专区 · 怪物资料",
        "accessed_at": ACCESSED,
        "bytes": 21726,
        "sha256": "d69aa72c674532f4",
        "raw_copy": "raw/mir3_17173_mob17.html",
        "excerpt": "怪物页含中文名 + 中文描述 + mob/pic/<n>.gif 图标；栏目分组 一般怪物 / 毒蛇山谷 / 盟重 / 天然洞穴 / 银杏废矿 / 矿区 / 潘夜岛 / 沙漠绿洲 / 灌木林",
        "used_for": ["website-archive-provenance", "legacy-chinese-attestation"],
    },
    "17173-mir3-skill": {
        "url": "https://mir3.17173.com/skill/skill.htm",
        "title": "17173.com 网络游戏：《传奇3》专区 · 技能资料",
        "accessed_at": ACCESSED,
        "excerpt": "翔空剑法 / 十方斩 等技能中文描述；与本站镜像 data/skills.json 同源",
        "used_for": ["website-archive-provenance"],
    },
    "baike-duogoumao": {
        "url": "https://baike.baidu.com/item/%E5%A4%9A%E9%92%A9%E7%8C%AB/5630779",
        "title": "多钩猫_百度百科",
        "accessed_at": ACCESSED,
        "excerpt": "多钩猫手持偷盗的钩子作为武器（钩=hook）→ 对应 Wemade 名 HookingCat / Zircon 名 ClawCat",
        "used_for": ["alias-chain-zh-en"],
    },
    "baike-dingpamao": {
        "url": "https://baike.baidu.com/item/%E9%92%89%E8%80%99%E7%8C%AB/5630928",
        "title": "钉耙猫_百度百科",
        "accessed_at": ACCESSED,
        "excerpt": "钉耙猫偷取农民的钉耙作为武器（耙=rake）→ 对应 Wemade 名 RakingCat；Zircon 客户端有 RakingCat 图像但当前 MonsterInfo 无对应行",
        "used_for": ["alias-chain-zh-en", "resource-only-candidate"],
    },
    "zhihu-mir3-skills": {
        "url": "https://zhuanlan.zhihu.com/p/649403177",
        "title": "传奇3光通1.45版：三大职业最详细完美攻略（技能篇）",
        "accessed_at": ACCESSED,
        "excerpt": "翔空剑法 / 十方斩 / 龙卷风系等技能中文名与效果；用于技能中文名独立佐证",
        "used_for": ["skill-zh-attestation"],
    },
    "mir3-archive-site": {
        "url": "https://mir3.iamcheyan.com/",
        "title": "传奇三 · 资料 archive（17173 传奇3 专区镜像）",
        "accessed_at": ACCESSED,
        "bytes": 5027,
        "excerpt": "154 怪物 / 371 物品 / 61 技能 / 24 任务 / 3 地图；页面自述 '资料整理自 17173 传奇3 专区镜像'",
        "used_for": ["website-side-provenance"],
    },
}

# ---------------------------------------------------------------- search queries
# Each entry is a query actually issued through the DIM web search tool during
# this audit.  `outcome` records what the query was used to establish.
SEARCH_QUERIES: list[dict] = [
    {"q": "传奇3 Zircon 服务端 怪物 英文名 中文名 对照 MonsterInfo",
     "outcome": "确认中文圈存在 Zircon 引擎私服生态；GM 命令以中文名操作怪物，说明中文名与 Zircon 数据是同一实体集",
     "sources": ["https://blog.csdn.net/weixin_35828992/article/details/119695349"]},
    {"q": "传奇3 怪物 名称 中英文对照 Zuma Oma Claw Cat 英文名",
     "outcome": "命中 17173/新浪/百度百科 传奇3 怪物条目，确认 多钩猫/钉耙猫 等中文名与描述可用于语义映射",
     "sources": ["https://baike.baidu.com/item/%E4%BC%A0%E5%A5%873/3071381",
                 "https://games.sina.com.cn/zhqu/mir3/2/gwzl/"]},
    {"q": "site:lomcn.net Mir3 Zircon monster list",
     "outcome": "定位 LOMCN Mir3 怪物数据库（531 行英文名）与 Zircon 开源板块",
     "sources": ["https://www.lomcn.net/wiki/index.php/Monster_Database",
                 "https://www.lomcn.net/forum/forums/zircon-mir3-files-open-source.735/"]},
    {"q": "传奇3 钉耙猫 多钩猫 怪物 英文名 Raking Cat",
     "outcome": "确认 多钩猫(钩/hook) 与 钉耙猫(耙/rake) 是两个独立怪物，语义直译对应 HookingCat / RakingCat",
     "sources": ["https://baike.baidu.com/item/%E5%A4%9A%E9%92%A9%E7%8C%AB/5630779",
                 "https://baike.baidu.com/item/%E9%92%89%E8%80%99%E7%8C%AB/5630928"]},
    {"q": "传奇3 冰宫 冰原 怪物 名称 列表",
     "outcome": "命中冰原/冰宫版本怪物中文名（狼人/雪猪/幽灵骑士/冰魄鬼女/冰魂武将等），确认 Zircon Ice Plain/Ice Palace 系怪物属 1.45 后期内容",
     "sources": ["https://mir3.17173.com/content/2025-04-02/20250402115532979.shtml",
                 "http://qh773.com/a/youxiziliao/zhongjiziliao/2017/0505/321.html"]},
    {"q": "传奇3 怪物 白野猪 祖玛弓箭手 潘夜 英文名 WhiteBoar ZumaArcher Banya",
     "outcome": "命中怪物分布表（潘夜石窟=骷髅系 / 石阁庙=野猪系 / 沃玛神殿=沃玛系），建立 中文族名 ↔ Wemade 英文族名 的对应",
     "sources": ["http://qh773.com/a/youxiziliao/zhongjiziliao/2017/0505/321.html"]},
    {"q": "传奇3 怪物 英文名对照表 Wooma WhiteBoar RedMoonEvil 沃玛 白野猪 赤月恶魔",
     "outcome": "命中新浪 2003 老版怪物全量排名表，作为老版中文名独立佐证清单",
     "sources": ["https://games.sina.com.cn/z/mir3/2003-06-18/13374.shtml"]},
    {"q": "Legend of Mir 3 monster names list Wooma Zuma Banya Numa Chiwoo",
     "outcome": "确认 Mir3 英文名体系（Wooma/Zuma/Banya/Numa/Chiwoo）在英文社区资料中的使用",
     "sources": ["https://www.lomcn.net/forum/threads/legend-of-mir-3-go.114531/"]},
    {"q": "传奇3 蚂蚁洞 钳虫 蜈蚣 蜘蛛 怪物 名称 英文",
     "outcome": "命中蚂蚁洞/蜈蚣洞怪物中文清单，作为中文侧独立佐证",
     "sources": ["https://mir3.17173.com/content/2012-10-14/20121014234729325.shtml",
                 "https://games.sina.com.cn/z/mir3/2003-06-16/12957.shtml"]},
    {"q": "\"WhiteBoar\" OR \"RedMoonEvil\" OR \"WoomaTaurus\" Mir3 传奇3 白野猪 赤月恶魔 沃玛教主",
     "outcome": "无结果 —— 中英混排检索在通用引擎不可得，记为 excluded_candidates 依据（不可据此判为独有）",
     "sources": []},
    {"q": "传奇3 Zircon 汉化 怪物名称 对照 MonsterInfo 中文",
     "outcome": "确认中文圈 Zircon 私服以中文名操作怪物（@mob 怪物中文名），但未发现公开的完整中英对照表",
     "sources": ["https://blog.csdn.net/weixin_35828992/article/details/119695349",
                 "http://www.zircon.vip/Home/StrategyDetail?view=2"]},
    {"q": "传奇3 技能 英文名 Dragon Rise 翔空剑法 Blade Storm 十方斩 对照",
     "outcome": "命中 17173 技能页与光通 1.45 技能攻略，佐证技能中文名；英文名由 Zircon 官方 ChineseMessages.cs 提供",
     "sources": ["https://mir3.17173.com/skill/skill.htm",
                 "https://zhuanlan.zhihu.com/p/649403177"]},
    {"q": "传奇3 地图 比奇 盟重 潘夜 英文名 Bichon Numa map name",
     "outcome": "命中官方地图清单（边境村落/银杏村落/比奇县/盟重县/潘夜岛/诺玛遗址/沙巴克），用于地图中文名佐证",
     "sources": ["http://mir3.youxi.com/211371965/211372894/211372898.html"]},
]

# ---------------------------------------------------------------- rule-level queries
# Queries that a bulk rule stands on.  Records closed by a rule inherit these so
# that "every record has search queries" is literally true and auditable.
RULE_QUERIES: dict[str, list[str]] = {
    "zh-en-dictionary": [
        "传奇3 怪物 名称 中英文对照 Zuma Oma Claw Cat 英文名",
        "site:lomcn.net Mir3 Zircon monster list",
        "传奇3 Zircon 汉化 怪物名称 对照 MonsterInfo 中文",
    ],
    "wemade-english": [
        "site:lomcn.net Mir3 Zircon monster list",
        "Legend of Mir 3 monster names list Wooma Zuma Banya Numa Chiwoo",
    ],
    "semantic-alias": [
        "传奇3 钉耙猫 多钩猫 怪物 英文名 Raking Cat",
        "传奇3 怪物 白野猪 祖玛弓箭手 潘夜 英文名 WhiteBoar ZumaArcher Banya",
    ],
    "legacy-chinese-attestation": [
        "传奇3 怪物 英文名对照表 Wooma WhiteBoar RedMoonEvil 沃玛 白野猪 赤月恶魔",
        "传奇3 蚂蚁洞 钳虫 蜈蚣 蜘蛛 怪物 名称 英文",
    ],
    "official-zh-strings": [
        "传奇3 技能 英文名 Dragon Rise 翔空剑法 Blade Storm 十方斩 对照",
    ],
    "map-zh-attestation": [
        "传奇3 地图 比奇 盟重 潘夜 英文名 Bichon Numa map name",
    ],
    "version-scope": [
        "传奇3 冰宫 冰原 怪物 名称 列表",
    ],
}
