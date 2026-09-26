unit cliUtil;

interface

uses
  Windows, Messages, SysUtils, Classes, Graphics, Controls, Forms, Dialogs, Clipbrd,
  HGETextures, HGECanvas, WIL, {Grobal2,} StdCtrls, HGEFontManager, HGEBase, HGE, HUtil32,
  wmutil; //, bmputil;


const
  MAXGRADE = 64;
  DIVUNIT = 4;
  DEFSCREENWIDTH = 640;
  DEFSCREENHEIGHT = 480;
  PLAYSCREENWIDTH = 800;
  PLAYSCREENHEIGHT = 600;
type
//  TColorEffect = (ceNone, ceGrayScale, ceBright, ceBlack, ceWhite, ceRed, ceGreen, ceBlue, ceYellow, ceFuchsia);

   TEffectSprinfo = record
     dwFstFrm     : DWORD;
     dwEndFrm     : DWORD;
     wDelay       : Word;
     wImgIdx      : Word;
     wEffectIdx   : Word;
     bLightRadius : array[0..1] of Byte;
     bLightColor  : array[0..1, 0..2] of Byte;
     bMagicColor : array[0..2] of Byte;
     bBlendType  : Byte;
     bOpa        : Byte;
     bSwingCnt   : Byte;
     bDir        : Byte;
     bRepeat     : Boolean;
     bFixed      : Boolean;
     bShowLight  : Boolean;
     bTargetUse  : Boolean;
   end;
   PTEffectSprinfo = ^TEffectSprinfo;

  TNearestIndexHeader = record
    Title: string[30];
    IndexCount: integer;
    desc: array[0..10] of byte;
  end;

function  HasMMX: Boolean;
procedure BuildColorLevels (ctable: TRGBQuads);
procedure BuildNearestIndex (ctable: TRGBQuads);
procedure SaveNearestIndex (flname: string);
function  LoadNearestIndex (flname: string): Boolean;
procedure DrawFog (ssuf: TDirectDrawSurface; fogmask: PByte; fogwidth: integer);
procedure DrawFog2 (ssuf: TDirectDrawSurface; fogmask: PByte; fogwidth: integer);
//procedure MakeDark (ssuf: TDirectDrawSurface; darklevel: integer);
procedure FogCopy (PSource: Pbyte; ssx, ssy, swidth, sheight: integer;
                   PDest: Pbyte; ddx, ddy, dwidth, dheight, maxfog: integer);
procedure   SpriteCopy(DestX, DestY : integer;
                       SourX, SourY : integer;
                       Size         : TPoint;
                       Sour, Dest   : TDirectDrawSurface);
procedure MMXBlt (ssuf, dsuf: TDirectDrawSurface);
procedure CopyStrToClipboard(sStr: string);
procedure LoadColorLevels();
procedure UnLoadColorLevels();
function GetTempSurface(ColorFormat: TWILColorFormat): TDirectDrawSurface;

procedure DrawBlendShadow(dsuf: TDirectDrawSurface; x, y, stype: integer; ssuf: TDirectDrawSurface; blendmode: integer); overload;
procedure DrawBlendShadow(dsuf: TDirectDrawSurface; x, y, sx, sy, stype: integer; ssuf: TDirectDrawSurface; blendmode: integer); overload;

procedure DrawBlend(dsuf: TDirectDrawSurface; x, y: integer; ssuf: TDirectDrawSurface; blendmode: integer);
procedure DrawBlendEx(dsuf: TDirectDrawSurface; x, y: integer; ssuf: TDirectDrawSurface; blendmode: integer);
procedure DrawBlendR(dsuf: TDirectDrawSurface; x, y: integer; Rect: TRect; ssuf: TDirectDrawSurface; blendmode: integer);
procedure DrawEffect(dsuf: TDirectDrawSurface; x, y: integer; ssuf: TDirectDrawSurface; eff: TColorEffect; boBlend: Boolean; blendmode: integer = 0);
procedure MakeDark(darklevel: integer);

var
  DarkLevel : integer;

  g_DXCanvas: TDXDrawCanvas;
  g_boInitialize: Boolean;
  g_boCanDraw: Boolean = True;
  g_boCanSound: Boolean = True;
  g_boBGSound: Boolean = True;
  g_FScreenMode: Byte = 0;
  g_FScreenWidth: Integer = DEFSCREENWIDTH;
  g_FScreenHeight: Integer = DEFSCREENHEIGHT;
  g_FPlayScreenWidth: Integer = PLAYSCREENWIDTH;
  g_FPlayScreenHeight: Integer = PLAYSCREENHEIGHT;
  g_btMP3Volume: Byte = 70;
  g_boFullScreen: Boolean = False;
  g_DXFont: TDXFont;
  g_boDrawTileMap: Boolean = True;
  g_SelectChr: Boolean = True;
  g_boShadowBlend: Byte = 1;
  m_pszMagicExplain: TStringList;

	m_pstEffectSpr: array of TEffectSprinfo;
	m_pstMagicSpr: array of TEffectSprinfo;
	m_pstExplosionSpr: array of TEffectSprinfo;
  m_nEffectCnt: Integer;
  m_nMagicCnt: Integer;
  m_nExplosionCnt: Integer;

implementation

var
  RgbIndexTable: array[0..MAXGRADE-1, 0..MAXGRADE-1, 0..MAXGRADE-1] of byte;
  Color256Mix: array[0..255, 0..255] of byte;
  Color256Anti: array[0..255, 0..255] of byte;
  HeavyDarkColorLevel: array[0..255, 0..255] of byte;
  LightDarkColorLevel: array[0..255, 0..255] of byte;
  DengunColorLevel: array[0..255, 0..255] of byte;
  BrightColorLevel: array[0..255] of byte;
  GrayScaleLevel: array[0..255] of byte;
  RedishColorLevel: array[0..255] of byte;
  BlackColorLevel: array[0..255] of byte;
  WhiteColorLevel: array[0..255] of byte;
  GreenColorLevel: array[0..255] of byte;
  YellowColorLevel: array[0..255] of byte;
  BlueColorLevel: array[0..255] of byte;
  FuchsiaColorLevel: array[0..255] of byte;

  GrayScaleByR5G6B5: array[Word] of Word;
  GrayScaleByA1R5G5B5: array[Word] of Word;
  GrayScaleByA4R4G4B4: array[Word] of Word;
  GSA1R5G5B5ToA4R4G4B4: array[Word] of Word;
  ImgMixSurfaceR5G6B5: TDirectDrawSurface;
  ImgMixSurfaceA1R5G5B5: TDirectDrawSurface; //0x0C
  ImgMixSurfaceA4R4G4B4: TDirectDrawSurface; //0x0C
  ImgMaxSurfaceR5G6B5: TDirectDrawSurface;
  ImgMaxSurfaceA1R5G5B5: TDirectDrawSurface; //0x0C
  ImgMaxSurfaceA4R4G4B4: TDirectDrawSurface; //0x0C
  boA1R5G5B5, boR5G6B5, boA4R4G4B4: Boolean;

function  HasMMX: Boolean;
var
   n: byte;
begin
   asm
      mov   eax, 1
      db $0F,$A2               /// CPUID
      test  edx, 00800000H
      mov   n, 1
      jnz   @@Found
      mov   n, 0
   @@Found:
   end;
   if n = 1 then Result := TRUE
   else Result := FALSE;
end;

procedure BuildNearestIndex (ctable: TRGBQuads);
var
   r, g, b, rr, gg, bb, color, MinDif, ColDif: Integer;
   MatchColor: Byte;
   pal0, pal1, pal2: TRGBQuad;

   procedure BuildMix;
   var
      i, j, n: integer;
   begin
      for i:=0 to 255 do begin
         pal0 := ctable[i];
         for j:=0 to 255 do begin
            pal1 := ctable[j];
            pal1.rgbRed := pal0.rgbRed div 2 + pal1.rgbRed div 2;
            pal1.rgbGreen := pal0.rgbGreen div 2 + pal1.rgbGreen div 2;
            pal1.rgbBlue := pal0.rgbBlue div 2 + pal1.rgbBlue div 2;
            MinDif := 768;
            MatchColor := 0;
            for n:=0 to 255 do begin
               pal2 := ctable[n];
               ColDif := Abs(pal2.rgbRed - pal1.rgbRed) +
                         Abs(pal2.rgbGreen - pal1.rgbGreen) +
                         Abs(pal2.rgbBlue - pal1.rgbBlue);
               if ColDif < MinDif then begin
                  MinDif := ColDif;
                  MatchColor := n;
               end;
            end;
            Color256Mix[i, j] := MatchColor;
         end;
      end;
   end;
   procedure BuildAnti;
   var
      i, j, n, ever: integer;
   begin
      for i:=0 to 255 do begin
         pal0 := ctable[i];
         for j:=0 to 255 do begin
            pal1 := ctable[j];
            ever := _MAX(pal0.rgbRed, pal0.rgbGreen);
            ever := _MAX(ever, pal0.rgbBlue);
//            pal1.rgbRed := _MIN(255, Round (pal0.rgbRed  + (255-ever)/255 * pal1.rgbRed));
//            pal1.rgbGreen := _MIN(255, Round (pal0.rgbGreen  + (255-ever)/255 * pal1.rgbGreen));
//         pal1.rgbBlue := _MIN(255, Round (pal0.rgbBlue  + (255-ever)/255 * pal1.rgbBlue));
            pal1.rgbRed := _MIN(255, Round (pal0.rgbRed  + (255-pal0.rgbRed)/255 * pal1.rgbRed));
            pal1.rgbGreen := _MIN(255, Round (pal0.rgbGreen  + (255-pal0.rgbGreen)/255 * pal1.rgbGreen));
            pal1.rgbBlue := _MIN(255, Round (pal0.rgbBlue  + (255-pal0.rgbBlue)/255 * pal1.rgbBlue));
            MinDif := 768;
            MatchColor := 0;
            for n:=0 to 255 do begin
               pal2 := ctable[n];
               ColDif := Abs(pal2.rgbRed - pal1.rgbRed) +
                         Abs(pal2.rgbGreen - pal1.rgbGreen) +
                         Abs(pal2.rgbBlue - pal1.rgbBlue);
               if ColDif < MinDif then begin
                  MinDif := ColDif;
                  MatchColor := n;
               end;
            end;
            Color256Anti[i, j] := MatchColor;
         end;
      end;
   end;
   procedure BuildColorLevels;
   var
      n, i, j, rr, gg, bb: integer;
   begin
      for n:=0 to 30 do begin
         for i:=0 to 255 do begin
            pal1 := ctable[i];
            rr := _MIN(Round(pal1.rgbRed * (n+1) / 31) - 5, 255);      //(n + (n-1)*3) / 121);
            gg := _MIN(Round(pal1.rgbGreen * (n+1) / 31) - 5, 255);  //(n + (n-1)*3) / 121);
            bb := _MIN(Round(pal1.rgbBlue * (n+1) / 31) - 5, 255);    //(n + (n-1)*3) / 121);
            pal1.rgbRed := _MAX(0, rr);
            pal1.rgbGreen := _MAX(0, gg);
            pal1.rgbBlue := _MAX(0, bb);
            MinDif := 768;
            MatchColor := 0;
            for j:=0 to 255 do begin
               pal2 := ctable[j];
               ColDif := Abs(pal2.rgbRed - pal1.rgbRed) +
                         Abs(pal2.rgbGreen - pal1.rgbGreen) +
                         Abs(pal2.rgbBlue - pal1.rgbBlue);
               if ColDif < MinDif then begin
                  MinDif := ColDif;
                  MatchColor := j;
               end;
            end;
            HeavyDarkColorLevel[n, i] := MatchColor;
         end;
      end;
      for n:=0 to 30 do begin
         for i:=0 to 255 do begin
            pal1 := ctable[i];
            pal1.rgbRed := _MIN(Round(pal1.rgbRed * (n*3+47) / 140), 255);
            pal1.rgbGreen := _MIN(Round(pal1.rgbGreen * (n*3+47) / 140), 255);
            pal1.rgbBlue := _MIN(Round(pal1.rgbBlue * (n*3+47) / 140), 255);
            MinDif := 768;
            MatchColor := 0;
            for j:=0 to 255 do begin
               pal2 := ctable[j];
               ColDif := Abs(pal2.rgbRed - pal1.rgbRed) +
                         Abs(pal2.rgbGreen - pal1.rgbGreen) +
                         Abs(pal2.rgbBlue - pal1.rgbBlue);
               if ColDif < MinDif then begin
                  MinDif := ColDif;
                  MatchColor := j;
               end;
            end;
            LightDarkColorLevel[n, i] := MatchColor;
         end;
      end;
      for n:=0 to 30 do begin
         for i:=0 to 255 do begin
            pal1 := ctable[i];
            pal1.rgbRed := _MIN(Round(pal1.rgbRed * (n*3+120) / 214), 255);
            pal1.rgbGreen := _MIN(Round(pal1.rgbGreen * (n*3+120) / 214), 255);
            pal1.rgbBlue := _MIN(Round(pal1.rgbBlue * (n*3+120) / 214), 255);
            MinDif := 768;
            MatchColor := 0;
            for j:=0 to 255 do begin
               pal2 := ctable[j];
               ColDif := Abs(pal2.rgbRed - pal1.rgbRed) +
                         Abs(pal2.rgbGreen - pal1.rgbGreen) +
                         Abs(pal2.rgbBlue - pal1.rgbBlue);
               if ColDif < MinDif then begin
                  MinDif := ColDif;
                  MatchColor := j;
               end;
            end;
            DengunColorLevel[n, i] := MatchColor;
         end;
      end;

      {for i:=0 to 255 do begin
         HeavyDarkColorLevel[0, i] := HeavyDarkColorLevel[1, i];
         LightDarkColorLevel[0, i] := LightDarkColorLevel[1, i];
         DengunColorLevel[0, i] := DengunColorLevel[1, i];
      end;}
      for n:=31 to 255 do
         for i:=0 to 255 do begin
            HeavyDarkColorLevel[n, i] := HeavyDarkColorLevel[30, i];
            LightDarkColorLevel[n, i] := LightDarkColorLevel[30, i];
            DengunColorLevel[n, i] := DengunColorLevel[30, i];
         end;

   end;
begin
   BuildMix;
   BuildAnti;
   BuildColorLevels;
end;

procedure BuildColorLevels (ctable: TRGBQuads);
var
   n, i, j, MinDif, ColDif: integer;
   pal1, pal2: TRGBQuad;
   MatchColor: byte;
begin
   BrightColorLevel[0] := 0;
   for i:=1 to 255 do begin
      pal1 := ctable[i];
      pal1.rgbRed := _MIN(Round(pal1.rgbRed * 1.3), 255);
      pal1.rgbGreen := _MIN(Round(pal1.rgbGreen * 1.3), 255);
      pal1.rgbBlue := _MIN(Round(pal1.rgbBlue * 1.3), 255);
      MinDif := 768;
      MatchColor := 0;
      for j:=1 to 255 do begin
         pal2 := ctable[j];
         ColDif := Abs(pal2.rgbRed - pal1.rgbRed) +
                   Abs(pal2.rgbGreen - pal1.rgbGreen) +
                   Abs(pal2.rgbBlue - pal1.rgbBlue);
         if ColDif < MinDif then begin
            MinDif := ColDif;
            MatchColor := j;
         end;
      end;
      BrightColorLevel[i] := MatchColor;
   end;
   GrayScaleLevel[0] := 0;
   for i:=1 to 255 do begin
      pal1 := ctable[i];
      n := (pal1.rgbRed + pal1.rgbGreen + pal1.rgbBlue) div 3;
      pal1.rgbRed := n; //Round(pal1.rgbRed * (n*3+25) / 118);
      pal1.rgbGreen := n; //Round(pal1.rgbGreen * (n*3+25) / 118);
      pal1.rgbBlue := n; //Round(pal1.rgbBlue * (n*3+25) / 118);
      MinDif := 768;
      MatchColor := 0;
      for j:=1 to 255 do begin
         pal2 := ctable[j];
         ColDif := Abs(pal2.rgbRed - pal1.rgbRed) +
                   Abs(pal2.rgbGreen - pal1.rgbGreen) +
                   Abs(pal2.rgbBlue - pal1.rgbBlue);
         if ColDif < MinDif then begin
            MinDif := ColDif;
            MatchColor := j;
         end;
      end;
      GrayScaleLevel[i] := MatchColor;
   end;
   BlackColorLevel[0] := 0;
   for i:=1 to 255 do begin
      pal1 := ctable[i];
      n := Round ((pal1.rgbRed + pal1.rgbGreen + pal1.rgbBlue) / 3 * 0.6);
      pal1.rgbRed := n; //_MAX(8, Round(pal1.rgbRed * 0.7));
      pal1.rgbGreen := n; //_MAX(8, Round(pal1.rgbGreen * 0.7));
      pal1.rgbBlue := n; //_MAX(8, Round(pal1.rgbBlue * 0.7));
      MinDif := 768;
      MatchColor := 0;
      for j:=1 to 255 do begin
         pal2 := ctable[j];
         ColDif := Abs(pal2.rgbRed - pal1.rgbRed) +
                   Abs(pal2.rgbGreen - pal1.rgbGreen) +
                   Abs(pal2.rgbBlue - pal1.rgbBlue);
         if ColDif < MinDif then begin
            MinDif := ColDif;
            MatchColor := j;
         end;
      end;
      BlackColorLevel[i] := MatchColor;
   end;
   WhiteColorLevel[0] := 0;
   for i:=1 to 255 do begin
      pal1 := ctable[i];
      n := _MIN (Round ((pal1.rgbRed + pal1.rgbGreen + pal1.rgbBlue) / 3 * 1.6), 255);
      pal1.rgbRed := n; //_MAX(8, Round(pal1.rgbRed * 0.7));
      pal1.rgbGreen := n; //_MAX(8, Round(pal1.rgbGreen * 0.7));
      pal1.rgbBlue := n; //_MAX(8, Round(pal1.rgbBlue * 0.7));
      MinDif := 768;
      MatchColor := 0;
      for j:=1 to 255 do begin
         pal2 := ctable[j];
         ColDif := Abs(pal2.rgbRed - pal1.rgbRed) +
                   Abs(pal2.rgbGreen - pal1.rgbGreen) +
                   Abs(pal2.rgbBlue - pal1.rgbBlue);
         if ColDif < MinDif then begin
            MinDif := ColDif;
            MatchColor := j;
         end;
      end;
      WhiteColorLevel[i] := MatchColor;
   end;
   RedishColorLevel[0] := 0;
   for i:=1 to 255 do begin
      pal1 := ctable[i];
      n := (pal1.rgbRed + pal1.rgbGreen + pal1.rgbBlue) div 3;
      pal1.rgbRed := n;
      pal1.rgbGreen := 0;
      pal1.rgbBlue := 0;
      MinDif := 768;
      MatchColor := 0;
      for j:=1 to 255 do begin
         pal2 := ctable[j];
         ColDif := Abs(pal2.rgbRed - pal1.rgbRed) +
                   Abs(pal2.rgbGreen - pal1.rgbGreen) +
                   Abs(pal2.rgbBlue - pal1.rgbBlue);
         if ColDif < MinDif then begin
            MinDif := ColDif;
            MatchColor := j;
         end;
      end;
      RedishColorLevel[i] := MatchColor;
   end;
   GreenColorLevel[0] := 0;
   for i:=1 to 255 do begin
      pal1 := ctable[i];
      //n := (pal1.rgbRed + pal1.rgbGreen + pal1.rgbBlue) div 5;
      //pal1.rgbRed := 0;//_MIN(Round(n / 2), 255);
      //pal1.rgbGreen := _MIN(Round(n), 255);
      //pal1.rgbBlue := 0;//_MIN(Round(n / 2), 255);
      n := (pal1.rgbRed + pal1.rgbGreen + pal1.rgbBlue) div 3;
      pal1.rgbRed := 0;
      pal1.rgbGreen := n;
      pal1.rgbBlue := 0;
      //pal1.rgbRed := _MIN(Round (pal1.rgbRed / 3), 255);
      //pal1.rgbGreen := _MIN(Round (pal1.rgbGreen * 1.5), 255);
      //pal1.rgbBlue := _MIN(Round (pal1.rgbBlue / 3), 255);
      MinDif := 768;
      MatchColor := 0;
      for j:=1 to 255 do begin
         pal2 := ctable[j];
         ColDif := Abs(pal2.rgbRed - pal1.rgbRed) +
                   Abs(pal2.rgbGreen - pal1.rgbGreen) +
                   Abs(pal2.rgbBlue - pal1.rgbBlue);
         if ColDif < MinDif then begin
            MinDif := ColDif;
            MatchColor := j;
         end;
      end;
      GreenColorLevel[i] := MatchColor;
   end;
   YellowColorLevel[0] := 0;
   for i:=1 to 255 do begin
      pal1 := ctable[i];
      n := (pal1.rgbRed + pal1.rgbGreen + pal1.rgbBlue) div 3;
      pal1.rgbRed := n;
      pal1.rgbGreen := n;
      pal1.rgbBlue := 0;
      MinDif := 768;
      MatchColor := 0;
      for j:=1 to 255 do begin
         pal2 := ctable[j];
         ColDif := Abs(pal2.rgbRed - pal1.rgbRed) +
                   Abs(pal2.rgbGreen - pal1.rgbGreen) +
                   Abs(pal2.rgbBlue - pal1.rgbBlue);
         if ColDif < MinDif then begin
            MinDif := ColDif;
            MatchColor := j;
         end;
      end;
      YellowColorLevel[i] := MatchColor;
   end;
   BlueColorLevel[0] := 0;
   for i:=1 to 255 do begin
      pal1 := ctable[i];
      //n := (pal1.rgbRed + pal1.rgbGreen + pal1.rgbBlue) div 5;
      n := (pal1.rgbRed + pal1.rgbGreen + pal1.rgbBlue) div 3;
      pal1.rgbRed := 0; //_MIN(Round(n*1.3), 255);
      pal1.rgbGreen := 0; //_MIN(Round(n), 255);
      pal1.rgbBlue := n; //_MIN(Round(n*1.3), 255);
      MinDif := 768;
      MatchColor := 0;
      for j:=1 to 255 do begin
         pal2 := ctable[j];
         ColDif := Abs(pal2.rgbRed - pal1.rgbRed) +
                   Abs(pal2.rgbGreen - pal1.rgbGreen) +
                   Abs(pal2.rgbBlue - pal1.rgbBlue);
         if ColDif < MinDif then begin
            MinDif := ColDif;
            MatchColor := j;
         end;
      end;
      BlueColorLevel[i] := MatchColor;
   end;
   FuchsiaColorLevel[0] := 0;
   for i:=1 to 255 do begin
      pal1 := ctable[i];
      n := (pal1.rgbRed + pal1.rgbGreen + pal1.rgbBlue) div 3;
      pal1.rgbRed := n;
      pal1.rgbGreen := 0;
      pal1.rgbBlue := n;
      MinDif := 768;
      MatchColor := 0;
      for j:=1 to 255 do begin
         pal2 := ctable[j];
         ColDif := Abs(pal2.rgbRed - pal1.rgbRed) +
                   Abs(pal2.rgbGreen - pal1.rgbGreen) +
                   Abs(pal2.rgbBlue - pal1.rgbBlue);
         if ColDif < MinDif then begin
            MinDif := ColDif;
            MatchColor := j;
         end;
      end;
      FuchsiaColorLevel[i] := MatchColor;
   end;
end;


procedure SaveNearestIndex (flname: string);
var
   nih: TNearestIndexHeader;
   fhandle: integer;
begin
   nih.Title := 'WEMADE Entertainment Inc.';
   nih.IndexCount := Sizeof(Color256Mix);
   if FileExists (flname) then begin
      fhandle := FileOpen (flname, fmOpenWrite or fmShareDenyNone);
   end else
      fhandle := FileCreate (flname);
   if fhandle > 0 then begin
      FileWrite (fhandle, nih, sizeof(TNearestIndexHeader));
      FileWrite (fhandle, Color256Mix, sizeof(Color256Mix));
      FileWrite (fhandle, Color256Anti, sizeof(Color256Anti));
      FileWrite (fhandle, HeavyDarkColorLevel, sizeof(HeavyDarkColorLevel));
      FileWrite (fhandle, LightDarkColorLevel, sizeof(LightDarkColorLevel)); 
      FileWrite (fhandle, DengunColorLevel, sizeof(DengunColorLevel));
      FileClose (fhandle);
   end;
end;

function LoadNearestIndex (flname: string): Boolean;
var
   nih: TNearestIndexHeader;
   fhandle, rsize: integer;
begin
   Result := FALSE;
   if FileExists (flname) then begin
      fhandle := FileOpen (flname, fmOpenRead or fmShareDenyNone);
      if fhandle > 0 then begin
         FileRead (fhandle, nih, sizeof(TNearestIndexHeader));
         if nih.IndexCount = Sizeof(Color256Mix) then begin
            Result := TRUE;
            rsize := 256*256;
            if rsize <> FileRead (fhandle, Color256Mix, sizeof(Color256Mix)) then Result := FALSE;
            if rsize <> FileRead (fhandle, Color256Anti, sizeof(Color256Anti)) then Result := FALSE;
            if rsize <> FileRead (fhandle, HeavyDarkColorLevel, sizeof(HeavyDarkColorLevel)) then Result := FALSE;
            if rsize <> FileRead (fhandle, LightDarkColorLevel, sizeof(LightDarkColorLevel)) then Result := FALSE;
            if rsize <> FileRead (fhandle, DengunColorLevel, sizeof(DengunColorLevel)) then Result := FALSE;
         end;
         FileClose (fhandle);
      end;
   end;
end;

procedure FogCopy (PSource: Pbyte; ssx, ssy, swidth, sheight: integer;
                   PDest: Pbyte; ddx, ddy, dwidth, dheight, maxfog: integer);
var
   i, j, n, k, row, srclen, scount, si, di, srcheight, spitch, dpitch: integer;
   sptr, dptr: PByte;
begin
   if (PSource = nil) or (pDest = nil) then exit; 
   spitch := swidth;
   dpitch := dwidth;
   if ddx < 0 then begin
      ssx := ssx - ddx;
      swidth := swidth + ddx;
      //dwidth := dwidth + ddx;
      ddx := 0;
   end;
   if ddy < 0 then begin
      ssy := ssy - ddy;
      sheight := sheight + ddy;
      //dheight := dheight + ddy;
      ddy := 0;
   end;
   //if ssx+swidth > dwidth then swidth := dwidth - ssx;
   //if ssy+sheight > dheight then sheight := dheight - ssy;
   srclen := _MIN(swidth, dwidth-ddx);
   srcheight := _MIN(sheight, dheight-ddy);
   if (srclen <= 0) or (srcheight <= 0) then exit;

   asm
         mov   row, 0
      @@NextRow:
         mov   eax, row
         cmp   eax, srcheight
         jae   @@Finish

         mov   esi, psource
         mov   eax, ssy
         add   eax, row
         mov   ebx, spitch
         imul  eax, ebx
         add   eax, ssx
         add   esi, eax          //sptr

         mov   edi, pdest
         mov   eax, ddy
         add   eax, row
         mov   ebx, dpitch
         imul  eax, ebx
         add   eax, ddx
         add   edi, eax          //dptr

         mov   ebx, srclen
      @@FogNext:
         cmp   ebx, 0
         jbe   @@FinOne
         cmp   ebx, 8
         jb    @@FinOne   //@@EageNext

         db $0F,$6F,$06           /// movq  mm0, [esi]
         db $0F,$6F,$0F           /// movq  mm1, [edi]
         db $0F,$FE,$C8           /// paddd mm1, mm0
         db $0F,$7F,$0F           /// movq [edi], mm1

         sub   ebx, 8
         add   esi, 8
         add   edi, 8
         jmp   @@FogNext
      {@@EageNext:
         movzx eax, [esi].byte
         movzx ecx, [edi].byte
         add   eax, ecx
         mov   [edi].byte, al

         dec   ebx
         inc   esi
         inc   edi
         jmp   @@FogNext }
      @@FinOne:
         inc   row
         jmp   @@NextRow

      @@Finish:
         db $0F,$77               /// emms
   end;
end;

procedure DrawFog (ssuf: TDirectDrawSurface; fogmask: PByte; fogwidth: integer);
//var
//   i, j, idx, row, n, count: integer;
//   ddsd: TDDSurfaceDesc2;
//   sptr, mptr, pmix: PByte;
//   //source: array[0..910] of byte;
//   bitindex, scount, dcount, srclen, destlen, srcheight: integer;
//   lpitch: integer;
//   src, msk: array[0..7] of byte;
//   pSrc, psource, pColorLevel: Pbyte;
begin
//   if ssuf.Width > 900 then exit;
//   case DarkLevel of
//      1: pColorLevel := @HeavyDarkColorLevel;
//      2: pColorLevel := @LightDarkColorLevel;
//      3: pColorLevel := @DengunColorLevel;
//      else exit;
//   end;
//   try
//      ddsd.dwSize := SizeOf(ddsd);
//      ssuf.Lock (TRect(nil^), ddsd);
//      srclen := _MIN(ssuf.Width, fogwidth);
//      pSrc := @src;
//      srcheight := ssuf.Height;
//      lpitch := ddsd.lPitch;
//      psource := ddsd.lpSurface;
//
//      asm
//            mov   row, 0
//         @@NextRow:
//            mov   ebx, row
//            mov   eax, srcheight
//            cmp   ebx, eax
//            jae   @@DrawFogFin
//
//            mov   esi, psource      //esi = ddsd.lpSurface;
//            mov   eax, lpitch
//            mov   ebx, row
//            imul  eax, ebx
//            add   esi, eax
//
//            mov   edi, fogmask      //edi = fogmask
//            mov   eax, fogwidth
//            mov   ebx, row
//            imul  eax, ebx
//            add   edi, eax
//
//            mov   ecx, srclen
//            mov   edx, pColorLevel
//
//         @@NextByte:
//            cmp   ecx, 0
//            jbe   @@Finish
//
//            movzx eax, [edi].byte   //fogmask
//            ///cmp   eax, 30
//            ///ja    @@SkipByte
//            imul  eax, 256
//            movzx ebx, [esi].byte   //¼Ò½º ddsd.lpSurface;
//            add   eax, ebx
//            mov   al, [edx+eax].byte //pColorLevel
//            mov   [esi].byte, al
//         ///@@SkipByte:
//            dec   ecx
//            inc   esi
//            inc   edi
//            jmp   @@NextByte
//
//         @@Finish:
//            inc   row
//            jmp   @@NextRow
//
//         @@DrawFogFin:
//            db $0F,$77               /// emms
//      end;
//   finally
//      ssuf.UnLock;
//   end;
end;

procedure DrawFog2 (ssuf: TDirectDrawSurface; fogmask: PByte; fogwidth: integer);
//var
//   i, j, n, scount, srclen, offsvalue: integer;
//   sddsd: TDDSurfaceDesc2;
//   sptr, fptr, pColorLevel: Pbyte;
//   source: array[0..810] of byte;
begin
//   if ssuf.Width > 800 then exit;
//   try
//      sddsd.dwSize := SizeOf(sddsd);
//      ssuf.Lock (TRect(nil^), sddsd);
//      srclen := _MIN(ssuf.Width, fogwidth);
//      case DarkLevel of
//         0: pColorLevel := @HeavyDarkColorLevel;
//         1: pColorLevel := @LightDarkColorLevel;
//         2: pColorLevel := @DengunColorLevel;
//      end;
//      for i:=0 to ssuf.height-1 do begin
//         sptr := PBYTE(integer(sddsd.lpSurface) + i*sddsd.lPitch);
//         fptr := PBYTE(integer(fogmask) + i*fogwidth);
//         asm
//               mov   scount, 0
//               mov   esi, sptr
//               lea   edi, source
//            @@CopySource:
//               mov   ebx, scount        //ebx = scount
//               cmp   ebx, srclen
//               jae   @@EndSourceCopy
//               db $0F,$6F,$04,$1E       /// movq  mm0, [esi+ebx]
//               db $0F,$7F,$07           /// movq  [edi], mm0
//
//               xor   ebx, ebx
//            @@Loop8:
//               cmp   ebx, 8
//               jz    @@EndLoop8
//               mov   ecx, fptr
//               add   ecx, scount
//               add   ecx, ebx
//               movzx eax, [ecx].byte
//               cmp   eax, 30
//               jae   @@Skip
//               imul  eax, 256
//               mov   ecx, eax
//
//
//               movzx eax, [edi+ebx].byte
//               mov   edx, pColorLevel
//               add   edx, ecx
//               movzx eax, [edx+eax].byte     //
//               mov   [edi+ebx], al
//            @@Skip:
//               inc   ebx
//               jmp   @@Loop8
//            @@EndLoop8:
//
//               mov   ebx, scount
//               db $0F,$6F,$07           /// movq  mm0, [edi]
//               db $0F,$7F,$04,$1E       /// movq  [esi+ebx], mm0
//
//               add   edi, 8
//               add   scount, 8
//               jmp   @@CopySource
//            @@EndSourceCopy:
//               db $0F,$77               /// emms
//
//         end;
//      end;
//   finally
//      ssuf.UnLock;
//   end;
end;


//procedure MakeDark (ssuf: TDirectDrawSurface; darklevel: integer);
//var
//   i, j, idx, row, n, count: integer;
//   ddsd: TDDSurfaceDesc2;
//   sptr, mptr, pmix: PByte;
//   //source: array[0..910] of byte;
//   bitindex, scount, dcount, srclen, destlen, srcheight: integer;
//   lpitch: integer;
//   src, msk: array[0..7] of byte;
//   pSrc, psource, pColorLevel: Pbyte;
//begin
//   if not darklevel in [1..30] then exit;
//   if ssuf.Width > 900 then exit;
//   try
//      ddsd.dwSize := SizeOf(ddsd);
//      ssuf.Lock (TRect(nil^), ddsd);
//      srclen := ssuf.Width;
//      srcheight := ssuf.Height;
//      pSrc := @src;
//      //if HeavyDark then pColorLevel := @HeavyDarkColorLevel
//      //else pColorLevel := @LightDarkColorLevel;
//      pColorLevel := @HeavyDarkColorLevel;
//      lpitch := ddsd.lPitch;
//      psource := ddsd.lpSurface;
//
//      asm
//            mov   row, 0
//         @@NextRow:
//            mov   ebx, row
//            mov   eax, srcheight
//            cmp   ebx, eax
//            jae   @@DrawFogFin
//
//            mov   esi, psource      //sptr
//            mov   eax, lpitch
//            mov   ebx, row
//            imul  eax, ebx
//            add   esi, eax
//
//            mov   eax, srclen
//            mov   scount, eax
//         @@FogNext:
//            mov   edx, pSrc     //pSrc = array[0..7]
//            mov   ebx, scount
//            cmp   ebx, 0
//            jbe   @@Finish
//            cmp   ebx, 8
//            jb    @@FogSmall
//
//            db $0F,$6F,$06           /// movq  mm0, [esi]       //8¹ÙÀÌÆ® ÀÐÀ½ sptr
//            db $0F,$7F,$02           /// movq  [edx], mm0
//            mov   count, 8
//
//          @@LevelChange:
//            mov   eax, darklevel
//            imul  eax, 256
//            movzx ebx, [edx].byte   //8¹ÙÀÌÆ® ¹­À½À¸·Î ÀÐÀº µ¥ÀÌÅÍ
//            add   eax, ebx
//            mov   ebx, pColorLevel
//            mov   al, [ebx+eax].byte
//            mov   [edx].byte, al
//
//         @@Skip1:
//            dec   count
//            inc   edx
//            inc   edi
//            cmp   count, 0
//            ja    @@LevelChange
//            sub   edx, 8
//
//            db $0F,$6F,$02           /// movq  mm0, [edx]
//            db $0F,$7F,$06           /// movq  [esi], mm0
//         @@Skip_8Byte:
//            sub   scount, 8
//            add   esi, 8
//            jmp   @@FogNext
//
//         @@FogSmall:
//            mov   eax, darklevel
//            imul  eax, 256
//            movzx ebx, [edx].byte
//            add   eax, ebx
//            mov   ebx, pColorLevel
//            mov   al, [ebx+eax].byte
//            mov   [esi].byte, al
//
//         @@Skip2:
//            inc   edi
//            inc   esi
//            dec   scount
//            jmp   @@FogNext
//
//         @@Finish:
//            inc   row
//            jmp   @@NextRow
//
//         @@DrawFogFin:
//            db $0F,$77               /// emms
//      end;
//   finally
//      ssuf.UnLock;
//   end;
//end;

//ssuf(system memory) -> dsuf(video memory)  : ÀÌ¶§¸¸ »ç¿ëÇÒ °Í
//³ÐÀÌ´Â 8ÀÇ ¹è¼ö
procedure MMXBlt (ssuf, dsuf: TDirectDrawSurface);
//var
//   n, m, aheight, awidth, spitch, dpitch: integer;
//   sddsd, dddsd: TDDSurfaceDesc2;
//   sptr, dptr: PByte;
begin
//   try
//      sddsd.dwSize := SizeOf(sddsd);
//      ssuf.Lock (TRect(nil^), sddsd);
//      dddsd.dwSize := Sizeof(dddsd);
//      dsuf.Lock (TRect(nil^), dddsd);
//      aheight := ssuf.Height-1;
//      awidth := ssuf.Width-1;
//      spitch := sddsd.lPitch;
//      dpitch := dddsd.lPitch;
//      sptr := sddsd.lpSurface; //esi
//      dptr := dddsd.lpSurface; //edi
//      m := -1; //height
//      asm
//       @@NextLine:
//         inc   m
//         mov   eax, m
//         cmp   eax, aheight
//         jae   @@End
//         //sptr
//         mov   esi, sptr
//         mov   ebx, spitch
//         imul  eax, ebx
//         add   esi, eax
//         //dptr
//         mov   eax, m
//         mov   edi, dptr
//         mov   ebx, dpitch
//         imul  eax, ebx
//         add   edi, eax
//
//         xor   eax, eax
//       @@CopyNext:
//         cmp   eax, awidth
//         jae   @@NextLine
//
//         db $0F,$6F,$04,$06       /// movq  mm0, [esi+eax]
//         db $0F,$7F,$04,$07       /// movq  [edi+eax], mm0
//
//         add   eax, 8
//         jmp   @@CopyNext
//
//       @@End:
//         db $0F,$77               /// emms
//      end;
//   finally
//      ssuf.UnLock;
//      dsuf.UnLock;
//   end;
end;

procedure   SpriteCopy(DestX, DestY : integer;
                       SourX, SourY : integer;
                       Size         : TPoint;
                       Sour, Dest   : TDirectDrawSurface);
const
   TRANSPARENCY_VALUE  = 0; // Åõ¸í»öÀÌ 0¹ø ÀÎµ¦½ºÀÌ´Ù.
//var
//   SourDesc, DestDesc  : TDDSurfaceDesc2;
//   pSour, pDest, pMask : PByte;
//   Transparency        : array[1..8] of byte;
begin
//   FillChar(Transparency,8,TRANSPARENCY_VALUE);
//
//   SourDesc.dwSize := SizeOf(DDSURFACEDESC);
//   Sour.Lock (TRect(nil^), SourDesc);
//   DestDesc.dwSize := SizeOf(DDSURFACEDESC);
//   Dest.Lock (TRect(nil^), DestDesc);
//
//   pSour := PByte(DWORD(SourDesc.lpSurface)+SourY*SourDesc.lPitch+SourX);
//   pDest := PByte(DWORD(DestDesc.lpSurface)+DestY*DestDesc.lPitch+DestX);
//   pMask := Pointer(@Transparency);
//
//   asm
//         push  esi
//         push  edi
//
//         mov   esi, pMask
//         db $0F,$6F,$26       /// movq  mm4, [esi]
//                              //  mm4 ¿¡ Åõ¸í»ö ¹øÈ£¸¦ ³Ö´Â´Ù
//         mov   esi, pSour
//         mov   edi, pDest
//
//         mov   ecx, Size.Y
//
//   @@LOOP_Y:
//
//         push  ecx
//
//         mov   ecx, Size.X
//         shr   ecx, 3         // µ¿½Ã¿¡ 8°³ÀÇ Á¡À» ¿¬»êÇÏ¹Ç·Î
//
//
//   @@LOOP_X:
//
//         db $0F,$6F,$07       /// movq  mm0, [edi]
//                              //  mm0 Àº Destination
//         db $0F,$6F,$0E       /// movq  mm1, [esi]
//                              //  mm1 Àº Source
//         db $0F,$6F,$D1       /// movq  mm2, mm1
//                              //  mm2 ¿¡ Source µ¥ÀÌÅÍ¸¦ º¹»ç
//         db $0F,$74,$D4       /// pcmpeqb mm2, mm4
//                              //  mm2 ¿¡ Åõ¸í»ö¿¡ µû¸¥ ¸¶½ºÅ©¸¦ »ý¼º
//         db $0F,$6F,$DA       /// movq  mm3, mm2
//                              //  mm3 ¿¡ ¸¶½ºÅ©¸¦ ÇÏ³ª ´õ º¹»ç
//         db $0F,$DF,$D1       /// pandn mm2, mm1
//                              //  Source ½ºÇÁ¶óÀÌÆ® ºÎºÐ¸¸À» ³²±è
//         db $0F,$DB,$D8       /// pand  mm3, mm0
//                              //  Destination ÀÇ °»½ÅµÉ ºÎºÐ¸¸ Á¦°Å
//         db $0F,$EB,$D3       /// por   mm2, mm3
//                              //  Source ¿Í Destination À» °áÇÕ
//         db $0F,$7F,$17       /// movq  [edi], mm2
//                              //  Destination ¿¡ °á°ú¸¦ ¾¸
//
//         add   esi, 8
//                              //  ÇÑ¹ø¿¡ 8 bytes ¸¦ µ¿½Ã¿¡ Ã³¸®ÇßÀ¸¹Ç·Î
//         add   edi, 8
//
//         loop  @@LOOP_X
//
//         add   esi, SourDesc.lPitch
//         sub   esi, Size.X
//         add   edi, DestDesc.lPitch
//         sub   edi, Size.X
//
//         pop   ecx
//         loop  @@LOOP_Y
//
//         db $0F,$77              /// emms
//
//         pop   edi
//         pop   esi
//
//   end;
//
//   Sour.UnLock;
//   Dest.UnLock;

end;

procedure CopyStrToClipboard(sStr: string);
var
  Clipboard: TClipboard;
begin
  Clipboard := TClipboard.Create;
  try
    Clipboard.AsText := sStr;
  finally
    Clipboard.Free;
  end;
end;

procedure LoadColorLevels();
var
  i: integer;
  nA, nR, nG, nB, nX: Byte;
begin
  ImgMixSurfaceR5G6B5 := MakeDXImageTexture(DEFSCREENWIDTH, DEFSCREENHEIGHT, WILFMT_R5G6B5);
  ImgMixSurfaceA1R5G5B5 := MakeDXImageTexture(DEFSCREENWIDTH, DEFSCREENHEIGHT, WILFMT_A1R5G5B5);
  ImgMixSurfaceA4R4G4B4 := MakeDXImageTexture(DEFSCREENWIDTH, DEFSCREENHEIGHT, WILFMT_A4R4G4B4);
  ImgMaxSurfaceR5G6B5 := MakeDXImageTexture(DEFSCREENWIDTH, DEFSCREENHEIGHT, WILFMT_R5G6B5);
  ImgMaxSurfaceA1R5G5B5 := MakeDXImageTexture(DEFSCREENWIDTH, DEFSCREENHEIGHT, WILFMT_A1R5G5B5);
  ImgMaxSurfaceA4R4G4B4 := MakeDXImageTexture(DEFSCREENWIDTH, DEFSCREENHEIGHT, WILFMT_A4R4G4B4);
  ImgMixSurfaceR5G6B5.Canvas := g_DXCanvas;
  ImgMixSurfaceA1R5G5B5.Canvas := g_DXCanvas;
  ImgMixSurfaceA4R4G4B4.Canvas := g_DXCanvas;
  ImgMaxSurfaceR5G6B5.Canvas := g_DXCanvas;
  ImgMaxSurfaceA1R5G5B5.Canvas := g_DXCanvas;
  ImgMaxSurfaceA4R4G4B4.Canvas := g_DXCanvas;
  GrayScaleByR5G6B5[0] := 0;
  GrayScaleByA1R5G5B5[0] := 0;
  GrayScaleByA4R4G4B4[0] := 0;
  for I := Low(Word) to High(Word) do begin
    //R5G6B5
    nB := BYTE((Word(I) and $1F) shl 3);
    nG := BYTE((Word(I) and $7E0) shr 3);
    nR := BYTE((Word(I) and $F800) shr 8);
    nX := (nR + nG + nB) div 3;
    GrayScaleByR5G6B5[I] := ((Word(nX) and $F8) shl 8) + (Word(nX) and $FC shl 3) + (Word(nX) shr 3);

    //A1R5G5B5
    nB := BYTE((Word(I) and $1F) shl 3);
    nG := BYTE((Word(I) and $3E0) shr 2);
    nR := BYTE((Word(I) and $7C00) shr 7);
    nA := BYTE((Word(I) and $8000) shr 15);
    nX := (nR + nG + nB) div 3;
    GrayScaleByA1R5G5B5[I] := Word(nA) shl 15 + ((Word(nX) and $F8) shl 7) + (Word(nX) and $F8 shl 2) + (Word(nX) shr 3);

    //A4R4G4B4
    nB := BYTE((Word(I) and $F) shl 4);
    nG := BYTE(Word(I) and $F0);
    nR := BYTE((Word(I) and $F00) shr 4);
    nA := BYTE((Word(I) and $F000) shr 8);
    nX := (nR + nG + nB) div 3;
    GrayScaleByA4R4G4B4[I] := Word(nA) and $F0 shl 8 + ((Word(nX) and $F0) shl 4) + (Word(nX) and $F0) + (Word(nX) shr 4);

    nB := BYTE((Word(I) and $1F) shl 3);
    nG := BYTE((Word(I) and $3E0) shr 2);
    nR := BYTE((Word(I) and $7C00) shr 7);
    nA := BYTE((Word(I) and $8000) shr 15);
    nX := (nR + nG + nB) div 3;
    if nA = 0 then
      GSA1R5G5B5ToA4R4G4B4[I] := ((Word(nX) and $F0) shl 4) + (Word(nX) and $F0) + (Word(nX) shr 4)
    else
      GSA1R5G5B5ToA4R4G4B4[I] := $F000 + ((Word(nX) and $F0) shl 4) + (Word(nX) and $F0) + (Word(nX) shr 4);
  end;
end;

procedure UnLoadColorLevels();
begin
  if ImgMixSurfaceR5G6B5 <> nil then
    ImgMixSurfaceR5G6B5.Free;
  if ImgMixSurfaceA1R5G5B5 <> nil then
    ImgMixSurfaceA1R5G5B5.Free;
  if ImgMixSurfaceA4R4G4B4 <> nil then
    ImgMixSurfaceA4R4G4B4.Free;
  ImgMixSurfaceR5G6B5 := nil;
  ImgMixSurfaceA1R5G5B5 := nil;
  ImgMixSurfaceA4R4G4B4 := nil;
  if ImgMaxSurfaceR5G6B5 <> nil then
    ImgMaxSurfaceR5G6B5.Free;
  if ImgMaxSurfaceA1R5G5B5 <> nil then
    ImgMaxSurfaceA1R5G5B5.Free;
  if ImgMaxSurfaceA4R4G4B4 <> nil then
    ImgMaxSurfaceA4R4G4B4.Free;
  ImgMaxSurfaceR5G6B5 := nil;
  ImgMaxSurfaceA1R5G5B5 := nil;
  ImgMaxSurfaceA4R4G4B4 := nil;
end;

function GetTempSurface(ColorFormat: TWILColorFormat): TDirectDrawSurface;
begin
  Result := nil;
  case ColorFormat of
    WILFMT_A1R5G5B5: begin
      if boA1R5G5B5 then Result := ImgMaxSurfaceA1R5G5B5
      else Result := ImgMixSurfaceA1R5G5B5;
      boA1R5G5B5 := not boA1R5G5B5;
    end;
    WILFMT_A4R4G4B4: begin
      if boA4R4G4B4 then Result := ImgMaxSurfaceA4R4G4B4
      else Result := ImgMixSurfaceA4R4G4B4;
      boA4R4G4B4 := not boA4R4G4B4;
    end;
    WILFMT_R5G6B5: begin
      if boR5G6B5 then Result := ImgMaxSurfaceR5G6B5
      else Result := ImgMixSurfaceR5G6B5;
      boR5G6B5 := not boR5G6B5;
    end;
  end;
  if Result <> nil then
    Result.PatternSize := Point(DEFSCREENWIDTH, DEFSCREENHEIGHT);
end;

procedure DrawBlendShadow(dsuf: TDirectDrawSurface; x, y, stype: integer; ssuf: TDirectDrawSurface; blendmode: integer);
begin
  if blendmode = 0 then
    dsuf.DrawShadow(x, y, stype, ssuf.ClientRect, ssuf, $FF161616, Blend_OneColor)
  else
    dsuf.DrawShadow(x, y, stype, ssuf.ClientRect, ssuf, $601F1F1F, Blend_OneColor);
end;

procedure DrawBlendShadow(dsuf: TDirectDrawSurface; x, y, sx, sy, stype: integer; ssuf: TDirectDrawSurface; blendmode: integer);
begin
  if blendmode = 0 then
    dsuf.DrawShadow(x, y, sx, sy, stype, ssuf.ClientRect, ssuf, $FF161616, Blend_OneColor)
  else
    dsuf.DrawShadow(x, y, sx, sy, stype, ssuf.ClientRect, ssuf, $601F1F1F, Blend_OneColor);
end;

procedure DrawBlend(dsuf: TDirectDrawSurface; x, y: integer; ssuf: TDirectDrawSurface; blendmode: integer);
begin
  if blendmode = 100 then
    dsuf.Draw(x, y, ssuf.ClientRect, ssuf, $FF1F1F1F, fxAnti)
  else if blendmode = 0 then
    dsuf.Draw(x, y, ssuf.ClientRect, ssuf, $80FFFFFF, fxBlend)
  else
    dsuf.Draw(x, y, ssuf.ClientRect, ssuf, fxAnti);
end;

procedure DrawBlendEx(dsuf: TDirectDrawSurface; x, y: integer; ssuf: TDirectDrawSurface; blendmode: integer);
begin
  if blendmode = 0 then
    dsuf.Draw(x, y, ssuf.ClientRect, ssuf, $03FFFFFF, fxBlend)
  else
    dsuf.Draw(x, y, ssuf.ClientRect, ssuf, fxAnti);
end;

procedure DrawBlendR(dsuf: TDirectDrawSurface; x, y: integer; Rect: TRect; ssuf: TDirectDrawSurface; blendmode:
  integer);
begin
  if blendmode = 0 then
    dsuf.Draw(x, y, Rect, ssuf, $80FFFFFF, fxBlend)
  else
  if blendmode = 2 then
    dsuf.Draw(x, y, Rect, ssuf, $C1C1C1C1, fxAnti)
  else
  if blendmode = 100 then
    dsuf.Draw(x, y, Rect, ssuf, $FF1F1F1F, fxAnti)
  else
    dsuf.Draw(x, y, Rect, ssuf, fxAnti);
end;

procedure DrawEffect(dsuf: TDirectDrawSurface; x, y: integer; ssuf: TDirectDrawSurface; eff: TColorEffect; boBlend:
  Boolean; blendmode: integer);
var
  nColor: Integer;
  SourceAccess, TargetAccess: TDXAccessInfo;
  peff: PByte;
  TargetTexture: TDirectDrawSurface;
  SourcePtr, TargetPtr: PChar;
  I, nCount: Integer;
  DrawFx: Cardinal;
  nWidth, nHeight: Integer;
begin
  if (dsuf = nil) or (ssuf = nil) then Exit;

  if boBlend then nColor := Integer($80000000)
  else nColor := Integer($FF000000);

  if blendmode = 0 then DrawFx := fxBlend
  else DrawFx := fxAnti;

  case eff of
    ceNone: begin
      dsuf.Draw (x, y, ssuf.ClientRect, ssuf, DrawFx);
      exit;
    end;
    ceGrayScale: begin
      Dsuf.Draw(x, y, ssuf.ClientRect, ssuf,Blend_GrayScale);
    end;
    ceBright: begin //¸ßÁÁ
      Dsuf.Draw(x, y, ssuf.ClientRect, ssuf, clWhite or nColor, fxBlend); //ÁÁ¶ÈÊÊÖÐ£¬½Ó½üÐ¡»ð¾æ
      Dsuf.Draw(x, y, ssuf.ClientRect, ssuf, $FF696969, fxAnti); //¹âÁÁÐ§¹û Éî»ÒÉ«
    end;
    ceRed: Dsuf.Draw(x, y, ssuf.ClientRect, ssuf, clRed or nColor, DrawFx);
    ceGreen: Dsuf.Draw(x, y, ssuf.ClientRect, ssuf, clGreen or nColor, DrawFx);
    ceBlue: Dsuf.Draw(x, y, ssuf.ClientRect, ssuf, clBlue or nColor, DrawFx);
    ceYellow: Dsuf.Draw(x, y, ssuf.ClientRect, ssuf, clYellow or nColor, DrawFx);
    ceFuchsia: Dsuf.Draw(x, y, ssuf.ClientRect, ssuf, clFuchsia or nColor, DrawFx);
  end;
end;

procedure MakeDark(darklevel: integer);
var
  dark: TColor;
begin
  dark := ARGB(darklevel, 0, 0, 0);
  g_DXCanvas.FillRect(0, 0, 800, 600, 8 or dark);
end;

end.
