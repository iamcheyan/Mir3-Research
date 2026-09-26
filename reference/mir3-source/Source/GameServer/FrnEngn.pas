unit FrnEngn;

interface

uses
  Windows, Messages, SysUtils, Classes, Graphics, Controls, Dialogs,
  ScktComp, syncobjs, MudUtil, HUtil32, ObjBase, Grobal2, RunDB, MFdbDef,
  M2Share;

type
  TFrontEngine = class(TThread)
  private
    ReadyUsers: TList;  //접속하여서 로딩을 신청한 유저리스트
    SavePlayers: TList;
    ChangeUsers: TList;
    fDBDatas    : TStringList;

    function  OpenUserCharactor (pu: PTReadyUserInfo): Boolean;
    function  OpenChangeSaveUserInfo (pc: PTChangeUserInfo): Boolean;
  protected
    procedure Execute; override;
    procedure ProcessReadyPlayers;
    procedure ProcessEtc;
  public
    constructor Create;
    destructor Destroy; override;
    procedure UserSocketHasClosed (gateindex, uhandle: integer);
    procedure LoadPlayer (uid, chrname, uaddr: string; startnew: Boolean;
                    certify, certmode, availmode,
                    clversion, loginclversion, clientchecksum,
                    shandle, userremotegateindex, gateindex: integer);
    procedure ChangeUserInfos (cmdr, chrname: string; chggold: integer);
    procedure AddDBData( Data : string);
    function  AddSavePlayer (psr: PTSaveRcd) : integer;
    function  IsDoingSave (chrname: string): Boolean;
    function  IsFinished: Boolean; //모든 일을 종료 했는가.
    function  HasServerHeavyLoad: Boolean;
  end;

var
    g_DbUse : Boolean;


implementation

uses
   svMain;

{ TFrontEngine }


constructor TFrontEngine.Create;
begin
   Randomize;

   ReadyUsers := TList.Create;
   SavePlayers := TList.Create;
   ChangeUsers := TList.Create;
   fDBDatas    := TStringList.Create;

   inherited Create (TRUE);
//   FreeOnTerminate := TRUE;
end;

destructor TFrontEngine.Destroy;
begin
   ReadyUsers.Free;
   SavePlayers.Free;
   ChangeUsers.Free;
   fDBDatas.Free;
   inherited Destroy;
end;

procedure TFrontEngine.UserSocketHasClosed (gateindex, uhandle: integer);
var
   i: integer;
   pu: PTReadyUserInfo;
begin
   try
      fuLock.Enter;
      for i:=0 to ReadyUsers.Count-1 do begin
         pu := PTReadyUserInfo (ReadyUsers[i]);
         if (pu.GateIndex = gateindex) and (pu.shandle = uhandle) then begin
            Dispose (pu);
            ReadyUsers.Delete (i);
            break;
         end;
      end;
   finally
      fuLock.Leave;
   end;
end;

procedure TFrontEngine.LoadPlayer (uid, chrname, uaddr: string; startnew: Boolean;
                  certify, certmode, availmode,
                  clversion, loginclversion, clientchecksum,
                  shandle, userremotegateindex, gateindex: integer);
var
   pu: PTReadyUserInfo;
begin
   // TEST_TIME
   if g_TestTime = 2 then  MainOutMessage( 'Loadplayer :'+ uid + ','+ chrname);

   new (pu);
   pu.UserId             := uid;
   pu.UserName           := chrname;
   pu.UserAddress        := uaddr;
   pu.StartNew           := startnew;
   pu.Certification      := certify;
   pu.ClientVersion      := clversion;
   pu.LoginClientVersion := loginclversion;
   pu.ClientCheckSum     := clientchecksum;
   pu.ApprovalMode       := certmode;
   pu.AvailableMode      := availmode;
   pu.Shandle            := shandle;
   pu.UserGateIndex      := userremotegateindex;
   pu.GateIndex          := gateindex;
   pu.ReadyStartTime     := GetTickCount;
   pu.Closed             := FALSE;
   try
      fuLock.Enter;
      ReadyUsers.Add (pu);
   finally
      fuLock.Leave;
   end;
end;

procedure TFrontEngine.ChangeUserInfos (cmdr, chrname: string; chggold: integer);
var
   pc: PTChangeUserInfo;
begin
   new (pc);
   pc.CommandWho := cmdr;
   pc.UserName := chrname;
   pc.ChangeGold := chggold;
   try
      fuLock.Enter;
      ChangeUsers.Add (pc);
   finally
      fuLock.Leave;
   end;
end;

function  TFrontEngine.IsFinished: Boolean;
begin
   Result := FALSE;
   try
      fuLock.Enter;
      if SavePlayers.Count = 0 then Result := TRUE;
   finally
      fuLock.Leave;
   end;
end;

function  TFrontEngine.HasServerHeavyLoad: Boolean;
begin
   Result := FALSE;
   // 한국에선 필요 없을지도...
   try
      fuLock.Enter;
      if SavePlayers.Count >= 1000 then Result := TRUE;
   finally
      fuLock.Leave;
   end;
end;

//UserEngine에서만 호출해야 한다. 다른 스래드에서 사용불가
function TFrontEngine.AddSavePlayer (psr: PTSaveRcd) : integer; //hum: TUserHuman); //UsrEngn에서 호출
begin
   Result := -1;
   try
      fuLock.Enter;
      SavePlayers.Add (psr);
      Result := SavePlayers.Count;
   finally
      fuLock.Leave;
   end;
end;

procedure TFrontEngine.AddDBData ( Data: string );
begin
   try
      fuLock.Enter;
      fDBDatas.Add(Data);
   finally
      fuLock.Leave;
   end;
end;

function  TFrontEngine.IsDoingSave (chrname: string): Boolean;
var
   i: integer;
begin
   Result := FALSE;
   try
      fuLock.Enter;
      for i:=0 to SavePlayers.Count-1 do begin
         if PTSaveRcd (SavePlayers[i]).uname = chrname then begin
            Result := TRUE;
            break;
         end;
      end;
   finally
      fuLock.Leave;
   end;
end;

function  TFrontEngine.OpenUserCharactor (pu: PTReadyUserInfo): Boolean;
var
   pui: PTUserOpenInfo;
   rcd: FDBRecord;
begin
   Result := FALSE;
   if not LoadHumanCharacter (pu.UserId, pu.UserName, pu.UserAddress, pu.Certification, rcd) then begin
      //클라이언트에 에러 메세지를 보낸다.
      fuOpenLock.Enter;
      try
      RunSocket.SendForcedClose (pu.GateIndex, pu.Shandle);
      finally
      fuOpenLock.Leave;
      end;
      exit;
   end;
   new (pui);
   pui.Name := pu.UserName;
   pui.ReadyInfo := pu^;
   pui.Rcd := rcd;
   UserEngine.AddNewUser (pui);
   Result := TRUE;
end;

function  TFrontEngine.OpenChangeSaveUserInfo (pc: PTChangeUserInfo): Boolean;
var
   rcd: FDBRecord;
begin
   Result := FALSE;
   if LoadHumanCharacter ('1', pc.UserName, '1', 1, rcd) then begin
      if (rcd.Block.DBHuman.Gold + pc.ChangeGold > 0) and (rcd.Block.DBHuman.Gold + pc.ChangeGold < MAXGOLD) then begin
         rcd.Block.DBHuman.Gold := rcd.Block.DBHuman.Gold + pc.ChangeGold;
         if SaveHumanCharacter ('1', pc.UserName, 1, rcd) then begin
            UserEngine.ChangeAndSaveOk (pc); //성공했음을 알린다.
            Result := TRUE;
         end;
      end;
   end;
end;

procedure TFrontEngine.ProcessReadyPlayers;
var
   i, k, n: integer;
   pu: PTReadyUserInfo;
   loadlist, savelist, chglist: TList;
   datalist : TStringList;
   p: PTSaveRcd;
   pc: PTChangeUserInfo;
   listtime : LongWord;
   listcount: integer;
   totaltime : LongWord;
begin
   totaltime := GetTickCount;

   loadlist := nil;
   savelist := nil;
   chglist := nil;
   datalist := nil;
   try
      fuLock.Enter;
      if SavePlayers.Count > 0 then begin
         savelist := TList.Create;
         for i:=0 to SavePlayers.Count-1 do  //thread 충돌을 피하기 위해서 복사본을 만든다.
            savelist.Add (SavePlayers[i]);
      end;
      if ReadyUsers.Count > 0 then begin
         loadlist := TList.Create;
         for i:=0 to ReadyUsers.Count-1 do begin
            pu := PTReadyUserInfo (ReadyUsers[i]);
            loadlist.Add (pu);
         end;
         ReadyUsers.Clear;
      end;
      if ChangeUsers.Count > 0 then begin
         chglist := TList.Create;
         for i:=0 to ChangeUsers.Count-1 do begin
            pc := PTChangeUserInfo (ChangeUsers[i]);
            chglist.Add (pc);
         end;
         ChangeUsers.Clear;
      end;
      if FDBDatas.Count > 0 then begin
        DataList := TStringList.Create;
        for i := 0 to fDBDatas.Count -1 do begin
           DataList.Add ( FDBDatas[i]);
        end;
        fDBDatas.Clear;
      end;
   finally
      fuLock.Leave;
   end;

   if savelist <> nil then begin
      //n := 0;
      listtime  := GetTickCount;
      listcount := savelist.Count;

      for i:=0 to savelist.Count-1 do begin
         p := PTSaveRcd(savelist[i]);
         //저장 실패 후 0.5초에 한번씩만 저장 요청
         if GetTickCount - p.savetime > 500 then begin
            if SaveHumanCharacter (p.uId, p.uName, p.Certify, p.Rcd) or (p.savefail > 20) then begin
               if (p.savefail > 20) then MainOutMessage('[Warning] SavePlayers was deleted because of timeover... ' + p.uName);
               try
               fuLock.Enter;
                  try
                     if p.hum <> nil then p.hum.BoSaveOk := TRUE; // 쓰레드 주의
                  except
                     MainOutMessage('NOT BoSaveOK ... ');
                  end;
                  for k:=0 to SavePlayers.Count-1 do begin
                     //저장 성공한 것만 지운다.
                     if SavePlayers[k] = p then begin
                        SavePlayers.Delete (k);
                        Dispose (p);
                        break;
                     end;
                  end;
               finally
                  fuLock.Leave;
               end;
            end else begin //저장 실패
               //저장 실패 시간 기록
               p.savetime := GetTickCount;
               Inc (p.savefail);
            end;
         end;
      end;
      savelist.Free;
      // TEST_TIME
      if g_TestTime = 5 then
        MainOutMessage('SaveListTime:'+IntToStr(GetTickCount-listtime)+','+IntToStr(listcount));
      end;


   if loadlist <> nil then begin
      listtime := GetTickCount;
      listcount := loadlist.Count;

      for i:=0 to loadlist.Count-1 do begin
         //load human here...
         //<rundb>
         g_DBUse := true;
         pu := PTReadyUserInfo (loadlist[i]);
         if not OpenUserCharactor (pu) then
         begin
            // TEST_TIME
            if g_TestTime = 17 then
            MainOutMessage('DONT OPEN CHAR:'+ pu.UserId +','+ pu.UserName + ','+pu.UserAddress);

            fuCloseLock.Enter;
            try
            RunSocket.CloseUser (pu.GateIndex, pu.shandle);
            finally
            fuCloseLock.Leave;
            end;
         end;

         Dispose (loadlist[i]);
      end;
      g_DBUse := false;
      loadlist.Free;

      // TEST_TIME
      if g_TestTime = 6 then
        MainOutMessage('LoadListTime:'+IntToStr(GetTickCount-listtime)+','+IntToStr(listcount));

   end;
   if chglist <> nil then begin
      listtime := GetTickCount;
      listcount:= chglist.Count;
      for i:=0 to chglist.Count-1 do begin
         pc := PTChangeUserInfo (chglist[i]);
         OpenChangeSaveUserInfo (pc);
         Dispose (pc);
      end;
      chglist.Free;

      // TEST_TIME
      if g_TestTime = 7 then
        MainOutMessage('ChgListTime:'+IntToStr(GetTickCount-listtime)+','+IntToStr(listcount));

   end;

   if ( DataList <> nil)then begin
      listtime := GetTickCount;
      listcount:= DataList.Count;

        for  i:= 0 to DataList.Count - 1 do begin
          fuLock.Enter;
          try
          SendNonBlockDatas( DataList[i] );
          finally
          fuLock.Leave;
          end;
        end;
        DataList.Clear;
        DataList.Free;
      // TEST_TIME
      if g_TestTime = 8 then
        MainOutMessage('DataListTime:'+IntToStr(GetTickCount-listtime)+','+IntToStr(listcount));
      end;

      // TEST_TIME
      if g_TestTime = 9 then
      begin
        MainOutMessage('ToTalTime:'+IntToStr(GetTickCount-totaltime));
        g_TestTime := 0;
      end;

end;

procedure TFrontEngine.ProcessEtc;
var
   ahour, amin, asec, amsec: word;
begin
   DecodeTime (Time, ahour, amin, asec, amsec);
   //0: 새벽, 1: 낮, 2: 저녁 3: 밤
   case ahour of
      23, 11: MirDayTime := 2; //저녁
      4, 15: MirDayTime := 0; //새벽
      0..3, 12..14: MirDayTime := 3; //밤
      else MirDayTime := 1;  //낮
   end;
end;


{%%%%%%%%%%%%%%%%%% *Execute* %%%%%%%%%%%%%%%%%%%}

procedure TFrontEngine.Execute;
begin
//   Suspend;
   while TRUE do begin
      try
         ProcessReadyPlayers;
      except
         MainOutMessage ('[FrnEngn] raise exception1..');
      end;

      try
         ProcessEtc;
      except
         MainOutMessage ('[FrnEngn] raise exception2..');
      end;
      sleep (1);
      if Terminated then exit;
   end;
end;

end.
