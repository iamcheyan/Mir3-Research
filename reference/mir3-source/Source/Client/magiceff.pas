unit magiceff;

interface

uses
  Windows, Messages, SysUtils, Classes, Graphics, Controls, Forms, Dialogs,
  Grobal2, HGETextures, CliUtil, ClFunc, HUtil32, WIl;


const
   MG_READY       = 10;
   MG_FLY         = 6;
   MG_EXPLOSION   = 10;
   READYTIME  = 120;
   EXPLOSIONTIME = 100;
   FLYBASE = 10;
   EXPLOSIONBASE = 170;
   //EFFECTFRAME = 260;
   MAXMAGIC = 10;
   FLYOMAAXEBASE = 447;
   THORNBASE = 2967;
   ARCHERBASE = 2607;
   ARCHERBASE2 = 272; //2609;

   FLYFORSEC = 500;
   FIREGUNFRAME = 6;

   // 2003/03/15 신규무공 추가
   MAXEFFECT = 49;
   EffectBase: array[0..MAXEFFECT-1] of integer = (
      0,             //0  화염장
      200,           //1  회복술
      400,           //2  금강화염장
      600,           //3  암연술
      0,             //4  검광
      900,           //5  화염풍
      920,           //6  화염방사
      940,           //7  뢰인장 //시전효과없음
      20,            //8  강격,  Magic2
      940,           //9  폭살계 //시전효과없음
      940,           //10 대지원호 //시전효과없음
      940,           //11 대지원호마 //시전효과없음
      0,             //12 어검술
      1380,          //13 결계
      1500,          //14 백골투자소환, 소환술
      1520,          //15 은신술
      940,           //16 대은신
      1560,          //17 전기충격
      1590,          //18 순간이동
      1620,          //19 지열장
      1650,          //20 화염폭발
      1680,          //21 대은하(전기퍼짐)
      0,             //22 반월검법
      0,             //23 염화결
      0,             //24 무태보
      3960,          //25 탐기파연
      1790,          //26 대회복술
      0,             //27 신수소환  Magic2
      3880,          //28 주술의막
      3920,          //29 사자윤회
      3840,          //30 빙설풍
      0,             //31 마법진
      40,            //32 광풍참     (Magic2)
      130,           //33 멸천화     (Magic2)
      160,           //34 무극진기   (Magic2)
      190,           //35 기공파     (Magic2)
      0,             //36 마법진2
      // 2003/07/15 신규무공
      210,           //37 쌍룡참     (Magic2)  //210
      400,           //38 결빙장     (Magic2)
      600,           //39 정화술     (Magic2)
      1500,          //40 정혼소환술 (Magic2)
      650,           //41 분신술     (Magic2)
      710,           //42 사자후     (Magic2)
      740,           //43 공파섬     (Magic2)
      900,           //44 화룡기염   (Magic2)
      940,           //45 저주술     (Magic2)
      990,           //46 포승검     (Magic2)
      1040,          //47 흡혈술     (Magic2)
      1100           //48 맹안술    ( Magic2)
   );
   MAXHITEFFECT = 8;
   HitEffectBase: array[0..MAXHITEFFECT-1] of integer = (
      1350,          //0, 어검술
      320,           //1  어검술
      230,           //2  반월검법
      1470,          //3  염화결, 시작
      3390,          //4  염화결 반짝임
      40,            //5  광풍참
      220,           //6  쌍룡참
      740            //7  공파섬
   );


   MAXMAGICTYPE = 15;

type
   TMagicType = (mtReady,           mtFly,            mtExplosion,
                 mtFlyAxe,          mtFireWind,       mtFireGun,
                 mtLightingThunder, mtThunder,        mtExploBujauk,
                 mtBujaukGroundEffect, mtKyulKai,     mtFlyArrow,
                 mtFireBall,        mtGroundEffect,   mtFireThunder,
                 mtFlyBug,          mtFlyBolt);

   TUseMagicInfo = record
      ServerMagicCode: integer;
      MagicSerial: integer;
      Target: integer; //recogcode
      EffectType: TMagicType;
      EffectNumber: integer;
      TargX: integer;
      TargY: integer;
      Recusion: Boolean;
      AniTime: integer;
   end;
   PTUseMagicInfo = ^TUseMagicInfo;

   TMagicEff = class
      Active: Boolean;
      Blend: Boolean;
      ServerMagicId: integer;
      MagOwner: TObject;
      TargetActor: TObject;

      ImgLib: TWMImages;
      EffectBase: integer;

      MagExplosionBase: integer;
      px, py: integer;
      RX, RY: integer;  // 맵의 좌표로 환산한 좌표
      Dir16, OldDir16: byte;
      TargetX, TargetY: integer;   //타겟의 스크린 좌표
      TargetRx, TargetRy: integer; //타겟의 맵 좌표
      FlyX, FlyY, OldFlyX, OldFlyY: integer; //현재 좌표
      FlyXf, FlyYf: Real;
      Repetition: Boolean; //애니메이션 반복
      FixedEffect: Boolean;  //고정 애니메시션
      MagicType: integer;
      NextEffect: TMagicEff;
      ExplosionFrame: integer;
      NextFrameTime: integer;
      Light: integer;
      //2003/07/15 시간제 이펙트
      RepeatUntil: longword;
      ExCase : Byte; // 0: 일반, 1,2..:예외사항
      FireDir : Byte; // 불공격 방향
   private
      start, curframe, frame: integer;
      framesteptime: longword;
      starttime:  longword;
      repeattime: longword; //반복 애니메이션 시간 (-1: 계속)
      steptime: longword;
      fireX, fireY: integer;
      firedisX, firedisY, newfiredisX, newfiredisY: integer;
      FireMyselfX, FireMyselfY: integer;
      prevdisx, prevdisy: integer; //날아가는 효과의 목표와의 거리
   protected
      procedure GetFlyXY (ms: integer; var fx, fy: integer);
   public
      constructor Create (id, effnum, sx, sy, tx, ty: integer; mtype: TMagicType; Recusion: Boolean; anitime: integer);
      destructor Destroy; override;
      function  Run: Boolean; dynamic; //false:끝났음.
      function  Shift: Boolean; dynamic;
      procedure DrawEff (surface: TDirectDrawSurface); dynamic;
   end;

   TFlyingAxe = class (TMagicEff)
      FlyImageBase: integer;
      ReadyFrame: integer;
   public
      constructor Create (id, effnum, sx, sy, tx, ty: integer; mtype: TMagicType; Recusion: Boolean; anitime: integer);
      procedure DrawEff (surface: TDirectDrawSurface); override;
   end;

   TFlyingBug = class (TMagicEff)
      FlyImageBase: integer;
      ReadyFrame: integer;
   public
      constructor Create (id, effnum, sx, sy, tx, ty: integer; mtype: TMagicType; Recusion: Boolean; anitime: integer);
      procedure DrawEff (surface: TDirectDrawSurface); override;
   end;

   TFlyingArrow = class (TFlyingAxe)
   public
      procedure DrawEff (surface: TDirectDrawSurface); override;
   end;

   // 2003/02/11
   TFlyingFireBall = class (TFlyingAxe)
   public
      constructor Create (id, effnum, sx, sy, tx, ty: integer; mtype: TMagicType; Recusion: Boolean; anitime: integer);
      procedure DrawEff (surface: TDirectDrawSurface); override;
   end;

   TCharEffect = class (TMagicEff)
   public
      constructor Create (effbase, effframe: integer; target: TObject);
      function  Run: Boolean; override; //false:끝났음.
      procedure DrawEff (surface: TDirectDrawSurface); override;
   end;

   TMapEffect = class (TMagicEff)
   public
      RepeatCount: integer;
      constructor Create (effbase, effframe: integer; x, y: integer);
      function  Run: Boolean; override; //false:끝났음.
      procedure DrawEff (surface: TDirectDrawSurface); override;
   end;

   TScrollHideEffect = class (TMapEffect)
   public
      constructor Create (effbase, effframe: integer; x, y: integer; target: TObject);
      function  Run: Boolean; override;
   end;

   TLightingEffect = class (TMagicEff)
   public
      constructor Create (effbase, effframe: integer; x, y: integer);
      function  Run: Boolean; override;
   end;

   TFireNode = record
      x: integer;
      y: integer;
      firenumber: integer;
   end;

   TFireGunEffect = class (TMagicEff)
   public
      OutofOil: Boolean;
      firetime: longword;
      FireNodes: array[0..FIREGUNFRAME-1] of TFireNode;
      constructor Create (effbase, sx, sy, tx, ty: integer);
      function  Run: Boolean; override;
      procedure DrawEff (surface: TDirectDrawSurface); override;
   end;

   TThuderEffect = class (TMagicEff)
   public
      ExCheckMag: Boolean;
      constructor Create (effbase, tx, ty: integer; target: TObject);
      procedure DrawEff (surface: TDirectDrawSurface); override;
   end;

   TThuderEffectEx = class (TMagicEff)
   public
      constructor Create (effbase, tx, ty: integer; target: TObject; magnum:integer);
      procedure DrawEff (surface: TDirectDrawSurface); override;
   end;

   TLightingThunder = class (TMagicEff)
   public
      constructor Create (effbase, sx, sy, tx, ty: integer; target: TObject);
      procedure DrawEff (surface: TDirectDrawSurface); override;
   end;

   TExploBujaukEffect = class (TMagicEff)
   public
      MagicNumber: integer;
      constructor Create (effbase, magicnumb, sx, sy, tx, ty: integer; target: TObject);
      procedure DrawEff (surface: TDirectDrawSurface); override;
   end;

   TBujaukGroundEffect = class (TMagicEff)
   public
      MagicNumber: integer;
      BoGroundEffect: Boolean;
      constructor Create (effbase, magicnumb, sx, sy, tx, ty: integer);
      function  Run: Boolean; override;
      procedure DrawEff (surface: TDirectDrawSurface); override;
   end;

   //한번 생겼다 사리지는 효과, 블랜등 안함
   TNormalDrawEffect = class (TMagicEff)
   private
      BoBlending: Boolean;
   public
      constructor Create (xx, yy: integer;
                          iLib: TWMImages;
                          eff_base: integer;
                          eff_frame: integer;
                          eff_time: integer;
                          blending: Boolean);
      function Run: Boolean; override;
      procedure DrawEff (surface: TDirectDrawSurface); override;
   end;

   procedure GetEffectBase (mag, mtype: integer; var wimg: TWMImages; var idx: integer);


implementation

uses
   ClMain, Actor, SoundUtil, uWilFile;


procedure GetEffectBase (mag, mtype: integer; var wimg: TWMImages; var idx: integer);
//function  GetEffectBase (mag, mtype: integer): integer;
begin
   wimg := nil;
   idx := 0;
//   if Not BoViewEffect then Exit;  //@@@@
   case mtype of
      0:  //일반적인 마법 시작 프래임
         begin
            case mag of
               // 2003/03/15 신규무공 추가
               33, // 멸천화
               34, // 무극진기
               35, // 기공파
               8,  // 강격
               // 2003/07/15 신규무공 추가
               37, // 쌍룡참
               38, // 결빙장
               39, // 정화술
               41, // 분신소환술
               42, // 사자후
               44, // 화룡기염
               46, // 포승검
               47, // 흡혈술
               48, // 맹안술
               27: // 신수소환
                  begin
                     wimg := g_WMagicEx[1];
                     if mag in [0..MAXEFFECT-1] then
                        idx := EffectBase[mag];
                  end;
               // 2003/03/04
               31: //마법진
                  begin
                     wimg := g_WMon21Img;
                     if mag in [0..MAXEFFECT-1] then
                        idx := EffectBase[mag];
                  end;
               36: //마법진2
                  begin
                     wimg := g_WMon22Img;
                     if mag in [0..MAXEFFECT-1] then
                        idx := EffectBase[mag];
                  end;
               (SM_DRAGON_FIRE1-1), (SM_DRAGON_FIRE2-1), (SM_DRAGON_FIRE3-1): // FireDragon
                  begin
                     wimg := g_WDragonImg;
                     if mag = SM_DRAGON_FIRE1-1 then begin
                        if Myself.XX >= 84 then idx := 130
                        else idx := 140;
                     end else if mag = SM_DRAGON_FIRE2-1 then begin
                        if (Myself.XX >= 78) and (Myself.YY >= 48) then idx := 150
                        else idx := 160;
                     end
                     else if mag = SM_DRAGON_FIRE3-1 then idx := 180;
                  end;
               89: // 용석상 지염
                  begin
                     wimg := g_WDragonImg;
                     idx := 350
//                     if mag = 89 then idx := 310
//                     else if mag = 90 then idx := 330;
                  end;
               MAGIC_TURTLE_WARTERATT-1:
                  begin
                     wimg := g_WMon25Img;
                     idx := 1460;
                  end;

               else
                  begin
                     wimg := g_WMagic;
                     if mag in [0..MAXEFFECT-1] then
                        idx := EffectBase[mag];
                  end;
            end;
         end;
      1: //검법 효과
         begin
            wimg := g_WMagic;
            if mag in [0..MAXHITEFFECT-1] then begin
               idx := HitEffectBase[mag];
            end;
            // 2003/03/15 신규무공
            // 2003/07/15 신규무공
            if (mag >= 5) then wimg := g_WMagicEx[1];
         end;
   end;
end;

constructor TMagicEff.Create (id, effnum, sx, sy, tx, ty: integer; mtype: TMagicType; Recusion: Boolean; anitime: integer);
var
   tax, tay: integer;
begin

   ExCase := 0;
   FireDir := 2;
   ImgLib := g_WMagic;  //기본
   Blend := True;

   if (not BoViewEffect) and (mtype <> mtThunder) then begin
      ImgLib := g_WMagicEx[1];
      EffectBase := 30;
      Exit;
   end;

   case mtype of
      mtReady:
         begin
         end;
      mtFly,
      mtBujaukGroundEffect,
      mtExploBujauk:
         begin
            start := 0;
            frame := 6;
            curframe := start;
            FixedEffect := FALSE;
            Repetition := Recusion;
            ExplosionFrame := 10;

            if id = 38 then begin // 쌍룡참
               frame := 10;
            end
            else if id = 39 then begin // 결빙장
               frame := 4;
               ExplosionFrame := 8;
            end;

            if id in [SM_DRAGON_FIRE1, SM_DRAGON_FIRE2, SM_DRAGON_FIRE3] then begin // FireDragon
               ExCase := 1;
               Repetition := True;
               if id = SM_DRAGON_FIRE1 then begin
                  if Myself.XX >= 84 then EffectBase := 130
                  else EffectBase := 140;
                  FireDir := 1;
               end
               else if id = SM_DRAGON_FIRE2 then begin
                  if (Myself.XX >= 78) and (Myself.YY >= 48) then EffectBase := 150
                  else EffectBase := 160;
                  FireDir := 2;
               end
               else if id = SM_DRAGON_FIRE3 then begin
                  EffectBase := 180;
                  FireDir := 3;
               end;
//            DScreen.AddChatBoardString (IntToStr(FireDir)+'%%Myself.XX=> '+IntToStr(Myself.XX), clYellow, clRed);
//            DScreen.AddChatBoardString (IntToStr(FireDir)+'%%Myself.YY=> '+IntToStr(Myself.YY), clYellow, clRed);
//            DScreen.AddChatBoardString ('EffectBase=> '+IntToStr(EffectBase), clYellow, clRed);

               start := 0;
               frame := 10;
               MagExplosionBase := 190;
               ExplosionFrame := 10;
            end
            else if id = MAGIC_TURTLE_WARTERATT then begin //갑철귀수 물공격
               frame := 3;
            end;

         end;
      // 2003/02/11
      mtFireBall:
         begin
            start := 0;
            frame := 6;
            curframe := start;
            FixedEffect := FALSE;
            Repetition  := Recusion;
            ExplosionFrame := 1;
         end;
      // 2003/03/04
      mtGroundEffect:
         begin
            start := 0;
            frame := 20;
            if id = MAGIC_SIDESTONE_ATT1 then frame := 10;
            curframe := start;
            FixedEffect := TRUE;
            Repetition  := FALSE;
//            ExplosionFrame := 20; 
            ImgLib := g_WMon21Img;  //기본
         end;
      mtExplosion,
      mtThunder,
      mtLightingThunder:
         begin
            start := 0;
            frame := -1;
            ExplosionFrame := 10;
            curframe := start;
            FixedEffect := TRUE;
            Repetition := FALSE;
            if id = SM_DRAGON_LIGHTING then begin // FireDragon
               ExCase := 2;
               Randomize;
               case random(6) of
                  0 : EffectBase := 230;
                  1 : EffectBase := 240;
                  2 : EffectBase := 250;
                  3 : EffectBase := 230;
                  4 : EffectBase := 240;
                  5 : EffectBase := 250;
               end;
               Light := 4;
               ExplosionFrame := 5;
            end
            else if id = MAGIC_DUN_THUNDER then begin // FireDragon
               ExCase := 3;
               Randomize;
               case random(3) of
                  0 : EffectBase := 400;
                  1 : EffectBase := 410;
                  2 : EffectBase := 420;
               end;
               Light := 4;
               ExplosionFrame := 5;
            end
            else if id = MAGIC_DUN_FIRE1 then begin
               ExCase := 3;
               ExplosionFrame := 20;
            end
            else if id = MAGIC_DUN_FIRE2 then begin
               ExCase := 3;
               Light := 3;
               ExplosionFrame := 10;
            end
            else if id = MAGIC_DRAGONFIRE then begin
               ExCase := 3;
               Light := 5;
               ExplosionFrame := 20;
            end
            else if id = MAGIC_FIREBURN then begin
               ExCase := 3;
               Light := 4;
               ExplosionFrame := 35;
            end
            else if id = MAGIC_SERPENT_1 then begin //####
               ExCase := 3;
               Light := 4;
               ExplosionFrame := 10;
            end
            else if id in [90] then begin
               EffectBase := 350;
               MagExplosionBase := 350;
               ExplosionFrame := 30;
            end;

         end;
      // 2003/03/15 신규무공 추가
      mtFireThunder:
         begin
            start := 0;
            frame := -1;
            ExplosionFrame := 10;
            curframe := start;
            FixedEffect := TRUE;
            Repetition := FALSE;
            ImgLib := g_WMagicEx[1];  //기본
         end;
      mtFlyAxe:
         begin
            start := 0;
            if ImgLib = g_WMon24Img then frame := 4
            else frame := 3;
            curframe := start;
            FixedEffect := FALSE;
            Repetition := Recusion;
            ExplosionFrame := 3;
         end;
      mtFlyArrow:
         begin
            start := 0;
            frame := 1;
            curframe := start;
            FixedEffect := FALSE;
            Repetition := Recusion;
            ExplosionFrame := 1;
         end;
      // 2003/07/15 신규몹 추가
      mtFlyBug:
         begin
            start := 0;
            frame := 6;
            curframe := start;
            FixedEffect := FALSE;
            Repetition := Recusion;
            ExplosionFrame := 2;
         end;
      mtFlyBolt:
         begin
            start := 0;
            frame := 1;
            curframe := start;
            FixedEffect := FALSE;
            Repetition := Recusion;
            ExplosionFrame := 1;
         end;
   end;
   RepeatUntil := 0;
   ServerMagicId := id; //서버의 ID
   EffectBase := effnum;
   TargetX := tx;   // "   target x
   TargetY := ty;   // "   target y

   if ExCase = 1 then begin
      if id = SM_DRAGON_FIRE1 then begin
         sx := sx-14;
         sy := sy+20;
      end else if id = SM_DRAGON_FIRE2 then begin
         sx := sx-70;
         sy := sy-10;
      end else if id = SM_DRAGON_FIRE3 then begin
         sx := sx-60;
         sy := sy-70;
      end;
      PlaySound (8208);
   end;

   fireX := sx;     //쏜 위치
   fireY := sy;     //
   FlyX := sx;      //날아가고 있는 위치
   FlyY := sy;
   OldFlyX := sx;
   OldFlyY := sy;
   FlyXf := sx;
   FlyYf := sy;
   FireMyselfX := Myself.RX*UNITX + Myself.ShiftX;
   FireMyselfY := Myself.RY*UNITY + Myself.ShiftY;

   if ExCase = 0  then  // ExCase = 0 일반
      MagExplosionBase := EffectBase + EXPLOSIONBASE;
   light := 1;

   if fireX <> TargetX then tax := abs(TargetX-fireX)
   else tax := 1;
   if fireY <> TargetY then tay := abs(TargetY-fireY)
   else tay := 1;
   if abs(fireX-TargetX) > abs(fireY-TargetY) then begin
      firedisX := Round((TargetX-fireX) * (500 / tax));
      firedisY := Round((TargetY-fireY) * (500 / tax));
   end else begin
      firedisX := Round((TargetX-fireX) * (500 / tay));
      firedisY := Round((TargetY-fireY) * (500 / tay));
   end;

   NextFrameTime := 50;
   framesteptime := GetTickCount;
   starttime := GetTickCount;
   steptime := GetTickCount;
   RepeatTime := anitime;
   Dir16 := GetFlyDirection16 (sx, sy, tx, ty);
   OldDir16 := Dir16;
   NextEffect := nil;
   Active := TRUE;
   prevdisx := 99999;
   prevdisy := 99999;
end;

destructor TMagicEff.Destroy;
begin
   inherited Destroy;
end;

function  TMagicEff.Shift: Boolean;
   function OverThrough (olddir, newdir: integer): Boolean;
   begin
      Result := FALSE;
      if abs(olddir-newdir) >= 2 then begin
         Result := TRUE;
         if ((olddir=0) and (newdir=15)) or ((olddir=15) and (newdir=0)) then
            Result := FALSE;
      end;
   end;
var
   i, rrx, rry, ms, stepx, stepy, newstepx, newstepy, nn: integer;
   tax, tay, shx, shy, passdir16: integer;
   crash: Boolean;
   stepxf, stepyf: Real;
   bofly: Boolean;
begin
   Result := TRUE;
   if Repetition then begin
      if GetTickCount - steptime > longword(NextFrameTime) then begin
         steptime := GetTickCount;
         Inc (curframe);
         if curframe > start+frame-1 then
            curframe := start;
      end;
   end else begin
      if (frame > 0) and (GetTickCount - steptime > longword(NextFrameTime)) then begin
         steptime := GetTickCount;
         Inc (curframe);
         if curframe > start+frame-1 then begin
            curframe := start+frame-1;
            Result := FALSE;
         end;
      end;
   end;
   if (not FixedEffect) then begin

      crash := FALSE;
      if TargetActor <> nil then begin
         ms := GetTickCount - framesteptime;  //이전 효과를 그린후 얼마나 시간이 흘렀는지?
         framesteptime := GetTickCount;
         //TargetX, TargetY 재설정
         PlayScene.ScreenXYfromMCXY (TActor(TargetActor).RX,
                                     TActor(TargetActor).RY,
                                     TargetX,
                                     TargetY);
         shx := (Myself.RX*UNITX + Myself.ShiftX) - FireMyselfX;
         shy := (Myself.RY*UNITY + Myself.ShiftY) - FireMyselfY;
         TargetX := TargetX + shx;
         TargetY := TargetY + shy;

         //새로운 타겟을 좌표를 새로 설정한다.
         if FlyX <> TargetX then tax := abs(TargetX-FlyX)
         else tax := 1;
         if FlyY <> TargetY then tay := abs(TargetY-FlyY)
         else tay := 1;
         if abs(FlyX-TargetX) > abs(FlyY-TargetY) then begin
            newfiredisX := Round((TargetX-FlyX) * (500 / tax));
            newfiredisY := Round((TargetY-FlyY) * (500 / tax));
         end else begin
            newfiredisX := Round((TargetX-FlyX) * (500 / tay));
            newfiredisY := Round((TargetY-FlyY) * (500 / tay));
         end;

         if firedisX < newfiredisX then firedisX := firedisX + _MAX(1, (newfiredisX - firedisX) div 10);
         if firedisX > newfiredisX then firedisX := firedisX - _MAX(1, (firedisX - newfiredisX) div 10);
         if firedisY < newfiredisY then firedisY := firedisY + _MAX(1, (newfiredisY - firedisY) div 10);
         if firedisY > newfiredisY then firedisY := firedisY - _MAX(1, (firedisY - newfiredisY) div 10);

         stepxf := (firedisX/700) * ms;
         stepyf := (firedisY/700) * ms;
         FlyXf := FlyXf + stepxf;
         FlyYf := FlyYf + stepyf;
         FlyX := Round (FlyXf);
         FlyY := Round (FlyYf);

         //방향 재설정
       //  Dir16 := GetFlyDirection16 (OldFlyX, OldFlyY, FlyX, FlyY);
         OldFlyX := FlyX;
         OldFlyY := FlyY;
         //통과여부를 확인하기 위하여
         passdir16 := GetFlyDirection16 (FlyX, FlyY, TargetX, TargetY);

         //DebugOutStr (IntToStr(prevdisx) + ' ' + IntToStr(prevdisy) + ' / ' + IntToStr(abs(TargetX-FlyX)) + ' ' + IntToStr(abs(TargetY-FlyY)) + '   ' +
         //             IntToStr(firedisX) + '.' + IntToStr(firedisY) + ' ' +
         //             IntToStr(FlyX) + '.' + IntToStr(FlyY) + ' ' +
         //             IntToStr(TargetX) + '.' + IntToStr(TargetY));
         if ((abs(TargetX-FlyX) <= 15) and (abs(TargetY-FlyY) <= 15)) or
            ((abs(TargetX-FlyX) >= prevdisx) and (abs(TargetY-FlyY) >= prevdisy)) or
            OverThrough(OldDir16, passdir16) then begin
            crash := TRUE;
         end else begin
            prevdisx := abs(TargetX-FlyX);
            prevdisy := abs(TargetY-FlyY);
            //if (prevdisx <= 5) and (prevdisy <= 5) then crash := TRUE;
         end;
         OldDir16 := passdir16;

      end else begin
         ms := GetTickCount - framesteptime;  //효과의 시작후 얼마나 시간이 흘렀는지?

         rrx := TargetX - fireX;
         rry := TargetY - fireY;

         stepx := Round ((firedisX/900) * ms);
         stepy := Round ((firedisY/900) * ms);
         FlyX := fireX + stepx;
         FlyY := fireY + stepy;
      end;

      PlayScene.CXYfromMouseXY (FlyX, FlyY, Rx, Ry);

      if crash and (TargetActor <> nil) then begin
         FixedEffect := TRUE;  //폭발
         Repetition := FALSE;
         if ExCase = 1 then begin
            PlayScene.NewMagic (nil, MAGIC_DRAGONFIRE, MAGIC_DRAGONFIRE,
                                TActor(TargetActor).Rx, TActor(TargetActor).Ry, TActor(TargetActor).Rx, TActor(TargetActor).Ry, 0, mtThunder, FALSE, 30, bofly);
            PlaySound (8207);
         end
         else begin
            start := 0;
            frame := ExplosionFrame;
            curframe := start;
            //터지는 사운드
            PlaySound (TActor(MagOwner).magicexplosionsound);
         end;
      end;
      //if not Map.CanFly (Rx, Ry) then
      //   Result := FALSE;
   end;
   if FixedEffect then begin
      if frame = -1 then frame := ExplosionFrame;
      if TargetActor = nil then begin
         FlyX := TargetX - ((Myself.RX*UNITX + Myself.ShiftX) - FireMyselfX);
         FlyY := TargetY - ((Myself.RY*UNITY + Myself.ShiftY) - FireMyselfY);
         PlayScene.CXYfromMouseXY (FlyX, FlyY, Rx, Ry);
      end else begin
         Rx := TActor(TargetActor).Rx;
         Ry := TActor(TargetActor).Ry;
         PlayScene.ScreenXYfromMCXY (Rx, Ry, FlyX, FlyY);
         FlyX := FlyX + TActor(TargetActor).ShiftX;
         FlyY := FlyY + TActor(TargetActor).ShiftY;
      end;
   end;
end;

procedure TMagicEff.GetFlyXY (ms: integer; var fx, fy: integer);
var
   rrx, rry, stepx, stepy: integer;
begin
   rrx := TargetX - fireX;
   rry := TargetY - fireY;

   stepx := Round ((firedisX/900) * ms);
   stepy := Round ((firedisY/900) * ms);
   fx := fireX + stepx;
   fy := fireY + stepy;
end;

function  TMagicEff.Run: Boolean;
begin
   Result := Shift;
   if Result then
      if GetTickCount - starttime > 10000 then //2000 then
         Result := FALSE
      else Result := TRUE;
end;

procedure TMagicEff.DrawEff (surface: TDirectDrawSurface);
var
   img: integer;
   d: TDirectDrawSurface;
   shx, shy: integer;
begin
//   if not BoViewEffect then Exit; //@@@@
   if Active and ((Abs(FlyX-fireX) > 15) or (Abs(FlyY-fireY) > 15) or FixedEffect) then begin

      shx := (Myself.RX*UNITX + Myself.ShiftX) - FireMyselfX;
      shy := (Myself.RY*UNITY + Myself.ShiftY) - FireMyselfY;

      if not FixedEffect then begin
         //날아가는거
         if ExCase = 1 then img := EffectBase // FireDragon
         else img := EffectBase + FLYBASE + Dir16 * 10;
//         DScreen.AddChatBoardString ('img + curframe=> '+IntToStr(img + curframe), clYellow, clRed); // FireDragon
         d := ImgLib.GetCachedImage (img + curframe, px, py);
         if d <> nil then begin
            DrawBlend (surface,
                       FlyX + px - UNITX div 2 - shx,
                       FlyY + py - UNITY div 2 - shy,
                       d, 1);
         end;
      end else begin
         //터지는거
         img := MagExplosionBase + curframe; //EXPLOSIONBASE;
         d := ImgLib.GetCachedImage (img, px, py);
         if d <> nil then begin
            DrawBlend (surface,
                       FlyX + px - UNITX div 2,
                       FlyY + py - UNITY div 2,
                       d, 1);
         end;
      end;
   end;
end;


{------------------------------------------------------------}
//      TFlyingAxe : 날아가는 도끼
{------------------------------------------------------------}

constructor TFlyingAxe.Create (id, effnum, sx, sy, tx, ty: integer; mtype: TMagicType; Recusion: Boolean; anitime: integer);
begin
   inherited Create (id, effnum, sx, sy, tx, ty, mtype, Recusion, anitime);
   FlyImageBase := FLYOMAAXEBASE;
   ReadyFrame := 65;
end;

procedure TFlyingAxe.DrawEff (surface: TDirectDrawSurface);
var
   img: integer;
   d: TDirectDrawSurface;
   shx, shy: integer;
begin
   if Active and ((Abs(FlyX-fireX) > ReadyFrame) or (Abs(FlyY-fireY) > ReadyFrame)) then begin

      shx := (Myself.RX*UNITX + Myself.ShiftX) - FireMyselfX;
      shy := (Myself.RY*UNITY + Myself.ShiftY) - FireMyselfY;

      if not FixedEffect then begin
         //날아가는거
         img := FlyImageBase + Dir16 * 10;
         d := ImgLib.GetCachedImage (img + curframe, px, py);
         if d <> nil then begin
            //알파블랭딩하지 않음
            surface.Draw (FlyX + px - UNITX div 2 - shx,
                          FlyY + py - UNITY div 2 - shy,
                          d.ClientRect, d, TRUE);
         end;
      end else begin
         {//정지, 도끼에 찍힌 모습.
         img := FlyImageBase + Dir16 * 10;
         d := ImgLib.GetCachedImage (img, px, py);
         if d <> nil then begin
            //알파블랭딩하지 않음
            surface.Draw (FlyX + px - UNITX div 2,
                          FlyY + py - UNITY div 2,
                          d.ClientRect, d, TRUE);
         end;  }
      end;
   end;
end;

{------------------------------------------------------------}
//      TFlyingBug : 날아가는 벌레
{------------------------------------------------------------}

constructor TFlyingBug.Create (id, effnum, sx, sy, tx, ty: integer; mtype: TMagicType; Recusion: Boolean; anitime: integer);
begin
   inherited Create (id, effnum, sx, sy, tx, ty, mtype, Recusion, anitime);
   FlyImageBase := FLYOMAAXEBASE;
   ReadyFrame := 65;
end;

procedure TFlyingBug.DrawEff (surface: TDirectDrawSurface);
var
   img: integer;
   d: TDirectDrawSurface;
   shx, shy: integer;
begin
//   if not BoViewEffect then Exit;
   if Active and ((Abs(FlyX-fireX) > ReadyFrame) or (Abs(FlyY-fireY) > ReadyFrame)) then begin

      shx := (Myself.RX*UNITX + Myself.ShiftX) - FireMyselfX;
      shy := (Myself.RY*UNITY + Myself.ShiftY) - FireMyselfY;

      if not FixedEffect then begin
         //날아가는거          // 8 방향이다 이런 ...
         img := FlyImageBase + ( Dir16 div 2 )* 10;
         d := ImgLib.GetCachedImage (img + curframe, px, py);
         if d <> nil then begin
            //알파블랭딩하지 않음
            surface.Draw (FlyX + px - UNITX div 2 - shx,
                          FlyY + py - UNITY div 2 - shy,
                          d.ClientRect, d, TRUE);
         end;
      end else begin
         //터지는거
         img := MagExplosionBase + curframe; //EXPLOSIONBASE;
         d := ImgLib.GetCachedImage (img, px, py);
         if d <> nil then begin
            //알파블랭딩하지 않음
            surface.Draw (FlyX + px - UNITX div 2 - shx,
                          FlyY + py - UNITY div 2 - shy,
                          d.ClientRect, d, TRUE);
         end;
      end;
   end;
end;


{------------------------------------------------------------}
//      TFlyingArrow : 날아가는 화살
{------------------------------------------------------------}


procedure TFlyingArrow.DrawEff (surface: TDirectDrawSurface);
var
   img: integer;
   d: TDirectDrawSurface;
   shx, shy: integer;
begin
//(**6월패치
   if Active and ((Abs(FlyX-fireX) > 40) or (Abs(FlyY-fireY) > 40)) then begin
//*)
(**이전
   if Active then begin //and ((Abs(FlyX-fireX) > 65) or (Abs(FlyY-fireY) > 65)) then begin
//*)
      shx := (Myself.RX*UNITX + Myself.ShiftX) - FireMyselfX;
      shy := (Myself.RY*UNITY + Myself.ShiftY) - FireMyselfY;

      if not FixedEffect then begin
         //날아가는거
         img := FlyImageBase + Dir16; // * 10;
         d := ImgLib.GetCachedImage (img + curframe, px, py);
//(**6월패치
         if d <> nil then begin
            //알파블랭딩하지 않음
            surface.Draw (FlyX + px - UNITX div 2 - shx,
                          FlyY + py - UNITY div 2 - shy - 46,
                          d.ClientRect, d, TRUE);
         end;
//**)
(***이전
         if d <> nil then begin
            //알파블랭딩하지 않음
            surface.Draw (FlyX + px - UNITX div 2 - shx,
                          FlyY + py - UNITY div 2 - shy,
                          d.ClientRect, d, TRUE);
         end;
//**)
      end;
   end;
end;


{--------------------------------------------------------}

constructor TCharEffect.Create (effbase, effframe: integer; target: TObject);
begin
   inherited Create (111, effbase,
                     TActor(target).XX, TActor(target).YY,
                     TActor(target).XX, TActor(target).YY,
                     mtExplosion,
                     FALSE,
                     0);
   TargetActor := target;
   frame := effframe;
   NextFrameTime := 30;
end;

function  TCharEffect.Run: Boolean;
begin
   Result := TRUE;
   if GetTickCount - steptime > longword(NextFrameTime) then begin
      steptime := GetTickCount;
      Inc (curframe);
      if curframe > start+frame-1 then begin
         if RepeatUntil = 0 then begin
            curframe := start+frame-1;
            Result := FALSE;
         end else begin
            curframe := start;
            if GetTickCount > RepeatUntil then Result := FALSE;
         end;
      end;
   end;
end;

procedure TCharEffect.DrawEff (surface: TDirectDrawSurface);
var
   d: TDirectDrawSurface;
begin
//   if not BoViewEffect then Exit;
   if TargetActor <> nil then begin
      if TActor(TargetActor).Death then RepeatUntil := 0;
      Rx := TActor(TargetActor).Rx;
      Ry := TActor(TargetActor).Ry;
      PlayScene.ScreenXYfromMCXY (Rx, Ry, FlyX, FlyY);
      FlyX := FlyX + TActor(TargetActor).ShiftX;
      FlyY := FlyY + TActor(TargetActor).ShiftY;
      d := ImgLib.GetCachedImage (EffectBase + curframe, px, py);
      if d <> nil then begin
         if Blend then
            DrawBlend (surface,
                       FlyX + px - UNITX div 2,
                       FlyY + py - UNITY div 2,
                       d, 1)
         else
            surface.Draw (FlyX + px - UNITX div 2, FlyY + py - UNITY div 2, d.ClientRect, d, True);
      end;
   end;
end;


{--------------------------------------------------------}

constructor TMapEffect.Create (effbase, effframe: integer; x, y: integer);
begin
   inherited Create (111, effbase,
                     x, y,
                     x, y,
                     mtExplosion,
                     FALSE,
                     0);
   TargetActor := nil;
   frame := effframe;
   NextFrameTime := 30;
   RepeatCount := 0;
end;

function  TMapEffect.Run: Boolean;
begin
   Result := TRUE;
   if GetTickCount - steptime > longword(NextFrameTime) then begin
      steptime := GetTickCount;
      Inc (curframe);
      if curframe > start+frame-1 then begin
         curframe := start+frame-1;
         if RepeatCount > 0 then begin
            Dec (RepeatCount);
            curframe := start;
         end else
            Result := FALSE;
      end;
   end;
end;

procedure TMapEffect.DrawEff (surface: TDirectDrawSurface);
var
   d: TDirectDrawSurface;
begin
   Rx := TargetX;
   Ry := TargetY;
   PlayScene.ScreenXYfromMCXY (Rx, Ry, FlyX, FlyY);
   d := ImgLib.GetCachedImage (EffectBase + curframe, px, py);
   if d <> nil then begin
      DrawBlend (surface,
                 FlyX + px - UNITX div 2,
                 FlyY + py - UNITY div 2,
                 d, 1);
   end;
end;


{--------------------------------------------------------}

constructor TScrollHideEffect.Create (effbase, effframe: integer; x, y: integer; target: TObject);
begin
   inherited Create (effbase, effframe, x, y);
   TargetActor := target;
end;

function  TScrollHideEffect.Run: Boolean;
begin
   Result := inherited Run;
   if frame = 7 then
      if TargetActor <> nil then
         PlayScene.DeleteActor (TActor(TargetActor).RecogId);

end;


{--------------------------------------------------------}


constructor TLightingEffect.Create (effbase, effframe: integer; x, y: integer);
begin

end;

function  TLightingEffect.Run: Boolean;
begin
end;


{--------------------------------------------------------}


constructor TFireGunEffect.Create (effbase, sx, sy, tx, ty: integer);
begin
   inherited Create (111, effbase,
                     sx, sy,
                     tx, ty, //TActor(target).XX, TActor(target).YY,
                     mtFireGun,
                     TRUE,
                     0);
   NextFrameTime := 50;
   FillChar (FireNodes, sizeof(TFireNode)*FIREGUNFRAME, #0);
   OutofOil := FALSE;
   firetime := GetTickCount;
end;

function  TFireGunEffect.Run: Boolean;
var
   i, fx, fy: integer;
   allgone: Boolean;
begin
   Result := TRUE;
   if GetTickCount - steptime > longword(NextFrameTime) then begin
      Shift;
      steptime := GetTickCount;
      //if not FixedEffect then begin  //목표에 맞지 않았으면
      if not OutofOil then begin
         if (abs(RX-TActor(MagOwner).RX) >= 5) or (abs(RY-TActor(MagOwner).RY) >= 5) or (GetTickCount - firetime > 800) then
            OutofOil := TRUE;
         for i:=FIREGUNFRAME-2 downto 0 do begin
            FireNodes[i].FireNumber := FireNodes[i].FireNumber + 1;
            FireNodes[i+1] := FireNodes[i];
         end;
         FireNodes[0].FireNumber := 1;
         FireNodes[0].x := FlyX;
         FireNodes[0].y := FlyY;
      end else begin
         allgone := TRUE;
         for i:=FIREGUNFRAME-2 downto 0 do begin
            if FireNodes[i].FireNumber <= FIREGUNFRAME then begin
               FireNodes[i].FireNumber := FireNodes[i].FireNumber + 1;
               FireNodes[i+1] := FireNodes[i];
               allgone := FALSE;
            end;
         end;
         if allgone then Result := FALSE;
      end;
   end;
end;

procedure TFireGunEffect.DrawEff (surface: TDirectDrawSurface);
var
   i, num, shx, shy, firex, firey, prx, pry, img: integer;
   d: TDirectDrawSurface;
begin
   if not BoViewEffect then Exit;
   prx := -1;
   pry := -1;
   for i:=0 to FIREGUNFRAME-1 do begin
      if (FireNodes[i].FireNumber <= FIREGUNFRAME) and (FireNodes[i].FireNumber > 0) then begin
         shx := (Myself.RX*UNITX + Myself.ShiftX) - FireMyselfX;
         shy := (Myself.RY*UNITY + Myself.ShiftY) - FireMyselfY;

         img := EffectBase + (FireNodes[i].FireNumber - 1);
         d := ImgLib.GetCachedImage (img, px, py);
         if d <> nil then begin
            firex := FireNodes[i].x + px - UNITX div 2 - shx;
            firey := FireNodes[i].y + py - UNITY div 2 - shy;
            if (firex <> prx) or (firey <> pry) then begin
               prx := firex;
               pry := firey;
               DrawBlend (surface, firex, firey, d, 1);
            end;
         end;
      end;
   end;
end;

{--------------------------------------------------------}

constructor TThuderEffect.Create (effbase, tx, ty: integer; target: TObject);
begin
   ExCheckMag := False;
   if (effbase = 10) then begin
     ExCheckMag := True;
     inherited Create (111, effbase,
                       tx, ty,
                       tx, ty, //TActor(target).XX, TActor(target).YY,
                       mtThunder,
                       FALSE,
                       0);
   end else begin
     inherited Create (111, effbase,
                       tx, ty,
                       tx, ty, //TActor(target).XX, TActor(target).YY,
                       mtFireThunder,
                       FALSE,
                       0);
   end;
   TargetActor := target;

end;

procedure TThuderEffect.DrawEff (surface: TDirectDrawSurface);
var
   img, px, py: integer;
   d: TDirectDrawSurface;
begin
   if (not BoViewEffect) and (not ExCheckMag) then Exit;
   img := EffectBase;
   d := ImgLib.GetCachedImage (img + curframe, px, py);
   if d <> nil then begin
      DrawBlend (surface,
                 FlyX + px - UNITX div 2,
                 FlyY + py - UNITY div 2,
                 d, 1);
   end;
end;

// TThuderEffectEx ---------------

constructor TThuderEffectEx.Create (effbase, tx, ty: integer; target: TObject; magnum:integer);
begin

//  inherited Create (SM_DRAGON_LIGHTING, effbase,
  inherited Create (magnum, effbase,
                    tx, ty,
                    tx, ty, //TActor(target).XX, TActor(target).YY,
                    mtThunder,
                    FALSE,
                    0);
   TargetActor := target;

end;


procedure TThuderEffectEx.DrawEff (surface: TDirectDrawSurface);
var
   img, px, py: integer;
   d: TDirectDrawSurface;
begin
   if not BoViewEffect then Exit;
   img := EffectBase;
   d := ImgLib.GetCachedImage (img + curframe, px, py);
   if d <> nil then begin
      DrawBlend (surface,
                 FlyX + px - UNITX div 2,
                 FlyY + py - UNITY div 2,
                 d, 1);
   end;
end;


{--------------------------------------------------------}

constructor TLightingThunder.Create (effbase, sx, sy, tx, ty: integer; target: TObject);
begin
   inherited Create (111, effbase,
                     sx, sy,
                     tx, ty, //TActor(target).XX, TActor(target).YY,
                     mtLightingThunder,
                     FALSE,
                     0);
   TargetActor := target;
end;

procedure TLightingThunder.DrawEff (surface: TDirectDrawSurface);
var
   img, sx, sy, px, py, shx, shy: integer;
   d: TDirectDrawSurface;
begin
   if not BoViewEffect then Exit;
   img := EffectBase + Dir16 * 10;
   if curframe < 6 then begin

      shx := (Myself.RX*UNITX + Myself.ShiftX) - FireMyselfX;
      shy := (Myself.RY*UNITY + Myself.ShiftY) - FireMyselfY;

      d := ImgLib.GetCachedImage (img + curframe, px, py);
      if d <> nil then begin
         PlayScene.ScreenXYfromMCXY (TActor(MagOwner).RX,
                                     TActor(MagOwner).RY,
                                     sx,
                                     sy);
         DrawBlend (surface,
                    sx + px - UNITX div 2,
                    sy + py - UNITY div 2,
                    d, 1);
      end;
   end;
   {if (curframe < 10) and (TargetActor <> nil) then begin
      d := ImgLib.GetCachedImage (EffectBase + 17*10 + curframe, px, py);
      if d <> nil then begin
         PlayScene.ScreenXYfromMCXY (TActor(TargetActor).RX,
                                     TActor(TargetActor).RY,
                                     sx,
                                     sy);
         DrawBlend (surface,
                    sx + px - UNITX div 2,
                    sy + py - UNITY div 2,
                    d, 1);
      end;
   end;}
end;


{--------------------------------------------------------}

constructor TExploBujaukEffect.Create (effbase, magicnumb, sx, sy, tx, ty: integer; target: TObject);
begin
   inherited Create (111, effbase,
                     sx, sy,
                     tx, ty,
                     mtExploBujauk,
                     TRUE,
                     0);
   frame := 3;
   MagicNumber := magicnumb;
   TargetActor := target;
   NextFrameTime := 50;
end;

procedure TExploBujaukEffect.DrawEff (surface: TDirectDrawSurface);
var
   img: integer;
   d: TDirectDrawSurface;
   shx, shy: integer;
   meff: TMapEffect;
begin
   if not BoViewEffect then Exit;
   if Active and ((Abs(FlyX-fireX) > 30) or (Abs(FlyY-fireY) > 30) or FixedEffect) then begin

      shx := (Myself.RX*UNITX + Myself.ShiftX) - FireMyselfX;
      shy := (Myself.RY*UNITY + Myself.ShiftY) - FireMyselfY;

      if not FixedEffect then begin
         //날아가는거
         img := EffectBase + Dir16 * 10;
         d := ImgLib.GetCachedImage (img + curframe, px, py);
         if d <> nil then begin
            //알파블랭딩하지 않음
            surface.Draw (FlyX + px - UNITX div 2 - shx,
                          FlyY + py - UNITY div 2 - shy,
                          d.ClientRect, d, TRUE);
         end;
      end else begin
         //폭발
         img := MagExplosionBase + curframe;

         if MagicNumber = 49 then begin //미혼술
            NextFrameTime := 100;
            img := 1110 + curframe;
            ImgLib := g_WMagicEx[1];
         end
         else if MagicNumber = MAGIC_FOX_FIRE2 then begin //도사비월여우 폭살계
            NextFrameTime := 100;
            img := 1320 + curframe;
            ImgLib := g_WMon24Img;
         end
         else if MagicNumber = MAGIC_FOX_CURSE then begin //도사비월여우 저주술
            NextFrameTime := 100;
            img := 1330 + curframe;
            ImgLib := g_WMon24Img;
         end;

         d := ImgLib.GetCachedImage (img, px, py);
         if d <> nil then begin
            DrawBlend (surface,
                       FLyX + px - UNITX div 2,
                       FlyY + py - UNITY div 2,
                       d, 1);
         end;
      end;
   end;
end;

{--------------------------------------------------------}

constructor TBujaukGroundEffect.Create (effbase, magicnumb, sx, sy, tx, ty: integer);
begin
   inherited Create (111, effbase,
                     sx, sy,
                     tx, ty,
                     mtBujaukGroundEffect,
                     TRUE,
                     0);
   frame := 3;
   MagicNumber := magicnumb;
   BoGroundEffect := FALSE;
   NextFrameTime := 50;
end;

function  TBujaukGroundEffect.Run: Boolean;
begin
   Result := inherited Run;
   if not FixedEffect then begin
      if ((abs(TargetX-FlyX) <= 15) and (abs(TargetY-FlyY) <= 15)) or
         ((abs(TargetX-FlyX) >= prevdisx) and (abs(TargetY-FlyY) >= prevdisy)) then begin
         FixedEffect := TRUE;  //폭발
         start := 0;
         frame := ExplosionFrame;
         curframe := start;
         Repetition := FALSE;
         //터지는 사운드
         PlaySound (TActor(MagOwner).magicexplosionsound);

         Result := TRUE;
      end else begin
         prevdisx := abs(TargetX-FlyX);
         prevdisy := abs(TargetY-FlyY);
      end;
   end;
end;

procedure TBujaukGroundEffect.DrawEff (surface: TDirectDrawSurface);
var
   img: integer;
   d: TDirectDrawSurface;
   shx, shy: integer;
   meff: TMapEffect;
begin
   if not BoViewEffect then Exit;
   if Active and ((Abs(FlyX-fireX) > 30) or (Abs(FlyY-fireY) > 30) or FixedEffect) then begin

      shx := (Myself.RX*UNITX + Myself.ShiftX) - FireMyselfX;
      shy := (Myself.RY*UNITY + Myself.ShiftY) - FireMyselfY;

      if not FixedEffect then begin
         //날아가는거
         img := EffectBase + Dir16 * 10;
         d := ImgLib.GetCachedImage (img + curframe, px, py);
         if d <> nil then begin
            //알파블랭딩하지 않음
            surface.Draw (FlyX + px - UNITX div 2 - shx,
                          FlyY + py - UNITY div 2 - shy,
                          d.ClientRect, d, TRUE);
         end;
      end else begin
         //폭발
         if MagicNumber = 11 then       //항마진법
            img := EffectBase + 16 * 10 + curframe
         else if MagicNumber = 12 then  //대지원호
            img := EffectBase + 18 * 10 + curframe
         else if MagicNumber = 46 then begin //저주술
            NextFrameTime := 100;
            img := 950 + curframe;
            ImgLib := g_WMagicEx[1];
         end;

         d := ImgLib.GetCachedImage (img, px, py);
         if d <> nil then begin
            DrawBlend (surface,
                       FLyX + px - UNITX div 2, // - shx,
                       FlyY + py - UNITY div 2, // - shy,
                       d, 1);
         end;

         {if not BoGroundEffect and (curframe = 8) then begin
            BoGroundEffect := TRUE;
            meff := TMapEffect.Create (img+2, 6, TargetRx, TargetRy);
            meff.NextFrameTime := 100;
            //meff.RepeatCount := 1;
            PlayScene.GroundEffectList.Add (meff);
         end; }
      end;
   end;
end;



{--------------------------------------------------------}
//블랜딩 안하는 효과

constructor TNormalDrawEffect.Create (xx, yy: integer;
                                       iLib: TWMImages;
                                       eff_base: integer;
                                       eff_frame: integer;
                                       eff_time: integer;
                                       blending: Boolean);
begin
   if not BoViewEffect then Exit;
   inherited Create (111, eff_base,
                     xx, yy,
                     xx, yy,
                     mtReady,  //사용안함
                     TRUE,
                     0);
   ImgLib := ilib;          //이미지 라이브러리
   EffectBase := eff_base;      //그림의 시작 번호
   start := 0;
   curframe := 0;
   frame := eff_frame;      //프래임수
   NextFrameTime := eff_time;  //간격
   BoBlending := blending;

end;

function TNormalDrawEffect.Run: Boolean;
begin
   if not BoViewEffect then Exit;
   Result := TRUE;
   if Active then begin
      if GetTickCount - steptime > longword(NextFrameTime) then begin
         steptime := GetTickCount;
         Inc (curframe);
         if curframe > start+frame-1 then begin
            curframe := start;
            Result := FALSE;
         end;
      end;
   end;
end;

procedure TNormalDrawEffect.DrawEff (surface: TDirectDrawSurface);
var
   img, sx, sy, px, py, shx, shy: integer;
   d: TDirectDrawSurface;
begin
   if not BoViewEffect then Exit;
   img := EffectBase + curframe;

   //shx := (Myself.RX*UNITX + Myself.ShiftX) - FireMyselfX;
   //shy := (Myself.RY*UNITY + Myself.ShiftY) - FireMyselfY;

   d := ImgLib.GetCachedImage (img, px, py);
   if d <> nil then begin
      PlayScene.ScreenXYfromMCXY (FlyX, //TActor(MagOwner).RX,
                                  FlyY, //TActor(MagOwner).RY,
                                  sx,
                                  sy);
      if BoBlending then begin
         DrawBlend (surface,
                    sx + px - UNITX div 2,
                    sy + py - UNITY div 2,
                    d, 1);
      end else begin
         surface.Draw (
                    sx + px - UNITX div 2,
                    sy + py - UNITY div 2,
                    d.ClientRect,
                    d,
                    TRUE);
      end;
   end;
end;

// 2003/02/11
// 날아가는 불공
constructor TFlyingFireBall.Create (id, effnum, sx, sy, tx, ty: integer; mtype: TMagicType; Recusion: Boolean; anitime: integer);
begin
   inherited Create (id, effnum, sx, sy, tx, ty, mtype, Recusion, anitime);
end;

procedure TFlyingFireBall.DrawEff (surface: TDirectDrawSurface);
var
   img, tdir : integer;
   d: TDirectDrawSurface;
begin
   if not BoViewEffect then Exit;
   if Active and ((Abs(FlyX-fireX) > ReadyFrame) or (Abs(FlyY-fireY) > ReadyFrame)) then begin
      tdir := GetFlyDirection(FlyX, FlyY, TargetX, TargetY);
      img := FlyImageBase + tdir * 10;
      d := ImgLib.GetCachedImage (img + curframe, px, py);
      if d <> nil then begin
         DrawBlend (surface,
                    FLyX + px - UNITX div 2,
                    FlyY + py - UNITY div 2,
                    d, 1);
      end;
   end;
end;

end.

