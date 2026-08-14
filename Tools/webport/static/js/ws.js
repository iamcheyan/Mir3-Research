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
  if (!s || !s.length) {
    // Guid N 前 20 位 (ServerConnection.cs:28)
    const chars = '0123456789abcdef';
    s = Array.from({ length: 20 }, () => chars[Math.random() * 16 | 0]).join('');
    localStorage.setItem('webport_checksum', s);
  }
  return s;
}

export class GameConnection extends EventTarget {
  constructor() {
    super();
    this.ws = null;
    this.stream = new PacketStream();
    this.connected = false;      // G.Connected 完成
    this.versionOK = false;      // G.GoodVersion 完成
    this.checkSum = loadCheckSum();
    this.stage = 'none';         // none | login | select | game
    this.log = [];
  }

  #emit(type, detail) { this.dispatchEvent(new CustomEvent(type, { detail })); }
  #trace(msg) {
    this.log.push(`${new Date().toISOString().slice(11, 23)} ${msg}`);
    if (this.log.length > 200) this.log.shift();
    console.log(`[net] ${msg}`);
  }

  connect(url = GATEWAY) {
    return new Promise((resolve, reject) => {
      let opened = false;
      const ws = new WebSocket(url);
      this.ws = ws;
      ws.binaryType = 'arraybuffer';
      const timer = setTimeout(() => { if (!opened) { ws.close(); reject(new Error('连接网关超时')); } }, 8000);
      ws.onopen = () => { opened = true; clearTimeout(timer); this.#trace(`WS open ${url}`); resolve(); };
      ws.onerror = () => { if (!opened) { clearTimeout(timer); reject(new Error('WS 错误 (网关未启动?)')); } };
      ws.onclose = () => this.#handleClose();
      ws.onmessage = (ev) => this.#onBytes(ev.data);
    });
  }

  send(bytes) {
    if (this.ws?.readyState === WebSocket.OPEN) this.ws.send(bytes);
  }

  #onBytes(data) {
    this.stream.feed(new Uint8Array(data));
    let pkt;
    while ((pkt = this.stream.next()) !== null) {
      this.#dispatch(pkt.id, pkt.payload);
    }
  }

  #dispatch(id, payload) {
    const r = new Reader(payload);
    try {
    switch (id) {
      case ID.G_CONNECTED:                       // 服务器握手包 → 回显 (ServerConnection.cs:364-368)
        this.connected = true;
        this.send(C.Connected());
        this.#trace('G.Connected → 回显');
        this.#emit('connected');
        break;
      case ID.G_GOODVERSION: {
        const p = S.GoodVersion(r);
        this.versionOK = true;
        this.send(C.SelectLanguage('Chinese'));  // ServerConnection.cs:371
        this.#trace(`G.GoodVersion db=${p.systemDatabaseVersion}`);
        this.#emit('versionOK', p);
        break;
      }
      case ID.G_PING:                            // ServerConnection.cs:379
        this.send(C.Ping());
        break;
      case ID.G_PINGRESPONSE: {
        const p = S.PingResponse(r);
        this.#emit('ping', p.ping);
        break;
      }
      case ID.G_DISCONNECT: {
        const p = S.Disconnect(r);
        this.#trace(`G.Disconnect reason=${p.reason}`);
        this.#emit('serverDisconnect', p.reason);
        this.close();
        break;
      }
      case ID.S_LOGIN: {
        const p = S.Login(r);
        this.#trace(`S.Login result=${p.result} chars=${p.characters?.length ?? 0}`);
        this.#emit('loginResult', p);
        break;
      }
      case ID.S_NEWACCOUNT: {
        this.#emit('newAccountResult', r.byte());
        break;
      }
      case ID.S_NEWCHARACTER: {
        const p = S.NewCharacter(r);
        this.#emit('newCharacterResult', p);
        break;
      }
      case ID.S_DELETECHARACTER: {
        this.#emit('deleteCharacterResult', S.DeleteCharacter(r));
        break;
      }
      case ID.S_STARTGAME: {
        const p = S.StartGame(r);
        this.#trace(`S.StartGame result=${p.result}`);
        this.#emit('startGameResult', p);
        break;
      }
      case ID.S_MAPCHANGED: this.#emit('mapChanged', S.MapChanged(r)); break;
      case ID.S_DAYCHANGED: this.#emit('dayTime', S.DayChanged(r).dayTime); break;
      case ID.S_USERLOCATION: this.#emit('userLocation', S.UserLocation(r)); break;
      case ID.S_OBJECTMOVE: this.#emit('objectMove', S.ObjectMove(r)); break;
      case ID.S_OBJECTTURN: this.#emit('objectTurn', S.ObjectTurn(r)); break;
      case ID.S_OBJECTREMOVE: this.#emit('objectRemove', S.ObjectRemove(r)); break;
      case ID.S_OBJECTPLAYER: this.#emit('objectPlayer', S.ObjectPlayer(r)); break;
      case ID.S_OBJECTMONSTER: this.#emit('objectMonster', S.ObjectMonster(r)); break;
      case ID.S_OBJECTNPC: this.#emit('objectNPC', S.ObjectNPC(r)); break;
      case ID.S_CHAT: this.#emit('chat', S.Chat(r)); break;
      default:
        this.#trace(`未处理包 id=${id} (${IDName[id] ?? '?'}) ${payload.length}B`);
        break;
    }
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
  sendNewCharacter(name, cls, gender, hairType = 1, hairColour = -16777216, armourColour = -1) {
    this.send(C.NewCharacter(name, cls, gender, hairType, hairColour, armourColour, this.checkSum));
  }
  sendDeleteCharacter(characterIndex) { this.send(C.DeleteCharacter(characterIndex, this.checkSum)); }
  sendStartGame(characterIndex) { this.send(C.StartGame(characterIndex)); }
  sendTurn(direction) { this.send(C.Turn(direction)); }
  sendMove(direction, distance = 1) { this.send(C.Move(direction, distance)); }
  sendChat(text) { this.send(C.Chat(text)); }
}
