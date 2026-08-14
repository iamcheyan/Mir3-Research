// shell.js — 常驻外壳: 双 UI 模式切换器 (两模式共用, 独立于主题)
// 右上角悬浮按钮 → 菜单 (Zircon 主线 / EI 参考) → 切换后整页重载重建 UI。
import { getMode, setMode, MODE_LABELS, MODES } from './mode.js';

export function mountModeSwitcher() {
  const btn = document.createElement('button');
  btn.id = 'mode-switcher';
  btn.textContent = MODE_LABELS[getMode()];
  btn.title = '切换 UI 参考模式 (Zircon 主线 / EI 参考)';

  const menu = document.createElement('div');
  menu.id = 'mode-menu';
  menu.style.display = 'none';
  for (const m of MODES) {
    const item = document.createElement('div');
    item.className = 'mode-item' + (m === getMode() ? ' active' : '');
    item.textContent = MODE_LABELS[m];
    item.addEventListener('click', () => {
      if (m === getMode()) { menu.style.display = 'none'; return; }
      setMode(m);
      location.reload();   // 重建整套 UI (逻辑层随页面重置, 简单可靠)
    });
    menu.appendChild(item);
  }
  btn.addEventListener('click', (ev) => {
    ev.stopPropagation();
    menu.style.display = menu.style.display === 'none' ? 'block' : 'none';
  });
  document.addEventListener('click', () => { menu.style.display = 'none'; });

  document.body.append(btn, menu);
}
