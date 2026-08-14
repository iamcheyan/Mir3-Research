// themes/ei/login.js — EI 参考模式登录页 (webclient 的 EI 风格: 深棕金 CSS 面板)
// 逻辑层与 Zircon 模式共用 (ws.js/net.js); 仅 UI 外观不同。
import { LoginResultText, LOGIN_SUCCESS, NewAccountResultText, NEWACCOUNT_SUCCESS, NEWACCOUNT_ALREADY } from '../../net.js';

const css = `
.ei-root { position:absolute; inset:0; display:flex; align-items:center; justify-content:center;
  background: radial-gradient(ellipse at 50% 30%, #241f16 0%, #0a0a0e 70%); font-family:"Noto Sans CJK SC",sans-serif; }
.ei-panel { width:380px; background:linear-gradient(#2e2817f2,#1c180ef5); border:1px solid #6b5a33;
  border-radius:4px; box-shadow:0 4px 18px #000a; padding-bottom:14px; }
.ei-title { padding:8px 12px; background:#3a3223; color:#e8c96a; font-weight:bold; letter-spacing:2px;
  border-bottom:1px solid #6b5a33; font-size:15px; }
.ei-body { padding:14px 16px 0; display:flex; flex-direction:column; gap:10px; color:#ddd; font-size:13px; }
.ei-row { display:flex; align-items:center; gap:8px; }
.ei-row label { width:64px; color:#d8c690; }
.ei-input { flex:1; background:rgba(8,8,10,.7); border:1px solid #6b5a33; color:#eee;
  padding:6px 8px; font-size:13px; border-radius:2px; }
.ei-btn { background:#2e2817; color:#d8c690; border:1px solid #6b5a33; border-radius:3px;
  padding:6px 14px; cursor:pointer; font-size:13px; }
.ei-btn:hover { background:#4a3f24; color:#ffe9a8; }
.ei-btn:disabled { opacity:.45; cursor:default; }
.ei-status { min-height:18px; font-size:12px; color:#ffd573; }
.ei-check { display:flex; align-items:center; gap:6px; color:#d8c690; font-size:12px; cursor:pointer; }
`;

export class LoginScene {
  constructor(conn, onEnterSelect) {
    this.conn = conn;
    this.onEnterSelect = onEnterSelect;
    this.root = document.createElement('div');
    this.root.className = 'ei-root';
    const style = document.createElement('style');
    style.textContent = css + (document.getElementById('ei-login-style') ? '' : '');
    this.root.appendChild(style);

    const panel = document.createElement('div');
    panel.className = 'ei-panel';
    panel.innerHTML = `
      <div class="ei-title">传奇3 · 登录（EI 风格）</div>
      <div class="ei-body">
        <div class="ei-row"><label>邮箱</label><input class="ei-input" id="ei-email" type="text" placeholder="test@test.com"></div>
        <div class="ei-row"><label>密码</label><input class="ei-input" id="ei-pw" type="password" placeholder="test123"></div>
        <div class="ei-row">
          <label class="ei-check"><input type="checkbox" id="ei-remember">记住账号</label>
          <span style="flex:1"></span>
          <button class="ei-btn" id="ei-register">注册</button>
          <button class="ei-btn" id="ei-login" disabled>登录</button>
        </div>
        <div class="ei-status" id="ei-status">正在连接服务端...</div>
      </div>`;
    this.root.appendChild(panel);

    this.emailInput = panel.querySelector('#ei-email');
    this.passwordInput = panel.querySelector('#ei-pw');
    this.btnLogin = panel.querySelector('#ei-login');
    this.btnRegister = panel.querySelector('#ei-register');
    this.statusEl = panel.querySelector('#ei-status');
    this.chkRemember = panel.querySelector('#ei-remember');

    this.chkRemember.checked = localStorage.getItem('webport_remember') === '1';
    if (this.chkRemember.checked) {
      this.emailInput.value = localStorage.getItem('webport_email') ?? '';
      this.passwordInput.value = localStorage.getItem('webport_password') ?? '';
    }
    this.btnLogin.addEventListener('click', () => this.#onLogin());
    this.btnRegister.addEventListener('click', () => this.#onRegister());
    this.passwordInput.addEventListener('keydown', (ev) => { if (ev.key === 'Enter' && !this.btnLogin.disabled) this.#onLogin(); });
    this.#wire();
  }

  setStatus(text) { this.statusEl.textContent = text; }

  #wire() {
    this.conn.addEventListener('versionOK', () => {
      this.setStatus('已连接服务端');
      this.btnLogin.disabled = false;
      this.btnRegister.disabled = false;
    });
    this.conn.addEventListener('loginResult', (e) => this.#onLoginResult(e.detail));
    this.conn.addEventListener('newAccountResult', (e) => this.#onNewAccount(e.detail));
    this.conn.addEventListener('disconnected', () => {
      this.setStatus('与服务器的连接已断开');
      this.btnLogin.disabled = true; this.btnRegister.disabled = true;
    });
    this.conn.addEventListener('serverDisconnect', (e) => this.setStatus(`服务器断开: ${e.detail}`));
  }

  #onLogin() {
    this.btnLogin.disabled = true;
    this.setStatus('正在登录...');
    if (this.chkRemember.checked) {
      localStorage.setItem('webport_remember', '1');
      localStorage.setItem('webport_email', this.emailInput.value);
      localStorage.setItem('webport_password', this.passwordInput.value);
    } else {
      localStorage.removeItem('webport_remember');
      localStorage.removeItem('webport_email');
      localStorage.removeItem('webport_password');
    }
    this.conn.sendLogin(this.emailInput.value, this.passwordInput.value);
  }

  #onRegister() {
    this.btnRegister.disabled = true;
    this.setStatus('正在注册账号...');
    this.conn.sendNewAccount(this.emailInput.value, this.passwordInput.value);
  }

  #onNewAccount(result) {
    if (result === NEWACCOUNT_SUCCESS || result === NEWACCOUNT_ALREADY) {
      this.setStatus(`注册结果: ${NewAccountResultText[result]}，请登录`);
    } else {
      this.setStatus(`注册失败: ${NewAccountResultText[result] ?? result}`);
    }
    this.btnRegister.disabled = false;
  }

  #onLoginResult(p) {
    if (p.result === LOGIN_SUCCESS) {
      this.setStatus(`登录成功, 角色数 ${p.characters?.length ?? 0}`);
      this.onEnterSelect(p.characters ?? []);
    } else {
      this.setStatus(`登录失败: ${LoginResultText[p.result] ?? p.result}${p.message ? ` (${p.message})` : ''}`);
      this.btnLogin.disabled = false;
    }
  }
}
