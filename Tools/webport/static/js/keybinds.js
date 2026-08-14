// keybinds.js — KeyBindManager.cs 全量移植 (GodotClient/Controls/KeyBindManager.cs)
//   enum/默认表(:13-179) + GetAction(:250-268) + NormalizeKey(:270-273)
//   + GetKeyBindLabel(:276-297) + GetKeyText(:299-316)
//   + Load/Save/ResetDefaults 持久化(:181-238, localStorage = user://ZirconKeyBinds.ini)。
// 键名规范: 从 KeyboardEvent.code 归一化 (布局无关) —
//   KeyA→'a', Digit1→'1', Comma→',', Period→'.', Escape/Tab/F1..F12/Scrolllock 原名小写。
// 未绑定的键位槽 = null (C# Key.None)。模块加载即 Load() 一次 (对照 GameScene.cs:919)。

export const KeyBindAction = {
  None: 0,
  MenuWindow: 1, HelpWindow: 2, ConfigWindow: 3, CharacterWindow: 4,
  InventoryWindow: 5, MagicWindow: 6, MagicBarWindow: 7, DungeonFinderWindow: 8,
  StorageWindow: 9, BeltWindow: 10, AutoPotionWindow: 11, CurrencyWindow: 12,
  FilterDropWindow: 13, FortuneWindow: 14, ItemPickUp: 15, QuestTrackerWindow: 16,
  MapMiniWindow: 17, MapBigWindow: 18, RankingWindow: 19, GameStoreWindow: 20,
  CompanionWindow: 21, GroupWindow: 22, GuildWindow: 23, MailBoxWindow: 24,
  MailSendWindow: 25, BlockListWindow: 26, QuestLogWindow: 27, ChatOptionsWindow: 28,
  ExitGameWindow: 29, GroupAllowSwitch: 30, GroupTarget: 31, TradeRequest: 32,
  TradeAllowSwitch: 33, PartnerTeleport: 34, MountToggle: 35, AutoRunToggle: 36,
  ChangeChatMode: 37, ToggleItemLock: 38,
  UseBelt01: 39, UseBelt02: 40, UseBelt03: 41, UseBelt04: 42, UseBelt05: 43,
  UseBelt06: 44, UseBelt07: 45, UseBelt08: 46, UseBelt09: 47, UseBelt10: 48,
  ChangeAttackMode: 49, ChangePetMode: 50,
  SpellSet01: 51, SpellSet02: 52, SpellSet03: 53, SpellSet04: 54,
  SpellUse01: 55, SpellUse02: 56, SpellUse03: 57, SpellUse04: 58,
  SpellUse05: 59, SpellUse06: 60, SpellUse07: 61, SpellUse08: 62,
  SpellUse09: 63, SpellUse10: 64, SpellUse11: 65, SpellUse12: 66,
  SpellUse13: 67, SpellUse14: 68, SpellUse15: 69, SpellUse16: 70,
  SpellUse17: 71, SpellUse18: 72, SpellUse19: 73, SpellUse20: 74,
  SpellUse21: 75, SpellUse22: 76, SpellUse23: 77, SpellUse24: 78,
};
export const SPELL_USE_FIRST = KeyBindAction.SpellUse01;
export const SPELL_USE_LAST = KeyBindAction.SpellUse24;
export const SPELL_SET_FIRST = KeyBindAction.SpellSet01;
export const SPELL_SET_LAST = KeyBindAction.SpellSet04;
export const BELT_FIRST = KeyBindAction.UseBelt01;
export const BELT_LAST = KeyBindAction.UseBelt10;

// KeyBindInfo(action, key1, ctrl1, alt1, shift1) — 与 C# 构造签名一致
const bind = (action, key1, control1 = false, alt1 = false, shift1 = false) =>
  ({ action, key1, control1, alt1, shift1, key2: null, control2: false, alt2: false, shift2: false });

// KeyBindManager.KeyBinds 默认表 (KeyBindManager.cs:109-178)
export const KeyBinds = [
  bind(KeyBindAction.MenuWindow, 'n'),
  bind(KeyBindAction.HelpWindow, 'h'),
  bind(KeyBindAction.ConfigWindow, 'o'),
  bind(KeyBindAction.CharacterWindow, 'q'),
  bind(KeyBindAction.InventoryWindow, 'w'),
  bind(KeyBindAction.MagicWindow, 'e'),
  bind(KeyBindAction.MagicBarWindow, 'x'),
  bind(KeyBindAction.DungeonFinderWindow, 'j'),
  bind(KeyBindAction.StorageWindow, 's'),
  bind(KeyBindAction.BeltWindow, 'z'),
  bind(KeyBindAction.AutoPotionWindow, 'p', true),
  bind(KeyBindAction.CurrencyWindow, 'c', true),
  bind(KeyBindAction.FilterDropWindow, 'f', true),
  bind(KeyBindAction.FortuneWindow, 'r', true),
  bind(KeyBindAction.ItemPickUp, 'tab'),
  bind(KeyBindAction.QuestTrackerWindow, 'l'),
  bind(KeyBindAction.MapMiniWindow, 'v'),
  bind(KeyBindAction.MapBigWindow, 'b'),
  bind(KeyBindAction.RankingWindow, 'r'),
  bind(KeyBindAction.GameStoreWindow, 'y'),
  bind(KeyBindAction.CompanionWindow, 'u'),
  bind(KeyBindAction.GroupWindow, 'p'),
  bind(KeyBindAction.GuildWindow, 'g'),
  bind(KeyBindAction.MailBoxWindow, ','),
  bind(KeyBindAction.MailSendWindow, '.'),
  bind(KeyBindAction.BlockListWindow, 'b', true),
  bind(KeyBindAction.QuestLogWindow, 'k'),
  bind(KeyBindAction.ChatOptionsWindow, 'o', true),
  bind(KeyBindAction.ExitGameWindow, 'escape'),
  bind(KeyBindAction.UseBelt01, '1', false, false, true),  // Shift+1..0 (Key.Key1+Shift)
  bind(KeyBindAction.UseBelt02, '2', false, false, true),
  bind(KeyBindAction.UseBelt03, '3', false, false, true),
  bind(KeyBindAction.UseBelt04, '4', false, false, true),
  bind(KeyBindAction.UseBelt05, '5', false, false, true),
  bind(KeyBindAction.UseBelt06, '6', false, false, true),
  bind(KeyBindAction.UseBelt07, '7', false, false, true),
  bind(KeyBindAction.UseBelt08, '8', false, false, true),
  bind(KeyBindAction.UseBelt09, '9', false, false, true),
  bind(KeyBindAction.UseBelt10, '0', false, false, true),
  bind(KeyBindAction.ChangeAttackMode, 'h', true),
  bind(KeyBindAction.ChangePetMode, 'a', true),
  bind(KeyBindAction.ToggleItemLock, 'scrolllock'),
  bind(KeyBindAction.SpellSet01, 'f1', true),
  bind(KeyBindAction.SpellSet02, 'f2', true),
  bind(KeyBindAction.SpellSet03, 'f3', true),
  bind(KeyBindAction.SpellSet04, 'f4', true),
  bind(KeyBindAction.SpellUse01, 'f1'),
  bind(KeyBindAction.SpellUse02, 'f2'),
  bind(KeyBindAction.SpellUse03, 'f3'),
  bind(KeyBindAction.SpellUse04, 'f4'),
  bind(KeyBindAction.SpellUse05, 'f5'),
  bind(KeyBindAction.SpellUse06, 'f6'),
  bind(KeyBindAction.SpellUse07, 'f7'),
  bind(KeyBindAction.SpellUse08, 'f8'),
  bind(KeyBindAction.SpellUse09, 'f9'),
  bind(KeyBindAction.SpellUse10, 'f10'),
  bind(KeyBindAction.SpellUse11, 'f11'),
  bind(KeyBindAction.SpellUse12, 'f12'),
  bind(KeyBindAction.SpellUse13, 'f1', false, false, true),
  bind(KeyBindAction.SpellUse14, 'f2', false, false, true),
  bind(KeyBindAction.SpellUse15, 'f3', false, false, true),
  bind(KeyBindAction.SpellUse16, 'f4', false, false, true),
  bind(KeyBindAction.SpellUse17, 'f5', false, false, true),
  bind(KeyBindAction.SpellUse18, 'f6', false, false, true),
  bind(KeyBindAction.SpellUse19, 'f7', false, false, true),
  bind(KeyBindAction.SpellUse20, 'f8', false, false, true),
  bind(KeyBindAction.SpellUse21, 'f9', false, false, true),
  bind(KeyBindAction.SpellUse22, 'f10', false, false, true),
  bind(KeyBindAction.SpellUse23, 'f11', false, false, true),
  bind(KeyBindAction.SpellUse24, 'f12', false, false, true),
];

// KeyboardEvent.code → 归一化键名 (等价 Godot Key 枚举比较; NormalizeKey 含小键盘归一)
export function normalizeCode(code) {
  if (!code) return '';
  if (code.startsWith('Key')) return code.slice(3).toLowerCase();        // KeyA → a
  if (code.startsWith('Digit')) return code.slice(5);                    // Digit1 → 1
  if (code.startsWith('Numpad')) {                                      // 小键盘数字归一 (KeyBindManager.cs:270)
    const d = code.slice(6);
    if (/^\d$/.test(d)) return d;
    return '';
  }
  const map = {
    Comma: ',', Period: '.', Escape: 'escape', Tab: 'tab',
    ScrollLock: 'scrolllock', F1: 'f1', F2: 'f2', F3: 'f3', F4: 'f4', F5: 'f5',
    F6: 'f6', F7: 'f7', F8: 'f8', F9: 'f9', F10: 'f10', F11: 'f11', F12: 'f12',
  };
  return map[code] ?? code.toLowerCase();
}

// GetAction(InputEventKey) — KeyboardEvent 版 (KeyBindManager.cs:250-268)
export function getAction(ev) {
  if (!ev || ev.type !== 'keydown') return KeyBindAction.None;
  const ctrl = ev.ctrlKey, alt = ev.altKey, shift = ev.shiftKey;
  const pressed = normalizeCode(ev.code);
  if (!pressed) return KeyBindAction.None;
  for (const b of KeyBinds) {
    const first = b.key1 === pressed && b.control1 === ctrl && b.alt1 === alt && b.shift1 === shift;
    const second = b.key2 != null && b.key2 === pressed
      && b.control2 === ctrl && b.alt2 === alt && b.shift2 === shift;
    if (first || second) return b.action;
  }
  return KeyBindAction.None;
}

// GetKeyText (KeyBindManager.cs:299-316): 字母→大写单字符, 数字原样,
// 特殊键映射 (C# fallback = Key 枚举 ToString(): Comma/Period/Scrolllock 原名)。
const KEY_TEXT = {
  escape: 'Esc', tab: 'Tab', up: 'Up', down: 'Down', left: 'Left', right: 'Right',
  ',': 'Comma', '.': 'Period', scrolllock: 'Scrolllock',
};
export function getKeyText(key) {
  if (key == null) return 'None'; // Key.None.ToString()
  if (KEY_TEXT[key]) return KEY_TEXT[key];
  return key.length === 1 ? key.toUpperCase() : key[0].toUpperCase() + key.slice(1);
}

// GetKeyBindLabel (KeyBindManager.cs:276-297): "Ctrl + H"
export function getKeyBindLabel(action) {
  const b = KeyBinds.find(x => x.action === action);
  if (!b) return 'None';
  let text = '';
  if (b.control1) text += 'Ctrl + ';
  if (b.alt1) text += 'Alt + ';
  if (b.shift1) text += 'Shift + ';
  text += getKeyText(b.key1);
  if (b.key2 != null) {
    text += ', ';
    if (b.control2) text += 'Ctrl + ';
    if (b.alt2) text += 'Alt + ';
    if (b.shift2) text += 'Shift + ';
    text += getKeyText(b.key2);
  }
  return text;
}

// ---- 持久化 (KeyBindManager.cs:181-238) ----
// C# ConfigFile user://ZirconKeyBinds.ini → localStorage JSON:
//   { "<ActionName>": { Key1, Key2, Control1, Alt1, Shift1, Control2, Alt2, Shift2 } }
const STORAGE_KEY = 'ZirconKeyBinds.ini';
const cloneBind = (b) => ({
  action: b.action, key1: b.key1, control1: b.control1, alt1: b.alt1, shift1: b.shift1,
  key2: b.key2, control2: b.control2, alt2: b.alt2, shift2: b.shift2,
});
const ACTION_NAMES = Object.fromEntries(
  Object.entries(KeyBindAction).filter(([, v]) => typeof v === 'number').map(([k, v]) => [v, k]));
const Defaults = KeyBinds.map(cloneBind);
let _loaded = false;

function storage() {
  try { return globalThis.localStorage ?? null; } catch { return null; }
}

// Load (KeyBindManager.cs:184-203): 只覆盖 ini 中出现的 section/字段, 其余保留当前值
export function load() {
  if (_loaded) return;
  _loaded = true;
  const s = storage();
  if (!s) return;
  let ini;
  try { ini = JSON.parse(s.getItem(STORAGE_KEY)); } catch { ini = null; }
  if (!ini || typeof ini !== 'object') return;
  for (const b of KeyBinds) {
    const sec = ini[ACTION_NAMES[b.action]];
    if (!sec || !('Key1' in sec)) continue; // C#: !file.HasSectionKey(section, "Key1") → continue
    b.key1 = sec.Key1 ?? null;
    b.key2 = sec.Key2 ?? null;                       // C# 默认 Key.None
    b.control1 = sec.Control1 ?? b.control1;          // C# 默认 = 当前值
    b.alt1 = sec.Alt1 ?? b.alt1;
    b.shift1 = sec.Shift1 ?? b.shift1;
    b.control2 = sec.Control2 ?? false;
    b.alt2 = sec.Alt2 ?? false;
    b.shift2 = sec.Shift2 ?? false;
  }
}

// Save (KeyBindManager.cs:205-221): 全量写回
export function save() {
  const s = storage();
  if (!s) return;
  const ini = {};
  for (const b of KeyBinds) {
    ini[ACTION_NAMES[b.action]] = {
      Key1: b.key1, Key2: b.key2,
      Control1: b.control1, Alt1: b.alt1, Shift1: b.shift1,
      Control2: b.control2, Alt2: b.alt2, Shift2: b.shift2,
    };
  }
  s.setItem(STORAGE_KEY, JSON.stringify(ini));
}

// ResetDefaults (KeyBindManager.cs:223-238): 就地恢复默认并 Save
export function resetDefaults() {
  for (const b of KeyBinds) {
    const d = Defaults.find(x => x.action === b.action);
    if (!d) continue;
    Object.assign(b, cloneBind(d));
  }
  save();
}

// 重绑数据层 (对照 KeyBindDialog.cs:113-148 直接改 KeyBindInfo 公有字段):
// getBind(action) 返回可变绑定对象; 捕获新键用 normalizeCode(ev.code) + ev.ctrl/alt/shiftKey。
export function getBind(action) {
  return KeyBinds.find(x => x.action === action) ?? null;
}

load(); // 对照 GameScene.cs:919 KeyBindManager.Load() (启动即载入, 幂等)
