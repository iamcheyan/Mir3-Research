unit ObjNpc;

interface

uses
  Windows, Messages, SysUtils, Classes, Graphics, Controls, Dialogs,
  ScktComp, syncobjs, MudUtil, HUtil32, Grobal2, Envir, EdCode, ObjBase,
  M2Share, Guild;


const
   GUILDWARFEE = 60000;
   // 2003/07/15 사북성 관련 수정
   CASTLEMAINDOORREPAREGOLD = 1500000; //2000000;
   CASTLECOREWALLREPAREGOLD = 400000;  //500000;
   CASTLEARCHEREMPLOYFEE = 250000;     //300000;
   CASTLEGUARDEMPLOYFEE = 250000;      //300000;
   UPGRADEWEAPONFEE = 10000;

   MAXREQUIRE = 10;

   //문파 장원
//   GUILDAGITREGFEE = 10000000;
//   GUILDAGITEXTENDFEE = 1000000;

type
   //무기 제련 관련
   TUpgradeInfo = record
      UserName: string[14];
      uitem: TUserItem;
      updc: byte;
      upsc: byte;
      upmc: byte;
      durapoint: byte;
      readydate: TDateTime;
      readycount: longword;
   end;
   PTUpgradeInfo = ^TUpgradeInfo;

   //퀘스트 관련
   TQuestRequire = record
      RandomCount: integer;
      CheckIndex: word;
      CheckValue: byte;  //0, 1
   end;

   TQuestActionInfo = record
      ActIdent: integer;
      ActParam: string;
      ActParamVal: integer;
      ActTag: string;
      ActTagVal: integer;
      ActExtra: string;
      ActExtraVal: integer;
   end;
   PTQuestActionInfo = ^TQuestActionInfo;

   TQuestConditionInfo = record
      IfIdent: integer;
      IfParam: string;
      IfParamVal: integer;
      IfTag: string;
      IfTagVal: integer;
   end;
   PTQuestConditionInfo = ^TQuestConditionInfo;

   TSayingProcedure = record
      ConditionList: TList;
      ActionList: TList; //StringList;
      Saying: string;
      ElseActionList: TList; //StringList;
      ElseSaying: string;
      AvailableCommands: TStringList;
   end;
   PTSayingProcedure = ^TSayingProcedure;

   TSayingRecord = record
      Title: string;
      Procs: TList; //list of PTSayingProcedure
   end;
   PTSayingRecord = ^TSayingRecord;

   TQuestRecord = record
      BoRequire: Boolean;  //요구조건이 있는지 여부, 없으면 기본 대화
      LocalNumber: integer;
      QuestRequireArr: array[0..MAXREQUIRE-1] of TQuestRequire;
      SayingList: TList;  //list of PTSayingRecord
   end;
   PTQuestRecord = ^TQuestRecord;


   TNormNpc = class (TAnimal)
      NpcFace: byte;  //상인 얼굴.. 채팅창에 나오는 얼굴..
      //SayString: string; //상인이 말하는 대사...
      //SayStrings: TStringList; //list of TStringList;
      Sayings: TList;  //list of PTQuestRecord
      DefineDirectory: string;  //기본은 ''
      BoInvisible: Boolean;
      BoUseMapFileName: Boolean;  //파일이름에 '-D001'처럼 맵이름이 따라 붙는지 여부
      //6-11
      NpcBaseDir: string;

      CanSell       : Boolean;
      CanBuy        : Boolean;
      CanStorage    : Boolean;
      CanGetBack    : Boolean;
      CanRepair     : Boolean;
      CanMakeDrug   : Boolean;
      CanUpgrade    : Boolean;
      CanMakeItem   : Boolean;
      CanItemMarket : Boolean;

      CanSpecialRepair  : Boolean;
      CanTotalRepair    : Boolean;

      // 문파 장원
      CanAgitUsage  : Boolean;
      CanAgitManage  : Boolean;
      CanBuyDecoItem : Boolean;

      // 기타
      CanDoingEtc : Boolean;

      BoSoundPlaying : Boolean;
      SoundStartTime : LongWord;

      MemorialCount : LongInt;

   private
   protected
   public
      constructor Create;
      destructor Destroy; override;
      procedure RunMsg (msg: TMessageInfo); override;
      procedure Run; override;
      procedure ActivateNpcUtilitys (saystr: string);  //상인이 할 수 있는 기능 제어,  판매, 구입, 맡기기 등...
      procedure UserCall (caller: TCreature); dynamic;
      procedure UserSelect (whocret: TCreature; selstr: string); dynamic;
      //procedure ArrangeSayStrings;
      procedure NpcSay (target: TCreature; str: string);
      function  ChangeNpcSayTag (src, orgstr, chstr: string): string;
      procedure NpcSayTitle (who: TCreature; title: string);
      procedure CheckNpcSayCommand (hum: TUserHuman; var source: string; tag: string); dynamic;
      procedure ClearNpcInfos;
      procedure LoadNpcInfos;
      procedure LoadMemorialCount;
      procedure WriteMemorialCount;
   end;

   TMerchant = class (TNormNpc)  //판매만 하는 상인
      MarketName: string;
      MarketType: byte;
      //RepairItem: byte;  //0:안함,  1:함
      //StorageItem: byte;
      PriceRate: integer;  //물가, 100:보통, 100보다 크면 비싸다.
      NoSeal: Boolean;
      BoCastleManage: Boolean;  //성에서 관리하는 상점 (사북성이 한개 있을 경우에 해당됨)
      BoHiddenNpc: Boolean;
      fSaveToFileCount: integer;
      CreateIndex: integer;   //생성될 때 순차적으로 부여되는 Index(부하 분산에 이용한다).
   private
      checkrefilltime: longword;
      checkverifytime: longword;
      //specialrepairtime: longword;
      //specialrepair: integer;
      function  GetGoodsList (gindex: integer): TList;
      function  GetGoodsPrice (uitem: TUserItem): integer;
      function  GetSellPrice (whocret: TUserHuman; price: integer): integer;
      function  GetBuyPrice (price: integer): integer;
      procedure RefillGoods;
      procedure SaveUpgradeItemList;
      procedure LoadUpgradeItemList;
      procedure VerifyUpgradeList;
   protected
   public
      DealGoods: TStringList;  //취급하는 아이템 StdMode   ;공유불가
      ProductList: TList;  //젠되는 아이템 list of PTMarketProduct  ;공유불가
      GoodsList: TList;  //현재 판매하는 상품 리스트  ;공유불가
      PriceList: TList;  //가격 리스트, 한번 판매된 아이템은 물가 정보에 기록이 남는다.

      UpgradingList: TList;  //업그레이드를 맡긴 아이템 목록

      constructor Create;
      destructor Destroy; override;
      procedure RunMsg (msg: TMessageInfo); override;
      procedure Run; override;
      procedure CheckNpcSayCommand (hum: TUserHuman; var source: string; tag: string); override;
      procedure UserCall (caller: TCreature); override;
      //------------------------------------------------------------------------
      // UserSelect에서 분리
      procedure SendGoodsEntry (who: TCreature; ltop: integer);  //
      procedure SendSellGoods (who: TCreature); //팔기 메뉴준다.
      procedure SendRepairGoods (who: TCreature); //수리하기 메뉴
      procedure SendSpecialRepairGoods (who: TCreature); //특수수리하기 메뉴
      procedure SendStorageItemMenu (who: TCreature);
      procedure SendStorageItemList (who: TCreature);
      procedure SendMakeDrugItemList (who: TCreature);
      procedure SendMakeFoodList (who: TCreature);
      procedure SendMakePotionList (who: TCreature);
      procedure SendMakeGemList (who: TCreature);
      procedure SendMakeItemList (who: TCreature);
      procedure SendMakeStuffList (who: TCreature);
      procedure SendMakeEtcList (who: TCreature);
      //------------------------------------------------------------------------
      //장원꾸미기
      procedure SendDecoItemListShow (who: TCreature);
      //------------------------------------------------------------------------
      // 위탁상점
      procedure SendUserMarket( hum : TuserHuman ; ItemType : integer ; UserMode : integer );
      //------------------------------------------------------------------------
      procedure UserSelect (whocret: TCreature; selstr: string); override;
      procedure SayMakeItemMaterials (whocret: TCreature; selstr: string);
      procedure QueryPrice (whocret: TCreature; uitem: TUserItem);
      function  AddGoods (uitem: TUserItem): Boolean;
      function  UserSellItem (whocret: TCreature; uitem: TUserItem): Boolean;
      function  UserCountSellItem (whocret: TCreature; uitem: TUserItem; sellcnt: integer): Boolean;
      procedure QueryRepairCost (whocret: TCreature; uitem: TUserItem);
      function  UserRepairItem (whocret: TCreature; puitem: PTUserItem): Boolean;
      procedure UserSelectUpgradeWeapon (hum: TUserHuman);
      procedure UserSelectGetBackUpgrade (hum: TUserHuman);
      procedure PriceDown (index: integer);
      procedure PriceUp (index: integer);
      function  GetPrice (index: integer): integer;
      procedure NewPrice (index, price: integer);
//      function  IsDealingItem (stdmode: integer): Boolean;
      function  IsDealingItem (stdmode: integer ; shape :integer ): Boolean;
      procedure UserBuyItem (whocret: TUserHuman; itmname: string; serverindex, BuyCount: integer);
      procedure UserWantDetailItems (whocret: TCreature; itmname: string; menuindex: integer);
      procedure UserMakeNewItem (whocret: TUserHuman; itmname: string);
      procedure UserManufactureItem (whocret: TUserHuman; itmname: string);
      procedure ClearMerchantInfos;
      procedure LoadMerchantInfos;
      procedure LoadMarketSavedGoods;
      function CheckMakeItemCondition (hum: TUserHuman; itemname: string; sItemMakeIndex, sItemName, sItemCount: array of string; var iPrice, iMakeCount: Integer): Integer;
      function GetGradeOfGuardStoneByName ( strGuardStone: string ): Integer;
   end;

   TGuildOfficial = class (TNormNpc)
   private
      function  UserDeclareGuildWarNow (hum: TUserHuman; gname: string): integer;
      function  UserBuildGuildNow (hum: TUserHuman; gname: string): Integer;
      function  UserFreeGuild (hum: TUserHuman): integer;
      procedure UserDonateGold (hum: TUserHuman);
      procedure UserRequestCastleWar (hum: TUserHuman);
//      function UserGuildMemberRecall (hum: TUserHuman; man: string): Boolean;
   public
      constructor Create;
      destructor Destroy; override;
      procedure Run; override;
      procedure UserCall (caller: TCreature); override;
      procedure UserSelect (whocret: TCreature; selstr: string); override;
   end;

   TTrainer = class (TNormNpc)
   private
      strucktime: longword;
      damagesum: integer;
      struckcount: integer;
   public
      constructor Create;
      procedure RunMsg (msg: TMessageInfo); override;
      procedure Run; override;
   end;

   TCastleManager = class (TMerchant)
   private
      procedure RepaireCastlesMainDoor (hum: TUserHuman);
      procedure RepaireCoreCastleWall (wall: integer; hum: TUserHuman);
      procedure HireCastleGuard (numstr: string; hum: TUserHuman);
      procedure HireCastleArcher (numstr: string; hum: TUserHuman);
   public
      constructor Create;
      procedure CheckNpcSayCommand (hum: TUserHuman; var source: string; tag: string); override;
      procedure UserCall (caller: TCreature); override;
      procedure UserSelect (whocret: TCreature; selstr: string); override;
   end;

   // 일정 범위안에 오면 나타나는 NPC(sonmg)
   THiddenNpc = class (TMerchant)
   private
   protected
      RunDone: Boolean;
      DigupRange: integer;
      DigdownRange: integer;
      procedure CheckComeOut; dynamic;
      procedure ComeOut; dynamic;
      procedure ComeDown; dynamic;
   public
      constructor Create;
      destructor Destroy; override;
      procedure RunMsg (msg: TMessageInfo); override;
      procedure Run; override;
   end;

implementation

uses
   svMain, RunSock, LocalDB, ObjMon2, Castle;


constructor TNormNpc.Create;
begin
   inherited Create;
   NeverDie := TRUE;
   RaceServer := RC_NPC;
   Light := 2;
   AntiPoison := 99;
   //SayStrings := TStringList.Create;
   Sayings := TList.Create;
   StickMode := TRUE;
   DefineDirectory := '';
   BoInvisible := FALSE;
   BoUseMapFileName := TRUE;

   CanSell      := FALSE;
   CanBuy       := FALSE;
   CanStorage   := FALSE;
   CanGetBack   := FALSE;
   CanRepair    := FALSE;
   CanMakeDrug  := FALSE;
   CanUpgrade   := FALSE;
   CanMakeItem  := FALSE;
   CanItemMarket:= FALSE;

   CanSpecialRepair  := FALSE;
   CanTotalRepair    := FALSE;

   // 문파 장원
   CanAgitUsage   := FALSE;
   CanAgitManage  := FALSE;
   CanBuyDecoItem := FALSE;

   // 기타
   CanDoingEtc    := FALSE;

   BoSoundPlaying := FALSE;
   SoundStartTime := GetTickCount;

   MemorialCount := 0;
end;

destructor TNormNpc.Destroy;
var
   i, j: integer;
begin
   //for i:=0 to SayStrings.Count-1 do
   //   TStringList(SayStrings.Objects[i]).Free;
   //SayStrings.Free;
   for i:=0 to Sayings.Count-1 do begin
      Dispose (PTQuestRecord(Sayings[i]));
      //PTQuestRecord 내부 블럭은 Free하지 않음 (원래 해야함)
   end;
   Sayings.Free;
   inherited Destroy;
end;

procedure TNormNpc.RunMsg (msg: TMessageInfo);
begin
   inherited RunMsg (msg);
end;

procedure TNormNpc.Run;
begin
   inherited Run;
end;

{procedure TNormNpc.ArrangeSayStrings;
var
   i, k: integer;
   strs: TStringList;
   ptq: PTQuestRecord;
begin
   //for i:=0 to SayStrings.Count-1 do begin
   //   strs := TStringList(SayStrings.Objects[i]);
   //   for k:=1 to strs.Count-1 do begin
   //      strs[0] := strs[0] + strs[k];
   //   end;
   //end;

end; }

procedure TNormNpc.ActivateNpcUtilitys (saystr: string);
var
   lwstr: string;
begin
   lwstr := LowerCase (saystr);
   if pos ('@buy', lwstr) > 0 then CanBuy := TRUE;
   if pos ('@sell', lwstr) > 0 then CanSell := TRUE;
   if pos ('@storage', lwstr) > 0 then CanStorage := TRUE;
   if pos ('@getback', lwstr) > 0 then CanGetBack := TRUE;
   if pos ('@repair', lwstr) > 0 then CanRepair := TRUE;
   if pos ('@makedrug', lwstr) > 0 then CanMakeDrug := TRUE;
   if pos ('@upgradenow', lwstr) > 0 then CanUpgrade := TRUE;
   if pos ('@s_repair', lwstr) > 0 then CanSpecialRepair := TRUE;
   if pos ('@t_repair', lwstr) > 0 then CanTotalRepair := TRUE;
   // 아이템 제조
   if pos ('@makefood', lwstr) > 0 then CanMakeItem := TRUE;
   if pos ('@makepotion', lwstr) > 0 then CanMakeItem := TRUE;
   if pos ('@makegem', lwstr) > 0 then CanMakeItem := TRUE;
   if pos ('@makeitem', lwstr) > 0 then CanMakeItem := TRUE;
   if pos ('@makestuff', lwstr) > 0 then CanMakeItem := TRUE;  //새로추가(sonmg)
   if pos ('@makeetc', lwstr) > 0 then CanMakeItem := TRUE;  //새로추가(sonmg)
   // 위탁상점
   if pos( '@market_', lwstr ) > 0 then CanItemMarket := TRUE;
   // 문파장원
   if pos( '@agitreg', lwstr ) > 0 then CanAgitUsage := TRUE;
   if pos( '@agitmove', lwstr ) > 0 then CanAgitUsage := TRUE;
   if pos( '@agitbuy', lwstr ) > 0 then CanAgitUsage := TRUE;
   if pos( '@agittrade', lwstr ) > 0 then CanAgitUsage := TRUE;
   // 문파장원(관리)
   if pos( '@agitextend', lwstr ) > 0 then CanAgitManage := TRUE;
   if pos( '@agitremain', lwstr ) > 0 then CanAgitManage := TRUE;
   if pos( '@@agitonerecall', lwstr ) > 0 then CanAgitManage := TRUE;
   if pos( '@agitrecall', lwstr ) > 0 then CanAgitManage := TRUE;
   if pos( '@@agitforsale', lwstr ) > 0 then CanAgitManage := TRUE;
   if pos( '@agitforsalecancel', lwstr ) > 0 then CanAgitManage := TRUE;
   if pos( '@gaboardlist', lwstr ) > 0 then CanAgitManage := TRUE;
   if pos( '@@guildagitdonate', lwstr ) > 0 then CanAgitManage := TRUE;
   if pos( '@viewdonation', lwstr ) > 0 then CanAgitManage := TRUE;
   // 장원꾸미기
   if pos( '@ga_decoitem_buy', lwstr ) > 0 then CanBuyDecoItem := TRUE;
   if pos( '@ga_decomon_count', lwstr ) > 0 then CanBuyDecoItem := TRUE;
   // 명성치
   if pos( '@@freepkother', lwstr ) > 0 then CanDoingEtc := TRUE;
end;

function GetPP (str: string): integer;
var
   n: integer;
begin
   Result := -1;
   if Length(str) = 2 then begin
      if UpCase(str[1]) = 'P' then begin
         n := Str_ToInt (str[2], -1);
         if n in [0..9] then
            Result := n;
      end;
      if UpCase(str[1]) = 'G' then begin
         n := Str_ToInt (str[2], -1);
         if n in [0..9] then
            Result := 100 + n;
      end;
      if UpCase(str[1]) = 'D' then begin
         n := Str_ToInt (str[2], -1);
         if n in [0..9] then
            Result := 200 + n;
      end;
      if UpCase(str[1]) = 'M' then begin
         n := Str_ToInt (str[2], -1);
         if n in [0..9] then
            Result := 300 + n;
      end;
   end;
end;

procedure TNormNpc.NpcSay (target: TCreature; str: string);  //점차 안 쓰임... 하드코딩 하지 않는 것이 좋음
begin
   str := ReplaceChar (str, '\', char($a));
	target.SendMsg (self, RM_MERCHANTSAY, 0, 0, 0, 0, UserName + '/' + str);
end;

function TNormNpc.ChangeNpcSayTag (src, orgstr, chstr: string): string;
var
   n: integer;
   src1, src2: string;
begin
   n := pos(orgstr, src);
   if n > 0 then begin
      src1 := Copy(src, 1, n-1);
      src2 := Copy(src, n+Length(orgstr), Length(src));
      Result := src1 + chstr + src2;
   end else
      Result := src;
end;

procedure TNormNpc.CheckNpcSayCommand (hum: TUserHuman; var source: string; tag: string);
var
   data, str2: string;
   n: integer;
begin
   if tag = '$OWNERGUILD' then begin
      data := UserCastle.OwnerGuildName;
      if data = '' then data := 'GameManagerconsultation';
      source := ChangeNpcSayTag (source, '<$OWNERGUILD>', data);
   end;
   if tag = '$LORD' then begin
      if UserCastle.OwnerGuild <> nil then begin
         data := UserCastle.OwnerGuild.GetGuildMaster;
      end else begin
         {$IFDEF KOREA} data := '유비';
         {$ELSE}        data := 'Yubi';
         {$ENDIF}
      end;
      source := ChangeNpcSayTag (source, '<$LORD>', data);
   end;
   if tag = '$GUILDWARFEE' then begin
      source := ChangeNpcSayTag (source, '<$GUILDWARFEE>', GetGoldStr(GUILDWARFEE));
   end;
   if tag = '$GUILDWARTIME' then begin
      source := ChangeNpcSayTag (source, '<$GUILDWARTIME>', IntToStr(GUILDWARTIME));
   end;
   if tag = '$CASTLEWARDATE' then begin
      if not UserCastle.BoCastleUnderAttack then begin
         data := UserCastle.GetNextWarDateTimeStr;
         if data <> '' then begin
            source := ChangeNpcSayTag (source, '<$CASTLEWARDATE>', data);
         end else begin
            {$IFDEF KOREA} source := '가까운 시일 안에는 공성전이 없다네.\ \<뒤로/@main>';
            {$ELSE}        source := 'Well I guess there may be no wall conquest war in the meam time .\ \<back/@main>';
            {$ENDIF}
         end;
      end else begin
         {$IFDEF KOREA} source := '지금 공성전 중이라네.\ \<뒤로/@main>';
         {$ELSE}        source := 'Now is on wall conquest war.\ \<back/@main>';
         {$ENDIF}
      end;
      source := ReplaceChar (source, '\', char($a));
   end;
   if tag = '$LISTOFWAR' then begin
      data := UserCastle.GetListOfWars;  //모든 공성 일정
      if data <> '' then begin
         source := ChangeNpcSayTag (source, '<$LISTOFWAR>', data);
      end else begin
         {$IFDEF KOREA} source := '일정이 없다네...\ \<뒤로/@main>';
         {$ELSE}        source := 'We have no schedule...\ \<back/@main>';
         {$ENDIF}
      end;
      source := ReplaceChar (source, '\', char($a));
   end;
   if tag = '$USERNAME' then begin
      source := ChangeNpcSayTag (source, '<$USERNAME>', hum.UserName);
   end;

   if tag = '$PKTIME' then begin
      source := ChangeNpcSayTag (source, '<$PKTIME>',hum.GetPKTimeMin);
   end;
   //여관 보관 개수
   if tag = '$SAVEITEM' then begin
      source := ChangeNpcSayTag (source, '<$SAVEITEM>', IntToStr(hum.SaveItems.Count));
   end;
   if tag = '$REMAINSAVEITEM' then begin
      source := ChangeNpcSayTag (source, '<$REMAINSAVEITEM>', IntToStr(MAXSAVELIMIT - hum.SaveItems.Count));
   end;
   if tag = '$MAXSAVEITEM' then begin
      source := ChangeNpcSayTag (source, '<$MAXSAVEITEM>', IntToStr(MAXSAVELIMIT));
   end;

   //문파 장원.
   if tag = '$GUILDAGITREGFEE' then begin
      source := ChangeNpcSayTag (source, '<$GUILDAGITREGFEE>', GetGoldStr(GUILDAGITREGFEE));
   end;
   if tag = '$GUILDAGITEXTENDFEE' then begin
      source := ChangeNpcSayTag (source, '<$GUILDAGITEXTENDFEE>', GetGoldStr(GUILDAGITEXTENDFEE));
   end;
   if tag = '$GUILDAGITMAXGOLD' then begin
      source := ChangeNpcSayTag (source, '<$GUILDAGITMAXGOLD>', GetGoldStr(GUILDAGITMAXGOLD));
   end;
   //장원꾸미기.
   if tag = '$AGITGUILDNAME' then begin
      source := ChangeNpcSayTag (source, '<$AGITGUILDNAME>', hum.GetGuildNameHereAgit);
   end;
   if tag = '$AGITGUILDMASTER' then begin
      source := ChangeNpcSayTag (source, '<$AGITGUILDMASTER>', hum.GetGuildMasterNameHereAgit);
   end;

   if tag = '$MEMORIALCOUNT' then begin
      source := ChangeNpcSayTag (source, '<$MEMORIALCOUNT>', IntToStr(MemorialCount));
   end;

   if CompareLStr (tag, '$STR(', 5)  then begin
      ArrestStringEx (tag, '(', ')', str2);
      n := GetPP (str2);
      if n >= 0 then begin
         case n of
            0..9:       source := ChangeNpcSayTag (source, '<'+tag+'>', IntToStr(TUserHuman(hum).QuestParams[n]));
            100..109:   source := ChangeNpcSayTag (source, '<'+tag+'>', IntToStr(GrobalQuestParams[n-100]));
            200..209:   source := ChangeNpcSayTag (source, '<'+tag+'>', IntToStr(TUserHuman(hum).DiceParams[n-200]));
            300..309:   source := ChangeNpcSayTag (source, '<'+tag+'>', IntToStr(PEnvir.MapQuestParams[n-300]));
         end;
      end;
   end;
end;

procedure ReadStrings (flname: string; strlist: TStringList);
var
   f: TextFile;
   str: string;
begin
   strlist.Clear;
   {$I-}
   AssignFile (f, flname);
   FileMode := 0;  {Set file access to read only }
   Reset (f);
   while not EOF(f) do begin
      ReadLn (f, str);
      strlist.Add (str);
   end;
   CloseFile (f);
   //IOResult
   {$I+}
end;

procedure WriteStrings (flname: string; strlist: TStringList);
var
   f: TextFile;
   str: string;
   i: integer;
begin
   {$I-}
   AssignFile (f, flname);
   //FileMode := 2;  {Set file access to read only }
   Rewrite (f);
   for i:=0 to strlist.Count-1 do begin
      WriteLn (f, strlist[i]);
   end;
   CloseFile (f);
   //IOResult
   {$I+}
end;

procedure TNormNpc.NpcSayTitle (who: TCreature; title: string);
var
   latesttakeitem: string;
   pcheckitem, puTemp: PTUserItem;
   batchlist: TStringList;
   batchdelay, previousbatchdelay: integer;
   bosaynow: Boolean;

   //6-11
   function CheckNameAndDeleteFromFileList (uname, listfile: string): Boolean;
   var
      i: integer;
      str: string;
      strlist: TStringList;
   begin
      Result := FALSE;
      listfile := EnvirDir + listfile;
      if FileExists (listfile) then begin
         strlist := TStringList.Create;
         try
            ReadStrings (listfile, strlist);
         except
            MainOutMessage ('loading fail.... => ' + listfile);
         end;
         for i:=0 to strlist.Count-1 do begin
            str := Trim(strlist[i]);
            if str = uname then begin
               strlist.Delete (i);
               Result := TRUE;
               break;
            end;
         end;
         try
            WriteStrings (listfile, strlist);
         except
            MainOutMessage ('saving fail.... => ' + listfile);
         end;
         strlist.Free;
      end else
         MainOutMessage ('file not found => ' + listfile);
   end;
   //6-11
   function CheckNameFromFileList (uname, listfile: string): Boolean;
   var
      i: integer;
      str: string;
      strlist: TStringList;
   begin
      Result := FALSE;
      listfile := EnvirDir + listfile;
      if FileExists (listfile) then begin
         strlist := TStringList.Create;
         try
            ReadStrings (listfile, strlist);
         except
            MainOutMessage ('loading fail.... => ' + listfile);
         end;
         for i:=0 to strlist.Count-1 do begin
            str := Trim(strlist[i]);
            if str = uname then begin
               Result := TRUE;
               break;
            end;
         end;
         strlist.Free;
      end else
         MainOutMessage ('file not found => ' + listfile);
   end;
   //6-11
   procedure AddNameFromFileList (uname, listfile: string);
   var
      i: integer;
      str: string;
      strlist: TStringList;
      flag: Boolean;
   begin
      listfile := EnvirDir + listfile;
      strlist := TStringList.Create;
      if FileExists (listfile) then begin
         try
            ReadStrings (listfile, strlist);
         except
            MainOutMessage ('loading fail.... => ' + listfile);
         end;
      end;

      //flag := FALSE;
      //for i:=0 to strlist.Count-1 do begin
      //   str := Trim(strlist[i]);
      //   if str = uname then begin
      //      flag := TRUE;
      //      break;
      //   end;
      //end;
      //if not flag then   //복수로 추가 안함

      strlist.Add (uname);

      try
         WriteStrings (listfile, strlist);
      except
         MainOutMessage ('saving fail.... => ' + listfile);
      end;
      strlist.Free;
   end;
   //6-11
   procedure DeleteNameFromFileList (uname, listfile: string);
   var
      i: integer;
      str: string;
      strlist: TStringList;
   begin
      listfile := EnvirDir + listfile;
      if FileExists (listfile) then begin
         strlist := TStringList.Create;
         try
            ReadStrings (listfile, strlist);
         except
            MainOutMessage ('loading fail.... => ' + listfile);
         end;
         for i:=0 to strlist.Count-1 do begin
            str := Trim(strlist[i]);
            if str = uname then begin
               strlist.Delete (i);
               break;
            end;
         end;
         try
            WriteStrings (listfile, strlist);
         except
            MainOutMessage ('saving fail.... => ' + listfile);
         end;
         strlist.Free;
      end else
         MainOutMessage ('file not found => ' + listfile);
   end;
   function  CheckQuestCondition (pq: PTQuestRecord): Boolean;
   var
      i: integer;
   begin
      Result := TRUE;
      if pq.BoRequire then begin
         for i:=0 to MAXREQUIRE-1 do begin
            if pq.QuestRequireArr[i].RandomCount > 0 then begin
               if Random (pq.QuestRequireArr[i].RandomCount) <> 0 then begin
                  Result := FALSE;
                  break;
               end;
            end;
            if who.GetQuestMark (pq.QuestRequireArr[i].CheckIndex) <> pq.QuestRequireArr[i].CheckValue then begin
               Result := FALSE;
               break;
            end;
         end;
      end;
   end;
   function FindItemFromState (iname: string; count: integer): PTUserItem;
   var
      n: integer;
   begin
      Result := nil;
      if CompareLStr (iname, '[NECKLACE]', 4) then begin
         if who.UseItems[U_NECKLACE].Index > 0 then
            Result := @(who.UseItems[U_NECKLACE]);
         exit;
      end;
      if CompareLStr (iname, '[RING]', 4) then begin
         if who.UseItems[U_RINGL].Index > 0 then
            Result := @(who.UseItems[U_RINGL]);
         if who.UseItems[U_RINGR].Index > 0 then
            Result := @(who.UseItems[U_RINGR]);
         exit;
      end;
      if CompareLStr (iname, '[ARMRING]', 4) then begin
         if who.UseItems[U_ARMRINGL].Index > 0 then
            Result := @(who.UseItems[U_ARMRINGL]);
         if who.UseItems[U_ARMRINGR].Index > 0 then
            Result := @(who.UseItems[U_ARMRINGR]);
         exit;
      end;
      if CompareLStr (iname, '[WEAPON]', 4) then begin
         if who.UseItems[U_WEAPON].Index > 0 then
            Result := @(who.UseItems[U_WEAPON]);
         exit;
      end;
      if CompareLStr (iname, '[HELMET]', 4) then begin
         if who.UseItems[U_HELMET].Index > 0 then
            Result := @(who.UseItems[U_HELMET]);
         exit;
      end;
      // 2003/03/15 COPARK 아이템 인벤토리 확장
      if CompareLStr (iname, '[BUJUK]', 4) then begin
         if who.UseItems[U_BUJUK].Index > 0 then
            Result := @(who.UseItems[U_BUJUK]);
         exit;
      end;
      if CompareLStr (iname, '[BELT]', 4) then begin
         if who.UseItems[U_BELT].Index > 0 then
            Result := @(who.UseItems[U_BELT]);
         exit;
      end;
      if CompareLStr (iname, '[BOOTS]', 4) then begin
         if who.UseItems[U_BOOTS].Index > 0 then
            Result := @(who.UseItems[U_BOOTS]);
         exit;
      end;
      if CompareLStr (iname, '[CHARM]', 4) then begin
         if who.UseItems[U_CHARM].Index > 0 then
            Result := @(who.UseItems[U_CHARM]);
         exit;
      end;

      Result := who.FindItemWear (iname, n);
      if n < count then
         Result := nil;
   end;
   function  CheckSayingCondition (clist: TList): Boolean;
   var
      i, k, m, n, param, tag, count, durasum, duratop: integer;
      ahour, amin, asec, amsec: word;
      pqc: PTQuestConditionInfo;
      pitem: PTUserItem;
      ps: PTStdItem;
      penv: TEnvirnoment;
      hum: TUserHuman;
      nFame: integer;
      WarriorCount, WizardCount, TaoistCount: integer;
      equalvar: integer;
      CheckMap: string;
      cret: TCreature;
      list: TList;
      flag: Boolean;
   begin
      Result := TRUE;

      for i:=0 to clist.Count-1 do begin
         pqc := PTQuestConditionInfo (clist[i]);
         case pqc.IfIdent of
            QI_CHECK:
               begin
                  param := Str_ToInt (pqc.IfParam, 0);
                  tag := Str_ToInt (pqc.IfTag, 0);
                  n := who.GetQuestMark (param);
                  if n = 0 then begin
                     if tag <> 0 then Result := FALSE;
                  end else
                     if tag = 0 then Result := FALSE;
               end;
            QI_CHECKOPENUNIT:
               begin
                  param := Str_ToInt (pqc.IfParam, 0);
                  tag := Str_ToInt (pqc.IfTag, 0);
                  n := who.GetQuestOpenIndexMark (param);
                  if n = 0 then begin
                     if tag <> 0 then Result := FALSE;
                  end else
                     if tag = 0 then Result := FALSE;
               end;
            QI_CHECKUNIT:
               begin
                  param := Str_ToInt (pqc.IfParam, 0);
                  tag := Str_ToInt (pqc.IfTag, 0);
                  n := who.GetQuestFinIndexMark (param);
                  if n = 0 then begin
                     if tag <> 0 then Result := FALSE;
                  end else
                     if tag = 0 then Result := FALSE;
               end;
            QI_RANDOM:
               begin
                  if Random(pqc.IfParamVal) <> 0 then Result := FALSE;
               end;
            QI_GENDER:
               begin
                  if CompareText (pqc.IfParam, 'MAN') = 0 then begin  //요구가 남자
                     if who.Sex <> 0 then Result := FALSE;
                  end else begin //
                     if who.Sex <> 1 then Result := FALSE;
                  end;
               end;
            QI_DAYTIME:
               begin
                  if CompareText (pqc.IfParam, 'SUNRAISE') = 0 then begin
                     if MirDayTime <> 0 then Result := FALSE;
                  end;
                  if CompareText (pqc.IfParam, 'DAY') = 0 then begin
                     if MirDayTime <> 1 then Result := FALSE;
                  end;
                  if CompareText (pqc.IfParam, 'SUNSET') = 0 then begin
                     if MirDayTime <> 2 then Result := FALSE;
                  end;
                  if CompareText (pqc.IfParam, 'NIGHT') = 0 then begin
                     if MirDayTime <> 3 then Result := FALSE;
                  end;
               end;
            QI_DAYOFWEEK:
               begin
                  if CompareLStr (pqc.IfParam, 'Sun', 3) then
                     if DayOfWeek(Date) <> 1 then Result := FALSE;
                  if CompareLStr (pqc.IfParam, 'Mon', 3) then
                     if DayOfWeek(Date) <> 2 then Result := FALSE;
                  if CompareLStr (pqc.IfParam, 'Tue', 3) then
                     if DayOfWeek(Date) <> 3 then Result := FALSE;
                  if CompareLStr (pqc.IfParam, 'Wed', 3) then
                     if DayOfWeek(Date) <> 4 then Result := FALSE;
                  if CompareLStr (pqc.IfParam, 'Thu', 3) then
                     if DayOfWeek(Date) <> 5 then Result := FALSE;
                  if CompareLStr (pqc.IfParam, 'Fri', 3) then
                     if DayOfWeek(Date) <> 6 then Result := FALSE;
                  if CompareLStr (pqc.IfParam, 'Sat', 3) then
                     if DayOfWeek(Date) <> 7 then Result := FALSE;
               end;
            QI_TIMEHOUR:
               begin
                  if (pqc.IfParamVal <> 0) and (pqc.IfTagVal = 0) then
                     pqc.IfTagVal := pqc.IfParamVal;
                  DecodeTime (Time, ahour, amin, asec, amsec);
                  if not ((ahour >= pqc.IfParamVal) and (ahour <= pqc.IfTagVal)) then
                     Result := FALSE;
               end;
            QI_TIMEMIN:
               begin
                  if (pqc.IfParamVal <> 0) and (pqc.IfTagVal = 0) then
                     pqc.IfTagVal := pqc.IfParamVal;
                  DecodeTime (Time, ahour, amin, asec, amsec);
                  if not ((amin >= pqc.IfParamVal) and (amin <= pqc.IfTagVal)) then
                     Result := FALSE;
               end;

            QI_CHECKITEM:
               begin
                  pcheckitem := who.FindItemNameEx (pqc.IfParam, count, durasum, duratop);
                  if count < pqc.IfTagVal then
                     Result := FALSE;
               end;
            QI_CHECKITEMW:
               begin
                  pcheckitem := FindItemFromState (pqc.IfParam, pqc.IfTagVal);
                  if pcheckitem = nil then
                     Result := FALSE;
               end;
            QI_CHECKGOLD:
               begin
                  if who.Gold < pqc.ifParamVal then
                     Result := FALSE;
               end;
            QI_ISTAKEITEM:
               begin
                  if latesttakeitem <> pqc.IfParam then
                     Result := FALSE;
               end;
            QI_CHECKLEVEL:
               begin
                  if who.Abil.Level < pqc.IfParamVal then
                     Result := FALSE;
               end;
            QI_CHECKJOB:
               begin
                  if CompareLStr (pqc.IfParam, 'Warrior', 3) then
                     if who.Job <> 0 then Result := FALSE;
                  if CompareLStr (pqc.IfParam, 'Wizard', 3) then
                     if who.Job <> 1 then Result := FALSE;
                  if CompareLStr (pqc.IfParam, 'Taoist', 3) then
                     if who.Job <> 2 then Result := FALSE;
               end;
            QI_CHECKDURA:
               begin
                  pcheckitem := who.FindItemNameEx (pqc.IfParam, count, durasum, duratop);
                  if Round(duratop/1000) < pqc.IfTagVal then
                     Result := FALSE;
               end;
            QI_CHECKDURAEVA:
               begin
                  pcheckitem := who.FindItemNameEx (pqc.IfParam, count, durasum, duratop);
                  if count > 0 then begin
                     if Round((durasum/count)/1000) < pqc.IfTagVal then
                        Result := FALSE;
                  end else
                     Result := FALSE;
               end;
            QI_CHECKPKPOINT:
               begin
                  if who.PKLevel < pqc.IfParamVal then
                     Result := FALSE;
               end;
            QI_CHECKLUCKYPOINT:
               begin
                  if who.BodyLuckLevel < pqc.IfParamVal then
                     Result := FALSE;
               end;
            QI_CHECKMON_MAP:
               begin
                  penv := GrobalEnvir.GetEnvir (pqc.IfParam);
                  if penv <> nil then
                     if UserEngine.GetMapMons (penv, nil) < pqc.IfTagVal then
                        Result := FALSE;
               end;
            QI_CHECKMON_NORECALLMOB_MAP:
               begin
                  penv := GrobalEnvir.GetEnvir (pqc.IfParam);
                  if penv <> nil then
                     if UserEngine.GetMapMonsNoRecallMob (penv, nil) < pqc.IfTagVal then
                        Result := FALSE;
               end;
            QI_CHECKMON_AREA:
               begin
               end;
            QI_CHECKHUM:
               begin
                  if UserEngine.GetHumCount (pqc.IfParam) < pqc.IfTagVal then
                     Result := FALSE;
               end;
            QI_CHECKBAGGAGE:
               begin
                  if who.CanAddItem then begin
                     if pqc.IfParam <> '' then begin
                        Result := FALSE;
                        ps := UserEngine.GetStdItemFromName (pqc.IfParam);
                        if ps <> nil then begin
                           if who.IsAddWeightAvailable (ps.Weight) then
                              Result := TRUE;
                        end;
                     end;
                  end else
                     Result := FALSE;
               end;
            //6-11
            QI_CHECKANDDELETENAMELIST:
               begin
                  if not CheckNameAndDeleteFromFileList (who.UserName, NpcBaseDir + pqc.IfParam{filename}) then
                     Result := FALSE;
               end;
            //6-11
            QI_CHECKANDDELETEIDLIST:
               begin
                  hum := TUserHuman (who);
                  if not CheckNameAndDeleteFromFileList (hum.UserId, NpcBaseDir + pqc.IfParam{filename}) then
                     Result := FALSE;
               end;
            //6-11
            QI_CHECKNAMELIST:
               begin
                  if not CheckNameFromFileList (who.UserName, NpcBaseDir + pqc.IfParam{filename}) then
                     Result := FALSE;
               end;

            //*dq
            QI_IFGETDAILYQUEST:
               begin
                  if who.GetDailyQuest <> 0 then
                     Result := FALSE;
               end;
            //*dq
            QI_RANDOMEX:
               begin
                  if Random(pqc.IfTagVal) >= pqc.IfParamVal then
                     Result := FALSE;
               end;
            //*dq
            QI_CHECKDAILYQUEST:
               begin
                  if who.GetDailyQuest <> pqc.IfParamVal then
                     Result := FALSE;
               end;

            QI_CHECKGRADEITEM:   //Event Grade
               begin
                  //------------------------------------------------------------
                  // IfParamVal : 이벤트 아이템 등급
                  // IfTagVal   : 존재 아이템 개수(카운트 아이템은 하나로 간주)
                  // 지정 등급의 아이템을 지정 개수 이상 가지고 있는지 검사해서
                  // 있으면 TRUE, 없으면 FALSE를 리턴함.
                  //------------------------------------------------------------
                  if who.FindItemEventGrade (pqc.IfParamVal, pqc.IfTagVal) = FALSE then
                     Result := FALSE;
               end;
            QI_CHECKBAGREMAIN:  // 가방창에 Parameter 개수만큼 남아 있는지
               begin
                  if who.CanAddItem then begin
                     if pqc.IfParamVal > 0 then begin
                        Result := FALSE;
                        if (MAXBAGITEM - who.ItemList.Count) >= pqc.IfParamVal then begin
                           Result := TRUE;
                        end;
                     end;
                  end else
                     Result := FALSE;
               end;

            QI_EQUALVAR:
               begin
                  equalvar := 0;
                  n := GetPP (pqc.IfParam);
                  m := GetPP (pqc.IfTag);
                  if m >= 0 then begin
                     case m of
                        0..9:
                           equalvar := TUserHuman(who).QuestParams[m];
                        100..109:
                           equalvar := GrobalQuestParams[m-100];
                        200..209:
                           equalvar := TUserHuman(who).DiceParams[m-200];
                        300..309:
                           equalvar := PEnvir.MapQuestParams[m-300];
                     end;
                  end;
                  if n >= 0 then begin
                     case n of
                        0..9:
                           if TUserHuman(who).QuestParams[n] <> equalvar then
                              Result := FALSE;
                        100..109:
                           //전역변수
                           if GrobalQuestParams[n-100] <> equalvar then
                              Result := FALSE;
                        200..209:
                           if TUserHuman(who).DiceParams[n-200] <> equalvar then
                              Result := FALSE;
                        300..309:
                           //맵지역변수
                           if PEnvir.MapQuestParams[n-300] <> equalvar then
                              Result := FALSE;
                     end;
                  end else
                     Result := FALSE;
               end;

            QI_EQUAL:
               begin
                  n := GetPP (pqc.IfParam);
                  if n >= 0 then begin
                     case n of
                        0..9:
                           if TUserHuman(who).QuestParams[n] <> pqc.IfTagVal then
                              Result := FALSE;
                        100..109:
                           //전역변수
                           if GrobalQuestParams[n-100] <> pqc.IfTagVal then
                              Result := FALSE;
                        200..209:
                           if TUserHuman(who).DiceParams[n-200] <> pqc.IfTagVal then
                              Result := FALSE;
                        300..309:
                           //맵지역변수
                           if PEnvir.MapQuestParams[n-300] <> pqc.IfTagVal then
                              Result := FALSE;
                     end;
                  end else
                     Result := FALSE;
               end;
            QI_LARGE:
               begin
                  n := GetPP (pqc.IfParam);
                  if n >= 0 then begin
                     case n of
                        0..9:
                           if TUserHuman(who).QuestParams[n] <= pqc.IfTagVal then
                              Result := FALSE;
                        100..109:
                           if GrobalQuestParams[n-100] <= pqc.IfTagVal then
                              Result := FALSE;
                        200..209:
                           if TUserHuman(who).DiceParams[n-200] <= pqc.IfTagVal then
                              Result := FALSE;
                        300..309:
                           if PEnvir.MapQuestParams[n-300] <= pqc.IfTagVal then
                              Result := FALSE;
                     end;
                  end else
                     Result := FALSE;
               end;
            QI_SMALL:
               begin
                  n := GetPP (pqc.IfParam);
                  if n >= 0 then begin
                     case n of
                        0..9:
                           if TUserHuman(who).QuestParams[n] >= pqc.IfTagVal then
                              Result := FALSE;
                        100..109:
                           if GrobalQuestParams[n-100] >= pqc.IfTagVal then
                              Result := FALSE;
                        200..209:
                           if TUserHuman(who).DiceParams[n-200] >= pqc.IfTagVal then
                              Result := FALSE;
                        300..309:
                           if PEnvir.MapQuestParams[n-300] >= pqc.IfTagVal then
                              Result := FALSE;
                     end;
                  end else
                     Result := FALSE;
               end;
            QI_ISGROUPOWNER:
               begin
                  //자신이 GroupOwner인지 검사.
                  Result := FALSE;
                  if who <> nil then begin
                     if who.GroupOwner <> nil then begin
                        if who.GroupOwner = who then
                           Result := TRUE;
                     end;
                  end;
               end;
            QI_ISEXPUSER:
               begin
                  //자신이 체험판 유저인지 검사한다.
                  Result := FALSE;
                  hum := TUserHuman (who);
                  if hum <> nil then begin
                     if hum.ApprovalMode = 1 then
                        Result := TRUE;
                  end;
               end;
            QI_CHECKLOVERFLAG:
               begin
                  if TUserHuman(who).fLover <> nil then begin
                     hum := UserEngine.GetUserHuman(TUserHuman(who).fLover.GetLoverName);
                     if hum <> nil then begin
                        param := Str_ToInt (pqc.IfParam, 0);
                        tag := Str_ToInt (pqc.IfTag, 0);
                        n := hum.GetQuestMark (param);
                        if n = 0 then begin
                           if tag <> 0 then Result := FALSE;
                        end else
                           if tag = 0 then Result := FALSE;
                     end else begin
                        Result := FALSE;
                     end;
                  end else begin
                     Result := FALSE;
                  end;
               end;
            QI_CHECKLOVERRANGE:
               begin
                  if TUserHuman(who).fLover <> nil then begin
                     hum := UserEngine.GetUserHuman(TUserHuman(who).fLover.GetLoverName);
                     if hum <> nil then begin
                        param := Str_ToInt (pqc.IfParam, 0);
                        if not( (abs(who.CX - hum.CX) <= param) and (abs(who.CY - hum.CY) <= param) ) then
                           Result := FALSE;
                     end else begin
                        Result := FALSE;
                     end;
                  end else begin
                     Result := FALSE;
                  end;
               end;
            QI_CHECKLOVERDAY:
               begin
                  if TUserHuman(who).fLover <> nil then begin
                     param := Str_ToInt( pqc.IfParam, 0 );
                     if Str_ToInt( TUserHuman(who).fLover.GetLoverDays, 0 ) < param then
                        Result := FALSE;
                  end else begin
                     Result := FALSE;
                  end;
               end;
            //명성치
            QI_CHECKFAMEGRADE:
               begin
                  TUserHuman(who).GetFameName(nFame);
                  if nFame < pqc.IfParamVal then begin
                     Result := FALSE;
                  end;
               end;
            QI_CHECKFAMEPOINT:
               begin
                  nFame := TUserHuman(who).Abil.FameCur;
                  if nFame < pqc.IfParamVal then begin
                     Result := FALSE;
                  end;
               end;
            QI_CHECKFAMEBASEPOINT:
               begin
                  nFame := TUserHuman(who).Abil.FameBase;
                  if nFame < pqc.IfParamVal then begin
                     Result := FALSE;
                  end;
               end;
            QI_CHECKDONATION:
               begin
                  if TUserHuman(who).GetGuildAgitDonation < pqc.IfParamVal then
                     Result := FALSE;
               end;
            QI_ISGUILDMASTER:
               begin
                  if not who.IsGuildMaster then
                     Result := FALSE;
               end;
            QI_CHECKWEAPONBADLUCK:
               begin
                  if who.UseItems[U_WEAPON].Index <> 0 then begin
                     if not (who.UseItems[U_WEAPON].Desc[4] - who.UseItems[U_WEAPON].Desc[3] > 0) then begin //저주가 붙어있을 때
                        Result := FALSE;
                     end;
                  end;
               end;
            QI_CHECKPREMIUMGRADE:
               begin
                  if who.PremiumGrade <> pqc.IfParamVal then begin
                     Result := FALSE;
                  end;
               end;
            QI_CHECKCHILDMOB:
               begin
                  if who.GetExistSlave(pqc.IfParam) = nil then begin
                     Result := FALSE;
                  end;
               end;
            QI_CHECKGROUPJOBBALANCE:
               begin
                  WarriorCount := 0;
                  WizardCount := 0;
                  TaoistCount := 0;
                  CheckMap := '';
                  for k:=0 to who.GroupMembers.Count-1 do begin
                     hum := UserEngine.GetUserHuman (who.GroupMembers[k]);
                     if hum <> nil then begin
                        //같은 맵에 있는지 체크
                        if CheckMap = '' then begin
                           CheckMap := hum.MapName;
                        end else begin
                           if CheckMap <> hum.MapName then begin
                              Result := FALSE;
                           end;
                        end;

                        if hum.Job = 0 then begin
                           Inc(WarriorCount);
                        end else if hum.Job = 1 then begin
                           Inc(WizardCount);
                        end else if hum.Job = 2 then begin
                           Inc(TaoistCount);
                        end;
                     end;
                  end;
                  if not( (WarriorCount = pqc.IfParamVal) and (WizardCount = pqc.IfParamVal) and (TaoistCount = pqc.IfParamVal) ) then begin
                     Result := FALSE;
                  end;
               end;
            QI_CHECKRANGEONELOVER:
               begin
                  //주변에 연인 맺은 사람이 있는지 체크
                  flag := FALSE;
                  list := TList.Create;
                  //맵퀘스트를 위해 PEnvir 대신에 who.PEnvir를 사용한다.
                  who.PEnvir.GetCreatureInRange (who.CX, who.CY, pqc.IfParamVal, TRUE, list);
                  for k:=0 to list.Count-1 do begin
                     cret := TCreature(list[k]);
                     if (cret <> nil) and (cret.RaceServer = RC_USERHUMAN) then begin
                        hum := TUserHuman(cret);
                        if (hum.fLover <> nil) and (hum.fLover.GetLoverName <> '') and (hum <> who) then begin
                           flag := TRUE;
                           break;
                        end;
                     end;
                  end;
                  list.Free;

                  if not flag then begin
                     Result := FALSE;
                  end;
               end;
            QI_EVENTCHECK: //ComeBack2005 이벤트 체크
               begin
                  if not who.EventCheckFlag then Result := FALSE;
               end;
            QI_CHECKITEMWVALUE: //착용중인 고통 아이템 기수치 체크
               begin
                  flag := FALSE;
                  pitem := FindItemFromState (pqc.IfParam, 1);
                  if pitem <> nil then begin
                     ps := UserEngine.GetStdItem(pitem.Index);
                     if ps <> nil then begin
                        if ps.Shape = PAIN_SERIES_SHAPE then begin
                           if pitem.Desc[10] >= pqc.IfTagVal then begin
                              flag := TRUE;
                           end;
                        end;
                     end;
                  end;

                  if not flag then
                     Result := FALSE;
               end;
         end;
      end;
   end;
   procedure GotoQuest (num: integer);
   var
      i: integer;
   begin
      for i:=0 to Sayings.Count-1 do
         if PTQuestRecord (Sayings[i]).LocalNumber = num then begin
            PTQuestRecord (TUserHuman(who).CurQuest) := PTQuestRecord (Sayings[i]);
            TUserHuman(who).CurQuestNpc := self;
            NpcSayTitle (who, '@main');
            break;
         end;
   end;
   procedure GotoSay (saystr: string);
   begin
      NpcSayTitle (who, saystr);
   end;
   procedure TakeItemFromUser (iname: string; count: integer);
   var
      i: integer;
      pu: PTUserItem;
      ps: PTStdItem;
   begin
      pu := nil;
      ps := nil;
      if CompareText (iname, NAME_OF_MONEY) = 0 then begin
         who.DecGold (count);
         who.GoldChanged;
         latesttakeitem := NAME_OF_MONEY;

         AddUserLog ('10'#9 + //판매 와 같이씀
                     who.MapName + ''#9 +
                     IntToStr(who.CX) + ''#9 +
                     IntToStr(who.CY) + ''#9 +
                     who.UserName + ''#9 +
                     NAME_OF_GOLD{'금전'} + ''#9 +
                     IntToStr(count) + ''#9 +
                     '1'#9 +
                     UserName);

      end else
         for i:=who.ItemList.Count-1 downto 0 do begin
            if count <= 0 then break;
            pu := PTUserItem(who.ItemList[i]);
            ps := UserEngine.GetStdItem( pu.Index );
            if ps <> nil then begin
               if CompareText (ps.Name, iname) = 0 then begin
                  //카운트아이템 (sonmg 2005/03/15)
                  if ps.OverlapItem >= 1 then begin
                     //로그남김
                     AddUserLog ('10'#9 + //판매 와 같이씀(카운트아이템)
                                 who.MapName + ''#9 +
                                 IntToStr(who.CX) + ''#9 +
                                 IntToStr(who.CY) + ''#9 +
                                 who.UserName + ''#9 +
                                 IntToStr(pu.Index) + ''#9 +
                                 IntToStr(count) + ''#9 +  //count
                                 '1'#9 +
                                 UserName);

                     //-------------------------(sonmg 2005/03/15)
                     if pu.Dura >= count then begin
                        pu.Dura := pu.Dura - count;

                        if pu.Dura <= 0 then begin
                           if who.RaceServer = RC_USERHUMAN then begin
                              TUserHuman(who).SendDelItem (pu^);
                           end;
                           Dispose(pu);
                           who.ItemList.Delete (i);
                        end else begin
                           who.SendMsg(self, RM_COUNTERITEMCHANGE, 0, pu.MakeIndex, pu.Dura, 0, ps.Name);
                        end;
                     end else begin
                        if who.RaceServer = RC_USERHUMAN then begin
                           TUserHuman(who).SendDelItem (pu^);
                        end;
                        Dispose (pu);
                        who.ItemList.Delete (i);
                     end;
                     //-------------------------

//                     TUserHuman(who).SendDelItem (pu^);    // 이상하다.
                     latesttakeitem := UserEngine.GetStdItemName (pu^.index);
//                     Dispose (pu);
//                     who.ItemList.Delete (i);
//                     Dec (count);
                     break;
                  end else begin
                     //-----------------------------------------------------------
                     //부적이면 개수를 체크해서 모자르면 다음 아이템으로 넘어감.
                     if iname = GetUnbindItemName(SHAPE_AMULET_BUNCH) then begin
                        if pu.Dura < pu.DuraMax then
                           continue;
                     end;
                     //-----------------------------------------------------------

                     //로그남김
                     AddUserLog ('10'#9 + //판매 와 같이씀
                                 who.MapName + ''#9 +
                                 IntToStr(who.CX) + ''#9 +
                                 IntToStr(who.CY) + ''#9 +
                                 who.UserName + ''#9 +
                                 iname + ''#9 +
                                 IntToStr(pu.MakeIndex) + ''#9 +  //count
                                 '1'#9 +
                                 UserName);

                     TUserHuman(who).SendDelItem (pu^);    // 이상하다.
                     latesttakeitem := UserEngine.GetStdItemName (pu^.index);
                     Dispose (pu);
                     who.ItemList.Delete (i);
                     Dec (count);
                  end;
               end;
            end;
         end;
   end;
   // 지정 등급 이하의 아이템을 모두 가져온다.
   procedure TakeEventGradeItemFromUser (grade: integer);
   var
      i: integer;
      pu: PTUserItem;
      ps: PTStdItem;
   begin
      pu := nil;
      ps := nil;
      for i:=who.ItemList.Count-1 downto 0 do begin
         pu := PTUserItem(who.ItemList[i]);
         if pu <> nil then begin
            ps := UserEngine.GetStdItem(pu.Index);
            if ps <> nil then begin
               if ps.EffType2 = EFFTYPE2_EVENT_GRADE then begin
                  if ps.EffValue2 <= grade then begin
                     //로그남김
                     AddUserLog ('10'#9 + //판매 와 같이씀
                                 who.MapName + ''#9 +
                                 IntToStr(who.CX) + ''#9 +
                                 IntToStr(who.CY) + ''#9 +
                                 who.UserName + ''#9 +
                                 ps.Name + ''#9 +
                                 IntToStr(pu.MakeIndex) + ''#9 +  //count
                                 '1'#9 +
                                 UserName);

                     TUserHuman(who).SendDelItem (pu^);    // 이상하다.
                     latesttakeitem := UserEngine.GetStdItemName (pu^.index);
                     Dispose (pu);
                     who.ItemList.Delete (i);
                  end;
               end;
            end;
         end;
      end;
   end;
   procedure TakeWItemFromUser (iname: string; count: integer);
   var
      i: integer;
   begin
      if CompareLStr (iname, '[NECKLACE]', 4) then begin
         if who.UseItems[U_NECKLACE].Index > 0 then begin
            TUserHuman(who).SendDelItem (who.UseItems[U_NECKLACE]);
            latesttakeitem := UserEngine.GetStdItemName (who.UseItems[U_NECKLACE].index);
            who.UseItems[U_NECKLACE].Index := 0;
         end;
         exit;
      end;
      if CompareLStr (iname, '[RING]', 4) then begin
         if who.UseItems[U_RINGL].Index > 0 then begin
            TUserHuman(who).SendDelItem (who.UseItems[U_RINGL]);
            latesttakeitem := UserEngine.GetStdItemName (who.UseItems[U_RINGL].index);
            who.UseItems[U_RINGL].Index := 0;
            exit;
         end;
         if who.UseItems[U_RINGR].Index > 0 then begin
            TUserHuman(who).SendDelItem (who.UseItems[U_RINGR]);
            latesttakeitem := UserEngine.GetStdItemName (who.UseItems[U_RINGR].index);
            who.UseItems[U_RINGR].Index := 0;
            exit;
         end;
         exit;
      end;
      if CompareLStr (iname, '[ARMRING]', 4) then begin
         if who.UseItems[U_ARMRINGL].Index > 0 then begin
            TUserHuman(who).SendDelItem (who.UseItems[U_ARMRINGL]);
            latesttakeitem := UserEngine.GetStdItemName (who.UseItems[U_ARMRINGL].index);
            who.UseItems[U_ARMRINGL].Index := 0;
            exit;
         end;
         if who.UseItems[U_ARMRINGR].Index > 0 then begin
            TUserHuman(who).SendDelItem (who.UseItems[U_ARMRINGR]);
            latesttakeitem := UserEngine.GetStdItemName (who.UseItems[U_ARMRINGR].index);
            who.UseItems[U_ARMRINGR].Index := 0;
            exit;
         end;
         exit;
      end;
      if CompareLStr (iname, '[WEAPON]', 4) then begin
         if who.UseItems[U_WEAPON].Index > 0 then begin
            TUserHuman(who).SendDelItem (who.UseItems[U_WEAPON]);
            latesttakeitem := UserEngine.GetStdItemName (who.UseItems[U_WEAPON].index);
            who.UseItems[U_WEAPON].Index := 0;
         end;
         exit;
      end;
      if CompareLStr (iname, '[HELMET]', 4) then begin
         if who.UseItems[U_HELMET].Index > 0 then begin
            TUserHuman(who).SendDelItem (who.UseItems[U_HELMET]);
            latesttakeitem := UserEngine.GetStdItemName (who.UseItems[U_HELMET].index);
            who.UseItems[U_HELMET].Index := 0;
         end;
         exit;
      end;
      // 2003/03/15 COPARK 아이템 인벤토리 확장
      if CompareLStr (iname, '[BUJUK]', 4) then begin
         if who.UseItems[U_BUJUK].Index > 0 then begin
            TUserHuman(who).SendDelItem (who.UseItems[U_BUJUK]);
            latesttakeitem := UserEngine.GetStdItemName (who.UseItems[U_BUJUK].index);
            who.UseItems[U_BUJUK].Index := 0;
         end;
         exit;
      end;
      if CompareLStr (iname, '[BELT]', 4) then begin
         if who.UseItems[U_BELT].Index > 0 then begin
            TUserHuman(who).SendDelItem (who.UseItems[U_BELT]);
            latesttakeitem := UserEngine.GetStdItemName (who.UseItems[U_BELT].index);
            who.UseItems[U_BELT].Index := 0;
         end;
         exit;
      end;
      if CompareLStr (iname, '[BOOTS]', 4) then begin
         if who.UseItems[U_BOOTS].Index > 0 then begin
            TUserHuman(who).SendDelItem (who.UseItems[U_BOOTS]);
            latesttakeitem := UserEngine.GetStdItemName (who.UseItems[U_BOOTS].index);
            who.UseItems[U_BOOTS].Index := 0;
         end;
         exit;
      end;
      if CompareLStr (iname, '[CHARM]', 4) then begin
         if who.UseItems[U_CHARM].Index > 0 then begin
            TUserHuman(who).SendDelItem (who.UseItems[U_CHARM]);
            latesttakeitem := UserEngine.GetStdItemName (who.UseItems[U_CHARM].index);
            who.UseItems[U_CHARM].Index := 0;
         end;
         exit;
      end;
      // 2003/03/15 COPARK 아이템 인벤토리 확장
      for i:=0 to U_CHARM do begin     // 8->12
         if count <= 0 then break;
         if who.UseItems[i].Index > 0 then begin
            if CompareText (UserEngine.GetStdItemName (who.UseItems[i].Index), iname) = 0 then begin
               TUserHuman(who).SendDelItem (who.UseItems[i]);
               latesttakeitem := UserEngine.GetStdItemName (who.UseItems[i].index);
               who.UseItems[i].Index := 0;
               Dec (count);
            end;
         end;
      end;
   end;
   procedure GiveItemToUser (receivewho: TCreature; iname: string; count: integer);
   var
      i, idx: integer;
      pstd, pstd2: PTStdItem;
      pu: PTUserItem;
      wg: integer;
   begin
      if CompareText (iname, NAME_OF_MONEY) = 0 then begin
         receivewho.IncGold (count);
         receivewho.GoldChanged;

         AddUserLog ('9'#9 + //구입 와 같이씀
                     receivewho.MapName + ''#9 +
                     IntToStr(receivewho.CX) + ''#9 +
                     IntToStr(receivewho.CY) + ''#9 +
                     receivewho.UserName + ''#9 +
                     NAME_OF_GOLD{'금전'} + ''#9 +
                     IntToStr(count) + ''#9 +  //count
                     '1'#9 +
                     UserName);
      end else begin
         idx := 0;
         idx := UserEngine.GetStdItemIndex(iname);
         pstd := UserEngine.GetStdItem(idx);

         if (idx > 0) and (pstd <> nil) then begin
            for i:=0 to count-1 do begin
               // 카운트아이템
               if pstd.OverlapItem >= 1 then begin
                  if receivewho.UserCounterItemAdd(pstd.StdMode, pstd.Looks, count, iName, FALSE) then begin
                      AddUserLog('9'#9 + //구입 와 같이씀(카운트아이템)
                          receivewho.MapName + ''#9 +
                          IntToStr(receivewho.CX) + ''#9 +
                          IntToStr(receivewho.CY) + ''#9 +
                          receivewho.UserName + ''#9 +
                          IntToStr(idx) + ''#9 +
                          IntToStr(count) + ''#9 +
                          '1'#9 +
                          UserName);
                      receivewho.WeightChanged;
                      exit;
                  end;
               end;

               if pstd.OverlapItem = 1 then
                  wg := receivewho.WAbil.Weight + (count div 10)
               else if pstd.OverlapItem >= 2 then
                  wg := receivewho.WAbil.Weight + (pstd.Weight * count)
               else
                  wg := receivewho.WAbil.Weight + pstd.Weight;

               if (receivewho.CanAddItem) {and (wg <= receivewho.WAbil.MaxWeight)} then begin
                  new (pu);
                  if UserEngine.CopyToUserItemFromName (iname, pu^) then begin
                     // gadget:카운트아이템
                     if pstd.OverlapItem >= 1 then begin
                        pu.Dura := count;
                     end;

                     receivewho.ItemList.Add (pu);
                     TUserHuman(receivewho).SendAddItem (pu^);
                     //로그남김
                     AddUserLog ('9'#9 + //구입 와 같이씀
                                 receivewho.MapName + ''#9 +
                                 IntToStr(receivewho.CX) + ''#9 +
                                 IntToStr(receivewho.CY) + ''#9 +
                                 receivewho.UserName + ''#9 +
                                 iname + ''#9 +
                                 IntToStr(pu.MakeIndex) + ''#9 +
                                 '1'#9 +
                                 UserName);
                     receivewho.WeightChanged;
                     if pstd.OverlapItem >= 1 then break;
                  end else
                     Dispose (pu);
               end else begin
                  new (pu);
                  if UserEngine.CopyToUserItemFromName (iname, pu^) then begin
                     pstd2 := UserEngine.GetStdItem(UserEngine.GetStdItemIndex(iname));
                     if pstd2 <> nil then
                     begin
                        if pstd2.OverlapItem >= 1 then begin
                           pu.Dura := count;  // gadget:카운트아이템
                        end;
                        //로그남김
                        AddUserLog ('9'#9 + //구입 와 같이씀
                                    receivewho.MapName + ''#9 +
                                    IntToStr(receivewho.CX) + ''#9 +
                                    IntToStr(receivewho.CY) + ''#9 +
                                    receivewho.UserName + ''#9 +
                                    iname + ''#9 +
                                    IntToStr(pu.MakeIndex) + ''#9 +
                                    '1'#9 +
                                    UserName);
                        receivewho.DropItemDown (pu^, 3, FALSE, receivewho, nil , 2);  //일정시간동안 다른 사람이 못 줍게
                     end;//if pstd2 <> nil then
                  end;
                  if pu <> nil then Dispose(pu);   // Memory Leak sonmg
               end;
            end;
         end;
      end;
   end;
   function  DoActionList (alist: TList): Boolean;
   var
      i, k, n, n1, n2, ixx, iyy, param, tag, timerval, iparam1, iparam2, iparam3, iparam4: integer;
      sparam1, sparam2, sparam3, sparam4 : string;
      pqa: PTQuestActioninfo;
      list: TList;
      hum: TUserHuman;
      envir: TEnvirnoment;
      kind: integer;
   begin
      iparam2 := 0;
      iparam3 := 0;
      Result := TRUE; //CONTINUE 의미
      timerval := 0;

      for i:=0 to alist.Count-1 do begin
         pqa := PTQuestActioninfo (alist[i]);
         case pqa.ActIdent of
            QA_SET:
               begin
                  param := Str_ToInt (pqa.ActParam, 0);
                  //if param > 100 then begin
                  tag := Str_ToInt (pqa.ActTag, 0);
                  who.SetQuestMark (param, tag);
                  //end;
               end;
            QA_OPENUNIT:
               begin
                  param := Str_ToInt (pqa.ActParam, 0);
                  tag := Str_ToInt (pqa.ActTag, 0);
                  who.SetQuestOpenIndexMark (param, tag);
               end;
            QA_SETUNIT:
               begin
                  param := Str_ToInt (pqa.ActParam, 0);
                  tag := Str_ToInt (pqa.ActTag, 0);
                  who.SetQuestFinIndexMark (param, tag);
               end;
            QA_TAKE:
               begin
                  TakeItemFromUser (pqa.ActParam, pqa.ActTagVal);
               end;
            QA_TAKEW:
               begin
                  TakeWItemFromUser (pqa.ActParam, pqa.ActTagVal);
               end;
            QA_GIVE:
               begin
                  GiveItemToUser (who, pqa.ActParam, pqa.ActTagVal);
               end;
            QA_CLOSE: //대화창을 닫음
               begin
                  who.SendMsg (self, RM_MERCHANTDLGCLOSE, 0, integer(self), 0, 0, '');
               end;
            QA_CLOSENOINVEN: //대화창을 닫음(인벤창은 건드리지 않음)
               begin
                  who.SendMsg (self, RM_MERCHANTDLGCLOSE, 0, integer(self), 1, 0, '');
               end;
            QA_RESET:
               begin
                  //if pqa.ActParamVal > 100 then  //100미만은 리렛할 수 없다
                  for k:=0 to pqa.ActTagVal-1 do
                     who.SetQuestMark (pqa.ActParamVal + k, 0);
               end;
            QA_RESETUNIT:
               begin
                  //for k:=0 to pqa.ActTagVal-1 do
                  //   if pqa.ActParamVal + k <= 100 then  //100이하만 리셋 됨
                  //      who.SetQuestMark (pqa.ActParamVal + k, 0);
               end;
            QA_MAPMOVE:  //자유이동 시켜줌
               begin
                  who.SendRefMsg (RM_SPACEMOVE_HIDE, 0, 0, 0, 0, '');
                  who.SpaceMove (pqa.ActParam, pqa.ActTagVal, pqa.ActExtraVal, 0);
                  bosaynow := TRUE;
               end;
            QA_MAPRANDOM:
               begin
                  who.SendRefMsg (RM_SPACEMOVE_HIDE, 0, 0, 0, 0, '');
                  who.RandomSpaceMove (pqa.ActParam, 0);
                  bosaynow := TRUE;
               end;
            QA_BREAK:
               Result := FALSE;  //break;
            QA_TIMERECALL:
               begin
                  TUserHuman(who).BoTimeRecall := TRUE;
                  TUserHuman(who).TimeRecallMap := TUserHuman(who).MapName;
                  TUserHuman(who).TimeRecallX := TUserHuman(who).CX;
                  TUserHuman(who).TimeRecallY := TUserHuman(who).CY;
                  TUserHuman(who).TimeRecallEnd := LongInt(GetTickCount) + pqa.ActParamVal * 60 * 1000;
               end;
            QA_TIMERECALLGROUP:
               begin
                  for k:=0 to who.GroupMembers.Count-1 do begin
                     hum := UserEngine.GetUserHuman (who.GroupMembers[k]);
                     if hum <> nil then begin
                        hum.BoTimeRecall := FALSE; //개인 TimeRecall은 해제
                        hum.BoTimeRecallGroup := TRUE;
                        hum.TimeRecallMap := hum.MapName;
                        hum.TimeRecallX := hum.CX;
                        hum.TimeRecallY := hum.CY;
                        hum.TimeRecallEnd := LongInt(GetTickCount) + pqa.ActParamVal * 60 * 1000;
                     end;
                  end;
               end;
            QA_BREAKTIMERECALL:
               begin
                  TUserHuman(who).BoTimeRecall := FALSE;
                  TUserHuman(who).BoTimeRecallGroup := FALSE;
               end;
            QA_PARAM1:
               begin
                  iparam1 := pqa.ActParamVal;
                  sparam1 := pqa.ActParam;
               end;
            QA_PARAM2:
               begin
                  iparam2 := pqa.ActParamVal;
                  sparam2 := pqa.ActParam;
               end;
            QA_PARAM3:
               begin
                  iparam3 := pqa.ActParamVal;
                  sparam3 := pqa.ActParam;
               end;
            QA_PARAM4:
               begin
                  iparam4 := pqa.ActParamVal;
                  sparam4 := pqa.ActParam;
               end;
            QA_TAKECHECKITEM:
               begin
                  if pcheckitem <> nil then begin
                     who.DeletePItemAndSend (pcheckitem);
                  end;
               end;
            QA_MONGEN:
               begin
                  for k:=0 to pqa.ActTagVal-1 do begin
                     //pqa.ActTagVal : 몹수
                     //pqa.ActExtraVal : 범위
                     //sparam1 : map
                     //iparam2 : x
                     //iparam3 : y
                     ixx := iparam2 - pqa.ActExtraVal + Random(pqa.ActExtraVal*2+1);
                     iyy := iparam3 - pqa.ActExtraVal + Random(pqa.ActExtraVal*2+1);
                     UserEngine.AddCreatureSysop (UpperCase(sparam1),  //map
                                                  ixx,
                                                  iyy,
                                                  pqa.ActParam); //mon-name
                  end;
               end;
            QA_MONCLEAR:
               begin
                  list := TList.Create;
                  UserEngine.GetMapMons (GrobalEnvir.GetEnvir(pqa.ActParam), list);
                  for k:=0 to list.Count-1 do begin
                     TCreature(list[k]).BoNoItem := TRUE;
                     TCreature(list[k]).WAbil.HP := 0;  //모두 죽인다.
                  end;
                  list.Free;
               end;
            QA_MOV:
               begin
                  n := GetPP (pqa.ActParam);
                  if n >= 0 then begin
                     case n of
                        0..9:
                           TUserHuman(who).QuestParams[n] := pqa.ActTagVal;
                        100..109:
                           GrobalQuestParams[n-100] := pqa.ActTagVal;
                        200..209:
                           TUserHuman(who).DiceParams[n-200] := pqa.ActTagVal;
                        300..309:
                           PEnvir.MapQuestParams[n-300] := pqa.ActTagVal;
                     end;
                  end;
               end;
            QA_INC:
               begin
                  n := GetPP (pqa.ActParam);
                  if n >= 0 then begin
                     case n of
                        0..9:
                           if pqa.ActTagVal > 1 then
                              TUserHuman(who).QuestParams[n] := TUserHuman(who).QuestParams[n] + pqa.ActTagVal
                           else
                              TUserHuman(who).QuestParams[n] := TUserHuman(who).QuestParams[n] + 1;
                        100..109:
                           if pqa.ActTagVal > 1 then
                              GrobalQuestParams[n-100] := GrobalQuestParams[n-100] + pqa.ActTagVal
                           else
                              GrobalQuestParams[n-100] := GrobalQuestParams[n-100] + 1;
                        200..209:
                           if pqa.ActTagVal > 1 then
                              TUserHuman(who).DiceParams[n-200] := TUserHuman(who).DiceParams[n-200] + pqa.ActTagVal
                           else
                              TUserHuman(who).DiceParams[n-200] := TUserHuman(who).DiceParams[n-200] + 1;
                        300..309:
                           if pqa.ActTagVal > 1 then
                              PEnvir.MapQuestParams[n-300] := PEnvir.MapQuestParams[n-300] + pqa.ActTagVal
                           else
                              PEnvir.MapQuestParams[n-300] := PEnvir.MapQuestParams[n-300] + 1;
                     end;
                  end;
               end;
            QA_DEC:
               begin
                  n := GetPP (pqa.ActParam);
                  if n >= 0 then begin
                     case n of
                        0..9:
                           if pqa.ActTagVal > 1 then
                              TUserHuman(who).QuestParams[n] := TUserHuman(who).QuestParams[n] - pqa.ActTagVal
                           else
                              TUserHuman(who).QuestParams[n] := TUserHuman(who).QuestParams[n] - 1;
                        100..109:
                           if pqa.ActTagVal > 1 then
                              GrobalQuestParams[n-100] := GrobalQuestParams[n-100] - pqa.ActTagVal
                           else
                              GrobalQuestParams[n-100] := GrobalQuestParams[n-100] - 1;
                        200..209:
                           if pqa.ActTagVal > 1 then
                              TUserHuman(who).DiceParams[n-200] := TUserHuman(who).DiceParams[n-200] - pqa.ActTagVal
                           else
                              TUserHuman(who).DiceParams[n-200] := TUserHuman(who).DiceParams[n-200] - 1;
                        300..309:
                           if pqa.ActTagVal > 1 then
                              PEnvir.MapQuestParams[n-300] := PEnvir.MapQuestParams[n-300] - pqa.ActTagVal
                           else
                              PEnvir.MapQuestParams[n-300] := PEnvir.MapQuestParams[n-300] - 1;
                     end;
                  end;
               end;
            QA_SUM:
               begin
                  n1 := 0;
                  n := GetPP (pqa.ActParam);
                  if n >= 0 then begin
                     case n of
                        0..9:     n1 := TUserHuman(who).QuestParams[n];
                        100..109:  n1 := GrobalQuestParams[n-100];
                        200..209:  n1 := TUserHuman(who).DiceParams[n-200];
                        300..309:  n1 := PEnvir.MapQuestParams[n-300];
                     end;
                  end;
                  n2 := 0;
                  n := GetPP (pqa.ActTag);
                  if n >= 0 then begin
                     case n of
                        0..9:     n2 := TUserHuman(who).QuestParams[n];
                        100..109:  n2 := GrobalQuestParams[n-100];
                        200..209:  n2 := TUserHuman(who).DiceParams[n-200];
                        300..309:  n2 := PEnvir.MapQuestParams[n-300];
                     end;
                  end;
                  n := GetPP (pqa.ActParam);
                  if n >= 0 then begin
                     case n of
                        0..9:      TUserHuman(who).QuestParams[9] := TUserHuman(who).QuestParams[9] + n1 + n2;
                        100..109:  GrobalQuestParams[9] := GrobalQuestParams[9] + n1 + n2;
                        200..209:   TUserHuman(who).DiceParams[9] := TUserHuman(who).DiceParams[9] + n1 + n2;
                        300..309:   PEnvir.MapQuestParams[9] := PEnvir.MapQuestParams[9] + n1 + n2;
                     end;
                  end;
               end;

            QA_MOVRANDOM:  //MOVR
               begin
                  n := GetPP (pqa.ActParam);
                  if n >= 0 then begin
                     case n of
                        0..9:
                           TUserHuman(who).QuestParams[n] := Random(pqa.ActTagVal);
                        100..109:
                           GrobalQuestParams[n-100] := Random(pqa.ActTagVal);
                        200..209:
                           TUserHuman(who).DiceParams[n-200] := Random(pqa.ActTagVal);
                        300..309:
                           PEnvir.MapQuestParams[n-300] := Random(pqa.ActTagVal);
                     end;
                  end;
               end;
            QA_EXCHANGEMAP:
               begin
                  //부를 사람
                  envir := GrobalEnvir.GetEnvir (pqa.ActParam);
                  if envir <> nil then begin
                     list := TList.Create;
                     UserEngine.GetAreaUsers (envir, 0, 0, 1000, list);
                     if list.Count > 0 then begin
                        //한명만 선택
                        hum := TUserHuman (list[0]);
                        if hum <> nil then begin
                           hum.RandomSpaceMove (MapName, 0);
                        end;
                     end;
                     list.Free;
                  end;
                  //나도 이동
                  who.RandomSpaceMove (pqa.ActParam, 0);
               end;
            QA_RECALLMAP:
               begin
                  //부를 사람
                  envir := GrobalEnvir.GetEnvir (pqa.ActParam);
                  if envir <> nil then begin
                     list := TList.Create;
                     UserEngine.GetAreaUsers (envir, 0, 0, 1000, list);
                     for k:=0 to list.Count-1 do begin
                        hum := TUserHuman (list[k]);
                        if hum <> nil then begin
                           hum.RandomSpaceMove (MapName, 0);
                        end;
                        //22명 제한
                        if k > 20 then break;
                     end;
                     list.Free;
                  end;
               end;
            QA_BATCHDELAY:
               begin
                  batchdelay := pqa.ActParamVal * 1000;
               end;
            QA_ADDBATCH:
               begin
                  batchlist.AddObject (pqa.ActParam, TObject(batchdelay));
               end;
            QA_BATCHMOVE:
               begin
                  for k:=0 to batchlist.Count-1 do begin
                     who.SendDelayMsg (self, RM_RANDOMSPACEMOVE, 0, 0, 0, 0, batchlist[k], previousbatchdelay + integer(batchlist.Objects[k]));
                     previousbatchdelay := previousbatchdelay + integer(batchlist.Objects[k])
                  end;
               end;
            QA_PLAYDICE:
               begin
                  who.SendMsg (self, RM_PLAYDICE,
                                     pqa.ActParamVal,  //굴리는 주사위 수
                                     MakeLong(MakeWord(TUserHuman(who).DiceParams[0],
                                                       TUserHuman(who).DiceParams[1]),
                                              MakeWord(TUserHuman(who).DiceParams[2],
                                                       TUserHuman(who).DiceParams[3])),
                                     MakeLong(MakeWord(TUserHuman(who).DiceParams[4],
                                                       TUserHuman(who).DiceParams[5]),
                                              MakeWord(TUserHuman(who).DiceParams[6],
                                                       TUserHuman(who).DiceParams[7])),
                                     MakeLong(MakeWord(TUserHuman(who).DiceParams[8],
                                                       TUserHuman(who).DiceParams[9]),
                                              0),
                                     pqa.ActTag);  //굴린후 이동 대화 태그 예)@diceresult
                  bosaynow := TRUE;
               end;
            QA_PLAYROCK:  //가위바위보 게임
               begin
                  who.SendMsg (self, RM_PLAYROCK,
                                     pqa.ActParamVal,  //굴리는 주사위 수
                                     MakeLong(MakeWord(TUserHuman(who).DiceParams[0],
                                                       TUserHuman(who).DiceParams[1]),
                                              MakeWord(TUserHuman(who).DiceParams[2],
                                                       TUserHuman(who).DiceParams[3])),
                                     MakeLong(MakeWord(TUserHuman(who).DiceParams[4],
                                                       TUserHuman(who).DiceParams[5]),
                                              MakeWord(TUserHuman(who).DiceParams[6],
                                                       TUserHuman(who).DiceParams[7])),
                                     MakeLong(MakeWord(TUserHuman(who).DiceParams[8],
                                                       TUserHuman(who).DiceParams[9]),
                                              0),
                                     pqa.ActTag);  //굴린후 이동 대화 태그 예)@diceresult
                  bosaynow := TRUE;
               end;
            //6-11
            QA_ADDNAMELIST:
               begin
                  AddNameFromFileList (who.UserName, NpcBaseDir + pqa.ActParam{filename});
               end;
            //6-11
            QA_DELETENAMELIST:
               begin
                  DeleteNameFromFileList (who.UserName, NpcBaseDir + pqa.ActParam{filename});
               end;
            //*DQ
            QA_RANDOMSETDAILYQUEST:
               begin
                  who.SetDailyQuest (pqa.ActParamVal + Random(pqa.ActTagVal - pqa.ActParamVal + 1));
               end;
            //*DQ
            QA_SETDAILYQUEST:
               begin
                  who.SetDailyQuest (pqa.ActParamVal);
               end;
            //경험치 주는 스크립트
            QA_GIVEEXP:
               begin
                  // 4주년 이벤트용 경험치 주는 명령(추후 삭제 요망)
//                  who.WinExp( _MIN(pqa.ActParamVal, 5000) );
//                  MainOutMessage( 'GIVEEXP(' + IntToStr(_MIN(pqa.ActParamVal, 5000)) + ') : ' + who.UserName );
               end;

            QA_TAKEGRADEITEM: // Event Grade
               begin
                  TakeEventGradeItemFromUser (pqa.ActParamVal);
               end;

            QA_GOTOQUEST:
               begin
                  GotoQuest (pqa.ActParamVal);
               end;
            QA_ENDQUEST:
               begin
                  TUserHuman(who).CurQuest := nil;
               end;
            QA_GOTO:
               begin
                  GotoSay (pqa.ActParam);
               end;
            QA_SOUND:
               begin
                  who.SendMsg( self, RM_SOUND , 0 ,Str_ToInt( pqa.ActParam,0), 0 , 0 ,'');
               end;
            QA_SOUNDALL:
               begin
                  //시간이 지나면 플래그 Reset
                  if GetTickCount - SoundStartTime > 25 * 1000{25초} then begin
                     SoundStartTime := GetTickCount;
                     BoSoundPlaying := FALSE;
                  end;

                  if not BoSoundPlaying then begin
                     BoSoundPlaying := TRUE;
                     //사운드 플레이 요청
                     SendRefMsg (RM_DIGUP, Dir, CX, CY, 0, '');
                  end;
               end;
            QA_CHANGEGENDER:
               begin
                  TUserHuman(who).CmdChangeSex;

                  if who.Sex = 1 then begin
                     {$IFDEF KOREA}
                     who.BoxMsg( '남성에서 여성으로 변화하였습니다.\재접속하면 변화된 모습을 확인하실 수 있습니다.',1);
                     who.SysMsg( '남성에서 여성으로 변화하였습니다. 재접속하면 변화된 모습을 확인하실 수 있습니다.',1);
                     {$ELSE}
                     who.BoxMsg( 'Changed to from a man to a woman;\by reconnecting, you may check your new looks.',1);
                     who.SysMsg( 'Changed to from a man to a woman; by reconnecting, you may check your new looks.',1);
                     {$ENDIF}
                  end else begin
                     {$IFDEF KOREA}
                     who.BoxMsg( '여성에서 남성으로 변화하였습니다.\재접속하면 변화된 모습을 확인하실 수 있습니다.',1);
                     who.SysMsg( '여성에서 남성으로 변화하였습니다. 재접속하면 변화된 모습을 확인하실 수 있습니다.',1);
                     {$ELSE}
                     who.BoxMsg( 'Changed to from a woman to a man;\by reconnecting, you may check your new looks.',1);
                     who.SysMsg( 'Changed to from a woman to a man; by reconnecting, you may check your new looks.',1);
                     {$ENDIF}
                  end;
               end;
            QA_KICK:
               begin
                  TUserHuman(who).EmergencyClose := TRUE;
               end;
            QA_MOVEALLMAP:
               begin
                  param := pqa.ActTagVal;
                  //이동 시킬 사람
                  envir := GrobalEnvir.GetEnvir (MapName);
                  if envir <> nil then begin
                     list := TList.Create;
                     UserEngine.GetAreaUsers (envir, 0, 0, 1000, list);
                     for k:=0 to list.Count-1 do begin
                        hum := TUserHuman (list[k]);
                        if hum <> nil then begin
                           hum.RandomSpaceMove (pqa.ActParam, 0);
                        end;
                        //param명 제한
                        if k >= (param - 1) then break;
                     end;
                     list.Free;
                  end;
               end;
            QA_MOVEALLMAPGROUP:
               begin
                  if who.GroupOwner = nil then begin
                     // 그룹이 없고 자기 혼자만 있을 때
                     if (pqa.ActTag = '') and (pqa.ActExtra = '') then begin
                        who.RandomSpaceMove(pqa.ActParam, 0);
                     end else begin
                        who.SpaceMove (pqa.ActParam, pqa.ActTagVal, pqa.ActExtraVal, 0);
                     end;
                  end else if who.GroupOwner = who then begin //자신이 그룹짱
                     for k:=0 to who.GroupMembers.Count-1 do begin  //자신 포함.
                        hum := UserEngine.GetUserHuman (who.GroupMembers[k]);
                        if hum <> nil then begin
                           // 현재 맵에 있는 사람만 지정 맵으로 이동.
                           if hum.MapName = MapName then begin
                              if (pqa.ActTag = '') and (pqa.ActExtra = '') then begin
                                 hum.RandomSpaceMove(pqa.ActParam, 0);
                              end else begin
                                 hum.SpaceMove (pqa.ActParam, pqa.ActTagVal, pqa.ActExtraVal, 0);
                              end;
                           end;
                        end;
                     end;
                  end;
               end;
            QA_RECALLMAPGROUP:
               begin
                  n := (GetTickCount - who.CGHIstart) div 1000;
                  who.CGHIstart := who.CGHIstart + longword(n * 1000);
                  if who.CGHIUseTime > n then who.CGHIUseTime := who.CGHIUseTime - n
                  else who.CGHIUseTime := 0;
                  if who.CGHIUseTime = 0 then begin
                     if who.GroupOwner = who then begin //자신이 그룹짱
                        for k:=1 to who.GroupMembers.Count-1 do begin  //자신 빼고
                           // 지정한 맵에 있는 사람만 소환
                           TUserHuman(who).CmdRecallMan (who.GroupMembers[k], pqa.ActParam);
                        end;
                        who.CGHIstart := GetTickCount;
                        who.CGHIUseTime := 10;  //10초 간격
                     end;
                  end else begin
                     {$IFDEF KOREA} who.SysMsg (IntToStr(who.CGHIUseTime) + '초 후에 다시 사용할 수 있습니다.', 0);
                     {$ELSE}        who.SysMsg ('Can be used again after ' + IntToStr(who.CGHIUseTime) + ' seconds.', 0);
                     {$ENDIF}
                  end;
               end;
            QA_WEAPONUPGRADE:
               begin
                  if (pqa.ActParam = 'DC') or (pqa.ActParam = '파괴') then
                     TUserHuman(who).CmdRefineWeapon(pqa.ActTagVal, 0, 0, 0)
                  else if (pqa.ActParam = 'MC') or (pqa.ActParam = '마법') then
                     TUserHuman(who).CmdRefineWeapon(0, pqa.ActTagVal, 0, 0)
                  else if (pqa.ActParam = 'SC') or (pqa.ActParam = '도력') then
                     TUserHuman(who).CmdRefineWeapon(0, 0, pqa.ActTagVal, 0)
                  else if (pqa.ActParam = 'ACC') or (pqa.ActParam = '정확') then
                     TUserHuman(who).CmdRefineWeapon(0, 0, 0, pqa.ActTagVal);
               end;
            QA_SETALLINMAP:
               begin
                  param := Str_ToInt (pqa.ActParam, 0);
                  tag := Str_ToInt (pqa.ActTag, 0);
                  //맵에 있는 모든 사람
                  envir := GrobalEnvir.GetEnvir (MapName);
                  if envir <> nil then begin
                     list := TList.Create;
                     UserEngine.GetAreaUsers (envir, 0, 0, 1000, list);
                     for k:=0 to list.Count-1 do begin
                        hum := TUserHuman (list[k]);
                        if hum <> nil then
                           hum.SetQuestMark (param, tag);
                     end;
                     list.Free;
                  end;
               end;
            QA_INCPKPOINT:
               begin
                  param := Str_ToInt (pqa.ActParam, 0);
                  TUserHuman(who).IncPkPoint(param);
               end;
            QA_DECPKPOINT:
               begin
                  param := Str_ToInt (pqa.ActParam, 0);
                  TUserHuman(who).DecPkPoint(param);
               end;
            QA_MOVETOLOVER:   //연인 앞으로 이동
               begin
                  if TUserHuman(who).fLover <> nil then begin
                     if TUserHuman(who).fLover.GetLoverName <> '' then
                        TUserHuman(who).CmdCharSpaceMove( TUserHuman(who).fLover.GetLoverName );
                  end;
               end;
            QA_BREAKLOVER:   //연인 관계 일방 해제
               begin
                  TUserHuman(who).CmdBreakLoverRelation;
               end;

            QA_USEFAMEPOINT:   //명성치 사용
               begin
                  who.UseCurrentFamePoint( pqa.ActParamVal );
               end;
            QA_DECWEAPONBADLUCK:
               begin
                  who.DecWeaponBadLuck;
               end;
            QA_DECDONATION:   //장원기부금
               begin
                  TUserHuman(who).DecGuildAgitDonation( pqa.ActParamVal );
               end;
            QA_SHOWEFFECT:    //장원이펙트
               begin
                  if pqa.ActTagVal > 0 then tag := pqa.ActTagVal * 1000
                  else tag := 60000;

                  case pqa.ActParamVal of  //이펙트 종류
                  1:
                     begin
                        who.SendRefMsg (RM_LOOPNORMALEFFECT, integer(self), tag, 0, NE_JW_EFFECT1, '');
                     end;
                  else
                     begin
                        who.SendRefMsg (RM_LOOPNORMALEFFECT, integer(self), tag, 0, NE_JW_EFFECT1, '');
                     end;
                  end;
               end;
            QA_MONGENAROUND:    //캐릭 주위에 몬스터 젠
               begin
                  for ixx:=who.CX-2 to who.CX+2 do begin
                     for iyy:=who.CY-2 to who.CY+2 do begin
                        //sparam1 : map
                        if sparam1 = '' then sparam1 := who.MapName;
                        if ( (abs(who.CX - ixx) = 2) or (abs(who.CY - iyy) = 2) )
                              and ( (abs(who.CX - ixx) mod 2 = 0) and (abs(who.CY - iyy) mod 2 = 0) ) then begin
                           //맵퀘스트를 위해 PEnvir 대신에 who.PEnvir를 사용한다.
                           if who.PEnvir.CanWalk(ixx, iyy, FALSE) then begin
                              UserEngine.AddCreatureSysop (UpperCase(sparam1),  //map
                                                           ixx,
                                                           iyy,
                                                           pqa.ActParam); //mon-name
                           end;
                        end;
                     end;
                  end;
               end;
            QA_RECALLMOB:
               begin
                  TUserHuman(who).CmdCallMakeSlaveMonster(pqa.ActParam{몹이름}, pqa.ActTag{마리수}, 3, 0);
               end;

            QA_SETLOVERFLAG:
               begin
                  if TUserHuman(who).fLover <> nil then begin
                     hum := UserEngine.GetUserHuman(TUserHuman(who).fLover.GetLoverName);
                     if hum <> nil then begin
                        param := Str_ToInt (pqa.ActParam, 0);
                        //if param > 100 then begin
                        tag := Str_ToInt (pqa.ActTag, 0);
                        hum.SetQuestMark (param, tag);
                        //end;
                     end;
                  end;
               end;
            QA_GUILDSECESSION:
               begin
                  if who.RaceServer = RC_USERHUMAN then
                     TUserHuman(who).GuildSecession;
               end;
            QA_GIVETOLOVER:
               begin
                  if TUserHuman(who).fLover <> nil then begin
                     hum := UserEngine.GetUserHuman(TUserHuman(who).fLover.GetLoverName);
                     if hum <> nil then begin
                        if (Abs(hum.CX-who.CX) <= 7) and (Abs(hum.CY-who.CY) <= 7) then begin
                           GiveItemToUser (hum, pqa.ActParam, pqa.ActTagVal);
                        end else begin
                           {$IFDEF KOREA} who.SysMsg('연인이 주변에 없습니다.', 0);
                           {$ELSE}        who.SysMsg('Your lover is not around here.', 0);
                           {$ENDIF}
                        end;
                     end else begin
                        {$IFDEF KOREA} who.SysMsg('연인을 찾을 수 없습니다.', 0);
                        {$ELSE}        who.SysMsg('Cannot found your lover.', 0);
                        {$ENDIF}
                     end;
                  end;
               end;
            QA_INCMEMORIALCOUNT:
               begin
                  MemorialCount := MemorialCount + pqa.ActParamVal;
               end;
            QA_DECMEMORIALCOUNT:
               begin
                  MemorialCount := MemorialCount - pqa.ActParamVal;
               end;
            QA_SAVEMEMORIALCOUNT:
               begin
                  WriteMemorialCount;
               end;
            //2005/12/14
            QA_INSTANTPOWERUP:
               begin
                  if (UPPERCASE(pqa.ActParam) = 'DC') then begin
                     kind := EABIL_DCUP;
                  end else if (UPPERCASE(pqa.ActParam) = 'MC') then begin
                     kind := EABIL_MCUP;
                  end else if (UPPERCASE(pqa.ActParam) = 'SC') then begin
                     kind := EABIL_SCUP;
                  end else if (UPPERCASE(pqa.ActParam) = 'HITSPEED') then begin
                     kind := EABIL_HITSPEEDUP;
                  end else if (UPPERCASE(pqa.ActParam) = 'HP') then begin
                     kind := EABIL_HPUP;
                  end else if (UPPERCASE(pqa.ActParam) = 'MP') then begin
                     kind := EABIL_MPUP;
                  end else begin
                     kind := -1;
                  end;
                  who.EnhanceExtraAbility( kind, pqa.ActTagVal, pqa.ActExtraVal div 60, pqa.ActExtraVal mod 60 );
                  who.RecalcAbilitys;
                  who.SendMsg (who, RM_ABILITY, 0, 0, 0, 0, '');
               end;
            QA_INSTANTEXPDOUBLE:
               begin
                  who.InstantExpDoubleTime := GetTickCount + LongWord(pqa.ActParamVal * 1000);
               end;
            QA_HEALING:
               begin
                  who.SendRefMsg (RM_NORMALEFFECT, 0, who.CX, who.CY, NE_USERHEALING, '');
                  who.IncHealing := who.IncHealing + pqa.ActParamVal;
                  who.PerHealing := 5;
               end;
            QA_UNIFYITEM:
               begin
                  if who.RaceServer = RC_USERHUMAN then
                     TUserHuman(who).UserUnifyItem( Integer(self), pqa.ActParam );
               end;

         end;
      end;
   end;
   procedure NpcSayProc (str: string; fast: Boolean);
   var
      k: integer;
      tag, rst: string;
   begin
      rst := str;
      for k:=0 to 100 do begin
         if CharCount(rst, '>') >= 1 then begin
            rst := ArrestStringEx (rst, '<', '>', tag);
            CheckNpcSayCommand (TUserHuman(who), str, tag);
         end else
            break;
      end;
      if fast then
         who.SendFastMsg (self, RM_MERCHANTSAY, 0, 0, 0, 0, UserName + '/' + str)
      else
         who.SendMsg (self, RM_MERCHANTSAY, 0, 0, 0, 0, UserName + '/' + str);
   end;
var
   i, j, m: integer;
   str, tag: string;
   pquest, pqr: PTQuestRecord;
   psay: PTSayingRecord;
   psayproc: PTSayingProcedure;
begin
   pquest := nil;
   psayproc := nil;
   batchlist := TStringList.Create;
   batchdelay := 1000;
   previousbatchdelay := 0;

   if TUserHuman(who).CurQuestNpc <> self then begin
      TUserHuman(who).CurQuestNpc := nil;
      TUserHuman(who).CurQuest := nil;
      FillChar (TUserHuman(who).QuestParams, sizeof(integer)*10, #0);
   end;

   if CompareText (title, '@main') = 0 then begin
      for i:=0 to Sayings.Count-1 do begin
         pqr := PTQuestRecord (Sayings[i]);
         for j:=0 to pqr.SayingList.Count-1 do begin
            psay := pqr.SayingList[j];
            if CompareText (psay.Title, title) = 0 then begin
               pquest := pqr;
               TUserHuman(who).CurQuest := pquest;
               TUserHuman(who).CurQuestNpc := self;
               break;
            end;
         end;
         if pquest <> nil then break;
      end;
   end;
   if pquest = nil then begin
      if TUserHuman(who).CurQuest <> nil then begin
         for i:=Sayings.Count-1 downto 0 do begin
            if TUserHuman(who).CurQuest = PTQuestRecord (Sayings[i]) then begin
               pquest := PTQuestRecord (Sayings[i]);
            end;
         end;
      end;
      if pquest = nil then begin
         for i:=Sayings.Count-1 downto 0 do begin
            //퀘스트의 조건을 검사 한다.
            if CheckQuestCondition (PTQuestRecord (Sayings[i])) then begin
               pquest := PTQuestRecord (Sayings[i]);
               TUserHuman(who).CurQuest := pquest;
               TUserHuman(who).CurQuestNpc := self;
            end;
         end;
      end;
   end;
   if pquest <> nil then begin
      for j:=0 to pquest.SayingList.Count-1 do begin
         psay := PTSayingRecord (pquest.SayingList[j]);
         if CompareText (psay.Title, title) = 0 then begin
            str := '';
            for m:=0 to psay.Procs.Count-1 do begin
               psayproc := PTSayingProcedure(psay.Procs[m]);
               if psayproc = nil then continue; // 2003-09-08 nil 검사
               bosaynow := FALSE;
               if CheckSayingCondition (psayproc.ConditionList) then begin
                  //조건 참인 경우, 대화
                  str := str + psayproc.Saying;
                  //조건 참인 경우, 액션
                  if not DoActionList (psayproc.ActionList) then
                     break;
                  if bosaynow then begin
                     NpcSayProc (str, TRUE);
                     TUserHuman(who).CurSayProc := psayproc;
                  end;
               end else begin
                  //조건 거짓인 경우, 대화
                  str := str + psayproc.ElseSaying;
                  //조건 거짓인 경우, 액션
                  if not DoActionList (psayproc.ElseActionList) then
                     break;
                  if bosaynow then begin
                     NpcSayProc (str, TRUE);
                     TUserHuman(who).CurSayProc := psayproc;
                  end;
               end;
            end;

            if str <> '' then begin
               NpcSayProc (str, FALSE);
               TUserHuman(who).CurSayProc := psayproc;
            end;
            break;
         end;
      end;
   end;

   batchlist.Free;

end;

procedure TNormNpc.ClearNpcInfos;
var
   i, j, k, m: integer;
   pqr: PTQuestRecord;
   psay: PTSayingRecord;
   psayproc: PTSayingProcedure;
   pqcon: PTQuestConditionInfo;
   pqact: PTQuestActionInfo;
begin
   for i:=0 to Sayings.Count-1 do begin
      pqr := PTQuestRecord (Sayings[i]);
      for j:=0 to pqr.SayingList.Count-1 do begin
         psay := pqr.SayingList[j];
         for k:=0 to psay.Procs.Count-1 do begin
            psayproc := PTSayingProcedure(psay.Procs[k]);
            for m:=0 to psayproc.ConditionList.Count-1 do
               Dispose (PTQuestConditionInfo (psayproc.ConditionList[m]));
            for m:=0 to psayproc.ActionList.Count-1 do
               Dispose (PTQuestActionInfo (psayproc.ActionList[m]));
            for m:=0 to psayproc.ElseActionList.Count-1 do
               Dispose (PTQuestActionInfo (psayproc.ElseActionList[m]));
            psayproc.ConditionList.Free;
            psayproc.ActionList.Free;
            psayproc.ElseActionList.Free;
            Dispose (psayproc);
         end;
         psay.Procs.Free;
         Dispose (psay);
      end;
      pqr.SayingList.Free;
      Dispose (pqr);
   end;
   Sayings.Clear;
end;

procedure TNormNpc.LoadNpcInfos;
begin
   if BoUseMapFileName then begin
      NpcBaseDir := NPCDEFDIR;
      FrmDB.LoadNpcDef (self, DefineDirectory, UserName + '-' + MapName)
   end else begin
      NpcBaseDir := DefineDirectory;
      FrmDB.LoadNpcDef (self, DefineDirectory, UserName);
   end;
   //ArrangeSayStrings;
end;

procedure TNormNpc.LoadMemorialCount;
begin
   FrmDB.LoadMemorialCount (self, UserName + '-' + MapName);
end;

procedure TNormNpc.WriteMemorialCount;
begin
   FrmDB.WriteMemorialCount (self, UserName + '-' + MapName);
end;

procedure TNormNpc.UserCall (caller: TCreature);
begin
end;
procedure TNormNpc.UserSelect (whocret: TCreature; selstr: string);
begin
end;

{-------------------- TMerchant ----------------------}

constructor TMerchant.Create;
begin
   inherited Create;
   RaceImage := RCC_MERCHANT;  //상인
   Appearance := 0;
   PriceRate := 100;
   NoSeal := FALSE;
   BoCastleManage := FALSE;
   BoHiddenNpc := FALSE;

   DealGoods := TStringList.Create;
   ProductList := TList.Create;
   GoodsList := TList.Create;
   PriceList := TList.Create;

   UpgradingList := TList.Create;

   checkrefilltime := GetTickCount;
   checkverifytime := GetTickCount;

   fSaveToFileCount := 0;
   //specialrepairtime := 0;
   //specialrepair := 0;
   CreateIndex := 0;
end;

destructor TMerchant.Destroy;
var
   i, k: integer;
   list: TList;
begin
   for i:=0 to ProductList.Count-1 do
      Dispose (PTMarketProduct (ProductList[i]));
   ProductList.Free;
   for i:=0 to GoodsList.Count-1 do begin
      list := TList (GoodsList[i]);
      for k:=0 to list.Count-1 do begin
         Dispose (PTUserItem (list[k]));
      end;
      list.Free;
   end;
   GoodsList.Free;
   for i:=0 to PriceList.Count-1 do begin
      Dispose (PTPricesInfo (PriceList[i]));
   end;
   PriceList.Free;
   for i:=0 to UpgradingList.Count-1 do
      Dispose (PTUpgradeInfo (UpgradingList[i]));
   UpgradingList.Free;
   inherited Destroy;
end;

procedure TMerchant.ClearMerchantInfos;
var
   i: integer;
begin
   for i:=0 to ProductList.Count-1 do
      Dispose (PTMarketProduct (ProductList[i]));
   ProductList.Clear;
   DealGoods.Clear;

   {inherited} ClearNpcInfos;  //공통으로 사용
end;

procedure TMerchant.LoadMerchantInfos;
var
   i: integer;
begin
   NpcBaseDir := MARKETDEFDIR;
   FrmDB.LoadMarketDef (self, MARKETDEFDIR, MarketName + '-' + MapName, TRUE);
   //ArrangeSayStrings;
   /////////////*****************
   //for i:=0 to SayStrings.Count-1 do begin
   //   if CompareText(SayStrings[i], '@makedrug') = 0 then begin
   //      NoSeal := TRUE;  //물건을 만드는 곳에서는 판매는 안함.
   //      break;
   //   end;
   //end;
end;

procedure TMerchant.LoadMarketSavedGoods;
begin
   FrmDB.LoadMarketSavedGoods (self, MarketName + '-' + MapName);
   FrmDB.LoadMarketPrices (self, MarketName + '-' + MapName);
   LoadUpgradeItemList;
end;

function  TMerchant.GetGoodsList (gindex: integer): TList;
var
   i: integer;
   l: TList;
   pstd: PTStdItem;
begin
   Result := nil;
   if gindex > 0 then
      try
      for i:=0 to GoodsList.Count-1 do begin
         l := TList(GoodsList[i]);
         if l.Count > 0 then
            if PTUserItem (l[0]).Index = gindex then begin
               Result := l;
               break;
            end;
      end;
      except
      end;
end;

procedure TMerchant.PriceUp (index: integer);
var
   i, price: integer;
   pstd: PTStdItem;
begin
   for i:=0 to PriceList.Count-1 do begin
      if PTPricesInfo(PriceList[i]).Index = index then begin
         price := PTPricesInfo(PriceList[i]).SellPrice;
         if price < Round(price * 1.1) then price := Round(price * 1.1)
         else price := price + 1;
         exit;
      end;
   end;
   pstd := UserEngine.GetStdItem (index);
   if pstd <> nil then
      NewPrice (index, Round (pstd.Price * 1.1));
end;

procedure TMerchant.PriceDown (index: integer);
var
   i, price: integer;
   pstd: PTStdItem;
begin
   for i:=0 to PriceList.Count-1 do begin
      if PTPricesInfo(PriceList[i]).Index = index then begin
         price := PTPricesInfo(PriceList[i]).SellPrice;
         if price > Round(price / 1.1) then price := Round(price / 1.1)
         else price := price - 1;
         price := _MAX(2, price); //가격은 2보다 작을 수 없다. //_MIN->_MAX로 수정(sonmg)
         exit;
      end;
   end;
   pstd := UserEngine.GetStdItem (index);
   if pstd <> nil then
      NewPrice (index, Round (pstd.Price * 1.1));
end;

procedure TMerchant.NewPrice (index, price: integer);
var
   pi: PTPricesInfo;
begin
   new (pi);
   pi.Index := index;
   pi.SellPrice := price;
   PriceList.Add (pi);
   FrmDB.WriteMarketPrices (self, MarketName + '-' + MapName);
end;

//물건의 대표 가격
function  TMerchant.GetPrice (index: integer): integer; //-1: not found
var
   i, price: integer;
   pstd: PTStdItem;
begin
   price := -2;
   for i:=0 to PriceList.Count-1 do begin
      if PTPricesInfo(PriceList[i]).Index = index then begin
         price := PTPricesInfo(PriceList[i]).SellPrice;
         break;
      end;
   end;
   if price < 0 then begin
      pstd := UserEngine.GetStdItem (index);
      if (pstd <> nil) and IsDealingItem (pstd.StdMode, pstd.Shape ) then begin
         price := pstd.Price;
      end;
   end;
   Result := price;
end;

//물건의 개별 가격
function  TMerchant.GetGoodsPrice (uitem: TUserItem): integer;
var
   i, price, upg: integer;
   dam: Real;
   pstd: PTStdItem;
begin
   price := GetPrice (uitem.Index);
   if price > 0 then begin
      pstd := UserEngine.GetStdItem (uitem.Index);
      if pstd <> nil then
         if (pstd.OverlapItem < 1) and (pstd.StdMode > 4) and (pstd.DuraMax > 0) and
            (uitem.DuraMax > 0) and (pstd.StdMode <> 8) then begin   //초대장 제외
            //고기류
            if pstd.StdMode = 40 then begin
               if (uitem.Dura <= uitem.DuraMax) then begin //일반 고기
                  dam := (price / 2 / uitem.DuraMax) * (uitem.DuraMax - uitem.Dura);
                  price := _MAX(2, Round(price - dam));
               end else begin //고품질 좋은 고기
                  price := price + Round((uitem.Dura-uitem.DuraMax) * (price/uitem.DuraMax*2)); //가격이 많이 올라감
               end;
            end;
            //광석류
            if pstd.StdMode = 43 then begin
               if uitem.DuraMax < 10000 then uitem.DuraMax := 10000;
               if uitem.Dura <= uitem.DuraMax then begin //일반 고기
                  dam := (price / 2 / uitem.DuraMax) * (uitem.DuraMax - uitem.Dura);
                  price := _MAX(2, Round(price - dam));
               end else begin //고품질 좋은 고기
                  price := price + Round((uitem.Dura-uitem.DuraMax) * (price/uitem.DuraMax*1.3)); //가격이 많이 올라감
               end;
            end;
            if (pstd.OverlapItem < 1) and (pstd.StdMode > 4) then begin //시약,스크롤,음식 제외
               //업그레이드 된 능력
               // 가격이 상승....
               upg := 0;
               for i:=0 to 7 do begin  //능력치 상승은 0..7
                  if (pstd.StdMode = 5) or (pstd.StdMode = 6) then begin //무기류
                     if (i = 4) or (i = 9) then continue; //저주, 업그레이드 실패는 제외
                     if i = 6 then begin
                        if uitem.Desc[i] > 10 then //공격 속도 (+)
                           upg := upg + (uitem.Desc[i] - 10) * 2;
                        continue; //공격속도(-)는 제외
                     end;
                     upg := upg + uitem.Desc[i];
                  end else
                     upg := upg + uitem.Desc[i];
               end;
               if upg > 0 then begin  //업그레이드 된 아이템은 비싸다
                  price := price + (price div 5) * upg;
               end;

               //전체 마모도 검사
               price := Round ((price / pstd.DuraMax) * uitem.DuraMax);
               //현재 마모도 검사
               dam := (price / 2 / uitem.DuraMax) * (uitem.DuraMax - uitem.Dura);
               price := _MAX(2, Round(price - dam));
            end;
         end;
   end;
   Result := price;
end;

//whocret: 물건값을 물어보는이, 사람에 따라서 가격이 틀려질 수 있다.
//price: 원래 가격
function  TMerchant.GetSellPrice (whocret: TUserHuman; price: integer): integer;
var
   prate: integer;
begin
   if BoCastleManage then begin //성안에의 상점, 성을 지배하는 문파원들에게는
                              //싸게 준다.
      if UserCastle.IsOurCastle (TGuild(whocret.MyGuild)) then begin
         prate := _MAX(60, Round (PriceRate * 0.8));
         Result := Round (price / 100 * prate);
      end else
         Result := Round (price / 100 * PriceRate);
   end else
      Result := Round (price / 100 * PriceRate);
end;

function  TMerchant.GetBuyPrice (price: integer): integer;
begin
   Result := Round (price / 2);
end;

function  TMerchant.IsDealingItem (stdmode: integer ; shape :integer ): Boolean;
var
   i: integer;
   _stdmode : integer;
   _shape   : integer;
   str1 , str2 : string;
begin
   Result := FALSE;
   for i:=0 to DealGoods.Count-1 do begin
      str2 := GetValidStr3 ( DealGoods.Strings[i], str1, [',',' ']);
      _stdmode := Str_ToInt( str1 , -1 );
      _shape   := Str_ToInt( str2 , -1 );
      // Test 2003-09-20 PDS
      // MainOutMessage( 'Merchant Dealing Stdmode,Shape:'+IntTostr(_stdmode)+','+IntTostr(_shape));
      if ( _stdmode = stdmode )then
      begin
         if _shape <> -1 then
         begin
            if ( _shape = shape ) then
            begin
                result := TRUE;
                break;
            end;
         end
         else
         begin
           Result := TRUE;
           break;
         end;
      end;
   end;
end;

procedure TMerchant.RefillGoods; //리필 시간 체크해서 부족한 상품을 보충하고 필요하면 가격 조정
   procedure RefillNow (var list: TList; itemname: string; fcount: integer);
   var
      i: integer;
      pu: PTUserItem;
      ps: PTStdItem;
   begin
      if list = nil then begin
         list := TList.Create;
         GoodsList.Add (list);
      end;
      for i:=0 to fcount-1 do begin
         new (pu);
         if UserEngine.CopyToUserItemFromName (itemname, pu^) then begin
            ps := UserEngine.GetStdItem(pu.Index);
            if ps <> nil then
            begin
               // 카운트아이템
               if ps.OverlapItem >= 1 then begin
                  pu.Dura := 1;
               end;

               list.Insert (0, pu); //새거는 처음부터..
            end//if ps <> nil then
            else
                Dispose(pu);
         end else
            Dispose (pu);
      end;
   end;
   procedure WasteNow (var list: TList; wcount: integer);
   var
      i: integer;
   begin
      for i:=list.Count-1 downto 0 do begin
         if wcount <= 0 then break;
         try
         Dispose (PTUserItem (list[i]));
         finally
         list.Delete (i);
         end;
         Dec (wcount);
      end;
   end;
var
   i,j, k, stock, gindex: integer;
   pp: PTMarketProduct;
   list, l: TList;
   flag : Boolean;
   step : integer;
   ItemChanged : Boolean;
begin
   ItemChanged := false;
   i    := 0;
   step := 0;
   try
      step := 0;
      for i:=0 to ProductList.Count-1 do begin
         step := 1;
         pp := ProductList[i];
       if GetTickCount - pp.ZenTime > longword(pp.ZenHour) * 60 * 1000 then begin
         // 2003/03/04 상점 젠 타임 조정 1분 -> 1시간
//         if GetTickCount - pp.ZenTime > longword(pp.ZenHour) * 60 * 60 * 1000 then begin
            step := 3;
            pp.ZenTime := GetTickCount;
            gindex := UserEngine.GetStdItemIndex (pp.GoodsName);  //이름으로 아이템 인덱스를 얻어옴
            if gindex >= 0 then begin
               step := 4;
               list := nil;
               list := GetGoodsList (gindex);
               stock := 0;
               if list <> nil then stock := list.Count;
               if stock < pp.Count then begin //물건이 부족
                  step := 5;
                  PriceUp (gindex);
                  RefillNow (list, pp.GoodsName, pp.Count-stock);  //새로 추가는 앞에서 부터
//MainOutMessage('[[[Refill Goods...]]] NPC:' + UserName + '(' + IntToStr(CreateIndex) + ')'); // Lag Test
                  ItemChanged := true;
                  //저장
                  // FrmDB.WriteMarketSavedGoods (self, MarketName + '-' + MapName);
                  // FrmDB.WriteMarketPrices (self, MarketName + '-' + MapName);
                  step := 6;
               end;
               if stock > pp.Count then begin //물건이 남아 돈다. 버린다.
                  step := 7;
                  /////PriceDown (gindex);
                  WasteNow (list, stock - pp.Count); //뒤에서 부터 버림
//MainOutMessage('[[[Waste Goods...]]] NPC:' + UserName); // Lag Test
                  ItemChanged := true;
                  //저장
                  // FrmDB.WriteMarketSavedGoods (self, MarketName + '-' + MapName);
                  // FrmDB.WriteMarketPrices (self, MarketName + '-' + MapName);
                  step := 8;
               end;
            end;
         end;
      end;

      if ItemChanged then begin
         // 10 번에 한번씩 저장을 하게한다 5분 x 10 = 50 분에 한번씩 저장됨
         if ( fSaveToFileCount >= 10 ) then begin
            FrmDB.WriteMarketSavedGoods (self, MarketName + '-' + MapName);
            FrmDB.WriteMarketPrices (self, MarketName + '-' + MapName);
            fSaveToFileCount := 0;
         end else begin
            inc ( fSaveToFileCount );
         end;
      end;
      //이상점에서 나지는 않지만 사들인 물건중에서 1000개 이상이면 버린다.
      //이 상점에서 나는 것은 5000개 이상 버림
      for j:=0 to GoodsList.Count-1 do begin
         step := 9;
         l := TList(GoodsList[j]);
         step := 10;
         if l.Count > 1000 then begin
            //이 상점에서 나는것은 제거하지 않음.
            flag := FALSE;
            for k:=0 to ProductList.Count-1 do begin
               step := 11;
               pp := ProductList[k];
               gindex := UserEngine.GetStdItemIndex (pp.GoodsName);  //이름으로 아이템 인덱스를 얻어옴
               if PTUserItem (l[0]).Index = gindex then begin
                  step := 12;
                  flag := TRUE; //
                  break;
               end;
            end;
            step := 13;
            if not flag then begin
               WasteNow (l, l.count - 1000); //뒤에서 부터 버림
            end else
               WasteNow (l, l.count - 5000); //뒤에서 부터 버림
         end;
      end;

   except
      MainOutMessage ('Merchant RefillGoods Exception..Step=('+IntToStr(step)+')' );
   end;
end;

procedure TMerchant.CheckNpcSayCommand (hum: TUserHuman; var source: string; tag: string);
begin
   inherited CheckNpcSayCommand (hum, source, tag);
   if tag = '$PRICERATE' then begin
      source := ChangeNpcSayTag (source, '<$PRICERATE>', IntToStr(PriceRate));
   end;
   if tag = '$UPGRADEWEAPONFEE' then begin
      source := ChangeNpcSayTag (source, '<$UPGRADEWEAPONFEE>', IntToStr(UPGRADEWEAPONFEE));
   end;
   if tag = '$USERWEAPON' then begin
      if hum.UseItems[U_WEAPON].Index <> 0 then
         source := ChangeNpcSayTag (source, '<$USERWEAPON>', UserEngine.GetStdItemName(hum.UseItems[U_WEAPON].Index))
      else
         source := ChangeNpcSayTag (source, '<$USERWEAPON>', 'Weapon');
   end;
end;

procedure TMerchant.UserCall (caller: TCreature);
var
   data: string;
   n: integer;
begin
   NpcSayTitle (caller, '@main');
end;

procedure TMerchant.SaveUpgradeItemList;
begin
   try
      FrmDB.WriteMarketUpgradeInfos (UserName, UpgradingList);
   except
      MainOutMessage ('Failure in saving upgradinglist - ' + UserName);
   end;
end;

procedure TMerchant.LoadUpgradeItemList;
var
   i: integer;
begin
   for i:=0 to UpgradingList.Count-1 do
      Dispose (PTUpgradeInfo (UpgradingList[i]));
   UpgradingList.Clear;
   try
      FrmDB.LoadMarketUpgradeInfos (UserName, UpgradingList);
   except
      MainOutMessage ('Failure in loading upgradinglist - ' + UserName);
   end;
end;

//30분에 한 번씩 너무 오래됬는데 안 찾아가는 아이템은 삭제한다
//7일 이상 안 찾아 가는 아이템은 삭제된다.
procedure TMerchant.VerifyUpgradeList;
var
   i, old   : integer;
   pup      : PTUpgradeInfo;
   realdate : Real;
begin
   old := 0;
   for i:=UpgradingList.Count-1 downto 0 do
   begin
      pup := PTUpgradeInfo (UpgradingList[i]);
      // TO PDS: CHeck Null..
      if pup <> Nil then begin

         realdate := real(Date ) - real(pup.readydate);

         try // Round 시에 숫자 컨버팅 에러 발생 PDS
            old := Round(realdate);
         except
            on EInvalidOp do old := 0;
         end;

         if old >= 8 then begin //7+1일 이상 지난 것
            Dispose (pup);
            UpgradingList.Delete (i);
         end;

      end else begin
         MainOutMessage ('pup Is Nil... ');
      end;

   end;
end;

procedure TMerchant.UserSelectUpgradeWeapon (hum: TUserHuman);
   procedure PrepareWeaponUpgrade (ilist: TList; var adc, asc, amc, dura: byte);
   var
      i, k, d, s, m, dctop, dcsec, sctop, scsec, mctop, mcsec, durasum, duracount: integer;
      ps: PTStdItem;
      dellist: TStringList;
      sumlist: TList;
      std: TStdItem;
   begin
      dctop := 0; dcsec := 0;
      sctop := 0; scsec := 0;
      mctop := 0; mcsec := 0;
      durasum := 0;
      duracount := 0;
      dellist := nil;
      sumlist := TList.Create;

      for i := ilist.Count-1 downto 0 do begin
         if UserEngine.GetStdItemName(PTUserItem(ilist[i]).Index) = __BlackStone then begin
            sumlist.Add (pointer(Round(PTUserItem(ilist[i]).dura / 1000)));
            //durasum := durasum +
            //Inc (duracount);

            if dellist = nil then dellist := TStringList.Create;
            dellist.AddObject(__BlackStone, TObject(PTUserItem(ilist[i]).MakeIndex));

            Dispose(PTUserItem(ilist[i]));
            ilist.Delete (i);
         end else begin
            if IsUpgradeWeaponStuff (PTUserItem(ilist[i]).Index) then begin
               ps := UserEngine.GetStdItem (PTUserItem(ilist[i]).Index);
               if ps <> nil then begin
                  std := ps^;
                  ItemMan.GetUpgradeStdItem (PTUserItem(ilist[i])^, std);

                  d := 0;  s := 0;  m := 0;

                  case std.StdMode of
                     19,20,21: begin  //목걸이
                           d := Lobyte(std.DC) + Hibyte(std.DC);
                           s := Lobyte(std.SC) + Hibyte(std.SC);
                           m := Lobyte(std.MC) + Hibyte(std.MC);
                        end;
                     22,23: begin     //반지
                           d := Lobyte(std.DC) + Hibyte(std.DC);
                           s := Lobyte(std.SC) + Hibyte(std.SC);
                           m := Lobyte(std.MC) + Hibyte(std.MC);
                        end;
                     24,26: begin     //팔찌
                           d := Lobyte(std.DC) + Hibyte(std.DC) + 1;
                           s := Lobyte(std.SC) + Hibyte(std.SC) + 1;
                           m := Lobyte(std.MC) + Hibyte(std.MC) + 1;
                        end;
                  end;

                  if dctop < d then begin dcsec := dctop; dctop := d;
                  end else if dcsec < d then dcsec := d;

                  if sctop < s then begin scsec := sctop; sctop := s;
                  end else if scsec < s then scsec := s;

                  if mctop < m then begin mcsec := mctop; mctop := m;
                  end else if mcsec < m then mcsec := m;

                  if dellist = nil then dellist := TStringList.Create;
                  dellist.AddObject(ps.Name, TObject(PTUserItem(ilist[i]).MakeIndex));

                  //로그남김
                  AddUserLog ('26'#9 + //업재_
                              hum.MapName + ''#9 +
                              IntToStr(hum.CX) + ''#9 +
                              IntToStr(hum.CY) + ''#9 +
                              hum.UserName + ''#9 +
                              UserEngine.GetStdItemName (PTUserItem(ilist[i]).Index) + ''#9 +
                              IntToStr(PTUserItem(ilist[i]).MakeIndex) + ''#9 +
                              '1'#9 +
                              ItemOptionToStr(PTUserItem(ilist[i]).desc));
                  Dispose(PTUserItem(ilist[i]));
                  ilist.Delete (i);
               end;
            end;
         end;
      end;
      for i:=0 to sumlist.Count-1 do begin
         for k:=sumlist.Count-1 downto i+1 do begin
            if integer(sumlist[k]) > integer(sumlist[k-1]) then begin
               sumlist.Exchange (k, k-1);
            end;
         end;
      end;
      for i:=0 to sumlist.Count-1 do begin
         durasum := durasum + integer(sumlist[i]);
         inc (duracount);
         if duracount >= 5 then break;
      end;

      //내구 평균, 5개 까지 많이 넣으면 어드벤테지
      dura := Round(_MIN(5,duracount) + (durasum/duracount) / 5 * _MIN(5,duracount));

      adc := dctop + dctop div 5 + dcsec div 3;  //파괴 5이상 가중치
      asc := sctop + sctop div 5 + scsec div 3;
      amc := mctop + mctop div 5 + mcsec div 3;

      if dellist <> nil then begin
         hum.SendMsg (hum, RM_DELITEMS, 0, integer(dellist), 0, 0, '');
         //dellist 는 RM_DELITEMS 에서 FREE 된다.
      end;

      if sumlist <> nil then sumlist.Free;
   end;
var
   i: integer;
   flag: Boolean;
   pup: PTUpgradeInfo;
   pstd: PTStdItem;
begin
   flag := FALSE;
   //들고 있는 무기의 업그레이드를 맡긴다.
   for i:=0 to UpgradingList.Count-1 do begin
      if hum.UserName = PTUpgradeInfo(UpgradingList[i]).UserName then begin
         NpcSayTitle (hum, '~@upgradenow_ing');
         exit;
      end;
   end;

   if hum.UseItems[U_WEAPON].Index <> 0 then begin   //
      //--------------------------------------
      //유니크아이템은 제련 못맡기게...
      pstd := UserEngine.GetStdItem (hum.UseItems[U_WEAPON].Index);
      if pstd <> nil then begin
         // => UNIQUEITEM 필드가 00000001(2진수)를 포함하면 제련불가(업그레이드 포함) 아이템(sonmg 2005/12/09)
         if {pstd.UniqueItem = 1} (pstd.UniqueItem and $01) <> 0 then begin
            {$IFDEF KOREA} hum.BoxMsg('유니크 아이템은 제련을 맡길 수 없습니다.', 0);
            {$ELSE}        hum.BoxMsg('The unique item cannot be refined.', 0);
            {$ENDIF}
            exit;
         end;
      end;
      //--------------------------------------

      if hum.Gold >= UPGRADEWEAPONFEE then begin  //돈이 있는지
         if hum.FindItemName (__BlackStone) <> nil then begin  //흑철을 가지고 있는지
            hum.DecGold (UPGRADEWEAPONFEE);
            if BoCastleManage then  //5%의 세금이 걷힌다.
               UserCastle.PayTax (UPGRADEWEAPONFEE);
            hum.GoldChanged;

            //가방에 있는 아이템을 몽땅 넣는다.
            new (pup);
            pup.UserName := hum.UserName;
            pup.uitem := hum.UseItems[U_WEAPON];

            //로그남김
            AddUserLog ('25'#9 + //업맞_ +
                        hum.MapName + ''#9 +
                        IntToStr(hum.CX) + ''#9 +
                        IntToStr(hum.CY) + ''#9 +
                        hum.UserName + ''#9 +
                        UserEngine.GetStdItemName (hum.UseItems[U_WEAPON].Index) + ''#9 +
                        IntToStr(hum.UseItems[U_WEAPON].MakeIndex) + ''#9 +
                        '1'#9 +
                        ItemOptionToStr(UseItems[U_WEAPON].desc));

            hum.SendDelItem (hum.UseItems[U_WEAPON]); //클라이언트에 없어진거 보냄
            hum.UseItems[U_WEAPON].Index := 0;
            hum.RecalcAbilitys;
            hum.FeatureChanged;
            hum.SendMsg (hum, RM_ABILITY, 0, 0, 0, 0, '');
            //hum.SendMsg (hum, RM_SUBABILITY, 0, 0, 0, 0, '');

            PrepareWeaponUpgrade (hum.ItemList, pup^.updc, pup^.upsc, pup^.upmc, pup^.durapoint);

            pup.readydate := Now;
            pup.readycount := GetTickCount;

            UpgradingList.Add (pup);
            SaveUpgradeItemList;

            flag := TRUE;
         end;
      end;

   end;
   if flag then
      NpcSayTitle (hum, '~@upgradenow_ok')
   else
      NpcSayTitle (hum, '~@upgradenow_fail');
end;

procedure TMerchant.UserSelectGetBackUpgrade (hum: TUserHuman);
var
   i, per, n: integer;
   state, rand: integer;
   pup: PTUpgradeInfo;
   pu: PTUserItem;
begin
   state := 0;
   pup := nil;
   if hum.CanAddItem then begin
      for i:=0 to UpgradingList.Count-1 do begin
         if hum.UserName = PTUpgradeInfo(UpgradingList[i]).UserName then begin
            state := 1;  //맡긴 것이 있음
            if (GetTickCount - PTUpgradeInfo(UpgradingList[i]).readycount > 60 * 60 * 1000) or
               (hum.UserDegree >= UD_ADMIN)
            then begin
               //다 되었으면
               pup := PTUpgradeInfo(UpgradingList[i]);
               UpgradingList.Delete (i);
               SaveUpgradeItemList;
               state := 2;
               break;
            end;
         end;
      end;
      if (pup <> nil) then begin
         //내구 결정
         case pup.durapoint of
            0..8:
               begin
//                  n := _MAX(3000, pup.uitem.DuraMax div 2);
                  if pup.uitem.DuraMax > 3000 then pup.uitem.DuraMax := pup.uitem.DuraMax - 3000
                  else pup.uitem.DuraMax := pup.uitem.DuraMax div 2;
                  if pup.uitem.Dura > pup.uitem.DuraMax then
                     pup.uitem.Dura := pup.uitem.DuraMax;
               end;
            9..15:
               begin
                  if Random(pup.durapoint) < 6 then
                     pup.uitem.DuraMax := _MAX(0, pup.uitem.DuraMax - 1000);  //DURAMAX수정
               end;
            //16..19
            18..255:
               begin
                  case Random(pup.durapoint-18) of
                     1..4:  pup.uitem.DuraMax := pup.uitem.DuraMax + 1000;
                     5..7: pup.uitem.DuraMax := pup.uitem.DuraMax + 2000;
                     8..255: pup.uitem.DuraMax := pup.uitem.DuraMax + 4000;
                  end;
               end;
         end;

         if (pup.updc = pup.upmc) and (pup.upmc = pup.upsc) then begin
            rand := Random(3);
         end else rand := -1;

         //능력치
         if (pup.updc >= pup.upmc) and (pup.updc >= pup.upsc) or (rand = 0) then begin //파괴업
            //무기의 행운도 관련 있음
            per := _MIN(85, 10 + _MIN(11, pup.updc) * 7 +
                            pup.uitem.Desc[3]{행운} - pup.uitem.Desc[4] +
                            hum.BodyLuckLevel);
            if Random(100) < per then begin
               pup.uitem.Desc[10] := 10;
               if (per > 63) and (Random(30) = 0) then pup.uitem.Desc[10] := 11;
               if (per > 79) and (Random(200) = 0) then pup.uitem.Desc[10] := 12;
            end else
               pup.uitem.Desc[10] := 1;
         end;
         if (pup.upmc >= pup.updc) and (pup.upmc >= pup.upsc) or (rand = 1) then begin //마력업
            //무기의 행운도 관련 있음
            per := _MIN(85, 10 + _MIN(11, pup.upmc) * 7 +
                            pup.uitem.Desc[3] - pup.uitem.Desc[4] +
                            hum.BodyLuckLevel);
            if Random(100) < per then begin
               pup.uitem.Desc[10] := 20;
               if (per > 63) and (Random(30) = 0) then pup.uitem.Desc[10] := 21;
               if (per > 79) and (Random(200) = 0) then pup.uitem.Desc[10] := 22;
            end else
               pup.uitem.Desc[10] := 1;
         end;
         if (pup.upsc >= pup.upmc) and (pup.upsc >= pup.updc) or (rand = 2) then begin //도력업
            //무기의 행운도 관련 있음
            per := _MIN(85, 10 + _MIN(11, pup.upsc) * 7 +
                            pup.uitem.Desc[3] - pup.uitem.Desc[4] +
                            hum.BodyLuckLevel);
            if Random(100) < per then begin
               pup.uitem.Desc[10] := 30;
               if (per > 63) and (Random(30) = 0) then pup.uitem.Desc[10] := 31;
               if (per > 79) and (Random(200) = 0) then pup.uitem.Desc[10] := 32;
            end else
               pup.uitem.Desc[10] := 1;
         end;

         new (pu);
         pu^ := pup.uitem;
         Dispose (pup);

         //로그남김
         AddUserLog ('24'#9 + //업찾_ +
                     hum.MapName + ''#9 +
                     IntToStr(hum.CX) + ''#9 +
                     IntToStr(hum.CY) + ''#9 +
                     hum.UserName + ''#9 +
                     UserEngine.GetStdItemName (pu.Index) + ''#9 +
                     IntToStr(pu.MakeIndex) + ''#9 +
                     '1'#9 +
                     ItemOptionToStr(pu.desc));

         hum.AddItem (pu);
         hum.SendAddItem (pu^);

      end;

      case state of
         2: NpcSayTitle (hum, '~@getbackupgnow_ok');  //완성
         1: NpcSayTitle (hum, '~@getbackupgnow_ing');  //작업중
         0: NpcSayTitle (hum, '~@getbackupgnow_fail');
      end;
   end else begin
      {$IFDEF KOREA} hum.SysMsg ('더 이상 들 수 없습니다.', 0);
      {$ELSE}        hum.SysMsg ('You cannot carry any more.', 0);
      {$ENDIF}
      NpcSayTitle (hum, '@exit');
   end;
end;

///////////////////////////////////////////////////////////////
// UserSelect 별도 분리.
procedure TMerchant.SendGoodsEntry (who: TCreature; ltop: integer);  //
var
   i, count: integer;
   cg: TClientGoods;
   l: TList;
   pstd: PTStdItem;
   pu: PTUserItem;
   data: string;
begin
   data := '';
   count := 0;
   for i:=ltop to GoodsList.Count-1 do begin
      l := GoodsList[i];
      pu := PTUserItem (l[0]);
      pstd := UserEngine.GetStdItem (pu.Index);
      if pstd <> nil then begin
         cg.Name := pstd.Name;
         cg.Price := GetSellPrice (TUserHuman(who), GetPrice (pu.Index));//대표 가격, 물가를 적용함.
         cg.Stock := l.Count;
         if (pstd.StdMode <= 4) or (pstd.StdMode = 42) or (pstd.StdMode = 31) then cg.SubMenu := 0 //시약,음식,도구류, 약재, 묶음약..
         else cg.SubMenu := 1;

         // 카운트 아이템
         if pstd.OverlapItem >= 1 then
            cg.SubMenu := 2;

         data := data + cg.Name + '/' + IntToStr(cg.SubMenu) + '/' + IntToStr(cg.Price) + '/' + IntToStr(cg.Stock) + '/';
         Inc (count);
      end;
   end;
   who.SendMsg (self, RM_SENDGOODSLIST, 0, integer(self), count, 0, data);
end;
procedure TMerchant.SendSellGoods (who: TCreature); //팔기 메뉴준다.
begin
   who.SendMsg (self, RM_SENDUSERSELL, 0, integer(self), 0, 0, '');
end;
procedure TMerchant.SendRepairGoods (who: TCreature); //수리하기 메뉴
begin
   who.SendMsg (self, RM_SENDUSERREPAIR, 0, integer(self), 0, 0, '');
end;
procedure TMerchant.SendSpecialRepairGoods (who: TCreature); //특수수리하기 메뉴
var
   str: string;
begin
   //if specialrepair > 0 then begin
      {$IFDEF KOREA}
      str := '당신은 참 운이 좋군 그래. 재료가 마침 있다네..\' +
                      '대신, 가격은 3배 비싸다는 것을 명심하게나.\ \' +
                      ' <뒤로/@main>';
      {$ELSE}
      str :=  'Hey guy !  You are very lucky... \We have material to do special repairs,\' +
                      'Instead, please keep in mind that the price \would be 3 times higher than normal price.\ \' +
                      ' <back/@main>';
      {$ENDIF}
//      str := ReplaceChar (str, '\', char($a));
//      NpcSay (who, str);
      NpcSayTitle (who, '@ready_s_repair');
      who.SendMsg (self, RM_SENDUSERSPECIALREPAIR, 0, integer(self), 0, 0, '');
   //end else begin
   //   {$IFDEF KOREA}
   //      NpcSay (who, '쯧쯧... 재료가 다 떨어져서 특수수리는\' +
   //             '힘들겠는걸, 잠시만 기다려야 재료를 구할 수\' +
   //             '있네.. 아쉽지만 기다려주게...\ \ <뒤로/@main>');
   //   {$ELSE}
   //      NpcSay (who, 'Sorry, but we ran out of material for special repairs\' +
   //             'Sorry but we have no materials for repairs, Please wait for a moment\' +
   //             ' \ <back/@main>');
   //   {$ENDIF}
   //   whocret.LatestNpcCmd := '@repair';
   //end;
end;
procedure TMerchant.SendStorageItemMenu (who: TCreature);
begin
   who.SendMsg (self, RM_SENDUSERSTORAGEITEM, 0, integer(self), 0, 0, '');
end;
procedure TMerchant.SendStorageItemList (who: TCreature);
begin
   who.SendMsg (self, RM_SENDUSERSTORAGEITEMLIST, 0, integer(self), 0, 0, '');
end;
procedure TMerchant.SendMakeDrugItemList (who: TCreature);
const
   MAKEPRICE = 100;
var
   i, j: integer;
   data: string;
   cg: TClientGoods;
   pu: PTUserItem;
   pstd: PTStdItem;
   L: TList;
   sMakeItemName, sMakePrice: string;
begin
   data := '';
   for i:=0 to GoodsList.Count-1 do begin
      L := GoodsList[i];
      pu := PTUserItem (L[0]);
      pstd := UserEngine.GetStdItem (pu.Index);
      if pstd <> nil then begin
         cg.Name := pstd.Name;
         cg.Price := MAKEPRICE;  //GetSellPrice (GetPrice (pu.Index));//약만드는 비용
         for j:=0 to MakeItemList.Count-1 do begin
            sMakePrice := GetValidStr3(MakeItemList[j], sMakeItemName, [':']);
            if cg.Name = sMakeItemName then begin
               cg.Price := Str_ToInt(sMakePrice, 0);
               break;
            end;
         end;
         cg.Stock := 1;    //l.Count;
         cg.SubMenu := 0; //시약,음식,도구류...

         data := data + cg.Name + '/' + IntToStr(cg.SubMenu) + '/' + IntToStr(cg.Price) + '/' + IntToStr(cg.Stock) + '/';
      end;
   end;
   if data <> '' then
      who.SendMsg (self, RM_SENDUSERMAKEDRUGITEMLIST, 0, integer(self), 0, 0, data);
end;
///////////////////////////////////////////////////////
procedure TMerchant.SendMakeFoodList (who: TCreature);
const
   MAKEPRICE = 100;
var
   i, j: integer;
   data: string;
   cg: TClientGoods;
   pu: PTUserItem;
   pstd: PTStdItem;
   L: TList;
   sMakeItemName, sMakePrice: string;
begin
   data := '';
   for i := 0 to GoodsList.Count-1 do begin
//      if i >= 12 then // MAKE FOOD
//         break;
      if i >= Str_ToInt(MakeItemIndexList[1], 0) - Str_ToInt(MakeItemIndexList[0], 0) then // MAKE FOOD
         break;

      L := GoodsList[i];
      pu := PTUserItem (L[0]);
      pstd := UserEngine.GetStdItem (pu.Index);
      if pstd <> nil then begin
         cg.Name := pstd.Name;
         cg.Price := MAKEPRICE;  //GetSellPrice (GetPrice (pu.Index));//약만드는 비용
         for j:=0 to MakeItemList.Count-1 do begin
            sMakePrice := GetValidStr3(MakeItemList[j], sMakeItemName, [':']);
            if cg.Name = sMakeItemName then begin
               cg.Price := Str_ToInt(sMakePrice, 0);
               break;
            end;
         end;
         cg.Stock := 1;    //l.Count;
         cg.SubMenu := 0; //시약,음식,도구류...

         data := data + cg.Name + '/' + IntToStr(cg.SubMenu) + '/' + IntToStr(cg.Price) + '/' + IntToStr(cg.Stock) + '/';
      end;
   end;
   if data <> '' then
      who.SendMsg (self, RM_SENDUSERMAKEITEMLIST, 0, integer(self), 1{모드}, 0, data);
end;
///////////////////////////////////////////////////////
procedure TMerchant.SendMakePotionList (who: TCreature);
const
   MAKEPRICE = 100;
var
   i, j: integer;
   data: string;
   cg: TClientGoods;
   pu: PTUserItem;
   pstd: PTStdItem;
   L: TList;
   sMakeItemName, sMakePrice: string;
begin
   data := '';
   for i := Str_ToInt(MakeItemIndexList[1], 0) - Str_ToInt(MakeItemIndexList[0], 0) to GoodsList.Count-1 do begin
//      if i >= 16 then // MAKE POTION
//         break;
      if i >= Str_ToInt(MakeItemIndexList[2], 0) - Str_ToInt(MakeItemIndexList[0], 0) then // MAKE FOOD
         break;

      L := GoodsList[i];
      pu := PTUserItem (L[0]);
      pstd := UserEngine.GetStdItem (pu.Index);
      if pstd <> nil then begin
         cg.Name := pstd.Name;
         cg.Price := MAKEPRICE;  //GetSellPrice (GetPrice (pu.Index));//약만드는 비용
         for j:=0 to MakeItemList.Count-1 do begin
            sMakePrice := GetValidStr3(MakeItemList[j], sMakeItemName, [':']);
            if cg.Name = sMakeItemName then begin
               cg.Price := Str_ToInt(sMakePrice, 0);
               break;
            end;
         end;
         cg.Stock := 1;    //l.Count;
         cg.SubMenu := 0; //시약,음식,도구류...

         data := data + cg.Name + '/' + IntToStr(cg.SubMenu) + '/' + IntToStr(cg.Price) + '/' + IntToStr(cg.Stock) + '/';
      end;
   end;
   if data <> '' then
      who.SendMsg (self, RM_SENDUSERMAKEITEMLIST, 0, integer(self), 2{모드}, 0, data);
end;
///////////////////////////////////////////////////////
procedure TMerchant.SendMakeGemList (who: TCreature);
const
   MAKEPRICE = 100;
var
   i, j: integer;
   data: string;
   cg: TClientGoods;
   pu: PTUserItem;
   pstd: PTStdItem;
   L: TList;
   sMakeItemName, sMakePrice: string;
begin
   data := '';
   for i := Str_ToInt(MakeItemIndexList[2], 0) - Str_ToInt(MakeItemIndexList[0], 0) to GoodsList.Count-1 do begin
//      if i >= 29 then // MAKE GEM
//         break;
      if i >= Str_ToInt(MakeItemIndexList[3], 0) - Str_ToInt(MakeItemIndexList[0], 0) then // MAKE FOOD
         break;

      L := GoodsList[i];
      pu := PTUserItem (L[0]);
      pstd := UserEngine.GetStdItem (pu.Index);
      if pstd <> nil then begin
         cg.Name := pstd.Name;
         cg.Price := MAKEPRICE;  //GetSellPrice (GetPrice (pu.Index));//약만드는 비용
         for j:=0 to MakeItemList.Count-1 do begin
            sMakePrice := GetValidStr3(MakeItemList[j], sMakeItemName, [':']);
            if cg.Name = sMakeItemName then begin
               cg.Price := Str_ToInt(sMakePrice, 0);
               break;
            end;
         end;
         cg.Stock := 1;    //l.Count;
         cg.SubMenu := 0; //시약,음식,도구류...

         data := data + cg.Name + '/' + IntToStr(cg.SubMenu) + '/' + IntToStr(cg.Price) + '/' + IntToStr(cg.Stock) + '/';
      end;
   end;
   if data <> '' then
      who.SendMsg (self, RM_SENDUSERMAKEITEMLIST, 0, integer(self), 3{모드}, 0, data);
end;
///////////////////////////////////////////////////////
procedure TMerchant.SendMakeItemList (who: TCreature);
const
   MAKEPRICE = 100;
var
   i, j: integer;
   data: string;
   cg: TClientGoods;
   pu: PTUserItem;
   pstd: PTStdItem;
   L: TList;
   sMakeItemName, sMakePrice: string;
begin
   data := '';
   for i := Str_ToInt(MakeItemIndexList[3], 0) - Str_ToInt(MakeItemIndexList[0], 0) to GoodsList.Count-1 do begin
//      if i >= 66 then // MAKE ITEM
//         break;
      if i >= Str_ToInt(MakeItemIndexList[4], 0) - Str_ToInt(MakeItemIndexList[0], 0) then // MAKE FOOD
         break;

      L := GoodsList[i];
      pu := PTUserItem (L[0]);
      pstd := UserEngine.GetStdItem (pu.Index);
      if pstd <> nil then begin
         cg.Name := pstd.Name;
         cg.Price := MAKEPRICE;  //GetSellPrice (GetPrice (pu.Index));//약만드는 비용
         for j:=0 to MakeItemList.Count-1 do begin
            sMakePrice := GetValidStr3(MakeItemList[j], sMakeItemName, [':']);
            if cg.Name = sMakeItemName then begin
               cg.Price := Str_ToInt(sMakePrice, 0);
               break;
            end;
         end;
         cg.Stock := 1;    //l.Count;
         cg.SubMenu := 0; //시약,음식,도구류...

         data := data + cg.Name + '/' + IntToStr(cg.SubMenu) + '/' + IntToStr(cg.Price) + '/' + IntToStr(cg.Stock) + '/';
      end;
   end;
   if data <> '' then
      who.SendMsg (self, RM_SENDUSERMAKEITEMLIST, 0, integer(self), 4{모드}, 0, data);
end;
///////////////////////////////////////////////////////
procedure TMerchant.SendMakeStuffList (who: TCreature);
const
   MAKEPRICE = 100;
var
   i, j: integer;
   data: string;
   cg: TClientGoods;
   pu: PTUserItem;
   pstd: PTStdItem;
   L: TList;
   sMakeItemName, sMakePrice: string;
begin
   data := '';
   for i := Str_ToInt(MakeItemIndexList[4], 0) - Str_ToInt(MakeItemIndexList[0], 0) to GoodsList.Count-1 do begin
      if i >= Str_ToInt(MakeItemIndexList[5], 0) - Str_ToInt(MakeItemIndexList[0], 0) then // MAKE STUFF
         break;

      L := GoodsList[i];
      pu := PTUserItem (L[0]);
      pstd := UserEngine.GetStdItem (pu.Index);
      if pstd <> nil then begin
         cg.Name := pstd.Name;
         cg.Price := MAKEPRICE;  //GetSellPrice (GetPrice (pu.Index));//약만드는 비용
         for j:=0 to MakeItemList.Count-1 do begin
            sMakePrice := GetValidStr3(MakeItemList[j], sMakeItemName, [':']);
            if cg.Name = sMakeItemName then begin
               cg.Price := Str_ToInt(sMakePrice, 0);
               break;
            end;
         end;
         cg.Stock := 1;    //l.Count;
         cg.SubMenu := 0; //시약,음식,도구류...

         data := data + cg.Name + '/' + IntToStr(cg.SubMenu) + '/' + IntToStr(cg.Price) + '/' + IntToStr(cg.Stock) + '/';
      end;
   end;
   if data <> '' then
      who.SendMsg (self, RM_SENDUSERMAKEITEMLIST, 0, integer(self), 5{모드}, 0, data);
end;
///////////////////////////////////////////////////////
procedure TMerchant.SendMakeEtcList (who: TCreature);
const
   MAKEPRICE = 100;
var
   i, j: integer;
   data: string;
   cg: TClientGoods;
   pu: PTUserItem;
   pstd: PTStdItem;
   L: TList;
   sMakeItemName, sMakePrice: string;
begin
   data := '';
   for i := Str_ToInt(MakeItemIndexList[5], 0) - Str_ToInt(MakeItemIndexList[0], 0) to GoodsList.Count-1 do begin
      L := GoodsList[i];
      pu := PTUserItem (L[0]);
      pstd := UserEngine.GetStdItem (pu.Index);
      if pstd <> nil then begin
         cg.Name := pstd.Name;
         cg.Price := MAKEPRICE;  //GetSellPrice (GetPrice (pu.Index));//약만드는 비용
         for j:=0 to MakeItemList.Count-1 do begin
            sMakePrice := GetValidStr3(MakeItemList[j], sMakeItemName, [':']);
            if cg.Name = sMakeItemName then begin
               cg.Price := Str_ToInt(sMakePrice, 0);
               break;
            end;
         end;
         cg.Stock := 1;    //l.Count;
         cg.SubMenu := 0; //시약,음식,도구류...

         data := data + cg.Name + '/' + IntToStr(cg.SubMenu) + '/' + IntToStr(cg.Price) + '/' + IntToStr(cg.Stock) + '/';
      end;
   end;
   if data <> '' then
      who.SendMsg (self, RM_SENDUSERMAKEITEMLIST, 0, integer(self), 6{모드}, 0, data);
end;
///////////////////////////////////////////////////////////////

procedure TMerchant.UserSelect (whocret: TCreature; selstr: string);
var
   sel, body, rmsg: string;
   i: integer;
   goflag: Boolean;
   psayproc: PTSayingProcedure;
begin
   try
      if (BoCastleManage and UserCastle.BoCastleUnderAttack) or
         //사북성안에 있는 상점은 공성전 중에는 물건을 팔지 않는다.
         whocret.Death
      then begin
         ;
      end else begin
         body := GetValidStr3 (selstr, sel, [#13]);

         if (sel <> '') then begin

            goflag := TRUE;
{
            goflag := FALSE;
            if (CompareText(sel, '@main') <> 0) then begin
               if TUserHuman(whocret).CurSayProc <> nil then begin
                  psayproc := PTSayingProcedure(TUserHuman(whocret).CurSayProc);
                  for i:=0 to psayproc.AvailableCommands.Count-1 do begin
                     if CompareText(sel, psayproc.AvailableCommands[i]) = 0 then begin
                        goflag := TRUE;
                        break;
                     end;
                  end;
               end;
            end else
               goflag := TRUE;
}

            if (sel[1] = '@') then begin
//          if goflag and (sel[1] = '@') then begin
               rmsg := '';
               while TRUE do begin
                  whocret.LatestNpcCmd := sel;

                  //---------------------------------------
                  //따로 말하는 것이 프로그램되어 있음
                  if CanSpecialRepair then
                     if CompareText(sel, '@s_repair') = 0 then begin
                        SendSpecialRepairGoods (whocret);
                        break;
                     end;
                  if CanTotalRepair then
                     if CompareText(sel, '@t_repair') = 0 then begin
                        SendSpecialRepairGoods (whocret);
                        break;
                     end;
                  //---------------------------------------

                  //상인말하는 정보 읽어서 말함.
                  NpcSayTitle (whocret, sel);

                  if CanBuy then
                     if CompareText(sel, '@buy') = 0 then begin
                        //상품 정보를 보낸다.  10개씩 끊어서 보낸다.
                        SendGoodsEntry (whocret, 0);
                        break;
                     end;
                  if CanSell then
                     if CompareText(sel, '@sell') = 0 then begin
                        SendSellGoods (whocret);
                        break;
                     end;
                  if CanRepair then
                     if CompareText(sel, '@repair') = 0 then begin
                        SendRepairGoods (whocret);
                        break;
                     end;
                  if CanMakeDrug then
                     if CompareText(sel, '@makedrug') = 0 then begin
                        SendMakeDrugItemList (whocret);
                        break;
                     end;
                  if CompareText(sel, '@prices') = 0 then begin
                     //시세 보기...
                     break;
                  end;
                  if CanStorage then
                     if CompareText(sel, '@storage') = 0 then begin
                        SendStorageItemMenu (whocret);
                        break;
                     end;
                  if CanGetBack then
                     if CompareText(sel, '@getback') = 0 then begin
                        SendStorageItemList (whocret);
                        break;
                     end;

                     //무기 업그레이드
                  if CanUpgrade then begin
                     if CompareText(sel, '@upgradenow') = 0 then begin
                        UserSelectUpgradeWeapon (TUserHuman(whocret));
                        break;
                     end;
                     if CompareText(sel, '@getbackupgnow') = 0 then begin
                        UserSelectGetBackUpgrade (TUserHuman(whocret));
                        break;
                     end;
                  end;

                  // 아이템 제조
                  if CanMakeItem then begin
                     if CompareText(sel, '@makefood') = 0 then begin
                        SendMakeFoodList (whocret);
//                        rmsg := '~@makefood';
//                        NpcSayTitle (whocret, rmsg);
//                        UserSelectMakeFood (TUserHuman(whocret));
                        break;
                     end;
                     if CompareText(sel, '@makepotion') = 0 then begin
                        SendMakePotionList (whocret);
//                        rmsg := '~@makepotion';
//                        NpcSayTitle (whocret, rmsg);
//                        UserSelectMakePotion (TUserHuman(whocret));
                        break;
                     end;
                     if CompareText(sel, '@makegem') = 0 then begin
                        SendMakeGemList (whocret);
//                        rmsg := '~@makegem';
//                        NpcSayTitle (whocret, rmsg);
//                        UserSelectMakeGem (TUserHuman(whocret));
                        break;
                     end;
                     if CompareText(sel, '@makeitem') = 0 then begin
                        SendMakeItemList (whocret);
//                        rmsg := '~@makeitem';
//                        NpcSayTitle (whocret, rmsg);
//                        UserSelectMakeItem (TUserHuman(whocret));
                        break;
                     end;
                     if CompareText(sel, '@makestuff') = 0 then begin
                        SendMakeStuffList (whocret);
//                        rmsg := '~@makestuff';
//                        NpcSayTitle (whocret, rmsg);
//                        UserSelectMakeStuff (TUserHuman(whocret));
                        break;
                     end;
                     if CompareText(sel, '@makeetc') = 0 then begin
                        SendMakeEtcList (whocret);
//                        rmsg := '~@makeetc';
//                        NpcSayTitle (whocret, rmsg);
//                        UserSelectMakeEtc (TUserHuman(whocret));
                        break;
                     end;
                  end;

                  //위탁판매관련...
                  if CanItemMarket and ( whocret <> nil )and ( whocret.RaceServer = RC_USERHUMAN )then
                  begin
                    if  CompareText( sel, '@market_0') = 0 then
                    begin
                        SendUserMarket( TUserHuman ( whocret ) ,USERMARKET_TYPE_ALL,  USERMARKET_MODE_BUY );
                        break;
                    end;
                    if  CompareText( sel, '@market_1') = 0 then
                    begin
                        SendUserMarket( TUserHuman ( whocret ) ,USERMARKET_TYPE_WEAPON,  USERMARKET_MODE_BUY );
                        break;
                    end;
                    if  CompareText( sel, '@market_2') = 0 then
                    begin
                        SendUserMarket( TUserHuman ( whocret ) ,USERMARKET_TYPE_NECKLACE,  USERMARKET_MODE_BUY );
                        break;
                    end;
                    if  CompareText( sel, '@market_3') = 0 then
                    begin
                        SendUserMarket( TUserHuman ( whocret ) ,USERMARKET_TYPE_RING,  USERMARKET_MODE_BUY );
                        break;
                    end;
                    if  CompareText( sel, '@market_4') = 0 then
                    begin
                        SendUserMarket( TUserHuman ( whocret ) ,USERMARKET_TYPE_BRACELET,  USERMARKET_MODE_BUY );
                        break;
                    end;
                    if  CompareText( sel, '@market_5') = 0 then
                    begin
                        SendUserMarket( TUserHuman ( whocret ) ,USERMARKET_TYPE_CHARM,  USERMARKET_MODE_BUY );
                        break;
                    end;
                    if  CompareText( sel, '@market_6') = 0 then
                    begin
                        SendUserMarket( TUserHuman ( whocret ) ,USERMARKET_TYPE_HELMET,  USERMARKET_MODE_BUY );
                        break;
                    end;
                    if  CompareText( sel, '@market_7') = 0 then
                    begin
                        SendUserMarket( TUserHuman ( whocret ) ,USERMARKET_TYPE_BELT,  USERMARKET_MODE_BUY );
                        break;
                    end;
                    if  CompareText( sel, '@market_8') = 0 then
                    begin
                        SendUserMarket( TUserHuman ( whocret ) ,USERMARKET_TYPE_SHOES,  USERMARKET_MODE_BUY );
                        break;
                    end;

                    if  CompareText( sel, '@market_9') = 0 then
                    begin
                        SendUserMarket( TUserHuman ( whocret ) ,USERMARKET_TYPE_ARMOR,  USERMARKET_MODE_BUY );
                        break;
                    end;
                    if  CompareText( sel, '@market_10') = 0 then
                    begin
                        SendUserMarket( TUserHuman ( whocret ) ,USERMARKET_TYPE_DRINK,  USERMARKET_MODE_BUY );
                        break;
                    end;
                    if  CompareText( sel, '@market_11') = 0 then
                    begin
                        SendUserMarket( TUserHuman ( whocret ) ,USERMARKET_TYPE_JEWEL,  USERMARKET_MODE_BUY );
                        break;
                    end;
                    if  CompareText( sel, '@market_12') = 0 then
                    begin
                        SendUserMarket( TUserHuman ( whocret ) ,USERMARKET_TYPE_BOOK,  USERMARKET_MODE_BUY );
                        break;
                    end;
                    if  CompareText( sel, '@market_13') = 0 then
                    begin
                        SendUserMarket( TUserHuman ( whocret ) ,USERMARKET_TYPE_MINERAL,  USERMARKET_MODE_BUY );
                        break;
                    end;
                    if  CompareText( sel, '@market_14') = 0 then
                    begin
                        SendUserMarket( TUserHuman ( whocret ) ,USERMARKET_TYPE_QUEST,  USERMARKET_MODE_BUY );
                        break;
                    end;
                    if  CompareText( sel, '@market_15') = 0 then
                    begin
                        SendUserMarket( TUserHuman ( whocret ) ,USERMARKET_TYPE_ETC,  USERMARKET_MODE_BUY );
                        break;
                    end;

                    if  CompareText( sel, '@market_100') = 0 then
                    begin
                        SendUserMarket( TUserHuman ( whocret ) ,USERMARKET_TYPE_SET,  USERMARKET_MODE_BUY );
                        break;
                    end;

                    if  CompareText( sel, '@market_200') = 0 then
                    begin
                        SendUserMarket( TUserHuman ( whocret ) ,USERMARKET_TYPE_MINE,  USERMARKET_MODE_INQUIRY );
                        break;
                    end;

                    if  CompareText( sel, '@market_sell') = 0 then
                    begin
                        SendUserMarket( TUserHuman ( whocret ) ,USERMARKET_TYPE_ALL,  USERMARKET_MODE_SELL );
                        break;
                    end;

                  end;

                  // 문파 장원
                  if CanAgitUsage and {(ServerIndex = 0) and} (whocret <> nil) then begin
                     if CompareText( sel, '@agitreg') = 0 then begin
                        TUserHuman(whocret).CmdGuildAgitRegistration;
                     end;
                     if CompareText( sel, '@agitmove') = 0 then begin
                        TUserHuman(whocret).CmdGuildAgitAutoMove;
                     end;
                     if CompareText( sel, '@agitbuy') = 0 then begin
                        TUserHuman(whocret).CmdGuildAgitBuy ( 1 );
                     end;
                     if CompareText( sel, '@agittrade') = 0 then begin
                        TUserHuman(whocret).BoGuildAgitDealTry := TRUE; //장원거래시작
                        TUserHuman(whocret).CmdTryGuildAgitTrade;
                     end;
                  end;
                  // 문파 장원(관리)
                  if CanAgitManage and {(ServerIndex = 0) and} (whocret <> nil) then begin
                     if CompareText( sel, '@agitextend') = 0 then begin
                        TUserHuman(whocret).CmdGuildAgitExtendTime( 1 );
                     end;
                     if CompareText( sel, '@agitremain') = 0 then begin
                        TUserHuman(whocret).CmdGuildAgitRemainTime;
                     end;
                     if CompareText( sel, '@@agitonerecall') = 0 then begin
                        TUserHuman(whocret).CmdGuildAgitRecall (body, FALSE);
                     end;
                     if CompareText( sel, '@agitrecall') = 0 then begin
                        TUserHuman(whocret).CmdGuildAgitRecall ('', TRUE);
                     end;
                     if CompareText( sel, '@@agitforsale') = 0 then begin
                        TUserHuman(whocret).CmdGuildAgitSale ( body );
                     end;
                     if CompareText( sel, '@agitforsalecancel') = 0 then begin
                        TUserHuman(whocret).CmdGuildAgitSaleCancel;
                     end;
                     if CompareText( sel, '@gaboardlist') = 0 then begin
                        TUserHuman(whocret).CmdGaBoardList ( 1 );
                     end;
                     if CompareText( sel, '@@guildagitdonate') = 0 then begin
                        TUserHuman(whocret).CmdGuildAgitDonate (body);
                     end;
                     if CompareText( sel, '@viewdonation') = 0 then begin
                        TUserHuman(whocret).CmdGuildAgitViewDonation;
                     end;
                     if CompareText( sel, '@gaboarddelall') = 0 then begin
                        TUserHuman(whocret).CmdGaBoardDelAll;
                     end;
                  end;
                  // 장원꾸미기
                  if CanBuyDecoItem and (whocret <> nil) then begin
                     if CompareText( sel, '@ga_decoitem_buy') = 0 then begin
                        SendDecoItemListShow(whocret);
                     end;
                     if CompareText( sel, '@ga_decomon_count') = 0 then begin
                        TUserHuman(whocret).CmdAgitDecoMonCountHere;
                     end;
                  end;
                  // 명성치
                  if CanDoingEtc and (whocret <> nil) then begin
                     if CompareText( sel, '@@freepkother') = 0 then begin
                        //PkPoint 해제
                        if TUserHuman(whocret).CmdDeletePKPoint (body) then begin
                           //명성치 모두 감소
                           TUserHuman(whocret).ZeroFamePoint;
                           TUserHuman(whocret).BoxMsg('당신의 명성을 대가로 ' + body + '님의 명예를 회복시켰습니다.', 0);
                        end;
                     end;
                  end;

                  if CompareText(sel, '@exit') = 0 then begin
                     whocret.SendMsg (self, RM_MERCHANTDLGCLOSE, 0, integer(self), 0, 0, '');
                     break;
                  end;
                  break;
               end;
            end;
         end;
      end;
   except
      MainOutMessage ('[Exception] TMerchant.UserSelect... ');
   end;
end;

// 제조 아이템 재료 설명.
procedure TMerchant.SayMakeItemMaterials (whocret: TCreature; selstr: string);
var
   rmsg: string;
begin
   rmsg := '@';

   // selstr is itemname...
   rmsg := rmsg + selstr;

   NpcSayTitle (whocret, rmsg);
end;

procedure TMerchant.QueryPrice (whocret: TCreature; uitem: TUserItem);
var
   i, buyprice: integer;
begin
   buyprice := GetBuyPrice (GetGoodsPrice (uitem));  //구입 가격을 알려줌
   if buyprice >= 0 then begin
      whocret.SendMsg (self, RM_SENDBUYPRICE, 0, buyprice, 0, 0, '');
   end else
      whocret.SendMsg (self, RM_SENDBUYPRICE, 0, 0, 0, 0, '');  //없음..
end;

function  TMerchant.AddGoods (uitem: TUserItem): Boolean;
var
   pu: PTUserItem;
   list: TList;
   pstd: PTStdItem;
begin
   if uitem.DuraMax > 0 then begin //내구성이 0인것은 손실 처리한다. (쓰래기 방지)
      list := GetGoodsList (uitem.Index);
      if list = nil then begin
         list := TList.Create;
         GoodsList.Add (list);
      end;
      new (pu);
      // 2003/06/12 사용자가 팔은 물건의 내구성은 최대내구로 수정하여
      // 싼 가격에 되살수 없도록 수정
      pstd := UserEngine.GetStdItem (uitem.Index);
      if pstd <> nil then begin
         //잡상인의횃불,독가루의 내구를 최대로 수정하지 않는다(sonmg 2004/07/16)
         if(pstd.StdMode = 0) or (pstd.StdMode = 31) or
          ((pstd.StdMode = 3) and ((pstd.Shape = 1) or (pstd.Shape = 2) or (pstd.Shape = 3) or (pstd.Shape = 5) or (pstd.Shape = 9)))
           {or (pstd.StdMode = 25)} or ((pstd.StdMode = 30) and (pstd.Shape = 0)) then begin
            uitem.Dura := uitem.DuraMax;
         end;
      end;
      pu^ := uitem;
      list.Insert (0, pu);
   end;
   Result := TRUE;
end;

function  TMerchant.UserSellItem (whocret: TCreature; uitem: TUserItem): Boolean;
   function CanSell (pu: PTUserItem): Boolean;
   var
      pstd: PTStdItem;
   begin
      Result := TRUE;
      pstd := UserEngine.GetStdItem (pu.Index);
      if pstd <> nil then begin
         if (pstd.UniqueItem and $08) <> 0 then Result := FALSE; //UNIQUEITEM 필드가 00001000(2진수)를 포함하면 교환 및 상점거래 할 수 없는 아이템(sonmg 2005/03/14)
         if (pstd.StdMode = 25) or (pstd.StdMode = 30) then begin
            if pu.Dura < 4000 then
               Result := FALSE;
         end else if (pstd.StdMode = 8) then begin   //초대장은 팔 수 없다.
            Result := FALSE;
         end;
      end;
   end;
var
   i, buyprice: integer;
   pstd : PTStdItem;
begin
   Result := FALSE;
   buyprice := GetBuyPrice (GetGoodsPrice (uitem));  //물건 구입 가격
   if (buyprice >= 0) and (not NoSeal) and CanSell(@uitem) then begin    //사용자가 물건을 팔음. 상품 구입도 안함
      if whocret.IncGold (buyprice) then begin

         //사북성안의 상점인 경우
         if BoCastleManage then  //5%의 세금이 걷힌다.
            UserCastle.PayTax (buyprice);

         whocret.SendMsg (self, RM_USERSELLITEM_OK, 0, whocret.Gold, 0, 0, '');
         //상품에 추가
         AddGoods (uitem);

         //로그남김
         pstd := UserEngine.GetStdItem(uitem.Index);
         if ( pstd <> nil ) and ( not IsCheapStuff (pstd.StdMode) ) then begin
            AddUserLog ('10'#9 + //판매_ +
                        whocret.MapName + ''#9 +
                        IntToStr(whocret.CX) + ''#9 +
                        IntToStr(whocret.CY) + ''#9 +
                        whocret.UserName + ''#9 +
                        UserEngine.GetStdItemName (uitem.Index) + ''#9 +
                        IntToStr(uitem.MakeIndex) + ''#9 +
                        '1'#9 +
                        UserName);
         end;

         Result := TRUE;
      end else //돈이 너무 많음.
         whocret.SendMsg (self, RM_USERSELLITEM_FAIL, 0, 0, 1, 0, '');
   end else //취급 안함
      whocret.SendMsg (self, RM_USERSELLITEM_FAIL, 0, 0, 0, 0, '');
end;

//카운트 아이템
function  TMerchant.UserCountSellItem (whocret: TCreature; uitem: TUserItem; sellcnt: integer): Boolean;
var
   remain: integer;
   i, buyprice: integer;
   pstd: PTStdItem;
begin
   Result := FALSE;
   buyprice := -1;

   pstd := UserEngine.GetStdItem(uitem.Index);
   if pstd <> nil then begin
      if IsDealingItem(pstd.StdMode, pstd.Shape) then
         buyprice := GetBuyPrice(GetGoodsPrice(uitem)) * sellcnt; //물건 구입 가격
   end;

   remain := uitem.Dura - sellcnt;

   if (buyprice >= 0) and (not NoSeal) and (remain >= 0) then begin //사용자가 물건을 팔음. 상품 구입도 안함
      if whocret.IncGold (buyprice) then begin

         //사북성안의 상점인 경우
         if BoCastleManage then  //5%의 세금이 걷힌다.
            UserCastle.PayTax (buyprice);

         whocret.SendMsg (self, RM_USERSELLCOUNTITEM_OK, 0, whocret.Gold, remain, sellcnt, '');

         //상품에 추가
//         AddGoods (uitem);
         //로그남김
         AddUserLog ('10'#9 + //판매_ +
                     whocret.MapName + ''#9 +
                     IntToStr(whocret.CX) + ''#9 +
                     IntToStr(whocret.CY) + ''#9 +
                     whocret.UserName + ''#9 +
                     UserEngine.GetStdItemName (uitem.Index) + ''#9 +
                     IntToStr(uitem.MakeIndex) + ''#9 +
                     '1'#9 +
                     UserName);
         Result := TRUE;
      end else //돈이 너무 많음.
         whocret.SendMsg (self, RM_USERSELLCOUNTITEM_FAIL, 0, 0, 0, 0, '');
   end else //취급 안함
      whocret.SendMsg (self, RM_USERSELLCOUNTITEM_FAIL, 0, 0, 0, 0, '');
end;

procedure TMerchant.QueryRepairCost (whocret: TCreature; uitem: TUserItem);
var
   i, price, cost: integer;
begin
   price := GetSellPrice (TUserHuman(whocret), GetGoodsPrice (uitem)); //판매가격으로 환산함.
   if price > 0 then begin
      if (whocret.LatestNpcCmd = '@s_repair') or (whocret.LatestNpcCmd = '@t_repair') then begin //특수수리
         price := price * 3;
         //if specialrepair > 0 then
         //else whocret.LatestNpcCmd := '@fail_s_repair';     //특수수리 재료 부족..
      end;

      if uitem.DuraMax > 0 then
         cost := Round(((price div 3) / uitem.DuraMax) * _MAX(0, uitem.DuraMax-uitem.Dura))  //DURAMAX수정
      else
         cost := 0;//price;

      whocret.SendMsg (self, RM_SENDREPAIRCOST, 0, cost, 0, 0, '');
   end else
      whocret.SendMsg (self, RM_SENDREPAIRCOST, 0, -1, 0, 0, '');  //없음..
end;

function  TMerchant.UserRepairItem (whocret: TCreature; puitem: PTUserItem): Boolean;
var
   i, price, cost: integer;
   pstd: PTStdItem;
   repair_type : integer;
   str: string;
begin
   Result := FALSE;
   repair_type := 0;
   if whocret.LatestNpcCmd = '@fail_s_repair' then begin
      //특수수리 못함.
      {$IFDEF KOREA}
         str := '미안하네, 특수수리 재료가 방금 떨어졌네...\ ' +
                        '\ \<뒤로/@main>';
      {$ELSE}
         str := 'Sorry, but we have no material for special repairs at the moment...\ ' +
                        '\ \<back/@main>';
      {$ENDIF}
      str := ReplaceChar (str, '\', char($a));
      NpcSay (whocret, str);
      whocret.SendMsg (self, RM_USERREPAIRITEM_FAIL, 0, 0, 0, 0, '');
      exit;
   end;

   pstd := UserEngine.GetStdItem (puitem.Index);
   if pstd = nil then exit;

   price := GetSellPrice (TUserHuman(whocret), GetGoodsPrice (puitem^));
   if CanSpecialRepair and (whocret.LatestNpcCmd = '@s_repair') then begin //특수수리
      price := price * 3;
      if (pstd.StdMode <> 5) and (pstd.StdMode <> 6) then begin
         {$IFDEF KOREA} MainOutMessage('특수수리(X): ' + whocret.UserName + ' - ' + pstd.Name);
         {$ELSE}        MainOutMessage('Special Repair(X): ' + whocret.UserName + ' - ' + pstd.Name);
         {$ENDIF}
         whocret.SendMsg (self, RM_USERREPAIRITEM_FAIL, 0, 0, 0, 0, '');
         exit; // gadget:무기가 아니면 특수수리 없음.
      end else begin
         {$IFDEF KOREA} MainOutMessage('특수수리: ' + whocret.UserName + '(' + whocret.MapName + ':' + IntToStr(whocret.CX) + ',' + IntToStr(whocret.CY) + ')' + ' - ' + pstd.Name);
         {$ELSE}
         {$ENDIF}
      end;
   end;

   if CanTotalRepair and (whocret.LatestNpcCmd = '@t_repair') then begin //절대수리
      price := price * 3;
      // 절대수리 이벤트 2003-06-26
      case pstd.StdMode of
      5,6,10,11,15,19,20,21,22,23,24,26,52,54:
         begin
            {$IFDEF KOREA} MainOutMessage('이벤트 특수수리: ' + whocret.UserName + '(' + whocret.MapName + ':' + IntToStr(whocret.CX) + ',' + IntToStr(whocret.CY) + ')' + ' - ' + pstd.Name)
            {$ELSE}
            {$ENDIF}
         end;
      else
         {$IFDEF KOREA} MainOutMessage('이벤트 특수수리(X): ' + whocret.UserName + ' - ' + pstd.Name);
         {$ELSE}        MainOutMessage('Perfect Repair(X): ' + whocret.UserName + ' - ' + pstd.Name);
         {$ENDIF}
         whocret.SendMsg (self, RM_USERREPAIRITEM_FAIL, 0, 0, 0, 0, '');
         exit; // pds:이벤트 절대수리
      end;

   end;

   // 유니크아이템 필드가 3이면 수리불가.
   // or -> and (sonmg's bug 2003/12/03)
   if ((price > 0) and (pstd.StdMode <> 43)) and {(pstd.UniqueItem <> 3)} ((pstd.UniqueItem and $02) = 0) then begin  //취급하지 않는 것은 수리 안됨
      if puitem.DuraMax > 0 then
         cost := Round(((price div 3) / puitem.DuraMax) * _MAX(0, puitem.DuraMax-puitem.Dura))  //DURAMAX수정
      else
         cost := 0;//price;

      if ( cost > 0 ) and whocret.DecGold (cost) then begin

         //사북성안의 상점인 경우
         if BoCastleManage then  //5%의 세금이 걷힌다.
            UserCastle.PayTax (cost);

         if (CanSpecialRepair and (whocret.LatestNpcCmd = '@s_repair'))
            or (CanTotalRepair and (whocret.LatestNpcCmd = '@t_repair')) then begin //특수수리
            //Dec (specialrepair);
            //특수수리는 내구가 약해지지 않음
            //puitem.DuraMax := puitem.DuraMax - _MAX(0, puitem.DuraMax-puitem.Dura) div 100;  //DURAMAX수정
            puitem.Dura := puitem.DuraMax;

            whocret.SendMsg (self, RM_USERREPAIRITEM_OK, 0, whocret.Gold, puitem.Dura, puitem.DuraMax, '');

            {$IFDEF KOREA} str := '완벽하게 수리되었네...\잘 쓰시게.\ \<뒤로/@main>';
            {$ELSE}        str := 'It seems to be repaired perfectly ...\use it well .\ \<back/@main>';
            {$ENDIF}
//            str := ReplaceChar (str, '\', char($a));
//            NpcSay (whocret, str);
            NpcSayTitle (whocret, '@succeed_s_repair');
            repair_type := 2;
         end else begin
            //일반 수리, 내구성이 많이 약해짐
            puitem.DuraMax := puitem.DuraMax - _MAX(0, puitem.DuraMax-puitem.Dura) div 30;   //DURAMAX수정
            puitem.Dura := puitem.DuraMax;

            whocret.SendMsg (self, RM_USERREPAIRITEM_OK, 0, whocret.Gold, puitem.Dura, puitem.DuraMax, '');
            NpcSayTitle (whocret, '~@repair');
            repair_type := 1;
         end;
         Result := TRUE;

         //수리 로그 남김
         AddUserLog ('36'#9 + //수리_ +
                 whocret.MapName + ''#9 +
                 IntToStr(cost) + ''#9 +
                 IntToStr(whocret.Gold) + ''#9 +
                 whocret.UserName + ''#9 +
                 intToStr(puitem.DuraMax) + ''#9 +
                 IntToStr(puitem.MakeIndex) + ''#9 +
                 intToStr(Repair_type)+#9 +
                 '0');


      end else //돈이 없음
         whocret.SendMsg (self, RM_USERREPAIRITEM_FAIL, 0, 0, 0, 0, '');
   end else
      whocret.SendMsg (self, RM_USERREPAIRITEM_FAIL, 0, 0, 0, 0, '');
end;

procedure TMerchant.UserBuyItem (whocret: TUserHuman; itmname: string; serverindex, BuyCount: integer);
var
   i, k, sellprice, rcode: integer;
   list: TList;
   pstd: PTStdItem;
   pu: PTUserItem;
   done: Boolean;
   CheckWeight : integer;
   iname : String;
   InviteResult : Boolean;
begin
   done := FALSE;
   InviteResult := TRUE;
   rcode := 1;  //상품이 다 팔렸습니다.
   for i:=0 to GoodsList.Count-1 do begin
      if done then break;
      if NoSeal then break;  //물건을 안파는 가게
      list := GoodsList[i];
      pu := PTUserItem (list[0]);
      pstd := UserEngine.GetStdItem (pu.Index);
      if pstd <> nil then begin
         // 카운트아이템
         if pstd.OverlapItem = 1 then
            CheckWeight := pstd.Weight + pstd.Weight * (BuyCount div 10)
         else if pstd.OverlapItem >= 2 then
            CheckWeight := pstd.Weight * BuyCount
         else
            CheckWeight := pstd.Weight;

         if whocret.IsAddWeightAvailable (CheckWeight) then begin
            if pstd.Name = itmname then begin
               for k:=0 to list.Count-1 do begin     //사용자가 물건을 사감
                  pu := PTUserItem (list[k]);
                  if (pstd.StdMode <= 4) or (pstd.StdMode = 42) or (pstd.StdMode = 31) or (pu.MakeIndex = serverindex)  or (pstd.OverlapItem >= 1) then begin
                     //돈을 충분이 가지고 있어야함.
                     //if pstd.StdMode <= 4 then sellprice := GetPrice (pu.Index) //대표가격
                     sellprice := GetSellPrice (whocret, GetGoodsPrice (pu^)) * BuyCount; //개별 가격
                     if (whocret.Gold >= sellprice) and (sellprice > 0) then begin
                        if pstd.OverlapItem >= 1 then begin
                           pu.Dura := _MIN(1000, BuyCount);
                        end;

                        // 2003/03/04 상점 젠 타임 조정 1분 -> 1시간<- 이 리마크로 코딩되어 있는 테스트 서버 코드
{
                        // 2003/03/04 약물, 전서류, 횃불, 약묶음, 부적 종류는 새로 만들어 보내준다
                        if(pstd.StdMode = 0) or //(pstd.StdMode = 25) or //독가루 제외
                         ((pstd.StdMode = 3) and ((pstd.Shape = 1) or (pstd.Shape = 2) or (pstd.Shape = 3) or (pstd.Shape = 5) or (pstd.Shape = 9))) or
                          ((pstd.StdMode = 30) and (pstd.Shape = 0)) or (pstd.StdMode = 31) then begin
                           iname := pstd.Name;
                           new(pu);
                           if UserEngine.CopyToUserItemFromName(iname, pu^) then begin
                              if whocret.AddItem(pu) then begin
//                                 whocret.Gold := whocret.Gold - sellprice;
                                 whocret.DecGold( sellprice );
                                 whocret.SendAddItem(pu^);
                                 //사북성안의 상점인 경우
                                 if BoCastleManage then  //5%의 세금이 걷힌다.
                                    UserCastle.PayTax (sellprice);
                                 //로그남김
                                 AddUserLog ('9'#9 + //구입_
                                             whocret.MapName + ''#9 +
                                             IntToStr(whocret.CX) + ''#9 +
                                             IntToStr(whocret.CY) + ''#9 +
                                             whocret.UserName + ''#9 +
                                             UserEngine.GetStdItemName (pu.Index) + ''#9 +
                                             IntToStr(pu.MakeIndex) + ''#9 +
                                             '1'#9 +
                                             UserName);
                                 rcode := 0;
                              end else begin
                                 Dispose(pu);
                                 rcode := 2;
                              end;
                           end else begin
                              Dispose(pu);
                              rcode := 2;
                           end;
                        end else begin
}

                           // 카운트 아이템
                           if pstd.OverlapItem >= 1 then begin
                              if whocret.UserCounterItemAdd(pstd.StdMode, pstd.Looks, BuyCount, pstd.Name, FALSE) then begin
//                                 whocret.Gold := whocret.Gold - sellprice;
                                 whocret.DecGold( sellprice );

//                                 Dispose(list[k]);    //막아보자...

                                 list.Delete(k);
                                 if list.Count = 0 then begin
                                    list.Free;
                                    GoodsList.Delete(i);
                                 end;

                                 whocret.WeightChanged;

                                 rcode := 0;
                                 done := TRUE;
                                 break;
                              end;
                           end;

                           InviteResult := TRUE;
                           //초대장 셋팅.
                           if (pstd.StdMode = 8) and (pstd.Shape = SHAPE_OF_INVITATION) then begin
                              InviteResult := whocret.GuildAgitInvitationItemSet(pu);
                              if not InviteResult then begin
                                 {$IFDEF KOREA} whocret.SysMsg('해당 장원소유 문파원들만이 초대장을 구입할 수 있습니다.', 0);
                                 {$ELSE}        whocret.SysMsg('You can get an Invitation only in your guild territory.', 0);
                                 {$ENDIF}
                              end;
                           end;

                           if InviteResult then begin
                              if whocret.AddItem (pu) then begin
//                                 whocret.Gold := whocret.Gold - sellprice;
                                 whocret.DecGold( sellprice );

                                 //사북성안의 상점인 경우
                                 if BoCastleManage then  //5%의 세금이 걷힌다.
                                    UserCastle.PayTax (sellprice);

                                 whocret.SendAddItem (pu^);  //사기 성공

                                 // 중요도가 떨어지는 아이템은 로그를 남기지 않는다.
                                 if not IsCheapStuff (pstd.StdMode) then begin
                                    AddUserLog ('9'#9 + //구입_
                                                whocret.MapName + ''#9 +
                                                IntToStr(whocret.CX) + ''#9 +
                                                IntToStr(whocret.CY) + ''#9 +
                                                whocret.UserName + ''#9 +
                                                UserEngine.GetStdItemName (pu.Index) + ''#9 +
                                                IntToStr(pu.MakeIndex) + ''#9 +
                                                '1'#9 +
                                                UserName);
                                 end;

                                 list.Delete (k);
                                 if list.Count = 0 then begin
                                    list.Free;
                                    GoodsList.Delete (i);
                                 end;
                                 rcode := 0;
                              end else
                                 rcode := 2;
                           end else begin
                              //초대장을 살 수 없으면 빠져나감.
                              exit;
                           end;
                        // 2003/03/04 약물, 전서류, 횃불, 약묶음, 부적 종류는 새로 만들어 보내준다
                        // end;
                     end else
                        rcode := 3; //돈이 부족함.
                     done := TRUE;
                     break;
                  end;
               end;
            end;
         end else begin
            rcode := 2;  //더 이상 들 수 없음.
         end;
      end;
   end;
   if rcode = 0 then begin
      whocret.SendMsg (self, RM_BUYITEM_SUCCESS, 0, whocret.Gold, serverindex{팔린 아이템}, 0, '');
   end else begin
      whocret.SendMsg (self, RM_BUYITEM_FAIL, 0, rcode, 0, 0, '');
   end;
end;

procedure TMerchant.UserWantDetailItems (whocret: TCreature; itmname: string; menuindex: integer);
var
   i, k, count, grade: integer;
   rr: Real;
   data: string;
   list: TList;
   pstd: PTStdItem;
   pu: PTUserItem;
   cg: TClientGoods;
   citem: TClientItem;
begin
   count := 0;
   for i:=0 to GoodsList.Count-1 do begin
      list := GoodsList[i];
      pu := PTUserItem (list[0]);
      pstd := UserEngine.GetStdItem (pu.Index);
      if pstd <> nil then begin
         if pstd.Name = itmname then begin
            if menuindex > list.Count-1 then menuindex := _MAX(0, list.Count-10);
            for k:=menuindex to list.Count-1 do begin
               pu := PTUserItem (list[k]);
               citem.S := pstd^;

               //미지의속성 프리 안된 것들 숨기기
               if pstd.StdMode in [15,19,20,21,22,23,24,26,52,53,54] then begin
                  if pu.Desc[8] = 0 then begin //속성이 프리됨(sonmg 2005/04/07 수정)
                     citem.S.ItemDesc := citem.S.ItemDesc and (not IDC_UNIDENTIFIED);//$01;
                  end else begin
                     citem.S.ItemDesc := citem.S.ItemDesc or IDC_UNIDENTIFIED;//$01;
                  end;
               end;

               citem.UpgradeOpt := 0;
               citem.Dura := pu.Dura;
               citem.DuraMax := GetSellPrice (TUserHuman(whocret), GetGoodsPrice (pu^));  //개별 자세한 가격
               citem.MakeIndex := pu.MakeIndex;
               data := data + EncodeBuffer (@citem, sizeof(TClientItem)) + '/';

               Inc (count);
               if count >= 10 then break;
            end;
            break;
         end;
      end;
   end;
   whocret.SendMsg (self, RM_SENDDETAILGOODSLIST, 0, integer(self), count, menuindex, data);
end;

//////////////////////////////////////////
// 제조 관련 상수
//////////////////////////////////////////
const
   MAX_SOURCECNT    = 6;
   //---------------//
   // 조건 결과
   COND_FAILURE     = 0;
   COND_GEMFAIL     = 1;
   COND_SUCCESS     = 2;
   COND_MINERALFAIL = 3;
   COND_NOMONEY     = 4;
   COND_BAGFULL     = 5;
   //---------------//
   // 수호석 등급
   GSG_ERROR       = 0;
   GSG_SMALL       = 1; //(소)
   GSG_MEDIUM      = 2; //(중)
   GSG_LARGE       = 3; //(대)
   GSG_GREATLARGE  = 4; //(특)
   GSG_SUPERIOR    = 5; //지석 or 신석
   //---------------//
//////////////////////////////////////////

procedure TMerchant.UserMakeNewItem (whocret: TUserHuman; itmname: string);
{
const
   COND_FAILURE = 0;
//   COND_GEMFAIL = 1;
   COND_SUCCESS = 2;
//   COND_MINERALFAIL = 3;
   COND_NOMONEY = 4;
   //---------------//
}
   function CheckCondition (hum: TUserHuman; itemname: string; var iPrice: Integer): Integer;
   var
      list: TStringList;
      k, i, sourcecount: integer;
      sourcename: string;
      condition: Integer;
      dellist: TStringList;
      pu: PTUserItem;
      ps: PTStdItem;
   begin
      condition := COND_FAILURE;
      list := GetMakeItemCondition (itemname, iPrice);

      if (hum.Gold < iPrice) then begin
         Result := COND_NOMONEY;
         exit;
      end;

      if list <> nil then begin
         condition := COND_SUCCESS;
         for k:=0 to list.Count-1 do begin  //만드는데 필요한 재료
            sourcename := list[k];
            sourcecount := integer (list.Objects[k]);
            for i:=0 to hum.ItemList.Count-1 do begin //내 가방에 아이템이 있는지 검사
               pu := PTUserItem (hum.ItemList[i]);
               if sourcename = UserEngine.GetStdItemName(pu.Index) then begin
                  ps := UserEngine.GetStdItem (pu.Index);
                  if ps <> nil then
                  begin
                     // 카운트 아이템.
                     if ps.OverlapItem >= 1 then
                        sourcecount := sourcecount - _MIN(pu.Dura, sourcecount)
                     else
                        dec (sourcecount);  //갯수 검사..
                  end;
               end;
            end;
            if sourcecount > 0 then begin
               condition := COND_FAILURE;  //갯수 미달이면 조건 안맞음간주.
               break;
            end;
         end;
         if condition = COND_SUCCESS then begin //조건이 맞으면 재료는 사라진다.
            dellist := nil;
            for k:=0 to list.Count-1 do begin
               sourcename := list[k];
               sourcecount := integer (list.Objects[k]);
               for i:=hum.ItemList.Count-1 downto 0 do begin
                  pu := PTUserItem (hum.ItemList[i]);
                  if sourcecount > 0 then begin
                     if sourcename = UserEngine.GetStdItemName(pu.Index) then begin
                        ps := UserEngine.GetStdItem (pu.Index);
                        if ps <> nil then
                        begin
                           //카운트 아이템.
                           if ps.OverlapItem >= 1 then begin
                              if pu.Dura < Integer(list.Objects[k]) then
                                 pu.Dura := 0
                              else
                                 pu.Dura := pu.Dura - Integer(list.Objects[k]);

                              if pu.Dura > 0 then begin
                                 hum.SendMsg(self, RM_COUNTERITEMCHANGE, 0, pu.MakeIndex, pu.Dura, 0, ps.Name);
                                 continue;
                              end;
                           end;
                           //일반 아이템 또는 카운트 아이템 삭제
                           if dellist = nil then dellist := TStringList.Create;
                           dellist.AddObject(sourcename, TObject(PTUserItem (hum.ItemList[i]).MakeIndex));
                           Dispose (PTUserItem(hum.ItemList[i]));
                           hum.ItemList.Delete (i);
                           dec (sourcecount);
                        end;
                     end;
                  end else
                     break;
               end;
            end;
            if dellist <> nil then //dellist은  RM_DELITEMS에서 Free됨.
               hum.SendMsg (self, RM_DELITEMS, 0, integer(dellist), 0, 0, '');
         end;
      end;
      Result := condition;
   end;
const
   MAKEPRICE = 100;
var
   i, rcode: integer;
   done: Boolean;
   list: TList;
   pu, newpu: PTUserItem;
   pstd: PTStdItem;
   iMakePrice: Integer;
   iCheckResult: Integer;
begin
   iMakePrice := MAKEPRICE;

   done := FALSE;
   rcode := 1;
   for i:=0 to GoodsList.Count-1 do begin
      if done then break;
      list := GoodsList[i];
      pu := PTUserItem (list[0]);
      pstd := UserEngine.GetStdItem (pu.Index);
      if pstd <> nil then begin
         if pstd.Name = itmname then begin
            //아이템 만드는 비용도 함께 체크한다.
            iCheckResult := CheckCondition (whocret, itmname, iMakePrice);
            if iCheckResult <> COND_NOMONEY then begin
               if iCheckResult = COND_SUCCESS then begin
                  new (newpu);
                  UserEngine.CopyToUserItemFromName (itmname, newpu^);
                  if whocret.AddItem (newpu) then begin
//                     whocret.Gold := whocret.Gold - iMakePrice;
                     whocret.DecGold( iMakePrice );
                     whocret.SendAddItem (newpu^);  //만들기 성공...
                     //로그남김
                     AddUserLog ('2'#9 + //제작_
                                 whocret.MapName + ''#9 +
                                 IntToStr(whocret.CX) + ''#9 +
                                 IntToStr(whocret.CY) + ''#9 +
                                 whocret.UserName + ''#9 +
                                 UserEngine.GetStdItemName (newpu.Index) + ''#9 +
                                 IntToStr(newpu.MakeIndex) + ''#9 +
                                 '1'#9 +
                                 UserName);
                     rcode := 0;
                  end else begin
                     Dispose (newpu);
                     rcode := 2;
                  end;
               end else
                  rcode := 4;
            end else
               rcode := 3;
         end;
      end;
   end;
   if rcode = 0 then begin
      whocret.SendMsg (self, RM_MAKEDRUG_SUCCESS, 0, whocret.Gold, 0, 0, '');
   end else begin
      whocret.SendMsg (self, RM_MAKEDRUG_FAIL, 0, rcode, 0, 0, '');
   end;
end;

// 아이템 제조 프로시져.
procedure TMerchant.UserManufactureItem (whocret: TUserHuman; itmname: string);
const
   MAKEPRICE = 100;
var
   i, j, rcode: integer;
   done: Boolean;
   list: TList;
   pu, newpu: PTUserItem;
   pstd: PTStdItem;
   sMakeItemName: string;
   sItemMakeIndex: array [1..MAX_SOURCECNT] of string;
   sItemName: array [1..MAX_SOURCECNT] of string;
   sItemCount: array [1..MAX_SOURCECNT] of string;
   iCheckResult: Integer;
   iMakePrice, iMakeCount: integer;
   strSourceLog: string;
begin
   iMakePrice := MAKEPRICE;
   strSourceLog := '';

   try
      // RightStr := GetValidStr3 (OrgStr, LeftStr of Separator, Separator);
      itmname := GetValidStr3 (itmname, sMakeItemName, ['/']);
      for i:= 1 to MAX_SOURCECNT do begin
         itmname := GetValidStr3 (itmname, sItemMakeIndex[i], [':']);
         itmname := GetValidStr3 (itmname, sItemName[i], [':']);
         itmname := GetValidStr3 (itmname, sItemCount[i], ['/']);
      end;
      ///////////////////////////////////////////
{$IFDEF DEBUG}   //sonmg
      whocret.SysMsg (sMakeItemName, 0);
      for i := 1 to MAX_SOURCECNT do begin
         whocret.SysMsg (sItemMakeIndex[i] + sItemName[i] + sItemCount[i], 0);
         //제조 재료 로그
         strSourceLog := strSourceLog + sItemName[i];
         if i <> MAX_SOURCECNT then
            strSourceLog := strSourceLog + ','; //마지막 재료가 아니면 ','를 붙인다.
      end;
{$ENDIF}
      ///////////////////////////////////////////

      done := FALSE;
      rcode := 1;
      for i:=0 to GoodsList.Count-1 do begin
         if done then break;
         list := GoodsList[i];
         pu := PTUserItem (list[0]);
         pstd := UserEngine.GetStdItem (pu.Index);
         if pstd <> nil then begin
            if pstd.Name = sMakeItemName then begin
               //아이템 만드는 비용도 함께 체크한다.
               iCheckResult := CheckMakeItemCondition (whocret, sMakeItemName, sItemMakeIndex, sItemName, sItemCount, iMakePrice, iMakeCount);
               if iCheckResult <> COND_NOMONEY then begin
                  if iCheckResult = COND_SUCCESS then begin
                     for j:=0 to iMakeCount-1 do begin
                        new (newpu);
                        UserEngine.CopyToUserItemFromName (sMakeItemName, newpu^);
                        if whocret.AddItem (newpu) then begin
//                           whocret.Gold := whocret.Gold - iMakePrice;
                           whocret.DecGold( iMakePrice );
                           whocret.SendAddItem (newpu^);  //만들기 성공...

                           // 제조 성공 로그
{
                           MainOutMessage( '[Manufacture 제조] ' + whocret.UserName + ' ' + UserEngine.GetStdItemName (newpu.Index) + '(' + IntToStr(newpu.MakeIndex) + ') '
                              + '=> 삭제된 재료:' + sItemName[1] + ', ' + sItemName[2]
                              + ', ' + sItemName[3] + ', ' + sItemName[4]
                              + ', ' + sItemName[5] + ', ' + sItemName[6] );
}

                           //로그남김
                           AddUserLog ('2'#9 + //제작_
                                       whocret.MapName + ''#9 +
                                       IntToStr(whocret.CX) + ''#9 +
                                       IntToStr(whocret.CY) + ''#9 +
                                       whocret.UserName + ''#9 +
                                       UserEngine.GetStdItemName (newpu.Index) + ''#9 +
                                       IntToStr(newpu.MakeIndex) + ''#9 +
                                       '1'#9 +
                                       UserName);
                           rcode := 0;
                        end else begin
                           Dispose (newpu);
                           rcode := 2;
                        end;
                     end;
                  end else if iCheckResult = COND_GEMFAIL then begin
                     // 보옥 제조 실패시에도 돈은 빠져 나간다.
//                     whocret.Gold := whocret.Gold - iMakePrice;
                     whocret.DecGold( iMakePrice );
                     whocret.GoldChanged;

                     //로그남김
                     AddUserLog ('2'#9 + //제작_실패
                                 whocret.MapName + ''#9 +
                                 IntToStr(whocret.CX) + ''#9 +
                                 IntToStr(whocret.CY) + ''#9 +
                                 whocret.UserName + ''#9 +
                                 'FAIL'#9 +
                                 '0'#9 +
                                 '1'#9 +
                                 UserName);
                     rcode := 5;
                  end else if iCheckResult = COND_MINERALFAIL then begin
                     rcode := 6;
                  end else if iCheckResult = COND_BAGFULL then begin
                     rcode := 7;
                  end else
                     rcode := 4;
               end else
                  rcode := 3;
            end;
         end;
      end;

      if rcode = 0 then begin
         whocret.SendMsg (self, RM_MAKEDRUG_SUCCESS, 0, whocret.Gold, 0, 0, '');
      end else begin
         whocret.SendMsg (self, RM_MAKEDRUG_FAIL, 0, rcode, 0, 0, '');
      end;
   except
      MainOutMessage ('[Exception] TMerchant.UserManufactureItem');
   end;
end;

////////////////////////////////////////////////////////////
// 수호석의 등급을 얻어내는 함수.
function TMerchant.GetGradeOfGuardStoneByName ( strGuardStone: string ): Integer;
begin
   Result := GSG_ERROR;

   //Compare String...
   if ENGLISHVERSION or PHILIPPINEVERSION then begin
      if CompareBackLStr(strGuardStone, '(S)', 3) = TRUE then begin
         Result := GSG_SMALL;
      end else if CompareBackLStr(strGuardStone, '(M)', 3) = TRUE then begin
         Result := GSG_MEDIUM;
      end else if CompareBackLStr(strGuardStone, '(L)', 3) = TRUE then begin
         Result := GSG_LARGE;
      end else if (CompareBackLStr(strGuardStone, '(XL)', 4) = TRUE) or
          (CompareBackLStr(strGuardStone, 'XL', 2) = TRUE) then begin
         Result := GSG_GREATLARGE;
      end else if CompareBackLStr(strGuardStone, 'STONE', 5) = TRUE then begin
         Result := GSG_SUPERIOR;
      end else begin
         Result := GSG_ERROR;
      end;
   end else if KOREANVERSION then begin
      if CompareBackLStr(strGuardStone, '(소)', 4) = TRUE then begin
         Result := GSG_SMALL;
      end else if CompareBackLStr(strGuardStone, '(중)', 4) = TRUE then begin
         Result := GSG_MEDIUM;
      end else if CompareBackLStr(strGuardStone, '(대)', 4) = TRUE then begin
         Result := GSG_LARGE;
      end else if CompareBackLStr(strGuardStone, '(특)', 4) = TRUE then begin
         Result := GSG_GREATLARGE;
      end else if CompareBackLStr(strGuardStone, '지석', 4) = TRUE then begin
         Result := GSG_SUPERIOR;
      end else if CompareBackLStr(strGuardStone, '신석', 4) = TRUE then begin
         Result := GSG_SUPERIOR;
      end else begin
         Result := GSG_ERROR;
      end;
   end else begin
      //기본값
      if CompareBackLStr(strGuardStone, '(소)', 4) = TRUE then begin
         Result := GSG_SMALL;
      end else if CompareBackLStr(strGuardStone, '(중)', 4) = TRUE then begin
         Result := GSG_MEDIUM;
      end else if CompareBackLStr(strGuardStone, '(대)', 4) = TRUE then begin
         Result := GSG_LARGE;
      end else if CompareBackLStr(strGuardStone, '(특)', 4) = TRUE then begin
         Result := GSG_GREATLARGE;
      end else if CompareBackLStr(strGuardStone, '지석', 4) = TRUE then begin
         Result := GSG_SUPERIOR;
      end else if CompareBackLStr(strGuardStone, '신석', 4) = TRUE then begin
         Result := GSG_SUPERIOR;
      end else begin
         Result := GSG_ERROR;
      end;
   end;
end;

////////////////////////////////////////////////////////////
// 제조대상에 필요한 목록과 전송받은 목록을 비교하여
// 조건에 맞는지 아닌지 체크하고 아이템을 삭제하는 함수.
function TMerchant.CheckMakeItemCondition (hum: TUserHuman; itemname: string; sItemMakeIndex, sItemName, sItemCount: array of string; var iPrice, iMakeCount: Integer): Integer;
var
   list: TStringList;
   k, i, j, icnt: integer;
   sourcecount, counteritmcount, itemp: integer;
   sourcemindex: integer;
   sourcename: string;
   condition: Integer;
   dellist: TStringList;
   pu: PTUserItem;
   ps: PTStdItem;
   iGuardStoneGrade: integer;
   iProbability: Integer;
   fTemporary: Real;
   iRequiredGuardStoneGrade: Integer;
   iSumOutfitAbil, iOutfitGrade: Integer;
   // 새로운 List
   sNewName: array [0..MAX_SOURCECNT-1] of string;
   sNewCount: array [0..MAX_SOURCECNT-1] of string;
   sNewMIndex: array [0..MAX_SOURCECNT-1] of string;
   iListDoubleCount: array [0..MAX_SOURCECNT-1] of Integer;
   checkcount: integer;
   bCheckMIndex: Boolean;
   // 스크립트 문자열 정의
   strPendant, strGuardStone, strGuardStone15, strGuardStoneXLHigher : string;
   delitemname : string;
begin
   strPendant := '';
   strGuardStone := '';
   strGuardStone15 := '';
   strGuardStoneXLHigher := '';

   if ENGLISHVERSION or PHILIPPINEVERSION then begin
      strPendant := '<PENDANT>';
      strGuardStone := '<GUARDSTONE>';
      strGuardStone15 := '<GUARDSTONE15>';
      strGuardStoneXLHigher := '<GUARDSTONE(XL)HIGHER>';
   end else if KOREANVERSION then begin
      strPendant := '<장신구>';
      strGuardStone := '<수호석>';
      strGuardStone15 := '<수호석15>';
      strGuardStoneXLHigher := '<수호석(특)이상>';
   end else begin
      //기본값
      strPendant := '<장신구>';
      strGuardStone := '<수호석>';
      strGuardStone15 := '<수호석15>';
      strGuardStoneXLHigher := '<수호석(특)이상>';
   end;

   iProbability := 0;
   fTemporary := 0;
   condition := COND_FAILURE;
   iRequiredGuardStoneGrade := 0;  //수호석 추가 확률 등급
   iOutfitGrade := 0;   //장신구 추가 확률 등급
   iSumOutfitAbil := 0;
   iGuardStoneGrade := GSG_ERROR;

   list := GetMakeItemCondition (itemname, iPrice);

   // 가방창 여분의 공간 확인
   if hum.CanAddItem = FALSE then begin
      Result := COND_BAGFULL;
      {$IFDEF KOREA} hum.SysMsg('가방이 가득 차서 제조를 할 수 없습니다.', 0);
      {$ELSE}        hum.SysMsg('Your bag is full.', 0);
      {$ENDIF}
      exit;
   end;

   if list <> nil then begin
      // 전송문자열 인자수보다 크면 안됨.
      if list.Count > MAX_SOURCECNT then
         MainOutMessage ('[Caution!] list.Count Overflow in TMerchant.UserManufactureItem');

      condition := COND_SUCCESS;

      // 보옥 타입 검사(수호석의 종류로 검사 sonmg)
      for j:= 0 to list.Count-1 do begin
         if UPPERCASE(list[j]) = strGuardStone then begin
            iRequiredGuardStoneGrade := 1;  // 타입 A
         end else if UPPERCASE(list[j]) = strGuardStoneXLHigher then begin
            iRequiredGuardStoneGrade := 2;  // 타입 B
         end else if UPPERCASE(list[j]) = strGuardStone15 then begin
            iRequiredGuardStoneGrade := 3;  // 타입 C (수호석은 일반, 광석순도 15이상)
         end;
      end;

      //------ 재료 검사 ------//
      // 1.전송문자열이 가방창에 모두 있는지(Name과 MakeIndex) 검사
      // 있으면 List에서 해당 아이템 이름과 MakeIndex 업데이트(StdMode참조)
      for k:=0 to MAX_SOURCECNT-1 do begin  //전송문자열
         sourcemindex := Str_ToInt(sItemMakeIndex[k], 0);
         sourcename := sItemName[k];
         sourcecount := Str_ToInt(sItemCount[k], 0);

         for i:=0 to hum.ItemList.Count-1 do begin
            pu := PTUserItem (hum.ItemList[i]);
            // 아이템 이름 비교
            if sItemName[k] = UserEngine.GetStdItemName(pu.Index) then begin
               ps := UserEngine.GetStdItem (pu.Index);
               if ps <> nil then
               begin
                  // 카운트 아이템.
                  if ps.OverlapItem >= 1 then begin
                     if pu.Dura < sourcecount then begin
                        sourcecount := sourcecount - pu.Dura;
                     end else begin
                        itemp := sourcecount;
                        sourcecount := _MAX(0, itemp - pu.Dura);
                     end;

                     if sourcecount <= 0 then begin
                        for j:= 0 to list.Count-1 do begin
                           if list[j] = sourcename then begin
                              sNewMIndex[j] := sItemMakeIndex[k];
                              sNewName[j] := sourcename;
                              sNewCount[j] := sItemCount[k];
                           end;
                        end;

                        break;
                     end;
                  end else begin
                     // MakeIndex 비교
                     if sourcemindex = pu.MakeIndex then begin
                        for j:= 0 to list.Count-1 do begin
                           if list[j] = sourcename then begin
                              // 같은 아이템이 두개 이상 있을 경우 카운트 증가
                              if sNewName[j] = sourcename then begin
                                 sNewCount[j] := IntToStr( Str_ToInt(sNewCount[j], 0) + 1 );
                              end else begin
                                 sNewCount[j] := sItemCount[k];
                                 sNewMIndex[j] := sItemMakeIndex[k];
                              end;

                              sNewName[j] := sourcename;
                           end;
                        end;

                        // <장신구> <수호석> <수호석(특)이상> 아이템이 있으면
                        // 전송문자열에 있는 아이템을 list에 등록한다.
                        if ps.StdMode in [19,20,21, 22,23, 24,26] then begin
                           for j:= 0 to list.Count-1 do begin
                              if UPPERCASE(list[j]) = strPendant then begin
                                 sNewMIndex[j] := sItemMakeIndex[k];
                                 sNewName[j] := sourcename;
                                 sNewCount[j] := sItemCount[k];

                                 // 장신구 파괴,마력,도력 총합에 따라 등급 결정...
                                 iSumOutfitAbil := HIBYTE(ps.DC) + HIBYTE(ps.MC) + HIBYTE(ps.SC);
                                 if ps.StdMode in [22,23] then begin //반지
                                    if iSumOutfitAbil <= 3 then
                                       iOutfitGrade := 0   //가군
                                    else if iSumOutfitAbil = 4 then
                                       iOutfitGrade := 1   //나군
                                    else
                                       iOutfitGrade := 2;   //다군
                                 end else if ps.StdMode in [24,26] then begin //팔찌
                                    if HIBYTE(ps.DC) > 0 then begin //파괴 붙은 팔찌
                                       if iSumOutfitAbil = 1 then
                                          iOutfitGrade := 0   //가군
                                       else if iSumOutfitAbil = 2 then
                                          iOutfitGrade := 1   //나군
                                       else
                                          iOutfitGrade := 2;   //다군
                                    end else begin
                                       if iSumOutfitAbil = 1 then
                                          iOutfitGrade := 0   //가군
                                       else if iSumOutfitAbil in [2,3] then
                                          iOutfitGrade := 1   //나군
                                       else
                                          iOutfitGrade := 2;   //다군
                                    end;
                                 end else begin //목걸이
                                    if iSumOutfitAbil <= 3 then
                                       iOutfitGrade := 0   //가군
                                    else if iSumOutfitAbil in [4,5] then
                                       iOutfitGrade := 1   //나군
                                    else
                                       iOutfitGrade := 2;   //다군
                                 end;
                              end;
                           end;
                        end;
                        if ps.StdMode = 53 then begin
                           // 수호석 등급을 얻어낸다.
                           iGuardStoneGrade := GetGradeOfGuardStoneByName( sourcename );

                           for j := 0 to list.Count-1 do begin
                              if iGuardStoneGrade < GSG_GREATLARGE then begin
                                 if (UPPERCASE(list[j]) = strGuardStone) or (UPPERCASE(list[j]) = strGuardStone15) then begin
                                    sNewMIndex[j] := sItemMakeIndex[k];
                                    sNewName[j] := sourcename;
                                    sNewCount[j] := sItemCount[k];
                                 end;
                              end else if iGuardStoneGrade >= GSG_GREATLARGE then begin
                                 if (UPPERCASE(list[j]) = strGuardStone) or (UPPERCASE(list[j]) = strGuardStone15) or (UPPERCASE(list[j]) = strGuardStoneXLHigher) then begin
                                    sNewMIndex[j] := sItemMakeIndex[k];
                                    sNewName[j] := sourcename;
                                    sNewCount[j] := sItemCount[k];
                                 end;
                              end else begin
                                 // 수호석 이름이 이상하다면 Error : 확인해 봐야함.
                                 MainOutMessage('[Caution!] TMerchant.UserManufactureItem iGuardStoneGrade = GSG_ERROR');
                              end;
                           end;
                        end;

                        //------ 광석 순도 검사 ------//
                        if ps.StdMode = 43 then begin //광석
                           if iRequiredGuardStoneGrade = 1 then begin  // 타입 A
                              if pu.Dura < 11500 then begin // 순도 12
                                 condition := COND_MINERALFAIL;
                              end;
                           end else if iRequiredGuardStoneGrade = 2 then begin  // 타입 B
                              if pu.Dura < 14500 then begin // 순도 15
                                 condition := COND_MINERALFAIL;
                              end;
                           end else if iRequiredGuardStoneGrade = 3 then begin  // 타입 C
                              if pu.Dura < 14500 then begin // 순도 15
                                 condition := COND_MINERALFAIL;
                              end;
                           end;
                        end;

                        dec (sourcecount);  //갯수 감소..
                     end;
                  end;
               end;//if ps <> nil then
            end;
         end;

         if sourcecount > 0 then begin
            condition := COND_FAILURE;  //갯수 미달이면 조건 안맞음간주.
            break;
         end;
      end;

{$IFDEF DEBUG}
      for k:=0 to list.Count-1 do begin
         hum.SysMsg(sNewMIndex[k] + ' ' + sNewName[k] + ' ' + sNewCount[k], 2);
      end;
{$ENDIF}

      // 2.새로운 List가 list의 조건에 만족하는지 검사
      // 몇 개까지 만들 수 있는지 확인
      if (condition = COND_SUCCESS) or (condition = COND_MINERALFAIL) then begin
         checkcount := list.Count;
         for k:=0 to list.Count-1 do begin  //새로운 List
            sourcename := sNewName[k];
            sourcecount := Str_ToInt(sNewCount[k], 0);

            if (sourcename = list[k]) and (sourcecount >= Integer(list.Objects[k])) then begin
               iListDoubleCount[k] := sourcecount div Integer(list.Objects[k]);
               Dec(checkcount);
            end else if ( (UPPERCASE(list[k]) = strPendant) or (UPPERCASE(list[k]) = strGuardStone) or (UPPERCASE(list[k]) = strGuardStone15)
            or (UPPERCASE(list[k]) = strGuardStoneXLHigher) ) and (sourcecount >= Integer(list.Objects[k])) then begin
               iListDoubleCount[k] := sourcecount div Integer(list.Objects[k]);
               Dec(checkcount);
            end;
         end;

         if checkcount > 0 then
            condition := COND_FAILURE;  //갯수 미달이면 조건 안맞음간주.
      end;

      //------ 재료 삭제 ------//
      // 가방창에서 새로운 List에 해당하는 아이템을 삭제한다.
      // 만들 수 있는 개수만큼 삭제하고 나머지는 삭제하지 않음...
      if condition = COND_SUCCESS then begin
         //------ 만들 수 있는 개수 계산(최소값) -----//
         iMakeCount := iListDoubleCount[0];
         for k:=0 to list.Count-1 do begin
            if iMakeCount > iListDoubleCount[k] then
               iMakeCount := iListDoubleCount[k];
//               hum.SysMsg(IntToStr(iListDoubleCount[k]), 1);
         end;
//            hum.SysMsg('만드는 아이템 개수 : ' + IntToStr(iMakeCount), 2);

         // 필요한 금전이 있는지 확인
         if (hum.Gold < iPrice * iMakeCount) then begin
            Result := COND_NOMONEY;
            exit;
         end;

         // 가방창 여분이 있는지 확인 (sonmg 2004/02/21)
         if hum.Itemlist.Count + iMakeCount > MAXBAGITEM then begin
            Result := COND_BAGFULL;
            {$IFDEF KOREA} hum.SysMsg('가방이 가득 차서 제조를 할 수 없습니다.', 0);
            {$ELSE}        hum.SysMsg('Your bag is full.', 0);
            {$ENDIF}
            exit;
         end;

         //초기화
         dellist := nil;

         // 일단 새로운 List 항목 무조건 삭제
         // 제조는 만드는 아이템 개수만큼 Loop.
         // => 카운트는 list의 카운트만큼 삭제
         // ==> 카운트 아이템이 아닌데 2개 이상 있는 경우는 MakeIndex를
         //     전송리스트(sMakeItemIndex)에서 참조한다.
         //
         // 알아둘 것 : 수호석이나 장신구가 포함된 제조는 두 개 이상 한꺼번에
         // 제조가 안되고 나중에 올려진 아이템으로 제조가 된다.(sonmg 2003/12/19)
         for j:=0 to iMakeCount-1 do begin
            for k:=0 to list.Count-1 do begin  //새로운 List
               sourcemindex := Str_ToInt(sNewMIndex[k], 0);
               sourcename := sNewName[k];
               // 카운트는 list의 카운트만큼 삭제(필요한 만큼만 삭제)
               sourcecount := Integer(list.Objects[k]);
               counteritmcount := Integer(list.Objects[k]);

               for i:=hum.ItemList.Count-1 downto 0 do begin
                  pu := PTUserItem (hum.ItemList[i]);
                  if sourcecount > 0 then begin
                     if sourcename = UserEngine.GetStdItemName(pu.Index) then begin
                        ps := UserEngine.GetStdItem (pu.Index);
                        if ps <> nil then
                        begin
                           //카운트 아이템.
                           if ps.OverlapItem >= 1 then begin
                              if pu.Dura < counteritmcount then begin
                                 counteritmcount := counteritmcount - pu.Dura;
                                 pu.Dura := 0;
                              end else begin
                                 itemp := counteritmcount;
                                 counteritmcount := _MAX(0, itemp - pu.Dura);
                                 pu.Dura := pu.Dura - itemp;
                              end;

                              if pu.Dura > 0 then begin
                                 hum.SendMsg(self, RM_COUNTERITEMCHANGE, 0, pu.MakeIndex, pu.Dura, 0, ps.Name);
                                 continue;
                              end;
                           end else begin
                              // MakeIndex 비교
                              if pu.MakeIndex <> Str_ToInt(sNewMIndex[k], 0) then begin
                                 bCheckMIndex := FALSE;
                                 for icnt:= 0 to MAX_SOURCECNT-1 do begin
                                    if pu.MakeIndex = Str_ToInt(sItemMakeIndex[icnt], 0) then begin
                                       bCheckMIndex := TRUE;
                                       break;
                                    end;
                                 end;

                                 if bCheckMIndex = FALSE then
                                    continue;
                              end;
                           end;

                           //일반 아이템 또는 카운트 아이템 삭제
                           if dellist = nil then dellist := TStringList.Create;
                           delitemname := UserEngine.GetStdItemName(pu.Index);
                           dellist.AddObject(delitemname, TObject(PTUserItem (hum.ItemList[i]).MakeIndex));

                           //로그남김
                           AddUserLog ('44'#9 + //제조삭_
                                       hum.MapName + ''#9 +
                                       IntToStr(hum.CX) + ''#9 +
                                       IntToStr(hum.CY) + ''#9 +
                                       hum.UserName + ''#9 +
                                       delitemname + ''#9 +
                                       IntToStr(PTUserItem (hum.ItemList[i]).MakeIndex) + ''#9 +
                                       '1'#9 +
                                       UserName);

                           Dispose (PTUserItem(hum.ItemList[i]));
                           hum.ItemList.Delete (i);
                           dec (sourcecount);
                        end;//if ps <> nil then
                     end;
                  end else
                     break;
               end;
            end;
         end;
         if dellist <> nil then //dellist은  RM_DELITEMS에서 Free됨.
            hum.SendMsg (self, RM_DELITEMS, 0, integer(dellist), 0, 0, '');

         // 공통(1차) 보옥 제조 확률 적용...
         if iRequiredGuardStoneGrade > 0 then begin
            fTemporary := (hum.BodyLuck - hum.PlayerKillingPoint) / 250;

            if iRequiredGuardStoneGrade = 1 then
               iProbability := 50
            else if iRequiredGuardStoneGrade = 2 then
               iProbability := 50
            else if iRequiredGuardStoneGrade = 3 then
               iProbability := 50;

            if fTemporary >= 100 then
               iProbability := iProbability + 5
            else if (fTemporary < 100) and (fTemporary >= 50) then
               iProbability := iProbability + 3;

            // 수호석별 추가 확률 적용 (sonmg 2003/12/19)
            case iGuardStoneGrade of
               GSG_SMALL         : iProbability := iProbability + 5;
               GSG_MEDIUM        : iProbability := iProbability + 10;
               GSG_LARGE         : iProbability := iProbability + 15;
               GSG_GREATLARGE    : iProbability := iProbability + 30;
               GSG_SUPERIOR      : iProbability := iProbability + 50;
            end;
         end;

         // 2차 보옥 제조 확률 적용...
         if (iRequiredGuardStoneGrade = 1) or (iRequiredGuardStoneGrade = 3) then begin
            // 보옥 타입A 제조 확률 적용...
            if iOutfitGrade = 0 then begin
               iProbability := iProbability + 10;
            end else if iOutfitGrade = 1 then begin
               iProbability := iProbability + 20;
            end else if iOutfitGrade = 2 then begin
               iProbability := iProbability + 40;
            end;

{$IFDEF DEBUG}
            // test
            hum.SysMsg('BodyLuck:' + FloatToStr(hum.BodyLuck) +
               ' - PKPoint:' + FloatToStr(hum.PlayerKillingPoint) +
               ' = ' + FloatToStr(fTemporary) + ', iProbability:' + IntToStr(iProbability) +
               ', DC/MC/SC SUM :' + IntToStr(iSumOutfitAbil), 0);
{$ENDIF}

            if Random(100) < iProbability then begin
               condition := COND_SUCCESS;
            end else begin
               condition := COND_GEMFAIL;
            end;
         end else if iRequiredGuardStoneGrade = 2 then begin
            // 보옥 타입B 제조 확률 적용...
            // 2차 확률 없음.

{$IFDEF DEBUG}
            // test
            hum.SysMsg('BodyLuck:' + FloatToStr(hum.BodyLuck) +
               ' - PKPoint:' + FloatToStr(hum.PlayerKillingPoint) +
               ' = ' + FloatToStr(fTemporary) + ', iProbability:' + IntToStr(iProbability), 0);
{$ENDIF}

            if Random(100) < iProbability then begin
               condition := COND_SUCCESS;
            end else begin
               condition := COND_GEMFAIL;
            end;
         end;
      end;
   end;

{
   if condition = COND_GEMFAIL then begin
      // 보옥 제조 실패 로그
      MainOutMessage( '[Gem Manufacture Failure 보옥제조실패] ' + hum.UserName + ' ' + itemname + ' '
         + '=> Deleted Items(삭제된 재료):' + sNewName[0] + ', ' + sNewName[1]
         + ', ' + sNewName[2] + ', ' + sNewName[3]
         + ', ' + sNewName[4] + ', ' + sNewName[5] + ' '
         + 'BodyLuck:' + FloatToStr(hum.BodyLuck)
         + ' - PK Point:' + FloatToStr(hum.PlayerKillingPoint)
         + ' / 250 = ' + FloatToStr(fTemporary) + ', Prob.Manufacture Gem(보옥제조확률):' + IntToStr(iProbability) );
   end;
}

   if condition = COND_SUCCESS then begin
      // 제조 성공 로그 -> 축소
      MainOutMessage( '[Manufacture Success 제조성공] ' + hum.UserName + ' ' + itemname + '(' + IntToStr(iMakeCount) + '개)');
{
         + ' ' + '=> Deleted Items(삭제된 재료):' + sNewName[0] + ', ' + sNewName[1]
         + ', ' + sNewName[2] + ', ' + sNewName[3]
         + ', ' + sNewName[4] + ', ' + sNewName[5] + ' '
         + 'BodyLuck:' + FloatToStr(hum.BodyLuck)
         + ' - PK Point:' + FloatToStr(hum.PlayerKillingPoint)
         + ' / 250 = ' + FloatToStr(fTemporary) + ', Prob.Manufacture Gem(보옥제조확률):' + IntToStr(iProbability) );
}
   end;

   Result := condition;
end;

// 위탁상점
// Mode : 0 = 전체 , 1~13 종류별 , 100 = 셋트아이템 , 200 = 자가자신이 올린거
procedure TMerchant.SendUserMarket( hum : TuserHuman ; ItemType : integer ; UserMode : integer );
begin
    case UserMode of
    USERMARKET_MODE_BUY,    // 사는모드
    USERMARKET_MODE_INQUIRY:// 조회모드
        hum.RequireLoadUserMarket( ServerName+'_'+UserName , ItemType , Usermode , '','' );
    USERMARKET_MODE_SELL:   // 판매모드
        hum.SendUserMarketSellReady( self); // NPC 를 넘겨준다.
    end;
end;

procedure TMerchant.RunMsg (msg: TMessageInfo);
begin
   inherited RunMsg (msg);
end;

procedure TMerchant.Run;
var
   flag : integer;
   dwCurrentTick: longword;
   dwDelayTick: longword;
begin
   flag := 0;
   try
      //--------------------------------
      //Merchant 부하 분산 코드(sonmg 2005/02/01)
      dwCurrentTick := GetTickCount;
      dwDelayTick   := CreateIndex * 500;
      if dwCurrentTick < dwDelayTick then
         dwDelayTick := 0;
      //--------------------------------

      if dwCurrentTick - checkrefilltime > 5 * 60 * 1000 + dwDelayTick then begin
         checkrefilltime := dwCurrentTick - dwDelayTick;
         flag := 1;
         RefillGoods;
         flag := 2;
         // TEST_TIME
         if g_TestTime = 10 then mainOutMessage( 'RefillGoods:'+IntToStr(dwCurrentTick - checkrefilltime) );
      end;
      if dwCurrentTick - checkverifytime > 601 {10 * 60} * 1000 then begin
         checkverifytime := dwCurrentTick;
         flag := 3;
         VerifyUpgradeList;
         flag := 4;
         // TEST_TIME
         if g_TestTime = 11 then mainOutMessage( 'VerifyUpgradeList:'+IntToStr(dwCurrentTick - checkverifytime) );

      end;
      //if GetTickCount - specialrepairtime > 10 * 60 * 1000 then begin  //10분에 30번
      //   specialrepairtime := GetTickCount;
      //   Inc (specialrepair, 100);
      //end;
      if Random(50) = 0 then Turn (Random(8))
      else if Random(80) = 0 then
         SendRefMsg (RM_HIT, Dir, CX, CY, 0, '');

      if BoCastleManage and UserCastle.BoCastleUnderAttack then begin
         flag := 5;
         //전쟁중에 사북성안의 상점은 문을 닫는다.
         if not HideMode then begin
            SendRefMsg (RM_DISAPPEAR, 0, 0, 0, 0, '');
            HideMode := TRUE;
         end;
         flag := 6;
      end else begin
         if not BoHiddenNpc then begin
            //평상시
            if HideMode then begin
               HideMode := FALSE;
               SendRefMsg (RM_HIT, Dir, CX, CY, 0, '');
            end;
         end;
      end;

   except
      MainOutMessage ('[Exception] Merchant.Run (' + IntToStr(flag) + ') ' + MarketName + '-' + MapName);
   end;
   inherited Run;
end;

//장원꾸미기 아이템 목록 보내기
procedure TMerchant.SendDecoItemListShow (who: TCreature);
var
   i, count: integer;
   data: string;
begin
   data := '';
   count := 0;
   who.SendMsg (self, RM_DECOITEM_LISTSHOW, 0, integer(self), count, 0, data);
end;


{-----------------------------------------------------------------}


constructor TGuildOfficial.Create;
begin
   inherited Create;
   RaceImage := RCC_MERCHANT;  //상인
   Appearance := 8;
end;

destructor TGuildOfficial.Destroy;
begin
   inherited Destroy;
end;

procedure TGuildOfficial.UserCall (caller: TCreature);
begin
   NpcSayTitle (caller, '@main');
   //NpcSay (caller, SayString);
end;

function  TGuildOfficial.UserBuildGuildNow (hum: TUserHuman; gname: string): integer;
var
   i: integer;
   pu: PTUserItem;
begin
   Result := 0;
   //문파를 만들 자격이 있는지 검사
   //문파에 가입한 적이 없고
   //돈100만원, 우면귀왕의 뿔
   gname := Trim(gname);
   pu := nil;
   if gname = '' then Result := -4;
   if hum.MyGuild = nil then begin
      if hum.Gold >= BUILDGUILDFEE then begin
         pu := hum.FindItemName (__WomaHorn);
         if pu <> nil then begin
            ;//조건 성립
         end else Result := -3; //조건 아이템이 없음
      end else Result := -2; //돈이 부족
   end else Result := -1; //이미 문파에 가입되어 있음.

   //문파를 만든다.
   if Result = 0 then begin
      if GuildMan.AddGuild (gname, hum.UserName) then begin
         UserEngine.SendInterMsg (ISM_ADDGUILD, ServerIndex, gname + '/' + hum.UserName);
         hum.SendDelItem (pu^); //클라이언트에 보냄
         hum.DelItem (pu.MakeIndex, __WomaHorn);
         hum.DecGold (BUILDGUILDFEE);
         hum.GoldChanged;
         //문파정보를 다시 읽는다.
         hum.MyGuild := GuildMan.GetGuildFromMemberName (hum.UserName);
         if hum.MyGuild <> nil then begin  //길드에 가입되어 있는 경우
            hum.GuildRankName := TGuild (hum.MyGuild).MemberLogin (hum, hum.GuildRank);
            //hum.SendMsg (self, RM_CHANGEGUILDNAME, 0, 0, 0, 0, '');
         end;

         //-----------------------
         //명성치 획득(문파생성:+1000)
         if ENABLE_FAME_SYSTEM then begin
            hum.IncFamePoint( 1000 );
         end;
         //-----------------------
      end else
         Result := -4;
   end;

   case Result of
      0: hum.SendMsg (self, RM_BUILDGUILD_OK, 0, 0, 0, 0, '');
      else
         hum.SendMsg (self, RM_BUILDGUILD_FAIL, 0, Result, 0, 0, '');
   end;
end;

function  TGuildOfficial.UserDeclareGuildWarNow (hum: TUserHuman; gname: string): integer;
begin
   if GuildMan.GetGuild(gname) <> nil then begin
      if hum.Gold >= GUILDWARFEE then begin
         if hum.GuildDeclareWar (gname) = TRUE then begin
            hum.DecGold (GUILDWARFEE);
            hum.GoldChanged;
         end;
      end else begin
         {$IFDEF KOREA} hum.SysMsg ('돈이 부족합니다.', 0);
         {$ELSE}        hum.SysMsg ('Lack of Gold.', 0);
         {$ENDIF}
      end;
   end else begin
      {$IFDEF KOREA} hum.SysMsg (gname + ' 문파를 찾을 수 없습니다.', 0);
      {$ELSE}        hum.SysMsg (gname + ' Cannot find Guild.', 0);
      {$ENDIF}
   end;
   Result := 1;
end;

{
function TGuildOfficial.UserGuildMemberRecall (hum: TUserHuman; man: string): Boolean;
var
   recallhum: TUserHuman;
   nx, ny, dx, dy: integer;
begin
   Result := FALSE;

   if hum.IsGuildMaster then begin   //문주전용
      recallhum := UserEngine.GetUserHuman (man);
      if recallhum <> nil then begin
         if hum.MyGuild = recallhum.MyGuild then begin
            if GetFrontPosition (hum, nx, ny) then begin
               if hum.GetRecallPosition (nx, ny, 3, dx, dy) then begin
                  recallhum.SendRefMsg (RM_SPACEMOVE_HIDE, 0, 0, 0, 0, '');
                  recallhum.SpaceMove (MapName, dx, dy, 0); //공간이동
                  Result := TRUE;
               end;
            end else
               hum.SysMsg ('소환을 실패했습니다.', 0);
         end;
      end else
         hum.SysMsg (man + '님을 찾을 수 없습니다.', 0);
   end else begin
      hum.BoxMsg('문주만 사용할 수 있는 명령입니다.', 0);
   end;
end;
}

function  TGuildOfficial.UserFreeGuild (hum: TUserHuman): integer;
begin
   Result := 1;
end;

procedure TGuildOfficial.UserDonateGold (hum: TUserHuman);
begin
   hum.SendMsg (self, RM_DONATE_FAIL, 0, 0, 0, 0, '');
end;

procedure TGuildOfficial.UserRequestCastleWar (hum: TUserHuman);
var
   pu: PTUserItem;
begin
   if hum.IsGuildMaster and (not UserCastle.IsOurCastle (TGuild(hum.MyGuild))) then begin
      pu := hum.FindItemName (__ZumaPiece);
      if pu <> nil then begin
         if UserCastle.ProposeCastleWar (TGuild(hum.MyGuild)) then begin
            hum.SendDelItem (pu^); //클라이언트에 보냄
            hum.DelItem (pu.MakeIndex, __ZumaPiece);

            //로그 남김(주마왕의조각)(sonmg 2005/04/08)
            AddUserLog ('10'#9 + //판매_ +
                        hum.MapName + ''#9 +
                        IntToStr(hum.CX) + ''#9 +
                        IntToStr(hum.CY) + ''#9 +
                        hum.UserName + ''#9 +
                        __ZumaPiece + ''#9 +
                        '0' + ''#9 +
                        '1'#9 +
                        UserName);

            //-----------------------
            //명성치 획득(공성신청:+500)
            if ENABLE_FAME_SYSTEM then begin
               hum.IncFamePoint( 500 );
            end;
            //-----------------------

            NpcSayTitle (hum, '~@request_ok');
         end else begin
            //중복 신청됐거나, 현재 공성전 중인 경우
            {$IFDEF KOREA} hum.SysMsg ('지금은 신청할 수 없습니다.', 0);
            {$ELSE}        hum.SysMsg ('You can not request at the moment.', 0);
            {$ENDIF}
         end;
      end else begin
         {$IFDEF KOREA} hum.SysMsg ('당신은 주마왕의조각을 가지고 있지 않습니다.', 0);
         {$ELSE}        hum.SysMsg ('You have not a Piece of Zumataurus.', 0);
         {$ENDIF}
      end;
   end else begin
      //문파가 없거나, 성의 주인문파가 신청한 경우
      {$IFDEF KOREA} hum.SysMsg ('신청이 취소되었습니다.', 0);
      {$ELSE}        hum.SysMsg ('Your request cancelled.', 0);
      {$ENDIF}
   end;
   hum.SendMsg (self, RM_MENU_OK, 0, 0, 0, 0, '');
end;

procedure TGuildOfficial.UserSelect (whocret: TCreature; selstr: string);
var
   sel, body: string;
begin
   try
      if selstr <> '' then begin
         if selstr[1] = '@' then begin
            body := GetValidStr3 (selstr, sel, [#13]);

            NpcSayTitle (whocret, sel);

            if CompareText(sel, '@@buildguildnow') = 0 then begin
               UserBuildGuildNow (TUserHuman(whocret), body);
            end;
            if CompareText(sel, '@@guildwar') = 0 then begin
               UserDeclareGuildWarNow (TUserHuman(whocret), body);
            end;
            if CompareText(sel, '@@donate') = 0 then begin
               UserDonateGold (TUserHuman(whocret));
            end;
            if CompareText(sel, '@requestcastlewarnow') = 0 then begin
               UserRequestCastleWar (TUserHuman(whocret));
            end;

            if CompareText(sel, '@exit') = 0 then begin
               whocret.SendMsg (self, RM_MERCHANTDLGCLOSE, 0, integer(self), 0, 0, '');
            end;
         end;
      end;
   except
      MainOutMessage ('[Exception] TGuildOfficial.UserSelect... ');
   end;
end;

procedure TGuildOfficial.Run;
begin
   if Random(40) = 0 then Turn (Random(8))
   else if Random(30) = 0 then
      SendRefMsg (RM_HIT, Dir, CX, CY, 0, '');
   inherited Run;
end;


{-------------------------------------------------------}

constructor TTrainer.Create;
begin
   inherited Create;
   strucktime := GetTickCount;
   damagesum := 0;
   struckcount := 0;
end;

procedure TTrainer.RunMsg (msg: TMessageInfo);
var
   str: string;
begin
   case msg.Ident of
      RM_REFMESSAGE:
         begin
            if (Integer(msg.Sender) = RM_STRUCK) and (msg.wParam <> 0) then begin
               damagesum := damagesum + msg.wParam;
               strucktime := GetTickCount;
               Inc (struckcount);
               {$IFDEF KOREA} Say ('파괴력은 ' + IntToStr(msg.wParam) + ', 평균은 ' + IntToStr(damagesum div struckcount));
               {$ELSE}        Say ('Destructive power is ' + IntToStr(msg.wParam) + ', Average  is ' + IntToStr(damagesum div struckcount));
               {$ENDIF}
            end;
         end;
(*
      RM_STRUCK:
         begin
            if (msg.Sender = self) and (msg.lParam3 <> 0) then begin
               damagesum := damagesum + msg.wParam;
               strucktime := GetTickCount;
               Inc (struckcount);
               {$IFDEF KOREA} Say ('파괴력은 ' + IntToStr(msg.wParam) + ', 평균은 ' + IntToStr(damagesum div struckcount));
               {$ELSE}        Say ('Destructive power is ' + IntToStr(msg.wParam) + ', Average  is ' + IntToStr(damagesum div struckcount));
               {$ENDIF}
            end;
         end;
*)
      RM_MAGSTRUCK:
         begin
            if {(msg.Sender = self) and} (msg.lParam1 <> 0) then begin
                  damagesum := damagesum + msg.lParam1;
                  strucktime := GetTickCount;
                  Inc (struckcount);
                  {$IFDEF KOREA} Say ('파괴력은 ' + IntToStr(msg.lParam1) + ', 평균은 ' + IntToStr(damagesum div struckcount));
                  {$ELSE}        Say ('Destructive power is ' + IntToStr(msg.lParam1) + ', Average  is ' + IntToStr(damagesum div struckcount));
                  {$ENDIF}
            end;
         end;
   end;
end;

procedure TTrainer.Run;
begin
   if struckcount > 0 then begin
      if GetTickCount - strucktime > 3 * 1000 then begin
         {$IFDEF KOREA} Say ('총 파괴력은 ' + IntToStr(damagesum) + ' 평균 파괴력은 ' + IntToStr(damagesum div struckcount));
         {$ELSE}        Say ('Total destructive power is ' + IntToStr(damagesum) + ' Average destructive power is ' + IntToStr(damagesum div struckcount));
         {$ENDIF}
         struckcount := 0;
         damagesum := 0;
      end;
   end;
   inherited Run;
end;


//
// TCastleManager, (사북성에만 해당됨)
// 문원들에게만 클릭이 되게 하고, 성주에게만 돈 입금, 출금을
// 할 수 있게 한다.
//

constructor TCastleManager.Create;
begin
   inherited Create;
end;

procedure TCastleManager.CheckNpcSayCommand (hum: TUserHuman; var source: string; tag: string);
var
   str: string;
begin
   inherited CheckNpcSayCommand (hum, source, tag);
   if tag = '$CASTLEGOLD' then begin
      source := ChangeNpcSayTag (source, '<$CASTLEGOLD>', IntToStr(UserCastle.TotalGold));
   end;
   if tag = '$TODAYINCOME' then begin
      source := ChangeNpcSayTag (source, '<$TODAYINCOME>', IntToStr(UserCastle.TodayIncome));
   end;
   if tag = '$CASTLEDOORSTATE' then begin
      with TCastleDoor(UserCastle.MainDoor.UnitObj) do begin
         {$IFDEF KOREA}
            if Death then str := '파괴 되었습니다'
            else if BoOpenState then str := '열림'
            else str := '닫힘';
         {$ELSE}
            if Death then str := 'destroyed'
            else if BoOpenState then str := 'opened'
            else str := 'closed';
         {$ENDIF}
      end;
      source := ChangeNpcSayTag (source, '<$CASTLEDOORSTATE>', str);
   end;
   if tag = '$REPAIRDOORGOLD' then begin
      source := ChangeNpcSayTag (source, '<$REPAIRDOORGOLD>', IntToStr(CASTLEMAINDOORREPAREGOLD));
   end;
   if tag = '$REPAIRWALLGOLD' then begin
      source := ChangeNpcSayTag (source, '<$REPAIRWALLGOLD>', IntToStr(CASTLECOREWALLREPAREGOLD));
   end;
   if tag = '$GUARDFEE' then begin
      source := ChangeNpcSayTag (source, '<$GUARDFEE>', IntToStr(CASTLEGUARDEMPLOYFEE));
   end;
   if tag = '$ARCHERFEE' then begin
      source := ChangeNpcSayTag (source, '<$ARCHERFEE>', IntToStr(CASTLEARCHEREMPLOYFEE));
   end;

   if tag = '$GUARDRULE' then begin

   end;

end;

procedure TCastleManager.RepaireCastlesMainDoor (hum: TUserHuman);
begin
   if UserCastle.TotalGold >= CASTLEMAINDOORREPAREGOLD then begin
      if UserCastle.RepairCastleDoor then begin
         UserCastle.TotalGold := UserCastle.TotalGold - CASTLEMAINDOORREPAREGOLD;
         {$IFDEF KOREA} hum.SysMsg ('수리되었습니다.', 1);
         {$ELSE}        hum.SysMsg ('repaired.', 1);
         {$ENDIF}
      end else begin
         {$IFDEF KOREA} hum.SysMsg ('지금은 수리할 수 없습니다.', 0);
         {$ELSE}        hum.SysMsg ('You cannot repair it now.', 0);
         {$ENDIF}
      end;
   end else begin
      {$IFDEF KOREA} hum.SysMsg ('성의 자금이 부족합니다.', 0);
      {$ELSE}        hum.SysMsg ('Fund of wall is not sufficient.', 0);
      {$ENDIF}
   end;
end;

procedure TCastleManager.RepaireCoreCastleWall (wall: integer; hum: TUserHuman);
var
   n: integer;
begin
   if UserCastle.TotalGold >= CASTLECOREWALLREPAREGOLD then begin
      n := UserCastle.RepairCoreCastleWall (wall);
      if n = 1 then begin
         UserCastle.TotalGold := UserCastle.TotalGold - CASTLECOREWALLREPAREGOLD;
         {$IFDEF KOREA} hum.SysMsg ('수리되었습니다.', 1);
         {$ELSE}        hum.SysMsg ('repaired.', 1);
         {$ENDIF}
      end else begin
         {$IFDEF KOREA} hum.SysMsg ('지금은 수리할 수 없습니다.', 0);
         {$ELSE}        hum.SysMsg ('You cannot repair it now.', 0);
         {$ENDIF}
      end;
   end else begin
      {$IFDEF KOREA} hum.SysMsg ('성의 자금이 부족합니다.', 0);
      {$ELSE}        hum.SysMsg ('Fund of wall is not sufficient.', 0);
      {$ENDIF}
   end;
end;

procedure TCastleManager.HireCastleGuard (numstr: string; hum: TUserHuman);
var
   gnum, mrace: integer;
begin
   if UserCastle.TotalGold >= CASTLEGUARDEMPLOYFEE then begin
      gnum := Str_ToInt(numstr, 0) - 1;
      if gnum in [0..MAXGUARD-1] then begin
         if UserCastle.Guards[gnum].UnitObj = nil then begin
            if not UserCastle.BoCastleUnderAttack then begin
               with UserCastle.Guards[gnum] do begin
                  UnitObj := UserEngine.AddCreatureSysop (
                                             UserCastle.CastleMapName,
                                             X,
                                             Y,
                                             UnitName);
                  if UnitObj <> nil then begin
                     UserCastle.TotalGold := UserCastle.TotalGold - CASTLEGUARDEMPLOYFEE;
                     //TGuardUnit(UnitObj).OriginX := X;
                     //TGuardUnit(UnitObj).OriginY := Y;
                     //TGuardUnit(UnitObj).OriginDir := 3;
                     {$IFDEF KOREA} hum.SysMsg ('경비병을 고용하였습니다.', 1);
                     {$ELSE}        hum.SysMsg ('hired guard.', 1);
                     {$ENDIF}
                  end;
               end;
            end else begin
               {$IFDEF KOREA} hum.SysMsg ('지금은 고용할 수 없습니다.', 0);
               {$ELSE}        hum.SysMsg ('You cannot hire it right now.', 0);
               {$ENDIF}
            end;
         end else begin
            if not UserCastle.Guards[gnum].UnitObj.Death then begin
               {$IFDEF KOREA} hum.SysMsg ('이미 그 자리에 경비병이 있습니다.', 0);
               {$ELSE}        hum.SysMsg ('Guard already exists in that place.', 0);
               {$ENDIF}
            end else begin
               {$IFDEF KOREA} hum.SysMsg ('지금은 고용할 수 없습니다.', 0);
               {$ELSE}        hum.SysMsg ('You cannot hire it right now.', 0);
               {$ENDIF}
            end;
         end;
      end else begin
         {$IFDEF KOREA} hum.SysMsg ('잘못된 명령입니다.', 0);
         {$ELSE}        hum.SysMsg ('Wrong command.', 0);
         {$ENDIF}
      end;
   end else begin
      {$IFDEF KOREA} hum.SysMsg ('성의 자금이 부족합니다.', 0);
      {$ELSE}        hum.SysMsg ('Fund of wall is not sufficient.', 0);
      {$ENDIF}
   end;
end;

procedure TCastleManager.HireCastleArcher (numstr: string; hum: TUserHuman);
var
   gnum, mrace: integer;
begin
   if UserCastle.TotalGold >= CASTLEARCHEREMPLOYFEE then begin
      gnum := Str_ToInt(numstr, 0) - 1;
      if gnum in [0..MAXARCHER-1] then begin
         if UserCastle.Archers[gnum].UnitObj = nil then begin
            if not UserCastle.BoCastleUnderAttack then begin
               with UserCastle.Archers[gnum] do begin
                  UnitObj := UserEngine.AddCreatureSysop (
                                             UserCastle.CastleMapName,
                                             X,
                                             Y,
                                             UnitName);
                  if UnitObj <> nil then begin
                     UserCastle.TotalGold := UserCastle.TotalGold - CASTLEARCHEREMPLOYFEE;
                     TGuardUnit(UnitObj).Castle := UserCastle;
                     TGuardUnit(UnitObj).OriginX := X;
                     TGuardUnit(UnitObj).OriginY := Y;
                     TGuardUnit(UnitObj).OriginDir := 3;
                     {$IFDEF KOREA} hum.SysMsg ('궁병을 고용하였습니다.', 1);
                     {$ELSE}        hum.SysMsg ('You hired archer.', 1);
                     {$ENDIF}
                  end;
               end;
            end else begin
               {$IFDEF KOREA} hum.SysMsg ('지금은 고용할 수 없습니다.', 0);
               {$ELSE}        hum.SysMsg ('You cannot hire it right now.', 0);
               {$ENDIF}
            end;
         end else begin
            if not UserCastle.Archers[gnum].UnitObj.Death then begin
               {$IFDEF KOREA} hum.SysMsg ('이미 그 자리에 경비병이 있습니다.', 0);
               {$ELSE}        hum.SysMsg ('Guard already exists in that place.', 0);
               {$ENDIF}
            end else begin
               {$IFDEF KOREA} hum.SysMsg ('지금은 고용할 수 없습니다.', 0);
               {$ELSE}        hum.SysMsg ('You cannot hire it right now.', 0);
               {$ENDIF}
            end;
         end;
      end else begin
         {$IFDEF KOREA} hum.SysMsg ('잘못된 명령입니다.', 0);
         {$ELSE}        hum.SysMsg ('Wrong command.', 0);
         {$ENDIF}
      end;
   end else begin
      {$IFDEF KOREA} hum.SysMsg ('성의 자금이 부족합니다.', 0);
      {$ELSE}        hum.SysMsg ('Fund of wall is not sufficient.', 0);
      {$ENDIF}
   end;
end;



procedure TCastleManager.UserCall (caller: TCreature);
begin
   if UserCastle.IsOurCastle (TGuild(caller.MyGuild)) then begin
      inherited UserCall (caller);
   end;
end;

procedure TCastleManager.UserSelect (whocret: TCreature; selstr: string);
var
   body, sel, rmsg: string;
begin
   try
      if selstr <> '' then begin
         if selstr[1] = '@' then begin
            body := GetValidStr3 (selstr, sel, [#13]);
            rmsg := '';
            while TRUE do begin
               whocret.LatestNpcCmd := selstr;

               NpcSayTitle (whocret, sel);

               //사북성에서의 문주명령
               if UserCastle.IsOurCastle(TGuild(whocret.MyGuild)) and (whocret.IsGuildMaster) then begin
                  if CompareText(sel, '@@withdrawal') = 0 then begin
                     case UserCastle.GetBackCastleGold (TUserHuman(whocret), abs(Str_ToInt(body,0))) of
                        -1:
                           begin
                              {$IFDEF KOREA} rmsg := UserCastle.OwnerGuildName + '의 문주만 사용할 수 있습니다.';
                              {$ELSE}                  rmsg := 'It is available only for Guild chief of ' + UserCastle.OwnerGuildName;
                              {$ENDIF}
                           end;
                        -2:
                           begin
                              {$IFDEF KOREA} rmsg := '성안에 그만큼의 돈이 없습니다.';
                              {$ELSE}                  rmsg := 'That amount of Gold is not in this wall.';
                              {$ENDIF}
                           end;
                        -3:
                           begin
                              {$IFDEF KOREA} rmsg := '당신은 더 이상 들 수 없습니다.';
                              {$ELSE}                  rmsg := 'You cannot carry any more.';
                              {$ENDIF}
                           end;
                        1: UserSelect (whocret, '@main');
                     end;
                     whocret.SendMsg (self, RM_MENU_OK, 0, integer(self), 0, 0, rmsg);
                     break;
                  end;
                  if CompareText(sel, '@@receipts') = 0 then begin
                     case UserCastle.TakeInCastleGold (TUserHuman(whocret), abs(Str_ToInt(body,0))) of
                        -1:
                           begin
                              {$IFDEF KOREA} rmsg := UserCastle.OwnerGuildName + '의 문주만 사용할 수 있습니다.';
                              {$ELSE}                  rmsg := 'It is available only for Guild chief of ' + UserCastle.OwnerGuildName;
                              {$ENDIF}
                           end;
                        -2:
                           begin
                              {$IFDEF KOREA} rmsg := '당신은 그만큼의 돈이 없습니다.';
                              {$ELSE}                  rmsg := 'You have not Gold of that amount.';
                              {$ENDIF}
                           end;
                        -3:
                           begin
                              {$IFDEF KOREA} rmsg := '성안에 보관할 수 있는 금액을 초과합니다.';
                              {$ELSE}                  rmsg := 'It exceeds the limit of custody to the wall.';
                              {$ENDIF}
                           end;
                        1: UserSelect (whocret, '@main');
                     end;
                     whocret.SendMsg (self, RM_MENU_OK, 0, integer(self), 0, 0, rmsg);
                     break;
                  end;
                  if CompareText(sel, '@openmaindoor') = 0 then begin
                     UserCastle.ActivateMainDoor (FALSE);
                     break;
                  end;
                  if CompareText(sel, '@closemaindoor') = 0 then begin
                     UserCastle.ActivateMainDoor (TRUE);
                     break;
                  end;
                  if CompareText(sel, '@repairdoornow') = 0 then begin
                     RepaireCastlesMainDoor (TUserHuman(whocret));
                     UserSelect (whocret, '@main');
                     break;
                  end;
                  if CompareText(sel, '@repairwallnow1') = 0 then begin
                     RepaireCoreCastleWall (1, TUserHuman(whocret));
                     UserSelect (whocret, '@main');
                     break;
                  end;
                  if CompareText(sel, '@repairwallnow2') = 0 then begin
                     RepaireCoreCastleWall (2, TUserHuman(whocret));
                     UserSelect (whocret, '@main');
                     break;
                  end;
                  if CompareText(sel, '@repairwallnow3') = 0 then begin
                     RepaireCoreCastleWall (3, TUserHuman(whocret));
                     UserSelect (whocret, '@main');
                     break;
                  end;

                  if CompareLStr(sel, '@hireguardnow', 13) then begin
                     HireCastleGuard (Copy(sel,14,Length(sel)), TUserHuman(whocret));
                     UserSelect (whocret, '@hireguards');
                  end;

                  if CompareLStr(sel, '@hirearchernow', 14) then begin
                     HireCastleArcher (Copy(sel,15,Length(sel)), TUserHuman(whocret));
                     //UserSelect (whocret, '@hirearchers');
                     whocret.SendMsg (self, RM_MENU_OK, 0, integer(self), 0, 0, '');
                  end;

                  if CompareText(sel, '@exit') = 0 then begin
                     whocret.SendMsg (self, RM_MERCHANTDLGCLOSE, 0, integer(self), 0, 0, '');
                     break;
                  end;
               end else begin
                  {$IFDEF KOREA}
                     whocret.SendMsg (self, RM_MENU_OK, 0, integer(self), 0, 0, '당신에게는 권한이 없습니다.');
                  {$ELSE}
                     whocret.SendMsg (self, RM_MENU_OK, 0, integer(self), 0, 0, 'You have no right.');
                  {$ENDIF}
               end;

               break;
            end;
         end;
      end;
   except
      MainOutMessage ('[Exception] TMerchant.UserSelect... ');
   end;
end;


{---------------------------HiddenNpc-----------------------------}

constructor THiddenNpc.Create;
begin
   inherited Create;
   RunDone := FALSE;
   ViewRange := 7;
   RunNextTick := 250;
   SearchRate := 2500 + longword(Random(1500));
   SearchTime := GetTickCount;
   DigupRange := 4;
   DigdownRange := 4;
   HideMode := TRUE;
   StickMode := TRUE;
   BoHiddenNpc := TRUE;
end;

destructor THiddenNpc.Destroy;
begin
   inherited destroy;
end;

procedure THiddenNpc.ComeOut;
begin
   HideMode := FALSE;
//   SendRefMsg (RM_DIGUP, Dir, CX, CY, 0, '');
   SendRefMsg (RM_HIT, Dir, CX, CY, 0, '');
end;

procedure THiddenNpc.ComeDown;
var
   i: integer;
begin
//   SendRefMsg (RM_DIGDOWN, {Dir}0, CX, CY, 0, '');
   SendRefMsg (RM_DISAPPEAR, 0, 0, 0, 0, '');
   try
      for i:=0 to VisibleActors.Count-1 do
         Dispose (PTVisibleActor(VisibleActors[i]));
      VisibleActors.Clear;
   except
      MainOutMessage ('[Exception] THiddenNpc VisbleActors Dispose(..)');
   end;
   HideMode := TRUE;
end;

procedure THiddenNpc.CheckComeOut;
var
   i: integer;
   cret: TCreature;
begin
   for i:=0 to VisibleActors.Count-1 do begin
      cret := TCreature (PTVisibleActor(VisibleActors[i]).cret);
      if (not cret.Death) and (IsProperTarget(cret)) and (not cret.BoHumHideMode or BoViewFixedHide) then begin
         if (abs(CX-cret.CX) <= DigupRange) and (abs(CY-cret.CY) <= DigupRange) then begin
            ComeOut; //밖으로 나오다. 보인다.
            break;
         end;
      end;
   end;
end;

procedure THiddenNpc.RunMsg (msg: TMessageInfo);
begin
   inherited RunMsg (msg);
end;

procedure THiddenNpc.Run;
var
   boidle: Boolean;
   nearcret : TCreature;
begin
   nearcret := nil;
   
//   if (not BoGhost) and (not Death) and
//      (StatusArr[POISON_STONE] = 0) and (StatusArr[POISON_ICE] = 0) and
//      (StatusArr[POISON_STUN] = 0) then begin
   if IsMoveAble then begin
      if GetCurrentTime - WalkTime > GetNextWalkTime then begin
         WalkTime := GetCurrentTime;
         if HideMode then begin //아직 모습을 나타내지 않았음.
            CheckComeOut;
         end else begin
            if GetCurrentTime - HitTime > GetNextHitTime then begin //상속받은 run 에서 HitTime 재설정함.
//               HitTime := GetTickCount; //아래 AttackTarget에서 함.
               nearcret := GetNearMonster;
            end;

            boidle := FALSE;
            if nearcret <> nil then begin
               if (abs(nearcret.CX-CX) > DigdownRange) or (abs(nearcret.CY-CY) > DigdownRange) then
                  boidle := TRUE;
            end else boidle := TRUE;

            if boidle then begin
               ComeDown; //다시 들어간다.
            end;
         end;
      end;
   end;

   inherited Run;
end;

end.


