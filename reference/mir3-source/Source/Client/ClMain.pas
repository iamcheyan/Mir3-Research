unit ClMain;

interface

uses
  Windows, Messages, MMSystem, SysUtils, Classes, Graphics, Controls, Forms,
  Dialogs, DirectX, HGETextures, HGE, HGEBase, HGECanvas, DrawScrn, IntroScn,
  PlayScn, MapUnit, WIL, Grobal2, Actor, StdCtrls, CliUtil, ScktComp, ExtCtrls,
  HUtil32, EdCode, jpeg, wmUtil, DWinCtl, ClFunc, magiceff, SoundUtil, HGESounds,
  clEvent, IniFiles, Registry, MaketSystem, RelationShip, Mpeg, CMsg;

const
  BO_FOR_TEST = FALSE;
  BoNeedPatch = TRUE;
  BoDebugModeScreen = FALSE;

  VERSION_YEAR = 2005;
  VERSION_MON = 5;
  VERSION_DAY = 1;

  LocalLanguage: TImeMode = imOpen;
  SERVERADDR: string = '127.0.0.1';
  TESTSERVERADDR = '127.0.0.1';

  SCREENWIDTH = 800;
  SCREENHEIGHT = 600;
  MAXBAGITEMCL = 52;
  ENEMYCOLOR = 69;

  MAXVIEWOBJECT = 20;

  CurFontName: string = 'ËÎÌå';

  HIT_INCLEVEL = 14;
  HIT_INCSPEED = 60;
  HIT_BASE = 1400;
  RUN_STRUCK_DELAY: integer = 3 * 1000;

type
  TInt64Decompose = packed record
    case Integer of
      1: (nInt64: Int64;);
      2: (nInteger1: Integer; nInteger2: Integer;);
  end;

  TMemoryStatusEx = packed record
    dwLength: DWORD;
    dwMemoryLoad: DWORD;
    dwTotalPhys: Int64;
    dwAvailPhys: Int64;
    dwTotalPageFile: Int64;
    dwAvailPageFile: Int64;
    dwTotalVirtual: Int64;
    dwAvailVirtual: Int64;
    dwAvailExtendedVirtual: Int64;
  end;

  TTimerCommand = (tcSoftClose, tcReSelConnect, tcFastQueryChr, tcQueryItemPrice);
  TChrAction = (caWalk, caRun, caHit, caSpell, caSitdown);
  TConnectionStep = (cnsLogin, cnsSelChr, cnsReSelChr, cnsPlay);
  TDirectDrawCreate = function(lpGUID: PGUID; out lplpDD: IDirectDraw; pUnkOuter: IUnknown): HRESULT; stdcall;

  TMovingItem = record
    Index: integer;
    Item: TClientItem;
  end;
  PTMovingItem = ^TMovingItem;

  TMiniViewObject = record
    Index: integer;
    x, y : integer;
    LastTick : longword;
  end;
  PTMiniViewObject = ^TMiniViewObject;

  TFrmMain = class(TForm)
    CSocket: TClientSocket;
    Timer1: TTimer;
    MouseTimer: TTimer;
    WaitMsgTimer: TTimer;
    SelChrWaitTimer: TTimer;
    CmdTimer: TTimer;
    MinTimer: TTimer;
    TimerRun: TTimer;
    TimerBrowserUpdate: TTimer;

    procedure DeviceInitialize(Sender: TObject; var Success: Boolean; var ErrorMsg: string);
    procedure FormCreate(Sender: TObject);
    procedure FormDestroy(Sender: TObject);
    procedure FormKeyDown(Sender: TObject; var Key: Word;
      Shift: TShiftState);
    procedure FormKeyPress(Sender: TObject; var Key: Char);
    procedure DeviceFinalize(Sender: TObject);
    procedure CSocketConnect(Sender: TObject; Socket: TCustomWinSocket);
    procedure CSocketDisconnect(Sender: TObject; Socket: TCustomWinSocket);
    procedure CSocketError(Sender: TObject; Socket: TCustomWinSocket;
      ErrorEvent: TErrorEvent; var ErrorCode: Integer);
    procedure CSocketRead(Sender: TObject; Socket: TCustomWinSocket);
    procedure Timer1Timer(Sender: TObject);
    procedure MsgProg;
    procedure MouseTimerTimer(Sender: TObject);
    procedure FormClose(Sender: TObject; var Action: TCloseAction);
    procedure DXDraw1DblClick(Sender: TObject);
    procedure WaitMsgTimerTimer(Sender: TObject);
    procedure SelChrWaitTimerTimer(Sender: TObject);
    procedure CmdTimerTimer(Sender: TObject);
    procedure MinTimerTimer(Sender: TObject);
    procedure CheckHackTimerTimer(Sender: TObject);
    procedure SendTimeTimerTimer(Sender: TObject);
    procedure DelitemProg;
    procedure MainCancelItemMoving;
    procedure FormKeyUp(Sender: TObject; var Key: Word;
      Shift: TShiftState);
    procedure TimerRunTimer(Sender: TObject);
    procedure FormActivate(Sender: TObject);
    procedure FormShow(Sender: TObject);
    procedure FormClick(Sender: TObject);
    procedure FormDblClick(Sender: TObject);
    procedure FormMouseDown(Sender: TObject; Button: TMouseButton; Shift: TShiftState; X, Y: Integer);
    procedure FormMouseMove(Sender: TObject; Shift: TShiftState; X, Y: Integer);
    procedure FormMouseUp(Sender: TObject; Button: TMouseButton; Shift: TShiftState; X, Y: Integer);
    procedure TimerBrowserUpdateTimer(Sender: TObject);
    procedure FormMouseWheel(Sender: TObject; Shift: TShiftState;
      WheelDelta: Integer; MousePos: TPoint; var Handled: Boolean);
  private
    SocStr, BufferStr: string;
    WarningLevel: integer;
    TimerCmd: TTimerCommand;
    MakeNewId: string; //Áö±Ý¸¸µé·Á°íÇÏ´Â ¾ÆÀÌµð

    ActionLockTime: longword;
    LastHitTime: longword;
    ActionFailLock: Boolean;
    FailAction, FailDir: integer;
    FailActionTime: longword;
    ActionKey: word;

    CursorSurface: TDirectDrawSurface;
    mousedowntime: longword;
    WaitingMsg: TDefaultMessage;
    WaitingStr: string;

    boSizeMove: Boolean;
    boInFocus: Boolean;
    m_Point: TPoint;
    FIDDraw: IDirectDraw;
    FDDrawHandle: THandle;
    FHotKeyId: Integer;
    FCriticalSection: TRTLCriticalSection;
    FboDisplayChange: Boolean;
    FboShowLogo: Boolean;
    FdwShowLogoTick: LongWord; 
    FnShowLogoIndex: Integer;
    m_FreeTextureTick: LongWord;
    m_FreeTextureIndex: Integer;
    FFrameRate: Integer;
    FInterval: Cardinal;
    FInterval2: Cardinal;
    FNowFrameRate: Integer;
    FOldTime: DWORD;
    FOldTime2: DWORD;
    
    procedure SpeedHackTimerTimer(Sender: TObject);
    procedure FindWHHackTimerTimer(Sender: TObject);
    procedure RunEffectTimerTimer(Sender: TObject); // FireDragon

    procedure ProcessKeyMessages;
    procedure ProcessActionMessages;
    procedure CheckSpeedHack (rtime: Longword);
    procedure DecodeMessagePacket (datablock: string);
    procedure ActionFailed;
    function  GetMagicByKey (Key: char): PTClientMagic;
    procedure UseMagic (tx, ty: integer; pcm: PTClientMagic);
    procedure UseMagicSpell (who, effnum, targetx, targety, magic_id: integer);
    procedure UseMagicFire (who, efftype, effnum, targetx, targety, target: integer);
    procedure UseMagicFireFail (who: integer);
    procedure CloseAllWindows;
    procedure ClearDropItems;
    procedure ResetGameVariables;
    procedure ChangeServerClearGameVariables;
    procedure _FormMouseDown(Sender: TObject; Button: TMouseButton; Shift: TShiftState; X, Y: Integer);

    function  CheckDoorAction (dx, dy: integer): Boolean;
    procedure ClientGetPasswdSuccess (body: string);

    procedure ClientGetSelectServer;
    procedure ClientGetReceiveChrs (nChrCnt: integer;body: string);
    procedure ClientGetStartPlay (body: string);
    procedure ClientGetReconnect (body: string);
    procedure ClientGetMapDescription (body: string);
    procedure ClientGetAdjustBonus (bonus: integer; body: string);
    procedure ClientGetAddItem (body: string);
    procedure ClientGetUpdateItem (body: string);
    procedure ClientGetDelItem (body: string; flag: integer );
    procedure ClientGetDelItems (body: string);
    procedure ClientGetBagItmes (body: string);
    procedure ClientGetDropItemFail (iname: string; sindex: integer);
    procedure ClientGetShowItem (itemid, x, y, looks: integer; body: string);
    procedure ClientGetHideItem (itemid, x, y: integer);
    procedure ClientGetSenduseItems (body: string);
    procedure ClientGetAddMagic (body: string);
    procedure ClientGetDelMagic (magid: integer);
    procedure ClientGetMyMagics (checksum: integer; body: string);
    procedure ClientGetMagicLvExp (magid, maglv, magtrain: integer);
    procedure ClientGetSound( soundid :integer);
    procedure ClientGetDuraChange (uidx, newdura, newduramax: integer);
    procedure ClientGetMerchantSay (merchant, face: integer; saying: string);
    procedure ClientGetSendGoodsList (merchant, count: integer; body: string);
    procedure ClientGetDecorationList (merchant, count: integer; body: string);
    procedure ClientGetJangwonList (Page, count: integer; body: string);
    procedure ClientGetGABoardList (ListNum, Page, MaxPage : integer; body: string);
    procedure ClientGetGABoardRead (body: string);
    procedure ClientGetSendMakeDrugList (merchant: integer; body: string);
    procedure ClientGetSendMakeItemList (merchant: integer; body: string);
    procedure ClientGetSendUserSell (merchant: integer);
    procedure ClientGetSendUserRepair (merchant: integer);
    procedure ClientGetSendUserStorage (merchant: integer);
    procedure ClientGetSendUserMaketSell (merchant: integer);
    procedure ClientGetSaveItemList (merchant,currentpage,maxpage: integer; bodystr: string);
    procedure ClientGetSendDetailGoodsList (merchant, count, topline: integer; bodystr: string);
    procedure ClientGetSendNotice (body: string);
    procedure ClientGetGroupMembers (bodystr: string);
    procedure ClientGetOpenGuildDlg (bodystr: string);
    procedure ClientGetSendGuildMemberList (body: string);
    procedure ClientGetDealRemoteAddItem (body: string);
    procedure ClientGetDealRemoteDelItem (body: string);
    procedure ClientGetReadMiniMap (mapindex: integer);
    procedure ClientGetChangeGuildName (body: string);
    procedure ClientGetSendUserState (body: string);

    procedure ClientGetUserInfo      (msg :TDefaultMessage;body: string);
    procedure ClientGetDelFriend     (msg :TDefaultMessage;body: string);
    procedure ClientGetFriendInfo    (msg :TDefaultMessage;body: string);
    procedure ClientGetFriendResult  (msg :TDefaultMessage;body: string);
    procedure ClientGetTagAlarm      (msg :TDefaultMessage;body: string);
    procedure ClientGetTagList       (msg :TDefaultMessage;body: string);
    procedure ClientGetTagInfo       (msg :TDefaultMessage;body: string);
    procedure ClientGetTagRejectList (msg :TDefaultMessage;body: string);
    procedure ClientGetTagRejectAdd  (msg :TDefaultMessage;body: string);
    procedure ClientGetTagRejectDelete(msg:TDefaultMessage;body: string);
    procedure ClientGetTagResult     (msg :TDefaultMessage;body: string);
    procedure ClientFriendSort       ( var datalist : TList ; firstname : string);

    procedure ClientGetLMList        (msg :TDefaultMessage;body : string);
    procedure ClientGetLMOptionChange(msg :TDefaultMessage);
    procedure ClientGetLMRequest     (msg :TDefaultMessage;body : string);
    procedure ClientGetLMResult      (msg :TDefaultMessage;body : string);
    procedure ClientGetLMDelete      (msg :TDefaultMessage;body : string);

    procedure RecalcNotReadCount;
    procedure RecalcOnlinUserCount;

    // Encrypt LoginId,PasswordmCharName
    function  GetLoginId     : String;
    procedure SetLogId      ( id   : String );
    function  GetLoginPasswd : String;
    procedure SetLoginPasswd( pw   : String );
    function  GetCharName    : String;
    procedure SetCharName   ( name : String );

  public
    Certification: integer;
    ActionLock: Boolean;
    SpeedHackTimer: TTimer;
    FindWHHackTimer: TTimer;
    RunEffectTimer: TTimer;
    WhisperName: string;

    // Encrypt LoginId,PasswordmCharName
    EncLoginId, EncLoginPasswd, EncCharName: string;
    EncEncLoginID : string;
    FLoginIDLock  : Boolean;

    property LoginId     : String read GetLoginId       write SetLogId;
    property LoginPasswd : String read GetLoginPasswd   write SetLoginPasswd;
    property CharName    : String read GetCharName      write SetCharName;

//    procedure InitializeClient;
    procedure WMSysCommand(var Message: TWMSysCommand); message WM_SYSCOMMAND;
//    procedure ProcOnIdle;
    procedure AppOnIdle(boInitialize: Boolean = False);
//    procedure AppOnIdle (Sender: TObject; var Done: Boolean);
    procedure AppLogout;
    procedure AppExit;
    procedure PrintScreenNow;
    procedure EatItem (idx: integer);

    procedure SendClientMessage (msg, Recog, param, tag, series: integer);
    procedure SendClientMessage2 (msg, Recog, param, tag, series: integer; str: string);
    procedure SendVersionNumber;
    procedure SendLogin (uid, passwd: string);
    procedure SendNewAccount (ue: TUserEntryInfo; ua: TUserEntryAddInfo);
    procedure SendUpdateAccount (ue: TUserEntryInfo; ua: TUserEntryAddInfo);
    procedure SendSelectServer (svname: string);
    procedure SendChgPw (id, passwd, newpasswd: string);
    procedure SendNewChr (uid, uname, shair, sjob, ssex: string);
    procedure SendQueryChr;
    procedure SendDelChr (chrname: string);
    procedure SendSelChr (chrname: string);
    procedure SendRunLogin;
    procedure SendSay (str: string);
    procedure SendActMsg (ident, x, y, dir: integer);
    procedure SendSpellMsg (ident, x, y, dir, target: integer);
    procedure SendQueryUserName (targetid, x, y: integer);
    procedure SendDropItem (name: string; itemserverindex: integer);
    procedure SendDropCountItem ( iname : String; mindex, icount :integer );// °ãÄ¡±â
    procedure SendPickup;
    procedure SendTakeOnItem (where: byte; itmindex: integer; itmname: string);
    procedure SendTakeOffItem (where: byte; itmindex: integer; itmname: string);
    procedure SendEat (idx, itmindex: integer; itmname: string);
    procedure UpgradeItem (ItemIndex, jewelIndex: integer; StrItem, StrJewel :String);
    procedure SendItemSumCount (OrgItemIndex, ExItemIndex: integer; StrOrgItem, StrExItem :String);
    procedure UpgradeItemResult (ItemIndex: integer; wResult : word; str: string);
    procedure SendButchAnimal (x, y, dir, actorid: integer);
    procedure SendMagicKeyChange (magid: integer; keych: char);
    procedure SendMerchantDlgSelect (merchant: integer; rstr: string);
    procedure SendQueryPrice (merchant, itemindex: integer; itemname: string);
    procedure SendQueryRepairCost (merchant, itemindex: integer; itemname: string);
    procedure SendSellItem (merchant, itemindex: integer; itemname: string; Count: word);
    procedure SendRepairItem (merchant, itemindex: integer; itemname: string);
    procedure SendStorageItem (merchant, itemindex: integer; itemname: string; Count :word);
    procedure SendMaketSellItem (merchant, itemindex: integer; price: string; Count :word);
    procedure SendGetDetailItem (merchant, menuindex: integer; itemname: string);
    procedure SendGetJangwonList (Page: integer);
    procedure SendGABoardRead (Body : String);
    procedure SendGetMarketPageList (merchant, pagetype: integer; itemname: string);
    procedure SendBuyMarket (merchant, sellindex: integer);
    procedure SendCancelMarket (merchant, sellindex: integer);
    procedure SendGetPayMarket (merchant, sellindex: integer);
    procedure SendMarketClose;
    procedure SendBuyItem (merchant, itemserverindex: integer; itemname: string; Count :word);
    procedure SendBuyDecoItem (merchant, DecoItemNum: integer);
    procedure SendTakeBackStorageItem (merchant, itemserverindex: integer; itemname: string; Count :word);
    procedure SendMakeDrugItem (merchant: integer; itemname: string);
    procedure SendMakeItemSel (merchant: integer; itemname: string);
    procedure SendMakeItem (merchant: integer; data: string);
    procedure SendDropGold (dropgold: integer);
    procedure SendGroupMode (onoff: Boolean);
    procedure SendCreateGroup (withwho: string);
    procedure SendWantMiniMap;
    procedure SendDealTry; //¾Õ¿¡ »ç¶÷ÀÌ ÀÖ´ÂÁö °Ë»ç
    procedure SendGuildDlg;
    procedure SendCancelDeal;
    procedure SendAddDealItem (ci: TClientItem);
    procedure SendDelDealItem (ci: TClientItem);
    procedure SendChangeDealGold (gold: integer);
    procedure SendDealEnd;
    procedure SendAddGroupMember (withwho: string);
    procedure SendDelGroupMember (withwho: string);
    procedure SendGuildHome;
    procedure SendGuildMemberList;
    procedure SendGuildAddMem (who: string);
    procedure SendGuildDelMem (who: string);
    procedure SendGuildUpdateNotice (notices: string);
    procedure SendGABoardUpdateNotice ( notice, CurPage: integer; bodyText: string);
    procedure SendGABoardModify ( CurPage : integer; bodyText: string);
    procedure SendGABoardDel(CurPage : integer; bodyText: string);
    procedure SendGABoardNoticeCheck;
    procedure SendGetGABoardList ( Page: integer );
    procedure SendGuildUpdateGrade (rankinfo: string);
    procedure SendSpeedHackUser(code: integer); //SpeedHaker »ç¿ëÀÚ¸¦ ¼­¹ö¿¡ Åëº¸ÇÑ´Ù.
    procedure SendAdjustBonus (remain: integer; babil: TNakedAbility);
    procedure UseNormalEffect (effnum, effx, effy: integer);
    procedure UseLoopNormalEffect (ActorID: integer; EffectIndex, LoopTime: Word);
    procedure AttackTarget (target: TActor);    
    // 2003/04/15 Ä£±¸, ÂÊÁö
    procedure SendAddFriend   (data: string ; FriendType : integer);
    procedure SendDelFriend   (data: string);
    procedure SendMail        (data: string);
    procedure SendReadingMail (data: string);
    procedure SendDelMail     (data: string);
    procedure SendLockMail    (data: string);
    procedure SendUnLockMail  (data: string);
    procedure SendMailList;
    procedure SendRejectList;
    procedure SendUpdateFriend(data: string);
    procedure SendAddReject   (data: string);
    procedure SendDelREject   (data: string);
//    procedure WndProc(var Message: TMessage); override;             // À©µµ¿ì ¸Þ½ÃÁö ¼ö½Å

    // ¿¬ÀÎ»çÁ¦
    procedure SendLMOPtionChange ( OptionType : integer ; Enable :integer);
    procedure SendLMRequest      ( ReqType : integer ; ReqSeq :integer);
    procedure SendLMSeparate     ( ReqType : integer ; data:String);
    // ³»°¡ µî·ÏÇÏ°í ÀÖ´Â Ä£±¸ÀÎ°¡ °Ë»ç
    function  IsMyMember      ( name : string ): Boolean;

    function  TargetInSwordLongAttackRange (ndir: integer): Boolean;
    function  TargetInSwordWideAttackRange (ndir: integer): Boolean;
    // 2003/03/15 ½Å±Ô¹«°ø
    function  TargetInSwordCrossAttackRange (ndir: integer): Boolean;
    procedure OnProgramException (Sender: TObject; E: Exception);
    procedure SendSocket (sendstr: string);
    function  ServerAcceptNextAction: Boolean;
    function  CanNextAction: Boolean;
    function  CanNextHit: Boolean;
    function  IsUnLockAction (action, adir: integer): Boolean;
    procedure ActiveCmdTimer (cmd: TTimerCommand);
    function  IsGroupMember (uname: string): Boolean;
    //ÐÂÔö¼Óº¯Êý
    procedure DeviceRender(Sender: TObject);
    procedure DisplayChange(boReset: Boolean);
    procedure DeviceNotifyEvent(Sender: TObject; Msg: Cardinal);
    Procedure WMMove(Var Message: TWMMove); Message WM_MOVE;
    procedure WMSetFocus(var WMessage: TMessage); message WM_SETFOCUS;
    procedure WMKillFocus(var WMessage: TMessage); message WM_KILLFOCUS;
    procedure WMHotKey(var Msg: Tmessage); message WM_HOTKEY;
    procedure WMTabKey(var WMessage: TMessage); message WM_USER + 1003;
    procedure ProcessFreeTexture;
    procedure FullScreen(boFull: Boolean);

    function GetMagicType(nMagicID: Integer): Byte;
  end;

//  procedure DecodeLicenseStrings (strlist: TStringlist);
//  function  CheckMirProgram: Boolean;
//  procedure PomiTextOut (dsurface: TDirectDrawSurface; x, y: integer; str: string);
  procedure WaitAndPass (msec: longword);
  procedure Delay(dwMilliseconds:DWORD);
  function  GetRGB (c256: byte): integer;
  procedure DebugOutStr (msg: string);
  procedure ChangeWalkHitValues (level, speed, weightsum, rundelay: integer);
//  procedure TogglePlaySoundEffect;
  function  GetFileCheckSum (flname: string): integer;
  function GlobalMemoryStatusEx(var lpBuffer: TMemoryStatusEx): BOOL; stdcall; external kernel32;
  procedure StringDivide(nDivideWidth: integer; var nDividedLine: integer; szSrc2: TStringList; var szResult: TStringList);overload;
  procedure StringDivide(nDivideWidth: integer; var nDividedLine: integer; szSrc2: PChar; var szResult: TStringList);overload;
  function SetMessageInfo(szSrc: String):String;
  procedure SetMagicExplain(nMagicID: Word; var szResult: TStringList);
  function LoadMagicInfo: Boolean;
  procedure SetEffectInfo(var pstEffect: TEffectSprinfo; dwFstFrm, dwEndFrm: DWORD; wDelay, wImgIdx, wEffectIdx: word;
             bSLightRadius, bLLightRadius,
             bSLightRColor, bSLightGColor, bSLightBColor,
             bLLightRColor, bLLightGColor, bLLightBColor: Byte;
             bMagicRColor: Byte = 255; bMagicGColor: Byte = 255; bMagicBColor: Byte = 255;
             bBlendType: Byte = _BLEND_LIGHTINV; bOpa: Byte = 0; bSwingCnt: Byte = 0; bDir: Byte = 0;
             bRepeat: Boolean = FALSE; bFixed: Boolean = TRUE; bShowLight: Boolean = TRUE; bTargetUse: Boolean = TRUE);
var
  FrmMain: TFrmMain;
  DScreen: TDrawScreen;
  IntroScene: TIntroScene;
  LoginScene: TLoginScene;
  SelectChrScene: TSelectChrScene;
  PlayScene: TPlayScene;
  LoadingScene: TLoading;
  LoginNoticeScene: TLoginNotice;
  DropedItemList: TList;
//  Sound: TSoundEngine;
  SoundManager: TSoundManager;
  ChangeFaceReadyList: TList;
  TerminateNow: Boolean;

  ViewList: array[1..MAXVIEWOBJECT] of TMiniViewObject;
  ViewListCount : Integer;

  MainParam1, MainParam2, MainParam3, MainParam4, MainParam5, MainParam6: string;

//  SoundList: TStringList;

  EventMan: TClEventManager;
  ServerCount: integer;
  ServerCaptionArr: array[0..31] of string;
  ServerNameArr: array[0..31] of string;
  ServerStatusArr: array[0..31] of string;

  ServerName: string;
  MapTitle: string;
  GuildName: string;
  GuildRankName: string;
  Map: TMap;
  MySelf: THumActor;
  MyDrawActor: THumActor;

  UseItems: array[0..12] of TClientItem;       //8->12
  ItemArr: array[0..MAXBAGITEMCL-1] of TClientItem;
  DealItems: array[0..9] of TClientItem;
  MakeItemArr: array[0..5] of TClientItem;
  DealRemoteItems: array[0..19] of TClientItem;
  SaveItemList: TList;
  MenuItemList: TList;
  DealGold, DealRemoteGold: integer;
  BoDealEnd: Boolean;
  DealWho: string;
//  MagicList: TList;
  m_xMyMagicList: array[0..7] of TList;
  MouseItem, MouseStateItem, MouseUserStateItem: TClientItem; //ÇöÀç ¸¶¿ì½º°¡ °¡¸®Å°°í ÀÖ´Â ¾ÆÀÌÅÛ
  FreeActorList: TList; //
  BoServerChanging: Boolean;
  BoBagLoaded: Boolean;
  BoOptionLoaded: Boolean;
  BoOneTimePassword: Boolean;

  FirstServerTime: longword;
  FirstClientTime: longword;
  //ServerTimeGap: int64;
  TimeFakeDetectCount: integer;
  MainAniCount: integer;
  ClientVersion: integer;

  FirstServerTimeChina: longword;
  FirstClientTimeChina: longword;
  TimeFakeDetectCountChina: integer;
  checkfaketime: longword;
  checkchecksumtime: longword;

  SHGetTime: longword;
  SHTimerTime: longword;
  SHFakeCount: integer;
  SHHitSpeedCount: integer;

  LatestClientTime2: longword;
  FirstClientTimerTime: longword; //timer ½Ã°£
  LatestClientTimerTime: longword;
  FirstClientGetTime: longword; //gettickcount ½Ã°£
  LatestClientGetTime: longword;
  TimeFakeDetectSum: integer;
  TimeFakeDetectTimer: integer;

  BonusPoint, SaveBonusPoint: integer;
  BonusTick: TNakedAbility;
  BonusAbil: TNakedAbility;
  NakedAbil: TNakedAbility;
  BonusAbilChg: TNakedAbility;

  SellDlgItem: TClientItem;
  SellDlgItemSellWait: TClientItem;
  DealDlgItem: TClientItem;
  MakingDlgItem: TClientItem;  
  BoQueryPrice: Boolean;
  QueryPriceTime: longword;
  SellPriceStr: string;

  BoOneClick: Boolean;

  BoFirstTime: Boolean;
  ConnectionStep: TConnectionStep;
  BoWellLogin: Boolean;
  ServerConnected: Boolean;
  BackgroundShow: Boolean;
  ViewFog: Boolean;
  Weather: integer;
  DayBright: integer;
  AreaStateValue: integer;
  MyHungryState: integer;
  BoPlaySoundEffect: Boolean;

  LastAttackTime: longword;
  LastMoveTime: longword;
  ItemMoving: Boolean;
  MovingItem: TMovingItem;
  DelTempItem: TClientItem;
  UpItemItem: TClientItem;
  WaitingUseItem: TMovingItem;
  EatingItem: TClientItem;
  EatTime: longword; //timeout...

  LatestStruckTime: longword;
  LatestSpellTime: longword;
  LatestFireHitTime: longword;
  LatestRushRushTime: longword;
  LatestHitTime: longword;
  LatestMagicTime: longword;
  DizzyDelayStart: longword;
  DizzyDelayTime: integer;

  DoFadeOut: Boolean;
  DoFadeIn: Boolean;
  FadeIndex: integer;
  DoFastFadeOut: Boolean;

  BoStopAfterAttack : Boolean;
  BoAttackSlow: Boolean;
  BoMoveSlow, BoMoveSlow2: Boolean;
  MoveSlowLevel: integer;
  MoveSlowValue: integer;  
  MapMoving: Boolean;
  MapMovingWait: Boolean;
//  CheckBadMapMode: Boolean;
  BoCheckSpeedHackDisplay: Boolean;
  BoWantMiniMap: Boolean;
  BoDrawMiniMap: Boolean;
  ViewMiniMapStyle: integer; //0:¾Èº¸ÀÓ  1: ¹ÝÅõ¸í  2: Á÷Á¢
  ViewMiniMapBlend: Boolean;
  ViewGeneralMapStyle: integer; //0:¾Èº¸ÀÓ  1: ¹ÝÅõ¸í  2: Á÷Á¢
//  PrevVMMStyle: integer;
  MiniMapIndex: integer;

  MCX: integer;
  MCY: integer;
  MouseX, MouseY: integer;

  TargetX: integer;
  TargetY: integer;
  TargetCret, FocusCret: TActor;
  MagicTarget, AutoTarget: TActor;
  TargetCase: Byte;
  BoAutoDig: Boolean;
  BoSelectMyself: Boolean;
  FocusItem: PTDropItem;
  MagicDelayTime: longword;
  MagicPKDelayTime: longword;
  ChrAction: TChrAction;
  NoDarkness: Boolean;
  RunReadyCount: integer;

  SoftClosed: Boolean;
  SelChrAddr: string;
  SelChrPort: integer;

  CurMerchant: integer;
  MDlgX, MDlgY: integer;
  changegroupmodetime: longword;
  dealactiontime: longword;
  querymsgtime: longword;
  DupSelection: integer;

  MsgYesIagree: string;
  MsgNoImnot: string;

  AllowGroup: Boolean;
  SellStHold: Boolean;
  GroupMembers: TStringList;
  GroupIdList: TList; // MonOpenHp

  FriendMembers : TList;
  BlackMembers  : TList;
  MailLists     : TList;
  BlockLists    : TStringList;
  MailAlarm     : Boolean;
  WantMailList  : Boolean;
  ConnectFriend : integer;
  ConnectBlack  : integer;
  NotReadMailCount : integer;

  fLover         : TRelationShipMgr;

  MySpeedPoint, MyHitPoint, MyAntiPoison, MyPoisonRecover,
  MyHealthRecover, MySpellRecover, MyAntiMagic: integer;

  AvailIDDay, AvailIDHour: word;
  AvailIPDay, AvailIPHour: word;

  CaptureSerial: integer;
  SendCount, ReceiveCount: integer;
  TestSendCount, TestReceiveCount: integer;
  SpellCount, SpellFailCount, FireCount: integer;
  DebugCount, DebugCount1, DebugCount2: integer;

  LastestClientGetTime: longword;
  ToolMenuHook: HHOOK;
  LastHookKey: integer;
  LastHookKeyTime: longword;

  BoNextTimePowerHit: Boolean;
  BoCanLongHit: Boolean;
  BoCanWideHit: Boolean;
  // 2003/03/15 ½Å±Ô¹«°ø
  BoCanCrossHit: Boolean;
  BoCanTwinHit: Boolean;
  BoNextTimeFireHit: Boolean;
  BoCanStoneHit: Boolean;

  //
  WalkCheckSum_fake1: integer;
  WalkCheckSum_fake2: integer;
  WalkCheckSum_fake3: integer;

  WalkCheckSum1: integer;
  HitCheckSum1: integer;

  HitCheckSum_fake1: integer;
  HitCheckSum_fake2: integer;
  HitCheckSum_fake3: integer;

  pWalkCheckSum2: ^integer;
  pHitCheckSum2: ^integer;

  pWalkCheckSum3: ^integer;
  pHitCheckSum3: ^integer;

  DayBright_fake: integer;
  DarkLevel_fake: integer;

  pDayBrightCheck: ^integer;
  pDarkLevelCheck: ^integer;

  pLocalFileCheckSum: ^integer;
  pClientCheckSum1: ^integer;
  pClientCheckSum2: ^integer;
  pClientCheckSum3: ^integer;

  BoSendFileCheckSum: Boolean;
  EffectNum: Byte;
  BoMsgDlgTimeCheck: Boolean;
  MsgDlgMaxStr: Byte;
  SpeedHackUse: Boolean;
  hfindWnd: Integer;
  BoViewEffect: Boolean;
  SkillBarNum: integer;
  BoSkillBarView: Boolean;
  SkillKeyMode: integer;
  DropItemView: Boolean;
  gCheckTime: longword;
  mirapphandle: HWnd;
  GameClose: Boolean;
  CouplePower: Boolean;
  TabClickTime: longword;
  AngelFastDraw: Boolean;
  StBeltAutoFill: Boolean;
  BtInDex: integer;
  BeltType: integer;
  gAutoRun: Boolean;

  Video: TMpeg;
  ReConnection: Boolean;
  CMsg: TCMsg;

  //HGE»æÍ¼¶¨Òå
  HGE: IHGE = nil;
  m_hwnd: hwnd;

implementation

uses
  FState, Bass, DirectXGraphics, D3DX81mo, uWilFile, HGEFont, HGEFontManager,
  Logo, Light0a, Light0b, Light0c, Light0d;

{$R *.DFM}

procedure StringDivide(nDivideWidth: integer; var nDividedLine: integer; szSrc2: TStringList; var szResult: TStringList);
var
  i, nCnt, len, aline: integer;
  temp ,szSrc: string;
begin
  nDividedLine := 0;
  for nCnt := 0 to szSrc2.Count - 1 do begin
    szSrc := szSrc2[nCnt];
    len := Length(szSrc);
    temp := '';
    i := 1;

    if szSrc = '' then szResult.Add('');

    while TRUE do begin
      if i > len then begin
        break;
      end;
      if byte(szSrc[i]) >= 128 then begin
        temp := temp + szSrc[i];
        Inc(i);
        if i <= len then
          temp := temp + szSrc[i]
        else
          break;
      end
      else
        temp := temp + szSrc[i];
      aline := FrmMain.Canvas.TextWidth(temp);
      if aline > nDivideWidth then begin
        Inc(nDividedLine);
        szResult.Add(temp);
        Delete(szSrc, 1, i);
        i := 0;
        len := Length(szSrc);
        temp := '';
      end;
      Inc(i);
    end;

    if temp <> '' then begin
      Inc(nDividedLine);
      szResult.Add(temp);
    end;
  end;
end;

procedure StringDivide(nDivideWidth: integer; var nDividedLine: integer; szSrc2: PChar; var szResult: TStringList);
var
  i, len, aline: integer;
  temp ,szSrc: string;
begin
  szSrc := StrPas(szSrc2);
  len := Length(szSrc);
  nDividedLine := 0;
  temp := '';
  i := 1;

  while TRUE do begin
    if i > len then break;
    if byte(szSrc[i]) >= 128 then begin
      temp := temp + szSrc[i];
      Inc(i);
      if i <= len then
        temp := temp + szSrc[i]
      else
        break;
    end
    else
      temp := temp + szSrc[i];
    aline := FrmMain.Canvas.TextWidth(temp);
    if aline > nDivideWidth then begin
      Inc(nDividedLine);
      szResult.Add(temp);
      Delete(szSrc, 1, i);
      i := 0;
      len := Length(szSrc);
      temp := '';
    end;
    Inc(i);
  end;

  if temp <> '' then begin
    Inc(nDividedLine);
    szResult.Add(temp);
  end;
end;

function SetMessageInfo(szSrc: String):String;
var
  i, len, aline, m_nDividedExplain: integer;
  dline, s_Explain: string;
  m_ExplainList: TStringList;
const
  BOXWIDTH = 280;
begin
  m_nDividedExplain := 0;
  s_Explain := '';
  m_ExplainList := TStringList.Create;

  aline := FrmMain.Canvas.TextWidth(szSrc);
  if aline > BOXWIDTH then begin
    StringDivide(BOXWIDTH, m_nDividedExplain, PChar(szSrc), m_ExplainList);
    for I := 0 to m_ExplainList.Count - 1 do begin
      s_Explain := s_Explain + m_ExplainList.Strings[I] + '\';
    end;
  end else begin
    s_Explain := szSrc;
  end;
  Result := s_Explain;
  FreeAndNil(m_ExplainList);
end;

procedure SetMagicExplain(nMagicID: Word; var szResult: TStringList);
var
  i, nNum: integer;
  str: string;
  boBegin: Boolean;
begin
  boBegin := False;
  szResult.Clear;
//  szResult := nil;
  for i:=0 to m_pszMagicExplain.Count-1 do begin
    str := Trim(m_pszMagicExplain[i]);
    if str <> '' then begin
      if str[1] = ';' then continue;
      if str[1] = '#' then begin
        if boBegin then break;

        str := Copy (str, 2, length(str)-1);
        nNum := Str_ToInt (str, -1);
        if nNum = nMagicID then boBegin := True;
      end else begin
        if boBegin then begin
          szResult.Add(str);
        end;
      end;
    end;
  end;
end;

procedure SetEffectInfo(var pstEffect: TEffectSprinfo; dwFstFrm, dwEndFrm: DWORD; wDelay, wImgIdx, wEffectIdx: word;
           bSLightRadius, bLLightRadius,
           bSLightRColor, bSLightGColor, bSLightBColor,
           bLLightRColor, bLLightGColor, bLLightBColor: Byte;
           bMagicRColor: Byte; bMagicGColor: Byte; bMagicBColor: Byte;
           bBlendType: Byte; bOpa: Byte; bSwingCnt: Byte; bDir: Byte;
           bRepeat: Boolean; bFixed: Boolean; bShowLight: Boolean; bTargetUse: Boolean);
begin
	pstEffect.dwFstFrm := dwFstFrm;
	pstEffect.dwEndFrm := dwEndFrm;
	pstEffect.wDelay	:= wDelay;
	pstEffect.wImgIdx  := wImgIdx;
	pstEffect.wEffectIdx := wEffectIdx;

	pstEffect.bLightRadius[0] := bSLightRadius;
	pstEffect.bLightRadius[1] := bLLightRadius;

	pstEffect.bLightColor[0][0] := bSLightRColor;
	pstEffect.bLightColor[0][1] := bSLightGColor;
	pstEffect.bLightColor[0][2] := bSLightBColor;

	pstEffect.bLightColor[1][0] := bLLightRColor;
	pstEffect.bLightColor[1][1] := bLLightGColor;
	pstEffect.bLightColor[1][2] := bLLightBColor;

	pstEffect.bMagicColor[0] := bMagicRColor;
	pstEffect.bMagicColor[1] := bMagicGColor;
	pstEffect.bMagicColor[2] := bMagicBColor;

	pstEffect.bBlendType	:= bBlendType;
	pstEffect.bOpa			:= bOpa;
	pstEffect.bSwingCnt	:= bSwingCnt;

	pstEffect.bDir			:= bDir;
	pstEffect.bRepeat		:= bRepeat;
	pstEffect.bFixed		:= bFixed;
	pstEffect.bShowLight	:= bShowLight;
	pstEffect.bTargetUse	:= bTargetUse;
end;

function LoadMagicInfo: Boolean;
var
  I, nStep, nArrayNum, nEffectCnt, II: integer;
  FileLength: Integer;
  TmpList: TStringList;
  pszLine, pszTmpLine, sType: string;
  bIsInserting: Boolean;
//  nValue : array [0..23] of Integer;
  nValueList: TStringList;
  stSprInfo: TEffectSprinfo;
begin
  Result := False;
	if not FileExists('MInfo.dat') then Exit;

  try
    TmpList := Decrypt('MInfo.dat');
  except
		TmpList.Free;
    Application.MessageBox(PChar('MInfo File Error.'), '[Error] - Legend of Mir III', MB_OK + MB_ICONERROR);
    Exit;
  end;

  nStep	:= -1;

  for I := 0 to TmpList.Count - 1 do begin
    pszLine := TmpList[I];
    if pszLine <> '' then begin
      if pszLine[1] = ';' then continue;
      if pszLine[1] = '/' then continue;
      if pszLine[1] = ' ' then continue;
      if pszLine[1] = '#' then begin
        pszLine := GetValidStr3 (pszLine, sType, [' ', #9]);

        if CompareText(sType, '#SPELL') = 0 then begin
          nStep := 0;
          nEffectCnt := StrToInt(pszLine);
//          FillChar(m_pstEffectSpr, sizeof(TEffectSprinfo) * (nEffectCnt + 1), #0);
          SetLength(m_pstEffectSpr, nEffectCnt);
          ZeroMemory(@m_pstEffectSpr[0], nEffectCnt * SizeOf(TEffectSprinfo) - 1);
          m_nEffectCnt := nEffectCnt;
        end else if CompareText(sType, '#MAGIC') = 0 then begin
          nStep := 1;
          nEffectCnt := StrToInt(pszLine);
//          FillChar(m_pstMagicSpr, sizeof(TEffectSprinfo) * (nEffectCnt + 1), #0);
          SetLength(m_pstMagicSpr, nEffectCnt);
          ZeroMemory(@m_pstMagicSpr[0], nEffectCnt * SizeOf(TEffectSprinfo) - 1);
          m_nMagicCnt := nEffectCnt;
        end else if CompareText(sType, '#EXPLOSION') = 0 then begin
          nStep := 2;
          nEffectCnt := StrToInt(pszLine);
//          FillChar(m_pstExplosionSpr, sizeof(TEffectSprinfo) * (nEffectCnt + 1), #0);
          SetLength(m_pstExplosionSpr, nEffectCnt);
          ZeroMemory(@m_pstExplosionSpr[0], nEffectCnt * SizeOf(TEffectSprinfo) - 1);
          m_nExplosionCnt := nEffectCnt;
        end;
      end else if pszLine[1] = '{' then begin
        if nStep <> -1 then begin
          bIsInserting := TRUE;
          nArrayNum	:= 0;
        end else begin
          // Error.
          Application.MessageBox(PChar('MInfo File Error.'), '[Error] - Legend of Mir III', MB_ICONERROR);
        end;
      end else if pszLine[1] = '}' then begin
        bIsInserting := FALSE;
        nStep := -1;
      end else if pszLine[1] = '[' then begin
        if bIsInserting or (nStep <> -1) then begin
          if nArrayNum < nEffectCnt then begin
            pszLine := ArrestStringEx (pszLine, '[', ']', pszTmpLine);
            // Value Analysys.
//            ZeroMemory(&stSprInfo, sizeof(EFFECTSPRINFO));
            FillChar(stSprInfo, sizeof(TEffectSprinfo), #0);

            nValueList := TStringList.Create;
            nValueList.CommaText := pszTmpLine;

            SetEffectInfo(stSprInfo, StrToInt(nValueList[0]), StrToInt(nValueList[1]), StrToInt(nValueList[2]), StrToInt(nValueList[3]), StrToInt(nValueList[4]),
                          StrToInt(nValueList[5]), StrToInt(nValueList[6]),
                          StrToInt(nValueList[7]), StrToInt(nValueList[8]), StrToInt(nValueList[9]),
                          StrToInt(nValueList[10]), StrToInt(nValueList[11]), StrToInt(nValueList[12]),
                          StrToInt(nValueList[13]), StrToInt(nValueList[14]), StrToInt(nValueList[15]),
                          StrToInt(nValueList[16]), StrToInt(nValueList[17]), StrToInt(nValueList[18]));

            case nStep of
              0: Move(stSprInfo, m_pstEffectSpr[nArrayNum], sizeof(TEffectSprinfo));
              1: Move(stSprInfo, m_pstMagicSpr[nArrayNum], sizeof(TEffectSprinfo));
              2: Move(stSprInfo, m_pstExplosionSpr[nArrayNum], sizeof(TEffectSprinfo));
            end;

            FreeAndNil(nValueList);
            Inc(nArrayNum);
          end else begin
            // Error.
            Application.MessageBox(PChar('MInfo File Error.'), '[Error] - Legend of Mir III', MB_ICONERROR);
          end;
        end else begin
          // Error.
          Application.MessageBox(PChar('MInfo File Error.'), '[Error] - Legend of Mir III', MB_ICONERROR);
        end;
      end;
    end;
  end;
  Result := True;
end;


//procedure DecodeLicenseStrings (strlist: TStringlist);
//var
//   i: integer;
//   str: string;
//begin
//   for i:=0 to strlist.Count-1 do begin
//      str := strlist[i];
//      strlist[i] := DecodeString (str);
//   end;
//end;

procedure ChangeWalkHitValues(level, speed, weightsum, rundelay: integer);
begin
  WalkCheckSum_fake1 := 10 + Random(1000);
  WalkCheckSum_fake2 := 100 + Random(1000);
  WalkCheckSum_fake3 := 1000 + Random(1000);
  WalkCheckSum1 := Random(100);
  pWalkCheckSum2^ := Random(10000);
  pWalkCheckSum3^ := Random(10000);

  HitCheckSum_fake1 := 10 + Random(1000);
  HitCheckSum_fake2 := 100 + Random(1000);
  HitCheckSum_fake3 := 1000 + Random(1000);

  HitCheckSum1 := level * HIT_INCLEVEL +
                  abs(speed) * HIT_INCSPEED +
                  weightsum +
                  rundelay;

  pHitCheckSum2^ := (HitCheckSum1 * 4) xor $FFFFFFFF;
  pHitCheckSum3^ := (HitCheckSum1 * 20) xor $FFFFFFFF;
end;

//function  CheckMirProgram: Boolean;
//var
//   pstr, cstr: array[0..255] of char;
//begin
//   Result := FALSE;
//   StrPCopy (pstr, 'Legend of Mir 2');
//   mirapphandle := FindWindow (nil, pstr);
//   if (mirapphandle <> 0) and (mirapphandle <> Application.Handle) then begin
//{$IFNDEF COMPILE}
//      SetActiveWindow(mirapphandle);
//      Result := TRUE;
//{$ENDIF}
//      exit;
//   end;
//end;

//procedure PomiTextOut (dsurface: TDirectDrawSurface; x, y: integer; str: string);
//var
//   i, n: integer;
//   d: TDirectDrawSurface;
//begin
//   for i:=1 to Length(str) do begin
//      n := byte(str[i]) - byte('0');
//      if n in [0..9] then begin //¼ýÀÚ¸¸ µÊ
//         d := g_WProgUse.Images[30 + n];
//         if d <> nil then
//            dsurface.Draw (x + i*8, y, d.ClientRect, d, TRUE);
//      end else begin
//         if str[i] = '-' then begin
//            d := g_WProgUse.Images[40];
//            if d <> nil then
//               dsurface.Draw (x + i*8, y, d.ClientRect, d, TRUE);
//         end;
//      end;
//   end;
//end;

procedure WaitAndPass(msec: longword);
var
  start: longword;
begin
  start := GetTickCount;
  while GetTickCount - start < msec do begin
    Application.ProcessMessages;
  end;
end;

procedure Delay(dwMilliseconds: DWORD);//Longint
var
  iStart, iStop: DWORD;
begin
  iStart := GetTickCount;
  repeat
    iStop := GetTickCount;
    Application.ProcessMessages;
  until (iStop - iStart) >= dwMilliseconds;
end;

function GetRGB(c256: byte): integer;
var
  i: integer;
begin
  Result := RGB(PotoPalette[c256].rgbRed,
                PotoPalette[c256].rgbGreen,
                PotoPalette[c256].rgbBlue);
end;

procedure DebugOutStr(msg: string);
var
  flname: string;
  fhandle: TextFile;
begin
  flname := '.\!debug.txt';
  if FileExists(flname) then begin
    AssignFile(fhandle, flname);
    Append(fhandle);
  end else begin
    AssignFile(fhandle, flname);
    Rewrite(fhandle);
  end;
  WriteLn(fhandle, TimeToStr(Time) + ' ' + msg);
  CloseFile(fhandle);
end;

function KeyboardHookProc(Code: Integer; WParam: Longint; var Msg: TMsg):
  Longint; stdcall;
begin
  if ((WParam = 9){ or (WParam = 13)}) and (LastHookKey = 18) and (GetTickCount - LastHookKeyTime < 500) then begin
    if FrmMain.WindowState <> wsMinimized then begin
      FrmMain.WindowState := wsMinimized;
    end else
      Result := CallNextHookEx(ToolMenuHook, Code, WParam, Longint(@Msg));
    exit;
  end;
  LastHookKey := WParam;
  LastHookKeyTime := GetTickCount;
  Result := CallNextHookEx(ToolMenuHook, Code, WParam, Longint(@Msg));
end;

//procedure TogglePlaySoundEffect;
//begin
//   BoPlaySoundEffect := not BoPlaySoundEffect;
//   if BoPlaySoundEffect then
//      DScreen.AddChatBoardString ('<À½Çâ È¿°ú ÄÔ>', clGreen, clWhite)
//   else
//      DScreen.AddChatBoardString ('<À½Çâ È¿°ú ²û>', clGreen, clWhite);
//end;

function GetFileCheckSum(flname: string): integer;
type
  pinteger = ^Integer;
var
  pbuf: PChar;
  i, n, handle, bsize, cval, csum: integer;
begin
  Result := 0;
  if FileExists(flname) then begin
    handle := FileOpen(flname, fmOpenRead or fmShareDenyNone);
    if handle > 0 then begin
      bsize := FileSeek(handle, 0, 2);
      GetMem(pbuf, (bsize + 3) div 4 * 4);
      FillChar(pbuf^, (bsize + 3) div 4 * 4, 0);
      FileSeek(handle, 0, 0);
      FileRead(handle, pbuf^, bsize);
      FileClose(handle);

      csum := 0;
      for i := 0 to (bsize + 3) div 4 - 1 do begin
        cval := pinteger(pbuf)^;
        pbuf := PChar(integer(pbuf) + 4);
        csum := csum xor cval;
      end;
      Result := csum;
    end;
  end;
end;

// Encrypt LoginId,PasswordmCharName
function TFrmMain.GetLoginId: string;
begin
  Result := '';
  if FLoginIDLock = false then begin
    Result := DecodeString(EncLoginId);
  end else begin
    if EncLoginId = DecodeString(EncEncLoginId) then
      Result := DecodeString(EncLoginId);
  end
end;

procedure TFrmMain.SetLogId(id: string);
begin
  if FLoginIDLock = false then begin
    EncLoginId := EncodeString(id);
    EncEncLoginId := EncodeString(EncLoginId);
  end;
end;

function TFrmMain.GetLoginPasswd: string;
begin
  Result := DecodeString(EncLoginPasswd);
end;

procedure TFrmMain.SetLoginPasswd(pw: string);
begin
  if FLoginIDLock = false then begin
    EncLoginPasswd := EncodeString(pw);
  end;
end;

function TFrmMain.GetCharName: string;
begin
  Result := DecodeString(EncCharName);
end;

procedure TFrmMain.SetCharName(name: string);
begin
  EncCharName := EncodeString(name);
end;

procedure TFrmMain.FormCreate(Sender: TObject);
var
  flname, str: string;
  ini: TIniFile;
  i: integer;
  compo: TComponent;
  fr : PTFriend;
  ma : PTMail;
begin
  DebugOutStr('----------------------- start ------------------------');
  ImageFont := TImageFont.Create;
  MainForm := Self;

  FInterval2 := 1;
  FInterval := 10;
  FOldTime := TimeGetTime;
  FOldTime2 := TimeGetTime;

  m_FreeTextureTick := GetTickCount;
  m_FreeTextureIndex := 0;

  FboShowLogo := True;
  FnShowLogoIndex := 0;
  FdwShowLogoTick := GetTickCount;

  FboDisplayChange := False;

  FDDrawHandle := 0;
  FIDDraw := nil;
  InitializeCriticalSection(FCriticalSection);

  HGE := HGECreate(HGE_VERSION);
  HGE.System_SetState(HGE_SCREENBPP, 16);

  boSizeMove := False;
  boInFocus := True;

  if g_boFullScreen then begin
    BorderStyle := bsNone;
    BorderIcons := [];
    ClientWidth := DEFSCREENWIDTH;
    ClientHeight := DEFSCREENHEIGHT;
    WindowState := wsMaximized;
    DisplayChange(False);
    m_Point := ClientOrigin;
  end
  else begin
    BorderStyle := bsSingle;
  end;

  GUIFScreenWidth := g_FScreenWidth;
  GUIFScreenHeight := g_FScreenHeight;

  HGE.System_SetState(HGE_WINDOWED, True);

  if not g_boFullScreen then begin
    ClientWidth := g_FScreenWidth;
    ClientHeight := g_FScreenHeight;
  end;

  HGE.System_SetState(HGE_FScreenWidth, DEFSCREENWIDTH);
  HGE.System_SetState(HGE_FScreenHeight, DEFSCREENHEIGHT);
  HGE.System_SetState(HGE_HIDEMOUSE, False);
  HGE.System_SetState(HGE_HWNDPARENT, Handle);
  HGE.System_SetState(HGE_SHOWSPLASH, False);
  HGE.System_SetState(HGE_HARDWARE, True);
  HGE.System_SetState(HGE_TEXTUREFILTER, True);
  HGE.System_SetState(HGE_FPS, HGEFPS_VSYNC); //HGEFPS_UNLIMITED(ÎÞÏÞÖÆ)ºÍHGEFPS_VSYNC(´¹Ö±Í¬²½),
  HGE.System_SetState(HGE_INITIALIZE, DeviceInitialize);
  HGE.System_SetState(HGE_FINALIZE, DeviceFinalize);
  HGE.System_SetState(HGE_NOTIFYEVENT, DeviceNotifyEvent);

  m_hwnd := HGE.System_GetState(HGE_HWNDPARENT);
  g_DWinMan := TDWinManager.Create(Self);
  LoadWMImagesLib(nil);

  m_Point := ClientOrigin;
  g_DXFont := TDXFont.Create;

  SoundManager := TSoundManager.Create(Self);
  SoundManager.Initialize;

  Video := TMPEG.Create(Self);
  //ÖØÁ¬±êÊ¶
  ReConnection := False;

  //³õÊ¼»¯¼ÓÔØ¿Í»§¶ËÎÄ¼þ
  CMsg := TCMsg.Create;

  //¼ÓÔØ¼¼ÄÜÐÅÏ¢ÎÄ¼þ
	if FileExists('Magic.Exp') then begin
    try
      m_pszMagicExplain := Decrypt('Magic.Exp');
    except
      m_pszMagicExplain.Free;
    end;
  end;

  Randomize;

  new(pWalkCheckSum2);
  new(pHitCheckSum2);
  new(pWalkCheckSum3);
  new(pHitCheckSum3);

  new(pDayBrightCheck);
  new(pDarkLevelCheck);
  new(pLocalFileCheckSum);
  new(pClientCheckSum1);
  new(pClientCheckSum2);
  new(pClientCheckSum3);

  ini := TIniFile.Create('.\Mir3.ini');
  if ini <> nil then begin
    SERVERADDR := ini.ReadString('Initial', 'ServerAddr', SERVERADDR);
    LocalLanguage := imSAlpha;
    MainParam1 := ini.ReadString('Initial', 'Param1', MainParam1);
    MainParam2 := ini.ReadString('Initial', 'Param2', MainParam2);
    MainParam3 := ini.ReadString('Initial', 'Param3', MainParam3);
    MainParam4 := ini.ReadString('Initial', 'Param4', MainParam4);
    MainParam5 := ini.ReadString('Initial', 'Param5', MainParam5);

    ServerCount := _MIN(32, ini.ReadInteger('Server', 'ServerCount', 1));
    for i := 0 to ServerCount - 1 do begin
      str := 'Server' + IntToStr(i + 1) + 'Caption';
      ServerCaptionArr[i] := ini.ReadString('Server', str, '');
      str := 'Server' + IntToStr(i + 1) + 'Name';
      ServerNameArr[i] := ini.ReadString('Server', str, '');
    end;
    ini.Free;
  end;

  ToolMenuHook := SetWindowsHookEx(WH_KEYBOARD, @KeyboardHookProc, 0, GetCurrentThreadID);

  ClientVersion := VERSION_YEAR * 10000 +
                   VERSION_MON * 100 +
                   VERSION_DAY;

//  SoundList := TStringList.Create;
//  flname := '.\SoundList.wwl';
//  LoadSoundList(flname);
//  SoundManager.ReadWaveFileList(flname);

  
//  BgmList := TList.Create;
//  flname := '.\BgmList.wwl';
//  SoundManager.ReadBgmFileList(flname);

  DScreen := TDrawScreen.Create;
  IntroScene := TIntroScene.Create;
  LoginScene := TLoginScene.Create;
  SelectChrScene := TSelectChrScene.Create;
  PlayScene := TPlayScene.Create;
  LoginNoticeScene := TLoginNotice.Create;
  LoadingScene := TLoading.Create;

  Map := TMap.Create;
  DropedItemList := TList.Create;
//  MagicList := TList.Create;

  for I := 0 to _MAX_TYPE_MAGIC - 1 do
    m_xMyMagicList[I] := TList.Create;

  FreeActorList := TList.Create;
  EventMan := TClEventManager.Create;
  ChangeFaceReadyList := TList.Create;

  ViewListCount := 0;
  FillChar(ViewList, sizeof(TMiniViewObject) * MAXVIEWOBJECT, #0);

  Myself := nil;
  FillChar(UseItems, sizeof(TClientItem) * 13, #0);
  FillChar(ItemArr, sizeof(TClientItem) * MAXBAGITEMCL, #0);
  FillChar(DealItems, sizeof(TClientItem) * 10, #0);
  FillChar(DealRemoteItems, sizeof(TClientItem) * 20, #0);
  SaveItemList := TList.Create;
  MenuItemList := TList.Create;
  WaitingUseItem.Item.S.Name := '';
  EatingItem.S.Name := '';

  TargetX := -1;
  TargetY := -1;
  TargetCret := nil;
  FocusCret := nil;
  FocusItem := nil;
  MagicTarget := nil;
  AutoTarget := nil;
  TargetCase := 1; // AutoTarget

  DebugCount := 0;
  DebugCount1 := 0;
  DebugCount2 := 0;
  TestSendCount := 0;
  TestReceiveCount := 0;
  BoServerChanging := FALSE;
  BoBagLoaded := FALSE;
  BoOptionLoaded := FALSE;
  BoAutoDig := FALSE;

  LatestClientTime2 := 0;
  FirstClientTime := 0;
  FirstServerTime := 0;
  FirstClientTimerTime := 0;
  LatestClientTimerTime := 0;
  FirstClientGetTime := 0;
  LatestClientGetTime := 0;

  TimeFakeDetectCount := 0;
  TimeFakeDetectTimer := 0;
  TimeFakeDetectSum := 0;
  TimeFakeDetectCountChina := 0;

  SHGetTime := 0;
  SHTimerTime := 0;
  SHFakeCount := 0;
  SHHitSpeedCount := 0;

  DayBright := 3; //¹ã
  DayBright_fake := DayBright;
  pDayBrightCheck^ := DayBright;
  BackgroundShow := FALSE;
  ViewFog := TRUE;
  Weather := 0;
  DarkLevel := 0;
  DarkLevel_fake := DarkLevel;
  pDarkLevelCheck^ := DarkLevel;

  AreaStateValue := 0;
  ConnectionStep := cnsLogin;
  BoWellLogin := FALSE;
  ServerConnected := FALSE;
  SocStr := '';
  WarningLevel := 0;
  ActionFailLock := FALSE;
  MapMoving := FALSE;
  MapMovingWait := FALSE;
//   CheckBadMapMode := FALSE;
  BoCheckSpeedHackDisplay := FALSE;
   //BoViewMiniMap := FALSE;
  BoWantMiniMap := FALSE;
  BoDrawMiniMap := FALSE;
  ViewMiniMapStyle := 0;  //0: ¾Èº¸ÀÓ, 1: ¹ÝÅõ¸í, 2: Á÷Á¢
  ViewMiniMapBlend := FALSE;
  ViewGeneralMapStyle := 0;
//   PrevVMMStyle := 1;
  FailDir := 0;
  FailAction := 0;
  FailActionTime := GetTickCount;
  DupSelection := 0;

  LastAttackTime := GetTickCount;
  LastMoveTime := GetTickCount;
  LatestSpellTime := GetTickCount;
  TabClickTime := GetTickCount;

  BoFirstTime := TRUE;
  ItemMoving := FALSE;
  DoFadeIn := FALSE;
  DoFadeOut := FALSE;
  DoFastFadeOut := FALSE;
  BoAttackSlow := FALSE;
  BoStopAfterAttack := FALSE;

  BoMoveSlow := FALSE;
  BoMoveSlow2 := FALSE;
  BoNextTimePowerHit := FALSE;
  BoCanLongHit := FALSE;
  BoCanWideHit := FALSE;
  BoCanCrossHit := FALSE;
  BoCanTwinHit := FALSE;
  BoNextTimeFireHit := FALSE;

  BoPlaySoundEffect := TRUE;

  NoDarkness := FALSE;
  SoftClosed := FALSE;
  BoQueryPrice := FALSE;
  SellPriceStr := '';

  AllowGroup := FALSE;
  SellStHold := FALSE;
  GroupMembers := TStringList.Create;
  GroupIdList := TList.Create; // MonOpenHp
  FriendMembers := TList.Create;
  BlackMembers := TList.Create;
  MailLists := TList.Create;
  BlockLists := TStringList.Create;
  MailAlarm := false;
  WantMailList := false;

  fLover := TRelationShipMgr.Create;

  MainWinHandle := handle;

  BoOneClick := FALSE;

  CSocket.Active := FALSE;
  CSocket.Address := SERVERADDR;
  if MainParam1 = '' then
    CSocket.Port := StrToInt(MainParam1)
  else begin
    CSocket.Port := 7000;
  end;
  if BO_FOR_TEST then
    CSocket.Address := TESTSERVERADDR;

  SpeedHackTimer := TTimer.Create(self);
  SpeedHackTimer.Interval := 250;
  SpeedHackTimer.Enabled := TRUE;
  SpeedHackTimer.OnTimer := SpeedHackTimerTimer;

  FindWHHackTimer := TTimer.Create(self);
  FindWHHackTimer.Interval := 5000;
  FindWHHackTimer.Enabled := TRUE;
  FindWHHackTimer.OnTimer := FindWHHackTimerTimer;

  RunEffectTimer := TTimer.Create(self); // ¿ë´øÁ¯ ³«·ÚÀÇ±æ, ¿ë¾ÏÀÇ±æ
  RunEffectTimer.Interval := 400;
  RunEffectTimer.Enabled := False;
  RunEffectTimer.OnTimer := RunEffectTimerTimer;
  RunEffectTimer.Tag := 555;

  pLocalFileCheckSum^ := GetFileCheckSum(ParamStr(0));
  BoSendFileCheckSum := FALSE;

  EffectNum := 0; // FireDragon

  EncLoginId := '';
  EncLoginPasswd := '';
  EncCharName := '';
  FLoginIDLock := false;

  //Î¯ÍÐÉÌÈË
  g_Market := TMarketItemManager.Create;

  BoMsgDlgTimeCheck := False;
  MsgDlgMaxStr := 30;
  SpeedHackUse := False;
  BoViewEffect := True;
  SkillBarNum := 1;
  BoSkillBarView := False;
  SkillKeyMode := 1;
  gCheckTime := GetTickcount;

  GameClose := False;
  CouplePower := False;
  StBeltAutoFill := False;
  BtInDex := -1;
  BeltType := 1;
  DropItemView := True;
  gAutoRun := False;
  AngelFastDraw := False;

//   StUpKey    := False;
//   StDownKey  := False;
//   StLeftKey  := False;
//   StRightKey := False;
  DebugOutStr ('----------------------- started ------------------------');

  Application.OnException := OnProgramException;
//   Application.OnIdle := AppOnIdle;

  FrmDlg := TFrmDlg.Create(nil);
end;

//procedure TFrmMain.InitializeClient;
//begin
(*   if TerminateNow then begin
//      CloseNPMon;
      FrmMain.Close;
      exit;
   end;     

   DxDraw1.AutoInitialize := TRUE;  //Initialize;

   //»ç¿îµå °ü·Ã ÃÊ±âÈ­
   if DxSound.Initialized then begin
      Sound := TSoundEngine.Create (DxSound.DSound);
   end else begin
      Sound := nil;
   end;

   cSocket.Active := TRUE;

   DebugOutStr ('----------------------- started ------------------------');

   Application.OnException := OnProgramException;
   Application.OnIdle := AppOnIdle;

   if not BoDebugModeScreen then begin
     if not (doFullScreen in DxDraw1.Options) then
       DxDraw1.Options := DxDraw1.Options + [doFullScreen];
   end;
//   else
//       DxDraw1.Options := DxDraw1.Options - [doFullScreen];
  *)
//end;

procedure TFrmMain.OnProgramException(Sender: TObject; E: Exception);
begin
  DebugOutStr(E.Message);
end;

procedure TFrmMain.WMSysCommand(var Message: TWMSysCommand);
begin
  if Message.CmdType = SC_MINIMIZE then begin
    boSizeMove := True;
    DisplayChange(True);
  end
  else if Message.CmdType = SC_RESTORE then begin
    boSizeMove := False;
    if g_boFullScreen then DisplayChange(False);
  end;
  inherited;
end;

procedure TFrmMain.FormDblClick(Sender: TObject);
var
  pt: TPoint;
begin
  GetCursorPos(pt);
  pt.X := pt.X - m_Point.X;
  pt.Y := pt.Y - m_Point.Y;
//   Windows.ScreenToClient(FrmMAin.Handle,pt);
  if g_DWinMan.DblClick(pt.X, pt.Y) then
    exit;
end;

procedure TFrmMain.FormDestroy(Sender: TObject);
var
  I: Integer;
begin
  if ToolMenuHook <> 0 then
    UnhookWindowsHookEx(ToolMenuHook);
   //SoundCloseProc;
   //DXTimer.Enabled := FALSE;
  Timer1.Enabled := FALSE;
  MinTimer.Enabled := FALSE;

  DScreen.Finalize;
  PlayScene.Finalize;
  LoginNoticeScene.Finalize;
  LoadingScene.Finalize;

  DScreen.Free;
  IntroScene.Free;
  LoginScene.Free;
  SelectChrScene.Free;
  PlayScene.Free;
  LoginNoticeScene.Free;
  LoadingScene.Free;
  SaveItemList.Free;
  MenuItemList.Free;

  UnLoadWMImagesLib();

  DebugOutStr('----------------------- closed -------------------------');
  Map.Free;
  DropedItemList.Free;
//  MagicList.Free;

  for I := 0 to _MAX_TYPE_MAGIC - 1 do
    m_xMyMagicList[I].Free;

  FreeActorList.Free;
  ChangeFaceReadyList.Free;
//   Sound.Free;
//  SoundList.Free;
  EventMan.Free;
  g_DWinMan.Free;
  DeleteCriticalSection(FCriticalSection);
  FrmDlg.Free;

  if RunEffectTimer <> nil then
    RunEffectTimer.Free;
  if FindWHHackTimer <> nil then
    FindWHHackTimer.Free;
  if SpeedHackTimer <> nil then
    SpeedHackTimer.Free;

  BASS_StreamFree(MusicHS);
  if MusicStream <> nil then
    MusicStream.Free;
  BASS_Free;

  HGE.System_Shutdown;
  HGE := nil;
  FreeAndNil(g_DXFont);
  FreeAndNil(ImageFont);

  LoginScene.m_xNoticeList.Free;
//  m_pszMagicExplain.Free;
  CMsg.Free;
   //À§Å¹»óÁ¡
  g_Market.Free;
end;

function ComposeColor(Dest, Src: TRGBQuad; Percent: Integer): TRGBQuad;
begin
  with Result do
  begin
    rgbRed := Src.rgbRed+((Dest.rgbRed-Src.rgbRed)*Percent div 256);
    rgbGreen := Src.rgbGreen+((Dest.rgbGreen-Src.rgbGreen)*Percent div 256);
    rgbBlue := Src.rgbBlue+((Dest.rgbBlue-Src.rgbBlue)*Percent div 256);
    rgbReserved := 0;
  end;
end;

//procedure TFrmMain.DXDraw1Initialize(Sender: TObject);
procedure TFrmMain.DeviceInitialize(Sender: TObject; var Success: Boolean; var ErrorMsg: string);
var
  nCount: Integer;
  FFileName:string;
  Stream: TFileStream;
  error: Integer;
begin
  HGETextures.InitializeTexturesInfo();

  FrmMain.Font.Name := CurFontName;
  FrmMain.Canvas.Font.Name := CurFontName;
  PlayScene.EdChat.Font.Name := CurFontName;
  FrmDlg.Font.Name := CurFontName;
  FrmDlg.Canvas.Font.Name := CurFontName;

  FrmMain.Font.Size := 9;
  FrmMain.Canvas.Font.Size := 9;
  PlayScene.EdChat.Font.Size := 9;
  FrmDlg.Font.Size := 9;
  FrmDlg.Canvas.Font.Size := 9;

  g_boInitialize := True;

  CliUtil.g_DXCanvas := TDXDrawCanvas.Create(g_DXFont);
  HGECanvas.g_DXCanvas := CliUtil.g_DXCanvas;
//  g_Font := Font;

  nCount := g_DXFont.CreateTexture;
  if nCount = -1 then begin
    Success := False;
    ErrorMsg := 'Texture Size Error';
    exit;
  end;

  CreateLogoSurface();
  CreateLight0aSurface();
  CreateLight0bSurface();
  CreateLight0cSurface();
  CreateLight0dSurface();

  InitWMImagesLib;

  while not FboShowLogo do begin
    AppOnIdle();
    Sleep(1);
    Application.ProcessMessages;
    if GetTickCount > FdwShowLogoTick then begin
      FdwShowLogoTick := GetTickCount + 25;
      Inc(FnShowLogoIndex, 5);
      if FnShowLogoIndex = 400 then begin
//        CSocket.Active := TRUE;
        break;
      end;
    end;
  end;

  SoundManager.Resume;

  AppOnIdle();
  FrmDlg.Initialize;
  LoginScene.Initialize;

  AppOnIdle();
  DScreen.Initialize;

  AppOnIdle();
  Success := PlayScene.Initialize;
  if not Success then begin
    ErrorMsg := 'PlayScene Initialize Error';
    exit;
  end;

  AppOnIdle();
  Success := g_DXFont.Initialize(CurFontName, 9);
  if not Success then begin
    ErrorMsg := 'Font Initialize Error';
    exit;
  end;

  Try
    AppOnIdle();
    ErrorMsg := 'Error Code = 1';
    LoadColorLevels();
    ErrorMsg := 'Error Code = 2';
    FBoShowLogo := True;
    ErrorMsg := 'Error Code = 3';
    g_boInitialize := False;
    ErrorMsg := 'Error Code = 4';
    TimerRun.Enabled := True;
    ErrorMsg := 'Error Code = 7';
    if g_boFullScreen then begin
      m_Point.X := 0;
      m_Point.Y := 0;
    end;

    DScreen.ChangeScene (stIntro);
    asm
      finit;//D3D³õÊ¼»¯ÒýÆðÊ±¼ä´íÎó, ÖØÐÂ³õÊ¼»¯¸¡µãµ¥Ôª½â¾öÎÊÌâ
    end;
//    if Win32Platform = VER_PLATFORM_WIN32_NT then begin //ÕûÀíÄÚ´æ
//      begin
//        SetProcessWorkingSetSize(GetCurrentProcess, $FFFFFFFF, $FFFFFFFF);
//        Application.ProcessMessages;
//      end;
//    end;
  except
    Success := False;
  end;
end;

//procedure TFrmMain.DXDraw1Finalize(Sender: TObject);
procedure TFrmMain.DeviceFinalize(Sender: TObject);
begin
  TimerRun.Enabled := False;
  g_DXCanvas := nil;
   //DXTimer.Enabled := FALSE;
end;

procedure TFrmMain.FormActivate(Sender: TObject);
var
  ErrorMsg, AFilePath: string;
  Int64Decompose: TInt64Decompose;
  MemoryStatus: TMemoryStatusEx;
  Reg: TRegistry;
  VersionInfo: TosversionInfo;
  DI: TD3DAdapterIdentifier8;
  ini: TIniFile;
  D3D: IDirect3D8;
{$IFNDEF DEBUG}
  nCount: Integer;
{$ENDIF}
begin
  if boFirstTime then begin
    if not CMsg.LoadMsg then begin
      Application.MessageBox(PChar('Message List File Error.'), '[Error] - Legend of Mir III', MB_ICONERROR);
      Application.Terminate;
      Exit;
    end;

    if not LoadMagicInfo then begin
      Application.MessageBox(PChar('MInfo File Error.'), '[Error] - Legend of Mir III', MB_ICONERROR);
      Application.Terminate;
      Exit;
    end;

    AFilePath := '.\Data\wemade.dat';
    Video.Play(AFilePath, 0, 60, 640, 420);
    TimerBrowserUpdate.Enabled := True;

    boFirstTime := FALSE;
    if not BASS_Init(-1, 44100, 0, 0, nil) then
    Application.MessageBox(PCHar('ÓÎÏ·ÒôÆµ³õÊ¼»¯Ê§°Ü, ½«ÎÞ·¨²¥·Å±³¾°ÒôÀÖ'), 'ÌáÊ¾ÐÅÏ¢', MB_OK + MB_ICONSTOP);

    if not HGE.System_Initiate then begin
      ErrorMsg := '----------------´íÎóÐÅÏ¢--------------------' + #13#10;
      ErrorMsg := ErrorMsg + HGE.System_GetErrorMessage + #13#10;
      ErrorMsg := ErrorMsg + #13#10;
      ErrorMsg := ErrorMsg + '----------------ÏµÍ³ÐÅÏ¢--------------------' + #13#10;
      VersionInfo.dwOSVersionInfoSize := SizeOf(TOSVersionInfo);
      Reg := TRegistry.Create;
      if Windows.GetVersionEx(VersionInfo) then begin
        Reg.RootKey := HKEY_LOCAL_MACHINE;
        case VersionInfo.dwPlatformId of
          VER_PLATFORM_WIN32s: begin
          
          end;
          VER_PLATFORM_WIN32_WINDOWS: begin
            if Reg.OpenKey('SOFTWARE\Microsoft\Windows\CurrentVersion', False) then begin
              ErrorMsg := ErrorMsg + '²Ù×÷ÏµÍ³: ' + Reg.ReadString('ProductName') + #13#10;
            end;
            Reg.CloseKey;
          end;
          VER_PLATFORM_WIN32_NT: begin
            if Reg.OpenKey('SOFTWARE\Microsoft\Windows NT\CurrentVersion', False) then begin
              ErrorMsg := ErrorMsg + '²Ù×÷ÏµÍ³: ' + Reg.ReadString('ProductName') + #13#10;
            end;
            Reg.CloseKey;
          end;
          VER_PLATFORM_WIN32_CE: begin

          end;
        end;
        ErrorMsg := ErrorMsg + 'ÏµÍ³°æ±¾: ' + Format('%d.%d.%d', [VersionInfo.dwMajorVersion, VersionInfo.dwMinorVersion, VersionInfo.dwBuildNumber]) + #13#10;
        ErrorMsg := ErrorMsg + '²¹¶¡°æ±¾: ' + VersionInfo.szCSDVersion + #13#10;
        if Reg.OpenKey('SOFTWARE\Microsoft\DirectX', False) then begin
          ErrorMsg := ErrorMsg + 'DirectX : ' + Reg.ReadString('Version') + #13#10;
        end;
        Reg.CloseKey;
      end;
      Reg.Free;

      D3D := Direct3DCreate8(D3D_SDK_VERSION);
      if D3D <> nil then begin
        Try
          D3D.GetAdapterIdentifier(D3DADAPTER_DEFAULT, D3DENUM_NO_WHQL_LEVEL, DI);
        Except
        End;
        ErrorMsg := ErrorMsg + #13#10;
        ErrorMsg := ErrorMsg + '----------------ÏÔ¿¨ÐÅÏ¢--------------------' + #13#10;
        ErrorMsg := ErrorMsg + 'ÏÔ¿¨Ãû³Æ: ' + DI.Description + #13#10;
        ErrorMsg := ErrorMsg + 'Çý¶¯³ÌÐò: ' + DI.Driver + #13#10;
        Int64Decompose.nInteger1 := DI.DriverVersionLowPart;
        Int64Decompose.nInteger2 := DI.DriverVersionHighPart;;
        ErrorMsg := ErrorMsg + Format('Çý¶¯°æ±¾: %d.%d.%d.%d', [
          HiWord(Int64Decompose.nInteger2),
            LoWord(Int64Decompose.nInteger2),
            HiWord(Int64Decompose.nInteger1),
            LoWord(Int64Decompose.nInteger1)]) + #13#10;

        ErrorMsg := ErrorMsg + '¿ÉÓÃÏÔ´æ: ' + IntToStr(HGE.AvailableTextureMem div 1024 div 1024) + 'M' + #13#10;
        ErrorMsg := ErrorMsg + 'ÎÆÀí´óÐ¡: ' + IntToStr(HGE.D3DCaps.MaxTextureWidth) + '*' + IntToStr(HGE.D3DCaps.MaxTextureHeight) + #13#10;
      end;
      D3D := nil;
      SafeFillChar(MemoryStatus, SizeOf(MemoryStatus), #0);
      MemoryStatus.dwLength := SizeOf(TMemoryStatus);
      GlobalMemoryStatusEx(MemoryStatus);
      ErrorMsg := ErrorMsg + #13#10;
      ErrorMsg := ErrorMsg + '----------------ÄÚ´æÐÅÏ¢--------------------' + #13#10;
      ErrorMsg := ErrorMsg + 'ÎïÀíÄÚ´æ: ' + intToStr(MemoryStatus.dwTotalPhys div 1024 div 1024) + 'M' + #13#10;
      ErrorMsg := ErrorMsg + '¿ÉÓÃÎïÀíÄÚ´æ: ' + intToStr(MemoryStatus.dwAvailPhys div 1024 div 1024) + 'M' + #13#10;
      ErrorMsg := ErrorMsg + 'ÐéÄâÄÚ´æ: ' + intToStr(MemoryStatus.dwTotalVirtual div 1024 div 1024) + 'M' + #13#10;
      ErrorMsg := ErrorMsg + '¿ÉÓÃÐéÄâÄÚ´æ: ' + intToStr(MemoryStatus.dwAvailVirtual div 1024 div 1024) + 'M' + #13#10;
      CopyStrToClipboard(ErrorMsg);
      ErrorMsg := ErrorMsg + #13#10;
      ErrorMsg := ErrorMsg + 'ÇëÊ¹ÓÃ Ctrl + V Õ³ÌùÒÔÉÏÐÅÏ¢·¢ËÍ¸øÓÎÏ·¹ÜÀíÔ±        ';
      //Visible := False;
      Application.MessageBox(PCHar(ErrorMsg), 'ÓÎÏ·³õÊ¼»¯Ê§°Ü', MB_OK + MB_ICONSTOP);
      close;
      HGE.System_Shutdown;
      Exit;
    end;
    MinTimer.Enabled := True;
  end;
end;

procedure TFrmMain.FormClick(Sender: TObject);
var
   pt: TPoint;
begin
   GetCursorPos (pt);
   pt.X := pt.X - m_Point.X;
   pt.Y := pt.Y - m_Point.Y;
//   Windows.ScreenToClient(FrmMAin.Handle,pt);
   if g_DWinMan.Click (pt.X, pt.Y) then exit;
end;

procedure TFrmMain.FormClose(Sender: TObject; var Action: TCloseAction);
begin
  if (ServerName <> '') and (CharName <> '') then
  Savebags ('.\Data\' + ServerName + '.' + CharName + '.itm', @ItemArr);
end;

//procedure TFrmMain.ProcOnIdle;
//var
//   done: Boolean;
//begin
//   AppOnIdle (self, done);
   //DXTimerTimer (self, 0);
//end;

procedure TFrmMain.AppOnIdle(boInitialize: Boolean = False);
var
  CanDraw: Boolean;
  t, t2: DWORD;   
  LagCount: Integer;
  I: Integer;
begin
  CanDraw := HGE.Gfx_CanBegin();
  g_boCanDraw := CanDraw and (not boSizeMove);

  if MusicHS >= BASS_ERROR_ENDED then begin
    if {boInFocus and }g_boCanDraw then begin
      if BASS_ChannelIsActive(MusicHS) = BASS_ACTIVE_PAUSED then begin
        ChangeBGMState(bgmPlay);
      end;
      g_boCanSound := True;
    end
    else begin
      if BASS_ChannelIsActive(MusicHS) = BASS_ACTIVE_PLAYING then begin
        ChangeBGMState(bgmPause);
      end;
      g_boCanSound := False;
      SilenceSound;
    end;
  end;

  g_boCanDraw := False;
  t := TimeGetTime;
  t2 := t - FOldTime;
  if t2 >= FInterval then begin
    FOldTime := t;

    LagCount := t2 div FInterval2;
    if LagCount < 1 then LagCount := 1;

    Inc(FNowFrameRate);

    i := Max(t - FOldTime2, 1);
    if i >= 1000 then begin
      FFrameRate := Round(FNowFrameRate * 1000 / i);
      FNowFrameRate := 0;
      FOldTime2 := t;
    end;
    g_boCanDraw := True;
  end;

  if not FboShowLogo then begin
    if g_boCanDraw then begin
      HGE.Gfx_BeginScene;
      HGE.Gfx_Clear($FF000000);
      HGE.RenderBatch;
      DeviceRender(nil);
      HGE.Gfx_EndScene;
    end;
  end else
  if not boInitialize then begin
    if DScreen.CurrentScene = PlayScene then begin
      PlayScene.BeginScene; //DebugOutStr('106');

      if g_boCanDraw then begin
        if BackgroundShow then begin
          HGE.Gfx_BeginScene(PlayScene.Background.Target);
          HGE.Gfx_Clear(0);
          HGE.RenderBatch;
          PlayScene.BackgroundSurface(nil);
          HGE.Gfx_EndScene;
        end;
//        if PlayScene.CanDrawTileMap then begin
//          HGE.Gfx_BeginScene(PlayScene.MapSurface.Target);
//          HGE.Gfx_Clear(0);
//          HGE.RenderBatch;
//          PlayScene.DrawTileMap(nil);
//          HGE.Gfx_EndScene;
//        end;
        if PlayScene.m_boPlayChange then begin
          HGE.Gfx_BeginScene(PlayScene.ObjSurface.Target);
          HGE.Gfx_Clear(0);
          HGE.RenderBatch;
          PlayScene.PlaySurface(nil);
          HGE.Gfx_EndScene;
        end;
        if ViewFog then begin
          HGE.Gfx_BeginScene(PlayScene.LigSurface.Target);
          HGE.Gfx_Clear(0);
          HGE.RenderBatch;
          PlayScene.LightSurface(nil);
          HGE.Gfx_EndScene;
        end;
        if Weather <> 0 then begin
          HGE.Gfx_BeginScene(PlayScene.WeaSurface.Target);
          HGE.Gfx_Clear(0);
          HGE.RenderBatch;
          PlayScene.WeatherSurface(nil);
          HGE.Gfx_EndScene;
        end;
        HGE.Gfx_BeginScene(PlayScene.MagSurface.Target);
        HGE.Gfx_Clear(0);
        HGE.RenderBatch;
        PlayScene.MagicSurface(nil);
        HGE.Gfx_EndScene;
      end;
    end;
    if g_boCanDraw then begin
      HGE.Gfx_BeginScene;
      HGE.Gfx_Clear(0);
      HGE.RenderBatch;
      DeviceRender(nil);
      HGE.Gfx_EndScene;
    end;
  end else begin
    if g_boCanDraw then begin
      HGE.Gfx_BeginScene;
      HGE.Gfx_Clear(0);
      HGE.RenderBatch;
      DeviceRender(nil);
      HGE.Gfx_EndScene;
    end;
  end;

  if Myself <> nil then begin
    if not BoDebugModeScreen and not Myself.Death then begin
      if GetTickCount - checkfaketime > 1000 then begin
        checkfaketime := GetTickCount;
        if not ((DayBright = DayBright_fake) and (DayBright = pDayBrightCheck^) and
                (DarkLevel = DarkLevel_fake) and (DarkLevel = pDarkLevelCheck^))
        then
          DScreen.AddSysMsg (IntToStr(DayBright) + '=' + IntToStr(DayBright_fake) + '=' + IntToStr(pDayBrightCheck^) + ', ' +
                             IntToStr(DarkLevel) + '=' + IntToStr(DarkLevel) + '=' + IntToStr(pDarkLevelCheck^));
           //FrmMain.Close;

        if DarkLevel <> 0 then begin
          if ViewFog = FALSE then begin
            FrmMain.Close;
          end;
        end;
      end;
    end;

    if (GetTickCount - checkchecksumtime > 5000) and not BoDebugModeScreen then begin
      checkchecksumtime := GetTickCount;
{$IFNDEF COMPILE}
      if (pLocalFileCheckSum^ <> pClientCheckSum1^) and
        (pLocalFileCheckSum^ <> pClientCheckSum2^) and
        (pLocalFileCheckSum^ <> pClientCheckSum3^) then
           FrmMain.Close;
{$ENDIF}
    end;
  end;
end;

procedure TFrmMain.AppLogout;
begin
  if mrOk = FrmDlg.DMessageDlg('ÄúÒªÍË³öÓÎÏ·Âð£¿', [mbOk, mbCancel]) then begin
    SendClientMessage(CM_SOFTCLOSE, 0, 0, 0, 0);
//    PlayScene.ClearActors;
    PlayScene.ScreenBright := 255;
    PlayScene.ChangeBright := 2;
    CloseAllWindows;
    if not BoOneClick then begin
      SoftClosed := TRUE;
      ActiveCmdTimer(tcSoftClose);
    end
    else begin
      ActiveCmdTimer(tcReSelConnect);
    end;
    if BoBagLoaded then
      Savebags('.\Data\' + ServerName + '.' + CharName + '.itm', @ItemArr);

    if BoOptionLoaded then
      SaveOption('.\Data\' + ServerName + '.' + CharName + '.Opt');
    BoOptionLoaded := FALSE;

    BoBagLoaded := FALSE;
  end;
end;

procedure TFrmMain.AppExit;
begin
  if mrOk = FrmDlg.DMessageDlg('ÊÇ·ñÍË³öÓÎÏ·?', [mbOk, mbCancel]) then begin
    if BoBagLoaded then
      Savebags('.\Data\' + ServerName + '.' + CharName + '.itm', @ItemArr);

    if BoOptionLoaded then
      SaveOption('.\Data\' + ServerName + '.' + CharName + '.Opt');

    BoOptionLoaded := FALSE;
    BoBagLoaded := FALSE;
    FrmMain.Close;
  end;
end;

procedure TFrmMain.PrintScreenNow;
  procedure BitmapBoldTextOut(Canvas: TCanvas; x, y, fcolor, bcolor: integer; str: string);
  var
    nLen: Integer;
    ChrBuff: PChar;
  begin
    if str = '' then
      Exit;
    nLen := Length(str);
    GetMem(ChrBuff, nLen);
    Move(str[1], ChrBuff^, nlen);
    Canvas.Font.Color := bcolor;
    TextOut(Canvas.Handle, x, y - 1, ChrBuff, nlen);
    TextOut(Canvas.Handle, x, y + 1, ChrBuff, nlen);
    TextOut(Canvas.Handle, x - 1, y, ChrBuff, nlen);
    TextOut(Canvas.Handle, x + 1, y, ChrBuff, nlen);
    TextOut(Canvas.Handle, x - 1, y - 1, ChrBuff, nlen);
    TextOut(Canvas.Handle, x + 1, y + 1, ChrBuff, nlen);
    TextOut(Canvas.Handle, x - 1, y + 1, ChrBuff, nlen);
    TextOut(Canvas.Handle, x + 1, y - 1, ChrBuff, nlen);
    Canvas.Font.Color := fcolor;
    TextOut(Canvas.Handle, x, y, ChrBuff, nlen);
    FreeMem(ChrBuff);
  end;
  function IntToStr2(n: Integer): string;
  begin
    if n < 10 then
      Result := '0' + IntToStr(n)
    else
      Result := IntToStr(n);
  end;
var
  flname, Dirname: string;
  JPG: TJPEGImage;
  BItmap: TBitmap;
  Surf: IDirect3DSurface8;
  n: Integer;
begin
  //PlaySoundEx(bmg_Camera);
  //HGE.Target_GetTexture()
  {Surf.GetDesc(Desc);
  HGE.GetD3DDevice.GetBackBuffer(0, D3DBACKBUFFER_TYPE_MONO, Surf);
  D3DXSaveSurfaceToFile('D:\Temp.bmp', D3DXIFF_BMP, Dest, nil, nil);
  Surf := nil;
  Dest := nil;  }

//  PlaySoundEx(bmg_Camera);
  if (HGE = nil) or (HGE.GetD3DDevice = nil) then
    exit;
  Dirname := GetCurrentDir;
  if Copy(Dirname, Length(Dirname), 1) <> '\' then
    Dirname := Dirname + '\';
  Dirname := Dirname + 'ScreenShot\';
  if not DirectoryExists(Dirname) then
    CreateDir(Dirname);
  while True do begin
    flname := Dirname + 'Images' + IntToStr2(CaptureSerial) + '.jpg';
    if not FileExists(flname) then
      break;
    Inc(CaptureSerial);
  end;

  HGE.GetD3DDevice.GetBackBuffer(0, D3DBACKBUFFER_TYPE_MONO, Surf);
  D3DXSaveSurfaceToFile(PChar(flname), D3DXIFF_BMP, Surf, nil, nil);
  Bitmap := TBitmap.Create;
  JPG := TJPEGImage.Create;
  try
    BItmap.LoadFromFile(flname);
    BItmap.Canvas.Font.Name := 'ËÎÌå';
    BItmap.Canvas.Font.Size := 9;
    n := 0;
    SetBkMode(Bitmap.Canvas.Handle, TRANSPARENT);
    BitmapBoldTextOut(Bitmap.Canvas, 2, 2, clWhite, clBlack, 'ÁúµÄ´«ËµII');
    if MySelf <> nil then begin
      BitmapBoldTextOut(Bitmap.Canvas, 2, 14, clWhite, clBlack, MySelf.UserName);
      BitmapBoldTextOut(Bitmap.Canvas, 2, 14 + 12, clWhite, clBlack, ServerName);
      Inc(n, 2);
    end;
    BitmapBoldTextOut(Bitmap.Canvas, 2, 14 + n * 12, clWhite, clBlack, FormatDateTime('YYYY-MM-DD HH:MM:SS', Now));
    JPG.Assign(Bitmap); //FormatDateTime('YYYY-MM-DD HH:MM:SS', Now)
    Jpg.CompressionQuality := 100;
    Jpg.SaveToFile(flname);
//    Bitmap.SaveToFile(flname);
    Bitmap.Free;
    JPG.Free;
    BItmap := nil;
    JPG := nil;
    //Bitmap.SaveToFile(flname);
   // if boShowPrintMsg then
    DScreen.AddSysMsg('[½ØÍ¼±£´æÎ»ÖÃ: ' + flname + ']');
  finally
    if BItmap <> nil then
      BItmap.Free;
    if JPG <> nil then
      JPG.Free;
  end;
end;

{------------------------------------------------------------}
procedure TFrmMain.ProcessKeyMessages;
begin
  case ActionKey of
    VK_F1, VK_F2, VK_F3, VK_F4, VK_F5, VK_F6, VK_F7, VK_F8, VK_F9, VK_F10, VK_F11, VK_F12:
     begin
       UseMagic (MouseX, MouseY, GetMagicByKey (char ((ActionKey-VK_F1) + byte('1')) )); //½ºÅ©¸° ÁÂÇ¥
        //DScreen.AddSysMsg ('KEY' + IntToStr(Random(10000)));
       ActionKey := 0;
       TargetX := -1;
       exit;
     end;
//      // 2003/08/20 =>¸¶¹ý´ÜÃàÅ° Ãß°¡  // AddMagicKey
//    VK_F1-100, VK_F2-100, VK_F3-100, VK_F4-100, VK_F5-100, VK_F6-100, VK_F7-100, VK_F8-100:
//      begin
//        UseMagic(MouseX, MouseY, GetMagicByKey(char((ActionKey - (VK_F1 - 100)) + byte('1') + 20))); //½ºÅ©¸° ÁÂÇ¥
//        ActionKey := 0;
//        TargetX := -1;
//        exit;
//      end;
  end;
end;

procedure TFrmMain.ProcessActionMessages;
var
  mx, my, dx, dy, crun: integer;
  ndir, adir, mdir: byte;
  bowalk, bostop: Boolean;
  stdcount: integer;
label
  LB_WALK;
begin
  if Myself = nil then exit;

   //Move
  if (TargetX >= 0) and CanNextAction and ServerAcceptNextAction then begin //ActionLockÀÌ Ç®¸®¸é, ActionLockÀº µ¿ÀÛÀÌ ³¡³ª±â Àü¿¡ Ç®¸°´Ù.
    if (TargetX <> Myself.XX) or (TargetY <> Myself.YY) then begin
      mx := Myself.XX;
      my := Myself.YY;
      dx := TargetX;
      dy := TargetY;
      ndir := GetNextDirection (mx, my, dx, dy);
      case ChrAction of
        caWalk: begin
          LB_WALK:
          //DScreen.AddSysMsg ('caWalk ' + IntToStr(Myself.XX) + ' ' +
          //                               IntToStr(Myself.YY) + ' ' +
          //                               IntToStr(TargetX) + ' ' +
          //                               IntToStr(TargetY));
          crun := Myself.CanWalk;
          if IsUnLockAction (CM_WALK, ndir) and (crun > 0) then begin
            GetNextPosXY (ndir, mx, my);
            bowalk := TRUE;
            bostop := FALSE;
            if not PlayScene.CanWalk (mx, my) then begin
              bowalk := FALSE;
              adir := 0;
              if not bowalk then begin  //ÀÔ±¸ °Ë»ç
                mx := Myself.XX;
                my := Myself.YY;
                GetNextPosXY (ndir, mx, my);
                if CheckDoorAction (mx, my) then
                  bostop := TRUE;
              end;
              if not bostop and not PlayScene.CrashMan(mx,my) then begin //»ç¶÷Àº ÀÚµ¿À¸·Î ÇÇÇÏÁö ¾ÊÀ½..
                mx := Myself.XX;
                my := Myself.YY;
                adir := PrivDir(ndir);
                GetNextPosXY (adir, mx, my);
                if not Map.CanMove(mx,my) then begin
                  mx := Myself.XX;
                  my := Myself.YY;
                  adir := NextDir (ndir);
                  GetNextPosXY (adir, mx, my);
                  if Map.CanMove(mx,my) then
                    bowalk := TRUE;
                end else
                  bowalk := TRUE;
              end;
              if bowalk then begin
                Myself.UpdateMsg (CM_WALK, mx, my, adir, 0, 0, '', 0);
                LastMoveTime := GetTickCount;
              end else begin
                mdir := GetNextDirection (Myself.XX, Myself.YY, dx, dy);
                if mdir <> Myself.Dir then
                  Myself.SendMsg (CM_TURN, Myself.XX, Myself.YY, mdir, 0, 0, '', 0);
                TargetX := -1;
              end;
            end else begin
              Myself.UpdateMsg (CM_WALK, mx, my, ndir, 0, 0, '', 0);  //Ç×»ó ¸¶Áö¸· ¸í·É¸¸ ±â¾ï
              LastMoveTime := GetTickCount;
            end;
          end else begin
            TargetX := -1;
          end;
        end;
        caRun: begin
          stdcount := 1;
          if (MySelf.State and $01000000) <> 0 then
            stdcount := 0;
          if RunReadyCount >= stdcount {1} then begin
            crun := Myself.CanRun;
            if (GetDistance (mx, my, dx, dy) >= 2) and (crun > 0) then begin
              if IsUnLockAction (CM_RUN, ndir) then begin
                GetNextRunXY (ndir, mx, my);
                if PlayScene.CanRun (Myself.XX, Myself.YY, mx, my) then begin
                  Myself.UpdateMsg (CM_RUN, mx, my, ndir, 0, 0, '', 0);
                  LastMoveTime := GetTickCount;
                end else begin
                  mx := Myself.XX;
                  my := Myself.YY;
                  goto LB_WALK;
                end;
              end else
                TargetX := -1;
            end else begin
              goto LB_WALK;
            end;
          end else begin
             Inc (RunReadyCount);
             goto LB_WALK;
          end;
        end;
      end;
    end;
  end;
  TargetX := -1; //ÇÑ¹ø¿¡ ÇÑÄ­¾¿..
  if Myself.RealActionMsg.Ident > 0 then begin
    FailAction := Myself.RealActionMsg.Ident; //½ÇÆÐÇÒ¶§ ´ëºñ
    FailDir := Myself.RealActionMsg.Dir;
    FailActionTime := GetTickCount;
    if Myself.RealActionMsg.Ident = CM_SPELL then begin
      SendSpellMsg (Myself.RealActionMsg.Ident,
                    Myself.RealActionMsg.X,
                    Myself.RealActionMsg.Y,
                    Myself.RealActionMsg.Dir,
                    Myself.RealActionMsg.State);
    end else begin
      SendActMsg (Myself.RealActionMsg.Ident,
                  Myself.RealActionMsg.X,
                  Myself.RealActionMsg.Y,
                  Myself.RealActionMsg.Dir);
    end;
    Myself.RealActionMsg.Ident := 0;

    if MDlgX <> -1 then begin
      if (abs(MDlgX-Myself.XX) >= 8) or (abs(MDlgY-Myself.YY) >= 8) then begin
        FrmDlg.CloseMDlg;
        FrmDlg.SafeCloseDlg;

{            if(FrmDlg.DMakeItemDlg.Visible) then
           FrmDlg.DMakeItemDlgOkClick(FrmDlg.DMakeItemDlgCancel, 0, 0);
        if FrmDlg.DItemMarketDlg.Visible then FrmDlg.CloseItemMarketDlg;
        if(FrmDlg.DJangwonListDlg.Visible) then
           FrmDlg.DJangwonCloseClick(FrmDlg.DJangwonClose, 0, 0);
        if(FrmDlg.DGABoardListDlg.Visible) then
           FrmDlg.DGABoardListCloseClick(FrmDlg.DGABoardListClose, 0, 0);
        if(FrmDlg.DGABoardDlg.Visible) then
           FrmDlg.DGABoardCloseClick(FrmDlg.DGABoardClose, 0, 0);}

        MDlgX := -1;
      end;
    end;
  end;
end;

procedure TFrmMain.FormKeyDown(Sender: TObject; var Key: Word;
  Shift: TShiftState);
var
  msg, wc, dir, mx, my: integer;
  ini: TIniFile;
begin
//  DScreen.AddChatBoardString ('FormKeyDown Key=> '+IntToStr(Key), clGreen, clWhite);
  case Key of
    VK_PAUSE: 
      begin
        Key := 0;
        PrintScreenNow;
      end;
    VK_RETURN:
      begin
        if (ssAlt in Shift) and (Key = VK_RETURN) then begin
          FullScreen(not g_boFullScreen);
          Exit;
        end;
      end;
  end;

  if g_DWinMan.KeyDown (Key, Shift) then exit;

  if (Myself = nil) or (DScreen.CurrentScene <> PlayScene) then exit;
  mx := Myself.XX;
  my := Myself.YY;
  case Key of
      VK_F1, VK_F2, VK_F3, VK_F4, VK_F5, VK_F6, VK_F7, VK_F8, VK_F9, VK_F10, VK_F11, VK_F12:
      begin
        if (GetTickCount - LatestSpellTime > (500 + MagicDelayTime)) then begin
          ActionKey := Key;
        end;
        Key := 0;
      end;

//      if SkillKeyMode = 1 then begin
//        if SkillBarNum = 1 then begin
//          if (GetTickCount - LatestSpellTime > (500 + MagicDelayTime)) then begin
//            ActionKey := Key;
//          end;
//          Key := 0;
//        end
//        else if SkillBarNum = 2 then begin
//          if (GetTickCount - LatestSpellTime > (500 + MagicDelayTime)) then begin
//            ActionKey := Key - 100;
//          end;
//          Key := 0;
//        end;
//      end
//      else if SkillKeyMode = 2 then begin
//        if ssCtrl in Shift then begin
//          if (GetTickCount - LatestSpellTime > (500 + MagicDelayTime)) then begin
//            ActionKey := Key - 100;
//          end;
//          Key := 0;
//        end
//        else begin
//          if (GetTickCount - LatestSpellTime > (500 + MagicDelayTime)) then begin
//            ActionKey := Key;
//          end;
//          Key := 0;
//        end;
//      end;

//      VK_F9:
//         begin
//            FrmDlg.OpenItemBag;
//         end;
//      VK_F10:
//         begin
//            FrmDlg.StatePage := 0;
//            FrmDlg.OpenMyStatus;
//         end;
//      VK_F11:
//         begin
//            FrmDlg.StatePage := 3;
//            FrmDlg.OpenMyStatus;
//         end;
{      VK_F12: // ½ºÅ³¹öÆ°¸ðµå º¯°æ
         begin
           if SkillKeyMode = 1 then begin
              SkillKeyMode := 2;
//              DScreen.AddChatBoardString ('<CtrlÅ° »ç¿ë>', clGreen, clWhite)
           end
           else if SkillKeyMode = 2 then begin
              SkillKeyMode := 1;
//              DScreen.AddChatBoardString ('<~Å° »ç¿ë>', clGreen, clWhite)
           end;
         end;}

    word('H'):  //´ëÀÎ°ø°Ý ¹æ¹ý
      begin
        if ssCtrl in Shift then begin
          SendSay('@°ø°Ý¹æ½Ä');
        end;
      end;
    word('A'):
      begin
        if ssCtrl in Shift then begin
          SendSay('@ÈÞ½Ä');
        end;
      end;
    word('X'):
      begin
        if MySelf = nil then exit;
        if ssAlt in Shift then begin

          FrmMain.SendClientMessage(CM_CANCLOSE, 0, 0, 0, 0);
        end;
      end;
    word('Q'):
      begin
        if MySelf = nil then
          exit;
        if ssAlt in Shift then begin
          if (GetTickCount - LatestStruckTime > 10000) and
            (GetTickCount - LatestMagicTime > 10000) and
            (GetTickCount - LatestHitTime > 10000)
            or (MySelf.Death) then begin
            AppExit;
          end
          else
            DScreen.AddChatBoardString('ÀüÅõÁß¿¡´Â Á¢¼ÓÀ» ²÷À» ¼ö ¾ø½À´Ï´Ù.', clYellow, clRed);
        end;
        if ssCtrl in Shift then begin
          FrmDlg.StatePage := 0;
          FrmDlg.OpenMyStatus;
        end;
      end;
    word('W'):
      begin
        if ssCtrl in Shift then begin
          FrmDlg.OpenItemBag;
        end;
      end;
  end;
   //Ã¤ÆÃÃ¢ Á¶Á¤
  case Key of
    VK_UP:
      with DScreen do begin
        if ChatBoardTop > 0 then Dec (ChatBoardTop);
      end;
    VK_DOWN:
      with DScreen do begin
        if ChatBoardTop < ChatStrs.Count - 1 then
          Inc(ChatBoardTop);
      end;
    VK_PRIOR:
      with DScreen do begin
        if ChatBoardTop > VIEWCHATLINE then
          ChatBoardTop := ChatBoardTop - VIEWCHATLINE
        else
          ChatBoardTop := 0;
      end;
    VK_NEXT:
      with DScreen do begin
        if ChatBoardTop + VIEWCHATLINE < ChatStrs.Count - 1 then
          ChatBoardTop := ChatBoardTop + VIEWCHATLINE
        else
          ChatBoardTop := ChatStrs.Count - 1;
        if ChatBoardTop < 0 then
          ChatBoardTop := 0;
      end;
  end;
end;

procedure TFrmMain.FormKeyPress(Sender: TObject; var Key: Char);
var
  i: integer;
begin

//  DScreen.AddChatBoardString ('FormKeyPress Key=> '+IntToStr(byte(Key)), clGreen, clWhite);

  if FrmDlg.DSelServerDlg.Visible then begin
//          MessageDlg ('FormKeyPress Key=> '+IntToStr(byte(Key)), mtWarning, [mbOk], 0);
    case Byte(Key) of
      Byte('1'):
        FrmDlg.DSServer1Click(FrmDlg.DSServer1, 1, 1);
      Byte('2'):
        FrmDlg.DSServer1Click(FrmDlg.DSServer2, 1, 1);
      Byte('3'):
        FrmDlg.DSServer1Click(FrmDlg.DSServer3, 1, 1);
      Byte('4'):
        FrmDlg.DSServer1Click(FrmDlg.DSServer4, 1, 1);
      Byte('5'):
        FrmDlg.DSServer1Click(FrmDlg.DSServer5, 1, 1);
      Byte('6'):
        FrmDlg.DSServer1Click(FrmDlg.DSServer6, 1, 1);
      Byte('7'):
        FrmDlg.DSServer1Click(FrmDlg.DSServer7, 1, 1);
      Byte('8'):
        FrmDlg.DSServer1Click(FrmDlg.DSServer8, 1, 1);
    end;
    Exit;
  end;

  if g_DWinMan.KeyPress(Key) then Exit;

  if (Byte(Key) = 13) and FrmDlg.DSelectChr.Visible and (not FrmDlg.DCreateChr.Visible) then begin
//      SelectChrScene.SelChrStartClick;
    FrmDlg.DscSelect1Click(FrmDlg.DscStart, 0, 0);
    Exit;
  end;

  if DScreen.CurrentScene = PlayScene then begin
    if PlayScene.EdChat.Visible then begin
         //°øÅëÀ¸·Î Ã³¸®ÇØ¾ß ÇÏ´Â °æ¿ì¸¸ ¾Æ·¡·Î ³Ñ¾î°¨
      Exit;
    end;
    case Byte(Key) of
      byte('W'), byte('w'):
        begin
          FrmDlg.OpenItemBag;
        end;
      byte('Q'), byte('q'):
        begin
          FrmDlg.OpenMyStatus;
        end;
      byte('E'), byte('e'):
        begin
          FrmDlg.OpenMyMagic;
        end;
//          byte('S'), byte('s'):
//             begin
//                FrmDlg.StatePage := 3;
//                FrmDlg.OpenMyStatus;
//             end;
//          byte('H'), byte('h'):  //´ëÀÎ°ø°Ý ¹æ¹ý
//             begin
//                   SendSay ('@°ø°Ý¹æ½Ä');
//             end;
      byte('A'), byte('a'):
        begin
          SendSay('@ÈÞ½Ä');
        end;
{          byte('K'), byte('k'): //ÀÓÆåÆ® º¸±â
             begin
                BoViewEffect := not BoViewEffect;
                if BoViewEffect then
                   DScreen.AddChatBoardString ('<È¿°ú¸¦ º¾´Ï´Ù>', clGreen, clWhite)
                else
                   DScreen.AddChatBoardString ('<È¿°ú¸¦ º¸Áö¾Ê½À´Ï´Ù>', clGreen, clWhite)
             end;}
      byte('N'), byte('n'):
        FrmDlg.DMyStateClick(FrmDlg.DOption, 0, 0);
      byte('`'):
        begin
          if SkillKeyMode = 1 then begin
            if SkillBarNum = 1 then
              SkillBarNum := 2
            else if SkillBarNum = 2 then
              SkillBarNum := 1;
            DScreen.AddChatBoardString('<¹«°ø¹Ù Ã¼ÀÎÁö ' + IntToStr(SkillBarNum) + '>', clGreen, clWhite)
          end;
        end;
      byte('B'), byte('b'):
        begin
          if not BoSkillBarView then begin
            BoSkillBarView := True;
            DScreen.AddChatBoardString('<¹«°ø¹Ù¸¦ º¾´Ï´Ù>', clGreen, clWhite)
          end
          else if BoSkillBarView then begin
            BoSkillBarView := False;
            DScreen.AddChatBoardString('<¹«°ø¹Ù¸¦ º¸Áö ¾Ê½À´Ï´Ù>', clGreen, clWhite)
          end;
        end;
      byte('V'), byte('v'):
        begin
          FrmDlg.DBotMiniMapClick(nil, 0, 0);
        end;
      byte('Y'), byte('y'):
        begin
          FrmDlg.DMiniMapBlendClick(nil, 0, 0);
        end;
      byte('T'), byte('t'):
        begin
          FrmDlg.DMiniMapShowClick(nil, 0, 0);
        end;
      byte('R'), byte('r'):
        begin
        end;
//          byte('B'), byte('b'):
//             begin
//                FrmMain.SendWantMiniMap;
//                if ViewGeneralMapStyle < 2 then begin
//                   Inc(ViewGeneralMapStyle);
//                end
//                else ViewGeneralMapStyle := 0;
//             end;
//          byte('U'), byte('u')://TestCode
//             begin
//                if AngelFastDraw then begin
//                   AngelFastDraw := False;
//                   DScreen.AddChatBoardString ('<¿ù·ÉÀÇ ºü¸¥ ±×¸®±â ¹æ½ÄÀ» »ç¿ëÇÏÁö ¾Ê½À´Ï´Ù.>', clGreen, clWhite)
//                end
//                else begin
//                   AngelFastDraw := True;
//                   DScreen.AddChatBoardString ('<¿ù·ÉÀÇ ºü¸¥ ±×¸®±â ¹æ½ÄÀ» »ç¿ëÇÕ´Ï´Ù.>', clGreen, clWhite)
//                end;
//             end;
      byte('D'), byte('d'):
        begin
          RunReadyCount := 0;
          if gAutoRun then begin
            gAutoRun := False;
            DScreen.AddChatBoardString('<ÀÚµ¿´Þ¸®±â¸¦ ÇÏÁö ¾Ê½À´Ï´Ù.>', clGreen, clWhite)
          end
          else begin
            gAutoRun := True;
            DScreen.AddChatBoardString('<ÀÚµ¿´Þ¸®±â¸¦ ÇÕ´Ï´Ù.>', clGreen, clWhite)
          end;
        end;
      byte('G'), byte('g'):
        begin
          FrmDlg.DBotGroupClick(nil, 0, 0);
        end;
      byte('C'), byte('c'):
        begin
          FrmDlg.DBotTradeClick(nil, 0, 0);
        end;
      byte('F'), byte('f'):
        begin
          FrmDlg.DBotGuildClick(nil, 0, 0);
        end;
                    // 2003/01/13 .. ´ÜÃàÅ° Ãß°¡ ======================== ³¡
          // 2003/04/15 Ä£±¸, ÂÊÁö
//          byte('W'), byte('w'):
//             begin
//                FrmDlg.DBotFriendClick(nil, 0, 0);
//             end;
      byte('Z'), byte('z'):
        begin
          if FrmDlg.DBeltWin.Visible then
            FrmDlg.DBeltWin.Visible := False
          else
            FrmDlg.DBeltWin.Visible := True;
        end;
      byte('J'), byte('j'):
        begin
          FrmDlg.DBotMemoClick(nil, 0, 0);
        end;
      byte('L'), byte('l'):
        begin
          FrmDlg.DBotMasterClick(nil, 0, 0);
        end;
      byte('1')..byte('6'):
        begin
          FrmDlg.SwapBujuk(byte(Key) - byte('1'));

          StBeltAutoFill := True;
          EatItem(byte(Key) - byte('1'));
        end;
      27: //ESC
        begin
          CloseAllWindows;
        end;
      byte(' '), 13: //Ã¤ÆÃ ¹Ú½º
        begin
          PlayScene.EdChat.Visible := TRUE;
          PlayScene.EdChat.SetFocus;
          SetImeMode(PlayScene.EdChat.Handle, imSHanguel);
          if FrmDlg.BoGuildChat then begin
            PlayScene.EdChat.Text := '!~';
            PlayScene.EdChat.SelStart := Length(PlayScene.EdChat.Text);
            PlayScene.EdChat.SelLength := 0;
          end
          else begin
            PlayScene.EdChat.Text := '';
          end;
        end;
      byte('@'), byte('!'), byte(','), byte('/'):
        begin
          PlayScene.EdChat.Visible := True;
          PlayScene.EdChat.SetFocus;
          LocalLanguage := imSHanguel;
          SetImeMode(PlayScene.EdChat.Handle, LocalLanguage);
          if Key = '/' then begin
            if WhisperName = '' then
              PlayScene.EdChat.Text := Key
            else if Length(WhisperName) > 2 then
              PlayScene.EdChat.Text := '/' + WhisperName + ' '
            else
              PlayScene.EdChat.Text := Key;
            PlayScene.EdChat.SelStart := Length(PlayScene.EdChat.Text);
            PlayScene.EdChat.SelLength := 0;
          end
          else if Key = ',' then begin
            if Copy(fLover.GetDisplay(0), Length(STR_LOVER) + 1, 6) <> '' then
              PlayScene.EdChat.Text := '¢½'
            else
              PlayScene.EdChat.Text := Key;
            PlayScene.EdChat.SelStart := Length(PlayScene.EdChat.Text);
            PlayScene.EdChat.SelLength := 0;
          end
          else begin
            PlayScene.EdChat.Text := Key;
            PlayScene.EdChat.SelStart := 1;
            PlayScene.EdChat.SelLength := 0;
          end;
          LocalLanguage := imSAlpha;
        end;
    end;
    Key := #0;
  end;
end;

function TFrmMain.GetMagicByKey(Key: char): PTClientMagic;
var
  I, II: integer;
  pm: PTClientMagic;
begin
  Result := nil;
  for I := 0 to _MAX_TYPE_MAGIC - 1 do begin
    for II := 0 to m_xMyMagicList[I].Count - 1 do begin
      pm := PTClientMagic(m_xMyMagicList[I][II]);
      if pm.Key = Key then begin
        Result := pm;
        break;
      end;
    end;
  end;
end;

procedure TFrmMain.UseMagic(tx, ty: integer; pcm: PTClientMagic); //tx, ty: ½ºÅ©¸° ÁÂÇ¥ÀÓ.
var
  tdir, targx, targy, targid: integer;
  pmag: PTUseMagicInfo;
  meff: TMagicEff;
  TempTarget: TActor;
  SpellSpend: word;
begin
  if pcm = nil then Exit;

   // 2003/03/15 ½Å±Ô¹«°ø Ãß°¡

//   if (pcm.Def.Spell + pcm.Def.DefSpell <= Myself.Abil.MP) or (pcm.Def.EffectType = 0) then begin
  SpellSpend := Round(pcm.Def.Spell / (pcm.Def.MaxTrainLevel + 1) * (pcm.Level + 1)) + pcm.Def.DefSpell;

  if (SpellSpend <= MySelf.Abil.MP) or (pcm.Def.EffectType = 0) then begin
    if pcm.Def.EffectType = 0 then begin //°Ë¹ý,È¿°ú¾øÀ½
         //°Ë¹ý Å°´Â Çàµ¿À» µû·Î ÇÏÁö ¾Ê´Â´Ù.
         //¼­¹ö¿¡ Á÷Á¢ Àü´ÞÇÑ´Ù.
         //if CanNextAction and ServerAcceptNextAction then begin

         //¿°È­°áÀº ÇÑ¹ø »ç¿ëÈÄ 9ÃÊ±îÁö´Â ´Ù½Ã ´­·ÁÁöÁö ¾Ê°Ô ÇÑ´Ù.
      if pcm.Def.MagicId = SWD_FIREHIT then begin //¿°È­°á
        if GetTickCount - LatestFireHitTime < 10 * 1000 then begin
          Exit;
        end;
      end;
                  //¹«ÅÂº¸´Â ÇÑ¹ø »ç¿ëÈÄ 3ÃÊ±îÁö´Â ´Ù½Ã ´­·ÁÁöÁö ¾Ê´Â´Ù.
      if pcm.Def.MagicId = SWD_RUSHRUSH then begin //¹«ÅÂº¸
        if GetTickCount - LatestRushRushTime < 3 * 1000 then begin
          Exit;
        end;
      end;
                  // 2003/07/15 ½Å±Ô¹«°ø Ãß°¡
         // ½Ö·æÂüÀº ÇÑ¹ø »ç¿ëÈÄ °ø°ÝÀ» ÁßÁöÇÑ´Ù
      if pcm.Def.MagicId = SWD_TWINHIT then begin
        BoStopAfterAttack := True;
//            if BoViewEffect then begin  //@@@@
        meff := TCharEffect.Create(210, 6, MySelf);
        meff.NextFrameTime := 120;
        meff.ImgLib := g_WMagicEx[1];
        PlayScene.EffectList.Add(meff);
//            end;
      end;

         //°Ë¹ýÀº µô·¹ÀÌ(500ms) ¾øÀÌ ´­·ÁÁø´Ù.
      if GetTickCount - LatestSpellTime > 500 then begin
        LatestSpellTime := GetTickCount;
        MagicDelayTime := 0; //pcm.Def.DelayTime;
        SendSpellMsg(CM_SPELL, MySelf.Dir{x}, 0, pcm.Def.MagicId, 0);
      end;
    end
    else begin

      tdir := GetFlyDirection(390, 175, tx, ty);

      if (pcm.Def.Effect in [2, 6, 7, 8, 11, 12, 14, 15, 17, 18, 20, 21, 22, 26, 27, 28, 29, 31, 35, 36, 40, 41, 44, 46, 47]) then begin
        TargetCase := 1;
        MagicTarget := FocusCret;
      end
      else begin
        TargetCase := 2;
        if (FocusCret <> nil) and (not FocusCret.Death) then begin
          if FocusCret.Race = 0 then begin
            TargetCase := 1;
            MagicTarget := FocusCret;
          end
          else
            AutoTarget := FocusCret;
        end;
        if (AutoTarget <> nil) and AutoTarget.Death then
          AutoTarget := nil;
      end;

      if TargetCase = 2 then
        TempTarget := AutoTarget
      else
        TempTarget := MagicTarget;

      if (TempTarget = nil) or (TempTarget <> FocusCret) then begin //¿ÀÅäÅ¸°Ù AutoTarget
        if (FocusCret <> nil) and (not FocusCret.Death) then
          TempTarget := FocusCret;
      end;

      if (not PlayScene.IsValidActor(TempTarget)) and (TempTarget <> nil) and (not TempTarget.Death) then
        TempTarget := nil;

      if TargetCase = 1 then
        MagicTarget := TempTarget
      else if TargetCase = 2 then
        AutoTarget := TempTarget;

      if TempTarget = nil then begin
        PlayScene.CXYfromMouseXYMid(tx, ty, targx, targy); // ¸¶¿ì½º ÁöÁ¤ ¸¶¹ý À§Ä¡ ¼öÁ¤
//            PlayScene.CXYfromMouseXY(tx, ty, targx, targy);
        targid := 0;
      end
      else begin
        targx := TempTarget.XX;
        targy := TempTarget.YY;
        targid := TempTarget.RecogId;
      end;

      if CanNextAction and ServerAcceptNextAction then begin
        LatestSpellTime := GetTickCount;  //¸¶¹ý »ç¿ë
        New(pmag);
        FillChar(pmag^, SizeOf(TUseMagicInfo), #0);
        pmag.EffectNumber := pcm.Def.Effect;
        pmag.MagicSerial := pcm.Def.MagicId;
        pmag.ServerMagicCode := 0;
        MagicDelayTime := 200 + pcm.Def.DelayTime; //´ÙÀ½ ¸¶¹ýÀ» »ç¿ëÇÒ¶§±îÁö ½¬´Â ½Ã°£

        case pmag.MagicSerial of
           //0, 2, 11, 12, 15, 16, 17, 13, 23, 24, 26, 27, 28, 29: ;
          2, 14, 15, 16, 17, 18, 19, 21,  //ºñ°ø°Ý ¸¶¹ý Á¦¿Ü
          12, 25, 26, 28, 29, 30, 31, 40, 41, 42, 43: ; //¿ù·É,ºÐ½Å Ãß°¡
          else LatestMagicTime := GetTickCount;
        end;

            //»ç¶÷À» °ø°ÝÇÏ´Â °æ¿ìÀÇ µô·¹ÀÌ
        MagicPKDelayTime := 0;
        if MagicTarget <> nil then
          if MagicTarget.Race = 0 then
            MagicPKDelayTime := 300 + Random(1100); //(600+200 + MagicDelayTime div 5);

        MySelf.SendMsg(CM_SPELL, targx, targy, tdir, Integer(pmag), targid, '', 0);
      end; // else
            //Dscreen.AddSysMsg ('Àá½ÃÈÄ¿¡ »ç¿ëÇÒ ¼ö ÀÖ½À´Ï´Ù.');
         //Inc (SpellCount);
    end;
  end
  else
    DScreen.AddSysMsg('¸¶·ÂÀÌ ¸ðÀÚ¶ø´Ï´Ù.');
end;

procedure TFrmMain.UseMagicSpell(who, effnum, targetx, targety, magic_id: integer);
var
  actor: TActor;
  adir: integer;
  pmag: PTUseMagicInfo;
begin
  actor := PlayScene.FindActor(who);
  if actor <> nil then begin
    adir := GetFlyDirection(actor.XX, actor.YY, targetx, targety);
    New(pmag);
    FillChar(pmag^, SizeOf(TUseMagicInfo), #0);
    pmag.EffectNumber := effnum; //magnum;
    pmag.ServerMagicCode := 0; //ÀÓ½Ã
    pmag.MagicSerial := magic_id;
    actor.SendMsg(SM_SPELL, 0, 0, adir, Integer(pmag), 0, '', 0);
    Inc(SpellCount);
  end else
    Inc(SpellFailCount);
end;

procedure TFrmMain.UseMagicFire(who, efftype, effnum, targetx, targety, target: integer);
var
  actor: TActor;
  adir, sound: integer;
  pmag: PTUseMagicInfo;
begin
  actor := PlayScene.FindActor(who);
  if actor <> nil then begin
    actor.SendMsg(SM_MAGICFIRE, target{111magid}, efftype, effnum, targetx, targety, '', sound);
      //if actor = Myself then Dec (SpellCount);
    if FireCount < SpellCount then
      Inc(FireCount);
  end;
end;

procedure TFrmMain.UseMagicFireFail(who: integer);
var
  actor: TActor;
begin
  actor := PlayScene.FindActor(who);
  if actor <> nil then begin
    actor.SendMsg(SM_MAGICFIRE_FAIL, 0, 0, 0, 0, 0, '', 0);
  end;
  MagicTarget := nil;
end;

procedure TFrmMain.UseNormalEffect(effnum, effx, effy: integer);
var
  meff, meff2: TMagicEff;
  k: integer;
  bofly: Boolean;
begin
  meff := nil;
  meff2 := nil;
  if not BoViewEffect then Exit;
  case effnum of
    NE_HEARTPALP:
      meff := TNormalDrawEffect.Create (effx, effy,
                                       g_WMon14Img,
                                       410,  //½ÃÀÛ À§Ä¡
                                       6,    //ÇÁ·¡ÀÓ
                                       120,  //µô·¹ÀÌ
                                       FALSE);
    NE_CLONESHOW: // ºÐ½Å¼ú
      meff := TNormalDrawEffect.Create (effx, effy,
                                       g_WMagicEx[1],
                                       670,  //½ÃÀÛ À§Ä¡
                                       10,    //ÇÁ·¡ÀÓ
                                       150,  //µô·¹ÀÌ
                                       True);
{      NE_CLONEHIDE: begin
         meff := TNormalDrawEffect.Create (effx, effy,
                                       WMagic2,
                                       690,  //½ÃÀÛ À§Ä¡
                                       10,    //ÇÁ·¡ÀÓ
                                       150,  //µô·¹ÀÌ
                                       True);
            PlaySound (48);
         end;}
    NE_THUNDER: begin
      PlayScene.NewMagic (nil, MAGIC_DUN_THUNDER, MAGIC_DUN_THUNDER, effx, effy, effx, effy, 0, mtThunder, FALSE, 30, bofly);
      PlaySound (8301);
    end;
    NE_FIRE: begin
      PlayScene.NewMagic (nil, MAGIC_DUN_FIRE1, MAGIC_DUN_FIRE1, effx, effy, effx, effy, 0, mtThunder, FALSE, 30, bofly);
      PlayScene.NewMagic (nil, MAGIC_DUN_FIRE2, MAGIC_DUN_FIRE2, effx, effy, effx, effy, 0, mtThunder, FALSE, 30, bofly);
      PlaySound (8302);
    end;
    NE_DRAGONFIRE: begin
      PlayScene.NewMagic (nil, MAGIC_DRAGONFIRE, MAGIC_DRAGONFIRE, effx, effy, effx, effy, 0, mtThunder, FALSE, 30, bofly);
      PlaySound (8207);
    end;

    NE_FIREBURN: begin
      PlayScene.NewMagic (nil, MAGIC_FIREBURN, MAGIC_FIREBURN, effx, effy, effx, effy, 0, mtThunder, FALSE, 30, bofly);
      PlaySound (8226);
    end;

    NE_FIRECIRCLE: begin// È­·æ±â¿°
      meff := TNormalDrawEffect.Create (effx, effy,
                                       g_WMagicEx[1],
                                       910,  //½ÃÀÛ À§Ä¡
                                       23,   //ÇÁ·¡ÀÓ
                                       100,  //µô·¹ÀÌ
                                       True);
    end;
    NE_POISONFOG: begin//ÀÌ¹«±â µ¶¾È°³ ÀÓÆåÆ® //####
      meff := TNormalDrawEffect.Create (effx, effy,
                                       g_WMagicEx[1],
                                       1280, //½ÃÀÛ À§Ä¡
                                       10,   //ÇÁ·¡ÀÓ
                                       100,  //µô·¹ÀÌ
                                       True);
      PlaySound (2446);//8102
    end;
    NE_SN_MOVEHIDE: begin//ÀÌ¹«±â ¿öÇÁ »ç¶óÁö´ÂÀÓÆåÆ®
      meff := TNormalDrawEffect.Create (effx, effy,
                                       g_WMagicEx[1],
                                       1300, //½ÃÀÛ À§Ä¡
                                       10,   //ÇÁ·¡ÀÓ
                                       80,   //µô·¹ÀÌ
                                       True);
      PlaySound (2447);//8103
    end;
    NE_SN_MOVESHOW: begin//ÀÌ¹«±â ¿öÇÁ ³ªÅ¸³ª´ÂÀÓÆåÆ®
      meff := TNormalDrawEffect.Create (effx, effy,
                                       g_WMagicEx[1],
                                       1310, //½ÃÀÛ À§Ä¡
                                       10,   //ÇÁ·¡ÀÓ
                                       80,   //µô·¹ÀÌ
                                       True);
      PlaySound (2447);//8103
    end;
    NE_SN_RELIVE: begin//ÀÌ¹«±â ºÎÈ° ÀÓÆåÆ®
      meff := TNormalDrawEffect.Create (effx, effy,
                                       g_WMagicEx[1],
                                       1330, //½ÃÀÛ À§Ä¡
                                       10,   //ÇÁ·¡ÀÓ
                                       100,  //µô·¹ÀÌ
                                       True);
      PlaySound (2448);//8104
    end;
    NE_FOX_MOVEHIDE: begin//¼ú»çºñ¿ù¿©¿ì »ç¶óÁö´Â ÀÓÆåÆ®
      meff := TNormalDrawEffect.Create (effx, effy,
                                       g_WMon24Img,
                                       800,  //½ÃÀÛ À§Ä¡
                                       10,   //ÇÁ·¡ÀÓ
                                       90,   //µô·¹ÀÌ
                                       True);
      PlaySound (109);
    end;
    NE_FOX_MOVESHOW: begin//¼ú»çºñ¿ù¿©¿ì ³ªÅ¸³ª´Â ÀÓÆåÆ®
      meff := TNormalDrawEffect.Create (effx, effy,
                                       g_WMon24Img,
                                       810,  //½ÃÀÛ À§Ä¡
                                       10,   //ÇÁ·¡ÀÓ
                                       90,   //µô·¹ÀÌ
                                       True);
      PlaySound (110);
    end;
    NE_SOULSTONE_HIT: begin//È£È¥¼® °ø°Ý ÀÓÆåÆ®
      meff := TNormalDrawEffect.Create (effx, effy,
                                       g_WMon24Img,
                                       1410, //½ÃÀÛ À§Ä¡
                                       10,   //ÇÁ·¡ÀÓ
                                       120,  //µô·¹ÀÌ
                                       True);
      PlaySound (157);//(442);
    end;
    NE_KINGSTONE_RECALL_1: begin//ºñ¿ùÃµÁÖ ¼ÒÈ¯, ºñ¿ùÃµÁÖ¿¡°Ô¿¡ »Ñ·ÁÁÜ
//      DScreen.AddChatBoardString ('ºñ¿ùÃµÁÖ ¼ÒÈ¯-Ä³¸¯ÀÓÆåÆ®', clYellow, clRed);
      meff := TNormalDrawEffect.Create (effx, effy,
                                       g_WMagicEx[1],
                                       1370, //½ÃÀÛ À§Ä¡
                                       10,   //ÇÁ·¡ÀÓ
                                       110,  //µô·¹ÀÌ
                                       True);
      PlaySound (2579);
    end;
    NE_KINGSTONE_RECALL_2: begin//ºñ¿ùÃµÁÖ ¼ÒÈ¯, Ä³¸¯¿¡°Ô »Ñ·ÁÁÜ
//      DScreen.AddChatBoardString ('ºñ¿ùÃµÁÖ ¼ÒÈ¯-Ä³¸¯ÀÓÆåÆ®', clYellow, clRed);
      meff := TNormalDrawEffect.Create (effx, effy,
                                       g_WMagicEx[1],
                                       1390, //½ÃÀÛ À§Ä¡
                                       10,   //ÇÁ·¡ÀÓ
                                       110,  //µô·¹ÀÌ
                                       True);
      PlaySound (10062);
    end;
    NE_KINGTURTLE_MOBSHOW: begin
      meff := TNormalDrawEffect.Create (effx, effy,
                                       g_WMon25Img,
                                       3080, //½ÃÀÛ À§Ä¡
                                       10,   //ÇÁ·¡ÀÓ
                                       90,   //µô·¹ÀÌ
                                       True);
      PlaySound (110);
    end;
    NE_DEFENCEEFFECT: begin
//         meff := TNormalDrawEffect.Create (effx, effy,
//                                       g_WEffectImg,
//                                       580, //½ÃÀÛ À§Ä¡
//                                       10,   //ÇÁ·¡ÀÓ
//                                       90,   //µô·¹ÀÌ
//                                       True);
//         PlaySound (110);
    end;
  end;
  if meff <> nil then begin
    meff.MagOwner := MySelf;  //³» ±âÁØÀ¸·Î
    PlayScene.EffectList.Add(meff);
  end;
  if meff2 <> nil then begin
    meff2.MagOwner := MySelf;  //³» ±âÁØÀ¸·Î
    PlayScene.EffectList.Add(meff2);
  end;
end;

procedure TFrmMain.UseLoopNormalEffect(ActorID: integer; EffectIndex, LoopTime: Word);
var
  actor: TActor;
  meff: TMagicEff;
begin
  meff := nil;
  if not BoViewEffect then Exit;
  actor := PlayScene.FindActor(ActorID);

  case EffectIndex of
    NE_CLONEHIDE: //ºÐ½Å¼ú-ºÐ½Å »ç¶óÁö´Â ÀÓÆåÆ®
      begin
        meff := TCharEffect.Create(690, 10, actor);
        meff.NextFrameTime := 150;
        meff.RepeatUntil := 0;
        PlaySound(48);
      end;
    NE_MONCAPTURE: //Æ÷½Â°Ë-Æ÷È¹ ÀÓÆåÆ®
      begin
        meff := TCharEffect.Create(1020, 8, actor);
        meff.NextFrameTime := 110;
        meff.RepeatUntil := GetTickCount + LoopTime;
        PlaySound(10475);
      end;
    NE_BLOODSUCK: //ÈíÇ÷¼ú-ÈíÀÔ ÀÓÆåÆ®
      begin
        meff := TCharEffect.Create(1090, 10, actor);
        meff.NextFrameTime := 100;
        meff.RepeatUntil := 0;
        PlaySound(10485);
      end;
    NE_FLOWERSEFFECT: //²É´Ù¹ß ÀÓÆåÆ®(¿¬ÀÎ)
      begin
        meff := TCharEffect.Create(1160, 20, actor);
        meff.NextFrameTime := 120;
        meff.RepeatUntil := GetTickCount + LoopTime;
        meff.Blend := False
      end;
    NE_LEVELUP:
      begin
        PlaySound(156);
        meff := TCharEffect.Create(1190, 20, actor);
        meff.NextFrameTime := 80;
        meff.RepeatUntil := GetTickCount + LoopTime;
      end;
    NE_RELIVE:
      begin
        Exit;
{         meff := TCharEffect.Create (1220, 20, actor);
         meff.NextFrameTime := 100;
         meff.RepeatUntil := GetTickCount + LoopTime;}
      end;
    NE_BIGFORCE: //¹«±ØÁø±â ÀÓÆåÆ®
      begin
        meff := TCharEffect.Create(160, 15, actor);
        meff.NextFrameTime := 80;
        meff.RepeatUntil := 0;
      end;
    NE_FOX_FIRE: //¼ú»çºñ¿ù¿©¿ì È­¿° ·çÇÁ ÀÓÆåÆ®
      begin
//      DScreen.AddChatBoardString ('¼ú»çÈ­¿° ·çÇÁ ÀÓÆåÆ®', clYellow, clRed);
        meff := TCharEffect.Create(1350, 10, actor);
        meff.NextFrameTime := 100;
        meff.RepeatUntil := GetTickCount + LoopTime;
      end;
    NE_SIDESTONE_PULL: //È£È¥±â¼® ´ç±â±â ÀÓÆåÆ®
      begin
        meff := TCharEffect.Create(1410, 10, actor);
        meff.NextFrameTime := 150;
        meff.RepeatUntil := GetTickCount + LoopTime;
        PlaySound(2547);
      end;
    NE_HAPPYBIRTHDAY:
      begin
        PlaySound(158);
//      DScreen.AddChatBoardString ('NE_HAPPYBIRTHDAY', clYellow, clRed);
        meff := TCharEffect.Create(1430, 30, actor);
        meff.NextFrameTime := 100;
        meff.RepeatUntil := GetTickCount + LoopTime;
      end;
    NE_KOREAFIGHTING:
      begin
        PlaySound(161);
        meff := TCharEffect.Create(1470, 30, actor);
        meff.NextFrameTime := 80;
        meff.RepeatUntil := GetTickCount + LoopTime;
      end;
  end;

  if meff <> nil then begin
    meff.ImgLib := g_WMagicEx[1];
    PlayScene.EffectList.Add(meff);
  end;
end;

procedure TFrmMain.EatItem(idx: integer);
begin
   // 2004/03/23 ³ë²öÀÏ¶§ º°µµ Ã³¸®
  if (MovingItem.Item.S.StdMode = 7) and ItemMoving then begin
    EatingItem := MovingItem.Item;
    FrmDlg.CancelItemMoving;
    EatTime := GetTickCount;
    SendEat(idx, EatingItem.MakeIndex, EatingItem.S.Name);
//      DScreen.AddChatBoardString ('SendEat-after', clYellow, clRed);
    ItemUseSound(EatingItem.S.StdMode);
    Exit;
  end;

  if idx in [0..MAXBAGITEMCL - 1] then begin
    if (EatingItem.S.Name <> '') and (GetTickCount - EatTime > 5 * 1000) then begin
      EatingItem.S.Name := '';
    end;
    if (EatingItem.S.Name = '') and (ItemArr[idx].S.Name <> '') and (ItemArr[idx].S.StdMode <= 3) then begin
      EatingItem := ItemArr[idx];
      ItemArr[idx].S.Name := '';

      if (ItemArr[idx].S.StdMode = 4) and (ItemArr[idx].S.Shape < 100) then begin
        //shape > 100ÀÌ¸é ¹­À½ ¾ÆÀÌÅÛ ÀÓ..
        if ItemArr[idx].S.Shape < 50 then begin
          if mrYes <> FrmDlg.DMessageDlg(ItemArr[idx].S.Name + 'À» ÀÍÈ÷½Ã°Ú½À´Ï±î?', [mbYes, mbNo]) then begin
            ItemArr[idx] := EatingItem;
            Exit;
          end;
        end
        else begin
          //shape > 50ÀÌ¸é ÁÖ¹® ¼­ Á¾·ù...
          if mrYes <> FrmDlg.DMessageDlg(ItemArr[idx].S.Name + 'À» »ç¿ëÇÏ½Ã°Ú½À´Ï±î?', [mbYes, mbNo]) then begin
            ItemArr[idx] := EatingItem;
            Exit;
          end;
        end;
      end;
      EatTime := GetTickCount;
      SendEat(idx, ItemArr[idx].MakeIndex, ItemArr[idx].S.Name);
      ItemUseSound(ItemArr[idx].S.StdMode);
    end;
  end
  else begin
    if (idx = -1) and ItemMoving then begin
      ItemMoving := False;
      EatingItem := MovingItem.Item;
      MovingItem.Item.S.Name := '';
      //Ã¥À» ÀÐ´Â °Í... ÀÍÈú °ÍÀÎ Áö ¹°¾îº»´Ù.
      if (EatingItem.S.StdMode = 4) and (EatingItem.S.Shape < 100) then begin
        //shape > 100ÀÌ¸é ¹­À½ ¾ÆÀÌÅÛ ÀÓ..
        if EatingItem.S.Shape < 50 then begin
          if mrYes <> FrmDlg.DMessageDlg('"' + EatingItem.S.Name + '"À»(¸¦) ÀÍÈ÷½Ã°Ú½À´Ï±î?', [mbYes, mbNo]) then begin
            AddItemBag(EatingItem);
            Exit;
          end;
        end
        else begin
          //shape > 50ÀÌ¸é ÁÖ¹® ¼­ Á¾·ù...
          if mrYes <> FrmDlg.DMessageDlg ('"' + EatingItem.S.Name + '"À»(¸¦) »ç¿ëÇÏ½Ã°Ú½À´Ï±î?', [mbYes, mbNo]) then begin
            AddItemBag (EatingItem);
            Exit;
          end;
        end;
      end;
      EatTime := GetTickCount;
      SendEat(idx, EatingItem.MakeIndex, EatingItem.S.Name);
      ItemUseSound(EatingItem.S.StdMode);
    end;
  end;
end;

function TFrmMain.TargetInSwordLongAttackRange(ndir: integer): Boolean;
var
  nx, ny: integer;
  actor: TActor;
begin
  Result := FALSE;
  GetFrontPosition(Myself.XX, Myself.YY, ndir, nx, ny);
  GetFrontPosition(nx, ny, ndir, nx, ny);
  if (abs(Myself.XX - nx) = 2) or (abs(Myself.YY - ny) = 2) then begin
    actor := PlayScene.FindActorXY(nx, ny);
    if actor <> nil then
      if not actor.Death then
        Result := TRUE;
  end;
end;

function TFrmMain.TargetInSwordWideAttackRange(ndir: integer): Boolean;
var
  nx, ny, rx, ry, mdir: integer;
  actor, ractor: TActor;
begin
  Result := FALSE;
  GetFrontPosition(Myself.XX, Myself.YY, ndir, nx, ny);
  actor := PlayScene.FindActorXY(nx, ny);

  mdir := (ndir + 1) mod 8;
  GetFrontPosition(Myself.XX, Myself.YY, mdir, rx, ry);
  ractor := PlayScene.FindActorXY(rx, ry);
  if ractor = nil then begin
    mdir := (ndir + 2) mod 8;
    GetFrontPosition(Myself.XX, Myself.YY, mdir, rx, ry);
    ractor := PlayScene.FindActorXY(rx, ry);
  end;
  if ractor = nil then begin
    mdir := (ndir + 7) mod 8;
    GetFrontPosition(Myself.XX, Myself.YY, mdir, rx, ry);
    ractor := PlayScene.FindActorXY(rx, ry);
  end;

  if (actor <> nil) and (ractor <> nil) then
    if not actor.Death and not ractor.Death then
      Result := True;
end;

function TFrmMain.TargetInSwordCrossAttackRange(ndir: integer): Boolean;
var
  nx, ny, rx, ry, mdir: integer;
  actor, ractor: TActor;
begin
  Result := FALSE;
  GetFrontPosition(Myself.XX, Myself.YY, ndir, nx, ny);
  actor := PlayScene.FindActorXY(nx, ny);

  mdir := (ndir + 1) mod 8;
  GetFrontPosition(Myself.XX, Myself.YY, mdir, rx, ry);
  ractor := PlayScene.FindActorXY(rx, ry);
  if ractor = nil then begin
    mdir := (ndir + 2) mod 8;
    GetFrontPosition(Myself.XX, Myself.YY, mdir, rx, ry);
    ractor := PlayScene.FindActorXY(rx, ry);
  end;
  if ractor = nil then begin
    mdir := (ndir + 3) mod 8;
    GetFrontPosition(Myself.XX, Myself.YY, mdir, rx, ry);
    ractor := PlayScene.FindActorXY(rx, ry);
  end;
  if ractor = nil then begin
    mdir := (ndir + 4) mod 8;
    GetFrontPosition(Myself.XX, Myself.YY, mdir, rx, ry);
    ractor := PlayScene.FindActorXY(rx, ry);
  end;
  if ractor = nil then begin
    mdir := (ndir + 5) mod 8;
    GetFrontPosition(MySelf.XX, MySelf.YY, mdir, rx, ry);
    ractor := PlayScene.FindActorXY(rx, ry);
  end;
  if ractor = nil then begin
    mdir := (ndir + 6) mod 8;
    GetFrontPosition(MySelf.XX, MySelf.YY, mdir, rx, ry);
    ractor := PlayScene.FindActorXY(rx, ry);
  end;
  if ractor = nil then begin
    mdir := (ndir + 7) mod 8;
    GetFrontPosition(MySelf.XX, MySelf.YY, mdir, rx, ry);
    ractor := PlayScene.FindActorXY(rx, ry);
  end;

  if (actor <> nil) and (ractor <> nil) then
    if not actor.Death and not ractor.Death then
      Result := True;
end;

procedure TFrmMain.AttackTarget(target: TActor);
var
  tdir, dx, dy, hitmsg: integer;
begin
  hitmsg := CM_HIT;
  if UseItems[U_WEAPON].S.StdMode = 6 then hitmsg := CM_HEAVYHIT;

  tdir := GetNextDirection(Myself.XX, Myself.YY, target.XX, target.YY);
  if (abs(Myself.XX-target.XX) <= 1) and (abs(Myself.YY-target.YY) <= 1) and (not target.Death) then begin
    if CanNextAction and ServerAcceptNextAction and CanNextHit then begin

      if BoNextTimeFireHit and (MySelf.Abil.MP >= 7) then begin
        BoNextTimeFireHit := False;
        hitmsg := CM_FIREHIT;
      end
      else if BoNextTimePowerHit then begin  //ÆÄ¿ö ¾ÆÅØÀÎ °æ¿ì, ¿¹µµ°Ë¹ý
        BoNextTimePowerHit := False;
        hitmsg := CM_POWERHIT;
      end
      else if BoCanTwinHit and (MySelf.Abil.MP >= 10) then begin
        hitmsg := CM_TWINHIT;
      end
      else if BoCanWideHit and (MySelf.Abil.MP >= 3) then begin //and (TargetInSwordWideAttackRange (tdir)) then begin  //·Õ ¾ÆÅØÀÎ °æ¿ì, ¹Ý¿ù°Ë¹ý
        hitmsg := CM_WIDEHIT;
      end
      else if BoCanCrossHit and (MySelf.Abil.MP >= 6) then begin
        hitmsg := CM_CROSSHIT;
      end
      else if BoCanLongHit and (TargetInSwordLongAttackRange(tdir)) then begin  //·Õ ¾ÆÅØÀÎ °æ¿ì, ¾î°Ë¼ú
        hitmsg := CM_LONGHIT;
      end;

         //if ((target.Race <> 0) and (target.Race <> RCC_GUARD)) or (ssShift in Shift) then //»ç¶÷À» ½Ç¼ö·Î °ø°ÝÇÏ´Â °ÍÀ» ¸·À½
      MySelf.SendMsg(hitmsg, MySelf.XX, MySelf.YY, tdir, 0, 0, '', 0);
      LatestHitTime := GetTickCount;
    end;
    LastAttackTime := GetTickCount;
  end else begin
      //ºñµµ¸¦ µé°í ÀÖÀ¸¸é
      //if (UseItems[U_WEAPON].S.Shape = 6) and (target <> nil) then begin
      //   Myself.SendMsg (CM_THROW, Myself.XX, Myself.YY, tdir, integer(target), 0, '', 0);
      //   TargetCret := nil;  //ÇÑ¹ø¸¸ °ø°Ý
      //end else begin
    ChrAction := caWalk;
    GetBackPosition(target.XX, target.YY, tdir, dx, dy);
    TargetX := dx;
    TargetY := dy;
      //end;
  end;
end;

procedure TFrmMain._FormMouseDown(Sender: TObject; Button: TMouseButton; Shift:
  TShiftState; X, Y: Integer);
var
  tdir, nx, ny, hitmsg, sel: integer;
  target: TActor;
begin
  ActionKey := 0;
  MouseX := X;
  MouseY := Y;
  BoAutoDig := FALSE;

  if (Button = mbRight) and ItemMoving then begin
    FrmDlg.CancelItemMoving;
    Exit;
  end;
  if g_DWinMan.MouseDown(Button, Shift, X, Y) then Exit;
  if (MySelf = nil) or (DScreen.CurrentScene <> PlayScene) then Exit;

  if ssMiddle in Shift then begin
    RunReadyCount := 0;
    if gAutoRun then begin
      gAutoRun := False;
      DScreen.AddChatBoardString('<ÀÚµ¿´Þ¸®±â¸¦ ÇÏÁö ¾Ê½À´Ï´Ù.>', clGreen, clWhite)
    end
    else begin
      gAutoRun := True;
      DScreen.AddChatBoardString('<ÀÚµ¿´Þ¸®±â¸¦ ÇÕ´Ï´Ù.>', clGreen, clWhite)
    end;
  end
  else if ssLeft in Shift then begin
    if gAutoRun then begin
      RunReadyCount := 0;
      gAutoRun := False;
      DScreen.AddChatBoardString('<ÀÚµ¿´Þ¸®±â¸¦ ÇÏÁö ¾Ê½À´Ï´Ù.>', clGreen, clWhite)
    end;
  end;

  if (ssRight in Shift) or gAutoRun then begin
    if Shift = [ssRight] then Inc(DupSelection);  //°ãÃÆÀ» °æ¿ì ¼±ÅÃ
    target := PlayScene.GetAttackFocusCharacter(X, Y, DupSelection, sel, False); //¸ðµÎ..
    if DupSelection <> sel then DupSelection := 0;
    if target <> nil then begin
      if ssCtrl in Shift then begin
        if GetTickCount - LastMoveTime > 1000 then begin
          if (target.Race = 0) and (not target.Death) then begin
            SendClientMessage(CM_QUERYUSERSTATE, target.RecogId, target.XX, target.YY, 0);
            Exit;
          end;
        end;
      end;
    end
    else
      DupSelection := 0;

    PlayScene.CXYfromMouseXY(X, Y, MCX, MCY);
    if (Abs(MySelf.XX - MCX) <= 2) and (Abs(MySelf.YY - MCY) <= 2) then begin //¹æÇâÅÏ
      tdir := GetNextDirection(MySelf.XX, MySelf.YY, MCX, MCY);
      if CanNextAction and ServerAcceptNextAction then begin
        MySelf.SendMsg(CM_TURN, MySelf.XX, MySelf.YY, tdir, 0, 0, '', 0);
      end;
    end
    else begin //¶Ù±â
      ChrAction := caRun;
      TargetX := MCX;
      TargetY := MCY;
      Exit;
    end;
  end;

  if ssLeft in Shift {Button = mbLeft} then begin
    target := PlayScene.GetAttackFocusCharacter(X, Y, DupSelection, sel, True); //»ì¾ÆÀÖ´Â ³ð¸¸..
    PlayScene.CXYfromMouseXY(X, Y, MCX, MCY);
    TargetCret := nil;

    if (UseItems[U_WEAPON].S.Name <> '') and (target = nil) then begin
      if UseItems[U_WEAPON].S.Shape = 19 then begin //°î±ªÀÌ
        tdir := GetNextDirection(MySelf.XX, MySelf.YY, MCX, MCY);
        GetFrontPosition(MySelf.XX, MySelf.YY, tdir, nx, ny);
        if not Map.CanMove(nx, ny) or (ssShift in Shift) then begin  //¸ø °¡´Â °÷Àº °î±ªÀÌÁú ÇÑ´Ù.
          if CanNextAction and ServerAcceptNextAction and CanNextHit then begin
            MySelf.SendMsg(CM_HIT + 1, MySelf.XX, MySelf.YY, tdir, 0, 0, '', 0);
          end;
          BoAutoDig := True;
          Exit;
        end;
      end;
    end;

    if ssAlt in Shift then begin
      tdir := GetNextDirection(MySelf.XX, MySelf.YY, MCX, MCY);
      if CanNextAction and ServerAcceptNextAction then begin
        target := PlayScene.ButchAnimal(MCX, MCY);
        if target <> nil then begin
          SendButchAnimal(MCX, MCY, tdir, target.RecogId);
          MySelf.SendMsg(CM_SITDOWN, MySelf.XX, MySelf.YY, tdir, 0, 0, '', 0); //ÀÚ¼¼´Â °°À½
          Exit;
        end;
        MySelf.SendMsg(CM_SITDOWN, MySelf.XX, MySelf.YY, tdir, 0, 0, '', 0);
      end;
      TargetX := -1;
    end
    else begin
      if (target <> nil) or (ssShift in Shift) then begin
        TargetX := -1;
        if target <> nil then begin
          if GetTickCount - LastMoveTime > 1500 then begin
            if target.Race = RCC_MERCHANT then begin
              SendClientMessage(CM_CLICKNPC, target.RecogId, 0, 0, 0);
              Exit;
            end;
          end;

          if (not target.Death) then begin //
            TargetCret := target;
            if ((target.Race <> 0) and
                (target.Race <> RCC_GUARD) and
                (target.Race <> RCC_GUARD2) and
                (target.Race <> RCC_MERCHANT) and
                (pos('(', target.UserName) = 0) //ÁÖÀÎ¾ø´Â ¸÷(ÀÖ´Â ¸÷Àº °­Á¦°ø°Ý ÇØ¾ßÇÔ)
               )
               or (ssShift in Shift) //»ç¶÷À» ½Ç¼ö·Î °ø°ÝÇÏ´Â °ÍÀ» ¸·À½
               or (target.NameColor = ENEMYCOLOR)   //ÀûÀº ÀÚµ¿ °ø°ÝÀÌ µÊ
            then begin
               MagicTarget := target; // AutoTarget
               AutoTarget := target; // AutoTarget
               AttackTarget (target);
               LatestHitTime := GetTickCount;
               // 2003/07/15 ½Å±Ô¹«°ø Ãß°¡
               if BoStopAfterAttack then begin
                  BoStopAfterAttack := FALSE;
                  TargetCret := nil;
                  AutoTarget := nil;
               end;
               if (target <> nil) and (ssShift in Shift) then
                  AutoTarget := nil;
            end;
          end;
        end
        else begin
          tdir := GetNextDirection (Myself.XX, Myself.YY, MCX, MCY);
          if CanNextAction and ServerAcceptNextAction and CanNextHit then begin
            hitmsg := CM_HIT;//+Random(3);
            if BoCanLongHit and (TargetInSwordLongAttackRange (tdir)) then begin  //·Õ ¾ÆÅØÀÎ °æ¿ì
              hitmsg := CM_LONGHIT;
            end;
            if BoCanWideHit and (Myself.Abil.MP >= 3) and (TargetInSwordWideAttackRange (tdir)) then begin  //·Õ ¾ÆÅØÀÎ °æ¿ì
              hitmsg := CM_WIDEHIT;
            end;
            if BoCanCrossHit and (Myself.Abil.MP >= 6) and (TargetInSwordCrossAttackRange (tdir)) then begin  //·Õ ¾ÆÅØÀÎ °æ¿ì
              hitmsg := CM_CROSSHIT;
            end;
            Myself.SendMsg (hitmsg, Myself.XX, Myself.YY, tdir, 0, 0, '', 0);
          end;
          LastAttackTime := GetTickCount;
        end;
      end
      else begin
        if (MCX = MySelf.XX) and (MCY = MySelf.YY) then begin
          tdir := GetNextDirection(MySelf.XX, MySelf.YY, MCX, MCY);
          if CanNextAction and ServerAcceptNextAction then begin
            SendPickup; //ÁÝ±â
          end;
        end
        else if GetTickCount - LastAttackTime > 1000 then begin //°ø°ÝÇÏ´Â Å¬¸¯ ½Ç¼öÀÌµ¿À» ¹æÁö
          if ssCtrl in Shift then begin
            ChrAction := caRun;
          end
          else begin
            ChrAction := caWalk;
          end;
          TargetX := MCX;
          TargetY := MCY;
        end;
      end;
    end;
  end;
end;

procedure TFrmMain.DXDraw1DblClick(Sender: TObject);
var
  pt: TPoint;
begin
  GetCursorPos(pt);
  if g_DWinMan.DblClick(pt.X, pt.Y) then exit;
end;

function TFrmmain.CheckDoorAction(dx, dy: integer): Boolean;
var
  nx, ny, ndir, door: integer;
begin
  Result := FALSE;
   //if not Map.CanMove (dx, dy) then begin
      //if (Abs(dx-Myself.XX) <= 2) and (Abs(dy-Myself.YY) <= 2) then begin
         door := Map.GetDoor (dx, dy);
         if door > 0 then begin
           if not Map.IsDoorOpen (dx, dy) then begin
             SendClientMessage (CM_OPENDOOR, door, dx, dy, 0);
             Result := TRUE;
           end;
         end;
      //end;
   //end;
end;

procedure TFrmMain.MouseTimerTimer(Sender: TObject);
var
  pt: TPoint;
  keyvalue: TKeyBoardState;
  shift: TShiftState;
begin
  GetCursorPos(pt);
  SetCursorPos(pt.X, pt.Y);

  if TargetCret <> nil then begin
    if ActionKey > 0 then begin
      ProcessKeyMessages;
    end else begin
      if not TargetCret.Death and PlayScene.IsValidActor(TargetCret) then begin
        FillChar(keyvalue, sizeof(TKeyboardState), #0);
        if GetKeyboardState (keyvalue) then begin
          shift := [];
          if ((keyvalue[VK_SHIFT] and $80) <> 0) then shift := shift + [ssShift];
          if ((TargetCret.Race <> 0) and
               (TargetCret.Race <> RCC_GUARD) and
               (TargetCret.Race <> RCC_GUARD2) and
               (TargetCret.Race <> RCC_MERCHANT) and
               (pos('(', TargetCret.UserName) = 0) //ÁÖÀÎÀÖ´Â ¸÷(°­Á¦°ø°Ý ÇØ¾ßÇÔ)
              )
              or (TargetCret.NameColor = ENEMYCOLOR)   //ÀûÀº ÀÚµ¿ °ø°ÝÀÌ µÊ
              or ((ssShift in Shift) and (not PlayScene.EdChat.Visible)) then begin //»ç¶÷À» ½Ç¼ö·Î °ø°ÝÇÏ´Â °ÍÀ» ¸·À½
              AttackTarget (TargetCret);
          end; //else begin
              //TargetCret := nil;
           //end
        end;
      end else
        TargetCret := nil;
    end;
  end;
  if BoAutoDig then begin
    if CanNextAction and ServerAcceptNextAction and CanNextHit then begin
      MySelf.SendMsg(CM_HIT + 1, MySelf.XX, MySelf.YY, MySelf.Dir, 0, 0, '', 0);
    end;
  end;
end;

procedure TFrmMain.WaitMsgTimerTimer(Sender: TObject);
begin
  if Myself = nil then
    exit;
  if Myself.ActionFinished then begin
    WaitMsgTimer.Enabled := FALSE;
    case WaitingMsg.Ident of
      SM_CHANGEMAP:
        begin
          FrmDlg.SafeCloseDlg;
          MapMovingWait := False;
          MapMoving := False;

          if MDlgX <> -1 then begin
            FrmDlg.CloseMDlg;
            MDlgX := -1;
          end;
          ClearDropItems;
          PlayScene.CleanObjects;
          MapTitle := '';
          PlayScene.SendMsg (SM_CHANGEMAP, 0,
                              WaitingMsg.Param{x},
                              WaitingMsg.tag{y},
                              LOBYTE(WaitingMsg.Series){darkness}, // ¿ë´øÁ¯
                              0, 0, 0,
                              WaitingStr{mapname});

          EffectNum := HiByte(WaitingMsg.Series);
          if EffectNum < 0 then EffectNum := 0;
          if (EffectNum = 1) or (EffectNum = 2) then RunEffectTimer.Enabled := True
          else RunEffectTimer.Enabled := False;

          Myself.CleanCharMapSetting (WaitingMsg.Param, WaitingMsg.Tag);
           //DScreen.AddSysMsg (IntToStr(WaitingMsg.Param) + ' ' +
           //                   IntToStr(WaitingMsg.Tag) + ' : My ' +
           //                   IntToStr(Myself.XX) + ' ' +
           //                   IntToStr(Myself.YY) + ' ' +
           //                   IntToStr(Myself.RX) + ' ' +
           //                   IntToStr(Myself.RY) + ' '
           //                  );
          TargetX := -1;
          TargetCret := nil;
          FocusCret := nil;
        end;
    end;
  end;
end;

{----------------------- Socket -----------------------}
procedure TFrmMain.SelChrWaitTimerTimer(Sender: TObject);
begin
  SelChrWaitTimer.Enabled := FALSE;
  SendQueryChr;
end;

procedure TFrmMain.ActiveCmdTimer(cmd: TTimerCommand);
begin
  CmdTimer.Enabled := TRUE;
  TimerCmd := cmd;
end;

procedure TFrmMain.CmdTimerTimer(Sender: TObject);
begin
  CmdTimer.Enabled := FALSE;
  CmdTimer.Interval := 1000;
  case TimerCmd of
    tcSoftClose:
      begin
        CmdTimer.Enabled := FALSE;
        CSocket.Socket.Close;
      end;
    tcReSelConnect:
      begin
        ResetGameVariables;
        DScreen.ChangeScene(stSelectChr);
        ConnectionStep := cnsReSelChr;
        if not BoOneClick then begin
          with CSocket do begin
            Active := False;
            Address := SelChrAddr;
            Port := SelChrPort;
            Active := True;
          end;
        end else begin
          if CSocket.Socket.Connected then
            CSocket.Socket.SendText('$S' + SelChrAddr + '/' + IntToStr(SelChrPort) + '%');
          CmdTimer.Interval := 1;
          ActiveCmdTimer(tcFastQueryChr);
        end;
      end;
    tcFastQueryChr:
      begin
        SendQueryChr;
      end;
  end;
end;

procedure TFrmMain.CloseAllWindows;
begin
  with FrmDlg do begin

    CancelItemMoving;
    if DStateWin.Visible then DStateWin.Visible := FALSE;
    if DUserState1.Visible then DUserState1.Visible := FALSE;
    if DItemBag.Visible then DItemBag.Visible := FALSE;
    if DMiniMapDlg.Visible then DMiniMapDlg.Visible := FALSE;
    if DMerchantDlg.Visible then CloseMDlg;
    if DSellDlg.Visible then CloseDSellDlg;
    if DGuildDlg.Visible then DGDCloseClick(nil, 0, 0);
    if DDealDlg.Visible then DDealCloseClick(nil, 0, 0);
    if DGroupDlg.Visible then DGrpDlgCloseClick(nil, 0, 0);
    if DMailListDlg.Visible then ToggleShowMailListDlg;
    if DFriendDlg.Visible then ToggleShowFriendsDlg;
    if DBlockListDlg.Visible then ToggleShowBlockListDlg;
//      if DMemo.Visible then ToggleShowMemoDlg;
    if DMemo.Visible then DMemoCloseClick(DMemoClose, 0, 0);
    if DMakeItemDlg.Visible then DMakeItemDlgOkClick(DMakeItemDlgCancel, 0, 0);
    if DItemMarketDlg.Visible then CloseItemMarketDlg;
//      if DItemMarketDlg.Visible then DItemMarketDlg.Visible := FALSE;

    if DJangwonListDlg.Visible then DJangwonCloseClick(DJangwonClose, 0, 0);
    if DGABoardListDlg.Visible then DGABoardListCloseClick(DGABoardListClose, 0, 0);
    if DGABoardDlg.Visible then DGABoardCloseClick(DGABoardClose, 0, 0);
    if DGADecorateDlg.Visible then DGADecorateCloseClick(DGADecorateClose, 0, 0);
    if DMasterDlg.Visible then ToggleShowMasterDlg;
    DMsgDlg.Visible := FALSE;
    DMenuDlg.Visible := FALSE;
    DKeySelDlg.Visible := FALSE;
    DDealRemoteDlg.Visible := FALSE;
    DGuildEditNotice.Visible := FALSE;
    DAdjustAbility.Visible := FALSE;
    DMailDlg.Visible := FALSE;
    if DMainOption.Visible then DMainOptionCloseClick(DMainOption, 0, 0);
  end;
  if MDlgX <> -1 then begin
    FrmDlg.CloseMDlg;
    MDlgX := -1;
  end;
  ItemMoving := FALSE;
  BoMsgDlgTimeCheck := False;
  FrmDlg.MsgDlgClickTime := GetTickCount;
end;

procedure TFrmMain.ClearDropItems;
var
  i: integer;
begin
  for i := 0 to DropedItemList.Count - 1 do
    Dispose(PTDropItem(DropedItemList[i]));
  DropedItemList.Clear;
end;

procedure TFrmMain.ResetGameVariables;
var
  I, II: integer;
begin
  CloseAllWindows;
  ClearDropItems;
//  for i := 0 to MagicList.Count - 1 do
//    Dispose(PTClientMagic(MagicList[i]));
//  MagicList.Clear;

  for I := 0 to _MAX_TYPE_MAGIC - 1 do begin
    for II := 0 to m_xMyMagicList[I].Count - 1 do
      Dispose(PTClientMagic(m_xMyMagicList[i][II]));
    m_xMyMagicList[I].Clear;
  end;

  ItemMoving := FALSE;
  WaitingUseItem.Item.S.Name := '';
  EatingItem.S.name := '';
  MovingItem.Item.S.Name := '';

  TargetX := -1;
  TargetCret := nil;
  FocusCret := nil;
  MagicTarget := nil;
  ActionLock := False;
  GroupMembers.Clear;
  GroupIdList.Clear;

  for i := 0 to FriendMembers.Count - 1 do
    Dispose(PTFriend(FriendMembers[i]));
  FriendMembers.Clear;

  for i := 0 to BlackMembers.Count - 1 do
    Dispose(PTFriend(BlackMembers[i]));
  BlackMembers.Clear;

  BlockLists.Clear;
  for i := 0 to MailLists.Count - 1 do
    Dispose(PTMail(MailLists[i]));
  MailLists.Clear;
  WantMailList := False;

  fLover.Clear;

  GuildRankName := '';
  GuildName := '';

  MapMoving := False;
  WaitMsgTimer.Enabled := False;
  MapMovingWait := False;
  DScreen.ChatBoardTop := 0;
  BoNextTimePowerHit := False;
  BoCanLongHit := False;
  BoCanWideHit := False;
  BoCanCrossHit := False;
  BoCanTwinHit := False;
  BoNextTimeFireHit := False;

  FillChar(UseItems, SizeOf(TClientItem) * 13, #0);        // 9->13
  FillChar(ItemArr, SizeOf(TClientItem) * MAXBAGITEMCL, #0);

  with SelectChrScene do begin
    FillChar(m_stSelectChrInfo, SizeOf(TSelChar) * 3, #0);
    m_stSelectChrInfo[0].FreezeState := True; //±âº»ÀÌ ¾ó¾î ÀÖ´Â »óÅÂ
    m_stSelectChrInfo[1].FreezeState := True;
  end;
  PlayScene.ClearActors;
  ClearDropItems;
  EventMan.ClearEvents;
  PlayScene.CleanObjects;
  MySelf := nil;
  g_Market.Clear;
end;

procedure TFrmMain.ChangeServerClearGameVariables;
var
  I, II: integer;
begin
  CloseAllWindows;
  ClearDropItems;
//  for i := 0 to MagicList.Count - 1 do
//    Dispose(PTClientMagic(MagicList[i]));
//  MagicList.Clear;

  for I := 0 to _MAX_TYPE_MAGIC - 1 do begin
    for II := 0 to m_xMyMagicList[I].Count - 1 do
      Dispose(PTClientMagic(m_xMyMagicList[i][II]));
    m_xMyMagicList[I].Clear;
  end;

  ItemMoving := False;
  WaitingUseItem.Item.S.Name := '';
  EatingItem.S.name := '';
  TargetX := -1;
  TargetCret := nil;
  FocusCret := nil;
  MagicTarget := nil;
  ActionLock := False;
  GroupMembers.Clear;
  GroupIdList.Clear;

  for i := 0 to FriendMembers.Count - 1 do
    Dispose(PTFriend(FriendMembers[i]));
  FriendMembers.Clear;

  for i := 0 to BlackMembers.Count - 1 do
    Dispose(PTFriend(BlackMembers[i]));
  BlackMembers.Clear;

  BlockLists.Clear;
  for i := 0 to MailLists.Count - 1 do
    Dispose(PTMail(MailLists[i]));
  MailLists.Clear;
  WantMailList := False;

  fLover.clear;

  GuildRankName := '';
  GuildName := '';

  MapMoving := False;
  WaitMsgTimer.Enabled := False;
  MapMovingWait := False;
  BoNextTimePowerHit := False;
  BoCanLongHit := False;
  BoCanWideHit := False;
   // 2003/03/15 ½Å±Ô¹«°ø
  BoCanCrossHit := False;
  BoCanTwinHit := False;

  ClearDropItems;
  EventMan.ClearEvents;
  PlayScene.CleanObjects;
end;

procedure TFrmMain.CSocketConnect(Sender: TObject; Socket: TCustomWinSocket);
var
  packet: array[0..255] of char;
  strbuf: array[0..255] of char;
  str: string;
begin
  ServerConnected := TRUE;
  if ConnectionStep = cnsLogin then begin
//      DScreen.ChangeScene (stLogin);
//      DScreen.ChangeScene (stIntro);
      //SendVersionNumber;
  end;
  if ConnectionStep = cnsSelChr then begin
//    Application.MessageBox( PChar('cnsSelChr'), PChar('Check'), IDOK);
    LoginScene.OpenLoginDoor;
    SelChrWaitTimer.Enabled := True;
  end;
  if ConnectionStep = cnsReSelChr then begin
    CmdTimer.Interval := 1;
    ActiveCmdTimer(tcFastQueryChr);
  end;
  if ConnectionStep = cnsPlay then begin
    if not BoServerChanging then begin
      ClearBag;  //°¡¹æ ÃÊ±âÈ­
      DScreen.ClearChatBoard; //Ã¤ÆÃÃ¢ ÃÊ±âÈ­
      DScreen.ChangeScene(stLoginNotice);
//         DScreen.ChangeScene (stLoading);
    end
    else begin
      ChangeServerClearGameVariables;
    end;
    SendRunLogin;
  end;
  SocStr := '';
  BufferStr := '';
end;

procedure TFrmMain.CSocketDisconnect(Sender: TObject; Socket: TCustomWinSocket);
begin
  ServerConnected := FALSE;
  if (ConnectionStep = cnsLogin) and not BoWellLogin then begin
//    FrmDlg.DMessageDlg('Connection closed...', [mbOk]);
    if MessageBox(handle, 'ÄúÁ¬½ÓÊ§°ÜÁË£¬ÏëÒªÖØÐÂÁ¬½ÓÂð£¿', 'Legend Of Mir 3', MB_ICONINFORMATION + MB_OKCANCEL) = IDOK then begin
      ReConnection := True;
      Exit;
    end else begin
      Close;
    end;
  end;
  if SoftClosed then begin
    SoftClosed := FALSE;
    ActiveCmdTimer(tcReSelConnect);
  end;
end;

procedure TFrmMain.CSocketError(Sender: TObject; Socket: TCustomWinSocket;
  ErrorEvent: TErrorEvent; var ErrorCode: Integer);
begin
  ErrorCode := 0;
  Socket.Close;
end;

procedure TFrmMain.CSocketRead(Sender: TObject; Socket: TCustomWinSocket);
var
  n: integer;
  data, data2: string;
begin
  data := Socket.ReceiveText;

   //DebugOutStr (data);
   //if pos('GOOD', data) > 0 then DScreen.AddSysMsg (data);

  n := Pos('*', data);
  if n > 0 then begin
    data2 := Copy(data, 1, n - 1);
    data := data2 + Copy(data, n + 1, Length(data));
      //SendSocket ('*');
    CSocket.Socket.SendText('*');
  end;
  SocStr := SocStr + data;
end;

{-------------------------------------------------------------}
procedure TFrmMain.SendSocket(sendstr: string);
const
  Code: byte = 1;
begin
   //DebugOutStr (sendstr);
  if CSocket.Socket.Connected then begin
    CSocket.Socket.SendText('#' + IntToStr(Code) + sendstr + '!');
    Inc(Code);
    if Code >= 10 then
      Code := 1;
  end;
end;

procedure TFrmMain.SendClientMessage(msg, Recog, param, tag, series: integer);
var
  dmsg: TDefaultMessage;
begin
  dmsg := MakeDefaultMsg(msg, Recog, param, tag, series);
  SendSocket(EncodeMessage(dmsg));
end;

procedure TFrmMain.SendClientMessage2(msg, Recog, param, tag, series: integer;
  str: string);
var
  dmsg: TDefaultMessage;
begin
  dmsg := MakeDefaultMsg(msg, Recog, param, tag, series);
  SendSocket(EncodeMessage(dmsg) + EncodeString(str));
end;

procedure TFrmMain.SendVersionNumber;
var
  msg: TDefaultMessage;
begin
{   msg := MakeDefaultMsg (CM_PROTOCOL, ClientVersion, 0, 0, 0);
   SendSocket (EncodeMessage (msg));}
end;

procedure TFrmMain.SendLogin(uid, passwd: string);
var
  msg: TDefaultMessage;
begin
  LoginId := uid;
  LoginPasswd := passwd;
  msg := MakeDefaultMsg(CM_IDPASSWORD, ClientVersion, 0, 0, 0);
  SendSocket(EncodeMessage(msg) + EncodeString(uid + '/' + passwd));
  BoWellLogin := TRUE;
end;

procedure TFrmMain.SendNewAccount(ue: TUserEntryInfo; ua: TUserEntryAddInfo);
var
  msg: TDefaultMessage;
begin
  MakeNewId := ue.LoginId;
  msg := MakeDefaultMsg(CM_ADDNEWUSER, 0, 0, 0, 0);
  SendSocket(EncodeMessage(msg) + EncodeBuffer(@ue, sizeof(TUserEntryInfo)) + EncodeBuffer(@ua, sizeof(TUserEntryAddInfo)));
end;

procedure TFrmMain.SendUpdateAccount(ue: TUserEntryInfo; ua: TUserEntryAddInfo);
var
  msg: TDefaultMessage;
begin
  MakeNewId := ue.LoginId;
  msg := MakeDefaultMsg(CM_UPDATEUSER, 0, 0, 0, 0);
  SendSocket(EncodeMessage(msg) + EncodeBuffer(@ue, sizeof(TUserEntryInfo)) + EncodeBuffer(@ua, sizeof(TUserEntryAddInfo)));
end;

procedure TFrmMain.SendSelectServer(svname: string);
var
  msg: TDefaultMessage;
begin
  msg := MakeDefaultMsg(CM_SELECTSERVER, 0, 0, 0, 0);
  SendSocket(EncodeMessage(msg) + EncodeString(svname));
end;

procedure TFrmMain.SendChgPw(id, passwd, newpasswd: string);
var
  msg: TDefaultMessage;
begin
  msg := MakeDefaultMsg(CM_CHANGEPASSWORD, 0, 0, 0, 0);
  SendSocket(EncodeMessage(msg) + EncodeString(id + #9 + passwd + #9 + newpasswd));
end;

procedure TFrmMain.SendNewChr(uid, uname, shair, sjob, ssex: string);
var
  msg: TDefaultMessage;
begin
  msg := MakeDefaultMsg(CM_NEWCHR, 0, 0, 0, 0);
  SendSocket(EncodeMessage(msg) + EncodeString(uid + '/' + uname + '/' + shair + '/' + sjob + '/' + ssex));
end;

procedure TFrmMain.SendQueryChr;
var
  msg: TDefaultMessage;
begin
  msg := MakeDefaultMsg(CM_QUERYCHR, 0, 0, 0, 0);
  SendSocket(EncodeMessage(msg) + EncodeString(LoginId + '/' + IntToStr(Certification)));
end;

procedure TFrmMain.SendDelChr(chrname: string);
var
  msg: TDefaultMessage;
begin
  msg := MakeDefaultMsg(CM_DELCHR, 0, 0, 0, 0);
  SendSocket(EncodeMessage(msg) + EncodeString(DecodeString(chrname)));
end;

procedure TFrmMain.SendSelChr(chrname: string);
var
  msg: TDefaultMessage;
begin
  CharName := DecodeString(chrname);
  msg := MakeDefaultMsg(CM_SELCHR, 0, 0, 0, 0);
  SendSocket(EncodeMessage(msg) + EncodeString(LoginId + '/' + DecodeString(chrname)));
end;

procedure TFrmMain.SendRunLogin;
var
  msg: TDefaultMessage;
  str: string;
begin
  str := '**' +
          LoginId + '/' +
          CharName + '/' +
          IntToStr(Certification) + '/' +
          IntToStr(ClientVersion) + '/' +
          IntToStr(Certification xor $F2E44FFF) + '/' +
          IntToStr(pLocalFileCheckSum^) + '/' +
          IntToStr(Certification xor $a4a5b277) +
          '/' + '0';
   //if NewGameStart then begin
   //   str := str + '0';
   //   NewGameStart := FALSE;
   //end else str := str + '1';
  SendSocket (EncodeString (str));
end;

procedure TFrmMain.SendSay(str: string);
var
  msg: TDefaultMessage;
begin
  if str <> '' then begin
{      if str = '/check debug screen' then begin
         CheckBadMapMode := not CheckBadMapMode;
         if CheckBadMapMode then DScreen.AddSysMsg ('On')
         else DScreen.AddSysMsg ('Off');
         exit;
      end;}
    if str = '/check speedhack' then begin
      BoCheckSpeedHackDisplay := not BoCheckSpeedHackDisplay;
      exit;
    end;
    if str = '@password' then begin
      if PlayScene.EdChat.PasswordChar = #0 then
        PlayScene.EdChat.PasswordChar := '*'
      else PlayScene.EdChat.PasswordChar := #0;
      exit;
    end;
    msg := MakeDefaultMsg (CM_SAY, 0, 0, 0, 0);
    SendSocket (EncodeMessage (msg) + EncodeString(str));

    if str[1] = '/' then begin
      DScreen.AddChatBoardString (str, GetRGB(180), clWhite);
      GetValidStr3 (Copy(str,2,Length(str)-1), WhisperName, [' ']);
    end
    else if (Copy(str,1,2) = '¢½') then
      if Copy(fLover.GetDisplay(0), length(STR_LOVER)+1, 6) <> '' then
        DScreen.AddChatBoardString (MySelf.UserName +': '+  Copy(str,3,Length(str)-2), GetRGB(253), clWhite);

    if BoOneTimePassword then begin
      BoOneTimePassword := FALSE;
      PlayScene.EdChat.PasswordChar := #0;
    end;
  end;
end;

procedure TFrmMain.SendActMsg(ident, x, y, dir: integer);
var
  msg: TDefaultMessage;
begin
  if (ident=CM_TURN)or (ident=CM_WALK)or (ident=CM_RUN)or (ident=CM_HIT)or (ident=CM_POWERHIT)or (ident=CM_LONGHIT)or (ident=CM_WIDEHIT)or
     (ident=CM_HEAVYHIT)or (ident=CM_BIGHIT)or (ident=CM_FIREHIT)or (ident=CM_CROSSHIT)or (ident=CM_TWINHIT)or (ident=CM_SITDOWN) then
    msg := MakeDefaultMsg (ident, MakeLong(x,y), 0, dir, 0, Myself.RecogId)
  else
    msg := MakeDefaultMsg (ident, MakeLong(x,y), 0, dir, 0);
      
  SendSocket (EncodeMessage (msg));
  ActionLock := TRUE;
  ActionLockTime := GetTickCount;
  Inc (SendCount);
end;

procedure TFrmMain.SendSpellMsg(ident, x, y, dir, target: integer);
var
  msg: TDefaultMessage;
begin
  msg := MakeDefaultMsg(ident, MakeLong(x, y), Loword(target), dir, Hiword(target));
  SendSocket(EncodeMessage(msg));
  ActionLock := TRUE; //¼­¹ö¿¡¼­ #+FAIL! ÀÌ³ª #+GOOD!ÀÌ ¿Ã¶§±îÁö ±â´Ù¸²
  ActionLockTime := GetTickCount;
  Inc(SendCount);
end;

procedure TFrmMain.SendQueryUserName(targetid, x, y: integer);
var
  msg: TDefaultMessage;
begin
  msg := MakeDefaultMsg(CM_QUERYUSERNAME, targetid, x, y, 0);
  SendSocket(EncodeMessage(msg));
end;

procedure TFrmMain.SendDropItem(name: string; itemserverindex: integer);
var
  msg: TDefaultMessage;
begin
  msg := MakeDefaultMsg(CM_DROPITEM, itemserverindex, 0, 0, 0);
  SendSocket(EncodeMessage(msg) + EncodeString(name));
end;

procedure TFrmMain.SendDropCountItem(iname: string; mindex, icount: integer);
var
  msg: TDefaultMessage;
begin
  msg := MakeDefaultMsg(CM_DROPCOUNTITEM, mindex, icount, 0, 0);
  SendSocket(EncodeMessage(msg) + EncodeString(iname));
end;

procedure TFrmMain.SendPickup;
var
  msg: TDefaultMessage;
begin
  if Assigned(MySelf) then begin
    msg := MakeDefaultMsg(CM_PICKUP, 0, Myself.XX, Myself.YY, 0, Myself.RecogId);
    SendSocket(EncodeMessage(msg));
  end;
end;

procedure TFrmMain.SendTakeOnItem(where: byte; itmindex: integer; itmname: string);
var
  msg: TDefaultMessage;
begin
  msg := MakeDefaultMsg(CM_TAKEONITEM, itmindex, where, 0, 0);
  SendSocket(EncodeMessage(msg) + EncodeString(itmname));
end;

procedure TFrmMain.SendTakeOffItem(where: byte; itmindex: integer; itmname: string);
var
  msg: TDefaultMessage;
begin
  msg := MakeDefaultMsg(CM_TAKEOFFITEM, itmindex, where, 0, 0);
  SendSocket(EncodeMessage(msg) + EncodeString(itmname));
end;

procedure TFrmMain.SendEat(idx, itmindex: integer; itmname: string);
var
  msg: TDefaultMessage;
begin
  msg := MakeDefaultMsg(CM_EAT, itmindex, 0, 0, 0);
  SendSocket(EncodeMessage(msg) + EncodeString(itmname));
//   DScreen.AddChatBoardString ('SendEat  idx=>'+IntToStr(idx), clYellow, clRed);
//   if idx < 6 then StBeltAutoFill := True;
  if idx <> -1 then BtInDex := idx;
end;

procedure TFrmMain.UpgradeItem(ItemIndex, jewelIndex: integer; StrItem, StrJewel: string);
var
  msg: TDefaultMessage;
begin
  msg := MakeDefaultMsg(CM_UPGRADEITEM, ItemIndex, Loword(jewelIndex), Hiword(jewelIndex), 0);
  SendSocket(EncodeMessage(msg) + EncodeString(StrItem + '/' + StrJewel));
end;

procedure TFrmMain.SendItemSumCount(OrgItemIndex, ExItemIndex: integer;
  StrOrgItem, StrExItem: string);
var
  msg: TDefaultMessage;
begin
  msg := MakeDefaultMsg(CM_ITEMSUMCOUNT, OrgItemIndex, Loword(ExItemIndex), Hiword(ExItemIndex), 0);
  SendSocket(EncodeMessage(msg) + EncodeString(StrOrgItem + '/' + StrExItem));
end;

procedure TFrmMain.UpgradeItemResult(ItemIndex: integer; wResult: word; str: string);
begin
  FrmDlg.UpgradeItemEffect(wResult);
  PlaySound(10310);  // s_deal_additem
end;

procedure TFrmMain.SendButchAnimal(x, y, dir, actorid: integer);
var
  msg: TDefaultMessage;
begin
  msg := MakeDefaultMsg(CM_BUTCH, actorid, x, y, dir);
  SendSocket(EncodeMessage(msg));
end;

procedure TFrmMain.SendMagicKeyChange(magid: integer; keych: char);
var
  msg: TDefaultMessage;
begin
  msg := MakeDefaultMsg(CM_MAGICKEYCHANGE, magid, byte(keych), 0, 0);
  SendSocket(EncodeMessage(msg));
end;

procedure TFrmMain.SendMerchantDlgSelect(merchant: integer; rstr: string);
var
  msg: TDefaultMessage;
  param: string;
begin
  if Length(rstr) >= 2 then begin  //ÆÄ¶ó¸ÞÅ¸°¡ ÇÊ¿äÇÑ °æ¿ì°¡ ÀÖÀ½.
    if (rstr[1] = '@') and (rstr[2] = '@') then begin
      if rstr = '@@AgitForSale' then
        FrmDlg.DMessageDlg ('Àå¿øÆÇ¸Å ±Ý¾×À» ÀÔ·ÂÇÏ¼¼¿ä.', [mbOk, mbAbort])
      else if rstr = '@@AgitOneRecall' then
        FrmDlg.DMessageDlg ('¼ÒÈ¯ ÇÒ ¹®ÆÄ¿øÀ» ÀÔ·ÂÇÏ¼¼¿ä.', [mbOk, mbAbort])
      else if rstr = '@@buildguildnow' then begin
        MsgDlgMaxStr := 20;
        FrmDlg.DMessageDlg ('¼³¸³ÇÒ ¹®ÆÄÀÇ ÀÌ¸§À» ÀûÀ¸½Ê½Ã¿À.', [mbOk, mbAbort]);
        MsgDlgMaxStr := 30;
      end
      else FrmDlg.DMessageDlg ('ÀÔ·ÂÇÏ½Ê½Ã¿À.', [mbOk, mbAbort]);
      param := Trim (FrmDlg.DlgEditText);
      rstr := rstr + #13 + param;
    end;
  end;
  msg := MakeDefaultMsg(CM_MERCHANTDLGSELECT, merchant, 0, 0, 0);
  SendSocket(EncodeMessage(msg) + EncodeString(rstr));
end;

procedure TFrmMain.SendQueryPrice(merchant, itemindex: integer; itemname: string);
var
  msg: TDefaultMessage;
begin
  msg := MakeDefaultMsg(CM_MERCHANTQUERYSELLPRICE, merchant, Loword(itemindex), Hiword(itemindex), 0);
  SendSocket(EncodeMessage(msg) + EncodeString(itemname));
end;

procedure TFrmMain.SendQueryRepairCost(merchant, itemindex: integer; itemname: string);
var
  msg: TDefaultMessage;
begin
  msg := MakeDefaultMsg(CM_MERCHANTQUERYREPAIRCOST, merchant, Loword(itemindex), Hiword(itemindex), 0);
  SendSocket(EncodeMessage(msg) + EncodeString(itemname));
end;

procedure TFrmMain.SendSellItem(merchant, itemindex: integer; itemname: string;
  Count: word);
var
  msg: TDefaultMessage;
begin
  msg := MakeDefaultMsg(CM_USERSELLITEM, merchant, Loword(itemindex), Hiword(itemindex), Count);
  SendSocket(EncodeMessage(msg) + EncodeString(itemname));
end;

procedure TFrmMain.SendRepairItem(merchant, itemindex: integer; itemname: string);
var
  msg: TDefaultMessage;
begin
  msg := MakeDefaultMsg(CM_USERREPAIRITEM, merchant, Loword(itemindex), Hiword(itemindex), 0);
  SendSocket(EncodeMessage(msg) + EncodeString(itemname));
end;

procedure TFrmMain.SendStorageItem(merchant, itemindex: integer; itemname: string; Count: word);
var
  msg: TDefaultMessage;
begin
  msg := MakeDefaultMsg(CM_USERSTORAGEITEM, merchant, Loword(itemindex), Hiword(itemindex), Count);
  SendSocket(EncodeMessage(msg) + EncodeString(itemname));
end;

procedure TFrmMain.SendMaketSellItem(merchant, itemindex: integer; price: string; Count: word);
var
  msg: TDefaultMessage;
begin
  msg := MakeDefaultMsg(CM_MARKET_SELL, merchant, Loword(itemindex), Hiword(itemindex), Count);
  SendSocket(EncodeMessage(msg) + EncodeString(price));
end;

procedure TFrmMain.SendGetDetailItem(merchant, menuindex: integer; itemname: string);
var
  msg: TDefaultMessage;
begin
  msg := MakeDefaultMsg(CM_USERGETDETAILITEM, merchant, menuindex, 0, 0);
  SendSocket(EncodeMessage(msg) + EncodeString(itemname));
end;

procedure TFrmMain.SendGetJangwonList(Page: integer);
var
  msg: TDefaultMessage;
begin
  msg := MakeDefaultMsg(CM_GUILDAGITLIST, Page, 0, 0, 0);
  SendSocket(EncodeMessage(msg));
end;

procedure TFrmMain.SendGABoardRead(Body: string);
var
  msg: TDefaultMessage;
begin
  msg := MakeDefaultMsg(CM_GABOARD_READ, 0, 0, 0, 0);
  SendSocket(EncodeMessage(msg) + EncodeString(Body));
end;

procedure TFrmMain.SendGetMarketPageList(merchant, pagetype: integer; itemname: string);
var // Market System..
  msg: TDefaultMessage;
begin
  msg := MakeDefaultMsg(CM_MARKET_LIST, merchant, pagetype, 0, 0);
  SendSocket(EncodeMessage(msg) + EncodeString(itemname));
end;

procedure TFrmMain.SendBuyMarket(merchant, sellindex: integer);
var // Market System..
  msg: TDefaultMessage;
begin
  msg := MakeDefaultMsg(CM_MARKET_BUY, merchant, Loword(sellindex), Hiword(sellindex), 0);
  SendSocket(EncodeMessage(msg));
end;

procedure TFrmMain.SendCancelMarket(merchant, sellindex: integer);
var // Market System..
  msg: TDefaultMessage;
begin
  msg := MakeDefaultMsg(CM_MARKET_CANCEL, merchant, Loword(sellindex), Hiword(sellindex), 0);
  SendSocket(EncodeMessage(msg));
end;

procedure TFrmMain.SendGetPayMarket(merchant, sellindex: integer);
var // Market System..
  msg: TDefaultMessage;
begin
  msg := MakeDefaultMsg(CM_MARKET_GETPAY, merchant, Loword(sellindex), Hiword(sellindex), 0);
  SendSocket(EncodeMessage(msg));
end;

procedure TFrmMain.SendMarketClose;
var // Market System..
  msg: TDefaultMessage;
begin
  msg := MakeDefaultMsg(CM_MARKET_CLOSE, 0, 0, 0, 0);
  SendSocket(EncodeMessage(msg));
end;

procedure TFrmMain.SendBuyItem(merchant, itemserverindex: integer; itemname: string; Count: word);
var
  msg: TDefaultMessage;
begin
  msg := MakeDefaultMsg(CM_USERBUYITEM, merchant, Loword(itemserverindex), Hiword(itemserverindex), Count);
  SendSocket(EncodeMessage(msg) + EncodeString(itemname));
end;

procedure TFrmMain.SendBuyDecoItem(merchant, DecoItemNum: integer);
var
  msg: TDefaultMessage;
begin
  msg := MakeDefaultMsg(CM_DECOITEM_BUY, merchant, Loword(DecoItemNum), Hiword(DecoItemNum), 1);
  SendSocket(EncodeMessage(msg));
end;

procedure TFrmMain.SendTakeBackStorageItem(merchant, itemserverindex: integer; itemname: string; Count: word);
var
  msg: TDefaultMessage;
begin
  msg := MakeDefaultMsg(CM_USERTAKEBACKSTORAGEITEM, merchant, Loword(itemserverindex), Hiword(itemserverindex), Count);
  SendSocket(EncodeMessage(msg) + EncodeString(itemname));
end;

procedure TFrmMain.SendMakeDrugItem(merchant: integer; itemname: string);
var
  msg: TDefaultMessage;
begin
  msg := MakeDefaultMsg(CM_USERMAKEDRUGITEM, merchant, 0, 0, 0);
  SendSocket(EncodeMessage(msg) + EncodeString(itemname));
end;

procedure TFrmMain.SendMakeItemSel(merchant: integer; itemname: string);
var
  msg: TDefaultMessage;
begin
  msg := MakeDefaultMsg(CM_USERMAKEITEMSEL, merchant, 0, 0, 0);
  SendSocket(EncodeMessage(msg) + EncodeString(itemname));
end;

procedure TFrmMain.SendMakeItem(merchant: integer; data: string);
var
  msg: TDefaultMessage;
begin
  msg := MakeDefaultMsg(CM_USERMAKEITEM, merchant, 0, 0, 0);
  SendSocket(EncodeMessage(msg) + EncodeString(data));
end;

procedure TFrmMain.SendDropGold(dropgold: integer);
var
  msg: TDefaultMessage;
begin
  msg := MakeDefaultMsg(CM_DROPGOLD, dropgold, 0, 0, 0);
  SendSocket(EncodeMessage(msg));
end;

procedure TFrmMain.SendGroupMode(onoff: Boolean);
var
  msg: TDefaultMessage;
begin
  if onoff then
    msg := MakeDefaultMsg(CM_GROUPMODE, 0, 1, 0, 0)   //on
  else
    msg := MakeDefaultMsg(CM_GROUPMODE, 0, 0, 0, 0);  //off
  SendSocket(EncodeMessage(msg));
end;

procedure TFrmMain.SendCreateGroup(withwho: string);
var
  msg: TDefaultMessage;
begin
  if withwho <> '' then begin
    msg := MakeDefaultMsg(CM_CREATEGROUP, 0, 0, 0, 0);
    SendSocket(EncodeMessage(msg) + EncodeString(withwho));
    DScreen.AddChatBoardString(withwho + '´Ô¿¡°Ô ±×·ì Âü°¡½ÅÃ»À» Çß½À´Ï´Ù.', TColor($BB840F), clWhite);
  end;
end;

procedure TFrmMain.SendWantMiniMap;
var
  msg: TDefaultMessage;
begin
  msg := MakeDefaultMsg(CM_WANTMINIMAP, 0, 0, 0, 0);
  SendSocket(EncodeMessage(msg));
end;

procedure TFrmMain.SendDealTry;
var
  msg: TDefaultMessage;
  i, fx, fy: integer;
  actor: TActor;
  who: string;
  proper: Boolean;
begin
      (*proper := FALSE;
   GetFrontPosition (Myself.XX, Myself.YY, Myself.Dir, fx, fy);
   with PlayScene do
      for i:=0 to ActorList.Count-1 do begin
         actor := TActor (ActorList[i]);
         if {(actor.Race = 0) and} (actor.XX = fx) and (actor.YY = fy) then begin
            proper := TRUE;
            who := actor.UserName;
            break;
         end;
      end;
   if proper then begin*)
  msg := MakeDefaultMsg(CM_DEALTRY, 0, 0, 0, 0);
  SendSocket(EncodeMessage(msg) + EncodeString(who));
   //end;
end;

procedure TFrmMain.SendGuildDlg;
var
  msg: TDefaultMessage;
begin
  msg := MakeDefaultMsg(CM_OPENGUILDDLG, 0, 0, 0, 0);
  SendSocket(EncodeMessage(msg));
end;

procedure TFrmMain.SendCancelDeal;
var
  msg: TDefaultMessage;
begin
  msg := MakeDefaultMsg(CM_DEALCANCEL, 0, 0, 0, 0);
  SendSocket(EncodeMessage(msg));
end;

procedure TFrmMain.SendAddDealItem(ci: TClientItem);
var
  msg: TDefaultMessage;
begin
  msg := MakeDefaultMsg(CM_DEALADDITEM, ci.MakeIndex, 0, 0, ci.Dura);
  SendSocket(EncodeMessage(msg) + EncodeString(ci.S.Name));
end;

procedure TFrmMain.SendDelDealItem(ci: TClientItem);
var
  msg: TDefaultMessage;
begin
  msg := MakeDefaultMsg(CM_DEALDELITEM, ci.MakeIndex, 0, 0, ci.Dura);
  SendSocket(EncodeMessage(msg) + EncodeString(ci.S.Name));
end;

procedure TFrmMain.SendChangeDealGold(gold: integer);
var
  msg: TDefaultMessage;
begin
  msg := MakeDefaultMsg(CM_DEALCHGGOLD, gold, 0, 0, 0);
  SendSocket(EncodeMessage(msg));
end;

procedure TFrmMain.SendDealEnd;
var
  msg: TDefaultMessage;
begin
  msg := MakeDefaultMsg(CM_DEALEND, 0, 0, 0, 0);
  SendSocket(EncodeMessage(msg));
end;

procedure TFrmMain.SendAddGroupMember(withwho: string);
var
  msg: TDefaultMessage;
begin
  if withwho <> '' then begin
    msg := MakeDefaultMsg(CM_ADDGROUPMEMBER, 0, 0, 0, 0);
    SendSocket(EncodeMessage(msg) + EncodeString(withwho));
    DScreen.AddChatBoardString(withwho + '´Ô¿¡°Ô ±×·ì Âü°¡½ÅÃ»À» Çß½À´Ï´Ù.', TColor($BB840F), clWhite);
  end;
end;

procedure TFrmMain.SendDelGroupMember(withwho: string);
var
  msg: TDefaultMessage;
begin
  if withwho <> '' then begin
    msg := MakeDefaultMsg(CM_DELGROUPMEMBER, 0, 0, 0, 0);
    SendSocket(EncodeMessage(msg) + EncodeString(withwho));
  end;
end;

procedure TFrmMain.SendGuildHome;
var
  msg: TDefaultMessage;
begin
  msg := MakeDefaultMsg(CM_GUILDHOME, 0, 0, 0, 0);
  SendSocket(EncodeMessage(msg));
end;

procedure TFrmMain.SendGuildMemberList;
var
  msg: TDefaultMessage;
begin
  msg := MakeDefaultMsg(CM_GUILDMEMBERLIST, 0, 0, 0, 0);
  SendSocket(EncodeMessage(msg));
end;

procedure TFrmMain.SendGuildAddMem(who: string);
var
  msg: TDefaultMessage;
begin
  if Trim(who) <> '' then begin
    msg := MakeDefaultMsg(CM_GUILDADDMEMBER, 0, 0, 0, 0);
    SendSocket(EncodeMessage(msg) + EncodeString(who));
  end;
end;

procedure TFrmMain.SendGuildDelMem(who: string);
var
  msg: TDefaultMessage;
begin
  if Trim(who) <> '' then begin
    msg := MakeDefaultMsg(CM_GUILDDELMEMBER, 0, 0, 0, 0);
    SendSocket(EncodeMessage(msg) + EncodeString(who));
  end;
end;

procedure TFrmMain.SendGuildUpdateNotice(notices: string);
var
  msg: TDefaultMessage;
begin
  msg := MakeDefaultMsg(CM_GUILDUPDATENOTICE, 0, 0, 0, 0);
  SendSocket(EncodeMessage(msg) + EncodeString(notices));
end;

procedure TFrmMain.SendGABoardUpdateNotice(notice, CurPage: integer; bodyText: string);
var
  msg: TDefaultMessage;
begin
  msg := MakeDefaultMsg(CM_GABOARD_ADD, notice, CurPage, 0, 0);
  SendSocket(EncodeMessage(msg) + EncodeString(bodyText));
end;

procedure TFrmMain.SendGABoardModify(CurPage: integer; bodyText: string);
var
  msg: TDefaultMessage;
begin
  msg := MakeDefaultMsg(CM_GABOARD_EDIT, 0, CurPage, 0, 0);
  SendSocket(EncodeMessage(msg) + EncodeString(bodyText));
end;

procedure TFrmMain.SendGetGABoardList(Page: integer);
var
  msg: TDefaultMessage;
begin
  msg := MakeDefaultMsg(CM_GABOARD_LIST, Page, 0, 0, 0);
  SendSocket(EncodeMessage(msg));
end;

procedure TFrmMain.SendGABoardNoticeCheck;
var
  msg: TDefaultMessage;
begin
  msg := MakeDefaultMsg(CM_GABOARD_NOTICE_CHECK, 0, 0, 0, 0);
  SendSocket(EncodeMessage(msg));
end;

procedure TFrmMain.SendGABoardDel(CurPage: integer; bodyText: string);
var
  msg: TDefaultMessage;
begin
  msg := MakeDefaultMsg(CM_GABOARD_DEL, 0, CurPage, 0, 0);
  SendSocket(EncodeMessage(msg) + EncodeString(bodyText));
end;

procedure TFrmMain.SendGuildUpdateGrade(rankinfo: string);
var
  msg: TDefaultMessage;
begin
  msg := MakeDefaultMsg(CM_GUILDUPDATERANKINFO, 0, 0, 0, 0);
  SendSocket(EncodeMessage(msg) + EncodeString(rankinfo));
end;

procedure TFrmMain.SendSpeedHackUser(code: integer);
var
  msg: TDefaultMessage;
begin
  msg := MakeDefaultMsg(CM_SPEEDHACKUSER, code, 0, 0, 0);
  SendSocket(EncodeMessage(msg));
end;

procedure TFrmMain.SendAdjustBonus(remain: integer; babil: TNakedAbility);
var
  msg: TDefaultMessage;
begin
  msg := MakeDefaultMsg(CM_ADJUST_BONUS, remain, 0, 0, 0);
  SendSocket(EncodeMessage(msg) + EncodeBuffer(@babil, sizeof(TNakedAbility)));
end;

function TFrmMain.ServerAcceptNextAction: Boolean;
begin
  Result := TRUE;
  if ActionLock then begin
    if GetTickCount - ActionLockTime > 10 * 1000 then begin
      ActionLock := FALSE;
      //Dec (WarningLevel);
    end;
    Result := FALSE;
  end;
end;

function TFrmMain.CanNextAction: Boolean;
begin
  if (Myself.IsIdle) and (Myself.State and $04000000 = 0) and
    (Myself.State and $20000000 = 0) and
    (GetTickCount - DizzyDelayStart > DizzyDelayTime) then begin
    Result := TRUE;
  end else
    Result := FALSE;
end;

function TFrmMain.CanNextHit: Boolean;
var
  nexthit, levelfast: integer;
begin
  levelfast := _MIN(370, (Myself.Abil.Level * 14));
  levelfast := _MIN(800, levelfast + Myself.HitSpeed * 60);
  if BoAttackSlow then
    nexthit := 1400 - levelfast + 1500
  else
    nexthit := 1400 - levelfast;
  if nexthit < 0 then nexthit := 0;
  if GetTickCount - LastHitTime > longword(nexthit) then begin
    LastHitTime := GetTickCount;
    Result := TRUE;
  end else
    Result := FALSE;
end;

procedure TFrmMain.ActionFailed;
begin
  targetx := -1;
  targety := -1;
  ActionFailLock := TRUE;
  Myself.MoveFail;
end;

function TFrmMain.IsUnLockAction(action, adir: integer): Boolean;
begin
  if (ActionFailLock and (action = FailAction) and (adir = FailDir) and
    (GetTickCount - FailActionTime < 1000)) or (MapMoving) or (BoServerChanging) then begin
    Result := FALSE;
  end
  else begin
    ActionFailLock := FALSE;
    Result := TRUE;
  end;
end;

function TFrmMain.IsGroupMember(uname: string): Boolean;
var
  i: integer;
begin
  Result := FALSE;
  for i := 0 to GroupMembers.Count - 1 do
    if GroupMembers[i] = uname then begin
      Result := TRUE;
      break;
    end;
end;

procedure TFrmMain.Timer1Timer(Sender: TObject);
var
  str, data: string;
  len, i, n, mcnt: integer;
const
  busy: Boolean = FALSE;
begin
  if busy then exit;
      //if ServerConnected then
   //   DxTimer.Enabled := TRUE
   //else
   //   DxTimer.Enabled := FALSE;

  if ReConnection then begin
    ReConnection := False;
    CSocket.Active := False;
    DScreen.ChangeScene(stLogin);
    with CSocket do begin
      Address := SERVERADDR;
      Port := 7000;
      Active := True;
    end;
  end;

  busy := True;
  try
    BufferStr := BufferStr + SocStr;
    SocStr := '';
    if BufferStr <> '' then begin
      mcnt := 0;
      while Length(BufferStr) >= 2 do begin
        if MapMovingWait then
          Break; // ´ë±â..
        if Pos('!', BufferStr) <= 0 then
          Break;
        BufferStr := ArrestStringEx(BufferStr, '#', '!', data);
        if data <> '' then begin
          DecodeMessagePacket(data);
        end
        else if Pos('!', BufferStr) = 0 then
          Break;
      end;
    end;
  finally
    busy := False;
  end;

  if WarningLevel > 30 then begin
    FrmMain.Close;
  end;

  if BoQueryPrice then begin
    if GetTickCount - QueryPriceTime > 500 then begin
      BoQueryPrice := False;
      case FrmDlg.SpotDlgMode of
        dmSell:
          SendQueryPrice(CurMerchant, SellDlgItem.MakeIndex, SellDlgItem.S.Name);
        dmRepair:
          SendQueryRepairCost(CurMerchant, SellDlgItem.MakeIndex, SellDlgItem.S.Name);
      end;
    end;
  end;

  if BonusPoint > 0 then begin
    FrmDlg.DBotPlusAbil.Visible := True;
  end else begin
    FrmDlg.DBotPlusAbil.Visible := False;
  end;
end;

procedure TFrmMain.TimerBrowserUpdateTimer(Sender: TObject);
begin
  if Video <> nil then begin
    if Video.GetState = 2 then begin
      if VIdeo.GetPosition >= VIdeo.GetStopPosition then begin
        TimerBrowserUpdate.Enabled := False;
        Video.Stop;
        if ConnectionStep = cnsLogin then begin
          DScreen.ChangeScene(stLogin);
          CSocket.Active := TRUE;
        end;
        if ConnectionStep in [cnsSelChr, cnsReSelChr] then begin
          with SelectChrScene do begin
            if m_bChrProcState = _CHR_PROC_CREATEIN then begin
              SetCharExplain(_GENDER_MAN, _JOB_JUNSA);
              if not m_stSelectChrInfo[0].bSetted then
                MakeNewChar(0)
              else
                MakeNewChar(1);
              EdChrName.Left := FrmDlg.DCreateChr.Left + 289;
              EdChrName.Top := FrmDlg.DCreateChr.Top + 407;
              EdChrName.Visible := TRUE;
              EdChrName.SetFocus;
            end;
          end;
        end;

        if ConnectionStep = cnsPlay then SelectChrScene.SelChrStartClick;;
      end;
    end else if Video.GetState = 0 then begin
      TimerBrowserUpdate.Enabled := False;
      Video.Stop;
      if ConnectionStep = cnsLogin then begin
        DScreen.ChangeScene(stLogin);
        CSocket.Active := TRUE;
      end;
      if ConnectionStep in [cnsSelChr, cnsReSelChr] then begin
        with SelectChrScene do begin
          if m_bChrProcState = _CHR_PROC_CREATEIN then begin
            SetCharExplain(_GENDER_MAN, _JOB_JUNSA);
            if not m_stSelectChrInfo[0].bSetted then
              MakeNewChar(0)
            else
              MakeNewChar(1);
            EdChrName.Left := FrmDlg.DCreateChr.Left + 289;
            EdChrName.Top := FrmDlg.DCreateChr.Top + 407;
            EdChrName.Visible := TRUE;
            EdChrName.SetFocus;
          end;
        end;
      end;
      if ConnectionStep = cnsPlay then SelectChrScene.SelChrStartClick;;
    end;
  end;
end;

procedure TFrmMain.TimerRunTimer(Sender: TObject);
const
  boRun: Boolean = False;
begin
  if boRun  then Exit;
  boRun := True;
  try
    AppOnIdle();
  finally
    boRun := False;
  end;
end;

procedure TFrmMain.MsgProg;
var
  str, data: string;
  len, i, n, mcnt: integer;
const
  busy: Boolean = FALSE;
begin
  if busy then exit;
   //if ServerConnected then
   //   DxTimer.Enabled := TRUE
   //else
   //   DxTimer.Enabled := FALSE;

  busy := True;
  try
    BufferStr := BufferStr + SocStr;
    SocStr := '';
    if BufferStr <> '' then begin
      mcnt := 0;
      while Length(BufferStr) >= 2 do begin
        if MapMovingWait then Break; // ´ë±â..
        if Pos('!', BufferStr) <= 0 then Break;
        BufferStr := ArrestStringEx(BufferStr, '#', '!', data);
        if data <> '' then begin
          DecodeMessagePacket(data);
        end
        else if Pos('!', BufferStr) = 0 then Break;
      end;
    end;
  finally
    busy := False;
  end;

  if WarningLevel > 30 then begin
    FrmMain.Close;
  end;

  if BoQueryPrice then begin
    if GetTickCount - QueryPriceTime > 500 then begin
      BoQueryPrice := False;
      case FrmDlg.SpotDlgMode of
        dmSell:
          SendQueryPrice(CurMerchant, SellDlgItem.MakeIndex, SellDlgItem.S.Name);
        dmRepair:
          SendQueryRepairCost(CurMerchant, SellDlgItem.MakeIndex, SellDlgItem.S.Name);
      end;
    end;
  end;

  if BonusPoint > 0 then begin
    FrmDlg.DBotPlusAbil.Visible := True;
  end else begin
    FrmDlg.DBotPlusAbil.Visible := False;
  end;
end;

procedure TFrmMain.SpeedHackTimerTimer(Sender: TObject);
var
  gcount, timer: longword;
  ahour, amin, asec, amsec: word;
begin
  DecodeTime(Time, ahour, amin, asec, amsec);
  timer := ahour * 1000 * 60 * 60 + amin * 1000 * 60 + asec * 1000 + amsec;
  gcount := GetTickCount;
  if SHGetTime > 0 then begin
    if abs((gcount - SHGetTime) - (timer - SHTimerTime)) > 70 then begin
      Inc(SHFakeCount);
    end else
      SHFakeCount := 0;
//      if SHFakeCount > 4 then begin
    if SHFakeCount > 1 then begin
      if Not SpeedHackUse then begin
        SendSpeedHackUser(10001);
        SpeedHackUse := True;
      end;
      FrmDlg.DMessageDlg ('ÇÁ·Î±×·¥À» Á¾·áÇÕ´Ï´Ù. CODE=10001\' +
                          '¿î¿µÀÚ¿¡°Ô ¹®ÀÇ ¹Ù¶ø´Ï´Ù. [mir2master@wemade.com]',
                          [mbOk]);
      FrmMain.Close;
    end;
    if BoCheckSpeedHackDisplay then begin
      DScreen.AddSysMsg ('->' + IntToStr(gcount - SHGetTime) + ' - ' +
                                IntToStr(timer - SHTimerTime) + ' = ' +
                                IntToStr(abs((gcount - SHGetTime) - (timer - SHTimerTime))) + ' (' +
                                IntToStr(SHFakeCount) + ')');
    end;
  end;
  SHGetTime := gcount;
  SHTimerTime := timer;
end;

procedure TFrmMain.FindWHHackTimerTimer(Sender: TObject);
var
  v0, v1, v2, v3: integer;
begin
  if Myself <> nil then begin
            // ÇØÅ· È¸ÇÇ °Ë»ç
    v0 := Myself.Abil.Level * HIT_INCLEVEL +
          abs(Myself.HitSpeed) * HIT_INCSPEED +
          Myself.Abil.Weight + Myself.Abil.MaxWeight +
                Myself.Abil.WearWeight +
                Myself.Abil.MaxWearWeight +
                Myself.Abil.HandWeight +
                Myself.Abil.MaxHandWeight
          + RUN_STRUCK_DELAY;

    v1 := HitCheckSum1;
    v2 := (longword(pHitCheckSum2^) xor $FFFFFFFF) div 4;
    v3 := (longword(pHitCheckSum3^) xor $FFFFFFFF) div 20;
      ////
    if (v0 = v1) and (v0 = v2) and (v0 = v3) then begin
      ;
    end
    else begin
      FrmMain.Close;
      Exit;
    end;
  end;
end;


procedure TFrmMain.CheckSpeedHack(rtime: Longword);
var
  cltime, svtime: integer;
  str: string;
begin
  if FirstServerTime > 0 then begin
    if (GetTickCount - FirstClientTime) > 10 * 60 * 1000 then begin  //30ºÐ ¸¶´Ù ÃÊ±âÈ­
      FirstServerTime := rtime; //ÃÊ±âÈ­
      FirstClientTime := GetTickCount;
         //ServerTimeGap := rtime - int64(GetTickCount);
    end;
    cltime := GetTickCount - FirstClientTime;
    svtime := rtime - FirstServerTime; // + 3000;

    if cltime > (svtime + 5000) then begin  //·ºÀ» °¨¾ÈÇÔ
      Inc (TimeFakeDetectCount);
      if TimeFakeDetectCount > 5 then begin
        //½Ã°£Á¶ÀÛ...
        str := 'Bad';
        if Not SpeedHackUse then begin
          SendSpeedHackUser(10000);
          SpeedHackUse := True;
        end;
        FrmDlg.DMessageDlg ('ÇÁ·Î±×·¥À» Á¾·áÇÕ´Ï´Ù. CODE=10000\' +
                            'Á¢¼ÓÀÌ ºÒ·®ÇÏ°Å³ª ½Ã½ºÅÛÀÌ ºÒ¾ÈÁ¤ÇÕ´Ï´Ù.\' +
                            '¿î¿µÀÚ¿¡°Ô ¹®ÀÇ ¹Ù¶ø´Ï´Ù. [mir2master@wemade.com]',
                            [mbOk]);
        FrmMain.Close;
      end;
    end else begin
      str := 'Good';
      TimeFakeDetectCount := 0;
    end;
    if BoCheckSpeedHackDisplay then begin
      DScreen.AddSysMsg (IntToStr(svtime) + ' - ' +
                         IntToStr(cltime) + ' = ' +
                         IntToStr(svtime-cltime) +
                         ' ' + str);
    end;
  end else begin
    FirstServerTime := rtime;
    FirstClientTime := GetTickCount;
      //ServerTimeGap := int64(GetTickCount) - longword(msg.Recog);
  end;
end;

procedure TFrmMain.DecodeMessagePacket(datablock: string);
var
  head, body, body2, tagstr, data, rdstr, str: string;
  msg: TDefaultMessage;
  smsg: TShortMessage;
  mbw: TMessageBodyW;
  desc: TCharDesc;
  wl: TMessageBodyWL;
  featureEx, wd: word;
  L, i, j, n, BLKSize, param, sound, cltime, svtime, idx: integer;
  tempb, AddCheck: boolean;
  actor: TActor;
  event: TClEvent;
  meff: TMagicEff;
begin
  if datablock[1] = '+' then begin  //checkcode
    data := Copy (datablock, 2, Length(datablock)-1);
    data := GetValidStr3 (data, tagstr, ['/']);
    if tagstr = 'PWR'  then BoNextTimePowerHit := TRUE;  //´ÙÀ½¹ø¿¡ powerhitÀ» ¶§¸± ¼ö ÀÖÀ½...
    if tagstr = 'LNG'  then BoCanLongHit := TRUE;
    if tagstr = 'ULNG' then BoCanLongHit := FALSE;
    if tagstr = 'WID'  then BoCanWideHit := TRUE;
    if tagstr = 'UWID' then BoCanWideHit := FALSE;
    if tagstr = 'CRS'  then BoCanCrossHit := TRUE;
    if tagstr = 'UCRS' then BoCanCrossHit := FALSE;
    if tagstr = 'TWN'  then BoCanTwinHit := TRUE;
    if tagstr = 'UTWN' then BoCanTwinHit := FALSE;
    if tagstr = 'FIR'  then begin
       BoNextTimeFireHit := TRUE;  //¿°È­°áÀÌ ¼¼ÆÃµÈ »óÅÂ
       LatestFireHitTime := GetTickCount;
       //Myself.SendMsg (SM_READYFIREHIT, Myself.XX, Myself.YY, Myself.Dir, 0, 0, '', 0);
    end;
    if tagstr = 'STN'  then BoCanStoneHit := TRUE;
    if tagstr = 'USTN' then BoCanStoneHit := FALSE;

    if tagstr = 'UFIR' then BoNextTimeFireHit := FALSE;
    if tagstr = 'GOOD' then begin
      ActionLock := FALSE;
      Inc (ReceiveCount);
    end;
    if tagstr = 'FAIL' then begin
      ActionFailed;
      ActionLock := FALSE;
      Inc (ReceiveCount);
    end;
    if data <> '' then begin
      data := GetValidStr3 (data, tagstr, ['/']);
      CheckSpeedHack (Str_ToInt(tagstr, 0));
      if data <> '' then begin
//            DScreen.AddSysMsg('[°ø¼ÓÇÙÃ¼Å©] Count:'+IntToStr(SHHitSpeedCount));
        if Myself.HitSpeed <> Str_ToInt(data, 0) then begin
//               DScreen.AddSysMsg('[ºñÁ¤»ó]');
          Inc(SHHitSpeedCount);
          if SHHitSpeedCount > 3 then begin
            DScreen.AddChatBoardString ('ÇØÅ·Åø »ç¿ëÁß ÀÔ´Ï´Ù. »ç¿ëÀ» ÁßÁöÇØ ÁÖ½Ê½Ã¿ä.', clYellow, clRed);
          end;
          Myself.HitSpeed := Str_ToInt(data, 0);

          if SHHitSpeedCount > 6 then begin
            if Not SpeedHackUse then begin
              SendSpeedHackUser(10002);
              SpeedHackUse := True;
            end;
            FrmDlg.DMessageDlg ('ÇÁ·Î±×·¥À» Á¾·áÇÕ´Ï´Ù. CODE=10002\' +
                                '¿î¿µÀÚ¿¡°Ô ¹®ÀÇ ¹Ù¶ø´Ï´Ù. [mir2master@wemade.com]',
                                [mbOk]);
            FrmMain.Close;
          end;
        end
        else begin
//               DScreen.AddSysMsg('[Á¤»ó]');
          if SHHitSpeedCount > 0 then Dec(SHHitSpeedCount);
        end;
      end;
    end;
    exit;
  end;
  if Length(datablock) < DEFBLOCKSIZE then begin
    if datablock[1] = '=' then begin
      data := Copy (datablock, 2, Length(datablock)-1);
      if data = 'DIG' then begin
        Myself.BoDigFragment := TRUE;
      end;
    end;
    exit;
  end;

  head := Copy(datablock, 1, DEFBLOCKSIZE);
  body := Copy(datablock, DEFBLOCKSIZE + 1, Length(datablock) - DEFBLOCKSIZE);
  msg := DecodeMessage(head);

  if msg.Ident = SM_DAYCHANGING then begin
    DayBright_fake := msg.Param;
    DarkLevel_fake := msg.Tag;
  end;

  if Myself = nil then begin
    case msg.Ident of
      SM_PASSWD_FAIL:
        begin
          case msg.Recog of
            -1: FrmDlg.DMessageDlg (CMsg.GetMsg(109){'ÊäÈëµÄÃÜÂë²»ÕýÈ·¡£'}, [mbOk]);
            -2: FrmDlg.DMessageDlg (CMsg.GetMsg(110){'ÊäÈëÃÜÂëÁ¬ÐøÈý´Î³öÏÖ´íÎó£¬ÇëÉÔºòÔÙÊÔ¡£'}, [mbOk]);
            -3: FrmDlg.DMessageDlg ('ÇöÀç °èÁ¤ÀÌ »ç¿ëÁßÀÌ°Å³ª, ºñÁ¤»óÀûÀÎ Á¾·á·Î Àá°ÜÁ®ÀÖ½À´Ï´Ù.\Àá½ÃÈÄ¿¡ »ç¿ëÇÏ½Ç ¼ö ÀÖ½À´Ï´Ù.', [mbOk]);
            -4: FrmDlg.DMessageDlg ('ÀÌ °èÁ¤Àº »ç¿ë ±ÇÇÑÀÌ ¾ø½À´Ï´Ù.\´Ù¸¥ °èÁ¤À» »ç¿ëÇÏ½Ê½Ã¿À.\À¯·á µî·Ï ¹®ÀÇ http://www.mir2.co.kr', [mbOk]);
//                  -5: FrmDlg.DMessageDlg ('ÀÌ °èÁ¤Àº '+intToStr(msg.Param)+'ÀÏ ³²Àº ±â°£µ¿¾È »ç¿ëÀÌ ±ÝÁöµÇ¾î ÀÖ´Â °èÁ¤ÀÔ´Ï´Ù.\¹®ÀÇ http://www.mir2.co.kr', [mbOk]);
            -5: FrmDlg.DMessageDlg ('ÀÌ °èÁ¤Àº »ç¿ëÀÌ ±ÝÁöµÇ¾î ÀÖ´Â °èÁ¤ÀÔ´Ï´Ù.\'+intToStr(msg.Param)+'ÀÏ '+intToStr(msg.Tag)+'½Ã°£ ÈÄ¿¡ »ç¿ëÇÒ ¼ö ÀÖ½À´Ï´Ù.\¹®ÀÇ http://www.mir2.co.kr', [mbOk]);
            -10:FrmDlg.DMessageDlg ('¸¸ 14¼¼ ¹Ì¸¸ °í°´´Ôµé²²¼­´Â È¸¿ø°¡ÀÔÈÄ º¸È£ÀÚµ¿ÀÇ¼­°¡ ÇÊ¿äÇÕ´Ï´Ù.\'+
                                    'º¸È£ÀÚµ¿ÀÇ¼­¸¦ º¸³»ÁÖ½ÃÁö ¾Ê´Â °æ¿ì¿¡´Â °ÔÀÓÀÌ¿ëÀÌ ºÒ°¡´ÉÇÕ´Ï´Ù.\'+
                                    'ÀÚ¼¼ÇÑ »çÇ×Àº È¨ÆäÀÌÁö È¸¿ø°¡ÀÔ¶õÀ» Âü°íÇÏ¼¼¿ä.\\'+
                                    '¹®ÀÇ http://www.mir2.co.kr', [mbOk]);
            else  FrmDlg.DMessageDlg (CMsg.GetMsg(108), [mbOk]);
          end;
          LoginScene.PassWdFail;
        end;
      SM_PASSOK_SELECTSERVER:
        begin
          AvailIDDay := Loword(msg.Recog);
          AvailIDHour := Hiword(msg.Recog);
          AvailIPDay := msg.Param;
          AvailIPHour := msg.Tag;

          if AvailIDDay > 0 then begin
            if AvailIDDay = 1 then
               FrmDlg.DMessageDlg (CMsg.GetMsg(102){ÄúµÄ°üÔÂÊ±¼ä½ñÌìµ½ÆÚ¡£}, [mbOk])
            else
               FrmDlg.DMessageDlg (Format(CMsg.GetMsg(103){ÄúµÄ°üÔÂÊ±¼ä»¹Ê£ÏÂ%dÌì¡£)},[AvailIDDay-1]), [mbOk]);
          end else if AvailIPDay > 0 then begin
            if AvailIPDay = 1 then
               FrmDlg.DMessageDlg ('ÇöÀç »ç¿ëÁßÀÎ IPÀÇ »ç¿ë ±â°£ÀÌ ¿À´Ã ³¡³³´Ï´Ù.', [mbOk])
            else // if AvailIPDay <= 3 then
               FrmDlg.DMessageDlg ('ÇöÀç »ç¿ëÁßÀÎ IPÀÇ »ç¿ë ±â°£ÀÌ ' + IntToStr(AvailIPDay) + ' ÀÏ ³²¾Ò½À´Ï´Ù.', [mbOk]);
          end else if AvailIPHour > 0 then begin
            // if AvailIPHour <= 100 then
               FrmDlg.DMessageDlg ('ÇöÀç »ç¿ëÁßÀÎ IPÀÇ »ç¿ë ½Ã°£ÀÌ ' + IntToStr(AvailIPHour) + ' ½Ã°£ ³²¾Ò½À´Ï´Ù.', [mbOk]);
          end else if AvailIDHour > 0 then begin
            FrmDlg.DMessageDlg ('°³ÀÎ °èÁ¤ÀÇ »ç¿ë ½Ã°£ÀÌ ' + IntToStr(AvailIDHour) + ' ½Ã°£ ³²¾Ò½À´Ï´Ù.', [mbOk]);
          end;

          ClientGetSelectServer;
        end;
      SM_PASSOK_WRONGSSN:
        begin
          FrmDlg.DMessageDlg('µî·ÏÇÏ½Å ÁÖ¹Îµî·Ï¹øÈ£°¡ Àß¸øµÇ¾ú½À´Ï´Ù.', [mbOK]);
        end;
      SM_NOT_IN_SERVICE:
        begin
          FrmDlg.DMessageDlg('ÇöÀç ¼­ºñ½º Á¡°ËÁßÀÔ´Ï´Ù.\ÀÚ¼¼ÇÑ »çÇ×Àº È¨ÆäÀÌÁö °øÁö¸¦ ÂüÁ¶ÇØÁÖ½Ê½Ã¿ä.', [mbOk]);
        end;
      SM_SEND_PUBLICKEY:
        begin
          SetPublicKey(msg.Param xor msg.Tag);
        end;
      SM_SELECTSERVER_OK:
        begin
          ClientGetPasswdSuccess(body);
        end;
      SM_QUERYCHR:
        begin
          FrmDlg.DMsgDlgOkClick(self, 0, 0);
          ClientGetReceiveChrs(msg.Recog, body);
        end;
      SM_QUERYCHR_FAIL:
        begin
          DoFastFadeOut := FALSE;
          DoFadeIn := FALSE;
          DoFadeOut := FALSE;
          FrmDlg.DMessageDlg(CMsg.GetMsg(220), [mbOk]);
          Close;
        end;
      SM_NEWCHR_SUCCESS:
        begin
//               SelectChrScene.CreateChrMode := FALSE;
          SelectChrScene.EdChrName.Text := '';
          PlayBGMEx('Sound\SelChr.mp3');
          FrmDlg.DCreateChr.Visible := FALSE;
          SelectChrScene.EdChrName.Visible := FALSE;
          SendQueryChr;
        end;
      SM_NEWCHR_FAIL:
        begin
          case msg.Recog of
            2: FrmDlg.DMessageDlg(CMsg.GetMsg(224){'´Ë½ÇÉ«ÃûÒÑ´æÔÚ.ÇëÖØÐÂÊäÈë.'}, [mbOk]);
            3: FrmDlg.DMessageDlg(CMsg.GetMsg(226), [mbOk]);
            4: FrmDlg.DMessageDlg(CMsg.GetMsg(232){'½ÇÉ«Ãûº¬ÓÐ²»ÔÊÐíÎÄ×Ö¼°×Ö·û£¬Çë¸ü»»½ÇÉ«Ãû¡£'}, [mbOk]);
          else
            FrmDlg.DMessageDlg('[½ÇÆÐ] ¾Ë ¼ö ¾ø´Â ¿À·ùÀÔ´Ï´Ù.', [mbOk]);
          end;
        end;
      SM_CHGPASSWD_SUCCESS:
        begin
          FrmDlg.DMessageDlg('ºñ¹Ð¹øÈ£°¡ Àß ¹Ù²î¾ú½À´Ï´Ù.', [mbOk]);
        end;
      SM_CHGPASSWD_FAIL:
        begin
          case msg.Recog of
            -1: FrmDlg.DMessageDlg ('ÇöÀç ºñ¹Ð¹øÈ£°¡ Æ²·È½À´Ï´Ù. ºñºô¹øÈ£¸¦ º¯°æÇÒ ¼ö ¾ø½À´Ï´Ù.', [mbOk]);
            -2: FrmDlg.DMessageDlg ('ÇöÀç °èÁ¤ÀÌ Àá°ÜÀÖ½À´Ï´Ù. Àá½ÃÈÄ¿¡ »ç¿ëÇÏ½Ê½Ã¿À.', [mbOk]);
            else FrmDlg.DMessageDlg ('¹Ù²Ü ºñ¹Ð¹øÈ£°¡ ³Ê¹« Âª°Å³ª, ¾Ë ¼ö ¾ø´Â ¿À·ù¹ß»ýÇß½À´Ï´Ù.', [mbOk]);
          end;
        end;
      SM_DELCHR_SUCCESS:
        begin
          SendQueryChr;
        end;
      SM_DELCHR_FAIL:
        begin
          FrmDlg.DMessageDlg(CMsg.GetMsg(227){'É¾³ý½ÇÉ«·¢Éú´íÎó¡£'}, [mbOk]);
        end;
      SM_STARTPLAY:
        begin
          ClientGetStartPlay(body);
          exit;
        end;
      SM_STARTFAIL:
        begin
          LoginScene.HideLoginBox;
          FrmDlg.DMessageDlg('Á¢¼Ó·®ÀÇ ÆøÁÖ·Î ÀÎÇÏ¿© ¿¬°áÀÌ ²÷¾îÁ³½À´Ï´Ù.', [mbOk]);
                           //'¼­¹öÀÇ ¿¹±âÄ¡ ¸øÇÑ ¹®Á¦·Î Á¢¼ÓÀÌ Ãë¼ÒµÇ¾ú½À´Ï´Ù.',
          FrmMain.Close;
          exit;
        end;
      SM_VERSION_FAIL:
        begin
          LoginScene.HideLoginBox;
          FrmDlg.DMessageDlg('¹öÀüÀÌ ¸ÂÁö ¾Ê½À´Ï´Ù. ÃÖ½Å ¹öÀüÀ» ´Ù¿î·ÎµåÇÏ½Ê½Ã¿À. (www.mir2.co.kr)', [mbOk]);
          FrmMain.Close;
          exit;
        end;
      SM_OUTOFCONNECTION,
      SM_NEWMAP,
      SM_LOGON,
      SM_RECONNECT,
      SM_SENDNOTICE,
      SM_DLGMSG: ;  //¾Æ·¡¿¡¼­ Ã³¸®
    else
      exit;
    end;
  end;
  if MapMoving then begin
    if msg.Ident = SM_CHANGEMAP then begin
      WaitingMsg := msg;
      WaitingStr := DecodeString(body);
      MapMovingWait := True;
      WaitMsgTimer.Enabled := True;
    end;
    Exit;
  end;

  if msg.Ident = SM_DAYCHANGING then begin
    pDayBrightCheck^ := msg.Param;
    pDarkLevelCheck^ := msg.Tag;
  end;

  case msg.Ident of
    SM_NEWMAP:  // »õ·Î¿î ¸Ê¿¡ µé¾î°¨
      begin
        FrmDlg.SafeCloseDlg;
        MapTitle := '';
        str := DecodeString (body); //mapname
        PlayScene.SendMsg (SM_NEWMAP, 0,
                             msg.Param{x},
                             msg.tag{y},
                             LOBYTE(msg.Series){darkness}, // ¿ë´øÁ¯ FireDragon
                             0, 0, 0,
                             str{mapname});
        EffectNum := HIBYTE(msg.Series);
        if EffectNum < 0 then EffectNum := 0;
        if (EffectNum = 1) or (EffectNum = 2) then RunEffectTimer.Enabled := True
        else RunEffectTimer.Enabled := False;
      end;

    SM_LOGON:
      begin
        FirstServerTime := 0;
        FirstClientTime := 0;
        with msg do begin
           DecodeBuffer (body, @wl, sizeof(TMessageBodyWL));
           PlayScene.SendMsg (SM_LOGON, msg.Recog,
                                msg.Param{x},
                                msg.tag{y},
                                msg.Series{dir},
                                wl.lParam1, //desc.Feature,
                                wl.lParam2, //desc.Status,
                                0,
                                '');
           DScreen.ChangeScene (stPlayGame);
           SendClientMessage (CM_QUERYBAGITEMS, 0, 0, 0, 0);
           if Lobyte(Loword(wl.lTag1)) = 1 then AllowGroup := TRUE
           else AllowGroup := FALSE;
           BoServerChanging := FALSE;
           // 2003/04/15 Ä£±¸, ÂÊÁö
           SendClientMessage (CM_FRIEND_LIST, 0, 0, 0, 0);
        end;
        if AvailIDDay > 0 then begin
           DScreen.AddChatBoardString ('°³ÀÎ °èÁ¤À¸·Î Á¢¼ÓÇÏ¿´½À´Ï´Ù.', clGreen, clWhite)
        end else if AvailIPDay > 0 then begin
           DScreen.AddChatBoardString ('Á¤¾×Á¦ IP¿¡¼­ Á¢¼ÓÇÏ¿´½À´Ï´Ù.', clGreen, clWhite)
        end else if AvailIPHour > 0 then begin
           DScreen.AddChatBoardString ('IP Á¤·®Á¦·Î Á¢¼ÓÇÏ¿´½À´Ï´Ù.', clGreen, clWhite)
        end else if AvailIDHour > 0 then begin
           DScreen.AddChatBoardString ('°³ÀÎ Á¤·®Á¦·Î Á¢¼ÓÇÏ¿´½À´Ï´Ù.', clGreen, clWhite)
        end;
      end;

    SM_CHECK_CLIENTVALID:
      begin

        DecodeBuffer(body, @smsg, sizeof(TShortMessage));
        pClientCheckSum1^ := msg.Recog;
        pClientCheckSum2^ := MakeLong(msg.Param, msg.Tag);
        pClientCheckSum3^ := MakeLong(smsg.Ident, smsg.Msg);

      end;
    SM_RECONNECT:
      begin
        ClientGetReconnect(body);
      end;
    SM_TIMECHECK_MSG:
      begin
        CheckSpeedHack(msg.Recog);
      end;

    SM_AREASTATE:
      begin
        AreaStateValue := msg.Recog;
      end;

    SM_MAPDESCRIPTION:
      begin
        ClientGetMapDescription(body);
      end;

    SM_ADJUST_BONUS:
      begin
        ClientGetAdjustBonus(msg.Recog, body);
      end;

    SM_MYSTATUS:
      begin
        MyHungryState := msg.Param;  //¹è°íÇ° »óÅÂ
      end;

    SM_TURN:
      begin
        if Length(body) > UpInt(sizeof(TCharDesc)*4/3) then begin
          Body2 := Copy (Body, UpInt(sizeof(TCharDesc)*4/3)+1, Length(body));
          data := DecodeString (body2); //Ä³¸¯ ÀÌ¸§
          str := GetValidStr3 (data, data, ['/']);
           //data = ÀÌ¸§
           //str = »ö°¥
        end else data := '';
        DecodeBuffer (body, @desc, sizeof(TCharDesc));
        PlayScene.SendMsg (SM_TURN, msg.Recog,
                             msg.Param{x},
                             msg.tag{y},
                             msg.Series{dir + light},
                             desc.Feature,
                             desc.Status,
                             0,
                             ''); //ÀÌ¸§
        if data <> '' then begin
          actor := PlayScene.FindActor(msg.Recog);
          if actor <> nil then begin
            actor.DescUserName := GetValidStr3(data, actor.UserName, ['\']);
                  //actor.UserName := data;
            actor.NameColor := GetRGB(Str_ToInt(str, 0));
          end;
        end;
      end;

    SM_FOXSTATE:
      begin
        if Length(body) > UpInt(sizeof(TCharDesc)*4/3) then begin
          Body2 := Copy (Body, UpInt(sizeof(TCharDesc)*4/3)+1, Length(body));
          data := DecodeString (body2); //Ä³¸¯ ÀÌ¸§
          str := GetValidStr3 (data, data, ['/']);
           //data = ÀÌ¸§
           //str = »ö°¥
        end else data := '';
        DecodeBuffer (body, @desc, sizeof(TCharDesc));
        PlayScene.SendMsg (SM_TURN, msg.Recog,
                             msg.Param{x},
                             msg.tag{y},
                             msg.Series{dir + light},
                             desc.Feature,
                             desc.Status,
                             0,
                             ''); //ÀÌ¸§

        if data <> '' then begin
          actor := PlayScene.FindActor (msg.Recog);
          if actor <> nil then begin
            actor.DescUserName := GetValidStr3(data, actor.UserName, ['\']);
            //actor.UserName := data;
            actor.NameColor := GetRGB(Str_ToInt(str, 0));
            actor.TempState := Hibyte(msg.Series); //ºñ¿ùÃµÁÖ ÇöÁ¦ »óÅÂ ¹ÞÀ½
//      DScreen.AddChatBoardString ('SM_FOXSTATE: TempState=> '+InttoStr(actor.TempState), clYellow, clRed);
          end;
        end;
      end;

    SM_BACKSTEP:
      begin
        if Length(body) > UpInt(sizeof(TCharDesc)*4/3) then begin
          Body2 := Copy (Body, UpInt(sizeof(TCharDesc)*4/3)+1, Length(body));
          data := DecodeString (body2); //Ä³¸¯ ÀÌ¸§
          str := GetValidStr3 (data, data, ['/']);
           //data = ÀÌ¸§
           //str = »ö°¥
        end else data := '';
        DecodeBuffer (body, @desc, sizeof(TCharDesc));
        PlayScene.SendMsg (SM_BACKSTEP, msg.Recog,
                             msg.Param{x},
                             msg.tag{y},
                             msg.Series{dir + light},
                             desc.Feature,
                             desc.Status,
                             0,
                             ''); //ÀÌ¸§
        if data <> '' then begin
          actor := PlayScene.FindActor (msg.Recog);
          if actor <> nil then begin
            actor.DescUserName := GetValidStr3(data, actor.UserName, ['\']);
              //actor.UserName := data;
            actor.NameColor := GetRGB(Str_ToInt(str, 0));
          end;
        end;
      end;

    SM_SPACEMOVE_HIDE,
    SM_SPACEMOVE_HIDE2:
      begin
        if msg.Recog = Myself.RecogId then begin
          FrmDlg.SafeCloseDlg;
        end
        else
          PlayScene.SendMsg (msg.Ident, msg.Recog, msg.Param{x}, msg.tag{y}, 0, 0, 0, 0, '');
      end;

    SM_SPACEMOVE_SHOW,
    SM_SPACEMOVE_SHOW2:
      begin
        if Length(body) > UpInt(sizeof(TCharDesc)*4/3) then begin
          Body2 := Copy (Body, UpInt(sizeof(TCharDesc)*4/3)+1, Length(body));
          data := DecodeString (body2); //Ä³¸¯ ÀÌ¸§
          str := GetValidStr3 (data, data, ['/']);
           //data = ÀÌ¸§
           //str = »ö°¥
        end else data := '';
        DecodeBuffer (body, @desc, sizeof(TCharDesc));
        if msg.Recog <> Myself.RecogId then begin //´Ù¸¥ Ä³¸¯ÅÍÀÎ °æ¿ì
          PlayScene.NewActor (msg.Recog, msg.Param, msg.tag, msg.Series, desc.feature, desc.Status);
        end;
        PlayScene.SendMsg (msg.Ident, msg.Recog,
                           msg.Param{x},
                           msg.tag{y},
                           msg.Series{dir + light},
                           desc.Feature,
                           desc.Status,
                           0,
                           ''); //ÀÌ¸§
        if data <> '' then begin
          actor := PlayScene.FindActor (msg.Recog);
          if actor <> nil then begin
            actor.DescUserName := GetValidStr3(data, actor.UserName, ['\']);
            //actor.UserName := data;
            actor.NameColor := GetRGB(Str_ToInt(str, 0));
          end;
        end;
      end;
    SM_SPACEMOVE_SHOW_NO:
      begin
        if Length(body) > UpInt(sizeof(TCharDesc)*4/3) then begin
          Body2 := Copy (Body, UpInt(sizeof(TCharDesc)*4/3)+1, Length(body));
          data := DecodeString (body2); //Ä³¸¯ ÀÌ¸§
          str := GetValidStr3 (data, data, ['/']);
          //data = ÀÌ¸§
          //str = »ö°¥
        end else data := '';
        DecodeBuffer (body, @desc, sizeof(TCharDesc));
        if msg.Recog <> Myself.RecogId then begin //´Ù¸¥ Ä³¸¯ÅÍÀÎ °æ¿ì
          PlayScene.NewActor (msg.Recog, msg.Param, msg.tag, msg.Series, desc.feature, desc.Status);
        end;
        PlayScene.SendMsg (msg.Ident, msg.Recog,
                           msg.Param{x},
                           msg.tag{y},
                           msg.Series{dir + light},
                           desc.Feature,
                           desc.Status,
                           0,
                           ''); //ÀÌ¸§
        if data <> '' then begin
          actor := PlayScene.FindActor (msg.Recog);
          if actor <> nil then begin
            actor.DescUserName := GetValidStr3(data, actor.UserName, ['\']);
            //actor.UserName := data;
            actor.NameColor := GetRGB(Str_ToInt(str, 0));
          end;
        end;
      end;

    SM_WALK, SM_RUSH, SM_RUSHKUNG:
      begin
        //DScreen.AddSysMsg ('WALK ' + IntToStr(msg.Param) + ':' + IntToStr(msg.Tag));
        DecodeBuffer (body, @desc, sizeof(TCharDesc));

        if (msg.Recog <> Myself.RecogId) or (msg.Ident = SM_RUSH) or (msg.Ident = SM_RUSHKUNG) then
          PlayScene.SendMsg (msg.Ident, msg.Recog,
                             msg.Param{x},
                             msg.tag{y},
                             msg.Series{dir+light},
                             desc.Feature,
                             desc.Status,
                             0,
                             '');
        if msg.Ident = SM_RUSH then
          LatestRushRushTime := GetTickCount;
      end;

    SM_RUN:
      begin
        //DScreen.AddSysMsg ('RUN ' + IntToStr(msg.Param) + ':' + IntToStr(msg.Tag));
        DecodeBuffer (body, @desc, sizeof(TCharDesc));
        if msg.Recog <> Myself.RecogId then
           PlayScene.SendMsg (SM_RUN, msg.Recog,
                              msg.Param{x},
                              msg.tag{y},
                              msg.Series{dir+light},
                              desc.Feature,
                              desc.Status,
                              0,
                              '');
      end;

    SM_CHANGELIGHT:
      begin
        actor := PlayScene.FindActor (msg.Recog);
        if actor <> nil then begin
          actor.ChrLight := msg.Param;
        end;
      end;

    SM_LAMPCHANGEDURA:
      begin
        if UseItems[U_RIGHTHAND].S.Name <> '' then begin
          UseItems[U_RIGHTHAND].Dura := msg.Recog;
        end;
      end;

    SM_MOVEFAIL:      //»ç¿ë ¾ÈÇÔ...
      begin
        ActionFailed;
        DecodeBuffer (body, @desc, sizeof(TCharDesc));
        PlayScene.SendMsg (SM_TURN, msg.Recog,
                             msg.Param{x},
                             msg.tag{y},
                             msg.Series{dir},
                             desc.Feature,
                             desc.Status,
                             0,
                             '');
      end;

    SM_BUTCH:
      begin
        DecodeBuffer (body, @desc, sizeof(TCharDesc));
        if msg.Recog <> Myself.RecogId then begin
           actor := PlayScene.FindActor (msg.Recog);
           if actor <> nil then
              actor.SendMsg (SM_SITDOWN,
                                msg.Param{x},
                                msg.tag{y},
                                msg.Series{dir},
                                0, 0, '', 0);
        end;
      end;
    SM_SITDOWN:
      begin
        DecodeBuffer (body, @desc, sizeof(TCharDesc));
        if msg.Recog <> Myself.RecogId then begin
           actor := PlayScene.FindActor (msg.Recog);
           if actor <> nil then
              actor.SendMsg (SM_SITDOWN,
                                msg.Param{x},
                                msg.tag{y},
                                msg.Series{dir},
                                0, 0, '', 0);
        end;
      end;

    SM_HIT,
    SM_HEAVYHIT,
    SM_POWERHIT,
    SM_LONGHIT,
    SM_WIDEHIT,
    SM_CROSSHIT,
    SM_TWINHIT,
    SM_STONEHIT,
    SM_BIGHIT,
    SM_FIREHIT:
      begin
        if msg.Recog <> Myself.RecogId then begin
          actor := PlayScene.FindActor (msg.Recog);
          if actor <> nil then begin
            actor.SendMsg (msg.Ident,
                              msg.Param{x},
                              msg.tag{y},
                              msg.Series{dir},
                              0, 0, '',
                              0);
            if msg.ident = SM_HEAVYHIT then begin
               if body <> '' then
                  actor.BoDigFragment := TRUE;
            end;
          end;
        end;
      end;
    SM_FLYAXE:
      begin
        DecodeBuffer (body, @mbw, sizeof(TMessageBodyW));
        actor := PlayScene.FindActor (msg.Recog);
        if actor <> nil then begin
           actor.SendMsg (msg.Ident,
                             msg.Param{x},
                             msg.tag{y},
                             msg.Series{dir},
                             0, 0, '',
                             0);
           actor.TargetX := mbw.Param1;  //x ´øÁö´Â ¸ñÇ¥
           actor.TargetY := mbw.Param2;    //y
           actor.TargetRecog := MakeLong(mbw.Tag1, mbw.Tag2);
        end;
      end;

    SM_LIGHTING, SM_DRAGON_FIRE1, SM_DRAGON_FIRE2, SM_DRAGON_FIRE3, SM_LIGHTING_1..SM_LIGHTING_3:
      begin
        DecodeBuffer (body, @wl, sizeof(TMessageBodyWL));
        actor := PlayScene.FindActor (msg.Recog);
        if actor <> nil then begin
           actor.SendMsg (msg.Ident,
                             msg.Param{x},
                             msg.tag{y},
                             msg.Series{dir},
                             0, 0, '',
                             0);
           actor.TargetX := wl.lParam1;  //x ´øÁö´Â ¸ñÇ¥
           actor.TargetY := wl.lParam2;    //y
           actor.TargetRecog := wl.lTag1;
           actor.MagicNum := wl.lTag2;   //¸¶¹ý ¹øÈ£
        end;
      end;

      // 2003/02/11 ±×·ì¿øÀÇ À§Ä¡ Á¤º¸
    SM_GROUPPOS:
      begin
        DecodeBuffer (body, @mbw, sizeof(TMessageBodyW));
        // 2003/03/04 ±×·ì¿ø Å½±âÆÄ¿¬ ¼³Á¤
        actor := PlayScene.FindActor (msg.Recog);
        if actor <> nil then begin
//               if not actor.BoOpenHealth then
           AddCheck := True;
           if GroupIdList.Count > 0 then
              for i := 0 to GroupIdList.Count-1 do begin
                  if integer(GroupIdList[i]) = actor.RecogId then begin
                     AddCheck := False;
                     Break;
                  end;
              end;
           if AddCheck then GroupIdList.Add(pointer(actor.RecogId)); // MonOpenHp
           actor.BoOpenHealth := TRUE;
        end;
        if(msg.Recog <> MySelf.RecogId) then begin
           idx := -1;
           for i:=1 to MAXVIEWOBJECT do begin
              if(ViewList[i].Index = msg.Recog) then idx := i;
           end;
           if(idx = -1) then begin
             Inc(ViewListCount);
             if(ViewListCount> MAXVIEWOBJECT) then ViewListCount := MAXVIEWOBJECT;
             idx := ViewListCount;
           end;
           ViewList[idx].Index     := msg.Recog;
           ViewList[idx].x         := msg.Param;  {x}
           ViewList[idx].y         := msg.tag;    {y}
           ViewList[idx].LastTick  := GetTickCount;
        end;
      end;

    SM_SPELL: //´Ù¸¥ ÀÌ°¡ ÁÖ¹®À» ¿Ü¿ò
      begin
        UseMagicSpell(msg.Recog{who}, msg.Series{effectnum}, msg.Param{tx}, msg.Tag{y}, Str_ToInt(body, 0));
      end;
    SM_MAGICFIRE:
      begin
        DecodeBuffer (body, @param, sizeof(integer));
        UseMagicFire (msg.Recog{who}, Lobyte(msg.Series){efftype}, Hibyte(msg.Series){effnum}, msg.Param{tx}, msg.Tag{y}, param);
      end;
    SM_MAGICFIRE_FAIL:
      begin
        UseMagicFireFail(msg.Recog{who});
      end;

    SM_NORMALEFFECT:
      begin
          //msg.Recog{who},
        UseNormalEffect(msg.Series{Á¾·ù}, msg.Param{X}, msg.Tag{Y});
      end;
    SM_LOOPNORMALEFFECT:
      begin
        UseLoopNormalEffect(msg.Recog{RecogID}, msg.Series{Á¾·ù}, msg.Param{½Ã°£});
//      DScreen.AddChatBoardString ('SM_LOOPNORMALEFFECT: ·çÇÁÅ¸ÀÓ=> ' +IntToStr(msg.Param), clYellow, clRed);
      end;

    SM_OUTOFCONNECTION:
      begin
        DoFastFadeOut := False;
        DoFadeIn := False;
        DoFadeOut := False;
        FrmDlg.DMessageDlg('¼­¹ö¿¡¼­ ¿¬°áÀÌ °­Á¦ ÇØÁ¦µÇ¾ú½À´Ï´Ù.\¿¬°á½Ã°£ÀÌ ÃÊ°úµÇ¾ú°Å³ª »ç¿ëÀÚÀÇ ÀçÁ¢¼Ó ¿ä±¸·Î ÀÎÇÑ °æ¿ìÀÔ´Ï´Ù.', [mbOK]);
        Close;
      end;

    SM_DEATH,
    SM_NOWDEATH:
      begin
        DecodeBuffer (body, @desc, sizeof(TCharDesc));
        actor := PlayScene.FindActor (msg.Recog);
        if actor <> nil then begin
           actor.SendMsg (msg.Ident,
                          msg.param{x}, msg.Tag{y}, msg.Series{damage},
                          desc.Feature, desc.Status, '',
                          0);
           actor.Abil.HP := 0;
        end else begin
           PlayScene.SendMsg (SM_DEATH, msg.Recog, msg.param{x}, msg.Tag{y}, msg.Series{damage}, desc.Feature, desc.Status, 0, '');
        end;
      end;
    SM_SKELETON:
      begin
        DecodeBuffer (body, @desc, sizeof(TCharDesc));
        PlayScene.SendMsg (SM_SKELETON, msg.Recog, msg.param{HP}, msg.Tag{maxHP}, msg.Series{damage}, desc.Feature, desc.Status, 0, '');
      end;
    SM_ALIVE:
      begin
        DecodeBuffer (body, @desc, sizeof(TCharDesc));
//            UseNormalEffect (NE_RELIVE{Á¾·ù}, MySelf.XX{X}, MySelf.YY{Y});
        PlayScene.SendMsg (SM_ALIVE, msg.Recog, msg.param{HP}, msg.Tag{maxHP}, msg.Series{damage}, desc.Feature, desc.Status, 0, '');
      end;

    SM_ABILITY:
      begin
        Myself.Gold := msg.Recog;
        Myself.Job := msg.Param;
        DecodeBuffer (body, @Myself.Abil, sizeof(TAbility));
        ChangeWalkHitValues (Myself.Abil.Level
                             , Myself.HitSpeed
                             , Myself.Abil.Weight + Myself.Abil.MaxWeight
                             + Myself.Abil.WearWeight + Myself.Abil.MaxWearWeight
                             + Myself.Abil.HandWeight + Myself.Abil.MaxHandWeight
                             , RUN_STRUCK_DELAY
                             );
      end;

    SM_SUBABILITY:
      begin
        MyHitPoint := Lobyte(msg.Param);
        MySpeedPoint := Hibyte(msg.Param);
        MyAntiPoison := Lobyte(msg.Tag);
        MyPoisonRecover := Hibyte(msg.Tag);
        MyHealthRecover := Lobyte(msg.Series);
        MySpellRecover := Hibyte(msg.Series);
        MyAntiMagic := lobyte(loword(msg.Recog));
      end;

    SM_DAYCHANGING:
      begin
        DayBright := msg.Param;
        DarkLevel := msg.Tag;
        if DarkLevel = 0 then
          ViewFog := FALSE
        else
          ViewFog := TRUE;
      end;

    SM_WINEXP:
      begin
        MySelf.Abil.Exp := msg.Recog; //¿À¸¥ °æÇèÄ¡
            //DScreen.AddSysMsg ('°æÇèÄ¡°¡ ' + IntToStr(msg.Param) + ' ¿Ã¶ú½À´Ï´Ù.');
        DScreen.AddChatBoardString('»ñµÃ¾­ÑéÖµ ' + IntToStr(msg.Param) + '', clWhite, clRed);
      end;

    SM_CHANGEFAMEPOINT:
      begin
        MySelf.FameName := DecodeString(body);
        MySelf.Abil.FameCur := msg.Recog; //º¯°æµÈ ¸í¼ºÄ¡
//            DScreen.AddChatBoardString ('SM_CHANGEFAMEPOINT: msg.Recog=> ' + IntToStr(Myself.Abil.FameCur), clWhite, clRed);
//            DScreen.AddChatBoardString ('SM_CHANGEFAMEPOINT: DecodeString (body)=> ' + Myself.FameName, clWhite, clRed);
      end;

    SM_LEVELUP:
      begin
        DScreen.AddSysMsg('·¹º§ÀÌ ¿Ã¶ú½À´Ï´Ù.');
        DScreen.AddChatBoardString('ÃàÇÏÇÕ´Ï´Ù! ·¹º§ÀÌ ¿Ã¶ú½À´Ï´Ù. HP,MP°¡ ¸ðµÎ È¸º¹µÇ¾ú½À´Ï´Ù.', TColor($A21C06), TColor($F6B9DE));
      end;

    SM_POWERUP:
      begin
        meff := nil;

        meff := TNormalDrawEffect.Create (msg.param{x}, msg.Tag{y},
                                       g_WMagicEx[1],
                                       40,  //½ÃÀÛ À§Ä¡
                                       10,   //ÇÁ·¡ÀÓ
                                       100,  //µô·¹ÀÌ
                                       True);
        PlaySound (11022);
        if meff <> nil then begin
          meff.MagOwner := MySelf;  //³» ±âÁØÀ¸·Î
          PlayScene.EffectList.Add(meff);
        end;

      end;

    SM_HEALTHSPELLCHANGED:
      begin
        actor := PlayScene.FindActor(msg.Recog);
        if actor <> nil then begin
          actor.Abil.HP := msg.Param;
          actor.Abil.MP := msg.Tag;
          actor.Abil.MaxHP := msg.Series;
               //actor.BoEatEffect := TRUE;
               //actor.EatEffectFrame := 0;
               //actor.EatEffectTime := GetTickCount;
        end;
      end;

    SM_STRUCK:
      begin
            //wl: TMessageBodyWL;
        DecodeBuffer(body, @wl, sizeof(TMessageBodyWL));
        actor := PlayScene.FindActor(msg.Recog);
        if actor <> nil then begin
          if actor = MySelf then begin
            if MySelf.NameColor = 249 then //»¡°»ÀÌ´Â ¸ÂÀ¸¸é Á¢¼ÓÀ» ¸ø ²÷´Â´Ù.
              LatestStruckTime := GetTickCount;
          end
          else begin
            if actor.CanCancelAction then
              actor.CancelAction;
          end;
          actor.UpdateMsg(SM_STRUCK, wl.lTag2, 0, msg.Series{damage}, wl.lParam1,
            wl.lParam2, '', wl.lTag1{¶§¸°³ð¾ÆÀÌµð});
          actor.Abil.HP := msg.param;
          actor.Abil.MaxHP := msg.Tag;
        end;
      end;

    SM_CHANGEFACE:
      begin
        actor := PlayScene.FindActor(msg.Recog);
        if actor <> nil then begin
          DecodeBuffer(body, @desc, sizeof(TCharDesc));
          actor.WaitForRecogId := MakeLong(msg.Param, msg.Tag);
          actor.WaitForFeature := desc.Feature;
          actor.WaitForStatus := desc.Status;
          AddChangeFace(actor.WaitForRecogId);
        end;
      end;

    SM_OPENHEALTH:
      begin
        actor := PlayScene.FindActor(msg.Recog);
        if actor <> nil then begin
          if actor <> MySelf then begin
            actor.Abil.HP := msg.Param;
            actor.Abil.MaxHP := msg.Tag;
          end;
          actor.BoOpenHealth := TRUE;
               //actor.OpenHealthTime := 999999999;
               //actor.OpenHealthStart := GetTickCount;
        end;
      end;
    SM_CLOSEHEALTH:
      begin
        actor := PlayScene.FindActor(msg.Recog);
        if actor <> nil then begin
          actor.BoOpenHealth := FALSE;
        end;
      end;
    SM_INSTANCEHEALGUAGE:
      begin
        actor := PlayScene.FindActor(msg.Recog);
        if actor <> nil then begin
          actor.Abil.HP := msg.param;
          actor.Abil.MaxHP := msg.Tag;
          actor.BoInstanceOpenHealth := TRUE;
          actor.OpenHealthTime := 2 * 1000;
          actor.OpenHealthStart := GetTickCount;
        end;
      end;

    SM_BREAKWEAPON:
      begin
        actor := PlayScene.FindActor(msg.Recog);
        if actor <> nil then begin
          if actor is THumActor then
            THumActor(actor).DoWeaponBreakEffect;
        end;
      end;

    SM_CRY,
    SM_GROUPMESSAGE,//   ±×·ì ¸Þ¼¼Áö
    SM_GUILDMESSAGE,
    SM_WHISPER,
    SM_SYSMSG_REMARK,
    SM_SYSMESSAGE:
      begin
        str := DecodeString(body);
        DScreen.AddChatBoardString(str, GetRGB(LOBYTE(msg.Param)), GetRGB(HiByte(msg.Param)));
        if msg.Ident = SM_GUILDMESSAGE then
          FrmDlg.AddGuildChat(str)
        else if msg.Ident = SM_SYSMSG_REMARK then
          DScreen.AddSysMsg('clYellow' + str);
      end;

    SM_HEAR:
      begin
        str := DecodeString(body);
        DScreen.AddChatBoardString(str, GetRGB(Lobyte(msg.Param)), GetRGB(Hibyte(msg.Param)));
        actor := PlayScene.FindActor(msg.Recog);
        if actor <> nil then
          actor.Say(str);
      end;

    SM_USERNAME:
      begin
        str := DecodeString(body);
        actor := PlayScene.FindActor(msg.Recog);
        if actor <> nil then begin
               //Username \ »çºÏ¹®ÆÄ / ¸í¼ºÈ£Äª
          actor.FameName := GetValidStr3(str, str, ['/']);
          actor.DescUserName := GetValidStr3(str, actor.Username, ['\']);
          actor.NameColor := GetRGB(msg.Param);
        end;
      end;
    SM_CHANGENAMECOLOR:
      begin
        actor := PlayScene.FindActor(msg.Recog);
        if actor <> nil then begin
          actor.NameColor := GetRGB(msg.Param);
        end;
      end;

    SM_HIDE,
    SM_GHOST,  //ÀÜ»ó..
    SM_DISAPPEAR:
      begin
        if Myself.RecogId <> msg.Recog then
          PlayScene.SendMsg (SM_HIDE, msg.Recog, msg.Param{x}, msg.tag{y}, 0, 0, 0, 0, '');
      end;

    SM_DIGUP:
      begin
        DecodeBuffer (body, @wl, sizeof(TMessageBodyWL));
        actor := PlayScene.FindActor (msg.Recog);
        if actor = nil then
           actor := PlayScene.NewActor (msg.Recog, msg.Param, msg.tag, msg.Series, wl.lParam1, wl.lParam2);
        actor.CurrentEvent := wl.lTag1;
        actor.SendMsg (SM_DIGUP,
                       msg.Param{x},
                       msg.tag{y},
                       msg.Series{dir + light},
                       wl.lParam1,
                       wl.lParam2, '', 0);
      end;
    SM_DIGDOWN:
      begin //È¯¿µÇÑÈ£ msg.Series(¹æÇâ)¹ÞÀ½
        PlayScene.SendMsg(SM_DIGDOWN, msg.Recog, msg.Param{x}, msg.tag{y}, msg.Series, 0, 0, 0, '');
      end;
    SM_SHOWEVENT:
      begin
        DecodeBuffer(body, @smsg, sizeof(TShortMessage));
        event := TClEvent.Create(msg.Recog, Loword(msg.Tag){x}, msg.Series{y}, msg.Param{e-type});
        event.Dir := 0;
        event.EventParam := smsg.Ident;
        EventMan.AddEvent(event);  //clvent°¡ FreeµÉ ¼ö ÀÖÀ½
      end;
    SM_HIDEEVENT:
      begin
        EventMan.DelEventById(msg.Recog);
      end;

      //Item ??
    SM_ADDITEM:
      begin
        ClientGetAddItem(body);
      end;
    SM_COUNTERITEMCHANGE:
      begin
        if not BoDealEnd then
          dealactiontime := GetTickCount;  // ±³È¯ÇÒ¶§ - °ãÄ¡±â ¾ÆÀÌÅÛÀÇ °æ¿ì ¸Þ¼¼Áö ³¯¶ó¿È
        ChangeItemCount(msg.Recog, msg.Param, msg.Tag, DecodeString(body));
      end;
    SM_UPGRADEITEM_RESULT:
      begin
        UpgradeItemResult(msg.Recog, msg.Param, DecodeString(body));
      end;
    SM_BAGITEMS:
      begin
        ClientGetBagItmes(body);
      end;
    SM_UPDATEITEM:
      begin
        ClientGetUpdateItem(body);
      end;
    SM_DELITEM:
      begin
        ClientGetDelItem(body, msg.Tag);
      end;
    SM_DELITEMS:
      begin
        ClientGetDelItems(body);
      end;

    SM_DROPITEM_SUCCESS:
      begin
        DelDropItem(DecodeString(body), msg.Recog);
      end;
    SM_DROPITEM_FAIL:
      begin
        ClientGetDropItemFail(DecodeString(body), msg.Recog);
      end;

    SM_ITEMSHOW:
      begin
        ClientGetShowItem(msg.Recog, msg.param{x}, msg.Tag{y}, msg.Series{looks}, DecodeString(body));
      end;
    SM_ITEMHIDE:
      begin
        ClientGetHideItem(msg.Recog, msg.param, msg.Tag);
      end;

    SM_OPENDOOR_OK: //´©±º°¡¿¡ ÀÇÇØ ¹®ÀÌ ¿­¸²
      begin
        Map.OpenDoor(msg.param, msg.tag);
            //¹®¿©´Â ¼Ò¸®...
      end;

    SM_OPENDOOR_LOCK: //³»°¡ ¿­·Á°í ÇÑ ¹®ÀÌ Àá°ÜÀÖÀ½
      begin
        DScreen.AddSysMsg('¹®ÀÌ Àá°ÜÁ® ÀÖ½À´Ï´Ù.');
      end;
    SM_CLOSEDOOR:
      begin
        Map.CloseDoor(msg.param, msg.tag);
      end;

    SM_CANCLOSE_OK:
      begin
//               DScreen.AddChatBoardString ('Receive=> SM_CANCLOSE_OK:', clYellow, clRed);
        if (GetTickCount - LatestStruckTime > 10000) and
           (GetTickCount - LatestMagicTime > 10000) and
           (GetTickCount - LatestHitTime > 10000) or
           (Myself.Death) then begin
          AppLogOut;
        end else
          DScreen.AddChatBoardString ('ÀüÅõÁß¿¡´Â Á¢¼ÓÀ» ²÷À» ¼ö ¾ø½À´Ï´Ù.', clYellow, clRed);
      end;

    SM_CANCLOSE_FAIL:
      begin
//               DScreen.AddChatBoardString ('Receive=> SM_CANCLOSE_FAIL:', clYellow, clRed);
        DScreen.AddChatBoardString('¼ÒÈ¯¼ö°¡ PKÁß ÀÔ´Ï´Ù, Áö±ÝÀº Á¢¼ÓÀ» ²÷À» ¼ö ¾ø½À´Ï´Ù.', clYellow, clRed);
      end;

    SM_TAKEON_OK:
      begin
        MySelf.Feature := msg.Recog;
        MySelf.FeatureChanged;
        if WaitingUseItem.Index in [0..12] then      //8->12
          UseItems[WaitingUseItem.Index] := WaitingUseItem.Item;
        WaitingUseItem.Item.S.Name := '';
      end;
    SM_CREATEGROUPREQ:
      begin
        str := DecodeString(body);
//        DScreen.AddChatBoardString ('SM_CREATEGROUPREQ: SendUderID=> '+str, clYellow, clRed);
        if not BoMsgDlgTimeCheck then begin
          BoMsgDlgTimeCheck := True;
          FrmDlg.MsgDlgClickTime := GetTickCount + 30000;
          if mrYes = FrmDlg.DMessageDlg(str + '´Ô°ú ±×·ìÀ» ÇÏ½Ã°Ú½À´Ï±î?', [mbYes, mbNo]) then begin
            FrmMain.SendClientMessage2(CM_CREATEGROUPREQ_OK, 0, 0, 0, 0, str);
//        DScreen.AddChatBoardString ('CM_CREATEGROUPREQ_OK', clYellow, clRed);
          end
          else begin
            FrmMain.SendClientMessage2(CM_CREATEGROUPREQ_FAIL, 0, 0, 0, 0, str);
//        DScreen.AddChatBoardString ('CM_CREATEGROUPREQ_FAIL', clYellow, clRed);
          end;
          BoMsgDlgTimeCheck := False;
          FrmDlg.MsgDlgClickTime := GetTickCount;
        end;
      end;

    SM_ADDGROUPMEMBERREQ:
      begin
        str := DecodeString(body);
//        DScreen.AddChatBoardString ('SM_ADDGROUPMEMBERREQ: SendUderID=> '+str, clYellow, clRed);
        if not BoMsgDlgTimeCheck then begin
          BoMsgDlgTimeCheck := True;
          FrmDlg.MsgDlgClickTime := GetTickCount + 30000;
          if mrYes = FrmDlg.DMessageDlg(str + '´Ô°ú ±×·ìÀ» ÇÏ½Ã°Ú½À´Ï±î?', [mbYes, mbNo]) then begin
            FrmMain.SendClientMessage2(CM_ADDGROUPMEMBERREQ_OK, 0, 0, 0, 0, str);
//        DScreen.AddChatBoardString ('CM_ADDGROUPMEMBERREQ_OK', clYellow, clRed);
          end
          else begin
            FrmMain.SendClientMessage2(CM_ADDGROUPMEMBERREQ_FAIL, 0, 0, 0, 0, str);
//        DScreen.AddChatBoardString ('CM_ADDGROUPMEMBERREQ_FAIL', clYellow, clRed);
          end;
          BoMsgDlgTimeCheck := False;
          FrmDlg.MsgDlgClickTime := GetTickCount;
        end;
      end;

    SM_LM_DELETE_REQ:
      begin
        str := DecodeString(body);
//        DScreen.AddChatBoardString ('SM_LM_DELETE_REQ: SendUderID=> '+str, clYellow, clRed);
        if not BoMsgDlgTimeCheck then begin
          BoMsgDlgTimeCheck := True;
          FrmDlg.MsgDlgClickTime := GetTickCount + 30000;
          if mrYes = FrmDlg.DMessageDlg(str +
            '´Ô°ú ¿¬ÀÎ°ü°è¸¦ ÇØÁ¦ÇÏ½Ã°Ú½À´Ï±î?\±³Á¦¸¦ Áß´ÜÇÒ °æ¿ì À§¾à±ÝÀ¸·Î 10¸¸ÀüÀÌ ÀÚµ¿ÁöºÒµË´Ï´Ù.', [mbYes, mbNo])
            then begin
            FrmMain.SendClientMessage2(CM_LM_DELETE_REQ_OK, RsState_Lover, 0, 0, 0, str);
//        DScreen.AddChatBoardString ('CM_LM_DELETE_REQ_OK', clYellow, clRed);
          end
          else begin
            FrmMain.SendClientMessage2(CM_LM_DELETE_REQ_FAIL, RsState_Lover, 0,
              0, 0, str);
//        DScreen.AddChatBoardString ('CM_LM_DELETE_REQ_FAIL', clYellow, clRed);
          end;
          BoMsgDlgTimeCheck := False;
          FrmDlg.MsgDlgClickTime := GetTickCount;
        end;
      end;

    SM_TAKEON_FAIL:
      begin
        AddItemBag(WaitingUseItem.Item);
        WaitingUseItem.Item.S.Name := '';
      end;
    SM_TAKEOFF_OK:
      begin
        MySelf.Feature := msg.Recog;
        MySelf.FeatureChanged;
        WaitingUseItem.Item.S.Name := '';
      end;
    SM_TAKEOFF_FAIL:
      begin
        if WaitingUseItem.Index < 0 then begin
          n := -(WaitingUseItem.Index + 1);
          UseItems[n] := WaitingUseItem.Item;
        end;
        WaitingUseItem.Item.S.Name := '';
      end;
    SM_EXCHGTAKEON_OK:
      ;
    SM_EXCHGTAKEON_FAIL:
      ;

    SM_SENDUSEITEMS:
      begin
        ClientGetSenduseItems (body);
      end;
    SM_WEIGHTCHANGED:
      begin
        if (msg.Recog + msg.Param + msg.Tag) = (((msg.Series xor $aa21) xor $1F35) xor $3A5F) then begin
          Myself.Abil.Weight := msg.Recog;
          Myself.Abil.WearWeight := msg.Param;
          Myself.Abil.HandWeight := msg.Tag;
        end else begin
          Myself.Abil.Weight := 127;
          Myself.Abil.WearWeight := 127;
          Myself.Abil.HandWeight := 127;
        end;
        ChangeWalkHitValues (Myself.Abil.Level
                             , Myself.HitSpeed
                             , Myself.Abil.Weight + Myself.Abil.MaxWeight
                             + Myself.Abil.WearWeight + Myself.Abil.MaxWearWeight
                             + Myself.Abil.HandWeight + Myself.Abil.MaxHandWeight
                             , RUN_STRUCK_DELAY
                             );
      end;
    SM_GOLDCHANGED:
      begin
        SoundUtil.PlaySound(s_money);
        if msg.Recog > MySelf.Gold then begin
          DScreen.AddSysMsg(IntToStr(msg.Recog - MySelf.Gold) + 'ÀüÀ» ¾ò¾ú½À´Ï´Ù.');
        end;
        MySelf.Gold := msg.Recog;
      end;
    SM_FEATURECHANGED:
      begin
        PlayScene.SendMsg(msg.Ident, msg.Recog, 0, 0, 0, MakeLong(msg.Param, msg.Tag), 0, 0, '');
      end;
    SM_CHARSTATUSCHANGED:
      begin
        PlayScene.SendMsg(msg.Ident, msg.Recog, 0, 0, 0, MakeLong(msg.Param, msg.Tag), msg.Series, 0, '');
      end;
    SM_CLEAROBJECTS:
      begin
            //PlayScene.CleanObjects;
        MapMoving := TRUE; //¸Ê ÀÌµ¿Áß
      end;

    SM_EAT_OK:
      begin
//      DScreen.AddChatBoardString ('SM_EAT_OK: EatingItem.S.Name=> '+ EatingItem.S.Name, clYellow, clRed);
        if EatingItem.S.StdMode <> 7 then
          EatingItem.S.Name := ''; // ³ë²öÀÌ ¾Æ´Ï¸é
        if (EatingItem.S.StdMode = 7) and (EatingItem.Dura = 1) then begin
          EatingItem.S.Name := '';
        end;
        if (MovingItem.Item.S.StdMode = 7) and (MovingItem.Item.Dura = 1) then begin
          MovingItem.Item.S.Name := '';
          ItemMoving := FALSE;
//               FrmDlg.CancelItemMoving;
        end;
        ArrangeItembag;
//º§Æ®¾ÆÀÌÅÛ ¼Òºñ½Ã ÀÚµ¿À¸·Î Ã¤¿ì±â 2006/03/22-------------------------
        if StBeltAutoFill then begin
          if ItemArr[BtInDex].S.Name = '' then begin
            i := GetSameItemFromBag(EatingItem);
//      DScreen.AddChatBoardString ('i := GetSameItemFromBag(EatingItem)    i=> '+IntToStr(i), clYellow, clRed);
            if i <> -100 then begin
//      DScreen.AddChatBoardString ('ItemArr[i].S.Name=> '+ ItemArr[i].S.Name  +'     '+IntToStr(i), clYellow, clRed);
              if ItemArr[i].S.Name <> '' then begin
                ItemArr[BtInDex] := ItemArr[i];
                ItemArr[i].S.Name := '';
              end;
            end;
          end;
          StBeltAutoFill := False;
        end;
//---------------------------------------------------------------------
      end;
    SM_EAT_FAIL:
      begin
//      DScreen.AddChatBoardString ('SM_EAT_FAIL: EatingItem.S.Name=> '+ EatingItem.S.Name, clYellow, clRed);
        StBeltAutoFill := False;
        if EatingItem.S.StdMode <> 7 then
          AddItemBag(EatingItem); // ³ë²öÀÌ ¾Æ´Ï¸é
        EatingItem.S.Name := '';
      end;

    SM_ADDMAGIC:
      begin
        if body <> '' then
          ClientGetAddMagic(body);
      end;
    SM_SENDMYMAGIC:
      begin
        if body <> '' then
          ClientGetMyMagics(msg.Recog, body);
      end;
    SM_DELMAGIC:
      begin
        ClientGetDelMagic(msg.Recog);
      end;
    SM_MAGIC_LVEXP:
      begin
        ClientGetMagicLvExp(msg.Recog{magid}, msg.Param{lv}, MakeLong(msg.Tag,
          msg.Series));
      end;
    SM_SOUND:
      begin
        ClientGetSound(msg.Param);
      end;
    SM_DURACHANGE:
      begin
        ClientGetDuraChange(msg.Param{useitem index}, msg.Recog, MakeLong(msg.Tag, msg.Series));
      end;

    SM_MERCHANTSAY:
      begin
        ClientGetMerchantSay(msg.Recog, msg.Param, DecodeString(body));
      end;
    SM_MERCHANTDLGCLOSE:
      begin
//      DScreen.AddChatBoardString ('SM_MERCHANTDLGCLOSE: msg.Param=> '+IntToStr(msg.Param), clYellow, clRed);
//            FrmDlg.CloseMDlg();
        if msg.Param = 0 then
          FrmDlg.CloseMDlg()
        else
          FrmDlg.CloseMDlg2(); //@@@@
      end;
    SM_SENDGOODSLIST:
      begin
        ClientGetSendGoodsList(msg.Recog, msg.Param, body);
      end;
    SM_DECOITEM_LIST:
      begin
//      DScreen.AddChatBoardString ('SM_DECOITEM_LIST: msg.Recog=> '+IntToStr(msg.Recog), clYellow, clRed);
//      DScreen.AddChatBoardString ('SM_DECOITEM_LIST: msg.Param=> '+IntToStr(msg.Param), clYellow, clRed);
        ClientGetDecorationList(msg.Recog, msg.Param, body);
      end;
    SM_DECOITEM_LISTSHOW: //2004/08/05 Àå¿ø²Ù¹Ì±â
      begin
//      DScreen.AddChatBoardString ('SM_DECOITEM_LISTSHOW: msg.Recog=> '+IntToStr(msg.Recog), clYellow, clRed);
//      DScreen.AddChatBoardString ('SM_DECOITEM_LISTSHOW: msg.Param=> '+IntToStr(msg.Param), clYellow, clRed);
        CurMerchant := msg.Recog;
        FrmDlg.ShowGADecorateDlg;
      end;
    SM_SENDUSERMAKEDRUGITEMLIST:
      begin
        ClientGetSendMakeDrugList(msg.Recog, body);
      end;
    SM_SENDUSERMAKEITEMLIST:
      begin
        ClientGetSendMakeItemList(msg.Recog, body);
      end;
    SM_SENDUSERSELL:
      begin
        ClientGetSendUserSell(msg.Recog);
      end;
    SM_SENDUSERREPAIR:
      begin
        ClientGetSendUserRepair(msg.Recog);
      end;
    SM_SENDBUYPRICE:
      begin
        if SellDlgItem.S.Name <> '' then begin
          if msg.Recog > 0 then begin
            if SellDlgItem.S.OverlapItem > 0 then
              SellPriceStr := IntToStr(msg.Recog * SellDlgItem.Dura) + 'Àü'
            else
              SellPriceStr := IntToStr(msg.Recog) + 'Àü';
          end
          else
            SellPriceStr := '????Àü';
        end;
      end;
    SM_USERSELLITEM_OK:
      begin
        FrmDlg.LastestClickTime := GetTickCount;
        MySelf.Gold := msg.Recog;
        SellDlgItemSellWait.S.Name := '';
      end;

    SM_USERSELLITEM_FAIL:
      begin
        FrmDlg.LastestClickTime := GetTickCount;
        AddItemBag(SellDlgItemSellWait);
        SellDlgItemSellWait.S.Name := '';
        FrmDlg.DMessageDlg('ÀÌ ¾ÆÀÌÅÛÀ» ÆÈ ¼ö ¾ø½À´Ï´Ù.', [mbOK]);
      end;

    SM_USERSELLCOUNTITEM_OK:
      begin
        FrmDlg.LastestClickTime := GetTickCount;
        MySelf.Gold := msg.Recog;
        SellItemProg(msg.Param, msg.Tag);
        SellDlgItemSellWait.S.Name := '';
      end;

    SM_USERSELLCOUNTITEM_FAIL:
      begin
        FrmDlg.LastestClickTime := GetTickCount;
        AddItemBag(SellDlgItemSellWait);
        SellDlgItemSellWait.S.Name := '';
        FrmDlg.DMessageDlg('ÀÌ ¾ÆÀÌÅÛÀ» ÆÈ ¼ö ¾ø½À´Ï´Ù.', [mbOk]);
      end;
    SM_SENDREPAIRCOST:
      begin
        if SellDlgItem.S.Name <> '' then begin
          if msg.Recog >= 0 then
            SellPriceStr := IntToStr(msg.Recog) + 'Àü'
          else
            SellPriceStr := '????Àü';
        end;
      end;
      SM_STORAGE_FAIL:
      begin
        FrmDlg.LastestClickTime := GetTickCount;
        if msg.Ident <> SM_STORAGE_OK then begin
          if msg.Ident = SM_STORAGE_FULL then
            FrmDlg.DMessageDlg('°³ÀÎ º¸°ü Ã¢°í°¡ ´Ù Ã¡½À´Ï´Ù. ´õ ÀÌ»ó º¸°üÇÒ ¼ö ¾ø½À´Ï´Ù.', [mbOK])
          else
            FrmDlg.DMessageDlg('º¸°ü ÇÒ ¼ö ¾ø½À´Ï´Ù.', [mbOK]);
          AddItemBag(SellDlgItemSellWait);
        end;
        SellDlgItemSellWait.S.Name := '';
      end;
    SM_SAVEITEMLIST:
      begin
        ClientGetSaveItemList(msg.Recog, msg.tag, msg.series, body);
      end;
    SM_TAKEBACKSTORAGEITEM_OK,
    SM_TAKEBACKSTORAGEITEM_FAIL,
    SM_TAKEBACKSTORAGEITEM_FULLBAG:
      begin
        FrmDlg.LastestClickTime := GetTickCount;
        if msg.Ident <> SM_TAKEBACKSTORAGEITEM_OK then begin
          if msg.Ident = SM_TAKEBACKSTORAGEITEM_FULLBAG then
            FrmDlg.DMessageDlg('´õ ÀÌ»ó µé ¼ö ¾ø½À´Ï´Ù.', [mbOK])
          else
            FrmDlg.DMessageDlg('Ã£À» ¼ö ¾ø½À´Ï´Ù.', [mbOK]);
        end
        else
          FrmDlg.DelStorageItem(msg.Recog, msg.Param); //itemserverindex
      end;

    SM_BUYITEM_SUCCESS:
      begin
        FrmDlg.LastestClickTime := GetTickCount;
        MySelf.Gold := msg.Recog;
        FrmDlg.SoldOutGoods(MakeLong(msg.Param, msg.Tag)); //ÆÈ¸° ¾ÆÀÌÅÛ ¸Þ´º¿¡¼­ »­
      end;
    SM_BUYITEM_FAIL:
      begin
        FrmDlg.LastestClickTime := GetTickCount;
        case msg.Recog of
          1: FrmDlg.DMessageDlg('»óÇ°ÀÌ ´Ù ÆÈ·È½À´Ï´Ù.', [mbOk]);
          2: FrmDlg.DMessageDlg('´õ ÀÌ»ó ¹°°ÇÀ» µéÀ» ¼ö ¾ø½À´Ï´Ù.', [mbOk]);
          3: FrmDlg.DMessageDlg('¹°°ÇÀ» ±¸ÀÔÇÒ µ·ÀÌ ºÎÁ·ÇÕ´Ï´Ù.', [mbOk]);
        end;
      end;
    SM_MAKEDRUG_SUCCESS:
      begin
        FrmDlg.LastestClickTime := GetTickCount;
        MySelf.Gold := msg.Recog;
        FrmDlg.DMessageDlg('¾ÆÀÌÅÛÀÌ Àß ¸¸µé¾î Á³½À´Ï´Ù.', [mbOK]);
      end;
    SM_MAKEDRUG_FAIL:
      begin
        FrmDlg.LastestClickTime := GetTickCount;
        case msg.Recog of
           1: FrmDlg.DMessageDlg ('¿À·ù°¡ ¹ß»ýÇß½À´Ï´Ù.', [mbOk]);
           2: FrmDlg.DMessageDlg ('´õ ÀÌ»ó ¹°°ÇÀ» µéÀ» ¼ö ¾ø½À´Ï´Ù.', [mbOk]);
           3: FrmDlg.DMessageDlg ('µ·ÀÌ ºÎÁ·ÇÕ´Ï´Ù.', [mbOk]);
           4: FrmDlg.DMessageDlg ('Àç·á°¡ ºÎÁ·ÇÕ´Ï´Ù.', [mbOk]);
           5: FrmDlg.DMessageDlg ('º¸¿Á Á¦Á¶¿¡ ½ÇÆÐÇß½À´Ï´Ù.', [mbOk]);
           6: FrmDlg.DMessageDlg ('±¤¼®ÀÇ ¼øµµ°¡ ³·½À´Ï´Ù.', [mbOk]);
        end;
      end;

    SM_SENDDETAILGOODSLIST:
      begin
        ClientGetSendDetailGoodsList(msg.Recog, msg.Param, msg.Tag, body);
      end;

    SM_TEST:
      begin
        Inc(TestReceiveCount);
      end;

    SM_SENDNOTICE:
      begin
        ClientGetSendNotice(body);
      end;

    SM_GROUPMODECHANGED: //¼­¹ö¿¡¼­ ³ªÀÇ ±×·ì ¼³Á¤ÀÌ º¯°æµÇ¾úÀ½.
      begin
        if msg.Param > 0 then
          AllowGroup := TRUE
        else
          AllowGroup := FALSE;
        changegroupmodetime := GetTickCount;
      end;
    SM_CREATEGROUP_OK:
      begin
        changegroupmodetime := GetTickCount;
        AllowGroup := TRUE;
            // 2003/03/04 ±×·ìÀ» ¸Î´Â °æ¿ì ÀÚ±â ÀÚ½ÅÀÇ HP¸¦ º¸¿©ÁÜ
        MySelf.BoOpenHealth := TRUE;
            {GroupMembers.Add (Myself.UserName);
            GroupMembers.Add (DecodeString(body));}
      end;
    SM_CREATEGROUP_FAIL:
      begin
        changegroupmodetime := GetTickCount;
        case msg.Recog of
           -1: FrmDlg.DMessageDlg ('ÀÌ¹Ì ±×·ì¿¡ °¡ÀÔµÇ¾î ÀÖ½À´Ï´Ù.', [mbOk]);
           -2: FrmDlg.DMessageDlg ('±×·ì¿¡ Âü¿©ÇÒ ÀÌ¸§ÀÌ ¹Ù¸£Áö ¾Ê½À´Ï´Ù.', [mbOk]);
           -3: FrmDlg.DMessageDlg ('ÇÔ²² Âü¿©ÇÏ·Á´Â »ç¶÷ÀÌ ´Ù¸¥ ±×·ì¿¡ Âü¿©ÁßÀÔ´Ï´Ù.', [mbOk]);
           -4: FrmDlg.DMessageDlg ('»ó´ë¹æÀÌ ±×·ì°ÅºÎÁßÀÔ´Ï´Ù.', [mbOk]);
           -5: FrmDlg.DMessageDlg ('»ó´ë¹æÀÌ ´Ù¸¥ ±×·ìÀÇ Âü°¡¿©ºÎ¸¦ È®ÀÎÁß ÀÔ´Ï´Ù.', [mbOk]);
        end;
      end;
    SM_GROUPADDMEM_OK:
      begin
        changegroupmodetime := GetTickCount;
            //GroupMembers.Add (DecodeString(body));
      end;
    SM_GROUPADDMEM_FAIL:
      begin
        changegroupmodetime := GetTickCount;
        case msg.Recog of
           -1: FrmDlg.DMessageDlg ('±×·ìÀÌ ¾ÆÁ÷ °á¼ºµÇÁö ¾Ê¾Ò°Å³ª, ±ÇÇÑÀÌ ¾ø½À´Ï´Ù.', [mbOk]);
           -2: FrmDlg.DMessageDlg ('±×·ì¿¡ Âü¿©ÇÒ ÀÌ¸§ÀÌ ¹Ù¸£Áö ¾Ê½À´Ï´Ù.', [mbOk]);
           -3: FrmDlg.DMessageDlg ('ÀÌ¹Ì ±×·ì¿¡ Âü¿©ÁßÀÔ´Ï´Ù.', [mbOk]);
           -4: FrmDlg.DMessageDlg ('»ó´ë¹æÀÌ ±×·ì°ÅºÎÁßÀÔ´Ï´Ù.', [mbOk]);
           -5: FrmDlg.DMessageDlg ('±×·ì¿ø Á¤¿øÀÌ ²ËÃ¡½À´Ï´Ù.', [mbOk]);
        end;
      end;
    SM_GROUPDELMEM_OK:
      begin
        changegroupmodetime := GetTickCount;
            {data := DecodeString (body);
            for i:=0 to GroupMembers.Count-1 do begin
               if GroupMembers[i] = data then begin
                  GroupMembers.Delete (i);
                  break;
               end;
            end; }
      end;
    SM_GROUPDELMEM_FAIL:
      begin
        changegroupmodetime := GetTickCount;
        case msg.Recog of
           -1: FrmDlg.DMessageDlg ('±×·ìÀÌ ¾ÆÁ÷ °á¼ºµÇÁö ¾Ê¾Ò°Å³ª, ±ÇÇÑÀÌ ¾ø½À´Ï´Ù.', [mbOk]);
           -2: FrmDlg.DMessageDlg ('±×·ì¿¡ Âü¿©ÇÒ ÀÌ¸§ÀÌ ¹Ù¸£Áö ¾Ê½À´Ï´Ù.', [mbOk]);
           -3: FrmDlg.DMessageDlg ('¿ì¸® ±×·ì¿¡ Âü¿©ÇÏ°í ÀÖÁö ¾Ê½À´Ï´Ù.', [mbOk]);
        end;
      end;
    SM_GROUPCANCEL:
      begin
            // 2003/03/04 ±×·ìÀÌ ÇØÁ¦µÇ´Â °æ¿ì HPÃâ·ÂÇÏÁö ¾ÊÀ½
        MySelf.BoOpenHealth := FALSE;
        GroupMembers.Clear;
        try
          for i := 0 to GroupIdList.Count - 1 do begin
            actor := PlayScene.FindActor(integer(GroupIdList[i]));
            if actor <> nil then
              actor.BoOpenHealth := False;
          end;
          GroupIdList.Clear;  // MonOpenHp
        except
        end;
      end;
    SM_GROUPMEMBERS:
      begin
            // 2003/03/04 ±×·ìÀÌ ÇØÁ¦µÇ´Â °æ¿ì HPÃâ·ÂÇÏÁö ¾ÊÀ½
        MySelf.BoOpenHealth := TRUE;
        ClientGetGroupMembers(DecodeString(body));
      end;

    SM_OPENGUILDDLG:
      begin
        querymsgtime := GetTickCount;
        ClientGetOpenGuildDlg(body);
      end;

    SM_SENDGUILDMEMBERLIST:
      begin
        querymsgtime := GetTickCount;
        ClientGetSendGuildMemberList(body);
      end;

    SM_OPENGUILDDLG_FAIL:
      begin
        querymsgtime := GetTickCount;
        FrmDlg.DMessageDlg(CMsg.GetMsg(1473), [mbOk]);
      end;

    SM_DEALTRY_FAIL:
      begin
        querymsgtime := GetTickCount;
//        FrmDlg.DMessageDlg('°Å·¡°¡ Ãë¼ÒµÇ¾ú½À´Ï´Ù.\°Å·¡´Â »ç¿ëÀÚÀÎ »ó´ë¹æ°ú ¸¶ÁÖº¸°í ÇØ¾ß ÇÕ´Ï´Ù.', [mbOk]);
      end;
    SM_DEALMENU:
      begin
        querymsgtime := GetTickCount;
        DealWho := DecodeString(body);
        FrmDlg.OpenDealDlg(1);
      end;
    SM_GUILDAGITDEALMENU:
      begin
        querymsgtime := GetTickCount;
        DealWho := DecodeString(body);
        FrmDlg.OpenDealDlg(2);
      end;
    SM_DEALCANCEL:
      begin
        FrmDlg.CancelItemMoving;
        MoveDealItemToBag;

        if DealGold > 0 then begin
          MySelf.Gold := MySelf.GOld + DealGold;
          DealGold := 0;
        end;
        FrmDlg.CloseDealDlg;

//            if DealDlgItem.S.OverlapItem > 0 then FrmDlg.CancelItemMoving;
        FrmDlg.CancelItemMoving;
        if FrmDlg.DCountDlgCancel.Visible then begin
          FrmDlg.DCountDlg.DialogResult := mrCancel;
          FrmDlg.DCountDlg.Visible := False;
        end;
      end;

    SM_DEALADDITEM_OK:
      begin
        dealactiontime := GetTickCount;
        if DealDlgItem.S.Name <> '' then begin
          ResultDealItem(DealDlgItem, msg.Recog, msg.Param);  //Deal Dlg¿¡ Ãß°¡
          DealDlgItem.S.Name := '';
        end;
      end;
    SM_DEALADDITEM_FAIL:
      begin
        dealactiontime := GetTickCount;
        if DealDlgItem.S.Name <> '' then begin
          AddItemBag(DealDlgItem);  //°¡¹æ¿¡ Ãß°¡
          DealDlgItem.S.Name := '';
        end;
      end;
    SM_DEALDELITEM_OK:
      begin
        dealactiontime := GetTickCount;
        if DealDlgItem.S.Name <> '' then begin
               //AddItemBag (DealDlgItem);  //°¡¹æ¿¡ Ãß°¡
          DealDlgItem.S.Name := '';
        end;
      end;
    SM_DEALDELITEM_FAIL:
      begin
        dealactiontime := GetTickCount;
        if DealDlgItem.S.Name <> '' then begin
          DelCountItemBag(DealDlgItem.S.Name, DealDlgItem.MakeIndex, DealDlgItem.Dura);
          AddDealItem(DealDlgItem);
          if (MovingItem.Item.MakeIndex = DealDlgItem.MakeIndex) and (MovingItem.Item.S.Name = DealDlgItem.S.Name) then begin
            ItemMoving := FALSE;
            MovingItem.Item.S.Name := '';
          end;
          DealDlgItem.S.Name := '';
        end;
        FrmDlg.CancelItemMoving;
      end;
    SM_DEALREMOTEADDITEM:
      begin
        ClientGetDealRemoteAddItem(body);
        SoundUtil.PlaySound(s_deal_additem);
      end;
    SM_DEALREMOTEDELITEM:
      begin
        ClientGetDealRemoteDelItem(body);
        SoundUtil.PlaySound(s_deal_delitem);
      end;

    SM_DEALCHGGOLD_OK:
      begin
        DealGold := msg.Recog;
        MySelf.Gold := MakeLong(msg.param, msg.tag);
        dealactiontime := GetTickCount;
      end;
    SM_DEALCHGGOLD_FAIL:
      begin
        DealGold := msg.Recog;
        MySelf.Gold := MakeLong(msg.param, msg.tag);
        dealactiontime := GetTickCount;
      end;
    SM_DEALREMOTECHGGOLD:
      begin
        DealRemoteGold := msg.Recog;
        SoundUtil.PlaySound(s_money);  //»ó´ë¹æÀÌ µ·À» º¯°æÇÑ °æ¿ì ¼Ò¸®°¡ ³­´Ù.
      end;
    SM_DEALSUCCESS:
      begin
        FrmDlg.CloseDealDlg;
      end;

    SM_SENDUSERSTORAGEITEM:  //º¸°üÇÏ´Â Ã¢À» ¶ç¿ò.
      begin
        ClientGetSendUserStorage(msg.Recog);
      end;

    SM_READMINIMAP_OK:
      begin
        querymsgtime := GetTickCount;
        ClientGetReadMiniMap(msg.Param);
      end;

    SM_READMINIMAP_FAIL:
      begin
        querymsgtime := GetTickCount;
        DScreen.AddChatBoardString('µ±Ç°ÇøÓòÃ»ÓÃ¿ÉÓÃµÄÐ¡µØÍ¼.', clWhite, clRed);
        FrmDlg.DMiniMapDlg.Visible := False;
//            BoDrawMiniMap := False;
      end;

    SM_CHANGEGUILDNAME:
      begin
        ClientGetChangeGuildName(DecodeString(body));
      end;

    SM_SENDUSERSTATE:
      begin
//        DScreen.AddChatBoardString('SM_SENDUSERSTATE', clWhite, clRed);
        ClientGetSendUserState(body);
      end;

    SM_GUILDADDMEMBER_OK:
      begin
        SendGuildMemberList;
      end;
    SM_GUILDADDMEMBER_FAIL:
      begin
        case msg.Recog of
           1: FrmDlg.DMessageDlg ('¸í·ÉÀÇ »ç¿ë±ÇÇÑÀÌ ¾ø½À´Ï´Ù.', [mbOk]);
           2: FrmDlg.DMessageDlg ('°¡ÀÔÇÏ·Á´Â »ç¶÷ÀÌ ¹®ÁÖ¿Í ¸¶ÁÖº¸°í ÀÖ¾î¾ß ÇÕ´Ï´Ù.', [mbOk]);
           3: FrmDlg.DMessageDlg ('ÀÌ¹Ì ¿ì¸® ¹®ÆÄ¿¡ °¡ÀÔµÇ¾î ÀÖ½À´Ï´Ù.', [mbOk]);
           4: FrmDlg.DMessageDlg ('ÀÌ¹Ì ´Ù¸¥ ¹®ÆÄ¿¡ °¡ÀÔµÇ¾î ÀÖ½À´Ï´Ù.', [mbOk]);
           5: FrmDlg.DMessageDlg ('»ó´ë¹æÀÌ ¹®ÆÄ°¡ÀÔÀ» Çã¿ëÇÏÁö ¾Ê¾Ò½À´Ï´Ù.', [mbOk]);
        end;
      end;
    SM_GUILDDELMEMBER_OK:
      begin
        SendGuildMemberList;
      end;
    SM_GUILDDELMEMBER_FAIL:
      begin
        case msg.Recog of
           1: FrmDlg.DMessageDlg ('¸í·ÉÀÇ »ç¿ë±ÇÇÑÀÌ ¾ø½À´Ï´Ù.', [mbOk]);
           2: FrmDlg.DMessageDlg ('¿ì¸® ¹®ÆÄÀÇ ¹®¿øÀÌ ¾Æ´Õ´Ï´Ù.', [mbOk]);
           3: FrmDlg.DMessageDlg ('¹®ÁÖ º»ÀÎÀÌ º»ÀÎÀ» Å»Åð ½ÃÅ³ ¼ö ¾ø½À´Ï´Ù.', [mbOk]);
           4: FrmDlg.DMessageDlg ('¸í·ÉÀ» »ç¿ëÇÒ ¼ö ¾ø½À´Ï´Ù.', [mbOk]);
        end;
      end;

    SM_GUILDRANKUPDATE_FAIL:
      begin
        case msg.Recog of
           -2: FrmDlg.DMessageDlg ('[º¯°æ¿À·ù] ¹®ÁÖ°¡ ºñ¾î ÀÖ½À´Ï´Ù.', [mbOk]);
           -3: FrmDlg.DMessageDlg ('[º¯°æ¿À·ù] ¹®ÁÖÀÇ ¸íÄ¢ÀÌ ºñ¾îÀÖ½À´Ï´Ù.', [mbOk]);
           -4: FrmDlg.DMessageDlg ('[º¯°æ¿À·ù] ¹®ÁÖ´Â 2¸íÀ» ÃÊ°úÇÒ ¼ö ¾ø½À´Ï´Ù.', [mbOk]);
           -5: FrmDlg.DMessageDlg ('[º¯°æ¿À·ù] º¯°æµÈ ¹®ÁÖ Áß¿¡¼­ Àû¾îµµ ÇÑ¸íÀÌ»óÀÌ Á¢¼ÓÇÏ°í\ ÀÖ¾î¾ß ÇÕ´Ï´Ù.', [mbOk]);
           -6: FrmDlg.DMessageDlg ('[º¯°æ¿À·ù] ¹®¿øÀÇ Ãß°¡/»èÁ¦¸¦ ÇÒ ¼ö ¾ø½À´Ï´Ù.', [mbOk]);
           -7: FrmDlg.DMessageDlg ('[º¯°æ¿À·ù] Á÷Ã¥ÀÌ Áßº¹µÇ¾îÀÖ°Å³ª Àß¸øµÇ¾ú½À´Ï´Ù.', [mbOk]);
        end;
      end;

    SM_GUILDMAKEALLY_OK,
    SM_GUILDMAKEALLY_FAIL:
      begin
        case msg.Recog of
           -1: FrmDlg.DMessageDlg ('´ç½ÅÀº ±ÇÇÑÀÌ ¾ø½À´Ï´Ù.', [mbOk]);
           -2: FrmDlg.DMessageDlg ('µ¿¸Í¿¡ ½ÇÆÐÇß½À´Ï´Ù.', [mbOk]);
           -3: FrmDlg.DMessageDlg ('µ¿¸ÍÇÏ°í ½ÍÀº ¹®ÁÖ¿Í ¸¶ÁÖºÁ¾ß ÇÕ´Ï´Ù.', [mbOk]);
           -4: FrmDlg.DMessageDlg ('»ó´ë¹®ÁÖ°¡ µ¿¸ÍÀ» Çã¿ëÇÏÁö ¾Ê°í ÀÖ½À´Ï´Ù.', [mbOk]);
        end;
      end;
    SM_GUILDBREAKALLY_OK,
    SM_GUILDBREAKALLY_FAIL:
      begin
        case msg.Recog of
           -1: FrmDlg.DMessageDlg ('´ç½ÅÀº ±ÇÇÑÀÌ ¾ø½À´Ï´Ù.', [mbOk]);
           -2: FrmDlg.DMessageDlg ('±× ¹®ÆÄ¿Í µ¿¸ÍÁßÀÌ ¾Æ´Õ´Ï´Ù.', [mbOk]);
           -3: FrmDlg.DMessageDlg ('Á¸ÀçÇÏÁö ¾Ê´Â ¹®ÆÄÀÔ´Ï´Ù.', [mbOk]);
        end;
      end;


    SM_BUILDGUILD_OK:
      begin
        FrmDlg.LastestClickTime := GetTickCount;
        FrmDlg.DMessageDlg('¹®ÆÄ°¡ ¸¸µé¾î Á³½À´Ï´Ù.', [mbOK]);
      end;

    SM_BUILDGUILD_FAIL:
      begin
        FrmDlg.LastestClickTime := GetTickCount;
        case msg.Recog of
           -1: FrmDlg.DMessageDlg ('ÀÌ¹Ì ¹®ÆÄ¿¡ °¡ÀÔÇØ ÀÖ½À´Ï´Ù.', [mbOk]);
           -2: FrmDlg.DMessageDlg ('µî·Ïºñ¿ëÀÌ ºÎÁ·ÇÕ´Ï´Ù.', [mbOk]);
           -3: FrmDlg.DMessageDlg ('ÇÊ¿ä¾ÆÀÌÅÛÀ» ¸ðµÎ °¡Áö°í ÀÖÁö ¾Ê½À´Ï´Ù.', [mbOk]);
        end;
      end;
    SM_MENU_OK:
      begin
        FrmDlg.LastestClickTime := GetTickCount;
        if body <> '' then
          FrmDlg.DMessageDlg(DecodeString(body), [mbOk]);
      end;
    SM_DLGMSG:
      begin
        if body <> '' then
          FrmDlg.DMessageDlg(DecodeString(body), [mbOk]);
      end;

      // 2003/04/15 Ä£±¸, ÂÊÁö
      SM_USER_INFO:
      begin
        if body <> '' then
          ClientGetUserInfo(msg, body);
      end;

    SM_FRIEND_INFO:
      begin
        if body <> '' then
          ClientGetFriendInfo(msg, body);
      end;
    SM_FRIEND_DELETE:
      begin
        if body <> '' then
          ClientGetDelFriend(msg, body);
      end;
    SM_FRIEND_RESULT:
      begin
        if body <> '' then
          ClientGetFriendResult(msg, body);
      end;
            // 2003/04/15 Ä£±¸, ÂÊÁö
    SM_TAG_ALARM: // ½Å±Ô ¸Þ¼¼Áö µµÂø
      begin
            // if body <> '' then ClientGetTagAlarm (msg ,body);
        ClientGetTagAlarm(msg, body);
      end;
    SM_TAG_LIST:  // ÂÊÁö ¸®½ºÆ®
      begin
        if body <> '' then
          ClientGetTagList(msg, body);
      end;
    SM_TAG_INFO:  // ÂÊÁö Á¤º¸
      begin
        if body <> '' then
          ClientGetTagInfo(msg, body);
      end;
    SM_TAG_REJECT_LIST:   // °ÅºÎÀÚ ¸®½ºÆ®
      begin
        if body <> '' then
          ClientGetTagRejectList(msg, body);
      end;
    SM_TAG_REJECT_ADD:    // °ÅºÎÀÚ µî·Ï
      begin
        if body <> '' then
          ClientGetTagRejectAdd(msg, body);
      end;
    SM_TAG_REJECT_DELETE: // °ÅºÎÀÚ »èÁ¦
      begin
        if body <> '' then
          ClientGetTagRejectDelete(msg, body);
      end;
    SM_TAG_RESULT:        // ÂÊÁö °á°ú
      begin
        if body <> '' then
          ClientGetTagResult(msg, body);
      end;
    SM_LM_OPTION:       // ¿¬ÀÎ»çÁ¦ ¿É¼Çº¯°æ
      begin
        ClientGetLMOptionChange(msg);
      end;
    SM_LM_REQUEST:      // ¿¬ÀÎ»çÁ¦ µî·Ï¿ä±¸
      begin
        ClientGetLMRequest(msg, body);
      end;
    SM_LM_LIST:       // ¿¬ÀÎ»çÁ¦ ¸®½ºÆ®
      begin
        ClientGetLMList(msg, body);
      end;
    SM_LM_RESULT:      // ¿¬ÀÎ»çÁ¦ °á°ú
      begin
        ClientGetLMREsult(msg, body);
      end;
    SM_LM_DELETE:     // ¿¬ÀÎ »çÁ¦ »èÁ¦
      begin
        ClientGetLMDelete(msg, body);
      end;

    SM_MARKET_LIST:  //À§Å¹ÆÇ¸Å ¸®½ºÆ®
      begin
        g_Market.OnMsgWriteData(msg, body);
        FrmDlg.ShowItemMarketDlg; // À§Å¹ÆÇ¸Å ItemMarket
      end;
    SM_MARKET_RESULT: // À§Å¹ÆÇ¸Å °á°ú
      begin
//            DScreen.AddSysMsg ('SM_MARKET_RESULT R:'+ intToStr(msg.Recog));
//            DScreen.AddSysMsg ('SM_MARKET_RESULT P:'+ intToStr(msg.param));
//            DScreen.AddSysMsg ('SM_MARKET_RESULT T:'+ intToStr(msg.Tag));

        case msg.Param of // Market System..
               UMResult_Success:     ;    // 0   ;     // ¼º°ø
               UMResult_Fail:        ;    // 1   ;     // ½ÇÆÐ
               UMResult_ReadFail:    ;    // 2   ;     // ÀÏ±â ½ÇÆÐ
               UMResult_WriteFail:   ;    // 3   ;     // ÀúÀå ½ÇÆÐ
               UMResult_ReadyToSell:      // 4   ;     // ÆÇ¸Å°¡´É
                  begin
                     ClientGetSendUserMaketSell (msg.Recog);
                  end;
               UMResult_OverSellCount:   // 5   ;     // ÆÇ¸Å ¾ÆÀÌÅÛ °³¼ö ÃÊ°ú
                  FrmDlg.DMessageDlg ('À§Å¹ °¡´ÉÇÑ °³¼ö¸¦ ÃÊ°ú ÇÏ¼Ì½À´Ï´Ù. \À§Å¹ÇÏ´ø ¹°Ç°À» È®ÀÎÇÏ½Å ÈÄ ´Ù½Ã °Å·¡ÇÏ½Ê½Ã¿ä.', [mbOk]);
               UMResult_LessMoney:       // 6   ;     // ±ÝÀüºÎÁ·
                  begin
                     FrmDlg.LastestClickTime := GetTickCount;
                     if SellDlgItemSellWait.S.Name <> '' then begin
                        AddItemBag (SellDlgItemSellWait);
                     end;
                     SellDlgItemSellWait.S.Name := '';
                  end;
               UMResult_LessLevel:   ;    // 7   ;     // ·¹º§ºÎÁ·
               UMResult_MaxBagItemCount: ;// 8   ;     // °¡¹æ¿¡ ¾ÆÀÌÅÛ²ËÂü
               UMResult_NoItem:      ;    // 9   ;     // ¾ÆÀÌÅÛÀÌ ¾øÀ½
               UMResult_DontSell:         // 10  ;     // ÆÇ¸ÅºÒ°¡
                  begin
                     FrmDlg.LastestClickTime := GetTickCount;
                     AddItemBag (SellDlgItemSellWait);
                     SellDlgItemSellWait.S.Name := '';
                     FrmDlg.DMessageDlg ('ÀÌ ¾ÆÀÌÅÛÀ» ÆÈ ¼ö ¾ø½À´Ï´Ù.', [mbOk]);
                  end;
               UMResult_DontBuy:        ; // 11  ;     // ±¸ÀÔºÒ°¡
               UMResult_DontGetMoney:   ; // 12  ;     // ±Ý¾×È¸¼ö ºÒ°¡
               UMResult_MarketNotReady: ; // 13  ;     // À§Å¹½Ã½ºÅÛ ÀÚÃ¼°¡ ºÒ°¡´É
               UMResult_LessTrustMoney:   // 14  ;     // À§Å¹±Ý¾×ÀÌ ºÎÁ· 1000 Àü º¸´Ù´Â Ä¿¾ßµÊ
                  begin
                     FrmDlg.LastestClickTime := GetTickCount;
                     if SellDlgItemSellWait.S.Name <> '' then begin
                        AddItemBag (SellDlgItemSellWait);
                     end;
                     SellDlgItemSellWait.S.Name := '';
                  end;

               UMResult_MaxTrustMoney:  ; // 15  ;     // À§Å¹±Ý¾×ÀÌ ³Ê¹« Å­
               UMResult_CancelFail:     ; // 16  ;     // À§Å¹Ãë¼Ò ½ÇÆÐ
               UMResult_OverMoney:      ; // 17  ;     // ¼ÒÀ¯±Ý¾× ÃÖ´ëÄ¡°¡ ³Ñ¾î°¨
               UMResult_SellOK:           // 18  ;     // ÆÇ¸Å°¡ Àß‰çÀ½
                  begin
//      DScreen.AddChatBoardString ('UMResult_SellOK:', clYellow, clRed);
                     FrmDlg.DSellDlg.Visible := FALSE;
                     FrmDlg.LastestClickTime := GetTickCount;
//                     Myself.Gold := msg.Recog;
//                     SellItemProg ( msg.Param, msg.Tag );
                     SellDlgItemSellWait.S.Name := '';
                  end;
               UMResult_BuyOK:          ; // 19  ;     // ±¸ÀÔÀÌ Àß‰çÀ½
               UMResult_CancelOK:       ; // 20  ;     // ÆÇ¸ÅÃë¼Ò°¡ Àß‰çÀ½
               UMResult_GetPayOK:       ; // 21  ;     // ÆÇ¸Å±Ý È¸¼ö°¡ Àß‰çÀ½
        else
        end;
      end;

    SM_GUILDAGITLIST:
      begin
        ClientGetJangwonList(msg.Recog, msg.Param, body);
      end;
    SM_GABOARD_LIST: //Àå¿ø °Ô½ÃÆÇ
      begin
        ClientGetGABoardList(msg.Param, msg.Recog, msg.Tag, body);
      end;
    SM_GABOARD_READ: //Àå¿ø °Ô½ÃÆÇ
      begin
        ClientGetGABoardRead(body);
      end;
    SM_GABOARD_NOTICE_OK:
      begin
        FrmDlg.SendGABoardNoticeOk;
      end;
    SM_GABOARD_NOTICE_FAIL:
      begin
        DScreen.AddChatBoardString('¹®ÁÖ¿¡°Ô¸¸ ¾²±â ±ÇÇÑÀÌ ÀÖ½À´Ï´Ù.', clWhite, clRed);
      end;

    SM_DONATE_OK:
      begin
        FrmDlg.LastestClickTime := GetTickCount;
      end;

    SM_DONATE_FAIL:
      begin
        FrmDlg.LastestClickTime := GetTickCount;
      end;

    SM_NEXTTIME_PASSWORD:
      begin
        if PlayScene.EdChat.PasswordChar = #0 then
          PlayScene.EdChat.PasswordChar := '*';
        BoOneTimePassword := TRUE;
      end;

    SM_PLAYDICE:
      begin
        body2 := Copy(body, UpInt(sizeof(TMessageBodyWL) * 4 / 3) + 1, Length(body));
        DecodeBuffer(body, @wl, sizeof(TMessageBodyWL));
        str := DecodeString(body2);
        FrmDlg.RunDice := msg.Param;

        FrmDlg.DiceType := 1;
        FrmDlg.DiceArr[0].DiceResult := lobyte(loword(wl.lparam1));
        FrmDlg.DiceArr[1].DiceResult := hibyte(loword(wl.lparam1));
        FrmDlg.DiceArr[2].DiceResult := lobyte(hiword(wl.lparam1));
        FrmDlg.DiceArr[3].DiceResult := hibyte(hiword(wl.lparam1));
        FrmDlg.DiceArr[4].DiceResult := lobyte(loword(wl.lparam2));
        FrmDlg.DiceArr[5].DiceResult := hibyte(loword(wl.lparam2));
        FrmDlg.DiceArr[6].DiceResult := lobyte(hiword(wl.lparam2));
        FrmDlg.DiceArr[7].DiceResult := hibyte(hiword(wl.lparam2));
        FrmDlg.DiceArr[8].DiceResult := lobyte(loword(wl.lTag1));
        FrmDlg.DiceArr[9].DiceResult := hibyte(loword(wl.lTag1));
        FrmDlg.DialogSize := 0;

        FrmDlg.DMessageDlg('', []);

        FrmMain.SendMerchantDlgSelect(msg.Recog, str);
      end;

    SM_PLAYROCK:
      begin
        body2 := Copy(body, UpInt(sizeof(TMessageBodyWL) * 4 / 3) + 1, Length(body));
        DecodeBuffer(body, @wl, sizeof(TMessageBodyWL));
        str := DecodeString(body2);

        FrmDlg.RunDice := msg.Param;
        FrmDlg.DiceType := 2;
        FrmDlg.DiceArr[0].DiceResult := lobyte(loword(wl.lparam1));
//      DScreen.AddChatBoardString ('SM_PLAYDICE: DiceResult=> '+InttoStr(FrmDlg.DiceArr[0].DiceResult), clYellow, clRed);
//            FrmDlg.DiceArr[1].DiceResult := hibyte(loword(wl.lparam1));
        FrmDlg.DialogSize := 0;

        FrmDlg.DMessageDlg('', []);
        FrmMain.SendMerchantDlgSelect(msg.Recog, str);
      end;

  else
    begin
      DScreen.AddSysMsg(IntToStr(msg.Ident) + ' : ' + body);
    end;
  end;
  if Pos('#', datablock) > 0 then
    DScreen.AddSysMsg(datablock);
end;

procedure TFrmMain.ClientGetPasswdSuccess(body: string);
var
  str, runaddr, runport, uid, certifystr: string;
begin
  str := DecodeString(body);
  str := GetValidStr3(str, runaddr, ['/']);
  str := GetValidStr3(str, runport, ['/']);
  str := GetValidStr3(str, certifystr, ['/']);
  Certification := Str_ToInt(certifystr, 0);

  if not BoOneClick then begin
    CSocket.Active := False;  //·Î±×ÀÎ¿¡ ¿¬°áµÈ ¼ÒÄÏ ´ÝÀ½
    FrmDlg.DSelServerDlg.Visible := False;
    WaitAndPass(500); //0.5ÃÊµ¿¾È ±â´Ù¸²
    ConnectionStep := cnsSelChr;

//    Application.MessageBox( PChar(runaddr+'/'+runport+'/'+certifystr), PChar('Check'), IDOK);
    with CSocket do begin
      SelChrAddr := runaddr;
      SelChrPort := Str_ToInt(runport, 0);
      Address := SelChrAddr;
      Port := SelChrPort;
      Active := True;
    end;
//    Application.MessageBox( PChar('Activated'), PChar('Check'), IDOK);
  end
  else begin
    FrmDlg.DSelServerDlg.Visible := False;
    SelChrAddr := runaddr;
    SelChrPort := Str_ToInt(runport, 0);

//    Application.MessageBox( PChar(runaddr+'/'+runport+'/'+certifystr), PChar('CheckOneClick'), IDOK);
    if CSocket.Socket.Connected then
      CSocket.Socket.SendText('$S' + runaddr + '/' + runport + '%');
    WaitAndPass(500); //0.5ÃÊµ¿¾È ±â´Ù¸²
    ConnectionStep := cnsSelChr;
    LoginScene.OpenLoginDoor;
    SelChrWaitTimer.Enabled := True;
//    Application.MessageBox( PChar('Activated'), PChar('CheckOneClick'), IDOK);
  end;
  FLoginIDLock := True;
end;

procedure TFrmMain.ClientGetSelectServer;
var
  sname: string;
  bzClose: Bool;
begin
  LoginScene.HideLoginBox;
  FrmDlg.ShowSelectServerDlg;
end;

procedure TFrmMain.ClientGetReceiveChrs(nChrCnt: integer; body: string);
var
  nCnt, select, bMtn: integer;
  str, uname, sjob, shair, slevel, ssex: string;
begin
  SelectChrScene.ClearChrs;
  str := DecodeString(body);
  for nCnt := 0 to 3 do begin
    str := GetValidStr3(str, uname, ['/']);
    str := GetValidStr3(str, sjob, ['/']);
    str := GetValidStr3(str, shair, ['/']);
    str := GetValidStr3(str, slevel, ['/']);
    str := GetValidStr3(str, ssex, ['/']);
    select := 0;
    if (uname <> '') and (slevel <> '') and (ssex <> '') then begin
      if uname[1] = '*' then begin
        select := nCnt;
        uname := Copy(uname, 2, Length(uname) - 1);
      end;
      SelectChrScene.AddChr (uname, Str_ToInt(sjob, 0), Str_ToInt(shair, 0), Str_ToInt(slevel, 0), Str_ToInt(ssex, 0));
    end;
    with SelectChrScene do begin
      if select = 0 then begin
        m_stSelectChrInfo[0].FreezeState := False;
        m_stSelectChrInfo[0].Selected := True;
        m_stSelectChrInfo[1].FreezeState := True;
        m_stSelectChrInfo[1].Selected := False;
//            ChrArr[2].FreezeState := TRUE;
//            ChrArr[2].Selected := FALSE;
      end
      else if select = 1 then begin
        m_stSelectChrInfo[0].FreezeState := True;
        m_stSelectChrInfo[0].Selected := False;
        m_stSelectChrInfo[1].FreezeState := False;
        m_stSelectChrInfo[1].Selected := True;
//            ChrArr[2].FreezeState := TRUE;
//            ChrArr[2].Selected := FALSE;
//         end
//         else if select = 2 then begin
//            ChrArr[0].FreezeState := TRUE;
//            ChrArr[0].Selected := FALSE;
//            ChrArr[1].FreezeState := TRUE;
//            ChrArr[1].Selected := FALSE;
//            ChrArr[2].FreezeState := FALSE;
//            ChrArr[2].Selected := TRUE;
      end;

      bMtn := _CHR_MT_NS;

      if nChrCnt = 1 then begin
        bMtn := _CHR_MT_SM;
        m_stSelectChrInfo[nCnt].stCurrFrmInfo.bBlend := 255;
        m_stSelectChrInfo[nCnt].stCurrFrmInfo.nPosX := 300;
        m_stSelectChrInfo[nCnt].stCurrFrmInfo.nPosY := 210;
      end
      else begin
        if nCnt in [0,2] then begin
          bMtn := _CHR_MT_SM;
          m_stSelectChrInfo[nCnt].stCurrFrmInfo.bBlend := 255;
          m_stSelectChrInfo[nCnt].stCurrFrmInfo.nPosX := 250;
          m_stSelectChrInfo[nCnt].stCurrFrmInfo.nPosY := 210;
        end
        else if nCnt in [1,3] then begin
          m_stSelectChrInfo[nCnt].stCurrFrmInfo.nPosX := 350;
          m_stSelectChrInfo[nCnt].stCurrFrmInfo.nPosY := 250;
        end;
      end;
      m_nSelectedChr := _SELECTED_FST_CHR;
      SetMotion(nCnt, bMtn);
    end;
  end;
  if nChrCnt = 0 then begin
    FrmDlg.DialogSize := 1;
    FrmDlg.DMessageDlg(CMsg.GetMsg(219), [mbOk]);
  end;
end;

procedure TFrmMain.ClientGetStartPlay(body: string);
var
  str, addr, sport: string;
begin
  str := DecodeString(body);
  sport := GetValidStr3(str, addr, ['/']);

  if not BoOneClick then begin
    CSocket.Active := FALSE;  //·Î±×ÀÎ¿¡ ¿¬°áµÈ ¼ÒÄÏ ´ÝÀ½
    WaitAndPass(500); //0.5ÃÊµ¿¾È ±â´Ù¸²

    ConnectionStep := cnsPlay;
    with CSocket do begin
      Address := addr;
      Port := Str_ToInt(sport, 0);
      Active := TRUE;
    end;
  end
  else begin
    SocStr := '';
    BufferStr := '';
    if CSocket.Socket.Connected then
      CSocket.Socket.SendText('$R' + addr + '/' + sport + '%');

    ConnectionStep := cnsPlay;
    ClearBag;  //°¡¹æ ÃÊ±âÈ­
    DScreen.ClearChatBoard; //Ã¤ÆÃÃ¢ ÃÊ±âÈ­
//      DScreen.ChangeScene (stLoading);
    DScreen.ChangeScene(stLoginNotice);

    WaitAndPass(500); //0.5ÃÊµ¿¾È ±â´Ù¸²
    SendRunLogin;
  end;
end;

procedure TFrmMain.ClientGetReconnect(body: string);
var
  str, addr, sport: string;
begin
  str := DecodeString(body);
  sport := GetValidStr3(str, addr, ['/']);

  if not BoOneClick then begin
    if BoBagLoaded then
      Savebags('.\Data\' + ServerName + '.' + CharName + '.itm', @ItemArr);

    if BoOptionLoaded then
      SaveOption('.\Data\' + ServerName + '.' + CharName + '.Opt');
    BoOptionLoaded := FALSE;

    BoBagLoaded := FALSE;

    BoServerChanging := TRUE;
    CSocket.Active := FALSE;  //·Î±×ÀÎ¿¡ ¿¬°áµÈ ¼ÒÄÏ ´ÝÀ½

    WaitAndPass(500); //0.5ÃÊµ¿¾È ±â´Ù¸²

    ConnectionStep := cnsPlay;
    with CSocket do begin
      Address := addr;
      Port := Str_ToInt(sport, 0);
      Active := TRUE;
    end;
  end
  else begin
    if BoBagLoaded then
      SaveBags('.\Data\' + ServerName + '.' + CharName + '.itm', @ItemArr);

    if BoOptionLoaded then
      SaveOption('.\Data\' + ServerName + '.' + CharName + '.Opt');
    BoOptionLoaded := False;

    BoBagLoaded := False;

    SocStr := '';
    BufferStr := '';
    BoServerChanging := True;

    if CSocket.Socket.Connected then   //Á¢¼Ó Á¾·á ½ÅÈ£ º¸³½´Ù.
      CSocket.Socket.SendText('$C' + addr + '/' + sport + '%');

    WaitAndPass(500); //0.5ÃÊµ¿¾È ±â´Ù¸²
    if CSocket.Socket.Connected then   //ÀçÁ¢..
      CSocket.Socket.SendText('$R' + addr + '/' + sport + '%');

    ConnectionStep := cnsPlay;
    ClearBag;  //°¡¹æ ÃÊ±âÈ­
    DScreen.ClearChatBoard; //Ã¤ÆÃÃ¢ ÃÊ±âÈ­
    DScreen.ChangeScene(stLoginNotice);
//      DScreen.ChangeScene (stLoading);

    WaitAndPass(300); //0.5ÃÊµ¿¾È ±â´Ù¸²
    ChangeServerClearGameVariables;

    SendRunLogin;
  end;
end;

procedure TFrmMain.ClientGetMapDescription(body: string);
var
  data: string;
begin
  body := DecodeString(body);
  body := GetValidStr3(body, data, [#13]);
  MapTitle := data; //¸Ê ÀÌ¸§....
end;

procedure TFrmMain.ClientGetAdjustBonus(bonus: integer; body: string);
var
  str1, str2, str3: string;
begin
  BonusPoint := bonus;
  body := GetValidStr3(body, str1, ['/']);
  str3 := GetValidStr3(body, str2, ['/']);
  DecodeBuffer(str1, @BonusTick, sizeof(TNakedAbility));
  DecodeBuffer(str2, @BonusAbil, sizeof(TNakedAbility));
  DecodeBuffer(str3, @NakedAbil, sizeof(TNakedAbility));
  FillChar(BonusAbilChg, sizeof(TNakedAbility), #0);
end;

procedure TFrmMain.ClientGetAddItem(body: string);
var
  cu: TClientItem;
begin
  if body <> '' then begin
    DecodeBuffer(body, @cu, sizeof(TClientItem));
    AddItemBag(cu);
    DScreen.AddSysMsg(cu.S.Name + '±»·¢ÏÖÁË.');
  end;
end;

procedure TFrmMain.ClientGetUpdateItem(body: string);
var
  i: integer;
  cu: TClientItem;
begin
  if body <> '' then begin
    DecodeBuffer(body, @cu, sizeof(TClientItem));
    UpdateItemBag(cu);
    for i := 0 to 12 do begin    // 8 -> 12
      if (UseItems[i].S.Name = cu.S.Name) and (UseItems[i].MakeIndex = cu.MakeIndex)
        then begin
        UseItems[i] := cu;
      end;
    end;
  end;
end;

procedure TFrmMain.ClientGetDelItem(body: string; flag: integer);
var
  i: integer;
  cu: TClientItem;
begin
  if body <> '' then begin
    if flag = 1 then begin
      DecodeBuffer(body, @DelTempItem, sizeof(TClientItem));
    end
    else begin
      DecodeBuffer(body, @cu, sizeof(TClientItem));
      DelItemBag(cu.S.Name, cu.MakeIndex);
      for i := 0 to 12 do begin   // 8 -> 12
        if (UseItems[i].S.Name = cu.S.Name) and (UseItems[i].MakeIndex = cu.MakeIndex)
          then begin
          UseItems[i].S.Name := '';
        end;
      end;
    end;
  end;
end;

procedure TFrmMain.ClientGetDelItems(body: string);
var
  i, iindex: integer;
  str, iname: string;
  cu: TClientItem;
begin
  body := DecodeString(body);
  while body <> '' do begin
    body := GetValidStr3(body, iname, ['/']);
    body := GetValidStr3(body, str, ['/']);
    if (iname <> '') and (str <> '') then begin
      iindex := Str_ToInt(str, 0);
      DelItemBag(iname, iindex);
         // 2003/03/15 ÀÎº¥Åä¸® È®Àå
      for i := 0 to 12 do begin   // 8->12
        if (UseItems[i].S.Name = iname) and (UseItems[i].MakeIndex = iindex) then begin
          UseItems[i].S.Name := '';
        end;
      end;
    end
    else
      break;
  end;
end;

procedure TFrmMain.ClientGetBagItmes(body: string);
var
  str: string;
  cu: TClientItem;
  ItemSaveArr: array[0..MAXBAGITEMCL - 1] of TClientItem;

  function CompareItemArr: Boolean;
  var
    i, j: integer;
    flag: Boolean;
  begin
    flag := TRUE;
    for i := 0 to MAXBAGITEMCL - 1 do begin
      if ItemSaveArr[i].S.Name <> '' then begin
        flag := FALSE;
        for j := 0 to MAXBAGITEMCL - 1 do begin
          if (ItemArr[j].S.Name = ItemSaveArr[i].S.Name) and (ItemArr[j].MakeIndex
            = ItemSaveArr[i].MakeIndex) then begin
            if (ItemArr[j].Dura = ItemSaveArr[i].Dura) and (ItemArr[j].DuraMax =
              ItemSaveArr[i].DuraMax) then begin
              flag := TRUE;
            end;
            break;
          end;
        end;
        if not flag then
          break;
      end;
    end;
    if flag then begin
      for i := 0 to MAXBAGITEMCL - 1 do begin
        if ItemArr[i].S.Name <> '' then begin
          flag := False;
          for j := 0 to MAXBAGITEMCL - 1 do begin
            if (ItemArr[i].S.Name = ItemSaveArr[j].S.Name) and (ItemArr[i].MakeIndex
              = ItemSaveArr[j].MakeIndex) then begin
              if (ItemArr[i].Dura = ItemSaveArr[j].Dura) and (ItemArr[i].DuraMax
                = ItemSaveArr[j].DuraMax) then begin
                flag := True;
              end;
              Break;
            end;
          end;
          if not flag then
            Break;
        end;
      end;
    end;
    Result := flag;
  end;
begin
      //ClearBag;
  FillChar(ItemArr, SizeOf(TClientItem) * MAXBAGITEMCL, #0);
  while True do begin
    if body = '' then Break;
    body := GetValidStr3(body, str, ['/']);
    DecodeBuffer(str, @cu, SizeOf(TClientItem));
    AddItemBag(cu);
  end;
  FillChar(ItemSaveArr, SizeOf(TClientItem) * MAXBAGITEMCL, #0);
  Loadbags('.\Data\' + ServerName + '.' + CharName + '.itm', @ItemSaveArr);
  if CompareItemArr then begin
    Move(ItemSaveArr, ItemArr, SizeOf(TClientItem) * MAXBAGITEMCL);
  end;
  ArrangeItemBag;
  BoBagLoaded := True;
end;

procedure TFrmMain.ClientGetDropItemFail(iname: string; sindex: integer);
var
  pc: PTClientItem;
begin
  pc := GetDropItem(iname, sindex);
  if pc <> nil then begin
    AddItemBag(pc^);
    DelDropItem(iname, sindex);
  end;
end;

procedure TFrmMain.ClientGetShowItem(itemid, x, y, looks: integer; body: string);
var
  i: integer;
  pd: PTDropItem;
  itmname, sDeco: string;
begin
  for i := 0 to DropedItemList.Count - 1 do begin
    if PTDropItem(DropedItemList[i]).id = itemid then
      exit;
  end;
  New(pd);
  pd.Id := itemid;
  pd.X := x;
  pd.Y := y;
  pd.Looks := looks;
  sDeco := '0';
  if body <> '' then begin
    body := GetValidStr3(body, itmname, ['/']);
    body := GetValidStr3(body, sDeco, ['/']);
  end;
  pd.Name := itmname;
  if Str_ToInt(sDeco, 0) = 0 then
    pd.BoDeco := False
  else
    pd.BoDeco := True;

  pd.FlashTime := GetTickCount - Random(3000);
  pd.BoFlash := False;
  DropedItemList.Add(pd);
end;

procedure TFrmMain.ClientGetHideItem(itemid, x, y: integer);
var
  i: integer;
  pd: PTDropItem;
begin
  for i := 0 to DropedItemList.Count - 1 do begin
    if PTDropItem(DropedItemList[i]).id = itemid then begin
      Dispose(PTDropItem(DropedItemList[i]));
      DropedItemlist.Delete(i);
      break;
    end;
  end;
end;

procedure TFrmMain.ClientGetSenduseItems(body: string);
var
  index: integer;
  str, data: string;
  cu: TClientItem;
begin
  FillChar(UseItems, SizeOf(TClientItem) * 13, #0);      // 9->13
  while True do begin
    if body = '' then Break;
    body := GetValidStr3(body, str, ['/']);
    body := GetValidStr3(body, data, ['/']);
    index := Str_ToInt(str, -1);
    if index in [0..12] then begin    // 8->12
      DecodeBuffer(data, @cu, SizeOf(TClientItem));
      UseItems[index] := cu;
    end;
  end;
end;

//procedure TFrmMain.ClientGetAddMagic(body: string);
//var
//  pcm: PTClientMagic;
//begin
//  new(pcm);
//  DecodeBuffer(body, @(pcm^), sizeof(TClientMagic));
//  MagicList.Add(pcm);
//end;

procedure TFrmMain.ClientGetAddMagic(body: string);
var
  pcm: PTClientMagic;
begin
  new(pcm);
  DecodeBuffer(body, @(pcm^), sizeof(TClientMagic));
  m_xMyMagicList[GetMagicType(pcm.Def.MagicId)].Add(pcm);
end;


//procedure TFrmMain.ClientGetDelMagic(magid: integer);
//var
//  i: integer;
//begin
//  for i := MagicList.Count - 1 downto 0 do begin
//    if PTClientMagic(MagicList[i]).Def.MagicId = magid then begin
//      Dispose(PTClientMagic(MagicList[i]));
//      MagicList.Delete(i);
//      break;
//    end;
//  end;
//end;

procedure TFrmMain.ClientGetDelMagic(magid: integer);
var
  I, II: integer;
begin
  for I := 0 to _MAX_TYPE_MAGIC - 1 do begin
    for II := m_xMyMagicList[I].Count - 1 downto 0 do begin
      if PTClientMagic(m_xMyMagicList[I][II]).Def.MagicId = magid then begin
        Dispose(PTClientMagic(m_xMyMagicList[I][II]));
        m_xMyMagicList[I].Delete(II);
        break;
      end;
    end;
  end;
end;

//procedure TFrmMain.ClientGetMyMagics(checksum: integer; body: string);
//var
//  i, mdelay: integer;
//  data: string;
//  pcm: PTClientMagic;
//begin
//  for i := 0 to MagicList.Count - 1 do
//    Dispose(PTClientMagic(MagicList[i]));
//  MagicList.Clear;
//  mdelay := 0;
//  while TRUE do begin
//    if body = '' then
//      break;
//    body := GetValidStr3(body, data, ['/']);
//    if data <> '' then begin
//      new(pcm);
//      DecodeBuffer(data, @(pcm^), sizeof(TClientMagic));
//      MagicList.Add(pcm);
//      mdelay := mdelay + pcm.Def.DelayTime;
//    end else
//      break;
//  end;
//
//  if (checksum xor $4BBC2255) xor $773F1A34 <> mdelay then begin
//    for i := 0 to MagicList.Count - 1 do
//      PTClientMagic(MagicList[i]).Def.DelayTime := 1000;
//  end;
//end;

procedure TFrmMain.ClientGetMyMagics(checksum: integer; body: string);
var
  I, II, mdelay: integer;
  data: string;
  pcm: PTClientMagic;
begin
  for I := 0 to _MAX_TYPE_MAGIC - 1 do begin
    for II := 0 to m_xMyMagicList[I].Count - 1 do begin
      Dispose(PTClientMagic(m_xMyMagicList[I][II]));
    end;
    m_xMyMagicList[I].Clear;
  end;

  mdelay := 0;
  while TRUE do begin
    if body = '' then
      break;
    body := GetValidStr3(body, data, ['/']);
    if data <> '' then begin
      new(pcm);
      DecodeBuffer(data, @(pcm^), sizeof(TClientMagic));
      m_xMyMagicList[GetMagicType(pcm.Def.MagicId)].Add(pcm);
      mdelay := mdelay + pcm.Def.DelayTime;
    end else
      break;
  end;

  if (checksum xor $4BBC2255) xor $773F1A34 <> mdelay then begin
    for I := 0 to _MAX_TYPE_MAGIC - 1 do
      for II := 0 to m_xMyMagicList[I].Count - 1 do
        PTClientMagic(m_xMyMagicList[I][II]).Def.DelayTime := 1000;
  end;
end;

//procedure TFrmMain.ClientGetMagicLvExp(magid, maglv, magtrain: integer);
//var
//  i: integer;
//begin
//  for i := MagicList.Count - 1 downto 0 do begin
//    if PTClientMagic(MagicList[i]).Def.MagicId = magid then begin
//      PTClientMagic(MagicList[i]).level := maglv;
//      PTClientMagic(MagicList[i]).CurTrain := magtrain;
//      break;
//    end;
//  end;
//end;

procedure TFrmMain.ClientGetMagicLvExp(magid, maglv, magtrain: integer);
var
  I, II: integer;
begin
  for I := 0 to _MAX_TYPE_MAGIC - 1 do begin
    for II := m_xMyMagicList[I].Count - 1 downto 0 do begin
      if PTClientMagic(m_xMyMagicList[I][II]).Def.MagicId = magid then begin
        PTClientMagic(m_xMyMagicList[I][II]).level := maglv;
        PTClientMagic(m_xMyMagicList[I][II]).CurTrain := magtrain;
        break;
      end;
    end;
  end;
end;

procedure TFrmMain.ClientGetSound(soundid: integer);
begin
  SilenceSound;
  if soundid <> 0 then begin
    PlaySound(soundid);
  end
end;

procedure TFrmMain.ClientGetDuraChange(uidx, newdura, newduramax: integer);
begin
  if uidx in [0..12] then begin     // 8->12
    if UseItems[uidx].S.Name <> '' then begin
      UseItems[uidx].Dura := newdura;
      UseItems[uidx].DuraMax := newduramax;
    end;
  end;
end;

procedure TFrmMain.ClientGetMerchantSay(merchant, face: integer; saying: string);
var
  npcname: string;
begin
  MDlgX := Myself.XX;
  MDlgY := Myself.YY;
  if CurMerchant <> merchant then begin
    CurMerchant := merchant;
    FrmDlg.ResetMenuDlg;
    FrmDlg.CloseMDlg;
  end;

  saying := GetValidStr3(saying, npcname, ['/']);
  FrmDlg.ShowMDlg(face, npcname, saying);
end;

procedure TFrmMain.ClientGetSendGoodsList(merchant, count: integer; body: string);
var
  i: integer;
  data, gname, gsub, gprice, gstock: string;
  pcg: PTClientGoods;
begin
  FrmDlg.ResetMenuDlg;

  CurMerchant := merchant;
  with FrmDlg do begin
      //deocde body received from server
    body := DecodeString(body);
    while body <> '' do begin
      body := GetValidStr3(body, gname, ['/']);
      body := GetValidStr3(body, gsub, ['/']);
      body := GetValidStr3(body, gprice, ['/']);
      body := GetValidStr3(body, gstock, ['/']);
      if (gname <> '') and (gprice <> '') and (gstock <> '') then begin
        new(pcg);
        pcg.Name := gname;
        pcg.SubMenu := Str_ToInt(gsub, 0);
        pcg.Price := Str_ToInt(gprice, 0);
        pcg.Stock := Str_ToInt(gstock, 0);
        pcg.Grade := -1;
        MenuList.Add(pcg);
      end else
        break;
    end;
    FrmDlg.ShowShopMenuDlg;
    FrmDlg.CurDetailItem := '';
  end;
end;

procedure TFrmMain.ClientGetDecorationList(merchant, count: integer; body: string);
var
  i: integer;
  data, sname, simgindex, sprice, scase: string;
  pcd: PTClientGADecoration;
begin

  with FrmDlg do begin
    for i := 0 to GADecorationList.Count - 1 do
      Dispose(PTClientGADecoration(GADecorationList[i]));
    GADecorationList.Clear;
  end;

//   CurMerchant := merchant;
   //ÀÌ¸§/¹øÈ£/°¡°Ý/Á¾·ù
  with FrmDlg do begin
      //deocde body received from server
    body := DecodeString(body);
    while body <> '' do begin
      body := GetValidStr3(body, sname, ['/']);
      body := GetValidStr3(body, simgindex, ['/']);
      body := GetValidStr3(body, sprice, ['/']);
      body := GetValidStr3(body, scase, ['/']);
//         body := GetValidStr3 (body, sprice, ['/']);
//      DScreen.AddChatBoardString (sname+'/'+stemp1+'/'+simgindex+'/'+stemp2, clYellow, clRed);
//         if (sname <> '') and (sprice <> '') and (simgindex <> '') then begin
      if (sname <> '') and (simgindex <> '') then begin
        New(pcd);
        pcd.Num := Str_ToInt(simgindex, 0);
        pcd.Name := sname;
        pcd.Price := Str_ToInt(sprice, 0);
        pcd.ImgIndex := Str_ToInt(simgindex, 0);
        pcd.CaseNum := Str_ToInt(scase, 0);

        GADecorationList.Add(pcd);
      end else
        Break;
    end;
//      FrmDlg.ShowGADecorateDlg;
  end;
end;

procedure TFrmMain.ClientGetJangwonList(Page, count: integer; body: string);
var //Àå¿ø¸®½ºÆ® ¹ÞÀ½
//   i: integer;
  SNum, SGuildname, SCaptainname1, SCaptainname2, SSellprice, SSellstate: string;
  pcj: PTClientJangwon;
begin
  FrmDlg.ResetMenuDlg;

   //deocde body received from server
   body := DecodeString (body);
  while body <> '' do begin
    body := GetValidStr3(body, SNum, ['/']);
    body := GetValidStr3(body, SGuildname, ['/']);
    body := GetValidStr3(body, SCaptainname1, ['/']);
    body := GetValidStr3(body, SCaptainname2, ['/']);
    body := GetValidStr3(body, SSellprice, ['/']);
    body := GetValidStr3(body, SSellstate, ['/']);
    if (SCaptainname1 <> '') and (SSellprice <> '') and (SSellstate <> '') then begin
      New(pcj);
      pcj.Num := Str_ToInt(SNum, 0);
      pcj.GuildName := SGuildname;
      pcj.CaptaineName1 := SCaptainname1;
      pcj.CaptaineName2 := SCaptainname2;
      pcj.SellPrice := Str_ToInt(SSellprice, 0);
      pcj.SellState := SSellstate;
      FrmDlg.JangwonList.Add(pcj);
//  DScreen.AddChatBoardString (SNum +'/'+ SGuildname +'/'+ SCaptainname +'/'+ SSellprice +'/'+ SSellstate, clYellow, clRed);
    end else
      Break;
  end;
  if Page = 1 then
    FrmDlg.MenuTop := 0
  else if Page = 2 then
    FrmDlg.MenuTop := 10;
  FrmDlg.ShowJangwonDlg; // À§Å¹ÆÇ¸Å ItemMarket

end;

procedure TFrmMain.ClientGetGABoardList(ListNum, Page, MaxPage: integer; body: string);
var //Àå¿ø °Ô½ÃÆÇ ¸®½ºÆ® ¹ÞÀ½
  i: integer;
  SGuildname, SWriteUser, SIndexType1, SIndexType2, SIndexType3, SIndexType4, STitleMsg, LineData: string;
  pcb: PTClientGABoard;
begin
   //deocde body received from server
  body := DecodeString(body);

  body := GetValidStr3(body, SGuildname, ['/']);
  body := GetValidStr3(body, SWriteUser, ['/']);
  body := GetValidStr3(body, SIndexType1, ['/']);
  body := GetValidStr3(body, SIndexType2, ['/']);
  body := GetValidStr3(body, SIndexType3, ['/']);
  body := GetValidStr3(body, SIndexType4, ['/']);
  body := GetValidStr3(body, STitleMsg, ['/']);

  FrmDlg.GABoard_MaxPage := MaxPage;
  FrmDlg.GABoard_CurPage := Page;

  if ListNum = 1 then begin
    FrmDlg.ResetMenuDlg;
    FrmDlg.GABoard_GuildName := SGuildname;
  end;

  if STitleMsg <> '' then begin
    New(pcb);
    pcb.WrigteUser := SWriteUser;
    pcb.IndexType1 := StrToInt(SIndexType1);
    pcb.IndexType2 := StrToInt(SIndexType2);
    pcb.IndexType3 := StrToInt(SIndexType3);
    pcb.IndexType4 := StrToInt(SIndexType4);

    STitleMsg := GetValidStr3(SQLSafeToStr(STitleMsg), LineData, [#13]);
    FrmDlg.GABoard_Notice.Add(LineData);
    pcb.TitleMsg := LineData;
    pcb.ReplyCount := 0;
    if pcb.IndexType2 > 0 then
      Inc(pcb.ReplyCount);
    if pcb.IndexType3 > 0 then
      Inc(pcb.ReplyCount);
    if pcb.IndexType4 > 0 then
      Inc(pcb.ReplyCount);

    FrmDlg.GABoardList.Add(pcb);
  end;

//   if FrmDlg.DGABoardListDlg.Visible then FrmDlg.DGABoardListDlg.Visible := False;
  if ListNum = 100 then FrmDlg.ShowGABoardListDlg;
end;

procedure TFrmMain.ClientGetGABoardRead(body: string);
var
  SWriteUser, STitleMsg, SIndexType1, SIndexType2, SIndexType3, SIndexType4, LineData: string;
begin

  body := DecodeString(body);

  body := GetValidStr3(body, SIndexType1, ['/']);
  body := GetValidStr3(body, SIndexType2, ['/']);
  body := GetValidStr3(body, SIndexType3, ['/']);
  body := GetValidStr3(body, SIndexType4, ['/']);
  body := GetValidStr3(body, SWriteUser, ['/']);
  body := GetValidStr3(body, STitleMsg, ['/']);

  FrmDlg.GABoard_IndexType1 := StrToInt(SIndexType1);
  FrmDlg.GABoard_IndexType2 := StrToInt(SIndexType2);
  FrmDlg.GABoard_IndexType3 := StrToInt(SIndexType3);
  FrmDlg.GABoard_IndexType4 := StrToInt(SIndexType4);

  FrmDlg.GABoard_UserName := SWriteUser;
  FrmDlg.GABoard_TxtBody := STitleMsg;

//DScreen.AddChatBoardString (SIndexType1 +'/'+ SIndexType2 +'/'+ SIndexType3 +'/'+ SIndexType4 +'/'+
//                            SWriteUser +'/'+ STitleMsg , clYellow, clRed);

  FrmDlg.GABoard_Notice.Clear;
//   STitleMsg := GetValidStr3 (SQLSafeToStr(STitleMsg), LineData, [#13]);
//   FrmDlg.GABoard_Notice.Add (SQLSafeToStr(STitleMsg));

  while True do begin
    if STitleMsg = '' then begin
//    DScreen.AddChatBoardString ('STitleMsg=> '+STitleMsg, clYellow, clRed);
//    DScreen.AddChatBoardString ('LineData=> '+LineData, clYellow, clRed);
      Break;
    end;
    STitleMsg := GetValidStr3(SQLSafeToStr(STitleMsg), LineData, [#13]);
    FrmDlg.GABoard_Notice.Add(LineData);
  end;
  FrmDlg.ShowGABoardReadDlg;
end;

procedure TFrmMain.ClientGetSendMakeDrugList(merchant: integer; body: string);
var
  i: integer;
  data, gname, gsub, gprice, gstock: string;
  pcg: PTClientGoods;
begin
  FrmDlg.ResetMenuDlg;

  CurMerchant := merchant;
  with FrmDlg do begin
      //clear shop menu list
      //deocde body received from server
    body := DecodeString(body);
    while body <> '' do begin
      body := GetValidStr3(body, gname, ['/']);
      body := GetValidStr3(body, gsub, ['/']);
      body := GetValidStr3(body, gprice, ['/']);
      body := GetValidStr3(body, gstock, ['/']);
      if (gname <> '') and (gprice <> '') and (gstock <> '') then begin
        New(pcg);
        pcg.Name := gname;
        pcg.SubMenu := Str_ToInt(gsub, 0);
        pcg.Price := Str_ToInt(gprice, 0);
        pcg.Stock := Str_ToInt(gstock, 0);
        pcg.Grade := -1;
        MenuList.Add(pcg);
      end else
        Break;
    end;
    FrmDlg.ShowShopMenuDlg;
    FrmDlg.CurDetailItem := '';
    FrmDlg.BoMakeDrugMenu := True;
  end;
end;

procedure TFrmMain.ClientGetSendMakeItemList(merchant: integer; body: string);
var
  i: integer;
  data, gname, gsub, gprice, gstock: string;
  pcg: PTClientGoods;
begin
  FrmDlg.ResetMenuDlg;

  CurMerchant := merchant;
  with FrmDlg do begin
      //clear shop menu list
      //deocde body received from server
    body := DecodeString(body);
    while body <> '' do begin
      body := GetValidStr3(body, gname, ['/']);
      body := GetValidStr3(body, gsub, ['/']);
      body := GetValidStr3(body, gprice, ['/']);
      body := GetValidStr3(body, gstock, ['/']);
      if (gname <> '') and (gprice <> '') and (gstock <> '') then begin
        new(pcg);
        pcg.Name := gname;
        pcg.SubMenu := Str_ToInt(gsub, 0);
        pcg.Price := Str_ToInt(gprice, 0);
        pcg.Stock := Str_ToInt(gstock, 0);
        pcg.Grade := -1;
        MenuList.Add(pcg);
      end else
        break;
    end;
    FrmDlg.ShowShopMenuDlg;
    FrmDlg.CurDetailItem := '';
    FrmDlg.BoMakeItemMenu := True;
  end;
end;

procedure TFrmMain.ClientGetSendUserSell(merchant: integer);
begin
  FrmDlg.CloseDSellDlg;
  CurMerchant := merchant;
  FrmDlg.SpotDlgMode := dmSell;
  FrmDlg.ShowShopSellDlg;
end;

procedure TFrmMain.ClientGetSendUserRepair(merchant: integer);
begin
  FrmDlg.CloseDSellDlg;
  CurMerchant := merchant;
  FrmDlg.SpotDlgMode := dmRepair;
  FrmDlg.ShowShopSellDlg;
end;

procedure TFrmMain.ClientGetSendUserStorage(merchant: integer);
begin
  FrmDlg.CloseDSellDlg;
  CurMerchant := merchant;
  FrmDlg.SpotDlgMode := dmStorage;
  FrmDlg.ShowShopSellDlg;
end;

procedure TFrmMain.ClientGetSendUserMaketSell(merchant: integer);
begin
  FrmDlg.CloseDSellDlg;
  CurMerchant := merchant;
  FrmDlg.SpotDlgMode := dmMaketSell;
  FrmDlg.ShowShopSellDlg;
end;

procedure TFrmMain.ClientGetSaveItemList(merchant, Currentpage, maxpage: integer; bodystr: string);
var
  i: integer;
  data: string;
  pc: PTClientItem;
  pcg: PTClientGoods;
begin
  FrmDlg.ResetMenuDlg;

//   DScreen.AddSysMsg (IntToStr(CurrentPage) + ' , ' + IntToStr(maxpage) );

  if Currentpage = 0 then begin
    for i := 0 to SaveItemList.Count - 1 do
      Dispose(PTClientItem(SaveItemList[i]));
    SaveItemList.Clear;
  end;

  while True do begin
    if bodystr = '' then Break;
    bodystr := GetValidStr3(bodystr, data, ['/']);
    if data <> '' then begin
      New(pc);
      DecodeBuffer(data, @(pc^), SizeOf(TClientItem));
      SaveItemList.Add(pc);
    end else
      Break;
  end;

  CurMerchant := merchant;
  with FrmDlg do begin
      //deocde body received from server
    for i := 0 to SaveItemList.Count - 1 do begin
      New(pcg);
      pcg.Name := PTClientItem(SaveItemList[i]).S.Name;
      pcg.SubMenu := 0;
      pcg.Price := PTClientItem(SaveItemList[i]).MakeIndex;
      pcg.Stock := Round(PTClientItem(SaveItemList[i]).Dura / 1000);
      pcg.Grade := Round(PTClientItem(SaveItemList[i]).DuraMax / 1000);
      MenuList.Add(pcg);
    end;
    if Currentpage = maxpage then begin
      FrmDlg.ShowShopMenuDlg;
      FrmDlg.BoStorageMenu := True;
    end;
  end;
end;

procedure TFrmMain.ClientGetSendDetailGoodsList(merchant, count, topline: integer; bodystr: string);
var
  i: integer;
  body, data, gname, gprice, gstock, ggrade: string;
  pcg: PTClientGoods;
  pc: PTClientItem;
begin
  FrmDlg.ResetMenuDlg;

  CurMerchant := merchant;

  bodystr := DecodeString(bodystr);
  while True do begin
    if bodystr = '' then Break;
    bodystr := GetValidStr3(bodystr, data, ['/']);
    if data <> '' then begin
      New(pc);
      DecodeBuffer(data, @(pc^), SizeOf(TClientItem));
      MenuItemList.Add(pc);
    end else
      Break;
  end;

  with FrmDlg do begin
      //clear shop menu list
    for i := 0 to MenuItemList.Count - 1 do begin
      New(pcg);
      pcg.Name := PTClientItem(MenuItemList[i]).S.Name;
      pcg.SubMenu := 0;
      pcg.Price := PTClientItem(MenuItemList[i]).DuraMax;
      pcg.Stock := PTClientItem(MenuItemList[i]).MakeIndex;
      pcg.Grade := Round(PTClientItem(MenuItemList[i]).Dura / 1000);
      MenuList.Add(pcg);
    end;
    FrmDlg.ShowShopMenuDlg;
    FrmDlg.BoDetailMenu := True;
    FrmDlg.MenuTopLine := topline;
  end;
end;

procedure TFrmMain.ClientGetSendNotice(body: string);
var
  data, msgstr: string;
begin
  DoFastFadeOut := FALSE;
  msgstr := '';
  body := DecodeString(body);
  while TRUE do begin
    if body = '' then
      break;
    body := GetValidStr3(body, data, [#27]);
    msgstr := msgstr + data + '\';
  end;
  FrmDlg.DialogSize := 2;
  gAutoRun := False;
  if FrmDlg.DMessageDlg(msgstr, [mbOk]) = mrOk then begin
    SendClientMessage(CM_LOGINNOTICEOK, 0, 0, 0, 0);
  end;
end;

procedure TFrmMain.ClientGetGroupMembers(bodystr: string);
var
  memb: string;
  actor: TActor;
  i: integer;
begin
  GroupMembers.Clear;

  try
    for i := 0 to GroupIdList.Count - 1 do begin
      actor := PlayScene.FindActor(integer(GroupIdList[i]));
      if actor <> nil then
        actor.BoOpenHealth := False;
    end;
    GroupIdList.Clear; // MonOpenHp
  except
  end;

  while True do begin
    if bodystr = '' then Break;
    bodystr := GetValidStr3(bodystr, memb, ['/']);
    if memb <> '' then
      GroupMembers.Add(memb)
    else
      Break;
  end;
end;

procedure TFrmMain.ClientGetOpenGuildDlg(bodystr: string);
var
  str, data, linestr, s1: string;
  pstep: integer;
begin
  str := DecodeString(bodystr);
  str := GetValidStr3(str, FrmDlg.Guild, [#13]);
  str := GetValidStr3(str, FrmDlg.GuildFlag, [#13]);
  str := GetValidStr3(str, data, [#13]);
  if data = '1' then
    FrmDlg.GuildCommanderMode := TRUE
  else
    FrmDlg.GuildCommanderMode := FALSE;

  FrmDlg.GuildStrs.Clear;
  FrmDlg.GuildNotice.Clear;
  pstep := 0;
  while True do begin
    if str = '' then
      Break;
    str := GetValidStr3(str, data, [#13]);
    if data = '<Notice>' then begin
      FrmDlg.GuildStrs.AddObject(Char(7) + '°øÁö»çÇ×', TObject(clWhite));
      FrmDlg.GuildStrs.Add(' ');
      pstep := 1;
      Continue;
    end;
    if data = '<KillGuilds>' then begin
      FrmDlg.GuildStrs.Add(' ');
      FrmDlg.GuildStrs.AddObject(Char(7) + 'Àû´ë¹®ÆÄ', TObject(clWhite));
      FrmDlg.GuildStrs.Add(' ');
      pstep := 2;
      linestr := '';
      Continue;
    end;
    if data = '<AllyGuilds>' then begin
      if linestr <> '' then
        FrmDlg.GuildStrs.Add(linestr);
      linestr := '';
      FrmDlg.GuildStrs.Add(' ');
      FrmDlg.GuildStrs.AddObject(Char(7) + 'µ¿¸Í¹®ÆÄ', TObject(clWhite));
      FrmDlg.GuildStrs.Add(' ');
      pstep := 3;
      Continue;
    end;

    if pstep = 1 then
      FrmDlg.GuildNotice.Add(data);

    if data <> '' then begin
      if data[1] = '<' then begin
        ArrestStringEx(data, '<', '>', s1);
        if s1 <> '' then begin
          FrmDlg.GuildStrs.Add(' ');
          FrmDlg.GuildStrs.AddObject(Char(7) + s1, TObject(clWhite));
          FrmDlg.GuildStrs.Add(' ');
          Continue;
        end;
      end;
    end;
    if (pstep = 2) or (pstep = 3) then begin
      if Length(linestr) > 80 then begin
        FrmDlg.GuildStrs.Add(linestr);
        linestr := '';
        linestr := linestr + fmStr(data, 18);
      end
      else begin
        linestr := linestr + fmStr(data, 18);
      end;
      Continue;
    end;

    FrmDlg.GuildStrs.Add(data);
  end;

  if linestr <> '' then FrmDlg.GuildStrs.Add(linestr);
  FrmDlg.ShowGuildDlg;
end;

procedure TFrmMain.ClientGetSendGuildMemberList(body: string);
var
  str, data, rankname, members: string;
  rank: integer;
begin
  str := DecodeString(body);
  FrmDlg.GuildStrs.Clear;
  FrmDlg.GuildMembers.Clear;
  rank := 0;
  while TRUE do begin
    if str = '' then
      break;
    str := GetValidStr3(str, data, ['/']);
    if data <> '' then begin
      if data[1] = '#' then begin
        rank := Str_ToInt(Copy(data, 2, Length(data) - 1), 0);
        continue;
      end;
      if data[1] = '*' then begin
        if members <> '' then
          FrmDlg.GuildStrs.Add(members);
        rankname := Copy(data, 2, Length(data) - 1);
        members := '';
        FrmDlg.GuildStrs.Add(' ');
        if FrmDlg.GuildCommanderMode then
          FrmDlg.GuildStrs.AddObject(fmStr('(' + IntToStr(rank) + ')', 3) + '<'
            + rankname + '>', TObject(clWhite))
        else
          FrmDlg.GuildStrs.AddObject('<' + rankname + '>', TObject(clWhite));
        FrmDlg.GuildMembers.Add('#' + IntToStr(rank) + ' <' + rankname + '>');
        continue;
      end;
      if Length(members) > 80 then begin
        FrmDlg.GuildStrs.Add(members);
        members := '';
      end;
      members := members + FmStr(data, 18);
      FrmDlg.GuildMembers.Add(data);
    end;
  end;
  if members <> '' then
    FrmDlg.GuildStrs.Add(members);
end;

procedure TFrmMain.MinTimerTimer(Sender: TObject);
var
  i: integer;
  timertime: longword;
begin
  with PlayScene do
    for i := 0 to ActorList.Count - 1 do begin
      if IsGroupMember(TActor(ActorList[i]).UserName) then begin
        TActor(ActorList[i]).Grouped := TRUE;
      end
      else
        TActor(ActorList[i]).Grouped := FALSE;
    end;
  for i := FreeActorList.Count - 1 downto 0 do begin
    if GetTickCount - TActor(FreeActorList[i]).DeleteTime > 60000 then begin
      TActor(FreeActorList[i]).Free;
      FreeActorList.Delete(i);
    end;
  end;
end;

procedure TFrmMain.CheckHackTimerTimer(Sender: TObject);
const
  busy: boolean = FALSE;
var
  ahour, amin, asec, amsec: word;
  tcount, timertime: longword;
begin
(*   if busy then exit;
   busy := TRUE;
   DecodeTime (Time, ahour, amin, asec, amsec);
   timertime := amin * 1000 * 60 + asec * 1000 + amsec;
   tcount := GetTickCount;

   if BoCheckSpeedHackDisplay then begin
      DScreen.AddSysMsg (IntToStr(tcount - LatestClientTime2) + ' ' +
                         IntToStr(timertime - LatestClientTimerTime) + ' ' +
                         IntToStr(abs(tcount - LatestClientTime2) - abs(timertime - LatestClientTimerTime)));
                         // + ',  ' +
                         //IntToStr(tcount - FirstClientGetTime) + ' ' +
                         //IntToStr(timertime - FirstClientTimerTime) + ' ' +
                         //IntToStr(abs(tcount - FirstClientGetTime) - abs(timertime - FirstClientTimerTime)));
   end;

   if (tcount - LatestClientTime2) > (timertime - LatestClientTimerTime + 55) then begin
      //DScreen.AddSysMsg ('**' + IntToStr(tcount - LatestClientTime2) + ' ' + IntToStr(timertime - LatestClientTimerTime));
      Inc (TimeFakeDetectTimer);
      if TimeFakeDetectTimer > 3 then begin
         //½Ã°£ Á¶ÀÛ...
         SendSpeedHackUser;
         FrmDlg.DMessageDlg ('ÇØÅ· ÇÁ·Î±×·¥ »ç¿ëÀÚ·Î ±â·Ï µÇ¾ú½À´Ï´Ù.\' +
                             'ÀÌ·¯ÇÑ Á¾·ùÀÇ ÇÁ·Î±×·¥À» »ç¿ëÇÏ´Â °ÍÀº ºÒ¹ýÀÌ¸ç,\' +
                             '°èÁ¤ ¾Ð·ùµîÀÇ Á¦Àç Á¶Ä¡°¡ °¡ÇØÁú ¼ö ÀÖÀ½À» ¾Ë·Áµå¸³´Ï´Ù.\' +
                             '[¹®ÀÇ] mir2master@wemade.com\' +
                             'ÇÁ·Î±×·¥À» Á¾·áÇÕ´Ï´Ù.', [mbOk]);
         FrmMain.Close;
      end;
   end else
      TimeFakeDetectTimer := 0;


   if FirstClientTimerTime = 0 then begin
      FirstClientTimerTime := timertime;
      FirstClientGetTime := tcount;
   end else begin
      if (abs(timertime - LatestClientTimerTime) > 500) or
         (timertime < LatestClientTimerTime)
      then begin
         FirstClientTimerTime := timertime;
         FirstClientGetTime := tcount;
      end;
      if abs(abs(tcount - FirstClientGetTime) - abs(timertime - FirstClientTimerTime)) > 5000 then begin
         Inc (TimeFakeDetectSum);
         if TimeFakeDetectSum > 25 then begin
            //½Ã°£ Á¶ÀÛ...
            SendSpeedHackUser;
            FrmDlg.DMessageDlg ('ÇØÅ· ÇÁ·Î±×·¥ »ç¿ëÀÚ·Î ±â·Ï µÇ¾ú½À´Ï´Ù.\' +
                                'ÀÌ·¯ÇÑ Á¾·ùÀÇ ÇÁ·Î±×·¥À» »ç¿ëÇÏ´Â °ÍÀº ºÒ¹ýÀÌ¸ç,\' +
                                '°èÁ¤ ¾Ð·ùµîÀÇ Á¦Àç Á¶Ä¡°¡ °¡ÇØÁú ¼ö ÀÖÀ½À» ¾Ë·Áµå¸³´Ï´Ù.\' +
                                '[¹®ÀÇ] mir2master@wemade.com\' +
                                'ÇÁ·Î±×·¥À» Á¾·áÇÕ´Ï´Ù.', [mbOk]);
            FrmMain.Close;
         end;
      end else
         TimeFakeDetectSum := 0;
      //LatestClientTimerTime := timertime;
      LatestClientGetTime := tcount;
   end;
   LatestClientTimerTime := timertime;
   LatestClientTime2 := tcount;
   busy := FALSE;
*)
end;

(**
const
   busy: boolean = FALSE;
var
   ahour, amin, asec, amsec: word;
   timertime, tcount: longword;
begin
   if busy then exit;
   busy := TRUE;
   DecodeTime (Time, ahour, amin, asec, amsec);
   timertime := amin * 1000 * 60 + asec * 1000 + amsec;
   tcount := GetTickCount;

   //DScreen.AddSysMsg (IntToStr(tcount - FirstClientGetTime) + ' ' +
   //                   IntToStr(timertime - FirstClientTimerTime) + ' ' +
   //                   IntToStr(abs(tcount - FirstClientGetTime) - abs(timertime - FirstClientTimerTime)));

   if FirstClientTimerTime = 0 then begin
      FirstClientTimerTime := timertime;
      FirstClientGetTime := tcount;
   end else begin
      if (abs(timertime - LatestClientTimerTime) > 2000) or
         (timertime < LatestClientGetTime)
      then begin
         FirstClientTimerTime := timertime;
         FirstClientGetTime := tcount;
      end;
      if abs(abs(tcount - FirstClientGetTime) - abs(timertime - FirstClientTimerTime)) > 2000 then begin
         Inc (TimeFakeDetectSum);
         if TimeFakeDetectSum > 10 then begin
            //½Ã°£ Á¶ÀÛ...
            SendSpeedHackUser;
            FrmDlg.DMessageDlg ('ÇØÅ· ÇÁ·Î±×·¥ »ç¿ëÀÚ·Î ±â·Ï µÇ¾ú½À´Ï´Ù.\' +
                                'ÀÌ·¯ÇÑ Á¾·ùÀÇ ÇÁ·Î±×·¥À» »ç¿ëÇÏ´Â °ÍÀº ºÒ¹ýÀÌ¸ç,\' +
                                '°èÁ¤ ¾Ð·ùµîÀÇ Á¦Àç Á¶Ä¡°¡ °¡ÇØÁú ¼ö ÀÖÀ½À» ¾Ë·Áµå¸³´Ï´Ù.\' +
                                '[¹®ÀÇ] mir2master@wemade.com\' +
                                'ÇÁ·Î±×·¥À» Á¾·áÇÕ´Ï´Ù.', [mbOk]);
            FrmMain.Close;
         end;
      end else
         TimeFakeDetectSum := 0;
      LatestClientTimerTime := timertime;
      LatestClientGetTime := tcount;
   end;
   busy := FALSE;
end;
//**)

procedure TFrmMain.ClientGetDealRemoteAddItem(body: string);
var
  ci: TClientItem;
begin
  if body <> '' then begin
    DecodeBuffer(body, @ci, sizeof(TClientItem));
    AddDealRemoteItem(ci);
  end;
end;

procedure TFrmMain.ClientGetDealRemoteDelItem(body: string);
var
  ci: TClientItem;
begin
  if body <> '' then begin
    DecodeBuffer(body, @ci, sizeof(TClientItem));
    DelDealRemoteItem(ci);
  end;
end;

procedure TFrmMain.ClientGetReadMiniMap(mapindex: integer);
begin
  if mapindex >= 1 then begin
    BoDrawMiniMap := True;
{      if BoWantMiniMap then begin
         if PrevVMMStyle < 1 then PrevVMMStyle := 1;
         ViewMiniMapStyle := PrevVMMStyle;
      end;}
    MiniMapIndex := mapindex - 1;
    FrmDlg.DMiniMapDlg.Visible := True;
  end;
end;

procedure TFrmMain.ClientGetChangeGuildName(body: string);
var
  str: string;
begin
  str := GetValidStr3(body, GuildName, ['/']);
  GuildRankName := Trim(str);
end;

procedure TFrmMain.ClientGetSendUserState(body: string);
var
  ustate: TUserStateInfo;
begin
  DecodeBuffer(body, @ustate, sizeof(TUserStateInfo));
  ustate.NameColor := GetRGB(ustate.NameColor);
  FrmDlg.OpenUserState(ustate);
end;

procedure TFrmMain.SendTimeTimerTimer(Sender: TObject);
var
  tcount: longword;
begin
//   tcount := GetTickCount;
//   SendClientMessage (CM_CLIENT_CHECKTIME, tcount, Loword(LatestClientGetTime), Hiword(LatestClientGetTime), 0);
//   LastestClientGetTime := tcount;
end;

function TFrmMain.IsMyMember(name: string): Boolean;
var
  i: integer;
begin
  Result := false;
   // Ä£±¸¿¡¼­ °Ë»ö
  for i := FriendMembers.Count - 1 downto 0 do begin
    if PTFriend(FriendMembers[i]).CharID = name then begin
      Result := true;
      Exit;
    end;
  end;

   // Black List¿¡¼­ °Ë»ö
  for i := BlackMembers.Count - 1 downto 0 do begin
    if PTFriend(BlackMembers[i]).CharID = name then begin
      Result := True;
      Exit;
    end;
  end;
end;


// 2003/04/15 Ä£±¸, ÂÊÁö
procedure TFrmMain.ClientGetDelFriend(msg: TDefaultMessage; body: string);
var
  i: integer;
  str: string;
  keep: boolean;
begin
  str := DecodeString(body);
  keep := TRUE;
   // Ä£±¸¿¡¼­ °Ë»ö
  for i := FriendMembers.Count - 1 downto 0 do begin
    if PTFriend(FriendMembers[i]).CharID = str then begin
      Dispose(PTFriend(FriendMembers[i]));
      FriendMembers.Delete(i);
      keep := FALSE;
      break;
    end;
  end;

   // Ä£±¸¿¡¼­ °Ë»ö
   // Black List¿¡¼­ °Ë»ö
  for i := BlackMembers.Count - 1 downto 0 do begin
    if PTFriend(BlackMembers[i]).CharID = str then begin
      Dispose(PTFriend(BlackMembers[i]));
      BlackMembers.Delete(i);
      keep := False;
      Break;
    end;
  end;


   // Block List¿¡¼­ °Ë»ö
  if keep then begin
    for i := BlockLists.Count - 1 downto 0 do begin
      if BlockLists[i] = str then begin
        BlockLists.Delete(i);
        keep := False;
        Break;
      end;
    end;
  end;
  RecalcOnlinUserCount;
end;

procedure TFrmMain.RecalcOnlinUserCount;
var
  i: integer;
begin
  ConnectFriend := 0;
  for i := 0 to FriendMembers.Count - 1 do begin
    if PTFriend(FriendMembers[i]).Status >= 4 then
      inc(ConnectFriend);
  end;

  ConnectBlack := 0;
  for i := 0 to BlackMembers.Count - 1 do begin
    if PTFriend(BlackMembers[i]).Status >= 4 then
      inc(ConnectBlack);
  end;
end;

procedure TFrmMain.ClientGetUserInfo(msg: TDefaultMessage; body: string);
var
  i, j: integer;
  str, fname, fmapinfo: string;
  fstatus: integer;
  keep: boolean;
  fr: PTFriend;
begin
//   DScreen.AddSysMsg('SM_USER_INFO(BODY):'+body);
  str := DecodeString(body);
//   DScreen.AddSysMsg('SM_USER_INFO:'+str);

  fstatus := msg.param;
  fmapinfo := GetValidStr3(str, fname, ['/']);

   // Ä£±¸¿¡¼­ °Ë»ç
  for i := FriendMembers.Count - 1 downto 0 do begin
    if PTFriend(FriendMembers[i]).CharID = fname then begin
      PTFriend(FriendMembers[i]).Status := fstatus;
      Break;
    end;
  end;

   // ¾Ç¿¬¿¡¼­ °Ë»ç
  for i := BlackMembers.Count - 1 downto 0 do begin
    if PTFriend(BlackMembers[i]).CharID = fname then begin
      PTFriend(BlackMembers[i]).Status := fstatus;
      Break;
    end;
  end;
  RecalcOnlinUserCount;
end;

procedure TFrmMain.ClientFriendSort(var datalist: TList; firstname: string);
var
  i, j: integer;
  firstpt, temppt: pointer;
begin
    // 2°³ÀÌ»óÀÌ µÇ¾ß ¼ÒÆ®°¡ µÈ´Ù.
  if (datalist = nil) or (datalist.count < 2) then Exit;

  firstpt := nil;

    // Ã³À½À¸·Î ³Ö¾î¾ß µÇ´Â°ÍÀ» –A´Ù.
  if (firstname <> '') then begin
    for i := 0 to datalist.count - 1 do begin
      if (PTFriend(datalist[i]).CharID = firstname) then begin
        firstpt := datalist[i];
        datalist.Delete(i);
        Break;
      end;
    end;
  end;

    // °³¼ö°¡ 2º¸´Ù Å¬°æ¿ì¿¡
  if datalist.count >= 2 then begin
    for i := 0 to datalist.count - 2 do begin
      for j := i + 1 to datalist.count - 1 do begin
        if PTFriend(datalist[i]).CharID > PTFriend(datalist[j]).CharID then begin
          temppt := datalist[i];
          datalist[i] := datalist[j];
          datalist[j] := temppt;
        end;
      end;
    end;
  end;

    // Ã³À½¿¡´Ù ³Ö¾îÁØ´Ù.
  if firstpt <> nil then begin
    datalist.Insert(0, firstpt);
  end;
end;

procedure TFrmMain.ClientGetFriendInfo(msg: TDefaultMessage; body: string);
var
  i, j: integer;
  str, fname, fmemo: string;
  ftype, fstatus: integer;
  keep: boolean;
  fr: PTFriend;
begin
//   DScreen.AddSysMsg('SM_FRIEND_INFO(BODY):'+body);
  str := DecodeString(body);
//   DScreen.AddSysMsg('SM_FRIEND_INFO:'+str);

   //str := GetValidStr3 (str, ftype, [' ']);
   //str := GetValidStr3 (str, fstatus, [' ']);
  ftype := msg.param;
  fstatus := msg.tag;
  fmemo := GetValidStr3(str, fname, ['/']);

  i := ftype;
  case i of
    RT_FRIENDS:
      begin
        keep := TRUE;
            // Ä£±¸¿¡¼­ °Ë»ö
        for i := FriendMembers.Count - 1 downto 0 do begin
          if PTFriend(FriendMembers[i]).CharID = fname then begin
            PTFriend(FriendMembers[i]).Status := fstatus;
            PTFriend(FriendMembers[i]).Memo := fmemo;
            keep := FALSE;
            break;
          end;
        end;
        if keep then begin
          new(fr);
          fr.CharID := fname;
          fr.Status := fstatus;
          fr.Memo := fmemo;
          FriendMembers.Add(fr);
        end;

        ClientFriendSort(FriendMembers, flover.GetName(RsState_Lover));
      end;
    RT_BLACKLIST:
      begin
        keep := TRUE;
            // Ä£±¸¿¡¼­ °Ë»ö
        for i := BlackMembers.Count - 1 downto 0 do begin
          if PTFriend(BlackMembers[i]).CharID = fname then begin
            PTFriend(BlackMembers[i]).Status := fstatus;
            PTFriend(BlackMembers[i]).Memo := fmemo;
            keep := FALSE;
            break;
          end;
        end;
        if keep then begin
          new(fr);
          fr.CharID := fname;
          fr.Status := fstatus;
          fr.Memo := fmemo;
          BlackMembers.Add(fr);
        end;

        ClientFriendSort(BlackMembers, '');
      end;
    RT_LOVERS:
      begin
      end;
    RT_MASTER:
      begin
      end;
    RT_DISCIPLE:
      begin
      end;
  end;
  RecalcOnlinUserCount
end;

procedure TFrmMain.ClientGetFriendResult(msg: TDefaultMessage; body: string);
var
  i: integer;
  str, fcmd, ferr, fname: string;
  keep: boolean;
  fr: PTFriend;
begin
  str := DecodeString(body);
  ferr := GetValidStr3(str, fcmd, [' ']);
  i := StrToInt(ferr);
  case i of
    CR_FAIL:
      DScreen.AddChatBoardString('¿äÃ»ÇÏ½Å ÀÛ¾÷ÀÌ ½ÇÆÐÇÏ¿´½À´Ï´Ù', clWhite, clRed);
    CR_DONTFINDUSER:
      DScreen.AddChatBoardString('ÇØ´ç ÄÉ¸¯À» Ã£À»¼ö ¾ø½À´Ï´Ù', clWhite, clRed);
    CR_DONTADD:
      DScreen.AddChatBoardString('Ä£±¸µî·ÏÀÌ ½ÇÆÐÇß½À´Ï´Ù', clWhite, clRed);
    CR_DONTDELETE:
      DScreen.AddChatBoardString('Ä£±¸»èÁ¦°¡ ½ÇÆÐÇß½À´Ï´Ù', clWhite, clRed);
    CR_DONTUPDATE:
      DScreen.AddChatBoardString('Ä£±¸¼öÁ¤ÀÌ ½ÇÆÐÇß½À´Ï´Ù', clWhite, clRed);
    CR_DONTACCESS:
      DScreen.AddChatBoardString('Ä£±¸Á¤º¸¿¡ Á¢±Ù ÇÒ ¼ö ¾ø½À´Ï´Ù', clWhite, clRed);
    CR_LISTISMAX:
      DScreen.AddChatBoardString('ÃÖ´ëÇã¿ëÀÎ¿øÀ» ÃÊ°úÇß½À´Ï´Ù', clWhite, clRed);
    CR_LISTISMIN:
      DScreen.AddChatBoardString('ÃÖ¼ÒÇã¿ëÀÎ¿ø¿¡ µµ´ÞÇß½À´Ï´Ù', clWhite, clRed);
  end;
end;

procedure TFrmMain.ClientGetTagAlarm(msg: TDefaultMessage; body: string);
var
  notreadcount: integer;
begin
//     DScreen.AddSysMsg('SM_TAG_ARLARM:');
  notreadcount := msg.Param;
  if (notreadcount > 0) then begin
    DScreen.AddChatBoardString('ÂÊÁö°¡ ¿Ô½À´Ï´Ù.', clWhite, clRed);
    MailAlarm := true;
  end;
end;

procedure TFrmMain.RecalcNotReadCount;
var
  i: integer;
begin
     // ÀÐÁö ¾ÊÀº°³¼ö¸¦ °»½ÅÇÑ´Ù.
  NotReadMailCount := 0;
  for i := 0 to MailLists.Count - 1 do begin
    if (pTMail(MailLists[i]).Status = 0) then
      inc(NotReadMailCount);
  end;
end;

procedure TFrmMain.ClientGetTagList(msg: TDefaultMessage; body: string);
var
  i: integer;
  str: string;
  MailStr: string;
  StateStr: string;
  DateStr: string;
  SenderStr: string;
  TotalCount: integer;
  PageCount: integer;
  pMail: pTMail;
begin
  str := DecodeString(body);
//   DScreen.AddSysMsg('SM_TAG_LIST:'+str);
  PageCount := msg.Param;
  TotalCount := msg.Tag;

  pMail := nil;
  for i := 0 to TotalCount - 1 do begin
    str := GetValidStr3(str, MailStr, ['/']);
    MailStr := GetValidStr3(MailStr, StateStr, [':']);
    MailStr := GetValidStr3(MailStr, DateStr, [':']);
    MailStr := GetValidStr3(MailStr, SenderStr, [':']);

    New(pMail);
    pMail^.Sender := SenderStr;
    pMail^.Date := DateStr;
    pMail^.Mail := MailStr;
    pMail^.Status := Str_ToInt(StateStr, 0);

    MailLists.Insert(0, pMail);
  end;
  RecalcNotReadCount;
end;

procedure TFrmMain.ClientGetTagInfo(msg: TDefaultMessage; body: string);
var
  str: string;
  i: integer;
  Status: integer;
begin
  str := DecodeString(body);
  Status := msg.Param;
//   DScreen.AddSysMsg('SM_TAG_INFO:'+str + IntToStr(Status));
  for i := 0 to MailLists.Count - 1 do begin
    if pTMail(MailLists[i]).Date = str then begin
         // »èÁ¦ÀÎ°æ¿ì¿¡´Â »èÁ¦ÇÏÀÚ
      if Status = 3 then begin
        dispose(MailLists[i]);
        MailLists.Delete(i);
      end
      else
        pTMail(MailLists[i]).Status := Status;

      break;
    end;
  end;
  RecalcNotReadCount;
end;

procedure TFrmMain.ClientGetTagRejectList(msg: TDefaultMessage; body: string);
var
  i: integer;
  str: string;
  RejectStr: string;
  RejectCount: Integer;
begin
  str := DecodeString(body);
//   DScreen.AddSysMsg('SM_TAG_REJECT_LIST:'+str);

  RejectCount := msg.Param;
  for i := 0 to RejectCount - 1 do begin
    str := GetValidStr3(str, RejectStr, ['/']);
    BlockLists.Add(RejectStr);
  end;
end;

procedure TFrmMain.ClientGetTagRejectAdd(msg: TDefaultMessage; body: string);
var
  str: string;
begin
  str := DecodeString(body);
//   DScreen.AddSysMsg('SM_TAG_REJECT_ADD:'+str);
  BlockLists.Add(str);
end;

procedure TFrmMain.ClientGetTagRejectDelete(msg: TDefaultMessage; body: string);
var
  str: string;
  i: integer;
begin
  str := DecodeString(body);
//   DScreen.AddSysMsg('SM_TAG_REJECT_DELETE:'+str);

  for i := 0 to BlockLists.Count - 1 do begin
    if (BlockLists[i] = str) then begin
      BlockLists.Delete(i);
      break;
    end;
  end
end;

procedure TFrmMain.ClientGetTagResult(msg: TDefaultMessage; body: string);
begin

end;

procedure TFrmMain.ClientGetLMList(msg: TDefaultMessage; body: string);
var
  _state: integer;
  _level: integer;
  _Sex: integer;
  _Date: string;
  _ServerDate: string;
  _Name: string;
  _MapInfo: string;
  count, i: integer;
  str: string;
  infostr: string;
  temp: string;
begin
  str := DecodeString(body);
  count := msg.Param;

//     DScreen.AddSysmsg ('SM_LM_LIST:'+intToStr(count)+','+str);
  for i := 0 to count - 1 do begin
    str := GetValidStr3(str, infostr, ['/']);
    if infostr <> '' then begin
      infostr := GetValidStr3(infostr, temp, [':']);
      _state := Str_ToInt(temp, 0);
      infostr := GetValidStr3(infostr, _Name, [':']);
      infostr := GetValidStr3(infostr, temp, [':']);
      _level := Str_ToInt(temp, 1);
      infostr := GetValidStr3(infostr, temp, [':']);
      _Sex := Str_ToInt(temp, 0);
      infostr := GetValidStr3(infostr, _Date, [':']);
      infostr := GetValidStr3(infostr, _ServerDate, [':']);
      infostr := GetValidStr3(infostr, _MapInfo, [':']);

      fLover.Add(MySelf.UserName, _Name, _state, _level, _Sex, _Date,
        _ServerDate, _MapInfo);

      ClientFriendSort(FriendMembers, fLover.GetName(RsState_Lover));
//            if _MapInfo <> '' then
//            begin
//                DScreen.AddChatBoardString (_Name+'´ÔÀÌ '+_MapInfo+'¿¡ °è½Ê´Ï´Ù.', clWhite, clGreen);
//            end;
    end;
  end;
end;

procedure TFrmMain.ClientGetLMOptionChange(msg: TDefaultMessage);
var
  optiontype, enable: integer;
begin
  optiontype := msg.Param;
  enable := msg.Tag;
  case optiontype of
    1:
      begin
        fLover.SetEnable(rsState_Lover, enable);
        if enable = 1 then
          DScreen.AddChatBoardString('±³Á¦°¡ °¡´ÉÇÕ´Ï´Ù.', clRed, clWhite)
        else
          DScreen.AddChatBoardString('±³Á¦¸¦ ÇÏÁö ¾Ê½À´Ï´Ù.', clRed, clWhite);
      end;
  end;
     // DScreen.AddSysmsg ('SM_LM_OPTION:'+IntToStr( optiontype) + ','+ IntToStr( enable));

end;

procedure TFrmMain.ClientGetLMRequest(msg: TDefaultMessage; body: string);
var
  str: string;
  ReqType: integer;
  ReqSeq: integer;
begin
  str := DecodeString(body);
  ReqType := msg.Param;
  ReqSeq := msg.Tag;

  case ReqType of
    RsState_Lover:
      begin
        case ReqSeq of
          RsReq_WhoWantJoin:
            begin
              if mrYes = FrmDlg.DMessageDlg(str + '´ÔÀÌ ±³Á¦¸¦ ½ÅÃ»ÇÏ¿´½À´Ï´Ù.\±³Á¦¼º¸³ÈÄ ±³Á¦¸¦ Áß´ÜÇÒ °æ¿ì À§¾à±ÝÀ¸·Î 10¸¸ÀüÀÌ ÀÚµ¿ÁöºÒµË´Ï´Ù.\±³Á¦ÇÏ½Ã°Ú½À´Ï±î?',
                [mbYes, mbNo]) then
                SendLMRequest(ReqType, RsReq_AloowJoin)
              else
                SendLMRequest(ReqType, RsReq_DenyJoin);

            end;
        end;
      end;
  end;
//   DScreen.AddSysmsg ('SM_LM_REQUEST:'+IntToStr( msg.param) + ','+IntToStr( msg.Tag) + ','+ str);
end;

procedure TFrmMain.ClientGetLMResult(msg: TDefaultMessage; body: string);
var
  str: string;
  reqtype: integer;
  errcode: integer;
begin
  str := DecodeString(body);
  reqtype := msg.Param;
  errcode := msg.Tag;

  case reqtype of
    RsState_Lover:
      begin
        case errcode of
          RsError_SuccessJoin: //= 1;         // Âü°¡¿¡ ¼º°øÇÏ¿´´Ù ( Âü°¡ÇÑ»ç¶÷ÂÊ)
            begin
//                FrmDlg.DMessageDlg (str+'´Ô°ú ¿¬ÀÎÀÌ µÇ¾ú½À´Ï´Ù.', [mbYes]);
              FrmDlg.AddFriend(str, false);
              PlaySound(154);
            end;
          RsError_SuccessJoined: //= 2;         // Âü°¡¿¡ ¼º°øµÇ¾îÁ³´Ù ( Âü°¡µÈ »ç¶÷ÂÊ)
            begin
//                FrmDlg.DMessageDlg (str+'´ÔÀÌ ±³Á¦¸¦ Çã¶ôÇÏ¿© ¿¬ÀÎÀÌ µÇ¾ú½À´Ï´Ù.', [mbYes]);
              FrmDlg.AddFriend(str, false);
              PlaySound(154);
            end;
          RsError_DontJoin: //= 3;         // Âü°¡ÇÒ ¼ö ¾ø´Ù
//            FrmDlg.JustMessageDlg (str+'´Ô°ú´Â ±³Á¦¸¦ ÇÒ ¼ö ¾ø½À´Ï´Ù.', [mbOK]);
            FrmDlg.DMessageDlg(str + '´ÔÀÌ ±³Á¦ ½Â³« ¿©ºÎ¸¦ °áÁ¤ÁßÀÔ´Ï´Ù.', [mbOK]);
          RsError_DontLeave: //= 4;         // ¶°³¯¼ö ¾ø´Ù.
            FrmDlg.DMessageDlg(str + '´Ô°ú ±³Á¦¸¦ Áß´ÜÇÒ ¼ö ¾ø½À´Ï´Ù.', [mbOK]);
          RsError_RejectMe: //= 5;         // °ÅºÎ»óÅÂÀÌ´Ù
            FrmDlg.DMessageDlg('´ç½ÅÀº ÇöÀç ±³Á¦»óÅÂ°¡ ¾Æ´Õ´Ï´Ù. \±³Á¦°¡´É»óÅÂ·Î ÀüÈ¯ÇÏ±â À§ÇØ¼­´Â ±³Á¦¼±ÅÃ ¹öÆ°À» Å¬¸¯ÇÏ¿© ÁÖ½Ê½Ã¿À.',
              [mbOK]);
          RsError_RejectOther: //= 6;         // °ÅºÎ»óÅÂÀÌ´Ù
            FrmDlg.DMessageDlg(str + '´ÔÀº ±³Á¦°¡´É »óÅÂ°¡ ¾Æ´Õ´Ï´Ù.', [mbOK]);
          RsError_LessLevelMe: //= 7;         // ³ªÀÇ·¹º§ÀÌ ³·´Ù
            FrmDlg.DMessageDlg('·¹º§ÀÌ 22 ÀÌ»óÀÏ¶§¸¸ ±³Á¦½ÅÃ»À» ÇÒ ¼ö ÀÖ½À´Ï´Ù.', [mbOK]);
          RsError_LessLevelOther: //= 8;         // »ó´ë¹æÀÇ·¹º§ÀÌ ³·´Ù
            FrmDlg.DMessageDlg(str + '´ÔÀÇ ·¹º§ÀÌ 22°¡ µÇ¾î¾ß ±³Á¦¸¦ ÇÒ ¼ö ÀÖ½À´Ï´Ù.', [mbOK]);
          RsError_EqualSex: //= 9;         // ¼ºº°ÀÌ °°´Ù
            FrmDlg.DMessageDlg('µ¿ÀÏÇÑ ¼ºº°³¢¸®´Â ±³Á¦¸¦ ÇÒ ¼ö ¾ø½À´Ï´Ù.', [mbOK]);
          RsError_FullUser: //= 10;        // Âü¿©ÀÎ¿øÀÌ °¡µæÃ¡´Ù
            FrmDlg.DMessageDlg(str + '´ÔÀº ÀÌ¹Ì ±³Á¦»óÅÂÀÔ´Ï´Ù. ´Ù¸¥ ±³Á¦¸¦ ÇÒ ¼ö ¾ø½À´Ï´Ù.', [mbOK]);
          RsError_CancelJoin: //= 11;        // Âü°¡Ãë¼Ò
            DScreen.AddChatBoardString('±³Á¦½ÅÃ»ÀÌ Ãë¼ÒµÇ¾ú½À´Ï´Ù.', clGreen, clWhite);
          RsError_DenyJoin: //= 12;        // Âü°¡¸¦ °ÅÀýÇÔ
            FrmDlg.DMessageDlg(str + '´ÔÀÌ ±³Á¦½ÅÃ»À» °ÅÀýÇÏ¼Ì½À´Ï´Ù.', [mbOK]);
          RsError_DontDelete: //= 13;        // Å»Åð½ÃÅ³¼ö ¾ø´Ù.
            FrmDlg.DMessageDlg(str + '´Ô°úÀÇ ±³Á¦¸¦ Áß´ÜÇÒ ¼ö ¾ø½À´Ï´Ù.', [mbOK]);
          RsError_SuccessDelete: //= 14;        // Å»Åð½ÃÄ×À½
            begin
              PlaySound(155);
              FrmDlg.DMessageDlg(str + '´Ô°úÀÇ ±³Á¦°¡ Áß´ÜµÇ¾ú½À´Ï´Ù.', [mbOK]);
            end;
          RsError_NotRelationShip: //= 15;        // ±³Á¦»óÅÂ°¡ ¾Æ´Ï´Ù.
            FrmDlg.DMessageDlg('´ç½ÅÀº ±³Á¦»óÅÂ°¡ ¾Æ´Õ´Ï´Ù.', [mbOK]);
        end;
      end;
  end;
     // DScreen.AddSysmsg ('SM_LM_RESULT:'+IntToStr( msg.param) + ','+IntToStr( msg.Tag) + ','+ str);
end;

procedure TFrmMain.ClientGetLMDelete(msg: TDefaultMessage; body: string);
var
  str: string;
  ReqType: integer;
begin
  str := DecodeString(body);
  ReqType := msg.Param;
  fLover.Delete(str);
end;

procedure TFrmMain.SendAddFriend(data: string; FriendType: integer);
var
  msg: TDefaultMessage;
begin
//   DScreen.AddSysMsg('CM_FRIEND_ADD:'+data);
   // TO DO , FRIEND = 1 (wparam ) , BLACKLIST = 8
  msg := MakeDefaultMsg(CM_FRIEND_ADD, 0, FriendType, 0, 0);
  SendSocket(EncodeMessage(msg) + EncodeString(data));
end;

procedure TFrmMain.SendAddReject(data: string);
var
  msg: TDefaultMessage;
begin
//   DScreen.AddSysMsg('CM_TAG_REJECT_ADD:'+data);
  msg := MakeDefaultMsg(CM_TAG_REJECT_ADD, 0, 0, 0, 0);
  SendSocket(EncodeMessage(msg) + EncodeString(data));
end;

procedure TFrmMain.SendDelReject(data: string);
var
  msg: TDefaultMessage;
begin
//   DScreen.AddSysMsg('CM_TAG_REJECT_DELETE:'+data);
  msg := MakeDefaultMsg(CM_TAG_REJECT_DELETE, 0, 0, 0, 0);
  SendSocket(EncodeMessage(msg) + EncodeString(data));
end;

procedure TFrmMain.SendLMOptionChange(OptionType: integer; Enable: integer);
var
  msg: TDefaultMessage;
begin
  msg := MakeDefaultMsg(CM_LM_OPTION, OptionType, Enable, 0, 0);
  SendSocket(EncodeMessage(msg));
end;

procedure TFrmMain.SendLMRequest(ReqType: integer; ReqSeq: integer);
var
  msg: TDefaultMessage;
begin
  msg := MakeDefaultMsg(CM_LM_REQUEST, ReqType, ReqSeq, 0, 0);
  SendSocket(EncodeMessage(msg));
end;

procedure TFrmMain.SendLMSeparate(ReqType: integer; data: string);
var
  msg: TDefaultMessage;
begin
  msg := MakeDefaultMsg(CM_LM_DELETE, ReqType, 0, 0, 0);
  SendSocket(EncodeMessage(msg) + EncodeString(data));
end;

procedure TFrmMain.SendDelFriend(data: string);
var
  msg: TDefaultMessage;
begin
//   DScreen.AddSysMsg('CM_FRIEND_DELETE:'+data);
  msg := MakeDefaultMsg(CM_FRIEND_DELETE, 0, 0, 0, 0);
  SendSocket(EncodeMessage(msg) + EncodeString(data));
end;

procedure TFrmMain.SendMail(data: string);
var
  msg: TDefaultMessage;
begin
  if frmDlg.BoMemoJangwon then begin
    msg := MakeDefaultMsg(CM_GUILDAGIT_TAG_ADD, 0, 0, 0, 0);
    frmDlg.BoMemoJangwon := False;
  end else
    msg := MakeDefaultMsg(CM_TAG_ADD, 0, 0, 0, 0);
  SendSocket(EncodeMessage(msg) + EncodeString(data));
end;

procedure TFrmMain.SendReadingMail(data: string);
var
  msg: TDefaultMessage;
begin
  msg := MakeDefaultMsg(CM_TAG_SETINFO, 0, 1, 0, 0);
  SendSocket(EncodeMessage(msg) + EncodeString(data));
end;

procedure TFrmMain.SendDelMail(data: string);
var
  msg: TDefaultMessage;
begin
  msg := MakeDefaultMsg(CM_TAG_DELETE, 0, 0, 0, 0);
  SendSocket(EncodeMessage(msg) + EncodeString(data));
end;

procedure TFrmMain.SendLockMail(data: string);
var
  msg: TDefaultMessage;
begin
  msg := MakeDefaultMsg(CM_TAG_SETINFO, 0, 2, 0, 0);
  SendSocket(EncodeMessage(msg) + EncodeString(data));
end;

procedure TFrmMain.SendUnLockMail(data: string);
var
  msg: TDefaultMessage;
begin
  msg := MakeDefaultMsg(CM_TAG_SETINFO, 0, 3, 0, 0);
  SendSocket(EncodeMessage(msg) + EncodeString(data));
end;

procedure TFrmMain.SendMailList;
var
  msg: TDefaultMessage;
begin
  msg := MakeDefaultMsg(CM_TAG_LIST, 0, 0, 0, 0);
  SendSocket(EncodeMessage(msg));
end;

procedure TFrmMain.SendRejectList;
var
  msg: TDefaultMessage;
begin
  msg := MakeDefaultMsg(CM_TAG_REJECT_LIST, 0, 0, 0, 0);
  SendSocket(EncodeMessage(msg));
end;

procedure TFrmMain.SendUpdateFriend(data: string);
var
  msg: TDefaultMessage;
begin
  msg := MakeDefaultMsg(CM_FRIEND_EDIT, 0, 0, 0, 0);
  SendSocket(EncodeMessage(msg) + EncodeString(data));
end;

procedure TFrmMain.DelitemProg;
begin
  DelItemBag(DelTempItem.S.Name, DelTempItem.MakeIndex);
end;

procedure TFrmMain.RunEffectTimerTimer(Sender: TObject);
var
  tx, ty, n, kx, ky, i: integer;
  bofly: Boolean;
begin

  tx := Myself.XX;
  ty := Myself.YY;

  Randomize;
  RunEffectTimer.Tag := RunEffectTimer.Tag + 1;
  n := random(4);
  kx := random(5) + 1;
  ky := random(4) + 1;
  if RunEffectTimer.Tag > 1000000 then
    RunEffectTimer.Tag := 1000;

  if EffectNum = 1 then begin
    case random(5) of
      0:
        RunEffectTimer.Interval := 400;
      1:
        RunEffectTimer.Interval := 600;
      2:
        RunEffectTimer.Interval := 800;
      3:
        RunEffectTimer.Interval := 1000;
      4:
        RunEffectTimer.Interval := 1500;
    end;

    case n of
      0:
        if Map.CanMove(tx + kx, ty - ky) then
          PlayScene.NewMagic(nil, MAGIC_DUN_THUNDER, MAGIC_DUN_THUNDER, tx + kx,
            ty - ky, tx + kx, ty - ky, 0, mtThunder, False, 30, bofly);
      1:
        if Map.CanMove(tx - kx, ty + ky) then
          PlayScene.NewMagic(nil, MAGIC_DUN_THUNDER, MAGIC_DUN_THUNDER, tx - kx,
            ty + ky, tx - kx, ty + ky, 0, mtThunder, False, 30, bofly);
      2:
        if Map.CanMove(tx - kx, ty - ky) then
          PlayScene.NewMagic(nil, MAGIC_DUN_THUNDER, MAGIC_DUN_THUNDER, tx - kx,
            ty - ky, tx - kx, ty - ky, 0, mtThunder, False, 30, bofly);
      3:
        if Map.CanMove(tx + kx, ty + ky) then
          PlayScene.NewMagic(nil, MAGIC_DUN_THUNDER, MAGIC_DUN_THUNDER, tx + kx,
            ty + ky, tx + kx, ty + ky, 0, mtThunder, False, 30, bofly);
    end;
    PlaySound(8301);

  end
  else if EffectNum = 2 then begin
    case Random(RunEffectTimer.Tag) mod 5 of
      0:
        RunEffectTimer.Interval := 1000;
      1:
        RunEffectTimer.Interval := 1500;
      2:
        RunEffectTimer.Interval := 2000;
      3:
        RunEffectTimer.Interval := 2500;
      4:
        RunEffectTimer.Interval := 3000;
    end;

    case n of
      0:
        if Map.CanMove(tx + kx, ty - ky) then begin
          PlayScene.NewMagic(nil, MAGIC_DUN_FIRE1, MAGIC_DUN_FIRE1, tx + kx, ty
            - ky, tx + kx, ty - ky, 0, mtThunder, False, 30, bofly);
          PlayScene.NewMagic(nil, MAGIC_DUN_FIRE2, MAGIC_DUN_FIRE2, tx + kx, ty
            - ky, tx + kx, ty - ky, 0, mtThunder, False, 30, bofly);
        end;
      1:
        if Map.CanMove(tx - kx, ty + ky) then begin
          PlayScene.NewMagic(nil, MAGIC_DUN_FIRE1, MAGIC_DUN_FIRE1, tx - kx, ty
            + ky, tx - kx, ty + ky, 0, mtThunder, False, 30, bofly);
          PlayScene.NewMagic(nil, MAGIC_DUN_FIRE2, MAGIC_DUN_FIRE2, tx - kx, ty
            + ky, tx - kx, ty + ky, 0, mtThunder, False, 30, bofly);
        end;
      2:
        if Map.CanMove(tx - kx, ty - ky) then begin
          PlayScene.NewMagic(nil, MAGIC_DUN_FIRE1, MAGIC_DUN_FIRE1, tx - kx, ty
            - ky, tx - kx, ty - ky, 0, mtThunder, False, 30, bofly);
          PlayScene.NewMagic(nil, MAGIC_DUN_FIRE2, MAGIC_DUN_FIRE2, tx - kx, ty
            - ky, tx - kx, ty - ky, 0, mtThunder, False, 30, bofly);
        end;
      3:
        if Map.CanMove(tx + kx, ty + ky) then begin
          PlayScene.NewMagic(nil, MAGIC_DUN_FIRE1, MAGIC_DUN_FIRE1, tx + kx, ty
            + ky, tx + kx, ty + ky, 0, mtThunder, False, 30, bofly);
          PlayScene.NewMagic(nil, MAGIC_DUN_FIRE2, MAGIC_DUN_FIRE2, tx + kx, ty
            + ky, tx + kx, ty + ky, 0, mtThunder, False, 30, bofly);
        end;
    end;
    PlaySound(8302);
  end;
end;

procedure TFrmMain.MainCancelItemMoving;
begin
  FrmDlg.CancelItemMoving;
end;

procedure TFrmMain.FormKeyUp(Sender: TObject; var Key: Word; Shift: TShiftState);
begin
  case Key of
    VK_TAB:
      begin
        SendPickup;
        TabClickTime := GetTickCount;
      end;
  end;
  if g_DWinMan.KeyUp(Key, Shift) then Exit;
end;

{--------------------- Mouse Interface ----------------------}
procedure TFrmMain.FormMouseDown(Sender: TObject; Button: TMouseButton; Shift: TShiftState; X, Y: Integer);
begin
  mousedowntime := GetTickCount;
  RunReadyCount := 0;     //µµ¿ò´Ý±â Ãë¼Ò(¶Ù±â ÀÎ°æ¿ì)
  _FormMouseDown(Sender, Button, Shift, X, Y);
end;

procedure TFrmMain.FormMouseMove(Sender: TObject; Shift: TShiftState; X, Y: Integer);
var
  i, mx, my, msx, msy, sel: integer;
  target: TActor;
  itemnames: string;
begin
  if g_DWinMan.MouseMove(Shift, X, Y) then Exit;
  if (MySelf = nil) or (DScreen.CurrentScene <> PlayScene) then Exit;
  BoSelectMyself := PlayScene.IsSelectMyself(X, Y);

  target := PlayScene.GetAttackFocusCharacter(X, Y, DupSelection, sel, False);
  if DupSelection <> sel then DupSelection := 0;
  if target <> nil then begin
    if (target.UserName = '') and (GetTickCount - target.SendQueryUserNameTime > 10 * 1000) then begin
      target.SendQueryUserNameTime := GetTickCount;
      SendQueryUserName(target.RecogId, target.XX, target.YY);
    end;
    FocusCret := target;
  end else
    FocusCret := nil;

  FocusItem := PlayScene.GetDropItems(X, Y, itemnames);
  if FocusItem <> nil then begin
    PlayScene.ScreenXYfromMCXY (FocusItem.X, FocusItem.Y, mx, my);
//      DScreen.AddChatBoardString ('Pos=> '+ IntToStr(((Length(FocusItem.Name) div 2)*6)), clYellow, clRed);
    DScreen.ShowHint (mx+2-((Length(FocusItem.Name) div 2)*6),
                      my-10,
                      itemnames, //PTDropItem(ilist[i]).Name,
                      $80FFFF,
                      TRUE, 1);
  end else
    DScreen.ClearHint;

  PlayScene.CXYfromMouseXY(X, Y, MCX, MCY);
  MouseX := X;
  MouseY := Y;
  MouseItem.S.Name := '';
  MouseStateItem.S.Name := '';
  MouseUserStateItem.S.Name := '';
//   if ((ssLeft in Shift) or (ssRight in Shift)) and (GetTickCount - mousedowntime > 300) then
  if ((ssLeft in Shift) or (ssRight in Shift) or gAutoRun) and (GetTickCount - mousedowntime > 300) then
    _FormMouseDown(self, mbLeft, Shift, X, Y);
end;

procedure TFrmMain.FormMouseUp(Sender: TObject; Button: TMouseButton; Shift: TShiftState; X, Y: Integer);
begin
  if g_DWinMan.MouseUp(Button, Shift, X, Y) then exit;
  targetx := -1;
end;

procedure TFrmMain.FormMouseWheel(Sender: TObject; Shift: TShiftState;
  WheelDelta: Integer; MousePos: TPoint; var Handled: Boolean);
begin
  if WheelDelta > 0 then begin
    if FrmDlg.DMagicWnd.Visible then begin
      if FrmDlg.m_nStartPos > 0 then Dec (FrmDlg.m_nStartPos, 10);
      if FrmDlg.m_nStartPos <= 0 then FrmDlg.m_nStartPos := 0;
      FrmDlg.DMagicWndScrollBar.Top:= 112 + Trunc(238 * FrmDlg.m_nStartPos / 201);
    end;
  end else begin
    if FrmDlg.DMagicWnd.Visible then begin
      if FrmDlg.m_nStartPos < 201 then Inc (FrmDlg.m_nStartPos, 10);
      if FrmDlg.m_nStartPos >= 201 then FrmDlg.m_nStartPos := 201;
      FrmDlg.DMagicWndScrollBar.Top:= 112 + Trunc(238 * FrmDlg.m_nStartPos / 201);
    end;
  end;
end;

procedure TFrmMain.FormShow(Sender: TObject);
begin
//  ShowWindow(Application.Handle, SW_HIDE);
end;

procedure TfrmMain.DeviceRender(Sender: TObject);
  procedure LogoInitialize(MinImage: Integer);
  var
    d: TDirectDrawSurface;
  begin
    if g_LogoSurface <> nil then begin
      if FnShowLogoIndex < 256 then begin
        g_DXCanvas.Draw((DEFScreenWidth - g_LogoSurface.Width) div 2,
          (DEFScreenHeight - g_LogoSurface.Height) div 2 - 20,
          g_LogoSurface.ClientRect, g_LogoSurface, True,
          cColor4($FFFFFF or (FnShowLogoIndex shl 24)));
      end else
      if FnShowLogoIndex < 400 then begin
        g_DXCanvas.Draw((DEFScreenWidth - g_LogoSurface.Width) div 2,
          (DEFScreenHeight - g_LogoSurface.Height) div 2 - 20,
          g_LogoSurface.ClientRect, g_LogoSurface, True);
      end else
      if FnShowLogoIndex < 626 then begin
        d := g_WProgUse.Images[MinImage];
        if d <> nil then
          g_DXCanvas.Draw(0, 0, d.ClientRect, d, True, cColor4($FFFFFF or ((FnShowLogoIndex - 400) shl 24)));

        g_DXCanvas.Draw((DEFScreenWidth - g_LogoSurface.Width) div 2,
          (DEFScreenHeight - g_LogoSurface.Height) div 2 - 20,
          g_LogoSurface.ClientRect, g_LogoSurface, True,
          cColor4($FFFFFF or ((655 - FnShowLogoIndex) shl 24)));
      end else begin
        d := g_WProgUse.Images[MinImage];
        if d <> nil then
          g_DXCanvas.Draw(0, 0, d.ClientRect, d, True);
        FBoShowLogo := True;

        //FnShowLogoIndex := 0;
      end;
    end else FBoShowLogo := True;
  end;
var
  d : TDirectDrawSurface;
  p: TPoint;
begin
  if not FBoShowLogo then begin
    LogoInitialize(LOGINBAGIMGINDEX);
  end else
  if not g_boInitialize then begin
    ProcessFreeTexture;
    ProcessKeyMessages;
    ProcessActionMessages;

    if DScreen.CurrentScene = PlayScene then begin
      d := g_WProgUse.Images[570];
      if d <> nil then
        g_DXCanvas.Draw(SOFFX, SOFFY, d.ClientRect, d, True);
      g_DXCanvas.Draw(SOFFX, SOFFY, PlayScene.MagSurface.ClientRect, PlayScene.MagSurface, true);
    end;
    DScreen.DrawScreen (g_DXCanvas.DrawTexture);

    if DropItemView then begin
      if TabClickTime + 3000 > GetTickCount then begin
        PlayScene.DropItemsShow(g_DXCanvas.DrawTexture); //@@@@
      end;
    end;

    if g_boCanDraw then begin
      g_DWinMan.DirectPaint (g_DXCanvas.DrawTexture);
      DScreen.DrawScreenTop (g_DXCanvas.DrawTexture);
      DScreen.DrawHint (g_DXCanvas.DrawTexture);

      if ItemMoving then begin
        if (MovingItem.Item.S.Name <> '½ð±Ò') then
           d := g_WInventory.Images[MovingItem.Item.S.Looks]
        else d := g_WInventory.Images[123]; //µ· ¸ð¾ç
        if d <> nil then begin
          GetCursorPos (p);
          p.X := p.X - m_Point.X;
          p.Y := p.Y - m_Point.Y;
          g_DXCanvas.Draw(p.x - (d.ClientRect.Right div 2), p.y - (d.ClientRect.Bottom div 2), d.ClientRect, d, TRUE);

          if (MovingItem.Item.S.OverlapItem > 0) and (MovingItem.Item.S.Name <> '½ð±Ò') then begin
            g_DXCanvas.TextOut(p.x + 9, p.y + 3, clYellow, IntToStr(MovingItem.Item.Dura));
          end;
        end;
      end;
      if DoFadeOut then begin
        if FadeIndex > 255 then
          FadeIndex := 255;
        MakeDark (FadeIndex);
        if FadeIndex >= 255 then
          DoFadeOut := FALSE
        else
          Inc(FadeIndex, 5);
      end
      else if DoFadeIn then begin
        if FadeIndex < 0 then
          FadeIndex := 0;
        MakeDark (FadeIndex);
        if FadeIndex <= 0 then
          DoFadeIn := FALSE
        else
          Dec(FadeIndex, 10);
      end
      else if DoFastFadeOut then begin
        if FadeIndex > 255 then
          FadeIndex := 255;
//        MakeDark (FadeIndex);
        if FadeIndex < 255 then
          Inc(FadeIndex, 40);
      end;
    end;
  end;
end;

procedure TFrmMain.DisplayChange(boReset: Boolean);
var
  nWidth, nHeight: Integer;
begin
  if boReset then begin
    if FboDisplayChange then begin
      FormStyle := fsNormal;
      FIDDraw := nil;
      if FDDrawHandle > 0 then
        FreeLibrary(FDDrawHandle);
      FDDrawHandle := 0;
      FboDisplayChange := False;
      UnRegisterHotKey(Handle, FHotKeyId);
    end;
  end else begin
    if not FboDisplayChange then begin
      FormStyle := fsStayOnTop;
      if HGE.System_GetState(HGE_FScreenWidth) = DEFSCREENWIDTH then begin
        nWidth := DEFSCREENWIDTH;
        nHeight := DEFSCREENHEIGHT;
      end
      else begin
        nWidth := PLAYSCREENWIDTH;
        nHeight := PLAYSCREENHEIGHT;
      end;

      FIDDraw := nil;
      if FDDrawHandle > 0 then
        FreeLibrary(FDDrawHandle);
      FDDrawHandle := LoadLibrary('DDraw.dll');

      if DD_OK = TDirectDrawCreate(GetProcAddress(FDDrawHandle, 'DirectDrawCreate'))(nil, FIDDraw, nil) then begin
        if DD_OK = FIDDraw.SetDisplayMode(nWidth, nHeight, 32) then begin
          FboDisplayChange := True;
          FHotKeyId := GlobalAddAtom('ClientKey') - $C000;
          RegisterHotKey(Handle, FHotKeyId, MOD_ALT, VK_TAB);
        end;
      end;
    end;
  end;
end;

procedure TFrmMain.DeviceNotifyEvent(Sender: TObject; Msg: Cardinal);
begin
  case Msg of
    msgDeviceLost: begin
        PlayScene.Lost;
        g_DXFont.Lost;
     //   DScreen.ClearHint(True);
        DebugOutStr('DeviceLost');
      end;
    msgDeviceRecovered: begin
        PlayScene.Recovered;
        g_DXFont.Recovered;
        Map.OldClientRect := Rect(0, 0, 0, 0);
      //  DScreen.ClearHint(True);
        DebugOutStr('DeviceRecovered');
      end;
    msgDeviceRestoreSize: begin
        ClientWidth := g_FScreenWidth;
        ClientHeight := g_FScreenHeight;
        if g_boFullScreen then begin
          if FIDDraw <> nil then begin
            FIDDraw.SetDisplayMode(ClientWidth, ClientHeight, 32); //·Ö±æÂÊÐÞ¸Ä±ê¼Ç
          end;
          m_Point.X := 0;
          m_Point.Y := 0;
        end else begin
          Left := (Screen.width - ClientWidth) div 2;
          Top := (Screen.Height - ClientHeight) div 2 - 40;
          SetWindowPos(handle, HWND_NOTOPMOST, left, top, width, height, SWP_SHOWWINDOW);
        end;
      end;
  end;
end;

procedure TFrmMain.WMMove(var Message: TWMMove);
begin
  m_Point := ClientOrigin;
  inherited;
end;

procedure TfrmMain.WMSetFocus(var WMessage: TMessage);
begin
  boInFocus := True;
  inherited;
end;

procedure TfrmMain.WMKillFocus(var WMessage: TMessage);
begin
  boInFocus := False;
  inherited;
end;

procedure TfrmMain.WMHotKey(var Msg: Tmessage);
begin
  if (Msg.LparamLo = MOD_ALT) and (Msg.LParamHi = VK_TAB) then begin
    PostMessage(Handle, WM_SYSCOMMAND, SC_MINIMIZE, 0);
  end;
end;

procedure TfrmMain.WMTabKey(var WMessage: TMessage);
var
  Key: Char;
  nKey: Word;
begin
  Key := #9;
  nKey := VK_TAB;
  FormKeyDown(self, nKey, []);
  FormKeyPress(self, Key);
  FormKeyUp(self, nKey, []);
end;

procedure TFrmMain.ProcessFreeTexture;
begin
  if GetTickCount > m_FreeTextureTick then begin
    m_FreeTextureTick := GetTickCount + 2000;
    while True do begin
      Inc(m_FreeTextureIndex);
      if not (m_FreeTextureIndex in [Low(g_ClientImages)..High(g_ClientImages)]) then begin
        m_FreeTextureIndex := Low(g_ClientImages);
      end;
      if (g_ClientImages[m_FreeTextureIndex] <> nil) and (g_ClientImages[m_FreeTextureIndex].SurfaceCount > 0) and
        (g_ClientImages[m_FreeTextureIndex].boInitialize) then
      begin
        g_ClientImages[m_FreeTextureIndex].FreeTextureByTime;
        Break;
      end;
    end;
  end;
end;

procedure TFrmMain.FullScreen(boFull: Boolean);
begin
  if g_boFullScreen <> boFull then begin
    TimerRun.Enabled := False;
    application.ProcessMessages;
    g_boFullScreen := boFull;
    if g_boFullScreen then begin
      DisplayChange(False);

      BorderStyle := bsNone;
      BorderIcons := [];

      ClientWidth := HGE.System_GetState(HGE_FScreenWidth);
      ClientHeight := HGE.System_GetState(HGE_FScreenHeight);
      WindowState := wsMaximized;

      m_Point.X := 0;
      m_Point.Y := 0;
    end else begin
      DisplayChange(True);

      BorderStyle := bsSingle;
      FormStyle := fsNormal;
      WindowState := wsNormal;
      ClientWidth := HGE.System_GetState(HGE_FScreenWidth);
      ClientHeight := HGE.System_GetState(HGE_FScreenHeight);
      BorderIcons := [biSystemMenu, biMinimize];
      Left := (Screen.width - ClientWidth) div 2;
      Top := (Screen.Height - ClientHeight) div 2 - 40;
      SetWindowPos(handle, HWND_NOTOPMOST, left, top, width, height, SWP_SHOWWINDOW);
    end;
    TimerRun.Enabled := True;
    Tag := 0;
  end;
end;

function TFrmMain.GetMagicType(nMagicID: Integer): Byte;
var
  bRet: byte;
begin
  bRet := 7;
  case nMagicID of
    1, 5, 9, 23, 22, 47, 113:
      begin
        bRet := 0;
      end;
    39, 40, 53, 33, 110:
      begin
        bRet := 1;
      end;
    41, 11, 10, 24, 63, 64, 66, 111, 133, 134:
      begin
        bRet := 2;
      end;
    67, 8, 31, 72, 73, 74, 114, 145:
      begin
        bRet := 3;
      end;
    2, 29, 77, 37, 38, 120, 122, 129, 136:
      begin
        bRet := 4;
      end;
    6, 13, 18, 19, 14, 15, 16:
      ;
    48:
      ;
    78:
      ;
    85, 86, 87, 88, 89, 90, 91, 92, 93:
      ;
		94,95,96,97,98,99,100,101,121,124,135,147,148,149:
		begin
			bRet := 5;
		end;
		17,30,20,21,32,105,104,112,123,127,137,146:
		begin
			bRet := 6;
		end;
		 4:;
    3, 25, 27, 26, 7, 12, 34, 35, 36, 102, 103, 106, 109, 125, 126, 128, 132,
      131, 130, 138, 139, 150, 141, 142, 143, 144:
      begin
        bRet := 7;
      end;
	end;
	Result := bRet;
end;


end.
