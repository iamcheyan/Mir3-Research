program Mir3;

uses
  Forms,
  Dialogs,
  IniFiles,
  Windows,
  SysUtils,
  classes,
  shellapi,
  ClMain in 'ClMain.pas' {FrmMain},
  DrawScrn in 'DrawScrn.pas',
  IntroScn in 'IntroScn.pas',
  PlayScn in 'PlayScn.pas',
  MapUnit in 'MapUnit.pas',
  FState in 'FState.pas' {FrmDlg},
  ClFunc in 'ClFunc.pas',
  cliUtil in 'cliUtil.pas',
  DWinCtl in 'DWinCtl.pas',
  magiceff in 'magiceff.pas',
  SoundUtil in 'SoundUtil.pas',
  Actor in 'Actor.pas',
  HerbActor in 'HerbActor.pas',
  AxeMon in 'AxeMon.pas',
  clEvent in 'clEvent.pas',
  HUtil32 in '..\Common\HUtil32.pas',
  Grobal2 in '..\Common\Grobal2.pas',
  SingleInstance in 'SingleInstance.pas',
  MaketSystem in 'MaketSystem.pas',
  RelationShip in 'RelationShip.pas',
  uWilFile in 'uWilFile.pas',
  WIL in 'WIL.pas',
  wmUtil in 'wmUtil.pas',
  CMsg in 'CMsg.pas';

{$R *.RES}

begin
  Application.Initialize;
  Application.Title := 'Legend Of Mir 3 Development';
  Application.MainFormOnTaskBar := True;
  Application.CreateForm(TFrmMain, FrmMain);
  Application.Run;
end.

