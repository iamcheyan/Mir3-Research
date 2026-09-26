unit ObjMon2;

interface

uses
  Windows, Messages, SysUtils, Classes, Graphics, Controls, Dialogs,
  ScktComp, syncobjs, MudUtil, HUtil32, Grobal2, Envir, EdCode, ObjBase,
  M2Share, Event, ObjMon;


type
   TDoorState = (dsOpen, dsClose, dsBroken);

   TStickMonster = class (TAnimal)
   private
   protected
      RunDone: Boolean;
      DigupRange: integer;
      DigdownRange: integer;
      function  AttackTarget: Boolean; dynamic;
      procedure CheckComeOut; dynamic;
      procedure ComeOut; dynamic;
      procedure ComeDown; dynamic;
   public
      constructor Create;
      destructor Destroy; override;
      procedure RunMsg (msg: TMessageInfo); override;
      procedure Run; override;
   end;

   TBeeQueen = class (TAnimal)   //비막원충, 비막충
   private
      //childcount: integer;
      childlist: TList;  //생산한 부하들의 리스트
   protected
      procedure MakeChildBee;
   public
      constructor Create;
      destructor Destroy; override;
      procedure RunMsg (msg: TMessageInfo); override;
      procedure Run; override;
   end;

   TCentipedeKingMonster = class (TStickMonster)
   private
      appeartime: longword;
   protected
      function  FindTarget: Boolean;
      function  AttackTarget: Boolean; override;
   public
      constructor Create;
      procedure ComeOut; override;
      procedure Run; override;
   end;

   TBigHeartMonster = class (TAnimal)  //적월마, 심장몬스터
   private
   protected
      function  AttackTarget: Boolean; dynamic;
   public
      constructor Create;
      procedure Run; override;
   end;

   TBamTreeMonster = class (TAnimal)
   public
      StruckCount, DeathStruckCount: integer;
      constructor Create;
      procedure Struck (hiter: TCreature); override;
      procedure Run; override;
   end;

   TMonsterBox = class (TBamTreeMonster)
   public
      constructor Create;
      procedure Die; override;
   end;

   TSpiderHouseMonster = class (TAnimal)   //폭안거미, 폭주
   private
      childlist: TList;  //생산한 부하들의 리스트
   protected
      procedure MakeChildSpider;
   public
      constructor Create;
      destructor Destroy; override;
      procedure RunMsg (msg: TMessageInfo); override;
      procedure Run; override;
   end;

   TExplosionSpider = class (TMonster)
   public
      maketime: longword;
      constructor Create;
      procedure DoSelfExplosion;
      function  AttackTarget: Boolean; override;
      procedure Run; override;
   end;


   //경비, 성문, 궁수

   TGuardUnit = class (TAnimal)
      OriginX, OriginY, OriginDir: integer;
   public
      procedure Struck (hiter: TCreature); override;
      function  IsProperTarget (target: TCreature): Boolean; override;
   end;

   TArcherGuard = class (TGuardUnit)
   private
      procedure ShotArrow (targ: TCreature);
   public
      constructor Create;
      procedure Run; override;
   end;

   TArcherMaster = class (TATMonster)   //궁수호위병
   private
      procedure ShotArrow (targ: TCreature);
   public
      constructor Create;
      function  AttackTarget: Boolean; override;
      procedure Run; override;
   end;

   TArcherPolice = class (TArcherGuard)
   private
   public
      constructor Create;
   end;

   TCastleDoor = class (TGuardUnit)
   public
      BrokenTime: longword; //부서진 시간
      BoOpenState: Boolean;  //문인경우 열려졌있는지
      constructor Create;
      procedure Run; override;
      procedure Initialize; override;
      procedure Die; override;
      procedure RepairStructure;
      procedure ActiveDoorWall (dstate: TDoorState); //TRUE: 이동가, false:막힘, 못움직임
      procedure OpenDoor;
      procedure CloseDoor;
   end;

   TWallStructure = class (TGuardUnit)
   public
      BrokenTime: longword;
      BoBlockPos: Boolean;
      constructor Create;
      procedure Initialize; override;
      procedure Die; override;
      procedure RepairStructure;
      procedure Run; override;
   end;


   TSoccerBall = class (TAnimal)
   public
      GoPower: integer;
      constructor Create;
      procedure Struck (hiter: TCreature); override;
      procedure Run; override;
   end;

   TMineMonster = class (TAnimal)
   private
   protected
      RunDone: Boolean;
      DigupRange: integer;
      DigdownRange: integer;
      function  AttackTarget: Boolean; dynamic;
      procedure CheckComeOut; dynamic;
      procedure ComeOut; dynamic;
   public
      constructor Create;
      destructor Destroy; override;
      procedure RunMsg (msg: TMessageInfo); override;
      procedure Run; override;
   end;

   //호혼석
   TStickBlockMonster = class (TStickMonster)
   private
      DontAttack: Boolean;
      BoCallFollower: Boolean;
      BoTransparent: Boolean;
      FirstComeOut: Boolean;
      SecondMovement: Boolean;
      FirstStruck: Boolean;
      Caller: TCreature;
      ComeoutTime: Longword;
      TargetDisappearTime: Longword;
      childlist: TList;  //만들어 낸 부하의 리스트
      OldTargetCret: TCreature;
   protected
      function  FindTarget: Boolean;
      function  AttackTarget: Boolean; override;
   public
      constructor Create;
      destructor Destroy; override;
      procedure Attack (target: TCreature; dir: byte); override;
      procedure ComeOut; override;
      procedure ComeDown; override;
      procedure CallFollower; dynamic;
      procedure Die; override;
      procedure RunMsg (msg: TMessageInfo); override;
      procedure Struck (hiter: TCreature); override;
      procedure Run; override;
   end;

implementation

uses
   svMain, Castle, Guild;


constructor TStickMonster.Create;
begin
   inherited Create;
   RunDone := FALSE;
   ViewRange := 7;
   RunNextTick := 250;
   SearchRate := 2500 + longword(Random(1500));
   SearchTime := GetTickCount;
   RaceServer := RC_KILLINGHERB;
   DigupRange := 4;
   DigdownRange := 4;
   HideMode := TRUE;
   StickMode := TRUE;
   BoAnimal := TRUE;  //썰면 식인초잎, 식인초열매가 나옴.
end;

destructor TStickMonster.Destroy;
begin
   inherited Destroy;
end;

function  TStickMonster.AttackTarget: Boolean;
var
   targdir: byte;
begin
   Result := FALSE;
   if TargetCret <> nil then begin
      if TargetInAttackRange (TargetCret, targdir) then begin
         if GetCurrentTime - HitTime > GetNextHitTime then begin
            HitTime := GetCurrentTime;
            TargetFocusTime := GetTickCount;
            Attack (TargetCret, targdir);
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

procedure TStickMonster.ComeOut;
begin
   HideMode := FALSE;
   SendRefMsg (RM_DIGUP, Dir, CX, CY, 0, '');
end;

procedure TStickMonster.ComeDown;
var
   i: integer;
begin
   SendRefMsg (RM_DIGDOWN, {Dir}0, CX, CY, 0, '');
   try
      for i:=0 to VisibleActors.Count-1 do
         Dispose (PTVisibleActor(VisibleActors[i]));
      VisibleActors.Clear;
   except
      MainOutMessage ('[Exception] TStickMonster VisbleActors Dispose(..)');
   end;
   HideMode := TRUE;
end;

procedure TStickMonster.CheckComeOut;
var
   i: integer;
   cret: TCreature;
begin
   for i:=0 to VisibleActors.Count-1 do begin
      cret := TCreature (PTVisibleActor(VisibleActors[i]).cret);
      if (not cret.Death) and (IsProperTarget(cret)) and (not cret.BoHumHideMode or BoViewFixedHide) then begin
         if (abs(CX-cret.CX) <= DigupRange) and (abs(CY-cret.CY) <= DigupRange) then begin
            ComeOut; //밖으로 나오다. 보인다.
            break;
         end;
      end;
   end;
end;

procedure TStickMonster.RunMsg (msg: TMessageInfo);
begin
   inherited RunMsg (msg);
end;

procedure TStickMonster.Run;
var
   boidle: Boolean;
begin
//   if (not BoGhost) and (not Death) and
//      (StatusArr[POISON_STONE] = 0) and (StatusArr[POISON_ICE] = 0) and
//      (StatusArr[POISON_STUN] = 0) then begin
   if IsMoveAble then begin
      if GetCurrentTime - WalkTime > GetNextWalkTime then begin
         WalkTime := GetCurrentTime;
         if HideMode then begin //아직 모습을 나타내지 않았음.
            CheckComeOut;
         end else begin
            if GetCurrentTime - HitTime > GetNextHitTime then begin //상속받은 run 에서 HitTime 재설정함.
               ///HitTime := GetTickCount; //아래 AttackTarget에서 함.
               MonsterNormalAttack;
            end;

            boidle := FALSE;
            if TargetCret <> nil then begin
               if (abs(TargetCret.CX-CX) > DigdownRange) or (abs(TargetCret.CY-CY) > DigdownRange) then
                  boidle := TRUE;
            end else boidle := TRUE;

            if boidle then
               ComeDown //다시 들어간다.
            else
               if AttackTarget then begin
                  inherited Run;
                  exit;
               end;
         end;
      end;
   end;

   inherited Run;

end;

// Mine Monster -----------------------------------------------------------------
constructor TMineMonster.Create;
begin
   inherited Create;
   RunDone := FALSE;
   ViewRange := 7;
   RunNextTick := 250;
   SearchRate := 2500 + longword(Random(1500));
   SearchTime := GetTickCount;
   RaceServer := RC_MINE;
   DigupRange := 4;
   DigdownRange := 4;
   HideMode := TRUE;
   StickMode := TRUE;
   BoAnimal := FALSE;  //썰면 식인초잎, 식인초열매가 나옴.
end;

destructor TMineMonster.Destroy;
begin
   inherited Destroy;
end;

function  TMineMonster.AttackTarget: Boolean;
var
   targdir: byte;
begin
   WAbil.HP := 0;
   Result := TRUE;
end;

procedure TMineMonster.ComeOut;
begin
   HideMode := FALSE;
   SendRefMsg (RM_DIGUP, Dir, CX, CY, 0, '');
end;


procedure TMineMonster.CheckComeOut;
var
   i: integer;
   cret: TCreature;
begin
   for i:=0 to VisibleActors.Count-1 do begin
      cret := TCreature (PTVisibleActor(VisibleActors[i]).cret);
      if (not cret.Death) and (IsProperTarget(cret)) and (not cret.BoHumHideMode or BoViewFixedHide) then begin
         if (abs(CX-cret.CX) <= DigupRange) and (abs(CY-cret.CY) <= DigupRange) then begin
            ComeOut; //밖으로 나오다. 보인다.
            break;
         end;
      end;
   end;
end;

procedure TMineMonster.RunMsg (msg: TMessageInfo);
begin
   inherited RunMsg (msg);
end;

procedure TMineMonster.Run;
begin
//   if (not BoGhost) and (not Death) and
//      (StatusArr[POISON_STONE] = 0) and (StatusArr[POISON_ICE] = 0) and
//      (StatusArr[POISON_STUN] = 0) then begin
   if IsMoveAble then begin
      if GetCurrentTime - WalkTime > GetNextWalkTime then begin
         WalkTime := GetCurrentTime;
         if HideMode then begin //아직 모습을 나타내지 않았음.
            CheckComeOut;
         end
         else
         begin
            if GetCurrentTime - HitTime > GetNextHitTime then
            begin //상속받은 run 에서 HitTime 재설정함.
               ///HitTime := GetTickCount; //아래 AttackTarget에서 함.
               if AttackTarget then begin
                  inherited Run;
                  exit;
               end;

            end;
         end;
      end;
   end;

   inherited Run;

end;


{--------------------------------------------------------------}
//벌통

constructor TBeeQueen.Create;
begin
   inherited Create;
   ViewRange := 9;
   RunNextTick := 250;
   SearchRate := 2500 + longword(Random(1500));
   SearchTime := GetTickCount;
   StickMode := TRUE;
   childlist := TList.Create;
end;

destructor TBeeQueen.Destroy;
begin
   childlist.Free;
   inherited Destroy;
end;

procedure TBeeQueen.MakeChildBee;
begin
   if childlist.Count < 15 then begin
      SendRefMsg (RM_HIT, self.Dir, CX, CY, 0, '');
      SendDelayMsg (self, RM_ZEN_BEE, 0, 0, 0, 0, '', 500);
   end;
end;

procedure TBeeQueen.RunMsg (msg: TMessageInfo);
var
   nx, ny: integer;
   monname: string;
   mon: TCreature;
begin
   case msg.Ident of
      RM_ZEN_BEE:
         begin
            monname := __Bee;  //비막충
            mon := UserEngine.AddCreatureSysop (PEnvir.MapName, CX, CY, monname);
            if mon <> nil then begin
               mon.SelectTarget (TargetCret);
               childlist.Add (mon);
            end;
         end;
   end;
   inherited RunMsg (msg);
end;

procedure TBeeQueen.Run;
var
   i: integer;
begin
//   if (not BoGhost) and (not Death) and
//      (StatusArr[POISON_STONE] = 0) and (StatusArr[POISON_ICE] = 0) and
//      (StatusArr[POISON_STUN] = 0) then begin
    if IsMoveAble then begin
      if GetCurrentTime - WalkTime > GetNextWalkTime then begin
         WalkTime := GetCurrentTime;
         if GetCurrentTime - HitTime > GetNextHitTime then begin //상속받은 run 에서 HitTime 재설정함.
            HitTime := GetTickCount;
            MonsterNormalAttack;

            if TargetCret <> nil then
               MakeChildBee;

         end;

         for i:=childlist.Count-1 downto 0 do begin
            if (TCreature(childlist[i]).Death) or (TCreature(childlist[i]).BoGhost) then begin
               childlist.Delete(i);
            end;
         end;
      end;
   end;

   inherited Run;
end;



{--------------------------------------------------------------}
//지네왕, 촉룡신

constructor TCentipedeKingMonster.Create;
begin
   inherited Create;
   ViewRange := 6;
   DigupRange := 4;
   DigdownRange := 6;
   BoAnimal := FALSE;
   appeartime := GetTickCount;
end;

function  TCentipedeKingMonster.FindTarget: Boolean;
var
   i: integer;
   cret: TCreature;
begin
   Result := FALSE;
   for i:=0 to VisibleActors.Count-1 do begin
      cret := TCreature (PTVisibleActor(VisibleActors[i]).cret);
      if (not cret.Death) and IsProperTarget(cret) then begin
         if (abs(CX-cret.CX) <= ViewRange) and (abs(CY-cret.CY) <= ViewRange) then begin
            Result := TRUE;
            break;
         end;
      end;
   end;
end;

function  TCentipedeKingMonster.AttackTarget: Boolean;
var
   i, pwr: integer;
   cret: TCreature;
   targdir: byte;
begin
   Result := FALSE;
   if FindTarget then begin
      if GetCurrentTime - HitTime > GetNextHitTime then begin
         HitTime := GetCurrentTime;
         //inherited HitHit (nil, HM_CROSSHIT, Dir);
         HitMotion (RM_HIT, self.Dir, CX, CY);

         with WAbil do
            pwr := _MAX( 0, Lobyte(DC) + Random(SmallInt(Hibyte(DC)-Lobyte(DC)) + 1) );

         for i:=0 to VisibleActors.Count-1 do begin
            cret := TCreature (PTVisibleActor(VisibleActors[i]).cret);
            if (not cret.Death) and IsProperTarget(cret) then begin
               if (abs(CX-cret.CX) <= ViewRange) and (abs(CY-cret.CY) <= ViewRange) then begin
                  TargetFocusTime := GetTickCount;

                  SendDelayMsg (self, RM_DELAYMAGIC, pwr, MakeLong(cret.CX, cret.CY), 2, integer(cret), '', 600);
                  //cret.SendDelayMsg (self, RM_MAGSTRUCK, 0, acpwr, 0, 0, '', 600);
                  if Random(4) = 0 then begin
                     if Random(3) <> 0 then
                        cret.MakePoison (POISON_DECHEALTH, 60, 3)   //체력이 감소
                     else
                        cret.MakePoison (POISON_STONE, 5{시간,초}, 0);
                  end;

                  TargetCret := cret;
               end;
            end;
         end;
      end;
      Result := TRUE;
   end;
end;

procedure TCentipedeKingMonster.ComeOut;
begin
   inherited ComeOut;
   WAbil.HP := WAbil.MaxHP;   //재등장하면 체력이 만땅
end;


procedure TCentipedeKingMonster.Run;   //지네왕,촉룡신
var
   i, dis, d: integer;
   cret, nearcret: TCreature;
begin
//   if (not BoGhost) and (not Death) and
//      (StatusArr[POISON_STONE] = 0) and (StatusArr[POISON_ICE] = 0) and
//      (StatusArr[POISON_STUN] = 0) then begin
     if IsMoveAble then begin
      if GetCurrentTime - WalkTime > NextWalkTime then begin
         WalkTime := GetCurrentTime;
         if HideMode then begin //아직 모습을 나타내지 않았음.
            if GetTickCount - appeartime > 10 * 1000 then begin
               for i:=0 to VisibleActors.Count-1 do begin
                  cret := TCreature (PTVisibleActor(VisibleActors[i]).cret);
                  if (not cret.Death) and (IsProperTarget(cret)) and (not cret.BoHumHideMode or BoViewFixedHide) then begin
                     if (abs(CX-cret.CX) <= DigupRange) and (abs(CY-cret.CY) <= DigupRange) then begin
                        ComeOut; //밖으로 나오다. 보인다.
                        appeartime := GetTickCount;
                        break;
                     end;
                  end;
               end;
            end;
         end else begin
            if GetTickCount - appeartime > 3 * 1000 then begin
               if AttackTarget then begin
                  inherited Run;
                  exit;
               end else begin  //적이 없음
                  if GetTickCount - appeartime > 10 * 1000 then begin
                     ComeDown;
                     appeartime := GetTickCount;
                  end;
               end;
            end;
         end;
      end;
   end;

   inherited Run;
end;


{--------------------------------------------------------------}
//TBigHeartMonster

constructor TBigHeartMonster.Create;
begin
   inherited Create;
   ViewRange := 16;
   BoAnimal := FALSE;
end;

function  TBigHeartMonster.AttackTarget: Boolean;
var
   i, pwr: integer;
   cret: TCreature;
   ev2: TEvent;
begin
   Result := FALSE;
   if GetCurrentTime - HitTime > GetNextHitTime then begin
      HitTime := GetCurrentTime;
      HitMotion (RM_HIT, self.Dir, CX, CY);

      with WAbil do
         pwr := _MAX( 0, Lobyte(DC) + Random(SmallInt(Hibyte(DC)-Lobyte(DC)) + 1) );

      for i:=0 to VisibleActors.Count-1 do begin
         cret := TCreature (PTVisibleActor(VisibleActors[i]).cret);
         if (not cret.Death) and IsProperTarget(cret) then begin
            if (abs(CX-cret.CX) <= ViewRange) and (abs(CY-cret.CY) <= ViewRange) then begin

               //공격....
               SendDelayMsg (self, RM_DELAYMAGIC, pwr, MakeLong(cret.CX, cret.CY), 1{range}, integer(cret), '', 200);
               SendRefMsg (RM_NORMALEFFECT, 0, cret.CX, cret.CY, NE_HEARTPALP, '');

               //ev2 := TEvent (PEnvir.GetEvent (cret.CX, cret.CY));    //공격 효과, 흔적
               //if ev2 = nil then begin
               //   ev2 := TPileStones.Create (PEnvir, cret.CX, cret.CY, ET_HEARTPALP, 3 * 60 * 1000, TRUE);
               //   EventMan.AddEvent (ev2);
               //end;


            end;
         end;
      end;

      Result := TRUE;
   end;
end;

procedure TBigHeartMonster.Run;
begin
//   if (not BoGhost) and (not Death) and
//      (StatusArr[POISON_STONE] = 0) and (StatusArr[POISON_ICE] = 0) and
//      (StatusArr[POISON_STUN] = 0) then begin
     if IsMoveAble then begin
      if VisibleActors.Count > 0 then
         AttackTarget;
   end;
   inherited Run;
end;


{--------------------------------------------------------------}
//밤나무


constructor TBamTreeMonster.Create;
begin
   inherited Create;
   BoAnimal := FALSE;
   StruckCount := 0;
   DeathStruckCount := 0;  //HP;;;
end;

procedure TBamTreeMonster.Struck (hiter: TCreature);
begin
   inherited Struck (hiter);
   Inc (StruckCount);
end;

procedure TBamTreeMonster.Run;
begin
   if DeathStruckCount = 0 then
      DeathStruckCount := WAbil.MaxHP;
   WAbil.HP := WAbil.MaxHP;

   if StruckCount >= DeathStruckCount then
      WAbil.HP := 0;

   inherited Run;
end;



{--------------------------------------------------------------}
//몬스터박스
constructor TMonsterBox.Create;
begin
   inherited Create;
   BoAnimal := FALSE;
   StruckCount := 0;
   DeathStruckCount := 0;  //HP;;;
end;

procedure TMonsterBox.Die;
var
   monname: string;
   mon: TCreature;
begin
   inherited Die;
   if (Random(100) mod 10) = 1 then begin
      //젠시킬 몬스터이름
      monname := '사슴';
      mon := UserEngine.AddCreatureSysop (PEnvir.MapName, CX, CY, monname);
   end;
end;


{--------------------------------------------------------------}
//폭안거미,  거미집


constructor TSpiderHouseMonster.Create;
begin
   inherited Create;
   ViewRange := 9;
   RunNextTick := 250;
   SearchRate := 2500 + longword(Random(1500));
   SearchTime := GetTickCount;
   StickMode := TRUE;
   childlist := TList.Create;
end;

destructor TSpiderHouseMonster.Destroy;
begin
   childlist.Free;
   inherited Destroy;
end;

procedure TSpiderHouseMonster.MakeChildSpider;
begin
   if childlist.Count < 15 then begin
      SendRefMsg (RM_HIT, self.Dir, CX, CY, 0, '');
      SendDelayMsg (self, RM_ZEN_BEE, 0, 0, 0, 0, '', 500);
   end;
end;

procedure TSpiderHouseMonster.RunMsg (msg: TMessageInfo);
var
   nx, ny: integer;
   monname: string;
   mon: TCreature;
begin
   case msg.Ident of
      RM_ZEN_BEE:
         begin
            monname := __Spider;  //폭주

            //거미의 방향에 따라서 새끼 거미의 위치가 조정
            nx := CX;
            ny := CY+1;

            if PEnvir.CanWalk (nx, ny, TRUE) then begin
               mon := UserEngine.AddCreatureSysop (PEnvir.MapName, nx, ny, monname);
               if mon <> nil then begin
                  mon.SelectTarget (TargetCret);
                  childlist.Add (mon);
               end;
            end;
         end;
   end;
   inherited RunMsg (msg);
end;

procedure TSpiderHouseMonster.Run;
var
   i: integer;
begin
//   if (not BoGhost) and (not Death) and
//      (StatusArr[POISON_STONE] = 0) and (StatusArr[POISON_ICE] = 0) and
//      (StatusArr[POISON_STUN] = 0) then begin
     if IsMoveAble then begin
      if GetCurrentTime - WalkTime > GetNextWalkTime then begin
         WalkTime := GetCurrentTime;
         if GetCurrentTime - HitTime > GetNextHitTime then begin //상속받은 run 에서 HitTime 재설정함.
            HitTime := GetTickCount;
            MonsterNormalAttack;

            if TargetCret <> nil then
               MakeChildSpider;

         end;

         for i:=childlist.Count-1 downto 0 do begin
            if (TCreature(childlist[i]).Death) or (TCreature(childlist[i]).BoGhost) then begin
               childlist.Delete(i);
            end;
         end;
      end;
   end;

   inherited Run;
end;



{--------------------------------------------------------------}
//폭주,  자폭 거미

constructor TExplosionSpider.Create;
begin
   inherited Create;
   ViewRange := 5;
   RunNextTick := 250;
   SearchRate := 2500 + longword(Random(1500));
   SearchTime := 0; //GetTickCount;
   maketime := GetTickCount;
end;

procedure TExplosionSpider.DoSelfExplosion;
var
   i, pwr, dam: integer;
   cret: TCreature;
begin
   WAbil.HP := 0;  //자폭
   //주위에 데미지를 준다.

   with WAbil do
      pwr := _MAX( 0, Lobyte(DC) + Random(SmallInt(Hibyte(DC)-Lobyte(DC)) + 1) );

   for i:=0 to VisibleActors.Count-1 do begin
      cret := TCreature (PTVisibleActor(VisibleActors[i]).cret);
      if (abs(cret.CX-CX) <= 1) and (abs(cret.CY-CY) <= 1) then begin
         if (not cret.Death) and (IsProperTarget(cret)) then begin
            dam := 0;
            dam := dam + cret.GetHitStruckDamage (self, pwr div 2);
            dam := dam + cret.GetMagStruckDamage (self, pwr div 2);
            if dam > 0 then begin
               cret.StruckDamage (dam, self);
               cret.SendDelayMsg (TCreature(RM_STRUCK), RM_REFMESSAGE, dam{wparam},
                        cret.WAbil.HP{lparam1}, cret.WAbil.MaxHP{lparam2}, Longint(self){hiter}, '', 700);
            end;
         end;
      end;
   end;
end;

function  TExplosionSpider.AttackTarget: Boolean;
var
   targdir: byte;
begin
   Result := FALSE;
   if TargetCret <> nil then begin
      if TargetInAttackRange (TargetCret, targdir) then begin
         if GetCurrentTime - HitTime > GetNextHitTime then begin
            HitTime := GetCurrentTime;
            TargetFocusTime := GetTickCount;
            //자폭....
            DoSelfExplosion;
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

procedure TExplosionSpider.Run;
begin
   if (not Death) and (not BoGhost) then begin
      if GetTickCount - maketime > 1 * 60 * 1000 then begin  //자폭
         maketime := GetTickCount;
         DoSelfExplosion;
      end;
   end;
   inherited Run;
end;


{--------------------------------------------------------------}
// TGuardUnit

procedure TGuardUnit.Struck (hiter: TCreature);
begin
   inherited Struck (hiter);
   if Castle <> nil then begin
      hiter.BoCrimeforCastle := TRUE;
      hiter.CrimeforCastleTime := GetTickCount;
   end;
end;

function  TGuardUnit.IsProperTarget (target: TCreature): Boolean;
begin
   Result := FALSE;
   if Castle <> nil then begin
      if LastHiter = target then Result := TRUE;

      if target.BoCrimeforCastle then begin
         if GetTickCount - target.CrimeforCastleTime < 2 * 60 * 1000 then begin //5분
            Result := TRUE;
         end else
            target.BoCrimeforCastle := FALSE;
         if TCreature(target).Castle <> nil then begin
            target.BoCrimeforCastle := FALSE;
            Result := FALSE;
         end;
      end;

      //기본 공격 모드 (공성전에만 적을 공격하는 모드)
      if TUserCastle(Castle).BoCastleUnderAttack then begin
         Result := TRUE;
      end;

      if TUserCastle(Castle).OwnerGuild <> nil then begin
         if target.Master = nil then begin
            if ((TUserCastle(Castle).OwnerGuild = target.MyGuild) or
               TUserCastle(Castle).OwnerGuild.IsAllyGuild (TGuild(target.MyGuild))) and
               (LastHiter <> target)
            then
               Result := FALSE;
         end else begin
            if ((TUserCastle(Castle).OwnerGuild = target.Master.MyGuild) or
               TUserCastle(Castle).OwnerGuild.IsAllyGuild (TGuild(target.Master.MyGuild))) and
               (LastHiter <> target.Master) and
               (LastHiter <> target)
            then
               Result := FALSE;
         end;
      end;
      
      if target.BoSysopMode or
         target.BoStoneMode or
         (target.RaceServer >= RC_NPC) and (target.RaceServer < RC_ANIMAL) or
         (target = self) or
         (TCreature(target).Castle = self.Castle)
      then  //운영자, 석상,...
          Result := FALSE;

   end else begin
      ///Result := inherited IsProperTarget (target);

      //자신을 때린놈
      if LastHiter = target then Result := TRUE;

      //같은 궁병을 공격하는 놈을 공격
      if target.TargetCret <> nil then
         if target.TargetCret.RaceServer = RC_ARCHERGUARD then
            Result := TRUE;

      if target.PKLevel >= 2 then begin  //궁수는 빨갱이를 공격한다.
         Result := TRUE;
      end;

      if target.BoSysopMode or target.BoStoneMode or (target = self) then  //운영자, 석상,...
          Result := FALSE;
   end;
end;



{--------------------------------------------------------------}
// TArcherGuard

constructor TArcherGuard.Create;
begin
   inherited Create;
   ViewRange := 12;
   WantRefMsg := TRUE;
   Castle := nil;
   OriginDir := -1;
   RaceServer := RC_ARCHERGUARD;
end;

//반드시 target <> nil
procedure TArcherGuard.ShotArrow (targ: TCreature);
var
   dam, armor: integer;
begin
   if targ = nil then exit;

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
      targ.SetLastHiter (self);
      targ.ExpHiter := nil; //경험치를
      targ.StruckDamage (dam, self);
      targ.SendDelayMsg (TCreature(RM_STRUCK), RM_REFMESSAGE, dam{wparam},
               targ.WAbil.HP{lparam1}, targ.WAbil.MaxHP{lparam2}, Longint(self){hiter}, '', 600 + _MAX(Abs(CX-targ.CX),Abs(CY-targ.CY)) * 50);
   end;
   SendRefMsg (RM_FLYAXE, Dir, CX, CY, Integer(targ), '');
end;

procedure TArcherGuard.Run;
var
   i, d, dis: integer;
   cret, nearcret: TCreature;
begin
   dis := 9999;
   nearcret := nil;
//   if not Death and not BoGhost and
//      (StatusArr[POISON_STONE] = 0) and (StatusArr[POISON_ICE] = 0) and
//      (StatusArr[POISON_STUN] = 0) then begin
     if IsMoveAble then begin
      if GetCurrentTime - WalkTime > GetNextWalkTime then begin
         WalkTime := GetCurrentTime;
         for i:=0 to VisibleActors.Count-1 do begin
            cret := TCreature (PTVisibleActor(VisibleActors[i]).cret);
            if (not cret.Death) and (IsProperTarget(cret)) then begin
               d := abs(CX-cret.CX) + abs(CY-cret.CY);
               if d < dis then begin
                  dis := d;
                  nearcret := cret;
               end;
            end;
         end;
         if nearcret <> nil then begin
            SelectTarget (nearcret);
         end else begin
            LoseTarget;
         end;
      end;
      if TargetCret <> nil then begin
         if GetCurrentTime - HitTime > GetNextHitTime then begin
            HitTime := GetCurrentTime;
            ShotArrow (TargetCret);
         end;
      end else begin
         if OriginDir >= 0 then
            if OriginDir <> Dir then
               Turn (OriginDir);
      end;
   end;
   inherited Run;

end;


{--------------------------------------------------------------}
// TArcherMaster

constructor TArcherMaster.Create;
begin
   inherited Create;
   ViewRange := 12;
end;

//반드시 target <> nil
procedure TArcherMaster.ShotArrow (targ: TCreature);
var
   dam, armor: integer;
begin
   if targ = nil then exit;

   //시야 범위 내 타겟만 공격
   if not ( (abs(CX-targ.CX) <= ViewRange) and (abs(CY-targ.CY) <= ViewRange) ) then exit;

   if (not targ.Death) and IsProperTarget(targ) then begin
      Dir := GetNextDirection (CX, CY, targ.CX, targ.CY);
      //타겟 레벨에 따른 데미지 조정
      if (MultiplyTargetLevelMin > 0) and (MultiplyTargetLevelMin > 0) then begin
         with WAbil do
            dam := Trunc(targ.Abil.Level * MultiplyTargetLevelMin div 100) + Lobyte(DC) + Random((Trunc(targ.Abil.Level * MultiplyTargetLevelMax div 100) + Hibyte(DC)-Lobyte(DC)) + 1);
      end else begin
         with WAbil do
            dam := Lobyte(DC) + Random(SmallInt(Hibyte(DC)-Lobyte(DC)) + 1);
      end;
      if dam > 0 then begin
         //armor := (Lobyte(targ.WAbil.AC) + Random(ShortInt(Hibyte(targ.WAbil.AC)-Lobyte(targ.WAbil.AC)) + 1));
         //dam := dam - armor;
         //if dam <= 0 then
         //   if dam > -10 then dam := 1;
         dam := targ.GetHitStruckDamage (self, dam);
      end;
      if dam > 0 then begin
         targ.SetLastHiter (self);
         targ.ExpHiter := nil; //경험치를
         targ.StruckDamage (dam, self);
         targ.SendDelayMsg (TCreature(RM_STRUCK), RM_REFMESSAGE, dam{wparam},
                  targ.WAbil.HP{lparam1}, targ.WAbil.MaxHP{lparam2}, Longint(self){hiter}, '', 600 + _MAX(Abs(CX-targ.CX),Abs(CY-targ.CY)) * 50);
      end;
      SendRefMsg (RM_FLYAXE, Dir, CX, CY, Integer(targ), '');
   end;
end;

function  TArcherMaster.AttackTarget: Boolean;
var
   i, pwr: integer;
   cret: TCreature;
   targdir: byte;
begin
   Result := FALSE;
   if GetCurrentTime - HitTime > GetNextHitTime then begin
      HitTime := GetCurrentTime;
      ShotArrow(TargetCret);
   end;
   Result := TRUE;
end;

procedure TArcherMaster.Run;
var
   i, dis, d: integer;
   cret, nearcret: TCreature;
   nx, ny: integer;
begin
   dis := 9999;
   nearcret := nil;
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

      AttackTarget;

      if GetCurrentTime - WalkTime > GetNextWalkTime then begin
         //상속받은 run에서 WalkTime 재설정함
         if TargetCret <> nil then
            if (abs(CX-TargetCret.CX) <= 4) and (abs(CY-TargetCret.CY) <= 4) then begin
               if (abs(CX-TargetCret.CX) <= 2) and (abs(CY-TargetCret.CY) <= 2) then begin
                  if Random(3) = 0 then begin
                     //너무 가까우면 도망감.
                     GetBackPosition (self, TargetX, TargetY);
                     if TargetX <> -1 then begin //가야할 곳이 있음
                        GotoTargetXY;
                     end;
                  end;
               end;
            end else if (abs(CX-TargetCret.CX) > 5) or (abs(CY-TargetCret.CY) > 5) then begin
               if Random(2) = 0 then begin
                  Dir := GetNextDirection (CX, CY, TargetCret.CX, TargetCret.CY);
                  //너무 멀면 가까이 감.
                  if GetNextPosition (PEnvir, CX, CY, Dir, 1, nx, ny) then begin
                     TargetX := nx;
                     TargetY := ny;
                     GotoTargetXY;
                  end;
               end;
            end;
      end;
   end;
   inherited Run;
end;


{--------------------------------------------------------------}
//궁수경찰

constructor TArcherPolice.Create;
begin
   inherited Create;
   RaceServer := RC_ARCHERPOLICE;  //평화모드로 공격이 안되게
end;


{--------------------------------------------------------------}
//성문, 성벽

constructor TCastleDoor.Create;
begin
   inherited Create;
   BoAnimal := FALSE;
   StickMode := TRUE;
   BoOpenState := FALSE; //닫힌 상태
   AntiPoison := 200;
   //HideMode := TRUE;  //생성 당시는 안보이는 모드임
end;

procedure TCastleDoor.Initialize;
begin
   Dir := 0;  //초기상태
   inherited Initialize;
   if WAbil.HP > 0 then begin
      if BoOpenState then ActiveDoorWall (dsOpen)
      else ActiveDoorWall (dsClose);
   end else
      ActiveDoorWall (dsBroken);
end;

//새로 고쳐짐
procedure TCastleDoor.RepairStructure;
var
   n, newdir: integer;
begin
   if not BoOpenState then begin
      newdir := 3 - Round (WAbil.HP / WAbil.MaxHP * 3);
      if not (newdir in [0..2]) then newdir := 0;
      Dir := newdir;
      SendRefMsg (RM_ALIVE, Dir, CX, CY, 0, '');
   end;
end;

//사북성문인 경우에만 사용
procedure TCastleDoor.ActiveDoorWall (dstate: TDoorState);
var
   bomove: Boolean;
begin
   PEnvir.GetMarkMovement (CX, CY-2, TRUE);
   PEnvir.GetMarkMovement (CX+1, CY-1, TRUE);
   PEnvir.GetMarkMovement (CX+1, CY-2, TRUE);
   if dstate = dsClose then bomove := FALSE
   else bomove := TRUE;

   PEnvir.GetMarkMovement (CX, CY, bomove);
   PEnvir.GetMarkMovement (CX, CY-1, bomove);
   PEnvir.GetMarkMovement (CX, CY-2, bomove);
   PEnvir.GetMarkMovement (CX+1, CY-1, bomove);
   PEnvir.GetMarkMovement (CX+1, CY-2, bomove);
   PEnvir.GetMarkMovement (CX-1, CY, bomove);
   PEnvir.GetMarkMovement (CX-2, CY, bomove);
   PEnvir.GetMarkMovement (CX-1, CY-1, bomove);
   PEnvir.GetMarkMovement (CX-1, CY+1, bomove);
   if dstate = dsOpen then begin
      PEnvir.GetMarkMovement (CX, CY-2, FALSE);
      PEnvir.GetMarkMovement (CX+1, CY-1, FALSE);
      PEnvir.GetMarkMovement (CX+1, CY-2, FALSE);
   end;
end;

procedure TCastleDoor.OpenDoor;
begin
   if not Death then begin
      Dir := 7; //안보이는 상태
      SendRefMsg (RM_DIGUP, Dir, CX, CY, 0, '');
      BoOpenState := TRUE;
      BoStoneMode := TRUE;  //맞지 않음
      ActiveDoorWall (dsOpen);  //이동가능하게
      HoldPlace := FALSE;  //자리차지 안함
   end;
end;

procedure TCastleDoor.CloseDoor;
begin
   if not Death then begin
      Dir := 3 - Round (WAbil.HP / WAbil.MaxHP * 3);
      if not (Dir in [0..2]) then Dir := 0;
      SendRefMsg (RM_DIGDOWN, {Dir}0, CX, CY, 0, '');
      BoOpenState := FALSE;
      BoStoneMode := FALSE;  //맞음
      ActiveDoorWall (dsClose);  //이동 못하게
      HoldPlace := TRUE;  //자리차지 함
   end;
end;

procedure TCastleDoor.Die;
begin
   inherited Die;
   BrokenTime := GetTickCount;
   ActiveDoorWall (dsBroken);  //이동가능하게
end;

procedure TCastleDoor.Run;
var
   n, newdir: integer;
begin
   if Death and (Castle <> nil) then begin
      DeathTime := GetTickCount;  //없어지지 않는다.
   end else
      HealthTick := 0;  //체력이 다시 차지 않는다.

   if not BoOpenState then begin
      newdir := 3 - Round (WAbil.HP / WAbil.MaxHP * 3);
      if (newdir <> Dir) and (newdir < 3) then begin  //방향 0,1,2
         Dir := newdir;
         SendRefMsg (RM_TURN, Dir, CX, CY, 0, '');
      end;
   end;

   inherited Run;
end;



//---------------------------------------------------------------------
//성벽,

constructor TWallStructure.Create;
begin
   inherited Create;
   BoAnimal := FALSE;
   StickMode := TRUE;
   BoBlockPos := FALSE;
   AntiPoison := 200;
   //HideMode := TRUE;
end;

procedure TWallStructure.Initialize;
begin
   Dir := 0;  //초기상태
   inherited Initialize;
end;

//새로 고쳐짐
procedure TWallStructure.RepairStructure;
var
   n, newdir: integer;
begin
   if WAbil.HP > 0 then newdir := 3 - Round (WAbil.HP / WAbil.MaxHP * 3)
   else newdir := 4;
   if not (newdir in [0..4]) then newdir := 0;
   Dir := newdir;
   SendRefMsg (RM_ALIVE, Dir, CX, CY, 0, '');
end;

procedure TWallStructure.Die;
begin
   inherited Die;
   BrokenTime := GetTickCount;
end;

procedure TWallStructure.Run;
var
   n, newdir: integer;
begin
   if Death then begin
      DeathTime := GetTickCount;  //없어지지 않는다.
      if BoBlockPos then begin
         PEnvir.GetMarkMovement (CX, CY, TRUE);  //이동 가능하게
         BoBlockPos := FALSE;
      end;
   end else begin
      HealthTick := 0;  //체력이 다시 차지 않는다.
      if not BoBlockPos then begin
         PEnvir.GetMarkMovement (CX, CY, FALSE);  //이동 못하게
         BoBlockPos := TRUE;
      end;
   end;

   if WAbil.HP > 0 then newdir := 3 - Round (WAbil.HP / WAbil.MaxHP * 3)
   else newdir := 4;
   if (newdir <> Dir) and (newdir < 5) then begin  //방향 0,1,2,3,4
      Dir := newdir;
      SendRefMsg (RM_DIGUP, Dir, CX, CY, 0, '');  //부서지는 애니메이션
   end;

   inherited Run;
end;


//---------------------------------------------------------------------
// 축구공

constructor TSoccerBall.Create;
begin
   inherited Create;
   BoAnimal := FALSE;
   NeverDie := TRUE;
   GoPower := 0;
   TargetX := -1;
end;

procedure TSoccerBall.Struck (hiter: TCreature);
var
   nx, ny: integer;
begin
   if hiter <> nil then begin
      Dir := hiter.Dir;  //때린사람의 방향으로 공이 간다.
      GoPower := GoPower + 4 + Random (4);
      GoPower := _MIN (20, GoPower);
      GetNextPosition (PEnvir, CX, CY, Dir, GoPower, nx, ny);
      TargetX := nx;
      TargetY := ny;
   end;

end;


procedure TSoccerBall.Run;
var
   i, dis, nx, ny, nnx, nny: integer;
   bohigh: Boolean;
begin
   bohigh := false; // 축구공이 겹치면 안됨 
   if GoPower > 0 then begin
      if GetNextPosition (PEnvir, CX, CY, Dir, 1, nx, ny) then begin
         if not PEnvir.CanWalk (nx, ny, bohigh) then begin  //벽에 부딧힘
            case Dir of
               0: Dir := 4;
               1: Dir := 7;
               2: Dir := 6;
               3: Dir := 5;
               4: Dir := 0;
               5: Dir := 3;
               6: Dir := 2;
               7: Dir := 1;
            end;
            GetNextPosition (PEnvir, CX, CY, Dir, GoPower, nx, ny);
            TargetX := nx;
            TargetY := ny;
         end;
      end;
   end else
      TargetX := -1;

   if TargetX <> -1 then begin
      GotoTargetXY;
      if (TargetX = CX) and (TargetY = CY) then
         GoPower := 0;
   end;

   inherited Run;

end;

{--------------------------------------------------------------}
//호혼석

constructor TStickBlockMonster.Create;
begin
   inherited Create;
   ViewRange := 7;
   DigupRange := 4;
   DigdownRange := 4;
   BoCallFollower := TRUE;
   BoTransparent := FALSE;
   FirstComeOut := TRUE;
   SecondMovement := FALSE;
   DontAttack := TRUE;
   childlist := TList.Create;
   RaceServer := RC_STICKBLOCK;
   FirstStruck := FALSE;
   ComeoutTime := 0;
   TargetDisappearTime := 0;
   Caller := nil;
   OldTargetCret := nil;
   BoAnimal := FALSE;  //썰리지 않도록...
end;

destructor TStickBlockMonster.Destroy;
begin
   childlist.Free;
   inherited Destroy;
end;

function  TStickBlockMonster.FindTarget: Boolean;
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
               //타겟 지정
               TargetCret := cret;
               OldTargetCret := TargetCret;

               Result := TRUE;
               break;
            end;
         end;
      end;
   end;
end;

procedure TStickBlockMonster.Attack (target: TCreature; dir: byte);
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
   SendRefMsg (RM_HIT, self.Dir, CX, CY, Integer(target), '');
   with WAbil do
      pwr := GetAttackPower (Lobyte(DC), SmallInt(Hibyte(DC)-Lobyte(DC)));
   if pwr <= 0 then exit;

   rlist := TList.Create;
   GetMapCreatures (PEnvir, target.CX, target.CY, wide, rlist);
   for i:=0 to rlist.Count-1 do begin
      cret := TCreature (rlist[i]);
      if IsProperTarget(cret) then begin
         SelectTarget (cret);
         cret.SendRefMsg (RM_NORMALEFFECT, 0, cret.CX, cret.CY, NE_SOULSTONE_HIT, '');
         cret.SendDelayMsg (self, RM_MAGSTRUCK, 0, pwr, 0, 0, '', 600);
      end;
   end;
   rlist.Free;

end;

function  TStickBlockMonster.AttackTarget: Boolean;
var
   i, pwr: integer;
   cret: TCreature;
   targdir: byte;
begin
   Result := FALSE;
   if DontAttack then exit;

   if FindTarget then begin
      //처음 타겟을 바꾸지 않음.
      if OldTargetCret <> TargetCret then TargetCret := OldTargetCret;

      if TargetCret <> nil then begin
         if TargetInAttackRange (TargetCret, targdir) then begin
            if GetCurrentTime - HitTime > GetNextHitTime then begin
               HitTime := GetCurrentTime;

               if Random(8) = 0 then begin
                  TargetCret.MakePoison (POISON_STONE, 5{시간,초}, 0);
               end else begin
                  Attack(TargetCret, targdir);
               end;
               Result := TRUE;
            end;
         end;
      end;
   end;
end;

procedure TStickBlockMonster.ComeOut;
begin
   inherited ComeOut;
   if BoCallFollower then begin
      if FindTarget then begin
         if TargetCret <> nil then begin
            if FirstComeOut then begin
               FirstComeOut := FALSE;
               SecondMovement := TRUE;
               TargetCret.MakePoison (POISON_STONE, 5{시간,초}, 0);
            end;
         end;
      end;
   end;
end;

procedure TStickBlockMonster.ComeDown;
begin
   //처리 안함.
end;

procedure TStickBlockMonster.CallFollower;
const
   MAX_FOLLOWERS = 2;
var
   i, nx, ny, dx, dy: integer;
   monname: string;
   mon: TCreature;
   followers: array[0..MAX_FOLLOWERS-1] of string;
begin
   if TargetCret <> nil then begin
      nx := TargetCret.CX;
      ny := TargetCret.CY;

      //젠시킬 몬스터이름
      followers[0] := UserName;
      followers[1] := '11';//'호혼석00';   //이미지 안보임

      for dx:=-1 to 1 do begin
         for dy:=-1 to 1 do begin
            if ((nx + dx = CX) and (ny + dy = CY)) or ((nx + dx = TargetCret.CX) and (ny + dy = TargetCret.CY)) then continue;

            //대각선
            if abs(dx) = abs(dy) then begin
               monname := followers[1];
            end else begin
               monname := followers[0];
            end;
            if PEnvir.CanWalk( nx + dx, ny + dy, FALSE ) then begin
               mon := UserEngine.AddCreatureSysop (MapName, nx + dx, ny + dy, monname);
               if mon <> nil then begin
                  // 같은 종류의 몬스터이면
                  if mon.RaceServer = RC_STICKBLOCK then begin
                     TStickBlockMonster(mon).BoCallFollower := FALSE;
                     //투명몬스터 설정
                     if mon.UserName = followers[1] then begin
                        TStickBlockMonster(mon).BoTransparent := TRUE;
                     end;
                     TStickBlockMonster(mon).ComeOut;
                     TStickBlockMonster(mon).Caller := self;
                     childlist.Add (mon);
                  end;
               end;
            end;
         end;
      end;
      self.ComeOut;
   end;
end;

procedure TStickBlockMonster.Die;
var
   i: integer;
begin
   inherited Die;
   if BoCallFollower then begin
      for i:=childlist.Count-1 downto 0 do begin
         if not TCreature(childlist[i]).Death then begin
            TCreature(childlist[i]).LastHiter := nil;
            TCreature(childlist[i]).ExpHiter := nil;
            TCreature(childlist[i]).BoNoitem := TRUE; //꼬봉 호혼석은 아이템을 안떨구게(sonmg 2005/10/21)
            TCreature(childlist[i]).Die;
         end;
      end;
   end;
end;

procedure TStickBlockMonster.RunMsg (msg: TMessageInfo);
var
   nx, ny: integer;
   monname: string;
   mon: TCreature;
   i: integer;
   check: Boolean;
   hiter : TCreature;
begin
   hiter := nil;
   case msg.Ident of
      RM_REFMESSAGE:
         begin
            if Integer(msg.Sender) = RM_STRUCK then begin
               check := FALSE;

               hiter := TCreature(msg.lParam3);

               if (hiter <> nil) and (hiter.RaceServer = RC_USERHUMAN) then begin
                  //메인 몹이 맞았을 때 follower들 중에 먼저 맞은 넘이 없으면 바로 죽음
                  if BoCallFollower then begin
                     for i:=0 to childlist.count-1 do begin
                        if TStickBlockMonster(childlist[i]).FirstStruck then begin
                           check := TRUE;
                        end;
                     end;
                     if (not check) and (DontAttack) then begin
                        if not Death then begin
                           FirstStruck := TRUE;
                           Die;
{$IFDEF DEBUG}
//UserEngine.CryCry (RM_CRY, PEnvir, CX, CY, 10000, ' 빙고! : ' + TargetCret.UserName);//test
{$ENDIF}
                        end;
                     end;
                     DontAttack := FALSE;
                  end else begin
                     WAbil.HP := WAbil.MaxHP;
                     if not BoTransparent then begin
                        //follower가 맞았을 때 메인 몹이 먼저 맞지 않았으면 FirstStruck TRUE로 셋팅
                        //(뢰혼격으로 꼬셔지는가?)
                        if (Caller <> nil) and (Caller.RaceServer = RC_STICKBLOCK) and not TStickBlockMonster(Caller).FirstStruck then begin
                           FirstStruck := TRUE;
                           //메인 몹 공격 모드로
                           TStickBlockMonster(Caller).DontAttack := FALSE;
                        end;
                     end;
                  end;
               end;
            end;
         end;
      RM_MAGSTRUCK:
         begin
            if BoCallFollower then begin
               DontAttack := FALSE;
            end else begin
               WAbil.HP := WAbil.MaxHP;
               exit;
            end;
         end;
   end;
   inherited RunMsg (msg);
end;

procedure TStickBlockMonster.Struck (hiter: TCreature);
begin
{
   if not BoCallFollower then begin
      WAbil.HP := WAbil.MaxHP;
      exit;
   end else begin
      DontAttack := FALSE;
   end;
}

   inherited Struck(hiter);
end;

procedure TStickBlockMonster.Run;
var
   i, dis, d, nx, ny: integer;
   cret, nearcret: TCreature;
   targdir: byte;
begin
   //처음 타겟을 바꾸지 않음.
   if OldTargetCret <> TargetCret then TargetCret := OldTargetCret;

   if GetCurrentTime - WalkTime > GetNextWalkTime then begin
      if BoCallFollower and (not Death) then begin
         if (Caller <> nil) and (Caller.RaceServer = RC_STICKBLOCK) and not TStickBlockMonster(Caller).DontAttack then begin
            DontAttack := FALSE;
         end;
         if TargetCret <> nil then begin
            if (not FirstComeOut) and SecondMovement then begin
               SecondMovement := FALSE;
               case Random(4) of
               0: begin
                     nx := 0;
                     ny := -1;
                  end;
               1: begin
                     nx := 0;
                     ny := 1;
                  end;
               2: begin
                     nx := -1;
                     ny := 0;
                  end;
               else
                  begin
                     nx := 1;
                     ny := 0;
                  end;
               end;
               SpaceMove ( MapName, TargetCret.CX + nx, TargetCret.CY + ny, 2);
               CallFollower;  //부하들을 불러냄
               ComeoutTime := GetTickCount;
            end;

            //시간이 흐르면
            if (ComeoutTime <> 0) and (GetTickCount - ComeoutTime > 10000) then begin
               //메인 몹 공격 모드로
               if DontAttack then
                  DontAttack := FALSE;
            end;
         end;

         if DontAttack = FALSE then begin
            if TargetCret <> nil then begin
               if not TargetInAttackRange (TargetCret, targdir) then begin
                  if (TargetDisappearTime = 0) then begin
                     if (ComeoutTime <> 0) and (GetTickCount - ComeoutTime > 15000) then begin
                        TargetDisappearTime := GetTickCount;
                     end;
                  end;
               end;
            end else begin
               if (TargetDisappearTime = 0) then begin
                  if (ComeoutTime <> 0) and (GetTickCount - ComeoutTime > 15000) then begin
                     TargetDisappearTime := GetTickCount;
                  end;
               end;
            end;

            if (TargetDisappearTime <> 0) and (GetTickCount - TargetDisappearTime > 10000) then begin
               if not Death then begin
                  FirstStruck := TRUE;
                  Die;
               end;
            end;
         end;
      end;
   end;

   inherited Run;
end;


end.
