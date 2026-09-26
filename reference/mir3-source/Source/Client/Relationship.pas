unit Relationship;

interface

uses
    Classes, SysUtils ,grobal2,Windows ;

const
    MAX_LOVERCOUNT      = 1;
    STR_LOVER           = '연      인 : ';
    STR_LOVER_STARTDAY  = '교제시작일 : ';
    STR_LOVER_DAYCOUNT  = '교제총기간 : ';
type

    TRelationShipInfo  = class
    private
        FOwnner      : String;   // 소유자 이름
        FName        : String;   // 등록자 이름
        FState       : BYTE;     // 등록상태
        FLevel       : BYTE;     // 레벨
        FSex         : BYTE;     // 성별
        FDate        : String;   // 등록날짜
        FServerDate  : String;   // 서버날짜
        FMapInfo     : String;   // 맵정보

    public
        constructor Create;
        destructor  Destroy; override;

        // 내부 멤버접근용 프로퍼티
        property  Ownner    : String  read FOwnner      Write FOwnner;
        property  Name      : String  read FName        Write FName;
        property  State     : BYTE    read FState       Write FState;
        property  Level     : BYTE    read FLevel       Write FLevel;
        property  Sex       : BYTE    read FSex         Write FSex;
        property  Date      : String  read FDate        Write FDate;
        property  ServerDate: String  read FServerDate  Write FServerDate;
        property  MapInfo   : String  read FMapInfo     Write FMapInfo;

    end;
    PTRelationShipInfo = ^TRelationShipInfo;


    TRelationShipMgr = class
    private
        FItems          : TList;
        FEnableJoinLover: Boolean;
        FReqSequence    : Integer;
        FCancelTime     : LongWord;
        FLoverCount     : Integer;
        fDisplayStr     : TStringList;

        procedure RemoveAll;

        function    GetReqSequence : Integer;
        procedure   SetReqSequence ( Sequence : integer );
        function    GetDayStr( datestr: string;delimeter:String):string;
        function    GetDayNow( datestr: string; serverdatestr :string):string;
    public
        constructor Create;
        destructor  Destroy; override;

        procedure   Clear;
        // 찾기
        function GetInfo   ( Name_ : String ; var Info_ : TRelationShipInfo ):Boolean;
        function Find      ( Name_ : String ):Boolean;


        // 추가
        function Add    (   Ownner_     : String;
                            Other_      : String;
                            State_      : BYTE  ;
                            Level_      : BYTE  ;
                            Sex_        : BYTE  ;
                            Date_       : String;
                            ServerDate_ : String;
                            MapInfo_    : String
                         ): Boolean;
        // 삭제
        function Delete ( Name_    : String ):Boolean;
        // 레벨변경
        function ChangeLevel ( Name_ : String ; Level_ : BYTE ):Boolean;

        function GetEnableJoin    ( ReqType : integer ) : Boolean;
        function GetEnableJoinReq ( ReqType : integer ) : Boolean;
        procedure SetEnable       ( ReqType : integer ; Enable : integer);
        function GetEnable        ( ReqType : integer ) : Integer;
        function GetDisplay       ( Line : Integer ) : String;
        function GetName          ( ReqType : integer ):String;
        // 디스플레이 겡신
        procedure   MakeDisplay;

        // Request sequence 처리
        property  ReqSequence      : Integer  read GetReqSequence Write SetReqSequence;

    end;


implementation

// TRealtionShipInfo ===========================================================
constructor TRelationShipInfo.Create;
begin
    inherited ;
    //TO DO Initialize
    FOwnner      := '';
    FName        := '';
    FState       := 0;
    FLevel       := 0;
    FSex         := 0;
    FDate        := '';
    FServerDate  := '';
    FMapInfo     := '';
end;

destructor  TRelationShipInfo.Destroy;
begin
    // TO DO Free Mem

    inherited;
end;

// TRealtionShipMgr ============================================================
constructor TRelationShipMgr.Create;
begin
    inherited ;
    //TO DO Initialize
    FItems          := TList.Create;
    fDisplayStr     := TStringList.Create;
end;

destructor TRelationShipMgr.Destroy;
begin
    // TO DO Free Mem
    RemoveAll;
    FItems.Free;

    fDisplayStr.Free;
    inherited;
end;

procedure TRelationShipMgr.Clear;
begin
    RemoveAll;
    FEnableJoinLover:= False;
    FReqSequence    := rsReq_None;
    FCancelTime     := 0;
    FLoverCount     := 0;
    fDisplayStr.Clear;

    MakeDisplay;
end;

procedure TRelationShipMgr.RemoveAll;
var
    Info : TRelationShipInfo;
    i    : integer;
begin
    for i := 0 to FItems.count -1 do
    begin
        Info := FItems[i];

        if ( Info <> nil ) then
        begin
            Info.Free;
            Info := nil;
        end;
    end;

    FItems.Clear;
end;

function TrelationShipMgr.GetReqSequence : Integer;
begin
    if (FcancelTime = 0) or ((GetTickCount - FCancelTime) <= MAX_WAITTIME )then
    begin
       // 지정한 시간 내에 잘 응답 했음
       ;
    end
    else
    begin
        // 시간이 너무 오래 지났으므로 무효
         FReqSequence := RsReq_None ;
    end;

    Result := FReqSequence;
end;

procedure TrelationShipMgr.SetReqSequence ( Sequence : integer );
begin
    if ( FCancelTime = 0 ) or ( (GetTickCount - FCancelTime) <= MAX_WAITTIME) then
    begin
         FReqSequence := Sequence ;
    end
    else
    begin
        // 시간이 너무 오래 지났으므로 무효
         FReqSequence := RsReq_None ;
    end;
    FCancelTime := GetTickCount;
end;


function TrelationShipMgr.GetDayStr( datestr: string ;delimeter:String):string;
begin
    Result := '';
    if length(datestr) >= 6 then
    begin
        Result := '20'+datestr[1]+datestr[2]+delimeter+
                  datestr[3]+datestr[4]+delimeter+
                  datestr[5]+datestr[6];
    end;

end;

function TrelationShipMgr.GetDayNow( datestr: string ; serverdatestr :string):string;
var
    date        : TDateTime;
    serverdate  : TDateTime;
begin
    date        := StrToDate( GetDayStr( datestr        , '-') );
    serverdate  := StrToDate( GetDayStr( serverdatestr  , '-') );

    Result := IntTostr ( Trunc( serverdate - date )+1 );

end;


procedure TrelationShipMgr.MakeDisplay;
var
    Info    : TRelationShipInfo;
    i       : integer;
begin
    fDisplayStr.Clear;
    fDisplayStr.Add(STR_LOVER);
    fDisplayStr.Add(STR_LOVER_STARTDAY );
    fDisplayStr.Add(STR_LOVER_DAYCOUNT );

    for i := 0 to FItems.Count -1 do
    begin
        Info := Fitems[i];
        if Info <> nil then
        begin
            if Info.State = RsState_Lover then
            begin
                fDisplayStr[0] := STR_LOVER+Info.Name;
                fDisplayStr[1] := STR_LOVER_STARTDAY + GetDayStr( Info.Date,'/');
                fDisplayStr[2] := STR_LOVER_DAYCOUNT + GetDayNow( Info.Date , Info.ServerDate);
            end;
        end;
    end;

end;

// 참가 여부 결정
function  TrelationShipMgr.GetEnableJoin( ReqType : integer ) : Boolean;
begin
    Result := false;

    case ReqType of
    RsState_Lover : if fEnableJoinLover and ( fLoverCount < MAX_LOVERCOUNT ) then Result := true;
    end;

end;

// 참가 여부 결정
function  TrelationShipMgr.GetEnableJoinReq( ReqType : integer ) : Boolean;
begin
    Result := false;

    case ReqType of
    RsState_Lover : if fEnableJoinLover and ( fLoverCount < MAX_LOVERCOUNT ) then Result := true;
    end;

end;

procedure TrelationShipMgr.SetEnable( ReqType : integer ; enable : integer);
begin
    case ReqType of
    RsState_Lover :
        begin
            if enable = 1 then FEnableJoinLover := true
            else FEnableJoinLover := false;
        end;
    end;
end;


function TrelationShipMgr.GetEnable( ReqType : integer ) : Integer;
begin
    Result := 0;

    case ReqType of
    RsState_Lover :
        begin
            if FEnableJoinLover then Result := 1
            else Result := 0;
        end;
    end;
end;

function TrelationShipMgr.GetDisplay( Line : integer ) : String;
begin
    Result := '';
    if fDisplayStr.Count > Line then
    Result := fDisplayStr[Line];
end;

function TrelationShipMgr.GetName( ReqType : integer ):String;
var
    Info : TRelationShipInfo;
    i    : integer;
begin
    Result := '';
    for i := 0 to fItems.Count -1  do
    begin
        Info := FITems[i];
        if (Info <> nil) and  (Info.State = ReqType) then
        begin
            Result := Info.Name;
            Exit;
        end;
    end;
end;

// Get Infomation...
function TrelationShipMgr.GetInfo( Name_ : String ; var Info_ : TRelationShipInfo ):Boolean;
var
    i    : integer;
    Info : TrelationShipInfo;
begin
    result := False;
    Info_  := nil;

    for i := 0 to FItems.Count - 1 do
    begin
        Info :=  FItems[i];
        if (Info <> nil) and (Info.Name = Name_) then
        begin
            Info_ := Info;
            Result := true;
            Exit;
        end;
    end;
end;

function TRelationShipMgr.Find( Name_ : String ):Boolean;
var
    Info    : TRelationShipInfo;
begin
    Result := GetInfo( Name_  , Info );
end;

function TRelationShipMgr.Add(
    Ownner_     : String;
    Other_      : String;
    State_      : BYTE  ;
    Level_      : BYTE  ;
    Sex_        : BYTE  ;
    Date_       : String;
    ServerDate_ : String;
    MapInfo_    : String
): Boolean;
var
    Info : TRelationShipInfo;
begin
    Result  := false;

    // 데이터 체크
    if ( Ownner_ = '' ) or ( Other_ = '') or (Level_ = 0) then Exit;

    // 시간이 없다면 현재시간으로 넣어준다.
    if (Date_ = '') then
    begin
        Date_ := FormatDateTime('yymmddhhnn',Now );
    end;

    // 등록되어있지 않은 사람이라면 등록한다.
    Info    := nil;
    if not Find( Other_ ) then
    begin
        Info := TRelationShipInfo.Create;

        Info.Ownner     := Ownner_      ;
        Info.Name       := Other_       ;
        Info.State      := State_       ;
        Info.Level      := Level_       ;
        Info.Sex        := Sex_         ;
        Info.Date       := Date_        ;
        Info.ServerDate := ServerDate_  ;
        Info.Mapinfo    := MapInfo_     ;

        FItems.Add( Info );

        case State_ of
        RsState_Lover : inc ( fLoverCount );
        end;

        Result := true;
        MakeDisplay;

    end;
end;

function TRelationShipMgr.Delete ( Name_  : String ):Boolean;
var
    Info    : TRelationShipInfo;
    i       : integer;
begin
    Result := false;

    for i := 0 to FItems.Count -1 do
    begin
        Info := FItems[i];
        if (Info <> nil) and (Info.Name = Name_ )then
        begin
            Info.Free;
            Info:= Nil;
            FItems.Delete(i);
            result := true;
            MakeDisplay;
            Exit;
        end;
    end;

end;

function TRelationShipMgr.ChangeLevel( Name_ : String ; Level_ : BYTE ):Boolean;
var
    Info : TRelationShipInfo;
begin
    Result := false;
    // 레벨이 0 보다 크고
    if Level_ > 0 then
    begin
        // 정보를 얻어서
        if GetInfo ( Name_ , Info ) then
        begin
            // 레벨변경
            if Info <> nil then
            begin
                Info.Level := Level_;
                Result := true;
                MakeDisplay;
            end;
        end;

    end;

end;

end.
