unit FState;

interface

uses
  Windows, Messages, SysUtils, Classes, Graphics, Controls, Forms, Dialogs,
  DWinCtl, StdCtrls, HGETextures, Grids, Grobal2, clFunc, hUtil32, cliUtil,
  MapUnit, SoundUtil, comobj , RelationShip , MaketSystem;

const
   BOTTOMBOARD = 1160;
   CHATBOARD = 1161;
   BIGCHATBOARD = 1162;
   VIEWCHATLINE = 5;
   MAXSTATEPAGE = 4;
   LISTLINEHEIGHT = 13;
   LISTLINEHEIGHT2 = 14;
   MAKETLINEHEIGHT = 19;
   REPLYIMGPOS = 20;
   MAXMENU = 10;
   DECOMAXMENU = 12;

   RING_OF_UNKNOWN = 130;
   BRACELET_OF_UNKNOWN = 131;
   HELMET_OF_UNKNOWN = 132;
   // ¾ÆÀÌÅÛ ¾÷±×·¹ÀÌµå
   UPITEMSUCCESSOFFSET = 633;//3960;

   // Ä£±¸ ,ÂÊÁö
   MAX_FRIEND_COUNT  = 20;
   VIEW_FRIEND       = 1;
   VIEW_MAILSEND     = 2;
   VIEW_MAILREAD     = 3;
   VIEW_MEMO         = 4;

   AdjustAbilHints : array[0..8] of string = (
      'ÆÄ±«·Â',
      '¸¶¹ýÀÇ Èû(ÁÖ¼ú»ç ÇØ´ç)',
      'µµ¼úÀÇ Èû(µµ»ç ÇØ´ç)',
      '¹æ¾î·Â',
      '¸¶¹ý ¹æ¾î·Â',
      'Ã¼·Â',
      '¸¶·Â',
      'Á¤È®¼º',
      'È¸ÇÇ·Â'
   );

  w11Img: array[0..1] of word = (942, 952);	// Equip.wil
  wBLightImg11: array[0..1] of word = (160, 161);	// ProgUse.wil
  w33Img: array[0..5] of word = (982, 992, 1002, 1012, 1022, 1032);	// Equip.wil
  wBLightImg33: array[0..5] of word = (100, 110, 101, 111, 102, 112); // ProgUse.wil
  w44Img: array[0..5] of word = (983, 993, 1003, 1013, 1023, 1033);	// Equip.wil
  wBLightImg44: array[0..5] of word = (120, 130, 121, 131, 122, 132); // ProgUse.wil
  w50Img: array[0..1] of word = (984, 994);	// Equip.wil
  wBLightImg50: array[0..1] of word = (190, 191); // ProgUse.wil
  w51Img: array[0..1] of word = (985, 995);	// Equip.wil
  wBLightImg51: array[0..1] of word = (171, 181); // ProgUse.wil
  w58Img: array[0..1] of word = (986, 996);	// Equip.wil
  wBLightImg58: array[0..1] of word = (281, 291); // ProgUse.wil

type

  TSpotDlgMode = (dmSell, dmRepair, dmStorage, dmMaketSell);

  TClickPoint = record
     rc: TRect;
     RStr: string;
  end;
  PTClickPoint = ^TClickPoint;

  TDiceInfo = record
     DiceResult: integer;
     DiceCurrent: integer;
     DiceLeft, DiceTop: integer;
     DiceCount: integer;
     DiceLimit: integer;
     DiceTime: longword;
  end;

  TFrmDlg = class(TForm)
    DStateWin: TDWindow;
    DBackground: TDWindow;
    DItemBag: TDWindow;
    DBottom: TDWindow;
    DMyState: TDButton;
    DMyBag: TDButton;
    DMyMagic: TDButton;
    DOption: TDButton;
    DGold: TDButton;
    DPrevState: TDButton;
    DRepairItem: TDButton;
    DCloseBag: TDButton;
    DCloseState: TDButton;
    DLogIn: TDWindow;
    DLoginNew: TDButton;
    DLoginOk: TDButton;
    DLoginClose: TDButton;
    DSelectChr: TDWindow;
    DscStart: TDButton;
    DscNewChr: TDButton;
    DscEraseChr: TDButton;
    DscExit: TDButton;
    DCreateChr: TDWindow;
    DccWarrior: TDButton;
    DccWizzard: TDButton;
    DccMonk: TDButton;
    DccReserved: TDButton;
    DccMale: TDButton;
    DccFemale: TDButton;
    DccLeftHair: TDButton;
    DccRightHair: TDButton;
    DccOk: TDButton;
    DccClose: TDButton;
    DItemGrid: TDGrid;
    DLoginChgPw: TDButton;
    DMsgDlg: TDWindow;
    DMsgDlgOk: TDButton;
    DMsgDlgYes: TDButton;
    DMsgDlgCancel: TDButton;
    DMsgDlgNo: TDButton;
    DNextState: TDButton;
    DSWNecklace: TDButton;
    DSWLight: TDButton;
    DSWArmRingR: TDButton;
    DSWArmRingL: TDButton;
    DSWRingR: TDButton;
    DSWRingL: TDButton;
    DSWWeapon: TDButton;
    DSWDress: TDButton;
    DSWHelmet: TDButton;
    DBelt1: TDButton;
    DBelt2: TDButton;
    DBelt3: TDButton;
    DBelt4: TDButton;
    DBelt5: TDButton;
    DBelt6: TDButton;
    DMerchantDlg: TDWindow;
    DMerchantDlgClose: TDButton;
    DMenuDlg: TDWindow;
    DMenuPrev: TDButton;
    DMenuNext: TDButton;
    DMenuBuy: TDButton;
    DMenuClose: TDButton;
    DSellDlg: TDWindow;
    DSellDlgOk: TDButton;
    DSellDlgClose: TDButton;
    DSellDlgSpot: TDButton;
    DStMag1: TDButton;
    DStMag2: TDButton;
    DStMag3: TDButton;
    DStMag4: TDButton;
    DStMag5: TDButton;
    DKeySelDlg: TDWindow;
    DKsIcon: TDButton;
    DKsF1: TDButton;
    DKsF2: TDButton;
    DKsF3: TDButton;
    DKsF4: TDButton;
    DKsNone: TDButton;
    DKsOk: TDButton;
    DBotGroup: TDButton;
    DBotTrade: TDButton;
    DBotMiniMap: TDButton;
    DGroupDlg: TDWindow;
    DGrpAllowGroup: TDButton;
    DGrpDlgClose: TDButton;
    DGrpCreate: TDButton;
    DGrpAddMem: TDButton;
    DGrpDelMem: TDButton;
    DBotLogout: TDButton;
    DBotExit: TDButton;
    DBotGuild: TDButton;
    DStPageUp: TDButton;
    DStPageDown: TDButton;
    DDealRemoteDlg: TDWindow;
    DDealDlg: TDWindow;
    DDRGrid: TDGrid;
    DDGrid: TDGrid;
    DDealOk: TDButton;
    DDealClose: TDButton;
    DDGold: TDButton;
    DDRGold: TDButton;
    DSelServerDlg: TDWindow;
    DSSrvClose: TDButton;
    DSServer1: TDButton;
    DSServer2: TDButton;
    DUserState1: TDWindow;
    DCloseUS1: TDButton;
    DWeaponUS1: TDButton;
    DHelmetUS1: TDButton;
    DNecklaceUS1: TDButton;
    DDressUS1: TDButton;
    DLightUS1: TDButton;
    DArmringRUS1: TDButton;
    DRingRUS1: TDButton;
    DArmringLUS1: TDButton;
    DRingLUS1: TDButton;
    DSServer3: TDButton;
    DSServer4: TDButton;
    DGuildDlg: TDWindow;
    DGDHome: TDButton;
    DGDList: TDButton;
    DGDChat: TDButton;
    DGDAddMem: TDButton;
    DGDDelMem: TDButton;
    DGDEditNotice: TDButton;
    DGDEditGrade: TDButton;
    DGDAlly: TDButton;
    DGDBreakAlly: TDButton;
    DGDWar: TDButton;
    DGDCancelWar: TDButton;
    DGDUp: TDButton;
    DGDDown: TDButton;
    DGDClose: TDButton;
    DGuildEditNotice: TDWindow;
    DGEClose: TDButton;
    DGEOk: TDButton;
    DSServer5: TDButton;
    DSServer6: TDButton;
    DAdjustAbility: TDWindow;
    DPlusDC: TDButton;
    DPlusMC: TDButton;
    DPlusSC: TDButton;
    DPlusAC: TDButton;
    DPlusMAC: TDButton;
    DPlusHP: TDButton;
    DPlusMP: TDButton;
    DPlusHit: TDButton;
    DPlusSpeed: TDButton;
    DMinusDC: TDButton;
    DMinusMC: TDButton;
    DMinusSC: TDButton;
    DMinusAC: TDButton;
    DMinusMAC: TDButton;
    DMinusMP: TDButton;
    DMinusHP: TDButton;
    DMinusHit: TDButton;
    DMinusSpeed: TDButton;
    DAdjustAbilClose: TDButton;
    DAdjustAbilOk: TDButton;
    DBotPlusAbil: TDButton;
    DKsF5: TDButton;
    DKsF6: TDButton;
    DKsF7: TDButton;
    DKsF8: TDButton;
    DEngServer1: TDButton;
    DSServer8: TDButton;
    DSServer7: TDButton;
    DSServer9: TDButton;
    DSServer10: TDButton;
    DSServer11: TDButton;
    DSServer12: TDButton;
    DSServer13: TDButton;
    DSServer14: TDButton;
    DSServer15: TDButton;
    DSServer16: TDButton;
    DSServer17: TDButton;
    DSServer18: TDButton;
    DSServer19: TDButton;
    DSServer20: TDButton;
    DSServer21: TDButton;
    DSServer22: TDButton;
    DSServer23: TDButton;
    DSServer24: TDButton;
    DSServer25: TDButton;
    DSServer26: TDButton;
    DSServer27: TDButton;
    DSServer28: TDButton;
    DSWBujuk: TDButton;
    DSWBelt: TDButton;
    DSWBoots: TDButton;
    DSWCharm: TDButton;
    DBujukUS1: TDButton;
    DBeltUS1: TDButton;
    DBootsUS1: TDButton;
    DCharmUS1: TDButton;
    DBotFriend: TDButton;
    DBotMemo: TDButton;
    DFriendDlg: TDWindow;
    DFrdClose: TDButton;
    DFrdPgUp: TDButton;
    DFrdPgDn: TDButton;
    DFrdFriend: TDButton;
    DFrdBlackList: TDButton;
    DFrdAdd: TDButton;
    DFrdDel: TDButton;
    DFrdMemo: TDButton;
    DFrdMail: TDButton;
    DFrdWhisper: TDButton;
    DMailListDlg: TDWindow;
    DMailDlg: TDWindow;
    DMailOK: TDButton;
    DMailClose: TDButton;
    DMailListClose: TDButton;
    DMailListPgUp: TDButton;
    DMailListPgDn: TDButton;
    DMLBlock: TDButton;
    DMLLock: TDButton;
    DMLDel: TDButton;
    DMLRead: TDButton;
    DMLReply: TDButton;
    DBlockListDlg: TDWindow;
    DBlockListClose: TDButton;
    DBLPgUp: TDButton;
    DBLPgDn: TDButton;
    DBLDel: TDButton;
    DBLAdd: TDButton;
    DMemo: TDWindow;
    DMemoClose: TDButton;
    DMemoB1: TDButton;
    DMemoB2: TDButton;
    DKsConF1: TDButton;
    DKsConF5: TDButton;
    DKsConF2: TDButton;
    DKsConF6: TDButton;
    DKsConF3: TDButton;
    DKsConF7: TDButton;
    DKsConF4: TDButton;
    DKsConF8: TDButton;
    DCountDlg: TDWindow;
    DMakeitemGrid: TDGrid;
    DMakeItemDlgOk: TDButton;
    DMakeItemDlgCancel: TDButton;
    DMakeItemDlgClose: TDButton;
    DMakeItemDlg: TDWindow;
    DCountDlgCancel: TDButton;
    DCountDlgClose: TDButton;
    DCountDlgMax: TDButton;
    DCountDlgOk: TDButton;
    DItemBuy: TDButton;
    DItemCancel: TDButton;
    DItemFind: TDButton;
    DItemMarketClose: TDButton;
    DItemSellCancel: TDButton;
    DItemListPrev: TDButton;
    DItemListRefresh: TDButton;
    DItemListNext: TDButton;
    DMGold: TDButton;
    DItemMarketDlg: TDWindow;
    DJangwonListDlg: TDWindow;
    DJangwonClose: TDButton;
    DJangListNext: TDButton;
    DJangMemo: TDButton;
    DJangListPrev: TDButton;
    DDealJangwon: TDWindow;
    DGABoardListDlg: TDWindow;
    DGABoardListClose: TDButton;
    DGABoardListNext: TDButton;
    DGABoardListRefresh: TDButton;
    DGABoardListPrev: TDButton;
    DGABoardDlg: TDWindow;
    DGABoardClose: TDButton;
    DGABoardCancel: TDButton;
    DGABoardOk2: TDButton;
    DGABoardReply: TDButton;
    DGABoardOk: TDButton;
    DGABoardWrite: TDButton;
    DGABoardNotice: TDButton;
    DGABoardDel: TDButton;
    DGABoardMemo: TDButton;
    DGADecorateDlg: TDWindow;
    DGADecorateListNext: TDButton;
    DGADecorateListPrev: TDButton;
    DGADecorateBuy: TDButton;
    DGADecorateCancel: TDButton;
    DGADecorateClose: TDButton;
    DMasterDlg: TDWindow;
    DLover1: TDButton;
    DLover2: TDButton;
    DLover3: TDButton;
    DMasterClose: TDButton;
    DMaster3: TDButton;
    DMaster2: TDButton;
    DMaster1: TDButton;
    DBotMaster: TDButton;
    DHeartImg: TDButton;
    DHeartImgUS: TDButton;
    DMarketMemo: TDButton;
    DMainOption: TDWindow;
    DSkillMode1: TDButton;
    DSkillBarOn: TDButton;
    DEffectOn: TDButton;
    DSoundOn: TDButton;
    DSkillMode2: TDButton;
    DSkillBarOff: TDButton;
    DEffectOff: TDButton;
    DSoundOff: TDButton;
    DMainOptionClose: TDButton;
    DChGroup: TDButton;
    DChFriend: TDButton;
    DChMemo: TDButton;
    DBeltWin: TDWindow;
    DCloseBelt: TDButton;
    DTurnBelt: TDButton;
    DSellDlgStHold: TDButton;
    DSellDlgBtnHold: TDButton;
    DDropViewOn: TDButton;
    DDropViewOff: TDButton;
    DChat: TDWindow;
    DMiniMapDlg: TDWindow;
    DMiniMapShow: TDButton;
    DMiniMapBlend: TDButton;
    DBotBelt: TDButton;
    DBotSkillBar: TDButton;
    DMagicWnd: TDWindow;
    DCloseMagic: TDButton;
    DMagicType0: TDButton;
    DMagicType1: TDButton;
    DMagicType2: TDButton;
    DMagicType3: TDButton;
    DMagicType4: TDButton;
    DMagicType5: TDButton;
    DMagicType6: TDButton;
    DMagicType7: TDButton;
    DMagicWndScrollBar: TDButton;
    DChatMode: TDButton;
    DChatSet1: TDButton;
    DChatSet2: TDButton;
    DChatSet3: TDButton;
    DChatSet4: TDButton;
    DChatSet5: TDButton;
    DChatSet6: TDButton;
    DChatScrlChat: TDButton;
    DChatSet7: TDButton;
    DShowMap: TDButton;
    DInventoryWnd: TDWindow;

    procedure DBottomInRealArea(Sender: TObject; X, Y: Integer;
      var IsRealArea: Boolean);
    procedure DBottomDirectPaint(Sender: TObject;
      dsurface: TDirectDrawSurface);
    procedure DMyStateDirectPaint(Sender: TObject;
      dsurface: TDirectDrawSurface);
    procedure DOptionClick(Sender: TObject);
    procedure DItemBagDirectPaint(Sender: TObject;
      dsurface: TDirectDrawSurface);
    procedure DStateWinDirectPaint(Sender: TObject;
      dsurface: TDirectDrawSurface);
    procedure FormCreate(Sender: TObject);
    procedure DPrevStateDirectPaint(Sender: TObject;
      dsurface: TDirectDrawSurface);
    procedure DLoginNewDirectPaint(Sender: TObject;
      dsurface: TDirectDrawSurface);
    procedure DscSelect1DirectPaint(Sender: TObject;
      dsurface: TDirectDrawSurface);
    procedure DccCloseDirectPaint(Sender: TObject;
      dsurface: TDirectDrawSurface);
    procedure DItemGridGridSelect(Sender: TObject; X, Y: Integer; ACol, ARow: Integer;
      Shift: TShiftState);
    procedure DItemGridGridPaint(Sender: TObject; ACol, ARow: Integer;
      Rect: TRect; State: TGridDrawState; dsurface: TDirectDrawSurface);
    procedure DItemGridDblClick(Sender: TObject);
    procedure DMsgDlgOkDirectPaint(Sender: TObject;
      dsurface: TDirectDrawSurface);
    procedure DMsgDlgDirectPaint(Sender: TObject;
      dsurface: TDirectDrawSurface);
    procedure DMsgDlgKeyDown(Sender: TObject; var Key: Word;
      Shift: TShiftState);
    procedure DCloseBagDirectPaint(Sender: TObject;
      dsurface: TDirectDrawSurface);
    procedure DBackgroundBackgroundClick(Sender: TObject);
    procedure DItemGridGridMouseMove(Sender: TObject; X, Y: Integer; ACol, ARow: Integer;
      Shift: TShiftState);
    procedure DBelt1DirectPaint(Sender: TObject;
      dsurface: TDirectDrawSurface);
    procedure FormDestroy(Sender: TObject);
    procedure DBelt1DblClick(Sender: TObject);
    procedure SwapBujuk(idx: integer);
    procedure DLoginCloseClick(Sender: TObject; X, Y: Integer);
    procedure DLoginOkClick(Sender: TObject; X, Y: Integer);
    procedure DLoginNewClick(Sender: TObject; X, Y: Integer);
    procedure DLoginChgPwClick(Sender: TObject; X, Y: Integer);
    procedure DccCloseClick(Sender: TObject; X, Y: Integer);
    procedure DscSelect1Click(Sender: TObject; X, Y: Integer);
    procedure DCloseStateClick(Sender: TObject; X, Y: Integer);
    procedure DPrevStateClick(Sender: TObject; X, Y: Integer);
    procedure DNextStateClick(Sender: TObject; X, Y: Integer);
    procedure DSWWeaponClick(Sender: TObject; X, Y: Integer);
    procedure DMsgDlgOkClick(Sender: TObject; X, Y: Integer);
    procedure DCloseBagClick(Sender: TObject; X, Y: Integer);
    procedure DBelt1Click(Sender: TObject; X, Y: Integer);
    procedure DMyStateClick(Sender: TObject; X, Y: Integer);
    procedure DStateWinClick(Sender: TObject; X, Y: Integer);
    procedure DSWWeaponMouseMove(Sender: TObject; Shift: TShiftState; X,
      Y: Integer);
    procedure DBelt1MouseMove(Sender: TObject; Shift: TShiftState; X,
      Y: Integer);
    procedure DMerchantDlgDirectPaint(Sender: TObject;
      dsurface: TDirectDrawSurface);
    procedure DMerchantDlgCloseClick(Sender: TObject; X, Y: Integer);
    procedure DMerchantDlgClick(Sender: TObject; X, Y: Integer);
    procedure DMerchantDlgMouseDown(Sender: TObject; Button: TMouseButton;
      Shift: TShiftState; X, Y: Integer);
    procedure DMerchantDlgMouseUp(Sender: TObject; Button: TMouseButton;
      Shift: TShiftState; X, Y: Integer);
    procedure DMenuCloseClick(Sender: TObject; X, Y: Integer);
    procedure DMenuDlgDirectPaint(Sender: TObject;
      dsurface: TDirectDrawSurface);
    procedure DMenuDlgClick(Sender: TObject; X, Y: Integer);
    procedure DSellDlgDirectPaint(Sender: TObject;
      dsurface: TDirectDrawSurface);
    procedure DSellDlgCloseClick(Sender: TObject; X, Y: Integer);
    procedure DSellDlgSpotClick(Sender: TObject; X, Y: Integer);
    procedure DSellDlgSpotDirectPaint(Sender: TObject;
      dsurface: TDirectDrawSurface);
    procedure DSellDlgSpotMouseMove(Sender: TObject; Shift: TShiftState; X,
      Y: Integer);
    procedure DSellDlgOkClick(Sender: TObject; X, Y: Integer);
    procedure DMenuBuyClick(Sender: TObject; X, Y: Integer);
    procedure DMenuPrevClick(Sender: TObject; X, Y: Integer);
    procedure DMenuNextClick(Sender: TObject; X, Y: Integer);
    procedure DGoldClick(Sender: TObject; X, Y: Integer);
    procedure DSWLightDirectPaint(Sender: TObject;
      dsurface: TDirectDrawSurface);
    procedure DBackgroundMouseDown(Sender: TObject; Button: TMouseButton;
      Shift: TShiftState; X, Y: Integer);
    procedure DStateWinMouseMove(Sender: TObject; Shift: TShiftState; X,
      Y: Integer);
    procedure DLoginNewClickSound(Sender: TObject;
      Clicksound: TClickSound);
    procedure DStMag1DirectPaint(Sender: TObject;
      dsurface: TDirectDrawSurface);
    procedure DStMag1Click(Sender: TObject; X, Y: Integer);
    procedure DKsIconDirectPaint(Sender: TObject;
      dsurface: TDirectDrawSurface);
    procedure DKsF1DirectPaint(Sender: TObject;
      dsurface: TDirectDrawSurface);
    procedure DKsOkClick(Sender: TObject; X, Y: Integer);
    procedure DKsF1Click(Sender: TObject; X, Y: Integer);
    procedure DKeySelDlgDirectPaint(Sender: TObject;
      dsurface: TDirectDrawSurface);
    procedure DBotGroupDirectPaint(Sender: TObject;
      dsurface: TDirectDrawSurface);
    procedure DGrpAllowGroupDirectPaint(Sender: TObject;
      dsurface: TDirectDrawSurface);
    procedure DGrpDlgCloseClick(Sender: TObject; X, Y: Integer);
    procedure DBotGroupClick(Sender: TObject; X, Y: Integer);
    procedure DGrpAllowGroupClick(Sender: TObject; X, Y: Integer);
    procedure DGrpCreateClick(Sender: TObject; X, Y: Integer);
    procedure DGroupDlgDirectPaint(Sender: TObject;
      dsurface: TDirectDrawSurface);
    procedure DGrpAddMemClick(Sender: TObject; X, Y: Integer);
    procedure DGrpDelMemClick(Sender: TObject; X, Y: Integer);
    procedure DBotLogoutClick(Sender: TObject; X, Y: Integer);
    procedure DBotExitClick(Sender: TObject; X, Y: Integer);
    procedure DStPageUpClick(Sender: TObject; X, Y: Integer);
    procedure DBottomMouseDown(Sender: TObject; Button: TMouseButton;
      Shift: TShiftState; X, Y: Integer);
    procedure DDealOkClick(Sender: TObject; X, Y: Integer);
    procedure DDealCloseClick(Sender: TObject; X, Y: Integer);
    procedure DBotTradeClick(Sender: TObject; X, Y: Integer);
    procedure DDealRemoteDlgDirectPaint(Sender: TObject;
      dsurface: TDirectDrawSurface);
    procedure DDealDlgDirectPaint(Sender: TObject;
      dsurface: TDirectDrawSurface);
    procedure DDGridGridSelect(Sender: TObject; X, Y: Integer; ACol, ARow: Integer;
      Shift: TShiftState);
    procedure DDGridGridPaint(Sender: TObject; ACol, ARow: Integer;
      Rect: TRect; State: TGridDrawState; dsurface: TDirectDrawSurface);
    procedure DDGridGridMouseMove(Sender: TObject; X, Y: Integer; ACol, ARow: Integer;
      Shift: TShiftState);
    procedure DDRGridGridPaint(Sender: TObject; ACol, ARow: Integer;
      Rect: TRect; State: TGridDrawState; dsurface: TDirectDrawSurface);
    procedure DDRGridGridMouseMove(Sender: TObject; X, Y: Integer; ACol, ARow: Integer;
      Shift: TShiftState);
    procedure DDGoldClick(Sender: TObject; X, Y: Integer);
    procedure DSServer1Click(Sender: TObject; X, Y: Integer);
    procedure DSSrvCloseClick(Sender: TObject; X, Y: Integer);
    procedure DBotMiniMapClick(Sender: TObject; X, Y: Integer);
    procedure DMenuDlgMouseMove(Sender: TObject; Shift: TShiftState; X,
      Y: Integer);
    procedure DUserState1DirectPaint(Sender: TObject;
      dsurface: TDirectDrawSurface);
    procedure DUserState1MouseMove(Sender: TObject; Shift: TShiftState; X,
      Y: Integer);
    procedure DWeaponUS1MouseMove(Sender: TObject; Shift: TShiftState; X,
      Y: Integer);
    procedure DCloseUS1Click(Sender: TObject; X, Y: Integer);
    procedure DNecklaceUS1DirectPaint(Sender: TObject;
      dsurface: TDirectDrawSurface);
    procedure DBotGuildClick(Sender: TObject; X, Y: Integer);
    procedure DGuildDlgDirectPaint(Sender: TObject;
      dsurface: TDirectDrawSurface);
    procedure DGDUpClick(Sender: TObject; X, Y: Integer);
    procedure DGDDownClick(Sender: TObject; X, Y: Integer);
    procedure DGDCloseClick(Sender: TObject; X, Y: Integer);
    procedure DGDHomeClick(Sender: TObject; X, Y: Integer);
    procedure DGDListClick(Sender: TObject; X, Y: Integer);
    procedure DGDAddMemClick(Sender: TObject; X, Y: Integer);
    procedure DGDDelMemClick(Sender: TObject; X, Y: Integer);
    procedure DGDEditNoticeClick(Sender: TObject; X, Y: Integer);
    procedure DGDEditGradeClick(Sender: TObject; X, Y: Integer);
    procedure DGECloseClick(Sender: TObject; X, Y: Integer);
    procedure DGEOkClick(Sender: TObject; X, Y: Integer);
    procedure DGuildEditNoticeDirectPaint(Sender: TObject;
      dsurface: TDirectDrawSurface);
    procedure DGDChatClick(Sender: TObject; X, Y: Integer);
    procedure DGoldDirectPaint(Sender: TObject;
      dsurface: TDirectDrawSurface);
    procedure DAdjustAbilCloseClick(Sender: TObject; X, Y: Integer);
    procedure DAdjustAbilityDirectPaint(Sender: TObject;
      dsurface: TDirectDrawSurface);
    procedure DBotPlusAbilClick(Sender: TObject; X, Y: Integer);
    procedure DPlusDCClick(Sender: TObject; X, Y: Integer);
    procedure DMinusDCClick(Sender: TObject; X, Y: Integer);
    procedure DAdjustAbilOkClick(Sender: TObject; X, Y: Integer);
    procedure DBotPlusAbilDirectPaint(Sender: TObject;
      dsurface: TDirectDrawSurface);
    procedure DAdjustAbilityMouseMove(Sender: TObject; Shift: TShiftState;
      X, Y: Integer);
    procedure DUserState1MouseDown(Sender: TObject; Button: TMouseButton;
      Shift: TShiftState; X, Y: Integer);
    procedure DEngServer1Click(Sender: TObject; X, Y: Integer);
    procedure DGDAllyClick(Sender: TObject; X, Y: Integer);
    procedure DGDBreakAllyClick(Sender: TObject; X, Y: Integer);
    procedure DSelServerDlgDirectPaint(Sender: TObject;
      dsurface: TDirectDrawSurface);
    procedure DSServer1DirectPaint(Sender: TObject;
      dsurface: TDirectDrawSurface);
    procedure DBotExitMouseMove(Sender: TObject; Shift: TShiftState; X,
      Y: Integer);
    procedure DBotGroupMouseMove(Sender: TObject; Shift: TShiftState; X,
      Y: Integer);
    procedure DBotLogoutMouseMove(Sender: TObject; Shift: TShiftState; X,
      Y: Integer);
    procedure DBotMiniMapMouseMove(Sender: TObject; Shift: TShiftState; X,
      Y: Integer);
    procedure DBotTradeMouseMove(Sender: TObject; Shift: TShiftState; X,
      Y: Integer);
    procedure DBotGuildMouseMove(Sender: TObject; Shift: TShiftState; X,
      Y: Integer);
    procedure DMyStateMouseMove(Sender: TObject; Shift: TShiftState; X,
      Y: Integer);
    procedure DMyBagMouseMove(Sender: TObject; Shift: TShiftState; X,
      Y: Integer);
    procedure DMyMagicMouseMove(Sender: TObject; Shift: TShiftState; X,
      Y: Integer);
    procedure DOptionMouseMove(Sender: TObject; Shift: TShiftState; X,
      Y: Integer);
    procedure DBottomMouseMove(Sender: TObject; Shift: TShiftState; X,
      Y: Integer);
    procedure DBotFriendClick(Sender: TObject; X, Y: Integer);
    procedure DBotFriendDirectPaint(Sender: TObject;
      dsurface: TDirectDrawSurface);
    procedure DBotFriendMouseMove(Sender: TObject; Shift: TShiftState; X,
      Y: Integer);
    procedure DFriendDlgDirectPaint(Sender: TObject;
      dsurface: TDirectDrawSurface);
    procedure DFrdPgUpClick(Sender: TObject; X, Y: Integer);
    procedure DFrdPgUpDirectPaint(Sender: TObject;
      dsurface: TDirectDrawSurface);
    procedure DFrdFriendClick(Sender: TObject; X, Y: Integer);
    procedure DFrdBlackListClick(Sender: TObject; X, Y: Integer);
    procedure DFrdAddMouseMove(Sender: TObject; Shift: TShiftState; X,
      Y: Integer);
    procedure DFrdDelMouseMove(Sender: TObject; Shift: TShiftState; X,
      Y: Integer);
    procedure DFrdMemoMouseMove(Sender: TObject; Shift: TShiftState; X,
      Y: Integer);
    procedure DFrdMailMouseMove(Sender: TObject; Shift: TShiftState; X,
      Y: Integer);
    procedure DFrdWhisperMouseMove(Sender: TObject; Shift: TShiftState; X,
      Y: Integer);
    procedure DFrdCloseClick(Sender: TObject; X, Y: Integer);
    procedure DFrdFriendDirectPaint(Sender: TObject;
      dsurface: TDirectDrawSurface);
    procedure DFrdBlackListDirectPaint(Sender: TObject;
      dsurface: TDirectDrawSurface);
    procedure DMailListDlgDirectPaint(Sender: TObject;
      dsurface: TDirectDrawSurface);
    procedure DMailListCloseClick(Sender: TObject; X, Y: Integer);
    procedure DMailListPgUpClick(Sender: TObject; X, Y: Integer);
    procedure DMLReplyMouseMove(Sender: TObject; Shift: TShiftState; X,
      Y: Integer);
    procedure DMLReadMouseMove(Sender: TObject; Shift: TShiftState; X,
      Y: Integer);
    procedure DMLDelMouseMove(Sender: TObject; Shift: TShiftState; X,
      Y: Integer);
    procedure DMLLockMouseMove(Sender: TObject; Shift: TShiftState; X,
      Y: Integer);
    procedure DMLBlockMouseMove(Sender: TObject; Shift: TShiftState; X,
      Y: Integer);
    procedure DMailListDlgClick(Sender: TObject; X, Y: Integer);
    procedure DFriendDlgClick(Sender: TObject; X, Y: Integer);
    procedure DBlockListCloseClick(Sender: TObject; X, Y: Integer);
    procedure DBLPgUpClick(Sender: TObject; X, Y: Integer);
    procedure DBlockListDlgDirectPaint(Sender: TObject;
      dsurface: TDirectDrawSurface);
    procedure DBlockListDlgClick(Sender: TObject; X, Y: Integer);
    procedure DBLAddMouseMove(Sender: TObject; Shift: TShiftState; X,
      Y: Integer);
    procedure DBLDelMouseMove(Sender: TObject; Shift: TShiftState; X,
      Y: Integer);
    procedure DMLBlockClick(Sender: TObject; X, Y: Integer);
    procedure DBotMemoMouseMove(Sender: TObject; Shift: TShiftState; X,
      Y: Integer);
    procedure DBotMemoClick(Sender: TObject; X, Y: Integer);
    procedure DFrdAddClick(Sender: TObject; X, Y: Integer);
    procedure DMLReadClick(Sender: TObject; X, Y: Integer);
    procedure DFrdMailClick(Sender: TObject; X, Y: Integer);
    procedure DMemoDirectPaint(Sender: TObject;
      dsurface: TDirectDrawSurface);
    procedure DFrdMemoClick(Sender: TObject; X, Y: Integer);
    procedure DMemoCloseClick(Sender: TObject; X, Y: Integer);
    procedure DFrdDelClick(Sender: TObject; X, Y: Integer);
    procedure DFrdWhisperClick(Sender: TObject; X, Y: Integer);
    procedure DMemoB1DirectPaint(Sender: TObject;
      dsurface: TDirectDrawSurface);
    procedure DMemoB2DirectPaint(Sender: TObject;
      dsurface: TDirectDrawSurface);
    procedure DMemoB1Click(Sender: TObject; X, Y: Integer);
    procedure DBLAddClick(Sender: TObject; X, Y: Integer);
    procedure DBLDelClick(Sender: TObject; X, Y: Integer);
    procedure DMLReplyClick(Sender: TObject; X, Y: Integer);
    procedure DMLDelClick(Sender: TObject; X, Y: Integer);
    procedure DMLLockClick(Sender: TObject; X, Y: Integer);
    procedure DFriendDlgDblClick(Sender: TObject);
    procedure DMailListDlgDblClick(Sender: TObject);
    procedure DBotMemoDirectPaint(Sender: TObject;
      dsurface: TDirectDrawSurface);
    procedure DFriendDlgMouseUp(Sender: TObject; Button: TMouseButton;
      Shift: TShiftState; X, Y: Integer);
    procedure DMailListDlgMouseUp(Sender: TObject; Button: TMouseButton;
      Shift: TShiftState; X, Y: Integer);
    procedure DFrdPgUpMouseMove(Sender: TObject; Shift: TShiftState; X,
      Y: Integer);
    procedure DFrdPgDnMouseMove(Sender: TObject; Shift: TShiftState; X,
      Y: Integer);
    procedure DMailListPgUpMouseMove(Sender: TObject; Shift: TShiftState;
      X, Y: Integer);
    procedure DMailListPgDnMouseMove(Sender: TObject; Shift: TShiftState;
      X, Y: Integer);
    procedure DBLPgUpMouseMove(Sender: TObject; Shift: TShiftState; X,
      Y: Integer);
    procedure DBLPgDnMouseMove(Sender: TObject; Shift: TShiftState; X,
      Y: Integer);
    procedure DFriendDlgMouseMove(Sender: TObject; Shift: TShiftState; X,
      Y: Integer);
    procedure DMailListDlgMouseMove(Sender: TObject; Shift: TShiftState; X,
      Y: Integer);
    procedure DMailDlgMouseMove(Sender: TObject; Shift: TShiftState; X,
      Y: Integer);
    procedure DBlockListDlgMouseMove(Sender: TObject; Shift: TShiftState;
      X, Y: Integer);
    procedure DMemoMouseMove(Sender: TObject; Shift: TShiftState; X,
      Y: Integer);
    procedure DMakeItemDlgOkDirectPaint(Sender: TObject;
      dsurface: TDirectDrawSurface);
    procedure DCountDlgDirectPaint(Sender: TObject;
      dsurface: TDirectDrawSurface);
    procedure DCountDlgKeyDown(Sender: TObject; var Key: Word;
      Shift: TShiftState);
    procedure DCountDlgOkDirectPaint(Sender: TObject;
      dsurface: TDirectDrawSurface);
    procedure DCountDlgOkClick(Sender: TObject; X, Y: Integer);
    procedure DCountDlgCloseClick(Sender: TObject; X, Y: Integer);
    procedure DMakeItemDlgDirectPaint(Sender: TObject;
      dsurface: TDirectDrawSurface);
    procedure DMakeitemGridGridPaint(Sender: TObject; ACol, ARow: Integer;
      Rect: TRect; State: TGridDrawState; dsurface: TDirectDrawSurface);
    procedure DMakeitemGridGridMouseMove(Sender: TObject; X, Y: Integer; ACol,
      ARow: Integer; Shift: TShiftState);
    procedure DMakeitemGridGridSelect(Sender: TObject; X, Y: Integer; ACol, ARow: Integer;
      Shift: TShiftState);
    procedure DMakeItemDlgOkClick(Sender: TObject; X, Y: Integer);
    procedure DItemMarketDlgDirectPaint(Sender: TObject;
      dsurface: TDirectDrawSurface);
    procedure DItemMarketDlgClick(Sender: TObject; X, Y: Integer);
    procedure DItemMarketDlgMouseMove(Sender: TObject; Shift: TShiftState;
      X, Y: Integer);
    procedure DItemListPrevClick(Sender: TObject; X, Y: Integer);
    procedure DItemListNextClick(Sender: TObject; X, Y: Integer);
    procedure DItemBuyClick(Sender: TObject; X, Y: Integer);
    procedure DItemMarketCloseClick(Sender: TObject; X, Y: Integer);
    procedure DMGoldDirectPaint(Sender: TObject;
      dsurface: TDirectDrawSurface);
    procedure DItemMarketDlgKeyDown(Sender: TObject; var Key: Word;
      Shift: TShiftState);
    procedure DItemListRefreshClick(Sender: TObject; X, Y: Integer);
    procedure DItemSellCancelClick(Sender: TObject; X, Y: Integer);
    procedure DItemFindClick(Sender: TObject; X, Y: Integer);
  
    procedure DItemSellCancelMouseMove(Sender: TObject; Shift: TShiftState;
      X, Y: Integer);
    procedure DItemCancelMouseMove(Sender: TObject; Shift: TShiftState; X,
      Y: Integer);
    procedure DItemBagClick(Sender: TObject; X, Y: Integer);
    procedure DMemoClick(Sender: TObject; X, Y: Integer);
    procedure DMailDlgClick(Sender: TObject; X, Y: Integer);
    procedure DItemMarketDlgMouseDown(Sender: TObject;
      Button: TMouseButton; Shift: TShiftState; X, Y: Integer);
    procedure DJangwonListDlgClick(Sender: TObject; X, Y: Integer);
    procedure DJangwonListDlgDirectPaint(Sender: TObject;
      dsurface: TDirectDrawSurface);
    procedure DJangwonCloseClick(Sender: TObject; X, Y: Integer);
    procedure DJangListPrevClick(Sender: TObject; X, Y: Integer);
    procedure DJangListNextClick(Sender: TObject; X, Y: Integer);
    procedure DJangMemoClick(Sender: TObject; X, Y: Integer);
    procedure DDealJangwonDirectPaint(Sender: TObject;
      dsurface: TDirectDrawSurface);
    procedure DGABoardListDlgDirectPaint(Sender: TObject;
      dsurface: TDirectDrawSurface);
    procedure DGABoardListCloseClick(Sender: TObject; X, Y: Integer);
    procedure DGABoardOkClick(Sender: TObject; X, Y: Integer);
    procedure DGABoardListDlgDblClick(Sender: TObject);
    procedure DGABoardListDlgMouseDown(Sender: TObject;
      Button: TMouseButton; Shift: TShiftState; X, Y: Integer);
    procedure DGABoardDlgDirectPaint(Sender: TObject;
      dsurface: TDirectDrawSurface);
    procedure DGABoardCloseClick(Sender: TObject; X, Y: Integer);
    procedure DGABoardOk2Click(Sender: TObject; X, Y: Integer);
    procedure DGABoardWriteClick(Sender: TObject; X, Y: Integer);
    procedure DGABoardNoticeClick(Sender: TObject; X, Y: Integer);
    procedure DGABoardReplyClick(Sender: TObject; X, Y: Integer);
    procedure DGABoardDlgKeyDown(Sender: TObject; var Key: Word;
      Shift: TShiftState);
    procedure DGABoardListNextClick(Sender: TObject; X, Y: Integer);
    procedure DGABoardListPrevClick(Sender: TObject; X, Y: Integer);
    procedure DGABoardListRefreshClick(Sender: TObject; X, Y: Integer);
    procedure DGABoardMemoClick(Sender: TObject; X, Y: Integer);
    procedure DGABoardDelClick(Sender: TObject; X, Y: Integer);
    procedure DGADecorateDlgDirectPaint(Sender: TObject;
      dsurface: TDirectDrawSurface);
    procedure DGADecorateCloseClick(Sender: TObject; X, Y: Integer);
    procedure DGADecorateBuyClick(Sender: TObject; X, Y: Integer);
    procedure DGADecorateCancelClick(Sender: TObject; X, Y: Integer);
    procedure DGADecorateDlgClick(Sender: TObject; X, Y: Integer);
    procedure DGADecorateDlgKeyDown(Sender: TObject; var Key: Word;
      Shift: TShiftState);
    procedure DGADecorateListNextClick(Sender: TObject; X, Y: Integer);
    procedure DGADecorateListPrevClick(Sender: TObject; X, Y: Integer);
    procedure DMasterDlgClick(Sender: TObject; X, Y: Integer);
    procedure DMasterDlgDirectPaint(Sender: TObject;
      dsurface: TDirectDrawSurface);
    procedure DMasterDlgMouseMove(Sender: TObject; Shift: TShiftState; X,
      Y: Integer);
    procedure DLover1Click(Sender: TObject; X, Y: Integer);
    procedure DLover1MouseMove(Sender: TObject; Shift: TShiftState; X,
      Y: Integer);
    procedure DLover2Click(Sender: TObject; X, Y: Integer);
    procedure DLover2MouseMove(Sender: TObject; Shift: TShiftState; X,
      Y: Integer);
    procedure DLover3Click(Sender: TObject; X, Y: Integer);
    procedure DLover3MouseMove(Sender: TObject; Shift: TShiftState; X,
      Y: Integer);
    procedure DMasterCloseClick(Sender: TObject; X, Y: Integer);
    procedure DHeartImgDirectPaint(Sender: TObject;
      dsurface: TDirectDrawSurface);
    procedure DHeartImgUSDirectPaint(Sender: TObject;
      dsurface: TDirectDrawSurface);
    procedure DBotMasterClick(Sender: TObject; X, Y: Integer);
    procedure DBotMasterMouseMove(Sender: TObject; Shift: TShiftState; X,
      Y: Integer);
    procedure DMarketMemoClick(Sender: TObject; X, Y: Integer);
    procedure DMemoKeyDown(Sender: TObject; var Key: Word;
      Shift: TShiftState);
    procedure DMainOptionDirectPaint(Sender: TObject;
      dsurface: TDirectDrawSurface);
    procedure DSkillMode1Click(Sender: TObject; X, Y: Integer);
    procedure DSkillMode2Click(Sender: TObject; X, Y: Integer);
    procedure DSkillBarOnClick(Sender: TObject; X, Y: Integer);
    procedure DSkillBarOffClick(Sender: TObject; X, Y: Integer);
    procedure DSkillBarOnDirectPaint(Sender: TObject;
      dsurface: TDirectDrawSurface);
    procedure DEffectOnClick(Sender: TObject; X, Y: Integer);
    procedure DEffectOffClick(Sender: TObject; X, Y: Integer);
    procedure DSoundOnClick(Sender: TObject; X, Y: Integer);
    procedure DSoundOffClick(Sender: TObject; X, Y: Integer);
    procedure DMainOptionCloseClick(Sender: TObject; X, Y: Integer);
    procedure DChFriendDirectPaint(Sender: TObject;
      dsurface: TDirectDrawSurface);
    procedure DChGroupClick(Sender: TObject; X, Y: Integer);
    procedure DChFriendClick(Sender: TObject; X, Y: Integer);
    procedure DChMemoClick(Sender: TObject; X, Y: Integer);
    procedure DChGroupMouseMove(Sender: TObject; Shift: TShiftState; X,
      Y: Integer);
    procedure DChFriendMouseMove(Sender: TObject; Shift: TShiftState; X,
      Y: Integer);
    procedure DChMemoMouseMove(Sender: TObject; Shift: TShiftState; X,
      Y: Integer);
    procedure DCreateChrDirectPaint(Sender: TObject;
      dsurface: TDirectDrawSurface);
    procedure DBeltWinDirectPaint(Sender: TObject;
      dsurface: TDirectDrawSurface);
    procedure DCloseBeltClick(Sender: TObject; X, Y: Integer);
    procedure DCloseBeltMouseMove(Sender: TObject; Shift: TShiftState; X,
      Y: Integer);
    procedure DTurnBeltClick(Sender: TObject; X, Y: Integer);
    procedure DCloseBeltDirectPaint(Sender: TObject;
      dsurface: TDirectDrawSurface);
    procedure DSellDlgBtnHoldClick(Sender: TObject; X, Y: Integer);
    procedure DSellDlgStHoldDirectPaint(Sender: TObject;
      dsurface: TDirectDrawSurface);
    procedure DSelectChrClick(Sender: TObject; X, Y: Integer);
    procedure DSellDlgBtnHoldMouseMove(Sender: TObject; Shift: TShiftState;
      X, Y: Integer);
    procedure DDropViewOnClick(Sender: TObject; X, Y: Integer);
    procedure DDropViewOffClick(Sender: TObject; X, Y: Integer);
    procedure DGrpAllowGroupMouseMove(Sender: TObject; Shift: TShiftState;
      X, Y: Integer);
    procedure DGroupDlgMouseMove(Sender: TObject; Shift: TShiftState; X,
      Y: Integer);
    procedure DLogInDirectPaint(Sender: TObject; dsurface: TDirectDrawSurface);
    procedure DSelServerDlgMouseMove(Sender: TObject; Shift: TShiftState; X,
      Y: Integer);
    procedure DSelServerDlgInRealArea(Sender: TObject; X, Y: Integer;
      var IsRealArea: Boolean);
    procedure DSelServerDlgClick(Sender: TObject; X, Y: Integer);
    procedure DccOkDirectPaint(Sender: TObject; dsurface: TDirectDrawSurface);
    procedure DscStartInRealArea(Sender: TObject; X, Y: Integer; var IsRealArea: Boolean);
    procedure DCreateChrClick(Sender: TObject; X, Y: Integer);
    procedure DChatDirectPaint(Sender: TObject;
      dsurface: TDirectDrawSurface);
    procedure DChatInRealArea(Sender: TObject; X, Y: Integer;
      var IsRealArea: Boolean);
    procedure DMiniMapDlgDirectPaint(Sender: TObject;
      dsurface: TDirectDrawSurface);
    procedure DMiniMapShowClick(Sender: TObject; X, Y: Integer);
    procedure DMiniMapBlendClick(Sender: TObject; X, Y: Integer);
    procedure DBotBeltClick(Sender: TObject; X, Y: Integer);
    procedure DBotBeltMouseMove(Sender: TObject; Shift: TShiftState; X, Y: Integer);
    procedure DBotSkillBarClick(Sender: TObject; X, Y: Integer);
    procedure DBotSkillBarMouseMove(Sender: TObject; Shift: TShiftState; X, Y: Integer);
    procedure DCloseStateMouseMove(Sender: TObject; Shift: TShiftState; X,
      Y: Integer);
    procedure DMiniMapBlendDirectPaint(Sender: TObject;
      dsurface: TDirectDrawSurface);
    procedure DMiniMapShowDirectPaint(Sender: TObject;
      dsurface: TDirectDrawSurface);
    procedure DCloseBagMouseMove(Sender: TObject; Shift: TShiftState; X,
      Y: Integer);
    procedure DCloseUS1MouseMove(Sender: TObject; Shift: TShiftState; X,
      Y: Integer);
    procedure DCloseMagicMouseMove(Sender: TObject; Shift: TShiftState; X, Y: Integer);
    procedure DCloseMagicClick(Sender: TObject; X, Y: Integer);
    procedure DMagicWndDirectPaint(Sender: TObject; dsurface: TDirectDrawSurface);
    procedure DLoginOkDirectPaint(Sender: TObject; dsurface: TDirectDrawSurface);
    procedure DLoginNewInRealArea(Sender: TObject; X, Y: Integer; var IsRealArea: Boolean);
    procedure DGrpCreateMouseMove(Sender: TObject; Shift: TShiftState; X,
      Y: Integer);
    procedure DGrpAddMemMouseMove(Sender: TObject; Shift: TShiftState; X,
      Y: Integer);
    procedure DGrpDelMemMouseMove(Sender: TObject; Shift: TShiftState; X,
      Y: Integer);
    procedure DMiniMapShowMouseMove(Sender: TObject; Shift: TShiftState; X,
      Y: Integer);
    procedure DMiniMapBlendMouseMove(Sender: TObject; Shift: TShiftState; X,
      Y: Integer);
    procedure DMagicType0DirectPaint(Sender: TObject;
      dsurface: TDirectDrawSurface);
    procedure DMagicType0Click(Sender: TObject; X, Y: Integer);
    procedure DMagicWndScrollBarDirectPaint(Sender: TObject; dsurface: TDirectDrawSurface);
    procedure DMagicWndScrollBarMouseMove(Sender: TObject; Shift: TShiftState; X, Y: Integer);
    procedure DMagicWndMouseMove(Sender: TObject; Shift: TShiftState; X,
      Y: Integer);
    procedure DccWarriorMouseMove(Sender: TObject; Shift: TShiftState; X,
      Y: Integer);
    procedure DCreateChrMouseMove(Sender: TObject; Shift: TShiftState; X,
      Y: Integer);
    procedure DSelectChrMouseMove(Sender: TObject; Shift: TShiftState; X,
      Y: Integer);
    procedure DMagicType0MouseMove(Sender: TObject; Shift: TShiftState; X,
      Y: Integer);
    procedure DChatModeMouseMove(Sender: TObject; Shift: TShiftState; X,
      Y: Integer);
    procedure DChatModeDirectPaint(Sender: TObject;
      dsurface: TDirectDrawSurface);
    procedure DChatModeClick(Sender: TObject; X, Y: Integer);
    procedure DChatSet3DirectPaint(Sender: TObject;
      dsurface: TDirectDrawSurface);
    procedure DChatSet3Click(Sender: TObject; X, Y: Integer);
    procedure DChatSet4Click(Sender: TObject; X, Y: Integer);
    procedure DChatSet5Click(Sender: TObject; X, Y: Integer);
    procedure DChatSet6Click(Sender: TObject; X, Y: Integer);
    procedure DChatSet7Click(Sender: TObject; X, Y: Integer);
    procedure DMagicWndClick(Sender: TObject; X, Y: Integer);
    procedure DShowMapDirectPaint(Sender: TObject;
      dsurface: TDirectDrawSurface);
    procedure DInventoryWndDirectPaint(Sender: TObject;
      dsurface: TDirectDrawSurface);
  private
    DlgTemp: TList;
    magcur, magtop: integer;
    EdDlgEdit: TEdit;
    EdCountEdit: TEdit;
    ItemSearchEdit: TEdit;
    Memo: TMemo;
    // 2003/04/15 Ä£±¸, ÂÊÁö
    edCharID : TEdit;
    memoMail : TMemo;

    ViewDlgEdit: Boolean;
    msglx, msgly: integer;

    MagKeyIcon, MagKeyCurKey: integer;
    MagKeyMagName  : string;
    BackupMemoMail : string;
    StrMemoMail    : string;
    MagicPage: integer;
    // 2003/04/15 Ä£±¸, ÂÊÁö
    MemoCharID    : string;
    MemoCharID2   : string;
    MemoDate      : string;
    FriendPage    : integer;
    BlackListPage : integer;
    MailPage      : integer;
    BlockPage     : integer;
    CurrentMail   : integer;
    CurrentFriend : integer;
    CurrentBlack  : integer;
    CurrentBlock  : integer;
    ViewFriends   : boolean;
    ViewWindowNo  : integer;
    ViewWindowData: integer;
    FriendDlgDblClicked  : Boolean;
    MailListDlgDblClicked: Boolean;

    BlinkTime: longword;
    BlinkCount: integer;  //0..9»çÀÌ¸¦ ¹Ýº¹

    procedure RestoreHideControls;
    procedure PageChanged;
    procedure DealItemReturnBag (mitem: TClientItem);
    procedure DealZeroGold;
    procedure SetMagicIconPos;
    function GetInvenCellNum(ptMouse :TPoint):Integer;
    function GetInvenItemNum(ptMouse :TPoint):Integer;
    function GetEmptyInvenNum():Integer;
    function CanItemInsert(nCellNum: Integer; {CItem* pxItem;} rcCell: TRect):Boolean;
    procedure SetItemState({CItem* pxItem; }nItemNum: Integer; lprcCell: TRect);
    function GetCellWH(wLooks: word; var nCellWidth, nCellHeight: integer):Boolean;
  public
    MenuTop: integer;
    StatePage: integer;
    MsgText: string;
    DialogSize: integer;
    RunDice: integer;
    DiceType: Byte;
    BoDrawDice: Boolean;
    DiceArr: array[0..9] of TDiceInfo;

    MerchantName: string;
    MerchantFace: integer;
    MDlgStr: string;
    MDlgPoints: TList;
    RequireAddPoints: Boolean;
    SelectMenuStr: string;
    LastestClickTime: longword;
    MsgDlgClickTime: longword;
    SpotDlgMode: TSpotDlgMode;

    MenuList: TList; //list of PTClientGoods
    JangwonList: TList; //Àå¿ø ¸®½ºÆ® PTClientJangwon
    GABoardList: TList; //Àå¿ø °Ô½ÃÆÇ ¸®½ºÆ®
    GADecorationList: TList; //Àå¿ø ²Ù¹Ì±â ¸®½ºÆ®
    MenuIndex: integer;
    CurDetailItem: string;
    MenuTopLine: integer;

    BoDetailMenu: Boolean;
    BoStorageMenu: Boolean;
    BoNoDisplayMaxDura: Boolean;
    BoMakeDrugMenu: Boolean;
//    BoFirstShowOnServerSel: Boolean;
    // ¾ÆÀÌÅÛ ¾÷±×·¹ÀÌµå
    BoUpItemEffect: Boolean;
    CurUpItemEffect: integer;
    UpItemOffset  : integer;
    UpItemMaxFrame  : integer;
    upeffecttime: longword;

    // °ãÄ¡±â
    Total  : integer;
    NameMakeItem   : string[14];

    // Á¦Á¶
    BoMakeItemMenu : Boolean;
    // À§Å¹ÆÇ¸Å
    MItemSellState : Byte;
    BoInRect : Boolean;
    // Àå¿ø ÂÊÁö
    BoMemoJangwon : Boolean;

    NAHelps: TStringList;
    NewAccountTitle: string;

    DlgEditText: string;
    UserState1: TUserStateInfo;

    Guild: string;
    GuildFlag: string;
    GuildCommanderMode: Boolean;
    GuildStrs: TStringList;
    GuildStrs2: TStringList;
    GuildNotice: TStringList;
    GuildMembers: TStringList;
    GuildTopLine: integer;
    GuildEditHint: string;
    GuildChats: TStringList;
    BoGuildChat: Boolean;

    GABoard_GuildName: string;
    GABoard_UserName : string[14];
    GABoard_TxtBody  : string;
//    GABoard_Edit     : string;
    GABoard_Notice   : TStringList;
    GABoard_MaxPage  : integer;
    GABoard_CurPage  : integer;
    GABoard_BoNotice : integer;
    GABoard_BoWrite  : Byte;
    GABoard_BoReply  : Byte;
    GABoard_IndexType1  : integer;
    GABoard_IndexType2  : integer;
    GABoard_IndexType3  : integer;
    GABoard_IndexType4  : integer;
    GABoard_X, GABoard_Y  : integer;

    ServerSelectIndex: integer;
    ServerSelectAlpha: integer;
    ServerSelectEnabledAlpha: Boolean;
    //Ð¡µØÍ¼µãÉÁË¸
    MiniMapBlinkTime: Longword;
    MiniMapViewBlink: Boolean;

    dwEquipEffectTime: longword;
    nWeaponEffect: integer;

    m_bTypeMagic: Byte;
    m_bMyMagicCnt: Byte;
    m_nStartLineNum: array[0.._MAX_TYPE_MAGIC - 1] of integer;
    m_rcMagicCell: array[0.._MAGIC_MAX_CELL - 1] of TRect;
    m_bMagicKeyTable: array[0.._MAGIC_MAX_KEY - 1] of Byte;
    m_xMagicIconPos: array[0.._MAX_TYPE_MAGIC - 1] of array[0.._MAX_MAGICSLOT - 1] of TMagicIconPos;

    m_nShowMagicNum : integer;
    m_nSelectedMagic: array[0.._MAX_TYPE_MAGIC - 1] of integer;
	  m_bWantSetKey: Boolean;
    m_ptSetKey: TPoint;
    m_rcSetKey: TRect;
    m_nStartPos: integer;
    m_nMaxPos: integer;

    m_nInventoryWndStartLineNum: integer;
    m_shItemSetInfo: array[0.._INVEN_TOTAL_CELL] of Short;

    //ÁÄÌì´°¿Ú
    mChatViewMode: Boolean;

    procedure Initialize;
    procedure OpenMyStatus;
    procedure OpenUserState (ustate: TUserStateInfo);
    procedure OpenItemBag;
    procedure OpenMyMagic;
    procedure ViewBottomBox (visible: Boolean);
    procedure CancelItemMoving;
    procedure DropMovingItem;
    procedure OpenAdjustAbility;

    procedure HideAllControls;
    procedure ShowSelectServerDlg;
    function  DMessageDlg (msgstr: string; DlgButtons: TMsgDlgButtons): TModalResult;
    function  OnlyMessageDlg (msgstr: string; DlgButtons: TMsgDlgButtons): TModalResult;    
    function  DCountMsgDlg (msgstr: string; DlgButtons: TMsgDlgButtons): TModalResult;
    function  MakeItemDlgShow ( msgstr: string ): TModalResult;
    procedure ShowMDlg (face: integer; mname, msgstr: string);
    procedure ShowGuildDlg;
    procedure ShowGuildEditNotice;
    procedure ShowGuildEditGrade;

    procedure ResetMenuDlg;
    procedure ShowShopMenuDlg;
    procedure ShowItemMarketDlg;
    procedure ShowJangwonDlg;
    procedure ShowGADecorateDlg;
    procedure ShowGABoardListDlg;
    procedure ShowGABoardReadDlg;
    procedure SendGABoardOkProg;
    procedure SendGABoardNoticeOk;
    procedure ShowShopSellDlg;
    procedure CloseDSellDlg;
    procedure CloseMDlg;
    procedure CloseMDlg2;    
    procedure CloseItemMarketDlg;
    procedure SafeCloseDlg;

    procedure ToggleShowGroupDlg;
    // 2003/04/15 Ä£±¸, ÂÊÁö
    procedure ToggleShowFriendsDlg;
    procedure ToggleShowMailListDlg;
    procedure ToggleShowBlockListDlg;
    procedure ToggleShowMemoDlg;
    procedure ToggleShowMasterDlg;
    procedure ShowEditMail;
    procedure AddFriend( FriendName : string ; ShowMessage : Boolean);

    procedure OpenDealDlg( DealCase: Byte);
    procedure CloseDealDlg;
    procedure SetChatFocus;
    function  DecoItemDesc(Dura: word; var str: string) : string;

    procedure SoldOutGoods (itemserverindex: integer);
    procedure DelStorageItem (itemserverindex: integer; remain: word);
    procedure GetMouseItemInfo (var iname, line1, line2, line3, line4: string; var useable: boolean; bowear: Boolean);
    procedure SetMagicKeyDlg (icon: integer; magname: string; var curkey: word);
    procedure AddGuildChat (str: string);
    function  ConvertEscChar(str: string) : string;
    procedure  UpgradeItemEffect(wResult : word);
    procedure DGABoardReplyVisibleOk(Index, ReplyCount: Integer; dsurface: TDirectDrawSurface);
  end;

var
  FrmDlg: TFrmDlg;

implementation

uses
   ClMain, HGEFont, uWilFile, HGE, ShellApi, Actor, IntroScn;

{$R *.DFM}

{
   ##  MovingItem.Index
      1~n : °¡¹æÃ¢ÀÇ ¾ÆÀÌÅÛ ¼ø¼­
      -1~-8 : ÀåÂøÃ¢¿¡¼­ÀÇ ¾ÆÀÌÅÛ ¼ø¼­
      -97 : ±³È¯Ã¢ÀÇ µ·
      -98 : µ·
      -99 : ÆÈ±â Ã¢¿¡¼­ÀÇ ¾ÆÀÌÅÛ ¼ø¼­
      -20~29: ±³È¯Ã¢¿¡¼­ÀÇ ¾ÆÀÌÅÛ ¼ø¼­
}

procedure TFrmDlg.FormCreate(Sender: TObject);
begin
   StatePage := 0;
   DlgTemp := TList.Create;
   DialogSize := 1; //±âº» Å©±â
   RunDice := 0;
   DiceType := 1;
   BoDrawDice := FALSE;
   magcur := 0;
   magtop := 0;
   MDlgPoints := TList.Create;
   SelectMenuStr := '';
   MenuList := TList.Create;
   JangwonList := TList.Create;
   GABoardList := TList.Create;
   GADecorationList := TList.Create;
   MenuIndex := -1;
   MenuTopLine := 0;
   BoDetailMenu := FALSE;
   BoStorageMenu := FALSE;
   BoNoDisplayMaxDura := FALSE;
   BoMakeDrugMenu := FALSE;
   BoMakeItemMenu := FALSE;
   BoMemoJangwon  := False;
   NameMakeItem := '';
   MagicPage := 0;
   // 2003/04/15 Ä£±¸, ÂÊÁö
   FriendPage := 0;
   BlackListPage := 0;
   MailPage      := 0;
   BlockPage     := 0;
   CurrentMail   := -1;
   CurrentFriend := -1;
   CurrentBlack  := -1;
   CurrentBlock  := -1;
   ViewFriends   := TRUE;
   ViewWindowNo  := 0;
   ViewWindowData:= 0;

   NAHelps := TStringList.Create;
   BlinkTime := GetTickCount;
   BlinkCount := 0;

   SellDlgItem.S.Name := '';
   Guild := '';
   GuildFlag := '';
   GuildCommanderMode := FALSE;
   GuildStrs := TStringList.Create;
   GuildStrs2 := TStringList.Create; //¹é¾÷¿ë
   GuildNotice := TStringList.Create;
   GABoard_Notice := TStringList.Create;
   GuildMembers := TStringList.Create;
   GuildChats := TStringList.Create;

   EdDlgEdit := TEdit.Create (FrmMain.Owner);
   with EdDlgEdit do begin
      Parent := FrmMain;  Color := clBlack; Font.Color := clWhite; Font.Size := 10; MaxLength := 30;
      Height := 16; Ctl3d := FALSE;
      BorderStyle := bsNone;  {OnKeyPress := EdDlgEditKeyPress;}  Visible := FALSE;
   end;

   EdCountEdit := TEdit.Create (FrmMain.Owner);
   with EdCountEdit do begin
      Parent := FrmMain;  Color := clBlack; Font.Color := clWhite; Font.Size := 10; MaxLength := 20;
      Height := 16; Ctl3d := FALSE;
      BorderStyle := bsSingle;   Visible := False;
   end;

   ItemSearchEdit := TEdit.Create (FrmMain.Owner);
   with ItemSearchEdit do begin
      Parent := FrmMain;  Color := clBlack; Font.Color := clWhite; Font.Size := 10; MaxLength := 20;
      Height := 16; Ctl3d := FALSE;
      BorderStyle := bsSingle;   Visible := False;
   end;

   Memo := TMemo.Create (FrmMain.Owner);
   with Memo do begin
      Parent := FrmMain;  Color := clBlack; Font.Color := clWhite; Font.Size := 10;
      Ctl3d := FALSE;
      BorderStyle := bsSingle;  {OnKeyPress := EdDlgEditKeyPress;}  Visible := FALSE;
   end;

   // 2003/04/15 Ä£±¸, ÂÊÁö
   edCharID := TEdit.Create (FrmMain.Owner);
   with edCharID do begin
      Parent := FrmMain;  Color := clBlack; Font.Color := clWhite; Font.Size := 10; MaxLength := 14;
      Height := 16; Ctl3d := FALSE;
      BorderStyle := bsSingle;  {OnKeyPress := EdDlgEditKeyPress;}  Visible := FALSE;
   end;

   memoMail := TMemo.Create (FrmMain.Owner);
   with memoMail do begin
      Parent := FrmMain;  Color := clBlack; Font.Color := clWhite; Font.Size := 10; MaxLength := 80;
      Ctl3d := FALSE;
      BorderStyle := bsSingle;  {OnKeyPress := EdDlgEditKeyPress;}  Visible := FALSE;
   end;

  ServerSelectIndex := -1;
  ServerSelectAlpha := 100;
  ServerSelectEnabledAlpha := False;
  MiniMapBlinkTime := GetTickCount;
  MiniMapViewBlink := False;

  dwEquipEffectTime := GetTickCount;
  nWeaponEffect := 0;

  FillChar(m_xMagicIconPos, sizeof(TMagicIconPos) * _MAX_TYPE_MAGIC * _MAX_MAGICSLOT, #0);
end;

procedure TFrmDlg.FormDestroy(Sender: TObject);
begin
   DlgTemp.Free;
   MDlgPoints.Free;  //°£´ÜÈ÷..
   MenuList.Free;
   JangwonList.Free;
   GABoardList.Free;
   GADecorationList.Free;
   NAHelps.Free;
   GuildStrs.Free;
   GuildStrs2.Free;
   GuildNotice.Free;
   GABoard_Notice.Free;
   GuildMembers.Free;
   GuildChats.Free; 
end;

procedure TFrmDlg.HideAllControls;
var
   i: integer;
   c: TControl;
begin
   DlgTemp.Clear;
   with FrmMain do
      for i:=0 to ControlCount-1 do begin
         c := Controls[i];
         if c is TEdit then
            if (c.Visible) and (c <> EdDlgEdit) then begin
               DlgTemp.Add (c);
               c.Visible := FALSE;
            end;
      end;
end;

procedure TFrmDlg.RestoreHideControls;
var
   i: integer;
   c: TControl;
begin
   for i:=0 to DlgTemp.Count-1 do begin
      TControl(DlgTemp[i]).Visible := TRUE;
   end;
end;

procedure TFrmDlg.Initialize;  //°ÔÀÓÀ» ¸®½ºÅä¾îÇÒ¶§¸¶´Ù È£ÃâµÊ
var
   nCnt, i, dsrvtop, dsrvheight: integer;
   lx, ly : integer;
   d: TDirectDrawSurface;
begin
   g_DWinMan.ClearAll;

   DBackground.Left := 0;
   DBackground.Top := 0;
   DBackground.Width := SCREENWIDTH;
   DBackground.Height := SCREENHEIGHT;
   DBackground.Background := TRUE;
   g_DWinMan.AddDControl (DBackground, TRUE);

   {-----------------------------------------------------------}

   //¸Þ¼¼Áö ´ÙÀÌ¾ó·Î±× Ã¢
   d := g_WGameInter.Images[1240];
   if d <> nil then begin
      DMsgDlg.SetImgIndex (g_WGameInter, 1240);
      DMsgDlg.Left := (SCREENWIDTH - d.Width) div 2;
      DMsgDlg.Top := (SCREENHEIGHT - d.Height) div 2;
   end;
   DMsgDlgOk.SetImgIndex (g_WGameInter, 1241);
   DMsgDlgYes.SetImgIndex (g_WGameInter, 1241);
   DMsgDlgNo.SetImgIndex (g_WGameInter, 1245);

   DMsgDlgCancel.SetImgIndex (g_WGameInter, 1245);

   DMsgDlgOk.Top := 190;
   DMsgDlgYes.Top := 190;
   DMsgDlgCancel.Top := 190;
   DMsgDlgNo.Top := 190;

   {-----------------------------------------------------------}

   // Ä«¿îÆ® ´ÙÀÌ¾ó·Î±× Ã¢
   d := g_WProgUse.Images[660];
   if d <> nil then begin
      DCountDlg.SetImgIndex (g_WProgUse, 660);
      DCountDlg.Left := (SCREENWIDTH - d.Width) div 2;
      DCountDlg.Top := (SCREENHEIGHT - d.Height) div 2;
   end;
   DCountDlgMax.SetImgIndex (g_WProgUse, 654);
   DCountDlgOk.SetImgIndex (g_WProgUse, 650);
   DCountDlgCancel.SetImgIndex (g_WProgUse, 652);
   DCountDlgClose.SetImgIndex (g_WProgUse, 86);

   {-----------------------------------------------------------}
   // Á¦Á¶ ´ÙÀÌ¾ó·Î±× Ã¢
   d := g_WProgUse.Images[661];
   if d <> nil then begin
      DMakeItemDlg.SetImgIndex (g_WProgUse, 661);
      DMakeItemDlg.Left := (SCREENWIDTH - d.Width) div 2;
      DMakeItemDlg.Top := (SCREENHEIGHT - d.Height) div 2;
   end;

   DMakeitemGrid.Left := 29;
   DMakeitemGrid.Top  := 28;
   DMakeitemGrid.Width := 224;//240;//286;
   DMakeitemGrid.Height := 34;//40;//80;

//   lx := 163;//234;
//   ly := 109;//141;

   DMakeItemDlgCancel.SetImgIndex (g_WProgUse, 652);
   DMakeItemDlgCancel.Left := 138;//lx;
   DMakeItemDlgCancel.Top  := 126;//ly;
   DMakeItemDlgCancel.Visible := True;
//   lx := lx - 70;

   DMakeItemDlgOk.SetImgIndex (g_WProgUse, 650);
   DMakeItemDlgOk.Left := 66;//lx;
   DMakeItemDlgOk.Top  := 126;//ly;
   DMakeItemDlgOk.Visible := True;


   DMakeItemDlgClose.SetImgIndex (g_WProgUse, 86);
   DMakeItemDlgClose.Left := 242;//319;
   DMakeItemDlgClose.Top  := 5;
   DMakeItemDlgClose.Visible := True;

   DMakeItemDlg.Floating := True;

   {-----------------------------------------------------------}
   //º§Æ®Ã¢ 2006/03/27
//   if BeltType = 1 then begin
      DBeltWin.SetImgIndex (g_WGameInter, 1210);
      DBeltWin.Left   := - 50;
      DBeltWin.Top    := SCREENHEIGHT - 195;
//      DTurnBelt.SetImgIndex (g_WProgUse, 81);
//      DTurnBelt.Left  := 239;
//      DTurnBelt.Top   := 1;
      DCloseBelt.SetImgIndex (g_WGameInter, 1211);
      DCloseBelt.Left := 379;
      DCloseBelt.Top  := 40;

      DBelt1.Left := 132;
      DBelt1.Width := 35;
      DBelt1.Top := 15;
      DBelt1.Height := 35;

      DBelt2.Left := DBelt1.Left + 43;
      DBelt2.Width := 35;
      DBelt2.Top := 15;
      DBelt2.Height := 35;

      DBelt3.Left := DBelt2.Left + 43;
      DBelt3.Width := 35;
      DBelt3.Top := 15;
      DBelt3.Height := 35;

      DBelt4.Left := DBelt3.Left + 43;
      DBelt4.Width := 35;
      DBelt4.Top := 15;
      DBelt4.Height := 35;

      DBelt5.Left := DBelt4.Left + 43;
      DBelt5.Width := 35;
      DBelt5.Top := 15;
      DBelt5.Height := 35;

      DBelt6.Left := DBelt5.Left + 43;
      DBelt6.Width := 35;
      DBelt6.Top := 15;
      DBelt6.Height := 35;
//   end
//   else begin
//      DBeltWin.SetImgIndex (g_WProgUse, 83);
//      DBeltWin.Left   := 0;
//      DBeltWin.Top    := 140;
//      DTurnBelt.SetImgIndex (g_WProgUse, 84);
//      DTurnBelt.Left  := 20;
//      DTurnBelt.Top   := 239;
//      DCloseBelt.SetImgIndex (g_WProgUse, 85);
//      DCloseBelt.Left := 1;
//      DCloseBelt.Top  := 239;
//
//      DBelt1.Left := 5;    DBelt1.Width  := 32;
//      DBelt1.Top  := 19;   DBelt1.Height := 34;
//      DBelt2.Left := 5;    DBelt2.Width  := 32;
//      DBelt2.Top  := 56;   DBelt2.Height := 34;
//      DBelt3.Left := 5;    DBelt3.Width  := 32;
//      DBelt3.Top  := 92;   DBelt3.Height := 34;
//      DBelt4.Left := 5;    DBelt4.Width  := 32;
//      DBelt4.Top  := 128;  DBelt4.Height := 34;
//      DBelt5.Left := 5;    DBelt5.Width  := 32;
//      DBelt5.Top  := 165;  DBelt5.Height := 34;
//      DBelt6.Left := 5;    DBelt6.Width  := 32;
//      DBelt6.Top  := 200;  DBelt6.Height := 34;
//   end;

   {-----------------------------------------------------------}
   //·Î±×ÀÎ Ã¢
   d := g_WInterface1c.Images[1];
   if d <> nil then begin
      DLogIn.SetImgIndex (g_WInterface1c, 1);
      DLogIn.Left := (640 - d.Width) div 2;
      DLogIn.Top := 420 - d.Height;
   end;

  DLoginOk.SetImgIndex (g_WInterface1c, 10);
  DLoginOk.Left := 460;//169;
  DLoginOk.Top := 65;//164;
  DLoginNew.SetImgIndex (g_WInterface1c, 12);
  DLoginNew.Left := 140;//25;
  DLoginNew.Top  := 10;//207;
  DLoginChgPw.SetImgIndex (g_WInterface1c, 14);
  DLoginChgPw.Left := 280;//130;
  DLoginChgPw.Top  := 10;//207;
  DLoginClose.SetImgIndex (g_WInterface1c, 16);//64);
  DLoginClose.Left := 440;//252;
  DLoginClose.Top := 10;//28;


   {-----------------------------------------------------------}


      DEngServer1.Visible := FALSE;

      DSServer1.Visible := FALSE;
      DSServer2.Visible := FALSE;
      DSServer3.Visible := FALSE;
      DSServer4.Visible := FALSE;
      DSServer5.Visible := FALSE;
      DSServer6.Visible := FALSE;
      DSServer7.Visible := FALSE;
      DSServer8.Visible := FALSE;

      DSServer9.Visible := FALSE;
      DSServer10.Visible := FALSE;
      DSServer11.Visible := FALSE;
      DSServer12.Visible := FALSE;
      DSServer13.Visible := FALSE;
      DSServer14.Visible := FALSE;
      DSServer15.Visible := FALSE;
      DSServer16.Visible := FALSE;

      DSServer17.Visible := FALSE;
      DSServer18.Visible := FALSE;
      DSServer19.Visible := FALSE;
      DSServer20.Visible := FALSE;
      DSServer21.Visible := FALSE;
      DSServer22.Visible := FALSE;
      DSServer23.Visible := FALSE;
      DSServer24.Visible := FALSE;

      DSServer25.Visible := FALSE;
      DSServer26.Visible := FALSE;
      DSServer27.Visible := FALSE;
      DSServer28.Visible := FALSE;

//      if ServerCount >= 1 then DSServer1.Visible := TRUE;
//      if ServerCount >= 2 then DSServer2.Visible := TRUE;
//      if ServerCount >= 3 then DSServer3.Visible := TRUE;
//      if ServerCount >= 4 then DSServer4.Visible := TRUE;
//      if ServerCount >= 5 then DSServer5.Visible := TRUE;
//      if ServerCount >= 6 then DSServer6.Visible := TRUE;
//      if ServerCount >= 7 then DSServer7.Visible := TRUE;
//      if ServerCount >= 8 then DSServer8.Visible := TRUE;
//
//      if ServerCount >= 9 then DSServer9.Visible := TRUE;
//      if ServerCount >= 10 then DSServer10.Visible := TRUE;
//      if ServerCount >= 11 then DSServer11.Visible := TRUE;
//      if ServerCount >= 12 then DSServer12.Visible := TRUE;
//      if ServerCount >= 13 then DSServer13.Visible := TRUE;
//      if ServerCount >= 14 then DSServer14.Visible := TRUE;
//      if ServerCount >= 15 then DSServer15.Visible := TRUE;
//      if ServerCount >= 16 then DSServer16.Visible := TRUE;
//
//      if ServerCount >= 17 then DSServer17.Visible := TRUE;
//      if ServerCount >= 18 then DSServer18.Visible := TRUE;
//      if ServerCount >= 19 then DSServer19.Visible := TRUE;
//      if ServerCount >= 20 then DSServer20.Visible := TRUE;
//      if ServerCount >= 21 then DSServer21.Visible := TRUE;
//      if ServerCount >= 22 then DSServer22.Visible := TRUE;
//      if ServerCount >= 23 then DSServer23.Visible := TRUE;
//      if ServerCount >= 24 then DSServer24.Visible := TRUE;
//
//      if ServerCount >= 25 then DSServer25.Visible := TRUE;
//      if ServerCount >= 26 then DSServer26.Visible := TRUE;
//      if ServerCount >= 27 then DSServer27.Visible := TRUE;
//      if ServerCount >= 28 then DSServer28.Visible := TRUE;

      DSelServerDlg.Left := 20;
      DSelServerDlg.Top := 60;
      DSelServerDlg.Width := 130;
      DSelServerDlg.Height := 20 + (30 * ServerCount);

   (*   if ServerCount <= 8 then begin
         dsrvheight := 25;//42;
//         dsrvtop := 235 - (dsrvheight * ServerCount) div 2;
         dsrvtop := 10;

         d := g_WProgUse.Images[256];  //2];
         if d <> nil then begin
            DSelServerDlg.SetImgIndex (g_WProgUse, 256);
            DSelServerDlg.Left := 20;
            DSelServerDlg.Top := 60;
         end;
         DSSrvClose.SetImgIndex (g_WProgUse, 41);//64);
         DSSrvClose.Left := 100;//244;
         DSSrvClose.Top := 481;//30;

         DSServer1.SetImgIndex (g_WProgUse2, 2); //82);
         DSServer1.Left := 0;
         DSServer1.Top  := dsrvtop + 0 * dsrvheight; //102;

         DSServer2.SetImgIndex (g_WProgUse2, 2); //82);
         DSServer2.Left := 0;
         DSServer2.Top  := dsrvtop + 1 * dsrvheight; //102;

         DSServer3.SetImgIndex (g_WProgUse2, 2); //82);
         DSServer3.Left := 37;
         DSServer3.Top  := dsrvtop + 2 * dsrvheight; //102;

         DSServer4.SetImgIndex (g_WProgUse2, 2); //82);
         DSServer4.Left := 37;
         DSServer4.Top  := dsrvtop + 3 * dsrvheight; //102;

         DSServer5.SetImgIndex (g_WProgUse2, 2); //82);
         DSServer5.Left := 37;
         DSServer5.Top  := dsrvtop + 4 * dsrvheight; //102;

         DSServer6.SetImgIndex (g_WProgUse2, 2); //82);
         DSServer6.Left := 37;
         DSServer6.Top  := dsrvtop + 5 * dsrvheight; //102;

         DSServer7.SetImgIndex (g_WProgUse2, 2); //82);
         DSServer7.Left := 37;
         DSServer7.Top  := dsrvtop + 6 * dsrvheight; //102;

         DSServer8.SetImgIndex (g_WProgUse2, 2); //82);
         DSServer8.Left := 37;
         DSServer8.Top  := dsrvtop + 7 * dsrvheight; //102;
      end;

      if (ServerCount > 8) and (ServerCount <= 16) then begin
         dsrvheight := 42;
         dsrvtop := 235 - (dsrvheight * 16{ServerCount} div 2) div 2;

         d := g_WProgUse2.Images[4];
         if d <> nil then begin
            DSelServerDlg.SetImgIndex (g_WProgUse2, 4);
            DSelServerDlg.Left := (SCREENWIDTH - d.Width) div 2;
            DSelServerDlg.Top := (SCREENHEIGHT - d.Height) div 2;
         end;
         DSSrvClose.SetImgIndex (g_WProgUse, 41);//64);
         DSSrvClose.Left := 100;//244;
         DSSrvClose.Top := 481;//30;


         DSServer1.SetImgIndex (g_WProgUse2, 2); //82);
         DSServer1.Left := 25;
         DSServer1.Top  := dsrvtop + 0 * dsrvheight; //102;

         DSServer2.SetImgIndex (g_WProgUse2, 2); //82);
         DSServer2.Left := 25;
         DSServer2.Top  := dsrvtop + 1 * dsrvheight; //102;

         DSServer3.SetImgIndex (g_WProgUse2, 2); //82);
         DSServer3.Left := 25;
         DSServer3.Top  := dsrvtop + 2 * dsrvheight; //102;

         DSServer4.SetImgIndex (g_WProgUse2, 2); //82);
         DSServer4.Left := 25;
         DSServer4.Top  := dsrvtop + 3 * dsrvheight; //102;

         DSServer5.SetImgIndex (g_WProgUse2, 2); //82);
         DSServer5.Left := 25;
         DSServer5.Top  := dsrvtop + 4 * dsrvheight; //102;

         DSServer6.SetImgIndex (g_WProgUse2, 2); //82);
         DSServer6.Left := 25;
         DSServer6.Top  := dsrvtop + 5 * dsrvheight; //102;

         DSServer7.SetImgIndex (g_WProgUse2, 2); //82);
         DSServer7.Left := 25;
         DSServer7.Top  := dsrvtop + 6 * dsrvheight; //102;

         DSServer8.SetImgIndex (g_WProgUse2, 2); //82);
         DSServer8.Left := 25;
         DSServer8.Top  := dsrvtop + 7 * dsrvheight; //102;

         DSServer9.SetImgIndex (g_WProgUse2, 2); //82);
         DSServer9.Left := 195;
         DSServer9.Top  := dsrvtop + 0 * dsrvheight; //102;

         DSServer10.SetImgIndex (g_WProgUse2, 2); //82);
         DSServer10.Left := 195;
         DSServer10.Top  := dsrvtop + 1 * dsrvheight; //102;

         DSServer11.SetImgIndex (g_WProgUse2, 2); //82);
         DSServer11.Left := 195;
         DSServer11.Top  := dsrvtop + 2 * dsrvheight; //102;

         DSServer12.SetImgIndex (g_WProgUse2, 2); //82);
         DSServer12.Left := 195;
         DSServer12.Top  := dsrvtop + 3 * dsrvheight; //102;

         DSServer13.SetImgIndex (g_WProgUse2, 2); //82);
         DSServer13.Left := 195;
         DSServer13.Top  := dsrvtop + 4 * dsrvheight; //102;

         DSServer14.SetImgIndex (g_WProgUse2, 2); //82);
         DSServer14.Left := 195;
         DSServer14.Top  := dsrvtop + 5 * dsrvheight; //102;

         DSServer15.SetImgIndex (g_WProgUse2, 2); //82);
         DSServer15.Left := 195;
         DSServer15.Top  := dsrvtop + 6 * dsrvheight; //102;

         DSServer16.SetImgIndex (g_WProgUse2, 2); //82);
         DSServer16.Left := 195;
         DSServer16.Top  := dsrvtop + 7 * dsrvheight; //102;

      end;

      if (ServerCount > 16) then begin // and (ServerCount <= 24) then begin
         dsrvheight := 42;
         dsrvtop := 235 - (dsrvheight * 8) div 2;

         d := g_WProgUse2.Images[5];
         if d <> nil then begin
            DSelServerDlg.SetImgIndex (g_WProgUse2, 5);
            DSelServerDlg.Left := (SCREENWIDTH - d.Width) div 2;
            DSelServerDlg.Top := (SCREENHEIGHT - d.Height) div 2;
         end;
         DSSrvClose.SetImgIndex (g_WProgUse, 41);//64);
         DSSrvClose.Left := 100;//244;
         DSSrvClose.Top := 481;//30;

         DSServer1.SetImgIndex (g_WProgUse2, 2); //82);
         DSServer1.Left := 25;
         DSServer1.Top  := dsrvtop + 0 * dsrvheight; //102;

         DSServer2.SetImgIndex (g_WProgUse2, 2); //82);
         DSServer2.Left := 25;
         DSServer2.Top  := dsrvtop + 1 * dsrvheight; //102;

         DSServer3.SetImgIndex (g_WProgUse2, 2); //82);
         DSServer3.Left := 25;
         DSServer3.Top  := dsrvtop + 2 * dsrvheight; //102;

         DSServer4.SetImgIndex (g_WProgUse2, 2); //82);
         DSServer4.Left := 25;
         DSServer4.Top  := dsrvtop + 3 * dsrvheight; //102;

         DSServer5.SetImgIndex (g_WProgUse2, 2); //82);
         DSServer5.Left := 25;
         DSServer5.Top  := dsrvtop + 4 * dsrvheight; //102;

         DSServer6.SetImgIndex (g_WProgUse2, 2); //82);
         DSServer6.Left := 25;
         DSServer6.Top  := dsrvtop + 5 * dsrvheight; //102;

         DSServer7.SetImgIndex (g_WProgUse2, 2); //82);
         DSServer7.Left := 25;
         DSServer7.Top  := dsrvtop + 6 * dsrvheight; //102;

         DSServer8.SetImgIndex (g_WProgUse2, 2); //82);
         DSServer8.Left := 25;
         DSServer8.Top  := dsrvtop + 7 * dsrvheight; //102;

         DSServer9.SetImgIndex (g_WProgUse2, 2); //82);
         DSServer9.Left := 195;
         DSServer9.Top  := dsrvtop + 0 * dsrvheight; //102;

         DSServer10.SetImgIndex (g_WProgUse2, 2); //82);
         DSServer10.Left := 195;
         DSServer10.Top  := dsrvtop + 1 * dsrvheight; //102;

         DSServer11.SetImgIndex (g_WProgUse2, 2); //82);
         DSServer11.Left := 195;
         DSServer11.Top  := dsrvtop + 2 * dsrvheight; //102;

         DSServer12.SetImgIndex (g_WProgUse2, 2); //82);
         DSServer12.Left := 195;
         DSServer12.Top  := dsrvtop + 3 * dsrvheight; //102;

         DSServer13.SetImgIndex (g_WProgUse2, 2); //82);
         DSServer13.Left := 195;
         DSServer13.Top  := dsrvtop + 4 * dsrvheight; //102;

         DSServer14.SetImgIndex (g_WProgUse2, 2); //82);
         DSServer14.Left := 195;
         DSServer14.Top  := dsrvtop + 5 * dsrvheight; //102;

         DSServer15.SetImgIndex (g_WProgUse2, 2); //82);
         DSServer15.Left := 195;
         DSServer15.Top  := dsrvtop + 6 * dsrvheight; //102;

         DSServer16.SetImgIndex (g_WProgUse2, 2); //82);
         DSServer16.Left := 195;
         DSServer16.Top  := dsrvtop + 7 * dsrvheight; //102;

         DSServer17.SetImgIndex (g_WProgUse2, 2); //82);
         DSServer17.Left := 365;
         DSServer17.Top  := dsrvtop + 0 * dsrvheight; //102;

         DSServer18.SetImgIndex (g_WProgUse2, 2); //82);
         DSServer18.Left := 365;
         DSServer18.Top  := dsrvtop + 1 * dsrvheight; //102;

         DSServer19.SetImgIndex (g_WProgUse2, 2); //82);
         DSServer19.Left := 365;
         DSServer19.Top  := dsrvtop + 2 * dsrvheight; //102;

         DSServer20.SetImgIndex (g_WProgUse2, 2); //82);
         DSServer20.Left := 365;
         DSServer20.Top  := dsrvtop + 3 * dsrvheight; //102;

         DSServer21.SetImgIndex (g_WProgUse2, 2); //82);
         DSServer21.Left := 365;
         DSServer21.Top  := dsrvtop + 4 * dsrvheight; //102;

         DSServer22.SetImgIndex (g_WProgUse2, 2); //82);
         DSServer22.Left := 365;
         DSServer22.Top  := dsrvtop + 5 * dsrvheight; //102;

         DSServer23.SetImgIndex (g_WProgUse2, 2); //82);
         DSServer23.Left := 365;
         DSServer23.Top  := dsrvtop + 6 * dsrvheight; //102;

         DSServer24.SetImgIndex (g_WProgUse2, 2); //82);
         DSServer24.Left := 365;
         DSServer24.Top  := dsrvtop + 7 * dsrvheight; //102;

      end;    *)

  {-----------------------------------------------------------}

  DSelectChr.Left := 0;
  DSelectChr.Top := 0;
  DSelectChr.Width := SCREENWIDTH;
  DSelectChr.Height := SCREENHEIGHT;


  DscNewChr.SetImgIndex (g_WInterface1c, 52);
  DscEraseChr.SetImgIndex (g_WInterface1c, 54);
  DscStart.SetImgIndex (g_WInterface1c, 56);
  DscExit.SetImgIndex (g_WInterface1c, 58);
  DscNewChr.Left := 440;
  DscNewChr.Top := 93;
  DscEraseChr.Left := 79;
  DscEraseChr.Top := 243;
  DscStart.Left := 259;
  DscStart.Top := 49;
  DscExit.Left := 28;
  DscExit.Top := 438;

   {-----------------------------------------------------------}

   //»õ Ä³¸¯ÅÍ ¸¸µé±â Ã¢
//   d := g_WProgUse.Images[73];
//   if d <> nil then begin
//      DCreateChr.SetImgIndex (g_WProgUse, 73);
//      DCreateChr.Left := 0;
//      DCreateChr.Top := 0;//(SCREENHEIGHT - d.Height) div 2;
//   end;
   //DccReserved.SetImgIndex (g_WProgUse.Images[76], TRUE);
   DccMale.SetImgIndex (g_WProgUse, 58);
   DccFemale.SetImgIndex (g_WProgUse, 59);
//   DccLeftHair.SetImgIndex (g_WProgUse, 79);
//   DccRightHair.SetImgIndex (g_WProgUse, 80);
  DCreateChr.Left := 0;
  DCreateChr.Top := 0;
  DCreateChr.Width := SCREENWIDTH;
  DCreateChr.Height := SCREENHEIGHT;
  DccOk.SetImgIndex (g_WInterface1c, 85);
  DccClose.SetImgIndex (g_WInterface1c, 88);
  DccOk.Left := 450;
  DccOk.Top := 444;
  DccClose.Left := 491;
  DccClose.Top := 444;
  DccWarrior.SetImgIndex (g_WInterface1c, 91);
  DccWizzard.SetImgIndex (g_WInterface1c, 94);
  DccMonk.SetImgIndex (g_WInterface1c, 97);
  DccWarrior.Left := 260+6;
  DccWarrior.Top := 422;
  DccWizzard.Left := 296+13;
  DccWizzard.Top := 422;
  DccMonk.Left := 332+20;
  DccMonk.Top := 422;
      //DccReserved.Left := 502;
      //DccReserved.Top := 408;
      DccMale.Left := 407;
      DccMale.Top := 297;
      DccFemale.Left := 454;
      DccFemale.Top := 297;
//      DccLeftHair.Left := 76;
//      DccLeftHair.Top := 308;
//      DccRightHair.Left := 170;
//      DccRightHair.Top := 308;



   {-----------------------------------------------------------}

  d := g_WGameInter.Images[1280]; //81];
  if d <> nil then begin
    DStateWin.SetImgIndex(g_WGameInter, 1280);
    DStateWin.Left := 0 - (d.Width - 328) div 2;
    DStateWin.Top := 0 - (d.Height - 466) div 2;
  end;
  DCloseState.SetImgIndex (g_WGameInter, 1221);
  DCloseState.Left := 380;
  DCloseState.Top := 36;

  DSWNecklace.Left := 259;
  DSWNecklace.Top := 110;
  DSWNecklace.Width := 40;
  DSWNecklace.Height := 40;
  DSWHelmet.Left := 110 + 77;
  DSWHelmet.Top := 52 + 41;
  DSWHelmet.Width := 18;
  DSWHelmet.Height := 18;

  DSWArmRingR.Left := 259;
  DSWArmRingR.Top := 177;
  DSWArmRingR.Width := 40;
  DSWArmRingR.Height := 40;
  DSWArmRingL.Left := 101;
  DSWArmRingL.Top := 177;
  DSWArmRingL.Width := 40;
  DSWArmRingL.Height := 40;
  DSWRingR.Left := 101;
  DSWRingR.Top := 217;
  DSWRingR.Width := 40;
  DSWRingR.Height := 40;
  DSWRingL.Left := 259;
  DSWRingL.Top := 217;
  DSWRingL.Width := 40;
  DSWRingL.Height := 40;
  DSWWeapon.Left := 98 + 22;
  DSWWeapon.Top := 52 + 28;
  DSWWeapon.Width := 47;
  DSWWeapon.Height := 87;
  DSWDress.Left := 118 + 58;
  DSWDress.Top := 52 + 80;
  DSWDress.Width := 53;
  DSWDress.Height := 112;
  DSWLight.Left := 145;                 //À¯Öò
  DSWLight.Top := 287;
  DSWLight.Width := 40;
  DSWLight.Height := 40;

  DSWBujuk.Left := 186;                 //·û
  DSWBujuk.Top := 287;
  DSWBujuk.Width := 40;
  DSWBujuk.Height := 40;

  DSWBelt.Left := 225;                  //Ñ«ÕÂÀà
  DSWBelt.Top := 287;
  DSWBelt.Width := 40;
  DSWBelt.Height := 40;

  DSWBoots.Left := 101;                 //Ð¬
  DSWBoots.Top := 257;
  DSWBoots.Width := 40;
  DSWBoots.Height := 70;

  DSWCharm.Left := 265;                 //±¦Ê¯
  DSWCharm.Top := 287;
  DSWCharm.Width := 40;
  DSWCharm.Height := 40;

//      DStMag1.Left := 38 + 8-2;
//      DStMag1.Top := 80 + 7;    DStMag1.Width := 31;  DStMag1.Height := 33;
//      DStMag2.Left := 38 + 8-2;
//      DStMag2.Top := 80 + 44;   DStMag2.Width := 31;  DStMag2.Height := 33;
//      DStMag3.Left := 38 + 8-2;
//      DStMag3.Top := 80 + 81;   DStMag3.Width := 31;  DStMag3.Height := 33;
//      DStMag4.Left := 38 + 8-2;
//      DStMag4.Top := 80 + 118;  DStMag4.Width := 31;  DStMag4.Height := 33;
//      DStMag5.Left := 38 + 8-2;
//      DStMag5.Top := 80 + 156;  DStMag5.Width := 31;  DStMag5.Height := 33;
//
//      DStPageUp.SetImgIndex (g_WProgUse, 398);
//      DStPageDown.SetImgIndex (g_WProgUse, 396);
//      DStPageUp.Left := 217;
//      DStPageUp.Top  := 144;
//      DStPageDown.Left := 217;
//      DStPageDown.Top  := 178;

//   DPrevState.SetImgIndex (g_WProgUse, 373);
//   DNextState.SetImgIndex (g_WProgUse, 372);
//   DPrevState.Left := 5;
//   DPrevState.Top := 138;
//   DNextState.Left := 5;
//   DNextState.Top := 197;
//   DHeartImg.SetImgIndex (g_WProgUse, 604);

   {-----------------------------------------------------------}
   //»óÅÂÃ¢  (´Ù¸¥»ç¶÷¿ë)
  d := g_WGameInter.Images[1288];  //»óÅÂ
  if d <> nil then begin
    DUserState1.SetImgIndex (g_WGameInter, 1288);
    DUserState1.Left := SCREENWIDTH - 398;
    DUserState1.Top := -81;
  end;
  DCloseUS1.SetImgIndex (g_WGameInter, 1176);
  DCloseUS1.Left := 367;
  DCloseUS1.Top := 397;
  DNecklaceUS1.Left := 336 {259};
  DNecklaceUS1.Top := 174 {110};
  DNecklaceUS1.Width := 40;
  DNecklaceUS1.Height := 40;
  DHelmetUS1.Left := 110 + 77;
  DHelmetUS1.Top := 52 + 41;
  DHelmetUS1.Width := 18;
  DHelmetUS1.Height := 18;
  DArmringRUS1.Left := 133;
  DArmringRUS1.Top := 265;
  DArmringRUS1.Width := 40;
  DArmringRUS1.Height := 40;
  DArmringLUS1.Left := 336;
  DArmringLUS1.Top := 265;
  DArmringLUS1.Width := 40;
  DArmringLUS1.Height := 40;
  DRingRUS1.Left := 133;
  DRingRUS1.Top := 305;
  DRingRUS1.Width := 40;
  DRingRUS1.Height := 40;
  DRingLUS1.Left := 336;
  DRingLUS1.Top := 305;
  DRingLUS1.Width := 40;
  DRingLUS1.Height := 40;
  DWeaponUS1.Left := 185;
  DWeaponUS1.Top := 160;
  DWeaponUS1.Width := 47;
  DWeaponUS1.Height := 87;
  DDressUS1.Left := 118 + 58 + 65;
  DDressUS1.Top := 52 + 160;
  DDressUS1.Width := 53;
  DDressUS1.Height := 112;
  DLightUS1.Left := 214 {179};
  DLightUS1.Top := 373 {287};
  DLightUS1.Width := 40;
  DLightUS1.Height := 40;
  DBujukUS1.Left := 254;                //·û
  DBujukUS1.Top := 373;
  DBujukUS1.Width := 40;
  DBujukUS1.Height := 40;
  DBeltUS1.Left := 294;
  DBeltUS1.Top := 373;
  DBeltUS1.Width := 40;
  DBeltUS1.Height := 40;
  DBootsUS1.Left := 133;
  DBootsUS1.Top := 345;
  DBootsUS1.Width := 40;
  DBootsUS1.Height := 70;
  DCharmUS1.Left := 334;
  DCharmUS1.Top := 373;
  DCharmUS1.Width := 40;
  DCharmUS1.Height := 40;
  DHeartImgUS.SetImgIndex (g_WProgUse, 604);

   DChGroup.SetImgIndex  (g_WProgUse, 431);
   DChGroup.Left := 71;//52;
   DChGroup.Top  := 303;//298;
   DChFriend.SetImgIndex (g_WProgUse, 432);
   DChFriend.Left := 104;//103;
   DChFriend.Top  := 303;
   DChMemo.SetImgIndex   (g_WProgUse, 433);
   DChMemo.Left := 137;//153;
   DChMemo.Top  := 303;

  {-------------------------------------------------------------}

  //°ü¸¤
  d := g_WGameInter.Images[1220];
  if d <> nil then begin
    DItemBag.SetImgIndex(g_WGameInter, 1220);
    DItemBag.Left := 518 - (d.Width - 283) div 2;
    DItemBag.Top := 0 - (d.Height - 466) div 2;
  end;
  DItemGrid.Left := 133;
  DItemGrid.Top := 81;
  DItemGrid.Width := 228;
  DItemGrid.Height := 304;
  DCloseBag.SetImgIndex(g_WGameInter, 1222);
  DCloseBag.Left := 356;
  DCloseBag.Top := 445;

  DShowMap.SetImgIndex(g_WGameInter, 1232);
  DShowMap.Left := 337;
  DShowMap.Top := 36;

  DGold.Left := 131;
  DGold.Top := 412;
  DGold.Width := 36;
  DGold.Height := 24;

  m_nInventoryWndStartLineNum	:= 0;

//   DRepairItem.SetImgIndex (g_WProgUse, 26);
//   DRepairItem.Left := 254;
//   DRepairItem.Top := 183;
//   DRepairItem.Width := 48;
//   DRepairItem.Height := 22;
   {-----------------------------------------------------------}

   BoUpItemEffect := FALSE;
   {-----------------------------------------------------------}


  d := g_WGameInter.Images[1620];
  if d <> nil then begin
    DMagicWnd.SetImgIndex(g_WGameInter, 1620);
    DMagicWnd.Left := 0;//(SCREENWIDTH - d.Width) div 2;
    DMagicWnd.Top := 0;//(SCREENHEIGHT - d.Height) div 2;
  end;
  DMagicWndScrollBar.SetImgIndex(g_WGameInter, 1672);
  DMagicWndScrollBar.Left := 322+76;
  DMagicWndScrollBar.Top := 113;
  DCloseMagic.SetImgIndex(g_WGameInter, 1221);
  DCloseMagic.Left := 392;
  DCloseMagic.Top := 434;
  DMagicType0.SetImgIndex(g_WGameInter, 1640);
  DMagicType0.Left := 121;
  DMagicType0.Top := 42;
  DMagicType1.SetImgIndex(g_WGameInter, 1642);
  DMagicType1.Left := 155;
  DMagicType1.Top := 42;
  DMagicType2.SetImgIndex(g_WGameInter, 1644);
  DMagicType2.Left := 189;
  DMagicType2.Top := 42;
  DMagicType3.SetImgIndex(g_WGameInter, 1646);
  DMagicType3.Left := 223;
  DMagicType3.Top := 42;
  DMagicType4.SetImgIndex(g_WGameInter, 1648);
  DMagicType4.Left := 257;
  DMagicType4.Top := 42;
  DMagicType5.SetImgIndex(g_WGameInter, 1650);
  DMagicType5.Left := 291;
  DMagicType5.Top := 42;
  DMagicType6.SetImgIndex(g_WGameInter, 1652);
  DMagicType6.Left := 325;
  DMagicType6.Top := 42;
  DMagicType7.SetImgIndex(g_WGameInter, 1654);
  DMagicType7.Left := 359;
  DMagicType7.Top := 42;

  m_bTypeMagic := 0;
	m_nShowMagicNum := -1;

	m_nStartPos := 0;
	m_nMaxPos := 275;
  SetMagicIconPos();

  for nCnt := 0 to _MAX_TYPE_MAGIC - 1 do begin
    m_nSelectedMagic[nCnt] := -1;
  end;

   {-----------------------------------------------------------}

   //¹Ù´Ú Ã¢
  d := g_WGameInter.Images[1160];
  if d <> nil then begin
    DBottom.SetImgIndex(g_WGameInter, 1160);
    DBottom.Left := (SCREENWIDTH - d.Width) div 2;
    DBottom.Top := (SCREENHEIGHT - d.Height);
//    DBottom.Width := d.Width;
//    DBottom.Height := d.Height;
  end;

  DBotMiniMap.SetImgIndex(g_WGameInter, 1172);
  DBotMiniMap.Left := 638;
  DBotMiniMap.Top := 40;
  DBotTrade.SetImgIndex(g_WGameInter, 1170);
  DBotTrade.Left := 638;
  DBotTrade.Top := 5;
  DBotSkillBar.SetImgIndex(g_WGameInter, 1174);
  DBotSkillBar.Left := 638;
  DBotSkillBar.Top := 75;

  DBotGuild.SetImgIndex(g_WGameInter, 1182);
  DBotGuild.Left := 674;
  DBotGuild.Top := 11;
  DBotGroup.SetImgIndex(g_WGameInter, 1180);
  DBotGroup.Left := 706;
  DBotGroup.Top := 8;
  DMyState.SetImgIndex(g_WGameInter, 1196);
  DMyState.Left := 711;
  DMyState.Top := 31;
  DMyBag.SetImgIndex(g_WGameInter, 1194);
  DMyBag.Left := 682;
  DMyBag.Top := 33;
  DMyMagic.SetImgIndex(g_WGameInter, 1184);
  DMyMagic.Left := 739;
  DMyMagic.Top := 33;
  DOption.SetImgIndex(g_WGameInter, 1188);
  DOption.Left := 706;
  DOption.Top := 72;
  DBotMemo.SetImgIndex(g_WGameInter, 1190);
  DBotMemo.Left := 742;
  DBotMemo.Top := 61;
   {-----------------------------------------------------------}



  DBotBelt.SetImgIndex(g_WGameInter, 1205); //Áù¸ñÎïÆ·
  DBotBelt.Left := 148;
  DBotBelt.Top := 2;



   DBotPlusAbil.SetImgIndex (g_WProgUse, 140);
   DBotPlusAbil.Left := 219 + 30*4;
   DBotPlusAbil.Top := 104;
   // 2003/04/15 Ä£±¸, ÂÊÁö
   DBotFriend.SetImgIndex (g_WProgUse, 531);
   DBotFriend.Left := 181;//219 + 30*4;
   DBotFriend.Top := 184;//104;
   DBotMaster.SetImgIndex (g_WProgUse, 529);
   DBotMaster.Left := 603;//219 + 30*5;
   DBotMaster.Top := 85;//104;

  DBotExit.SetImgIndex(g_WGameInter, 1176);
  DBotExit.Left := 8;
  DBotExit.Top := 72;
  DBotLogout.SetImgIndex(g_WGameInter, 1178);
  DBotLogout.Left := 109;
  DBotLogout.Top := 72;

  //ÁÄÌì¿ò
  d := g_WGameInter.Images[1161];
  if d <> nil then begin
    DChat.SetImgIndex(g_WGameInter, 1161);
    DChat.Left := 178;
    DChat.Top := DBottom.Top - 19;
    DChat.Width := d.Width;
    DChat.Height := d.Height;
  end;
  DChatMode.SetImgIndex(g_WGameInter, 1168);
  DChatMode.Left := 441;
  DChatMode.Top := 24;

  DChatScrlChat.SetImgIndex(g_WGameInter, 1207);
  DChatScrlChat.Left := 441;
  DChatScrlChat.Top := 70;

  DChatSet1.SetImgIndex(g_WGameInter, 1330);
  DChatSet1.Left := 8;
  DChatSet1.Top := 276;
  DChatSet2.SetImgIndex(g_WGameInter, 1333);
  DChatSet2.Left := 8 + 40;
  DChatSet2.Top := 276;
  DChatSet3.SetImgIndex(g_WGameInter, 1335);
  DChatSet3.Left := 7 + 40 * 2;
  DChatSet3.Top := 275;
  DChatSet4.SetImgIndex(g_WGameInter, 1337);
  DChatSet4.Left := 7 + 40 * 3;
  DChatSet4.Top := 275;
  DChatSet5.SetImgIndex(g_WGameInter, 1338);
  DChatSet5.Left := 7 + 40 * 4;
  DChatSet5.Top := 275;
  DChatSet6.SetImgIndex(g_WGameInter, 1340);
  DChatSet6.Left := 7 + 40 * 5;
  DChatSet6.Top := 275;
  DChatSet7.SetImgIndex(g_WGameInter, 1342);
  DChatSet7.Left := 7 + 40 * 6;
  DChatSet7.Top := 275;

  mChatViewMode := False;

  //Ð¡µØÍ¼
  d := g_WGameInter.Images[1481];
  if d <> nil then begin
    DMiniMapDlg.SetImgIndex(g_WGameInter, 1481);
    DMiniMapDlg.Left := (SCREENWIDTH - d.Width);
    DMiniMapDlg.Top := 0;
  end;
  DMiniMapShow.SetImgIndex(g_WGameInter, 1484);
  DMiniMapShow.Left := 110;
  DMiniMapShow.Top := 109;
  DMiniMapBlend.SetImgIndex(g_WGameInter, 1482);
  DMiniMapBlend.Left := 90;
  DMiniMapBlend.Top := 109;

   {-----------------------------------------------------------}

   //»óÀÎ ´ëÈ­Ã¢
   d := g_WProgUse.Images[384];
   if d <> nil then begin
      DMerchantDlg.Left := 0;
      DMerchantDlg.Top := 0;
      DMerchantDlg.SetImgIndex (g_WProgUse, 384);
   end;
   DMerchantDlgClose.Left := 409;
   DMerchantDlgClose.Top := 5;
   DMerchantDlgClose.SetImgIndex (g_WProgUse, 86);

   {-----------------------------------------------------------}

   //¸Þ´ºÃ¢
   d := g_WProgUse.Images[385];
   if d <> nil then begin
      DMenuDlg.Left := 138;
      DMenuDlg.Top  := 163;
      DMenuDlg.SetImgIndex (g_WProgUse, 385);
   end;
   DMenuPrev.Left := 75;
   DMenuPrev.Top := 191;
   DMenuPrev.SetImgIndex (g_WProgUse, 388);
   DMenuNext.Left := 134;
   DMenuNext.Top := 191;
   DMenuNext.SetImgIndex (g_WProgUse, 387);
   DMenuBuy.Left := 210;
   DMenuBuy.Top := 187;
   DMenuBuy.SetImgIndex (g_WProgUse, 386);
   DMenuClose.Left := 305;
   DMenuClose.Top := 5;
   DMenuClose.SetImgIndex (g_WProgUse, 86);

   {-----------------------------------------------------------}

   //À§Å¹ÆÇ¸Å  //2004/01/15 ItemMarket..
   d := g_WProgUse.Images[670];
   if d <> nil then begin
      DItemMarketDlg.Left := 0;
      DItemMarketDlg.Top  := 90;
      DItemMarketDlg.SetImgIndex (g_WProgUse, 670);
   end;

   DItemListPrev.Left := 198;
   DItemListPrev.Top := 389;
   DItemListPrev.SetImgIndex (g_WProgUse, 388);
   DItemListNext.Left := 301;
   DItemListNext.Top := 389;
   DItemListNext.SetImgIndex (g_WProgUse, 387);
   DItemListRefresh.Left := 248;
   DItemListRefresh.Top := 388;
   DItemListRefresh.SetImgIndex (g_WProgUse, 665);

   DItemBuy.Left := 346;
   DItemBuy.Top  := 353;
   DItemBuy.SetImgIndex (g_WProgUse, 678);
   DItemSellCancel.Left := 346;
   DItemSellCancel.Top  := 353;
   DItemSellCancel.SetImgIndex (g_WProgUse, 650);
   DItemCancel.Left := 415;
   DItemCancel.Top  := 353;
   DItemCancel.SetImgIndex (g_WProgUse, 652);
   DItemFind.Left := 180;
   DItemFind.Top  := 353;
   DItemFind.SetImgIndex (g_WProgUse, 676);
   DMarketMemo.Left := 316;
   DMarketMemo.Top := 353;
   DMarketMemo.SetImgIndex (g_WProgUse, 666);

   DMGold.Visible := False;
//   DMGold.SetImgIndex (g_WProgUse, 29); //µ·Å©±â 3°³ °°À½
//   DMGold.Left := 465;
//   DMGold.Top  := 226;

   DItemMarketClose.Left := 491;
   DItemMarketClose.Top := 5;
   DItemMarketClose.SetImgIndex (g_WProgUse, 86);
   {-----------------------------------------------------------}

   //Àå¿ø ²Ù¹Ì±â //2004/06/18
   d := g_WProgUse.Images[702];
   if d <> nil then begin
      DGADecorateDlg.Left := 0;
      DGADecorateDlg.Top  := 20;
      DGADecorateDlg.SetImgIndex (g_WProgUse, 702);
   end;

   DGADecorateListPrev.Left := 255;
   DGADecorateListPrev.Top := 382;
   DGADecorateListPrev.SetImgIndex (g_WProgUse, 388);
   DGADecorateListNext.Left := 358;
   DGADecorateListNext.Top := 382;
   DGADecorateListNext.SetImgIndex (g_WProgUse, 387);

   DGADecorateBuy.Left := 219;
   DGADecorateBuy.Top  := 325;
   DGADecorateBuy.SetImgIndex (g_WProgUse, 678);
   DGADecorateCancel.Left := 219;
   DGADecorateCancel.Top  := 348;
   DGADecorateCancel.SetImgIndex (g_WProgUse, 652);
   DGADecorateClose.Left := 607;
   DGADecorateClose.Top := 5;
   DGADecorateClose.SetImgIndex (g_WProgUse, 86);

   {-----------------------------------------------------------}

   //Àå¿øÃ¢
   d := g_WProgUse.Images[680];
   if d <> nil then begin
      DJangwonListDlg.Left := 0;
      DJangwonListDlg.Top  := 175;
      DJangwonListDlg.SetImgIndex (g_WProgUse, 680);
   end;

   DJangListPrev.Left := 214;
   DJangListPrev.Top := 213;
   DJangListPrev.SetImgIndex (g_WProgUse, 388);
   DJangListNext.Left := 317;
   DJangListNext.Top := 213;
   DJangListNext.SetImgIndex (g_WProgUse, 387);
   DJangMemo.Left := 264;
   DJangMemo.Top := 211;
   DJangMemo.SetImgIndex (g_WProgUse, 666);

   DMGold.Visible := False;
//   DMGold.SetImgIndex (g_WProgUse, 29); //µ·Å©±â 3°³ °°À½
//   DMGold.Left := 465;
//   DMGold.Top  := 226;

   DJangwonClose.Left := 534;//410;
   DJangwonClose.Top := 5;
   DJangwonClose.SetImgIndex (g_WProgUse, 86);

   {-----------------------------------------------------------}
   //Àå¿ø °Ô½ÃÆÇ ¸®½ºÆ®
   d := g_WProgUse.Images[688];
   if d <> nil then begin
      DGABoardListDlg.Left := 0;
      DGABoardListDlg.Top  := 48;
      DGABoardListDlg.SetImgIndex (g_WProgUse, 688);
   end;

   DGABoardOk.Left := 217;
   DGABoardOk.Top := 286;
   DGABoardOk.SetImgIndex (g_WProgUse, 650);
   DGABoardWrite.Left := 287;
   DGABoardWrite.Top := 286;
   DGABoardWrite.SetImgIndex (g_WProgUse, 693);
   DGABoardNotice.Left := 357;
   DGABoardNotice.Top := 286;
   DGABoardNotice.SetImgIndex (g_WProgUse, 695);

   DGABoardListPrev.Left := 163;
   DGABoardListPrev.Top := 321;
   DGABoardListPrev.SetImgIndex (g_WProgUse, 388);
   DGABoardListNext.Left := 266;
   DGABoardListNext.Top := 321;
   DGABoardListNext.SetImgIndex (g_WProgUse, 387);
   DGABoardListRefresh.Left := 213;
   DGABoardListRefresh.Top := 320;
   DGABoardListRefresh.SetImgIndex (g_WProgUse, 665);

   DGABoardListClose.Left := 432;
   DGABoardListClose.Top := 5;
   DGABoardListClose.SetImgIndex (g_WProgUse, 86);

   {-----------------------------------------------------------}
   //Àå¿ø °Ô½ÃÆÇ ÀÐ±âÃ¢
   d := g_WProgUse.Images[689];
   if d <> nil then begin
      DGABoardDlg.Left := 0;
      DGABoardDlg.Top  := 145;
      DGABoardDlg.SetImgIndex (g_WProgUse, 689);
   end;

   DGABoardDel.Left := 29;
   DGABoardDel.Top := 213;
   DGABoardDel.SetImgIndex (g_WProgUse, 697);
   DGABoardMemo.Left := 95;
   DGABoardMemo.Top := 213;
   DGABoardMemo.SetImgIndex (g_WProgUse, 666);

   DGABoardReply.Left := 121;
   DGABoardReply.Top := 213;
   DGABoardReply.SetImgIndex (g_WProgUse, 699);
   DGABoardOk2.Left := 187;
   DGABoardOk2.Top := 213;
   DGABoardOk2.SetImgIndex (g_WProgUse, 650);
   DGABoardCancel.Left := 253;
   DGABoardCancel.Top := 213;
   DGABoardCancel.SetImgIndex (g_WProgUse, 652);

   DGABoardClose.Left := 324;
   DGABoardClose.Top := 5;
   DGABoardClose.SetImgIndex (g_WProgUse, 86);

   {-----------------------------------------------------------}

   //ÆÈ±âÃ¢
   d := g_WProgUse.Images[392];
   if d <> nil then begin
      DSellDlg.Left := 328;
      DSellDlg.Top  := 163;
      DSellDlg.SetImgIndex (g_WProgUse, 392);
   end;
   DSellDlgOk.Left := 114;
   DSellDlgOk.Top := 72;
   DSellDlgOk.SetImgIndex (g_WProgUse, 393);
   DSellDlgBtnHold.Left := 114;
   DSellDlgBtnHold.Top := 43;
   DSellDlgBtnHold.SetImgIndex (g_WProgUse, 404);
   DSellDlgStHold.Left := 94;
   DSellDlgStHold.Top := 43;
   DSellDlgStHold.SetImgIndex (g_WProgUse, 403);
   DSellDlgClose.Left := 147;
   DSellDlgClose.Top := 16;
   DSellDlgClose.SetImgIndex (g_WProgUse, 86);
   DSellDlgSpot.Left := 27;
   DSellDlgSpot.Top  := 60;
   DSellDlgSpot.Width := 58;
   DSellDlgSpot.Height := 60;

   {-----------------------------------------------------------}

   //¸¶¹ý Å° ¼³Á¤ Ã¢
   d := g_WProgUse.Images[710];
   if d <> nil then begin
      DKeySelDlg.Left := (SCREENWIDTH - d.Width) div 2;
      DKeySelDlg.Top  := (SCREENHEIGHT - d.Height) div 2;
      DKeySelDlg.SetImgIndex (g_WProgUse, 710);
//      DKeySelDlg.SetImgIndex (g_WProgUse, 360);
   end;
   DKsIcon.Left := 51;//38;
   DKsIcon.Top := 36;//24;
   DKsF1.SetImgIndex (g_WProgUse, 713);
   DKsF1.Left := 37+15;
   DKsF1.Top  := 80;
   DKsF2.SetImgIndex (g_WProgUse, 715);
   DKsF2.Left := 69+15;//66;
   DKsF2.Top  := 80;
   DKsF3.SetImgIndex (g_WProgUse, 717);
   DKsF3.Left := 101+15;//98;
   DKsF3.Top  := 80;
   DKsF4.SetImgIndex (g_WProgUse, 719);
   DKsF4.Left := 133+15;////130;
   DKsF4.Top  := 80;
   DKsF5.SetImgIndex (g_WProgUse, 721);
   DKsF5.Left := 170+15;//171; //-11
   DKsF5.Top  := 80;
   DKsF6.SetImgIndex (g_WProgUse, 723);
   DKsF6.Left := 202+15;//203;
   DKsF6.Top  := 80;
   DKsF7.SetImgIndex (g_WProgUse, 725);
   DKsF7.Left := 234+15;//235;
   DKsF7.Top  := 80;
   DKsF8.SetImgIndex (g_WProgUse, 727);
   DKsF8.Left := 266+15;//267;
   DKsF8.Top  := 80;

{   DKsF9.SetImgIndex (g_WProgUse, 729);
   DKsF9.Left := 289;//171; //-11
   DKsF9.Top  := 79;
   DKsF10.SetImgIndex (g_WProgUse, 731);
   DKsF10.Left := 322;//203;
   DKsF10.Top  := 79;
   DKsF11.SetImgIndex (g_WProgUse, 733);
   DKsF11.Left := 353;//235;
   DKsF11.Top  := 79;
   DKsF12.SetImgIndex (g_WProgUse, 735);
   DKsF12.Left := 386;//267;
   DKsF12.Top  := 79;}

   // 2003/08/20 =>¸¶¹ý´ÜÃàÅ° Ãß°¡  // AddMagicKey
   DKsConF1.SetImgIndex (g_WProgUse, 729);
   DKsConF1.Left := 37+15;
   DKsConF1.Top  := 117;
   DKsConF2.SetImgIndex (g_WProgUse, 731);
   DKsConF2.Left := 69+15;
   DKsConF2.Top  := 117;
   DKsConF3.SetImgIndex (g_WProgUse, 733);
   DKsConF3.Left := 101+15;
   DKsConF3.Top  := 117;
   DKsConF4.SetImgIndex (g_WProgUse, 735);
   DKsConF4.Left := 133+15;
   DKsConF4.Top  := 117;
   DKsConF5.SetImgIndex (g_WProgUse, 737);
   DKsConF5.Left := 170+15;
   DKsConF5.Top  := 117;
   DKsConF6.SetImgIndex (g_WProgUse, 739);
   DKsConF6.Left := 202+15;
   DKsConF6.Top  := 117;
   DKsConF7.SetImgIndex (g_WProgUse, 741);
   DKsConF7.Left := 234+15;
   DKsConF7.Top  := 117;
   DKsConF8.SetImgIndex (g_WProgUse, 743);
   DKsConF8.Left := 266+15;
   DKsConF8.Top  := 117;

{   DKsConF9.SetImgIndex (g_WProgUse, 753);
   DKsConF9.Left := 290;
   DKsConF9.Top  := 116;
   DKsConF10.SetImgIndex (g_WProgUse, 755);
   DKsConF10.Left := 322;
   DKsConF10.Top  := 116;
   DKsConF11.SetImgIndex (g_WProgUse, 757);
   DKsConF11.Left := 354;
   DKsConF11.Top  := 116;
   DKsConF12.SetImgIndex (g_WProgUse, 759);
   DKsConF12.Left := 386;
   DKsConF12.Top  := 116;}

   //-------
   DKsNone.SetImgIndex (g_WProgUse, 748);
   DKsNone.Left := 324;//319;
   DKsNone.Top  := 84;//77;
   DKsOk.SetImgIndex (g_WProgUse, 651);
   DKsOk.Left := 324;//319;
   DKsOk.Top  := 121;//113;

   {-----------------------------------------------------------}

   //¿É¼ÇÃ¢ 2006/01/12
   d := g_WGameInter.Images[1290];
   if d <> nil then begin
      DMainOption.Left := (SCREENWIDTH - d.Width) div 2;
      DMainOption.Top  := 125;
      DMainOption.SetImgIndex (g_WGameInter, 1290);
   end;

   DSkillMode1.SetImgIndex (g_WProgUse, 1292);
   DSkillMode1.Left := 166;
   DSkillMode1.Top  := 77;
   DSkillMode2.SetImgIndex (g_WProgUse, 1294);
   DSkillMode2.Left := 208;
   DSkillMode2.Top  := 77;
   DSkillBarOn.SetImgIndex (g_WProgUse, 1292);
   DSkillBarOn.Left := 166;
   DSkillBarOn.Top  := 99;
   DSkillBarOff.SetImgIndex (g_WProgUse, 1294);
   DSkillBarOff.Left := 208;
   DSkillBarOff.Top  := 99;
   DEffectOn.SetImgIndex (g_WProgUse, 1292);
   DEffectOn.Left := 166;
   DEffectOn.Top  := 121;
   DEffectOff.SetImgIndex (g_WProgUse, 1294);
   DEffectOff.Left := 208;
   DEffectOff.Top  := 121;
   DSoundOn.SetImgIndex (g_WProgUse, 1292);
   DSoundOn.Left := 166;
   DSoundOn.Top  := 143;
   DSoundOff.SetImgIndex (g_WProgUse, 1294);
   DSoundOff.Left := 208;
   DSoundOff.Top  := 143;
   DDropViewOn.SetImgIndex (g_WProgUse, 1292);
   DDropViewOn.Left := 166;
   DDropViewOn.Top  := 165;
   DDropViewOff.SetImgIndex (g_WProgUse, 1294);
   DDropViewOff.Left := 208;
   DDropViewOff.Top  := 165;
   DMainOptionClose.SetImgIndex (g_WGameInter, 1221);
   DMainOptionClose.Left := 274;
   DMainOptionClose.Top  := 5;

   {-----------------------------------------------------------}
  //Ð¡×é
  d := g_WGameInter.Images[1360];
  if d <> nil then
  begin
    DGroupDlg.Left := (SCREENWIDTH - d.Width) div 2;
    DGroupDlg.Top := (SCREENHEIGHT - d.Height) div 2;
    DGroupDlg.SetImgIndex(g_WGameInter, 1360);
  end;
  DGrpDlgClose.SetImgIndex(g_WGameInter, 1221);
  DGrpDlgClose.Left := 343;
  DGrpDlgClose.Top := 206;
  DGrpAllowGroup.SetImgIndex(g_WGameInter, 1371);
  DGrpAllowGroup.Left := 150;
  DGrpAllowGroup.Top := 52;
  DGrpCreate.SetImgIndex(g_WGameInter, 1362);
  DGrpCreate.Left := 166;
  DGrpCreate.Top := 198;
  DGrpAddMem.SetImgIndex(g_WGameInter, 1365);
  DGrpAddMem.Left := 226;
  DGrpAddMem.Top := 198;
  DGrpDelMem.SetImgIndex(g_WGameInter, 1368);
  DGrpDelMem.Left := 286;
  DGrpDelMem.Top := 198;
   {-----------------------------------------------------------}

   d := g_WProgUse.Images[389];  //³» ±³È¯Ã¢
   if d <> nil then begin
      DDealDlg.Left := SCREENWIDTH - d.Width;
      DDealDlg.Top  := 0;
      DDealDlg.SetImgIndex (g_WProgUse, 389);
   end;
   DDGrid.Left := 29;
   DDGrid.Top  := 38;
   DDGrid.Width := 36 * 5;
   DDGrid.Height := 33 * 2;
   DDealOk.SetImgIndex (g_WProgUse, 391);
   DDealOk.Left := 158;
   DDealOk.Top := 105;
   DDealClose.SetImgIndex (g_WProgUse, 86);
   DDealClose.Left := 212;
   DDealClose.Top := 16;
   DDGold.SetImgIndex (g_WProgUse, 28);
   DDGold.Left := 14;
   DDGold.Top  := 125;

   d := g_WProgUse.Images[390];  //»ó´ë¹æ ±³È¯Ã¢
   if d <> nil then begin
      DDealRemoteDlg.Left := DDealDlg.Left - d.Width;
      DDealRemoteDlg.Top  := 0;
      DDealRemoteDlg.SetImgIndex (g_WProgUse, 390);
   end;
   DDRGrid.Left := 29;
   DDRGrid.Top  := 38;
   DDRGrid.Width := 36 * 5;
   DDRGrid.Height := 33 * 2;
   DDRGold.SetImgIndex (g_WProgUse, 28);
   DDRGold.Left := 14;
   DDRGold.Top  := 125;

   // Àå¿ø °Å·¡ ¾Ë¸²ÆÇ
   d := g_WProgUse.Images[683];
   if d <> nil then begin
      DDealJangwon.Left := 398;
      DDealJangwon.Top  := 138;
      DDealJangwon.SetImgIndex (g_WProgUse, 683);
   end;

   {-----------------------------------------------------------}
   //¹®ÆÄÃ¢
  d := g_WGameInter.Images[1300];
  if d <> nil then begin
    DGuildDlg.Left := 0;
    DGuildDlg.Top := 0;
    DGuildDlg.SetImgIndex(g_WGameInter, 1300);
  end;
  DGDClose.Left := 760;
  DGDClose.Top := 431;
  DGDClose.SetImgIndex (g_WGameInter, 1222);
  DGDHome.Left := 234;
  DGDHome.Top := 409;
  DGDHome.SetImgIndex (g_WGameInter, 1301);
  DGDList.Left := 303;
  DGDList.Top := 418;
  DGDList.SetImgIndex (g_WGameInter, 1304);
  DGDChat.Left := 353;
  DGDChat.Top := 418;
  DGDChat.SetImgIndex(g_WGameInter, 1304);
//  DGDAddMem.Left := 243;
//  DGDAddMem.Top := 411;
//  DGDAddMem.SetImgIndex (g_WGameInter, 1310);
  DGDDelMem.Left := 553;
  DGDDelMem.Top := 418;
  DGDDelMem.SetImgIndex (g_WGameInter, 1313);
  DGDEditNotice.Left := 503;
  DGDEditNotice.Top := 418;
  DGDEditNotice.SetImgIndex (g_WGameInter, 1310);
  DGDEditGrade.Left := 653;
  DGDEditGrade.Top := 418;
  DGDEditGrade.SetImgIndex(g_WGameInter, 1320);
//   DGDAlly.Left := 400;
//   DGDAlly.Top  := 405;
//   DGDAlly.SetImgIndex (g_WGameInter, 184);
  DGDBreakAlly.Left := 703;
  DGDBreakAlly.Top := 418;
  DGDBreakAlly.SetImgIndex(g_WGameInter, 1323);
//   DGDWar.Left := 517;
//   DGDWar.Top  := 405;
//   DGDWar.SetImgIndex (g_WGameInter, 202);
//   DGDCancelWar.Left := 517;
//   DGDCancelWar.Top  := 426;
//   DGDCancelWar.SetImgIndex (g_WGameInter, 188);

   DGDUp.Left := 607;
   DGDUp.Top  := 215;
   DGDUp.SetImgIndex (g_WGameInter, 373);
   DGDDown.Left := 607;
   DGDDown.Top  := 274;
   DGDDown.SetImgIndex (g_WGameInter, 372);

   //¹®ÆÄ °øÁö»çÇ× ¿¡µðÆ®
  DGuildEditNotice.SetImgIndex(g_WGameInter, 1326);
  DGEOk.SetImgIndex(g_WGameInter, 1327);
  DGEOk.Left := 681;
  DGEOk.Top := 16;
  DGEClose.SetImgIndex(g_WGameInter, 1222);
  DGEClose.Left := 766;
  DGEClose.Top := 214;


   {-----------------------------------------------------------}
   //´É·ÂÄ¡ Á¶ÀýÃ¢
   DAdjustAbility.SetImgIndex (g_WProgUse, 226);
   DAdjustAbilClose.SetImgIndex (g_WProgUse, 64);
   DAdjustAbilClose.Left := 316;
   DAdjustAbilClose.Top := 1;
   DAdjustAbilOk.SetImgIndex (g_WProgUse, 62);
   DAdjustAbilOk.Left := 220;
   DAdjustAbilOk.Top := 298;

   DPlusDC.SetImgIndex (g_WProgUse, 227);     DPlusDC.Left := 217; DPlusDC.Top := 101;
   DPlusMC.SetImgIndex (g_WProgUse, 227);     DPlusMC.Left := 217; DPlusMC.Top := 121;
   DPlusSC.SetImgIndex (g_WProgUse, 227);     DPlusSC.Left := 217; DPlusSC.Top := 140;
   DPlusAC.SetImgIndex (g_WProgUse, 227);     DPlusAC.Left := 217; DPlusAC.Top := 160;
   DPlusMAC.SetImgIndex (g_WProgUse, 227);    DPlusMAC.Left := 217; DPlusMAC.Top := 181;
   DPlusHP.SetImgIndex (g_WProgUse, 227);     DPlusHP.Left := 217; DPlusHP.Top := 201;
   DPlusMP.SetImgIndex (g_WProgUse, 227);     DPlusMP.Left := 217; DPlusMP.Top := 220;
   DPlusHit.SetImgIndex (g_WProgUse, 227);    DPlusHit.Left := 217; DPlusHit.Top := 240;
   DPlusSpeed.SetImgIndex (g_WProgUse, 227);  DPlusSpeed.Left := 217; DPlusSpeed.Top := 261;

   DMinusDC.SetImgIndex (g_WProgUse, 228);    DMinusDC.Left := 227; DMinusDC.Top := 101;
   DMinusMC.SetImgIndex (g_WProgUse, 228);    DMinusMC.Left := 227; DMinusMC.Top := 121;
   DMinusSC.SetImgIndex (g_WProgUse, 228);    DMinusSC.Left := 227; DMinusSC.Top := 140;
   DMinusAC.SetImgIndex (g_WProgUse, 228);    DMinusAC.Left := 227; DMinusAC.Top := 160;
   DMinusMAC.SetImgIndex (g_WProgUse, 228);   DMinusMAC.Left := 227; DMinusMAC.Top := 181;
   DMinusHP.SetImgIndex (g_WProgUse, 228);    DMinusHP.Left := 227; DMinusHP.Top := 201;
   DMinusMP.SetImgIndex (g_WProgUse, 228);    DMinusMP.Left := 227; DMinusMP.Top := 220;
   DMinusHit.SetImgIndex (g_WProgUse, 228);   DMinusHit.Left := 227; DMinusHit.Top := 240;
   DMinusSpeed.SetImgIndex (g_WProgUse, 228); DMinusSpeed.Left := 227; DMinusSpeed.Top := 261;

   {-----------------------------------------------------------}
   // 2003/04/15 Ä£±¸, ÂÊÁö
   //Ä£±¸Ã¢
   d := g_WProgUse.Images[536];
   if d <> nil then begin
      DFriendDlg.SetImgIndex (g_WProgUse, 536);
      DFriendDlg.Left := 0;//(SCREENWIDTH - d.Width) div 2;
      DFriendDlg.Top  := 0;//(SCREENHEIGHT - d.Height) div 2;
   end;
   DFrdClose.SetImgIndex (g_WProgUse, 86);  DFrdClose.Left := 270;   DFrdClose.Top := 5;
   DFrdPgUp.SetImgIndex (g_WProgUse, 373);   DFrdPgUp.Left := 275;    DFrdPgUp.Top := 116;
   DFrdPgDn.SetImgIndex (g_WProgUse, 372);   DFrdPgDn.Left := 275;    DFrdPgDn.Top := 175;
   DFrdFriend.SetImgIndex (g_WProgUse, 540); DFrdFriend.Left := 27;   DFrdFriend.Top := 60;
   DFrdBlackList.SetImgIndex (g_WProgUse, 573); DFrdBlackList.Left := 147;  DFrdBlackList.Top := 60;
   DFrdAdd.SetImgIndex (g_WProgUse, 554);    DFrdAdd.Left := 92;      DFrdAdd.Top := 260;
   DFrdDel.SetImgIndex (g_WProgUse, 556);    DFrdDel.Left := 92+35;     DFrdDel.Top := 260;
   DFrdMemo.SetImgIndex (g_WProgUse, 558);   DFrdMemo.Left := 92+70;    DFrdMemo.Top := 260;
   DFrdMail.SetImgIndex (g_WProgUse, 560);   DFrdMail.Left := 92+105;    DFrdMail.Top := 260;
   DFrdWhisper.SetImgIndex(g_WProgUse, 562); DFrdWhisper.Left := 92+140; DFrdWhisper.Top := 260;
   {-----------------------------------------------------------}
   //ÂÊÁö¸ñ·ÏÃ¢
   d := g_WGameInter.Images[1960];
   if d <> nil then begin
      DMailListDlg.SetImgIndex (g_WGameInter, 1960);
      DMailListDlg.Left := 512;//(SCREENWIDTH - d.Width) div 2;
      DMailListDlg.Top  := 0;//(SCREENHEIGHT - d.Height) div 2;
   end;
   DMailListClose.SetImgIndex (g_WGameInter, 1221);   DMailListClose.Left := 270;   DMailListClose.Top := 5;
   DMailListPgUp.SetImgIndex (g_WGameInter, 373);   DMailListPgUp.Left := 275;    DMailListPgUp.Top := 116;
   DMailListPgDn.SetImgIndex (g_WGameInter, 372);   DMailListPgDn.Left := 275;    DMailListPgDn.Top := 175;
   DMLReply.SetImgIndex (g_WGameInter, 564);        DMLReply.Left := 92;      DMLReply.Top := 260;
   DMLRead.SetImgIndex (g_WGameInter, 566);         DMLRead.Left := 92+35;       DMLRead.Top := 260;
   DMLDel.SetImgIndex (g_WGameInter, 556);          DMLDel.Left := 92+70;        DMLDel.Top := 260;
   DMLLock.SetImgIndex (g_WGameInter, 568);         DMLLock.Left := 92+105;      DMLLock.Top := 260;
   DMLBlock.SetImgIndex(g_WGameInter, 570);         DMLBlock.Left := 92+140;     DMLBlock.Top := 260;
   {-----------------------------------------------------------}
   //°ÅºÎÀÚ ¸®½ºÆ®
   d := g_WProgUse.Images[536];
   if d <> nil then begin
      DBlockListDlg.SetImgIndex (g_WProgUse, 536);
      DBlockListDlg.Left := 512;//(SCREENWIDTH - d.Width) div 2;
      DBlockListDlg.Top  := 265;//(SCREENHEIGHT - d.Height) div 2;
   end;
   DBlockListClose.SetImgIndex (g_WProgUse, 86);  DBlockListClose.Left := 270;   DBlockListClose.Top := 5;
   DBLPgUp.SetImgIndex (g_WProgUse, 373);   DBLPgUp.Left := 275;    DBLPgUp.Top := 116;
   DBLPgDn.SetImgIndex (g_WProgUse, 372);   DBLPgDn.Left := 275;    DBLPgDn.Top := 175;
   DBLAdd.SetImgIndex (g_WProgUse, 554);    DBLAdd.Left := 92+105;     DBLAdd.Top := 260;
   DBLDel.SetImgIndex(g_WProgUse, 556);     DBLDel.Left := 92+140;     DBLDel.Top := 260;
   {-----------------------------------------------------------}
   //ÂÊÁöÃ¢
   d := g_WGameInter.Images[1960];
   if d <> nil then begin
      DMemo.SetImgIndex (g_WGameInter, 1960);
      DMemo.Left := 290;//(SCREENWIDTH - d.Width) div 2;
      DMemo.Top  := 0; //(SCREENHEIGHT - d.Height) div 2;
   end;
   DMemoClose.SetImgIndex (g_WProgUse, 86); DMemoClose.Left := 208;  DMemoClose.Top := 5;
   DMemoB1.SetImgIndex (g_WProgUse, 544);    DMemoB1.Left := 63;      DMemoB1.Top := 146;
   DMemoB2.SetImgIndex(g_WProgUse, 538);     DMemoB2.Left := 134;     DMemoB2.Top := 146;

   {-----------------------------------------------------------}
   //¿¬ÀÎ»çÁ¦Ã¢
   d := g_WProgUse.Images[583];
   if d <> nil then begin
      DMasterDlg.SetImgIndex (g_WProgUse, 583);
      DMasterDlg.Left := 0;//(SCREENWIDTH - d.Width) div 2;
      DMasterDlg.Top  := 0;//(SCREENHEIGHT - d.Height) div 2;
   end;
   DMasterClose.SetImgIndex (g_WProgUse, 86);  DMasterClose.Left := 300;    DMasterClose.Top := 5;
   DLover1.SetImgIndex (g_WProgUse, 600);       DLover1.Left := 41;         DLover1.Top := 161;
   DLover2.SetImgIndex (g_WProgUse, 598);       DLover2.Left := 41+37;      DLover2.Top := 161;
   DLover3.SetImgIndex (g_WProgUse, 594);       DLover3.Left := 41+37*2;    DLover3.Top := 161;
   DMaster1.SetImgIndex (g_WProgUse, 590);      DMaster1.Left := 145;       DMaster1.Top:= 381;
   DMaster2.SetImgIndex (g_WProgUse, 596);      DMaster2.Left := 145+37;    DMaster2.Top:= 381;
   DMaster3.SetImgIndex (g_WProgUse, 592);      DMaster3.Left := 145+37*2;  DMaster3.Top:= 381;

end;




{------------------------------------------------------------------------}



//»óÅÂÃ¢ ¿­±â
procedure TFrmDlg.OpenMyStatus;
var
  str : String;
begin
   str := Copy(fLover.GetDisplay(0), length(STR_LOVER)+1, 6);
   if str = '' then DHeartImg.Visible := False
   else DHeartImg.Visible := True;

   DStateWin.Visible := not DStateWin.Visible;
   PageChanged;
end;

procedure TFrmDlg.OpenUserState (ustate: TUserStateInfo);
begin
   UserState1 := ustate;
   if UserState1.bExistLover then  DHeartImgUS.Visible := True
   else DHeartImgUS.Visible := False;
   DUserState1.Visible := TRUE;
end;

//°¡¹æ ¿­±â
procedure TFrmDlg.OpenItemBag;
begin
   DItemBag.Visible := not DItemBag.Visible;
   if DItemBag.Visible then
      ArrangeItemBag;
end;

procedure TFrmDlg.OpenMyMagic;
begin
   DMagicWnd.Visible := not DMagicWnd.Visible;
end;

//ÇÏ´Ü »óÅÂ¹Ù º¸±â
procedure TFrmDlg.ViewBottomBox (visible: Boolean);
begin
   DBottom.Visible := visible;
   DChat.Visible := visible;
end;


// ¾ÆÀÌÅÛ ¸¶¿ì½º·Î ÀÌµ¿Áß Ãë¼Ò
procedure TFrmDlg.CancelItemMoving;
var
   idx, n: integer;
begin
   if ItemMoving then begin
      ItemMoving := FALSE;
      idx := MovingItem.Index;
      if idx < 0 then begin
         if idx = -99 then begin
            AddItemBag (MovingItem.Item);
            Exit;
         end;
         if (idx <= -20) and (idx > -30) then begin
            AddDealItem (MovingItem.Item);
         end else begin
            n := -(idx+1);
            // 2003/03/15 ¾ÆÀÌÅÛ ÀÎº¥Åä¸® È®Àå
            if n in [0..12] then begin    //8->12
               UseItems[n] := MovingItem.Item;
            end;
         end;
      end else
         if idx in [0..MAXBAGITEM-1] then begin
            if (ItemArr[idx].S.Name = '') then begin
//               (MovingItem.Item.S.StdMode <= 3) then begin // 2004/02/23 Æ÷¼Ç, À½½Ä, ½ºÅ©·Ñ ¾Æ´Ñ°ÍÀº °¡¹æÃ¢¿¡..
               ItemArr[idx] := MovingItem.Item;
            end else begin
               AddItemBag (MovingItem.Item);
            end;
         end;
      MovingItem.Item.S.Name := '';
   end;
   ArrangeItemBag;
end;

//ÀÌµ¿ÁßÀÎ ¾ÆÀÌÅÛÀ» ¹Ù´Ú¿¡ ¶³¾î ¶ß¸²...
//°¡¹æ(º§Æ®)¿¡¼­ ¹ö¸°°Í¸¸ È£ÃâµÊ
procedure TFrmDlg.DropMovingItem;
var
   idx, DlopCount : integer;
   valstr : String;
   MsgResult : integer;
begin

   if ItemMoving then begin
      ItemMoving := FALSE;
      if MovingItem.Item.S.Name <> '' then begin
         if MovingItem.Item.S.OverlapItem > 0 then begin
            if DMakeItemDlg.Visible then begin
               DMessageDlg ('Á¦Á¶ Áß¿¡´Â °ãÄ¡±â °¡´ÉÇÑ ¾ÆÀÌÅÛÀ» ¹ö¸± ¼ö ¾ø½À´Ï´Ù.', [mbOk]);
               ItemMoving := True;
               CancelItemMoving;
               Exit;
            end;

            DlopCount := 0;
            Total := MovingItem.Item.Dura;
            if Total = 1 then begin
               DlgEditText := '1';
               MsgResult := mrOk;
            end
            else MsgResult := DCountMsgDlg ('ÃÑ ' + IntToStr(MovingItem.Item.Dura) +
                     '°³Áß ¸î°³¸¦ ¹ö¸®½Ã°Ú½À´Ï±î?', [mbOk, mbCancel, mbAbort]);
            ItemMoving := TRUE;
            if (MsgResult = mrCancel) then begin
               CancelItemMoving;
               Exit;
            end
            else if MsgResult = mrOk then begin

               GetValidStrVal (DlgEditText, valstr, [' ']);
               DlopCount := Str_ToInt (valstr, 0);

               if DlopCount <= 0 then DlopCount := 0;
               if DlopCount > MovingItem.Item.Dura then DlopCount := MovingItem.Item.Dura;
               if DlopCount = MovingItem.Item.Dura then begin
                  FrmMain.SendDropItem (MovingItem.Item.S.Name, MovingItem.Item.MakeIndex);
                  AddDropItem (MovingItem.Item);
                  MovingItem.Item.S.Name := '';
                  MovingItem.Item.Dura := 0;
               end
               else if (DlopCount > 0) then begin
                  FrmMain.SendDropCountItem( MovingItem.Item.S.Name, MovingItem.Item.MakeIndex, DlopCount );
               end;
               CancelItemMoving;
               Exit;
            end;
         end
         else begin

           if MovingItem.Item.S.StdMode <> 9 then begin
              if (MovingItem.Item.S.UniqueItem and $04) <> 0 then begin
                 if mrOk = DMessageDlg ('ÀÌ ¾ÆÀÌÅÛÀº ¹ö¸®¸é »ç¶óÁö´Â ¾ÆÀÌÅÛÀÔ´Ï´Ù.\Á¤¸»·Î ¾ÆÀÌÅÛÀ» »èÁ¦ÇÏ½Ã°Ú½À´Ï±î?', [mbOk, mbCancel]) then
                    FrmMain.SendDropItem (MovingItem.Item.S.Name, MovingItem.Item.MakeIndex)//2004/01/15 ItemSafeGuard..
                 else begin
                    ItemMoving := TRUE;
                    CancelItemMoving;
                    Exit;
                 end;
              end
              else if mrOk = DMessageDlg ('Á¤¸»·Î ¾ÆÀÌÅÛÀ» ¹ö¸®°Ú½À´Ï±î?', [mbOk, mbCancel]) then
                 FrmMain.SendDropItem (MovingItem.Item.S.Name, MovingItem.Item.MakeIndex)//2004/01/15 ItemSafeGuard..
              else begin
                 ItemMoving := TRUE;
                 CancelItemMoving;
                 Exit;
              end;
           end
           else
              FrmMain.SendDropItem (MovingItem.Item.S.Name, MovingItem.Item.MakeIndex)//2004/01/15 ItemSafeGuard..
         end;

         AddDropItem (MovingItem.Item);
         MovingItem.Item.S.Name := '';
      end;
   end;

    {
   if ItemMoving then begin
      ItemMoving := FALSE;
      if MovingItem.Item.S.Name <> '' then begin
         FrmMain.SendDropItem (MovingItem.Item.S.Name, MovingItem.Item.MakeIndex);
         AddDropItem (MovingItem.Item);
         MovingItem.Item.S.Name := '';
      end;
   end;
    }
end;

procedure TFrmDlg.OpenAdjustAbility;
begin
   DAdjustAbility.Left := 0;
   DAdjustAbility.Top := 0;
   SaveBonusPoint := BonusPoint;
   FillChar (BonusAbilChg, sizeof(TNakedAbility), #0);
   DAdjustAbility.Visible := TRUE;
end;

procedure TFrmDlg.DBackgroundBackgroundClick(Sender: TObject);
var
   dropgold: integer;
   valstr: string;
begin
   if ItemMoving then begin
      DBackground.WantReturn := TRUE;
      if MovingItem.Item.S.Name = '½ð±Ò' then begin
         ItemMoving := FALSE;
         MovingItem.Item.S.Name := '';
         //¾ó¸¶¸¦ ¹ö¸± °ÇÁö ¹°¾îº»´Ù.
         DialogSize := 1;
         DMessageDlg ('µ·À» ¾ó¸¶³ª ¹ö¸®½Ã°Ú½À´Ï±î?', [mbOk, mbAbort]);

         GetValidStrVal (DlgEditText, valstr, [' ']);
         dropgold := Str_ToInt (valstr, 0);
         //
         FrmMain.SendDropGold (dropgold);
      end;
      if MovingItem.Index >= 0 then //¾ÆÀÌÅÛ °¡¹æ¿¡¼­ ¹ö¸°°Í¸¸..
         DropMovingItem;
   end;
end;

procedure TFrmDlg.DBackgroundMouseDown(Sender: TObject;
  Button: TMouseButton; Shift: TShiftState; X, Y: Integer);
begin
   if ItemMoving then begin
      DBackground.WantReturn := TRUE;
   end;
end;

procedure TFrmDlg.DBottomMouseDown(Sender: TObject; Button: TMouseButton;
  Shift: TShiftState; X, Y: Integer);
   function ExtractUserName (line: string): string;
   var
      uname: string;
   begin
      GetValidStr3 (line, line, ['(', '!', '*', '/', ')']);
      GetValidStr3 (line, uname, [' ', '=', ':']);
      if uname <> '' then
         if (uname[1] = '/') or (uname[1] = '(') or (uname[1] = ' ') or (uname[1] = '[') then
            uname := '';
      Result := uname;
   end;
var
   n: integer;
   str: string;
begin
   //Ã¤ÆÃÃ¢¿¡ Å¬¸¯ÇÏ¸é, '/'±Ó¼Ó¸» ÀÏ¶§ Å¬¸¯ÇÑ ´ëÈ­¸¦ ÇÑ»ç¶÷ÀÇ ÀÌ¸§ÀÌ ±Ó¸»´ë»óÀÚ°¡ µÇ°Ô ÇÑ´Ù.
   if (X >= 208) and (X <= 208+374) and (Y >= SCREENHEIGHT-130) and (Y <= SCREENHEIGHT-130 + 12*9) then begin
      n := DScreen.ChatBoardTop + (Y - (SCREENHEIGHT-130)) div 12;
      if (n < DScreen.ChatStrs.Count) then begin
         if not PlayScene.EdChat.Visible then begin
            PlayScene.EdChat.Visible := TRUE;
            PlayScene.EdChat.SetFocus;
         end;
         PlayScene.EdChat.Text := '/' + ExtractUserName (DScreen.ChatStrs[n]) + ' ';
         PlayScene.EdChat.SelStart := Length(PlayScene.EdChat.Text);
         PlayScene.EdChat.SelLength := 0;

         LocalLanguage := imSHanguel;
         SetImeMode (PlayScene.EdChat.Handle, LocalLanguage);
         LocalLanguage := imSAlpha;

      end else
         PlayScene.EdChat.Text := '';
   end;

   if DItemMarketDlg.Visible then begin
      if (X >= 206) and (X <= 208+380) and (Y >= SCREENHEIGHT-51) then SetChatFocus;
   end

end;

{------------------------------------------------------------------------}

////¸Þ¼¼Áö ´ÙÀÌ¾ó·Î±× ¹Ú½º
function  TFrmDlg.DMessageDlg (msgstr: string; DlgButtons: TMsgDlgButtons): TModalResult;
   procedure DoRunDice;
   var
      dr: TDirectDrawSurface;
      i: integer;
      flag: Boolean;
   begin

      if (DiceType = 2) then begin
         if DiceArr[0].DiceCount < 20 then begin
            if GetTickCount - DiceArr[0].DiceTime > 250 then begin
//               if DiceArr[0].DiceCount mod 2 = 1 then DiceArr[0].DiceCurrent := 1 + Random(3)
               DiceArr[0].DiceCurrent := DiceArr[0].DiceCount mod 3;
               DiceArr[0].DiceTime := GetTickCount;
               Inc (DiceArr[0].DiceCount);
            end;
         end else begin
            DiceArr[0].DiceCurrent := DiceArr[0].DiceResult-1;
            if GetTickCount - DiceArr[0].DiceTime > 3000 then
               DMsgDlg.Visible := FALSE;
         end;
      end
      else if RunDice = 1 then begin
         if DiceArr[0].DiceCount < 20 then begin
            if GetTickCount - DiceArr[0].DiceTime > 100 then begin
               if DiceArr[0].DiceCount mod 5 = 4 then DiceArr[0].DiceCurrent := 1 + Random(6)
               else DiceArr[0].DiceCurrent := 8 + DiceArr[0].DiceCount mod 5;
               DiceArr[0].DiceTime := GetTickCount;
               Inc (DiceArr[0].DiceCount);
            end;
         end else begin
            DiceArr[0].DiceCurrent := DiceArr[0].DiceResult;
            if GetTickCount - DiceArr[0].DiceTime > 3000 then
               DMsgDlg.Visible := FALSE;
         end;
      end else begin
         flag := TRUE;
         for i:=0 to RunDice-1 do begin
            if DiceArr[i].DiceCount < DiceArr[i].DiceLimit then begin
               if GetTickCount - DiceArr[i].DiceTime > 100 then begin
                  if DiceArr[i].DiceCount mod 5 = 4 then DiceArr[i].DiceCurrent := 1 + Random(6)
                  else DiceArr[i].DiceCurrent := 8 + DiceArr[i].DiceCount mod 5;
                  DiceArr[i].DiceTime := GetTickCount;
                  Inc (DiceArr[i].DiceCount);
               end;
               flag := FALSE;
            end else begin
               DiceArr[i].DiceCurrent := DiceArr[i].DiceResult;
               if GetTickCount - DiceArr[i].DiceTime < 4000 then
                  flag := FALSE;
            end;
         end;
         if flag then
            DMsgDlg.Visible := FALSE;
      end;
   end;
const
   XBase = 140;
var
   lx, ly, i, k: integer;
   d: TDirectDrawSurface;
begin
   lx := XBase;
   ly := 126;
   case DialogSize of
      0:  //ÀÛÀº°Å
         begin
            d := g_WGameInter.Images[1248];
            if d <> nil then begin
               DMsgDlg.SetImgIndex (g_WGameInter, 1248);
               DMsgDlg.Left := (g_FScreenWidth - d.Width) div 2;
               DMsgDlg.Top := (g_FScreenHeight - d.Height) div 2;
               msglx := (d.Width - g_DXCanvas.TextWidth(msgstr)) div 2;//39;
               msgly := (d.Height - g_DXCanvas.TextHeight(msgstr)) div 2;//38;
               lx := 90; //d.Width div 2 - 38; //XBase;
               ly := 36; //56;
            end;
         end;
      1:  //³Ð°í Å«°Å
         begin
            d := g_WGameInter.Images[1240];
            if d <> nil then begin
               DMsgDlg.SetImgIndex (g_WGameInter, 1240);
               DMsgDlg.Left := (g_FScreenWidth - d.Width) div 2;
               DMsgDlg.Top := (g_FScreenHeight - d.Height) div 2;
               DMsgDlgOk.SetImgIndex (g_WGameInter, 1241);
               msglx := 39;
               msgly := 38+5+50;
               lx := XBase;
               ly := 188;
            end;
         end;
      2:  //±æÀº°Å
         begin
            d := g_WGameInter.Images[1250];
            if d <> nil then begin
               DMsgDlg.SetImgIndex (g_WGameInter, 1250);
               DMsgDlg.Left := (g_FScreenWidth - d.Width) div 2;
               DMsgDlg.Top := (g_FScreenHeight - d.Height) div 2;
               DMsgDlgOk.SetImgIndex (g_WGameInter, 1251);
               msglx := 50;
               msgly := 110;
               lx := 131;
               ly := 429;
            end;
         end;
   end;
   MsgText := msgstr;
   ViewDlgEdit := FALSE;
   DMsgDlg.Floating := TRUE;   //¸Þ¼¼Áö ¹Ú½º°¡ ¶°´Ù´Ô..
   DMsgDlgOk.Visible := FALSE;
   DMsgDlgYes.Visible := FALSE;
   DMsgDlgCancel.Visible := FALSE;
   DMsgDlgNo.Visible := FALSE;
   DMsgDlg.Left := (g_FScreenWidth - DMsgDlg.Width) div 2;
   DMsgDlg.Top := (g_FScreenHeight - DMsgDlg.Height) div 2;

   for i:=0 to RunDice-1 do begin
      DiceArr[i].DiceCount := 0;
      DiceArr[i].DiceLimit := 10 + Random(RunDice+2) * 5;
      DiceArr[i].DiceCurrent := 1;
      DiceArr[i].DiceTime := GetTickCount;
   end;

   if mbCancel in DlgButtons then begin
      DMsgDlgCancel.Left := lx;
      DMsgDlgCancel.Top := ly;
      DMsgDlgCancel.Visible := TRUE;
      lx := lx - 110;
   end;
   if mbNo in DlgButtons then begin
      DMsgDlgNo.Left := lx;
      DMsgDlgNo.Top := ly;
      DMsgDlgNo.Visible := TRUE;
      lx := lx - 110;
   end;
   if mbYes in DlgButtons then begin
      DMsgDlgYes.Left := lx;
      DMsgDlgYes.Top := ly;
      DMsgDlgYes.Visible := TRUE;
      lx := lx - 110;
   end;
   if (mbOk in DlgButtons) or (lx = XBase) then begin
      DMsgDlgOk.Left := lx;
      DMsgDlgOk.Top := ly;
      DMsgDlgOk.Visible := TRUE;
      lx := lx - 110;
   end;
   HideAllControls;
   DMsgDlg.ShowModal;

   if mbAbort in DlgButtons then begin
      ViewDlgEdit := TRUE; //¿¡µðÆ® ÄÁÆ®·ÑÀÌ º¸¿©¾ß ÇÏ´Â °æ¿ì.
      DMsgDlg.Floating := FALSE;
      with EdDlgEdit do begin
         Text := '';
         Width := DMsgDlg.Width - 50;
         Left := (g_FScreenWidth - EdDlgEdit.Width) div 2;
         Top  := (g_FScreenHeight - EdDlgEdit.Height) div 2 + 105;
         EdDlgEdit.MaxLength := MsgDlgMaxStr;
      end;
   end;
   Result := mrOk;
   k := 0;
   while TRUE do begin
      if not DMsgDlg.Visible then break;
      //FrmMain.DXTimerTimer (self, 0);
//      FrmMain.ProcOnIdle;
      Application.ProcessMessages;
      Inc(k);
      if k = 5 then begin
         FrmMain.MsgProg;
         k := 0;
      end;

      if BoMsgDlgTimeCheck then begin
         if MsgDlgClickTime < GetTickCount then begin
            DMsgDlg.DialogResult := mrNo;
            BoMsgDlgTimeCheck := False;
            MsgDlgClickTime := GetTickCount;
            DMsgDlg.Visible := False;
            break;
         end;
      end;
      if RunDice > 0 then begin
         BoDrawDice := TRUE;
         for i:=0 to RunDice-1 do begin
            DiceArr[i].DiceLeft := DMsgDlg.Width div 2 + 6 - (33 * RunDice) div 2 + 33 * i; // - 15;  //37
            DiceArr[i].DiceTop  := DMsgDlg.Height div 2 - 14;  //25
         end;
         DoRunDice;
      end;
      if Application.Terminated then exit;
   end;

   EdDlgEdit.Visible := FALSE;
   RestoreHideControls;
   DlgEditText := EdDlgEdit.Text;
   if PlayScene.EdChat.Visible then PlayScene.EdChat.SetFocus;
   ViewDlgEdit := FALSE;
   Result := DMsgDlg.DialogResult;
   DialogSize := 1; //±âº»»óÅÂ
   RunDice := 0;
   BoDrawDice := FALSE;
end;

function  TFrmDlg.OnlyMessageDlg (msgstr: string; DlgButtons: TMsgDlgButtons): TModalResult;
const
   XBase = 329;
var
   lx, ly, i: integer;
   d: TDirectDrawSurface;
begin
   lx := XBase;
   ly := 126;
   case DialogSize of
      1:  //³Ð°í Å«°Å
         begin
            d := g_WGameInter.Images[1240];
            if d <> nil then begin
               DMsgDlg.SetImgIndex (g_WGameInter, 1240);
               DMsgDlg.Left := (SCREENWIDTH - d.Width) div 2;
               DMsgDlg.Top := (SCREENHEIGHT - d.Height) div 2;
               msglx := 39;
               msgly := 38;
               lx := XBase;
               ly := 143;
            end;
         end;
   end;
   MsgText := msgstr;
   ViewDlgEdit := FALSE;
   DMsgDlg.Floating := TRUE;   //¸Þ¼¼Áö ¹Ú½º°¡ ¶°´Ù´Ô..
   DMsgDlgOk.Visible := FALSE;
   DMsgDlgYes.Visible := FALSE;
   DMsgDlgCancel.Visible := FALSE;
   DMsgDlgNo.Visible := FALSE;
   DMsgDlg.Left := (SCREENWIDTH - DMsgDlg.Width) div 2;
   DMsgDlg.Top := (SCREENHEIGHT - DMsgDlg.Height) div 2;

   if (mbOk in DlgButtons) or (lx = XBase) then begin
      DMsgDlgOk.Left := lx;
      DMsgDlgOk.Top := ly;
      DMsgDlgOk.Visible := TRUE;
      lx := lx - 110;
   end;
   HideAllControls;
   Result := mrOk;
   DMsgDlg.ShowModal;
   while TRUE do begin
      if not DMsgDlg.Visible then break;
      //FrmMain.DXTimerTimer (self, 0);
//      FrmMain.ProcOnIdle;
      Application.ProcessMessages;

{      if BoMsgDlgTimeCheck then begin
         if MsgDlgClickTime < GetTickCount then begin
            DMsgDlg.DialogResult := mrNo;
            BoMsgDlgTimeCheck := False;
            MsgDlgClickTime := GetTickCount;
            DMsgDlg.Visible := False;
            break;
         end;
      end;}
      if Application.Terminated then exit;
   end;

   EdDlgEdit.Visible := FALSE;
   RestoreHideControls;
   DlgEditText := EdDlgEdit.Text;
   if PlayScene.EdChat.Visible then PlayScene.EdChat.SetFocus;
   ViewDlgEdit := FALSE;
   Result := DMsgDlg.DialogResult;
   DialogSize := 1; //±âº»»óÅÂ
   RunDice := 0;
   BoDrawDice := FALSE;
end;

procedure TFrmDlg.DMsgDlgOkClick(Sender: TObject; X, Y: Integer);
begin
   if Sender = DMsgDlgOk then DMsgDlg.DialogResult := mrOk;
   if Sender = DMsgDlgYes then DMsgDlg.DialogResult := mrYes;
   if Sender = DMsgDlgCancel then DMsgDlg.DialogResult := mrCancel;
   if Sender = DMsgDlgNo then DMsgDlg.DialogResult := mrNo;

   if GameClose then begin
//      FrmMain.CloseNPMon;
      FrmMain.Close;
   end;

   BoMsgDlgTimeCheck := False;
   MsgDlgClickTime := GetTickCount;
   DMsgDlg.Visible := FALSE;
end;

procedure TFrmDlg.DMsgDlgKeyDown(Sender: TObject; var Key: Word;
  Shift: TShiftState);
begin
   if Key = 13 then begin
      //2003/02/11 OK/Cancel¿¡¼­´Â ¿£ÅÍ¸¦ OK·Î...
      if DMsgDlgOk.Visible and not (DMsgDlgYes.Visible {or DMsgDlgCancel.Visible} or DMsgDlgNo.Visible) then begin
         DMsgDlg.DialogResult := mrOk;
         DMsgDlg.Visible := FALSE;
      end;
      if DMsgDlgYes.Visible and not (DMsgDlgOk.Visible or DMsgDlgCancel.Visible ) then begin
         DMsgDlg.DialogResult := mrYes;
         DMsgDlg.Visible := FALSE;
      end;
   end;
   if Key = 27 then begin
      if DMsgDlgNo.Visible then begin
         DMsgDlg.DialogResult := mrNo;
         DMsgDlg.Visible := FALSE;
      end;
      if DMsgDlgCancel.Visible then begin
         DMsgDlg.DialogResult := mrCancel;
         DMsgDlg.Visible := FALSE;
      end;
   end;
end;

procedure TFrmDlg.DMsgDlgOkDirectPaint(Sender: TObject;
  dsurface: TDirectDrawSurface);
var
  d: TDirectDrawSurface;
begin
   with Sender as TDButton do begin
      if not Downed then
         d := WLib.Images[FaceIndex]
      else d := WLib.Images[FaceIndex+1];
      if d <> nil then
         dsurface.Draw (SurfaceX(Left), SurfaceY(Top), d.ClientRect, d, TRUE);
   end;
end;

procedure TFrmDlg.DMsgDlgDirectPaint(Sender: TObject;
  dsurface: TDirectDrawSurface);
var
  d, dr: TDirectDrawSurface;
  ly, px, py, i: integer;
  str, data: string;
begin
   with Sender as TDWindow do begin
      d := WLib.Images[FaceIndex];
      if d <> nil then
         dsurface.Draw (SurfaceX(Left), SurfaceY(Top), d.ClientRect, d, TRUE);
      if BoDrawDice then begin
         if DiceType = 1 then begin
            for i:=0 to RunDice-1 do begin
               dr := g_WInventory.GetCachedImage (140 + DiceArr[i].DiceCurrent - 1, px, py);
               if dr <> nil then begin
                  dsurface.Draw (SurfaceX(Left) + DiceArr[i].DiceLeft + px - 14,
                              SurfaceY(Top) + DiceArr[i].DiceTop + py + 38,
                              dr.ClientRect,
                              dr, TRUE);
               end;
            end;
         end
         else if DiceType = 2 then begin
            dr := g_WBagItem.GetCachedImage (887 + DiceArr[0].DiceCurrent, px, py);
            if dr <> nil then begin
               dsurface.Draw (SurfaceX(Left) + DiceArr[0].DiceLeft + px - 14,
                           SurfaceY(Top) + DiceArr[0].DiceTop + py + 38,
                           dr.ClientRect,
                           dr, TRUE);
            end;
         end;
      end;
//      SetBkMode (dsurface.Canvas.Handle, TRANSPARENT);
      ly := msgly;
      str := MsgText;
      while TRUE do begin
         if str = '' then break;
         str := GetValidStr3 (str, data, ['\']);
         if data <> '' then
            g_DXCanvas.BoldTextOut (SurfaceX(Left+msglx), SurfaceY(Top+ly), clWhite, data);
         ly := ly + 14;
      end;
//      dsurface.Canvas.Release;
   end;
   if ViewDlgEdit then begin
      if not EdDlgEdit.Visible then begin
         EdDlgEdit.Visible := TRUE;
         EdDlgEdit.SetFocus;
      end;
   end;
end;

{------------------------------------------------------------------------}

//·Î±×ÀÎ Ã¢

procedure TFrmDlg.DLoginNewDirectPaint(Sender: TObject;
  dsurface: TDirectDrawSurface);
var
  d: TDirectDrawSurface;
begin
  with Sender as TDButton do begin
    if TDButton(Sender).Downed or (MouseEntry = msIn) then
      d := WLib.Images[FaceIndex + 1]
    else
      d := WLib.Images[FaceIndex];

    if d <> nil then
      dsurface.Draw(SurfaceX(Left), SurfaceY(Top), d.ClientRect, d, TRUE);
  end;
end;

procedure TFrmDlg.DLoginNewInRealArea(Sender: TObject; X, Y: Integer; var IsRealArea: Boolean);
var
   d: TDirectDrawSurface;
begin
  with Sender as TDButton do begin
    d := WLib.Images[FaceIndex];
    if (X >= 0) and (Y >= 0) and (X <= d.Width) and
      (Y <= d.Height) then
         IsRealArea := TRUE
    else IsRealArea := FALSE;
  end;
end;

procedure TFrmDlg.DLoginNewClick(Sender: TObject; X, Y: Integer);
begin
  ShellExecute(Application.Handle,nil,PAnsiChar(MainParam2),nil,nil,SW_SHOWNORMAL);
  Application.Minimize;
end;

procedure TFrmDlg.DLoginOkClick(Sender: TObject; X, Y: Integer);
begin
  LoginScene.OkClick;
end;

procedure TFrmDlg.DLoginOkDirectPaint(Sender: TObject; dsurface: TDirectDrawSurface);
var
  d: TDirectDrawSurface;
  rc: TRect;
begin
  with Sender as TDButton do begin
    if TDButton(Sender).Downed or (MouseEntry = msIn) then
      d := WLib.Images[FaceIndex + 1]
    else
      d := WLib.Images[FaceIndex];

    if d <> nil then
      dsurface.Draw(SurfaceX(Left), SurfaceY(Top), d.ClientRect, d, TRUE);

    if MouseEntry = msIn then begin
      rc.Left := SurfaceX(Left);
      rc.Top := SurfaceY(Top);
      rc.Right := rc.Left + d.Width;
      rc.Bottom := rc.Top + d.Height;
      g_DXCanvas.Draw2DRect(rc, $C89664, fxBlend);
//      g_DXCanvas.RoundRect(rc.Left,rc.Top,rc.Right,rc.Bottom,$FF326496);
      g_DXCanvas.Draw2DRectLine(rc, $FF966432);
    end;
  end;
end;

procedure TFrmDlg.DLoginCloseClick(Sender: TObject; X, Y: Integer);
begin
  FrmMain.Close;
end;

procedure TFrmDlg.DLogInDirectPaint(Sender: TObject; dsurface: TDirectDrawSurface);
var
  d, dd: TDirectDrawSurface;
  i: integer;
begin
  with DLogIn do begin
    d := WLib.Images[FaceIndex];
    if d <> nil then
      dsurface.Draw(SurfaceX(Left), SurfaceY(Top), d.ClientRect, d, $70B8B8B8, Blend_BrightAdd);

    dd := WLib.Images[2];
    if dd <> nil then
      dsurface.Draw(SurfaceX(Left + 100), SurfaceY(Top + 70), dd.ClientRect, dd, True);

    g_DXCanvas.RoundRect(SurfaceX(Left + 1), SurfaceY(Top), SurfaceX(Left + d.Width), SurfaceY(Top + d.Height), $FF636363);
  end;
end;

procedure TFrmDlg.DLoginChgPwClick(Sender: TObject; X, Y: Integer);
begin
  ShellExecute(Application.Handle, nil, PAnsiChar(MainParam3), nil, nil, SW_SHOWNORMAL);
  Application.Minimize;
end;

procedure TFrmDlg.DLoginNewClickSound(Sender: TObject; Clicksound: TClickSound);
begin
  case Clicksound of
    csNorm:
      PlaySound(s_norm_button_click);
    csStone:
      PlaySound(s_rock_button_click);
    csGlass:
      PlaySound(s_glass_button_click);
  end;
end;


{------------------------------------------------------------------------}
//¼­¹ö ¼±ÅÃ Ã¢

procedure TFrmDlg.ShowSelectServerDlg;
begin
   DSelServerDlg.Visible := TRUE;
//   BoFirstShowOnServerSel := TRUE;
end;

procedure TFrmDlg.DSelServerDlgClick(Sender: TObject; X, Y: Integer);
var
   lx, ly, idx: integer;
   svname: string;
begin
   if ServerCount < 1 then exit;
   lx := DSelServerDlg.LocalX (X) - DSelServerDlg.Left;
   ly := DSelServerDlg.LocalY (Y) - DSelServerDlg.Top;
   idx := 0;
   if (lx >= 0) and (lx <= 130) and (ly >= 10) and (ly <= (10 + (30 * ServerCount))) then begin
      if ServerSelectIndex > 0 then begin
         svname := ServerNameArr[ServerSelectIndex-1];

         if svname <> '' then begin
            if BO_FOR_TEST then begin
               svname := 'Çö¹«¼­¹ö';
            end;
            FrmMain.SendSelectServer (svname);
            DSelServerDlg.Visible := FALSE;
            ServerName := svname;
         end;
      end;
   end else begin
     ServerSelectIndex := - 1;
   end;
end;

procedure TFrmDlg.DSelServerDlgDirectPaint(Sender: TObject;
  dsurface: TDirectDrawSurface);
var
   d: TDirectDrawSurface;
   str: string;
   rc, src: TRect;
   FColor: TColor;
   i: Integer;
begin
  if ServerSelectEnabledAlpha then begin
    if ServerSelectAlpha < 255 then Inc(ServerSelectAlpha)
    else ServerSelectEnabledAlpha := False;
  end else begin
    if ServerSelectAlpha > 100 then Dec(ServerSelectAlpha)
    else ServerSelectEnabledAlpha := True;
  end;
  
  with DSelServerDlg do begin
    rc.Left := SurfaceX(Left);
    rc.Top := SurfaceY(Top);
    rc.Right := rc.Left + 130;
    rc.Bottom := rc.Top + (30 * ServerCount) + 20;
    g_DXCanvas.Draw2DRect(rc,$FF32C8C8, ServerSelectAlpha);
//    g_DXCanvas.RoundRect(rc.Left,rc.Top,rc.Right,rc.Bottom,$FF969696);
    g_DXCanvas.Draw2DRectLine(rc, $FF969696);

    if ServerSelectIndex > 0 then begin
      src.Left := SurfaceX(Left);
      src.Top := SurfaceY(Top) + 10 + ((ServerSelectIndex - 1) * 30);
      src.Right := src.Left + 130;
      src.Bottom := src.Top + 30;
      g_DXCanvas.Draw2DRect(src ,clWhite, 120);
      g_DXCanvas.Draw2DRectLine(src ,TColor($C86464));
//      g_DXCanvas.RoundRect(src.Left, src.Top, src.Right, src.Bottom, TColor($C86464));
    end;

    with g_DXCanvas do begin
      for I := 0 to ServerCount - 1 do begin
        if I = (ServerSelectIndex - 1) then FColor := TColor($FF6464)
        else FColor := TColor($303030);
        str := Trim(ServerCaptionArr[I]);
        TextOut(SurfaceX(Left) + 15,//(DSelServerDlg.Width- TextWidth(str)) div 2,
                SurfaceY(Top) + 10 + (I * 30) + (30 - TextHeight(str)) div 2,
                FColor,
                str);
      end;
    end;
  end;
end;

procedure TFrmDlg.DSelServerDlgInRealArea(Sender: TObject; X, Y: Integer;
  var IsRealArea: Boolean);
begin
  if (X >= 0) and (X <= 130) and (Y >= 10) and (Y <= (20 + (30 * 8))) then IsRealArea := TRUE
  else IsRealArea := FALSE;
end;

procedure TFrmDlg.DSelServerDlgMouseMove(Sender: TObject; Shift: TShiftState; X,
  Y: Integer);
var
  lx, ly, idx: integer;
begin
  ServerSelectIndex := -1;
  if ServerCount < 1 then exit;
  lx := DSelServerDlg.LocalX(X) - DSelServerDlg.Left;
  ly := DSelServerDlg.LocalY(Y) - DSelServerDlg.Top;
  idx := 0;
  if (lx >= 0) and (lx <= 130) and (ly >= 10) and (ly <= (10 + (30 * ServerCount))) then begin
//    FrmMain.Caption := 'X='+ IntToStr(lx) +' Y='+ IntToStr(lY);
    idx := Trunc((ly + 17) div 30);
    if idx > 0 then begin
      ServerSelectIndex := idx;
    end;
  end else begin
    ServerSelectIndex := -1;
  end;
end;


procedure TFrmDlg.DShowMapDirectPaint(Sender: TObject;
  dsurface: TDirectDrawSurface);
var
   d: TDirectDrawSurface;
begin
   with DShowMap do begin
      if DShowMap.Downed then begin
         d := WLib.Images[FaceIndex];
         if d <> nil then
            dsurface.Draw (SurfaceX(Left), SurfaceY(Top), d.ClientRect, d, TRUE);
      end;
   end;
end;

procedure TFrmDlg.DSServer1Click(Sender: TObject; X, Y: Integer);
var
   svname: string;
begin
   svname := '';
   if TDButton(Sender).Tag = 0 then svname := ServerNameArr[0];
   if TDButton(Sender).Tag = 1 then svname := ServerNameArr[1];
   if TDButton(Sender).Tag = 2 then svname := ServerNameArr[2];
   if TDButton(Sender).Tag = 3 then svname := ServerNameArr[3];
   if TDButton(Sender).Tag = 4 then svname := ServerNameArr[4];
   if TDButton(Sender).Tag = 5 then svname := ServerNameArr[5];
   if TDButton(Sender).Tag = 6 then svname := ServerNameArr[6];
   if TDButton(Sender).Tag = 7 then svname := ServerNameArr[7];

   if TDButton(Sender).Tag = 8 then svname := ServerNameArr[8];
   if TDButton(Sender).Tag = 9 then svname := ServerNameArr[9];
   if TDButton(Sender).Tag = 10 then svname := ServerNameArr[10];
   if TDButton(Sender).Tag = 11 then svname := ServerNameArr[11];
   if TDButton(Sender).Tag = 12 then svname := ServerNameArr[12];
   if TDButton(Sender).Tag = 13 then svname := ServerNameArr[13];
   if TDButton(Sender).Tag = 14 then svname := ServerNameArr[14];
   if TDButton(Sender).Tag = 15 then svname := ServerNameArr[15];

   if TDButton(Sender).Tag = 16 then svname := ServerNameArr[16];
   if TDButton(Sender).Tag = 17 then svname := ServerNameArr[17];
   if TDButton(Sender).Tag = 18 then svname := ServerNameArr[18];
   if TDButton(Sender).Tag = 19 then svname := ServerNameArr[19];
   if TDButton(Sender).Tag = 20 then svname := ServerNameArr[20];
   if TDButton(Sender).Tag = 21 then svname := ServerNameArr[21];
   if TDButton(Sender).Tag = 22 then svname := ServerNameArr[22];
   if TDButton(Sender).Tag = 23 then svname := ServerNameArr[23];

   if TDButton(Sender).Tag = 24 then svname := ServerNameArr[24];
   if TDButton(Sender).Tag = 25 then svname := ServerNameArr[25];
   if TDButton(Sender).Tag = 26 then svname := ServerNameArr[26];
   if TDButton(Sender).Tag = 27 then svname := ServerNameArr[27];

   if svname <> '' then begin
      if BO_FOR_TEST then begin
         svname := 'Çö¹«¼­¹ö';
      end;
      FrmMain.SendSelectServer (svname);
      DSelServerDlg.Visible := FALSE;
      ServerName := svname;
   end;
end;

procedure TFrmDlg.DEngServer1Click(Sender: TObject; X, Y: Integer);
var
   svname: string;
begin
   svname := 'Çö¹«¼­¹ö';

   if svname <> '' then begin
      if BO_FOR_TEST then begin
         svname := 'Çö¹«¼­¹ö';
      end;
      FrmMain.SendSelectServer (svname);
      DSelServerDlg.Visible := FALSE;
      ServerName := svname;
   end;
end;

procedure TFrmDlg.DSSrvCloseClick(Sender: TObject; X, Y: Integer);
begin
   DSelServerDlg.Visible := FALSE;
//   FrmMain.CloseNPMon;
   FrmMain.Close;
end;


{------------------------------------------------------------------------}
//»õ °èÁ¤ ¸¸µé±â Ã¢


procedure TFrmDlg.DscSelect1DirectPaint(Sender: TObject; dsurface: TDirectDrawSurface);
var
  d: TDirectDrawSurface;
  rc: TRect;
begin
  with Sender as TDButton do begin
    if Downed then begin
      d := WLib.Images[FaceIndex];
    end else if MouseEntry = msIn then begin
      d := WLib.Images[FaceIndex - 1];
    end else
      d := WLib.Images[FaceIndex];

    if d <> nil then
      dsurface.Draw(Left, Top, d.ClientRect, d, TRUE);

    if MouseEntry = msIn then begin
      rc.Left := SurfaceX(Left);
      rc.Top := SurfaceY(Top);
      rc.Right := rc.Left + d.Width;
      rc.Bottom := rc.Top + d.Height;
      g_DXCanvas.Draw2DRect(rc,$C89664,Blend_BrightAdd);
//      g_DXCanvas.RoundRect(rc.Left,rc.Top,rc.Right,rc.Bottom,$FF326496);
      g_DXCanvas.Draw2DRectLine(rc,$FF966432);
    end;
  end;
end;

procedure TFrmDlg.DscStartInRealArea(Sender: TObject; X, Y: Integer; var IsRealArea: Boolean);
var
   d: TDirectDrawSurface;
begin
  with Sender as TDButton do begin
    d := WLib.Images[FaceIndex];
    if (X >= 0) and (Y >= 0) and (X <= d.Width) and
      (Y <= d.Height) then
         IsRealArea := TRUE
    else IsRealArea := FALSE;
  end;
end;

procedure TFrmDlg.DscSelect1Click(Sender: TObject; X, Y: Integer);
begin
//   if Sender = DscSelect1 then SelectChrScene.SelChrSelect1Click;
//   if Sender = DscSelect2 then SelectChrScene.SelChrSelect2Click;
//   if Sender = DscSelect3 then SelectChrScene.SelChrSelect3Click;
   if Sender = DscStart then begin
     Video.Play('.\Data\StartGame.dat', 0, 0, 640, 480);
     FrmMain.TimerBrowserUpdate.Enabled := True;
//     SelectChrScene.SelChrStartClick;
     ConnectionStep := cnsPlay;
     DScreen.ChangeScene (stLoading);
   end;
   if Sender = DscNewChr then SelectChrScene.SelChrNewChrClick;
   if Sender = DscEraseChr then SelectChrScene.SelChrEraseChrClick;
//   if Sender = DscCredits then SelectChrScene.SelChrCreditsClick;
   if Sender = DscExit then SelectChrScene.SelChrExitClick;
end;


{------------------------------------------------------------------------}
//»õ Ä³¸¯ÅÍ ¸¸µé±â Ã¢


procedure TFrmDlg.DccCloseDirectPaint(Sender: TObject;
  dsurface: TDirectDrawSurface);
var
   d: TDirectDrawSurface;
begin
   with Sender as TDButton do begin
      if Downed then begin
         d := WLib.Images[FaceIndex];
         if d <> nil then
            dsurface.Draw (SurfaceX(Left), SurfaceY(Top), d.ClientRect, d, TRUE);
      end else begin
         d := WLib.Images[FaceIndex];
         if Sender = DccWarrior then begin
            with SelectChrScene do
               if m_stSelectChrInfo[NewIndex].UserChr.Job = 0 then d := WLib.Images[93];
         end;
         if Sender = DccWizzard then begin
            with SelectChrScene do
               if m_stSelectChrInfo[NewIndex].UserChr.Job = 1 then d := WLib.Images[96];
         end;
         if Sender = DccMonk then begin
            with SelectChrScene do
               if m_stSelectChrInfo[NewIndex].UserChr.Job = 2 then d := WLib.Images[99];
         end;
         if Sender = DccMale then begin
            with SelectChrScene do
               if m_stSelectChrInfo[NewIndex].UserChr.Sex = 0 then d := WLib.Images[58];
         end;
         if Sender = DccFemale then begin
            with SelectChrScene do
               if m_stSelectChrInfo[NewIndex].UserChr.Sex = 1 then d := WLib.Images[59];
         end;
         if d <> nil then
            dsurface.Draw (SurfaceX(Left), SurfaceY(Top), d.ClientRect, d, TRUE);
      end;
   end;
end;

procedure TFrmDlg.DccOkDirectPaint(Sender: TObject;
  dsurface: TDirectDrawSurface);
var
  d: TDirectDrawSurface;
begin
  with Sender as TDButton do begin
    if Downed then begin
      d := WLib.Images[FaceIndex + 2];
    end else if MouseEntry = msIn then begin
      d := WLib.Images[FaceIndex + 1];
    end else
      d := WLib.Images[FaceIndex];

    if d <> nil then
      dsurface.Draw(Left, Top, d.ClientRect, d, TRUE);
  end;
end;


procedure TFrmDlg.DccWarriorMouseMove(Sender: TObject; Shift: TShiftState; X,
  Y: Integer);
var
  sx, sy: integer;
begin
  with Sender as TDButton do begin
    sx := SurfaceX(Left) + DCreateChr.SurfaceX(DCreateChr.Left) + 30;
    sy := SurfaceY(Top) + DCreateChr.SurfaceX(DCreateChr.Top) + 20;
    DScreen.ShowHint(sx, sy, CMsg.GetMsg(200+TDButton(Sender).Tag), $393800, True);
  end;
end;

procedure TFrmDlg.DccCloseClick(Sender: TObject; X, Y: Integer);
begin
   if Sender = DccClose then SelectChrScene.SelChrNewClose;
   if Sender = DccWarrior then SelectChrScene.SelChrNewJob (0);
   if Sender = DccWizzard then SelectChrScene.SelChrNewJob (1);
   if Sender = DccMonk then SelectChrScene.SelChrNewJob (2);
   if Sender = DccReserved then SelectChrScene.SelChrNewJob (3);
   if Sender = DccMale then SelectChrScene.SelChrNewSex (0);
   if Sender = DccFemale then SelectChrScene.SelChrNewSex (1);
//   if Sender = DccLeftHair then SelectChrScene.SelChrNewPrevHair;
//   if Sender = DccRightHair then SelectChrScene.SelChrNewNextHair;
   if Sender = DccOk then SelectChrScene.SelChrNewOk;
end;

{------------------------------------------------------------------------}

//»óÅÂÃ¢...

{------------------------------------------------------------------------}


procedure TFrmDlg.DStateWinDirectPaint(Sender: TObject;
  dsurface: TDirectDrawSurface);
var
   i, l, m, pgidx, magline, bbx, bby, mmx, idx, ax, ay, trainlv, tx, ty: integer;
   pm: PTClientMagic;
   d: TDirectDrawSurface;
   hcolor, old, keyimg: integer;
   iname, d1, d2, d3, d4, str, fstr: string;
   useable: Boolean;
   FColor:TColor;
   nLeft, nTop: integer;
   nCnt: integer;
   wLooks: word;
begin
  if Myself = nil then exit;
  with DStateWin do begin
    d := WLib.Images[FaceIndex];
    if d <> nil then
      dsurface.Draw(SurfaceX(Left), SurfaceY(Top), d.ClientRect, d, $ECFFFFFF, True);

    if GetTickCount - dwEquipEffectTime > 80 then begin
      dwEquipEffectTime := GetTickCount;
      nWeaponEffect := nWeaponEffect + 1;
      if nWeaponEffect > 10-1 then
        nWeaponEffect := 0;
    end;

    nLeft := Left + ((d.Width - 328) div 2);
    nTop := Top + ((d.Height - 466) div 2);

    pgidx := 0;
    if Myself <> nil then
       if Myself.Sex = 1 then pgidx := 1;

    bbx := nLeft + 81;
    bby := nTop + 198;

    if UseItems[U_DRESS].S.Name <> '' then begin
      wLooks := UseItems[U_DRESS].S.Looks;
      for nCnt := 0 to 1 do begin
        if wLooks = w11Img[nCnt] then begin
          d := g_WProgUse.GetCachedImage (wBLightImg11[nCnt], ax, ay);
          if d <> nil then
            DrawBlend (dsurface, SurfaceX(bbx+ax), SurfaceY(bby+ay), d, 1);
          Break;
        end;
      end;

      wLooks := UseItems[U_DRESS].S.Looks;
      for nCnt := 0 to 6 - 1 do begin
        if wLooks = w33Img[nCnt] then begin
          d := g_WProgUse.GetCachedImage (wBLightImg33[nCnt], ax, ay);
          if d <> nil then
            DrawBlend (dsurface, SurfaceX(bbx+ax), SurfaceY(bby+ay), d, 1);
          Break;
        end;
      end;

      wLooks := UseItems[U_DRESS].S.Looks;
      for nCnt := 0 to 6 - 1 do begin
        if wLooks = w44Img[nCnt] then begin
          d := g_WProgUse.GetCachedImage (wBLightImg44[nCnt], ax, ay);
          if d <> nil then
            DrawBlend (dsurface, SurfaceX(bbx+ax), SurfaceY(bby+ay), d, 1);
          Break;
        end;
      end;

      wLooks := UseItems[U_DRESS].S.Looks;
      for nCnt := 0 to 1 do begin
        if wLooks = w50Img[nCnt] then begin
          d := g_WProgUse.GetCachedImage (wBLightImg50[nCnt], ax, ay);
          if d <> nil then
            DrawBlend (dsurface, SurfaceX(bbx+ax), SurfaceY(bby+ay), d, 1);
          Break;
        end;
      end;

      wLooks := UseItems[U_DRESS].S.Looks;
      for nCnt := 0 to 1 do begin
        if wLooks = w51Img[nCnt] then begin
          d := g_WProgUse.GetCachedImage (wBLightImg51[nCnt], ax, ay);
          if d <> nil then
            DrawBlend (dsurface, SurfaceX(bbx+ax), SurfaceY(bby+ay), d, 1);
          Break;
        end;
      end;

      wLooks := UseItems[U_DRESS].S.Looks;
      case MySelf.Job of
        _JOB_JUNSA: begin
          wBLightImg58[0] := 280;
          wBLightImg58[1] := 290;
        end;
        _JOB_SULSA:begin
          wBLightImg58[0] := 281;
          wBLightImg58[1] := 291;
        end;
        _JOB_DOSA:begin
          wBLightImg58[0] := 282;
          wBLightImg58[1] := 292;
        end;
      end;
      for nCnt := 0 to 2 - 1 do begin
        if wLooks = w58Img[nCnt] then begin
          d := g_WProgUse.GetCachedImage (wBLightImg58[nCnt], ax, ay);
          if d <> nil then
            DrawBlend (dsurface, SurfaceX(bbx+ax), SurfaceY(bby+ay), d, 1);
          Break;
        end;
      end;

      wLooks := UseItems[U_DRESS].S.Looks;
      for nCnt := 0 to 6 - 1 do begin
        if wLooks = w44Img[nCnt] then begin
          d := g_WProgUse.GetCachedImage (wBLightImg44[nCnt], ax, ay);
          if d <> nil then
            DrawBlend (dsurface, SurfaceX(bbx+ax), SurfaceY(bby+ay), d, 1);
          Break;
        end;
      end;
    end;
    d := g_WProgUse.GetCachedImage(pgidx, ax, ay);
    if d <> nil then
       dsurface.Draw (SurfaceX(bbx+ax), SurfaceY(bby+ay), d.ClientRect, d, TRUE);

    if UseItems[U_DRESS].S.Name <> '' then begin
      idx := UseItems[U_DRESS].S.Looks; //¿Ê if Myself.Sex = 1 then idx := 80; //¿©ÀÚ¿Ê
      if idx >= 0 then begin
        d := g_WEquip.GetCachedImage (idx, ax, ay);
        if d <> nil then
          dsurface.Draw (SurfaceX(bbx+ax), SurfaceY(bby+ay), d.ClientRect, d, TRUE);
      end;
    end;

//    if (UseItems[U_DRESS].S.Looks = 982) or (UseItems[U_DRESS].S.Looks <> 983) then begin
//      idx := 100;
//      if idx > 0 then begin
//        d := g_WProgUse.GetCachedImage (idx, ax, ay);
//        if d <> nil then
//          DrawBlend (dsurface, SurfaceX(bbx+ax), SurfaceY(bby+ay), d, 1);
//      end;
//    end;

    
//    DScreen.AddChatBoardString ('UseItems[U_DRESS].S.Looks=> '+IntToStr(UseItems[U_DRESS].S.Looks), clYellow, clRed);
//    if (UseItems[U_DRESS].S.Name = '') or
//      ((UseItems[U_DRESS].S.Looks <> 597) and (UseItems[U_DRESS].S.Looks <> 607)) then begin
//      idx := 440 + Myself.Hair div 2; //¸Ó¸® ½ºÅ¸ÀÏ
//      if Myself.Sex = 1 then idx := 480 + Myself.Hair div 2;
//      if idx > 0 then begin
//        d := g_WProgUse.GetCachedImage (idx, ax, ay);
//        if d <> nil then
//          dsurface.Draw (SurfaceX(bbx+ax), SurfaceY(bby+ay), d.ClientRect, d, TRUE);
//      end;
//    end;

    if UseItems[U_WEAPON].S.Name <> '' then begin
      idx := UseItems[U_WEAPON].S.Looks;
      if idx >= 0 then begin
        d := g_WEquip.GetCachedImage (idx, ax, ay);
        if d <> nil then
           dsurface.Draw (SurfaceX(bbx+ax), SurfaceY(bby+ay), d.ClientRect, d, TRUE);
      end;
      if idx = 1076 then begin
        d := g_WProgUse.GetCachedImage (420+nWeaponEffect, ax, ay);
        if d <> nil then DrawBlend (dsurface, SurfaceX(bbx+ax), SurfaceY(bby+ay), d, 1);
      end;
    end;
    if UseItems[U_HELMET].S.Name <> '' then begin
      idx := UseItems[U_HELMET].S.Looks;
      if idx >= 0 then begin
        d := g_WEquip.GetCachedImage (idx, ax, ay);
        if d <> nil then
          dsurface.Draw (SurfaceX(bbx+ax), SurfaceY(bby+ay), d.ClientRect, d, TRUE);
      end;
    end;

//         1: begin //´É·ÂÄ¡
//            l := Left + 112; //66;
//            m := Top + 115;
//            with g_DXCanvas do begin
//               TextOut (SurfaceX(l+0), SurfaceY(m+0), clWhite, IntToStr(Lobyte(Myself.Abil.AC)) + '-' + IntToStr(Hibyte(Myself.Abil.AC)));
//               TextOut (SurfaceX(l+0), SurfaceY(m+22), clWhite, IntToStr(Lobyte(Myself.Abil.MAC)) + '-' + IntToStr(Hibyte(Myself.Abil.MAC)));
//               TextOut (SurfaceX(l+0), SurfaceY(m+22*2), clWhite, IntToStr(Lobyte(Myself.Abil.DC)) + '-' + IntToStr(Hibyte(Myself.Abil.DC)));
//               TextOut (SurfaceX(l+0), SurfaceY(m+22*3), clWhite, IntToStr(Lobyte(Myself.Abil.MC)) + '-' + IntToStr(Hibyte(Myself.Abil.MC)));
//               TextOut (SurfaceX(l+0), SurfaceY(m+22*4), clWhite, IntToStr(Lobyte(Myself.Abil.SC)) + '-' + IntToStr(Hibyte(Myself.Abil.SC)));
//               TextOut (SurfaceX(l+0), SurfaceY(m+22*5), clWhite, IntToStr(Myself.Abil.HP) + '/' + IntToStr(Myself.Abil.MaxHP));
//               TextOut (SurfaceX(l+0), SurfaceY(m+22*6), clWhite, IntToStr(Myself.Abil.MP) + '/' + IntToStr(Myself.Abil.MaxMP));
//            end;
//         end;
//         2: begin //´É·ÂÄ¡ ¼³¸íÃ¢
//            bbx := Left + 38;
//            bby := Top + 59;
//            d := g_WProgUse.Images[382];
//            if d <> nil then
//               dsurface.Draw (SurfaceX(bbx), SurfaceY(bby), d.ClientRect, d, FALSE);
//
//            bbx := bbx + 20;
//            bby := bby + 21;
//            with g_DXCanvas do begin
////               SetBkMode (Handle, TRANSPARENT);
//               mmx := bbx + 85;
//
//               TextOut (bbx, bby, clWhite, '°æÇè');
//               TextOut (mmx, bby, clSilver, Format('%2.2f',[Myself.Abil.Exp/Myself.Abil.MaxExp*100]) + '%');
////             TextOut (mmx, bby, FloatToStrFixFmt (100 * Myself.Abil.Exp / Myself.Abil.MaxExp, 3, 2) + '%');
//               //TextOut (bbx, bby+14*1, 'ÃÖ´ë°æÇè');
//               //TextOut (mmx, bby+14*1, IntToStr(Myself.Abil.MaxExp));
//
//               TextOut (bbx, bby+14*1, clSilver, '°¡¹æ¹«°Ô');
//               if Myself.Abil.Weight > Myself.Abil.MaxWeight then
//                 TextOut (mmx, bby+14*1, clRed, IntToStr(Myself.Abil.Weight) + '/' + IntToStr(Myself.Abil.MaxWeight))
//               else
//                 TextOut (mmx, bby+14*1, clSilver, IntToStr(Myself.Abil.Weight) + '/' + IntToStr(Myself.Abil.MaxWeight));
//
//               TextOut (bbx, bby+14*2, clSilver, 'Âø¿ë¹«°Ô');
//               if Myself.Abil.WearWeight > Myself.Abil.MaxWearWeight then
//                 TextOut (mmx, bby+14*2, clRed, IntToStr(Myself.Abil.WearWeight) + '/' + IntToStr(Myself.Abil.MaxWearWeight))
//               else
//                 TextOut (mmx, bby+14*2, clSilver, IntToStr(Myself.Abil.WearWeight) + '/' + IntToStr(Myself.Abil.MaxWearWeight));
//
//               TextOut (bbx, bby+14*3, clSilver, '¾ç¼Õ¹«°Ô');
//               if Myself.Abil.HandWeight > Myself.Abil.MaxHandWeight then
//
//                 TextOut (mmx, bby+14*3, clRed, IntToStr(Myself.Abil.HandWeight) + '/' + IntToStr(Myself.Abil.MaxHandWeight))
//               else
//                 TextOut (mmx, bby+14*3, clSilver, IntToStr(Myself.Abil.HandWeight) + '/' + IntToStr(Myself.Abil.MaxHandWeight));
//
//               TextOut (bbx, bby+14*4, clSilver, 'Á¤È®');
//               TextOut (mmx, bby+14*4, clSilver, IntToStr(MyHitPoint));
//
//               TextOut (bbx, bby+14*5, clSilver, '¹ÎÃ¸');
//               TextOut (mmx, bby+14*5, clSilver, IntToStr(MySpeedPoint));
//
//               TextOut (bbx, bby+14*6, clSilver, '¸¶¹ýÀúÇ×');
//               TextOut (mmx, bby+14*6, clSilver, '+' + IntToStr(MyAntiMagic ) );
//
//               TextOut (bbx, bby+14*7, clSilver, 'Áßµ¶ÀúÇ×');
//               TextOut (mmx, bby+14*7, clSilver, '+' + IntToStr(MyAntiPoison ) );
//
//               TextOut (bbx, bby+14*8, clSilver, 'Áßµ¶È¸º¹');
//               TextOut (mmx, bby+14*8, clSilver, '+' + IntToStr(MyPoisonRecover * 10) + '%');
//
//               TextOut (bbx, bby+14*9, clSilver, 'Ã¼·ÂÈ¸º¹');
//               TextOut (mmx, bby+14*9, clSilver, '+' + IntToStr(MyHealthRecover * 10) + '%');
//
//               TextOut (bbx, bby+14*10, clSilver, '¸¶·ÂÈ¸º¹');
//               TextOut (mmx, bby+14*10, clSilver, '+' + IntToStr(MySpellRecover * 10) + '%');
//
//               TextOut (bbx, bby+14*11, clSilver, '¸í¼º:');
//               TextOut (bbx+40, bby+14*11, clSilver, Myself.FameName);
//
////               Release;
//            end;
//         end;
//         3: begin //¸¶¹ý Ã¢
//            bbx := Left + 38;
//            bby := Top + 59;
//            d := g_WProgUse.Images[383];
//            if d <> nil then
//               dsurface.Draw (SurfaceX(bbx), SurfaceY(bby), d.ClientRect, d, FALSE);
//
//            //Å° Ç¥½Ã, lv, exp
//            magtop := MagicPage * 5;
//            magline := _MIN(MagicPage*5+5, MagicList.Count);
//            for i:=magtop to magline-1 do begin
//               pm := PTClientMagic (MagicList[i]);
//               m := i - magtop;
//               keyimg := 0;
//
//               case byte(pm.Key) of
//                  byte('1'): keyimg := 750;//650;
//                  byte('2'): keyimg := 751;
//                  byte('3'): keyimg := 752;
//                  byte('4'): keyimg := 753;
//                  byte('5'): keyimg := 754;
//                  byte('6'): keyimg := 755;
//                  byte('7'): keyimg := 756;
//                  byte('8'): keyimg := 757;
//
////                  byte('9'):   keyimg := 769;
////                  byte('9')+1: keyimg := 770;
////                  byte('9')+2: keyimg := 771;
////                  byte('9')+3: keyimg := 772;
//
//                  // 2003/08/20 =>¸¶¹ý´ÜÃàÅ° Ãß°¡  // AddMagicKey
//                  byte('1')+20: keyimg := 758;//642;
//                  byte('2')+20: keyimg := 759;
//                  byte('3')+20: keyimg := 760;
//                  byte('4')+20: keyimg := 761;
//                  byte('5')+20: keyimg := 762;
//                  byte('6')+20: keyimg := 763;
//                  byte('7')+20: keyimg := 764;
//                  byte('8')+20: keyimg := 765;
//
////                  byte('9')+20: keyimg := 781;
////                  byte('9')+21: keyimg := 782;
////                  byte('9')+22: keyimg := 783;
////                  byte('9')+23: keyimg := 784;
//
//                  //-----------
//               end;
//               if keyimg > 0 then begin
//                  d := g_WProgUse.Images[keyimg];
//                  if d <> nil then
//                     dsurface.Draw (bbx + 142, bby+33+m*37, d.ClientRect, d, TRUE);
//               end;
//               d := g_WProgUse.Images[112]; //lv
//               if d <> nil then
//                  dsurface.Draw (bbx + 48, bby+33+15+m*37, d.ClientRect, d, TRUE);
//               d := g_WProgUse.Images[111]; //exp
//               if d <> nil then
//                  dsurface.Draw (bbx + 48 + 26, bby+33+15+m*37, d.ClientRect, d, TRUE);
//            end;
//
//            with g_DXCanvas do begin
//               for i:=magtop to magline-1 do begin
//                  pm := PTClientMagic (MagicList[i]);
//                  m := i - magtop;
//                  if not (pm.Level in [0..3]) then pm.Level := 0;
//                  TextOut (bbx + 46, bby + 32 + m*37, clSilver,
//                              pm.Def.MagicName);
//                  if pm.Level in [0..3] then trainlv := pm.Level
//                  else trainlv := 0;
//                  TextOut (bbx + 46 + 16, bby + 32 + 15 + m*37, clSilver, IntToStr(pm.Level));
//                  if pm.Def.MaxTrain[trainlv] > 0 then begin
//                     if trainlv < 3 then
//                        TextOut (bbx + 46 + 46, bby + 32 + 15 + m*37, clSilver, IntToStr(pm.CurTrain) + '/' + IntToStr(pm.Def.MaxTrain[trainlv]))
//                     else TextOut (bbx + 46 + 46, bby + 32 + 15 + m*37, clSilver, '-');
//                  end;
//               end;
//            end;
//         end;
//      end;
      if MouseStateItem.S.Name <> '' then begin
         MouseItem := MouseStateItem;
         GetMouseItemInfo (iname, d1, d2, d3, d4, useable, TRUE);
         if iname <> '' then begin
            if MouseItem.Dura = 0 then hcolor := clRed
//            else if MouseItem.UpgradeOpt > 0 then hcolor := clAqua  //$0C36E9
            else if MouseItem.UpgradeOpt > 0 then hcolor := TColor($cccc33)
            else hcolor := clWhite;
            // 2003/03/15 ¾ÆÀÌÅÛ ÀÎº¥Åä¸® È®Àå
            {
            with dsurface.Canvas do begin
               SetBkMode (Handle, TRANSPARENT);
               old := Font.Size;
               Font.Size := 8;
               Font.Color := clYellow;
               TextOut (SurfaceX(Left+37), SurfaceY(Top+272), iname);
               Font.Color := hcolor;
               TextOut (SurfaceX(Left+37+TextWidth(iname)), SurfaceY(Top+272), d1);
               TextOut (SurfaceX(Left+37), SurfaceY(Top+272+TextHeight('A')+2), d2);
               TextOut (SurfaceX(Left+37), SurfaceY(Top+272+(TextHeight('A')+2)*2), d3);
               Font.Size := old;
               Release;
            end;
            }
            // 2003/03/15 ¾ÆÀÌÅÛ ÀÎº¥Åä¸® È®Àå
            Str := iname + d1 + '\' + d2 + '\' + d3 + '\' + d4;
            DScreen.ShowHint(MouseX+10, MouseY+10, Str, hcolor, FALSE);

         end;
         MouseItem.S.Name := '';
      end;

    //ÎÄ×ÖÏÔÊ¾
    with g_DXCanvas do begin
      FColor := Myself.NameColor;
      tx := nLeft + (328 - TextWidth(FrmMain.CharName)) div 2;
      ty := nTop + 30;
      TextOut (tx, ty, FColor, Myself.UserName);

      tx := nLeft + 278;
      ty := nTop + 91;
      FColor := $FAFAFA;
      //µÈ¼¶
      str := IntToStr(Myself.Abil.Level);
      TextOut (tx - TextWidth(str) div 2, ty, FColor, str);
      //¾­ÑéÖµ
      str := Format('%2.2f',[Myself.Abil.Exp/Myself.Abil.MaxExp*100]) + '%';
      TextOut (tx - TextWidth(str) div 2, ty + 24, clRed, str);
      //ÉúÃüÖµ
      str := Format('%d/%d',[Myself.Abil.HP,MySelf.Abil.MaxHP]);
      TextOut (tx - TextWidth(str) div 2, ty + 24 * 2, FColor, str);
      //Ä§·¨Öµ
      str := Format('%d/%d',[Myself.Abil.MP,MySelf.Abil.MaxMP]);
      TextOut (tx - TextWidth(str) div 2, ty + 24 * 3, FColor, str);
      //±³°üÖØÁ¿
      str := Format('%d/%d',[Myself.Abil.Weight,MySelf.Abil.MaxWeight]);
      if Myself.Abil.Weight > Myself.Abil.MaxWeight then
        TextOut (tx - TextWidth(str) div 2, ty + 24 * 4, clRed, str)
      else
        TextOut (tx - TextWidth(str) div 2, ty + 24 * 4, FColor, str);
      //¸ºÖØ
      str := Format('%d/%d',[Myself.Abil.WearWeight,MySelf.Abil.MaxWearWeight]);
      if Myself.Abil.WearWeight > Myself.Abil.MaxWearWeight then
        TextOut (tx - TextWidth(str) div 2, ty + 24 * 5, clRed, str)
      else
        TextOut (tx - TextWidth(str) div 2, ty + 24 * 5, FColor, str);
      //ÊÖÖØÁ¿
      str := Format('%d/%d',[Myself.Abil.HandWeight,MySelf.Abil.MaxHandWeight]);
      if Myself.Abil.HandWeight > Myself.Abil.MaxHandWeight then
        TextOut (tx - TextWidth(str) div 2, ty + 24 * 6, clRed, str)
      else
        TextOut (tx - TextWidth(str) div 2, ty + 24 * 6, FColor, str);
      //×¼È·
      str := Format('+%d',[MyHitPoint]);
      TextOut (tx - TextWidth(str) div 2, ty + 24 * 7, FColor, str);
      //Ãô½Ý
      str := Format('+%d',[MySpeedPoint]);
      TextOut (tx - TextWidth(str) div 2, ty + 24 * 8, FColor, str);
      //ÆÆ»µ
      str := Format('ÆÆ»µ %d-%d',[Lobyte(MySelf.Abil.DC), Hibyte(MySelf.Abil.DC)]);
      TextOut (nLeft + 12, ty + 230, FColor, str);
      //·ÀÓù
      str := Format('·ÀÓù %d-%d',[Lobyte(MySelf.Abil.AC), Hibyte(MySelf.Abil.AC)]);
      TextOut (nLeft + 12 + 105, ty + 230, FColor, str);
      //×ÔÈ»ÏµÄ§·¨
      str := Format('×ÔÈ»ÏµÄ§·¨ %d-%d',[Lobyte(MySelf.Abil.MC), Hibyte(MySelf.Abil.MC)]);
      TextOut (nLeft + 12, ty + 230 + 28, FColor, str);
      //Áé»êÏµÄ§·¨
      str := Format('Áé»êÏµÄ§·¨ %d-%d',[Lobyte(MySelf.Abil.SC), Hibyte(MySelf.Abil.SC)]);
      TextOut (nLeft + 12 + 105, ty + 230 + 28, FColor, str);
      //Ä§·¨·ÀÓù
      str := Format('Ä§·¨·ÀÓù %d-%d',[Lobyte(MySelf.Abil.MAC), Hibyte(MySelf.Abil.MAC)]);
      TextOut (nLeft + 12 + 105 * 2, ty + 230 + 28, FColor, str);
      //¹¥»÷ÔªËØ
      str := '¹¥»÷ÔªËØ';
      TextOut (nLeft + 33 - TextWidth(str) div 2, ty + 230 + 57, FColor, str);
      //Ç¿ÔªËØ
      str := 'Ç¿ÔªËØ';
      TextOut (nLeft + 33 - TextWidth(str) div 2, ty + 230 + 57 + 30, FColor, str);
      //ÈõÔªËØ
      str := 'ÈõÔªËØ';
      TextOut (nLeft + 33 - TextWidth(str) div 2, ty + 230 + 57 + 60, FColor, str);

      DHeartImg.Left := tx-14;
      DHeartImg.Top := 25;

{         if StatePage = 0 then begin
            FColor := clSilver;
            tx := 122 - TextWidth(GuildName + ' ' + GuildRankName) div 2;
            TextOut (SurfaceX(Left + tx), SurfaceY(Top + 27), FColor,
                     GuildName + ' ' + GuildRankName);
//            Font.Color := clYellow;
//            TextOut (SurfaceX(Left + 45), SurfaceY(Top + 55), GuildName);
//            Font.Color := clSilver;
            fstr := Copy(Myself.FameName, 1, pos(' ', Myself.FameName)-1 );
            tx := 122 - TextWidth(Myself.FameName) div 2;
            TextOut (SurfaceX(Left + tx), SurfaceY(Top + 41), FColor, Myself.FameName );
            FColor := clGreen;
            TextOut (SurfaceX(Left + tx), SurfaceY(Top + 41), FColor, fstr );
//            TextOut (SurfaceX(Left + 77), SurfaceY(Top + 55+15), fstr );
         end;   }
    end;
  end;
end;

procedure TFrmDlg.DSWLightDirectPaint(Sender: TObject;
  dsurface: TDirectDrawSurface);
var
   idx: integer;
   d: TDirectDrawSurface;
begin
//   if StatePage = 0 then begin
      if Sender = DSWNecklace then begin
         if UseItems[U_NECKLACE].S.Name <> '' then begin
            idx := UseItems[U_NECKLACE].S.Looks;
            if idx >= 0 then begin
               d := g_WInventory.Images[idx];
               if d <> nil then
                  dsurface.Draw (DSWNecklace.SurfaceX(DSWNecklace.Left + (DSWNecklace.Width - d.Width) div 2),
                                 DSWNecklace.SurfaceY(DSWNecklace.Top + (DSWNecklace.Height - d.Height) div 2),
                                 d.ClientRect, d, TRUE);
            end;
         end;
      end;
      if Sender = DSWLight then begin
         if UseItems[U_RIGHTHAND].S.Name <> '' then begin
            idx := UseItems[U_RIGHTHAND].S.Looks;
            if idx >= 0 then begin
               d := g_WInventory.Images[idx];
               if d <> nil then
                  dsurface.Draw (DSWLight.SurfaceX(DSWLight.Left + (DSWLight.Width - d.Width) div 2),
                                 DSWLight.SurfaceY(DSWLight.Top + (DSWLight.Height - d.Height) div 2),
                                 d.ClientRect, d, TRUE);
            end;
         end;
      end;
      if Sender = DSWArmRingR then begin
         if UseItems[U_ARMRINGR].S.Name <> '' then begin
            idx := UseItems[U_ARMRINGR].S.Looks;
            if idx >= 0 then begin
               d := g_WInventory.Images[idx];
               if d <> nil then
                  dsurface.Draw (DSWArmRingR.SurfaceX(DSWArmRingR.Left + (DSWArmRingR.Width - d.Width) div 2),
                                 DSWArmRingR.SurfaceY(DSWArmRingR.Top + (DSWArmRingR.Height - d.Height) div 2),
                                 d.ClientRect, d, TRUE);
            end;
         end;
      end;
      if Sender = DSWArmRingL then begin
         if UseItems[U_ARMRINGL].S.Name <> '' then begin
            idx := UseItems[U_ARMRINGL].S.Looks;
            if idx >= 0 then begin
               d := g_WInventory.Images[idx];
               if d <> nil then
                  dsurface.Draw (DSWArmRingL.SurfaceX(DSWArmRingL.Left + (DSWArmRingL.Width - d.Width) div 2),
                                 DSWArmRingL.SurfaceY(DSWArmRingL.Top + (DSWArmRingL.Height - d.Height) div 2),
                                 d.ClientRect, d, TRUE);
            end;
         end;
      end;
      if Sender = DSWRingR then begin
         if UseItems[U_RINGR].S.Name <> '' then begin
            idx := UseItems[U_RINGR].S.Looks;
            if idx >= 0 then begin
               d := g_WInventory.Images[idx];
               if d <> nil then
                  dsurface.Draw (DSWRingR.SurfaceX(DSWRingR.Left + (DSWRingR.Width - d.Width) div 2),
                                 DSWRingR.SurfaceY(DSWRingR.Top + (DSWRingR.Height - d.Height) div 2),
                                 d.ClientRect, d, TRUE);
            end;
         end;
      end;
      if Sender = DSWRingL then begin
         if UseItems[U_RINGL].S.Name <> '' then begin
            idx := UseItems[U_RINGL].S.Looks;
            if idx >= 0 then begin
               d := g_WInventory.Images[idx];
               if d <> nil then
                  dsurface.Draw (DSWRingL.SurfaceX(DSWRingL.Left + (DSWRingL.Width - d.Width) div 2),
                                 DSWRingL.SurfaceY(DSWRingL.Top + (DSWRingL.Height - d.Height) div 2),
                                 d.ClientRect, d, TRUE);
            end;
         end;
      end;
      // 2003/03/15 ¾ÆÀÌÅÛ ÀÎº¥Åä¸® È®Àå
      if Sender = DSWBujuk then begin
         if UseItems[U_BUJUK].S.Name <> '' then begin
            idx := UseItems[U_BUJUK].S.Looks;
            if idx >= 0 then begin
               d := g_WInventory.Images[idx];
               if d <> nil then
                  dsurface.Draw (DSWBujuk.SurfaceX(DSWBujuk.Left + (DSWBujuk.Width - d.Width) div 2) + 1,
                                 DSWBujuk.SurfaceY(DSWBujuk.Top + (DSWBujuk.Height - d.Height) div 2),
                                 d.ClientRect, d, TRUE);
            end;
         end;
      end;
      if Sender = DSWBelt then begin
         if UseItems[U_BELT].S.Name <> '' then begin
            idx := UseItems[U_BELT].S.Looks;
            if idx >= 0 then begin
               d := g_WInventory.Images[idx];
               if d <> nil then
                  dsurface.Draw (DSWBelt.SurfaceX(DSWBelt.Left + (DSWBelt.Width - d.Width) div 2) + 1,
                                 DSWBelt.SurfaceY(DSWBelt.Top + (DSWBelt.Height - d.Height) div 2),
                                 d.ClientRect, d, TRUE);
            end;
         end;
      end;
      if Sender = DSWBoots then begin
         if UseItems[U_BOOTS].S.Name <> '' then begin
            idx := UseItems[U_BOOTS].S.Looks;
            if idx >= 0 then begin
               d := g_WInventory.Images[idx];
               if d <> nil then
                  dsurface.Draw (DSWBoots.SurfaceX(DSWBoots.Left + (DSWBoots.Width - d.Width) div 2 + 1),
                                 DSWBoots.SurfaceY(DSWBoots.Top + (DSWBoots.Height - d.Height) div 2),
                                 d.ClientRect, d, TRUE);
            end;
         end;
      end;
      if Sender = DSWCharm then begin
         if UseItems[U_CHARM].S.Name <> '' then begin
            idx := UseItems[U_CHARM].S.Looks;
            if idx >= 0 then begin
               d := g_WInventory.Images[idx];
               if d <> nil then
                  dsurface.Draw (DSWCharm.SurfaceX(DSWCharm.Left + (DSWCharm.Width - d.Width) div 2 + 1),
                                 DSWCharm.SurfaceY(DSWCharm.Top + (DSWCharm.Height - d.Height) div 2),
                                 d.ClientRect, d, TRUE);
            end;
         end;
      end;

//   end;
end;

procedure TFrmDlg.DStateWinClick(Sender: TObject; X, Y: Integer);
begin
//   if StatePage = 3 then begin
//      X := DStateWin.LocalX (X) - DStateWin.Left;
//      Y := DStateWin.LocalY (Y) - DStateWin.Top;
//      if (X >= 33) and (X <= 33+166) and (Y >= 55) and (Y <= 55+37*5) then begin
//         magcur := (Y-55) div 37;
//         if (magcur+magtop) >= MagicList.Count then
//            magcur := (MagicList.Count-1) - magtop;
//      end;
//   end;
end;

procedure TFrmDlg.DCloseStateClick(Sender: TObject; X, Y: Integer);
begin
  DStateWin.Visible := FALSE;
end;

procedure TFrmDlg.DCloseStateMouseMove(Sender: TObject; Shift: TShiftState; X,
  Y: Integer);
var
  lx, ly: integer;
  sx, sy: integer;
begin
  with DCloseState do begin
    lx := LocalX(X - Left);
    ly := LocalY(Y - Top);
    sx := SurfaceX(Left) + DStateWin.SurfaceX(DStateWin.Left) + lx + 8;
    sy := SurfaceY(Top) + DStateWin.SurfaceX(DStateWin.Top) + ly + 6;
    DScreen.ShowHint(sx, sy, '¹Ø ±Õ', $393800, True);
  end;
end;

procedure TFrmDlg.DPrevStateDirectPaint(Sender: TObject;
  dsurface: TDirectDrawSurface);
var
   d: TDirectDrawSurface;
begin
   with Sender as TDButton do begin
      if TDButton(Sender).Downed then begin
         d := WLib.Images[FaceIndex];
         if d <> nil then
            dsurface.Draw (SurfaceX(Left), SurfaceY(Top), d.ClientRect, d, TRUE);
      end;
   end;
end;

procedure TFrmDlg.PageChanged;
begin
   case StatePage of
      3: begin //¸¶¹ý »óÅÂÃ¢
         DStMag1.Visible := TRUE;  DStMag2.Visible := TRUE;
         DStMag3.Visible := TRUE;  DStMag4.Visible := TRUE;
         DStMag5.Visible := TRUE;
         DStPageUp.Visible := TRUE;
         DStPageDown.Visible := TRUE;
         MagicPage := 0;
      end;
      else begin
         DStMag1.Visible := FALSE;  DStMag2.Visible := FALSE;
         DStMag3.Visible := FALSE;  DStMag4.Visible := FALSE;
         DStMag5.Visible := FALSE;
         DStPageUp.Visible := FALSE;
         DStPageDown.Visible := FALSE;
      end;
   end;
   DScreen.ClearHint;
end;

procedure TFrmDlg.DPrevStateClick(Sender: TObject; X, Y: Integer);
begin
   Dec (StatePage);
   if StatePage < 0 then
      StatePage := MAXSTATEPAGE-1;
   PageChanged;
end;

procedure TFrmDlg.DNextStateClick(Sender: TObject; X, Y: Integer);
begin
   Inc (StatePage);
   if StatePage > MAXSTATEPAGE-1 then
      StatePage := 0;
   PageChanged;
end;

procedure TFrmDlg.DSWWeaponClick(Sender: TObject; X, Y: Integer);
var
   where, n, sel: integer;
   flag, movcancel: Boolean;
begin
   if Myself = nil then exit;
   if StatePage <> 0 then exit;
   if ItemMoving then begin
      flag := FALSE;
      movcancel := FALSE;
      if (MovingItem.Index = -97) or (MovingItem.Index = -98) then exit;
      if (MovingItem.Item.S.Name = '') or (WaitingUseItem.Item.S.Name <> '') then exit;
      where := GetTakeOnPosition (MovingItem.Item.S.StdMode);
      if MovingItem.Index >= 0 then begin
         case where of
            U_DRESS: begin
               if Sender = DSWDress then begin
                  if Myself.Sex = 0 then //³²ÀÚ
                     if MovingItem.Item.S.StdMode <> 10 then //³²ÀÚ¿Ê
                        exit;
                  if Myself.Sex = 1 then //¿©ÀÚ
                     if MovingItem.Item.S.StdMode <> 11 then //¿©ÀÚ¿Ê
                        exit;
                  flag := TRUE;
               end;
            end;
            U_WEAPON: begin
               if Sender = DSWWEAPON then begin
                  flag := TRUE;
               end;
            end;
            U_NECKLACE: begin
               if Sender = DSWNecklace then
                  flag := TRUE;
            end;
            U_RIGHTHAND: begin
               if Sender = DSWLight then
                  flag := TRUE;
            end;
            U_HELMET: begin
               if Sender = DSWHelmet then
                  flag := TRUE;
            end;
            U_RINGR, U_RINGL: begin
               if Sender = DSWRingL then begin
                  where := U_RINGL;
                  flag := TRUE;
               end;
               if Sender = DSWRingR then begin
                  where := U_RINGR;
                  flag := TRUE;
               end;
            end;
            U_ARMRINGR: begin  //ÆÈÂî
               if Sender = DSWArmRingL then begin
                  where := U_ARMRINGL;
                  flag := TRUE;
               end;
               if Sender = DSWArmRingR then begin
                  where := U_ARMRINGR;
                  flag := TRUE;
               end;
            end;
            U_ARMRINGL: begin  //  ÆÈÂî
               if Sender = DSWArmRingL then begin
                  where := U_ARMRINGL;
                  flag := TRUE;
               end;
            end;
            // 2003/03/15 COPARK ¾ÆÀÌÅÛ ÀÎº¥Åä¸® È®Àå
            U_BUJUK: begin       //ºÎÀû, µ¶°¡·ç
               if Sender = DSWBujuk then begin
                  where := U_BUJUK;
                  flag := TRUE;
               end;
               if Sender = DSWArmRingL then begin
                  where := U_ARMRINGL;
                  flag := TRUE;
               end;
            end;
            U_BELT: begin  //º§Æ®
               if Sender = DSWBelt then begin
                  where := U_BELT;
                  flag := TRUE;
               end;
            end;
            U_BOOTS: begin  //½Å¹ß
               if Sender = DSWBoots then begin
                  where := U_BOOTS;
                  flag := TRUE;
               end;
            end;
            U_CHARM: begin  //¼öÈ£¼®
               if Sender = DSWCharm then begin
                  where := U_CHARM;
                  flag := TRUE;
               end;
            end;

         end;
      end else begin
         n := -(MovingItem.Index+1);
         // 2003/03/15 COPARK ¾ÆÀÌÅÛ ÀÎº¥Åä¸® È®Àå
         if n in [0..12] then begin            // 8->12
            ItemClickSound (MovingItem.Item.S);
            UseItems[n] := MovingItem.Item;
            MovingItem.Item.S.Name := '';
            ItemMoving := FALSE;
         end;
      end;
      if flag then begin
         ItemClickSound (MovingItem.Item.S);
         WaitingUseItem := MovingItem;
         WaitingUseItem.Index := where;

         FrmMain.SendTakeOnItem (where, MovingItem.Item.MakeIndex, MovingItem.Item.S.Name);
         MovingItem.Item.S.Name := '';
         ItemMoving := FALSE;
      end;
   end else begin
      flag := FALSE;
      if (MovingItem.Item.S.Name <> '') or (WaitingUseItem.Item.S.Name <> '') then exit;
      sel := -1;
      if Sender = DSWDress then sel := U_DRESS;
      if Sender = DSWWeapon then sel := U_WEAPON;
      if Sender = DSWHelmet then sel := U_HELMET;
      if Sender = DSWNecklace then sel := U_NECKLACE;
      if Sender = DSWLight then sel := U_RIGHTHAND;
      if Sender = DSWRingL then sel := U_RINGL;
      if Sender = DSWRingR then sel := U_RINGR;
      if Sender = DSWArmRingL then sel := U_ARMRINGL;
      if Sender = DSWArmRingR then sel := U_ARMRINGR;
      // 2003/03/15 ¾ÆÀÌÅÛ ÀÎº¥Åä¸® È®Àå
      if Sender = DSWBujuk then sel := U_BUJUK;
      if Sender = DSWBelt  then sel := U_BELT;
      if Sender = DSWBoots then sel := U_BOOTS;
      if Sender = DSWCharm then sel := U_CHARM;

      if sel >= 0 then begin
         if UseItems[sel].S.Name <> '' then begin
            ItemClickSound (UseItems[sel].S);
            MovingItem.Index := -(sel+1);
            MovingItem.Item := UseItems[sel];
            UseItems[sel].S.Name := '';
            ItemMoving := TRUE;
         end;
      end;
   end;
end;

procedure TFrmDlg.DSWWeaponMouseMove(Sender: TObject; Shift: TShiftState;
  X, Y: Integer);
var
   sel: integer;
   iname, d1, d2, d3: string;
   useable: Boolean;
   hcolor: TColor;
   lx, ly : integer;
begin

   if StatePage = 1 then begin
      lx := X;// - DStateWin.Left;
      ly := Y;// - DStateWin.Top;
//      DScreen.AddChatBoardString ('lx=> '+IntToStr(lx) +'  ly=> '+IntToStr(ly), clYellow, clRed);
      if (lx>57) and (lx<180) and (ly>110) and (ly<127) then
         DScreen.ShowHint (DStateWin.Left+158, DStateWin.Top+112, '¹æ¾î·Â', clYellow, FALSE)
      else if (lx>57) and (lx<180) and (ly>132) and (ly<149) then
         DScreen.ShowHint (DStateWin.Left+158, DStateWin.Top+134, '¸¶¹ý¹æ¾î', clYellow, FALSE)
      else if (lx>57) and (lx<180) and (ly>154) and (ly<171) then
         DScreen.ShowHint (DStateWin.Left+158, DStateWin.Top+156, 'ÆÄ±«·Â', clYellow, FALSE)
      else if (lx>57) and (lx<180) and (ly>176) and (ly<193) then
         DScreen.ShowHint (DStateWin.Left+158, DStateWin.Top+178, '¸¶·Â', clYellow, FALSE)
      else if (lx>57) and (lx<180) and (ly>198) and (ly<215) then
         DScreen.ShowHint (DStateWin.Left+158, DStateWin.Top+200, 'µµ·Â', clYellow, FALSE)
      else DScreen.ClearHint;
   end;

   if StatePage <> 0 then exit;
   //DScreen.ClearHint;
   sel := -1;
   if Sender = DSWDress then sel := U_DRESS;
   if Sender = DSWWeapon then sel := U_WEAPON;
   if Sender = DSWHelmet then sel := U_HELMET;
   if Sender = DSWNecklace then sel := U_NECKLACE;
   if Sender = DSWLight then sel := U_RIGHTHAND;
   if Sender = DSWRingL then sel := U_RINGL;
   if Sender = DSWRingR then sel := U_RINGR;
   if Sender = DSWArmRingL then sel := U_ARMRINGL;
   if Sender = DSWArmRingR then sel := U_ARMRINGR;
   // 2003/03/15 ¾ÆÀÌÅÛ ÀÎº¥Åä¸® È®Àå
   if Sender = DSWBujuk then sel := U_BUJUK;
   if Sender = DSWBelt  then sel := U_BELT;
   if Sender = DSWBoots then sel := U_BOOTS;
   if Sender = DSWCharm then sel := U_CHARM;

   if sel >= 0 then begin
      MouseStateItem := UseItems[sel];
      // 2003/03/15 ¾ÆÀÌÅÛ ÀÎº¥Åä¸® È®Àå
      MouseX := DStateWin.Left + X;
      MouseY := DStateWin.Top  + Y;
      {MouseItem := UseItems[sel];
      GetMouseItemInfo (iname, d1, d2, d3, useable);
      if iname <> '' then begin
         if UseItems[sel].Dura = 0 then hcolor := clRed
         else hcolor := clSilver;
         with Sender as TDButton do
            DScreen.ShowHint (SurfaceX(Left - 30),
                              SurfaceY(Top + 50),
                              iname + d1 + '\' + d2 + '\' + d3 + d4, hcolor, FALSE);
      end;
      MouseItem.S.Name := '';}
   end;
end;

procedure TFrmDlg.DStateWinMouseMove(Sender: TObject; Shift: TShiftState;
  X, Y: Integer);
var
   lx, ly : integer;
begin
   DScreen.ClearHint;
   MouseStateItem.S.Name := '';

   lx := X - DStateWin.Left;
   ly := Y - DStateWin.Top;
//      DScreen.AddChatBoardString ('lx=> '+IntToStr(lx) +'  ly=> '+IntToStr(ly), clYellow, clRed);
   if StatePage = 1 then begin
      if (lx>57) and (lx<180) and (ly>110) and (ly<127) then
         DScreen.ShowHint (DStateWin.Left+158, DStateWin.Top+112, '¹æ¾î·Â', clYellow, FALSE)
      else if (lx>57) and (lx<180) and (ly>132) and (ly<149) then
         DScreen.ShowHint (DStateWin.Left+158, DStateWin.Top+134, '¸¶¹ýÀúÇ×', clYellow, FALSE)
      else if (lx>57) and (lx<180) and (ly>154) and (ly<171) then
         DScreen.ShowHint (DStateWin.Left+158, DStateWin.Top+156, 'ÆÄ±«·Â', clYellow, FALSE)
      else if (lx>57) and (lx<180) and (ly>176) and (ly<193) then
         DScreen.ShowHint (DStateWin.Left+158, DStateWin.Top+178, '¸¶·Â', clYellow, FALSE)
      else if (lx>57) and (lx<180) and (ly>198) and (ly<215) then
         DScreen.ShowHint (DStateWin.Left+158, DStateWin.Top+200, 'µµ·Â', clYellow, FALSE)
      else DScreen.ClearHint;
   end;

end;


//»óÅÂÃ¢ : ¸¶¹ý ÆäÀÌÁö

procedure TFrmDlg.DStMag1DirectPaint(Sender: TObject;
  dsurface: TDirectDrawSurface);
var
   idx, icon: integer;
   d: TDirectDrawSurface;
   pm: PTClientMagic;
begin
//   with Sender as TDButton do begin
//      idx := _Max(Tag + MagicPage * 5, 0);
//      if idx < MagicList.Count then begin
//         pm := PTClientMagic (MagicList[idx]);
//         icon := pm.Def.Effect * 2;
//         if icon >= 0 then begin //¾ÆÀÌÄÜÀÌ ¾ø´Â°Å..
//            if not Downed then begin
//               d := g_WMagIcon.Images[icon];
//               if d <> nil then
//                  dsurface.Draw (SurfaceX(Left), SurfaceY(Top), d.ClientRect, d, TRUE);
//            end else begin
//               d := g_WMagIcon.Images[icon+1];
//               if d <> nil then
//                  dsurface.Draw (SurfaceX(Left), SurfaceY(Top), d.ClientRect, d, TRUE);
//            end;
//         end;
//      end;
//   end;
end;

procedure TFrmDlg.DStMag1Click(Sender: TObject; X, Y: Integer);
var
   i, idx: integer;
   selkey: word;
   keych: char;
   pm: PTClientMagic;
begin
//   if StatePage = 3 then begin
//      idx := TDButton(Sender).Tag + magtop;
//      if (idx >= 0) and (idx < MagicList.Count) then begin
//
//         pm := PTClientMagic (MagicList[idx]);
//         selkey := word(pm.Key);
//         SetMagicKeyDlg (pm.Def.Effect * 2, pm.Def.MagicName, selkey);
//         keych := char(selkey);
//
//         for i:=0 to MagicList.Count-1 do begin
//            pm := PTClientMagic (MagicList[i]);
//            if pm.Key = keych then begin
//               pm.Key := #0;
//               FrmMain.SendMagicKeyChange (pm.Def.MagicId, #0);
//            end;
//         end;
//         pm := PTClientMagic (MagicList[idx]);
//         //if pm.Def.EffectType <> 0 then begin //°Ë¹ýÀº Å°¼³Á¤À» ¸øÇÔ.
//         pm.Key := keych;
//         FrmMain.SendMagicKeyChange (pm.Def.MagicId, keych);
//         //end;
//      end;
//   end;
end;

procedure TFrmDlg.DStPageUpClick(Sender: TObject; X, Y: Integer);
begin
//   if Sender = DStPageUp then begin
//      if MagicPage > 0 then
//         Dec (MagicPage);
//   end else begin
//      if MagicPage < (MagicList.Count+4) div 5 - 1 then
//         Inc (MagicPage);
//   end;
end;





{------------------------------------------------------------------------}

//¹Ù´Ú »óÅÂ

{------------------------------------------------------------------------}


procedure TFrmDlg.DBottomDirectPaint(Sender: TObject;
  dsurface: TDirectDrawSurface);
var
   d: TDirectDrawSurface;
   rc: TRect;
   btop, sx, sy, i, fcolor, bcolor: integer;
   r: Real;
   s, sMapTitle, sInfo1, sInfo2: string;
begin
   d := g_WGameInter.Images[BOTTOMBOARD];
   if d <> nil then
      dsurface.Draw (DBottom.Left, DBottom.Top, d.ClientRect, d, TRUE);
   btop := 0;
   if d <> nil then begin
      with d.ClientRect do
         rc := Rect (Left, Top, Right, Top+120);
      btop := SCREENHEIGHT - d.height;
      dsurface.Draw (0,
                     btop,
                     rc,
                     d, TRUE);
      with d.ClientRect do
         rc := Rect (Left, Top+120, Right, Bottom);
      dsurface.Draw (0,
                     btop + 120,
                     rc,
                     d, FALSE);
   end;

   if Myself <> nil then begin
      //Ã¼·Â ¸¶·Â Ç¥½Ã
      if (Myself.Abil.MaxHP > 0) and (Myself.Abil.MaxMP > 0) then begin
         if (Myself.Job = 0) and (Myself.Abil.Level < 26) then begin //Àü»ç
            d := g_WGameInter.Images[1163];
            if d <> nil then begin
               rc := d.ClientRect;
               rc.Right := d.ClientRect.Right - 2;
               rc.Top := Round(rc.Bottom / Myself.Abil.MaxHP * (Myself.Abil.MaxHP - Myself.Abil.HP));
               dsurface.Draw (33, btop+8+rc.Top, rc, d, TRUE);
            end;
            d := g_WGameInter.Images[1165];
            if d <> nil then begin
               rc := d.ClientRect;
               rc.Right := d.ClientRect.Right - 2;
               rc.Top := Round(rc.Bottom / Myself.Abil.MaxHP * (Myself.Abil.MaxHP - Myself.Abil.HP));
               dsurface.Draw (73, btop+8+rc.Top, rc, d, TRUE);
            end;
         end else begin
            d := g_WGameInter.Images[1163];
            if d <> nil then begin
               rc := d.ClientRect;
               rc.Right := d.ClientRect.Right - 2;
               rc.Top := Round(rc.Bottom / Myself.Abil.MaxHP * (Myself.Abil.MaxHP - Myself.Abil.HP));
               dsurface.Draw (33, btop+8+rc.Top, rc, d, TRUE);
            end;
            d := g_WGameInter.Images[1164];
            if d <> nil then begin
               rc := d.ClientRect;
               rc.Right := d.ClientRect.Right - 2;
               rc.Top := Round(rc.Bottom / Myself.Abil.MaxMP * (Myself.Abil.MaxMP - Myself.Abil.MP));
               dsurface.Draw (73, btop+8+rc.Top, rc, d, TRUE);
            end;
         end;
      end;

      if (MySelf.Abil.MaxExp > 0) and (MySelf.Abil.MaxWeight > 0) then
      begin
        d := g_WGameInter.Images[1166];
          //¾­ÑéÌõ
        if d <> nil then
        begin
          rc := d.ClientRect;
          rc.bottom := Round(d.ClientRect.Bottom / MySelf.Abil.MaxExp * _MIN(MySelf.Abil.MaxExp, MySelf.Abil.Exp));

          dsurface.Draw(152, DBottom.Top + d.ClientRect.Bottom - rc.Bottom + 26, rc, d, TRUE);
        end;

        //±³°üÖØÁ¿Ìõ
        d := g_WGameInter.Images[1167];
        if d <> nil then
        begin
          rc := d.ClientRect;
          rc.bottom := Round(d.ClientRect.Bottom / MySelf.Abil.MaxWeight * _MIN(MySelf.Abil.MaxWeight, MySelf.Abil.Weight));
          dsurface.draw(165, DBottom.Top + d.ClientRect.Bottom - rc.Bottom + 26, rc, d, TRUE);
        end;
      end;

      //·¹º§ Ç¥½Ã
//      with dsurface.Canvas do begin
//         PomiTextOut (dsurface, 679, 512, IntToStr(Myself.Abil.Level));
//      end;
      //°æÇèÄ¡, ¹«°Ô Ç¥½Ã
      if (Myself.Abil.MaxExp > 0) and (Myself.Abil.MaxWeight > 0) then begin
         d := g_WProgUse.Images[7];
         if d <> nil then begin
            //°æÇèÄ¡
            rc := d.ClientRect;
            if Myself.Abil.Exp > 0 then r := Myself.Abil.MaxExp / Myself.Abil.Exp
            else r := 0;
            if r > 0 then rc.Right := Round (rc.Right / r)
            else rc.Right := 0;
            dsurface.Draw (665, 546, rc, d, FALSE);
            //PomiTextOut (dsurface, 660, 528, IntToStr(Myself.Abil.Exp));
            //¹«°Ô
         end;
         d := g_WProgUse.Images[76];
         if d <> nil then begin
            rc := d.ClientRect;
            if Myself.Abil.Weight > 0 then r := Myself.Abil.MaxWeight / Myself.Abil.Weight
            else r := 0;
            if r > 0 then rc.Right := Round (rc.Right / r)
            else rc.Right := 0;
            dsurface.Draw (688, 577, rc, d, FALSE);
            //PomiTextOut (dsurface, 660, 561, IntToStr(Myself.Abil.Weight));
         end;
      end;
      //¹è°íÇ° Ç¥½Ã
      { 2003/04/15 ÂÊÁö·Î ´ëÃ¼
      if MyHungryState in [1..4] then begin
         d := g_WProgUse.Images[16 + MyHungryState-1];
         if d <> nil then begin
            dsurface.Draw (754, 553, d.ClientRect, d, TRUE);
         end;
      end;
      }
     sMapTitle:= MapTitle + ' ' + IntToStr(Myself.XX) + ':' + IntToStr(Myself.YY);

     sInfo1:= Format('%d-%d',[Lobyte(MySelf.Abil.AC), Hibyte(MySelf.Abil.AC)]);
     sInfo2:= Format('%d-%d',[Lobyte(MySelf.Abil.DC), Hibyte(MySelf.Abil.DC)]);
     with g_DXCanvas do begin
        BoldTextOut (72- TextWidth(sMapTitle) div 2, SCREENHEIGHT-23, clWhite, sMapTitle);

        TextOut (SCREENWIDTH - 115 - TextWidth(sInfo1) div 2, SCREENHEIGHT-26, $32C8FF, sInfo1);
        TextOut (SCREENWIDTH - 35 - TextWidth(sInfo2) div 2, SCREENHEIGHT-26, $32C8FF, sInfo2);
     end;

   end;



//Ã¼·Â ¼öÄ¡·Î º¸¿©ÁÜ-------------------------------------------------------
//   if (Myself.Abil.HP < Myself.Abil.MaxHP) or (Myself.Abil.MP < Myself.Abil.MaxMP) then begin

//      s  := 'HP('+IntToStr(Myself.Abil.HP)+'/'+IntToStr(Myself.Abil.MaxHP)+')';
//
//      dsurface.Canvas.Font.Color := clBlack;
//      dsurface.Canvas.TextOut (63-1, 504, s);
//      dsurface.Canvas.TextOut (63+1, 504, s);
//      dsurface.Canvas.TextOut (63,   504-1, s);
//      dsurface.Canvas.TextOut (63,   504+1, s);
//
//      dsurface.Canvas.Font.Color := clWhite;
//      dsurface.Canvas.TextOut (63, 504, s);
//      if (Myself.Job <> 0) or (Myself.Abil.Level >= 26) then begin
//         s := 'MP('+IntToStr(Myself.Abil.MP)+'/'+IntToStr(Myself.Abil.MaxMP)+')';
//
//         dsurface.Canvas.Font.Color := clBlack;
//         dsurface.Canvas.TextOut (63-1, 504+14, s);
//         dsurface.Canvas.TextOut (63+1, 504+14, s);
//         dsurface.Canvas.TextOut (63,   504-1+14, s);
//         dsurface.Canvas.TextOut (63,   504+1+14, s);
//
//         dsurface.Canvas.Font.Color := clWhite;
//         dsurface.Canvas.TextOut (63, 504+14, s);
//      end;
//   end;
 //-----------------------------------------------------------------------

//   sx := 208;
//   sy := SCREENHEIGHT - 130;
//   with DScreen do begin
//      for i := ChatBoardTop to ChatBoardTop + VIEWCHATLINE-1 do begin
//         if i > ChatStrs.Count-1 then break;
//         fcolor := integer(ChatStrs.Objects[i]);
//         bcolor := integer(ChatBks[i]);
//         g_DXCanvas.TextOutX(sx, sy+(i-ChatBoardTop)*12, ChatStrs.Strings[i],fcolor, bcolor);
//      end;
//   end;

end;




{--------------------------------------------------------------}
//¹Ù´Ú »óÅÂ¹ÙÀÇ 4°³ ¹öÆ°


procedure TFrmDlg.DBottomInRealArea(Sender: TObject; X, Y: Integer;
  var IsRealArea: Boolean);
var
   d: TDirectDrawSurface;
begin
   d := g_WGameInter.Images[BOTTOMBOARD];
   if d <> nil then begin
      if d.Pixels[X, Y] > 0 then IsRealArea := TRUE
      else IsRealArea := FALSE;
   end;
end;

procedure TFrmDlg.DMyStateDirectPaint(Sender: TObject; dsurface: TDirectDrawSurface);
var
  d: TDButton;
  dd: TDirectDrawSurface;
begin
  if Sender is TDButton then begin
    d := TDButton(Sender);
    if d.Downed then begin
      dd := d.WLib.Images[d.FaceIndex + 1];
    end
    else if d.MouseEntry = msIn then begin
      dd := d.WLib.Images[d.FaceIndex];
    end
    else begin
      dd := nil;
    end;
    if dd <> nil then
      dsurface.Draw(d.SurfaceX(d.Left), d.SurfaceY(d.Top), dd.ClientRect, dd, TRUE);
  end;
end;

procedure TFrmDlg.DBotMemoDirectPaint(Sender: TObject;
  dsurface: TDirectDrawSurface);
var
   d: TDButton;
   dd: TDirectDrawSurface;
begin
     DMyStateDirectPaint( Sender , dsurface );

   if Sender is TDButton then
   begin
      d := TDButton(Sender);
     // ±ô¹ÚÀÓ Ç¥½Ã ??
     if not TDButton(Sender).Downed and MailAlarm then
     begin
        if (GetTickCount mod 1000) > 500 then  dd := d.WLib.Images[d.FaceIndex]
        else dd := d.WLib.Images[d.FaceIndex +1];

        if dd <> nil then
        dsurface.Draw (d.SurfaceX(d.Left), d.SurfaceY(d.Top), dd.ClientRect, dd, TRUE);

      end;
   end;
end;


//±×·ì, ±³È¯, ¸Ê ¹öÆ°
procedure TFrmDlg.DBotGroupDirectPaint(Sender: TObject;
  dsurface: TDirectDrawSurface);
var
   d: TDButton;
   dd: TDirectDrawSurface;
begin
   if Sender is TDButton then begin
      d := TDButton(Sender);
      if not d.Downed then begin
         dd := d.WLib.Images[d.FaceIndex];
         if dd <> nil then
            dsurface.Draw (d.SurfaceX(d.Left), d.SurfaceY(d.Top), dd.ClientRect, dd, TRUE);
      end else begin
         dd := d.WLib.Images[d.FaceIndex+1];
         if dd <> nil then
            dsurface.Draw (d.SurfaceX(d.Left), d.SurfaceY(d.Top), dd.ClientRect, dd, TRUE);
      end;
   end;
end;

procedure TFrmDlg.DBotPlusAbilDirectPaint(Sender: TObject;
  dsurface: TDirectDrawSurface);
var
   d: TDButton;
   dd: TDirectDrawSurface;
begin
   if Sender is TDButton then begin
      d := TDButton(Sender);
      if not d.Downed then begin
         if (BlinkCount mod 2 = 0) and (not DAdjustAbility.Visible) then dd := d.WLib.Images[d.FaceIndex]
         else dd := d.WLib.Images[d.FaceIndex + 2];
         if dd <> nil then
            dsurface.Draw (d.SurfaceX(d.Left), d.SurfaceY(d.Top), dd.ClientRect, dd, TRUE);
      end else begin
         dd := d.WLib.Images[d.FaceIndex+1];
         if dd <> nil then
            dsurface.Draw (d.SurfaceX(d.Left), d.SurfaceY(d.Top), dd.ClientRect, dd, TRUE);
      end;

      if GetTickCount - BlinkTime >= 500 then begin
         BlinkTime := GetTickCount;
         Inc (BlinkCount);
         if BlinkCount >= 10 then BlinkCount := 0;
      end;
   end;
end;



procedure TFrmDlg.DBotSkillBarClick(Sender: TObject; X, Y: Integer);
begin
  if BoSkillBarView then BoSkillBarView := False
  else BoSkillBarView := True;
end;

procedure TFrmDlg.DBotSkillBarMouseMove(Sender: TObject; Shift: TShiftState; X, Y: Integer);
var
  lx, ly: integer;
  sx, sy: integer;
begin
  with DBotSkillBar do begin
    lx := LocalX(X - Left);
    ly := LocalY(Y - Top);
    sx := SurfaceX(Left) + DBottom.SurfaceX(DBottom.Left) + lx + 13;
    sy := SurfaceY(Top) + DBottom.SurfaceX(DBottom.Top) + ly - 2;
    DScreen.ShowHint(sx, sy, 'Ä§·¨¿ì½Ý¼ü´°¿Ú(Ctrl+B, B)', $393800, True);
  end;
end;

procedure TFrmDlg.DMyStateClick(Sender: TObject; X, Y: Integer);
begin
   if Sender = DMyState then OpenMyStatus;
   if Sender = DMyBag then OpenItemBag;
   if Sender = DMyMagic then OpenMyMagic;
   if Sender = DOption then begin

      if DMainOption.Visible then begin
         DMainOption.Visible := False;
         Exit;
      end;
      if SkillKeyMode = 1 then begin
         DSkillMode1.Tag := 1;
         DSkillMode2.Tag := 0;
      end
      else if SkillKeyMode = 2 then begin
         DSkillMode1.Tag := 0;
         DSkillMode2.Tag := 1;
      end;
      if BoSkillBarView then begin
         DSkillBarOn.Tag  := 1;
         DSkillBarOff.Tag := 0;
      end
      else begin
         DSkillBarOn.Tag  := 0;
         DSkillBarOff.Tag := 1;
      end;
      if BoViewEffect then begin
         DEffectOn.Tag  := 1;
         DEffectOff.Tag := 0;
      end
      else begin
         DEffectOn.Tag  := 0;
         DEffectOff.Tag := 1;
      end;
      if BoPlaySoundEffect then begin
         DSoundOn.Tag  := 1;
         DSoundOff.Tag := 0;
      end
      else begin
         DSoundOn.Tag  := 0;
         DSoundOff.Tag := 1;
      end;
      if DropItemView then begin
         DDropViewOn.Tag  := 1;
         DDropViewOff.Tag := 0;
      end
      else begin
         DDropViewOn.Tag  := 0;
         DDropViewOff.Tag := 1;
      end;

      DMainOption.Visible := True;
   end;
end;

procedure TFrmDlg.DOptionClick(Sender: TObject);
begin
end;





{------------------------------------------------------------------------}

// º§Æ®

{------------------------------------------------------------------------}


procedure TFrmDlg.DBelt1DirectPaint(Sender: TObject;
  dsurface: TDirectDrawSurface);
var
   idx: integer;
   d: TDirectDrawSurface;
begin
   if Myself = nil then Exit;
   if not DBeltWin.Visible then Exit;
   with Sender as TDButton do begin
      idx := Tag;
      if idx in [0..5] then begin
         if ItemArr[idx].S.Name <> '' then begin
            d := g_WInventory.Images[ItemArr[idx].S.Looks];
            if d <> nil then
               dsurface.Draw (SurfaceX(Left+(Width-d.Width) div 2), SurfaceY(Top+(Height-d.Height) div 2), d.ClientRect, d, TRUE);
         end;
      end;
//      if BeltType = 1 then PomiTextOut (dsurface, SurfaceX(Left+14), SurfaceY(Top+20), IntToStr(idx+1))
//      else PomiTextOut (dsurface, SurfaceX(Left+12), SurfaceY(Top+21), IntToStr(idx+1));
   end;
end;

procedure TFrmDlg.DBelt1MouseMove(Sender: TObject; Shift: TShiftState; X,
  Y: Integer);
var
   idx: integer;  
begin
   idx := TDButton(Sender).Tag;
   if idx in [0..5] then begin
      if ItemArr[idx].S.Name <> '' then begin
         MouseItem := ItemArr[idx];
      end;
   end;
end;

procedure TFrmDlg.DBelt1Click(Sender: TObject; X, Y: Integer);
var
   idx: integer;
   temp: TClientItem;
begin
   idx := TDButton(Sender).Tag;
   if idx in [0..5] then begin
      if not ItemMoving then begin
         if ItemArr[idx].S.Name <> '' then begin
            ItemClickSound (ItemArr[idx].S);
            ItemMoving := TRUE;
            MovingItem.Index := idx;
            MovingItem.Item := ItemArr[idx];
            ItemArr[idx].S.Name := '';
         end;
      end else begin
         if (MovingItem.Index = -97) or (MovingItem.Index = -98) then exit;
//         if MovingItem.Item.S.StdMode <= 3 then begin //Æ÷¼Ç,À½½Ä,½ºÅ©·Ñ
         if (MovingItem.Item.S.StdMode <= 3) or (MovingItem.Item.S.StdMode = 25) then begin //Æ÷¼Ç,À½½Ä,½ºÅ©·Ñ, µ¶°¡·ç, ºÎÀû
            //ItemClickSound (MovingItem.Item.S.StdMode);
            if ItemArr[idx].S.Name <> '' then begin
               temp := ItemArr[idx];
               ItemArr[idx] := MovingItem.Item;
               MovingItem.Index := idx;
               MovingItem.Item := temp
            end else begin
               ItemArr[idx] := MovingItem.Item;
               MovingItem.Item.S.name := '';
               ItemMoving := FALSE;
            end;
         end;
      end;
   end;
end;

{procedure TFrmDlg.DBelt1Click(Sender: TObject; X, Y: Integer);
var
   idx: integer;
   temp: TClientItem;
begin
   idx := TDButton(Sender).Tag;
   if idx in [0..5] then begin
      if not ItemMoving then begin
         if ItemArr[idx].S.Name <> '' then begin
            ItemClickSound (ItemArr[idx].S);
            ItemMoving := TRUE;
            MovingItem.Index := idx;
            MovingItem.Item := ItemArr[idx];
            ItemArr[idx].S.Name := '';
         end;
      end else begin
         if (MovingItem.Index = -97) or (MovingItem.Index = -98) then exit;
         if MovingItem.Item.S.StdMode <= 3 then begin //Æ÷¼Ç,À½½Ä,½ºÅ©·Ñ
            //ItemClickSound (MovingItem.Item.S.StdMode);
            if ItemArr[idx].S.Name <> '' then begin
               temp := ItemArr[idx];
               ItemArr[idx] := MovingItem.Item;
               MovingItem.Index := idx;
               MovingItem.Item := temp
            end else begin
               ItemArr[idx] := MovingItem.Item;
               MovingItem.Item.S.name := '';
               ItemMoving := FALSE;
            end;
         end;
      end;
   end;
end;}

procedure TFrmDlg.DBelt1DblClick(Sender: TObject);
var
   idx, where: integer;
   TempSender: TObject;
begin
   idx := TDButton(Sender).Tag;
   if idx in [0..5] then begin
      if ItemArr[idx].S.Name <> '' then begin
         if (ItemArr[idx].S.StdMode <= 4) or (ItemArr[idx].S.StdMode = 31) then begin //»ç¿ëÇÒ ¼ö ÀÖ´Â ¾ÆÀÌÅÛ
            StBeltAutoFill := True;
            FrmMain.EatItem (idx);
         end;
      end else begin
//         if ItemMoving and (MovingItem.Index = idx) and
//           (MovingItem.Item.S.StdMode <= 4) or (MovingItem.Item.S.StdMode = 31)
         if ItemMoving and (MovingItem.Index = idx) and
           (MovingItem.Item.S.StdMode <= 4) or (MovingItem.Item.S.StdMode = 31) or
           (MovingItem.Item.S.StdMode = 25)
         then begin
            if MovingItem.Item.S.StdMode = 25 then begin
//      DScreen.AddChatBoardString ('MovingItem.Item.S.Shape=> '+IntToStr(MovingItem.Item.S.Shape), clYellow, clRed);
                  where := GetTakeOnPosition (MovingItem.Item.S.StdMode);
                  if MovingItem.Index >= 0 then begin
                     case where of
                        U_ARMRINGR, U_BUJUK: begin
                           TempSender := DSWBujuk;
                        end;
                     end;
                  end;
                  DSWWeaponClick(TempSender, 1, 1);
                  Exit;
            end;
            StBeltAutoFill := True;
            FrmMain.EatItem (-1);
            BtInDex := idx;
         end;
      end;
   end;
end;

{----------------------------------------------------------}

//¾ÆÀÌÅÛ °¡¹æ

{----------------------------------------------------------}



procedure TFrmDlg.GetMouseItemInfo (var iname, line1, line2, line3, line4: string; var useable: boolean; bowear: Boolean);
   function GetDuraStr (dura, maxdura: integer): string;
   begin
      if not BoNoDisplayMaxDura then begin
         if dura <= 1 then Result := '<F:C=$3232FF>ÄÍ¾Ã : ' + IntToStr(Round(dura/1000)) + '/' + IntToStr(Round(maxdura/1000))
         else Result := '<F:C=$FFFF80>ÄÍ¾Ã : ' + IntToStr(Round(dura/1000)) + '/' + IntToStr(Round(maxdura/1000));
      end else
         Result := IntToStr(Round(dura/1000));
   end;
   function GetDura100Str (dura, maxdura: integer): string;
   begin
      if not BoNoDisplayMaxDura then
         Result := IntToStr(Round(dura/100)) + '/' + IntToStr(Round(maxdura/100))
      else
         Result := IntToStr(Round(dura/100));
   end;
begin
   if Myself = nil then exit;
   iname := ''; line1 := ''; line2 := ''; line3 := '';
   useable := TRUE;

   if MouseItem.S.Name <> '' then begin
      iname := '<F:C=$00FAFF>¨‹ ' + MouseItem.S.Name + '\';   //ÑÕÉ«$FAFA00
      case MouseItem.S.StdMode of
         0: begin //½Ã¾à
               if MouseItem.S.Shape = 1 then begin //¼ÖÀÙ
                  if (MouseItem.S.DC > 0) and (MouseItem.S.MC > 0) then begin
                     line1 := line1 + 'HP'+ IntToStr(MouseItem.S.DC)+'%È¸º¹ ';
                     line1 := line1 + 'MP'+ IntToStr(MouseItem.S.MC)+'%È¸º¹ ';
                  end
                  else if (MouseItem.S.DC > 0) then
                     line1 := line1 + 'HP'+ IntToStr(MouseItem.S.DC)+'%È¸º¹ '
                  else if (MouseItem.S.MC > 0) then
                     line1 := line1 + 'MP'+ IntToStr(MouseItem.S.MC)+'%È¸º¹ ';
               end;

               if MouseItem.S.AC > 0 then
                  line1 := '+' + IntToStr(MouseItem.S.AC) + 'HP ';
               if MouseItem.S.MAC > 0 then
                  line1 := line1 + '+' + IntToStr(MouseItem.S.MAC) + 'MP ';

               line1 := line1 + 'ÖØÁ¿ : ' + IntToStr(MouseItem.S.Weight);
            end;
         1..3:
            begin
               if (MouseItem.S.StdMode = 3) and (MouseItem.S.Shape = 12) and (MouseItem.S.Name = '»ýÀÏ¶±') then begin
                  line1 := line1 + 'ÖØÁ¿ : ' +  IntToStr(MouseItem.S.Weight);
                  line3 := MySelf.UserName + '´ÔÀÇ »ýÀÏÀ» ÃàÇÏ ÇÕ´Ï´Ù.';
               end
               else if MouseItem.S.OverlapItem = 1 then
                  line1 := line1 + 'ÖØÁ¿ : ' +  IntToStr(MouseItem.Dura div 10) +
                           ' °³¼ö' + IntToStr(MouseItem.Dura)
               else if MouseItem.S.OverlapItem = 2 then
                  line1 := line1 + 'ÖØÁ¿ : ' +  IntToStr(MouseItem.S.Weight * MouseItem.Dura) +
                           ' °³¼ö' + IntToStr(MouseItem.Dura)
               else
                  line1 := line1 + 'ÖØÁ¿ : ' +  IntToStr(MouseItem.S.Weight);
            end;
         4:
            begin
               line1 := line1 + 'ÖØÁ¿ : ' +  IntToStr(MouseItem.S.Weight);
               useable := FALSE;
               case MouseItem.S.Shape of
                  0: begin
                        line2 := 'Àü»ç¹«°øºñ±Þ';
                        line4 := 'ÇÊ¿ä·¹º§ ' + IntToStr(MouseItem.S.DuraMax);
                        if (Myself.Job = 0) and (Myself.Abil.Level >= MouseItem.S.DuraMax) then
                           useable := TRUE;
                     end;
                  1: begin
                        line2 := 'ÁÖ¼ú»ç¸¶¹ýÃ¥';
                        line4 := 'ÇÊ¿ä·¹º§ ' + IntToStr(MouseItem.S.DuraMax);
                        if (Myself.Job = 1) and (Myself.Abil.Level >= MouseItem.S.DuraMax) then
                           useable := TRUE;
                     end;
                  2: begin
                        line2 := 'µµ»ç¹«°øºñ±Þ';
                        line4 := 'ÇÊ¿ä·¹º§ ' + IntToStr(MouseItem.S.DuraMax);
                        if (Myself.Job = 2) and (Myself.Abil.Level >= MouseItem.S.DuraMax) then
                           useable := TRUE;
                     end;
               end;
            end;
         5..6: //¹«±â
            begin
               useable := FALSE;
               if MouseItem.S.ItemDesc and $01 <> 0 then  //¾ÆÀÌµ§Æ¼ÇÇ¾Æ ¾È µÈ °ÍÀÓ
                  iname := '(*)' + iname;

               line1 := line1 + GetDuraStr(MouseItem.Dura, MouseItem.DuraMax) + '\';  //ÄÍ¾Ã
               line1 := line1 + 'ÖØÁ¿ : ' + IntToStr(MouseItem.S.Weight) + '\';

               if MouseItem.S.DC > 0 then
                  line2 := 'ÆÆ»µ : ' + IntToStr(Lobyte(MouseItem.S.DC)) + '-' + IntToStr(Hibyte(MouseItem.S.DC)) + '\';
               if MouseItem.S.MC > 0 then
                  line2 := line2 + '×ÔÈ»ÏµÄ§Á¦ : ' + IntToStr(Lobyte(MouseItem.S.MC)) + '-' + IntToStr(Hibyte(MouseItem.S.MC)) + '\';
               if MouseItem.S.SC > 0 then
                  line2 := line2 + 'Áé»êÏµÄ§Á¦ : ' + IntToStr(Lobyte(MouseItem.S.SC)) + '-' + IntToStr(Hibyte(MouseItem.S.SC)) + '\';
               if MouseItem.S.SpecialPwr in [1..10] then  //¹«±âÀÇ °­µµ
                  line2 := line2 + '°­µµ+' + IntToStr(MouseItem.S.SpecialPwr) + ' ';
               if (MouseItem.S.SpecialPwr <= -1) and (MouseItem.S.SpecialPwr >= -50) then
                  line2 := line2 + '½Å¼º+' + IntToStr(-MouseItem.S.SpecialPwr) + ' ';
               if (MouseItem.S.SpecialPwr <= -51) and (MouseItem.S.SpecialPwr >= -100) then
                  line2 := line2 + '½Å¼º-' + IntToStr((-MouseItem.S.SpecialPwr) - 50) + ' ';
               if Hibyte(MouseItem.S.AC) > 0 then
                  line2 := line2 + 'Á¤È®+' + IntToStr(Hibyte(MouseItem.S.AC)) + ' ';
               if MouseItem.S.Slowdown > 0 then
                  line3 := line3 + 'µÐÈ­+' + IntToStr(MouseItem.S.Slowdown) + ' '; //==Upgradeitem==
               if MouseItem.S.Tox > 0 then
                  line3 := line3 + 'Áßµ¶+' + IntToStr(MouseItem.S.Tox) + ' '; //==Upgradeitem==
               if Hibyte(MouseItem.S.MAC) > 0 then begin
                  if Hibyte(MouseItem.S.MAC) > 10 then
                     line3 := line3 + '°ø°Ý¼Óµµ+' + IntToStr(Hibyte(MouseItem.S.MAC)-10) + ' '
                  else
                     line3 := line3 + '°ø°Ý¼Óµµ-' + IntToStr(Hibyte(MouseItem.S.MAC)) + ' ';
               end;
               if (MouseItem.S.AC and $80) <> 0 then begin
                  line3 := line3 + 'Ãà ';
               end;
               if Lobyte(MouseItem.S.AC and $7F) > 0 then
                  line3 := line3 + 'Çà¿î+' + IntToStr(Lobyte(MouseItem.S.AC and $7F)) + ' ';
               if Lobyte(MouseItem.S.MAC) > 0 then
                  line3 := line3 + 'ÀúÁÖ+' + IntToStr(Lobyte(MouseItem.S.MAC)) + ' ';
               case MouseItem.S.Need of
                  0: begin
                        if Myself.Abil.Level >= MouseItem.S.NeedLevel then
                           useable := TRUE;
                        line4 := line4 + 'ÐèÒªµÈ¼¶ : ' + IntToStr(MouseItem.S.NeedLevel);
                     end;
                  1: begin
                        if hibyte (Myself.Abil.DC) >= MouseItem.S.NeedLevel then
                           useable := TRUE;
                        line4 := line4 + 'ÇÊ¿äÆÄ±«·Â' + IntToStr(MouseItem.S.NeedLevel);
                     end;
                  2: begin
                        if hibyte (Myself.Abil.MC) >= MouseItem.S.NeedLevel then
                           useable := TRUE;
                        line4 := line4 + 'ÇÊ¿ä¸¶¹ý·Â' + IntToStr(MouseItem.S.NeedLevel);
                     end;
                  3: begin
                        if hibyte (Myself.Abil.SC) >= MouseItem.S.NeedLevel then
                           useable := TRUE;
                        line4 := line4 + 'ÇÊ¿äµµ·Â' + IntToStr(MouseItem.S.NeedLevel);
                     end;
               end;
            end;
         7: begin //³ë²ö
               if MouseItem.S.OverlapItem = 1 then
                  line1 := line1 + 'ÖØÁ¿ : ' +  IntToStr(MouseItem.Dura div 10) +
                           ' °³¼ö' + IntToStr(MouseItem.Dura)
               else if MouseItem.S.OverlapItem = 2 then
                  line1 := line1 + 'ÖØÁ¿ : ' +  IntToStr(MouseItem.S.Weight * MouseItem.Dura) +
                           ' °³¼ö' + IntToStr(MouseItem.Dura)
               else
                  line1 := line1 + '¹«°Ô' +  IntToStr(MouseItem.S.Weight);
               line2 := 'CtrlÅ°¸¦ ´©¸£°í ¹­À» ¾ÆÀÌÅÛ ¼±ÅÃ';
            end;
         8: begin
               case MouseItem.S.Shape of
                  0: begin //ÃÊ´ëÀå
                        line1 := line1 + IntToStr(MouseItem.Dura) + '¹øÀå¿ø ¹«°Ô' +  IntToStr(MouseItem.S.Weight);
                        line2 := 'À¯È¿±â°£Àº 24½Ã°£ ÀÔ´Ï´Ù.';
                     end;
                  1: begin //¿Õ¹æÀÌµ¿ ¸¶ÆÐ
                        line1 := line1 + '¹«°Ô' +  IntToStr(MouseItem.S.Weight);
                        line2 := '½Ã°ø°£À» ÃÊ¿ùÇÏ¿© ÀÚ½ÅÀ» ÀÌ²ô´Â ÈûÀÌ';
                        line3 := '´À²¸Áý´Ï´Ù.'
                     end;
                  2:       //¼±¹°»óÀÚ È²±Ý´Þ°¿
                    line1 := line1 + 'ÖØÁ¿ : ' +  IntToStr(MouseItem.S.Weight);
               end;
            end;
         9: begin //»óÇöÁÖ¸Ó´Ï
//               line1 := DecoItemDesc( MouseItem.Dura);
//               line1 := line1 + ' ¹«°Ô' +  IntToStr(MouseItem.S.Weight)
//                                        + ' ³»±¸'+ IntToStr(Round(MouseItem.DuraMax/1000));
               line1 := 'ÖØÁ¿ : ' +  IntToStr(MouseItem.S.Weight)
                                + ' ³»±¸'+ IntToStr(Round(MouseItem.DuraMax/1000));
//                                + ' ³»±¸'+ IntToStr(Trunc(MouseItem.DuraMax/1000));
               line2 := DecoItemDesc( MouseItem.Dura, line3);
            end;
         10, 11:  //³²ÀÚ¿Ê, ¿©ÀÚ¿Ê
            begin
               useable := FALSE;
               line1 := line1 + GetDuraStr(MouseItem.Dura, MouseItem.DuraMax) + '\';
               line1 := line1 + 'ÖØÁ¿ : ' + IntToStr(MouseItem.S.Weight) + '\';

               if MouseItem.S.AC > 0 then
                  line2 := 'ÎïÀí·ÀÓù : ' + IntToStr(Lobyte(MouseItem.S.AC)) + '-' + IntToStr(Hibyte(MouseItem.S.AC)) + '\';
               if MouseItem.S.MAC > 0 then
                  line2 := line2 + 'Ä§·¨·ÀÓù : ' + IntToStr(Lobyte(MouseItem.S.MAC)) + '-' + IntToStr(Hibyte(MouseItem.S.MAC)) + '\';
               if MouseItem.S.DC > 0 then
                  line2 := line2 + 'ÆÆ»µ : ' + IntToStr(Lobyte(MouseItem.S.DC)) + '-' + IntToStr(Hibyte(MouseItem.S.DC)) + '\';
               if MouseItem.S.MC > 0 then
                  line2 := line2 + '×ÔÈ»ÏµÄ§Á¦ : ' + IntToStr(Lobyte(MouseItem.S.MC)) + '-' + IntToStr(Hibyte(MouseItem.S.MC)) + '\';
               if MouseItem.S.Agility > 0 then
                  line2 := line2 + '¹ÎÃ¸+' + IntToStr(MouseItem.S.Agility) + '\'; // ==Upgradeitem==
               if MouseItem.S.SC > 0 then
                  line2 := line2 + 'Áé»êÏµÄ§Á¦ : ' + IntToStr(Lobyte(MouseItem.S.SC)) + '-' + IntToStr(Hibyte(MouseItem.S.SC)) + '\';

               if MouseItem.S.HpAdd > 0 then
                  line3 := line3 + 'HP+' + IntToStr(MouseItem.S.HpAdd) + ' ';
               if MouseItem.S.MpAdd > 0 then
                  line3 := line3 + 'MP+' + IntToStr(MouseItem.S.MpAdd) + ' ';
               if MouseItem.S.EffType1 = 3 then
                  line3 := line3 + 'Çà¿î+' + IntToStr(MouseItem.S.EffValue1) + ' ';
               if MouseItem.S.MgAvoid > 0 then
                  line3 := line3 + '¸¶¹ýÀúÇ×+' + IntToStr(MouseItem.S.MgAvoid )+ ' '; //==Upgradeitem==
               if MouseItem.S.ToxAvoid > 0 then
                  line3 := line3 + 'Áßµ¶ÀúÇ×+' + IntToStr(MouseItem.S.ToxAvoid )+ ' '; //==Upgradeitem==

               case MouseItem.S.EffType1 of
                  5: begin
                        line3 := line3 + 'Ã¼·ÂÈ¸º¹+' + IntToStr(MouseItem.S.EffRate1 * 10) + '% ';
                        line3 := line3 + '¸¶·ÂÈ¸º¹+' + IntToStr(MouseItem.S.EffValue1 * 10) + '% ';
                     end;
               end;
               case MouseItem.S.EffType2 of
                  5: begin
                        line3 := line3 + 'Ã¼·ÂÈ¸º¹+' + IntToStr(MouseItem.S.EffRate2 * 10) + '% ';
                        line3 := line3 + '¸¶·ÂÈ¸º¹+' + IntToStr(MouseItem.S.EffValue2 * 10) + '% ';
                     end;
               end;

               case MouseItem.S.Need of
                  0: begin
                        if Myself.Abil.Level >= MouseItem.S.NeedLevel then
                           useable := TRUE;
                        line4 := 'ÐèÒªµÈ¼¶ : ' + IntToStr(MouseItem.S.NeedLevel);
                     end;
                  1: begin
                        if hibyte (Myself.Abil.DC) >= MouseItem.S.NeedLevel then
                           useable := TRUE;
                        line4 := 'ÇÊ¿äÆÄ±«·Â' + IntToStr(MouseItem.S.NeedLevel);
                     end;
                  2: begin
                        if hibyte (Myself.Abil.MC) >= MouseItem.S.NeedLevel then
                           useable := TRUE;
                        line4 := 'ÇÊ¿ä¸¶¹ý·Â' + IntToStr(MouseItem.S.NeedLevel);
                     end;
                  3: begin
                        if hibyte (Myself.Abil.SC) >= MouseItem.S.NeedLevel then
                           useable := TRUE;
                        line4 := 'ÇÊ¿äµµ·Â' + IntToStr(MouseItem.S.NeedLevel);
                     end;
               end;
            end;
         15,     //¸ðÀÚ,Åõ±¸
         19,20,21,  //¸ñ°ÉÀÌ
         22,23,  //¹ÝÁö
         // 2003/03/15 ¾ÆÀÌÅÛ ÀÎº¥Åä¸® È®Àå
         52,53,54,
         24,26:  //ÆÈÂî
            begin
               useable := FALSE;
               line1 := line1 + '¹«°Ô' + IntToStr(MouseItem.S.Weight)+ ' ';
               if (MouseItem.S.StdMode <> 53) then
                  line1 := line1 + '³»±¸'+ GetDuraStr(MouseItem.Dura, MouseItem.DuraMax)+ ' ';
               // 2003/08/25 ÆÈÂî ¾ÆÀÌÅÛ, ½Å¼º¼Ó¼º Ç³¼± µµ¿ò¸» Ãß°¡.  // AddHolyMent
               if MouseItem.S.StdMode = 15 then begin
                  if (MouseItem.S.Accurate > 0) then
                     line2 := line2 + 'Á¤È®+'+ IntToStr(MouseItem.S.Accurate)+ ' '; // ==Upgradeitem==
                  if MouseItem.S.MgAvoid > 0 then
                     line3 := line3 + '¸¶¹ýÀúÇ×+' + IntToStr(MouseItem.S.MgAvoid )+ ' '; //==Upgradeitem==
                  if MouseItem.S.ToxAvoid > 0 then
                     line3 := line3 + 'Áßµ¶ÀúÇ×+' + IntToStr(MouseItem.S.ToxAvoid )+ ' '; //==Upgradeitem==
               end;
               if MouseItem.S.StdMode = 26 then begin
                  if (MouseItem.S.Accurate > 0) then
                     line2 := line2 + 'Á¤È®+'+ IntToStr(MouseItem.S.Accurate)+ ' '; // ==Upgradeitem==
                  if MouseItem.S.Agility > 0 then
                     line2 := line2 + '¹ÎÃ¸+' + IntToStr(MouseItem.S.Agility) + ' '; // ==Upgradeitem==
               end;
               if (MouseItem.S.StdMode = 52) or (MouseItem.S.StdMode = 54)then begin
//                  if MouseItem.S.AC > 0 then
//                     line2 := '¹æ¾î' + IntToStr(Lobyte(MouseItem.S.AC)) + '-' + IntToStr(Hibyte(MouseItem.S.AC)) + ' ';// ==Upgradeitem==
//                  if MouseItem.S.MAC > 0 then
//                     line2 := line2 + '¸¶Ç×' + IntToStr(Lobyte(MouseItem.S.MAC)) + '-' + IntToStr(Hibyte(MouseItem.S.MAC)) + ' ';// ==Upgradeitem==
                  if MouseItem.S.Agility > 0 then
                     line2 := line2 + '¹ÎÃ¸+' + IntToStr(MouseItem.S.Agility) + ' '; // ==Upgradeitem==
                  if (MouseItem.S.Accurate > 0) then   //2004/01/08
                     line2 := line2 + 'Á¤È®+'+ IntToStr(MouseItem.S.Accurate)+ ' '; // ==Upgradeitem==

                  if MouseItem.S.StdMode = 54 then begin
                     if MouseItem.S.ToxAvoid > 0 then
                        line3 := line3 + 'Áßµ¶ÀúÇ×+' + IntToStr(MouseItem.S.ToxAvoid )+ ' '; //==Upgradeitem==
                  end;
               end;
               if (MouseItem.S.SpecialPwr <= -1) and (MouseItem.S.SpecialPwr >= -50) then
                  line2 := line2 + '½Å¼º+' + IntToStr(-MouseItem.S.SpecialPwr) + ' ';
               if (MouseItem.S.SpecialPwr <= -51) and (MouseItem.S.SpecialPwr >= -100) then
                  line2 := line2 + '½Å¼º-' + IntToStr((-MouseItem.S.SpecialPwr) - 50) + ' ';
               //-----------------

               if ((MouseItem.S.Shape = RING_OF_UNKNOWN) or
                   (MouseItem.S.Shape = BRACELET_OF_UNKNOWN) or
                   (MouseItem.S.Shape = HELMET_OF_UNKNOWN)
                  ) and (not bowear)
               then begin
                  line2 := '????????';
               end else begin
                  case MouseItem.S.StdMode of
                     19: //¸ñ°ÉÀÌ
                        begin
                           if MouseItem.S.AtkSpd > 0 then
                              line2 := line2 + '°ø°Ý¼Óµµ+' + IntToStr(MouseItem.S.AtkSpd ) + ' ';
                           if (MouseItem.S.Accurate > 0) then
                              line2 := line2 + 'Á¤È®+'+ IntToStr(MouseItem.S.Accurate)+ ' '; // ==Upgradeitem==
                           if MouseItem.S.Slowdown > 0 then
                              line2 := line2 + 'µÐÈ­+' + IntToStr(MouseItem.S.Slowdown) + ' '; //==Upgradeitem==
                           if MouseItem.S.Tox > 0 then
                              line2 := line2 + 'Áßµ¶+' + IntToStr(MouseItem.S.Tox) + ' '; //==Upgradeitem==
//                           if MouseItem.S.MgAvoid > 0 then
//                              line3 := line3 + '¸¶¹ýÀúÇ×' + IntToStr(MouseItem.S.MgAvoid)+ ' '; //==Upgradeitem==
                           if MouseItem.S.AC > 0 then begin
                              line3 := line3 + '¸¶¹ýÀúÇ×+' + IntToStr(Hibyte(MouseItem.S.AC) ) + ' ';
                           end;
                           if Lobyte(MouseItem.S.MAC) > 0 then line2 := line2 + 'ÀúÁÖ+' + IntToStr(Lobyte(MouseItem.S.MAC)) + ' ';
                           if Hibyte(MouseItem.S.MAC) > 0 then line2 := line2 + 'Çà¿î+' + IntToStr(Hibyte(MouseItem.S.MAC)) + ' ';
                              //¼ýÀÚ Ç¥½Ã¾ÈµÊ + IntToStr(Hibyte(MouseItem.S.MAC)) + ' ';
                        end;
                      20:
                         begin
                           if MouseItem.S.AC > 0 then
                              line2 := line2 + 'Á¤È®+' + IntToStr(Hibyte(MouseItem.S.AC)) + ' ';
                           if MouseItem.S.MAC > 0 then
                              line2 := line2 + '¹ÎÃ¸+' + IntToStr(Hibyte(MouseItem.S.MAC)) + ' ';
                           if MouseItem.S.AtkSpd > 0 then
                              line2 := line2 + '°ø°Ý¼Óµµ+' + IntToStr(MouseItem.S.AtkSpd ) + ' ';
                           if MouseItem.S.Slowdown > 0 then
                              line2 := line2 + 'µÐÈ­+' + IntToStr(MouseItem.S.Slowdown) + ' '; //==Upgradeitem==
                           if MouseItem.S.Tox > 0 then
                              line2 := line2 + 'Áßµ¶+' + IntToStr(MouseItem.S.Tox) + ' '; //==Upgradeitem==
                           if MouseItem.S.MgAvoid > 0 then
                              line3 := line3 + '¸¶¹ýÀúÇ×+' + IntToStr(MouseItem.S.MgAvoid )+ ' '; //==Upgradeitem==
                        end;
                     21:  //¸ñ°ÉÀÌ
                        begin
                           if Hibyte(MouseItem.S.AC) > 0 then
                              line2 := line2 + 'Ã¼·ÂÈ¸º¹+' + IntToStr(Hibyte(MouseItem.S.AC)) + '0% ';
                           if Hibyte(MouseItem.S.MAC) > 0 then
                              line2 := line2 + '¸¶·ÂÈ¸º¹+' + IntToStr(Hibyte(MouseItem.S.MAC)) + '0% ';
                           if MouseItem.S.Accurate > 0 then
                              line2 := line2 + 'Á¤È®+' + IntToStr(MouseItem.S.Accurate) + ' '; //==Upgradeitem==
                           if MouseItem.S.Slowdown > 0 then
                              line2 := line2 + 'µÐÈ­+' + IntToStr(MouseItem.S.Slowdown) + ' '; //==Upgradeitem==
                           if MouseItem.S.Tox > 0 then
                              line2 := line2 + 'Áßµ¶+' + IntToStr(MouseItem.S.Tox) + ' '; //==Upgradeitem==
//                           if MouseItem.S.AtkSpd > 0 then
//                              line3 := line3 + '°ø°Ý¼Óµµ+' + IntToStr(MouseItem.S.AtkSpd ) + ' ';
                           if Lobyte(MouseItem.S.AC) + MouseItem.S.AtkSpd > 0 then
                              line3 := line3 + '°ø°Ý¼Óµµ+' + IntToStr(Lobyte(MouseItem.S.AC)+MouseItem.S.AtkSpd) + ' ';
                           if Lobyte(MouseItem.S.MAC) > 0 then
                              line3 := line3 + '°ø°Ý¼Óµµ-' + IntToStr(Lobyte(MouseItem.S.MAC)) + ' ';
                           if MouseItem.S.MgAvoid > 0 then
                              line3 := line3 + '¸¶¹ýÀúÇ×+' + IntToStr(MouseItem.S.MgAvoid )+ ' '; //==Upgradeitem==
                        end;
                     22:
                        begin
                           if MouseItem.S.AC > 0 then
                              line2 := line2 + '¹æ¾î' + IntToStr(Lobyte(MouseItem.S.AC)) + '-' + IntToStr(Hibyte(MouseItem.S.AC)) + ' ';
                           if MouseItem.S.MAC > 0 then
                              line2 := line2 + '¸¶Ç×' + IntToStr(Lobyte(MouseItem.S.MAC)) + '-' + IntToStr(Hibyte(MouseItem.S.MAC)) + ' ';
                           if MouseItem.S.AtkSpd > 0 then
                              line2 := line2 + '°ø°Ý¼Óµµ+' + IntToStr(MouseItem.S.AtkSpd ) + ' ';
                           if MouseItem.S.Slowdown > 0 then
                              line2 := line2 + 'µÐÈ­+' + IntToStr(MouseItem.S.Slowdown) + ' '; //==Upgradeitem==
                           if MouseItem.S.Tox > 0 then
                              line2 := line2 + 'Áßµ¶+' + IntToStr(MouseItem.S.Tox) + ' '; //==Upgradeitem==
                        end;
                     23:  //¹ÝÁö
                        begin
                           if MouseItem.S.Slowdown > 0 then
                              line2 := line2 + 'µÐÈ­+' + IntToStr(MouseItem.S.Slowdown) + ' '; //==Upgradeitem==
                           if MouseItem.S.Tox > 0 then
                              line2 := line2 + 'Áßµ¶+' + IntToStr(MouseItem.S.Tox) + ' '; //==Upgradeitem==
                           if Hibyte(MouseItem.S.AC) > 0 then
                              line2 := line2 + 'Áßµ¶ÀúÇ×+' + IntToStr(Hibyte(MouseItem.S.AC) ) + ' ';
                           if Hibyte(MouseItem.S.MAC) > 0 then
                              line2 := line2 + 'Áßµ¶È¸º¹+' + IntToStr(Hibyte(MouseItem.S.MAC)) + '0% ';
//                           if MouseItem.S.AtkSpd > 0 then
//                              line3 := line3 + '°ø°Ý¼Óµµ+' + IntToStr(MouseItem.S.AtkSpd ) + ' ';
                           if Lobyte(MouseItem.S.AC) + MouseItem.S.AtkSpd > 0 then
                              line3 := line3 + '°ø°Ý¼Óµµ+' + IntToStr(Lobyte(MouseItem.S.AC)+MouseItem.S.AtkSpd) + ' ';
                           if Lobyte(MouseItem.S.MAC) > 0 then
                              line3 := line3 + '°ø°Ý¼Óµµ-' + IntToStr(Lobyte(MouseItem.S.MAC)) + ' ';
                        end;
                     24: //ÆÈÂî
                        begin
                           if MouseItem.S.AC > 0 then
                              line2 := line2 + 'Á¤È®+' + IntToStr(Hibyte(MouseItem.S.AC)) + ' ';
                           if MouseItem.S.MAC > 0 then
                              line2 := line2 + '¹ÎÃ¸+' + IntToStr(Hibyte(MouseItem.S.MAC)) + ' ';
{                           if (MouseItem.S.Accurate > 0) then
                              line2 := line2 + 'Á¤È®+'+ IntToStr(MouseItem.S.Accurate)+ ' '; // ==Upgradeitem==
                           if MouseItem.S.Agility > 0 then
                              line2 := line2 + '¹ÎÃ¸+' + IntToStr(MouseItem.S.Agility) + ' '; // ==Upgradeitem==}
                        end;
                     else
                        begin
                           if MouseItem.S.AC > 0 then
                              line2 := line2 + '¹æ¾î' + IntToStr(Lobyte(MouseItem.S.AC)) + '-' + IntToStr(Hibyte(MouseItem.S.AC)) + ' ';
                           if MouseItem.S.MAC > 0 then
                              line2 := line2 + '¸¶Ç×' + IntToStr(Lobyte(MouseItem.S.MAC)) + '-' + IntToStr(Hibyte(MouseItem.S.MAC)) + ' ';
                        end;
                  end;
                  if MouseItem.S.DC > 0 then
                     line2 := line2 + 'ÆÄ±«' + IntToStr(Lobyte(MouseItem.S.DC)) + '-' + IntToStr(Hibyte(MouseItem.S.DC)) + ' ';
                  if MouseItem.S.MC > 0 then
                     line2 := line2 + '¸¶¹ý' + IntToStr(Lobyte(MouseItem.S.MC)) + '-' + IntToStr(Hibyte(MouseItem.S.MC)) + ' ';
                  if MouseItem.S.SC > 0 then
                     line2 := line2 + 'µµ·Â' + IntToStr(Lobyte(MouseItem.S.SC)) + '-' + IntToStr(Hibyte(MouseItem.S.SC)) + ' ';
                  // 2003/03/15 ¾ÆÀÌÅÛ ÀÎº¥Åä¸® È®Àå
                  if MouseItem.S.HpAdd > 0 then
                     line2 := line2 + 'HP+' + IntToStr(MouseItem.S.HpAdd) + ' ';
                  if MouseItem.S.MpAdd > 0 then begin
                     if MouseItem.S.StdMode = 26 then
                        line3 := line3 + 'MP+' + IntToStr(MouseItem.S.MpAdd) + ' '
                     else
                        line2 := line2 + 'MP+' + IntToStr(MouseItem.S.MpAdd) + ' ';
                  end;
                  if MouseItem.S.ExpAdd > 0 then
                     line2 := line2 + '°æÇèÄ¡+' + IntToStr(MouseItem.S.ExpAdd) + ' ';
                  case MouseItem.S.EffType1 of
                     1: begin
                           line2 := line2 + '¾ç¼Õ¹«°Ô+' + IntToStr(MouseItem.S.EffValue1) + ' ';
                        end;
                     2: begin
                           line2 := line2 + 'Âø¿ë¹«°Ô+' + IntToStr(MouseItem.S.EffValue1) + ' ';
                        end;
                     4: begin
                           line2 := line2 + '°¡¹æ¹«°Ô+' + IntToStr(MouseItem.S.EffValue1) + ' ';
                        end;
//                     5: begin
//                           line2 := line2 + 'Ã¼·ÂÈ¸º¹+' + IntToStr(MouseItem.S.EffRate1) + '% ';
//                           line2 := line2 + '¸¶·ÂÈ¸º¹+' + IntToStr(MouseItem.S.EffValue1) + '% ';
//                        end;

                  end;
                  case MouseItem.S.EffType2 of
                     1: begin
                           line2 := line2 + '¾ç¼Õ¹«°Ô+' + IntToStr(MouseItem.S.EffValue2) + ' ';
                        end;
                     2: begin
                           line2 := line2 + 'Âø¿ë¹«°Ô+' + IntToStr(MouseItem.S.EffValue2) + ' ';
                        end;
                     4: begin
                           line2 := line2 + '°¡¹æ¹«°Ô+' + IntToStr(MouseItem.S.EffValue2) + ' ';
                        end;
//                     5: begin
//                           line2 := line2 + 'Ã¼·ÂÈ¸º¹+' + IntToStr(MouseItem.S.EffRate2) + '% ';
//                           line2 := line2 + '¸¶·ÂÈ¸º¹+' + IntToStr(MouseItem.S.EffValue2) + '% ';
//                        end;
                  end;

                  case MouseItem.S.Need of
                     0: begin
                           if Myself.Abil.Level >= MouseItem.S.NeedLevel then useable := TRUE;
                           line4 := line4 + 'ÇÊ¿ä·¹º§' + IntToStr(MouseItem.S.NeedLevel);
                        end;
                     1: begin
                           if hibyte (Myself.Abil.DC) >= MouseItem.S.NeedLevel then
                              useable := TRUE;
                           line4 := line4 + 'ÇÊ¿äÆÄ±«·Â' + IntToStr(MouseItem.S.NeedLevel);
                        end;
                     2: begin
                           if hibyte (Myself.Abil.MC) >= MouseItem.S.NeedLevel then
                              useable := TRUE;
                           line4 := line4 + 'ÇÊ¿ä¸¶¹ý·Â' + IntToStr(MouseItem.S.NeedLevel);
                        end;
                     3: begin
                           if hibyte (Myself.Abil.SC) >= MouseItem.S.NeedLevel then
                              useable := TRUE;
                           line4 := line4 + 'ÇÊ¿äµµ·Â' + IntToStr(MouseItem.S.NeedLevel);
                        end;
                  end;
               end;
            end;
         25: //»Ñ¸®´Â µ¶°¡·ç
            begin
               line1 := line1 + 'Ê¹ÓÃ : '+ GetDura100Str(MouseItem.Dura, MouseItem.DuraMax);
               line2 := 'ÖØÁ¿ : ' +  IntToStr(MouseItem.S.Weight);
            end;
         30: //ÃÊ,È½ºÒ
            begin
               line1 := line1 + 'ÄÍ¾Ã : '+ GetDuraStr(MouseItem.Dura, MouseItem.DuraMax) + '\';
               line1 := line1 + 'ÖØÁ¿ : ' +  IntToStr(MouseItem.S.Weight) + '\';
//               if MouseItem.S.Shape = 2 then begin
                  if MouseItem.S.DC > 0 then
                     line2 := line2 + 'ÆÆ»µ : ' + IntToStr(Lobyte(MouseItem.S.DC)) + '-' + IntToStr(Hibyte(MouseItem.S.DC)) + '\';
                  if MouseItem.S.MC > 0 then
                     line2 := line2 + '×ÔÈ»ÏµÄ§Á¦ : ' + IntToStr(Lobyte(MouseItem.S.MC)) + '-' + IntToStr(Hibyte(MouseItem.S.MC)) + '\';
                  if MouseItem.S.SC > 0 then
                     line2 := line2 + 'Áé»êÏµÄ§Á¦ : ' + IntToStr(Lobyte(MouseItem.S.SC)) + '-' + IntToStr(Hibyte(MouseItem.S.SC)) + '\';
//               end;
            end;
         40: //°í±âµ¢¾î¸®
            begin
               line1 := line1 + 'ÖØÁ¿ : ' +  IntToStr(MouseItem.S.Weight) + ' Ç°Áú'+ GetDuraStr(MouseItem.Dura, MouseItem.DuraMax);
            end;
         42: //¾à Àç·á
            begin
               if MouseItem.S.OverlapItem = 1 then
                  line1 := line1 + 'ÖØÁ¿ : ' +  IntToStr(MouseItem.Dura div 10) +
                           ' °³¼ö' + IntToStr(MouseItem.Dura) + ' ¾àÀç'
               else if MouseItem.S.OverlapItem = 2 then
                  line1 := line1 + '¹«°Ô' +  IntToStr(MouseItem.S.Weight * MouseItem.Dura) +
                           ' °³¼ö' + IntToStr(MouseItem.Dura) + ' ¾àÀç'
               else
                  line1 := line1 + 'ÖØÁ¿ : ' +  IntToStr(MouseItem.S.Weight) + ' ¾àÀç';
            end;
         43: //±¤¼®
            begin
               line1 := line1 + 'ÖØÁ¿ : ' +  IntToStr(MouseItem.S.Weight) + ' ¼øµµ'+ IntToStr(Round(MouseItem.Dura/1000));
            end;
         44: //ÁÖ¿Á
            begin
               if MouseItem.S.Shape = 1 then begin
                  if MouseItem.S.OverlapItem = 1 then
                     line1 := line1 + 'ÖØÁ¿ : ' +  IntToStr(MouseItem.Dura div 10) +
                              ' °³¼ö' + IntToStr(MouseItem.Dura)
                  else if MouseItem.S.OverlapItem = 2 then
                     line1 := line1 + 'ÖØÁ¿ : ' +  IntToStr(MouseItem.S.Weight * MouseItem.Dura) +
                              ' °³¼ö' + IntToStr(MouseItem.Dura)// + ' ÁÖ¿Á'
                  else
                     line1 := line1 + 'ÖØÁ¿ : ' +  IntToStr(MouseItem.S.Weight);// + ' ÁÖ¿Á';
               end
               else begin
                  line1 := line1 + 'ÖØÁ¿ : ' +  IntToStr(MouseItem.S.Weight);
               end;
            end;

         60,61:
            begin
               if MouseItem.S.Shape in [20,21] then begin
                  if MouseItem.S.Shape = 20 then begin
                     line2 := 'CtrlÅ°¸¦ ´©¸£°í ¼ö¸®ÇÒ ¹æ¾î±¸ ¼±ÅÃ';
                     line3 := '¼ö¸®°¡´É: °©¿Ê, Åõ±¸, ¿ä´ë, ½Å¹ß'
                  end
                  else if MouseItem.S.Shape = 21 then begin
                     line2 := 'CtrlÅ°¸¦ ´©¸£°í ¼ö¸®ÇÒ Àå½Å±¸ ¼±ÅÃ';
                     line3 := '¼ö¸®°¡´É: ¸ñ°ÉÀÌ, ¹ÝÁö, ÆÈÂî';
                  end;
               end
               else line2 := 'CtrlÅ°¸¦ ´©¸£°í °­È­ÇÒ ¾ÆÀÌÅÛ ¼±ÅÃ';

               case MouseItem.S.Shape of
                  1: begin
                        line1 := '¹«°Ô' + IntToStr(MouseItem.S.Weight) + ' ÆÄ±« Áõ°¡';
                        line3 := '°­È­°¡´É : ¹«±â, ¸ñ°ÉÀÌ, ¹ÝÁö, ÆÈÂî'
                     end;
                  2: begin
                        line1 := '¹«°Ô' + IntToStr(MouseItem.S.Weight) + ' ¸¶¹ý Áõ°¡';
                        line3 := '°­È­°¡´É : ¹«±â, ¸ñ°ÉÀÌ, ¹ÝÁö, ÆÈÂî'
                     end;
                  3: begin
                        line1 := '¹«°Ô' + IntToStr(MouseItem.S.Weight) + ' µµ·Â Áõ°¡';
                        line3 := '°­È­°¡´É : ¹«±â, ¸ñ°ÉÀÌ, ¹ÝÁö, ÆÈÂî'
                     end;
                  4: begin
                        line1 := '¹«°Ô' + IntToStr(MouseItem.S.Weight) + ' ¹æ¾î Áõ°¡';
                        line3 := '°­È­°¡´É:¹ÝÁö,ÆÈÂî,¿Ê,Åõ±¸,Çã¸®¶ì,½Å¹ß'
                     end;
                  5: begin
                        line1 := '¹«°Ô' + IntToStr(MouseItem.S.Weight) + ' ¸¶Ç× Áõ°¡';
                        line3 := '°­È­°¡´É:¹ÝÁö,ÆÈÂî,¿Ê,Åõ±¸,Çã¸®¶ì,½Å¹ß'
                     end;
                  6: begin
                        line1 := '¹«°Ô' + IntToStr(MouseItem.S.Weight) + ' ÃÖ´ë ³»±¸ Áõ°¡';
                        line3 := '°­È­°¡´É : ¸ðµç Àåºñ'
                     end;
                  7: begin
                        line1 := '¹«°Ô' + IntToStr(MouseItem.S.Weight) + ' Á¤È® Áõ°¡';
                        line3 := '°­È­°¡´É : ¸ñ°ÉÀÌ, ÆÈÂî, Åõ±¸, Çã¸®¶ì'
                     end;
                  8: begin
                        line1 := '¹«°Ô' + IntToStr(MouseItem.S.Weight) + ' ¹ÎÃ¸ Áõ°¡';
                        line3 := '°­È­°¡´É : ÆÈÂî, ¿Ê, Çã¸®¶ì, ½Å¹ß'
                     end;
                  9: begin
                        line1 := '¹«°Ô' + IntToStr(MouseItem.S.Weight) + ' °ø°Ý ¼Óµµ Áõ°¡';
                        line3 := '°­È­°¡´É : ¹«±â, ¸ñ°ÉÀÌ, ¹ÝÁö'
                     end;
                  10: begin
                        line1 := '¹«°Ô' + IntToStr(MouseItem.S.Weight) + ' µÐÈ­ Ãß°¡';
                        line3 := '°­È­°¡´É : ¹«±â, ¸ñ°ÉÀÌ, ¹ÝÁö'
                     end;
                  11: begin
                        line1 := '¹«°Ô' + IntToStr(MouseItem.S.Weight) + ' Áßµ¶ Ãß°¡';
                        line3 := '°­È­°¡´É : ¹«±â, ¸ñ°ÉÀÌ, ¹ÝÁö'
                     end;
                  12: begin
                        line1 := '¹«°Ô' + IntToStr(MouseItem.S.Weight) + ' ¸¶¹ýÀúÇ× Áõ°¡';
                        line3 := '°­È­°¡´É : ¸ñ°ÉÀÌ, ¿Ê, Åõ±¸'
                     end;
                  13: begin
                        line1 := '¹«°Ô' + IntToStr(MouseItem.S.Weight) + ' Áßµ¶ÀúÇ× Áõ°¡';
                        line3 := '°­È­°¡´É : ¿Ê, Åõ±¸, Çã¸®¶ì'
                     end;
               end;
            end;
         else begin
               line1 := line1 + 'ÖØÁ¿ : ' +  IntToStr(MouseItem.S.Weight);
            end;
      end;
      if MouseItem.S.Shape = 99 then begin
         if MouseItem.S.StdMode in [21,22,26,53] then begin
            line1 := line1 + 'ÖØÁ¿ : ' + IntToStr(MouseItem.S.Weight);
            line2 := '±â '+IntToStr(MouseItem.S.Undead);
         end;
      end;
   end;
end;

procedure TFrmDlg.DItemBagDirectPaint(Sender: TObject;
  dsurface: TDirectDrawSurface);
var
  iname, d0, d1, d2, d3: string;
  n: integer;
  useable: Boolean;
  d: TDirectDrawSurface;
  FColor: TColor;
  old: Integer;
  OldFontStyle: TFontStyles;
begin
  if Myself = nil then exit;
  with DItemBag do begin
    d := WLib.Images[FaceIndex];
    if d <> nil then
      dsurface.Draw(SurfaceX(Left), SurfaceY(Top), d.ClientRect, d, $ECFFFFFF, True);

    GetMouseItemInfo(iname, d0, d1, d2, d3, useable, False);

    with g_DXCanvas do begin
      FColor := TColor(RGB(250,250,250));
      TextOut(SurfaceX(Left + 145), SurfaceY(Top + 44), FColor, CMsg.GetMsg(1701));
      TextOut(SurfaceX(Left + 145), SurfaceY(Top + 44), FColor, CMsg.GetMsg(1701));

      FColor := $64C8F8;

      old := MainForm.Canvas.Font.Size;
      OldFontStyle := MainForm.Canvas.Font.Style;
      MainForm.Canvas.Font.Size := 10;
      MainForm.Canvas.Font.Style := [fsBold];
      TextOut(SurfaceX(Left + 220 - (TextWidth(GetGoldStr(MySelf.Gold)) div 2)),
        SurfaceY(Top + 425), FColor, GetGoldStr(MySelf.Gold));
      MainForm.Canvas.Font.Style := OldFontStyle;
      MainForm.Canvas.Font.Size := old;
    end;
  end;
end;

procedure TFrmDlg.DCloseBagDirectPaint(Sender: TObject;
  dsurface: TDirectDrawSurface);
var
   d: TDirectDrawSurface;
begin
   with DCloseBag do begin
      if DCloseBag.Downed then begin
         d := WLib.Images[FaceIndex];
         if d <> nil then
            dsurface.Draw (SurfaceX(Left), SurfaceY(Top), d.ClientRect, d, TRUE);
      end;
   end;
end;

procedure TFrmDlg.DCloseBagMouseMove(Sender: TObject; Shift: TShiftState; X,
  Y: Integer);
var
  lx, ly: integer;
  sx, sy: integer;
begin
  with DCloseBag do begin
    lx := LocalX(X - Left);
    ly := LocalY(Y - Top);
    sx := SurfaceX(Left) + DItemBag.SurfaceX(DItemBag.Left) + lx + 8;
    sy := SurfaceY(Top) + DItemBag.SurfaceX(DItemBag.Top) + ly + 6;
    DScreen.ShowHint(sx, sy, '¹Ø ±Õ', $393800, FALSE);
  end;
end;

procedure TFrmDlg.DCloseBagClick(Sender: TObject; X, Y: Integer);
begin
  DItemBag.Visible := FALSE;
end;

procedure TFrmDlg.DItemGridGridMouseMove(Sender: TObject; X, Y: Integer; ACol,
  ARow: Integer; Shift: TShiftState);
var
   idx: integer;
   temp: TClientItem;
   iname, d0, d1, d2, d3: string;
   useable: Boolean;
   hcolor: TColor;
begin
   DScreen.ClearHint;
   if ssRight in Shift then begin
      if ItemMoving then
         DItemGridGridSelect (self, X, Y, ACol, ARow, Shift);
   end else begin
      idx := ACol + ARow * DItemGrid.ColCount + 6{º§Æ®°ø°£};

      if idx in [6..MAXBAGITEM-1] then begin
         MouseItem := ItemArr[idx];
         GetMouseItemInfo(iname, d0, d1, d2, d3, useable, False);

         if iname <> '' then begin
            if useable then hcolor := clWhite
            else hcolor := clRed;
            with DItemGrid do
               DScreen.ShowHint (DItemBag.Left + X + 10,
                                 DItemBag.Top + Y + 10,
                                 iname + d0 + '\' + d1 + '\' + d2 + '\' + d3, hcolor, FALSE);
         end;
         MouseItem.S.Name := '';
      end else DScreen.ClearHint;
   end;
end;

procedure TFrmDlg.DItemGridGridSelect(Sender: TObject; X, Y: Integer; ACol, ARow: Integer;
  Shift: TShiftState);
var
   idx, mi, n: integer;
   temp: TClientItem;
   bCheck: Boolean;
begin
   bCheck := False;
   idx := ACol + ARow * DItemGrid.ColCount + 6{º§Æ®°ø°£};

   if (not ItemMoving) and (ItemArr[idx].S.Name <> '') then begin
      if ssRight in Shift then begin
         if (EatTime + 300 < GetTickCount) and (ItemArr[idx].S.StdMode < 4) then begin
            if (ItemArr[idx].S.StdMode = 3) and ( ItemArr[idx].S.Shape in [1,2,3,4,5,6,9,10,11]) then
            else begin
               FrmMain.EatItem (idx);
               Exit;
            end
         end;
      end;
   end;

   if idx in [6..MAXBAGITEM-1] then begin
      if not ItemMoving then begin
         if ItemArr[idx].S.Name <> '' then begin
            ItemMoving := TRUE;
            MovingItem.Index := idx;
            MovingItem.Item := ItemArr[idx];
            ItemArr[idx].S.Name := '';
            ItemClickSound (ItemArr[idx].S);
         end;
      end else begin
         //¾ÆÀÌÅÛ ÀÌµ¿Áß
         //ItemClickSound (MovingItem.Item.S.StdMode);
         mi := MovingItem.Index;
         if (DMakeItemDlg.Visible) or (DDealDlg.Visible) then begin  // 2004/02/23 ¾ÆÀÌÅÛ ±³È¯,Á¦Á¶½Ã º§Æ®Ã¢¿¡¼­ °¡¹æÃ¢À¸·Î ¾ÆÀÌÅÛÀ» ÀÌµ¿ ÇÒ ¼ö ¾øµµ·Ï ¼öÁ¤..
            if (mi >= 0) and (mi < 6) then begin
               CancelItemMoving;
               if DMakeItemDlg.Visible then DMessageDlg ('¾ÆÀÌÅÛ Á¦Á¶½Ã º§Æ®Ã¢¿¡¼­ °¡¹æÃ¢À¸·Î ¾ÆÀÌÅÛÀ» ÀÌµ¿ ÇÒ ¼ö ¾ø½À´Ï´Ù.', [mbOk])
               else if DDealDlg.Visible then DMessageDlg ('¾ÆÀÌÅÛ ±³È¯½Ã º§Æ®Ã¢¿¡¼­ °¡¹æÃ¢À¸·Î ¾ÆÀÌÅÛÀ» ÀÌµ¿ ÇÒ ¼ö ¾ø½À´Ï´Ù.', [mbOk]);
               Exit;
            end;
         end;
         if (mi = -97) or (mi = -98) then exit; //µ·...
         // 2003/03/15 ¾ÆÀÌÅÛ ÀÎº¥Åä¸® È®Àå
         if (mi < 0) and (mi >= -13) then begin  //-99: SellÃ¢¿¡¼­ °¡¹æÀ¸·Î....-9->-13
            //»óÅÂÃ¢¿¡¼­ °¡¹æÀ¸·Î
            WaitingUseItem := MovingItem;
            FrmMain.SendTakeOffItem (-(MovingItem.Index+1), MovingItem.Item.MakeIndex, MovingItem.Item.S.Name);
            MovingItem.Item.S.name := '';
            ItemMoving := FALSE;
         end else begin
            if (mi <= -20) and (mi > -30) then begin //±³È¯Ã¢¿¡¼­
               DealItemReturnBag (MovingItem.Item); //send only
               //2004/01/06 ¾ÆÀÌÅÛ °³¼ö Á¦ÇÑ ¶§¹®¿¡ ¹Ù²ñ --------
               if MovingItem.Item.S.OverlapItem > 0 then begin
                  MovingItem.Item.S.name := '';
                  ItemMoving := FALSE;
                  Exit;
               end;//--------------------------------------------
            end;
            if ItemArr[idx].S.Name <> '' then begin

              if ssCtrl in Shift then begin //####
                 if (MovingItem.Item.S.StdMode in [60,61]) and (Not ((MovingItem.Item.S.StdMode = 61) and (MovingItem.Item.S.Shape in [20,21])) ) then begin
                    if mrOk = DMessageDlg (ItemArr[idx].S.Name+'¿¡ '+MovingItem.Item.S.Name+'À» ¹Ù¸£½Ã°Ú½À´Ï±î?', [mbOk, mbCancel]) then bCheck := True
                    else begin
                       CancelItemMoving;
                       Exit;
                    end;
                 end
                 else bCheck := True;
              end;

               if bCheck then begin
//               if ssCtrl in Shift then begin
                  UpItemItem := ItemArr[idx];
                  FrmMain.UpGradeItem(ItemArr[idx].MakeIndex, MovingItem.Item.MakeIndex,
                                      ItemArr[idx].S.Name , MovingItem.Item.S.Name );
                  if AddItemBag(MovingItem.Item) then begin
                     MovingItem.Item.S.name := '';
                     ItemMoving := FALSE;
                  end;
               end
               else begin
                  if (ItemArr[idx].S.OverlapItem > 0) and (ItemArr[idx].S.Name = MovingItem.Item.S.Name) and
                      (not DMakeItemDlg.Visible) then begin

                     FrmMain.SendItemSumCount(ItemArr[idx].MakeIndex, MovingItem.Item.MakeIndex,
                                              ItemArr[idx].S.Name, MovingItem.Item.S.Name );

                     //2004/01/06 ¾ÆÀÌÅÛ °³¼ö Á¦ÇÑ ¶§¹®¿¡ ¹Ù²ñ -----------
                     if (mi > 0) and (mi < 100) then CancelItemMoving
                     else begin
                        MovingItem.Item.S.Name := '';
                        ItemMoving := FALSE;
                     end;//-----------------------------------------------
                  end
                  else begin
                     temp := ItemArr[idx];
                     ItemArr[idx] := MovingItem.Item;
                     MovingItem.Index := idx;
                     MovingItem.Item := temp
                  end;
               end;
            end else begin
               ItemArr[idx] := MovingItem.Item;
               MovingItem.Item.S.name := '';
               ItemMoving := FALSE;
            end;
         end;
      end;
   end;
   ArrangeItemBag;
end;

procedure TFrmDlg.DItemGridDblClick(Sender: TObject);
var
   idx, i, where: integer;
   keyvalue: TKeyBoardState;
   cu: TClientItem;
   TempSender: TObject;
begin
   idx := DItemGrid.Col + DItemGrid.Row * DItemGrid.ColCount + 6;
   if idx in [6..MAXBAGITEM-1] then begin
      if ItemArr[idx].S.Name <> '' then begin
         {FillChar(keyvalue, sizeof(TKeyboardState), #0);
         GetKeyboardState (keyvalue);
         if keyvalue[VK_CONTROL] = $80 then begin
            //½Ã¾à·ùÀÎ°æ¿ì º§Æ®Ã¢À¸·Î ¿Å±â°í, ±âÅ¸ÀÎ °æ¿ì ÀûÀýÇÑ ÀÚ¸® Ã£À½
            cu := ItemArr[idx];
            ItemArr[idx].S.Name := '';
            AddItemBag (cu);
         end else
            if (ItemArr[idx].S.StdMode <= 4) or (ItemArr[idx].S.StdMode = 31) then begin //»ç¿ëÇÒ ¼ö ÀÖ´Â ¾ÆÀÌÅÛ
               FrmMain.EatItem (idx);
            end; }
      end else begin
         if ItemMoving and (MovingItem.Item.S.Name <> '') then begin
            FillChar(keyvalue, sizeof(TKeyboardState), #0);
            GetKeyboardState (keyvalue);
            if keyvalue[VK_CONTROL] = $80 then begin
               //º§Æ®Ã¢À¸·Î ¿Å±è
               cu := MovingItem.Item;
               MovingItem.Item.S.Name := '';
               ItemMoving := FALSE;
               AddItemBag (cu);
            end else
               if (MovingItem.Index = idx) and
                  (MovingItem.Item.S.StdMode <= 4) or (ItemArr[idx].S.StdMode in [7,8,31])
               then begin
                  FrmMain.EatItem (-1);
               end
//´õºíÅ¬¸¯À¸·Î ¾ÆÀÌÅÛÂø¿ë 2006/03/22----------------------------------------
               else begin
                  where := GetTakeOnPosition (MovingItem.Item.S.StdMode);

                  if MovingItem.Index >= 0 then begin
                     case where of
                        U_DRESS: TempSender := DSWDress;
                        U_WEAPON: TempSender := DSWWEAPON;
                        U_NECKLACE: TempSender := DSWNecklace;
                        U_RIGHTHAND: TempSender := DSWLight;
                        U_HELMET: TempSender := DSWHelmet;
                        U_RINGL: begin
                           if UseItems[U_RINGR].S.Name = '' then TempSender := DSWRingR
                           else TempSender := DSWRingL;
                        end;
                        U_ARMRINGR: begin
                           if UseItems[U_ARMRINGR].S.Name = '' then TempSender := DSWArmRingR
                           else TempSender := DSWArmRingL;
                        end;
                        U_BUJUK: begin
                           if MovingItem.Item.S.Shape = 5 then TempSender := DSWBujuk
                           else TempSender := DSWArmRingL
                        end;
                        U_BELT: TempSender := DSWBelt;
                        U_BOOTS: TempSender := DSWBoots;
                        U_CHARM: TempSender := DSWCharm;
                     end;
                  end;
                  DSWWeaponClick(TempSender, 1, 1);
               end;
//------------------------------------------------------------------------------
         end;
      end;
   end;
end;

procedure  TFrmDlg.UpgradeItemEffect(wResult : word);
begin
   UpItemOffset := UPITEMSUCCESSOFFSET;
   UpItemMaxFrame := 8;

   BoUpItemEffect := TRUE;
   CurUpItemEffect := 0;
end;
procedure TFrmDlg.DItemGridGridPaint(Sender: TObject; ACol, ARow: Integer;
  Rect: TRect; State: TGridDrawState; dsurface: TDirectDrawSurface);
var
   d: TDirectDrawSurface;
   idx, ax, ay : integer;   
begin
   idx := ACol + ARow * DItemGrid.ColCount + 6;
   if idx in [6..MAXBAGITEM-1] then begin
      if ItemArr[idx].S.Name <> '' then begin
         d := g_WStoreItem.Images[ItemArr[idx].S.Looks];
         if (ItemArr[idx].S.OverlapItem < 1) or
            ((ItemArr[idx].S.OverlapItem > 0) and (ItemArr[idx].Dura > 0)) then begin
            if d <> nil then
               with DItemGrid do
                  dsurface.Draw (SurfaceX(Rect.Left + (ColWidth - d.Width) div 2 - 1),
                                 SurfaceY(Rect.Top + (RowHeight - d.Height) div 2 + 1),
                                 d.ClientRect,
                                 d, TRUE);

            // ¾ÆÀÌÅÛ °ãÄ¡±â
            if ItemArr[idx].S.OverlapItem > 0 then begin
//               SetBkMode (dsurface.Canvas.Handle, TRANSPARENT);
//               dsurface.Canvas.Font.Color := clYellow;

               g_DXCanvas.TextOut (DItemGrid.SurfaceX(Rect.Left +20), DItemGrid.SurfaceY(Rect.Top +20), clYellow,
                                        IntToStr(ItemArr[idx].Dura));
//               dsurface.Canvas.Release;
            end;
         end;

      end;
   end;

   if BoUpItemEffect then begin  // ¾ÆÀÌÅÛ ¾÷±×·¹ÀÌµå È¿°ú
      if GetTickCount - upeffecttime > 120 then begin
         upeffecttime := GetTickCount;
         Inc (CurUpItemEffect);
         if CurUpItemEffect >= UpItemMaxFrame then begin
            FrmMain.DelitemProg;
            BoUpItemEffect := FALSE;
            UpItemItem.S.Name := '';
         end;
      end;
   end;

   if BoUpItemEffect then begin

      d := g_WMagicEx[1].GetCachedImage (UpItemOffset + CurUpItemEffect, ax, ay);

      if d <> nil then
         if idx in [6..MAXBAGITEM-1] then
            if (UpItemItem.MakeIndex = ItemArr[idx].MakeIndex) and
               (Trim(UpItemItem.S.Name) = Trim(ItemArr[idx].S.Name))  then
               DrawBlend (dsurface,
                           DItemGrid.SurfaceX(Rect.Left) -9 + ax,
                           DItemGrid.SurfaceY(Rect.Top) +41 + ay,
                           d, 1);
   end;
end;

procedure TFrmDlg.DGoldClick(Sender: TObject; X, Y: Integer);
begin
   if Myself = nil then exit;
   if not ItemMoving then begin
      if Myself.Gold > 0 then begin
         PlaySound (s_money);
         ItemMoving := TRUE;
         MovingItem.Index := -98; //µ·
         MovingItem.Item.S.Name := '½ð±Ò';
      end;
   end else begin
      if (MovingItem.Index = -97) or (MovingItem.Index = -98) then begin //µ·¸¸..
         ItemMoving := FALSE;
         MovingItem.Item.S.Name := '';
         if MovingItem.Index = -97 then begin //±³È¯Ã¢¿¡¼­ ¿Å
            DealZeroGold;
         end;
      end;
   end;
   ;
end;






{------------------------------------------------------------------------}

//»óÀÎ ´ëÈ­ Ã¢

{------------------------------------------------------------------------}


procedure TFrmDlg.ShowMDlg (face: integer; mname, msgstr: string);
var
   i: integer;
begin
   DMerchantDlg.Left := 0;  //±âº» À§Ä¡
   DMerchantDlg.Top := 0;
   MerchantFace := face;
   MerchantName := mname;
   MDlgStr := msgstr;
   DMerchantDlg.Visible := TRUE;
   DItemBag.Left := 456;  //°¡¹æÀ§Ä¡ º¯°æ
   DItemBag.Top := 0;
   for i:=0 to MDlgPoints.Count-1 do
      Dispose (PTClickPoint (MDlgPoints[i]));
   MDlgPoints.Clear;
   RequireAddPoints := TRUE;
   LastestClickTime := GetTickCount;
end;


procedure TFrmDlg.ResetMenuDlg;
var
   i: integer;
begin
   CloseDSellDlg;
   for i:=0 to MenuItemList.Count-1 do  //¼¼ºÎ ¸Þ´ºµµ Å¬¸®¾î ÇÔ.
      Dispose(PTClientItem(MenuItemList[i]));
   MenuItemList.Clear;

   for i:=0 to MenuList.Count-1 do
      Dispose (PTClientGoods(MenuList[i]));
   MenuList.Clear;

   for i:=0 to JangwonList.Count-1 do
      Dispose (PTClientJangwon(JangwonList[i]));
   JangwonList.Clear;

   for i:=0 to GABoardList.Count-1 do
      Dispose (PTClientGABoard(GABoardList[i]));
   GABoardList.Clear;

   //CurDetailItem := '';
   MenuIndex := -1;
   MenuTopLine := 0;
   BoDetailMenu := FALSE;
   BoStorageMenu := FALSE;
   BoMakeDrugMenu := FALSE;
   BoMakeItemMenu := FALSE;
   NameMakeItem := '';

   DSellDlg.Visible := FALSE;
   DMenuDlg.Visible := FALSE;
end;

procedure TFrmDlg.ShowShopMenuDlg;
begin
   MenuIndex := -1;

   DMerchantDlg.Left := 0;  //±âº» À§Ä¡
   DMerchantDlg.Top := 0;
   DMerchantDlg.Visible := TRUE;

   DSellDlg.Visible := FALSE;

   DMenuDlg.Left := 0;
   DMenuDlg.Top  := 208;
   DMenuDlg.Visible := TRUE;
   MenuTop := 0;

   DItemBag.Left := 456;
   DItemBag.Top := 0;
   DItemBag.Visible := TRUE;

   LastestClickTime := GetTickCount;
end;

procedure TFrmDlg.ShowItemMarketDlg; //2004/01/15 ItemMarket..
var
   i: integer;
begin

   DSellDlg.Visible := FALSE;
   BoInRect := False;

   if Not DItemBag.Visible then begin
      DItemBag.Left := 456;
      DItemBag.Top := 0;
      DItemBag.Visible := TRUE;
   end;
   if Not DItemMarketDlg.Visible then begin
      DItemMarketDlg.Left := 0;//10;
      DItemMarketDlg.Top  := 90;//20;
      DItemMarketDlg.Visible := TRUE;
   end;

   if g_Market.GetFirst = 1 then begin
      MenuTop := 0;
      MenuIndex := -1;
   end;

//   HideAllControls;
//   DItemMarketDlg.ShowModal;
   DItemMarketDlg.Show;

   with ItemSearchEdit do begin
      Text  := '';
      Width := 132;
      Left  := DItemMarketDlg.Left+39;
      Top   := DItemMarketDlg.Top +355;
   end;

   if g_Market.GetUserMode = 1 then begin
      DItemBuy.Visible := True;
      DItemSellCancel.Visible := False;
      DItemFind.Visible := True;
      DItemMarketDlg.MouseFocus := True;
      ItemSearchEdit.Visible := TRUE;
      ItemSearchEdit.SetFocus;
      DlgEditText := ItemSearchEdit.Text;
   end else if g_Market.GetUserMode = 2 then begin
      DItemBuy.Visible := False;
      DItemSellCancel.Visible := True;
      DItemFind.Visible := False;
      ItemSearchEdit.Visible := False;
   end;
   DItemCancel.Visible := True;

   SetImeMode (PlayScene.EdChat.Handle, imSHanguel);//@@@@
//   RestoreHideControls;
   if PlayScene.EdChat.Visible then PlayScene.EdChat.SetFocus;

   LastestClickTime := GetTickCount;

end;

procedure TFrmDlg.ShowJangwonDlg; //2004/01/15 ItemMarket..
var
   i: integer;
begin

   BoMemoJangwon := False;
   DSellDlg.Visible := FALSE;

   if Not DJangwonListDlg.Visible then begin
      DJangwonListDlg.Left := 0;//10;
      DJangwonListDlg.Top  := 175;//20;
      DJangwonListDlg.Visible := TRUE;
   end;

   MenuIndex := -1;
   DJangwonListDlg.Show;
   LastestClickTime := GetTickCount;

end;

procedure TFrmDlg.ShowGADecorateDlg; //2004/06/18 Àå¿ø ²Ù¹Ì±â
var
   i: integer;
begin

   if Not DItemBag.Visible then begin
      DItemBag.Left := 456;
      DItemBag.Top := 0;
//      DItemBag.Visible := TRUE;
   end;
   if Not DGADecorateDlg.Visible then begin
      DGADecorateDlg.Left := 0;//10;
      DGADecorateDlg.Top  := 20;//90;//20;
      DGADecorateDlg.Visible := TRUE;
   end;

   MenuTop := 0;
   MenuIndex := 0;

   DGADecorateDlg.Show;
   LastestClickTime := GetTickCount;

end;

procedure TFrmDlg.ShowGABoardListDlg;
var
   i: integer;
begin

//   BoMemoJangwon := False;
   DSellDlg.Visible := FALSE;
   GABoard_BoWrite  := 0;
   GABoard_BoNotice := 1;

   if Not DGABoardListDlg.Visible then begin
      DGABoardListDlg.Left := 0;//10;
      DGABoardListDlg.Top  := 48;//20;
      DGABoardListDlg.Visible := TRUE;
   end;

   MenuIndex := -1;
   DGABoardListDlg.Show;
   LastestClickTime := GetTickCount;

end;

procedure TFrmDlg.ShowGABoardReadDlg;
var
   d: TDirectDrawSurface;
   i: integer;
   data: String;
begin
   with DGABoardDlg do begin
      d := WLib.Images[FaceIndex];
      if d <> nil then begin
         Left := 230;
         Top  := 145;
      end;

      DGABoardDlg.ShowModal;
      if (GABoard_BoReply = 1) or (GABoard_BoWrite = 1) then begin
         DGABoardReply.Visible := False;
         DGABoardDel.Visible   := False;
         DGABoardMemo.Visible  := False;
      end
      else begin
         DGABoardReply.Visible := True;
         DGABoardDel.Visible   := True;
         DGABoardMemo.Visible  := True;
      end;
      DGABoardOk2.Visible := True;

      if Memo.ReadOnly then begin
         DGABoardDel.Visible   := False;
      end;

      Memo.Left := SurfaceX(Left+28);
      Memo.Top  := SurfaceY(Top+62);
      Memo.Width := d.Width-58;
      Memo.Height := 142;
      Memo.Lines.Assign (GABoard_Notice);
      Memo.Visible := TRUE;
   end;

end;

procedure TFrmDlg.CloseItemMarketDlg;
begin
    DItemMarketCloseClick(DItemMarketClose, 0, 0);
end;

procedure TFrmDlg.ShowShopSellDlg;
begin
   SellStHold := False;
   DSellDlg.Left := 252;
   DSellDlg.Top := 208;
   DSellDlg.Visible := TRUE;

   DMenuDlg.Visible := FALSE;

   DItemBag.Left := 456;
   DItemBag.Top := 0;
   DItemBag.Visible := TRUE;

   LastestClickTime := GetTickCount;
   SellPriceStr := '';
end;

procedure TFrmDlg.CloseMDlg;
var
   i: integer;
begin
   MDlgStr := '';
   DMerchantDlg.Visible := FALSE;
   for i:=0 to MDlgPoints.Count-1 do
      Dispose (PTClickPoint (MDlgPoints[i]));
   MDlgPoints.Clear;
   //¸Þ´ºÃ¢µµ ´ÝÀ½
//   DItemBag.Left := 0;  //@@@@
//   DItemBag.Top := 0;
   DMenuDlg.Visible := FALSE;
   CloseDSellDlg;
end;

procedure TFrmDlg.CloseMDlg2;
var
   i: integer;
begin
   MDlgStr := '';
   DMerchantDlg.Visible := FALSE;
   for i:=0 to MDlgPoints.Count-1 do
      Dispose (PTClickPoint (MDlgPoints[i]));
   MDlgPoints.Clear;

   DMenuDlg.Visible := FALSE;
   CloseDSellDlg;
end;

procedure TFrmDlg.CloseDSellDlg;
begin
   DSellDlg.Visible := FALSE;
   if SellDlgItem.S.Name <> '' then
      AddItemBag (SellDlgItem);
   SellDlgItem.S.Name := '';
end;

//»óÀÎ ´ëÈ­Ã¢

procedure TFrmDlg.DMerchantDlgDirectPaint(Sender: TObject;
  dsurface: TDirectDrawSurface);
var
   d: TDirectDrawSurface;
   str, data, fdata, cmdstr, cmdmsg, cmdparam: string;
   lx, ly, sx: integer;
   drawcenter: Boolean;
   pcp: PTClickPoint;
begin
   with Sender as TDWindow do begin
      d := WLib.Images[FaceIndex];
      if d <> nil then
         dsurface.Draw (SurfaceX(Left), SurfaceY(Top), d.ClientRect, d, TRUE);
      //SetBkMode (g_DXCanvas.Handle, TRANSPARENT); //ÉèÖÃÍ¸Ã÷
      lx := 15;
      ly := 37;
      str := MDlgStr;
      drawcenter := FALSE;
      while TRUE do begin
         if str = '' then break;
         str := GetValidStr3 (str, data, [char($a)]);
         if data <> '' then begin
            sx := 0;
            fdata := '';
            while (pos('<', data) > 0) and (pos('>', data) > 0) and (data <> '') do begin
               if data[1] <> '<' then begin
                  data := '<' + GetValidStr3 (data, fdata, ['<']);
               end;
               data := ArrestStringEx (data, '<', '>', cmdstr);

               //fdata + cmdstr + data
               if cmdstr <> '' then begin
                  if Uppercase(cmdstr) = 'C' then begin
                     drawcenter := TRUE;
                     continue;
                  end;
                  if UpperCase(cmdstr) = '/C' then begin
                     drawcenter := FALSE;
                     continue;
                  end;
                  cmdparam := GetValidStr3 (cmdstr, cmdstr, ['/']); //cmdparam : ÃüÁî²ÎÊý
               end else begin
                  DMenuDlg.Visible := FALSE;
                  DSellDlg.Visible := FALSE;
               end;

               if fdata <> '' then begin
                  g_DXCanvas.BoldTextOut ( SurfaceX(Left+lx+sx), SurfaceY(Top+ly), clWhite, {clBlack,} fdata);
                  sx := sx + g_DXCanvas.TextWidth(fdata);
               end;
               if cmdstr <> '' then begin
                  if RequireAddPoints then begin //ÇÑ¹ø¸¸...
                     new (pcp);
                     pcp.rc := Rect (lx+sx, ly, lx+sx + g_DXCanvas.TextWidth(cmdstr), ly + 14);
                     pcp.RStr := cmdparam;
                     MDlgPoints.Add (pcp);
                  end;
                  if SelectMenuStr = cmdparam then begin
                     g_DXCanvas.BoldTextOut( SurfaceX(Left+lx+sx), SurfaceY(Top+ly), clRed,  cmdstr);
                     g_DXCanvas.MoveTo(SurfaceX(Left+lx+sx), SurfaceY(Top+ly) + g_DXCanvas.TextHeight(cmdstr) + 2);
                     g_DXCanvas.LineTo(SurfaceX(Left+lx+sx)+ g_DXCanvas.TextWidth(cmdstr) - 1, SurfaceY(Top+ly) + g_DXCanvas.TextHeight(cmdstr) + 2, clRed);
                 end
                 else begin
                     g_DXCanvas.BoldTextOut ( SurfaceX(Left+lx+sx), SurfaceY(Top+ly), clYellow,  cmdstr);
                     g_DXCanvas.MoveTo(SurfaceX(Left+lx+sx), SurfaceY(Top+ly) + g_DXCanvas.TextHeight(cmdstr) + 2);
                     g_DXCanvas.LineTo(SurfaceX(Left+lx+sx)+ g_DXCanvas.TextWidth(cmdstr) - 1, SurfaceY(Top+ly) + g_DXCanvas.TextHeight(cmdstr) + 2, clYellow);
                 end;

                  sx := sx + g_DXCanvas.TextWidth(cmdstr);
//                  g_DXCanvas.Font.Style := g_DXCanvas.Font.Style - [fsUnderline];
               end;
            end;
            if data <> '' then
               g_DXCanvas.BoldTextOut ( SurfaceX(Left+lx+sx), SurfaceY(Top+ly), clWhite, {clBlack,} data);
         end;
         ly := ly + 16;
      end;
      RequireAddPoints := FALSE;
   end;
end;

procedure TFrmDlg.DMerchantDlgCloseClick(Sender: TObject; X, Y: Integer);
begin
   CloseMDlg;
end;

procedure TFrmDlg.DMenuDlgDirectPaint(Sender: TObject;
  dsurface: TDirectDrawSurface);
  function SX(x: integer): integer;
  begin
      Result := DMenuDlg.SurfaceX (DMenuDlg.Left + x);
  end;
  function SY(y: integer): integer;
  begin
      Result := DMenuDlg.SurfaceY (DMenuDlg.Top + y);
  end;
var
   i, lh, k, m, menuline: integer;
   d: TDirectDrawSurface;
   pg: PTClientGoods;
   str: string;
   FColor: TColor;
begin
   with g_DXCanvas do begin
      with DMenuDlg do begin
         d := DMenuDlg.WLib.Images[FaceIndex];
         if d <> nil then
            dsurface.Draw (SurfaceX(Left), SurfaceY(Top), d.ClientRect, d, TRUE);
      end;

//      SetBkMode (dsurface.Canvas.Handle, TRANSPARENT);
//      SetBkMode (Handle, TRANSPARENT);
      //title
      FColor := clWhite;
      if not BoStorageMenu then begin
         TextOut (SX(36),  SY(30), FColor, '»óÇ° ¸ñ·Ï');
         TextOut (SX(175), SY(30), FColor, '°¡°Ý');
         if not BoMakeItemMenu then
            TextOut (SX(263), SY(30), FColor, '³»±¸');
         lh := LISTLINEHEIGHT;
         menuline := _MIN(MAXMENU, MenuList.Count-MenuTop);
         //»óÇ° ¸®½ºÆ®
         for i:=MenuTop to MenuTop+menuline-1 do begin
            m := i-MenuTop;
            if i = MenuIndex then begin
               FColor := clRed;
               TextOut (SX(29),  SY(51 + m*lh), FColor, char(7));
            end else FColor := clWhite;
            pg := PTClientGoods (MenuList[i]);
            TextOut (SX(36),  SY(51 + m*lh), FColor, pg.Name);
            if (pg.SubMenu >= 1) and (pg.SubMenu <> 2) then
               TextOut (SX(137), SY(51 + m*lh), FColor, #31);
            TextOut (SX(175), SY(51 + m*lh), FColor, IntToStr(pg.Price) + 'Àü');
            str := '';
            if pg.Grade = -1 then str := '-'
            else TextOut (SX(263), SY(51 + m*lh), FColor, IntToStr(pg.Grade));
            {else for k:=0 to pg.Grade-1 do
               str := str + '*';
            if Length(str) >= 4 then begin
               Font.Color := clYellow;
               TextOut (SX(245), SY(32 + m*lh), str);
            end else
               TextOut (SX(245), SY(32 + m*lh), str);}
         end;
      end else begin
         TextOut (SX(36),  SY(30), FColor, 'º¸°ü ¸ñ·Ï');
         TextOut (SX(175), SY(30), FColor, '³»±¸');
         TextOut (SX(263), SY(30), FColor, '');
         lh := LISTLINEHEIGHT;
         menuline := _MIN(MAXMENU, MenuList.Count-MenuTop);
         //»óÇ° ¸®½ºÆ®
         for i:=MenuTop to MenuTop+menuline-1 do begin
            m := i-MenuTop;
            if i = MenuIndex then begin
               FColor := clRed;
               TextOut (SX(29),  SY(51 + m*lh), FColor, char(7));
            end else FColor := clWhite;
            pg := PTClientGoods (MenuList[i]);
            TextOut (SX(36),  SY(51 + m*lh), FColor, pg.Name);
            if (pg.SubMenu >= 1) and (pg.SubMenu <> 2) then
               TextOut (SX(175), SY(51 + m*lh), FColor, #31);
            TextOut (SX(263), SY(51 + m*lh), FColor, IntToStr(pg.Stock) + '/' + IntToStr(pg.Grade));
         end;
      end;
      //TextOut (0, 0, IntToStr(MenuTopLine));

//      Release;
   end;
end;

{
procedure TFrmDlg.DMenuDlgDirectPaint(Sender: TObject;
  dsurface: TDirectDrawSurface);
  function SX(x: integer): integer;
  begin
      Result := DMenuDlg.SurfaceX (DMenuDlg.Left + x);
  end;
  function SY(y: integer): integer;
  begin
      Result := DMenuDlg.SurfaceY (DMenuDlg.Top + y);
  end;
var
   i, lh, k, m, menuline: integer;
   d: TDirectDrawSurface;
   pg: PTClientGoods;
   str: string;
begin
   with dsurface.Canvas do begin
      with DMenuDlg do begin
         d := DMenuDlg.WLib.Images[FaceIndex];
         if d <> nil then
            dsurface.Draw (SurfaceX(Left), SurfaceY(Top), d.ClientRect, d, TRUE);
      end;

      SetBkMode (dsurface.Canvas.Handle, TRANSPARENT);
      SetBkMode (Handle, TRANSPARENT);
      //title
      Font.Color := clWhite;
      if not BoStorageMenu then begin
         TextOut (SX(19),  SY(11), '»óÇ° ¸ñ·Ï');
         TextOut (SX(156), SY(11), '°¡°Ý');
         if not BoMakeItemMenu then
            TextOut (SX(245), SY(11), '³»±¸');
         lh := LISTLINEHEIGHT;
         menuline := _MIN(MAXMENU, MenuList.Count-MenuTop);
         //»óÇ° ¸®½ºÆ®
         for i:=MenuTop to MenuTop+menuline-1 do begin
            m := i-MenuTop;
            if i = MenuIndex then begin
               Font.Color := clRed;
               TextOut (SX(12),  SY(32 + m*lh), char(7));
            end else Font.Color := clWhite;
            pg := PTClientGoods (MenuList[i]);
            TextOut (SX(19),  SY(32 + m*lh), pg.Name);
            if (pg.SubMenu >= 1) and (pg.SubMenu <> 2) then
               TextOut (SX(137), SY(32 + m*lh), #31);
            TextOut (SX(156), SY(32 + m*lh), IntToStr(pg.Price) + 'Àü');
            str := '';
            if pg.Grade = -1 then str := '-'
            else TextOut (SX(245), SY(32 + m*lh), IntToStr(pg.Grade));
         end;
      end else begin
         TextOut (SX(19),  SY(11), 'º¸°ü ¸ñ·Ï');
         TextOut (SX(156), SY(11), '³»±¸');
         TextOut (SX(245), SY(11), '');
         lh := LISTLINEHEIGHT;
         menuline := _MIN(MAXMENU, MenuList.Count-MenuTop);
         //»óÇ° ¸®½ºÆ®
         for i:=MenuTop to MenuTop+menuline-1 do begin
            m := i-MenuTop;
            if i = MenuIndex then begin
               Font.Color := clRed;
               TextOut (SX(12),  SY(32 + m*lh), char(7));
            end else Font.Color := clWhite;
            pg := PTClientGoods (MenuList[i]);
            TextOut (SX(19),  SY(32 + m*lh), pg.Name);
            if (pg.SubMenu >= 1) and (pg.SubMenu <> 2) then
               TextOut (SX(137), SY(32 + m*lh), #31);
            TextOut (SX(156), SY(32 + m*lh), IntToStr(pg.Stock) + '/' + IntToStr(pg.Grade));
         end;
      end;
      //TextOut (0, 0, IntToStr(MenuTopLine));

      Release;
   end;
end;}

procedure TFrmDlg.DMenuDlgClick(Sender: TObject; X, Y: Integer);
var
   lx, ly, idx: integer;
   iname, d1, d2, d3, d4: string;
   useable: Boolean;
begin
   DScreen.ClearHint;
   lx := DMenuDlg.LocalX (X) - DMenuDlg.Left;
   ly := DMenuDlg.LocalY (Y) - DMenuDlg.Top;
   if (lx >= 28) and (lx <= 299) and (ly >= 51) then begin
      idx := (ly-51) div LISTLINEHEIGHT + MenuTop;
      if idx < MenuList.Count then begin
         PlaySound (s_glass_button_click);
         MenuIndex := idx;
         if DMakeItemDlg.Visible then
            DMakeItemDlgOkClick(DMakeItemDlgCancel, 0, 0);
      end;
   end;

   if BoStorageMenu then begin
      if (MenuIndex >= 0) and (MenuIndex < SaveItemList.Count) then begin
         MouseItem := PTClientItem(SaveItemList[MenuIndex])^;
         GetMouseItemInfo (iname, d1, d2, d3, d4, useable, FALSE);
         if iname <> '' then begin
            lx := 256;
            ly := 51+(MenuIndex-MenuTop) * LISTLINEHEIGHT;
            with Sender as TDButton do
               DScreen.ShowHint (DMenuDlg.SurfaceX(Left + lx),
                                 DMenuDlg.SurfaceY(Top + ly),
                                 iname + d1 + '\' + d2 + '\' + d3 + d4, clYellow, FALSE);
         end;
         MouseItem.S.Name := '';
      end;
   end else begin
      if (MenuIndex >= 0) and (MenuIndex < MenuItemList.Count) and
         ((PTClientGoods (MenuList[MenuIndex]).SubMenu = 0) or (PTClientGoods (MenuList[MenuIndex]).SubMenu = 2)) then begin
         MouseItem := PTClientItem(MenuItemList[MenuIndex])^;
         BoNoDisplayMaxDura := TRUE;
         GetMouseItemInfo (iname, d1, d2, d3, d4, useable, FALSE);
         BoNoDisplayMaxDura := FALSE;
         if iname <> '' then begin
            lx := 256;
            ly := 51+(MenuIndex-MenuTop) * LISTLINEHEIGHT;
            with Sender as TDButton do
               DScreen.ShowHint (DMenuDlg.SurfaceX(Left + lx),
                                 DMenuDlg.SurfaceY(Top + ly),
                                 iname + d1 + '\' + d2 + '\' + d3 + d4, clYellow, FALSE);
         end;
         MouseItem.S.Name := '';
      end;
   end;
end;

procedure TFrmDlg.DMenuDlgMouseMove(Sender: TObject; Shift: TShiftState; X,
  Y: Integer);
begin
   with DMenuDlg do
      if (X < SurfaceX(Left+10)) or (X > SurfaceX(Left+Width-20)) or (Y < SurfaceY(Top+30)) or (Y > SurfaceY(Top+Height-50)) then begin
         DScreen.ClearHint;
      end;
end;

procedure TFrmDlg.DMenuBuyClick(Sender: TObject; X, Y: Integer);
var
   pg: PTClientGoods;
   MsgResult, Count : integer;
   valstr : String;
begin
   Count := 0;
   if GetTickCount < LastestClickTime then exit; //Å¬¸¯À» ÀÚÁÖ ¸øÇÏ°Ô Á¦ÇÑ
   if (MenuIndex >= 0) and (MenuIndex < MenuList.Count) then begin
      pg := PTClientGoods (MenuList[MenuIndex]);
      LastestClickTime := GetTickCount + 5000;
      if (pg.SubMenu > 0) and (pg.SubMenu <> 2) then begin
         FrmMain.SendGetDetailItem (CurMerchant, 0, pg.Name);
         MenuTopLine := 0;
         CurDetailItem := pg.Name;
      end else begin
         if BoStorageMenu then begin
            try
               MouseItem := PTClientItem(SaveItemList[MenuIndex])^;
            except
            end;
            if MouseItem.S.OverlapItem > 0 then begin
               Total := MouseItem.Dura;
               if Total = 1 then begin
                  DlgEditText := '1';
                  MsgResult := mrOk;
               end
               else MsgResult := DCountMsgDlg ('ÃÑ '+IntToStr(MouseItem.Dura) +'°³Áß ¸î°³¸¦ Ã£°Ú½À´Ï±î?', [mbAbort]);
               GetValidStrVal (DlgEditText, valstr, [' ']);
               Count := Str_ToInt (valstr, 0);

               if Count > MouseItem.Dura then Count := MouseItem.Dura;
               if (MsgResult = mrCancel) or (Count <= 0 ) then begin// or (Count < 1) or(Count > MAX_OVERLAPITEM ) then begin
                  Count := 0;
                  Exit;
               end;
               FrmMain.SendTakeBackStorageItem (CurMerchant, pg.Price{MakeIndex}, pg.Name, word(Count));
            end
            else FrmMain.SendTakeBackStorageItem (CurMerchant, pg.Price{MakeIndex}, pg.Name, word(Count));
            exit;
         end;
         if BoMakeItemMenu then begin
            NameMakeItem := pg.Name;
            FrmMain.SendMakeItemSel (CurMerchant, pg.Name);
            MakeItemDlgShow('');
            exit;
         end;
         if BoMakeDrugMenu then begin
            FrmMain.SendMakeDrugItem (CurMerchant, pg.Name);
            exit;
         end;

         if pg.SubMenu = 2 then begin // pg.SubMenu = 2 ÀÌ¸é °ãÄ¡±â ¾ÆÀÌÅÛ..
            Total := 100;
            MsgResult := DCountMsgDlg ('¸î°³¸¦ »ç½Ã°Ú½À´Ï±î?', [mbOk, mbCancel, mbAbort]);
            GetValidStrVal (DlgEditText, valstr, [' ']);
            Count := Str_ToInt (valstr, 0);
            if (MsgResult = mrCancel) or (Count <= 0) or(Count > MAX_OVERLAPITEM ) then begin
               Exit;
            end;
         end;
         FrmMain.SendBuyItem (CurMerchant, pg.Stock, pg.Name, word(Count));
      end;
   end;
end;

procedure TFrmDlg.DMenuPrevClick(Sender: TObject; X, Y: Integer);
begin
   if not BoDetailMenu then begin
      if MenuTop > 0 then Dec (MenuTop, MAXMENU-1);
      if MenuTop < 0 then MenuTop := 0;
   end else begin
      if MenuTopLine > 0 then begin
         MenuTopLine := _MAX(0, MenuTopLine-10);
         FrmMain.SendGetDetailItem (CurMerchant, MenuTopLine, CurDetailItem);
      end;
   end;
end;

procedure TFrmDlg.DMenuNextClick(Sender: TObject; X, Y: Integer);
begin
   if not BoDetailMenu then begin
      if MenuTop + MAXMENU < MenuList.Count then Inc (MenuTop, MAXMENU-1);
   end else begin
      MenuTopLine := MenuTopLine + 10;
      FrmMain.SendGetDetailItem (CurMerchant, MenuTopLine, CurDetailItem);
   end;      
end;

procedure TFrmDlg.SoldOutGoods (itemserverindex: integer);
var
   i: integer;
   pg: PTClientGoods;
begin
   for i:=0 to MenuList.Count-1 do begin
      pg := PTClientGoods (MenuList[i]);
      if (pg.Grade >= 0) and (pg.Stock = itemserverindex) then begin
         Dispose (pg);
         MenuList.Delete (i);
         if i < MenuItemList.Count then MenuItemList.Delete (i);
         if MenuIndex > MenuList.Count-1 then MenuIndex := MenuList.Count-1;
         break;
      end;
   end;
end;

procedure TFrmDlg.DelStorageItem (itemserverindex: integer; remain: word);
var
   i: integer;
   pg: PTClientGoods;
begin
   for i:=0 to MenuList.Count-1 do begin
      pg := PTClientGoods (MenuList[i]);
      if (pg.Price = itemserverindex) then begin //º¸°ü¸ñ·ÏÀÎ°æ¿î Price = ItemServerIndexÀÓ.
         if (remain > 0) and (PTClientItem(SaveItemList[i])^.S.OverlapItem > 0 ) then begin
            PTClientItem(SaveItemList[i])^.Dura := remain;
            Exit;
         end;
         Dispose (pg);
         MenuList.Delete (i);
         if i < SaveItemList.Count then SaveItemList.Delete (i);
         if MenuIndex > MenuList.Count-1 then MenuIndex := MenuList.Count-1;
         break;
      end;
   end;
end;

procedure TFrmDlg.DMenuCloseClick(Sender: TObject; X, Y: Integer);
begin
   DMenuDlg.Visible := FALSE;
end;

procedure TFrmDlg.DMerchantDlgClick(Sender: TObject; X, Y: Integer);
var
   i, L, T: integer;
   p: PTClickPoint;
begin
   if GetTickCount < LastestClickTime then exit; //Å¬¸¯À» ÀÚÁÖ ¸øÇÏ°Ô Á¦ÇÑ
   L := DMerchantDlg.Left;
   T := DMerchantDlg.Top;
   with DMerchantDlg do
      for i:=0 to MDlgPoints.Count-1 do begin
         p := PTClickPoint (MDlgPoints[i]);
         if (X >= SurfaceX(L + p.rc.Left)) and (X <= SurfaceX(L + p.rc.Right)) and
            (Y >= SurfaceY(T + p.rc.Top)) and (Y <= SurfaceY(T + p.rc.Bottom)) then begin
            PlaySound (s_glass_button_click);
            if DMakeItemDlg.Visible then DMakeItemDlgOkClick(DMakeItemDlgCancel, 0, 0);
            if DSellDlg.Visible then CloseDSellDlg;
            SafeCloseDlg;
{            if DItemMarketDlg.Visible then CloseItemMarketDlg;
            if DJangwonListDlg.Visible then DJangwonCloseClick(DJangwonClose, 0, 0);
            if DGABoardListDlg.Visible then DGABoardListCloseClick(FrmDlg.DGABoardListClose, 0, 0);
            if DGABoardDlg.Visible then DGABoardCloseClick(FrmDlg.DGABoardClose, 0, 0);
            if DGADecorateDlg.Visible then DGADecorateCloseClick(FrmDlg.DGADecorateClose, 0, 0);}

            FrmMain.SendMerchantDlgSelect (CurMerchant, p.RStr);
            LastestClickTime := GetTickCount + 5000; //5ÃÊÈÄ¿¡ »ç¿ë °¡´É
            break;
         end;
      end;
end;

procedure TFrmDlg.DMerchantDlgMouseDown(Sender: TObject;
  Button: TMouseButton; Shift: TShiftState; X, Y: Integer);
var
   i, L, T: integer;
   p: PTClickPoint;
begin
   if GetTickCount < LastestClickTime then exit; //Å¬¸¯À» ÀÚÁÖ ¸øÇÏ°Ô Á¦ÇÑ
   SelectMenuStr := '';
   L := DMerchantDlg.Left;
   T := DMerchantDlg.Top;
   with DMerchantDlg do
      for i:=0 to MDlgPoints.Count-1 do begin
         p := PTClickPoint (MDlgPoints[i]);
         if (X >= SurfaceX(L + p.rc.Left)) and (X <= SurfaceX(L + p.rc.Right)) and
            (Y >= SurfaceY(T + p.rc.Top)) and (Y <= SurfaceY(T + p.rc.Bottom)) then begin
            SelectMenuStr := p.RStr;
            break;
         end;
      end;
end;

procedure TFrmDlg.DMerchantDlgMouseUp(Sender: TObject;
  Button: TMouseButton; Shift: TShiftState; X, Y: Integer);
begin
   SelectMenuStr := '';
end;

procedure TFrmDlg.DSellDlgDirectPaint(Sender: TObject;
  dsurface: TDirectDrawSurface);
var
   d: TDirectDrawSurface;
   actionname: string;
begin
   with DSellDlg do begin
      d := DMenuDlg.WLib.Images[FaceIndex];
      if d <> nil then
         dsurface.Draw (SurfaceX(Left), SurfaceY(Top), d.ClientRect, d, TRUE);

      with g_DXCanvas do begin
//         SetBkMode (Handle, TRANSPARENT);
//         Font.Color := clWhite;
         actionname := '';
         case SpotDlgMode of
            dmSell:   actionname := 'ÆÇ¸Å: ';
            dmRepair: actionname := '¼ö¸®: ';
            dmStorage: actionname := '   ¹°°Ç º¸°ü';
            dmMaketSell: actionname := '   À§Å¹ ÆÇ¸Å';
         end;
         TextOut (SurfaceX(Left+37), SurfaceY(Top+7), clWhite, actionname + SellPriceStr);
      end;
   end;
end;

procedure TFrmDlg.DSellDlgCloseClick(Sender: TObject; X, Y: Integer);
begin
   CloseDSellDlg;
end;

procedure TFrmDlg.DSellDlgSpotClick(Sender: TObject; X, Y: Integer);
var
   temp: TClientItem;
   MsgResult, Count : integer;
   valstr : String;
begin
   SellPriceStr := '';
   if not ItemMoving then begin
      if SellDlgItem.S.Name <> '' then begin
         ItemClickSound (SellDlgItem.S);
         ItemMoving := TRUE;
         MovingItem.Index := -99; //sell Ã¢¿¡¼­ ³ª¿È..
         MovingItem.Item := SellDlgItem;
         SellDlgItem.S.Name := '';
      end;
   end else begin
      if (MovingItem.Index = -97) or (MovingItem.Index = -98) then exit;
      if (MovingItem.Index >= 0) or (MovingItem.Index = -99) then begin
         ItemClickSound (MovingItem.Item.S);
         if SellDlgItem.S.Name <> '' then begin //ÀÚ¸®¿¡ ÀÖÀ¸¸é
            temp := SellDlgItem;
            SellDlgItem := MovingItem.Item;
            MovingItem.Index := -99; //sell Ã¢¿¡¼­ ³ª¿È..
            MovingItem.Item := temp;
         end
         else if MovingItem.Item.S.OverlapItem = 0 then begin
            SellDlgItem := MovingItem.Item;
            MovingItem.Item.S.name := '';
            ItemMoving := FALSE;
         end
         else if MovingItem.Item.S.OverlapItem > 0 then begin
            SellDlgItem := MovingItem.Item;
            ItemMoving := FALSE;
            Total := MovingItem.Item.Dura;
            if Total = 1 then begin
               DlgEditText := '1';
               MsgResult := mrOk;
            end
            else MsgResult := DCountMsgDlg ('ÃÑ ' + IntToStr(MovingItem.Item.Dura) +
                         '°³Áß ¸î°³¸¦ ¿Ã·Á³õ°Ú½À´Ï±î?', [mbOk, mbCancel, mbAbort]);
            ItemMoving := TRUE;
            GetValidStrVal (DlgEditText, valstr, [' ']);
            Count := Str_ToInt (valstr, 0);
            if Count <= 0 then begin
               Count := 0;
               AddItemBag(SellDlgItem);
               SellDlgItem.S.Name := '';
               SellDlgItem.Dura := 0;
               MovingItem.Item.S.name := '';
               CancelItemMoving;
               Exit;
            end;
            if Count >= SellDlgItem.Dura then begin
               Count := SellDlgItem.Dura;
               MovingItem.Item.Dura := 0;
            end;
            if MsgResult = mrOk then begin
               SellDlgItem.Dura := word(Count);
               if MovingItem.Item.Dura > 0 then begin
                  MovingItem.Item.Dura := MovingItem.Item.Dura - word(Count);
               end;
               if MovingItem.Item.Dura <= 0 then begin
                  MovingItem.Item.Dura := 0;
                  MovingItem.Item.S.name := '';
                  ItemMoving := FALSE;
               end;
//               MovingItem.Index := 0;
               CancelItemMoving;
            end;
            if MsgResult = mrCancel then begin
               AddItemBag(SellDlgItem);
               SellDlgItem.S.Name := '';
               SellDlgItem.Dura := 0;
               MovingItem.Item.S.name := '';
//               MovingItem.Index := 0;
               CancelItemMoving;
               Exit;
            end;
         end;

         BoQueryPrice := TRUE;
         QueryPriceTime := GetTickCount;
         //È¦µå¹öÆ°Ã³¸® 2006/04/04
         if SellStHold and (SellDlgItem.S.Name <> '') then DSellDlgOkClick(DSellDlgOk,1,1);
      end;
   end;

end;

procedure TFrmDlg.DSellDlgSpotDirectPaint(Sender: TObject;
  dsurface: TDirectDrawSurface);
var
   d: TDirectDrawSurface;
begin
   if SellDlgItem.S.Name <> '' then begin
      d := g_WInventory.Images[SellDlgItem.S.Looks];
      if d <> nil then begin
         with DSellDlgSpot do
            dsurface.Draw (SurfaceX(Left + (Width - d.Width) div 2),
                           SurfaceY(Top + (Height - d.Height) div 2),
                           d.ClientRect,
                           d, TRUE);

            if SellDlgItem.S.OverlapItem > 0 then begin
               with DSellDlgSpot do
                  g_DXCanvas.TextOut (SurfaceX(Left + (Width - d.Width) div 2)+21,
                                           SurfaceY(Top + (Height - d.Height) div 2)+15,
                                           clYellow, IntToStr(SellDlgItem.Dura));
            end;
      end;
   end;
end;

procedure TFrmDlg.DSellDlgSpotMouseMove(Sender: TObject;
  Shift: TShiftState; X, Y: Integer);
begin
   MouseItem := SellDlgItem;
end;

procedure TFrmDlg.DSellDlgOkClick(Sender: TObject; X, Y: Integer);
var
   dropgold: integer;
   valstr: string;
   MsgResult : integer;
begin
   if (SellDlgItem.S.Name = '') and (SellDlgItemSellWait.S.Name = '') then exit;
   if GetTickCount < LastestClickTime then exit; //Å¬¸¯À» ÀÚÁÖ ¸øÇÏ°Ô Á¦ÇÑ
   case SpotDlgMode of
      dmSell: FrmMain.SendSellItem (CurMerchant, SellDlgItem.MakeIndex, SellDlgItem.S.Name, SellDlgItem.Dura);
      dmRepair: FrmMain.SendRepairItem (CurMerchant, SellDlgItem.MakeIndex, SellDlgItem.S.Name);
      dmStorage: FrmMain.SendStorageItem (CurMerchant, SellDlgItem.MakeIndex, SellDlgItem.S.Name, SellDlgItem.Dura);
      dmMaketSell:
      begin
         DMessageDlg ('¾ó¸¶¿¡ À§Å¹ÇÏ½Ã°Ú½À´Ï±î?', [mbOk, mbAbort]);
         GetValidStrVal (DlgEditText, valstr, [' ']);

         try
            dropgold := Str_ToInt (valstr, 0);
         except
            DMessageDlg ('Àß¸øµÈ ÀÔ·ÂÀÔ´Ï´Ù.', [mbOk]);
            Exit;
         end;
         if (dropgold > 0) and (dropgold <= MAX_MARKETPRICE) then begin
            MsgResult := DMessageDlg (SellDlgItem.S.Name+' À» '+GetGoldStr(dropgold)+'Àü¿¡ À§Å¹ÇÏ°Ú½À´Ï±î?', [mbOk, mbCancel]);
            if MsgResult = mrOk then
               FrmMain.SendMaketSellItem (CurMerchant, SellDlgItem.MakeIndex, valstr, SellDlgItem.Dura )
            else if MsgResult = mrCancel then Exit;
         end else begin
            DMessageDlg ('Àû´çÇÑ ±Ý¾×À» ÀÔ·ÂÇÏ¼¼¿ä.\À§Å¹ÆÇ¸Å ÃÖ°í ±Ý¾×Àº '+GetGoldStr(MAX_MARKETPRICE)+'Àü ÀÔ´Ï´Ù.', [mbOk]);
            Exit;
         end;
      end;
   end;

   SellDlgItemSellWait := SellDlgItem;
   SellDlgItem.S.Name := '';
   LastestClickTime := GetTickCount + 5000;
   SellPriceStr := '';
end;





{------------------------------------------------------------------------}

//¸¶¹ý Å° ¼³Á¤ Ã¢ (´ÙÀÌ¾ó ·Î±×)

{------------------------------------------------------------------------}


procedure TFrmDlg.SetMagicKeyDlg (icon: integer; magname: string; var curkey: word);
begin
   MagKeyIcon := icon;
   MagKeyMagName := magname;
   MagKeyCurKey := curkey;


   DKeySelDlg.Left := (SCREENWIDTH - DKeySelDlg.Width) div 2;
   DKeySelDlg.Top  := (SCREENHEIGHT - DKeySelDlg.Height) div 2;
   HideAllControls;
   DKeySelDlg.ShowModal;

   while TRUE do begin
      if not DKeySelDlg.Visible then break;
      //FrmMain.DXTimerTimer (self, 0);
//      FrmMain.ProcOnIdle;
      Application.ProcessMessages;
      if Application.Terminated then exit;
   end;

   RestoreHideControls;
   curkey := MagKeyCurKey;
end;

procedure TFrmDlg.DKeySelDlgDirectPaint(Sender: TObject;
  dsurface: TDirectDrawSurface);
var
   d: TDirectDrawSurface;
begin
   with DKeySelDlg do begin
      d := WLib.Images[FaceIndex];
      if d <> nil then
         dsurface.Draw (SurfaceX(Left), SurfaceY(Top), d.ClientRect, d, TRUE);
      //¸¶¹ý ÀÌ¸§
      with g_DXCanvas do begin
         TextOut (SurfaceX(Left + 95), SurfaceY(Top + 38), clSilver, MagKeyMagName + 'ÀÇ Å°¼³Á¤');
      end;
   end;
end;

procedure TFrmDlg.DKsIconDirectPaint(Sender: TObject;
  dsurface: TDirectDrawSurface);
var
   d: TDirectDrawSurface;
begin
//   with DksIcon do begin
//      d := g_WMagIcon.Images[MagKeyIcon];
//      if d <> nil then
//         dsurface.Draw (SurfaceX(Left), SurfaceY(Top), d.ClientRect, d, TRUE);
//   end;
end;

procedure TFrmDlg.DKsF1DirectPaint(Sender: TObject;
  dsurface: TDirectDrawSurface);
var
   b: TDButton;
   d: TDirectDrawSurface;
begin
   b := nil;
   case MagKeyCurKey of
      word('1'): b := DKsF1;
      word('2'): b := DKsF2;
      word('3'): b := DKsF3;
      word('4'): b := DKsF4;
      word('5'): b := DKsF5;
      word('6'): b := DKsF6;
      word('7'): b := DKsF7;
      word('8'): b := DKsF8;
      // 2003/08/20 =>¸¶¹ý´ÜÃàÅ° Ãß°¡  // AddMagicKey
      word('1')+20: b := DKsConF1;
      word('2')+20: b := DKsConF2;
      word('3')+20: b := DKsConF3;
      word('4')+20: b := DKsConF4;
      word('5')+20: b := DKsConF5;
      word('6')+20: b := DKsConF6;
      word('7')+20: b := DKsConF7;
      word('8')+20: b := DKsConF8;
      //-------
      else b := DKsNone;
   end;
   if b = Sender then begin
      with b do begin
         d := WLib.Images[FaceIndex+1];
         if d <> nil then
            dsurface.Draw (SurfaceX(Left), SurfaceY(Top), d.ClientRect, d, TRUE);
      end;
   end;
   with Sender as TDButton do begin
      if Downed then begin
         d := WLib.Images[FaceIndex];
         if d <> nil then
            dsurface.Draw (SurfaceX(Left), SurfaceY(Top), d.ClientRect, d, TRUE);
      end;
   end;
end;

procedure TFrmDlg.DKsOkClick(Sender: TObject; X, Y: Integer);
begin
   DKeySelDlg.Visible := FALSE;
end;

procedure TFrmDlg.DKsF1Click(Sender: TObject; X, Y: Integer);
begin
   if Sender = DKsF1 then MagKeyCurKey := integer('1');
   if Sender = DKsF2 then MagKeyCurKey := integer('2');
   if Sender = DKsF3 then MagKeyCurKey := integer('3');
   if Sender = DKsF4 then MagKeyCurKey := integer('4');
   if Sender = DKsF5 then MagKeyCurKey := integer('5');
   if Sender = DKsF6 then MagKeyCurKey := integer('6');
   if Sender = DKsF7 then MagKeyCurKey := integer('7');
   if Sender = DKsF8 then MagKeyCurKey := integer('8');
   // 2003/08/20 =>¸¶¹ý´ÜÃàÅ° Ãß°¡  // AddMagicKey
   if Sender = DKsConF1 then MagKeyCurKey := integer('1')+20;
   if Sender = DKsConF2 then MagKeyCurKey := integer('2')+20;
   if Sender = DKsConF3 then MagKeyCurKey := integer('3')+20;
   if Sender = DKsConF4 then MagKeyCurKey := integer('4')+20;
   if Sender = DKsConF5 then MagKeyCurKey := integer('5')+20;
   if Sender = DKsConF6 then MagKeyCurKey := integer('6')+20;
   if Sender = DKsConF7 then MagKeyCurKey := integer('7')+20;
   if Sender = DKsConF8 then MagKeyCurKey := integer('8')+20;
   //------
   if Sender = DKsNone then MagKeyCurKey := 0;
end;



{------------------------------------------------------------------------}

//±âº»Ã¢ÀÇ ¹Ì´Ï ¹öÆ°

{------------------------------------------------------------------------}


procedure TFrmDlg.DBotMiniMapClick(Sender: TObject; X, Y: Integer);
begin
  if DMiniMapDlg.Visible then begin
    DMiniMapDlg.Visible:= False;
    BoWantMiniMap := FALSE;
  end else begin
    if GetTickCount > querymsgtime then begin
      querymsgtime := GetTickCount + 3000;
      FrmMain.SendWantMiniMap;
      BoWantMiniMap := TRUE;
//      Inc(ViewMiniMapStyle);
    end;
  end;
//   if ViewMiniMapStyle = 0 then begin
//      if GetTickCount > querymsgtime then begin
//         querymsgtime := GetTickCount + 3000;
//         FrmMain.SendWantMiniMap;
//         BoWantMiniMap := TRUE;
//         Inc (ViewMiniMapStyle);
//      end;
//   end else begin
//      Inc (ViewMiniMapStyle);
//      if ViewMiniMapStyle > 2 then begin
//         ViewMiniMapStyle := 0;
////         PrevVMMStyle := 1;  //ÃÊ±â °ª
//         BoWantMiniMap := FALSE;
//      end;
//   end;
end;

procedure TFrmDlg.DBotTradeClick(Sender: TObject; X, Y: Integer);
begin
   if GetTickCount > querymsgtime then begin
      querymsgtime := GetTickCount + 3000;
      FrmMain.SendDealTry;
   end;
end;

procedure TFrmDlg.DBotGuildClick(Sender: TObject; X, Y: Integer);
begin
   if DGuildDlg.Visible then begin
      DGuildDlg.Visible := FALSE;
   end else
      if GetTickCount > querymsgtime then begin
         querymsgtime := GetTickCount + 3000;
         FrmMain.SendGuildDlg;
      end;
end;

procedure TFrmDlg.DBotGroupClick(Sender: TObject; X, Y: Integer);
begin
   ToggleShowGroupDlg;
end;


{------------------------------------------------------------------------}

//±×·ì ´ÙÀÌ¾ó·Î±×

{------------------------------------------------------------------------}

procedure TFrmDlg.ToggleShowGroupDlg;
begin
   DGroupDlg.Visible := not DGroupDlg.Visible;
end;

procedure TFrmDlg.DGroupDlgDirectPaint(Sender: TObject;
  dsurface: TDirectDrawSurface);
var
   d: TDirectDrawSurface;
   lx, ly, n: integer;
begin
   with DGroupDlg do begin
      d := WLib.Images[FaceIndex];
      if d <> nil then
         dsurface.Draw(SurfaceX(Left), SurfaceY(Top), d.ClientRect, d, $ECFFFFFF, True);
      if GroupMembers.Count > 0 then begin
         with g_DXCanvas do begin
            lx := SurfaceX(37) + Left;
            ly := SurfaceY(98) + Top;
            TextOut (lx, ly, clSilver, GroupMembers[0]);
            for n:=1 to GroupMembers.Count-1 do begin
               lx := SurfaceX(37) + Left + ((n-1) mod 2) * 100;
               ly := SurfaceY(98 + 16) + Top + ((n-1) div 2) * 16;
               TextOut (lx, ly, clSilver, GroupMembers[n]);
            end;
         end;
      end;
   end;
end;

procedure TFrmDlg.DGrpDlgCloseClick(Sender: TObject; X, Y: Integer);
begin
   DGroupDlg.Visible := FALSE;
end;

procedure TFrmDlg.DGrpAllowGroupDirectPaint(Sender: TObject;
  dsurface: TDirectDrawSurface);
var
   d: TDirectDrawSurface;
begin
   with Sender as TDButton do begin
      if AllowGroup then begin
         d := WLib.Images[FaceIndex];
         if d <> nil then
            dsurface.Draw (SurfaceX(Left), SurfaceY(Top), d.ClientRect, d, TRUE);
      end;
   end;
end;

procedure TFrmDlg.DGrpAllowGroupClick(Sender: TObject; X, Y: Integer);
begin
   if GetTickCount > changegroupmodetime then begin
      AllowGroup := not AllowGroup;
      changegroupmodetime := GetTickCount + 2000; //timeout 5ÃÊ //DelayTime 5ÃÊ¿¡¼­ 2ÃÊ·Î¼öÁ¤ //2004/11/18
      FrmMain.SendGroupMode (AllowGroup);
   end;
end;

procedure TFrmDlg.DGrpCreateClick(Sender: TObject; X, Y: Integer);
var
   who: string;
begin
   if (GetTickCount > changegroupmodetime) and (GroupMembers.Count = 0) then begin
      DialogSize := 1;
      DMessageDlg ('±×·ì¿¡ Âü¿©ÇÒ »ç¶÷ÀÇ ÀÌ¸§À» ÀûÀ¸½Ê½Ã¿À.', [mbOk, mbAbort]);
      who := Trim (DlgEditText);
      if who <> '' then begin
         changegroupmodetime := GetTickCount + 2000; //timeout 5ÃÊ //DelayTime 5ÃÊ¿¡¼­ 2ÃÊ·Î¼öÁ¤ //2004/11/18
         FrmMain.SendCreateGroup (Trim (DlgEditText));
      end;
   end;
end;

procedure TFrmDlg.DGrpCreateMouseMove(Sender: TObject; Shift: TShiftState; X,
  Y: Integer);
var
  lx, ly: integer;
  sx, sy: integer;
begin
  with DGrpCreate do begin
    lx := LocalX(X - Left);
    ly := LocalY(Y - Top);
    sx := SurfaceX(Left) + DGroupDlg.SurfaceX(DGroupDlg.Left) + lx + 8;
    sy := SurfaceY(Top) + DGroupDlg.SurfaceX(DGroupDlg.Top) + ly + 6;
    DScreen.ShowHint(sx, sy, '×é¶Ó', $393800, True);
  end;
end;

procedure TFrmDlg.DGrpAddMemClick(Sender: TObject; X, Y: Integer);
var
   who: string;
begin
   if (GetTickCount > changegroupmodetime) and (GroupMembers.Count > 0) then begin
      DialogSize := 1;
      DMessageDlg ('±×·ì¿¡ Âü¿©ÇÒ »ç¶÷ÀÇ ÀÌ¸§À» ÀûÀ¸½Ê½Ã¿À.', [mbOk, mbAbort]);
      who := Trim (DlgEditText);
      if who <> '' then begin
         changegroupmodetime := GetTickCount + 2000; //timeout 5ÃÊ //DelayTime 5ÃÊ¿¡¼­ 2ÃÊ·Î¼öÁ¤ //2004/11/18
         FrmMain.SendAddGroupMember (Trim (DlgEditText));
      end;
   end;
end;

procedure TFrmDlg.DGrpAddMemMouseMove(Sender: TObject; Shift: TShiftState; X,
  Y: Integer);
var
  lx, ly: integer;
  sx, sy: integer;
begin
  with DGrpAddMem do begin
    lx := LocalX(X - Left);
    ly := LocalY(Y - Top);
    sx := SurfaceX(Left) + DGroupDlg.SurfaceX(DGroupDlg.Left) + lx + 8;
    sy := SurfaceY(Top) + DGroupDlg.SurfaceX(DGroupDlg.Top) + ly + 6;
    DScreen.ShowHint(sx, sy, 'Ìí¼Ó', $393800, True);
  end;
end;

procedure TFrmDlg.DGrpDelMemClick(Sender: TObject; X, Y: Integer);
var
   who: string;
begin
   if (GetTickCount > changegroupmodetime) and (GroupMembers.Count > 0) then begin
      DialogSize := 1;
      DMessageDlg ('±×·ì¿¡¼­ ºüÁú »ç¶÷ÀÇ ÀÌ¸§À» ÀûÀ¸½Ê½Ã¿À.', [mbOk, mbAbort]);
      who := Trim (DlgEditText);
      if who <> '' then begin
         changegroupmodetime := GetTickCount + 2000; //timeout 5ÃÊ //DelayTime 5ÃÊ¿¡¼­ 2ÃÊ·Î¼öÁ¤ //2004/11/18
         FrmMain.SendDelGroupMember (Trim (DlgEditText));
      end;
   end;
end;

procedure TFrmDlg.DGrpDelMemMouseMove(Sender: TObject; Shift: TShiftState; X,
  Y: Integer);
var
  lx, ly: integer;
  sx, sy: integer;
begin
  with DGrpDelMem do begin
    lx := LocalX(X - Left);
    ly := LocalY(Y - Top);
    sx := SurfaceX(Left) + DGroupDlg.SurfaceX(DGroupDlg.Left) + lx + 8;
    sy := SurfaceY(Top) + DGroupDlg.SurfaceX(DGroupDlg.Top) + ly + 6;
    DScreen.ShowHint(sx, sy, 'É¾³ý', $393800, True);
  end;
end;

procedure TFrmDlg.DBotLogoutClick(Sender: TObject; X, Y: Integer);
begin
   // 2003/08/29 IME ¹ö±×¼öÁ¤
   LocalLanguage := imSAlpha;

   FrmMain.SendClientMessage (CM_CANCLOSE, 0, 0, 0, 0);
{
   if (GetTickCount - LatestStruckTime > 10000) and
      (GetTickCount - LatestMagicTime > 10000) and
      (GetTickCount - LatestHitTime > 10000) or
      (Myself.Death) then begin
      FrmMain.AppLogOut;
   end else
      DScreen.AddChatBoardString ('ÀüÅõÁß¿¡´Â Á¢¼ÓÀ» ²÷À» ¼ö ¾ø½À´Ï´Ù.', clYellow, clRed);
}
end;

procedure TFrmDlg.DBotBeltClick(Sender: TObject; X, Y: Integer);
begin
  DBeltWin.Visible := not DBeltWin.visible;
end;

procedure TFrmDlg.DBotBeltMouseMove(Sender: TObject; Shift: TShiftState; X, Y: Integer);
var
  lx, ly: integer;
  sx, sy: integer;
begin
  with DBotBelt do begin
    lx := LocalX(X - Left);
    ly := LocalY(Y - Top);
    sx := SurfaceX(Left) + DBottom.SurfaceX(DBottom.Left) + lx + 13;
    sy := SurfaceY(Top) + DBottom.SurfaceX(DBottom.Top) + ly - 2;
    DScreen.ShowHint(sx, sy, 'ÎïÆ·¿ì½ÝÀ¸(Ctrl+Z, Z)', $393800, True);
  end;
end;

procedure TFrmDlg.DBotExitClick(Sender: TObject; X, Y: Integer);
begin
   if (GetTickCount - LatestStruckTime > 10000) and
      (GetTickCount - LatestMagicTime > 10000) and
      (GetTickCount - LatestHitTime > 10000) or
      (Myself.Death) then begin
      FrmMain.AppExit;
   end else
      DScreen.AddChatBoardString ('ÄãÔÚÕ½¶·µ±ÖÐ²»ÄÜÍË³öÓÎÏ·.', clYellow, clRed);
end;

procedure TFrmDlg.DBotPlusAbilClick(Sender: TObject; X, Y: Integer);
begin
   FrmDlg.OpenAdjustAbility;
end;


{------------------------------------------------------------------------}

//±³È¯ ´ÙÀÌ¾ó·Î±×

{------------------------------------------------------------------------}


procedure TFrmDlg.OpenDealDlg( DealCase: Byte);
var
   d: TDirectDrawSurface;
begin
   if DealCase = 1 then begin
      DDealDlg.Floating := True;
      DDealRemoteDlg.Floating := True;
      DDealRemoteDlg.Left := SCREENWIDTH-236-100;
      DDealRemoteDlg.Top := 0;
      DDealDlg.Left := SCREENWIDTH-236-100;
      DDealDlg.Top  := DDealRemoteDlg.Height;
      DDealJangwon.Visible := False;
   end
   else if DealCase = 2 then begin
      DDealJangwon.Floating := False;
      DDealJangwon.Visible := True;
      DDealDlg.Floating := False;
      DDealRemoteDlg.Floating := False;
      DDealRemoteDlg.Left := 558;
      DDealRemoteDlg.Top := 202;
      DDealDlg.Left := 322;
      DDealDlg.Top  := 202;
   end;
   DItemBag.Left := 0; //475;
   DItemBag.Top := 0;
   DItemBag.Visible := TRUE;
   DDealDlg.Visible := TRUE;
   DDealRemoteDlg.Visible := TRUE;

   FillCHar (DealItems, sizeof(TClientItem)*10, #0);
   FillCHar (DealRemoteItems, sizeof(TClientItem)*20, #0);
   DealGold := 0;
   DealRemoteGold := 0;
   BoDealEnd := FALSE;

   //¾ÆÀÌÅÛ °¡¹æ¿¡ ÀÜ»óÀÌ ÀÖ´ÂÁö °Ë»ç
   ArrangeItembag;
end;

procedure TFrmDlg.CloseDealDlg;
begin
   DDealDlg.Visible := FALSE;
   DDealRemoteDlg.Visible := FALSE;
   if DDealJangwon.Visible then DDealJangwon.Visible := False;

   //¾ÆÀÌÅÛ °¡¹æ¿¡ ÀÜ»óÀÌ ÀÖ´ÂÁö °Ë»ç
   ArrangeItembag;
end;

procedure TFrmDlg.DDealOkClick(Sender: TObject; X, Y: Integer);
var
   mi: integer;
begin
   if GetTickCount > dealactiontime then begin
      //CloseDealDlg;
      FrmMain.SendDealEnd;
      dealactiontime := GetTickCount + 4000;
      BoDealEnd := TRUE;
      //µô Ã¢¿¡¼­ ¸¶¿ì½º·Î ²ø°í ÀÖ´Â °ÍÀ» µôÃ¢À¸·Î ³Ö´Â´Ù. ¸¶¿ì½º¿¡ ³²´Â ÀÜ»ó(º¹»ç)À» ¾ø¾Ø´Ù.
      if ItemMoving then begin
         mi := MovingItem.Index;
         if (mi <= -20) and (mi > -30) then begin //µô Ã¢¿¡¼­ ¿Â°Í¸¸
            AddDealItem (MovingItem.Item);  // ±³È¯=>°ãÄ¡±â
            ItemMoving := FALSE;
            MovingItem.Item.S.name := '';
            MovingItem.Item.Dura := 0; // 10/29
         end;
      end;
   end;
end;

procedure TFrmDlg.DDealCloseClick(Sender: TObject; X, Y: Integer);
begin
   if GetTickCount > dealactiontime then begin
      CloseDealDlg;
      FrmMain.SendCancelDeal;
   end;
end;

procedure TFrmDlg.DDealRemoteDlgDirectPaint(Sender: TObject;
  dsurface: TDirectDrawSurface);
var
  d: TDirectDrawSurface;
begin
   with DDealRemoteDlg do begin
      d := WLib.Images[FaceIndex];
      if d <> nil then
         dsurface.Draw (SurfaceX(Left), SurfaceY(Top), d.ClientRect, d, TRUE);
      with g_DXCanvas do begin
         TextOut (SurfaceX(Left+69), SurfaceY(Top+111), clWhite, GetGoldStr(DealRemoteGold));
         TextOut (SurfaceX(Left+62 + (106-TextWidth(DealWho)) div 2), SurfaceY(Top+3)+5, clWhite, DealWho);
      end;
   end;
end;

procedure TFrmDlg.DDealDlgDirectPaint(Sender: TObject;
  dsurface: TDirectDrawSurface);
var
  d: TDirectDrawSurface;
begin
   with DDealDlg do begin
      d := WLib.Images[FaceIndex];
      if d <> nil then
         dsurface.Draw (SurfaceX(Left), SurfaceY(Top), d.ClientRect, d, TRUE);
      with g_DXCanvas do begin
         TextOut (SurfaceX(Left+69), SurfaceY(Top+111), clWhite, GetGoldStr(DealGold));
         TextOut (SurfaceX(Left+62 + (106-TextWidth(FrmMain.CharName)) div 2), SurfaceY(Top+3)+5, clWhite, FrmMain.CharName);
      end;
   end;
end;

procedure TFrmDlg.DealItemReturnBag (mitem: TClientItem);
begin
   if not BoDealEnd then begin
      DealDlgItem := mitem;
      FrmMain.SendDelDealItem (DealDlgItem);
      dealactiontime := GetTickCount + 4000;
   end;
end;

procedure TFrmDlg.DDGridGridSelect(Sender: TObject; X, Y: Integer; ACol, ARow: Integer;
  Shift: TShiftState);
var
   temp: TClientItem;
   mi, idx: integer;
   MsgResult, Count : integer;
   valstr : String;
begin
   if not BoDealEnd and (GetTickCount > dealactiontime) then begin
      //2004/01/15 ItemSafeGuard..
      if not ItemMoving then begin
//         idx := ACol + ARow * DDGrid.ColCount;
//         if idx in [0..9] then begin
//            if DealItems[idx].S.Name <> '' then begin
//               ItemMoving := TRUE;
//               MovingItem.Index := -idx - 20;
//               MovingItem.Item := DealItems[idx];
//               DealItems[idx].S.Name := '';
//               ItemClickSound (MovingItem.Item.S);
//            end;
//         end;
      end else begin
         mi := MovingItem.Index;
         if (mi >= 0) or (mi <= -20) and (mi > -30) then begin //°¡¹æ,¿¡¼­ ¿Â°Í¸¸
            ItemClickSound (MovingItem.Item.S);
            ItemMoving := FALSE;
            if mi >= 0 then begin
               if MovingItem.Item.S.OverlapItem > 0 then begin

                  Total := MovingItem.Item.Dura;
                  if Total = 1 then begin
                     DlgEditText := '1';
                     MsgResult := mrOk;
                  end
                  else MsgResult := DCountMsgDlg ('ÃÑ '+ IntToStr(MovingItem.Item.Dura) +
                                            '°³Áß ¸î°³¸¦ ¿Ã·Á³õ°Ú½À´Ï±î?', [mbOk, mbCancel, mbAbort]);
                  GetValidStrVal (DlgEditText, valstr, [' ']);
                  Count := Str_ToInt (valstr, 0);
                  if Count <= 0 then Count := 0;
                  if Count > MovingItem.Item.Dura then begin
                     Count := MovingItem.Item.Dura;
                  end;
                  ItemMoving := TRUE;
                  if MsgResult = mrOk then begin //and (Count > 0) and (Count < MAX_OVERLAPITEM+1 ) then begin
                     DealDlgItem := MovingItem.Item; //¼­¹ö¿¡ °á°ú¸¦ ±â´Ù¸®´Âµ¿¾È º¸°ü
                     DealDlgItem.Dura := word(Count);
                     MovingItem.Item.Dura := MovingItem.Item.Dura - Count;
                     if MovingItem.Item.Dura = 0 then begin
                        MovingItem.Item.S.name := '';
                        ItemMoving := FALSE;
                     end;
                     CancelItemMoving;
                     FrmMain.SendAddDealItem (DealDlgItem);
                     dealactiontime := GetTickCount + 4000;
                  end
                  else if MsgResult = mrCancel then begin
                     CancelItemMoving;
                     dealactiontime := GetTickCount;
                  end;
               end else begin
                  DealDlgItem := MovingItem.Item;
                  FrmMain.SendAddDealItem (DealDlgItem);
                  dealactiontime := GetTickCount + 4000;
               end;
            end else
               AddDealItem (MovingItem.Item);
            MovingItem.Item.S.name := '';
         end;
         if mi = -98 then DDGoldClick (self, 0, 0);
      end;
      ArrangeItemBag;
   end;
end;

procedure TFrmDlg.DCountDlgKeyDown(Sender: TObject; var Key: Word;
  Shift: TShiftState);
begin
   if Key = 13 then begin
      if DCountDlgOk.Visible then begin
         DCountDlg.DialogResult := mrOk;
         DCountDlg.Visible := FALSE;
      end;
   end;
   if Key = 27 then begin
      if DCountDlgCancel.Visible then begin
         DCountDlg.DialogResult := mrCancel;
         DCountDlg.Visible := FALSE;
      end;
   end;
end;

procedure TFrmDlg.DDGridGridPaint(Sender: TObject; ACol, ARow: Integer;
  Rect: TRect; State: TGridDrawState; dsurface: TDirectDrawSurface);
var
   idx: integer;
   d: TDirectDrawSurface;
begin
   idx := ACol + ARow * DDGrid.ColCount;
   if idx in [0..9] then begin
      if DealItems[idx].S.Name <> '' then begin
         d := g_WInventory.Images[DealItems[idx].S.Looks];
         if d <> nil then
            with DDGrid do
               dsurface.Draw (SurfaceX(Rect.Left + (ColWidth - d.Width) div 2 - 1),
                              SurfaceY(Rect.Top + (RowHeight - d.Height) div 2 + 1),
                              d.ClientRect,
                              d, TRUE);
         // ¾ÆÀÌÅÛ °ãÄ¡±â
         if DealItems[idx].S.OverlapItem > 0 then begin
            g_DXCanvas.TextOut (DDGrid.SurfaceX(Rect.Left +20), DDGrid.SurfaceY(Rect.Top +20),
                                clYellow, IntToStr(DealItems[idx].Dura));
         end;
      end;
   end;
end;

procedure TFrmDlg.DDGridGridMouseMove(Sender: TObject; X, Y: Integer; ACol, ARow: Integer;
  Shift: TShiftState);
var
   idx: integer;
begin
   idx := ACol + ARow * DDGrid.ColCount;
   if idx in [0..9] then begin
      MouseItem := DealItems[idx];
   end;
end;

procedure TFrmDlg.DDRGridGridPaint(Sender: TObject; ACol, ARow: Integer;
  Rect: TRect; State: TGridDrawState; dsurface: TDirectDrawSurface);
var
   idx: integer;
   i, k: integer;
   d: TDirectDrawSurface;
begin

   //Áßº¹µÈ ¾ÆÀÌÅÛÀÌ ÀÖÀ¸¸é ¾ø¾Ø´Ù.
   for i:=0 to 19 do begin
      if DealRemoteItems[i].S.Name <> '' then begin
         for k:=i+1 to 19 do begin
            if DealRemoteItems[i].S.OverlapItem > 0 then begin
               if (DealRemoteItems[i].S.Name = DealRemoteItems[k].S.Name) then begin //(ItemArr[i].MakeIndex <> ItemArr[k].MakeIndex) and
                  DealRemoteItems[i].Dura := DealRemoteItems[i].Dura + DealRemoteItems[k].Dura;
                  FillChar (DealRemoteItems[k], sizeof(TClientItem), #0);
               end;
            end
            else if (DealRemoteItems[i].S.Name = DealRemoteItems[k].S.Name) and (DealRemoteItems[i].MakeIndex = DealRemoteItems[k].MakeIndex) then begin
               FillChar (DealRemoteItems[k], sizeof(TClientItem), #0);
            end;
         end;
      end;
   end;

   idx := ACol + ARow * DDRGrid.ColCount;
   if idx in [0..19] then begin
      if DealRemoteItems[idx].S.Name <> '' then begin
         d := g_WBagItem.Images[DealRemoteItems[idx].S.Looks];
         if d <> nil then
            with DDRGrid do
               dsurface.Draw (SurfaceX(Rect.Left + (ColWidth - d.Width) div 2 - 1),
                              SurfaceY(Rect.Top + (RowHeight - d.Height) div 2 + 1),
                              d.ClientRect,
                              d, TRUE);
         // ¾ÆÀÌÅÛ °ãÄ¡±â
         if DealRemoteItems[idx].S.OverlapItem > 0 then begin
            g_DXCanvas.TextOut (DDRGrid.SurfaceX(Rect.Left +20), DDRGrid.SurfaceY(Rect.Top +20),
                                clYellow, IntToStr(DealRemoteItems[idx].Dura));
         end;

      end;
   end;
end;

procedure TFrmDlg.DDRGridGridMouseMove(Sender: TObject; X, Y: Integer; ACol,
  ARow: Integer; Shift: TShiftState);
var
   idx: integer;
begin
   idx := ACol + ARow * DDRGrid.ColCount;
   if idx in [0..19] then begin
      MouseItem := DealRemoteItems[idx];
   end;
end;

procedure TFrmDlg.DealZeroGold;
begin
   if not BoDealEnd and (DealGold > 0) then begin
      dealactiontime := GetTickCount + 4000;
      FrmMain.SendChangeDealGold (0);
   end;
end;

procedure TFrmDlg.SetMagicIconPos;
const
  DPosX = 29;
  DPosY = 56;
begin
  // È­°è¿­
  m_xMagicIconPos[0][0].nMagicID := _SKILL_FIREBALL;  //»ðÇòÊõ
  m_xMagicIconPos[0][0].nPosX := DPosX;
  m_xMagicIconPos[0][0].nPosY := DPosY;

  m_xMagicIconPos[0][1].nMagicID := _SKILL_FIREBALL2;  //´ó»ðÇò
  m_xMagicIconPos[0][1].nPosX := DPosX;
  m_xMagicIconPos[0][1].nPosY := DPosY + 65;

  m_xMagicIconPos[0][2].nMagicID := _SKILL_FIRE;     //µØÓü»ð
  m_xMagicIconPos[0][2].nPosX := DPosX + 60 * 2;
  m_xMagicIconPos[0][2].nPosY := DPosY + 65;

  m_xMagicIconPos[0][3].nMagicID := _SKILL_FIREBOOM;  //±¬ÁÑ»ðÑæ
  m_xMagicIconPos[0][3].nPosX := DPosX + 60 * 2;
  m_xMagicIconPos[0][3].nPosY := DPosY + 65 * 2;

  m_xMagicIconPos[0][4].nMagicID := _SKILL_EARTHFIRE;  //»ðÇ½
  m_xMagicIconPos[0][4].nPosX := DPosX + 60 * 2;
  m_xMagicIconPos[0][4].nPosY := DPosY + 65 * 3;

  m_xMagicIconPos[0][5].nMagicID := _SKILL_FIREBALL10;  //ÑæÌì»ðÓê
  m_xMagicIconPos[0][5].nPosX := DPosX;
  m_xMagicIconPos[0][5].nPosY := DPosY + 65 * 3;

  // ºù°è¿­
  m_xMagicIconPos[1][0].nMagicID := _SKILL_ICEBOLT;       //±ùÔÂÉñÕÆ
  m_xMagicIconPos[1][0].nPosX := DPosX;
  m_xMagicIconPos[1][0].nPosY := DPosY;

  m_xMagicIconPos[1][1].nMagicID := _SKILL_SUPERICEBOLT;    //±ùÔÂÕðÌì
  m_xMagicIconPos[1][1].nPosX := DPosX;
  m_xMagicIconPos[1][1].nPosY := DPosY + 65;

  m_xMagicIconPos[1][2].nMagicID := _SKILL_ICE;          //±ùÉ³ÕÆ
  m_xMagicIconPos[1][2].nPosX := DPosX + 60 * 2;
  m_xMagicIconPos[1][2].nPosY := DPosY + 65 * 2;

  m_xMagicIconPos[1][3].nMagicID := _SKILL_SNOWWIND;    //±ùÅØÏø
  m_xMagicIconPos[1][3].nPosX := DPosX + 60 * 2;
  m_xMagicIconPos[1][3].nPosY := DPosY + 65 * 3;

  m_xMagicIconPos[1][4].nMagicID := _SKILL_CROSS_ICE;    //ÆÇ±ù´Ì
  m_xMagicIconPos[1][4].nPosX := DPosX + 60 * 2;
  m_xMagicIconPos[1][4].nPosY := DPosY + 65 * 4;

  // ·Ú°è¿­
  m_xMagicIconPos[2][0].nMagicID := _SKILL_MAGICARROW;   //Åùö¨ÕÆ
  m_xMagicIconPos[2][0].nPosX := DPosX;
  m_xMagicIconPos[2][0].nPosY := DPosY;

  m_xMagicIconPos[2][1].nMagicID := _SKILL_LIGHTENING;   //À×µçÊõ
  m_xMagicIconPos[2][1].nPosX := DPosX;
  m_xMagicIconPos[2][1].nPosY := DPosY + 65;

  m_xMagicIconPos[2][2].nMagicID := _SKILL_SHOOTLIGHTEN;  //¼²¹âµçÓ°
  m_xMagicIconPos[2][2].nPosX := DPosX + 60 * 2;
  m_xMagicIconPos[2][2].nPosY := DPosY + 65 * 2;

  m_xMagicIconPos[2][3].nMagicID := _SKILL_LIGHTFLOWER;   //µØÓüÀ×¹â
  m_xMagicIconPos[2][3].nPosX := DPosX + 60 * 2;
  m_xMagicIconPos[2][3].nPosY := DPosY + 65 * 3;

  m_xMagicIconPos[2][4].nMagicID := _SKILL_THUNDERSTORM;   //Å­ÉñÅùö¨
  m_xMagicIconPos[2][4].nPosX := DPosX + 60 * 2;
  m_xMagicIconPos[2][4].nPosY := DPosY + 65 * 4;

//  m_xMagicIconPos[2][5].nMagicID := _SKILL_1000THUNDER;
//  m_xMagicIconPos[2][5].nPosX := 89;
//  m_xMagicIconPos[2][5].nPosY := 319;
//
//  m_xMagicIconPos[2][6].nMagicID := _SKILL_CLOUDTHUNDER;
//  m_xMagicIconPos[2][6].nPosX := 28;
//  m_xMagicIconPos[2][6].nPosY := 319;

  // Ç³°è¿­
  m_xMagicIconPos[3][0].nMagicID := _SKILL_HANDWIND;  //·çÕÆ
  m_xMagicIconPos[3][0].nPosX := DPosX;
  m_xMagicIconPos[3][0].nPosY := DPosY;

  m_xMagicIconPos[3][1].nMagicID := _SKILL_FIREWIND;   //¿¹¾Ü»ð»·
  m_xMagicIconPos[3][1].nPosX := DPosX + 60 * 4;
  m_xMagicIconPos[3][1].nPosY := DPosY + 65;

  m_xMagicIconPos[3][2].nMagicID := _SKILL_HURRICANEBOMB;  //»÷·ç
  m_xMagicIconPos[3][2].nPosX := DPosX;
  m_xMagicIconPos[3][2].nPosY := DPosY + 65;

  m_xMagicIconPos[3][3].nMagicID := _SKILL_HURRICANESHOT;  //·çÕðÌì
  m_xMagicIconPos[3][3].nPosX := DPosX + 60 * 2;
  m_xMagicIconPos[3][3].nPosY := DPosY + 65 * 2;

  m_xMagicIconPos[3][4].nMagicID := _SKILL_SHIELD;    //Ä§·¨¶Ü
  m_xMagicIconPos[3][4].nPosX := DPosX + 60 * 4;
  m_xMagicIconPos[3][4].nPosY := DPosY + 65 * 2;

  m_xMagicIconPos[3][5].nMagicID := _SKILL_HURRICANE;   //Áú¾í·ç
  m_xMagicIconPos[3][5].nPosX := DPosX + 60 * 2;
  m_xMagicIconPos[3][5].nPosY := DPosY + 65 * 3;

//  m_xMagicIconPos[3][6].nMagicID := _SKILL_KANGMAK;
//  m_xMagicIconPos[3][6].nPosX := 89;
//  m_xMagicIconPos[3][6].nPosY := 319;
//
//  m_xMagicIconPos[3][7].nMagicID := _SKILL_SHIELD_HIGH;
//  m_xMagicIconPos[3][7].nPosX := 149;
//  m_xMagicIconPos[3][7].nPosY := 199;

  // ½Å¼º
  m_xMagicIconPos[4][0].nMagicID := _SKILL_HEALLING;   //ÖÎÓúÊõ
  m_xMagicIconPos[4][0].nPosX := DPosX;
  m_xMagicIconPos[4][0].nPosY := DPosY;

  m_xMagicIconPos[4][1].nMagicID := _SKILL_MOONOK;    //ÔÂ»ê¶ÏÓñ
  m_xMagicIconPos[4][1].nPosX := DPosX + 60 * 2;
  m_xMagicIconPos[4][1].nPosY := DPosY + 65;

  m_xMagicIconPos[4][2].nMagicID := _SKILL_BIGHEALLING;   //ÈºÌåÖÎÓúÊõ
  m_xMagicIconPos[4][2].nPosX := DPosX;
  m_xMagicIconPos[4][2].nPosY := DPosY + 65 * 2;

  m_xMagicIconPos[4][3].nMagicID := _SKILL_MOONCHAM;    //ÔÂ»êÁé²¨
  m_xMagicIconPos[4][3].nPosX := DPosX + 60 * 2;
  m_xMagicIconPos[4][3].nPosY := DPosY + 65 * 2;

  m_xMagicIconPos[4][4].nMagicID := _SKILL_REVIVE;   //»ØÉúÊõ
  m_xMagicIconPos[4][4].nPosX := DPosX;
  m_xMagicIconPos[4][4].nPosY := DPosY + 65 * 3;

  m_xMagicIconPos[4][5].nMagicID := _SKILL_REMOVEPOISON;   //ÔÆ¼ÅÊõ
  m_xMagicIconPos[4][5].nPosX := DPosX + 60 * 4;
  m_xMagicIconPos[4][5].nPosY := DPosY + 65 * 3;

  m_xMagicIconPos[4][6].nMagicID := _SKILL_DOSASHIELD;   //ÒõÑô·¨»·
  m_xMagicIconPos[4][6].nPosX := DPosX + 60 * 4;
  m_xMagicIconPos[4][6].nPosY := DPosY + 65 * 4;

//  m_xMagicIconPos[4][7].nMagicID := _SKILL_INHALEHP;
//  m_xMagicIconPos[4][7].nPosX := 29;
//  m_xMagicIconPos[4][7].nPosY := 319;
//
//  m_xMagicIconPos[4][8].nMagicID := _SKILL_HEALX;
//  m_xMagicIconPos[4][8].nPosX := 29;
//  m_xMagicIconPos[4][8].nPosY := 379;

  // ¾ÏÈæ
  m_xMagicIconPos[5][0].nMagicID := _SKILL_AMYOUNSUL;    //Ê©¶¾Êõ
  m_xMagicIconPos[5][0].nPosX := DPosX;
  m_xMagicIconPos[5][0].nPosY := DPosY;

  m_xMagicIconPos[5][1].nMagicID := _SKILL_FIRECHARM;    //Áé»ê»ð·û
  m_xMagicIconPos[5][1].nPosX := DPosX + 60 * 3;
  m_xMagicIconPos[5][1].nPosY := DPosY;

  m_xMagicIconPos[5][2].nMagicID := _SKILL_HOLYSHIELD;    //À§Ä§Öä
  m_xMagicIconPos[5][2].nPosX := DPosX;
  m_xMagicIconPos[5][2].nPosY := DPosY + 65;

  m_xMagicIconPos[5][3].nMagicID := _SKILL_HANGMAJINBUB;  //ÓÄÁé¶Ü
  m_xMagicIconPos[5][3].nPosX := DPosX + 60;
  m_xMagicIconPos[5][3].nPosY := DPosY + 65;

  m_xMagicIconPos[5][4].nMagicID := _SKILL_CLOAK;   //ÒþÉíÊõ
  m_xMagicIconPos[5][4].nPosX := DPosX + 60 * 2;
  m_xMagicIconPos[5][4].nPosY := DPosY;

  m_xMagicIconPos[5][5].nMagicID := _SKILL_DEJIWONHO; //ÉñÊ¥Õ½¼×Êõ
  m_xMagicIconPos[5][5].nPosX := DPosX + 60;
  m_xMagicIconPos[5][5].nPosY := DPosY + 65 * 2;

  m_xMagicIconPos[5][6].nMagicID := _SKILL_BIGCLOAK;     //¼¯ÌåÒþÉíÊõ
  m_xMagicIconPos[5][6].nPosX := DPosX + 60 * 2;
  m_xMagicIconPos[5][6].nPosY := DPosY + 65;

  m_xMagicIconPos[5][7].nMagicID := _SKILL_MAGICUP;    //Ç¿Ä§Õð·¨
  m_xMagicIconPos[5][7].nPosX := DPosX + 60;
  m_xMagicIconPos[5][7].nPosY := DPosY + 65 * 3;

  m_xMagicIconPos[5][8].nMagicID := _SKILL_POWERUP;   //ÃÍ»¢Ç¿ÊÆ
  m_xMagicIconPos[5][8].nPosX := DPosX + 60;
  m_xMagicIconPos[5][8].nPosY := DPosY + 65 * 4;

  m_xMagicIconPos[5][9].nMagicID := _SKILL_FULLCLOAK;  //ÃîÓ°ÎÞ×Ù
  m_xMagicIconPos[5][9].nPosX := DPosX + 60 * 2;
  m_xMagicIconPos[5][9].nPosY := DPosY + 65 * 4;

//  m_xMagicIconPos[5][10].nMagicID := _SKILL_MYULSAL;
//  m_xMagicIconPos[5][10].nPosX := 29;
//  m_xMagicIconPos[5][10].nPosY := 379;
//
//  m_xMagicIconPos[5][11].nMagicID := _SKILL_BIGAM;
//  m_xMagicIconPos[5][11].nPosX := 29;
//  m_xMagicIconPos[5][11].nPosY := 449;
//
//  m_xMagicIconPos[5][12].nMagicID := _SKILL_DEJIWONHO_HIGH;
//  m_xMagicIconPos[5][12].nPosX := 89;
//  m_xMagicIconPos[5][12].nPosY := 259;
//
//  m_xMagicIconPos[5][13].nMagicID := _SKILL_CLOAK_HIGH;
//  m_xMagicIconPos[5][13].nPosX := 149;
//  m_xMagicIconPos[5][13].nPosY := 139;
//
//  m_xMagicIconPos[5][14].nMagicID := _SKILL_MOONCHAM_HIGH;
//  m_xMagicIconPos[5][14].nPosX := 29;
//  m_xMagicIconPos[5][14].nPosY := 379;
  // È¯¿µ
  m_xMagicIconPos[6][0].nMagicID := _SKILL_SKELLETON;  //ÕÙ»½÷¼÷Ã
  m_xMagicIconPos[6][0].nPosX := DPosX;
  m_xMagicIconPos[6][0].nPosY := DPosY;

  m_xMagicIconPos[6][1].nMagicID := _SKILL_TAMMING;    //ÓÕ»óÖ®¹â
  m_xMagicIconPos[6][1].nPosX := DPosX + 60 * 2;
  m_xMagicIconPos[6][1].nPosY := DPosY;

  m_xMagicIconPos[6][2].nMagicID := _SKILL_SPACEMOVE;  //Ë²Ï¢ÒÆ¶¯
  m_xMagicIconPos[6][2].nPosX := DPosX + 60 * 3;
  m_xMagicIconPos[6][2].nPosY := DPosY;

  m_xMagicIconPos[6][3].nMagicID := _SKILL_SINSU;   //ÕÙ»½ÉñÊÞ
  m_xMagicIconPos[6][3].nPosX := DPosX;
  m_xMagicIconPos[6][3].nPosY := DPosY + 65;

  m_xMagicIconPos[6][4].nMagicID := _SKILL_KILLUNDEAD; //Ê¥ÑÔÊõ
  m_xMagicIconPos[6][4].nPosX := DPosX + 60 * 2;
  m_xMagicIconPos[6][4].nPosY := DPosY + 65;

  m_xMagicIconPos[6][5].nMagicID := _SKILL_SMALLSPACEMOVE; //ÒìÐÎ»»Î»
  m_xMagicIconPos[6][5].nPosX := DPosX + 60 * 3;
  m_xMagicIconPos[6][5].nPosY := DPosY + 65;

  m_xMagicIconPos[6][6].nMagicID := _SKILL_POWERSKELLETON; //³¬Ç¿ÕÙ»½÷¼÷Ã
  m_xMagicIconPos[6][6].nPosX := DPosX;
  m_xMagicIconPos[6][6].nPosY := DPosY + 65 * 2;

  m_xMagicIconPos[6][7].nMagicID := _SKILL_MONSTERUP;   //ÒÆ»¨½ÓÓñ
  m_xMagicIconPos[6][7].nPosX := DPosX;
  m_xMagicIconPos[6][7].nPosY := DPosY + 65 * 3;

  m_xMagicIconPos[6][8].nMagicID := _SKILL_MAXDEFEECEMAGIC; //ÄýÑªÀë»ê
  m_xMagicIconPos[6][8].nPosX := DPosX + 60 * 2;
  m_xMagicIconPos[6][8].nPosY := DPosY + 65 * 3;

//  m_xMagicIconPos[6][9].nMagicID := _SKILL_DOLL;
//  m_xMagicIconPos[6][9].nPosX := 29;
//  m_xMagicIconPos[6][9].nPosY := 319;
//
//  m_xMagicIconPos[6][10].nMagicID := _SKILL_COPY;
//  m_xMagicIconPos[6][10].nPosX := 209;
//  m_xMagicIconPos[6][10].nPosY := 319;
//
//  m_xMagicIconPos[6][11].nMagicID := _SKILL_MAXDEFEECEMAGIC_HIGH;
//  m_xMagicIconPos[6][11].nPosX := 149;
//  m_xMagicIconPos[6][11].nPosY := 319;

//  x 12, y 65;
  // ¹«¼Ó¼º
  m_xMagicIconPos[7][0].nMagicID := _SKILL_ONESWORD;   //»ù±¾½£·¨
  m_xMagicIconPos[7][0].nPosX := DPosX;
  m_xMagicIconPos[7][0].nPosY := DPosY;

  m_xMagicIconPos[7][1].nMagicID := _SKILL_MOOTEBO;    //Ò°Âù³å×²
  m_xMagicIconPos[7][1].nPosX := DPosX + 60 * 3;
  m_xMagicIconPos[7][1].nPosY := DPosY + 65 * 3;

  m_xMagicIconPos[7][2].nMagicID := _SKILL_ILKWANG;    //¾«ÉñÁ¦Õ½·¨
  m_xMagicIconPos[7][2].nPosX := DPosX + 60 * 4;
  m_xMagicIconPos[7][2].nPosY := DPosY;

  m_xMagicIconPos[7][3].nMagicID := _SKILL_YEDO;       //¹¥É±½£Êõ
  m_xMagicIconPos[7][3].nPosX := DPosX;
  m_xMagicIconPos[7][3].nPosY := DPosY + 65;

  m_xMagicIconPos[7][4].nMagicID := _SKILL_KICK;       //¿ÕÈ­µ¶·¨
  m_xMagicIconPos[7][4].nPosX := DPosX + 60 * 4;
  m_xMagicIconPos[7][4].nPosY := DPosY + 65 * 3;

  m_xMagicIconPos[7][5].nMagicID := _SKILL_ERGUM;      //´ÌÉ±½£Êõ
  m_xMagicIconPos[7][5].nPosX := DPosX;
  m_xMagicIconPos[7][5].nPosY := DPosY + 65 * 2;

  m_xMagicIconPos[7][6].nMagicID := _SKILL_BANWOL;     //°ëÔÂÍäµ¶
  m_xMagicIconPos[7][6].nPosX := DPosX + 60;
  m_xMagicIconPos[7][6].nPosY := DPosY + 65 * 3;

  m_xMagicIconPos[7][7].nMagicID := _SKILL_FIRESWORD;  //ÁÒ»ð½£·¨
  m_xMagicIconPos[7][7].nPosX := DPosX + 60 * 2;
  m_xMagicIconPos[7][7].nPosY := DPosY + 65 * 4;

  m_xMagicIconPos[7][8].nMagicID := _SKILL_JUMPSHOT;   //Ïè¿Õ½£·¨
  m_xMagicIconPos[7][8].nPosX := DPosX + 60;
  m_xMagicIconPos[7][8].nPosY := DPosY + 65 * 4;

  m_xMagicIconPos[7][9].nMagicID := _SKILL_RANDSWING;  //Á«ÔÂ½£·¨
  m_xMagicIconPos[7][9].nPosX := DPosX + 60 * 2;
  m_xMagicIconPos[7][9].nPosY := DPosY + 65 * 5;

  m_xMagicIconPos[7][10].nMagicID := _SKILL_MANWOL;   //Ê®·½Õ¶
  m_xMagicIconPos[7][10].nPosX := DPosX + 60;
  m_xMagicIconPos[7][10].nPosY := DPosY + 65 * 5;

  m_xMagicIconPos[7][11].nMagicID := _SKILL_CHANGEPOSITION; //Ç¬À¤´óÅ²ÒÆ
  m_xMagicIconPos[7][11].nPosX := DPosX + 60 * 3;
  m_xMagicIconPos[7][11].nPosY := DPosY + 65 * 4;

  m_xMagicIconPos[7][12].nMagicID := _SKILL_MAXDEFENCE;  //Ìú²¼ÉÀ
  m_xMagicIconPos[7][12].nPosX := DPosX + 60 * 3;
  m_xMagicIconPos[7][12].nPosY := DPosY + 65 * 5;

  m_xMagicIconPos[7][13].nMagicID := _SKILL_MAXOFENCE;    //ÆÆÑª¿ñÉ±
  m_xMagicIconPos[7][13].nPosX := DPosX + 60 * 3;
  m_xMagicIconPos[7][13].nPosY := DPosY + 65 * 7;

  m_xMagicIconPos[7][14].nMagicID := _SKILL_PULL;       //¶·×ªÐÇÒÆ
  m_xMagicIconPos[7][14].nPosX := DPosX + 60 * 3;
  m_xMagicIconPos[7][14].nPosY := DPosY + 65 * 6;

//  m_xMagicIconPos[7][15].nMagicID := _SKILL_PAWHANGBO;
//  m_xMagicIconPos[7][15].nPosX := 149;
//  m_xMagicIconPos[7][15].nPosY := 439;
//
//  m_xMagicIconPos[7][16].nMagicID := _SKILL_TAWOO;
//  m_xMagicIconPos[7][16].nPosX := 269;
//  m_xMagicIconPos[7][16].nPosY := 379;
//
//  m_xMagicIconPos[7][17].nMagicID := _SKILL_BANTAN;
//  m_xMagicIconPos[7][17].nPosX := 209;
//  m_xMagicIconPos[7][17].nPosY := 499;
//
//  m_xMagicIconPos[7][18].nMagicID := _SKILL_FREEMOVE;
//  m_xMagicIconPos[7][18].nPosX := 149;
//  m_xMagicIconPos[7][18].nPosY := 499;
//
//  m_xMagicIconPos[7][19].nMagicID := _SKILL_POTIONUP;
//  m_xMagicIconPos[7][19].nPosX := 29;
//  m_xMagicIconPos[7][19].nPosY := 499;
//
//  m_xMagicIconPos[7][20].nMagicID := _SKILL_HYPERSWORD;
//  m_xMagicIconPos[7][20].nPosX := 89;
//  m_xMagicIconPos[7][20].nPosY := 559;
//
//  m_xMagicIconPos[7][21].nMagicID := _SKILL_BIGMOUNTAIN;
//  m_xMagicIconPos[7][21].nPosX := 209;
//  m_xMagicIconPos[7][21].nPosY := 559;
//
//  m_xMagicIconPos[7][22].nMagicID := _SKILL_RANDSWING_HIGH;
//  m_xMagicIconPos[7][22].nPosX := 89;
//  m_xMagicIconPos[7][22].nPosY := 379;
//
//  m_xMagicIconPos[7][23].nMagicID := _SKILL_JUMPSHOT_HIGH;
//  m_xMagicIconPos[7][23].nPosX := 29;
//  m_xMagicIconPos[7][23].nPosY := 319;
//
//  m_xMagicIconPos[7][24].nMagicID := _SKILL_PAWHANGBO_HIGH;
//  m_xMagicIconPos[7][24].nPosX := 149;
//  m_xMagicIconPos[7][24].nPosY := 439;
//
//  m_xMagicIconPos[7][25].nMagicID := _SKILL_BALSACHE;
//  m_xMagicIconPos[7][25].nPosX := 29;
//  m_xMagicIconPos[7][25].nPosY := 619;
//
//  m_xMagicIconPos[7][26].nMagicID := _SKILL_JIKSUNGYE;
//  m_xMagicIconPos[7][26].nPosX := 89;
//  m_xMagicIconPos[7][26].nPosY := 619;
//
//  m_xMagicIconPos[7][27].nMagicID := _SKILL_POKBAL;
//  m_xMagicIconPos[7][27].nPosX := 149;
//  m_xMagicIconPos[7][27].nPosY := 619;
//
//  m_xMagicIconPos[7][28].nMagicID := _SKILL_JISOKGYE;
//  m_xMagicIconPos[7][28].nPosX := 209;
//  m_xMagicIconPos[7][28].nPosY := 619;
end;


procedure TFrmDlg.DDGoldClick(Sender: TObject; X, Y: Integer);
var
   dgold: integer;
   valstr: string;
begin
   if Myself = nil then exit;
   if not BoDealEnd and (GetTickCount > dealactiontime) then begin
      if not ItemMoving then begin
         if DealGold > 0 then begin
            PlaySound (s_money);
            ItemMoving := TRUE;
            MovingItem.Index := -97; //±³È¯ Ã¢¿¡¼­ÀÇ µ·
            MovingItem.Item.S.Name := '±ÝÀü';
         end;
      end else begin
         if (MovingItem.Index = -97) or (MovingItem.Index = -98) then begin //µ·¸¸..
            if (MovingItem.Index = -98) then begin //°¡¹æÃ¢¿¡¼­ ¿Â µ·
               if MovingItem.Item.S.Name = '±ÝÀü' then begin
                  //¾ó¸¶¸¦ ¹ö¸± °ÇÁö ¹°¾îº»´Ù.
                  DialogSize := 1;
                  ItemMoving := FALSE;
                  MovingItem.Item.S.Name := '';
                  DMessageDlg ('µ·À» ¾ó¸¶³ª ¿Å±â°Ú½À´Ï±î?', [mbOk, mbAbort]);
                  GetValidStrVal (DlgEditText, valstr, [' ']);
                  dgold := Str_ToInt (valstr, 0);
                  if (dgold <= (DealGold+Myself.Gold)) and (dgold > 0) then begin
                     FrmMain.SendChangeDealGold (dgold);
                     dealactiontime := GetTickCount + 4000;
                  end else
                     dgold := 0;
               end;
            end;
            ItemMoving := FALSE;
            MovingItem.Item.S.Name := '';
         end;
      end;
   end;
end;



{--------------------------------------------------------------}


procedure TFrmDlg.DUserState1DirectPaint(Sender: TObject;
  dsurface: TDirectDrawSurface);
var
   i, l, m, pgidx, bbx, bby, idx, ax, ay, sex, hair, tx: integer;
   d: TDirectDrawSurface;
   hcolor, keyimg: integer;
   iname, d1, d2, d3, d4, str, fstr: string;
   useable: Boolean;
   FColor: TColor;
   nLeft, nTop: integer;
   nCnt: integer;
   wLooks: word;
begin
  with DUserState1 do begin
      d := WLib.Images[FaceIndex];
      if d <> nil then
         dsurface.Draw (SurfaceX(Left), SurfaceY(Top), d.ClientRect, d, $ECFFFFFF, TRUE);

    nLeft := Left + ((d.Width - 284) div 2);
    nTop := Top + ((d.Height - 350) div 2);
      //Âø¿ë»óÅÂ
      sex := DRESSfeature (UserState1.Feature) mod 2;
      hair := HAIRfeature (UserState1.Feature);
      if sex = 1 then pgidx := 1   //¿©ÀÚ
      else pgidx := 0;     //³²ÀÚ
//      if (UserState1.UseItems[U_DRESS].S.Name <> '') and
//         ((UserState1.UseItems[U_DRESS].S.Looks = 597) or (UserState1.UseItems[U_DRESS].S.Looks = 607)) then pgidx := 378;
//
    bbx := nLeft + 120;
    bby := nTop + 225;
    d := g_WProgUse.GetCachedImage(pgidx, ax, ay);
    if d <> nil then
       dsurface.Draw (SurfaceX(bbx+ax), SurfaceY(bby+ay), d.ClientRect, d, TRUE);

//      bbx := bbx - 7;
//      bby := bby + 44;
//
//      if UserState1.UseItems[U_DRESS].S.Name <> '' then begin
//         idx := UserState1.UseItems[U_DRESS].S.Looks; //¿Ê if Sex = 1 then idx := 80; //¿©ÀÚ¿Ê
//         if idx >= 0 then begin
//            d := g_WStateItem.GetCachedImage (idx, ax, ay);
//            if d <> nil then
//               dsurface.Draw (SurfaceX(bbx+ax), SurfaceY(bby+ay), d.ClientRect, d, TRUE);
//         end;
//      end;
//
//      //¿Ê, ¹«±â, ¸Ó¸® ½ºÅ¸ÀÏ
//      if (UserState1.UseItems[U_DRESS].S.Name = '') or
//         ((UserState1.UseItems[U_DRESS].S.Looks <> 597) and (UserState1.UseItems[U_DRESS].S.Looks <> 607)) then begin
////         idx := 440 + hair div 2; //¸Ó¸® ½ºÅ¸ÀÏ
////         if sex = 1 then idx := 480 + hair div 2;
//         idx := 442; //¸Ó¸® ½ºÅ¸ÀÏ
//         if sex = 1 then idx := 482;
//         if idx > 0 then begin
//            d := g_WProgUse.GetCachedImage (idx, ax, ay);
//            if d <> nil then
//               dsurface.Draw (SurfaceX(bbx+ax), SurfaceY(bby+ay), d.ClientRect, d, TRUE);
//         end;
//      end;
//
//
//      if UserState1.UseItems[U_WEAPON].S.Name <> '' then begin
//         idx := UserState1.UseItems[U_WEAPON].S.Looks;
//         if idx >= 0 then begin
//            d := g_WStateItem.GetCachedImage (idx, ax, ay);
//            if d <> nil then
//               dsurface.Draw (SurfaceX(bbx+ax), SurfaceY(bby+ay), d.ClientRect, d, TRUE);
//         end;
//         if idx = 923 then begin
//            d := g_WStateItem.GetCachedImage (idx-1, ax, ay);
//            if d <> nil then DrawBlend (dsurface, SurfaceX(bbx+ax), SurfaceY(bby+ay), d, 1);
//         end;
//      end;
//      if UserState1.UseItems[U_HELMET].S.Name <> '' then begin
//         idx := UserState1.UseItems[U_HELMET].S.Looks;
//         if idx >= 0 then begin
//            d := g_WStateItem.GetCachedImage (idx, ax, ay);
//            if d <> nil then
//               dsurface.Draw (SurfaceX(bbx+ax), SurfaceY(bby+ay), d.ClientRect, d, TRUE);
//         end;
//      end;
//
//
//      if MouseUserStateItem.S.Name <> '' then begin
//         MouseItem := MouseUserStateItem;
//         GetMouseItemInfo (iname, d1, d2, d3, d4, useable, FALSE);
//         if iname <> '' then begin
//            if MouseItem.Dura = 0 then hcolor := clRed
////            else if MouseItem.UpgradeOpt > 0 then hcolor := clAqua
//            else if MouseItem.UpgradeOpt > 0 then hcolor := TColor($cccc33)
//            else hcolor := clWhite;
//            {
//            with dsurface.Canvas do begin
//               SetBkMode (Handle, TRANSPARENT);
//               Font.Color := clYellow;
//               TextOut (SurfaceX(Left+37), SurfaceY(Top+272), iname);
//               Font.Color := hcolor;
//               TextOut (SurfaceX(Left+37+TextWidth(iname)), SurfaceY(Top+272), d1);
//               TextOut (SurfaceX(Left+37), SurfaceY(Top+272+TextHeight('A')+2), d2);
//               TextOut (SurfaceX(Left+37), SurfaceY(Top+272+(TextHeight('A')+2)*2), d3);
//               Release;
//            end;
//            }
//            // 2003/03/15 ¾ÆÀÌÅÛ ÀÎº¥Åä¸® È®Àå
//            Str := iname + d1 + '\' + d2 + '\' + d3 + d4;
//            DScreen.ShowHint(MouseX, MouseY, Str, hcolor, FALSE);
//         end;
//         MouseItem.S.Name := '';
//      end;
////      else if Not UserState1.bExistLover then
////         DScreen.ClearHint;
//
//      //ÀÌ¸§
//      with g_DXCanvas do begin
//         FColor := UserState1.NameColor;
//         tx := 122 - TextWidth(UserState1.UserName) div 2;
//         TextOut (SurfaceX(Left + tx), SurfaceX(Top + 12), FColor, UserState1.UserName);
//         DHeartImgUS.Left := tx-14;
//         DHeartImgUS.Top := 12;
//
//         FColor := clSilver;
//         tx := 122 - TextWidth(UserState1.GuildName + ' ' + UserState1.GuildRankName) div 2;
//         TextOut (SurfaceX(Left + tx), SurfaceY(Top + 27), FColor,
//                  UserState1.GuildName + ' ' + UserState1.GuildRankName);
////         Font.Color := clYellow;
////         TextOut (SurfaceX(Left + 45), SurfaceY(Top + 55), UserState1.GuildName);
////         Font.Color := clSilver;
//
//         fstr := Copy(UserState1.FameName, 1, pos(' ', UserState1.FameName)-1 );
//         tx := 122 - TextWidth(UserState1.FameName) div 2;
//         TextOut (SurfaceX(Left + tx), SurfaceY(Top + 41), FColor, UserState1.FameName );
//         FColor := clGreen;
//         TextOut (SurfaceX(Left + tx), SurfaceY(Top + 41), FColor, fstr );
//      end;

   end;

end;

procedure TFrmDlg.DUserState1MouseDown(Sender: TObject;
  Button: TMouseButton; Shift: TShiftState; X, Y: Integer);
begin
//   X := DUserState1.LocalX (X) - DUserState1.Left;
//   Y := DUserState1.LocalY (Y) - DUserState1.Top;
//   if (X > 30) and (X < 215) and (Y > 24) and (Y < 36) then begin
//      //DScreen.AddSysMsg (IntToStr(X) + ' ' + IntToStr(Y) + ' ' + UserState1.GuildName);
//      if UserState1.GuildName <> '' then begin
//         PlayScene.EdChat.Visible := TRUE;
//         PlayScene.EdChat.SetFocus;
//         SetImeMode (PlayScene.EdChat.Handle, imSHanguel);
//         PlayScene.EdChat.Text := UserState1.GuildName;
//         PlayScene.EdChat.SelStart := Length(PlayScene.EdChat.Text);
//         PlayScene.EdChat.SelLength := 0;
//      end;
//   end
//   else if (X > 73) and (X < 172) and (Y > 9) and (Y < 23) then begin
//      if UserState1.UserName <> '' then begin
//         PlayScene.EdChat.Visible := TRUE;
//         PlayScene.EdChat.SetFocus;
////         SetImeMode (PlayScene.EdChat.Handle, LocalLanguage);
//         SetImeMode (PlayScene.EdChat.Handle, imSHanguel);
//         PlayScene.EdChat.Text := '/'+UserState1.UserName+' ';
//         PlayScene.EdChat.SelStart := Length(PlayScene.EdChat.Text);
//         PlayScene.EdChat.SelLength := 0;
//      end;
//   end;
end;

procedure TFrmDlg.DUserState1MouseMove(Sender: TObject; Shift: TShiftState;
  X, Y: Integer);
begin
   MouseUserStateItem.S.Name := '';
//   if UserState1.bExistLover then begin
//      X := DUserState1.LocalX (X) - DUserState1.Left;
//      Y := DUserState1.LocalY (Y) - DUserState1.Top;
//      if (X > 73) and (X < 170) and (Y > 9) and (Y < 22) then
//         DScreen.ShowHint (DUserState1.Left+DHeartImgUS.Left+10, DUserState1.Top+DHeartImgUS.Top+14,
//                           UserState1.LoverName+'ÀÇ ¿¬ÀÎ', clYellow, FALSE)
//      else if Y < 200 then DScreen.ClearHint;
//   end;
end;

procedure TFrmDlg.DWeaponUS1MouseMove(Sender: TObject; Shift: TShiftState;
  X, Y: Integer);
var
   sel: integer;
begin
   sel := -1;
   if Sender = DDressUS1 then sel := U_DRESS;
   if Sender = DWeaponUS1 then sel := U_WEAPON;
   if Sender = DHelmetUS1 then sel := U_HELMET;
   if Sender = DNecklaceUS1 then sel := U_NECKLACE;
   if Sender = DLightUS1 then sel := U_RIGHTHAND;
   if Sender = DRingLUS1 then sel := U_RINGL;
   if Sender = DRingRUS1 then sel := U_RINGR;
   if Sender = DArmRingLUS1 then sel := U_ARMRINGL;
   if Sender = DArmRingRUS1 then sel := U_ARMRINGR;
   // 2003/03/15 ¾ÆÀÌÅÛ ÀÎº¥Åä¸® È®Àå
   if Sender = DBujukUS1 then sel := U_BUJUK;
   if Sender = DBeltUS1  then sel := U_BELT;
   if Sender = DBootsUS1 then sel := U_BOOTS;
   if Sender = DCharmUS1 then sel := U_CHARM;

   if sel >= 0 then begin
      MouseUserStateItem := UserState1.UseItems[sel];
      // 2003/03/15 ¾ÆÀÌÅÛ ÀÎº¥Åä¸® È®Àå
      MouseX := DUserState1.Left + X;
      MouseY := DUserState1.Top  + Y;
   end;

end;

procedure TFrmDlg.DCloseUS1Click(Sender: TObject; X, Y: Integer);
begin
   DUserState1.Visible := FALSE;
end;

procedure TFrmDlg.DCloseUS1MouseMove(Sender: TObject; Shift: TShiftState; X,
  Y: Integer);
var
  lx, ly: integer;
  sx, sy: integer;
begin
  with DCloseUS1 do begin
    lx := LocalX(X - Left);
    ly := LocalY(Y - Top);
    sx := SurfaceX(Left) + DUserState1.SurfaceX(DUserState1.Left) + lx + 8;
    sy := SurfaceY(Top) + DUserState1.SurfaceX(DUserState1.Top) + ly + 6;
    DScreen.ShowHint(sx, sy, '¹Ø ±Õ', $393800, FALSE);
  end;
end;

procedure TFrmDlg.DNecklaceUS1DirectPaint(Sender: TObject;
  dsurface: TDirectDrawSurface);
var
   idx: integer;
   d: TDirectDrawSurface;
begin
   if Sender = DNecklaceUS1 then begin
      if UserState1.UseItems[U_NECKLACE].S.Name <> '' then begin
         idx := UserState1.UseItems[U_NECKLACE].S.Looks;
         if idx >= 0 then begin
            d := g_WInventory.Images[idx];
            if d <> nil then
               dsurface.Draw (DNecklaceUS1.SurfaceX(DNecklaceUS1.Left + (DNecklaceUS1.Width - d.Width) div 2),
                              DNecklaceUS1.SurfaceY(DNecklaceUS1.Top + (DNecklaceUS1.Height - d.Height) div 2),
                              d.ClientRect, d, TRUE);
         end;
      end;
   end;
   if Sender = DLightUS1 then begin
      if UserState1.UseItems[U_RIGHTHAND].S.Name <> '' then begin
         idx := UserState1.UseItems[U_RIGHTHAND].S.Looks;
         if idx >= 0 then begin
            d := g_WInventory.Images[idx];
            if d <> nil then
               dsurface.Draw (DLightUS1.SurfaceX(DLightUS1.Left + (DLightUS1.Width - d.Width) div 2),
                              DLightUS1.SurfaceY(DLightUS1.Top + (DLightUS1.Height - d.Height) div 2),
                              d.ClientRect, d, TRUE);
         end;
      end;
   end;
   if Sender = DArmRingRUS1 then begin
      if UserState1.UseItems[U_ARMRINGR].S.Name <> '' then begin
         idx := UserState1.UseItems[U_ARMRINGR].S.Looks;
         if idx >= 0 then begin
            d := g_WInventory.Images[idx];
            if d <> nil then
               dsurface.Draw (DArmRingRUS1.SurfaceX(DArmRingRUS1.Left + (DArmRingRUS1.Width - d.Width) div 2),
                              DArmRingRUS1.SurfaceY(DArmRingRUS1.Top + (DArmRingRUS1.Height - d.Height) div 2),
                              d.ClientRect, d, TRUE);
         end;
      end;
   end;
   if Sender = DArmRingLUS1 then begin
      if UserState1.UseItems[U_ARMRINGL].S.Name <> '' then begin
         idx := UserState1.UseItems[U_ARMRINGL].S.Looks;
         if idx >= 0 then begin
            d := g_WInventory.Images[idx];
            if d <> nil then
               dsurface.Draw (DArmRingLUS1.SurfaceX(DArmRingLUS1.Left + (DArmRingLUS1.Width - d.Width) div 2),
                              DArmRingLUS1.SurfaceY(DArmRingLUS1.Top + (DArmRingLUS1.Height - d.Height) div 2),
                              d.ClientRect, d, TRUE);
         end;
      end;
   end;
   if Sender = DRingRUS1 then begin
      if UserState1.UseItems[U_RINGR].S.Name <> '' then begin
         idx := UserState1.UseItems[U_RINGR].S.Looks;
         if idx >= 0 then begin
            d := g_WInventory.Images[idx];
            if d <> nil then
               dsurface.Draw (DRingRUS1.SurfaceX(DRingRUS1.Left + (DRingRUS1.Width - d.Width) div 2),
                              DRingRUS1.SurfaceY(DRingRUS1.Top + (DRingRUS1.Height - d.Height) div 2),
                              d.ClientRect, d, TRUE);
         end;
      end;
   end;
   if Sender = DRingLUS1 then begin
      if UserState1.UseItems[U_RINGL].S.Name <> '' then begin
         idx := UserState1.UseItems[U_RINGL].S.Looks;
         if idx >= 0 then begin
            d := g_WInventory.Images[idx];
            if d <> nil then
               dsurface.Draw (DRingLUS1.SurfaceX(DRingLUS1.Left + (DRingLUS1.Width - d.Width) div 2),
                              DRingLUS1.SurfaceY(DRingLUS1.Top + (DRingLUS1.Height - d.Height) div 2),
                              d.ClientRect, d, TRUE);
         end;
      end;
   end;
   // 2003/03/15 ¾ÆÀÌÅÛ ÀÎº¥Åä¸® È®Àå
   if Sender = DBujukUS1 then begin
      if UserState1.UseItems[U_BUJUK].S.Name <> '' then begin
         idx := UserState1.UseItems[U_BUJUK].S.Looks;
         if idx >= 0 then begin
            d := g_WInventory.Images[idx];
            if d <> nil then
               dsurface.Draw (DBujukUS1.SurfaceX(DBujukUS1.Left + (DBujukUS1.Width - d.Width) div 2),
                              DBujukUS1.SurfaceY(DBujukUS1.Top + (DBujukUS1.Height - d.Height) div 2),
                              d.ClientRect, d, TRUE);
         end;
      end;
   end;
   if Sender = DBeltUS1 then begin
      if UserState1.UseItems[U_BELT].S.Name <> '' then begin
         idx := UserState1.UseItems[U_BELT].S.Looks;
         if idx >= 0 then begin
            d := g_WInventory.Images[idx];
            if d <> nil then
               dsurface.Draw (DBeltUS1.SurfaceX(DBeltUS1.Left + (DBeltUS1.Width - d.Width) div 2),
                              DBeltUS1.SurfaceY(DBeltUS1.Top + (DBeltUS1.Height - d.Height) div 2),
                              d.ClientRect, d, TRUE);
         end;
      end;
   end;
   if Sender = DBootsUS1 then begin
      if UserState1.UseItems[U_BOOTS].S.Name <> '' then begin
         idx := UserState1.UseItems[U_BOOTS].S.Looks;
         if idx >= 0 then begin
            d := g_WInventory.Images[idx];
            if d <> nil then
               dsurface.Draw (DBootsUS1.SurfaceX(DBootsUS1.Left + (DBootsUS1.Width - d.Width) div 2),
                              DBootsUS1.SurfaceY(DBootsUS1.Top + (DBootsUS1.Height - d.Height) div 2),
                              d.ClientRect, d, TRUE);
         end;
      end;
   end;
   if Sender = DCharmUS1 then begin
      if UserState1.UseItems[U_CHARM].S.Name <> '' then begin
         idx := UserState1.UseItems[U_CHARM].S.Looks;
         if idx >= 0 then begin
            d := g_WInventory.Images[idx];
            if d <> nil then
               dsurface.Draw (DCharmUS1.SurfaceX(DCharmUS1.Left + (DCharmUS1.Width - d.Width) div 2),
                              DCharmUS1.SurfaceY(DCharmUS1.Top + (DCharmUS1.Height - d.Height) div 2),
                              d.ClientRect, d, TRUE);
         end;
      end;
   end;

end;


procedure TFrmDlg.ShowGuildDlg;
begin
   DGuildDlg.Visible := TRUE;  //not DGuildDlg.Visible;
   DGuildDlg.Top := -3;
   DGuildDlg.Left := 0;
   if DGuildDlg.Visible then begin
      if GuildCommanderMode then begin
         DGDAddMem.Visible := TRUE;
         DGDDelMem.Visible := TRUE;
         DGDEditNotice.Visible := TRUE;
         DGDEditGrade.Visible := TRUE;
         DGDAlly.Visible := TRUE;
         DGDBreakAlly.Visible := TRUE;
         DGDWar.Visible := TRUE;
         DGDCancelWar.Visible := TRUE;
      end else begin
         DGDAddMem.Visible := FALSE;
         DGDDelMem.Visible := FALSE;
         DGDEditNotice.Visible := FALSE;
         DGDEditGrade.Visible := FALSE;
         DGDAlly.Visible := FALSE;
         DGDBreakAlly.Visible := FALSE;
         DGDWar.Visible := FALSE;
         DGDCancelWar.Visible := FALSE;
      end;

   end;
   GuildTopLine := 0;
end;

procedure TFrmDlg.ShowGuildEditNotice;
var
   d: TDirectDrawSurface;
   i: integer;
   data: string;
begin
   with DGuildEditNotice do begin
      d := WLib.Images[FaceIndex];
      if d <> nil then begin
         Left := (SCREENWIDTH - d.Width) div 2;
         Top := (SCREENHEIGHT - d.Height) div 2;
      end;
      HideAllControls;
      DGuildEditNotice.ShowModal;

      Memo.Left := SurfaceX(Left+29);
      Memo.Top  := SurfaceY(Top+61);
      Memo.Width := 569;
      Memo.Height := 242;
      Memo.Lines.Assign (GuildNotice);
      Memo.ReadOnly := False;
      Memo.Visible := TRUE;

      while TRUE do begin
         if not DGuildEditNotice.Visible then break;
//         FrmMain.ProcOnIdle;
         Application.ProcessMessages;
         if Application.Terminated then exit;
      end;

      DGuildEditNotice.Visible := FALSE;
      RestoreHideControls;

      if DMsgDlg.DialogResult = mrOk then begin
         //°á°ú... ¹®ÆÄ°øÁö»çÇ×À» ¾÷µ¥ÀÌÆ® ÇÑ´Ù.
         data := '';
         for i:=0 to Memo.Lines.Count-1 do begin
            if Memo.Lines[i] = '' then
               data := data + Memo.Lines[i] + ' '#13
            else data := data + Memo.Lines[i] + #13;
         end;
         if Length(data) > 4000 then begin
            data := Copy (data, 1, 4000);
            DMessageDlg ('¹®ÀÚ¿­ÀÌ ³Ê¹« ±æ¾î¼­ µÚ¿¡ ºÎºÐÀÌ Â©·È½À´Ï´Ù.', [mbOk]);
         end;
         FrmMain.SendGuildUpdateNotice (data);
      end;
   end;
end;

procedure TFrmDlg.ShowGuildEditGrade;
var
   d: TDirectDrawSurface;
   data: string;
   i: integer;
begin
   if GuildMembers.Count <= 0 then begin
      DMessageDlg ('¹®¿ø Á¤º¸ ºÒ·¯¿À±â(LIST)¹öÆ°À» ¸ÕÀú ´©¸£½Ê½Ã¿À.', [mbOk]);
      exit;
   end;

   with DGuildEditNotice do begin
      d := WLib.Images[FaceIndex];
      if d <> nil then begin
         Left := (SCREENWIDTH - d.Width) div 2;
         Top := (SCREENHEIGHT - d.Height) div 2;
      end;
      HideAllControls;
      DGuildEditNotice.ShowModal;

      Memo.Left := SurfaceX(Left+29);
      Memo.Top  := SurfaceY(Top+61);
      Memo.Width := 569;
      Memo.Height := 242;
      Memo.Lines.Assign (GuildMembers);
      Memo.Visible := TRUE;

      while TRUE do begin
         if not DGuildEditNotice.Visible then break;
//         FrmMain.ProcOnIdle;
         Application.ProcessMessages;
         if Application.Terminated then exit;
      end;

      DGuildEditNotice.Visible := FALSE;
      RestoreHideControls;

      if DMsgDlg.DialogResult = mrOk then begin
         //GuildMembers.Assign (Memo.Lines);
         //°á°ú... ¹®ÆÄµî±ÞÀ» ¾÷µ¥ÀÌÆ® ÇÑ´Ù.
         data := '';
         for i:=0 to Memo.Lines.Count-1 do begin
            data := data + Memo.Lines[i] + #13;  //¼­¹ö¿¡¼­ ÆÄ½ÌÇÔ.
         end;
         if Length(data) > 5000 then begin
            data := Copy (data, 1, 5000);
            DMessageDlg ('¹®ÀÚ¿­ÀÌ ³Ê¹« ±æ¾î¼­ µÚ¿¡ ºÎºÐÀÌ Â©·È½À´Ï´Ù.', [mbOk]);
         end;
         FrmMain.SendGuildUpdateGrade (data);
      end;
   end;
end;

procedure TFrmDlg.DGuildDlgDirectPaint(Sender: TObject;
  dsurface: TDirectDrawSurface);
var
  d: TDirectDrawSurface;
  i, n, bx, by: integer;
  FColor: TColor;
begin
   with DGuildDlg do begin
      d := WLib.Images[FaceIndex];
      if d <> nil then
         dsurface.Draw (SurfaceX(Left), SurfaceY(Top), d.ClientRect, d, TRUE);

      with g_DXCanvas do begin
         FColor := clWhite;
         TextOut (Left+322, Top+38, clWhite, Guild);

         bx := Left + 33;
         by := Top + 66;
         for i:=GuildTopLine to GuildStrs.Count-1 do begin
            n := i-GuildTopLine;
//            if n*14 > 356 then break;
            if n*14 > 328 then break;
            if Integer(GuildStrs.Objects[i]) <> 0 then FColor := TColor(GuildStrs.Objects[i])
            else begin
               if BoGuildChat then FColor := GetRGB (2)
               else FColor := clSilver;
            end;
            TextOut (bx, by + n*14, FColor, GuildStrs[i]);
         end;
      end;

   end;
end;

procedure TFrmDlg.DGDUpClick(Sender: TObject; X, Y: Integer);
begin
   if GuildTopLine > 0 then Dec (GuildTopLine, 3);
   if GuildTopLine < 0 then GuildTopLine := 0;
end;

procedure TFrmDlg.DGDDownClick(Sender: TObject; X, Y: Integer);
begin
   if GuildTopLine+12 < GuildStrs.Count then Inc (GuildTopLine, 3);
end;

procedure TFrmDlg.DGDCloseClick(Sender: TObject; X, Y: Integer);
begin
   DGuildDlg.Visible := FALSE;
   BoGuildChat := FALSE;
end;

procedure TFrmDlg.DGDHomeClick(Sender: TObject; X, Y: Integer);
begin
   if GetTickCount > querymsgtime then begin
      querymsgtime := GetTickCount + 3000;
      FrmMain.SendGuildHome;
      BoGuildChat := FALSE;
   end;
end;

procedure TFrmDlg.DGDListClick(Sender: TObject; X, Y: Integer);
begin
   if GetTickCount > querymsgtime then begin
      querymsgtime := GetTickCount + 3000;
      FrmMain.SendGuildMemberList;
      BoGuildChat := FALSE;
   end;
end;

procedure TFrmDlg.DGDAddMemClick(Sender: TObject; X, Y: Integer);
begin
   DMessageDlg (Guild + 'ÀÇ ¹®¿øÀ¸·Î Ãß°¡ÇÒ »ç¶÷ÀÇ ÀÌ¸§À» ÀÔ·ÂÇÏ½Ê½Ã¿À', [mbOk, mbAbort]);
   if DlgEditText <> '' then
      FrmMain.SendGuildAddMem (DlgEditText);
end;

procedure TFrmDlg.DGDDelMemClick(Sender: TObject; X, Y: Integer);
begin
   DMessageDlg (Guild + 'ÀÇ ¹®¿ø¿¡¼­ »èÁ¦ÇÒ »ç¶÷ÀÇ ÀÌ¸§À» ÀÔ·ÂÇÏ½Ê½Ã¿À', [mbOk, mbAbort]);
   if DlgEditText <> '' then
      FrmMain.SendGuildDelMem (DlgEditText);
end;

procedure TFrmDlg.DGDEditNoticeClick(Sender: TObject; X, Y: Integer);
begin
   GuildEditHint := '[¹®ÆÄÀÇ °øÁö»çÇ×À» ¼öÁ¤ÇÕ´Ï´Ù.]';
   ShowGuildEditNotice;
end;

procedure TFrmDlg.DGDEditGradeClick(Sender: TObject; X, Y: Integer);
begin
   GuildEditHint := '[¹®¿øÀÇ ¼­¿­°ú Á÷Ã¥ ÀÌ¸§À» ¼öÁ¤ÇÕ´Ï´Ù. #ÁÖÀÇ: ¹®¿ø Ãß°¡/»èÁ¦ ¾ÈµÊ]';
   ShowGuildEditGrade;
end;

procedure TFrmDlg.DGDAllyClick(Sender: TObject; X, Y: Integer);
begin
   if mrOk = DMessageDlg ('µ¿¸ÍÀ» ÇÏ±â À§ÇØ¼­´Â »ó´ë¹æ ¹®ÆÄ°¡ [µ¿¸Í°¡´É] »óÅÂ ÀÌ¾î¾ß ÇÏ¸ç\' +
                  '»ó´ë ¹®ÁÖ¿Í ¸¶ÁÖº¸°í ÀÖ¾î¾ß ÇÕ´Ï´Ù.\' +
                  'µ¿¸ÍÀ» ÇÏ½Ã°Ú½À´Ï±î?', [mbOk, mbCancel])
   then
      FrmMain.SendSay ('@µ¿¸Í');
end;

procedure TFrmDlg.DGDBreakAllyClick(Sender: TObject; X, Y: Integer);
begin
   DMessageDlg ('µ¿¸ÍÀ» ÆÄ±âÇÒ ¹®ÆÄÀÇ ÀÌ¸§À» ÀÔ·ÂÇÏ½Ê½Ã¿À.', [mbOk, mbAbort]);
   if DlgEditText <> '' then
      FrmMain.SendSay ('@µ¿¸ÍÆÄ±â ' + DlgEditText);
end;



procedure TFrmDlg.DGuildEditNoticeDirectPaint(Sender: TObject;
  dsurface: TDirectDrawSurface);
var
   d: TDirectDrawSurface;
begin
   with DGuildEditNotice do begin
      d := WLib.Images[FaceIndex];
      if d <> nil then
         dsurface.Draw (SurfaceX(Left), SurfaceY(Top), d.ClientRect, d, TRUE);

      with g_DXCanvas do begin
         TextOut (Left+42, Top+314, clSilver, GuildEditHint);
      end;
   end;
end;

procedure TFrmDlg.DGECloseClick(Sender: TObject; X, Y: Integer);
begin
   DGuildEditNotice.Visible := FALSE;
   Memo.Visible := FALSE;
   DMsgDlg.DialogResult := mrCancel;
end;

procedure TFrmDlg.DGEOkClick(Sender: TObject; X, Y: Integer);
begin
   DGECloseClick (self, 0, 0);
   DMsgDlg.DialogResult := mrOk;
end;

procedure TFrmDlg.AddGuildChat (str: string);
var
   i: integer;
begin
   GuildChats.Add (str);
   if GuildChats.Count > 500 then begin
      for i:=0 to 100 do GuildChats.Delete(0);
   end;
   if BoGuildChat then
      GuildStrs.Assign (GuildChats);
end;

procedure TFrmDlg.DGDChatClick(Sender: TObject; X, Y: Integer);
begin
   BoGuildChat := not BoGuildChat;
   if BoGuildChat then begin
      GuildStrs2.Assign (GuildStrs);
      GuildStrs.Assign (GuildChats);
   end else
      GuildStrs.Assign (GuildStrs2);
end;

procedure TFrmDlg.DGoldDirectPaint(Sender: TObject;
  dsurface: TDirectDrawSurface);
begin

end;




{--------------------------------------------------------------}
//´É·ÂÄ¡ Á¶Á¤ Ã¢

procedure TFrmDlg.DAdjustAbilCloseClick(Sender: TObject; X, Y: Integer);
begin
   DAdjustAbility.Visible := FALSE;
   BonusPoint := SaveBonusPoint;
end;

procedure TFrmDlg.DAdjustAbilityDirectPaint(Sender: TObject;
  dsurface: TDirectDrawSurface);
   procedure AdjustAb (abil: byte; val: word; var lov, hiv: byte);
   var
      lo, hi: byte;
      i: integer;
   begin
      lo := Lobyte(abil);
      hi := Hibyte(abil);
      lov := 0; hiv := 0;
      for i:=1 to val do begin
         if lo+1 < hi then begin Inc(lo); Inc(lov);
         end else begin Inc(hi); Inc(hiv); end;
      end;
   end;
var
   d: TDirectDrawSurface;
   l, m, adc, amc, asc, aac, amac: integer;
   ldc, lmc, lsc, lac, lmac, hdc, hmc, hsc, hac, hmac: byte;
   FColor: TColor;
begin
   if Myself = nil then exit;
   with g_DXCanvas do begin
      with DAdjustAbility do begin
         d := DMenuDlg.WLib.Images[FaceIndex];
         if d <> nil then
            dsurface.Draw (SurfaceX(Left), SurfaceY(Top), d.ClientRect, d, TRUE);
      end;

      FColor := clSilver;

      l := DAdjustAbility.SurfaceX(DAdjustAbility.Left) + 36;
      m := DAdjustAbility.SurfaceY(DAdjustAbility.Top) + 22;

      TextOut (l, m,      FColor, 'ÃàÇÏÇÕ´Ï´Ù. ´ç½ÅÀÇ ·¹º§ÀÌ ¿Ã¶ú±º¿ä.');
      TextOut (l, m+14,   FColor, '¾Æ·¡ÀÇ ´É·Â Áß¿¡¼­ ¿øÇÏ´Â ´É·ÂÀ» ¿Ã¸®½Ã±â');
      TextOut (l, m+14*2, FColor, '¹Ù¶ø´Ï´Ù. ¼±ÅÃÀº ¿ÀÁ÷ ÇÑ¹ø »ÓÀÌ¹Ç·Î ½ÅÁß');
      TextOut (l, m+14*3, FColor, 'ÇÏ°Ô ¼±ÅÃÇÏ½Ã±â ¹Ù¶ø´Ï´Ù.');

      FColor := clWhite;
      //ÇöÀçÀÇ ´É·ÂÄ¡
      l := DAdjustAbility.SurfaceX(DAdjustAbility.Left) + 100; //66;
      m := DAdjustAbility.SurfaceY(DAdjustAbility.Top) + 101;

      adc := (BonusAbil.DC + BonusAbilChg.DC) div BonusTick.DC;
      amc := (BonusAbil.MC + BonusAbilChg.MC) div BonusTick.MC;
      asc := (BonusAbil.SC + BonusAbilChg.SC) div BonusTick.SC;
      aac := (BonusAbil.AC + BonusAbilChg.AC) div BonusTick.AC;
      amac := (BonusAbil.MAC + BonusAbilChg.MAC) div BonusTick.MAC;

      AdjustAb (NakedAbil.DC, adc, ldc, hdc);
      AdjustAb (NakedAbil.MC, amc, lmc, hmc);
      AdjustAb (NakedAbil.SC, asc, lsc, hsc);
      //AdjustAb (NakedAbil.AC, aac, lac, hac);
      //AdjustAb (NakedAbil.MAC, amac, lmac, hmac);
      lac  := 0;  hac := aac;
      lmac := 0;  hmac := amac;

      TextOut (l+0, m+0, FColor, IntToStr(Lobyte(Myself.Abil.DC)+ldc) + '-' + IntToStr(Hibyte(Myself.Abil.DC) + hdc));
      TextOut (l+0, m+20, FColor, IntToStr(Lobyte(Myself.Abil.MC)+lmc) + '-' + IntToStr(Hibyte(Myself.Abil.MC) + hmc));
      TextOut (l+0, m+40, FColor, IntToStr(Lobyte(Myself.Abil.SC)+lsc) + '-' + IntToStr(Hibyte(Myself.Abil.SC) + hsc));
      TextOut (l+0, m+60, FColor, IntToStr(Lobyte(Myself.Abil.AC)+lac) + '-' + IntToStr(Hibyte(Myself.Abil.AC) + hac));
      TextOut (l+0, m+80, FColor, IntToStr(Lobyte(Myself.Abil.MAC)+lmac) + '-' + IntToStr(Hibyte(Myself.Abil.MAC) + hmac));
      TextOut (l+0, m+100, FColor, IntToStr(Myself.Abil.MaxHP + (BonusAbil.HP + BonusAbilChg.HP) div BonusTick.HP));
      TextOut (l+0, m+120, FColor, IntToStr(Myself.Abil.MaxMP + (BonusAbil.MP + BonusAbilChg.MP) div BonusTick.MP));
      TextOut (l+0, m+140, FColor, IntToStr(MyHitPoint + (BonusAbil.Hit + BonusAbilChg.Hit) div BonusTick.Hit));
      TextOut (l+0, m+160, FColor, IntToStr(MySpeedPoint + (BonusAbil.Speed + BonusAbilChg.Speed) div BonusTick.Speed));

      FColor := clYellow;
      TextOut (l+0, m+180, FColor, IntToStr(BonusPoint));

      FColor := clWhite;
      l := DAdjustAbility.SurfaceX(DAdjustAbility.Left) + 155; //66;
      m := DAdjustAbility.SurfaceY(DAdjustAbility.Top) + 101;

      if BonusAbilChg.DC > 0 then FColor := clWhite
      else FColor := clSilver;
      TextOut (l+0, m+0, FColor, IntToStr(BonusAbilChg.DC + BonusAbil.DC) + '/' + IntToStr(BonusTick.DC));

      if BonusAbilChg.MC > 0 then FColor := clWhite
      else FColor := clSilver;
      TextOut (l+0, m+20, FColor, IntToStr(BonusAbilChg.MC + BonusAbil.MC) + '/' + IntToStr(BonusTick.MC));

      if BonusAbilChg.SC > 0 then FColor := clWhite
      else FColor := clSilver;
      TextOut (l+0, m+40, FColor, IntToStr(BonusAbilChg.SC + BonusAbil.SC) + '/' + IntToStr(BonusTick.SC));

      if BonusAbilChg.AC > 0 then FColor := clWhite
      else FColor := clSilver;
      TextOut (l+0, m+60, FColor, IntToStr(BonusAbilChg.AC + BonusAbil.AC) + '/' + IntToStr(BonusTick.AC));

      if BonusAbilChg.MAC > 0 then FColor := clWhite
      else FColor := clSilver;
      TextOut (l+0, m+80, FColor, IntToStr(BonusAbilChg.MAC + BonusAbil.MAC) + '/' + IntToStr(BonusTick.MAC));

      if BonusAbilChg.HP > 0 then FColor := clWhite
      else FColor := clSilver;
      TextOut (l+0, m+100, FColor, IntToStr(BonusAbilChg.HP + BonusAbil.HP) + '/' + IntToStr(BonusTick.HP));

      if BonusAbilChg.MP > 0 then FColor := clWhite
      else FColor := clSilver;
      TextOut (l+0, m+120, FColor, IntToStr(BonusAbilChg.MP + BonusAbil.MP) + '/' + IntToStr(BonusTick.MP));

      if BonusAbilChg.Hit > 0 then FColor := clWhite
      else FColor := clSilver;
      TextOut (l+0, m+140, FColor, IntToStr(BonusAbilChg.Hit + BonusAbil.Hit) + '/' + IntToStr(BonusTick.Hit));

      if BonusAbilChg.Speed > 0 then FColor := clWhite
      else FColor := clSilver;
      TextOut (l+0, m+160, FColor, IntToStr(BonusAbilChg.Speed + BonusAbil.Speed) + '/' + IntToStr(BonusTick.Speed));
   end;

end;

procedure TFrmDlg.DPlusDCClick(Sender: TObject; X, Y: Integer);
var
   incp: integer;
begin
   if BonusPoint > 0 then begin
      if IsKeyPressed (VK_CONTROL) and (BonusPoint > 10) then incp := 10
      else incp := 1;
      Dec(BonusPoint, incp);
      if Sender = DPlusDC then Inc (BonusAbilChg.DC, incp);
      if Sender = DPlusMC then Inc (BonusAbilChg.MC, incp);
      if Sender = DPlusSC then Inc (BonusAbilChg.SC, incp);
      if Sender = DPlusAC then Inc (BonusAbilChg.AC, incp);
      if Sender = DPlusMAC then Inc (BonusAbilChg.MAC, incp);
      if Sender = DPlusHP then Inc (BonusAbilChg.HP, incp);
      if Sender = DPlusMP then Inc (BonusAbilChg.MP, incp);
      if Sender = DPlusHit then Inc (BonusAbilChg.Hit, incp);
      if Sender = DPlusSpeed then Inc (BonusAbilChg.Speed, incp);
   end;
end;

procedure TFrmDlg.DMiniMapBlendClick(Sender: TObject; X, Y: Integer);
begin
  if DMiniMapDlg.Visible then ViewMiniMapBlend := not ViewMiniMapBlend;
end;

procedure TFrmDlg.DMiniMapBlendDirectPaint(Sender: TObject;
  dsurface: TDirectDrawSurface);
var
  d: TDirectDrawSurface;
begin
  with Sender as TDButton do begin
    if ViewMiniMapBlend then
      d := WLib.Images[FaceIndex]
    else
      d := WLib.Images[FaceIndex + 1];
    if d <> nil then
      dsurface.Draw(SurfaceX(Left), SurfaceY(Top), d.ClientRect, d, TRUE);
  end;
end;

procedure TFrmDlg.DMiniMapBlendMouseMove(Sender: TObject; Shift: TShiftState; X,
  Y: Integer);
var
  lx, ly: integer;
  sx, sy: integer;
  str: string;
begin
  with DMiniMapBlend do begin
    lx := LocalX(X - Left);
    ly := LocalY(Y - Top);
    sx := SurfaceX(Left) + DMiniMapDlg.SurfaceX(DMiniMapDlg.Left) + lx + 8;
    sy := SurfaceY(Top) + DMiniMapDlg.SurfaceX(DMiniMapDlg.Top) + ly + 6;
    if ViewMiniMapBlend then str := '²»Í¸Ã÷'
    else str := 'Í¸Ã÷';
    DScreen.ShowHint(sx, sy, str, $393800, True);
  end;
end;

procedure TFrmDlg.DMiniMapDlgDirectPaint(Sender: TObject;
  dsurface: TDirectDrawSurface);
var
  d: TDirectDrawSurface;
  v: Boolean;
  i, k, cl, ix, mx, my, NearLoverCount, spot: integer;
  rc, rc2: TRect;
  actor: TActor;
  nRealWidth, nRealHeight, nSize, nShowWidthSize, nShowHeightSize: integer;
  DrawZoom: Boolean;
begin
  DrawZoom := False;
  if GetTickCount > MiniMapBlinkTime + 300 then begin
    MiniMapBlinkTime := GetTickCount;
    MiniMapViewBlink := not MiniMapViewBlink;
  end;

  if MiniMapIndex >= 1000 then d := g_WFMMap.Images[MiniMapIndex-1000]
  else d := g_WMMap.Images[MiniMapIndex];


  if d <> nil then begin
    case ViewMiniMapStyle of
      0:begin
        nSize:= 128;
      end;
      1:begin
        nSize:= 256;
      end;
    end;
    mx := (MySelf.XX * 48) div 32;
    my := (MySelf.YY * 32) div 32;
    rc.Left := _MAX(0, mx - (nSize div 2));
    rc.Top := _MAX(0, my - (nSize div 2));
    rc.Right := _MIN(d.ClientRect.Right, rc.Left + nSize);
    rc.Bottom := _MIN(d.ClientRect.Bottom, rc.Top + nSize);

    if (d.Width > nSize) and ((rc.Right - rc.Left) < nSize) then rc.Left := rc.Right - nSize;
    if (d.Height > nSize) and ((rc.Bottom - rc.Top) < nSize) then rc.Top := rc.Bottom - nSize;

    nShowWidthSize := nSize;
    nShowHeightSize := nSize;

    if (d.Width < nSize) or (d.Height < nSize) then begin
      if (d.Width < nSize) then begin
        rc.Left := 0;
        rc.Right := rc.Left + d.Width;
        nShowWidthSize := d.Width;
      end;
      if (d.Height < nSize) then begin
        rc.Top := 0;
        rc.Bottom := rc.Top + d.Height;
        nShowHeightSize := d.Height;
      end;
      DrawZoom := True;
    end;

    if ViewMiniMapBlend then
      DrawBlendR (dsurface, (SCREENWIDTH-nShowWidthSize), 0, rc, d, 0)
    else
      dsurface.Draw ((SCREENWIDTH-nShowWidthSize), 0, rc, d, false);

    ix := (SCREENWIDTH-nShowWidthSize) - rc.Left;

    NearLoverCount := 0;
    with PlayScene do begin
      if ActorList.Count > 0 then begin
        for i:=0 to ActorList.Count-1 do begin
          mx := ix + (TActor(ActorList[i]).XX*48) div 32;
          my := (TActor(ActorList[i]).YY*32) div 32 - rc.Top;
          cl := 0;
          spot := 3;
          case TActor(ActorList[i]).Race of
            RC_USERHUMAN: if TActor(ActorList[i]) = Myself then begin
                            if MiniMapViewBlink then cl := $FF00FF00
                            else cl := 0;
                            if ViewMiniMapStyle = 0 then spot := 4
                            else spot := 5;
                          end else if (nil <> fLover) and  (Length( Trim(TActor(ActorList[i]).UserName)) > 0) and
                            ( TActor(ActorList[i]).UserName = Copy(fLover.GetDisplay(0), length(STR_LOVER)+1, 20) ) and
                            (Not TActor(ActorList[i]).BoOpenHealth) then begin
                            cl := 253;
                            if (mx > 680) and (my < 119) then Inc(NearLoverCount);
                          end
                          else cl := $FFFFFFFF;

//            RCC_GUARD,
//            RCC_GUARD2,
            RCC_MERCHANT:                cl := $FFFFFF00;
            54, 55:                      cl := 0;
            98, 99:                      cl := 0;
            else if ( (TActor(ActorList[i]).Visible) and (not TActor(ActorList[i]).Death) and (pos('(', TActor(ActorList[i]).UserName) = 0)) then cl := $FFFF0000;
          end;

          rc2.Left := mx - (spot div 2);
          rc2.Top := my - (spot div 2);
          rc2.Right := rc2.Left + spot;
          rc2.Bottom := rc2.Top + spot;

          if (mx > (SCREENWIDTH-nShowWidthSize)) and (my < nShowHeightSize) then begin //@@@@old
            if cl <> 0 then begin
//              g_DXCanvas.FillRect(mx-2, my-2,3, 3, cl);
              g_DXCanvas.Draw2DRectLine(rc2, cl);
            end;
          end;
        end;
      end;

      if NearLoverCount > 0 then CouplePower := True
      else CouplePower := False;

      if ViewListCount > 0 then begin
        for i:=1 to ViewListCount do begin
          if ((Abs(ViewList[i].X - MySelf.XX) < 40) and (Abs(ViewList[i].Y - MySelf.YY) < 40)) then begin
            mx := ix + (ViewList[i].X * 48) div 32;
            my := (ViewList[i].Y * 32) div 32 - rc.Top;
            if (mx > (SCREENWIDTH - nShowWidthSize)) and (my < nShowHeightSize)
              then begin //@@@@old
              cl := $FFFF0000;
              g_DXCanvas.FillRect(mx - 2, my - 2, 3, 3, cl);
            end;
          end;
          if (((GetTickCount - ViewList[i].LastTick) > 5000) and (ViewList[i].Index > 0)) then begin
            actor := FindActor(ViewList[i].Index);
            if actor <> nil then begin
              actor.BoOpenHealth := False;
              if GroupIdList.Count > 0 then begin
                for k := 0 to GroupIdList.Count - 1 do begin
                  if Integer(GroupIdList[k]) = actor.RecogId then begin
                    GroupIdList.Delete(k);
                    Break;
                  end;
                end;
              end;
            end;
            if (ViewListCount > 0) then begin
              ViewList[i].Index := ViewList[ViewListCount].Index;
              ViewList[i].X := ViewList[ViewListCount].X;
              ViewList[i].Y := ViewList[ViewListCount].Y;
              ViewList[i].LastTick := ViewList[ViewListCount].LastTick;
              ViewList[ViewListCount].Index := 0;
              ViewList[ViewListCount].X := 0;
              ViewList[ViewListCount].Y := 0;
              ViewList[ViewListCount].LastTick := 0;
            end;
            Dec(ViewListCount);
          end;
        end;
      end;
    end;
    with DMiniMapDlg do begin
      Left := (SCREENWIDTH - nShowWidthSize);
      if not DrawZoom then begin
        if ViewMiniMapStyle = 1 then begin
          DMiniMapShow.Left := 237;
          DMiniMapShow.Top := 237;
          DMiniMapBlend.Left := 218;
          DMiniMapBlend.Top := 237;
          DMiniMapDlg.SetImgIndex(g_WGameInter, 1480);
        end else begin
          DMiniMapShow.Left := 109;
          DMiniMapShow.Top := 109;
          DMiniMapBlend.Left := 90;
          DMiniMapBlend.Top := 109;
          DMiniMapDlg.SetImgIndex(g_WGameInter, 1481);
        end;

        d := WLib.Images[FaceIndex];
        if d <> nil then begin
          Left := (SCREENWIDTH - d.Width);
          dsurface.Draw (SurfaceX(Left), SurfaceY(Top), d.ClientRect, d, TRUE);
        end;
      end else begin
        g_DXCanvas.RoundRect(SCREENWIDTH - nShowWidthSize + 1, SurfaceY(Top), SCREENWIDTH, rc.Bottom, $FFA0A8A0);
        DMiniMapShow.Left := nShowWidthSize - 19;
        DMiniMapShow.Top := rc.Bottom - 19;
        DMiniMapBlend.Left := nShowWidthSize - 38;
        DMiniMapBlend.Top := rc.Bottom - 19;
        d := WLIB.Images[1486];
          dsurface.Draw ((SCREENWIDTH - nShowWidthSize), SurfaceY(Top), d.ClientRect, d, TRUE);
        d := WLIB.Images[1487];
          dsurface.Draw ((SCREENWIDTH - d.Width), SurfaceY(Top), d.ClientRect, d, TRUE);
        d := WLIB.Images[1488];
          dsurface.Draw ((SCREENWIDTH - nShowWidthSize), nShowHeightSize - d.Height + 1, d.ClientRect, d, TRUE);
      end;
    end;
  end;
end;

procedure TFrmDlg.DMiniMapShowClick(Sender: TObject; X, Y: Integer);
begin
  if DMiniMapDlg.Visible then begin
    Inc(ViewMiniMapStyle);
    if ViewMiniMapStyle > 1 then ViewMiniMapStyle := 0;
  end;
end;

procedure TFrmDlg.DMiniMapShowDirectPaint(Sender: TObject;
  dsurface: TDirectDrawSurface);
var
  d: TDirectDrawSurface;
begin
  with Sender as TDButton do begin
    if ViewMiniMapStyle = 0 then
      d := WLib.Images[FaceIndex]
    else
      d := WLib.Images[FaceIndex + 1];
    if d <> nil then
      dsurface.Draw(SurfaceX(Left), SurfaceY(Top), d.ClientRect, d, TRUE);
  end;
end;

procedure TFrmDlg.DMiniMapShowMouseMove(Sender: TObject; Shift: TShiftState; X,
  Y: Integer);
var
  lx, ly: integer;
  sx, sy: integer;
  str: string;
begin
  with DMiniMapShow do begin
    lx := LocalX(X - Left);
    ly := LocalY(Y - Top);
    sx := SurfaceX(Left) + DMiniMapDlg.SurfaceX(DMiniMapDlg.Left) + lx + 8;
    sy := SurfaceY(Top) + DMiniMapDlg.SurfaceX(DMiniMapDlg.Top) + ly + 6;
    if ViewMiniMapStyle = 0 then str := '·Å´ó'
    else str := 'ËõÐ¡';
    DScreen.ShowHint(sx, sy, str, $393800, True);
  end;
end;

procedure TFrmDlg.DMinusDCClick(Sender: TObject; X, Y: Integer);
var
   decp: integer;
begin
   if IsKeyPressed (VK_CONTROL) and (BonusPoint-10 > 0) then decp := 10
   else decp := 1;
   if Sender = DMinusDC then
      if BonusAbilChg.DC >= decp then begin
         Dec(BonusAbilChg.DC, decp);
         Inc (BonusPoint, decp);
      end;
   if Sender = DMinusMC then
      if BonusAbilChg.MC >= decp then begin
         Dec(BonusAbilChg.MC, decp);
         Inc (BonusPoint, decp);
      end;
   if Sender = DMinusSC then
      if BonusAbilChg.SC >= decp then begin
         Dec(BonusAbilChg.SC, decp);
         Inc (BonusPoint, decp);
      end;
   if Sender = DMinusAC then
      if BonusAbilChg.AC >= decp then begin
         Dec(BonusAbilChg.AC, decp);
         Inc (BonusPoint, decp);
      end;
   if Sender = DMinusMAC then
      if BonusAbilChg.MAC >= decp then begin
         Dec(BonusAbilChg.MAC, decp);
         Inc (BonusPoint, decp);
      end;
   if Sender = DMinusHP then
      if BonusAbilChg.HP >= decp then begin
         Dec(BonusAbilChg.HP, decp);
         Inc (BonusPoint, decp);
      end;
   if Sender = DMinusMP then
      if BonusAbilChg.MP >= decp then begin
         Dec(BonusAbilChg.MP, decp);
         Inc (BonusPoint, decp);
      end;
   if Sender = DMinusHit then
      if BonusAbilChg.Hit >= decp then begin
         Dec(BonusAbilChg.Hit, decp);
         Inc (BonusPoint, decp);
      end;
   if Sender = DMinusSpeed then
      if BonusAbilChg.Speed >= decp then begin
         Dec(BonusAbilChg.Speed, decp);
         Inc (BonusPoint, decp);
      end;
end;

procedure TFrmDlg.DAdjustAbilOkClick(Sender: TObject; X, Y: Integer);
begin
   FrmMain.SendAdjustBonus (BonusPoint, BonusAbilChg);
   DAdjustAbility.Visible := FALSE;
end;

procedure TFrmDlg.DAdjustAbilityMouseMove(Sender: TObject;
  Shift: TShiftState; X, Y: Integer);
var
   i, lx, ly: integer;
   flag: Boolean;
begin
   with DAdjustAbility do begin
      lx := LocalX (X - Left);
      ly := LocalY (Y - Top);
      flag := FALSE;
      if (lx >= 50) and (lx < 150) then
         for i:=0 to 8 do begin  //DC,MC,SC..ÀÇ ÈùÆ®°¡ ³ª¿À°Ô ÇÑ´Ù.
            if (ly >= 98 + i*20) and (ly < 98 + (i+1)*20) then begin
               DScreen.ShowHint (SurfaceX(Left) + lx + 10,
                                 SurfaceY(Top) + ly + 5,
                                 AdjustAbilHints[i],
                                 clWhite,
                                 FALSE);
               flag := TRUE;
               break;
            end;
         end;
      if not flag then
         DScreen.ClearHint;
   end;
end;

procedure TFrmDlg.DSServer1DirectPaint(Sender: TObject;
  dsurface: TDirectDrawSurface);
var
   d: TDirectDrawSurface;
   oldsize, down: integer;
begin
   with Sender as TDButton do begin
//      if not Downed then begin
//         d := WLib.Images[FaceIndex];
//         down := 0;
//      end else begin
//         d := WLib.Images[FaceIndex+1];
//         down := 1;
//      end;
//      if d <> nil then
//         dsurface.Draw (SurfaceX(Left), SurfaceY(Top), d.ClientRect, d, TRUE);


//      SetBkMode (dsurface.Canvas.Handle, TRANSPARENT);
//      oldsize := dsurface.Canvas.Font.Size;
//      dsurface.Canvas.Font.Size := 12;
//      dsurface.Canvas.Font.Style := [fsBold];
//      with g_DXCanvas do begin
//         TextOutEx(
//                   SurfaceX(Left) + (TDButton(Sender).Width - g_DXCanvas.TextWidth(TDButton(Sender).Caption)) div 2 + down,
////                   SurfaceY(Top) + (TDButton(Sender).Height - dsurface.Canvas.TextHeight(TDButton(Sender).Caption)) div 2 + down,
//                   SurfaceY(Top)+8 + (TDButton(Sender).Height - g_DXCanvas.TextHeight(TDButton(Sender).Caption)) div 2 + down,
//                   clBlue, //RGB(253, 192, 75),
//                   TDButton(Sender).Caption);
//
//      end;
//      dsurface.Canvas.Font.Size := oldsize;
//      dsurface.Canvas.Font.Style := [];
//      dsurface.Canvas.Release;

   end;

end;

procedure TFrmDlg.DBotExitMouseMove(Sender: TObject; Shift: TShiftState; X,
  Y: Integer);
var
   lx, ly : integer;
   sx, sy : integer;
begin
   with DBotExit do begin
      lx := LocalX (X - Left);
      ly := LocalY (Y - Top);
//      if (X < SurfaceX(Left)) or (X > SurfaceX(Left+Width)) or (Y < SurfaceY(Top)) or (Y > SurfaceY(Top+Height)) then begin
//         DScreen.ClearHint;
//      end
//      else begin
         sx := SurfaceX(Left)+DBottom.SurfaceX(DBottom.Left)+lx+8;
         sy := SurfaceY(Top)+DBottom.SurfaceX(DBottom.Top)+ly+6;
         DScreen.ShowHint(sx, sy, 'ÍË³öÓÎÏ·(Alt+Q)', $393800, True);
//      end;
   end;
end;

procedure TFrmDlg.DBotGroupMouseMove(Sender: TObject; Shift: TShiftState;
  X, Y: Integer);
var
   lx, ly : integer;
   sx, sy : integer;
begin
   with DBotGroup do begin
      lx := LocalX (X - Left);
      ly := LocalY (Y - Top);
//      if (X < SurfaceX(Left)) or (X > SurfaceX(Left+Width)) or (Y < SurfaceY(Top)) or (Y > SurfaceY(Top+Height)) then begin
//         DScreen.ClearHint;
//      end
//      else begin
         sx := SurfaceX(Left)+DBottom.SurfaceX(DBottom.Left)+lx+13;
         sy := SurfaceY(Top)+DBottom.SurfaceX(DBottom.Top)+ly-2;
         DScreen.ShowHint(sx, sy, 'Ð¡×é(Ctrl+G, G)', $393800, True);
//      end;
   end;
end;

procedure TFrmDlg.DBotLogoutMouseMove(Sender: TObject; Shift: TShiftState;
  X, Y: Integer);
var
   lx, ly : integer;
   sx, sy : integer;
begin
   with DBotLogout do begin
      lx := LocalX (X - Left);
      ly := LocalY (Y - Top);
//      if (X < SurfaceX(Left)) or (X > SurfaceX(Left+Width)) or (Y < SurfaceY(Top)) or (Y > SurfaceY(Top+Height)) then begin
//         DScreen.ClearHint;
//      end
//      else begin
         sx := SurfaceX(Left)+DBottom.SurfaceX(DBottom.Left)+lx+8;
         sy := SurfaceY(Top)+DBottom.SurfaceX(DBottom.Top)+ly+6;
         DScreen.ShowHint(sx, sy, '×¢ÏúÓÎÏ·(Alt+X)', $393800, True);
//      end;
   end;
end;

procedure TFrmDlg.DBotMiniMapMouseMove(Sender: TObject; Shift: TShiftState;
  X, Y: Integer);
var
   lx, ly : integer;
   sx, sy : integer;
begin
   with DBotMiniMap do begin
      lx := LocalX (X - Left);
      ly := LocalY (Y - Top);
//      if (X < SurfaceX(Left)) or (X > SurfaceX(Left+Width)) or (Y < SurfaceY(Top)) or (Y > SurfaceY(Top+Height)) then begin
//         DScreen.ClearHint;
//      end
//      else begin
         sx := SurfaceX(Left)+DBottom.SurfaceX(DBottom.Left)+lx+13;
         sy := SurfaceY(Top)+DBottom.SurfaceX(DBottom.Top)+ly-2;
         DScreen.ShowHint(sx, sy, 'Ð¡µØÍ¼(Ctrl+V, V)', $393800, True);
//      end;
   end;
end;

procedure TFrmDlg.DBotTradeMouseMove(Sender: TObject; Shift: TShiftState;
  X, Y: Integer);
var
   lx, ly : integer;
   sx, sy : integer;
begin
   with DBotTrade do begin
      lx := LocalX (X - Left);
      ly := LocalY (Y - Top);
//      if (X < SurfaceX(Left)) or (X > SurfaceX(Left+Width)) or (Y < SurfaceY(Top)) or (Y > SurfaceY(Top+Height)) then begin
//         DScreen.ClearHint;
//      end
//      else begin
         sx := SurfaceX(Left)+DBottom.SurfaceX(DBottom.Left)+lx+13;
         sy := SurfaceY(Top)+DBottom.SurfaceX(DBottom.Top)+ly-2;
         DScreen.ShowHint(sx, sy, '½»Ò×(Ctrl+C, C)', $393800, True);
//      end;
   end;
end;

procedure TFrmDlg.DBotGuildMouseMove(Sender: TObject; Shift: TShiftState;
  X, Y: Integer);
var
   lx, ly : integer;
   sx, sy : integer;
begin
   with DBotGuild do begin
      lx := LocalX (X - Left);
      ly := LocalY (Y - Top);
//      if (X < SurfaceX(Left)) or (X > SurfaceX(Left+Width)) or (Y < SurfaceY(Top)) or (Y > SurfaceY(Top+Height)) then begin
//         DScreen.ClearHint;
//      end
//      else begin
         sx := SurfaceX(Left)+DBottom.SurfaceX(DBottom.Left)+lx+13;
         sy := SurfaceY(Top)+DBottom.SurfaceX(DBottom.Top)+ly-2;
         DScreen.ShowHint(sx, sy, 'ÃÅÅÉ(Ctrl+F, F)', $393800, True);
//      end;
   end;
end;

procedure TFrmDlg.DMyStateMouseMove(Sender: TObject; Shift: TShiftState; X,
  Y: Integer);
var
   lx, ly : integer;
   sx, sy : integer;
begin
   with DMyState do begin
      lx := LocalX (X - Left);
      ly := LocalY (Y - Top);
//      if (X < SurfaceX(Left)) or (X > SurfaceX(Left+Width)) or (Y < SurfaceY(Top)) or (Y > SurfaceY(Top+Height)) then begin
//         DScreen.ClearHint;
//      end
//      else begin
         sx := SurfaceX(Left)+DBottom.SurfaceX(DBottom.Left)+lx+8;
         sy := SurfaceY(Top)+DBottom.SurfaceX(DBottom.Top)+ly+6;
         DScreen.ShowHint(sx, sy, 'ÈËÎï×´Ì¬(Ctrl+W, W)', $393800, True);
//      end;
   end;
end;

procedure TFrmDlg.DMyBagMouseMove(Sender: TObject; Shift: TShiftState; X,
  Y: Integer);
var
   lx, ly : integer;
   sx, sy : integer;
begin
   with DMyBag do begin
      lx := LocalX (X - Left);
      ly := LocalY (Y - Top);
//      if (X < SurfaceX(Left)) or (X > SurfaceX(Left+Width)) or (Y < SurfaceY(Top)) or (Y > SurfaceY(Top+Height)) then begin
//         DScreen.ClearHint;
//      end
//      else begin
         sx := SurfaceX(Left)+DBottom.SurfaceX(DBottom.Left)+lx+8;
         sy := SurfaceY(Top)+DBottom.SurfaceX(DBottom.Top)+ly+6;
         DScreen.ShowHint(sx, sy, '°ü¸¤(Ctrl+Q, Q)', $393800, True);
//      end;
   end;
end;

procedure TFrmDlg.DMyMagicMouseMove(Sender: TObject; Shift: TShiftState; X,
  Y: Integer);
var
   lx, ly : integer;
   sx, sy : integer;
begin
   with DMyMagic do begin
      lx := LocalX (X - Left);
      ly := LocalY (Y - Top);
//      if (X < SurfaceX(Left)) or (X > SurfaceX(Left+Width)) or (Y < SurfaceY(Top)) or (Y > SurfaceY(Top+Height)) then begin
//         DScreen.ClearHint;
//      end
//      else begin
         sx := SurfaceX(Left)+DBottom.SurfaceX(DBottom.Left)+lx+8;
         sy := SurfaceY(Top)+DBottom.SurfaceX(DBottom.Top)+ly+6;
         DScreen.ShowHint(sx, sy, 'Îä¹¦(Ctrl+E, E)', $393800, True);
//      end;
   end;
end;

procedure TFrmDlg.DOptionMouseMove(Sender: TObject; Shift: TShiftState; X,
  Y: Integer);
var
   lx, ly : integer;
   sx, sy : integer;
begin
   with DOption do begin
      lx := LocalX (X - Left);
      ly := LocalY (Y - Top);
//      if (X < SurfaceX(Left)) or (X > SurfaceX(Left+Width)) or (Y < SurfaceY(Top)) or (Y > SurfaceY(Top+Height)) then begin
//         DScreen.ClearHint;
//      end
//      else begin
         sx := SurfaceX(Left)+DBottom.SurfaceX(DBottom.Left)+lx+8;
         sy := SurfaceY(Top)+DBottom.SurfaceX(DBottom.Top)+ly+6;
         DScreen.ShowHint(sx, sy, '»·¾³Ñ¡Ïî(Ctrl+N, N)', $393800, True);
//      end;
   end;
end;

procedure TFrmDlg.DBottomMouseMove(Sender: TObject; Shift: TShiftState; X,
  Y: Integer);
var
  lx, ly: integer;
  sx, sy: integer;
  flag: boolean;
  sMsg: string;
begin
  flag := FALSE;
  with DBottom do begin
    lx := X;
    ly := Y;
//    DScreen.AddSysMsg(IntToStr(lx)+'/'+IntToStr(ly));

//      if (lx>57) and (lx<128) and (ly>470) and (ly<542) then begin
{      if (Myself.Abil.HP < Myself.Abil.MaxHP) or (Myself.Abil.MP < Myself.Abil.MaxMP) then begin
//         flag := TRUE;
         sx := 57;
         sy := 492;
         s  := 'HP('+IntToStr(Myself.Abil.HP)+'/'+IntToStr(Myself.Abil.MaxHP)+')';
         if (Myself.Job <> 0) or (Myself.Abil.Level >= 26) then begin
             s := s+ '\MP('+IntToStr(Myself.Abil.MP)+'/'+IntToStr(Myself.Abil.MaxMP)+')';
         end;
         DScreen.ShowHint(sx, sy, s, clYellow, FALSE);
      end;}
//    if (lx>656) and (lx<714) and (ly>507) and (ly<524) then begin
//       flag := TRUE;
//       sx := 711;
//       sy := 507;
//       DScreen.ShowHint(sx, sy, 'ÇöÀç·¹º§', clYellow, FALSE);
//    end;
    if (lx>148) and (lx<156) and (ly>500) and (ly<583) then begin
       flag := TRUE;
       sx := 100;
       sy := 540;
       sMsg := '(µ±Ç°¾­Ñé)' + inttostr(Myself.Abil.Exp) + '/(Éý¼¶¾­Ñé)' + inttostr(Myself.Abil.MaxExp);
       DScreen.ShowHint(sx, sy, sMsg, $393800, True);
    end;
    if (lx>162) and (lx<170) and (ly>500) and (ly<583) then begin
       flag := TRUE;
       sx := 166;//704;
       sy := 540;
       sMsg := Format('(ÖØÁ¿)%d/%d', [Myself.Abil.Weight, Myself.Abil.MaxWeight]);
       DScreen.ShowHint(sx, sy, sMsg, $393800, True);
    end;
    if not flag then begin
     DScreen.ClearHint;
    end;
  end;
end;

// 2003/04/15 Ä£±¸, ÂÊÁö =============== ÀÌÇÏ ³¡±îÁö
procedure TFrmDlg.DBotFriendClick(Sender: TObject; X, Y: Integer);
begin
   ToggleShowFriendsDlg;
end;

procedure TFrmDlg.DBotFriendDirectPaint(Sender: TObject;
  dsurface: TDirectDrawSurface);
var
   d: TDButton;
   dd: TDirectDrawSurface;
begin
   if Sender is TDButton then begin
      d := TDButton(Sender);
      if not d.Downed then begin
         dd := d.WLib.Images[d.FaceIndex];
         if dd <> nil then
            dsurface.Draw (d.SurfaceX(d.Left), d.SurfaceY(d.Top), dd.ClientRect, dd, TRUE);
      end else begin
         dd := d.WLib.Images[d.FaceIndex+1];
         if dd <> nil then
            dsurface.Draw (d.SurfaceX(d.Left), d.SurfaceY(d.Top), dd.ClientRect, dd, TRUE);
      end;
   end;
end;

procedure TFrmDlg.DBotFriendMouseMove(Sender: TObject; Shift: TShiftState;
  X, Y: Integer);
var
   lx, ly : integer;
   sx, sy : integer;
begin
   with DBotFriend do begin
      lx := LocalX (X - Left);
      ly := LocalY (Y - Top);
      sx := SurfaceX(Left)+DBottom.SurfaceX(DBottom.Left)+lx+13;
      sy := SurfaceY(Top)+DBottom.SurfaceX(DBottom.Top)+ly-2;
      DScreen.ShowHint(sx, sy, 'Ä£±¸Ã¢(W)', clYellow, FALSE);
   end;
end;

procedure TFrmDlg.ToggleShowFriendsDlg;
begin
   DFriendDlg.Visible := not DFriendDlg.Visible;
end;

procedure TFrmDlg.ToggleShowMailListDlg;
begin
   DMailListDlg.Visible := not DMailListDlg.Visible;
   MailAlarm := false;
end;

procedure TFrmDlg.ToggleShowBlockListDlg;
begin
   DBlockListDlg.Visible := not DBlockListDlg.Visible;
end;

procedure TFrmDlg.ToggleShowMemoDlg;
begin
   DMemo.Visible := not DMemo.Visible;
   MemoMail.Visible := DMemo.Visible;
end;

procedure TFrmDlg.DFriendDlgDirectPaint(Sender: TObject;
  dsurface: TDirectDrawSurface);
var
   d: TDirectDrawSurface;
   b: TDirectDrawSurface;
   lx, ly, n, t, l, ax, ay : integer;
   CurrentPage ,maxPage , UpPage , DownPage : integer;
begin
(*
   if ViewFriends then
   begin
     CurrentPage :=  FriendPage + 1;
     MaxPage     :=  FriendMembers.Count div 10 + 1;
   end
   else
   begin
     CurrentPage :=  BlackListPage + 1;
     MaxPage     :=  BlackMembers.Count div 10 + 1;
   end;

   if CurrentPage > 1 then UpPage := CurrentPage -1
   else UpPage := CurrentPage;
   if CurrentPage < MaxPage then DownPage := CurrentPage+1
   else DownPage := CurrentPage;

   DFrdpgUp.hint   := IntToStr ( UpPage   ) + '/' + IntToStr ( MaxPage );
   DFrdpgDn.hint   := IntToStr ( DownPage ) + '/' + IntToStr ( MaxPage );

   b := g_WProgUse.GetCachedImage (534, ax, ay);
   with DFriendDlg do begin
      d := WLib.Images[FaceIndex];
      if d <> nil then
         dsurface.Draw (SurfaceX(Left), SurfaceY(Top), d.ClientRect, d, TRUE);
      if ViewFriends then begin
         if FriendMembers.Count > 0 then begin
//            SetBkMode (dsurface.Canvas.Handle, TRANSPARENT);
            t := FriendPage * 20;
            l := _MIN(FriendPage*20+20, FriendMembers.Count);
            for n := t to l-1 do begin
               if PTFriend(FriendMembers[n]).Status >= 4 then
                   dsurface.Canvas.Font.Color := clWhite
               else
                   dsurface.Canvas.Font.Color := clSilver;

               if n = CurrentFriend then
               begin
                  dsurface.Canvas.Font.Color  := clBlack;
                  dsurface.Canvas.Brush.Color := clSilver;
                  dsurface.Canvas.Brush.Style := bsSolid;
               end
               else
               begin
                  dsurface.Canvas.Brush.Color := clBlack;
                  dsurface.Canvas.Brush.Style := bsClear;
               end;

//               lx := SurfaceX(30) + Left + ((n-t) mod 2) * 120;
//               ly := SurfaceY(70) + Top  + ((n-t) div 2) * 15;

               lx := SurfaceX(39) + Left + ((n-t) mod 2) * 120;
               ly := SurfaceY(96) + Top  + ((n-t) div 2) * 15;

               if fLover.Find( PTFriend(FriendMembers[n]).CharID ) then
                  dsurface.Canvas.TextOut (lx, ly, '¢½'+PTFriend(FriendMembers[n]).CharID)
               else
                  dsurface.Canvas.TextOut (lx, ly, PTFriend(FriendMembers[n]).CharID);
//             DScreen.AddSysMsg (IntToStr(lx+ax-5) + ' ' + IntToStr(ly+ay+5));
//             dsurface.Draw (SurfaceX(lx+ax-5), SurfaceY(ly+ay+5), b.ClientRect, b, TRUE);

               dsurface.Canvas.Font.Color := clWhite;
               dsurface.Canvas.Brush.Style := bsClear;
               lx := SurfaceX(44) + Left ;
               ly := SurfaceY(268) + Top  ;
               dsurface.Canvas.TextOut (lx, ly, IntToStr(ConnectFriend)+'/'+IntToStr(FriendMembers.Count));

            end;
            dsurface.Canvas.Release;
         end;
      end else begin
         if BlackMembers.Count > 0 then begin
            with dsurface.Canvas do begin
               SetBkMode (Handle, TRANSPARENT);
               Font.Color := clSilver;
               t := BlackListPage * 20;
               l := _MIN(BlackListPage*20+20, BlackMembers.Count);
               for n := t to l-1 do begin

                  if PTFriend(BlackMembers[n]).Status >= 4 then
                    dsurface.Canvas.Font.Color := clWhite
                  else
                   dsurface.Canvas.Font.Color := clSilver;

                  if n = CurrentBlack then
                  begin
                    dsurface.Canvas.Font.Color  := clBlack;
                    dsurface.Canvas.Brush.Color := clSilver;
                    dsurface.Canvas.Brush.Style := bsSolid;
                  end
                  else
                  begin
                    dsurface.Canvas.Brush.Color := clBlack;
                    dsurface.Canvas.Brush.Style := bsClear;
                  end;

                  lx := SurfaceX(39) + Left + ((n-t) mod 2) * 120;
                  ly := SurfaceY(96) + Top  + ((n-t) div 2) * 15;
                  TextOut (lx, ly, PTFriend(BlackMembers[n]).CharID);
                  dsurface.Draw (lx+ax-5, ly+ay+5, b.ClientRect, b, TRUE);
               end;

               dsurface.Canvas.Font.Color := clWhite;
               dsurface.Canvas.Brush.Style := bsClear;
               lx := SurfaceX(44) + Left ;
               ly := SurfaceY(265) + Top  ;
               dsurface.Canvas.TextOut (lx, ly, IntToStr(ConnectBlack)+'/'+IntToStr(BlackMembers.Count));

               Release;
            end;
         end;
      end;
      //ÀÌ¸§
      with dsurface.Canvas do begin
         SetBkMode (Handle, TRANSPARENT);
         Font.Color := MySelf.NameColor;
//         TextOut (SurfaceX(Left + 134 - TextWidth(MySelf.UserName) div 2),
//                  SurfaceY(Top + 13), MySelf.UserName);
         TextOut (SurfaceX(Left + 136 - TextWidth(MySelf.UserName) div 2),
                  SurfaceY(Top + 38), MySelf.UserName);
         Release;
      end;
   end;*)
end;

procedure TFrmDlg.DFrdPgUpClick(Sender: TObject; X, Y: Integer);
begin
   if Sender = DFrdPgUp then begin
      if ViewFriends then begin
         if FriendPage > 0 then
            Dec (FriendPage);
      end else begin
         if BlackListPage > 0 then
            Dec (BlackListPage);
      end;
   end else begin
      if ViewFriends then begin
         if FriendPage < (FriendMembers.Count+19) div 20 - 1 then
            Inc (FriendPage);
      end else begin
         if BlackListPage < (BlackMembers.Count+19) div 20 - 1 then
            Inc (BlackListPage);
      end;
   end;
end;

procedure TFrmDlg.DFrdPgUpDirectPaint(Sender: TObject;
  dsurface: TDirectDrawSurface);
var
   d: TDirectDrawSurface;
begin
   with Sender as TDButton do begin
      if TDButton(Sender).Downed then begin
         d := WLib.Images[FaceIndex];
         if d <> nil then
            dsurface.Draw (SurfaceX(Left), SurfaceY(Top), d.ClientRect, d, TRUE);
      end;
   end;
end;

procedure TFrmDlg.DFrdFriendClick(Sender: TObject; X, Y: Integer);
begin
   ViewFriends := TRUE;
   DFriendDlg.hint := '';
end;

procedure TFrmDlg.DFrdBlackListClick(Sender: TObject; X, Y: Integer);
begin
   ViewFriends := FALSE;
   DFriendDlg.hint := '';   
end;

procedure TFrmDlg.DFrdAddMouseMove(Sender: TObject; Shift: TShiftState; X,
  Y: Integer);
var
   lx, ly : integer;
   sx, sy : integer;
begin
   with DFrdAdd do begin
      lx := LocalX (X - Left);
      ly := LocalY (Y - Top);
      sx := SurfaceX(Left)+DFriendDlg.SurfaceX(DFriendDlg.Left)+lx+8;
      sy := SurfaceY(Top) +DFriendDlg.SurfaceX(DFriendDlg.Top) +ly+6;
      DScreen.ShowHint(sx, sy, 'µî·Ï', clYellow, FALSE);
      DFriendDlg.hint := '';
   end;
end;

procedure TFrmDlg.DFrdDelMouseMove(Sender: TObject; Shift: TShiftState; X,
  Y: Integer);
var
   lx, ly : integer;
   sx, sy : integer;
begin
   with DFrdDel do begin
      lx := LocalX (X - Left);
      ly := LocalY (Y - Top);
      sx := SurfaceX(Left)+DFriendDlg.SurfaceX(DFriendDlg.Left)+lx+8;
      sy := SurfaceY(Top) +DFriendDlg.SurfaceX(DFriendDlg.Top)+ly+6;
      DScreen.ShowHint(sx, sy, '»èÁ¦', clYellow, FALSE);
      DFriendDlg.hint := '';
   end;
end;


procedure TFrmDlg.DFrdMemoMouseMove(Sender: TObject; Shift: TShiftState; X,
  Y: Integer);
var
   lx, ly : integer;
   sx, sy : integer;
begin
   with DFrdMemo do begin
      lx := LocalX (X - Left);
      ly := LocalY (Y - Top);
      sx := SurfaceX(Left)+DFriendDlg.SurfaceX(DFriendDlg.Left)+lx+8;
      sy := SurfaceY(Top) +DFriendDlg.SurfaceX(DFriendDlg.Top)+ly+6;
      DScreen.ShowHint(sx, sy, '¸Þ¸ð', clYellow, FALSE);
      DFriendDlg.hint := '';
   end;
end;

procedure TFrmDlg.DFrdMailMouseMove(Sender: TObject; Shift: TShiftState; X,
  Y: Integer);
var
   lx, ly : integer;
   sx, sy : integer;
begin
   with DFrdMail do begin
      lx := LocalX (X - Left);
      ly := LocalY (Y - Top);
      sx := SurfaceX(Left)+DFriendDlg.SurfaceX(DFriendDlg.Left)+lx+8;
      sy := SurfaceY(Top) +DFriendDlg.SurfaceX(DFriendDlg.Top)+ly+6;
      DScreen.ShowHint(sx, sy, 'ÂÊÁö', clYellow, FALSE);
      DFriendDlg.hint := '';
   end;
end;

procedure TFrmDlg.DFrdWhisperMouseMove(Sender: TObject; Shift: TShiftState;
  X, Y: Integer);
var
   lx, ly : integer;
   sx, sy : integer;
begin
   with DFrdWhisper do begin
      lx := LocalX (X - Left);
      ly := LocalY (Y - Top);
      sx := SurfaceX(Left)+DFriendDlg.SurfaceX(DFriendDlg.Left)+lx+8;
      sy := SurfaceY(Top) +DFriendDlg.SurfaceX(DFriendDlg.Top)+ly+6;
      DScreen.ShowHint(sx, sy, '±Ó¼Ó¸»', clYellow, FALSE);
      DFriendDlg.hint := '';
   end;
end;

procedure TFrmDlg.DFrdCloseClick(Sender: TObject; X, Y: Integer);
begin
   ToggleShowFriendsDlg;
end;

procedure TFrmDlg.DFrdFriendDirectPaint(Sender: TObject;
  dsurface: TDirectDrawSurface);
var
   d: TDirectDrawSurface;
begin
   with Sender as TDButton do begin
     if ViewFriends then begin
        d := WLib.Images[FaceIndex];
        if d <> nil then
           dsurface.Draw (SurfaceX(Left), SurfaceY(Top), d.ClientRect, d, TRUE);
     end else begin
        d := WLib.Images[FaceIndex+1];
        if d <> nil then
           dsurface.Draw (SurfaceX(Left), SurfaceY(Top), d.ClientRect, d, TRUE);
     end;
   end;
end;

procedure TFrmDlg.DFrdBlackListDirectPaint(Sender: TObject;
  dsurface: TDirectDrawSurface);
var
   d: TDirectDrawSurface;
begin
   with Sender as TDButton do begin
     if ViewFriends then begin
        d := WLib.Images[FaceIndex+1];
        if d <> nil then
           dsurface.Draw (SurfaceX(Left), SurfaceY(Top), d.ClientRect, d, TRUE);
     end else begin
        d := WLib.Images[FaceIndex];
        if d <> nil then
           dsurface.Draw (SurfaceX(Left), SurfaceY(Top), d.ClientRect, d, TRUE);
     end;
   end;
end;

procedure TFrmDlg.DMailListDlgDirectPaint(Sender: TObject;
  dsurface: TDirectDrawSurface);
var
   d : TDirectDrawSurface;
   b : TDirectDrawSurface;
   lx, ly, n, t, l, ax, ay : integer;
   Rect : TRect;
   CurrentPage ,maxPage , UpPage , DownPage : integer;
   LockStr : string;
begin
(*   CurrentPage :=  MailPage + 1;
   MaxPage     :=  MailLists.Count div 10 + 1;
   if CurrentPage > 1 then UpPage := CurrentPage -1
   else UpPage := CurrentPage;
   if CurrentPage < MaxPage then DownPage := CurrentPage+1
   else DownPage := CurrentPage;

   DMailListPgUp.hint   := IntToStr ( UpPage   ) + '/' + IntToStr ( MaxPage );
   DMailListpgDn.hint   := IntToStr ( DownPage ) + '/' + IntToStr ( MaxPage );

   b := g_WProgUse.GetCachedImage (543, ax, ay);
   with DMailListDlg do
   begin
      d := WLib.Images[FaceIndex];

      if d <> nil then
         dsurface.Draw (SurfaceX(Left), SurfaceY(Top), d.ClientRect, d, TRUE);

//      dsurface.Draw (SurfaceX(Left+15), SurfaceY(Top+35), b.ClientRect, b, TRUE);
      dsurface.Draw (SurfaceX(Left+27), SurfaceY(Top+60), b.ClientRect, b, TRUE);

      if MailLists.Count > 0 then
      begin
         t := MailPage * 11;
         l := _MIN(MailPage*11+11, MailLists.Count);

         for n := t to l-1 do begin

            if n = CurrentMail then
            begin
               dsurface.Canvas.Brush.Color := clDkGray ;
               dsurface.Canvas.Brush.Style := bsSolid;
            end
            else
            begin
               dsurface.Canvas.Brush.Color := clBlack;
               dsurface.Canvas.Brush.Style := bsClear;
            end;

            LockStr := '';

            case PTMail(MailLists[n]).Status of
            0 : dsurface.Canvas.Font.Color := clWhite;
            1 : dsurface.Canvas.Font.Color := clSilver;
            2 : begin
                dsurface.Canvas.Font.Color := clWhite;
                LockStr := '[*]';
                end;
            3 : dsurface.Canvas.Font.Color := clBlue;
            end;

//            lx := SurfaceX(30) + Left;
//            ly := SurfaceY(60) + Top  + (n-t) * 15;

            lx := SurfaceX(39) + Left;
            ly := SurfaceY(85) + Top  + (n-t) * 15;

            Rect.Left  := lx - 10;    Rect.Top    := ly;
            Rect.Right := lx + 215;   Rect.Bottom := ly + 15;
            dsurface.Canvas.FillRect(Rect);
            dsurface.Canvas.TextOut (lx, ly+2, PTMail(MailLists[n]).Sender);


//            lx := SurfaceX(145) + Left;
//            ly := SurfaceY(60) + Top  + (n-t) * 15;

            lx := SurfaceX(155) + Left;
            ly := SurfaceY(85) + Top  + (n-t) * 15;

            Rect.Left  := lx;         Rect.Top    := ly;
            Rect.Right := lx + 100;   Rect.Bottom := ly + 15;
            dsurface.Canvas.TextRect (Rect, lx, ly+2, LockStr + StrToVisibleOnly( SqlSafeToStr(PTMail(MailLists[n]).Mail) ) )  ;

            dsurface.Canvas.Font.Color := clWhite;
            dsurface.Canvas.Brush.Style := bsClear;
            lx := SurfaceX(44) + Left ;
            ly := SurfaceY(268) + Top  ;
            dsurface.Canvas.TextOut (lx, ly, IntToStr(NotReadMailCount)+'/'+IntToStr(MailLists.Count));

         end;
         dsurface.Canvas.Release;
      end;

      //ÀÌ¸§
      with dsurface.Canvas do
      begin
         SetBkMode (Handle, TRANSPARENT);
         Font.Color := MySelf.NameColor;
         TextOut (SurfaceX(Left + 136 - TextWidth(MySelf.UserName) div 2),
                  SurfaceY(Top + 38), MySelf.UserName);
         Release;
      end;
   end; *)
end;

procedure TFrmDlg.DMailListCloseClick(Sender: TObject; X, Y: Integer);
begin
   ToggleShowMailListDlg;
end;

procedure TFrmDlg.DMailListPgUpClick(Sender: TObject; X, Y: Integer);
begin
   if Sender = DMailListPgUp then begin
      if MailPage > 0 then
         Dec (MailPage);
   end else begin
      if MailPage < (MailLists.Count+10) div 11 - 1 then
         Inc (MailPage);
   end;
end;

procedure TFrmDlg.DMLReplyMouseMove(Sender: TObject; Shift: TShiftState; X,
  Y: Integer);
var
   lx, ly : integer;
   sx, sy : integer;
begin
   with DMLReply do begin
      lx := LocalX (X - Left);
      ly := LocalY (Y - Top);
      sx := SurfaceX(Left)+DMailListDlg.SurfaceX(DMailListDlg.Left)+lx+8;
      sy := SurfaceY(Top) +DMailListDlg.SurfaceX(DMailListDlg.Top) +ly+6;
      DScreen.ShowHint(sx, sy, '´äÀå', clYellow, FALSE);
   end;
end;

procedure TFrmDlg.DMLReadMouseMove(Sender: TObject; Shift: TShiftState; X,
  Y: Integer);
var
   lx, ly : integer;
   sx, sy : integer;
begin
   with DMLRead do begin
      lx := LocalX (X - Left);
      ly := LocalY (Y - Top);
      sx := SurfaceX(Left)+DMailListDlg.SurfaceX(DMailListDlg.Left)+lx+8;
      sy := SurfaceY(Top) +DMailListDlg.SurfaceX(DMailListDlg.Top) +ly+6;
      DScreen.ShowHint(sx, sy, 'ÀÐ±â', clYellow, FALSE);
   end;
end;

procedure TFrmDlg.DMLDelMouseMove(Sender: TObject; Shift: TShiftState; X,
  Y: Integer);
var
   lx, ly : integer;
   sx, sy : integer;
begin
   with DMLDel do begin
      lx := LocalX (X - Left);
      ly := LocalY (Y - Top);
      sx := SurfaceX(Left)+DMailListDlg.SurfaceX(DMailListDlg.Left)+lx+8;
      sy := SurfaceY(Top) +DMailListDlg.SurfaceX(DMailListDlg.Top) +ly+6;
      DScreen.ShowHint(sx, sy, '»èÁ¦', clYellow, FALSE);
   end;
end;

procedure TFrmDlg.DMLLockMouseMove(Sender: TObject; Shift: TShiftState; X,
  Y: Integer);
var
   lx, ly : integer;
   sx, sy : integer;
begin
   with DMLLock do begin
      lx := LocalX (X - Left);
      ly := LocalY (Y - Top);
      sx := SurfaceX(Left)+DMailListDlg.SurfaceX(DMailListDlg.Left)+lx+8;
      sy := SurfaceY(Top) +DMailListDlg.SurfaceX(DMailListDlg.Top) +ly+6;
      DScreen.ShowHint(sx, sy, '»èÁ¦±ÝÁö', clYellow, FALSE);
   end;
end;

procedure TFrmDlg.DMLBlockMouseMove(Sender: TObject; Shift: TShiftState; X,
  Y: Integer);
var
   lx, ly : integer;
   sx, sy : integer;
begin
   with DMLBlock do begin
      lx := LocalX (X - Left);
      ly := LocalY (Y - Top);
      sx := SurfaceX(Left)+DMailListDlg.SurfaceX(DMailListDlg.Left)+lx+8;
      sy := SurfaceY(Top) +DMailListDlg.SurfaceX(DMailListDlg.Top) +ly+6;
      DScreen.ShowHint(sx, sy, '°ÅºÎÀÚ¸®½ºÆ®', clYellow, FALSE);
   end;
end;

procedure TFrmDlg.DMailListDlgClick(Sender: TObject; X, Y: Integer);
var lx, ly : integer;
    pos : integer;
begin
    ItemSearchEdit.Visible := False;
    lx := x - DMailListDlg.Left;
    ly := y - DMailListDlg.Top;
//    if (lx > 20) and (lx < 250) and (ly > 60) and (ly < 225) then begin
    if (lx > 28) and (lx < 263) and (ly > 85) and (ly < 247) then begin
       pos := (ly - 85) div 15 + MailPage * 11;
       if MailLists.Count > pos then
          CurrentMail := pos;
    end;
end;

procedure TFrmDlg.DMailListDlgDblClick(Sender: TObject);
begin
     MailListDlgDblClicked := true;
end;

procedure TFrmDlg.DMailListDlgMouseUp(Sender: TObject;
  Button: TMouseButton; Shift: TShiftState; X, Y: Integer);
begin
     if not MailListDlgDblClicked then Exit;

     MailListDlgDblClicked := false;
     DMLReadClick( nil ,0,0 );
end;

procedure TFrmDlg.DFriendDlgClick(Sender: TObject; X, Y: Integer);
var
   lx, ly, pos , sx, sy: integer;
begin
    ItemSearchEdit.Visible := False;

    lx := x - DFriendDlg.Left;
    ly := y - DFriendDlg.Top;
    (Sender As TDWindow).hint := '';
//    if (lx > 30) and (lx < 240) and (ly > 70) and (ly < 225) then
    if (lx > 39) and (lx < 260) and (ly > 96) and (ly < 247) then
    begin

//        pos := (lx div 140) + ((ly - 70) div 15) * 2 + FriendPage * 20;
        pos := (lx div 140) + ((ly - 96) div 15) * 2 + FriendPage * 20;
        if ViewFriends then
        begin
           if FriendMembers.Count > pos then
           begin
               CurrentFriend := pos;

               if CurrentFriend >= 0 then
               begin
               (Sender As TDWindow).hint := StrToHint( SqlSafeToStr( PTFriend(FriendMembers[CurrentFriend]).Memo ));
               end;
           end
           else
           begin
              CurrentFriend := -1;
           end;
        end
        else
        begin
           if BlackMembers.Count > pos then
           begin
               CurrentBlack  := pos;
               if CurrentBlack >= 0 then
               begin
                   (Sender As TDWindow).hint := StrToHint(SqlSafeToStr( PTFriend(BlackMembers[CurrentBlack]).Memo ));
               end;
           end
           else
           begin
              CurrentBlack := -1;
           end;
        end;
    end
//    DScreen.AddSysMsg (IntToStr(lx) + ' ' + IntToStr(ly) + ' ' + IntToStr(pos));
end;

procedure TFrmDlg.DFriendDlgDblClick(Sender: TObject);
begin
     FriendDlgDblClicked := true;
end;

procedure TFrmDlg.DFriendDlgMouseUp(Sender: TObject; Button: TMouseButton;
  Shift: TShiftState; X, Y: Integer);
begin
     if not FriendDlgDblClicked then Exit;

     FriendDlgDblClicked := false;
     
     if ViewFriends then
     begin
          if CurrentFriend >= 0 then
          begin
            if ( PTFriend(FriendMembers[CurrentFriend]).Status >= 4 ) then
               DFrdWhisperClick( nil,0,0)
            else
               DFrdMailClick(nil,0,0 );
          end;
     end
     else
     begin
          if CurrentBlack >= 0 then
          begin
            if ( PTFriend(BlackMembers[CurrentBlack]).Status >= 4 ) then
               DFrdWhisperClick( nil,0,0)
            else
               DFrdMailClick(nil,0,0 );
          end;
     end;

end;

procedure TFrmDlg.DBlockListCloseClick(Sender: TObject; X, Y: Integer);
begin
   ToggleShowBlockListDlg;
end;

procedure TFrmDlg.DBLPgUpClick(Sender: TObject; X, Y: Integer);
begin
   if Sender = DBLPgUp then begin
      if BlockPage > 0 then
         Dec (BlockPage);
   end else begin
      if BlockPage < (BlockLists.Count+10) div 11 - 1 then
         Inc (BlockPage);
   end;
end;

procedure TFrmDlg.DBlockListDlgDirectPaint(Sender: TObject;
  dsurface: TDirectDrawSurface);
var
   d : TDirectDrawSurface;
   b : TDirectDrawSurface;
   lx, ly, n, t, l, ax, ay : integer;
   Rect : TRect;
   CurrentPage ,maxPage , UpPage , DownPage : integer;
begin
(*   CurrentPage :=  BlockPage + 1;
   MaxPage     :=  BlockLists.Count div 10 + 1;
   if CurrentPage > 1 then UpPage := CurrentPage -1
   else UpPage := CurrentPage;
   if CurrentPage < MaxPage then DownPage := CurrentPage+1
   else DownPage := CurrentPage;

   DBLpgUp.hint   := IntToStr ( UpPage   ) + '/' + IntToStr ( MaxPage );
   DBLpgDn.hint   := IntToStr ( DownPage ) + '/' + IntToStr ( MaxPage );

   b := g_WProgUse.GetCachedImage (542, ax, ay);
   with DBlockListDlg do begin
      d := WLib.Images[FaceIndex];
      if d <> nil then
         dsurface.Draw (SurfaceX(Left), SurfaceY(Top), d.ClientRect, d, TRUE);
      dsurface.Draw (SurfaceX(Left+27), SurfaceY(Top+60), b.ClientRect, b, TRUE);
      if BlockLists.Count > 0 then begin
//         SetBkMode (dsurface.Canvas.Handle, TRANSPARENT);
         t := BlockPage * 11;
         l := _MIN(BlockPage*11+11, BlockLists.Count);
         for n := t to l-1 do begin
            if n = CurrentBlock then
            begin
               dsurface.Canvas.Font.Color  := clBlack;
               dsurface.Canvas.Brush.Color := clGray;
               dsurface.Canvas.Brush.Style := bsSolid;
            end
            else
            begin
               dsurface.Canvas.Font.Color  := clSilver;
               dsurface.Canvas.Brush.Color := clBlack;
               dsurface.Canvas.Brush.Style := bsClear;
            end;

//               lx := SurfaceX(30) + Left + ((n-t) mod 2) * 120;
//               ly := SurfaceY(70) + Top  + ((n-t) div 2) * 15;

               lx := SurfaceX(30+11) + Left + ((n-t) mod 2) * 120;
               ly := SurfaceY(70+25) + Top  + ((n-t) div 2) * 15;

               dsurface.Canvas.TextOut (lx, ly, BlockLists[n] );

//            lx := SurfaceX(30) + Left;
//            ly := SurfaceY(60) + Top  + (n-t) * 15;
//            Rect.Left  := lx - 10;    Rect.Top    := ly;
//            Rect.Right := lx + 215;   Rect.Bottom := ly + 14;
//            dsurface.Canvas.FillRect(Rect);
//            dsurface.Canvas.TextOut (lx, ly, BlockLists[n]);

         end;
         dsurface.Canvas.Release;
      end;
      //ÀÌ¸§
      with dsurface.Canvas do begin
         SetBkMode (Handle, TRANSPARENT);
         Font.Color := MySelf.NameColor;
         TextOut (SurfaceX(Left + 136 - TextWidth(MySelf.UserName) div 2),
                  SurfaceY(Top + 38), MySelf.UserName);
         Release;
      end;
   end; *)
end;

procedure TFrmDlg.DBlockListDlgClick(Sender: TObject; X, Y: Integer);
var lx, ly : integer;
    pos : integer;
begin
    ItemSearchEdit.Visible := False;

    lx := x - DBlockListDlg.Left;
    ly := y - DBlockListDlg.Top;
//    if (lx > 20) and (lx < 250) and (ly > 60) and (ly < 225) then begin
    if (lx > 28) and (lx < 265) and (ly > 82) and (ly < 247) then begin
       pos := (lx div 140) + ((ly - (70+25)) div 15) * 2 + FriendPage * 20;
//       pos := (ly - 60) div 15 + BlockPage * 11;
       if BlockLists.Count > pos then
          CurrentBlock := pos;
    end;
end;

procedure TFrmDlg.DBLAddMouseMove(Sender: TObject; Shift: TShiftState; X,
  Y: Integer);
var
   lx, ly : integer;
   sx, sy : integer;
begin
   with DBLAdd do begin
      lx := LocalX (X - Left);
      ly := LocalY (Y - Top);
      sx := SurfaceX(Left)+DBlockListDlg.SurfaceX(DBlockListDlg.Left)+lx+8;
      sy := SurfaceY(Top) +DBlockListDlg.SurfaceX(DBlockListDlg.Top) +ly+6;
      DScreen.ShowHint(sx, sy, '°ÅºÎÀÚµî·Ï', clYellow, FALSE);
   end;
end;

procedure TFrmDlg.DBLDelMouseMove(Sender: TObject; Shift: TShiftState; X,
  Y: Integer);
var
   lx, ly : integer;
   sx, sy : integer;
begin
   with DBLDel do begin
      lx := LocalX (X - Left);
      ly := LocalY (Y - Top);
      sx := SurfaceX(Left)+DBlockListDlg.SurfaceX(DBlockListDlg.Left)+lx+8;
      sy := SurfaceY(Top) +DBlockListDlg.SurfaceX(DBlockListDlg.Top) +ly+6;
      DScreen.ShowHint(sx, sy, '°ÅºÎÀÚ»èÁ¦', clYellow, FALSE);
   end;
end;

procedure TFrmDlg.DMLBlockClick(Sender: TObject; X, Y: Integer);
begin
   ToggleShowBlockListDlg;
end;

procedure TFrmDlg.DBotMemoMouseMove(Sender: TObject; Shift: TShiftState; X,
  Y: Integer);
var
   lx, ly : integer;
   sx, sy : integer;
begin
   with DBotMemo do begin
      lx := LocalX (X - Left);
      ly := LocalY (Y - Top);
      sx := SurfaceX(Left)+DBottom.SurfaceX(DBottom.Left)+lx+8;
      sy := SurfaceY(Top) +DBottom.SurfaceX(DBottom.Top) +ly+6;
      DScreen.ShowHint(sx, sy, 'ÓÊ¼þ(Ctrl+M, M)', $393800, True);
   end;
end;

procedure TFrmDlg.DBotMemoClick(Sender: TObject; X, Y: Integer);
begin
     ToggleShowMailListDlg;

     if WantMailList = false then
     begin
          FrmMain.SendMailList;
          FrmMain.SendRejectLIst;
          WantMailList := true;
     end;

     MailAlarm := false;

end;

procedure TFrmDlg.AddFriend( FriendName : string ; ShowMessage : Boolean);
var
   frdtype : integer;
begin
   if FriendName <> '' then
   begin
      // ÀÚ½ÅÀº µî·ÏÇÒ ¼ö ¾ø´Ù
      if FriendName = MySelf.UserName then
      begin
         if ShowMessage then DMessageDlg ('ÀÚ±âÀÚ½ÅÀº µî·ÏÇÒ ¼ö ¾ø½À´Ï´Ù.', [mbOk]);
         Exit;
      end;

      if FrmMain.IsMyMember( FriendName ) then
      begin
         if ShowMessage then DMessageDlg (FriendName+'´ÔÀº ÀÌ¹Ì µî·ÏµÇ¾îÀÖ½À´Ï´Ù.', [mbOk]);
         Exit;
      end;

      if ViewFriends then frdtype := 1
      else frdtype := 8;
      FrmMain.SendAddFriend ( FriendName , frdtype );
   end;

end;

procedure TFrmDlg.DFrdAddClick(Sender: TObject; X, Y: Integer);
begin
   { 2003/04/15
   if (not DMemo.Visible) then begin
      ViewWindowNo := 1;
      DMemoB1.SetImgIndex(g_WProgUse, 544);
      ShowEditMail;
   end;
   }
  // µî·ÏÇÒ Ä£±¸ ¶Ç´Â ¾Ç¿¬ÀÇ °³¼ö¸¦ ¼³Á¤ÇÑ´Ù.
  if ViewFriends then
  begin
       if Friendmembers.Count >= MAX_FRIEND_COUNT then
       begin
          DMessageDlg ('µî·ÏÇÒ Ä£±¸ ¼ö°¡ ´Ù Â÷ÀÖ½À´Ï´Ù.', [mbOk]);
          Exit;
       end;

  end
  else
  begin
       if Blackmembers.Count >= MAX_FRIEND_COUNT then
       begin
          DMessageDlg ('µî·ÏÇÒ ¾Ç¿¬ ¼ö°¡ ´Ù Â÷ÀÖ½À´Ï´Ù.', [mbOk]);
          Exit;
       end;

  end;

   DScreen.ClearHint;
   DMessageDlg ('Ä£±¸·Î µî·ÏÇÒ »ç¶÷ÀÇ ÀÌ¸§À» ÀÔ·ÂÇÏ½Ê½Ã¿À', [mbOk, mbAbort]);
   AddFriend( DlgEditText , true );

end;

procedure TFrmDlg.DFrdDelClick(Sender: TObject; X, Y: Integer);
var
   delchar : string;
begin
     if ViewFriends then
     begin
        if CurrentFriend >= 0 then
            delchar := PTFriend(FriendMembers[CurrentFriend]).CharID
        else
            Exit;
     end
     else
     begin
        if CurrentBlack >= 0 then
            delchar := PTFriend(BlackMembers[CurrentBlack]).CharID
        else
            Exit;
     end;

     if delchar <> '' then
     begin
        if mrOk = FrmDlg.DMessageDlg (delchar+'´ÔÀ» Ä£±¸¸ñ·Ï¿¡¼­ »èÁ¦ ÇÏ½Ã°Ú½À´Ï±î?', [mbOk, mbCancel]) then
        begin
             FrmMain.sendDelFriend( delchar );
        end;
     end;

end;

procedure TFrmDlg.DFrdMailClick(Sender: TObject; X, Y: Integer);
begin

//   if (not DMemo.Visible)then
   begin
      if ViewFriends  then
      begin
         if (CurrentFriend < 0) then Exit;
         ViewWindowData := CurrentFriend;
         MemoCharID := PTFriend(FriendMembers[ViewWindowData]).CharID;
      end
      else
      begin
         if (CurrentBlack < 0) then Exit;
         ViewWindowData := CurrentBlack;
         MemoCharID := PTFriend(BlackMembers[ViewWindowData]).CharID;
      end;

      ViewWindowNo   := VIEW_MAILSEND;
      DMemoB1.SetImgIndex(g_WProgUse, 546);
      DMemoB2.SetImgIndex(g_WProgUse, 538);
      DMemoB1.Visible := true;
      memoMail.Clear;

      ShowEditMail;
   end;
end;

procedure TFrmDlg.DMLReadClick(Sender: TObject; X, Y: Integer);
var
   str : string;
begin
//   if (not DMemo.Visible) and (CurrentMail >= 0) then begin
   if (CurrentMail >= 0) then begin

      ViewWindowNo   := VIEW_MAILREAD;
      ViewWindowData := CurrentMail;
      DMemoB1.Visible := false ;//.SetImgIndex(g_WProgUse, 544);
      DMemoB2.SetImgIndex(g_WProgUse, 544);
      MemoMail.Text  := SQlSafeToStr( pTMail(MailLists[CurrentMail]).Mail);
      MemoMail.ReadOnly := true;
      MemoCharID := PTMail(MailLists[ViewWindowData]).Sender;
      str   := PTMail(MailLists[ViewWindowData]).Date;
      MemoDate := '20'+str[1] + str[2] + '/' + str[3]+str[4] +'/'+
                  str[5] + str[6]+' '+str[7]+str[8]+':'+str[9]+str[10];
      // ÀÐ¾úÀ½À» Àü¼Û
      if ( pTMail(MailLists[CurrentMail]).Status = 0 ) then
      FrmMain.SendReadingMail( pTMail(MailLists[CurrentMail]).Date );

      ShowEditMail;

   end;
end;

procedure TFrmDlg.DFrdMemoClick(Sender: TObject; X, Y: Integer);
begin
//   if (not DMemo.Visible) then
   begin
      if ViewFriends then
      begin
         if (CurrentFriend >= 0) then
         begin
               ViewWindowData := CurrentFriend;
               MemoCharID := PTFriend(FriendMembers[ViewWindowData]).CharID;
               ViewWindowNo   := VIEW_MEMO;
               memoMail.Text := SqlSafeToStr( PTFriend(FriendMembers[CurrentFriend]).Memo );
               DMemoB1.SetImgIndex(g_WProgUse, 544);
               DMemoB2.SetImgIndex(g_WProgUse, 538);
               DMemoB1.Visible := true;

               ShowEditMail;
         end;
      end
      else
      begin
         if (CurrentBlack >= 0) then
         begin
               ViewWindowData := CurrentBlack;
               MemoCharID := PTFriend(BlackMembers[ViewWindowData]).CharID;
               ViewWindowNo   := VIEW_MEMO;
               memoMail.Text := SqlSafeToStr( PTFriend(BlackMembers[CurrentBlack]).Memo);
               DMemoB1.SetImgIndex(g_WProgUse, 544);
               DMemoB2.SetImgIndex(g_WProgUse, 538);
               DMemoB1.Visible := true;

               ShowEditMail;
         end;

      end;

   end;
end;

procedure TFrmDlg.DFrdWhisperClick(Sender: TObject; X, Y: Integer);
var
   wisname : string;
   actionchar : char;
begin

     if ViewFriends then
     begin
         if CurrentFriend >= 0 then
             wisname := PTFriend(FriendMembers[CurrentFriend]).CharID
         else
            Exit;
     end
     else
     begin
         if CurrentBlack >= 0 then
            wisname := PTFriend(BlackMembers[CurrentBlack]).CharID
         else
            Exit;
     end;

     PlayScene.EdChat.Visible := FALSE;
     FrmMain.WhisperName := wisname;
     if FrmMain.WhisperName = Copy(fLover.GetDisplay(0), length(STR_LOVER)+1, 20) then
        actionchar := ','
     else actionchar := '/';
     FrmMain.FormKeyPress(Sender, actionchar);
end;


procedure TFrmDlg.DMemoDirectPaint(Sender: TObject;
  dsurface: TDirectDrawSurface);
var
   d : TDirectDrawSurface;
   b : TDirectDrawSurface;
   lx, ly, n, t, l, ax, ay : integer;
   Rect : TRect;
begin
//     if not (Sender As TDWindow).CanFocus then MemoMail.Visible := false
//     else MemoMail.Visible := true;
(*
     case ViewWindowNo of
      VIEW_MAILREAD:
            begin
//            memoMail.Left  := DMemo.Left+28;
//            memoMail.Top   := DMemo.Top+36+14;

            memoMail.Left  := DMemo.Left+42;
            memoMail.Top   := DMemo.Top+62+14;

            memoMail.Width := 148;
            memoMail.Height:= 72 - 14;
            end;
      else
            begin
//            memoMail.Left := DMemo.Left+28;
//            memoMail.Top  := DMemo.Top+36;

            memoMail.Left := DMemo.Left+42;
            memoMail.Top  := DMemo.Top+62;

            memoMail.Width := 148;
            memoMail.Height := 72;
            end;
      end;

   with DMemo do begin
      d := WLib.Images[FaceIndex];
      if d <> nil then
         dsurface.Draw (SurfaceX(Left), SurfaceY(Top), d.ClientRect, d, TRUE);

      //ÀÌ¸§...ÂÊÁöº¸±â, ÂÊÁöº¸³»±â½Ã¿¡¸¸ Ãâ·Â, Ä£±¸µî·Ï½Ã´Â ÀÔ·Â¹Ú½º
      case ViewWindowNo of
      VIEW_FRIEND:  // Ä£±¸µî·Ï    À§: Ä£±¸¾ÆÀÌµð ÀÔ·Â, ¾Æ·¡: ¸Þ¸ð ÀÔ·Â
          begin
          b := g_WProgUse.GetCachedImage (549+1, ax, ay);
          end;
      VIEW_MAILSEND:  // ÂÊÁöº¸³»±â  À§: ¹Þ´Â»ç¶÷ Ãâ·Â, ¾Æ·¡: ÂÊÁö ³»¿ë ÀÔ·Â
          begin
          b := g_WProgUse.GetCachedImage (549+2, ax, ay);

          with dsurface.Canvas do begin
             SetBkMode (Handle, TRANSPARENT);
             Font.Color := clSilver;
//             MemoCharID := PTFriend(FriendMembers[ViewWindowData]).CharID;
             TextOut (SurfaceX(Left + 150 - TextWidth(MemoCharID) div 2),
                      SurfaceY(Top + 39), MemoCharID);
             Release;
          end;
          end;
      VIEW_MAILREAD:  // ÂÊÁöº¸±â    À§: º¸³½»ç¶÷ Ãâ·Â, ¾Æ·¡: ÂÊÁö ³»¿ë Ãâ·Â
          begin
          b := g_WProgUse.GetCachedImage (549+3, ax, ay);

          with dsurface.Canvas do begin
//             SetBkMode (Handle, TRANSPARENT);
             Brush.Style := bsSolid;
             Brush.Color := clGray;
             Font.Color  := clWhite;
             TextOut (SurfaceX(Left + 42),
                      SurfaceY(Top + 62), MemoDate);

             Brush.Style := bsClear;
             Font.Color := clSilver;
//             MemoCharID := PTMail(MailLists[ViewWindowData]).Sender;
             TextOut (SurfaceX(Left + 150 - TextWidth(MemoCharID) div 2),
                      SurfaceY(Top + 39), MemoCharID);
             Release;
          end;

          end;
      VIEW_MEMO:  // Ä£±¸Á¤º¸    À§: Ä£±¸¾ÆÀÌµð Ãâ·Â. ¾Æ·¡: ¸Þ¸ð ÀÔ·Â
          begin
          b := g_WProgUse.GetCachedImage (549+1, ax, ay);

          with dsurface.Canvas do begin
             SetBkMode (Handle, TRANSPARENT);
             Font.Color := clSilver;
//             MemoCharID := PTFriend(FriendMembers[ViewWindowData]).CharID;
//             TextOut (SurfaceX(Left + 140 - TextWidth(MemoCharID) div 2),
//                      SurfaceY(Top + 13), MemoCharID);
             TextOut (SurfaceX(Left + 150 - TextWidth(MemoCharID) div 2),
                      SurfaceY(Top + 39), MemoCharID);

             Release;
          end;
          end;
      end;

//      dsurface.Draw (SurfaceX(Left+9), SurfaceY(Top+7), b.ClientRect, b, TRUE);
      dsurface.Draw (SurfaceX(Left+25), SurfaceY(Top+34), b.ClientRect, b, TRUE);

      SetBkMode (dsurface.Canvas.Handle, TRANSPARENT);
      dsurface.Canvas.Font.Color  := clSilver;
      if n = CurrentBlock then
         dsurface.Canvas.Brush.Color := clGray
      else
         dsurface.Canvas.Brush.Color := clBlack;

      dsurface.Canvas.Release;
   end;  *)
end;

procedure TFrmDlg.ShowEditMail;
var
   d: TDirectDrawSurface;
   i: integer;
   data: string;
begin
   with DMemo do begin

      d := WLib.Images[FaceIndex];
      if d <> nil then begin
//         Left := (SCREENWIDTH - d.Width) div 2;
//         Top := (SCREENHEIGHT - d.Height) div 2;
      end;
      HideAllControls;

      //¸Þ¸ðÃ¢ Å©±â ¼³Á¤
{
      case ViewWindowNo of
      VIEW_MAILREAD:
            begin
            memoMail.Left  := SurfaceX(Left+21);
            memoMail.Top   := SurfaceY(Top+36+14);
            memoMail.Width := 146;
            memoMail.Height:= 72 - 14;
            end;
      else
            begin
            memoMail.Left := SurfaceX(Left+21);
            memoMail.Top  := SurfaceY(Top+36);
            memoMail.Width := 146;
            memoMail.Height := 72;
            end;
      end;
}
      // ¸Þ¸ð º¯°æÀÎ °æ¿ì ±âÁ¸ ¸Þ¸ð¸¦ ´ëÀÔ
      if ViewWindowNo = VIEW_MEMO then
      begin
         BackupMemoMail := memoMail.Text;
      end;
      memomail.MaxLength := 80;
      if not memoMail.visible then memoMail.Visible := TRUE;


      SetImeMode (MemoMail.Handle, imSHanguel);
      DMemo.Show;


      while TRUE do begin
         if not DMemo.Visible then break;
//         FrmMain.ProcOnIdle;
         Application.ProcessMessages;
         if Application.Terminated then exit;
      end;

      DMemo.Visible := FALSE;
      RestoreHideControls;

      if DMsgDlg.DialogResult = mrOk then begin
         //°á°ú... ¹®ÆÄ°øÁö»çÇ×À» ¾÷µ¥ÀÌÆ® ÇÑ´Ù.
         data := '';
         for i:=0 to Memo.Lines.Count-1 do begin
            if Memo.Lines[i] = '' then
               data := data + Memo.Lines[i] + ' '#13
            else data := data + Memo.Lines[i] + #13;
         end;
         data := ConvertEscChar(data);
         if Length(data) > 70 then begin
            data := Copy (data, 1, 70);
            DMessageDlg ('¹®ÀÚ¿­ÀÌ ³Ê¹« ±æ¾î¼­ µÚ¿¡ ºÎºÐÀÌ Â©·È½À´Ï´Ù.', [mbOk]);
         end;
         //case ViewWindowNo of
         //1: FrmMain.SendAddFriend (data);
         //2: FrmMain.SendMail (data);
         //3: begin end;
         //4: FrmMain.SendUpdateFriend (data);
         //end;
      end;
   end;
end;

function TFrmDlg.ConvertEscChar(str : String) : string;
begin
   // Convert...
   Result := str;
end;

procedure TFrmDlg.DMemoCloseClick(Sender: TObject; X, Y: Integer);
begin
   DMemo.Visible        := FALSE;
   case ViewWindowNo of
   VIEW_FRIEND:
      begin
        edCharID.Visible     := FALSE;
        memoMail.Visible     := FALSE;
        memoMail.ReadOnly    := FALSE;
      end;
   VIEW_MAILSEND:
      begin
        edCharID.Visible     := FALSE;
        memoMail.Visible     := FALSE;
        memoMail.ReadOnly    := FALSE;
      end;
   VIEW_MAILREAD:
      begin
        memoMail.Visible     := FALSE;
        memoMail.ReadOnly    := FALSE;
      end;
   VIEW_MEMO:
      begin
        memoMail.Visible     := FALSE;
        memoMail.ReadOnly    := FALSE;
      end;
   end;
   DMsgDlg.DialogResult := mrCancel;

   SetImeMode (PlayScene.EdChat.Handle, LocalLanguage);
end;


procedure TFrmDlg.DMemoB1DirectPaint(Sender: TObject;
  dsurface: TDirectDrawSurface);
var
   d: TDirectDrawSurface;
begin
   with Sender as TDButton do begin

      if TDButton(Sender).Downed then
         d := WLib.Images[FaceIndex+1]
      else
         d := WLib.Images[FaceIndex];

      if d <> nil then
         dsurface.Draw (SurfaceX(Left), SurfaceY(Top), d.ClientRect, d, TRUE);

   end;

end;

procedure TFrmDlg.DMemoB2DirectPaint(Sender: TObject;
  dsurface: TDirectDrawSurface);
var
   d: TDirectDrawSurface;
begin
   with Sender as TDButton do begin

      if TDButton(Sender).Downed then
         d := WLib.Images[FaceIndex+1]
      else
         d := WLib.Images[FaceIndex];

      if d <> nil then
         dsurface.Draw (SurfaceX(Left), SurfaceY(Top), d.ClientRect, d, TRUE);

   end;

end;

procedure TFrmDlg.DMemoB1Click(Sender: TObject; X, Y: Integer);
begin

  // °¢°¡ÀÇ »óÈ²ÀÏ‹š OK µ¿ÀÛ Á¤ÀÇ
   case ViewWindowNo of
   VIEW_FRIEND:
               begin

               end;
   VIEW_MAILSEND:
               begin
               if MemoMail.Text <> '' then begin
                  if frmDlg.BoMemoJangwon then
                     FrmMain.SendMail( MemoCharID +'/'+ MemoCharID2 +'/'+ StrToSqlSafe(MemoMail.Text) )
                  else FrmMain.SendMail( MemoCharID +'/' + StrToSqlSafe(MemoMail.Text) );
               end
               else frmDlg.BoMemoJangwon := False;

               end;
   VIEW_MAILREAD:
               begin

               end;
   VIEW_MEMO:
               begin
               if BackupMemoMail <> MemoMail.Text then
                  FrmMain.SendUpdateFriend ( MemoCharID + '/' + StrToSqlSafe(MemoMail.Text));
               end;
   end;

   edCharID.Visible     := FALSE;
   MemoMail.Visible     := FALSE;
   DMemo.Visible        := FALSE;
   MemoMail.ReadOnly    := FALSE;

   DMsgDlg.DialogResult := mrOK;

   SetImeMode (PlayScene.EdChat.Handle, LocalLanguage);

end;

procedure TFrmDlg.DBLAddClick(Sender: TObject; X, Y: Integer);
begin
   DMessageDlg ('°ÅºÎÀÚ·Î µî·ÏÇÒ »ç¶÷ÀÇ ÀÌ¸§À» ÀÔ·ÂÇÏ½Ê½Ã¿À', [mbOk, mbAbort]);
   if DlgEditText <> '' then
   begin
      FrmMain.SendAddReject (DlgEditText );
   end;

end;

procedure TFrmDlg.DBLDelClick(Sender: TObject; X, Y: Integer);
begin
   if mrOk = FrmDlg.DMessageDlg ('»èÁ¦ ÇÏ½Ã°Ú½À´Ï±î?', [mbOk, mbCancel]) then
   begin
      FrmMain.SendDelReject ( BlockLists[CurrentBlock] );
   end;
end;

procedure TFrmDlg.DMLReplyClick(Sender: TObject; X, Y: Integer);
begin
//   if (not DMemo.Visible) then
  begin
      ViewWindowNo   := VIEW_MAILSEND;
      ViewWindowData := CurrentMail;
      DMemoB1.SetImgIndex(g_WProgUse, 548);
      DMemoB2.SetImgIndex(g_WProgUse, 538);
      DMemoB1.Visible := true;
      MemoMail.Clear;
      MemoMail.ReadOnly := false;
      MemoCharID := PTMail(MailLists[CurrentMail]).Sender;
      ShowEditMail;
   end;

end;

procedure TFrmDlg.DMLDelClick(Sender: TObject; X, Y: Integer);
begin
   if pTMail(MailLists[CurrentMail]).Status = 2 then
   begin
     FrmDlg.DMessageDlg ('»èÁ¦±ÝÁö»óÅÂÀÔ´Ï´Ù »èÁ¦ÇÒ ¼ö ¾ø½À´Ï´Ù.', [mbOk] );
     exit;
   end;

   if pTMail(MailLists[CurrentMail]).Status = 3 then
   begin
     FrmDlg.DMessageDlg ('ÀÌ¹Ì »èÁ¦µÇ¾ú½À´Ï´Ù.', [mbOk] );
     exit;
   end;

   if mrOk = FrmDlg.DMessageDlg ('»èÁ¦ ÇÏ½Ã°Ú½À´Ï±î?', [mbOk, mbCancel]) then
   begin
      FrmMain.SendDelMail ( pTMail(MailLists[CurrentMail]).Date );
   end;

end;

procedure TFrmDlg.DMLLockClick(Sender: TObject; X, Y: Integer);
var
   IsLock : Boolean;
   mstate : Byte;
begin
      mstate := pTMail(MailLists[CurrentMail]).Status;

      // »èÁ¦µÈ ³ÑÀÌ¸é Àá±Û¼ö ¾øÀ½
      if ( mstate = 3 ) then exit ;

      if ( mstate = 2 ) then IsLock := TRUE
      else IsLock := FALSE;

      if IsLock then
      FrmMain.SendUnLockMail ( pTMail(MailLists[CurrentMail]).Date )
      else
      FrmMain.SendLockMail ( pTMail(MailLists[CurrentMail]).Date )
end;


procedure TFrmDlg.DFrdPgUpMouseMove(Sender: TObject; Shift: TShiftState; X,
  Y: Integer);
var
   lx, ly : integer;
   sx, sy : integer;
begin
   with (Sender As TDbutton) do begin
      lx := LocalX (X - Left);
      ly := LocalY (Y - Top);
      sx := SurfaceX(Left)+DFriendDlg.SurfaceX(DFriendDlg.Left)+lx+8;
      sy := SurfaceY(Top) +DFriendDlg.SurfaceX(DFriendDlg.Top) +ly+6;
      DScreen.ShowHint(sx, sy, (Sender As TDbutton).Hint, clYellow, FALSE);
   end;

end;

procedure TFrmDlg.DFrdPgDnMouseMove(Sender: TObject; Shift: TShiftState; X,
  Y: Integer);
var
   lx, ly : integer;
   sx, sy : integer;
begin
   with (Sender As TDbutton) do begin
      lx := LocalX (X - Left);
      ly := LocalY (Y - Top);
      sx := SurfaceX(Left)+DFriendDlg.SurfaceX(DFriendDlg.Left)+lx+8;
      sy := SurfaceY(Top) +DFriendDlg.SurfaceX(DFriendDlg.Top) +ly+6;
      DScreen.ShowHint(sx, sy, (Sender As TDbutton).Hint, clYellow, FALSE);
   end;

end;

procedure TFrmDlg.DMailListPgUpMouseMove(Sender: TObject;
  Shift: TShiftState; X, Y: Integer);
var
   lx, ly : integer;
   sx, sy : integer;
begin
   with (Sender As TDbutton) do begin
      lx := LocalX (X - Left);
      ly := LocalY (Y - Top);
      sx := SurfaceX(Left)+DMailListDlg.SurfaceX(DMailListDlg.Left)+lx+8;
      sy := SurfaceY(Top) +DMailListDlg.SurfaceX(DMailListDlg.Top) +ly+6;
      DScreen.ShowHint(sx, sy, (Sender As TDbutton).Hint, clYellow, FALSE);
   end;

end;

procedure TFrmDlg.DMailListPgDnMouseMove(Sender: TObject;
  Shift: TShiftState; X, Y: Integer);
var
   lx, ly : integer;
   sx, sy : integer;
begin
   with (Sender As TDbutton) do begin
      lx := LocalX (X - Left);
      ly := LocalY (Y - Top);
      sx := SurfaceX(Left)+DMailListDlg.SurfaceX(DMailListDlg.Left)+lx+8;
      sy := SurfaceY(Top) +DMailListDlg.SurfaceX(DMailListDlg.Top) +ly+6;
      DScreen.ShowHint(sx, sy, (Sender As TDbutton).Hint, clYellow, FALSE);
   end;

end;

procedure TFrmDlg.DBLPgUpMouseMove(Sender: TObject; Shift: TShiftState; X,
  Y: Integer);
var
   lx, ly : integer;
   sx, sy : integer;
begin
   with (Sender As TDbutton) do begin
      lx := LocalX (X - Left);
      ly := LocalY (Y - Top);
      sx := SurfaceX(Left)+DBlockListDlg.SurfaceX(DBlockListDlg.Left)+lx+8;
      sy := SurfaceY(Top) +DBlockListDlg.SurfaceX(DBlockListDlg.Top) +ly+6;
      DScreen.ShowHint(sx, sy, (Sender As TDbutton).Hint, clYellow, FALSE);
   end;

end;

procedure TFrmDlg.DBLPgDnMouseMove(Sender: TObject; Shift: TShiftState; X,
  Y: Integer);
var
   lx, ly : integer;
   sx, sy : integer;
begin
   with (Sender As TDbutton) do begin
      lx := LocalX (X - Left);
      ly := LocalY (Y - Top);
      sx := SurfaceX(Left)+DBlockListDlg.SurfaceX(DBlockListDlg.Left)+lx+8;
      sy := SurfaceY(Top) +DBlockListDlg.SurfaceX(DBlockListDlg.Top) +ly+6;
      DScreen.ShowHint(sx, sy, (Sender As TDbutton).Hint, clYellow, FALSE);
   end;

end;

procedure TFrmDlg.DFriendDlgMouseMove(Sender: TObject; Shift: TShiftState;
  X, Y: Integer);
var
   lx, ly : integer;
   sx, sy : integer;
begin
   if (Sender As TDWindow).hint = '' then DScreen.ClearHint
   else
   begin
      with (Sender As TDWindow) do
      begin
         if ViewFriends then
         begin
              lx := 39  +(CurrentFriend mod 2) * 120;
              ly := 108 +((CurrentFriend mod 20 ) div 2) * 15;
         end
         else
         begin
              lx := 39 + (CurrentBlack  mod 2) * 120;
              ly := 108 +((CurrentBlack mod 20 ) div 2) * 15;
         end;

         sx := SurfaceX(Left) + lx;
         sy := SurfaceY(Top)  + ly;
         DScreen.ShowHint(sx, sy, (Sender As TDWindow).Hint, clWhite, FALSE);
      end;
   end;
end;

procedure TFrmDlg.DMailListDlgMouseMove(Sender: TObject;
  Shift: TShiftState; X, Y: Integer);
begin
     DScreen.ClearHint;
end;

procedure TFrmDlg.DMailDlgMouseMove(Sender: TObject; Shift: TShiftState; X,
  Y: Integer);
begin
     DScreen.ClearHint;
end;

procedure TFrmDlg.DBlockListDlgMouseMove(Sender: TObject;
  Shift: TShiftState; X, Y: Integer);
begin
     DScreen.ClearHint;
end;

procedure TFrmDlg.DMemoMouseMove(Sender: TObject; Shift: TShiftState; X,
  Y: Integer);
begin
     DScreen.ClearHint;
end;

procedure TFrmDlg.DMakeItemDlgOkDirectPaint(Sender: TObject;
  dsurface: TDirectDrawSurface);
var
   d : TDirectDrawSurface;
begin
   with Sender as TDButton do begin
      if Downed then begin
         d := WLib.Images[FaceIndex];
         dsurface.Draw (SurfaceX(Left), SurfaceY(Top), d.ClientRect, d, TRUE);
      end;
   end;
end;

procedure TFrmDlg.DCountDlgDirectPaint(Sender: TObject;
  dsurface: TDirectDrawSurface);
var
  d, dr: TDirectDrawSurface;
  ly, px, py, i: integer;
  str, data: string;
begin
   with Sender as TDWindow do begin
      d := WLib.Images[FaceIndex];
      if d <> nil then
         dsurface.Draw (SurfaceX(Left), SurfaceY(Top), d.ClientRect, d, TRUE);

      ly := msgly;
      str := MsgText;
      while TRUE do begin
         if str = '' then break;
         str := GetValidStr3 (str, data, ['\']);
         if data <> '' then
            g_DXCanvas.BoldTextOut (SurfaceX(Left+msglx), SurfaceY(Top+ly), clWhite, data);
         ly := ly + 14;
      end;
   end;
      if not EdCountEdit.Visible then begin
         EdCountEdit.Visible := TRUE;
         EdCountEdit.SetFocus;
      end;
end;

function  TFrmDlg.DCountMsgDlg (msgstr: string; DlgButtons: TMsgDlgButtons): TModalResult;
var
//   lx, ly, i: integer;
   d: TDirectDrawSurface;
begin

   msglx := 44;
   msgly := 46;
//   lx := 205;
//   ly := 139;

   d := g_WProgUse.Images[660];
   if d <> nil then begin
      DCountDlg.SetImgIndex (g_WProgUse, 660);
      DCountDlg.Left := (SCREENWIDTH - d.Width) div 2;
      DCountDlg.Top := (SCREENHEIGHT - d.Height) div 2;
      DCountDlg.Visible := True;
   end;


   MsgText := msgstr;
   DCountDlg.Floating := False;
   DCountDlg.Left := (SCREENWIDTH - DCountDlg.Width) div 2;
   DCountDlg.Top := (SCREENHEIGHT - DCountDlg.Height) div 2;
   DCountDlg.Visible := True;

   DCountDlgCancel.Left := 199;//lx;
   DCountDlgCancel.Top := 139;//ly;
   DCountDlgCancel.Visible := TRUE;
//   lx := lx - 69;

   DCountDlgOk.Left := 128;//lx;
   DCountDlgOk.Top := 139;//ly;
   DCountDlgOk.Visible := TRUE;
//   lx := lx - 69;

   DCountDlgMax.Left := 57;//lx;
   DCountDlgMax.Top := 139;//ly;
   DCountDlgMax.Visible := TRUE;

   DCountDlgClose.Left := 298;
   DCountDlgClose.Top  := 5;
   DCountDlgClose.Visible := True;

   HideAllControls;
   DCountDlg.ShowModal;

   with EdCountEdit do begin
      Text := '';
      Width := DCountDlg.Width - 91;
      Left := DCountDlg.Left+43;//(SCREENWIDTH - EdCountEdit.Width) div 2 - 8;
      Top  := DCountDlg.Top+104;//(SCREENHEIGHT - EdCountEdit.Height) div 2 + 13;
   end;

   Result := mrOk;

  while TRUE do begin
      if not DCountDlg.Visible then break;
//      FrmMain.ProcOnIdle;
      Application.ProcessMessages;
      if Application.Terminated then exit;
   end;

   EdCountEdit.Visible := TRUE;
   RestoreHideControls;
   DlgEditText := EdCountEdit.Text;
   if PlayScene.EdChat.Visible then PlayScene.EdChat.SetFocus;

   EdCountEdit.Visible := FALSE;
   Result := DCountDlg.DialogResult;
end;


procedure TFrmDlg.DCountDlgOkDirectPaint(Sender: TObject;
  dsurface: TDirectDrawSurface);
var
   d : TDirectDrawSurface;
begin
   with Sender as TDButton do begin
      if Downed then begin
         d := WLib.Images[FaceIndex];
         if d <> nil then
            dsurface.Draw (SurfaceX(Left), SurfaceY(Top), d.ClientRect, d, TRUE);
      end;
   end;
end;

procedure TFrmDlg.DCountDlgOkClick(Sender: TObject; X, Y: Integer);
begin
   if Sender = DCountDlgMax then begin
      EdCountEdit.Text := IntToStr(Total);
      DlgEditText := EdCountEdit.Text;
      DCountDlg.DialogResult := mrAll;
   end;
   if Sender = DCountDlgOk then DCountDlg.DialogResult := mrOk;
   if Sender = DCountDlgCancel then DCountDlg.DialogResult := mrCancel;
   if Sender <> DCountDlgMax then begin
      EdCountEdit.Visible := False;
      DCountDlg.Visible := False;
   end;


end;

procedure TFrmDlg.DCountDlgCloseClick(Sender: TObject; X, Y: Integer);
begin
   DCountDlg.DialogResult := mrCancel;
   DCountDlg.Visible := False;
   DCountDlgClose.Downed := False;
end;
procedure TFrmDlg.DMakeItemDlgOkClick(Sender: TObject; X, Y: Integer);
var
   data : string;
begin

   if Sender = DMakeItemDlgOk then begin
      DMakeItemDlg.DialogResult := mrOk;
      data := NameMakeItem;
      data := data + '/' + MakeStrMakeItem();
      FrmMain.SendMakeItem(CurMerchant, data);
   end;
   if (Sender = DMakeItemDlgCancel) or (Sender = DMakeItemDlgClose) then begin
      DMakeItemDlg.DialogResult := mrCancel;
   end;
   MoveMakeItemToBag;

   DMakeItemDlg.Visible := False;
   DMakeItemDlgClose.Downed := False;

end;
procedure TFrmDlg.DMakeItemDlgDirectPaint(Sender: TObject;
  dsurface: TDirectDrawSurface);
var
   d: TDirectDrawSurface;
begin
   if Myself = nil then exit;
   with DMakeItemDlg do begin
      d := WLib.Images[FaceIndex];
      if d <> nil then
         dsurface.Draw (SurfaceX(Left), SurfaceY(Top), d.ClientRect, d, TRUE);

//      GetMouseItemInfo (d0, d1, d2, d3, useable, FALSE);
      with g_DXCanvas do begin
         TextOut (SurfaceX(Left+32), SurfaceY(Top+72), clWhite, 'Àç·á ¾ÆÀÌÅÛÀ» ¿Ã·Á ³õÀ¸¼¼¿ä.');
      end;
   end;
end;

function  TFrmDlg.MakeItemDlgShow ( msgstr: string ): TModalResult;
var
   i: integer;
begin

   DMakeItemDlg.Left := 212;//140;//291;
   DMakeItemDlg.Top  := 176;//176;

   DMakeItemDlg.Visible := True;

   //¾ÆÀÌÅÛ °¡¹æ¿¡ ÀÜ»óÀÌ ÀÖ´ÂÁö °Ë»ç
   ArrangeItembag;

end;
procedure TFrmDlg.DMakeitemGridGridPaint(Sender: TObject; ACol,
  ARow: Integer; Rect: TRect; State: TGridDrawState;
  dsurface: TDirectDrawSurface);
var
   idx: integer;
   d: TDirectDrawSurface;
begin
   idx := ACol + ARow * DMakeitemGrid.ColCount;
   if idx in [0..5] then begin
      if MakeItemArr[idx].S.Name <> '' then begin
         d := g_WBagItem.Images[MakeItemArr[idx].S.Looks];
         if d <> nil then
            with DMakeitemGrid do
               dsurface.Draw (SurfaceX(Rect.Left + (ColWidth - d.Width) div 2 - 1),
                              SurfaceY(Rect.Top + (RowHeight - d.Height) div 2 + 1),
                              d.ClientRect,
                              d, TRUE);
            // ¾ÆÀÌÅÛ °ãÄ¡±â
            if MakeItemArr[idx].S.OverlapItem > 0 then begin
               g_DXCanvas.TextOut (DMakeitemGrid.SurfaceX(Rect.Left +20), DMakeitemGrid.SurfaceY(Rect.Top +20),
                                        clYellow, IntToStr(MakeItemArr[idx].Dura));
            end;
      end;
   end;

end;


procedure TFrmDlg.DMakeitemGridGridSelect(Sender: TObject; X, Y: Integer; ACol,
  ARow: Integer; Shift: TShiftState);
var
   temp: TClientItem;
   mi, idx: integer;
   MsgResult, Count, OrgCount : integer;
   valstr : String;
begin
   MsgResult := mrCancel;
   if not ItemMoving then begin
      idx := ACol + ARow * DMakeitemGrid.ColCount;
      if idx in [0..5] then begin
         if MakeItemArr[idx].S.Name <> '' then begin
            ItemMoving := TRUE;
            MovingItem.Item := MakeItemArr[idx];
            MakeItemArr[idx].S.Name := '';
            ItemClickSound (MovingItem.Item.S);
         end;
      end;
   end else begin
      mi := MovingItem.Index;
      if mi >= 6 then begin //°¡¹æ,¿¡¼­ ¿Â°Í¸¸

         if SearchOverlapItem(MovingItem.Item) then begin
            CancelItemMoving;
            DMessageDlg ('°°ÀºÁ¾·ùÀÇ °ãÄ¡±â °¡´ÉÇÑ ¾ÆÀÌÅÛÀº ÇÑ¹ø¹Û¿¡ ¿Ã¸± ¼ö ¾ø½À´Ï´Ù.', [mbOk]);
            Exit;
         end;

         ItemClickSound (MovingItem.Item.S);
         OrgCount := MovingItem.Item.Dura;
         MakingDlgItem := MovingItem.Item; //¼­¹ö¿¡ °á°ú¸¦ ±â´Ù¸®´Âµ¿¾È º¸°ü
         if MakingDlgItem.S.OverlapItem > 0 then begin
            Total := MovingItem.Item.Dura;
            ItemMoving := FALSE;
            if Total = 1 then begin
               DlgEditText := '1';
               MsgResult := mrOk;
            end
            else MsgResult := DCountMsgDlg ('ÃÑ '+ IntToStr(MovingItem.Item.Dura) +
                                      '°³Áß ¸î°³¸¦ ¿Ã·Á³õ°Ú½À´Ï±î?', [mbOk, mbCancel, mbAbort]);

            ItemMoving := TRUE;
            GetValidStrVal (DlgEditText, valstr, [' ']);
            Count := Str_ToInt (valstr, 0);
            if Count <= 0 then begin
               Count := 0;
               MakingDlgItem.S.Name := '';
            end;
            if Count > MovingItem.Item.Dura then begin
               Count := MovingItem.Item.Dura;
//                  MovingItem.Item.Dura := 0;
            end;
            if MsgResult = mrOk then begin //and (Count > 0) and (Count < MAX_OVERLAPITEM+1 ) then begin
               MakingDlgItem.Dura := word(Count);
               MovingItem.Item.Dura := MovingItem.Item.Dura - Count;
               if MovingItem.Item.Dura = 0 then begin
                  MovingItem.Item.S.name := '';
                  ItemMoving := FALSE;
               end;
            end
            else if MsgResult = mrCancel then begin
               CancelItemMoving;
               Exit;
            end;
         end;
         if (not AddMakeItem(MakingDlgItem)) and (MakingDlgItem.S.OverlapItem > 0) then begin
            MovingItem.Item.Dura := OrgCount;
         end;
         if ItemMoving then
         CancelItemMoving;
      end;
   end;
   ArrangeItemBag;

end;

procedure TFrmDlg.DMakeitemGridGridMouseMove(Sender: TObject; X, Y: Integer; ACol,
  ARow: Integer; Shift: TShiftState);
var
   idx: integer;
begin
   idx := ACol + ARow * DMakeitemGrid.ColCount;
   if idx in [0..5] then begin
      MouseItem := MakeItemArr[idx];
   end;
end;


procedure TFrmDlg.DItemMarketDlgDirectPaint(Sender: TObject;
  dsurface: TDirectDrawSurface);
  function SX(x: integer): integer;
  begin
      Result := DItemMarketDlg.SurfaceX (DItemMarketDlg.Left + x);
  end;
  function SY(y: integer): integer;
  begin
      Result := DItemMarketDlg.SurfaceY (DItemMarketDlg.Top + y);
  end;
var
   i, lh, k, m, n, menuline: integer;
   d, TempSurface: TDirectDrawSurface;
   pg: PTMarketITem;
   year, mon, day, hour, min, datestr: string;
   targdate: TDateTime;
   iname, d0, d1, d2, d3, pagestr: string;
   useable: Boolean;
   MouseItemTemp : TClientItem;
   FColor : TColor;
begin
   i := 0;
   pg := nil;

   with g_DXCanvas do begin
      with DItemMarketDlg do begin
         d := DItemMarketDlg.WLib.Images[FaceIndex];
         if d <> nil then
            dsurface.Draw (SurfaceX(Left), SurfaceY(Top), d.ClientRect, d, TRUE);
      end;

      FColor := clWhite;

      lh := MAKETLINEHEIGHT;
      menuline := _MIN(MAXMENU, g_Market.Count-MenuTop);

      if g_Market.GetUserMode = 1 then begin
         TextOut (SX(204),  SY(37), FColor, '¾ÆÀÌÅÛ ±¸¸Å');
         DMarketMemo.Visible := True;
      end
      else if g_Market.GetUserMode = 2 then begin
         TextOut (SX(204),  SY(37), FColor, 'À§Å¹ÇÑ ¾ÆÀÌÅÛ');
         DMarketMemo.Visible := False;
      end;

      TextOut (SX(379), SY(37), FColor, format('%4d',[(MenuTop+10) div 10]));
      if g_Market.RecvMaxPage < 1 then
         TextOut (SX(409), SY(37), FColor, '/ ' + '1')
      else TextOut (SX(409), SY(37), FColor, '/ ' + IntToStr(g_Market.RecvMaxPage));
//      TextOut (SX(504), SY(16), GetGoldStr(Myself.Gold));

      TextOut (SX(60),  SY(71), FColor, '¾ÆÀÌÅÛ');
      TextOut (SX(230), SY(71), FColor, '°¡  °Ý');
      if g_Market.GetUserMode = 2 then TextOut (SX(382), SY(71), FColor, 'ÆÇ¸Å»óÅÂ')
      else TextOut (SX(382), SY(71), FColor, 'ÆÇ¸ÅÀÚ');

      for i:=MenuTop to MenuTop+menuline-1 do begin
         m := i-MenuTop;
         pg := g_Market.GetItem( i );

         if i = MenuIndex then begin
            FColor := clRed;
            TextOut (SX(53),  SY(97 + m*lh), FColor, char(7));
            MemoCharID := pg.SellWho;
         end else if pg.SellState = 2 then
            FColor := clYellow
         else if pg.UpgCount > 0 then
            FColor := clAqua
         else FColor := clWhite;

         if pg <> nil then
         begin
            TextOut (SX(60),  SY(97 + MAKETLINEHEIGHT * m), FColor, pg.Item.S.Name);
            TextOut (SX(196), SY(97 + MAKETLINEHEIGHT * m), FColor, format('%15s',[GetGoldStr(pg.SellPrice)]));
            if g_Market.GetUserMode = 2 then begin
               if pg.SellState = 1 then
                  TextOut (SX(382), SY(97 + MAKETLINEHEIGHT * m), FColor, 'ÆÇ¸ÅÁß')
               else if pg.SellState = 2 then
                  TextOut (SX(382), SY(97 + MAKETLINEHEIGHT * m), FColor, 'ÆÇ¸Å¿Ï·á');
            end
            else TextOut (SX(382), SY(97 + MAKETLINEHEIGHT * m), FColor, pg.SellWho);
         end;
      end;
      FColor := clWhite;
      if (MenuIndex >= 0) and (MenuIndex < g_Market.Count) then begin
         pg := g_Market.GetItem( MenuIndex );
         year := Copy(pg.Selldate,1,2);
         mon  := Copy(pg.Selldate,3,2);
         day  := Copy(pg.Selldate,5,2);
         hour := Copy(pg.Selldate,7,2);
         min  := Copy(pg.Selldate,9,2);
         datestr := '20' + year + '-' + mon + '-' + day + ' ' + hour + ':' + min;
         TextOut (SX(44),  SY(304), FColor, 'µî·ÏÀÏ: '+ datestr);
         targdate := EncodeDate (StrToInt(year)+2000, StrToInt(mon), StrToInt(day)) +
                     EncodeTime (StrToInt(hour), StrToInt(min), 0, 0);
         targdate := targdate+ 100;
         TextOut (SX(44),  SY(320), FColor, '»èÁ¦ÀÏ: '+ FormatDateTime('YYYY-MM-DD',targdate));
      end;

      if (MenuIndex >= 0) and (MenuIndex < g_Market.Count) then begin
         MouseItemTemp := MouseItem;
         MouseItem := pg.item;
         with DItemMarketDlg do begin
            GetMouseItemInfo (iname, d0, d1, d2, d3, useable, FALSE);
            MouseItem := MouseItemTemp;
//            SetBkMode (Handle, TRANSPARENT);

            if iname <> '' then begin
               Font.Color := clYellow;
               TextOut (SX(249), SY(298), FColor, iname);
               n := TextWidth (iname);
               Font.Color := clWhite;
               TextOut (SX(249) + n, SY(298), FColor, d0);
               TextOut (SX(249), SY(298+14), FColor, d1);
               TextOut (SX(249), SY(298+14*2), FColor, d2);
               if not useable then
                  Font.Color := clRed;
               n := TextWidth (d2);
               TextOut (SX(249) + n, SY(299+14*2), FColor, d3);
            end;
         end;
      end;
   end;

   if (MenuIndex >= 0) and (MenuIndex < g_Market.Count) then begin
      pg := g_Market.GetItem( MenuIndex );
      TempSurface := g_WBagItem.Images[pg.Item.S.Looks];
      if TempSurface <> nil then
         dsurface.Draw (SX(196)+(36-TempSurface.Width) div 2,
                        SY(303)+(32-TempSurface.Height) div 2,
                        TempSurface.ClientRect, TempSurface, TRUE);
//         dsurface.Draw (SX(173), SY(275), TempSurface.ClientRect, TempSurface, TRUE);
   end;

   if ( ItemSearchEdit.Left <> SX(39)) or (ItemSearchEdit.Top <> SY(355) ) then
   begin
      ItemSearchEdit.Left := SX(39);
      ItemSearchEdit.Top  := SY(355);
   end;

//   DScreen.ClearHint;
//   MouseStateItem.S.Name := '';

end;

procedure TFrmDlg.DItemMarketDlgClick(Sender: TObject; X, Y: Integer);
var
   lx, ly, idx: integer;
   pg: PTMarketITem;
begin

   pg := nil;
   lx := DItemMarketDlg.LocalX (X) - DItemMarketDlg.Left;
   ly := DItemMarketDlg.LocalY (Y) - DItemMarketDlg.Top;
   if (lx >= 36) and (lx <= 477) and (ly >= 92) and (ly <= 282) then begin
      idx := (ly-97) div MAKETLINEHEIGHT + MenuTop;
      if idx < g_Market.Count then begin
         PlaySound (s_glass_button_click);
         MenuIndex := idx;
      end;
   end;

   if (MenuIndex >= 0) and (MenuIndex < g_Market.Count) then begin
      pg := g_Market.GetItem( MenuIndex );
      if pg.SellState = 1 then MItemSellState := 1 // ÆÇ¸ÅÁß
      else if pg.SellState = 2 then MItemSellState := 2; // ÆÇ¸Å¿Ï·á
   end;

end;

procedure TFrmDlg.DItemMarketDlgMouseMove(Sender: TObject;
  Shift: TShiftState; X, Y: Integer);
begin
   if BoInRect then begin
//      DItemMarketDlg.SpotX := X;
//      DItemMarketDlg.SpotY := Y;
   end;
//   DScreen.ClearHint;
end;

procedure TFrmDlg.DItemListPrevClick(Sender: TObject; X, Y: Integer);
begin

   MenuIndex := -1;
   if MenuTop > 0 then begin
      Dec (MenuTop, MAXMENU);
      if MenuTop < 0 then MenuTop := 0;
   end;
   MenuIndex := MenuTop;
   DItemMarketDlgClick(DItemMarketDlg ,0 ,0);
end;

procedure TFrmDlg.DItemListNextClick(Sender: TObject; X, Y: Integer);
var
   MaxNum : integer;
begin

   MenuIndex := -1;
   MaxNum := (g_Market.RecvMaxPage) *10;
   if (MaxNum >= g_Market.Count) and (MaxNum >= (MenuTop+19)) then begin
      Inc (MenuTop, MAXMENU);
      if g_Market.Count <= MenuTop then
         FrmMain.SendGetMarketPageList (CurMerchant, 1, '')
   end;
   MenuIndex := MenuTop;
   DItemMarketDlgClick(DItemMarketDlg ,0 ,0);
end;

procedure TFrmDlg.DItemBuyClick(Sender: TObject; X, Y: Integer);
var
   pg: PTMarketITem;
   MsgResult : integer;
begin
   if GetTickCount < LastestClickTime then exit; //Å¬¸¯À» ÀÚÁÖ ¸øÇÏ°Ô Á¦ÇÑ
   DScreen.ClearHint;
   if (MenuIndex >= 0) and (MenuIndex < g_Market.Count) then begin
      ItemSearchEdit.Visible := False;
      pg := g_Market.GetItem( MenuIndex );
      if Myself.Gold < pg.SellPrice then begin
         MsgResult := DMessageDlg ('±ÝÀüÀÌ ºÎÁ·ÇÕ´Ï´Ù.', [mbOk, mbCancel]);
         Exit;
      end;
      MsgResult := DMessageDlg (pg.Item.S.Name+' ¾ÆÀÌÅÛÀ» '+IntToStr(pg.SellPrice)+'Àü¿¡ ±¸ÀÔÇÏ°Ú½À´Ï±î?', [mbOk, mbCancel]);

      if MsgResult = mrOk then begin
         FrmMain.SendBuyMarket (CurMerchant, pg.Index);
         DItemBag.Show;
      end
      else if MsgResult = mrCancel then begin
      end;
   end;
end;

procedure TFrmDlg.DItemMarketCloseClick(Sender: TObject; X, Y: Integer);
begin
   // À§Å¹¸ñ·ÏÃ¢ÀÌ ´ÝÈ÷¸é.. ¾ÆÀÌÅÛ Å¬¸®¾î ¹× ´ÝÇû´Ù°í ¼­¹ö¿¡ ¾Ë¸°´Ù.
   g_Market.Clear;
   FrmMain.SendMarketClose;

   ItemSearchEdit.Visible := FALSE;
   DItemMarketDlg.Visible := FALSE;
   DItemMarketClose.Downed := False;

//   PlayScene.EdChat.SetFocus;
   LocalLanguage := imSAlpha;
   SetImeMode (PlayScene.EdChat.Handle, LocalLanguage);
   LastestClickTime := GetTickCount;

   MemoCharID := '';

end;

procedure TFrmDlg.DMGoldDirectPaint(Sender: TObject;
  dsurface: TDirectDrawSurface);
var
  d: TDirectDrawSurface;
begin
   if Myself = nil then exit;
   if DMGold.Visible then begin
      with DMGold do begin
         d := WLib.Images[FaceIndex];
         if d <> nil then
            dsurface.Draw (SurfaceX(Left), SurfaceY(Top), d.ClientRect, d, TRUE);
      end;
   end;
end;

procedure TFrmDlg.DItemMarketDlgKeyDown(Sender: TObject; var Key: Word;
  Shift: TShiftState);
begin
   if Key = 27 then
      if DItemMarketDlg.Visible then CloseItemMarketDlg;

   if Key = 13 then
      DItemFindClick(DItemFind, 0, 0);

   DScreen.ClearHint;
   case key of
      VK_UP:
         begin
            if (MenuTop <= (MenuIndex-1)) and (MenuIndex <> -1) then begin
               Dec(MenuIndex, 1);
               DItemMarketDlgClick(DItemMarketDlg ,0 ,0);
            end;
         end;
      VK_DOWN:
         begin
            if (MenuTop+MAXMENU > (MenuIndex+1)) and (MenuIndex <> -1) and ((MenuIndex+1) < g_Market.Count) then begin
               Inc(MenuIndex, 1);
               DItemMarketDlgClick(DItemMarketDlg ,0 ,0);
            end;
         end;
      VK_LEFT:
         begin
            DItemListPrevClick( DItemListPrev, 0, 0);
         end;
      VK_RIGHT:
         begin
            DItemListNextClick( DItemListNext, 0, 0);
         end;
   else
   end;

end;

procedure TFrmDlg.DItemListRefreshClick(Sender: TObject; X, Y: Integer);
begin
   if GetTickCount < LastestClickTime then begin
      DScreen.AddChatBoardString ('Àá½Ã ÈÄ¿¡ ´Ù½Ã ´­·ÁÁÖ½Ê½Ã¿ä.',  clYellow, clRed);
      exit; //Å¬¸¯À» ÀÚÁÖ ¸øÇÏ°Ô Á¦ÇÑ
   end;
   DScreen.ClearHint;
   MenuIndex := -1;
   MenuTop := 0;
   MenuTopLine := 0;
   FrmMain.SendGetMarketPageList (CurMerchant, 0, '');
   LastestClickTime := GetTickCount + 5000;

end;

procedure TFrmDlg.DItemSellCancelClick(Sender: TObject; X, Y: Integer);
var
   pg: PTMarketITem;
   MsgResult : integer;
begin
   if GetTickCount < LastestClickTime then exit; //Å¬¸¯À» ÀÚÁÖ ¸øÇÏ°Ô Á¦ÇÑ
   DScreen.ClearHint;
   if (MenuIndex >= 0) and (MenuIndex < g_Market.Count) then begin
      ItemSearchEdit.Visible := False;
      pg := g_Market.GetItem( MenuIndex );
      if pg.SellState = 1 then begin
         MsgResult := DMessageDlg ('À§Å¹ÇÑ '+pg.Item.S.Name+' ¾ÆÀÌÅÛÀ» Ãë¼ÒÇÕ´Ï´Ù.', [mbOk, mbCancel]);
         if MsgResult = mrOk then begin
            FrmMain.SendCancelMarket (CurMerchant, pg.Index);
            DItemBag.Show;
         end;
      end
      else if pg.SellState = 2 then begin
         MsgResult := DMessageDlg ('À§Å¹±ÝÀ» È¸¼öÇÏ°í ¼ö¼ö·á¸¦ ÁöºÒ ÇÏ½Ã°Ú½À´Ï±î?', [mbOk, mbCancel]);
         if MsgResult = mrOk then FrmMain.SendGetPayMarket (CurMerchant, pg.Index);
      end;
      MItemSellState := 0;
   end;
end;

procedure TFrmDlg.DItemFindClick(Sender: TObject; X, Y: Integer);
var
   findstr : string;
begin

   if GetTickCount < LastestClickTime then exit; //Å¬¸¯À» ÀÚÁÖ ¸øÇÏ°Ô Á¦ÇÑ

//   DMessageDlg ('°Ë»öÇÒ ¾ÆÀÌÅÛ ÀÌ¸§À» ÀÔ·ÂÇÏ¼¼¿ä.', [mbOk, mbAbort]);
//   GetValidStrVal (DlgEditText, findstr, [' ']);
//   findstr := trim(findstr);
   findstr := trim(ItemSearchEdit.Text);
   findstr := Copy( findstr, 1, 14);
   ItemSearchEdit.Visible := False;
   if findstr <> '' then
      FrmMain.SendGetMarketPageList (CurMerchant, 2, findstr);
   LastestClickTime := GetTickCount + 5000;
//   DScreen.AddChatBoardString ('SendGetMarketPageList (CurMerchant, 2, ' +findstr + ')',  clYellow, clRed);

end;

procedure TFrmDlg.DItemSellCancelMouseMove(Sender: TObject;
  Shift: TShiftState; X, Y: Integer);
begin
{   if g_Market.GetUserMode = 1 then begin
   end else if g_Market.GetUserMode = 2 then begin
      if MItemSellState = 1 then
         DScreen.ShowHint (DItemMarketDlg.Left+ DItemMarketDlg.SurfaceX(330-40), DItemMarketDlg.Top+DItemMarketDlg.SurfaceY(322+25),//(269+40),
                           'À§Å¹ÇÑ ¾ÆÀÌÅÛÀ» Ãë¼Ò ÇÕ´Ï´Ù.', clYellow, FALSE)
      else if MItemSellState = 2 then
         DScreen.ShowHint (DItemMarketDlg.Left+DItemMarketDlg.SurfaceX(330-40), DItemMarketDlg.Top+DItemMarketDlg.SurfaceY(322+25),//(269+40),
                           'À§Å¹±ÝÀ» È¸¼ö ÇÕ´Ï´Ù.', clYellow, FALSE);
   end;}
end;

procedure TFrmDlg.DItemCancelMouseMove(Sender: TObject; Shift: TShiftState;
  X, Y: Integer);
begin
//   DScreen.ShowHint (DItemMarketDlg.SurfaceX(586-30), DItemMarketDlg.SurfaceY(269+45),//(269+40),
//                     'À§Å¹ÆÇ¸ÅÃ¢À» ´Ý½À´Ï´Ù.', clYellow, FALSE)
end;

//VOID CInventoryWnd::ShowInventoryWnd()
procedure TFrmDlg.DInventoryWndDirectPaint(Sender: TObject;
  dsurface: TDirectDrawSurface);
var
  rcItmRgn: TRect;
  rc, rcCell, rcInter, rcGold: TRect;
  mtrl: TDirectDrawSurface;
  nCell, nSX, nSY: Integer;
begin
	// À©µµ¿ì ¹ÙÅÁ±×¸®±â.
//	ShowGameWnd();
	// ½ºÅ©·Ñ¹Ù.
//	m_xInvenScrlBar.ShowScrlBar(m_rcWnd.left+254, m_rcWnd.top+70, m_nStartLineNum, _INVEN_MAX_CELL_YCNT - _NEW_INVEN_CELL_YCNT);

	SetRect(&rcItmRgn, _NEW_INVEN_CELL_XSTART + DInventoryWnd.left, _NEW_INVEN_CELL_YSTART+ DInventoryWnd.top,
			_NEW_INVEN_CELL_XSTART + DInventoryWnd.left + (_NEW_INVENTORY_CELL_WIDTH)*(_INVEN_CELL_XCNT), 
			_NEW_INVEN_CELL_YSTART + DInventoryWnd.top + (_NEW_INVENTORY_CELL_HEIGHT)*(_NEW_INVEN_CELL_YCNT) );

(*	if PtInRect(&rcItmRgn, m_Point) then begin
		if ( g_xGameProc.m_xInterface.m_stCommonItem.bSetted && !g_xGameProc.m_xInterface.m_stCommonItem.bIsHideItem ) then begin

			nCell := GetInvenCellNum(g_xGameProc.m_ptMousePos);

			if ( CanItemInsert(nCell, &g_xGameProc.m_xInterface.m_stCommonItem.xItem, rcCell) ) then begin

				nSX := DInventoryWnd.left+_NEW_INVEN_CELL_XSTART + rcCell.left*(_NEW_INVENTORY_CELL_WIDTH);
				nSY: = DInventoryWnd.top +_NEW_INVEN_CELL_YSTART + (rcCell.top-m_nStartLineNum)*(_NEW_INVENTORY_CELL_HEIGHT);

				SetRect(&rc, nSX, nSY, nSX+(rcCell.right-rcCell.left)*(_NEW_INVENTORY_CELL_WIDTH), nSY+(rcCell.bottom-rcCell.top)*(_NEW_INVENTORY_CELL_HEIGHT));

				if ( IntersectRect(&rcInter, &rcItmRgn, &rc) ) then begin

					D3DVECTOR	vecTrans((FLOAT)rcInter.left, (FLOAT)rcInter.top, 0);
					D3DVECTOR	vecScale((FLOAT)(rcInter.right-rcInter.left), (FLOAT)(rcInter.bottom-rcInter.top), 1);

					D3DUtil_InitMaterial(mtrl, (FLOAT)50/255.0f, (FLOAT)100/255.0f, (FLOAT)50/255.0f);
					mtrl.diffuse.a = 1.0f/255.0f;
					g_xGameProc.m_xImage.DrawBillBoard(g_xMainWnd.Get3DDevice(), &vecTrans, &vecScale, &mtrl, NULL);
        end;
      end
			else
			begin
				nSX := DInventoryWnd.left+_NEW_INVEN_CELL_XSTART + rcCell.left*(_NEW_INVENTORY_CELL_WIDTH);
				nSY := DInventoryWnd.top +_NEW_INVEN_CELL_YSTART + (rcCell.top-m_nStartLineNum)*(_NEW_INVENTORY_CELL_HEIGHT);

				SetRect(&rc, nSX, nSY, nSX+(rcCell.right-rcCell.left)*(_NEW_INVENTORY_CELL_WIDTH), nSY+(rcCell.bottom-rcCell.top)*(_NEW_INVENTORY_CELL_HEIGHT));

				if ( IntersectRect(&rcInter, &rcItmRgn, &rc) )then begin

					D3DVECTOR	vecTrans((FLOAT)rcInter.left, (FLOAT)rcInter.top, 0);
					D3DVECTOR	vecScale((FLOAT)(rcInter.right-rcInter.left), (FLOAT)(rcInter.bottom-rcInter.top), 1);

					D3DUtil_InitMaterial(mtrl, (FLOAT)100/255.0f, (FLOAT)50/255.0f, (FLOAT)50/255.0f);
					mtrl.diffuse.a = 1.0f/255.0f;
					g_xGameProc.m_xImage.DrawBillBoard(g_xMainWnd.Get3DDevice(), &vecTrans, &vecScale, &mtrl, NULL);
        end;
      end;
    end;
  end;

	ShowInvenItem();

	rcGold.left = DInventoryWnd.left+62; rcGold.top = DInventoryWnd.top+408; rcGold.right = DInventoryWnd.left+160; rcGold.bottom = DInventoryWnd.top+425;

	CHAR szStr[MAX_PATH];
	GetNumWithComma(g_xGameProc.m_xMyHero.m_nGlod, szStr);
//	sprintf(szStr, "%d", g_xGameProc.m_xMyHero.m_nGlod);
	g_xMainWnd.PutsHan(NULL, rcGold, RGB(248, 200, 100), RGB(0, 0, 0), szStr, g_xMainWnd.CreateGameFont(g_xMsg.GetMsg(1074), 10, 0, FW_BOLD));

	m_xInventoryBtn[_BTN_ID_INVENCLOSE].ChangeRect(DInventoryWnd.left+234, DInventoryWnd.top+417);
	m_xInventoryBtn[_BTN_ID_FUN1	  ].ChangeRect(DInventoryWnd.left+176, DInventoryWnd.top+22);
	m_xInventoryBtn[_BTN_ID_FUN2	  ].ChangeRect(DInventoryWnd.left+195, DInventoryWnd.top+410);
//	m_xInventoryBtn[_BTN_ID_MINIMAPBOOK].ChangeRect(m_rcWnd.left+222, m_rcWnd.top+13);

  case m_bType of
  _INVEN_TYPE_BAG:
		begin
			m_xInventoryBtn[_BTN_ID_INVENCLOSE].ShowGameBtn();
//			m_xInventoryBtn[_BTN_ID_MINIMAPBOOK].ShowGameBtn();

			RECT rcTitle = {m_rcWnd.left+60, m_rcWnd.top+24, m_rcWnd.left+100, m_rcWnd.top+40};
			g_xMainWnd.PutsHan(NULL, rcTitle, RGB(250, 220, 248), RGB(0, 0, 0), g_xMsg.GetMsg(1701));

			RECT rcWeight = {m_rcWnd.left+94, m_rcWnd.top+24, m_rcWnd.left+220, m_rcWnd.top+40};
			sprintf(szStr, "%s: %d / %d", g_xMsg.GetMsg(2501), g_xGameProc.m_xMyHero.m_stAbility.wWeight, g_xGameProc.m_xMyHero.m_stAbility.wMaxWeight);
			RECT rcWeightBack = {rcWeight.left+1, rcWeight.top+1, rcWeight.right+1, rcWeight.bottom+1};
			g_xMainWnd.PutsHan(NULL, rcWeightBack, RGB(10, 10, 10), RGB(0, 0, 0), szStr);
			g_xMainWnd.PutsHan(NULL, rcWeight, RGB(200, 200, 248), RGB(0, 0, 0), szStr);

			// ¿øº¸»óÁ¡, Æ÷ÀÎÆ®»óÁ¡ Æ÷ÀÎÆ®
			RECT rcPoint = rcGold;
			rcPoint.top += 19;
			rcPoint.bottom += 19;
			GetNumWithComma( g_xGameProc.m_xMyHero.m_nPoint, szStr );
			g_xMainWnd.PutsHan(NULL, rcPoint, RGB(248, 100, 0), RGB(0, 0, 0), szStr, g_xMainWnd.CreateGameFont(g_xMsg.GetMsg(1074), 10, 0, FW_BOLD));
		end;
	_INVEN_TYPE_REPAIR:
		begin
			m_xInventoryBtn[_BTN_ID_INVENCLOSE].ShowGameBtn();
//			m_xInventoryBtn[_BTN_ID_MINIMAPBOOK].ShowGameBtn();
			m_xInventoryBtn[_BTN_ID_FUN2].ShowGameBtn();

			RECT rcGold = {m_rcWnd.left+70, m_rcWnd.top+429, m_rcWnd.left+155, m_rcWnd.top+444};
			g_xMainWnd.PutsHan(NULL, rcGold, RGB(250, 150, 100), RGB(0, 0, 0), m_pszPrice);

			RECT rcTitle = {m_rcWnd.left+60, m_rcWnd.top+24, m_rcWnd.left+220, m_rcWnd.top+40};
			g_xMainWnd.PutsHan(NULL, rcTitle, RGB(250, 250, 200), RGB(0, 0, 0), g_xMsg.GetMsg(1702));
		end;
	_INVEN_TYPE_SELL:
		begin
			m_xInventoryBtn[_BTN_ID_INVENCLOSE].ShowGameBtn();
//			m_xInventoryBtn[_BTN_ID_MINIMAPBOOK].ShowGameBtn();
			m_xInventoryBtn[_BTN_ID_FUN2].ShowGameBtn();

			RECT rcGold = {m_rcWnd.left+70, m_rcWnd.top+429, m_rcWnd.left+155, m_rcWnd.top+444};
			g_xMainWnd.PutsHan(NULL, rcGold, RGB(250, 150, 100), RGB(0, 0, 0), m_pszPrice);
			
			RECT rcTitle = {m_rcWnd.left+60, m_rcWnd.top+24, m_rcWnd.left+220, m_rcWnd.top+40};
			g_xMainWnd.PutsHan(NULL, rcTitle, RGB(250, 250, 200), RGB(0, 0, 0), g_xMsg.GetMsg(1703));
		end;
	_INVEN_TYPE_STORAGE:
		begin
			m_xInventoryBtn[_BTN_ID_INVENCLOSE].ShowGameBtn();
//			m_xInventoryBtn[_BTN_ID_MINIMAPBOOK].ShowGameBtn();
			m_xInventoryBtn[_BTN_ID_FUN2].ShowGameBtn();

			RECT rcTitle = {m_rcWnd.left+60, m_rcWnd.top+24, m_rcWnd.left+220, m_rcWnd.top+40};
			g_xMainWnd.PutsHan(NULL, rcTitle, RGB(250, 250, 200), RGB(0, 0, 0), g_xMsg.GetMsg(1704));
		end;
  end;                           *)
	// ¾ÆÀÌÅÛÀÇ »óÅÂÄ¡ º¸¿©ÁÖ±â.
	// ShowInvenItemState();
end;

//INT CInventoryWnd::GetInvenItemNum(POINT ptMouse)
function TFrmDlg.GetInvenItemNum(ptMouse :TPoint):Integer;
var
	nCurrCell: Integer;
begin
  Result := -1;
	nCurrCell := GetInvenCellNum(ptMouse);

	if (nCurrCell <> -1) and (m_shItemSetInfo[nCurrCell] <> -1) then
		Result := m_shItemSetInfo[nCurrCell] mod 1000;
end;

//INT CInventoryWnd::GetEmptyInvenNum()
function TFrmDlg.GetEmptyInvenNum():Integer;
var
  nCnt: Integer;
begin
  Result := -1;
//  for nCnt := 0 to _MAX_INVEN_ITEM - 1 do begin
//		if m_stInventoryItem[nCnt].bSetted = FALSE then
//		begin
//			Result := nCnt;
//      blaek;
//		end
//  end;
end;

//BOOL CInventoryWnd::CanItemInsert(INT nCellNum, CItem* pxItem, RECT& rcCell)
function TFrmDlg.CanItemInsert(nCellNum: Integer; {CItem* pxItem; }rcCell: TRect):Boolean;
var
  nCellWidth, nCellHeight, nSX, nSY, nYCnt: Integer;
  ptCell: TPoint;
  bCheck: Boolean;
begin
  Result := FALSE;

(*	GetCellWH(pxItem->m_stItemInfo.stStdItem.wLooks, nCellWidth, nCellHeight);

	if nCellNum <> -1 then begin

		ptCell := (nCellNum%_INVEN_CELL_XCNT, nCellNum/_INVEN_CELL_XCNT);

		nSX	:= m_rcWnd.left+_NEW_INVEN_CELL_XSTART + ptCell.x*(_NEW_INVENTORY_CELL_WIDTH);
		nSY	:= m_rcWnd.top +_NEW_INVEN_CELL_YSTART + ptCell.y*(_NEW_INVENTORY_CELL_HEIGHT);

		SetRect(&rcCell, nSX, nSY, nSX+(_NEW_INVENTORY_CELL_WIDTH), nSY+(_NEW_INVENTORY_CELL_HEIGHT));

		if (nCellWidth mod 2) = 0 then begin
			if ( g_xGameProc.m_ptMousePos.x > rcCell.left + (rcCell.right - rcCell.left)/2 then begin

				Inc(ptCell.x);
      end;
    end;

    if (nCellHeight mod 2) = 0 then begin
			if ( g_xGameProc.m_ptMousePos.y > rcCell.top + (rcCell.bottom - rcCell.top)/2 then begin
        Inc(ptCell.y);
      end;
    end;

		rcCell.left   := ptCell.x - nCellWidth /2;
		rcCell.top    := ptCell.y - nCellHeight/2;
		rcCell.right  := rcCell.left + nCellWidth;
		rcCell.bottom := rcCell.top  + nCellHeight;

		bCheck := TRUE;
    for nYCnt := rcCell.top to rcCell.bottom - 1 do begin
      if nYCnt < 0 then begin
				bCheck = FALSE;
				break;
      end;
      if nYCnt >= _INVEN_TOTAL_CELL then begin
				bCheck = FALSE;
				break;
      end;
      for nXCnt := rcCell.left to rcCell.right - 1 do begin
         if nXCnt < 0 then begin
          bCheck = FALSE;
          break;
        end;
        if nXCnt >= _INVEN_CELL_XCNT then begin
          bCheck = FALSE;
          break;
        end;
        if m_shItemSetInfo[nXCnt+nYCnt*_INVEN_CELL_XCNT] <> -1 then begin
					bCheck = FALSE;
					break;
				end;
      end;
      if bCheck then Result := TRUE;
    end;
  end; *)
end;

//VOID CInventoryWnd::SetItemState(CItem* pxItem, INT nItemNum, LPRECT lprcCell)
procedure TFrmDlg.SetItemState({CItem* pxItem; }nItemNum: Integer; lprcCell: TRect);
var
	nXCnt, nYCnt, nXCntEX, nYCntEX, nCellX, nCellY: Integer;
	bCheck: Boolean;
  rcCell: TRect;
  nCellWidth, nCellHeight: Integer;
begin
 // GetWindowRect(FHandle, lprcCell);

	// ¿øÇÏ´Â°÷ÀÇ À§Ä¡¿¡ µé¾î°£´Ù.
(*	if (nItemNum <> -1) and lprcCell then begin
    for nYCnt := lprcCell.top to lprcCell.bottom - 1 do begin
      for nXCnt := lprcCell.left to nXCnt < lprcCell.right do begin
        m_shItemSetInfo[nXCnt+nYCnt*_INVEN_CELL_XCNT] = (SHORT)nItemNum;
        if ( nXCnt = lprcCell.left) and (nYCnt = lprcCell.top) then begin
          m_shItemSetInfo[nXCnt+nYCnt*_INVEN_CELL_XCNT] += 1000;
        end;
      end;
    end;

		m_stInventoryItem[nItemNum].bSetted = TRUE;
		m_stInventoryItem[nItemNum].nWidth	= lprcCell->right - lprcCell->left;
		m_stInventoryItem[nItemNum].nHeight	= lprcCell->bottom - lprcCell->top;
		memcpy(&m_stInventoryItem[nItemNum].xItem, pxItem, sizeof(CItem));
	end
	// ºñ¾îÀÖ´Â À§Ä¡ÀÇ Á©Ã³À½¿¡ µé¾î°£´Ù.
	else
	begin
		GetCellWH(pxItem->m_stItemInfo.stStdItem.wLooks, nCellWidth, nCellHeight);
		SetRect(&rcCell, 0, 0, nCellWidth, nCellHeight);
    for nYCnt := 0 to _INVEN_MAX_CELL_YCNT - 1 do begin
			for nXCnt := 0 to _INVEN_CELL_XCNT -1 do begin
				bCheck := FALSE;
        for nYCntEX := rcCell.top to rcCell.bottom -1 do begin
          for nXCntEX := rcCell.left to rcCell.right -1 do begin
						nCellX := nXCntEX + nXCnt;
						nCellY := nYCntEX + nYCnt;

						if (nCellX < 0) or (nCellY < 0) or (nCellX >= _INVEN_CELL_XCNT) or (nCellY >= _INVEN_TOTAL_CELL) then bCheck := TRUE;
						if m_shItemSetInfo[nCellX+nCellY*_INVEN_CELL_XCNT] <> -1 then bCheck = TRUE;
						if bCheck then continue;
          end;
        end;

				if not bCheck then begin
          for nYCntEX := rcCell.top to rcCell.bottom -1 do begin
            for nXCntEX := rcCell.left to rcCell.right -1 do begin
							nCellX := nXCntEX + nXCnt;
							nCellY := nYCntEX + nYCnt;
							m_shItemSetInfo[nCellX+nCellY*_INVEN_CELL_XCNT] := (SHORT)nItemNum;
							if (nCellX = (nXCnt + rcCell.left)) and (nCellY = (nYCnt + rcCell.top)) then begin
								m_shItemSetInfo[nCellX+nCellY*_INVEN_CELL_XCNT] += 1000;
              end;
            end;
          end;
					m_stInventoryItem[nItemNum].bSetted = TRUE;
					m_stInventoryItem[nItemNum].nWidth	= nCellWidth;
					m_stInventoryItem[nItemNum].nHeight	= nCellHeight;
					memcpy(&m_stInventoryItem[nItemNum].xItem, pxItem, sizeof(CItem));
        end;
      end;
    end;
  end;  *)
end;

function TFrmDlg.GetCellWH(wLooks: word; var nCellWidth, nCellHeight: integer):Boolean;
var
  d: TDirectDrawSurface;
begin
	nCellWidth := 0;
	nCellHeight := 0;
  Result := FALSE;

  d := g_WInventory.Images[wLooks];
  if d <> nil then begin
		nCellWidth := d.Width div _NEW_INVENTORY_CELL_WIDTH;
		if (d.Width mod _NEW_INVENTORY_CELL_WIDTH) > 0 then
      Inc(nCellWidth);
		nCellHeight := d.Height div _NEW_INVENTORY_CELL_HEIGHT;
		if (d.Height mod _NEW_INVENTORY_CELL_HEIGHT) > 0 then
      Inc(nCellHeight);
		Result := TRUE;
  end;
end;

//INT CInventoryWnd::GetInvenCellNum(POINT ptMouse)
function TFrmDlg.GetInvenCellNum(ptMouse :TPoint):Integer;
var
	nSX, nSY, nCntX, nCntY, nCntYMax :Integer;
	rc :TRect;
begin
  Result := -1;

	SetRect(&rc, _NEW_INVEN_CELL_XSTART + DItemBag.Left, _NEW_INVEN_CELL_YSTART + DItemBag.Top,
			_NEW_INVEN_CELL_XSTART + DItemBag.Left + (_NEW_INVENTORY_CELL_WIDTH)*(_INVEN_CELL_XCNT+1),
			_NEW_INVEN_CELL_YSTART + DItemBag.Top + (_NEW_INVENTORY_CELL_HEIGHT)*(_NEW_INVEN_CELL_YCNT+1) );
	nCntYMax := _NEW_INVEN_CELL_YCNT;

  if PtInRect(rc, ptMouse) then begin
    for nCntY := 0 to nCntYMax - 1 do begin
      for nCntX := 0 to _INVEN_CELL_XCNT - 1 do begin
		    nSX := DItemBag.Left+_NEW_INVEN_CELL_XSTART + nCntX*(_NEW_INVENTORY_CELL_WIDTH);
		  	nSY := DItemBag.Top +_NEW_INVEN_CELL_YSTART + nCntY*(_NEW_INVENTORY_CELL_HEIGHT);
        SetRect(&rc, nSX, nSY, nSX+(_NEW_INVENTORY_CELL_WIDTH), nSY+(_NEW_INVENTORY_CELL_HEIGHT));

				if PtInRect(rc, ptMouse) then begin
					Result := (nCntX+(m_nInventoryWndStartLineNum+nCntY)*_INVEN_CELL_XCNT);
				end;
      end;
    end;
  end;
end;


procedure TFrmDlg.DItemBagClick(Sender: TObject; X, Y: Integer);
begin
    ItemSearchEdit.Visible := False;
end;

procedure TFrmDlg.DMemoClick(Sender: TObject; X, Y: Integer);
begin
    ItemSearchEdit.Visible := False;
end;

procedure TFrmDlg.DMagicType0Click(Sender: TObject; X, Y: Integer);
begin
  m_bTypeMagic := TDButton(Sender).Tag;
end;

//´«Ææ3Îä¹¦´°¿Ú¼¼ÄÜÀà±ð°´Å¥»æÖÆ
procedure TFrmDlg.DMagicType0DirectPaint(Sender: TObject;
  dsurface: TDirectDrawSurface);
var
  d: TDirectDrawSurface;
begin
  with Sender as TDButton do begin
    if TDButton(Sender).Tag = m_bTypeMagic then d := WLib.Images[FaceIndex + 1]
    else if MouseEntry = msIn then d := WLib.Images[FaceIndex]
    else d := nil;
    if d <> nil then
      dsurface.Draw(SurfaceX(Left), SurfaceY(Top), d.ClientRect, d, True);
  end;
end;

procedure TFrmDlg.DMagicType0MouseMove(Sender: TObject; Shift: TShiftState; X,
  Y: Integer);
var
  sx, sy: integer;
begin
  with Sender as TDButton do begin
    sx := SurfaceX(Left) + 40;
    sy := SurfaceY(Top) + 35;
    DScreen.ShowHint(sx, sy, CMsg.GetMsg(5050+TDButton(Sender).Tag), $393800, True);
  end;
end;

//´«Ææ3Îä¹¦´°¿Ú¼¼ÄÜÊ÷»æÖÆ
procedure TFrmDlg.DMagicWndClick(Sender: TObject; X, Y: Integer);
var
  nCnt, nLineCnt, I, II, PosX, PosY, nStartX, nStartY, nMagicImgIdx, trainlv: Integer;
  pm: PTClientMagic;
  rcImg, rcMIconImg: TRect;
  bFind: Boolean;
  HintPosX, HintPosY: Integer;
begin
  if Myself = nil then exit;
  m_nShowMagicNum := -1;
  bFind := FALSE;
  PosX := DMagicWnd.LocalX(X) - (DMagicWnd.Left + 77);
  PosY := DMagicWnd.LocalY(Y) - (DMagicWnd.Top + 33);

  with DMagicWnd do begin
    if (PosX >= 16) and (PosY >= 43) and (PosX <= 339) and (PosY <= 371) then begin

      for nCnt := 0 to _MAX_MAGICSLOT - 1 do begin
        rcImg.left  := m_xMagicIconPos[m_bTypeMagic][nCnt].nPosX;
        rcImg.top	 :=  m_xMagicIconPos[m_bTypeMagic][nCnt].nPosY - m_nStartPos;
        rcImg.right := rcImg.left + 40;
        rcImg.bottom := rcImg.top + 40;
        HintPosX := rcImg.right + 77;
        HintPosY := rcImg.top + 33;

//        if nCnt = 0 then DScreen.AddChatBoardString('rcImg.left='+IntToStr(rcImg.left)+' rcImg.top='+IntToStr(rcImg.top), clYellow, clRed);
//        if nCnt = 0 then DScreen.AddChatBoardString('rcImg.right='+IntToStr(rcImg.right)+' rcImg.bottom='+IntToStr(rcImg.bottom), clYellow, clRed);
//        if nCnt = 0 then DScreen.AddChatBoardString('m_nStartPos='+IntToStr(m_nStartPos)+' PosX='+IntToStr(PosX)+' PosY='+IntToStr(PosY), clYellow, clRed);
        if PtInRect(rcImg, Point(PosX, PosY)) then begin
          m_nShowMagicNum := m_xMagicIconPos[m_bTypeMagic][nCnt].nMagicID;
          m_nSelectedMagic[m_bTypeMagic] := -1;
          for I := 0 to m_xMyMagicList[m_bTypeMagic].Count - 1 do begin
            pm := PTClientMagic(m_xMyMagicList[m_bTypeMagic][I]);
            if pm <> nil then begin
              if m_xMagicIconPos[m_bTypeMagic][nCnt].nMagicID = pm.Def.MagicId then begin
                m_nSelectedMagic[m_bTypeMagic] := nCnt;
//                DScreen.AddChatBoardString('m_nSelectedMagic['+IntToStr(m_bTypeMagic)+']='+IntToStr(m_nSelectedMagic[m_bTypeMagic]), clYellow, clRed);
              end;
            end;
          end;
        end;
      end;
    end;
  end;
end;

procedure TFrmDlg.DMagicWndDirectPaint(Sender: TObject; dsurface: TDirectDrawSurface);
var
  I, II, PosX, PosY, nStartX, nStartY, nMagicImgIdx, nAtoI: Integer;
  d, dd, Icon, Key: TDirectDrawSurface;
  pstMagicRCD: PTClientMagic;
  rc, rcText, rcImg, rcMIconImg, rcKeyImg: TRect;
  szLevel, sMLv: string;
  bKey: Byte;
begin
  if Myself = nil then exit;
  with DMagicWnd do begin
    d := WLib.Images[FaceIndex];
    if d <> nil then
      dsurface.Draw(SurfaceX(Left), SurfaceY(Top), d.ClientRect, d{, $ECFFFFFF}, True);

    dd := g_WGameInter.Images[1622 + m_bTypeMagic * 2];
    if dd <> nil then begin
      rcImg := Rect(0, m_nStartPos, dd.Width, m_nStartPos+331);
      dsurface.Draw (SurfaceX(Left + 94), SurfaceY(Top+76), rcImg, dd, True);
      PosX := SurfaceX(Left + 77);
      PosY := SurfaceY(Top + 33);

      for I := 0 to m_xMyMagicList[m_bTypeMagic].Count - 1 do begin
        pstMagicRCD := PTClientMagic(m_xMyMagicList[m_bTypeMagic][I]);
        sMLv := '';
        if pstMagicRCD <> nil then begin
          for II := 0 to _MAX_MAGICSLOT - 1 do begin
            if m_xMagicIconPos[m_bTypeMagic][II].nMagicID = pstMagicRCD.Def.MagicId then begin
              nStartX := PosX+m_xMagicIconPos[m_bTypeMagic][II].nPosX;
              nStartY := PosY+m_xMagicIconPos[m_bTypeMagic][II].nPosY - m_nStartPos;
              break;
            end;
          end;

          if II = m_nSelectedMagic[m_bTypeMagic] then begin
            SetRect(rc, nStartX-1, nStartY-1, nStartX+42, nStartY+42);
            if (rc.top > (SurfaceY(Top) + 75)) and (rc.top < (SurfaceY(Top) + 364)) then begin
              g_DXCanvas.Draw2DRectLine(rc, $FFFFFF00);
              if pstMagicRCD <> nil then begin
                szLevel:= Format('%s', [pstMagicRCD.Def.MagicName]);
                g_DXCanvas.TextOut(SurfaceY(left+120), SurfaceY(Top+425), TColor(RGB(250, 250, 250)), szLevel);

                if pstMagicRCD.Level < 5 then
                begin
                  szLevel:= Format('Level : %d', [pstMagicRCD.Level]);
                  g_DXCanvas.TextOut(SurfaceY(left+110), SurfaceY(Top+440), TColor(RGB(250, 250, 250)), szLevel);
                  szLevel:= Format('Exp : %d/%d', [pstMagicRCD.CurTrain, pstMagicRCD.Def.MaxTrain[pstMagicRCD.Level]]);
                  g_DXCanvas.TextOut(SurfaceY(left+180), SurfaceY(Top+440), TColor(RGB(250, 250, 250)), szLevel);
                end
                else if pstMagicRCD.Level = 10 then begin
                  szLevel:= 'Level : Max';
                  g_DXCanvas.TextOut(SurfaceY(left+110), SurfaceY(Top+440), TColor(RGB(250, 250, 250)), szLevel);
                end;
              end;
            end;
          end;

          nMagicImgIdx := (pstMagicRCD.Def.MagicId - 1) * 2;
          Icon := g_WMIcon.Images[nMagicImgIdx];
          if Icon <> nil then begin
            if (nStartY - SurfaceY(Top)) < 76 then begin
              rcMIconImg := Rect(0, 76-(nStartY - SurfaceY(Top)), Icon.Width, Icon.Height);
              dsurface.Draw (nStartX, SurfaceY(Top)+76, rcMIconImg, Icon, True);
            end else if (nStartY - SurfaceY(Top)) > 368 then begin
              rcMIconImg := Rect(0, 0, Icon.Width, Icon.Height - ((nStartY -SurfaceY(Top)) - 367));
              dsurface.Draw (nStartX, nStartY, rcMIconImg, Icon, True);
            end else begin
              dsurface.Draw (nStartX, nStartY, Icon.ClientRect, Icon, True);
            end;
          end;

          if byte(pstMagicRCD.Key) <> 0 then begin
            nAtoI := Byte(pstMagicRCD.Key);
            if (nAtoI < 10) and (nAtoI > 0) then
              bKey := Byte(nAtoI)
            else
              bKey := Byte(pstMagicRCD.Key) - 48;

            Key := g_WGameInter.Images[1659 + bKey];
            if Key <> nil then begin
              if (nStartY - SurfaceY(Top)) < 76 then begin
                rcKeyImg := Rect(0, 76-(nStartY - SurfaceY(Top)), Key.Width, Key.Height);
                dsurface.Draw (nStartX, SurfaceY(Top)+76, rcKeyImg, Key, True);
              end else if (nStartY - SurfaceY(Top)) > 390 then begin
                rcKeyImg := Rect(0, 0, Key.Width, Key.Height - ((nStartY -SurfaceY(Top)) - 389));
                dsurface.Draw (nStartX, nStartY, rcKeyImg, Key, True);
              end else begin
                dsurface.Draw (nStartX, nStartY, Key.ClientRect, Key, True);
              end;
            end;
          end;

          sMLv := IntToStr(pstMagicRCD.Level);
          if ((nStartY - SurfaceY(Top)) > 38) and ((nStartY - SurfaceY(Top)) < 359) then begin
            g_DXCanvas.TextOut(nStartX + 38, nStartY + 38, clYellow, sMLv);
          end;
        end;
      end;
    end;
  end;
end;

procedure TFrmDlg.DMagicWndMouseMove(Sender: TObject; Shift: TShiftState; X,
  Y: Integer);
var
  nCnt, nLineCnt, I, II, PosX, PosY, nStartX, nStartY, nMagicImgIdx, trainlv: Integer;
  pm: PTClientMagic;
  rcImg, rcMIconImg: TRect;
  bFind: Boolean;
  HintPosX, HintPosY: Integer;
  m_MagicExplainList, m_TempMagicExplainList: TStringList;
  s_MagicExplain: string;
begin
  if Myself = nil then exit;
  m_nShowMagicNum := -1;
  bFind := FALSE;
  PosX := DMagicWnd.LocalX(X) - (DMagicWnd.Left + 77);
  PosY := DMagicWnd.LocalY(Y) - (DMagicWnd.Top + 33);
  DScreen.ClearHint;
  m_TempMagicExplainList := TStringList.Create;
  m_MagicExplainList := TStringList.Create;
  s_MagicExplain := '';

  with DMagicWnd do begin
    if (PosX >= 16) and (PosY >= 43) and (PosX <= 339) and (PosY <= 371) then begin

      for nCnt := 0 to _MAX_MAGICSLOT - 1 do begin
        rcImg.left  := m_xMagicIconPos[m_bTypeMagic][nCnt].nPosX;
        rcImg.top	 :=  m_xMagicIconPos[m_bTypeMagic][nCnt].nPosY - m_nStartPos;
        rcImg.right := rcImg.left + 40;
        rcImg.bottom := rcImg.top + 40;
        HintPosX := rcImg.right + 77;
        HintPosY := rcImg.top + 33;

//        if nCnt = 0 then DScreen.AddChatBoardString('rcImg.left='+IntToStr(rcImg.left)+' rcImg.top='+IntToStr(rcImg.top), clYellow, clRed);
//        if nCnt = 0 then DScreen.AddChatBoardString('rcImg.right='+IntToStr(rcImg.right)+' rcImg.bottom='+IntToStr(rcImg.bottom), clYellow, clRed);
//        if nCnt = 0 then DScreen.AddChatBoardString('m_nStartPos='+IntToStr(m_nStartPos)+' PosX='+IntToStr(PosX)+' PosY='+IntToStr(PosY), clYellow, clRed);
        if PtInRect(rcImg, Point(PosX, PosY)) then begin
          m_nShowMagicNum := m_xMagicIconPos[m_bTypeMagic][nCnt].nMagicID;
          SetMagicExplain(m_nShowMagicNum, m_TempMagicExplainList);
          StringDivide(165, nLineCnt, m_TempMagicExplainList, m_MagicExplainList);
          for I := 0 to m_MagicExplainList.Count - 1 do begin
            if I = 0 then s_MagicExplain := s_MagicExplain + '<F:C=clRed S=11 B=Bold>'+m_MagicExplainList.Strings[I] + '\'
            else s_MagicExplain := s_MagicExplain + m_MagicExplainList.Strings[I] + '\';
           // g_DXCanvas.TextOut(DMagicWnd.Left + HintPosX, DMagicWnd.Top + HintPosY, clWhite, m_MagicExplainList.Strings[I]);
          end;
          for I := 0 to m_xMyMagicList[m_bTypeMagic].Count - 1 do begin
            pm := PTClientMagic(m_xMyMagicList[m_bTypeMagic][I]);
            if pm <> nil then begin
              if m_xMagicIconPos[m_bTypeMagic][nCnt].nMagicID = pm.Def.MagicId then begin
                if pm.Level in [0..3] then trainlv := pm.Level
                else trainlv := 0;
                if pm.Def.MaxTrain[trainlv] > 0 then begin
                  if trainlv < 3 then
                    s_MagicExplain := s_MagicExplain + '<F:C=clRed>' + IntToStr(pm.CurTrain) + '/' + IntToStr(pm.Def.MaxTrain[trainlv])
                  else s_MagicExplain := s_MagicExplain + 'MAX';
                end;

              end;
            end;
          end;

          DScreen.ShowHint(DMagicWnd.Left + HintPosX, DMagicWnd.Top + HintPosY, s_MagicExplain, clWhite, False);
//          for I := 0 to m_xMyMagicList[m_bTypeMagic].Count - 1 do begin
//            pm := PTClientMagic(m_xMyMagicList[m_bTypeMagic][I]);
//            if pm <> nil then begin
//              if m_xMagicIconPos[m_bTypeMagic][nCnt].nMagicID = pm.Def.MagicId then begin
//                m_nShowMagicNum := m_xMagicIconPos[m_bTypeMagic][nCnt].nMagicID;
//                DScreen.ShowHint(DMagicWnd.Left + HintPosX, DMagicWnd.Top + HintPosY, pm.Def.MagicName, clYellow, False);
//              end;
//            end;
//          end;
//  		   	if m_nShowMagicNum = -1 then begin
//  			   	m_nShowMagicNum := m_xMagicIconPos[m_bTypeMagic][nCnt].nMagicID;
//            DScreen.ShowHint(10, 10, '²âÊÔÐÅÏ¢ÏÔÊ¾='+IntToStr(m_nShowMagicNum), clYellow, FALSE);
//  				  bFind := TRUE;
//          end else begin
//            for I := 0 to m_xMyMagicList[m_bTypeMagic].Count - 1 do begin
//              pm := PTClientMagic(m_xMyMagicList[m_bTypeMagic][I]);
//              if pm <> nil then begin
//                if m_xMagicIconPos[m_bTypeMagic][nCnt].nMagicID = pm.Def.MagicId then begin
//                  m_nShowMagicNum := m_xMagicIconPos[m_bTypeMagic][nCnt].nMagicID;
//                  DScreen.ShowHint(10, 10, '²âÊÔÐÅÏ¢ÏÔÊ¾', clYellow, FALSE);
//                end;
//              end;
//            end;
//  			  end;
        end;
      end;
    end;
  end;
  FreeAndNil(m_TempMagicExplainList);
  FreeAndNil(m_MagicExplainList);
end;

procedure TFrmDlg.DMagicWndScrollBarDirectPaint(Sender: TObject; dsurface: TDirectDrawSurface);
var
  d: TDirectDrawSurface;
begin
  with Sender as TDButton do begin
    d := WLib.Images[FaceIndex];
    if d <> nil then
      dsurface.Draw(SurfaceX(Left), SurfaceY(Top), d.ClientRect, d, TRUE);
  end;
end;

procedure TFrmDlg.DMagicWndScrollBarMouseMove(Sender: TObject; Shift: TShiftState; X, Y: Integer);
var
  n, ncount: integer;
begin
  if DMagicWndScrollBar.Downed then begin
    if (DMagicWndScrollBar.Top >= 112) and (DMagicWndScrollBar.Top <= (112 + 238)) then begin
      DMagicWndScrollBar.Top := Y;
      if DMagicWndScrollBar.Top >= (112 + 238) then begin
        DMagicWndScrollBar.Top := (112 + 238);
      end;
      if DMagicWndScrollBar.Top <= 112 then begin
        DMagicWndScrollBar.Top := 112;
      end;
      
      ncount := 201;
      n := Trunc((Y - 112) * ncount / 238);
      if n < 0 then
        n := 0;
      if n > ncount then
        n := ncount;
      m_nStartPos := n;
    end;
  end;
end;

procedure TFrmDlg.DMailDlgClick(Sender: TObject; X, Y: Integer);
begin
    ItemSearchEdit.Visible := False;
end;

procedure TFrmDlg.DItemMarketDlgMouseDown(Sender: TObject;
  Button: TMouseButton; Shift: TShiftState; X, Y: Integer);
begin
   with DItemMarketDlg do
//      if (X < SurfaceX(Left+9)) or (X > SurfaceX(Left+Width-3)) or (Y < SurfaceY(Top+155)) or (Y > SurfaceY(Top+Height-125)) then begin
      if (X < SurfaceX(Left+36)) or (X > SurfaceX(Left+477)) or (Y < SurfaceY(Top+92)) or (Y > SurfaceY(Top+282)) then begin
         BoInRect := False;
      end else begin
         BoInRect := True;
      end;
//   DScreen.ClearHint;
//   MouseStateItem.S.Name := '';
   if g_Market.GetUserMode = 1 then begin
      with DItemMarketDlg do
         if (X > SurfaceX(Left+34)) and  (X < SurfaceX(Left+176)) and (Y > SurfaceY(Top+354)) and (Y < SurfaceY(Top+374)) then begin
            DItemMarketDlg.MouseFocus := True;
            ItemSearchEdit.Visible := TRUE;
            ItemSearchEdit.SetFocus;
         end
         else ItemSearchEdit.Visible := False;
   end;

end;

procedure TFrmDlg.SetChatFocus;
begin
   ItemSearchEdit.Visible := False;
   PlayScene.EdChat.Visible := TRUE;
   PlayScene.EdChat.SetFocus;
end;

procedure TFrmDlg.DJangwonListDlgDirectPaint(Sender: TObject;
  dsurface: TDirectDrawSurface);
  function SX(x: integer): integer;
  begin
      Result := DJangwonListDlg.SurfaceX (DJangwonListDlg.Left + x);
  end;
  function SY(y: integer): integer;
  begin
      Result := DJangwonListDlg.SurfaceY (DJangwonListDlg.Top + y);
  end;
var
   i, menuline: integer;
   d: TDirectDrawSurface;
   pj: PTClientJangwon;
   FColor: TColor;
begin
   i := 0;
   pj := nil;

   with g_DXCanvas do begin
      with DJangwonListDlg do begin
         d := DJangwonListDlg.WLib.Images[FaceIndex];
         if d <> nil then
            dsurface.Draw (SurfaceX(Left), SurfaceY(Top), d.ClientRect, d, TRUE);
      end;

//      SetBkMode (dsurface.Canvas.Handle, TRANSPARENT);
//      SetBkMode (Handle, TRANSPARENT);
      FColor := clWhite;
      menuline := _MIN(MAXMENU, JangwonList.Count);

//      TextOut (SX(15),  SY(32), '¹øÈ£');
      TextOut (SX(15+17),  SY(49), FColor, '¹øÈ£');
      TextOut (SX(68+17),  SY(49), FColor, '¹®ÆÄ ÀÌ¸§');
      TextOut (SX(250+17), SY(49), FColor, '¹®ÁÖ');      //(SX(191)
      TextOut (SX(384+17), SY(49), FColor, 'ÆÇ¸Å ±Ý¾×'); //SX(271)
      TextOut (SX(469+17), SY(49), FColor, '±¸ºÐ');      //SX(355)

//      for i:=MenuTop to MenuTop+menuline-1 do begin
      for i:=0 to menuline-1 do begin
//         m := i-MenuTop;
         pj:= PTClientJangwon (JangwonList[i]);

         if i = MenuIndex then
            FColor := clRed
         else FColor := clWhite;

         if pj <> nil then
         begin
//            TextOut (SX(19+18),  SY(51 + LISTLINEHEIGHT2 * i), format('%2s',[IntToStr(pj.Num)]));
            TextOut (SX(19+17),  SY(68 + LISTLINEHEIGHT2 * i), FColor, format('%2s',[IntToStr(pj.Num)]));
            TextOut (SX(58+17),  SY(68 + LISTLINEHEIGHT2 * i), FColor, pj.GuildName );
            TextOut (SX(160+17), SY(68 + LISTLINEHEIGHT2 * i), FColor, pj.CaptaineName1 );
            TextOut (SX(260+17), SY(68 + LISTLINEHEIGHT2 * i), FColor, ', '+pj.CaptaineName2 );
            TextOut (SX(355+17), SY(68 + LISTLINEHEIGHT2 * i), FColor, format('%14s',[GetGoldStr(pj.SellPrice)])); //SX(249)
            TextOut (SX(461+17), SY(68 + LISTLINEHEIGHT2 * i), FColor, pj.SellState ); //SX(348)
         end;
      end;
   end;
end;

procedure TFrmDlg.DJangwonListDlgClick(Sender: TObject; X, Y: Integer);
var
   lx, ly, idx: integer;
   pj: PTClientJangwon;
begin

   pj := nil;
   lx := DJangwonListDlg.LocalX (X) - DJangwonListDlg.Left;
   ly := DJangwonListDlg.LocalY (Y) - DJangwonListDlg.Top;
//   if (lx >= 9) and (lx <= 511) and (ly >= 48) and (ly <= 190) then begin
   if (lx >= 27) and (lx <= 528) and (ly >= 64) and (ly <= 205) then begin
//      idx := (ly-51) div LISTLINEHEIGHT2 + MenuTop;
      idx := (ly-68) div LISTLINEHEIGHT2;
      if idx < JangwonList.Count then begin
         PlaySound (s_glass_button_click);
         MenuIndex := idx;
      end;
   end;

   if (MenuIndex >= 0) and (MenuIndex < JangwonList.Count) then begin
      pj:= PTClientJangwon (JangwonList[MenuIndex]);
   end;

end;

procedure TFrmDlg.DJangListPrevClick(Sender: TObject; X, Y: Integer);
begin
   MenuIndex := -1;
   if MenuTop = 10 then
      FrmMain.SendGetJangwonList(1);
end;

procedure TFrmDlg.DJangListNextClick(Sender: TObject; X, Y: Integer);
begin
   MenuIndex := -1;
   if MenuTop = 0 then
      FrmMain.SendGetJangwonList(2);
end;

procedure TFrmDlg.DJangwonCloseClick(Sender: TObject; X, Y: Integer);
begin
   DJangwonListDlg.Visible := False;
   BoMemoJangwon := False;
end;

procedure TFrmDlg.DJangMemoClick(Sender: TObject; X, Y: Integer);
var
   pj: PTClientJangwon;
begin
   if MenuIndex < 0 then Exit;
   pj := nil;

   ViewWindowNo   := VIEW_MAILSEND;
   ViewWindowData := CurrentMail;
   DMemoB1.SetImgIndex(g_WProgUse, 546);
   DMemoB2.SetImgIndex(g_WProgUse, 538);
   DMemoB1.Visible := true;
   MemoMail.Clear;
//   MemoMail.ReadOnly := false;

   pj:= PTClientJangwon (JangwonList[MenuIndex]);
   MemoCharID  := pj.CaptaineName1 ;
   MemoCharID2 := pj.CaptaineName2 ;

   DMemo.Left := 410;
   DMemo.Top  := 198;
   Memo.Clear;
   BoMemoJangwon := True;
   ShowEditMail;

end;

procedure TFrmDlg.DDealJangwonDirectPaint(Sender: TObject;
  dsurface: TDirectDrawSurface);
var
  d: TDirectDrawSurface;
  OldColor: TColor;
  old: Integer;
  nStatus: Integer;
  OldFontStyle: TFontStyles;
begin
   with DDealJangwon do begin
      d := WLib.Images[FaceIndex];
      if d <> nil then
         dsurface.Draw (SurfaceX(Left), SurfaceY(Top), d.ClientRect, d, TRUE);
      with g_DXCanvas do begin
//         SetBkMode (Handle, TRANSPARENT);
        old := MainForm.Canvas.Font.Size;
        OldColor := MainForm.Canvas.Font.Color;
        OldFontStyle := MainForm.Canvas.Font.Style;
        MainForm.Canvas.Font.Size := 64;
        MainForm.Canvas.Font.Style := [fsBold];
        MainForm.Canvas.Font.Color := clWhite;
        TextOut (SurfaceX(Left+93), SurfaceY(Top+9), clWhite, 'Àå ¿ø °Å ·¡');
        MainForm.Canvas.Font.Style := OldFontStyle;
        MainForm.Canvas.Font.Size := old;
        MainForm.Canvas.Font.Color := OldColor;
      end;
   end;
end;

procedure TFrmDlg.DGABoardListDlgDirectPaint(Sender: TObject;
  dsurface: TDirectDrawSurface);
  function SX(x: integer): integer;
  begin
      Result := DGABoardListDlg.SurfaceX (DGABoardListDlg.Left + x);
  end;
  function SY(y: integer): integer;
  begin
      Result := DGABoardListDlg.SurfaceY (DGABoardListDlg.Top + y);
  end;
var
   i, menuline: integer;
   d, TempSurface: TDirectDrawSurface;
   pb: PTClientGABoard;
   TempTitleMsg : String[36];
   FColor: TColor;
begin
   i := 0;
   pb := nil;

   with g_DXCanvas do begin
      with DGABoardListDlg do begin
         d := DGABoardListDlg.WLib.Images[FaceIndex];
         if d <> nil then
            dsurface.Draw (SurfaceX(Left), SurfaceY(Top), d.ClientRect, d, TRUE);
      end;

      FColor := clWhite;
      menuline := _MIN(MAXMENU, GABoardList.Count);

      i := (TextWidth(GABoard_GuildName) div 2);
      TextOut (SX(204-i), SY(38), FColor, GABoard_GuildName);
      TextOut (SX(59),  SY(67), FColor, '±Û¾´ÀÌ');
      TextOut (SX(256), SY(67), FColor, '³»  ¿ë');

      TextOut (SX(360), SY(38), FColor, format('%2d',[GABoard_CurPage]));
      if GABoard_MaxPage < 1 then
         TextOut (SX(360+17), SY(38), FColor, '/ ' + '1')
      else TextOut (SX(360+17), SY(38), FColor, '/ ' + IntToStr(GABoard_MaxPage));

      for i:=0 to menuline-1 do begin
         pb:= PTClientGABoard (GABoardList[i]);

         if i in [0,1,2] then
            FColor := clYellow
         else FColor := clWhite;

         if i in [0,1,2] then pb.ReplyCount := 0;
         if pb <> nil then
         begin
            if pb.ReplyCount > 0 then begin
               TextOut (SX(20+18),  SY(68+21 + MAKETLINEHEIGHT * i), FColor, pb.WrigteUser );
               if pb.ReplyCount > 2 then begin
                  TempTitleMsg := pb.TitleMsg;
                  TextOut (SX(124+18+(pb.ReplyCount*REPLYIMGPOS)), SY(68+21 + MAKETLINEHEIGHT * i), FColor, TempTitleMsg )
               end
               else
                  TextOut (SX(124+18+(pb.ReplyCount*REPLYIMGPOS)), SY(68+21 + MAKETLINEHEIGHT * i), FColor, pb.TitleMsg );
            end
            else begin
//               TextOut (SX(38),  SY(89 + MAKETLINEHEIGHT * i), pb.WrigteUser );
               TextOut (SX(20+18),  SY(68+21 + MAKETLINEHEIGHT * i), FColor, pb.WrigteUser );
               TextOut (SX(124+18), SY(68+21 + MAKETLINEHEIGHT * i), FColor, pb.TitleMsg );
            end;
         end;
      end;
   end;

   for i:=0 to menuline-1 do begin
      pb:= PTClientGABoard (GABoardList[i]);

      if i in [0,1,2] then pb.ReplyCount := 0;
      if pb <> nil then
      begin
         if pb.ReplyCount > 0 then
            DGABoardReplyVisibleOk(i, pb.ReplyCount, dsurface);
      end;
   end;

end;

procedure TFrmDlg.DGABoardListCloseClick(Sender: TObject; X, Y: Integer);
begin
   GABoardList.Clear;
   DGABoardListDlg.Visible := False;
end;

procedure TFrmDlg.DGABoardOkClick(Sender: TObject; X, Y: Integer);
begin
   DGABoardListDlg.Visible := False;
end;

procedure TFrmDlg.DGABoardReplyVisibleOk(Index, ReplyCount: Integer; dsurface: TDirectDrawSurface);
  function SX(x: integer): integer;
  begin
      Result := DGABoardListDlg.SurfaceX (DGABoardListDlg.Left + x);
  end;
  function SY(y: integer): integer;
  begin
      Result := DGABoardListDlg.SurfaceY (DGABoardListDlg.Top + y);
  end;
var
   d : TDirectDrawSurface;
begin
   d := g_WProgUse.Images[690];
   if d <> nil then
//      dsurface.Draw (SX(109+(ReplyCount*REPLYIMGPOS)), SY(65 + MAKETLINEHEIGHT * Index),d.ClientRect, d, TRUE);
      dsurface.Draw (SX(109+18+(ReplyCount*REPLYIMGPOS)), SY(64+21 + MAKETLINEHEIGHT * Index),d.ClientRect, d, TRUE);
end;

procedure TFrmDlg.DGABoardListDlgDblClick(Sender: TObject);
var
   lx, ly, idx: integer;
   pb: PTClientGABoard;
   SendStr : String;
begin

   GABoard_BoWrite  := 0;
   GABoard_BoReply  := 0;
   pb := nil;
   lx := DGABoardListDlg.LocalX (GABoard_X) - DGABoardListDlg.Left;
   ly := DGABoardListDlg.LocalY (GABoard_Y) - DGABoardListDlg.Top;
//   if (lx >= 13) and (lx <= 411) and (ly >= 65) and (ly <= 253) then begin
   if (lx >= 28) and (lx <= 427) and (ly >= 85) and (ly <= 274) then begin
      idx := (ly-(64+21)) div MAKETLINEHEIGHT;
      if idx < GABoardList.Count then begin
         PlaySound (s_glass_button_click);
         MenuIndex := idx;
      end;

      if (MenuIndex >= 0) and (MenuIndex < GABoardList.Count) then begin
         pb:= PTClientGABoard (GABoardList[MenuIndex]);
         SendStr := IntToStr(pb.IndexType1) +'/'+ IntToStr(pb.IndexType2) +'/'+
                    IntToStr(pb.IndexType3) +'/'+ IntToStr(pb.IndexType4);
         if (Trim(pb.WrigteUser) = Trim(Myself.UserName)) then Memo.ReadOnly := False
         else Memo.ReadOnly := True;
         FrmMain.SendGABoardRead(SendStr);
      end;
   end;

end;

procedure TFrmDlg.DGABoardListDlgMouseDown(Sender: TObject;
  Button: TMouseButton; Shift: TShiftState; X, Y: Integer);
begin
   GABoard_X := X;
   GABoard_Y := Y;
end;

procedure TFrmDlg.DGABoardDlgDirectPaint(Sender: TObject;
  dsurface: TDirectDrawSurface);
var
   d: TDirectDrawSurface;
begin
   with DGABoardDlg do begin
      d := WLib.Images[FaceIndex];
      if d <> nil then
         dsurface.Draw (SurfaceX(Left), SurfaceY(Top), d.ClientRect, d, TRUE);

      with g_DXCanvas do begin
         TextOut (Left+33, Top+38, clWhite, GABoard_UserName);
      end;
   end;
end;


procedure TFrmDlg.DGABoardCloseClick(Sender: TObject; X, Y: Integer);
begin
   GABoard_Notice.Clear;
   DGABoardDlg.Visible := FALSE;
   Memo.ReadOnly := False;
   Memo.Visible := FALSE;
//   DMsgDlg.DialogResult := mrCancel;
end;

procedure TFrmDlg.DGABoardOk2Click(Sender: TObject; X, Y: Integer);
var
   data : String;
   i : Integer;
begin
   for i:=0 to Memo.Lines.Count-1 do begin
      if Memo.Lines[i] = '' then
         data := data + Memo.Lines[i] + ' '#13
      else data := data + Memo.Lines[i] + #13;
   end;
   if Length(StrToSqlSafe(data)) >= 500 then begin
      Memo.Visible := False;
      DMessageDlg ('¹®ÀÚ¿­ÀÌ ÃÖ´ë ±æÀÌ¸¦ ÃÊ°ú ÇÏ¿´½À´Ï´Ù.\´Ù½Ã ÆíÁýÇÏ¿© ÁÖ½Ê½Ã¿ä.', [mbOk]);
      DGABoardDlg.ShowModal;
      Memo.Visible := True;
      Exit;
   end;

   DGABoardCloseClick (self, 0, 0);
//   DScreen.AddChatBoardString ('====SendGABoardOkProg====;', clYellow, clRed);
//   DMsgDlg.DialogResult := mrOk;
   SendGABoardOkProg;
end;

procedure TFrmDlg.DGABoardWriteClick(Sender: TObject; X, Y: Integer);
begin
   GABoard_BoWrite  := 1;
   GABoard_BoNotice := 1;
   GABoard_BoReply  := 0;
   Memo.ReadOnly := False;
   GABoard_UserName := Myself.UserName;
   GABoard_Notice.Clear;
   if DGABoardDlg.Visible then DGABoardCloseClick (DGABoardClose, 0, 0);
   ShowGABoardReadDlg;
end;

procedure TFrmDlg.DGABoardNoticeClick(Sender: TObject; X, Y: Integer);
begin
   if GetTickCount < LastestClickTime then Exit;
   FrmMain.SendGABoardNoticeCheck;
   LastestClickTime := GetTickCount + 3000;
end;

procedure TFrmDlg.DGABoardReplyClick(Sender: TObject; X, Y: Integer);
begin
   if MenuIndex in [0,1,2] then begin
      GABoard_BoReply := 0;
      DScreen.AddChatBoardString ('°øÁö»çÇ×¿¡´Â ´ä±ÛÀ» ´Þ ¼ö ¾ø½À´Ï´Ù.', clYellow, clRed);
      Exit;
   end
   else GABoard_BoReply := 1;

   if DGABoardDlg.Visible then DGABoardCloseClick (DGABoardClose, 0, 0);
   ShowGABoardReadDlg;
end;

procedure TFrmDlg.DGABoardDlgKeyDown(Sender: TObject; var Key: Word;
  Shift: TShiftState);
begin
   if Key = 27 then begin
      if DGABoardDlg.Visible then DGABoardCloseClick(DGABoardClose, 0, 0);
   end;
end;

procedure TFrmDlg.DGABoardListPrevClick(Sender: TObject; X, Y: Integer);
begin
   if 1 < GABoard_CurPage then
      FrmMain.SendGetGABoardList(GABoard_CurPage-1);
end;

procedure TFrmDlg.DGABoardListNextClick(Sender: TObject; X, Y: Integer);
begin
   if GABoard_MaxPage > GABoard_CurPage then
      FrmMain.SendGetGABoardList(GABoard_CurPage+1);
end;

procedure TFrmDlg.DGABoardListRefreshClick(Sender: TObject; X, Y: Integer);
begin
   FrmMain.SendGetGABoardList(1);
end;

procedure TFrmDlg.DGABoardMemoClick(Sender: TObject; X, Y: Integer);
begin

   if (MenuIndex < 0) or (MenuIndex > 10 ) or (GABoard_UserName = '') or (GABoard_UserName = MySelf.UserName) then Exit;
   if DGABoardDlg.Visible then DGABoardCloseClick(DGABoardClose, 0, 0);
   ViewWindowNo   := VIEW_MAILSEND;
   ViewWindowData := CurrentMail;
   DMemoB1.SetImgIndex(g_WProgUse, 546);
   DMemoB2.SetImgIndex(g_WProgUse, 538);
   DMemoB1.Visible := true;
   MemoMail.Clear;

   MemoCharID := GABoard_UserName;

   DMemo.Left := 410;
   DMemo.Top  := 198;
   BoMemoJangwon := False;
   Memo.Clear;
   ShowEditMail;

end;

procedure TFrmDlg.DGABoardDelClick(Sender: TObject; X, Y: Integer);
var
   SendStr : String;
   MsgResult : integer;
begin

   if (Trim(GABoard_UserName) = Trim(Myself.UserName)) and (GABoard_BoWrite = 0) and (GABoard_BoReply = 0) then begin
      Memo.Visible := False;
      MsgResult := DMessageDlg ('Á¤¸»·Î ±ÛÀ» »èÁ¦ ÇÏ½Ã°Ú½À´Ï±î?', [mbOk, mbCancel]);
      DGABoardDlg.ShowModal;
      Memo.Visible := True;
      if MsgResult = mrCancel then Exit
      else if MsgResult = mrOk then begin
         if DGABoardDlg.Visible then DGABoardCloseClick(DGABoardClose, 0, 0);
         SendStr := IntToStr(GABoard_IndexType1) +'/'+ IntToStr(GABoard_IndexType2) +'/'+
                    IntToStr(GABoard_IndexType3) +'/'+ IntToStr(GABoard_IndexType4);
   //      DScreen.AddChatBoardString ('SendGABoardDel=> ' + SendStr, clYellow, clRed);
         FrmMain.SendGABoardDel(GABoard_CurPage, SendStr);
      end;
   end;
//   else if DGABoardDel.Visible then DGABoardDel.Visible   := False;
end;

procedure TFrmDlg.SendGABoardOkProg;
var
   data: String;
   i : Integer;
begin
   if (Trim(GABoard_UserName) <> Trim(Myself.UserName)) and (GABoard_BoWrite = 0) and (GABoard_BoReply = 0) then begin
      DGABoardOk2.Visible := False;
//      DScreen.AddChatBoardString ('ÀÐ±â »óÅÂ !!!!', clYellow, clRed);
   end
   else begin //if DMsgDlg.DialogResult = mrOk then begin

      data := '';
      for i:=0 to Memo.Lines.Count-1 do begin
         if Memo.Lines[i] = '' then
            data := data + Memo.Lines[i] + ' '#13
         else data := data + Memo.Lines[i] + #13;
      end;
      if Length(StrToSqlSafe(data)) > 500 then begin
//            data := Copy (data, 1, 500);
            DMessageDlg ('¹®ÀÚ¿­ÀÌ ÃÖ´ë ±æÀÌ¸¦ ÃÊ°ú ÇÏ¿´½À´Ï´Ù.', [mbOk]);
//            DScreen.AddChatBoardString ('¹®ÀÚ¿­ÀÌ ÃÖ´ë ±æÀÌ¸¦ ÃÊ°ú ÇÏ¿´½À´Ï´Ù.', clWhite, clRed);
         Exit;
      end;

      if (Trim(GABoard_UserName) = Trim(Myself.UserName)) and (GABoard_BoWrite = 0) and (GABoard_BoReply = 0) then begin
         data := IntToStr(GABoard_IndexType1) +'/'+ IntToStr(GABoard_IndexType2) +'/'+
                 IntToStr(GABoard_IndexType3) +'/'+ IntToStr(GABoard_IndexType4) +'/'+ StrToSqlSafe(data);
         FrmMain.SendGABoardModify(GABoard_CurPage, data);
//   DScreen.AddChatBoardString ('¼öÁ¤º¸³¿!!', clYellow, clRed);
         Memo.Clear;
         Exit;
      end
      else if GABoard_BoReply = 1 then begin
         data := IntToStr(GABoard_IndexType1) +'/'+ IntToStr(GABoard_IndexType2) +'/'+
                 IntToStr(GABoard_IndexType3) +'/'+ IntToStr(GABoard_IndexType4) +'/'+ StrToSqlSafe(data);
//      DScreen.AddChatBoardString ('´ä±Ûº¸³¿!!', clYellow, clRed);
      end
      else begin
//      DScreen.AddChatBoardString ('±Û¾²±âº¸³¿!!', clYellow, clRed);
         data := '0/0/0/0/' + StrToSqlSafe(data);
      end;

//     DScreen.AddChatBoardString (data, clYellow, clRed);
      FrmMain.SendGABoardUpdateNotice (GABoard_BoNotice, GABoard_CurPage, data);
      Memo.Clear;
      DMsgDlg.DialogResult := mrCancel;
   end;

end;

procedure TFrmDlg.SendGABoardNoticeOk;
begin
   GABoard_BoWrite  := 1;
   GABoard_BoNotice := 0;
   GABoard_BoReply  := 0;
   Memo.ReadOnly := False;
   GABoard_UserName := Myself.UserName;
   GABoard_Notice.Clear;
   if DGABoardDlg.Visible then DGABoardCloseClick (DGABoardClose, 0, 0);
   ShowGABoardReadDlg;
end;

procedure TFrmDlg.DGADecorateDlgDirectPaint(Sender: TObject;
  dsurface: TDirectDrawSurface);
  function SX(x: integer): integer;
  begin
      Result := DGADecorateDlg.SurfaceX (DGADecorateDlg.Left + x);
  end;
  function SY(y: integer): integer;
  begin
      Result := DGADecorateDlg.SurfaceY (DGADecorateDlg.Top + y);
  end;
var
   i, m, menuline, ImgX, ImgY: integer;
   d, TempSurface: TDirectDrawSurface;
   pd: PTClientGADecoration;
   FColor: TColor;
begin
   i := 0;
   pd := nil;

   with g_DXCanvas do begin
      with DGADecorateDlg do begin
         d := DGADecorateDlg.WLib.Images[FaceIndex];
         if d <> nil then
            dsurface.Draw (SurfaceX(Left), SurfaceY(Top), d.ClientRect, d, TRUE);
      end;


      FColor := clWhite;
      menuline := _MIN(DECOMAXMENU, GADecorationList.Count-MenuTop);
//      DScreen.AddChatBoardString ('GADecorationList.Count=> ' +IntToStr(GADecorationList.Count), clYellow, clRed);

      TextOut (SX(103),  SY(37), FColor, 'Àå¿ø ²Ù¹Ì±â ¸ñ·Ï');
//      TextOut (SX(527), SY(37), format('%3d',[(MenuTop+12) div 12]));
      TextOut (SX(513+7), SY(36), FColor, format('%3d',[(MenuTop+12) div 12]));
      if GADecorationList.Count < 13 then
         TextOut (SX(538+7), SY(36), FColor, '/ ' + '1')
      else TextOut (SX(538+7), SY(36), FColor, '/ ' + IntToStr((GADecorationList.Count div 12)+1 ));

//      TextOut (SX(15),  SY(32), '¹øÈ£');
      TextOut (SX(74),  SY(68), FColor, 'ÀÌ ¸§');
      TextOut (SX(196), SY(68), FColor, 'ÆÇ¸Å ±Ý¾×'); //SX(271)

      for i:=MenuTop to MenuTop+menuline-1 do begin
//      for i:=0 to menuline-1 do begin
         m := i-MenuTop;
         pd:= PTClientGADecoration (GADecorationList[i]);

         if i = MenuIndex then
            FColor := clRed
         else FColor := clWhite;

         if pd <> nil then
         begin
            TextOut (SX(26+10),  SY(70+22 + MAKETLINEHEIGHT * m), FColor, pd.Name );
            TextOut (SX(158+10), SY(70+22 + MAKETLINEHEIGHT * m), FColor, format('%14s',[GetGoldStr(pd.Price)])); //SX(249)
         end;
      end;

      FColor := clWhite;
      if (MenuIndex >= 0) and (MenuIndex < GADecorationList.Count) then begin
         pd:= PTClientGADecoration (GADecorationList[MenuIndex]);
         if pd.CaseNum = 1 then
            TextOut (SX(40), SY(333), FColor, '³»ºÎ ¼³Ä¡°¡´É' )
         else if pd.CaseNum = 2 then
            TextOut (SX(40), SY(333), FColor, '¿ÜºÎ ¼³Ä¡°¡´É' )
         else if pd.CaseNum = 3 then
            TextOut (SX(40), SY(333), FColor, '³»ºÎ, ¿ÜºÎ ¼³Ä¡°¡´É' );
      end;
   end;

   if (MenuIndex >= 0) and (MenuIndex < GADecorationList.Count) then begin
      pd:= PTClientGADecoration (GADecorationList[MenuIndex]);

      if pd.Num = 140 then pd.ImgIndex := 300
      else if pd.Num = 141 then pd.ImgIndex := 301
      else if pd.Num = 156 then pd.ImgIndex := 302
      else if pd.Num = 157 then pd.ImgIndex := 303
      else if pd.Num = 163 then pd.ImgIndex := 304
      else if pd.Num = 165 then pd.ImgIndex := 305
      else if pd.Num = 185 then pd.ImgIndex := 306;

//      TempSurface := g_WDecoImg.Images[pd.ImgIndex];
      if TempSurface <> nil then
//         ImgX := 285 +((312-TempSurface.Width) div 2);
//         ImgY := 72 +((285-TempSurface.Height) div 2);

         ImgX := 285+8 +((312-TempSurface.Width) div 2);
         ImgY := 72+22 +((285-TempSurface.Height) div 2);

         dsurface.Draw (SX(ImgX), SY(ImgY),
                        TempSurface.ClientRect, TempSurface, TRUE);
   end;

end;

procedure TFrmDlg.DGADecorateCloseClick(Sender: TObject; X, Y: Integer);
begin
   DGADecorateDlg.Visible := False;
end;

procedure TFrmDlg.DGADecorateCancelClick(Sender: TObject; X, Y: Integer);
begin
   DGADecorateDlg.Visible := False;
end;

procedure TFrmDlg.DGADecorateBuyClick(Sender: TObject; X, Y: Integer);
var
   pd: PTClientGADecoration;
begin
   if (MenuIndex >= 0) and (MenuIndex < GADecorationList.Count) then begin
      pd:= PTClientGADecoration (GADecorationList[MenuIndex]);
      FrmMain.SendBuyDecoItem (CurMerchant, pd.Num);
      if Not DItemBag.Visible then begin
         DItemBag.Left := 456;
         DItemBag.Top := 0;
         DItemBag.Visible := TRUE;
      end;
   end;
end;

procedure TFrmDlg.DGADecorateDlgClick(Sender: TObject; X, Y: Integer);
var
   lx, ly, idx: integer;
   pd: PTClientGADecoration;
begin

   pd := nil;
   lx := DGADecorateDlg.LocalX (X) - DGADecorateDlg.Left;
   ly := DGADecorateDlg.LocalY (Y) - DGADecorateDlg.Top;
//   if (lx >= 11) and (lx <= 275) and (ly >= 64) and (ly <= 294) then begin
   if (lx >= 29) and (lx <= 287) and (ly >= 87) and (ly <= 315) then begin
      idx := (ly-(70+22)) div MAKETLINEHEIGHT + MenuTop;
      if idx < GADecorationList.Count then begin
         PlaySound (s_glass_button_click);
         MenuIndex := idx;
      end;
   end;

   if (MenuIndex >= 0) and (MenuIndex < GADecorationList.Count) then begin
      pd:= PTClientGADecoration (GADecorationList[MenuIndex]);
   end;
end;

procedure TFrmDlg.DGADecorateDlgKeyDown(Sender: TObject; var Key: Word;
  Shift: TShiftState);
begin
   if Key = 27 then
      if DGADecorateDlg.Visible then DGADecorateDlg.Visible := False;

//   DScreen.ClearHint;
   case key of
      VK_UP:
         begin
            if (MenuTop <= (MenuIndex-1)) and (MenuIndex <> -1) then begin
               Dec(MenuIndex, 1);
               DGADecorateDlgClick(DGADecorateDlg ,0 ,0);
            end;
         end;
      VK_DOWN:
         begin
            if (MenuTop+DECOMAXMENU > (MenuIndex+1)) and (MenuIndex <> -1) and ((MenuIndex+1) < GADecorationList.Count) then begin
               Inc(MenuIndex, 1);
               DGADecorateDlgClick(DGADecorateDlg ,0 ,0);
            end;
         end;
      VK_LEFT:
         begin
            DGADecorateListPrevClick( DGADecorateListPrev, 0, 0);
         end;
      VK_RIGHT:
         begin
            DGADecorateListNextClick( DGADecorateListNext, 0, 0);
         end;
   else
   end;

end;

procedure TFrmDlg.DGADecorateListNextClick(Sender: TObject; X, Y: Integer);
var
   MaxNum : Integer;
begin
   MenuIndex := -1;
   MaxNum := ((GADecorationList.Count div 12)+1)*12;
   if (MaxNum >= GADecorationList.Count) and (MaxNum >= (MenuTop+23)) then begin
      Inc (MenuTop, DECOMAXMENU);
   end;
   MenuIndex := MenuTop;
   DGADecorateDlgClick(DGADecorateDlg ,0 ,0);

end;

procedure TFrmDlg.DGADecorateListPrevClick(Sender: TObject; X, Y: Integer);
begin
   MenuIndex := -1;
   if MenuTop > 0 then begin
      Dec (MenuTop, DECOMAXMENU);
      if MenuTop < 0 then MenuTop := 0;
   end;
   MenuIndex := MenuTop;
   DGADecorateDlgClick(DGADecorateDlg ,0 ,0);
end;

procedure TFrmDlg.SafeCloseDlg;
begin
   if DMakeItemDlg.Visible then DMakeItemDlgOkClick(DMakeItemDlgCancel, 0, 0);
   if DItemMarketDlg.Visible then CloseItemMarketDlg;
   if DJangwonListDlg.Visible then DJangwonCloseClick(DJangwonClose, 0, 0);
   if DGABoardListDlg.Visible then DGABoardListCloseClick(FrmDlg.DGABoardListClose, 0, 0);
   if DGABoardDlg.Visible then DGABoardCloseClick(FrmDlg.DGABoardClose, 0, 0);
   if DGADecorateDlg.Visible then DGADecorateCloseClick(DGADecorateClose, 0, 0);
end;

function TFrmDlg.DecoItemDesc(Dura: word; var str: string) : string;
var
   pd: PTClientGADecoration;
begin
   if (Dura >= 0) and (Dura < GADecorationList.Count) then begin
      pd:= PTClientGADecoration (GADecorationList[Dura]);
      if pd.CaseNum = 1 then str := '³»ºÎ ¼³Ä¡°¡´É'
      else if pd.CaseNum = 2 then str := '¿ÜºÎ ¼³Ä¡°¡´É'
      else if pd.CaseNum = 3 then str := '³»ºÎ, ¿ÜºÎ ¼³Ä¡°¡´É';
      Result := 'ÀÌ¹ÌÁö: '+pd.Name;
   end;
end;

procedure TFrmDlg.DMasterDlgClick(Sender: TObject; X, Y: Integer);
begin
    ItemSearchEdit.Visible := False;
end;

procedure TFrmDlg.DMasterDlgDirectPaint(Sender: TObject;
  dsurface: TDirectDrawSurface);
var
   d : TDirectDrawSurface;
   b : TDirectDrawSurface;
   lx, ly, n, t, l, ax, ay : integer;
   Rect : TRect;
   CurrentPage ,maxPage , UpPage , DownPage : integer;
begin


   with (Sender As TDWindow) do
   begin
      if fLover.GetEnable( RsState_Lover ) = 1 then
      DLover1.SetImgIndex (g_WProgUse, 602)
      else
      DLover1.SetImgIndex (g_WProgUse, 600);

      d := WLib.Images[FaceIndex];
      if d <> nil then
         dsurface.Draw (SurfaceX(Left), SurfaceY(Top), d.ClientRect, d, TRUE);

      b := g_WProgUse.GetCachedImage (582, ax, ay);
      dsurface.Draw (SurfaceX(Left+25), SurfaceY(Top+25), b.ClientRect, b, TRUE);
      b := g_WProgUse.GetCachedImage (580, ax, ay);
      dsurface.Draw (SurfaceX(Left+186), SurfaceY(Top+163), b.ClientRect, b, TRUE);
      b := g_WProgUse.GetCachedImage (581, ax, ay);
      dsurface.Draw (SurfaceX(Left+52), SurfaceY(Top+385), b.ClientRect, b, TRUE);


//      dsurface.Canvas.Font.Color  := clSilver;
//      dsurface.Canvas.Brush.Color := clBlack;
//      dsurface.Canvas.Brush.Style := bsClear;

      lx := SurfaceX(41) + Left ;
      ly := SurfaceY(58) + Top  + (1 * 15);
      g_DXCanvas.TextOut (lx, ly, clSilver, fLover.GetDisplay(0) );
      ly := SurfaceY(58) + Top  + (3 * 15);
      g_DXCanvas.TextOut (lx, ly, clSilver, fLover.GetDisplay(1) );
      ly := SurfaceY(58) + Top  + (5 * 15);
      g_DXCanvas.TextOut (lx, ly, clSilver, fLover.GetDisplay(2) );

//      dsurface.Canvas.Release;

   end;

end;

procedure TFrmDlg.DMasterDlgMouseMove(Sender: TObject; Shift: TShiftState;
  X, Y: Integer);
begin
     DScreen.ClearHint;
end;

procedure TFrmDlg.DLover1Click(Sender: TObject; X, Y: Integer);
var
   sendenable : integer;
begin
   if fLover.GetEnable( RsState_Lover) = 1 then
       sendenable := 0
   else
       sendenable := 1;

   FrmMain.SendLMOptionChange ( 1  , sendenable);

end;

procedure TFrmDlg.DLover1MouseMove(Sender: TObject; Shift: TShiftState; X,
  Y: Integer);
var
   lx, ly : integer;
   sx, sy : integer;
begin
   with DFrdAdd do begin
      lx := LocalX (X - Left);
      ly := LocalY (Y - Top);
      sx := SurfaceX(Left)+DMasterDlg.SurfaceX(DMasterDlg.Left)+lx+8;
      sy := SurfaceY(Top) +DMasterDlg.SurfaceX(DMasterDlg.Top) +ly+6;
      DScreen.ShowHint(sx, sy, '±³Á¦°¡´É¿©ºÎ¼±ÅÃ', clYellow, FALSE);
      DFriendDlg.hint := '';
   end;
end;

procedure TFrmDlg.DLover2Click(Sender: TObject; X, Y: Integer);
begin
     FrmMain.SendLMRequest( RsState_Lover , RsReq_WantToJoinOther );
end;

procedure TFrmDlg.DLover2MouseMove(Sender: TObject; Shift: TShiftState; X,
  Y: Integer);
var
   lx, ly : integer;
   sx, sy : integer;
begin
   with DFrdAdd do begin
      lx := LocalX (X - Left);
      ly := LocalY (Y - Top);
      sx := SurfaceX(Left)+DMasterDlg.SurfaceX(DMasterDlg.Left)+lx+8;
      sy := SurfaceY(Top) +DMasterDlg.SurfaceX(DMasterDlg.Top) +ly+6;
      DScreen.ShowHint(sx, sy, '±³Á¦½ÅÃ»', clYellow, FALSE);
      DFriendDlg.hint := '';
   end;

end;

procedure TFrmDlg.DLover3Click(Sender: TObject; X, Y: Integer);
var
   Name : string;
begin
     Name := fLover.GetName( RsState_Lover);
//     DScreen.AddSysMsg ( 'LOVER3_CLCIK:'+Name );
     if mrCancel = DMessageDlg ('±³Á¦¸¦ Áß´Ü ÇÏ½Ã°Ú½À´Ï±î?\±³Á¦¸¦ Áß´ÜÇÒ °æ¿ì À§¾à±ÝÀ¸·Î 10¸¸ÀüÀÌ ÀÚµ¿ÁöºÒµË´Ï´Ù.', [mbYes, mbCancel]) then
        Exit;
     if Name <> '' then
         FrmMain.SendLMSeparate( RsState_Lover , Name  );

end;

procedure TFrmDlg.DLover3MouseMove(Sender: TObject; Shift: TShiftState; X,
  Y: Integer);
var
   lx, ly : integer;
   sx, sy : integer;
begin
   with DFrdAdd do begin
      lx := LocalX (X - Left);
      ly := LocalY (Y - Top);
      sx := SurfaceX(Left)+DMasterDlg.SurfaceX(DMasterDlg.Left)+lx+8;
      sy := SurfaceY(Top) +DMasterDlg.SurfaceX(DMasterDlg.Top) +ly+6;
      DScreen.ShowHint(sx, sy, '±³Á¦Áß´Ü', clYellow, FALSE);
      DFriendDlg.hint := '';
   end;

end;

procedure TFrmDlg.ToggleShowMasterDlg;
begin
   DMasterDlg.Visible := not DMasterDlg.Visible;
   // È­¸éÀ» ¿­¶§¸¶´Ù µð½ºÇÃ·¹ÀÌ Á¤º¸¸¦ °»½ÅÇØÁØ´Ù.
   if DMasterDlg.Visible then flover.MakeDisplay;
end;

procedure TFrmDlg.DMasterCloseClick(Sender: TObject; X, Y: Integer);
begin
    ToggleShowMasterDlg;
end;

procedure TFrmDlg.DHeartImgDirectPaint(Sender: TObject;
  dsurface: TDirectDrawSurface);
var
   d: TDirectDrawSurface;
begin
   with DHeartImg do begin
      d := WLib.Images[FaceIndex];
      if d <> nil then
         dsurface.Draw (SurfaceX(Left), SurfaceY(Top), d.ClientRect, d, TRUE);
   end;
end;

procedure TFrmDlg.DHeartImgUSDirectPaint(Sender: TObject;
  dsurface: TDirectDrawSurface);
var
   d: TDirectDrawSurface;
begin
   with DHeartImgUS do begin
      d := WLib.Images[FaceIndex];
      if d <> nil then
         dsurface.Draw (SurfaceX(Left), SurfaceY(Top), d.ClientRect, d, TRUE);
   end;
end;

procedure TFrmDlg.DBotMasterClick(Sender: TObject; X, Y: Integer);
begin
   ToggleShowMasterDlg;
end;

procedure TFrmDlg.DBotMasterMouseMove(Sender: TObject; Shift: TShiftState;
  X, Y: Integer);
var
   lx, ly : integer;
   sx, sy : integer;
begin
   with DBotFriend do begin
      lx := LocalX (X - Left);
      ly := LocalY (Y - Top);
      sx := SurfaceX(Left)+DBottom.SurfaceX(DBottom.Left)+lx+13;
      sy := SurfaceY(Top)+DBottom.SurfaceX(DBottom.Top)+ly-2;
      DScreen.ShowHint(sx, sy, '±³Á¦Ã¢(L)', clYellow, FALSE);
   end;

end;

procedure TFrmDlg.DMarketMemoClick(Sender: TObject; X, Y: Integer);
begin
   if trim(MemoCharID) <> '' then begin
      ViewWindowNo   := VIEW_MAILSEND;
      DMemoB1.SetImgIndex(g_WProgUse, 546);
      DMemoB2.SetImgIndex(g_WProgUse, 538);
      DMemoB1.Visible := true;
      memoMail.Clear;
      ShowEditMail;
   end
   else
      DMessageDlg ('´ë»óÀ» ¼±ÅÃÇÏÁö ¾Ê¾Ò½À´Ï´Ù.', [mbOk]);
end;

procedure TFrmDlg.DMemoKeyDown(Sender: TObject; var Key: Word;
  Shift: TShiftState);
begin
   if Key = 27 then
      if DMemo.Visible then DMemoCloseClick(DMemoClose, 0, 0);
end;

procedure TFrmDlg.DMainOptionDirectPaint(Sender: TObject;
  dsurface: TDirectDrawSurface);
var
   d: TDirectDrawSurface;
begin
   with DMainOption do begin
      d := WLib.Images[FaceIndex];
      if d <> nil then
         dsurface.Draw (SurfaceX(Left), SurfaceY(Top), d.ClientRect, d, TRUE);
   end;
end;

procedure TFrmDlg.DSkillMode1Click(Sender: TObject; X, Y: Integer);
begin
   SkillKeyMode := 1;
   DSkillMode1.Tag := 1;
   DSkillMode2.Tag := 0;
end;

procedure TFrmDlg.DSkillMode2Click(Sender: TObject; X, Y: Integer);
begin
   SkillKeyMode := 2;
   DSkillMode1.Tag := 0;
   DSkillMode2.Tag := 1;
end;

procedure TFrmDlg.DSkillBarOnClick(Sender: TObject; X, Y: Integer);
begin
   BoSkillBarView := True;
   DSkillBarOn.Tag := 1;
   DSkillBarOff.Tag := 0;
   DScreen.AddChatBoardString ('<¹«°ø¹Ù¸¦ º¾´Ï´Ù>', clGreen, clWhite)
end;

procedure TFrmDlg.DSkillBarOffClick(Sender: TObject; X, Y: Integer);
begin
   BoSkillBarView := False;
   DSkillBarOn.Tag := 0;
   DSkillBarOff.Tag := 1;
   DScreen.AddChatBoardString ('<¹«°ø¹Ù¸¦ º¸Áö ¾Ê½À´Ï´Ù>', clGreen, clWhite)
end;

procedure TFrmDlg.DSkillBarOnDirectPaint(Sender: TObject;
  dsurface: TDirectDrawSurface);
var
   d: TDirectDrawSurface;
   b: TDButton;
begin
   b := nil;
   b := TDButton(Sender);
   if b.Tag = 1 then begin
   with b do begin
      d := WLib.Images[FaceIndex];
      if d <> nil then
         dsurface.Draw (SurfaceX(Left), SurfaceY(Top), d.ClientRect, d, TRUE);
   end;
   end;
end;

procedure TFrmDlg.DEffectOnClick(Sender: TObject; X, Y: Integer);
begin
   BoViewEffect := True;
   DEffectOn.Tag := 1;
   DEffectOff.Tag := 0;
   DScreen.AddChatBoardString ('<È¿°ú¸¦ º¾´Ï´Ù>', clGreen, clWhite)
end;

procedure TFrmDlg.DEffectOffClick(Sender: TObject; X, Y: Integer);
begin
   BoViewEffect := False;
   DEffectOn.Tag := 0;
   DEffectOff.Tag := 1;
   DScreen.AddChatBoardString ('<È¿°ú¸¦ º¸Áö ¾Ê½À´Ï´Ù>', clGreen, clWhite)
end;

procedure TFrmDlg.DSoundOnClick(Sender: TObject; X, Y: Integer);
begin
   BoPlaySoundEffect := True;
   DSoundOn.Tag := 1;
   DSoundOff.Tag := 0;
   DScreen.AddChatBoardString ('<À½Çâ È¿°ú ÄÔ>', clGreen, clWhite)
end;

procedure TFrmDlg.DSoundOffClick(Sender: TObject; X, Y: Integer);
begin
   BoPlaySoundEffect := False;
   DSoundOn.Tag := 0;
   DSoundOff.Tag := 1;
   DScreen.AddChatBoardString ('<À½Çâ È¿°ú ²û>', clGreen, clWhite);
end;

procedure TFrmDlg.DMainOptionCloseClick(Sender: TObject; X, Y: Integer);
begin
   SaveOption ('.\Data\' + ServerName + '.' + FrmMain.CharName + '.Opt');
   DMainOption.Visible := False;
end;

procedure TFrmDlg.DChFriendDirectPaint(Sender: TObject;
  dsurface: TDirectDrawSurface);
var
   d: TDirectDrawSurface;
   b: TDButton;
begin
   b := nil;
   b := TDButton(Sender);
   with TDButton(Sender) do begin
      d := WLib.Images[FaceIndex];
      if (b.Downed) and (d <> nil) then
         dsurface.Draw (SurfaceX(Left), SurfaceY(Top), d.ClientRect, d, TRUE);
   end;
end;

procedure TFrmDlg.DChGroupClick(Sender: TObject; X, Y: Integer);
begin
   if (GetTickCount > changegroupmodetime) and (GroupMembers.Count > 0) then begin
      if UserState1.UserName <> '' then begin
         changegroupmodetime := GetTickCount + 2000; //timeout 5ÃÊ //DelayTime 5ÃÊ¿¡¼­ 2ÃÊ·Î¼öÁ¤ //2004/11/18
         FrmMain.SendAddGroupMember (Trim (UserState1.UserName));
      end;
   end
   else if (GetTickCount > changegroupmodetime) and (GroupMembers.Count = 0) then begin
      if UserState1.UserName <> '' then begin
         changegroupmodetime := GetTickCount + 2000;
         FrmMain.SendCreateGroup (Trim (UserState1.UserName));
      end;
   end;
end;

procedure TFrmDlg.DChatDirectPaint(Sender: TObject;
  dsurface: TDirectDrawSurface);
var
  d, dd : TDirectDrawSurface;
  i, bbx, bby, fcolor, bcolor, img: integer;
  rc: TRect;
//  tStr: string;
//  OldColor: TColor;
//  old: Integer;
//  nStatus: Integer;
  OldFontStyle: TFontStyles;
begin
  with DChat do begin
    if mChatViewMode then begin
      with g_DXCanvas do begin
        rc.Left := SurfaceX(Left);
        rc.Top := SurfaceY(Top) + 30;
        rc.Right := rc.Left + 456;
        rc.Bottom := rc.Top + 220;
        Draw2DRect(rc, $141414, 120);
      end;
    end;

    d := WLib.Images[FaceIndex];
    if d <> nil then
      dsurface.Draw(SurfaceX(Left), SurfaceY(Top), d.ClientRect, d, True);

    dd := nil;
    case DayBright of
      0: dd := g_WGameInter.Images[1201];  //Áè³¿
      1: dd := g_WGameInter.Images[1202];  //Öç
      2: dd := g_WGameInter.Images[1203];  //»Æ»è
      3: dd := g_WGameInter.Images[1200];  //¹ã
    end;
    if dd <> nil then
      dsurface.Draw (SurfaceX(Left + 206), SurfaceY(Top + 7), dd.ClientRect, dd, TRUE);

    if Myself <> nil then begin
      if not mChatViewMode then begin
        img := 650 + (MySelf.Job * 2) + MySelf.Sex;

        if FocusCret <> nil then begin


        end;

        dd := g_WProgUse.Images[img];
        if dd <> nil then
          dsurface.Draw(SurfaceX(Left+356), SurfaceY(Top+39), dd.ClientRect, dd, True);
      end;

      with g_DXCanvas do begin

        OldFontStyle := MainForm.Canvas.Font.Style;
        MainForm.Canvas.Font.Style := [fsBold];
        TextOut(SurfaceX(Left + (d.Width - TextWidth(IntToStr(Myself.Abil.Level))) div 2 - 5), SurfaceY(Top + 19), clYellow, IntToStr(Myself.Abil.Level));
        MainForm.Canvas.Font.Style := OldFontStyle;


         bbx := SurfaceX(Left + 12);
         bby := SurfaceY(Top + 44);
         with DScreen do begin
            for i := ChatBoardTop to ChatBoardTop + VIEWCHATLINE-1 do begin
               if i > ChatStrs.Count-1 then break;
               fcolor := integer(ChatStrs.Objects[i]);
               bcolor := integer(ChatBks[i]);
               TextOutX(bbx, bby+(i-ChatBoardTop)*15, ChatStrs.Strings[i],fcolor, bcolor);
            end;
         end;
      end;
    end;
  end;
end;

procedure TFrmDlg.DChatInRealArea(Sender: TObject; X, Y: Integer;
  var IsRealArea: Boolean);
var
   d: TDirectDrawSurface;
begin
   d := g_WGameInter.Images[CHATBOARD];
   if d <> nil then begin
      if d.Pixels[X, Y] > 0 then IsRealArea := TRUE
      else IsRealArea := FALSE;
   end;
end;

procedure TFrmDlg.DChatModeClick(Sender: TObject; X, Y: Integer);
begin
  mChatViewMode := not mChatViewMode;
  if mChatViewMode then begin
    DChat.SetImgIndex(g_WGameInter, 1162);
    DChat.Left := 178;
    DChat.Top := DBottom.Top - 19 - 167;
    DChatSet1.Visible := True;
    DChatSet2.Visible := True;
    DChatSet3.Visible := True;
    DChatSet4.Visible := True;
    DChatSet5.Visible := True;
    DChatSet6.Visible := True;
    DChatSet7.Visible := True;
  end else begin
    DChat.SetImgIndex(g_WGameInter, 1161);
    DChat.Left := 178;
    DChat.Top := DBottom.Top - 19;
    DChatSet1.Visible := False;
    DChatSet2.Visible := False;
    DChatSet3.Visible := False;
    DChatSet4.Visible := False;
    DChatSet5.Visible := False;
    DChatSet6.Visible := False;
    DChatSet7.Visible := False;
  end;
end;

procedure TFrmDlg.DChatModeDirectPaint(Sender: TObject;
  dsurface: TDirectDrawSurface);
var
  d: TDButton;
  dd: TDirectDrawSurface;
begin
  if Sender is TDButton then begin
    d := TDButton(Sender);
    if d.Downed then begin
      dd := d.WLib.Images[d.FaceIndex];
    end else if d.MouseEntry = msIn then begin
      dd := d.WLib.Images[d.FaceIndex];
    end else begin
      dd := nil;
    end;
    if dd <> nil then
      dsurface.Draw(d.SurfaceX(d.Left), d.SurfaceY(d.Top), dd.ClientRect, dd, TRUE);
  end;
end;

procedure TFrmDlg.DChatModeMouseMove(Sender: TObject; Shift: TShiftState; X,
  Y: Integer);
var
  lx, ly: integer;
  sx, sy: integer;
begin
  with DBotTrade do
  begin
    lx := LocalX(X - Left);
    ly := LocalY(Y - Top);
    sx := SurfaceX(Left) + DChat.SurfaceX(DChat.Left) + lx + 13;
    sy := SurfaceY(Top) + DChat.SurfaceX(DChat.Top) + ly - 2;
    DScreen.ShowHint(sx, sy, CMsg.GetMsg(2614){'ÁÄÌì¼ÇÂ¼´°¿Ú(Ctrl+R, R)'}, $393800, True);
  end;
end;

procedure TFrmDlg.DChatSet3Click(Sender: TObject; X, Y: Integer);
begin
  if DChatSet3.Tag = 0 then DChatSet3.Tag := 1
  else DChatSet3.Tag := 0;
end;

procedure TFrmDlg.DChatSet3DirectPaint(Sender: TObject;
  dsurface: TDirectDrawSurface);
var
  d: TDirectDrawSurface;
  b: TDButton;
begin
  b := nil;
  b := TDButton(Sender);
  if b.Tag = 1 then
  begin
    with b do
    begin
      d := WLib.Images[FaceIndex];
      if d <> nil then
        dsurface.Draw(SurfaceX(Left), SurfaceY(Top), d.ClientRect, d, TRUE);
    end;
  end;
end;

procedure TFrmDlg.DChatSet4Click(Sender: TObject; X, Y: Integer);
begin
  if DChatSet4.Tag = 0 then DChatSet4.Tag := 1
  else DChatSet4.Tag := 0;
end;

procedure TFrmDlg.DChatSet5Click(Sender: TObject; X, Y: Integer);
begin
  if DChatSet5.Tag = 0 then DChatSet5.Tag := 1
  else DChatSet5.Tag := 0;
end;

procedure TFrmDlg.DChatSet6Click(Sender: TObject; X, Y: Integer);
begin
  if DChatSet6.Tag = 0 then DChatSet6.Tag := 1
  else DChatSet6.Tag := 0;
end;

procedure TFrmDlg.DChatSet7Click(Sender: TObject; X, Y: Integer);
begin
  if DChatSet7.Tag = 0 then DChatSet7.Tag := 1
  else DChatSet7.Tag := 0;
end;

procedure TFrmDlg.DChFriendClick(Sender: TObject; X, Y: Integer);
begin
   FrmMain.SendAddFriend (UserState1.UserName , 1 );
   ToggleShowFriendsDlg;
end;

procedure TFrmDlg.DChMemoClick(Sender: TObject; X, Y: Integer);
begin
   ViewWindowNo   := VIEW_MAILSEND;
   ViewWindowData := CurrentMail;
   DMemoB1.SetImgIndex(g_WProgUse, 548);
   DMemoB2.SetImgIndex(g_WProgUse, 538);
   DMemoB1.Visible := true;
   MemoMail.Clear;
   MemoMail.ReadOnly := false;
   MemoCharID := UserState1.UserName;
   ShowEditMail;
end;

procedure TFrmDlg.DChGroupMouseMove(Sender: TObject; Shift: TShiftState; X,
  Y: Integer);
begin
   MouseUserStateItem.S.Name := '';
   DScreen.ShowHint (DUserState1.Left+DChGroup.Left, DUserState1.Top+DChGroup.Top+22, '±×·ìÃÊ´ë', clYellow, FALSE);
end;

procedure TFrmDlg.DChFriendMouseMove(Sender: TObject; Shift: TShiftState;
  X, Y: Integer);
begin
   MouseUserStateItem.S.Name := '';
   DScreen.ShowHint (DUserState1.Left+DChFriend.Left, DUserState1.Top+DChFriend.Top+22, 'Ä£±¸µî·Ï', clYellow, FALSE);
end;

procedure TFrmDlg.DChMemoMouseMove(Sender: TObject; Shift: TShiftState; X,
  Y: Integer);
begin
   MouseUserStateItem.S.Name := '';
   DScreen.ShowHint (DUserState1.Left+DChMemo.Left, DUserState1.Top+DChMemo.Top+22, 'ÂÊÁöº¸³»±â', clYellow, FALSE);
end;

procedure TFrmDlg.DCreateChrClick(Sender: TObject; X, Y: Integer);
var
  nCnt, nSelectIdx: Integer;
begin
  with SelectChrScene do begin
    if m_bChrProcState = _CHR_PROC_CREATE then begin
      for nCnt :=0 to 1 do begin
        nSelectIdx:= nCnt;
        if m_stCreateChrInfo[nSelectIdx].bSetted then begin
          if PtInRect(m_stCreateChrInfo[nSelectIdx].stCurrFrmInfo.rcChrRgn, Point(X, Y)) then begin
            if (m_nCreatedChr <> nSelectIdx) then begin
              SetMotion(nSelectIdx, _CHR_MT_CC);
            end;
            m_nCreatedChr := nSelectIdx;

            if ( m_nCreatedChr <> _SELECTED_NONE ) then
            begin
              SetCharExplain(m_nCreatedChr, m_stCreateChrInfo[nCnt].UserChr.Job);
            end;
          end;
        end;
      end;
    end;
  end;
end;

procedure TFrmDlg.DCreateChrDirectPaint(Sender: TObject;
  dsurface: TDirectDrawSurface);
//var
//   rc: TRect;
//   n, bx, by, ax, ay, img: integer;
//   d, c, dd: TDirectDrawSurface;
begin
//   rc.Left   := 105;
//   rc.Top    := 45;
//   rc.Right  := 683;
//   rc.Bottom := 471;
////   FrmMain.DxDraw1.Surface.FillRect(rc,0);
//
//   with DCreateChr do begin
//      d := WLib.Images[FaceIndex];
//      if d <> nil then
//         dsurface.Draw (SurfaceX(Left), SurfaceY(Top), d.ClientRect, d, TRUE);
//   end;

   SelectChrScene.DrawNewChr(g_DXCanvas.DrawTexture);
end;

procedure TFrmDlg.DCreateChrMouseMove(Sender: TObject; Shift: TShiftState; X,
  Y: Integer);
begin
  DScreen.ClearHint;
end;

procedure TFrmDlg.DBeltWinDirectPaint(Sender: TObject;
  dsurface: TDirectDrawSurface);
var
   d: TDirectDrawSurface;
begin
   if Myself = nil then exit;
   with DBeltWin do begin
      d := WLib.Images[FaceIndex];
      if d <> nil then
         dsurface.Draw (SurfaceX(Left), SurfaceY(Top), d.ClientRect, d, TRUE);
   end;
end;

procedure TFrmDlg.DCloseBeltClick(Sender: TObject; X, Y: Integer);
begin
   if Myself = nil then exit;
   if DBeltWin.Visible then DBeltWin.Visible := FALSE;
end;

procedure TFrmDlg.DCloseBeltMouseMove(Sender: TObject; Shift: TShiftState;
  X, Y: Integer);
//var
//   lx, ly : integer;
//   sx, sy : integer;
begin
//   if Myself = nil then Exit;
//   if not DBeltWin.Visible then Exit;
//   with DCloseBelt do begin
//         sx := SurfaceX(Left)+19;
//         sy := SurfaceY(Top)+1;
//         DScreen.ShowHint(sx, sy, 'º§Æ®Ã¢(Z)', clYellow, FALSE);
//   end;
end;

procedure TFrmDlg.DCloseMagicClick(Sender: TObject; X, Y: Integer);
begin
  DMagicWnd.Visible := FALSE;
end;

procedure TFrmDlg.DCloseMagicMouseMove(Sender: TObject; Shift: TShiftState; X, Y: Integer);
var
  lx, ly: integer;
  sx, sy: integer;
begin
  with DCloseMagic do begin
    lx := LocalX(X - Left);
    ly := LocalY(Y - Top);
    sx := SurfaceX(Left) + DMagicWnd.SurfaceX(DMagicWnd.Left) + lx + 8;
    sy := SurfaceY(Top) + DMagicWnd.SurfaceX(DMagicWnd.Top) + ly + 6;
    DScreen.ShowHint(sx, sy, '¹Ø ±Õ', $393800, FALSE);
  end;
end;

procedure TFrmDlg.DTurnBeltClick(Sender: TObject; X, Y: Integer);
begin
//   if Myself = nil then exit;
//   if BeltType = 1 then BeltType := 2
//   else BeltType := 1;
//
//   if BeltType = 1 then begin
//      DBeltWin.SetImgIndex (g_WProgUse, 80);
//      DBeltWin.Left   := 242;
//      DBeltWin.Top    := 419;
//      DTurnBelt.SetImgIndex (g_WProgUse, 81);
//      DTurnBelt.Left  := 239;
//      DTurnBelt.Top   := 1;
//      DCloseBelt.SetImgIndex (g_WProgUse, 82);
//      DCloseBelt.Left := 240;
//      DCloseBelt.Top  := 21;
//
//      DBelt1.Left := 19;   DBelt1.Width  := 34;
//      DBelt1.Top  := 5;    DBelt1.Height := 32;
//      DBelt2.Left := 56;   DBelt2.Width  := 34;
//      DBelt2.Top  := 5;    DBelt2.Height := 32;
//      DBelt3.Left := 92;   DBelt3.Width  := 34;
//      DBelt3.Top  := 5;    DBelt3.Height := 32;
//      DBelt4.Left := 128;  DBelt4.Width  := 34;
//      DBelt4.Top  := 5;    DBelt4.Height := 32;
//      DBelt5.Left := 165;  DBelt5.Width  := 34;
//      DBelt5.Top  := 5;    DBelt5.Height := 32;
//      DBelt6.Left := 200;  DBelt6.Width  := 34;
//      DBelt6.Top  := 5;    DBelt6.Height := 32;
//   end
//   else begin
//      DBeltWin.SetImgIndex (g_WProgUse, 83);
//      DBeltWin.Left   := 0;
//      DBeltWin.Top    := 144;
//      DTurnBelt.SetImgIndex (g_WProgUse, 84);
//      DTurnBelt.Left  := 20;
//      DTurnBelt.Top   := 239;
//      DCloseBelt.SetImgIndex (g_WProgUse, 85);
//      DCloseBelt.Left := 1;
//      DCloseBelt.Top  := 239;
//
//      DBelt1.Left := 5;    DBelt1.Width  := 32;
//      DBelt1.Top  := 19;   DBelt1.Height := 34;
//      DBelt2.Left := 5;    DBelt2.Width  := 32;
//      DBelt2.Top  := 56;   DBelt2.Height := 34;
//      DBelt3.Left := 5;    DBelt3.Width  := 32;
//      DBelt3.Top  := 92;   DBelt3.Height := 34;
//      DBelt4.Left := 5;    DBelt4.Width  := 32;
//      DBelt4.Top  := 128;  DBelt4.Height := 34;
//      DBelt5.Left := 5;    DBelt5.Width  := 32;
//      DBelt5.Top  := 165;  DBelt5.Height := 34;
//      DBelt6.Left := 5;    DBelt6.Width  := 32;
//      DBelt6.Top  := 200;  DBelt6.Height := 34;
//   end;
end;

procedure TFrmDlg.DCloseBeltDirectPaint(Sender: TObject;
  dsurface: TDirectDrawSurface);
var
   d: TDButton;
   dd: TDirectDrawSurface;
begin
   if (Sender = DCloseBelt) or (Sender = DTurnBelt) then if Myself = nil then exit;
   if Sender is TDButton then begin
      d := TDButton(Sender);
      if d.Downed then
      begin
         dd := d.WLib.Images[d.FaceIndex];
         if dd <> nil then
            dsurface.Draw (d.SurfaceX(d.Left), d.SurfaceY(d.Top), dd.ClientRect, dd, TRUE);
      end;

   end;
end;

procedure TFrmDlg.DSellDlgBtnHoldClick(Sender: TObject; X, Y: Integer);
begin
   if SellStHold then SellStHold := False
   else SellStHold := True;
end;

procedure TFrmDlg.DSellDlgStHoldDirectPaint(Sender: TObject;
  dsurface: TDirectDrawSurface);
var
   d: TDirectDrawSurface;
begin
   with Sender as TDButton do begin
      if SellStHold then begin
         d := WLib.Images[FaceIndex];
         if d <> nil then
            dsurface.Draw (SurfaceX(Left), SurfaceY(Top), d.ClientRect, d, TRUE);
      end;
   end;
end;

procedure TFrmDlg.DSelectChrClick(Sender: TObject; X, Y: Integer);
var
  rc: TRect;
  nCnt, nSelectIdx: Integer;
begin
  with SelectChrScene do begin
    if m_bChrProcState = _CHR_PROC_SELECT then begin

      for nCnt :=0 to _MAX_SHOW_CHAR - 1 do begin

  //		if (m_bFrontSetofSelChar = FALSE)
  //			nSelectIdx = nCnt + 2;
  //		else
        nSelectIdx := nCnt;

        if m_stSelectChrInfo[nSelectIdx].bSetted then begin

          if PtInRect(m_stSelectChrInfo[nSelectIdx].stCurrFrmInfo.rcChrRgn, Point(X, Y)) then begin
            if m_nSelectedChr <> nSelectIdx then begin
              SetMotion(nSelectIdx, _CHR_MT_SM);

              if ( nSelectIdx = 0 ) then begin
                if ( m_stSelectChrInfo[1].bSetted ) then begin
                  SetMotion(1, _CHR_MT_R);
                end;
              end
              else if ( nSelectIdx = 1 ) then begin
                if ( m_stSelectChrInfo[0].bSetted ) then begin
                  SetMotion(0, _CHR_MT_R);
                end;
              end
              else if ( nSelectIdx = 2 ) then begin
                if ( m_stSelectChrInfo[3].bSetted ) then begin
                  SetMotion(3, _CHR_MT_R);
                end;
              end
              else if ( nSelectIdx = 3 ) then begin
                if ( m_stSelectChrInfo[2].bSetted ) then begin
                  SetMotion(2, _CHR_MT_R);
                end;
              end;
              m_nSelectedChr := nSelectIdx;
            end;
          end;
        end;
      end;
    end;
  end;
end;

procedure TFrmDlg.DSelectChrMouseMove(Sender: TObject; Shift: TShiftState; X,
  Y: Integer);
begin
  DScreen.ClearHint;
end;

procedure TFrmDlg.DSellDlgBtnHoldMouseMove(Sender: TObject;
  Shift: TShiftState; X, Y: Integer);
begin
   if not SellStHold then
   with DSellDlgBtnHold do
      DScreen.ShowHint(SurfaceX(Left)+46, SurfaceY(Top)+1, 'HOLD»óÅÂ°¡µÇ¸é ¿Ã·Á³õÀ½°ú µ¿½Ã¿¡ Ã³¸®µË´Ï´Ù ', clYellow, FALSE);
end;

procedure TFrmDlg.DDropViewOnClick(Sender: TObject; X, Y: Integer);
begin
   DropItemView := True;
   DDropViewOn.Tag := 1;
   DDropViewOff.Tag := 0;
   DScreen.AddChatBoardString ('<TabÅ°·Î µå·Ó¾ÆÀÌÅÛ ÀÌ¸§À» º¾´Ï´Ù>', clGreen, clWhite)
end;

procedure TFrmDlg.DDropViewOffClick(Sender: TObject; X, Y: Integer);
begin
   DropItemView := False;
   DDropViewOn.Tag := 0;
   DDropViewOff.Tag := 1;
   DScreen.AddChatBoardString ('<TabÅ°·Î µå·Ó¾ÆÀÌÅÛ ÀÌ¸§À» º¸Áö ¾Ê½À´Ï´Ù>', clGreen, clWhite)
end;

procedure TFrmDlg.DGrpAllowGroupMouseMove(Sender: TObject;
  Shift: TShiftState; X, Y: Integer);
begin
   with DGrpAllowGroup do begin
      if AllowGroup then
         DScreen.ShowHint(SurfaceX(Left)-2, SurfaceY(Top)-18, '[ÔÊÐí]', $393800, FALSE)
      else
         DScreen.ShowHint(SurfaceX(Left)-2, SurfaceY(Top)-18, '[¾Ü¾ø]', $393800, FALSE);
   end;
end;

procedure TFrmDlg.DGroupDlgMouseMove(Sender: TObject; Shift: TShiftState;
  X, Y: Integer);
begin
   DScreen.ClearHint;
end;

procedure TFrmDlg.SwapBujuk(idx: integer);
var
   where: integer;
   TempSender: TObject;
   i : Integer;
begin
   if ItemArr[idx].S.StdMode <> 25 then Exit;

   WaitingUseItem.Item := ItemArr[idx];
   WaitingUseItem.Index := U_BUJUK;
   FrmMain.SendTakeOnItem (U_BUJUK, ItemArr[idx].MakeIndex, ItemArr[idx].S.Name);
   ItemArr[idx].S.Name := '';
end;


end.





