// check-keybinds.mjs — E路(par-keys) 逐绑定验证:
//   直接解析 GodotClient/Controls/KeyBindManager.cs 的 enum + 默认表,
//   与 static/js/keybinds.js 逐条 diff, 再对每个绑定做 GetAction 正/负例、
//   Key2 双键、normalizeCode(含小键盘归一)、GetKeyText/GetKeyBindLabel、
//   Load/Save/ResetDefaults 持久化往返。
// 运行: node Tools/webport/scripts/check-keybinds.mjs   (退出码 0=全过)
import { readFileSync } from 'node:fs';

const CS_PATH = process.env.MIR3_ZIRCON_ROOT
  ? process.env.MIR3_ZIRCON_ROOT + '/GodotClient/Controls/KeyBindManager.cs'
  : '/home/tetsuya/development/zircon/GodotClient/Controls/KeyBindManager.cs';
const cs = readFileSync(CS_PATH, 'utf8');

let failures = 0, checks = 0;
const fail = (msg) => { failures++; console.log('FAIL: ' + msg); };
const assertEq = (a, b, msg) => {
  checks++;
  const ja = JSON.stringify(a), jb = JSON.stringify(b);
  if (ja !== jb) { failures++; console.log(`FAIL: ${msg}\n      got      ${ja}\n      expected ${jb}`); }
};

// ---------- 1. 解析 C# enum (顺序即编号) ----------
const enumBlock = cs.match(/public enum KeyBindAction\s*\{([^}]*)\}/)[1];
const enumNames = enumBlock.split('\n').map(l => l.replace(/\/\/.*$/, '').trim())
  .filter(l => l && l !== '{').flatMap(l =>
    l.includes(',') ? l.split(',').map(s => s.trim()).filter(Boolean) : [l])
  .filter(n => n !== 'None');
console.log(`[1] C# enum 解析: ${enumNames.length} 个动作 (None 除外)`);

// ---------- 2. 解析 C# 默认表 ----------
const tableBlock = cs.match(/public static readonly List<KeyBindInfo> KeyBinds[\s\S]*?\{([\s\S]*?)\n    \};/)[1];
const csTable = [...tableBlock.matchAll(/new KeyBindInfo\(KeyBindAction\.(\w+),\s*Key\.(\w+)((?:,\s*(?:control1|alt1|shift1): true)*)\)/g)]
  .map(m => ({
    action: m[1],
    key: m[2],
    control1: m[3].includes('control1'),
    alt1: m[3].includes('alt1'),
    shift1: m[3].includes('shift1'),
  }));
console.log(`[2] C# 默认表解析: ${csTable.length} 条绑定`);
if (csTable.length !== 70) fail(`C# 表条数 ${csTable.length} != 70 (解析器漂移?)`);

// C# Key 枚举名 → JS 归一化键名 (与 normalizeCode 产物同域)
const KEY_MAP = { Comma: ',', Period: '.', Escape: 'escape', Tab: 'tab', Scrolllock: 'scrolllock' };
const csKeyToJs = (k) => {
  if (KEY_MAP[k]) return KEY_MAP[k];
  if (/^Key\d$/.test(k)) return k.slice(3);
  if (/^F\d{1,2}$/.test(k)) return k.toLowerCase();
  if (/^[A-Z]$/.test(k)) return k.toLowerCase();
  throw new Error('未映射的 C# Key: ' + k);
};
// JS 归一化键名 → KeyboardEvent.code
const jsKeyToCode = (k) => {
  if (/^[a-z]$/.test(k)) return 'Key' + k.toUpperCase();
  if (/^[0-9]$/.test(k)) return 'Digit' + k;
  if (/^f\d{1,2}$/.test(k)) return 'F' + k.slice(1);
  return { ',': 'Comma', '.': 'Period', escape: 'Escape', tab: 'Tab', scrolllock: 'ScrollLock' }[k] ?? k;
};

// ---------- 3. import keybinds.js (主实例, 无 localStorage → 默认表) ----------
const mod = await import('../static/js/keybinds.js');
const { KeyBindAction, KeyBinds, getAction, normalizeCode, getKeyText, getKeyBindLabel } = mod;
const numToName = Object.fromEntries(Object.entries(KeyBindAction).map(([k, v]) => [v, k]));
const jsActionNames = Object.keys(KeyBindAction).filter(k => k !== 'None');

console.log('[3] enum 逐名比对');
assertEq(jsActionNames, enumNames, 'enum 名称/顺序不一致');

console.log('[4] 默认表逐条比对 (action/key/修饰键/Key2)');
assertEq(KeyBinds.length, csTable.length, '表条数不一致');
KeyBinds.forEach((b, i) => {
  const want = csTable[i];
  const got = {
    action: numToName[b.action], key: b.key1,
    control1: b.control1, alt1: b.alt1, shift1: b.shift1,
  };
  assertEq(got, { ...want, key: csKeyToJs(want.key) }, `第${i}条 ${want.action}`);
  assertEq(b.key2, null, `${want.action}.Key2 应为 null (C# Key.None)`);
});

// ---------- 5. GetAction 正例: 每条绑定合成 keydown 必须命中 ----------
console.log('[5] GetAction 正例 (逐绑定)');
const synth = (key, ctrl = false, alt = false, shift = false) =>
  ({ type: 'keydown', code: jsKeyToCode(key), ctrlKey: ctrl, altKey: alt, shiftKey: shift });
for (const e of csTable) {
  const act = getAction(synth(csKeyToJs(e.key), e.control1, e.alt1, e.shift1));
  if (act === KeyBindAction[e.action]) checks++;
  else fail(`正例未命中: ${e.action} <- ${e.key}`);
}

// ---------- 6. GetAction 负例: 翻转任一修饰键不得命中原 action ----------
console.log('[6] GetAction 负例 (修饰键翻转)');
for (const e of csTable) {
  const combos = [
    [!e.control1, e.alt1, e.shift1], [e.control1, !e.alt1, e.shift1], [e.control1, e.alt1, !e.shift1],
    [!e.control1, !e.alt1, !e.shift1],
  ];
  for (const [c, a, s] of combos) {
    const act = getAction(synth(csKeyToJs(e.key), c, a, s));
    if (act !== KeyBindAction[e.action]) checks++;
    else fail(`负例误命中: ${e.action} 在修饰键组合 c=${c},a=${a},s=${s} 下仍触发`);
  }
}

// ---------- 7. 同键不同修饰键 → 不同 action (键位表内在一致性) ----------
console.log('[7] 冲突键位语义');
assertEq(getAction(synth('p')), KeyBindAction.GroupWindow, 'p → GroupWindow');
assertEq(getAction(synth('p', true)), KeyBindAction.AutoPotionWindow, 'Ctrl+P → AutoPotionWindow');
assertEq(getAction(synth('r')), KeyBindAction.RankingWindow, 'r → RankingWindow');
assertEq(getAction(synth('r', true)), KeyBindAction.FortuneWindow, 'Ctrl+R → FortuneWindow');
assertEq(getAction(synth('b')), KeyBindAction.MapBigWindow, 'b → MapBigWindow');
assertEq(getAction(synth('b', true)), KeyBindAction.BlockListWindow, 'Ctrl+B → BlockListWindow');
assertEq(getAction(synth('o')), KeyBindAction.ConfigWindow, 'o → ConfigWindow');
assertEq(getAction(synth('o', true)), KeyBindAction.ChatOptionsWindow, 'Ctrl+O → ChatOptionsWindow');
assertEq(getAction(synth('h')), KeyBindAction.HelpWindow, 'h → HelpWindow');
assertEq(getAction(synth('h', true)), KeyBindAction.ChangeAttackMode, 'Ctrl+H → ChangeAttackMode');
assertEq(getAction(synth('a', true)), KeyBindAction.ChangePetMode, 'Ctrl+A → ChangePetMode');
assertEq(getAction(synth('f1')), KeyBindAction.SpellUse01, 'F1 → SpellUse01');
assertEq(getAction(synth('f1', true)), KeyBindAction.SpellSet01, 'Ctrl+F1 → SpellSet01');
assertEq(getAction(synth('f1', false, false, true)), KeyBindAction.SpellUse13, 'Shift+F1 → SpellUse13');
assertEq(getAction(synth('a')), KeyBindAction.None, '裸 a 无绑定 → None');
assertEq(getAction({ type: 'keyup', code: 'KeyN' }), KeyBindAction.None, 'keyup 不分发');
assertEq(getAction(null), KeyBindAction.None, 'null 事件 → None');

// ---------- 8. NormalizeKey 小键盘归一 (KeyBindManager.cs:270-273) ----------
console.log('[8] normalizeCode / 小键盘归一');
for (const [code, want] of [
  ['KeyA', 'a'], ['Digit7', '7'], ['Numpad4', '4'], ['Numpad0', '0'],
  ['NumpadEnter', ''], ['Comma', ','], ['Period', '.'], ['Escape', 'escape'],
  ['Tab', 'tab'], ['F12', 'f12'], ['ScrollLock', 'scrolllock'],
]) assertEq(normalizeCode(code), want, `normalizeCode(${code})`);
assertEq(getAction(synth('4', false, false, true)), KeyBindAction.UseBelt04, 'Shift+4 → UseBelt04');
assertEq(getAction({ type: 'keydown', code: 'Numpad4', ctrlKey: false, altKey: false, shiftKey: true }),
  KeyBindAction.UseBelt04, 'Shift+小键盘4 → UseBelt04 (Kp4 归一为 Key4)');

// ---------- 9. GetKeyText / GetKeyBindLabel (C# ToString 域) ----------
console.log('[9] GetKeyText / GetKeyBindLabel');
for (const [key, want] of [
  ['escape', 'Esc'], ['tab', 'Tab'], [',', 'Comma'], ['.', 'Period'],
  ['scrolllock', 'Scrolllock'], ['a', 'A'], ['1', '1'], ['f1', 'F1'], ['f12', 'F12'],
  ['up', 'Up'], [null, 'None'],
]) assertEq(getKeyText(key), want, `getKeyText(${key})`);
for (const [action, want] of [
  ['ChangeAttackMode', 'Ctrl + H'], ['UseBelt01', 'Shift + 1'], ['UseBelt10', 'Shift + 0'],
  ['SpellSet01', 'Ctrl + F1'], ['SpellUse13', 'Shift + F1'], ['SpellUse12', 'F12'],
  ['MailBoxWindow', 'Comma'], ['MailSendWindow', 'Period'], ['ToggleItemLock', 'Scrolllock'],
  ['ExitGameWindow', 'Esc'], ['MenuWindow', 'N'], ['None', 'None'],
]) assertEq(getKeyBindLabel(KeyBindAction[action]), want, `getKeyBindLabel(${action})`);

// ---------- 10. Key2 双键 (GetAction second 分支) ----------
console.log('[10] Key2 双键');
{
  const b = KeyBinds.find(x => x.action === KeyBindAction.HelpWindow);
  const saved = { key1: b.key1, control1: b.control1, alt1: b.alt1, shift1: b.shift1 };
  Object.assign(b, { key2: 'f24', control2: true, alt2: false, shift2: false });
  assertEq(getAction(synth('f24', true)), KeyBindAction.HelpWindow, 'Key2=Ctrl+F24 命中');
  assertEq(getAction(synth('f24')), KeyBindAction.None, 'Key2 修饰键不符 → None');
  assertEq(getKeyBindLabel(KeyBindAction.HelpWindow), 'H, Ctrl + F24', '双键标签 "H, Ctrl + F24"');
  Object.assign(b, { key2: null, control2: false, alt2: false, shift2: false }, saved);
}

// ---------- 11. 持久化: mock localStorage + 独立模块实例 ----------
console.log('[11] Load/Save/ResetDefaults (localStorage 往返)');
const mkStore = () => {
  const m = new Map();
  globalThis.localStorage = {
    getItem: (k) => (m.has(k) ? m.get(k) : null),
    setItem: (k, v) => m.set(k, String(v)),
    removeItem: (k) => m.delete(k),
  };
  return m;
};
const store = mkStore();
const fresh = (n) => import('../static/js/keybinds.js?t=' + n);

{ // 11a. 无存档 → 默认表
  const m1 = await fresh('a');
  assertEq(m1.getKeyBindLabel(m1.KeyBindAction.HelpWindow), 'H', '无存档 → 默认 H');
}
{ // 11b. 改绑 + save → 存档内容正确
  const m2 = await fresh('b');
  const hb = m2.getBind(m2.KeyBindAction.HelpWindow);
  hb.key1 = 'f24'; hb.alt1 = true; hb.control1 = false;
  m2.save();
  const raw = JSON.parse(store.get('ZirconKeyBinds.ini'));
  assertEq(raw.HelpWindow, { Key1: 'f24', Key2: null, Control1: false, Alt1: true, Shift1: false,
    Control2: false, Alt2: false, Shift2: false }, 'save() 写入 HelpWindow section');
}
{ // 11c. 新实例 load → 改绑生效且可触发
  const m3 = await fresh('c');
  assertEq(m3.getAction(synth('f24', false, true)), m3.KeyBindAction.HelpWindow, 'Alt+F24 → HelpWindow (已改绑)');
  assertEq(m3.getAction(synth('h')), m3.KeyBindAction.None, '原 H 不再触发 HelpWindow');
}
{ // 11d. 部分字段 section: 缺 Key1 → 跳过; 缺修饰键 → 保留默认
  //    (C# 语义: 新进程 KeyBinds 先取默认值, Load 只覆盖 ini 出现的 section/字段)
  const raw = JSON.parse(store.get('ZirconKeyBinds.ini'));
  raw.HelpWindow = { Control1: true };                       // 无 Key1 → 整节跳过
  raw.ExitGameWindow = { Key1: 'f23' };                        // 仅 Key1 → 修饰键保持默认
  store.set('ZirconKeyBinds.ini', JSON.stringify(raw));
  const m4 = await fresh('d');
  assertEq(m4.getBind(m4.KeyBindAction.HelpWindow).key1, 'h', '无 Key1 的 section 被跳过 → 保留默认 h');
  assertEq(m4.getBind(m4.KeyBindAction.ExitGameWindow).key1, 'f23', 'ExitGame 改绑 f23 生效');
  assertEq(m4.getBind(m4.KeyBindAction.ExitGameWindow).control1, false, '缺失字段保留默认 (C# GetValue 默认值语义)');
}
{ // 11e. resetDefaults → 恢复默认并写回存档
  const m5 = await fresh('e');
  m5.resetDefaults();
  const raw = JSON.parse(store.get('ZirconKeyBinds.ini'));
  assertEq(raw.HelpWindow.Key1, 'h', 'resetDefaults 后存档恢复 h');
  const m6 = await fresh('f');
  assertEq(m6.getAction(synth('h')), m6.KeyBindAction.HelpWindow, '新实例: H 重新触发 HelpWindow');
}

// ---------- 汇总 ----------
console.log(`\n${failures ? `✗ ${failures} 项失败` : `✓ 全部通过: ${checks} 项断言`}`);
process.exit(failures ? 1 : 0);
