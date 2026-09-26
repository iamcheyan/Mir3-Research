unit wmM3Zip;

interface
uses
  Windows, Classes, Graphics, SysUtils, HGETextures, HUtil32, WIL, DirectXGraphics, ZLibEx, Forms, Dialogs, HGE;

type
  PWilHeader = ^TWMImageHeader;
  TWMImageHeader = packed record
    Title      : string[20];
    ImageCount : Integer;
  end;

  { Wil 图片信息 }
  PWilImageInfo = ^TWMImageInfo;
  TWMImageInfo = packed record
    nWidth        : SmallInt;
    nHeight       : SmallInt;
    Px           : SmallInt;
    Py           : SmallInt;
    ShadowPX     : SmallInt;
    ShadowPY     : SmallInt;
    Shadow       : Byte;
    CompressedLen: Integer;
  end;

  { Wix 文件头结构 }
  PWixHeader = ^TWMIndexHeader;
  TWMIndexHeader = packed record
    Title     : string[20];
    IndexCount: Integer;
  end;

  TWMM3ZipImages = class(TWMBaseImages)
  private
    FHeader: TWMImageHeader;
    FIdxHeader: TWMIndexHeader;
    FIdxFile: string;
    procedure LoadIndex(idxfile: string);
    function CopyImageDataToTexture(Buffer: PChar; Texture: TDXImageTexture; Width, Height: Word): Boolean;
  protected
    procedure LoadDxImage(index: Integer; position: integer; pDXTexture: pTDXTextureSurface); override;
  public
    constructor Create(); override;
    function Initialize(): Boolean; override;
    procedure Finalize; override;
  end;
  procedure LineR5G6B5_A8R8G8B8(Source:Word; Alpha:Byte; var Dest: LongWord);

implementation

{ TWMM2KrImages }

procedure LineR5G6B5_A8R8G8B8(Source:Word; Alpha:Byte; var Dest: LongWord);
var
  r:Byte;
  g:Byte;
  b:Byte;
begin
  r:= ((Source and $f800) shr 8);
  g:= ((Source and $07e0) shr 3);
  b:= ((Source and $001f) shl 3);
  Dest:= (Alpha shl 24) or (r shl 16) or (g shl 8) or (b);
end;

function TWMM3ZipImages.CopyImageDataToTexture(Buffer: PChar; Texture: TDXImageTexture; Width, Height: Word): Boolean;
var
  X, Y: Integer;
  nColorId:Integer;
  cbMask:Byte;
  cbAlpha:Byte;
  wCol16:Word;
  pdwColor:PDWORD;
  cbHigh, cbLow:Byte;
  maskBase:Integer;
  maskId:Integer;
  dwColor:LongWord;
  Access: TDXAccessInfo;
  WriteBuffer, ReadBuffer: PByte;
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

constructor TWMM3ZipImages.Create;
begin
  inherited;
  FReadOnly := True;
end;

procedure TWMM3ZipImages.Finalize;
begin
  inherited;
end;

function TWMM3ZipImages.Initialize: Boolean;
begin
  Result := inherited Initialize;
  if Result then begin
    FFileStream.Read(FHeader, SizeOf(TWMImageHeader));
    FImageCount := FHeader.ImageCount;
    FIdxFile := ExtractFilePath(FFileName) + ExtractFileNameOnly(FFileName) + '.Idx';
    LoadIndex(FIdxFile);
    InitializeTexture;
  end;
end;

function KorZIPDecompress(const InBuf: Pointer; InBytes: Integer; OutEstimate: Integer; out OutBuf: PChar): Integer;
var
  outlen: integer;
begin
//  ZDecompress2(Pointer(inbuf), inbytes, Pointer(outbuf), outlen, -15, outEstimate);
//  Result := outlen;
end;

procedure TWMM3ZipImages.LoadDxImage(index: Integer; position: integer; pDXTexture: pTDXTextureSurface);
var
  imginfo: TWMImageInfo;
  inBuffer, outBuffer: PChar;
  nLen, nOutLen: Integer;
  SrcP:PByte;
  S: Pointer;
begin
  pDXTexture.boNotRead := True;
  if FFileStream.Seek(position, 0) = position then begin;
    FFileStream.Read(imginfo, SizeOf(TWMImageInfo));
    if (imginfo.nWidth > MAXIMAGESIZE) or (imgInfo.nHeight > MAXIMAGESIZE) then
      Exit;
    if (imginfo.nWidth < MINIMAGESIZE) or (imgInfo.nHeight < MINIMAGESIZE) then
      Exit;

    nLen := WidthBytes(16, imginfo.nWidth);

    if (imginfo.CompressedLen <= 0) then exit;
    GetMem(inBuffer, imginfo.CompressedLen);
    FFileStream.Read(inBuffer^, 6);
    outBuffer := nil;
        ///KorZIPDecompress(inBuffer, imginfo.nSize - 6, 0, outBuffer);
    try
      if FFileStream.Read(inBuffer^, imginfo.CompressedLen - 6) = imginfo.CompressedLen - 6 then begin
       // ZDecompress2(Pointer(inBuffer), imginfo.nSize - 6, Pointer(outBuffer), nLen, -15, 0);
        DecompressBuf(Pointer(inBuffer), imginfo.CompressedLen - 6, 0, Pointer(outBuffer), nOutLen);
//        KorZIPDecompress(inBuffer, imginfo.CompressedLen - 6, 0, outBuffer);
        pDXTexture.Surface := MakeDXImageTexture(imginfo.nWidth, imginfo.nHeight, WILFMT_A8R8G8B8);

        if pDXTexture.Surface <> nil then begin
          if not CopyImageDataToTexture(outBuffer, pDXTexture.Surface, nLen, imginfo.nHeight) then
          begin
            pDXTexture.Surface.Free;
            pDXTexture.Surface := nil;
          end
          else begin
            pDXTexture.boNotRead := False;
            pDXTexture.nPx := imginfo.px;
            pDXTexture.nPy := imginfo.py;
            pDXTexture.nsPx := imginfo.ShadowPX;
            pDXTexture.nsPy := imginfo.ShadowPY;
            pDXTexture.nShadow := imginfo.Shadow;
          end;
        end;
      end;
      FreeMem(outBuffer);
    finally
      FreeMem(inBuffer);
    end;
  end;
end;

procedure TWMM3ZipImages.LoadIndex(idxfile: string);
var
  fhandle, i, value: integer;
  pvalue: PInteger;
begin
  FIndexList.Clear;
  FImageCount := 0;
  if FileExists(idxfile) then begin
    fhandle := FileOpen(idxfile, fmOpenRead or fmShareDenyNone);
    if fhandle > 0 then begin
      FileSeek(fHandle, 0, 0);
      FileRead(fhandle, FIdxHeader, sizeof(TWMIndexHeader));
      if FIdxHeader.IndexCount > MAXIMAGECOUNT then exit;
      GetMem(pvalue, 4 * FIdxHeader.IndexCount);
      if FileRead(fhandle, pvalue^, 4 * FIdxHeader.IndexCount) = (4 * FIdxHeader.IndexCount) then begin
        for i := 0 to FIdxHeader.IndexCount - 1 do begin
          value := PInteger(integer(pvalue) + 4 * i)^;
          FIndexList.Add(pointer(value));
        end;
      end;
      FreeMem(pvalue);
      FileClose(fhandle);
    end;
    FImageCount := FIndexList.Count;
  end;
end;

end.

