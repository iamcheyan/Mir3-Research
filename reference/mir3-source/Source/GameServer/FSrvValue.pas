unit FSrvValue;

interface

uses
  Windows, Messages, SysUtils, Classes, Graphics, Controls, Forms, Dialogs,
  StdCtrls, Buttons, Spin, HUtil32;

type
  TFrmServerValue = class(TForm)
    Label1: TLabel;
    Label2: TLabel;
    Label3: TLabel;
    Label4: TLabel;
    Label5: TLabel;
    EHum: TSpinEdit;
    EMon: TSpinEdit;
    EZen: TSpinEdit;
    ESoc: TSpinEdit;
    ENpc: TSpinEdit;
    BitBtn1: TBitBtn;
    Label6: TLabel;
    EDec: TSpinEdit;
    Label7: TLabel;
    Label8: TLabel;
    ECheckBlock: TSpinEdit;
    ESendBlock: TSpinEdit;
    Label9: TLabel;
    EAvailableBlock: TSpinEdit;
    Label10: TLabel;
    EGateLoad: TSpinEdit;
    CbViewHack: TCheckBox;
    CkViewAdmfail: TCheckBox;
    procedure EHumKeyPress(Sender: TObject; var Key: Char);
  private
  public
    function  Execute: Boolean;
  end;

var
  FrmServerValue: TFrmServerValue;

implementation

uses
   svMain;

{$R *.DFM}


function  TFrmServerValue.Execute: Boolean;
begin
   Result := FALSE;
   EHum.Value := HumLimitTime;
   EMon.Value := MonLimitTime;
   EZen.Value := ZenLimitTime;
   ESoc.Value := SocLimitTime;
   EDec.Value := DecLimitTime;
   ENpc.Value := NpcLimitTime;

   ESendBlock.Value  := SENDBLOCK;
   ECheckBlock.Value := SENDCHECKBLOCK;
   EAvailableBlock.Value := SENDAVAILABLEBLOCK;
   EGateLoad.Value := GATELOAD;
   CbViewHack.Checked := BoViewHackCode;
   CkViewAdmfail.Checked := BoViewAdmissionFail;

   if ShowModal = mrOk then begin
      HumLimitTime := _MIN(150, EHum.Value);
      MonLimitTime := _MIN(150, EMon.Value);
      ZenLimitTime := _MIN(150, EZen.Value);
      SocLimitTime := _MIN(150, ESoc.Value);
      DecLimitTime := _MIN(150, EDec.Value);
      NpcLimitTime := _MIN(150, ENpc.Value);

      SENDBLOCK := _MAX(10, ESendBlock.Value);
      SENDCHECKBLOCK := _MAX(10, ECheckBlock.Value);
      SENDAVAILABLEBLOCK := _MAX(10, EAvailableBlock.Value);
      GATELOAD := EGateLoad.Value;
      BoViewHackCode := CbViewHack.Checked;
      BoViewAdmissionFail := CkViewAdmFail.Checked;
      Result := TRUE;
   end;
end;


procedure TFrmServerValue.EHumKeyPress(Sender: TObject; var Key: Char);
begin
   if Sender is TSpinEdit then
      TSpinEdit(Sender).Value := Str_ToInt(TSpinEdit(Sender).Text, 0);
end;

end.
