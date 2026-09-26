unit wmMyImage;

interface
uses
  Windows, Classes, Graphics, SysUtils, HGETextures, HUtil32, WIL, DirectXGraphics, DES{, ZLibEx};

const
  HEADERNAME = 'Mir3 Library';
  CHECKENSTR = 'lom2com';
  MYFILEEXT = '.Lib';

type
  pTWMImageHeader = ^TWMImageHeader;
  TWMImageHeader = packed record
    Title: array[0..15] of char;
    sEnStr: array[0..6] of Char;
    nVer: Byte;
    ImageCount2: Integer;
    IndexOffset1: Integer;
    IndexOffset2: Integer;
    OffsetSize: Integer;
    ImageCount: Integer;
    UpDateTime: TDateTime;
    IndexOffset: Integer;
  end;

  TWMImageInfo = packed record
    DXInfo: TDXTextureInfo;
    btImageFormat: TWILColorFormat;
    nDataSize: Integer;
  end;
  pTWMImageInfo = ^TWMImageInfo;

  TWMMyImageImages = class(TWMBaseImages)
  private
    FHeader: TWMImageHeader;
    procedure LoadIndex();
    function CopyImageDataToTexture(Buffer: PChar; Texture: TDXImageTexture; Width, Height: Word; WILColorFormat: TWILColorFormat): Boolean;
    function GetUpDateTime: TDateTime;
  protected
    procedure LoadDxImage(index: Integer; position: integer; pDXTexture: pTDXTextureSurface); override;
{$IFDEF WORKFILE}
    function GetImageBitmapEx(index: integer): TBitmap; override;
{$ENDIF}
  public
    FCanEncry: Boolean;
    constructor Create(); override;
    function Initialize(): Boolean; override;
    property UpDateTime: TDateTime read GetUpDateTime;
    procedure FormatImageInfo(WMImageInfo: pTWMImageInfo{$IFDEF WORKFILE}; boEncrypt: Boolean{$ENDIF});
    procedure FormatDataBuffer(Buffer: PChar; BufferLen: Integer{$IFDEF WORKFILE}; boEncrypt: Boolean{$ENDIF});
{$IFDEF WORKFILE}
    function SaveIndexList(): Boolean; override;
    procedure GetImageXY(index: Integer; out nX, nY: Integer);
    procedure UpdateImageXY(index, nX, nY, nShadow, nShadowX, nShadowY: Integer);
    function GetDataImageInfo(index: Integer): TWMImageInfo;
    function GetOffsetIndex(): Integer;
    function GetDataOffset(index: Integer; boStart: Boolean): Integer;
    function AddDataToFile(ImageInfo: pTWMImageInfo; Buffer: PChar; BufferLen: Integer): Boolean; overload;
    function AddDataToFile(Offset: Integer; Buffer: PChar; BufferLen: Integer): Boolean; overload;
    procedure InsertOffsetToList(OffList: TList; index, StartPos, OffsetPos: Integer);
    procedure UpdateOffsetToList(OffList: TList; index, StartPos, OffsetPos: Integer);
    procedure ChangeOffsetToList(Startindex, Endindex, ChangePos: Integer; boDel: Boolean);
    function CopyDataToTexture(index: integer; Texture: TDXImageTexture): Boolean; override;
{$ENDIF}
  end;
  procedure FormatHeader(Header: pTWMImageHeader{$IFDEF WORKFILE}; boEncrypt: Boolean{$ENDIF});

implementation

procedure FormatHeader(Header: pTWMImageHeader{$IFDEF WORKFILE}; boEncrypt: Boolean{$ENDIF});
begin
{$IFDEF WORKFILE}
  if boEncrypt then begin
    Header.IndexOffset1 := LoWord(Header.IndexOffset) shl 16 or Random($FFFF);
    Header.IndexOffset2 := HiWord(Header.IndexOffset) shl 16 or Random($FFFF);
    Header.IndexOffset := 0;
  end else begin
{$ENDIF}
    Header.IndexOffset := MakeLong(Word(Header.IndexOffset1 shr 16), Word(Header.IndexOffset2 shr 16));
{$IFDEF WORKFILE}
  end;
{$ENDIF}
end;

{ TWMMyImageImages }
procedure TWMMyImageImages.LoadDxImage(index, position: integer; pDXTexture: pTDXTextureSurface);
var
  imginfo: TWMImageInfo;
  Buffer, outBuffer: PChar;
  ReadSize, nOutLen: Integer;
begin
  pDXTexture.boNotRead := True;
  if (position < 10) then Exit;
  if FFileStream.Seek(position, 0) = position then begin
    FFileStream.Read(imginfo, SizeOf(imginfo));
    FormatImageInfo(@imginfo{$IFDEF WORKFILE}, False{$ENDIF});
    if (imginfo.nDataSize <= 0) then
      exit;

    if (imginfo.DXInfo.nWidth > MAXIMAGESIZE) or (imgInfo.DXInfo.nHeight > MAXIMAGESIZE) then
      Exit;
    if (imginfo.DXInfo.nWidth < MINIMAGESIZE) or (imgInfo.DXInfo.nHeight < MINIMAGESIZE) then
      Exit;
    ReadSize := imginfo.nDataSize;
    GetMem(Buffer, ReadSize);
    outBuffer := nil;
    try
      if FFileStream.Read(Buffer^, ReadSize) = ReadSize then begin
        FormatDataBuffer(Buffer, ReadSize{$IFDEF WORKFILE}, False{$ENDIF});
        ZIPDecompress(Buffer, ReadSize, 0, outBuffer);
        if imginfo.btImageFormat in [WILFMT_R5G6B5] then
          pDXTexture.Surface := MakeDXImageTexture(imginfo.DXInfo.nWidth, imginfo.DXInfo.nHeight, WILFMT_A8R8G8B8)
        else
          pDXTexture.Surface := MakeDXImageTexture(imginfo.DXInfo.nWidth, imginfo.DXInfo.nHeight, imginfo.btImageFormat);

        if pDXTexture.Surface <> nil then begin
          if not CopyImageDataToTexture(outBuffer, pDXTexture.Surface, imginfo.DXInfo.nWidth, imgInfo.DXInfo.nHeight,
            imginfo.btImageFormat) then begin
            pDXTexture.Surface.Free;
            pDXTexture.Surface := nil;
          end
          else begin
            pDXTexture.boNotRead := False;
            pDXTexture.nPx := imginfo.DXInfo.px;
            pDXTexture.nPy := imginfo.DXInfo.py;
            pDXTexture.nShadow := imginfo.DXInfo.bShadow;
            pDXTexture.nsPx := imginfo.DXInfo.shShadowPX;
            pDXTexture.nsPy := imginfo.DXInfo.shShadowPY;
          end;
        end;
        FreeMem(outBuffer);
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

function TWMMyImageImages.CopyImageDataToTexture(Buffer: PChar; Texture: TDXImageTexture; Width, Height: Word; WILColorFormat: TWILColorFormat): Boolean;
var
  X, Y: Integer;
  nColorId:LongWord;
  wCol16:Word;
  pdwColor:PDWORD;
  dwColor:LongWord;
  Access: TDXAccessInfo;
  cbAlpha:Byte;
  WriteBuffer, ReadBuffer: PChar;
  bitLength: Byte;
begin
  bitLength := GetFormatBitLen(WILColorFormat);
  Result := False;
  if (Texture.Size.X < Width) or (Texture.Size.Y < Height) then
    exit;
  if Texture.Lock(lfWriteOnly, Access) then begin
    try
      SafeFillChar(Access.Bits^, Access.Pitch * Texture.Size.Y, #0);
      if (Texture.Size.X = Width) and (Texture.Size.Y = Height) then begin
        if WILColorFormat in [WILFMT_R5G6B5] then begin
          nColorId:= 0;
          for Y := 0 to Height - 1 do begin
            for X := 0 to Texture.Width - 1 do begin
              pdwColor := (PDWORD(Access.Bits));
              wCol16:= PWord(@Buffer[nColorId])^;
              if wCol16 <> 63519 then cbAlpha := 255
              else cbAlpha := 0;
              if wCol16 = 63519 then wCol16 := 0;
              dwColor := ARGB(cbAlpha, (wCol16 and $F800) shr 8, (wCol16 and $7E0) shr 3, (wCol16 and $1F) shl 3);
              Inc(pdwColor, y * Texture.Width + x);
              pdwColor^:= dwColor;
              inc(nColorId, 2);
            end;
          end;
        end else begin
          Move(Buffer^, Access.Bits^, Width * Height * bitLength);
        end;
        Result := True;
      end
      else begin
        if WILColorFormat in [WILFMT_R5G6B5] then begin
          nColorId:= 0;
          for Y := 0 to Height - 1 do begin
            for X := 0 to Texture.Width - 1 do begin
              pdwColor := (PDWORD(Access.Bits));
              wCol16:= PWord(@Buffer[nColorId])^;
              if wCol16 <> 63519 then cbAlpha := 255
              else cbAlpha := 0;
              if wCol16 = 63519 then wCol16 := 0;
              dwColor := ARGB(cbAlpha, (wCol16 and $F800) shr 8, (wCol16 and $7E0) shr 3, (wCol16 and $1F) shl 3);
              Inc(pdwColor, y * Texture.Width + x);
              pdwColor^:= dwColor;
              inc(nColorId, 2);
            end;
          end;
        end else begin
          for Y := 0 to Height - 1 do begin
            ReadBuffer := @Buffer[Y * Width * bitLength];
            WriteBuffer := Pointer(Integer(Access.Bits) + (Access.Pitch * Y));
            Move(ReadBuffer^, WriteBuffer^, Width * bitLength);
          end;
        end;
        Result := True;
      end;
    finally
      Texture.Unlock;
    end;
  end;
end;

constructor TWMMyImageImages.Create;
begin
  inherited;
  FCanEncry := False;
{$IFDEF WORKFILE}
  FReadOnly := False;
{$ENDIF}
end;

function TWMMyImageImages.Initialize: Boolean;
var
  sEnStr: array[0..7] of Char;
begin
  Result := inherited Initialize;
  if Result then begin
    FFileStream.Read(FHeader, SizeOf(TWMImageHeader));
    FboEncryVer := FHeader.nVer = 1;
    FCanEncry := FboEncryVer and (FPassword <> '');
    if FCanEncry then begin
      DecryBuffer(FPassword, @FHeader.sEnStr[0], @sEnStr[0], 8, 8);
      if sEnStr <> CHECKENSTR then
        FCanEncry := False;
    end;
    FormatHeader(@FHeader{$IFDEF WORKFILE}, False{$ENDIF});
    FImageCount := FHeader.ImageCount;
    LoadIndex;
    InitializeTexture;
  end;
end;

procedure TWMMyImageImages.LoadIndex;
var
  pvalue, OffsetBuffer: PChar;
  OffsetSize, ImageCountSize: Integer;
begin
  FIndexList.Clear;
  FImageCount := 0;
  if FHeader.IndexOffset <= 0 then begin
    FHeader.IndexOffset := SizeOf(FHeader);
    exit;
  end;
  OffsetSize := FHeader.OffsetSize;
  if OffsetSize > 1024 * 1024 * 50 then exit;
  if FCanEncry then begin
    if FHeader.ImageCount2 <= 0 then exit;
    FHeader.ImageCount := FHeader.ImageCount2;
  end else if FHeader.ImageCount <= 0 then exit;
  FFileStream.Seek(FHeader.IndexOffset, soFromBeginning);
  ImageCountSize := FHeader.ImageCount * SizeOf(Integer);
  if OffsetSize > 0 then begin
    GetMem(pvalue, OffsetSize);
    Try
      if FFileStream.Read(pvalue^, OffsetSize) = OffsetSize then begin
        ImageCountSize := FHeader.ImageCount * SizeOf(Integer);
        OffsetSize := ZIPDecompress(pvalue, OffsetSize, ImageCountSize, OffsetBuffer);
        if (OffsetBuffer <> nil) then begin
          if OffsetSize = (ImageCountSize + 10 * SizeOf(Integer)) then begin
            FIndexList.Count := FHeader.ImageCount;
            Move(OffsetBuffer[10 * SizeOf(Integer)], FIndexList.List^, ImageCountSize);
            FImageCount := FIndexList.Count;
          end;
          FreeMem(OffsetBuffer);
        end;
      end;
    Finally
      FreeMem(pvalue);
    End;
  end else begin
    GetMem(OffsetBuffer, ImageCountSize);
    Try
      if FFileStream.Read(OffsetBuffer^, ImageCountSize) = ImageCountSize then begin
        FIndexList.Count := FHeader.ImageCount;
        Move(OffsetBuffer^, FIndexList.List^, ImageCountSize);
        FImageCount := FIndexList.Count;
      end;
    Finally
      FreeMem(OffsetBuffer);
    End;
  end;
end;
//位移宽高，进行加密
procedure TWMMyImageImages.FormatImageInfo(WMImageInfo: pTWMImageInfo{$IFDEF WORKFILE}; boEncrypt: Boolean{$ENDIF});
var
  nLen: Integer;
begin
  nLen := SizeOf(TWMImageInfo) div 8 * 8;
{$IFDEF WORKFILE}
  if boEncrypt then begin
    WMImageInfo.DXInfo.nWidth := WMImageInfo.DXInfo.nWidth shl 4 or (Random(16) and $F);
    WMImageInfo.DXInfo.nHeight := WMImageInfo.DXInfo.nHeight shl 4 or (Random(16) and $F);
    if FCanEncry and (FPassword = '') and (nLen > 0) then
      EncryBuffer(FPassword, PChar(WMImageInfo), PChar(WMImageInfo), nLen, nLen);
  end else begin
{$ENDIF}
    if FCanEncry and (FPassword = '') and (nLen > 0) then
      DecryBuffer(FPassword, PChar(WMImageInfo), PChar(WMImageInfo), nLen, nLen);
    WMImageInfo.DXInfo.nWidth := WMImageInfo.DXInfo.nWidth shr 4;
    WMImageInfo.DXInfo.nHeight := WMImageInfo.DXInfo.nHeight shr 4;
{$IFDEF WORKFILE}
  end;
{$ENDIF}
end;

procedure TWMMyImageImages.FormatDataBuffer(Buffer: PChar; BufferLen: Integer{$IFDEF WORKFILE}; boEncrypt: Boolean{$ENDIF});
begin
  if (not FCanEncry) or (BufferLen < 128) or (FPassword = '') then Exit;
{$IFDEF WORKFILE}
  if boEncrypt then begin
    EncryBuffer(FPassword, Buffer, Buffer, 128, 128);
  end else begin
{$ENDIF}
    DecryBuffer(FPassword, Buffer, Buffer, 128, 128); 
{$IFDEF WORKFILE}
  end;
{$ENDIF}
end;

function TWMMyImageImages.GetUpDateTime: TDateTime;
begin
  Result := FHeader.UpDateTime;
end;

{$IFDEF WORKFILE}
function TWMMyImageImages.AddDataToFile(ImageInfo: pTWMImageInfo; Buffer: PChar; BufferLen: Integer): Boolean;
begin
  Result := False;
  if FFileStream.Seek(FHeader.IndexOffset, 0) = FHeader.IndexOffset then begin
    FormatImageInfo(ImageInfo, True);
    FFileStream.Write(ImageInfo^, SizeOf(TWMImageInfo));
    FormatDataBuffer(Buffer, BufferLen, True);
    FFileStream.Write(Buffer^, BufferLen);
    FIndexList.Add(Pointer(FHeader.IndexOffset));
    Inc(FImageCount);
    Inc(FHeader.IndexOffset, BufferLen + SizeOf(TWMImageInfo));
    Result := True;
  end;
end;

function TWMMyImageImages.AddDataToFile(Offset: Integer; Buffer: PChar; BufferLen: Integer): Boolean;
begin
  Result := False;
  if FFileStream.Seek(Offset, 0) = Offset then begin
    FFileStream.Write(Buffer^, BufferLen);
    Result := True;
  end;
end;

function TWMMyImageImages.CopyDataToTexture(index: integer; Texture: TDXImageTexture): Boolean;
var
  nPosition: Integer;
  imginfo: TWMImageInfo;
  Buffer, outBuffer: PChar;
  ReadSize, nOutLen: Integer;
begin
  Result := False;
  if (index < 0) or (index >= FImageCount) or (Texture = nil) then
    exit;
  if index < FIndexList.Count then begin
    nPosition := Integer(FIndexList[index]);
    if FFileStream.Seek(nPosition, 0) <> nPosition then exit;
    FFileStream.Read(imginfo, SizeOf(imginfo));
    FormatImageInfo(@imginfo{$IFDEF WORKFILE}, False{$ENDIF});
    if (imginfo.nDataSize <= 0) then
      exit;

    if (imginfo.DXInfo.nWidth > MAXIMAGESIZE) or (imgInfo.DXInfo.nHeight > MAXIMAGESIZE) then
      Exit;
    if (imginfo.DXInfo.nWidth < MINIMAGESIZE) or (imgInfo.DXInfo.nHeight < MINIMAGESIZE) then
      Exit;
    ReadSize := imginfo.nDataSize;
    Buffer := AllocMem(ReadSize);
    outBuffer := nil;
    try
      if FFileStream.Read(Buffer^, ReadSize) = ReadSize then begin
        FormatDataBuffer(Buffer, ReadSize{$IFDEF WORKFILE}, False{$ENDIF});
        ZIPDecompress(Buffer, ReadSize, 0, outBuffer);
        FLastImageInfo := imginfo.DXInfo;
        FLastColorFormat := imgInfo.btImageFormat;
        Texture.Active := False;
        if ColorFormat[imginfo.btImageFormat] in [D3DFMT_R5G6B5] then Texture.Format := D3DFMT_A8R8G8B8
        else Texture.Format := ColorFormat[imginfo.btImageFormat];
        Texture.Size := Point(imginfo.DXInfo.nWidth, imginfo.DXInfo.nHeight);
        Texture.PatternSize := Point(imginfo.DXInfo.nWidth, imginfo.DXInfo.nHeight);
        Texture.Active := True;
        Result := CopyImageDataToTexture(outBuffer, Texture, imginfo.DXInfo.nWidth, imgInfo.DXInfo.nHeight, imginfo.btImageFormat);

        FreeMem(outBuffer);
      end;
    finally
      FreeMem(Buffer);
    end;
  end;
end;

procedure TWMMyImageImages.UpdateImageXY(index, nX, nY, nShadow, nShadowX, nShadowY: Integer);
var
  nPosition: Integer;
  ImageInfo: TWMImageInfo;
begin
  if (index < 0) or (index >= FImageCount)  then
    exit;
  if index < FIndexList.Count then begin
    nPosition := Integer(FIndexList[index]);
    if FFileStream.Seek(nPosition, 0) <> nPosition then exit;
    FFileStream.Read(ImageInfo, SizeOf(TWMImageInfo));
    FormatImageInfo(@ImageInfo{$IFDEF WORKFILE}, False{$ENDIF});
    FFileStream.Seek(-SizeOf(TWMImageInfo), soFromCurrent);
    ImageInfo.DXInfo.px := nX;
    ImageInfo.DXInfo.py := nY;
    ImageInfo.DXInfo.bShadow := nShadow;
    ImageInfo.DXInfo.shShadowPX := nShadowX;
    ImageInfo.DXInfo.shShadowPY := nShadowY;
    FormatImageInfo(@ImageInfo{$IFDEF WORKFILE}, True{$ENDIF});
    FFileStream.Write(ImageInfo, SizeOf(TWMImageInfo));
  end;
end;

function TWMMyImageImages.GetDataImageInfo(index: Integer): TWMImageInfo;
var
  nPosition: Integer;
begin
  SafeFillChar(Result, SizeOf(TWMImageInfo), #0);
  if (index < 0) or (index >= FImageCount)  then
    exit;
  if index < FIndexList.Count then begin
    nPosition := Integer(FIndexList[index]);
    if nPosition = 0 then exit;
    if FFileStream.Seek(nPosition, 0) <> nPosition then exit;
    FFileStream.Read(Result, SizeOf(TWMImageInfo));
    FormatImageInfo(@Result{$IFDEF WORKFILE}, False{$ENDIF});
  end;
end;

function TWMMyImageImages.GetDataOffset(index: Integer; boStart: Boolean): Integer;
begin
  Result := FHeader.IndexOffset;
  if (index < 0) or (index >= FImageCount) or (index >= FIndexList.Count) then
      exit;
  if boStart then begin
    while index >= 0 do begin
      Result := Integer(FIndexList[index]);
      if Result > 0 then exit;
      Dec(index);
    end;
    Result := SizeOf(FHeader);
  end else begin
    while index < FIndexList.Count do begin
      Result := Integer(FIndexList[index]);
      if Result > 0 then exit;
      Inc(index);
    end;
    Result := FHeader.IndexOffset;
  end;
end;

function TWMMyImageImages.GetImageBitmapEx(index: integer): TBitmap;
  function AlphaBlend(ScrCol: Word): Word;
  var
    Alpha: Byte;
    dR, dG, dB: Byte;
  begin
    Alpha := (ScrCol shr 12) and $0F;
    case Alpha of
      $00: Result := 0;
      $0F: begin
        Result := (((ScrCol shl 1) and $1E) or
          (((ScrCol shr 2) and $3C) shl 5) or
          (((ScrCol shr 7) and $1E) shl 11));
        if Result = 0 then
          Result := 2113;
      end
    else
      dB := 0;
      dG := 0;
      dR := 0;

      Result := ((Alpha * ((ScrCol shl 1) and $1E - dB) shr 4 + dB) or
        ((Alpha * ((ScrCol shr 2) and $3C - dG) shr 4 + dG) shl 5) or
        ((Alpha * ((ScrCol shr 7) and $1E - dR) shr 4 + dR) shl 11));
      if Result = 0 then
        Result := 2113;
    end;
  end;

  function Blend(ScrCol: Word): Word;
  var
    Alpha: Byte;
  begin
    Alpha := (ScrCol shr 15){(ScrCol and $8000)};
    if Alpha = 0 then begin
      Result := 0;
    end else begin
      Result := (((ScrCol shl 1) and $F800) or
                ((ScrCol and $3E0) shl 1) or
                (ScrCol and $1F));
      if Result = 0 then
        Result := 8;
    end;
  end;
var
  nPosition: Integer;
  imginfo: TWMImageInfo;
  Buffer, DecodeBuffer, outBuffer: PChar;
  wWriteBuffer, wReadBuffer: PWord;
  dwWriteBuffer, dwReadBuffer: PDWord;
  ReadSize, nOutLen: Integer;
  Y, X: Integer;
  bitLength: Byte;
begin
  Result := nil;

  if (index < 0) or (index >= FImageCount) then
    exit;
  if index < FIndexList.Count then begin
    nPosition := Integer(FIndexList[index]);
    if FFileStream.Seek(nPosition, 0) <> nPosition then exit;
    FFileStream.Read(imginfo, SizeOf(imginfo));
    FormatImageInfo(@imginfo{$IFDEF WORKFILE}, False{$ENDIF});

    if (imginfo.nDataSize <= 0) then
      exit;

    if (imginfo.DXInfo.nWidth > MAXIMAGESIZE) or (imgInfo.DXInfo.nHeight > MAXIMAGESIZE) then
      Exit;
    if (imginfo.DXInfo.nWidth < MINIMAGESIZE) or (imgInfo.DXInfo.nHeight < MINIMAGESIZE) then
      Exit;
    ReadSize := imginfo.nDataSize;
    Buffer := AllocMem(ReadSize);
    outBuffer := nil;
    try
      if FFileStream.Read(Buffer^, ReadSize) = ReadSize then begin
        FormatDataBuffer(Buffer, ReadSize{$IFDEF WORKFILE}, False{$ENDIF});
        ZIPDecompress(Buffer, ReadSize, 0, outBuffer);
        FLastImageInfo := imginfo.DXInfo;
        FLastColorFormat := imginfo.btImageFormat;
        bitLength := GetFormatBitLen(imginfo.btImageFormat);

        Result := TBitmap.Create;
        if imginfo.btImageFormat in [WILFMT_A4R4G4B4, WILFMT_A1R5G5B5, WILFMT_R5G6B5] then
        begin
          Result.PixelFormat := pf16bit;
          Result.Width := imginfo.DXInfo.nWidth;
          Result.Height := imginfo.DXInfo.nHeight;
          for Y := 0 to Result.Height - 1 do begin
            wWriteBuffer := Result.ScanLine[Y];
            wReadBuffer := @outBuffer[Y * Result.Width * bitLength];
            for X := 0 to Result.Width - 1 do begin
              case imginfo.btImageFormat of
                WILFMT_A4R4G4B4: wWriteBuffer^ := AlphaBlend(wReadBuffer^);
                WILFMT_A1R5G5B5: wWriteBuffer^ := Blend(wReadBuffer^);
                WILFMT_R5G6B5: begin
                  if wReadBuffer^ = 255 then wWriteBuffer^ := 2113
                  else wWriteBuffer^ := wReadBuffer^;
                end;
              end;
              Inc(wWriteBuffer);
              Inc(wReadBuffer);
            end;
          end;
        end
        else if (imginfo.btImageFormat in [WILFMT_A8R8G8B8]) then
        begin
          Result.PixelFormat := pf32bit;
          Result.Width := imginfo.DXInfo.nWidth;
          Result.Height := imginfo.DXInfo.nHeight;
          for Y := 0 to Result.Height - 1 do begin
            dwWriteBuffer := Result.ScanLine[Y];
            dwReadBuffer := @outBuffer[Y * Result.Width * bitLength];
            CopyMemory(dwWriteBuffer, dwReadBuffer, Result.Width * SizeOf(LongWord));
          end;
        end;
        FreeMem(outBuffer);
      end;
    finally
      FreeMem(Buffer);
    end;
  end;
end;

procedure TWMMyImageImages.GetImageXY(index: Integer; out nX, nY: Integer);
var
  nPosition: Integer;
  imginfo: TWMImageInfo;
begin
  nX := 0;
  nY := 0;
  if (index < 0) or (index >= FImageCount)  then
    exit;
  if index < FIndexList.Count then begin
    nPosition := Integer(FIndexList[index]);
    if FFileStream.Seek(nPosition, 0) <> nPosition then exit;
    if FFileStream.Read(imginfo, SizeOf(TWMImageInfo)) = SizeOf(TWMImageInfo) then begin
      FormatImageInfo(@imginfo{$IFDEF WORKFILE}, False{$ENDIF});
      nX := imginfo.DXInfo.px;
      nY := imginfo.DXInfo.py;
    end;
  end;
end;

procedure TWMMyImageImages.InsertOffsetToList(OffList: TList; index, StartPos, OffsetPos: Integer);
var
  i: integer;
  nPos: Integer;
begin
  for I := 0 to OffList.Count - 1 do begin
    nPos := Integer(OffList[I]);
    if nPos = -1 then FIndexList.Insert(index + I, nil)
    else FIndexList.Insert(index + I, Pointer(nPos + StartPos));
  end;
  while (index + Offlist.Count) < FindexList.Count do begin
    nPos := Integer(FindexList[index + Offlist.Count]);
    if nPos > 0 then
      FindexList[index + Offlist.Count] := Pointer(nPos + OffsetPos);
    Inc(index);
  end;
  FImageCount := FIndexList.Count;
  FHeader.ImageCount := FImageCount;
  Inc(FHeader.IndexOffset, OffsetPos);
end;

procedure TWMMyImageImages.UpdateOffsetToList(OffList: TList; index, StartPos, OffsetPos: Integer);
var
  i: integer;
  nPos: Integer;
begin
  i := 0;
  while index < FindexList.Count do begin
    if i < OffList.Count then begin
      nPos := Integer(OffList[I]);
      if nPos = -1 then FindexList[index] := nil
      else FindexList[index] := Pointer(nPos + StartPos);
    end else begin
      nPos := Integer(FindexList[index]);
      if nPos > 0 then
        FindexList[index] := Pointer(nPos + OffsetPos);
    end;
    Inc(index);
    Inc(I);
  end;
  Inc(FHeader.IndexOffset, OffsetPos);
end;

procedure TWMMyImageImages.ChangeOffsetToList(Startindex, Endindex, ChangePos: Integer; boDel: Boolean);
var
  index: Integer;
  nPos: Integer;
begin
  if ChangePos > 0 then begin
    index := Endindex + 1;
    while index < FindexList.Count do begin
      nPos := Integer(FindexList[index]);
      if nPos > 0 then begin
        Dec(nPos, ChangePos);
        FindexList[index] := Pointer(nPos);
      end;
      Inc(index);
    end;
    Dec(FHeader.IndexOffset, ChangePos);
  end;
  for index := Endindex downto Startindex do begin
    if boDel then FindexList.Delete(index)
    else FindexList[index] := nil;
  end;
  FImageCount := FIndexList.Count;
  FHeader.ImageCount := FImageCount;
end;

function TWMMyImageImages.GetOffsetIndex(): Integer;
var
  I: Integer;
  nOffset: Integer;
  imginfo: TWMImageInfo;
begin
  Result := SizeOf(FHeader);
  for I := FIndexList.Count - 1 downto 0 do begin
    nOffset := Integer(FIndexList[I]);
    if nOffset > 0 then begin
      if (FFileStream.Seek(nOffset, 0) <> nOffset) then Continue;
      FFileStream.Read(imginfo, SizeOf(imginfo));
      Result := nOffset + imginfo.nDataSize + SizeOf(imginfo);
      Exit;
    end;
  end;
end;

function TWMMyImageImages.SaveIndexList: Boolean;
var
  OffsetBuffer, SaveOffsetBuffer: PChar;
  OffsetSize: Integer;
begin
  Result := False;
  FHeader.ImageCount := FIndexList.Count;
  FHeader.IndexOffset := GetOffsetIndex();
  if FIndexList.Count > 0 then begin
    FFileStream.Seek(FHeader.IndexOffset, soFromBeginning);
    OffsetSize := (FIndexList.Count + 10) * SizeOf(Integer);
    GetMem(OffsetBuffer, OffsetSize);
    Try
      Move(FIndexList.List^, OffsetBuffer[SizeOf(Integer) * 10], OffsetSize - SizeOf(Integer) * 10);
      OffsetSize := ZIPCompress(OffsetBuffer, OffsetSize, 9, SaveOffsetBuffer);
      if SaveOffsetBuffer <> nil then begin
        FHeader.OffsetSize := OffsetSize;
        FFileStream.Write(SaveOffsetBuffer^, OffsetSize);
        FreeMem(SaveOffsetBuffer);
      end else begin
        FHeader.OffsetSize := 0;
        FFileStream.Write(FIndexList.List[0], FIndexList.Count * SizeOf(Pointer));
      end;
      FFileStream.Seek(0, soFromBeginning);
      FormatHeader(@FHeader{$IFDEF WORKFILE}, True{$ENDIF});
      if FCanEncry then begin
        FHeader.ImageCount2 := FHeader.ImageCount;
        FHeader.ImageCount := 0;
      end;
      FFileStream.Write(FHeader, SizeOf(FHeader));
      FHeader.IndexOffset := GetOffsetIndex();
      Result := True;
    Finally
      FreeMem(OffsetBuffer);
    End;
  end;
end;
{$ENDIF}

end.

