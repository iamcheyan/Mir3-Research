// win-gm.js — GM 面板 (Godot 无对应 — 自定义; 命令走真实 C.Chat("@CMD args"))
// 服务端: PlayerObject.Chat '@' 前缀 → SEnvir.CommandHandler (ServerLibrary/PlayerObject.cs:1786)。
// 命令清单自 ServerLibrary/Envir/Commands/Command/Admin/*.cs VALUE 属性。
// 仅 conn.isGM 时注册 (registry 过滤)。

import { WindowManager, DXWindow } from './windows.js';
import { DXControl, DXLabel, DXButton, DXTextInput } from './dx.js';
// 每组: [命令模板(占位 $1), 说明]
const COMMANDS = {
  '角色': [
    ['LEVEL $1', '设置等级 (LEVEL 50)'],
    ['GIVESKILLS', '授予全套职业技能'],
    ['TOGGLESUPERMAN', '切换无敌模式'],
    ['TOGGLEGAMEMASTER', '切换 GM 模式'],
    ['TOGGLEOBSERVER', '切换观察者模式'],
    ['KICK', '踢自己下线'],
  ],
  '物品/技能': [
    ['MAKE $1 $2', '造物 (MAKE 物品名 数量)'],
    ['GIVEITEM $1', '给物品 (别名)'],
  ],
  '移动': [
    ['MOVE $1 $2 $3', '地图移动 (MOVE 地图 X Y)'],
    ['GOTO $1', '传到玩家身边'],
    ['RECALLPLAYER $1', '召回玩家'],
    ['SPAWNMOB $1 $2', '刷怪 (SPAWNMOB 怪名 数量)'],
  ],
  '行会': [
    ['CREATEGUILD $1 $2', '创建行会 (名 会长)'],
  ],
};

export async function winGm(scene, store, reg) {
  if (!scene.conn?.isGM) return null;
  const w = new DXWindow({
    title: 'GM 面板', library: 'Interface', index: 160,
    location: [80, 120], size: [430, 470], allowResize: false, modal: false,
  });
  const content = new DXControl({ location: [8, 34], size: [414, 412], clip: true, isControl: false });
  w.addControl(content);

  // 免费输入行
  const cmdRow = new DXControl({ location: [8, 6], size: [414, 26], isControl: false });
  w.addControl(cmdRow);
  const cmdInput = new DXTextInput({ location: [0, 0], size: [300, 24], fontSize: 9,
    placeholder: '@命令 参数…' });
  cmdRow.addControl(cmdInput);
  cmdRow.addControl(new DXButton({ text: '执行', fontSize: 9, library: 'Interface', index: -1,
    location: [306, 0], size: [60, 24], onClick: () => {
      const t = cmdInput.text.trim();
      if (!t) return;
      conn.sendChat(t.startsWith('@') ? t : `@${t}`);
      cmdInput.text = '';
    } }));
  cmdInput.input.addEventListener('keydown', (ev) => {
    if (ev.key === 'Enter') {
      const t = cmdInput.text.trim();
      if (t) { conn.sendChat(t.startsWith('@') ? t : `@${t}`); cmdInput.text = ''; }
    }
  });

  // 命令组
  const area = new DXControl({ location: [8, 38], size: [414, 380], clip: true, isControl: false });
  w.addControl(area);
  let y = 0;
  for (const [group, list] of Object.entries(COMMANDS)) {
    area.addControl(new DXLabel({ text: group, fontSize: 10, textColour: [255, 216, 77, 255],
      drawOutline: true, location: [0, y], size: [200, 20], isControl: false }));
    y += 22;
    for (const [tpl, desc] of list) {
      const hasArg = tpl.includes('$');
      const base = tpl.split(' ')[0];
      const b = new DXButton({ text: tpl.replaceAll('$1', '…').replaceAll('$2', '…').replaceAll('$3', '…'),
        fontSize: 8, library: 'Interface', index: -1,
        location: [10, y], size: [170, 24], onClick: () => {
          if (!hasArg) { conn.sendChat(`@${tpl}`); return; }
          // 有参命令: 弹输入
          const ov = document.createElement('div');
          ov.style.cssText = 'position:fixed;inset:0;z-index:99996;display:flex;align-items:center;justify-content:center;background:rgba(0,0,0,.35);';
          const box = document.createElement('div');
          box.style.cssText = `width:340px;padding:14px;background:rgba(28,22,10,.97);border:1px solid #8a6d35;color:#ffdb8e;font-family:'Noto Sans CJK SC',sans-serif;`;
          const t = document.createElement('div');
          t.textContent = `${desc} — ${tpl}`;
          t.style.cssText = 'font-size:13px;margin-bottom:10px;';
          const i = document.createElement('input');
          i.style.cssText = 'width:100%;padding:6px;background:#000;border:1px solid #8a6d35;color:#ffdb8e;margin-bottom:10px;';
          const row = document.createElement('div');
          row.style.cssText = 'display:flex;gap:8px;justify-content:flex-end;';
          const mk = (label, send) => {
            const bb = document.createElement('button');
            bb.textContent = label;
            bb.style.cssText = 'padding:6px 16px;cursor:pointer;background:#4a3818;color:#ffdb8e;border:1px solid #8a6d35;font-size:13px;';
            bb.onclick = () => {
              if (send) {
                let k = 0;
                const args = i.value.trim().split(/\s+/).filter(Boolean);
                const cmd = tpl.replace(/\$[123]/g, () => args[k++] ?? '');
                conn.sendChat(`@${cmd}`);
              }
              ov.remove();
            };
            return bb;
          };
          row.append(mk('发送', true), mk('取消', false));
          box.append(t, i, row);
          ov.appendChild(box);
          scene.root.appendChild(ov);
          i.focus();
        } });
      b.el.title = desc;
      area.addControl(b);
      const d = new DXLabel({ text: desc, fontSize: 8, textColour: [180, 180, 180, 255],
        drawOutline: true, location: [186, y + 3], size: [220, 18], isControl: false });
      area.addControl(d);
      y += 26;
    }
    y += 8;
  }

  // 快速等级/金币 (常用)
  const quick = new DXControl({ location: [8, 424], size: [414, 30], isControl: false });
  w.addControl(quick);
  const lvlInput = new DXTextInput({ location: [0, 4], size: [70, 22], fontSize: 9, placeholder: '等级' });
  quick.addControl(lvlInput);
  quick.addControl(new DXButton({ text: '设等级', fontSize: 8, library: 'Interface', index: -1,
    location: [76, 3], size: [64, 24], onClick: () => {
      const v = parseInt(lvlInput.text, 10);
      if (v > 0) conn.sendChat(`@LEVEL ${v}`);
    } }));
  const goldInput = new DXTextInput({ location: [150, 4], size: [100, 22], fontSize: 9, placeholder: '金币数' });
  quick.addControl(goldInput);
  quick.addControl(new DXButton({ text: '给金币', fontSize: 8, library: 'Interface', index: -1,
    location: [256, 3], size: [70, 24], onClick: () => {
      const v = parseInt(goldInput.text, 10);
      if (v > 0) conn.sendChat(`@MAKE 金币 ${v}`);
    } }));

  void store; void reg;

  reg.wins.set('gm', w);
  return {
    win: w,
    open: () => WindowManager.open(w, scene.hudLayer),
    close: () => WindowManager.close(w),
    toggle: () => { if (w.visible) WindowManager.close(w); else WindowManager.open(w, scene.hudLayer); },
  };
}
