program ImageEditor;

uses
  Forms,
  FrmMain in 'FrmMain.pas' {FormMain},
  ZShare in 'ZShare.pas',
  FrmAdd in 'FrmAdd.pas' {FormAdd},
  FrmDel in 'FrmDel.pas' {FormDel},
  FrmOut in 'FrmOut.pas' {FormOut},
  FrmAlpha in 'FrmAlpha.pas' {frmConvertDlg},
  WIL in 'WIL.pas',
  wmMyImage in 'wmMyImage.pas',
  wmM3Def in 'wmM3Def.pas';

{$R *.res}

begin
  Application.Initialize;
  Application.MainFormOnTaskbar := True;
  Application.CreateForm(TFormMain, FormMain);
  Application.CreateForm(TFormAdd, FormAdd);
  Application.CreateForm(TFormDel, FormDel);
  Application.CreateForm(TFormOut, FormOut);
  Application.CreateForm(TfrmConvertDlg, frmConvertDlg);
  Application.Run;
end.
