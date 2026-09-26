unit UsrEngn;

interface

uses
  Windows, Messages, SysUtils, Classes, Graphics, Controls, Dialogs,
  ScktComp, syncobjs, MudUtil, HUtil32, ObjBase, Grobal2, EdCode,
  Envir, ObjMon, ObjMon2, objMon3, ObjAxeMon, ObjNpc, ObjGuard, M2Share, RunDB,
  Guild, Mission, MFdbDef, InterServerMsg, InterMsgClient, Event,
  UserMgr , CmdMgr;

type
   TRefillCretInfo = record
      x:    integer;
      y:    integer;
      size:  byte;
      count: byte;
      race:  byte;
   end;
   PTRefillCretInfo = ^TRefillCretInfo;


   TUserEngine = class
   private
      ReadyList: TStringList; //동기화 필요
      RunUserList: TStringList;
      OtherUserNameList: TStringList;  //다른 서버에 있는 사용자 리스트
      ClosePlayers: TList;
      SaveChangeOkList: TList;
      FUserCS : TCriticalSection;

      timer10min: longword;
      timer10sec: longword;
      timer1min : longword;
      opendoorcheck: longword;
      missiontime: longword;  //미션은 1초에 한번 틱이 된다.
      onezentime: longword;  //젠을 조금씩 한다.
      runonetime: longword;
      hum200time: longword;
      usermgrcheck: longword;

      eventitemtime: longword;  //유니크 아이템 이벤트의 변수

      GenCur: integer;
      MonCur, MonSubCur: integer;
      HumCur, HumRotCount: integer;
      MerCur: integer;
      NpcCur: integer;

      gaCount: integer;
      gaDecoItemCount: integer;

      procedure LoadRefillCretInfos;
      procedure SendRefMsgEx (envir: TEnvirnoment; x, y: integer; msg, wparam: Word; lParam1, lParam2, lParam3: Longint; str: string);
      procedure CheckOpenDoors;
   protected
      procedure ProcessUserHumans;
      procedure ProcessMonsters;
      procedure ProcessMerchants;
      procedure ProcessNpcs;
      procedure ProcessMissions;
      procedure ProcessDragon;
   public
      // 2003/06/20 이벤트몹 젠 메세지 리스트
      GenMsgList : TStringList;
      StdItemList: TList;
      MonDefList: TList;
      MonList: TList;
      DefMagicList: TList;
      AdminList: TStringList;
      // 2003/08/28
      ChatLogList: TStringList;
      MerchantList: TList;
      NpcList: TList;
      MissionList: TList;  //미션...
      WaitServerList: TList;
      HolySeizeList: TList; //결계의 리스트

      MonCount, MonCurCount, MonRunCount, MonCurRunCount: integer;
      BoUniqueItemEvent: Boolean;
      UniqueItemEventInterval: integer;
      // 2003/03/18 테스트 서버 인원 제한
      FreeUserCount: integer;

      constructor Create;
      destructor Destroy; override;
      procedure Initialize;
      procedure ExecuteRun;
      procedure ProcessUserMessage (hum: TUserHuman; pmsg: PTDefaultMessage; pbody: PChar);
      procedure ExternSendMessage( UserName : String ; Ident, wparam: Word; lParam1, lParam2, lParam3: Longint; str: string);
      //StdItem
      function  GetStdItemName (itemindex: integer): string;
      function  GetStdItemIndex (itmname: string): integer;
      function  GetStdItemWeight (itemindex: integer): integer;
      function  GetStdItem (index: integer): PTStdItem;
      function  GetStdItemFromName (itmname: string): PTStdItem;
      function  CopyToUserItem (itmindex: integer; var uitem: TUserItem): Boolean;
      function  CopyToUserItemFromName (itmname: string; var uitem: TUserItem): Boolean;
      function  GetStdItemNameByShape (stdmode, shape: integer): string;
      //DefMagic
      function  GetDefMagic (magname: string): PTDefMagic;
      function  GetDefMagicFromID (Id: integer): PTDefMagic;
      //User
      procedure AddNewUser (ui: PTUserOpenInfo); //싱크맞워야함
      procedure ClosePlayer (hum: TUserHuman);
      procedure SavePlayer (hum: TUserHuman);
      procedure ChangeAndSaveOk (pc: PTChangeUserInfo);
      function  GetMyDegree (uname: string): integer;
      function  GetUserHuman (who: string): TUserHuman;
      function  FindOtherServerUser (who: string; var svindex: integer): Boolean;  //다른서버에 접속하고 있는지
      function  GetUserCount: integer;
      function  GetRealUserCount: integer;
      function  GetAreaUserCount (env: TEnvirnoment; x, y, wide: integer): integer;
      function  GetAreaUsers (env: TEnvirnoment; x, y, wide: integer; ulist: TList): integer;
      function  GetAreaAllUsers (env: TEnvirnoment; ulist: TList): integer;
      function  GetHumCount (mapname: string): integer;
      procedure CryCry (msgtype: integer; env: TEnvirnoment; x, y, wide: integer; saying: string);
      // 문주 장원내 공지(sonmg)
      procedure GuildAgitCry (msgtype: integer; env: TEnvirnoment; x, y, wide: integer; saying: string);
      procedure SysMsgAll (saying: string);
      procedure KickDoubleConnect (uname: string);
      procedure GuildMemberReLogin (guild: TGuild);

      function  AddServerWaitUser (psui: PTServerShiftUserInfo): Boolean;
      function  GetServerShiftInfo (uname: string; certify: integer): PTServerShiftUserInfo;
      procedure MakeServerShiftData (hum: TUserHuman; var sui: TServerShiftUserInfo);
      procedure LoadServerShiftData (psui: PTServerShiftUserInfo; var hum: TUserHuman);
      procedure ClearServerShiftData (psui: PTServerShiftUserInfo);
      function  WriteShiftUserData (psui: PTServerShiftUserInfo): string;
      procedure SendInterServerMsg (msgstr: string);
      procedure SendInterMsg (ident, svidx: integer; msgstr: string);
      function  UserServerChange (hum: TUserHuman; svindex: integer): Boolean;
      // 2003/06/12 슬레이브 패치
      procedure GetISMChangeServerReceive (flname: string);
      function  DoUserChangeServer (hum: TUserHuman; svindex: integer): Boolean;
      procedure CheckServerWaitTimeOut;
      procedure CheckHolySeizeValid;
      procedure OtherServerUserLogon (snum: integer; uname: string);
      procedure OtherServerUserLogout (snum: integer; uname: string);
      procedure AccountExpired (uid: string);
      function  TimeAccountExpired( uid :string ):boolean;
      function  ApplyPremiumUser( iGrade: integer; uid, uname, sBirthday :string ):Boolean;
      function  ApplyEventUser( uid, uname :string ):Boolean;

      //Monster, NPC
      function  GetMonRace (monname: string): integer;
      function  GetMonLevel (monname: string): integer;
      procedure ApplyMonsterAbility (cret: TCreature; monname: string);
      procedure RandomUpgradeItem (pu: PTUserItem);
      procedure RandomSetUnknownItem (pu: PTUserItem);
      function  GetUniqueEvnetItemName (var iname: string; var numb: integer): Boolean;
      procedure ReloadAllMonsterItems;
      function  MonGetRandomItems (mon: TCreature): integer;
      function  AddCreature (map: string; x, y, race: integer; monname: string): TCreature;
      function  AddCreatureSysop (map: string; x, y: integer; monname: string): TCreature;
      function  RegenMonsters (pz: PTZenInfo; zcount: integer): Boolean;
      function  GetMonCount (pz: PTZenInfo): integer;
      function  GetGenCount (mapname: string): integer; //맵에 몇마리가 젠되었는지
      function  GetMapMons (penvir: TEnvirnoment; list: TList): integer;
      function  GetMapMonsNoRecallMob (penvir: TEnvirnoment; list: TList): integer;
      //Merchant
      function  GetMerchant (npcid: integer): TCreature;  //npcid는 TCreature임.
      function  GetMerchantXY (envir: TEnvirnoment; x, y, wide: integer; npclist: TList): integer;
      procedure InitializeMerchants;
      function  GetNpc (npcid: integer): TCreature;
      function  GetNpcXY (envir: TEnvirnoment; x, y, wide: integer; list: TList): integer;
      procedure InitializeNpcs;
      //sys
      function  OpenDoor (envir: TEnvirnoment; dx, dy: integer): Boolean;
      function  CloseDoor(envir: TEnvirnoment; pd: PTDoorInfo): Boolean;
      //미션
      function  LoadMission (flname: string): Boolean;  //미션 파일을 읽어서 미션을 확성화 시킴
      function  StopMission (missionname: string): Boolean; //미션을 종료한다. 자동 종료된다.
      //시작위치
      procedure GetRandomDefStart (var map: string; var sx, sy: integer; job: byte);
      // 채팅로그
      function  FindChatLogList( whostr : string ; var idx : integer ):boolean;
      // 맵에 아이템 젠 시키기(sonmg)
      function MakeItemToMap( DropMapName : string ; ItemName: String; Amount :integer; dx, dy:integer ):integer;
   end;

implementation

uses
   svMain, FrnEngn, IdSrvClient, LocalDB;

{ TUserEngine }

constructor TUserEngine.Create;
begin
   RunUserList := TStringList.Create;
   OtherUserNameList := TStringList.Create;
   ClosePlayers := TList.Create;
   SaveChangeOkList := TList.Create;

   // 2003/06/20 이벤트몹 젠 메세지 리스트
   GenMsgList := TStringList.Create;
   MonList := TList.Create;
   MonDefList := TList.Create;
   ReadyList := TStringList.Create; //동기화  필요
   StdItemList := TList.Create;  //Index가 TUserItem에서 리퍼런스 하므로 순서가 변경되어서는 안된다.
   DefMagicList := TList.Create;
   AdminList := TStringList.Create;
   ChatLogList := TStringList.Create;
   MerchantList := TList.Create;
   NpcList := TList.Create;
   MissionList := TList.Create;
   WaitServerList := TList.Create;
   HolySeizeList := TList.Create;

   timer10min := GetTickCount;
   timer10sec := GetTickCount;
   timer1min := GetTickCount;
   opendoorcheck := GetTickCount;
   missiontime := GetTickCount;
   onezentime := GetTickCount;
   hum200time := GetTickCount;
   usermgrcheck := GetTickCount;

   GenCur := 0;
   MonCur := 0;
   MonSubCur := 0;
   HumCur := 0;
   HumRotCount := 0;
   MerCur := 0;
   NpcCur := 0;
   // 2003/03/18 테스트 서버 인원 제한
   FreeUserCount := 0;

   gaCount := 0;
   gaDecoItemCount := 0;

   BoUniqueItemEvent := FALSE;
   UniqueItemEventInterval := 30 * 60 * 1000;
   eventitemtime := GetTickCount;

   FUserCS := TCriticalSection.Create;
   inherited Create;
end;

destructor TUserEngine.Destroy;
var
   i: integer;
begin
   for i:=0 to RunUserList.Count-1 do
      TUserHuman (RunUserList.Objects[i]).Free;
   RunUserList.Free;
   OtherUserNameList.Free;
   ClosePlayers.Free;
   SaveChangeOkList.Free;
   // 2003/06/20 이벤트몹 젠 메세지 리스트
   GenMsgList.Free;

   for i:=0 to MonList.Count-1 do
      Dispose (PTZenInfo (MonList[i]));
   MonList.Free;
   MonDefList.Free;
   for i:=0 to DefMagicList.Count-1 do
      Dispose (PTDefMagic (DefMagicList[i]));
   DefMagicList.Free;
   ReadyList.Free;
   for i:=0 to StdItemList.Count-1 do
      Dispose (PTStdItem(StdItemList[i]));
   StdItemList.Free;

   ChatLogList.Free;
   AdminList.Free;
   MerchantList.Free;
   NpcList.Free;
   MissionList.Free;
   WaitServerList.Free;
   HolySeizeList.Free;

   FUserCS.Free;
   inherited Destroy;
end;

{-------------------- StdItemList ----------------------}

//다른 스래드에서 사용 불가 !!
function  TUserEngine.GetStdItemName (itemindex: integer): string;
begin
   itemindex := itemindex - 1; //TUserItem의 Index는 +1된 것임.  0은 빈것으로 간주함.
   if (itemindex >= 0) and (itemindex <= StdItemList.Count-1) then
      Result := PTStdItem (StdItemList[itemindex]).Name
   else Result := '';
end;

//다른 스래드에서 사용 불가 !!
function  TUserEngine.GetStdItemIndex (itmname: string): integer;
var
   i: integer;
begin
   Result := -1;
   if itmname = '' then exit;
   for i:=0 to StdItemList.Count-1 do begin
      if CompareText(PTStdItem(StdItemList[i]).Name, itmname) = 0 then begin
         Result := i + 1;
         break;
      end;
   end;
end;

//다른 스래드에서 사용 불가 !!
function  TUserEngine.GetStdItemWeight (itemindex: integer): integer;
begin
   itemindex := itemindex - 1; //TUserItem의 Index는 +1된 것임.  0은 빈것으로 간주함.
   if (itemindex >= 0) and (itemindex <= StdItemList.Count-1) then
      Result := PTStdItem (StdItemList[itemindex]).Weight
   else Result := 0;
end;

//다른 스래드에서 사용 불가 !!
function  TUserEngine.GetStdItem (index: integer): PTStdItem;
begin
   index := index - 1;
   if (index >= 0) and (index < StdItemList.Count) then begin
      Result := PTStdItem(StdItemList[index]); //이름이 없는 아이템은 사라진 아이템
      if Result.Name = '' then Result := nil;
   end else Result := nil;
end;

//다른 스래드에서 사용 불가 !!
function  TUserEngine.GetStdItemFromName (itmname: string): PTStdItem;
var
   i: integer;
begin
   Result := nil;
   if itmname = '' then exit;
   for i:=0 to StdItemList.Count-1 do begin
      if CompareText (PTStdItem(StdItemList[i]).Name, itmname) = 0 then begin
         Result := PTStdItem(StdItemList[i]);
         break;
      end;
   end;
end;

//다른 스래드에서 사용 불가 !!
function  TUserEngine.CopyToUserItem (itmindex: integer; var uitem: TUserItem): Boolean;
begin
   Result := FALSE;
   itmindex := itmindex - 1;
   if (itmindex >= 0) and (itmindex < StdItemList.Count) then begin
      uitem.Index := itmindex + 1;  //Index=0은 빈것으로 인식
      uitem.MakeIndex := GetItemServerIndex;
      uitem.Dura := PTStdItem(StdItemList[itmindex]).DuraMax;
      uitem.DuraMax := PTStdItem(StdItemList[itmindex]).DuraMax;
      Result := TRUE;
   end;
end;

//다른 스래드에서 사용 불가 !!
function  TUserEngine.CopyToUserItemFromName (itmname: string; var uitem: TUserItem): Boolean;
var
   i: integer;
begin
   Result := FALSE;
   if itmname = '' then exit;
   for i:=0 to StdItemList.Count-1 do begin
      if CompareText (PTStdItem(StdItemList[i]).Name, itmname) = 0 then begin
         FillChar(uitem, sizeof(TUserItem), #0);
         uitem.Index := i + 1;  //Index=0은 빈것으로 인식
         uitem.MakeIndex := GetItemServerIndex;  //새 MakeIndex 발급

         // 카운트아이템 개수 0개 버그 수정(sonmg 2004/02/17)
         if PTStdItem(StdItemList[i]).OverlapItem >= 1 then begin
            if PTStdItem(StdItemList[i]).DuraMax = 0 then
               uitem.Dura := 1
            else
               uitem.Dura := PTStdItem(StdItemList[i]).DuraMax;
         end else begin
            uitem.Dura := PTStdItem(StdItemList[i]).DuraMax;
         end;

         uitem.DuraMax := PTStdItem(StdItemList[i]).DuraMax;
         Result := TRUE;
         break;
      end;
   end;
end;

//다른 스래드에서 사용 불가 !!(2004/03/16)
function  TUserEngine.GetStdItemNameByShape (stdmode, shape: integer): string;
var
   i: integer;
   pstd: PTStdItem;
begin
   Result := '';
   for i:=0 to StdItemList.Count-1 do begin
      pstd := PTStdItem(StdItemList[i]);
      if pstd <> nil then begin
         if (pstd.StdMode = stdmode) and (pstd.Shape = shape) then begin
            Result := pstd.Name;
            break;
         end;
      end;
   end;
end;

{-------------------- Background and system ----------------------}

procedure  TUserEngine.SendRefMsgEx (envir: TEnvirnoment; x, y: integer; msg, wparam: Word; lParam1, lParam2, lParam3: Longint; str: string);
var
	i, j, k, stx, sty, enx, eny: integer;
   cret: TCreature;
   pm: PTMapInfo;
   inrange: Boolean;
begin
   stx := x-12;
   enx := x+12;
   sty := y-12;
   eny := y+12;
   for i:=stx to enx do
      for j:=sty to eny do begin
         inrange := envir.GetMapXY (i, j, pm);
         if inrange then
            if pm.ObjList <> nil then
               for k:=0 to pm.ObjList.Count-1 do begin
                  //creature//
                  if pm.ObjList[k] <> nil then begin
                     if PTAThing (pm.ObjList[k]).Shape = OS_MOVINGOBJECT then begin
                        cret := TCreature (PTAThing (pm.ObjList[k]).AObject);
                        if cret <> nil then
                           if (not cret.BoGhost) then begin
                              if cret.RaceServer = RC_USERHUMAN then
                                 cret.SendMsg (cret, msg, wparam, lparam1, lparam2, lparam3, str);
                           end;
                     end;
                  end;
               end;
      end;
end;

function  TUserEngine.OpenDoor (envir: TEnvirnoment; dx, dy: integer): Boolean;
var
   pd: PTDoorInfo;
begin
   Result := FALSE;
   pd := envir.FindDoor (dx, dy);
   if pd <> nil then begin
      if (not pd.pCore.DoorOpenState) and (not pd.pCore.Lock) then begin //이미 열려 있거나, 잠겨있지않으면.
         pd.pCore.DoorOpenState := TRUE;
         pd.pCore.OpenTime := GetTickCount;
         SendRefMsgEx (envir, dx, dy, RM_OPENDOOR_OK, 0, dx, dy, 0, '');
         Result := TRUE;
      end;
   end;
end;

function  TUserEngine.CloseDoor (envir: TEnvirnoment; pd: PTDoorInfo): Boolean;
begin
   Result := FALSE;
   if pd <> nil then begin
      if pd.pCore.DoorOpenState then begin
         pd.pCore.DoorOpenState := FALSE;
         SendRefMsgEx (envir, pd.DoorX, pd.DoorY, RM_CLOSEDOOR, 0, pd.DoorX, pd.DoorY, 0, '');
         Result := TRUE;
      end;
   end;
end;

procedure TUserEngine.CheckOpenDoors;
var
   k, i: integer;
   pd: PTDoorInfo;
   e: TEnvirnoment;
begin
  try

   for k:=0 to GrobalEnvir.Count-1 do begin
      for i:=0 to TEnvirnoment(GrobalEnvir[k]).DoorList.Count-1 do begin
         e := TEnvirnoment(GrobalEnvir[k]);
         if PTDoorInfo(e.DoorList[i]).pCore.DoorOpenState then begin
            pd := PTDoorInfo(e.DoorList[i]);
            if GetTickCount - pd.pCore.OpenTime > 5000 then
               CloseDoor (e, pd);
         end;
      end;
   end;

   except
        MainOutMessage('EXCEPTION : CHECKOPENDOORS');
   end;
end;


{-------------------- Npc & Monster ----------------------}

procedure TUserEngine.LoadRefillCretInfos;
begin

end;

function  TUserEngine.GetMerchant (npcid: integer): TCreature;
var
   i: integer;
begin
   Result := nil;
   for i:=0 to MerchantList.Count-1 do begin
      if Integer(MerchantList[i]) = npcid then begin
         Result := TCreature(MerchantList[i]);
         break;
      end;
   end;
end;

function  TUserEngine.GetMerchantXY (envir: TEnvirnoment; x, y, wide: integer; npclist: TList): integer;
var
   i: integer;
begin
   for i:=0 to MerchantList.Count-1 do begin
      if (TCreature(MerchantList[i]).PEnvir = envir) and
         (abs(TCreature(MerchantList[i]).CX - x) <= wide) and
         (abs(TCreature(MerchantList[i]).CY - y) <= wide)
      then begin
         npclist.Add (MerchantList[i]);
      end;
   end;
   Result := npclist.Count;
end;

procedure TUserEngine.InitializeMerchants;
var
   i: integer;
   m: TMerchant;
   frmcap: string;
begin
   frmcap := FrmMain.Caption;

   for i:=MerchantList.Count-1 downto 0 do begin
      m := TMerchant (MerchantList[i]);
      m.Penvir := GrobalEnvir.GetEnvir (m.MapName);
      if m.Penvir <> nil then begin
         m.Initialize;
         if m.ErrorOnInit then begin
            MainOutMessage ('Merchant Initalize fail... ' + m.UserName);
            m.Free;
            MerchantList.Delete (i);
         end else begin
            m.LoadMerchantInfos;
            m.LoadMarketSavedGoods;
            m.LoadMemorialCount;
         end;
      end else begin
         MainOutMessage ('Merchant Initalize fail... (m.PEnvir=nil) ' + m.UserName);
         m.Free;
         MerchantList.Delete (i);
      end;

      FrmMain.Caption := 'Merchant Loading.. ' + IntToStr(MerchantList.Count-i+1) + '/' + IntToStr(MerchantList.Count);
      FrmMain.RefreshForm;
   end;

   FrmMain.Caption := frmcap;
end;

function  TUserEngine.GetNpc (npcid: integer): TCreature;
var
   i: integer;
begin
   Result := nil;
   for i:=0 to NpcList.Count-1 do begin
      if Integer(NpcList[i]) = npcid then begin
         Result := TCreature(NpcList[i]);
         break;
      end;
   end;
end;

function  TUserEngine.GetNpcXY (envir: TEnvirnoment; x, y, wide: integer; list: TList): integer;
var
   i: integer;
begin
   for i:=0 to NpcList.Count-1 do begin
      if (TCreature(NpcList[i]).PEnvir = envir) and
         (abs(TCreature(NpcList[i]).CX - x) <= wide) and
         (abs(TCreature(NpcList[i]).CY - y) <= wide)
      then begin
         list.Add (NpcList[i]);
      end;
   end;
   Result := list.Count;
end;

procedure TUserEngine.InitializeNpcs;
var
   i: integer;
   npc: TNormNpc;
   frmcap: string;
begin
   frmcap := FrmMain.Caption;

   for i:=NpcList.Count-1 downto 0 do begin
      npc := TNormNpc (NpcList[i]);
      npc.Penvir := GrobalEnvir.GetEnvir (npc.MapName);
      if npc.Penvir <> nil then begin
         npc.Initialize;
         if npc.ErrorOnInit and not npc.BoInvisible then begin
            MainOutMessage ('Npc Initalize fail... ' + npc.UserName);
            npc.Free;
            NpcList.Delete (i);
         end else begin
            npc.LoadNpcInfos;
            npc.LoadMemorialCount;
         end;
      end else begin
         MainOutMessage ('Npc Initalize fail... [Mapinfo or Map] (npc.PEnvir=nil) ' + npc.UserName);
         npc.Free;
         NpcList.Delete (i);
      end;

      FrmMain.Caption := 'Npc loading.. ' + IntToStr(NpcList.Count - i+1) + '/' + IntToStr(NpcList.Count);
      FrmMain.RefreshForm;
   end;

   FrmMain.Caption := frmcap;
end;

function  TUserEngine.GetMonRace (monname: string): integer;
var
   i: integer;
begin
   Result := -1;
   for i:=0 to MonDefList.Count-1 do begin
      if CompareText (PTMonsterInfo(MonDefList[i]).Name, monname) = 0 then begin
         Result := PTMonsterInfo(MonDefList[i]).Race;
         break;
      end;
   end;
end;

function  TUserEngine.GetMonLevel (monname: string): integer;
var
   i: integer;
begin
   Result := -1;
   for i:=0 to MonDefList.Count-1 do begin
      if CompareText (PTMonsterInfo(MonDefList[i]).Name, monname) = 0 then begin
         Result := PTMonsterInfo(MonDefList[i]).Level;
         break;
      end;
   end;
end;

procedure TUserEngine.ApplyMonsterAbility (cret: TCreature; monname: string);
var
   i: integer;
   pm: PTMonsterInfo;
begin
   for i:=0 to MonDefList.Count-1 do begin
      if CompareText (PTMonsterInfo(MonDefList[i]).Name, monname) = 0 then begin
         pm := PTMonsterInfo(MonDefList[i]);
         cret.RaceServer := pm.Race;
         cret.RaceImage := pm.RaceImg;
         cret.Appearance := pm.Appr;
         cret.Abil.Level := pm.Level;
         cret.LifeAttrib := pm.LifeAttrib;
         cret.CoolEye := pm.CoolEye;
         cret.FightExp := pm.Exp;
         cret.Abil.HP := pm.HP;
         cret.Abil.MaxHP := pm.HP;
         cret.Abil.MP := pm.MP;
         cret.Abil.MaxMP := pm.MP;
         cret.Abil.AC := makeword(pm.AC, pm.AC);
         cret.Abil.MAC := makeword(pm.MAC, pm.MAC);
         cret.Abil.DC := makeword(pm.DC, pm.MaxDC);
         cret.Abil.MC := makeword(pm.MC, pm.MC);
         cret.Abil.SC := makeword(pm.SC, pm.SC);
         cret.SpeedPoint := pm.Speed;
         cret.AccuracyPoint := pm.Hit;

         cret.NextWalkTime := pm.WalkSpeed;
         cret.WalkStep := pm.WalkStep;
         cret.WalkWaitTime := pm.WalkWait;
         cret.NextHitTime := pm.AttackSpeed;

         cret.Tame := pm.Tame;
         cret.AntiPush := pm.AntiPush;
         cret.AntiUndead := pm.AntiUndead;
         cret.SizeRate := pm.SizeRate;
         cret.AntiStop := pm.AntiStop;
         break;
      end;
   end;
end;

procedure TUserEngine.RandomUpgradeItem (pu: PTUserItem);
var
   pstd: PTStdItem;
begin
   pstd := GetStdItem (pu.Index);
   if pstd <> nil then begin
      case pstd.StdMode of
         5, 6: //무기
            ItemMan.UpgradeRandomWeapon (pu);
         10, 11: //남자옷, 여자옷
            ItemMan.UpgradeRandomDress (pu);
         19: //목걸이 (마법회피, 행운)
            ItemMan.UpgradeRandomNecklace19 (pu);
         20, 21, 24: //목걸이 팔찌
            ItemMan.UpgradeRandomNecklace (pu);
         26:
            ItemMan.UpgradeRandomBarcelet (pu);
         22: //반지
            ItemMan.UpgradeRandomRings (pu);
         23: //반지
            ItemMan.UpgradeRandomRings23 (pu);
         15: //헬멧
            ItemMan.UpgradeRandomHelmet (pu);
      end;
   end;
end;

procedure  TUserEngine.RandomSetUnknownItem (pu: PTUserItem);
var
   pstd: PTStdItem;
begin
   pstd := GetStdItem (pu.Index);
   if pstd <> nil then begin
      case pstd.StdMode of
         15: //투구
            ItemMan.RandomSetUnknownHelmet (pu);
         22,23: //반지
            ItemMan.RandomSetUnknownRing (pu);
         24,26: //팔찌
            ItemMan.RandomSetUnknownBracelet (pu);
      end;
   end;
end;

function  TUserEngine.GetUniqueEvnetItemName (var iname: string; var numb: integer): Boolean;
var
   n: integer;
begin
   Result := FALSE;
   if (GetTickCount - eventitemtime > longword(UniqueItemEventInterval)) and (EventItemList.Count > 0) then begin
      eventitemtime := GetTickCount;
      n := Random(EventItemList.Count);
      iname := EventItemList[n];
      numb := Integer(EventItemList.Objects[n]);
      EventItemList.Delete(n);
      Result := TRUE;
   end;
end;

procedure TUserEngine.ReloadAllMonsterItems;
var
   i: integer;
   list: TList;
begin
   list := nil;
   for i:=0 to MonDefList.Count-1 do begin
      FrmDB.LoadMonItems (PTMonsterInfo(MonDefList[i]).Name, PTMonsterInfo(MonDefList[i]).Itemlist);
   end;
end;

function  TUserEngine.MonGetRandomItems (mon: TCreature): integer;
var
   i, numb: integer;
   list: TList;
   iname: string;
   pmi: PTMonItemInfo;
   pu: PTUserItem;
   pstd: PTStdItem;
   RealMaxPoint: integer;
begin
   RealMaxPoint := 0;
   list := nil;
   for i:=0 to MonDefList.Count-1 do begin
      if CompareText (PTMonsterInfo(MonDefList[i]).Name, mon.UserName) = 0 then begin
         list := PTMonsterInfo(MonDefList[i]).Itemlist;
         break;
      end;
   end;
   if list <> nil then begin
      for i:=0 to list.Count-1 do begin
         pmi := PTMonItemInfo(list[i]);
         if BoTestServer then
            RealMaxPoint := Random(_MAX(1, pmi.MaxPoint div 5))  //드롭율 5배 이벤트(테섭)
         else
            RealMaxPoint := Random(pmi.MaxPoint);

         if pmi.SelPoint >= RealMaxPoint then begin
            if CompareText(pmi.ItemName, NAME_OF_MONEY) = 0 then begin
//               mon.Gold := mon.Gold + (pmi.Count div 2) + Random(pmi.Count);
               mon.IncGold( (pmi.Count div 2) + Random(pmi.Count) );
            end else begin
               //유니크 아이템 이벤트....
               iname := '';
               ////if (BoUniqueItemEvent) and (not mon.BoAnimal) then begin
               ////   if GetUniqueEvnetItemName (iname, numb) then begin
                     //numb; //iname
               ////   end;
               ////end;
               if iname = '' then
                  iname := pmi.ItemName;

               new (pu);
               if CopyToUserItemFromName (iname, pu^) then begin
                  //내구성이 변경되어 있음..
                  pu.Dura := Round ((pu.DuraMax / 100) * (20+Random(80)));

                  pstd := GetStdItem (pu.Index);
                  ////if pstd <> nil then
                  ////   if pstd.StdMode = 50 then begin  //상품권
                  ////      pu.Dura := numb;
                  ////   end;

                  //낮은 확률로
                  //아이템의 업그레이드된 내용 적용
                  if Random(10) = 0 then
                     RandomUpgradeItem (pu);

                  if pstd <> nil then
                  begin
                     //미지 시리즈 아이템인 경우
                     if pstd.StdMode in [15,19,20,21,22,23,24,26,52,53,54] then begin
                        if (pstd.Shape = RING_OF_UNKNOWN) or
                           (pstd.Shape = BRACELET_OF_UNKNOWN) or
                           (pstd.Shape = HELMET_OF_UNKNOWN)
                        then begin
                           UserEngine.RandomSetUnknownItem (pu);
                        end;
                     end;

                     if pstd.OverlapItem >= 1 then begin
                        pu.Dura := 1;  // gadget:카운트아이템
                     end;
                  end;

                  mon.ItemList.Add (pu)
               end else
                  Dispose (pu);
            end;
         end;
      end;
   end;
   Result := 1;
end;

function  TUserEngine.AddCreature (map: string; x, y, race: integer; monname: string): TCreature;
var
   env: TEnvirnoment;
   cret: TCreature;
   i, stepx, edge: integer;
   outofrange: pointer;
begin
   Result := nil;
   cret := nil;
   env := GrobalEnvir.GetEnvir (map);
   if env = nil then exit;

   case race of
      RC_DOORGUARD:
         begin
            cret := TSuperGuard.Create;
         end;
      RC_ANIMAL+1:  //닭
         begin
            cret := TMonster.Create;
            cret.BoAnimal := TRUE;
            cret.MeatQuality := 3000 + Random(3500); //기본값.
            cret.BodyLeathery := 50; //기본값
         end;
      RC_RUNAWAYHEN: //달아나는 닭(sonmg 2004/12/27)
         begin
            cret := TChickenDeer.Create; //달아남
            cret.BoAnimal := TRUE;
            cret.MeatQuality := 3000 + Random(3500); //기본값.
            cret.BodyLeathery := 50; //기본값
         end;
      RC_DEER:  //사슴
         begin
            if Random(30) = 0 then begin
               cret := TChickenDeer.Create; //겁쟁이 사슴, 달아남
               cret.BoAnimal := TRUE;
               cret.MeatQuality := 10000 + Random(20000);
               cret.BodyLeathery := 150; //기본값
            end else begin
               cret := TMonster.Create;
               cret.BoAnimal := TRUE;
               cret.MeatQuality := 8000 + Random(8000); //기본값.
               cret.BodyLeathery := 150; //기본값
            end;
         end;
      RC_WOLF:
         begin
            cret := TATMonster.Create;
            cret.BoAnimal := TRUE;
            cret.MeatQuality := 8000 + Random(8000); //기본값.
            cret.BodyLeathery := 150; //기본값
         end;
      RC_TRAINER:  //수련조교
         begin
            cret := TTrainer.Create;
            cret.RaceServer := RC_TRAINER;
         end;
      RC_MONSTER:
         begin
            cret := TMonster.Create;
         end;
      RC_OMA:
         begin
            cret := TATMonster.Create;
         end;
      RC_BLACKPIG:
         begin
            cret := TATMonster.Create;
            if Random(2) = 0 then cret.BoFearFire := TRUE;
         end;
      RC_SPITSPIDER:
         begin
            cret := TSpitSpider.Create;
         end;
      RC_SLOWMONSTER:
         begin
            cret := TSlowATMonster.Create;
         end;
      RC_SCORPION:  //전갈
         begin
            cret := TScorpion.Create;
         end;
      RC_KILLINGHERB:
         begin
            cret := TStickMonster.Create;
         end;
      RC_SKELETON: //해골
         begin
            cret := TATMonster.Create;
         end;
      RC_DUALAXESKELETON: //쌍도끼해골
         begin
            cret := TDualAxeMonster.Create;
         end;
      RC_HEAVYAXESKELETON: //큰도끼해골
         begin
            cret := TATMonster.Create;
         end;
      RC_KNIGHTSKELETON: //해골전사
         begin
            cret := TATMonster.Create;
         end;
      RC_BIGKUDEKI: //대형구데기
         begin
            cret := TGasAttackMonster.Create;
         end;

      RC_COWMON:  //우면귀
         begin
            cret := TCowMonster.Create;
            if Random(2) = 0 then cret.BoFearFire := TRUE;
         end;
      RC_MAGCOWFACEMON:
         begin
            cret := TMagCowMonster.Create;
         end;
      RC_COWFACEKINGMON:
         begin
            cret := TCowKingMonster.Create;
         end;

      RC_THORNDARK:
         begin
            cret := TThornDarkMonster.Create;
         end;

      RC_LIGHTINGZOMBI:
         begin
            cret := TLightingZombi.Create;
         end;

      RC_DIGOUTZOMBI:
         begin
            cret := TDigOutZombi.Create;
            if Random(2) = 0 then cret.BoFearFire := TRUE;
         end;

      RC_ZILKINZOMBI:
         begin
            cret := TZilKinZombi.Create;
            if Random(4) = 0 then cret.BoFearFire := TRUE;
         end;

      RC_WHITESKELETON:
         begin
            cret := TWhiteSkeleton.Create; //소환백골
         end;

      RC_ANGEL:
         begin
            cret := TAngelmon.Create; // 천녀(월령)
         end;

      RC_CLONE:
         begin
            cret := TClonemon.Create; //분신
         end;

      RC_FIREDRAGON:
         begin
            cret := TDragon.Create; //화룡
         end;

      RC_DRAGONBODY:
         begin
            cret := TDragonBody.Create; //화룡몸
         end;
      RC_DRAGONSTATUE:
         begin
            cret := TDragonStatue.Create; //용석상
         end;

      RC_SCULTUREMON:
         begin
            cret := TScultureMonster.Create;
            cret.BoFearFire := TRUE;
         end;

      RC_SCULKING:
         begin
            cret := TScultureKingMonster.Create;
         end;
      RC_SCULKING_2:
         begin
            cret := TScultureKingMonster.Create;
            TScultureKingMonster(cret).BoCallFollower := FALSE;
         end;

      RC_BEEQUEEN:
         begin
            cret := TBeeQueen.Create;   //벌통
         end;

      RC_ARCHERMON:
         begin
            cret := TArcherMonster.Create; //마궁사
         end;

      RC_GASMOTH:  //가스쏘는 쐐기나방
         begin
            cret := TGasMothMonster.Create;
         end;

      RC_DUNG:    //마비가스, 둥
         begin
            cret := TGasDungMonster.Create;
         end;

      RC_CENTIPEDEKING:  //촉룡신, 지네왕
         begin
            cret := TCentipedeKingMonster.Create;
         end;

      RC_BIGHEARTMON:
         begin
            cret := TBigHeartMonster.Create;  //혈거왕, 심장
         end;

      RC_BAMTREE:
         begin
            cret := TBamTreeMonster.Create;
         end;

      RC_MONSTERBOX:
         begin
            cret := TMonsterBox.Create;
         end;

      RC_SPIDERHOUSEMON:
         begin
            cret := TSpiderHouseMonster.Create;  //거미집,  폭안거미
         end;

      RC_EXPLOSIONSPIDER:
         begin
            cret := TExplosionSpider.Create;  //폭주
         end;

      RC_HIGHRISKSPIDER:
         begin
            cret := THighRiskSpider.Create
         end;

      RC_BIGPOISIONSPIDER:
         begin
            cret := TBigPoisionSpider.Create;
         end;

      RC_BLACKSNAKEKING:   //흑사왕, 더블 공격
         begin
            cret := TDoubleCriticalMonster.Create;
         end;

      RC_NOBLEPIGKING:     //귀돈왕, 강력 공격(더블 아님)
         begin
            cret := TATMonster.Create;
         end;

      RC_FEATHERKINGOFKING:  //흑천마왕
         begin
            cret := TDoubleCriticalMonster.Create;
         end;

      // 2003/02/11 해골 반왕, 부식귀, 해골병졸
      RC_SKELETONKING:  //해골반왕
         begin
            cret := TSkeletonKingMonster.Create;
         end;
      RC_TOXICGHOST:  //부식귀
         begin
            cret := TGasAttackMonster.Create;
         end;
      RC_SKELETONSOLDIER:  //해골병졸
         begin
            cret := TSkeletonSoldier.Create;
         end;
      // 2003/03/04 반야좌사, 우사, 사우천왕
      RC_BANYAGUARD:  //반야좌/우사
         begin
            cret := TBanyaGuardMonster.Create;
         end;
      RC_DEADCOWKING:  //사우천왕
         begin
            cret := TDeadCowKingMonster.Create;
         end;
      // 2003/07/15 과거비천 추가몹
      RC_PBOMA1: //날개오마
         begin
            cret := TArcherMonster.Create;
         end;
      RC_PBOMA2, //쇠뭉치상급오마
      RC_PBOMA3, //몽둥이상급오마
      RC_PBOMA4, //칼하급오마
      RC_PBOMA5: //도끼하급오마
         begin
            cret := TATMonster.Create;
         end;
      RC_PBOMA6: //활하급오마
         begin
            cret := TArcherMonster.Create;
         end;
      RC_PBGUARD: //과거비천 창경비
         begin
            cret := TSuperGuard.Create;
         end;
      RC_PBMSTONE1: //마계석1
         begin
            cret := TStoneMonster.Create;
         end;
      RC_PBMSTONE2: //마계석2
         begin
            cret := TStoneMonster.Create;
         end;
      RC_PBKING: //과거비천 보스
         begin
            cret := TPBKingMonster.Create;
         end;
      RC_GOLDENIMUGI: //황금이무기(부룡금사)
         begin
            cret := TGoldenImugi.Create;
         end;

      RC_CASTLEDOOR:   //성문
         begin
            cret := TCastleDoor.Create;
         end;

      RC_WALL:
         begin
            cret := TWallStructure.Create;
         end;

      RC_ARCHERGUARD:  //궁수경비
         begin
            cret := TArcherGuard.Create;
         end;
      RC_ARCHERMASTER:  //궁수호위병
         begin
            cret := TArcherMaster.Create;
         end;

      RC_ARCHERPOLICE:  //궁수경찰
         begin
            cret := TArcherPolice.Create;
         end;

      RC_ELFMON:
         begin
            cret := TElfMonster.Create;  //신수 변신전
         end;

      RC_ELFWARRIORMON:
         begin
            cret := TElfWarriorMonster.Create;  //신수 변신후
         end;

      RC_SOCCERBALL:
         begin
            cret := TSoccerBall.Create;
         end;
      RC_MINE:
         begin
            cret := TMineMonster.Create;
         end;

      RC_EYE_PROG:      //사안충 -> 설인대충
         begin
            cret := TEyeProg.Create;
         end;
      RC_STON_SPIDER:   //환마석거미 -> 신석독마주
         begin
            cret := TStoneSpider.Create;
         end;
      RC_GHOST_TIGER:   //환영한호
         begin
            cret := TGhostTiger.Create;
         end;
      RC_JUMA_THUNDER:  //주마뢰격장 -> 주마격뢰장
         begin
            cret := TJumaThunder.Create;
         end;

      RC_SUPEROMA:
         begin
            cret := TSuperOma.Create;
         end;
      RC_TOGETHEROMA:
         begin
            cret := TTogetherOma.Create;
         end;

      RC_STICKBLOCK:  //호혼석
         begin
            cret := TStickBlockMonster.Create;
         end;
      RC_FOXWARRIOR:  //비월여우(전사) 비월흑호
         begin
            cret := TFoxWarrior.Create;
         end;
      RC_FOXWIZARD:  //비월여우(술사) 비월적호
         begin
            cret := TFoxWizard.Create;
         end;
      RC_FOXTAOIST:  //비월여우(도사) 비월소호
         begin
            cret := TFoxTaoist.Create;
         end;

      RC_PUSHEDMON:  //호기연
         begin
            cret := TPushedMon.Create;
            TPushedMon(cret).AttackWide := 1;
         end;
      RC_PUSHEDMON2:  //호기옥
         begin
            cret := TPushedMon.Create;
            TPushedMon(cret).AttackWide := 2;
         end;

      RC_FOXPILLAR:  //호혼기석
         begin
            cret := TFoxPillar.Create;
         end;
      RC_FOXBEAD:  //비월천주
         begin
            cret := TFoxBead.Create;
         end;
      //2005/12/14
      RC_NEARTURTLE:
         begin
            cret := TATMonster.Create;
            cret.MultiplyTargetLevelMin := 70;
            cret.MultiplyTargetLevelMax := 120;
         end;
      RC_FARTURTLE:
         begin
            cret := TPhisicalFarAttackMonster.Create;
            cret.MultiplyTargetLevelMin := 60;
            cret.MultiplyTargetLevelMax := 130;
         end;
      RC_BOSSTURTLE:
         begin
            cret := TBossTurtle.Create;
         end;

   end;
   if cret <> nil then begin
      ApplyMonsterAbility (cret, monname);
      cret.Penvir := env;
      cret.MapName := map;
      cret.CX := x;
      cret.CY := y;
      cret.Dir := Random(8);
      cret.UserName := monname;
      cret.WAbil := cret.Abil;

      //은신 볼 확률
      if Random (100) < cret.CoolEye then begin
         cret.BoViewFixedHide := TRUE;
      end;

      MonGetRandomItems (cret);

      cret.Initialize;
      if cret.ErrorOnInit then begin //젠자리가 못움직이는 자리
         outofrange := nil;

         if cret.PEnvir.MapWidth < 50 then stepx := 2
         else stepx := 3;
         if cret.PEnvir.MapHeight < 250 then begin
            if cret.PEnvir.MapHeight < 30 then edge := 2
            else edge := 20;
         end else edge := 50;

         for i:=0 to 30 do begin
            //겹침 젠 허용
            if not cret.PEnvir.CanWalk (cret.CX, cret.CY, TRUE) then begin //FALSE) then begin
               if cret.CX < cret.PEnvir.MapWidth-edge-1 then Inc (cret.CX, stepx)
               else begin
                  cret.CX := edge + Random(cret.PEnvir.MapWidth div 2);
                  if cret.CY < cret.PEnvir.MapHeight-edge-1 then Inc (cret.CY, stepx)
                  else cret.CY := edge + Random(cret.PEnvir.MapHeight div 2);
               end;
            end else begin
               outofrange := cret.PEnvir.AddToMap (cret.CX, cret.CY, OS_MOVINGOBJECT, cret);
               break;
            end;
         end;
         if outofrange = nil then begin
            //왕몹젠 스킵되지 않게(테스트)
            if (race = RC_SKELETONKING) or (race = RC_DEADCOWKING) or
                  (race = RC_FEATHERKINGOFKING) or (race = RC_PBKING) then begin
               cret.RandomSpaceMoveInRange (0, 0, 5);
               MainOutMessage('Outofrange Nil - Race : ' + IntToStr(race));
            end else begin
               cret.Free;
               cret := nil;
            end;
         end;
      end;
   end;
   Result := cret;
end;

function  TUserEngine.AddCreatureSysop (map: string; x, y: integer; monname: string): TCreature;
var
   cret: TCreature;
   n, race: integer;
begin
   race := UserEngine.GetMonRace (monname);
   cret := AddCreature (map, x, y, race, monname);
   if cret <> nil then begin
      n := MonList.Count-1;
      if n < 0 then n := 0;
      PTZenInfo(MonList[n]).Mons.Add (cret);
   end;
   Result := cret;
end;

function  TUserEngine.RegenMonsters (pz: PTZenInfo; zcount: integer): Boolean;
var
   i, n, zzx, zzy: integer;
   start: longword;
   cret: TCreature;
   str : string;
begin
   Result := TRUE;
   start := GetTickCount;
   try
      n := zcount; //pz.Count - pz.Mons.Count;
      //race := GetMonRace (pz.MonName);
      if pz.MonRace > 0 then begin
         if Random(100) < pz.SmallZenRate then begin //젠이 몰려서 된다.
            zzx := pz.X - pz.Area + Random(pz.Area*2+1);
            zzy := pz.Y - pz.Area + Random(pz.Area*2+1);
            for i:=0 to n-1 do begin
               cret := AddCreature (pz.MapName,
                                    zzx - 10 + Random(20),
                                    zzy - 10 + Random(20),
                                    pz.MonRace,
                                    pz.MonName);
               // 2003/06/20
               if cret <> nil then begin
                  pz.Mons.Add (cret);
                  if (pz.TX <> 0) and (pz.TY <> 0) then begin
                     cret.BoHasMission := TRUE;
                     cret.Mission_X := pz.TX;
                     cret.Mission_Y := pz.TY;
                     // 젠시 외치는 정보가 0보다 커야됨
                     if pz.ZenShoutMsg < GenMsgList.count then
                         str := GenMsgList.Strings[pz.ZenShoutMsg]
                     else
                        str := '';

                     if str <> '' then begin
                        case pz.ZenShoutType of
                        1 : // 서버 전체 외치기
                            SysMsgAll (str);
                        2 : // 그냥 외치기
                            CryCry (RM_CRY, cret.PEnvir, cret.CX, cret.CY, 50{wide}, str);
                        end;
                     end;
                  end;
               end;
               if GetTickCount - start > ZenLimitTime then begin
                  Result := FALSE; //젠양이 많음, 다음에 다시함
                  break;
               end;
            end;
         end else begin
            for i:=0 to n-1 do begin
               zzx := pz.X - pz.Area + Random(pz.Area*2+1);
               zzy := pz.Y - pz.Area + Random(pz.Area*2+1);
               cret := AddCreature (pz.MapName,
                                    zzX,
                                    zzY,
                                    pz.MonRace,
                                    pz.MonName);
               // 2003/06/20
               if cret <> nil then begin
                  pz.Mons.Add (cret);
                  if (pz.TX <> 0) and (pz.TY <> 0) then begin
                     cret.BoHasMission := TRUE;
                     cret.Mission_X := pz.TX;
                     cret.Mission_Y := pz.TY;

                     if pz.ZenShoutMsg < GenMsgList.count then
                         str := GenMsgList.Strings[pz.ZenShoutMsg]
                     else
                        str := '';

                     if str <> '' then begin
                        case pz.ZenShoutType of
                        1 : // 서버 전체 외치기
                            SysMsgAll (str);
                        2 : // 그냥 외치기
                            CryCry (RM_CRY, cret.PEnvir, cret.CX, cret.CY, 50{wide}, str);
                        end;
                     end;
                  end;
               end else begin
                  //cret = nil이면...
//왕몹젠 스킵 모니터링(sonmg)
if (pz.MonRace = RC_SKELETONKING) then begin
   MainOutMessage('RegenMon Nil : 해골반왕-NIL');
   MainOutMessage(pz.MapName + ' ' +
                  IntToStr(zzx) + ',' +
                  IntToStr(zzy) + ' ' +
                  IntToStr(pz.MonRace) + ' ' +
                  pz.MonName);
end;
if (pz.MonRace = RC_DEADCOWKING) then begin
   MainOutMessage('RegenMon Nil : 사우천왕-NIL');
   MainOutMessage(pz.MapName + ' ' +
                  IntToStr(zzx) + ',' +
                  IntToStr(zzy) + ' ' +
                  IntToStr(pz.MonRace) + ' ' +
                  pz.MonName);
end;
if (pz.MonRace = RC_FEATHERKINGOFKING) then begin
   MainOutMessage('RegenMon Nil : 흑천마왕-NIL');
   MainOutMessage(pz.MapName + ' ' +
                  IntToStr(zzx) + ',' +
                  IntToStr(zzy) + ' ' +
                  IntToStr(pz.MonRace) + ' ' +
                  pz.MonName);
end;
if (pz.MonRace = RC_PBKING) then begin
   MainOutMessage('RegenMon Nil : 파황마신-NIL');
   MainOutMessage(pz.MapName + ' ' +
                  IntToStr(zzx) + ',' +
                  IntToStr(zzy) + ' ' +
                  IntToStr(pz.MonRace) + ' ' +
                  pz.MonName);
end;
               end;
               if GetTickCount - start > ZenLimitTime then begin
                  Result := FALSE; //젠양이 많음, 다음에 다시함
                  break;
               end;
            end;
         end;
      end;
   except
      MainOutMessage ('[TUserEngine] RegenMonsters exception');
   end;

   //왕몹젠 서버로그 출력
   if Result = TRUE then begin
      if (GetMonLevel( pz.MonName ) = 70) or
            (pz.MonName = '우면귀왕') or (pz.MonName = '촉룡신') or (pz.MonName = '해골반왕') or
            (pz.MonName = '사우천왕') or (pz.MonName = '주마왕') or (pz.MonName = '적월마') or
            (pz.MonName = '흑사왕') or (pz.MonName = '귀돈왕') or (pz.MonName = '흑천마왕') or
            (pz.MonName = '파황마신') then begin
         MainOutMessage('왕몹젠: ' + pz.MonName + ' (' + pz.MapName + ') ' + TimeToStr(Now));
      end;
   end;
end;

function  TUserEngine.GetMonCount (pz: PTZenInfo): integer;
var
   i, n: integer;
begin
   n := 0;
   for i:=0 to pz.Mons.Count-1 do begin
      if not TCreature(pz.Mons[i]).Death and not TCreature(pz.Mons[i]).BoGhost then
         Inc (n);
   end;
   Result := n;
end;

function  TUserEngine.GetGenCount (mapname: string): integer;
var
   i, count: integer;
   pz: PTZenInfo;
begin
   count := 0;
   for i:=0 to MonList.Count-1 do begin
      pz := PTZenInfo(MonList[i]);
      if pz <> nil then begin
         if CompareText(pz.MapName, mapname) = 0 then
            count := count + GetMonCount (pz);
      end;
   end;
   Result := count;
end;

//list가 nil이면 갯수만 리턴
function  TUserEngine.GetMapMons (penvir: TEnvirnoment; list: TList): integer;
var
   i, k, count: integer;
   pz: PTZenInfo;
   cret: TCreature;
begin
   count := 0;
   Result := 0;
   if penvir = nil then exit;
   for i:=0 to MonList.Count-1 do begin
      pz := PTZenInfo(MonList[i]);
      if pz <> nil then begin
         for k:=0 to pz.Mons.Count-1 do begin
            cret := TCreature (pz.Mons[k]);
            if not cret.BoGhost and not cret.Death and (cret.PEnvir = penvir) then begin
               if list <> nil then
                  list.Add (cret);
               Inc (count);
            end;
         end;
      end;
   end;
   Result := count;
end;

//list가 nil이면 갯수만 리턴
function  TUserEngine.GetMapMonsNoRecallMob (penvir: TEnvirnoment; list: TList): integer;
var
   i, k, count: integer;
   pz: PTZenInfo;
   cret: TCreature;
begin
   count := 0;
   Result := 0;
   if penvir = nil then exit;
   for i:=0 to MonList.Count-1 do begin
      pz := PTZenInfo(MonList[i]);
      if pz <> nil then begin
         for k:=0 to pz.Mons.Count-1 do begin
            cret := TCreature (pz.Mons[k]);
            if not cret.BoGhost and not cret.Death and (cret.PEnvir = penvir) and (cret.Master = nil) then begin
               if list <> nil then
                  list.Add (cret);
               Inc (count);
            end;
         end;
      end;
   end;
   Result := count;
end;

{---------------------------------------------------------}

function  TUserEngine.GetDefMagic (magname: string): PTDefMagic;
var
   i: integer;
begin
   Result := nil;
   for i:=0 to DefMagicList.Count-1 do begin
      if CompareText (PTDefMagic(DefMagicList[i]).MagicName, magname) = 0 then begin
         Result := PTDefMagic(DefMagicList[i]);
         break;
      end;
   end;
end;

function  TUserEngine.GetDefMagicFromId (Id: integer): PTDefMagic;
var
   i: integer;
begin
   Result := nil;
   for i:=0 to DefMagicList.Count-1 do begin
      if PTDefMagic(DefMagicList[i]).MagicId = Id then begin
         Result := PTDefMagic(DefMagicList[i]);
         break;
      end;
   end;
end;


{---------------------------------------------------------}


procedure TUserEngine.AddNewUser (ui: PTUserOpenInfo); //(hum: TUserHuman);
begin
   try
      usLock.Enter;
      ReadyList.AddObject (ui.Name, TObject(ui));
   finally
      usLock.Leave;
   end;
end;

procedure TUserEngine.ClosePlayer (hum: TUserHuman);
begin
   hum.GhostTime := GetTickCount;
   ClosePlayers.Add (hum);
end;

procedure TUserEngine.SavePlayer (hum: TUserHuman);
var
   p: PTSaveRcd;
   savelistcount : integer;
begin
   // TEST_TIME
//   if g_TestTime = 1 then  MainOutMessage( 'SavePlayer :'+ hum.UserId + ','+ hum.UserName);

   new (p);
   FillChar (p^, sizeof(TSaveRcd), 0);
   p.uId := hum.UserId;
   p.uName := hum.UserName;
   p.Certify := hum.Certification;
   p.hum := hum;
   FDBMakeHumRcd (hum, @p.rcd);
   savelistcount := FrontEngine.AddSavePlayer (p);

   // TEST_TIME
   if g_TestTime = 1 then  MainOutMessage( 'SavePlayer :'+ hum.UserId + ','+ hum.UserName + '(' + IntToStr(savelistcount) + ')');
end;

procedure TUserEngine.ChangeAndSaveOk (pc: PTChangeUserInfo);
var
   pcu: PTChangeUserInfo;
begin
   new (pcu);
   pcu^ := pc^;  //새로 복사해야 함
   try
      usLock.Enter;
      SaveChangeOkList.Add (pcu);
   finally
      usLock.Leave;
   end;
end;

function  TUserEngine.GetMyDegree (uname: string): integer;
var
   i: integer;
begin
   Result := UD_USER;
   for i:=0 to AdminList.Count-1 do begin
      if CompareText (AdminList[i], uname) = 0 then begin
         Result := integer(AdminList.Objects[i]);
         break;
      end;
   end;
end;

function  TUserEngine.GetUserHuman (who: string): TUserHuman;
var
   i: integer;
begin
   Result := nil;
   for i:=0 to RunUserList.Count-1 do begin
      if CompareText (RunUserList[i], who) = 0 then begin
         if ( not TUserHuman(RunUserList.Objects[i]).BoGhost )  then
         begin
            Result := TUserHuman(RunUserList.Objects[i]);
            break;
         end;
      end;
   end;
end;

function  TUserEngine.FindOtherServerUser (who: string; var svindex: integer): Boolean;
var
   i: integer;
begin
   Result := FALSE;
   for i:=0 to OtherUserNameList.Count-1 do begin
      if CompareText (OtherUserNameList[i], who) = 0 then begin
         svindex := integer(OtherUserNameList.Objects[i]);
         Result := TRUE;
         break;
      end;
   end;
end;

function  TUserEngine.GetUserCount: integer;
begin
   Result := RunUserList.Count + OtherUserNameList.Count;
end;

function  TUserEngine.GetRealUserCount: integer;
begin
   Result := RunUserList.Count;
end;

function  TUserEngine.GetAreaUserCount (env: TEnvirnoment; x, y, wide: integer): integer;
var
   i, n: integer;
   hum: TUserhuman;
begin
   n := 0;
   for i:=0 to RunUserList.Count-1 do begin
      hum := TUserHuman(RunUserList.Objects[i]);
      if (not hum.BoGhost) and (hum.PEnvir = env) then begin
         if (Abs(hum.CX-x) < wide) and (Abs(hum.CY-y) < wide) then
            Inc (n);
      end;
   end;
   Result := n;
end;

//누워있는 사람까지 리스트 보냄
function  TUserEngine.GetAreaUsers (env: TEnvirnoment; x, y, wide: integer; ulist: TList): integer;
var
   i, n: integer;
   hum: TUserhuman;
begin
   n := 0;
   for i:=0 to RunUserList.Count-1 do begin
      hum := TUserHuman(RunUserList.Objects[i]);
      if (not hum.BoGhost) and (hum.PEnvir = env) then begin
         if (Abs(hum.CX-x) < wide) and (Abs(hum.CY-y) < wide) then begin
            ulist.Add (hum);
            Inc (n);
         end;
      end;
   end;
   Result := n;
end;

function  TUserEngine.GetAreaAllUsers (env: TEnvirnoment; ulist: TList): integer;
var
   i, n: integer;
   hum: TUserhuman;
begin
   n := 0;
   for i:=0 to RunUserList.Count-1 do
   begin
      hum := TUserHuman(RunUserList.Objects[i]);
      if (not hum.BoGhost) and (hum.PEnvir = env) then
      begin
            ulist.Add (hum);
            Inc (n);
      end;
   end;
   Result := n;
end;

function  TUserEngine.GetHumCount (mapname: string): integer;
var
   i, n: integer;
   hum: TUserhuman;
begin
   n := 0;
   for i:=0 to RunUserList.Count-1 do begin
      hum := TUserHuman(RunUserList.Objects[i]);
      if (not hum.BoGhost) and (not hum.Death) and (CompareText (hum.PEnvir.MapName, mapname) = 0) then begin
         Inc (n);
      end;
   end;
   Result := n;
end;

procedure TUserEngine.CryCry (msgtype: integer; env: TEnvirnoment; x, y, wide: integer; saying: string);
var
   i: integer;
   hum: TUserhuman;
begin
   for i:=0 to RunUserList.Count-1 do begin
      hum := TUserHuman(RunUserList.Objects[i]);
      if (not hum.BoGhost) and (hum.PEnvir = env) and (hum.BoHearCry) then begin
         if (Abs(hum.CX-x) < wide) and (Abs(hum.CY-y) < wide) then
            hum.SendMsg (nil, msgtype{RM_CRY}, 0, clBlack, clYellow, 0, saying);
      end;
   end;
end;

procedure TUserEngine.GuildAgitCry (msgtype: integer; env: TEnvirnoment; x, y, wide: integer; saying: string);
var
   i: integer;
   hum: TUserhuman;
begin
   for i:=0 to RunUserList.Count-1 do begin
      hum := TUserHuman(RunUserList.Objects[i]);
      if (not hum.BoGhost) and (hum.BoHearCry) then begin
         // 문주가 장원 내에 있으면, 같은 번호의 장원 내에 있는 모든 사람에게 공지.
         if (env.GetGuildAgitRealMapName = GuildAgitMan.GuildAgitMapName[0]) or
               (env.GetGuildAgitRealMapName = GuildAgitMan.GuildAgitMapName[1]) or
               (env.GetGuildAgitRealMapName = GuildAgitMan.GuildAgitMapName[2]) or
               (env.GetGuildAgitRealMapName = GuildAgitMan.GuildAgitMapName[3]) then begin
            if hum.PEnvir.GuildAgit = env.GuildAgit then begin
               hum.SysMsg (saying, 6);
            end;
         end;
      end;
   end;
end;

procedure TUserEngine.SysMsgAll (saying: string);
var
   i: integer;
   hum: TUserhuman;
begin
   for i:=0 to RunUserList.Count-1 do begin
      hum := TUserHuman(RunUserList.Objects[i]);
      if( not hum.BoGhost) then begin
         hum.SysMsg (saying, 0);
      end;
   end;
end;


procedure TUserEngine.KickDoubleConnect (uname: string);
var
   i: integer;
begin
   for i:=0 to RunUserList.Count-1 do begin
      if CompareText (RunUserList[i], uname) = 0 then begin
         TUserHuman (RunUserList.Objects[i]).UserRequestClose := TRUE;
         MainOutMessage('[중복접속캐릭] ' + uname);
         break;
      end;
   end;
end;

procedure TUserEngine.GuildMemberReLogin (guild: TGuild);
var
   i, n: integer;
begin
   for i:=0 to RunUserList.Count-1 do begin
      if TUserHuman (RunUserList.Objects[i]).MyGuild = guild then begin
         guild.MemberLogin (TUserHuman (RunUserList.Objects[i]), n);
      end;
   end;
end;


//다른 서버로부터 대기자를 받음
function  TUserEngine.AddServerWaitUser (psui: PTServerShiftUserInfo): Boolean;
begin
   psui.waittime := GetTickCount;
   WaitServerList.Add (psui);
   Result := TRUE;
end;

procedure TUserEngine.CheckServerWaitTimeOut;
var
   i: integer;
begin
   for i:=WaitServerList.Count-1 downto 0 do begin
      if GetTickCount - PTServerShiftUserInfo(WaitServerList[i]).waittime > 30 * 1000 then begin
         Dispose (PTServerShiftUserInfo(WaitServerList[i]));
         WaitServerList.Delete (i);
      end;
   end;
end;

procedure TUserEngine.CheckHolySeizeValid;  //결계가 깨졌는지 검사한다.
var
   i, k: integer;
   phs: PTHolySeizeInfo;
   cret: TCreature;
begin
   for i:=HolySeizeList.Count-1 downto 0 do begin
      phs := PTHolySeizeInfo (HolySeizeList[i]);
      if phs <> nil then begin
         for k:=phs.seizelist.Count-1 downto 0 do begin  //결계에 걸린 몬스터가 죽었거나, 풀렸는지 검사
            cret := phs.seizelist[k];
            if (cret.Death) or (cret.BoGhost) or (not cret.BoHolySeize) then begin
               phs.seizelist.Delete (k);
            end;
         end;
         //결계에 잡인 몹이 없거나, 3분이 경과한 경우, (결계의 제한 시간은 3분이다)
         if (phs.seizelist.Count <= 0) or
            (GetTickCount - phs.OpenTime > phs.SeizeTime) or
            (GetTickCount - phs.OpenTime > 3 * 60 * 1000) then begin
            phs.seizelist.Free;
            for k:=0 to 7 do begin
               if phs.earr[k] <> nil then
                  TEvent(phs.earr[k]).Close;
            end;
            Dispose (phs);
            HolySeizeList.Delete (i);
         end;
      end;
   end;
end;

function  TUserEngine.GetServerShiftInfo (uname: string; certify: integer): PTServerShiftUserInfo;
var
   i: integer;
begin
   Result := nil;
   for i:=0 to WaitServerList.Count-1 do begin
      if (CompareText (PTServerShiftUserInfo(WaitServerList[i]).UserName, uname) = 0) and
         (PTServerShiftUserInfo(WaitServerList[i]).Certification = certify) then begin
         Result := PTServerShiftUserInfo(WaitServerList[i]);
         break;
      end;
   end;
end;

procedure TUserEngine.MakeServerShiftData (hum: TUserHuman; var sui: TServerShiftUserInfo);
var
   i: integer;
   cret: TCreature;
begin

   FillChar (sui, sizeof(TServerShiftUserInfo), #0);

   sui.UserName := hum.UserName;
   FDBMakeHumRcd (hum, @sui.rcd);

   sui.Certification := hum.Certification;
   if hum.GroupOwner <> nil then begin
      sui.GroupOwner := hum.GroupOwner.UserName;
      for i:=0 to hum.GroupOwner.GroupMembers.Count-1 do
         sui.GroupMembers[i] := hum.GroupOwner.GroupMembers[i];
   end;

   sui.BoHearCry := hum.BoHearCry;
   sui.BoHearWhisper := hum.BoHearWhisper;
   sui.BoHearGuildMsg := hum.BoHearGuildMsg;
   sui.BoSysopMode := hum.BoSysopMode;
   sui.BoSuperviserMode := hum.BoSuperviserMode;
   sui.BoSlaveRelax := hum.BoSlaveRelax;  // (sonmg 2005/01/21)

   for i:=0 to hum.WhisperBlockList.Count-1 do
      if i <= 9 then sui.WhisperBlockNames[i] := hum.WhisperBlockList[i];
   for i:=0 to hum.SlaveList.Count-1 do begin
      cret := hum.SlaveList[i];
      if i <= 4 then begin
         sui.Slaves[i].SlaveName := cret.UserName;
         sui.Slaves[i].SlaveExp := cret.SlaveExp;
         sui.Slaves[i].SlaveExpLevel := cret.SlaveExpLevel;
         sui.Slaves[i].SlaveMakeLevel := cret.SlaveMakeLevel;
         sui.Slaves[i].RemainRoyalty := (cret.MasterRoyaltyTime - GetTickCount) div 1000;  //초단위
         sui.Slaves[i].HP := cret.WAbil.HP;
         sui.Slaves[i].MP := cret.WAbil.MP;
      end;
   end;

   //추가 (sonmg 2005/06/03)
   for i:=0 to STATUSARR_SIZE - 1 do begin
      sui.StatusValue[i] := hum.StatusValue[i];
   end;

   for i:=0 to EXTRAABIL_SIZE - 1 do begin
      sui.ExtraAbil[i] := hum.ExtraAbil[i];
      if hum.ExtraAbilTimes[i] > GetTickCount then
      sui.ExtraAbilTimes[i] :=  hum.ExtraAbilTimes[i]- GetTickCount//남은 시간만 저장함
      else sui.ExtraAbilTimes[i] := 0;
   end;

   sui.ItemExpPoint := hum.ItemExpPoint;  // (sonmg 2005/11/16)
end;

procedure TUserEngine.LoadServerShiftData (psui: PTServerShiftUserInfo; var hum: TUserHuman);
var
   i: integer;
   pslave: PTSlaveInfo;
begin

   if psui.GroupOwner <> '' then begin
      //그룹처리는 다음에 한다. (복잡하다)
   end;
   hum.BoHearCry := psui.BoHearCry;
   hum.BoHearWhisper := psui.BoHearWhisper;
   hum.BoHearGuildMsg := psui.BoHearGuildMsg;
   hum.BoSysopMode := psui.BoSysopMode;
   hum.BoSuperviserMode := psui.BoSuperviserMode;
   hum.BoSlaveRelax := psui.BoSlaveRelax;  // (sonmg 2005/01/21)

   for i:=0 to 9 do
      if psui.WhisperBlockNames[i] <> '' then begin
         hum.WhisperBlockList.Add (psui.WhisperBlockNames[i]);
         break;
      end;
   for i:=0 to 4 do
      if psui.Slaves[i].SlaveName <> '' then begin
         new (pslave);
         pslave^ := psui.Slaves[i];
            // 2003/06/12 슬레이브 패치
            hum.PrevServerSlaves.Add (pslave);  //스레드에 안전하지 않음
            //hum.SendDelayMsg(hum, RM_MAKE_SLAVE, 0, integer(pslave), 0, 0, '', 500);
      end;
   for i:=0 to EXTRAABIL_SIZE-1 do begin
      hum.ExtraAbil[i] := psui.ExtraAbil[i];

      if psui.ExtraAbilTimes[i] > 0 then
      hum.ExtraAbilTimes[i] := psui.ExtraAbilTimes[i] + GetTickCount  //저장된 시간은 남은 시간임
      else
      hum.ExtraAbilTimes[i] := 0 ;
   end;

   hum.ItemExpPoint := psui.ItemExpPoint;  // (sonmg 2005/11/16)
end;

procedure TUserEngine.ClearServerShiftData (psui: PTServerShiftUserInfo);
var
   i: integer;
begin
   for i:=0 to WaitServerList.Count-1 do begin
      if PTServerShiftUserInfo(WaitServerList[i]) = psui then begin
         Dispose (PTServerShiftUserInfo(WaitServerList[i]));
         WaitServerList.Delete (i);
         break;
      end;
   end;
end;

function  TUserEngine.WriteShiftUserData (psui: PTServerShiftUserInfo): string;
var
   flname: string;
   i, fhandle, checksum: integer;
   shifttime : LongWord;
begin
   shifttime := GetTickCount;

   Result := '';
   flname := '$_' + IntToStr(ServerIndex) + '_$_' + IntToStr(ShareFileNameNum) + '.shr';
   Inc (ShareFileNameNum);
   try
      checksum := 0;
      for i:=0 to sizeof(TServerShiftUserInfo)-1 do
         checksum := checksum + pbyte(integer(psui)+i)^;
      fhandle := FileCreate (ShareBaseDir + flname);
      if fhandle > 0 then begin
         FileWrite (fhandle, psui^, sizeof(TServerShiftUserInfo));
         FileWrite (fhandle, checksum, sizeof(integer));
         FileClose (fhandle);
         Result := flname;
      end;
   except
      MainOutMessage ('[Exception] WriteShiftUserData..');
   end;

   // TEST_TIME
   if g_TestTime = 13  then
    MainOutMessage( 'SaveShiftTime :'+IntToStr( GetTickCount - shifttime ));

end;

procedure TUserEngine.SendInterServerMsg (msgstr: string);
begin
   usIMLock.Enter;
   try
       if ServerIndex = 0 then begin  //마스터 서버인경우
          FrmSrvMsg.SendServerSocket (msgstr);
       end else begin  //슬래이브 서버인경우
          FrmMsgClient.SendSocket (msgstr);
       end;
   finally
    usIMLock.Leave;
   end;
end;

//같은 서버군에서 서버들 사이의 메세지 전달
procedure TUserEngine.SendInterMsg (ident, svidx: integer; msgstr: string);
begin
   usIMLock.Enter;
   try

       if ServerIndex = 0 then begin  //마스터 서버인경우
          FrmSrvMsg.SendServerSocket (IntToStr(ident) + '/' + EncodeString(IntToStr(svidx)) + '/' +
                                   EncodeString(msgstr));
       end else begin  //슬래이브 서버인경우
          FrmMsgClient.SendSocket (IntToStr(ident) + '/' + EncodeString(IntToStr(svidx)) + '/' +
                                   EncodeString(msgstr));
       end;

   finally
    usIMLock.Leave;
   end;
end;

function  TUserEngine.UserServerChange (hum: TUserHuman; svindex: integer): Boolean;
var
   flname: string;
   sui: TServerShiftUserInfo;
begin
   Result := FALSE;
   MakeServerShiftData (hum, sui);
   flname := WriteShiftUserData (@sui);
   if flname <> '' then begin

      hum.TempStr := flname;  //나중에 이동하려는 서버에서 잘 받았는지 확인하는데 쓰임

      SendInterServerMsg (IntToStr (ISM_USERSERVERCHANGE) + '/' +
                              EncodeString(IntToStr(svindex)) + '/' +
                              EncodeString(flname));

      Result := TRUE;
   end;
end;

procedure TUserEngine.GetISMChangeServerReceive (flname: string);
var
    i: integer;
    hum: TUserHuman;
begin
    for i := 0 to ClosePlayers.Count - 1 do begin
        hum := TUserHuman(ClosePlayers[i]);
        if hum.TempStr = flname then begin
            hum.BoChangeServerOK := TRUE;
            // TEST_TIME
            if g_TestTime = 16 then MainOutMessage('ISM_CHANGE_SERVER_RECIEVE :'+hum.UserId);
            break;
        end;
    end;
end;


function  TUserEngine.DoUserChangeServer (hum: TUserHuman; svindex: integer): Boolean;
var
   naddr: string;
   nport: integer;
begin
   Result := false;
   //클라이언트에 다음의 재접속 주소와 포트로 재접속을 유도한다.
   if GetMultiServerAddrPort (byte(svindex), naddr, nport) then begin
      hum.SendDefMessage (SM_RECONNECT, 0, 0, 0, 0, naddr + '/' + IntToStr(nport));
      Result := true;
   end;
end;

procedure TUserEngine.OtherServerUserLogon (snum: integer; uname: string);
var
   i: integer;
   str, name, apmode: string;
begin
   apmode := GetValidStr3 (uname, name, [':']);
   for i:=OtherUserNameList.Count-1 downto 0 do begin
      if CompareText (OtherUserNameList[i], name) = 0 then begin
         OtherUserNameList.Delete (i);
      end;
   end;
   OtherUserNameList.AddObject (name, TObject(snum));

   // 2003/03/18 테스트 서버 인원 제한
   if BoTestServer then begin                  // gadget:테스트서버용
      if StrToInt(apmode) = 1 then begin
         Inc(FreeUserCount);
      end;
   end else begin
      if Str_ToInt(apmode,0) = 1 then begin
         Inc(FreeUserCount);
      end;
   end;
   // TO_PDS: Add User To UserMgr When Other Server Login...
   UserMgrEngine.AddUser( name , 0 , snum + 4 , 0 ,0, 0);
end;

procedure TUserEngine.OtherServerUserLogout (snum: integer; uname: string);
var
   i: integer;
   str, name, apmode: string;
begin
   apmode := GetValidStr3 (uname, name, [':']);
   for i:=0 to OtherUserNameList.Count-1 do begin
      if (CompareText (OtherUserNameList[i], name) = 0) and (integer(OtherUserNameList.Objects[i]) = snum) then begin
         OtherUserNameList.Delete (i);

         // TO_PDS: Add User To UserMgr When Other Server Login...
          UserMgrEngine.DeleteUser( name );
         break;
      end;
   end;
   // 2003/03/18 테스트 서버 인원 제한
   if BoTestServer then begin                   // gadget:테스트서버용
      if StrToInt(apmode) = 4 then begin
         Dec(FreeUserCount);
      end;
   end else begin
      if Str_ToInt(apmode,0) = 1 {3} then begin
         Dec(FreeUserCount);
      end;
   end;
end;

procedure TUserEngine.AccountExpired (uid: string);
var
   i: integer;
begin
   for i:=0 to RunUserList.Count-1 do begin
      if CompareText (TUserHuman(RunUserList.Objects[i]).UserId, uid) = 0 then begin
         TUserHuman(RunUserList.Objects[i]).BoAccountExpired := TRUE;
         break;
      end;
   end;
end;

function TUserEngine.TimeAccountExpired( uid :string ):Boolean;
var
   i: integer;
begin
   Result := false;
   for i:=0 to RunUserList.Count-1 do begin
      if CompareText (TUserHuman(RunUserList.Objects[i]).UserId, uid) = 0 then begin
         Result := TUserHuman(RunUserList.Objects[i]).SetExpiredTime( 5 * 60 + 1 ); // 초 입력
         break;
      end;
   end;
end;

//프리미엄 이벤트(sonmg 2005/07/29)
function TUserEngine.ApplyPremiumUser( iGrade: integer; uid, uname, sBirthday :string ):Boolean;
var
   i: integer;
   hum: TUserHuman;
   dwBirth: DWORD;
   nowdate, birthdate: TDateTime;
   nowyear, nowmon, nowday: WORD;
   birthyear, birthmon, birthday: WORD;
   str, syear, smon, sday: string;
begin
   Result := FALSE;
   hum := nil;
   for i:=0 to RunUserList.Count-1 do begin
      hum := TUserHuman(RunUserList.Objects[i]);
      if CompareText (hum.UserId, uid) = 0 then begin
         if CompareText (hum.UserName, uname) = 0 then begin
//            hum.PremiumGrade := iGrade;

            str := Trim(sBirthday);
            str := GetValidStr3 (str, syear, ['-']);
            str := GetValidStr3 (str, smon, ['-']);
            str := GetValidStr3 (str, sday, ['-']);

            birthyear := StrToInt(syear);
            birthmon := StrToInt(smon);
            birthday := StrToInt(sday);

            if (birthyear = 0) and (birthmon = 0) and (birthday = 0) then break;

{
            //몰아서 서비스 적용(8/9~10/31)
            if (birthmon = 8) and (birthday >= 9) then begin
               hum.PremiumBirthDay := TRUE;
               hum.PremiumGrade := 2;
               hum.RecalcAbilitys;
               Result := TRUE;
               break;
            end else if (birthmon = 9) or (birthmon = 10) then begin
               hum.PremiumBirthDay := TRUE;
               hum.PremiumGrade := 2;
               hum.RecalcAbilitys;
               Result := TRUE;
               break;
            end;
}

            nowdate := Now;
            DecodeDate (nowdate, nowyear, nowmon, nowday);
            if (nowmon = birthmon) and (nowday = birthday) then begin
               hum.PremiumBirthDay := TRUE;
               hum.PremiumGrade := 2;
            end;
            nowdate := Now - 3;
            DecodeDate (nowdate, nowyear, nowmon, nowday);
            if (nowmon = birthmon) and (nowday = birthday) then begin
               hum.PremiumBirthDay := TRUE;
               hum.PremiumGrade := 2;
            end;
            nowdate := Now - 2;
            DecodeDate (nowdate, nowyear, nowmon, nowday);
            if (nowmon = birthmon) and (nowday = birthday) then begin
               hum.PremiumBirthDay := TRUE;
               hum.PremiumGrade := 2;
            end;
            nowdate := Now - 1;
            DecodeDate (nowdate, nowyear, nowmon, nowday);
            if (nowmon = birthmon) and (nowday = birthday) then begin
               hum.PremiumBirthDay := TRUE;
               hum.PremiumGrade := 2;
            end;
            nowdate := Now + 1;
            DecodeDate (nowdate, nowyear, nowmon, nowday);
            if (nowmon = birthmon) and (nowday = birthday) then begin
               hum.PremiumBirthDay := TRUE;
               hum.PremiumGrade := 2;
            end;
            nowdate := Now + 2;
            DecodeDate (nowdate, nowyear, nowmon, nowday);
            if (nowmon = birthmon) and (nowday = birthday) then begin
               hum.PremiumBirthDay := TRUE;
               hum.PremiumGrade := 2;
            end;
            nowdate := Now + 3;
            DecodeDate (nowdate, nowyear, nowmon, nowday);
            if (nowmon = birthmon) and (nowday = birthday) then begin
               hum.PremiumBirthDay := TRUE;
               hum.PremiumGrade := 2;
            end;

            hum.RecalcAbilitys;
            Result := TRUE;
            break;
         end;
      end;
   end;
end;

function TUserEngine.ApplyEventUser( uid, uname :string ):Boolean;
var
   i: integer;
   hum: TUserHuman;
begin
   Result := FALSE;
   hum := nil;
   for i:=0 to RunUserList.Count-1 do begin
      hum := TUserHuman(RunUserList.Objects[i]);
      if CompareText (hum.UserId, uid) = 0 then begin
         if CompareText (hum.UserName, uname) = 0 then begin
            hum.EventCheckFlag := TRUE;

            hum.RecalcAbilitys;
            Result := TRUE;
            break;
         end;
      end;
   end;
end;

{------------------------ ProcessUserHumans --------------------------}



procedure TUserEngine.ProcessUserHumans;
   function OnUse (uname: string): Boolean;
   var
      k: integer;
   begin
      Result := FALSE;
      if FrontEngine.IsDoingSave (uname) then begin  //아직 저장이 채 되지 않았음
         Result := TRUE;
         exit;
      end;
      for k:=0 to RunUserList.Count-1 do begin
         if CompareText (RunUserList[k], uname) = 0 then begin  //현재 접속중
            Result := TRUE;
            break;
         end;
      end;
   end;
   function MakeNewHuman (pui: PTUserOpenInfo): TUserHuman;
   var
      i: integer;
      mapenvir: TEnvirnoment;
      hum: TUserHuman;
      hmap: string;
      pshift: PTServerShiftUserInfo;
   label
      ERROR_MAP;
   begin
      Result := nil;
      try
         hum := TUserHuman.Create;
         if hum = nil then begin
            MainOutMessage ('[TUserEngine.ProcessUserHumans]TUserHuman.Create Error');
         end;

         if not BoVentureServer then begin
            //서버이동중인 데이타가 있으면 가져온다.
            pshift := GetServerShiftInfo (pui.Name, pui.ReadyInfo.Certification);
         end else begin
            pshift := nil;
            //모험서버의 Shift 정보를 읽는다.

         end;
         if pshift = nil then begin //서버 이동이 아님
            FDBLoadHuman (@pui.Rcd, hum);
            hum.RaceServer := RC_USERHUMAN;
            if hum.HomeMap = '' then begin //아무것도 설정되어 있지 않음...
               ERROR_MAP:
               GetRandomDefStart (hmap, hum.HomeX, hum.HomeY, hum.Job);
               hum.HomeMap := hmap;

               hum.MapName := hum.HomeMap;    //HomeMap을 기준으로
               hum.CX := hum.GetStartX;
               hum.CY := hum.GetStartY;

               if hum.Abil.Level = 0 then begin  //아이디를 처음 만든 경우
                  with hum.Abil do begin
                     Level := 1;
                     AC    := 0;
                     MAC   := 0;
                     DC    := MakeWord(1,2);
                     MC    := MakeWord(1,2);
                     SC    := MakeWord(1,2);
                     MP    := 15;
                     HP    := 15;
                     MaxHP := 15;
                     MaxMP := 15;
                     Exp   := 0;
                     MaxExp := 100;
                     Weight := 0;
                     MaxWeight := 30;
                     FameCur := 0;
                     FameBase := 0;
                  end;
                  hum.FirstTimeConnection := TRUE;
               end;
            end;

            mapenvir := GrobalEnvir.ServerGetEnvir (ServerIndex, hum.MapName);
            if mapenvir <> nil then begin
               //문파 대련 이벤트 방에 있는 경우 검사
               if mapenvir.Fight3Zone then begin  //문파 대련 이벤트 방에 있음.
                  //죽은 경우
                  if hum.Abil.HP <= 0 then begin
                     if hum.FightZoneDieCount < 3 then begin
                        hum.Abil.HP := hum.Abil.MaxHP;
                        hum.Abil.MP := hum.Abil.MaxMP;
                        hum.MustRandomMove := TRUE;
                     end;
                  end;
               end else
                  hum.FightZoneDieCount := 0;

            end;

            hum.MyGuild := GuildMan.GetGuildFromMemberName (hum.UserName);
            if (mapenvir <> nil) then begin
               //사북성의 내성으로 재접하려는 경우
               if //(UserCastle.CorePEnvir = mapenvir) or
                  (UserCastle.BoCastleUnderAttack and UserCastle.IsCastleWarArea (mapenvir, hum.CX, hum.CY))
               then begin
                  if not UserCastle.IsCastleMember (hum) then begin
                     //사북성 문파 이외
                     hum.MapName := hum.HomeMap;
                     hum.CX := hum.HomeX - 2 + Random(5);
                     hum.CY := hum.HomeY - 2 + Random(5);
                  end else begin
                     //사북성 문파 문원
                     if UserCastle.CorePEnvir = mapenvir then begin
                        //사북성 문원이 내성안에서 재접하려고 하면
                        //귀성 자리로 나온다
                        hum.MapName := UserCastle.GetCastleStartMap;
                        hum.CX := UserCastle.GetCastleStartX;
                        hum.CY := UserCastle.GetCastleStartY;
                     end;
                  end;
               end;

            end;

            //2001-03-21일 빨갱이 수치, 경치 조정으로 DB일괄 수정됨
            if (hum.DBVersion <= 1) and (hum.Abil.Level >= 1) then begin
               //빨갱이를 노랭이로 만든다.
               //if hum.PKLevel >= 2 then hum.PlayerKillingPoint := 150;
               //경험치를 재 설정함.
               //hum.Abil.Exp := Round((hum.Abil.Exp / hum.Abil.MaxExp) * hum.GetNextLevelExp (hum.Abil.Level));
               //hum.Reset_6_28_bugitems;
               hum.DBVersion := 2;
            end;

{$IFDEF FOR_ABIL_POINT}
//4/16일 부터 적용
            //보너스 포인트를 적용했는지 검사
            if hum.BonusApply <= 3 then begin
               hum.BonusApply := 4;
               hum.BonusPoint := GetLevelBonusSum (hum.Job, hum.Abil.Level);
               FillChar (hum.BonusAbil, sizeof(TNakedAbility), #0);
               FillChar (hum.CurBonusAbil, sizeof(TNakedAbility), #0);
               hum.MapName := hum.HomeMap;  //마을에서 시작하게 한다. (체력이 떨어져 있기 때문에)
               hum.CX := hum.HomeX - 2 + Random(5);
               hum.CY := hum.HomeY - 2 + Random(5);
            end;
{$ENDIF}

            //맵이 오류 난 경우
            if GrobalEnvir.GetEnvir (hum.MapName) = nil then begin
               hum.Abil.HP := 0;  //죽은 것으로 처리
            end;

            //죽은 경우
            if hum.Abil.HP <= 0  then begin
               hum.ResetCharForRevival;
               if hum.PKLevel < 2 then begin
                  if UserCastle.BoCastleUnderAttack and UserCastle.IsCastleMember (hum) then begin
                     hum.MapName := UserCastle.CastleMap;
                     hum.CX := UserCastle.GetCastleStartX;
                     hum.CY := UserCastle.GetCastleStartY;
                  end else begin
                     hum.MapName := hum.HomeMap;
                     hum.CX := hum.HomeX - 2 + Random(5);
                     hum.CY := hum.HomeY - 2 + Random(5);
                  end;
               end else begin
                  //피케이는 성밖에서 시작한다.
                  hum.MapName := BADMANHOMEMAP; //hum.HomeMap;
                  hum.CX := BADMANSTARTX - 6 + Random(13);   //유배지
                  hum.CY := BADMANSTARTY - 6 + Random(13);   //hum.HomeY;
               end;
               hum.Abil.HP := 14; //hum.Abil.MaxHP div 3;
            end;
            hum.InitValues;  //WAbil := Abil

            mapenvir := GrobalEnvir.ServerGetEnvir (ServerIndex, hum.MapName);
            if mapenvir = nil then begin // ..
               //해당맵이 다른 서버에 있는경우 (서버 이동해야 함)
               hum.Certification := pui.ReadyInfo.Certification;
               hum.UserHandle := pui.ReadyInfo.shandle;
               hum.GateIndex := pui.ReadyInfo.GateIndex;
               hum.UserGateIndex := pui.ReadyInfo.UserGateIndex;
               hum.WAbil := hum.Abil; //기본 초기화
               hum.ChangeToServerNumber := GrobalEnvir.GetServer (hum.MapName);

               //테스트
               if hum.Abil.HP <> 14 then  //죽어서 들어온게 아님
                  MainOutMessage ('chg-server-fail-1 [' + IntToStr(ServerIndex) + '] -> [' +
                           IntToStr(hum.ChangeToServerNumber) + '] [' + hum.MapName);

               UserServerChange (hum, hum.ChangeToServerNumber);
               DoUserChangeServer (hum, hum.ChangeToServerNumber);
               hum.Free;
               exit;
            end else begin
               //현재 서버에 접속..
               for i:=0 to 4 do begin
                  if not mapenvir.CanWalk (hum.CX, hum.CY, TRUE) then begin
                     hum.CX := hum.CX - 3 + Random (6);
                     hum.CY := hum.CY - 3 + Random (6);
                  end else
                     break;
               end;
               if not mapenvir.CanWalk (hum.CX, hum.CY, TRUE) then begin
                  //테스트
                  MainOutMessage ('chg-server-fail-2 [' + IntToStr(ServerIndex) + '] ' +
                           IntToStr(hum.CX) + ':' + IntToStr(hum.CY) + ' [' + hum.MapName);

                  //걸을 수 없는 맵인 경우(잘못된 좌표)
                  hum.MapName := DefHomeMap[hum.Job];    //이 서버에 꼭 있는 맵이어야 함
                  mapenvir := GrobalEnvir.GetEnvir (DefHomeMap[hum.Job]);  //꼭 있음.
                  hum.CX := DefHomeX[hum.Job];
                  hum.CY := DefHomeY[hum.Job];
               end;
            end;
            hum.PEnvir := mapenvir;
            if hum.PEnvir = nil then begin
               MainOutMessage ('[Error] hum.PEnvir = nil');
               goto ERROR_MAP;
            end;

            hum.ReadyRun := FALSE; //초기화가 되어야 한다는 표시

         end else begin
            //pui : DB 서버에서 읽은 데이타
            //pshift : 서버 이동으로 읽은 데이타
//          FDBLoadHuman (@pui.Rcd, hum);
            FDBLoadHuman (@pshift.Rcd, hum);

            //map, hp 등은 서버이동의 데이타를 사용한다. 서버이동의 데이타를 읽지 못했을 경우
            //잘 못될 가능성이 있음.
            hum.MapName := pshift.rcd.Block.DBHuman.MapName;
            hum.CX := pshift.rcd.Block.DBHuman.CX;
            hum.CY := pshift.rcd.Block.DBHuman.CY;
            // TO PDS
            // hum.Abil := pshift.rcd.Block.DBHuman.Abil;
            hum.Abil.Level := pshift.rcd.Block.DBHuman.Abil_Level;
            hum.Abil.HP    := pshift.rcd.Block.DBHuman.Abil_HP;
            hum.Abil.MP    := pshift.rcd.Block.DBHuman.Abil_MP;
            hum.Abil.EXP   := pshift.rcd.Block.DBHuman.Abil_EXP;
            hum.Abil.FameCur   := pshift.rcd.Block.DBHuman.Abil_FameCur;   //현재 명성치(2004/10/22)
            hum.Abil.FameBase  := pshift.rcd.Block.DBHuman.Abil_FameBase;  //누적 명성치(2004/10/22)

            //서버 이동전의 데이타를 읽음
            LoadServerShiftData (pshift, hum);
            ClearServerShiftData (pshift);

            mapenvir := GrobalEnvir.ServerGetEnvir (ServerIndex, hum.MapName);
            if mapenvir = nil then begin // ..
               //테스트
               MainOutMessage ('chg-server-fail-3 [' + IntToStr(ServerIndex) + ']  ' +
                           IntToStr(hum.CX) + ':' + IntToStr(hum.CY) + ' [' + hum.MapName);

               hum.MapName := DefHomeMap[hum.Job];
               mapenvir := GrobalEnvir.GetEnvir (DefHomeMap[hum.Job]);  //꼭 있음.
               hum.CX := DefHomeX[hum.Job];
               hum.CY := DefHomeY[hum.Job];
            end else begin
               if not mapenvir.CanWalk (hum.CX, hum.CY, TRUE) then begin
                  //테스트
                  MainOutMessage ('chg-server-fail-4 [' + IntToStr(ServerIndex) + ']  ' +
                           IntToStr(hum.CX) + ':' + IntToStr(hum.CY) + ' [' + hum.MapName);

                  hum.MapName := DefHomeMap[hum.Job];
                  mapenvir := GrobalEnvir.GetEnvir (DefHomeMap[hum.Job]);  //꼭 있음.
                  hum.CX := DefHomeX[hum.Job];
                  hum.CY := DefHomeY[hum.Job];
               end;
            end;
            hum.InitValues;
            hum.PEnvir := mapenvir;
            if hum.PEnvir = nil then begin
               MainOutMessage ('[Error] hum.PEnvir = nil');
               goto ERROR_MAP;
            end;

            hum.ReadyRun := FALSE; //초기화가 되어야 한다는 표시
            hum.LoginSign := TRUE; //서버이동은 공지사항 안보이게
            hum.BoServerShifted := TRUE;
         end;

         hum.UserId             := pui.ReadyInfo.UserId;
         hum.UserAddress        := pui.ReadyInfo.UserAddress;
         hum.UserHandle         := pui.ReadyInfo.shandle;
         hum.UserGateIndex      := pui.ReadyInfo.UserGateIndex;
         hum.GateIndex          := pui.ReadyInfo.GateIndex;
         hum.Certification      := pui.ReadyInfo.Certification;
         hum.ApprovalMode       := pui.ReadyInfo.ApprovalMode;
         hum.AvailableMode      := pui.ReadyInfo.AvailableMode;
         hum.UserConnectTime    := pui.ReadyInfo.ReadyStartTime;
         hum.ClientVersion      := pui.ReadyInfo.ClientVersion;
         hum.LoginClientVersion := pui.ReadyInfo.LoginClientVersion;
         hum.ClientCheckSum     := pui.ReadyInfo.ClientCheckSum;

         Result := hum;
      except
         MainOutMessage ('[TUserEngine] MakeNewHuman exception');
      end;
   end;
var
   i, k: integer;
   start: longword;
   tcount: integer;
   pui: PTUserOpenInfo;
   pc: PTChangeUserInfo;
   hum: TUserHuman;
   newlist, cuglist, cuhlist: TList;
   bugcount: integer;
   lack: Boolean;
   down : integer;
begin
   bugcount := 0;
   down := 0;
   start := GetTickCount;
   if GetTickCount - hum200time > 200 then begin
   bugcount := 1;

      try
         hum200time := GetTickCount;
         newlist := nil;
         cuglist := nil;
         cuhlist := nil;
         try
   bugcount := 2;

            usLock.Enter;
            //게임 준비를 마친 유저들...
            for i:=0 to ReadyList.Count-1 do begin
   bugcount := 3;

               if not FrontEngine.HasServerHeavyLoad and not OnUse(ReadyList[i]) then begin
   bugcount := 4;

                  pui := PTUserOpenInfo (ReadyList.Objects[i]);
                  hum := MakeNewHuman (pui);
                  if hum <> nil then begin
   bugcount := 5;

                     RunUserList.AddObject (ReadyList[i], hum);
                     SendInterMsg (ISM_USERLOGON, ServerIndex, hum.UserName+ ':' + IntToStr(hum.ApprovalMode));
                     // 2003/03/18 테스트 서버 인원 제한
                     if BoTestServer then begin    // gadget:테스트서버용
                        if hum.ApprovalMode = 1 then
                           Inc(UserEngine.FreeUserCount);
                     end else begin
                        if hum.ApprovalMode = 1 then
                           Inc(UserEngine.FreeUserCount);
                     end;

                     if newlist = nil then newlist := TList.Create;
                     newlist.Add (hum);
                     // TO PDS Add To UserMgr ... 4 = Connext SercerIndex 0 ...
                     UserMgrEngine.AddUser( hum.UserName ,Integer(hum), ServerIndex + 4 , hum.GateIndex , hum.UserGateIndex, hum.UserHandle );
                  end;
               end else begin
   bugcount := 6;

                  KickDoubleConnect (ReadyList[i]);
                  ////MainOutMessage ('[Dup] ' + ReadyList[i]); //중복접속
                  if cuglist = nil then begin
                     cuglist := TList.Create;
                     cuhlist := TList.Create;
                  end;
                  cuglist.Add (pointer(TUserHuman(ReadyList.Objects[i]).GateIndex)); //thread lockdown을 피하기 위해서
                  cuhlist.Add (pointer(TUserHuman(ReadyList.Objects[i]).UserHandle));
               end;
   bugcount := 7;
               Dispose (PTUserOpenInfo (ReadyList.Objects[i]));
            end;
            ReadyList.Clear;

            //변경이 완료된 리스트
            for i:=0 to SaveChangeOkList.Count-1 do begin
   bugcount := 8;

               pc := PTChangeUserInfo (SaveChangeOkList[i]);

   bugcount := 9;
               hum := GetUserHuman (pc.CommandWho);
               if hum <> nil then begin
   bugcount := 10;
                  hum.RCmdUserChangeGoldOk (pc.UserName, pc.ChangeGold);
               end;
               Dispose (pc);
            end;
            SaveChangeOkList.Clear;
         finally
            usLock.Leave;
         end;

         if newlist <> nil then begin
            usLock.Enter;
            try
                for i:=0 to newlist.Count-1 do begin
   bugcount := 11;
                   hum := TUserHuman(newlist[i]);
                   RunSocket.UserLoadingOk (hum.GateIndex, hum.UserHandle, hum);
                end;
            finally
              usLock.Leave;
            end;

            newlist.Free;
         end;
         if cuglist <> nil then begin

   bugcount := 12;
            usLock.Enter;
            try
              for i:=0 to cuglist.Count-1 do
              begin
   bugcount := 13;
                 RunSocket.CloseUser (integer(cuglist[i]){GateIndex}, integer(cuhlist[i]){UserHandle});
              end;
            finally
              usLock.Leave;
            end;
   bugcount := 14;

            cuglist.Free;

   bugcount := 15;
            cuhlist.Free;
         end;

      except
         MainOutMessage ('[UsrEngn] Exception Ready, Save, Load...( '+IntToStr(bugcount)+')');
      end;
   end;

   try
      //5분 지나면 Free 시킴
      for i:=0 to ClosePlayers.Count-1 do begin
         hum := TUserHuman(ClosePlayers[i]);
         if GetTickCount - hum.GhostTime > 5 * 60 * 1000 then begin
            try
               TUserHuman(ClosePlayers[i]).Free;  //잔상이 남는다면 에러가날 수 있다.
            except
               MainOutMessage ('[UsrEngn] ClosePlayer.Delete - Free');
            end;
            ClosePlayers.Delete (i);
            break;
         end else begin
            if hum.BoChangeServer then begin
               if hum.BoSaveOk then begin   //저장을 하고 난 후에 서버 이동을 시킨다.
                  if UserServerChange (hum, hum.ChangeToServerNumber) or (hum.WriteChangeServerInfoCount > 20) then begin
                     hum.BoChangeServer := FALSE;
                     hum.BoChangeServerOK := FALSE;
                     hum.BoChangeServerNeedDelay := TRUE;
                     hum.ChangeServerDelayTime := GetTickCount;
                  end else
                     Inc (hum.WriteChangeServerInfoCount);
               end;
            end;
            if hum.BoChangeServerNeedDelay then begin
               if (hum.BoChangeServerOK) or (GetTickCount - hum.ChangeServerDelayTime > 10 * 1000) then begin
                  hum.ClearAllSlaves;  //부하들을 모두 없앤다.
                  hum.BoChangeServerNeedDelay := FALSE;
                  DoUserChangeServer (hum, hum.ChangeToServerNumber);
               end;
            end;
         end;
      end;
   except
      MainOutMessage ('[UsrEngn] ClosePlayer.Delete');
   end;

   lack := FALSE;
   try
      tcount := GetCurrentTime;
      i := HumCur;
      while TRUE do begin
         if i >= RunUserList.Count then break;
         hum := TUserHuman (RunUserList.Objects[i]);
         if tcount - hum.RunTime > hum.RunNextTick then begin
            hum.RunTime := tcount;
            if not hum.BoGhost then begin
               if not hum.LoginSign then begin
                  try
                     //pvDecodeSocketData (hum);
                     hum.RunNotice; //공지사항을 보낸다.
                  except
                     MainOutMessage ('[UsrEngn] Exception RunNotice in ProcessHumans');
                  end;
               end else
                  try
                     down := 1;
                     if not hum.ReadyRun then begin
                        hum.Initialize;  //캐릭 설정을 점검하고 로그인
                        hum.ReadyRun := TRUE;
                     end else begin

                     down := 2;
                        if GetTickCount - hum.SearchTime > hum.SearchRate then begin
                           hum.SearchTime := GetTickCount;
                     down := 3;
                           hum.SearchViewRange;

                     down := 4;
                           hum.ThinkEtc;
                        end;

                     down := 5;
                        if GetTickCount - hum.LineNoticeTime > 5 * 60 * 1000 then begin
                           hum.LineNoticeTime := GetTickCount;
                           if hum.LineNoticeNumber < LineNoticeList.Count then begin
                              //LineNoticeList와 Hum이 같은 스래드 이기 때문에 상관 없다
                              //하지만 다른 스래드가 된다면 LineNoticeList는 반드시 lock 시켜야 한다.
                     down := 6;
                              hum.SysMsg (LineNoticeList[hum.LineNoticeNumber], 2);
                           end;
                           Inc (hum.LineNoticeNumber);
                           if hum.LineNoticeNumber >= LineNoticeList.Count then
                              hum.LineNoticeNumber := 0;
                        end;

                     down := 7;
                        hum.Operate;

                        if ( not FrontEngine.HasServerHeavyLoad ) and  // 저장간격 10분에서 15분 변경 ->30분 변경
                           ( GetTickCount > ( 30 * 60 * 1000 + hum.LastSaveTime ) ) then // 음수가  나올수 있으므로 변경
                        begin
                           hum.LastSaveTime := GetTickCount + LongWord(random( 10 * 60 * 1000 )); // 1 분 랜덤->10분 번경
                     down := 8;
                           hum.ReadySave;
                     down := 9;
                           SavePlayer (hum);
                        end;
                     end;
                  except
                     MainOutMessage ('[UsrEngn] Exception Hum.Operate in ProcessHumans:'+intTOStr(down));
                  end;
            end else begin


               try
                  RunUserList.Delete (i);          bugcount := 2;
                  hum.Finalize;                 bugcount := 3;
               except
                  MainOutMessage ('[UsrEngn] Exception Hum.Finalize in ProcessHumans ' + IntToStr(bugcount));
               end;
               try
                  // TO PDS: Delete User From UserMgr...
                  UserMgrEngine.DeleteUser( hum.UserName );
                  ClosePlayer (hum);            bugcount := 4;
                  hum.ReadySave;
                  SavePlayer (hum);

                  usLock.Enter;
                  try
                  RunSocket.CloseUser (hum.GateIndex, hum.UserHandle);
                  finally
                  usLock.Leave;
                  end;

               except
                  MainOutMessage ('[UsrEngn] Exception RunSocket.CloseUser in ProcessHumans ' + IntToStr(bugcount));
               end;
               SendInterMsg (ISM_USERLOGOUT, ServerIndex, hum.UserName+ ':' + IntToStr(hum.ApprovalMode));


               // 2003/03/18 테스트 서버 인원 제한
               if BoTestServer then begin      // gadget:테스트서버용
                  if hum.ApprovalMode = 4 then
                     Dec(UserEngine.FreeUserCount);
               end;
               continue;
            end;
         end;
         Inc (i);

         if GetTickCount - start > HumLimitTime then begin
            //렉 발생, 다음으로 미룬다.
            lack := TRUE;
            HumCur := i;
            break;
         end;
      end;
      if not lack then HumCur := 0;

   except
      MainOutMessage ('[UsrEngn] ProcessHumans');
   end;

   Inc (HumRotCount);
   if HumCur = 0 then begin  //한바퀴 도는데 걸리는 시간
      HumRotCount := 0;
      humrotatecount := HumRotCount;
      k := GetTickCount - humrotatetime;
      curhumrotatetime := k;
      humrotatetime := GetTickCount;
      if maxhumrotatetime < k then begin
         maxhumrotatetime := k;
      end;
   end;

   curhumtime := GetTickCount - start;
   if maxhumtime < curhumtime then begin
      maxhumtime := curhumtime;
   end;
end;

procedure TUserEngine.ProcessMonsters;
   function GetZenTime (ztime: longword): longword;  //사용자의 수에 따라서 젠의 빠르기가 바뀜.
   var
      r: Real;
   begin
      if ztime < 30 * 60 * 1000 then begin
         r := (GetUserCount - UserFullCount) / ZenFastStep;  //매 200명이 늘때마다 10%씩 몹을 더 젠 시킴
         if r > 0 then begin
            if r > 6 then r := 6;
            Result := ztime - Round ((ztime/10) * r);
         end else
            Result := ztime;
      end else
         Result := ztime;
   end;
var
   i, k, zcount: integer;
   start: longword;
   tcount: integer;
   cret: TCreature;
   pz: PTZenInfo;
   lack, goodzen: Boolean;
begin
   start := GetTickCount;
   pz    := nil;
   try
      lack := FALSE;
      tcount := GetCurrentTime; //GetTickCount;

      pz := nil;
      if GetTickCount - onezentime > 200 then begin
         onezentime := GetTickCount;

         if GenCur < MonList.Count then
            pz := PTZenInfo (MonList[GenCur]);

         if GenCur < MonList.Count-1 then Inc(GenCur)
         else GenCur := 0;

         if pz <> nil then  begin
            if (pz.MonName <> '') and (not BoVentureServer) then begin //모험서버에서는 잰이 안된다.
               if (pz.StartTime = 0) or (GetTickCount - pz.StartTime > GetZenTime(pz.MonZenTime)) then begin
                  zcount := GetMonCount (pz);
                  goodzen := TRUE;
                  if pz.Count > zcount then
                     goodzen := RegenMonsters (pz, pz.Count - zcount);
                  if goodzen then begin
                     if pz.MonZenTime = 180 then begin
                        if GetTickCount >= 60 * 60 * 1000 then
                           pz.StartTime := GetTickCount - (60 * 60 * 1000) + Longword(Random(120 * 60 * 1000))
                        else
                           pz.StartTime := GetTickCount;
                     end else begin
                        pz.StartTime := GetTickCount;
                     end;
                  end;
               end;
               LatestGenStr := pz.MonName + ',' + IntToStr(GenCur) + '/' + IntToStr(MonList.Count);
            end;
         end;

      end;

      MonCurRunCount := 0;

      for i:=MonCur to MonList.Count-1 do begin
         pz := PTZenInfo (MonList[i]);

         if MonSubCur < pz.Mons.Count then k := MonSubCur
         else k := 0;

         MonSubCur := 0;

         while TRUE do begin
            if k >= pz.Mons.Count then break;

            cret := TCreature (pz.Mons[k]);

            if not cret.BoGhost then begin
               if tcount - cret.RunTime > cret.RunNextTick then begin
                  cret.RunTime := tcount;
                  if GetTickCount  > ( cret.SearchRate + cret.SearchTime )then begin
                     cret.SearchTime := GetTickCount;
                     //2003/03/18
                     if(cret.RefObjCount > 0) or (cret.HideMode) then
                        cret.SearchViewRange
                     else
                        cret.RefObjCount := 0;
                  end;

                  try   // 2003-09-09  PDS 에러발생시 몬스터 리스트에서 삭제
                      cret.Run;
                      Inc (MonCurRunCount);
                  except
                      pz.Mons.Delete (k);
                     // cret.Free;
                      cret := nil;
                  end;


               end;
               Inc (MonCurCount);
            end else begin
               //5분이 지나면 free 시킨다.
               if( GetTickCount > ( 5 * 60 * 1000 + cret.GhostTime ))then begin
                  pz.Mons.Delete (k);
                  cret.Free;
                  cret := nil;
                  continue;
               end;
            end;

            Inc (k);

            if ( cret <> nil ) and
            ( GetTickCount - start > MonLimitTime ) then begin
               //렉 발생, 몬스트 움직임은 우선순위가 낮음
               LatestMonStr := cret.UserName + '/' + IntToStr(i) + '/' + IntToStr(k);
               lack := TRUE;
               MonSubCur := k;
               break;
            end;

         end;

         if lack then break;

      end;

      if i >= MonList.Count then begin
         MonCur := 0;
         MonCount := MonCurCount;
         MonCurCount := 0;
         MonRunCount := (MonRunCount + MonCurRunCount) div 2;
      end;

      if not lack then MonCur := 0
      else MonCur := i;

   except
      if pz <> nil then
         MainOutMessage ('[UsrEngn] ProcessMonsters : ' + pz.MonName + '/' + pz.MapName + '/' + IntToStr(pz.X) + ',' + IntToStr(pz.Y) )
      else
         MainOutMessage ('[UsrEngn] ProcessMonsters');
   end;

   curmontime := GetTickCount - start;
   if maxmontime < curmontime then begin
      maxmontime := curmontime;
   end;
end;

procedure TUserEngine.ProcessMerchants;
var
   i: integer;
   start: longword;
   tcount: integer;
   cret: TCreature;
   lack: Boolean;
begin
   start := GetTickCount;
   lack := FALSE;
   try
      tcount := GetCurrentTime;
      for i:=MerCur to MerchantList.Count-1 do begin
         cret := TCreature (MerchantList[i]);
         if not cret.BoGhost then begin
            if (tcount - cret.RunTime > cret.RunNextTick) then begin
               if GetTickCount - cret.SearchTime > cret.SearchRate then begin
                  cret.SearchTime := GetTickCount;
                  cret.SearchViewRange;
               end;
               if tcount - cret.RunTime > cret.RunNextTick then begin
                  cret.RunTime := tcount;
                  cret.Run;
               end;
            end;
         end;
         if GetTickCount - start > NpcLimitTime then begin
            //시작 초과 다음에 처리
            MerCur := i;
            lack := TRUE;
            break;
         end;
      end;
      if not lack then
         MerCur := 0;
   except
      MainOutMessage ('[UsrEngn] ProcessMerchants');
   end;
end;

procedure TUserEngine.ProcessNpcs;
var
   i, tcount: integer;
   start: longword;
   cret: TCreature;
   lack: Boolean;
begin
   start := GetTickCount;
   lack := FALSE;
   try
      tcount := GetCurrentTime;
      for i:=NpcCur to NpcList.Count-1 do begin
         cret := TCreature (NpcList[i]);
         if not cret.BoGhost then begin
            if (tcount - cret.RunTime > cret.RunNextTick) then begin
               if GetTickCount - cret.SearchTime > cret.SearchRate then begin
                  cret.SearchTime := GetTickCount;
                  cret.SearchViewRange;
               end;
               if tcount - cret.RunTime > cret.RunNextTick then begin
                  cret.RunTime := tcount;
                  cret.Run;
               end;
            end;
         end;
         if GetTickCount - start > NpcLimitTime then begin
            //시작 초과 다음에 처리
            NpcCur := i;
            lack := TRUE;
            break;
         end;
      end;
      if not lack then
         NpcCur := 0;
   except
      MainOutMessage ('[UsrEngn] ProcessNpcs');
   end;
end;

{-------------------------- Missions ----------------------------}

function  TUserEngine.LoadMission (flname: string): Boolean;
var
   mission: TMission;
begin
   mission := TMission.Create (flname);
   if not mission.BoPlay then begin
      mission.Free;
      Result := FALSE;
   end else begin
      MissionList.Add (mission);
      Result := TRUE;
   end;
end;

function  TUserEngine.StopMission (missionname: string): Boolean;
var
   i: integer;
begin
   for i:=0 to MissionList.Count-1do begin
      if TMission(MissionList[i]).MissionName = missionname then begin
         TMission(MissionList[i]).BoPlay := FALSE;
         break;
      end;
   end;
   Result := TRUE;
end;

procedure TUserEngine.GetRandomDefStart (var map: string; var sx, sy: integer; job: byte);
var
   n: integer;
begin
//   if StartPoints.Count > 0 then begin
//      if StartPoints.Count > 1 then n := Random(2)
//      else n := 0;
//      if PHILIPPINEVERSION then n := 0;   //필리핀 버젼이면 시작 포인트 고정(sonmg 2006/03/20)
//
//      map := GetStartPointMapName(n);//StartPoints[n];
//      sx := Loword(integer(StartPoints.Objects[n]));
//      sy := Hiword(integer(StartPoints.Objects[n]));
//   end else begin
      map := DefHomeMap[job]; //'0';
      sx := DefHomeX[job];  //DEF_STARTX;
      sy := DefHomeY[job];  //DEF_STARTY;
//   end;
end;

procedure TUserEngine.ProcessMissions;
var
   i: integer;
begin
   try
      for i:=MissionList.Count-1 downto 0 do begin
         if TMission(MissionList[i]).BoPlay then begin
            TMission(MissionList[i]).Run;
         end else begin
            TMission(MissionList[i]).Free;
            MissionList.Delete (i);
         end;
      end;
   except
      MainOutMessage ('[UsrEngn] ProcessMissions');
   end;
end;


procedure TUserEngine.ProcessDragon;
begin
    gFireDragon.Run;
end;
{----------------------- ExecuteRun --------------------------}

procedure TUserEngine.Initialize;
var
   i: integer;
   pz: PTZenInfo;
begin
   LoadRefillCretInfos; //몬스터 리젠 정보를 읽는다.
   InitializeMerchants;
   InitializeNpcs;

   //pz, 몬스터의 MonName 으로 MonRace를 얻어 놓는다.
   for i:=0 to MonList.Count-1 do begin
      pz := PTZenInfo (MonList[i]);
      if pz <> nil then begin
         pz.MonRace := GetMonRace (pz.MonName);
      end;
   end;

end;

procedure TUserEngine.ExecuteRun;
var
   i: integer;
   down : integer;
begin
   runonetime := GetTickCount;
   down := 0;
   try
      ProcessUserHumans;

   down := 1;
      ProcessMonsters;

   down := 2;
      ProcessMerchants;

   down := 3;
      ProcessNpcs;

      if GetTickCount - missiontime > 1000 then begin
         missiontime := GetTickCount;

   down := 4;
         ProcessMissions;

   down := 5;
         CheckServerWaitTimeOut;

   down := 6;
         CheckHolySeizeValid;

      end;//if

   down := 7;
      if GetTickCount - opendoorcheck > 500 then begin
         opendoorcheck := GetTickCount;
         CheckOpenDoors;
      end;//if

   down := 8;
      if GetTickCount - timer10min > 10 * 60 * 1000 then begin //10분에 한 번
         timer10min := GetTickCount;
         NoticeMan.RefreshNoticeList;
         MainOutMessage (DateTimeToStr(Now) + ' User = ' + IntToStr(GetUserCount));
         UserCastle.SaveAll;
         //장원꾸미기 아이템 내구 업데이트
         Inc(gaDecoItemCount);
         if gaDecoItemCount >= 6 then gaDecoItemCount := 0; //6*10분 = 1시간에 한 번
         if gaDecoItemCount = 0 then begin
            GuildAgitMan.DecreaseDecoMonDurability;
         end;
{$IFDEF DEBUG} //sonmg
         //임시 10분에 한번...(sonmg)
         GuildAgitMan.DecreaseDecoMonDurability;
{$ENDIF}
      end;//if

   down := 9;
      if GetTickCount - timer10sec > 10 * 1000 then begin   //10초에 한 번
         timer10sec := GetTickCount;
         FrmIDSoc.SendUserCount (GetRealUserCount);
         GuildMan.CheckGuildWarTimeOut;
         UserCastle.Run;

   down := 91;
         if GetTickCount - timer1min > 60 * 1000 then begin   //1분에 한 번
            timer1min := GetTickCount;
            Inc(gaCount);
            if gaCount >= 10 then gaCount := 0;
            if GuildAgitMan.CheckGuildAgitTimeOut(gaCount) then begin
               //장원게시판 리로드.
               GuildAgitBoardMan.LoadAllGaBoardList('');
            end;
         end;

   down := 10;
         //채금 시간이 끝났는지 검사
         for i:=ShutUpList.Count-1 downto 0 do begin
            if GetCurrentTime > integer(ShutUpList.Objects[i]) then
               ShutUpList.Delete(i);
         end;
      end;//if

   down := 11;
        gFireDragon.Run;

   except
      MainOutMessage ('[UsrEngn] Raise Exception.. :'+intToStr(down));
   end;

   curusrcount := GetTickCount - runonetime;
   if maxusrtime < curusrcount then begin
      maxusrtime := curusrcount;
   end;
end;

function TUserEngine.FindChatLogList( whostr : string ; var idx : integer ):boolean;
var
    i : integer;
begin
    Result := false;
    for i := 0 to ChatLogList.Count - 1 do
    begin
      if ChatLogList.Strings[i] = whostr then
      begin
          Result := true;
          idx := i;
          Exit;
      end;
    end;

end;

procedure TUserEngine.ProcessUserMessage (hum: TUserHuman; pmsg: PTDefaultMessage; pbody: PChar);
var
   head, body, desc : string;
   RandKey: byte;
begin
   try
      if hum.BoGhost then begin
//         MainOutMessage('Ghost tried ProcessUserMessage!!! (' + IntToStr(pmsg.Ident) + ') ' + hum.UserName);
//         exit;
      end;

      if pmsg = nil then exit;
      if pbody = nil then body := ''
      else body := StrPas(pbody);

      case pmsg.Ident of
         CM_TURN,
         CM_WALK,
         CM_RUN,
         CM_HIT,
         CM_POWERHIT,
         CM_LONGHIT,
         CM_WIDEHIT,
         CM_HEAVYHIT,
         CM_BIGHIT,
         CM_FIREHIT,
         // 2003/03/15 신규무공
         CM_CROSSHIT,
         CM_TWINHIT,
         CM_SITDOWN:
            begin
               hum.SendMsg (hum, pmsg.Ident, pmsg.Tag, LoWord(pmsg.Recog), HiWord(pmsg.Recog), 0, '');
               // 서버 이동 중간에는 수 초 동안 패킷 검사 보류
               if GetTickCount - hum.ServerShiftTime > 5000 then begin
                  if pmsg.Etc2 <> ((LOWORD(Integer(hum)) and $EC) or $28) xor $A9 then begin
                     {$IFDEF KOREA}
                     hum.SysMsg ('해킹 프로그램 사용자로 기록되었습니다.', 0);
                     {$ELSE}
                     hum.SysMsg ('Recorded as user of hacking program.', 0);
                     {$ENDIF}
                     hum.EmergencyClose := TRUE;
                     MainOutMessage('MacroProgram : ' + hum.UserName);
                  end;
                  //-----------------------
                  RandKey := LOBYTE(pmsg.Etc) xor $08;
                  if BYTE(((pmsg.Recog and $57CD) + (pmsg.Ident or $48) + (pmsg.Param or $30) + (pmsg.Tag and $2D) + pmsg.Series) xor (GetPublicKey xor RandKey)) <> HIBYTE(pmsg.Etc) then begin
                     {$IFDEF KOREA}
                     hum.SysMsg ('해킹 프로그램 사용자로 기록되었습니다(2).', 0);
                     {$ELSE}
                     hum.SysMsg ('Recorded as user of hacking program(2).'', 0);
                     {$ENDIF}
                     hum.EmergencyClose := TRUE;
                     MainOutMessage('MacroProgram(2) : ' + hum.UserName);
                  end;
                  //-----------------------
               end;
            end;
         CM_SPELL:
            begin
               hum.SendMsg (hum, pmsg.Ident, pmsg.Tag, LoWord(pmsg.Recog), HiWord(pmsg.Recog), MakeLong(pmsg.Param, pmsg.Series), '');
            end;

         CM_QUERYUSERNAME:
            begin
               hum.SendMsg (hum, pmsg.Ident, 0, pmsg.Recog, pmsg.Param{x}, pmsg.Tag{y}, '');
            end;

         CM_SAY:
            begin
               hum.SendMsg (hum, CM_SAY, 0, 0, 0, 0, DecodeString(body));
            end;
         //string 파라메터가 있음.
         CM_DROPITEM,
         CM_TAKEONITEM,
         CM_TAKEOFFITEM,
         CM_EXCHGTAKEONITEM,
         CM_MERCHANTDLGSELECT,
         CM_MERCHANTQUERYSELLPRICE,
         CM_MERCHANTQUERYREPAIRCOST,
         CM_USERSELLITEM,
         CM_USERREPAIRITEM,
         CM_USERSTORAGEITEM,
         CM_USERBUYITEM,
         CM_USERGETDETAILITEM,
         CM_CREATEGROUP,
         CM_CREATEGROUPREQ_OK,   //그룹 결성 확인
         CM_CREATEGROUPREQ_FAIL,   //그룹 결성 확인
         CM_ADDGROUPMEMBER,
         CM_ADDGROUPMEMBERREQ_OK,   //그룹 결성 확인
         CM_ADDGROUPMEMBERREQ_FAIL,   //그룹 결성 확인
         CM_DELGROUPMEMBER,
         CM_DEALTRY,
         CM_DEALADDITEM,
         CM_DEALDELITEM,
         CM_USERTAKEBACKSTORAGEITEM,
         CM_USERMAKEDRUGITEM,
         CM_GUILDADDMEMBER,
         CM_GUILDDELMEMBER,
         CM_GUILDUPDATENOTICE,
         CM_GUILDUPDATERANKINFO,
         CM_LM_DELETE,
         CM_LM_DELETE_REQ_OK,
         CM_LM_DELETE_REQ_FAIL,
         CM_UPGRADEITEM,      // added by sonmg.2003/10/02
         CM_DROPCOUNTITEM,    // added by sonmg.2003/10/11
         CM_USERMAKEITEMSEL,  // added by sonmg.2003/11/3
         CM_USERMAKEITEM,     // added by sonmg.2003/11/3
         CM_ITEMSUMCOUNT,     // added by sonmg.2003/11/10
         CM_MARKET_LIST,
         CM_MARKET_SELL,
         CM_MARKET_BUY,
         CM_MARKET_CANCEL,
         CM_MARKET_GETPAY,
         CM_MARKET_CLOSE,
         CM_GUILDAGITLIST,
         CM_GUILDAGIT_TAG_ADD, // 장원 쪽지
         CM_GABOARD_LIST,   //장원게시판목록
         CM_GABOARD_READ,
         CM_GABOARD_ADD,
         CM_GABOARD_EDIT,
         CM_GABOARD_DEL,
         CM_GABOARD_NOTICE_CHECK,
         CM_DECOITEM_BUY   // added by sonmg.2004/08/04
         :
            begin
               hum.SendMsg (hum, pmsg.Ident, pmsg.Series, pmsg.Recog, pmsg.Param, pmsg.Tag, DecodeString(body));
            end;
         CM_ADJUST_BONUS
         :
            begin
               hum.SendMsg (hum, pmsg.Ident, pmsg.Series, pmsg.Recog, pmsg.Param, pmsg.Tag, body);
            end;
         CM_PICKUP:
            begin
               hum.SendMsg (hum, pmsg.Ident, pmsg.Series, pmsg.Recog, pmsg.Param, pmsg.Tag, '');
               // 서버 이동 중간에는 수 초 동안 패킷 검사 보류
               if GetTickCount - hum.ServerShiftTime > 5000 then begin
                  if pmsg.Etc2 <> ((LOWORD(Integer(hum)) and $EC) or $28) xor $A9 then begin
                     {$IFDEF KOREA}
                     hum.SysMsg ('해킹 프로그램 사용자로 기록되었습니다.', 0);
                     {$ELSE}
                     hum.SysMsg ('Recorded as user of hacking program.', 0);
                     {$ENDIF}
                     hum.EmergencyClose := TRUE;
                     MainOutMessage('MacroProgram : ' + hum.UserName);
                  end;
                  //-----------------------
                  RandKey := LOBYTE(pmsg.Etc) xor $08;
                  if BYTE(((pmsg.Recog and $57CD) + (pmsg.Ident or $48) + (pmsg.Param or $30) + (pmsg.Tag and $2D) + pmsg.Series) xor (GetPublicKey xor RandKey)) <> HIBYTE(pmsg.Etc) then begin
                     {$IFDEF KOREA}
                     hum.SysMsg ('해킹 프로그램 사용자로 기록되었습니다(2).', 0);
                     {$ELSE}
                     hum.SysMsg ('Recorded as user of hacking program(2).', 0);
                     {$ENDIF}
                     hum.EmergencyClose := TRUE;
                     MainOutMessage('MacroProgram(2) : ' + hum.UserName);
                  end;
                  //-----------------------
               end;
            end;

         CM_FRIEND_ADD      ,// 친구추가
         CM_FRIEND_DELETE   ,// 친구삭제
         CM_FRIEND_EDIT     ,// 친구설명 변경
         CM_FRIEND_LIST     ,// 친구 리스트 요청
         CM_TAG_ADD         ,// 쪽지 추가
         CM_TAG_DELETE      ,// 쪽지 삭제
         CM_TAG_SETINFO     ,// 쪽지 상태 변경
         CM_TAG_LIST        ,// 쪽지 리스트 요청
         CM_TAG_NOTREADCOUNT,// 읽지않은 쪽지 개수 요청
         CM_TAG_REJECT_LIST ,// 거부자 리스트
         CM_TAG_REJECT_ADD  ,// 거부자 추가
         CM_TAG_REJECT_DELETE// 거부자 삭제

         :
            begin
               //--------------------------------------------------------
               // 연인의 이름과 같으면 삭제하지 않는다.(2004/11/04)
               //--------------------------------------------------------
               if pmsg.Ident = CM_FRIEND_DELETE then begin
                  if hum.fLover.GetLoverName <> DecodeString(body) then begin
                     UserMgrEngine.ExternSendMsg(stInterServer,ServerIndex,hum.GateIndex ,hum.UserGateIndex, hum.userhandle,hum.UserName ,pmsg^, DecodeString(body));
                  end else begin
                     hum.BoxMsg('연인 관계는 삭제할 수 없습니다.', 0);
                  end;
               end else begin
                  UserMgrEngine.ExternSendMsg(stInterServer,ServerIndex,hum.GateIndex ,hum.UserGateIndex, hum.userhandle,hum.UserName ,pmsg^, DecodeString(body));
               end;
            end;
         else
            hum.SendMsg (hum, pmsg.Ident, pmsg.Series, pmsg.Recog, pmsg.Param, pmsg.Tag, '');
      end;

      //메세지를 받으면 바로 처리한다.  (멀티스래드인경에는 사용할 수 없다)
      if hum.ReadyRun then begin
         case pmsg.Ident of
            CM_TURN,
            CM_WALK,
            CM_RUN,
            CM_HIT,
            CM_POWERHIT,
            CM_LONGHIT,
            CM_WIDEHIT,
            CM_HEAVYHIT,
            CM_BIGHIT,
            CM_FIREHIT,
            // 2003/03/15 신규무공
            CM_CROSSHIT,
            CM_TWINHIT,
            CM_SITDOWN:
               hum.RunTime := hum.RunTime - 100;
         end;
      end;
   except
      MainOutMessage ('[Exception] ProcessUserMessage..');
   end;
end;

// 다른 쓰레드에 메세지 넣을때 사용
procedure TUserEngine.ExternSendMessage( UserName : String ; Ident, wparam: Word; lParam1, lParam2, lParam3: Longint; str: string);
var
   hum : TUserHuman;
begin

   FUserCS.Enter;
   try
      hum := GetUserHuman( UserName );
      if hum <> nil then begin
         hum.SendMsg( hum , Ident, wparam , lParam1, lParam2, lParam3 , str );
      end;
   finally
      FUserCS.Leave;
   end;

end;

function TUserEngine.MakeItemToMap( DropMapName: string; ItemName: String; Amount: integer; dx, dy:integer ):integer;
var
   ps: PTStdItem;
   newpu: PTUserItem;
   pmi, pr: PTMapItem;
   iTemp: integer;
   dropenvir : TEnvirnoment;
begin
   result := 0;

   if ItemName = NAME_OF_MONEY then begin
      ItemName := NAME_OF_GOLD{'금전'};
      Amount := Random( ( Amount div 2 ) +1 ) + ( Amount div 2 );
   end;

   try
      /////////////////////////////////////////////
      //MakeItemToMap
      ps := GetStdItemFromName ( ItemName );

      if ps <> nil then begin
         new (newpu);
         if CopyToUserItemFromName(ps.Name, newpu^) then begin
            new (pmi);
            pmi.UserItem := newpu^;

            if ItemName = NAME_OF_GOLD{'금전'} then begin
               pmi.Name := NAME_OF_GOLD{'금전'};
               pmi.Count := Amount;
               pmi.Looks := GetGoldLooks (Amount);
               pmi.Ownership := nil;
               pmi.Droptime := GetTickCount;
               pmi.Droper := nil;
            end else begin
               // 카운트 아이템
               if (ps.OverlapItem >= 1) then begin
                  iTemp := newpu.Dura;
                  if iTemp > 1 then
                     pmi.Name := ps.Name + '(' + IntToStr(iTemp) + ')'  // gadget :카운터아이템
                  else
                     pmi.Name := ps.Name;
               end else
                  pmi.Name := ps.Name;

               pmi.Looks := ps.Looks;
               if ps.StdMode = 45 then begin  //주사위, 목재
                  pmi.Looks := GetRandomLook (pmi.Looks, ps.Shape);
               end;
               pmi.AniCount := ps.AniCount;
               pmi.Reserved := 0;
               pmi.Count := 1;
               pmi.Ownership := nil;
               pmi.Droptime := GetTickCount;
               pmi.Droper := nil;
            end;

            dropenvir := GrobalEnvir.GetEnvir( DropMapName );
            pr := dropenvir.AddToMap (dx, dy, OS_ITEMOBJECT, TObject(pmi));
            if pr = pmi then begin
               // 결과값이 MakeIndex;
               result := pmi.useritem.MakeIndex ;
               // 서버로그
               MainOutMessage( '[DragonItemGen] ' + pmi.Name + '(' + IntToStr(dx) + ',' + IntToStr(dy) );
            end else begin
               //실패인경우
               Dispose (pmi);
            end;
         end;

         if newpu <> nil then Dispose( newpu );   // Memory Leak sonmg
      end;
      /////////////////////////////////////////////
   except
      MainOutMessage( '[Exception] TUserEngine.MakeItemToMap' );
   end;
end;

end.
