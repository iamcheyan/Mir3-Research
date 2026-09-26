unit ObjMon3;

interface

uses
  Windows, Messages, SysUtils, Classes, Graphics, Controls, Dialogs,
  ScktComp, syncobjs, MudUtil, HUtil32, Grobal2, Envir, EdCode, ObjBase,
  Event , objmon ;

type
   // 분신 ---------------------------------------------------------------------
   TCloneMon = class (TATMonster)
   private
      bofirst: Boolean;
      NextMPSpendTime : LONGWORD;
      MPSpendTickTime : LONGWORD;
   protected
      procedure   ResetLevel;
      procedure   RangeAttackTo (targ: TCreature);
      function    AttackTarget: Boolean; override;
      procedure   BeforeRecalcAbility;
      procedure   AfterRecalcAbility;
   public
      constructor Create;
      destructor  Destroy; override;
      procedure   RecalcAbilitys; override;
      procedure   Run; override;
   end;

   // 월령 ---------------------------------------------------------------------
   TAngelMon = class (TATMonster)
   private
      bofirst       : Boolean;
   protected
      procedure     ResetLevel;
      procedure     RangeAttackTo (targ: TCreature);
      function      AttackTarget: Boolean; override;
      procedure     BeforeRecalcAbility;
      procedure     AfterRecalcAbility;
   public
      constructor   Create;
      destructor    Destroy; override;
      procedure     RecalcAbilitys; override;
      procedure     Run; override;
   end;

   // 화룡  --------------------------------------------------------------------
   TDragon = class (TATMonster)
   private
      bofirst       : Boolean;
      ChildList     : TList;
   protected
      procedure RangeAttack (targ: TCreature);
      procedure ResetLevel;
      procedure AttackAll(targ: TCreature);
   public
      constructor   Create;
      destructor    Destroy; override;
      procedure     RecalcAbilitys; override;
      function      AttackTarget: Boolean; override;
      procedure     Struck (hiter: TCreature); override;
      procedure     Run; override;
   end;

   // 용몸 ---------------------------------------------------------------------
   TDragonBody = class (TATMonster)
   private
      bofirst       : Boolean;
   protected
      procedure RangeAttack (targ: TCreature);
      procedure ResetLevel;

   public
      constructor   Create;
      procedure     RecalcAbilitys; override;
      function      AttackTarget: Boolean; override;
      procedure     Struck (hiter: TCreature); override;
      procedure     Run; override;
   end;

   // 용석상 -------------------------------------------------------------------
   TDragonStatue = class (TATMonster)
   private
      bofirst       : Boolean;
   protected
      procedure RangeAttack (targ: TCreature);
      procedure ResetLevel;
   public
      constructor   Create;
      destructor    Destroy; override;
      procedure     RecalcAbilitys; override;
      function      AttackTarget: Boolean; override;
      procedure     Run; override;
   end;


   TEyeProg = class (TATMonster)
   protected
      procedure     RangeAttack (targ: TCreature);
   public
      constructor   Create;
      function      AttackTarget: Boolean; override;
   end;

   TStoneSpider = class (TATMonster)
   protected
      procedure     RangeAttack (targ: TCreature);
   public
      constructor   Create;
      function      AttackTarget: Boolean; override;
   end;

   TGhostTiger = class (TMonster)
   private
      LastHideTime      : LongWord;
      LastSitDownTime   : LongWord;
      fSitDown          : Boolean;
      fHide             : Boolean;
      fEnableSitDown    : Boolean;
   protected
      procedure     RangeAttack (targ: TCreature);
   public
      constructor   Create;
      function      AttackTarget: Boolean; override;
      procedure     Run; override;
   end;

   TJumaThunder = class (TScultureMonster)
   protected
      procedure     RangeAttack (targ: TCreature);
   public
      constructor   Create;
      function      AttackTarget: Boolean; override;
   end;

   //수퍼오마(텔레포트,크리티컬)
   TSuperOma = class (TATMonster)
   private
   protected
   public
      RecentAttackTime: integer;
      TeleInterval: integer;
      criticalpoint: integer;
      TargetTime: longword;
      OldTargetCret: TCreature;
      constructor Create;
      function  AttackTarget: Boolean; override;
      procedure Attack (target: TCreature; dir: byte); override;
   end;

   TTogetherOma = class (TATMonster)
   private
   protected
   public
      RecentAttackTime: integer;
      TargetTime: longword;
      OldTargetCret: TCreature;
      SameRaceCount: integer;
      constructor Create;
      procedure Initialize; override;
      function  AttackTarget: Boolean; override;
      procedure Attack (target: TCreature; dir: byte); override;
   end;

   //여우시리즈-------------------------------------------------------------------
   //비월여우(전사) 비월흑호
   TFoxWarrior = class (TATMonster)
   private
      CrazyKingMode: Boolean;
      CriticalMode: Boolean;
      CrazyTime: longword;
      oldhittime: integer;
      oldwalktime: integer;
   public
      constructor Create;
      procedure Initialize; override;
      procedure Attack (target: TCreature; dir: byte); override;
      procedure Run; override;
      function  AttackTarget: Boolean; override;
   end;

   //비월여우(술사) 비월적호
   TFoxWizard = class (TATMonster)
   private
      WarpTime: longword;
   public
      constructor Create;
      procedure Initialize; override;
      procedure Attack (target: TCreature; dir: byte); override;
      procedure RangeAttack (targ: TCreature);
      procedure Run; override;
      procedure RunMsg (msg: TMessageInfo); override;
      function  AttackTarget: Boolean; override;
   end;

   //비월여우(도사) 비월소호
   TFoxTaoist = class (TATMonster)
   private
      BoRecallComplete: Boolean;
   public
      constructor Create;
      procedure Initialize; override;
      procedure Attack (target: TCreature; dir: byte); override;
      procedure RangeAttack (targ: TCreature);
      procedure RangeAttack2 (targ: TCreature);
      procedure Run; override;
      function  AttackTarget: Boolean; override;
   end;

   //호기연, 호기옥
   TPushedMon = class (TATMonster)
   private
      DeathCount: integer;
   public
      AttackWide: integer;
      constructor Create;
      procedure Initialize; override;
      procedure Attack (target: TCreature; dir: byte); override;
      procedure Run; override;
      procedure RunMsg (msg: TMessageInfo); override;
      procedure Struck (hiter: TCreature); override;
      function  AttackTarget: Boolean; override;
   end;

   //호혼기석
   TFoxPillar = class (TATMonster)
   private
   protected
      RunDone: Boolean;
      function  AttackTarget: Boolean; override;
      function  FindTarget: Boolean;
   public
      constructor Create;
      procedure RangeAttack (targ: TCreature);
      procedure Attack (target: TCreature; dir: byte); override;
   end;

   //비월천주
   TFoxBead = class (TATMonster)
   protected
      RunDone: Boolean;
   public
      TargetTime: longword;
      RangeAttackTime: longword;
      OldTargetCret: TCreature;
      OrgNextHitTime: integer;
      sectick: longword;
      constructor Create;
      procedure Run; override;
      function  AttackTarget: Boolean; override;
      function  FindTarget: Boolean;
      procedure RangeAttack (targ: TCreature);
      procedure RangeAttack2 (targ: TCreature);
      procedure Attack (target: TCreature; dir: byte); override;
      procedure Die; override;
   end;

   //거북왕
   TBossTurtle = class (TATMonster)
   protected
   public
      RecallStep: integer;
      constructor Create;
      function  AttackTarget: Boolean; override;
      function  FindTarget: Boolean;
      procedure RangeAttack (targ: TCreature);
      procedure RangeAttack2 (targ: TCreature);
      procedure Attack (target: TCreature; dir: byte); override;
   end;
implementation

uses
   svMain, M2Share;

{---------------------------------------------------------------------------}
//천녀(월령):  소환수

constructor TAngelMon.Create;
begin
   inherited Create;

   bofirst := TRUE;
   HideMode := TRUE;
   RaceServer := RC_ANGEL;
   ViewRange := 10;

end;

destructor TAngelMon.Destroy;
begin
    inherited Destroy;

end;


procedure TAngelMon.RecalcAbilitys;
begin
   BeforeRecalcAbility;
   inherited RecalcAbilitys;
//   AfterRecalcAbility;   //지원 마법시 딜레이 버그 수정
//   ResetLevel;   //지원 마법을 쓰면 에너지 차는 버그 수정(20031216)
end;

procedure TAngelMon.BeforeRecalcAbility;
begin
   case SlaveMakeLevel of
   1 :
    begin
        Abil.MaxHP := 200;
        Abil.AC := MakeWord(4, 5);
        Abil.MC := MakeWord(11, 20);
    end;
   2 :
    begin
        Abil.MaxHP := 300;
        Abil.AC := MakeWord(5, 6);
        Abil.MC := MakeWord(13, 23);
    end;
   3 :
    begin
        Abil.MaxHP := 450;
        Abil.AC := MakeWord(6, 9);
        Abil.MC := MakeWord(18, 28);
    end;
   else
    begin
        Abil.MaxHP := 150;
        Abil.AC := MakeWord(4, 4);
        Abil.MC := MakeWord(10, 18);
    end;

   end;

   Abil.MAC := MakeWord(4, 4);
   AddAbil.HP := 0;
end;

procedure TAngelMon.AfterRecalcAbility;
begin

   NextHitTime  := 3100 - (SlaveMakeLevel * 300);
   NextWalkTime := 600 - (SlaveMakeLevel * 50);
   WalkTime     := GetCurrentTime + 2000;

end;

procedure TAngelMon.ResetLevel;
begin
    //처음 초기화 되는부분...
    WAbil.HP    := WAbil.MaxHP;

end;

procedure TAngelMon.RangeAttackTo (targ: TCreature); //반드시 target <> nil

    function GetPower1 (power, trainrate: integer): integer;
    begin
       Result := Round ((10 + trainrate * 0.9) * (power / 100));
    end;

    function  CalcMagicPower: integer;
    begin
        Result := 8  + Random( 20);
    end;

var
   i, pwr, dam: integer;
begin
   if targ = nil then exit;

   if IsProperTarget (Targ) then begin

      Self.Dir := GetNextDirection (CX, CY, targ.CX, targ.CY);
      SendRefMsg (RM_LIGHTING, self.Dir, CX, CY, Integer(targ), '');

      pwr := GetAttackPower (
                GetPower1 (CalcMagicPower,0) + Lobyte(WAbil.MC),
                SmallInt(Hibyte(WAbil.MC)-Lobyte(WAbil.MC)) + 1 );

      if targ.LifeAttrib = LA_UNDEAD then  pwr := Round (pwr * 1.5);


      dam := targ.GetMagStruckDamage (self, pwr);

      if dam > 0 then begin
         Targ.StruckDamage (dam, self);
         Targ.SendDelayMsg (TCreature(RM_STRUCK), RM_REFMESSAGE, dam,
                            targ.WAbil.HP, targ.WAbil.MaxHP, Longint(self), '', 800);
      end;

   end;
end;

function TAngelMon.AttackTarget: Boolean;
var
   targdir: byte;
begin
   Result := FALSE;

   if (TargetCret <> nil) and (Master <> nil) and (TargetCret <> Master) then begin
      if GetCurrentTime - HitTime > GetNextHitTime then begin
         HitTime := GetCurrentTime;

         if (abs(CX-TargetCret.CX) <= ViewRange) and (abs(CY-TargetCret.CY) <= ViewRange) and (not TargetCret.death)then begin
            RangeAttackTo (TargetCret);
            Result := TRUE;
         end;
      end;
   end;

//   LoseTarget;
   BoLoseTargetMoment := TRUE;  //sonmg

end;

procedure TAngelMon.Run;
var
   i: integer;
begin
try

   if bofirst then begin
      bofirst := FALSE;
      Dir := 5;
      HideMode := FALSE;
      SendRefMsg (RM_DIGUP, Dir, CX, CY, 0, '');
      RecalcAbilitys;
      AfterRecalcAbility;  // 지원 마법시 딜레이 버그 수정
      ResetLevel;
   end;

   inherited Run;

except
    MainOutMessage('EXCEPTION TANGEL');
end;

end;


{---------------------------------------------------------------------------}
//분신:  소환수


constructor TCloneMon.Create;
begin
   inherited Create;
   bofirst      := TRUE;
   HideMode     := FALSE;
   RaceServer   := RC_CLONE;
   ViewRange    := 10;
end;

destructor TCloneMon.Destroy;
begin
   inherited Destroy;
end;

procedure TCloneMon.RecalcAbilitys;
begin
   BeforeRecalcAbility;
   inherited RecalcAbilitys;
//   AfterRecalcAbility;   //지원 마법시 딜레이 버그 수정
end;

procedure TCloneMon.BeforeRecalcAbility;
begin
   case SlaveMakeLevel of
   1 :
      begin
         Abil.MC := MakeWord(10, 22);
      end;
   2 :
      begin
         Abil.MC := MakeWord(13, 25);
      end;
   3 :
      begin
         Abil.MC := MakeWord(15, 30);
      end;
   else
      begin
         Abil.MC := MakeWord(9, 20);
      end;
   end;

   AddAbil.HP := 0;
end;

procedure TCloneMon.AfterRecalcAbility;
begin
   NextHitTime  := 3300 - (SlaveMakeLevel * 300);
   NextWalkTime := 500;
   WalkTime     := GetCurrentTime + 2000;
   NextMPSpendTime := GetTickCount;
//   MPSpendTickTime := 600;
   MPSpendTickTime := 600 * 30;

   if Master <> nil then begin
      WAbil.MaxHP  := Master.WAbil.MaxHP;
      WAbil.HP     := Master.WAbil.HP;
      WAbil.AC     := MakeWord( LOBYTE(master.Abil.AC)*2 div  3, HIBYTE(master.Abil.AC) *2 div  3);
      WAbil.MAC    := MakeWord( LOBYTE(master.Abil.MAC)*2 div 3, HIBYTE(master.Abil.MAC) *2 div 3);
//      MPSpendTickTime := ( 600 - _MIN(400, Master.WAbil.Level * 10) );
   end;
end;

procedure TCloneMon.ResetLevel;
begin
   //처음만초기화되는부분...
end;

procedure TCloneMon.RangeAttackTo (targ: TCreature); //반드시 target <> nil

   function GetPower1 (power, trainrate: integer): integer;
   begin
      Result := Round ((10 + trainrate * 0.9) * (power / 100));
   end;

   function  CalcMagicPow: integer;
   begin
      Result := 8 + random(20);
   end;

var
   i, pwr, dam: integer;
   sx, sy, tx, ty : integer;
   list: TList;
   cret: TCreature;
begin
   if targ = nil then exit;

   if IsProperTarget (targ) then begin
      if targ.AntiMagic <= Random(50) then begin
          pwr := GetAttackPower (
                      GetPower1 (CalcMagicPow,0) + Lobyte(WAbil.MC),
                      SmallInt(Hibyte(WAbil.MC)-Lobyte(WAbil.MC)) + 1
                   );

         if targ.LifeAttrib = LA_UNDEAD then pwr := Round (pwr * 1.5);

         SendDelayMsg (self, RM_DELAYMAGIC, pwr, MakeLong(Targ.CX, Targ.CY), 2, integer(targ), '', 600);
         SendRefMsg (RM_MAGICFIRE, 0, MakeWord(7, 9), MakeLong(Targ.CX, Targ.CY), integer(targ), '');

      end;

   end;

end;

function TCloneMon.AttackTarget: Boolean;
var
   targdir: byte;
begin
   Result := FALSE;

   if (TargetCret <> nil) and (Master <> nil) and (TargetCret <> Master) then begin
      if GetCurrentTime - HitTime > GetNextHitTime then begin
         HitTime := GetCurrentTime;

         if (abs(CX-TargetCret.CX) <= ViewRange) and (abs(CY-TargetCret.CY) <= ViewRange) and (not TargetCret.death)then begin
            if IsProperTarget (TargetCret) then begin
               //마법 준비동작을 먼저 보냄
               SendRefMsg (RM_SPELL, 9, TargetCret.CX, TargetCret.CY, 11, ''); // 강격이미지
               RangeAttackTo (TargetCret);
               Result := TRUE;
            end;
         end;

      end;
   end;

//   LoseTarget;
   BoLoseTargetMoment := TRUE;  //sonmg

end;

procedure TCloneMon.Run;
var
   i: integer;
   plus, finalplus : integer;
begin
   plus := 0;
   try
      if bofirst then begin
         bofirst := FALSE;
         Dir := 5;
         HideMode := FALSE;
         SendRefMsg (RM_DIGUP, Dir, CX, CY, 0, '');
         RecalcAbilitys;
         AfterRecalcAbility;   //지원 마법시 딜레이 버그 수정
         ResetLevel;
      end;

      if Death then begin  //분신은 시체가 없다.
         if GetTickCount - DeathTime > 1500 then begin
            MakeGhost(8);
         end;
      end else begin

         if ( not BoDisapear )     and
            ( not BoGhost    )     and
            ( self.WAbil.HP > 0  ) and
            ( Master <> nil      ) and
            ( not Master.BoGhost ) and
            ( not Master.death   ) then begin

            // 마력이 회복되지 않게 한다.(sonmg 2005/02/15)
            Master.SpellTick := 0;
            // 분신에게 주인의 체력을 보강해준다.(sonmg 2005/03/09)
            Self.WAbil.HP := Master.WAbil.HP;

            if Master.WAbil.MP < 200 then begin
               // MP 가 200 보다 작으면 자동사라짐
               {$IFDEF KOREA} Master.SysMsg('마력저하로 분신이 소멸했습니다.',0);
               {$ELSE}        Master.SysMsg('Your clone is destroyed due to lack of MP.',0);
               {$ENDIF}
               Self.BoDisapear := true;
               self.WAbil.HP := 0;
            end;

            if (GetTickCount >= NextMPSpendTime + MPSpendTickTime) then begin
               NextMPSpendTime := GetTickCount;

               if Master.wabil.MP >= 200{170} then begin
//                  Self.WAbil.HP := Master.WAbil.HP;
//                  Master.WAbil.MP := Master.WAbil.MP - ( 1 + SlaveMakeLevel div 2 );
                  //----------------------------------------------------------
                  // 분신이 소환되었을 경우 마력 차는 공식 별도 적용
                  // 캐릭의 마력 공식이 변경되면 이 부분도 변경되어야 함.
                  plus := Master.WAbil.MaxMP div 18 + 1;
                  finalplus := - ((1 + SlaveMakeLevel div 2 ) * 64) + plus + ((plus * Master.SpellRecover) div 10);
                  // 더해지는 값이 양수인지 음수인지에 따라 구분
                  if finalplus >= 0 then begin
                     if Master.WAbil.MP + finalplus > Master.WAbil.MaxMP then
                        Master.WAbil.MP := Master.WAbil.MaxMP
                     else
                        Master.WAbil.MP := Master.WAbil.MP + finalplus;
                  end else begin
                     if Master.WAbil.MP < - finalplus then
                        Master.WAbil.MP := 0
                     else
                        Master.WAbil.MP := Master.WAbil.MP + finalplus;
                  end;
                  //----------------------------------------------------------
(*
               end else begin
                  // MP 가 200 보다 작으면 자동사라짐
                  {$IFDEF KOREA} Master.SysMsg('마력저하로 분신이 소멸했습니다.',0)
                  {$ELSE}        Master.SysMsg('Your clone is destroyed due to lack of MP.',0);
                  {$ENDIF}
                  Self.BoDisapear := true;
                  self.WAbil.HP := 0;
*)
               end;

               // 분신에서 수동으로 마력을 Refresh 시켜준다.(sonmg 2005/02/15)
               Master.HealthSpellChanged;

            end;

         end else begin
            Self.WAbil.HP := 0;
         end;

      end;

      inherited Run;
   except
      MainOutMessage('EXCEPT TCLONE');
   end;

end;

//==============================================================================
constructor TDragon.Create;
var
   pdefm: PTDefMagic;

begin
   inherited Create;
   bofirst := TRUE;
   HideMode := TRUE;
   RaceServer := RC_FIREDRAGON;
   ViewRange := 12;
   BoWalkWaitMode := TRUE;
   BoDontMove  := TRUE;

   ChildList := TList.Create;
end;

destructor TDragon.Destroy;
var
   mon : TCreature;
   i   : integer;
begin
   if ChildList <> nil then begin
      for i := ChildList.Count -1 downto 0 do begin
         mon := TCreature ( ChildList[0]);
         mon.Wabil.HP := 0;
         ChildList.Delete(0);
      end;
      ChildList.Free;
   end;

   inherited Destroy;
end;


procedure TDragon.RecalcAbilitys;
begin
   inherited RecalcAbilitys;
   ResetLevel;
end;

procedure TDragon.ResetLevel;
const
    bodypos : array[0..41,0..1] of integer = (
                              ( 0,-5),( 1,-5),
                     ( -1,-4),( 0,-4),( 1,-4),( 2,-4),
            ( -2,-3),( -1,-3),( 0,-3),( 1,-3),( 2,-3),
    (-3,-2),( -2,-2),( -1,-3),( 0,-2),( 1,-2),( 2,-2),
    (-3,-1),( -2,-1),( -1,-1),( 0,-1),( 1,-1),( 2,-1),
    (-3, 0),( -2, 0),( -1, 0),( 0, 0),( 1, 0),( 2, 0),( 3,0),
            ( -2, 1),( -1, 1),( 0, 1),( 1, 1),( 2, 1),( 3,1),
                     ( -1, 2),( 0, 2),( 1, 2),( 2, 2),
                              ( 0, 3),( 1, 3) );

var
   mon : TCreature;
   i,j : integer;
begin

   if pEnvir <> nil then begin

      for  i := 0 to 41 do begin
         if ( bodypos[i][0] <> 0 ) or( bodypos[i][1] <> 0 ) then begin
            // 파천마룡몸이 00
            mon := UserEngine.AddCreatureSysop (pEnvir.MapName, CX+bodypos[i][0], CY+bodypos[i][1], '00');
            if mon <> nil then begin
               childlist.Add (mon);
            end;
         end; //if  i <> cx
      end; // for i

   end;

end;

procedure TDragon.RangeAttack (targ: TCreature); //반드시 target <> nil

   function  MPow (pum: PTUserMagic): integer;
   begin
      Result := pum.pDef.MinPower + Random(pum.pDef.MaxPower - pum.pDef.MinPower);
   end;

var
   i, pwr, dam: integer;
   sx, sy, tx, ty ,TempDir: integer;
   ix,iy,ixf , iyf ,ixt , iyt: integer;
   cret : TCreature;
   list : TList;
begin
   if targ = nil then exit;

   TempDir := GetNextDirection (CX, CY, targ.CX, targ.CY);

   case TempDir of
   0,1,6,7: SendRefMsg (RM_DRAGON_FIRE3, TempDir, CX, CY, Integer(targ), '');
   5  : SendRefMsg (RM_DRAGON_FIRE2, TempDir, CX, CY, Integer(targ), '');
   2,3,4: SendRefMsg (RM_DRAGON_FIRE1, TempDir, CX, CY, Integer(targ), '');
   end;

   with WAbil do begin
      pwr := random ( Hibyte(Wabil.DC) ) + LoByte(Wabil.DC) + random( Lobyte(WAbil.MC)) ;
      pwr := pwr * (random(2)+1);
   end;

   if targ.LifeAttrib = LA_UNDEAD then
      pwr := Round (pwr * 1.5);



   ixf := _MAX(0, Targ.CX - 2); ixt := _MIN(pEnvir.MapWidth-1,  Targ.CX + 2);
   iyf := _MAX(0, Targ.CY - 2); iyt := _MIN(pEnvir.MapHeight-1, Targ.CY + 2);

   for ix := ixf to ixt do begin
      for iy := iyf to iyt do begin
         list := TList.Create;
         PEnvir.GetAllCreature (ix, iy, TRUE, list);
         for i:=0 to list.Count-1 do begin
            cret := TCreature(list[i]);
            if IsProperTarget (cret) then begin
               dam := cret.GetMagStruckDamage (self, pwr);

               if cret.LifeAttrib = LA_UNDEAD then
                  pwr := Round (pwr * 1.5);

               if dam > 0 then begin
                  cret.StruckDamage (dam, self);
                  cret.SendDelayMsg (TCreature(RM_STRUCK), RM_REFMESSAGE, dam{wparam},
                                     cret.WAbil.HP{lparam1}, cret.WAbil.MaxHP{lparam2}, Longint(self){hiter}, '',
                                     600 + _MAX(Abs(CX-cret.CX),Abs(CY-cret.CY)) * 70);
               end;
            end;
         end;
         list.Free;
      end;
   end;


end;

procedure TDragon.AttackAll(Targ:TCreature); //반드시 target <> nil

   function  MPow (pum: PTUserMagic): integer;
   begin
      Result := pum.pDef.MinPower + Random(pum.pDef.MaxPower - pum.pDef.MinPower);
   end;

var
   ix, iy, ixf, ixt, iyf, iyt, dam , pwr,i: integer;
   list: TList;
   cret: TCreature;
begin
   if targ = nil then exit;

   SendRefMsg (RM_LIGHTING, Self.Dir, CX, CY, Integer(self), '');
   with WAbil do begin
      pwr := random ( Hibyte(Wabil.DC) ) + LoByte(Wabil.DC) + random( Lobyte(WAbil.MC)) ;
      pwr := pwr * (random(5)+1);
   end;

   ixf := _MAX(0, targ.CX - 10); ixt := _MIN(pEnvir.MapWidth-1,  targ.CX + 10);
   iyf := _MAX(0, targ.CY - 10); iyt := _MIN(pEnvir.MapHeight-1, targ.CY + 10);

   for ix := ixf to ixt do begin
      for iy := iyf to iyt do begin
         list := TList.Create;
         PEnvir.GetAllCreature (ix, iy, TRUE, list);
         for i:=0 to list.Count-1 do begin
            cret := TCreature(list[i]);
            if IsProperTarget (cret) then begin
               dam := cret.GetMagStruckDamage (self, pwr);

               if cret.LifeAttrib = LA_UNDEAD then
                  pwr := Round (pwr * 1.5);

               if dam > 0 then begin
                  cret.StruckDamage (dam, self);
                  cret.SendDelayMsg (TCreature(RM_STRUCK), RM_REFMESSAGE, dam{wparam},
                                     cret.WAbil.HP{lparam1}, cret.WAbil.MaxHP{lparam2}, Longint(self){hiter}, '',
                                     600 );
               end;
            end;
         end;
         list.Free;
      end;
   end;

end;

function  TDragon.AttackTarget: Boolean;
var
   targdir: byte;
begin
   Result := FALSE;
   if (TargetCret <> nil) and ( TargetCret <> Master ) then begin

      if GetCurrentTime - HitTime > GetNextHitTime then begin
         HitTime := GetCurrentTime;

         if (abs(CX-TargetCret.CX) <= ViewRange) and
               (abs(CY-TargetCret.CY) <= ViewRange) and
               ( not TargetCret.death ) and
               ( not TargetCret.boghost )then begin
            if Random(5) = 0 then
               AttackAll(TargetCret)   //모두공격
            else
               RangeAttack (TargetCret);
            Result := TRUE;
         end;

         LoseTarget;  //<!!주의> TargetCret := nil로 바뀜
      end;

   end;
end;

procedure TDragon.Struck (hiter: TCreature);
begin
    inherited;
    if hiter <> nil then
    begin
        // 파천마룡은 범위가 8 이하일경우에만 경험치를 증가시킨다.
        // 멀리서 얍삽하게 공격하는 술사 방지
        if ( ABS( hiter.CX - CX ) <= 8) and ( ABS ( hiter.CY - CY ) <= 8) then
        begin
           SendMsg( self , RM_DRAGON_EXP , 0, Random(3)+1 , 0,0,'');
        end;
    end;
end;

procedure TDragon.Run;
var
   i: integer;
begin
   if bofirst then begin
      bofirst := FALSE;
      Dir := 5;
      HideMode := FALSE;
      SendRefMsg (RM_DIGUP, Dir, CX, CY, 0, '');
      ResetLevel;
   end;
   inherited Run;
end;

//==============================================================================
constructor TDragonBody.Create;
begin
   inherited Create;
   bofirst := TRUE;
   HideMode := TRUE;
   RaceServer := RC_DRAGONBODY;
   ViewRange := 0;
   BoWalkWaitMode := TRUE;
   BoDontMove  := TRUE;

end;



procedure TDragonBody.RecalcAbilitys;
begin
   inherited RecalcAbilitys;
   ResetLevel;
end;

procedure TDragonBody.ResetLevel;
begin
end;

function  TDragonBody.AttackTarget: Boolean;
begin
    Result := FALSE;
end;

procedure TDragonBody.RangeAttack (targ: TCreature);
begin
end;

procedure TDragonBody.Struck (hiter: TCreature);
begin
   if hiter <> nil then begin
      // 파천마룡의 몸은 범위가 8 이하일경우에만 경험치를 증가시킨다.
      // 멀리서 얍삽하게 공격하는 술사 방지
      if ( ABS( hiter.CX - CX ) <= 8) and ( ABS ( hiter.CY - CY ) <= 8) then begin
         SendMsg( self , RM_DRAGON_EXP , 0, Random(3)+1 , 0,0,'');
      end;
   end;
   inherited;
end;

procedure TDragonBody.Run;
var
   i: integer;
begin
   if bofirst then begin
      bofirst := FALSE;
      Dir := 5;
      HideMode := FALSE;
      SendRefMsg (RM_DIGUP, Dir, CX, CY, 0, '');
      ResetLevel;
   end;
   inherited Run;
end;

//==============================================================================
constructor TDragonStatue.Create;
begin
   inherited Create;
   bofirst := TRUE;
   HideMode := TRUE;
   RaceServer := RC_DRAGONSTATUE;
   ViewRange := 12;
   BoWalkWaitMode := TRUE;
   BoDontMove  := TRUE;
end;

destructor TDragonStatue.Destroy;
begin
    inherited Destroy;
end;


procedure TDragonStatue.RecalcAbilitys;
begin
   inherited RecalcAbilitys;
   ResetLevel;
end;

procedure TDragonStatue.ResetLevel;
begin

end;

procedure TDragonStatue.RangeAttack (targ: TCreature); //반드시 target <> nil

   function  MPow (pum: PTUserMagic): integer;
   begin
      Result := pum.pDef.MinPower + Random(pum.pDef.MaxPower - pum.pDef.MinPower);
   end;

var
   i, pwr, dam: integer;
   sx, sy, tx, ty : integer;
   ix,iy,ixf , iyf ,ixt , iyt: integer;
   cret : TCreature;
   list : TList;

begin
   if targ = nil then exit;

   SendRefMsg (RM_LIGHTING, Self.Dir, CX, CY, Integer(targ), '');

   with WAbil do begin
      pwr := random ( Hibyte(Wabil.DC) ) + LoByte(Wabil.DC) + random( Lobyte(WAbil.MC)) ;
   end;


   ixf := _MAX(0, Targ.CX - 2); ixt := _MIN(pEnvir.MapWidth-1,  Targ.CX + 2);
   iyf := _MAX(0, Targ.CY - 2); iyt := _MIN(pEnvir.MapHeight-1, Targ.CY + 2);

   for ix := ixf to ixt do begin
      for iy := iyf to iyt do begin
         list := TList.Create;
         PEnvir.GetAllCreature (ix, iy, TRUE, list);
         for i:=0 to list.Count-1 do begin
            cret := TCreature(list[i]);
            if IsProperTarget (cret) then begin
               dam := cret.GetMagStruckDamage (self, pwr);

               if cret.LifeAttrib = LA_UNDEAD then
                  pwr := Round (pwr * 1.5);

               if dam > 0 then begin
                  cret.StruckDamage (dam, self);
                  cret.SendDelayMsg (TCreature(RM_STRUCK), RM_REFMESSAGE, dam{wparam},
                                     cret.WAbil.HP{lparam1}, cret.WAbil.MaxHP{lparam2}, Longint(self){hiter}, '',
                                     600 + _MAX(Abs(CX-cret.CX),Abs(CY-cret.CY)) * 50);
               end;
            end;
         end;
         list.Free;
      end;
   end;

end;

function  TDragonStatue.AttackTarget: Boolean;
var
   targdir: byte;
begin
   Result := FALSE;
   if (TargetCret <> nil) and ( TargetCret <> Master )then begin
      if GetCurrentTime - HitTime > GetNextHitTime then begin
         HitTime := GetCurrentTime;

         if (abs(CX-TargetCret.CX) <= ViewRange) and
               (abs(CY-TargetCret.CY) <= ViewRange) and
               ( not TargetCret.death ) and
               ( not TargetCret.BoGhost ) then begin
            RangeAttack (TargetCret);

            Result := TRUE;
         end;

         LoseTarget;  //<!!주의> TargetCret := nil로 바뀜
      end;
   end;
end;

procedure TDragonStatue.Run;
var
   i: integer;
begin
   if bofirst then begin
      bofirst := FALSE;
      Dir := 5;
      HideMode := FALSE;
      SendRefMsg (RM_DIGUP, Dir, CX, CY, 0, '');
      ResetLevel;
   end;
   inherited Run;
end;

//==============================================================================
constructor TEyeProg.Create;
begin
   inherited Create;
   SearchRate := 1500 + longword(Random(1500));
   ViewRange := 11;
end;

procedure TEyeProg.RangeAttack (targ: TCreature);
var
   levelgap  ,rush , rushdir , rushDist: integer;
begin
    // 멀리있는 적을 끌어당긴다.
   Self.Dir := GetNextDirection (CX, CY, targ.CX, targ.CY);
   SendRefMsg (RM_LIGHTING, self.Dir, CX, CY, Integer(targ), '');

   rushDir := ( (Self.Dir + 4) mod 8 );
   rushDist := _MIN( abs( CX - targ.CX) , abs( CY -targ.CY ) );

   if IsProperTarget (targ) then begin
      if (not targ.Death) and ((targ.RaceServer = RC_USERHUMAN) or (targ.Master <> nil)) then begin
         levelgap := (targ.AntiMagic*5)+HIBYTE(targ.Wabil.AC) div 2  ;
         if (Random(40) > levelgap) then begin
            // 직선에 있는넘만 땡긴다.
            if ( CX = targ.CX ) or ( CY = targ.CY ) or ( abs (CX-targ.CX ) = abs (CY-targ.CY )) then begin
               rush := RushDist;
               targ.CharRushRush ( RushDir, rush , false );
            end;

            targ.MakePoison( POISON_DECHEALTH , 30 , random(10)+5 );
         end;
      end;
   end;

end;

function TEyeProg.AttackTarget: Boolean;
var
   targdir: byte;
begin
   Result := FALSE;

   // 근접해 일을때에는 근접 힘 공격을
   // 원거리 일때는 원거리 마법공격을 한다.
   if TargetCret <> nil then begin
      if GetCurrentTime - HitTime > GetNextHitTime then begin
         HitTime := GetCurrentTime;

         if (abs(CX-TargetCret.CX) <= 5) and (abs(CY-TargetCret.CY) <= 5) then begin
            if (TargetInAttackRange (TargetCret, targdir))then begin
               TargetFocusTime := GetTickCount;
               Attack (TargetCret, targdir);
               Result := TRUE;
            end else begin
               if Random(2) = 0 then begin
                  RangeAttack (TargetCret);
                  Result := TRUE;
               end else
                  result := inherited AttackTarget;
            end;
         end else begin
            if TargetCret.MapName = self.MapName then begin
               if (abs(CX-TargetCret.CX) <= ViewRange) and (abs(CY-TargetCret.CY) <= ViewRange) then begin
                  SetTargetXY (TargetCret.CX, TargetCret.CY)
               end;
            end else begin
               LoseTarget;  //<!!주의> TargetCret := nil로 바뀜
            end;
         end;

      end;
   end;

end;

//==============================================================================
constructor TStoneSpider.Create;
begin
   inherited Create;
   SearchRate := 1500 + longword(Random(1500));
   ViewRange := 11;
end;

procedure TStoneSpider.RangeAttack (targ: TCreature);
var

   i, pwr, dam: integer;
   sx, sy, tx, ty : integer;
   cret: TCreature;
   ndir  : integer;
begin
    // 뢰인장 쓰자
   Self.Dir := GetNextDirection (CX, CY, targ.CX, targ.CY);
   SendRefMsg (RM_LIGHTING, self.Dir, CX, CY, Integer(targ), '');

    with WAbil do
       pwr := _MAX( 0, Lobyte(DC) + Random(SmallInt(Hibyte(DC)-Lobyte(DC)) + 1) );

   nDir := self.dir ;
   GetNextPosition (PEnvir, Cx, Cy, ndir, 1, sx, sy);
   GetNextPosition (PEnvir, CX, CY, ndir, 8, tx, ty);

   for i:=0 to 12 do begin
      cret := TCreature (PEnvir.GetCreature (sx, sy, TRUE));
      if cret <> nil then begin
         if IsProperTarget (cret) then begin
            if ( random(18) > (cret.AntiMagic*3) ) then begin  //마법 회피가 있음
               dam := cret.GetMagStruckDamage (self, pwr);
               cret.SendDelayMsg (self, RM_MAGSTRUCK, 0, dam, 0, 0, '', 600);
            end;
         end;
      end;
      if not ((abs(sx-tx) <= 0) and (abs(sy-ty) <= 0)) then begin
         ndir := GetNextDirection (sx, sy, tx, ty);
         if not GetNextPosition (PEnvir, sx, sy, ndir, 1, sx, sy) then
            break;
      end else
         break;
   end;

end;

function TStoneSpider.AttackTarget: Boolean;
var
   targdir: byte;
begin
   Result := FALSE;
    // 근접해 일을때에는 근접 힘 공격을
    // 원거리 일때는 원거리 마법공격을 한다.

   if TargetCret <> nil then
   begin
      if GetCurrentTime - HitTime > GetNextHitTime then
      begin
         HitTime := GetCurrentTime;

         if (abs(CX-TargetCret.CX) <= ViewRange ) and (abs(CY-TargetCret.CY) <= ViewRange ) then
         begin
            if (TargetInAttackRange (TargetCret, targdir)) then
            begin
               TargetFocusTime := GetTickCount;
               Attack (TargetCret, targdir);

               //근접일때 독 걸리게...
               if random(3 ) = 0 then
               TargetCret.MakePoison( POISON_DECHEALTH , 30 , random(10)+5 );

               Result := TRUE;
            end else
            begin
               if Random(3)= 0 then
               begin
                   RangeAttack (TargetCret);
                   Result := TRUE;
               end
               else
               begin
                   result := Inherited AttackTarget;
               end;

            end;
         end
         else
         begin
            if TargetCret.MapName = self.MapName then
            begin
               if (abs(CX-TargetCret.CX) <= ViewRange) and (abs(CY-TargetCret.CY) <= ViewRange) then
               begin
                  SetTargetXY (TargetCret.CX, TargetCret.CY)
               end;
            end else begin
               LoseTarget;  //<!!주의> TargetCret := nil로 바뀜
            end;
         end;

      end;
   end;
end;

//==============================================================================
constructor TGhostTiger.Create;
begin
   inherited Create;
   SearchRate := 1500 + longword(Random(1500));
   LastHideTime     := GetTickCount + 10000;
   LastSitDownTime  := GetTickCount + 10000;
   fSitDown         := false;
   fHide            := false;
   fEnableSitDown   := false;
   ViewRange        := 11;
end;

procedure TGhostTiger.RangeAttack (targ: TCreature);
var

   i, pwr, dam: integer;
   sx, sy, tx, ty : integer;
   list: TList;
   cret: TCreature;
   slowtime : integer;

begin
    // 얼음쏘자
   Self.Dir := GetNextDirection (CX, CY, targ.CX, targ.CY);
   SendRefMsg (RM_LIGHTING, self.Dir, CX, CY, Integer(targ), '');

    with WAbil do
       pwr := _MAX( 0, Lobyte(DC) + Random(SmallInt(Hibyte(DC)-Lobyte(DC)) + 1) );

    list := TList.Create;
    GetMapCreatures ( PEnvir, targ.CX, targ.CY, 1, list);

    for i:=0 to list.Count-1 do
    begin
       cret := TCreature(list[i]);
       if IsProperTarget (cret) then
       begin

          if ( random(18) > (cret.AntiMagic*3) ) then
          begin

              dam := cret.GetMagStruckDamage (self, pwr);

              if ( cret <> targ) then dam := dam div 2;

              if dam > 0 then
              begin
                 cret.StruckDamage (dam, self);

                 slowtime := dam div 10;
                 if slowtime > 0 then
                 cret.MakePoison( POISON_SLOW , slowtime ,1 );

                 cret.SendDelayMsg (TCreature(RM_STRUCK), RM_REFMESSAGE, dam{wparam},
                                cret.WAbil.HP{lparam1}, cret.WAbil.MaxHP{lparam2}, Longint(self){hiter}, '', 800);
              end;
           end;
         end;
    end;

    list.Free;


end;

function TGhostTiger.AttackTarget: Boolean;
var
   targdir: byte;
begin
   Result := FALSE;
    // 근접해 일을때에는 근접 힘 공격을
    // 원거리 일때는 원거리 마법공격을 한다.

   if TargetCret <> nil then
   begin
      if GetCurrentTime - HitTime > GetNextHitTime then
      begin
         HitTime := GetCurrentTime;

         if (abs(CX-TargetCret.CX) <= ViewRange ) and (abs(CY-TargetCret.CY) <= ViewRange ) then
         begin
            if (TargetInAttackRange (TargetCret, targdir)) then
            begin
               TargetFocusTime := GetTickCount;
               Attack (TargetCret, targdir);
               if fSitDown = false then LastSitDownTime := GetTickCount + 10000;
               Result := TRUE;
            end else
            begin
               if Random(3)= 0 then
               begin
                   RangeAttack (TargetCret);
                   if fSitDown = false then LastSitDownTime := GetTickCount + 10000;
                   Result := TRUE;
               end
               else
               begin
                   result := Inherited AttackTarget;
               end;

            end;
         end
         else
         begin
            if TargetCret.MapName = self.MapName then
            begin
               if (abs(CX-TargetCret.CX) <= ViewRange) and (abs(CY-TargetCret.CY) <= ViewRange) then
               begin
                  SetTargetXY (TargetCret.CX, TargetCret.CY)
               end;
            end else begin
               LoseTarget;  //<!!주의> TargetCret := nil로 바뀜
            end;
         end;

      end;
   end;
end;

procedure TGhostTiger.Run;
begin

    if GetTickCount >= LastHideTime then
    begin
        if fHide then
        begin

            StatusArr[STATE_TRANSPARENT] := 0;
            LasthideTime := GetTickCount + LongWord(random ( 3000 )) + 9000;
            fHide := false;
        end
        else
        begin
            if ( not BoGhost ) and
               ( not death   ) then
            begin

            StatusArr[STATE_TRANSPARENT] := 60000;
            LasthideTime := GetTickCount + LongWord(random ( 3000 )) + 9000;
            fHide := true;

            end;
        end;

        CharStatus := GetCharStatus;
        CharStatusChanged;
    end;

    fenableSitDown := false;
    if master <> nil then
    begin
        if Master.BoSlaveRelax then   fenableSitDown := true;

        if not RunDone and IsMoveAble then
        begin
          if (GetTickCount - SearchEnemyTime > 8000) or ((GetTickCount - SearchEnemyTime > 1000) and (TargetCret = nil)) then
          begin
             SearchEnemyTime := GetTickCount;
             MonsterNormalAttack;
          end;
        end;

    end
    else
    begin
       if TargetX = -1 then fenableSitDown := true;
    end;

    if ( BoGhost ) or ( death   ) then fenableSitDown := false;

    if ( fenableSitDown or fSitDown ) and (LastSitDownTime < GetTickCount ) then
    begin
        if fSitDown then  // 앉아있다.
        begin
            SendRefMsg (RM_TURN, Dir, CX, CY, 0, '');
            LastSitDownTime := GetTickCount + LongWord(random( 5000)) + 15000;
            fSitDown := false;
            BoDontMove := false;
        end
        else    // 서있다.
        begin
            SendRefMsg (RM_DIGDOWN, Dir, CX, CY, 0, '');
            LastSitDownTime := GetTickCount + LongWord(random( 3000)) + 9000;
            fSitDown := true;
            BoDontMove := true;
        end;
    end;

    inherited run;
end;


//==============================================================================
constructor TJumaThunder.Create;
begin
   inherited Create;
   ViewRange := 11;
   MeltArea  := 5;
end;

procedure TJumaThunder.RangeAttack (targ: TCreature);
var

   i, pwr, dam: integer;
   sx, sy, tx, ty : integer;
   list: TList;
   cret: TCreature;

begin
    // 붉은 강격을 날린다.
   Self.Dir := GetNextDirection (CX, CY, targ.CX, targ.CY);
   SendRefMsg (RM_LIGHTING, self.Dir, CX, CY, Integer(targ), '');

    with WAbil do
       pwr := _MAX( 0, Lobyte(DC) + Random(SmallInt(Hibyte(DC)-Lobyte(DC)) + 1) );

    list := TList.Create;
    GetMapCreatures ( PEnvir, targ.CX, targ.CY, 1, list);

    for i:=0 to list.Count-1 do
    begin
       cret := TCreature(list[i]);
       if IsProperTarget (cret) then
       begin

          if ( random(18) > (cret.AntiMagic*3) ) then
          begin

              dam := cret.GetMagStruckDamage (self, pwr);

              if ( cret <> targ) then dam := dam div 2;

              if dam > 0 then
              begin
                 cret.StruckDamage (dam, self);
                 cret.SendDelayMsg (TCreature(RM_STRUCK), RM_REFMESSAGE, dam{wparam},
                                cret.WAbil.HP{lparam1}, cret.WAbil.MaxHP{lparam2}, Longint(self){hiter}, '', 800);
              end;
           end;
         end;
    end;

    list.Free;


end;

function TJumaThunder.AttackTarget: Boolean;
var
   targdir: byte;
begin
   Result := FALSE;
    // 근접해 일을때에는 근접 힘 공격을
    // 원거리 일때는 원거리 마법공격을 한다.

   if TargetCret <> nil then
   begin
      if GetCurrentTime - HitTime > GetNextHitTime then
      begin
         HitTime := GetCurrentTime;

         if (abs(CX-TargetCret.CX) <= ViewRange ) and (abs(CY-TargetCret.CY) <= ViewRange ) then
         begin
            if (TargetInAttackRange (TargetCret, targdir)) then
            begin
               TargetFocusTime := GetTickCount;
               Attack (TargetCret, targdir);
               Result := TRUE;
            end else
            begin
               if Random(3)= 0 then
               begin
                   RangeAttack (TargetCret);
                   Result := TRUE;
               end
               else
               begin
                   result := Inherited AttackTarget;
               end;

            end;
         end
         else
         begin
            if TargetCret.MapName = self.MapName then
            begin
               if (abs(CX-TargetCret.CX) <= ViewRange) and (abs(CY-TargetCret.CY) <= ViewRange) then
               begin
                  SetTargetXY (TargetCret.CX, TargetCret.CY)
               end;
            end else begin
               LoseTarget;  //<!!주의> TargetCret := nil로 바뀜
            end;
         end;

      end;
   end;
end;


//==============================================================================
//수퍼오마
constructor TSuperOma.Create;
begin
   RecentAttackTime := GetTickCount;
   TeleInterval := 10;  //sec
   criticalpoint := 0;
   TargetTime := GetTickCount;
   OldTargetCret := nil;
   inherited Create;
end;

function  TSuperOma.AttackTarget: Boolean;
var
   targdir: byte;
   nx, ny: integer;
begin
   Result := FALSE;

   if ( GetCurrentTime < LongInt( LongWord(Random(3000) + 4000) + TargetTime ) ) then begin
      if OldTargetCret <> nil then
         TargetCret := OldTargetCret;
   end;

   if TargetCret <> nil then begin
      OldTargetCret := TargetCret;
      if TargetInAttackRange (TargetCret, targdir) then begin
         if GetCurrentTime - HitTime > GetNextHitTime then begin
            HitTime := GetCurrentTime;
            TargetFocusTime := GetTickCount;
            RecentAttackTime := GetTickCount;
            Attack (TargetCret, targdir);
            BreakHolySeize;
         end;
         Result := TRUE;
      end else begin
         if GetCurrentTime - RecentAttackTime > (TeleInterval + Random(5)) * 1000 then begin
            if Random(2) = 0 then begin
               //타겟의 앞으로
               GetFrontPosition (TargetCret, nx, ny);
               //텔레포트
               SpaceMove( PEnvir.MapName, nx, ny, 0 );
               RecentAttackTime := GetTickCount;
            end;
         end else begin
            if TargetCret.MapName = self.MapName then
               SetTargetXY (TargetCret.CX, TargetCret.CY)
            else
               LoseTarget;  //<!!주의> TargetCret := nil로 바뀜
         end;
      end;
   end;
end;

procedure TSuperOma.Attack (target: TCreature; dir: byte);
var
   pwr: integer;
begin
   with WAbil do
      pwr := GetAttackPower (Lobyte(DC), SmallInt(Hibyte(DC)-Lobyte(DC)));
   Inc (criticalpoint);

   //마법 타격으로 되어있음.
   if (criticalpoint > 3) or (Random(20) = 0) then begin
      criticalpoint := 0;
      pwr := Round (pwr * 3);
      {inherited} HitHitEx2 (target, RM_LIGHTING, 0, pwr, TRUE);
   end else
      {inherited} HitHit2 (target, 0, pwr, TRUE);
end;

//==============================================================================
//뭉치면 강해지는 오마
constructor TTogetherOma.Create;
begin
   RecentAttackTime := GetTickCount;
   TargetTime := GetTickCount;
   OldTargetCret := nil;
   SameRaceCount := 0;
   inherited Create;
end;

procedure TTogetherOma.Initialize;
begin
   inherited Initialize;

   PlusPoisonFactor := 200;   //독에 200%의 데미지를 입음.
end;

function  TTogetherOma.AttackTarget: Boolean;
var
   targdir: byte;
   nx, ny: integer;
begin
   Result := FALSE;

   if ( GetCurrentTime < LongInt( LongWord(Random(3000) + 4000) + TargetTime ) ) then begin
      if OldTargetCret <> nil then
         TargetCret := OldTargetCret;
   end;

   if TargetCret <> nil then begin
      OldTargetCret := TargetCret;
      if TargetInAttackRange (TargetCret, targdir) then begin
         if GetCurrentTime - HitTime > GetNextHitTime then begin
            HitTime := GetCurrentTime;
            TargetFocusTime := GetTickCount;
            RecentAttackTime := GetTickCount;
            Attack (TargetCret, targdir);
            BreakHolySeize;
         end;
         Result := TRUE;
      end else begin
         if TargetCret.MapName = self.MapName then
            SetTargetXY (TargetCret.CX, TargetCret.CY)
         else
            LoseTarget;  //<!!주의> TargetCret := nil로 바뀜
      end;
   end;
end;

procedure TTogetherOma.Attack (target: TCreature; dir: byte);
var
   i: integer;
   rlist: TList;
   cret: TCreature;
   pwr, wide: integer;
   CriticalFact, DCFact: integer;
begin
   if target = nil then exit;

   DCFact := 0;
   CriticalFact := 0;
   SameRaceCount := 0;
   wide := 3;
   rlist := TList.Create;
   GetMapCreatures (PEnvir, CX, CY, wide, rlist);
   for i:=0 to rlist.Count-1 do begin
      cret := TCreature (rlist[i]);
      if not cret.BoGhost and not cret.Death then begin
         if cret.RaceServer = self.RaceServer then begin
            Inc(SameRaceCount);
         end;
      end;
   end;
   rlist.Free;

   //30마리로 제한
   SameRaceCount := _MIN(30, SameRaceCount);

   DCFact := SameRaceCount * 3;
   with WAbil do begin
      pwr := GetAttackPower (_MIN(255, Lobyte(DC) + DCFact), SmallInt(_MIN(255, Hibyte(DC) + DCFact)-_MIN(255, Lobyte(DC) + DCFact)));
   end;

   CriticalFact := SameRaceCount;
   if (Random(100) < 1 + CriticalFact) then begin
      //방어력 무시...
      pwr := pwr + Lobyte(target.WAbil.AC) + Random(Integer(Hibyte(target.WAbil.AC)-Lobyte(target.WAbil.AC)) + 1);
      {inherited} HitHitEx2 (target, RM_LIGHTING, pwr, 0, TRUE);
   end else
      {inherited} HitHit2 (target, pwr, 0, TRUE);
end;

{---------------------------------------------------------------------------}
// TFoxWarrior    비월여우(전사)

constructor TFoxWarrior.Create;
begin
   inherited Create;
   SearchRate := 2500 + longword(Random(1500));
   CrazyKingMode := FALSE;
   CriticalMode := FALSE;
end;

procedure TFoxWarrior.Initialize;
begin
   CrazyTime := GetTickCount;
   oldhittime := NextHitTime;
   oldwalktime := NextWalkTime;
   ViewRange := 7;

   inherited Initialize;
end;

procedure TFoxWarrior.Attack (target: TCreature; dir: byte);
var
   i, k,  mx, my, dam, armor: integer;
   cret: TCreature;
   pwr: integer;
begin
   self.Dir := dir;
   with WAbil do
      pwr := GetAttackPower (Lobyte(DC), SmallInt(Hibyte(DC)-Lobyte(DC)));

   if pwr <= 0 then exit;

   if CriticalMode then begin
      pwr := pwr * 2;
      SendRefMsg (RM_LIGHTING, self.Dir, CX, CY, Integer(target), '');
{$IFDEF DEBUG}
//UserEngine.CryCry (RM_CRY, PEnvir, CX, CY, 10000, ' Critical Attack : ' + TargetCret.UserName);//test
{$ENDIF}
   end else begin
      SendRefMsg (RM_HIT, self.Dir, CX, CY, Integer(target), '');
{$IFDEF DEBUG}
//UserEngine.CryCry (RM_CRY, PEnvir, CX, CY, 10000, ' Normal Attack : ' + TargetCret.UserName);//test
{$ENDIF}
   end;

   for i:=0 to 4 do
      for k:=0 to 4 do begin
         if SpitMap[dir, i, k] = 1 then begin
            mx := CX - 2 + k;
            my := CY - 2 + i;
            cret := TCreature (PEnvir.GetCreature (mx, my, TRUE));
            if (cret <> nil) and (cret <> self) then begin
               if IsProperTarget(cret) then begin
                  //맞는지 결정
                  if Random(cret.SpeedPoint) < AccuracyPoint then begin
                     cret.StruckDamage (pwr, self);
                     cret.SendDelayMsg (TCreature(RM_STRUCK), RM_REFMESSAGE, pwr{wparam},
                                        cret.WAbil.HP{lparam1}, cret.WAbil.MaxHP{lparam2}, Longint(self){hiter}, '',
                                        500 );
//                        {inherited} HitHit2 (cret, pwr, 0, TRUE);
                  end;
               end;
            end;
         end;
      end;
end;

procedure TFoxWarrior.Run;
var
   nn, nx, ny, old: integer;
   ncret: TCreature;
begin
   if not Death and not BoGhost then begin
      if CrazyKingMode then begin  //폭주
         if GetTickCount - CrazyTime < 60 * 1000 then begin
            NextHitTime := oldhittime * 2 div 5;
            NextWalkTime := oldwalktime * 1 div 2;
         end else begin
            CrazyKingMode := FALSE;
            NextHitTime := oldhittime;
            NextWalkTime := oldwalktime;
         end;
      end else begin
         if WAbil.HP < WAbil.MaxHP div 4 then begin
            CrazyKingMode := TRUE;
            CrazyTime := GetTickCount;
{$IFDEF DEBUG}
//UserEngine.CryCry (RM_CRY, PEnvir, CX, CY, 10000, ' CrazyKingMode : ' + TargetCret.UserName);//test
{$ENDIF}
         end;
      end;

   end;
   inherited Run;
end;

function TFoxWarrior.AttackTarget: Boolean;
var
   targdir: byte;
begin
   Result := FALSE;
   if TargetCret <> nil then begin
      if TargetInSpitRange (TargetCret, targdir) then begin
         if GetCurrentTime - HitTime > GetNextHitTime then begin
            HitTime := GetCurrentTime;
            TargetFocusTime := GetTickCount;
            if Random(100) < 20 then
               CriticalMode := TRUE
            else
               CriticalMode := FALSE;

            Attack (TargetCret, targdir);
            BreakHolySeize;
         end;
         Result := TRUE;
      end else begin
         if TargetCret.MapName = self.MapName then
            SetTargetXY (TargetCret.CX, TargetCret.CY)
         else
            LoseTarget;  //<!!주의> TargetCret := nil로 바뀜
      end;
   end;
end;

{---------------------------------------------------------------------------}
// TFoxWizard    비월여우(술사)

constructor TFoxWizard.Create;
begin
   inherited Create;
   SearchRate := 2500 + longword(Random(1500));
end;

procedure TFoxWizard.Initialize;
begin
   WarpTime := GetTickCount;
   ViewRange := 7;

   inherited Initialize;
end;

procedure TFoxWizard.Attack (target: TCreature; dir: byte);
var
   i, k,  mx, my, dam, armor: integer;
   wide: integer;
   rlist: TList;
   cret: TCreature;
   pwr: integer;
begin
   if target = nil then exit;

   wide := 0;
   Self.Dir := GetNextDirection (CX, CY, target.CX, target.CY);
   SendRefMsg (RM_LIGHTING, self.Dir, CX, CY, Integer(target), '');
   with WAbil do
      pwr := GetAttackPower (Lobyte(DC), SmallInt(Hibyte(DC)-Lobyte(DC)));
   if pwr <= 0 then exit;

   rlist := TList.Create;
   GetMapCreatures (PEnvir, target.CX, target.CY, wide, rlist);
   for i:=0 to rlist.Count-1 do begin
      cret := TCreature (rlist[i]);
      if IsProperTarget(cret) then begin
         SelectTarget (cret);
         cret.SendDelayMsg (self, RM_MAGSTRUCK, 0, pwr, 0, 0, '', 600);
      end;
   end;
   rlist.Free;

end;

procedure TFoxWizard.RangeAttack (targ: TCreature); //반드시 target <> nil
var
   i, pwr, dam: integer;
   sx, sy, tx, ty : integer;
   list: TList;
   cret: TCreature;
begin
   if targ = nil then exit;

   Self.Dir := GetNextDirection (CX, CY, targ.CX, targ.CY);
   SendRefMsg (RM_LIGHTING_1, self.Dir, CX, CY, Integer(targ), '');
   if GetNextPosition (PEnvir, CX, CY, dir, 1, sx, sy) then begin
      GetNextPosition (PEnvir, CX, CY, dir, 9, tx, ty);
      with WAbil do
         pwr := _MAX( 0, Lobyte(DC) + Random(SmallInt(Hibyte(DC)-Lobyte(DC)) + 1) );

      list := TList.Create;
      PEnvir.GetAllCreature (targ.CX, targ.CY, TRUE, list);
      for i:=0 to list.Count-1 do begin
         cret := TCreature(list[i]);
         if IsProperTarget(cret) then begin
            dam := cret.GetMagStruckDamage (self, pwr);
            if dam > 0 then begin
               cret.StruckDamage (dam, self);
               cret.SendDelayMsg (TCreature(RM_STRUCK), RM_REFMESSAGE, dam{wparam},
                                  cret.WAbil.HP{lparam1}, cret.WAbil.MaxHP{lparam2}, Longint(self){hiter}, '', 800);
            end;
         end;
      end;
      list.Free;
   end;
end;

procedure TFoxWizard.Run;
begin
   if not RunDone and IsMoveAble then begin
      if GetCurrentTime - WalkTime > GetNextWalkTime then begin
         //상속받은 run에서 WalkTime 재설정함
         if TargetCret <> nil then begin
            if (abs(CX-TargetCret.CX) <= 5) and (abs(CY-TargetCret.CY) <= 5) then begin
               if (abs(CX-TargetCret.CX) <= 2) and (abs(CY-TargetCret.CY) <= 2) then begin
                  //너무 가까우면, 잘 도망 안감.
                  if Random(3) = 0 then begin
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
   end;

   inherited Run;
end;

procedure TFoxWizard.RunMsg (msg: TMessageInfo);
var
   nx, ny: integer;
   monname: string;
   mon: TCreature;
begin
   case msg.Ident of
      RM_REFMESSAGE:
         begin
            if Integer(msg.Sender) = RM_STRUCK then begin
               if Random(100) < 30 then begin
                  //2초 딜레이
                  if (GetTickCount - WarpTime > 2000) and (not Death) then begin
                     WarpTime := GetTickCount;
                     //워프
                     SendRefMsg (RM_NORMALEFFECT, 0, CX, CY, NE_FOX_MOVEHIDE, '');
                     RandomSpaceMoveInRange(2, 4, 4);
                     SendRefMsg (RM_NORMALEFFECT, 0, CX, CY, NE_FOX_MOVESHOW, '');
                  end;
               end;
            end;
         end;
   end;
   inherited RunMsg (msg);
end;

function TFoxWizard.AttackTarget: Boolean;
var
   targdir: byte;
begin
   Result := FALSE;
   if TargetCret <> nil then begin
      if GetCurrentTime - HitTime > GetNextHitTime then begin
         HitTime := GetCurrentTime;
         if (abs(CX-TargetCret.CX) <= 7) and (abs(CY-TargetCret.CY) <= 7) then begin
            if Random(10) < 7 then begin
               //강격
               Attack( TargetCret, dir );
               Result := TRUE;
            end else if Random(10) < 6 then begin
               //폭열파
               RangeAttack( TargetCret );
               Result := TRUE;
            end;

         end else begin
            if TargetCret.MapName = self.MapName then begin
               if (abs(CX-TargetCret.CX) <= 11) and (abs(CY-TargetCret.CY) <= 11) then begin
                  SetTargetXY (TargetCret.CX, TargetCret.CY)
               end;
            end else begin
               LoseTarget;  //<!!주의> TargetCret := nil로 바뀜
            end;
         end;
      end;
   end;
end;

{---------------------------------------------------------------------------}
// TFoxTaoist    비월여우(도사)

constructor TFoxTaoist.Create;
begin
   inherited Create;
   SearchRate := 2500 + longword(Random(1500));
end;

procedure TFoxTaoist.Initialize;
begin
   BoRecallComplete := FALSE;
   ViewRange := 7;

   inherited Initialize;
end;

procedure TFoxTaoist.Attack (target: TCreature; dir: byte);
var
   pwr: integer;
begin
   self.Dir := dir;
   with WAbil do
      pwr := GetAttackPower (Lobyte(DC), SmallInt(Hibyte(DC)-Lobyte(DC)));

   if pwr <= 0 then exit;

   SendRefMsg (RM_HIT, self.Dir, CX, CY, Integer(target), '');

   if IsProperTarget(target) then begin
      target.StruckDamage (pwr, self);
      target.SendDelayMsg (TCreature(RM_STRUCK), RM_REFMESSAGE, pwr{wparam},
                         target.WAbil.HP{lparam1}, target.WAbil.MaxHP{lparam2}, Longint(self){hiter}, '',
                         500 );
   end;
end;

procedure TFoxTaoist.RangeAttack (targ: TCreature); //반드시 target <> nil
var
   i, pwr, dam: integer;
   sx, sy, tx, ty : integer;
   list: TList;
   cret: TCreature;
   sec, skilllevel: integer;
begin
   if targ = nil then exit;

   sec := 60;
   pwr := 70;
   skilllevel := 3;
   MagMakeCurseArea (targ.CX, targ.CY, 2, sec, pwr, skilllevel, FALSE);

   Self.Dir := GetNextDirection (CX, CY, targ.CX, targ.CY);
   SendRefMsg (RM_LIGHTING_1, self.Dir, CX, CY, Integer(targ), '');
end;

procedure TFoxTaoist.RangeAttack2 (targ: TCreature); //반드시 target <> nil
var
   i, pwr, dam: integer;
   sx, sy, tx, ty : integer;
   list: TList;
   cret: TCreature;
begin
   if targ = nil then exit;

   Self.Dir := GetNextDirection (CX, CY, targ.CX, targ.CY);
   SendRefMsg (RM_LIGHTING, self.Dir, CX, CY, Integer(targ), '');
   if GetNextPosition (PEnvir, CX, CY, dir, 1, sx, sy) then begin
      GetNextPosition (PEnvir, CX, CY, dir, 9, tx, ty);
      with WAbil do
         pwr := _MAX( 0, Lobyte(DC) + Random(SmallInt(Hibyte(DC)-Lobyte(DC)) + 1) );

      list := TList.Create;
      PEnvir.GetAllCreature (targ.CX, targ.CY, TRUE, list);
      for i:=0 to list.Count-1 do begin
         cret := TCreature(list[i]);
         if IsProperTarget (cret) then begin
            dam := cret.GetMagStruckDamage (self, pwr);
            if dam > 0 then begin
               cret.StruckDamage (dam, self);
               cret.SendDelayMsg (TCreature(RM_STRUCK), RM_REFMESSAGE, dam{wparam},
                                  cret.WAbil.HP{lparam1}, cret.WAbil.MaxHP{lparam2}, Longint(self){hiter}, '', 800);
            end;
         end;
      end;
      list.Free;
   end;
end;

procedure TFoxTaoist.Run;
var
   nx, ny: integer;
   cret: TCreature;
   recallmob1, recallmob2: string;
begin
   cret := nil;

   {$IFDEF KOREA}
      recallmob1 := '비월흑호';
      recallmob2 := '비월적호';
   {$ELSE}
      recallmob1 := 'BlackFoxFolks';
      recallmob2 := 'RedFoxFolks';
   {$ENDIF}

   if not BoRecallComplete then begin
      if WAbil.HP <= WAbil.MaxHP div 2 then begin
         SendRefMsg (RM_LIGHTING_2, self.Dir, CX, CY, Integer(TargetCret), '');
         //소환
         cret := UserEngine.AddCreatureSysop (PEnvir.MapName, CX+1, CY, recallmob1);
         if cret <> nil then begin
            cret.SendRefMsg (RM_NORMALEFFECT, 0, cret.CX, cret.CY, NE_FOX_MOVESHOW, '');
         end;
         cret := UserEngine.AddCreatureSysop (PEnvir.MapName, CX-1, CY, recallmob1);
         if cret <> nil then begin
            cret.SendRefMsg (RM_NORMALEFFECT, 0, cret.CX, cret.CY, NE_FOX_MOVESHOW, '');
         end;
         cret := UserEngine.AddCreatureSysop (PEnvir.MapName, CX, CY+1, recallmob2);
         if cret <> nil then begin
            cret.SendRefMsg (RM_NORMALEFFECT, 0, cret.CX, cret.CY, NE_FOX_MOVESHOW, '');
         end;
         cret := UserEngine.AddCreatureSysop (PEnvir.MapName, CX, CY-1, recallmob2);
         if cret <> nil then begin
            cret.SendRefMsg (RM_NORMALEFFECT, 0, cret.CX, cret.CY, NE_FOX_MOVESHOW, '');
         end;
//UserEngine.CryCry (RM_CRY, PEnvir, CX, CY, 10000, '소환 : ' + TargetCret.UserName);//test
         BoRecallComplete := TRUE;
      end;
   end;

   if not RunDone and IsMoveAble then begin
      if GetCurrentTime - WalkTime > GetNextWalkTime then begin
         //상속받은 run에서 WalkTime 재설정함
         if TargetCret <> nil then begin
            if (abs(CX-TargetCret.CX) <= 5) and (abs(CY-TargetCret.CY) <= 5) then begin
               if (abs(CX-TargetCret.CX) <= 2) and (abs(CY-TargetCret.CY) <= 2) then begin
                  //너무 가까우면, 잘 도망 안감.
                  if Random(3) = 0 then begin
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
   end;

   inherited Run;
end;

function TFoxTaoist.AttackTarget: Boolean;
var
   targdir: byte;
begin
   Result := FALSE;
   if TargetCret <> nil then begin
      if GetCurrentTime - HitTime > GetNextHitTime then begin
         HitTime := GetCurrentTime;
         if (abs(CX-TargetCret.CX) <= 7) and (abs(CY-TargetCret.CY) <= 7) then begin
            if (TargetInAttackRange (TargetCret, targdir)) and (Random(10) < 8) then begin
               TargetFocusTime := GetTickCount;
               Attack (TargetCret, targdir);
               Result := TRUE;
            end else begin
               if (abs(CX-TargetCret.CX) <= 6) and (abs(CY-TargetCret.CY) <= 6) then begin
                  if Random(10) < 7 then begin
                     //여우_폭살계
                     RangeAttack2( TargetCret );
                     Result := TRUE;
                  end else if Random(10) < 6 then begin
                     //여우_저주술
                     RangeAttack( TargetCret );
                     Result := TRUE;
                  end;
               end else begin
                  if Random(10) < 6 then begin
                     //여우_저주술
                     RangeAttack( TargetCret );
                     Result := TRUE;
                  end;
               end;
            end;
         end else begin
            if TargetCret.MapName = self.MapName then begin
               if (abs(CX-TargetCret.CX) <= 11) and (abs(CY-TargetCret.CY) <= 11) then begin
                  SetTargetXY (TargetCret.CX, TargetCret.CY)
               end;
            end else begin
               LoseTarget;  //<!!주의> TargetCret := nil로 바뀜
            end;
         end;
      end;
   end;
end;

{---------------------------------------------------------------------------}
// TPushedMon    호기연

constructor TPushedMon.Create;
begin
   inherited Create;
   Light := 3;
   SearchRate := 2500 + longword(Random(1500));

   AttackWide := 1;
end;

procedure TPushedMon.Initialize;
begin
   PushedCount := 0;
   if AttackWide = 1 then begin
      DeathCount := 5;
   end else begin
      DeathCount := 7;
   end;

   ViewRange := 7;

   inherited Initialize;
end;

procedure TPushedMon.Attack (target: TCreature; dir: byte);
var
   i, k,  mx, my, dam, armor: integer;
   wide: integer;
   rlist: TList;
   cret: TCreature;
   pwr: integer;
begin
   if target = nil then exit;

   wide := AttackWide;
   Self.Dir := GetNextDirection (CX, CY, target.CX, target.CY);
   SendRefMsg (RM_LIGHTING, self.Dir, CX, CY, Integer(target), '');
   with WAbil do
      pwr := GetAttackPower (Lobyte(DC), SmallInt(Hibyte(DC)-Lobyte(DC)));
   if pwr <= 0 then exit;

   rlist := TList.Create;
   GetMapCreatures (PEnvir, CX, CY, wide, rlist);
   for i:=0 to rlist.Count-1 do begin
      cret := TCreature (rlist[i]);
      if IsProperTarget(cret) then begin
         SelectTarget (cret);
         cret.SendDelayMsg (self, RM_MAGSTRUCK, 0, pwr, 0, 0, '', 600);
      end;
   end;
   rlist.Free;

end;

procedure TPushedMon.Run;
begin
   if not Death then begin
      if PushedCount >= DeathCount then begin
         //죽음
         Die;
      end;
   end;

   inherited Run;
end;

procedure TPushedMon.RunMsg (msg: TMessageInfo);
var
   nx, ny: integer;
   monname: string;
   mon: TCreature;
begin
   case msg.Ident of
      RM_STRUCK:
         begin
            WAbil.HP := WAbil.MaxHP;
            exit;
         end;
      RM_REFMESSAGE:
         begin
            if Integer(msg.Sender) = RM_STRUCK then begin
               WAbil.HP := WAbil.MaxHP;
               exit;
            end;
         end;
   end;

   inherited RunMsg (msg);
end;

procedure TPushedMon.Struck (hiter: TCreature);
begin
   WAbil.HP := WAbil.MaxHP;
end;

function TPushedMon.AttackTarget: Boolean;
var
   targdir: byte;
   TargX, TargY : integer;
   Flag: Boolean;
begin
   Result := FALSE;
   if TargetCret <> nil then begin
      if GetCurrentTime - HitTime > GetNextHitTime then begin
         HitTime := GetCurrentTime;
         if AttackWide = 1 then begin
            Flag := (TargetInAttackRange (TargetCret, targdir));
         end else begin
            Flag := (TargetInSpitRange (TargetCret, targdir));
         end;

         if Flag then begin
            Attack( TargetCret, targdir );
         end else begin
            if TargetCret.MapName = self.MapName then begin
               if (abs(CX-TargetCret.CX) <= 11) and (abs(CY-TargetCret.CY) <= 11) then begin
                  TargX := Random(2*AttackWide +1) -AttackWide;
                  TargY := Random(2*AttackWide +1) -AttackWide;
                  if (TargX < AttackWide) and (TargY < AttackWide) then TargX := -AttackWide;
                  TargX := TargX + TargetCret.CX;
                  TargY := TargY + TargetCret.CY;
                  SetTargetXY (TargX, TargY);
               end;
            end else begin
               LoseTarget;  //<!!주의> TargetCret := nil로 바뀜
            end;
         end;
      end;
   end;
end;

{---------------------------------------------------------------------------}
// TFoxPillar    호혼기석

constructor TFoxPillar.Create;
begin
   inherited Create;
   RunDone := FALSE;
   ViewRange := 12;
   RunNextTick := 250;
   SearchRate := 2500 + longword(Random(1500));
   SearchTime := GetTickCount;
   HideMode := FALSE;
   StickMode := TRUE;
   BoDontMove  := TRUE;
   NeverDie := TRUE;
end;

function TFoxPillar.AttackTarget: Boolean;
var
   targdir: byte;
begin
   Result := FALSE;

   if FindTarget then begin
      if GetCurrentTime - HitTime > GetNextHitTime then begin
         HitTime := GetCurrentTime;

         if (abs(CX-TargetCret.CX) <= ViewRange) and (abs(CY-TargetCret.CY) <= ViewRange) then begin
            if Random(5) = 0 then begin
               RangeAttack (TargetCret);
               Attack (TargetCret, Dir);
               Result := TRUE;
            end else if Random(4) < 2 then begin
               RangeAttack (TargetCret);
               Result := TRUE;
            end else begin
               Attack (TargetCret, Dir);
               Result := TRUE;
            end;
         end else begin
            if TargetCret.MapName = self.MapName then begin
               if (abs(CX-TargetCret.CX) <= ViewRange) and (abs(CY-TargetCret.CY) <= ViewRange) then begin
                  SetTargetXY (TargetCret.CX, TargetCret.CY)
               end;
            end else begin
               LoseTarget;  //<!!주의> TargetCret := nil로 바뀜
            end;
         end;

      end;
   end;

end;

function  TFoxPillar.FindTarget: Boolean;
var
   i: integer;
   cret: TCreature;
begin
   Result := FALSE;
   for i:=0 to VisibleActors.Count-1 do begin
      cret := TCreature (PTVisibleActor(VisibleActors[i]).cret);
      if (not cret.Death) and IsProperTarget(cret) then begin
         if (abs(CX-cret.CX) <= ViewRange) and (abs(CY-cret.CY) <= ViewRange) then begin
            if cret.RaceServer = RC_USERHUMAN then begin
               if TargetCret = nil then begin
                  //타겟 지정
                  TargetCret := cret;
               end else begin
                  //고정 타겟 방지.
                  if Random(2) = 0 then continue;

                  //타겟 지정
                  TargetCret := cret;
               end;

               Result := TRUE;
               break;
            end;
         end;
      end;
   end;
end;

procedure TFoxPillar.RangeAttack (targ: TCreature);
var
   levelgap, rushdir, rushDist: integer;
begin
   if targ = nil then exit;

    // 멀리있는 적을 끌어당긴다.
   Self.Dir := GetNextDirection (CX, CY, targ.CX, targ.CY);
   SendRefMsg (RM_LIGHTING_1, self.Dir, CX, CY, Integer(targ), '');

   rushDir := ( (Self.Dir + 4) mod 8 );
   rushDist := _MAX(0, _MAX( abs( CX - targ.CX ), abs( CY - targ.CY ) ) -3);

   if IsProperTarget (targ) then begin
      if not ( (abs(CX - targ.CX) <= 2) and (abs(CY - targ.CY) <= 2) ) then begin
         if (not targ.Death) and ((targ.RaceServer = RC_USERHUMAN) or (targ.Master <> nil)) then begin
            levelgap := (targ.AntiMagic*5)+HIBYTE(targ.Wabil.AC) div 2;
            if (Random(50) > levelgap) then begin
               // 직선에 있는넘만 땡긴다.(1칸씩 좌우로 있는 넘도 땡긴다)
//               if ( CX = targ.CX ) or ( CY = targ.CY ) or (abs (CX-targ.CX) <= 2) or (abs (CY-targ.CY) <= 2)
//                      or ( abs( abs (CX-targ.CX) - abs (CY-targ.CY) ) <= 2 ) then begin
               // 범위 안에 있는넘을 모두 땡긴다.
               if (abs(CX - targ.CX) <= 12) and (abs(CY - targ.CY) <= 12) then begin
                  //캐릭터 당기기 이펙트
                  targ.SendRefMsg (RM_LOOPNORMALEFFECT, integer(targ), 1000, 0, NE_SIDESTONE_PULL, '');

                  targ.CharRushRush ( RushDir, RushDist , false );
               end;
            end;
         end;
      end;
   end;

end;

//중심 범위 공격
procedure TFoxPillar.Attack (target: TCreature; dir: byte);
var
   i, k,  mx, my, dam, armor: integer;
   wide: integer;
   rlist: TList;
   cret: TCreature;
   pwr: integer;
begin
   if target = nil then exit;

   wide := 2;
   Self.Dir := GetNextDirection (CX, CY, target.CX, target.CY);
   SendRefMsg (RM_LIGHTING, self.Dir, CX, CY, Integer(target), '');
   with WAbil do
      pwr := GetAttackPower (Lobyte(DC), SmallInt(Hibyte(DC)-Lobyte(DC)));
   if pwr <= 0 then exit;

   rlist := TList.Create;
   GetMapCreatures (PEnvir, CX, CY, wide, rlist);
   for i:=0 to rlist.Count-1 do begin
      cret := TCreature (rlist[i]);
      if IsProperTarget(cret) then begin
         SelectTarget (cret);
         cret.SendDelayMsg (self, RM_MAGSTRUCK, 0, pwr, 0, 0, '', 600);
      end;
   end;
   rlist.Free;
end;


{---------------------------------------------------------------------------}
// TFoxBead    비월천주

constructor TFoxBead.Create;
begin
   inherited Create;
   RunDone := FALSE;
   ViewRange := 16;
   RunNextTick := 250;
   SearchRate := 1500 + longword(Random(1500));
   SearchTime := GetTickCount;
   HideMode := FALSE;
   StickMode := TRUE;
   BoDontMove  := TRUE;
   BodyState := 1;
   OrgNextHitTime := NextHitTime;
   sectick := GetTickCount;
end;

procedure TFoxBead.Run ;
begin
   if GetTickCount - sectick > 3000 then begin
      sectick := GetTickCount;
      if (not Death) and (not BoGhost) then begin
         if (WAbil.HP >= WAbil.MaxHP * 4 div 5) then begin
            if BodyState <> 1 then begin
               BodyState := 1;
{$IFDEF DEBUG}
UserEngine.CryCry (RM_CRY, PEnvir, CX, CY, 10000, ' State(' + IntToStr(BodyState) + ') : ' + TargetCret.UserName);//test
{$ENDIF}
               WAbil.DC := MakeWord( _MIN(255, LOBYTE(Abil.DC)), _MIN(255, HIBYTE(Abil.DC)) );
               WAbil.AC := MakeWord( _MIN(255, LOBYTE(Abil.AC)), _MIN(255, HIBYTE(Abil.AC)) );
               WAbil.MAC := MakeWord( _MIN(255, LOBYTE(Abil.MAC)), _MIN(255, HIBYTE(Abil.MAC)) );
               SendRefMsg (RM_FOXSTATE, Dir, CX, CY, BodyState, UserName);
//               NextHitTime := OrgNextHitTime;
            end;
         end else if (WAbil.HP >= WAbil.MaxHP * 3 div 5) then begin
            if BodyState <> 2 then begin
               BodyState := 2;
{$IFDEF DEBUG}
UserEngine.CryCry (RM_CRY, PEnvir, CX, CY, 10000, ' State(' + IntToStr(BodyState) + ') : ' + TargetCret.UserName);//test
{$ENDIF}
               WAbil.DC := MakeWord( _MIN(255, LOBYTE(Abil.DC)), _MIN(255, HIBYTE(Abil.DC) + HIBYTE(Abil.DC) div 10) );
               WAbil.AC := MakeWord( _MIN(255, LOBYTE(Abil.AC)), _MIN(255, HIBYTE(Abil.AC) + HIBYTE(Abil.AC) * 2 div 10) );
               WAbil.MAC := MakeWord( _MIN(255, LOBYTE(Abil.MAC)), _MIN(255, HIBYTE(Abil.MAC) + HIBYTE(Abil.MAC) * 2 div 10) );
               SendRefMsg (RM_FOXSTATE, Dir, CX, CY, BodyState, UserName);
//               NextHitTime := OrgNextHitTime;
            end;
         end else if (WAbil.HP >= WAbil.MaxHP * 2 div 5) then begin
            if BodyState <> 3 then begin
               BodyState := 3;
{$IFDEF DEBUG}
UserEngine.CryCry (RM_CRY, PEnvir, CX, CY, 10000, ' State(' + IntToStr(BodyState) + ') : ' + TargetCret.UserName);//test
{$ENDIF}
               WAbil.DC := MakeWord( _MIN(255, LOBYTE(Abil.DC)), _MIN(255, HIBYTE(Abil.DC) + HIBYTE(Abil.DC) * 2 div 10) );
               WAbil.AC := MakeWord( _MIN(255, LOBYTE(Abil.AC)), _MIN(255, HIBYTE(Abil.AC) + HIBYTE(Abil.AC) * 4 div 10) );
               WAbil.MAC := MakeWord( _MIN(255, LOBYTE(Abil.MAC)), _MIN(255, HIBYTE(Abil.MAC) + HIBYTE(Abil.MAC) * 4 div 10) );
               SendRefMsg (RM_FOXSTATE, Dir, CX, CY, BodyState, UserName);
//               NextHitTime := OrgNextHitTime * 9 div 10;
            end;
         end else if (WAbil.HP >= WAbil.MaxHP * 1 div 5) then begin
            if BodyState <> 4 then begin
               BodyState := 4;
{$IFDEF DEBUG}
UserEngine.CryCry (RM_CRY, PEnvir, CX, CY, 10000, ' State(' + IntToStr(BodyState) + ') : ' + TargetCret.UserName);//test
{$ENDIF}
               WAbil.DC := MakeWord( _MIN(255, LOBYTE(Abil.DC)), _MIN(255, HIBYTE(Abil.DC) + HIBYTE(Abil.DC) * 3 div 10) );
               WAbil.AC := MakeWord( _MIN(255, LOBYTE(Abil.AC)), _MIN(255, HIBYTE(Abil.AC) + HIBYTE(Abil.AC) * 6 div 10) );
               WAbil.MAC := MakeWord( _MIN(255, LOBYTE(Abil.MAC)), _MIN(255, HIBYTE(Abil.MAC) + HIBYTE(Abil.MAC) * 4 div 10) );
               SendRefMsg (RM_FOXSTATE, Dir, CX, CY, BodyState, UserName);
//               NextHitTime := OrgNextHitTime * 8 div 10;
            end;
         end else begin
            if BodyState <> 5 then begin
               BodyState := 5;
{$IFDEF DEBUG}
UserEngine.CryCry (RM_CRY, PEnvir, CX, CY, 10000, ' State(' + IntToStr(BodyState) + ') : ' + TargetCret.UserName);//test
{$ENDIF}
               WAbil.DC := MakeWord( _MIN(255, LOBYTE(Abil.DC)), _MIN(255, HIBYTE(Abil.DC) + HIBYTE(Abil.DC) * 4 div 10) );
               WAbil.AC := MakeWord( _MIN(255, LOBYTE(Abil.AC)), _MIN(255, HIBYTE(Abil.AC) + HIBYTE(Abil.AC) * 8 div 10) );
               WAbil.MAC := MakeWord( _MIN(255, LOBYTE(Abil.MAC)), _MIN(255, HIBYTE(Abil.MAC) + HIBYTE(Abil.MAC) * 4 div 10) );
               SendRefMsg (RM_FOXSTATE, Dir, CX, CY, BodyState, UserName);
//               NextHitTime := OrgNextHitTime * 7 div 10;
            end;
         end;
      end;
   end;

   // 기존 실행을 한다.
   inherited Run;
end;

function TFoxBead.AttackTarget: Boolean;
var
   targdir: byte;
   i, nx, ny: integer;
   cret: TCreature;
   rlist: TList;
begin
   Result := FALSE;

   rlist := nil;
   cret := nil;
   if TargetCret <> nil then begin
      if GetCurrentTime - HitTime > GetNextHitTime then begin
         HitTime := GetCurrentTime;

         if (abs(CX-TargetCret.CX) <= ViewRange) and (abs(CY-TargetCret.CY) <= ViewRange) then begin
            //소환(10%)
            if Random(10) = 0 then begin
               //소환 비월천주 Effect
               SendRefMsg (RM_NORMALEFFECT, 0, CX, CY, NE_KINGSTONE_RECALL_1, '');

               rlist := TList.Create;
               GetMapCreatures (PEnvir, CX, CY, 30, rlist);
               for i:=0 to rlist.Count-1 do begin
                  cret := TCreature (rlist[i]);
                  if (not cret.Death) and IsProperTarget (cret) then begin
                     //일정 범위 밖에 있는 사람만
                     if (cret.RaceServer = RC_USERHUMAN) and ( (abs(CX - cret.CX) > 3) or (abs(CY - cret.CY) > 3) ) then begin
                        //소환한다.
                        if Random(3) < 2 then begin
                           //소환 캐릭 Effect
                           cret.SendRefMsg (RM_NORMALEFFECT, 0, cret.CX, cret.CY, NE_KINGSTONE_RECALL_2, '');

                           if Random(2) = 0 then begin
                              nx := CX + Random(3) + 1;
                              ny := CY + Random(3) + 1;
                           end else begin
                              nx := CX - Random(3) - 1;
                              ny := CY - Random(3) - 1;
                           end;
                           cret.SpaceMove( PEnvir.MapName, nx, ny, 2 );

                           //소환 캐릭 Effect
                           cret.SendRefMsg (RM_NORMALEFFECT, 0, cret.CX, cret.CY, NE_KINGSTONE_RECALL_2, '');
                        end;
                     end;
                  end;
               end;
               rlist.Free;
{$IFDEF DEBUG}
UserEngine.CryCry (RM_CRY, PEnvir, CX, CY, 10000, ' 소환 : ' + TargetCret.UserName);//test
{$ENDIF}
               Result := TRUE;
            end else if Random(100) < 40 then begin
               //초필살 공격(35%)
{$IFDEF DEBUG}
UserEngine.CryCry (RM_CRY, PEnvir, CX, CY, 10000, ' 초필살 : ' + TargetCret.UserName);//test
{$ENDIF}
               RangeAttack2 (TargetCret);
               Result := TRUE;
            end else if Random(10) < 4 then begin
               //중심공격(%)
{$IFDEF DEBUG}
UserEngine.CryCry (RM_CRY, PEnvir, CX, CY, 10000, ' 중심공격 : ' + TargetCret.UserName);//test
{$ENDIF}
               Attack (TargetCret, Dir);
               Result := TRUE;
            end else begin
               //원거리공격(%)
{$IFDEF DEBUG}
UserEngine.CryCry (RM_CRY, PEnvir, CX, CY, 10000, ' 원거리범위 : ' + TargetCret.UserName);//test
{$ENDIF}
               RangeAttack (TargetCret);
               Result := TRUE;
            end;
            //다른 타겟 물색
            if Random(10) < 4 then begin
               FindTarget;
            end;
         end else begin
            if TargetCret.MapName = self.MapName then begin
               if (abs(CX-TargetCret.CX) <= ViewRange) and (abs(CY-TargetCret.CY) <= ViewRange) then begin
                  SetTargetXY (TargetCret.CX, TargetCret.CY)
               end;
            end else begin
               LoseTarget;  //<!!주의> TargetCret := nil로 바뀜
            end;
         end;

      end;
   end;

end;

function  TFoxBead.FindTarget: Boolean;
var
   i: integer;
   cret: TCreature;
begin
   Result := FALSE;
   for i:=0 to VisibleActors.Count-1 do begin
      cret := TCreature (PTVisibleActor(VisibleActors[i]).cret);
      if (not cret.Death) and IsProperTarget(cret) then begin
         if (abs(CX-cret.CX) <= ViewRange) and (abs(CY-cret.CY) <= ViewRange) then begin
            if cret.RaceServer = RC_USERHUMAN then begin
               if TargetCret = nil then begin
                  //타겟 지정
                  TargetCret := cret;
               end else begin
                  //고정 타겟 방지.
                  if Random(100) < 50 then continue;

                  //타겟 지정
                  TargetCret := cret;
               end;

               Result := TRUE;
               break;
            end;
         end;
      end;
   end;
end;

//5x5 원거리 범위 공격
procedure TFoxBead.RangeAttack (targ: TCreature); //반드시 target <> nil
var
   i, pwr, dam: integer;
   sx, sy, tx, ty : integer;
   list: TList;
   cret: TCreature;
begin
   if targ = nil then exit;

   Self.Dir := GetNextDirection (CX, CY, targ.CX, targ.CY);
   SendRefMsg (RM_LIGHTING_1, self.Dir, CX, CY, Integer(targ), '');
   if GetNextPosition (PEnvir, CX, CY, dir, 1, sx, sy) then begin
      GetNextPosition (PEnvir, CX, CY, dir, 9, tx, ty);
      with WAbil do begin
         pwr := _MAX( 0, Lobyte(DC) + _MIN( 255, Random(SmallInt(Hibyte(DC)-Lobyte(DC)) + 1) ) );
         pwr := pwr + Random(Lobyte(MC));
         pwr := pwr * 2;
      end;

      list := TList.Create;
      PEnvir.GetCreatureInRange (targ.CX, targ.CY, 2, TRUE, list);
      for i:=0 to list.Count-1 do begin
         cret := TCreature(list[i]);
         if IsProperTarget (cret) then begin
            dam := cret.GetMagStruckDamage (self, pwr);
            if dam > 0 then begin
               cret.StruckDamage (dam, self);
               cret.SendDelayMsg (TCreature(RM_STRUCK), RM_REFMESSAGE, dam{wparam},
                                  cret.WAbil.HP{lparam1}, cret.WAbil.MaxHP{lparam2}, Longint(self){hiter}, '', 800);
            end;
         end;
      end;
      list.Free;
   end;
end;

//초필살 공격
procedure TFoxBead.RangeAttack2 (targ: TCreature); //반드시 target <> nil
var
   i, ix, iy, ixf, ixt, iyf, iyt, pwr, dam: integer;
   sx, sy, tx, ty : integer;
   list: TList;
   cret: TCreature;
   sec, skilllevel: integer;
begin
   if targ = nil then exit;

   //초필살 Effect
   SendRefMsg (RM_LIGHTING_2, self.Dir, CX, CY, Integer(self), '');
   with WAbil do begin
      pwr := GetAttackPower (Lobyte(DC), _MIN( 255, SmallInt(Hibyte(DC)-Lobyte(DC)) ) );
      pwr := pwr * 2;
   end;

   // 시야내 모든 캐릭/소환몹 중독
   for i := 0 to VisibleActors.Count-1 do begin
      cret := TCreature (PTVisibleActor(VisibleActors[i]).cret);
      if (not cret.Death) and IsProperTarget (cret) then begin
         if (cret.RaceServer = RC_USERHUMAN) or (cret.Master <> nil) then begin
            //저주술 또는 마비가 된다.
            if Random(10) < 2 then begin
               if Random(2 + cret.AntiPoison) = 0 then
                  cret.MakePoison (POISON_STONE, 5, 5);
            end else begin
               if Random(2 + cret.AntiPoison) = 0 then begin
                  sec := 60;
                  pwr := 70;
                  skilllevel := 3;
                  MagMakeCurseArea (targ.CX, targ.CY, 2, sec, pwr, skilllevel, FALSE);
               end;
            end;

            dam := cret.GetMagStruckDamage (self, pwr);
            if dam > 0 then
               cret.SendDelayMsg (self, RM_MAGSTRUCK, 0, dam, 0, 0, '', 1500);
            dam := cret.GetMagStruckDamage (self, pwr);
            if dam > 0 then
               cret.SendDelayMsg (self, RM_MAGSTRUCK, 0, dam, 0, 0, '', 2000);
         end;
      end;
   end;
end;

//중심 범위 공격
procedure TFoxBead.Attack (target: TCreature; dir: byte);
var
   i, k,  mx, my, dam, armor: integer;
   wide: integer;
   rlist: TList;
   cret: TCreature;
   pwr: integer;
begin
   if target = nil then exit;

   wide := 3;
   Self.Dir := GetNextDirection (CX, CY, target.CX, target.CY);
   SendRefMsg (RM_LIGHTING, self.Dir, CX, CY, Integer(target), '');
   with WAbil do begin
      pwr := GetAttackPower (Lobyte(DC), _MIN( 255, SmallInt(Hibyte(DC)-Lobyte(DC)) ) );
      pwr := pwr + Random(Lobyte(MC));
      pwr := pwr * 2;
   end;
   if pwr <= 0 then exit;

   rlist := TList.Create;
   GetMapCreatures (PEnvir, CX, CY, wide, rlist);
   for i:=0 to rlist.Count-1 do begin
      cret := TCreature (rlist[i]);
      if IsProperTarget(cret) then begin
         SelectTarget (cret);
         //3번 연속 타격
         dam := cret.GetMagStruckDamage (self, pwr);
         if dam > 0 then
            cret.SendDelayMsg (self, RM_MAGSTRUCK, 0, dam, 0, 0, '', 300);
         dam := cret.GetMagStruckDamage (self, pwr);
         if dam > 0 then
            cret.SendDelayMsg (self, RM_MAGSTRUCK, 0, dam, 0, 0, '', 600);
         dam := cret.GetMagStruckDamage (self, pwr);
         if dam > 0 then
            cret.SendDelayMsg (self, RM_MAGSTRUCK, 0, dam, 0, 0, '', 900);
      end;
   end;
   rlist.Free;
end;

procedure TFoxBead.Die;
var
   k: integer;
   cret: TCreature;
   list: TList;
begin
   list := TList.Create;
   UserEngine.GetMapMons (PEnvir, list);
   for k:=0 to list.Count-1 do begin
      TCreature(list[k]).NeverDie := FALSE;
//      TCreature(list[k]).BoNoItem := TRUE;
      TCreature(list[k]).WAbil.HP := 0;  //모두 죽인다.
   end;
   list.Free;

   inherited Die;
end;


{---------------------------------------------------------------------------}
// TBossTurtle    거북왕(현무)

constructor TBossTurtle.Create;
begin
   inherited Create;
   ViewRange := 17;
   RunNextTick := 250;
   SearchRate := 1500 + longword(Random(2000));
   SearchTime := GetTickCount;
   HideMode := FALSE;
   RecallStep := 9;
end;

function TBossTurtle.AttackTarget: Boolean;
var
   targdir: byte;
   i, nx, ny: integer;
   cret: TCreature;
   rlist: TList;
   rand, selectattack: integer;
   recallflag: Boolean;
   mobname1, mobname2: string;
begin
   Result := FALSE;

   {$IFDEF KOREA}
      mobname1 := '갑석귀수';
      mobname2 := '갑철귀수';
   {$ELSE}
      mobname1 := '갑석귀수';
      mobname2 := '갑철귀수';
   {$ENDIF}

   selectattack := 0;
   rlist := nil;
   cret := nil;
   if TargetCret <> nil then begin
      if GetCurrentTime - HitTime > GetNextHitTime then begin
         HitTime := GetCurrentTime;

         //공격거리 : 12
         if (abs(CX-TargetCret.CX) <= 12) and (abs(CY-TargetCret.CY) <= 12) then begin
            rand := Random(10000) + 1;

            //공격 종류 선택
            //체력이 50%이상일 때
            if WAbil.HP >= WAbil.MaxHP div 2 then begin
               case rand of
                  1..2800: //전체공격
                     begin
                        selectattack := 1;
                     end;
                  2801..6800: //물리A
                     begin
                        selectattack := 2;
                     end;
                  6801..9800: //물리B
                     begin
                        selectattack := 3;
                     end;
                  else  //힐링
                     begin
                        selectattack := 4;
                     end;
               end;
            //체력이 50%미만일 때
            end else begin
               case rand of
                  1..4300: //전체공격
                     begin
                        selectattack := 1;
                     end;
                  4301..7300: //물리A
                     begin
                        selectattack := 2;
                     end;
                  7301..9300: //물리B
                     begin
                        selectattack := 3;
                     end;
                  else  //힐링
                     begin
                        selectattack := 4;
                     end;
               end;
            end;

            //공격 수행
            case selectattack of
               1: //전체공격
                  begin
                     RangeAttack2 (TargetCret);
{$IFDEF DEBUG}
UserEngine.CryCry (RM_CRY, PEnvir, CX, CY, 10000, ' 전체 : ' + TargetCret.UserName);//test
{$ENDIF}
                     Result := TRUE;
                  end;
               2: //물리A
                  begin
                     Attack (TargetCret, Dir);
{$IFDEF DEBUG}
UserEngine.CryCry (RM_CRY, PEnvir, CX, CY, 10000, ' 중심공격 : ' + TargetCret.UserName);//test
{$ENDIF}
                     Result := TRUE;
                  end;
               3: //물리B
                  begin
                     //공격거리 : 4
                     if (abs(CX-TargetCret.CX) <= 4) and (abs(CY-TargetCret.CY) <= 4) then begin
                        RangeAttack (TargetCret);
{$IFDEF DEBUG}
UserEngine.CryCry (RM_CRY, PEnvir, CX, CY, 10000, ' 원거리범위 : ' + TargetCret.UserName);//test
{$ENDIF}
                        Result := TRUE;
                     end;
                  end;
               4:  //힐링
                  begin
                     SendRefMsg (RM_LIGHTING_1, Dir, CX, CY, Integer(self), '');
                     IncHealthSpell (1000{+hp}, 0{+mp});
{$IFDEF DEBUG}
UserEngine.CryCry (RM_CRY, PEnvir, CX, CY, 10000, ' 힐링 : ' + TargetCret.UserName);//test
{$ENDIF}
                     Result := TRUE;
                  end;
               else
                  begin
                  end;
            end;

            //다른 타겟 물색
            if Random(10) < 4 then begin
               FindTarget;
            end;

         end else begin
            if TargetCret.MapName = self.MapName then begin
               if (abs(CX-TargetCret.CX) <= ViewRange) and (abs(CY-TargetCret.CY) <= ViewRange) then begin
                  SetTargetXY (TargetCret.CX, TargetCret.CY)
               end;
            end else begin
               LoseTarget;  //<!!주의> TargetCret := nil로 바뀜
            end;
         end;

         //------------------------------------
         //소환 조건
         recallflag := FALSE;

         if (WAbil.HP <= WAbil.MaxHP div 10 * RecallStep) and (RecallStep > 0) then begin
            Dec(RecallStep);
            recallflag := TRUE;
         end;

         if recallflag then begin
            //소환 Effect
            SendRefMsg (RM_LIGHTING_3, Dir, CX, CY, Integer(self), '');

            //소환
            for i := -1 to 1 do begin
               cret := UserEngine.AddCreatureSysop (PEnvir.MapName, CX+i, CY-1, mobname1);
               if cret <> nil then begin
                  cret.SendRefMsg (RM_NORMALEFFECT, 0, cret.CX, cret.CY, NE_KINGTURTLE_MOBSHOW, '');
               end;
               cret := UserEngine.AddCreatureSysop (PEnvir.MapName, CX+i, CY+1, mobname2);
               if cret <> nil then begin
                  cret.SendRefMsg (RM_NORMALEFFECT, 0, cret.CX, cret.CY, NE_KINGTURTLE_MOBSHOW, '');
               end;
            end;
{$IFDEF DEBUG}
UserEngine.CryCry (RM_CRY, PEnvir, CX, CY, 10000, ' 소환 : ' + TargetCret.UserName);//test
{$ENDIF}
            Result := TRUE;
         end;
         //------------------------------------
      end;
   end;

end;

function  TBossTurtle.FindTarget: Boolean;
var
   i: integer;
   cret: TCreature;
begin
   Result := FALSE;
   for i:=0 to VisibleActors.Count-1 do begin
      cret := TCreature (PTVisibleActor(VisibleActors[i]).cret);
      if (not cret.Death) and IsProperTarget(cret) then begin
         if (abs(CX-cret.CX) <= ViewRange) and (abs(CY-cret.CY) <= ViewRange) then begin
            if cret.RaceServer = RC_USERHUMAN then begin
               if TargetCret = nil then begin
                  //타겟 지정
                  TargetCret := cret;
               end else begin
                  //고정 타겟 방지.
                  if Random(100) < 50 then continue;

                  //타겟 지정
                  TargetCret := cret;
               end;

               Result := TRUE;
               break;
            end;
         end;
      end;
   end;
end;

//공격4(물리B) : 타겟중심 원거리 범위 물리공격
procedure TBossTurtle.RangeAttack (targ: TCreature); //반드시 target <> nil
var
   i, pwr, dam: integer;
   sx, sy, tx, ty : integer;
   list: TList;
   cret: TCreature;
begin
   if targ = nil then exit;

   Self.Dir := GetNextDirection (CX, CY, targ.CX, targ.CY);
   SendRefMsg (RM_LIGHTING, self.Dir, CX, CY, Integer(targ), '');
   if GetNextPosition (PEnvir, CX, CY, dir, 1, sx, sy) then begin
      GetNextPosition (PEnvir, CX, CY, dir, 9, tx, ty);
      with WAbil do begin
         pwr := _MAX( 0, Lobyte(DC) + _MIN( 255, Random(SmallInt(Hibyte(DC)-Lobyte(DC)) + 1) ) );
         pwr := pwr + Random(Lobyte(MC));
         pwr := pwr * 2;
      end;

      list := TList.Create;
      //3*3 범위 공격
      PEnvir.GetCreatureInRange (targ.CX, targ.CY, 1, TRUE, list);
      for i:=0 to list.Count-1 do begin
         cret := TCreature(list[i]);
         if IsProperTarget (cret) then begin
            dam := cret.GetHitStruckDamage (self, pwr);
            if dam > 0 then begin
               cret.StruckDamage (dam, self);
               cret.SendDelayMsg (TCreature(RM_STRUCK), RM_REFMESSAGE, dam{wparam},
                                  cret.WAbil.HP{lparam1}, cret.WAbil.MaxHP{lparam2}, Longint(self){hiter}, '', 500);
            end;
         end;
      end;
      list.Free;
   end;
end;

//공격1(전체공격) : 타겟을 중심으로 15*15 범위 원거리 마법공격
procedure TBossTurtle.RangeAttack2 (targ: TCreature); //반드시 target <> nil
var
   i, ix, iy, ixf, ixt, iyf, iyt, pwr, dam: integer;
   sx, sy, tx, ty : integer;
   list: TList;
   cret: TCreature;
   sec, skilllevel: integer;
begin
   if targ = nil then exit;

   Self.Dir := GetNextDirection (CX, CY, targ.CX, targ.CY);
   SendRefMsg (RM_LIGHTING_2, self.Dir, CX, CY, Integer(targ), '');
   if GetNextPosition (PEnvir, CX, CY, dir, 1, sx, sy) then begin
      GetNextPosition (PEnvir, CX, CY, dir, 9, tx, ty);
      with WAbil do begin
         pwr := _MAX( 0, Lobyte(DC) + _MIN( 255, Random(SmallInt(Hibyte(DC)-Lobyte(DC)) + 1) ) );
         pwr := pwr + Random(Lobyte(MC));
         pwr := pwr * 2;
      end;

      list := TList.Create;
      //15*15 범위 공격
      PEnvir.GetCreatureInRange (targ.CX, targ.CY, 7, TRUE, list);
      for i:=0 to list.Count-1 do begin
         cret := TCreature(list[i]);
         if IsProperTarget (cret) then begin
            dam := cret.GetHitStruckDamage (self, pwr);
            if dam > 0 then begin
               cret.StruckDamage (dam, self);
               cret.SendDelayMsg (TCreature(RM_STRUCK), RM_REFMESSAGE, dam{wparam},
                                  cret.WAbil.HP{lparam1}, cret.WAbil.MaxHP{lparam2}, Longint(self){hiter}, '', 800);
            end;
         end;
      end;
      list.Free;
   end;
end;

//공격3(물리A) : 시전자 중심 범위 물리공격
procedure TBossTurtle.Attack (target: TCreature; dir: byte);
var
   i, k,  mx, my, dam, armor: integer;
   wide: integer;
   rlist: TList;
   cret: TCreature;
   pwr: integer;
begin
   if target = nil then exit;

   //시전자 중심 5*5
   wide := 2;
//   Self.Dir := GetNextDirection (CX, CY, target.CX, target.CY);
//   SendRefMsg (RM_LIGHTING, self.Dir, CX, CY, Integer(target), '');
   with WAbil do begin
      pwr := GetAttackPower (Lobyte(DC), _MIN( 255, SmallInt(Hibyte(DC)-Lobyte(DC)) ) );
      pwr := pwr + Random(Lobyte(MC));
      pwr := pwr * 2;
   end;
   if pwr <= 0 then exit;

   rlist := TList.Create;
   GetMapCreatures (PEnvir, CX, CY, wide, rlist);
   for i:=0 to rlist.Count-1 do begin
      cret := TCreature (rlist[i]);
      if IsProperTarget(cret) then begin
         SelectTarget (cret);
         dam := cret.GetHitStruckDamage (self, pwr);
         if dam > 0 then
            HitHit2 (cret, dam, 0, TRUE);
//            cret.SendDelayMsg (self, RM_MAGSTRUCK, 0, dam, 0, 0, '', 300);
      end;
   end;
   rlist.Free;
end;


end.
