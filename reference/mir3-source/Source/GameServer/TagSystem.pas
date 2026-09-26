unit TagSystem;

interface

uses
    Classes, CmdMgr , grobal2 , {ElHashList ,} UserSystem , sysutils , HUtil32,
    ObjBase;

const

    MAX_TAG_COUNT       = 30;       // 최대 쪽지 개수
    MAX_TAG_PAGE_COUNT  = 10;       // 페이지당 쪽지 개수
    MAX_REJECTER_COUNT  = 20;       // 최대 거부자 수

type
    // TTagInfo Class Decralations ---------------------------------------------
    TTagInfo  = class ( ICommand )
    private
        FSender     : String;       // 전송자
        FSendDate   : String;       // 전송날짜
        FMsg        : String;       // 전송 내용
        FState      : Integer;      // ( 읽지않음(0) , 읽음(1) , 삭제불가(2) , 삭제됨(3) );
        FDBSaved    : Boolean;      // ( DB 저장됨 , DB 저장안됨 );
        FClient     : Boolean;      // 클라이언트에 전송되었는지 판단
    public
        constructor Create;  override;
        destructor  Destroy; override;

        // 클라이언트에 전송한 쪽지 정보양식을 얻음
        function  GetMsgList : String;
//        procedure OnCmdChange( var Msg : TCmdMsg ) ; override;

        // 내부 멤버 변수에 대한 프로퍼티
        property  Sender      : String  read FSender    Write FSender;
        property  SendDate    : String  read FSendDate  Write FSendDate;
        property  Msg         : String  read FMsg       Write FMsg;
        property  State       : Integer read FState     Write FState;
        property  DBSaved     : Boolean read FDBSaved   Write FDBSaved;
        property  Client      : Boolean read FClient    Write FClient;

    end;
    PTTagInfo = ^TTagInfo;

    // TTagMgr Class Decralations ----------------------------------------------
    TTagMgr = class ( ICommand )
    private
        FItems          : TList; //TElHashList;  // 쪽지를 가지고 있을 해쉬리스트
        FRejecter       : TStringList; //TElHashList;  // 거부자 리스트

        FNotReadCount   : integer;      // 읽지 않은 쪽지 개수

        FIsTagListSendAble : Boolean;   // 쪽지 리스트 준비가 되었는지 검사
        FWantTagListFlag   : Boolean;      // 클라이언트가 리스트를 원함
        FWantTagListPage   : integer;      // 클라이언트가 원하는 리스트 페이지
        FClientGetList     : Boolean;      // 클라이언트가 쪽지 리스트를 가지고 있다

        FIsRejectListSendAble : Boolean;// 거부자 리스트 준비가 되었는지 검사
        FWantRejectListFlag   : Boolean;// 클라이언트가 거부자 리스트를 원함

    public
        constructor Create;  override;
        destructor  Destroy; override;

        procedure   OnUserOpen;
        procedure   OnUserClose;

        //신규 테그번호 생성
        function GenerateSendDate : String;
        // 쪽지 개수 얻기
        function GetTagCount    : Integer;
        // 쪽지를 추가할 수 있는지 검토
        function IsTagAddAble   : Boolean;
        // 검색
        function Find (SendDate : String) : TTagInfo;
        // 추가
        function Add(
            UserInfo    : TUserInfo;
            Sender      : String;
            SendDate    : String;
            State       : Integer;
            Msg         : String
            ): Boolean;
        // 삭제 : 상태를 TAGSTATE_DELETED 로 바꿈
        function  Delete(
            UserInfo    : TUserInfo;
            SendDate    : String;
            var rState  : Integer
            ): Boolean;
        // 상태 변경
        function SetInfo(
            UserInfo    : TUserInfo;
            SendDate    : String;
            var State   : Integer
            ): Boolean;
        // 지정된 날짜의 쪽지 삭제
        procedure RemoveInfo( Date:String );
        // 전체 삭제
        procedure RemoveAll;


        // 거부자 개수
        function GetRejecterCount    : Integer;
        // 거부자를 등록할 수 있나 검토
        function IsRejecterAddAble( Name :String ) : Boolean;
        // 거부자 추가
        function  AddRejecter   ( Rejecter : String ): Boolean;
        // 거부자 삭제
        function  DeleteRejecter( Rejecter : String ): Boolean;
        // 거부자 찾기
        function  FindRejecter  ( Rejecter : String ; pName :String): Boolean;
        // 거부자 찾기
        function  IsRejecter    ( Rejecter : String ): Boolean;
        // 거부자 전체 삭제
        procedure RemoveAllRejecter;

        // 메세지 리스트 보내기
        procedure OnMsgList      ( UserInfo : TUserInfo ; PageNum : Integer );
        procedure OnMsgRejectList( UserInfo : TUserInfo );


        // 명령어 전송받었을때 발생하는 이벤트
        procedure OnCmdChange( var Msg : TCmdMsg ) ; override;

        // 클라이언트에서 오는 명령어들 ........................................
        procedure OnCmdCMAdd            ( Cmd : TCmdMsg );
        procedure OnCmdCMAddDouble      ( Cmd : TCmdMsg );  //sonmg
        procedure OnCmdCMDelete         ( Cmd : TCmdMsg );
        procedure OnCmdCMList           ( Cmd : TCmdMsg );
        procedure OnCmdCMSetInfo        ( Cmd : TCmdMsg );
        procedure OnCmdCMRejectAdd      ( Cmd : TCmdMsg );
        procedure OnCmdCMRejectDelete   ( Cmd : TCmdMsg );
        procedure OnCmdCMRejectList     ( Cmd : TCmdMsg );
        procedure OnCmdCMNotReadCount   ( Cmd : TCmdMsg );

        // 클라이언트로 보내는 명령어들 ........................................
        // 리스트 전송
        procedure OnCmdSMList(
            UserInfo    : TUserInfo;
            PageNum     : Integer;
            ListCount   : Integer;
            TagList     : String
            );
        // 쪽지 상태 전송
        procedure OnCmdSMInfo(
            UserInfo    : TUserInfo;
            SendDate    : String;
            State       : integer
            );
        // 쪽지추가 전송
        procedure OnCmdSMAdd(
            UserInfo    : TUserInfo;
            Sender      : String;
            SendDate    : String;
            State       : integer;
            SendMsg     : String
            );
        // 쪽지 삭제 전송
        procedure OnCmdSMDelete(
            UserInfo    : TUserInfo;
            SendDate    : String;
            State       : Integer
            );
        // 거부자 추가 전송
        procedure OnCmdSMRejectAdd(
            UserInfo    : TUserInfo;
            Rejecter    : String
            );
        // 거부자 삭제 전송
        procedure OnCmdSMRejectDelete(
            UserInfo    : TUserInfo;
            Rejecter    : String
            );
        // 거부자 리스트 전송
        procedure OnCmdSMRejectList(
            UserInfo    : TUserInfo;
            ListCount   : integer;
            RejectList  : String
            );
        // 쪽지 읽지 않은 개수 전송
        procedure OnCmdSMNotReadCount(
            UserInfo    : TUserInfo;
            NotReadCount: integer
            );
        // 클라언트 명령어에 대한 결과값
        procedure OnCmdSMResult(
            UserInfo    : TUserInfo;
            CmdNum      : Word;
            ResultValue : Word
            );

        // 서버간에 전송받는 명령어들 ..........................................
        // 서버가 쪽지 전송받음
        procedure OnCmdISMSend  ( Cmd : TCmdMsg );
        // 서버건 명령에 대한 결과값받음
        procedure OnCmdISMResult( Cmd : TCmdMsg );

        // 서버간에 전송하는 명령어들 ..........................................
        // 서버간에 쪽기 전송
        procedure OnCmdOSMSend(
            UserName    : String;
            SvrIndex    : integer;
            Sender      : String;
            SendDate    : String;
            State       : integer;
            SendMsg     : String
            );
        // 서버간 명령에 대한 결괎 전송
        procedure OnCmdOSMResult(
            UserName    : String;
            SvrIndex    : integer;
            CmdNum      : Word;
            ResultValue : Word
            );

        //DB 로 보내는 명령어들 ................................................
        // DB 에 쪽지 추가
        procedure OnCmdDBAdd(
            UserInfo    : TUserInfo;
            Reciever    : String;
            SendDate    : String;
            State       : integer;
            SendMsg     : String
            );
       // DB 에 쪽지 상태 변경
        procedure OnCmdDBInfo(
            UserInfo    : TUserInfo;
            SendDate    : String;
            State       : integer
            );
        // DB에  쪽지 삭제
        procedure OnCmdDBDelete         ( UserInfo : TUserInfo; SendDate : String );
        // DB에 읽은 쪽지 전부 삭제
        procedure OnCmdDBDeleteAll      ( UserInfo : TUserInfo );
        // DB에 쪽지 리스트 요청
        procedure OnCmdDBList           ( UserInfo : TUserInfo );
        // DB에 거부자 추가
        procedure OnCmdDBRejectAdd      ( UserInfo : TUserInfo ; Rejecter :String);
        // DB에 거부자 삭제
        procedure OnCmdDBRejectDelete   ( UserInfo : TUserInfo ; Rejecter :String);
        // DB에 거부자 리스트 요청
        procedure OnCmdDBRejectList     ( UserInfo : TUserInfo );
        // 읽지않은 쪽지개수 요청
        procedure OnCmdDBNotReadCount   ( UserInfo : TUserInfo );

        // DB 로부터 오는 명령어들 .............................................
        // 쪽지 리스트 받음
        procedure OnCmdDBRList          ( Cmd : TCmdMsg );
        // 거부자 리스트 받음
        procedure OnCmdDBRRejectList    ( Cmd : TCmdMsg );
        // 읽지않은 쪽지 개수 받음
        procedure OnCmdDBRNotReadCount  ( Cmd : TCmdMsg );
        // 결과값 받음
        procedure OnCmdDBRResult        ( Cmd : TCmdMsg );


    end;
    PTagMgr = ^TTagMgr;

implementation
    uses
        svMain , UserMgr;
// TTagInfo ====================================================================
constructor TTagInfo.Create;
begin
    inherited ;
    //TO DO Initialize
    FSender     := '';
    FSendDate   := '';
    FMsg        := '';
    FState      := 0;
    FDBSaved    := false;
    FClient     := false;

end;

destructor  TTagInfo.Destroy;
begin
    // TO DO Free Mem

    inherited;
end;

//------------------------------------------------------------------------------
// 쪽지를 클라이언트에 전송할때 필요한 문자열 만듬
//------------------------------------------------------------------------------
function TTagInfo.GetMsgList : String;
begin
    //상태:날짜:전송한케릭명:"내용"
    Result := IntToStr(FState)+':'+FSendDate +':'+FSender+':'+FMsg;
end;

//------------------------------------------------------------------------------
// 명령어 패치
//------------------------------------------------------------------------------
{
procedure TTagInfo.OnCmdChange( var Msg : TCmdMsg ) ;
begin
    // TODO : 필요시에 명령어를 패치함
end;
}

// TTagMgr Class Decralations ==================================================
constructor TTagMgr.Create;
begin
    inherited ;
    //TO DO Initialize
    FItems                  := TList.Create; //TElHashList.Create;
    FRejecter               := TStringList.Create; //TElHashList.Create;

    FIstagListSendAble         := false;
    FWantTagListFlag           := false;
    FWantTagListPage           := -1;

    FClientGetList          := false;

    FIsRejectListSendAble   := false;  // 거부자 리스트 준비가 되었는지 검사
    FWantRejectListFlag     := false;  // 클라이언트가 거부자 리스트를 원함

    FNotReadCount           := 0;

end;

destructor  TTagMgr.Destroy;
begin
    // TO DO Free Mem

    RemoveAll;
    FItems.Free;

    FRejecter.clear;
    FRejecter.Free;


    inherited;
end;

//------------------------------------------------------------------------------
// 시스템을 가능하게 한다.
//------------------------------------------------------------------------------
procedure TTagMgr.OnUserOpen;
begin

end;

//------------------------------------------------------------------------------
// 시스템을 불가능하게 한다.
//------------------------------------------------------------------------------
procedure TTagMgr.OnUserClose;
begin

end;

//------------------------------------------------------------------------------
// 쪽지 개수 얻기
//------------------------------------------------------------------------------
function TTagMgr.GetTagCount : Integer;
begin
    Result := FItems.Count;
end;

//------------------------------------------------------------------------------
// 쪽지 추가 가능한가 검토
//------------------------------------------------------------------------------
function TTagMgr.IsTagAddAble : Boolean;
begin
   Result := false;

   if GetTagCount < MAX_TAG_COUNT then begin
      Result := true;
   end;
end;

//------------------------------------------------------------------------------
// 쪽지 전송 날짜 생성
//------------------------------------------------------------------------------
function TTagMgr.GenerateSendDate : String;
begin
    Result := FormatDateTime('yymmddhhnnss',Now );
end;

function TTagMgr.Find (SendDate : String) : TTagInfo;
var
   Item   : TTagInfo;
   i      : integer;
begin
   Result := nil;
   for i := 0 to FItems.Count - 1 do begin
       Item := TTagInfo(FItems.Items[i]);
       if Item.FSendDate = SendDate then begin
          Result := Item;
          exit;
       end;
   end;
end;

//------------------------------------------------------------------------------
// 쪽지 추가
//------------------------------------------------------------------------------
function TTagMgr.Add(
   UserInfo    : TUserInfo;
   Sender      : String;
   SendDate    : String;
   State       : Integer;
   Msg         : String
): Boolean;
var
   Info        : TTagInfo;
begin
   Result := false;

   // 쪽지가 추가가능한지 검토한후에
   if IsTagAddAble then begin
      // 쪽지를 하나 만들고
      Info := TTagInfo.Create;

      // 객체가 잘 할당되었으면
      if ( Info <> nil ) then begin

         // 내부 내용을 넣고
         Info.Sender     := Sender;
         Info.SendDate   := SendDate;
         Info.FState     := State;
         Info.Msg        := Msg;

         // 추가
         FItems.Add( Info );   //FItems.Add ( SendDate , Info );

         // 읽지않은 메세지 개수 파악
         if Info.State = TAGSTATE_NOTREAD then begin
             Inc( FNotReadCount );
         end;

         Result := true;
      end; // if ( Info <> nil )...

   end; // if IsTagAddable...
end;

//------------------------------------------------------------------------------
// 쪽지 삭제
//------------------------------------------------------------------------------
function TTagMgr.Delete(
   UserInfo    : TUserInfo;
   SendDate    : String;
   var rState  : Integer
): Boolean;
var
   i       : Integer;
   Info    : TTagInfo;
begin
   Result := false;

   // 쪽지정보를 얻고
   Info := Find(SendDate);            //FItems.Item[SendDate];

   // 정보가 있으면
   if ( Info <> nil ) then begin
      // 삭제 금지 상태면 삭제 금지
      if ( Info.State = TAGSTATE_DONTDELETE ) then begin
         rState := TAGSTATE_DONTDELETE;
         Exit;
      end else begin  // 삭제 가능하면 삭제됐음으로 속성 변경
         Info.State := TAGSTATE_DELETED;
         rState := Info.State;
         Result := true;
         Exit;
      end;
   end;// if ( Info <> nil ) ...

end;

//------------------------------------------------------------------------------
// 상태 변경
// 변경요구 상태 : 0 ( 읽지않음 ) , 1( 읽음 ) , 2 ( 삭제금지 ) , 3 ( 삭제금지 해제)
//------------------------------------------------------------------------------
function TTagMgr.SetInfo(
    UserInfo    : TUserInfo;
    SendDate    : String;
    var state   : Integer
): Boolean;
var
    i   : integer;
    Info: TTagInfo;
begin
    Result := false;

    Info := Find( SendDate ); //FItems.Item[SendDate];

    if Info <> nil then
    begin
        // 쪽지를 읽은경우에는 안읽음 개수를 하나 줄이자
        if (Info.FState = TAGSTATE_NOTREAD ) and
               (State <> TAGSTATE_NOTREAD )
        then
        begin
            if ( FNotReadCount > 0 ) then
            begin
                Dec( FNotReadCount );
            end;
        end;

        // 삭제금지 해제일 경우에는 읽음으로 변경한다.
        if State = TAGSTATE_WANTDELETABLE then
        begin
            State := TAGSTATE_READ;
        end;

        // 스테이트 변경
        Info.FState := State;

        Result := true;
    end;

end;

//------------------------------------------------------------------------------
// 지정된 날짜의 쪽지 삭제
//------------------------------------------------------------------------------
procedure TTagMgr.RemoveInfo( Date:String );
var
    Info    : TTagInfo;
    i       : integer;
begin
    Info := Find( Date ); //FItems.Item[Date];

    if ( Info <> nil ) then
    begin
        i := FItems.IndexOf( Info );
        if i >= 0 then begin
           FItems.Delete(i); //FItems.Delete( Date );
           Info.Free;
           exit;
        end;
    end;

end;
//------------------------------------------------------------------------------
//  내부 쪽지 메모리 전부 삭제
//------------------------------------------------------------------------------
procedure TTagMgr.RemoveAll;
var
    i       : integer;
    Info    : TTagInfo;
begin
    for i := 0 to FItems.Count -1 do
    begin
        Info := FItems.Items[i];
        if ( Info <> nil ) then
        begin
            Info.Free;
        end
    end;

    FItems.Clear;
end;

//------------------------------------------------------------------------------
// 거부자 개수 얻기
//------------------------------------------------------------------------------
function TTagMgr.GetRejecterCount : Integer;
begin
    Result := FRejecter.Count;
end;

//------------------------------------------------------------------------------
// 거부자 추가 가능한가.
//------------------------------------------------------------------------------
function TTagMgr.IsRejecterAddAble( Name : String ) : Boolean;
var
   Str    : String;
begin
    if ( Name <> '' )  and                      // 이름이 있고
       ( false = FindRejecter( Name , Str) ) and     // 이미 들어있지 않고
       ( GetRejecterCount < MAX_REJECTER_COUNT )// 최대 개수를 넘지않아야함
    then
        Result := true
    else
        Result := false;
end;

//------------------------------------------------------------------------------
// 거부자 추가
//------------------------------------------------------------------------------
function  TTagMgr.AddRejecter( Rejecter : String ): Boolean;
var
    pStr    :PString;
begin
    Result := false;

    if IsRejecterAddAble( Rejecter ) then
    begin
//      new (pStr);
//      pStr^ := Rejecter;
        FRejecter.Add ( Rejecter );        //FRejecter.Add ( Rejecter , pStr );
        Result := true;
    end;
end;

//------------------------------------------------------------------------------
// 거부자 삭제
//------------------------------------------------------------------------------
function  TTagMgr.DeleteRejecter(Rejecter : String ): Boolean;
var
    Str  : String;
    i    : integer;
begin
    Result := false;

    if FindRejecter( Rejecter , Str) then
    begin
        i := FRejecter.IndexOf ( Rejecter );
        if i >= 0 then begin
           FRejecter.Delete(i); //FRejecter.Delete ( Rejecter );
//         Dispose( pStr);
           Result := true;
        end;
    end;
end;

//------------------------------------------------------------------------------
// 거부자 찾기
//------------------------------------------------------------------------------
function  TTagMgr.FindRejecter( Rejecter : String ; pName :String) : Boolean;
var
    pStr    : PString;
    i       : Integer;
begin
    pStr   := nil;
    pName  := '';
    Result := false;
    // pStr := FRejecter.Item[Rejecter];
    for i := 0 to FRejecter.Count - 1 do begin
//     pStr := PString(FRejecter.Items[i]);
       if FRejecter.Strings[i] = Rejecter then begin
          pName  := FRejecter.Strings[i];
          Result := true;
          exit;
       end;
    end;
end;

//------------------------------------------------------------------------------
// 거부자 찾기
//------------------------------------------------------------------------------
function  TTagMgr.IsRejecter( Rejecter : String ) : Boolean;
var
    pStr    : PString;
    i       : Integer;
begin
    Result := false;

//  pStr := FRejecter.Item[Rejecter];
    for i := 0 to FRejecter.Count - 1 do begin
//     pStr := PString(FRejecter.Items[i]);
       if FRejecter.Strings[i] = Rejecter then begin
          Result := true;
          exit;
       end;
    end;
end;

//------------------------------------------------------------------------------
// 모든 거부자 메모리를 삭제한다.
//------------------------------------------------------------------------------
procedure  TTagMgr.RemoveAllRejecter;
var
    pStr    : PString;
    i       : Integer;
begin
   {
    for i := 0 to FRejecter.Count - 1 do
    begin
        pStr := FRejecter.Items[i];        //FRejecter.GetByIndex(i);
        if ( pStr <> nil ) then
        begin
            Dispose( pStr );
            pStr := nil;
        end;
    end;
    }
    FRejecter.Clear;
end;

//------------------------------------------------------------------------------
// 명령어 전송받았을 경우 발생하는 이벤트 오버로드됨
//------------------------------------------------------------------------------
procedure TTagMgr.OnCmdChange( var Msg : TCmdMsg ) ;
begin
    case Msg.CmdNum of
    CM_TAG_ADD          :OnCmdCMAdd         ( Msg );
    CM_TAG_ADD_DOUBLE   :OnCmdCMAddDouble   ( Msg );  //sonmg
    CM_TAG_DELETE       :OnCmdCMDelete      ( Msg );
    CM_TAG_SETINFO      :OnCmdCMSetInfo     ( Msg );
    CM_TAG_LIST         :OnCmdCMList        ( Msg );
    CM_TAG_NOTREADCOUNT :OnCmdCMNotReadCount( Msg );
    CM_TAG_REJECT_LIST  :OnCmdCMRejectList  ( Msg );
    CM_TAG_REJECT_ADD   :OnCmdCMRejectAdd   ( Msg );
    CM_TAG_REJECT_DELETE:OnCmdCMRejectDelete( Msg );

    ISM_TAG_Send        :OnCmdISMSend       ( Msg );
    ISM_TAG_RESULT      :OnCmdISMResult     ( Msg );
    DBR_TAG_LIST        :OnCmdDBRList       ( Msg );
    DBR_TAG_REJECT_LIST :OnCmdDBRRejectList ( Msg );
    DBR_TAG_NOTREADCOUNT:OnCmdDBRNotReadCount( Msg );
    DBR_TAG_RESULT      :OnCmdDBRResult     ( Msg );
    end;
end;

//------------------------------------------------------------------------------
// 클라언트에 쪽지 리스트르 전송한다.
//------------------------------------------------------------------------------
procedure TTagMgr.OnMsgList( UserInfo : TUserInfo ; PageNum : Integer );
var
   i           : Integer;
   startnum    : Integer;
   endnum      : Integer;
   listcount   : Integer;
   Cnt         : Integer;
   TempStr     : String;
   taginfo     : TTagInfo;

begin
   listcount := GetTagCount - 1;

   // 페이지 번호가 0 이면 전체전송한다.
   if ( PageNum = 0 )then begin
      startnum    := 0;
      endnum      := listcount;
   end else begin
      startnum    := (PageNum-1)  * MAX_TAG_PAGE_COUNT;
      endnum      := startnum + MAX_TAG_PAGE_COUNT;
   end;

   TempStr     := '';

   // 전송 시작번호가 리스트 크기 안으로 들어오고
   if startnum <= listcount then begin
      // 전송 끝번호가 리스트 크기보다 크면 끝번호로 벼경한다.
      if endnum > listCount then
         endnum := listcount;

      // 시작번호 - 끝번호까지의 내용으로 리스트 구성
      Cnt := 0;
//      for i := startnum to endnum do begin
      for i := endnum downto startnum do begin   //거꾸로
         taginfo := FItems.Items[i];   //FItems.GetByIndex(i);
         TempStr := TempStr + taginfo.GetMsgList + '/';
         Inc(Cnt);
      end;

      // 클라이언트로 전송
      OnCmdSMList( UserInfo , PageNum , Cnt ,TempStr );

      // 클라언트가 리스트를 가지고 있다
      FClientGetList := true;

   end;

end;

//------------------------------------------------------------------------------
// 클라이언트에 거부자 리스트를 전송한다.
//------------------------------------------------------------------------------
procedure TTagMgr.OnMsgRejectList( UserInfo : TUserInfo );
var
    i       : integer;
    Cnt     : Integer;
    TempStr : string;
    pName   : pString;
begin
    // 전송할께 없으면 취소
    if FRejecter.Count = 0 then Exit;

    TempStr := '';
    Cnt     := 0;

    for i := 0 to FRejecter.Count - 1 do
    begin
//        pName := FRejecter.Items[i];   //FRejecter.GetByIndex(i);
//        if ( pName <> nil ) then
//        begin
//            TempStr := TempStr + pName^ +'/';
       TempStr := TempStr + FRejecter.Strings[i] +'/';
       Inc( Cnt );
//        end;

    end;

    OnCmdSMRejectList( UserInfo, Cnt ,TempStr );

end;

////////////////////////////////////////////////////////////////////////////////
// 클라이언트에서 오는 명령어들
////////////////////////////////////////////////////////////////////////////////
//------------------------------------------------------------------------------
// CM_TAG_ADD : 쪽지 추가
// 수신자 / 쪽지내용
//------------------------------------------------------------------------------
procedure TTagMgr.OnCmdCMAdd( Cmd : TCmdMsg );
var
    reciever    : String;
    tagmsg      : String;
    senddate     : String;
    recieverinfo: TUserInfo;
begin
    // 명려어 분석
    tagmsg := GetValidStr3 (Cmd.body,reciever, ['/']);

    senddate := GenerateSendDate;

    // 접속해 있으면 접속자에게 알려준다.
    if UserMgrEngine.InterGetUserInfo( reciever , recieverinfo ) then
    begin
        // 내외부 서버로 전송
        OnCmdOSMSend(   reciever,
                        recieverinfo.ConnState - CONNSTATE_CONNECT_0,
                        Cmd.UserName,
                        senddate,
                        0,
                        tagmsg
                    );
    end;

    // DB 에 저장하자
    OnCmdDBAdd( Cmd.pInfo ,reciever,senddate , 0 , tagmsg );
end;

procedure TTagMgr.OnCmdCMAddDouble( Cmd : TCmdMsg );
var
    receiver    : String;
    receiver2   : String;
    tagmsg      : String;
    senddate     : String;
    receiverinfo: TUserInfo;
    receiverinfo2: TUserInfo;
    hum : TUserHuman;
begin
    // 명령어 분석
    tagmsg := GetValidStr3 (Cmd.body, receiver, ['/']);
    tagmsg := GetValidStr3 (tagmsg, receiver2, ['/']);

    // 보내는 시간 기록.
    senddate := GenerateSendDate;

    /////////////////////////////////
    // 첫번째 수신자에게 전송.
    // 보내는 사람과 받는 사람이 같으면 보내지 않음.(sonmg : 2004/05/03)
    if receiver <> Cmd.UserName then begin
       // 접속해 있으면 접속자에게 알려준다.
       if UserMgrEngine.InterGetUserInfo( receiver , receiverinfo ) then
       begin
           // 내외부 서버로 전송
           OnCmdOSMSend(   receiver,
                           receiverinfo.ConnState - CONNSTATE_CONNECT_0,
                           Cmd.UserName,
                           senddate,
                           0,
                           tagmsg
                       );
       end;

       // 쪽지 전송 메시지 출력
       // 이거 이렇케 쓰면 땡빵인데.. 나중에 고치자 쓰레드 함부로 쓰고 있음
{      TagLock.Enter;
       try

       hum := UserEngine.GetUserHuman( Cmd.UserName );
       if hum <> nil then begin
           hum.SysMsg(receiver + '님에게 쪽지를 전송했습니다.', 0);
       end;

       finally
          TagLock.Leave;
       end;
}
       // DB 에 저장하자
       OnCmdDBAdd( Cmd.pInfo, receiver, senddate , 0 , tagmsg );
    end;

    /////////////////////////////////
    // 두번째 수신자에게 전송.
    if receiver2 <> Cmd.UserName then begin
       if receiver2 = '---' then exit;

       // 접속해 있으면 접속자에게 알려준다.
       if UserMgrEngine.InterGetUserInfo( receiver2 , receiverinfo2 ) then
       begin
           // 내외부 서버로 전송
           OnCmdOSMSend(   receiver2,
                           receiverinfo2.ConnState - CONNSTATE_CONNECT_0,
                           Cmd.UserName,
                           senddate,
                           0,
                           tagmsg
                       );
       end;

       // 쪽지 전송 메시지 출력
       // 이거 이렇케 쓰면 땡빵인데.. 나중에 고치자 쓰레드 함부로 쓰고 있음
{      TagLock.Enter;
       try

       hum := UserEngine.GetUserHuman( Cmd.UserName );
       if hum <> nil then begin
           hum.SysMsg(receiver2 + '님에게 쪽지를 전송했습니다.', 0);
       end;

       finally
           TagLock.Leave;
       end;
}
       // DB 에 저장하자
       OnCmdDBAdd( Cmd.pInfo, receiver2, senddate , 0 , tagmsg );
    end;
end;

//------------------------------------------------------------------------------
// CM_TAG_DELETE    : 쪽지 삭제
// Param    : 쪽지날짜
//------------------------------------------------------------------------------
procedure TTagMgr.OnCmdCMDelete( Cmd : TCmdMsg );
var
    senddate    : string;
    deletemode  : integer;
    rState      : Integer;
    userinfo    : TUserInfo;
begin
    // 명려어 분석
    senddate    := Cmd.body;
    deletemode  := Cmd.Msg.Param;
    userinfo    := Cmd.pInfo;

    case deletemode of
    0 : begin   // 1 개 삭제
            if Delete( Cmd.pInfo , senddate ,rState ) then
            begin

                // DB에 명령어 보내기
                OnCmdDBDelete( userinfo, senddate );

                // 클라이언트에 명령어 보내기
                OnCmdSMDelete(
                    userinfo,
                    senddate,
                    rState
                );

                // 실제로 메모리에서 삭제 
                RemoveInfo( senddate );

            end;
        end;
    1 : begin   // 읽은것 전부 삭제

        end;
    end;

end;

//------------------------------------------------------------------------------
// CM_TAG_LIST    : 쪽지 리스트 요구
// Param    : 페이지 번호
//------------------------------------------------------------------------------
procedure TTagMgr.OnCmdCMList( Cmd : TCmdMsg );
var
   pagenum : integer;
begin
   pagenum := Cmd.Msg.Param;

   // 전송가능하면
   if FIsTagListSendAble then begin
      OnMsgList( Cmd.pInfo , pagenum );
   end else begin
      // 전송이 불가능하다. DB로부터 아직 리스트가 도착하지 않음
      FWantTagListFlag   := true;
      FWantTagListPage   := pagenum;

      // 클릭한순간 읽어오게 변경한다.
      OnCmdDBList( Cmd.pInfo );
   end;

end;

//------------------------------------------------------------------------------
// CM_TAG_EDIT    : 읽은상태 변경 및 삭제 금지 해제
// Param    : 쪽지날짜 ,  쪽지 상태 변경 번호
//------------------------------------------------------------------------------
procedure TTagMgr.OnCmdCMSetInfo( Cmd : TCmdMsg );
var
    tagstate    : integer;
    senddate    : string;
    userinfo    : TUserInfo;
begin
    senddate    := Cmd.body;
    tagstate    := Cmd.Msg.Param;

    userinfo := Cmd.pInfo;

    if SetInfo( userinfo , senddate , tagstate ) then
    begin
        // 클라이언트에 전송
        OnCmdSMInfo(userinfo, senddate, tagstate);
        // DB 에 전송
        OnCmdDBInfo( userinfo,senddate , tagstate );
    end
    else
    begin
        // 오류 전송
        OnCmdSMResult(userinfo , CM_TAG_SETINFO , CR_DONTUPDATE );
    end;
end;

//------------------------------------------------------------------------------
// CM_TAG_REjECT_ADD   : 거부자 추가
// Param    : 거부자이름
//------------------------------------------------------------------------------
procedure TTagMgr.OnCmdCMRejectAdd( Cmd : TCmdMsg );
var
    rejecter    : String;
    userinfo    : TUserInfo;
    rejectinfo  : TUserInfo;
begin
    rejecter    := Cmd.body;
    userinfo    := Cmd.pInfo;

    // 온라인에 있는사람만 거부자로 추가할 수 있다.
    if not UserMgrEngine.InterGetUserInfo( rejecter , rejectinfo ) then
    begin
        OnCmdSMResult( userinfo , CM_TAG_REJECT_ADD , CR_DONTADD );
        Exit;
    end;

    // 거부자 추가
    if AddRejecter( rejecter ) then
    begin
        OnCmdDBRejectAdd( userinfo , Rejecter );
        OnCmdSMRejectAdd( userinfo, rejecter );
    end
    else
    begin
        OnCmdSMResult(userinfo,CM_TAG_REJECT_ADD , CR_DONTADD);
    end;

end;

//------------------------------------------------------------------------------
// CM_TAG_REJECT_DELETE    : 거부자 삭제
// Param    : 삭제할 거부자 이름
//------------------------------------------------------------------------------
procedure TTagMgr.OnCmdCMRejectDelete( Cmd : TCmdMsg );
var
    rejecter    : String;
    userinfo    : TUserInfo;
begin
    rejecter    := Cmd.body;
    userinfo    := Cmd.pInfo;
    if DeleteRejecter( rejecter ) then
    begin
        OnCmdDBRejectDelete( userinfo , Rejecter );
        OnCmdSMRejectDelete( userinfo, rejecter );
    end
    else
    begin
        OnCmdSMResult(userinfo ,CM_TAG_REJECT_DELETE , CR_DONTDELETE);
    end;

end;

//------------------------------------------------------------------------------
// CM_TAG_REJECT_LIST    : 거부자 리스트 요구
// Param    : 없음
//------------------------------------------------------------------------------
procedure TTagMgr.OnCmdCMRejectList( Cmd : TCmdMsg );
var
    userinfo : TUserInfo;
begin
    userinfo    := Cmd.pInfo;
    if FIsRejectListSendAble then
        OnMsgRejectList( userinfo )
    else
    begin
        FWantRejectListFlag := TRUE;
        // OnCmdSMResult(userinfo,CM_TAG_REJECT_LIST , CR_DBWAIT);
    end;

end;

//------------------------------------------------------------------------------
// CM_TAG_NOTREADCOUNT    : 읽지않은 쪽지 개수 요구
// Param    : 없음
//------------------------------------------------------------------------------
procedure TTagMgr.OnCmdCMNotReadCount( Cmd : TCmdMsg );
var
    userinfo : TUserInfo;
begin
    userinfo    := Cmd.pInfo;
    if FIsTagListSendAble then
        OnCmdSMNotReadCount( userinfo, FNotReadCount )
    else
        OnCmdSMResult(userinfo ,CM_TAG_NOTREADCOUNT , CR_DBWAIT);
end;

//==============================================================================
// 클라이언트로 보내는 명령어들
//==============================================================================
//------------------------------------------------------------------------------
// SM_TAG_LIST    : 쪽지 리스트 전송
// Param    : 쪽지 개수 , 쪽지 정보들의 리스트
//------------------------------------------------------------------------------
procedure TTagMgr.OnCmdSMList(
    UserInfo    : TUserInfo;
    PageNum     : Integer;
    ListCount   : Integer;
    TagList     : String
);
var
    str : String;
begin
    str := TagList;

    UserMgrEngine.InterSendMsg (   stClient ,0,
                                UserInfo.GateIdx ,UserInfo.UserGateIdx,UserInfo.UserHandle,
                                UserInfo.UserName,UserInfo.Recog ,
                                SM_TAG_LIST , PageNum,ListCount,0, str);

end;

//------------------------------------------------------------------------------
// SM_TAG_INFO    : 쪽지 상태 정보 전송
// Param    : 쪽지날짜 , 상태정보
//------------------------------------------------------------------------------
procedure TTagMgr.OnCmdSMInfo(
    UserInfo    : TUserInfo;
    SendDate    : String;
    State       : integer
);
var
    str : String;
begin
    str := SendDate;

    UserMgrEngine.InterSendMsg (   stClient ,0,
                                UserInfo.GateIdx  ,UserInfo.UserGateIdx,UserInfo.UserHandle,
                                UserInfo.UserName ,UserInfo.Recog,
                                SM_TAG_INFO , State,0,0, str);

end;

//------------------------------------------------------------------------------
// SM_TAG_ADD    : 쪽지 추가 전송
// Param    : 상태 : 날짜 : 전송자 : 내용
//------------------------------------------------------------------------------
procedure TTagMgr.OnCmdSMAdd(
    UserInfo    : TUserInfo;
    Sender      : String;
    SendDate    : String;
    State       : integer;
    SendMsg     : String
);
var
    str : String;
begin
    //상태: 날짜:전송자:"내용"
    str := IntToStr(State)+':'+SendDate+':'+Sender+':'+SendMsg;
    // pagenum = 0 , sendnum = 1;
    UserMgrEngine.InterSendMsg (   stClient ,0,
                                UserInfo.GateIdx,UserInfo.UserGateIdx,UserInfo.UserHandle,
                                UserInfo.UserName ,UserInfo.Recog,
                                SM_TAG_LIST ,0,1,0, str);

end;

//------------------------------------------------------------------------------
// 쪽지는 실제로 메모리에서 삭제됨으로만 표시되고 DB에는 실제로 삭제시킴
// 따라서 나중에 유저가 재 접속하면 사라지게됨
// +----------------------------------------------------------------------------
// SM_TAG_DELETE    : 쪽지 삭제 정보 전송
// Param    : 쪽지날짜 , 상태정보 ( 삭제됨 으로 변경 )
//------------------------------------------------------------------------------
procedure TTagMgr.OnCmdSMDelete(
    UserInfo    : TUserInfo;
    SendDate    : String;
    State       : Integer
);
var
    str : String;
begin
    //상태: 날짜:전송자:"내용"
    str := SendDate;
    // pagenum = 0 , sendnum = 1;
    UserMgrEngine.InterSendMsg (   stClient ,0,
                                UserInfo.GateIdx  ,UserInfo.UserGateIdx, UserInfo.UserHandle,
                                UserInfo.UserName , UserInfo.Recog ,
                                SM_TAG_INFO ,State,0,0, str);

end;

//------------------------------------------------------------------------------
// SM_TAG_REJECT_LIST   : 거부자 리스트 전송
// Param    : 거부자 개수 , 거부자 리스트
//------------------------------------------------------------------------------
procedure TTagMgr.OnCmdSMRejectList(
    UserInfo    : TUserInfo;
    ListCount   : integer;
    RejectList  : String
);
var
    str : String;
begin
    str := RejectList;

    UserMgrEngine.InterSendMsg (   stClient ,0,
                                UserInfo.GateIdx  ,UserInfo.UserGateIdx,UserInfo.UserHandle,
                                UserInfo.UserName ,UserInfo.Recog,
                                SM_TAG_REJECT_LIST ,ListCount,0,0, str);

end;

//------------------------------------------------------------------------------
// SM_TAG_REJECT_ADD   : 거부자 추가 전송
// Param    : 거부자명
//------------------------------------------------------------------------------
procedure TTagMgr.OnCmdSMRejectAdd(
    UserInfo    : TUserInfo;
    Rejecter    : String
);
var
    str : String;
begin
    str := Rejecter;
    UserMgrEngine.InterSendMsg (   stClient ,0,
                                UserInfo.GateIdx,UserInfo.UserGateIdx,UserInfo.UserHandle,
                                UserInfo.UserName , UserInfo.Recog ,
                                SM_TAG_REJECT_ADD ,0,0,0, str);

end;

//------------------------------------------------------------------------------
// SM_TAG_REJECT_DELETE   : 거부자 삭제 전송
// Param    : 거부자명
//------------------------------------------------------------------------------
procedure TTagMgr.OnCmdSMRejectDelete(
    UserInfo    : TUserInfo;
    Rejecter    : String
);
var
    str : String;
begin
    str := Rejecter;

    UserMgrEngine.InterSendMsg (   stClient ,0,
                                UserInfo.GateIdx  ,UserInfo.UserGateIdx,UserInfo.UserHandle,
                                UserInfo.UserName ,UserInfo.Recog,
                                SM_TAG_REJECT_DELETE ,0,0,0, str);

end;

//------------------------------------------------------------------------------
// SM_TAG_NOTREADCOUNT   : 읽지않은 쪽지 개수 전송
// Param    : 읽지않은 쪽지 개수
//------------------------------------------------------------------------------
procedure TTagMgr.OnCmdSMNotReadCount(
    UserInfo    : TUserInfo;
    NotReadCount: integer
);
begin

    UserMgrEngine.InterSendMsg (   stClient ,0,
                                UserInfo.GateIdx,UserInfo.UserGateIdx,UserInfo.UserHandle,
                                UserInfo.UserName , UserInfo.Recog,
                                SM_TAG_ALARM ,NotReadCount,0,0,'');

end;

//------------------------------------------------------------------------------
// SM_TAG_RESULT   : 클라이언트 명령어에 대한 결과값
// Param    : 전송된 명령어 , 결과값
//------------------------------------------------------------------------------
procedure TTagMgr.OnCmdSMResult(
    UserInfo    : TUserInfo;
    CmdNum      : Word;
    ResultValue : Word
    );
begin

    UserMgrEngine.InterSendMsg (   stClient ,0,
                                UserInfo.GateIdx  ,UserInfo.UserGateIdx,UserInfo.UserHandle,
                                UserInfo.UserName ,UserInfo.Recog,
                                SM_TAG_RESULT ,CmdNum,Resultvalue,0,'');

end;

////////////////////////////////////////////////////////////////////////////////
// 서버간에 전송받는 명령어들
////////////////////////////////////////////////////////////////////////////////
//------------------------------------------------------------------------------
// ISM_TAG_SEND   : 서버간에 쪽지 전송받음
// Param    : 쪽지상태 , 날짜 , 전송자 , 내용
//------------------------------------------------------------------------------
procedure TTagMgr.OnCmdISMSend( Cmd : TCmdMsg );
var
    sender      : String;
    senddate    : String;
    statestr    : String;
    state       : integer;
    sendmsg     : String;
    tempstr     : String;
    userinfo    : TUserInfo;
begin
    // 상태:날짜:전송한케릭명:"내용"
    TempStr := GetValidStr3 (Cmd.body   ,statestr   , [':']);
    TempStr := GetValidStr3 (TempStr    ,SendDate   , [':']);
    SendMsg := GetValidStr3 (TempStr    ,Sender     , [':']);

    userinfo := Cmd.pInfo;
    state    := Str_ToInt( statestr , 0 );

    // 거부자가 아니면
    if not IsRejecter( sender ) then
    begin
        // 쪽지를 추가한다.
        if Add( userinfo , sender , senddate ,state, sendmsg ) then
        begin
            // 크라이언트가 리스트를 전송받았다면 쪽지정보 전송
            if FClientGetList then
            begin
                OnCmdSMAdd( userinfo, sender , senddate , state , sendmsg );
            end;
            // 쪽지왔음 알림 전송
            OnCmdSMNotReadCount( userinfo , FNotReadCount );
        end;

    end;

end;

//------------------------------------------------------------------------------
// ISM_TAG_RESULT   : 서버간에 결과 전송 받음
// Param    : 전송명령어 , 결과값
//------------------------------------------------------------------------------
procedure TTagMgr.OnCmdISMResult( Cmd : TCmdMsg );
begin

end;

////////////////////////////////////////////////////////////////////////////////
// 서버간에 전송하는 명령어들
////////////////////////////////////////////////////////////////////////////////
//------------------------------------------------------------------------------
// ISM_TAG_SEND   : 서버간에 쪽지 전송함
// Param    : 쪽지상태 , 날짜 , 전송자 , 내용
//------------------------------------------------------------------------------
procedure TTagMgr.OnCmdOSMSend(
    UserName    : String;
    SvrIndex    : integer;
    Sender      : String;
    SendDate    : String;
    State       : integer;
    SendMsg     : String
);
var
    str : string;
begin
    // 상태:날짜:전송한케릭명:"내용"
    str := IntToStr(State) +':'+SendDate+':'+Sender+':'+SendMsg;

    UserMgrEngine.InterSendMsg (   stOtherServer ,0,0,0,0,
                                UserName ,0, ISM_TAG_SEND , SvrIndex,0,0, str);

end;

//------------------------------------------------------------------------------
// ISM_TAG_RESULT   : 서버간에 결과 전송함
// Param    : 전송명령어 , 결과값
//------------------------------------------------------------------------------
procedure TTagMgr.OnCmdOSMResult(
    UserName    : String;
    SvrIndex    : integer;
    CmdNum      : Word;
    ResultValue : Word
);
var
    str : string;
begin
    str := IntToStr(CmdNum) +':' +IntToStr(ResultValue);

    UserMgrEngine.InterSendMsg (   stOtherServer ,0,0,0,0,
                                UserName ,0, ISM_TAG_RESULT , SvrIndex,0,0, str);

end;
////////////////////////////////////////////////////////////////////////////////
// DB 로부터 오는 명령어들
////////////////////////////////////////////////////////////////////////////////
//------------------------------------------------------------------------------
// DBR_TAG_LIST   : DB로부터 쪽지 리스트 받음
// Param    : 개수 , 리스트
//------------------------------------------------------------------------------
procedure TTagMgr.OnCmdDBRList( Cmd : TCmdMsg );
var
   tagcountstr : string;
   sender      : String;
   senddate    : String;
   statestr    : String;
   sendmsg     : String;
   tempstr     : String;
   tagstr      : String;
   tagcount    : integer;
   i           : Integer;
   userinfo    : TUserInfo;
begin
   tempstr     := GetValidStr3 (Cmd.body, tagcountstr, ['/']);
   tagcount    := Str_ToInt( tagcountstr , 0 );

   userinfo    := Cmd.pInfo;
   // 가지고있는 모든 리스트틀 지운다.
   RemoveAll;

   for i := 0 to tagcount -1 do begin
      // 쪽지에 관련된넘을 가져온다.
      tempstr := GetValidStr3 (tempstr    ,tagstr, ['/']);

      // 쪽지 인자를 분리한다.
      tagstr  := GetValidStr3 (tagstr     ,statestr, [':']);
      tagstr  := GetValidStr3 (tagstr     ,senddate, [':']);
      sendmsg := GetValidStr3 (tagstr     ,sender  , [':']);

      // 쪽지 추가
      if not Add( userinfo , sender , senddate , Str_ToInt( statestr,0 ), sendmsg ) then begin
         // 추가안되는 이유를 표시하자
//         MainOutMessage('Tag didn''t Added...');
      end;
   end;


    // 리스트 준비가 되었다
    FIsTagListSendAble := true ;

    // 쪽지왔음 알림 전송 2003-08-21 : 메인에서 알려준다.. 수정됨
    // OnCmdSMNotReadCount( userinfo , FNotReadCount );

    // 클라이언트가 리스트를 원함 주자
    if FWantTagListFlag then begin
        // 클라이언트에게 리스틀 보낸후
        OnMsgList( userinfo , FWantTagListPage );
        // 클라이언트에게 보냈음을 셋팅
        FWantTagListFlag   := false;
    end;


end;

//------------------------------------------------------------------------------
// DBR_TAG_REJECT_LIST   : DB로부터 거부자 리스트 받음
// Param    : 개수 , 리스트
//------------------------------------------------------------------------------
procedure TTagMgr.OnCmdDBRRejectList( Cmd : TCmdMsg );
var
    tempstr         : String;
    rejecter        : String;
    rejectcountstr  : String;
    rejectcount     : Integer;
    i               : Integer;
    userinfo        : TUserInfo;
begin
    tempstr         := GetValidStr3 (Cmd.body   ,rejectcountstr, ['/']);
    rejectcount     := Str_ToInt( rejectcountstr ,0 );

    userinfo        := Cmd.pInfo;

    for i := 0 to rejectcount -1 do
    begin
        // 쪽지에 관련된넘을 가져온다.
        tempstr := GetValidStr3 (tempstr    ,rejecter, ['/']);

        if not AddRejecter( rejecter ) then
        begin
            // 추가안되는 이유를 표시하자
        end;
    end;

    // 거부자 리스트 준비가 되었음됩
    FIsRejectListSendAble := true;

    // 클라이언트가 거부자 리스트를 원함
    if FWantRejectListFlag then
    begin
        OnMsgRejectList( userinfo );
        FWantRejectListFlag := false;
    end;


end;

//------------------------------------------------------------------------------
// DBR_TAG_NOTREADCOUNT   : DB로부터 읽지않은 쪽지 개수 받음
// Param    : 개수
//------------------------------------------------------------------------------
procedure TTagMgr.OnCmdDBRNotReadCount( Cmd : TCmdMsg );
var
    notreadcountstr : string;
    userinfo        : TUserInfo;
begin
    notreadcountstr := Cmd.body;
    userinfo        := Cmd.pInfo;

    OnCmdSMNotReadCount( userinfo, Str_ToInt(notreadcountstr,0 ));
end;

//------------------------------------------------------------------------------
// DBR_TAG_RESULT   : DB로부터 결과값 받음
// Param    : 전송한 명령어 결과값
//------------------------------------------------------------------------------
procedure TTagMgr.OnCmdDBRResult( Cmd : TCmdMsg );
var
    CmdNum  : string;
    ErrCode : string;

begin
    // TO TEST:
    ErrMsg( 'CmdDBRResult[Tag] :'+Cmd.Body );

    CmdNum := GetValidStr3 (Cmd.body,ErrCode, ['/']);

    Case Str_ToInt( CmdNum , 0) of
    DB_TAG_ADD          :;
    DB_TAG_DELETE       :;
    DB_TAG_DELETEALL    :;
    DB_TAG_LIST         :;
    DB_TAG_SETINFO      :;
    DB_TAG_REJECT_ADD   :;
    DB_TAG_REJECT_DELETE:;
    DB_TAG_REJECT_LIST  :;
    DB_TAG_NOTREADCOUNT :;
    end;


end;
////////////////////////////////////////////////////////////////////////////////
//DB 로 보내는 명령어들
////////////////////////////////////////////////////////////////////////////////
//------------------------------------------------------------------------------
// DB_TAG_ADD   : DB에 쪽지 추가 전송
// Param    : 상태 , 날짜 , 수신자 , 내용
//------------------------------------------------------------------------------
procedure TTagMgr.OnCmdDBAdd(
    UserInfo    : TUserInfo;
    Reciever    : String;
    SendDate    : String;
    State       : integer;
    SendMsg     : String
);
var
    str :string;
begin

    str := IntToStr(State) +':'+SendDate+':'+Reciever+':'+SendMsg+'/';

    UserMgrEngine.InterSendMsg (   stDBServer ,ServerIndex,0,0,0,
                                UserInfo.UserName ,0, DB_TAG_ADD ,
                                0,0,0,str );

end;

//------------------------------------------------------------------------------
// DB_TAG_INFO   : DB에 쪽지 상태 변경 전송
// Param    : 날짜 , 상태
//------------------------------------------------------------------------------
procedure TTagMgr.OnCmdDBInfo(
    UserInfo    : TUserInfo;
    SendDate    : String;
    State       : integer
);
var
    str :string;
begin

    str := IntToStr(State) +':'+SendDate+'/';

    UserMgrEngine.InterSendMsg (   stDBServer ,ServerIndex,0,0,0,
                                UserInfo.UserName ,0, DB_TAG_SETINFO ,
                                0,0,0,str );

end;

//------------------------------------------------------------------------------
// DB_TAG_DELETE   : DB에 쪽지 삭제 전송
// Param    : 날짜
//------------------------------------------------------------------------------
procedure TTagMgr.OnCmdDBDelete( UserInfo : TUserInfo; SendDate : String );
var
    str :string;
begin
    str := SendDate +'/';
    UserMgrEngine.InterSendMsg (   stDBServer ,ServerIndex,0,0,0,
                                UserInfo.UserName ,0, DB_TAG_DELETE ,
                                0,0,0,str );

end;

//------------------------------------------------------------------------------
// DB_TAG_DELETEALL   : DB에 쪽지 전부삭제 전송 ( 읽지않은것과 삭제금지된것은 제외)
// Param    : 없음
//------------------------------------------------------------------------------
procedure TTagMgr.OnCmdDBDeleteAll( UserInfo : TUserInfo );
begin
    UserMgrEngine.InterSendMsg (   stDBServer ,ServerIndex,0,0,0,
                                UserInfo.UserName ,0, DB_TAG_DELETEALL ,
                                0,0,0,'' );
end;

//------------------------------------------------------------------------------
// DB_TAG_LIST   : DB에 쪽지리스트 요청
// Param    : 없음
//------------------------------------------------------------------------------
procedure TTagMgr.OnCmdDBList( UserInfo : TUserInfo );
begin
    UserMgrEngine.InterSendMsg (   stDBServer ,ServerIndex,0,0,0,
                                UserInfo.UserName ,0, DB_TAG_LIST ,
                                0,0,0,'' );
end;

//------------------------------------------------------------------------------
// DB_TAG_REJECT_ADD   : DB에 거부자 리스트 추가
// Param    : 거부자명
//------------------------------------------------------------------------------
procedure TTagMgr.OnCmdDBRejectAdd( UserInfo : TUserInfo ; Rejecter :String);
var
    str : string;
begin
    str := Rejecter+'/';
    UserMgrEngine.InterSendMsg (   stDBServer ,ServerIndex,0,0,0,
                                UserInfo.UserName ,0, DB_TAG_REJECT_ADD ,
                                0,0,0,str );
end;

//------------------------------------------------------------------------------
// DB_TAG_REJECT_DELETE   : DB에 거부자 리스트 삭제
// Param    : 거부자명
//------------------------------------------------------------------------------
procedure TTagMgr.OnCmdDBRejectDelete( UserInfo : TUserInfo ; Rejecter :String);
var
    str : string;
begin
    str := Rejecter+'/';
    UserMgrEngine.InterSendMsg (   stDBServer ,ServerIndex,0,0,0,
                                UserInfo.UserName ,0, DB_TAG_REJECT_DELETE ,
                                0,0,0,str );

end;

//------------------------------------------------------------------------------
// DB_TAG_REJECT_LIST   : DB에 거부자 리스트 전송 요청
// Param    : 없음
//------------------------------------------------------------------------------
procedure TTagMgr.OnCmdDBRejectList( UserInfo : TUserInfo );
begin
    UserMgrEngine.InterSendMsg (   stDBServer ,ServerIndex,0,0,0,
                                UserInfo.UserName ,0, DB_TAG_REJECT_LIST ,
                                0,0,0,'' );

end;

//------------------------------------------------------------------------------
// DB_TAG_NOTREDCOUNT   : DB에 읽지않은 메세지 수자 요청
// Param    : 없음
//------------------------------------------------------------------------------
procedure TTagMgr.OnCmdDBNotReadCount( UserInfo : TUserInfo );
begin
    UserMgrEngine.InterSendMsg (   stDBServer ,ServerIndex,0,0,0,
                                UserInfo.UserName ,0, DB_TAG_NOTREADCOUNT ,
                                0,0,0,'' );
end;




end.
