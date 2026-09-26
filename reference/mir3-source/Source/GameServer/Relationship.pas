unit Relationship;

interface

uses
    Classes, SysUtils ,grobal2,Windows;

const
    MAX_LOVERCOUNT  = 1;
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

        //현재날짜를 포멧에 맞게 변화시킨다.
        function GetNowDate : String;

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
        procedure RemoveAll;

        function    GetReqSequence : Integer;
        procedure   SetReqSequence ( Sequence : integer );
        function    GetDayStr( datestr, delimeter : string): string;
        function    GetDayNow( datestr, serverdatestr : string): string;
    public
        constructor Create;
        destructor  Destroy; override;


        // 찾기
        function GetInfo   ( Name_ : String ; var Info_ : TRelationShipInfo ):Boolean;
        function Find      ( Name_ : String ):Boolean;

        // 추가
        function Add    (   Ownner_     : String;
                            Other_      : String;
                            State_      : BYTE  ;
                            Level_      : BYTE  ;
                            Sex_        : BYTE  ;
                            var Date_   : String;
                            MapInfo_    : String
                         ): Boolean;
        // 삭제
        function Delete ( Name_    : String ):Boolean;
        // 레벨변경
        function ChangeLevel ( Name_ : String ; Level_ : BYTE ):Boolean;

        function GetEnableJoin    ( ReqType : integer ) : integer;
        function GetEnableJoinReq ( ReqType : integer ) : Boolean;
        procedure SetEnable       ( ReqType : integer ; Enable : integer);
        function GetEnable        ( ReqType : integer ) : Integer;
        function GetListMsg       ( ReqType : integer ; var ListCount : integer) : String;

        // Request sequence 처리
        property  ReqSequence      : Integer  read GetReqSequence Write SetReqSequence;
        property  EnableJoinLover  : Boolean  read FEnableJoinLover;
        function GetLoverCount : integer;
        function GetLoverName : string;
        function GetLoverDays : string;
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
    FDate        := GetNowDate;
    FMapInfo     := '';
    FServerDate  := GetNowDate;
end;

destructor  TRelationShipInfo.Destroy;
begin
    // TO DO Free Mem

    inherited;
end;

// 현재날짜를 포멧에 맞게 변환시킨다.
function TRelationShipInfo.GetNowDate : String;
begin
    Result := FormatDateTime('yymmddhhnn',Now );
end;

// TRealtionShipMgr ============================================================
constructor TRelationShipMgr.Create;
begin
    inherited ;
    //TO DO Initialize
    FItems          := TList.Create;
    FEnableJoinLover:= False;
    FReqSequence    := rsReq_None;
    FCancelTime     := 0;
    FLoverCount     := 0;

end;

destructor TRelationShipMgr.Destroy;
begin
    // TO DO Free Mem
    RemoveAll;
    FItems.Free;

    inherited;
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

function TRelationShipMgr.GetReqSequence : Integer;
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

procedure TRelationShipMgr.SetReqSequence ( Sequence : integer );
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


function TRelationShipMgr.GetDayStr( datestr: string ;delimeter:String):string;
begin
    Result := '';
    if length(datestr) >= 6 then
    begin
        Result := '20'+datestr[1]+datestr[2]+delimeter+
                  datestr[3]+datestr[4]+delimeter+
                  datestr[5]+datestr[6];
    end;

end;

function TRelationShipMgr.GetDayNow( datestr: string ; serverdatestr :string):string;
var
    date        : TDateTime;
    serverdate  : TDateTime;
begin
    date        := StrToDate( GetDayStr( datestr        , '-') );
    serverdate  := StrToDate( GetDayStr( serverdatestr  , '-') );

    Result := IntTostr ( Trunc( serverdate - date ) + 1 );

end;


// 참가 여부 결정
function  TRelationShipMgr.GetEnableJoin( ReqType : integer ) : integer;
begin
   Result := 3;   //실패(기타)

   case ReqType of
   RsState_Lover :
      begin
         //실패(교제가능 상태가 아님)
         if not fEnableJoinLover then begin
            Result := 1;
            exit;
         end;
         if fLoverCount < MAX_LOVERCOUNT then begin
            //성공
            Result := 0;
            exit;
         end else begin
            //실패(이미 연인이 있음)
            Result := 2;
            exit;
         end;
      end;
   end;

end;

// 참가 여부 결정
function  TRelationShipMgr.GetEnableJoinReq( ReqType : integer ) : Boolean;
begin
    Result := false;

    case ReqType of
    RsState_Lover : if fEnableJoinLover and ( fLoverCount < MAX_LOVERCOUNT ) then Result := true;
    end;

end;

procedure TRelationShipMgr.SetEnable( ReqType : integer ; enable : integer);
begin
    case ReqType of
    RsState_Lover :
        begin
            if enable = 1 then FEnableJoinLover := true
            else FEnableJoinLover := false;
        end;
    end;
end;


function TRelationShipMgr.GetEnable( ReqType : integer ) : Integer;
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

function TRelationShipMgr.GetListMsg( ReqType : integer ; var ListCount : integer) : String;
var
    i       : integer;
    Info    : TRelationShipInfo;
    msg     : String;
begin
    ListCount := 0;
    msg := '';
    for i := 0 to FItems.Count -1 do
    begin
        Info := Fitems[i];

        if Info.FState = ReqType then
        begin
            // 등록상태:케릭터이름:레벨:성별:등록일자:서버일자:맵정보/
            msg := msg + IntToStr( Info.FState)+':'+ Info.Name + ':'+
                   IntToStr( Info.Level) +':'+ IntToStr(Info.Sex)+':'+
                   Info.Date + ':'+ Info.ServerDate+':'+Info.MapInfo + '/';
            Inc( ListCount );
        end;

    end;
    Result:= msg;
end;

// Get Infomation...
function TRelationShipMgr.GetInfo( Name_ : String ; var Info_ : TRelationShipInfo ):Boolean;
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
    var Date_   : String;
    MapInfo_    : String

): Boolean;
var
    Info : TRelationShipInfo;
begin
    Result  := false;

    // 데이터 체크
    if ( Ownner_ = '' ) or ( Other_ = '') or (Level_ = 0) then Exit;

    // 등록되어있지 않은 사람이라면 등록한다.
    Info    := nil;
    if not Find( Other_ ) then
    begin
        Info := TRelationShipInfo.Create;

        Info.Ownner := Ownner_  ;
        Info.Name   := Other_   ;
        Info.State  := State_   ;
        Info.Level  := Level_   ;
        Info.Sex    := Sex_     ;
        if Date_ <> '' then
            Info.Date   := Date_
        else
            Date_ := Info.Date;
        Info.MapInfo := MapInfo_;

        FItems.Add( Info );

        case State_ of
        RsState_Lover : inc ( fLoverCount );
        end;

        Result := true;
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
            // 스테이트에 맞는 사람을 삭제한다.
            case Info.State of
            RsState_Lover : dec ( fLoverCount );
            end;

            Info.Free;
            Info:= Nil;
            FItems.Delete(i);
            result := true;
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
   if Level_ > 0 then begin
      // 정보를 얻어서
      if GetInfo ( Name_ , Info ) then begin
         // 레벨변경
         if Info <> nil then begin
            Info.Level := Level_;
            Result := true;
         end;
      end;
   end;
end;

function TRelationShipMgr.GetLoverCount : integer;
begin
   Result := fLoverCount;
end;

function TRelationShipMgr.GetLoverName : string;
var
   Info : TRelationShipInfo;
   i    : integer;
begin
   Result := '';

   for i := 0 to FItems.count -1 do
   begin
      Info := FItems[i];

      if ( Info <> nil ) then
      begin
         Result := Info.Name;
         exit;
      end;
   end;
end;

function TRelationShipMgr.GetLoverDays : string;
var
   Info : TRelationShipInfo;
   i    : integer;
begin
   Result := '';

   for i := 0 to FItems.count -1 do begin
      Info := FItems[i];

      if ( Info <> nil ) then begin
         Result := GetDayNow( Info.Date, Info.ServerDate );
         exit;
      end;
   end;
end;


end.
