unit ObjAxeMon;

interface

uses
  Windows, Messages, SysUtils, Classes, Graphics, Controls, Dialogs,
  ScktComp, syncobjs, MudUtil, HUtil32, Grobal2, Envir, EdCode, ObjBase,
  M2Share, ObjMon;


type
   TDualAxeMonster = class(TMonster)
   private
   protected
      RunDone: Boolean;
      ChainShot: integer;
      ChainShotCount: integer;
      procedure FlyAxeAttack (targ: TCreature);
      function  AttackTarget: Boolean; override;
   public
      constructor Create;
      destructor Destroy; override;
      procedure Run; override;
   end;

   TThornDarkMonster = class (TDualAxeMonster)
   public
      constructor Create;
   end;

   TArcherMonster = class (TDualAxeMonster)
   public
      constructor Create;
   end;



implementation


constructor TDualAxeMonster.Create;
begin
   inherited Create;
   RunDone := FALSE;
   ViewRange := 5;
   RunNextTick := 250;
   SearchRate := 3000;
   ChainShot := 0;
   ChainShotCount := 2;
   SearchTime := GetTickCount;
   RaceServer := RC_DUALAXESKELETON;
end;

destructor TDualAxeMonster.Destroy;
begin
   inherited Destroy;
end;

procedure TDualAxeMonster.FlyAxeAttack (targ: TCreature); //반드시 target <> nil
var
   dam, armor: integer;
begin
   if targ = nil then exit;

   if PEnvir.CanFly (CX, CY, targ.CX, targ.CY) then begin //도끼가 날아갈수 있는지.
      Dir := GetNextDirection (CX, CY, targ.CX, targ.CY);
      with WAbil do
         dam := Lobyte(DC) + Random(SmallInt(Hibyte(DC)-Lobyte(DC)) + 1);
      if dam > 0 then begin
         //armor := (Lobyte(targ.WAbil.AC) + Random(ShortInt(Hibyte(targ.WAbil.AC)-Lobyte(targ.WAbil.AC)) + 1));
         //dam := dam - armor;
         //if dam <= 0 then
         //   if dam > -10 then dam := 1;
         dam := targ.GetHitStruckDamage (self, dam);
      end;
      if dam > 0 then begin
         targ.StruckDamage (dam, self);
         targ.SendDelayMsg (TCreature(RM_STRUCK), RM_REFMESSAGE, dam{wparam},
                  targ.WAbil.HP{lparam1}, targ.WAbil.MaxHP{lparam2}, Longint(self){hiter}, '', 600 + _MAX(Abs(CX-targ.CX),Abs(CY-targ.CY)) * 50);
      end;
      SendRefMsg (RM_FLYAXE, Dir, CX, CY, Integer(targ), '');
   end;
end;

function  TDualAxeMonster.AttackTarget: Boolean;
var
   targdir: byte;
begin
   Result := FALSE;
   if TargetCret <> nil then begin
      if GetCurrentTime - HitTime > GetNextHitTime then begin
         HitTime := GetCurrentTime;
         if (abs(CX-TargetCret.CX) <= 7) and (abs(CY-TargetCret.CY) <= 7) then begin
            if ChainShot < ChainShotCount-1 then begin
               Inc (ChainShot);
               TargetFocusTime := GetTickCount;
               FlyAxeAttack (TargetCret);
            end else begin
               if Random(5) = 0 then
                  ChainShot := 0;
            end;
            Result := TRUE;
         end else begin
            if TargetCret.MapName = self.MapName then begin
               if (abs(CX-TargetCret.CX) <= 11) and (abs(CY-TargetCret.CY) <= 11) then begin
                  //약간 떨어진 경우 따라간다.
                  SetTargetXY (TargetCret.CX, TargetCret.CY)
               end;
            end else
               LoseTarget;  //<!!주의> TargetCret := nil로 바뀜
         end;
      end;
   end;
end;

procedure TDualAxeMonster.Run;
var
   i, dis, d: integer;
   cret, nearcret: TCreature;
begin
   dis := 9999;
   nearcret := nil;
//   if not Death and not RunDone and not BoGhost and
//      (StatusArr[POISON_STONE] = 0) and (StatusArr[POISON_ICE] = 0) and
//      (StatusArr[POISON_STUN] = 0) then begin
     if not RunDone and IsMoveAble then begin
      if GetTickCount - SearchEnemyTime > 5000 then begin
         SearchEnemyTime := GetTickCount;
         //상속받은 run 에서 HitTime 재설정함.
         for i:=0 to VisibleActors.Count-1 do begin
            cret := TCreature (PTVisibleActor(VisibleActors[i]).cret);
            if (not cret.Death) and (IsProperTarget(cret)) and (not cret.BoHumHideMode or BoViewFixedHide) then begin
               d := abs(CX-cret.CX) + abs(CY-cret.CY);
               if d < dis then begin
                  dis := d;
                  nearcret := cret;
               end;
            end;
         end;
         if nearcret <> nil then
            SelectTarget (nearcret);
      end;
      if GetCurrentTime - WalkTime > GetNextWalkTime then begin
         //상속받은 run에서 WalkTime 재설정함
         if TargetCret <> nil then
            if (abs(CX-TargetCret.CX) <= 4) and (abs(CY-TargetCret.CY) <= 4) then begin
               if (abs(CX-TargetCret.CX) <= 2) and (abs(CY-TargetCret.CY) <= 2) then begin
                  //너무 가까우면, 잘 도망 안감.
                  if Random(5) = 0 then begin
                     //도망감.
                     GetBackPosition (self, TargetX, TargetY);
                  end;
               end else begin
                  //도망감.
                  GetBackPosition (self, TargetX, TargetY);
               end;
            end;
      end;
   end;
   inherited Run;
end;


{----------------------------------------------------}

// TThornDarkMonster


constructor  TThornDarkMonster.Create;
begin
   inherited Create;
   ChainShotCount := 3;
   RaceServer := RC_THORNDARK;
end;


{----------------------------------------------------}

// TArcherMonster


constructor  TArcherMonster.Create;
begin
   inherited Create;
   ChainShotCount := 6;
   RaceServer := RC_ARCHERMON;
end;


end.
