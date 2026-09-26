unit RunDB;

interface

uses
  Forms, Windows, Messages, SysUtils, Classes, Controls, ExtCtrls, StdCtrls, HUtil32,
  ObjBase, Grobal2, mmsystem, ScktComp, EDCode, Dialogs, mudutil, Envir, MfdbDef;


//DB 서버와 통신하는 부분은 FrnEngn에서만 사용해야만 한다.
procedure FDBLoadHuman (prcd: PFDBRecord; var hum: TUserHuman);
procedure FDBMakeHumRcd (hum: TUserHuman; prcd: PFDBRecord);
function LoadHumanCharacter (uid, usrname, useraddr: string; certify: integer; var rcd: FDBRecord): Boolean;
function SaveHumanCharacter (uid, usrname: string; certify: integer; rcd: FDBRecord): Boolean;
procedure SendNonBlockDatas   ( data : string );
procedure SendRDBSocket (certify: integer; data: string);
function  RunDBWaitMsg (cert: integer; var ident, recog: integer; var rmsg: string; waittime: longword): Boolean;
function  LoadHumanRcd (uid, uname, useraddr: string; certify: integer; var rcd: FDBRecord): Boolean;
function  SaveHumanRcd  (uid, uname: string; certify: integer; rcd: FDBRecord): Boolean;
procedure SendChangeServer (uid, chrname: string; certify: integer);
{procedure ConnectionOpened (uname, raddr: string);
procedure ConnectionClosed (uname, raddr: string);
procedure SaveLogo (logtitle, logdata: string);
procedure SaveSpecFee (Log: integer; addr, usrname: string);
procedure SendCloseUser (uid: string; certify: integer);
procedure SendShareMessage (ident, msg: integer; data: string);}


implementation

uses
   svMain;


var
   LatestDBSendMsg, LatestDBError: integer;
   g_DbUse : Boolean;

procedure MakeDefMsg (var DMsg: TDefaultMessage; msg:word; llong: integer; aparam, atag, nseries: word);
begin
   with DMsg do begin
      Ident := msg;
      Recog := llong;
      Param := aparam;
      Tag	:= atag;
      Series := nseries;
   end;
end;

//FDBRecord -> hum
procedure FDBLoadHuman (prcd: PFDBRecord; var hum: TUserHuman);
var
   i: integer;
   pu: PTUserItem;
   pum: PTUserMagic;
   pdefm: PTDefMagic;
begin
   with prcd.Block.DBHuman do begin
      hum.UserName := UserName;
      hum.MapName := MapName;
      hum.CX := CX;
      hum.CY := CY;
      hum.Dir := Dir;
      hum.Hair := Hair;
      hum.Sex := Sex;
      hum.Job := Job;
      hum.Gold := Gold;
      // TO PDS
      // hum.Abil := Abil;
      hum.Abil.Level := Abil_LEVEL;
      hum.Abil.HP    := Abil_HP;
      hum.Abil.MP    := Abil_MP;
      hum.Abil.EXP   := Abil_EXP;
      hum.Abil.FameCur   := Abil_FameCur;    //현재 명성치(2004/10/22)
      hum.Abil.FameBase  := Abil_FameBase;   //누적 명성치(2004/10/22)
      hum.WAbil.Level:= Abil_LEVEL;
      hum.WAbil.HP   := Abil_HP;
      hum.WAbil.MP   := Abil_MP;
      hum.WAbil.EXP  := Abil_EXP;

      //중복 코드 (sonmg 2004/10/22)
//      hum.wAbil.Level := Abil_LEVEL;
//      hum.wAbil.HP    := Abil_HP;
//      hum.wAbil.MP    := Abil_MP;
//      hum.wAbil.EXP   := Abil_EXP;

      Move (StatusArr, hum.StatusArr, sizeof(word)*STATUSARR_SIZE);
      hum.HomeMap := HomeMap;
      hum.HomeX := HomeX;
      hum.HomeY := HomeY;
      //hum.NeckName := NeckName;  //사용안함
      hum.PlayerKillingPoint := PkPoint;
      if AllowParty > 0 then hum.AllowGroup := TRUE
      else hum.AllowGroup := FALSE;
      hum.FreeGulityCount := FreeGulityCount;
      hum.HumAttackMode := AttackMode;
      hum.IncHealth := byte(IncHealth);
      hum.IncSpell := byte(IncSpell);
      hum.IncHealing := byte(IncHealing);
      hum.FightZoneDieCount := FightZoneDie;
      hum.UserId := UserId;
      hum.DBVersion := DBVersion;
      hum.BonusApply := BonusApply;
{$IFDEF FOR_ABIL_POINT}
      hum.BonusAbil := BonusAbil;
      hum.CurBonusAbil := CurBonusAbil;
      hum.BonusPoint := BonusPoint;
{$ENDIF}
      // To PDS:
      // hum.HungryState := HungryState;
      // hum.TestServerResetCount := TestServerResetCount;
      //hum.DailyQuestNum := LOWORD(DailyQuest);
      //hum.DailyQuestDay := HIWORD(DailyQuest);
      hum.CGHIUseTime := CGHIUseTime;
      hum.BodyLuck := SolveDouble(BodyLuck);
      hum.BoEnableRecall := BoEnableGRecall;
      Move (QuestOpenIndex, hum.QuestIndexOpenStates, MAXQUESTINDEXBYTE);
      Move (QuestFinIndex, hum.QuestIndexFinStates, MAXQUESTINDEXBYTE);
      Move (Quest, hum.QuestStates, MAXQUESTBYTE);
      hum.NotReadTag := HorseRace ; // 2003-08-21 HorseRace 를  NotReadTag 로사용

      hum.WAbil.FameCur   := Abil_FameCur;    //현재 명성치(2004/10/22)
      hum.WAbil.FameBase  := Abil_FameBase;   //누적 명성치(2004/10/22)

      //Bit Flag (sonmg 2005/03/17)  ($01, $02, $04, $08, $10, $20, $40, $80)
      hum.HairColorR := HairColorR;
      hum.HairColorG := HairColorG;
      hum.HairColorB := HairColorB;

      //문파장원 소환 여부
      if (hum.HairColorR and $01) = 0 then hum.BoEnableAgitRecall := FALSE
      else                                 hum.BoEnableAgitRecall := TRUE;

{
      //시간계정 만료 여부
      if (hum.HairColorR and $02) = 0 then hum.BoAccountExpired := FALSE
      else                                 hum.BoAccountExpired := TRUE;
}
   end;
   with prcd.Block.DBBagItem do begin
      hum.UseItems[U_DRESS]     := uDress;
      hum.UseItems[U_WEAPON]    := uWeapon;
      hum.UseItems[U_RIGHTHAND] := uRightHand;
      hum.UseItems[U_NECKLACE]  := uNecklace;
      hum.UseItems[U_HELMET]    := uHelmet;
      hum.UseItems[U_ARMRINGL]  := uArmRingL;
      hum.UseItems[U_ARMRINGR]  := uArmRingR;
      hum.UseItems[U_RINGL]     := uRingL;
      hum.UseItems[U_RINGR]     := uRingR;
      // 2003/03/15 COPARK 아이템 인벤토리 확장
      hum.UseItems[U_BUJUK]     := uBujuk;
      hum.UseItems[U_BELT]      := uBelt;
      hum.UseItems[U_BOOTS]     := uBoots;
      hum.UseItems[U_CHARM]     := uCharm;

      for i:=0 to MAXBAGITEM-1 do begin
         if Bags[i].Index > 0 then begin
            new (pu);
            pu^ := Bags[i];
            hum.ItemList.Add (pu);
         end;
      end;
   end;
   with prcd.Block.DBUseMagic do begin
      for i:=0 to MAXUSERMAGIC-1 do begin
         if Magics[i].MagicId > 0 then begin
            pdefm := UserEngine.GetDefMagicFromID (Magics[i].MagicId);
            if pdefm <> nil then begin
               new (pum);
               pum.pDef := pdefm;
               pum.MagicId := Magics[i].MagicId;
               pum.Level := Magics[i].Level;
               pum.Key := Magics[i].Key;
               pum.CurTrain := Magics[i].CurTrain;
               hum.MagicList.Add (pum);
            end;
         end else
            break;
      end;
   end;
   with prcd.Block.DBSaveItem do begin
      for i:=0 to MAXSAVEITEM-1 do begin
         if Items[i].Index > 0 then begin
            new (pu);
            pu^ := Items[i];
            hum.SaveItems.Add (pu);
         end;
      end;
   end;
end;

//UserEngine스래드에서만 호출해야 함. 다른 스래드 호출 불가
procedure FDBMakeHumRcd (hum: TUserHuman; prcd: PFDBRecord);
var
   i: integer;
   umi: TUseMagicInfo;
begin
   with prcd.Block.DBHuman do begin
//      UserName := hum.UserName;
        StrPCopy(UserName, hum.UserName); // gadget
        StrPCopy(MapName, hum.MapName); // gadget
//      MapName := hum.MapName;
      CX    := hum.CX;
      CY    := hum.CY;
      Dir   := hum.Dir;
      Hair  := hum.Hair;
      Sex   := hum.Sex;
      Job   := hum.Job;
      Gold  := hum.Gold;
      // TO PDS
      //Abil := hum.Abil;
      Abil_LEVEL := hum.Abil.Level;
//    Abil_HP    := hum.Abil.HP;
//    Abil_MP    := hum.Abil.MP;
      Abil_EXP   := hum.Abil.EXP;

      // TO PDSS
      Abil_HP := hum.WAbil.HP;
      Abil_MP := hum.WAbil.MP;

      Move (hum.StatusArr, StatusArr, sizeof(word)*STATUSARR_SIZE);
//      HomeMap := hum.HomeMap;
      StrPCopy(HomeMap, hum.HomeMap); // gadget
      HomeX := hum.HomeX;
      HomeY := hum.HomeY;
      //NeckName := hum.NeckName;  //사용안함
      PKPoint := hum.PlayerKillingPoint;
      if hum.AllowGroup then AllowParty := 1
      else AllowParty := 0;
      FreeGulityCount := hum.FreeGulityCount;
      AttackMode := hum.HumAttackMode;
      IncHealth := hum.IncHealth;
      IncSpell := hum.IncSpell;
      IncHealing := hum.IncHealing;
      FightZoneDie := hum.FightZoneDieCount;
//      UserId := hum.UserId;
      StrPCopy (UserId, hum.UserId); // gadget
      DBVersion := hum.DBVersion;
      BonusApply := hum.BonusApply;
{$IFDEF FOR_ABIL_POINT}
      BonusAbil := hum.BonusAbil;
      CurBonusAbil := hum.CurBonusAbil;
      BonusPoint := hum.BonusPoint;
{$ENDIF}
      // TO PDS
      // HungryState := hum.HungryState;
      // TestServerResetCount := hum.TestServerResetCount;
      // DailyQuest := MAKELONG(hum.DailyQuestNum, hum.DailyQuestDay);
      CGHIUseTime := hum.CGHIUseTime;
      BodyLuck := PackDouble(hum.BodyLuck);
      BoEnableGRecall := hum.BoEnableRecall;
      Move (hum.QuestIndexOpenStates, QuestOpenIndex, MAXQUESTINDEXBYTE);
      Move (hum.QuestIndexFinStates, QuestFinIndex, MAXQUESTINDEXBYTE);
      Move (hum.QuestStates, Quest, MAXQUESTBYTE);
      HorseRace := hum.NotReadTag; // 2003-08-21 : PDS NotReadTag 추가

      //명성치 추가
      Abil_FameCur   := hum.Abil.FameCur;    //현재 명성치(2004/10/22)
      Abil_FameBase  := hum.Abil.FameBase;   //누적 명성치(2004/10/22)

      //Bit Flag (sonmg 2005/03/17)  ($01, $02, $04, $08, $10, $20, $40, $80)
      HairColorR := hum.HairColorR;
      HairColorG := hum.HairColorG;
      HairColorB := hum.HairColorB;

      //문파장원 소환 여부
      if hum.BoEnableAgitRecall = FALSE then HairColorR := HairColorR and (not $01)
      else                                   HairColorR := HairColorR or $01;

{
      //시간계정 만료 여부
      if hum.BoAccountExpired = FALSE then HairColorR := HairColorR and (not $02)
      else                                 HairColorR := HairColorR or $02;
}      
   end;
   with prcd.Block.DBBagItem do begin
      uDress := hum.UseItems[U_DRESS];
      uWeapon := hum.UseItems[U_WEAPON];
      uRightHand := hum.UseItems[U_RIGHTHAND];
      uNecklace := hum.UseItems[U_NECKLACE];
      uHelmet := hum.UseItems[U_HELMET];
      uArmRingL := hum.UseItems[U_ARMRINGL];
      uArmRingR := hum.UseItems[U_ARMRINGR];
      uRingL := hum.UseItems[U_RINGL];
      uRingR := hum.UseItems[U_RINGR];
      // 2003/03/15 COPARK 아이템 인벤토리 확장
      uBujuk := hum.UseItems[U_BUJUK];
      uBelt  := hum.UseItems[U_BELT];
      uBoots := hum.UseItems[U_BOOTS];
      uCharm := hum.UseItems[U_CHARM];
      for i:=0 to hum.Itemlist.Count-1 do begin
         if i < MAXBAGITEM then begin
            Bags[i] := PTUserItem (hum.Itemlist[i])^;
         end else
            break;
      end;
   end;
   for i:=0 to MAXUSERMAGIC-1 do begin
      if i >= hum.MagicList.Count then break;
      umi.MagicId  := PTUserMagic (hum.MagicList[i]).MagicId;
      umi.Level    := PTUserMagic (hum.MagicList[i]).Level;
      umi.Key      := PTUserMagic (hum.MagicList[i]).Key;
      umi.CurTrain := PTUserMagic (hum.MagicList[i]).CurTrain;

      prcd.Block.DBUseMagic.Magics[i] := umi;
   end;
   with prcd.Block.DBSaveItem do begin
      for i:=0 to hum.SaveItems.Count-1 do begin
         if i < MAXSAVEITEM then begin
            Items[i] := PTUserItem (hum.SaveItems[i])^;
         end;
      end;
   end;
end;

function LoadHumanCharacter (uid, usrname, useraddr: string; certify: integer; var rcd: FDBRecord): Boolean;
var
    loadtime : Longword;
begin
   loadtime := GetTickCount;

   Result := FALSE;
   FillChar (rcd, sizeof(FDBRecord), #0);
   if LoadHumanRcd (uid, usrname, useraddr, certify, rcd) then begin
      if (rcd.Block.DBHuman.UserName = usrname) and
         ((rcd.Block.DBHuman.UserId = '') or (CompareText (rcd.Block.DBHuman.UserId, uid) = 0))
      then
         Result := TRUE;
   end;
   Inc (MirUserLoadCount);

   // TEST_TIME
   if g_TestTime = 4 then
   begin
        MainOutMessage( 'LoadTime:'+IntToStr( GetTickCount - loadtime )+','+ uid+','+usrname);
   end;

end;

function SaveHumanCharacter (uid, usrname: string; certify: integer; rcd: FDBRecord): Boolean;
var
    savetime : longword;
begin
   savetime := GetTickCount;

   Result := SaveHumanRcd (uid, usrname, certify, rcd);
   Inc (MirUserSaveCount);

   // TEST_TIME
   if g_TestTime = 3 then
   begin
        MainOutMessage( 'SaveTime:'+IntToStr( GetTickCount - savetime )+','+ uid+','+usrname);
   end;

end;

procedure SendNonBlockDatas ( data : string );
begin
    SendRDBSocket (0, Data);
end;

procedure SendRDBSocket (certify: integer; data: string);
var
   cc, str: string;
   len: word;
   cert: integer;
begin
   if DBConnected then begin
      try
         csSocLock.Enter;
         // TEST PDS Why delete?
         RDBSocData := '';
      finally
         csSocLock.Leave;
      end;
      len := Length(data) + 6;
      cert := MakeLong ((certify) xor $aa, len);
      cc := EncodeBuffer (@cert, sizeof(integer));
      str := '#' + IntToStr(certify) + '/' + data + cc + '!';
      ReadyDBReceive := TRUE;
      FrmMain.DBSocket.Socket.SendText (str);
   end;
end;


function RunDBWaitMsg (cert: integer; var ident, recog: integer; var rmsg: string; waittime: longword): Boolean;
var
   start: longword;
   len, v: integer;
   w1, w2: word;
   str, data, certify, cc: string;
   msg: TDefaultMessage;
   head, body: string;
   flag: Boolean;
   canceled : Boolean;
   waitcnt : integer;
   EndPosition : integer;
begin
   // pds
//   g_DbUse := true;

   flag := FALSE;
   Result := FALSE;
   start := GetTickCount;
//   canceled := false;
   waitcnt := 0;
   str := '';
   while TRUE do begin

   waitcnt := 1;
      if GetTickCount - start > waittime then begin
         LatestDBError := LatestDBSendMsg;
         break;
      end;

   waitcnt := 2;
      try
         csSocLock.Enter;
//         EndPosition := Pos ('!', RDBSocData);
//         if EndPosition > 0 then begin
            str := str + RDBSocData;
            RDBSocData := '';
//         end;
      finally
         csSocLock.Leave;
      end;

   waitcnt := 3;
      EndPosition := Pos ('!', str);
      if {(str <> '')  and} (EndPosition > 0 )then begin
         data := '';
         str := ArrestStringEx (str, '#', '!', data);

   waitcnt := 4;
         if data <> '' then begin
            data := GetValidStr3 (data, certify, ['/']);

//            canceled := FALSE;
            if Str_ToInt(certify,0) = 0 then
            begin
               // TEST_TIME
               if g_TestTime = 15 then MainOutMessage( 'WAIT CERT is 0');
             // Delete( str,1,EndPosition );
//              data := '';
                continue;
//                canceled := true;
            end
            else
            begin

   waitcnt := 5;
            len := Length (data);
            if (len >= DEFBLOCKSIZE) and (Str_ToInt(certify,0) = cert) then
            begin
               w1 := Str_ToInt (certify,0) xor $aa;
               w2 := word(len);
               v  := MakeLong (w1, w2);
               cc := EncodeBuffer(@v, sizeof(integer));

   waitcnt := 6;
               if CompareBackLStr (data, cc, Length(cc)) then
               begin
                  if len = DEFBLOCKSIZE then
                  begin
                     head := data;
                     body := '';
                  end else
                  begin
                     head := Copy (data, 1, DEFBLOCKSIZE);
                     body := Copy (data, DEFBLOCKSIZE+1, Length(data)-DEFBLOCKSIZE-6);
                  end;
                  msg := DecodeMessage (head);
                  ident := msg.Ident;
                  recog := msg.Recog;
                  rmsg   := body;
                  flag := TRUE;
                  Result := TRUE;
                  break;
               end else
                  Inc (RunFailCount);
            end else
            begin
   waitcnt := 7;
                   Inc (RunFailCount);
            end;

            end; //Str_ToInt(certify,0) = 0

         end;

   waitcnt := 8;
//         if not canceled then break;
      end;
      sleep (0); // 1로 하면 안됨 ... 쓰레드 락걸림
   end;
   if not flag then begin
      MainOutMessage ('[RunDB] DB Wait Error (' + IntToStr(waittime)+')'+TimeToStr(Time)+':'+IntToStr(WaitCnt));
   end;
   if GetTickCount - start > CurrentDBloadingTime then begin
      CurrentDBloadingTime := GetTickCount - start;
   end;
   ReadyDBReceive := FALSE;
   // pds
   // g_DbUse := false;

end;


function  LoadHumanRcd (uid, uname, useraddr: string; certify: integer; var rcd: FDBRecord): Boolean;
var
   ident, recog, cer: integer;
   body, str, accstr, runame, data: string;
   Def: TDefaultMessage;
   lhuman: TLoadHuman;
begin

   cer := GetCertifyNumber;
   MakeDefMsg (Def, DB_LOADHUMANRCD, 0, 0, 0, 0);
//   lhuman.UsrId := uid;
    FillChar(lhuman.UsrId, sizeof(lhuman.UsrId), #0);
    StrPCopy(lhuman.UsrId, uid); // gadget
//   lhuman.ChrName := uname;
    FillChar(lhuman.ChrName, sizeof(lhuman.ChrName), #0);
    StrPCopy(lhuman.ChrName, uname); // gadget
//   lhuman.UsrAddr := useraddr;
   lhuman.CertifyCode := certify;
   str := EncodeMessage (Def) + EncodeBuffer (@lhuman, sizeof(TLoadHuman));
   LatestDBSendMsg := DB_LOADHUMANRCD;
   SendRDBSocket (cer, str);
   if RunDBWaitMsg (cer, ident, recog, body, 5000) then begin
      Result := FALSE;
      if ident = DBR_LOADHUMANRCD then begin
         if recog = 1 then begin
            body := GetValidStr3 (body, str, ['/']);
            runame := DecodeString (str);
            if (runame = uname) then begin //and (Length(body) = UpInt(sizeof(FDBRecord)*4/3)) then begin
               DecodeBuffer (body, @rcd, sizeof(FDBRecord));
               Result := TRUE;
            end else
               Result := FALSE;;
         end else begin
            Result := FALSE;
         end;
      end else
         Result := FALSE;
   end else
      Result := FALSE;
end;

function  SaveHumanRcd (uid, uname: string; certify: integer; rcd: FDBRecord): Boolean;
var
   ident, recog, cer: integer;
   body, upasswd: string;
   Def: TDefaultMessage;
begin

   cer := GetCertifyNumber;
   Result := FALSE;
   {if sachange then begin
      LatestDBSendMsg := DB_SAVEANDCHANGE;
      MakeDefMsg (Def, DB_SAVEANDCHANGE, certify, 0, 0);
   end else begin}
   LatestDBSendMsg := DB_SAVEHUMANRCD;
   MakeDefMsg (Def, DB_SAVEHUMANRCD, certify, 0, 0, 0);
   SendRDBSocket (cer,
                  EncodeMessage (Def) +
                  EncodeString (uid) + '/' +
                  EncodeString (uname) + '/' +
                  EncodeBuffer (@rcd, sizeof(FDBRecord)));
   if RunDBWaitMsg (cer, ident, recog, body, 4999) then begin
      if ident = DBR_SAVEHUMANRCD then begin
         if recog = 1 then begin
            Result := TRUE;
         end;
      end;
   end;

end;

procedure SendCloseUser (uid: string; certify: integer);
var
   body, scert: string;
   ident, recog, cer: integer;
   Def: TDefaultMessage;
begin
   if ServerClosing then exit;
   cer := GetCertifyNumber;
   scert := IntToStr(certify);
   MakeDefMsg (Def, DB_RUNCLOSEUSER, 0, 0, 0, 0);
   LatestDBSendMsg := DB_RUNCLOSEUSER;
   SendRDBSocket (cer, EncodeMessage (Def) + EncodeString (uid + '/' + scert));
   RunDBWaitMsg (cer, ident, recog, body, 2000);
end;

procedure SendChangeServer (uid, chrname: string; certify: integer);
var
   body: string;
   ident, recog, cer: integer;
   Def: TDefaultMessage;
begin
   cer := GetCertifyNumber;
   MakeDefMsg (Def, DB_CHANGESERVER, certify, 0, 0, 0);
   LatestDBSendMsg := DB_CHANGESERVER;
   SendRDBSocket (cer, EncodeMessage (Def) + EncodeString (uid + '/' + chrname));
   RunDBWaitMsg (cer, ident, recog, body, 2000);
end;


//  Log SOCKET

{---------------------------------------------}
(*
procedure SendLogDataSocket (data: string);
begin
   if LogDataConnected then begin
      try
         SocSendLock.Enter;
         FrmSrvMain.LogDataSocket.Socket.SendText ('#' + data + '!');
      finally
         SocSendLock.Leave;
      end;
   end;
end;


procedure ConnectionOpened (uname, raddr: string);
var
   Def: TDefaultMessage;
   ident, recog: integer;
   body: string;
begin
//   ConnectMan.WriteAddConnectionInfo ('O', uname, raddr);
   MakeDefMsg (Def, DB_CONNECTIONOPEN, 0, 0, 0, 0);
   SendLogDataSocket (EncodeMessage (Def) + EncodeString (uname + '/' + raddr));
end;

procedure ConnectionClosed (uname, raddr: string);
var
   Def: TDefaultMessage;
   ident, recog: integer;
   body: string;
begin
//   ConnectMan.WriteAddConnectionInfo ('X', uname, raddr);
   MakeDefMsg (Def, DB_CONNECTIONCLOSE, 0, 0, 0, 0);
   SendLogDataSocket (EncodeMessage (Def) + EncodeString (uname + '/' + raddr));
end;


procedure SaveLogo (logtitle, logdata: string);
var
   Def: TDefaultMessage;
   ident, recog: integer;
begin
//   SaveWhisper.AddSaveWhisper (logtitle, logdata);
   MakeDefMsg (Def, DB_SAVELOGO, 0, 0, 0, 0);
   SendLogDataSocket (EncodeMessage (Def) + EncodeString (logtitle + '/' + logdata));
end;

procedure SaveSpecFee (Log: integer; addr, usrname: string);
var
   Def: TDefaultMessage;
begin
   MakeDefMsg (Def, DB_SAVESPECFEE, 0, 0, 0, Log);
   SendLogDataSocket (EncodeMessage (Def) + EncodeString (addr + '/' + usrname));
end;

procedure SendShareMessage (ident, msg: integer; data: string);
var
   sm: TShortMessage;
   str: string;
begin
   sm.Ident := ident;
   sm.msg := msg;
   if LoginConnected then begin
      if data = '' then str := EncodeBuffer(@sm, sizeof(TShortMessage))
      else str := EncodeBuffer(@sm, sizeof(TShortMessage)) + EncodeString(data);
      try
         SocSendLock.Enter;
         FrmSrvMain.MidSocket.Socket.SendText ('#' + str + '!');
      finally
         SocSendLock.Leave;
      end;
   end;
end;   *)


end.
