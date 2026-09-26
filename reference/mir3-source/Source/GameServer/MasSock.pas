unit MasSock;

interface

uses
  Windows, Messages, SysUtils, Classes, Graphics, Controls, Forms, Dialogs,
  ScktComp;

type
  TUserInfo = record
    SocStr: string;
    Socket: TCustomWinSocket;
  end;
  PTUserInfo = ^TUserInfo;

  TFrmMasSoc = class(TForm)
    MSocket: TServerSocket;
    procedure FormCreate(Sender: TObject);
    procedure MSocketClientConnect(Sender: TObject;
      Socket: TCustomWinSocket);
    procedure MSocketClientDisconnect(Sender: TObject;
      Socket: TCustomWinSocket);
    procedure MSocketClientError(Sender: TObject; Socket: TCustomWinSocket;
      ErrorEvent: TErrorEvent; var ErrorCode: Integer);
    procedure MSocketClientRead(Sender: TObject; Socket: TCustomWinSocket);
    procedure FormDestroy(Sender: TObject);
  private
  public
    UserList: TList;  //List of server (selchr, game server..)
    procedure SendInterServerMsg (msg: word; body: string);
  end;

var
  FrmMasSoc: TFrmMasSoc;

implementation

{$R *.DFM}

procedure TFrmMasSoc.FormCreate(Sender: TObject);
begin
   UserList := TList.Create;
   with MSocket do begin
      Port := 5600;
      Active := TRUE;
   end;
end;

procedure TFrmMasSoc.FormDestroy(Sender: TObject);
begin
   UserList.Free;
end;

procedure TFrmMasSoc.MSocketClientConnect(Sender: TObject;
  Socket: TCustomWinSocket);
var
   p: PTUserInfo;
begin
   new (p);
   p.SocStr := '';
   p.Socket := Socket;
   UserList.Add (p);
end;

procedure TFrmMasSoc.MSocketClientDisconnect(Sender: TObject;
  Socket: TCustomWinSocket);
var
   i: integer;
begin
   for i:=0 to UserList.Count-1 do
      if PTUserInfo(UserList[i]).Socket = Socket then begin
         Dispose (PTUserInfo(UserList[i]));
         UserList.Delete (i);
         break;
      end;
end;

procedure TFrmMasSoc.MSocketClientError(Sender: TObject;
  Socket: TCustomWinSocket; ErrorEvent: TErrorEvent;
  var ErrorCode: Integer);
begin
   ErrorCode := 0;
   Socket.Close;
end;

procedure TFrmMasSoc.MSocketClientRead(Sender: TObject;
  Socket: TCustomWinSocket);
var
   i: integer;
begin
   for i:=0 to UserList.Count-1 do
      if PTUserInfo(UserList[i]).Socket = Socket then begin
         PTUserInfo(UserList[i]).SocStr := PTUserInfo(UserList[i]).SocStr
               + Socket.ReceiveText;
      end;
end;

procedure TFrmMasSoc.SendInterServerMsg (msg: word; body: string);
var
   str: string;
   i: integer;
begin
   str := '(' + IntToStr(msg) + '/' + body + ')';
   for i:=0 to UserList.Count-1 do begin
      if PTUserInfo(UserList[i]).Socket.Connected then
         PTUserInfo(UserList[i]).Socket.SendText (str);
   end;
end;

end.
