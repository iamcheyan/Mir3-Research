unit wmM3Def;

interface
uses
  Windows, Classes, Graphics, SysUtils, HGETextures,HGEBase, HUtil32, WIL, DirectXGraphics, HGE, Math;

const
  _OLD_VER	=	17;
  _NEW_VER	=	5000;
  _WTL_VER	=	6000;

  _WIL_VER: integer	=	20020;
  _WIX_VER: integer	=	20021;

  _WIL_MAGIC_CODE	= $C02A1173;
  _WIX_MAGIC_CODE	= $B13A11F0;

  _F32FMTREAD = True;
  _READTEXTURE = 0;

var
  NewVerSign        : DWORD;

type
  TNewWilFileImageInfo = packed record
    shWidth: Smallint;
    shHeight: Smallint;
    shPX: Smallint;
    shPY: SmallInt;
    bShadow: Byte;
    shShadowPX: SmallInt;
    shShadowPY: SmallInt;
    dwImageLength: Integer;
    shVer: Integer;
  end;
  PTNewWilFileImageInfo = ^TNewWilFileImageInfo;

  TWilFileHerder = Packed Record
    shComp: Smallint;
    szTitle: array[0..19] of Char;
    shVer: Smallint;
    nImageCount: Integer;
  end;
  PTWilFileHerder = ^TWilFileHerder;

  TNewWixFileImageInfo = packed record
    szTitle: array[0..19] of Char;
    nIndexCount: integer;
    pnPosition: integer;
  end;
  PTWMIndexHeader = ^TNewWixFileImageInfo;

  TWMM3DefImages = class(TWMBaseImages)
  private
    FIdxHeader: TNewWixFileImageInfo;
    FIdxFile: string;
    m_bNewVer: Boolean;

    procedure LoadIndex(idxfile: string);
    procedure LoadMemoryMap;
    function Decode(Source, Target: PChar; Width, Height: Integer): Boolean;
    function CopyImageDataToTexture(Buffer: PChar; Texture: TDirectDrawSurface; Width, Height: Word; ReadMode:Boolean): Boolean;
  protected
    procedure LoadDxImage(index: Integer; position: integer; pDXTexture: pTDXTextureSurface); override;
  public
    constructor Create(); override;
    function Initialize(): Boolean; override;
    procedure Finalize; override;
  end;
{$IF _READTEXTURE = 1}
var
  FHGE: IHGE = nil;
{$IFEND}

implementation

{ TWMM3DefImages }

function TWMM3DefImages.CopyImageDataToTexture(Buffer: PChar; Texture: TDirectDrawSurface; Width, Height: Word; ReadMode: Boolean): Boolean;
var
  X, Y: Integer;
  nColorId:LongWord;
  wCol16:Word;
  pdwColor:PDWORD;
  dwColor:LongWord;
  Access: TDXAccessInfo;
  cbAlpha:Byte;
  WriteBuffer, ReadBuffer: PChar;
begin
  Result := False;
  if Texture.Lock(lfWriteOnly, Access) then begin
    try
      FillChar(Access.Bits^, Access.Pitch * Texture.Size.Y, #0);
      if ReadMode then begin
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
      end else begin
        for Y := 0 to Height - 1 do begin
          WriteBuffer := Pointer(Integer(Access.Bits) + (Access.Pitch * Y));
          ReadBuffer := @Buffer[(Height - 1 - Y) * Width];
          LineR5G6B5_A1R5G5B5(ReadBuffer, WriteBuffer, Texture.Width);
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
{$IF _READTEXTURE = 1}
  FHGE := HGECreate(HGE_VERSION);
{$IFEND}
  m_bNewVer := False;
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
  if m_bNewVer then nHLan := 2
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
        if (npos < 0) or (npos >= Width * Height) then halt(0);
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

{$IF _READTEXTURE = 1}
procedure TWMM3DefImages.LoadDxImage(index: Integer; position: integer; pDXTexture: pTDXTextureSurface);
var
  imginfo          : TNewWilFileImageInfo;
  buf               : array Of word;
  nYCnt, nWidthEnd, nWidthStart, nCntCopyWord, x: Integer;
  nCurrWidth, nLastWidth, nCheck: integer;
  nHLan             : byte;
  Image             : ITexture;
  w, h              : integer;
  color             : plongword;
  k, l              : integer;
  colorfirst        : longword;
Begin
  If m_bNewVer Then
    nHLan := 0
  Else
    nHLan := 2;
  FFileStream.Seek(Position, 0);
  FFileStream.Read(imginfo, sizeof(TNewWilFileImageInfo));

  if (imginfo.shWidth > MAXIMAGESIZE) or (imgInfo.shHeight > MAXIMAGESIZE) then Exit;
  if (imginfo.shWidth < MINIMAGESIZE) or (imgInfo.shHeight < MINIMAGESIZE) then Exit;

  SetLength(Buf, imginfo.dwImageLength * 2);
  FFileStream.Read(Buf[0], imginfo.dwImageLength * 2);
  nWidthStart := 0;
  nWidthEnd := 0;
  nCurrWidth := 0;
  nCntCopyWord := 0;
  nYCnt := 0;
  nLastWidth := 0;
  w := 1 Shl ceil(log2(imginfo.shWidth)); //计算2的N次幂大小，做为纹理大小
  h := 1 Shl ceil(log2(imginfo.shHeight));
  Image := FHGE.Texture_Create(w, h);
  color := Image.Lock(False);
  colorfirst := LongWord(color);

  For nYCnt := 0 To 1 - nHLan Do
  Begin
    nWidthEnd := nWidthEnd + Buf[nWidthStart];
    Inc(nWidthStart);
    Inc(nWidthEnd);
    nWidthStart := nWidthEnd;
  End;

//  For nycnt := imginfo.shHeight - nHLan - 1 downto 0 Do
  For nycnt := 0 to imginfo.shHeight + nHLan - 1 Do
  Begin
    nWidthEnd := Buf[nwidthstart] + nWidthEnd;
    Inc(nWidthStart);
    x := nWidthStart;
    While x < nwidthend Do
    Begin
      If Buf[x] = $C0 Then
      Begin
        Inc(x);
        nCntCopyWord := Buf[x];
        Inc(x);
        nCurrWidth := nCurrWidth + nCntCopyWord;
      End
      Else If (Buf[x] = $C1) Or (Buf[x] = $C2) Or (Buf[x] = $C3) Then
      Begin
        Inc(x);
        nCntCopyWord := Buf[x];
        Inc(x);
        nLastWidth := nCurrWidth;
        nCurrWidth := nCurrWidth + nCntCopyWord;
        If (imginfo.shWidth < nLastWidth) Then
          x := x + nCntCopyWord
        Else
        Begin
          If (nLastWidth <= imginfo.shWidth) And (imginfo.shWidth < nCurrWidth) Then
          Begin
            color := plongword((colorfirst + (nycnt * (w) + nlastwidth) * 4));
            For k := x To (((imginfo.shWidth - nlastwidth)) + x) - 1 Do
            Begin
              color^ := ARGB(255, (buf[k] And $F800) Shr 8, (buf[k] And $7E0) Shr 3, (buf[k] And $1F) Shl 3);
              inc(color);
            End;
            x := x + ncntcopyword;
          End
          Else
          Begin

            color := plongword((colorfirst + (nycnt * (w) + nlastwidth) * 4));
            For k := x To (((nCntCopyWord)) + x) - 1 Do
            Begin
              color^ := ARGB(255, (buf[k] And $F800) Shr 8, (buf[k] And $7E0) Shr 3, (buf[k] And $1F) Shl 3);
              inc(color);
            End;
            x := x + ncntcopyword;
          End;
        End;
      End
      Else
      Begin
        inc(x);
      End;
    End;
    Inc(nWidthEnd);
    nWidthStart := nWidthEnd;
    nCurrWidth := 0;
  End;
  Image.Unlock;
  pDXTexture.surface := MakeDXImageTexture(imginfo.shWidth, imginfo.shHeight, WILFMT_A1R5G5B5);
  pDXTexture.nPx := imginfo.shPX;
  pDXTexture.nPy := imginfo.shPY;
  pDXTexture.nsPx := imginfo.shShadowPX;
  pDXTexture.nsPy := imginfo.shShadowPY;
  pDXTexture.nShadow := imginfo.bShadow;
  pDXTexture.surface.LoadFromITexture(image, imginfo.shWidth, imginfo.shHeight);
End;
{$ELSE}
procedure TWMM3DefImages.LoadDxImage(index: Integer; position: integer; pDXTexture: pTDXTextureSurface);
var
  imginfo: TNewWilFileImageInfo;
  Buffer,DecodeBuffer: PChar;
  ReadSize,nLen: Integer;
begin
  pDXTexture.boNotRead := True;
  if FFileStream.Seek(position, soFromBeginning) = position then begin;

    if m_bNewVer then
      FFileStream.Read(imginfo, sizeof(TNewWilFileImageInfo))
    else
      FFileStream.Read(imginfo, sizeof(TNewWilFileImageInfo) - 4);

//    FFileStream.Read(imginfo, SizeOf(imginfo));

    if (imginfo.shWidth > MAXIMAGESIZE) or (imgInfo.shHeight > MAXIMAGESIZE) then Exit;
    if (imginfo.shWidth < MINIMAGESIZE) or (imgInfo.shHeight < MINIMAGESIZE) then Exit;

//    nLen := WidthBytes(16, imginfo.shWidth);

    if (imginfo.dwImageLength <= 0) then exit;
    ReadSize := imginfo.dwImageLength * 2;
    GetMem(Buffer, ReadSize);

    DecodeBuffer := nil;
    try
      SafeFillChar(Buffer^, ReadSize, 0);
      if FFileStream.Read(Buffer^, ReadSize) = ReadSize then begin
        GetMem(DecodeBuffer, imginfo.shWidth * imgInfo.shHeight * 2);
        FillChar(DecodeBuffer^, imginfo.shWidth * imgInfo.shHeight * 2, #0);
        Decode(Buffer, DecodeBuffer, imginfo.shWidth * 2, imgInfo.shHeight);

        if _F32FMTREAD then pDXTexture.Surface := MakeDXImageTexture(imginfo.shWidth, imgInfo.shHeight, WILFMT_A8R8G8B8)
        else pDXTexture.Surface := MakeDXImageTexture(imginfo.shWidth, imgInfo.shHeight, WILFMT_A1R5G5B5);

        if pDXTexture.Surface <> nil then begin
          if not CopyImageDataToTexture(DecodeBuffer, pDXTexture.Surface, nLen, imginfo.shHeight, _F32FMTREAD) then
          begin
            pDXTexture.Surface.Free;
            pDXTexture.Surface := nil;
          end else begin
            pDXTexture.boNotRead := False;
            pDXTexture.nPx := imginfo.shPX;
            pDXTexture.nPy := imginfo.shPY;
            pDXTexture.nShadow := imginfo.bShadow;
            pDXTexture.nsPx := imginfo.shShadowPX;
            pDXTexture.nsPy := imginfo.shShadowPY;
          end;
        end;
        FreeMem(DecodeBuffer);
      end;
    finally
      FreeMem(Buffer);
    end;
  end;
end; 
{$IFEND}

procedure TWMM3DefImages.Finalize;
begin
  FIndexList.Clear;
  inherited;
end;

function TWMM3DefImages.Initialize: Boolean;
var
  FHeader: TWilFileHerder;
  hFile: THandle;
begin
  Result := inherited Initialize;
  if Result then begin
    FFileStream.Read(FHeader, SizeOf(TWilFileHerder));
    if FHeader.shVer = _NEW_VER then m_bNewVer := True
    else m_bNewVer := False;
    FImageCount := FHeader.nImageCount;
    FIdxFile := ExtractFilePath(FFileName) + ExtractFileNameOnly(FFileName) + '.WIX';

    if LibType = ltLoadMemory then begin
      LoadMemoryMap;
    end else begin
      LoadIndex(FIdxFile);
    end;
    InitializeTexture;
  end;
end;

procedure TWMM3DefImages.LoadIndex(idxfile: string);
var
  fhandle, i, value: integer;
  pvalue: PInteger;
begin
  FIndexList.Clear;
  FImageCount := 0;
  if FileExists(idxfile) then begin
    fhandle := FileOpen(idxfile, fmOpenRead or fmShareDenyNone);
    if fhandle > 0 then begin
      if not m_bNewVer then FileRead(fhandle, FIdxHeader, sizeof(TNewWixFileImageInfo) - 4)
      else FileRead(fhandle, FIdxHeader, sizeof(TNewWixFileImageInfo));

      GetMem(pvalue, 4 * FIdxHeader.nIndexCount);
      FileRead(fhandle, pvalue^, 4 * FIdxHeader.nIndexCount);
      for i := 0 to FIdxHeader.nIndexCount - 1 do begin
        value := PInteger(integer(pvalue) + 4 * i)^;
        FIndexList.Add(pointer(value));
      end;
      FreeMem(pvalue);
      FileClose(fhandle);
    end;
    FImageCount := FIndexList.Count;
  end;
end;

procedure TWMM3DefImages.LoadMemoryMap;
var
  fhandle, i, j,x,y     : integer;
  POffsetIndex      : dword;
  hWix, hWil, hMap, mCount, mfSize: Cardinal;
  hMem              : Pointer;
  bOk               : boolean;
  fWil              : String;
  fBegin            : integer;
begin
  FIndexList.Clear;
  FIdxFile := ExtractFilePath(FFileName) + ExtractFileNameOnly(FFileName) + '.WIX';

  if FileExists(FIdxFile) then begin
    if FileExists(FIdxFile) then begin
      fhandle := FileOpen(FIdxFile, fmOpenRead or fmShareDenyNone);
    end;
    if fhandle > 0 then begin
      hWix := CreateFile(PChar(FIdxFile), GENERIC_READ, FILE_SHARE_WRITE or FILE_SHARE_READ, 0, OPEN_EXISTING, FILE_ATTRIBUTE_NORMAL, 0);
      if hWix <> INVALID_HANDLE_VALUE then begin
        hMap := CreateFileMapping(hWix, Nil, PAGE_READONLY, 0, 0, Nil);
        if hMap <> 0 then begin
          hMem := MapViewOfFile(hMap, FILE_MAP_READ, 0, 0, 0);
          if hMem <> Nil then begin
            CopyMemory(@mCount, Pointer(DWORD(hMem) + 20), 4);
            CopyMemory(@NewVerSign, Pointer(DWORD(hMem) + 24), 4);
            m_bNewVer := (NewVerSign and $FFFF0000) = $B13A0000;
            mfSize := GetFileSize(hWix, 0);
            if not m_bNewVer then begin
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
                bOk := True;
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
    end;

  end;
end;

{$IF _READTEXTURE = 1}
Initialization
  FHGE := Nil;
{$IFEND}


end.

