unit UserMgrEngn;


interface

uses
  Windows, Messages, SysUtils, Classes, Graphics, Controls, Dialogs,
  UserMgr, CmdMgr , UserSystem , Grobal2;

type

  TUserMgrEngine = class(TThread)
  private
    FUserMgr    : TUserMgr;
  protected
      procedure Execute; override;
  public
    constructor Create;
    destructor Destroy; override;

    function InterGetUserInfo( UserName_ : String ; var UserInfo_ : TUserInfo): Boolean;

    procedure AddUser(
        UserName_   : String;
        Recog_      : Integer;
        ConnState_  : Integer;
        GateIdx_    : Integer;
        UserGateIdx_: Integer;
        UserHandle_ : Integer
        );

    procedure DeleteUser(UserName_ :String);

    procedure InterSendMsg(
        SendTarget  : TSendTarget;
        TargetSvrIdx: Integer;
        GateIdx     : Integer;
        UserGateIdx : Integer;
        UserHandle  : Integer;
        UserName    : String;
        Recog       : Integer;
        Ident       : word;
        Param       : word;
        Tag         : word;
        Series      : word;
        Body        : String
        );

    procedure ExternSendMsg(
        SendTarget  : TSendTarget;
        TargetSvrIdx: Integer;
        GateIdx     : Integer;
        UserGateIdx : Integer;
        UserHandle  : Integer;
        UserName    : String;
        msg         : TDefaultMessage;
        body        : String
        );


    procedure OnDBRead( data : string );

    procedure OnExternInterMsg(
        snum    : integer ;
        Ident   : integer;
        UserName: string ;
        Data    : String
        );
  end;

implementation
uses
    svMain;
//------------------------------------------------------------------------------
// Creator ...
//------------------------------------------------------------------------------
constructor TUserMgrEngine.Create;
begin
   inherited Create (TRUE);
//   FreeOnTerminate := TRUE;

   FUserMgr := TUserMgr.Create;

end;

//------------------------------------------------------------------------------
// Destructor ...
//------------------------------------------------------------------------------
destructor TUserMgrEngine.Destroy;
begin

   FUserMgr.Free;

   inherited Destroy;
end;

//------------------------------------------------------------------------------
// Tread Execute ...
//------------------------------------------------------------------------------
procedure TUserMgrEngine.Execute;
begin
//   Suspend;
   while TRUE do begin
      try
         FUserMgr.RunMsg;

      except
         MainOutMessage ('[UserMgrEngine] raise exception..');
      end;
      sleep (1);
      if Terminated then exit;
   end;
end;

//------------------------------------------------------------------------------
// Add User...
//------------------------------------------------------------------------------
procedure TUserMgrEngine.AddUser(
    UserName_   : String;
    Recog_      : Integer;
    ConnState_  : Integer;
    GateIdx_    : Integer;
    UserGateIdx_: Integer;
    UserHandle_ : Integer
);
begin
    umLock.Enter;
    try
        InterSendMsg( stInterServer , 0 , GateIdx_ , UserGateIdx_, UserHandle_, UserName_ ,
                     Recog_ , ISM_FUNC_USEROPEN , ConnState_ , 0 , 0 , '');
    finally
        umLock.Leave;
    end;
end;
//------------------------------------------------------------------------------
// DelUser...
//------------------------------------------------------------------------------
procedure TUserMgrEngine.DeleteUser(UserName_ :String);
begin
    umLock.Enter;
    try
        InterSendMsg( stInterServer , 0 , 0 , 0, 0, UserName_ , 0 , ISM_FUNC_USERCLOSE , 0 , 0 , 0 , '');
    finally
        umLock.Leave;
    end;
end;
//------------------------------------------------------------------------------
// Internal SendMsg... Don't Use Lock...
//------------------------------------------------------------------------------
procedure TUserMgrEngine.InterSendMsg(
        SendTarget  : TSendTarget;
        TargetSvrIdx: Integer;
        GateIdx     : Integer;
        UserGateIdx : Integer;
        UserHandle  : Integer;
        UserName    : String;
        Recog       : Integer;
        Ident       : word;
        Param       : word;
        Tag         : word;
        Series      : word;
        Body        : String
);
var
    userinfo : TUserInfo;
begin

    if ( SendTarget = stClient) then
    begin
        if not InterGetUserInfo( UserName , userinfo ) then
        begin
            umLock.Enter;
            try
            FUserMgr.ErrMsg( '[USERMGR_ENGINE]Not Exist Object '+UserName );
            finally
            umLock.Leave;
            end;

            Exit;
        end;
    end;


    umLock.Enter;
    try
      FUserMgr.SendMsgQueue1(
          SendTarget  ,
          TargetSvrIdx,
          GateIdx     ,
          UserGateIdx ,
          UserHandle  ,
          UserName    ,
          Recog       ,
          Ident       ,
          Param       ,
          Tag         ,
          Series      ,
          Body
      );
    finally
      umLock.Leave;
    end;

end;

function TUserMgrEngine.InterGetUserInfo( UserName_ : String ; var UserInfo_ : TUserInfo):Boolean;
begin
    Result := FUserMgr.GetuserInfo( UserName_ , UserInfo_ );
end;

//------------------------------------------------------------------------------
// External SendMsg... use Lock
//------------------------------------------------------------------------------
procedure TUserMgrEngine.ExternSendMsg(
        SendTarget  : TSendTarget;
        TargetSvrIdx: Integer;
        GateIdx     : Integer;
        UserGateIdx : Integer;
        UserHandle  : Integer;
        UserName    : String;
        msg         : TDefaultMessage;
        body        : String
    );

begin
    umLock.Enter;

    try
        FUserMgr.SendMsgQueue(
            SendTarget  ,
            TargetSvrIdx,
            GateIdx     ,
            UserGateIdx ,
            UserHandle  ,
            UserName    ,
            msg         ,
            Body
        );
    finally
        umLock.Leave;
    end;
end;

procedure TUserMgrEngine.OnDBRead( data : string );
begin
//    umLock.Enter;
//    try
        FUserMgr.OnDBRead( data );
//    finally
//        umLock.Leave;
//    end;
end;

procedure TUserMgrEngine.OnExternInterMsg(
    snum    : integer ;
    Ident   : integer;
    UserName: string ;
    Data    : String
);
var
    userinfo    :TUserInfo;

begin
    umLock.Enter;
    try

        InterSendMsg(   stInterServer , snum,
                        0 , 0, 0,UserName, 0,
                        Ident ,0, 0, 0, Data );
    finally
        umLock.Leave;
    end;
end;


end.
