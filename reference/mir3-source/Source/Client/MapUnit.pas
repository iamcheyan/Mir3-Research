unit MapUnit;

interface

uses
  Windows, Classes, SysUtils, Grobal2, HUtil32, HGETextures, CliUtil;

const
  MAPDIR = '.\Map\';
  MAXX = 40;
  MAXY = 40;

type
// -------------------------------------------------------------------------------
// Map
// -------------------------------------------------------------------------------
  TMapFileHeader = packed record
    szDesc: array[0..19] of char;
    wAttr: Word;
    shWidth: Word;
    shHeight: Word;
    cEventFileIdx: Byte;
    cFogColor: Byte;
  end;

  TTileInfo = packed record
    bFileIdx: byte;
    wTileIdx: Word;
  end;
  pTTileInfo = ^TTileInfo;

  TCellInfo = packed record
    bFlag: byte;
    bObj1Ani: byte;
    bObj2Ani: byte;
    wFileIdx: Word;
    wObj1: Word;
    wObj2: Word;
    bDoorIdx: byte;
    bDoorOffset: Word;
    wLigntNEvent: Word;
  end;
  pTCellInfo = ^TCellInfo;

  TMapInfoArr = array[0..MaxListSize] of TCellInfo;
  PTMapInfoArr = ^TMapInfoArr;

  TMap = class
  private
    function loadmapinfo(mapfile: string; var width, height: integer): Boolean;
    procedure updatemapseg(cx, cy: integer); //, maxsegx, maxsegy: integer);
    procedure updatemap(cx, cy: integer);
  public
    MapBase: string;
    MArr: array[0..MAXX * 3, 0..MAXY * 3] of TTileInfo;
    MArrOb: array[0..MAXX * 3, 0..MAXY * 3] of TCellInfo;
    ClientRect: TRect;
    OldClientRect: TRect;
    BlockLeft, BlockTop: integer;
    oldleft, oldtop: integer;
    oldmap: string;
    CurUnitX, CurUnitY: integer;
    CurrentMap: string;
    Segmented: Boolean;
    SegXCount, SegYCount: integer;
    shWidth, shHeight: integer;
    constructor Create;
    destructor Destroy;
    procedure UpdateMapSquare(cx, cy: integer);
    procedure UpdateMapPos(mx, my: integer);
    procedure ReadyReload;
    procedure LoadMap(mapname: string; mx, my: integer);
    procedure MarkCanWalk(mx, my: integer; bowalk: Boolean);
    function CanMove(mx, my: integer): Boolean;
    function CanFly(mx, my: integer): Boolean;
    function GetDoor(mx, my: integer): Integer;
    function IsDoorOpen(mx, my: integer): Boolean;
    function OpenDoor(mx, my: integer): Boolean;
    function CloseDoor(mx, my: integer): Boolean;
  end;

implementation

uses
  ClMain;

constructor TMap.Create;
begin
  inherited Create;
   //GetMem (MInfoArr, sizeof(TMapInfo) * LOGICALMAPUNIT * 3 * LOGICALMAPUNIT * 3);
  ClientRect := Rect(0, 0, 0, 0);
  MapBase := MAPDIR;
  CurrentMap := '';
  Segmented := FALSE;
  SegXCount := 0;
  SegYCount := 0;
  CurUnitX := -1;
  CurUnitY := -1;
  BlockLeft := -1;
  BlockTop := -1;
  oldmap := '';
  shWidth := 0;
  shHeight := 0;
end;

destructor TMap.Destroy;
begin
  inherited Destroy;
end;

function TMap.loadmapinfo(mapfile: string; var width, height: integer): Boolean;
var
  flname: string;
  fhandle: integer;
  header: TMapFileHeader;
begin
  Result := FALSE;
  flname := MapBase + mapfile;
  if FileExists(flname) then begin
    fhandle := FileOpen(flname, fmOpenRead or fmShareDenyNone);
    if fhandle > 0 then begin
      FileRead(fhandle, header, sizeof(TMapFileHeader));
      width := header.shWidth;
      height := header.shHeight;
    end;
    FileClose(fhandle);
  end;
end;

procedure TMap.updatemapseg(cx, cy: integer); //, maxsegx, maxsegy: integer);
begin

end;

procedure TMap.updatemap(cx, cy: integer);
var
  fhandle, i, k, aline, lx, rx, ty, by: integer;
  header: TMapFileHeader;
  flname: string;
begin
  FillChar(MArr, sizeof(MArr), #0);
  Fillchar(MArrOb, SizeOf(MArrOb), #0);
  flname := MapBase + CurrentMap + '.map';
  if FileExists(flname) then begin
    fhandle := FileOpen(flname, fmOpenRead or fmShareDenyNone);
    if fhandle > 0 then begin
      FileSeek(fhandle, 0, 0);
      FileRead(fhandle, header, sizeof(TMapFileHeader));

      shWidth := header.shWidth;
      shHeight := header.shHeight;
      lx := (cx - 1) * LOGICALMAPUNIT;
      rx := (cx + 2) * LOGICALMAPUNIT;
      ty := (cy - 1) * LOGICALMAPUNIT;
      by := (cy + 2) * LOGICALMAPUNIT;
      if lx < 0 then lx := 0;
      if ty < 0 then ty := 0;

      if by >= header.shHeight then
        by := header.shHeight;

      aline := sizeof(TTileInfo) * (header.shHeight div 2);

      for i := lx div 2 {+ 14} to lx div 2 + 44 {+ 44} do begin
        if (i >= 0) and (i < header.shWidth) then begin
          FileSeek(fhandle, SizeOf(header) + (aline * i) + (SizeOf(TTileInfo) * ty div 2), 0);

          FileRead(fhandle, MArr[i - lx div 2, 0], aline);
        end;
      end;
      aline := sizeof(TCellInfo) * (header.shHeight);

      for i := lx to lx + 90 do begin
        if (i >= 0) and (i < header.shWidth) then begin
          FileSeek(fhandle, SizeOf(header) + (header.shWidth * header.shHeight * 3 div 4) + (aline * i) + (SizeOf(TCellInfo) * ty), 0);
          FileRead(fhandle, MArrOb[i - lx, 0], SizeOf(TCellInfo) * (by - ty));
        end;
      end;
      FileClose(fhandle);
    end;
  end;
end;

procedure TMap.ReadyReload;
begin
  CurUnitX := -1;
  CurUnitY := -1;
end;

procedure TMap.UpdateMapSquare(cx, cy: integer);
begin
  if (cx <> CurUnitX) or (cy <> CurUnitY) then begin
    if Segmented then
      updatemapseg(cx, cy)
    else
      updatemap(cx, cy);
    CurUnitX := cx;
    CurUnitY := cy;
  end;
end;

procedure TMap.UpdateMapPos(mx, my: integer);
var
  cx, cy: integer;
//   procedure Unmark (xx, yy: integer);
//   var
//      ax, ay: integer;
//   begin
//      if (cx = xx div LOGICALMAPUNIT) and (cy = yy div LOGICALMAPUNIT) then begin
//         ax := xx - BlockLeft;
//         ay := yy - BlockTop;
//         MArr[ax,ay].FrImg := MArr[ax,ay].FrImg and $7FFF;
//         MArr[ax,ay].BkImg := MArr[ax,ay].BkImg and $7FFF;
//      end;
//   end;
begin
  cx := mx div LOGICALMAPUNIT;
  cy := my div LOGICALMAPUNIT;
  BlockLeft := _MAX(0, (cx - 1) * LOGICALMAPUNIT);
  BlockTop := _MAX(0, (cy - 1) * LOGICALMAPUNIT);

  UpdateMapSquare(cx, cy);

//   if (oldleft <> BlockLeft) or (oldtop <> BlockTop) or (oldmap <> CurrentMap) then begin
//      //3번맵 성벽자리 버그 보정 (2001-7-3)
//      if CurrentMap = '3' then begin
//         Unmark (624, 278);
//         Unmark (627, 278);
//         Unmark (634, 271);
//
//         Unmark (564, 287);
//         Unmark (564, 286);
//         Unmark (661, 277);
//         Unmark (578, 296);
//      end;
//   end;
  oldleft := BlockLeft;
  oldtop := BlockTop;
end;

//맵변경시 처음 한번 호출..
procedure TMap.LoadMap(mapname: string; mx, my: integer);
begin
  CurUnitX := -1;
  CurUnitY := -1;
  CurrentMap := mapname;
  Segmented := FALSE;
  UpdateMapPos(mx, my);
  oldmap := CurrentMap;
end;

procedure TMap.MarkCanWalk(mx, my: integer; bowalk: Boolean);
var
  cx, cy: integer;
begin
  cx := mx - BlockLeft;
  cy := my - BlockTop;
  if (cx < 0) or (cy < 0) then exit;
  if bowalk then
    Map.MArrOb[cx, cy].bFlag := 1
  else
    Map.MArrOb[cx, cy].bFlag := 0;
end;

function TMap.CanMove(mx, my: integer): Boolean;
var
  cx, cy: integer;
begin
  cx := mx - BlockLeft;
  cy := my - BlockTop;
  if (cx < 0) or (cy < 0) then exit;
  Result := Boolean((Map.MArrOb[cx, cy].bFlag) and $01);
  if result then begin
    if Map.MArrOb[cx, cy].bDoorIdx and $80 <> 0 then begin
      if (Map.MArrOb[cx, cy].bDoorOffset and $8000) = 0 then
        Result := FALSE;
    end;
  end;
end;

function TMap.CanFly(mx, my: integer): Boolean;
var
  cx, cy: integer;
begin
  cx := mx - BlockLeft;
  cy := my - BlockTop;
  if (cx < 0) or (cy < 0) then exit;
end;

function TMap.GetDoor(mx, my: integer): Integer;
var
  cx, cy: integer;
begin
  Result := 0;
  cx := mx - BlockLeft;
  cy := my - BlockTop;
  if Map.MArrOb[cx, cy].bDoorIdx and $80 > 0 then begin
    Result := Map.MArrOb[cx, cy].bDoorIdx and $7F;
  end;
end;

function TMap.IsDoorOpen(mx, my: integer): Boolean;
var
  cx, cy: integer;
begin
  Result := FALSE;
  cx := mx - BlockLeft;
  cy := my - BlockTop;
  if Map.MArrOb[cx, cy].bDoorIdx and $80 > 0 then begin
    Result := (Map.MArrOb[cx, cy].bDoorOffset and $8000 <> 0);
  end;
end;

function TMap.OpenDoor(mx, my: integer): Boolean;
var
  i, j, cx, cy, idx: integer;
begin
  Result := FALSE;
  cx := mx - BlockLeft;
  cy := my - BlockTop;
  if (cx < 0) or (cy < 0) then exit;
  if Map.MArrOb[cx, cy].bDoorIdx and $80 > 0 then begin
    idx := Map.MArrOb[cx, cy].bDoorIdx and $7F;
    for i := cx - 10 to cx + 10 do begin
      for j := cy - 10 to cy + 10 do begin
        if (i > 0) and (j > 0) then
          if (Map.MArrOb[i, j].bDoorIdx and $7F) = idx then
            Map.MArrOb[i, j].bDoorOffset := Map.MArrOb[i, j].bDoorOffset or $8000;
      end;
    end;
  end;
end;

function TMap.CloseDoor(mx, my: integer): Boolean;
var
  i, j, cx, cy, idx: integer;
begin
  Result := FALSE;
  cx := mx - BlockLeft;
  cy := my - BlockTop;
  if (cx < 0) or (cy < 0) then exit;
  if Map.MArrOb[cx, cy].bDoorIdx and $80 > 0 then begin
    idx := Map.MArrOb[cx, cy].bDoorIdx and $7F;
    for i := cx - 8 to cx + 10 do begin
      for j := cy - 8 to cy + 10 do begin
        if (Map.MArrOb[i, j].bDoorIdx and $7F) = idx then
          Map.MArrOb[i, j].bDoorOffset := Map.MArrOb[i, j].bDoorOffset and $7FFF;
      end;
    end;
  end;
end;

end.

