// login.js — LoginScene (Scripts/LoginScene.cs 逐行移植; 布局 = BuildLegacyLoginUi L368-530)
// 所有坐标/贴图索引右侧标注 Godot 源行号。逻辑画布 1024x768, UiScaler 缩放居中。
import { DXImageControl, DXAnimatedControl, DXLabel, DXButton, DXTextInput, DXCheckBox } from '../../dx.js';
import { skin } from '../../skin.js';
import { LoginResultText, LOGIN_SUCCESS, NewAccountResultText, NEWACCOUNT_SUCCESS, NEWACCOUNT_ALREADY } from '../../net.js';

export class LoginScene {
  constructor(conn, onEnterSelect) {
    this.conn = conn;
    this.onEnterSelect = onEnterSelect; // (characters) => void
    this.root = document.createElement('div');
    this.root.style.cssText = 'position:absolute;inset:0;';
    this.statusText = '正在连接服务端...'; // Lang.LoginUi492Label
    this.characters = [];
    this.#build();
    this.#wire();
  }

  setStatus(text) { this.statusLabel.text = text; }

  #build() {
    // 背景 Interface1c[20] 1024x768 (LoginScene.cs:374-382)
    const bg = new DXImageControl({
      library: 'Interface1c', index: 20, fixedSize: true,
      location: [0, 0], size: [1024, 768], isControl: false,
    });
    this.root.appendChild(bg.el);

    // 4 组登录动画 (LoginScene.cs:385-388)
    const anim = (base, count, sec, blend, offset) => new DXAnimatedControl({
      library: 'Interface1c', baseIndex: base, frameCount: count,
      animationDelayMs: sec * 1000, loop: true, animated: true,
      blend, useOffSet: offset, isControl: false,
    });
    bg.addControl(anim(2200, 100, 10, true, true));   // L385
    bg.addControl(anim(2400, 30, 5, true, true));     // L386
    bg.addControl(anim(2300, 30, 10, true, false));   // L387 (blend=true per L387 args (true,false,true))
    bg.addControl(anim(2500, 30, 8, true, true));     // L388

    // Logo 底 + Logo (LoginScene.cs:390-408)
    const logoBg = new DXImageControl({
      library: 'Interface1c', index: 23,
      location: [Math.trunc((1024 - 564) / 2), 25],   // L394
      isControl: false,
    });
    bg.addControl(logoBg);
    const logo = new DXImageControl({
      library: 'Interface1c', index: 22, fixedSize: true,
      size: [564, 300], location: [-35, -35], blend: true, // L398-407
      isControl: false,
    });
    logoBg.addControl(logo);

    // 主登录框 Interface[151] (LoginScene.cs:410-421)
    const dialog = new DXImageControl({ library: 'Interface', index: 151 });
    this.dialog = dialog;
    bg.addControl(dialog);
    // 原版底框位置: 居中偏下 (LoginScene.cs:419-421)
    skin.frame('Interface', 151).then(f => {
      const w = f && f.w > 0 ? f.w : 780, h = f && f.h > 0 ? f.h : 115;
      dialog.location = [Math.trunc((1024 - w) / 2), 768 - h - 20];
    });

    // 输入框 (LoginScene.cs:433-452)
    this.emailInput = new DXTextInput({ location: [70, 65], size: [170, 14], fontSize: 8 });
    this.passwordInput = new DXTextInput({ location: [357, 65], size: [170, 14], fontSize: 8, secret: true });
    dialog.addControl(this.emailInput);
    dialog.addControl(this.passwordInput);

    // 按钮: 先按 Interface[16] 高度 (LoginScene.cs:466-467, 兜底 21)
    skin.frame('Interface', 16).then(f => { if (f) this.#buildButtons(f.h); });
  }

  async #buildButtons(btnH) {
    const d = this.dialog;
    const gold = [255, 224, 140, 255];   // (1f,.88f,.55f)
    const orange = [255, 191, 64, 255];  // (1f,.75f,.25f)

    // 登录/退出 (LoginScene.cs:470-471)
    this.btnLogin = new DXButton({
      text: '登录', fontSize: 10, textColour: gold, library: 'Interface', index: -1,
      location: [550, 60], size: [100, btnH], enabled: false, onClick: () => this.#onLogin(),
    });
    const btnExit = new DXButton({
      text: '退出', fontSize: 10, textColour: gold, library: 'Interface', index: -1,
      location: [660, 60], size: [100, btnH], onClick: () => { this.conn.close(); location.reload(); },
    });
    const btnRanking = new DXButton({
      text: '排行榜', fontSize: 9, textColour: gold, library: 'Interface', index: 153,
      location: [20, 0], size: [68, 32], onClick: () => this.#toggleLoginRanking(),
    });
    const btnOptions = new DXButton({
      text: '选项', fontSize: 9, textColour: gold, library: 'Interface', index: 153,
      location: [93, 0], size: [68, 32], onClick: () => this.#toggleLoginOptions(),
    });
    this.btnRegister = new DXButton({
      text: '注册新账号', fontSize: 10, textColour: gold, library: 'Interface', index: 152,
      location: [485, 0], size: [136, 32], enabled: false, onClick: () => this.#onRegister(),
    });
    const btnChange = new DXButton({
      text: '修改密码', fontSize: 10, textColour: gold, library: 'Interface', index: 152,
      location: [625, 0], size: [136, 32], onClick: () => this.#promptChangePassword(),
    });
    d.addControl(this.btnLogin);
    d.addControl(btnExit);
    d.addControl(btnRanking);
    d.addControl(btnOptions);
    d.addControl(this.btnRegister);
    d.addControl(btnChange);

    // 标题提示 (LoginScene.cs:424-431)
    d.addControl(new DXLabel({
      text: '请输入邮箱和密码', // Lang.LoginPasswordLabel14
      textColour: [214, 190, 148, 255], location: [280, 38], size: [220, 18], isControl: false,
    }));

    // 忘记密码 (LoginScene.cs:498-502)
    const forgot = new DXLabel({
      text: '忘记密码', fontSize: 9, textColour: orange,
      location: [640, 38], size: [100, 16], isControl: true,
    });
    forgot.el.style.cursor = 'pointer';
    forgot.el.addEventListener('mouseenter', () => forgot.el.style.color = '#fff');
    forgot.el.addEventListener('mouseleave', () => forgot.el.style.color = 'rgb(255,191,64)');
    forgot.el.addEventListener('click', () => this.#promptPasswordReset());
    d.addControl(forgot);

    // 记住账号 (LoginScene.cs:505-509)
    this.chkRemember = new DXCheckBox({
      location: [490, 38], label: '记住账号', fontSize: 9, textColour: orange,
      checked: localStorage.getItem('webport_remember') === '1',
    });
    d.addControl(this.chkRemember);

    // 激活账号 (LoginScene.cs:512-514)
    const btnActivation = new DXButton({
      text: '激活账号', fontSize: 9, textColour: orange, library: 'Interface', index: -1,
      location: [20, 36], size: [72, 20], onClick: () => this.#promptActivation(),
    });
    d.addControl(btnActivation);

    // 状态 Label (LoginScene.cs:516-518)
    this.statusLabel = new DXLabel({
      text: this.statusText, fontSize: 9, textColour: [255, 217, 115, 255],
      drawOutline: true, location: [20, 84], size: [500, 36], isControl: false,
    });
    d.addControl(this.statusLabel);

    // 记住的账号回填 (LoginScene.cs:438/446)
    if (this.chkRemember.checked) {
      this.emailInput.text = localStorage.getItem('webport_email') ?? '';
      this.passwordInput.text = localStorage.getItem('webport_password') ?? '';
    }
  }

  #onNewAccount(result) { // ShowNewAccountResult (LoginScene.cs:223-231)
    if (result === NEWACCOUNT_SUCCESS || result === NEWACCOUNT_ALREADY) {
      this.setStatus(`注册结果: ${NewAccountResultText[result]}，请登录`);
    } else {
      this.setStatus(`注册失败: ${NewAccountResultText[result] ?? result}`);
    }
    if (this.btnRegister) this.btnRegister.enabled = true;
  }


  #wire() {
    this.conn.addEventListener('versionOK', () => {
      this.setStatus('已连接服务端');   // Lang.LoginLoginLabel {version}
      if (this.btnLogin) this.btnLogin.enabled = true;
      if (this.btnRegister) this.btnRegister.enabled = true;
    });
    this.conn.addEventListener('loginResult', (e) => this.#onLoginResult(e.detail));
    this.conn.addEventListener('newAccountResult', (e) => this.#onNewAccount(e.detail));
    // 账号操作结果 → 状态行 (LoginScene.cs:211-221 OnChangePasswordResult 等对照)
    this.conn.addEventListener('changePasswordResult', (e) => this.setStatus(`修改密码结果: ${e.detail?.result ?? '?'}${e.detail?.message ? ` (${e.detail.message})` : ''}`));
    this.conn.addEventListener('requestPasswordResetResult', (e) => this.setStatus(`密码重置申请: ${e.detail?.result ?? '?'}${e.detail?.message ? ` (${e.detail.message})` : ''}`));
    this.conn.addEventListener('resetPasswordResult', (e) => this.setStatus(`重置密码结果: ${e.detail?.result ?? '?'}`));
    this.conn.addEventListener('activationResult', (e) => this.setStatus(`激活结果: ${e.detail?.result ?? '?'}`));
    this.conn.addEventListener('requestActivationKeyResult', (e) => this.setStatus(`激活键请求结果: ${e.detail?.result ?? '?'}`));
    this.conn.addEventListener('disconnected', () => {
      this.setStatus('与服务器的连接已断开'); // Lang.LoginUi459Label
      if (this.btnLogin) this.btnLogin.enabled = false;
      if (this.btnRegister) this.btnRegister.enabled = false;
    });
    this.conn.addEventListener('serverDisconnect', (e) => {
      this.setStatus(`服务器断开: ${e.detail}`);
    });
    // Enter 登录
    this.passwordInput.input.addEventListener('keydown', (ev) => {
      if (ev.key === 'Enter' && this.btnLogin?.enabled) this.#onLogin();

    });
  }

  // ---- 排行榜 (LoginScene.cs:281-286 ToggleLoginRanking) ----
  #toggleLoginRanking() {
    if (!this._rankWin) {
      const win = document.createElement('div');
      win.style.cssText =
        'position:absolute;left:312px;top:170px;width:400px;height:260px;z-index:60;' +
        'background:rgba(20,16,12,.94);border:2px solid #6b5a3e;box-shadow:0 4px 16px #000;';
      const title = document.createElement('div');
      title.textContent = '排行榜 (仅在线)';
      title.style.cssText = 'padding:6px 10px;font:bold 13px \'Noto Sans CJK SC\',sans-serif;color:#ffd573;border-bottom:1px solid #6b5a3e;';
      const list = document.createElement('div');
      list.style.cssText = 'position:absolute;top:32px;left:0;right:0;bottom:0;overflow-y:auto;';
      list.textContent = '（等待服务器响应...）';
      const close = document.createElement('div');
      close.textContent = '×';
      close.style.cssText = 'position:absolute;top:2px;right:8px;cursor:pointer;color:#c9a;font:16px sans-serif;';
      close.onclick = () => { win.style.display = 'none'; };
      win.append(title, list, close);
      this.root.appendChild(win);
      this._rankWin = win;
      this._rankList = list;
      const onRanks = (e) => {
        const ranks = e.detail?.ranks ?? [];
        list.replaceChildren();
        if (!ranks.length) { list.textContent = '（暂无上榜角色）'; return; }
        for (const r0 of ranks) {
          const d = document.createElement('div');
          d.textContent = `#${r0.rank} ${r0.name} Lv.${r0.level}`;
          d.style.cssText = 'padding:2px 10px;font:12px \'Noto Sans CJK SC\',sans-serif;color:#eee;text-shadow:1px 1px 0 #000;';
          list.appendChild(d);
        }
      };
      this.conn.addEventListener('rankings', onRanks);
    }
    const show = this._rankWin.style.display === 'none';
    this._rankWin.style.display = show ? '' : 'none';
    if (show) this.conn.sendRankRequest(0, true, 0);   // ServerConnection.cs:1077 RequiredClass.None
  }

  // ---- 选项 (LoginScene.cs:522 ConfigDialog) — 网页设置: UI 缩放/音量占位 ----
  #toggleLoginOptions() {
    if (!this._optWin) {
      const win = document.createElement('div');
      win.style.cssText =
        'position:absolute;left:322px;top:169px;width:380px;height:190px;z-index:60;' +
        'background:rgba(20,16,12,.94);border:2px solid #6b5a3e;box-shadow:0 4px 16px #000;';
      win.innerHTML =
        '<div style="padding:6px 10px;font:bold 13px \'Noto Sans CJK SC\',sans-serif;color:#ffd573;border-bottom:1px solid #6b5a3e">选项</div>' +
        '<div style="padding:10px;font:12px \'Noto Sans CJK SC\',sans-serif;color:#eee">' +
        '  <label>UI 缩放 <select id="wp-ui-scale"><option value="1">100%</option><option value="1.25">125%</option><option value="1.5">150%</option></select></label>' +
        '</div>';
      const close = document.createElement('div');
      close.textContent = '×';
      close.style.cssText = 'position:absolute;top:2px;right:8px;cursor:pointer;color:#c9a;font:16px sans-serif;';
      close.onclick = () => { win.style.display = 'none'; };
      win.appendChild(close);
      const sel = () => win.querySelector('#wp-ui-scale');
      win.addEventListener('change', () => {
        const v = parseFloat(sel().value) || 1;
        localStorage.setItem('webport_ui_scale', String(v));
        document.documentElement.style.setProperty('--webport-scale', String(v));
        window.dispatchEvent(new CustomEvent('webport-ui-scale', { detail: v }));
      });
      sel().value = localStorage.getItem('webport_ui_scale') ?? '1';
      this.root.appendChild(win);
      this._optWin = win;
    }
    this._optWin.style.display = this._optWin.style.display === 'none' ? '' : 'none';
  }

  // ---- 账号操作 (LoginScene.cs:51-55 AddAccountButton 系列) ----
  #promptChangePassword() {   // SendChangePassword(email, current, next)
    const email = prompt('修改密码 — 邮箱:', this.emailInput.text) ?? '';
    if (!email) return;
    const current = prompt('当前密码:') ?? '';
    const next = prompt('新密码:') ?? '';
    if (!current || !next) return;
    this.conn.sendChangePassword(email, current, next);
    this.setStatus('正在提交修改密码...');
  }
  #promptPasswordReset() {    // SendRequestPasswordReset(email)
    const email = prompt('忘记密码 — 输入注册邮箱申请重置:', this.emailInput.text) ?? '';
    if (!email) return;
    this.conn.sendRequestPasswordReset(email);
    this.setStatus('已申请密码重置 (若邮箱有效将下发重置键)...');
  }
  #promptActivation() {       // SendActivation(key) / SendRequestActivationKey(email)
    const email = prompt('激活账号 — 邮箱 (留空则直接输入激活键):', this.emailInput.text) ?? '';
    if (!email) return;
    if (email.includes('@')) { this.conn.sendRequestActivationKey(email); this.setStatus('已请求激活键...'); }
    else { this.conn.sendActivation(email); this.setStatus('正在激活...'); }
  }

  #onLogin() { // OnLoginPressed (LoginScene.cs:244-264) — 网页测试台: 忽略输入框, 固定测试账号直进
    this.btnLogin.enabled = false;
    this.setStatus('正在登录...');     // Lang.LoginLoginLabel4
    this.conn.sendLogin('test@test.com', 'test123');
  }

  #onRegister() { // OnRegisterPressed (LoginScene.cs:266-271)
    this.btnRegister.enabled = false;
    this.setStatus('正在注册账号...');  // Lang.LoginRegisterLabel2
    this.conn.sendNewAccount(this.emailInput.text, this.passwordInput.text);
  }
  #onLoginResult(p) { // ShowLoginResult (LoginScene.cs:175-193)
    if (p.result === LOGIN_SUCCESS) {
      this.setStatus(`登录成功, 角色数 ${p.characters?.length ?? 0}`);
      this.onEnterSelect(p.characters ?? []);
    } else {
      this.setStatus(`登录失败: ${LoginResultText[p.result] ?? p.result}${p.message ? ` (${p.message})` : ''}`);
      if (this.btnLogin) this.btnLogin.enabled = true;
    }
  }
}

