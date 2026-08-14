// net.js — Zircon 协议编解码 (从 LibraryCore/Network/Packet.cs 移植)
// 帧格式 (Packet.cs:146-187): [int32 LE 总长(含自身4B)][int16 LE packet id][payload]
// 序列化规则 (Packet.cs:189-303):
//   属性按声明序; string=7bit varint 长度+UTF8; byte[]=int32 len+bytes;
//   enum=底层类型; class 属性=1B null标志+字段; List<T>=1B null+int32 count+元素
//   (原始/枚举元素裸写, class 元素=1B null+字段); Dictionary 同理;
//   TimeSpan=i64 ticks; DateTime=i64 ToBinary; Color=i32 ARGB; Point=2×i32。
// packet id 全部来自 packet_id_dump 反射导出 (Tools/wsgateway/packet_id_dump),
// 对 Debug/ServerCore/LibraryCore.dll 反射; 禁止手推 (任何包类增删都会移位)。

// ---- Packet IDs (packet_id_dump 2026-08-14 实跑导出, login_client.py 交叉验证) ----
export const ID = {
  G_CHECKVERSION: 0, G_CONNECTED: 1, G_DISCONNECT: 2, G_GOODVERSION: 3,
  G_PING: 4, G_PINGRESPONSE: 5, G_VERSION: 6,
  C_LOGIN: 182, S_LOGIN: 183,
  C_NEWACCOUNT: 278, S_NEWACCOUNT: 277,
  C_NEWCHARACTER: 280, S_NEWCHARACTER: 279,
  C_DELETECHARACTER: 67, S_DELETECHARACTER: 68,
  C_SELECTLANGUAGE: 343,
  C_STARTGAME: 349, S_STARTGAME: 348,
  S_MAPCHANGED: 208, S_USERLOCATION: 373,
  C_MOVE: 240, C_TURN: 372, C_CHAT: 76,
  S_OBJECTMOVE: 299, S_OBJECTTURN: 316, S_OBJECTREMOVE: 308,
  S_OBJECTPLAYER: 303, S_OBJECTMONSTER: 297, S_OBJECTNPC: 300, S_OBJECTITEM: 293,
  S_CHAT: 39,
};

// ---- 枚举 (LibraryCore/Enum.cs; byte 底层) ----
export const LoginResultText = {
  0: '账号被禁用', 1: '密码错误', 2: '账号不存在', 3: '密码错误(多次)',
  4: '账号被封禁', 5: 'IP 不匹配', 6: '账号被锁定', 7: '账号已在游戏中',
  8: '等待审批', 9: '请完善注册信息', 10: '成功',
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
  0: '禁止注册', 1: '账号格式错误', 2: '密码格式错误', 3: '邮箱格式错误',
  4: '推荐人不存在', 5: '推荐已完成', 6: '成功', 7: '账号已存在',
};
export const NEWACCOUNT_SUCCESS = 6, NEWACCOUNT_ALREADY = 7;
export const DisconnectReasonText = {
  0: '未知', 1: '超时', 2: '版本不符', 3: '服务器关闭', 4: '另一处登录', 5: '被踢', 6: '崩溃',
};

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
  o.colour = r.int32();    // Color ARGB
  r.int64();               // SpecialRepairCoolDown
  r.int64();               // ResetCoolDown
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

// Stats (Stat.cs:10): 唯一序列化属性 Values = SortedDictionary<Stat,int>
function readStats(r) {
  if (!r.bool()) return null;
  if (!r.bool()) return null;   // dict null 标志
  const n = r.int32();
  const out = [];
  for (let i = 0; i < n; i++) out.push([r.int32(), r.int32()]);
  return { values: out };
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
// StartInformation (Globals.cs:345-452) — 逐字段声明序
export function readStartInformation(r) {
  const o = {};
  o.index = r.int32();
  o.objectID = r.uint32();
  o.name = r.string();
  o.caption = r.string();
  o.captionOutlineColour = r.int32();
  o.nameColour = r.int32();
  o.guildName = r.string();
  o.guildRank = r.string();
  o.class = r.byte();
  o.gender = r.byte();
  o.locationX = r.int32(); o.locationY = r.int32();
  o.direction = r.byte();
  o.mapIndex = r.int32();
  o.instanceIndex = r.int32();
  o.level = r.int32();
  o.hairType = r.int32();
  o.hairColour = r.int32();
  o.weapon = r.int32();
  o.armour = r.int32();
  o.costume = r.int32();
  o.shield = r.int32();
  o.armourColour = r.int32();
  o.armourEffect = r.byte();
  o.emblemEffect = r.byte();
  o.weaponEffect = r.byte();
  o.shieldEffect = r.byte();
  o.experience = r.skip(16); // decimal 16B (Phase1 不用数值)
  o.currentHP = r.int32();
  o.currentMP = r.int32();
  o.currentFP = r.int32();
  o.attackMode = r.byte();
  o.petMode = r.byte();
  o.onlineState = r.byte();
  o.discipline = readClientUserDiscipline(r);
  o.hermitPoints = r.int32();
  o.dayTime = r.float();
  o.timeOfDay = r.byte();
  o.timeOfDayLabel = r.string();
  o.allowGroup = r.bool();
  o.allowTrade = r.bool();
  o.friends = r.list(readClientFriendInfo);
  o.items = r.list(readClientUserItemFull);
  o.beltLinks = r.list(readClientBeltLink);
  o.autoPotionLinks = r.list(readClientAutoPotionLink);
  o.milestones = r.list(readClientUserMilestone);
  o.magics = r.list(readClientUserMagic);
  o.buffs = r.list(readClientBuffInfo);
  o.currencies = r.list(readClientUserCurrency);
  o.poison = r.int32();
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
  o.filtersClass = r.string();
  o.filtersRarity = r.string();
  o.filtersItemType = r.string();
  o.struckEnabled = r.bool();
  o.hermitEnabled = r.bool();
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
  Chat: (text) => new Writer().string(text).build(ID.C_CHAT),
};

// Dictionary<BuffType(int32),int32> — 1B null + i32 count + (k i32, v i32)
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
    const blockList = r.list((rr) => rr.bool() ? ({ index: rr.int32(), name: rr.string() }) : null);
    const address = r.string(), testServer = r.bool(), isGM = r.bool();
    return { result, message, duration, characters, items, blockList, address, testServer, isGM };
  },
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
  Chat(r) { return { type: r.byte(), message: r.string(), objectID: r.uint32() }; },
};

// packet id → 名 (诊断)
export const IDName = Object.fromEntries(Object.entries(ID).map(([k, v]) => [v, k]));
