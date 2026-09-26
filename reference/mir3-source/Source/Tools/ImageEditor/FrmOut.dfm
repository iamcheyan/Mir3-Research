object FormOut: TFormOut
  Left = 0
  Top = 0
  BorderIcons = [biSystemMenu]
  BorderStyle = bsSingle
  Caption = #23548#20986#25968#25454
  ClientHeight = 212
  ClientWidth = 396
  Color = clBtnFace
  Font.Charset = DEFAULT_CHARSET
  Font.Color = clWindowText
  Font.Height = -12
  Font.Name = #23435#20307
  Font.Style = []
  OldCreateOrder = False
  Position = poMainFormCenter
  PixelsPerInch = 96
  TextHeight = 12
  object GroupBox1: TGroupBox
    Left = 8
    Top = 62
    Width = 153
    Height = 79
    Caption = #32534#21495
    TabOrder = 0
    object Label2: TLabel
      Left = 8
      Top = 22
      Width = 54
      Height = 12
      Caption = #36215#22987#32534#21495':'
    end
    object Label3: TLabel
      Left = 8
      Top = 48
      Width = 54
      Height = 12
      Caption = #32467#26463#32534#21495':'
    end
    object edtIndexStart: TSpinEdit
      Left = 68
      Top = 18
      Width = 69
      Height = 21
      MaxValue = 10000000
      MinValue = 0
      TabOrder = 0
      Value = 9
    end
    object edtIndexEnd: TSpinEdit
      Left = 68
      Top = 45
      Width = 69
      Height = 21
      MaxValue = 10000000
      MinValue = 0
      TabOrder = 1
      Value = 9
    end
  end
  object GroupBox2: TGroupBox
    Left = 9
    Top = 8
    Width = 376
    Height = 48
    Caption = #35774#32622
    TabOrder = 1
    object Label1: TLabel
      Left = 8
      Top = 21
      Width = 54
      Height = 12
      Caption = #20445#23384#20301#32622':'
    end
    object edtSaveDir: TEdit
      Left = 68
      Top = 17
      Width = 257
      Height = 20
      TabOrder = 0
    end
    object Button1: TButton
      Left = 336
      Top = 17
      Width = 29
      Height = 21
      Caption = '...'
      TabOrder = 1
      OnClick = Button1Click
    end
  end
  object GroupBox3: TGroupBox
    Left = 167
    Top = 62
    Width = 218
    Height = 79
    Caption = #36873#39033
    TabOrder = 2
    object Out_Offset: TCheckBox
      Left = 13
      Top = 22
      Width = 73
      Height = 17
      Caption = #23548#20986#22352#26631
      Checked = True
      State = cbChecked
      TabOrder = 0
      OnClick = Out_OffsetClick
    end
    object Out_Format: TCheckBox
      Left = 14
      Top = 45
      Width = 72
      Height = 17
      Caption = #23548#20986#26684#24335
      Checked = True
      State = cbChecked
      TabOrder = 1
    end
    object Out_Alpha: TCheckBox
      Left = 104
      Top = 23
      Width = 73
      Height = 17
      Caption = 'Alpha'#36890#36947
      TabOrder = 2
      OnClick = Out_OffsetClick
    end
    object Out_Clear: TCheckBox
      Left = 104
      Top = 46
      Width = 97
      Height = 17
      Caption = #28165#31354#20445#23384#30446#24405
      TabOrder = 3
      OnClick = Out_OffsetClick
    end
  end
  object btnGo: TButton
    Left = 215
    Top = 161
    Width = 80
    Height = 25
    Caption = #25191#34892'(&G)'
    TabOrder = 3
    OnClick = btnGoClick
  end
  object btnExit: TButton
    Left = 305
    Top = 161
    Width = 80
    Height = 25
    Cancel = True
    Caption = #36864#20986'(&E)'
    Default = True
    ModalResult = 2
    TabOrder = 4
  end
  object ProgressBar: TProgressBar
    Left = 0
    Top = 200
    Width = 396
    Height = 12
    Align = alBottom
    TabOrder = 5
    ExplicitTop = 203
    ExplicitWidth = 393
  end
  object RadioGroupImageFormat: TRadioGroup
    Left = 8
    Top = 147
    Width = 193
    Height = 42
    Caption = #36755#20986#26684#24335
    Columns = 4
    Items.Strings = (
      'BMP'
      'PNG'
      'TGA'
      'DDS')
    TabOrder = 6
  end
end
