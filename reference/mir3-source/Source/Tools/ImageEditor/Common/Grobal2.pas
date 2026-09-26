unit Grobal2;

interface

uses
	Windows, SysUtils, Classes, Hutil32;

type
   TMsgHeader = record  //게이트와 서버 통신에 사용
      Code:          integer;  //$aa55aa55;
      SNumber:       integer;  //socket number
      UserGateIndex: word;    //Gate에서의 Index
      Ident:         word;    //
      UserListIndex: word;    //서버에 UserList에서의 Index
      temp:          word;
      length:        integer;  //body binary 의 길이
   end;
   PTMsgHeader = ^TMsgHeader;

   TDefaultMessage = record
      Recog:   integer;       //4
      Ident:   word;          //2
      Param:   word;          //2
      Tag:     word;          //2
      Series:  word;          //2
      Etc:     word;//
      Etc2:    word;//
   end;
   PTDefaultMessage = ^TDefaultMessage;

   //클라이언트에서 사용
   TChrMsg = record
      ident:   integer;
      x:       integer;
      y:       integer;
      dir:     integer;
      feature: integer;
      state:   integer;
      saying:  string;
      sound:   integer;
   end;
   PTChrMsg = ^TChrMsg;

   //서버에서 사용
   TMessageInfo = record
      Ident	: word;
      wParam	: word;
      lParam1	: Longint;
      lParam2 : Longint;
      lParam3 : Longint;
      sender	: TObject;
      target  : TObject;
      description : string;
   end;
   PTMessageInfo = ^TMessageInfo;

   TMessageInfoPtr = record
      Ident	: word;
      wParam	: word;
      lParam1	: Longint;
      lParam2 : Longint;
      lParam3 : Longint;
      sender	: TObject;
      //target  : TObject;
      deliverytime: longword;  //도착 시간...
      descptr : PChar;
   end;
   PTMessageInfoPtr = ^TMessageInfoPtr;

   TShortMessage = record
      Ident    : word;
      msg      : word;
   end;

   TMessageBodyW = record
     Param1    : word;
     Param2    : word;
     Tag1      : word;
     Tag2      : word;
   end;

   TMessageBodyWL = record
     lParam1   : longint;
     lParam2   : longint;
     lTag1     : longint;
     lTag2     : longint;
   end;

   TCharDesc = record                	// sm_walk 의 이동 정보
     Feature : integer;                // 4 = (9)
     Status  : integer;
   end;

   TPowerClass = record
      Min   : byte;
      Ever  : byte;
      Max   : byte;
      dummy : byte;
   end;

   TNakedAbility = record
      DC          : word;
      MC          : word;
      SC          : word;
      AC          : word;
      MAC         : word;
      HP          : word;
      MP          : word;
      Hit         : word;
      Speed       : word;
      Reserved    : word;
   end;
   PTNakedAbility = ^TNakedAbility;

   TChgAttr = record
      attr         : byte;          //변경된 속성 식별 1:AC 2:MAC 3:DC 4:MC 5:SC
      min          : byte;          //DC,MC,SC의 min/max  AC,MAC인경우 MakeWord(min,max)값임
      max          : byte;
   end;

{$ifdef MIR2EI}  //ei에서 변경 되는 것들

   //ei
   TStdItem = record
      Name		    : string[30];        //14, 변경  아이템 이름 (천하제일검)
      StdMode      : byte;              //
      Shape 	   : byte;              // 형태별 이름 (철검)
      CharLooks    : byte;              // gadget
      Weight       : byte;              // 무게
      AniCount     : byte;              // 1보다 크면 애니메이션 되는 아이템 (다른 용도로 많이 쓰임)
      SpecialPwr   : shortint;          // +이면 생물공격+능력, -이면 언데드공격+
                                        //1~10 강도
                                        //-50~-1 언데드 능력치 향상
                                        //-100~-51 언데드 능력치 감소
      ItemDesc     : byte;              //$01 IDC_UNIDENTIFIED  (아이댄티파이 안 된 것, 클라이언트에서만 사용됨)
                                        //$02 IDC_UNABLETAKEOFF (손에서 떨어지지 않음, 미지수 사용 가능)
                                        //$04 IDC_NEVERTAKEOFF  (손에서 떨어지지 않음, 미지수 사용 불가능)
                                        //$08 IDC_DIEANDBREAK   (죽으면 깨지는 속성)
                                        //$10 IDC_NEVERLOSE     (죽어더 떨어지지 않음)
      Looks        : word;              // 그림 번호
      DuraMax      : word;
      AC           : word;              // 방어력
      MACType      : byte;
      MAC          : word;              // 마항력
      DC           : word;              // 데미지
      MCType       : byte;
      MC           : word;              // 술사의 마법 파워
      AtomDCType   : byte;
      AtomDC       : word;
//      SCType       : byte;
//      SC           : word;              // 도사의 정신력 gadget
      Need         : byte;              // 0:Level, 1:DC, 2:MC, 3:SC
      NeedLevel    : byte;              // 1..60 level value...
      Price        : integer;
      FuncType     : byte;
      Throw        : byte;              // 1: 죽었을때 안떨굼 (gagdet)
                                        // 2: 카운트형 아이템 (gadget)
      Reserved     : array[0..11] of byte;
   end;
   PTStdItem = ^TStdItem;

    TStdItemPack = packed record         // Gadget
        Name	    : array[0..29] of char;       // 아이템 이름 (천하제일검)
        StdMode     : byte;              //
        Shape       : byte;             // 형태별 이름 (철검)
        Weight      : byte;              // 무게
        AniCount    : byte;              // 1보다 크면 애니메이션 되는 아이템 (다른 용도로 많이 쓰임)
        SpecialPwr  : shortint;          // +이면 생물공격+능력, -이면 언데드공격+
                                        //1~10 강도
                                        //-50~-1 언데드 능력치 향상
                                        //-100~-51 언데드 능력치 감소
        ItemDesc     : byte;              //$01 IDC_UNIDENTIFIED  (아이댄티파이 안 된 것, 클라이언트에서만 사용됨)
                                        //$02 IDC_UNABLETAKEOFF (손에서 떨어지지 않음, 미지수 사용 가능)
                                        //$04 IDC_NEVERTAKEOFF  (손에서 떨어지지 않음, 미지수 사용 불가능)
                                        //$08 IDC_DIEANDBREAK   (죽으면 깨지는 속성)
                                        //$10 IDC_NEVERLOSE     (죽어더 떨어지지 않음)
        Looks        : word;              // 그림 번호
        DuraMax      : word;
        AC           : word;              // 방어력
        MACType      : byte;
        MAC          : word;              // 마항력
        DC           : word;              // 데미지
        MCType       : byte;
        MC           : word;              // 술사의 마법 파워
        AtomDCType   : byte;
        AtomDC       : word;
        Need         : byte;              // 0:Level, 1:DC, 2:MC, 3:SC
        NeedLevel    : byte;              // 1..60 level value...
        Price        : integer;
        FuncType     : byte;
        Throw        : byte;                // 1: 죽었을때 안떨굼 (gagdet)
                                            // 2: 카운트형 아이템 (gadget)
    end;
   PTStdItemPack = ^TStdItemPack;

   //ei
   TUserItem = packed record // gadget
      MakeIndex  : integer;      //서버에서의 아이템 인덱스(만들어 질때 인덱스 매겨짐, 중복가능)
      Index        : word;          //표준아이템의 인덱스  0:없음, 1부터 시작함..
      Dura         : word;
      DuraMax      : word;          //변경된 내구성 최대값
      Desc         : array[0..13] of byte;
           //0..7 아이템 업그레이드 상태
           //10 0:업그레이드와 상관 없음
           //   1:파괴력 업그레이드 아이댄티파이 안 되었음
           //   2:마력 (자연계) 업그레이드 아이댄티파이 안 되었음
           //   3:도력 업그레이드 아이댄티파이 안 되었음 - Mir2
           //   3:마력 (영혼계) 업그레이드 아이덴티파이 안 되었음 - Mir3
           //   5:공격속도 업그레이드 아이댄티파이 안 되었음
           //   9:실패, 포개짐
           //11 MAC_TYPE : gadget
           //12 MC_TYPE : gadget
      ColorR       : byte;
      ColorG       : byte;
      ColorB       : byte;
      Prefix       : array [0..12] of char;
   end;
   PTUserItem = ^TUserItem;

   //ei (gadget)
   TAbility = packed record
      Level       : byte;
//      reserved1   : byte;     // remaek by gadget
      AC          : word;     //armor class

//      MAC         : word;     //magic armor class
      DC          : word;    //damage class  -> makeword(min/max)

//      MC          : word;    //magic power class   -> makeword(min/max)
//      SC          : word;    //sprite energy class    -> makeword(min/max)

      HP          : word;     //health point
      MP          : word;     //magic point

      MaxHP       : word;     //max health point
      MaxMP       : word;     //max magic point

//      ExpCount    : byte;   //사용안함 , 삭제
//      ExpMaxCount : byte;   //사용안함 , 삭제

      Exp         : longword;  //현재 경험치
      MaxExp      : longword;  //현재 최대 경험치

      Weight      : word;  //현재 무게
      MaxWeight   : word;  //들 수 있는 최대 무게

      WearWeight    : byte;
      MaxWearWeight : byte;  //검을 제외한 착용 가능한 아이템의 무게 (초과하면 굉장히 느리다 2-3배느림)
      HandWeight    : byte;
      MaxHandWeight : byte;  //들 수 있는 검의 무게 (무게를 초과하면 굉장히 느리게 공격한다 2-3배느림)

      //ei 추가
{      FameLevel      : byte;  //명성
      MiningLevel    : byte;  //광부 레벨
      FramingLevel   : byte;  //경작
      FishingLevel   : byte;  //낚시

      FameExp        : integer;
      FameMaxExp     : integer;
      MiningExp      : integer;
      MiningMaxExp   : integer;
      FramingExp     : integer;
      FramingMaxExp  : integer;
      FishingExp     : integer;
      FishingMaxExp  : integer;                      }

      ATOM_DC        : array [0.._MAX_ATOM_] of word;
      ATOM_MC        : array [0.._MAX_ATOM_] of word;   // 0: Fire
                                                        // 1: Ice
                                                        // 2: Light
                                                        // 3: Wind
                                                        // 4: Holy
                                                        // 5: Dark
                                                        // 6: Phantom
      ATOM_MAC       : array [0.._MAX_ATOM_] of word;
   end;

   //ei
   TAddAbility = record       //아이템 착용으로 늘어나는 능력치
      HP          : word;
      MP          : word;
      HIT         : word;
      SPEED       : word;
      AC          : word;
//      MAC         : word;
      DC          : word;
//      MC          : word;
//      SC          : word;
      AntiPoison  : word;    //%
      PoisonRecover : word;  //%
      HealthRecover : word;  //%
      SpellRecover : word;   //%
      AntiMagic   : word; //마법 회피율 %
      Luck        : byte; //행운 포인트
      UnLuck      : byte; //불행 포인트
      WeaponStrong : byte;
      UndeadPower : byte;
      HitSpeed    : shortint;
      ATOM_DC        : array [0.._MAX_ATOM_] of word;
      ATOM_MC        : array [0.._MAX_ATOM_] of word;
      ATOM_MAC       : array [0.._MAX_ATOM_] of word;
   end;

{$else}

   //미르2
   TStdItem = record
  	   Name		    : string[14];        // 아이템 이름 (천하제일검)
      StdMode      : byte;              //
      Shape 	    : byte;              // 형태별 이름 (철검)
      Weight       : byte;              // 무게
      AniCount     : byte;              // 1보다 크면 애니메이션 되는 아이템 (다른 용도로 많이 쓰임)
      SpecialPwr   : shortint;          // +이면 생물공격+능력, -이면 언데드공격+
                                        //1~10 강도
                                        //-50~-1 언데드 능력치 향상
                                        //-100~-51 언데드 능력치 감소
      ItemDesc     : byte;              //$01 IDC_UNIDENTIFIED  (아이댄티파이 안 된 것, 클라이언트에서만 사용됨)
                                        //$02 IDC_UNABLETAKEOFF (손에서 떨어지지 않음, 미지수 사용 가능)
                                        //$04 IDC_NEVERTAKEOFF  (손에서 떨어지지 않음, 미지수 사용 불가능)
                                        //$08 IDC_DIEANDBREAK   (착용아이템에서 죽으면 깨지는 속성)
                                        //$10 IDC_NEVERLOSE     (착용아이템에서 죽어도 떨어지지 않음)
      Looks        : word;              // 그림 번호
      DuraMax      : word;
      AC           : word;              // 방어력
      MAC          : word;              // 마항력
      DC           : word;              // 데미지
      MC           : word;              // 술사의 마법 파워
      SC           : word;              // 도사의 정신력
      Need         : byte;              // 0:Level, 1:DC, 2:MC, 3:SC
      NeedLevel    : byte;              // 1..60 level value...
      Price        : integer;           // 가격
      Stock        : integer;           // 보유량
      AtkSpd       : byte;              // 공격속도
      Agility      : byte;              // 민첩
      Accurate     : byte;              // 정확
      MgAvoid      : byte;              // 마법회피 -> 마법저항(sonmg)
      Strong       : byte;              // 강도
      Undead       : byte;              // 사자
      HpAdd        : integer;           // 추가HP
      MpAdd        : integer;           // 추가MP
      ExpAdd       : integer;           // 추가 경험치
      EffType1     : byte;              // 효과종류1
      EffRate1     : byte;              // 효과확률1
      EffValue1    : byte;              // 효과값1
      EffType2     : byte;              // 효과종류2
      EffRate2     : byte;              // 효과확률2
      EffValue2    : byte;              // 효과값2
      {--------------------}
      // added by sonmg
      Slowdown     : byte;              // 둔화
      Tox          : byte;              // 중독
      ToxAvoid     : byte;              // 중독저항
      UniqueItem   : byte;              // 유니크속성
                                        // 유니크 --- $01:제련/업그레이드 안됨
                                        // 유니크 --- $02:수리불가
                                        // 유니크 --- $04:버리면사라짐(가방창에서 떨구지 않음)
                                        // 유니크 --- $08:교환 및 상점거래불가(12=4+8 : 거래불가,떨굼불가)
      OverlapItem  : byte;              // 중복허용
      light        : byte;              // 빛을내는 아이템
      {--------------------}
      ItemType     : byte;              // 아이템의 구분
      ItemSet      : Word;              // 셋트 아이템 구분
      Reference    : string[14];        // 참조 문자열
   end;

   PTStdItem = ^TStdItem;

   //미르2
   TUserItem = packed record
      MakeIndex  : integer;      //서버에서의 아이템 인덱스(만들어 질때 인덱스 매겨짐, 중복가능)
      Index        : word;          //표준아이템의 인덱스  0:없음, 1부터 시작함..
      Dura         : word;
      DuraMax      : word;          //변경된 내구성 최대값
      Desc         : array[0..13] of byte;
           //0..7 아이템 업그레이드 상태
           //10 0:업그레이드와 상관 없음
           //   1:파괴력 업그레이드 아이댄티파이 안 되었음
           //   2:마력 업그레이드 아이댄티파이 안 되었음
           //   3:도력 업그레이드 아이댄티파이 안 되었음
           //   5:공격속도 업그레이드 아이댄티파이 안 되었음
           //   9:실패, 포개짐
      ColorR        : byte;
      ColorG        : byte;
      ColorB        : byte;
      Prefix        : array [0..12] of char;
   end;
   PTUserItem = ^TUserItem;

   //미르2
   TAbility = record
      Level       : byte;
      reserved1   : byte;
      AC          : word;     //armor class
      MAC         : word;     //magic armor class
      DC          : word;    //damage class  -> makeword(min/max)
      MC          : word;    //magic power class   -> makeword(min/max)
      SC          : word;    //sprite energy class    -> makeword(min/max)
      HP          : word;     //health point
      MP          : word;     //magic point
      MaxHP       : word;     //max health point
      MaxMP       : word;     //max magic point
      ExpCount    : byte;   //사용안함
      ExpMaxCount : byte;   //사용안함
      Exp         : longword;  //현재 경험치
      MaxExp      : longword;  //현재 최대 경험치
      Weight      : word;  //현재 무게
      MaxWeight   : word;  //들 수 있는 최대 무게
      WearWeight    : byte;
      MaxWearWeight : byte;  //검을 제외한 착용 가능한 아이템의 무게 (초과하면 굉장히 느리다 2-3배느림)
      HandWeight    : byte;
      MaxHandWeight : byte;  //들 수 있는 검의 무게 (무게를 초과하면 굉장히 느리게 공격한다 2-3배느림)

      FameCur     : integer; //현재 명성치(2004/10/22)
      FameBase    : integer; //누적 명성치(2004/10/22)
   end;

   //미르2
   TAddAbility = record       //아이템 착용으로 늘어나는 능력치
      HP          : word;
      MP          : word;
      HIT         : word;   // 정확
      SPEED       : word;   // 민첩
      AC          : word;
      MAC         : word;
      DC          : word;
      MC          : word;
      SC          : word;
      AntiPoison  : word;    //%  // 중독저항
      PoisonRecover : word;  //%
      HealthRecover : word;  //%
      SpellRecover : word;   //%
      AntiMagic   : word; //마법 회피율 % // => 마법저항
      Luck        : byte; //행운 포인트
      UnLuck      : byte; //불행 포인트
      WeaponStrong : byte;
      UndeadPower : byte;
      HitSpeed    : shortint;
      // added by sonmg
      Slowdown    : byte;
      Poison      : byte;
   end;

{$endif} //미르2


   TPricesInfo = record            //가격 정보
      Index       : word;  //표준 아이템의 인덱스
      SellPrice   : integer;    //기본 가격, BuyPrice는 SellPrice의 절반
   end;
   PTPricesInfo = ^TPricesInfo;

   TClientGoods = record
      Name        : string[14];
      SubMenu     : byte;
      Price       : integer;
      Stock       : integer;  //개별아이템인경우, Item의 ServerIndex 임
      //Dura        : word;
      //DuraMax     : word;
      Grade       : ShortInt;     //상태
   end;
   PTClientGoods = ^TClientGoods;

   TClientJangwon = record //장원 리스트
      Num           : integer;
      GuildName     : string[20];
      CaptaineName1 : string[14];
      CaptaineName2 : string[14];
      SellPrice     : integer;
      SellState     : string[10];
   end;
   PTClientJangwon = ^TClientJangwon;

   TClientGABoard = record //장원 게시판 리스트
      WrigteUser   : string[14];
      TitleMsg     : string[40];
      IndexType1   : integer;
      IndexType2   : integer;
      IndexType3   : integer;
      IndexType4   : integer;
      ReplyCount   : integer;
   end;
   PTClientGABoard = ^TClientGABoard;

   TClientGADecoration = record //장원 꾸미기
      Num       : integer;
      Name      : string[25];
      Price     : integer;
      ImgIndex  : integer;
      CaseNum   : integer;
//      Hint      : string[40];
   end;
   PTClientGADecoration = ^TClientGADecoration;


   TClientItem = record      //클라이언트에서 필요한 포멧
      S            : TStdItem;  //변경된 능력치는 여기에 적용됨.
      MakeIndex    : integer;
      Dura         : word;
      DuraMax      : word;
      UpgradeOpt   : integer;    //업그레이드 된 개수
   end;
   PTClientItem = ^TClientItem;

   TUserStateInfo = record
      Feature     : integer;
      UserName    : string[14];
      NameColor   : integer;
      GuildName   : string[20];//[14]; //수정(2004/12/22)
      GuildRankName : string[14];
      UseItems : array[0..12] of TClientItem;    // 8->12
      bExistLover : Boolean;     //연인 상태(2004/10/27)
      LoverName   : string[14];  //연인 이름(2004/11/03)
      FameName    : string[20];  //명성 호칭(2004/10/27)
   end;
   PTUserStateInfo = ^TUserStateInfo;

   TDropItem = record  //클라이언트에서 사용
      Id          : integer;
      X           : word;
      Y           : word;
      Looks       : word;
      FlashTime   : longword; //마지막으로 반짝거린 시간
      BoFlash     : Boolean;
      FlashStepTime : longword;
      FlashStep   : integer;
      Name        : string[25];
      BoDeco      : Boolean;
   end;
   PTDropItem = ^TDropItem;

   TDefMagic = record
      MagicId: word;
      MagicName: string[14];       //칸 늘릴것 12->14(클라이언트와 함께 사용)
      EffectType: byte;
      Effect: byte;
      Spell: word;
      MinPower: word;
      NeedLevel: array[0..3] of byte;
      MaxTrain: array[0..3] of integer;
      MaxTrainLevel: byte;  //수련 레벨
      Job: byte;         //0: 전사 1:술사  2:도사   99:모두가능
      DelayTime: integer; //한방 쏜다음에 다음 마법을 쓸 수 있는데 걸리는 시간
      DefSpell: byte;
      DefMinPower: byte;
      MaxPower: word;
      DefMaxPower: byte;
      Desc: string[15];
   end;
   PTDefMagic = ^TDefMagic;

   TUserMagic = record
      pDef        : PTDefMagic;  //반드시 nil이 아니어야 한다.
      MagicId     : word;     //Magic Index 저장. 유니크해야하며, 변동되면 안됨, 항상 0보다 크다.
      Level       : byte;
      Key         : char;     //사용자가 지정한 키
      CurTrain    : integer;  //현재 수련치
   end;
   PTUserMagic = ^TUserMagic;

   TClientMagic = record
      Key: char;
      Level: byte;
      CurTrain: integer;
      Def: TDefMagic;
   end;
   PTClientMagic = ^TClientMagic;

   // 2003/04/15 친구, 쪽지
   TFriend = record
      CharID: String;
      Status: Byte;
      Memo  : String;
   end;
   PTFriend = ^TFriend;
   TMail = record
      Sender: String;
      Date  : String;
      Mail  : String;
      Status: Byte;
   end;
   PTMail = ^TMail;

   TRelationship = record
      CharID: String;
      Level : Byte;
      Sex   : Byte;
      Status: Byte;
      Date  : String;
   end;
   PTRelationship = ^TRelationship;

   TSkillInfo = record
      SkillIndex  : word;
      Reserved    : word;
      CurTrain    : integer;
   end;
   PTSkillInfo = ^TSkillInfo;

   TMapItem = record
      UserItem: TUserItem;
      Name: string[25];
      Looks: word;
      AniCount: byte;
      Reserved: byte;
      Count: integer;
      Ownership: TObject; //물건을 집을 수 있는 사람
      Droptime: longword; //물건을 흘린 시간
      Droper: TObject;  //물건을 떨어뜨린 자 (사람? 몬스터?)
   end;
   PTMapItem = ^TMapItem;

   //장원꾸미기 아이템(sonmg)
   TAgitDecoItem = record
      Name: string[25];
      Looks: word;
      MapName:  string[14];
      x: word;
      y: word;
      Maker: string[14];
      Dura: word;
   end;
   PTAgitDecoItem = ^TAgitDecoItem;

   {map용 아이템}
   TVisibleItemInfo = record
      check: byte;
      x: word;
      y: word;
      Id: longint;
      Name: string[25];
      looks: word;
   end;
   PTVisibleItemInfo = ^TVisibleItemInfo;

   TVisibleActor = record
      check: byte;
      cret: TObject;
   end;
   PTVisibleActor = ^TVisibleActor;

   {맵 에서 일어나는 이벤트, activate시켜야만 이벤트가 발생한다.}
   TMapEventInfo = record
      check: byte;
      X: integer;
      Y: integer;
      EventObject: TObject;  {TMapEvent}
   end;
   PTMapEventInfo = ^TMapEventInfo;

   TGateInfo = record
      GateType: byte;
      EnterEnvir: TObject;  //TEnvirnoment;
      EnterX: integer;
      EnterY: integer;
   end;
   PTGateInfo = ^TGateInfo;

   //맵에 관련된 레코드
   TAThing = record
      Shape  	: byte;
      AObject : TObject;
      ATime   : longword;
   end;
   PTAThing = ^TAThing;

   TMapInfo = record
      MoveAttr	: byte;    //0: can move  1: can't move  2: can't move and cant't fly
      Door     : Boolean; //문이있음, OBJList중에 문 있음
      Area     : byte;    //지역 구분 (마을,수련장,등등)
      Reserved : byte;    //미사용
      OBJList	: TList;   // list of TAThing
   end;
   PTMapInfo = ^TMapInfo;


   TUserEntryInfo = record              // 사용자 등록정보, logon전에 쓰임
      LoginId  : string[10];
      Password : string[10];
      UserName : string[20];     //*
      SSNo     : string[14];     //* 721109-1476110
      Phone    : string[14];     //집전화 번호
      Quiz     : string[20];     //*
      Answer   : string[12];     //*
      EMail    : string[40];  //25];
   end;
   TUserEntryAddInfo = record
      //temp     : array[0..14] of byte;
      Quiz2    : string[20];     //*
      Answer2  : string[12];     //*
      Birthday : string[10];     //* 1972/11/09
      MobilePhone: string[13];   //017-6227-1234
      Memo1: string[20];    //*
      Memo2: string[20];    //*
   end;

   TUserCharacterInfo = record          // 가상세계에 들어오기 전에 사용자에게 전달되는
      EncName	: string[20];              // 케랙터 정보
      Sex		: byte;
      Hair      : byte;
      Job       : byte;                 //0:전사 1: 술사 2:도사
      Level	    : byte;
      Feature	: integer;
      EncEncName: string[30];              // 케랙터 정보
   end;
   PTUserCharacterInfo = ^TUserCharacterInfo;

   TLoadHuman = packed record
      UsrId: array [0..20] of char;
      ChrName: array [0..19] of char; // 13 -> 19
      UsrAddr: array [0..14] of char;
      CertifyCode: integer;
   end;
   PTLoadHuman = ^TLoadHuman;

   TMonsterInfo = record
      Name: string[14];
      Race: byte;   //서버의 AI 프로그램
      RaceImg: byte;  //클라이언트 프래임 식별
      Appr: word;   //이미지 번호
      Level: byte;
      LifeAttrib: byte;
      CoolEye: byte;  //눈의 좋음, 100% 이면 은신을 봄, 50%이면 은신을 볼 확률이 50%
      Exp: word;
      HP: word;
      MP: word;
      AC: byte;
      MAC: byte;
      DC: byte;
      MaxDC: byte;
      MC: byte;
      SC: byte;
      Speed: Byte;
      Hit: Byte;
      WalkSpeed: word;
      WalkStep: word;
      WalkWait: word;
      AttackSpeed: word;
      //////////////////////////
      // newly added by sonmg.
      Tame: word;
      AntiPush: word;
      AntiUndead: word;
      SizeRate: word;
      AntiStop: word;
      //////////////////////////
      ItemList: TList;
   end;
   PTMonsterInfo = ^TMonsterInfo;

   TZenInfo = record
      MapName:  string[14];
      X: integer;
      Y: integer;
      MonName: string[14];
      MonRace: integer; //
      Area: integer;  //범위 +area, -area rectangle
      Count: integer;
      MonZenTime: longword; //밀리세컨드 단위
      StartTime: longword;
      Mons: TList;
      SmallZenRate: integer;
      // 2003/06/20 이벤트용 몹 처리
      TX : integer;
      TY : integer;
      ZenShoutType : integer;
      ZenShoutMsg  : integer;
   end;
   PTZenInfo = ^TZenInfo;

   TMonItemInfo = record
      SelPoint: integer;
      MaxPoint: integer;
      ItemName: string[14];
      Count: integer;  //갯수,
   end;
   PTMonItemInfo = ^TMonItemInfo;

   TMarketProduct = record
      GoodsName: string[14];
      Count: integer;
      ZenHour: integer; //hour
      ZenTime: longword; //최근에 젠시킨 시간
   end;
   PTMarketProduct = ^TMarketProduct;

   //QuestDiary용
   TQDDinfo = record
      Index: integer;
      Title: string;
      SList: TStringList;
   end;
   PTQDDinfo = ^TQDDinfo;

   // 위탁판매용 아이템 --------------------------------------------------------
   TMarketItem = record
      Item   	: TClientItem;	// 변경된 능력치는 여기에 적용됨.
      UpgCount  : integer;      // 추가로 업그레이드 된 개수
      Index	    : integer;	    // 판매번호
      SellPrice	: integer;	    // 판매 가격
      SellWho	: string[20];	// 판매자
      Selldate	: string[10]; 	// 판매날짜(0312311210 = 2003-12-31 12:10 )
      SellState : word          // 1 = 판매중 , 2 = 판매완료
   end;
   PTMarketItem = ^TMarketItem;

   // 위탁판매 읽기용 ----------------------------------------------------------
   TMarketLoad = record
      UserItem  : TUserItem;    // DB 저장용
      Index     : Integer;      // DB 인덱스
      MarketType: integer;      // 분리된 아이템 종류
      SetType   : integer;      // 셋트 아이템 종류
      SellCount : integer;
      SellPrice : integer;      // 판매 가격
      ItemName  : string[30];   // 아이템이름
      MarketName: string[30];   // 판매자명
      SellWho	: string[20];	// 판매자
      Selldate	: string[10]; 	// 판매날짜(0312311210 = 2003-12-31 12:10 )
      SellState : word;         // 1 = 판매중 , 2 = 판매완료
      IsOK      : integer;      // 결과값
   end;
   PTMarketLoad   = ^TMarketLoad;

    //아이템 검색용 ------------------------------------------------------------
    TSearchSellItem = record
        MarketName  : string[25];   // 서버이름_NPC  이름이 사용됨
        Who         : string[25];   // 아이템 판매자 검색시 사용 ,
        ItemName    : string[25];   // 아이템 이름 검색시 사용
        MakeIndex   : integer;      // 아이템의 유니크 번호  
        ItemType    : integer;      // 아이테 종류 검색시 사용
        ItemSet     : integer;      // 아이템 셋트 조회시 사용
        SellIndex   : integer;      // 판매 인덱스 아이템 살때 , 취소 , 금액회수등에 사용
        CheckType   : integer;      // DB 의 체크타입
        IsOK        : integer;      // 결과값
        UserMode    : integer;      // 1= 아이템 사기  , 2= 자신의 아이템 검색
        pList       : TList;        // 위탁아이템의 리스트
    end;
    PTSearchSellItem = ^TSearchSellItem;

    //위탁검사용....------------------------------------------------------------
    TMarKetReqInfo  = Record
        UserName    :   string[30];
        MarketName  :   string[30];
        SearchWho   :   string[30];
        SearchItem  :   string[30];
        ItemType    :   integer;
        ItemSet     :   integer;
        UserMode    :   integer;
    end;

    //장원게시판 리스트 검색용....------------------------------------------------------------
    TSearchGaBoardList  = Record
        AgitNum     :   integer;      // 미사용
        GuildName   :   string[30];
        OrgNum      :   integer;      // 미사용
        SrcNum1     :   integer;      // 미사용
        SrcNum2     :   integer;      // 미사용
        SrcNum3     :   integer;      // 미사용
        Kind        :   integer;
        UserName    :   string[20];   // 미사용
        ArticleList :   TList;        // 게시판 리스트
    end;
    PTSearchGaBoardList = ^TSearchGaBoardList;

{
    //장원게시판 제목 리스트용....------------------------------------------------------------
    TGaBoardListLoad  = Record
        AgitNum     :   integer;
        GuildName   :   string[30];
        OrgNum      :   integer;
        SrcNum      :   integer;
        Kind        :   integer;
        UserName    :   string[20];
        Subject     :   array [0..40] of char;
    end;
    PTGaBoardListLoad = ^TGaBoardListLoad;
}

    //장원게시판 글내용....------------------------------------------------------------
    TGaBoardArticleLoad  = Record
        AgitNum     :   integer;
        GuildName   :   string[30];
        OrgNum      :   integer;
        SrcNum1     :   integer;
        SrcNum2     :   integer;
        SrcNum3     :   integer;
        Kind        :   integer;
        UserName    :   string[20];
        Content     :   array [0..500] of char;
    end;
    PTGaBoardArticleLoad = ^TGaBoardArticleLoad;

const
  _GENDER_MAN   = 0;
  _GENDER_WOMAN = 1;

  _JOB_GUNGSA   = 3;
  _JOB_DOSA     = 2;
  _JOB_SULSA    = 1;
  _JOB_JUNSA    = 0;

  _CHR_PROC_IMG_SELECT          = 50;
  _CHR_PROC_IMG_CREATE          = 80;
  _CHR_PROC_IMG_CREATE_STONE    = 81;
  _CHR_PROC_IMG_CREATE_STONE_S  = 82;

  _MAX_CHAR      = 4;
  _MAX_SHOW_CHAR = 2;
  _MAX_SPR_KIND  = 40;

  _CHR_MAX_MT = 5;

  _CHR_MT_NS = 0;
  _CHR_MT_SM = 1;
  _CHR_MT_SS = 2;
  _CHR_MT_R  = 3;
  _CHR_MT_CC = 4;

  _CHR_PROC_SELECT    = 0;
  _CHR_PROC_CREATEIN  = 1;
  _CHR_PROC_CREATE    = 2;
  _CHR_PROC_CREATEOUT = 3;
  _CHR_PROC_START     = 4;

  _SELECTED_FST_CHR   = 0;
  _SELECTED_SND_CHR   = 1;
  _SELECTED_TRD_CHR   = 2;
  _SELECTED_4TH_CHR   = 3;
  _SELECTED_NONE      = -1;

//******************************************************************************************************************
//	#1. Map Handler
//******************************************************************************************************************
  _BASETILE_WIDTH  = 96;
  _BASETILE_HEIGHT = 64;

  _CELL_WIDTH  = 48;
  _CELL_HEIGHT = 32;

//  _VIEW_CELL_X_COUNT = 24
//  _VIEW_CELL_Y_COUNT = 26
//  _VIEW_CELL_Y_COUNT_FOR_OBJ = 44
//
//  _MEMVIEW_CELL_X_COUNT = 36
//  _MEMVIEW_CELL_Y_COUNT = 36
//
//  _VIEW_CELL_X_START = -200
//  _VIEW_CELL_Y_START = -157
//
//  _VIEW_CELL_X_START_INVEN = -196
//  _VIEW_CELL_Y_START_INVEN = -157
//
//  _VIEW_CELL_X_START_STATUS = -186
//  _VIEW_CELL_Y_START_STATUS = -157
//
//  _MAX_TILE_FILE = 14

//******************************************************************************************************************
//	#1. Inventory Window
//******************************************************************************************************************
  _INVEN_MAX_CELL = 36;
  _INVEN_CELL_XCNT = 6;
  _INVEN_CELL_YCNT = 6;
  _INVEN_TOTAL_CELL = 600;
  _INVEN_MAX_CELL_YCNT = 100;
  _INVEN_CELL_XSTART = 25;
  _INVEN_CELL_YSTART = 41;

  _NEW_INVEN_CELL_YCNT = 8;

  _NEW_INVEN_CELL_XSTART = 17;
  _NEW_INVEN_CELL_YSTART = 71;

  _MAX_INVEN_BTN = 4;
  _MAX_INVEN_ITEM = 46;

  _MAX_INVENEX_ITEM = 50;

  _BTN_ID_INVENCLOSE = 0;
  _BTN_ID_FUN1 = 1;
  _BTN_ID_FUN2 = 2;
  _BTN_ID_MINIMAPBOOK = 3;

  _MAX_TYPE = 3;

  _INVEN_TYPE_BAG = 0;
  _INVEN_TYPE_REPAIR = 1;
  _INVEN_TYPE_SELL = 2;
  _INVEN_TYPE_STORAGE = 3;

  _PRICE_NONE = 0;
  _PRICE_RECEIVING = 1;
  _PRICE_RECEIVED = 2;
  
   DEFBLOCKSIZE  = 22;//16;

{$ifdef MIR2EI}

   MAXBAGITEM = 46;
   MAXHORSEBAG = 30;
   MAXUSERMAGIC = 20;
   MAXSAVEITEM = 100;

   MAXQUESTINDEXBYTE = 24; //ei용
   MAXQUESTBYTE = 176; //ei용

{$else}  //기존 미르2

   MAXBAGITEM = 46;
   MAXHORSEBAG = 30;
   MAXUSERMAGIC = 25;//20;   //(sonmg 2004/10/27)
   MAXSAVEITEM = 100;

   MAXQUESTINDEXBYTE = 24;       // To PDS:13;  //100;
   MAXQUESTBYTE = 176;           // TO PDS:100; //13;

{$endif}

   //클라이언트에서 쓰임
   LOGICALMAPUNIT    = 40;
   UNITX             = 48;
   UNITY             = 32;
   HALFX             = 24;
   HALFY             = 16;

   OS_MOVINGOBJECT  = 1;
   OS_ITEMOBJECT     = 2;
   OS_EVENTOBJECT    = 3;
   OS_GATEOBJECT     = 4;
   OS_SWITCHOBJECT   = 5;
   OS_MAPEVENT       = 6;
   OS_DOOR           = 7;
   OS_ROON           = 8;

   // StatusArr Size 지정(sonmg 2004/03/19)
   STATUSARR_SIZE    = 16;
   EXTRAABIL_SIZE    = 7;
   // 2003/07/15 상태이상 추가
   POISON_DECHEALTH     = 0;   //$80000000
   POISON_DAMAGEARMOR   = 1;   //$40000000
   POISON_ICE           = 2;   //$20000000
   POISON_STUN          = 3;   //$10000000
   POISON_SLOW          = 4;   //$08000000
   POISON_STONE         = 5;   //$04000000
   POISON_DONTMOVE      = 6;   //$02000000

   STATE_BLUECHAR       = 2;
   STATE_FASTMOVE       = 7;   //$01000000
   STATE_TRANSPARENT    = 8;   //$00800000
   STATE_DEFENCEUP      = 9;   //$00400000
   STATE_MAGDEFENCEUP   = 10;  //$00200000
   STATE_BUBBLEDEFENCEUP = 11; //$00100000

   // 2004/03/19 캐릭터 효과 추가(sonmg)
   STATE_50LEVELEFFECT  = 12;  //$00080000
   STATE_TEMPORARY1     = 13;  //$00040000  //임시1(빼빼로이펙트)
   STATE_TEMPORARY2     = 14;  //$00020000  //임시2(호박머리)
   STATE_TEMPORARY3     = 15;  //$00010000  //임시3(하트빼빼로)

   EABIL_DCUP       = 0;   //순간적으로 파괴력을 올림 (일정 시간)
   EABIL_MCUP       = 1;
   EABIL_SCUP       = 2;
   EABIL_HITSPEEDUP = 3;
   EABIL_HPUP       = 4;
   EABIL_MPUP       = 5;
   EABIL_PWRRATE    = 6;   // 공격력 레이트 조정 

   //ItemDesc 의 속성
   IDC_UNIDENTIFIED     = $01;   //능력 확인 안됨
   IDC_UNABLETAKEOFF    = $02;   //손에서 떨어지지 않음, 미지수 사용으로 떨어짐
   IDC_NEVERTAKEOFF     = $04;   //손에서 절대로 떨어지지 않음
   IDC_DIEANDBREAK      = $08;   //죽으면 깨짐
   IDC_NEVERLOSE        = $10;   //죽어도 잃어버리지 않음


   STATE_STONE_MODE     = $00000001;  //석상몬스터의 모습(석상으로 있음)
   STATE_OPENHEATH      = $00000002;  //체력 공개상태


   HAM_ALL              = 0;  //모두 공격
   HAM_PEACE            = 1;  //평화모드, 몬스터만 공격
   HAM_GROUP            = 2;  //그룹원 이외 아무나 공격
   HAM_GUILD            = 3; //길드원 이외 아무나 공격
   HAM_PKATTACK         = 4; //빨갱이 대 흰둥이
   HAM_GUILDWAR         = 5; //적대문파만 공격

   HAM_MAXCOUNT         = 6;


   AREA_FIGHT        = $01;
   AREA_SAFE         = $02;
   AREA_FREEPK       = $04;


   HM_HIT            = 0;
   HM_HEAVYHIT       = 1;
   HM_BIGHIT         = 2;
   HM_POWERHIT       = 3;
   HM_LONGHIT        = 4;
   HM_WIDEHIT        = 5;
   // 2003/03/15 신규무공
   HM_CROSSHIT       = 6;  //4 곳 맞음 -> 8곳 맞음
   HM_FIREHIT        = 7;
   HM_TWINHIT        = 8;  //2번 공격
   HM_STONEHIT       = 9;  //4 곳 맞음 -> 8곳 맞음

   {----------------------------}

   //SM_??    서버 -> 클라이언트로
   //  1 ~ 2000
   SM_TEST                 = 1;
   //흐름제어 명령
   SM_STOPACTIONS          = 2;  //모든 캐릭터/마법의 동작을 멈춘다.
                                 //다른 맵에 들어간 경우,

   //행동에 관련 명령
   SM_ACTION_MIN           = 5;
   SM_THROW                = 5;
   SM_RUSH                 = 6;  //앞으로 전진
   SM_RUSHKUNG             = 7;  //앞으로 전진실패
   SM_FIREHIT              = 8;  //염화결
   SM_BACKSTEP             = 9;  //뒷걸음질,
   SM_TURN                 = 10;
   SM_WALK                 = 11;
   SM_SITDOWN              = 12;
   SM_RUN                  = 13;
   SM_HIT                  = 14;
   SM_HEAVYHIT             = 15;
   SM_BIGHIT               = 16;
   SM_SPELL                = 17;
   SM_POWERHIT             = 18;
   SM_LONGHIT              = 19;  //더 세게 때림
   SM_DIGUP                = 20;  //땅파고 나오다.
   SM_DIGDOWN              = 21;  //땅파고 들어가 숨다.
   SM_FLYAXE               = 22;
   SM_LIGHTING             = 23;  //마법 사용
   SM_WIDEHIT              = 24;
   SM_ACTION_MAX           = 25;

   // 2003/03/15 신규무공
   SM_CROSSHIT             = 35;  //광풍참, 주변8타일 공격
   SM_TWINHIT              = 36;  //쌍룡참, 빠르게 2번 공격
   SM_STONEHIT             = 37;  //사자후, 주변8타일 돌로만듬
   SM_WINDCUT              = 38;  //공파섬,  앞타일 9개 공격
   SM_DRAGONFIRE           = 39; // 천룡기염(화룡기염)  자신주변 타일 25개 공격
   SM_CURSE                = 40; // 저주술
   // 2004/06/22 신규무공(포승검, 흡혈술, 맹안술)
   SM_PULLMON              = 41;  //포승검, 끌어당김
   SM_SUCKBLOOD            = 42;  //흡혈술, 피를 빨아들임
   SM_BLINDMON             = 43;  //맹안술, 적의 시야를 가림

   // FireDragon ------------------------ by Leekg...2003/11/27
   MAGIC_DUN_THUNDER       = 70; //용던젼 번개  // FireDragon
   MAGIC_DUN_FIRE1         = 71; //용던젼 용암 덩어리
   MAGIC_DUN_FIRE2         = 72; //용던젼 용암 임펙트
   MAGIC_DRAGONFIRE        = 73; //용불공격 터짐
   MAGIC_FIREBURN          = 74; //용석상공격 터짐 타오름

   MAGIC_SERPENT_1         = 75; //이무기 멸천화
   MAGIC_JW_EFFECT1        = 76; //장원 임펙트 1
   MAGIC_FOX_THUNDER       = 78; //술사비월여우 강격
   MAGIC_FOX_FIRE1         = 79; //술사비월여우 화염

   SM_DRAGON_LIGHTING      = 80;
   SM_DRAGON_FIRE1         = 81;
   SM_DRAGON_FIRE2         = 82;
   SM_DRAGON_FIRE3         = 83;

   SM_DRAGON_STRUCK        = 85;
   SM_DRAGON_DROPITEM      = 86;
   SM_LIGHTING_1           = 87; //마법_1:이무기 멸천화
   SM_LIGHTING_2           = 88;
   SM_LIGHTING_3           = 89; //현무현신

   MAGIC_FOX_FIRE2         = 90; //도사비월여우 폭살계
   MAGIC_FOX_CURSE         = 91; //도사비월여우 저주술
   MAGIC_SOULBALL_ATT1     = 93; //비월천주 전기 공격(근접범위)
   MAGIC_SOULBALL_ATT2     = 94; //비월천주 전기 공격(원거리)
   MAGIC_SOULBALL_ATT3_1   = 95; //비월천주 전기 공격(필사기) 5가지 임펙트
   MAGIC_SOULBALL_ATT3_2   = 96;
   MAGIC_SOULBALL_ATT3_3   = 97;
   MAGIC_SOULBALL_ATT3_4   = 98;
   MAGIC_SOULBALL_ATT3_5   = 99;
   MAGIC_SIDESTONE_ATT1    = 100; //호혼기석 전기 공격
   MAGIC_TURTLE_WARTERATT  = 101; //갑철귀수 물공격

   MAGIC_KINGTURTLE_ATT1   = 102; //현무현신-힐링
   MAGIC_KINGTURTLE_ATT2_1 = 103; //현무현신-전체물공격1
   MAGIC_KINGTURTLE_ATT2_2 = 104; //현무현신-전체물공격2
   MAGIC_KINGTURTLE_ATT3   = 105; //현무현신-몬스터소환

   SM_ACTION2_MIN          = 1000;
   //SM_READYFIREHIT         = 1000;  //클라이언트에서만 쓰임, 염화결 준비

   SM_ACTION2_MAX          = 1099;

   SM_DIE                  = 26; //사라 짐
   SM_ALIVE                = 27;
   SM_MOVEFAIL             = 28;
   SM_HIDE                 = 29;
   SM_DISAPPEAR            = 30;
   SM_STRUCK               = 31;
   SM_DEATH                = 32;
   SM_SKELETON             = 33;
   SM_NOWDEATH             = 34;

   SM_HEAR                 = 40;
   SM_FEATURECHANGED       = 41;
   SM_USERNAME             = 42;
   SM_WINEXP               = 44;
   SM_LEVELUP              = 45;
   SM_DAYCHANGING          = 46;

   SM_LOGON                = 50;
   SM_NEWMAP               = 51;
   SM_ABILITY              = 52;
   SM_HEALTHSPELLCHANGED   = 53;
   SM_MAPDESCRIPTION       = 54;

   SM_CHANGEFAMEPOINT      = 55; //명성치 변화(2004/11/04)

   SM_SYSMESSAGE           = 100;
   SM_GROUPMESSAGE         = 101;
   SM_CRY                  = 102;
   SM_WHISPER              = 103;
   SM_GUILDMESSAGE         = 104;
   SM_SYSMSG_REMARK        = 105;

   //ITEM ?
   SM_ADDITEM              = 200;  //아이템을 새로 얻음  Series(수량)
   SM_BAGITEMS             = 201;  //가방의 모든 아이템
   SM_DELITEM              = 202;  //닳아서 없어지는 등의 이유로 없어짐
   SM_UPDATEITEM           = 203;  //아이템의 사양이 변함
   //Magic
   SM_ADDMAGIC             = 210;
   SM_SENDMYMAGIC          = 211;  //
   SM_DELMAGIC             = 212;

   SM_VERSION_AVAILABLE    = 500;
   SM_VERSION_FAIL         = 501;
   SM_PASSWD_SUCCESS       = 502;
   SM_PASSWD_FAIL          = 503;
   SM_NEWID_SUCCESS        = 504;  //새아이디 잘 만들어 졌음
   SM_NEWID_FAIL           = 505;  //새아이디 만들기 실패
   SM_CHGPASSWD_SUCCESS    = 506;
   SM_CHGPASSWD_FAIL       = 507;
   SM_QUERYCHR             = 520;  //캐릭리스트
   SM_NEWCHR_SUCCESS       = 521;
   SM_NEWCHR_FAIL          = 522;
   SM_DELCHR_SUCCESS       = 523;
   SM_DELCHR_FAIL          = 524;
   SM_STARTPLAY            = 525;
   SM_STARTFAIL            = 526;
   SM_QUERYCHR_FAIL        = 527;
   SM_OUTOFCONNECTION      = 528;  //연결 해제됨
   SM_PASSOK_SELECTSERVER  = 529;
   SM_SELECTSERVER_OK      = 530;
   SM_NEEDUPDATE_ACCOUNT   = 531;  //계정의 정보를 다시 입력하기 바람 창..
   SM_UPDATEID_SUCCESS     = 532;
   SM_UPDATEID_FAIL        = 533;
   SM_PASSOK_WRONGSSN      = 534;
   SM_NOT_IN_SERVICE       = 535;
   SM_SEND_PUBLICKEY       = 536;
   SM_FOXSTATE             = 537;   //비월천주 상태


   SM_DROPITEM_SUCCESS     = 600;  //아이템 버리기 성공
   SM_DROPITEM_FAIL        = 601;  //
   SM_ITEMSHOW             = 610;
   SM_ITEMHIDE             = 611;
   SM_OPENDOOR_OK          = 612;
   SM_OPENDOOR_LOCK        = 613;
   SM_CLOSEDOOR            = 614;
   SM_TAKEON_OK            = 615; //착용 성공, + New Feature
   SM_TAKEON_FAIL          = 616; //착용 실패
   SM_EXCHGTAKEON_OK       = 617; //착용아이템 교환 성공
   SM_EXCHGTAKEON_FAIL     = 618; //착용아이템 교환 실패
   SM_TAKEOFF_OK           = 619; //벗기 성공, + New Feature
   SM_TAKEOFF_FAIL         = 620; //
   SM_SENDUSEITEMS         = 621; //착용 아이템 모두 보냄
   SM_WEIGHTCHANGED        = 622;
   SM_CLEAROBJECTS         = 633;
   SM_CHANGEMAP            = 634;
   SM_EAT_OK               = 635;
   SM_EAT_FAIL             = 636;
   SM_BUTCH                = 637;
   SM_MAGICFIRE            = 638; //마법 발사됨  CM_SPELL -> SM_SPELL + SM_MAGICFIRE
   SM_MAGICFIRE_FAIL       = 639;
   SM_MAGIC_LVEXP          = 640;
   SM_SOUND                = 641;
   SM_DURACHANGE           = 642;
   SM_MERCHANTSAY          = 643;
   SM_MERCHANTDLGCLOSE     = 644;
   SM_SENDGOODSLIST        = 645;
   SM_SENDUSERSELL         = 646;
   SM_SENDBUYPRICE         = 647;
   SM_USERSELLITEM_OK      = 648;
   SM_USERSELLITEM_FAIL    = 649;
   SM_BUYITEM_SUCCESS      = 650;
   SM_BUYITEM_FAIL         = 651;
   SM_SENDDETAILGOODSLIST  = 652;
   SM_GOLDCHANGED          = 653;
   SM_CHANGELIGHT          = 654;
   SM_LAMPCHANGEDURA       = 655;
   SM_CHANGENAMECOLOR      = 656;
   SM_CHARSTATUSCHANGED    = 657;
   SM_SENDNOTICE           = 658;
   SM_GROUPMODECHANGED     = 659;
   SM_CREATEGROUP_OK       = 660;
   SM_CREATEGROUP_FAIL     = 661;
   SM_GROUPADDMEM_OK       = 662;
   SM_GROUPDELMEM_OK       = 663;
   SM_GROUPADDMEM_FAIL     = 664;
   SM_GROUPDELMEM_FAIL     = 665;
   SM_GROUPCANCEL          = 666;
   SM_GROUPMEMBERS         = 667;
   SM_SENDUSERREPAIR       = 668;
   SM_USERREPAIRITEM_OK    = 669;
   SM_USERREPAIRITEM_FAIL  = 670;
   SM_SENDREPAIRCOST       = 671;
   SM_DEALMENU             = 673;
   SM_DEALTRY_FAIL         = 674;
   SM_DEALADDITEM_OK       = 675;
   SM_DEALADDITEM_FAIL     = 676;
   SM_DEALDELITEM_OK       = 677;
   SM_DEALDELITEM_FAIL     = 678;
   //SM_DEALREMOTEADDITEM_OK = 679;
   //SM_DEALREMOTEDELITEM_OK = 680;
   SM_DEALCANCEL           = 681; //도중에 거래 취소됨
   SM_DEALREMOTEADDITEM    = 682; //상대방이 교환 아이템을 추가
   SM_DEALREMOTEDELITEM    = 683; //상대방이 교환 아이템을 뺌
   SM_DEALCHGGOLD_OK       = 684;
   SM_DEALCHGGOLD_FAIL     = 685;
   SM_DEALREMOTECHGGOLD    = 686;
   SM_DEALSUCCESS          = 687;
   SM_SENDUSERSTORAGEITEM  = 700;
   SM_STORAGE_OK           = 701;
   SM_STORAGE_FULL         = 702; //더 보관 못 함.
   SM_STORAGE_FAIL         = 703; //보관 에러
   SM_SAVEITEMLIST         = 704;
   SM_TAKEBACKSTORAGEITEM_OK = 705;
   SM_TAKEBACKSTORAGEITEM_FAIL = 706;
   SM_TAKEBACKSTORAGEITEM_FULLBAG = 707;
   SM_AREASTATE            = 708; //안전,대련,일반..
   SM_DELITEMS             = 709;
   SM_READMINIMAP_OK       = 710;
   SM_READMINIMAP_FAIL     = 711;
   SM_SENDUSERMAKEDRUGITEMLIST = 712;
   SM_MAKEDRUG_SUCCESS     = 713;
   SM_MAKEDRUG_FAIL        = 714;
   SM_ALLOWPOWERHIT        = 715;
   SM_NORMALEFFECT         = 716;  //기본 효과
   // 아이템 제조
   SM_SENDUSERMAKEITEMLIST = 717;

   SM_CHANGEGUILDNAME      = 750;  //길드의 이름 혹의 길드내의 직책이름이 변경
   SM_SENDUSERSTATE        = 751;  //
   SM_SUBABILITY           = 752;
   SM_OPENGUILDDLG         = 753;
   SM_OPENGUILDDLG_FAIL    = 754;
   SM_SENDGUILDHOME        = 755;
   SM_SENDGUILDMEMBERLIST  = 756;
   SM_GUILDADDMEMBER_OK    = 757;
   SM_GUILDADDMEMBER_FAIL  = 758;
   SM_GUILDDELMEMBER_OK    = 759;
   SM_GUILDDELMEMBER_FAIL  = 760;
   SM_GUILDRANKUPDATE_FAIL = 761;
   SM_BUILDGUILD_OK        = 762;
   SM_BUILDGUILD_FAIL      = 763;
   SM_DONATE_FAIL          = 764;
   SM_DONATE_OK            = 765;
   SM_MYSTATUS             = 766;
   SM_MENU_OK              = 767;  //description으로 메세지 전달
   SM_GUILDMAKEALLY_OK     = 768;
   SM_GUILDMAKEALLY_FAIL   = 769;
   SM_GUILDBREAKALLY_OK    = 770;
   SM_GUILDBREAKALLY_FAIL  = 771;
   SM_DLGMSG               = 772;

   SM_SPACEMOVE_HIDE       = 800;  //순간이동 사라짐
   SM_SPACEMOVE_SHOW       = 801;  //나타남
   SM_RECONNECT            = 802;
   SM_GHOST                = 803;  //화면에 나타난 잔상임
   SM_SHOWEVENT            = 804;
   SM_HIDEEVENT            = 805;
   SM_SPACEMOVE_HIDE2      = 806;  //순간이동 사라짐
   SM_SPACEMOVE_SHOW2      = 807;  //나타남
   SM_SPACEMOVE_SHOW_NO    = 808;  //나타남(이펙트 없음)

   SM_TIMECHECK_MSG        = 810;  //클라이언트에서 시간
   SM_ADJUST_BONUS         = 811;  //보너스 포인트를 조정하라.
   // Frined System -------------
   SM_FRIEND_DELETE        = 812;   //친구 삭제
   SM_FRIEND_INFO          = 813;   //친구 추가 및 정보변경
   SM_FRIEND_RESULT        = 814;   //친구관련 결과값 전송
   // Tag System ----------------
   SM_TAG_ALARM            = 815;   //쪽지왔음 알림
   SM_TAG_LIST             = 816;   //쪽지리스트
   SM_TAG_INFO             = 817;   //쪽지정보 변경
   SM_TAG_REJECT_LIST      = 818;   //거부자 리스트
   SM_TAG_REJECT_ADD       = 819;   //거부자 추가
   SM_TAG_REJECT_DELETE    = 820;   //거부자 삭제
   SM_TAG_RESULT           = 821;   //쪽지관련 결과값 전송
   // User System ---------------
   SM_USER_INFO            = 822;   //유저의 접속상태및 맵정보전송
   // RelationShip --------------
   SM_LM_LIST              = 823;   //관계 리스트
   SM_LM_OPTION            = 824;   //관계 옵션
   SM_LM_REQUEST           = 825;   //관계 설정 요구
   SM_LM_DELETE            = 826;   //관계 삭제
   SM_LM_RESULT            = 827;   //관계 결과값 전송
   // 위탁판매 ---------------------
   SM_MARKET_LIST          = 828;   // 위탁리스트전송
   SM_MARKET_RESULT        = 829;   // 위탁결과  전송

   // 문파장원 ---------------------
   SM_GUILDAGITLIST        = 830;   //장원 판매 목록
   SM_GUILDAGITDEALMENU    = 831;   //장원거래

   // 장원게시판
   SM_GABOARD_LIST         = 832;  // 장원게시판 리스트
   SM_GABOARD_READ         = 833;  // 장원게시판 글읽기
   SM_GABOARD_NOTICE_OK    = 834;  // 장원게시판 공지사항 쓰기 OK
   SM_GABOARD_NOTICE_FAIL  = 835;  // 장원게시판 공지사항 쓰기 FAIL

   // 장원꾸미기
   SM_DECOITEM_LIST        = 836;  // 장원꾸미기 아이템 리스트
   SM_DECOITEM_LISTSHOW    = 837;  // 장원꾸미기 아이템 리스트

   // 그룹 결성 확인
   SM_CREATEGROUPREQ       = 838;   //그룹 결성 확인
   SM_ADDGROUPMEMBERREQ    = 839;   //그룹 결성 확인
   // RelationShip (cont.)--------------
   SM_LM_DELETE_REQ        = 840;   //관계 삭제 확인

   //1000 ~ 1099  액션으로 예약

   SM_OPENHEALTH           = 1100;  //체력이 상대방에 보임
   SM_CLOSEHEALTH          = 1101;  //체력이 상대방에게 보이지 않음
   SM_BREAKWEAPON          = 1102;
   SM_INSTANCEHEALGUAGE    = 1103;
   SM_CHANGEFACE           = 1104;  //변신...
   SM_NEXTTIME_PASSWORD    = 1105;  //다음번에는 비밀번호 입력 모드이다.
   SM_CHECK_CLIENTVALID    = 1106;  //클라이언트의 수정 여부 확인

   SM_LOOPNORMALEFFECT     = 1107;  //루프 임펙트 효과
   SM_LOOPSCREENEFFECT     = 1108;  //화면 이펙트

   SM_PLAYDICE             = 1200;
   SM_PLAYROCK             = 1201;
   // 2003/02/11 그룹원 위치 정보
   SM_GROUPPOS             = 1312;

   // UpgradeItem_Result ---------------- by sonmg...2003/10/02
   SM_UPGRADEITEM_RESULT     = 1300;
   // 겹치기
   SM_COUNTERITEMCHANGE      = 1301;
   SM_USERSELLCOUNTITEM_OK   = 1302;
   SM_USERSELLCOUNTITEM_FAIL = 1303;

   SM_CANCLOSE_OK            = 1304;
   SM_CANCLOSE_FAIL          = 1305;


   //CM_??   클라이언트 -> 서버로
   //  2000 ~ 4000
   CM_PROTOCOL             = 2000;
   CM_IDPASSWORD           = 2001;
   CM_ADDNEWUSER           = 2002;
   CM_CHANGEPASSWORD       = 2003;
   CM_UPDATEUSER           = 2004;

   {----------------------------}

   CM_QUERYCHR             = 100;
   CM_NEWCHR               = 101;
   CM_DELCHR               = 102;
   CM_SELCHR               = 103;
   CM_SELECTSERVER         = 104;  //서버를 선택 (+ 서버이름)

   //3000 - 3099 클라이언트 이동 메세지도 예약
   //서버에서 이동 메세지도 0..99 사이 이어야 한다.
   CM_THROW                = 3005;
   CM_TURN                 = 3010;    //CM_TURN - 3000 = SM_TURN 규칙을 반드시 지켜야 함
   CM_WALK                 = 3011;
   CM_SITDOWN              = 3012;
   CM_RUN                  = 3013;
   CM_HIT                  = 3014;
   CM_HEAVYHIT             = 3015;
   CM_BIGHIT               = 3016;
   CM_SPELL                = 3017;
   CM_POWERHIT             = 3018;  //더 세게 때림
   CM_LONGHIT              = 3019;  //더 세게 때림
   CM_WIDEHIT              = 3024;
   CM_FIREHIT              = 3025;
   CM_SAY                  = 3030;
   // 2003/03/15 신규무공
   CM_CROSSHIT             = 3035;
   CM_TWINHIT              = 3036;

   CM_QUERYUSERNAME        = 80;  //QUERY 시리즈 명령어
   CM_QUERYBAGITEMS        = 81;
   CM_QUERYUSERSTATE       = 82;  //타인의 상태 보기

   CM_DROPITEM             = 1000;
   CM_PICKUP               = 1001;
   CM_OPENDOOR             = 1002;
   CM_TAKEONITEM           = 1003;  //복장을 착용
   CM_TAKEOFFITEM          = 1004;  //복장을 벗는다
   CM_EXCHGTAKEONITEM      = 1005;  //착용한 아이템을 좌우를 바꾼다.(반지,팔찌)
   CM_EAT                  = 1006;  //먹다, 마시다
   CM_BUTCH                = 1007;  //도륙하다
   CM_MAGICKEYCHANGE       = 1008;
   CM_SOFTCLOSE            = 1009;
   CM_CLICKNPC             = 1010;
   CM_MERCHANTDLGSELECT    = 1011;
   CM_MERCHANTQUERYSELLPRICE = 1012;
   CM_USERSELLITEM         = 1013;  //아이템 팔기
   CM_USERBUYITEM          = 1014;
   CM_USERGETDETAILITEM    = 1015;
   CM_DROPGOLD             = 1016;
   CM_TEST                 = 1017;  //테스트
   CM_LOGINNOTICEOK        = 1018;
   CM_GROUPMODE            = 1019;
   CM_CREATEGROUP          = 1020;
   CM_ADDGROUPMEMBER       = 1021;
   CM_DELGROUPMEMBER       = 1022;
   CM_USERREPAIRITEM       = 1023;
   CM_MERCHANTQUERYREPAIRCOST = 1024;
   CM_DEALTRY              = 1025;
   CM_DEALADDITEM          = 1026;
   CM_DEALDELITEM          = 1027;
   CM_DEALCANCEL           = 1028;
   CM_DEALCHGGOLD          = 1029; //교환하는 돈이 변경됨
   CM_DEALEND              = 1030;
   CM_USERSTORAGEITEM      = 1031;
   CM_USERTAKEBACKSTORAGEITEM = 1032;
   CM_WANTMINIMAP          = 1033;
   CM_USERMAKEDRUGITEM     = 1034;
   CM_OPENGUILDDLG         = 1035;
   CM_GUILDHOME            = 1036;
   CM_GUILDMEMBERLIST      = 1037;
   CM_GUILDADDMEMBER       = 1038;
   CM_GUILDDELMEMBER       = 1039;
   CM_GUILDUPDATENOTICE    = 1040;
   CM_GUILDUPDATERANKINFO  = 1041;
   CM_SPEEDHACKUSER        = 1042;
   CM_ADJUST_BONUS         = 1043;
   CM_GUILDMAKEALLY        = 1044;
   CM_GUILDBREAKALLY       = 1045;
   // Frined System---------------
   CM_FRIEND_ADD           = 1046;  // 친구추가
   CM_FRIEND_DELETE        = 1047;  // 친구삭제
   CM_FRIEND_EDIT          = 1048;  // 친구설명 변경
   CM_FRIEND_LIST          = 1049;  // 친구 리스트 요청
   // Tag System -----------------
   CM_TAG_ADD              = 1050;  // 쪽지 추가
   CM_TAG_DELETE           = 1051;  // 쪽지 삭제
   CM_TAG_SETINFO          = 1052;  // 쪽지 상태 변경
   CM_TAG_LIST             = 1053;  // 쪽지 리스트 요청
   CM_TAG_NOTREADCOUNT     = 1054;  // 읽지않은 쪽지 개수 요청
   CM_TAG_REJECT_LIST      = 1055;  // 거부자 리스트
   CM_TAG_REJECT_ADD       = 1056;  // 거부자 추가
   CM_TAG_REJECT_DELETE    = 1057;  // 거부자 삭제
   // Relationship ---------------
   CM_LM_OPTION            = 1058;  // 관계 활성 / 비활성
   CM_LM_REQUEST           = 1059;  // 관계 등록 요청
   CM_LM_Add               = 1060;  // 관계 추가 ( 내부적으로 쓰임 )
   CM_LM_EDIT              = 1061;  // 관계 수정
   CM_LM_DELETE            = 1062;  // 관계 파기
   // UpgradeItem ---------------- by sonmg...2003/10/02
   CM_UPGRADEITEM          = 1063;  // 아이템 업그레이드 요청
   // 카운트 아이템
   CM_DROPCOUNTITEM        = 1064;  // 겹치기 아이템 떨어뜨림
   // 아이템 제조
   CM_USERMAKEITEMSEL      = 1065;
   CM_USERMAKEITEM         = 1066;
   CM_ITEMSUMCOUNT         = 1067;

   // 위탁판매 -------------------
   CM_MARKET_LIST          = 1068;  // 위탁판매 레스트 요청
   CM_MARKET_SELL          = 1069;  // 위탁판매 유저 -> NPC
   CM_MARKET_BUY           = 1070;  // 위탁사기 NPC -> 유저
   CM_MARKET_CANCEL        = 1071;  // 위탁취소 NPC -> 유저
   CM_MARKET_GETPAY        = 1072;  // 위탁금회수 NPC -> 유저
   CM_MARKET_CLOSE         = 1073;  // 위탁상점 이용 끝

   // 장원 판매 목록
   CM_GUILDAGITLIST        = 1074;
   CM_GUILDAGIT_TAG_ADD    = 1075;  // 장원 쪽지 보내기

   // 장원게시판
   CM_GABOARD_LIST         = 1076;  // 장원게시판 리스트
   CM_GABOARD_ADD          = 1077;  // 장원게시판 글쓰기
   CM_GABOARD_READ         = 1078;  // 장원게시판 글읽기
   CM_GABOARD_EDIT         = 1079;  // 장원게시판 글수정
   CM_GABOARD_DEL          = 1080;  // 장원게시판 글삭제
   CM_GABOARD_NOTICE_CHECK = 1081;  // 장원게시판 공지사항 쓰기 체크

   CM_TAG_ADD_DOUBLE       = 1082;  // 두명 동시 쪽지 추가

   // 장원꾸미기 -------------------
   CM_DECOITEM_BUY         = 1083;  // 장원꾸미기 아이템 구입

   //그룹 결성 확인
   CM_CREATEGROUPREQ_OK    = 1084;  //그룹 결성 확인
   CM_CREATEGROUPREQ_FAIL  = 1085;  //그룹 결성 확인

   CM_ADDGROUPMEMBERREQ_OK   = 1086;  //그룹 결성 확인
   CM_ADDGROUPMEMBERREQ_FAIL = 1087;  //그룹 결성 확인

   // Relationship (cont.)---------------
   CM_LM_DELETE_REQ_OK     = 1088;  // 관계 파기 OK
   CM_LM_DELETE_REQ_FAIL   = 1089;  // 관계 파기 FAIL

   CM_CLIENT_CHECKTIME     = 1100;
   CM_CANCLOSE             = 1101;

   {----------------------------}

   RM_TURN                 = 10001;
   RM_WALK                 = 10002;
   RM_RUN                  = 10003;
   RM_HIT                  = 10004;
   RM_HEAVYHIT             = 10005;
   RM_BIGHIT               = 10006;
   RM_SPELL                = 10007;
   RM_POWERHIT             = 10008;
   RM_SITDOWN              = 10009;
   RM_MOVEFAIL             = 10010;
   RM_LONGHIT              = 10011;
   RM_WIDEHIT              = 10012;
   RM_PUSH                 = 10013;
   RM_FIREHIT              = 10014;
   RM_RUSH                 = 10015;
   RM_RUSHKUNG             = 10016;
   // 2003/03/15 신규무공
   RM_CROSSHIT             = 10017;
   RM_TWINHIT              = 10019;
   RM_DECREFOBJCOUNT       = 10018;

   RM_STRUCK               = 10020;
   RM_DEATH                = 10021;
   RM_DISAPPEAR            = 10022;
//   RM_HIDE                 = 10023;
   RM_SKELETON             = 10024;
   RM_MAGSTRUCK            = 10025;  //체력이 이 시점에서 닳는다.
   RM_MAGHEALING           = 10026;  //힐링
   RM_STRUCK_MAG           = 10027;  //마법으로 맞음
   RM_MAGSTRUCK_MINE       = 10028;  //지뢰밣음
   RM_STONEHIT             = 10029;

   RM_HEAR                 = 10030;
   RM_WHISPER              = 10031;
   RM_CRY                  = 10032;
   RM_TAG_ADD              = 10033;

   RM_WINDCUT              = 10040; // 공파섬
   RM_DRAGONFIRE           = 10041; // 천룡기염(->화룡기염)
   RM_CURSE                = 10042; // 저주술

   RM_LOGON                = 10050;
   RM_ABILITY              = 10051;
   RM_HEALTHSPELLCHANGED   = 10052;
   RM_DAYCHANGING          = 10053;

   RM_USERNAME             = 10043;
   RM_WINEXP               = 10044;
   RM_LEVELUP              = 10045;
   RM_CHANGENAMECOLOR      = 10046;

   //2004/06/22 신규무공(포승검, 흡혈술, 맹안술)
   RM_PULLMON              = 10047;  //포승검, 끌어당김
   RM_SUCKBLOOD            = 10048;  //흡혈술, 피를 빨아들임
   RM_BLINDMON             = 10049;  //맹안술, 적의 시야를 가림

   RM_CHANGEFAMEPOINT      = 10054;    //명성치 변화(2004/11/04)
   RM_GMWHISPER            = 10055;    //운영자 모드일 때 귓말(2004/11/18)
   RM_LM_WHISPER           = 10056;    //연인 귓속말

   RM_FOXSTATE             = 10057;    //비월천주 상태

   RM_SYSMESSAGE           = 10100;
   RM_REFMESSAGE           = 10101;
   RM_GROUPMESSAGE         = 10102;
   RM_SYSMESSAGE2          = 10103;
   RM_GUILDMESSAGE         = 10104;
   RM_SYSMSG_BLUE          = 10105;
   RM_SYSMESSAGE3          = 10106;
   RM_SYSMSG_REMARK        = 10107;
   RM_SYSMSG_PINK          = 10108;
   RM_SYSMSG_GREEN         = 10109;

   RM_ITEMSHOW             = 10110;
   RM_ITEMHIDE             = 10111;
   RM_OPENDOOR_OK          = 10112;
   RM_CLOSEDOOR            = 10113;
   RM_SENDUSEITEMS         = 10114;
   RM_WEIGHTCHANGED        = 10115;
   RM_FEATURECHANGED       = 10116;
   RM_CLEAROBJECTS         = 10117;
   RM_CHANGEMAP            = 10118;
   RM_BUTCH                = 10119; //
   RM_MAGICFIRE            = 10120;
   RM_MAGICFIRE_FAIL       = 10121;
   RM_SENDMYMAGIC          = 10122;
   RM_MAGIC_LVEXP          = 10123;
   RM_SOUND                = 10124;
   RM_DURACHANGE           = 10125;
   RM_MERCHANTSAY          = 10126;
   RM_MERCHANTDLGCLOSE     = 10127;
   RM_SENDGOODSLIST        = 10128;
   RM_SENDUSERSELL         = 10129;
   RM_SENDBUYPRICE         = 10130;  //상점에서 사용자의 아이템을 사는 가격
   RM_USERSELLITEM_OK      = 10131;
   RM_USERSELLITEM_FAIL    = 10132;
   RM_BUYITEM_SUCCESS      = 10133;
   RM_BUYITEM_FAIL         = 10134;
   RM_SENDDETAILGOODSLIST  = 10135;
   RM_GOLDCHANGED          = 10136;
   RM_CHANGELIGHT          = 10137;
   RM_LAMPCHANGEDURA       = 10138;
   RM_CHARSTATUSCHANGED    = 10139;
   RM_GROUPCANCEL          = 10140;
   RM_SENDUSERREPAIR       = 10141;
   RM_SENDREPAIRCOST       = 10142;
   RM_USERREPAIRITEM_OK    = 10143;
   RM_USERREPAIRITEM_FAIL  = 10144;
   //RM_ITEMDURACHANGE       = 10145;
   RM_SENDUSERSTORAGEITEM  = 10146;
   RM_SENDUSERSTORAGEITEMLIST = 10147;
   RM_DELITEMS             = 10148;  //아이템 읽어 버림, 클라이언테에 알림.
   RM_SENDUSERMAKEDRUGITEMLIST = 10149;
   RM_MAKEDRUG_SUCCESS     = 10150;
   RM_MAKEDRUG_FAIL        = 10151;
   RM_SENDUSERSPECIALREPAIR = 10152;
   RM_ALIVE                = 10153;
   RM_DELAYMAGIC           = 10154;
   RM_RANDOMSPACEMOVE      = 10155;
   // 아이템 제조
   RM_SENDUSERMAKEITEMLIST = 10156;

   RM_DIGUP                = 10200;
   RM_DIGDOWN              = 10201;
   RM_FLYAXE               = 10202;
   RM_ALLOWPOWERHIT        = 10203;
   RM_LIGHTING             = 10204;
   RM_NORMALEFFECT         = 10205;  //기본 효과
   RM_DRAGON_FIRE1         = 10206;
   RM_DRAGON_FIRE2         = 10207;
   RM_DRAGON_FIRE3         = 10208;
   RM_LIGHTING_1           = 10209;
   RM_LIGHTING_2           = 10210;
   RM_LIGHTING_3           = 10211;

   RM_MAKEPOISON           = 10300;
   RM_CHANGEGUILDNAME      = 10301; //길드의 이름, 길드내 직책이름 변경
   RM_SUBABILITY           = 10302;
   RM_BUILDGUILD_OK        = 10303;
   RM_BUILDGUILD_FAIL      = 10304;
   RM_DONATE_FAIL          = 10305;
   RM_DONATE_OK            = 10306;
   RM_MYSTATUS             = 10307;
   RM_TRANSPARENT          = 10308;
   RM_MENU_OK              = 10309;

   RM_SPACEMOVE_HIDE       = 10330;
   RM_SPACEMOVE_SHOW       = 10331;
   RM_RECONNECT            = 10332;
   RM_HIDEEVENT            = 10333;
   RM_SHOWEVENT            = 10334;
   RM_SPACEMOVE_HIDE2      = 10335;
   RM_SPACEMOVE_SHOW2      = 10336;
   RM_ZEN_BEE              = 10337;  //비막원충이 비막충을 만들어 낸다.
   RM_DELAYATTACK          = 10338;  //타격 시점을 맞추기 위해서
   RM_SPACEMOVE_SHOW_NO    = 10339;  //이펙트 없이 나타남

   RM_ADJUST_BONUS         = 10400;  //보너스 포인트를 조정하라.
   RM_MAKE_SLAVE           = 10401;  //서버이동으로 부하가 따라온다.

   RM_OPENHEALTH           = 10410;  //체력이 상대방에 보임
   RM_CLOSEHEALTH          = 10411;  //체력이 상대방에게 보이지 않음
   RM_DOOPENHEALTH         = 10412;
   RM_BREAKWEAPON          = 10413;  //무기가 깨짐, 애미메이션 효과
   RM_INSTANCEHEALGUAGE    = 10414;
   RM_CHANGEFACE           = 10415;  //변신...
   RM_NEXTTIME_PASSWORD    = 10416;  //다음 한번은 비밀번호입력 모드
   RM_DOSTARTUPQUEST       = 10417;
   RM_TAG_ALARM            = 10418;  //내부적으로 쪽지왔음알림

   RM_LM_DBWANTLIST        = 10420;  // 연인사제 리스트원함
   RM_LM_DBADD             = 10421;  // 연인사제 리스트원함
   RM_LM_DBEDIT            = 10422;  // 연인사제 리스트원함
   RM_LM_DBDELETE          = 10423;  // 연인사제 리스트원함
   RM_LM_DBGETLIST         = 10424;  // 연인사제 리스트얻음
   RM_LM_LOGOUT            = 10425;  // 연인 종료를 알려줌

   RM_DRAGON_EXP           = 10430;  // 용시스템에 경험치 준다.

   RM_LOOPNORMALEFFECT     = 10431;  //루프 임펙트 효과
   RM_LOOPSCREENEFFECT     = 10432;  //화면 이펙트

   RM_PLAYDICE             = 10500;
   RM_PLAYROCK             = 10501;
   //2003/02/11 그룹원 위치 정보
   RM_GROUPPOS             = 11008;

   // 카운트 아이템
   RM_COUNTERITEMCHANGE    = 11011;
   RM_USERSELLCOUNTITEM_OK = 11012;
   RM_USERSELLCOUNTITEM_FAIL = 11013;
   // 아이템 제조
   RM_SENDUSERMAKEFOODLIST = 11014;
   // 아이템 위탁판매
   RM_MARKET_LIST          = 11015;
   RM_MARKET_RESULT        = 11016;

   // 장원 판매 목록
   RM_GUILDAGITLIST     = 11017;
   RM_GUILDAGITDEALTRY  = 11018;

   // 장원게시판
   RM_GABOARD_LIST         = 11019;  // 장원게시판 리스트
   RM_GABOARD_NOTICE_OK    = 11020;  // 장원게시판 공지사항 쓰기 OK
   RM_GABOARD_NOTICE_FAIL  = 11021;  // 장원게시판 공지사항 쓰기 FAIL

   // 장원꾸미기
   RM_DECOITEM_LIST        = 11022;  // 장원꾸미기 아이템 리스트
   RM_DECOITEM_LISTSHOW    = 11023;  // 장원꾸미기 아이템 리스트창 띄우기

   RM_CANCLOSE_OK          = 11024;
   RM_CANCLOSE_FAIL        = 11025;



   {----------------------------}
   //서버간 메세지서버를 거치지 않은 메세징

   ISM_PASSWDSUCCESS       = 100;  //패스워드 통과, Certification+ID
   ISM_CANCELADMISSION     = 101;  //Certification 승인취소..
   ISM_USERCLOSED          = 102;  //사용자 접속 끊음
   ISM_USERCOUNT           = 103;  //이 서버의 사용자 수
   ISM_TOTALUSERCOUNT      = 104;
   ISM_SHIFTVENTURESERVER  = 110;
   ISM_ACCOUNTEXPIRED      = 111;
   ISM_GAMETIMEOFTIMECARDUSER = 112;
   ISM_USAGEINFORMATION    = 113;
   ISM_FUNC_USEROPEN       = 114;
   ISM_FUNC_USERCLOSE      = 115;
   ISM_CHECKTIMEACCOUNT    = 116;
   ISM_REQUEST_PUBLICKEY   = 117;
   ISM_SEND_PUBLICKEY      = 118;
   ISM_PREMIUMCHECK        = 119;
   ISM_EVENTCHECK          = 120;

   {----------------------------}

   ISM_USERSERVERCHANGE    = 200;
   ISM_USERLOGON           = 201;
   ISM_USERLOGOUT          = 202;
   ISM_WHISPER             = 203;
   ISM_SYSOPMSG            = 204;
   ISM_ADDGUILD            = 205;
   ISM_DELGUILD            = 206;
   ISM_RELOADGUILD         = 207;
   ISM_GUILDMSG            = 208;
   ISM_CHATPROHIBITION     = 209;    //채금
   ISM_CHATPROHIBITIONCANCEL = 210;  //채금해제
   ISM_CHANGECASTLEOWNER   = 211;   //사북성 주인 변경
   ISM_RELOADCASTLEINFO    = 212;   //사북성정보가 변경됨
   ISM_RELOADADMIN         = 213;

   // Friend System -------------
   ISM_FRIEND_INFO         = 214;    // 친구정보 추가
   ISM_FRIEND_DELETE       = 215;    // 친구 삭제
   ISM_FRIEND_OPEN         = 216;    // 친구 시스템 열기
   ISM_FRIEND_CLOSE        = 217;    // 친구 시스템 닫기
   ISM_FRIEND_RESULT       = 218;    // 결과값 전송
   // Tag System ----------------
   ISM_TAG_SEND            = 219;    // 쪽지 전송
   ISM_TAG_RESULT          = 220;    // 결과값 전송
   // User System --------------
   ISM_USER_INFO           = 221;    // 유저의 접속상태 전송
   // 2003/06/12 슬레이브 패치
   ISM_CHANGESERVERRECIEVEOK = 222;
   // 2003/08/28 채팅로그
   ISM_RELOADCHATLOG       = 223;
   // 위탁판매 열고 닫음
   ISM_MARKETOPEN          = 224;
   ISM_MARKETCLOSE         = 225;  
   // relationship --------------
//   ISM_LM_INFO             = 224;   // 관계 정보 전송
//   ISM_LM_LEVELINFO        = 225;   // 관계 레벨정보 전송
   ISM_LM_DELETE           = 226;

   // 제조 재료 목록 ------------(sonmg)
   ISM_RELOADMAKEITEMLIST  = 227;   // 제조 재료 목록 리로드

   // 문원소환 ------------(sonmg)
   ISM_GUILDMEMBER_RECALL  = 228;   // 문원소환
   ISM_RELOADGUILDAGIT     = 229;   // 문파장원정보 리로드.

   //연인
   ISM_LM_WHISPER          = 230;
   ISM_GMWHISPER           = 231;   //운영자 귓말
   //연인(sonmg 2005/04/04)
   ISM_LM_LOGIN            = 232;   //연인 로그인
   ISM_LM_LOGOUT           = 233;   //연인 로그아웃
   ISM_REQUEST_RECALL      = 234;   //소환 요청
   ISM_RECALL              = 235;   //서버간 소환
   ISM_LM_LOGIN_REPLY      = 236;   //로그인 했을 때 연인의 위치정보
   ISM_LM_KILLED_MSG       = 237;   //연인 살해 메시지
   ISM_REQUEST_LOVERRECALL = 238;   //연인 소환 요청

   ISM_GUILDWAR            = 239;   //문파전 신청연장
   ISM_STANDARDTICK        = 240;   //0번 서버의 표준 틱 정보

   {----------------------------}

   DB_LOADHUMANRCD         = 100;
   DB_SAVEHUMANRCD         = 101;
   DB_SAVEANDCHANGE        = 102;
   DB_IDPASSWD             = 103;
   DB_NEWUSERID            = 104;
   DB_CHANGEPASSWD         = 105;
   DB_QUERYCHR             = 106;
   DB_NEWCHR               = 107;
   DB_GETOTHERNAMES        = 108;
   DB_ISVALIDUSER          = 111;
   DB_DELCHR               = 112;
   DB_ISVALIDUSERWITHID    = 113;
   DB_CONNECTIONOPEN       = 114;
   DB_CONNECTIONCLOSE      = 115;
   DB_SAVELOGO             = 116;
   DB_GETACCOUNT           = 117;
   DB_SAVESPECFEE          = 118;
   DB_SAVELOGO2            = 119;
   DB_GETSERVER            = 120;
   DB_CHANGESERVER         = 121;
   DB_LOGINCLOSEUSER       = 122;
   DB_RUNCLOSEUSER         = 123;
   DB_UPDATEUSERINFO       = 124;
   // Friend System -------------
   DB_FRIEND_LIST          = 125;   // 친구 리스트 요구
   DB_FRIEND_ADD           = 126;   // 친구 추가
   DB_FRIEND_DELETE        = 127;   // 친구 삭제
   DB_FRIEND_OWNLIST       = 128;   // 친구로 등록한 사람 리스트 요구
   DB_FRIEND_EDIT          = 129;   // 친구 설명 수정
   // Tag System ----------------
   DB_TAG_ADD              = 130;   // 쪽지 추가
   DB_TAG_DELETE           = 131;   // 쪽지 삭제
   DB_TAG_DELETEALL        = 132;   // 쪽지 전부 삭제 ( 가능한것만 )
   DB_TAG_LIST             = 133;   // 쪽지 리스트 추가
   DB_TAG_SETINFO          = 134;   // 촉지 상태 변경
   DB_TAG_REJECT_ADD       = 135;   // 거부자 추가
   DB_TAG_REJECT_DELETE    = 136;   // 거부자 삭제
   DB_TAG_REJECT_LIST      = 137;   // 거부자 리스트 요청
   DB_TAG_NOTREADCOUNT     = 138;   // 읽지않은 쪽지 개수 요청
   // RelationShip --------------
   DB_LM_LIST              = 139;   // 관계자 리스트 요구
   DB_LM_ADD               = 140;   // 관계자 추가
   DB_LM_EDIT              = 141;   // 관계자 설정 변경
   DB_LM_DELETE            = 142;   // 관계자 삭제

   DBR_LOADHUMANRCD         = 1100;
   DBR_SAVEHUMANRCD         = 1101;
   DBR_IDPASSWD             = 1103;
   DBR_NEWUSERID            = 1104;
   DBR_CHANGEPASSWD         = 1105;
   DBR_QUERYCHR             = 1106;
   DBR_NEWCHR               = 1107;
   DBR_GETOTHERNAMES        = 1108;
   DBR_ISVALIDUSER          = 1111;
   DBR_DELCHR               = 1112;
   DBR_ISVALIDUSERWITHID    = 1113;
   DBR_GETACCOUNT           = 1117;
   DBR_GETSERVER            = 1200;
   DBR_CHANGESERVER         = 1201;
   DBR_UPDATEUSERINFO       = 1202;
   // Friend System ---------------
   DBR_FRIEND_LIST          = 1203; // 친구 리스트 전송
   DBR_FRIEND_WONLIST       = 1204; // 친구로 등록한 사람 전송
   DBR_FRIEND_RESULT        = 1205; // 명령어에 대한 결과값
   // Tag System ------------------
   DBR_TAG_LIST             = 1206; // 쪽지 리스트 전송
   DBR_TAG_REJECT_LIST      = 1207; // 거부자 리스트 전송
   DBR_TAG_NOTREADCOUNT     = 1208; // 읽지않은 쪽지 새수 전송
   DBR_TAG_RESULT           = 1209; // 멸령에 대한 결과값
   // RelationShip ---------------
   DBR_LM_LIST              = 1210; // 관계 리스트 얻어오기
   DBR_LM_RESULT            = 1211; // 명령어에 대한 결과값

   DBR_FAIL                 = 2000;
   DBR_NONE                 = 2000;

   {----------------------------}

   MSM_LOGIN            = 1;
   MSM_GETUSERKEY       = 100;
   MSM_SELECTUSERKEY    = 101;
   MSM_GETGROUPKEY      = 102;
   MSM_SELECTGROUPKEY   = 103;
   MSM_UPDATEFEERCD     = 120;
   MSM_DELETEFEERCD     = 121;
   MSM_ADDFEERCD        = 122;
   MSM_GETTIMEOUTLIST   = 123;

   MCM_PASSWDSUCCESS    = 10;
   MCM_PASSWDFAIL       = 11;
   MCM_IDONUSE          = 12;
   MCM_GETFEERCD        = 1000;
   MCM_ADDFEERCD        = 1001;
   MCM_ENDTIMEOUT       = 1002;
   MCM_ONUSETIMEOUT     = 1003;


   //게이트와 서버와의 통신

   GM_OPEN              = 1;
   GM_CLOSE             = 2;
   GM_CHECKSERVER       = 3;     //서버에서 채크 신호를 보냄
   GM_CHECKCLIENT       = 4;     //클라이언트에서 채크 신호를 보냄
   GM_DATA              = 5;
   GM_SERVERUSERINDEX   = 6;
   GM_RECEIVE_OK        = 7;
   GM_SENDPUBLICKEY     = 8;
   GM_TEST              = 20;

   {----------------------------}


   //종족
   RC_USERHUMAN   = 0;           //경험치를 얻을 수 없음
   RC_NPC         = 10;
   RC_DOORGUARD   = 11;          //문지기 경비병
   RC_PEACENPC    = 15;

   RC_ARCHERPOLICE = 20;

   RC_ANIMAL      = 50;
   RC_HEN         = 51;     //닭
   RC_DEER        = 52;     //사슴...
   RC_WOLF        = 53;     //늑대
   RC_RUNAWAYHEN  = 54;     //달아나는 닭
   RC_TRAINER     = 55;     //수련조교
   RC_MONSTER     = 80;     //비선몹
   RC_OMA         = 81;
   RC_SPITSPIDER  = 82;
   RC_SLOWMONSTER = 83;
   RC_SCORPION     = 84;  //전갈
   RC_KILLINGHERB  = 85;  //식인초
   RC_SKELETON     = 86;  //해골
   RC_DUALAXESKELETON = 87;  //쌍도끼해골
   RC_HEAVYAXESKELETON = 88;  //큰도끼해골
   RC_KNIGHTSKELETON = 89;  //해골전사
   RC_BIGKUDEKI      = 90;
   RC_MAGCOWFACEMON  = 91;
   RC_COWFACEKINGMON = 92;
   RC_THORNDARK      = 93;
   RC_LIGHTINGZOMBI  = 94;
   RC_DIGOUTZOMBI    = 95;
   RC_ZILKINZOMBI    = 96;
   RC_COWMON         = 97;   //우면귀
   RC_WHITESKELETON  = 100;  //백골
   RC_SCULTUREMON    = 101;  //석상몬스터
   RC_SCULKING       = 102;  //주마왕
   RC_BEEQUEEN       = 103;  //벌통
   RC_ARCHERMON      = 104;  //마궁사, 해골궁수
   RC_GASMOTH        = 105;
   RC_DUNG           = 106;  //둥, 가스
   RC_CENTIPEDEKING  = 107;  //지네왕
   RC_BLACKPIG       = 108;  //흑돈
   RC_CASTLEDOOR     = 110;  //사북성문, 성벽,..
   RC_WALL           = 111;  //사북성문, 성벽,..
   RC_ARCHERGUARD    = 112;  //궁수경비
   RC_ELFMON         = 113;
   RC_ELFWARRIORMON  = 114;
   RC_BIGHEARTMON    = 115;  //혈거인 왕 큰 심장
   RC_SPIDERHOUSEMON = 116;  //폭안거미
   RC_EXPLOSIONSPIDER = 117; //폭주
   RC_HIGHRISKSPIDER      = 118;    //거대 거미
   RC_BIGPOISIONSPIDER = 119;  //거대 독거미
   RC_SOCCERBALL     = 120;   //축구공
   RC_BAMTREE        = 121;

   RC_SCULKING_2     = 122;  //짝퉁 주마왕
   RC_BLACKSNAKEKING = 123;  //흑사왕
   RC_NOBLEPIGKING   = 124;   //귀돈왕
   RC_FEATHERKINGOFKING = 125; //흑천마왕
   // 2003/02/11 추가 몹
   RC_SKELETONKING      = 126; //해골반왕
   RC_TOXICGHOST        = 127; //부식귀
   RC_SKELETONSOLDIER   = 128; //해골병졸
   // 2003/03/04 추가 몹
   RC_BANYAGUARD        = 129; //반야좌사/반야우사
   RC_DEADCOWKING       = 130; //사우천왕
   // 2003/07/15 추가 몹
   RC_PBOMA1         = 131; //날개오마
   RC_PBOMA2         = 132; //쇠뭉치상급오마
   RC_PBOMA3         = 133; //몽둥이상급오마
   RC_PBOMA4         = 134; //칼하급오마
   RC_PBOMA5         = 135; //도끼하급오마
   RC_PBOMA6         = 136; //활하급오마
   RC_PBGUARD        = 137; //과거비천 창경비
   RC_PBMSTONE1      = 138; //마계석1
   RC_PBMSTONE2      = 139; //마계석2
   RC_PBKING         = 140; //오마파천황(파황마신)
   RC_MINE           = 141; //지뢰

   RC_ANGEL          = 142; //월령(천녀)
   RC_CLONE          = 143; //분신
   RC_FIREDRAGON     = 144; //파천마룡 (화룡)
   RC_DRAGONBODY     = 145; //화룡몸
   RC_DRAGONSTATUE   = 146; //용석상

   RC_EYE_PROG       = 147; //설인대충
   RC_STON_SPIDER    = 148; //신석독마주
   RC_GHOST_TIGER    = 149; //환영한호
   RC_JUMA_THUNDER   = 150; //주마격뢰장

   RC_GOLDENIMUGI    = 151; //황금이무기

   RC_MONSTERBOX     = 152; //몬스터박스
   RC_STICKBLOCK     = 153; //호혼석
   RC_FOXWARRIOR     = 154; //비월여우(전사) 비월흑호
   RC_FOXWIZARD      = 155; //비월여우(술사) 비월적호
   RC_FOXTAOIST      = 156; //비월여우(도사) 비월소호
   RC_PUSHEDMON      = 157; //호기연
   RC_PUSHEDMON2     = 158; //호기옥
   RC_FOXPILLAR      = 159; //호혼기석
   RC_FOXBEAD        = 160; //비월천주
   RC_ARCHERMASTER   = 161;  //궁수호위병(2005/08)
   //2005/12/14
   RC_NEARTURTLE     = 162; //근거리 거북
   RC_FARTURTLE      = 163; //원거리 거북
   RC_BOSSTURTLE     = 164; //보스 거북(현무)
   //2005/11/01
   RC_SUPEROMA       = 181; //수퍼오마
   RC_TOGETHEROMA    = 182; //뭉치면 강해지는 오마

   RC_CLONEMON       = 183; //분신몬스터


   //클라이언트 종족...
   RCC_HUMAN      = 0;
   RCC_GUARD      = 12;
   RCC_GUARD2     = 24;
   RCC_MERCHANT   = 50;
   RCC_FIREDRAGON   = 83; // 파천마룡 (화룡)

   LA_CREATURE    = 0;
   LA_UNDEAD      = 1;

   
   MP_CANMOVE		= 0;
   MP_WALL			= 1;
   MP_HIGHWALL    = 2;
   
   DR_UP          = 0;
   DR_UPRIGHT     = 1;
   DR_RIGHT       = 2;
   DR_DOWNRIGHT   = 3;
   DR_DOWN        = 4;
   DR_DOWNLEFT    = 5;
   DR_LEFT        = 6;
   DR_UPLEFT      = 7;

   U_DRESS        = 0;
   U_WEAPON       = 1;
   U_RIGHTHAND    = 2;
   U_NECKLACE     = 3;
   U_HELMET       = 4;
   U_ARMRINGL     = 5;
   U_ARMRINGR     = 6;
   U_RINGL        = 7;
   U_RINGR        = 8;
   // 2003/03/15 아이템 인벤토리 확장
   U_BUJUK        = 9;
   U_BELT         = 10;
   U_BOOTS        = 11;
   U_CHARM        = 12;

   UD_USER        = 0;
   UD_USER2       = 1;
   UD_OBSERVER    = 2;   // '2' 등급
   UD_ASSISTANT   = 4;   // 'A' 등급(observer등급과 sysop등급 사이에 추가)
   UD_SYSOP       = 6;   // '1' 등급
   UD_ADMIN       = 8;   // '*' 등급
   UD_SUPERADMIN  = 10;  // '*' 등급(테스트 서버 또는 패스워드 성공 후)

   ET_DIGOUTZOMBI    = 1;  //좀비가 땅파고 나온 흔적
   ET_MINE           = 2;  //광석이 매장되어 있음
   ET_PILESTONES     = 3;  //돌무더기
   ET_HOLYCURTAIN    = 4;  //결계
   ET_FIRE           = 5;
   ET_SCULPEICE      = 6;  //주마왕의 돌깨진 조각
   ET_HEARTPALP      = 7;  //혈거인 왕(심장)방의 촉수 공격
   ET_MINE2          = 8;  //보석이 매장되어 있음
   ET_JUMAPEICE      = 9;  //주마격뢰장 꺠진 조각
   ET_MINE3          = 10;  //이벤트용 광석 및 보석이 매장되어 있음(2004/11/03)

   NE_HEARTPALP      = 1;  //기본 효과 시리즈, 1번 촉수공격
   NE_CLONESHOW      = 2;  //분신나타남
   NE_CLONEHIDE      = 3;  //분신사라짐
   NE_THUNDER        = 4;  //용던젼 번개
   NE_FIRE           = 5;  //용던젼 용암
   NE_DRAGONFIRE     = 6;  //용불공격 터짐
   NE_FIREBURN       = 7;  //용석상공격 터짐 타오름
   NE_FIRECIRCLE     = 8;  //화룡기염
   //2004/06/22 신규무공 이펙트.
   NE_MONCAPTURE     = 9;  //포승검-포획 이펙트
   NE_BLOODSUCK      = 10; //흡혈술-흡입 이펙트
   NE_BLINDEFFECT    = 11; //맹안술 이펙트
   NE_FLOWERSEFFECT  = 12; //꽃잎 이펙트
   NE_LEVELUP        = 13; //레벨업 이펙트
   NE_RELIVE         = 14; //부활 이펙트
   NE_POISONFOG      = 15; //이무기 독안개 임펙트
   NE_SN_MOVEHIDE    = 16; //이무기 워프 사라지는임펙트
   NE_SN_MOVESHOW    = 17; //이무기 워프 나타나는임펙트
   NE_SN_RELIVE      = 18; //이무기 부활 임펙트
   NE_BIGFORCE       = 19; //무극진기 임펙트
   NE_JW_EFFECT1     = 20; //장원 이펙트
   NE_FOX_MOVEHIDE   = 21; //술사비월여우 순간이동 임펙트
   NE_FOX_FIRE       = 22; //술사비월여우 화염 루프 임펙트
   NE_FOX_MOVESHOW   = 23; //술사비월여우 나타나는 임펙트
   NE_SOULSTONE_HIT  = 24; //호혼석 공격 임펙트
   NE_KINGSTONE_RECALL_1  = 25; //비월천주 소환 비월천주에게 뿌려줌
   NE_KINGSTONE_RECALL_2  = 26; //비월천주 소환 캐릭에게 뿌려줌
   NE_SIDESTONE_PULL = 27; //호혼기석 당기기
   NE_HAPPYBIRTHDAY  = 28; //프리미엄 생일 임펙트
   NE_KINGTURTLE_MOBSHOW  = 29; //현무현신 소환몹 나타나는임펙트
   NE_USERHEALING    = 30; //초보자지역 NPC힐 이펙트
   NE_DEFENCEEFFECT  = 31; //영정갑주 반사 이펙트
   NE_KOREAFIGHTING  = 32; //월드컵응원

   SWD_LONGHIT       = 12; //어검술
   SWD_WIDEHIT       = 25; //반월검법
   SWD_FIREHIT       = 26; //염화결
   SWD_RUSHRUSH      = 27; //무태보
   // 2003/03/15 신규무공
   SWD_CROSSHIT      = 34; //광풍참
   SWD_TWINHIT       = 38; //쌍룡참
   SWD_STONEHIT      = 43; //사자후

   //퀘스트 관련
   //IF
   QI_CHECK          = 1;  //101이상
   QI_RANDOM         = 2;
   QI_GENDER         = 3;  //MAN or WOMAN
   QI_DAYTIME        = 4;  //SUNRAISE DAY SUNSET NIGHT
   QI_CHECKOPENUNIT  = 5;  //유닛체크
   QI_CHECKUNIT      = 6;  //유닛체크
   QI_CHECKLEVEL     = 7;
   QI_CHECKJOB       = 8;  //Warrior, Wizard, Taoist
   QI_CHECKITEM      = 20;
   QI_CHECKITEMW     = 21;
   QI_CHECKGOLD      = 22;
   QI_ISTAKEITEM     = 23;  //방금전에 받은 아이템이 무엇인지 검사
   QI_CHECKDURA      = 24;  //아이템의 아이템의 평균 내구(dura / 1000) 검사
                            //여러개 있는 경우 최고 내구를 검사
   QI_CHECKDURAEVA   = 25;
   QI_DAYOFWEEK      = 26;  //요일 검사
   QI_TIMEHOUR       = 27;  //시간단위 검사(0..23)
   QI_TIMEMIN        = 28;  //분 검사
   QI_CHECKPKPOINT   = 29;
   QI_CHECKLUCKYPOINT = 30;
   QI_CHECKMON_MAP   = 31;  //현재 맵에 몹이 있는지
   QI_CHECKMON_AREA  = 32;  //특정 지역에 몹이 있는지
   QI_CHECKHUM       = 33;
   QI_CHECKBAGGAGE   = 34;  //사용자에게 줄 수 있는지?
   //6-11
   QI_CHECKNAMELIST  = 35;
   QI_CHECKANDDELETENAMELIST  = 36;
   QI_CHECKANDDELETEIDLIST    = 37;
   //*dq
   QI_IFGETDAILYQUEST = 40;  //오늘 퀘스트를 받았는지 검사, 유효기간 검사 포함
   QI_CHECKDAILYQUEST = 41;  //특정 번호의 퀘스트를 수행중인지 검사, 유효기간 검사 포함
   QI_RANDOMEX        = 42;  //파라메타  5 100   5%임...

   QI_CHECKMON_NORECALLMOB_MAP = 43;   //현재 맵에 있는 몹 수(소환몹 제외)
   QI_CHECKBAGREMAIN  = 44;  //유저 가방의 공간이 N개 남아 있는지

   QI_CHECKGRADEITEM  = 50;

   QI_EQUALVAR        = 51;   //EQUALV D1 P1  //D1이 P1과 같은지

   QI_EQUAL          = 135;  //EQUAL P1 10   //P1이 10인지
   QI_LARGE          = 136;  //LARGE P1 10   //P1이 10보다 큰지
   QI_SMALL          = 137;  //SMALL P1 10   //P1이 10보다 작은지 검사

   QI_ISGROUPOWNER   = 138;  //그룹 소유주인지 아닌지 검사
   QI_ISEXPUSER      = 139;  //체험판 사용자인지 검사
   QI_CHECKLOVERFLAG = 140;  //연인의 플래그가 TRUE인지 검사(연인정보를 찾을 수 없으면 FALSE 리턴)
   QI_CHECKLOVERRANGE = 141;  //연인이 일정 범위 안에 있는지
   QI_CHECKLOVERDAY  = 142;  //연인과의 교제일이 일정일 이상 되는지
   //명성치
   QI_CHECKFAMEGRADE = 143;  //명성 등급이 N 이상 되는지 체크
   QI_CHECKFAMEPOINT = 144;  //명성 FameCur 포인트가 N 이상 되는지 체크
   QI_CHECKFAMEBASEPOINT = 145;  //명성 FameBase 포인트가 N 이상 되는지 체크
   //장원기부금
   QI_CHECKDONATION      = 146;    // 현재 기부금 잔액 체크
   QI_ISGUILDMASTER      = 147;    // Guildmaster인지 체크
   QI_CHECKWEAPONBADLUCK = 148;     //무기의 저주 체크
   QI_CHECKPREMIUMGRADE  = 149;    // 프리미엄 등급 체크
   QI_CHECKCHILDMOB      = 150;    // 소환중인 몬스터 이름으로 체크(CHECKRECALLMOB)

   QI_CHECKGROUPJOBBALANCE = 151;    // 그룹에 전사, 술사, 도사 수가 같은지 체크
   QI_CHECKRANGEONELOVER   = 152;    // 범위내에 연인인 사람이 있는지 체크

   QI_EVENTCHECK     = 153; // ComeBack2005 이벤트 체크
   QI_CHECKITEMWVALUE    = 154; //착용중인 고통 아이템 기수치 체크

   //Action

   QA_SET            = 1;   //101이상
   QA_TAKE           = 2;   //아이템을 받다
   QA_GIVE           = 3;
   QA_TAKEW          = 4;   //착용하고 있는 아이템을 받다
   QA_CLOSE          = 5;   //대화창을 닫음
   QA_RESET          = 6;   //
   QA_OPENUNIT       = 7;
   QA_SETUNIT        = 8;  //유닛셋  1..100
   QA_RESETUNIT      = 9;  //유닛리셋   1..100
   QA_BREAK          = 10;
   QA_TIMERECALL     = 11;  // 지정된 시간이 지나면 현재 장소로 소환 된다.
   QA_PARAM1         = 12;
   QA_PARAM2         = 13;
   QA_PARAM3         = 14;
   QA_PARAM4         = 15;
   QA_MAPMOVE        = 20;
   QA_MAPRANDOM      = 21;
   QA_TAKECHECKITEM  = 22;  //CHECK항목에서 검사된 아이템을 받는다.
   QA_MONGEN         = 23;  //몬스터를 젠시킴
   QA_MONCLEAR       = 24;  //몬스터를 모두 제거 시킨다
   QA_MOV            = 25;
   QA_INC            = 26;
   QA_DEC            = 27;
   QA_SUM            = 28; //SUM P1 P2 //P9 = P1 + P2
   QA_BREAKTIMERECALL = 29;
   QA_TIMERECALLGROUP = 30;  // 지정된 시간이 지나면 그룹 전체가 현재 장소로 소환 된다.
   QA_CLOSENOINVEN    = 31;   //대화창을 닫음(인벤창은 건드리지 않음)

   QA_MOVRANDOM      = 50;  //MOVR
   QA_EXCHANGEMAP    = 51;  //EXCHANGEMAP R001  //R001에 있는 한 사람과 자리를 바꾼다.
   QA_RECALLMAP      = 52;  //RECALLMAP R001  //R001에 있는 사람들을 모두 소환 한다.
   QA_ADDBATCH       = 53;
   QA_BATCHDELAY     = 54;
   QA_BATCHMOVE      = 55;
   QA_PLAYDICE       = 56;  //PLAYDICE 2 @diceresult //2개의 주사위를 굴린다. 그후 @diceresult 세션으로 간다
   //6-11
   QA_ADDNAMELIST     = 57;
   QA_DELETENAMELIST  = 58;
   QA_PLAYROCK       = 59;  //PLAYDICE 2 @diceresult //2개의 주사위를 굴린다. 그후 @diceresult 세션으로 간다
   //*dq
   QA_RANDOMSETDAILYQUEST = 60;  //파라메터,  최소, 최대  예) 401 450  401에서 450번까지 랜덤으로 설정
   QA_SETDAILYQUEST  = 61;

   QA_GIVEEXP        = 63; // 경험치 주기(이벤트 종료후 기능 삭제)

   QA_TAKEGRADEITEM  = 70;

   QA_GOTOQUEST      = 100;
   QA_ENDQUEST       = 101;
   QA_GOTO           = 102;
   QA_SOUND          = 103;
   QA_CHANGEGENDER   = 104;
   QA_KICK           = 105;
   QA_MOVEALLMAP     = 106;    // 현재 맵 유저들을 모두 특정 맵으로 이동시킴.
   QA_MOVEALLMAPGROUP = 107;    // 그룹 멤버들 중에 현재 맵에 있는 멤버들만 특정 맵으로 이동시킴.
   QA_RECALLMAPGROUP = 108;    // 그룹 멤버들 중에 특정 맵에 있는 멤버들만 현재 맵으로 이동시킴.
   QA_WEAPONUPGRADE  = 109;    // 들고 있는 무기에 옵션을 붙인다.
   QA_SETALLINMAP    = 110;    // 현재 맵에 있는 모든 유저들의 플래그를 SET한다.
   QA_INCPKPOINT     = 111;    // PK Point를 증가시킨다.
   QA_DECPKPOINT     = 112;    // PK Point를 감소시킨다.
   //연인
   QA_MOVETOLOVER    = 113;    // 연인앞으로 이동한다.
   QA_BREAKLOVER     = 114;    // 연인관계를 일방적으로 해제시킨다.
   QA_SOUNDALL       = 115;    // 주변사람에게 사운드를 들려줌
   //명성치
   QA_USEFAMEPOINT   = 116;    // 자신의 명성치 사용
   QA_DECWEAPONBADLUCK = 117;    // 저주가 붙은 무기의 저주를 1 감소 시킨다.
   //장원기부금
   QA_DECDONATION    = 118;    // 기부금 잔액을 감소 시킨다.
   QA_SHOWEFFECT     = 119;    // 장원이펙트를 보여준다.
   QA_MONGENAROUND   = 120;    // 캐릭의 주위에 몬스터를 젠 시킨다.
   QA_RECALLMOB      = 121;    // 부하 몬스터 소환

   QA_SETLOVERFLAG   = 122;    //연인의 플래그를 SET한다.
   QA_GUILDSECESSION = 123;    //문파탈퇴
   QA_GIVETOLOVER    = 124;    //연인에게 아이템 주기
   QA_INCMEMORIALCOUNT  = 125;    //NPC별 카운트 증가
   QA_DECMEMORIALCOUNT  = 126;    //NPC별 카운트 감소
   QA_SAVEMEMORIALCOUNT = 127;    //NPC별 카운트 파일 저장

   QA_INSTANTPOWERUP   = 128; //순간 능력치 상승
   QA_INSTANTEXPDOUBLE = 129; //순간 경험치 2배
   QA_HEALING          = 130; //힐링
   QA_UNIFYITEM        = 131; //아이템을 합친다

   QA_MISSION          = 132; //미션 설정
   QA_MOBPLACE         = 133; //미션몹 배치

   VERSION_NUMBER = 20050501;
   VERSION_NUMBER_20030805 = 20030805;
   VERSION_NUMBER_20030715 = 20030715;
   VERSION_NUMBER_20030527 =20030527;
   VERSION_NUMBER_20030403 = 20030403;
   VERSION_NUMBER_030328 = 20030328;
   VERSION_NUMBER_030317 = 20030317;
   VERSION_NUMBER_030211 = 20030211;
   VERSION_NUMBER_030122 = 20030122;
   VERSION_NUMBER_020819 = 20020819;
   VERSION_NUMBER_0522 = 20020522;
   VERSION_NUMBER_02_0403 = 20020403;
   VERSION_NUMBER_01_1006 = 20011006;
   VERSION_NUMBER_0925 = 20010925;
   VERSION_NUMBER_0704 = 20010704;
   //VERSION_NUMBER_0522 = 20010522;
   VERSION_NUMBER_0419 = 20010419;
   VERSION_NUMBER_0407 = 20010407;
   VERSION_NUMBER_0305 = 20010305;
   VERSION_NUMBER_0216 = 20010216;
   BUFFERSIZE = 10000;

    // 아이템의 변화값 정의
    EFFTYPE_TWOHAND_WEHIGHT_ADD  = 1;
    EFFTYPE_EQUIP_WHEIGHT_ADD    = 2;
    EFFTYPE_LUCK_ADD             = 3;
    EFFTYPE_BAG_WHIGHT_ADD       = 4;
    EFFTYPE_HP_MP_ADD            = 5;
    EFFTYPE2_EVENT_GRADE         = 6;

    // Comand Result Defines... PDS:2003-03-31 ---------------------------------
    CR_SUCCESS          = 0;       // 성공
    CR_FAIL             = 1;       // 실패
    CR_DONTFINDUSER     = 2;       // 유저를 찾을 수 없음
    CR_DONTADD          = 3;       // 추가할 수 없음
    CR_DONTDELETE       = 4;       // 삭제할 수 없음
    CR_DONTUPDATE       = 5;       // 변경할 수 없음
    CR_DONTACCESS       = 6;       // 실행 불가능
    CR_LISTISMAX        = 7;       // 리스트의 최대치이므로 불가능
    CR_LISTISMIN        = 8;       // 리스트의 최소치이므로 불가능
    CR_DBWAIT           = 9;       // DB에서 기다리고 있는중 

    // 접속상태  PDS:2003-03-31 ------------------------------------------------
    CONNSTATE_UNKNOWN    = 0;       // 알수 없음
    CONNSTATE_DISCONNECT = 1;       // 비접속 상태
    CONNSTATE_NOUSE1     = 2;       // 사용안함
    CONNSTATE_NOUSE2     = 3;       // 사용안함
    CONNSTATE_CONNECT_0  = 4;       // 0번서버에 접속함
    CONNSTATE_CONNECT_1  = 5;       // 1번서버에 접속함
    CONNSTATE_CONNECT_2  = 6;       // 2번서버에 접속함
    CONNSTATE_CONNECT_3  = 7;       // 3번서버에 접속함 : 예비로만듬

    // 관계분류  2003/04/15 친구, 쪽지
    RT_FRIENDS          = 1;       // 친구
    RT_LOVERS           = 2;       // 연인
    RT_MASTER           = 3;       // 사부
    RT_DISCIPLE         = 4;       // 제자
    RT_BLACKLIST        = 8;       // 악연

    // 쪽지상태  PDS:2003-03-31 ------------------------------------------------
    TAGSTATE_NOTREAD     = 0;       // 읽지않음
    TAGSTATE_READ        = 1;       // 읽음
    TAGSTATE_DONTDELETE  = 2;       // 삭제금지
    TAGSTATE_DELETED     = 3;       // 삭제됨

    // 쪽지상태 변경에서 쓰임
    TAGSTATE_WANTDELETABLE = 3;     // 삭제가능하게 변경

// Relationship Request Sequences...
    RsReq_None             = 0;        // 기본상태
    RsReq_WantToJoinOther  = 1;        // 누구에게 참가신청을 함
    RsReq_WaitAnser        = 2;        // 응답을 기다림
    RsReq_WhoWantJoin      = 3;        // 누군가 참가를 원함
    RsReq_AloowJoin        = 4;        // 참가를 허락함
    RsReq_DenyJoin         = 5;        // 참가를 거절함
    RsReq_Cancel           = 6;        // 취소

    RaReq_CancelTime       = 30 * 1000; // 자동 취소 시간 30초 msec
    MAX_WAITTIME           = 60 * 1000; // 최대 기다리는 시간
// Relationship State Define...
    RsState_None           = 0;         // 기본상태
    RsState_Lover          = 10;        // 연인
    RsState_LoverEnd       = 11;        // 연인탈퇴
    RsState_Married        = 20;        // 결혼
    RsState_MarriedEnd     = 21;        // 결혼탈퇴
    RsState_Master         = 30;        // 사부
    RsState_MasterEnd      = 31;        // 사부탈퇴
    RsState_Pupil          = 40;        // 제자
    RsState_PupilEnd       = 41;        // 제자탈퇴
    RsState_TempPupil      = 50;        // 임시제자
    RsState_TempPupilEnd   = 51;        // 임시제자탈퇴

// RelationShip Error Code...
    RsError_SuccessJoin    = 1;         // 참가에 성공하였다 ( 참가한사람쪽)
    RsError_SuccessJoined  = 2;         // 참가에 성공되어졌다 ( 참가된 사람쪽)
    RsError_DontJoin       = 3;         // 참가할수 없다
    RsError_DontLeave      = 4;         // 떠날수 없다.
    RsError_RejectMe       = 5;         // 거부상태이다
    RsError_RejectOther    = 6;         // 거부상태이다
    RsError_LessLevelMe    = 7;         // 나의레벨이 낮다
    RsError_LessLevelOther = 8;         // 상대방의레벨이 낮다
    RsError_EqualSex       = 9;         // 성별이 같다
    RsError_FullUser       = 10;        // 참여인원이 가득찼다
    RsError_CancelJoin     = 11;        // 참가취소
    RsError_DenyJoin       = 12;        // 참가를 거절함
    RsError_DontDelete     = 13;        // 탈퇴시킬수 없다.
    RsError_SuccessDelete  = 14;        // 탈퇴시켰음
    RsError_NotRelationShip= 15;        // 교제상태가 아니다.

    // 겹치기
    MAX_OVERLAPITEM = 1000;

    // 위탁상점 판매종류
    // 개별아이템류
    USERMARKET_TYPE_ALL     = 0   ;     // 모두
    USERMARKET_TYPE_WEAPON  = 1   ;     // 무기
    USERMARKET_TYPE_NECKLACE= 2   ;     // 목걸이
    USERMARKET_TYPE_RING    = 3   ;     // 반지
    USERMARKET_TYPE_BRACELET= 4   ;     // 팔찌,장갑
    USERMARKET_TYPE_CHARM   = 5   ;     // 수호석
    USERMARKET_TYPE_HELMET  = 6   ;     // 투구
    USERMARKET_TYPE_BELT    = 7   ;     // 허리띠
    USERMARKET_TYPE_SHOES   = 8   ;     // 신발
    USERMARKET_TYPE_ARMOR   = 9   ;     // 갑옷
    USERMARKET_TYPE_DRINK   = 10  ;     // 시약
    USERMARKET_TYPE_JEWEL   = 11  ;     // 보옥,신주
    USERMARKET_TYPE_BOOK    = 12  ;     // 책
    USERMARKET_TYPE_MINERAL = 13  ;     // 광석
    USERMARKET_TYPE_QUEST   = 14  ;     // 퀘스트아이템
    USERMARKET_TYPE_ETC     = 15  ;     // 기타
    USERMARKET_TYPE_ITEMNAME= 16  ;     // 아이템이름
    // 셋트류
    USERMARKET_TYPE_SET     = 100 ;     // 셋트 아이템
    // 유저류
    USERMARKET_TYPE_MINE    = 200 ;     // 자신이판물건
    USERMARKET_TYPE_OTHER   = 300 ;     // 다른사람이 판물건

    USERMARKET_MODE_NULL    = 0   ;     // 초기값
    USERMARKET_MODE_BUY     = 1   ;     // 사는모드
    USERMARKET_MODE_INQUIRY = 2   ;     // 조회모드
    USERMARKET_MODE_SELL    = 3   ;     // 판매모드


    MARKET_CHECKTYPE_SELLOK     = 1;    //위탁 정상
    MARKET_CHECKTYPE_SELLFAIL   = 2;    //위탁 실패
    MARKET_CHECKTYPE_BUYOK      = 3;    //구입 정상
    MARKET_CHECKTYPE_BUYFAIL    = 4;    //구입 실패
    MARKET_CHECKTYPE_CANCELOK   = 5;    //취소 정상
    MARKET_CHECKTYPE_CANCELFAIL = 6;    //취소 실패
    MARKET_CHECKTYPE_GETPAYOK   = 7;    //돈 회수 정상
    MARKET_CHECKTYPE_GETPAYFAIL = 8;    //돈 회수 실패

    MARKET_DBSELLTYPE_SELL          = 1;//판매중
    MARKET_DBSELLTYPE_BUY           = 2;//샀음
    MARKET_DBSELLTYPE_CANCEL        = 3;//취소
    MARKET_DBSELLTYPE_GETPAY        = 4;//금액회수
    MARKET_DBSELLTYPE_READYSELL     = 11;//임시 판매중
    MARKET_DBSELLTYPE_READYBUY      = 12;//임시 사는중
    MARKET_DBSELLTYPE_READYCANCEL   = 13;//임시 취소중
    MARKET_DBSELLTYPE_READYGETPAY   = 14;//임시 회수중
    MARKET_DBSELLTYPE_DELETE        = 20;//삭제

    // 위탁상점 리턴값
    UMResult_Success         = 0   ;     // 성공
    UMResult_Fail            = 1   ;     // 실패
    UMResult_ReadFail        = 2   ;     // 읽기 실패
    UMResult_WriteFail       = 3   ;     // 저장 실패
    UMResult_ReadyToSell     = 4   ;     // 판매가능
    UMResult_OverSellCount   = 5   ;     // 판매 아이템 개수 초과
    UMResult_LessMoney       = 6   ;     // 금전부족
    UMResult_LessLevel       = 7   ;     // 레벨부족
    UMResult_MaxBagItemCount = 8   ;     // 가방에 아이템꽉참
    UMResult_NoItem          = 9   ;     // 아이템이 없음
    UMResult_DontSell        = 10  ;     // 판매불가
    UMResult_DontBuy         = 11  ;     // 구입불가
    UMResult_DontGetMoney    = 12  ;     // 금액회수 불가
    UMResult_MarketNotReady  = 13  ;     // 위탁시스템 자체가 불가능
    UMResult_LessTrustMoney  = 14  ;     // 위탁금액이 부족 1000 전 보다는 커야됨
    UMResult_MaxTrustMoney   = 15  ;     // 위탁금액이 너무 큼
    UMResult_CancelFail      = 16  ;     // 위탁취소 실패
    UMResult_OverMoney       = 17  ;     // 소유금액 최대치가 넘어감
    UMResult_SellOK          = 18  ;     // 판매가 잘됬음
    UMResult_BuyOK           = 19  ;     // 구입이 잘됬음
    UMResult_CancelOK        = 20  ;     // 판매취소가 잘됬음
    UMResult_GetPayOK        = 21  ;     // 판매금 회수가 잘됬음

    // 가격최대치
    MAX_MARKETPRICE = 50000000;  //5000만전


function  RACEfeature (feature: Longint): byte;
function  DRESSfeature (feature: Longint): byte;
function  WEAPONfeature (feature: Longint): byte;
function  HAIRfeature (feature: Longint): byte;
function  APPRfeature (feature: Longint): word;
function  MakeFeature (race, dress, weapon, face: byte): Longint;
function  MakeFeatureAp (race, state: byte; appear: word): Longint;
function  MakeDefaultMsg (msg: word; soul: integer; wparam, atag, nseries: word; hid: integer = 200): TDefaultMessage;
function  UpInt (r: Real): integer;


implementation


function RACEfeature (feature: Longint): byte;
begin
	Result := LOBYTE (LOWORD (feature));
end;

function WEAPONfeature (feature: Longint): byte;
begin
	Result := HIBYTE (LOWORD (feature));
end;

function HAIRfeature (feature: Longint): byte;
begin
	Result := LOBYTE (HIWORD (feature));
end;

function DRESSfeature (feature: Longint): byte;
begin
	Result := HIBYTE (HIWORD (feature));
end;

function APPRfeature (feature: Longint): word;
begin
	Result := HIWORD (feature);
end;

function MakeFeature (race, dress, weapon, face: byte): Longint;
begin
	Result := MakeLong (MakeWord (race, weapon), MakeWord (face, dress));
end;

function MakeFeatureAp (race, state: byte; appear: word): Longint;
begin
	Result := MakeLong (MakeWord (race, state), appear);
end;

function  MakeDefaultMsg (msg: word; soul: integer; wparam, atag, nseries: word; hid: integer = 200): TDefaultMessage;
begin
   with Result do begin
      Ident := msg;
      Recog := soul;
      param := wparam;
      Tag	:= atag;
      Series := nseries;
      Etc := ((HIWORD(hid) and $A3) or $58) xor $8A;
      Etc2 := ((LOWORD(hid) and $EC) or $28) xor $A9;
   end;
end;

function UpInt (r: Real): integer;
begin
   if r > int(r) then Result := Trunc(r)+1 else Result := Trunc(r);
end;


end.



