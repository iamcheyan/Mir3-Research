unit CmdMgr ;


interface

uses
    Classes,Grobal2 , sysUtils , windows , syncobjs , EDcode , HUtil32;


type
    TSendTarget = (stClient , stInterServer , stOtherServer , stDbServer , stFunc);

    // 명령어 레코드 ...........................................................
    TCmdMsg  = Record
        CmdNum      : integer;
        TagetSvrIdx : integer;
        GateIdx     : integer;
        UserGateIdx : integer;
        Userhandle  : integer;
        SendTarget  : TSendTarget;
        Msg         : TDefaultMessage;
        UserName    : String;
        body        : String;
        pInfo       : pointer;
    end;
    PTCmdMsg = ^TCmdMsg;

    // 명령어 interface ........................................................
    ICommand = class ( TObject)
    public
        constructor Create; virtual;
        destructor  Destroy; override;
        // 명령어 변경됐을때 발생하는이벤트
        procedure   OnCmdChange( var Msg : TCmdMsg ) ; virtual;
        // 테스트를 위해 메세지를 외부로 보이게 함
        procedure   ErrMsg( Msg : String );

    end;

    // 명령어 메니저 ...........................................................
    TCmdMgr  = class ( ICommand )
    private
        FItems              : TList;             // 명령어 리스트

        FDBBuffer           : String;            // DB 에서 온 데이터
        FDBBufferBack       : String;            // DB 에서 온 데이터 백업본
        FDBList             : TStringList;       // DB 에소 온 명령어를 구분해놓음
        FInterCS            : TCriticalSection;
        FExternCS           : TCriticalSection;

        // 내부 명령어 전부 삭제
        procedure  RemoveAll;

        procedure   SendToClient2     ( Msg : TCmdMsg );    // 테스트 루틴
        procedure   SendToClient      ( Msg : TCmdMsg );    // 클라이언트로 전송
        procedure   SendToInterServer ( Msg : TCmdMsg );    // 내부 서버로 전송
        procedure   SendToOtherServer ( Msg : TCmdMsg );    // 외부 서버로 전송
        procedure   SendToDbServer    ( Msg : TCmdMsg );    // DB 서버로 전송

        // 버퍼를 나눈다.
        procedure   DivideBuffer;
        // DB에서 전송된 명령어를 분석한다.
        procedure   PatchDBBuffer;


    public
        constructor Create; override;
        destructor  Destroy; override;

        // 명령어 변경됬을때 발생하는이벤트
//        procedure   OnCmdChange( var Msg : TCmdMsg ) ; virtual;
        // 내부서버시스템으로 메세지 전송
        procedure   SendMsg( Msg : TCmdMsg ); virtual;

        // DB소켓에서 명령어가 도착했을때 버퍼넣어주는 이벤트
        procedure   OnDBRead( ReadBuffer :String );

        // 각종 명령어를 큐에다 넣음
        procedure   SendMsgQueue (
                        SendTarget  : TSendTarget;
                        TargetSvrIdx: Integer;
                        GateIdx     : Integer;
                        UserGateIdx : Integer;
                        UserHandle  : Integer;
                        UserName    : String;
                        msg         : TDefaultMessage;
                        body        : String
                        );
        // 각종 명령어를 큐에다 넣음
        procedure   SendMsgQueue1(
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

        // 명령어 큐에 있는 내용을 실행함
        procedure   RunMsg;
    end;
    PTCmdMgr = ^TCmdMgr;
var
    g_DbUse : Boolean;

implementation
uses
    svMain , RunDB;


//------------------------------------------------------------------------------
// 생성자 정의
//------------------------------------------------------------------------------
constructor ICommand.Create;
begin
    inherited;
end;

//------------------------------------------------------------------------------
// 소멸자 정의
//------------------------------------------------------------------------------
destructor ICommand.Destroy;
begin
    inherited;

end;

//------------------------------------------------------------------------------
// 메세지 전송시에 내부에서 불리는 실제 처리함수 : 가상함수로 구현
//------------------------------------------------------------------------------
procedure ICommand.OnCmdChange( var Msg : TCmdMsg ) ;
begin
    // 상속받은 곳에서 명령어 처리를 구현해 줘야 한다....

end;

//------------------------------------------------------------------------------
// 소스 내부의 에러 메세지 전송
//------------------------------------------------------------------------------
procedure ICommand.ErrMsg( Msg : String );
begin
    // 메모에다 일딴 표신한다. 추후 화일이등에 저장할 수 있게 한다.
    MainOutMessage ( Msg );

end;

//------------------------------------------------------------------------------
// 생성자 정의
//------------------------------------------------------------------------------
constructor TCmdMgr.Create;
begin
    inherited ;
    FItems := TList.Create;
    FDBList:= TStringList.Create;

    FInterCS  := TCriticalSection.Create;
    FExternCS := TCriticalSection.Create;
end;

//------------------------------------------------------------------------------
// 소멸자 정의
//------------------------------------------------------------------------------
destructor TCmdMgr.Destroy;
begin
    inherited;

    RemoveAll;
    FItems.Free;

    FDBList.Clear;
    FDBList.Free;
    FInterCS.Free;
    FExternCS.Free;
end;

//------------------------------------------------------------------------------
//  내부 리스트에 저장된 명령어들을 전부 삭제한다.
//------------------------------------------------------------------------------
procedure TCmdMgr.RemoveAll;
var
    i       : integer;
    pItem   : PTCmdMsg;
begin


    for i := 0 to FItems.Count -1 do
    begin
        pItem := FItems[i];
        if ( pItem <> nil ) then
            Dispose ( pItem );
    end;

    FItems.Clear;


end;

//------------------------------------------------------------------------------
// 즉시 처리되는 메세지 보냄
//------------------------------------------------------------------------------
procedure TCmdMgr.SendMsg( Msg : TCmdMsg );
begin
     case Msg.SendTarget of
      stClient        : SendToClient      ( Msg );
      stInterServer   : SendToInterServer ( Msg );
      stOtherServer   : SendToOtherServer ( Msg );
      stDbServer      : SendToDbServer    ( Msg );
     end;
end;

//------------------------------------------------------------------------------
//  클라이언트로 메세지 전송을 테스트 하기위한 코드 화면에 보여줌
//------------------------------------------------------------------------------
procedure TCmdMgr.SendToClient2( Msg : TCmdMsg );
var
    str     : string;
begin
    str :=
    '['+IntToStr( Msg.Msg.Ident ) + ']'+
    '['+IntToStr( Msg.Msg.Param ) + ']'+
    '['+IntToStr( Msg.Msg.Tag   ) + ']'+
    '['+IntToStr( Msg.Msg.Series) + ']<'+
    Msg.body + '>';

    Msg.Msg.Ident   := SM_SYSMESSAGE ;
    Msg.Msg.Param   := MakeWord(219, 255);
    Msg.Msg.Tag     := 0;
    Msg.Msg.Series  := 1;
    Msg.body        := EncodeString ( str );

    SendToClient( Msg);
end;


//------------------------------------------------------------------------------
//  클라이언트로 메세지 전송
//------------------------------------------------------------------------------
procedure TCmdMgr.SendToClient( Msg : TCmdMsg );
var
   packetlen: integer;
   header: TMsgHeader;
   pbuf: PChar;
   EncodeBody   : String;
begin

    pbuf := nil;


    // Exit Codes...
    if Msg.Userhandle = 0 then Exit;


    // Make Header...
    header.Code         := integer($aa55aa55);
    header.SNumber      := Msg.Userhandle;
    header.UserGateIndex:= Msg.UserGateIdx;
    header.Ident        := GM_DATA;

    // 추가 명령어가 있으면
    if Msg.body <> '' then
    begin
         EncodeBody     := EncodeString(Msg.Body);
         header.Length  := sizeof(TDefaultMessage) + Length(EncodeBody) + 1;
         packetlen      := sizeof(TMsgHeader) + header.Length;
         GetMem (pbuf, packetlen + 4);
         Move (packetlen, pbuf^, 4);
         Move (header, (@pbuf[4])^, sizeof(TMsgHeader));
         Move (Msg.Msg, (@pbuf[4+sizeof(TMsgHeader)])^, sizeof(TDefaultMessage));
         Move ((@EncodeBody[1])^, (@pbuf[4+sizeof(TMsgHeader)+sizeof(TDefaultMessage)])^, Length(EncodeBody)+1);
    end
    else // 추가 명령어가 없으면
    begin
         header.Length  := sizeof(TDefaultMessage);
         packetlen      := sizeof(TMsgHeader) + header.Length;
         GetMem (pbuf, packetlen + 4);
         Move (packetlen, pbuf^, 4);
         Move (header, (@pbuf[4])^, sizeof(TMsgHeader));
         Move (Msg.Msg, (@pbuf[4+sizeof(TMsgHeader)])^, sizeof(TDefaultMessage));
    end;

    fInterCS.Enter;
    try
    // Gate Index = 게이트 접속번호
       RunSocket.SendCmdSocket (Msg.GateIdx, pbuf);

    finally
        fInterCS.Leave;
        // MainOutMessage ('CmdMgr Exception SendSocket..');
    end;



end;

//------------------------------------------------------------------------------
// 내부적으로 처리함
//------------------------------------------------------------------------------
procedure TCmdMgr.SendToInterServer( Msg : TCmdMsg );
begin
   OnCmdChange(Msg);
end;

//------------------------------------------------------------------------------
// 다른 서버로 메세지 전송
//------------------------------------------------------------------------------
procedure TCmdMgr.SendToOtherServer( Msg : TCmdMsg );
var
    str : string;
begin

    str := Msg.UserName +'/' + Msg.body;
    // TO DO : Need Send Message To Other Server
    // 외부적으로도 보내자
    FInterCS.Enter;
    try
        UserEngine.SendInterMsg (Msg.CmdNum, ServerIndex, str);
    finally
    FInterCS.Leave;
    end;

    // 내부적으로로 한번 보내고 //Msg.TagetSvrIdx
    SendMsgQueue( stInterServer , ServerIndex , 0,0,0, Msg.UserName , Msg.msg , Msg.body );

end;

//------------------------------------------------------------------------------
// DB 서버로 메세지 전송
//------------------------------------------------------------------------------
procedure TCmdMgr.SendToDBServer( Msg : TCmdMsg );
var
    str : string;
begin

    str := EncodeMessage (Msg.Msg)+Msg.UserName +'/' + Msg.body;


    FInterCS.Enter;
    try
        FrontEngine.AddDBData (str);
    finally
        FInterCS.Leave;
    end;


    // TO DO : Need Send Message To DB Server
//    while g_DbUse do Sleep(1);
//    SendRDBSocket (0, str);


end;

//------------------------------------------------------------------------------
// 큐에 저장되는 메세지 보냄
//------------------------------------------------------------------------------
procedure TCmdMgr.SendMsgQueue(
        SendTarget  : TSendTarget;
        TargetSvrIdx: Integer;
        GateIdx     : Integer;
        UserGateIdx : Integer;
        UserHandle  : Integer;
        UserName    : String;
        msg         : TDefaultMessage;
        body        : String
);
var
    pItem : PTCmdMsg;
begin


    new ( pItem );

    pItem^.CmdNum       := msg.Ident;

    pItem^.SendTarget   := SendTarget;
    pItem^.TagetSvrIdx  := TargetSvrIdx;
    pItem^.GateIdx      := GateIdx;
    pItem^.UserGateIdx  := UserGateIdx;
    pItem^.Userhandle   := UserHandle;
    pItem^.UserName     := UserName;
    pItem^.msg          := msg;
    pItem^.body         := Body;
    pItem^.pInfo        := nil;

    FItems.Add( pItem );


end;

procedure TCmdMgr.SendMsgQueue1(
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
        Body        : String );
var
    pItem : PTCmdMsg;
begin

    new ( pItem );
    //
    pItem^.msg.Recog := Recog;
    pItem^.msg.Ident := Ident;
    pItem^.msg.Param := Param;
    pItem^.msg.Tag   := Tag;
    pItem^.msg.Series:= Series;

    //
    pItem^.SendTarget   := SendTarget;
    pItem^.CmdNum       := Ident;
    pItem^.TagetSvrIdx  := TargetSvrIdx;
    pItem^.GateIdx      := GateIdx;
    pItem^.UserGateIdx  := UserGateIdx;
    pItem^.UserHandle   := UserHandle;
    pItem^.UserName     := UserName;
    pItem^.body         := Body;
    pItem^.pInfo        := nil;

    FItems.Add( pItem );


end;



//------------------------------------------------------------------------------
// 큐에 저장된 메세지를 처리함
//------------------------------------------------------------------------------
procedure TCmdMgr.RunMsg;
var
    i       : integer;
    Count   : integer;
    pInfo   : PTCmdMsg;
    TempCmdNum : integer;
begin
    TempCmdNum := 0;
    // DB에서 읽어들인것을 명령어로 변환한다.
    try
    PatchDBBuffer;
    except
      on E: Exception do ErrMsg( '[Exception] PatchFBBuffer : '+E.Message);
    end;

    Count := FItems.Count ;
    // 리스트의 앞에서 부터 처리한다.
    // 실행도중 다시 리스트가 쌓일수 있으나 이것은 다음번 처리에 하도록한다.
    For i := 0 To Count -1 do
    begin

        FInterCS.Enter;
        try
            pInfo := nil;
            pInfo := FItems[0];
            FItems.Delete(0);
        finally
            FInterCS.Leave;
        end;

        if ( pInfo <> nil ) then
        begin
            try
            TempCmdNum := pInfo^.CmdNum;
            SendMsg( pInfo^ );

            except
            on E: Exception do ErrMsg( 'FT_EXCEPTION:['+IntToStr(TempCmdNum)+']:'+E.Message);
            end;
            dispose( pInfo );
        end;
    end;

//    FCriticalSection.Leave;

end;

//------------------------------------------------------------------------------
// DB 소켓에서 명령어가 도착하면 이곳의 이벤트를 불러줌
//------------------------------------------------------------------------------
procedure TCmdMgr.OnDBRead( ReadBuffer :String );
begin
    try
    FExternCS.Enter;
        FDBBuffer := FDBBuffer + ReadBuffer;
    finally
    FExternCS.Leave;
    end;

end;

procedure TCmdMgr.DivideBuffer;
var
    EndPosition : integer;
    DataLength  : Integer;
    TempData    : String;
begin
    try
    FExternCS.Enter;
        FDBBufferBack := FDBBufferBack+ FDBBuffer;
        FDBBuffer := '';
    finally
    FExternCS.Leave;
    end;
    // DB 에서 온 데이터를 델리미터(!) 기준으로 자른다.
    // 소켓데이터는 중간에 끊길수 있으므로 버퍼를 삭제하진 않는다.
    while true do
    begin

        EndPosition := Pos ('!', FDBBufferBack );
        if EndPosition > 0 then
        begin
            TempData := FDBBufferBack;
            DataLength  := length(TempData);

            Delete(FDBBufferBack,1,EndPosition );
            Delete(TempData,EndPosition + 1 , DataLength);

//            FExternCS.Enter;
//            try
            FDBList.Add( TempData );
//            finally
//                FExternCS.Leave;
//            end;

        end
        else Break;

    end;

end;
//------------------------------------------------------------------------------
// DB 명령어를 분석한다.
//------------------------------------------------------------------------------
procedure TCmdMgr.PatchDBBuffer;
var
    Str         : String;
    Data        : String;
    ListCount   : Integer;
    len         : Integer;
    certify     : String;
    head        : String;
    Body        : String;
    msg         : TDefaultMessage;
    rmsg        : String;
    i           : Integer;
    username    : string;
    sendcmdnum  : string;
    EndStr      : string;
begin
    //버퍼를 나눈다음에
    DivideBuffer;

    ListCount := FDBList.Count ;
    // 버퍼가 없다.
    if ListCount = 0 then Exit;

    for i := 0 to ListCount -1 do
    begin
        // 맨처음의 것을 얻어서
//        FInterCS.Enter;

//        try
            Str := FDBList[0];
            FDBList.Delete(0);
//        finally
//            FInterCS.Leave;
//        end;

        // 버퍼가 존재하면
        if str <> '' then
        begin
            data := '';
            // 앞뒤 기본 명령어를 분리하고
            str := ArrestStringEx (str, '#', '!', data);

            if data <> '' then
            begin
                data := GetValidStr3 (data, certify, ['/']);
                len := Length (data);

                // certify 가 0인것은 친구 쪽지 시스템 아니면 기존 시스템
                if ( Str_ToInt(certify,0) = 0) then
                begin
                  // 기본 블럭사이즈면 안된다. 모든 명령어에 추가 내용이 붙음
                  if len <> DEFBLOCKSIZE then
                  begin
                     head := Copy (data, 1, DEFBLOCKSIZE);
                     body := Copy (data, DEFBLOCKSIZE+2, Length(data)-DEFBLOCKSIZE - 7);

                     msg  := DecodeMessage ( head );
                     rmsg := DecodeString  ( body ) ;

                     rmsg := GetValidStr3 ( rmsg   , username   , ['/']);
                     rmsg := GetValidStr3 ( rmsg   , sendcmdnum , ['/']);

                     // 유저이름이 없어도 에러다.
                     if username <> '' then
                        SendMsgQueue ( stInterServer , 0 , 0 , 0, 0,username , msg , rmsg );
                  end;
                end; //if Str_ToInt(...
            end; // if Data <> '' ...
        end; // if str <> '' ...
    end; // For i := ...
end;

//------------------------------------------------------------------------------
// 메세지 전송시에 내부에서 불리는 실제 처리함수 : 가상함수로 구현
//------------------------------------------------------------------------------
{
procedure TCmdMgr.OnCmdChange( var Msg : TCmdMsg ) ;
begin
    // 상속받은 곳에서 명령어 처리를 구현해 줘야 한다....

end;
}


end.
