object FrmServerValue: TFrmServerValue
  Left = 502
  Top = 327
  BorderStyle = bsDialog
  Caption = 'Adjust Server Settings'
  ClientHeight = 229
  ClientWidth = 397
  Color = clBtnFace
  Font.Charset = DEFAULT_CHARSET
  Font.Color = clWindowText
  Font.Height = -11
  Font.Name = 'MS Sans Serif'
  Font.Style = []
  OldCreateOrder = False
  Position = poDesktopCenter
  PixelsPerInch = 96
  TextHeight = 13
  object Label1: TLabel
    Left = 40
    Top = 16
    Width = 72
    Height = 13
    Caption = 'Hum Limit Time'
  end
  object Label2: TLabel
    Left = 40
    Top = 40
    Width = 71
    Height = 13
    Caption = 'Mon Limit Time'
  end
  object Label3: TLabel
    Left = 40
    Top = 64
    Width = 69
    Height = 13
    Caption = 'Zen Limit Time'
  end
  object Label4: TLabel
    Left = 40
    Top = 88
    Width = 69
    Height = 13
    Caption = 'Soc Limit Time'
  end
  object Label5: TLabel
    Left = 40
    Top = 136
    Width = 70
    Height = 13
    Caption = 'Npc Limit Time'
  end
  object Label6: TLabel
    Left = 40
    Top = 112
    Width = 70
    Height = 13
    Caption = 'Dec Limit Time'
  end
  object Label7: TLabel
    Left = 208
    Top = 40
    Width = 84
    Height = 13
    Caption = 'Check Block Size'
  end
  object Label8: TLabel
    Left = 208
    Top = 16
    Width = 87
    Height = 13
    Caption = 'Socket Block Size'
  end
  object Label9: TLabel
    Left = 208
    Top = 64
    Width = 73
    Height = 13
    Caption = 'Available Block'
  end
  object Label10: TLabel
    Left = 200
    Top = 104
    Width = 97
    Height = 13
    Caption = 'Gate Load Test (KB)'
  end
  object EHum: TSpinEdit
    Left = 124
    Top = 13
    Width = 47
    Height = 22
    MaxValue = 0
    MinValue = 0
    TabOrder = 0
    Value = 0
    OnKeyPress = EHumKeyPress
  end
  object EMon: TSpinEdit
    Left = 124
    Top = 37
    Width = 47
    Height = 22
    MaxValue = 0
    MinValue = 0
    TabOrder = 1
    Value = 0
  end
  object EZen: TSpinEdit
    Left = 124
    Top = 61
    Width = 47
    Height = 22
    MaxValue = 0
    MinValue = 0
    TabOrder = 2
    Value = 0
  end
  object ESoc: TSpinEdit
    Left = 124
    Top = 85
    Width = 47
    Height = 22
    MaxValue = 0
    MinValue = 0
    TabOrder = 3
    Value = 0
  end
  object ENpc: TSpinEdit
    Left = 124
    Top = 133
    Width = 47
    Height = 22
    MaxValue = 0
    MinValue = 0
    TabOrder = 5
    Value = 0
  end
  object BitBtn1: TBitBtn
    Left = 296
    Top = 184
    Width = 75
    Height = 25
    TabOrder = 10
    Kind = bkOK
  end
  object EDec: TSpinEdit
    Left = 124
    Top = 109
    Width = 47
    Height = 22
    MaxValue = 0
    MinValue = 0
    TabOrder = 4
    Value = 0
  end
  object ECheckBlock: TSpinEdit
    Left = 308
    Top = 37
    Width = 59
    Height = 22
    MaxValue = 0
    MinValue = 0
    TabOrder = 7
    Value = 0
  end
  object ESendBlock: TSpinEdit
    Left = 308
    Top = 13
    Width = 59
    Height = 22
    MaxValue = 0
    MinValue = 0
    TabOrder = 6
    Value = 0
  end
  object EAvailableBlock: TSpinEdit
    Left = 308
    Top = 61
    Width = 59
    Height = 22
    MaxValue = 0
    MinValue = 0
    TabOrder = 8
    Value = 0
  end
  object EGateLoad: TSpinEdit
    Left = 308
    Top = 101
    Width = 71
    Height = 22
    MaxValue = 0
    MinValue = 0
    TabOrder = 9
    Value = 0
  end
  object CbViewHack: TCheckBox
    Left = 40
    Top = 176
    Width = 129
    Height = 17
    Caption = 'View 1100X message'
    Checked = True
    State = cbChecked
    TabOrder = 11
  end
  object CkViewAdmfail: TCheckBox
    Left = 40
    Top = 192
    Width = 177
    Height = 17
    Caption = 'View Admission failure message'
    TabOrder = 12
  end
end
