unit Magic;

interface

uses
  Windows, Messages, SysUtils, Classes, Graphics, Controls, Dialogs,
  ScktComp, syncobjs, MudUtil, HUtil32, Grobal2, Envir, EdCode, ObjBase,
  M2Share, Event;


type
   TMagicManager = class
   private
   public
      constructor Create;
      function  MPow (pum: PTUserMagic): integer;
      function  MagPushAround (user: TCreature; pushlevel: integer): integer; //0..3
      function  MagLightingShock (user, target: TCreature; x, y, shocklevel: integer): Boolean;
      function  MagTurnUndead (user, target: TCreature; x, y, mlevel: integer): Boolean;
      function  MagLightingSpaceMove (user: TCreature; slevel: integer): Boolean;
      function  MagMakeHolyCurtain (user: TCreature; htime, x, y: integer): integer;
      function  MagMakeFireCross (user: TCreature; dam, htime, x, y: integer): integer;
      function  MagBigHealing (user: TCreature; pwr, x, y: integer): Boolean;
      function  MagBigExplosion (user: TCreature; pwr, x, y, wide: integer): Boolean;
      function  MagDragonFire (user: TCreature; pwr, skilllevel: integer): Boolean;
      function  MagElecBlizzard (user: TCreature; pwr: integer): Boolean;
      function  MagMakePrivateTransparent (user: TCreature; htime: integer): Boolean;
      function  MagMakeGroupTransparent (user: TCreature; x, y, htime: integer): Boolean;
      function  IsSwordSkill (mid: integer): Boolean;
      function  SpellNow (user: TCreature; pum: PTUserMagic; xx, yy: integer; target: TCreature ; spell : integer): Boolean;
      // 2003/07/15 신규무공
      function  MagMakePrivateClean (user: TCreature; x, y, pct: integer): Boolean;
      procedure WindCutHit  ( user , target : TCreature ; hitPwr ,magpwr: integer );
      function  MagWindCut (user: TCreature; skilllevel: integer): Boolean;
      // 2004/06/23 신규무공
      function  MagPullMon (user, target: TCreature; skilllevel: integer): Boolean;
      function  MagBlindEye (user, target: TCreature; pum: PTUserMagic): Boolean;

   end;


implementation

uses
   svMain;


constructor TMagicManager.Create;
begin
   inherited Create;
end;

//검술인지 아닌지 구분..
//검술은 키룰 눌러 사용하는 마법이 아님
function  TMagicManager.IsSwordSkill (mid: integer): Boolean;
begin
   Result := FALSE;
   //2003/03/15 신규무공 추가
   case mid of
      3, 4, 7, 12, 25, 26, 27, 34, 38: Result := TRUE;
   end;
end;

function  TMagicManager.MPow (pum: PTUserMagic): integer;
begin
   Result := pum.pDef.MinPower + Random(pum.pDef.MaxPower - pum.pDef.MinPower);
end;

//pushlevel = 0..3
function  TMagicManager.MagPushAround (user: TCreature; pushlevel: integer): integer;
var
   i, ndir, levelgap, push: integer;
   cret: TCreature;
begin
   Result := 0;
   for i:=0 to user.VisibleActors.Count-1 do begin
      cret := TCreature (PTVisibleActor(user.VisibleActors[i]).cret);
      if (abs(user.CX-cret.CX) <= 1) and (abs(user.CY-cret.CY) <= 1) then begin
         if (not cret.Death) and (cret <> user) then begin
            if (user.Abil.Level > cret.Abil.Level) and (not cret.StickMode) then begin
               levelgap := user.Abil.Level - cret.Abil.Level;
               if (Random(20) < 6+pushlevel*3+levelgap) then begin  //수련정도에 따라서
                  if user.IsProperTarget(cret) then begin
                     push := 1 + _MAX(0,pushlevel-1) + Random(2);
                     ndir := GetNextDirection (user.CX, user.CY, cret.CX, cret.CY);
                     cret.CharPushed (ndir, push);
                     Inc(cret.PushedCount);
                     Inc (Result);
                  end;
               end;
            end;
         end;
      end;
   end;
end;

function  TMagicManager.MagDragonFire( user : TCreature ; pwr, skilllevel : integer ) :Boolean;
var
   i: integer;
   rlist: TList;
   cret: TCreature;
   wide : integer;
   realpwr : integer;
begin
   Result := FALSE;

   realpwr := pwr;
   rlist := TList.Create;
   wide := 2;
   user.GetMapCreatures (user.PEnvir, user.CX, user.CY, wide, rlist);
   for i:=0 to rlist.Count-1 do begin
      cret := TCreature (rlist[i]);
      if user.IsProperTarget (cret) then begin
         user.SelectTarget (cret);
         //화룡기염 무공수정
         if (abs(user.CX - cret.CX) >= 2) or (abs(user.CY - cret.CY) >= 2) then begin
            realpwr := (pwr * 8) div 10;
         end else begin
            realpwr := pwr;
         end;
         cret.SendMsg (user, RM_MAGSTRUCK, 0, realpwr, 0, 0, '');
         Result := TRUE;
      end;
   end;
   rlist.Free;

end;

function  TMagicManager.MagLightingShock (user, target: TCreature; x, y, shocklevel: integer): Boolean;
var
   ran: integer;
begin
   Result := FALSE;
   if (target.RaceServer <> RC_USERHUMAN) and (Random(4-shocklevel) = 0) then begin
      target.TargetCret := nil;
      //팁: 내부하에게 뢰혼격을 쓰면 멈춘다.
      if target.Master = user then begin
         target.MakeHolySeize ((10 + shocklevel * 5) * 1000);  //정신을 잃음, 적을 잃어버림
         Result := TRUE;
         exit;
      end;

      if (Random(2) = 0) then begin
         if target.Abil.Level <= user.Abil.Level + 2 then begin
            if Random(3) = 0 then begin
               if (10 + target.Abil.Level) < Random(20 + user.Abil.Level + shocklevel * 5) then begin
//                  if (not target.NoMaster) and
//                     (target.LifeAttrib = LA_CREATURE) and
//                     (target.RaceServer <> RC_CLONE  ) and
//                     (target.RaceServer <> RC_ANGEL  ) and
                     //2003/02/11 최대래밸 변경
//                     (target.Abil.Level < MAXKINGLEVEL-1) and     //50
//                     (user.SlaveList.Count < (2 + shocklevel) and
                  if user.EnableRecallMob( target , shockLevel ) then begin
                     //생명있는몹이고, 레벨이 50미만이어야 하고, 부하수가 5마리 미만인 경우
                     ran := target.WAbil.MaxHP div 100;

                     if target.RaceServer = RC_GHOST_TIGER then ran := ran div 4;

                     if ran <= 2 then ran := 2
                     else ran := ran + ran;

                     if (target.Master <> user) and (Random(ran) = 0) then begin
                        target.BreakCrazyMode;
                        if target.Master <> nil then //남에 몹을 꼬심
                           target.WAbil.HP := target.WAbil.HP div 10;  //
                        target.Master := user;  //소환몹을 뺏어온다.
                        target.MasterRoyaltyTime := GetTickCount +
                                                    longword(20 + shocklevel * 20 +
                                                             Random(user.Abil.Level * 2))
                                                    * 60 * 1000;
                        target.SlaveMakeLevel := shocklevel;
                        if target.SlaveLifeTime = 0 then target.SlaveLifeTime := GetTickCount;
                        //target.SlaveExpLevel := 0;
                        target.BreakHolySeize;
                        if target.NextWalkTime > 1500-(shocklevel*200)  then target.NextWalkTime := 1500-(shocklevel*200);
                        if target.NextHitTime > 2000-(shocklevel*200) then target.NextHitTime := 2000-(shocklevel*200);
                        //target.FeatureChanged;
                        target.UserNameChanged;
                        user.SlaveList.Add (target);
                     end else begin
                        if (Random(20) = 0) then begin
                           target.WAbil.HP := 0;  //바로 죽는다.
                        end;
                     end;
                  end else begin
                     if (target.LifeAttrib = LA_UNDEAD) and (Random(2) = 0) then begin
                        target.WAbil.HP := 0;  //바로 죽는다.
                     end;
                  end;
               end else begin
                  if (target.LifeAttrib <> LA_UNDEAD) and (Random(2) = 0) then begin //언데드가 아닌경우 폭주상태
                     target.MakeCrazyMode (10 + Random(20));
                  end;
               end;
            end else begin
               if target.LifeAttrib <> LA_UNDEAD then begin //언데드가 아닌경우 폭주상태
                  target.MakeCrazyMode (10 + Random(20));
               end;
            end;
         end;
      end else begin
         target.MakeHolySeize ((10 + shocklevel * 5) * 1000);  //정신을 잃음, 적을 잃어버림
      end;
      Result := TRUE;
   end else
      if Random(2) = 0 then
         Result := TRUE;
end;

function  TMagicManager.MagTurnUndead (user, target: TCreature; x, y, mlevel: integer): Boolean;
var
   lvgap: integer;
begin
   Result := FALSE;
   if (not target.NeverDie) and
      (target.LifeAttrib = LA_UNDEAD)
   then begin
      TAnimal(target).Struck (user);
      if target.TargetCret = nil then begin  //놀고 있을때 턴언데드가 오면 잠시 도망감
         TAnimal(target).BoRunAwayMode := TRUE;
         TAnimal(target).RunAwayStart := GetTickCount;
         TAnimal(target).RunAwayTime := 10 * 1000;
      end;
      user.SelectTarget (target);
      // 유저 52레벨 문제 수정(sonmg 2004/09/08)
      if (target.Abil.Level < (_MIN(user.Abil.Level, 51) - 1 + Random(4))) and
         //2003/02/11 최대래밸 변경
         (target.Abil.Level < MAXKINGLEVEL-1)   //50 -> 61
      then begin
         lvgap := user.Abil.Level - target.Abil.Level;
         if Random(100) < (15 + mlevel * 7 + lvgap) then begin
            target.SetLastHiter (user);
            target.WAbil.HP := 0;  //바로 죽는다.
            Result := TRUE;
         end;
      end;
   end;
end;

function  TMagicManager.MagLightingSpaceMove (user: TCreature; slevel: integer): Boolean;
var
   oldenvir: TEnvirnoment;
   hum: TUserHuman;
begin
   Result := FALSE;
   if not user.BoTaiwanEventUser then begin
      if not (user.PEnvir.NoEscapeMove or user.PEnvir.NoTeleportMove) then begin  //아공행법 사용불가(sonmg)
         if Random(11) < 4 + slevel*2 then begin
            user.SendRefMsg (RM_SPACEMOVE_HIDE2, 0, 0, 0, 0, '');
            if user is TUserHuman then begin
               oldenvir := user.PEnvir;

               TUserHuman(user).RandomSpaceMove (user.HomeMap, 1);

               if oldenvir <> user.PEnvir then begin  //실질적으로 다른 맵으로 이동 하였음
                  if user.RaceServer = RC_USERHUMAN then begin
//                     hum := TUserHuman (self); //공포의버그
                     hum := TUserHuman (user);   // 옳은코드
                     hum.BoTimeRecall := FALSE;    //TimeRecall 취소
                     hum.BoTimeRecallGroup := FALSE;    //TimeRecall 취소
                  end;
               end;
            end;
            Result := TRUE;
         end;
      end;
   end;
end;

function  TMagicManager.MagMakeHolyCurtain (user: TCreature; htime, x, y: integer): integer;
var
   event: TEvent;
   i: integer;
   rlist: TList;
   cret: TCreature;
   phs: PTHolySeizeInfo;
begin
   Result := 0;
   if user.PEnvir.CanWalk (x, y, TRUE) then begin
      rlist := TList.Create;
      phs := nil;
      user.GetMapCreatures (user.PEnvir, x, y, 1, rlist);
      for i:=0 to rlist.Count-1 do begin
         cret := TCreature (rlist[i]);
         if (cret.RaceServer >= RC_ANIMAL) and
            (cret.Abil.Level < (user.Abil.Level - 1 + Random(4))) and
            //2003/02/11 최대래밸 변경
            (cret.Abil.Level < MAXKINGLEVEL-1) and    //50 -> 61
            (cret.Master = nil)
         then begin  //결계에 걸린다.
            cret.MakeHolySeize (htime * 1000);
            if phs = nil then begin
               phs := new (PTHolySeizeInfo);    //결계정보
               FillChar (phs^, sizeof(THolySeizeInfo), #0);
               phs.seizelist := TList.Create;
               phs.OpenTime := GetTickCount;  //결계가 최소로 생성된 시간(결계의 최대시간은 3분)
               phs.SeizeTime := htime * 1000; //결계의 지속시간
            end;
            phs.seizelist.Add (cret);  //결계에 걸린 몹을 기록, 나중에 결계가 해지되었는지를 알기위해
            Inc (Result);
         end else begin
            Result := 0;  //결계에 걸리지 않는 것이 포함되어 있으면 취소됨
            break;
         end;
      end;
      rlist.Free;

      if (Result > 0) and (phs <> nil) then begin
         //8개의 빛을 찍는다.
         event := THolyCurtainEvent.Create (user.PEnvir, x-1, y-2, ET_HOLYCURTAIN, htime * 1000);
         EventMan.AddEvent (event);  phs.earr[0] := event;
         event := THolyCurtainEvent.Create (user.PEnvir, x+1, y-2, ET_HOLYCURTAIN, htime * 1000);
         EventMan.AddEvent (event);  phs.earr[1] := event;
         event := THolyCurtainEvent.Create (user.PEnvir, x-2, y-1, ET_HOLYCURTAIN, htime * 1000);
         EventMan.AddEvent (event);  phs.earr[2] := event;
         event := THolyCurtainEvent.Create (user.PEnvir, x+2, y-1, ET_HOLYCURTAIN, htime * 1000);
         EventMan.AddEvent (event);  phs.earr[3] := event;
         event := THolyCurtainEvent.Create (user.PEnvir, x-2, y+1, ET_HOLYCURTAIN, htime * 1000);
         EventMan.AddEvent (event);  phs.earr[4] := event;
         event := THolyCurtainEvent.Create (user.PEnvir, x+2, y+1, ET_HOLYCURTAIN, htime * 1000);
         EventMan.AddEvent (event);  phs.earr[5] := event;
         event := THolyCurtainEvent.Create (user.PEnvir, x-1, y+2, ET_HOLYCURTAIN, htime * 1000);
         EventMan.AddEvent (event);  phs.earr[6] := event;
         event := THolyCurtainEvent.Create (user.PEnvir, x+1, y+2, ET_HOLYCURTAIN, htime * 1000);
         EventMan.AddEvent (event);  phs.earr[7] := event;

         UserEngine.HolySeizeList.Add (phs); //결계추가
      end else begin
         if phs <> nil then begin
            phs.seizelist.Free;
            Dispose (phs);
         end;
      end;
   end;
end;

function  TMagicManager.MagMakeFireCross (user: TCreature; dam, htime, x, y: integer): integer;
var
   event: TEvent;
   i: integer;
   rlist: TList;
   cret: TCreature;
begin
   if user.PEnvir.GetEvent(x, y-1) = nil then begin
      event := TFireBurnEvent.Create (user, x, y-1, ET_FIRE, htime * 1000, dam);
      EventMan.AddEvent (event);
   end;
   if user.PEnvir.GetEvent(x-1, y) = nil then begin
      event := TFireBurnEvent.Create (user, x-1, y, ET_FIRE, htime * 1000, dam);
      EventMan.AddEvent (event);
   end;
   if user.PEnvir.GetEvent(x, y) = nil then begin
      event := TFireBurnEvent.Create (user, x, y, ET_FIRE, htime * 1000, dam);
      EventMan.AddEvent (event);
   end;
   if user.PEnvir.GetEvent(x+1, y) = nil then begin
      event := TFireBurnEvent.Create (user, x+1, y, ET_FIRE, htime * 1000, dam);
      EventMan.AddEvent (event);
   end;
   if user.PEnvir.GetEvent(x, y+1) = nil then begin
      event := TFireBurnEvent.Create (user, x, y+1, ET_FIRE, htime * 1000, dam);
      EventMan.AddEvent (event);
   end;

   Result := 1;
end;

function  TMagicManager.MagBigHealing (user: TCreature; pwr, x, y: integer): Boolean;
var
   i: integer;
   rlist: TList;
   cret: TCreature;
begin
   Result := FALSE;
   rlist := TList.Create;
   user.GetMapCreatures (user.PEnvir, x, y, 1, rlist);
   for i:=0 to rlist.Count-1 do begin
      cret := TCreature (rlist[i]);
      if user.IsProperFriend (cret) then begin
         if cret.WAbil.HP < cret.WAbil.MaxHP then begin
            cret.SendDelayMsg (user, RM_MAGHEALING, 0, pwr, 0, 0, '', 800);
            Result := TRUE;
         end;
         if user.BoAbilSeeHealGauge then begin
            user.SendMsg (cret, RM_INSTANCEHEALGUAGE, 0, 0, 0, 0, '');
         end;
      end;
   end;
   rlist.Free;
end;

function  TMagicManager.MagBigExplosion (user: TCreature; pwr, x, y, wide: integer): Boolean;
var
   i: integer;
   rlist: TList;
   cret: TCreature;
begin
   Result := FALSE;
   rlist := TList.Create;
   user.GetMapCreatures (user.PEnvir, x, y, wide, rlist);
   for i:=0 to rlist.Count-1 do begin
      cret := TCreature (rlist[i]);
      if user.IsProperTarget (cret) then begin
         user.SelectTarget (cret);
         cret.SendMsg (user, RM_MAGSTRUCK, 0, pwr, 0, 0, '');
         Result := TRUE;
      end;
   end;
   rlist.Free;
end;

function  TMagicManager.MagElecBlizzard (user: TCreature; pwr: integer): Boolean;
var
   i, acpwr: integer;
   rlist: TList;
   cret: TCreature;
begin
   Result := FALSE;
   rlist := TList.Create;
   user.GetMapCreatures (user.PEnvir, user.CX, user.CY, 2, rlist);
   for i:=0 to rlist.Count-1 do begin
      cret := TCreature (rlist[i]);
      if cret.LifeAttrib <> LA_UNDEAD then  //언데드 계열 몬스터에게 공격력이 있음
         acpwr := pwr div 10
      else acpwr := pwr;
      if user.IsProperTarget (cret) then begin
         cret.SendMsg (user, RM_MAGSTRUCK, 0, acpwr, 0, 0, '');
         Result := TRUE;
      end;
   end;
   rlist.Free;
end;


//술자가 은신이 된다. 나를 공격하고 있는 몹들이 나를 몰라본다.
//술자가 때리면 공격함.
//술자가 이동하면 해제된다.
function  TMagicManager.MagMakePrivateTransparent (user: TCreature; htime: integer): Boolean;
var
   i: integer;
   rlist: TList;
   cret: TCreature;
begin
   Result := FALSE;
   if user.StatusArr[STATE_TRANSPARENT] > 0 then exit;  //이미 투명

   rlist := TList.Create;
   user.GetMapCreatures (user.PEnvir, user.CX, user.CY, 9, rlist);
   for i:=0 to rlist.Count-1 do begin
      cret := TCreature (rlist[i]);
      if cret.RaceServer >= RC_ANIMAL then begin  //
         if cret.TargetCret = user then begin
            //가까이 있는놈은 1/2 은 넘어간다.
            if (abs(cret.CX-user.CX) > 1) or (abs(cret.CY-user.CY) > 1) or (Random(2) = 0) then begin
               cret.TargetCret := nil;
            end;
         end;
      end;
   end;
   rlist.Free;
   user.StatusArr[STATE_TRANSPARENT] := htime;
   user.CharStatus := user.GetCharStatus;
   user.CharStatusChanged;
   user.BoHumHideMode := TRUE;
   user.BoFixedHideMode := TRUE; //한 자리에서만 은신가능, 이동하면 은신이 풀린다.
   Result := TRUE;
end;

function  TMagicManager.MagMakeGroupTransparent (user: TCreature; x, y, htime: integer): Boolean;
var
   i: integer;
   rlist: TList;
   cret: TCreature;
begin
   Result := FALSE;
   rlist := TList.Create;
   user.GetMapCreatures (user.PEnvir, x, y, 1, rlist);
   for i:=0 to rlist.Count-1 do begin
      cret := TCreature (rlist[i]);
      //if cret.RaceServer = RC_USERHUMAN then begin
      if user.IsProperFriend(cret) then begin  //. or (cret.Master <> nil) then begin  //
         if cret.StatusArr[STATE_TRANSPARENT] = 0 then begin  //투명이 아닌 상태
            cret.SendDelayMsg (cret, RM_TRANSPARENT, 0, htime, 0, 0, '', 800);
            //if MagMakePrivateTransparent (cret, htime) then
            Result := TRUE;
         end;
      end;
   end;
   rlist.Free;
end;

function  TMagicManager.MagMakePrivateClean (user: TCreature; x, y, pct: integer): Boolean;
var
   i: integer;
   rlist: TList;
   cret: TCreature;
begin
   Result := FALSE;
   if Random(100) > pct then exit;

   rlist := TList.Create;
   user.GetMapCreatures (user.PEnvir, x, y, 0, rlist);
   for i:=0 to rlist.Count-1 do begin
      cret := TCreature (rlist[i]);
      if user.IsProperFriend(cret) then begin
         cret.StatusArr[POISON_DECHEALTH] := 0;
         cret.StatusArr[POISON_DAMAGEARMOR] := 0;
         cret.StatusArr[POISON_ICE] := 0;
         cret.StatusArr[POISON_STUN] := 0;
         cret.StatusArr[POISON_DONTMOVE] := 0;
         cret.StatusArr[POISON_STONE] := 0;
         cret.StatusArr[POISON_SLOW] := 0;
         cret.CharStatus := cret.GetCharStatus;
         cret.CharStatusChanged;
         Result := TRUE;
      end;
   end;
   rlist.Free;
end;

procedure TMagicManager.WindCutHit  ( user , target : TCreature ; hitPwr ,magpwr: integer );
var
   i, dam: integer;
//   list: TList;
//   cret: TCreature;
begin
//   list := TList.Create;
//   user.PEnvir.GetAllCreature (target.CX, target.CY, TRUE, list);
//   for i:=0 to list.Count-1 do begin
//      cret := TCreature(list[i]);
      if user.IsProperTarget (target) then begin
         dam := 0;
         dam := dam + target.GetHitStruckDamage (user, hitpwr);
         dam := dam + target.GetMagStruckDamage (user, magpwr);
         if dam > 0 then begin
            target.StruckDamage (dam, user);
            target.SendDelayMsg (TCreature(RM_STRUCK), RM_REFMESSAGE, dam{wparam},
                     target.WAbil.HP{lparam1}, target.WAbil.MaxHP{lparam2}, Longint(user){hiter}, '', 200);
         end;
      end;
//   end;
//   list.Free;

end;

function  TMagicManager.MagWindCut (user: TCreature; skilllevel: integer): Boolean;
var
   i    : integer;
   rlist: TList;
   cret : TCreature;
   pwr  : integer;
   isnear : boolean;
   xx,yy : integer;
   f1x,f1y,f2x,f2y : integer;
   CriticalDamage: Boolean;
   DcRandom: integer;
begin
   Result := FALSE;
   pwr := 0;
   isnear := FALSE;
   rlist := TList.Create;

   // 범위의 줌심이 되는 좌표 변경
   xx := user.CX;
   yy := user.CY;
   f1x := xx;
   f1y := yy;
   f2x := xx;
   f2y := yy;

   case user.dir of
   0 :  begin
            // 강하게 타격이 들어가는 좌표 설정
            f1x := xx;
            f1y := yy - 1;
            f2x := xx;
            f2y := yy - 2;

            //중앙좌표 설정
            yy := yy - 2;

            user.GetMapCreatures (user.PEnvir, xx, yy, 1, rlist);
        end;
   1 :  begin

            // 강하게 타격이 들어가는 좌표 설정
            f1x := xx + 1;
            f1y := yy - 1;
            f2x := xx + 2;
            f2y := yy - 2;

            //중앙좌표 설정
//            xx := xx + 1;
//            yy := yy - 1;
            xx := xx + 2;
            yy := yy - 2;

            user.GetObliqueMapCreatures (user.PEnvir, xx, yy, 1, user.dir, rlist);
        end;
   2 :  begin
            // 강하게 타격이 들어가는 좌표 설정
            f1x := xx + 1;
            f1y := yy ;
            f2x := xx + 2;
            f2y := yy;

            //중앙좌표 설정
            xx  := xx + 2;

            user.GetMapCreatures (user.PEnvir, xx, yy, 1, rlist);
        end;
   3 :  begin
            // 강하게 타격이 들어가는 좌표 설정
            f1x := xx + 1;
            f1y := yy + 1;
            f2x := xx + 2;
            f2y := yy + 2;

            //중앙좌표 설정
//            xx := xx + 1;
//            yy := yy + 1;
            xx := xx + 2;
            yy := yy + 2;

            user.GetObliqueMapCreatures (user.PEnvir, xx, yy, 1, user.dir, rlist);
        end;
   4 :  begin
            // 강하게 타격이 들어가는 좌표 설정
            f1x := xx ;
            f1y := yy + 1;
            f2x := xx ;
            f2y := yy + 2;

            //중앙좌표 설정
            yy := yy + 2;

            user.GetMapCreatures (user.PEnvir, xx, yy, 1, rlist);
        end;
   5 :  begin
            // 강하게 타격이 들어가는 좌표 설정
            f1x := xx - 1;
            f1y := yy + 1;
            f2x := xx - 2;
            f2y := yy + 2;

            //중앙좌표 설정
//            xx := xx - 1;
//            yy := yy + 1;
            xx := xx - 2;
            yy := yy + 2;

            user.GetObliqueMapCreatures (user.PEnvir, xx, yy, 1, user.dir, rlist);
        end;
   6 :  begin
            // 강하게 타격이 들어가는 좌표 설정
            f1x := xx - 1;
            f1y := yy ;
            f2x := xx - 2;
            f2y := yy ;

            //중앙좌표 설정
            xx := xx - 2;

            user.GetMapCreatures (user.PEnvir, xx, yy, 1, rlist);
        end;
   7 :  begin
            // 강하게 타격이 들어가는 좌표 설정
            f1x := xx - 1;
            f1y := yy - 1;
            f2x := xx - 2;
            f2y := yy - 2;

            //중앙좌표 설정
//            xx := xx - 1;
//            yy := yy - 1;
            xx := xx - 2;
            yy := yy - 2;

            user.GetObliqueMapCreatures (user.PEnvir, xx, yy, 1, user.dir, rlist);
        end;
   end;

   // 모션을 취하게 한다음에
//   user.HitMotion( RM_HIT, user.Dir, user.CX, user.CY);
//   user.SendRefMsg( RM_WINDCUT , user.Dir , user.CX , user.CY , 0, '');

   //장비 행운치로 크리티컬 확률 결정
   CriticalDamage := FALSE;
   if Random(100) <= (1 + user.UseItems[U_WEAPON].Desc[3] - user.UseItems[U_WEAPON].Desc[4]) then
      CriticalDamage := TRUE;

   for i:=0 to rlist.Count-1 do begin
      cret := TCreature (rlist[i]);
      if user.IsProperTarget (cret) and ( not cret.Death) and ( not cret.BoGhost ) then
      begin

         // 타격이 강하게 들어가야될 넘과 약하게 들어가야될 넘 판단.
         if ( (cret.CX = f1x) and (cret.CY = f1y) ) or ( (cret.CX = f2x) and (cret.CY = f2y) ) then begin
            isnear := true;
         end else begin
            isnear := false;
         end;

         //크리티컬 데미지
         if CriticalDamage then begin
            DcRandom := HIBYTE(user.Wabil.DC);
         end else begin
            DcRandom := Random( HIBYTE(user.Wabil.DC) );
         end;

         //전방 1*2의 범위:
         //((1.2+0.3*(Lv_S+(LV/20)) * Random(Dcmax)/3+DC
         //그 외 범위: ((0.8+0.2*(Lv_S+LV/20)) * Random(Dcmax)/3+DC
         //타격치가 다른게 적용됨
         if isnear then begin
            pwr := ( (12 + 3 * ( SkillLevel + user.Abil.Level div 20 )) ) * DcRandom div 30 + LOBYTE(user.Wabil.DC);
         end else begin
            pwr := ( (8 + 2 * ( SkillLevel + user.Abil.Level div 20 )) ) * DcRandom div 30 + LOBYTE(user.Wabil.DC);
         end;

         //크리티컬 데미지
         if CriticalDamage then begin
            pwr := pwr * 2;
         end;

         if pwr > 0 then begin
            //테스트용
{
            if isnear then
               cret.MakePoison( POISON_STONE , 2 ,1 )
            else
               cret.MakePoison( POISON_SLOW , 2 ,1 );
}
            windcuthit( user, cret, pwr, 0 );
            Result := TRUE;
         end;
      end;
   end;
   rlist.Free;

end;

//포승검
function  TMagicManager.MagPullMon (user, target: TCreature; skilllevel: integer): Boolean;
var
   levelgap, rush, rushdir, rushDist, Dur: integer;
   SuccessFlag : Boolean;
begin
   Result := FALSE;
   SuccessFlag := FALSE;
   if user = nil then exit;

   if target <> nil then begin
      //사람한테 쓸 수 없음.
      if target.RaceServer = RC_USERHUMAN then exit;

      //움직이지 않는 몬스터는 끌어올 수 없음(2004/12/01)
      if target.StickMode then exit;

      // 너무 가까이 있으면 기술을 쓸 수 없음.
      if (abs(user.CX - target.CX) < 3) and (abs(user.CY - target.CY) < 3) then begin
         {$IFDEF KOREA} user.SysMsg('상대가 너무 가까이 있습니다.', 0);
         {$ELSE}        user.SysMsg('Target is too close.', 0);
         {$ENDIF}
         exit;
      end else if (abs(user.CX - target.CX) > 7) and (abs(user.CY - target.CY) > 7) then begin
//         {$IFDEF KOREA} user.SysMsg('상대가 너무 멀리 있습니다.', 0)
//         {$ELSE}        user.SysMsg('Target is too far.', 0);
//         {$ENDIF}
         exit;
      end;

      // 멀리있는 적을 끌어당긴다.
      user.Dir := GetNextDirectionNew (user.CX, user.CY, target.CX, target.CY);
//      user.SendRefMsg (RM_LIGHTING, user.Dir, user.CX, user.CY, Integer(target), '');

      // 방향별 끌어당기는 거리 조절
      rushDir := ( (user.Dir + 4) mod 8 );
      if rushDir in [0,4] then begin
         rushDist := abs(user.CY - target.CY) -3;
      end else if rushDir in [2,6] then begin
         rushDist := abs(user.CX - target.CX) -3;
      end else begin
         rushDist := _MAX( 0, _MIN( abs(user.CX - target.CX) -2, abs(user.CY - target.CY) -2 ) );
      end;

      if user.IsProperTarget (target) then begin
         // 시체가 아니고 꼬봉몹이 아니어야 함.
//         if (not target.Death) and (target.Master = nil) then begin
         // 시체가 아니어야 함. 꼬봉몹은 가능하게 수정(sonmg 2005/11/2)
         if (not target.Death) then begin
            if (target.Abil.Level < user.Abil.Level + 5 + Random(8)) and (target.Abil.Level < 60) then begin
               levelgap := user.Abil.Level - target.Abil.Level;
               if target.RaceServer = RC_USERHUMAN then begin
                  if (Random(30) < ((skilllevel+1) * 2) + levelgap + 4) then
                     SuccessFlag := TRUE;
               end else if target.RaceServer >= RC_ANIMAL then begin
                  if (Random(30) < ((skilllevel+1) * 3) + levelgap + 9) then
                     SuccessFlag := TRUE;
               end;

               if SuccessFlag then begin
                  // 직선에 있는넘만 땡긴다.(1칸씩 좌우로 있는 넘도 땡긴다)
                  if ( user.CX = target.CX ) or ( user.CY = target.CY ) or ( abs (user.CX-target.CX ) = abs (user.CY-target.CY ))
                        or (user.CX+1 = target.CX) or ( user.CY+1 = target.CY ) or ( abs( abs (user.CX-target.CX ) - abs (user.CY-target.CY ) ) = 1 )
                        or (user.CX-1 = target.CX) or ( user.CY-1 = target.CY ) then begin
                     rush := RushDist;
                     target.CharDrawingRush ( RushDir, rush, false );
                     if target.RaceServer <> RC_USERHUMAN then begin
                        Dur := Round((skilllevel+1) * 1.6) + _MAX(1, 10 - target.SpeedPoint);
                     end else begin
                        Dur := Round((skilllevel+1) * 0.8) + _MAX(1, 10 - target.SpeedPoint);
                        if user.RaceServer = RC_USERHUMAN then begin
                           //정당방어를 위한 기록..
                           target.AddPkHiter (user);
                        end;
                     end;
                     target.MakePoison( POISON_STONE, Dur, 1 );
                     target.SendRefMsg (RM_LOOPNORMALEFFECT, integer(target), 1500, 0, NE_MONCAPTURE, '');
                     Result := TRUE;
                  end else begin
//                     user.SysMsg('끌어 당길 수 없는 위치에 있습니다.', 0);
                  end;
               end;
            end;
         end;
      end;
   end;
end;

function  TMagicManager.MagBlindEye (user, target: TCreature; pum: PTUserMagic): Boolean;
   function GetRPow (pw: word): byte;
   begin
      if Hibyte(pw) > Lobyte(pw) then begin
         Result := Lobyte(pw) + Random(Hibyte(pw)-Lobyte(pw)+1);
      end else
         Result := Lobyte(pw);
   end;
   function GetPower (pw: integer): integer;  //수련 0 단계에서는 1/4의 파워임
   begin
      Result := Round(pw / (pum.pDef.MaxTrainLevel+1) * (pum.Level+1))
                      + (pum.pDef.DefMinPower + Random(pum.pDef.DefMaxPower - pum.pDef.DefMinPower));
   end;
   function GetPower13 (pw: integer): integer;  //수련 0 단계에도 1/3의 파워가 남
   var
      p1, p2: Real;
   begin
      p1 := pw / 3;
      p2 := pw - p1;
      Result := Round(p1 + p2 / (pum.pDef.MaxTrainLevel+1) * (pum.Level+1)
                      + (pum.pDef.DefMinPower + Random(pum.pDef.DefMaxPower - pum.pDef.DefMinPower)));
   end;
var
   pwr : integer;
   levelgap : integer;
//   flag : Boolean;
begin
   Result := FALSE;
//   flag := FALSE;
   if user.IsProperTarget (target) then begin
      //몬스터에만 걸림.
      if target.RaceServer >= RC_ANIMAL then begin
         //스킬정도에 따라 성공여부가 결정
         levelgap := user.Abil.Level - target.Abil.Level;
         if (20 - (pum.Level+1)*2) <= Random(GetRPow(user.WAbil.SC) + (user.Abil.Level div 5) + (levelgap*2)) then begin
            //(상대방 레벨 < 시전자 레벨+1+Random(3)) and (상대방레벨 < 55)
            if (target.Abil.Level < user.Abil.Level + 1 + Random(3)) and (target.Abil.Level < 55) then begin
               if (target.BoGoodCrazyMode = FALSE) then begin //중복해서 걸리지 않는다.
                  //pwr = 폭주시간
                  pwr := GetPower13 (10) + Round(GetRPow(user.WAbil.SC)/3);
                  pwr := pwr + Random(20);
                  target.TargetCret := nil;
                  target.MakeGoodCrazyMode (pwr);
//                  target.SendRefMsg (RM_LOOPNORMALEFFECT, integer(target), pwr * 1000, 0, NE_BLINDEFFECT, '');
//                  flag := TRUE;
//                  user.SysMsg('떠도는 영혼을 빙의시켰습니다.', 1);
               end;
            end;

            Result := TRUE;
         end;
         user.SelectTarget (target);
      end;
   end;

//   if flag = FALSE then
//      user.SysMsg('떠도는 영혼을 빙의시키지 못했습니다.', 0);
end;

function  TMagicManager.SpellNow (user: TCreature; pum: PTUserMagic; xx, yy: integer; target: TCreature ; spell:integer): Boolean;
   function GetRPow (pw: word): byte;
   begin
      if Hibyte(pw) > Lobyte(pw) then begin
         Result := Lobyte(pw) + Random(Hibyte(pw)-Lobyte(pw)+1);
      end else
         Result := Lobyte(pw);
   end;
   function GetPower (pw: integer): integer;  //수련 0 단계에서는 1/4의 파워임
   begin
      Result := Round(pw / (pum.pDef.MaxTrainLevel+1) * (pum.Level+1))
                      + (pum.pDef.DefMinPower + Random(pum.pDef.DefMaxPower - pum.pDef.DefMinPower));
   end;
   function GetPower13 (pw: integer): integer;  //수련 0 단계에도 1/3의 파워가 남
   var
      p1, p2: Real;
   begin
      p1 := pw / 3;
      p2 := pw - p1;
      Result := Round(p1 + p2 / (pum.pDef.MaxTrainLevel+1) * (pum.Level+1)
                      + (pum.pDef.DefMinPower + Random(pum.pDef.DefMaxPower - pum.pDef.DefMinPower)));
   end;
   function CanUseBujuk (user: TCreature; count: integer): integer;
   var
      pstd: PTStdItem;
   begin
      Result := 0;
      // 2003/03/15 COPARK 아이템 인벤토리 확장
      if (user.UseItems[U_BUJUK].Index > 0) then begin   // U_ARMRINGL->U_BUJUK
         pstd := UserEngine.GetStdItem (user.UseItems[U_BUJUK].Index);
         if pstd <> nil then begin
            if (pstd.StdMode = 25) and (pstd.Shape = 5) then begin  //부적
               if Round(user.UseItems[U_BUJUK].Dura / 100) >= (count-1) then begin
                  Result := 1;
               end;
            end;
         end;
      end;
      if (user.UseItems[U_ARMRINGL].Index > 0) and (Result = 0) then begin
         pstd := UserEngine.GetStdItem (user.UseItems[U_ARMRINGL].Index);
         if pstd <> nil then begin
            if (pstd.StdMode = 25) and (pstd.Shape = 5) then begin  //부적
               if Round(user.UseItems[U_ARMRINGL].Dura / 100) >= (count-1) then begin
                  Result := 2;
               end;
            end;
         end;
      end;
   end;
   procedure UseBujuk (user: TCreature);
   var
      hum: TUserHuman;
      pstd: PTStdItem;
   begin
      // 2003/03/15 COPARK 아이템 인벤토리 확장
      //다 쓴 부적은 사라진다.
      if user.UseItems[U_BUJUK].Index > 0 then begin
         if user.UseItems[U_BUJUK].Dura < 100 then begin    // U_ARMRINGL->U_BUJUK
            user.UseItems[U_BUJUK].Dura := 0;
            //다 쓴 부적은 사라진다.
            if user.RaceServer = RC_USERHUMAN then begin
               hum := TUserHuman(user);
               hum.SendDelItem (user.UseItems[U_BUJUK]); //클라이언트에 없어진거 보냄
               //부적 다 닳았을 때 메시지(2004/11/15)
               {$IFDEF KOREA} hum.SysMsg('부적이 다 닳았습니다.', 0);
               {$ELSE}        hum.SysMsg('Your Amulet has been exhausted.', 0);
               {$ENDIF}
            end;
            user.UseItems[U_BUJUK].Index := 0;
         end;
      end;
      if user.UseItems[U_ARMRINGL].Index > 0 then begin
         pstd := UserEngine.GetStdItem (user.UseItems[U_ARMRINGL].Index);
         if pstd <> nil then begin
            if (pstd.StdMode = 25) then begin  //25:부적/독주머니
               if user.UseItems[U_ARMRINGL].Dura < 100 then begin
                  user.UseItems[U_ARMRINGL].Dura := 0;
                  //다 쓴 부적은 사라진다.
                  if user.RaceServer = RC_USERHUMAN then begin
                     hum := TUserHuman(user);
                     hum.SendDelItem (user.UseItems[U_ARMRINGL]); //클라이언트에 없어진거 보냄
                     //부적 다 닳았을 때 메시지(2004/11/15)
                     {$IFDEF KOREA} hum.SysMsg('부적이 다 닳았습니다.', 0);
                     {$ELSE}        hum.SysMsg('Your Amulet has been exhausted.', 0);
                     {$ENDIF}
                  end;
                  user.UseItems[U_ARMRINGL].Index := 0;
               end;
            end;
         end;
      end;
   end;

var
   idx, sx, sy, ndir, pwr,sec, MoC, Dur, Gap : integer;
   train, nofire, needfire : Boolean;
   bhasitem : integer;
   bujuckcount : integer;
   pstd: PTStdItem;
   hum: TUserHuman;
   k : integer;
   TempCret: TCreature;
begin
   Result := FALSE;
   if IsSwordSkill (pum.MagicId) then exit;

   //마법 준비동작을 먼저 보냄
   user.SendRefMsg (RM_SPELL, pum.pDef.Effect, xx, yy, pum.pDef.MagicId, '');
   if target <> nil then
      if target.Death then begin  //타겟이 죽은경우.....
         target := nil;
      end;

   train := FALSE;
   nofire := FALSE;
   needfire := TRUE;
   pwr := 0;
   case pum.pDef.MagicId of
      1, //화염장
      5: //금강화염장
         if user.MagCanHitTarget (user.CX, user.CY, target) then begin
            if user.IsProperTarget (target) then begin
               if (target.AntiMagic <= Random(50)) and (abs(target.CX-xx) <= 1) and (abs(target.CY-yy) <= 1) then begin
                  with user do begin
                     pwr := GetAttackPower (
                                 GetPower (MPow(pum)) + Lobyte(WAbil.MC),
                                 Integer(Hibyte(WAbil.MC)-Lobyte(WAbil.MC)) + 1
                              ); //오버플로 수정(sonmg 2005/02/15)
                     //pwr := GetPower (MPow(pum)) + (Lobyte(WAbil.MC) + Random(Hibyte(WAbil.MC)-Lobyte(WAbil.MC) + 1));
                     //타겟 맞음, 후에 효과나타남
                     //target.SendDelayMsg (user, RM_MAGSTRUCK, 0, pwr, 0, 0, '', 1200 + _MAX(Abs(CX-xx),Abs(CY-yy)) * 50 );
                  end;
                  //rm-delaymagic에서 selecttarget을 처리한다.
                  user.SendDelayMsg (user, RM_DELAYMAGIC, pwr, MakeLong(xx, yy), 2, integer(target), '', 600);
                  if (target.RaceServer >= RC_ANIMAL) then train := TRUE;
               end else
                  target := nil;
            end else
               target := nil;
         end else
            target := nil;
      //2003/03/15 신규무공 추가
      37,//기공파...도사 밀기 무공
      8: //화염풍
         begin
            if MagPushAround (user, pum.Level) > 0 then //주위를 밀어냄
               train := TRUE;
         end;
      9: //염사장
         begin
            ndir := GetNextDirection (user.CX, user.CY, xx, yy);
            if GetNextPosition (user.PEnvir, user.CX, user.CY, ndir, 1, sx, sy) then begin
               GetNextPosition (user.PEnvir, user.CX, user.CY, ndir, 5, xx, yy);
               with user do begin
                  pwr := GetAttackPower (
                           GetPower (MPow(pum)) + Lobyte(WAbil.MC),
                           Integer(Hibyte(WAbil.MC)-Lobyte(WAbil.MC)) + 1
                         ); //오버플로 수정(sonmg 2005/02/15)
               end;
               if user.MagPassThroughMagic (sx, sy, xx, yy, ndir, pwr, FALSE) > 0 then
                  train := TRUE;
            end;
         end;
      10: //뢰인장
         begin
            ndir := GetNextDirection (user.CX, user.CY, xx, yy);
            if GetNextPosition (user.PEnvir, user.CX, user.CY, ndir, 1, sx, sy) then begin
               GetNextPosition (user.PEnvir, user.CX, user.CY, ndir, 8, xx, yy);
               with user do begin
                  pwr := GetAttackPower (
                              GetPower (MPow(pum)) + Lobyte(WAbil.MC),
                              Integer(Hibyte(WAbil.MC)-Lobyte(WAbil.MC)) + 1
                           ); //오버플로 수정(sonmg 2005/02/15)
               end;
               if user.MagPassThroughMagic (sx, sy, xx, yy, ndir, pwr, TRUE) > 0 then
                  train := TRUE;
            end;
         end;
      //2003/03/15 신규무공 추가
      35, //멸천화
      11: //강격
         if user.IsProperTarget (target) then begin
            if target.AntiMagic <= Random(50) then begin
               with user do begin
                  pwr := GetAttackPower (
                              GetPower (MPow(pum)) + Lobyte(WAbil.MC),
                              Integer(Hibyte(WAbil.MC)-Lobyte(WAbil.MC)) + 1
                           ); //오버플로 수정(sonmg 2005/02/15)
               end;
               //user.SelectTarget (target);
               if pum.pDef.MagicId = 11 then begin
                  if target.LifeAttrib = LA_UNDEAD then
                     pwr := Round (pwr * 1.5);
               end else begin
                  if (target.LifeAttrib <> LA_UNDEAD) and (target.RaceServer <> RC_USERHUMAN) then
                     pwr := Round (pwr * 1.2);
               end;
               user.SendDelayMsg (user, RM_DELAYMAGIC, pwr, MakeLong(xx, yy), 2, integer(target), '', 600);
               if (target.RaceServer >= RC_ANIMAL) then train := TRUE;
            end else
               target := nil;
         end else
            target := nil;
      20: //뢰혼격
         if user.IsProperTarget (target) then begin
            if MagLightingShock (user, target, xx, yy, pum.Level) then
               train := TRUE;
         end;
      32: //사자윤회
         if user.IsProperTarget (target) then begin
            if MagTurnUndead (user, target, xx, yy, pum.Level) then
               train := TRUE;
         end;
      21: //아공행법
         begin
            user.SendRefMsg (RM_MAGICFIRE, 0, MakeWord(pum.pDef.EffectType, pum.pDef.Effect), MakeLong(xx, yy), integer(target), '');
            needfire := FALSE;
            if MagLightingSpaceMove (user, pum.Level) then
               train := TRUE;
         end;
      22: //지염술
         begin
            if MagMakeFireCross (user,
                                 user.GetAttackPower (GetPower (MPow(pum)) + Lobyte(user.WAbil.MC),
                                                 Integer(Hibyte(user.WAbil.MC)-Lobyte(user.WAbil.MC)) + 1), //오버플로 수정(sonmg 2005/02/15)
                                 GetPower(10) + GetRPow(user.WAbil.MC) div 2,
                                 xx,
                                 yy) > 0 then begin
               train := TRUE;
            end;
         end;
      23: //폭열파
         begin
            if MagBigExplosion (user,
                                user.GetAttackPower (GetPower (MPow(pum)) + Lobyte(user.WAbil.MC),
                                                 Integer(Hibyte(user.WAbil.MC)-Lobyte(user.WAbil.MC)) + 1), //오버플로 수정(sonmg 2005/02/15)
                                xx,
                                yy,
                                1) then begin
               train := TRUE;
            end;
         end;
      45 : // 화룡기염
         begin
            with user do begin
               // Random(0.8+(0.5*(Lv_S+1)))*Mcmax)+(1.2*Lv_S)*Mc
               pwr := ( Random(8+(5*(pum.level+1)))*Hibyte(WAbil.MC)+(12*pum.level)*Lobyte(WAbil.MC)) div 10;
               //화룡기염 무공수정
               DamageHealth( 10*pum.level, 1 );
            end;

            if MagDragonFire ( user , pwr , pum.Level ) then
                train := true;
         end;

      33: //빙설풍
         begin
            if MagBigExplosion (user,
                                user.GetAttackPower (GetPower (MPow(pum)) + Lobyte(user.WAbil.MC),
                                                 Integer(Hibyte(user.WAbil.MC)-Lobyte(user.WAbil.MC)) + 1), //오버플로 수정(sonmg 2005/02/15)
                                xx,
                                yy,
                                1) then begin
               train := TRUE;
            end;
         end;
      24: //뢰설화
         begin
            if MagElecBlizzard (user,
                                user.GetAttackPower (GetPower (MPow(pum)) + Lobyte(user.WAbil.MC),
                                                 Integer(Hibyte(user.WAbil.MC)-Lobyte(user.WAbil.MC)) + 1) //오버플로 수정(sonmg 2005/02/15)
                                ) then begin
               train := TRUE;
            end;
         end;
      31: //주술의막
         begin
            if user.MagBubbleDefenceUp (pum.Level, GetPower (15 + GetRPow(user.WAbil.MC))) then
               train := TRUE;
         end;


      2: //회복술
         begin
            if target = nil then begin
               target := user;
               xx := user.CX;
               yy := user.CY;
            end;
            if user.IsProperFriend (target) then begin
               with user do begin
                  pwr := GetAttackPower (
                              GetPower (MPow(pum)) + Lobyte(WAbil.SC)*2,
                              Integer(Hibyte(WAbil.SC)-Lobyte(WAbil.SC))*2 + 1
                           ); //오버플로 수정(sonmg 2005/02/15)
               end;
               if target.WAbil.HP < target.WAbil.MaxHP then begin
                  target.SendDelayMsg (user, RM_MAGHEALING, 0, pwr, 0, 0, '', 800);
                  train := TRUE;
               end;
               if user.BoAbilSeeHealGauge then begin
                  user.SendMsg (target, RM_INSTANCEHEALGUAGE, 0, 0, 0, 0, '');
               end;
            end;
         end;
      29: //대회복술
         begin
            with user do begin
               pwr := GetAttackPower (
                           GetPower (MPow(pum)) + Lobyte(WAbil.SC)*2,
                           Integer(Hibyte(WAbil.SC)-Lobyte(WAbil.SC))*2 + 1
                        ); //오버플로 수정(sonmg 2005/02/15)
            end;
            if MagBigHealing (user, pwr, xx, yy) then
               train := TRUE;
         end;

      6: //암연술
         begin
            nofire := TRUE;
            bhasitem := 0;
            pstd := nil;
            if user.IsProperTarget (target) then begin
               //암연술은 독가루주머니가 있어야 한다.
               // 2003/03/15 COPARK 아이템 인벤토리 확장
               if (user.UseItems[U_BUJUK].Index > 0) then begin        // U_ARMRINGL->U_BUJUK
                  pstd := UserEngine.GetStdItem (user.UseItems[U_BUJUK].Index);
                  if pstd <> nil then begin
                     if (pstd.StdMode = 25) and (pstd.Shape <= 2) then begin  //25:독주머니
                        if user.UseItems[U_BUJUK].Dura >= 100 then begin
                           user.UseItems[U_BUJUK].Dura := user.UseItems[U_BUJUK].Dura - 100;
                           //내구성 변경은 알림
                           user.SendMsg (user, RM_DURACHANGE, U_BUJUK, user.UseItems[U_BUJUK].Dura, user.UseItems[U_BUJUK].DuraMax, 0, '');
                           bhasItem := 1;
                        end;
                     end;
                  end;
               end;
               if (user.UseItems[U_ARMRINGL].Index > 0) and (bhasitem = 0) then begin
                  pstd := UserEngine.GetStdItem (user.UseItems[U_ARMRINGL].Index);
                  if pstd <> nil then begin
                     if (pstd.StdMode = 25) and (pstd.Shape <= 2) then begin  //25:독주머니
                        if user.UseItems[U_ARMRINGL].Dura >= 100 then begin
                           user.UseItems[U_ARMRINGL].Dura := user.UseItems[U_ARMRINGL].Dura - 100;
                           //내구성 변경은 알림
                           user.SendMsg (user, RM_DURACHANGE, U_ARMRINGL, user.UseItems[U_ARMRINGL].Dura, user.UseItems[U_ARMRINGL].DuraMax, 0, '');
                           bhasItem := 2;
                        end;
                     end;
                  end;
               end;

               if pstd <> nil then begin
                  if bhasItem > 0 then begin
                     //스킬정도에 따라 성공여부가 결정
                     if 6 >= Random(7 + target.AntiPoison) then begin
                        case pstd.Shape of
                           1: //회색독가루: 중독
                              begin
                                 //sec = 중독시간  60초 + 알파
                                 sec := GetPower13 (30) + 2 * GetRPow(user.WAbil.SC);
                                 //pwr := pum.Level;
                                 pwr := pum.Level + _MAX( 0, _MIN( 3, _MAX(0, HIBYTE(user.WAbil.SC) - 30) * 15 div 100 ) );
                                 target.SendDelayMsg (user, RM_MAKEPOISON, POISON_DECHEALTH{wparam}, sec, integer(user), pwr, '', 1000);
                              end;
                           2: //황색독가루: 방어력감소
                              begin
                                 //녹독을 건 상대가 누구인지 모른 상태에서 빨독을 걸면 녹독은 사라진다.(sonmg 2004/12/27)
                                 if (target.LastHiter = nil) and (target.StatusArr[POISON_DECHEALTH] > 0) then begin
                                    target.StatusArr[POISON_DECHEALTH] := 0;
                                 end;
                                 //sec = 중독시간 40초 + 알파
                                 sec := GetPower13 (40) + 2 * GetRPow(user.WAbil.SC); //(Lobyte(user.WAbil.SC) + Random(ShortInt(Hibyte(user.WAbil.SC)-Lobyte(user.WAbil.SC)) + 1));
                                 //pwr := 2{pum.Level};
                                 pwr := _MAX(2, _MIN(5, HIBYTE(user.WAbil.SC) div 10));
                                 target.SendDelayMsg (user, RM_MAKEPOISON, POISON_DAMAGEARMOR{wparam}, sec, integer(user), pwr, '', 1000);
                              end;
                        end;

                        //-----------------------------------------
                        // 갈피 체크(sonmg 2005/11/28)
                        if (target.RaceServer = RC_USERHUMAN) and (user.RaceServer = RC_USERHUMAN) then begin
                           //정당방어를 위한 기록..
                           target.AddPkHiter (user);
                           target.SetLastHiter (user);
                        end else if (target.Master <> nil) then begin
                           //중독된 소환몹의 주인이 때린사람이 아니면
                           if target.Master <> user then begin
                              //정당방어를 위한 기록..
                              target.AddPkHiter (user);
                              target.SetLastHiter (user);
                           end;
                        end;
                        //-----------------------------------------

                        //사람,몬스터에게 걸었을때 수련된다.
                        if (target.RaceServer = RC_USERHUMAN) or (target.RaceServer >= RC_ANIMAL) then
                           train := TRUE;
                     end;
                     user.SelectTarget (target);
                     nofire := FALSE;
                  end;
               end;
               //다 쓴 약은 사라진다.
               if bhasitem = 1 then begin
                  if user.UseItems[U_BUJUK].Dura < 100 then begin
                     user.UseItems[U_BUJUK].Dura := 0;
                     //다 쓴약은 사라진다.
                     if user.RaceServer = RC_USERHUMAN then begin
                        hum := TUserHuman(user);
                        hum.SendDelItem (user.UseItems[U_BUJUK]); //클라이언트에 없어진거 보냄
                        //독가루 다 닳았을 때 메시지(2004/11/15)
                        {$IFDEF KOREA} hum.SysMsg('독가루가 다 닳았습니다.', 0);
                        {$ELSE}        hum.SysMsg('The Poison item has been exhausted.', 0);
                        {$ENDIF}
                     end;
                     user.UseItems[U_BUJUK].Index := 0;
                  end;
               end;
               if(user.UseItems[U_ARMRINGL].Index > 0) and (bhasitem = 2) then begin
                  pstd := UserEngine.GetStdItem (user.UseItems[U_ARMRINGL].Index);
                  if pstd <> nil then begin
                     if (pstd.StdMode = 25) then begin  //25:독주머니
                        if user.UseItems[U_ARMRINGL].Dura < 100 then begin
                           user.UseItems[U_ARMRINGL].Dura := 0;
                           //다 쓴약은 사라진다.
                           if user.RaceServer = RC_USERHUMAN then begin
                              hum := TUserHuman(user);
                              hum.SendDelItem (user.UseItems[U_ARMRINGL]); //클라이언트에 없어진거 보냄
                              //독가루 다 닳았을 때 메시지(2004/11/15)
                              {$IFDEF KOREA} hum.SysMsg('독가루가 다 닳았습니다.', 0);
                              {$ELSE}        hum.SysMsg('The Poison item has been exhausted.', 0);
                              {$ENDIF}
                           end;
                           user.UseItems[U_ARMRINGL].Index := 0;
                        end;
                     end;
                  end;
               end;
            end;
         end;
      //2003/03/15 신규무공 추가
      36, //무극진기
      13, //폭살계(도사)
      14, //항마진법
      15, //대지원호
      16, //결계
      17, //백골소환술
      18, //은신술
      19, //대은신술
      41, //천녀소환(정혼소환-월령)
      46, //저주술
      49: //맹안술(미혼술)
         begin
            nofire := TRUE;
            bujuckCount := 1;
            try
            // 천녀소환(정혼소환-월령)일경우에는 5개 소비
            case pum.pDef.MagicId of
            41 :
               begin
                  TempCret := user.GetExistSlave( __AngelMob );
                  if TempCret <> nil then
                  begin
                     TempCret.forcemovetomaster := true;
                     exit;
                  end;
                  bujuckCount := 5;
               end;
            17  :
               begin
                  TempCret := user.GetExistSlave( __WhiteSkeleton );
                  if TempCret <> nil then
                  begin
                     TempCret.forcemovetomaster := true;
                     exit;
                  end;
                  bujuckCount := 1;
               end;
            else
                bujuckcount := 1;
            end;

            except
                MainOutMessage('EXCEPTION BUJUCK CALC');
            end;


            bhasItem := 0;
            if bujuckcount > 0 then bhasItem := CanUseBujuk (user, bujuckcount);

            if bhasItem > 0 then begin
               if bhasitem = 1 then begin
                  // 2003/03/15 COPARK 아이템 인벤토리 확장
                  if user.UseItems[U_BUJUK].Dura >= (bujuckcount * 100) then      // U_ARMRINGL->U_BUJUK
                     user.UseItems[U_BUJUK].Dura := user.UseItems[U_BUJUK].Dura - (bujuckcount * 100)
                  else user.UseItems[U_BUJUK].Dura := 0;
                  user.SendMsg (user, RM_DURACHANGE, U_BUJUK, user.UseItems[U_BUJUK].Dura, user.UseItems[U_BUJUK].DuraMax, 0, '');
               end;
               if bhasitem = 2 then begin
                  if user.UseItems[U_ARMRINGL].Dura >= (bujuckcount * 100) then
                     user.UseItems[U_ARMRINGL].Dura := user.UseItems[U_ARMRINGL].Dura - ( bujuckcount * 100 )
                  else user.UseItems[U_ARMRINGL].Dura := 0;
                  user.SendMsg (user, RM_DURACHANGE, U_ARMRINGL, user.UseItems[U_ARMRINGL].Dura, user.UseItems[U_ARMRINGL].DuraMax, 0, '');
               end;

               case pum.pDef.MagicId of
                  13:  //폭살계
                     if user.MagCanHitTarget (user.CX, user.CY, target) then begin
                        if user.IsProperTarget(target) then begin
                           if (target.AntiMagic <= Random(50)) and (abs(target.CX-xx) <= 1) and (abs(target.CY-yy) <= 1) then begin
                              with user do begin //파워
                                 pwr := GetAttackPower (
                                             GetPower (MPow(pum)) + Lobyte(WAbil.SC),
                                             Integer(Hibyte(WAbil.SC)-Lobyte(WAbil.SC)) + 1
                                          ); //오버플로 수정(sonmg 2005/02/15)
                                 //타겟 맞음, 후에 효과나타남
                                 //target.SendDelayMsg (user, RM_MAGSTRUCK, 0, pwr, 0, 0, '', 1200 + _MAX(Abs(CX-xx),Abs(CY-yy)) * 50 );
                              end;
                              //user.SelectTarget (target);
                              user.SendDelayMsg (user, RM_DELAYMAGIC, pwr, MakeLong(xx, yy), 2, integer(target), '', 1200);
                              if (target.RaceServer >= RC_ANIMAL) then train := TRUE;
                           end;
                        end;
                     end else
                        target := nil;
                  14: //항마진법
                     begin
                        pwr := user.GetAttackPower (
                                    GetPower13 (60) + 5 * Lobyte(user.WAbil.SC),
                                    5 * (Integer(Hibyte(user.WAbil.SC)-Lobyte(user.WAbil.SC)) + 1)
                                 ); //오버플로 수정(sonmg 2005/02/15)
                        if user.MagMakeDefenceArea (xx, yy, 3, pwr{초}, TRUE) > 0 then
                           train := TRUE;
                     end;
                  46: //저주술
                     begin

                        sec := ((( pum.level + 1)* 24 ) + Hibyte(user.WAbil.SC) + user.Abil.Level) div 2 ;

                        case pum.Level of
                        0   : pwr := 93;
                        1   : pwr := 88;
                        2   : pwr := 82;
                        3   : pwr := 75;
                        end;

                        if user.MagMakeCurseArea (xx, yy, 2, sec, pwr, pum.level, TRUE) > 0 then
                           train := TRUE;

                     end;
                  //2003/03/15 신규무공 추가
                  36: //무극진기
                     begin
                        sec := user.GetAttackPower (
                                    GetPower13 (60) + 5 * Lobyte(user.WAbil.SC),
                                    5 * (Integer(Hibyte(user.WAbil.SC)-Lobyte(user.WAbil.SC)) + 1)
                                 ); //오버플로 수정(sonmg 2005/02/15)
                        //증가되는 파괴력
                        pwr := ((Hibyte(user.WAbil.SC)-1) div 5) + 1;
                        if (pwr > 8) then pwr := 8;

{$IFNDEF DEBUG}
                        if user.MagDcUp (sec{초}, pwr) then
                           train := TRUE;
{$ELSE} //-----도사 무극진기 그룹적용 (디버그모드)------
                        //그룹이 없으면 자신만 적용
                        if user.GroupOwner = nil then begin
                           if user.MagDcUp (sec{초}, pwr) then
                              train := TRUE;
                        end else begin
                           //그룹이 있으면 모든 그룹원에게 적용
                           for k:=0 to user.GroupOwner.GroupMembers.Count-1 do begin  //자신 포함.
                              hum := UserEngine.GetUserHuman (user.GroupOwner.GroupMembers[k]);
                              if hum <> nil then begin
                                 if hum.MagDcUp (sec, pwr) then
                                    train := TRUE;
                              end;
                           end;
                        end;
{$ENDIF}

                        //타켓의 능력치를 올려줌(sonmg 2005/06/07)
                        if (target <> nil) and (target.RaceServer = RC_USERHUMAN) then begin
                           if target.MagDcUp (sec{초}, pwr) then begin
                              target.SendRefMsg (RM_LOOPNORMALEFFECT, integer(target), 0, 0, NE_BIGFORCE, '');
                              train := TRUE;
                           end;
                        end;
                     end;
                  15: //대지원호
                     begin
                        pwr := user.GetAttackPower (
                                    GetPower13 (60) + 5 * Lobyte(user.WAbil.SC),
                                    5 * (Integer(Hibyte(user.WAbil.SC)-Lobyte(user.WAbil.SC)) + 1)
                                 ); //오버플로 수정(sonmg 2005/02/15)
                        if user.MagMakeDefenceArea (xx, yy, 3, pwr{초}, FALSE) > 0 then
                           train := TRUE;
                     end;
                  16: //결계
                     begin
                        if MagMakeHolyCurtain (user,
                                          GetPower13 (40) + 3 * GetRPow(user.WAbil.SC), //Lobyte(user.WAbil.SC),
                                          xx, yy) > 0 then begin
                           train := TRUE;
                        end;
                     end;
                  17: //백골소환술
                     begin
                      try
                        TempCret := user.GetExistSlave( __WhiteSkeleton );
                        if TempCret = nil  then
                        begin
                           if (user.GetExistSlave( __Shinsu  ) = nil) and
                              (user.GetExistSlave( __Shinsu1 ) = nil) then
                           if user.MakeSlave (__WhiteSkeleton, pum.Level, 1, 10 * 24 * 60 * 60) <> nil then
                              train := TRUE;
                        end;
                      except
                        MainOutMessage('EXCEPT WHITE SKELETON');
                      end;
                     end;
                  18: //은신
                     begin
                        if MagMakePrivateTransparent (user, GetPower13 (30) + 3 * GetRPow(user.WAbil.SC)) then begin
                           train := TRUE;
                        end;
                     end;
                  19: //대은신
                     begin
                        if MagMakeGroupTransparent (user, xx, yy, GetPower13 (30) + 3 * GetRPow(user.WAbil.SC)) then begin
                           train := TRUE;
                        end;
                     end;
                  41: //천녀소환술(정혼소환술)
                     begin
                      try
                        TempCret := user.GetExistSlave( __AngelMob );
                        if TempCret = nil  then
                        begin
                            //천녀(월령)가 없다.
                           if user.MakeSlave (__AngelMob, pum.Level, 1, 10 * 24 * 60 * 60) <> nil then
                              train := TRUE;
                        end;
                       except
                        MainOutMessage('EXCEPT ALGEL ');
                       end;
                     end;
                  49: //맹안술(미혼술)
                     begin
                        if MagBlindEye( user, target, pum ) then begin
                           train := TRUE;
                        end;
                     end;
               end;

               nofire := FALSE;
               UseBujuk (user);
            end;
         end;
      30: //신수소환
         begin
            nofire := TRUE;
            try

            TempCret := user.GetExistSlave( __ShinSu );
            if TempCret = nil then
                TempCret := user.GetExistSlave( __ShinSu1 );

            if TempCret <> nil then
            begin
              TempCret.forcemovetomaster := true;
              exit;
            end;


            bhasItem := CanUseBujuk (user, 5);
            if bhasItem > 0 then
            begin
               if bhasitem = 1 then begin
                  // 2003/03/15 COPARK 아이템 인벤토리 확장
                  if user.UseItems[U_BUJUK].Dura >= 500 then      // U_ARMRINGL->U_BUJUK
                     user.UseItems[U_BUJUK].Dura := user.UseItems[U_BUJUK].Dura - 500
                  else user.UseItems[U_BUJUK].Dura := 0;
                  //내구성 변경은 알림
                  user.SendMsg (user, RM_DURACHANGE, U_BUJUK, user.UseItems[U_BUJUK].Dura, user.UseItems[U_BUJUK].DuraMax, 0, '');
               end;
               if bhasitem = 2 then begin
                  if user.UseItems[U_ARMRINGL].Dura >= 500 then
                     user.UseItems[U_ARMRINGL].Dura := user.UseItems[U_ARMRINGL].Dura - 500
                  else user.UseItems[U_ARMRINGL].Dura := 0;
                  user.SendMsg (user, RM_DURACHANGE, U_ARMRINGL, user.UseItems[U_ARMRINGL].Dura, user.UseItems[U_ARMRINGL].DuraMax, 0, '');
               end;
               case pum.pDef.MagicId of
                  30: //신수소환
                     begin
                        if (user.GetExistSlave(__WhiteSkeleton) = nil) then
                           if user.MakeSlave (__ShinSu, pum.Level, 1, 10 * 24 * 60 * 60) <> nil then
                              train := TRUE;
                     end;
               end;
               nofire := FALSE;
               UseBujuk (user);  // 버그 수정(2004/09/01 sonmg)
            end;

            except
                MainOutMessage('EXCEPT SHINSU');
            end;

         end;
      42: //분신소환
         begin
          try
            TempCret :=user.GetExistSlave( __CloneMob );
            if TempCret <> nil then
            begin
                // 분신한넘이 있다.
                TempCret.BoDisapear := true;
                // MP 다시 더해주자
                user.Wabil.MP := user.WAbil.MP + Spell;
            end
            else // 분신한넘이 없다.
            begin

               TempCret := user.MakeSlave (__CloneMob, pum.Level, 5, 10 * 24 * 60 * 60);
               if TempCret <> nil then
               begin
                  user.SendRefMsg (RM_NORMALEFFECT, 0, TempCret.CX, TempCret.CY, NE_CLONESHOW, '');
                  train := TRUE;
               end;

            end;

           except
                MainOutMessage('EXCET CLONE');
           end;

         end;

      28:  //탐기파연
         begin
            if target <> nil then begin
               if not target.BoOpenHealth then begin
                  if Random(6) <= 3+pum.Level then begin
                     target.OpenHealthStart := GetTickCount;
                     target.OpenHealthTime := GetPower13 (30 + GetRPow(user.WAbil.SC) * 2) * 1000;
                     target.SendDelayMsg (target, RM_DOOPENHEALTH, 0, 0, 0, 0, '', 1500);
                     train := TRUE;
                  end;
               end;
            end;
         end;
      // 2003/07/15 신규무공
      39:   // 결빙장
         if user.MagCanHitTarget (user.CX, user.CY, target) then begin
            if user.IsProperTarget (target) then begin
               if (target.AntiMagic <= Random(50)) and (abs(target.CX-xx) <= 1) and (abs(target.CY-yy) <= 1) then begin
                  with user do begin
                     //결빙장 공식 수정(sonmg 2004/10/20)
//                     Dur := (Round (0.4+pum.Level*0.2) * (Lobyte(WAbil.MC) + Hibyte(WAbil.MC)));
                     Dur := (Round (0.4+pum.Level*0.2) * (Lobyte(WAbil.MC) + Random(Hibyte(WAbil.MC)) + (Hibyte(WAbil.MC) div 2)));
                     pwr := pum.pDef.MinPower + Dur;
                  end;
                  user.SendDelayMsg (user, RM_DELAYMAGIC, pwr, MakeLong(xx, yy), 2, integer(target), '', 600);
                  // 상태이상...둔화판정
                  if (target.Abil.Level < 60) and
                     (target.StatusArr[POISON_SLOW] = 0) and
                     (target.StatusArr[POISON_ICE] = 0) and
                     (Random(50) > target.AntiMagic) then begin    // 100->50
                     MoC := 1;
                     Gap := target.Abil.Level - user.Abil.Level;
                     if Gap > 10 then Gap := 10;
                     if Gap <-10 then Gap :=-10;
                     if target.RaceServer = RC_USERHUMAN then MoC := 2;
                     if Random(100) < (20 + (pum.Level - Gap) div Moc) then begin
                        Dur := (900 * pum.Level + 3300) div 1000;
                        if (MoC = 1) and (Random(10) = 0) then target.MakePoison(POISON_ICE, Dur, 1)
                        else if (MoC = 2) and (Random(100) = 0) then target.MakePoison(POISON_ICE, Dur, 1)
                        else target.MakePoison(POISON_SLOW, Dur + 1, 1);
                     end;
                  end;
                  if (target.RaceServer >= RC_ANIMAL) then train := TRUE;
               end else
                  target := nil;
            end else
               target := nil;
         end else
            target := nil;
      40:   // 정화술
         begin
            if MagMakePrivateClean (user, xx, yy, pum.Level*15+45) then begin
               train := TRUE;
            end;
         end;
      43: // 사자후
         begin
            try
//             nofire := true;   //sonmg(2004/05/19)
               user._Attack( HM_STONEHIT, nil );
            except
               MainOutMessage('EXCEPTION STONEHIT');
            end;
            train := FALSE;
         end;
      44: // 공파섬
         begin
            if MagWindCut ( user , pum.Level ) then begin
               train := true;
            end;
         end;
      47: // 포승검
         begin
            if MagPullMon ( user, target, pum.Level ) then begin
               train := true;
            end;
         end;
      48: // 흡혈술
         if user.IsProperTarget (target) then begin
            if target.AntiMagic <= Random(50) then begin
               with user do begin
                  pwr := GetAttackPower (
                              GetPower (MPow(pum)) + Lobyte(WAbil.MC),
                              Integer(Hibyte(WAbil.MC)-Lobyte(WAbil.MC)) + 1
                           ); //오버플로 수정(sonmg 2005/02/15)
               end;
               //user.SelectTarget (target);
               if (target.LifeAttrib <> LA_UNDEAD) and (target.RaceServer <> RC_USERHUMAN) then
                  pwr := Round (pwr * 1.2);
               user.SendDelayMsg (user, RM_DELAYMAGIC, pwr, MakeLong(xx, yy), 2, integer(target), '', 0);
               if (target.RaceServer >= RC_ANIMAL) then begin
                  //몹에게 사용한 경우 뺏어오는 HP량.
                  user.IncHealth := (pwr * (pum.Level+1)*10 + Random(20)) div 100;
                  train := TRUE;
               end else begin
                  //사람에게 사용한 경우 뺏어오는 HP량.
                  user.IncHealth := ((pwr * (pum.Level+1)*10 + Random(10)) div 100) * _MAX(0, 1 - target.AntiMagic div 25);
               end;
//               user.SendRefMsg (RM_LOOPNORMALEFFECT, integer(user), 0, 0, NE_BLOODSUCK, '');
               user.SendDelayMsg (user, RM_LOOPNORMALEFFECT, integer(user), 0, 0, NE_BLOODSUCK, '', 1000);
            end else
               target := nil;
         end else
            target := nil;

   end;

   if not nofire then begin
      with user do begin
         if needfire then
            SendRefMsg (RM_MAGICFIRE, 0, MakeWord(pum.pDef.EffectType, pum.pDef.Effect), MakeLong(xx, yy), integer(target), '');
         //2003/03/15 신규무공 추가
         //맞은 상대
         if (pum.Level < 3) and train then
            if Abil.Level >= pum.pDef.NeedLevel[pum.Level] then begin
               //수련레벨에 도달한 경우
               user.TrainSkill (pum, 1 + Random(3));
               if not CheckMagicLevelup (pum) then
                  SendDelayMsg (user, RM_MAGIC_LVEXP, 0, pum.pDef.MagicId, pum.Level, pum.CurTrain, '', 1000);
            end;
      end;
      Result := TRUE;
   end;
end;

end.

