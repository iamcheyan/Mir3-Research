/* portal.js — Mir3 工具门户共享脚本（Phase 1，Goal §3.1/§3.3）
 *
 * 职责：
 *   - 健康检查渲染（WU.portal.renderHealth）
 *   - 最近访问（localStorage，WU.portal.recent）
 *   - 工具深链（链接上加 ?from=portal 以便统计，不强制）
 *
 * 门户页面（Tools/portal）引入本文件；其他工具以后可复用 recent 做互跳。
 */
(function () {
  "use strict";
  const WU = window.WU = window.WU || {};
  WU.portal = WU.portal || {};

  const RECENT_KEY = "mir3_portal_recent_v1";
  const RECENT_MAX = 6;

  WU.portal.rememberVisit = function (name, url) {
    try {
      const list = JSON.parse(localStorage.getItem(RECENT_KEY) || "[]");
      const next = [{ name, url, t: Date.now() }]
        .concat(list.filter(v => v.url !== url))
        .slice(0, RECENT_MAX);
      localStorage.setItem(RECENT_KEY, JSON.stringify(next));
    } catch (e) { /* localStorage 不可用时静默降级 */ }
  };

  WU.portal.recent = function () {
    try { return JSON.parse(localStorage.getItem(RECENT_KEY) || "[]"); }
    catch (e) { return []; }
  };

  const esc = (s) => String(s).replace(/[&<>"']/g,
    c => ({ "&": "&amp;", "<": "&lt;", ">": "&gt;", '"': "&quot;", "'": "&#39;" }[c]));

  WU.portal.renderHealth = function (container, data) {
    if (!container) return;
    const tools = (data && data.tools) || [];
    container.innerHTML = tools.map(t => {
      const up = t.up;
      const dot = `<span class="wu-status-dot ${up ? "up" : "down"}"></span>`;
      const count = t.detail ? ` <span style="color:var(--wu-dim,#8b95a3);font-size:12px">${esc(t.detail)}</span>` : "";
      const open = up
        ? `<a class="wu-card-open" href="${esc(t.url)}" target="_blank" rel="noopener">打开 →</a>`
        : `<div class="wu-card-hint">未运行 · 启动：<code>${esc(t.start)}</code></div>`;
      return `<div class="wu-card tool-card ${up ? "" : "down"}">
        <div class="tool-head">${dot}<b>${esc(t.name)}</b>
          <span class="wu-badge ${t.ro ? "ro" : "rw"}">${t.ro ? "只读" : "可写"}</span>
          <span class="wu-badge ${up ? t.mob : "mobile-no"}">${up ? esc(t.mobLabel) : "离线"}</span>
          <span style="color:var(--wu-dim,#8b95a3);font-size:12px">:${t.port}</span>
        </div>
        <div class="tool-desc">${esc(t.desc)}${count}</div>
        ${open}
      </div>`;
    }).join("");
    container.querySelectorAll("a.wu-card-open").forEach(a => {
      a.addEventListener("click", () => {
        const name = a.closest(".tool-card").querySelector("b").textContent;
        WU.portal.rememberVisit(name, a.getAttribute("href"));
      });
    });
  };
})();
