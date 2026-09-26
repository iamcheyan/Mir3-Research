unit IntroScn;

interface

uses
  Windows, Messages, SysUtils, Classes, Graphics, StdCtrls, Controls, Forms,
  Dialogs, extctrls, HGETextures, HGE, FState, Grobal2, cliUtil, clFunc,
  SoundUtil, WIL, DWinCtl, HGESounds, HUtil32, EdCode;

const
  SELECTEDFRAME = 16;
  FREEZEFRAME = 13;
  EFFECTFRAME = 14;
  NPKSECOPT_CRYPTRC4 = 2;
  LOGINBAGIMGINDEX = 22;

type
  TLoginState = (lsLogin, lsCloseAll);
  TSceneType = (stIntro, stLogin, stSelectCountry, stSelectChr, stNewChr, stLoading, stLoginNotice, stPlayGame);

  TCharsprIinfo = record
    wFstFrm: Word;						// µ¿ÀÛÀÇ ½ÃÀÛ ÇÁ·¹ÀÓ.
    wEndFrm: Word;						// µ¿ÀÛÀÇ ¸¶Áö¸· ÇÁ·¹ÀÓ.
    wDelay: Word;							// µ¿ÀÛÀÇ Áö¿¬½Ã°£.
  end;
  PTCharsprIinfo = ^TCharsprIinfo;

  TCurrfrmInfo = record
    nPosX: integer;							// ÁÂÇ¥.
    nPosY: integer;
    wCurrMtn: Word;						// ÇöÀç µ¿ÀÛ.
    wCurrFrm: Word;						// ÇöÀç ÇÁ·¹ÀÓ.
    wCurrDelay: LongWord;						// ÇöÀçÀÇ Áö¿¬½Ã°£.
    rcChrRgn: TRect;
    bBlend: byte;
    pstCurrSprInfo: TCharsprIinfo;					// ÇöÀç Animation¿¡ ´ëÇÑ Á¤º¸.
  end;
  PTCurrfrmInfo = ^TCurrfrmInfo;

  TSelChar = record
    bSetted: Boolean;
    UserChr: TUserCharacterInfo;
    Selected: Boolean;
    FreezeState: Boolean; //TRUE:¾óÀº»óÅÂ FALSE:³ìÀº»óÅÂ
    Unfreezing: Boolean; //³ì°í ÀÖ´Â »óÅÂÀÎ°¡?
    Freezing: Boolean;  //¾ó°í ÀÖ´Â »óÅÂ?
    AniIndex: integer;  //³ì´Â(¾î´Â) ¾Ö´Ï¸ÞÀÌ¼Ç
    DarkLevel: integer;
    EffIndex: integer;  //È¿°ú ¾Ö´Ï¸ÞÀÌ¼Ç
    starttime: longword;
    moretime: longword;
    startefftime: longword;
//      ChrSelectValue: byte;
//      boHitEffect: Boolean;
//      CurrentImageNumber: integer;
    stCurrFrmInfo: TCurrfrmInfo;
  end;

  PTSelChar = ^TSelChar;

  TScene = class
  private
  public
    SceneType: TSceneType;
    constructor Create(scenetype: TSceneType);
    procedure Initialize; dynamic;
    procedure Finalize; dynamic;
    procedure OpenScene; dynamic;
    procedure CloseScene; dynamic;
    procedure OpeningScene; dynamic;
    procedure KeyPress(var Key: Char); dynamic;
    procedure KeyDown(var Key: Word; Shift: TShiftState); dynamic;
    procedure MouseMove(Shift: TShiftState; X, Y: Integer); dynamic;
    procedure MouseDown(Button: TMouseButton; Shift: TShiftState; X, Y: Integer); dynamic;
    procedure PlayScene(MSurface: TDirectDrawSurface); dynamic;
  end;

  TIntroScene = class(TScene)
  private
  public
    constructor Create;
    destructor Destroy; override;
    procedure OpenScene; override;
    procedure CloseScene; override;
    procedure PlayScene(MSurface: TDirectDrawSurface); override;
  end;

  TLoginScene = class(TScene)
    m_xNoticeList: TStringList;
  private
    EdId: TEdit;
    EdPasswd: TEdit;
    m_nBackIdx: integer;

    nNoticeLoopTime: longword;
    nScrlY: integer;
    nSum: integer;
    m_rcNotice: TRect;
    CurFrame, MaxFrame: integer;
    StartTime: longword;  //ÇÑ ÇÁ·¡ÀÓ´ç ½Ã°£
    NowOpening: Boolean;
    NoticeView: Boolean;
    BoOpenFirst: Boolean;
    NewIdRetryUE: TUserEntryInfo;
    NewIdRetryAdd: TUserEntryAddInfo;

    procedure EdLoginIdKeyPress(Sender: TObject; var Key: Char);
    procedure EdLoginPasswdKeyPress(Sender: TObject; var Key: Char);
      // 20003-09-05 Encrypt LoginId,PasswordmCharName
    function GetLoginId: string;
    procedure SetLogId(id: string);
    function GetLoginPasswd: string;
    procedure SetLoginPasswd(pw: string);
  public
      //LoginId, LoginPasswd: string;
      //2003-09-05 Encrypt LoginID & Password
    EncLoginId, EncLoginPasswd: string;
    property LoginId: string read GetLoginId write SetLogId;
    property LoginPasswd: string read GetLoginPasswd write SetLoginPasswd;
    constructor Create;
    destructor Destroy; override;
    procedure OpenScene; override;
    procedure CloseScene; override;
    procedure PlayScene(MSurface: TDirectDrawSurface); override;
    procedure ChangeLoginState(state: TLoginState);
    procedure OkClick;
    procedure HideLoginBox;
    procedure OpenLoginDoor;
    procedure PassWdFail;
    procedure LoadNoticeText;
  end;

  TSelectChrScene = class(TScene)
  private
    SoundTimer: TTimer;
    CreateChrMode: Boolean;
    m_stChrSprInfo: array[0..29] of TCharsprIinfo;
    procedure SoundOnTimer(Sender: TObject);
//    procedure MakeNewChar(index: integer);
    procedure EdChrnameKeyPress(Sender: TObject; var Key: Char);
    function GetJobName(job: integer): string;
  public
    m_stEffctWav: array[0..2] of string;
    m_stCreateWav: array[0..1, 0..2] of string;
    m_stSelectWav: array[0..1, 0..2] of string;
    EdChrName: TEdit;
    m_bChrProcState: Byte;
    m_nCreatedChr: Byte;
    m_nSelectedChr: Integer;
    NewIndex: integer;
    m_stSelectChrInfo: array[0..3] of TSelChar;
    m_stCreateChrInfo: array[0..1] of TSelChar;
    m_bBGMPlay: Boolean;
    m_bBGMPlayTime: integer;
    m_nDividedExplain: integer;
    m_pszChrExplain: TStringList;
    constructor Create;
    destructor Destroy; override;
    procedure OpenScene; override;
    procedure CloseScene; override;
    procedure PlayScene(MSurface: TDirectDrawSurface); override;
    procedure SelChrSelect1Click;
    procedure SelChrSelect2Click;
    procedure SelChrSelect3Click;
    procedure SelChrStartClick;
    procedure SelChrNewChrClick;
    procedure SelChrEraseChrClick;
    procedure SelChrCreditsClick;
    procedure SelChrExitClick;
    procedure SelChrNewClose;
    procedure SelChrNewJob(job: integer);
    procedure SelChrNewSex(sex: integer);
    procedure SelChrNewPrevHair;
    procedure SelChrNewNextHair;
    procedure DrawNewChr(MSurface: TDirectDrawSurface);
    procedure SelChrNewOk;
    procedure ClearChrs;
    procedure AddChr(uname: string; job, hair, level, sex: integer);
    procedure SelectChr(index: integer);
    procedure SetCharSprInfo(var pstChrSpr: TCharsprIinfo; wFstFrm, wEndFrm, wDelay: Word);
    procedure SetChrSelSprite;
    function GetCharSprInfo(bGender, bJob, bMtn: byte): TCharsprIinfo;
    procedure SetMotion(nNum: Integer; bMtn: byte);
    procedure SetCharRect(nNum: Integer; bMtn: byte);
    function GetChrCreatePos(bGender, bJob: byte): TPoint;
    procedure SetChrInfo(var pstChrInfo: TSelChar; bGender, bJob, bLevel: byte; pszName: string = '');
    procedure MakeNewChar(index: integer);
    function SetCharExplain(bGender, bJob: Byte):Boolean;
  end;

  TLoading = class(TScene)
  private
  public
    constructor Create;
    destructor Destroy; override;
    procedure OpenScene; override;
    procedure CloseScene; override;
  end;

  TLoginNotice = class(TScene)
  private
  public
    constructor Create;
    destructor Destroy; override;
    procedure OpenScene; override;
    procedure CloseScene; override;
  end;

implementation

uses
  ClMain, uWilFile, HGEFont;

constructor TScene.Create(scenetype: TSceneType);
begin
  scenetype := scenetype;
end;

procedure TScene.Initialize;
begin
end;

procedure TScene.Finalize;
begin
end;

procedure TScene.OpenScene;
begin
end;

procedure TScene.CloseScene;
begin
end;

procedure TScene.OpeningScene;
begin
end;

procedure TScene.KeyPress(var Key: Char);
begin
end;

procedure TScene.KeyDown(var Key: Word; Shift: TShiftState);
begin
end;

procedure TScene.MouseMove(Shift: TShiftState; X, Y: Integer);
begin
end;

procedure TScene.MouseDown(Button: TMouseButton; Shift: TShiftState; X, Y: Integer);
begin
end;

procedure TScene.PlayScene(MSurface: TDirectDrawSurface);
begin
end;

{------------------- TIntroScene ----------------------}
constructor TIntroScene.Create;
begin
  inherited Create(stIntro);
end;

destructor TIntroScene.Destroy;
begin
  inherited Destroy;
end;

procedure TIntroScene.OpenScene;
begin
end;

procedure TIntroScene.CloseScene;
begin
end;

procedure TIntroScene.PlayScene(MSurface: TDirectDrawSurface);
begin
end;

{--------------------- Login ----------------------}
// 20003-09-05 Encrypt LoginId,PasswordmCharName
function TLoginScene.GetLoginId: string;
begin
  Result := DecodeString(EncLoginId);
end;

procedure TLoginScene.SetLogId(id: string);
begin
  EncLoginId := EncodeString(id);
end;

function TLoginScene.GetLoginPasswd: string;
begin
  Result := DecodeString(EncLoginPasswd);
end;

procedure TLoginScene.SetLoginPasswd(pw: string);
begin
  EncLoginPasswd := EncodeString(pw);
end;

constructor TLoginScene.Create;
var
  nx, ny: integer;
begin
  inherited Create(stLogin);

  EdId := TEdit.Create(FrmMain.Owner);
  with EdId do begin
    Parent := FrmMain;
    Color := clBlack;
    Font.Color := clWhite;
    Font.Size := 10;
    MaxLength := 10;
    BorderStyle := bsNone;
    OnKeyPress := EdLoginIdKeyPress;
    Visible := FALSE;
    Tag := 10;
  end;

  EdPasswd := TEdit.Create(FrmMain.Owner);
  with EdPasswd do begin
    Parent := FrmMain;
    Color := clBlack;
    Font.Size := 10;
    MaxLength := 10;
    Font.Color := clWhite;
    BorderStyle := bsNone;
    PasswordChar := '*';
    OnKeyPress := EdLoginPasswdKeyPress;
    Visible := FALSE;
    Tag := 10;
  end;
end;

destructor TLoginScene.Destroy;
begin
  inherited Destroy;
end;

procedure TLoginScene.OpenScene;
var
  i: integer;
  str: string;
  bzRegBool, szOptionBool: Bool;
  Result: LongInt;
begin
  m_nBackIdx := 20 + Random(14);
  m_nBackIdx := 0;
  CurFrame := 0;
  MaxFrame := 19;
  LoginId := '';
  LoginPasswd := '';

  LoadNoticeText;

  with EdId do begin
    Left := 129;
    Top := 444;
    Height := 16;
    Width := 98;
    Visible := FALSE;
  end;
  with EdPasswd do begin
    Left := 327;
    Top := 444;
    Height := 16;
    Width := 98;
    Visible := FALSE;
  end;

  nNoticeLoopTime := GetTickCount;

  BoOpenFirst := TRUE;
  FrmDlg.DLogin.Visible := TRUE;
  NowOpening := FALSE;
  NoticeView := TRUE;
  PlayBGMEx(bmg_intro);
end;

procedure TLoginScene.CloseScene;
var
  bzClose: Bool;
begin
  EdId.Visible := FALSE;
  EdPasswd.Visible := FALSE;
  FrmDlg.DLogin.Visible := FALSE;
  SilenceSound;
  ClearBGM();
end;

procedure TLoginScene.EdLoginIdKeyPress(Sender: TObject; var Key: Char);
begin
  if Key = #13 then begin
    Key := #0;
    LoginId := LowerCase(EdId.Text);
    if LoginId <> '' then begin
      EdPasswd.SetFocus;
    end;
  end;
end;

procedure TLoginScene.EdLoginPasswdKeyPress(Sender: TObject; var Key: Char);
var
  i: Integer;
  TempStr: string;
begin
  if Key = #13 then begin
    Key := #0;
    LoginId := LowerCase(EdId.Text);
    LoginPasswd := EdPasswd.Text;

    if (LoginId <> '') and (LoginPasswd <> '') then begin
         //°èÁ¤À¸·Î ·Î±×ÀÎ ÇÑ´Ù.
      FrmMain.SendLogin(LoginId, LoginPasswd);
      EdId.Text := '';
      EdPasswd.Text := '';
      EdId.Visible := FALSE;
      EdPasswd.Visible := FALSE;
    end
    else if (EdId.Visible) and (EdId.Text = '') then
      EdId.SetFocus;
  end;
end;

procedure TLoginScene.LoadNoticeText;
var
  nW, nLineCnt: Integer;
  temp: TStringList;
begin
  SetRect(m_rcNotice, 23, 120, 247, 353);
  nW := m_rcNotice.right - m_rcNotice.Left - 10;
  if FileExists('Notice.ntc') then begin
    try
      temp:= Decrypt('Notice.ntc');
      m_xNoticeList := TStringList.Create;
      StringDivide(nW, nLineCnt, temp, m_xNoticeList);
      nScrlY := 0;
      nSum := -1500;
      nNoticeLoopTime := GetTickCount;
    finally
      FreeAndNil(temp);
    end;
  end;
end;

procedure TLoginScene.PassWdFail;
begin
  EdId.Visible := TRUE;
  EdPasswd.Visible := TRUE;
  EdId.SetFocus;
end;

procedure TLoginScene.HideLoginBox;
begin
  EdId.Visible := FALSE;
  EdPasswd.Visible := FALSE;
  FrmDlg.DLogin.Visible := FALSE;
  NoticeView := FALSE;
  ChangeLoginState(lsCloseAll);
end;

procedure TLoginScene.OpenLoginDoor;
begin
  NowOpening := TRUE;
  StartTime := GetTickCount;
  HideLoginBox;
//   PlaySound (s_rock_door_open);
end;

procedure TLoginScene.PlayScene(MSurface: TDirectDrawSurface);
var
  d: TDirectDrawSurface;
  rc: TRect;
  i, nCnt: integer;
  nRed, nGreen, nBlue: integer;
  nRedLine, nGreenLine, nBlueLine: integer;
  nW, nH: integer;
  BackColor, LineColor: LongWord;
begin
   //if not ServerConnected then exit;
  if BoOpenFirst then begin
    BoOpenFirst := FALSE;
    EdId.Visible := TRUE;
    EdPasswd.Visible := TRUE;
{$IFDEF DEBUG}
    EdId.Text := 'admin';
    EdPasswd.Text := 'admin';
    EdPasswd.SetFocus;
{$ELSE}
    EdId.SetFocus;
{$ENDIF}
  end;
  d := g_WInterface1c.Images[m_nBackIdx];
  if d <> nil then begin
    MSurface.Draw(0, (480 - d.Height) div 2, d.ClientRect, d, FALSE);
  end;

  if FrmDlg.DSelServerDlg.Visible then begin
    g_DXCanvas.TextOut(40, 445, clYellow, CMsg.GetMsg(129){'Á¼ºÃ - ´Ë·þÎñÆ÷×´Ì¬Á¼ºÃ'});
    g_DXCanvas.TextOut(250, 445, clYellow, CMsg.GetMsg(130){'·±Ã¦ - ´Ë·þÎñÆ÷ÈËÊý½Ï¶à'});
    g_DXCanvas.TextOut(460, 445, clYellow, CMsg.GetMsg(131){'ÂúÔ± - ´Ë·þÎñÆ÷ÈËÔ±±¬Âú'});
  end;
  
  if (m_xNoticeList.Count > 0) and NoticeView then begin
    SetRect(rc, m_rcNotice.left-5, m_rcNotice.top-5, m_rcNotice.right+10, m_rcNotice.bottom + 5);
    nW := rc.right - rc.Left;
    nH := rc.bottom - rc.top;

    case m_nBackIdx of
      20, 27:
        begin
          nRed := 57;
          nGreen := 77;
          nBlue := 51;
          nRedLine := 43;
          nGreenLine := 55;
          nBlueLine := 38;
        end;
      21, 22, 23, 30:
        begin
          nRed := 75;
          nGreen := 50;
          nBlue := 0;
          nRedLine := 100;
          nGreenLine := 75;
          nBlueLine := 50;
        end;
      0, 24, 25, 26:
        begin
          nRed := 25;
          nGreen := 78;
          nBlue := 104;
          nRedLine := 40;
          nGreenLine := 95;
          nBlueLine := 120;
        end;
      28:
        begin
          nRed := 40;
          nGreen := 30;
          nBlue := 98;
          nRedLine := 27;
          nGreenLine := 20;
          nBlueLine := 65;
        end;
      29:
        begin
          nRed := 54;
          nGreen := 90;
          nBlue := 143;
          nRedLine := 37;
          nGreenLine := 62;
          nBlueLine := 99;
        end;
      31, 32, 33, 34:
        begin
          nRed := 10;
          nGreen := 10;
          nBlue := 10;
          nRedLine := 5;
          nGreenLine := 5;
          nBlueLine := 5;
        end;
    end;

    BackColor := (255 shl 24) + (nBlue shl 16) + (nGreen shl 8) + nRed;
    LineColor := (255 shl 24) + (nBlueLine shl 16) + (nGreenLine shl 8) + nRedLine;

    g_DXCanvas.Draw2DRect(rc,BackColor, 100);
    g_DXCanvas.Draw2DRectLine(rc, LineColor);
//    g_DXCanvas.TextOut(10, 10, clWhite, InttoStr(GetTickCount - nNoticeLoopTime));

		if (GetTickCount - nNoticeLoopTime) > 100 then	begin
      nSum := nNoticeLoopTime;
      nNoticeLoopTime := GetTickCount;
    end;

		if nSum > 100 then begin
			nSum := 0;
			if (m_xNoticeList.Count * 14) > nH then begin
        Dec(nScrlY);
				if abs(nScrlY) >= (m_xNoticeList.Count-1) * 14 then begin
					nScrlY := nH - 14;
        end;
      end;
    end;

    with g_DXCanvas do begin
      for nCnt := 0 to m_xNoticeList.Count - 1 do begin
				if (m_rcNotice.Top+(nCnt*14)+nScrlY >= m_rcNotice.Top) and
           (m_rcNotice.Top+((nCnt+1)*14)+nScrlY < m_rcNotice.bottom) then
				begin
          TextOut(m_rcNotice.Left, m_rcNotice.Top+(nCnt*14)+nScrlY, clWhite, m_xNoticeList.Strings[nCnt]);
				end;
      end;
    end;
  end;

  if NowOpening then begin
{      if GetTickCount - StartTime > 120 then begin
         StartTime := GetTickCount;
         Inc (CurFrame);
      end;
      if CurFrame >= MaxFrame-1 then begin
         CurFrame := MaxFrame-1;
         if not DoFadeOut and not DoFadeIn then begin
            DoFadeOut := TRUE;
            DoFadeIn := TRUE;
//            FadeIndex := 29;
            FadeIndex := 25;
         end;
      end;
      d := g_WChrSel.Images[CurFrame];
      if d <> nil then
         MSurface.Draw (0, 0, d.ClientRect, d, TRUE);  }
//         MSurface.Draw (152, 96, d.ClientRect, d, TRUE);

    if not DoFadeOut and not DoFadeIn then begin
      DoFadeOut := TRUE;
      DoFadeIn := TRUE;
      FadeIndex := 0;
    end;

    if DoFadeOut then begin
      if FadeIndex >= 255 then begin
//            FrmMain.WProgUse.ClearCache;
//            FrmMain.WChrSel.ClearCache;
        Sleep(500);
        DScreen.ChangeScene(stSelectChr); //¼­¹ö¿¡¼­ Ä³¸¯ÅÍ Á¤º¸°¡ ¿À¸é ¼±ÅÃÃ¢À¸·Î ³Ñ¾î°£´Ù.
      end;
    end;
  end;
end;

procedure TLoginScene.ChangeLoginState(state: TLoginState);
var
  i, focus: integer;
  c: TControl;
begin
  focus := -1;
  case state of
    lsLogin: focus := 10;
    lsCloseAll: focus := -1;
  end;
  with FrmMain do begin  //login
    for i := 0 to ControlCount - 1 do begin
      c := Controls[i];
      if c is TEdit then begin
        if c.Tag in [10..12] then begin
          if c.Tag = focus then begin
            c.Visible := TRUE;
            TEdit(c).Text := '';
          end
          else begin
            c.Visible := FALSE;
            TEdit(c).Text := '';
          end;
        end;
      end;
    end;

    case state of
      lsLogin:
        begin
          FrmDlg.DLogin.Visible := TRUE;
          if EdId.Visible then
            EdId.SetFocus;
        end;
      lsCloseAll:
        begin
          FrmDlg.DLogin.Visible := FALSE;
        end;
    end;
  end;
end;

procedure TLoginScene.OkClick;
var
  key: char;
begin
  key := #13;
  EdLoginPasswdKeyPress(self, key);
end;


{-------------------- TSelectChrScene ------------------------}
constructor TSelectChrScene.Create;
begin
  CreateChrMode := FALSE;
  FillChar(m_stSelectChrInfo, sizeof(TSelChar) * 4, #0);
  FillChar(m_stCreateChrInfo, sizeof(TSelChar) * 2, #0);
  m_stSelectChrInfo[0].FreezeState := TRUE; //±âº»ÀÌ ¾ó¾î ÀÖ´Â »óÅÂ
  m_stSelectChrInfo[1].FreezeState := TRUE;
//   ChrArr[2].FreezeState := TRUE;
  NewIndex := 0;
  m_bChrProcState := _CHR_PROC_SELECT;
  m_nSelectedChr := _SELECTED_NONE;
  m_nCreatedChr := _SELECTED_FST_CHR;

  m_bBGMPlay := FALSE;
  m_bBGMPlayTime := 0;

  m_nDividedExplain := 0;
  m_pszChrExplain := TStringList.Create;

	m_stEffctWav[0] := 'Sound\CreateChr.wav';
	m_stEffctWav[1] := 'Sound\SelChr.wav';
	m_stEffctWav[2] := 'Sound\StartGame.wav';
	m_stCreateWav[0][0] := 'Sound\JMCre.wav';
	m_stCreateWav[0][1] := 'Sound\SMCre.wav';
	m_stCreateWav[0][2] := 'Sound\DMCre.wav';
	m_stCreateWav[1][0] := 'Sound\JWCre.wav';
	m_stCreateWav[1][1] := 'Sound\SWCre.wav';
	m_stCreateWav[1][2] := 'Sound\DWCre.wav';
	m_stSelectWav[0][0] := 'Sound\JMMSel.wav';
	m_stSelectWav[1][0] := 'Sound\JWMSel.wav';
	m_stSelectWav[0][1] := 'Sound\SMMSel.wav';
	m_stSelectWav[1][1] := 'Sound\SWMSel.wav';
	m_stSelectWav[0][2] := 'Sound\DMMSel.wav';
	m_stSelectWav[1][2] := 'Sound\DWMSel.wav';

  SetChrSelSprite();
  EdChrName := TEdit.Create(FrmMain.Owner);
  with EdChrName do begin
    Parent := FrmMain;
    Height := 12;
    Width := 73;
    BorderStyle := bsNone;
    Color := clBlack;
    Font.Color := clWhite;
    Font.Size := 9;
    ImeMode := LocalLanguage;
    MaxLength := 14;
    Visible := FALSE;
    OnKeyPress := EdChrnameKeyPress;
  end;
  SoundTimer := TTimer.Create(FrmMain.Owner);
  with SoundTimer do begin
    OnTimer := SoundOnTimer;
    Interval := 1;
    Enabled := FALSE;
  end;
  inherited Create(stSelectChr);
end;

destructor TSelectChrScene.Destroy;
begin
  inherited Destroy;
end;

procedure TSelectChrScene.OpenScene;
begin
  m_bBGMPlay := TRUE;
  FrmDlg.DSelectChr.Visible := TRUE;
  SoundTimer.Enabled := TRUE;
  SoundTimer.Interval := 1;
end;

procedure TSelectChrScene.CloseScene;
begin
  ClearBGM();
  SilenceSound;
  FrmDlg.DSelectChr.Visible := FALSE;
  SoundTimer.Enabled := FALSE;
end;

procedure TSelectChrScene.SoundOnTimer(Sender: TObject);
begin
//   PlayBGMEx (m_stEffctWav[1]);
  SoundTimer.Enabled := FALSE;
  FrmDlg.DialogSize := 0;
  FrmDlg.DMessageDlg(CMsg.GetMsg(200){'ÕýÏÂÔØ½ÇÉ«×ÊÁÏ£¬ÇëÉÔµÈºò¡£'}, []);
   //SoundTimer.Interval := 38 * 1000;
end;

procedure TSelectChrScene.SelChrSelect1Click;
begin
  if CreateChrMode then
    SelChrNewClose;
  if (not m_stSelectChrInfo[0].Selected) and (m_stSelectChrInfo[0].bSetted) then begin
    m_stSelectChrInfo[0].Selected := TRUE;
    m_stSelectChrInfo[1].Selected := FALSE;
//      ChrArr[1].freezing := TRUE;
//      ChrArr[1].AniIndex := 0;
//      ChrArr[1].StartTime := GetTickCount;
//      ChrArr[2].Selected := FALSE;
    m_stSelectChrInfo[0].Unfreezing := TRUE;
    m_stSelectChrInfo[0].AniIndex := 0;
    m_stSelectChrInfo[0].DarkLevel := 0;
    m_stSelectChrInfo[0].EffIndex := 0;
    m_stSelectChrInfo[0].StartTime := GetTickCount;
    m_stSelectChrInfo[0].MoreTime := GetTickCount;
    m_stSelectChrInfo[0].StartEffTime := GetTickCount;
    g_SelectChr := True;
//      PlaySound (s_meltstone);
  end;
end;

procedure TSelectChrScene.SelChrSelect2Click;
begin
  if (not m_stSelectChrInfo[1].Selected) and (m_stSelectChrInfo[1].bSetted) then begin
    m_stSelectChrInfo[1].Selected := TRUE;
    m_stSelectChrInfo[0].Selected := FALSE;
//      ChrArr[0].freezing := TRUE;
//      ChrArr[0].AniIndex := 0;
//      ChrArr[0].StartTime := GetTickCount;
//      ChrArr[2].Selected := FALSE;
    m_stSelectChrInfo[1].Unfreezing := TRUE;
    m_stSelectChrInfo[1].AniIndex := 0;
    m_stSelectChrInfo[1].DarkLevel := 0;
    m_stSelectChrInfo[1].EffIndex := 0;
    m_stSelectChrInfo[1].StartTime := GetTickCount;
    m_stSelectChrInfo[1].MoreTime := GetTickCount;
    m_stSelectChrInfo[1].StartEffTime := GetTickCount;
    g_SelectChr := True;
//      PlaySound (s_meltstone);
  end;
end;

procedure TSelectChrScene.SelChrSelect3Click;
begin
//   if (not ChrArr[2].Selected) and (ChrArr[2].Valid) then begin
//      ChrArr[2].Selected := TRUE;
//      ChrArr[0].Selected := FALSE;
//      ChrArr[1].Selected := FALSE;
//      ChrArr[2].Unfreezing := TRUE;
//      ChrArr[2].AniIndex := 0;
//      ChrArr[2].DarkLevel := 0;
//      ChrArr[2].EffIndex := 0;
//      ChrArr[2].StartTime := GetTickCount;
//      ChrArr[2].MoreTime := GetTickCount;
//      ChrArr[2].StartEffTime := GetTickCount;
//      PlaySound (s_meltstone);
//   end;
end;

procedure TSelectChrScene.SelChrStartClick;
var
   chrname: string;
begin
   chrname := '';
//   PlaySoundEx (SelectChrScene.m_stEffctWav[2]);
//   if m_stSelectChrInfo[0].bSetted and m_stSelectChrInfo[0].Selected then
//   begin
//    if m_stSelectChrInfo[0].UserChr.EncName = DecodeString( m_stSelectChrInfo[0].UserChr.EncEncName ) then
//        chrname := m_stSelectChrInfo[0].UserChr.EncName
//    else
//        Exit;
//   end;
//   if m_stSelectChrInfo[1].bSetted and m_stSelectChrInfo[1].Selected then
//   begin
//    if m_stSelectChrInfo[1].UserChr.EncName = DecodeString( m_stSelectChrInfo[1].UserChr.EncEncName ) then
//        chrname := m_stSelectChrInfo[1].UserChr.EncName
//    else
//        Exit;
//   end;


  if (m_nSelectedChr <> _SELECTED_NONE) and (m_nSelectedChr < _MAX_CHAR) then begin
    if m_stSelectChrInfo[m_nSelectedChr].UserChr.EncName = DecodeString(m_stSelectChrInfo[m_nSelectedChr].UserChr.EncEncName) then
      chrname := m_stSelectChrInfo[m_nSelectedChr].UserChr.EncName
    else
      Exit;
  end;

//   if ChrArr[2].Valid and ChrArr[2].Selected then
//   begin
//    if ChrArr[2].UserChr.EncName = DecodeString( ChrArr[2].UserChr.EncEncName ) then
//        chrname := ChrArr[2].UserChr.EncName
//    else
//        Exit;
//   end;

  if chrname <> '' then begin
    if not DoFadeOut and not DoFadeIn then begin
      DoFastFadeOut := TRUE;
      FadeIndex := 29;
    end;
    FrmMain.SendSelChr(chrname);
    LoadOption;
  end
  else begin
    FrmDlg.DialogSize := 1;
    FrmDlg.DMessageDlg(CMsg.GetMsg(219), [mbOk]);
  end;
end;

procedure TSelectChrScene.SelChrNewChrClick;
begin
  if not m_stSelectChrInfo[0].bSetted or not m_stSelectChrInfo[1].bSetted then begin
//    g_SoundManager.SndmngrStopMp3();
    SilenceSound;
    ClearBGM();
    m_bChrProcState := _CHR_PROC_CREATEIN;
    m_bBGMPlay	    := FALSE;

    PlayBGMEx(m_stEffctWav[0]);
    Video.Play('.\Data\CreateChr.dat', 0, 0, 640, 480);
//    Delay(1000);
//    WaitAndPass(1000);
    FrmMain.TimerBrowserUpdate.Enabled := True;
//    if not m_stSelectChrInfo[0].bSetted then
//      MakeNewChar(0)
//    else
//      MakeNewChar(1);
  end
  else
    FrmDlg.DMessageDlg('Äú¿ÉÒÔÎªÃ¿¸öµ¥¶ÀµÄÕÊºÅ½¨Á¢Á½¸ö½ÇÉ«¡£', [mbOk]);

//   if (not ChrArr[0].Valid) or (not ChrArr[1].Valid) or (not ChrArr[2].Valid) then begin
//      if not ChrArr[0].Valid then MakeNewChar (0)
//      else if not ChrArr[1].Valid then begin
//         ChrArr[0].Selected := False;
//         ChrArr[0].FreezeState := True;
//         MakeNewChar (1);
//      end
//      else begin
//         ChrArr[0].Selected := False;
//         ChrArr[0].FreezeState := True;
//         ChrArr[1].Selected := False;
//         ChrArr[1].FreezeState := True;
//         MakeNewChar (2);
//      end;
//   end else
//      FrmDlg.DMessageDlg ('ÇÑ °èÁ¤¿¡ 3°³ÀÇ Ä³¸¯ÅÍ±îÁö¸¸ ¸¸µé ¼ö ÀÖ½À´Ï´Ù.', [mbOk]);
end;

procedure TSelectChrScene.SelChrEraseChrClick;
var
  n: integer;
  charname: string;
begin
  n := 0;
  if m_stSelectChrInfo[0].bSetted and m_stSelectChrInfo[0].Selected then n := 0;
  if m_stSelectChrInfo[1].bSetted and m_stSelectChrInfo[1].Selected then n := 1;
//   if ChrArr[2].Valid and ChrArr[2].Selected then n := 2;
  charname := DecodeString ( m_stSelectChrInfo[m_nSelectedChr].UserChr.EncName );
  if (m_stSelectChrInfo[m_nSelectedChr].bSetted){ and (not m_stSelectChrInfo[m_nSelectedChr].FreezeState) }and (charname <> '') then begin
//    StringDivide(_CHR_EXPLAIN_WIDTH, m_nDividedExplain, PChar(CMsg.GetMsg(228)), m_pszChrExplain);

    //É¾³ýµÄ½ÇÉ«ÎÞ·¨»¹Ô­£¬Ò»¶¨Ê±¼äÄÚ²»ÄÜ´´½¨Í¬Ãû½ÇÉ«£¬»¹ÒªÉ¾³ýÂð£¿Èç¹ûÒªÉ¾³ý£¬ÇëÊäÈëÓÎÏ··ÖÇøÃÜÂë£¬²¢µã»÷¡°ÊÇ¡±¡£
    if mrYes = FrmDlg.DMessageDlg (SetMessageInfo(CMsg.GetMsg(228)), [mbYes, mbNo{, mbAbort}]) then
      FrmMain.SendDelChr (m_stSelectChrInfo[m_nSelectedChr].UserChr.EncName);
  end;
end;

procedure TSelectChrScene.SelChrCreditsClick;
begin
  BoOneClick := FALSE;
//   OneClickMode := toNone;
  with FrmMain do begin
    CSocket.Active := False;
    CSocket.Port := 7000;

//     if MainParam1 = '' then CSocket.Address := SERVERADDR
//     else begin
//        if (MainParam1 <> '') and (MainParam2 = '') then  //ÆÄ¶ó¸ÞÅÍ 1°³
//           CSocket.Address := MainParam1;
//        if (MainParam2 <> '') and (MainParam3 = '') then begin  //ÆÄ¶ó¸ÞÅÍ 2°³ ÀÎ°æ¿ì
//           CSocket.Address := MainParam1;
//           CSocket.Port := Str_ToInt (MainParam2, 0);
//        end;
//        if (MainParam3 <> '') then begin  //ÆÄ¶ó¸ÞÅÍ 3°³ÀÎ°æ¿ì, ÅëÇÕ Á¢¼Ó
//           if CompareText (MainParam1, '/KWG') = 0 then begin
//              //ÄÚ³Ý ¿ùµå ¿ë
//              CSocket.Address := kornetworldaddress;  //game.megapass.net';
//              CSocket.Port := 9000;
//              BoOneClick := TRUE;
//              OneClickMode := toKornetWorld;
//              with KornetWorld do begin
//                 CPIPcode := MainParam2;
//                 SVCcode  := MainParam3;
//                 LoginID  := MainParam4;
//                 CheckSum := MainParam5; //'dkskxhdkslxlkdkdsaaaasa';
//              end;
//           end else begin
//              //ÀÏ¹Ý ¿øÅ¬¸¯ ÅëÇÕ °ÔÀÌÆ®¿ë
//              CSocket.Address := MainParam2;
//              CSocket.Port := Str_ToInt (MainParam3, 0);
//              BoOneClick := TRUE;
//           end;
//        end;
//     end;
    if BO_FOR_TEST then
      CSocket.Address := TESTSERVERADDR;
    CSocket.Active := True;
  end;

  DScreen.ChangeScene(stLogin);
  ConnectionStep := cnsLogin;
end;

procedure TSelectChrScene.SelChrExitClick;
begin
  FrmMain.Close;
end;

procedure TSelectChrScene.ClearChrs;
begin
  FillChar(m_stSelectChrInfo, sizeof(TSelChar) * 3, #0);
  m_stSelectChrInfo[0].FreezeState := FALSE;
  m_stSelectChrInfo[1].FreezeState := TRUE; //±âº»ÀÌ ¾ó¾î ÀÖ´Â »óÅÂ
//   ChrArr[2].FreezeState := TRUE;
  m_stSelectChrInfo[0].Selected := TRUE;
  m_stSelectChrInfo[1].Selected := FALSE;
//   ChrArr[2].Selected := FALSE;
  m_stSelectChrInfo[0].UserChr.EncName := '';
  m_stSelectChrInfo[1].UserChr.EncName := '';
//   ChrArr[2].UserChr.EncName := '';
end;

procedure TSelectChrScene.AddChr(uname: string; job, hair, level, sex: integer);
var
  n: integer;
begin
  if not m_stSelectChrInfo[0].bSetted then n := 0
  else if not m_stSelectChrInfo[1].bSetted then n := 1
//  else if not ChrArr[2].Valid then n := 2
  else exit;
  m_stSelectChrInfo[n].UserChr.EncName := EncodeString(uname);
  m_stSelectChrInfo[n].UserChr.Job := job;
  m_stSelectChrInfo[n].UserChr.Hair := hair;
  m_stSelectChrInfo[n].UserChr.Level := level;
  m_stSelectChrInfo[n].UserChr.Sex := sex;
  m_stSelectChrInfo[n].bSetted := TRUE;
  m_stSelectChrInfo[n].UserChr.EncEncName := EncodeString(EncodeString(uname));
  m_bChrProcState := _CHR_PROC_SELECT;
end;

procedure TSelectChrScene.MakeNewChar(index: integer);
begin
  CreateChrMode := TRUE;
  NewIndex := index;
//   PlayBGMEx (m_stEffctWav[0]);
  m_bBGMPlay := TRUE;
  m_bChrProcState := _CHR_PROC_CREATE;
  SetChrInfo(m_stCreateChrInfo[0], _GENDER_MAN, _JOB_JUNSA, 0);
  SetMotion(0, _CHR_MT_CC);

  SetChrInfo(m_stCreateChrInfo[1], _GENDER_WOMAN, _JOB_JUNSA, 0);
  SetMotion(1, _CHR_MT_CC);

  FrmDlg.DCreateChr.Tag := NewIndex;
  FrmDlg.DCreateChr.ShowModal;
//   FrmDlg.DCreateChr.Visible := TRUE;
  m_stSelectChrInfo[NewIndex].bSetted := TRUE;
  m_stSelectChrInfo[NewIndex].FreezeState := FALSE;
//  EdChrName.Left := FrmDlg.DCreateChr.Left + 289;
//  EdChrName.Top := FrmDlg.DCreateChr.Top + 404;
//  EdChrName.Visible := TRUE;
//  EdChrName.SetFocus;
  SelectChr(NewIndex);
  FillChar(m_stSelectChrInfo[NewIndex].UserChr, sizeof(TUserCharacterInfo), #0);
end;

function TSelectChrScene.SetCharExplain(bGender, bJob: Byte):Boolean;
var
  nCnt: Integer;
  szJobExplain: array[0..14] of Char;
  pszJobExplain: PChar;
begin
	Result := FALSE;
  if (bGender in [0,1]) and (bJob in [0..3]) then
  begin
    m_pszChrExplain.Clear;
    GetMem(pszJobExplain, SizeOf(Char) * 15);

    case bGender of
			_GENDER_MAN: StrCopy(@szJobExplain, PChar(CMsg.GetMsg(211)));
			_GENDER_WOMAN: StrCopy(@szJobExplain, PChar(CMsg.GetMsg(212)));
		end;

    case bJob of
			_JOB_JUNSA:
			begin
				StrCat(@szJobExplain, PChar(CMsg.GetMsg(213)));
        StrCopy(pszJobExplain,@szJobExplain);
        m_pszChrExplain.Add(pszJobExplain);
			  StringDivide(_CHR_EXPLAIN_WIDTH, m_nDividedExplain, PChar(CMsg.GetMsg(216+bJob)), m_pszChrExplain);
			end;
			_JOB_SULSA:
			begin
				StrCat(@szJobExplain, PChar(CMsg.GetMsg(214)));
        StrCopy(pszJobExplain,@szJobExplain);
        m_pszChrExplain.Add(pszJobExplain);
				StringDivide(_CHR_EXPLAIN_WIDTH, m_nDividedExplain, PChar(CMsg.GetMsg(216+bJob)), m_pszChrExplain);
			end;
			_JOB_DOSA:
			begin
				StrCat(@szJobExplain, PChar(CMsg.GetMsg(215)));
        StrCopy(pszJobExplain,@szJobExplain);
        m_pszChrExplain.Add(pszJobExplain);
				StringDivide(_CHR_EXPLAIN_WIDTH, m_nDividedExplain, PChar(CMsg.GetMsg(216+bJob)), m_pszChrExplain);
			end;
			_JOB_GUNGSA:
			begin
				StrCopy(@szJobExplain, PChar(CMsg.GetMsg(237)));
        StrCopy(pszJobExplain,@szJobExplain);
        m_pszChrExplain.Add(pszJobExplain);
				StringDivide(_CHR_EXPLAIN_WIDTH, m_nDividedExplain, PChar(CMsg.GetMsg(236)), m_pszChrExplain);
			end;
    end;

		Inc(m_nDividedExplain, 1);
//    ShowMessage(IntToStr(m_nDividedExplain));
//    ShowMessage(PChar(m_pszChrExplain.Text));

//    ShowMessage(PChar(pszJobExplainEx));

//		strScanf(pszJobExplainEx, "%[^`]%*c %[^`]%*c %[^`]%*c %[^`]%*c %[^`]%*c %[^`]%*c %[^`]%*c %[^`]%*c %[^`]%*c %[^`]%*c %[^`]%*c %[^`]%*c %[^`]%*c %[^`]%*c %[^`]%*c",
//			   m_pszChrExplain[1], m_pszChrExplain[ 2], m_pszChrExplain[ 3], m_pszChrExplain[ 4], m_pszChrExplain[ 5], m_pszChrExplain[ 6], m_pszChrExplain[ 7], m_pszChrExplain[ 8],
//			   m_pszChrExplain[9], m_pszChrExplain[10], m_pszChrExplain[11], m_pszChrExplain[12], m_pszChrExplain[13], m_pszChrExplain[14]);

//    StrDispose(pszJobExplain);
//    StrDispose(pszJobExplainEx);
    FreeMem(pszJobExplain);
		Result :=  TRUE;
	end;
end;

procedure TSelectChrScene.EdChrnameKeyPress(Sender: TObject; var Key: Char);
begin

end;

function TSelectChrScene.GetJobName(job: integer): string;
begin
  Result := '';
  case job of
    0: Result := 'Õ½Ê¿';
    1: Result := 'Ä§·¨Ê¦';
    2: Result := 'µÀÊ¿';
  end;
end;

procedure TSelectChrScene.SelectChr(index: integer);
begin
  m_stSelectChrInfo[index].Selected := TRUE;
  m_stSelectChrInfo[index].DarkLevel := 30;
  m_stSelectChrInfo[index].starttime := GetTickCount;
  m_stSelectChrInfo[index].Moretime := GetTickCount;

//   m_stSelectChrInfo[index].stCurrFrmInfo.wCurrDelay := GetTickCount;
  if index = 0 then begin
    m_stSelectChrInfo[1].Selected := FALSE;
//      ChrArr[2].Selected := FALSE;
  end
  else if index = 1 then begin
    m_stSelectChrInfo[0].Selected := FALSE;
//      ChrArr[2].Selected := FALSE;
//   end
//   else begin
//      ChrArr[0].Selected := FALSE;
//      ChrArr[1].Selected := FALSE;
  end;
end;

procedure TSelectChrScene.SelChrNewClose;
begin
  m_stSelectChrInfo[NewIndex].bSetted := FALSE;
  m_stSelectChrInfo[NewIndex].Selected := FALSE;
// FrmDlg.DMessageDlg ('NewIndex=> '+IntToStr(NewIndex), [mbYes, mbNo]);
  CreateChrMode := FALSE;
  FrmDlg.DCreateChr.Visible := FALSE;
  EdChrName.Visible := FALSE;
  m_bChrProcState := _CHR_PROC_SELECT;
//   PlayBGMEx (m_stEffctWav[1]);
  m_bBGMPlay := TRUE;
  SetMotion(m_nSelectedChr, _CHR_MT_SM);

//   SelChrSelect1Click;
//   if not ChrArr[0].Selected then begin
//   m_stSelectChrInfo[0].Selected := TRUE;
//   m_stSelectChrInfo[0].FreezeState := FALSE;
//   end;
end;

procedure TSelectChrScene.SelChrNewOk;
var
  chrname, shair, sjob, ssex: string;
begin
  chrname := Trim(EdChrName.Text);
  if chrname <> '' then begin
    m_stSelectChrInfo[NewIndex].bSetted := FALSE;
//      CreateChrMode := FALSE;
//      FrmDlg.DCreateChr.Visible := FALSE;
//      EdChrName.Visible := FALSE;

    m_stSelectChrInfo[0].Selected := TRUE;
    m_stSelectChrInfo[0].FreezeState := FALSE;

    shair := IntToStr(1 + Random(5)); //////****IntToStr(ChrArr[NewIndex].UserChr.Hair);
    sjob := IntToStr(m_stCreateChrInfo[m_nCreatedChr].UserChr.Job);
    ssex := IntToStr(m_stCreateChrInfo[m_nCreatedChr].UserChr.Sex);
    FrmMain.SendNewChr(FrmMain.LoginId, chrname, shair, sjob, ssex); //»õ Ä³¸¯ÅÍ¸¦ ¸¸µç´Ù.
  end;
end;

procedure TSelectChrScene.SelChrNewJob(job: integer);
begin
  if (job in [0..2]) and (m_stSelectChrInfo[NewIndex].UserChr.Job <> job) then begin
    m_stSelectChrInfo[NewIndex].UserChr.Job := job;
    SelectChr(NewIndex);
  end;
  case job of
    0:begin
			SetChrInfo(m_stCreateChrInfo[0], _GENDER_MAN, _JOB_JUNSA, 0);
			SetMotion(0, _CHR_MT_CC);

			SetChrInfo(m_stCreateChrInfo[1], _GENDER_WOMAN, _JOB_JUNSA, 0);
			SetMotion(1, _CHR_MT_CC);

			if ( m_nCreatedChr <>_SELECTED_NONE ) then begin
				SetCharExplain(m_nCreatedChr, _JOB_JUNSA);
      end;
    end;
    1:begin
			SetChrInfo(m_stCreateChrInfo[0], _GENDER_MAN, _JOB_SULSA, 0);
			SetMotion(0, _CHR_MT_CC);

			SetChrInfo(m_stCreateChrInfo[1], _GENDER_WOMAN, _JOB_SULSA, 0);
			SetMotion(1, _CHR_MT_CC);

			if ( m_nCreatedChr <>_SELECTED_NONE ) then begin
				SetCharExplain(m_nCreatedChr, _JOB_SULSA);
      end;
    end;
    2:begin
			SetChrInfo(m_stCreateChrInfo[0], _GENDER_MAN, _JOB_DOSA, 0);
			SetMotion(0, _CHR_MT_CC);

			SetChrInfo(m_stCreateChrInfo[1], _GENDER_WOMAN, _JOB_DOSA, 0);
			SetMotion(1, _CHR_MT_CC);

			if ( m_nCreatedChr <>_SELECTED_NONE ) then begin
				SetCharExplain(m_nCreatedChr, _JOB_DOSA);
      end;
    end;
  end;
end;

procedure TSelectChrScene.SelChrNewSex(sex: integer);
begin
  if sex <> m_stSelectChrInfo[NewIndex].UserChr.Sex then begin
    m_stSelectChrInfo[NewIndex].UserChr.Sex := sex;
    SelectChr(NewIndex);
  end;
end;

procedure TSelectChrScene.SelChrNewPrevHair;
begin
end;

procedure TSelectChrScene.SelChrNewNextHair;
begin
end;

procedure TSelectChrScene.PlayScene (MSurface: TDirectDrawSurface);
var
  nCnt, nSelectIdx, nPosX, nPosY, shPX, shPY: Integer;
  d, c, e: TDirectDrawSurface;
  pstChrInfo: TSelChar;
  pstSprInfo: TCharsprIinfo;
  sShowName: string;
  rc: TRect;
  OldFontStyle: TFontStyles;
begin
  if (m_bChrProcState = _CHR_PROC_SELECT) or (m_bChrProcState = _CHR_PROC_CREATEOUT) then begin

    if m_bBGMPlay then begin
      m_bBGMPlayTime := m_bBGMPlayTime + GetTickCount;
      if ( m_bBGMPlayTime > 1000 ) then begin
        PlayBGMEx ('.\Sound\SelChr.mp3');
        m_bBGMPlay     := FALSE;
        m_bBGMPlayTime := 0;
      end;
    end;

    d := g_WInterface1c.Images[50];
    if d <> nil then begin
      MSurface.Draw (0, 0, d.ClientRect, d, FALSE);
    end;

    for nCnt :=0 to _MAX_SHOW_CHAR - 1 do begin
  //		if (m_bFrontSetofSelChar = FALSE)
  //			nSelectIdx = nCnt + 2;
  //		else
      nSelectIdx := nCnt;

      if m_stSelectChrInfo[nSelectIdx].bSetted then begin
        pstChrInfo := m_stSelectChrInfo[nSelectIdx];
        pstSprInfo := m_stSelectChrInfo[nSelectIdx].stCurrFrmInfo.pstCurrSprInfo;

        if GetTickCount - m_stSelectChrInfo[nSelectIdx].stCurrFrmInfo.wCurrDelay > pstSprInfo.wDelay then begin
          m_stSelectChrInfo[nSelectIdx].stCurrFrmInfo.wCurrDelay := GetTickCount;
          Inc(m_stSelectChrInfo[nSelectIdx].stCurrFrmInfo.wCurrFrm , 1);

          if m_stSelectChrInfo[nSelectIdx].stCurrFrmInfo.wCurrFrm = pstSprInfo.wFstFrm+1 then begin
            if m_stSelectChrInfo[nSelectIdx].stCurrFrmInfo.wCurrMtn = _CHR_MT_SM then begin
              PlaySoundEx(m_stSelectWav[pstChrInfo.UserChr.Sex][pstChrInfo.UserChr.Job]);
            end;
          end;

          SetCharRect(nSelectIdx, m_stSelectChrInfo[nSelectIdx].stCurrFrmInfo.wCurrMtn);
          if m_stSelectChrInfo[nSelectIdx].stCurrFrmInfo.wCurrFrm > pstSprInfo.wEndFrm then begin
            if m_stSelectChrInfo[nSelectIdx].stCurrFrmInfo.wCurrMtn = _CHR_MT_SM then begin
              SetMotion(nSelectIdx, _CHR_MT_SS);
            end else if  m_stSelectChrInfo[nSelectIdx].stCurrFrmInfo.wCurrMtn = _CHR_MT_R then begin
              SetMotion(nSelectIdx, _CHR_MT_NS);
            end else begin
              m_stSelectChrInfo[nSelectIdx].stCurrFrmInfo.wCurrFrm := pstSprInfo.wFstFrm;
            end;
          end;
        end;

        c := g_WInterface1c.GetCachedImage(m_stSelectChrInfo[nSelectIdx].stCurrFrmInfo.wCurrFrm + 20, shPX, shPY);
        nPosX := m_stSelectChrInfo[nSelectIdx].stCurrFrmInfo.nPosX + shPX;
        nPosY := m_stSelectChrInfo[nSelectIdx].stCurrFrmInfo.nPosY + shPY;
        if c <> nil then begin
          DrawBlend (MSurface, nPosX, nPosY, c, 0);
        end;

        d := g_WInterface1c.GetCachedImage(m_stSelectChrInfo[nSelectIdx].stCurrFrmInfo.wCurrFrm, shPX, shPY);
        nPosX := m_stSelectChrInfo[nSelectIdx].stCurrFrmInfo.nPosX + shPX;
        nPosY := m_stSelectChrInfo[nSelectIdx].stCurrFrmInfo.nPosY + shPY;
        if d <> nil then begin
          if m_stSelectChrInfo[nSelectIdx].stCurrFrmInfo.bBlend <> 0 then
            MSurface.Draw (nPosX, nPosY, d.ClientRect, d, TRUE)
          else
            MSurface.Draw(nPosX, nPosY, d.ClientRect, d, Blend_GrayScale);
        end;

        e := g_WInterface1c.GetCachedImage(m_stSelectChrInfo[nSelectIdx].stCurrFrmInfo.wCurrFrm+40, shPX, shPY);
        nPosX := m_stSelectChrInfo[nSelectIdx].stCurrFrmInfo.nPosX + shPX;
        nPosY := m_stSelectChrInfo[nSelectIdx].stCurrFrmInfo.nPosY + shPY;
        if e <> nil then begin
          DrawBlend (MSurface, nPosX, nPosY, e, 1);
        end;

        if m_nSelectedChr = nSelectIdx then begin
  //      if m_stSelectChrInfo[nSelectIdx].Selected then begin
          if m_stSelectChrInfo[nSelectIdx].UserChr.EncName <> '' then begin
            with g_DXCanvas do begin
              sShowName := CMsg.GetMsg(206) + ' ' + DecodeString(m_stSelectChrInfo[nSelectIdx].UserChr.EncName);
              rc.Left := 80;
              rc.Top := 110;
              rc.Right := rc.Left + 40 + TextWidth(sShowName);
              rc.Bottom := rc.Top + 70;
              Draw2DRect(rc, $C89664, 80);
              Draw2DRectLine(rc, $FF966432);
              OldFontStyle := MainForm.Canvas.Font.Style;
              MainForm.Canvas.Font.Style := [fsBold];
              TextOut(90, 120, sShowName, TColor($96C8FF), 255);
              TextOut(90, 140, TColor($96C8FF), CMsg.GetMsg(207) + '   ' + IntToStr(m_stSelectChrInfo[nSelectIdx].UserChr.Level));
              TextOut(90, 160, TColor($96C8FF), CMsg.GetMsg(208 + m_stSelectChrInfo[nSelectIdx].UserChr.Job));
              MainForm.Canvas.Font.Style := OldFontStyle;
            end;
          end;
        end;
      end;
    end;
  end;


 (*	for ( nCnt = 0; nCnt < _MAX_CHR_SELECT_BTN; nCnt++ )

		if (m_bMoreTwoChar == FALSE)

			if ( nCnt == _MAX_CHR_SELECT_BEFORE || nCnt == _MAX_CHR_SELECT_NEXT )
				continue;
/*			if (m_bFrontSetofSelChar == TRUE)
			{
				if (nCnt == _MAX_CHR_SELECT_NEXT)
				{
					m_xSelectBtn[nCnt].ShowGameBtn();
				}
			}
			else
			{
				if (nCnt == _MAX_CHR_SELECT_BEFORE)
				{
					m_xSelectBtn[nCnt].ShowGameBtn();
				}
			}
*/
		}


//		if ( nCnt != _MAX_CHR_SELECT_BEFORE && nCnt != _MAX_CHR_SELECT_NEXT )
			m_xSelectBtn[nCnt].ShowGameBtn();

		// ¹öÆ°ÀÌ¹ÌÁö(Å¬¸¯)°¡ ¾ø´Â°ü°è·Î...
		RECT* prcBtn = &m_xSelectBtn[nCnt].m_rcBtn;
		if ( PtInRect(prcBtn, m_ptMousePos) )
		{
			if ( nCnt == _MAX_CHR_SELECT_BEFORE || nCnt == _MAX_CHR_SELECT_NEXT )
				continue;

			D3DVECTOR	 vecTrans((FLOAT)prcBtn->left, (FLOAT)prcBtn->top, 0);
			D3DVECTOR	 vecScale((FLOAT)prcBtn->right-prcBtn->left, (FLOAT)prcBtn->bottom-prcBtn->top, 1);

			D3DMATERIAL7 mtrl;
			D3DUtil_InitMaterial(mtrl, (FLOAT)150/255.0f, (FLOAT)100/255.0f, (FLOAT)50/255.0f);
			mtrl.diffuse.a = 50.0f/255.0f;
			DrawBillBoard(g_xMainWnd.Get3DDevice(), &vecTrans, &vecScale, &mtrl, NULL);

			g_xMainWnd.DrawWithGDI(prcBtn, NULL, RGB(200, 150, 100), 1);
		}
	}

	ShowSelectedChrInfo();  *)
end;

procedure TSelectChrScene.DrawNewChr (MSurface: TDirectDrawSurface);
var
   nCnt, nPosX, nPosY, shPX, shPY, img: integer;
   d, dd, c, e: TDirectDrawSurface;
  pstChrInfo: TSelChar;
  pstSprInfo: TCharsprIinfo;
  rcShow, rc2: TRect;
  OldFontStyle: TFontStyles;
  old: Integer;
begin
  if (m_bChrProcState = _CHR_PROC_CREATE) then begin
    if m_bBGMPlay then begin
      m_bBGMPlayTime := m_bBGMPlayTime + GetTickCount;
      if ( m_bBGMPlayTime > 1000 ) then begin
        PlayBGMEx ('.\Sound\CreateChr.mp3');
        m_bBGMPlay     := FALSE;
        m_bBGMPlayTime := 0;
      end;
    end;

    d := g_WInterface1c.Images[80];
    if d <> nil then begin
      MSurface.Draw (0, 0, d.ClientRect, d, FALSE);
    end;

  //	ShowCharExplain();

    for nCnt :=0 to _MAX_SHOW_CHAR - 1 do begin

      if m_stCreateChrInfo[nCnt].bSetted then begin

        pstChrInfo := m_stCreateChrInfo[nCnt];
        pstSprInfo := m_stCreateChrInfo[nCnt].stCurrFrmInfo.pstCurrSprInfo;

        if GetTickCount - m_stCreateChrInfo[nCnt].stCurrFrmInfo.wCurrDelay > pstSprInfo.wDelay then begin
          m_stCreateChrInfo[nCnt].stCurrFrmInfo.wCurrDelay := GetTickCount;
          Inc(m_stCreateChrInfo[nCnt].stCurrFrmInfo.wCurrFrm , 1);

          if nCnt = m_nCreatedChr then begin
            if m_stCreateChrInfo[nCnt].stCurrFrmInfo.wCurrFrm = pstSprInfo.wFstFrm then begin
              PlaySoundEx(m_stCreateWav[pstChrInfo.UserChr.Sex][pstChrInfo.UserChr.Job]);
            end;
          end;

          SetCharRect(0, m_stCreateChrInfo[0].stCurrFrmInfo.wCurrMtn);
          SetCharRect(1, m_stCreateChrInfo[1].stCurrFrmInfo.wCurrMtn);

          if m_stCreateChrInfo[nCnt].stCurrFrmInfo.wCurrFrm > pstSprInfo.wEndFrm then begin
            m_stCreateChrInfo[nCnt].stCurrFrmInfo.wCurrFrm := pstSprInfo.wFstFrm;
          end;

          if nCnt <> m_nCreatedChr then m_stCreateChrInfo[nCnt].stCurrFrmInfo.wCurrFrm := pstSprInfo.wFstFrm;
        end;

        c := g_WInterface1c.GetCachedImage(m_stCreateChrInfo[nCnt].stCurrFrmInfo.wCurrFrm + 20, shPX, shPY);
        nPosX := m_stCreateChrInfo[nCnt].stCurrFrmInfo.nPosX + shPX;
        nPosY := m_stCreateChrInfo[nCnt].stCurrFrmInfo.nPosY + shPY;
        if c <> nil then begin
          DrawBlend (MSurface, nPosX, nPosY, c, 0);
        end;

        d := g_WInterface1c.GetCachedImage(m_stCreateChrInfo[nCnt].stCurrFrmInfo.wCurrFrm, shPX, shPY);
        nPosX := m_stCreateChrInfo[nCnt].stCurrFrmInfo.nPosX + shPX;
        nPosY := m_stCreateChrInfo[nCnt].stCurrFrmInfo.nPosY + shPY;
        if d <> nil then begin
          if nCnt = m_nCreatedChr then
            MSurface.Draw (nPosX, nPosY, d.ClientRect, d, TRUE)
          else
            MSurface.Draw(nPosX, nPosY, d.ClientRect, d, Blend_GrayScale);
        end;

        if nCnt = m_nCreatedChr then begin
          e := g_WInterface1c.GetCachedImage(m_stCreateChrInfo[nCnt].stCurrFrmInfo.wCurrFrm+40, shPX, shPY);
          nPosX := m_stCreateChrInfo[nCnt].stCurrFrmInfo.nPosX + shPX;
          nPosY := m_stCreateChrInfo[nCnt].stCurrFrmInfo.nPosY + shPY;
          if e <> nil then begin
            DrawBlend (MSurface, nPosX, nPosY, e, 1);
          end;
        end;
      end;
    end;

    dd := g_WInterface1c.Images[_CHR_PROC_IMG_CREATE_STONE_S];
    if dd <> nil then begin
      DrawBlend (MSurface, 201, 434, dd, 0);
    end;

    dd := g_WInterface1c.Images[_CHR_PROC_IMG_CREATE_STONE];
    if dd <> nil then begin
      MSurface.Draw (247, 384, dd.ClientRect, dd, TRUE);
    end;


    with g_DXCanvas do begin
      rcShow.Left := 95;
      rcShow.Top := 15;
      rcShow.Right := rcShow.Left + _CHR_EXPLAIN_WIDTH + 20;
      rcShow.Bottom := rcShow.Top + m_nDividedExplain * 18 + 20;
      Draw2DRect(rcShow, $C89664, 80);
      Draw2DRectLine(rcShow, $FF966432);

      old := MainForm.Canvas.Font.Size;
      OldFontStyle := MainForm.Canvas.Font.Style;
      MainForm.Canvas.Font.Size := 11;
      MainForm.Canvas.Font.Style := [fsBold];
      case m_stCreateChrInfo[m_nSelectedChr].UserChr.Job of
        _JOB_JUNSA:
          TextOut(rcShow.Left + 10, rcShow.Top + 10, m_pszChrExplain[0], TColor(RGB(250, 200, 150)), 255);
        _JOB_SULSA:
          TextOut(rcShow.Left + 10, rcShow.Top + 10, m_pszChrExplain[0], TColor(RGB(250, 170, 170)), 255);
        _JOB_DOSA:
          TextOut(rcShow.Left + 10, rcShow.Top + 10, m_pszChrExplain[0], TColor(RGB(150, 220, 150)), 255);
        _JOB_GUNGSA:
          TextOut(rcShow.Left + 10, rcShow.Top + 10, m_pszChrExplain[0], TColor(RGB(150, 220, 150)), 255);
      end;
      MainForm.Canvas.Font.Style := OldFontStyle;
      MainForm.Canvas.Font.Size := old;

      for nCnt := 1 to m_nDividedExplain - 1 do begin
        TextOut(rcShow.Left + 10, rcShow.top+35+18*(nCnt-1), m_pszChrExplain[nCnt], TColor(RGB(250, 250, 255)), 255);
      end;

      rc2.Left := EdChrName.Left;
      rc2.Top := EdChrName.Top;
      rc2.Right := rc2.Left + 1 + EdChrName.Width;
      rc2.Bottom := rc2.Top + 1 + EdChrName.Height;
      Draw2DRectLine(rc2, $FF966432);
    end;

  end;
end;


procedure TSelectChrScene.SetCharSprInfo(var pstChrSpr:TCharsprIinfo; wFstFrm, wEndFrm, wDelay: Word);
begin
	pstChrSpr.wFstFrm := wFstFrm;
	pstChrSpr.wEndFrm := wEndFrm;
	pstChrSpr.wDelay  := wDelay;
end;

procedure TSelectChrScene.SetChrSelSprite;
begin
  FillChar (m_stChrSprInfo, sizeof(TCharsprIinfo)*30, #0);
	// ³²ÀÚÀü»ç.
	SetCharSprInfo(m_stChrSprInfo[0],  200,  210, 120);	// _CHR_MT_NS (Normal Stand ) ¼±ÅÃ ¾ÈµÉ½ÃÀÇ À¯ÈÞ.
	SetCharSprInfo(m_stChrSprInfo[1],  260,  279, 120);	// _CHR_MT_SM (Select Motion) ¼±ÅÃ ½ÃÀÇ µ¿ÀÛ.
	SetCharSprInfo(m_stChrSprInfo[2],  320,  331, 120);	// _CHR_MT_SS (Select Stand ) ¼±ÅÃ ÈÄÀÇ À¯ÈÞ.
	SetCharSprInfo(m_stChrSprInfo[3],  380,  387, 120);	// _CHR_MT_R  (Return       ) ¼±ÅÃ ¾ÈµÉ¶§·Î µ¹¾Æ°¡±â.
	SetCharSprInfo(m_stChrSprInfo[4],  440,  457, 120);	// _CHR_MT_CC (Char Create  ) Ä³¸¯ »ý¼º½ÃÀÇ À¯ÈÞ.

	// ¿©ÀÚÀü»ç.
	SetCharSprInfo(m_stChrSprInfo[5],  500,  510, 120);
	SetCharSprInfo(m_stChrSprInfo[6],  560,  570, 120);
	SetCharSprInfo(m_stChrSprInfo[7],  620,  630, 120);
	SetCharSprInfo(m_stChrSprInfo[8],  680,  691, 120);
	SetCharSprInfo(m_stChrSprInfo[9],  740,  755, 120);

	// ³²ÀÚ¼ú»ç.
	SetCharSprInfo(m_stChrSprInfo[10],  800,  810, 120);
	SetCharSprInfo(m_stChrSprInfo[11],  860,  871, 120);
	SetCharSprInfo(m_stChrSprInfo[12],  920,  930, 120);
	SetCharSprInfo(m_stChrSprInfo[13],  980,  990, 120);
	SetCharSprInfo(m_stChrSprInfo[14], 1040, 1054, 120);

	// ¿©ÀÚ¼ú»ç.
	SetCharSprInfo(m_stChrSprInfo[15], 1100, 1110, 120);
	SetCharSprInfo(m_stChrSprInfo[16], 1160, 1177, 120);
	SetCharSprInfo(m_stChrSprInfo[17], 1220, 1230, 120);
	SetCharSprInfo(m_stChrSprInfo[18], 1280, 1288, 120);
	SetCharSprInfo(m_stChrSprInfo[19], 1340, 1356, 120);

	// ³²ÀÚµµ»ç.
	SetCharSprInfo(m_stChrSprInfo[20], 1400, 1410, 120);
	SetCharSprInfo(m_stChrSprInfo[21], 1460, 1476, 120);
	SetCharSprInfo(m_stChrSprInfo[22], 1520, 1539, 120);
	SetCharSprInfo(m_stChrSprInfo[23], 1580, 1591, 120);
	SetCharSprInfo(m_stChrSprInfo[24], 1640, 1656, 120);

	// ¿©ÀÚµµ»ç.
	SetCharSprInfo(m_stChrSprInfo[25], 1700, 1710, 120);
	SetCharSprInfo(m_stChrSprInfo[26], 1760, 1776, 120);
	SetCharSprInfo(m_stChrSprInfo[27], 1820, 1830, 120);
	SetCharSprInfo(m_stChrSprInfo[28], 1880, 1889, 120);
	SetCharSprInfo(m_stChrSprInfo[29], 1940, 1954, 120);

end;

function TSelectChrScene.GetCharSprInfo (bGender, bJob, bMtn: byte): TCharsprIinfo;
var
  nSprArray: Integer;
begin
	nSprArray := bJob*10 + bGender*5 + bMtn;
	if (nSprArray >= 0) and (nSprArray < _MAX_SPR_KIND) then
	begin
    Result := m_stChrSprInfo[nSprArray];
	end;
end;

procedure TSelectChrScene.SetMotion(nNum :Integer; bMtn: byte);
var
  pstChrInfo: TSelChar;
begin
	if (nNum > _MAX_CHAR) or (bMtn >= _CHR_MAX_MT) then exit;
  FillChar (pstChrInfo, sizeof(TSelChar), #0);

	if (m_bChrProcState = _CHR_PROC_SELECT) or (m_bChrProcState = _CHR_PROC_CREATEOUT) then begin
		pstChrInfo := m_stSelectChrInfo[nNum];
	end else if ( m_bChrProcState = _CHR_PROC_CREATE ) then begin
		pstChrInfo := m_stCreateChrInfo[nNum];
  end;

	if pstChrInfo.bSetted then begin
		pstChrInfo.stCurrFrmInfo.pstCurrSprInfo := GetCharSprInfo(pstChrInfo.UserChr.Sex, pstChrInfo.UserChr.Job, bMtn);

    pstChrInfo.stCurrFrmInfo.wCurrMtn   := bMtn;
    pstChrInfo.stCurrFrmInfo.wCurrFrm   := pstChrInfo.stCurrFrmInfo.pstCurrSprInfo.wFstFrm;
    pstChrInfo.stCurrFrmInfo.wCurrDelay := 0;

    if pstChrInfo.stCurrFrmInfo.wCurrMtn = _CHR_MT_NS then
    begin
      pstChrInfo.stCurrFrmInfo.bBlend := 0;
    end
    else
    begin
      pstChrInfo.stCurrFrmInfo.bBlend := 255;
    end;

    if (m_bChrProcState = _CHR_PROC_SELECT) or (m_bChrProcState = _CHR_PROC_CREATEOUT) then begin
      m_stSelectChrInfo[nNum] := pstChrInfo;
    end else if ( m_bChrProcState = _CHR_PROC_CREATE ) then begin
      m_stCreateChrInfo[nNum] := pstChrInfo
    end;
	end;
end;


procedure TSelectChrScene.SetCharRect(nNum :Integer; bMtn: byte);
var
  pstChrInfo: TSelChar;
  nPosX, nPosY, shPX, shPY: Integer;
  d: TDirectDrawSurface;
  CharRect: TRect;
begin
	if (nNum > _MAX_CHAR) or (bMtn >= _CHR_MAX_MT) then exit;
	FillChar (pstChrInfo, sizeof(TSelChar), #0);

	if ( m_bChrProcState = _CHR_PROC_SELECT ) then begin
		pstChrInfo := m_stSelectChrInfo[nNum];
	end else if ( m_bChrProcState = _CHR_PROC_CREATE ) then begin
		pstChrInfo := m_stCreateChrInfo[nNum];
	end;

	if pstChrInfo.bSetted then begin
    pstChrInfo.stCurrFrmInfo.pstCurrSprInfo := GetCharSprInfo(pstChrInfo.UserChr.Sex, pstChrInfo.UserChr.Job, bMtn);
    d := g_WInterface1c.GetCachedImage(pstChrInfo.stCurrFrmInfo.wCurrFrm, shPX, shPY);
    if d <> nil then begin

      nPosX := pstChrInfo.stCurrFrmInfo.nPosX+shPX;
      nPosY := pstChrInfo.stCurrFrmInfo.nPosY+shPY;

      with pstChrInfo.stCurrFrmInfo.rcChrRgn do begin
        Left := nPosX;
        Top := nPosY;
        Right := Left + d.Width;
        Bottom := Top + d.Height;
      end;

      if ( m_bChrProcState = _CHR_PROC_SELECT ) then begin
        m_stSelectChrInfo[nNum] := pstChrInfo;
      end else if ( m_bChrProcState = _CHR_PROC_CREATE ) then begin
        m_stCreateChrInfo[nNum] := pstChrInfo;
      end;
		end;
	end;
end;

function TSelectChrScene.GetChrCreatePos(bGender, bJob: byte):TPoint;
const
	ptRet: TPoint	= (X:110;Y:100);
  ptPos: array[0..1] of array[0..3] of TPoint= (
  ((X:110;Y:110),(X:110;Y:120),(X:110;Y:120),(X:110;Y:120)),
  ((X:400;Y:160),(X:420;Y:115),(X:425;Y:118),(X:420;Y:118))
   );
begin
	if ((bGender >= 0) and (bGender < 2)) and ((bJob >= 0) and (bJob < 4)) then
	begin
		ptRet := ptPos[bGender][bJob];
	end;
	Result:= ptRet;
end;

procedure TSelectChrScene.SetChrInfo(var pstChrInfo:TSelChar; bGender, bJob, bLevel: byte; pszName: string);
var
  ptPos: TPoint;
begin
	pstChrInfo.bSetted := TRUE;
	pstChrInfo.UserChr.Sex := bGender;
	pstChrInfo.UserChr.Job  := bJob;
	pstChrInfo.UserChr.Level  := bLevel;

	ptPos := GetChrCreatePos(bGender, bJob);
	pstChrInfo.stCurrFrmInfo.nPosX := ptPos.x;
	pstChrInfo.stCurrFrmInfo.nPosY := ptPos.y;

//	ZeroMemory(pstChrInfo.pszChrName, 25);
//
//	if ( pszName ) then begin
//
//		strcpy(pstChrInfo->pszChrName, pszName);
//	end;
end;

{--------------------------- TLoading ----------------------------}
constructor TLoading.Create;
begin
  inherited Create(stLoading);
end;

destructor TLoading.Destroy;
begin
  inherited Destroy;
end;

procedure TLoading.OpenScene;
begin
  PlaySoundEx (SelectChrScene.m_stEffctWav[2]);
end;

procedure TLoading.CloseScene;
begin
end;

{--------------------------- TLoginNotice ----------------------------}
constructor TLoginNotice.Create;
begin
  inherited Create(stLoginNotice);
end;

destructor TLoginNotice.Destroy;
begin
  inherited Destroy;
end;

procedure TLoginNotice.OpenScene;
begin
  g_FScreenWidth:= PLAYSCREENWIDTH;
  g_FScreenHeight:= PLAYSCREENHEIGHT;

  ClMain.HGE.Gfx_Restore(g_FScreenWidth, g_FScreenHeight, 16);
   //×Ô¶¯¸Ä±äUI×î´óÒÆ¶¯·¶Î§
  GUIFScreenWidth := g_FScreenWidth;
  GUIFScreenHeight := g_FScreenHeight;
end;

procedure TLoginNotice.CloseScene;
begin
end;

end.

