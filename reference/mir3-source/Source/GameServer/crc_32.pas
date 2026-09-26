unit crc_32;

interface

uses Windows;

function crc32(crc: longint; const c: byte): longint;

function CrcStr(Str : string) : longint;

implementation

const
    CRC32_POLYNOMIAL = $EDB88320;

var
    Ccitt32Table: array[0..255] of longint;

function CrcStr(Str : string) : longint;
var i,l,c : integer;
begin
  l := length(Str);
  c := 0;
  for i := 1 to l do
    c:=crc32(c, byte(str[i]));
  result := c;
end;

function crc32(crc: longint; const c: byte): longint;
begin
  crc32 := (((crc shr 8) and $00FFFFFF) xor (Ccitt32Table[(crc xor c) and $FF]));
end;

procedure BuildCRCTable;
var i, j, value: DWORD;
begin
  for i := 0 to 255 do
  begin
    value := i;
    for j := 8 downto 1 do
    begin
      if ((value and 1) <> 0) then
        value := (value shr 1) xor CRC32_POLYNOMIAL
      else
        value := value shr 1;
    end;
    Ccitt32Table[i] := value;
  end
end;

initialization
  BuildCRCTable;
end.

