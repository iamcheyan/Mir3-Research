unit wmM3Def;

interface
uses
  Windows, Classes, Graphics, SysUtils, MyDirect3D9, TDX9Textures, HUtil32, WIL;

type

  PTWMImageHeader = ^TWMImageHeader;
  TWMImageHeader = packed record
    shComp: Smallint;
    Title: array[0..19] of Char;
    VerFlag: Smallint;
    ImageCount: integer;
  end;

  TWMIndexHeader = packed record
    Title: array[0..19] of Char;
    IndexCount: integer;
    VerFlag: integer;
  end;
  PTWMIndexHeader = ^TWMIndexHeader;

  TWMImageInfo = packed record
    DXInfo: TDXTextureInfo;
    dwImageLength: DWORD;
    VerFlag: Integer;
  end;
  PTWMImageInfo = ^TWMImageInfo;

  TWMM3DefImages = class(TWMBaseImages)
  private
    FIdxHeader: TWMIndexHeader;
    FIdxFile: string;
    FNewFmt: Boolean;
    function LoadIndex(idxfile: string): Boolean;
    function Decode(Source, Target: PChar; Width, Height: Integer): Boolean;
    function CopyImageDataToTexture(Buffer: PChar; Texture: TDXImageTexture; Width, Height: Word): Boolean;
  protected
    function GetImageBitmapEx(index: integer): TBitmap; override;
  public
    constructor Create(); override;
    destructor Destroy; override;
    function Initialize(): Boolean; override;
    procedure Finalize; override;

    property NewFmt: Boolean read FNewFmt;
    function CopyDataToTexture(index: integer; Texture: TDXImageTexture): Boolean; override;
  end;

implementation

{$IFDEF WORKFILE}
uses
  ZShare;
{$ENDIF}

{ TWMM3DefImages }
function TWMM3DefImages.CopyDataToTexture(index: integer; Texture: TDXImageTexture): Boolean;
var
  nPosition: Integer;
  imginfo: TWMImageInfo;
  Buffer, DecodeBuffer: PChar;
  ReadSize: Integer;
begin
  Result := False;
  if (index < 0) or (index >= FImageCount) or (Texture = nil) then
    exit;
  if index < FIndexList.Count then begin
    nPosition := Integer(FIndexList[index]);
    if FFileStream.Seek(nPosition, 0) <> nPosition then
      exit;
    if not FNewFmt then
      FFileStream.Read(imginfo, SizeOf(TWMImageInfo) - SizeOf(Integer))
    else
      FFileStream.Read(imginfo, SizeOf(TWMImageInfo));

    if (imginfo.DXInfo.nWidth > MAXIMAGESIZE) or (imgInfo.DXInfo.nHeight > MAXIMAGESIZE) then
      Exit;
    if (imginfo.DXInfo.nWidth < MINIMAGESIZE) or (imgInfo.DXInfo.nHeight < MINIMAGESIZE) then
      Exit;
    ReadSize := imginfo.dwImageLength * 2;
    GetMem(Buffer, ReadSize);
    try
      FillChar(Buffer^, ReadSize, 0);
      if FFileStream.Read(Buffer^, ReadSize) = ReadSize then begin
        FLastImageInfo := imginfo.DXInfo;
        GetMem(DecodeBuffer, imginfo.DXInfo.nWidth * imginfo.DXInfo.nHeight * 2);
        FillChar(DecodeBuffer^, imginfo.DXInfo.nWidth * imginfo.DXInfo.nHeight * 2, #0);
        Result := Decode(Buffer, DecodeBuffer, imginfo.DXInfo.nWidth * 2, imginfo.DXInfo.nHeight);
        if Result then begin
          FLastImageInfo := imginfo.DXInfo;
          Texture.Active := False;
          Texture.Format := D3DFMT_A8R8G8B8;
          Texture.Size := Point(imginfo.DXInfo.nWidth, imginfo.DXInfo.nHeight);
          Texture.PatternSize := Point(imginfo.DXInfo.nWidth, imginfo.DXInfo.nHeight);
          Texture.Active := True;
          Result := CopyImageDataToTexture(DecodeBuffer, Texture, imginfo.DXInfo.nWidth, imginfo.DXInfo.nHeight);
        end;
        FreeMem(DecodeBuffer);
      end;
    finally
      FreeMem(Buffer);
    end;
  end;
end;

function ARGB(const A, R, G, B: Byte): Longword; inline;
begin
  Result := (A shl 24) or (R shl 16) or (G shl 8) or B;
end;

function TWMM3DefImages.CopyImageDataToTexture(Buffer: PChar; Texture: TDXImageTexture; Width, Height: Word): Boolean;
var
  X, Y: Integer;
  nColorId:LongWord;
  wCol16:Word;
  pdwColor:PDWORD;
  dwColor:LongWord;
  Access: TDXAccessInfo;
  cbAlpha:Byte;
begin
  Result := False;
  if Texture.Lock(lfWriteOnly, Access) then begin
    try
      FillChar(Access.Bits^, Access.Pitch * Texture.Size.Y, #0);
      nColorId:= 0;
      for y := Height - 1 downto 0 do begin
        for X := 0 to Texture.Width - 1 do begin
          pdwColor := (PDWORD(Access.Bits));
          wCol16:= PWord(@Buffer[nColorId])^;
          if wCol16 <> 0 then cbAlpha := 255
          else cbAlpha := 0;
//          if wCol16 = 0 then wCol16 := 63519;
          dwColor := ARGB(cbAlpha, (wCol16 and $F800) shr 8, (wCol16 and $7E0) shr 3, (wCol16 and $1F) shl 3);
          Inc(pdwColor, y * Texture.Width + x);
          pdwColor^:= dwColor;
          inc(nColorId, 2);
        end;
      end;
      Result := True;
    finally
      Texture.Unlock;
    end;
  end;
end;

constructor TWMM3DefImages.Create;
begin
  inherited;
  FReadOnly := True;
  FNewFmt := False;
end;

function TWMM3DefImages.Decode(Source, Target: PChar; Width, Height: Integer): Boolean;
var
  nY, nX: Integer;
  nWidthEnd, nWidthStart, nCurrWidth, nCntCopyWord, nLastWidth: integer;
  SourcePtr: PWord;
begin
  Result := False;
  nWidthStart := 0;
  nWidthEnd := 0;
  nCurrWidth := 0;
  for nY := Height - 1 downto 0 do
  begin
    SourcePtr := @Source[nWidthStart * 2];
    nWidthEnd := nWidthEnd + SourcePtr^; //循环取字节
    Inc(nWidthStart);
    nX := nWidthStart;
    Inc(SourcePtr);
    while nX < nWidthEnd do
    begin
      if (SourcePtr^ = $C0) then
      begin
        Inc(nX);
        Inc(SourcePtr);
        nCntCopyWord := SourcePtr^;
        Inc(nX);
        Inc(SourcePtr);
        nCurrWidth := nCurrWidth + nCntCopyWord;
      end
      else
        if (SourcePtr^ = $C1) or (SourcePtr^ = $C2) or (SourcePtr^ = $C3) then
        begin
          Inc(nX);
          Inc(SourcePtr);
          nCntCopyWord := SourcePtr^;
          Inc(nX);
          Inc(SourcePtr);
          nLastWidth := nCurrWidth;
          nCurrWidth := nCurrWidth + nCntCopyWord;
          Move(SourcePtr^, Target[(nY * Width) + (nLastWidth) * 2], nCntCopyWord * 2);
          nX := nX + nCntCopyWord;
          Inc(SourcePtr, nCntCopyWord);
        end
        else exit;
    end;
    inc(nWidthEnd);
    nWidthStart := nWidthEnd;
    nCurrWidth := 0;
  end;
  Result := True;
end;
(*
function TWMM3DefImages.Decode(Source, Target: PChar; Width, Height: Integer): Boolean;
var
  nY, nX, nHLan, npos: Integer;
  nWidthEnd, nWidthStart, nCurrWidth, nCntCopyWord, nLastWidth: integer;
  SourcePtr: PWord;
begin
  Result := False;
  nWidthStart := 0;
  nWidthEnd := 0;
  nCurrWidth := 0;
  if FNewFmt then nHLan := 2
  else nHLan := 0;

  for nY := Height + nHLan - 1 downto 0 do begin
    SourcePtr := @Source[nWidthStart * 2];
    nWidthEnd := nWidthEnd + SourcePtr^; //循环取字节
    Inc(nWidthStart);
    nX := nWidthStart;
    Inc(SourcePtr);
    while nX < nWidthEnd do begin
      if (SourcePtr^ = $C0) then begin
        Inc(nX);
        Inc(SourcePtr);
        nCntCopyWord := SourcePtr^;
        Inc(nX);
        Inc(SourcePtr);
        nCurrWidth := nCurrWidth + nCntCopyWord;
      end
      else if (SourcePtr^ = $C1) or (SourcePtr^ = $C2) or (SourcePtr^ = $C3) then begin
        Inc(nX);
        Inc(SourcePtr);
        nCntCopyWord := SourcePtr^;
        Inc(nX);
        Inc(SourcePtr);
        nLastWidth := nCurrWidth;
        nCurrWidth := nCurrWidth + nCntCopyWord;
//        If {(nLastWidth <= Width) and} (Width < nCurrWidth) Then
//        begin
//          continue;
//        end else begin
//          npos := (nY * Width) + (nLastWidth) * 2;
//          if (npos < 0) or (npos >= Width * Height) then
//            halt(0);
//          Move(SourcePtr^, Target[npos], (nCntCopyWord) * 2);
//          nX := nX + nCntCopyWord;
//          Inc(SourcePtr, nCntCopyWord);
//        end;
        If (nLastWidth <= Width) and (Width < nCurrWidth) Then break;
        npos := (nY * Width) + (nLastWidth) * 2;
//        if (npos < 0) or (npos >= Width *Height) then halt(0);
        Move(SourcePtr^, Target[npos], (nCntCopyWord) * 2);
        nX := nX + nCntCopyWord;
        Inc(SourcePtr, nCntCopyWord);
      end else break;
    end;
    inc(nWidthEnd);
    nWidthStart := nWidthEnd;
    nCurrWidth := 0;
  end;
  Result := True;
end; *)

destructor TWMM3DefImages.Destroy;
begin

  inherited;
end;

procedure TWMM3DefImages.Finalize;
begin
  FIndexList.Clear;
  inherited;
end;

function TWMM3DefImages.GetImageBitmapEx(index: integer): TBitmap;
var
  nPosition: Integer;
  imginfo: TWMImageInfo;
  Buffer, WriteBuffer, ReadBuffer, DecodeBuffer: PChar;
  ReadSize: Integer;
  X, Y: Integer;
  wWriteBuffer, wReadBuffer: PWord;
  nR, nG, nB: Byte;
begin
  Result := nil;

  if (index < 0) or (index >= FImageCount) {or (FLibType <> ltLoadBmp)} then
    exit;
  if index < FIndexList.Count then begin
    nPosition := Integer(FIndexList[index]);
//    if (nPosition = 0) or (FFileStream.Seek(nPosition, 0) <> nPosition) then
//      exit;
    FFileStream.Seek(nPosition, 0);
    if not FNewFmt then
      FFileStream.Read(imginfo, SizeOf(TWMImageInfo) - SizeOf(Integer))
    else
      FFileStream.Read(imginfo, SizeOf(TWMImageInfo));

    if (imginfo.DXInfo.nWidth > MAXIMAGESIZE) or (imgInfo.DXInfo.nHeight > MAXIMAGESIZE) then
      Exit;
    if (imginfo.DXInfo.nWidth < MINIMAGESIZE) or (imgInfo.DXInfo.nHeight < MINIMAGESIZE) then
      Exit;
    ReadSize := imginfo.dwImageLength * 2;
    GetMem(Buffer, ReadSize);
    try
      FillChar(Buffer^, ReadSize, 0);
      if FFileStream.Read(Buffer^, ReadSize) = ReadSize then begin
        FLastImageInfo := imginfo.DXInfo;
        Result := TBitmap.Create;
        Result.PixelFormat := pf16bit;
        Result.Width := imginfo.DXInfo.nWidth;
        Result.Height := imginfo.DXInfo.nHeight;
        GetMem(DecodeBuffer, Result.Width * Result.Height * 2);
        FillChar(DecodeBuffer^, Result.Width * Result.Height * 2, #0);
        if Decode(Buffer, DecodeBuffer, Result.Width * 2, Result.Height) then begin
          for Y := 0 to Result.Height - 1 do begin
            wReadBuffer := @DecodeBuffer[Y * Result.Width * 2];
            wWriteBuffer := Result.ScanLine[Result.Height - Y - 1];
            for X := 0 to Result.Width - 1 do begin
              TColor2RGB(g_OutBackColor, nR, nG, nB);
              if wReadBuffer^ = 0 then wWriteBuffer^ := RGB16(nR, nG, nB)//63519
              else wWriteBuffer^ := wReadBuffer^;
              Inc(wWriteBuffer);
              Inc(wReadBuffer);
            end;
//            Move(ReadBuffer^, WriteBuffer^, Result.Width * 2);
          end;
        end else begin
          Result.Free;
          Result := nil;
        end;
        FreeMem(DecodeBuffer);
      end;
    finally
      FreeMem(Buffer);
    end;
  end;
end;

function TWMM3DefImages.Initialize: Boolean;
var
  FHeader: TWMImageHeader;
begin
  Result := inherited Initialize;
  if Result then begin
    FFileStream.Read(FHeader, SizeOf(TWMImageHeader));
    if FHeader.VerFlag = 5000 then FNewFmt := True
    else FNewFmt := False;
    FImageCount := FHeader.ImageCount;

    FIdxFile := ExtractFilePath(FFileName) + ExtractFileNameOnly(FFileName) + '.WIX';
    Result := LoadIndex(FIdxFile);
    if not Result then begin
      Finalize;
      exit;
    end;
//    FFileStream.Read(FHeader, SizeOf(TWMImageHeader));
//    if FHeader.ImageCount = FIndexList.Count then begin
//      FImageCount := FHeader.ImageCount;
      InitializeTexture;
//    end
//    else begin
//      Finalize;
//      raise Exception.Create(FFileName + ' 对应文件数量不一致');
//    end;
  end;
end;
{
function TWMM3DefImages.LoadIndex(idxfile: string): Boolean;
var
  fhandle, i, value: integer;
  pvalue: PInteger;
begin
  Result := False;
  FIndexList.Clear;
  if FileExists(idxfile) then begin
    fhandle := FileOpen(idxfile, fmOpenRead or fmShareDenyNone);
    if fhandle > 0 then begin
      if not FNewFmt then FileRead(fhandle, FIdxHeader, sizeof(TWMIndexHeader) - 4)
      else FileRead(fhandle, FIdxHeader, sizeof(TWMIndexHeader));

      GetMem(pvalue, 4 * FIdxHeader.IndexCount);
      FileRead(fhandle, pvalue^, 4 * FIdxHeader.IndexCount);
      for i := 0 to FIdxHeader.IndexCount - 1 do begin
        value := PInteger(integer(pvalue) + 4 * i)^;
        FIndexList.Add(pointer(value));
      end;
      FreeMem(pvalue);
      FileClose(fhandle);
      Result := True;
    end;
  end;
end; }

var
  NewVerSign        : DWORD;

function TWMM3DefImages.LoadIndex(idxfile: string): Boolean;
var
  fhandle, i        : integer;
  POffsetIndex      : dword;
  hWix, hWil, hMap, mCount, mfSize: Cardinal;
  hMem              : Pointer;
  fWil              : String;
  fBegin            : integer;
begin
  Result := False;
  FIndexList.Clear;
  fhandle := 0;

  if FileExists(idxfile) then begin
    if FileExists(idxfile) then begin
      fhandle := FileOpen(idxfile, fmOpenRead or fmShareDenyNone);
    end;
    if fhandle > 0 then begin
      hWix := CreateFile(PChar(idxfile), GENERIC_READ, FILE_SHARE_WRITE or FILE_SHARE_READ, 0, OPEN_EXISTING, FILE_ATTRIBUTE_NORMAL, 0);
      if hWix <> INVALID_HANDLE_VALUE then begin
        hMap := CreateFileMapping(hWix, Nil, PAGE_READONLY, 0, 0, Nil);
        if hMap <> 0 then begin
          hMem := MapViewOfFile(hMap, FILE_MAP_READ, 0, 0, 0);
          if hMem <> Nil then begin
            CopyMemory(@mCount, Pointer(DWORD(hMem) + 20), 4);
            CopyMemory(@NewVerSign, Pointer(DWORD(hMem) + 24), 4);
            FNewFmt := (NewVerSign and $FFFF0000) = $B13A0000;
            mfSize := GetFileSize(hWix, 0);
            if not FNewFmt then begin
              fBegin := 24;
              NewVerSign := $B13AD3FB;
            end
            else
              fBegin := 28;

            if (mCount * 4 + fBegin) <= mfSize + 4 then begin
              GetMem(Pointer(POffsetIndex), mCount * 4);
              if Pointer(POffsetIndex) <> Nil then begin
                CopyMemory(Pointer(POffsetIndex), Pointer(DWORD(hMem) + fBegin), mCount * 4);
                FImageCount := mCount;
              end;
            end;
            UnmapViewOfFile(hMem);
          end;
          CloseHandle(hMap);
        end;
        CloseHandle(hWix);
      end;
      for i := 0 to FImageCount - 1 do begin
        FIndexList.Add(Pointer(PDWORD(POffsetIndex + i * 4)^));
      end;
      FreeMem(PDWORD(POffsetIndex));
      Result := True;
    end;
  end;
end;

end.
