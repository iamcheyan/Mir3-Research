unit ConfirmDlg;

interface

uses
  Windows, Messages, SysUtils, Classes, Graphics, Controls, Forms, Dialogs,
  StdCtrls, ExtCtrls;

type
  TFrmConfirmDlg = class(TForm)
    Panel1: TPanel;
    Memo1: TMemo;
    Button1: TButton;
    Button2: TButton;
  private
    { Private declarations }
  public
    { Public declarations }
    function ExecuteDlg (strlist: TStringlist): Boolean;
  end;

var
  FrmConfirmDlg: TFrmConfirmDlg;

implementation

{$R *.DFM}

function TFrmConfirmDlg.ExecuteDlg (strlist: TStringlist): Boolean;
var
   r: integer;
begin
   Memo1.Lines.Assign (strlist);
   r := ShowModal;
   if r = mrYes then
      Result := TRUE
   else
      Result := FALSE;   
end;


end.
