// check-dispatch.js — ws.js DISPATCH 引用的 S 解析器是否都存在 (node 检查)
import { S } from '../static/js/net.js';

const SRC = (await import('../static/js/ws.js', { with: { type: 'javascript' } }).catch(() => null));
// ws.js 顶层无 window 引用前可直接 import; 失败则解析源码
let dispatchSrc = '';
if (SRC?.DISPATCH) {
  for (const [id, [name, parse]] of Object.entries(SRC.DISPATCH)) {
    if (typeof parse !== 'function') console.log('非函数:', id, name);
  }
} else {
  const text = await (await import('node:fs/promises')).readFile(
    new URL('../static/js/ws.js', import.meta.url), 'utf8');
  const re = /\[ID\.S_(\w+)\]:\s*\['(\w+)',\s*(?:S\.(\w+)|(?:\(r\)[^\n]*))?\]/g;
  let m, bad = [];
  while ((m = re.exec(text))) {
    const sName = m[3];
    if (sName && typeof S[sName] !== 'function') bad.push(`${m[1]} -> ${sName}`);
  }
  console.log(bad.length ? '缺失解析器:\n' + bad.join('\n') : '全部存在');
}
