// uitree.js — ui_tree.json (GodotClient/UI/ui_tree.json, UiTreeExporter 产物) 驱动的窗口渲染器。
// 46 窗口的控件树 (type/location/size/image{text,library,index}/hint/text) 是坐标唯一权威;
// 本模块只负责"画出来", 行为 (按钮点击/数据绑定) 由 game.js + dialogs 注册。

import { DXControl, DXImageControl, DXLabel, DXButton, DXTextInput, DXCheckBox } from './dx.js';
import { DXWindow, WindowManager, setHint } from './windows.js';

let TREE = null;
let TREE_PROMISE = null;

export function loadUiTree() {
  if (TREE_PROMISE) return TREE_PROMISE;
  TREE_PROMISE = fetch('/ui/ui_tree.json').then(r => r.json()).then(d => {
    TREE = d;
    TREE.byType = new Map(d.windows.map(w => [w.type, w]));
    return d;
  });
  return TREE_PROMISE;
}

export function getWindowDef(type) { return TREE?.byType?.get(type) ?? null; }

// ---- 单控件构建 ----
function buildControl(node, win) {
  const opts = {
    location: node.location ?? [0, 0],
    size: node.size ?? [0, 0],
    isControl: node.type !== 'DXImageControl' && node.type !== 'DXLabel',
  };
  let ctl = null;
  switch (node.type) {
    case 'DXImageControl': {
      const img = node.image ?? {};
      ctl = new DXImageControl({
        ...opts,
        library: img.library ?? 'Interface',
        index: img.index ?? -1,
        fixedSize: !!img.fixedSize,
        hoverIndex: img.hoverIndex ?? -1,
        pressedIndex: img.pressedIndex ?? -1,
        isControl: node.visible !== false && (img.hoverIndex ?? -1) >= 0, // 有 hover 帧的贴图可点
        foreColour: node.foreColour,
      });
      break;
    }
    case 'DXAnimatedControl': {
      const img = node.image ?? {};
      ctl = new DXImageControl({ ...opts, library: img.library ?? 'Interface', index: img.index ?? -1 });
      break;
    }
    case 'DXButton': {
      const img = node.image ?? {};
      ctl = new DXButton({
        ...opts,
        library: img.library ?? 'Interface',
        index: img.index ?? -1,
        text: node.text ?? '',
        fontSize: node.fontSize ?? 10,
        textColour: node.textColour,
      });
      break;
    }
    case 'DXLabel':
      ctl = new DXLabel({
        ...opts,
        text: node.text ?? '',
        fontSize: node.fontSize ?? 10,
        textColour: node.textColour,
        drawOutline: !!node.drawOutline,
        outlineColour: node.outlineColour,
        align: (node.align ?? 'Left').toLowerCase(),
        valign: node.valign === 'Center' ? 'center' : 'top',
        autoSize: node.autoSize !== false,
      });
      break;
    case 'DXTextInput':
      ctl = new DXTextInput({
        ...opts,
        fontSize: node.fontSize ?? 8,
        text: node.text ?? '',
        maxLength: node.maxLength || undefined,
        secret: !!node.secret,
      });
      break;
    case 'DXCheckBox':
      ctl = new DXCheckBox({ ...opts, label: node.text ?? '', checked: !!node.checked });
      break;
    default:
      ctl = new DXControl({ ...opts, backColour: null });
  }
  setHint(ctl, node.hint);
  ctl.treeNode = node;
  // 递归子控件
  for (const child of node.children ?? []) ctl.addControl(buildControl(child, win));
  if (node.visible === false) ctl.visible = false;
  return ctl;
}

// ---- 窗口构建 ----
// 返回 { win, byPath (Map path→ctl), buttons (DXButton[]), findByHint, findByText, findControls(type) }
export function buildWindow(type, overrides = {}) {
  const def = getWindowDef(type);
  if (!def) throw new Error(`ui_tree 缺窗口: ${type}`);
  const win = new DXWindow({
    title: def.title ?? '',
    size: def.size,
    hasTitle: def.hasTitle ?? true,
    hasFooter: def.hasFooter ?? false,
    showCloseButton: false, // 树里的 Interface[15] 关闭按钮由 buildControl 渲染后 wireClose
    movable: def.movable ?? true,
    allowResize: def.allowResize ?? false,
    ...overrides,
  });
  const byPath = new Map();
  const buttons = [];
  let closeBtn = null;

  for (const node of def.controls ?? []) {
    const ctl = buildControl(node, win);
    win.addControl(ctl);
    byPath.set(node.path, ctl);
    if (node.type === 'DXButton') buttons.push(ctl);
    // DXWindow.cs:88-98: 树里自带 Interface[15] = 关闭按钮
    if (node.type === 'DXButton' && node.image?.library === 'Interface' && node.image?.index === 15)
      closeBtn = ctl;
    // 窗口底图贴图 (fixedSize 全窗) 置底
    if (node.type === 'DXImageControl' && node.location?.[0] === 0 && node.location?.[1] === 0
      && (node.size?.[0] ?? 0) >= (def.size?.[0] ?? 0) - 2 && (node.size?.[1] ?? 0) >= (def.size?.[1] ?? 0) - 2)
      ctl.el.style.zIndex = '0';
  }
  win.wireClose(closeBtn);

  win.byPath = byPath;
  win.buttons = buttons;
  win.findByHint = (hint) => {
    for (const [p, c] of byPath) if (c.treeNode?.hint === hint) return c;
    return null;
  };
  win.findByText = (text) => {
    for (const [p, c] of byPath) if (c.treeNode?.text === text) return c;
    return null;
  };
  win.findAllByText = (text) => [...byPath.values()].filter(c => c.treeNode?.text === text);
  win.findControls = (type) => [...byPath.values()].filter(c => c.treeNode?.type === type);
  return win;
}

// 延迟构建+缓存 (每个窗口类型一个实例, 与 Godot 单例对话框对齐)
const built = new Map();
export async function getWindow(type, overrides = {}) {
  await loadUiTree();
  if (!built.has(type)) {
    try {
      built.set(type, buildWindow(type, overrides));
    } catch (e) {
      console.warn(`[uitree] 窗口 ${type} 构建失败:`, e.message);
      built.set(type, null);
    }
  }
  return built.get(type);
}
