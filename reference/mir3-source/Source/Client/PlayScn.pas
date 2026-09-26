unit PlayScn;

interface

uses
  Windows, Messages, SysUtils, Classes, Graphics, Controls, Forms, Dialogs,
  HGETextures, HGE, IntroScn, Grobal2, CliUtil, HUtil32, Actor, HerbActor,
  AxeMon, SoundUtil, ClEvent, Wil, DWinCtl, StdCtrls, clFunc, magiceff, extctrls;

const
  MAPSURFACEWIDTH = 800;
//   MAPSURFACEHEIGHT = 445;
  MAPSURFACEHEIGHT = 475;
  LONGHEIGHT_IMAGE = 80;
  FLASHBASE = 40;
  AAX = 16;
  SOFFX = 0;
  SOFFY = 0;
  LMX = 30;
  LMY = 26;

  _TILE_ANI_DELAY_1 = 150;
  _TILE_ANI_DELAY_2 = 25;
  _TILE_ANI_DELAY_3 = 50;
  _TILE_ANI_DELAY_4 = 100;
  _TILE_ANI_DELAY_5 = 200;
  _TILE_ANI_DELAY_6 = 250;
  _TILE_ANI_DELAY_7 = 300;
  _TILE_ANI_DELAY_8 = 420;
//   SCREENWIDTH = 800;
//   SCREENHEIGHT = 600;

   MAXLIGHT = 5;
   LightFiles : array[0..MAXLIGHT] of string = (
      'Data\lig0a.dat',
      'Data\lig0b.dat',
      'Data\lig0c.dat',
      'Data\lig0d.dat',
      'Data\lig0e.dat',
      'Data\lig0f.dat'
   );
   LightSizes : array[0..MAXLIGHT] of integer = (
      34496,
      161280,
      327360,
      405920,
      542976,
      713632
   );

   LightMask0 : array[0..2, 0..2] of shortint = (
      (0,1,0),
      (1,3,1),
      (0,1,0)
   );
   LightMask1 : array[0..4, 0..4] of shortint = (
      (0,1,1,1,0),
      (1,1,3,1,1),
      (1,3,4,3,1),
      (1,1,3,1,1),
      (0,1,2,1,0)
   );
   LightMask2 : array[0..8, 0..8] of shortint = (
      (0,0,0,1,1,1,0,0,0),
      (0,0,1,2,3,2,1,0,0),
      (0,1,2,3,4,3,2,1,0),
      (1,2,3,4,4,4,3,2,1),
      (1,3,4,4,4,4,4,3,1),
      (1,2,3,4,4,4,3,2,1),
      (0,1,2,3,4,3,2,1,0),
      (0,0,1,2,3,2,1,0,0),
      (0,0,0,1,1,1,0,0,0)
   );

   LightMask3 : array[0..12, 0..12] of shortint = (
      (0,0,0,0,0,1,1,1,0,0,0,0,0),
      (0,0,0,0,1,1,2,1,1,0,0,0,0),
      (0,0,0,1,1,2,3,2,1,1,0,0,0),
      (0,0,1,1,2,3,4,3,2,1,1,0,0),
      (0,1,1,2,3,4,4,4,3,2,1,1,0),
      (1,1,2,3,4,4,4,4,4,3,2,1,1),
      (1,2,3,4,4,4,4,4,4,4,3,2,1),
      (1,1,2,3,4,4,4,4,4,3,2,1,1),
      (0,1,1,2,3,4,4,4,3,2,1,1,0),
      (0,0,1,1,2,3,4,3,2,1,1,0,0),
      (0,0,0,1,1,2,3,2,1,1,0,0,0),
      (0,0,0,0,1,1,2,1,1,0,0,0,0),
      (0,0,0,0,0,1,1,1,0,0,0,0,0)
   );

   LightMask4 : array[0..20, 0..20] of shortint = (
      (0,0,0,0,0,0,0,0,0,1,1,1,0,0,0,0,0,0,0,0,0),
      (0,0,0,0,0,0,0,0,1,1,1,1,1,0,0,0,0,0,0,0,0),
      (0,0,0,0,0,0,0,1,2,2,2,2,2,1,0,0,0,0,0,0,0),
      (0,0,0,0,0,0,1,2,4,4,4,4,4,2,1,0,0,0,0,0,0),
      (0,0,0,0,0,1,2,4,4,4,4,4,4,4,2,1,0,0,0,0,0),
      (0,0,0,0,1,2,4,4,4,4,4,4,4,4,4,2,1,0,0,0,0),
      (0,0,0,1,2,4,4,4,4,4,4,4,4,4,4,4,2,1,0,0,0),
      (0,0,1,2,4,4,4,4,4,4,4,4,4,4,4,4,4,2,1,0,0),
      (0,1,2,4,4,4,4,4,4,4,4,4,4,4,4,4,4,4,2,1,0),
      (1,2,4,4,4,4,4,4,4,4,4,4,4,4,4,4,4,4,4,2,1),
      (1,2,4,4,4,4,4,4,4,4,4,4,4,4,4,4,4,4,4,2,1),
      (1,2,4,4,4,4,4,4,4,4,4,4,4,4,4,4,4,4,4,2,1),
      (0,1,2,4,4,4,4,4,4,4,4,4,4,4,4,4,4,4,2,1,0),
      (0,0,1,2,4,4,4,4,4,4,4,4,4,4,4,4,4,2,1,0,0),
      (0,0,0,1,2,4,4,4,4,4,4,4,4,4,4,4,2,1,0,0,0),
      (0,0,0,0,1,2,4,4,4,4,4,4,4,4,4,2,1,0,0,0,0),
      (0,0,0,0,0,1,2,4,4,4,4,4,4,4,2,1,0,0,0,0,0),
      (0,0,0,0,0,0,1,2,4,4,4,4,4,2,1,0,0,0,0,0,0),
      (0,0,0,0,0,0,0,1,2,2,2,2,2,1,0,0,0,0,0,0,0),
      (0,0,0,0,0,0,0,0,1,1,1,1,1,0,0,0,0,0,0,0,0),
      (0,0,0,0,0,0,0,0,0,1,1,1,0,0,0,0,0,0,0,0,0)
   );

type
  PShoftInt = ^ShortInt;
  TLightEffect = record
    Width: integer;
    Height: integer;
    PFog: Pbyte;
  end;

  TLightMapInfo = record
    ShiftX: integer;
    ShiftY: integer;
    light: integer;
    bright: integer;
    cLightSizeType: integer;
    cLightColorType: integer;
  end;

  TPlayScene = class(TScene)
    Background: TDXRenderTargetTexture;
//      MapSurface: TDXRenderTargetTexture;
    ObjSurface: TDXRenderTargetTexture;
//      ObjOneCellTile: TDXRenderTargetTexture;
//      ObjTile: TDXRenderTargetTexture;
    MagSurface: TDXRenderTargetTexture;
    LigSurface: TDXRenderTargetTexture;
    WeaSurface: TDXRenderTargetTexture;
    m_boPlayChange: Boolean;
  private
    m_dwPlayChangeTick: LongWord;
//      FogScreen: array[0..MAPSURFACEHEIGHT, 0..MAPSURFACEWIDTH] of byte;
//      PFogScreen: PByte;
//      FogWidth, FogHeight: integer;
    Lights: array[0..MAXLIGHT] of TLightEffect;
    MoveTime: longword;
    MoveStepCount: integer;
    AniTime: longword;
    DefXX, DefYY: integer;
    MainSoundTimer: TTimer;
    MsgList: TList;
    LightMap: array[0..LMX, 0..LMY] of TLightMapInfo;
    WeatherCurFrame, WeatherMaxFrame: integer;
    WeatherAniTime: longword;

    BackgroundRightCurFrame, BackgroundRightMaxFrame: integer;
    BackgroundCurFrame, BackgroundMaxFrame: integer;
    BackgroundAniTime: longword;

    m_dwAniSaveTime: array[0..7] of longword;
    m_bAniTileFrame: array[0..7] of array[0..15] of byte;

//      procedure LoadFog;
    procedure ClearLightMap;
    procedure AddLight(x, y, shiftx, shifty, light: integer; nocheck: Boolean);
    procedure AddMapLight(x, y, shiftx, shifty, light, color: integer; nocheck: Boolean);
    procedure UpdateBright(x, y, light: integer);
    function CheckOverLight(x, y, light: integer): Boolean;
    procedure ApplyLightMap;
    procedure DrawLightEffect(lx, ly, bright: integer);
    procedure EdChatKeyPress(Sender: TObject; var Key: Char);
    procedure SoundOnTimer(Sender: TObject);
  public
    EdChat: TEdit;
    ActorList, TempList: TList;
    GroundEffectList: TList;
    EffectList: TList;
    FlyList: TList;
    BlinkTime: Longword;
    ViewBlink: Boolean;

    ScreenBright: byte;
    ScreenBrightTime: longword;
    ChangeBright: byte;

    constructor Create;
    destructor Destroy; override;
    function Initialize: Boolean;
    procedure Finalize; override;
    procedure OpenScene; override;
    procedure CloseScene; override;
    procedure OpeningScene; override;
    procedure Lost;
    procedure Recovered;
    procedure BeginScene;
    procedure SetAniTileFrame;
    procedure PlaySurface(Sender: TObject);
    procedure DrawObjOneCellTile(nX, nY: integer; bObjNum: byte);
    procedure DrawObjTile(nX, nY: integer; bObjNum: byte);
    procedure LightSurface(Sender: TObject);
    procedure BackgroundSurface(Sender: TObject);
    procedure WeatherSurface(Sender: TObject);
    procedure MagicSurface(Sender: TObject);
    function CanDrawTileMap(): Boolean;
//      procedure DrawTileMap(Sender: TObject);
    procedure DrawMagicBar(surface: TDirectDrawSurface; transparent: Boolean);
    procedure PlayScene(MSurface: TDirectDrawSurface); override;
    function ButchAnimal(x, y: integer): TActor;

    function FindActor(id: integer): TActor;
    function FindActorXY(x, y: integer): TActor;
    function IsValidActor(Actor: TActor): Boolean;
    function NewActor(chrid: integer; cx, cy, cdir: word; cfeature, cstate: integer): TActor;
    procedure ActorDied(Actor: TObject);
    procedure SetActorDrawLevel(Actor: TObject; level: integer);
    procedure ClearActors;
    function DeleteActor(id: integer): TActor;
    procedure DelActor(Actor: TObject);
    procedure SendMsg(ident, chrid, x, y, cdir, feature, state, param: integer; str: string);

    procedure NewMagic (aowner: TActor;
                        magid, magnumb, cx, cy, tx, ty, targetcode: integer;
                        mtype: TMagicType;
                        Recusion: Boolean;
                        anitime: integer;
                        var bofly: Boolean);
    procedure DelMagic(magid: integer);
    function NewFlyObject(aowner: TActor; cx, cy, tx, ty, targetcode: integer; mtype: TMagicType): TMagicEff;
        //function  NewStaticMagic (aowner: TActor; tx, ty, targetcode, effnum: integer);

    procedure ScreenXYfromMCXY(cx, cy: integer; var sx, sy: integer);
    procedure CXYfromMouseXY(mx, my: integer; var ccx, ccy: integer);
    procedure CXYfromMouseXYMid(mx, my: integer; var ccx, ccy: integer);
    function GetCharacter(x, y, wantsel: integer; var nowsel: integer; liveonly: Boolean): TActor;
    function GetAttackFocusCharacter(x, y, wantsel: integer; var nowsel: integer; liveonly: Boolean): TActor;
    function IsSelectMyself(x, y: integer): Boolean;
    function GetDropItems(x, y: integer; var inames: string): PTDropItem;
    procedure DropItemsShow(dsurface: TDirectDrawSurface);
    function CanRun(sx, sy, ex, ey: integer): Boolean;
    function CanWalk(mx, my: integer): Boolean;
    function CrashMan(mx, my: integer): Boolean; //»ç¶÷³¢¸® °ãÄ¡´Â°¡?
    function CanFly(mx, my: integer): Boolean;
    procedure RefreshScene;
    procedure CleanObjects;
  end;

implementation

uses
  ClMain, FState, RelationShip, uWilFile, Light0a, Light0b, Light0c, Light0d;


constructor TPlayScene.Create;
begin
  Background := nil;
//   MapSurface := nil;
  ObjSurface := nil;
//   ObjOneCellTile := nil;
//   ObjTile := nil;
  MagSurface := nil;
  LigSurface := nil;
  WeaSurface := nil;
  MsgList := TList.Create;
  ActorList := TList.Create;
  TempList := TList.Create;
  GroundEffectList := TList.Create;
  EffectList := TList.Create;
  FlyList := TList.Create;
  BlinkTime := GetTickCount;
  ViewBlink := False;

  EdChat := TEdit.Create(FrmMain.Owner);
  with EdChat do begin
    Parent := FrmMain;
    BorderStyle := bsNone;
    OnKeyPress := EdChatKeyPress;
    Visible := False;
    MaxLength := 70;
    Ctl3D := False;
    Left := 185;
    Top := SCREENHEIGHT - 25;
    Height := 12;
    Width := 344;
    Color := clBlack;
    Font.Color := clWhite;
  end;
  MoveTime := GetTickCount;
  AniTime := GetTickCount;
  MainAniCount := 0;
  MoveStepCount := 0;
  MainSoundTimer := TTimer.Create(FrmMain.Owner);
  with MainSoundTimer do begin
    OnTimer := SoundOnTimer;
    Interval := 1;
    Enabled := False;
  end;
  WeatherCurFrame := 0;
  WeatherMaxFrame := 512;
  WeatherAniTime := GetTickCount;
  BackgroundRightCurFrame := 512;
  BackgroundRightMaxFrame := 0;
  BackgroundCurFrame := 0;
  BackgroundMaxFrame := 512;
  BackgroundAniTime := GetTickCount;

  ChangeBright := 0;
end;

destructor TPlayScene.Destroy;
begin
  MsgList.Free;
  ActorList.Free;
  TempList.Free;
  GroundEffectList.Free;
  EffectList.Free;
  FlyList.Free;
  inherited Destroy;
end;

procedure TPlayScene.SoundOnTimer(Sender: TObject);
begin
  PlaySound(s_main_theme);
  MainSoundTimer.Interval := 46 * 1000;
end;

procedure TPlayScene.EdChatKeyPress(Sender: TObject; var Key: Char);
begin
  if Key = #13 then begin
    FrmMain.SendSay(EdChat.Text);
    EdChat.Text := '';
    EdChat.Visible := FALSE;
    Key := #0;
    SetImeMode(EdChat.Handle, imSAlpha);
  end;
  if Key = #27 then begin
    EdChat.Text := '';
    EdChat.Visible := FALSE;
    Key := #0;
    SetImeMode(EdChat.Handle, imSAlpha);
  end;
end;

function TPlayScene.Initialize: Boolean;
var
   i: integer;
begin
  Background := TDXRenderTargetTexture.Create(g_DXCanvas);
  Background.Size := Point(g_FPlayScreenWidth + 10, g_FPlayScreenHeight + 10);
  Background.Active := True;
  if not Background.Active then exit;

//  MapSurface := TDXRenderTargetTexture.Create(g_DXCanvas);
//  MapSurface.Size := Point(g_FPlayScreenWidth+UNITX*10, g_FPlayScreenHeight+UNITY*10);
//  MapSurface.Active := True;
//  if not MapSurface.Active then exit;

  ObjSurface := TDXRenderTargetTexture.Create(g_DXCanvas);
  ObjSurface.Size := Point(g_FPlayScreenWidth + 10, g_FPlayScreenHeight + 10);
  ObjSurface.Active := True;
  if not ObjSurface.Active then exit;

//  ObjOneCellTile := TDXRenderTargetTexture.Create(g_DXCanvas);
//  ObjOneCellTile.Size := Point(g_FPlayScreenWidth + 10, g_FPlayScreenHeight + 10);
//  ObjOneCellTile.Active := True;
//  if not ObjOneCellTile.Active then exit;
//
//  ObjTile := TDXRenderTargetTexture.Create(g_DXCanvas);
//  ObjTile.Size := Point(g_FPlayScreenWidth + 10, g_FPlayScreenHeight + 10);
//  ObjTile.Active := True;
//  if not ObjTile.Active then exit;


  MagSurface := TDXRenderTargetTexture.Create(g_DXCanvas);
  MagSurface.Size := Point(g_FPlayScreenWidth, g_FPlayScreenHeight);
  MagSurface.Active := True;
  if not MagSurface.Active then exit;

  LigSurface := TDXRenderTargetTexture.Create(g_DXCanvas);
  LigSurface.Size := Point(g_FPlayScreenWidth + 10, g_FPlayScreenHeight + 10);
  LigSurface.Active := True;
  if not LigSurface.Active then exit;

  WeaSurface := TDXRenderTargetTexture.Create(g_DXCanvas);
  WeaSurface.Size := Point(g_FPlayScreenWidth + 10, g_FPlayScreenHeight + 10);
  WeaSurface.Active := True;
  if not WeaSurface.Active then exit;

//   FogWidth := MAPSURFACEWIDTH - SOFFX * 2;
//   FogHeight := MAPSURFACEHEIGHT;
//   PFogScreen := @FogScreen;
//   //PFogScreen := AllocMem (FogWidth * FogHeight);
//   ZeroMemory (PFogScreen, MAPSURFACEHEIGHT * MAPSURFACEWIDTH);
//
//   ViewFog := FALSE;
//   for i:=0 to MAXLIGHT do
//      Lights[i].PFog := nil;
//   LoadFog;
  Result := True;
end;

procedure TPlayScene.Finalize;
begin
  if Background <> nil then
    Background.Free;
//  if MapSurface <> nil then
//    MapSurface.Free;
  if ObjSurface <> nil then
    ObjSurface.Free;
//  if ObjOneCellTile <> nil then
//    ObjOneCellTile.Free;
//  if ObjTile <> nil then
//    ObjTile.Free;
  if MagSurface <> nil then
    MagSurface.Free;
  if LigSurface <> nil then
    LigSurface.Free;
  if WeaSurface <> nil then
    WeaSurface.Free;
  Background := nil;
//  MapSurface := nil;
  ObjSurface := nil;
//  ObjOneCellTile := nil;
//  ObjTile := nil;
  MagSurface := nil;
  LigSurface := nil;
  WeaSurface := nil;
end;

procedure TPlayScene.OpenScene;
begin
//   FrmMain.WProgUse.ClearCache;  //·Î±×ÀÎ ÀÌ¹ÌÁö Ä³½Ã¸¦ Áö¿î´Ù.
   FrmDlg.ViewBottomBox (TRUE);
//   EdChat.Visible := TRUE;
//   EdChat.SetFocus;
   SetImeMode (FrmMain.Handle, LocalLanguage);
//   MainSoundTimer.Interval := 1000;
//   MainSoundTimer.Enabled := TRUE;
//   ClMain.HGE.Gfx_Restore(SCREENWIDTH, SCREENHEIGHT, 16);
  ScreenBright := 0;
  ChangeBright := 1;
end;

procedure TPlayScene.CloseScene;
begin
  g_FScreenWidth:= DEFSCREENWIDTH;
  g_FScreenHeight:= DEFSCREENHEIGHT;
  ClMain.HGE.Gfx_Restore(g_FScreenWidth, g_FScreenHeight, 16);
   //×Ô¶¯»Ö¸´UI×î´óÒÆ¶¯·¶Î§800*600
  GUIFScreenWidth := g_FScreenWidth;
  GUIFScreenHeight := g_FScreenHeight;
    //MainSoundTimer.Enabled := FALSE;
  SilenceSound;

  EdChat.Visible := False;
  FrmDlg.ViewBottomBox(False);
end;

procedure TPlayScene.OpeningScene;
begin
end;

procedure TPlayScene.Lost;
begin
  if Background <> nil then
    Background.Lost;
//  if MapSurface <> nil then
//    MapSurface.Lost;
  if ObjSurface <> nil then
    ObjSurface.Lost;
//  if ObjOneCellTile <> nil then
//    ObjOneCellTile.Lost;
//  if ObjTile <> nil then
//    ObjTile.Lost;
  if MagSurface <> nil then
    MagSurface.Lost;
  if LigSurface <> nil then
    LigSurface.Lost;
  if WeaSurface <> nil then
    WeaSurface.Lost;
end;

procedure TPlayScene.Recovered;
begin
  if Background <> nil then
    Background.Recovered;
//  if MapSurface <> nil then
//    MapSurface.Recovered;
  if ObjSurface <> nil then
    ObjSurface.Recovered;
//  if ObjOneCellTile <> nil then
//    ObjOneCellTile.Recovered;
//  if ObjTile <> nil then
//    ObjTile.Recovered;
  if MagSurface <> nil then
    MagSurface.Recovered;
  if LigSurface <> nil then
    LigSurface.Recovered;
  if WeaSurface <> nil then
    WeaSurface.Recovered;
end;

procedure TPlayScene.SetAniTileFrame;
var
  nCnt: integer;
begin
	if GetTickCount - m_dwAniSaveTime[0] > _TILE_ANI_DELAY_1 then begin
    for nCnt := 0 to 16 - 1 do begin
      Inc(m_bAniTileFrame[0][nCnt]);
			if m_bAniTileFrame[0][nCnt] >= nCnt then
				m_bAniTileFrame[0][nCnt] := 0;
    end;
    m_dwAniSaveTime[0] := GetTickCount;
  end;
	if GetTickCount - m_dwAniSaveTime[1] > _TILE_ANI_DELAY_2 then begin
    for nCnt := 0 to 16 - 1 do begin
      Inc(m_bAniTileFrame[1][nCnt]);
			if m_bAniTileFrame[1][nCnt] >= nCnt then
				m_bAniTileFrame[1][nCnt] := 0;
    end;
    m_dwAniSaveTime[1] := GetTickCount;
  end;
	if GetTickCount - m_dwAniSaveTime[2] > _TILE_ANI_DELAY_3 then begin
    for nCnt := 0 to 16 - 1 do begin
      Inc(m_bAniTileFrame[2][nCnt]);
			if m_bAniTileFrame[2][nCnt] >= nCnt then
				m_bAniTileFrame[2][nCnt] := 0;
    end;
    m_dwAniSaveTime[2] := GetTickCount;
  end;
	if GetTickCount - m_dwAniSaveTime[3] > _TILE_ANI_DELAY_4 then begin
    for nCnt := 0 to 16 - 1 do begin
      Inc(m_bAniTileFrame[3][nCnt]);
			if m_bAniTileFrame[3][nCnt] >= nCnt then
				m_bAniTileFrame[3][nCnt] := 0;
    end;
    m_dwAniSaveTime[3] := GetTickCount;
  end;
	if GetTickCount - m_dwAniSaveTime[4] > _TILE_ANI_DELAY_5 then begin
    for nCnt := 0 to 16 - 1 do begin
      Inc(m_bAniTileFrame[4][nCnt]);
			if m_bAniTileFrame[4][nCnt] >= nCnt then
				m_bAniTileFrame[4][nCnt] := 0;
    end;
    m_dwAniSaveTime[4] := GetTickCount;
  end;
	if GetTickCount - m_dwAniSaveTime[5] > _TILE_ANI_DELAY_6 then begin
    for nCnt := 0 to 16 - 1 do begin
      Inc(m_bAniTileFrame[5][nCnt]);
			if m_bAniTileFrame[5][nCnt] >= nCnt then
				m_bAniTileFrame[5][nCnt] := 0;
    end;
    m_dwAniSaveTime[5] := GetTickCount;
  end;
	if GetTickCount - m_dwAniSaveTime[6] > _TILE_ANI_DELAY_7 then begin
    for nCnt := 0 to 16 - 1 do begin
      Inc(m_bAniTileFrame[6][nCnt]);
			if m_bAniTileFrame[6][nCnt] >= nCnt then
				m_bAniTileFrame[6][nCnt] := 0;
    end;
    m_dwAniSaveTime[6] := GetTickCount;
  end;
	if GetTickCount - m_dwAniSaveTime[7] > _TILE_ANI_DELAY_8 then begin
    for nCnt := 0 to 16 - 1 do begin
      Inc(m_bAniTileFrame[7][nCnt]);
			if m_bAniTileFrame[7][nCnt] >= nCnt then
				m_bAniTileFrame[7][nCnt] := 0;
    end;
    m_dwAniSaveTime[7] := GetTickCount;
  end;
//  for nCnt := 0 to 8 - 1 do begin
//    m_dwAniSaveTime[nCnt] := m_dwAniSaveTime[nCnt] + GetTickCount;
//  end;
end;

procedure TPlayScene.BeginScene;
var
  i, k: integer;
  movetick: Boolean;
  pd: PTDropItem;
  evn: TClEvent;
  actor: TActor;
  meff: TMagicEff;
  msgstr: string;
  boChange: Boolean;
begin
  if (Myself = nil) then
  begin
//    msgstr := 'ÕýÔÚÍË³öÓÎÏ·£¬ÇëÉÔºó...';
////    with g_DXCanvas do
////    begin
//      g_ImageDraw.TextOut((g_FScreenWidth - g_ImageDraw.TextWidth(msgstr)) div 2, 200, clWhite, msgstr);
////    end;
    exit;
  end;
  DoFastFadeOut := FALSE;
  m_boPlayChange := False;

  movetick := FALSE;
  if GetTickCount - MoveTime >= 100 then begin
    MoveTime := GetTickCount;   //ÒÆ¶¯¿ªÊ¼Ê±¼ä
    movetick := TRUE;          //ÔÊÐíÒÆ¶¯
    Inc(MoveStepCount);
    if MoveStepCount > 1 then
      MoveStepCount := 0;
  end;
  if GetTickCount - AniTime >= 50 then begin
    AniTime := GetTickCount;
    Inc(MainAniCount);
    if MainAniCount > 1000000 then
      MainAniCount := 0;
  end;
  if ChangeBright <> 0 then begin
    if GetTickCount - ScreenBrightTime >= 20 then begin
      ScreenBrightTime := GetTickCount;
      if ChangeBright = 1 then begin
        Inc(ScreenBright, 5);
        if ScreenBright >= 255 then begin
          ScreenBright := 255;
          ChangeBright := 0;
        end;
      end
      else if ChangeBright = 2 then begin
        Dec(ScreenBright, 5);
        if ScreenBright <= 0 then begin
          ScreenBright := 0;
          ChangeBright := 0;
        end;
      end;
    end;
  end;

  SetAniTileFrame;

  try
    i := 0;                          //´¦Àí½ÇÉ«Ò»Ð©Ïà¹Ø¶«Î÷
    while TRUE do begin              //Frame Ã³¸®´Â ¿©±â¼­ ¾ÈÇÔ.
      if i >= ActorList.Count then
        break;
      actor := ActorList[i];
      if movetick then
        actor.LockEndFrame := FALSE; //¿ÉÒÔÒÆ¶¯
      if not actor.LockEndFrame then begin //Ã»ÓÐËø¶¨¶¯×÷
        actor.ProcMsg;   //´¦Àí½ÇÉ«µÄÏûÏ¢
        if movetick then
          if actor.Move(MoveStepCount, boChange) then begin  //½ÇÉ«ÒÆ¶¯
            m_boPlayChange := m_boPlayChange or boChange;
            Inc(i);
            continue;
          end;
        actor.Run;    //Ä³¸¯ÅÍµéÀ» ¿òÁ÷ÀÌ°Ô ÇÔ.
        if actor <> Myself then
          actor.ProcHurryMsg;
      end;
      if actor = Myself then
        actor.ProcHurryMsg;
      //º¯½ÅÀÎ °æ¿ì
      if actor.WaitForRecogId <> 0 then begin
        if actor.IsIdle then begin
          DelChangeFace(actor.WaitForRecogId);
          NewActor (actor.WaitForRecogId, actor.XX, actor.YY, actor.Dir, actor.WaitForFeature, actor.WaitForStatus);
          actor.WaitForRecogId := 0;
          actor.BoDelActor := TRUE;
        end;
      end;
      if actor.BoDelActor then begin
         //actor.Free;
        FreeActorList.Add(actor);
        ActorList.Delete(i);
        if TargetCret = actor then
          TargetCret := nil;
        if FocusCret = actor then
          FocusCret := nil;
        if MagicTarget = actor then
          MagicTarget := nil;
      end
      else
        Inc(i);
    end;
  except
    DebugOutStr('101');
  end;
  m_boPlayChange := m_boPlayChange or (GetTickCount > m_dwPlayChangeTick);

  try
    i := 0;
    while TRUE do begin
      if i >= GroundEffectList.Count then
        break;
      meff := GroundEffectList[i];
      if meff.Active then begin
        if not meff.Run then begin //¸¶¹ýÈ¿°ú
          meff.Free;
          GroundEffectList.Delete(i);
          continue;
        end;
      end;
      Inc(i);
    end;
    i := 0;
    while TRUE do begin
      if i >= EffectList.Count then
        break;
      meff := EffectList[i];
      if meff.Active then begin
        if not meff.Run then begin //¸¶¹ýÈ¿°ú
          meff.Free;
          EffectList.Delete(i);
          continue;
        end;
      end;
      Inc(i);
    end;
    i := 0;
    while TRUE do begin
      if i >= FlyList.Count then
        break;
      meff := FlyList[i];
      if meff.Active then begin
        if not meff.Run then begin //µµ³¢,È­»ìµî ³¯¾Æ°¡´Â°Í
          meff.Free;
          FlyList.Delete(i);
          continue;
        end;
      end;
      Inc(i);
    end;
    EventMan.Execute;
  except
    DebugOutStr('102');
  end;

  try
   //»ç¶óÁø ¾ÆÀÌÅÛ Ã¼Å©
    for k := 0 to DropedItemList.Count - 1 do begin
      pd := PTDropItem(DropedItemList[k]);
      if pd <> nil then begin
        if (Abs(pd.x - Myself.XX) > 30) and (Abs(pd.y - Myself.YY) > 30) then begin
          Dispose(PTDropItem(DropedItemList[k]));
          DropedItemList.Delete(k);
          break;  //ÇÑ¹ø¿¡ ÇÑ°³¾¿..
        end;
      end;
    end;
   //»ç¶óÁø ´ÙÀÌ³ª¹Í¿ÀºêÁ§Æ® °Ë»ç
    for k := 0 to EventMan.EventList.Count - 1 do begin
      evn := TClEvent(EventMan.EventList[k]);
      if (Abs(evn.X - Myself.XX) > 30) and (Abs(evn.Y - Myself.YY) > 30) then begin
        evn.Free;
        EventMan.EventList.Delete(k);
        break;  //ÇÑ¹ø¿¡ ÇÑ°³¾¿
      end;
    end;
  except
    DebugOutStr('103');
  end;
  try
    with Map.ClientRect do begin
      Left   := MySelf.Rx - 13;
      Top    := MySelf.Ry - 12;
      Right  := MySelf.Rx + 13;
      Bottom := MySelf.Ry + 12;
    end;
    Map.UpdateMapPos(Myself.Rx, Myself.Ry);
  except
    DebugOutStr('104');
  end;
end;

procedure TPlayScene.DrawObjOneCellTile(nX, nY: integer; bObjNum: byte);
var
  m, mm, mmm, defx, defy, nObjFileIdx, nImgIdx, bObjAni, drawingbottomline: integer;
  DSurface, d: TDirectDrawSurface;
begin
  if (MySelf = nil) then exit;

  drawingbottomline := g_FScreenHeight;
  defx := -UNITX * 2 - MySelf.ShiftX + AAX + 14;
  defy := -UNITY * 2 - MySelf.ShiftY;
  DefXX := defx;
  DefYY := defy;

	if map.MArrOb[nX, nY].wFileIdx <> 65535 then begin
		nObjFileIdx := 0;
		nImgIdx	:= 0;
		
    if bObjNum = 0 then begin
      nObjFileIdx := (map.MArrOb[nX, nY].wFileIdx and $FF00) shr 8;
      nImgIdx := map.MArrOb[nX, nY].wObj1;
    end
    else begin
      nObjFileIdx := map.MArrOb[nX, nY].wFileIdx and $FF;
      nImgIdx := map.MArrOb[nX, nY].wObj2;
    end;

    nObjFileIdx := nObjFileIdx - (nObjFileIdx div 15);

    if ((nObjFileIdx mod 14) < 3) or (nObjFileIdx > 69) then exit;

    if (nImgIdx <> 65535) and (nObjFileIdx < 70) and (nObjFileIdx > 0) and ((nObjFileIdx <> 0) or (nImgIdx <> 0)) then
    begin
      if ((nObjFileIdx = 11) or (nObjFileIdx = 25) or
        (nObjFileIdx = 39) or (nObjFileIdx = 53) or (nObjFileIdx = 67)) then
      begin
        bObjAni := map.MArrOb[nX, nY].bObj1Ani;
        if (bObjAni <> 255) and (bObjAni > 0) then
        begin
          if (bObjAni and 7) <> 0 then
            bObjAni := bObjAni and 7;
          nImgIdx := nImgIdx + (MainAniCount mod (bObjAni + (bObjAni * 3))) div 4;
        end;
      end;
      dsurface := nil;
      DSurface := g_MapImageList[nObjFileIdx].Images[nImgIdx];
      if Assigned(dsurface) then begin
        if (dsurface.Width = 48) and (dsurface.Height = 32) then begin
          mmm := mm + UNITY - dsurface.Height;
          if (m + dsurface.Width > 0) and (m <= SCREENWIDTH) and (mmm + dsurface.Height > 0) and (mmm < drawingbottomline) then begin
            if (nObjFileIdx = 25) and
             (map.MArrOb[nX, nY].bFlag = 3) then
              DrawBlend (ObjSurface, m, mmm, DSurface, 0)
            else  ObjSurface.Draw (m, mmm, DSurface.ClientRect, Dsurface, TRUE);
          end;
        end;
      end;
    end;
  end;
end;

procedure TPlayScene.DrawObjTile(nX, nY: integer; bObjNum: byte);
begin
//»æÖÆµÚ¶þ²ãµØÍ¼
end;

procedure TPlayScene.PlaySurface (Sender: TObject);
  function CheckOverlappedObject(myrc, obrc: TRect): Boolean;
  begin
    if (obrc.Right > myrc.Left) and (obrc.Left < myrc.Right) and (obrc.Bottom >
      myrc.Top) and (obrc.Top < myrc.Bottom) then
      Result := TRUE
    else
      Result := FALSE;
  end;
var
  i, j, k, n, m, mmm, ix, iy, line, defx, defy, nObjFileIdx, nImgIdx, bObjAni,
    anitick, ax, ay, idx, drawingbottomline: integer;
  DSurface, d: TDirectDrawSurface;
  blend, movetick: Boolean;
  pd: PTDropItem;
  evn: TClEvent;
  actor: TActor;
  meff: TMagicEff;
  msgstr: string;
  px, py, ImgPosX, ImgPosY: integer;
  rc: TRect;
  bTickType: byte;
  nAniCnt: integer;
  cLightSizeType, cLightColorType: integer;
  bBlend: Boolean;
begin
  if (MySelf = nil) then  exit;

  if BackgroundShow and (Background <> nil) then
  ObjSurface.Draw(SOFFX, SOFFY, Background.ClientRect, Background, False);

  try
    if NoDarkness or (Myself.Death) then begin
      ViewFog := FALSE;
    end;

    if ViewFog then begin //Æ÷±×
     //   ZeroMemory (PFogScreen, MAPSURFACEHEIGHT * (MAPSURFACEWIDTH-200));
      ClearLightMap;
    end;

    drawingbottomline := g_FScreenHeight;
//    ObjSurface.Draw (0, 0,
//                     Rect(UNITX*4 + Myself.ShiftX,
//                          UNITY*3 + Myself.ShiftY,
//                          UNITX*4 + Myself.ShiftX + g_FPlayScreenWidth+10,
//                          UNITY*3 + Myself.ShiftY + g_FPlayScreenHeight+10),
//                          MapSurface,
//                          False);
  except
    DebugOutStr ('104');
  end;

  defx := -UNITX*6 - Myself.ShiftX + AAX + 14;
  defy := -UNITY*4 - Myself.ShiftY;
  DefXX := defx;
  DefYY := defy;

  //»æÖÆµØ×©²ã
  if CanDrawTileMap then begin
    with Map.ClientRect do begin
      m := defy - UNITY * 3;
      for j := (Top - Map.BlockTop - 2) to (Bottom - Map.BlockTop + 1) do begin
        n := defx - UNITX * 2;
        for i := (Left - Map.BlockLeft - 2) to (Right - Map.BlockLeft + 1) do begin
          if (i >= 0) and (i < LOGICALMAPUNIT * 3) and (j >= 0) and (j < LOGICALMAPUNIT * 3) then begin

            if ( i >= map.shWidth) or (j >= map.shHeight) or (i < 0) or (j < 0 ) then continue;
            if (i mod 2 = 0) and (j mod 2 = 0) then begin
              nObjFileIdx := map.MArr[i div 2, j div 2].bFileIdx;
              nImgIdx := map.MArr[i div 2, j div 2].wTileIdx;
              nObjFileIdx := nObjFileIdx - (nObjFileIdx div 15);

              if (nImgIdx <> 65535) and (nObjFileIdx < 70 ) and ((nObjFileIdx mod 14) >= 0) then begin
                DSurface := g_MapImageList[nObjFileIdx].Images[nImgIdx];
                if Assigned(DSurface) then
                  ObjSurface.Draw (n, m, DSurface.ClientRect, DSurface, True);
              end;
            end;
          end;
          Inc(n, UNITX);
        end;
        Inc(m, UNITY);
      end;
    end;
  end;

  try
    m := defy - UNITY;
    for j := (Map.ClientRect.Top - Map.BlockTop) to (Map.ClientRect.Bottom - Map.BlockTop + LONGHEIGHT_IMAGE) do begin
      if j < 0 then begin
        Inc(m, UNITY);
        Continue;
      end;
      n := defx - UNITX * 2;
      for I := (Map.ClientRect.Left - Map.BlockLeft - 2) to (Map.ClientRect.Right - Map.BlockLeft + 2) do begin
        if (I >= 0) and (I < LOGICALMAPUNIT * 3) and (j >= 0) and (j < LOGICALMAPUNIT * 3) then begin
          nObjFileIdx := (map.MArrOb[i, j].wFileIdx and $FF00) shr 8;
          nImgIdx := map.MArrOb[i, j].wObj1;
          nObjFileIdx := nObjFileIdx - (nObjFileIdx div 15);
          bBlend := False;
          if (nImgIdx <> 65535) and (nObjFileIdx < 70) and ((nObjFileIdx mod 14) > 2) then
          begin
            if nObjFileIdx in [11,25,39,53,67] then
            begin
              bObjAni := map.MArrOb[i, j].bObj1Ani;
              if (bObjAni <> 255) {and (bObjAni > 0)} then
              begin
                bTickType := BYTE((bObjAni and $70) shr 4);
                nAniCnt := bObjAni and $0F;
                if (bObjAni and $80) shr 7 <> 0 then bBlend := TRUE;
                nImgIdx := nImgIdx + m_bAniTileFrame[bTickType][nAniCnt];
//                if (bObjAni and 7) <> 0 then
//                  bObjAni := bObjAni and 7;
//                nImgIdx := nImgIdx + (MainAniCount mod (bObjAni + (bObjAni * 3))) div 4;
              end;
            end;

            DSurface := g_MapImageList[nObjFileIdx].Images[nImgIdx];
            if Assigned(dsurface) then begin
              if (dsurface.Width = 48) and (dsurface.Height = 32) then begin
                mmm := m + UNITY - dsurface.Height;
                if (n + dsurface.Width > 0) and (n <= SCREENWIDTH) and (mmm + dsurface.Height > 0) and (mmm < drawingbottomline) then begin
                  if (nObjFileIdx = 25) and ({(map.MArrOb[i, j].bFlag = 3) or }bBlend) then
                    DrawBlend (ObjSurface, n, mmm, DSurface, 0)
                  else  ObjSurface.Draw (n, mmm, DSurface.ClientRect, Dsurface, TRUE);
                end;
              end;
            end;
          end;

          {Front Object Trans}
          nObjFileIdx := map.MArrOb[i, j].wFileIdx and $FF;
          nImgIdx  := map.MArrOb[i, j].wObj2;
          nObjFileIdx := nObjFileIdx - (nObjFileIdx div 15);
          bBlend := False;
          if (nImgIdx <> 65535) and (nObjFileIdx < 70) and ((nObjFileIdx mod 14) > 2) then
          begin
            if nObjFileIdx in [11,25,39,53,67] then
            begin
              bObjAni := map.MArrOb[i, j].bObj2Ani;
              if (bObjAni <> 255){ and (bObjAni > 0)} then
              begin
                bTickType := BYTE((bObjAni and $70) shr 4);
                nAniCnt := bObjAni and $0F;
                if (bObjAni and $80) shr 7 <> 0 then bBlend := TRUE;
                nImgIdx := nImgIdx + m_bAniTileFrame[bTickType][nAniCnt];
//                nImgIdx := nImgIdx + (MainAniCount mod (bObjAni + (bObjAni * 3))) div 4;
//                if (bObjAni and 7) <> 0 then
//                  bObjAni := bObjAni and 7;
              end;
            end;

            DSurface := g_MapImageList[nObjFileIdx].Images[nImgIdx];
            if Assigned(dsurface) then begin
              if (dsurface.Width = 48) and (dsurface.Height = 32) then begin
                mmm := m + UNITY - dsurface.Height;
                if (n + dsurface.Width > 0) and (n <= SCREENWIDTH) and (mmm + dsurface.Height > 0) and (mmm < drawingbottomline) then begin
                  if (nObjFileIdx = 25) and ({(map.MArrOb[i, j].bFlag = 3) or }bBlend) then
                    DrawBlend (ObjSurface, n, mmm, DSurface, 0)
                  else ObjSurface.Draw (n, mmm, DSurface.ClientRect, Dsurface, TRUE);
                end;
              end;
            end;
          end;
        end;
        Inc(n, UNITX);
      end;
      Inc(m, UNITY);
    end;

    for k:=0 to GroundEffectList.Count-1 do begin
      meff := TMagicEff(GroundEffectList[k]);
      //if j = (meff.Ry - Map.BlockTop) then begin
      meff.DrawEff (ObjSurface);
      if ViewFog then begin
         AddLight (meff.Rx, meff.Ry, 0, 0, meff.light, FALSE);
      end;
    end;
  except
      DebugOutStr ('105');
  end;

  try
    m := defy - UNITY;
    for j:=(Map.ClientRect.Top - Map.BlockTop) to (Map.ClientRect.Bottom - Map.BlockTop + LONGHEIGHT_IMAGE) do begin
      if j < 0 then begin Inc (m, UNITY); continue; end;
      n := defx-UNITX*2;
      for i:=(Map.ClientRect.Left - Map.BlockLeft-2) to (Map.ClientRect.Right - Map.BlockLeft+2) do begin
        nObjFileIdx := (map.MArrOb[i, j].wFileIdx and $FF00) shr 8;
        nImgIdx := map.MArrOb[i, j].wObj1;
        nObjFileIdx := nObjFileIdx - (nObjFileIdx div 15);
        bBlend := False;
        if (nImgIdx <> 65535) and (nObjFileIdx < 70) and ((nObjFileIdx mod 14) > 2) then
        begin
          if nObjFileIdx in [11,12,13,25,39,53,67] then
          begin
            bObjAni := 0;
            bObjAni := map.MArrOb[i, j].bObj1Ani;
            if (bObjAni <> 255){ and (bObjAni > 0) }then
            begin
              bTickType := BYTE((bObjAni and $70) shr 4);
              nAniCnt := bObjAni and $0F;
              if (bObjAni and $80) shr 7 <> 0 then bBlend := TRUE;
              nImgIdx := nImgIdx + m_bAniTileFrame[bTickType][nAniCnt];
//              if (bObjAni and 7) <> 0 then
//                bObjAni := bObjAni and 7;
//              nImgIdx := nImgIdx + (MainAniCount mod (bObjAni + (bObjAni * 3))) div 4;
            end;
          end;

          DSurface := g_MapImageList[nObjFileIdx].Images[nImgIdx];
          if Assigned(dsurface) then begin
            if (dsurface.Width in [36,48]) and (dsurface.Height <> 32) then begin
//              DebugOutStr('nObjFileIdx='+IntToStr(nObjFileIdx)+' nImgIdx='+IntToStr(nImgIdx));
              mmm := m + UNITY - dsurface.Height;
              if (n + dsurface.Width > 0) and (n <= SCREENWIDTH) and (mmm + dsurface.Height > 0) and (mmm < drawingbottomline) then begin
                if (nObjFileIdx in [11,25,39,67]) and ({(map.MArrOb[i, j].bFlag = 3) or }bBlend) then
                  DrawBlend (ObjSurface, n, mmm, DSurface, 1)
                else  ObjSurface.Draw (n, mmm, DSurface.ClientRect, Dsurface, TRUE);
              end;
            end;
          end;
        end;

        {Front Object Trans}
        nObjFileIdx := map.MArrOb[i, j].wFileIdx and $FF;
        nImgIdx  := map.MArrOb[i, j].wObj2;
        nObjFileIdx := nObjFileIdx - (nObjFileIdx div 15);
        bBlend := False;
        if (nImgIdx <> 65535) and (nObjFileIdx < 70) and ((nObjFileIdx mod 14) > 2) then
        begin
          if nObjFileIdx in [11,12,13,25,39,53,67] then
          begin
            bObjAni := 0;
            bObjAni := map.MArrOb[i, j].bObj2Ani;
            if (bObjAni <> 255){ and (bObjAni > 0)} then
            begin
              bTickType := BYTE((bObjAni and $70) shr 4);
              nAniCnt := bObjAni and $0F;
              if (bObjAni and $80) shr 7 <> 0 then bBlend := TRUE;
              nImgIdx := nImgIdx + m_bAniTileFrame[bTickType][nAniCnt];
//              if (bObjAni and 7) <> 0 then
//                bObjAni := bObjAni and 7;
//              nImgIdx := nImgIdx + (MainAniCount mod (bObjAni + (bObjAni * 3))) div 4;
            end;
          end;

          DSurface := g_MapImageList[nObjFileIdx].Images[nImgIdx];
          if Assigned(dsurface) then begin
            if (dsurface.Width in [36,48]) and (dsurface.Height <> 32) then begin
//              DebugOutStr('nObjFileIdx='+IntToStr(nObjFileIdx)+' nImgIdx='+IntToStr(nImgIdx));
              mmm := m + UNITY - dsurface.Height;
              if (n + dsurface.Width > 0) and (n <= SCREENWIDTH) and (mmm + dsurface.Height > 0) and (mmm < drawingbottomline) then begin
                if (nObjFileIdx in [11,25]) and ({(map.MArrOb[i, j].bFlag = 3) or }bBlend) then
                  DrawBlend (ObjSurface, n, mmm, DSurface, 1)
                else ObjSurface.Draw (n, mmm, DSurface.ClientRect, Dsurface, TRUE);
              end;
            end;
          end;
        end;
        Inc (n, UNITX);
      end;

      if (j <= (Map.ClientRect.Bottom - Map.BlockTop)) and (not BoServerChanging) then begin
        for k:=0 to EventMan.EventList.Count-1 do begin
          evn := TClEvent (EventMan.EventList[k]);
          if j = (evn.Y - Map.BlockTop) then begin
            evn.DrawEvent (ObjSurface,
                           (evn.X-Map.ClientRect.Left)*UNITX + defx,
                           m);
          end;
        end;

        for k := 0 to DropedItemList.Count - 1 do begin
          pd := PTDropItem(DropedItemList[k]);
          if pd <> nil then begin
            if j = (pd.y - Map.BlockTop) then begin
//              if pd.BoDeco then
//                d := g_WDecoImg.Images[pd.Looks]
//              else
                d := g_WGround.Images[pd.Looks];

              if d <> nil then begin
                ix := (pd.x - Map.ClientRect.Left) * UNITX + defx + SOFFX;
                iy := m; // + actor.ShiftY;
//                if pd.BoDeco then begin
//                  g_WDecoImg.GetCachedImage(pd.Looks, px, py);
//                  ImgPosX := ix + px;
//                  ImgPosY := iy + py;
//                end
//                else begin
                  ImgPosX := ix + HALFX - (d.Width div 2);
                  ImgPosY := iy + HALFY - (d.Height div 2);
//                end;
                DrawBlendShadow(ObjSurface, ImgPosX+1, ImgPosY+1, 50, d, g_boShadowBlend);
                if pd = FocusItem then begin
                  ObjSurface.Draw(ImgPosX, ImgPosY, d.ClientRect, d, True);
                  DrawEffect(ObjSurface, ImgPosX, ImgPosY, d, ceBright, False);
                end
                else begin
                  ObjSurface.Draw(ImgPosX, ImgPosY, d.ClientRect, d, True);
                end;
              end;
            end;
          end;
        end;
                  //*** Ä³¸¯ÅÍ ±×¸®±â
        for k:=0 to ActorList.Count-1 do begin
          actor := ActorList[k];
          if actor.Race = 81 then begin  // ¿ù·É(Ãµ³à)
            if actor.State and $00800000 = 0 then begin//Åõ¸íÀÌ ¾Æ´Ï¸é
              actor.DrawChr (ObjSurface,
                          (actor.Rx-Map.ClientRect.Left)*UNITX+defx,
                          (actor.Ry-Map.ClientRect.Top-1)*UNITY+defy, TRUE, FALSE);
            end;
          end;

          if (j = actor.Ry-Map.BlockTop-actor.DownDrawLevel) then begin
            actor.SayX := (actor.Rx-Map.ClientRect.Left)*UNITX + defx + actor.ShiftX + 24;
            if actor.Death then
              actor.SayY := m + UNITY + actor.ShiftY + 16 - 60  + (actor.DownDrawLevel * UNITY)
            else actor.SayY := m + UNITY + actor.ShiftY + 16 - 95  + (actor.DownDrawLevel * UNITY);
            actor.DrawChr (ObjSurface, (actor.Rx-Map.ClientRect.Left)*UNITX + defx,
                                        m + (actor.DownDrawLevel * UNITY),
                                        FALSE, TRUE);
          end;
        end;
        for k:=0 to FlyList.Count-1 do begin
          meff := TMagicEff(FlyList[k]);
          if j = (meff.Ry - Map.BlockTop) then
            meff.DrawEff (ObjSurface);
        end;
      end;
      Inc (m, UNITY);
    end;
  except
    DebugOutStr ('106');
  end;

  try
    if ViewFog then begin
      m := defy - UNITY*4;
      for j:=(Map.ClientRect.Top - Map.BlockTop - 4) to (Map.ClientRect.Bottom - Map.BlockTop + LONGHEIGHT_IMAGE) do begin
        if j < 0 then begin Inc (m, UNITY); continue; end;
        n := defx-UNITX*5;

        for i:=(Map.ClientRect.Left - Map.BlockLeft-5) to (Map.ClientRect.Right - Map.BlockLeft+5) do begin
          if (i >= 0) and (i < LOGICALMAPUNIT*3) and (j >= 0) and (j < LOGICALMAPUNIT*3) then begin
            idx := Map.MArrOb[i, j].wLigntNEvent;
            if idx <> 0 then begin
              cLightSizeType := (Map.MArrOb[i, j].wLigntNEvent and $C000) shr 14;
            	cLightColorType	:= ((Map.MArrOb[i, j].wLigntNEvent and $3FF0) shr 4);
//              DebugOutStr('cLightSizeType = ' + IntToStr(cLightSizeType));
//              DebugOutStr('cLightColorType = ' + IntToStr(cLightColorType));
              AddMapLight (i+Map.BlockLeft, j+Map.BlockTop, 0, 0, cLightSizeType, cLightColorType, FALSE);
            end;
          end;
          Inc (n, UNITX);
        end;
        Inc (m, UNITY);
      end;

      //Ä³¸¯ÅÍ Æ÷±× ±×¸®±â
      if ActorList.Count > 0 then begin
        for k:=0 to ActorList.Count-1 do begin
          actor := ActorList[k];
          if (actor = Myself) or (actor.Light > 0) then
//            AddLight (actor.Rx, actor.Ry, actor.ShiftX, actor.ShiftY, actor.Light, actor=Myself);
            AddMapLight (actor.Rx, actor.Ry, actor.ShiftX, actor.ShiftY, actor.Light, 5, actor=Myself);
        end;
      end else begin
        if Myself <> nil then
//          AddLight (Myself.Rx, Myself.Ry, Myself.ShiftX, Myself.ShiftY, Myself.Light, TRUE);
          AddMapLight (Myself.Rx, Myself.Ry, Myself.ShiftX, Myself.ShiftY, Myself.Light, 5, TRUE);
      end;
    end;
  except
    DebugOutStr ('107');
  end;

  if not BoServerChanging then begin
    try
      if (MagicTarget <> nil) then begin
//         if IsValidActor (MagicTarget) and (MagicTarget <> Myself) then
        if IsValidActor (MagicTarget) and (MagicTarget <> Myself) and (actor.Race <> 81) then
          if MagicTarget.State and $00800000 = 0 then //Åõ¸íÀÌ ¾Æ´Ï¸é
            if (MagicTarget.State and $00020000 = 0) or (FrmMain.IsGroupMember (TActor (ActorList[k]).UserName)) then
              MagicTarget.DrawChr (ObjSurface,
                           (MagicTarget.Rx-Map.ClientRect.Left)*UNITX+defx,
                           (MagicTarget.Ry-Map.ClientRect.Top-1)*UNITY+defy, TRUE, FALSE);
      end;

      //**** ÁÖÀÎ°ø Ä³¸¯ÅÍ ±×¸®±â
//      if not CheckBadMapMode then
//         if ( Myself.State and $00800000 = 0 ) then //Åõ¸íÀÌ ¾Æ´Ï¸é 1¹ø¸ðµåÀÏ¶§¿¡´Â Ç®¾îÁÜ
//         begin
      Myself.DrawChr (ObjSurface, (Myself.Rx-Map.ClientRect.Left)*UNITX+defx, (Myself.Ry-Map.ClientRect.Top-1)*UNITY+defy, TRUE, FALSE);
//         end;
         
      //**** ¸¶¿ì½º¸¦ °®´Ù´ë°í ÀÖ´Â Ä³¸¯ÅÍ
      if (FocusCret <> nil) then begin
//         if IsValidActor (FocusCret) and (FocusCret <> Myself) then
        if IsValidActor (FocusCret) and (FocusCret <> Myself) and (actor.Race <> 81) then
          if FocusCret.State and $00800000 = 0 then //Åõ¸íÀÌ ¾Æ´Ï¸é
            if (FocusCret.State and $00020000 = 0) or (FrmMain.IsGroupMember (TActor (ActorList[k]).UserName)) then
              FocusCret.DrawChr (ObjSurface,
                           (FocusCret.Rx-Map.ClientRect.Left)*UNITX+defx,
                           (FocusCret.Ry-Map.ClientRect.Top-1)*UNITY+defy, TRUE, FALSE);
      end;
    except
         DebugOutStr ('108');
    end;
  end;
   
  try
   //**** ¸¶¹ý È¿°ú
    for k:=0 to ActorList.Count-1 do begin
      actor := ActorList[k];
      actor.DrawEff (ObjSurface,
                     (actor.Rx-Map.ClientRect.Left)*UNITX + defx,
                     (actor.Ry-Map.ClientRect.Top-1)*UNITY + defy);
    end;
    for k:=0 to EffectList.Count-1 do begin
      meff := TMagicEff(EffectList[k]);
      //if j = (meff.Ry - Map.BlockTop) then begin
      meff.DrawEff (ObjSurface);
      if ViewFog then begin
        AddLight (meff.Rx, meff.Ry, 0, 0, meff.Light, FALSE);
      end;
    end;
    if ViewFog then begin
      for k:=0 to EventMan.EventList.Count-1 do begin
        evn := TClEvent (EventMan.EventList[k]);
        if evn.light > 0 then
            AddLight (evn.X, evn.Y, 0, 0, evn.light, FALSE);
      end;
    end;
  except
      DebugOutStr ('109');
  end;

  //ÏÔÊ¾µØÃæÎïÆ·ÉÁË¸
  try
    for k := 0 to DropedItemList.Count - 1 do begin
      pd := PTDropItem(DropedItemList[k]);
      if (pd <> nil) and (not pd.BoDeco) then begin
        if GetTickCount - pd.FlashTime > 5 * 1000 then begin
          pd.FlashTime := GetTickCount;
          pd.BoFlash := TRUE;
          pd.FlashStepTime := GetTickCount;
          pd.FlashStep := 0;
        end;
        if pd.BoFlash then begin
          if GetTickCount - pd.FlashStepTime >= 20 then begin
            pd.FlashStepTime := GetTickCount;
            Inc(pd.FlashStep);
          end;
          ix := (pd.x - Map.ClientRect.Left) * UNITX + defx + SOFFX;
          iy := (pd.y - Map.ClientRect.Top - 1) * UNITY + defy + SOFFY;

          if (pd.FlashStep >= 0) and (pd.FlashStep < 10) then begin
            DSurface := g_WProgUse.GetCachedImage(FLASHBASE + pd.FlashStep, ax, ay);
            if DSurface <> nil then
              DrawBlend(ObjSurface, ix + 6 {+ ax}, iy {+ ay}, DSurface, 1);
          end
          else
            pd.BoFlash := FALSE;
        end;
      end;
    end;
  except
    DebugOutStr('110');
  end;

  if Weather <> 0 then
    WeaSurface.Draw(SOFFX, SOFFY, WeaSurface.ClientRect, WeaSurface, True, fxAnti);
//   ObjOneCellTile.Draw(SOFFX, SOFFY, ObjOneCellTile.ClientRect, ObjOneCellTile, True);
  try
    if ViewFog then begin
//      ApplyLightMap;
      g_DXCanvas.DrawPart(LigSurface.Target.GetTexture,0,0,0,0,g_FPlayScreenWidth, g_FPlayScreenHeight,$FFFFFFFF, blend_Multiply);
      ObjSurface.Draw (SOFFX, SOFFY, ObjSurface.ClientRect, ObjSurface, FALSE);
    end else begin
      if Myself.Death then
        ObjSurface.Draw(SOFFX, SOFFY, ObjSurface.ClientRect, ObjSurface, Blend_GrayScale)
      else
        ObjSurface.Draw (SOFFX, SOFFY, ObjSurface.ClientRect, ObjSurface, FALSE);
    end;
  except
    DebugOutStr ('111');
  end;
  if BoSkillBarView then DrawMagicBar (ObjSurface, False);
end;

procedure TPlayScene.LightSurface(Sender: TObject);
var
  d: TDirectDrawSurface;
  k, i, j, n, m, idx, sx, sy, defy, defx, lx, ly, Level, Level2, lcount, light, lxx, lyy, ColorType: Integer;
  Actor: TActor;
  LightColor: TColor;
begin
  if (MySelf = nil) then exit;
  if DarkLevel = 1 then Level := 15
  else Level := 85;

  defx := -UNITX * 6 - MySelf.ShiftX + AAX + 14;
  defy := -UNITY * 5 - MySelf.ShiftY;

  if ViewFog and (not MySelf.Death) then begin
    LigSurface.DrawRect(0, 0, g_FPlayScreenWidth, g_FPlayScreenHeight, ARGB(255, Level, Level, Level), True);
    lcount := 0;
    for i := 1 to LMX - 1 do begin
      for j := 1 to LMY - 1 do begin
        light := LightMap[i, j].light;
        ColorType := LightMap[i, j].cLightColorType;
        if light >= 0 then begin
          lx := (i + Myself.Rx - LMX div 2);
          ly := (j + Myself.Ry - LMY div 2);
          lxx := (lx - Map.ClientRect.Left) * UNITX + defx + LightMap[i, j].shiftx;
          lyy := (ly - Map.ClientRect.Top) * UNITY + defy + LightMap[i, j].shifty;

          case ColorType of
            0: LightColor := $FFADC6D6;
            1: LightColor := $FF5A8CA5;
            2: LightColor := $FF293973;
            3: LightColor := $FFDEC663;
            4: LightColor := $FF297331;
            5..9: LightColor := $FFFFFFFF;
            else LightColor := $FFADC6D6;
          end;

          case light of
            0: d := Light0aSurface;
            1: d := Light0cSurface;
            2: d := Light0cSurface;
            3: d := Light0dSurface;
          else
            d := Light0aSurface;
          end;

          if d <> nil then begin
            LigSurface.Draw(lxx - (d.Width-UNITX) div 2, lyy - (d.Height-UNITY) div 2 - 5, d.ClientRect, d, LightColor, Blend_MapLight);
//            LigSurface.Draw(lxx - (d.Width-UNITX) div 2, lyy - (d.Height-UNITY) div 2, d.ClientRect, d, LightColor, BLend_SrcColorAdd);
          end;
          inc(lcount);
        end;
      end;
    end;
  end;
end;

procedure TPlayScene.BackgroundSurface(Sender: TObject);
var
  mx, my: Integer;
  d: TDirectDrawSurface;
  rc: TRect;
begin
  d := g_WProgUse.Images[570];
  if d <> nil then
    Background.Draw(0, 0, d.ClientRect, d, True);

  if GetTickCount - BackgroundAniTime > 10 then begin
    BackgroundAniTime := GetTickCount;
    Inc (BackgroundCurFrame, 12);
    Dec (BackgroundRightCurFrame, 12);
  end;
  if BackgroundCurFrame >= BackgroundMaxFrame then begin
     BackgroundCurFrame := 0;
  end;
  if BackgroundRightCurFrame <= BackgroundRightMaxFrame then begin
     BackgroundRightCurFrame := 512;
  end;

  d := g_WProgUse.Images[550];
  if d <> nil then begin
    mx := BackgroundRightCurFrame;
    my := BackgroundCurFrame;
    rc.Left := mx;
    rc.Top := my;
    rc.Right := rc.Left + g_FPlayScreenWidth;
    rc.Bottom := rc.Top + g_FPlayScreenHeight;
    DrawBlendR(Background, 0, 0, rc, d, 2)
  end;
end;

procedure TPlayScene.WeatherSurface(Sender: TObject);
var
  mx, my: Integer;
  d: TDirectDrawSurface;
  rc: TRect;
begin
  if GetTickCount - WeatherAniTime > 100 then begin
    WeatherAniTime := GetTickCount;
    Inc (WeatherCurFrame, 1);
  end;
  if WeatherCurFrame >= WeatherMaxFrame then begin
     WeatherCurFrame := 0;
  end;

  d := g_WProgUse.Images[550];
  if d <> nil then begin
    if Weather = 1 then begin
      mx := WeatherCurFrame;
      my := 0;
      rc.Left := mx;
      rc.Top := my;
      rc.Right := rc.Left + g_FPlayScreenWidth;
      rc.Bottom := g_FPlayScreenHeight;
    end else begin
      mx := 0;
      my := WeatherCurFrame;
      rc.Left := mx;
      rc.Top := my;
      rc.Right := g_FPlayScreenWidth;
      rc.Bottom := rc.Top + g_FPlayScreenHeight;
    end;
    DrawBlendR(WeaSurface, 0, 0, rc, d, 2)
  end;
end;

procedure TPlayScene.MagicSurface(Sender: TObject);
var
  k: integer;
  meff: TMagicEff;
  ObjSurfaceColor: LongWord;
begin
  if ScreenBright <> 255 then
    ObjSurfaceColor := (ScreenBright shl 24) + (ScreenBright shl 16) + (ScreenBright shl 8) + ScreenBright
  else
    ObjSurfaceColor := $FFFFFFFF;

  MagSurface.Draw(SOFFX, SOFFY, ObjSurface.ClientRect, ObjSurface, ObjSurfaceColor, FALSE);
  for k := 0 to EffectList.count - 1 do begin
    meff := TMagicEff(EffectList[k]);
    meff.DrawEff(ObjSurface);
  end;
end;

function TPlayScene.CanDrawTileMap: Boolean;
begin
  Result := False;
  with Map do
    if (ClientRect.Left = OldClientRect.Left) and (ClientRect.Top = OldClientRect.Top) then Exit;
  if not g_boDrawTileMap then Exit;
  Result := True;
end;

procedure TPlayScene.RefreshScene;
var
  i: integer;
begin
  Map.OldClientRect.Left := -1;
  for i := 0 to ActorList.Count - 1 do
    TActor(ActorList[i]).LoadSurface;
end;

procedure TPlayScene.CleanObjects;
var
  i: integer;
begin
  for i := ActorList.Count - 1 downto 0 do begin
    if TActor(ActorList[i]) <> Myself then begin
      TActor(ActorList[i]).Free;
      ActorList.Delete(i);
    end;
  end;
  MsgList.Clear;
  TargetCret := nil;
  FocusCret := nil;
  MagicTarget := nil;

  for i := 0 to GroundEffectList.Count - 1 do
    TMagicEff(GroundEffectList[i]).Free;
  GroundEffectList.Clear;
  for i := 0 to EffectList.Count - 1 do
    TMagicEff(EffectList[i]).Free;
  EffectList.Clear;
end;


{---------------------- Draw Map -----------------------}

//procedure TPlayScene.DrawTileMap(Sender: TObject);
//var
//   i,j, m,n, nFileIdx, imgnum:integer;
//   DSurface: TDirectDrawSurface;
//  mx, my: Integer;
//  d: TDirectDrawSurface;
//  rc: TRect;
//begin
//  with Map do
//    if (ClientRect.Left = OldClientRect.Left) and (ClientRect.Top = OldClientRect.Top) then exit;
//  Map.OldClientRect := Map.ClientRect;
////   MapSurface.Fill(0);
//
//  with Map.ClientRect do begin
//    m := -UNITY * 4;
//    for j := (Top - Map.BlockTop - 2) to (Bottom - Map.BlockTop + 1) do begin
//      n := AAX + 14 -UNITX * 4;
//      for i := (Left - Map.BlockLeft - 2) to (Right - Map.BlockLeft + 1) do begin
//        if (i >= 0) and (i < LOGICALMAPUNIT * 3) and (j >= 0) and (j < LOGICALMAPUNIT * 3) then begin
//
//          if ( i >= map.shWidth) or (j >= map.shHeight) or (i < 0) or (j < 0 ) then continue;
//
//          if (i mod 2 = 0) and (j mod 2 = 0) then begin
////            nFileIdx := -1;
////            imgnum := -1;
//            nFileIdx := map.MArr[i div 2, j div 2].bFileIdx;
//            imgnum := map.MArr[i div 2, j div 2].wTileIdx;
//            nFileIdx := nFileIdx - (nFileIdx div 15);
//
////            DebugOutStr('nFileIdx='+IntToStr(nFileIdx)+' wTileIdx='+IntToStr(imgnum));
//            if (imgnum <> 65535) and (nFileIdx < 70 ) and ((nFileIdx mod 14) >= 0) then begin
//              DSurface := g_MapImageList[nFileIdx].Images[imgnum];
//              if Assigned(DSurface) then
//                MapSurface.Draw (n, m, DSurface.ClientRect, DSurface, True);
//            end;
//          end;
//        end;
//        Inc(n, UNITX);
//      end;
//      Inc(m, UNITY);
//    end;
//  end;
//end;

{----------------------- Æ÷±×, ¶óÀÌÆ® Ã³¸® -----------------------}


//procedure TPlayScene.LoadFog;  //¶óÀÌÆ® µ¥ÀÌÅ¸ ÀÐ±â
//var
//   i, fhandle, w, h, prevsize: integer;
//   cheat: Boolean;
//begin
//   prevsize := 0; //Á¶ÀÛ Ã¼Å©
//   cheat := FALSE;
//   for i:=0 to MAXLIGHT do begin
//      if FileExists (LightFiles[i]) then begin
//         fhandle := FileOpen (LightFiles[i], fmOpenRead or fmShareDenyNone);
//         FileRead (fhandle, w, sizeof(integer));
//         FileRead (fhandle, h, sizeof(integer));
//         Lights[i].Width := w;
//         Lights[i].Height := h;
//         Lights[i].PFog := AllocMem  (w * h + 8);
//         if prevsize < w * h then begin
//            FileRead (fhandle, Lights[i].PFog^, w*h);
//         end else
//            cheat := TRUE;
//         prevsize := w * h;
//         if LightSizes[i] <> prevsize then
//            cheat := TRUE;
//         FileClose (fhandle);
//      end;
//   end;
//   if cheat then
//      for i:=0 to MAXLIGHT do begin
//         if Lights[i].PFog <> nil then
//            FillChar (Lights[i].PFog^, Lights[i].Width*Lights[i].Height+8, #0);
//      end;
//end;

procedure TPlayScene.ClearLightMap;
var
  i, j: integer;
begin
  FillChar(LightMap, (LMX + 1) * (LMY + 1) * sizeof(TLightMapInfo), 0);
  for i := 0 to LMX do
    for j := 0 to LMY do
      LightMap[i, j].light := -1;
end;

procedure TPlayScene.UpdateBright(x, y, light: integer);
var
  i, j, r, lx, ly: integer;
  pmask: ^ShortInt;
begin
  r := -1;
  case light of
    0:
      begin
        r := 2;
        pmask := @LightMask0;
      end;
    1:
      begin
        r := 4;
        pmask := @LightMask1;
      end;
    2:
      begin
        r := 8;
        pmask := @LightMask2;
      end;
    3:
      begin
        r := 12;
        pmask := @LightMask3;
      end;
    4:
      begin
        r := 20;
        pmask := @LightMask4;
      end;
//      5: begin r := 16; pmask := @LightMask5; end;
  end;
  for i := 0 to r do begin
    for j := 0 to r do begin
      lx := x - (r div 2) + i;
      ly := y - (r div 2) + j;
      if (lx in [0..LMX]) and (ly in [0..LMY]) then
        LightMap[lx, ly].bright := LightMap[lx, ly].bright + PShoftInt(Integer(pmask)
          + (i * (r + 1) + j) * SizeOf(Shortint))^;
    end;
  end;
end;

function TPlayScene.CheckOverLight(x, y, light: integer): Boolean;
var
  i, j, r, mlight, lx, ly, count, check: integer;
  pmask: ^ShortInt;
begin
  r := -1;
  case light of
    0:
      begin
        r := 2;
        pmask := @LightMask0;
        check := 0;
      end;
    1:
      begin
        r := 4;
        pmask := @LightMask1;
        check := 4;
      end;
    2:
      begin
        r := 8;
        pmask := @LightMask2;
        check := 8;
      end;
    3:
      begin
        r := 12;
        pmask := @LightMask3;
        check := 18;
      end;
    4:
      begin
        r := 20;
        pmask := @LightMask4;
        check := 30;
      end;
//      5: begin r := 16; pmask := @LightMask5; check := 40; end;
  end;
  count := 0;
  for i := 0 to r do begin
    for j := 0 to r do begin
      lx := x - (r div 2) + i;
      ly := y - (r div 2) + j;
      if (lx in [0..LMX]) and (ly in [0..LMY]) then begin
        mlight := PShoftInt(Integer(pmask) + (i * (r + 1) + j) * SizeOf(Shortint))^;
        if LightMap[lx, ly].bright < mlight then begin
          Inc(count, mlight - LightMap[lx, ly].bright);
          if count >= check then begin
            Result := False;
            Exit;
          end;
        end;
      end;
    end;
  end;
  Result := True;
end;

procedure TPlayScene.AddLight(x, y, shiftx, shifty, light: integer; nocheck: Boolean);
var
  lx, ly: integer;
begin
  lx := x - Myself.Rx + LMX div 2;
  ly := y - Myself.Ry + LMY div 2;
  if (lx >= 1) and (lx < LMX) and (ly >= 1) and (ly < LMY) then begin
    if LightMap[lx, ly].light < light then begin
      if not CheckOverLight(lx, ly, light) or nocheck then begin // > LightMap[lx, ly].light then begin
        UpdateBright(lx, ly, light);
        LightMap[lx, ly].light := light;
        LightMap[lx, ly].shiftx := shiftx;
        LightMap[lx, ly].shifty := shifty;
      end;
    end;
  end;
end;

procedure TPlayScene.AddMapLight(x, y, shiftx, shifty, light, color: integer;
  nocheck: Boolean);
var
  lx, ly: integer;
begin
  lx := x - Myself.Rx + LMX div 2;
  ly := y - Myself.Ry + LMY div 2;
//  DebugOutStr('LightMap[lx, ly].light = ' + IntToStr(LightMap[lx, ly].light));
//  DebugOutStr('light = ' + IntToStr(light));

  if (lx >= 1) and (lx < LMX) and (ly >= 1) and (ly < LMY) then begin
    if (LightMap[lx, ly].light <= light) or (LightMap[lx, ly].light = 256) then begin
      if not CheckOverLight(lx, ly, light) or nocheck then begin // > LightMap[lx, ly].light then begin
        UpdateBright(lx, ly, light);
        LightMap[lx, ly].light := light;
        LightMap[lx, ly].shiftx := shiftx;
        LightMap[lx, ly].shifty := shifty;
        LightMap[lx, ly].cLightColorType := color;
      end;
    end;
  end;
end;

procedure TPlayScene.ApplyLightMap;
var
  i, j, light, defx, defy, lx, ly, lxx, lyy, lcount: integer;
begin
  defx := -UNITX * 2 + AAX + 14 - Myself.ShiftX;
  defy := -UNITY * 3 - Myself.ShiftY;
  lcount := 0;
  for i := 1 to LMX - 1 do
    for j := 1 to LMY - 1 do begin
      light := LightMap[i, j].light;
      if light >= 0 then begin
        lx := (i + Myself.Rx - LMX div 2);
        ly := (j + Myself.Ry - LMY div 2);
        lxx := (lx - Map.ClientRect.Left) * UNITX + defx + LightMap[i, j].shiftx;
        lyy := (ly - Map.ClientRect.Top) * UNITY + defy + LightMap[i, j].shifty;

//            FogCopy (Lights[light].PFog,
//                     0,
//                     0,
//                     Lights[light].Width,
//                     Lights[light].Height,
//                     PFogScreen,
//                     lxx - (Lights[light].Width-UNITX) div 2,
//                     lyy - (Lights[light].Height-UNITY) div 2 - 5,
//                     FogWidth,
//                     FogHeight,
//                     20);
//            inc (lcount);
      end;
    end;
end;

procedure TPlayScene.DrawLightEffect (lx, ly, bright: integer);
begin
//   if (bright > 0) and (bright <= MAXLIGHT) then
//      FogCopy (Lights[bright].PFog,
//               0,
//               0,
//               Lights[bright].Width,
//               Lights[bright].Height,
//               PFogScreen,
//               lx - (Lights[bright].Width-UNITX) div 2,
//               ly - (Lights[bright].Height-UNITY) div 2,
//               FogWidth,
//               FogHeight,
//               15);
end;

{-----------------------------------------------------------------------}

procedure TPlayScene.DrawMagicBar (surface: TDirectDrawSurface; transparent: Boolean);
var
  d: TDirectDrawSurface;
  I, II, pos, keyimg, icon: integer;
  rc: TRect;
  pm: PTClientMagic;
begin
  for I := 1 to 12 do begin
    pos := I - 1;
    d := g_WGameInter.Images[1450+pos];
    if d <> nil then begin
      rc.Left := 12;
      rc.Top := 12;
      rc.Right := d.Width - 12;
      rc.Bottom := d.Height - 12;
      surface.Draw(pos * 41, 0, rc, d, True, fxBlend);
    end;
  end;
  for I := 0 to _MAX_TYPE_MAGIC - 1 do begin
    for II := 0 to m_xMyMagicList[I].Count - 1 do begin
      pm := PTClientMagic(m_xMyMagicList[I][II]);
      icon := (pm.Def.MagicId - 1) + 1000;
      keyimg := 0;
      case Byte(pm.Key) of
        Byte('1'):
          keyimg := 713;
        Byte('2'):
          keyimg := 715;
        Byte('3'):
          keyimg := 717;
        Byte('4'):
          keyimg := 719;
        Byte('5'):
          keyimg := 721;
        Byte('6'):
          keyimg := 723;
        Byte('7'):
          keyimg := 725;
        Byte('8'):
          keyimg := 727;
        byte('9'):
          keyimg := 729;
        byte('9') + 1:
          keyimg := 731;
        byte('9') + 2:
          keyimg := 733;
        byte('9') + 3:
          keyimg := 735;

        byte('1') + 20:
          keyimg := 729;
        byte('2') + 20:
          keyimg := 731;
        byte('3') + 20:
          keyimg := 733;
        byte('4') + 20:
          keyimg := 735;
        byte('5') + 20:
          keyimg := 737;
        byte('6') + 20:
          keyimg := 739;
        byte('7') + 20:
          keyimg := 741;
        byte('8') + 20:
          keyimg := 743;
        byte('9') + 20:
          keyimg := 753;
        byte('9') + 21:
          keyimg := 755;
        byte('9') + 22:
          keyimg := 757;
        byte('9') + 23:
          keyimg := 759;

      end;

      if keyimg > 0 then begin
        if icon >= 0 then d := g_WMIcon.Images[icon];
        if d <> nil then begin
          if SkillBarNum = 1 then begin
            case keyimg of
              713: surface.Draw (0,   0, d.ClientRect, d, TRUE);
              715: surface.Draw (41,  0, d.ClientRect, d, TRUE);
              717: surface.Draw (41*2,  0, d.ClientRect, d, TRUE);
              719: surface.Draw (41*3, 0, d.ClientRect, d, TRUE);
              721: surface.Draw (41*4, 0, d.ClientRect, d, TRUE);
              723: surface.Draw (41*5, 0, d.ClientRect, d, TRUE);
              725: surface.Draw (41*6, 0, d.ClientRect, d, TRUE);
              727: surface.Draw (41*7, 0, d.ClientRect, d, TRUE);
              729: surface.Draw (41*8, 0, d.ClientRect, d, TRUE);
              731: surface.Draw (41*9, 0, d.ClientRect, d, TRUE);
              733: surface.Draw (41*10, 0, d.ClientRect, d, TRUE);
              735: surface.Draw (41*11, 0, d.ClientRect, d, TRUE);
            end;
          end
          else if SkillBarNum = 2 then begin
            case keyimg of
              729: surface.Draw (9-2,   8-2, d.ClientRect, d, TRUE);
              731: surface.Draw (42-2,  8-2, d.ClientRect, d, TRUE);
              733: surface.Draw (74-2,  8-2, d.ClientRect, d, TRUE);
              735: surface.Draw (106-2, 8-2, d.ClientRect, d, TRUE);
              737: surface.Draw (143-2, 8-2, d.ClientRect, d, TRUE);
              739: surface.Draw (175-2, 8-2, d.ClientRect, d, TRUE);
              741: surface.Draw (207-2, 8-2, d.ClientRect, d, TRUE);
              743: surface.Draw (239-2, 8-2, d.ClientRect, d, TRUE);
  //            743: surface.Draw (277, 8, d.ClientRect, d, TRUE);
              745: surface.Draw (309, 8, d.ClientRect, d, TRUE);
              747: surface.Draw (341, 8, d.ClientRect, d, TRUE);
              759: surface.Draw (374, 8, d.ClientRect, d, TRUE);
            end;
          end;
        end;
      end;
    end;
  end;
end;

{-----------------------------------------------------------------------}
procedure TPlayScene.PlayScene(MSurface: TDirectDrawSurface);
begin
  if (MySelf = nil) then exit;
end;

{-------------------------------------------------------}
procedure TPlayScene.NewMagic(aowner: TActor; magid, magnumb, cx, cy, tx, ty,
  targetcode: integer; mtype: TMagicType; Recusion: Boolean; anitime: integer;
  var bofly: Boolean);
var
  i, scx, scy, sctx, scty, effnum: integer;
  meff: TMagicEff;
  target: TActor;
  wimg: TWMImages;
begin
  if (mtype = mtThunder) and ((magnumb = 8) or (magnumb = 9)) then
  else if not BoViewEffect then begin
    meff := nil;
    Exit;
  end;
  bofly := False;
  if not (magid in [SM_DRAGON_LIGHTING, 70..74, 111, MAGIC_JW_EFFECT1,
    MAGIC_SOULBALL_ATT3_1..MAGIC_SOULBALL_ATT3_5, MAGIC_KINGTURTLE_ATT2_1,
    MAGIC_KINGTURTLE_ATT2_2]) then // FireDragon
    for i := 0 to EffectList.Count - 1 do
      if TMagicEff(EffectList[i]).ServerMagicId = magid then Exit;

  ScreenXYfromMCXY(cx, cy, scx, scy);
  ScreenXYfromMCXY(tx, ty, sctx, scty);
  if magnumb > 0 then
    GetEffectBase(magnumb - 1, 0, wimg, effnum)
  else
    effnum := -magnumb;

  target := FindActor(targetcode);

  meff := nil;
  case mtype of
      mtReady, mtFly, mtFlyAxe:
         begin
            meff := TMagicEff.Create (magid, effnum, scx, scy, sctx, scty, mtype, Recusion, anitime);
            meff.TargetActor := target;
            meff.ImgLib := wimg;
            bofly := TRUE;
         end;
      mtFlyBug :
         begin
            meff := TFlyingBug.Create (magid, effnum, scx, scy, sctx, scty, mtype, Recusion, anitime);
            meff.TargetActor := target;
            //if effnum = 38 then
            //   meff.ImgLib := FrmMain.WMagic2;
            bofly := TRUE;
         end;

      mtExplosion:
         case magnumb of
            18: begin //·ÚÈ¥°Ý
               meff := TMagicEff.Create (magid, effnum, scx, scy, sctx, scty, mtype, Recusion, anitime);
               meff.MagExplosionBase := 1570;
               meff.TargetActor := target;
               meff.NextFrameTime := 80;
            end;
            21: begin //Æø¿­ÆÄ
               meff := TMagicEff.Create (magid, effnum, scx, scy, sctx, scty, mtype, Recusion, anitime);
               meff.MagExplosionBase := 1660;
               meff.TargetActor := nil; //target;
               meff.NextFrameTime := 80;
               meff.ExplosionFrame := 20;
               meff.Light := 3;
            end;
            26: begin //Å½±âÆÄ¿¬
               meff := TMagicEff.Create (magid, effnum, scx, scy, sctx, scty, mtype, Recusion, anitime);
               meff.MagExplosionBase := 3990;
               meff.TargetActor := target;
               meff.NextFrameTime := 80;
               meff.ExplosionFrame := 10;
               meff.Light := 2;
            end;
            27: begin //´ëÈ¸º¹¼ú
               meff := TMagicEff.Create (magid, effnum, scx, scy, sctx, scty, mtype, Recusion, anitime);
               meff.MagExplosionBase := 1800;
               meff.TargetActor := nil; //target;
               meff.NextFrameTime := 80;
               meff.ExplosionFrame := 10;
               meff.Light := 3;
            end;
            30: begin //»çÀÚÀ±È¸
               meff := TMagicEff.Create (magid, effnum, scx, scy, sctx, scty, mtype, Recusion, anitime);
               meff.MagExplosionBase := 3930;
               meff.TargetActor := target;
               meff.NextFrameTime := 80;
               meff.ExplosionFrame := 16;
               meff.Light := 3;
            end;
            31: begin //ºù¼³Ç³
               meff := TMagicEff.Create (magid, effnum, scx, scy, sctx, scty, mtype, Recusion, anitime);
               meff.MagExplosionBase := 3850;
               meff.TargetActor := nil; //target;
               meff.NextFrameTime := 80;
               meff.ExplosionFrame := 20;
               meff.Light := 3;
            end;
            40: begin //Á¤È­¼ú
               meff := TMagicEff.Create (magid, effnum, scx, scy, sctx, scty, mtype, Recusion, anitime);
               meff.MagExplosionBase := 620;
               meff.TargetActor := target;
               meff.NextFrameTime := 80;
               meff.ExplosionFrame := 10;
               meff.Light := 3;
               meff.ImgLib := wimg;
            end;
            47: begin //Æ÷½Â°Ë
               meff := TMagicEff.Create (magid, effnum, scx, scy, sctx, scty, mtype, Recusion, anitime);
               meff.MagExplosionBase := 1010;
               meff.TargetActor := target;
               meff.NextFrameTime := 120;
               meff.ExplosionFrame := 10;
               meff.Light := 2;
               meff.ImgLib := wimg;
            end;
            48: begin //ÈíÇ÷¼ú
               meff := TMagicEff.Create (magid, effnum, scx, scy, sctx, scty, mtype, Recusion, anitime);
               meff.MagExplosionBase := 1060;
               meff.TargetActor := target;
               meff.NextFrameTime := 80;
               meff.ExplosionFrame := 20;
               meff.Light := 2;
               meff.ImgLib := wimg;
            end;
            90: begin // ¿ë¼®»ó Áö¿° FireDragon
               wimg := g_WDragonImg;
               meff.ImgLib := wimg;
               effnum := 350;
               meff := TMagicEff.Create (magid, effnum, scx, scy, sctx, scty, mtype, Recusion, anitime);
               meff.MagExplosionBase := 350;
               meff.ExplosionFrame := 30;
               meff.TargetActor := nil; //target;
               meff.NextFrameTime := 100;
               meff.Light := 3;
            end;

            else begin  //È¸º¹µî..
               meff := TMagicEff.Create (magid, effnum, scx, scy, sctx, scty, mtype, Recusion, anitime);
               meff.TargetActor := target;
               meff.NextFrameTime := 80;
            end;
         end;
      mtFireWind:
         meff := nil;  //È¿°ú ¾øÀ½
      mtFireGun: //È­¿°¹æ»ç
         meff := TFireGunEffect.Create (930, scx, scy, sctx, scty);
      mtThunder:
         begin
            if  magnumb = SM_DRAGON_LIGHTING then begin
               meff := TThuderEffectEx.Create (230, sctx, scty, nil, magnumb); //target);
               meff.ExplosionFrame := 5;
//               meff.MagExplosionBase := 250;
               meff.ImgLib := g_WDragonImg;
               meff.NextFrameTime := 80;
            end
            else if  magnumb = MAGIC_DUN_THUNDER then begin
               meff := TThuderEffectEx.Create (400, sctx, scty, nil, magnumb); //target);
               meff.ExplosionFrame := 5;
               meff.ImgLib := g_WDragonImg;
               meff.NextFrameTime := 100;
            end
            else if  magnumb = MAGIC_DUN_FIRE1 then begin
               meff := TThuderEffectEx.Create (440, sctx, scty, nil, magnumb); //target);
               meff.ExplosionFrame := 20;
               meff.ImgLib := g_WDragonImg;
               meff.NextFrameTime := 90;
            end
            else if  magnumb = MAGIC_DUN_FIRE2 then begin
               meff := TThuderEffectEx.Create (470, sctx, scty, nil, magnumb); //target);
               meff.ExplosionFrame := 10;
               meff.ImgLib := g_WDragonImg;
               meff.NextFrameTime := 90;
            end
            else if  magnumb = MAGIC_DRAGONFIRE then begin
               meff := TThuderEffectEx.Create (200, sctx, scty, nil, magnumb); //target);
               meff.ExplosionFrame := 20;
               meff.ImgLib := g_WDragonImg;
               meff.NextFrameTime := 120;
            end
            else if  magnumb = MAGIC_FIREBURN then begin
               meff := TThuderEffectEx.Create (350, sctx, scty, nil, magnumb); //target);
               meff.ExplosionFrame := 35;
               meff.ImgLib := g_WDragonImg;
               meff.NextFrameTime := 100;
            end
            else if  magnumb = MAGIC_SERPENT_1 then begin
               meff := TThuderEffectEx.Create (1250, sctx, scty, nil, magnumb); //target);
               meff.ExplosionFrame := 15;
               meff.ImgLib := g_WMagicEx[1];
               meff.NextFrameTime := 90;
            end
            else if  magnumb = MAGIC_JW_EFFECT1 then begin
               meff := TThuderEffectEx.Create (1160, sctx, scty, nil, magnumb);
               meff.ExplosionFrame := 18;
               meff.ImgLib := g_WMagicEx[1];
               meff.NextFrameTime := 120;
            end
            else if  magnumb = MAGIC_FOX_THUNDER then begin
               meff := TThuderEffectEx.Create (780, sctx, scty, nil, magnumb);
               meff.ExplosionFrame := 9;
               meff.ImgLib := g_WMon24Img;
               meff.NextFrameTime := 100;
            end
            else if  magnumb = MAGIC_FOX_FIRE1 then begin
               meff := TThuderEffectEx.Create (790, sctx, scty, nil, magnumb);
               meff.ExplosionFrame := 10;
               meff.ImgLib := g_WMon24Img;
               meff.NextFrameTime := 100;
            end
            else if  magnumb = MAGIC_SOULBALL_ATT2 then begin
               meff := TThuderEffectEx.Create (2120, sctx, scty, nil, magnumb);
               meff.ExplosionFrame := 20;
               meff.ImgLib := g_WMon24Img;
               meff.NextFrameTime := 100;
            end
            else if  magnumb = MAGIC_SOULBALL_ATT3_1 then begin
               meff := TThuderEffectEx.Create (2160, sctx, scty, nil, magnumb);
               meff.ExplosionFrame := 20;
               meff.ImgLib := g_WMon24Img;
               meff.NextFrameTime := 100;
               meff.Light := 1;
            end
            else if  magnumb = MAGIC_SOULBALL_ATT3_2 then begin
               meff := TThuderEffectEx.Create (2180, sctx, scty, nil, magnumb);
               meff.ExplosionFrame := 20;
               meff.ImgLib := g_WMon24Img;
               meff.NextFrameTime := 100;
               meff.Light := 1;
            end
            else if  magnumb = MAGIC_SOULBALL_ATT3_3 then begin
               meff := TThuderEffectEx.Create (2200, sctx, scty, nil, magnumb);
               meff.ExplosionFrame := 20;
               meff.ImgLib := g_WMon24Img;
               meff.NextFrameTime := 100;
               meff.Light := 1;
            end
            else if  magnumb = MAGIC_SOULBALL_ATT3_4 then begin
               meff := TThuderEffectEx.Create (2220, sctx, scty, nil, magnumb);
               meff.ExplosionFrame := 20;
               meff.ImgLib := g_WMon24Img;
               meff.NextFrameTime := 100;
               meff.Light := 1;
            end
            else if  magnumb = MAGIC_SOULBALL_ATT3_5 then begin
               meff := TThuderEffectEx.Create (2240, sctx, scty, nil, magnumb);
               meff.ExplosionFrame := 20;
               meff.ImgLib := g_WMon24Img;
               meff.NextFrameTime := 100;
               meff.Light := 1;
            end
            else if  magnumb = MAGIC_KINGTURTLE_ATT2_1 then begin
               meff := TThuderEffectEx.Create (3010, sctx, scty, nil, magnumb);
               meff.ExplosionFrame := 12;
               meff.ImgLib := g_WMon25Img;
               meff.NextFrameTime := 100;
               meff.Light := 1;
            end
            else if  magnumb = MAGIC_KINGTURTLE_ATT2_2 then begin
               meff := TThuderEffectEx.Create (3030, sctx, scty, nil, magnumb);
               meff.ExplosionFrame := 12;
               meff.ImgLib := g_WMon25Img;
               meff.NextFrameTime := 100;
               meff.Light := 1;
            end
            else begin
               meff := TThuderEffect.Create (10, sctx, scty, nil); //target);
               meff.ExplosionFrame := 6;
               meff.ImgLib := g_WMagicEx[1];
            end
         end;
      // 2003/03/15 ½Å±Ô¹«°ø Ãß°¡
      mtFireThunder:
         begin
            meff := TThuderEffect.Create (140, sctx, scty, nil); //target);
            meff.ExplosionFrame := 10;
            meff.ImgLib := g_WMagicEx[1];
         end;

      mtLightingThunder:
         meff := TLightingThunder.Create (970, scx, scy, sctx, scty, target);
      mtExploBujauk:
         begin
            case magnumb of
               10: begin  //Æø»ì°è
                  meff := TExploBujaukEffect.Create (1160, magnumb, scx, scy, sctx, scty, target);
                  meff.MagExplosionBase := 1360;
               end;
               17: begin  //´ëÀº½Å
                  meff := TExploBujaukEffect.Create (1160, magnumb, scx, scy, sctx, scty, target);
                  meff.MagExplosionBase := 1540;
               end;
               49: begin  //¹ÌÈ¥¼ú
                  meff := TExploBujaukEffect.Create (1160, magnumb, scx, scy, sctx, scty, target);
                  meff.MagExplosionBase := 1110;
                  meff.ExplosionFrame := 10;
//                  meff.ImgLib := FrmMain.WMagic2;
               end;
               MAGIC_FOX_FIRE2: begin  //¼ú»çºñ¿ù¿©¿ì:Æø»ì°è
                  meff := TExploBujaukEffect.Create (1160, magnumb, scx, scy, sctx, scty, target);
                  meff.MagExplosionBase := 1320;
                  meff.ExplosionFrame := 10;
               end;
               MAGIC_FOX_CURSE: begin  //¼ú»çºñ¿ù¿©¿ì:ÀúÁÖ¼ú
                  meff := TExploBujaukEffect.Create (1160, magnumb, scx, scy, sctx, scty, target);
                  meff.MagExplosionBase := 1330;
                  meff.ExplosionFrame := 20;
               end;
            end;
            bofly := TRUE;
         end;
      // 2003/03/04
      mtGroundEffect:
         begin
            meff := TMagicEff.Create (magid, effnum, scx, scy, sctx, scty, mtype, Recusion, anitime);
            if meff <> nil then begin
               case magnumb of
               32: begin  //¸¶¹ýÁø1
                      meff.ImgLib := g_WMon21Img;
                      meff.MagExplosionBase := 3580;
                      meff.TargetActor := target;
                      meff.Light := 3;
                      meff.ExplosionFrame := 20;
                   end;
               37: begin
                      meff.ImgLib := g_WMon22Img;
                      meff.MagExplosionBase := 3520;
                      meff.TargetActor := target;
                      meff.Light := 5;
                      meff.ExplosionFrame := 20;
                   end;
               MAGIC_SOULBALL_ATT1: begin
                      meff.ImgLib := g_WMon24Img;
                      meff.MagExplosionBase := 2140;
                      meff.TargetActor := target;
                      meff.Light := 5;
                      meff.ExplosionFrame := 20;
                   end;
               MAGIC_SIDESTONE_ATT1: begin
                      meff.ImgLib := g_WMon24Img;
                      meff.MagExplosionBase := 1440;
                      meff.TargetActor := target;
                      meff.Light := 4;
                      meff.ExplosionFrame := 10;
                      meff.NextFrameTime := 150;
                   end;
               MAGIC_KINGTURTLE_ATT1: begin
                      meff.ImgLib := g_WMon25Img;
                      meff.MagExplosionBase := 2990;
                      meff.TargetActor := target;
                      meff.Light := 5;
                      meff.ExplosionFrame := 10;
                   end;
               MAGIC_KINGTURTLE_ATT3: begin
                      meff.ImgLib := g_WMon25Img;
                      meff.MagExplosionBase := 3060;
                      meff.TargetActor := target;
                      meff.Light := 5;
                      meff.ExplosionFrame := 10;
                   end;
               end;
            end;
//          bofly := TRUE;
         end;
      mtBujaukGroundEffect:
         begin
            meff := TBujaukGroundEffect.Create (1160, magnumb, scx, scy, sctx, scty);
            case magnumb of
               11: meff.ExplosionFrame := 16; //Ç×¸¶Áø¹ý
               12: meff.ExplosionFrame := 16; //´ëÁö¿øÈ£
               46: meff.ExplosionFrame := 24; //ÀúÁÖ¼ú
            end;
            bofly := TRUE;
         end;
      mtKyulKai:
         begin
            meff := nil; //TKyulKai.Create (1380, scx, scy, sctx, scty);
         end;
  end;
  if meff = nil then exit;

  meff.TargetRx := tx;
  meff.TargetRy := ty;
  if meff.TargetActor <> nil then begin
    meff.TargetRx := TActor(meff.TargetActor).XX;
    meff.TargetRy := TActor(meff.TargetActor).YY;
  end;
  meff.MagOwner := aowner;
  EffectList.Add(meff);
end;

procedure TPlayScene.DelMagic(magid: integer);
var
  i: integer;
begin
  for i := 0 to EffectList.Count - 1 do begin
    if TMagicEff(EffectList[i]).ServerMagicId = magid then begin
      TMagicEff(EffectList[i]).Free;
      EffectList.Delete(i);
      break;
    end;
  end;
end;

function TPlayScene.NewFlyObject(aowner: TActor; cx, cy, tx, ty, targetcode:
  integer; mtype: TMagicType): TMagicEff;
var
  i, scx, scy, sctx, scty: integer;
  meff: TMagicEff;
begin
  ScreenXYfromMCXY(cx, cy, scx, scy);
  ScreenXYfromMCXY(tx, ty, sctx, scty);
  case mtype of
    mtFlyArrow:
      meff := TFlyingArrow.Create(1, 1, scx, scy, sctx, scty, mtype, TRUE, 0);
    mtFlyBug:
      meff := TFlyingBug.Create(1, 1, scx, scy, sctx, scty, mtype, TRUE, 0);
    mtFireBall:
      meff := TFlyingFireBall.Create(1, 1, scx, scy, sctx, scty, mtype, TRUE, 0);
  else
    meff := TFlyingAxe.Create(1, 1, scx, scy, sctx, scty, mtype, TRUE, 0);
  end;
  meff.TargetRx := tx;
  meff.TargetRy := ty;
  meff.TargetActor := FindActor(targetcode);
  meff.MagOwner := aowner;
  FlyList.Add(meff);
  Result := meff;
end;


{-------------------------------------------------------}
procedure TPlayScene.ScreenXYfromMCXY(cx, cy: integer; var sx, sy: integer);
begin
  if Myself = nil then exit;
  sx := (cx - Myself.Rx) * UNITX + 364 + UNITX div 2 - Myself.ShiftX;
//   sy := (cy-Myself.Ry)*UNITY + 192 + UNITY div 2 - Myself.ShiftY;
  sy := (cy - Myself.Ry + 1) * UNITY + 192 + UNITY div 2 - Myself.ShiftY;
end;

//½ºÅ©¸°ÀÇ mx, my·Î ¸ÊÀÇ ccx, ccyÁÂÇ¥¸¦ ¾ò¾î³¿
procedure TPlayScene.CXYfromMouseXY(mx, my: integer; var ccx, ccy: integer);
begin
  if Myself = nil then exit;
  ccx := UpInt((mx - 364 + Myself.ShiftX - UNITX) / UNITX) + Myself.Rx;
//   ccy := UpInt((my - 192 + Myself.ShiftY - UNITY) / UNITY) + Myself.Ry;
  ccy := UpInt((my - 192 + Myself.ShiftY - UNITY) / UNITY) + Myself.Ry - 1;
end;

procedure TPlayScene.CXYfromMouseXYMid(mx, my: integer; var ccx, ccy: integer); // ¸¶¹ýÀ» Á»´õ Á¤È®ÇÑ À§Ä¡¿¡ »Ñ¸®±â À§ÇØ..
begin
  if Myself = nil then exit;
  ccx := UpInt((mx - 364 + Myself.ShiftX - UNITX) / UNITX) + Myself.Rx;
//   ccy := UpInt((my - (192 -20)+ Myself.ShiftY - UNITY) / UNITY) + Myself.Ry;
  ccy := UpInt((my - (192 - 20) + Myself.ShiftY - UNITY) / UNITY) + Myself.Ry - 1;
end;

function TPlayScene.GetCharacter(x, y, wantsel: integer; var nowsel: integer;
  liveonly: Boolean): TActor;
var
  k, i, ccx, ccy, dx, dy: integer;
  a: TActor;
begin
  Result := nil;
  nowsel := -1;
  CXYfromMouseXY(x, y, ccx, ccy);
  for k := ccy + 8 downto ccy - 1 do begin
    for i := ActorList.Count - 1 downto 0 do begin
      if TActor(ActorList[i]) <> Myself then begin
        a := TActor(ActorList[i]);
        if (not liveonly or not a.Death) and (a.BoHoldPlace) and (a.Visible) then begin
          if a.YY = k then begin
                  //´õ ³ÐÀº ¹üÀ§·Î ¼±ÅÃµÇ°Ô
            dx := (a.Rx - Map.ClientRect.Left) * UNITX + DefXX + a.px + a.ShiftX;
            dy := (a.Ry - Map.ClientRect.Top - 1) * UNITY + DefYY + a.py + a.ShiftY;
            if a.CheckSelect(x - dx, y - dy) then begin
              Result := a;
              Inc(nowsel);
              if nowsel >= wantsel then
                exit;
            end;
          end;
        end;
      end;
    end;
  end;
end;

function TPlayScene.GetAttackFocusCharacter(x, y, wantsel: integer; var nowsel:
  integer; liveonly: Boolean): TActor;
var
  k, i, ccx, ccy, dx, dy, centx, centy: integer;
  a: TActor;
begin
  Result := GetCharacter(x, y, wantsel, nowsel, liveonly);
  if Result = nil then begin
    nowsel := -1;
    CXYfromMouseXY(x, y, ccx, ccy);
    for k := ccy + 8 downto ccy - 1 do begin
      for i := ActorList.Count - 1 downto 0 do
        if TActor(ActorList[i]) <> Myself then begin
          a := TActor(ActorList[i]);
          if (not liveonly or not a.Death) and (a.BoHoldPlace) and (a.Visible) then begin
            if a.YY = k then begin
              dx := (a.Rx - Map.ClientRect.Left) * UNITX + DefXX + a.px + a.ShiftX;
              dy := (a.Ry - Map.ClientRect.Top - 1) * UNITY + DefYY + a.py + a.ShiftY;
              if a.CharWidth > 40 then
                centx := (a.CharWidth - 40) div 2
              else
                centx := 0;

              if a.CharHeight > 70 then
                centy := (a.CharHeight - 70) div 2
              else
                centy := 0;
              if (x - dx >= centx) and (x - dx <= a.CharWidth - centx) and
                (y - dy >= centy) and (y - dy <= a.CharHeight - centy) then begin
                Result := a;
                Inc(nowsel);
                if nowsel >= wantsel then exit;
              end;
            end;
          end;
        end;
    end;
  end;
end;

function TPlayScene.IsSelectMyself(x, y: integer): Boolean;
var
  k, i, ccx, ccy, dx, dy: integer;
begin
  Result := FALSE;
  CXYfromMouseXY(x, y, ccx, ccy);
  for k := ccy + 2 downto ccy - 1 do begin
    if Myself.YY = k then begin
      dx := (Myself.Rx - Map.ClientRect.Left) * UNITX + DefXX + Myself.px + Myself.ShiftX;
      dy := (Myself.Ry - Map.ClientRect.Top - 1) * UNITY + DefYY + Myself.py +
        Myself.ShiftY;
      if Myself.CheckSelect(x - dx, y - dy) then begin
        Result := TRUE;
        exit;
      end;
    end;
  end;
end;

function TPlayScene.GetDropItems(x, y: integer; var inames: string): PTDropItem; //È­¸éÁÂÇ¥·Î ¾ÆÀÌÅÛ
var
  k, i, ccx, ccy, ssx, ssy, dx, dy: integer;
  d: PTDropItem;
  s: TDirectDrawSurface;
  c: byte;
begin
  Result := nil;
  CXYfromMouseXY(x, y, ccx, ccy);
  ScreenXYfromMCXY(ccx, ccy, ssx, ssy);
  dx := x - ssx;
  dy := y - ssy;
  inames := '';
  for i := 0 to DropedItemList.Count - 1 do begin
    d := PTDropItem(DropedItemList[i]);
    if (d.X = ccx) and (d.Y = ccy) then begin
      {if d.BoDeco then s := g_WDecoImg.Images[d.Looks]
      else}
      s := g_WGround.Images[d.Looks];
      if s = nil then
        continue;
      dx := (x - ssx) + (s.Width div 2) - 3;
      dy := (y - ssy) + (s.Height div 2);
      c := s.Pixels[dx, dy];
      if (c <> 0) or d.BoDeco then begin  //Àå¿ø²Ù¹Ì±â Deco¾ÆÀÌÅÛÀÎ °æ¿ì ÀÌ¸§ ¶ß´Â ¹üÀ§ È®Àå
        if Result = nil then
          Result := d;
        inames := inames + d.Name + '\';
        //break;
      end;
    end;
  end;
end;

procedure TPlayScene.DropItemsShow(dsurface: TDirectDrawSurface); //@@@@
var
  i, k, mx, my, HintWidth, HintHeight: integer;
  d: PTDropItem;
  hintrc: TRect;
begin
  for i := 0 to DropedItemList.Count - 1 do begin
    d := PTDropItem(DropedItemList[i]);
    if d <> nil then begin
      ScreenXYfromMCXY(d.X, d.Y, mx, my);
      HintWidth := FrmMain.Canvas.TextWidth(d.Name) + 4 * 2;
      HintHeight := (FrmMain.Canvas.TextHeight('A') + 1) + 3 * 2;
      hintrc.Left := mx + 2 - ((Length(d.Name) div 2) * 6);
      hintrc.Top := my - 29;
      hintrc.Right := hintrc.Left + HintWidth;
      hintrc.Bottom := hintrc.Top + HintHeight;
      g_DXCanvas.Draw2DRect(hintrc, $503C28, 150);
    end;
  end;

  for k := 0 to DropedItemList.Count - 1 do begin
    d := PTDropItem(DropedItemList[k]);
    if d <> nil then begin
      ScreenXYfromMCXY(d.X, d.Y, mx, my);
      if my > 480 then Continue;
      g_DXCanvas.ShadowTextOut(mx + 2 - ((Length(d.Name) div 2) * 6) + 4, my - 26, $80FFFF, d.Name);
    end;
  end;
end;

function TPlayScene.CanRun(sx, sy, ex, ey: integer): Boolean;
var
  ndir, rx, ry: integer;
begin
  ndir := GetNextDirection(sx, sy, ex, ey);
  rx := sx;
  ry := sy;
  GetNextPosXY(ndir, rx, ry);
  if CanWalk(rx, ry) and CanWalk(ex, ey) then
    Result := TRUE
  else
    Result := FALSE;
end;

function TPlayScene.CanWalk(mx, my: integer): Boolean;
begin
  Result := FALSE;
  if Map.CanMove(mx, my) then
    Result := not CrashMan(mx, my);
end;

function TPlayScene.CrashMan(mx, my: integer): Boolean;
var
  i: integer;
  a: TActor;
begin
  Result := FALSE;
  for i := 0 to ActorList.Count - 1 do begin
    a := TActor(ActorList[i]);
    if (a.Visible) and (a.BoHoldPlace) and (not a.Death) and (a.XX = mx) and (a.YY
      = my) then begin
      Result := TRUE;
      break;
    end;
  end;
end;

function TPlayScene.CanFly(mx, my: integer): Boolean;
begin
  Result := Map.CanFly(mx, my);
end;

{------------------------ Actor ------------------------}
function TPlayScene.FindActor(id: integer): TActor;
var
  i: integer;
begin
  Result := nil;
  for i := 0 to ActorList.Count - 1 do begin
    if TActor(ActorList[i]).RecogId = id then begin
      Result := TActor(ActorList[i]);
      break;
    end;
  end;
end;

function TPlayScene.FindActorXY(x, y: integer): TActor;
var
  i: integer;
begin
  Result := nil;
  for i := 0 to ActorList.Count - 1 do begin
    if (TActor(ActorList[i]).XX = x) and (TActor(ActorList[i]).YY = y) then begin
      Result := TActor(ActorList[i]);
      if not Result.Death and Result.Visible and Result.BoHoldPlace then
        break;
    end;
  end;
end;

function TPlayScene.IsValidActor(actor: TActor): Boolean;
var
  i: integer;
begin
  Result := FALSE;
  for i := 0 to ActorList.Count - 1 do begin
    if TActor(ActorList[i]) = actor then begin
      Result := TRUE;
      break;
    end;
  end;
end;

function TPlayScene.NewActor(chrid: integer; cx: word; cy: word; cdir: word;
  cfeature: integer; cstate: integer): TActor;
var
  i: integer;
  actor: TActor;
  pm: PTMonsterAction;
begin
  for i := 0 to ActorList.Count - 1 do begin
    if TActor(ActorList[i]).RecogId = chrid then begin
      Result := TActor(ActorList[i]);
      Exit;
    end;
  end;
  if IsChangingFace (chrid) then exit;

  case RACEfeature (cfeature) of
    0:  actor := THumActor.Create;
    9: actor := TSoccerBall.Create;  //Ãà±¸°ø

    13: actor := TKillingHerb.Create;
    14: actor := TSkeletonOma.Create;
    15: actor := TDualAxeOma.Create;

    16: actor := TGasKuDeGi.Create;  //°¡½º½î´Â ±¸µ¥±â

    17: actor := TCatMon.Create;   //±ªÀÌ, ¿ì¸é±Í(¿ì¸é±Í,Ã¢µç¿ì¸é±Í,Ã¶Åð¿ì¸é±Í)
    18: actor := THuSuABi.Create;
    19: actor := TCatMon.Create;   //¿ì¸é±Í(¿ì¸é±Í,Ã¢µç¿ì¸é±Í,Ã¶Åðµç¿ì¸é±Í)

    20: actor := TFireCowFaceMon.Create;
    21: actor := TCowFaceKing.Create;
    22: actor := TDualAxeOma.Create;  //Ä§½î´Â ´ÙÅ©
    23: actor := TWhiteSkeleton.Create;  //¼ÒÈ¯¹é°ñ

    24: actor := TSuperiorGuard.Create;  //¸ÚÀÖ´Â °æºñº´

    30: actor := TCatMon.Create; //³¯°³Áþ
    31: actor := TCatMon.Create; //³¯°³Áþ
    32: actor := TScorpionMon.Create; //°ø°ÝÀÌ 2µ¿ÀÛ

    33: actor := TCentipedeKingMon.Create;  //Áö³×¿Õ, ÃË·æ½Å
    34, 97: actor := TBigHeartMon.Create;  //Àû¿ù¸¶, ½ÉÀå, ¹ã³ª¹«, º¸¹°ÇÔ
    35: actor := TSpiderHouseMon.Create;  //Æø¾È°Å¹Ì
    36: actor := TExplosionSpider.Create;  //ÆøÁÖ
    37: actor := TFlyingSpider.Create;  //ºñµ¶°Å¹Ì

    40: actor := TZombiLighting.Create;  //Á»ºñ 1 (Àü±â ¸¶¹ý Á»ºñ)
    41: actor := TZombiDigOut.Create;  //¶¥ÆÄ°í ³ª¿À´Â Á»ºñ
    42: actor := TZombiZilkin.Create;

    43: actor := TBeeQueen.Create;

    45: actor := TArcherMon.Create;
    47: actor := TSculptureMon.Create;  //¿°¼ÒÀå±º, ¿°¼Ò´ëÀå
    48: actor := TSculptureMon.Create;  //
    49: actor := TSculptureKingMon.Create;  //ÁÖ¸¶¿Õ

    50: actor := TNpcActor.Create;

    52, 53: actor := TGasKuDeGi.Create;  //°¡½º½î´Â ½û±â³ª¹æ, µÕ
    54: actor := TSmallElfMonster.Create;
    55: actor := TWarriorElfMonster.Create;

    60: actor := TElectronicScolpionMon.Create;   //·ÚÇ÷»ç
    61: actor := TBossPigMon.Create;              //¿Õµ·
    62: actor := TKingOfSculpureKingMon.Create;   //ÁÖ¸¶º»¿Õ(¿ÕÁß¿Õ)
    // 2003/02/11 ½Å±Ô ¸÷ Ãß°¡ .. ÇØ°ñº»¿Õ, ºÎ½Ä±Í
    63: actor := TSkeletonKingMon.Create;
    64: actor := TGasKuDeGi.Create;
    65: actor := TSamuraiMon.Create;
    66: actor := TSkeletonSoldierMon.Create;
    67: actor := TSkeletonSoldierMon.Create;
    68: actor := TSkeletonSoldierMon.Create;
    69: actor := TSkeletonArcherMon.Create;
    70: actor := TBanyaGuardMon.Create;           //¹Ý¾ß¿ì»ç
    71: actor := TBanyaGuardMon.Create;           //¹Ý¾ßÁÂ»ç
    72: actor := TBanyaGuardMon.Create;           //»ç¿ìÃµ¿Õ
    // 2003/07/15 °ú°ÅºñÃµ ¸÷ Ãß°¡
    73: actor := TPBOMA1Mon.Create;               //ºñÀÍ¿À¸¶
    74: actor := TCatMon.Create;                  //¿À¸¶°Ëº´/Âüº´/ÁßÀ§º´/Ä£À§º´
    75: actor := TStoneMonster.Create;            //¸¶°è¼®1
    76: actor := TSuperiorGuard.Create;           //°ú°ÅºñÃµ°æºñ
    77: actor := TStoneMonster.Create;            //¸¶°è¼®2
    78: actor := TBanyaGuardMon.Create;           //ÆÄÈ²¸¶½Å
    79: actor := TPBOMA6Mon.Create;               //¿À¸¶¼®±Ãº´
    80, 96: actor := TMineMon.Create;             //µµ±úºñºÒ

    81: actor := TAngel.Create;                   //¿ù·É(Ãµ³à)
    83: actor := TFireDragon.Create;              //ÆÄÃµ¸¶·æ
    84,85,86,87,88,89: actor := TDragonStatue.Create; //¿ë¼®»ó
    90: actor := TDragonBody.Create;              //ÆÄÃµ¸¶·æ Åõ¸í¸ö
    91: actor := TBanyaGuardMon.Create;           //¼³ÀÎ´ëÃæ
    92: actor := TJumaThunderMon.Create;          //ÁÖ¸¶°Ý·ÚÀå  TSculptureMon »ó¼Ó¹ÞÀ½
    93: actor := TBanyaGuardMon.Create;           //È¯¿µÇÑÈ£
    94: actor := TBanyaGuardMon.Create;           //°Å¹Ì(½Å¼®µ¶¸¶ÁÖ)
    95: actor := TGasKuDeGi.Create;               //ÀÌº¥Æ®³ª¹æ 96:²É´« 97:º¸¹°ÇÔ

    98: actor := TWallStructure.Create;
    99: actor := TCastleDoor.Create;              //¼º¹®...

    100: actor := TBanyaGuardMon.Create;          //È²±ÝÀÌ¹«±â
    101: actor := TCatMon.Create;                 //¹é»ç(Ã»¿µ»ç)
    102: actor := TSkeletonArcherMon.Create;      //±Ã¼öÈ£À§º´  #####
    103: actor := TBanyaGuardMon.Create;          //Àü»çºñ¿ù¿©¿ì
    104: actor := TBanyaGuardMon.Create;          //¼ú»çºñ¿ù¿©¿ì
    105: actor := TBanyaGuardMon.Create;          //µµ»çºñ¿ù¿©¿ì
    106: actor := TCentipedeKingMon.Create;       //È£È¥¼®
    107: actor := TBanyaGuardMon.Create;          //È£È¥±â¼®
    108: actor := TBanyaGuardMon.Create;          //È£±â¿¬(¼Ò)
    109: actor := TBanyaGuardMon.Create;          //È£±â¿¬(´ë)
    110: actor := TFireDragon.Create;             //ºñ¿ùÃµÁÖ
    111,112: actor := TDualAxeOma.Create;         //ºñ¿ù´ÙÅ©
    113,114: actor := TCatMon.Create;             //Ä¡Ãæ
    // 115 È£¹Ú±«¹°
    116: actor := TCatMon.Create;                 //°©¼®±Í¼ö
    117: actor := TBanyaGuardMon.Create;          //°©Ã¶±Í¼ö
    118: actor := TFireDragon.Create;             //Çö¹«Çö½Å
    119: actor := TKillingHerb.Create;            //¶±
  else actor := TActor.Create;
  end;

  with actor do begin
    RecogId := chrid;
    XX := cx;
    YY := cy;
    rx := XX;
    ry := YY;
    Dir := cdir;
    Feature := cfeature;
    Race := RACEfeature(cfeature);
    hair := HAIRfeature(cfeature);
    dress := DRESSfeature(cfeature);
    weapon := WEAPONfeature(cfeature);
    Appearance := APPRfeature(cfeature);

    pm := RaceByPM(Race, Appearance);
    if pm <> nil then
      WalkFrameDelay := pm.ActWalk.ftime;

    if Race = 0 then begin
      Sex := Dress mod 2;   //0:³²ÀÚ 1:¿©ÀÚ
    end
    else
      Sex := 0;
    State := cstate;
    Saying[0] := '';
  end;
  ActorList.Add(actor);
  Result := actor;
end;

procedure TPlayScene.ActorDied(actor: TObject);
var
  i: integer;
  flag: Boolean;
begin
  for i := 0 to ActorList.Count - 1 do
    if ActorList[i] = actor then begin
      ActorList.Delete(i);
      break;
    end;
  flag := FALSE;
  for i := 0 to ActorList.Count - 1 do
    if not TActor(ActorList[i]).Death then begin
      ActorList.Insert(i, actor);
      flag := TRUE;
      break;
    end;
  if not flag then
    ActorList.Add(actor);
end;

procedure TPlayScene.SetActorDrawLevel(actor: TObject; level: integer);
var
  i: integer;
begin
  if level = 0 then begin
    for i := 0 to ActorList.Count - 1 do
      if ActorList[i] = actor then begin
        ActorList.Delete(i);
        ActorList.Insert(0, actor);
        break;
      end;
  end;
end;

procedure TPlayScene.ClearActors;
var
  i: integer;
begin
  for i := 0 to ActorList.Count - 1 do
    TActor(ActorList[i]).Free;
  ActorList.Clear;
  Myself := nil;
  TargetCret := nil;
  FocusCret := nil;
  MagicTarget := nil;

  for i := 0 to EffectList.Count - 1 do
    TMagicEff(EffectList[i]).Free;
  EffectList.Clear;
end;

function TPlayScene.DeleteActor(id: integer): TActor;
var
  i: integer;
begin
  Result := nil;
  i := 0;
  while TRUE do begin
    if i >= ActorList.Count then break;
    if TActor(ActorList[i]).RecogId = id then begin
      if TargetCret = TActor(ActorList[i]) then
        TargetCret := nil;
      if FocusCret = TActor(ActorList[i]) then
        FocusCret := nil;
      if MagicTarget = TActor(ActorList[i]) then
        MagicTarget := nil;
      TActor(ActorList[i]).DeleteTime := GetTickCount;
      FreeActorList.Add(ActorList[i]);
         //TActor(ActorList[i]).Free;
      ActorList.Delete(i);
    end
    else
      Inc(i);
  end;
end;

procedure TPlayScene.DelActor(actor: TObject);
var
  i: integer;
begin
  for i := 0 to ActorList.Count - 1 do
    if ActorList[i] = actor then begin
      TActor(ActorList[i]).DeleteTime := GetTickCount;
      FreeActorList.Add(ActorList[i]);
      ActorList.Delete(i);
      break;
    end;
end;

function TPlayScene.ButchAnimal(x, y: integer): TActor;
var
  i: integer;
  a: TActor;
begin
  Result := nil;
  for i := 0 to ActorList.Count - 1 do begin
    a := TActor(ActorList[i]);
    if a.Death and (a.Race <> 0) then begin //µ¿¹° ½ÃÃ¼
      if (abs(a.XX - x) <= 1) and (abs(a.YY - y) <= 1) then begin
        Result := a;
        break;
      end;
    end;
  end;
end;

{------------------------- Msg -------------------------}
procedure TPlayScene.SendMsg(ident, chrid, x, y, cdir, feature, state, param: integer; str: string);
var
  actor: TActor;
  meff: TMagicEff;
  bgm: string;
begin
  case ident of
    SM_TEST:
      begin
        actor := NewActor(111, 254{x}, 214{y}, 0, 0, 0);
        Myself := THumActor(actor);
        Map.LoadMap('0', Myself.XX, Myself.YY);
      end;
    SM_CHANGEMAP, SM_NEWMAP:
      begin
        Map.LoadMap(str, x, y);
        DarkLevel := cdir;
        //DayBright_fake := msg.Param;

        DarkLevel_fake := cdir;
        pDarkLevelCheck^ := cdir;

        BackgroundShow := FALSE;
        if str = 'ID1_001' then BackgroundShow := TRUE;
        if str = 'ID1_002' then BackgroundShow := TRUE;
        if str = 'ID1_003' then BackgroundShow := TRUE;
        if str = 'ID2_001' then BackgroundShow := TRUE;
        if str = 'ID2_002' then BackgroundShow := TRUE;
        if str = 'ID2_003' then BackgroundShow := TRUE;

        if DarkLevel = 0 then
          ViewFog := False
        else
          ViewFog := True;

        if (ident = SM_NEWMAP) and (MySelf <> nil) then begin  //¼­¹öÀÌµ¿ ÇÒ¶§ ºÎµå·´°Ô ¸ÊÀÌµ¿À» ÇÏ°Ô ¸¸µé·Á°í
          MySelf.XX := x;
          MySelf.YY := y;
          MySelf.RX := x;
          MySelf.RY := y;
          DelActor(MySelf);
        end;

        //BoViewMiniMap := FALSE;
        if BoWantMiniMap then begin
          FrmDlg.DMiniMapDlg.Visible:= False;
//               if ViewMiniMapStyle > 0 then
//                  PrevVMMStyle := ViewMiniMapStyle;
//               ViewMiniMapStyle := 0;
          FrmMain.SendWantMiniMap;
        end;

        if ViewGeneralMapStyle > 0 then FrmMain.SendWantMiniMap;


        bgm := SoundManager.FindBgmList(str);
        if bgm <> '' then PlayBGMEx ('Sound\'+bgm)
        else ClearBGM();
      end;
    SM_LOGON:
      begin
        actor := FindActor (chrid);
        if actor = nil then begin
          actor := NewActor (chrid, x, y, Lobyte(cdir), feature, state);
          actor.ChrLight := Hibyte(cdir);
          cdir := Lobyte(cdir);
          actor.SendMsg (SM_TURN, x, y, cdir, feature, state, '', 0);
        end;
        if Myself <> nil then begin
          Myself := nil;
        end;
        Myself := THumActor (actor);
      end;
    SM_HIDE:
      begin
        actor := FindActor(chrid);
        if actor <> nil then begin
          if actor.BoDelActionAfterFinished then begin //¶¥À¸·Î »ç¶óÁö´Â ¾Ö´Ï¸ÞÀÌ¼ÇÀÌ ³¡³ª¸é ÀÚµ¿À¸·Î »ç¶óÁü.
            exit;
          end;
          if actor.WaitForRecogId <> 0 then begin  //º¯½ÅÁß.. º¯½ÅÀÌ ³¡³ª¸é ÀÚµ¿À¸·Î »ç¶óÁü
            exit;
          end;
        end;
        DeleteActor(chrid);
      end;
  else
    begin
      actor := FindActor (chrid);
      if (ident=SM_TURN) or (ident=SM_RUN) or (ident=SM_WALK) or
         (ident=SM_BACKSTEP) or
         (ident = SM_DEATH) or (ident = SM_SKELETON) or
         (ident = SM_DIGUP) or (ident = SM_ALIVE) then
      begin
        if actor = nil then
          actor := NewActor (chrid, x, y, Lobyte(cdir), feature, state);

        if actor <> nil then begin
          actor.ChrLight := Hibyte(cdir);
          cdir := Lobyte(cdir);
          if ident = SM_SKELETON then begin
            actor.Death := TRUE;
            actor.Skeleton := TRUE;
          end
          else if ident = SM_ALIVE then begin  //2005/05/11 ºÎÈ° //####
            actor.Feature := feature;
            actor.FeatureChanged;
            if DarkLevel = 0 then ViewFog := FALSE
            else ViewFog := TRUE;
            actor.Death := False;
            actor.Skeleton := False;
          end;
        end;
      end;

      if actor = nil then exit;
      case ident of
        SM_FEATURECHANGED:
          begin
            actor.Feature := feature;
            actor.FeatureChanged;
          end;
        SM_CHARSTATUSCHANGED:
          begin
            actor.State := feature;
            actor.HitSpeed := state;
            if actor = MySelf then begin
              ChangeWalkHitValues (Myself.Abil.Level
                       , Myself.HitSpeed
                       , Myself.Abil.Weight + Myself.Abil.MaxWeight
                       + Myself.Abil.WearWeight + Myself.Abil.MaxWearWeight
                       + Myself.Abil.HandWeight + Myself.Abil.MaxHandWeight
                       , RUN_STRUCK_DELAY
                                   );
//                        if Myself.State and $10000000 <> 0 then begin        //POISON_STUN
//                           DizzyDelayStart := GetTickCount;
//                           DizzyDelayTime  := 1500; //µô·¹ÀÌ
//                        end;
            end;
                     // 2003/07/15 ½ºÅÏ¿¡ ´ëÇÑ »óÅÂÀÌ»ó ÀÌÆåÆ® Ãß°¡
            if feature and $10000000 <> 0 then begin        //POISON_STUN
              meff := TCharEffect.Create(380, 6, actor);
              meff.NextFrameTime := 100;
              meff.ImgLib := g_WMagicEx[1];
              meff.RepeatUntil := GetTickCount + 2000;
              EffectList.Add(meff);
            end;
          end;
      else
        begin
          if ident = SM_TURN then begin
            if str <> '' then
              actor.UserName := str;
          end;
          if ident = SM_WALK then begin
            if param > 0 then
              actor.WalkFrameDelay := param;
          end;
          actor.SendMsg(ident, x, y, cdir, feature, state, '', 0);
        end;
      end;
    end;
  end;
end;

end.
