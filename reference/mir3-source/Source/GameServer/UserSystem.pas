unit UserSystem;

interface

uses
    Classes, SysUtils ,CmdMgr , {ElHashList ,} grobal2 , HUtil32;


type
    // TUserInfo Class Declarations --------------------------------------------
    TUserInfo  = class (ICommand)
    private
        FUserName    : String;      // 등록자 이름
        FConnState   : Integer;     // 접속상태
        FGateIdx     : Integer;     // 게임서버에 접속된 게이트 번호
        FUserGateIdx : Integer;     // 게임서버에 접속된 게이트 번호
        FUserHandle  : Integer;     // 유저 핸들
        FRecog       : Integer;     // Hum 메모리의 주소
        FMapInfo     : String;      // 접속한 때의 맵 정보
    public
        constructor Create;  override;
        destructor  Destroy; override;

        procedure   OnUserOpen;
        procedure   OnUserClose;
        // 명령어 패치
        procedure   OnCmdChange( var Cmd : TCmdMsg ) ; override;

        // 명령어 실행 관련
        procedure   OnCmdISMFriendOpen ( Cmd : TCmdMsg);
        procedure   OnCmdISMFriendClose( Cmd : TCmdMsg);
        procedure   OnCmdISMUserInfo   ( Cmd : TCmdMsg);


       // 내부 멤버함수 참조 프로퍼티
        property  UserName      : String  read FUserName    Write FUserName;
        property  ConnState     : Integer read FConnState   Write FConnState;
        property  GateIdx       : Integer read FGateIdx     Write FGateIdx;
        property  UserGateIdx   : Integer read FUserGateIdx Write FUserGateIdx;
        property  UserHandle    : Integer read FUserHandle  Write FUserHandle;
        property  Recog         : Integer read FRecog       Write FRecog;
        property  MapInfo       : String  read FMapInfo     Write FMapInfo;

    end;

    PTUserInfo = ^TUserInfo;

implementation
    uses
        UserMgr , svMain;

// TUserInfo =================================================================
constructor TUserInfo.Create;
begin
    inherited ;
    //TO DO Initialize
    FUserName    := '';
    FConnState   := CONNSTATE_UNKNOWN;
    FGateIdx     := 0;
    FUserHandle  := 0;
    FRecog       := 0;
    FMapInfo     :='';
end;

destructor  TUserInfo.Destroy;
begin
    // TO DO Free Mem

    inherited;
end;

//------------------------------------------------------------------------------
// 시스템을 가능하게 만든다.
//------------------------------------------------------------------------------
procedure TUserInfo.OnUserOpen;
begin

end;

//------------------------------------------------------------------------------
// 시스템을  불가능하게 만든다.
//------------------------------------------------------------------------------
procedure TUserInfo.OnUserClose;
begin

end;
//------------------------------------------------------------------------------
// 멸령어 이벤트 처리
//------------------------------------------------------------------------------
procedure TUserInfo.OnCmdChange( var Cmd :TCmdMsg ) ;
begin

    case Cmd.CmdNum of
    ISM_FRIEND_OPEN     : OnCmdISMFriendOpen ( Cmd );
    ISM_FRIEND_CLOSE    : OnCmdISMFriendClose( Cmd );
    ISM_USER_INFO       : OnCmdISMUserInfo   ( Cmd );
    end;

end;

//------------------------------------------------------------------------------
// 친구시스템 생성
//------------------------------------------------------------------------------
procedure TUserInfo.OnCmdISMFriendOpen ( Cmd : TCmdMsg );
begin

end;

//------------------------------------------------------------------------------
// 친구 시스템 삭제
//------------------------------------------------------------------------------
procedure TUserInfo.OnCmdISMFriendClose ( Cmd : TCmdMsg );
begin

end;

//------------------------------------------------------------------------------
// 친구 시스템등에서 보내준 접속정보를 클라이언트에 전송한다.
//------------------------------------------------------------------------------
procedure TUserInfo.OnCmdISMUserInfo ( Cmd : TCmdMsg );
var
    UserName    : String;
    ConnState   : String;
    MapInfo     : String;
    Str         : String;

    UserInfo    : TUserInfo;
begin

    // 들어온메세지 분리
    Str := GetValidStr3 (Cmd.body,UserName  , ['/']);
    Str := GetValidStr3 (Str     ,ConnState , ['/']);
    Str := GetValidStr3 (Str     ,MapInfo   , ['/']);

    // 전송할 메세지를 조합한다.
    UserInfo := Cmd.pInfo ;
    Str      := UserName + '/' + MapInfo;

    // 테스트서버가 아니면 유저 접속 상태를 0으로 보낸다. 2003-07-01 : 유저가 접속한 정보를 없엔다.
    if not BoTestServer then begin
       ConnState := '0';
    end;

    // 클라이언트에 메세지 전송
    //
    UserMgrEngine.InterSendMsg( stClient, 0, UserInfo.GateIdx, UserInfo.UserGateIdx, UserInfo.UserHandle,
                    UserInfo.UserName, UserInfo.Recog, SM_USER_INFO, Str_ToInt(ConnState,0), 0, 0, Str );

end;



end.
