unit ZShare;

interface

uses
  Windows, Variants, Forms, Classes, SysUtils, WIL, commdlg, Graphics,
  TDX9Textures, ShlObj, pngImage, MyCommon, ActiveX;

type

  PRGBQuads = ^TRGBQuads;
  TRGBQuads = array[0..255] of TRGBQuad;

const
  IMAGEOFFSETDIR = 'Placements\';

var
  g_WMImages: TWMBaseImages;
  g_OldWMImages: TWMBaseImages;
  g_NewWMImages: TWMBaseImages;
  g_BackColor: TColor = TColor($800000);
  g_AlphaColor: TColor = clWhite;
  g_OutBackColor: TColor = clFuchsia;
  g_AlignLineColor: TColor = clGreen;
  g_OffsetLineColor: TColor = clRed;

  g_SelectImageIndex: Integer = -1;
  g_TextureInfo: TDXTextureInfo;
  g_WILColorFormat: SmallInt;
  g_Texture: array[0..1] of TDXImageTexture;
  g_DefMainPalette: TRgbQuads;
  g_WILType: TWILType;

  g_CustomIndex: Integer;
  g_FileVersionInfo: TFileVersionInfo;
  MAINFORMCAPTION: string = '´«Ææ3¸´¿Ì°æÍ¼¿â±à¼­Æ÷ ';

  sBrowseForFolder: string;
  sBrowseForAllFolder: string;
  g_boWalking: Boolean = False;
  
function RGB2TColor(const R, G, B: Byte): Integer;
procedure TColor2RGB(const Color: TColor; var R, G, B: Byte);
function RGB16(r, G, b: Integer): Word;
function GetSysColor(HWND: Integer; DefColor: TColor = $0): TColor;
function BrowseForFolder(hd: HWND; sTitle: string): string;
function DisplaceRB(Color: Cardinal): Cardinal;
function CountDiffPixels(P: PByte; BPP: Byte; Count: Integer): Integer;
function CountSamePixels(P: PByte; BPP: Byte; Count: Integer): Integer;
function RemoveData(FileName: string; Offset, Size: Int64): Boolean;
function AppendData(FileName: string; Offset, FSize: Int64): Boolean;
function LoadPNGtoBMP(Stream: TStream; Dest: TBitmap): Boolean; overload;
function SelectDirectory(const Caption: string; const Root: WideString;
  var Directory: string; Owner: Thandle): Boolean;
function DoSearchFile(Path, FType: string; var Files: TStringList): Boolean;

implementation

var
  g_rgbCustom: array[0..15] of TColor;


function RGB2TColor(const R, G, B: Byte): Integer;
begin
  // convert hexa-decimal values to RGB
  Result := R + G shl 8 + B shl 16;
end;

procedure TColor2RGB(const Color: TColor; var R, G, B: Byte);
begin
//  R := Color and $FF;
//  G := (Color shr 8) and $FF;
//  B := (Color shr 16) and $FF;

  R := Color and $FF;
  G := (Color and $FF00) shr 8;
  B := (Color and $FF0000) shr 16;
end;

function RGB16(r, G, b: Integer): Word;
begin
  Result := Word((b and $F8) shr 3 or (G and $FC) shl 3 or (r and $F8) shl 8);
end;

function LoadPNGtoBMP(Stream: TStream; Dest: TBitmap): Boolean; overload;
var
  Image: TPngObject;
  ScanIndex, i: Integer;
  PxScan: PLongword;
  PxAlpha: PByte;
begin
  Result := True;

  Image := TPngObject.Create();
  try
    Image.LoadFromStream(Stream);
  except
    Result := False;
  end;

  if (Result) then begin
    Image.AssignTo(Dest);

    if (Image.Header.ColorType = COLOR_RGBALPHA) or (Image.Header.ColorType = COLOR_GRAYSCALEALPHA) then begin
      Dest.PixelFormat := pf32bit;

      for ScanIndex := 0 to Dest.Height - 1 do begin
        PxScan := Dest.Scanline[ScanIndex];
        PxAlpha := @Image.AlphaScanline[ScanIndex][0];
        for i := 0 to Dest.Width - 1 do begin
          PxScan^ := (PxScan^ and $FFFFFF) or (Longword(Byte(PxAlpha^)) shl 24);
          Inc(PxScan);
          Inc(PxAlpha);
        end;
      end;
    end;
  end;

  Image.Free();
end;

function GetPixel(P: PByte; BPP: Byte): Cardinal;
begin
  Result := P^;
  Inc(P);
  Dec(BPP);
  while BPP > 0 do begin
    Result := Result shl 8;
    Result := Result or P^;
    Inc(P);
    Dec(BPP);
  end;
end;

function CountDiffPixels(P: PByte; BPP: Byte; Count: Integer): Integer;
var
  N: Integer;
  Pixel,
    NextPixel: Cardinal;

begin
  N := 0;
  NextPixel := 0; // shut up compiler
  if Count = 1 then
    Result := Count
  else begin
    Pixel := GetPixel(P, BPP);
    while Count > 1 do begin
      Inc(P, BPP);
      NextPixel := GetPixel(P, BPP);
      if NextPixel = Pixel then
        Break;
      Pixel := NextPixel;
      Inc(N);
      Dec(Count);
    end;
    if NextPixel = Pixel then
      Result := N
    else
      Result := N + 1;
  end;
end;
//----------------------------------------------------------------------------------------------------------------------

function CountSamePixels(P: PByte; BPP: Byte; Count: Integer): Integer;

var
  Pixel,
    NextPixel: Cardinal;

begin
  Result := 1;
  Pixel := GetPixel(P, BPP);
  Dec(Count);
  while Count > 0 do begin
    Inc(P, BPP);
    NextPixel := GetPixel(P, BPP);
    if NextPixel <> Pixel then
      Break;
    Inc(Result);
    Dec(Count);
  end;
end;

function DisplaceRB(Color: Cardinal): Cardinal;
asm
 mov eax, Color
 mov ecx, eax
 mov edx, eax
 and eax, 0FF00FF00h
 and edx, 0000000FFh
 shl edx, 16
 or eax, edx
 mov edx, ecx
 shr edx, 16
 and edx, 0000000FFh
 or eax, edx
 mov Result, eax
end;

function GetSysColor(HWND: Integer; DefColor: TColor): TColor;
var
  CC: TChooseColor;
begin
  Result := DefColor;
  CC.lStructSize := SizeOf(TChooseColor);
  CC.hWndOwner := HWND;
  cc.Flags := CC_ANYCOLOR;
  cc.rgbResult := DefColor;
  cc.lpCustColors := @g_rgbCustom;
  if ChooseColor(CC) then
    Result := cc.rgbResult;
end;

function BrowseForFolder(hd: HWND; sTitle: string): string;
var
  BrowseInfo: TBrowseInfo;
  sBuf: array[0..511] of Char;
begin
  FillChar(BrowseInfo, SizeOf(TBrowseInfo), #0);
  BrowseInfo.hwndOwner := hd;
  BrowseInfo.lpszTitle := PChar(sTitle);
  BrowseInfo.ulFlags := 64;
  SHGetPathFromIDList(SHBrowseForFolder(BrowseInfo), @sBuf);
  Result := Trim(sBuf);
end;

function RemoveData(FileName: string; Offset, Size: Int64): Boolean;
{var
  Buffer: PChar;
  FileSize, CopySize: Int64;
begin
  Result := True;
  FileSize := FileStream.Size;
  CopySize := FileSize - Offset - Size;
  FileStream.Seek(Offset + Size, soFromBeginning);
  GetMem(Buffer, CopySize);
  Try
    FileStream.Read(Buffer^, CopySize);
    FileStream.Seek(Offset, soFromBeginning);
    FileStream.Write(Buffer^, CopySize);
    SetEndOfFile(FileStream.Handle);
  Finally
    FreeMem(Buffer, CopySize);
  End;  }


var
  FData: PByte;
  FHandle, FMapHandle: THandle;
  FFileSize: Integer;
  FSize, FOffset: Int64;
begin
  Result := True;
  FHandle := FileOpen(FileName, fmOpenReadWrite or fmShareDenyNone);
  FFileSize := GetFileSize(FHandle, nil);
  FMapHandle := CreateFileMapping(FHandle, nil, PAGE_READWRITE, 0, FFileSize, PChar('RPG_PAK_' + IntToStr(Random(9999) + 1000)));
  FData := MapViewOfFile(FMapHandle, FILE_MAP_ALL_ACCESS, 0, 0, 0);
  if Size > (FFileSize - Offset) then
    FSize := FFileSize - Offset
  else
    FSize := Size;
  if Offset > FFileSize then
    FOffset := FFileSize
  else
    FOffset := Offset;
  CopyMemory(Pointer(LongInt(FData) + FOffset), Pointer(LongInt(FData) + FOffset + FSize), FFileSize - FOffset - FSize);
  if FData <> nil then
    UnMapViewOfFile(FData);
  if FMapHandle <> 0 then
    CloseHandle(FMapHandle);
  Fileseek(Fhandle, -FSize, 2);
  SetEndOfFile(FHandle);
  if FHandle <> 0 then
    CloseHandle(FHandle);
end;

function AppendData(FileName: string; Offset, FSize: Int64): Boolean;
{var
  Buffer: PChar;
  FileSize, CopySize: Int64;
begin
  Result := True;
  FileSize := FileStream.Size;
  CopySize := FileSize - Offset;
  FileStream.Seek(Offset, soFromBeginning);
  GetMem(Buffer, CopySize);
  Try
    FileStream.Read(Buffer^, CopySize);
    FileStream.Seek(Offset + FSize, soFromBeginning);
    FileStream.Write(Buffer^, CopySize);
  Finally
    FreeMem(Buffer, CopySize);                         
  End;   }
var
  FData: PByte;
  FHandle, FMapHandle: THandle;
  FFileSize: Integer;
  FOffset: Int64;
begin
  Result := True;
  FHandle := FileOpen(FileName, fmOpenReadWrite or fmShareDenyNone);
  FFileSize := GetFileSize(FHandle, nil);
  if Offset > FFileSize then
    FOffset := FFileSize
  else                              
    FOffset := Offset;
  FMapHandle := CreateFileMapping(FHandle, nil, PAGE_READWRITE, 0, FFileSize + FSize, PChar('RPG_PAK_' + IntToStr(Random(9999) + 1000)));
  FData := MapViewOfFile(FMapHandle, FILE_MAP_ALL_ACCESS, 0, 0, 0);
  CopyMemory(Pointer(LongInt(FData) + FOffset + FSize), Pointer(LongInt(FData) + FOffset), FFileSize - FOffset);
  if FData <> nil then
    UnMapViewOfFile(FData);
  if FMapHandle <> 0 then
    CloseHandle(FMapHandle);
  if FHandle <> 0 then
    CloseHandle(FHandle);
end;

function SelectDirCB(Wnd: HWND; uMsg: UINT; lParam, lpData: lParam): Integer stdcall;
begin
  if (uMsg = BFFM_INITIALIZED) and (lpData <> 0) then
    SendMessage(Wnd, BFFM_SETSELECTION, Integer(True), lpData);
  Result := 0;
end;

function SelectDirectory(const Caption: string; const Root: WideString;
  var Directory: string; Owner: Thandle): Boolean;
var
  WindowList: Pointer;
  BrowseInfo: TBrowseInfo;
  Buffer: PChar;
  RootItemIDList, ItemIDList: PItemIDList;
  ShellMalloc: IMalloc;
  IDesktopFolder: IShellFolder;
  Eaten, Flags: LongWord;
begin
  Result := False;
  if not DirectoryExists(Directory) then
    Directory := '';
  FillChar(BrowseInfo, SizeOf(BrowseInfo), 0);
  if (ShGetMalloc(ShellMalloc) = S_OK) and (ShellMalloc <> nil) then begin
    Buffer := ShellMalloc.Alloc(MAX_PATH);
    try
      RootItemIDList := nil;
      if Root <> '' then begin
        SHGetDesktopFolder(IDesktopFolder);
        IDesktopFolder.ParseDisplayName(Application.Handle, nil,
          POleStr(Root), Eaten, RootItemIDList, Flags);
      end;
      with BrowseInfo do begin
        hwndOwner := Owner;
        pidlRoot := RootItemIDList;
        pszDisplayName := Buffer;
        lpszTitle := PChar(Caption);
        ulFlags := BIF_RETURNONLYFSDIRS + BIF_USENEWUI;
        if Directory <> '' then begin
          lpfn := SelectDirCB;
          lParam := Integer(PChar(Directory));
        end;
      end;
      WindowList := DisableTaskWindows(0);
      try
        ItemIDList := ShBrowseForFolder(BrowseInfo);
      finally
        EnableTaskWindows(WindowList);
      end;
      Result := ItemIDList <> nil;
      if Result then begin
        ShGetPathFromIDList(ItemIDList, Buffer);
        ShellMalloc.Free(ItemIDList);
        Directory := Buffer;
      end;
    finally
      ShellMalloc.Free(Buffer);
    end;
  end;
end;

function DoSearchFile(Path, FType: string; var Files: TStringList): Boolean;
var
  Info: TSearchRec;
  s01: string;
  procedure ProcessAFile(FileName: string);
  begin
   {if Assigned(PnlPanel) then
     PnlPanel.Caption := FileName;
   Label2.Caption := FileName;}
  end;
  function IsDir: Boolean;
  begin
    with Info do
      Result := (Name <> '.') and (Name <> '..') and ((Attr and faDirectory) = faDirectory);
  end;
  function IsFile: Boolean;
  begin
    Result := (not ((Info.Attr and faDirectory) = faDirectory)) and (CompareText(ExtractFileExt(Info.Name), FType) = 0);
  end;
begin
  try
    Result := False;
    if FindFirst(Path + '*.*', faAnyFile, Info) = 0 then begin
      while True do begin
        if IsFile then begin
          s01 := Path + Info.Name;
          Files.Add(s01);
        end;

        Application.ProcessMessages;
        if FindNext(Info) <> 0 then Break;
      end;
    end;
    Result := True;
  finally
    FindClose(Info);
  end;
end;

initialization
  begin
    FillChar(g_TextureInfo, SizeOf(g_TextureInfo), #0);
    g_rgbCustom[0] := clWhite;
    g_rgbCustom[1] := clWhite;
    g_rgbCustom[2] := clWhite;
    g_rgbCustom[3] := clWhite;
    g_rgbCustom[4] := clWhite;
    g_rgbCustom[5] := clWhite;
    g_rgbCustom[6] := clWhite;
    g_rgbCustom[7] := clWhite;
    g_rgbCustom[8] := clWhite;
    g_rgbCustom[9] := clWhite;
    g_rgbCustom[10] := clWhite;
    g_rgbCustom[11] := clWhite;
    g_rgbCustom[12] := clWhite;
    g_rgbCustom[13] := clWhite;
    g_rgbCustom[14] := clWhite;
    g_rgbCustom[15] := clWhite;
  end;

finalization

end.

