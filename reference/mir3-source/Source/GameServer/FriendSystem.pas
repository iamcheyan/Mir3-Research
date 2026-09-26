unit FriendSystem;

interface

uses
    Classes, SysUtils ,CmdMgr , {ElHashList ,} grobal2 , UserSystem , HUtil32 ;

type

    // TFriendInfo Class Declarations ------------------------------------------
    TFriendInfo  = class ( ICommand )
    private
        FOwnner      : String;      // 소유자 이름
        FName        : String;      // 등록자 이름
        FRegState    : Integer;     // 등록상태
        FDesc        : String;      // 간단한 설명

//        FIsSendAble  : Boolean;     // 정보를 전송가능하가 판다.

    public
        constructor Create;  override;
        destructor  Destroy; override;

        // 명령어 패치
//       procedure   OnCmdChange( var Msg : TCmdMsg ) ; override;

        // 내부 멤버접근용 프로퍼티
        property  Name      : String  read FName     Write FName;
        property  Ownner    : String  read FOwnner   Write FOwnner;
        property  RegState  : Integer read FRegState Write FRegState;
        property  Desc      : String  read FDesc     Write FDesc;


    end;
    PTFriendInfo = ^TFriendInfo;

    // TFreiendMgr Class Declarations ------------------------------------------
    TFriendMgr = class ( ICommand )
    private
        FItems          : TList;     //TElHashList;      // 친구정보를 가지고있는 해시테이블
        FIsListSendAble : Boolean;          // 리스트를 전송가능하가 여부
        FWantListFlag   : Boolean;          // 리스트를 전송가능하기전에 클라이언트가 요청함

       // 전부 삭제 ..............................
        procedure RemoveAll;

    public
        constructor Create; override;
        destructor  Destroy;override;

        procedure   OnUserOpen;
        procedure   OnUserClose;

        // 찾기
        function  Find( UserName_ : String) : TFriendInfo;
        // 친구추가 ...............................
        function  Add(
            UserInfo    : TUserInfo;
            Friend      : String;
            RegState    : Integer;
            Desc        : String
            ): Boolean;
        // 친구 삭제 ..............................
        function  Delete  (
            UserInfo    : TUserInfo;
            Friend      : String
            ): Boolean;
        // 설명 변경 ..............................
        function  SetDesc (
            UserInfo    : TUserInfo;
            Friend      : String;
            Desc        : String
            ):Boolean;
        // 친구 찾기 .............................
        function IsFriend (
            Name        : String
            ):Boolean;

        //----------------------------------------------------------------------
        procedure   OnCmdChange( var Msg : TCmdMsg ) ; override;

        //----------------------------------------------------------------------
        // 직접적으로 메세지 전송 합수들
        procedure OnMsgInfoToClient(
            UserInfo    : TUserInfo;
            FriendName  : String;
            ConnState   : integer;
            RegState    : integer;
            Desc        : String
        );
        procedure OnMsgInfoToServer(
            UserInfo    : TUserInfo;
            FriendName  : String;
            RegState    : integer;
            Desc        : string
        );


        // 프로토콜과 관련된 함수들.............................................
        procedure OnSendListToClient( UserInfo : TUserInfo );
        procedure OnSendInfoToClient( UserInfo : TUserInfo ; Friend : String);
//        procedure OnSendInfoToOthers( UserInfo : TUserInfo ; LinkedFriend : String );

        // Client 로부터 오는 명령어들 .........................................
        procedure OnCmdCMList     ( Cmd : TCmdMsg );
        procedure OnCmdCMAdd      ( Cmd : TCmdMsg );
        procedure OnCmdCMDelete   ( Cmd : TCmdMsg );
        procedure OnCmdCMEdit     ( Cmd : TCmdMsg );

        // Client 에 보내는 명령어들............................................
        procedure OnCmdSMInfo(
            UserInfo    : TUserInfo;
            FriendName  : String;
            RegState    : Word;
            Conn        : Word;
            Desc        : String );

        procedure OnCmdSMDelete(
            UserInfo    : TUserInfo;
            FriendName  : String );

        procedure OnCmdSMResult(
            UserInfo    : TUserInfo;
            CmdNum      : Word;
            Value       : Word );

        // 서버간에서 들어오는 명령어들 ........................................
        procedure OnCmdISMInfo    ( Cmd : TCmdMsg );
        procedure OnCmdISMDelete  ( Cmd : TCmdMsg );
        procedure OnCmdISMResult  ( Cmd : TCmdMsg );

        // 서버간에서 보내는 명령어들...........................................
        procedure OnCmdOSMInfo(
            UserName    : String;
            SvrIndex    : integer;
            FriendName  : String;
            RegState    : Integer;  // 등록상태
            Conn        : Integer;  // 접속상태
            Desc        : String    // 설명
            );
        procedure OnCmdOSMDelete(
            UserName    : String;
            SvrIndex    : integer;
            FriendName  : String    // 삭제할 친구명
            );
        procedure OnCmdOSMResult(
            UserName    : String;
            SvrIndex    : integer;
            CmdNum      : Word;     // 명령어번호
            ResultValue : Word      // 결과값
            );

        //DB 로 보내는 명령어들 ................................................
        procedure OnCmdDBList   ( UserInfo:TUserInfo );
        procedure OnCmdDBAdd    ( UserInfo:TUserInfo ; Friend : String;
                                  RegState : Word ; Desc : String);
        procedure OnCmdDBDelete ( UserInfo:TUserInfo ; Friend : String  );
        procedure OnCmdDBEdit   ( UserInfo:TUserInfo ; Friend : String ; Desc : String);

        //DB 로부터 오는 명령어들 ..............................................
        procedure OnCmdDBRList   ( Cmd : TCmdMsg );
        procedure OnCmdDBRResult ( Cmd : TCmdMsg );


    end;
    PTFriendMgr = ^TFriendMgr;

implementation
uses
    UserMgr , svMain;
// TFriendInfo =================================================================
constructor TFriendInfo.Create;
begin
    inherited ;
    //TO DO Initialize

end;

destructor  TFriendInfo.Destroy;
begin
    // TO DO Free Mem

    inherited;
end;
{
procedure TFriendInfo.OnCmdChange( var Msg : TCmdMsg );
begin
    // TO DO : 이벤트 처리
end;
}

// TFreiendMgr =================================================================
constructor TFriendMgr.Create;
begin
    inherited ;
    //TO DO Initialize
    FItems := TList.Create;     //TElHashList.Create;


    FIsListSendAble := false;   //  클라이언트에 쪽지리스트 전송 가능여부
    FWantListFlag   := false;   //  클라이언트에서 리스트 전송 요청

end;

destructor  TFriendMgr.Destroy;
begin
    RemoveAll;

    FItems.Free;
    inherited;
end;
//------------------------------------------------------------------------------
// 시스템을 가능하게 한다.
//------------------------------------------------------------------------------
procedure TFriendMgr.OnUserOpen;
begin

end;

//------------------------------------------------------------------------------
// 시스템을 불가능하게 한다.
//------------------------------------------------------------------------------
procedure TFriendMgr.OnUserClose;
begin

end;

function TFriendMgr.Find( UserName_ : String) : TFriendInfo;
var
   Item   : TFriendInfo;
   i      : integer;
begin
   Result := nil;
   for i := 0 to FItems.Count - 1 do begin
       Item := TFriendInfo(FItems.Items[i]);
       if Item.FName = UserName_ then begin
          Result := Item;
          exit;
       end;
   end;
end;

//------------------------------------------------------------------------------
// 친구 메니저에 친구정보 추가
//------------------------------------------------------------------------------
function TFriendMgr.Add(
    UserInfo    : TUserInfo;
    Friend      : String;
    RegState    : Integer;
    Desc        : String
): Boolean;
var
    Info   : TFriendInfo;
begin

    Result := false;

    if ( Friend <> '') and ( not IsFriend( Friend )) then
    begin

        Info := TFriendInfo.Create;

        if ( Info <> nil ) then
        begin
            Info.Name       := Friend ;
            Info.Ownner     := UserInfo.UserName ;
            Info.RegState   := RegState;
            Info.Desc       := Desc;

            FItems.Add(Info); //FItems.Add ( Friend , Info );

            Result := true;
        end
        else
            ErrMsg( 'Nil Pointer When Create -[TFriendMgr.Add]');

    end
    else
        ErrMsg ('Empty "Friend" -[TFriendMgr.Add]');
end;

//------------------------------------------------------------------------------
// 친구 메니저에서 친구정보 삭제
//------------------------------------------------------------------------------
function TFriendMgr.Delete( UserInfo : TUserInfo ; Friend : String ): Boolean;
var
    Item   : TFriendInfo;
    i      : Integer;
begin
    Result := false;

    Item := Find(Friend);   //FItems.Item[ Friend ];
    if  Item <> nil then
    begin
        i := FItems.IndexOf( Item );
        if i >= 0 then begin
           FItems.Delete(i); //FItems.Delete( Friend );
           Item.Free;
           Result := true;
        end;
    end;
end;

//------------------------------------------------------------------------------
// 친구의 설명을 변경한다.
//------------------------------------------------------------------------------
function  TFriendMgr.SetDesc(
    UserInfo    : TUserInfo;
    Friend      : String;
    Desc        : String
):Boolean;
var
    Item   : TFriendInfo;
begin
    Result := false;

    Item := Find(Friend);   //FItems.Item[ Friend ];
    if  Item <> nil then
    begin
        Item.FDesc := Desc;
        Result := true;
    end;
end;

//------------------------------------------------------------------------------
// 친구로 등록된 넘인지 알아본다 
//------------------------------------------------------------------------------
function TFriendMgr.IsFriend (
    Name        : String
):Boolean;
var
    Item   : TFriendInfo;
begin
    Result := FALSE;
    Item := Find(Name);
    if Item <> nil then Result := TRUE;
//  if FItems.Item[ Name ] <> nil then Result := TRUE;

end;
//------------------------------------------------------------------------------
// 등록된 모든 친구정보를 삭제한다.
//------------------------------------------------------------------------------
procedure TFriendMgr.RemoveAll;
var
    i      : integer;
    Item   : TFriendInfo;
begin
    // TO DO Free Mem
    for i := 0 to FItems.Count -1 do
    begin

        Item := FItems.Items[i];

        if ( Item  <> nil ) then
        begin
            Item.Free;
        end;

    end;

    FItems.Clear;

end;

//------------------------------------------------------------------------------
// 친구정보를 클라이언트에 전송
//------------------------------------------------------------------------------
procedure TFriendMgr.OnMsgInfoToClient(
    UserInfo    : TUserInfo;
    FriendName  : String;
    ConnState   : integer;
    RegState    : integer;
    Desc        : String
);
var
    str : string;
begin
    str := FriendName + '/' + Desc;

    UserMgrEngine.InterSendMsg (   stClient , 0, UserInfo.GateIdx,UserInfo.UserGateIdx,UserInfo.UserHandle,
                                UserInfo.UserName ,UserInfo.Recog, SM_FRIEND_INFO,
                                RegState,ConnState,0,str);
end;

//------------------------------------------------------------------------------
// 친구정보를 다른 게임서버로 전송
//------------------------------------------------------------------------------
procedure TFriendMgr.OnMsgInfoToServer(
    UserInfo    : TUserInfo;
    FriendName  : String;
    RegState    : integer;
    Desc        : string
);
var
    str : string;
begin
    str := IntToStr(RegState) +':'+FriendName + ':' + Desc;

    UserMgrEngine.InterSendMsg (
        stClient , 0,0,
        0,0,UserInfo.UserName ,UserInfo.Recog,
        ISM_FRIEND_INFO ,0,0,0,str);


end;


//------------------------------------------------------------------------------
// 리스트를 클라이언트에 전송
//------------------------------------------------------------------------------
procedure TFriendMgr.OnSendInfoToClient( UserInfo : TUserInfo ; Friend : String);
var
   i           : integer;
   friendinfo  : TUserInfo;
   Item        : TFriendInfo;
begin
   Item := Find(Friend);  // FItems.Item[Friend];

   if Item <> nil then begin
      // 친구가 접속한 사람인가 정보를 알아보고
      if BoTestServer and UserMgrEngine.InterGetUserInfo(Item.Name, friendinfo) then begin
         // 접속한 사람이면 접속정보를 알려주고
         OnMsgInfoToClient(  UserInfo,
                             Item.Name,
                             friendinfo.ConnState,
                             Item.RegState,
                             Item.Desc );
      end else begin
         // 비접속한 사람이면 비접속자임을 알려준다.
         OnMsgInfoToClient(  UserInfo,
                             Item.Name,
                             CONNSTATE_DISCONNECT,
                             Item.RegState,
                             Item.Desc );
      end;// if g_UserMgr...

   end;// if Item <> nil...

end;
//------------------------------------------------------------------------------
// 리스트를 클라이언트에 전송
//------------------------------------------------------------------------------
procedure TFriendMgr.OnSendListToClient( UserInfo : TUserInfo );
var
   i           : integer;
   friendinfo  : TUserInfo;
   Item        : TFriendInfo;
begin
   // 유저가 소유한 모든 친구리스트를 전송한다.
   for i := 0 to FItems.Count -1 do begin

      Item := FItems.Items[i];    // FItems.GetByIndex( i );

      //접속한 사람인지 알아본다.
      if BoTestServer and UserMgrEngine.InterGetUserInfo(Item.Name, friendinfo) then begin
         // 접속한 사람이면 접속정보를 알려주고
         OnMsgInfoToClient(  UserInfo,
                             Item.Name,
                             friendinfo.ConnState,
                             Item.RegState,
                             Item.Desc );
      end else begin
         // 비접속한 사람이면 비접속자임을 알려준다.
         OnMsgInfoToClient(  UserInfo,
                             Item.Name,
                             CONNSTATE_DISCONNECT,
                             Item.RegState,
                             Item.Desc );
      end;

   end;// for i :=0 ...

end;
//------------------------------------------------------------------------------
// 친구 명령어 처리 루틴 Override 됨
//------------------------------------------------------------------------------
procedure TFriendMgr.OnCmdChange( var Msg : TCmdMsg ) ;
begin
    case Msg.CmdNum of
    CM_FRIEND_ADD       : OnCmdCMAdd     ( Msg );
    CM_FRIEND_DELETE    : OnCmdCMDelete  ( Msg );
    CM_FRIEND_EDIT      : OnCmdCMEdit    ( Msg );
    CM_FRIEND_LIST      : OnCmdCMList    ( Msg );
    ISM_FRIEND_INFO     : OnCmdISMInfo   ( Msg );
    ISM_FRIEND_DELETE   : OnCmdISMDelete ( Msg );
    ISM_FRIEND_RESULT   : OnCmdISMResult ( Msg );
    DBR_FRIEND_LIST     : OnCmdDBRList   ( Msg );
//    DBR_FRIEND_WONLIST  : OnCmdDBROwnList( Msg );
    DBR_FRIEND_RESULT   : OnCmdDBRResult ( Msg );
    end;

end;

//==============================================================================
// 클라이언트로부터 오는 명령어들
//==============================================================================
//------------------------------------------------------------------------------
// CM_FRIEND_LIST  : 서버에게 리스트를 전송해달라고 요청
// Params   : 없음
//------------------------------------------------------------------------------
procedure TFriendMgr.OnCmdCMList( Cmd : TCmdMsg );
begin
    // 리스트를 전송해달라고 요청플레그 셋팅
    FWantListFlag := true;

    // 리스트 전송 준비가 되어있다면
    if ( FIsListSendAble ) then
    begin
        // 리스트 전송
        OnSendListToClient( Cmd.pInfo );
    end;
end;

//------------------------------------------------------------------------------
// CM_FRIEND_ADD  : 친구추가
// Params  : 케릭명 , 등록상태 ( 친구 , 연인 , 사제 , 악연 )
//------------------------------------------------------------------------------
procedure TFriendMgr.OnCmdCMAdd( Cmd : TCmdMsg );
var
    friend      : string;
    owner       : string;
    regstate    : integer;
    userinfo    : TUserInfo;
    forceflag   : integer;
begin
    // 패킷변환
    owner       := Cmd.UserName;
    friend      := Cmd.body;
    regstate    := Cmd.Msg.Param;
    forceflag   := Cmd.Msg.Tag;

{$IFDEF DEBUG}
    ErrMsg ('Cmd_CM_Add'+ Owner + '/' + Friend + '/' + IntToStr(regState) );
{$ENDIF}
    if UserMgrEngine.InterGetUserInfo( friend , userinfo ) then
    begin

      // 추가가 잘되는지 테스트 ... 나중에 DB 명령어에 가반하여 바꿔야됨
      if Add ( Cmd.pInfo , friend , regstate , '' ) then
      begin
         // 데이터 베이스로 명령어 전송
          OnCmdDBAdd( Cmd.pInfo , Friend ,regstate , '');
          OnMsgInfoToClient( Cmd.pInfo , friend , userinfo.ConnState , regstate , '' );
      end;

    end
    else
    begin
      //운영자에 의한 강제 입력일 경우
      if forceflag = 1 then
      begin
          if Add ( Cmd.pInfo , friend , regstate , '' ) then
          begin
              // 디비에는 저장하지 않고 클라이언트만 알려준다.
              OnMsgInfoToClient( Cmd.pInfo , friend , CONNSTATE_DISCONNECT , regstate , '' );
          end;
      end;

    end;

end;

//------------------------------------------------------------------------------
// CM_FRIEND_DELETEADD  : 친구삭제
// Params  : 삭제할 케릭명
//------------------------------------------------------------------------------
procedure TFriendMgr.OnCmdCMDelete( Cmd : TCmdMsg );
var
    Owner   : String;
    Friend  : String;
begin
    Owner   := Cmd.UserName;
    Friend  := Cmd.body;

{$IFDEF DEBUG}
    ErrMsg ('Cmd_CM_Delete'+ Owner + '/' + Friend );
{$ENDIF}

    if TRUE = Delete ( Cmd.pInfo , Friend ) then
    begin
       OnCmdSMDelete( Cmd.pInfo, Friend );
       OnCmdDBDelete( Cmd.pInfo , Friend );
    end
    else
    begin
       OnCmdSMResult( Cmd.pInfo,Cmd.CmdNum , CR_DONTDELETE );
    end;

end;

//------------------------------------------------------------------------------
// CM_FRIEND_EDIT  : 친구정보수정
// Params  : 변경할 케릭명 , 변경정보
//------------------------------------------------------------------------------
procedure TFriendMgr.OnCmdCMEdit(Cmd : TCmdMsg );
var
    Owner   :String;
    Friend  :String;
    Desc    :String;
begin
    Owner   := Cmd.UserName;
    Desc  := GetValidStr3 (Cmd.body,Friend, ['/']);

{$IFDEF DEBUG}
    ErrMsg ('Cmd_CM_SerDesc'+ Friend + '/' + Desc );
{$ENDIF}

    if ( TRUE = SetDesc( Cmd.pInfo , Friend , Desc ) ) then
    begin
        OnSendInfoToClient( Cmd.pInfo , Friend );
        OnCmdDBEdit( Cmd.pInfo, Friend, Desc );
    end;

end;

////////////////////////////////////////////////////////////////////////////////
// Client 에 보내는 명령어들
////////////////////////////////////////////////////////////////////////////////
//------------------------------------------------------------------------------
// SM_FRIEND_INFO  : 친구정보전송
// Params  : 친구케릭명 , 등록상태 , 접속상태 , 간단설명
//------------------------------------------------------------------------------
procedure TFriendMgr.OnCmdSMInfo(
    UserInfo    : TUserInfo;
    FriendName  : String;
    RegState    : Word;
    Conn        : Word;
    Desc        : String
    );
var
    str : string;
begin
    str := Desc;

    UserMgrEngine.InterSendMsg ( stClient ,
                              0,
                              UserInfo.GateIdx,
                              UserInfo.UserGateIdx,
                              UserInfo.UserHandle,
                              UserInfo.UserName,
                              UserInfo.Recog,
                              SM_FRIEND_INFO,
                              RegState,
                              Conn,
                              0,
                              str);
end;

//------------------------------------------------------------------------------
// SM_FRIEND_DELETE  : 친구삭제 요청
// Params  : 친구케릭명
//------------------------------------------------------------------------------
procedure TFriendMgr.OnCmdSMDelete(
    UserInfo    : TUserInfo;
    FriendName  : String
    );
var
    str : string;
begin
    str := FriendName;

    UserMgrEngine.InterSendMsg ( stClient ,0,
                              UserInfo.GateIdx  ,UserInfo.UserGateIdx,UserInfo.UserHandle,
                              UserInfo.UserName ,UserInfo.Recog,
                              SM_FRIEND_DELETE  , 0,0,0, str);

end;

//------------------------------------------------------------------------------
// SM_FRIEND_RESULT  : 클라이언트 요청에 대한 결과값
// Params  : 전송받은 클라이언트 프로토콜 번호  , 리턴값
//------------------------------------------------------------------------------
procedure TFriendMgr.OnCmdSMResult(
    UserInfo    : TUserInfo;
    CmdNum      : Word;
    Value       : Word
    );
begin
    UserMgrEngine.InterSendMsg ( stClient ,0,
                              UserInfo.GateIdx,UserInfo.UserGateIdx,UserInfo.UserHandle,
                              UserInfo.UserName ,UserInfo.Recog ,
                              SM_FRIEND_RESULT , CmdNum,Value,0, '');

end;

////////////////////////////////////////////////////////////////////////////////
// 서버간의 들어오는 명령어들
////////////////////////////////////////////////////////////////////////////////
//------------------------------------------------------------------------------
// ISM_FRIEND_INFO  : 서버간 친구추가 정보 전송받음
// Params  : 친구명 , 등록상태 , 간단설명
//------------------------------------------------------------------------------
procedure TFriendMgr.OnCmdISMInfo( Cmd : TCmdMsg );
var
    Friend      : string;
    RegState    : string;
    Desc        : string;
    TempStr     : string;
begin
    TempStr := GetValidStr3 (Cmd.body,RegState , [':']);
    Desc    := GetValidStr3 (TempStr,Friend , [':']);
    // 추가
    if not Add( Cmd.pInfo , Friend , Str_ToInt( RegState , 0 ) , Desc ) then
    begin
        ErrMsg( 'OnCmdISMInfo Dont Add Friend :'+ Cmd.Body );
    end;

end;

//------------------------------------------------------------------------------
// ISM_FRIEND_DELETE  : 서버간 친구삭제
// Params  : 친구명
//------------------------------------------------------------------------------
procedure TFriendMgr.OnCmdISMDelete( Cmd : TCmdMsg );
var
    Friend      : string;
    TempStr     : string;
begin
    Friend  := Cmd.Body;

    // 삭제
    if not Delete( Cmd.pInfo , Friend ) then
    begin
        ErrMsg( 'OnCmdISMInfo Dont Delete Friend :'+ Cmd.Body );
    end;

end;

//------------------------------------------------------------------------------
// ISM_FRIEND_RESULT  : 서버간 명령어 결과리턴
// Params  : 친구명
//------------------------------------------------------------------------------
procedure TFriendMgr.OnCmdISMResult( Cmd : TCmdMsg );
begin
    // TO TEST : 보낼것이 생기면 작성한다.
    ErrMsg('OnCmdISMRsult :'+Cmd.Body );
end;

////////////////////////////////////////////////////////////////////////////////
// 서버간의 보내는 명령어들
////////////////////////////////////////////////////////////////////////////////
//------------------------------------------------------------------------------
// ISM_FRIEND_INFO  : 서버간 친구등록 전송함
// Params  : 친구명 , 등록상태 , 간단설명
//------------------------------------------------------------------------------
procedure TFriendMgr.OnCmdOSMInfo(
    UserName    : String;
    SvrIndex    : integer;
    FriendName  : String;
    RegState    : Integer;
    Conn        : Integer;
    Desc        : String
);
var
    str : string;
begin
    // 페킷생성
    str := IntToStr(RegState)+':'+IntToStr(Conn)+':'+FriendName;
    // 패킷전송
    UserMgrEngine.InterSendMsg(   stOtherServer ,0,0,0,0,
                                UserName ,0, ISM_FRIEND_INFO ,
                                SvrIndex,0,0, str);
end;

//------------------------------------------------------------------------------
// ISM_FRIEND_DELETE  : 서버간 친구삭제 전송함
// Params  : 친구명
//------------------------------------------------------------------------------
procedure TFriendMgr.OnCmdOSMDelete(
    UserName    : String ;
    SvrIndex    : integer ;
    FriendName  : String
);
var
    str : string;
begin
    str := FriendName;

    UserMgrEngine.InterSendMsg(   stOtherServer ,0,0,0,0,
                                UserName ,0, ISM_FRIEND_DELETE ,
                                SvrIndex,0,0, str);

end;

//------------------------------------------------------------------------------
// ISM_FRIEND_DELETE  : 서버간 명령어에 대한 결과값 전송
// Params  : 명령번호 , 결과값
//------------------------------------------------------------------------------
procedure TFriendMgr.OnCmdOSMResult(
    UserName    : String;
    SvrIndex    : integer;
    CmdNum      : Word;
    ResultValue : Word
);
var
    str : string;
begin
    str := IntToStr(CmdNum) +':' +IntToStr(ResultValue);

    UserMgrEngine.InterSendMsg(   stOtherServer ,0,0,0,0,
                                UserName ,0, ISM_FRIEND_RESULT ,
                                SvrIndex,0,0, str);

end;

////////////////////////////////////////////////////////////////////////////////
// DB 로 보내는 명령어들
////////////////////////////////////////////////////////////////////////////////
//------------------------------------------------------------------------------
// DB_FRIEND_LIST  :  DB에 친구리스트 요청
// Params  : 친구명
//------------------------------------------------------------------------------
procedure TFriendMgr.OnCmdDBList( UserInfo : TUserInfo );
begin
    UserMgrEngine.InterSendMsg(   stDBServer ,ServerIndex,0,0,0,
                                UserInfo.UserName ,0, DB_FRIEND_LIST ,
                                0,0,0,'' );
end;

{//------------------------------------------------------------------------------
// DB_FRIEND_OWNLIST  :  DB에 친구로 등록된 사람들 리스트 요청
// Params  : 없음
//------------------------------------------------------------------------------
procedure TFriendMgr.OnCmdDBOwnList( UserInfo : TUserInfo );
begin
    g_UserMgr.SendMsgQueue1(   stDBServer ,ServerIndex,0,0,0,
                                UserInfo.UserName ,0, DB_FRIEND_OWNLIST ,
                                0,0,0,'' );
end;
}
//------------------------------------------------------------------------------
// DB_FRIEND_ADD  :  DB에 친구추가
// Params  : 친구명 , 등록상태 , 간단설명
//------------------------------------------------------------------------------
procedure TFriendMgr.OnCmdDBAdd(
    UserInfo    : TUserInfo;
    Friend      : String;
    RegState    : Word;
    Desc        : String);
var
    str : string;
begin
    str := IntToStr(regState) +':'+Friend+':'+Desc +'/';

    UserMgrEngine.InterSendMsg(   stDBServer ,ServerIndex,0,0,0,
                                UserInfo.UserName ,0, DB_FRIEND_ADD ,
                                RegState,0,0,str);
end;

//------------------------------------------------------------------------------
// DB_FRIEND_DELETE  :  DB에 친구삭제
// Params  : 친구명
//------------------------------------------------------------------------------
procedure TFriendMgr.OnCmdDBDelete( UserInfo:TUserInfo ; Friend : String  );
var
    str : string;
begin
    str := Friend+'/';

    UserMgrEngine.InterSendMsg(   stDBServer ,ServerIndex,0,0,0,
                                UserInfo.UserName ,0, DB_FRIEND_DELETE ,
                                0,0,0, str);
end;

//------------------------------------------------------------------------------
// DB_FRIEND_EDIT  :  DB에 친구정보 수정
// Params  : 친구명  , 간단설명
//------------------------------------------------------------------------------
procedure TFriendMgr.OnCmdDBEdit( UserInfo:TUserInfo ; Friend : String ; Desc : String);
var
    str : string;
begin
    str := Friend +':'+Desc+'/';
    UserMgrEngine.InterSendMsg(   stDBServer ,ServerIndex,0,0,0,
                                UserInfo.UserName ,0, DB_FRIEND_EDIT ,
                                0,0,0,str);
end;

////////////////////////////////////////////////////////////////////////////////
// DB 로부터 오는 명령어들
////////////////////////////////////////////////////////////////////////////////
//------------------------------------------------------------------------------
// DBR_FRIEND_LIST  :  DB에서 보내는 친구리스트
// Params  : 친구 리스트
//------------------------------------------------------------------------------
procedure TFriendMgr.OnCmdDBRList( Cmd : TCmdMsg );
var
    ListCount   : integer;
    Friend      : string;
    RegState    : string;
    Desc        : string;
    i           : integer;
    TempStr     : string;
    BodyStr     : string;
begin
    // TO DO : 리스트로 친구정보를 만들어서 클라이언트에 전송
    BodyStr := GetValidStr3(Cmd.body,TempStr, ['/']);

    // 리스트 개수 얻기
    ListCount := Str_ToInt( TempStr , 0);

    for i :=0 to ListCount -1 do
    begin
        // 분리자로 개인요소를 분리한다.
        BodyStr     := GetValidStr3 (BodyStr,TempStr, ['/']);
        // 내부 분리자로 케릭명과 등록정보를 분리한다.
        if ( TempStr <> '') then
        begin
            TempStr := GetValidStr3 (TempStr,RegState , [':']);
            Desc    := GetValidStr3 (TempStr,Friend   , [':']);
            Add( Cmd.pInfo , Friend , Str_ToInt ( RegState ,0 ),Desc );
        end;
    end;

    // 클라이언트로 리스트를 전송할 준비가 되어있다.
    FIsListSendAble := true;

    // 소유자리스트를 요청한다.
//    OnCmdDBOwnList( Cmd.pInfo );

    // 이미 클라이언트가 리스트를 요청했었다면 리스트 전송
    if FWantListFlag then
    begin
        OnSendListToClient( Cmd.pInfo );
    end;


end;

{
//------------------------------------------------------------------------------
// DBR_FRIEND_OWNLIST  :  DB에서 보내는 친구로 등록한사람 리스트
// Params  : 친구로 등록한사람 리스트
//------------------------------------------------------------------------------
procedure TFriendMgr.OnCmdDBROwnList( Cmd : TCmdMsg );
var
    ListCount   : integer;
    Friend      : string;
    i           : integer;
    TempStr     : string;
    BodyStr     : string;
begin
    // TO DO : 리스트로 User를  등록한 사람들에게 접속했음을 전송
    BodyStr := GetValidStr3(Cmd.body,TempStr, ['/']);

    // 리스트 개수 얻기
    ListCount := Str_ToInt( TempStr , 0);

    for i :=0 to ListCount -1 do
    begin
        // 분리자로 개인요소를 분리한다.
        BodyStr     := GetValidStr3 (BodyStr,Friend, ['/']);

        if ( Friend <> '') then
        begin
            OnSendInfoToOthers( Cmd.pInfo , Friend );
        end;
    end;

end;
}
//------------------------------------------------------------------------------
// DBR_FRIEND_RSULT  :  DB에서 보내는 결과값
// Params  : 보낸 명령어 , 결과값
//------------------------------------------------------------------------------
procedure TFriendMgr.OnCmdDBRResult( Cmd : TCmdMsg );
var
    CmdNum  : string;
    ErrCode : string;

begin
    // TO TEST:
    ErrMsg( 'CmdDBRResult[Friend] :'+Cmd.Body );

    CmdNum := GetValidStr3( Cmd.body,ErrCode, ['/'] );

    Case Str_ToInt( CmdNum , 0) of
    DB_FRIEND_LIST      :; // DB 오류
    DB_FRIEND_ADD       :; // Client 에 등록할수 없는 메세지 전달
    DB_FRIEND_DELETE    :; // 오류 또는 주의
    DB_FRIEND_OWNLIST   :; // DB 내부 오류
    DB_FRIEND_EDIT      :; // DB 냬부 오류
    end;

end;


end.
