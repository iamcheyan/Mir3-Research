unit SoundUtil;

interface

uses
  Windows, Messages, SysUtils, Classes, Graphics, Controls, Forms, Dialogs,
  Grobal2, ExtCtrls, HUtil32, HGESounds, Bass;

type
  TBGMState = (bgmPlay, bgmStop, bgmPause);

  TBGMList   = class;
  TSoundList = class;

  TFileHeader = packed record
    Titel: array[0..39] of char;
    TargetDir: array[0..9] of char;
    FieldCount: Cardinal;
    ListCount: Cardinal;
  end;

  TBGMListPart = packed record
    Start: array[0..0] of char;
    MapName: array[0..8] of char;
    FileName: array[0..13] of char;
  end;

  TSoundListPart = packed record
    SoundID: Word;
    SoundFile: array[0..13] of char;
  end;

  TSoundManager = class(TThread)
    m_UserCriticalSection: TRTLCriticalSection;
    m_SoundList: TStringList;
    m_SoundTempList: TStringList;
    m_sFileName: string;
    m_DXSound: TDXSound;
    m_Sound: TSoundEngine;
    m_boSound: Boolean;
  private
    { Private declarations }
    FSoundList : TSoundList;
    FBGMList   : TBGMList;
    procedure Run;
    function GetInitialized: Boolean;
  protected
    procedure Execute; override;
  public
    constructor Create(AOwner: TComponent);
    destructor Destroy; override;
    procedure PlayBGM(const sFileName: string);
    procedure PlaySound(const sFileName: string);
    procedure Initialize;
    procedure Clear;
    property Initialized: Boolean read GetInitialized;
    function FindBgmList(AMapName: String): String;
  end;

  TBGMList = class
  private
    FFileHeader : TFileHeader;
    FListItem   : array of TBGMListPart;
    FFieldCount : Cardinal;
    FListCount  : Cardinal;
    FFileSize   : Cardinal;
  private
    procedure AutoCorrectFile;
    procedure ReOrderList;
  public
    destructor Destroy; override;
    function LoadListFile(AFileName: String): Boolean;
  end;

  TSoundList = class
  private
    FHasInfoHeader : Boolean;
    FFileHeader    : TFileHeader;
    FListItem      : array of TSoundListPart;
    FFieldCount    : Cardinal;
    FListCount     : Cardinal;
    FFileSize      : Cardinal;
  private
    procedure AutoCorrectFile(ATestPoint: Integer);
    procedure ReOrderList;
  public
    destructor Destroy; override;
    function LoadListFile(AFileName: String): Boolean;
  end;

var
  CurVolume: integer;
  MusicStream: TMemoryStream;
  MusicHS: HSTREAM;

procedure PlaySound (idx: integer);
procedure PlaySoundEx (wavname: string);
function  PlayBGM (wavname: string): TDirectSoundBuffer;
procedure SilenceSound;
procedure ItemClickSound (std: TStdItem);
procedure ItemUseSound (stdmode: integer);
procedure PlayBGMEx (wavname: string);
procedure ClearBGM();
procedure ChangeBGMState(BGMState: TBGMState);

const
  bmg_intro            = 'Sound\Opening.wav';
  bmg_select           = 'Sound\SelChr.wav';
  bmg_field            = 'wav\Field2.wav';
  bmg_gameover         = 'wav\game-over2.wav';

  s_walk_ground_l      = 1;
  s_walk_ground_r      = 2;
  s_run_ground_l       = 3;
  s_run_ground_r       = 4;
  s_walk_stone_l       = 5;
  s_walk_stone_r       = 6;
  s_run_stone_l        = 7;
  s_run_stone_r        = 8;
  s_walk_lawn_l        = 9;
  s_walk_lawn_r        = 10;
  s_run_lawn_l         = 11;
  s_run_lawn_r         = 12;
  s_walk_rough_l       = 13;
  s_walk_rough_r       = 14;
  s_run_rough_l        = 15;
  s_run_rough_r        = 16;
  s_walk_wood_l        = 17;
  s_walk_wood_r        = 18;
  s_run_wood_l         = 19;
  s_run_wood_r         = 20;
  s_walk_cave_l        = 21;
  s_walk_cave_r        = 22;
  s_run_cave_l         = 23;
  s_run_cave_r         = 24;
  s_walk_room_l        = 25;
  s_walk_room_r        = 26;
  s_run_room_l         = 27;
  s_run_room_r         = 28;
  s_walk_water_l       = 29;
  s_walk_water_r       = 30;
  s_run_water_l        = 31;
  s_run_water_r        = 32;

  s_hit_short          = 50;
  s_hit_wooden         = 51;
  s_hit_sword          = 52;
  s_hit_do             = 53;
  s_hit_axe            = 54;
  s_hit_club           = 55;
  s_hit_long           = 56;
  s_hit_fist           = 57;

  s_struck_short       = 60;
  s_struck_wooden      = 61;
  s_struck_sword       = 62;
  s_struck_do          = 63;
  s_struck_axe         = 64;
  s_struck_club        = 65;

  s_struck_body_sword  = 70;
  s_struck_body_axe    = 71;
  s_struck_body_longstick = 72;
  s_struck_body_fist   = 73;

  s_struck_armor_sword = 80;
  s_struck_armor_axe   = 81;
  s_struck_armor_longstick = 82;
  s_struck_armor_fist  = 83;

  //s_powerup_man         = 80;
  //s_powerup_woman       = 81;
  //s_die_man             = 82;
  //s_die_woman           = 83;
  //s_struck_man          = 84;
  //s_struck_woman        = 85;
  //s_firehit             = 86;

  //s_struck_magic        = 90;
  s_strike_stone        = 91;
  s_drop_stonepiece     = 92;

  s_rock_door_open     = 100;
  s_intro_theme        = 102;
  s_meltstone          = 101;
  s_main_theme         = 102;
  s_norm_button_click  = 103;
  s_rock_button_click  = 104;
  s_glass_button_click = 105;
  s_money              = 106;
  s_eat_drug           = 107;
  s_click_drug         = 108;
  s_spacemove_out      = 109;
  s_spacemove_in       = 110;

  s_click_weapon       = 111;
  s_click_armor        = 112;
  s_click_ring         = 113;
  s_click_armring      = 114;
  s_click_necklace     = 115;
  s_click_helmet       = 116;
  s_click_grobes       = 117;
  s_itmclick           = 118;

  s_deal_additem       = 125;
  s_deal_delitem       = 126;

  s_yedo_man           = 130;
  s_yedo_woman         = 131;
  s_longhit            = 132;
  s_widehit            = 133;
  s_rush_l             = 134;
  s_rush_r             = 135;
  s_firehit_ready      = 136;
  s_firehit            = 137;

  s_crosshit           = 140;
  s_twinhit            = 141;

  s_man_struck     = 138;
  s_wom_struck     = 139;
  s_man_die        = 144;
  s_wom_die        = 145;


implementation

uses
   ClMain, cliUtil;

var
  OldBGName: string = '';
  OldBGIndex: Integer = -1;

constructor TSoundManager.Create(AOwner: TComponent);
begin
  inherited Create(False);
  InitializeCriticalSection(m_UserCriticalSection);
  m_SoundList := TStringList.Create;
  m_SoundTempList := TStringList.Create;
  m_DXSound := TDXSound.Create(AOwner);
  m_Sound := nil;
  m_boSound := True;

  FSoundList := TSoundList.Create;
  FSoundList.LoadListFile('.\SoundList.wwl');
  FBGMList   := TBGMList.Create;
  FBGMList.LoadListFile('.\BgmList.wwl');
  //  FreeOnTerminate:=True;
end;

destructor TSoundManager.Destroy;
begin
  FreeAndNil(FSoundList);
  FreeAndNil(FBGMList);
  m_SoundList.Free;
  m_SoundTempList.Free;
  if m_Sound <> nil then m_Sound.Free;
  m_DXSound.Free;
  DeleteCriticalSection(m_UserCriticalSection);
  inherited Destroy;
end;

procedure TSoundManager.Execute;
begin
  while not Terminated do begin
    try
      Run();
    except

    end;
    Sleep(1);
  end;
end;

procedure TSoundManager.Initialize;
begin
  try
    m_DXSound.Initialize;
  except
  end;
  if m_DXSound.Initialized then begin
    m_Sound := TSoundEngine.Create(m_DXSound.DSound);
  end;
end;

procedure TSoundManager.Run;
var
  I: Integer;
begin
  EnterCriticalSection(m_UserCriticalSection);
  try
    m_SoundTempList.Clear;
    m_SoundTempList.AddStrings(m_SoundList);
    m_SoundList.Clear;
    if (m_Sound <> nil) and m_boSound then begin
      for I := 0 to m_SoundTempList.Count - 1 do begin
        if (m_SoundTempList[I] <> '') and ((GetTickCount - LongWord(m_SoundTempList.Objects[I])) < 100) then begin
          if FileExists(m_SoundTempList[I]) then begin
            try
              Sleep(10);
              m_Sound.EffectFile(m_SoundTempList[I], False, False);
            except
            end;
          end;
        end;
      end;
    end;
  finally
    LeaveCriticalSection(m_UserCriticalSection);
  end;
end;

function TSoundManager.GetInitialized: Boolean;
begin
  Result := m_DXSound.Initialized;
end;

procedure TSoundManager.PlayBGM(const sFileName: string);
begin
  if (m_Sound <> nil) and FileExists(sFileName) then begin
    try
      m_Sound.EffectFile(sFileName, True, False);
    except
    end;
  end;
end;

procedure TSoundManager.Clear;
begin
  m_SoundList.Clear;
  if m_Sound <> nil then begin
    m_Sound.Clear;
  end;
end;

procedure TSoundManager.PlaySound(const sFileName: string);
begin
  EnterCriticalSection(m_UserCriticalSection);
  try
    if m_SoundList.Count > 0 then begin
      m_SoundList.InsertObject(0, sFileName, TObject(GetTickCount));
    end else begin
      m_SoundList.AddObject(sFileName, TObject(GetTickCount));
    end;
  finally
    LeaveCriticalSection(m_UserCriticalSection);
  end;
end;

function TSoundManager.FindBgmList(AMapName: string): string;
var
  I : Integer;
begin
  Result := '';
  for I := 0 to FBGMList.FFileHeader.ListCount - 1 do
  begin
    if (Trim(FBGMList.FListItem[I].MapName) = Trim(AMapName)) then
    begin
      Result := Trim(FBGMList.FListItem[I].FileName);
      break;
    end;
  end;
end;


{ TBGMList }
destructor TBGMList.Destroy;
begin
  ZeroMemory(@FFileHeader, SizeOf(TFileHeader));
  SetLength(FListItem, 0);
  FListItem := nil;
  inherited;
end;

{ Private }
procedure TBGMList.AutoCorrectFile;
var
  FFileItems : Cardinal;
begin
  // Test and Correct the List Count Information
  FFileItems             := Round(FFileSize / SizeOf(TBGMListPart));
  FFileHeader.ListCount  := FFileItems;
  FFileHeader.FieldCount := FFileItems;
end;

procedure TBGMList.ReOrderList;
var
  I, FCount : Integer;
  FTempList : array of TBGMListPart;
begin
  try
    FCount := 0;
    for I := 0 to FFileHeader.ListCount - 1 do
    begin
      if (FListItem[I].MapName <> '') and (FListItem[I].FileName <> '') then
      begin
        Inc(FCount);
        SetLength(FTempList, FCount);
        FTempList[FCount - 1].Start    := '[';
        FTempList[FCount - 1].MapName  := FListItem[I].MapName;
        FTempList[FCount - 1].FileName := FListItem[I].FileName;
      end;
    end;
    SetLength(FListItem, 0);
    SetLength(FListItem, FCount);
    CopyMemory(@FListItem[0], @FTempList[0], FCount * SizeOf(TBGMListPart));
    SetLength(FTempList, 0);
    FFileHeader.ListCount  := FCount;
    FFileHeader.FieldCount := FCount;
  except
    { Add Error }
  end;
end;

function TBGMList.LoadListFile(AFileName: String): Boolean;
var
  FBool       : Boolean;
  FFileHandle : Cardinal;
  FReadSize   : Cardinal;
  FMemFile    : TMemoryStream;
begin
  Result := True;
  try
    // Read Sound List File --------------------------------
    FFileHandle := CreateFile(PChar(AFileName), GENERIC_READ, FILE_SHARE_READ, nil, OPEN_EXISTING,FILE_ATTRIBUTE_NORMAL, 0);
    if FFileHandle <> 0 then
    begin
      FFileSize := GetFileSize(FFileHandle, nil) - SizeOf(TFileHeader);
      // Read File Header ----------------------------
      ZeroMemory(@FFileHeader, SizeOf(TFileHeader));
	    ReadFile(FFileHandle, FFileHeader, SizeOf(TFileHeader), FReadSize, nil);

      // Automatic check and correct List and field Count information -
      AutoCorrectFile;

      // Read File Items -----------------------------
      SetLength(FListItem, FFileHeader.FieldCount);
      ZeroMemory(@FListItem[0], FFileHeader.FieldCount * SizeOf(TBGMListPart) - 1);
      ReadFile(FFileHandle, FListItem[0], FFileHeader.FieldCount * SizeOf(TBGMListPart) - 1, FReadSize, nil);

      FFieldCount := FFileHeader.FieldCount;
      FListCount  := FFileHeader.ListCount;

      CloseHandle(FFileHandle);
    end;
    ReOrderList;
  except
    Result := False;
  end;
end;

{ TSoundList }
destructor TSoundList.Destroy;
begin
  ZeroMemory(@FFileHeader, SizeOf(TFileHeader));
  SetLength(FListItem, 0);
  FListItem := nil;

  inherited;
end;

{ Private }
procedure TSoundList.AutoCorrectFile(ATestPoint: Integer);
var
  I          : Integer;
  FFileItems : Cardinal;
begin
  case ATestPoint of
    0:
    begin
      // Test and Correct the List Count Information
      FFileItems            := Round(FFileSize / SizeOf(TSoundListPart));
      FFileHeader.ListCount := FFileItems;
    end;

    1:
    begin
      // Test and Correct the Sound List Information Count
      FFileItems := 0;
      for I := 0 to FFileHeader.ListCount - 1 do
      begin
        if FListItem[I].SoundID = 0 then
          Inc(FFileItems);
      end;
      if FFileItems = 0 then
      begin
        FFileHeader.FieldCount := 0;
        FHasInfoHeader         := False;
      end else
      begin
        FFileHeader.FieldCount := FFileItems;
        FHasInfoHeader         := True;
      end;
    end;
  end;
end;

procedure TSoundList.ReOrderList;
var
  I, FCount : Integer;
  FTempList : array of TSoundListPart;
begin
  try
    FCount := 0;
    for I := 0 to FFileHeader.ListCount - 1 do
    begin
      if (FListItem[I].SoundFile <> '') then
      begin
        Inc(FCount);
        SetLength(FTempList, FCount);
        FTempList[FCount - 1].SoundID   := FListItem[I].SoundID;
        FTempList[FCount - 1].SoundFile := FListItem[I].SoundFile;
      end;
    end;
    SetLength(FListItem, 0);
    SetLength(FListItem, FCount);
    CopyMemory(@FListItem[0], @FTempList[0], FCount * SizeOf(TSoundListPart));
    SetLength(FTempList, 0);
    FFileHeader.ListCount  := FCount;
  except
  end;
end;

function TSoundList.LoadListFile(AFileName: String): Boolean;
var
  FBool       : Boolean;
  FFileHandle : Cardinal;
  FReadSize   : Cardinal;
  FMemFile    : TMemoryStream;
begin
  Result := True;
  try
    // Read Sound List File --------------------------------
    FFileHandle := CreateFile(PChar(AFileName), GENERIC_READ, FILE_SHARE_READ, nil, OPEN_EXISTING,FILE_ATTRIBUTE_NORMAL, 0);
    if FFileHandle <> 0 then
    begin
      FFileSize := GetFileSize(FFileHandle, nil) - SizeOf(TFileHeader);
      // Read File Header ----------------------------
      ZeroMemory(@FFileHeader, SizeOf(TFileHeader));
	    ReadFile(FFileHandle, FFileHeader, SizeOf(TFileHeader), FReadSize, nil);

      // Automatic check and correct List Count information -
      AutoCorrectFile(0);

      // Read File Items -----------------------------
      SetLength(FListItem, FFileHeader.ListCount);
      ZeroMemory(@FListItem[0], FFileHeader.ListCount * SizeOf(TSoundListPart) - 1);
      ReadFile(FFileHandle, FListItem[0], FFileHeader.ListCount * SizeOf(TSoundListPart) - 1, FReadSize, nil);

      // Automatic check and correct Info Count information -
      AutoCorrectFile(1);

      FFieldCount := FFileHeader.FieldCount;
      FListCount  := FFileHeader.ListCount;

      CloseHandle(FFileHandle);
    end;
    ReOrderList;
  except
    Result := False;
  end;
end;

procedure PlaySound (idx: integer);
var
  I : Integer;
begin
  if g_boCanSound and (SoundManager.m_Sound.EffectCount < 500) then  begin
    if (idx <> 0) {and (idx < SoundManager.FSoundList.FFileHeader.ListCount)} then begin
//      DScreen.AddChatBoardString ('SoundManager.FSoundList.FFileHeader.ListCount=> '+ IntToStr(SoundManager.FSoundList.FFileHeader.ListCount), clYellow, clRed);
      for I := 0 to SoundManager.FSoundList.FFileHeader.ListCount - 1 do begin
        if SoundManager.FSoundList.FListItem[I].SoundID = idx then
        begin
          SoundManager.PlaySound('Sound\'+Trim(SoundManager.FSoundList.FListItem[I].SoundFile));
          break;
        end;
      end;
    end;
  end;
end;

{
procedure PlaySound (idx: integer);
begin
//   if (Sound <> nil) and BoPlaySoundEffect then  begin
//      if (idx >= 0) and (idx < SoundList.Count) then begin
//         if SoundList[idx] <> '' then
//            if FileExists (SoundList[idx]) then
//               try
//                  Sound.EffectFile(SoundList[idx], FALSE, FALSE);
//               except
//               end;
//      end;
//   end;
  if g_boCanSound and (MyPlaySound.m_Sound.EffectCount < 500) then  begin
    if (idx >= 0) and (idx < SoundList.Count) then begin
      if SoundList[idx] <> '' then
        if FileExists( SoundList[idx]) then
          try
            MyPlaySound.PlaySound(SoundList[idx]);
          except
          end;
    end;
  end;
end; }

procedure PlaySoundEx(wavname: string);
begin
  if g_boCanSound and (SoundManager.m_Sound.EffectCount < 500) then begin
    if wavname <> '' then begin
      if FileExists(wavname) then begin
        try
          SoundManager.PlaySound(wavname);
        except
        end;
      end;
    end;
  end;
end;

function PlayBGM(wavname: string): TDirectSoundBuffer;
begin
//   if Sound <> nil then  begin
//      if wavname <> '' then
//         if FileExists (wavname) then
//            try
//               Sound.EffectFile(wavname, TRUE, FALSE);
//            except
//            end;
//   end;
  if FileExists (wavname) and g_boCanSound then begin
    try
      SoundManager.PlaySound(wavname);
    except
    end;
  end;
end;

procedure SilenceSound;
begin
//   if Sound <> nil then  begin
//      Sound.Clear;
//   end;
  SoundManager.Clear;
end;

procedure ItemClickSound(std: TStdItem);
begin
  case std.StdMode of
    0:
      PlaySound(s_click_drug);
    5, 6:
      PlaySound(s_click_weapon);
    10, 11:
      PlaySound(s_click_armor);
    22, 23:
      PlaySound(s_click_ring);
    24, 26:
      begin
        if (pos('Àå°©', std.Name) > 0) or (pos('°©¹Ú', std.Name) > 0) then
          PlaySound(s_click_grobes)
        else
          PlaySound(s_click_armring);
      end;
    19, 20, 21:
      PlaySound(s_click_necklace);
    15:
      PlaySound(s_click_helmet);
  else
    PlaySound(s_itmclick);
  end;
end;

procedure ItemUseSound(stdmode: integer);
begin
  case stdmode of
    0:
      PlaySound(s_click_drug);
    1, 2:
      PlaySound(s_eat_drug);
  else
    ;
  end;
end;

procedure PlayBGMEx(wavname: string);
begin
  if (not g_boBGSound) or (g_btMP3Volume <= 0) then exit;
  if (OldBGName = wavname) and (MusicHS > 0) then begin
    if BASS_ChannelIsActive(MusicHS) <> BASS_ACTIVE_PLAYING then
      BASS_ChannelPlay(MusicHS, False);
      BASS_ChannelSetAttribute(MusicHS, BASS_ATTRIB_VOL, g_btMP3Volume / 100);
    exit;
  end;
  ClearBGM;
  Try
    MusicHS := BASS_StreamCreateFile(False, PAnsiChar(wavname), 0, 0, BASS_SAMPLE_LOOP);
    if MusicHS < BASS_ERROR_ENDED then begin
      BASS_StreamFree(MusicHS);
      MusicHS := 0;
      exit;
    end;
    OldBGName := wavname;
    BASS_ChannelPlay(MusicHS, True);
    BASS_ChannelSetAttribute(MusicHS, BASS_ATTRIB_VOL, g_btMP3Volume / 100);
  Except
    DebugOutStr('PlayBGM');
  End;
end;

procedure ClearBGM();
begin
  OldBGName := '';
  OldBGIndex := -1;
  BASS_StreamFree(MusicHS);
  MusicHS := 0;
end;

procedure ChangeBGMState(BGMState: TBGMState);
begin
  if MusicHS >= BASS_ERROR_ENDED then begin
    case BGMState of
      bgmPlay: BASS_ChannelPlay(MusicHS, False);
      bgmStop: BASS_ChannelStop(MusicHS);
      bgmPause: BASS_ChannelPause(MusicHS);
    end;
    BASS_ChannelSetAttribute(MusicHS, BASS_ATTRIB_VOL, 70 / 100);
  end;
end;

end.



