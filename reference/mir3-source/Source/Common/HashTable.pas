unit HashTable;

interface

uses SysUtils, Classes;

type
      { THashTable }
  PPHashItem = ^PHashItem;
  PHashItem = ^THashItem;
  THashItem = record
    Next: PHashItem;
    Key: string;
    Value: string;
    Data: Pointer;
    Int: Integer;
  end;

  THashTable = class
  private
    Buckets: array of Pointer;
    FRecordCount: Integer;
    function GetCount: Integer;
    function GetValue(const Name: string): string;
    procedure SetValue(const Name: string; Value: string);

    function GetInteger(const Name: string): Integer;
    procedure SetInteger(const Name: string; Value: Integer);


    function GetData(const Name: string): Pointer;
    procedure SetData(const Name: string; Value: Pointer);

    function Get(Index: Integer): Pointer;

    procedure Put(Index: Integer; Value: Pointer);

    function GetString(Index: Integer): string;
    procedure SetString(Index: Integer; Value: string);
  protected
    function Find(const Name: string): PPHashItem;

  public
    constructor Create(Size: Integer = 256);
    destructor Destroy; override;
    function HashOf(const Name: string): Cardinal; virtual;
    function IndexOf(const Name: string): Integer;
    procedure Clear;
    procedure Remove(const Name: string);
    procedure Delete(Index: Integer);
    function Modify(const Name: string; Value: string): Boolean;
    function Add(const Name: string; const Value: string; P: Pointer; Int: Integer = -1): Boolean;
    property Values[const Name: string]: string read GetValue write SetValue;
    property Integers[const Name: string]: Integer read GetInteger write SetInteger;
    property Datas[const Name: string]: Pointer read GetData write SetData;
    property Count: Integer read GetCount;
    property RecordCount: Integer read FRecordCount;
    property Items[Index: Integer]: Pointer read Get write Put;
    property Strings[Index: Integer]: string read GetString write SetString;
  end;

implementation

    { THashTable }

function THashTable.GetCount: Integer;
begin
  Result := Length(Buckets);
end;

function THashTable.GetString(Index: Integer): string;
begin
  if Buckets[Index] <> nil then
    Result := PHashItem(Buckets[Index]).Value
  else
    Result := '';
end;

procedure THashTable.SetString(Index: Integer; Value: string);
begin
  if Buckets[Index] <> nil then
    PHashItem(Buckets[Index]).Value := Value;
end;

function THashTable.GetInteger(const Name: string): Integer;
var
  P: PHashItem;
begin
  P := Find(Name)^;
  if P <> nil then
    Result := P^.Int
  else
    Result := -1;
end;

procedure THashTable.SetInteger(const Name: string; Value: Integer);
var
  P: PHashItem;
begin
  P := Find(Name)^;
  if P <> nil then
    P^.Int := Value;
end;

function THashTable.Get(Index: Integer): Pointer;
begin
  if Buckets[Index] <> nil then
    Result := PHashItem(Buckets[Index]).Data
  else
    Result := nil;
end;

procedure THashTable.Put(Index: Integer; Value: Pointer);
begin
  if Buckets[Index] <> nil then
    PHashItem(Buckets[Index]).Data := Value;
end;

function THashTable.GetValue(const Name: string): string;
var
  P: PHashItem;
begin
  P := Find(Name)^;
  if P <> nil then
    Result := P^.Value
  else
    Result := '';
end;

function THashTable.IndexOf(const Name: string): Integer;
begin
  Result := HashOf(Name) mod Cardinal(Length(Buckets));
end;

procedure THashTable.SetValue(const Name: string; Value: string);
var
  Hash: Integer;
  Bucket: PHashItem;
begin
  Hash := HashOf(Name) mod Cardinal(Length(Buckets));
  New(Bucket);
  Bucket^.Key := Name;
  Bucket^.Value := Value;
  Bucket^.Next := Buckets[Hash];
  Bucket^.Data := nil;
  Bucket^.Int := -1;
  Buckets[Hash] := Bucket;
  Inc(FRecordCount);
end;

function THashTable.GetData(const Name: string): Pointer;
var
  P: PHashItem;
begin
  P := Find(Name)^;
  if P <> nil then
    Result := P^.Data
  else
    Result := nil;
end;

procedure THashTable.SetData(const Name: string; Value: Pointer);
var
  Hash: Integer;
  Bucket: PHashItem;
begin
  Hash := HashOf(Name) mod Cardinal(Length(Buckets));
  New(Bucket);
  Bucket^.Key := Name;
  Bucket^.Value := '';
  Bucket^.Next := Buckets[Hash];
  Bucket^.Data := Value;
  Bucket^.Int := -1;
  Buckets[Hash] := Bucket;
  Inc(FRecordCount);
end;

procedure THashTable.Clear;
var
  I: Integer;
  P, N: PHashItem;
begin
  FRecordCount := 0;
  for I := 0 to Length(Buckets) - 1 do
  begin
    P := Buckets[I];
    while P <> nil do
    begin
      N := P^.Next;
      Dispose(P);
      P := N;
    end;
    Buckets[I] := nil;
  end;
end;

constructor THashTable.Create(Size: Integer);
begin
  inherited Create;
  SetLength(Buckets, Size);
  FRecordCount := 0;
end;

destructor THashTable.Destroy;
begin
  Clear;

  inherited;
end;

function THashTable.Find(const Name: string): PPHashItem;
var
  Hash: Integer;
begin
  Hash := HashOf(Name) mod Cardinal(Length(Buckets));
  Result := @Buckets[Hash];
  while Result^ <> nil do
  begin
    if Result^.Key = Name then
      Exit
    else
      Result := @Result^.Next;
  end;
end;

function THashTable.HashOf(const Name: string): Cardinal;
var
  I: Integer;
begin
  Result := 0;
  for I := 1 to Length(Name) do
    Result := ((Result shl 2) or (Result shr (SizeOf(Result) * 8 - 2))) xor
      Ord(Name[I]);
end;

function THashTable.Add(const Name: string; const Value: string; P: Pointer; Int: Integer): Boolean;
var
  Hash: Integer;
  Bucket: PHashItem;
begin
  Hash := HashOf(Name) mod Cardinal(Length(Buckets));
  New(Bucket);
  Bucket^.Key := Name;
  Bucket^.Value := Value;
  Bucket^.Next := Buckets[Hash];
  Bucket^.Data := P;
  Bucket^.Int := Int;
  Buckets[Hash] := Bucket;
  Inc(FRecordCount);
end;

function THashTable.Modify(const Name: string; Value: string): Boolean;
var
  P: PHashItem;
begin
  P := Find(Name)^;
  if P <> nil then
  begin
    Result := True;
    P^.Value := Value;
  end
  else
    Result := False;
end;

procedure THashTable.Delete(Index: Integer);
var
  P: PHashItem;
  Prev: PPHashItem;
begin
  Prev := @Buckets[Index];
  P := Prev^;
  if P <> nil then
  begin
    Prev^ := P^.Next;
    Dispose(P);
    Dec(FRecordCount);
  end;
end;

procedure THashTable.Remove(const Name: string);
{var
  Hash: Integer;
  Prev: PPHashItem;
begin
  Hash := HashOf(Name) mod Cardinal(Length(Buckets));
  Prev := @Buckets[Hash];

  if Prev <> nil then begin
    if Prev^.Key = Name then begin
      P := Prev^;
      if P <> nil then
      begin
        Prev^ := P^.Next;
        Dispose(P);
      end;
      Buckets[Hash] := nil;
    end;
  end;
end;}

var
  P: PHashItem;
  Prev: PPHashItem;
begin
  Prev := Find(Name);
  if Prev <> nil then begin
    P := Prev^;
    if P <> nil then
    begin
      Prev^ := P^.Next;
      Dispose(P);
      Dec(FRecordCount);
    end;
  end;
end;

end.

