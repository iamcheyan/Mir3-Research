object FrmMain: TFrmMain
  Left = 812
  Top = 315
  Caption = 'FrmMain'
  ClientHeight = 363
  ClientWidth = 404
  Color = clBtnFace
  Font.Charset = DEFAULT_CHARSET
  Font.Color = clWindowText
  Font.Height = -11
  Font.Name = 'MS Sans Serif'
  Font.Style = []
  OldCreateOrder = False
  Position = poScreenCenter
  OnCloseQuery = FormCloseQuery
  OnCreate = FormCreate
  OnDestroy = FormDestroy
  PixelsPerInch = 96
  TextHeight = 13
  object Memo1: TMemo
    Left = 0
    Top = 0
    Width = 404
    Height = 255
    Align = alClient
    ImeName = #20013#25991'('#31616#20307') - '#25628#29399#25340#38899#36755#20837#27861
    ScrollBars = ssVertical
    TabOrder = 0
  end
  object Panel1: TPanel
    Left = 0
    Top = 255
    Width = 404
    Height = 108
    Align = alBottom
    BevelOuter = bvNone
    Caption = ' '
    TabOrder = 1
    OnDblClick = Panel1DblClick
    ExplicitTop = 223
    ExplicitWidth = 385
    object LbRunTime: TLabel
      Left = 160
      Top = 0
      Width = 55
      Height = 13
      Caption = 'LbRunTime'
    end
    object LbUserCount: TLabel
      Left = 319
      Top = 0
      Width = 28
      Height = 13
      Alignment = taRightJustify
      Caption = 'Count'
    end
    object Label1: TLabel
      Left = 0
      Top = 0
      Width = 32
      Height = 13
      Caption = 'Label1'
    end
    object Label2: TLabel
      Left = 0
      Top = 13
      Width = 32
      Height = 13
      Caption = 'Label2'
    end
    object Label3: TLabel
      Left = 0
      Top = 55
      Width = 404
      Height = 53
      Align = alBottom
      AutoSize = False
      Caption = 'Label3'
      Color = clBtnShadow
      ParentColor = False
      WordWrap = True
      ExplicitWidth = 347
    end
    object Label4: TLabel
      Left = 0
      Top = 42
      Width = 200
      Height = 13
      Caption = '** B-Count/Remain SendBytes SendCount'
      Color = clBtnShadow
      ParentColor = False
    end
    object LbTimeCount: TLabel
      Left = 204
      Top = 42
      Width = 63
      Height = 13
      Caption = 'LbTimeCount'
    end
    object Label5: TLabel
      Left = 0
      Top = 26
      Width = 32
      Height = 13
      Caption = 'Label5'
    end
    object Panel2: TPanel
      Left = 298
      Top = 35
      Width = 49
      Height = 20
      BevelOuter = bvLowered
      Caption = 'Panel2'
      TabOrder = 0
      object SpeedButton1: TSpeedButton
        Left = 3
        Top = 2
        Width = 43
        Height = 16
        Caption = 'Initialize'
        OnClick = SpeedButton1Click
      end
    end
  end
  object GateSocket: TServerSocket
    Active = True
    Port = 5000
    ServerType = stNonBlocking
    OnClientConnect = GateSocketClientConnect
    OnClientDisconnect = GateSocketClientDisconnect
    OnClientRead = GateSocketClientRead
    OnClientError = GateSocketClientError
    Left = 24
    Top = 12
  end
  object Timer1: TTimer
    Enabled = False
    Interval = 2000
    OnTimer = Timer1Timer
    Left = 60
    Top = 12
  end
  object RunTimer: TTimer
    Enabled = False
    Interval = 1
    OnTimer = RunTimerTimer
    Left = 96
    Top = 12
  end
  object DBSocket: TClientSocket
    Active = False
    ClientType = ctNonBlocking
    Port = 6000
    OnConnect = DBSocketConnect
    OnDisconnect = DBSocketDisconnect
    OnRead = DBSocketRead
    OnError = DBSocketError
    Left = 24
    Top = 48
  end
  object ConnectTimer: TTimer
    Enabled = False
    Interval = 30000
    OnTimer = ConnectTimerTimer
    Left = 60
    Top = 48
  end
  object StartTimer: TTimer
    Enabled = False
    Interval = 100
    OnTimer = StartTimerTimer
    Left = 132
    Top = 12
  end
  object SaveVariableTimer: TTimer
    Interval = 10000
    OnTimer = SaveVariableTimerTimer
    Left = 172
    Top = 12
  end
  object TCloseTimer: TTimer
    Enabled = False
    Interval = 100
    OnTimer = TCloseTimerTimer
    Left = 96
    Top = 48
  end
  object LogUDP: TIdUDPClient
    Port = 10000
    Left = 132
    Top = 48
  end
  object ConAlarmUDP: TIdUDPClient
    Host = '172.20.2.49'
    Port = 9999
    Left = 164
    Top = 48
  end
end
