unit svMain;

interface


uses
  Windows, Messages, SysUtils, Classes, Graphics, Controls, Forms, Dialogs,
  ScktComp, RunSock, syncobjs, StdCtrls, ExtCtrls, FrnEngn, UsrEngn,
  Envir, IniFiles, itmunit, Magic, NoticeM, Guild, MudUtil, Event,
  Grobal2, FSrvValue, InterServerMsg, InterMsgClient, HUtil32, Buttons,
  M2Share, Castle, MfdbDef, ObjNpc , UserMgrEngn , DragonSystem,
  SQLEngn, DBSQL, EDcode, IdBaseComponent, IdComponent, IdUDPBase, IdUDPClient;

const
   ENGLISHVERSION = FALSE;    //이태리(유럽)
   PHILIPPINEVERSION = FALSE; //필리핀
   CHINAVERSION = FALSE;
   TAIWANVERSION = FALSE;
   KOREANVERSION = TRUE;      //한국

   SENDBLOCK: integer = 1024; //2048;  //게이트와 통신하기 때문에 블럭이 크다.
   SENDCHECKBLOCK: integer = 4096; //2048;      //캐크 신호를 보낸다.
   SENDAVAILABLEBLOCK: integer = 7999; //4096;  //캐크 신호가 없어도 이정도는 보낸다.
   GATELOAD: integer = 10; //10KB
   LINENOTICEFILE = 'Notice\LineNotice.txt';
   LINEHELPFILE = 'Setup\LineHelp.txt';

   BUILDGUILDFEE: integer = 1000000;

type
  TFrmMain = class(TForm)
    GateSocket: TServerSocket;
    Memo1: TMemo;
    Timer1: TTimer;
    RunTimer: TTimer;
    DBSocket: TClientSocket;
    ConnectTimer: TTimer;
    StartTimer: TTimer;
    Panel1: TPanel;
    SaveVariableTimer: TTimer;
    LbRunTime: TLabel;
    TCloseTimer: TTimer;
    LbUserCount: TLabel;
    Label1: TLabel;
    Label2: TLabel;
    Label3: TLabel;
    Panel2: TPanel;
    SpeedButton1: TSpeedButton;
    Label4: TLabel;
    LogUDP: TIdUDPClient;
    LbTimeCount: TLabel;
    Label5: TLabel;
    ConAlarmUDP: TIdUDPClient;
    procedure GateSocketClientConnect(Sender: TObject;
      Socket: TCustomWinSocket);
    procedure GateSocketClientDisconnect(Sender: TObject;
      Socket: TCustomWinSocket);
    procedure GateSocketClientError(Sender: TObject;
      Socket: TCustomWinSocket; ErrorEvent: TErrorEvent;
      var ErrorCode: Integer);
    procedure GateSocketClientRead(Sender: TObject;
      Socket: TCustomWinSocket);
    procedure FormCreate(Sender: TObject);
    procedure FormDestroy(Sender: TObject);
    procedure Timer1Timer(Sender: TObject);
    procedure RunTimerTimer(Sender: TObject);
    procedure ConnectTimerTimer(Sender: TObject);
    procedure DBSocketConnect(Sender: TObject; Socket: TCustomWinSocket);
    procedure DBSocketDisconnect(Sender: TObject;
      Socket: TCustomWinSocket);
    procedure DBSocketError(Sender: TObject; Socket: TCustomWinSocket;
      ErrorEvent: TErrorEvent; var ErrorCode: Integer);
    procedure DBSocketRead(Sender: TObject; Socket: TCustomWinSocket);
    procedure FormCloseQuery(Sender: TObject; var CanClose: Boolean);
    procedure StartTimerTimer(Sender: TObject);
    procedure SaveVariableTimerTimer(Sender: TObject);
    procedure TCloseTimerTimer(Sender: TObject);
    procedure Panel1DblClick(Sender: TObject);
    procedure SpeedButton1Click(Sender: TObject);
  private
    procedure MakeStoneMines;
    procedure StartServer;
    procedure OnProgramException (Sender: TObject; E: Exception);
    function LoadClientFileCheckSum: Boolean;
  public
    procedure SaveItemNumber;
    procedure RefreshForm;
  end;


procedure MainOutMessage (str: string);
procedure AddUserLog (str: string);  //플래이어의 행동을 기록
procedure AddUserConAlarmLog (str: string);
procedure AddConLog (str: string);  //접속 기록을 로그로 남김
procedure AddChatLog (str: string);  //채팅 기록을 로그로 남김
function  GetCertifyNumber: integer;
function  GetItemServerIndex: integer;
function  DBConnected: Boolean;
procedure LoadMultiServerTables;
function  GetMultiServerAddrPort (servernum: byte; var addr: string; var port: integer): Boolean;
function  GetUnbindItemName (shape: integer): string;
function  LoadLineNotice (flname: string): Boolean;
function  LoadLineHelp (flname: string): Boolean;
function  GetStartPointMapName (index: integer): string;
function  DecodeStringPassword( var src: string; key: integer ): string;


var
  FrmMain: TFrmMain;
  RunSocket: TRunSocket;
  FrontEngine: TFrontEngine;
  UserEngine: TUserEngine;
  UserMgrEngine : TUserMgrEngine;
  GrobalEnvir: TEnvirList;
  ItemMan: TItemUnit;
  MagicMan: TMagicManager;
  NoticeMan: TNoticeManager;
  GuildMan: TGuildManager;
  GuildAgitMan: TGuildAgitManager;  //문파장원(sonmg)
  GuildAgitBoardMan: TGuildAgitBoardManager;  //장원게시판(sonmg)
  GuildAgitStartNumber: integer;   //문파장원 시작번호(MapInfo에서 읽어옴).
  GuildAgitMaxNumber: integer;   //문파장원 최대개수(MapInfo에서 읽어옴).
  EventMan: TEventManager;
  UserCastle: TUserCastle;
  boUserCastleInitialized : Boolean;
  gFireDragon: TDragonSystem;

  DecoItemList: TStringList;  //장원꾸미기
  MakeItemList: TStringList;  // list of TStringList;
  MakeItemIndexList: TStringList;  // 제조 아이템 구분 Index 리스트.
  StartPoints: TStringList;
  SafePoints: TStringList;
  MultiServerList: TList;
  ShutUpList: TQuickList; //채팅금지 리스트
  MiniMapList: TStringList;
  UnbindItemList: TStringList;
  LineNoticeList: TStringList;
  LineHelpList: TStringList;
  QuestDiaryList: TList;  //list of TList of TList(PTQDDinfo)
                                      //TQDDinfo // [n] index or unit index
                                                 // TStringList
  StartupQuestNpc: TMerchant;


  EventItemList: TStringList;   //유니크 아이템 이벤트를 위한 리스트
  EventItemGifeBaseNumber: integer;
  GrobalQuestParams: array[0..9] of integer;

  ErrorLogFile: string;
  MirDayTime: integer;  //미르의 시간... 현실 시간의 2배 빠름
  ServerIndex: integer;
  ServerName: string;
  ServerNumber: integer;

  BoVentureServer: Boolean;
  BoTestServer: Boolean;
  BoClientTest: Boolean;
  TestLevel: integer;
  TestGold: integer;
  TestServerMaxUser: integer;
  BoServiceMode: Boolean;
  BoNonPKServer: Boolean;
  BoViewHackCode: Boolean;
  BoViewAdmissionfail: Boolean;
  BoGetGetNeedNotice: Boolean;
  GetGetNoticeTime: longword;

  UserFullCount: integer;
  ZenFastStep: integer;
  BoSysHasMission: Boolean;    //이벤트용, 미션이 있는지
  SysMission_Map: string;
  SysMission_X: integer;
  SysMission_Y: integer;
  TotalUserCount: integer;  //전서버를 통털은 사용자수

  csMsgLock: TCriticalSection;
  csTimerLock: TCriticalSection;
  csObjMsgLock: TCriticalSection;
  csSendMsgLock: TCriticalSection;
  csShare: TCriticalSection;  //동기화 시간이 ?은 공유변수에 사용해야 함.
  csDelShare: TCriticalSection;  //동기화 시간이 ?은 공유변수에 사용해야 함.
  csSocLock: TCriticalSection;
  usLock: TCriticalSection;   //user engine thread
  usIMLock: TCriticalSection;   //user engine thread
  ruLock: TCriticalSection;   // run sock
  ruSendLock: TCriticalSection;   // run sock
  ruCloseLock: TCriticalSection;   // run sock
  socstrLock: TCriticalSection;
  fuLock: TCriticalSection;   //front engine thread
  fuOpenLock: TCriticalSection;   //front engine thread
  fuCloseLock: TCriticalSection;   //front engine thread
  humanLock: TCriticalSection;   // human sendbufer
  umLock: TCriticalSection;   //User Manager engine thread
  SQLock: TCriticalSection;   // SQL Engine Thread

  MainMsg: TStringList;
  UserLogs: TStringList;  //플래이어의 행동 로그
  UserConAlarmLogs: TStringList;  //특정 행동 유저의 접속/행동 로그
  UserConLogs: TStringList;  //접속 로그
  UserChatLog: TStringList;  //채팅 로그
  DiscountForNightTime: Boolean;
  HalfFeeStart: integer;  //할인시간 시작
  HalfFeeEnd: integer;   //할인시간 끝

  ServerReady: Boolean;       //서버가 사용자를 받을 준비가 되었는가?
  ServerClosing: Boolean;
  FCertify, FItemNumber: integer;
  RDBSocData: string;
  ReadyDBReceive: Boolean;
  RunFailCount: integer;
  MirUserLoadCount: integer;
  MirUserSaveCount: integer;
  CurrentDBloadingTime: longword;
  BoEnableAbusiveFilter: Boolean;
  LottoSuccess, LottoFail: integer;
  Lotto1, Lotto2, Lotto3, Lotto4, Lotto5, Lotto6: integer;

  MsgServerAddress: string;
  MsgServerPort: integer;
  LogServerAddress: string;
  LogServerPort: integer;
  ShareBaseDir: string;
  ShareVentureDir: string;
  ShareFileNameNum: integer;
  ConLogBaseDir: string;  //접속 시간 로그
  ChatLogBaseDir: string;  //접속 시간 로그

  EmergencyMap: string;
  EmergencyX: integer;
  EmergencyY: integer;

  DefHomeMap: array[0..2] of string;  //각 서버마다 꼭 있어야 하는 맵
  DefHomeX: array[0..2] of integer;
  DefHomeY: array[0..2] of integer;
  GuildDir: string;
  GuildFile: string;
  GuildBaseDir: string;
  GuildAgitFile: string;
  CastleDir: string;
  EnvirDir: string;
  MapDir: string;

  SqlDBLocal: string;
  SqlDBID: string;
  SqlDBPassword: string;
  SqlDBDSN: string;

  CurrentMonthlyCard: integer;    //월정액 사용자 수
  TotalTimeCardUsage: integer;  //시간제 카드 사용자의 사용 총 시간 //시간
  LastMonthTotalTimeCardUsage: integer;   //시간
  GrossTimeCardUsage: integer;    //시간
  GrossResetCount: integer;

  serverruntime: longword;
  runstart: longword;
  rcount: integer;
  minruncount: integer;
  curruncount: integer;
  maxsoctime: integer;
  cursoctime: integer;
  maxusrtime: integer;
  curusrcount: integer;
  curhumtime: integer;
  maxhumtime: integer;
  curmontime: integer;
  maxmontime: integer;
  humrotatetime: longword;
  curhumrotatetime: integer;
  maxhumrotatetime: integer;
  humrotatecount: integer;
  LatestGenStr: string[30];
  LatestMonStr: string[30];

  HumLimitTime: longword;
  MonLimitTime: longword;
  ZenLimitTime: longword;
  NpcLimitTime: longword;
  SocLimitTime: longword;
  DecLimitTime: longword;

  //이름들
  __ClothsForMan: string;
  __ClothsForWoman: string;
  __WoodenSword: string;
  __Candle: string;
  __BasicDrug: string;

  __GoldStone: string;
  __SilverStone: string;
  __SteelStone: string;
  __CopperStone: string;
  __BlackStone: string;
  __Gem1Stone: string;
  __Gem2Stone: string;
  __Gem3Stone: string;
  __Gem4Stone: string;

  __ZumaMonster1: string;
  __ZumaMonster2: string;
  __ZumaMonster3: string;
  __ZumaMonster4: string;

  __Bee             : string;
  __Spider          : string;
  __WhiteSkeleton   : string;
  __ShinSu          : string;
  __ShinSu1         : string;
  __AngelMob        : string;
  __CloneMob        : string;
  __WomaHorn        : string;
  __ZumaPiece       : string;

  __GoldenImugi     : string;
  __WhiteSnake      : string;


  ClientFileName1: string;
  ClientFileName2: string;
  ClientFileName3: string;
  ClientCheckSumValue1: integer;
  ClientCheckSumValue2: integer;
  ClientCheckSumValue3: integer;

  //디버깅 정보
  gErrorCount :integer;
  g_TestTime : integer;

  //스핵체크
  g_SpeedHackCheck : integer;
  g_SpeedHackCheckChar : string;

  //외치기 범위
  g_CryWide : integer;
  //현재 생성중인 Merchant Index
  CurrentMerchantIndex : integer;
  ServerTickDifference: longword;

  //아이템 인덱스 지정
  INDEX_CHOCOLATE: integer;  //초콜렛
  INDEX_CANDY: integer;      //사탕
  INDEX_LOLLIPOP: integer;   //막대사탕
  INDEX_MIRBOOTS: integer;   //천룡신행보
implementation

{$R *.DFM}

uses
   LocalDB, IdSrvClient;


function IntTo_Str (val: integer): string;
begin
   if val < 10 then Result := '0' + IntToStr(val)
   else Result := IntToStr(val);
end;

function  CheckFileCheckSum (flname: string): integer;
type
   pinteger = ^Integer;
var
   pbuf: PChar;
   i, n, handle, bsize, cval, csum: integer;
begin
   Result := 0;
   if FileExists (flname) then begin
      handle := FileOpen (flname, fmOpenRead or fmShareDenyNone);
      if handle > 0 then begin
         bsize := FileSeek (handle, 0, 2);
         GetMem (pbuf, (bsize+3) div 4 * 4);
         FillChar (pbuf^, (bsize+3) div 4 * 4, 0);
         FileSeek (handle, 0, 0);
         FileRead (handle, pbuf^, bsize);
         FileClose (handle);

         csum := 0;
         for i:=0 to (bsize+3) div 4 - 1 do begin
            cval := pinteger (pbuf)^;
            pbuf := PChar (integer(pbuf) + 4);
            csum := csum xor cval;
         end;

         Result := csum;
      end;
   end;
end;


procedure TFrmMain.RefreshForm;
begin
   Application.ProcessMessages;
end;

procedure TFrmMain.FormCreate(Sender: TObject);
var
   fname, str: string;
   ini: TIniFile;
   ayear, amon, aday, ahour, amin, asec, amsec: word;
   fhandle: TextFile;
   I: Integer;
begin
   gErrorCount := 0;
   Randomize;
   ServerIndex := 0;

   RunSocket := TRunSocket.Create;
   MainMsg := TStringList.Create;
   UserLogs := TStringList.Create;
   UserConAlarmLogs := TStringList.Create;
   UserConLogs := TStringList.Create;
   UserChatLog := TStringList.Create;
   GrobalEnvir := TEnvirList.Create;
   ItemMan := TItemUnit.Create;
   MagicMan := TMagicManager.Create;
   NoticeMan := TNoticeManager.Create;
   GuildMan := TGuildManager.Create;
   GuildAgitMan := TGuildAgitManager.Create; //문파장원(sonmg)
   GuildAgitBoardMan := TGuildAgitBoardManager.Create;  //장원게시판(sonmg)
   EventMan := TEventManager.Create;
   UserCastle := TUserCastle.Create;
   boUserCastleInitialized := FALSE;
   //용던전 시스템
   gFireDragon := TDragonSystem.Create;

   FrontEngine  := TFrontEngine.Create;
   UserEngine   := TUserEngine.Create;
   // 친구 쪽지 시스템
   UserMgrEngine:= TUserMgrEngine.Create;

   // DBSQL
   g_DBSQL   := TDBSQL.Create;
   SQLEngine := TSQLEngine.Create;


   DecoItemList := TStringList.Create;
   MakeItemList := TStringList.Create;
   MakeItemIndexList := TStringList.Create;
   StartPoints := TStringList.Create;
   SafePoints := TStringList.Create;
   MultiServerList := TList.Create;
   ShutUpList := TQuickList.Create;
   MiniMapList := TStringList.Create;
   UnbindItemList := TStringList.Create;
   LineNoticeList := TStringList.Create;
   LineHelpList := TStringList.Create;
   QuestDiaryList := TList.Create;
   StartupQuestNpc := nil;

   EventItemList := TStringList.Create;
   EventItemGifeBaseNumber := 0;

   csMsgLock    := TCriticalSection.Create;
   csTimerLock  := TCriticalSection.Create;
   csObjMsgLock := TCriticalSection.Create;
   csSendMsgLock:= TCriticalSection.Create;
   csShare      := TCriticalSection.Create;
   csDelShare   := TCriticalSection.Create;
   csSocLock    := TCriticalSection.Create;
   usLock       := TCriticalSection.Create;
   usIMLock     := TCriticalSection.Create;
   ruLock       := TCriticalSection.Create;
   ruSendLock   := TCriticalSection.Create;
   ruCloseLock  := TCriticalSection.Create;
   socstrLock   := TCriticalSection.Create;
   fuLock       := TCriticalSection.Create;
   fuOpenLock   := TCriticalSection.Create;
   fuCloseLock  := TCriticalSection.Create;
   HumanLock    := TCriticalSection.Create; // 위에것들은 왜 프리 안할까...
   umLock       := TCriticalSection.Create;
   SQLock       := TCriticalSection.Create;

   RDBSocData := '';
   ReadyDBReceive := FALSE;
   RunFailCount := 0;
   MirUserLoadCount := 0;
   MirUserSaveCount := 0;
   BoGetGetNeedNotice := FALSE;

   FCertify := 0;
   FItemNumber := 0;
   ServerReady := FALSE;
   ServerClosing := FALSE;
   BoEnableAbusiveFilter := TRUE;
   LottoSuccess := 0;
   LottoFail := 0;
   Lotto1 := 0;
   Lotto2 := 0;
   Lotto3 := 0;
   Lotto4 := 0;
   Lotto5 := 0;
   Lotto6 := 0;

   CurrentMerchantIndex := 0;
   ServerTickDifference := 0;

   FillChar (GrobalQuestParams, sizeof(GrobalQuestParams), #0);

   DecodeDate (Date, ayear, amon, aday);
   DecodeTime (Time, ahour, amin, asec, amsec);
   ErrorLogFile := '.\Log\' +
                   IntToStr(ayear) + '-' + IntToStr(amon) + '-' + IntTo_Str(aday) +
                   '.' +
                   IntTo_Str(ahour) +
                   '-' +
                   IntTo_Str(amin) +
                   '.log';
   AssignFile (fhandle, ErrorLogFile);
   Rewrite (fhandle);
   CloseFile (fhandle);

   minruncount := 99999;
   maxsoctime := 0;
   maxusrtime := 0;
   maxhumtime := 0;
   maxmontime := 0;
   curhumrotatetime := 0;
   maxhumrotatetime := 0;
   humrotatecount := 0;


   HumLimitTime := 30;
   MonLimitTime := 30;
   ZenLimitTime := 5;
   NpcLimitTime := 5;
   SocLimitTime := 10;
   DecLimitTime := 20;

   Memo1.Lines.Add ('ready to load ini file..');
   fname := '.\Setup\!Setup.txt';
   if FileExists (fname) then begin
      ini := TIniFile.Create (fname);
      if ini <> nil then begin
         ServerIndex := ini.ReadInteger ('Server', 'ServerIndex', 0);
         ServerName := ini.ReadString ('Server', 'ServerName', '');
         ServerNumber := ini.ReadInteger ('Server', 'ServerNumber', 0);
         str := ini.ReadString ('Server', 'VentureServer', 'FALSE');
         BoVentureServer := (CompareText(str, 'TRUE') = 0);

         str := ini.ReadString ('Server', 'TestServer', 'FALSE');
         BoTestServer := (CompareText(str, 'TRUE') = 0);
         //클라이언트 테스트용
         str := ini.ReadString ('Server', 'ClientTest', 'FALSE');
         BoClientTest := (CompareText(str, 'TRUE') = 0);

         TestLevel := ini.ReadInteger ('Server', 'TestLevel', 1);
         TestGold := ini.ReadInteger ('Server', 'TestGold', 0);
         TestServerMaxUser := ini.ReadInteger ('Server', 'TestServerUserLimit', 500);

         str := ini.ReadString ('Server', 'ServiceMode', 'FALSE');
         BoServiceMode := (CompareText(str, 'TRUE') = 0);

         str := ini.ReadString ('Server', 'NonPKServer', 'FALSE');
         BoNonPKServer := (CompareText(str, 'TRUE') = 0);

         str := ini.ReadString ('Server', 'ViewHackMessage', 'TRUE');
         BoViewHackCode := (CompareText(str, 'TRUE') = 0);

         str := ini.ReadString ('Server', 'ViewAdmissionFailure', 'FALSE');
         BoViewAdmissionfail := (CompareText(str, 'TRUE') = 0);

         EmergencyMap := ini.ReadString ('Server', 'EmergencyMap', '0');
         EmergencyX := ini.ReadInteger ('Server', 'EmergencyX', 458);
         EmergencyY := ini.ReadInteger ('Server', 'EmergencyY', 398);

         for I := 0 to 2 do begin
           DefHomeMap[I] := ini.ReadString ('Server', 'HomeMap'+IntToStr(I), '0');
           DefHomeX[I] := ini.ReadInteger ('Server', 'HomeX'+IntToStr(I), 458);
           DefHomeY[I] := ini.ReadInteger ('Server', 'HomeY'+IntToStr(I), 398);
         end;

         SqlDBLocal := ini.ReadString ('Server', 'SqlDBLocal', '(local)');
         SqlDBID := ini.ReadString ('Server', 'SqlDBID', 'sa');
         SqlDBPassword := ini.ReadString ('Server', 'SqlDBPassword', 'sa');
         SqlDBDSN := ini.ReadString ('Server', 'SqlDBDSN', 'Game');
         
         with DBSocket do begin
            Address := ini.ReadString ('Server', 'DBAddr', '210.121.143.205');
            Port := ini.ReadInteger ('Server', 'DBPort', 6000);
            Active := TRUE;
         end;
         FItemNumber := ini.ReadInteger ('Setup', 'ItemNumber', 0);

         HumLimitTime := ini.ReadInteger ('Server', 'HumLimit', HumLimitTime);
         MonLimitTime := ini.ReadInteger ('Server', 'MonLimit', MonLimitTime);
         ZenLimitTime := ini.ReadInteger ('Server', 'ZenLimit', ZenLimitTime);
         NpcLimitTime := ini.ReadInteger ('Server', 'NpcLimit', NpcLimitTime);
         SocLimitTime := ini.ReadInteger ('Server', 'SocLimit', SocLimitTime);
         DecLimitTime := ini.ReadInteger ('Server', 'DecLimit', DecLimitTime);

         SENDBLOCK := ini.ReadInteger ('Server', 'SendBlock', SENDBLOCK);
         SENDCHECKBLOCK := ini.ReadInteger ('Server', 'CheckBlock', SENDCHECKBLOCK);
         SENDAVAILABLEBLOCK := ini.ReadInteger ('Server', 'AvailableBlock', SENDAVAILABLEBLOCK);
         GATELOAD := ini.ReadInteger ('Server', 'GateLoad', GATELOAD);

         UserFullCount := ini.ReadInteger ('Server', 'UserFull', 500);
         ZenFastStep := ini.ReadInteger ('Server', 'ZenFastStep', 300);

         MsgServerAddress := ini.ReadString ('Server', 'MsgSrvAddr', '210.121.143.205');
         MsgServerPort := ini.ReadInteger ('Server', 'MsgSrvPort', 4900);

         LogServerAddress := ini.ReadString ('Server', 'LogServerAddr', '192.168.0.152');
         LogServerPort := ini.ReadInteger ('Server', 'LogServerPort', 10000);

         DiscountForNightTime := ini.ReadBool ('Server', 'DiscountForNightTime', FALSE);
         HalfFeeStart := ini.ReadInteger ('Server', 'HalfFeeStart', 2);  //2시
         HalfFeeEnd := ini.ReadInteger ('Server', 'HalfFeeEnd', 10);  //10시

         ShareBaseDir := ini.ReadString ('Share', 'BaseDir', 'D:\');
         ShareFileNameNum := 1;
         GuildDir := ini.ReadString ('Share', 'GuildDir', 'D:\');
         GuildFile := ini.ReadString ('Share', 'GuildFile', 'D:\');
         // 장원 목록 파일.
         GuildBaseDir := ExtractFileDir(GuildFile) + '\';  //폴더는 GuildFile과 같이 사용(sonmg)
         GuildAgitFile := GuildBaseDir + 'GuildAgitList.txt';   //파일이름 하드코딩(sonmg)

         ShareVentureDir := ini.ReadString ('Share', 'VentureDir', 'D:\');
         ConLogBaseDir := ini.ReadString ('Share', 'ConLogDir', 'D:\');
         ChatLogBaseDir := ini.ReadString ('Share', 'ChatLogDir', 'D:\');
         CastleDir := ini.ReadString ('Share', 'CastleDir', 'D:\');
         EnvirDir := ini.ReadString ('Share', 'EnvirDir', '.\Envir\');
         MapDir := ini.ReadString ('Share', 'MapDir', '.\Map\');

         ClientFileName1 := ini.ReadString ('Setup', 'ClientFile1', '');
         ClientFileName2 := ini.ReadString ('Setup', 'ClientFile2', '');
         ClientFileName3 := ini.ReadString ('Setup', 'ClientFile3', '');

         __ClothsForMan := ini.ReadString ('Names', 'ClothsMan', '');
         __ClothsForWoman := ini.ReadString ('Names', 'ClothsWoman', '');
         __WoodenSword := ini.ReadString ('Names', 'WoodenSword', '');
         __Candle := ini.ReadString ('Names', 'Candle', '');
         __BasicDrug := ini.ReadString ('Names', 'BasicDrug', '');

         __GoldStone := ini.ReadString ('Names', 'GoldStone', '');
         __SilverStone := ini.ReadString ('Names', 'SilverStone', '');
         __SteelStone := ini.ReadString ('Names', 'SteelStone', '');
         __CopperStone := ini.ReadString ('Names', 'CopperStone', '');
         __BlackStone := ini.ReadString ('Names', 'BlackStone', '');
         __Gem1Stone := ini.ReadString ('Names', 'Gem1Stone', '');
         __Gem2Stone := ini.ReadString ('Names', 'Gem2Stone', '');
         __Gem3Stone := ini.ReadString ('Names', 'Gem3Stone', '');
         __Gem4Stone := ini.ReadString ('Names', 'Gem4Stone', '');

         __ZumaMonster1 := ini.ReadString ('Names', 'Zuma1', '');
         __ZumaMonster2 := ini.ReadString ('Names', 'Zuma2', '');
         __ZumaMonster3 := ini.ReadString ('Names', 'Zuma3', '');
         __ZumaMonster4 := ini.ReadString ('Names', 'Zuma4', '');

         __Bee      := ini.ReadString ('Names', 'Bee', '');
         __Spider   := ini.ReadString ('Names', 'Spider', '');
         __WhiteSkeleton := ini.ReadString ('Names', 'Skeleton', '');
         __ShinSu   := ini.ReadString ('Names', 'Dragon', '');
         __ShinSu1  := ini.ReadString ('Names', 'Dragon1', '');
         __AngelMob := ini.ReadString ('Names', 'Angel', '');
         __CloneMob := ini.ReadString ('Names', 'Clone', '');

         __WomaHorn := ini.ReadString ('Names', 'WomaHorn', '');
         BUILDGUILDFEE := ini.ReadInteger ('Names', 'BuildGuildFee', BUILDGUILDFEE);
         __ZumaPiece := ini.ReadString ('Names', 'ZumaPiece', '');

         __GoldenImugi := ini.ReadString ('Names', 'GoldenImugi', '');
         __WhiteSnake  := ini.ReadString ('Names', 'WhiteSnake', '');

         ini.Free;
      end;
      Memo1.Lines.Add ('!Setup.txt loaded..');
   end else
      ShowMessage ('!Setup.txt 파일이 없습니다. 치명적인 오류..');

   if (__ClothsForMan = '') or
      (__ClothsForWoman = '') or
      (__WoodenSword = '') or
      (__Candle = '') or
      (__BasicDrug = '') or
      (__GoldStone = '') or
      (__SilverStone = '') or
      (__SteelStone = '') or
      (__CopperStone = '') or
      (__BlackStone = '') or
      (__Gem1Stone = '') or
      (__Gem2Stone = '') or
      (__Gem3Stone = '') or
      (__Gem4Stone = '') or
      (__ZumaMonster1 = '') or
      (__ZumaMonster2 = '') or
      (__ZumaMonster3 = '') or
      (__ZumaMonster4 = '') or
      (__Bee = '') or
      (__Spider = '') or
      (__WhiteSkeleton = '') or
      (__ShinSu = '') or
      (__ShinSu1 = '') or
      (__AngelMob = '') or
      (__CloneMob = '') or
      (__WomaHorn = '') or
      (__ZumaPiece = '') or
      (__GoldenImugi = '') or
      (__WhiteSnake = '') then
      ShowMessage ('Check your !setup.txt file. [Names] -> ClothsForMan ...');

   //버전별 아이템 인덱스 지정
   if KOREANVERSION then begin
      INDEX_CHOCOLATE := 661; //초콜렛
      INDEX_CANDY     := 666; //사탕
      INDEX_LOLLIPOP  := 667; //막대사탕
      INDEX_MIRBOOTS  := 642; //천룡신행보
   end else if ENGLISHVERSION then begin
      INDEX_CHOCOLATE := 1; //초콜렛
      INDEX_CANDY     := 594; //사탕
      INDEX_LOLLIPOP  := 595; //막대사탕
      INDEX_MIRBOOTS  := 477; //천룡신행보
   end else if PHILIPPINEVERSION then begin
      INDEX_CHOCOLATE := 611; //초콜렛
      INDEX_CANDY     := 556; //사탕
      INDEX_LOLLIPOP  := 557; //막대사탕
      INDEX_MIRBOOTS  := 1; //천룡신행보
   end;

//{$IFDEF MIR2EI}
   Caption := Format('MIR3_RT [%s(%d)] ' + DateToStr(Date) + ' ' + TimeToStr(Time),[ServerName, ServerIndex]);
   Panel1.Color := clYellow;
//{$ELSE}
//   // 2003/04/01 버젼 번호 표기
//   Caption := ServerName + ' ' + DateToStr(Date) + ' ' + TimeToStr(Time) + ' V' + IntToStr(VERSION_NUMBER);
//{$ENDIF}

   LoadMultiServerTables;

   LogUDP.Host := LogServerAddress;
   LogUDP.Port := LogServerPort;

   ConnectTimer.Enabled := TRUE;
   Application.OnException := OnProgramException;

   CurrentDBloadingTime := GetTickCount;
   serverruntime := GetTickCount;

   StartTimer.Enabled := TRUE;
   Timer1.Enabled := TRUE;

   g_TestTime := 0;
   g_CryWide := 80;  //기본값

   //스핵체크
   g_SpeedHackCheck := 300;
   g_SpeedHackCheckChar := '';
end;

procedure TFrmMain.OnProgramException (Sender: TObject; E: Exception);
begin
   if gErrorCount > 20000 then
   begin
     gErrorCount := 0;
//   if Sender <> nil then
//       MainOutMessage (Sender.ClassName +':'+E.Message + formatdatetime('hh:nn:ss',now))
//   else
       MainOutMessage (E.Message + formatdatetime('hh:nn:ss',now));
   end;
   gErrorCount := gErrorCount + 1;
end;

procedure TFrmMain.FormDestroy(Sender: TObject);
begin
   SaveItemNumber;
   //서버 오류났을때 사북성 파일이 초기화되는 것을 막기위한 코드(sonmg 2004/08/13)
   if boUserCastleInitialized then
      UserCastle.SaveAll;

   FrontEngine.Terminate;
   FrontEngine.Free;

   UserEngine.Free;
   //친구 쪽지 시스템
   UserMgrEngine.Terminate;
   UserMgrEngine.Free;

   //DBSQL
   SQLEngine.Terminate;
   g_DBSQL.Free;
   SQLEngine.Free;

   RunSocket.Free;
   MainMsg.Free;
   UserLogs.Free;
   UserConAlarmLogs.Free;
   UserConLogs.Free;
   UserChatLog.Free;
   GrobalEnvir.Free;
   ItemMan.Free;
   MagicMan.Free;
   NoticeMan.Free;
   GuildMan.Free;
   GuildAgitMan.Free;   //문파장원(sonmg)
   GuildAgitBoardMan.Free; //장원게시판(sonmg)
   EventMan.Free;
   UserCastle.Free;
   gFireDragon.Free;

   DecoItemList.Free;
   MakeItemList.Free;
   MakeItemIndexList.Free;
   StartPoints.Free;
   SafePoints.Free;
   MultiServerList.Free;
   EventItemList.Free;

   csMsgLock.Free;
   csTimerLock.Free;
   csObjMsgLock.Free;
   csSendMsgLock.Free;
   csShare.Free;
   csDelShare.Free;
   csSocLock.Free;
end;

procedure TFrmMain.SaveItemNumber;
var
   fname: string;
   ini: TIniFile;
begin
   fname := '.\Setup\!Setup.txt';
   ini := TIniFile.Create (fname);
   if ini <> nil then begin
      ini.WriteInteger ('Setup', 'ItemNumber', FItemNumber);
      ini.Free;
   end;
end;

function GetCertifyNumber: integer;
begin
   Inc (FCertify);
   if FCertify > $7FFE then FCertify := 1;
   Result := FCertify;
end;

function GetItemServerIndex: integer;
begin
   Inc (FItemNumber);
   if FItemNumber > $7FFFFFFE then FItemNumber := 1;
   Result := FItemNumber;
end;

procedure LoadMultiServerTables;
var
   i, k: integer;
   str, snum, saddr, sport: string;
   strlist, slist: TStringList;
begin
   for i:=0 to MultiServerList.Count-1 do
      TStringList(MultiServerList[i]).Free;
   MultiServerList.Clear;

   if FileExists ('.\Setup\!ServerTable.txt') then begin
      strlist := TStringList.Create;
      strlist.LoadFromFile ('.\Setup\!ServerTable.txt');
      for i:=0 to strlist.Count-1 do begin
         str := Trim(strlist[i]);
         if str <> '' then begin
            if str[1] = ';' then continue;
            str := GetValidStr3 (str, snum, [' ', #9]);
            if str <> '' then begin
               slist := TStringList.Create;
               for k:=0 to 30 do begin
                  if str = '' then break;
                  str := GetValidStr3 (str, saddr, [' ', #9]);
                  str := GetValidStr3 (str, sport, [' ', #9]);
                  if (saddr <> '') and (sport <> '') then begin
                     slist.AddObject (saddr, TObject(Str_ToInt(sport, 0)));
                  end;
               end;
               MultiServerList.Add (slist);
            end;
         end;
      end;
   end else
      ShowMessage ('File not found... <!ServerTable.txt>');
end;

function  GetMultiServerAddrPort (servernum: byte; var addr: string; var port: integer): Boolean;
var
   n: integer;
   slist: TStringList;
begin
   Result := FALSE;
   if servernum < MultiServerList.Count then begin
      slist := TStringList(MultiServerList[servernum]);
      n := Random (slist.Count);
      addr := slist[n];
      port := Integer(slist.Objects[n]);
      Result := TRUE;
   end else
      MainOutMessage ('GetMultiServerAddrPort Fail..:'+ IntToStr(servernum));
end;

function  GetUnbindItemName (shape: integer): string;
var
   i: integer;
begin
   Result := '';
   for i:=0 to UnbindItemList.Count-1 do begin
      if Integer(UnbindItemList.Objects[i]) = shape then begin
         Result := UnbindItemList[i];
         break;
      end;
   end;
end;

function  LoadLineNotice (flname: string): Boolean;
begin
   Result := FALSE;
   if FileExists (flname) then begin
      LineNoticeList.LoadFromFile (flname);
      CheckListValid (LineNoticeList);
      Result := TRUE;
   end;
end;

function  LoadLineHelp (flname: string): Boolean;
begin
   Result := FALSE;
   if FileExists (flname) then begin
      LineHelpList.LoadFromFile (flname);
      CheckListValid (LineHelpList);
      Result := TRUE;
   end;
end;

//해당 index의 StartPoint 맵 이름을 얻어오는 함수(sonmg 2005/12/28)
function  GetStartPointMapName (index: integer): string;
var
   str, mapstr, rangestr: string;
begin
   str := '';
   Result := '';
   if index < 0 then exit;
   if StartPoints.Count <= 0 then exit;

   if (index < StartPoints.Count) then begin
      str := StartPoints[index];
      str := GetValidStr3(str, mapstr, ['/']);
      Result := mapstr;
   end;
end;

//문자열을 인코딩 또는 디코딩하는 함수
//문자열 앞에 'ENCODE_'가 붙어있으면 인코딩, 아니면 디코딩 작업을 수행
//@Param var src : 인코딩 또는 디코딩될 원본 문자열, 리턴될 때에는
//@Param key : 인코딩 및 디코딩에 사용될 Key
//@Result : 인코딩된 문자열을 반환함. 디코딩인 경우는 ''를 반환함.
function  DecodeStringPassword( var src: string; key: integer ): string;
var
   i, temp: integer;
   tempstr, EncodedPwd: string;
   EncodeString: string;
begin
   Result := '';
   EncodeString := 'M2';

   tempstr := Copy( UPPERCASE(src), 1, _MIN(Length(EncodeString), Length(src)) );
   if tempstr = EncodeString then begin
      src := Copy( src, Length(EncodeString) +1, Length(src) );
      EncodedPwd := src;
      //Encode Password
      for i:=1 to Length(src) do begin
         temp := Integer(src[i]) xor ( key + i );
         if not ((temp >= 33) and (temp <= 126)) then begin
            temp := Integer(src[i]);
         end;
         EncodedPwd[i] := Char(temp);
      end;
      Result := EncodedPwd;
   end else begin
      //Decode Password
      for i:=1 to Length(src) do begin
         temp := Integer(src[i]) xor ( key + i );
         if not ((temp >= 33) and (temp <= 126)) then begin
            temp := Integer(src[i]);
         end;
         src[i] := Char(temp);
      end;
   end;
end;

//---------------------------------------------------------------//

procedure MainOutMessage (str: string);
begin
   try
      csMsgLock.Enter;
      MainMsg.Add (str);
   finally
      csMsgLock.Leave;
   end;
end;

procedure AddUserLog (str: string);
begin
   try
      csMsgLock.Enter;
      UserLogs.Add (str);
   finally
      csMsgLock.Leave;
   end;
end;

procedure AddUserConAlarmLog (str: string);
begin
   try
      csMsgLock.Enter;
      UserConAlarmLogs.Add (str);
   finally
      csMsgLock.Leave;
   end;
end;

procedure AddConLog (str: string);
begin
   try
      csMsgLock.Enter;
      UserConLogs.Add (str);
   finally
      csMsgLock.Leave;
   end;
end;

procedure AddChatLog (str: string);
begin
   try
      csMsgLock.Enter;
      UserChatLog.Add (str);
   finally
      csMsgLock.Leave;
   end;
end;

procedure WriteConLogs (slist: TStringList);
var
   ayear, amon, aday, ahour, amin, asec, amsec: word;
   dirname, flname: string;
   dir256: array[0..255] of char;
   f: TextFile;
   i: integer;
begin
   if slist.Count = 0 then exit;

   DecodeDate (Date, ayear, amon, aday);
   DecodeTime (Time, ahour, amin, asec, amsec);
   dirname := ConLogBaseDir + IntToStr(ayear) + '-' + IntTo_Str(amon) + '-' + IntTo_Str(aday);
   if not FileExists (dirname) then begin
      StrPCopy (dir256, dirname);
      CreateDirectory (@dir256, nil);
   end;
   flname := dirname + '\C-' + IntToStr(ServerIndex) + '-' + IntTo_Str(ahour) + 'H' + IntTo_Str(amin div 10 * 10) + 'M.txt';

   AssignFile (f, flname);
   if not FileExists (flname) then
      Rewrite (f)
   else Append (f);

   for i:=0 to slist.Count-1 do begin
      WriteLn (f, '1'#9 + slist[i] + ''#9 + '0');
   end;

   CloseFile (f);
end;

procedure WriteChatLogs (slist: TStringList);
var
   ayear, amon, aday, ahour, amin, asec, amsec: word;
   dirname, flname: string;
   dir256: array[0..255] of char;
   f: TextFile;
   i: integer;
begin
   if slist.Count = 0 then exit;

   DecodeDate (Date, ayear, amon, aday);
   DecodeTime (Time, ahour, amin, asec, amsec);
   dirname := ChatLogBaseDir + IntToStr(ayear) + '-' + IntTo_Str(amon) + '-' + IntTo_Str(aday);
   if not FileExists (dirname) then begin
      StrPCopy (dir256, dirname);
      CreateDirectory (@dir256, nil);
   end;
   flname := dirname + '\C-' + {IntToStr(ServerIndex) + '-' +} IntTo_Str(ahour) + 'H' + {IntTo_Str(amin div 10 * 10) +} 'M.txt';

   AssignFile (f, flname);
   if not FileExists (flname) then
      Rewrite (f)
   else Append (f);

   for i:=0 to slist.Count-1 do begin
      WriteLn (f, IntToStr(ServerIndex) + ''#9 + slist[i] + ''#9 + '0');
   end;

   CloseFile (f);
end;

function TFrmMain.LoadClientFileCheckSum: Boolean;
begin
   Memo1.Lines.Add ('loading client version information..');
   if ClientFileName1 <> '' then
      ClientCheckSumValue1 := CheckFileCheckSum (ClientFileName1);
   if ClientFileName2 <> '' then
      ClientCheckSumValue2 := CheckFileCheckSum (ClientFileName2);
   if ClientFileName3 <> '' then
      ClientCheckSumValue3 := CheckFileCheckSum (ClientFileName3);
   if (clientchecksumvalue1 = 0) and (clientchecksumvalue2 = 0) and (clientchecksumvalue3 = 0) then begin
      Memo1.Lines.Add ('Loading client version information failed. check !setup.txt -> [setup] -> clientfile1,..');
      Result := FALSE;
   end else begin
      Memo1.Lines.Add ('Ok. ' + ClientFileName1 + '(' + IntToStr(ClientCheckSumValue1) + ') ' + ClientFileName2 + '(' + IntToStr(ClientCheckSumValue2) + ') ' + ClientFileName3 + '(' + IntToStr(ClientCheckSumValue3) + ')');
      Result := TRUE;
   end;
end;

// ----------------------------------------------------------------


procedure TFrmMain.StartTimerTimer(Sender: TObject);
var
   i,error, checkvalue: integer;
   IsSuccess : Boolean;
   handle, FileDate : integer;
   DateTime : TDateTime;
begin
   StartTimer.Enabled := FALSE;

   try
      //데이터 검사
{$ifdef MIR2EI}
      checkvalue := SIZEOFEIFDB;
{$else}
      checkvalue := SIZEOFFDB;
{$endif}

      if sizeof(FDBRecord) <> checkvalue then begin
         ShowMessage ('sizeof(THuman) '+inttostr(sizeof(FDBRecord))+' <> SIZEOFTHUMAN '+inttostr(SIZEOFFDB));
         Close;
         exit;
      end;

      if not LoadClientFileCheckSum then begin
         close;
         exit;
      end;

      Memo1.Lines.Add ('loading StdItem.DB...');

      //기본 데이타를 로딩 한다.
      error := FrmDB.LoadStdItems;
      if error < 0 then begin
         ShowMessage ('StdItems.DB' + '를 읽는 도중 오류가 발생 하였음. code=' + IntToStr(error));
         close;
         exit;
      end else
         Memo1.Lines.Add ('StdItem.DB loaded.');

      Memo1.Lines.Add ('loading MiniMap.txt...');
      error := FrmDB.LoadMiniMapInfos;
      if error < 0 then begin
         ShowMessage ('MiniMap.txt' + '를 읽는 도중 오류가 발생 하였음. code=' + IntToStr(error));
         close;
         exit;
      end else
         Memo1.Lines.Add ('MiniMap information loaded.');

      // 용던젼 시스템 로딩
      Memo1.Lines.Add('Loading DragonSystem...');
      Memo1.Lines.Add( gFireDragon.Initialize( EnvirDir + DRAGONITEMFILE , IsSuccess ) );
      if ( not IsSuccess ) then
      Memo1.Lines.Add( DRAGONITEMFILE +'를 읽는도중오류가 발생하였음');


      Memo1.Lines.Add ('loading MapFiles...');
      error := FrmDB.LoadMapFiles;
      if error < 0 then begin
         ShowMessage ('맵 정보를 읽는 도중 오류가 발생 하였음. code=' + IntToStr(error));
         close;
         exit;
      end else
         Memo1.Lines.Add  ('Mapfile loaded.');

      Memo1.Lines.Add ('loading Monster.DB...');
      error := FrmDB.LoadMonsters;
      if error <= 0 then begin
         ShowMessage ('Monster.DB' + '를 읽는 도중 오류가 발생 하였음. code=' + IntToStr(error));
         close;
         exit;
      end else
         Memo1.Lines.Add  ('Monster.DB loaded.');

      Memo1.Lines.Add ('loading Magic.DB...');
      error := FrmDB.LoadMagic;
      if error <= 0 then begin
         ShowMessage ('Magic.DB' + '를 읽는 도중 오류가 발생 하였음. code=' + IntToStr(error));
         close;
         exit;
      end else
         Memo1.Lines.Add  ('Magic.DB loaded.');

      Memo1.Lines.Add ('loading MonGen.txt...');
      error := FrmDB.LoadZenLists;
      if error <= 0 then begin
         ShowMessage ('MonGen.txt' + '를 읽는 도중 오류가 발생 하였음. code=' + IntToStr(error));
         close;
         exit;
      end else
         Memo1.Lines.Add  ('MonGen.txt loaded.');

      // 2003/06/20 이벤트몹 젠 메세지 등록
      Memo1.Lines.Add ('loading GenMsg.txt...');
      error := FrmDB.LoadGenMsgLists;
      if error <= 0 then begin
         ShowMessage ('GenMsg.txt' + '를 읽는 도중 오류가 발생 하였음. code=' + IntToStr(error));
         close;
         exit;
      end else
         Memo1.Lines.Add  ('GenMsg.txt loaded.');

      Memo1.Lines.Add ('loading UnbindList.txt...');
      error := FrmDB.LoadUnbindItemLists;
      if error < 0 then begin
         ShowMessage ('UnbindList.txt' + '를 읽는 도중 오류가 발생 하였음. code=' + IntToStr(error));
         close;
         exit;
      end else
         Memo1.Lines.Add ('UnbindList information loaded.');

      Memo1.Lines.Add ('loading MapQuest.txt...');
      error := FrmDB.LoadMapQuestInfos;
      if error < 0 then begin
         ShowMessage ('MapQuest.txt' + '를 읽는 도중 오류가 발생 하였음. code=' + IntToStr(error));
         close;
         exit;
      end else
         Memo1.Lines.Add ('MapQuest information loaded.');

      Memo1.Lines.Add ('loading StartupQuest.txt...');
      error := FrmDB.LoadStartupQuest;
      if error < 0 then begin
         ShowMessage ('StartupQuest.txt' + '를 읽는 도중 오류가 발생 하였음. code=' + IntToStr(error));
         close;
         exit;
      end else
         Memo1.Lines.Add ('StartupQuest information loaded..');

      Memo1.Lines.Add ('loading QuestDiary\*.txt...');
      error := FrmDB.LoadQuestDiary;
      if error < 0 then begin
         ShowMessage ('QuestDiary\*.txt' + '를 읽는 도중 오류가 발생 하였음. code=' + IntToStr(error));
         close;
         exit;
      end else
         Memo1.Lines.Add ('QuestDiary information loaded.');

      if LoadAbusiveList ('!Abuse.txt') then
         Memo1.Lines.Add  ('!Abuse.txt' + ' loaded..');

      if LoadLineNotice (LINENOTICEFILE) then
         Memo1.Lines.Add  (LINENOTICEFILE + ' loaded..')
      else
         Memo1.Lines.Add  (LINENOTICEFILE + ' loading failure !!!!!!!!!');

      if LoadLineHelp (LINEHELPFILE) then
         Memo1.Lines.Add  (LINEHELPFILE + ' loaded..')
      else
         Memo1.Lines.Add  (LINEHELPFILE + ' loading failure !!!!!!!!!');

      if FrmDB.LoadAdminFiles > 0 then
         Memo1.Lines.Add  ('AdminList loaded..')
      else
         Memo1.Lines.Add  ('AdminList loading failure !!!!!!!!!');

      // LoadPublicKey
//      if LoadPublicKey( EnvirDir + 'enckey.txt' ) then
//         Memo1.Lines.Add  ('PublicKey loaded..');

      // 2003/08/28
      FrmDB.LoadChatLogFiles;
      Memo1.Lines.Add  ('Chatting Log List loaded..');

      GuildMan.LoadGuildList;
      Memo1.Lines.Add  ('GuildList loaded..');

      GuildAgitMan.LoadGuildAgitList;
      Memo1.Lines.Add  ('GuildAgitList loaded..');

      //장원게시판
      GuildAgitBoardMan.LoadAllGaBoardList('');
      Memo1.Lines.Add  ('GuildAgitBoardList loaded..');

      UserCastle.Initialize;  //문파정보가 이미 읽어진 후에 불려져야함
      boUserCastleInitialized := TRUE;
      Memo1.Lines.Add  ('Castle initialized..');

      if ServerIndex = 0 then begin //0번 서버가 마스터가 된다.
         FrmSrvMsg.Initialize;
      end else begin
         FrmMsgClient.Initialize;
      end;

      // DBSQL 연결 ------------------------------------------------------------
      if g_DBSQL.Connect() then
      Memo1.Lines.Add ('DBSQL Connection Success')
      else
      Memo1.Lines.Add ('DBSQL Connection Fail [ ERROR!] ' );
      //------------------------------------------------------------------------
      //버전 표시...
      DateTime := 0;
      if FileExists ('M2Server.exe') then begin
         handle := FileOpen ('M2Server.exe', fmOpenRead or fmShareDenyNone);
         if handle > 0 then begin
            FileDate := FileGetDate( handle );
            DateTime := FileDateToDateTime(FileDate);
            MainOutMessage('FileDateVersion : ' + DateTimeToStr(DateTime));
            FileClose (handle);
         end;
      end;
      //------------------------------------------------------------------------

      StartServer;

      ServerReady := TRUE;

      Sleep(1);
      ConnectTimer.Enabled := TRUE;

      runstart := GetTickCount;
      rcount := 0;
      humrotatetime := GetTickCount;
      RunTimer.Enabled := TRUE;


   except
      MainOutMessage ('starttimer exception...');
   end;
end;

procedure TFrmMain.Timer1Timer(Sender: TObject);
var
   i, runsec: integer;
   fhandle: TextFile;
   fail: Boolean;
   r: Real;
   ayear, amon, aday: word;
   ahour, amin, asec, amsec: word;
   checkstr, str, sendb: string;
   pgate: PTRunGateInfo;
   MyStream: TMemoryStream;
   down : integer;
begin
   down := 1;
   try
      csTimerLock.Enter;
      if Memo1.Lines.Count > 500 then Memo1.Lines.Clear;
      fail := TRUE;
      if MainMsg.Count > 0 then begin
         try
            if not FileExists (ErrorLogFile) then begin
               AssignFile (fhandle, ErrorLogFile);
               Rewrite (fhandle);
               fail := FALSE;
            end else begin
               AssignFile (fhandle, ErrorLogFile);
               Append (fhandle);
               fail := FALSE;
            end;
         except
            Memo1.Lines.Add ('Error on writing ErrorLog.');
         end;
      end;
      for i:=0 to MainMsg.Count-1 do begin
         Memo1.Lines.Add (MainMsg[i]);
         if not fail then WriteLn (fhandle, MainMsg[i]);
      end;
      MainMsg.Clear;
      if not fail then CloseFile (fhandle);

      //플래이어의 접속 로그를 UDP소켓을 통해서 로그수집서버에 전달
      for I := 0 to UserLogs.Count-1 do begin
         try
            str := '1'#9 +
                   IntToStr(ServerNumber) + #9 +
                   IntToStr(ServerIndex) + #9 +
                   UserLogs[I];
            LogUDP.Send(str);
         except
            Continue;
         end;
      end;
      UserLogs.Clear;

      //특정 행동 유저의 접속/행동 로그를 접속자 체크 서버에 전달(sonmg 2005/06/23)
      for i:=0 to UserConAlarmLogs.Count-1 do begin
         try
            DecodeDate (Date, ayear, amon, aday);
            DecodeTime (Time, ahour, amin, asec, amsec);
            str := IntToStr(ayear) + '-' + IntToStr(amon) + '-' + IntToStr(aday) + '  ' +
                   IntToStr(ahour) + ':' + IntToStr(amin) + ':' + IntToStr(asec) + ''#9 +
                   ServerName + '  ' +
                   IntToStr(ServerIndex) + '번'#9 +
                   UserConAlarmLogs[i];
            

            //호스트로 보내기
            ConAlarmUDP.Host := '172.20.4.82';
            ConAlarmUDP.Send(str);
            //호스트로 보내기
            ConAlarmUDP.Host := '172.20.4.77';
            ConAlarmUDP.Send(str);
            //호스트로 보내기(내자리)
//            ConAlarmUDP.Host := '172.20.2.49';
//            ConAlarmUDP.Send(str);
            //호스트로 보내기(승기씨자리)
//            ConAlarmUDP.Host := '172.20.4.61';
//            ConAlarmUDP.Send(str);
            //호스트로 보내기(1층 성욱씨)
            ConAlarmUDP.Host := '172.20.5.85';
            ConAlarmUDP.Send(str);
         except
            Continue;
         end;
      end;
      UserConAlarmLogs.Clear;

      //플래이어의 접속 로그를 저장한다.
      if UserConLogs.Count > 0 then begin
         try
           WriteConLogs (UserConLogs);
         except
           MainOutMessage ('ERROR_CONLOG_FAIL');
         end;
         UserConLogs.Clear;
      end;

      //플래이어의 채팅 로그를 저장한다.
      if UserChatLog.Count > 0 then begin
         try
           WriteChatLogs (UserChatLog);
         except
           MainOutMessage ('ERROR_CHATLOG_FAIL');
         end;
         UserChatLog.Clear;
      end;

   finally
      csTimerLock.Leave;
   end;

   try
   down := 2;

   if ServerIndex = 0 then checkstr := '[M]'
   else if FrmMsgClient.MsgClient.Socket.Connected then checkstr := '[S]'
   else checkstr := '[ ]';

   checkStr := checkStr+IntToStr(gErrorCount);
{$IFDEF DEBUG} //sonmg
   checkstr := checkstr + ' DEBUG';
{$ENDIF}

   down := 3;

   runsec := (GetTickCount - serverruntime) div 1000;
   ahour := runsec div 3600;
   amin := (runsec mod 3600) div 60;
   asec := runsec mod 60;
   LbRunTime.Caption := '[' + IntToStr(ahour) + ':' + IntToStr(amin) + ':' + IntToStr(asec)
                        + ']' + checkstr;
   down := 4;
   // 2003/03/18 테스트 서버 인원 제한
   LbUserCount.Caption :=
                           '(' + //IntToStr(UserEngine.MonRunCount) + '/' +
                           IntToStr(UserEngine.MonCount) + ')   ' +
                           IntToStr(UserEngine.GetRealUserCount) +
                           '/' + IntToStr(UserEngine.GetUserCount) +
                           '/' + IntToStr(UserEngine.FreeUserCount);
   Label1.Caption := 'Run' + IntToStr(curruncount) + '/' + IntToStr(minruncount) + ' ' +
                     'Soc' + IntToStr(cursoctime) + '/' + IntToStr(maxsoctime) + ' ' +
                     'Usr' + IntToStr(curusrcount) + '/' + IntToStr(maxusrtime) + '.';
   Label2.Caption := 'Hum' + IntToStr(curhumtime) + '/' + IntToStr(maxhumtime) + ' ' +
                     'Mon' + IntToStr(curmontime) + '/' + IntToStr(maxmontime) + ' ' +
                     'UsrRot' + IntToStr(curhumrotatetime) + '/' + IntToStr(maxhumrotatetime) +
                                '(' + IntToStr(humrotatecount) + ')';

   Label5.Caption := LatestGenStr + ' - ' + LatestMonStr + '    ';

   down := 5;
   r := GetTickCount / (1000 * 60 * 60 * 24);
   if r >= 36 then LbTimeCount.Font.Color := clRed;
   LbTimeCount.Caption := FloatToString (r) + 'Day';

   down := 6;
   str := '';
   with RunSocket do begin  //멀티 스래트로 변경했을 경우 동기화 주의
      for i:=0 to MAXGATE-1 do begin
         pgate := PTRunGateInfo (@GateArr[i]);
         if pgate <> nil then begin
            if pgate.Socket <> nil then begin
               if pgate.sendbytes < 1024 then sendb := IntToStr(pgate.sendbytes) + 'b '
               else sendb := IntToStr(pgate.sendbytes div 1024) + 'kb ';
               str := str +
                      '[G' + IntToStr(i+1) + ': ' +
                      IntToStr(pgate.curbuffercount) + '/' + IntToStr(pgate.remainbuffercount) + ' ' +
                      sendb +
                      IntToStr(pgate.sendsoccount) +
                      '] ';
            end;
         end;
      end;
   end;
   Label3.Caption := str;

   down := 7;
   Inc (minruncount);
   Dec (maxsoctime);
   Dec (maxusrtime);
   Dec (maxhumtime);
   Dec (maxmontime);
   Dec (maxhumrotatetime);

   except
      MainOutMessage('Exception Timer1Timer :'+IntTostr(down));
   end;
end;

procedure TFrmMain.SaveVariableTimerTimer(Sender: TObject);
begin
   SaveItemNumber;
end;

procedure TFrmMain.MakeStoneMines;
var
   i, k, x, y: integer;
   ev: TStoneMineEvent;
   env: TEnvirnoment;
begin
   for i:=0 to GrobalEnvir.Count-1 do begin
      env := TEnvirnoment(GrobalEnvir[i]);
      if (env.MineMap > 0) then begin
         for x:=0 to env.MapWidth-1 do
            for y:=0 to env.MapHeight-1 do begin
               if env.minemap = 1 then
                  ev := TStoneMineEvent.Create (env, x, y, ET_MINE)   //생성으로 끝
               else if env.minemap = 2 then
                  ev := TStoneMineEvent.Create (env, x, y, ET_MINE2)  //생성으로 끝
               else
                  ev := TStoneMineEvent.Create (env, x, y, ET_MINE3);  //생성으로 끝
               //EventMan.AddEvent (ev); 추가할 필요는 없다.
               // 마인이 안 넣어졌다면 없에버리지..
               if ( ev <> nil ) and ev.IsAddToMap = false then
               begin
                    ev.Free;
                    ev := nil;
                    // MainOutMessage('STONMIME FREE');
               end;

            end;
      end;
   end;
end;

procedure TFrmMain.StartServer;
var
   error: integer;
   TotalDecoMonCount: integer;
begin
   try

      FrmIDSoc.Initialize;
      Memo1.Lines.Add ('IDSoc Initialized..');

      GrobalEnvir.InitEnvirnoments;
      Memo1.Lines.Add ('GrobalEnvir loaded..');

      MakeStoneMines; //광석을 채운다.
      Memo1.Lines.Add ('MakeStoneMines...');

      error := FrmDB.LoadMerchants;
      if error < 0 then begin
         ShowMessage ('merchant.txt' + '를 읽는 도중 오류가 발생 하였음. code=' + IntToStr(error));
         close;
         exit;
      end else
         Memo1.Lines.Add ('merchant loaded...');

      //---------------------------------------------
      //장원꾸미기 아이템 리스트 로드(sonmg)
      //LoadAgitDecoMon보다 먼저 실행되어야 함.
      error := FrmDB.LoadDecoItemList;
      if error < 0 then begin
         ShowMessage ('DecoItem.txt' + '를 읽는 도중 오류가 발생 하였음. code=' + IntToStr(error));
         close;
         exit;
      end else
         Memo1.Lines.Add ('DecoItemList loaded..');

      //0번 서버에서만 읽어들임.
      if ServerIndex = 0 then begin
         //장원꾸미기 오브젝트 로드(sonmg)
         //LoadDecoItemList보다 나중에 실행되어야 함.
         error := GuildAgitMan.LoadAgitDecoMon;
         if error < 0 then begin
            ShowMessage (GuildBaseDir + AGITDECOMONFILE + '를 읽는 도중 오류가 발생 하였음. code=' + IntToStr(error));
            close;
            exit;
         end else begin
            //장원에 꾸미기 오브젝트를 생성시킨다.
            TotalDecoMonCount := GuildAgitMan.MakeAgitDecoMon;
            //장원별 꾸미기 오브젝트 개수를 종합한다.
            GuildAgitMan.ArrangeEachAgitDecoMonCount;
            Memo1.Lines.Add ('AgitDecoMon ' + IntToStr(TotalDecoMonCount) + ' loaded...');
         end;
      end;
      //---------------------------------------------

      if not BoVentureServer then begin  //모험서버에서는 경비병이 없다.
         error := FrmDB.LoadGuards;
         if error < 0 then begin
            ShowMessage ('Guardlist.txt' + '를 읽는 도중 오류가 발생 하였음. code=' + IntToStr(error));
            close;
            exit;
         end;
      end;

      error := FrmDB.LoadNpcs;
      if error < 0 then begin
         ShowMessage ('Npc.txt' + '를 읽는 도중 오류가 발생 하였음. code=' + IntToStr(error));
         close;
         exit;
      end else
         Memo1.Lines.Add ('Npc loaded..');

      error := FrmDB.LoadMakeItemList;
      if error < 0 then begin
         ShowMessage ('MakeItem.txt' + '를 읽는 도중 오류가 발생 하였음. code=' + IntToStr(error));
         close;
         exit;
      end else
         Memo1.Lines.Add ('MakeItem loaded..');

      error := FrmDB.LoadStartPoints;
      if error < 0 then begin
         ShowMessage ('StartPoint.txt' + '를 읽는 도중 오류가 발생 하였음. code=' + IntToStr(error));
         close;
         exit;
      end else
         Memo1.Lines.Add ('StartPoints loaded..');

      error := FrmDB.LoadSafePoints;
      if error < 0 then begin
         ShowMessage ('SafePoint.txt' + '를 읽는 도중 오류가 발생 하였음. code=' + IntToStr(error));
         close;
         exit;
      end else
         Memo1.Lines.Add ('SafePoints loaded..');

      FrontEngine.Resume;
      Memo1.Lines.Add ('F-Engine resumed..');

      UserEngine.Initialize;
      Memo1.Lines.Add ('U-Engine initialized..');

      UserMgrEngine.Resume;
      Memo1.Lines.Add ('UserMgr-Engine resumed..');

      SQlEngine.Resume;
      Memo1.Lines.Add ('SQL-Engine resumed..');

   except
      MainOutMessage ('startserver exception..');
   end;
end;

procedure TFrmMain.ConnectTimerTimer(Sender: TObject);
begin
   if not DBSocket.Active then begin
      DBSocket.Active := TRUE;
   end;
end;


{--------------- Gate의 데이타를 처리함 --------------}

procedure TFrmMain.RunTimerTimer(Sender: TObject);
begin
   if ServerReady then begin
      RunSocket.Run;

      FrmIDSoc.DecodeSocStr;

      UserEngine.ExecuteRun;

      //위탁상점
      SqlEngine.ExecuteRun;

      EventMan.Run;

      if ServerIndex = 0 then begin //0번 서버가 마스터가 된다.
         FrmSrvMsg.Run;
      end else begin
         FrmMsgClient.Run;
      end;
   end;

   Inc (rcount);
   if GetTickCount - runstart > 250 then begin
      runstart := GetTickCount;
      curruncount := rcount;
      if minruncount > curruncount then minruncount := curruncount;
      rcount := 0;
   end;
end;

{------------- Gate Socket 관련 함수 ----------------}

procedure TFrmMain.GateSocketClientConnect(Sender: TObject;
  Socket: TCustomWinSocket);
begin
   RunSocket.Connect (Socket);
end;

procedure TFrmMain.GateSocketClientDisconnect(Sender: TObject;
  Socket: TCustomWinSocket);
begin
   RunSocket.Disconnect (Socket);
end;

procedure TFrmMain.GateSocketClientError(Sender: TObject;
  Socket: TCustomWinSocket; ErrorEvent: TErrorEvent;
  var ErrorCode: Integer);
begin
   RunSocket.SocketError (Socket, ErrorCode);
end;

procedure TFrmMain.GateSocketClientRead(Sender: TObject;
  Socket: TCustomWinSocket);
begin
   RunSocket.SocketRead (Socket);
end;

{------------- DB Socket 관련 함수 ----------------}

function  DBConnected: Boolean;
begin
   if FrmMain.DBSocket.Active then
      Result := FrmMain.DBSocket.Socket.Connected
   else Result := FALSE;      
end;

procedure TFrmMain.DBSocketConnect(Sender: TObject;
  Socket: TCustomWinSocket);
begin
   ;
end;

procedure TFrmMain.DBSocketDisconnect(Sender: TObject;
  Socket: TCustomWinSocket);
begin
   ;
end;

procedure TFrmMain.DBSocketError(Sender: TObject; Socket: TCustomWinSocket;
  ErrorEvent: TErrorEvent; var ErrorCode: Integer);
begin
   ErrorCode := 0;
   Socket.Close;
end;

procedure TFrmMain.DBSocketRead(Sender: TObject; Socket: TCustomWinSocket);
var
   data: string;
begin
   try
      csSocLock.Enter;
      data := Socket.ReceiveText;
      RDBSocData := RDBSocData + data;
      if not ReadyDBReceive then
         RDBSocData := '';

   finally
      csSocLock.Leave;
   end;

   // DB 에서읽은 데이터를 넣는다. PDS...
   UserMgrEngine.OnDBRead( data );


//   if ReadyDBReceive then MainOutMessage ('DB-> ' + IntToStr(Length(data)) + ' OK')
//   else MainOutMessage ('DB-> ' + IntToStr(Length(data)) + ' Miss');
end;

procedure TFrmMain.FormCloseQuery(Sender: TObject; var CanClose: Boolean);
begin
   if not ServerClosing then begin
      CanClose := FALSE;
      if MessageDlg ('exit server ? (yes=exit)', mtConfirmation, [mbYes, mbNo, mbCancel], 0) = mrYes then begin
         ServerClosing := TRUE;
         TCloseTimer.Enabled := TRUE;
         RunSocket.CloseAllGate;
      end;
   end;      
end;

procedure TFrmMain.TCloseTimerTimer(Sender: TObject);
begin
   if (UserEngine.GetRealUserCount = 0) and (FrontEngine.IsFinished) then begin
      Close;
   end;
end;

procedure TFrmMain.Panel1DblClick(Sender: TObject);
var
   ini: TIniFile;
   fname, bostr: string;
begin
   if FrmServerValue.Execute then begin
      fname := '.\Setup\!Setup.txt';
      ini := TIniFile.Create (fname);
      if ini <> nil then begin
         ini.WriteInteger ('Server', 'HumLimit', HumLimitTime);
         ini.WriteInteger ('Server', 'MonLimit', MonLimitTime);
         ini.WriteInteger ('Server', 'ZenLimit', ZenLimitTime);
         ini.WriteInteger ('Server', 'SocLimit', SocLimitTime);
         ini.WriteInteger ('Server', 'DecLimit', DecLimitTime);
         ini.WriteInteger ('Server', 'NpcLimit', NpcLimitTime);

         ini.WriteInteger ('Server', 'SendBlock', SENDBLOCK);
         ini.WriteInteger ('Server', 'CheckBlock', SENDCHECKBLOCK);
         ini.WriteInteger ('Server', 'GateLoad', GATELOAD);

         if BoViewHackCode then bostr := 'TRUE'
         else bostr := 'FALSE';
         ini.WriteString ('Server', 'ViewHackMessage', bostr);

         if BoViewAdmissionFail then bostr := 'TRUE'
         else bostr := 'FALSE';
         ini.WriteString ('Server', 'ViewAdmissionFailure', bostr);

      end;
   end;
end;

procedure TFrmMain.SpeedButton1Click(Sender: TObject);
var
   ini: TIniFile;
   fname: string;
begin
   FrmIDSoc.Timer1Timer(self);

   with FrmMsgClient do begin
      if ServerIndex <> 0 then
         if not MsgClient.Socket.Connected then begin
            MsgClient.Active := TRUE;
         end;
   end;

   fname := '.\Setup\!Setup.txt';
   if FileExists (fname) then begin
      ini := TIniFile.Create (fname);
      if ini <> nil then begin
         LogServerAddress := ini.ReadString ('Server', 'LogServerAddr', '192.168.0.152');
         LogServerPort := ini.ReadInteger ('Server', 'LogServerPort', 10000);

         ClientFileName1 := ini.ReadString ('Setup', 'ClientFile1', '');
         ClientFileName2 := ini.ReadString ('Setup', 'ClientFile2', '');
         ClientFileName3 := ini.ReadString ('Setup', 'ClientFile3', '');
      end;
      ini.Free;
   end;
   LogUDP.Host := LogServerAddress;
   LogUDP.Port := LogServerPort;

   LoadMultiServerTables;

   FrmIDSoc.LoadShareIPList;

   LoadClientFileCheckSum;
end;

end.

