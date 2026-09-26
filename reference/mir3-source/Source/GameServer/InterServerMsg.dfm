object FrmSrvMsg: TFrmSrvMsg
  Left = 1074
  Top = 695
  Width = 206
  Height = 164
  Caption = 'FrmSrvMsg'
  Color = clBtnFace
  Font.Charset = DEFAULT_CHARSET
  Font.Color = clWindowText
  Font.Height = -11
  Font.Name = 'MS Sans Serif'
  Font.Style = []
  OldCreateOrder = False
  OnCreate = FormCreate
  OnDestroy = FormDestroy
  PixelsPerInch = 96
  TextHeight = 13
  object MsgServer: TServerSocket
    Active = False
    Port = 0
    ServerType = stNonBlocking
    OnClientConnect = MsgServerClientConnect
    OnClientDisconnect = MsgServerClientDisconnect
    OnClientRead = MsgServerClientRead
    OnClientError = MsgServerClientError
    Left = 56
    Top = 40
  end
end
