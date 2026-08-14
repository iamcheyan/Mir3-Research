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
      location: [20, 0], size: [68, 32], onClick: () => this.setStatus('排行榜: 网页版暂未实现'),
    });
    const btnOptions = new DXButton({
      text: '选项', fontSize: 9, textColour: gold, library: 'Interface', index: 153,
      location: [93, 0], size: [68, 32], onClick: () => this.setStatus('选项: 网页版暂未实现'),
    });
    this.btnRegister = new DXButton({
      text: '注册新账号', fontSize: 10, textColour: gold, library: 'Interface', index: 152,
      location: [485, 0], size: [136, 32], enabled: false, onClick: () => this.#onRegister(),
    });
    const btnChange = new DXButton({
      text: '修改密码', fontSize: 10, textColour: gold, library: 'Interface', index: 152,
      location: [625, 0], size: [136, 32], onClick: () => this.setStatus('修改密码: 网页版暂未实现'),
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
    forgot.el.addEventListener('click', () => this.setStatus('忘记密码: 网页版暂未实现'));
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
      location: [20, 36], size: [72, 20], onClick: () => this.setStatus('激活账号: 网页版暂未实现'),
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

  #onLogin() { // OnLoginPressed (LoginScene.cs:244-264)
    this.btnLogin.enabled = false;
    this.setStatus('正在登录...');     // Lang.LoginLoginLabel4
    const email = this.emailInput.text;
    const password = this.passwordInput.text;
    if (this.chkRemember?.checked) {
      localStorage.setItem('webport_remember', '1');
      localStorage.setItem('webport_email', email);
      localStorage.setItem('webport_password', password);
    } else {
      localStorage.removeItem('webport_remember');
      localStorage.removeItem('webport_email');
      localStorage.removeItem('webport_password');
    }
    this.conn.sendLogin(email, password);
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

