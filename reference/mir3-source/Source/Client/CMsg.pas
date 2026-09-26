unit CMsg;

interface

uses
  Windows, Classes, Forms, SysUtils;

type
  TClientMsg = record
		nMsgIdx	: integer;
		pszMsg : string[255];
  end;
  PTClientMsg = ^TClientMsg;

  TCMsg = class
  private
    m_xlistMsg: TList;
  public
    constructor Create;
    destructor Destroy; override;
    function LoadMsg: Boolean;
	  function GetMsg(nIdx: Integer):string;
    procedure DelMsg(nIdx: Integer);
    procedure DelAllMsg;
  end;

implementation

uses
  EDcode, HUtil32;

constructor TCMsg.Create;
begin
  m_xlistMsg := TList.Create;
end;

destructor TCMsg.Destroy;
begin
	DelAllMsg;
  m_xlistMsg.Free;
  inherited Destroy;
end;

function TCMsg.LoadMsg: Boolean;
var
  I: integer;
  FileLength: Integer;
  TmpList: TStringList;
  sStr, sNum: string;
  pcm: PTClientMsg;
begin
  Result := False;
	if not FileExists('CMList.dat') then Exit;

  try
    TmpList := Decrypt('CMList.dat');
  except
		TmpList.Free;
    Application.MessageBox(PChar('Message List File Error.'), '[Error] - Legend of Mir III', MB_OK + MB_ICONERROR);
    Exit;
  end;

  for I := 0 to TmpList.Count - 1 do begin
    sStr := TmpList[I];
    if sStr <> '' then begin
      if sStr[1] = ';' then continue;
      if sStr[1] = '#' then begin
        sStr := GetValidStr3 (sStr, sNum, [' ', #9]);
        sNum := Copy (sNum, 2, length(sNum)-1);
        if (sNum <> '') and (sStr <> '') then begin
          New(pcm);
          pcm.nMsgIdx := StrToInt(sNum);
          pcm.pszMsg := sStr;
          m_xlistMsg.Add(pcm);
        end;
      end;
    end;
  end;
  Result := True;
end;

function TCMsg.GetMsg(nIdx: Integer): string;
var
  I: Integer;
begin
  Result := '';
  if nIdx < 0 then exit;
  for I := 0 to m_xlistMsg.Count - 1 do begin
    if PTClientMsg(m_xlistMsg[I]).nMsgIdx = nIdx then begin
      Result := PTClientMsg(m_xlistMsg[I]).pszMsg;
      break;
    end;
  end;
end;

procedure TCMsg.DelMsg(nIdx: Integer);
begin
//
end;

procedure TCMsg.DelAllMsg;
var
 i: Integer;
begin
  for i := 0 to m_xlistMsg.Count - 1 do
    Dispose(PTClientMsg(m_xlistMsg[i]));
  m_xlistMsg.Clear;
end;

end.
