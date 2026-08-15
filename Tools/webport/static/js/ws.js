// ws.js — 连接层: WebSocket → wsgateway:7001 → ServerCore:7000 (ServerConnection.cs 移植)
// 握手链 (SConnection.cs:43-64, 270-301; ServerConnection.cs:364-373):
//   服务器 accept → S.G.Connected → 客户端回 G.Connected → S.G.GoodVersion
//   → C.SelectLanguage{"Chinese"} → [Login 阶段可用]
// 心跳: G.Ping 每 2s, 必须回 G.Ping, 否则 20s 超时踢 (TEST_RESULTS §7)
// CheckSum: 20 位随机指纹, localStorage 持久化 (user://checksum.bin 等价, ServerConnection.cs:23-31)
import { ID, IDName, PacketStream, Reader, Writer, C, S } from './net.js';

const GATEWAY = location.hostname === '127.0.0.1' || location.hostname === 'localhost'
  ? `ws://127.0.0.1:7001` : `ws://${location.hostname}:7001`;

function loadCheckSum() {
  let s = localStorage.getItem('webport_checksum');
  if (!s || s.length !== 20) {
    const chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789';
    s = Array.from({ length: 20 }, () => chars[Math.floor(Math.random() * chars.length)]).join('');
    localStorage.setItem('webport_checksum', s);
  }
  return s;
}

// 每个已解析 S 包 → 事件名 (camelCase, GameScene On* 处理器对照)
const DISPATCH = {
  [ID.S_LOGIN]: ['loginResult', S.Login],
  [ID.S_NEWACCOUNT]: ['newAccountResult', (r) => ({ result: r.byte(), message: r.string(), duration: r.int64() })],
  [ID.S_NEWCHARACTER]: ['newCharacterResult', S.NewCharacter],
  [ID.S_DELETECHARACTER]: ['deleteCharacterResult', S.DeleteCharacter],
  [ID.S_STARTGAME]: ['startGameResult', S.StartGame],
  // 账号操作结果 (LoginScene.cs:110-123 On*Result 对照; byte 枚举直读)
  [ID.S_CHANGEPASSWORD]: ['changePasswordResult', (r) => ({ result: r.byte(), message: r.string(), duration: r.int64() })],
  [ID.S_REQUESTPASSWORDRESET]: ['requestPasswordResetResult', (r) => ({ result: r.byte(), message: r.string(), duration: r.int64() })],
  [ID.S_RESETPASSWORD]: ['resetPasswordResult', (r) => ({ result: r.byte() })],
  [ID.S_ACTIVATION]: ['activationResult', (r) => ({ result: r.byte() })],
  [ID.S_REQUESTACTIVATIONKEY]: ['requestActivationKeyResult', (r) => ({ result: r.byte(), duration: r.int64() })],
  [ID.S_MAPCHANGED]: ['mapChanged', S.MapChanged],
  [ID.S_USERLOCATION]: ['userLocation', S.UserLocation],
  [ID.S_OBJECTMOVE]: ['objectMove', S.ObjectMove],
  [ID.S_OBJECTTURN]: ['objectTurn', S.ObjectTurn],
  [ID.S_OBJECTREMOVE]: ['objectRemove', S.ObjectRemove],
  [ID.S_OBJECTPLAYER]: ['objectPlayer', S.ObjectPlayer],
  [ID.S_OBJECTMONSTER]: ['objectMonster', S.ObjectMonster],
  [ID.S_OBJECTNPC]: ['objectNPC', S.ObjectNPC],
  [ID.S_OBJECTITEM]: ['objectItem', S.ObjectItem],
  [ID.S_CHAT]: ['chat', S.Chat],
  [ID.S_DAYCHANGED]: ['dayTime', (r) => S.DayChanged(r).dayTime],
  // 战斗/对象事件
  [ID.S_OBJECTATTACK]: ['objectAttack', S.ObjectAttack],
  [ID.S_OBJECTRANGEATTACK]: ['objectRangeAttack', S.ObjectRangeAttack],
  [ID.S_OBJECTSTRUCK]: ['objectStruck', S.ObjectStruck],
  [ID.S_OBJECTDIED]: ['objectDied', S.ObjectDied],
  [ID.S_OBJECTMAGIC]: ['objectMagic', S.ObjectMagic],
  [ID.S_OBJECTPROJECTILE]: ['objectProjectile', S.ObjectProjectile],
  [ID.S_OBJECTSPELL]: ['objectSpell', S.ObjectSpell],
  [ID.S_OBJECTSPELLCHANGED]: ['objectSpellChanged', S.ObjectSpellChanged],
  [ID.S_OBJECTEFFECT]: ['objectEffect', S.ObjectEffect],
  [ID.S_OBJECTSHOW]: ['objectShow', S.ObjectShow],
  [ID.S_OBJECTHIDE]: ['objectHide', S.ObjectHide],
  [ID.S_OBJECTIDLE]: ['objectIdle', S.ObjectIdle],
  [ID.S_OBJECTPUSHED]: ['objectPushed', S.ObjectPushed],
  [ID.S_OBJECTDASH]: ['objectDash', S.ObjectDash],
  [ID.S_OBJECTREVIVE]: ['objectRevive', S.ObjectRevive],
  [ID.S_OBJECTLEVELED]: ['objectLeveled', S.ObjectLeveled],
  [ID.S_OBJECTPOISON]: ['objectPoison', S.ObjectPoison],
  [ID.S_OBJECTMOUNT]: ['objectMount', S.ObjectMount],
  [ID.S_OBJECTPETOWNERCHANGED]: ['objectPetOwnerChanged', S.ObjectPetOwnerChanged],
  [ID.S_OBJECTNAMECOLOUR]: ['objectNameColour', S.ObjectNameColour],
  [ID.S_OBJECTBUFFADD]: ['objectBuffAdd', S.ObjectBuffAdd],
  [ID.S_OBJECTBUFFREMOVE]: ['objectBuffRemove', S.ObjectBuffRemove],
  [ID.S_OBJECTHARVEST]: ['objectHarvest', S.ObjectHarvest],
  [ID.S_OBJECTHARVESTED]: ['objectHarvested', S.ObjectHarvested],
  [ID.S_OBJECTMINING]: ['objectMining', S.ObjectMining],
  [ID.S_OBJECTFISHING]: ['objectFishing', S.ObjectFishing],
  [ID.S_OBJECTTAMING]: ['objectTaming', S.ObjectTaming],
  [ID.S_OBJECTSTATS]: ['objectStats', S.ObjectStats],
  // 状态
  [ID.S_STATSUPDATE]: ['statsUpdate', S.StatsUpdate],
  [ID.S_HEALTHCHANGED]: ['healthChanged', S.HealthChanged],
  [ID.S_MANACHANGED]: ['manaChanged', S.ManaChanged],
  [ID.S_FOCUSCHANGED]: ['focusChanged', S.FocusChanged],
  [ID.S_LEVELCHANGED]: ['levelChanged', S.LevelChanged],
  [ID.S_GAINEDEXPERIENCE]: ['gainedExperience', S.GainedExperience],
  [ID.S_INFORMMAXEXPERIENCE]: ['informMaxExperience', S.InformMaxExperience],
  [ID.S_MAGICCOOLDOWN]: ['magicCooldown', S.MagicCooldown],
  [ID.S_MAGICLEVELED]: ['magicLeveled', S.MagicLeveled],
  [ID.S_MAGICTOGGLE]: ['magicToggle', S.MagicToggle],
  [ID.S_NEWMAGIC]: ['newMagic', S.NewMagic],
  [ID.S_WEIGHTUPDATE]: ['weightUpdate', S.WeightUpdate],
  [ID.S_SAFEZONECHANGED]: ['safeZoneChanged', S.SafeZoneChanged],
  [ID.S_COMBATTIME]: ['combatTime', S.CombatTime],
  [ID.S_SETTIMER]: ['setTimer', S.SetTimer],
  [ID.S_MAPEFFECT]: ['mapEffect', S.MapEffect],
  [ID.S_REVIVETIMERS]: ['reviveTimers', S.ReviveTimers],
  [ID.S_CHANGEATTACKMODE]: ['changeAttackMode', S.ChangeAttackMode],
  [ID.S_CHANGEPETMODE]: ['changePetMode', S.ChangePetMode],
  [ID.S_HELMETTOGGLE]: ['helmetToggle', S.HelmetToggle],
  [ID.S_PLAYERUPDATE]: ['playerUpdate', S.PlayerUpdate],
  [ID.S_PLAYERCHANGEUPDATE]: ['playerChangeUpdate', S.PlayerChangeUpdate],
  // 物品
  [ID.S_ITEMSCHANGED]: ['itemsChanged', S.ItemsChanged],
  [ID.S_ITEMSGAINED]: ['itemsGained', S.ItemsGained],
  [ID.S_ITEMCHANGED]: ['itemChanged', S.ItemChanged],
  [ID.S_ITEMDELETE]: ['itemDelete', S.ItemDelete],
  [ID.S_ITEMMOVE]: ['itemMove', S.ItemMove],
  [ID.S_ITEMSORT]: ['itemSort', S.ItemSort],
  [ID.S_ITEMSPLIT]: ['itemSplit', S.ItemSplit],
  [ID.S_ITEMDURABILITY]: ['itemDurability', S.ItemDurability],
  [ID.S_ITEMUSEDELAY]: ['itemUseDelay', S.ItemUseDelay],
  [ID.S_ITEMLOCK]: ['itemLock', S.ItemLock],
  [ID.S_ITEMSTATSCHANGED]: ['itemStatsChanged', S.ItemStatsChanged],
  [ID.S_ITEMSTATSREFRESHED]: ['itemStatsRefreshed', S.ItemStatsRefreshed],
  [ID.S_ITEMEXPERIENCE]: ['itemExperience', S.ItemExperience],
  [ID.S_ITEMACECESSORYREFINED]: ['itemAcessoryRefined', S.ItemAcessoryRefined],
  // Buff
  [ID.S_BUFFADD]: ['buffAdd', S.BuffAdd],
  [ID.S_BUFFREMOVE]: ['buffRemove', S.BuffRemove],
  [ID.S_BUFFCHANGED]: ['buffChanged', S.BuffChanged],
  [ID.S_BUFFTIME]: ['buffTime', S.BuffTime],
  [ID.S_BUFFPAUSED]: ['buffPaused', S.BuffPaused],
  // NPC
  [ID.S_NPCRESPONSE]: ['npcResponse', S.NPCResponse],
  [ID.S_NPCCLOSE]: ['npcClose', S.NPCClose],
  [ID.S_NPCROLL]: ['npcRoll', S.NPCRoll],
  // 任务
  [ID.S_QUESTCHANGED]: ['questChanged', S.QuestChanged],
  [ID.S_QUESTCANCELLED]: ['questCancelled', S.QuestCancelled],
  // 数据对象 (大地图/查找)
  [ID.S_DATAOBJECTLOCATION]: ['dataObjectLocation', S.DataObjectLocation],
  [ID.S_DATAOBJECTMAXHEALTHMANA]: ['dataObjectMaxHealthMana', S.DataObjectMaxHealthMana],
  [ID.S_DATAOBJECTMONSTER]: ['dataObjectMonster', S.DataObjectMonster],
  [ID.S_DATAOBJECTPLAYER]: ['dataObjectPlayer', S.DataObjectPlayer],
  [ID.S_DATAOBJECTREMOVE]: ['dataObjectRemove', S.DataObjectRemove],
  [ID.S_DATAOBJECTITEM]: ['dataObjectItem', S.DataObjectItem],
  [ID.S_DATAOBJECTHEALTHMANA]: ['dataObjectHealthMana', S.DataObjectHealthMana],
  // 组队
  [ID.S_GROUPINVITE]: ['groupInvite', S.GroupInvite],
  [ID.S_GROUPMEMBER]: ['groupMember', S.GroupMember],
  [ID.S_GROUPREMOVE]: ['groupRemove', S.GroupRemove],
  [ID.S_GROUPSWITCH]: ['groupSwitch', S.GroupSwitch],
  [ID.S_GROUPUPDATE]: ['groupUpdate', S.GroupUpdate],
  [ID.S_GROUPREQUEST]: ['groupRequest', S.GroupRequest],
  [ID.S_GROUPLFG]: ['groupLFG', S.GroupLFG],
  // 行会
  [ID.S_GUILDINFO]: ['guildInfo', S.GuildInfo],
  [ID.S_GUILDINVITE]: ['guildInvite', S.GuildInvite],
  [ID.S_GUILDCHANGED]: ['guildChanged', S.GuildChanged],
  [ID.S_GUILDNOTICECHANGED]: ['guildNoticeChanged', S.GuildNoticeChanged],
  [ID.S_GUILDUPDATE]: ['guildUpdate', S.GuildUpdate],
  [ID.S_GUILDNEWITEM]: ['guildNewItem', S.GuildNewItem],
  [ID.S_GUILDGETITEM]: ['guildGetItem', S.GuildGetItem],
  [ID.S_GUILDMEMBERONLINE]: ['guildMemberOnline', S.GuildMemberOnline],
  [ID.S_GUILDMEMBEROFFLINE]: ['guildMemberOffline', S.GuildMemberOffline],
  [ID.S_GUILDFUNDSCHANGED]: ['guildFundsChanged', S.GuildFundsChanged],
  [ID.S_GUILDSTATS]: ['guildStats', S.GuildStats],
  [ID.S_GUILDWARSTARTED]: ['guildWarStarted', S.GuildWarStarted],
  [ID.S_GUILDWARFINISHED]: ['guildWarFinished', S.GuildWarFinished],
  [ID.S_GUILDCASTLEINFO]: ['guildCastleInfo', S.GuildCastleInfo],
  [ID.S_GUILDCONQUESTDATE]: ['guildConquestDate', S.GuildConquestDate],
  [ID.S_GUILDCONQUESTSTARTED]: ['guildConquestStarted', S.GuildConquestStarted],
  [ID.S_GUILDCONQUESTFINISHED]: ['guildConquestFinished', S.GuildConquestFinished],
  [ID.S_GUILDCREATE]: ['guildCreate', S.GuildCreate],
  [ID.S_GUILDKICK]: ['guildKick', S.GuildKick],
  [ID.S_GUILDDAYRESET]: ['guildDayReset', S.GuildDayReset],
  [ID.S_GUILDINCREASEMEMBER]: ['guildIncreaseMember', S.GuildIncreaseMember ?? (() => ({}))],
  [ID.S_GUILDINCREASESTORAGE]: ['guildIncreaseStorage', S.GuildIncreaseStorage ?? (() => ({}))],
  [ID.S_GUILDINVITEMEMBER]: ['guildInviteMember', S.GuildInviteMember ?? (() => ({}))],
  [ID.S_GUILDMEMBERCONTRIBUTION]: ['guildMemberContribution', S.GuildMemberContribution],
  [ID.S_GUILDWAR]: ['guildWar', S.GuildWar],
  // 婚姻/社交
  [ID.S_MARRIAGEINFO]: ['marriageInfo', S.MarriageInfo],
  [ID.S_MARRIAGEINVITE]: ['marriageInvite', S.MarriageInvite],
  [ID.S_FRIENDADD]: ['friendAdd', S.FriendAdd],
  [ID.S_FRIENDREMOVE]: ['friendRemove', S.FriendRemove],
  [ID.S_FRIENDUPDATE]: ['friendUpdate', S.FriendUpdate],
  [ID.S_BLOCKADD]: ['blockAdd', S.BlockAdd],
  [ID.S_BLOCKREMOVE]: ['blockRemove', S.BlockRemove],
  // 交易
  [ID.S_TRADEOPEN]: ['tradeOpen', S.TradeOpen],
  [ID.S_TRADECLOSE]: ['tradeClose', S.TradeClose],
  [ID.S_TRADEUNLOCK]: ['tradeUnlock', S.TradeUnlock],
  [ID.S_TRADEITEMADDED]: ['tradeItemAdded', S.TradeItemAdded],
  [ID.S_TRADEGOLDADDED]: ['tradeGoldAdded', S.TradeGoldAdded],
  [ID.S_TRADEADDITEM]: ['tradeAddItem', S.TradeAddItem],
  [ID.S_TRADEADDGOLD]: ['tradeAddGold', S.TradeAddGold],
  [ID.S_TRADEREQUEST]: ['tradeRequest', S.TradeRequest],
  // 邮件
  [ID.S_MAILLIST]: ['mailList', S.MailList],
  [ID.S_MAILNEW]: ['mailNew', S.MailNew],
  [ID.S_MAILITEMDELETE]: ['mailItemDelete', S.MailItemDelete],
  [ID.S_MAILDELETE]: ['mailDelete', S.MailDelete],
  [ID.S_MAILSEND]: ['mailSend', S.MailSend],
  // 杂项
  [ID.S_STORAGESIZE]: ['storageSize', S.StorageSize],
  [ID.S_CURRENCYCHANGED]: ['currencyChanged', S.CurrencyChanged],
  [ID.S_FORTUNEUPDATE]: ['fortuneUpdate', S.FortuneUpdate],
  [ID.S_REFINELIST]: ['refineList', S.RefineList],
  // R19: NPC 精炼系回包 (GameScene.cs:2674-2752/2612-2627 对照)
  [ID.S_NPCREFINE]: ['npcRefineResult', S.NPCRefineResult],
  [ID.S_NPCMASTERREFINE]: ['npcMasterRefineResult', S.NPCMasterRefineResult],
  [ID.S_NPCREFINEMENTSTONE]: ['npcRefinementStoneResult', S.NPCRefinementStoneResult],
  [ID.S_NPCWEAPONCRAFT]: ['npcWeaponCraftResult', S.NPCWeaponCraftResult],
  [ID.S_NPCACCESSORYLEVELUP]: ['npcAccessoryLevelUpResult', S.NPCAccessoryLevelUpResult],
  [ID.S_NPCACCESSORYUPGRADE]: ['npcAccessoryUpgradeResult', S.NPCAccessoryUpgradeResult],
  [ID.S_NPCREFINERETRIEVE]: ['npcRefineRetrieveResult', S.NPCRefineRetrieveResult],
  [ID.S_COMPANIONRETRIEVE]: ['companionRetrieveResult', S.CompanionRetrieveResult],
  [ID.S_COMPANIONRELEASE]: ['companionReleaseResult', S.CompanionReleaseResult],
  [ID.S_INSPECT]: ['inspect', S.Inspect],
  [ID.S_RANKINGS]: ['rankings', S.Rankings],
  [ID.S_RANKSEARCH]: ['rankSearch', S.RankSearch],
  [ID.S_MARKETPLACECONSIGN]: ['marketPlaceConsign', S.MarketPlaceConsign],
  [ID.S_MARKETPLACEHISTORY]: ['marketPlaceHistory', S.MarketPlaceHistory],
  [ID.S_MARKETPLACESEARCH]: ['marketPlaceSearch', S.MarketPlaceSearch],
  [ID.S_MARKETPLACESEARCHCOUNT]: ['marketPlaceSearchCount', S.MarketPlaceSearchCount],
  [ID.S_MARKETPLACESEARCHINDEX]: ['marketPlaceSearchIndex', S.MarketPlaceSearchIndex],
  [ID.S_MARKETPLACEBUY]: ['marketPlaceBuy', S.MarketPlaceBuy],
  [ID.S_MARKETPLACECONSIGNCHANGED]: ['marketPlaceConsignChanged', S.MarketPlaceConsignChanged],
  [ID.S_GAMESTOREDATA]: ['gameStoreData', S.GameStoreData],
  [ID.S_GAMESTORETOPITEMS]: ['gameStoreTopItems', S.GameStoreTopItems],
  [ID.S_GAMESTOREFAVOURITECHANGED]: ['gameStoreFavouriteChanged', S.GameStoreFavouriteChanged],
  [ID.S_GAMESTOREGIFT]: ['gameStoreGift', S.GameStoreGift],
  [ID.S_COMPANIONUPDATE]: ['companionUpdate', S.CompanionUpdate],
  [ID.S_COMPANIONWEIGHTUPDATE]: ['companionWeightUpdate', S.CompanionWeightUpdate],
  [ID.S_COMPANIONADOPT]: ['companionAdopt', S.CompanionAdopt],
  [ID.S_MILESTONEEARNED]: ['milestoneEarned', S.MilestoneEarned],
  [ID.S_USERMILESTONES]: ['userMilestones', S.UserMilestones],
  [ID.S_DISCIPLINEUPDATE]: ['disciplineUpdate', S.DisciplineUpdate],
  [ID.S_TIMEOFDAYCHANGED]: ['timeOfDayChanged', S.TimeOfDayChanged],
  [ID.S_GAMELOGOUT]: ['gameLogout', S.GameLogout],
  [ID.S_SELECTLOGOUT]: ['selectLogout', S.SelectLogout],
  [ID.S_OBSERVABLESWITCH]: ['observableSwitch', S.ObservableSwitch],
  [ID.S_LOOTBOXOPEN]: ['lootBoxOpen', S.LootBoxOpen],
  [ID.S_LOOTBOXCLOSE]: ['lootBoxClose', S.LootBoxClose],
  [ID.S_BUNDLEOPEN]: ['bundleOpen', S.BundleOpen],
  [ID.S_BUNDLECLOSE]: ['bundleClose', S.BundleClose],
  [ID.S_JOININSTANCE]: ['joinInstance', S.JoinInstance],
  [ID.S_FISHINGSTATS]: ['fishingStats', S.FishingStats],
};

export class GameConnection extends EventTarget {
  constructor() {
    super();
    this.ws = null;
    this.connected = false;
    this.versionOK = false;
    this.checkSum = loadCheckSum();
    this.stream = new PacketStream();
    this.stage = 'login';     // login | select | game
    this.log = [];
    this.sentCount = 0; this.recvCount = 0;
  }

  #emit(type, detail) { this.dispatchEvent(new CustomEvent(type, { detail })); }

  #trace(msg) {
    const line = `[${new Date().toLocaleTimeString()}] ${msg}`;
    this.log.push(line);
    if (this.log.length > 400) this.log.shift();
  }

  connect(url = GATEWAY) {
    return new Promise((resolve, reject) => {
      this.ws = new WebSocket(url);
      this.ws.binaryType = 'arraybuffer';
      this.ws.onopen = () => { this.#trace('WS 已连接网关'); resolve(); };
      this.ws.onclose = () => { this.#handleClose(); reject(new Error('网关连接失败')); };
      this.ws.onerror = () => { /* onclose 跟进 */ };
      this.ws.onmessage = (ev) => this.#onBytes(ev.data);
    });
  }

  send(bytes) {
    this.sentCount++;
    if (this.ws?.readyState === WebSocket.OPEN) this.ws.send(bytes);
  }

  #onBytes(data) {
    this.stream.feed(new Uint8Array(data));
    let pkt;
    while ((pkt = this.stream.next()) !== null) {
      this.recvCount++;
      this.#dispatch(pkt.id, pkt.payload);
    }
  }

  #dispatch(id, payload) {
    const r = new Reader(payload);
    try {
      if (id === ID.G_CONNECTED) {                 // 服务器握手包 → 回显 (ServerConnection.cs:364-368)
        this.connected = true;
        this.send(C.Connected());
        this.#trace('G.Connected → 回显');
        this.#emit('connected');
        return;
      }
      if (id === ID.G_GOODVERSION) {
        const p = S.GoodVersion(r);
        this.versionOK = true;
        this.send(C.SelectLanguage('Chinese'));    // ServerConnection.cs:371
        this.#trace(`G.GoodVersion db=${p.systemDatabaseVersion}`);
        this.#emit('versionOK', p);
        return;
      }
      if (id === ID.G_PING) { this.send(C.Ping()); return; }  // ServerConnection.cs:379
      if (id === ID.G_PINGRESPONSE) { this.#emit('ping', S.PingResponse(r).ping); return; }
      if (id === ID.G_DISCONNECT) {
        const p = S.Disconnect(r);
        this.#trace(`G.Disconnect reason=${p.reason}`);
        this.#emit('serverDisconnect', p.reason);
        this.close();
        return;
      }
      const entry = DISPATCH[id];
      if (entry) {
        const [evName, parse] = entry;
        const p = parse(r);
        if (id === ID.S_LOGIN) { this.isGM = !!p.isGM; this.loginItems = p.items ?? []; } // PendingStorageItems (ServerConnection.cs:383)
        this.#emit(evName, p);
        return;
      }
      this.#trace(`未处理包 id=${id} (${IDName[id] ?? '?'}) ${payload.length}B`);
    } catch (err) {
      // 解析失败只丢当前包 (帧已定界), 不影响后续包
      this.#trace(`包解析失败 id=${id} (${IDName[id] ?? '?'}) ${payload.length}B: ${err.message}`);
    }
  }

  #handleClose() {
    if (this.connected) {
      this.connected = false;
      this.#emit('disconnected');
    }
    this.ws = null;
  }

  close() {
    try { this.ws?.close(); } catch { /* noop */ }
    this.ws = null;
  }

  // ---- 高层 API (ServerConnection SendXxx 等价) ----
  sendLogin(email, password) { this.send(C.Login(email, password, this.checkSum)); }
  sendNewAccount(email, password) { this.send(C.NewAccount(email, password, this.checkSum)); }
  // 账号操作 (ServerConnection.cs:897-905)
  sendChangePassword(email, current, next) { this.send(C.ChangePassword(email, current, next, this.checkSum)); }
  sendRequestPasswordReset(email) { this.send(C.RequestPasswordReset(email, this.checkSum)); }
  sendResetPassword(key, next) { this.send(C.ResetPassword(key, next, this.checkSum)); }
  sendActivation(key) { this.send(C.Activation(key, this.checkSum)); }
  sendRequestActivationKey(email) { this.send(C.RequestActivationKey(email, this.checkSum)); }
  sendNewCharacter(name, cls, gender, hairType = 1, hairColour = -16777216, armourColour = -1) {
    this.send(C.NewCharacter(name, cls, gender, hairType, hairColour, armourColour, this.checkSum));
  }
  sendDeleteCharacter(characterIndex) { this.send(C.DeleteCharacter(characterIndex, this.checkSum)); }
  sendStartGame(characterIndex) { this.send(C.StartGame(characterIndex)); }
  sendTurn(direction) { this.send(C.Turn(direction)); }
  sendMove(direction, distance = 1) { this.send(C.Move(direction, distance)); }
  sendChat(text) { this.send(C.Chat(text)); }
  // 战斗 (GameScene.cs:992-1037)
  sendAttack(direction, magic = 0) { this.send(C.Attack(direction, 3, magic)); }
  sendMagic(direction, type, target, x, y) { this.send(C.Magic(direction, 5, type, target, x, y)); }
  sendPickUp() { this.send(C.PickUp()); }
  sendNPCCall(objectID) { this.send(C.NPCCall(objectID)); }
  sendNPCButton(buttonID) { this.send(C.NPCButton(buttonID)); }
  sendNPCClose() { this.send(C.NPCClose()); }
  sendNPCBuy(index, amount, guildFunds = false) { this.send(C.NPCBuy(index, amount, guildFunds)); }
  sendNPCSell(links) { this.send(C.NPCSell(links)); }
  sendNPCRepair(links, special, guildFunds = false) { this.send(C.NPCRepair(links, special, guildFunds)); }
  sendNPCRefineRetrieve(index) { this.send(C.NPCRefineRetrieve(index)); }
  sendNPCRefine(refineType, quality, ores, items, specials) { this.send(C.NPCRefine(refineType, quality, ores, items, specials)); }
  sendNPCFragment(links) { this.send(C.NPCFragment(links)); }
  sendMarriageMakeRing(slot) { this.send(C.MarriageMakeRing(slot)); }
  sendNPCAccessoryUpgrade(target, refineType) { this.send(C.NPCAccessoryUpgrade(target, refineType)); }
  sendNPCAccessoryReset(cell) { this.send(C.NPCAccessoryReset(cell)); }
  sendNPCRefinementStone(iron, silver, diamond, goldOre, crystal, gold) { this.send(C.NPCRefinementStone(iron, silver, diamond, goldOre, crystal, gold)); }
  sendNPCMasterRefine(refineType, f1, f2, f3, stone, special) { this.send(C.NPCMasterRefine(refineType, f1, f2, f3, stone, special)); }
  sendNPCMasterRefineEvaluate(refineType, f1, f2, f3, stone, special) { this.send(C.NPCMasterRefineEvaluate(refineType, f1, f2, f3, stone, special)); }
  sendNPCAccessoryLevelUp(target, links) { this.send(C.NPCAccessoryLevelUp(target, links)); }
  sendNPCWeaponCraft(cls, template, yellow, blue, red, purple, green, grey) { this.send(C.NPCWeaponCraft(cls, template, yellow, blue, red, purple, green, grey)); }
  sendCompanionStore(index) { this.send(C.CompanionStore(index)); }
  sendItemMove(fromGrid, toGrid, fromSlot, toSlot, mergeItem = false) {
    this.send(C.ItemMove(fromGrid, toGrid, fromSlot, toSlot, mergeItem));
  }
  sendItemUse(grid, slot, count = 1n) { this.send(C.ItemUse({ gridType: grid, slot, count })); }
  sendItemDrop(grid, slot, count, dropSlot) { this.send(C.ItemDrop({ gridType: grid, slot, count }, dropSlot)); }
  sendItemSplit(grid, slot, count) { this.send(C.ItemSplit(grid, slot, count)); }
  sendItemSort(grid) { this.send(C.ItemSort(grid)); }
  sendItemDelete(grid, slot) { this.send(C.ItemDelete(grid, slot)); }
  sendQuestAccept(index) { this.send(C.QuestAccept(index)); }
  sendQuestComplete(index, choiceIndex = 0) { this.send(C.QuestComplete(index, choiceIndex)); }
  sendQuestAbandon(index) { this.send(C.QuestAbandon(index)); }
  sendQuestTrack(index, track) { this.send(C.QuestTrack(index, track)); }
  sendGroupInvite(name) { this.send(C.GroupInvite(name)); }
  sendGroupRemove(name) { this.send(C.GroupRemove(name)); }
  sendGroupResponse(name, accept) { this.send(C.GroupResponse(name, accept)); }
  sendGroupRequest(name) { this.send(C.GroupRequest(name)); }
  sendGroupSwitch(allow) { this.send(C.GroupSwitch(allow)); }
  sendGroupNotify(receive) { this.send(C.GroupNotify(receive)); }
  sendGuildCreate(name) { this.send(C.GuildCreate(name)); }
  sendGuildResponse(accept) { this.send(C.GuildResponse(accept)); }
  sendTradeRequestResponse(accept) { this.send(C.TradeRequestResponse(accept)); }
  sendTradeClose() { this.send(C.TradeClose()); }
  sendTradeConfirm() { this.send(C.TradeConfirm()); }
  sendTradeAddGold(gold) { this.send(C.TradeAddGold(gold)); }
  sendTradeAddItem(cell) { this.send(C.TradeAddItem(cell)); }
  sendRankRequest(cls, onlineOnly, startIndex) { this.send(C.RankRequest(cls, onlineOnly, startIndex)); }
  sendRankSearch(name) { this.send(C.RankSearch(name)); }
  sendMarketPlaceSearch(name, itemTypeFilter, itemType, sort) { this.send(C.MarketPlaceSearch(name, itemTypeFilter, itemType, sort)); }
  sendLogout() { this.send(C.Logout()); }
  sendItemLock(grid, slot, locked) { this.send(C.ItemLock(grid, slot, locked)); }
  sendInspect(index, ranking = false) { this.send(C.Inspect(index, ranking)); }
  sendMount() { this.send(C.Mount()); }
  sendTradeRequest() { this.send(new Writer().build(ID.C_TRADEREQUEST)); }
  sendChangeAttackMode(mode) { this.send(C.ChangeAttackMode(mode)); }
  sendChangePetMode(mode) { this.send(C.ChangePetMode(mode)); }
  sendTeleportRing(x, y, index = 0) { this.send(C.TeleportRing(x, y, index)); }
  sendMagicKey(magic, s1, s2, s3, s4) { this.send(C.MagicKey(magic, s1, s2, s3, s4)); }
  sendHelmetToggle(hide) { this.send(C.HelmetToggle(hide)); }
  sendMarriageTeleport() { this.send(new Writer().build(ID.C_MARRIAGETELEPORT)); }
  sendGroupLFGUpdate(enabled, name, type, maxCount) { this.send(C.GroupLFGUpdate(enabled, name, type, maxCount)); }
  sendFortuneCheck(itemIndex) { this.send(C.FortuneCheck(itemIndex)); }
  sendCompanionAdopt(index, name) { this.send(C.CompanionAdopt(index, name)); }
  sendCompanionRetrieve(index) { this.send(C.CompanionRetrieve(index)); }
  sendCompanionRelease(index) { this.send(C.CompanionRelease(index)); }
  sendJoinInstance(index) { this.send(C.JoinInstance(index)); }
  sendMilestoneClaim(index) { this.send(C.MilestoneClaim(index)); }
  sendMilestoneActive(index, active) { this.send(C.MilestoneActive(index, active)); }
  sendFriendAdd(name) { this.send(C.FriendAdd(name)); }
  sendFriendRemove(index) { this.send(C.FriendRemove(index)); }
  sendChangeOnlineState(state) { this.send(C.ChangeOnlineState(state)); }
  sendBlockAdd(name) { this.send(C.BlockAdd(name)); }
  sendBlockRemove(index) { this.send(C.BlockRemove(index)); }
  sendMailSend(links, recipient, subject, message, gold) { this.send(C.MailSend(links, recipient, subject, message, gold)); }
  sendMailGetItem(index, slot) { this.send(C.MailGetItem(index, slot)); }
  sendMailDelete(index) { this.send(C.MailDelete(index)); }
  sendMailOpened(index) { this.send(C.MailOpened(index)); }
  sendMarketPlaceConsign(link, price, message = '', guildFunds = false) { this.send(C.MarketPlaceConsign(link, price, message, guildFunds)); }
  sendMarketPlaceCancelConsign(index, count) { this.send(C.MarketPlaceCancelConsign(index, count)); }
  sendMarketPlaceBuy(index, count, guildFunds = false) { this.send(C.MarketPlaceBuy(index, count, guildFunds)); }
  sendMarketPlaceHistory(index, display = 0, partIndex = 0) { this.send(C.MarketPlaceHistory(index, display, partIndex)); }
  sendMarketPlaceSearchIndex(index) { this.send(C.MarketPlaceSearchIndex(index)); }
  sendGameStoreGift(index, count, useHuntGold, recipient) { this.send(C.GameStoreGift(index, count, useHuntGold, recipient)); }
  sendGameStoreFavouriteToggle(index) { this.send(C.GameStoreFavouriteToggle(index)); }
  sendHermit(stat) { this.send(C.Hermit(stat)); }
  sendMagicToggle(magic, canUse) { this.send(C.MagicToggle(magic, canUse)); }
  sendBeltLinkChanged(slot, linkIndex, linkItemIndex) { this.send(C.BeltLinkChanged(slot, linkIndex, linkItemIndex)); }
  sendAutoPotionLinkChanged(slot, linkIndex, health, mana, enabled) { this.send(C.AutoPotionLinkChanged(slot, linkIndex, health, mana, enabled)); }
  sendTownRevive() { this.send(C.TownRevive()); }
  sendObserverRequest(name) { this.send(C.ObserverRequest(name)); }
  sendObservableSwitch(allow) { this.send(C.ObservableSwitch(allow)); }
  // ---- par-win 窗口发送器 ----
  sendGuildInviteMember(name) { this.send(C.GuildInviteMember(name)); }
  sendGuildKickMember(index) { this.send(C.GuildKickMember(index)); }
  sendGuildEditMember(index, rank, permission) { this.send(C.GuildEditMember(index, rank, permission)); }
  sendGuildTax(tax) { this.send(C.GuildTax(tax)); }
  sendGuildIncreaseMember() { this.send(C.GuildIncreaseMember()); }
  sendGuildIncreaseStorage() { this.send(C.GuildIncreaseStorage()); }
  sendGuildWar(guildName) { this.send(C.GuildWar(guildName)); }
  sendGuildRequestConquest(index) { this.send(C.GuildRequestConquest(index)); }
  sendGuildColour(colour) { this.send(C.GuildColour(colour)); }
  sendGuildFlag(flag) { this.send(C.GuildFlag(flag)); }
  sendGuildToggleCastleGates() { this.send(C.GuildToggleCastleGates()); }
  sendGuildRepairCastleGates() { this.send(C.GuildRepairCastleGates()); }
  sendGuildRepairCastleGuards() { this.send(C.GuildRepairCastleGuards()); }
  sendJoinStarterGuild() { this.send(C.JoinStarterGuild()); }
  sendMarriageResponse(accept) { this.send(C.MarriageResponse(accept)); }
  sendSelectLanguage(lang) { this.send(C.SelectLanguage(lang)); }
  sendMilestoneNotify(receive) { this.send(C.MilestoneNotify(receive)); }
  sendGuildEditNotice(notice) { this.send(C.GuildEditNotice(notice)); }
  sendIncreaseDiscipline() { this.send(C.IncreaseDiscipline()); }
 }
