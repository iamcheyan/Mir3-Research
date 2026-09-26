unit wmM2Zip;

interface
uses
  Windows, Classes, Graphics, SysUtils, HGETextures, HUtil32, WIL, DirectXGraphics;

type
  TWZIndexHeader = record
    Title: string[43];
    IndexCount: Integer;
  end;
  PTWZIndexHeader = ^TWZIndexHeader;

  TWZImageInfo = record
    Encode: Byte;
    unKnow1: array [0 .. 2] of Byte;
    DXInfo: TDXTextureInfo;
    nSize: Integer;
  end;
  PTWZImageInfo = ^TWZImageInfo;


  TWMM2ZipImages = class(TWMBaseImages)
  private
    FIdxHeader: TWZIndexHeader;
    FIdxFile: string;
    Fbo16bit: Boolean;
    procedure LoadIndex(idxfile: string);
    function CopyImageDataToTexture(Buffer: PChar; Texture: TDirectDrawSurface; Width, Height: Word): Boolean;
    //新增函数
    function CopyImageDataToTextureEx(Buffer: PChar; Texture: TDirectDrawSurface; Width, Height: Word): Boolean;
  protected
    procedure LoadDxImage(index: Integer; position: integer; pDXTexture: pTDXTextureSurface); override;
  public
    constructor Create(); override;
    function Initialize(): Boolean; override;
    procedure Finalize; override;
  end;
 //定义函数原型
procedure LineR5G6B5_A8R8G8B8(Source:Word; Alpha:Byte; var Dest: LongWord);
implementation
//增加这个函数
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
{ TWMM2ZipImages }
function ExtractFilePath(const FileName: string): string;
var
  I: integer;
begin
  I := LastDelimiter(PathDelim + DriveDelim, FileName);
  Result := Copy(FileName, 1, I);
end;

function ExtractFileNameOnly(const fname: string): string;
var
  extpos: integer;
  ext, fn: string;
begin
  ext := ExtractFileExt(fname);
  fn := ExtractFileName(fname);
  if ext <> '' then begin
    extpos := Pos(ext, fn);
    Result := Copy(fn, 1, extpos - 1);
  end else
    Result := fn;
end;
//增加这个函数
function TWMM2ZipImages.CopyImageDataToTextureEx(Buffer: PChar; Texture: TDirectDrawSurface; Width, Height: Word): Boolean;
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
      if Fbo16bit then begin
        maskBase:= height * Texture.Width * 2;
        FillChar(Access.Bits^, Access.Pitch * Texture.Size.Y, #0);
        nColorId:= 0;
        for y := Height - 1 downto 0 do begin
          for x := 0 to Texture.Width - 1 do begin
            pdwColor := (PDWORD(Access.Bits));
            wCol16:= PWord(@Buffer[nColorId])^;
            maskId:= maskBase + y * (Texture.Width div 2) + (x div 2);
            cbMask:= LongWord(Buffer[maskId]);
            cbHigh:= (cbMask and $f0) shr 4;
            cbLow:= cbMask and $0f;
            if ((x mod 2)=0) then begin
              cbAlpha:= cbHigh;
            end else begin
              cbAlpha:= cbLow;
            end;
            LineR5G6B5_A8R8G8B8(wCol16, cbAlpha * 17, dwColor);
            Inc(pdwColor, y * Texture.Width + x);
            pdwColor^:= dwColor;
            inc(nColorId, 2);
          end;
        end;
      end else begin
        FillChar(Access.Bits^, Access.Pitch * Texture.Size.Y, #0);
        WriteBuffer := Pointer(Integer(Access.Bits));
        ReadBuffer := @Buffer[(Height - 1) * Width];
        for Y := 0 to Height - 1 do begin
          LineX8_A1R5G5B5(ReadBuffer, WriteBuffer, Texture.Width);
          Inc(WriteBuffer, Access.Pitch);
          Dec(ReadBuffer, Width);
        end;
      end;
      Result := True;
    finally
      Texture.Unlock;
    end;
  end;
end;

function TWMM2ZipImages.CopyImageDataToTexture(Buffer: PChar; Texture: TDirectDrawSurface; Width, Height: Word): Boolean;
var
  Y: Integer;
  Access: TDXAccessInfo;
  WriteBuffer, ReadBuffer: PChar;
begin
  Result := False;
  if Texture.Lock(lfWriteOnly, Access) then begin
    try
      if Fbo16bit then begin
        FillChar(Access.Bits^, Access.Pitch * Texture.Size.Y, #0);
        for Y := 0 to Height - 1 do begin
          WriteBuffer := Pointer(Integer(Access.Bits) + (Access.Pitch * Y));
          ReadBuffer := @Buffer[(Height - 1 - Y) * Width];
          LineR5G6B5_A1R5G5B5(ReadBuffer, WriteBuffer, Texture.Width);
        end;
      end else begin
        FillChar(Access.Bits^, Access.Pitch * Texture.Size.Y, #0);
        WriteBuffer := Pointer(Integer(Access.Bits));
        ReadBuffer := @Buffer[(Height - 1) * Width];
        for Y := 0 to Height - 1 do begin
          LineX8_A1R5G5B5(ReadBuffer, WriteBuffer, Texture.Width);
          Inc(WriteBuffer, Access.Pitch);
          Dec(ReadBuffer, Width);
        end;
      end;
      Result := True;
    finally
      Texture.Unlock;
    end;
  end;
end;

constructor TWMM2ZipImages.Create;
begin
  inherited;
  FReadOnly := True;
end;

procedure TWMM2ZipImages.Finalize;
begin
  inherited;
end;

function TWMM2ZipImages.Initialize: Boolean;
begin
  Result := inherited Initialize;
  if Result then begin
    FIdxFile := ExtractFilePath(fFileName) + ExtractFileNameOnly(fFileName) + '.WZX';
    LoadIndex(FIdxFile);
    InitializeTexture;
  end;
end;

procedure TWMM2ZipImages.LoadDxImage(index: Integer; position: integer; pDXTexture: pTDXTextureSurface);
var
  imginfo: TWZImageInfo;
  inBuffer, outBuffer: PChar;
  nLen, ReadSize, nZipSize: Integer;
begin
  if (FFileStream.Seek(position, 0) = position) and (position <> 0) then begin;
    FFileStream.Read(imginfo, SizeOf(imginfo));
    if (imginfo.DXInfo.nWidth > MAXIMAGESIZE) or (imgInfo.DXInfo.nHeight > MAXIMAGESIZE) then
      Exit;
    if (imginfo.DXInfo.nWidth < MINIMAGESIZE) or (imgInfo.DXInfo.nHeight < MINIMAGESIZE) then
      Exit;
    Fbo16bit := imginfo.Encode = 5;
    if Fbo16bit then begin
      nLen := WidthBytes(16, imginfo.DXInfo.nWidth);
      ReadSize := nLen * imgInfo.DXInfo.nHeight;
    end else begin
      nLen := WidthBytes(8, imginfo.DXInfo.nWidth);
      ReadSize := nLen * imgInfo.DXInfo.nHeight;
    end;
    if (imginfo.nSize <= 0) then begin
      //2014.09.25 是否是未压缩位图
      if (imginfo.DXInfo.nWidth <> 0) and (imginfo.DXInfo.nHeight <> 0) then begin
        //处理未压缩资源
        GetMem(inBuffer, ReadSize);
        try
          if FFileStream.Read(inBuffer^, ReadSize) = ReadSize then begin
            pDXTexture.Surface := MakeDXImageTexture(imginfo.DXInfo.nWidth, imginfo.DXInfo.nHeight, WILFMT_A1R5G5B5);
            if pDXTexture.Surface <> nil then begin
              if not CopyImageDataToTexture(inBuffer, pDXTexture.Surface, nLen, imginfo.DXInfo.nHeight) then begin
                pDXTexture.Surface.Free;
                pDXTexture.Surface := nil;
              end else begin
                pDXTexture.boNotRead := False;
                pDXTexture.nPx := imginfo.DXInfo.px;
                pDXTexture.nPy := imginfo.DXInfo.py;
              end;
            end;
          end;
        finally
          FreeMem(inBuffer);
        end;
      end;
      exit;
    end;
    GetMem(inBuffer, imginfo.nSize);
    outBuffer := nil;
    try
      if FFileStream.Read(inBuffer^, imginfo.nSize) = imginfo.nSize then begin
        if inBuffer^ <> '' then begin
          nZipSize := ZIPDecompress(inBuffer, imginfo.nSize, 0, outBuffer);
          if nZipSize = ReadSize then begin
            pDXTexture.Surface := MakeDXImageTexture(imginfo.DXInfo.nWidth, imginfo.DXInfo.nHeight, WILFMT_A1R5G5B5);
            if pDXTexture.Surface <> nil then begin
              if not CopyImageDataToTexture(outBuffer, pDXTexture.Surface, nLen, imginfo.DXInfo.nHeight) then begin
                pDXTexture.Surface.Free;
                pDXTexture.Surface := nil;
              end else begin
                pDXTexture.boNotRead := False;
                pDXTexture.nPx := imginfo.DXInfo.px;
                pDXTexture.nPy := imginfo.DXInfo.py;
              end;
            end;
          end else begin
            pDXTexture.Surface := MakeDXImageTexture(imginfo.DXInfo.nWidth, imginfo.DXInfo.nHeight, WILFMT_A8R8G8B8);
            if pDXTexture.Surface <> nil then begin
              if not CopyImageDataToTextureEx(outBuffer, pDXTexture.Surface, nLen, imginfo.DXInfo.nHeight) then begin
                pDXTexture.Surface.Free;
                pDXTexture.Surface := nil;
              end else begin
                pDXTexture.boNotRead := False;
                pDXTexture.nPx := imginfo.DXInfo.px;
                pDXTexture.nPy := imginfo.DXInfo.py;
              end;
            end;
          end;
        end;
        FreeMem(outBuffer);
      end;
    finally
      FreeMem(inBuffer);
    end;
  end;
end;
procedure TWMM2ZipImages.LoadIndex(idxfile: string);
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
      FileRead(fhandle, FIdxHeader, sizeof(TWZIndexHeader));
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


