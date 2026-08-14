// net.js — Zircon 协议编解码 (从 LibraryCore/Network/Packet.cs 移植)
// 帧格式 (Packet.cs:146-187): [int32 LE 总长(含自身4B)][int16 LE packet id][payload]
// 序列化规则 (Packet.cs:189-303):
//   属性按声明序; string=7bit varint 长度+UTF8; byte[]=int32 len+bytes;
//   enum=底层类型(byte枚举1B, 默认枚举4B); class 属性=1B null标志+字段;
//   List<T>=1B null+int32 count+元素 (原始/枚举元素裸写, class 元素=1B null+字段);
//   Dictionary 同理; TimeSpan=i64 ticks; DateTime=i64 ToBinary; Color=i32 ARGB;
//   Point=2×i32; decimal=16B。
// packet id 全部来自 packet_id_dump 反射导出 (Tools/wsgateway/packet_id_dump,
// 对 Debug/ServerCore/LibraryCore.dll 反射; 禁止手推 (任何包类增删都会移位)。
// 2026-08-14 P0 修正: C.Chat id=40 (旧表 76 是 S.FriendAdd) + 补 LinkedItemIndexes;
//   S.Chat Type 为 int32 (MessageType 无 byte 底层声明, Enum.cs:546)。

// ---- Packet IDs (packet_id_dump 2026-08-14 实跑导出, 376 包全量) ----
export const ID = {
G_CHECKVERSION: 0, G_CONNECTED: 1, G_DISCONNECT: 2, G_GOODVERSION: 3,
G_PING: 4, G_PINGRESPONSE: 5, G_VERSION: 6,
S_ACTIVATION: 7, C_ACTIVATION: 8, C_ARMOURDYE: 9, C_ATTACK: 10,
C_AUTOPATHCANCEL: 11, S_AUTOPATHCHANGED: 12, C_AUTOPATHMOVESTARTED: 13,
C_AUTOPATHSTART: 14, C_AUTOPATHWAYPOINT: 15, C_AUTOPOTIONLINKCHANGED: 16,
C_BELTLINKCHANGED: 17, C_BLOCKADD: 18, S_BLOCKADD: 19, S_BLOCKREMOVE: 20,
C_BLOCKREMOVE: 21, S_BUFFADD: 22, S_BUFFCHANGED: 23, S_BUFFPAUSED: 24,
S_BUFFREMOVE: 25, S_BUFFTIME: 26, S_BUNDLECLOSE: 27, C_BUNDLECONFIRM: 28,
C_BUNDLEOPEN: 29, S_BUNDLEOPEN: 30, C_CAPTIONCHANGE: 31,
S_CHANGEATTACKMODE: 32, C_CHANGEATTACKMODE: 33, C_CHANGEONLINESTATE: 34,
S_CHANGEPASSWORD: 35, C_CHANGEPASSWORD: 36, C_CHANGEPETMODE: 37,
S_CHANGEPETMODE: 38, S_CHAT: 39, C_CHAT: 40, S_COMBATTIME: 41,
C_COMPANIONADOPT: 42, S_COMPANIONADOPT: 43, S_COMPANIONITEMSGAINED: 44,
S_COMPANIONRELEASE: 45, C_COMPANIONRELEASE: 46, S_COMPANIONRETRIEVE: 47,
C_COMPANIONRETRIEVE: 48, S_COMPANIONSHAPEUPDATE: 49,
S_COMPANIONSKILLUPDATE: 50, S_COMPANIONSTORE: 51, C_COMPANIONSTORE: 52,
C_COMPANIONUNLOCK: 53, S_COMPANIONUNLOCK: 54, S_COMPANIONUPDATE: 55,
S_COMPANIONWEIGHTUPDATE: 56, S_CURRENCYCHANGED: 57, C_CURRENCYDROP: 58,
S_DATAOBJECTHEALTHMANA: 59, S_DATAOBJECTITEM: 60, S_DATAOBJECTLOCATION: 61,
S_DATAOBJECTMAXHEALTHMANA: 62, S_DATAOBJECTMONSTER: 63,
S_DATAOBJECTPLAYER: 64, S_DATAOBJECTREMOVE: 65, S_DAYCHANGED: 66,
C_DELETECHARACTER: 67, S_DELETECHARACTER: 68,
S_DISCIPLINEEXPERIENCECHANGED: 69, S_DISCIPLINEUPDATE: 70,
C_FISHINGCAST: 71, S_FISHINGSTATS: 72, S_FOCUSCHANGED: 73,
C_FORTUNECHECK: 74, S_FORTUNEUPDATE: 75, S_FRIENDADD: 76, C_FRIENDADD: 77,
S_FRIENDREMOVE: 78, C_FRIENDREMOVE: 79, S_FRIENDUPDATE: 80,
S_GAINEDEXPERIENCE: 81, C_GAMEGOLDRECHARGE: 82, S_GAMELOGOUT: 83,
S_GAMESTOREDATA: 84, S_GAMESTOREFAVOURITECHANGED: 85,
C_GAMESTOREFAVOURITETOGGLE: 86, C_GAMESTOREGIFT: 87, S_GAMESTOREGIFT: 88,
S_GAMESTORETOPITEMS: 89, C_GENDERCHANGE: 90, S_GROUPINVITE: 91,
C_GROUPINVITE: 92, S_GROUPLFG: 93, C_GROUPLFGUPDATE: 94,
S_GROUPMEMBER: 95, C_GROUPNOTIFY: 96, C_GROUPREMOVE: 97,
S_GROUPREMOVE: 98, S_GROUPREQUEST: 99, C_GROUPREQUEST: 100,
C_GROUPRESPONSE: 101, S_GROUPSWITCH: 102, C_GROUPSWITCH: 103,
S_GROUPUPDATE: 104, S_GUILDCASTLEINFO: 105, S_GUILDCHANGED: 106,
C_GUILDCOLOUR: 107, S_GUILDCONQUESTDATE: 108, S_GUILDCONQUESTFINISHED: 109,
S_GUILDCONQUESTSTARTED: 110, C_GUILDCREATE: 111, S_GUILDCREATE: 112,
S_GUILDDAYRESET: 113, C_GUILDEDITMEMBER: 114, C_GUILDEDITNOTICE: 115,
C_GUILDFLAG: 116, S_GUILDFUNDSCHANGED: 117, S_GUILDGETITEM: 118,
C_GUILDINCREASEMEMBER: 119, S_GUILDINCREASEMEMBER: 120,
S_GUILDINCREASESTORAGE: 121, C_GUILDINCREASESTORAGE: 122,
S_GUILDINFO: 123, S_GUILDINVITE: 124, S_GUILDINVITEMEMBER: 125,
C_GUILDINVITEMEMBER: 126, S_GUILDKICK: 127, C_GUILDKICKMEMBER: 128,
S_GUILDMEMBERCONTRIBUTION: 129, S_GUILDMEMBEROFFLINE: 130,
S_GUILDMEMBERONLINE: 131, S_GUILDNEWITEM: 132, S_GUILDNOTICECHANGED: 133,
C_GUILDREPAIRCASTLEGATES: 134, C_GUILDREPAIRCASTLEGUARDS: 135,
C_GUILDREQUESTCONQUEST: 136, C_GUILDRESPONSE: 137, S_GUILDSTATS: 138,
C_GUILDTAX: 139, S_GUILDTAX: 140, C_GUILDTOGGLECASTLEGATES: 141,
S_GUILDUPDATE: 142, C_GUILDWAR: 143, S_GUILDWAR: 144,
S_GUILDWARFINISHED: 145, S_GUILDWARSTARTED: 146, C_HAIRCHANGE: 147,
C_HARVEST: 148, S_HEALTHCHANGED: 149, S_HELMETTOGGLE: 150,
C_HELMETTOGGLE: 151, C_HERMIT: 152, C_INCREASEDISCIPLINE: 153,
S_INFORMMAXEXPERIENCE: 154, S_INSPECT: 155, C_INSPECT: 156,
S_ITEMACECESSORYREFINED: 157, S_ITEMCHANGED: 158, S_ITEMDELETE: 159,
C_ITEMDELETE: 160, C_ITEMDROP: 161, S_ITEMDURABILITY: 162,
S_ITEMEXPERIENCE: 163, S_ITEMLOCK: 164, C_ITEMLOCK: 165, S_ITEMMOVE: 166,
C_ITEMMOVE: 167, S_ITEMSORT: 168, C_ITEMSORT: 169, S_ITEMSPLIT: 170,
C_ITEMSPLIT: 171, S_ITEMSTATSCHANGED: 172, S_ITEMSTATSREFRESHED: 173,
C_ITEMUSE: 174, S_ITEMUSEDELAY: 175, S_ITEMSCHANGED: 176,
S_ITEMSGAINED: 177, C_JOININSTANCE: 178, S_JOININSTANCE: 179,
C_JOINSTARTERGUILD: 180, S_LEVELCHANGED: 181, C_LOGIN: 182, S_LOGIN: 183,
C_LOGOUT: 184, S_LOOTBOXCLOSE: 185, C_LOOTBOXCONFIRMSELECTION: 186,
S_LOOTBOXOPEN: 187, C_LOOTBOXOPEN: 188, C_LOOTBOXREROLL: 189,
C_LOOTBOXREVEAL: 190, C_LOOTBOXTAKEITEMS: 191, C_MAGIC: 192,
S_MAGICCOOLDOWN: 193, C_MAGICKEY: 194, S_MAGICLEVELED: 195,
S_MAGICTOGGLE: 196, C_MAGICTOGGLE: 197, C_MAILDELETE: 198,
S_MAILDELETE: 199, C_MAILGETITEM: 200, S_MAILITEMDELETE: 201,
S_MAILLIST: 202, S_MAILNEW: 203, C_MAILOPENED: 204, S_MAILSEND: 205,
C_MAILSEND: 206, S_MANACHANGED: 207, S_MAPCHANGED: 208, S_MAPEFFECT: 209,
C_MARKETPLACEBUY: 210, S_MARKETPLACEBUY: 211,
C_MARKETPLACECANCELCONSIGN: 212, C_MARKETPLACECONSIGN: 213,
S_MARKETPLACECONSIGN: 214, S_MARKETPLACECONSIGNCHANGED: 215,
C_MARKETPLACEHISTORY: 216, S_MARKETPLACEHISTORY: 217,
S_MARKETPLACESEARCH: 218, C_MARKETPLACESEARCH: 219,
S_MARKETPLACESEARCHCOUNT: 220, S_MARKETPLACESEARCHINDEX: 221,
C_MARKETPLACESEARCHINDEX: 222, S_MARKETPLACESTOREBUY: 223,
C_MARKETPLACESTOREBUY: 224, S_MARRIAGEINFO: 225, S_MARRIAGEINVITE: 226,
C_MARRIAGEMAKERING: 227, S_MARRIAGEMAKERING: 228,
S_MARRIAGEONLINECHANGED: 229, S_MARRIAGEREMOVERING: 230,
C_MARRIAGERESPONSE: 231, C_MARRIAGETELEPORT: 232,
C_MILESTONEACTIVE: 233, C_MILESTONECLAIM: 234, S_MILESTONEEARNED: 235,
C_MILESTONENOTIFY: 236, C_MINING: 237, C_MOUNT: 238, S_MOUNTFAILED: 239,
C_MOVE: 240, S_NPCACCESSORYLEVELUP: 241, C_NPCACCESSORYLEVELUP: 242,
S_NPCACCESSORYREFINE: 243, C_NPCACCESSORYREFINE: 244,
C_NPCACCESSORYRESET: 245, C_NPCACCESSORYUPGRADE: 246,
S_NPCACCESSORYUPGRADE: 247, C_NPCBUTTON: 248, C_NPCBUY: 249,
C_NPCCALL: 250, C_NPCCLOSE: 251, S_NPCCLOSE: 252, C_NPCFRAGMENT: 253,
C_NPCMASTERREFINE: 254, S_NPCMASTERREFINE: 255,
C_NPCMASTERREFINEEVALUATE: 256, C_NPCREFINE: 257, S_NPCREFINE: 258,
C_NPCREFINERETRIEVE: 259, S_NPCREFINERETRIEVE: 260,
C_NPCREFINEMENTSTONE: 261, S_NPCREFINEMENTSTONE: 262, C_NPCREPAIR: 263,
S_NPCREPAIR: 264, S_NPCRESPONSE: 265, C_NPCROLL: 266, S_NPCROLL: 267,
C_NPCROLLRESULT: 268, C_NPCSELL: 269, S_NPCSOCKETCOMBINE: 270,
C_NPCSOCKETCOMBINE: 271, C_NPCSOCKETITEM: 272, S_NPCSOCKETITEM: 273,
C_NPCWEAPONCRAFT: 274, S_NPCWEAPONCRAFT: 275, C_NAMECHANGE: 276,
S_NEWACCOUNT: 277, C_NEWACCOUNT: 278, S_NEWCHARACTER: 279,
C_NEWCHARACTER: 280, S_NEWMAGIC: 281, S_OBJECTATTACK: 282,
S_OBJECTBUFFADD: 283, S_OBJECTBUFFREMOVE: 284, S_OBJECTDASH: 285,
S_OBJECTDIED: 286, S_OBJECTEFFECT: 287, S_OBJECTFISHING: 288,
S_OBJECTHARVEST: 289, S_OBJECTHARVESTED: 290, S_OBJECTHIDE: 291,
S_OBJECTIDLE: 292, S_OBJECTITEM: 293, S_OBJECTLEVELED: 294,
S_OBJECTMAGIC: 295, S_OBJECTMINING: 296, S_OBJECTMONSTER: 297,
S_OBJECTMOUNT: 298, S_OBJECTMOVE: 299, S_OBJECTNPC: 300,
S_OBJECTNAMECOLOUR: 301, S_OBJECTPETOWNERCHANGED: 302,
S_OBJECTPLAYER: 303, S_OBJECTPOISON: 304, S_OBJECTPROJECTILE: 305,
S_OBJECTPUSHED: 306, S_OBJECTRANGEATTACK: 307, S_OBJECTREMOVE: 308,
S_OBJECTREVIVE: 309, S_OBJECTSHOW: 310, S_OBJECTSPELL: 311,
S_OBJECTSPELLCHANGED: 312, S_OBJECTSTATS: 313, S_OBJECTSTRUCK: 314,
S_OBJECTTAMING: 315, S_OBJECTTURN: 316, S_OBSERVABLESWITCH: 317,
C_OBSERVABLESWITCH: 318, C_OBSERVERREQUEST: 319, C_PICKUP: 320,
S_PLAYERCHANGEUPDATE: 321, S_PLAYERUPDATE: 322, C_QUESTABANDON: 323,
C_QUESTACCEPT: 324, S_QUESTCANCELLED: 325, S_QUESTCHANGED: 326,
C_QUESTCOMPLETE: 327, C_QUESTTRACK: 328, C_RANGEATTACK: 329,
C_RANKREQUEST: 330, C_RANKSEARCH: 331, S_RANKSEARCH: 332,
S_RANKINGS: 333, S_REFINELIST: 334, C_REQUESTACTIVATIONKEY: 335,
S_REQUESTACTIVATIONKEY: 336, S_REQUESTPASSWORDRESET: 337,
C_REQUESTPASSWORDRESET: 338, C_RESETPASSWORD: 340, S_RESETPASSWORD: 340,
S_REVIVETIMERS: 341, S_SAFEZONECHANGED: 342, C_SELECTLANGUAGE: 343,
S_SELECTLOGOUT: 344, C_SENDCOMPANIONFILTERS: 345,
S_SENDCOMPANIONFILTERS: 346, S_SETTIMER: 347, S_STARTGAME: 348,
C_STARTGAME: 349, S_STARTOBSERVER: 350, S_STATSUPDATE: 351,
S_STORAGESIZE: 352, C_TAMING: 353, C_TAMINGSUCCESS: 354,
C_TELEPORTRING: 355, S_TIMEOFDAYCHANGED: 356, C_TOWNREVIVE: 357,
C_TRADEADDGOLD: 358, S_TRADEADDGOLD: 359, C_TRADEADDITEM: 360,
S_TRADEADDITEM: 361, S_TRADECLOSE: 362, C_TRADECLOSE: 363,
C_TRADECONFIRM: 364, S_TRADEGOLDADDED: 365, S_TRADEITEMADDED: 366,
S_TRADEOPEN: 367, S_TRADEREQUEST: 368, C_TRADEREQUEST: 369,
C_TRADEREQUESTRESPONSE: 370, S_TRADEUNLOCK: 371, C_TURN: 372,
S_USERLOCATION: 373, S_USERMILESTONES: 374, S_WEIGHTUPDATE: 375,
};

// ---- 枚举 (LibraryCore/Enum.cs) ----
export const LoginResultText = {
  0: '账号不存在', 1: '密码错误', 2: '账号已禁用', 3: '被踢下线', 4: '已在游戏中',
  5: '信息不完整', 6: '账号被封禁', 7: '服务器繁忙', 8: '系统错误', 9: '加载失败',
  10: '成功',
};
export const LOGIN_SUCCESS = 10;
export const StartGameResultText = {
  0: '角色被禁用', 1: '角色已删除', 2: '冷却中,3秒后重试', 3: '无法出生', 4: '角色不存在', 5: '成功',
};
export const STARTGAME_SUCCESS = 5, STARTGAME_DELAYED = 2;
export const DELETECHARACTER_SUCCESS = 3;
export const DeleteCharacterResultText = { 0: '禁止删除', 1: '已被删除', 2: '角色不存在', 3: '成功' };
export const NewCharacterResultText = { 0: '禁止创建', 1: '名字已存在', 2: '名字不合法', 3: '成功' };
export const NEWCHARACTER_SUCCESS = 3;
export const NewAccountResultText = {
  0: '禁止创建', 1: '邮箱已存在', 2: '邮箱不合法', 3: '密码不合法', 4: '邮箱不可用',
  5: '姓名不合法', 6: '成功', 7: '已存在', 8: '引用人无效', 9: '系统错误',
};
export const NEWACCOUNT_SUCCESS = 6, NEWACCOUNT_ALREADY = 7;
export const DisconnectReasonText = {
  0: '未知', 1: '超时', 2: '版本不符', 3: '服务器关闭', 4: '另一处登录', 5: '被踢', 6: '崩溃',
};

// MessageType (Enum.cs:546, int32 底层) — 聊天频道
export const MSG = {
  NORMAL: 0, SHOUT: 1, WHISPERIN: 2, GMWHISPERIN: 3, WHISPEROUT: 4,
  GROUP: 5, GLOBAL: 6, HINT: 7, SYSTEM: 8, ANNOUNCEMENT: 9, COMBAT: 10,
  OBSERVERCHAT: 11, GUILD: 12, DEBUG: 13,
};
export const MsgTypeName = {
  0: '', 1: '[喊话]', 2: '[密语]', 3: '[GM]', 4: '[密语]', 5: '[组队]',
  6: '[世界]', 7: '', 8: '[系统]', 9: '[公告]', 10: '[战斗]', 11: '', 12: '[行会]', 13: '[调试]',
};
// 聊天颜色 (ChatLogPanel.cs 颜色规则)
export const MsgTypeColour = {
  0: '#ffffff', 1: '#ffff00', 2: '#c0c0ff', 3: '#ff80ff', 4: '#c0c0ff',
  5: '#80c0ff', 6: '#ffff80', 7: '#ffd573', 8: '#ff6060', 9: '#ff9020',
  10: '#c0c0c0', 11: '#ffffff', 12: '#80ff80', 13: '#808080',
};

// MirAction (Enum.cs:463, byte)
export const ACTION = {
  STANDING: 0, MOVING: 1, PUSHED: 2, ATTACK: 3, RANGEATTACK: 4, SPELL: 5,
  HARVEST: 6, STRUCK: 7, DIE: 8, DEAD: 9, SHOW: 10, HIDE: 11, MOUNT: 12,
  MINING: 13, FISHING: 14, TAMING: 15, IDLE: 16,
};

// GridType (Enum.cs:168, int32 底层)
export const GRID = {
  NONE: 0, INVENTORY: 1, EQUIPMENT: 2, BELT: 3, REPAIR: 4, STORAGE: 5,
  AUTOPOTION: 6, REFINEBLACKIRONORE: 7, REFINEACCESSORY: 8, REFINESPECIAL: 9,
  INSPECT: 10, CONSIGN: 11, SENDMAIL: 12, TRADEUSER: 13, TRADEPLAYER: 14,
  GUILDSTORAGE: 15, COMPANIONINVENTORY: 16, COMPANIONEQUIPMENT: 17,
  WEDDINGRING: 18, REFINEMENTSTONEIRONORE: 19, REFINEMENTSTONESILVERORE: 20,
  REFINEMENTSTONEDIAMOND: 21, REFINEMENTSTONEGOLDORE: 22,
  REFINEMENTSTONECRYSTAL: 23, ITEMFRAGMENT: 24,
  ACCESSORYREFINEUPGRADETARGET: 25, ACCESSORYREFINELEVELTARGET: 26,
  ACCESSORYREFINELEVELITEMS: 27, MASTERREFINEFRAGMENT1: 28,
  MASTERREFINEFRAGMENT2: 29, MASTERREFINEFRAGMENT3: 30,
};

// Stat (Stat.cs:507, int32 底层; SortedDictionary<Stat,int> 键)
export const STAT = {
  BASEHEALTH: 0, BASEMANA: 1, HEALTH: 2, MANA: 3, MINAC: 4, MAXAC: 5,
  MINMR: 6, MAXMR: 7, MINDC: 8, MAXDC: 9, MINMC: 10, MAXMC: 11, MINSC: 12,
  MAXSC: 13, ACCURACY: 14, AGILITY: 15, ATTACKSPEED: 16, LIGHT: 17,
  STRENGTH: 18, LUCK: 19, FIREATTACK: 20, FIRERESISTANCE: 21, ICEATTACK: 22,
  ICERESISTANCE: 23, LIGHTNINGATTACK: 24, LIGHTNINGRESISTANCE: 25,
  WINDATTACK: 26, WINDRESISTANCE: 27, HOLYATTACK: 28, HOLYRESISTANCE: 29,
  DARKATTACK: 30, DARKRESISTANCE: 31, PHANTOMATTACK: 32,
  PHANTOMRESISTANCE: 33, COMFORT: 34, LIFESTEAL: 35, EXPERIENCERATE: 36,
  DROPRATE: 37, NONE: 38, SKILLRATE: 39, PICKUPRADIUS: 40, HEALING: 41,
  HEALINGCAP: 42, INVISIBILITY: 43, FIREAFFINITY: 44, ICEAFFINITY: 45,
  LIGHTNINGAFFINITY: 46, WINDAFFINITY: 47, HOLYAFFINITY: 48,
  DARKAFFINITY: 49, PHANTOMAFFINITY: 50, REFLECTDAMAGE: 51,
  WEAPONELEMENT: 52, REDEMPTION: 53, HEALTHPERCENT: 54, CRITICALCHANCE: 55,
};
// 0-43 之外的 Stat 名 (Stat.cs 507-660 顺序), 供显示
export const STAT_NAMES = {
  0: '基础生命', 1: '基础魔力', 2: '生命', 3: '魔力', 4: '最小防御', 5: '最大防御',
  6: '最小魔御', 7: '最大魔御', 8: '最小攻击', 9: '最大攻击', 10: '最小魔法',
  11: '最大魔法', 12: '最小道术', 13: '最大道术', 14: '命中', 15: '敏捷',
  16: '攻击速度', 17: '光照', 18: '强度', 19: '幸运',
  20: '火元素', 21: '火抗性', 22: '冰元素', 23: '冰抗性', 24: '雷元素',
  25: '雷抗性', 26: '风元素', 27: '风抗性', 28: '圣元素', 29: '圣抗性',
  30: '暗元素', 31: '暗抗性', 32: '幻元素', 33: '幻抗性', 34: '回复',
  35: '吸血', 36: '经验加成', 37: '爆率加成', 39: '技能倍率', 40: '拾取范围',
  41: '治疗总量', 42: '单次回复上限', 44: '火亲和', 45: '冰亲和',
  46: '雷亲和', 47: '风亲和', 48: '圣亲和', 49: '暗亲和', 50: '幻亲和',
  51: '反弹伤害', 52: '武器元素', 53: '救赎', 54: '生命百分比', 55: '暴击',
};

// UserItemFlags (Enum.cs:1889, int32)
export const ITEM_FLAGS = { LOCKED: 1, MARRIAGE: 2, TRADE: 4, REFINE: 8 };

// MirClass (byte): 0=战士 1=法师 2=道士 3=刺客
export const CLASS_NAMES = ['战士', '法师', '道士', '刺客'];
export const CLASS_KEYS = ['Warrior', 'Wizard', 'Taoist', 'Assassin'];

// Rarity (Enum.cs:336 byte) — 物品品阶颜色
export const RARITY = { COMMON: 0, COMMON1: 1, ELITE: 2, ELITE1: 3, RARE: 4, RARE1: 5, LEGENDARY: 6, LEGENDARY1: 7 };
export const RarityColour = ['#ffffffff', '#ffffffff', '#ff3399ffff', '#ff3399ffff', '#ff9966ffff', '#ff9966ffff', '#ffff9900ff', '#ffff9900ff'];

// Element (Enum.cs:615 byte)
export const ELEMENT = { NONE: 0, FIRE: 1, ICE: 2, LIGHTNING: 3, WIND: 4, HOLY: 5, DARK: 6, PHANTOM: 7 };
export const ElementName = ['无', '火', '冰', '雷', '风', '圣', '暗', '幻'];

// ---- 编码器 (对应 C# BinaryWriter.Write) ----
export class Writer {
  constructor() { this.parts = []; this.len = 0; }
  #push(arr) { this.parts.push(arr); this.len += arr.length; }
  byte(v) { this.#push(new Uint8Array([v & 0xff])); return this; }
  int16(v) { const a = new Int16Array([v]); return this.#push(new Uint8Array(a.buffer)), this; }
  int32(v) { const a = new Int32Array([v]); return this.#push(new Uint8Array(a.buffer)), this; }
  uint32(v) { const a = new Uint32Array([v]); return this.#push(new Uint8Array(a.buffer)), this; }
  int64(v) { const a = new BigInt64Array([v]); return this.#push(new Uint8Array(a.buffer)), this; }
  float(v) { const a = new Float32Array([v]); return this.#push(new Uint8Array(a.buffer)), this; }
  bool(v) { return this.byte(v ? 1 : 0); }
  u7(v) { // 7-bit 编码长度 (BinaryWriter.Write(string) 前缀)
    const out = [];
    v = v >>> 0;
    while (v >= 0x80) { out.push((v & 0x7f) | 0x80); v >>>= 7; }
    out.push(v);
    return this.#push(new Uint8Array(out)), this;
  }
  string(s) { // 7bit 长度 + UTF-8; null → 空
    const b = new TextEncoder().encode(s ?? '');
    this.u7(b.length);
    return this.#push(b), this;
  }
  blob(bytes) { // byte[]: int32 len + raw
    this.int32(bytes.length);
    return this.#push(bytes), this;
  }
  point(x, y) { return this.int32(x).int32(y); }
  cellLink(link) { // CellLinkInfo (Globals.cs:862): GridType i32 + Slot i32 + Count i64
    if (!link) return this.bool(false);
    return this.bool(true).int32(link.gridType).int32(link.slot).int64(link.count);
  }
  list(items, writeElem) { // List<T>: 1B null + i32 count + 元素
    if (items == null) return this.bool(false);
    this.bool(true).int32(items.length);
    for (const x of items) writeElem(this, x);
    return this;
  }
  build(id) { // 帧 = [int32 LE 总长(含4)][int16 LE id][payload]
    const total = 4 + 2 + this.len;
    const out = new Uint8Array(total);
    const dv = new DataView(out.buffer);
    dv.setInt32(0, total, true);
    dv.setInt16(4, id, true);
    let o = 6;
    for (const p of this.parts) { out.set(p, o); o += p.length; }
    return out;
  }
}

// ---- 解码器 ----
export class Reader {
  constructor(buf) {
    this.u8 = buf;
    this.dv = new DataView(buf.buffer, buf.byteOffset, buf.byteLength);
    this.p = 0;
  }
  get left() { return this.u8.length - this.p; }
  byte() { return this.dv.getUint8(this.p++); }
  int16() { const v = this.dv.getInt16(this.p, true); this.p += 2; return v; }
  int32() { const v = this.dv.getInt32(this.p, true); this.p += 4; return v; }
  uint32() { const v = this.dv.getUint32(this.p, true); this.p += 4; return v; }
  int64() { const v = this.dv.getBigInt64(this.p, true); this.p += 8; return v; }
  float() { const v = this.dv.getFloat32(this.p, true); this.p += 4; return v; }
  bool() { return this.byte() !== 0; }
  bs7() { // 7-bit 变长长度
    let val = 0, shift = 0, b;
    do { b = this.byte(); val |= (b & 0x7f) << shift; shift += 7; } while (b & 0x80);
    return val >>> 0;
  }
  string() {
    const n = this.bs7();
    const s = new TextDecoder('utf-8').decode(this.u8.subarray(this.p, this.p + n));
    this.p += n;
    return s;
  }
  blob() { const n = this.int32(); const b = this.u8.subarray(this.p, this.p + n); this.p += n; return b; }
  nullable() { return this.bool(); } // class 属性 1B null 标志
  list(readElem) { // 1B null + i32 count + 元素
    if (!this.bool()) return null;
    const n = this.int32();
    const out = new Array(n);
    for (let i = 0; i < n; i++) out[i] = readElem(this);
    return out;
  }
  point() { return { x: this.int32(), y: this.int32() }; }
  skip(n) { this.p += n; return this; }
}

// ---- 流式拆帧 (wsgateway WS 消息 ≠ 包边界; login_client.py:88-113 同款) ----
export class PacketStream {
  constructor() { this.chunks = []; this.len = 0; }
  feed(bytes) {
    if (!(bytes instanceof Uint8Array)) bytes = new Uint8Array(bytes);
    this.chunks.push(bytes); this.len += bytes.length;
  }
  next() { // → {id, payload:Uint8Array} | null (需更多字节)
    if (this.len < 4) return null;
    const head = this.peek(4);
    const total = head[0] | (head[1] << 8) | (head[2] << 16) | (head[3] << 24);
    if (!(total >= 6 && total <= 64 * 1024 * 1024)) throw new Error(`帧长非法: ${total}`);
    if (this.len < total) return null;
    const buf = this.take(total);
    const dv = new DataView(buf.buffer, buf.byteOffset, buf.byteLength);
    return { id: dv.getInt16(4, true), payload: buf.subarray(6) };
  }
  peek(n) {
    const out = new Uint8Array(n);
    let o = 0;
    for (const c of this.chunks) {
      if (o >= n) break;
      const t = Math.min(c.length, n - o);
      out.set(c.subarray(0, t), o); o += t;
    }
    return out;
  }
  take(n) {
    const out = new Uint8Array(n);
    let o = 0;
    while (o < n && this.chunks.length) {
      const c = this.chunks[0];
      const t = Math.min(c.length, n - o);
      out.set(c.subarray(0, t), o); o += t;
      this.len -= t;
      if (t === c.length) this.chunks.shift();
      else this.chunks[0] = c.subarray(t);
    }
    return out;
  }
}

// ---- 嵌套 DTO (字段序 = LibraryCore/Globals.cs 声明序) ----

// SelectInfo (Globals.cs:333-343)
export function readSelectInfo(r) {
  return {
    characterIndex: r.int32(),
    characterName: r.string(),
    caption: r.string(),
    level: r.int32(),
    gender: r.byte(),
    class: r.byte(),
    location: r.int32(),
    lastLogin: r.int64(),
  };
}

export function readClientUserItemFull(r) {
  if (!r.bool()) return null;
  const o = {
    index: r.int32(), infoIndex: r.int32(), currentDurability: r.int32(),
    maxDurability: r.int32(), count: r.int64(), slot: r.int32(),
    level: r.int32(),
  };
  r.skip(16);              // Experience: decimal 16B
  o.colour = r.int32();     // Colour: Color (int32 ARGB)
  r.int64();                // SpecialRepairCoolDown: TimeSpan 8B
  r.int64();                // ResetCoolDown: TimeSpan 8B
  o.addedStats = readStats(r);
  o.sockets = r.list(readClientUserItemSocket);
  o.flags = r.int32();     // UserItemFlags (int 底层)
  r.int64();               // ExpireTime
  return o;
}
function readClientUserItemSocket(r) {
  if (!r.bool()) return null;
  return { slot: r.int32(), gem: readClientUserItemFull(r) };
}

// Stats (Stat.cs:10): class → 1B null 标志; 属性 Values=SortedDictionary (IsClass 也成立!)
// → 再 1B null 标志 + i32 count + (k,v) 对 (Packet.cs:198-237 IsClass 先于 IsGenericType)
export function readStats(r) {
  if (!r.bool()) return null;
  if (!r.bool()) return null;   // Values 字典 null 标志
  const n = r.int32();
  const out = [];
  for (let i = 0; i < n; i++) out.push([r.int32(), r.int32()]);
  return { values: out };
}
// Stats → 普通对象 (方便取值)
export function statsToObj(stats) {
  const o = {};
  if (stats?.values) for (const [k, v] of stats.values) o[k] = v;
  return o;
}

// CellLinkInfo (Globals.cs:862)
export function readCellLinkInfo(r) {
  if (!r.bool()) return null;
  return { gridType: r.int32(), slot: r.int32(), count: r.int64() };
}

function readClientUserDiscipline(r) { // Globals.cs:1211
  if (!r.bool()) return null;
  const o = { infoIndex: r.int32(), level: r.int32(), experience: r.int64() };
  o.magics = r.list(readClientUserMagic);
  return o;
}
function readClientFriendInfo(r) { // Globals.cs:1158
  if (!r.bool()) return null;
  return { index: r.int32(), name: r.string(), state: r.byte() };
}
function readClientBeltLink(r) { // Globals.cs:809
  if (!r.bool()) return null;
  return { slot: r.int32(), linkInfoIndex: r.int32(), linkItemIndex: r.int32() };
}
function readClientAutoPotionLink(r) { // Globals.cs:816
  if (!r.bool()) return null;
  return { slot: r.int32(), linkInfoIndex: r.int32(), health: r.int32(), mana: r.int32(), enabled: r.bool() };
}
function readClientUserMilestone(r) { // Globals.cs:1267
  if (!r.bool()) return null;
  const o = {
    index: r.int32(), infoIndex: r.int32(), active: r.bool(), claimed: r.bool(),
    dateEarned: r.int64(),
  };
  o.tasks = r.list((rr) => rr.bool() ? ({ infoTaskIndex: rr.int32(), count: rr.int64() }) : null);
  return o;
}
function readClientUserMagic(r) { // Globals.cs:825
  if (!r.bool()) return null;
  const o = {
    index: r.int32(), infoIndex: r.int32(),
    set1Key: r.byte(), set2Key: r.byte(), set3Key: r.byte(), set4Key: r.byte(),
    level: r.int32(), experience: r.int64(), itemRequired: r.bool(),
  };
  r.int64(); // Cooldown
  return o;
}
function readClientBuffInfo(r) { // Globals.cs:869
  if (!r.bool()) return null;
  const o = {
    index: r.int32(), type: r.int32(), remainingTime: r.int64(), tickFrequency: r.int64(),
  };
  o.stats = readStats(r);
  o.pause = r.bool(); o.itemIndex = r.int32(); o.extra = r.int32();
  return o;
}
function readClientUserCurrency(r) { // Globals.cs:1192
  if (!r.bool()) return null;
  return { currencyIndex: r.int32(), amount: r.int64() };
}
function readClientUserQuest(r) { // Globals.cs:1004
  if (!r.bool()) return null;
  const o = {
    index: r.int32(), questIndex: r.int32(), track: r.bool(), completed: r.bool(),
    selectedReward: r.int32(), dateTaken: r.int64(), dateCompleted: r.int64(),
  };
  o.tasks = r.list((rr) => rr.bool() ? ({ index: rr.int32(), taskIndex: rr.int32(), amount: rr.int64() }) : null);
  return o;
}
function readClientUserCompanion(r) { // Globals.cs:1063
  if (!r.bool()) return null;
  const o = {
    index: r.int32(), name: r.string(), companionIndex: r.int32(),
    level: r.int32(), hunger: r.int32(), experience: r.int32(),
  };
  for (const k of ['level3', 'level5', 'level7', 'level10', 'level11', 'level13', 'level15'])
    o[k] = readStats(r);
  o.characterName = r.string();
  o.items = r.list(readClientUserItemFull);
  return o;
}
// ClientBlockInfo (Globals.cs)
function readClientBlockInfo(r) {
  if (!r.bool()) return null;
  return { index: r.int32(), name: r.string() };
}
// ClientMailInfo (Globals.cs)
function readClientMailInfo(r) {
  if (!r.bool()) return null;
  const o = {
    index: r.int32(), opened: r.bool(), hasItem: r.bool(),
  };
  r.int64(); // Date (DateTime ToBinary)
  o.sender = r.string(); o.subject = r.string(); o.message = r.string();
  o.gold = r.int32();
  o.items = r.list(readClientUserItemFull);
  return o;
}
// ClientGuildMemberInfo (Globals.cs)
function readClientGuildMemberInfo(r) {
  if (!r.bool()) return null;
  const o = {
    index: r.int32(), name: r.string(), rank: r.string(),
    totalContribution: r.int64(), dailyContribution: r.int64(),
  };
  r.int64(); // Online TimeSpan
  o.permission = r.int32(); // GuildPermission (int 底层)
  // LastOnline 是 public 字段 (非属性) — 不序列化
  o.objectID = r.uint32();
  return o;
}
function readClientGuildInfo(r) {
  if (!r.bool()) return null;
  const o = {
    guildName: r.string(), notice: r.string(), memberLimit: r.int32(),
    guildFunds: r.int64(), dailyGrowth: r.int64(),
    totalContribution: r.int64(), dailyContribution: r.int64(),
    userIndex: r.int32(), storageLimit: r.int32(), tax: r.int32(),
    defaultRank: r.string(), defaultPermission: r.int32(),
  };
  o.colour = r.int32(); o.flag = r.int32();
  o.members = r.list(readClientGuildMemberInfo);
  o.storage = r.list(readClientUserItemFull);
  return o;
}
// ClientLookingForGroup (Globals.cs)
function readClientLookingForGroup(r) {
  if (!r.bool()) return null;
  const o = {
    leaderName: r.string(), groupName: r.string(), groupType: r.string(),
  };
  o.memberInfo = r.list((rr) => rr.string());
  o.maxCount = r.int32(); o.enabled = r.bool();
  return o;
}
// ClientNPCValues (Globals.cs)
function readClientNPCValues(r) {
  if (!r.bool()) return null;
  return { id: r.int32(), value: r.string() };
}
// ClientMarketPlaceInfo (Globals.cs)
function readClientMarketPlaceInfo(r) {
  if (!r.bool()) return null;
  const o = { index: r.int32(), item: readClientUserItemFull(r), price: r.int32() };
  r.int64(); // ConsignDate DateTime
  o.seller = r.string(); o.message = r.string(); o.isOwner = r.bool();
  return o;
}
// RankInfo (Globals.cs)
function readRankInfo(r) {
  if (!r.bool()) return null;
  const o = {
    rank: r.int32(), index: r.int32(), name: r.string(), class: r.byte(),
    level: r.int32(),
  };
  r.skip(32); // Experience + MaxExperience (2×decimal)
  o.online = r.bool(); o.observable = r.bool();
  o.rebirth = r.int32(); o.rankChange = r.int32();
  return o;
}
// ClientRefineInfo (Globals.cs)
function readClientRefineInfo(r) {
  if (!r.bool()) return null;
  const o = { index: r.int32(), weapon: readClientUserItemFull(r), type: r.byte(), quality: r.byte(), chance: r.int32(), maxChance: r.int32() };
  r.int64(); // ReadyDuration
  return o;
}
// ClientFortuneInfo (Globals.cs)
function readClientFortuneInfo(r) {
  if (!r.bool()) return null;
  const o = { itemIndex: r.int32() };
  r.int64(); // CheckTime
  o.dropCount = r.int64();
  r.skip(16); // Progress decimal
  return o;
}
// ClientPlayerInfo (Globals.cs) — {uint ObjectID, string Name}
function readClientPlayerInfo(r) {
  if (!r.bool()) return null;
  return { objectID: r.uint32(), name: r.string() };
}

// StartInformation (Globals.cs:345-452) — 逐字段声明序 (byte 枚举=1B, 默认枚举=4B)
// MirClass/MirGender/MirDirection/AttackMode/PetMode/OnlineState/HorseType/ExteriorEffect=byte
export function readStartInformation(r) {
  const o = {};
  o.index = r.int32();
  o.objectID = r.uint32();
  o.name = r.string();
  o.caption = r.string();
  o.captionOutlineColour = r.int32();   // Color
  o.nameColour = r.int32();             // Color
  o.guildName = r.string(); o.guildRank = r.string();
  o.class = r.byte(); o.gender = r.byte();
  o.locationX = r.int32(); o.locationY = r.int32();  // Point
  o.direction = r.byte();
  o.mapIndex = r.int32();
  o.instanceIndex = r.int32();
  o.level = r.int32();
  o.hairType = r.int32();
  o.hairColour = r.int32();             // Color
  o.weapon = r.int32(); o.armour = r.int32(); o.costume = r.int32(); o.shield = r.int32();
  o.armourColour = r.int32();           // Color
  o.armourEffect = r.byte(); o.emblemEffect = r.byte();
  o.weaponEffect = r.byte(); o.shieldEffect = r.byte();
  r.skip(16);                           // Experience decimal
  o.currentHP = r.int32(); o.currentMP = r.int32(); o.currentFP = r.int32();
  o.attackMode = r.byte(); o.petMode = r.byte();
  o.onlineState = r.byte();
  o.discipline = readClientUserDiscipline(r);
  o.hermitPoints = r.int32();
  o.dayTime = r.float();
  o.timeOfDay = r.byte();
  o.timeOfDayLabel = r.string();
  o.allowGroup = r.bool(); o.allowTrade = r.bool();
  o.friends = r.list(readClientFriendInfo);
  o.items = r.list(readClientUserItemFull);
  o.beltLinks = r.list(readClientBeltLink);
  o.autoPotionLinks = r.list(readClientAutoPotionLink);
  o.milestones = r.list(readClientUserMilestone);
  o.magics = r.list(readClientUserMagic);
  o.buffs = r.list(readClientBuffInfo);
  o.currencies = r.list(readClientUserCurrency);
  o.poison = r.int32();                 // PoisonType (int)
  o.inSafeZone = r.bool();
  o.observable = r.bool();
  o.dead = r.bool();
  o.horse = r.byte();
  o.helmetShape = r.int32();
  o.horseShape = r.int32();
  o.hideHead = r.bool();
  o.quests = r.list(readClientUserQuest);
  o.companionUnlocks = r.list((rr) => rr.int32());
  o.companions = r.list(readClientUserCompanion);
  o.companion = r.int32();
  o.storageSize = r.int32();
  o.filtersClass = r.string(); o.filtersRarity = r.string(); o.filtersItemType = r.string();
  o.struckEnabled = r.bool(); o.hermitEnabled = r.bool();
  o.maxGemPurity = r.int32();
  return o;
}

// ---- C 包构造 ----
export const C = {
  Connected: () => new Writer().build(ID.G_CONNECTED),
  Ping: () => new Writer().build(ID.G_PING),
  SelectLanguage: (lang) => new Writer().string(lang).build(ID.C_SELECTLANGUAGE),
  Login: (email, password, checkSum) =>
    new Writer().string(email).string(password).string(checkSum).build(ID.C_LOGIN),
  NewAccount: (email, password, checkSum, realName = 'Player', birthDate = 0n, referral = '') =>
    new Writer().string(email).string(password).string(realName).string(referral)
      .int64(birthDate).string(checkSum).build(ID.C_NEWACCOUNT),
  NewCharacter: (name, cls, gender, hairType, hairColour, armourColour, checkSum) =>
    new Writer().string(name).byte(cls).byte(gender).int32(hairType)
      .int32(hairColour).int32(armourColour).string(checkSum).build(ID.C_NEWCHARACTER),
  DeleteCharacter: (characterIndex, checkSum) =>
    new Writer().int32(characterIndex).string(checkSum).build(ID.C_DELETECHARACTER),
  StartGame: (characterIndex) => new Writer().int32(characterIndex).build(ID.C_STARTGAME),
  Turn: (direction) => new Writer().byte(direction).build(ID.C_TURN),
  Move: (direction, distance) => new Writer().byte(direction).int32(distance).build(ID.C_MOVE),
  // ClientPackets.cs:237-241 — Text + List<int> LinkedItemIndexes (1B null+i32 count)
  Chat: (text, linkedItemIndexes = []) =>
    new Writer().string(text)
      .bool(linkedItemIndexes != null).int32(linkedItemIndexes?.length ?? 0)
      .build(ID.C_CHAT),
  // 移动/战斗
  Attack: (direction, action = 3, attackMagic = 0) =>
    new Writer().byte(direction).byte(action).int32(attackMagic).build(ID.C_ATTACK),
  Magic: (direction, action, type, target, x, y) =>
    new Writer().byte(direction).byte(action).int32(type).uint32(target).point(x, y).build(ID.C_MAGIC),
  Harvest: (direction) => new Writer().byte(direction).build(ID.C_HARVEST),
  Mining: (direction) => new Writer().byte(direction).build(ID.C_MINING),
  Mount: () => new Writer().build(ID.C_MOUNT),
  PickUp: () => new Writer().build(ID.C_PICKUP),
  ChangeAttackMode: (mode) => new Writer().byte(mode).build(ID.C_CHANGEATTACKMODE),
  ChangePetMode: (mode) => new Writer().byte(mode).build(ID.C_CHANGEPETMODE),
  TownRevive: () => new Writer().build(ID.C_TOWNREVIVE),
  // 物品
  ItemMove: (fromGrid, toGrid, fromSlot, toSlot, mergeItem = false) =>
    new Writer().int32(fromGrid).int32(toGrid).int32(fromSlot).int32(toSlot).bool(mergeItem).build(ID.C_ITEMMOVE),
  ItemSort: (grid) => new Writer().int32(grid).build(ID.C_ITEMSORT),
  ItemSplit: (grid, slot, count) =>
    new Writer().int32(grid).int32(slot).int64(count).build(ID.C_ITEMSPLIT),
  ItemDelete: (grid, slot) => new Writer().int32(grid).int32(slot).build(ID.C_ITEMDELETE),
  ItemDrop: (link, slot) => new Writer().cellLink(link).int32(slot).build(ID.C_ITEMDROP),
  ItemUse: (link) => new Writer().cellLink(link).build(ID.C_ITEMUSE),
  ItemLock: (grid, slot, locked) =>
    new Writer().int32(grid).int32(slot).bool(locked).build(ID.C_ITEMLOCK),
  CurrencyDrop: (currencyIndex, amount) =>
    new Writer().int32(currencyIndex).int64(amount).build(ID.C_CURRENCYDROP),
  BeltLinkChanged: (slot, linkIndex, linkItemIndex) =>
    new Writer().int32(slot).int32(linkIndex).int32(linkItemIndex).build(ID.C_BELTLINKCHANGED),
  AutoPotionLinkChanged: (slot, linkIndex, health, mana, enabled) =>
    new Writer().int32(slot).int32(linkIndex).int32(health).int32(mana).bool(enabled).build(ID.C_AUTOPOTIONLINKCHANGED),
  // NPC
  NPCCall: (objectID) => new Writer().uint32(objectID).build(ID.C_NPCCALL),
  NPCButton: (buttonID) => new Writer().int32(buttonID).build(ID.C_NPCBUTTON),
  NPCClose: () => new Writer().build(ID.C_NPCCLOSE),
  NPCBuy: (index, amount = 1, guildFunds = false) =>
    new Writer().int32(index).int64(amount).bool(guildFunds).build(ID.C_NPCBUY),
  NPCSell: (links) => new Writer().list(links, (w, l) => w.cellLink(l)).build(ID.C_NPCSELL),
  NPCRepair: (links, special = false, guildFunds = false) =>
    new Writer().list(links, (w, l) => w.cellLink(l)).bool(special).bool(guildFunds).build(ID.C_NPCREPAIR),
  NPCRoll: (type) => new Writer().int32(type).build(ID.C_NPCROLL),
  // 任务
  QuestAccept: (index) => new Writer().int32(index).build(ID.C_QUESTACCEPT),
  QuestComplete: (index, choiceIndex = 0) =>
    new Writer().int32(index).int32(choiceIndex).build(ID.C_QUESTCOMPLETE),
  QuestAbandon: (index) => new Writer().int32(index).build(ID.C_QUESTABANDON),
  QuestTrack: (index, track) => new Writer().int32(index).bool(track).build(ID.C_QUESTTRACK),
  // 组队
  GroupInvite: (name) => new Writer().string(name).build(ID.C_GROUPINVITE),
  GroupRemove: (name) => new Writer().string(name).build(ID.C_GROUPREMOVE),
  GroupResponse: (name, accept) => new Writer().string(name).bool(accept).build(ID.C_GROUPRESPONSE),
  GroupRequest: (name) => new Writer().string(name).build(ID.C_GROUPREQUEST),
  GroupSwitch: (allow) => new Writer().bool(allow).build(ID.C_GROUPSWITCH),
  GroupNotify: (receive) => new Writer().bool(receive).build(ID.C_GROUPNOTIFY),
  GroupLFGUpdate: (enabled, name, type, maxCount) =>
    new Writer().bool(enabled).string(name).string(type).int32(maxCount).build(ID.C_GROUPLFGUPDATE),
  // 交易
  TradeRequestResponse: (accept) => new Writer().bool(accept).build(ID.C_TRADEREQUESTRESPONSE),
  TradeClose: () => new Writer().build(ID.C_TRADECLOSE),
  TradeConfirm: () => new Writer().build(ID.C_TRADECONFIRM),
  TradeAddGold: (gold) => new Writer().int64(gold).build(ID.C_TRADEADDGOLD),
  TradeAddItem: (cell) => new Writer().cellLink(cell).build(ID.C_TRADEADDITEM),
  // 行会
  GuildCreate: (name) => new Writer().string(name).build(ID.C_GUILDCREATE),
  GuildResponse: (accept) => new Writer().bool(accept).build(ID.C_GUILDRESPONSE),
  GuildEditNotice: (notice) => new Writer().string(notice).build(ID.C_GUILDEDITNOTICE),
  // 邮件
  MailOpened: (index) => new Writer().int32(index).build(ID.C_MAILOPENED),
  MailSend: (links, recipient, subject, message, gold = 0) =>
    new Writer().list(links, (w, l) => w.cellLink(l))
      .string(recipient).string(subject).string(message).int64(gold).build(ID.C_MAILSEND),
  MailGetItem: (index, slot) => new Writer().int32(index).int32(slot).build(ID.C_MAILGETITEM),
  MailDelete: (index) => new Writer().int32(index).build(ID.C_MAILDELETE),
  // 社交
  FriendAdd: (name) => new Writer().string(name).build(ID.C_FRIENDADD),
  FriendRemove: (index) => new Writer().int32(index).build(ID.C_FRIENDREMOVE),
  BlockAdd: (name) => new Writer().string(name).build(ID.C_BLOCKADD),
  BlockRemove: (index) => new Writer().int32(index).build(ID.C_BLOCKREMOVE),
  Inspect: (index, ranking = false) => new Writer().int32(index).bool(ranking).build(ID.C_INSPECT),
  ObserverRequest: (name) => new Writer().string(name).build(ID.C_OBSERVERREQUEST),
  ObservableSwitch: (allow) => new Writer().bool(allow).build(ID.C_OBSERVABLESWITCH),
  // 排行/寄售/商城
  RankRequest: (cls = 255, onlineOnly = false, startIndex = 0) =>
    new Writer().byte(cls).bool(onlineOnly).int32(startIndex).build(ID.C_RANKREQUEST),
  RankSearch: (name) => new Writer().string(name).build(ID.C_RANKSEARCH),
  MarketPlaceSearch: (name, itemTypeFilter = false, itemType = 0, sort = 0) =>
    new Writer().string(name).bool(itemTypeFilter).byte(itemType).int32(sort).build(ID.C_MARKETPLACESEARCH),
  MarketPlaceHistory: (index, display = 0, partIndex = 0) =>
    new Writer().int32(index).int32(display).int32(partIndex).build(ID.C_MARKETPLACEHISTORY),
  MarketPlaceConsign: (link, price, message = '', guildFunds = false) =>
    new Writer().cellLink(link).int32(price).string(message).bool(guildFunds).build(ID.C_MARKETPLACECONSIGN),
  MarketPlaceCancelConsign: (index, count) =>
    new Writer().int32(index).int64(count).build(ID.C_MARKETPLACECANCELCONSIGN),
  MarketPlaceBuy: (index, count, guildFunds = false) =>
    new Writer().int64(index).int64(count).bool(guildFunds).build(ID.C_MARKETPLACEBUY),
  GameStoreGift: (index, count, useHuntGold, recipient) =>
    new Writer().int32(index).int64(count).bool(useHuntGold).string(recipient).build(ID.C_GAMESTOREGIFT),
  GameStoreFavouriteToggle: (index) => new Writer().int32(index).build(ID.C_GAMESTOREFAVOURITETOGGLE),
  // 技能
  MagicKey: (magic, set1, set2, set3, set4) =>
    new Writer().int32(magic).byte(set1).byte(set2).byte(set3).byte(set4).build(ID.C_MAGICKEY),
  MagicToggle: (magic, canUse) =>
    new Writer().int32(magic).bool(canUse).build(ID.C_MAGICTOGGLE),
  Hermit: (stat) => new Writer().int32(stat).build(ID.C_HERMIT),
  // 宠物/杂项
  CompanionAdopt: (index, name) => new Writer().int32(index).string(name).build(ID.C_COMPANIONADOPT),
  CompanionRetrieve: (index) => new Writer().int32(index).build(ID.C_COMPANIONRETRIEVE),
  CompanionRelease: (index) => new Writer().int32(index).build(ID.C_COMPANIONRELEASE),
  CompanionUnlock: (index) => new Writer().int32(index).build(ID.C_COMPANIONUNLOCK),
  FortuneCheck: (itemIndex) => new Writer().int32(itemIndex).build(ID.C_FORTUNECHECK),
  HelmetToggle: (hideHelmet) => new Writer().bool(hideHelmet).build(ID.C_HELMETTOGGLE),
  ChangeOnlineState: (state) => new Writer().byte(state).build(ID.C_CHANGEONLINESTATE),
  Logout: () => new Writer().build(ID.C_LOGOUT),
  TeleportRing: (x, y, index = 0) => new Writer().int32(x).int32(y).int32(index).build(ID.C_TELEPORTRING),
  JoinInstance: (index) => new Writer().int32(index).build(ID.C_JOININSTANCE),
  MilestoneClaim: (index) => new Writer().int32(index).build(ID.C_MILESTONECLAIM),
  MilestoneActive: (index, active) => new Writer().int32(index).bool(active).build(ID.C_MILESTONEACTIVE),
  LootBoxOpen: (slot) => new Writer().int32(slot).build(ID.C_LOOTBOXOPEN),
  BundleOpen: (slot) => new Writer().int32(slot).build(ID.C_BUNDLEOPEN),
  BundleConfirm: (slot, choice) => new Writer().int32(slot).int32(choice).build(ID.C_BUNDLECONFIRM),
};

// Dictionary<BuffType(int32),int32> — Dictionary 也是 class → 1B null 标志 + i32 count + (k,v)
function readBuffDict(r) {
  if (!r.bool()) return null;
  const n = r.int32();
  const out = {};
  for (let i = 0; i < n; i++) { const k = r.int32(); out[k] = r.int32(); }
  return out;
}

// ---- S 包解析 (声明序) ----
export const S = {
  GoodVersion(r) { // DatabaseKey byte[] + SystemDatabaseVersion string
    return { databaseKey: r.blob(), systemDatabaseVersion: r.string() };
  },
  Disconnect(r) { return { reason: r.byte() }; },
  PingResponse(r) { return { ping: r.int32() }; },
  Login(r) { // ServerPackets.cs:25-43
    const result = r.byte(), message = r.string(), duration = r.int64();
    const characters = r.list((rr) => rr.bool() ? readSelectInfo(rr) : null);
    const items = r.list(readClientUserItemFull);
    const blockList = r.list(readClientBlockInfo);
    const address = r.string(), testServer = r.bool(), isGM = r.bool();
    return { result, message, duration, characters, items, blockList, address, testServer, isGM };
  },
  NewAccount(r) { return { result: r.byte(), message: r.string(), duration: r.int64() }; },
  NewCharacter(r) {
    const result = r.byte();
    const character = r.bool() ? readSelectInfo(r) : null;
    return { result, character };
  },
  DeleteCharacter(r) { return { result: r.byte(), deletedIndex: r.int32() }; },
  StartGame(r) { // ServerPackets.cs:82-90
    const result = r.byte(), message = r.string(), duration = r.int64();
    const startInformation = r.bool() ? readStartInformation(r) : null;
    return { result, message, duration, startInformation };
  },
  MapChanged(r) { return { mapIndex: r.int32(), instanceIndex: r.int32() }; },
  UserLocation(r) { return { direction: r.byte(), x: r.int32(), y: r.int32() }; },
  ObjectMove(r) { // ServerPackets.cs:149-156
    return {
      objectID: r.uint32(), direction: r.byte(), x: r.int32(), y: r.int32(),
      distance: r.int32(), slow: r.int64(), mapChanged: r.bool(),
    };
  },
  ObjectTurn(r) { // ServerPackets.cs:105-111
    return { objectID: r.uint32(), direction: r.byte(), x: r.int32(), y: r.int32(), slow: r.int64() };
  },
  ObjectRemove(r) { return { objectID: r.uint32() }; },
  ObjectPlayer(r) { // ServerPackets.cs:290-339 — 属性声明序; 末尾 3 个 public 字段不序列化
    const p = {
      index: r.int32(), objectID: r.uint32(), name: r.string(), caption: r.string(),
      captionOutlineColour: r.int32(), nameColour: r.int32(), guildName: r.string(),
      direction: r.byte(), x: r.int32(), y: r.int32(),
      class: r.byte(), gender: r.byte(), hairType: r.int32(), hairColour: r.int32(),
      weapon: r.int32(), shield: r.int32(), armour: r.int32(), costume: r.int32(),
      armourColour: r.int32(), armourEffect: r.byte(), emblemEffect: r.byte(),
      weaponEffect: r.byte(), shieldEffect: r.byte(),
      light: r.int32(), sizePercent: r.int32(),
      dead: r.bool(), poison: r.int32(),
      buffs: readBuffDict(r), horse: r.byte(), helmet: r.int32(), horseShape: r.int32(),
    };
    return p;
  },
  ObjectMonster(r) { // ServerPackets.cs:340-367
    const m = {
      objectID: r.uint32(), monsterIndex: r.int32(), customName: r.string(),
      nameColour: r.int32(), petOwner: r.string(),
      direction: r.byte(), x: r.int32(), y: r.int32(),
      dead: r.bool(), skeleton: r.bool(), poison: r.int32(),
      easterEvent: r.bool(), halloweenEvent: r.bool(), christmasEvent: r.bool(),
      buffs: readBuffDict(r), extra: r.bool(), extra1: r.int32(), colour: r.int32(),
    };
    // CompanionObject: class → bool; 非空时 Name/HeadShape/BackShape (Globals.cs:1055-1061)
    if (r.bool()) m.companionObject = { name: r.string(), headShape: r.int32(), backShape: r.int32() };
    else m.companionObject = null;
    return m;
  },
  ObjectNPC(r) { // ServerPackets.cs:369-378
    return {
      objectID: r.uint32(), npcIndex: r.int32(), x: r.int32(), y: r.int32(), direction: r.byte(),
    };
  },
  // ServerPackets.cs:641-648 — ObjectID u32 + Text str + Type int32 + LinkedItems + OverheadOnly
  Chat(r) {
    const objectID = r.uint32(), text = r.string(), type = r.int32();
    const linkedItems = r.list(readClientUserItemFull);
    const overheadOnly = r.bool();
    return { objectID, text, type, linkedItems, overheadOnly };
  },
  DayChanged(r) { return { dayTime: r.float() }; }, // ServerPackets.cs:436-439
  // ---- 战斗/对象事件 ----
  ObjectAttack(r) { // ServerPackets.cs:180-190
    return {
      objectID: r.uint32(), direction: r.byte(), location: r.point(),
      attackMagic: r.int32(), attackElement: r.byte(), targetID: r.uint32(), slow: r.int64(),
    };
  },
  ObjectStruck(r) {
    return {
      objectID: r.uint32(), direction: r.byte(), location: r.point(),
      attackerID: r.uint32(), element: r.byte(),
    };
  },
  ObjectDied(r) {
    return { objectID: r.uint32(), direction: r.byte(), location: r.point() };
  },
  ObjectHarvest(r) {
    return { objectID: r.uint32(), direction: r.byte(), location: r.point(), slow: r.int64() };
  },
  ObjectPushed(r) {
    return { objectID: r.uint32(), direction: r.byte(), location: r.point() };
  },
  ObjectDash(r) {
    return { objectID: r.uint32(), direction: r.byte(), location: r.point(), distance: r.int32(), magic: r.int32() };
  },
  ObjectShow(r) { return { objectID: r.uint32(), direction: r.byte(), location: r.point() }; },
  ObjectHide(r) { return { objectID: r.uint32(), direction: r.byte(), location: r.point() }; },
  ObjectIdle(r) { return { objectID: r.uint32(), direction: r.byte(), location: r.point(), type: r.int32() }; },
  ObjectRevive(r) { return { objectID: r.uint32(), location: r.point(), effect: r.bool() }; },
  ObjectLeveled(r) { return { objectID: r.uint32() }; },
  ObjectEffect(r) { return { objectID: r.uint32(), effect: r.int32() }; },
  ObjectPoison(r) { return { objectID: r.uint32(), poison: r.int32() }; },
  ObjectMount(r) { return { objectID: r.uint32(), horse: r.byte() }; },
  ObjectPetOwnerChanged(r) { return { objectID: r.uint32(), petOwner: r.string() }; },
  ObjectNameColour(r) { return { objectID: r.uint32(), colour: r.int32() }; },
  ObjectBuffAdd(r) { return { objectID: r.uint32(), type: r.int32(), extra: r.int32() }; },
  ObjectBuffRemove(r) { return { objectID: r.uint32(), type: r.int32() }; },
  ObjectMagic(r) {
    const o = {
      objectID: r.uint32(), direction: r.byte(), location: r.point(),
      type: r.int32(),
    };
    o.targets = r.list((rr) => rr.uint32());
    o.locations = r.list((rr) => rr.point());
    o.cast = r.bool(); o.attackElement = r.byte(); o.slow = r.int64();
    return o;
  },
  ObjectProjectile(r) {
    const o = { objectID: r.uint32(), direction: r.byte(), location: r.point(), type: r.int32() };
    o.targets = r.list((rr) => rr.uint32());
    o.locations = r.list((rr) => rr.point());
    return o;
  },
  ObjectRangeAttack(r) {
    const o = {
      objectID: r.uint32(), direction: r.byte(), location: r.point(),
      attackMagic: r.int32(), attackElement: r.byte(),
    };
    o.targets = r.list((rr) => rr.uint32());
    return o;
  },
  ObjectSpell(r) { return { objectID: r.uint32(), direction: r.byte(), location: r.point(), effect: r.int32(), power: r.int32() }; },
  ObjectSpellChanged(r) { return { objectID: r.uint32(), power: r.int32() }; },
  ObjectStats(r) { return { objectID: r.uint32(), stats: readStats(r) }; },
  ObjectItem(r) {
    return { objectID: r.uint32(), item: readClientUserItemFull(r), location: r.point() };
  },
  ObjectMining(r) { return { objectID: r.uint32(), direction: r.byte(), location: r.point(), slow: r.int64(), effect: r.bool() }; },
  ObjectFishing(r) { return { objectID: r.uint32(), state: r.byte(), direction: r.byte(), floatLocation: r.point(), fishFound: r.bool() }; },
  ObjectTaming(r) { return { objectID: r.uint32(), state: r.byte(), direction: r.byte(), tamingObjectID: r.uint32() }; },
  ObjectHarvested(r) { return { objectID: r.uint32(), direction: r.byte(), location: r.point() }; },
  // ---- 状态 ----
  StatsUpdate(r) { // ServerPackets.cs:502-507
    return { stats: readStats(r), hermitStats: readStats(r), hermitPoints: r.int32() };
  },
  HealthChanged(r) {
    return { objectID: r.uint32(), change: r.int32(), miss: r.bool(), block: r.bool(), critical: r.bool(), resist: r.bool() };
  },
  ManaChanged(r) { return { objectID: r.uint32(), change: r.int32() }; },
  FocusChanged(r) { return { objectID: r.uint32(), change: r.int32() }; },
  LevelChanged(r) {
    const o = { level: r.int32() };
    r.skip(32); // Experience + MaxExperience (2×decimal 16B)
    return o;
  },
  GainedExperience(r) { r.skip(16); return {}; }, // decimal
  InformMaxExperience(r) { r.skip(16); return {}; },
  MagicLeveled(r) { return { infoIndex: r.int32(), level: r.int32(), experience: r.int64() }; },
  MagicCooldown(r) { return { infoIndex: r.int32(), delay: r.int32() }; },
  MagicToggle(r) { return { magic: r.int32(), canUse: r.bool() }; },
  NewMagic(r) {
    return { magic: (r => { if (!r.bool()) return null; return {
      index: r.int32(), infoIndex: r.int32(),
      set1Key: r.byte(), set2Key: r.byte(), set3Key: r.byte(), set4Key: r.byte(),
      level: r.int32(), experience: r.int64(), itemRequired: r.bool(),
    }; })(r) };
  },
  WeightUpdate(r) { return { bagWeight: r.int32(), wearWeight: r.int32(), handWeight: r.int32() }; },
  SafeZoneChanged(r) { return { inSafeZone: r.bool() }; },
  CombatTime(r) { return {}; },
  SetTimer(r) { return { key: r.string(), type: r.byte(), seconds: r.int32() }; },
  MapEffect(r) { return { location: r.point(), effect: r.int32(), direction: r.byte() }; },
  ReviveTimers(r) { return { itemReviveTime: r.int64(), reincarnationPillTime: r.int64() }; },
  ChangeAttackMode(r) { return { mode: r.byte() }; },
  ChangePetMode(r) { return { mode: r.byte() }; },
  HelmetToggle(r) { return { hideHelmet: r.bool() }; },
  PlayerUpdate(r) { // ServerPackets.cs — 装备外观变化
    return {
      objectID: r.uint32(), weapon: r.int32(), shield: r.int32(), armour: r.int32(),
      costume: r.int32(), armourColour: r.int32(),
      armourEffect: r.byte(), emblemEffect: r.byte(), weaponEffect: r.byte(), shieldEffect: r.byte(),
      horseArmour: r.int32(), helmet: r.int32(), light: r.int32(), sizePercent: r.int32(),
      hideHead: r.bool(),
    };
  },
  PlayerChangeUpdate(r) {
    return {
      objectID: r.uint32(), name: r.string(), caption: r.string(),
      captionOutlineColour: r.int32(), gender: r.byte(), hairType: r.int32(),
      hairColour: r.int32(), armourColour: r.int32(),
    };
  },
  // ---- 物品 ----
  ItemsChanged(r) { return { links: r.list(readCellLinkInfo), success: r.bool() }; },
  ItemsGained(r) { return { items: r.list(readClientUserItemFull) }; },
  ItemChanged(r) { return { link: readCellLinkInfo(r), success: r.bool() }; },
  ItemDelete(r) { return { grid: r.int32(), slot: r.int32(), success: r.bool() }; },
  ItemMove(r) { // ServerPackets.cs:562-571
    return { fromGrid: r.int32(), toGrid: r.int32(), fromSlot: r.int32(), toSlot: r.int32(),
             mergeItem: r.bool(), success: r.bool() };
  },
  ItemSort(r) { // ServerPackets.cs:573-578
    return { grid: r.int32(), items: r.list(readClientUserItemFull), success: r.bool() };
  },
  ItemSplit(r) { // ServerPackets.cs:580-588
    return { grid: r.int32(), slot: r.int32(), count: r.int64(), newSlot: r.int32(), success: r.bool() };
  },
  ItemUseDelay(r) { return { delay: r.int64() }; },
  ItemDurability(r) { return { gridType: r.int32(), slot: r.int32(), currentDurability: r.int32() }; }, // ServerPackets.cs:627-632
  ItemLock(r) { return { grid: r.int32(), slot: r.int32(), locked: r.bool() }; },
  ItemStatsChanged(r) { return { gridType: r.int32(), slot: r.int32(), newStats: readStats(r) }; },
  ItemStatsRefreshed(r) { return { gridType: r.int32(), slot: r.int32(), newStats: readStats(r) }; },
  ItemExperience(r) { const target = readCellLinkInfo(r); r.skip(16); return { target, level: r.int32(), flags: r.int32() }; },
  ItemAcessoryRefined(r) { return { gridType: r.int32(), slot: r.int32(), newStats: readStats(r) }; },
  // ---- Buff ----
  BuffAdd(r) { return { buff: readClientBuffInfo(r) }; },
  BuffRemove(r) { return { index: r.int32() }; },
  BuffChanged(r) { return { index: r.int32(), stats: readStats(r) }; },
  BuffTime(r) { return { index: r.int32(), time: r.int64() }; },
  BuffPaused(r) { return { index: r.int32(), paused: r.bool() }; },
  // ---- NPC ----
  NPCResponse(r) { return { objectID: r.uint32(), index: r.int32(), values: r.list(readClientNPCValues) }; },
  NPCClose(r) { return {}; },
  NPCRoll(r) { return { value: r.int32() }; },
  // ---- 任务 ----
  QuestChanged(r) { return { quest: readClientUserQuest(r) }; },
  QuestCancelled(r) { return { index: r.int32() }; },
  // ---- 数据对象 (大地图/查找) ----
  DataObjectLocation(r) { return { objectID: r.uint32(), mapIndex: r.int32(), location: r.point() }; },
  DataObjectMaxHealthMana(r) { return { objectID: r.uint32(), maxHealth: r.int32(), maxMana: r.int32(), stats: readStats(r) }; },
  DataObjectMonster(r) {
    const o = { objectID: r.uint32(), mapIndex: r.int32(), location: r.point(), monsterIndex: r.int32(), petOwner: r.string(), health: r.int32(), stats: readStats(r), dead: r.bool() };
    return o;
  },
  DataObjectPlayer(r) { return { objectID: r.uint32(), mapIndex: r.int32(), location: r.point(), name: r.string(), health: r.int32(), mana: r.int32(), dead: r.bool(), maxHealth: r.int32(), maxMana: r.int32() }; },
  DataObjectRemove(r) { return { objectID: r.uint32() }; },
  DataObjectItem(r) { return { objectID: r.uint32(), mapIndex: r.int32(), location: r.point(), itemIndex: r.int32() }; },
  DataObjectHealthMana(r) { return { objectID: r.uint32(), health: r.int32(), mana: r.int32(), dead: r.bool() }; },
  // ---- 组队/行会/社交 ----
  GroupInvite(r) { return { name: r.string() }; },
  GroupMember(r) { return { objectID: r.uint32(), name: r.string() }; },
  GroupRemove(r) { return { objectID: r.uint32() }; },
  GroupSwitch(r) { return { allow: r.bool() }; },
  GroupUpdate(r) { return { group: readClientLookingForGroup(r) }; },
  GroupRequest(r) { return { name: r.string(), level: r.int32(), class: r.byte() }; },
  GroupLFG(r) { return { list: r.list(readClientLookingForGroup) }; },
  GuildInfo(r) { return { guild: readClientGuildInfo(r) }; },
  GuildInvite(r) { return { name: r.string(), guildName: r.string() }; },
  GuildChanged(r) { return { objectID: r.uint32(), guildName: r.string(), guildRank: r.string() }; },
  GuildNoticeChanged(r) { return { notice: r.string() }; },
  GuildUpdate(r) {
    const o = {
      memberLimit: r.int32(), storageLimit: r.int32(), guildFunds: r.int64(),
      dailyGrowth: r.int64(), guildLevel: r.int32(), tax: r.int32(),
      totalContribution: r.int64(), dailyContribution: r.int64(),
      defaultRank: r.string(), defaultPermission: r.int32(), colour: r.int32(), flag: r.int32(),
    };
    o.members = r.list(readClientGuildMemberInfo);
    return o;
  },
  GuildNewItem(r) { return { slot: r.int32(), item: readClientUserItemFull(r), count: r.int32() }; },
  GuildGetItem(r) { return { grid: r.int32(), slot: r.int32(), item: readClientUserItemFull(r) }; },
  GuildMemberOnline(r) { return { index: r.int32(), name: r.string(), objectID: r.uint32() }; },
  GuildMemberOffline(r) { return { index: r.int32() }; },
  GuildFundsChanged(r) { return { change: r.int64() }; },
  GuildStats(r) { return { index: r.int32(), stats: readStats(r) }; },
  GuildCreate(r) { return {}; },
  GuildKick(r) { return { index: r.int32() }; },
  GuildWarStarted(r) { return { guildName: r.string(), duration: r.int64() }; },
  GuildWarFinished(r) { return { guildName: r.string() }; },
  GuildCastleInfo(r) { return { index: r.int32(), owner: r.string() }; },
  MarriageInfo(r) { return { partner: readClientPlayerInfo(r) }; },
  MarriageInvite(r) { return { name: r.string() }; },
  FriendAdd(r) { return { info: readClientFriendInfo(r) }; },
  FriendRemove(r) { return { index: r.int32() }; },
  FriendUpdate(r) { return { info: readClientFriendInfo(r) }; },
  BlockAdd(r) { return { info: readClientBlockInfo(r) }; },
  BlockRemove(r) { return { index: r.int32() }; },
  // ---- 交易 ----
  TradeOpen(r) { return { name: r.string() }; },
  TradeClose(r) { return {}; },
  TradeUnlock(r) { return {}; },
  TradeItemAdded(r) { return { item: readClientUserItemFull(r) }; },
  TradeGoldAdded(r) { return { gold: r.int64() }; },
  TradeAddItem(r) { return { cell: readCellLinkInfo(r), success: r.bool() }; },
  TradeAddGold(r) { return { gold: r.int64() }; },
  TradeRequest(r) { return { name: r.string() }; },
  // ---- 邮件 ----
  MailList(r) { return { mail: r.list(readClientMailInfo) }; },
  MailNew(r) { return { mail: readClientMailInfo(r) }; },
  MailItemDelete(r) { return { index: r.int32(), slot: r.int32() }; },
  MailDelete(r) { return { index: r.int32() }; },
  MailSend(r) { return {}; },
  // ---- 仓库/货币/杂项 ----
  StorageSize(r) { return { size: r.int32() }; },
  CurrencyChanged(r) { return { currencyIndex: r.int32(), amount: r.int64() }; },
  FortuneUpdate(r) { return { fortunes: r.list(readClientFortuneInfo) }; },
  RefineList(r) { return { list: r.list(readClientRefineInfo) }; },
  Inspect(r) {
    const o = { name: r.string(), guildName: r.string(), guildRank: r.string(), guildFlag: r.int32(), guildColour: r.int32(), partner: r.string(), class: r.byte(), level: r.int32(), gender: r.byte() };
    o.stats = readStats(r); o.hermitStats = readStats(r); o.hermitPoints = r.int32();
    o.items = r.list(readClientUserItemFull);
    o.hair = r.int32(); o.hairColour = r.int32(); o.fame = r.int32();
    o.wearWeight = r.int32(); o.handWeight = r.int32(); o.ranking = r.bool();
    return o;
  },
  Rankings(r) {
    const o = { onlineOnly: r.bool(), class: r.byte(), startIndex: r.int32(), total: r.int32(), allowObservation: r.bool() };
    o.ranks = r.list(readRankInfo);
    return o;
  },
  RankSearch(r) { return { rank: readRankInfo(r), startIndex: r.int32() }; },
  MarketPlaceConsign(r) { return { consignments: r.list(readClientMarketPlaceInfo) }; },
  MarketPlaceHistory(r) { return { index: r.int32(), saleCount: r.int64(), lastPrice: r.int64(), averagePrice: r.int64(), display: r.int32() }; },
  MarketPlaceSearch(r) { const o = { count: r.int32() }; o.results = r.list(readClientMarketPlaceInfo); return o; },
  MarketPlaceSearchCount(r) { return { count: r.int32() }; },
  MarketPlaceSearchIndex(r) { return { index: r.int32(), result: readClientMarketPlaceInfo(r) }; },
  MarketPlaceBuy(r) { return { index: r.int32(), count: r.int64(), success: r.bool() }; },
  MarketPlaceConsignChanged(r) { return { index: r.int32(), count: r.int64() }; },
  GameStoreData(r) {
    const o = {};
    o.favourites = r.list((rr) => rr.int32());
    o.topItems = r.list((rr) => rr.int32());
    return o;
  },
  GameStoreTopItems(r) { return { items: r.list((rr) => rr.int32()) }; },
  GameStoreFavouriteChanged(r) { return { index: r.int32(), favourited: r.bool() }; },
  GameStoreGift(r) { return { result: r.byte() }; }, // ServerPackets.cs:904-907
  CompanionUpdate(r) { return { level: r.int32(), experience: r.int32(), hunger: r.int32() }; },
  CompanionWeightUpdate(r) { return { bagWeight: r.int32(), maxBagWeight: r.int32(), inventorySize: r.int32() }; },
  CompanionAdopt(r) { return { userCompanion: readClientUserCompanion(r) }; },
  MilestoneEarned(r) { return { index: r.int32() }; },
  UserMilestones(r) { return { milestones: r.list(readClientUserMilestone) }; },
  DisciplineUpdate(r) { return { discipline: readClientUserDiscipline(r) }; },
  TimeOfDayChanged(r) { return { timeOfDay: r.byte(), label: r.string() }; },
  GameLogout(r) { return { characters: r.list((rr) => rr.bool() ? readSelectInfo(rr) : null) }; },
  SelectLogout(r) { return {}; },
  ObservableSwitch(r) { return { allow: r.bool() }; },
  LootBoxOpen(r) {
    const o = { slot: r.int32() };
    o.items = r.list((rr) => { if (!rr.bool()) return null; return { itemIndex: rr.int32(), amount: rr.int32(), slot: rr.int32() }; });
    return o;
  },
  LootBoxClose(r) { return {}; },
  BundleOpen(r) {
    const o = { slot: r.int32() };
    o.items = r.list((rr) => { if (!rr.bool()) return null; return { itemIndex: rr.int32(), amount: rr.int32(), slot: rr.int32() }; });
    return o;
  },
  BundleClose(r) { return {}; },
  JoinInstance(r) { return { result: r.byte(), success: r.bool() }; },
  FishingStats(r) { return { ...(() => { const o = {}; try { o.attempts = r.int32(); o.success = r.int32(); o.catches = r.int32(); o.misses = r.int32(); o.streak = r.int32(); o.bestStreak = r.int32(); o.perfectCatches = r.int32(); } catch { /* 尾部字段不足忽略 */ } return o; })() }; },
};

// packet id → 名 (诊断)
export const IDName = Object.fromEntries(Object.entries(ID).map(([k, v]) => [v, k]));
