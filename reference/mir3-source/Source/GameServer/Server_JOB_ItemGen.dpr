program Server_JOB_ItemGen;

uses
  Forms,
  svMain in 'svMain.pas' {FrmMain},
  RunSock in 'RunSock.pas',
  FrnEngn in 'FrnEngn.pas',
  UsrEngn in 'UsrEngn.pas',
  ObjBase in 'ObjBase.pas',
  Envir in 'Envir.pas',
  M2Share in 'M2Share.pas',
  ObjMon in 'ObjMon.pas',
  RunDB in 'RunDB.pas',
  LocalDB in 'LocalDB.pas' {FrmDB},
  IdSrvClient in 'IdSrvClient.pas' {FrmIDSoc},
  ObjNpc in 'ObjNpc.pas',
  itmunit in 'itmunit.pas',
  Magic in 'Magic.pas',
  NoticeM in 'NoticeM.pas',
  ObjGuard in 'ObjGuard.pas',
  ObjMon2 in 'ObjMon2.pas',
  ObjAxeMon in 'ObjAxeMon.pas',
  Guild in 'Guild.pas',
  Mission in 'Mission.pas',
  Event in 'Event.pas',
  FSrvValue in 'FSrvValue.pas' {FrmServerValue},
  InterServerMsg in 'InterServerMsg.pas' {FrmSrvMsg},
  InterMsgClient in 'InterMsgClient.pas' {FrmMsgClient},
  Castle in 'Castle.pas',
  EDcode in '..\Common\EDCode.pas',
  MfdbDef in '..\Common\MfdbDef.pas',
  mudutil in '..\Common\mudutil.pas',
  Grobal2 in '..\Common\Grobal2.pas',
  FriendSystem in 'FriendSystem.pas',
  TagSystem in 'TagSystem.pas',
  UserSystem in 'UserSystem.pas',
  CmdMgr in 'CmdMgr.pas',
  UserMgr in 'UserMgr.pas',
  UserMgrEngn in 'UserMgrEngn.pas',
  Relationship in 'Relationship.pas',
  DragonSystem in 'DragonSystem.pas',
  SQLLocalDB in 'SQLLocalDB.pas',
  ObjMon3 in 'ObjMon3.pas',
  MaketSystem in 'MaketSystem.pas',
  DBSQL in 'DBSQL.pas',
  SqlEngn in 'SqlEngn.pas';

{$R *.RES}

begin
  Application.Initialize;
  Application.CreateForm(TFrmMain, FrmMain);
  Application.CreateForm(TFrmDB, FrmDB);
  Application.CreateForm(TFrmIDSoc, FrmIDSoc);
  Application.CreateForm(TFrmServerValue, FrmServerValue);
  Application.CreateForm(TFrmSrvMsg, FrmSrvMsg);
  Application.CreateForm(TFrmMsgClient, FrmMsgClient);
  Application.Run;
end.
