unit Scanf;

interface

uses SysUtils;

type
  EFormatError = class(ExCeption);


  function numScanf(const s: string; const fmt : string;
                      const Pointers : array of Pointer) : Integer;
  function strScanf(const s: string; const fmt : string;
                        var Strs : array of string) : Integer;
implementation

{
    Version 1.0 is written by unknown Delphier
    Version 2.0 is written by Lujiaxing(Delphier)

    distributed on GPL Lisence                                   }

{ numScanf parses an input string. The parameters ...
    s - input string to parse
    fmt - 'C' scanf-like format string to control parsing
      %d - convert a Long Integer
      %f - convert an Extended Float
      other char - increment s pointer past "other char"
      space - does nothing
    Pointers - array of pointers to have values assigned

    result - number of variables actually assigned

    for example with ...
      numScanf('Time. 7:32.77   Age. 8',
             '. %d:%f . %d', [@hrs, @min, @age]);

    You get ...
      hrs = 7  min = 32.77  age = 8                              }

function numScanf(const s: string; const fmt : string;
                      const Pointers : array of Pointer) : Integer;
var
  i,j,n,m : integer;
  s1      : string;
  L       : LongInt;
  X       : Extended;

  function GetInt : Integer;
  begin
    s1 := '';
    while (Length(s) > n) do begin
      if not (s[n] = ' ') then break;
      inc(n);
    end;
    while (s[n] in ['0'..'9', '+', '-'])
        and (Length(s) >= n) do begin
      //如果第二次遇到了加减号，则认为数字结束,Lujiaxing
      if (s[n]='+') or (s[n]='-') and (n>1) then break;
      s1 := s1+s[n];
      inc(n);
    end;
    Result := Length(s1);
  end;

  function GetFloat : Integer;
  begin
    s1 := '';
    while (Length(s) > n) do begin
      if not (s[n] = ' ') then break;
      inc(n);
    end;
    while (s[n] in ['0'..'9', '+', '-', '.', 'e', 'E'])
      and (Length(s) >= n) do begin
      s1 := s1+s[n];
      inc(n);
    end;
    Result := Length(s1);
  end;

  function ScanStr(c : Char) : Boolean;
  begin
    while (Length(s) > n) do begin
      if not (s[n] = ' ') then break;
      inc(n);
    end;
    inc(n);

    If (n <= Length(s)) then Result := True
    else Result := False;
  end;

  function GetFmt : Integer;
  begin
    Result := -1;

    while (TRUE) do begin
      while (Length(fmt) > m) do begin
        if not (fmt[m] = ' ') then break;
        inc(m);
      end;
      if (m >= Length(fmt)) then break;

      if (fmt[m] = '%') then begin
        inc(m);
        case fmt[m] of
          'd': Result := vtInteger;
          'f': Result := vtExtended;
          //'s': Result := vtString;
        end;
        inc(m);
        break;
      end;

      if (ScanStr(fmt[m]) = False) then break;
      inc(m);
    end;
  end;

begin
  n := 1;
  m := 1;
  Result := 0;

  for i := 0 to High(Pointers) do begin
    j := GetFmt;

    case j of
      vtInteger : begin
        if GetInt > 0 then begin
          L := StrToInt(s1);
          Move(L, Pointers[i]^, SizeOf(LongInt));
          inc(Result);
        end
        else break;
      end;

      vtExtended : begin
        if GetFloat > 0 then begin
          X := StrToFloat(s1);
          Move(X, Pointers[i]^, SizeOf(Extended));
          inc(Result);
        end
        else break;
      end;

      else break;
    end;
  end;
end;

{ strScanf parses an input string. The parameters ...
    s - input string to parsdssssse
    fmt - 'C' scanf-like format string to control parsing
      %s - convert a string (delimited by spaces)
      other char - increment s pointer past "other char"
      space - does nothing

    result - number of variables actually assigned

    for example with ...
      var Strs:array[1..4] of string;
      strScanf('Name. Bill   Time. 7:32.77   Age. 8',
             'Name. %s Time. %s:%s Age. %s', Strs);

    You get ...
      Strs[1] = 'Bill'  Strs[2] = '7'  Strs[3] = '32.77'  Strs[4] = '8'       }
function strScanf(const s: string; const fmt : string;
                      var Strs : array of string) : Integer;
var
  i,j,n,m : integer;
  s1      : string;
  L       : LongInt;
  X       : Extended;

  function GetString : Integer;
  begin
    s1 := '';
    while (Length(s) > n) do begin
      if not (s[n] = ' ') then break;
      inc(n);
    end;
    while (Length(s) >= n) do
    begin
      if (s[n] = ' ') then break;
      //如果遇到模板的下一个字符，则被认为是字符串结束,Lujiaxing
      if m<=length(fmt) then
        if (s[n]=fmt[m]) then break;
      s1 := s1+s[n];
      inc(n);
    end;
    Result := Length(s1);
  end;

  function ScanStr(c : Char) : Boolean;
  begin
    while (Length(s) > n) do begin
      if not (s[n] = ' ') then break;
      inc(n);
    end;
    inc(n);

    If (n <= Length(s)) then Result := True
    else Result := False;
  end;

  function GetFmt : Integer;
  begin
    Result := -1;

    while (TRUE) do begin
      while (Length(fmt) > m) do begin
        if not (fmt[m] = ' ') then break;
        inc(m);
      end;
      if (m >= Length(fmt)) then break;

      if (fmt[m] = '%') then begin
        inc(m);
        case fmt[m] of
          //'d': Result := vtInteger;
          //'f': Result := vtExtended;
          's': Result := vtString;
        end;
        inc(m);
        break;
      end;

      if (ScanStr(fmt[m]) = False) then break;
      inc(m);
    end;
  end;

begin
  n := 1;
  m := 1;
  Result := 0;

  for i := 0 to Sizeof(Strs) do begin
    j := GetFmt;

    case j of
      vtString : begin
        if GetString > 0 then begin
          Strs[i]:=s1;
          inc(Result);
        end
        //else break;
      end;

      else break;
    end;
  end;
end;

end.
