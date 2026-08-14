// buff-icons.js — BuffType → CBIcons.Zl 帧索引 (BuffDialog.cs:144-220 GetBuffIcon 照抄)
// 图标 URL: /res/sprites/CBIcons/{frame}.webp (webres 已导出所需帧)。
export const BUFF_ICONS = {
  9: 242,    // Castle
  3: 172,    // Observable
  14: 171,   // Veteran
  4: 229,    // Brown
  5: 266,    // PKPoint
  6: 241,    // PvPCurse
  11: 81,    // ItemBuffPermanent
  2: 264,    // HuntGold
  8: 137,    // Companion
  15: 76,    // MapEffect
  16: 76,    // InstanceEffect
  17: 140,   // Guild
  19: 80,    // Fame
  20: 210,   // RedGem
  21: 211,   // BlueGem
  22: 212,   // CursedGem
  300: 78,   // Heal
  301: 74,   // Invisibility
  201: 100,  // MagicShield
  205: 221,  // FrostBite
  7: 258,    // Redemption
  200: 94,   // Renounce
  100: 97,   // Defiance
  101: 96,   // Might
  103: 98,   // ReflectDamage
  102: 95,   // Endurance
  202: 99,   // JudgementOfHeaven
};

// BuffType → 中文名 (BuffDialog GetBuffHint 用的 Lang key 对应关系, 保留自 hud.js)
export const BUFF_TYPE_NAMES = {
  1: '服务器', 2: '狩猎金', 3: '可观察', 4: '褐名', 5: 'PK 点', 6: '红名诅咒',
  7: '救赎', 8: '伙伴', 9: '城堡', 10: '物品增益', 11: '永久增益', 14: '老兵',
  15: '地图效果', 16: '副本效果', 17: '行会', 19: '声望',
  20: '红宝石', 21: '蓝宝石', 22: '诅咒宝石',
  100: '反抗', 101: '威力', 102: '坚韧', 103: '反弹伤害', 104: '无敌',
  105: '防御打击', 106: '冲锋', 107: '元素剑',
  200: '放弃', 201: '魔法盾', 202: '天堂审判', 203: '元素风暴', 204: '强化魔法盾',
  205: '冰咬', 206: '龙卷',
  300: '治疗', 301: '隐身',
};

export function buffIcon(type) { return BUFF_ICONS[type] ?? 73; }   // ItemBuff 兜底 73 (BuffDialog.cs:157)
export function buffIconUrl(type) { return `/res/sprites/CBIcons/${buffIcon(type)}.webp`; }
