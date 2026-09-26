unit clEvent;

interface

uses
  Windows, Messages, SysUtils, Classes, Graphics, Controls, Forms, Dialogs,
  HGETextures, {DirectX, DXClass, }Grobal2, ScktComp, ExtCtrls, HUtil32, EdCode,
  CliUtil;


const
   ZOMBIDIGUPDUSTBASE = 420;
   STONEFRAGMENTBASE = 230;
   HOLYCURTAINBASE = 1390;
   FIREBURNBASE = 1630;
   SCULPTUREFRAGMENT = 1349;
   HEARTPALPMARK = 420;

type
   TClEvent = class
      X, Y, Dir: integer;
      px, py: integer;
      EventType: integer;
      EventParam: integer;
      ServerId: integer;
      dsurface: TDirectDrawSurface;
      BoBlend: Boolean;
      calcframetime: longword;
      curframe: longword;
      light: integer;
   private
   public
      constructor Create (svid, ax, ay, evtype: integer);
      destructor Destroy; override;
      procedure DrawEvent (backsurface: TDirectDrawSurface; ax, ay: integer); dynamic;
      procedure Run; dynamic;
   end;

   TClEventManager = class
   private
   public
      EventList: TList;
      constructor Create;
      destructor Destroy; override;
      procedure ClearEvents;
      function  AddEvent (evn: TClEvent): TClEvent;
      procedure DelEvent (evn: TClEvent);
      procedure DelEventById (svid: integer);
      function  GetEvent (ax, ay, etype: integer): TClEvent;
      procedure Execute;
   end;


implementation

uses
   ClMain, uWilFile;

constructor TClEvent.Create (svid, ax, ay, evtype: integer);
begin
   ServerId := svid;
   X := ax;
   Y := ay;
   EventType := evtype;
   EventParam := 0;
   BoBlend := FALSE;
   calcframetime := GetTickCount;
   curframe := 0;
   light := 0;
end;

destructor TClEvent.Destroy;
begin
   inherited Destroy;
end;

procedure TClEvent.DrawEvent (backsurface: TDirectDrawSurface; ax, ay: integer);
begin
   if dsurface <> nil then
      if BoBlend then DrawBlend (backsurface, ax+px, ay+py, dsurface, 1)
      else backsurface.Draw(ax+px, ay+py, dsurface.ClientRect, dsurface, TRUE);
end;

procedure TClEvent.Run;
begin
   dsurface := nil;
   if GetTickCount - calcframetime > 20 then begin
      calcframetime := GetTickCount;
      Inc (curframe);
   end;
   case EventType of
      ET_DIGOUTZOMBI:
         begin
            dsurface := g_WMon6Img.GetCachedImage (ZOMBIDIGUPDUSTBASE+Dir, px, py);
         end;
      ET_PILESTONES:
         begin
            if EventParam <= 0 then EventParam := 1;
            if EventParam > 5 then EventParam := 5;
            dsurface := g_WProgUse.GetCachedImage (STONEFRAGMENTBASE+(EventParam-1), px, py);
         end;
      ET_HOLYCURTAIN:
         begin
            dsurface := g_WMagic.GetCachedImage (HOLYCURTAINBASE+(curframe mod 10), px, py);
            BoBlend := TRUE;
            light := 1;
         end;
      ET_FIRE:
         begin
            if BoViewEffect then begin
               dsurface := g_WMagic.GetCachedImage (FIREBURNBASE+((curframe div 2) mod 6), px, py);
               BoBlend := TRUE;
               light := 1;
            end;
         end;
      ET_SCULPEICE:
         begin
            dsurface := g_WMon7Img.GetCachedImage (SCULPTUREFRAGMENT, px, py);
         end;
      ET_HEARTPALP:  //적월마의 촉수 공격
         begin
            dsurface := g_WMon14Img.GetCachedImage (HEARTPALPMARK, px, py);
         end;
   end;
end;


{-----------------------------------------------------------------------------}



{-----------------------------------------------------------------------------}

constructor TClEventManager.Create;
begin
   EventList := TList.Create;
end;

destructor TClEventManager.Destroy;
var
   i: integer;
begin
   for i:=0 to EventList.Count-1 do
      TClEvent(EventList[i]).Free;
   EventList.Free;
   inherited Destroy;
end;

procedure TClEventManager.ClearEvents;
var
   i: integer;
begin
   for i:=0 to EventList.Count-1 do
      TClEvent(EventList[i]).Free;
   EventList.Clear;
end;

function  TClEventManager.AddEvent (evn: TClEvent): TClEvent;
var
   i: integer;
   event: TClEvent;
begin
   for i:=0 to EventList.Count-1 do
      if (EventList[i] = evn) or (TClEvent(EventList[i]).ServerId = evn.ServerId) then begin
         evn.Free;
         Result := nil;
         exit;
      end;
   EventList.Add (evn);
   Result := evn;
end;

procedure TClEventManager.DelEvent (evn: TClEvent);
var
   i: integer;
begin
   for i:=0 to EventList.Count-1 do
      if EventList[i] = evn then begin
         TClEvent(EventList[i]).Free;
         EventList.Delete (i);
         break;
      end;
end;

procedure TClEventManager.DelEventById (svid: integer);
var
   i: integer;
begin
   for i:=0 to EventList.Count-1 do
      if TClEvent(EventList[i]).ServerId = svid then begin
         TClEvent(EventList[i]).Free;
         EventList.Delete (i);
         break;
      end;
end;

function  TClEventManager.GetEvent (ax, ay, etype: integer): TClEvent;
var
   i: integer;
begin
   Result := nil;
   for i:=0 to EventList.Count-1 do
      if (TClEvent(EventList[i]).X = ax) and (TClEvent(EventList[i]).Y = ay) and
         (TClEvent(EventList[i]).EventType = etype) then begin
         Result := TClEvent(EventList[i]);
         break;
      end;
end;

procedure TClEventManager.Execute;
var
   i: integer;
begin
   for i:=0 to EventList.Count-1 do
      TClEvent(EventList[i]).Run;
end;

end.
