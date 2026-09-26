object FrmMsgClient: TFrmMsgClient
  Left = 1084
  Top = 302
  Width = 196
  Height = 183
  Caption = 'FrmMsgClient'
  Color = clBtnFace
  Font.Charset = DEFAULT_CHARSET
  Font.Color = clWindowText
  Font.Height = -11
  Font.Name = 'MS Sans Serif'
  Font.Style = []
  OldCreateOrder = False
  PixelsPerInch = 96
  TextHeight = 13
  object MsgClient: TClientSocket
    Active = False
    ClientType = ctNonBlocking
    Port = 0
    OnConnect = MsgClientConnect
    OnDisconnect = MsgClientDisconnect
    OnRead = MsgClientRead
    OnError = MsgClientError
    Left = 72
    Top = 56
  end
end
