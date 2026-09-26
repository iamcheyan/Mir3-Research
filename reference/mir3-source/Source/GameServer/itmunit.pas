unit itmunit;

interface

uses
  Windows, Messages, SysUtils, Classes, Graphics, Controls, Dialogs,
  ScktComp, syncobjs, MudUtil, HUtil32, Grobal2, Math;

type
   TItemUnit = class
   private
   public
      function  GetUpgrade (count, ran: integer): integer;
      function  GetUpgrade2 (x, a: integer): integer;
      procedure UpgradeRandomWeapon (pu: PTUserItem); //무기를 랜덤하게 업그레이드 한다.
      procedure UpgradeRandomDress (pu: PTUserItem);  //옷을 랜덤하게 업그레이드함.
      procedure UpgradeRandomNecklace (pu: PTUserItem);
      procedure UpgradeRandomBarcelet (pu: PTUserItem);
      procedure UpgradeRandomNecklace19 (pu: PTUserItem);
      procedure UpgradeRandomRings (pu: PTUserItem);
      procedure UpgradeRandomRings23 (pu: PTUserItem);
      procedure UpgradeRandomHelmet (pu: PTUserItem);

      procedure RandomSetUnknownHelmet (pu: PTUserItem);
      procedure RandomSetUnknownRing (pu: PTUserItem);
      procedure RandomSetUnknownBracelet (pu: PTUserItem);

      function GetUpgradeStdItem (ui: TUserItem; var std: TStdItem):integer;

      //공속 변환 함수
      function RealAttackSpeed( wAtkSpd: WORD ): integer;   //-10~15의 값을 갖는 실제 공속
      function NaturalAttackSpeed( iAtkSpd: integer ): WORD;   //0 이상의 값을 갖는 공속값
      function GetAttackSpeed( bStdAtkSpd, bUserAtkSpd: BYTE ): BYTE;
      function UpgradeAttackSpeed( bUserAtkSpd: BYTE; iUpValue: integer ): BYTE;

   end;

implementation

uses
   svMain;


function  TItemUnit.GetUpgrade (count, ran: integer): integer;
var
   i: integer;
begin
   Result := 0;
   for i:=0 to count-1 do begin
      if Random(ran) = 0 then Result := Result + 1
      else break;
   end;
end;

function  TItemUnit.GetUpgrade2 (x, a: integer): integer;
var
   i: integer;
   iProb : integer;
begin
   Result := 0;
//   Result := Trunc(Sqrt(10000 - Power(x+a, 2)) / (100 + Power(x, 2)));
//   iProb := Trunc((Sqrt(10000 - Power(x+a, 2)) / (100 + Power(x, 2))) * 100);
   for i:=x downto 1 do begin
      if i > x div 2 then begin
         //확률이 낮은 거 적용
         iProb := Trunc((Sqrt(Power(a, 2) - Power(i, 2)) / (a * i + Power(i, 2))) * 100);
      end else begin
         //확률이 높은 거 적용
         iProb := Trunc( (Sqrt(1 - (Power(i, 2) / Power(a, 2))) * 100) / sqrt(i) );
      end;
        if Random(100) < iProb then begin
         Result := i{x} div 3;
         break;
      end;
   end;

{
   Result := 0;
//   Result := Trunc(Sqrt(10000 - Power(x+a, 2)) / (100 + Power(x, 2)));
//   iProb := Trunc((Sqrt(10000 - Power(x+a, 2)) / (100 + Power(x, 2))) * 100);
   for i:=x downto 1 do begin
      iProb := Trunc((Sqrt(Power(a, 2) - Power(x, 2)) / (a * x + Power(x, 2))) * 100);
      if Random(100) < iProb then begin
//         Result := x div 3;
         Result := i div 3;
         break;
      end;
   end;
}
end;

//파라메터 pu는 반드시 무기이다.
//TUserItem의 Desc의 업그레이드 맵 0:DC 1:MC 2:SC
procedure TItemUnit.UpgradeRandomWeapon (pu: PTUserItem);
var
   up, n, i, incp: integer;
begin
   //파괴 옵션
   up := GetUpgrade (12, 15);
   if Random(15) = 0 then pu.Desc[0] := 1+up; //DC

   //공격속도
   up := GetUpgrade (12, 15);
   if Random(20) = 0 then begin  //공격 속도
      incp := (1+up) div 3;  //잘 안 붙도록
      if incp > 0 then begin
         if Random(3) <> 0 then  pu.Desc[6] := incp  //공격속도 (-)
         else pu.Desc[6] := 10 + incp;  //공격속도 (+)
      end;
   end;

   //마력
   up := GetUpgrade (12, 15);
   if Random(15) = 0 then pu.Desc[1] := 1+up; //MC

   //도력
   up := GetUpgrade (12, 15);
   if Random(15) = 0 then pu.Desc[2] := 1+up; //SC

   //정확
   up := GetUpgrade (12, 15);
   if Random(24) = 0 then pu.Desc[5] := 1 + (up div 2); //정확(+)

   //내구
   up := GetUpgrade (12, 12);
   if Random(3) < 2 then begin
      n := (1+up)*2000;
      pu.DuraMax := _MIN(65000, integer(pu.DuraMax) + n);
      pu.Dura := _MIN(65000, integer(pu.Dura) + n);
   end;

   //강도
   up := GetUpgrade (12, 15);
   if Random(10) = 0 then
      pu.Desc[7] := 1 + (up div 2); //무기의 단단함 정도

end;

procedure TItemUnit.UpgradeRandomDress (pu: PTUserItem);
var
   i, n, up: integer;
begin
   //방어
   up := GetUpgrade (6, 15);
   if Random(30) = 0 then pu.Desc[0] := 1+up; //AC

   //마항
   up := GetUpgrade (6, 15);
   if Random(30) = 0 then pu.Desc[1] := 1+up; //MAC

   //파괴
   up := GetUpgrade (6, 20);
   if Random(40) = 0 then pu.Desc[2] := 1+up; //DC

   //마법
   up := GetUpgrade (6, 20);
   if Random(40) = 0 then pu.Desc[3] := 1+up; //MC

   //도력
   up := GetUpgrade (6, 20);
   if Random(40) = 0 then pu.Desc[4] := 1+up; //SC

   //내구
   up := GetUpgrade (6, 10);
   if Random(8) < 6 then begin
      n := (1+up)*2000;
      pu.DuraMax := _MIN(65000, integer(pu.DuraMax) + n);
      pu.Dura := _MIN(65000, integer(pu.Dura) + n);
   end;
end;


procedure TItemUnit.UpgradeRandomNecklace (pu: PTUserItem);
var
   i, n, up: integer;
begin
   //정확
   up := GetUpgrade (6, 30);
   if Random(60) = 0 then pu.Desc[0] := 1+up; //AC(HIT)

   //민첩
   up := GetUpgrade (6, 30);
   if Random(60) = 0 then pu.Desc[1] := 1+up; //MAC(SPEED)

   //파괴
   up := GetUpgrade (6, 20);
   if Random(30) = 0 then pu.Desc[2] := 1+up; //DC

   //마법
   up := GetUpgrade (6, 20);
   if Random(30) = 0 then pu.Desc[3] := 1+up; //MC

   //도력
   up := GetUpgrade (6, 20);
   if Random(30) = 0 then pu.Desc[4] := 1+up; //SC

   //내구
   up := GetUpgrade (6, 12);
   if Random(20) < 15 then begin  //내구
      n := (1+up)*1000;
      pu.DuraMax := _MIN(65000, integer(pu.DuraMax) + n);
      pu.Dura := _MIN(65000, integer(pu.Dura) + n);
   end;
end;

procedure TItemUnit.UpgradeRandomBarcelet (pu: PTUserItem);
var
   i, n, up: integer;
begin
   //방어
   up := GetUpgrade (6, 20);
   if Random(20) = 0 then pu.Desc[0] := 1+up; //AC

   //마항
   up := GetUpgrade (6, 20);
   if Random(20) = 0 then pu.Desc[1] := 1+up; //MAC

   //파괴
   up := GetUpgrade (6, 20);
   if Random(30) = 0 then pu.Desc[2] := 1+up; //DC

   //마법
   up := GetUpgrade (6, 20);
   if Random(30) = 0 then pu.Desc[3] := 1+up; //MC

   //도력
   up := GetUpgrade (6, 20);
   if Random(30) = 0 then pu.Desc[4] := 1+up; //SC

   //내구
   up := GetUpgrade (6, 12);
   if Random(20) < 15 then begin  //내구
      n := (1+up)*1000;
      pu.DuraMax := _MIN(65000, integer(pu.DuraMax) + n);
      pu.Dura := _MIN(65000, integer(pu.Dura) + n);
   end;
end;

procedure TItemUnit.UpgradeRandomNecklace19 (pu: PTUserItem);
var
   i, n, up: integer;
begin
   //마법회피
   up := GetUpgrade (6, 20);
   if Random(40) = 0 then pu.Desc[0] := 1+up; //마법회피

   //행운
   up := GetUpgrade (6, 20);
   if Random(40) = 0 then pu.Desc[1] := 1+up; //행운

   //파괴
   up := GetUpgrade (6, 20);
   if Random(30) = 0 then pu.Desc[2] := 1+up; //DC

   //마법
   up := GetUpgrade (6, 20);
   if Random(30) = 0 then pu.Desc[3] := 1+up; //MC

   //도력
   up := GetUpgrade (6, 20);
   if Random(30) = 0 then pu.Desc[4] := 1+up; //SC

   //내구
   up := GetUpgrade (6, 10);
   if Random(4) < 3 then begin //내구성 업그레이드
      n := (1+up)*1000;
      pu.DuraMax := _MIN(65000, integer(pu.DuraMax) + n);
      pu.Dura := _MIN(65000, integer(pu.Dura) + n);
   end;
end;

procedure TItemUnit.UpgradeRandomRings (pu: PTUserItem);
var
   i, n, up: integer;
begin
   //파괴
   up := GetUpgrade (6, 20);
   if Random(30) = 0 then pu.Desc[2] := 1+up; //DC

   //마력
   up := GetUpgrade (6, 20);
   if Random(30) = 0 then pu.Desc[3] := 1+up; //MC

   //도력
   up := GetUpgrade (6, 20);
   if Random(30) = 0 then pu.Desc[4] := 1+up; //SC

   //내구
   up := GetUpgrade (6, 12);
   if Random(4) < 3 then begin //내구성 업그레이드
      n := (1+up)*1000;
      pu.DuraMax := _MIN(65000, integer(pu.DuraMax) + n);
      pu.Dura := _MIN(65000, integer(pu.Dura) + n);
   end;
end;

procedure TItemUnit.UpgradeRandomRings23 (pu: PTUserItem);
var
   i, n, up: integer;
begin
   //중독저항
   up := GetUpgrade (6, 20);
   if Random(40) = 0 then pu.Desc[0] := 1+up; //중독저항

   //중독회복
   up := GetUpgrade (6, 20);
   if Random(40) = 0 then pu.Desc[1] := 1+up; //중독회복

   //파괴
   up := GetUpgrade (6, 20);
   if Random(30) = 0 then pu.Desc[2] := 1+up; //DC

   //마력
   up := GetUpgrade (6, 20);
   if Random(30) = 0 then pu.Desc[3] := 1+up; //MC

   //도력
   up := GetUpgrade (6, 20);
   if Random(30) = 0 then pu.Desc[4] := 1+up; //SC

   //내구
   up := GetUpgrade (6, 12);
   if Random(4) < 3 then begin
      n := (1+up)*1000;
      pu.DuraMax := _MIN(65000, integer(pu.DuraMax) + n);
      pu.Dura := _MIN(65000, integer(pu.Dura) + n);
   end;
end;

procedure TItemUnit.UpgradeRandomHelmet (pu: PTUserItem);
var
   i, n, up: integer;
begin
   //방어
   up := GetUpgrade (6, 20);
   if Random(40) = 0 then pu.Desc[0] := 1+up; //AC

   //마항
   up := GetUpgrade (6, 20);
   if Random(30) = 0 then pu.Desc[1] := 1+up; //MAC

   //파괴
   up := GetUpgrade (6, 20);
   if Random(30) = 0 then pu.Desc[2] := 1+up; //DC

   //마법
   up := GetUpgrade (6, 20);
   if Random(30) = 0 then pu.Desc[3] := 1+up; //MC

   //도력
   up := GetUpgrade (6, 20);
   if Random(30) = 0 then pu.Desc[4] := 1+up; //SC

   //내구
   up := GetUpgrade (6, 12);
   if Random(4) < 3 then begin
      n := (1+up)*1000;
      pu.DuraMax := _MIN(65000, integer(pu.DuraMax) + n);
      pu.Dura := _MIN(65000, integer(pu.Dura) + n);
   end;
end;

//-------------------------------------------------------------
// 미지의 아이템 (투구)

//투구
procedure TItemUnit.RandomSetUnknownHelmet (pu: PTUserItem);
var
   i, n, up, sum: integer;
begin
   //방어
//   up := GetUpgrade (4, 3) + GetUpgrade (4, 8) + GetUpgrade (4, 20);
   up := GetUpgrade2 (12, 13) + GetUpgrade2 (9, 10);
   if up > 0 then pu.Desc[0] := up; //AC
   sum := up;

   //마항
//   up := GetUpgrade (4, 3) + GetUpgrade (4, 8) + GetUpgrade (4, 20);
   up := GetUpgrade2 (9, 10);
   if up > 0 then pu.Desc[1] := up; //MAC
   sum := sum + up;

   //파괴
//   up := GetUpgrade (3, 15) + GetUpgrade (3, 30);
   up := GetUpgrade2 (6, 7);
   if up > 0 then pu.Desc[2] := up; //DC
   sum := sum + up;

   //마법
//   up := GetUpgrade (3, 15) + GetUpgrade (3, 30);
   up := GetUpgrade2 (6, 7);
   if up > 0 then pu.Desc[3] := up; //MC
   sum := sum + up;

   //도력
//   up := GetUpgrade (3, 15) + GetUpgrade (3, 30);
   up := GetUpgrade2 (6, 7);
   if up > 0 then pu.Desc[4] := up; //SC
   sum := sum + up;

   //내구
   up := GetUpgrade (6, 30);
   if up > 0 then begin
      n := (1+up)*1000;
      pu.DuraMax := _MIN(65000, integer(pu.DuraMax) + n);
      pu.Dura := _MIN(65000, integer(pu.Dura) + n);
   end;

   //떨어지지 않는 아이템
   if Random(30) = 0 then
      pu.Desc[7] := 1;  //떨어지지 않는 속성
   pu.Desc[8] := 1;  //미지의 속성

   //착용 필요치가 붙음
   if sum >= 3 then begin
      if (pu.Desc[0] >= 5) then begin //방어가 큼
         pu.Desc[5] := 1; //필파
         pu.Desc[6] := 25 + pu.Desc[0] * 3;
         exit;
      end;
      if (pu.Desc[2] >= 2) then begin //파괴가 큼
         pu.Desc[5] := 1; //필파
         pu.Desc[6] := 35 + pu.Desc[2] * 4;
         exit;
      end;
      if (pu.Desc[3] >= 2) then begin //마력 큼
         pu.Desc[5] := 2; //필마
         pu.Desc[6] := 18 + pu.Desc[3] * 2;
         exit;
      end;
      if (pu.Desc[4] >= 2) then begin //도력 큼
         pu.Desc[5] := 3; //필도
         pu.Desc[6] := 18 + pu.Desc[4] * 2;
         exit;
      end;
      pu.Desc[6] := 18 + sum * 2;
   end;
end;

//미지의 아이템 (반지)

procedure TItemUnit.RandomSetUnknownRing (pu: PTUserItem);
var
   i, n, up, sum: integer;
begin
   //파괴
//   up := GetUpgrade (3, 4) + GetUpgrade (3, 8) + GetUpgrade (6, 20);
   up := GetUpgrade2 (12, 13) + GetUpgrade2 (12, 13);
   if up > 0 then pu.Desc[2] := up; //DC
   sum := up;

   //마력
//   up := GetUpgrade (3, 4) + GetUpgrade (3, 8) + GetUpgrade (6, 20);
   up := GetUpgrade2 (12, 13) + GetUpgrade2 (12, 13);
   if up > 0 then pu.Desc[3] := up; //MC
   sum := sum + up;

   //도력
//   up := GetUpgrade (3, 4) + GetUpgrade (3, 8) + GetUpgrade (6, 20);
   up := GetUpgrade2 (12, 13) + GetUpgrade2 (9, 10);
   if up > 0 then pu.Desc[4] := up; //SC
   sum := sum + up;

   //내구
   up := GetUpgrade (6, 30);
   if up > 0 then begin //내구성 업그레이드
      n := (1+up)*1000;
      pu.DuraMax := _MIN(65000, integer(pu.DuraMax) + n);
      pu.Dura := _MIN(65000, integer(pu.Dura) + n);
   end;

   //떨어지지 않는 아이템
   if Random(30) = 0 then
      pu.Desc[7] := 1;  //떨어지지 않는 속성
   pu.Desc[8] := 1;  //미지의 속성

   //착용 필요치가 붙음
   if sum >= 3 then begin
      if (pu.Desc[2] >= 3) then begin //파괴가 큼
         pu.Desc[5] := 1; //필파
         pu.Desc[6] := 25 + pu.Desc[2] * 3;
         exit;
      end;
      if (pu.Desc[3] >= 3) then begin //마력가 큼
         pu.Desc[5] := 2; //필마
         pu.Desc[6] := 18 + pu.Desc[3] * 2;
         exit;
      end;
      if (pu.Desc[4] >= 3) then begin //도력가 큼
         pu.Desc[5] := 3; //필도
         pu.Desc[6] := 18 + pu.Desc[4] * 2;
         exit;
      end;
      pu.Desc[6] := 18 + sum * 2;
   end;
end;

//미지의 아이템 팔찌

procedure TItemUnit.RandomSetUnknownBracelet (pu: PTUserItem);
var
   i, n, up, sum: integer;
begin
   //방어
//   up := GetUpgrade (3, 5) + GetUpgrade (5, 20);
   up := GetUpgrade2 (12, 13);
   if up > 0 then pu.Desc[0] := up; //AC
   sum := up;

   //마항
//   up := GetUpgrade (3, 5) + GetUpgrade (5, 20);
   up := GetUpgrade2 (9, 10);
   if up > 0 then pu.Desc[1] := up; //MAC
   sum := sum + up;

   //파괴
//   up := GetUpgrade (3, 15) + GetUpgrade (5, 30);
   up := GetUpgrade2 (6, 7) + GetUpgrade2 (6, 7);
   if up > 0 then pu.Desc[2] := up; //DC
   sum := sum + up;

   //마법
//   up := GetUpgrade (3, 15) + GetUpgrade (5, 30);
   up := GetUpgrade2 (6, 7) + GetUpgrade2 (6, 7);
   if up > 0 then pu.Desc[3] := up; //MC
   sum := sum + up;

   //도력
//   up := GetUpgrade (3, 15) + GetUpgrade (5, 30);
   up := GetUpgrade2 (6, 7) + GetUpgrade2 (6, 7);
   if up > 0 then pu.Desc[4] := up; //SC
   sum := sum + up;

   //내구
   up := GetUpgrade (6, 30);
   if up > 0 then begin  //내구
      n := (1+up)*1000;
      pu.DuraMax := _MIN(65000, integer(pu.DuraMax) + n);
      pu.Dura := _MIN(65000, integer(pu.Dura) + n);
   end;

   //떨어지지 않는 아이템
   if Random(30) = 0 then
      pu.Desc[7] := 1;  //떨어지지 않는 속성
   pu.Desc[8] := 1;  //미지의 속성

   //착용 필요치가 붙음
   if sum >= 2 then begin
      if (pu.Desc[0] >= 3) then begin //방어가 큼
         pu.Desc[5] := 1; //필파
         pu.Desc[6] := 25 + pu.Desc[0] * 3;
         exit;
      end;
      if (pu.Desc[2] >= 2) then begin //파괴가 큼
         pu.Desc[5] := 1; //필파
         pu.Desc[6] := 30 + pu.Desc[2] * 3;
         exit;
      end;
      if (pu.Desc[3] >= 2) then begin //마력가 큼
         pu.Desc[5] := 2; //필마
         pu.Desc[6] := 20 + pu.Desc[3] * 2;
         exit;
      end;
      if (pu.Desc[4] >= 2) then begin //도력가 큼
         pu.Desc[5] := 3; //필도
         pu.Desc[6] := 20 + pu.Desc[4] * 2;
         exit;
      end;
      pu.Desc[6] := 18 + sum * 2;
   end;
end;


//업그래이된 값을 적용한 stditem값을 리턴
//std + pu = std
function TItemUnit.GetUpgradeStdItem (ui: TUserItem; var std: TStdItem) : integer;
var
   UCount  : integer;
begin
   UCount := 0;
   case std.StdMode of
      5,6: //무기
      begin
         std.DC := MakeWord (Lobyte(std.DC), _MIN(255, Hibyte(std.DC) + ui.Desc[0]));
         std.MC := MakeWord (Lobyte(std.MC), _MIN(255, Hibyte(std.MC) + ui.Desc[1]));
         std.SC := MakeWord (Lobyte(std.SC), _MIN(255, Hibyte(std.SC) + ui.Desc[2]));
         //3:행운, 4:저주, 5:정확, 6:공격속도
         std.AC := MakeWord (Lobyte(std.AC) + ui.Desc[3], Hibyte(std.AC) + ui.Desc[5]);  //행운, 정확
         std.MAC:= MakeWord (Lobyte(std.MAC) + ui.Desc[4], Hibyte(std.MAC));  //저주

         //공속값을 얻어옴.
         std.MAC:= MAKEWORD( LOBYTE(std.MAC), GetAttackSpeed( HIBYTE(std.MAC), ui.Desc[6] ) );

{
         //공속이 10보다 작을 때를 위한 처리.
         if HiByte(std.MAC) > 10 then begin
            std.Mac:= MakeWord (Lobyte(std.MAC), Hibyte(std.MAC) + ui.Desc[6]);  //공격속도(-/+)
         end else begin
            if Hibyte(std.MAC) >= ui.Desc[6] then
               std.Mac:= MakeWord (Lobyte(std.MAC), ABS( ui.Desc[6] - Hibyte(std.MAC) ))  //공격속도(-/+)
            else
               std.Mac:= MakeWord (Lobyte(std.MAC), ABS( ui.Desc[6] - Hibyte(std.MAC) ) + 10);  //공격속도(-/+)
         end;
}

         if ui.Desc[7] in [1..10] then begin
            // 신성이 붙어 있으면 강도를 보여주지 않는다(sonmg 2005/02/16)
            if std.SpecialPwr >= 0 then
               std.SpecialPwr := ui.Desc[7]; //무기의 강도를 나타냄
         end;
         if ui.Desc[10] <> 0 then
            std.ItemDesc := std.ItemDesc or IDC_UNIDENTIFIED;//$01;

         std.Slowdown := std.Slowdown + ui.Desc[12];
         std.Tox := std.Tox + ui.Desc[13];

         if ui.Desc[0] > 0 then inc ( UCount );
         if ui.Desc[1] > 0 then inc ( UCount );
         if ui.Desc[2] > 0 then inc ( UCount );
         if ui.Desc[3] > 0 then inc ( UCount );
         if ui.Desc[4] > 0 then inc ( UCount );
         if ui.Desc[5] > 0 then inc ( UCount );
         if ui.Desc[6] > 0 then inc ( UCount );
         if ui.Desc[7] > 0 then inc ( UCount );
         if ui.Desc[12] > 0 then inc ( UCount );
         if ui.Desc[13] > 0 then inc ( UCount );


      end;
      10,11: //옷
      begin
         std.AC  := MakeWord (Lobyte(std.AC), _MIN(255, Hibyte(std.AC) + ui.Desc[0]));
         std.MAC := MakeWord (Lobyte(std.MAC),_MIN(255, Hibyte(std.MAC)+ ui.Desc[1]));
         std.DC  := MakeWord (Lobyte(std.DC), _MIN(255, Hibyte(std.DC) + ui.Desc[2]));
         std.MC  := MakeWord (Lobyte(std.MC), _MIN(255, Hibyte(std.MC) + ui.Desc[3]));
         std.SC  := MakeWord (Lobyte(std.SC), _MIN(255, Hibyte(std.SC) + ui.Desc[4]));
         //added by sonmg
         std.Agility  := std.Agility + ui.Desc[11];
         std.MgAvoid := std.MgAvoid + ui.Desc[12];
         std.ToxAvoid := std.ToxAvoid + ui.Desc[13];

         if ui.Desc[0] > 0 then inc ( UCount );
         if ui.Desc[1] > 0 then inc ( UCount );
         if ui.Desc[2] > 0 then inc ( UCount );
         if ui.Desc[3] > 0 then inc ( UCount );
         if ui.Desc[4] > 0 then inc ( UCount );
         if ui.Desc[11] > 0 then inc ( UCount );
         if ui.Desc[12] > 0 then inc ( UCount );
         if ui.Desc[13] > 0 then inc ( UCount );

      end;
      15: //투구(added by sonmg)
      begin
         std.AC  := MakeWord (Lobyte(std.AC), _MIN(255, Hibyte(std.AC) + ui.Desc[0]));
         std.MAC := MakeWord (Lobyte(std.MAC),_MIN(255, Hibyte(std.MAC)+ ui.Desc[1]));
         std.DC  := MakeWord (Lobyte(std.DC), _MIN(255, Hibyte(std.DC) + ui.Desc[2]));
         std.MC  := MakeWord (Lobyte(std.MC), _MIN(255, Hibyte(std.MC) + ui.Desc[3]));
         std.SC  := MakeWord (Lobyte(std.SC), _MIN(255, Hibyte(std.SC) + ui.Desc[4]));
         //added by sonmg
         std.Accurate  := std.Accurate + ui.Desc[11];
         std.MgAvoid := std.MgAvoid + ui.Desc[12];
         std.ToxAvoid := std.ToxAvoid + ui.Desc[13];

         if ui.Desc[5] > 0 then  //필요(렙,파괴,마법,도력)
            std.Need := ui.Desc[5];
         if ui.Desc[6] > 0 then
            std.NeedLevel := ui.Desc[6];
         //if ui.Desc[7] > 0 then begin // : 떨어지지 않는 속성
         //   std.ItemDesc := std.ItemDesc or IDC_UNABLETAKEOFF;  //불필요
         //end;
         //if ui.Desc[8] > 0 then begin // : 미지의속성 아이템의 능력치가 보이지 않음
         //   std.ItemDesc := std.ItemDesc or IDC_UNIDENTIFIED;   //불필요
         //end;

         if ui.Desc[0] > 0 then inc ( UCount );
         if ui.Desc[1] > 0 then inc ( UCount );
         if ui.Desc[2] > 0 then inc ( UCount );
         if ui.Desc[3] > 0 then inc ( UCount );
         if ui.Desc[4] > 0 then inc ( UCount );
         if ui.Desc[11] > 0 then inc ( UCount );
         if ui.Desc[12] > 0 then inc ( UCount );
         if ui.Desc[13] > 0 then inc ( UCount );

      end;
      19,20,21: //목걸이
      begin
         std.AC  := MakeWord (Lobyte(std.AC), _MIN(255, Hibyte(std.AC) + ui.Desc[0]));
         std.MAC := MakeWord (Lobyte(std.MAC),_MIN(255, Hibyte(std.MAC)+ ui.Desc[1]));
         std.DC  := MakeWord (Lobyte(std.DC), _MIN(255, Hibyte(std.DC) + ui.Desc[2]));
         std.MC  := MakeWord (Lobyte(std.MC), _MIN(255, Hibyte(std.MC) + ui.Desc[3]));
         std.SC  := MakeWord (Lobyte(std.SC), _MIN(255, Hibyte(std.SC) + ui.Desc[4]));
         //added by sonmg
         std.AtkSpd  := std.AtkSpd + ui.Desc[9];
         std.Undead := std.Undead + ui.Desc[10];   //PAIN 시리즈
         std.Slowdown := std.Slowdown + ui.Desc[12];
         std.Tox := std.Tox + ui.Desc[13];

         if std.StdMode = 19 then
            std.Accurate := std.Accurate + ui.Desc[11]
         else if std.StdMode = 20 then
            std.MgAvoid := std.MgAvoid + ui.Desc[11]
         else if std.StdMode = 21 then begin
            std.Accurate := std.Accurate + ui.Desc[11];
            std.MgAvoid := std.MgAvoid + ui.Desc[7];  // 7번을 사용 안하나?(sonmg)
         end;

         if ui.Desc[5] > 0 then  //필요(렙,파괴,마법,도력)
            std.Need := ui.Desc[5];
         if ui.Desc[6] > 0 then
            std.NeedLevel := ui.Desc[6];
         //if ui.Desc[7] > 0 then begin // : 떨어지지 않는 속성
         //   std.ItemDesc := std.ItemDesc or IDC_UNABLETAKEOFF;  //불필요
         //end;
         //if ui.Desc[8] > 0 then begin // : 미지의속성 아이템의 능력치가 보이지 않음
         //   std.ItemDesc := std.ItemDesc or IDC_UNIDENTIFIED;   //불필요
         //end;

         if ui.Desc[0] > 0 then inc ( UCount );
         if ui.Desc[1] > 0 then inc ( UCount );
         if ui.Desc[2] > 0 then inc ( UCount );
         if ui.Desc[3] > 0 then inc ( UCount );
         if ui.Desc[4] > 0 then inc ( UCount );
         if ui.Desc[9] > 0 then inc ( UCount );
         if ui.Desc[11] > 0 then inc ( UCount );
         if ui.Desc[12] > 0 then inc ( UCount );
         if ui.Desc[13] > 0 then inc ( UCount );

      end;
      22,23: //반지
      begin
         std.AC  := MakeWord (Lobyte(std.AC), _MIN(255, Hibyte(std.AC) + ui.Desc[0]));
         std.MAC := MakeWord (Lobyte(std.MAC),_MIN(255, Hibyte(std.MAC)+ ui.Desc[1]));
         std.DC  := MakeWord (Lobyte(std.DC), _MIN(255, Hibyte(std.DC) + ui.Desc[2]));
         std.MC  := MakeWord (Lobyte(std.MC), _MIN(255, Hibyte(std.MC) + ui.Desc[3]));
         std.SC  := MakeWord (Lobyte(std.SC), _MIN(255, Hibyte(std.SC) + ui.Desc[4]));
         //added by sonmg
         std.AtkSpd  := std.AtkSpd + ui.Desc[9];
         std.Undead := std.Undead + ui.Desc[10];   //PAIN 시리즈
         std.Slowdown := std.Slowdown + ui.Desc[12];
         std.Tox := std.Tox + ui.Desc[13];

         if ui.Desc[5] > 0 then  //필요(렙,파괴,마법,도력)
            std.Need := ui.Desc[5];
         if ui.Desc[6] > 0 then
            std.NeedLevel := ui.Desc[6];
         //if ui.Desc[7] > 0 then begin // : 떨어지지 않는 속성
         //   std.ItemDesc := std.ItemDesc or IDC_UNABLETAKEOFF;  //불필요
         //end;
         //if ui.Desc[8] > 0 then begin // : 미지의속성 아이템의 능력치가 보이지 않음
         //   std.ItemDesc := std.ItemDesc or IDC_UNIDENTIFIED;   //불필요
         //end;

         if ui.Desc[0] > 0 then inc ( UCount );
         if ui.Desc[1] > 0 then inc ( UCount );
         if ui.Desc[2] > 0 then inc ( UCount );
         if ui.Desc[3] > 0 then inc ( UCount );
         if ui.Desc[4] > 0 then inc ( UCount );
         if ui.Desc[9] > 0 then inc ( UCount );
         if ui.Desc[12] > 0 then inc ( UCount );
         if ui.Desc[13] > 0 then inc ( UCount );

      end;
      24: //팔찌24
      begin
         std.AC  := MakeWord (Lobyte(std.AC), _MIN(255, Hibyte(std.AC) + ui.Desc[0]));
         std.MAC := MakeWord (Lobyte(std.MAC),_MIN(255, Hibyte(std.MAC)+ ui.Desc[1]));
         std.DC  := MakeWord (Lobyte(std.DC), _MIN(255, Hibyte(std.DC) + ui.Desc[2]));
         std.MC  := MakeWord (Lobyte(std.MC), _MIN(255, Hibyte(std.MC) + ui.Desc[3]));
         std.SC  := MakeWord (Lobyte(std.SC), _MIN(255, Hibyte(std.SC) + ui.Desc[4]));

         if ui.Desc[5] > 0 then  //필요(렙,파괴,마법,도력)
            std.Need := ui.Desc[5];
         if ui.Desc[6] > 0 then
            std.NeedLevel := ui.Desc[6];
         //if ui.Desc[7] > 0 then begin // : 떨어지지 않는 속성
         //   std.ItemDesc := std.ItemDesc or IDC_UNABLETAKEOFF;  //불필요
         //end;
         //if ui.Desc[8] > 0 then begin // : 미지의속성 아이템의 능력치가 보이지 않음
         //   std.ItemDesc := std.ItemDesc or IDC_UNIDENTIFIED;   //불필요
         //end;

         if ui.Desc[0] > 0 then inc ( UCount );
         if ui.Desc[1] > 0 then inc ( UCount );
         if ui.Desc[2] > 0 then inc ( UCount );
         if ui.Desc[3] > 0 then inc ( UCount );
         if ui.Desc[4] > 0 then inc ( UCount );

      end;
      26: //팔찌26
      begin
         std.AC  := MakeWord (Lobyte(std.AC), _MIN(255, Hibyte(std.AC) + ui.Desc[0]));
         std.MAC := MakeWord (Lobyte(std.MAC),_MIN(255, Hibyte(std.MAC)+ ui.Desc[1]));
         std.DC  := MakeWord (Lobyte(std.DC), _MIN(255, Hibyte(std.DC) + ui.Desc[2]));
         std.MC  := MakeWord (Lobyte(std.MC), _MIN(255, Hibyte(std.MC) + ui.Desc[3]));
         std.SC  := MakeWord (Lobyte(std.SC), _MIN(255, Hibyte(std.SC) + ui.Desc[4]));

         //added by sonmg
         std.Undead := std.Undead + ui.Desc[10];   //PAIN 시리즈
         std.Accurate  := std.Accurate + ui.Desc[11];
         std.Agility  := std.Agility + ui.Desc[12];

         if ui.Desc[5] > 0 then  //필요(렙,파괴,마법,도력)
            std.Need := ui.Desc[5];
         if ui.Desc[6] > 0 then
            std.NeedLevel := ui.Desc[6];
         //if ui.Desc[7] > 0 then begin // : 떨어지지 않는 속성
         //   std.ItemDesc := std.ItemDesc or IDC_UNABLETAKEOFF;  //불필요
         //end;
         //if ui.Desc[8] > 0 then begin // : 미지의속성 아이템의 능력치가 보이지 않음
         //   std.ItemDesc := std.ItemDesc or IDC_UNIDENTIFIED;   //불필요
         //end;

         if ui.Desc[0] > 0 then inc ( UCount );
         if ui.Desc[1] > 0 then inc ( UCount );
         if ui.Desc[2] > 0 then inc ( UCount );
         if ui.Desc[3] > 0 then inc ( UCount );
         if ui.Desc[4] > 0 then inc ( UCount );
         if ui.Desc[11] > 0 then inc ( UCount );
         if ui.Desc[12] > 0 then inc ( UCount );

      end;
      52: //신발(added by sonmg)
      begin
         std.AC  := MakeWord (Lobyte(std.AC), _MIN(255, Hibyte(std.AC) + ui.Desc[0]));
         std.MAC := MakeWord (Lobyte(std.MAC),_MIN(255, Hibyte(std.MAC)+ ui.Desc[1]));
         std.Agility := std.Agility + ui.Desc[3];

         if ui.Desc[0] > 0 then inc ( UCount );
         if ui.Desc[1] > 0 then inc ( UCount );
         if ui.Desc[3] > 0 then inc ( UCount );

      end;
      53: //수호석(added by sonmg 2006/01/17)
      begin
         std.Undead := std.Undead + ui.Desc[10];   //PAIN 시리즈
      end;
      54: //벨트(added by sonmg)
      begin
         std.AC  := MakeWord (Lobyte(std.AC), _MIN(255, Hibyte(std.AC) + ui.Desc[0]));
         std.MAC := MakeWord (Lobyte(std.MAC),_MIN(255, Hibyte(std.MAC)+ ui.Desc[1]));
         std.Accurate := std.Accurate + ui.Desc[2];
         std.Agility := std.Agility + ui.Desc[3];
         std.ToxAvoid := std.ToxAvoid + ui.Desc[13];

         if ui.Desc[0] > 0 then inc ( UCount );
         if ui.Desc[1] > 0 then inc ( UCount );
         if ui.Desc[2] > 0 then inc ( UCount );
         if ui.Desc[3] > 0 then inc ( UCount );
         if ui.Desc[13] > 0 then inc ( UCount );

      end;
   end;

   Result := UCount;
end;

// 양수 공속값을 실제 공속(-10~15)값으로 변환해주는 함수.
function TItemUnit.RealAttackSpeed( wAtkSpd: WORD ): integer;
begin
   if wAtkSpd <= 10 then
      Result := - wAtkSpd
   else
      Result := wAtkSpd - 10;
end;

// 실제 공속(-10~15)값을 양수 공속값으로 변환해주는 함수.
function TItemUnit.NaturalAttackSpeed( iAtkSpd: integer ): WORD;
begin
   if iAtkSpd <= 0 then
      Result := - iAtkSpd
   else
      Result := iAtkSpd + 10;
end;

// 리소스와 유저의 양수 공속값을 받아서 두 공속의 합을 양수 공속값으로 돌려주는 함수.
function TItemUnit.GetAttackSpeed( bStdAtkSpd, bUserAtkSpd: BYTE ): BYTE;
var
   iTemp: integer;
begin
   iTemp := RealAttackSpeed( bStdAtkSpd ) + RealAttackSpeed( bUserAtkSpd );

   Result := BYTE( NaturalAttackSpeed( iTemp ) );
end;

// 리소스와 유저의 양수 공속값을 받아서 업그레이드 값을 반영하여 리턴하는 함수.
// 리턴값 : 유저의 양수 공속값.
function TItemUnit.UpgradeAttackSpeed( bUserAtkSpd: BYTE; iUpValue: integer ): BYTE;
var
   iTemp: integer;
begin
   iTemp := RealAttackSpeed( bUserAtkSpd ) + iUpValue;

   Result := BYTE( NaturalAttackSpeed( iTemp ) );
end;


end.
