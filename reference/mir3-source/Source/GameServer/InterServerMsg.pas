unit InterServerMsg;

interface

uses
  Windows, Messages, SysUtils, Classes, Graphics, Controls, Forms, Dialogs,
  ScktComp, ExtCtrls, IniFiles, MudUtil, HUtil32, Grobal2, MFdbDef,
  EdCode, ObjBase, Guild , UserSystem , CmdMgr , SqlEngn;

const
   MAXSERVER = 10;

type
   TServerShiftUserInfo = record
      UserName: string[14];
      rcd: FDBRecord;
      Certification: integer;
      GroupOwner: string[14];
      GroupMembers: array[0..8] of string[14];  //그룹원은 최대 9명
      BoHearCry: Boolean;
      BoHearWhisper: Boolean;
      BoHearGuildMsg: Boolean;
      BoSysopMode: Boolean;
      BoSuperviserMode: Boolean;
      WhisperBlockNames: array[0..9] of string[14];  //귓속말 차단 캐릭터
      BoSlaveRelax: Boolean;  //부하몹의 휴식상태 (sonmg 2005/01/21)
      Slaves: array[0..4] of TSlaveInfo;
      waittime: longword;  //timeout은 30초
      StatusValue: array[0..STATUSARR_SIZE-1] of byte;  //상승 능력치 값 추가(sonmg 2005/06/03)
      ExtraAbil: array[0..EXTRAABIL_SIZE-1] of byte;  //상승 능력치 값
      ExtraAbilTimes: array[0..EXTRAABIL_SIZE-1] of longword; //일정시간동안, 파괴,마력,도력,공속,체력,마력 상승
      ItemExpPoint: integer; //아이템 경험치
   end;
   PTServerShiftUserInfo = ^TServerShiftUserInfo;

   TServerMsgInfo = record
      Socket: TCustomWinSocket;
      SocData: string;
      //SendData: string;
   end;
   PTServerMsgInfo = ^TServerMsgInfo;


  TFrmSrvMsg = class(TForm)
    MsgServer: TServerSocket;
    procedure FormCreate(Sender: TObject);
    procedure FormDestroy(Sender: TObject);
    procedure MsgServerClientConnect(Sender: TObject;
      Socket: TCustomWinSocket);
    procedure MsgServerClientDisconnect(Sender: TObject;
      Socket: TCustomWinSocket);
    procedure MsgServerClientError(Sender: TObject;
      Socket: TCustomWinSocket; ErrorEvent: TErrorEvent;
      var ErrorCode: Integer);
    procedure MsgServerClientRead(Sender: TObject;
      Socket: TCustomWinSocket);
  private
    PCur: PTServerMsgInfo;
    procedure DecodeSocStr (ps: PTServerMsgInfo);
  public
    WorkHum: TUserHuman;
    ServerArr: array[0..MAXSERVER-1] of TServerMsgInfo;
    procedure Initialize;
    procedure SendSocket (Socket: TCustomWinSocket; str: string);
    procedure SendServerSocket (msgstr: string);
    procedure MsgGetUserServerChange (snum: integer; body: string);
    procedure MsgGetUserChangeServerRecieveOk (snum: integer; body: string);
    procedure MsgGetUserLogon (snum: integer; body: string);
    procedure MsgGetUserLogout (snum: integer; body: string);
    procedure MsgGetWhisper (snum: integer; body: string);
    procedure MsgGetGMWhisper (snum: integer; body: string);
    procedure MsgGetLoverWhisper (snum: integer; body: string);
    procedure MsgGetSysopMsg (snum: integer; body: string);
    procedure MsgGetAddGuild (snum: integer; body: string);
    procedure MsgGetDelGuild (snum: integer; body: string);
    procedure MsgGetReloadGuild (snum: integer; body: string);
    procedure MsgGetGuildMsg (snum: integer; body: string);
    procedure MsgGetGuildWarInfo (snum: integer; body: string);
    procedure MsgGetChatProhibition (snum: integer; body: string);
    procedure MsgGetChatProhibitionCancel (snum: integer; body: string);
    procedure MsgGetChangeCastleOwner (snum: integer; body: string);
    procedure MsgGetReloadCastleAttackers (snum: integer);
    procedure MsgGetReloadAdmin;
    // 2003/08/28 채팅로그
    procedure MsgGetReloadChatLog;
    procedure MsgGetUserMgr(snum: integer; body: string ;Ident_ : Integer);
    procedure MsgGetRelationShipDelete (snum: integer; body: string);
    // 제조 재료 목록 리로드(sonmg)
    procedure MsgGetReloadMakeItemList;
    // 문원소환.
    procedure MsgGetGuildMemberRecall (snum: integer; body: string);
    procedure MsgGetReloadGuildAgit (snum: integer; body: string);
    // 연인
    procedure MsgGetLoverLogin (snum: integer; body: string);
    procedure MsgGetLoverLogout (snum: integer; body: string);
    procedure MsgGetLoverLoginReply (snum: integer; body: string);
    procedure MsgGetLoverKilledMsg (snum: integer; body: string);
    // 소환
    procedure MsgGetRecall (snum: integer; body: string);
    procedure MsgGetRequestRecall (snum: integer; body: string);
    procedure MsgGetRequestLoverRecall (snum: integer; body: string);

    //위탁판매
    procedure MsgGetMarketOpen( WantOpen : Boolean );

    procedure Run;
  end;


var
  FrmSrvMsg: TFrmSrvMsg;

implementation

uses
   svMain, LocalDB ,UserMgr;

{$R *.DFM}


procedure TFrmSrvMsg.FormCreate(Sender: TObject);
begin
   FillChar (ServerArr, sizeof(TServerMsgInfo) * MAXSERVER, #0);
   WorkHum := TUserHuman.Create;
end;

procedure TFrmSrvMsg.FormDestroy(Sender: TObject);
begin
   WorkHum.Free;
end;

procedure TFrmSrvMsg.Initialize;
begin
   with MsgServer do begin
      Active := FALSE;
      Port := MsgServerPort;
      Active := TRUE;
   end;
end;

//--------------------------- 서버 소켓 ----------------------------



procedure TFrmSrvMsg.MsgServerClientConnect(Sender: TObject;
  Socket: TCustomWinSocket);
var
   i: integer;
begin
   for i:=0 to MAXSERVER-1 do begin
      if ServerArr[i].Socket = nil then begin
         ServerArr[i].Socket := Socket;
         ServerArr[i].SocData := '';
         //ServerArr[i].SendData := '';
         Socket.Data := pointer(i);
         break;
      end;
   end;
end;

procedure TFrmSrvMsg.MsgServerClientDisconnect(Sender: TObject;
  Socket: TCustomWinSocket);
var
   i, k: integer;
begin
   for i:=0 to MAXSERVER-1 do begin
      if ServerArr[i].Socket = Socket then begin
         ServerArr[i].Socket := nil;
         ServerArr[i].SocData := '';
         //ServerArr[i].SendData := '';
         break;
      end;
   end;
end;

procedure TFrmSrvMsg.MsgServerClientError(Sender: TObject;
  Socket: TCustomWinSocket; ErrorEvent: TErrorEvent;
  var ErrorCode: Integer);
begin
   ErrorCode := 0;
   Socket.Close;
end;

procedure TFrmSrvMsg.MsgServerClientRead(Sender: TObject;
  Socket: TCustomWinSocket);
var
   i, idx, len: integer;
   p: PChar;
begin
   idx := integer (Socket.Data);
   if idx in [0..MAXSERVER-1] then begin
      if ServerArr[idx].Socket = Socket then begin
         ServerArr[idx].SocData := ServerArr[idx].SocData + Socket.ReceiveText;
      end;
   end;
end;

{-------------------------------------------------------------------}

procedure TFrmSrvMsg.SendSocket (Socket: TCustomWinSocket; str: string);
begin
   if Socket.Connected then
      Socket.SendText ('(' + str + ')');
end;

procedure TFrmSrvMsg.SendServerSocket (msgstr: string);
var
   i: integer;
begin
   for i:=0 to MAXSERVER-1 do begin
      if ServerArr[i].Socket <> nil then begin
         SendSocket (ServerArr[i].Socket, msgstr);
      end;
   end;
end;


{-------------------------------------------------------------------}


procedure TFrmSrvMsg.DecodeSocStr (ps: PTServerMsgInfo);
   procedure SendOtherServer (msgstr: string);
   var
      i: integer;
   begin
      for i:=0 to MAXSERVER-1 do begin
         if ServerArr[i].Socket <> nil then begin
            if ServerArr[i].Socket <> ps.Socket then begin
               SendSocket (ServerArr[i].Socket, msgstr);
            end;
         end;
      end;
   end;
var
   BufStr, str, snumstr, head, body: string;
   ident, snum: integer;
begin
   if Pos(')', ps.SocData) <= 0 then exit;

   try
      BufStr := ps.SocData;
      ps.SocData := '';
      while Pos (')', BufStr) > 0 do begin
         BufStr := ArrestStringEx (BufStr, '(', ')', str);
         if str <> '' then begin
            SendOtherServer (str);
            body := GetValidStr3 (str, head, ['/']);
            body := GetValidStr3 (body, snumstr, ['/']);
            ident := Str_ToInt (head, 0);
            snum := Str_ToInt (DecodeString(snumstr), -1);
            case ident of
               ISM_USERSERVERCHANGE:
                  begin
                     MsgGetUserServerChange (snum, body);
                  end;
               ISM_CHANGESERVERRECIEVEOK:
                  begin
                     MsgGetUserChangeServerRecieveOk (snum, body);
                  end;
               ISM_USERLOGON:
                  begin
                     MsgGetUserLogon (snum, body);
                  end;
               ISM_USERLOGOUT:
                  begin
                     MsgGetUserLogout (snum, body);
                  end;
               ISM_WHISPER:
                  begin
                     MsgGetWhisper (snum, body);
                  end;
               ISM_GMWHISPER:
                  begin
                     MsgGetGMWhisper (snum, body);
                  end;
               ISM_LM_WHISPER:
                  begin
                     MsgGetLoverWhisper (snum, body);
                  end;
               ISM_SYSOPMSG:
                  begin
                     MsgGetSysopMsg (snum, body);
                  end;
               ISM_ADDGUILD:
                  begin
                     MsgGetAddGuild (snum, body);
                  end;
               ISM_DELGUILD:
                  begin
                     MsgGetDelGuild (snum, body);
                  end;
               ISM_RELOADGUILD:
                  begin
                     MsgGetReloadGuild (snum, body);
                  end;
               ISM_GUILDMSG:
                  begin
                     MsgGetGuildMsg (snum, body);
                  end;
               ISM_GUILDWAR:
                  begin
                     MsgGetGuildWarInfo (snum, body);
                  end;
               ISM_CHATPROHIBITION:
                  begin
                     MsgGetChatProhibition (snum, body);
                  end;
               ISM_CHATPROHIBITIONCANCEL:
                  begin
                     MsgGetChatProhibitionCancel (snum, body);
                  end;
               ISM_CHANGECASTLEOWNER:
                  begin
                     MsgGetChangeCastleOwner (snum, body);
                  end;
               ISM_RELOADCASTLEINFO:
                  begin
                     MsgGetReloadCastleAttackers (snum);
                  end;
               ISM_RELOADADMIN:
                  begin
                     MsgGetReloadAdmin;
                  end;
               ISM_MARKETOPEN:
                  begin
                     MsgGetMarketOpen( true );
                  end;
               ISM_MARKETCLOSE:
                  begin
                     MsgGetMarketOpen( false );
                  end;
               // 2003/08/28 채팅로그
               ISM_RELOADCHATLOG:
                  begin
                     MsgGetReloadChatLog;
                  end;
               ISM_LM_DELETE:
                  begin
                     MsgGetRelationshipDelete (snum, body);
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
                     MsgGetUserMgr( snum , body , ident);
                  end;
               // 제조 재료 목록 리로드(sonmg)
               ISM_RELOADMAKEITEMLIST:
                  begin
                     MsgGetReloadMakeItemList;
                  end;
               // 문원소환.
               ISM_GUILDMEMBER_RECALL:
                  begin
                     MsgGetGuildMemberRecall (snum, body);
                  end;
               ISM_RELOADGUILDAGIT:
                  begin
                     MsgGetReloadGuildAgit (snum, body);
                  end;
               // 연인
               ISM_LM_LOGIN:
                  begin
                     MsgGetLoverLogin (snum, body);
                  end;
               ISM_LM_LOGOUT:
                  begin
                     MsgGetLoverLogout (snum, body);
                  end;
               ISM_LM_LOGIN_REPLY:
                  begin
                     MsgGetLoverLoginReply (snum, body);
                  end;
               ISM_LM_KILLED_MSG:
                  begin
                     MsgGetLoverKilledMsg (snum, body);
                  end;
               // 소환
               ISM_RECALL:
                  begin
                     MsgGetRecall (snum, body);
                  end;
               ISM_REQUEST_RECALL:
                  begin
                     MsgGetRequestRecall (snum, body);
                  end;
               ISM_REQUEST_LOVERRECALL:
                  begin
                     MsgGetRequestLoverRecall (snum, body);
                  end;

            end;
         end else
            break;
      end;
      ps.SocData := BufStr + ps.SocData;
   except
      MainOutMessage ('[Exception] FrmIdSoc.DecodeSocStr');
   end;
end;


//다른 서버로 서버 이동을 함.
//Decode(servernumber) + '/' + Decode(filename)(사용자 정보가 기록된 파일)
procedure TFrmSrvMsg.MsgGetUserServerChange (snum: integer; body: string);
var
   ufilename: string;
   i, fhandle, checksum, filechecksum: integer;
   psui: PTServerShiftUserInfo;
   shifttime : longWord;
begin
   shifttime := GetTickCount;

   ufilename := DecodeString(body);
   psui := nil;
   if ServerIndex = snum then begin  //내 서버의 메세지인지
      try
         fhandle := FileOpen (ShareBaseDir + ufilename, fmOpenRead or fmShareDenyNone);
         if fhandle > 0 then begin
            new (psui);
            FileRead (fhandle, psui^, sizeof(TServerShiftUserInfo));
            FileRead (fhandle, filechecksum, sizeof(integer));
            FileClose (fhandle);
         end;
         DeleteFile (ShareBaseDir + ufilename);
         checksum := 0;
         for i:=0 to sizeof(TServerShiftUserInfo)-1 do
            checksum := checksum + pbyte(integer(psui)+i)^;

         if checksum = filechecksum then begin
            UserEngine.AddServerWaitUser (psui);

            //서버 변경 정보를 잘 받았음을 알림
            UserEngine.SendInterServerMsg(IntToStr(ISM_CHANGESERVERRECIEVEOK) + '/' +
                        EncodeString(IntToStr(ServerIndex)) + '/' +   //서버에 상관없이 다 보냄
                        EncodeString(ufilename));

         end else
            Dispose (psui);
      except
         MainOutMessage ('[Exception] MsgGetUserServerChange..');
      end;
   end;

   // TEST_TIME
   if g_TestTime = 14 then
    MainOutMessage( 'LoadShiftTime:'+IntToStr( GetTickCount- ShiftTime ));

end;

procedure TFrmSrvMsg.MsgGetUserChangeServerRecieveOk (snum: integer; body: string);
var
   ufilename: string;
begin
   ufilename := DecodeString(body);

   UserEngine.GetISMChangeServerReceive (ufilename);
end;

procedure TFrmSrvMsg.MsgGetUserLogon (snum: integer; body: string);
var
   uname: string;
begin
   uname := DecodeString(body);
   UserEngine.OtherServerUserLogon (snum, uname);
end;

procedure TFrmSrvMsg.MsgGetUserLogout (snum: integer; body: string);
var
   uname: string;
begin
   uname := DecodeString (body);
   UserEngine.OtherServerUserLogout (snum, uname);
end;

procedure TFrmSrvMsg.MsgGetWhisper (snum: integer; body: string);
var
   msgstr, str, uname: string;
   hum: TUserHuman;
begin
   if snum = ServerIndex then begin
      str := DecodeString (body);
      str := GetValidStr3 (str, uname, ['/']);
      hum := UserEngine.GetUserHuman (uname);
      if hum <> nil then begin
         // 운영자 귓속말 차단
         if not hum.bStealth then
            hum.WhisperRe (str, FALSE);
      end;
   end;
end;

procedure TFrmSrvMsg.MsgGetGMWhisper (snum: integer; body: string);
var
   msgstr, str, uname: string;
   hum: TUserHuman;
begin
   if snum = ServerIndex then begin
      str := DecodeString (body);
      str := GetValidStr3 (str, uname, ['/']);
      hum := UserEngine.GetUserHuman (uname);
      if hum <> nil then begin
         // 운영자 귓속말 차단
         if not hum.bStealth then
            hum.WhisperRe (str, TRUE);
      end;
   end;
end;

procedure TFrmSrvMsg.MsgGetLoverWhisper (snum: integer; body: string);
var
   msgstr, str, uname: string;
   hum: TUserHuman;
begin
   if snum = ServerIndex then begin
      str := DecodeString (body);
      str := GetValidStr3 (str, uname, ['/']);
      hum := UserEngine.GetUserHuman (uname);
      if hum <> nil then begin
         // 운영자 귓속말 차단
         if not hum.bStealth then begin
            hum.LoverWhisperRe (str);
         end;
      end;
   end;
end;

procedure TFrmSrvMsg.MsgGetRelationshipDelete (snum: integer; body: string);
var
   msgstr, str, uname , reqType: string;
   hum: TUserHuman;
begin
   if snum = ServerIndex then begin
      str := DecodeString (body);
      str := GetValidStr3 (str, uname, ['/']);
      str := GetValidStr3 (str, ReqType, ['/']);
      hum := UserEngine.GetUserHuman (uname);
      if hum <> nil then begin
         hum.RelationShipDeleteOther( Str_ToInt (ReqType, 0 ) , uname );
      end;
   end;
end;

procedure TFrmSrvMsg.MsgGetSysopMsg (snum: integer; body: string);
var
   msgstr: string;
begin
   UserEngine.SysMsgAll (DecodeString(body));
end;

procedure TFrmSrvMsg.MsgGetAddGuild (snum: integer; body: string);
var
   gname, mname: string;
begin
   body := DecodeString(body);
   mname := GetValidStr3 (body, gname, ['/']);

   GuildMan.AddGuild (gname, mname);
end;

procedure TFrmSrvMsg.MsgGetDelGuild (snum: integer; body: string);
var
   gname: string;
begin
   gname := DecodeString(body);

   // 장원 반환 후 문파삭제.
//   GuildAgitMan.DelGuildAgit( gname );

   GuildMan.DelGuild (gname);
end;

procedure TFrmSrvMsg.MsgGetReloadGuild (snum: integer; body: string);
var
   gname: string;
   g: TGuild;
begin
   gname := DecodeString(body);
   if snum = 0 then begin  //0번 서버에서 보낸거....
      g := GuildMan.GetGuild (gname);
      if g <> nil then begin
         g.LoadGuild;
         UserEngine.GuildMemberReLogin (g);
      end;
   end else begin  //다른 서버에서 보냄
      if ServerIndex <> snum then begin
         g := GuildMan.GetGuild (gname);
         if g <> nil then begin
            g.LoadGuildFile (gname + '.' + IntToStr(snum));
            UserEngine.GuildMemberReLogin (g);
            g.SaveGuild;  //
         end;
      end;
   end;
end;

procedure TFrmSrvMsg.MsgGetGuildMsg (snum: integer; body: string);
var
   str, gname: string;
   g: TGuild;
begin
   str := DecodeString(body);
   str := GetValidStr3(str, gname, ['/']);
   if (gname <> '') then begin
      g := GuildMan.GetGuild (gname);
      if g <> nil then
         g.GuildMsg (str);
   end;
end;

procedure TFrmSrvMsg.MsgGetGuildWarInfo (snum: integer; body: string);
var
   str, gname, warguildname, starttime, remaintime: string;
   g, warguild: TGuild;
   pgw: PTGuildWarInfo;
   i: integer;
   currenttick: longword;
begin
   if snum = 0 then begin
      str := DecodeString(body);
      str := GetValidStr3(str, gname, ['/']);
      str := GetValidStr3(str, warguildname, ['/']);
      str := GetValidStr3(str, starttime, ['/']);
      remaintime := str;
      if (gname <> '') and (warguildname <> '') then begin
         g := GuildMan.GetGuild (gname);
         warguild := GuildMan.GetGuild (warguildname);
         if (g <> nil) and (warguild <> nil) then begin
            currenttick := GetTickCount;
            if ServerTickDifference = 0 then begin
               ServerTickDifference := StrToInt64(starttime) - Int64(currenttick);
            end;
            pgw := nil;
            for i:=0 to g.KillGuilds.Count-1 do begin
               if PTGuildWarInfo(g.KillGuilds.Objects[i]).WarGuild = warguild then begin
                  pgw := PTGuildWarInfo(g.KillGuilds.Objects[i]);
                  if pgw <> nil then begin
                     pgw.WarGuild := warguild;
                     pgw.WarStartTime := StrToInt64(starttime) - Int64(ServerTickDifference);
                     pgw.WarRemain := StrToInt64(remaintime);
                     MainOutMessage('[문파전(연장)] ' + g.GuildName + '<->' + warguild.GuildName + ', StartTime : ' + starttime + ', remaintime : ' + remaintime + ', WarStartTime : ' + IntToStr(pgw.WarStartTime) + ', differ : ' + IntToStr(ServerTickDifference));
                     break;
                  end;
               end;
            end;
            if pgw = nil then begin
               new (pgw);
               pgw.WarGuild := warguild;
               pgw.WarStartTime := StrToInt64(starttime) - Int64(ServerTickDifference);
               pgw.WarRemain := StrToInt64(remaintime);
               g.KillGuilds.AddObject (warguild.GuildName, TObject(pgw));
               //서버 로그
               MainOutMessage('[문파전(시작)] ' + g.GuildName + '<->' + warguild.GuildName + ', StartTime : ' + starttime + ', remaintime : ' + remaintime + ', WarStartTime : ' + IntToStr(pgw.WarStartTime) + ', differ : ' + IntToStr(ServerTickDifference));
            end;
            g.MemberNameChanged;
            g.GuildInfoChange;
         end;
      end;
   end;
end;

procedure TFrmSrvMsg.MsgGetChatProhibition (snum: integer; body: string);
var
   str, whostr, minstr: string;
begin
   str := DecodeString (body);
   str := GetValidStr3 (str, whostr, ['/']);
   str := GetValidStr3 (str, minstr, ['/']);
   if whostr <> '' then begin
      WorkHum.CmdAddShutUpList (whostr, minstr, FALSE);
   end;
end;

procedure TFrmSrvMsg.MsgGetChatProhibitionCancel (snum: integer; body: string);
var
   str, whostr: string;
begin
   whostr := DecodeString (body);
   if whostr <> '' then begin
      WorkHum.CmdDelShutUpList (whostr, FALSE);
   end;
end;

procedure TFrmSrvMsg.MsgGetChangeCastleOwner (snum: integer; body: string);
var
   str, gldstr: string;
begin
   gldstr := DecodeString (body);
   WorkHum.CmdChangeUserCastleOwner (gldstr, FALSE);
end;

procedure TFrmSrvMsg.MsgGetReloadCastleAttackers (snum: integer);
begin
   UserCastle.LoadAttackerList;
end;

procedure TFrmSrvMsg.MsgGetReloadAdmin;
begin
   FrmDB.LoadAdminFiles;
end;

// 2003/08/28 채팅로그
procedure TFrmSrvMsg.MsgGetReloadChatLog;
begin
   FrmDB.LoadChatLogFiles;
end;


procedure TFrmSrvMsg.MsgGetUserMgr(snum: integer; body: string ; Ident_ : Integer);
var
    username    :string;
    msgbody     :string;
    str         :string;
begin
   str      := DecodeString (body);
   msgbody  := GetValidStr3 (str, username, ['/']);

   UserMgrEngine.OnExternInterMsg( snum , Ident_ , username , msgBody );

end;

// 제조 재료 목록 리로드(sonmg)
procedure TFrmSrvMsg.MsgGetReloadMakeItemList;
begin
   FrmDB.LoadMakeItemList;
end;

//문원소환.
procedure TFrmSrvMsg.MsgGetGuildMemberRecall (snum: integer; body: string);
var
   hum: TUserHuman;
   dx, dy: integer;
   svidx: integer;
   dxstr, dystr, str, uname: string;
begin
   if snum = ServerIndex then begin
      str := DecodeString (body);
      str := GetValidStr3 (str, uname, ['/']);
      str := GetValidStr3 (str, dxstr, ['/']);
      str := GetValidStr3 (str, dystr, ['/']);
      dx := Str_ToInt(dxstr, 0);
      dy := Str_ToInt(dystr, 0);
      hum := UserEngine.GetUserHuman (uname);
      if hum <> nil then begin
         if hum.BoEnableAgitRecall then begin
            hum.SysMsg ('문주님이 ' + hum.UserName + '님을 소환 하셨습니다.', 0); //메시지
            hum.SendRefMsg (RM_SPACEMOVE_HIDE, 0, 0, 0, 0, '');
            hum.SpaceMove (str, dx, dy, 0); //공간이동
         end;
      end;
   end;
end;

procedure TFrmSrvMsg.MsgGetReloadGuildAgit (snum: integer; body: string);
begin
   GuildAgitMan.ClearGuildAgitList;
   GuildAgitMan.LoadGuildAgitList;
end;

procedure TFrmSrvMsg.MsgGetLoverLogin (snum: integer; body: string);
var
   humlover: TUserHuman;
   svidx: integer;
   str, uname, lovername: string;
begin
   if snum = ServerIndex then begin
      str := DecodeString (body);
      str := GetValidStr3 (str, uname, ['/']);
      str := GetValidStr3 (str, lovername, ['/']);
      humlover := UserEngine.GetUserHuman (lovername);
      if humlover <> nil then begin
         humlover.SysMsg(uname + '님이 ' + str + '에 들어오셨습니다.', 6);
         //연인 로그인 메시지를 받으면 나의 위치 정보를 알려줌
         if UserEngine.FindOtherServerUser (uname, svidx) then begin
            UserEngine.SendInterMsg (ISM_LM_LOGIN_REPLY, svidx, lovername + '/' + uname + '/' + humlover.PEnvir.MapTitle);
         end;
      end;
   end;
end;

procedure TFrmSrvMsg.MsgGetLoverLogout (snum: integer; body: string);
var
   hum: TUserHuman;
   svidx: integer;
   str, uname, lovername: string;
begin
   if snum = ServerIndex then begin
      str := DecodeString (body);
      str := GetValidStr3 (str, uname, ['/']);
      lovername := str;
      hum := UserEngine.GetUserHuman (lovername);
      if hum <> nil then begin
         hum.SysMsg(uname + '님이 게임을 종료하였습니다.', 5);

{
         //2005 빼빼로 이벤트
         if hum.LoverPlusAbility then begin
            hum.StatusArr[STATE_TEMPORARY3] := 0;
            hum.StatusArr[STATE_TEMPORARY1] := 60000;
            hum.CharStatus := hum.GetCharStatus;
            hum.CharStatusChanged;
         end;
}
      end;
   end;
end;

procedure TFrmSrvMsg.MsgGetLoverLoginReply (snum: integer; body: string);
var
   humlover: TUserHuman;
   svidx: integer;
   str, uname, lovername: string;
begin
   if snum = ServerIndex then begin
      str := DecodeString (body);
      str := GetValidStr3 (str, uname, ['/']);
      str := GetValidStr3 (str, lovername, ['/']);
      humlover := UserEngine.GetUserHuman (lovername);
      if humlover <> nil then begin
         humlover.SysMsg(uname + '님이 ' + str + '에 계십니다.', 6);
      end;
   end;
end;

procedure TFrmSrvMsg.MsgGetLoverKilledMsg (snum: integer; body: string);
var
   hum: TUserHuman;
   str, uname: string;
begin
   if snum = ServerIndex then begin
      str := DecodeString (body);
      str := GetValidStr3 (str, uname, ['/']);
      hum := UserEngine.GetUserHuman (uname);
      if hum <> nil then begin
         hum.SysMsg(str, 0);
      end;
   end;
end;

// 소환
procedure TFrmSrvMsg.MsgGetRecall (snum: integer; body: string);
var
   hum: TUserHuman;
   dx, dy: integer;
   dxstr, dystr, str, uname: string;
begin
   if snum = ServerIndex then begin
      str := DecodeString (body);
      str := GetValidStr3 (str, uname, ['/']);
      str := GetValidStr3 (str, dxstr, ['/']);
      str := GetValidStr3 (str, dystr, ['/']);
      dx := Str_ToInt(dxstr, 0);
      dy := Str_ToInt(dystr, 0);
      hum := UserEngine.GetUserHuman (uname);
      if hum <> nil then begin
         hum.SendRefMsg (RM_SPACEMOVE_HIDE, 0, 0, 0, 0, '');
         hum.SpaceMove (str, dx, dy, 0); //공간이동
      end;
   end;
end;

procedure TFrmSrvMsg.MsgGetRequestRecall (snum: integer; body: string);
var
   hum: TUserHuman;
   str, uname: string;
begin
   if snum = ServerIndex then begin
      str := DecodeString (body);
      str := GetValidStr3 (str, uname, ['/']);
      hum := UserEngine.GetUserHuman (uname);
      if hum <> nil then begin
         hum.CmdRecallMan( str, '' );
      end;
   end;
end;

procedure TFrmSrvMsg.MsgGetRequestLoverRecall (snum: integer; body: string);
var
   hum: TUserHuman;
   str, uname: string;
begin
   if snum = ServerIndex then begin
      str := DecodeString (body);
      str := GetValidStr3 (str, uname, ['/']);
      hum := UserEngine.GetUserHuman (uname);
      if hum <> nil then begin
         if not hum.PEnvir.NoRecall then begin
            hum.CmdRecallMan( str, '' );
         end;
      end;
   end;
end;

procedure TFrmSrvMsg.MsgGetMarketOpen( WantOpen : Boolean );
begin
   SqlEngine.Open ( WantOpen );
end;
{-------------------------------------------------------------------}

procedure TFrmSrvMsg.Run;
var
   i, len, start: integer;
   ps: PTServerMsgInfo;
begin
   try

   for i:=0 to MAXSERVER-1 do begin
      if ServerArr[i].Socket <> nil then begin
         ps := @ServerArr[i];
         DecodeSocStr (ps);
      end;
   end;

   except
        MainOutMessage('EXCEPT TFrmSrvMsg.Run');
   end;

end;

end.
