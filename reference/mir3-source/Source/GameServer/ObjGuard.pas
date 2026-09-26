unit ObjGuard;

interface

uses
  Windows, Messages, SysUtils, Classes, Graphics, Controls, Dialogs,
  ScktComp, syncobjs, MudUtil, HUtil32, Grobal2, Envir, EdCode, ObjBase,
  ObjNpc, M2Share;


type
   TSuperGuard = class (TNormNpc)
   private
   public
      constructor Create;
      destructor Destroy; override;
      procedure RunMsg (msg: TMessageInfo); override;
      function  AttackTarget: Boolean;
      procedure Run; override;
   end;


implementation

uses
   svMain;
   

constructor TSuperGuard.Create;
begin
   inherited Create;
   RaceServer := RC_DOORGUARD;
   ViewRange := 7;
   Light := 2;
end;

destructor TSuperGuard.Destroy;
begin
   inherited destroy;
end;

procedure TSuperGuard.RunMsg (msg: TMessageInfo);
begin
   inherited RunMsg (msg);
end;

function  TSuperGuard.AttackTarget: Boolean;
var
   ox, oy: integer;
   olddir: byte;
begin
   Result := FALSE;
   if TargetCret.PEnvir = PEnvir then begin
      if GetCurrentTime - HitTime > GetNextHitTime then begin
         HitTime := GetCurrentTime;
         TargetFocusTime := GetTickCount;
         ox := CX;
         oy := CY;
         olddir := Dir;
         GetBackPosition (TargetCret, CX, CY);
         Dir := GetNextDirection (CX, CY, TargetCret.CX, TargetCret.CY);
         //Turn (Dir);
         SendRefMsg (RM_HIT, Dir, CX, CY, 0, '');
         _Attack (HM_HIT, TargetCret); //점프해서 공격
         TargetCret.SetLastHiter (self);
         TargetCret.ExpHiter := nil; //경험치를
         CX := ox;
         CY := oy;
         Dir := olddir;
         Turn (Dir);
         BreakHolySeize;
      end;
      Result := TRUE;
   end else
      LoseTarget;
end;

procedure TSuperGuard.Run;
var
   i: integer;
   cret: TCreature;
begin
   if GetCurrentTime - HitTime > GetNextHitTime then begin //상속받은 run 에서 HitTime 재설정함.
      for i:=0 to VisibleActors.Count-1 do begin
         cret := TCreature (PTVisibleActor(VisibleActors[i]).cret);
         if (not cret.Death) and
            ( (cret.PKLevel >= 2) or
              ((cret.RaceServer >= RC_MONSTER) and (not cret.BoHasMission))
            ) then begin
            SelectTarget (cret);
            break;
         end;
      end;
   end;
   if TargetCret <> nil then
      AttackTarget;
   inherited Run;
end;


end.
