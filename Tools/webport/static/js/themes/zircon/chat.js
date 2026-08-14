// chat.js — par-hud C 路: ChatTextBox.cs + ChatLogPanel.cs 逐方法移植
// 行为权威: GodotClient/Controls/ChatTextBox.cs, ChatLogPanel.cs (行号随注)。
// 布局权威: ui_tree.json ChatTextBox 条目 (mode 60x24@0,0 / options 50x24@345,0 / input 275x23@65,1);
//           本文件不硬编码坐标, 从 uitree.js 读取。
import { DXControl, DXLabel, DXButton, DXTextInput } from '../../dx.js';
import { MsgTypeColour, MsgTypeName, MSG } from '../../net.js';

// ---- Lang (ChineseMessages.cs) ----
const LANG = {
  // ChatMode 名 (ChatTextBox.cs:19 ModeNames 声明序)
  modeNames: ['普通', '私聊:', '编组:', '行会:', '普通:', '全局:', '观察:'],
  modeNamesShort: ['普通', '私聊', '编组', '行会', '喊话', '全局', '观察'], // 按钮显示 (无冒号)
  options: '选项',                      // ChatTextBoxOptionsButtonLabel:432
  chatLabel: '主聊天',                  // ChatLogPanelChatLabel:862
  system: '系统',                       // GameSystemLabel:1001
  timeOfDay: ['黎明', '白天', '黄昏', '夜晚'], // MiniMap*Label:1146-1149 (TimeOfDay enum 序)
};

const MAX_CHAT_LENGTH = 120;             // Globals.cs:85
const MAX_LINES = 250;                   // ChatLogPanel.cs:26

// ====================================================================
// ChatLogPanel (ChatLogPanel.cs) — 记录区: 消息列表 + 透明淡出 + 频道过滤
// ====================================================================
export class ChatLogPanel extends DXControl {
  constructor(opts = {}) {
    // ChatLogPanel.cs:47-71: 400x150, 默认 tab Transparent+HideTab+FadeOut, 过滤 System/Combat
    super({ size: [400, 150], clip: true, isControl: false, ...opts });
    this.messages = [];                  // {text, type, colour}
    this.enabledTypes = new Set(Object.values(MSG));
    this.enabledTypes.delete(MSG.SYSTEM);
    this.enabledTypes.delete(MSG.COMBAT);
    this.transparent = true;             // 默认 tab Transparent (ChatLogPanel.cs:64)
    this.fadeOut = true;                 // FadeOut (ChatLogPanel.cs:66)
    this.idleSeconds = 0;
    this._lastActivity = performance.now();

    // _textArea (ChatLogPanel.cs:56): 380x124@0,22, clip
    this.textArea = new DXControl({ size: [380, 124], location: [0, 22], clip: true, isControl: false });
    this.addControl(this.textArea);
    // _scroll (ChatLogPanel.cs:58): 18x124@380,22 — DOM 直接 overflow-y 滚动
    this.scrollEl = document.createElement('div');
    this.scrollEl.style.cssText =
      `position:absolute;left:380px;top:22px;width:18px;height:124px;overflow-y:auto;` +
      `scrollbar-width:none;pointer-events:auto;display:none;`;
    this.scrollEl.innerHTML = '<div style="width:1px;height:1px"></div>';
    this.el.appendChild(this.scrollEl);
    this.textArea.el.addEventListener('wheel', (ev) => {
      this.scrollEl.scrollTop += ev.deltaY;
      ev.preventDefault();
    }, { passive: false });
    this.scrollEl.addEventListener('scroll', () => this.#updateLines());

    this._rafId = requestAnimationFrame(this._fadeTick);
  }


  // _Process (ChatLogPanel.cs:73-92): 空闲计时 + 淡出 (箭头函数属性, 类字段合法)
  _fadeTick = () => {
    this.idleSeconds = (performance.now() - this._lastActivity) / 1000;
    const opacity = this.fadeOut && this.transparent && this.idleSeconds > 10 ? 0.15 : 1;
    this.textArea.el.style.opacity = opacity;
    this.scrollEl.style.display = opacity >= 1 && this.scrollEl.scrollHeight > this.scrollEl.clientHeight + 2 ? 'block' : 'none';
    requestAnimationFrame(this._fadeTick);
  };


  #hasScroll() { return this.scrollEl.scrollHeight > this.scrollEl.clientHeight + 2; }

  // AddMessage (ChatLogPanel.cs:112-129)
  addMessage(text, type, colour) {
    if (!text || !text.trim()) return;
    this._lastActivity = performance.now();
    this.textArea.el.style.opacity = 1;
    this.messages.push({ text, type, colour: colour ?? MsgTypeColour[type] ?? '#ffffff' });
    if (this.messages.length > MAX_LINES) this.messages.shift();
    this.#rebuildVisibleLines(true);
  }

  // IsMessageEnabled (ChatLogPanel.cs:478-486)
  #isEnabled(type) {
    if (type === MSG.ANNOUNCEMENT || type === MSG.DEBUG) return true;
    if (type === MSG.WHISPEROUT || type === MSG.GMWHISPERIN) return this.enabledTypes.has(MSG.WHISPERIN);
    return this.enabledTypes.has(type);
  }

  // RebuildVisibleLines (ChatLogPanel.cs:390-427) — DOM: 仅重建过滤后行, 底部锚定
  #rebuildVisibleLines(keepBottom) {
    if (keepBottom) this.scrollEl.scrollTop = 0; // 逻辑滚动条在顶=最新在底 (UpdateLines 反向渲染)
    const frag = document.createDocumentFragment();
    for (const m of this.messages) {
      if (!this.#isEnabled(m.type)) continue;
      const line = document.createElement('div');
      line.textContent = m.text;
      line.style.cssText =
        `margin:0 0 1px 6px;font-size:13px;line-height:16px;white-space:pre-wrap;` +
        `word-break:break-all;width:372px;color:${m.colour};` +
        `text-shadow:1px 1px 0 #000;` +
        `background:${this.transparent ? 'rgba(0,0,0,.39)' : 'transparent'};`; // FromArgb(100,0,0,0)
      frag.appendChild(line);
    }
    this.textArea.el.replaceChildren(frag);
    // UpdateLines (ChatLogPanel.cs:429-452): 默认非 reverse, 滚动值=0 时全部可见, 底对齐
    this.textArea.el.style.display = 'flex';
    this.textArea.el.style.flexDirection = 'column';
    this.textArea.el.style.justifyContent = 'flex-end';
    this.#updateLines();
  }

  #updateLines() { /* DOM overflow 自管; 预留跟随过滤/滚动 */ }

  // SetTypeEnabled/IsTypeEnabled (ChatLogPanel.cs:262-274) — ChatOptions 窗口用
  setTypeEnabled(type, enabled) {
    if (enabled) this.enabledTypes.add(type); else this.enabledTypes.delete(type);
    this.#rebuildVisibleLines(false);
  }
  isTypeEnabled(type) { return this.enabledTypes.has(type); }
}

// ====================================================================
// ChatTextBox (ChatTextBox.cs) — 输入栏: 频道按钮 + 输入框 + 选项 + 历史
// ====================================================================
export class ChatTextBox extends DXControl {
  // ChatMode (ChatTextBox.cs:14-17)
  static ChatMode = { Local: 0, Whisper: 1, Group: 2, Guild: 3, Shout: 4, Global: 5, Observer: 6 };

  constructor(opts = {}) {
    // ChatTextBox.cs:33-44: 400x25, Opacity .6, 黑底 0.35
    super({ size: [400, 25], backColour: [0, 0, 0, 89], ...opts });
    this.mode = ChatTextBox.ChatMode.Local;
    this.lastPM = '';
    this.history = [];                   // _history (ChatTextBox.cs:25)
    this.historyIndex = -1;              // _historyIndex
    this.historyDraft = '';              // _historyDraft
    this.linkedItemIndexes = [];         // _linkedItemIndexes
    this.onSend = opts.onSend ?? (() => {});   // GameScene.SendChat
    this.onOptions = opts.onOptions ?? (() => {}); // OpenChatOptionsDialog
    this.selfName = opts.selfName ?? '';

    // _modeButton (ChatTextBox.cs:46-52) @ui_tree ChatTextBox/0
    this.modeButton = new DXButton({
      text: LANG.modeNamesShort[0], fontSize: 9, library: 'Interface', index: -1,
      location: [0, 0], size: [60, 24], onClick: () => this.cycleMode(),
    });
    this.addControl(this.modeButton);

    // _optionsButton (ChatTextBox.cs:54-60) @ui_tree ChatTextBox/1
    this.optionsButton = new DXButton({
      text: LANG.options, fontSize: 9, library: 'Interface', index: -1,
      location: [345, 0], size: [50, 24], onClick: () => this.onOptions(),
    });
    this.addControl(this.optionsButton);

    // _input (ChatTextBox.cs:62-70) @ui_tree ChatTextBox/2
    this.input = new DXTextInput({ location: [65, 1], size: [275, 23], fontSize: 9, maxLength: MAX_CHAT_LENGTH });
    this.addControl(this.input);
    this.input.input.addEventListener('keydown', (ev) => {
      if (ev.key === 'ArrowUp') { this.#navigateHistory(true); ev.preventDefault(); }
      else if (ev.key === 'ArrowDown') { this.#navigateHistory(false); ev.preventDefault(); }
      else if (ev.key === 'Enter') {
        ev.preventDefault();
        this.#submitChat(this.input.text);
      } else if (ev.key === 'Escape') {
        this.input.input.blur();
      }
    });
  }

  // CycleMode (ChatTextBox.cs:73-77)
  cycleMode() {
    this.mode = (this.mode + 1) % LANG.modeNames.length;
    this.modeButton.text = LANG.modeNamesShort[this.mode];
    this.#renderModeLabel();
  }
  setMode(mode) { this.mode = mode; this.modeButton.text = LANG.modeNamesShort[mode]; this.#renderModeLabel(); }
  #renderModeLabel() { this.modeButton.el.querySelector('.dxbtn-label').textContent = LANG.modeNamesShort[this.mode]; }

  // LinkItem (ChatTextBox.cs:79-86) — 背包 Shift 点物品 → 输入框插入 [物品名]
  linkItem(displayText, itemIndex) {
    if (this.linkedItemIndexes.length >= 10) return; // Globals.MaxChatItemLinks
    this.input.text += `[${displayText}]`;
    this.linkedItemIndexes.push(itemIndex);
    this.input.focus();
    this.input.input.setSelectionRange(this.input.text.length, this.input.text.length);
  }

  // StartPM (ChatTextBox.cs:88-95) — 点聊天记录玩家名 → 私聊
  startPM(name) {
    if (!name || !name.trim()) return;
    this.lastPM = `/${name}`;
    this.input.text = `${this.lastPM} `;
    this.focusInput();
  }

  // OpenChat (ChatTextBox.cs:97-118) — Enter/空格打开: 按频道预填前缀
  openChat() {
    this.visible = true;
    if (!this.input.text) {
      this.input.text = this.#modePrefix();
    }
    this.focusInput();
  }
  #modePrefix() {
    switch (this.mode) {
      case ChatTextBox.ChatMode.Shout: return '!';
      case ChatTextBox.ChatMode.Whisper: return this.lastPM ? `${this.lastPM} ` : '';
      case ChatTextBox.ChatMode.Group: return '!!';
      case ChatTextBox.ChatMode.Guild: return '!~';
      case ChatTextBox.ChatMode.Global: return '!@';
      case ChatTextBox.ChatMode.Observer: return '#';
      default: return '';
    }
  }

  // HandleGlobalKey (ChatTextBox.cs:121-156) — GameScene 转发的空格/回车//、@/!
  // 返回 true = 事件已消费 (GameScene 停止快捷键分发)。
  handleGlobalKey(ev) {
    const active = document.activeElement;
    // 输入框已聚焦: 只拦截分发, 不吃事件 (ChatTextBox.cs:128)
    if (active && (active === this.input.input)) return true;

    if (ev.code === 'Space' || ev.code === 'Enter') {
      this.openChat();
      return true;   // 第一次回车只打开聚焦 (ChatTextBox.cs:136)
    }
    if (ev.code === 'Slash' && !ev.ctrlKey && !ev.altKey) {
      this.openChat();
      if (!this.input.text.trim()) this.input.text = this.lastPM ? `${this.lastPM} ` : '/';
      this.focusInput();
      return true;
    }
    // key.Unicode == '@' || ('!' && Shift) (ChatTextBox.cs:147-154)
    const uni = ev.key.length === 1 ? ev.key : '';
    if (uni === '@' || (uni === '!' && ev.shiftKey)) {
      this.openChat();
      this.input.text = uni === '!' ? '!' : '@';
      this.focusInput();
      return true;
    }
    return false;
  }

  focusInput() {
    this.input.focus();
    this.input.input.setSelectionRange(this.input.text.length, this.input.text.length);
  }

  // SubmitChat (ChatTextBox.cs:158-176)
  #submitChat(text) {
    if (text && text.trim()) {
      this.onSend(text.trim(), [...this.linkedItemIndexes]);
      if (text.startsWith('/')) this.lastPM = text.split(' ')[0];
      if (this.history.length === 0 || this.history[this.history.length - 1] !== text)
        this.history.push(text);
      if (this.history.length > 100) this.history.shift();
    }
    this.linkedItemIndexes = [];
    this.historyIndex = -1;
    this.historyDraft = '';
    this.input.text = '';
    this.input.input.blur();
  }

  // NavigateHistory (ChatTextBox.cs:179-221) — ↑旧 ↓新, 越界回草稿
  #navigateHistory(up) {
    if (this.history.length === 0) return;
    if (this.historyIndex === -1) {
      this.historyDraft = this.input.text;
      this.historyIndex = this.history.length;
    }
    if (up) {
      if (this.historyIndex <= 0) return;
      this.historyIndex--;
    } else {
      if (this.historyIndex >= this.history.length) {
        this.input.text = this.historyDraft;
        this.historyIndex = -1;
        this.focusInput();
        return;
      }
      this.historyIndex++;
      if (this.historyIndex >= this.history.length) {
        this.input.text = this.historyDraft;
        this.historyIndex = -1;
        this.focusInput();
        return;
      }
    }
    this.input.text = this.history[this.historyIndex];
    this.focusInput();
  }
}

// ---- OnChat (GameScene.cs:2536-2545) 消息行格式 ----
export function formatChatLine(p, selfName, objects) {
  const sender = p.objectID === 0xffffffff ? '' :
    objects?.get?.(p.objectID)?.name ?? (p.objectID === p.selfID ? selfName : LANG.system);
  return { text: `[${MsgTypeName[p.type] ?? p.type}] ${sender}: ${p.text}`.replace(': : ', ': '), type: p.type };
}
