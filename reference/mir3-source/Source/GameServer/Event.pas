unit Event;

interface

uses
  Windows, Messages, SysUtils, Classes, Graphics, Controls, Dialogs,
  ScktComp, syncobjs, MudUtil, HUtil32, ObjBase, Grobal2,
  Envir, M2Share;

type
   TEvent = class
      Check: integer;
      PEnvir: TEnvirnoment;
      X, Y: integer;
      EventType: integer;
      EventParam: integer;
      OpenStartTime: longword;   //열린시간
      ContinueTime: longword;         //열여있을 시간
      CloseTime: longword;
      Closed: Boolean;
      Damage: integer;
      OwnCret: TCreature;

      runstart: longword;
      runtick: longword;
      IsAddToMap : Boolean;
   protected
      FVisible: Boolean;  //맵에 보인다.
      Active: Boolean;
   private
      procedure AddToMap ; virtual;
   public
      constructor Create (penv: TEnvirnoment; ax, ay, etype, etime: integer; bovisible: Boolean);
      destructor Destroy; override;
      procedure Run; dynamic;
      procedure Close;

      property Visible: Boolean read FVisible;
   end;

   TStoneMineEvent = class (TEvent)
      MineCount: integer;
      MineFillCount: integer;  //매장량
      RefillTime: longword;
   private
      procedure AddToMap ; override;
   public
      constructor Create (penv: TEnvirnoment; ax, ay, etype: integer);
      procedure Refill;
   end;

   TPileStones = class (TEvent) //돌무더기(캔 흔적)
   public
      constructor Create (penv: TEnvirnoment; ax, ay, etype, etime: integer; bovisible: Boolean);
      procedure EnlargePile;
   end;

   THolyCurtainEvent = class (TEvent)
   public
      constructor Create (penv: TEnvirnoment; ax, ay, etype, etime: integer);
   end;

   TFireBurnEvent = class (TEvent)
   private
      ticktime: longword;
   public
      constructor Create (user: TCreature; ax, ay, etype, etime, dam: integer);
      procedure Run; override;
   end;

   TEventManager = class
   private
   protected
   public
      EventList: TList;
      ClosedList: TList;
      constructor Create;
      destructor Destroy; override;
      procedure AddEvent (event: TEvent);
      function  FindEvent (penvir: TEnvirnoment; x, y, evtype: integer): TEvent;
      procedure Run;
   end;


implementation

uses
   svMain;


constructor TEvent.Create (penv: TEnvirnoment; ax, ay, etype, etime: integer; bovisible: Boolean);
begin
   OpenStartTime := GetTickCount;
   EventType := etype;
   EventParam := 0;
   ContinueTime := etime;
   FVisible := bovisible;
   Closed := FALSE;
   PEnvir := penv;
   X := ax;
   Y := ay;
   Active := TRUE;
   Damage := 0;
   OwnCret := nil;

   runstart := GetTickCount;
   runtick := 500;

   AddToMap;
end;

destructor TEvent.Destroy;
begin
   inherited Destroy;
end;

procedure TEvent.AddToMap;
begin
   IsAddToMap := false;
   if (PEnvir <> nil) and FVisible then begin
      if ( nil <> PEnvir.AddToMap (X, Y, OS_EVENTOBJECT, self) ) then
      begin
        IsAddToMap := true;
      end;

   end else
      FVisible := FALSE;
end;

procedure TEvent.Close;
begin
   CloseTime := GetTickCount;
   if FVisible then begin
      FVisible := FALSE;
      if PEnvir <> nil then
         PEnvir.DeleteFromMap (X, Y, OS_EVENTOBJECT, self);
      PEnvir := nil;
   end;
end;

procedure TEvent.Run;
begin
   if GetTickCount - OpenStartTime > ContinueTime then begin
      Closed := TRUE;
      Close;
   end;
end;

{----------------------------------------------------------}

constructor TStoneMineEvent.Create (penv: TEnvirnoment; ax, ay, etype: integer);
begin
   inherited Create (penv, ax, ay, etype, 0, FALSE);
   AddToMap;
   FVisible := FALSE;
   MineCount := Random(200);
   RefillTime := GettickCount;
   Active := FALSE;
   MineFillCount := Random(80);
end;

procedure TStoneMineEvent.Refill;
begin
   MineCount := MineFillCount;
   RefillTime := GettickCount;
end;

procedure TStoneMineEvent.AddToMap;
begin
   if( nil = PEnvir.AddToMapMineEvnet(X, Y, OS_EVENTOBJECT, self) )then
        IsAddToMap := false
   else
        IsAddToMap := true;

end;

{----------------------------------------------------------}


constructor TPileStones.Create (penv: TEnvirnoment; ax, ay, etype, etime: integer; bovisible: Boolean);
begin
   inherited Create (penv, ax, ay, etype, etime, TRUE);
   EventParam := 1;
end;

procedure TPileStones.EnlargePile;
begin
   if EventParam < 5 then Inc (EventParam);
end;


{----------------------------------------------------------}


constructor THolyCurtainEvent.Create (penv: TEnvirnoment; ax, ay, etype, etime: integer);
begin
   inherited Create (penv, ax, ay, etype, etime, TRUE);
end;


{----------------------------------------------------------}


constructor TFireBurnEvent.Create (user: TCreature; ax, ay, etype, etime, dam: integer);
begin
   inherited Create (user.PEnvir, ax, ay, etype, etime, TRUE);
   Damage := dam;
   OwnCret := user;
end;

procedure TFireBurnEvent.Run;
var
   i: integer;
   cret: TCreature;
   list: TList;
begin
   if GetTickCount - ticktime > 3000 then begin
      ticktime := GetTickCount;
      list := TList.Create;
      if PEnvir <> nil then begin
         PEnvir.GetAllCreature (X, Y, TRUE, list);
         for i:=0 to list.Count-1 do begin
            cret := TCreature(list[i]);
            if cret <> nil then begin
               if OwnCret.IsProperTarget (cret) then begin
                  cret.SendMsg (OwnCret, RM_MAGSTRUCK_MINE, 0, Damage, 0, 0, '');
               end;
            end;
         end;
      end;
      list.Free;
   end;
   inherited Run;
end;


{----------------------------------------------------------}


constructor TEventManager.Create;
begin
   EventList := TList.Create;
   ClosedList:= TList.Create;
end;

destructor TEventManager.Destroy;
var
   i: integer;
begin
   for i:=0 to EventList.Count-1 do
      TEvent(EventList[i]).Free;
   EventList.Free;
   ClosedList.Free;
   inherited Destroy;
end;

procedure TEventManager.AddEvent (event: TEvent);
begin
   EventList.Add (event);
end;

function  TEventManager.FindEvent (penvir: TEnvirnoment; x, y, evtype: integer): TEvent;
var
   i: integer;
   event: TEvent;
begin
   Result := nil;
   for i:=0 to EventList.Count-1 do begin
      event := TEvent(EventList[i]);
      if (event.PEnvir = penvir) and (event.X = x) and (event.Y = y) and (event.EventType = evtype) then begin
         Result := event;
         break;
      end;
   end;
end;

procedure TEventManager.Run;
var
   i: integer;
   event: TEvent;
begin
   i := 0;
   try

     while TRUE do begin
        if i >= EventList.Count then break;
        event := TEvent(EventList[i]);
        if event.Active and (GetTickCount - event.runstart > event.runtick) then begin
           event.runstart := GetTickCount;
           event.Run;
           if event.Closed then begin
              ClosedList.Add (event);
              EventList.Delete (i);
           end else
              Inc (i);
        end else
           Inc (i);
     end;

   except
    MainOutMessage('Except:TEventManager.Run[1]');
   end;

   try
     for i:=0 to ClosedList.Count-1 do begin
        if GetTickCount - TEvent(ClosedList[i]).CloseTime > 5 * 60 * 1000 then begin
           try
           TEvent(ClosedList[i]).Free;
           finally
           ClosedList.Delete (i); //한번에 한개씩
           end;
           break;
        end;
     end;
   except
    MainOutMessage('Except:TEventManager.Run[2]');
   end;


end;


end.
