// mode.js — 双 UI 参考模式管理 (总纲 §一 "双 UI 参考")
// zircon = 主线 (ui_tree.json + Interface.Zl→WebP); ei = 参考 (webclient 的 EI 风格)
// 选择持久化 localStorage, 默认 zircon。

const KEY = 'webport_uimode';
export const MODES = ['zircon', 'ei'];
export const MODE_LABELS = { zircon: 'Zircon (主线)', ei: 'EI (参考)' };

export function getMode() {
  const v = localStorage.getItem(KEY);
  return MODES.includes(v) ? v : 'zircon';
}

export function setMode(mode) {
  if (!MODES.includes(mode)) return;
  localStorage.setItem(KEY, mode);
}

export function isEI() { return getMode() === 'ei'; }
