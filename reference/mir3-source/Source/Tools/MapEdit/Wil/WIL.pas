unit WIL;

interface

uses
  Windows, Classes, Graphics, SysUtils, DirectXGraphics, HGETextures, HUtil32,
  ZLib, HGECanvas;

{$INCLUDE BitChange.inc}

type
  TWILColorFormat = (WILFMT_A4R4G4B4, WILFMT_A1R5G5B5, WILFMT_R5G6B5, WILFMT_A8R8G8B8);

const
  MAXIMAGECOUNT = 10000000;
  MINIMAGESIZE = 1;
  MAXIMAGESIZE = 4096;
  //位移宽高，进行加密
  //图像最大宽高不能大于 4095 不然会出错，要修改位移时的处理

  FILETYPE_IMAGE = $1F; //图像文件
  FILETYPE_DATA = $2F; //数据文件
  FILETYPE_WAVA = $3F; //WAVA文件
  FILETYPE_MP3 = $4F; //MP3文件

  ColorFormat: array[TWILColorFormat] of TD3DFormat = (D3DFMT_A4R4G4B4, D3DFMT_A1R5G5B5, D3DFMT_R5G6B5, D3DFMT_A8R8G8B8);
type
  PRGBQuads = ^TRGBQuads;
  TRGBQuads = array[0..255] of TRGBQuad;
  TColorEffect = (ceNone, ceGrayScale, ceBright, ceRed, ceGreen, ceBlue, ceYellow, ceFuchsia);
  TDataType = (dtAll, dtMusic, dtData, dtMP3, dtWav);
  TLibType = (ltLoadBmp, ltUseCache, ltFileData);
  TWILType = (t_wmMyImage, t_wmM3Def);

  TZIPLevel = 0..9;

  pTDXTextureSurface = ^TDXTextureSurface;

  TDXTextureSurface = packed record
    nPx: Smallint;
    nPy: Smallint;
    nsPx: Smallint;
    nsPy: Smallint;
    nShadow: Byte;
    Surface: TDXImageTexture;
    dwLatestTime: LongWord;
    boNotRead: Boolean;
  end;

  TDXTextureInfo = packed record
    nWidth: Word;
    nHeight: Word;
    px: Smallint;
    py: Smallint;
    bShadow: Byte;
    shShadowPX: Smallint;
    shShadowPY: Smallint;
  end;

  pTDXTextureInfo = ^TDXTextureInfo;

  TWMBaseImages = class
  private
    FAutoFreeMemorys: Boolean;
    FAutoFreeMemorysTick: LongWord;
    FAutoFreeMemorysTime: LongWord;
    FFreeSurfaceTick: LongWord;
    FWILType: TWILType;
    function GetImageSurface(index: Integer): TDXImageTexture;
{$IFDEF WORKFILE}
    function GetImageBitmap(index: Integer): TBitmap;
{$ENDIF}
  protected
    FLibType: TLibType;
    FSurfaceCount: Integer;
{$IFDEF WORKFILE}
    FLastImageInfo: TDXTextureInfo;
    FLastColorFormat: TWILColorFormat;
{$ENDIF}
    FFileName: string;
    FPassword: string;
    FInitialize: Boolean;
    FImageCount: Integer;
    FReadOnly: Boolean;
    FboEncryVer: Boolean;
    FFileStream: TFileStream;
    FDxTextureArr: array of TDXTextureSurface;

{$IFDEF WORKFILE}
    function GetImageBitmapEx(index: Integer): TBitmap; dynamic;
{$ENDIF}
    function InitializeTexture(): Boolean;
    procedure LoadDxImage(index: Integer; position: Integer; pDXTexture:
      pTDXTextureSurface); dynamic;
    function GetFormatBitLen(AFormat: TWILColorFormat): Byte;
  public
    FIndexList: TList;
    m_DefMainPalette: TRgbQuads;
    constructor Create(); dynamic;
    destructor Destroy; override;
    function Initialize(): Boolean; dynamic;
    procedure Finalize; dynamic;
    procedure FreeTexture;
    procedure FreeTextureByTime;
    function GetCachedImage(index: Integer; var px, py: Integer): TDXImageTexture;

{$IFDEF WORKFILE}
    procedure DrawZoom(paper: TCanvas; x, y, index: Integer; zoom: Real);
    procedure DrawZoomEx(paper: TCanvas; x, y, index: Integer; zoom: Real;
      leftzero: Boolean);
    function CopyDataToTexture(index: Integer; Texture: TDXImageTexture):
      Boolean; dynamic;
    property Bitmap[index: Integer]: TBitmap read GetImageBitmap;
    procedure AddIndex(nIndex, nOffset: Integer); dynamic;
    function SaveIndexList(): Boolean; dynamic;
    property LastImageInfo: TDXTextureInfo read FLastImageInfo;
    property LastColorFormat: TWILColorFormat read FLastColorFormat;
    property FileStream: TFileStream read FFileStream;
{$ENDIF}

    property boInitialize: Boolean read FInitialize;
    property ImageCount: Integer read FImageCount;
    property FileName: string read FFileName write FFileName;
    property Password: string read FPassword write FPassword;
    property LibType: TLibType read FLibType write FLibType;
    property EncryVer: Boolean read FboEncryVer;
    property SurfaceCount: Integer read FSurfaceCount;
    property ReadOnly: Boolean read FReadOnly;
    property Images[index: Integer]: TDXImageTexture read GetImageSurface;
    property AutoFreeMemorys: Boolean read FAutoFreeMemorys write FAutoFreeMemorys;
    property AutoFreeMemorysTick: LongWord read FAutoFreeMemorysTick write
      FAutoFreeMemorysTick;
    property FreeSurfaceTick: LongWord read FFreeSurfaceTick write FFreeSurfaceTick;
    property WILType: TWILType read FWILType write FWILType;
  end;

  TWMImages = TWMBaseImages;

function CreateWMImages(WILType: TWILType): TWMBaseImages;

function ZIPCompress(const InBuf: Pointer; InBytes: Integer; Level: TZIPLevel;
  out OutBuf: PChar): Integer;

function ZIPDecompress(const InBuf: Pointer; InBytes: Integer; OutEstimate:
  Integer; out OutBuf: PChar): Integer;

function MakeDXImageTexture(nWidth, nHeight: Word; WILColorFormat:
  TWILColorFormat): TDXImageTexture;

function WidthBytes(nBit, nWidth: Integer): Integer;

function RGB16(r, G, b: Integer): Word;
procedure TColor2RGB(const Color: TColor; var R, G, B: Byte);

var
  g_OutBackColor: TColor = clFuchsia;

implementation

uses
  wmM3Def, wmMyImage;



function RGB16(r, G, b: Integer): Word;
begin
  Result := Word((b and $F8) shr 3 or (G and $FC) shl 3 or (r and $F8) shl 8);
end;

procedure TColor2RGB(const Color: TColor; var R, G, B: Byte);
begin
  R := Color and $FF;
  G := (Color and $FF00) shr 8;
  B := (Color and $FF0000) shr 16;
end;

function WidthBytes(nBit, nWidth: Integer): Integer;
begin
  Result := (((nWidth * nBit) + 31) shr 5) * 4;
end;

function CreateWMImages(WILType: TWILType): TWMBaseImages;
begin
  Result := nil;
  case WILType of
    t_wmMyImage:
      Result := TWMMyImageImages.Create;
    t_wmM3Def:
      Result := TWMM3DefImages.Create;
  end;
end;

function CCheck(code: Integer): Integer;
begin
  Result := code;
  if code < 0 then
    raise ECompressionError.Create('ZIP Error'); //!!
end;

function DCheck(code: Integer): Integer;
begin
  Result := code;
  if code < 0 then
    raise EDecompressionError.Create('ZIP Error'); //!!
end;

function ZIPCompress(const InBuf: Pointer; InBytes: Integer; Level: TZIPLevel;
  out OutBuf: PChar): Integer;
var
  strm: TZStreamRec;
  P: Pointer;
begin
  SafeFillChar(strm, SizeOf(strm), 0);
  strm.zalloc := zlibAllocMem;
  strm.zfree := zlibFreeMem;
  Result := ((InBytes + (InBytes div 10) + 12) + 255) and not 255;
  GetMem(OutBuf, Result);
  try
    strm.next_in := InBuf;
    strm.avail_in := InBytes;
    strm.next_out := OutBuf;
    strm.avail_out := Result;
    CCheck(deflateInit_(strm, Level, zlib_Version, SizeOf(strm)));
    try
      while CCheck(deflate(strm, Z_FINISH)) <> Z_STREAM_END do begin
        P := OutBuf;
        Inc(Result, 256);
        ReallocMem(OutBuf, Result);
        strm.next_out := PChar(Integer(OutBuf) + (Integer(strm.next_out) - Integer(P)));
        strm.avail_out := 256;
      end;
    finally
      CCheck(deflateEnd(strm));
    end;
    ReallocMem(OutBuf, strm.total_out);
    Result := strm.total_out;
  except
    FreeMem(OutBuf);
    OutBuf := nil;
    //raise
  end;
end;

function ZIPDecompress(const InBuf: Pointer; InBytes: Integer; OutEstimate:
  Integer; out OutBuf: PChar): Integer;
var
  strm: TZStreamRec;
  P: Pointer;
  BufInc: Integer;
begin
  SafeFillChar(strm, SizeOf(strm), 0);
  strm.zalloc := zlibAllocMem;
  strm.zfree := zlibFreeMem;
  BufInc := (InBytes + 255) and not 255;
  if OutEstimate = 0 then
    Result := BufInc
  else
    Result := OutEstimate;
  GetMem(OutBuf, Result);
  try
    strm.next_in := InBuf;
    strm.avail_in := InBytes;
    strm.next_out := OutBuf;
    strm.avail_out := Result;
    DCheck(inflateInit_(strm, zlib_Version, SizeOf(strm)));
    try
      while DCheck(inflate(strm, Z_FINISH)) <> Z_STREAM_END do begin
        P := OutBuf;
        Inc(Result, BufInc);
        ReallocMem(OutBuf, Result);
        strm.next_out := PChar(Integer(OutBuf) + (Integer(strm.next_out) - Integer(P)));
        strm.avail_out := BufInc;
      end;
    finally
      DCheck(inflateEnd(strm));
    end;
    ReallocMem(OutBuf, strm.total_out);
    Result := strm.total_out;
  except
    FreeMem(OutBuf);
    OutBuf := nil;
    //raise
  end;
end;

{ TWMBaseImages }
constructor TWMBaseImages.Create;
begin
  inherited;
  FInitialize := False;
  FImageCount := 0;
  FFileName := '';
  FReadOnly := True;
  FAutoFreeMemorys := False;
  FAutoFreeMemorysTick := 10 * 1000;
  FFreeSurfaceTick := 60 * 1000;
  FAutoFreeMemorysTime := GetTickCount;
  FFileStream := nil;
  FDxTextureArr := nil;
  FIndexList := TList.Create;
  FSurfaceCount := 0;
  FPassword := '';
{$IFDEF WORKFILE}
  SafeFillChar(FLastImageInfo, SizeOf(FLastImageInfo), #0);
{$ENDIF}
  FLibType := ltUseCache;
end;

procedure TWMBaseImages.FreeTexture;
var
  i: Integer;
begin
  if FDxTextureArr <> nil then
    for i := 0 to High(FDxTextureArr) do begin
      if FDxTextureArr[i].Surface <> nil then begin
        FDxTextureArr[i].Surface.Free;
        FDxTextureArr[i].Surface := nil;
      end;
    end;
  FSurfaceCount := 0;
end;

procedure TWMBaseImages.FreeTextureByTime;
var
  i: Integer;
begin
  if FDxTextureArr <> nil then
    for i := 0 to High(FDxTextureArr) do begin
      if (FDxTextureArr[i].Surface <> nil) and (GetTickCount - FDxTextureArr[i].dwLatestTime
        > FFreeSurfaceTick) then begin
        if FSurfaceCount > 0 then
          Dec(FSurfaceCount);
        FDxTextureArr[i].Surface.Free;
        FDxTextureArr[i].Surface := nil;
      end;
    end;
end;

destructor TWMBaseImages.Destroy;
begin
  Finalize;
  FDxTextureArr := nil;
  FIndexList.Free;
  inherited;
end;

function TWMBaseImages.GetCachedImage(index: Integer; var px, py: Integer):
  TDXImageTexture;
begin
  Result := nil;
  if (index < 0) or (index >= FImageCount) or (FLibType <> ltUseCache) or (not
    FInitialize) then
    Exit;
  if (index < FIndexList.Count) then begin
    if (FDxTextureArr[index].Surface = nil) and (not FDxTextureArr[index].boNotRead)
      then begin
      try
        LoadDxImage(index, Integer(FIndexList[index]), @FDxTextureArr[index]);
        if FDxTextureArr[index].Surface <> nil then
          Inc(FSurfaceCount);
      except
        FDxTextureArr[index].Surface := nil;
        FDxTextureArr[index].boNotRead := True;
      end;
    end;
    Result := FDxTextureArr[index].Surface;
    px := FDxTextureArr[index].nPx;
    py := FDxTextureArr[index].nPy;
    FDxTextureArr[index].dwLatestTime := GetTickCount;
  end;
  if AutoFreeMemorys and (GetTickCount > FAutoFreeMemorysTime) then begin
    FAutoFreeMemorysTime := GetTickCount + FAutoFreeMemorysTick;
    FreeTextureByTime;
  end;
end;

procedure TWMBaseImages.Finalize;
begin
  FInitialize := False;
  FreeTexture;
  FDxTextureArr := nil;
  FSurfaceCount := 0;
  if FFileStream <> nil then
    FFileStream.Free;
  FFileStream := nil;
end;

function TWMBaseImages.GetImageSurface(index: Integer): TDXImageTexture;
var
  px, py: Integer;
begin
  Result := GetCachedImage(index, px, py);
end;

function TWMBaseImages.GetFormatBitLen(AFormat: TWILColorFormat): Byte;
begin
  if AFormat in [WILFMT_A4R4G4B4, WILFMT_A1R5G5B5, WILFMT_R5G6B5] then
    Result := 2
  else
    Result := 4;
end;

function TWMBaseImages.Initialize: Boolean;
begin
  Result := False;
  if (FFileName = '') or FInitialize or (FFileStream <> nil) or (not FileExists(FFileName))
    then
    Exit;
{$IFDEF WORKFILE}
  if FReadOnly then
    FFileStream := TFileStream.Create(FFileName, fmOpenRead or fmShareDenyNone)
  else
    FFileStream := TFileStream.Create(FFileName, fmOpenReadWrite or fmShareDenyNone);
{$ELSE}
  FFileStream := TFileStream.Create(FFileName, fmOpenRead or fmShareDenyNone);
{$ENDIF}
  Result := FFileStream <> nil;
  FInitialize := Result;
  if Result then begin
    FreeTexture;
    FDxTextureArr := nil;
    FSurfaceCount := 0;
  end;
end;

function TWMBaseImages.InitializeTexture: Boolean;
begin
  Result := False;
  FDxTextureArr := nil;
  if (not FInitialize) or (FImageCount <= 0) or (LibType <> ltUseCache) then
    Exit;
  SetLength(FDxTextureArr, FImageCount);
  SafeFillChar(FDxTextureArr[0], FImageCount * SizeOf(TDXTextureSurface), #0);
  Result := True;
end;

procedure TWMBaseImages.LoadDxImage(index: Integer; position: Integer;
  pDXTexture: pTDXTextureSurface);
begin
  if pDXTexture.Surface <> nil then
    pDXTexture.Surface.Free;
  pDXTexture.Surface := nil;
  pDXTexture.boNotRead := True;
end;

function MakeDXImageTexture(nWidth, nHeight: Word; WILColorFormat:
  TWILColorFormat): TDXImageTexture;
begin
  Result := TDXImageTexture.Create;
  with Result do begin
    SIZE := Point(nWidth, nHeight);
    PatternSize := Point(nWidth, nHeight);
    Format := {D3DFMT_A4R4G4B4} ColorFormat[WILColorFormat];
    Active := True;
  end;
  if not Result.Active then begin
    Result.Free;
    Result := nil;
  end;
end;

//工作区-----------------------------------------------------------------------------------------------------------------
{$IFDEF WORKFILE}
procedure TWMBaseImages.DrawZoom(paper: TCanvas; x, y, index: Integer; zoom: Real);
var
  rc: TRect;
  bmp: TBitmap;
begin
  if LibType <> ltLoadBmp then
    Exit;
  bmp := Self.Bitmap[index];
  if bmp <> nil then begin
    rc.Left := x;
    rc.Top := y;
    rc.Right := x + Round(bmp.Width * zoom);
    rc.Bottom := y + Round(bmp.Height * zoom);
    if (rc.Right > rc.Left) and (rc.Bottom > rc.Top) then begin
      paper.StretchDraw(rc, bmp);
      //FreeBitmap(index);
    end;
    bmp.Free;
  end;
end;

procedure TWMBaseImages.DrawZoomEx(paper: TCanvas; x, y, index: Integer; zoom:
  Real; leftzero: Boolean);
var
  rc: TRect;
  bmp, bmp2: TBitmap;
begin
  if LibType <> ltLoadBmp then
    Exit;
  bmp := Self.Bitmap[index];
  if bmp <> nil then begin
    bmp2 := TBitmap.Create;
    bmp2.Width := Round(bmp.Width * zoom);
    bmp2.Height := Round(bmp.Height * zoom);
    rc.Left := x;
    rc.Top := y;
    rc.Right := x + Round(bmp.Width * zoom);
    rc.Bottom := y + Round(bmp.Height * zoom);
    if (rc.Right > rc.Left) and (rc.Bottom > rc.Top) then begin
      bmp2.Canvas.StretchDraw(Rect(0, 0, bmp2.Width, bmp2.Height), bmp);
      if leftzero then begin
        SpliteBitmap(paper.Handle, x, y, bmp2, $0)
      end
      else begin
        SpliteBitmap(paper.Handle, x, y - bmp2.Height, bmp2, $0);
      end;
    end;
    bmp.Free;
    bmp2.Free;
  end;
end;

function TWMBaseImages.SaveIndexList(): Boolean;
begin
  Result := False;
end;

function TWMBaseImages.GetImageBitmapEx(index: Integer): TBitmap;
begin
  Result := nil;
end;

function TWMBaseImages.GetImageBitmap(index: Integer): TBitmap;
begin
  Result := GetImageBitmapEx(index);
end;

procedure TWMBaseImages.AddIndex(nIndex, nOffset: Integer);
begin
  if FReadOnly or (not FInitialize) or ((nIndex > -1) and (nIndex > FIndexList.Count))
    then
    Exit;
  if nIndex = -1 then
    FIndexList.Add(Pointer(nOffset))
  else
    FIndexList.Insert(nIndex, Pointer(nOffset));
  Inc(FImageCount);
end;

function TWMBaseImages.CopyDataToTexture(index: Integer; Texture:
  TDXImageTexture): Boolean;
begin
  Result := False;
end;
{$ENDIF}

end.

