unit ClFunc;

interface

uses
  Windows, Messages, SysUtils, Classes, Graphics, Controls, Forms, Dialogs,
  HGETextures, {DirectX, DXClass, }Grobal2, ScktComp, ExtCtrls, HUtil32, EdCode, IniFiles;


const
   DR_0      = 0;
   DR_1      = 1;
   DR_2      = 2;
   DR_3      = 3;
   DR_4      = 4;
   DR_5      = 5;
   DR_6      = 6;
   DR_7      = 7;
   DR_8      = 8;
   DR_9      = 9;
   DR_10      = 10;
   DR_11      = 11;
   DR_12      = 12;
   DR_13      = 13;
   DR_14      = 14;
   DR_15      = 15;

type
   TDynamicObject = record  //바닥에 흔적
      X: integer;  //캐릭 좌표계
      Y: integer;
      px: integer;  //shiftx ,y
      py: integer;
      DSurface: TDirectDrawSurface;
   end;
   PTDynamicObject = ^TDynamicObject;


var
   DropItems: TList;  //lsit of TClientItem

function  fmStr (str: string; len: integer): string;
function  GetGoldStr (gold: integer): string;
procedure SaveBags (flname: string; pbuf: Pbyte);
procedure SaveOption (flname: string);
procedure Loadbags (flname: string; pbuf: Pbyte);
procedure LoadOption;
procedure ClearBag;
function  AddItemBag (cu: TClientItem): Boolean;
function  GetSameItemFromBag (cu: TClientItem): Integer;
function AddMakeItem (ci: TClientItem): Boolean; // 제조
function SearchOverlapItem (ci: TClientItem): Boolean;
function MakeStrMakeItem (): string;
function  ChangeItemCount ( mindex :integer; Count, MsgNum :word; iname :string ): Boolean;
function  SellItemProg (remain, sellcnt :word): Boolean;
function  UpdateItemBag (cu: TClientItem): Boolean;
function  DelItemBag (iname: string; iindex: integer): Boolean;
function  DelCountItemBag (iname: string; iindex: integer; Count: word): Boolean;
procedure ArrangeItemBag;
procedure AddDropItem (ci: TClientItem);
function  GetDropItem (iname: string; MakeIndex: integer): PTClientItem;
procedure DelDropItem (iname: string; MakeIndex: integer);
procedure AddDealItem (ci: TClientItem);
procedure ResultDealItem (ci: TClientItem; mIndex: integer; Count: word);
procedure DelDealItem (ci: TClientItem);
procedure MoveMakeItemToBag;
procedure DelMakingItem (ci: TClientItem);
procedure MoveDealItemToBag;
procedure AddDealRemoteItem (ci: TClientItem);
procedure DelDealRemoteItem (ci: TClientItem);
function  GetDistance (sx, sy, dx, dy: integer): integer;
procedure GetNextPosXY (dir: byte; var x, y:Integer);
procedure GetNextRunXY (dir: byte; var x, y:Integer);
function  GetNextDirection (sx, sy, dx, dy: Integer): byte;
function  GetBack (dir: integer): integer;
procedure GetBackPosition (sx, sy, dir: integer; var newx, newy: integer);
procedure GetFrontPosition (sx, sy, dir: integer; var newx, newy: integer);
function  GetFlyDirection (sx, sy, ttx, tty: integer): Integer;
function  GetFlyDirection16 (sx, sy, ttx, tty: integer): Integer;
function  PrivDir (ndir: integer): integer;
function  NextDir (ndir: integer): integer;
//procedure BoldTextOut (surface: TDirectDrawSurface; x, y, fcolor, bcolor: integer; str: string);
function  GetTakeOnPosition (smode: integer): integer;
function  IsKeyPressed (key: byte): Boolean;

procedure AddChangeFace (recogid: integer);
procedure DelChangeFace (recogid: integer);
function  IsChangingFace (recogid: integer): Boolean;

implementation

uses
   clMain;


function fmStr (str: string; len: integer): string;
var i: integer;
begin
try
   Result := str + ' ';
   for i:=1 to len - Length(str)-1 do
      Result := Result + ' ';
except
	Result := str + ' ';
end;
end;

function  GetGoldStr (gold: integer): string;
var
   i, n: integer;
   str: string;
begin
   str := IntToStr (gold);
   n := 0;
   Result := '';
   for i:=Length(str) downto 1 do begin
      if n = 3 then begin
         Result := str[i] + ',' + Result;
         n := 1;
      end else begin
         Result := str[i] + Result;
         Inc(n);
      end;
   end;
end;

procedure SaveBags (flname: string; pbuf: Pbyte);
var
   fhandle: integer;
begin
   if FileExists (flname) then
      fhandle := FileOpen (flname, fmOpenWrite or fmShareDenyNone)
   else fhandle := FileCreate (flname);
   if fhandle > 0 then begin
      FileWrite (fhandle, pbuf^, sizeof(TClientItem) * MAXBAGITEMCL);
      FileClose (fhandle);
   end;
end;

procedure SaveOption (flname: string);
var
  fp        : TextFile;
//  str       : String;
  GameStartData : TStringList;
begin

  GameStartData := TStringList.Create;
  GameStartData.Add('[Option]');
  GameStartData.Add('SkillKeyMode=' + IntToStr(SkillKeyMode));
  GameStartData.Add('SkillBarNum='  + IntToStr(SkillBarNum));

  if BoSkillBarView then GameStartData.Add('SkillBarView=1')       //BoViewEffect
  else GameStartData.Add('SkillBarView=0');

  if BoViewEffect then GameStartData.Add('ViewEffect=1')       //BoViewEffect
  else GameStartData.Add('ViewEffect=0');

  if BoPlaySoundEffect then GameStartData.Add('Sound=1')       //BoPlaySoundEffect
  else GameStartData.Add('Sound=0');

  if DropItemView then GameStartData.Add('DropItemView=1')       //BoPlaySoundEffect
  else GameStartData.Add('DropItemView=0');

  AssignFile(fp, flname);
  Rewrite(fp);
  Write(fp, GameStartData.Text);
  CloseFile(fp);
//     MessageDlg (GameStartData.Text, mtError, [mbOk], 0);
  GameStartData.Free;
end;

procedure Loadbags (flname: string; pbuf: Pbyte);
var
   fhandle: integer;
begin
   if FileExists (flname) then begin
      fhandle := FileOpen (flname, fmOpenRead or fmShareDenyNone);
      if fhandle > 0 then begin
         FileRead (fhandle, pbuf^, sizeof(TClientItem) * MAXBAGITEMCL);
         FileClose (fhandle);
      end;
   end;
end;

procedure LoadOption;
var
   ini: TIniFile;
begin
   ini := TIniFile.Create ('.\Data\' + ServerName + '.' + FrmMain.CharName + '.Opt'); //@@@@
   if ini <> nil then begin
      SkillKeyMode := ini.ReadInteger ('Option', 'SkillKeyMode', 1);
      SkillBarNum := ini.ReadInteger ('Option', 'SkillBarNum', 1);

      if ini.ReadString ('Option', 'SkillBarView', '1') = '1' then BoSkillBarView := True
      else BoSkillBarView := False;

      if ini.ReadString ('Option', 'ViewEffect', '1') = '1' then BoViewEffect := True
      else BoViewEffect := False;

      if ini.ReadString ('Option', 'Sound', '1') = '1' then BoPlaySoundEffect := True
      else BoPlaySoundEffect := False;

      if ini.ReadString ('Option', 'DropItemView', '1') = '1' then DropItemView := True
      else DropItemView := False;

      ini.Free;
   end;
   BoOptionLoaded := True;
end;

procedure ClearBag;
var
   i: integer;
begin
   for i:=0 to MAXBAGITEMCL-1 do
      ItemArr[i].S.Name := '';
end;

function  AddItemBag (cu: TClientItem): Boolean;
var
   i : integer;
   InputCheck : Boolean;
begin
   Result := FALSE;
   InputCheck := False;
   for i:=0 to MAXBAGITEMCL-1 do begin
      if (ItemArr[i].MakeIndex = cu.MakeIndex) and (ItemArr[i].S.Name = cu.S.Name) and
         (ItemArr[i].S.OverlapItem < 1) then begin
         exit;  //잔상..
      end;
   end;

   if cu.S.Name = '' then exit;

   if (cu.S.StdMode = 25) then begin //독가루, 부적
      for i:=4 to 5 do
         if ItemArr[i].S.Name = '' then begin
            ItemArr[i] := cu;
            Result := TRUE;
            exit;
         end;
   end;

   if cu.S.StdMode <= 3 then begin //포션, 음식, 스크롤
      for i:=0 to 5 do
         if ItemArr[i].S.Name = '' then begin
            ItemArr[i] := cu;
            Result := TRUE;
            exit;
         end;
   end;

   for i:=6 to MAXBAGITEMCL-1 do begin
      if (ItemArr[i].S.OverlapItem > 0) and (ItemArr[i].S.Name = cu.S.Name) and
          (ItemArr[i].MakeIndex = cu.MakeIndex) then begin
//          ItemArr[i].S.ItemCount := ItemArr[i].S.ItemCount + cu.S.ItemCount;
          ItemArr[i].Dura := ItemArr[i].Dura + cu.Dura;
          cu.Dura := 0;
          InputCheck := True;
//          DScreen.AddSysMsg ('InputCheck := True;');
      end;
   end;

   if not InputCheck then begin
      for i:=6 to MAXBAGITEMCL-1 do begin
         if ItemArr[i].S.Name = '' then begin
            ItemArr[i] := cu;
            Result := TRUE;
            break;
         end;
      end;
   end;
   ArrangeItembag;
end;

function  GetSameItemFromBag (cu: TClientItem): Integer;
var
   i : integer;
   InputCheck : Boolean;
begin
   Result := -100;
//   for i:=6 to MAXBAGITEMCL-1 do begin
   for i:=MAXBAGITEMCL-1 Downto 6 do begin
      if (ItemArr[i].S.StdMode = cu.S.StdMode) and (ItemArr[i].S.Shape = cu.S.Shape) and
         (ItemArr[i].S.Name <> '') and (ItemArr[i].S.Looks = cu.S.Looks) and
         (ItemArr[i].S.Price = cu.S.Price) then begin
         Result := i;
         Exit;
      end;
   end;
end;

function  ChangeItemCount ( mindex :integer; Count, MsgNum :word; iname :string ): Boolean;
var
   i : integer;
begin

   Result := False;

   // 2004/03/23 노끈일때 처리
   if MovingItem.Item.S.StdMode = 7 then FrmMain.MainCancelItemMoving;

   for i:=6 to MAXBAGITEMCL-1 do begin
      if (ItemArr[i].MakeIndex = mindex) and (ItemArr[i].S.Name = iname) and
         (ItemArr[i].S.OverlapItem > 0)  then begin
         if Count < 1 then begin
            ItemArr[i].S.Name := '';
            Count := 0;
         end;
         ItemArr[i].Dura := Count;
         Result := True;
         Break;
      end;
   end;
   ArrangeItembag;

   if (Result = False) and (not BoDealEnd) then begin
      for i:=0 to 10-1 do begin
         if (DealItems[i].S.Name = iname) and (DealItems[i].S.OverlapItem > 0) and
            ( DealItems[i].MakeIndex = mindex ) then begin
            if Count < 1 then begin
               DealItems[i].S.Name := '';
               Count := 0;
            end;
            DealItems[i].Dura := Count;
            Result := True;
            Break;
         end;
      end;
   end;

   if (Result = False) and (not BoDealEnd) then begin
      for i:=0 to 19 do begin
         if (DealRemoteItems[i].S.Name = iname) and (DealRemoteItems[i].S.OverlapItem > 0) and
            ( DealRemoteItems[i].MakeIndex = mindex ) then begin
            if Count < 1 then begin
               DealRemoteItems[i].S.Name := '';
               Count := 0;
            end;
            DealRemoteItems[i].Dura := Count;
            Result := True;
            Break;
         end;
      end;
   end;

   if MsgNum = 1 then DScreen.AddSysMsg (iname + '을 얻었습니다.');

end;

function  SellItemProg (remain, sellcnt :word): Boolean;
var
   i : integer;
begin

   Result := False;
   for i:=0 to MAXBAGITEMCL-1 do begin
      if (ItemArr[i].MakeIndex = SellDlgItemSellWait.MakeIndex) and
         (ItemArr[i].S.Name = SellDlgItemSellWait.S.Name) and
         (ItemArr[i].S.OverlapItem > 0)  then begin
         if remain < 1 then begin
            ItemArr[i].S.Name := '';
            remain := 0;
         end;
         ItemArr[i].Dura := remain;
         Result := True;
      end;
   end;

end;


function  UpdateItemBag (cu: TClientItem): Boolean;
var
   i: integer;
begin
   Result := FALSE;
   for i:=MAXBAGITEMCL-1 downto 0 do begin
      if (ItemArr[i].S.Name = cu.S.Name) and (ItemArr[i].MakeIndex = cu.MakeIndex) then begin
         ItemArr[i] := cu;  //업데이트
         Result := TRUE;
         break;
      end;
   end;
end;

function  DelItemBag (iname: string; iindex: integer): Boolean;
var
   i: integer;
begin
   Result := FALSE;
   for i:=MAXBAGITEMCL-1 downto 0 do begin
      if (ItemArr[i].S.Name = iname) and (ItemArr[i].MakeIndex = iindex) then begin
         FillChar (ItemArr[i], sizeof(TClientItem), #0);
         Result := TRUE;
         break;
      end;
   end;
   ArrangeItembag;
end;

function  DelCountItemBag (iname: string; iindex: integer; Count: word): Boolean;
var
   i: integer;
begin
   Result := FALSE;
   for i:=MAXBAGITEMCL-1 downto 0 do begin
      if ItemArr[i].S.Name = iname  then begin
         if ItemArr[i].S.OverlapItem > 0 then begin
            ItemArr[i].Dura := ItemArr[i].Dura - Count;
            if ItemArr[i].Dura <= 0 then begin
               ItemArr[i].S.Name := '';
               ItemArr[i].Dura := 0;
            end;
         end
         else if ItemArr[i].MakeIndex = iindex then begin
            FillChar (ItemArr[i], sizeof(TClientItem), #0);
            Result := TRUE;
            break;
         end;
      end;
   end;
   ArrangeItembag;
end;

procedure ArrangeItemBag;
var
   i, k: integer;
begin
   //중복된 아이템이 있으면 없앤다.
   for i:=0 to MAXBAGITEMCL-1 do begin
      if ItemArr[i].S.Name <> '' then begin
         for k:=i+1 to MAXBAGITEMCL-1 do begin
            if (ItemArr[i].S.Name = ItemArr[k].S.Name) and (ItemArr[i].MakeIndex = ItemArr[k].MakeIndex) then begin
               if ItemArr[i].S.OverlapItem > 0 then begin
                  ItemArr[i].Dura := ItemArr[i].Dura + ItemArr[k].Dura;
                  FillChar (ItemArr[k], sizeof(TClientItem), #0);
               end
               else begin
                  FillChar (ItemArr[k], sizeof(TClientItem), #0);
               end;
            end;
         end;
         if (ItemArr[i].S.Name = MovingItem.Item.S.Name) and (ItemArr[i].MakeIndex = MovingItem.Item.MakeIndex) and
            (ItemArr[i].S.OverlapItem < 1) then begin
            MovingItem.Index := 0;
            MovingItem.Item.S.Name := '';
         end;
      end;
   end;

   //가방의 안보이는 부분에 있으면 끌어 올린다.
   for i:=46 to MAXBAGITEMCL-1 do begin
      if ItemArr[i].S.Name <> '' then begin
         for k:=6 to 45 do begin
            if ItemArr[k].S.Name = '' then begin
               ItemArr[k] := ItemArr[i];
               ItemArr[i].S.Name := '';
               break;
            end;
         end;
      end;
   end;
end;

{----------------------------------------------------------}

procedure AddDropItem (ci: TClientItem);
var
   pc: PTClientItem;
begin
   new (pc);
   pc^ := ci;
   DropItems.Add (pc);
end;

function  GetDropItem (iname: string; MakeIndex: integer): PTClientItem;
var
   i: integer;
begin
   Result := nil;
   for i:=0 to DropItems.Count-1 do begin
      if (PTClientItem(DropItems[i]).S.Name = iname) and (PTClientItem(DropItems[i]).MakeIndex = MakeIndex) then begin
         Result := PTClientItem(DropItems[i]);
         break;
      end;
   end;
end;

procedure DelDropItem (iname: string; MakeIndex: integer);
var
   i: integer;
begin
   for i:=0 to DropItems.Count-1 do begin
      if (PTClientItem(DropItems[i]).S.Name = iname) and (PTClientItem(DropItems[i]).MakeIndex = MakeIndex) then begin
         Dispose (PTClientItem(DropItems[i]));
         DropItems.Delete (i);
         break;
      end;
   end;
end;

{----------------------------------------------------------}

procedure ResultDealItem (ci: TClientItem; mIndex: integer; Count: word);
var
   i: integer;
begin
   for i:=0 to 10-1 do begin

      if (DealItems[i].S.Name = ci.S.Name) and (DealItems[i].S.OverlapItem > 0) then begin
         if (DealItems[i].S.Name = ci.S.Name) and (DealItems[i].MakeIndex = mIndex) then
         DealItems[i].Dura := DealItems[i].Dura + ci.Dura;
            DealItems[i].MakeIndex := mIndex;
         break;
      end
      else if DealItems[i].S.Name = '' then begin
         DealItems[i] := ci;
         DealItems[i].MakeIndex := mIndex;
         break;
      end;
   end;

   for i:=0 to MAXBAGITEMCL-1 do begin
      if  (ItemArr[i].S.Name = ci.S.Name) and (ItemArr[i].S.OverlapItem > 0) and
          (ItemArr[i].MakeIndex = ci.MakeIndex) then begin
         if Count < 1 then begin
            ItemArr[i].S.Name := '';
            Count := 0;
         end;
         ItemArr[i].Dura := Count;
      end;
   end;

end;
{procedure AddDealItem (ci: TClientItem);
var
   i: integer;
begin
   for i:=0 to 10-1 do begin
      if DealItems[i].S.Name = '' then begin
         DealItems[i] := ci;
         break;
      end;
   end;
end;}
// 교환=>겹치기
procedure AddDealItem (ci: TClientItem);
var
   i: integer;
begin
   for i:=0 to 10-1 do begin
      if (DealItems[i].S.Name = ci.S.Name) and (DealItems[i].S.OverlapItem > 0) then begin
         DealItems[i].Dura := DealItems[i].Dura + ci.Dura;
         break;
      end
      else if DealItems[i].S.Name = '' then begin
         DealItems[i] := ci;
         break;
      end;
   end;
end;


function AddMakeItem (ci: TClientItem): Boolean;
var
   i: integer;
begin
   Result := False;
   for i:=0 to 5 do begin
      if (MakeItemArr[i].S.Name = ci.S.Name) and (MakeItemArr[i].S.OverlapItem > 0) then begin
         MakeItemArr[i].Dura := MakeItemArr[i].Dura + ci.Dura;
         Result := True;
         break;
      end
      else if MakeItemArr[i].S.Name = '' then begin
         MakeItemArr[i] := ci;
         if MakeItemArr[i].S.OverlapItem < 1 then begin
            MovingItem.Item.S.Name := '';
            ItemMoving := FALSE;
         end;
         Result := True;
         break;
      end;
   end;
end;

function SearchOverlapItem (ci: TClientItem): Boolean;
var
   i: integer;
begin
   Result := False;
   for i:=0 to 5 do begin
      if (MakeItemArr[i].S.Name = ci.S.Name) and (MakeItemArr[i].S.OverlapItem > 0) then begin
         Result := True;
         Break;
      end
   end;
end;

function MakeStrMakeItem (): string;
var
   i: integer;
   data : string;
begin
   data := '';
   for i:=0 to 5 do begin
      if MakeItemArr[i].S.Name <> ''  then begin
         data := data + IntToStr( MakeItemArr[i].MakeIndex ) + ':';
         data := data + MakeItemArr[i].S.Name + ':';
         if MakeItemArr[i].S.OverlapItem > 0 then data := data + IntToStr( MakeItemArr[i].Dura ) + '/'
         else data := data + '1/';
      end;
   end;
   Result := data;
end;

procedure MoveMakeItemToBag;
var
   i: integer;
begin
   for i:=0 to 5 do begin
      if MakeItemArr[i].S.Name <> '' then
         AddItemBag (MakeItemArr[i]);
         MakeItemArr[i].S.Name := '';
   end;
//   FrmDlg.CancelItemMoving;
//   FillChar (DealItems, sizeof(TClientItem)*10, #0);
end;


procedure DelDealItem (ci: TClientItem);
var
   i: integer;
begin
   for i:=0 to 10-1 do begin
      if (DealItems[i].S.Name = ci.S.Name) and (DealItems[i].MakeIndex = ci.MakeIndex) then begin
         FillChar (DealItems[i], sizeof(TClientItem), #0);
         break;
      end;
   end;
end;

procedure DelMakingItem (ci: TClientItem);
var
   i: integer;
begin
   for i:=0 to 5 do begin
      if (MakeItemArr[i].S.Name = ci.S.Name) and (MakeItemArr[i].MakeIndex = ci.MakeIndex) then begin
         FillChar (MakeItemArr[i], sizeof(TClientItem), #0);
         break;
      end;
   end;
end;
procedure MoveDealItemToBag;
var
   i: integer;
begin
   for i:=0 to 10-1 do begin
      if (DealItems[i].S.Name <> '') then
         if DealItems[i].S.OverlapItem <= 0 then AddItemBag (DealItems[i]);
   end;
   FillChar (DealItems, sizeof(TClientItem)*10, #0);
end;

procedure AddDealRemoteItem (ci: TClientItem);
var
   i: integer;
begin
   for i:=0 to 20-1 do begin
      if (DealRemoteItems[i].S.Name = ci.S.Name) and (ci.S.OverlapItem > 0) then begin
         DealRemoteItems[i].MakeIndex := ci.MakeIndex;

      end
      else if DealRemoteItems[i].S.Name = '' then begin
         DealRemoteItems[i] := ci;
         break;
      end;
   end;
end;

procedure DelDealRemoteItem (ci: TClientItem);
var
   i: integer;
begin
   for i:=0 to 20-1 do begin
      if (DealRemoteItems[i].S.Name = ci.S.Name) and (DealRemoteItems[i].MakeIndex = ci.MakeIndex) then begin
         FillChar (DealRemoteItems[i], sizeof(TClientItem), #0);
         break;
      end;
   end;
end;

{----------------------------------------------------------}

function  GetDistance (sx, sy, dx, dy: integer): integer;
begin
   Result := _MAX(abs(sx-dx), abs(sy-dy));
end;

procedure GetNextPosXY (dir: byte; var x, y:Integer);
begin
   case dir of
      DR_UP:     begin x := x;   y := y-1; end;
      DR_UPRIGHT:   begin x := x+1; y := y-1; end;
      DR_RIGHT:  begin x := x+1; y := y; end;
      DR_DOWNRIGHT:  begin x := x+1; y := y+1; end;
      DR_DOWN:   begin x := x;   y := y+1; end;
      DR_DOWNLEFT:   begin x := x-1; y := y+1; end;
      DR_LEFT:   begin x := x-1; y := y; end;
      DR_UPLEFT:  begin x := x-1; y := y-1; end;
   end;
end;

procedure GetNextRunXY (dir: byte; var x, y:Integer);
begin
   case dir of
      DR_UP:     begin x := x;   y := y-2; end;
      DR_UPRIGHT:   begin x := x+2; y := y-2; end;
      DR_RIGHT:  begin x := x+2; y := y; end;
      DR_DOWNRIGHT:  begin x := x+2; y := y+2; end;
      DR_DOWN:   begin x := x;   y := y+2; end;
      DR_DOWNLEFT:   begin x := x-2; y := y+2; end;
      DR_LEFT:   begin x := x-2; y := y; end;
      DR_UPLEFT:  begin x := x-2; y := y-2; end;
   end;
end;

function GetNextDirection (sx, sy, dx, dy: Integer): byte;
var
   flagx, flagy: integer;
begin
   Result := DR_DOWN;
   if sx < dx then flagx := 1
   else if sx = dx then flagx := 0
   else flagx := -1;
   if abs(sy-dy) > 2
    then if (sx >= dx-1) and (sx <= dx+1) then flagx := 0;

   if sy < dy then flagy := 1
   else if sy = dy then flagy := 0
   else flagy := -1;
   if abs(sx-dx) > 2 then if (sy > dy-1) and (sy <= dy+1) then flagy := 0;

   if (flagx = 0)  and (flagy = -1) then Result := DR_UP;
   if (flagx = 1)  and (flagy = -1) then Result := DR_UPRIGHT;
   if (flagx = 1)  and (flagy = 0)  then Result := DR_RIGHT;
   if (flagx = 1)  and (flagy = 1)  then Result := DR_DOWNRIGHT;
   if (flagx = 0)  and (flagy = 1)  then Result := DR_DOWN;
   if (flagx = -1) and (flagy = 1)  then Result := DR_DOWNLEFT;
   if (flagx = -1) and (flagy = 0)  then Result := DR_LEFT;
   if (flagx = -1) and (flagy = -1) then Result := DR_UPLEFT;
end;

function  GetBack (dir: integer): integer;
begin
   Result := DR_UP;
   case dir of
      DR_UP:     Result := DR_DOWN;
      DR_DOWN:   Result := DR_UP;
      DR_LEFT:   Result := DR_RIGHT;
      DR_RIGHT:  Result := DR_LEFT;
      DR_UPLEFT:     Result := DR_DOWNRIGHT;
      DR_UPRIGHT:    Result := DR_DOWNLEFT;
      DR_DOWNLEFT:   Result := DR_UPRIGHT;
      DR_DOWNRIGHT:  Result := DR_UPLEFT;
   end;
end;

procedure GetBackPosition (sx, sy, dir: integer; var newx, newy: integer);
begin
   newx := sx;
   newy := sy;
   case dir of
      DR_UP:      newy := newy+1;
      DR_DOWN:    newy := newy-1;
      DR_LEFT:    newx := newx+1;
      DR_RIGHT:   newx := newx-1;
      DR_UPLEFT:
         begin
            newx := newx + 1;
            newy := newy + 1;
         end;
      DR_UPRIGHT:
         begin
            newx := newx - 1;
            newy := newy + 1;
         end;
      DR_DOWNLEFT:
         begin
            newx := newx + 1;
            newy := newy - 1;
         end;
      DR_DOWNRIGHT:
         begin
            newx := newx - 1;
            newy := newy - 1;
         end;
   end;
end;

procedure GetFrontPosition (sx, sy, dir: integer; var newx, newy: integer);
begin
   newx := sx;
   newy := sy;
   case dir of
      DR_UP:      newy := newy-1;
      DR_DOWN:    newy := newy+1;
      DR_LEFT:    newx := newx-1;
      DR_RIGHT:   newx := newx+1;
      DR_UPLEFT:
         begin
            newx := newx - 1;
            newy := newy - 1;
         end;
      DR_UPRIGHT:
         begin
            newx := newx + 1;
            newy := newy - 1;
         end;
      DR_DOWNLEFT:
         begin
            newx := newx - 1;
            newy := newy + 1;
         end;
      DR_DOWNRIGHT:
         begin
            newx := newx + 1;
            newy := newy + 1;
         end;
   end;
end;

function  GetFlyDirection (sx, sy, ttx, tty: integer): Integer;
var
   fx, fy: Real;
begin
   fx := ttx - sx;
   fy := tty - sy;
   sx := 0;
   sy := 0;
   Result := DR_DOWN;
   if fx=0 then begin
      if fy < 0 then Result := DR_UP
      else Result := DR_DOWN;
      exit;
   end;
   if fy=0 then begin
      if fx < 0 then Result := DR_LEFT
      else Result := DR_RIGHT;
      exit;
   end;
   if (fx > 0) and (fy < 0) then begin
      if -fy > fx*2.5 then Result := DR_UP
      else if -fy < fx/3 then Result := DR_RIGHT
      else Result := DR_UPRIGHT;
   end;
   if (fx > 0) and (fy > 0) then begin
      if fy < fx/3 then Result := DR_RIGHT
      else if fy > fx*2.5 then Result := DR_DOWN
      else Result := DR_DOWNRIGHT;
   end;
   if (fx < 0) and (fy > 0) then begin
      if fy  < -fx/3 then Result := DR_LEFT
      else if fy > -fx*2.5 then Result := DR_DOWN
      else Result := DR_DOWNLEFT;
   end;
   if (fx < 0) and (fy < 0) then begin
      if -fy > -fx*2.5 then Result := DR_UP
      else if -fy < -fx/3 then Result := DR_LEFT
      else Result := DR_UPLEFT;
   end;
end;

function  GetFlyDirection16 (sx, sy, ttx, tty: integer): Integer;
var
   fx, fy: Real;
begin
   fx := ttx - sx;
   fy := tty - sy;
   sx := 0;
   sy := 0;
   Result := 0;
   if fx=0 then begin
      if fy < 0 then Result := 0
      else Result := 8;
      exit;
   end;
   if fy=0 then begin
      if fx < 0 then Result := 12
      else Result := 4;
      exit;
   end;
   if (fx > 0) and (fy < 0) then begin
      Result := 4;
      if -fy > fx/4 then Result := 3;
      if -fy > fx/1.9 then Result := 2;
      if -fy > fx*1.4 then Result := 1;
      if -fy > fx*4 then Result := 0;
   end;
   if (fx > 0) and (fy > 0) then begin
      Result := 4;
      if fy > fx/4 then Result := 5;
      if fy > fx/1.9 then Result := 6;
      if fy > fx*1.4 then Result := 7;
      if fy > fx*4 then Result := 8;
   end;
   if (fx < 0) and (fy > 0) then begin
      Result := 12;
      if fy > -fx/4 then Result := 11;
      if fy > -fx/1.9 then Result := 10;
      if fy > -fx*1.4 then Result := 9;
      if fy > -fx*4 then Result := 8;
   end;
   if (fx < 0) and (fy < 0) then begin
      Result := 12;
      if -fy > -fx/4 then Result := 13;
      if -fy > -fx/1.9 then Result := 14;
      if -fy > -fx*1.4 then Result := 15;
      if -fy > -fx*4 then Result := 0;
   end;
end;

function  PrivDir (ndir: integer): integer;
begin
   if ndir - 1 < 0 then Result := 7
   else Result := ndir-1;
end;

function  NextDir (ndir: integer): integer;
begin
   if ndir + 1 > 7 then Result := 0
   else Result := ndir+1;
end;

//procedure BoldTextOut (surface: TDirectDrawSurface; x, y, fcolor, bcolor: integer; str: string);
//begin
//   with surface do begin
//      Canvas.Font.Color := bcolor;
//      Canvas.TextOut (x-1, y, str);
//      Canvas.TextOut (x+1, y, str);
//      Canvas.TextOut (x, y-1, str);
//      Canvas.TextOut (x, y+1, str);
//      Canvas.Font.Color := fcolor;
//      Canvas.TextOut (x, y, str);
//   end;
//end;

function  GetTakeOnPosition (smode: integer): integer;
begin
   Result := -1;
   case smode of //StdMode
      5, 6: //무기
         Result := U_WEAPON;
      10, 11:
         Result := U_DRESS;
      15,16:
         Result := U_HELMET;
      19,20,21:
         Result := U_NECKLACE;
      22,23:
         Result := U_RINGL;
      24, 26:
         Result := U_ARMRINGR;
      // 2003/03/15 아이템 인벤토리 확장 25->26
//    26:
//       Result := U_ARMRINGL;
      30:
         Result := U_RIGHTHAND;
      // 2003/03/15 아이템 인벤토리 확장
      25:
         Result := U_BUJUK;
      54:
         Result := U_BELT;
      52:
         Result := U_BOOTS;
      53:
         Result := U_CHARM;

   end;
end;

function  IsKeyPressed (key: byte): Boolean;
var
   keyvalue: TKeyBoardState;
begin
   Result := FALSE;
   FillChar(keyvalue, sizeof(TKeyboardState), #0);
   if GetKeyboardState (keyvalue) then
      if (keyvalue[key] and $80) <> 0 then
         Result := TRUE;
end;

procedure AddChangeFace (recogid: integer);
begin
   ChangeFaceReadyList.Add (pointer(recogid));
end;

procedure DelChangeFace (recogid: integer);
var
   i: integer;
begin
   for i:=0 to ChangeFaceReadyList.Count-1 do begin
      if integer(ChangeFaceReadyList[i]) = recogid then begin
         ChangeFaceReadyList.Delete (i);
         break;
      end;
   end;
end;

function  IsChangingFace (recogid: integer): Boolean;
var
   i: integer;
begin
   Result := FALSE;
   for i:=0 to ChangeFaceReadyList.Count-1 do begin
      if integer(ChangeFaceReadyList[i]) = recogid then begin
         Result := TRUE;
         break;
      end;
   end;
end;


Initialization
DropItems := TList.Create;

Finalization
DropItems.Free;


end.
