unit InterMsgClient;

interface

uses
  Windows, Messages, SysUtils, Classes, Graphics, Controls, Forms, Dialogs,
  ScktComp, ExtCtrls, IniFiles, MudUtil, HUtil32, Grobal2, EdCode,
  InterServerMsg;


type
  TFrmMsgClient = class(TForm)
    MsgClient: TClientSocket;
    procedure MsgClientConnect(Sender: TObject; Socket: TCustomWinSocket);
    procedure MsgClientDisconnect(Sender: TObject;
      Socket: TCustomWinSocket);
    procedure MsgClientError(Sender: TObject; Socket: TCustomWinSocket;
      ErrorEvent: TErrorEvent; var ErrorCode: Integer);
    procedure MsgClientRead(Sender: TObject; Socket: TCustomWinSocket);
  private
    start: longword;
    SocData: string;
    procedure DecodeSocStr;
  public
    procedure Initialize;
    procedure SendSocket (str: string);
    procedure Run;
  end;

var
  FrmMsgClient: TFrmMsgClient;

implementation

uses
   svMain, UserMgr;

{$R *.DFM}


procedure TFrmMsgClient.Initialize;
begin
   with MsgClient do begin
      Active := FALSE;
      Address := MsgServerAddress;
      Port := MsgServerPort;
   end;
   start := GetTickCount;
end;

procedure TFrmMsgClient.MsgClientConnect(Sender: TObject;
  Socket: TCustomWinSocket);
begin
   SocData := '';
end;

procedure TFrmMsgClient.MsgClientDisconnect(Sender: TObject;
  Socket: TCustomWinSocket);
begin
   ;
end;

procedure TFrmMsgClient.MsgClientError(Sender: TObject;
  Socket: TCustomWinSocket; ErrorEvent: TErrorEvent;
  var ErrorCode: Integer);
begin
   ErrorCode := 0;
   Socket.Close;
end;

procedure TFrmMsgClient.MsgClientRead(Sender: TObject;
  Socket: TCustomWinSocket);
begin
   SocData := SocData + Socket.ReceiveText;
end;


procedure TFrmMsgClient.SendSocket (str: string);
begin
   if MsgClient.Socket.Connected then
      MsgClient.Socket.SendText ('(' + str + ')');
end;

procedure TFrmMsgClient.DecodeSocStr;
var
   BufStr, str, head, body, snumstr: string;
   ident, snum: integer;
begin
   if Pos(')', SocData) <= 0 then exit;

   try
      BufStr := SocData;
      SocData := '';
      while Pos (')', BufStr) > 0 do begin
         BufStr := ArrestStringEx (BufStr, '(', ')', str);
         if str <> '' then begin
            body := GetValidStr3 (str, head, ['/']);
            body := GetValidStr3 (body, snumstr, ['/']);
            ident := Str_ToInt (head, 0);
            snum := Str_ToInt (DecodeString(snumstr), -1);
            case ident of
               ISM_USERSERVERCHANGE:
                  begin
                     FrmSrvMsg.MsgGetUserServerChange (snum, body);
                  end;
               ISM_CHANGESERVERRECIEVEOK:
                  begin
                     FrmSrvMsg.MsgGetUserChangeServerRecieveOk (snum, body);
                  end;
               ISM_USERLOGON:
                  begin
                     FrmSrvMsg.MsgGetUserLogon (snum, body);
                  end;
               ISM_USERLOGOUT:
                  begin
                     FrmSrvMsg.MsgGetUserLogout (snum, body);
                  end;
               ISM_WHISPER:
                  begin
                     FrmSrvMsg.MsgGetWhisper (snum, body);
                  end;
               ISM_GMWHISPER:
                  begin
                     FrmSrvMsg.MsgGetGMWhisper (snum, body);
                  end;
               ISM_LM_WHISPER:
                  begin
                     FrmSrvMsg.MsgGetLoverWhisper (snum, body);
                  end;
               ISM_SYSOPMSG:
                  begin
                     FrmSrvMsg.MsgGetSysopMsg (snum, body);
                  end;
               ISM_ADDGUILD:
                  begin
                     FrmSrvMsg.MsgGetAddGuild (snum, body);
                  end;
               ISM_DELGUILD:
                  begin
                     FrmSrvMsg.MsgGetDelGuild (snum, body);
                  end;
               ISM_RELOADGUILD:
                  begin
                     FrmSrvMsg.MsgGetReloadGuild (snum, body);
                  end;
               ISM_GUILDMSG:
                  begin
                     FrmSrvMsg.MsgGetGuildMsg (snum, body);
                  end;
               ISM_GUILDWAR:
                  begin
                     FrmSrvMsg.MsgGetGuildWarInfo (snum, body);
                  end;
               ISM_CHATPROHIBITION:
                  begin
                     FrmSrvMsg.MsgGetChatProhibition (snum, body);
                  end;
               ISM_CHATPROHIBITIONCANCEL:
                  begin
                     FrmSrvMsg.MsgGetChatProhibitionCancel (snum, body);
                  end;
               ISM_CHANGECASTLEOWNER:
                  begin
                     FrmSrvMsg.MsgGetChangeCastleOwner (snum, body);
                  end;
               ISM_RELOADCASTLEINFO:
                  begin
                     FrmSrvMsg.MsgGetReloadCastleAttackers (snum);
                  end;
               ISM_RELOADADMIN:
                  begin
                     FrmSrvMsg.MsgGetReloadAdmin;
                  end;
               ISM_MARKETOPEN:
                  begin
                     FrmSrvMsg.MsgGetMarketOpen( true );
                  end;
               ISM_MARKETCLOSE:
                  begin
                     FrmSrvMsg.MsgGetMarketOpen( false );
                  end;

               // 2003/08/28 채팅로그
               ISM_RELOADCHATLOG:
                  begin
                     FrmSrvMsg.MsgGetReloadChatLog;
                  end;
               ISM_LM_DELETE:
                  begin
                     FrmSrvMsg.MsgGetRelationshipDelete (snum, body);
                  end;

                // 친구 쪽지 관련 내부 서버 메세지
               ISM_USER_INFO    ,
               ISM_FRIEND_INFO  ,
               ISM_FRIEND_DELETE,
               ISM_FRIEND_OPEN  ,
               ISM_FRIEND_CLOSE ,
               ISM_FRIEND_RESULT,
               ISM_TAG_SEND     ,
               ISM_TAG_RESULT   :
                  begin
                     FrmSrvMsg.MsgGetUserMgr( snum , body , ident);
                  end;
               // 제조 재료 목록 리로드(sonmg)
               ISM_RELOADMAKEITEMLIST:
                  begin
                     FrmSrvMsg.MsgGetReloadMakeItemList;
                  end;
               // 문원소환.
               ISM_GUILDMEMBER_RECALL:
                  begin
                     FrmSrvMsg.MsgGetGuildMemberRecall (snum, body);
                  end;
               ISM_RELOADGUILDAGIT:
                  begin
                     FrmSrvMsg.MsgGetReloadGuildAgit (snum, body);
                  end;
               // 연인
               ISM_LM_LOGIN:
                  begin
                     FrmSrvMsg.MsgGetLoverLogin (snum, body);
                  end;
               ISM_LM_LOGOUT:
                  begin
                     FrmSrvMsg.MsgGetLoverLogout (snum, body);
                  end;
               ISM_LM_LOGIN_REPLY:
                  begin
                     FrmSrvMsg.MsgGetLoverLoginReply (snum, body);
                  end;
               ISM_LM_KILLED_MSG:
                  begin
                     FrmSrvMsg.MsgGetLoverKilledMsg (snum, body);
                  end;
               // 소환
               ISM_RECALL:
                  begin
                     FrmSrvMsg.MsgGetRecall (snum, body);
                  end;
               ISM_REQUEST_RECALL:
                  begin
                     FrmSrvMsg.MsgGetRequestRecall (snum, body);
                  end;
               ISM_REQUEST_LOVERRECALL:
                  begin
                     FrmSrvMsg.MsgGetRequestLoverRecall (snum, body);
                  end;

            end;
         end else
            break;
      end;
      SocData := BufStr + SocData;
   except
      MainOutMessage ('[Exception] FrmIdSoc.DecodeSocStr');
   end;
end;

procedure TFrmMsgClient.Run;
begin
   try

   if not MsgClient.Socket.Connected then begin
      if GetTickCount - start > 20 * 1000 then begin
         start := GetTickCount;
         MsgClient.Active := TRUE;
      end;
   end;

   DecodeSocStr;

   except
        MainOutMessage('EXCEPT TFrmClient.Run');
   end;
end;


end.
