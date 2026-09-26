unit UserMgr;

interface

uses
    Classes, CmdMgr , {ElHashList ,} grobal2 , UserSystem , TagSystem , FriendSystem,
    sysutils , HUtil32 , SyncObjs;

type

    // Sub System 's Type
    TSystemType = (stTag , stFriend);

    // TUserFunc Class Declarations --------------------------------------------
    // UserMgr 에서 리스트로 관리될 시스템의 집합
    // -------------------------------------------------------------------------
    TUserfunc  = class( ICommand)
    public
        FInfo    : TUserInfo;
        FTag     : TTagMgr;
        FFriend  : TFriendMgr;

        constructor Create;override;
        destructor  Destroy;override;
        procedure   OnCmdChange( var Msg : TCmdMsg ) ; override;

        function  IsRealUser : Boolean;
        // for TagMgr...
        function  OpenTag : Boolean;
        procedure CloseTag;

        // For FriendMgr...
        function  OpenFriend : Boolean;
        procedure CloseFriend;

    end;
    PTUserfunc = ^TUserfunc;

    // TUserMgr Class Declarations ---------------------------------------------
    // 여러 시스템을 유저이름을 가지고 해시 리스트로 관리함
    // -------------------------------------------------------------------------
    TUserMgr = class ( TCmdMgr )
    private
        FItems   : TList;  //TElHashList;
        FHumanCS : TCriticalSection;
        // 내부 유저 전부 삭제
        procedure RemoveAll;
    public
        constructor Create; override;
        destructor  Destroy;override;

        // 유저 추가
        function  Add(
            UserName_   : String;       // 유저이름
            Recog_      : Integer;      // Hum 의 메모리 번호
            ConnState_  : Integer;      // 접속 상태
            GateIdx_    : Integer;      // 게이트 번호
            userGateIdx_: Integer;      // 유저 게이트 번호
            UserHandle_ : Integer       // 유저 핸들
        ): Boolean;
        function  Find       ( UserName_ : String ): TUserFunc;
        // 유저 삭제
        function  Delete     ( UserName_ : String ): Boolean;

        procedure OpenUser   ( UserName_ : String ); // 서브시스템을 실행가능하게
        procedure CloserUser ( UserName_ : String ); // 서브시스템을 실행불가능하게

        function  GetUserInfo( UserName_ : String ; var UserInfo_ : TUserInfo ): Boolean;
        function  GetUserFunc( UserName_ : String ; var UserFunc_ : TUserFunc ): Boolean;

        procedure OnCmdChange( var Msg : TCmdMsg ) ; override;

        // DB 쪽에서 직접 전송됨
        procedure   OnCmdDBROwnList  ( Cmd : TCmdMsg );
        procedure   OnCmdDBRLMList   ( Cmd : TCmdMsg );
        // DB 쪽으로 명령 전송
        procedure OnCmdDBOwnList     ( UserInfo:TUserInfo );
        procedure OnSendInfoToOthers ( UserName : String ;ConnState : integer ;  MapInfo:String; LinkedFriend : String );

        // For UserInfo...
        // 접속 정보 변경
        function  SetConnState ( UserName_ : String ; ConnState_ : integer): Boolean;
        // 쪽지 또는 친구 시스템등을 생성
        procedure OpenSubSystem ( UserName_ : String ; SystemType : TSystemType );
        // 쪽지 또는 친구 시스템등을 삭제
        procedure CloseSubSystem( Username_ : String ; SystemType : TSystemType );

    end;
    PTUserMgr = ^TUserMgr;

//var
//    g_UserMgr : TUserMgr; // 시스템 전체가참조할 수 있는 유저 메니저 설정

implementation
uses
    svMain;
////////////////////////////////////////////////////////////////////////////////
// TUserFunc
////////////////////////////////////////////////////////////////////////////////
constructor TUserFunc.Create;
begin
    inherited;
    //TO DO Initialize
    FInfo    := TUserInfo.Create;
    FTag     := nil;
    FFriend  := nil;

end;

destructor  TUserFunc.Destroy;
begin
    if ( FInfo <> nil   ) then FInfo.Free;
    if ( FTag  <> nil   ) then FTag.Free;
    if ( FFriend <> nil ) then FFriend.Free;

    inherited;
end;

//------------------------------------------------------------------------------
// 명령어 이벤트 발생시 불리는 곳
//------------------------------------------------------------------------------
procedure TUserFunc.OnCmdChange( var Msg : TCmdMsg );
begin

end;

//------------------------------------------------------------------------------
// 같은서버에 접속하고 네트웍 전송이 가능한 유저
//------------------------------------------------------------------------------
function TUserFunc.IsRealUser : Boolean;
begin
    Result := false;

    if FInfo <> nil then
    begin
        if( FInfo.UserHandle > 0 )then
        begin
            Result := true;
        end;
    end;

end;
//------------------------------------------------------------------------------
// 쪽지 시스템 생성
//------------------------------------------------------------------------------
function TUserFunc.OpenTag : Boolean;
begin
    Result := false;
    if FInfo <> nil then
    begin
        if FTag <> nil then CloseTag;

        FTag := TTagMgr.Create;

        // Loading Datas...
        // 유저가 클릭한 순간 디비에서 읽어오게 변경
        // FTag.OnCmdDBList( FInfo );
        FTag.OnCmdDBRejectList( FInfo );

        Result := true;
    end
end;

//------------------------------------------------------------------------------
// 쪽지 시스템 닫기
//------------------------------------------------------------------------------
procedure TUserFunc.CloseTag;
begin
    if FTag <> nil then
    begin
        FTag.Free;
        FTag := nil;
    end;
end;

//------------------------------------------------------------------------------
// 친구 시스템 열기
//------------------------------------------------------------------------------
function TUserFunc.OpenFriend : Boolean;
begin
    Result := false;
    if FInfo <> nil then
    begin
        if FFriend <> nil then CloseFriend;
        FFriend := TFriendMgr.Create;

        // Loading Datas...
        FFriend.OnCmdDBList( FInfo );

        Result := true;
    end

end;

//------------------------------------------------------------------------------
// 친구 시스템 닫기
//------------------------------------------------------------------------------
procedure TUserFunc.CloseFriend;
begin
    if FFriend <> nil then
    begin
        FFriend.Free;
        FFriend := nil;
    end;
end;

////////////////////////////////////////////////////////////////////////////////
// TUserMgr
////////////////////////////////////////////////////////////////////////////////
constructor TUserMgr.Create;
begin
    inherited ;
    //TO DO Initialize
    FItems := TList.Create;   //TElHashList.Create;
    FHumanCS := TCriticalSection.Create;

end;

destructor  TUserMgr.Destroy;
begin
    RemoveAll;

    FItems.Free;

    FHumanCS.Free;

    inherited;
end;

//------------------------------------------------------------------------------
// ADD Info To hash List
//------------------------------------------------------------------------------
function TUserMgr.Add (
    UserName_   : String;
    Recog_      : Integer;
    ConnState_  : Integer;
    GateIdx_    : Integer;
    UserGateIdx_: Integer;
    UserHandle_ : Integer
): Boolean;
var
    Info   : TUserFunc;
    ReUse  : Boolean;
begin
    Result := false;

    // 같은 이름의 사용자가 있나보고
    if GetUserFunc( UserName_ , Info ) then
    begin
        ErrMsg('Exist User !:'+UserName_ );
        ReUse := true;
    end
    else
    begin
        // 메모리 생성
        Info := TUserFunc.Create;
        ReUse := false;
    end;


    if ( Info <> nil ) then
    begin
        // 데이터를 새로 갱신하자
        Info.FInfo.UserName     := UserName_;
        Info.FInfo.Recog        := Recog_;
        Info.FInfo.ConnState    := ConnState_;
        Info.FInfo.GateIdx      := GateIdx_;
        Info.FInfo.UserGateIdx  := UserGateIdx_;
        Info.FInfo.UserHandle   := UserHandle_;

        // ToTest
        // ErrMsg( UserName_ +':'+ IntTostr( Recog_ ) + ':'+IntToStr( UserHandle_ ));

        // 메모리 재사용일 경우에는 그냥 넘어가자
        if not ReUse then
            FItems.Add( Info );
//          FItems.Add ( UserName_ , Info );

        // 내부 서브 시스템을 연다....
        OpenUser( UserName_ );

        // 친구 관련 소유자 리스트 부르자
        // UserHandle_ = 0 이면 다른서버에서 접속한 사람임
        if Info.IsRealUser then
            OnCmdDBOwnList( Info.FInfo );

        Result := true;
    end


end;

function TUserMgr.Find    ( UserName_ : String ): TUserFunc;
var
   Item   : TUserFunc;
   i      : integer;
begin
   Result := nil;
   for i := 0 to FItems.Count - 1 do begin
       Item := TUserFunc(FItems.Items[i]);
       if Item.FInfo.UserName = UserName_ then begin
          Result := Item;
          exit;
       end;
   end;
end;

//------------------------------------------------------------------------------
// Delete Info From hash List
//------------------------------------------------------------------------------
function TUserMgr.Delete  ( UserName_ : String ): Boolean;
var
    Item   : TUserFunc;
    i      : integer;
begin
    Result := false;

    Item := Find( UserName_ );   //FItems.Item[ UserName_ ];
    if  Item <> nil then
    begin
        // 친구 관련 소유자 리스트 부르자
        if Item.IsRealUser then
            OnCmdDBOwnList( Item.FInfo );
        i := FItems.IndexOf (Item);
        if i >= 0 then begin
//         FItems.Delete( UserName_ );
           FItems.Delete(i); 
           Item.Free;
           Result := true;
        end;
    end;
end;


//------------------------------------------------------------------------------
// Open Sub System and Send Info To Others
//------------------------------------------------------------------------------
procedure TUserMgr.OpenUser ( UserName_ : String );
var
    Item    : TUserFunc;
begin
    Item := Find(UserName_);   //FItems.Item[ UserName_ ];
    if Item <> nil then
    begin
        if Item.FInfo   <> nil then Item.FInfo.OnUserOpen;
        if Item.FTag    <> nil then Item.FTag.OnUserOpen;
        if Item.FFriend <> nil then Item.FFriend.OnUserOpen;
    end;

end;

//------------------------------------------------------------------------------
// CLose Sub System and Send Info To Others
//------------------------------------------------------------------------------
procedure TUserMgr.CloserUser ( UserName_ : String );
var
    Item    : TUserFunc;
begin
    Item := Find(UserName_);  // FItems.Item[ UserName_ ];
    if Item <> nil then
    begin
        if Item.FInfo   <> nil then Item.FInfo.OnUserClose;
        if Item.FTag    <> nil then Item.FTag.OnUserClose;
        if Item.FFriend <> nil then Item.FFriend.OnUserClose;
    end;

end;
//------------------------------------------------------------------------------
// Delete All Info From hash List
//------------------------------------------------------------------------------
procedure TUserMgr.RemoveAll;
var
    i       : integer;
    Item    : TUserFunc;
begin
    // TO DO Free Mem
    for i := 0 to FItems.Count -1 do
    begin
        Item := FItems.Items[i];
        Item.Free;
    end;

    FItems.Clear;

end;

//------------------------------------------------------------------------------
// Find And Get Userfunc From hash List
//------------------------------------------------------------------------------
function TUserMgr.GetUserFunc( UserName_ : String ; var UserFunc_ :TUserfunc): Boolean;
var
    Item : TUserFunc;
begin
    Item := Find(UserName_);  // FItems.Item[ UserName_ ];
    if Item <> nil then
    begin
        UserFunc_   := Item;
        Result      := true;
    end
    else
    begin
        UserFunc_   := nil;
        Result      := false;
    end;
end;

//------------------------------------------------------------------------------
// Find And Get UserInfo From hash List
//------------------------------------------------------------------------------
function TUserMgr.GetUserInfo( UserName_ : String ; var UserInfo_ : TUserInfo): Boolean;
var
    Item    : TUserFunc;
begin
    UserInfo_   := nil;
    Result      := false;

    Item    := Find(UserName_); //FItems.Item[ UserName_ ];

    if ( Item <> nil ) then
    begin
        if ( Item.FInfo <> nil ) then
        begin
            UserInfo_   := Item.FInfo;
            Result      := true;
        end
    end;


end;

//------------------------------------------------------------------------------
// Change Info's ConnState
//------------------------------------------------------------------------------
function TUserMgr.SetConnState ( UserName_ : String ; ConnState_ : integer): Boolean;
var
    Item : TUserInfo;
begin
    Result := false;

    if GetUserInfo( UserName_  , Item ) then
    begin
        Item.ConnState := ConnState_;
        Result := true;
    end

end;

//------------------------------------------------------------------------------
// The Event Call When Command is Changed
//------------------------------------------------------------------------------
procedure TUserMgr.OnCmdChange( var Msg : TCmdMsg ) ;
var
    Func : TUserFunc;
begin

    // UserMgr 에서 처리할 명령어
    case Msg.CmdNum of
        DBR_FRIEND_WONLIST :
        begin
            OnCmdDBROwnList( Msg );
            exit;
        end;
        DBR_LM_LIST :
        begin
            OnCmdDBRLMList( Msg );
            exit;
        end;

        ISM_FUNC_USEROPEN  :
        begin
            // 유저를 추가한다.
            if Add( Msg.UserName   , Msg.Msg.Recog  ,  Msg.Msg.Param  ,
                    Msg.GateIdx    , Msg.UserGateIdx,  Msg.Userhandle  ) then
            begin
                // UserHandle_ = 0 이면 다른서버에서 접속한 사람이다
                // 서브 시스템은 열지 않는다.
                if Msg.Userhandle <> 0 then
                begin
                    OpenSubSystem( Msg.UserName , stFriend );
                    OpenSubSystem( Msg.UserName , stTag );
                end;
            end;
            exit;

        end;
        ISM_FUNC_USERCLOSE :
        begin
            CloserUser( Msg.UserName );
            Delete( Msg.UserName );
            exit;
        end;
    end;


    if GetUserFunc( Msg.UserName , Func ) then
    begin
        // TO TEST: 어떤 명령어가 왔는지 보여준다.
        //ErrMsg( Format('%d,%d,%d,%d,%d,%s',
        //[Msg.Msg.Recog , Msg.Msg.Ident ,Msg.Msg.Param ,Msg.Msg.Tag ,Msg.Msg.Series, Msg.Body ]));

        Msg.pInfo := Func.FInfo ;

        // Friend System -----------------------------------
        if ( Func.FInfo <> nil ) then
        begin

            case Msg.CmdNum of
            ISM_FRIEND_OPEN,
            ISM_FRIEND_CLOSE,
            ISM_USER_INFO:
                begin
                    Func.FInfo.OnCmdChange( Msg );
                    exit;
                end;
            end;

         end
         else
            exit; // UserInfo 가없으면 안됨

        // Friend System -----------------------------------
        if Func.FFriend <> nil then
        begin
            case Msg.CmdNum of
            CM_FRIEND_ADD,
            CM_FRIEND_DELETE,
            CM_FRIEND_EDIT,
            CM_FRIEND_LIST,
            ISM_FRIEND_INFO,
            ISM_FRIEND_DELETE,
            ISM_FRIEND_RESULT,
            DBR_FRIEND_LIST,
            DBR_FRIEND_RESULT:
                begin
                    Func.FFriend.OnCmdChange( Msg );
                    Exit;
                end;
            end;
        end;

        // Tag System --------------------------------------
        if Func.FTag <> nil then
        begin
            case Msg.CmdNum of
            CM_TAG_ADD,
            CM_TAG_ADD_DOUBLE,
            CM_TAG_DELETE,
            CM_TAG_SETINFO,
            CM_TAG_LIST,
            CM_TAG_REJECT_LIST,
            CM_TAG_REJECT_ADD,
            CM_TAG_REJECT_DELETE,
            ISM_TAG_SEND,
            ISM_TAG_RESULT,
            DBR_TAG_LIST,
            DBR_TAG_REJECT_LIST,
            DBR_TAG_NOTREADCOUNT,
            DBR_TAG_RESULT:
                begin
                    Func.FTag.OnCmdChange( Msg );
                    Exit;
                end;
            end;
        end;


    end; // if GetUserFunc...

end;

//------------------------------------------------------------------------------
// 내부 시스템중 친구와 쪽지를 새로 만든다.
//------------------------------------------------------------------------------
procedure TUserMgr.OpenSubSystem ( UserName_ : String ; SystemType : TSystemType );
var
    userfunc : TUserFunc;
begin
    if GetUserfunc ( UserName_ , userfunc) then
    begin
        case SystemType of
        stTag       : userfunc.OpenTag;
        stFriend    : userfunc.OpenFriend;
        end;
    end;
end;

//------------------------------------------------------------------------------
// 내부시스템중 친구와 쪽지를 삭제한다.
//------------------------------------------------------------------------------
procedure TUserMgr.CloseSubSystem( Username_ : String ; SystemType : TSystemType );
var
    userfunc : TUserFunc;
begin
    if GetUserFunc ( UserName_  , userfunc)  then
    begin
        case SystemType of
        stTag       : userfunc.CloseTag;
        stFriend    : userfunc.CloseFriend;
        end;
    end;
end;

//------------------------------------------------------------------------------
// DB_FRIEND_OWNLIST  :  DB에 친구로 등록된 사람들 리스트 요청
// Params  : 없음
//------------------------------------------------------------------------------
procedure TUserMgr.OnCmdDBOwnList( UserInfo : TUserInfo );
begin
   if BoTestServer then begin
      UserMgrEngine.InterSendMsg(   stDBServer ,ServerIndex,0,0,0,
                     UserInfo.UserName ,0, DB_FRIEND_OWNLIST ,
                     0,0,0,'' );
   end;
end;



//------------------------------------------------------------------------------
// DBR_FRIEND_OWNLIST  :  DB에서 보내는 친구로 등록한사람 리스트
// Params  : 친구로 등록한사람 리스트
//------------------------------------------------------------------------------
procedure TUserMgr.OnCmdDBROwnList( Cmd : TCmdMsg );
var
    ListCount   : integer;
    Friend      : string;
    i           : integer;
    ConnState   : integer;
    TempStr     : string;
    BodyStr     : string;
    MapInfo     : string;
    userinfo    : TUserInfo;
begin
    // TO DO : 리스트로 User를  등록한 사람들에게 접속했음을 전송
    BodyStr := GetValidStr3(Cmd.body,TempStr, ['/']);

    // 리스트 개수 얻기
    ListCount := Str_ToInt( TempStr , 0);

    // 커넥션 상태를 찾는다.
    ConnState := 0;
    MapInfo   := '';
    if GetUserInfo( Cmd.UserName , userinfo ) then
    begin
        ConnState   := userinfo.ConnState;
        MapInfo     := userinfo.MapInfo;
    end;

    for i :=0 to ListCount -1 do
    begin
        // 분리자로 개인요소를 분리한다.
        BodyStr     := GetValidStr3 (BodyStr,Friend, ['/']);

        if ( Friend <> '') then
        begin
            // 서버에 있는 사람들에게만 보낸다
            if GetUserInfo( Friend , userinfo ) then
                OnSendInfoToOthers( Cmd.UserName , ConnState ,MapInfo, Friend );
        end;
    end;

end;

//------------------------------------------------------------------------------
// 관계리스트를 읽었다.
//------------------------------------------------------------------------------
procedure TUserMgr.OnCmdDBRLMList( Cmd : TCmdMsg );
begin

   FHumanCS.Enter;
   try
      UserEngine.ExternSendMessage( Cmd.UserName, RM_LM_DBGETLIST, 0, 0, 0, 0, Cmd.Body );
   finally
      FHumanCS.Leave;
   end;

end;

//------------------------------------------------------------------------------
// 자신을 친구등록한 유저에게 접속되었음을 알린다.
//------------------------------------------------------------------------------
procedure TUserMgr.OnSendInfoToOthers ( UserName : String ; ConnState : Integer ; MapInfo:String; LinkedFriend : String );
var
    str : string;
begin
    str := UserName + '/'+IntToStr( ConnState )+'/'+ MapInfo +'/';

    UserMgrEngine.InterSendMsg (   stOtherServer , ServerIndex , 0 , 0 , 0,
                                LinkedFriend  , 0, ISM_USER_INFO ,
                                ServerIndex   , 0, 0, str);

{
    // 친구 정보를 얻자
    if g_UserMgr.GetUserInfo( LinkedFriend  , FriendInfo) then
    begin

        // 접속된 사람만 알아내서
        if FriendInfo.ConnState >= CONNSTATE_CONNECT_0 then
        begin
            // 친구메니저안의 친구정보를 얻자.
            ItemInfo := FItems.Item[LinkedFriend];
            if ( ItemInfo <> nil ) then
            begin

                // 자신의 서버와 같은 서버에있는사람이면
                if FriendInfo.ConnState = ( ServerIndex + CONNSTATE_CONNECT_0) then
                begin
                    // TO DO : 클라이언트에게 커넥션 정보를 보냄
                    OnCmdSMUserInfo( F
                end
                else
                begin
                    // TO DO : 다른서버로 커네션 정보를 보냄

                end;

            end;// if ItemInfo <> nil .../
        end; // if FriendInfo.ConnState...

    end
}
end;


// END.-------------------------------------------------------------------------
end.

