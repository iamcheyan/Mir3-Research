unit DragonSystem;

interface

uses
  Windows, Messages, SysUtils, Classes, Graphics, Controls, Dialogs,
  Grobal2 , Hutil32, Envir , usrengn ,objBase;

  const
    DRAGON_MAX_LEVEL    =13;
    DRAGON_RESETTIME    = 15 * 60 * 1000; // 최대 15분간은 레셋되지않는다.
    MAP_ATTACK_TIME     = 10 * 1000 ;   // 멥에있는 사람들에게 공격하는 시간
    DRAGONITEMFILE      = 'DragonItem.txt';

  type
     // 아이템 드롭정보
     TDropItemInfo  = record
        Name        : string;
        FirstRate   : integer;
        SecondRate  : integer;
        Amount      : integer;
        DropCount   : integer;
     end;
     PTDropItemInfo = ^TDropItemInfo;

     // 용의 레벨정보
     TDragonLevelInfo = record
        Level       :   integer;
        DropExp     :   integer;
        DropItemList:   TList;
     end;

     TATMapInfo    = record
        Envir       : TEnvirnoment;
        Mode        : integer;   // 1= 번개 , 2= 지염같은 번개
     end;
     PTATMapInfo = ^TATMapInfo;

     TDragonSystem = class(TObject)
      private
        //초기에 로딩되었던 화일이름 리로드시에 사용
        FInitFileName       : string;
        //레벨 정보 드라곤은 13레벨까지 되어있다.
        FLevelInfo          : array [0..DRAGON_MAX_LEVEL-1] of TDragonLevelInfo;

        FLevel              :integer;
        FExp                :integer;

        FLastChangeExpTime  : LONGWORD; // 마지막 경험치 변경시간
        FLastAttackTme      : LONGWORD; // 마지막으로 맵에 자동공격한 시간

        // 번개및 불을 떨구는맵
        FAutoAttackMap      : TList;

        FDropMapName        : string;
        FDopItemEnvir       : TEnvirnoment;
        FDropItemRect       : TRect;

        procedure   RemoveAll;
        procedure   InitFirst;
        function    DecodeStrInfo( StrInfo : TStringList ; var IsSuccess :Boolean ):String;
        function    GetNextLevelExp:integer;
        procedure   ResetLevel;

      protected
      public
        constructor Create;
        destructor  Destroy; override;
        function    Initialize( FileName : String ; var IsSuccess : Boolean ):string;
        function    Reload( var IsSuccess : Boolean ):string;
        procedure   SetAutoAttackMap( Envir_ : TEnvirnoment ; Mode_ : integer);
        procedure   SetItemDropMap( MapName: string ; Area_ : TRect);

        procedure   ChangeExp(exp : integer);
        procedure   Run;

        procedure   OnLevelup( changelevel : integer ); // 레벨업이 되었을떄 해야한는것
        procedure   OnDropItem( changelevel : integer); // 아이템 드롭시
        procedure   OnMapAutoAttack;                    // 맵에있는사람들 자동공격
        procedure   OnAutoAttack( Envir_ : TEnvirnoment ; Mode_ : integer);
        procedure   OnAttackTarget( Envir_ : TEnvirnoment ;user_ : TCreature ; Mode_ :integer);

      end;

implementation

uses
    svMain;
constructor TDragonSystem.Create;
var
   RetSuccess: Boolean;
begin
   inherited ;

   // 기본값으로 초기화
   InitFirst;

   Initialize( FInitFileName, RetSuccess );

   if RetSuccess = FALSE then
      ;  //MainOutMessage('TDragonSystem Initialization Failure');
end;

destructor TDragonSystem.Destroy;
begin

   RemoveAll;

   inherited ;
end;

// 시스템이 생성될때 처음 초기화 하는부분
//  메모리를 모두 지운다음에도 사용할수 있다.
procedure TDragonSystem.InitFirst;
var
   i : integer;
begin

   try
      // 초기 정보 입력
      for i := 0 to DRAGON_MAX_LEVEL -1 do
      begin
           FLevelInfo[i].Level        := i+1;
           FLevelInfo[i].DropExp      := (i+1) * 10000;
           FLevelInfo[i].DropItemList := TList.Create;
      end;

      FAutoAttackMap   := TList.Create;
   except
   end;

   // 드롭아이템이 떨어지는 맵
   FDopItemEnvir        := nil;
   // 떨어지는곳 초기화
   FDropItemRect.Left   := -1;
   FDropItemRect.Top    := -1;
   FDropItemRect.Right  := -1;
   FDropItemRect.Bottom := -1;


   FLevel       := 1;
   FExp         := 0;

   FLastChangeExpTime  := GetTickCount; // 마지막 경험치 변경시간
   FLastAttackTme      := GetTickCount; // 마지막으로 맵에 자동공격한 시간

   FInitFileName := {EnvirDir +} DRAGONITEMFILE;

end;

// 메모리상의 모든것을 지운다
procedure TDragonSystem.RemoveAll;
var
    i,j : integer;
begin

   try
    for i := 0 to DRAGON_MAX_LEVEL -1 do
    begin
        // 정상적으로 초기화 되어있으면
        if FLevelInfo[i].DropItemList <> nil then
        begin
            // 아이템리스트의 오브젝트 지운다.
            for j := FLevelInfo[i].DropItemList.Count -1 downto 0 do
            begin
                // 객체 메모리 해제
                dispose ( FLevelInfo[i].DropItemList[0] );
                // 리스트삭제
                FLevelInfo[i].DropItemList.Delete(0);
            end;
            // 리스트 Free
            FLevelInfo[i].DropItemList.Free;
            FLevelInfo[i].DropItemList := nil;

        end;
    end;
   except
   end;

   try
    // 번개맵 초기화
    for i := 0 to FAutoAttackMap.count -1 do
    begin
        dispose ( FAutoAttackMap[0]);
        FAutoAttackMap.Delete(0);
    end;
    FAutoAttackMap.Free;
    FAutoAttackMap := nil;
   except
   end;


end;

function TDragonSystem.DecodeStrInfo( StrInfo : TStringList ; var IsSuccess : Boolean ):String;
var
    i               : integer;
    str ,str1, str2, str3  : string;
    infostr         : string;
    CurrentLevel    : integer;
    CurrentExp      : integer;
    pDropItemInfo   : PTDropItemInfo;
    levelCount      : integer;
    expcount        : integer;
    itemcount       : integer;
begin
    Result := '';
    IsSuccess := false;

    levelcount := 0;
    expcount  := 0;
    levelcount := 0;
    ItemCount := 0;

    CurrentLevel := 1;
    CurrentExp   := 10000;

    try
       for i := 0 to StrInfo.Count -1 do
       begin
           str := Trim( StrInfo.Strings[i] );

           if ( str <> '' ) and ( str[1] <> ';' ) then
           begin
               infostr := str[1];

               // 처음문자가 명령어문자일경우에
               if infostr = '!' then
               begin
                     str2 := GetValidStr3 (str, str1, [' ', #9]);

                     //레벨변경자
                     if CompareText( str1, '!LEVEL' ) = 0 then
                     begin
                       CurrentLevel := Str_ToInt( Trim(Str2),1 );
                       //레벨의 최대최소값을 넘으면 에러
                       if ( CurrentLevel <= 0 ) and ( CurrentLevel > DRAGON_MAX_LEVEL ) then
                       begin
                           Result := '['+IntTostr(i+1)+'] '+'ERROR! LevelInfo Worng 1~'+IntToStr(DRAGON_MAX_LEVEL)+':'+str2;
                           Exit;
                       end;
                       inc ( levelcount );
                     end
                     else if CompareText( str1, '!EXP' ) = 0 then // 경험치 표시자
                     begin
                       CurrentExp := Str_ToInt( Trim(str2) ,0 ) ;

                       if CurrentExp > 0 then
                       begin
                          FLevelInfo[CurrentLevel -1].DropExp := CurrentExp;
                          inc ( expcount );
                       end
                       else // 경험치가 0보다작거나 0이면 안됨
                       begin
                           Result := '['+IntTostr(i+1)+'] '+'ERROR! ExpInfo Worong Exp < 0:'+str2;
                           Exit;
                       end;
                     end
                     else if CompareText( str1, '!DROPMAP' ) = 0 then
                     begin
                          FDropMapName := Trim(str2);
                     end
                     else if CompareText(str1, '!DROPAREA' ) = 0 then
                     begin
                         str2 := GetValidStr3 (str2, str3, [' ', #9]);
                         FDropItemRect.Left := Str_ToInt( str3, -1 );
                         str2 := GetValidStr3 (str2, str3, [' ', #9]);
                         FDropItemRect.Top := Str_ToInt( str3, -1 );
                         str2 := GetValidStr3 (str2, str3, [' ', #9]);
                         FDropItemRect.Right := Str_ToInt( str3, -1 );
                         str2 := GetValidStr3 (str2, str3, [' ', #9]);
                         FDropItemRect.Bottom := Str_ToInt( str3, -1 );
                     end
                     else
                     begin // 그밖에 다른 글자면 안됨.
                       Result := '['+IntTostr(i+1)+'] '+'ERROR! Check String :'+str1 ;
                     end;
               end
               else
               begin
                   new( pDropItemInfo );

                   // 아이템이름
                   str2 := GetValidStr3 (str, str1, [' ', #9]);
                   pDropItemInfo.Name := trim(str1);

                   // 분자의 확률값
                   str2 := GetValidStr3 (str2, str1, [' ', #9]);
                   pDropItemInfo.FirstRate := Str_ToInt( str1,0 );

                   //분모의 확률값
                   str2 := GetValidStr3 (str2, str1, [' ', #9]);
                   pDropItemInfo.SecondRate := Str_ToInt( str1,1);

                   // 양
                   str2 := GetValidStr3 (str2, str1, [' ', #9]);
                   pDropItemInfo.Amount := Str_ToInt( str1,1);

                   // 드롭횟수
                   str2 := GetValidStr3 (str2, str1, [' ', #9]);
                   pDropItemInfo.DropCount := Str_ToInt( str1,1);

                   FLevelInfo[CurrentLevel -1].DropItemList.Add( pDropItemInfo );

                   inc(itemcount);

               end;

           end;// 무시스트링인경우

       end;//for i...
    except
    end;

    IsSuccess := true;
    Result := 'READ SUCCESS Level:'+IntToStr(LevelCount) +' ,Exp:'+IntToStr(ExpCount) +' ,ITEM' + IntToStr(ItemCount)+
              ' DROPMAP: '+FDropMapName+'DROPAREA: '+
              ' X1:'+intToStr( FDropItemRect.Left) +','+
              ' Y1:'+intToStr( FDropItemRect.Top) +','+
              ' X2:'+intToStr( FDropItemRect.Right) +','+
              ' Y2:'+intToStr( FDropItemRect.Bottom);

end;

function TDragonSystem.Initialize( FileName : String ; var IsSuccess : Boolean ):string;
var
    fileinfo    : TStringList;
begin
    Result :='';
    IsSuccess := FALSE;

    try
       // 화일이 존재하는지 알아본다.
       if not FileExists( FileName ) then
       begin
           Result := self.ClassName + '|Do not Find FileName:'+FileName;
           Exit;
       end;

       fileinfo := TStringList.Create;
       fileinfo.LoadFromFile( FileName );

       // 화일을 레코드에 넣는다.
       Result := DecodeStrInfo( fileinfo , IsSuccess );

       fileinfo.Free;
    except
    end;
end;

function TDragonSystem.reload( var IsSuccess : Boolean ):string;
begin
    RemoveAll;
    InitFirst;
    Result := Initialize( FInitFileName, IsSuccess );
end;

function  TDragonSystem.GetNextLevelExp:integer;
begin
    if ( FLEVEL > 0 ) and ( FLEVEL <= DRAGON_MAX_LEVEL ) then
        result := ( FLevelInfo[FLEVEL -1].DropExp ) // div 100
    else
        result := $7FFFFFFF;
end;

procedure TDragonSystem.OnLevelup( changelevel : integer );
begin

   // 아이템을 떨군다.
   OnDropItem( changelevel );

end;

// 아이템을 맵에 떨궈야 할때..
procedure TDragonSystem.OnDropItem( changelevel : integer );
var
   i , j ,px,py: integer;
   pinfo   : PTDropItemInfo;
   slope1, slope2, slope3, slope4: integer;
   LowValue, HighValue: integer;
   itemmakeindex : integer;
begin
   if ( changelevel < 1 ) or ( changelevel >= 13 ) then exit;

   for i := 0 to  FLevelInfo[changelevel -1].DropItemList.count -1 do
   begin
      pinfo  := PTDropItemInfo( FLevelInfo[changelevel -1].DropItemList[i] ) ;

      for j := 0 to  pinfo.DropCount -1 do
      begin
         if random( pinfo.secondrate) < pinfo.FirstRate then
         begin
            px := random( abs(FDropItemRect.Right - FDropItemRect.Left) +1 ) + FDropItemRect.Left;
            // Old Code...(직사각형)
//            py := random( abs(FDropItemRect.Bottom - FDropItemRect.Top ) ) + FDropItemRect.Top;

            // 대각선 영역으로 조정(sonmg)
            // 대각선 영역을 구성하는 네 직선의 기울기를 구한다.
            slope1 := FDropItemRect.Left + FDropItemRect.Top + 4; // 121
            slope2 := FDropItemRect.Right + FDropItemRect.Bottom - 4;   // 133
            slope3 := FDropItemRect.Top - FDropItemRect.Left - 4; // -33
            slope4 := FDropItemRect.Bottom - FDropItemRect.Right + 4;   // -25
            // 정해진 x좌표(px)에서 가능한 y좌표(py) 범위를 구한다.
            LowValue := _MAX(slope1 - px, px + slope3);
            HighValue := _MIN(slope2 - px, px + slope4);
//            LowValue := _MAX(77 + 44 - px, px - 83 + 50);
//            HighValue := _MIN(79 + 54 - px, px - 73 + 48);
            // 정해진 범위 내에서 Random 한 y좌표를 구한다.
            py := Random( HighValue - LowValue +1 ) + LowValue;
            itemmakeindex := 0;
            itemmakeindex := UserEngine.MakeItemToMap(FDropMapName,pinfo.Name ,pinfo.Amount, px, py);

            if itemmakeindex <> 0 then
            begin

               AddUserLog ('15'#9 + //떨굼_
                           FDropMapName + ''#9 +
                           IntToStr(px) + ''#9 +
                           IntToStr(py) + ''#9 +
                        {$IFDEF KOREA}
                           '파천마룡' + ''#9 +
                        {$ELSE}
                           'EvilMir' + ''#9 +
                        {$ENDIF}
                           pInfo.Name + ''#9 +
                           IntToStr(itemmakeindex) + ''#9 +
                           '0' + ''#9 +
                           '0');

//               MainOutMessage('DRAGON GIVE ITEM MAP:('+IntTOStr(changelevel)+')'+FDropMapName +
//                  'ITEMNAME:'+pinfo.Name +'AMOUNT:'+intToStr(pInfo.Amount)+'X:'+
//                  IntTOStr(px )+'Y:'+IntToStr(py));

            end;
         end;
      end;

   end;
end;

procedure TDragonSystem.OnAttackTarget( Envir_ :TEnvirnoment; user_ : TCreature ; Mode_ : integer );
var
    pwr , dam : integer;
begin
    if ( not user_.Death ) and
       ( not user_.BoGhost ) and
       ( not user_.BoSysopMode ) and
       ( not user_.BoSuperviserMode )
    then
    begin

      // 이펙트 날려주고...
      case Mode_ of
      1: user_.SendRefMsg (RM_NORMALEFFECT, 0, user_.CX, user_.CY, NE_THUNDER, '');
      2: user_.SendRefMsg (RM_NORMALEFFECT, 0, user_.CX, user_.CY, NE_FIRE, '');
      end;

      // 데미지 계산후 내려준다.
      pwr := 20 * (random(3)+1);
      dam := user_.GetMagStruckDamage (nil, pwr);
      user_.StruckDamage (dam, nil);
      user_.SendDelayMsg (TCreature(RM_STRUCK), RM_REFMESSAGE, dam{wparam},
      user_.WAbil.HP{lparam1}, user_.WAbil.MaxHP{lparam2}, Longint(nil){hiter}, '', 200);

    end;

end;

procedure TDragonSystem.OnAutoAttack( Envir_ : TEnvirnoment ; Mode_ : integer);
var
    userlist    : TList;
    usercount   : integer;
    i           : integer;
    Tempuser    : TCreature;
begin
    userlist := TList.Create;
    usercount := UserEngine.GetAreaAllUsers( Envir_ , userlist);

    for i := 0 to userlist.count -1 do
    begin
        Tempuser := TCreature( UserList[i]);

        // 사람만 공격한다.
        if TempUser.RaceServer = RC_USERHUMAN then
        begin
           //랜덤값에 걸리면 공격하자
           if  random( 2 ) = 0 then
           begin
                onAttacktarget( Envir_ , Tempuser ,Mode_);
           end;
        end;
    end;

    userlist.Clear;
    userlist.Free;
end;

//맵에 자동공격할때
procedure TDragonSystem.OnMapAutoAttack;
var
    i : integer;
    pmapinfo : PTATMapInfo;
begin
    for i := 0 to FAutoAttackMap.Count -1 do
    begin
        pmapinfo := FAutoAttackMap[i];

        OnAutoAttack( pmapinfo.Envir , pmapinfo.Mode );
    end;
end;

// 자동공격맵에대한 설정을한다.
procedure TDragonSystem.SetAutoAttackMap( Envir_ : TEnvirnoment ; Mode_ : integer);
var
    pmapinfo : PTATMapInfo;
begin

    if FAutoAttackMap <> nil then
    begin
        new( pmapinfo );
        pmapinfo.Envir  := Envir_;
        pmapinfo.Mode   := Mode_;

        FAutoAttackMap.Add( pmapinfo );

    end;
end;

// 아이템이 떨어지는 맵과 지역을 설정한다.
procedure TDragonSystem.SetItemDropMap( MapName : string ; Area_ : TRect);
begin

    FDopItemEnvir := GrobalEnvir.GetEnvir( FDropMapName );
    FDropItemRect := Area_;

end;

// 용이 맞는경우 경험치가 증가한다.
procedure TDragonSystem.ChangeExp( exp : integer);
begin
    FLastChangeExpTime := GetTickCount;
    // 최대 레벨보다 작을때..
    if FLevel < DRAGON_MAX_LEVEL then
    begin

      if exp > 0 then
      begin
          if FEXP < GetNextLevelExp then
          begin
            FEXP := FEXP + exp;


            if FEXP >= GetNextLevelExp then
            begin
                //레벨업이 되었으니 아이템을 떨궈주자.(위치수정 sonmg 2006/01/27)
                OnLevelup(FLEVEL);

                FLEVEL := FLEVEL + 1;
                FEXP  := 0;

                MainOutMessage( 'DRAGON LEVELUP LEVEL:'+IntToStr( FLEVEL ));

            end;

          end; //FEXP <
      end;

    end;
end;

// 일정한 시간이 지나면 레벨이 초기화 된다.
procedure TDragonSystem.ResetLevel;
begin
    if (FLevel <> 1) or (FEXP <> 0) then
    begin
      FLevel := 1;
      FExp   := 0;
      MainOutMessage('DRAGON RESET LEVEL');
    end;
end;

procedure TDragonSystem.Run;
begin
try
    // 마지막으로 경험치 먹은시각(타격을받지않은지)이 오래되면(30분정도) 리셋해준다.
    if GetTickCount - FLastChangeExpTime > DRAGON_RESETTIME then
    begin
        FLastChangeExpTime := GetTickCount;   //다시 시가을 초기화 해준다.
        ResetLevel;
    end;


    if GetTickCount - FLastAttackTme > MAP_ATTACK_TIME then
    begin
        FLastAttackTme := GetTickCount;
        OnMapAutoAttack;
    end;
except
    MainOutMessage('EXCEPTION DRAGON SYSTEM'); 
end;
end;


end.
