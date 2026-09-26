unit M2Share;

interface

uses
  Windows, Messages, SysUtils, Classes, Graphics, Controls, Dialogs,
  ScktComp, syncobjs, MudUtil, HUtil32, Grobal2, EdCode, Envir,
  MFdbDef, ObjBase;


type
   TMonInfo = record
      Name: string;
      Race: integer;
   end;

  TSaveRcd = record
     uid: string;
     uname: string;
     certify: integer;
     savefail: integer;
     savetime: longword;
     hum: TUserHuman; //결과를 알리기 위해...
     rcd: FDBRecord;
  end;
  PTSaveRcd = ^TSaveRcd;

  TReadyUserInfo = record
     UserId: string[20];
     UserName: string[14];
     UserAddress: string[16];
     StartNew: Boolean;
     Certification: integer;
     ApprovalMode: integer;
     AvailableMode: integer;
     ClientVersion: integer;
     LoginClientVersion: integer;
     ClientCheckSum: integer;
     Shandle: integer;
     UserGateIndex: integer;
     GateIndex: integer;
     ReadyStartTime: longword;
     Closed: Boolean;
  end;
  PTReadyUserInfo = ^TReadyUserInfo;

  TChangeUserInfo = record
     CommandWho: string[14];  //명령을 한사람, 변경후 결과를 통보함...
     UserName: string[14];
     ChangeGold: integer;  //추가,삭제 될 돈
  end;
  PTChangeUserInfo = ^TChangeUserInfo;

  TUserOpenInfo = record
     Name: string;
     rcd: FDBRecord;
     readyinfo: TReadyUserInfo;
  end;
  PTUserOpenInfo = ^TUserOpenInfo;

   THolySeizeInfo = record   //결계
      earr: array[0..7] of TObject;
      seizelist: TList; //
      OpenTime: longword;
      SeizeTime: longword;
   end;
   PTHolySeizeInfo = ^THolySeizeInfo;


const
   MAXKINGLEVEL = 61;
   MAXLEVEL = 101;//61;
   NEEDEXPS : array[1..MAXLEVEL] of longword = (
      100,       //1
      200,      //2
      300,      //3
      400,      //4
      600,      //5
      900,      //6
      1200,      //7
      1700,      //8
      2500,     //9
      6000,     //10
      8000,     //11   5000
      10000,     //12   8000
      15000,     //13   12000
      30000,    //14   22000
      40000,    //15   36000
      50000,    //16   -
      70000, //80000,    //17   -
      100000, //120000,    //18
      120000, //170000,   //19
      140000, //250000,   //20
      250000,   //21
      300000,  //22
      350000,  //23
      400000,  //24
      500000, //1500000,  //25  24-
      700000,  //26  48-
      1000000,  //27
      1400000,  //28
      1800000,  //29
      2000000, //5200000,  //30
      2400000,  //31
      2800000,  //32
      3200000, //33
      3600000, //34
      4000000, //18900000, //35
      4800000,  //36
      5600000,  //37
      8200000,  //38
      9000000,  //39
      12000000, //69600000,     //40
      16000000, //90400000,     //41
      30000000, //117500000,    //42
      50000000, //152700000,    //43
      80000000, //198500000,    //44
      120000000, //258000000,   //45
      // 2003/02/11 필요경험치 테이블 변경
      160000000, //480000000,   //46
      200000000, //1000000000,  //47
      250000000, //3000000000,  //48
      300000000, //3500000000,  //49
      350000000, //4000000000,  //50
      400000000, //4000000000   //51
      480000000,                //52
      560000000,                //53
      640000000,                //54
      740000000,                //55
      840000000,                //56
      950000000,                //57
     1070000000,                //58
     1200000000,                //59
     1500000000,                //60
     1500000000,                 //61
     1600000000,                 //62
     1600000000,                 //63
     1700000000,                 //64
     1700000000,                 //65
     1800000000,                 //66
     1800000000,                 //67
     1900000000,                 //68
     1900000000,                 //69
     2000000000,                 //70
     2000000000,                 //71
     2000000000,                 //72
     2000000000,                 //73
     2000000000,                 //74
     2000000000,                 //75
     2000000000,                 //76
     2000000000,                 //77
     2000000000,                 //78
     2000000000,                 //79
     2000000000,                 //80
     2000000000,                 //81
     2000000000,                 //82
     2000000000,                 //83
     2000000000,                 //84
     2000000000,                 //85
     2000000000,                 //86
     2000000000,                 //87
     2000000000,                 //88
     2000000000,                 //89
     2000000000,                 //90
     2100000000,                 //91
     2100000000,                 //92
     2100000000,                 //93
     2100000000,                 //94
     2100000000,                 //95
     2100000000,                 //96
     2100000000,                 //97
     2100000000,                 //98
     2100000000,                 //99
     2100000000,                 //100
     2140000000                  //101
//   2147483647                 //62~ (int max값 : 4 byte)
   );

   ADJ_LEVEL = 20;  //15;

   WarriorBonus: TNakedAbility = (
      DC:   17;
      MC:   20;
      SC:   20;
      AC:   20;
      MAC:  20;
      HP:   1;
      MP:   3;
      Hit:  20;
      Speed: 35;
   );
   WizzardBonus: TNakedAbility = (
      DC:   17;
      MC:   25;
      SC:   30;
      AC:   20;
      MAC:  15;
      HP:   2;
      MP:   1;
      Hit:  25;
      Speed: 35;
   );
   PriestBonus: TNakedAbility = (
      DC:   20;
      MC:   30;
      SC:   17;
      AC:   20;
      MAC:  15;
      HP:   2;
      MP:   1;
      Hit:  30;
      Speed: 30;
   );


   SpitMap : array[0..7, 0..4, 0..4] of byte = (
      ( (0, 0, 1, 0, 0),     //DR_UP
        (0, 0, 1, 0, 0),
        (0, 0, 0, 0, 0),
        (0, 0, 0, 0, 0),
        (0, 0, 0, 0, 0) ),

      ( (0, 0, 0, 0, 1),     //DR_UPRIGHT
        (0, 0, 0, 1, 0),
        (0, 0, 0, 0, 0),
        (0, 0, 0, 0, 0),
        (0, 0, 0, 0, 0) ),

      ( (0, 0, 0, 0, 0),     //DR_RIGHT
        (0, 0, 0, 0, 0),
        (0, 0, 0, 1, 1),
        (0, 0, 0, 0, 0),
        (0, 0, 0, 0, 0) ),

      ( (0, 0, 0, 0, 0),     //DR_DOWNRIGHT
        (0, 0, 0, 0, 0),
        (0, 0, 0, 0, 0),
        (0, 0, 0, 1, 0),
        (0, 0, 0, 0, 1) ),

      ( (0, 0, 0, 0, 0),     //DR_DOWN
        (0, 0, 0, 0, 0),
        (0, 0, 0, 0, 0),
        (0, 0, 1, 0, 0),
        (0, 0, 1, 0, 0) ),

      ( (0, 0, 0, 0, 0),     //DR_DOWNLEFT
        (0, 0, 0, 0, 0),
        (0, 0, 0, 0, 0),
        (0, 1, 0, 0, 0),
        (1, 0, 0, 0, 0) ),

      ( (0, 0, 0, 0, 0),     //DR_LEFT
        (0, 0, 0, 0, 0),
        (1, 1, 0, 0, 0),
        (0, 0, 0, 0, 0),
        (0, 0, 0, 0, 0) ),

      ( (1, 0, 0, 0, 0),     //DR_UPLEFT
        (0, 1, 0, 0, 0),
        (0, 0, 0, 0, 0),
        (0, 0, 0, 0, 0),
        (0, 0, 0, 0, 0) )
   );

   CrossMap : array[0..7, 0..4, 0..4] of byte = (
      ( (0, 1, 1, 1, 0),     //DR_UP
        (0, 0, 1, 0, 0),
        (0, 0, 0, 0, 0),
        (0, 0, 0, 0, 0),
        (0, 0, 0, 0, 0) ),

      ( (0, 0, 0, 1, 1),     //DR_UPRIGHT
        (0, 0, 0, 1, 1),
        (0, 0, 0, 0, 0),
        (0, 0, 0, 0, 0),
        (0, 0, 0, 0, 0) ),

      ( (0, 0, 0, 0, 0),     //DR_RIGHT
        (0, 0, 0, 0, 1),
        (0, 0, 0, 1, 1),
        (0, 0, 0, 0, 1),
        (0, 0, 0, 0, 0) ),

      ( (0, 0, 0, 0, 0),     //DR_DOWNRIGHT
        (0, 0, 0, 0, 0),
        (0, 0, 0, 0, 0),
        (0, 0, 0, 1, 1),
        (0, 0, 0, 1, 1) ),

      ( (0, 0, 0, 0, 0),     //DR_DOWN
        (0, 0, 0, 0, 0),
        (0, 0, 0, 0, 0),
        (0, 0, 1, 0, 0),
        (0, 1, 1, 1, 0) ),

      ( (0, 0, 0, 0, 0),     //DR_DOWNLEFT
        (0, 0, 0, 0, 0),
        (0, 0, 0, 0, 0),
        (1, 1, 0, 0, 0),
        (1, 1, 0, 0, 0) ),

      ( (0, 0, 0, 0, 0),     //DR_LEFT
        (1, 0, 0, 0, 0),
        (1, 1, 0, 0, 0),
        (1, 0, 0, 0, 0),
        (0, 0, 0, 0, 0) ),

      ( (1, 1, 0, 0, 0),     //DR_UPLEFT
        (1, 1, 0, 0, 0),
        (0, 0, 0, 0, 0),
        (0, 0, 0, 0, 0),
        (0, 0, 0, 0, 0) )
   );



function  GetBonusPoint (job, lv: integer): integer;
function  GetLevelBonusSum (job, lv: integer): integer;
function  GetBack (dir: integer): integer;
function  GetFrontPosition (cret: TCreature; var newx, newy: integer): Boolean;
function  GetBackPosition (cret: TCreature; var newx, newy: integer): Boolean;
function  GetNextPosition (penv: TEnvirnoment; sx, sy, dir, dis: integer; var newx, newy: integer): Boolean;
function  GetNextDirection (sx, sy, dx, dy: Integer): byte;
function  GetNextDirectionNew (sx, sy, dx, dy: Integer): byte; //sonmg수정(2004/06/23)
function  GetHpMpRate (cret: TCreature): word;
function  IsTakeOnAvailable (useindex: integer; pstd: PTStdItem): Boolean;
function  IsDCItem (uindex: integer): Boolean;
function  IsUpgradeWeaponStuff (uindex: integer): Boolean;
function  GetMakeItemCondition (itemname: string; var iPrice: Integer): TStringList;
function  GetTurnDir (dir, rotatecount: integer): byte;
function  IsCheapStuff (stdmode: integer): Boolean;
function  GetGoldStr (gold: integer): string;   // 돈에 콤마 붙이는 함수.
function  GetStrGoldStr (strgold: string): string;   // 돈에 콤마 붙이는 함수.


implementation

uses
   svMain;


{function  GetBonusPoint (job, lv: integer): integer;
begin
   case job of
      0:                                    //전사
         if lv >= ADJ_LEVEL+1 then
            Result := 5 + Round(lv * 1.2)  //1.3
         else Result := 0;
      1:                                    //술사
         if lv >= ADJ_LEVEL+1 then
            Result := 5 + Round(lv * 2)
         else Result := 0;
      else                                  //도사
         if lv >= ADJ_LEVEL+1 then
            Result := 5 + Round(lv * 2.2)
         else Result := 0;
   end;
end;}

function  GetBonusPoint (job, lv: integer): integer;
   function adjlowlv(lv: integer): integer;
   begin
      if lv <= 25 then
         Result := Round((26 - lv))
      else Result := 0;
   end;
begin
   Result := 0;
   case job of
      0: begin
         if lv >= ADJ_LEVEL+1 then
            Result := Round(20 + (lv div 10) * 5)
            //Result := Round(5 + adjlowlv(lv) + lv * 0.7)
         else Result := 0;
      end;
      1: begin
         if lv >= ADJ_LEVEL+1 then
            Result := Round(27 + (lv div 10) * 8)
            //Result := Round(8 + adjlowlv(lv) + lv * 1.2)
         else Result := 0;
      end;
      2: begin
         if lv >= ADJ_LEVEL+1 then
            Result := Round(28 + (lv div 10) * 9)
            //Result := Round(8 + adjlowlv(lv) + lv * 1.4)
         else Result := 0;
      end;
   end;
end;

function  GetLevelBonusSum (job, lv: integer): integer;
var
   i: integer;
begin
   Result := 0;
   for i:=2 to lv do
      Result := Result + GetBonusPoint(job, i);
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

function GetFrontPosition (cret: TCreature; var newx, newy: integer): Boolean;
var
   penv: TEnvirnoment;
begin
   penv := cret.PEnvir;
   newx := cret.CX;
   newy := cret.CY;
   case cret.Dir of
      DR_UP:      if newy > 0 then newy := newy-1;
      DR_DOWN:    if newy < penv.MapHeight-1 then newy := newy+1;
      DR_LEFT:    if newx > 0 then newx := newx-1;
      DR_RIGHT:   if newx < penv.MapWidth-1 then newx := newx+1;
      DR_UPLEFT:
         begin
            if (newx > 0) and (newy > 0) then begin
               newx := newx - 1;
               newy := newy - 1;
            end;
         end;
      DR_UPRIGHT:
         begin
            if (newx > 0) and (newy < penv.MapHeight-1) then begin
               newx := newx + 1;
               newy := newy - 1;
            end;
         end;
      DR_DOWNLEFT:
         begin
            if (newx < penv.MapWidth-1) and (newy > 0) then begin
               newx := newx - 1;
               newy := newy + 1;
            end;
         end;
      DR_DOWNRIGHT:
         begin
            if (newx < penv.MapWidth-1) and (newy < penv.MapHeight-1) then begin
               newx := newx + 1;
               newy := newy + 1;
            end;
         end;
   end;
   Result := TRUE;
end;


//dis: 얼마나 멀리 뒤로..
function GetBackPosition (cret: TCreature; var newx, newy: integer): Boolean;
var
   penv: TEnvirnoment;
begin
   penv := cret.PEnvir;
   newx := cret.CX;
   newy := cret.CY;
   case cret.Dir of
      DR_UP:      if newy < penv.MapHeight-1 then newy := newy+1;
      DR_DOWN:    if newy > 0 then newy := newy-1;
      DR_LEFT:    if newx < penv.MapWidth-1 then newx := newx+1;
      DR_RIGHT:   if newx > 0 then newx := newx-1;
      DR_UPLEFT:
         begin
            if (newx < penv.MapWidth-1) and (newy < penv.MapHeight-1) then begin
               newx := newx + 1;
               newy := newy + 1;
            end;
         end;
      DR_UPRIGHT:
         begin
            if (newx < penv.MapWidth-1) and (newy > 0) then begin
               newx := newx - 1;
               newy := newy + 1;
            end;
         end;
      DR_DOWNLEFT:
         begin
            if (newx > 0) and (newy < penv.MapHeight-1) then begin
               newx := newx + 1;
               newy := newy - 1;
            end;
         end;
      DR_DOWNRIGHT:
         begin
            if (newx > 0) and (newy > 0) then begin
               newx := newx - 1;
               newy := newy - 1;
            end;
         end;
   end;
   Result := TRUE;
end;

//dis: 얼마나 멀리 뒤로..
function GetNextPosition (penv: TEnvirnoment; sx, sy, dir, dis: integer; var newx, newy: integer): Boolean;
begin
   newx := sx;
   newy := sy;
   case dir of
      DR_UP:      if newy > (dis-1) then newy := newy-dis;
      DR_DOWN:    if newy < penv.MapHeight-dis then newy := newy+dis;
      DR_LEFT:    if newx > (dis-1) then newx := newx-dis;
      DR_RIGHT:   if newx < penv.MapWidth-dis then newx := newx+dis;
      DR_UPLEFT:
         begin
            if (newx > dis-1) and (newy > dis-1) then begin
               newx := newx - dis;
               newy := newy - dis;
            end;
         end;
      DR_UPRIGHT:
         begin
            if (newx > dis-1) and (newy < penv.MapHeight-dis) then begin
               newx := newx + dis;
               newy := newy - dis;
            end;
         end;
      DR_DOWNLEFT:
         begin
            if (newx < penv.MapWidth-dis) and (newy > dis-1) then begin
               newx := newx - dis;
               newy := newy + dis;
            end;
         end;
      DR_DOWNRIGHT:
         begin
            if (newx < penv.MapWidth-dis) and (newy < penv.MapHeight-dis) then begin
               newx := newx + dis;
               newy := newy + dis;
            end;
         end;
   end;
   if (sx = newx) and (sy = newy) then Result := FALSE
   else Result := TRUE;
end;

function GetNextDirection (sx, sy, dx, dy: Integer): byte;
var
   flagx, flagy: integer;
begin
   Result := DR_DOWN;
   if sx < dx then flagx := 1
   else if sx = dx then flagx := 0
   else flagx := -1;
   if abs(sy-dy) > 2 then
      if (sx >= dx-1) and (sx <= dx+1) then flagx := 0;

   if sy < dy then flagy := 1
   else if sy = dy then flagy := 0
   else flagy := -1;
   if abs(sx-dx) > 2 then
      if (sy > dy-1) and (sy <= dy+1) then flagy := 0;

   if (flagx = 0)  and (flagy = -1) then Result := DR_UP;
   if (flagx = 1)  and (flagy = -1) then Result := DR_UPRIGHT;
   if (flagx = 1)  and (flagy = 0)  then Result := DR_RIGHT;
   if (flagx = 1)  and (flagy = 1)  then Result := DR_DOWNRIGHT;
   if (flagx = 0)  and (flagy = 1)  then Result := DR_DOWN;
   if (flagx = -1) and (flagy = 1)  then Result := DR_DOWNLEFT;
   if (flagx = -1) and (flagy = 0)  then Result := DR_LEFT;
   if (flagx = -1) and (flagy = -1) then Result := DR_UPLEFT;
end;

function GetNextDirectionNew (sx, sy, dx, dy: Integer): byte;
var
   flagx, flagy: integer;
begin
   Result := DR_DOWN;
   if sx < dx then flagx := 1
   else if sx = dx then flagx := 0
   else flagx := -1;
   if abs(sy-dy) > 2 then begin
      if (sx >= dx-1) and (sx <= dx+1) then
         flagx := 0;
   end;

   if sy < dy then flagy := 1
   else if sy = dy then flagy := 0
   else flagy := -1;
   if abs(sx-dx) > 2 then begin
      if (sy >= dy-1) and (sy <= dy+1) then
         flagy := 0;
   end;

   if (flagx = 0)  and (flagy = -1) then Result := DR_UP;
   if (flagx = 1)  and (flagy = -1) then Result := DR_UPRIGHT;
   if (flagx = 1)  and (flagy = 0)  then Result := DR_RIGHT;
   if (flagx = 1)  and (flagy = 1)  then Result := DR_DOWNRIGHT;
   if (flagx = 0)  and (flagy = 1)  then Result := DR_DOWN;
   if (flagx = -1) and (flagy = 1)  then Result := DR_DOWNLEFT;
   if (flagx = -1) and (flagy = 0)  then Result := DR_LEFT;
   if (flagx = -1) and (flagy = -1) then Result := DR_UPLEFT;
end;

function GetHpMpRate (cret: TCreature): word;
var
   hrate, srate: byte;
begin
   if (cret.Abil.MaxHP <> 0) and (cret.Abil.MaxMP <> 0) then begin
      Result := MakeWord (Round (cret.Abil.HP / cret.Abil.MaxHP * 100),
                          Round (cret.Abil.MP / cret.Abil.MaxMP * 100));
   end else begin
      if (cret.Abil.MaxHP = 0) then hrate := 0
      else hrate := Round (cret.Abil.HP / cret.Abil.MaxHP * 100);
      if (cret.Abil.MaxMP = 0) then srate := 0
      else srate := Round (cret.Abil.MP / cret.Abil.MaxMP * 100);
      Result := MakeWord (hrate, srate);
   end;
end;

function  IsTakeOnAvailable (useindex: integer; pstd: PTStdItem): Boolean;
begin
   Result := FALSE;
   if pstd = nil then exit;
   case useindex of
      U_DRESS:
         if pstd.StdMode in [10..11] then //남자 여자옷..
            Result := TRUE;
      U_WEAPON:
         if (pstd.StdMode = 5) or (pstd.StdMode = 6) then
            Result := TRUE;
      U_RIGHTHAND:
         if pstd.StdMode = 30 then begin //촛불, 파론램프
            Result := TRUE;
         end;
      U_NECKLACE:
         if (pstd.StdMode = 19) or (pstd.StdMode = 20) or (pstd.StdMode = 21) then begin
            Result := TRUE;
         end;
      U_HELMET:
         if pstd.StdMode = 15 then begin
            Result := TRUE;
         end;
      U_RINGL,
      U_RINGR:
         if (pstd.StdMode = 22) or (pstd.StdMode = 23) then begin
            Result := TRUE;
         end;
      U_ARMRINGR:    //팔찌만..
         if (pstd.StdMode = 24) or (pstd.StdMode = 26) then begin
            Result := TRUE;
         end;
      U_ARMRINGL:    //팔찌, 부적/독가루..
         if (pstd.StdMode = 24) or (pstd.StdMode = 25) or (pstd.StdMode = 26) then begin
            Result := TRUE;
         end;
      // 2003/03/15 아이템 인벤토리 확장
      U_BUJUK:
         if (pstd.StdMode = 25) then begin
            Result := TRUE;
         end;
      U_BELT:
         if (pstd.StdMode = 54) then begin
            Result := TRUE;
         end;
      U_BOOTS:
         if (pstd.StdMode = 52) then begin
            Result := TRUE;
         end;
      U_CHARM:
         if (pstd.StdMode = 53) then begin
            Result := TRUE;
         end;
   end;
end;

function  IsDCItem (uindex: integer): Boolean;
var
   pstd: PTStdItem;
begin
   pstd := UserEngine.GetStdItem (uindex);
   if pstd.StdMode in [5, 6, 10, 11, 15, 19, 20, 21, 22, 23, 24, 26,52,53,54] then
      Result := TRUE
   else
      Result := FALSE;
end;

function  IsUpgradeWeaponStuff (uindex: integer): Boolean;
var
   pstd: PTStdItem;
begin
   pstd := UserEngine.GetStdItem (uindex);
   if pstd.StdMode in [19, 20, 21, 22, 23, 24, 26{,52,53,54 sonmg}] then
      Result := TRUE
   else
      Result := FALSE;
end;

function  GetMakeItemCondition (itemname: string; var iPrice: Integer): TStringList;
var
   i: integer;
   sMakeItemName: string;
   sMakeItemPrice: string;
begin
   Result := nil;
   for i:=0 to MakeItemList.Count-1 do begin
      // RightStr := GetValidStr3 (OrgStr, LeftStr of Separator, Separator);
      sMakeItemPrice := GetValidStr3(MakeItemList[i], sMakeItemName, [':']);
      if sMakeItemName = itemname then begin
         Result := TStringList (MakeItemList.Objects[i]);
         iPrice := Str_ToInt(sMakeItemPrice, 0);
         break;
      end;
   end;
end;


function  GetTurnDir (dir, rotatecount: integer): byte;
begin
   Result := (dir + rotatecount) mod 8;
end;

function  IsCheapStuff (stdmode: integer): Boolean;
begin
   if stdmode in [0..2] then Result := TRUE
   else Result := FALSE;
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

function  GetStrGoldStr (strgold: string): string;
var
   i, n: integer;
//   str: string;
begin
//   str := IntToStr (gold);
   n := 0;
   Result := '';
   for i:=Length(strgold) downto 1 do begin
      if n = 3 then begin
         Result := strgold[i] + ',' + Result;
         n := 1;
      end else begin
         Result := strgold[i] + Result;
         Inc(n);
      end;
   end;
end;


end.
