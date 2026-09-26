unit FrmMain;

interface

uses
  Windows, Messages, SysUtils, StrUtils, Variants, Classes, Graphics, Controls,
  Forms, TDX9Textures, MyDXBase, MyDirect3D9, GraphicEx, ShellAPI, Dialogs,
  Menus, ToolWin, ComCtrls, ExtCtrls, Grids, ImgList, StdCtrls, ZShare, WIL,
  TDX9Devices, TeCanvas, ExtDlgs;

type
  TFormMain = class(TForm)
    MainMainMenu: TMainMenu;
    MEMU_FILE: TMenuItem;
    MEMU_FILE_NEW: TMenuItem;
    MEMU_FILE_CLOSE: TMenuItem;
    N2: TMenuItem;
    MEMU_FILE_AGOFILE: TMenuItem;
    MEMU_FILE_AGOFILE_PATHS: TMenuItem;
    N1: TMenuItem;
    MEMU_FILE_EXIT: TMenuItem;
    StatusBar: TStatusBar;
    Splitter1: TSplitter;
    DrawGrid: TDrawGrid;
    StandardToolBar: TToolBar;
    Tool_New: TToolButton;
    OpenButton: TToolButton;
    CloseButton: TToolButton;
    ToolbarImages: TImageList;
    Tool_Image_Add: TToolButton;
    Tool_Image_Put: TToolButton;
    Tool_Image_Del: TToolButton;
    ToolButton2: TToolButton;
    Tool_AUTOIMAGE: TToolButton;
    ToolButton8: TToolButton;
    Tool_Front: TToolButton;
    Tool_Next: TToolButton;
    ToolButton13: TToolButton;
    MEMU_WORK_: TMenuItem;
    MENU_VIER_: TMenuItem;
    MENU_OPTION: TMenuItem;
    MENU_VIER_TOOLBAR: TMenuItem;
    MENU_VIER_STATUSBAR: TMenuItem;
    MENU_OPTION_BACKCOLOR: TMenuItem;
    MENU_OPTION_BLENDCOLOR: TMenuItem;
    MEMU_WORK_AUTOIMAGE: TMenuItem;
    N6: TMenuItem;
    MEMU_WORK_ADDIMAGE: TMenuItem;
    MEMU_WORK_DELIMAGE: TMenuItem;
    MEMU_WORK_PUTIMAGE: TMenuItem;
    MEMU_FILE_OPEN_DIY: TMenuItem;
    MEMU_FILE_OPEN_MIR3: TMenuItem;
    Tool_Image_Goto: TToolButton;
    ToolButton16: TToolButton;
    Panel2: TPanel;
    Tool_BlendMode: TComboBox;
    Tool_Zoom: TComboBox;
    Tool_Alpha: TTrackBar;
    OpenDialog: TOpenDialog;
    MyDevice: TDX9Device;
    Timer: TTimer;
    Tool_BlendColor: TButtonColor;
    Tool_BackColor: TButtonColor;
    SaveDialog: TSaveDialog;
    MEMU_WORK_NEXT: TMenuItem;
    MEMU_WORK_IMAGE_GOTO: TMenuItem;
    N5: TMenuItem;
    MEMU_WORK_FRONT: TMenuItem;
    N4: TMenuItem;
    MENU_OPTION_BACKIMAGE: TMenuItem;
    OpenPictureDialog: TOpenPictureDialog;
    Tool_Middle: TToolButton;
    ToolButton3: TToolButton;
    Tool_BackImage: TToolButton;
    Tool_Position: TToolButton;
    ToolButton4: TToolButton;
    Tool_Random: TToolButton;
    Tool_SrcBlend: TComboBox;
    Tool_DestBlend: TComboBox;
    Panel1: TPanel;
    ScrollBox: TScrollBox;
    PanelDraw: TPanel;
    MENU_OPTION_LEVEL: TMenuItem;
    MENU_OPTION_UPRIGHTNESS: TMenuItem;
    Tool_OutBackColor: TButtonColor;
    Tool_AlignLineColor: TButtonColor;
    Tool_OffsetLineColor: TButtonColor;
    MEMU_FILE_WIL_TO_LIB: TMenuItem;
    procedure FormCreate(Sender: TObject);
    procedure MEMU_FILE_CLOSEClick(Sender: TObject);
    procedure Tool_BackColorClick(Sender: TObject);
    procedure Tool_BlendColorClick(Sender: TObject);
    procedure MENU_VIER_TOOLBARClick(Sender: TObject);
    procedure MENU_VIER_STATUSBARClick(Sender: TObject);
    procedure MyDeviceFinalize(Sender: TObject);
    procedure MyDeviceNotifyEvent(Sender: TObject; Msg: Cardinal);
    procedure MyDeviceRender(Sender: TObject);
    procedure TimerTimer(Sender: TObject);
    procedure DrawGridDrawCell(Sender: TObject; ACol, ARow: Integer; Rect: TRect; State: TGridDrawState);
    procedure FormDestroy(Sender: TObject);
    procedure DrawGridSelectCell(Sender: TObject; ACol, ARow: Integer; var CanSelect: Boolean);
    procedure MEMU_FILE_OPEN_MIR3Click(Sender: TObject);
    procedure MEMU_FILE_OPEN_DIYClick(Sender: TObject);
    procedure OpenButtonClick(Sender: TObject);
    procedure MEMU_FILE_EXITClick(Sender: TObject);
    procedure Tool_Image_GotoClick(Sender: TObject);
    procedure Tool_NextClick(Sender: TObject);
    procedure MENU_OPTION_BLENDCOLORClick(Sender: TObject);
    procedure Tool_NewClick(Sender: TObject);
    procedure MEMU_WORK_AUTOIMAGEClick(Sender: TObject);
    procedure MEMU_WORK_ADDIMAGEClick(Sender: TObject);
    procedure MEMU_WORK_PUTIMAGEClick(Sender: TObject);
    procedure MEMU_WORK_DELIMAGEClick(Sender: TObject);
    procedure Tool_BlendModeChange(Sender: TObject);
    procedure MENU_OPTION_BACKIMAGEClick(Sender: TObject);
    procedure Tool_AlphaChange(Sender: TObject);
    procedure Tool_ZoomChange(Sender: TObject);
    procedure PanelDrawMouseDown(Sender: TObject; Button: TMouseButton; Shift: TShiftState; X, Y: Integer);
    procedure PanelDrawMouseMove(Sender: TObject; Shift: TShiftState; X, Y: Integer);
    procedure PanelDrawMouseUp(Sender: TObject; Button: TMouseButton; Shift: TShiftState; X, Y: Integer);
    procedure Tool_DestBlendChange(Sender: TObject);
    procedure MyDeviceInitialize(Sender: TObject; var Success: Boolean; var ErrorMsg: string);
    procedure MENU_OPTION_LEVELClick(Sender: TObject);
    procedure MENU_OPTION_UPRIGHTNESSClick(Sender: TObject);
    procedure MEMU_FILE_AGOFILE_PATHSClick(Sender: TObject);
    procedure Tool_OutBackColorClick(Sender: TObject);
    procedure Tool_AlignLineColorClick(Sender: TObject);
    procedure Tool_OffsetLineColorClick(Sender: TObject);
    procedure MEMU_FILE_WIL_TO_LIBClick(Sender: TObject);
  private
    FAutoTick: LongWord;
    FBlend: Cardinal;
    FImageX: Integer;
    FImageY: Integer;
    FShowX: Integer;
    FShowY: Integer;
    FZoomSize: Extended;
    FSpotX: Integer;
    FSpotY: Integer;
    FDown: Boolean;
    FRenderSurface: TDXRenderTargetTexture;
    FSaveDir: string;
    FLastIndex: Integer;
    FRight, FBottom: Integer;
    { Private declarations }
    procedure ReadOpenFileList();
    procedure WriteOpenFileList();
    procedure AddOpenFileList(sFileName: string);
    function FormatBitmap(const Bitmap: TBitmap; BColor: TColor; var Data: PChar): Integer;
  public
    procedure Initializeg_WMImages(WILType: TWILType);
    procedure InitializeForm();
    procedure InitializeGrid();
    procedure RefStatusBar();
    procedure OpenWMFile(sFileName: string; WILType: TWILType);
    function SetDrawGridIndex(Index: Integer): Boolean;
    procedure DrawRender(Sender: TObject);
    procedure SaveRenderToBmp(sFileName: string);
  end;

var
  FormMain: TFormMain;

implementation

uses
  wmMyImage, wmM3Def, Hutil32, FrmAdd, FrmDel, FrmOut, FrmAlpha, Registry, MyCommon;

{$R *.dfm}
{$R ColorTable.RES}

const
  MAXWIDTH = 1920;
  MAXHEIGHT = 1080;
  WINLEFT = 60;
  WINTOP = 60;
  WINRIGHT = MAXWIDTH - 60;
  BOTTOMEDGE = MAXHEIGHT - 60;
  COL_COUNT = 16;

var
  BltBitmap: TBitmap;

procedure TFormMain.DrawGridDrawCell(Sender: TObject; ACol, ARow: Integer; Rect: TRect; State: TGridDrawState);
var
  OldColor: TColor;
  BitMap, BitMap2: TBitmap;
  nRect, iRect: TRect;
  Idx, X, Y: Integer;
  Str: string;
  boStr: Boolean;
begin
  if (g_WMImages <> nil) and g_WMImages.boInitialize then begin
    OldColor := 0;
    with DrawGrid.Canvas do begin
      if gdSelected in State then begin
        DrawGrid.Canvas.Brush.Color := clMenuHighlight;
        FillRect(Rect);
      end;

      Idx := ACol + ARow * COL_COUNT;
      BitMap2 := TBitmap.Create;
      BitMap := g_WMImages.Bitmap[Idx];

      boStr := False;
      if (BitMap <> nil) then begin
        if Bitmap.PixelFormat = pf8bit then
          SetDIBColorTable(Bitmap.Canvas.Handle, 0, 256, g_DefMainPalette);
        BitMap2.Width := _MIN(BitMap.Width, DrawGrid.DefaultColWidth);
        BitMap2.Height := _MIN(BitMap.Height, DrawGrid.DefaultRowHeight);
        if BitMap2.Height > (DrawGrid.DefaultRowHeight - 12) then
          boStr := True;
        BitMap2.Canvas.StretchDraw(BitMap2.Canvas.ClipRect, BitMap);
        BitMap2.TransparentColor := g_OutBackColor;
//        BitMap2.TransparentMode := tmFixed;
        BitMap2.Transparent := False;

        nRect.Left := 0;
        nRect.Top := 0;
        nRect.Right := Bitmap2.Width;
        nRect.Bottom := Bitmap2.Height;
        iRect := Rect;
        iRect.Right := iRect.Left + _MIN(BitMap2.Width, DrawGrid.DefaultColWidth);
        iRect.Bottom := iRect.Top + _MIN(BitMap2.Height, DrawGrid.DefaultRowHeight);
        DrawGrid.Canvas.Brush.Color := g_OutBackColor;
        DrawGrid.Canvas.BrushCopy(iRect, Bitmap2, nRect, g_OutBackColor);
        BitMap.Free;
      end;

      Bitmap2.Free;
      if (ACol + ARow * COL_COUNT) <= (g_WMImages.ImageCount - 1) then begin
        SetBkMode(Handle, TRANSPARENT);
        Str := Format('%.6d', [ACol + ARow * COL_COUNT]);
        X := Rect.Right - DrawGrid.Canvas.TextWidth(Str);
        Y := Rect.Bottom - DrawGrid.Canvas.TextHeight(Str);
        if boStr then begin
          Font.Color := clBlack;
          DrawGrid.Canvas.TextOut(X - 1, Y, Str);
          DrawGrid.Canvas.TextOut(X + 1, Y, Str);
          DrawGrid.Canvas.TextOut(X, Y - 1, Str);
          DrawGrid.Canvas.TextOut(X, Y + 1, Str);
        end;
        if boStr then
          Font.Color := clWhite
        else
          Font.Color := clBlack;
        DrawGrid.Canvas.TextOut(X, Y, Str);
        if gdSelected in State then begin
          Font.Color := OldColor;
        end;
      end;
    end;
  end;
end;

procedure TFormMain.DrawGridSelectCell(Sender: TObject; ACol, ARow: Integer; var CanSelect: Boolean);
begin
  if (g_WMImages <> nil) and g_WMImages.boInitialize then begin
    g_SelectImageIndex := ACol + ARow * COL_COUNT;
    FillChar(g_TextureInfo, SizeOf(g_TextureInfo), #0);
    g_WILColorFormat := -1;
    g_Texture[1].Clear;

    if g_WMImages.CopyDataToTexture(g_SelectImageIndex, g_Texture[1]) then begin
      FImageX := g_WMImages.LastImageInfo.px;
      FImageY := g_WMImages.LastImageInfo.py;
      g_TextureInfo := g_WMImages.LastImageInfo;
      if g_WMImages is TWMMyImageImages then
        g_WILColorFormat := Integer(g_WMImages.LastColorFormat);
    end else begin
      FImageX := 0;
      FImageY := 0;
    end;
    RefStatusBar();
  end;
end;

procedure TFormMain.DrawRender(Sender: TObject);
var
  Color4: TColor4;
  Rect: TRect;
  OffsetLineX, OffsetLineY: Word;
begin
  OffsetLineX := 0;
  OffsetLineY := 0;
  Color4 := cColor4(Tool_Alpha.Position and $FF shl 24 or (g_AlphaColor and $FFFFFF));
  MyDevice.Canvas.Draw(0, 0, g_Texture[0].ClientRect, g_Texture[0], fxNone);
  Rect := g_Texture[1].ClientRect;
  Rect.Right := Round(Rect.Right * FZoomSize);
  Rect.Bottom := Round(Rect.Bottom * FZoomSize);

  if Tool_Middle.Down then begin
    if Tool_Position.Down then begin
      Rect.Left := MAXWIDTH div 3 + FImageX;
      Rect.Top := MAXHEIGHT div 3 + FImageY;
    end
    else begin
      Rect.Left := (MAXWIDTH - Rect.Right) div 2;
      Rect.Top := (MAXHEIGHT - Rect.Bottom) div 2;
    end;
  end
  else if Tool_Random.Down then begin
    if Tool_Position.Down then begin
      Rect.Left := FImageX + FShowX;
      Rect.Top := FImageY + FShowY;
    end
    else begin
      Rect.Left := FShowX;
      Rect.Top := FShowY;
    end;
  end;
  Rect.Right := Rect.Right + Rect.Left;
  Rect.Bottom := Rect.Bottom + Rect.Top;
  FRight := Rect.Right - Rect.Left;
  FBottom := Rect.Bottom - Rect.Top;
  if FZoomSize <> 1 then
    MyDevice.Canvas.StretchDraw(Rect, g_Texture[1].ClientRect, g_Texture[1], FBlend, Color4,
      MENU_OPTION_LEVEL.Checked, MENU_OPTION_UPRIGHTNESS.Checked)
  else
    MyDevice.Canvas.Draw(Rect.Left, Rect.Top, g_Texture[1].ClientRect, g_Texture[1], FBlend, Color4,
      MENU_OPTION_LEVEL.Checked, MENU_OPTION_UPRIGHTNESS.Checked);

  MyDevice.Canvas.MoveTo(FShowX, 0);
  MyDevice.Canvas.LineTo(FShowX, PanelDraw.Height, g_AlignLineColor);
  MyDevice.Canvas.MoveTo(0, FShowY);
  MyDevice.Canvas.LineTo(PanelDraw.Width, FShowY, g_AlignLineColor);

  if Tool_Position.Down and Tool_Random.Down then begin
//    if FImageY <> 0 then begin
//      while True do begin
//        MyDevice.Canvas.MoveTo(FImageX + FShowX, OffsetLineY);
//        MyDevice.Canvas.LineTo(FImageX + FShowX, OffsetLineY + 3, g_OffsetLineColor);
//        Inc(OffsetLineY,6);
//        if OffsetLineY > PanelDraw.Height then Break;
//      end;
//    end;
//    if FImageX <> 0 then begin
//      while True do begin
//        MyDevice.Canvas.MoveTo(OffsetLineX, FImageY + FShowY);
//        MyDevice.Canvas.LineTo(OffsetLineX + 3, FImageY + FShowY, g_OffsetLineColor);
//        Inc(OffsetLineX,6);
//        if OffsetLineX > PanelDraw.Width then Break;
//      end;
//    end;
    MyDevice.Canvas.MoveTo(FImageX + FShowX, 0);
    MyDevice.Canvas.LineTo(FImageX + FShowX, PanelDraw.Height, g_OffsetLineColor);
    MyDevice.Canvas.MoveTo(0, FImageY + FShowY);
    MyDevice.Canvas.LineTo(PanelDraw.Width, FImageY + FShowY, g_OffsetLineColor);
  end;
end;

procedure TFormMain.Tool_DestBlendChange(Sender: TObject);
begin
  FBlend := (Tool_SrcBlend.ItemIndex and $FF) or (Tool_DestBlend.ItemIndex and $FF shl 8);
end;

procedure TFormMain.FormCreate(Sender: TObject);
var
  Res: TResourceStream;
begin
  Randomize;
  GetFileVersion(ParamStr(0), @g_FileVersionInfo);
  MAINFORMCAPTION := MAINFORMCAPTION + g_FileVersionInfo.sVersion;
  ReadOpenFileList;
  BltBitmap := TBitmap.Create;
  FImageX := 0;
  FImageY := 0;
  FShowX := 0;
  FShowY := 0;
  FRight := 0;
  FBottom := 0;
  FZoomSize := 1;
  FLastIndex := -1;
  FDown := False;
  PanelDraw.Width := MAXWIDTH;
  PanelDraw.Height := MAXHEIGHT;
  PanelDraw.Left := 0;
  PanelDraw.Top := 0;
  FSaveDir := '';
  Res := TResourceStream.Create(Hinstance, '256RGB', 'RGB');
  try
    Res.Read(g_DefMainPalette, SizeOf(g_DefMainPalette));
  finally
    Res.Free;
  end;
  OpenButton.Enabled := False;
  Caption := MAINFORMCAPTION;
  Tool_BackColor.SymbolColor := g_BackColor;
  Tool_BlendColor.SymbolColor := g_AlphaColor;
  Tool_OutBackColor.SymbolColor := g_OutBackColor;

  Tool_OffsetLineColor.SymbolColor := g_OffsetLineColor;
  Tool_AlignLineColor.SymbolColor := g_AlignLineColor;

  PanelDraw.Color := g_BackColor;
  ScrollBox.Color := g_BackColor;
  InitializeForm;
  FBlend := $00000504;
  Tool_BlendMode.Items.Clear;
  Tool_BlendMode.Items.AddObject('Blend_None', TObject($00000001));
  Tool_BlendMode.Items.AddObject('Blend_Default', TObject($00000504));
  Tool_BlendMode.Items.AddObject('Blend_Anti', TObject($00000109));
  Tool_BlendMode.Items.AddObject('Blend_AlphaAdd', TObject($00000104)); //alphaadd
  Tool_BlendMode.Items.AddObject('Blend_AlphaAdd2', TObject($00000101)); //alphaadd2
  Tool_BlendMode.Items.AddObject('Blend_AlphaAdd3', TObject($00000302)); //alphaadd3
  Tool_BlendMode.Items.AddObject('Blend_AlphaAdd4', TObject($7FFFFFF0));
  Tool_BlendMode.Items.AddObject('Blend_ColorAdd', TObject($00000102));
  Tool_BlendMode.Items.AddObject('Blend_Shadow', TObject($00000500));
  Tool_BlendMode.Items.AddObject('Blend_Bright', TObject($00000201));
  Tool_BlendMode.Items.AddObject('Blend_IgnoreColor', TObject($7FFFFFF6));
  Tool_BlendMode.Items.AddObject('Blend_IgnoreColor', TObject($7FFFFFF6));
  Tool_BlendMode.Items.AddObject('Blend_FxAnti', TObject($FF1F1F1F));
  Tool_BlendMode.Items.AddObject('Blend_FxBlend', TObject($80FFFFFF));
  g_CustomIndex := Tool_BlendMode.Items.AddObject('Blend_Custom', TObject($00000001));
  Tool_SrcBlend.ItemIndex := 1;
  Tool_DestBlend.ItemIndex := 0;
  Tool_BlendMode.ItemIndex := 1;
  PanelDraw.Left := 0;
  PanelDraw.Top := 0;
  PanelDraw.Width := MyDevice.Width;
  PanelDraw.Height := MyDevice.Height;
  MyDevice.WindowHandle := PanelDraw.Handle;

  if not MyDevice.Initialize then begin
    ShowMessage('初始化设备失败, error ' + MyDevice.InitError);
    exit;
  end;
end;

procedure TFormMain.FormDestroy(Sender: TObject);
begin
  WriteOpenFileList;
  if g_WMImages <> nil then
    g_WMImages.Free;
  g_WMImages := nil;
end;

procedure TFormMain.InitializeForm;
begin
  MEMU_WORK_AUTOIMAGE.Checked := False;
  Tool_AUTOIMAGE.ImageIndex := 28;
  MEMU_FILE_CLOSE.Enabled := g_WMImages <> nil;
  CloseButton.Enabled := g_WMImages <> nil;

  MEMU_WORK_IMAGE_GOTO.Enabled := g_WMImages <> nil;
  MEMU_WORK_FRONT.Enabled := g_WMImages <> nil;
  MEMU_WORK_NEXT.Enabled := g_WMImages <> nil;

  Tool_Image_Goto.Enabled := g_WMImages <> nil;
  Tool_Front.Enabled := g_WMImages <> nil;
  Tool_Next.Enabled := g_WMImages <> nil;
  Tool_AUTOIMAGE.Enabled := g_WMImages <> nil;
  MEMU_WORK_AUTOIMAGE.Enabled := g_WMImages <> nil;
  MEMU_WORK_ADDIMAGE.Enabled := (g_WMImages <> nil) and (not g_WMImages.ReadOnly);
  MEMU_WORK_DELIMAGE.Enabled := (g_WMImages <> nil) and (not g_WMImages.ReadOnly);
  MEMU_WORK_PUTIMAGE.Enabled := g_WMImages <> nil;
  Tool_Image_Add.Enabled := (g_WMImages <> nil) and (not g_WMImages.ReadOnly);
  Tool_Image_Put.Enabled := g_WMImages <> nil;
  Tool_Image_Del.Enabled := (g_WMImages <> nil) and (not g_WMImages.ReadOnly);
  DrawGrid.RowCount := 1;
  RefStatusBar;
end;

procedure TFormMain.InitializeGrid;
begin
  if g_WMImages <> nil then begin
    DrawGrid.RowCount := g_WMImages.ImageCount div COL_COUNT + 1;
    DrawGrid.Repaint;
  end;
end;

procedure TFormMain.Initializeg_WMImages(WILType: TWILType);
var
  FileName: string;
begin
  OpenDialog.FileName := '';
  if OpenDialog.Execute(Handle) and (OpenDialog.FileName <> '') then begin
    FileName := OpenDialog.FileName;
    OpenButton.Enabled := True;
    if ExtractFileExt(FileName) = '.Lib' then
      OpenWMFile(FileName, t_wmMyImage)
    else
      OpenWMFile(FileName, t_wmM3Def);
    AddOpenFileList(FileName + ' [' + IntToStr(Integer(WILType)) + ']');
  end;
end;

procedure TFormMain.MEMU_FILE_CLOSEClick(Sender: TObject);
begin
  if g_WMImages <> nil then begin
    FreeAndNil(g_WMImages);
    Caption := MAINFORMCAPTION;
  end;
  InitializeForm;
end;

procedure TFormMain.MEMU_FILE_EXITClick(Sender: TObject);
begin
  Close;
end;

procedure TFormMain.MEMU_FILE_OPEN_MIR3Click(Sender: TObject);
begin
  OpenDialog.FileName := '';
  OpenDialog.Filter := 'Wemade Image Library (*.Wil)|*.wil';
  Initializeg_WMImages(t_wmM3Def);
end;

function TFormMain.FormatBitmap(const Bitmap: TBitmap; BColor: TColor; var Data: PChar): Integer;
var
  nBuffLen: Integer;
  Buffer: PChar;
  nY, nX, nAlpha: Integer;
  PDWord: PWord;
  P32RGB: PRGBQuad;
  CheckColor: Integer;
  bitLength: Byte;
begin
  Data := nil;
  Result := 0;
  bitLength := 2;

  nBuffLen := Bitmap.Width * Bitmap.Height * bitLength;
  Buffer := AllocMem(nBuffLen);
  CheckColor := DisplaceRB(BColor) and $FFFFFF;
  try
    Bitmap.PixelFormat := pf32bit;
    for nY := 0 to Bitmap.Height - 1 do
    begin
      P32RGB := PRGBQuad(Bitmap.ScanLine[nY]);
      PDWord := PWord(@Buffer[Bitmap.Width * bitLength * nY]);
      for nX := 0 to Bitmap.Width - 1 do
      begin
        if (PInteger(P32RGB)^ and $FFFFFF) = CheckColor then
        begin
          PDWord^ := 63519;
        end
        else
        begin
          PDWord^ := ((WORD(P32RGB.rgbRed) and $F8) shl 8) + ((WORD(P32RGB.rgbGreen) and $FC) shl 3) + ((WORD(P32RGB.rgbBlue)) shr 3);
        end;
        Inc(P32RGB);
        Inc(PDWord);
      end;
    end;
    Result := ZIPCompress(Buffer, nBuffLen, 9, Data);
    FreeMem(Buffer);
  except
    FreeMem(Buffer);
  end;
end;

procedure TFormMain.MEMU_FILE_WIL_TO_LIBClick(Sender: TObject);
begin
  frmConvertDlg.Open;
end;
{
procedure TFormMain.MEMU_FILE_WIL_TO_LIBClick(Sender: TObject);
const
  MAXBUFFERLEN = 1024 * 1024 * 50;
var
  fhandle: THandle;
  sFileName, sNewFileName: string;
  I, nX, nY, nShadowX, nShadowY, nShadow: Integer;
  WMImageHeader: wmMyImage.TWMImageHeader;
  ImageInfo: wmMyImage.TWMImageInfo;
  WMImages: wmMyImage.TWMMyImageImages;
  Bitmap: TBitmap;
  DataBuffer: PChar;
  DataBufferLen: Integer;
begin
  DataBuffer := nil;
  Bitmap := nil;
  OpenDialog.FileName := '';
  OpenDialog.Filter := 'Wemade Image Library (*.Wil)|*.wil';
  if OpenDialog.Execute(Handle) and (OpenDialog.FileName <> '') then begin
    sFileName := OpenDialog.FileName;
    if FileExists(sFileName) then begin
      if g_OldWMImages <> nil then begin
        g_OldWMImages.Free;
        g_OldWMImages := nil;
      end;

      g_OldWMImages := CreateWMImages(t_wmM3Def);
      if g_OldWMImages <> nil then begin
        g_OldWMImages.FileName := sFileName;
        g_OldWMImages.LibType := ltLoadBmp;
        g_OldWMImages.Initialize;

        sNewFileName := ChangeFileExt(sFileName, '.Lib');
        if FileExists(sNewFileName) then begin
          if MessageBox(Handle, '文件已经存在，是否覆盖原文件？', '提示信息', MB_OKCANCEL + MB_ICONWARNING) = IDCANCEL then
            exit;
          DeleteFile(sNewFileName);
        end;
        fhandle := FileCreate(sNewFileName, fmOpenWrite);
        if fhandle > 0 then begin
          FillChar(WMImageHeader, SizeOf(WMImageHeader), #0);
          WMImageHeader.Title := HEADERNAME;
          WMImageHeader.UpDateTime := Now();
          FileWrite(fhandle, WMImageHeader, SizeOf(WMImageHeader));
          FileClose(fhandle);

          if g_NewWMImages <> nil then begin
            g_NewWMImages.Free;
            g_NewWMImages := nil;
          end;
          g_NewWMImages := CreateWMImages(t_wmMyImage);
          if g_NewWMImages <> nil then begin
            g_NewWMImages.FileName := sNewFileName;
            g_NewWMImages.LibType := ltLoadBmp;
            g_NewWMImages.Initialize;
            WMImages := TWMMyImageImages(g_NewWMImages);
            if g_OldWMImages.ImageCount > 0 then
            begin
              DataBuffer := nil;
              Bitmap := nil;
              try
                for I := 0 to g_OldWMImages.ImageCount - 1 do
                begin
                  nX := 0;
                  nY := 0;
                  nShadowX := 0;
                  nShadowY := 0;
                  nShadow := 0;

                  if DataBuffer <> nil then begin
                    FreeMem(DataBuffer);
                  end;
                  if Bitmap <> nil then begin
                    Bitmap.Free;
                  end;
                  DataBuffer := nil;
                  Bitmap := nil;
                  DataBufferLen := 0;

//                  Bitmap := TBitmap.Create;
//                  Bitmap.PixelFormat := pf16bit;
                  try
                    BitMap := g_OldWMImages.Bitmap[I];
                  except
                    Bitmap := nil;
                  end;
                  if Bitmap <> nil then begin
                    nX := g_OldWMImages.LastImageInfo.px;
                    nY := g_OldWMImages.LastImageInfo.py;
                    nShadowX := g_OldWMImages.LastImageInfo.shShadowPX;
                    nShadowY := g_OldWMImages.LastImageInfo.shShadowPY;
                    nShadow := g_OldWMImages.LastImageInfo.bShadow;
                  end;

                  if Bitmap = nil then begin
                    g_NewWMImages.AddIndex(-1, 0);
                    Continue;
                  end
                  else begin
//                    将图型数据转换为存储数据
                    DataBufferLen := FormatBitmap(Bitmap, g_OutBackColor, DataBuffer);
                    FillChar(ImageInfo, SizeOf(ImageInfo), #0);
                    ImageInfo.DXInfo.px := nX;
                    ImageInfo.DXInfo.py := nY;
                    ImageInfo.DXInfo.shShadowPX := nShadowX;
                    ImageInfo.DXInfo.shShadowPY := nShadowY;
                    ImageInfo.DXInfo.bShadow := nShadow;
                    ImageInfo.DXInfo.nWidth := Bitmap.Width;
                    ImageInfo.DXInfo.nHeight := Bitmap.Height;
                    ImageInfo.nDataSize := DataBufferLen;
                    ImageInfo.btImageFormat := WILFMT_R5G6B5;
                  end;
                  if Bitmap <> nil then begin
                    Bitmap.Free;
                    Bitmap := nil;
                  end;

                  if (DataBufferLen > 0) and (DataBuffer <> nil) then begin
                    if DataBufferLen + SizeOf(ImageInfo) > MAXBUFFERLEN then begin
                      Application.MessageBox(PChar(Format('第%d号图像',[I]) + #13#10 +
                        '内存溢出，数据大小(' + IntToStr(DataBufferLen) + ')'), '提示信息', MB_OK + MB_ICONSTOP);
                      break;
                    end;
                    WMImages.AddDataToFile(@ImageInfo, DataBuffer, DataBufferLen);
                  end else begin
                    g_NewWMImages.AddIndex(-1, 0);
                  end;
                  if DataBuffer <> nil then begin
                    FreeMem(DataBuffer);
                    DataBuffer := nil;
                  end;
                  Caption := MAINFORMCAPTION + ' [' + sFileName + '] ' + Format('数据转换(%d/%d)', [I + 1, g_OldWMImages.ImageCount]);
                  Application.ProcessMessages;
                end;
                WMImages.SaveIndexList;
              finally
                if Bitmap <> nil then
                  Bitmap.Free;
                if DataBuffer <> nil then begin
                  FreeMem(DataBuffer);
                end;
              end;
            end;
          end;
        end;
      end;
    end;
  end;
  if g_NewWMImages <> nil then begin
    FreeAndNil(g_NewWMImages);
  end;
  if g_OldWMImages <> nil then begin
    FreeAndNil(g_OldWMImages);
    Caption := MAINFORMCAPTION;
  end;
end;}

procedure TFormMain.MEMU_WORK_ADDIMAGEClick(Sender: TObject);
begin
  if (g_WMImages <> nil) and (g_WMImages.boInitialize) then begin
    FormAdd.Open;
  end;
end;

procedure TFormMain.MEMU_WORK_AUTOIMAGEClick(Sender: TObject);
begin
  MEMU_WORK_AUTOIMAGE.Checked := not MEMU_WORK_AUTOIMAGE.Checked;
  FAutoTick := GetTickCount;
  Tool_AUTOIMAGE.ImageIndex := 28 + Integer(MEMU_WORK_AUTOIMAGE.Checked);
end;

procedure TFormMain.MEMU_WORK_DELIMAGEClick(Sender: TObject);
begin
  if (g_WMImages <> nil) and (g_WMImages.boInitialize) then begin
    FormDel.Open;
  end;
end;

procedure TFormMain.MEMU_WORK_PUTIMAGEClick(Sender: TObject);
begin
  if (g_WMImages <> nil) and (g_WMImages.boInitialize) then begin
    FormOut.Open;
  end;
end;

procedure TFormMain.MENU_OPTION_BACKIMAGEClick(Sender: TObject);
var
  Picture: TPicture;
  Access: TDXAccessInfo;
  Y, nWidth, nHeight: Integer;
  WriteBuffer, ReadBuffer: PChar;
  Bitmap: TBitmap;
  boFree: Boolean;
begin
  if OpenPictureDialog.Execute(Handle) then begin
    Picture := TPicture.Create;
    try
      Picture.LoadFromFile(OpenPictureDialog.FileName);
      boFree := False;
      if not (Picture.Graphic is TBitmap) then begin
        Bitmap := TBitmap.Create;
        Bitmap.Assign(Picture.Graphic);
        boFree := True;
      end
      else
        Bitmap := TBitmap(Picture.Graphic);
      Bitmap.PixelFormat := pf32bit;
      g_Texture[0].PatternSize := Point(1, 1);
      nWidth := _MIN(Bitmap.Width, g_Texture[0].Size.X);
      nHeight := _MIN(Bitmap.Height, g_Texture[0].Size.Y);
      if g_Texture[0].Lock(lfWriteOnly, Access) then begin
        try
          for Y := 0 to nHeight - 1 do begin
            ReadBuffer := Bitmap.ScanLine[Y];
            WriteBuffer := Pointer(Integer(Access.Bits) + (Access.Pitch * Y));
            Move(ReadBuffer^, WriteBuffer^, nWidth * 4);
          end;
          g_Texture[0].PatternSize := Point(nWidth, nHeight);
        finally
          g_Texture[0].Unlock;
        end;
      end;
      if boFree then
        Bitmap.Free;
    finally
      Picture.Free;
    end;
  end;
end;

procedure TFormMain.MENU_OPTION_BLENDCOLORClick(Sender: TObject);
begin
  if Sender = MENU_OPTION_BLENDCOLOR then begin
    SendMessage(Tool_BlendColor.Handle, BM_CLICK, 0, 0);
  end
  else begin
    SendMessage(Tool_BackColor.Handle, BM_CLICK, 0, 0);
  end;
end;

procedure TFormMain.MENU_OPTION_LEVELClick(Sender: TObject);
begin
  MENU_OPTION_LEVEL.Checked := not MENU_OPTION_LEVEL.Checked;
end;

procedure TFormMain.MENU_OPTION_UPRIGHTNESSClick(Sender: TObject);
begin
  MENU_OPTION_UPRIGHTNESS.Checked := not MENU_OPTION_UPRIGHTNESS.Checked;
end;

procedure TFormMain.MENU_VIER_STATUSBARClick(Sender: TObject);
begin
  MENU_VIER_STATUSBAR.Checked := not MENU_VIER_STATUSBAR.Checked;
  StatusBar.Visible := MENU_VIER_STATUSBAR.Checked;
end;

procedure TFormMain.MENU_VIER_TOOLBARClick(Sender: TObject);
begin
  MENU_VIER_TOOLBAR.Checked := not MENU_VIER_TOOLBAR.Checked;
  StandardToolBar.Visible := MENU_VIER_TOOLBAR.Checked;
end;

procedure TFormMain.MyDeviceFinalize(Sender: TObject);
begin
  Timer.Enabled := False;
  g_Texture[0].Free;
  g_Texture[0] := nil;
  g_Texture[1].Free;
  g_Texture[1] := nil;
  FRenderSurface.Free;
  FRenderSurface := nil;
end;

procedure TFormMain.MyDeviceInitialize(Sender: TObject; var Success: Boolean; var ErrorMsg: string);
begin
  Timer.Enabled := True;
  g_Texture[0] := TDXImageTexture.Create;
  with g_Texture[0] do begin
    Size := Point(1024, 1024);
    PatternSize := Point(1, 1);
    Format := D3DFMT_A8R8G8B8;
    Active := True;
  end;
  g_Texture[1] := TDXImageTexture.Create;
  with g_Texture[1] do begin
    Size := Point(1024, 1024);
    PatternSize := Point(1, 1);
    //Format := D3DFMT_R5G6B5;
    //Active := True;
  end;
  FRenderSurface := TDXRenderTargetTexture.Create(nil);
  FRenderSurface.Size := Point(PresentParams.BackBufferWidth, PresentParams.BackBufferHeight);
  FRenderSurface.Format := D3DFMT_A4R4G4B4;
  FRenderSurface.MipMapping := False;
  FRenderSurface.Behavior := tbRTarget;
  FRenderSurface.Active := True;
end;

procedure TFormMain.MyDeviceNotifyEvent(Sender: TObject; Msg: Cardinal);
begin
  case Msg of
    msgDeviceLost: begin
      FRenderSurface.Lost;
    end;
    msgDeviceRecovered: begin
      FRenderSurface.Recovered;
    end;
  end;
end;

procedure TFormMain.MyDeviceRender(Sender: TObject);
begin
  MyDevice.Canvas.Draw(0, 0, FRenderSurface.ClientRect, FRenderSurface, fxBlend, clWhite4);
end;

procedure TFormMain.MEMU_FILE_AGOFILE_PATHSClick(Sender: TObject);
var
  sFileName, sType: string;
begin
  with Sender as TMenuitem do begin
    if Hint <> '' then begin
      sType := GetValidStr3(Hint, sFileName, [' ']);
      ArrestStringEx(sType, '[', ']', sType);
      if (sFileName <> '') and (sType <> '') then begin
        OpenWMFile(sFileName, TWILType(StrToIntDef(sType, 0)));
      end;
    end;
  end;
end;

procedure TFormMain.OpenButtonClick(Sender: TObject);
begin
  OpenDialog.Filter := 'Mir3 Library File (*.Lib)|*' + MYFILEEXT + '|Wemade Image Library (*.Wil)|*.wil';
  Initializeg_WMImages(g_WILType);
end;

procedure TFormMain.OpenWMFile(sFileName: string; WILType: TWILType);
begin
  if FileExists(sFileName) then begin
    OpenButton.Enabled := True;
    g_WILType := WILType;
    Caption := MAINFORMCAPTION + ' [' + sFileName + ']';
    if g_WMImages <> nil then begin
      g_WMImages.Free;
      g_WMImages := nil;
    end;
    g_SelectImageIndex := -1;
    g_WMImages := CreateWMImages(WILType);
    if g_WMImages <> nil then begin
      g_WMImages.FileName := sFileName;
      g_WMImages.LibType := ltLoadBmp;
      //g_WMImages.Password := '5d54273c';
      //g_WMImages.ChangeAlpha := True;
      g_WMImages.Initialize;
      DrawGrid.RowCount := g_WMImages.ImageCount div COL_COUNT + 1;
      DrawGrid.Repaint;
      if (WILType = t_wmMyImage) and (g_WMImages <> nil) and (g_WMImages.boInitialize) then
        Caption := MAINFORMCAPTION + ' [' + sFileName + '] ' + DateTimeToStr(TWMMyImageImages(g_WMImages).UpDateTime);
    end;
    InitializeForm;
    InitializeGrid;
  end;
end;

procedure TFormMain.PanelDrawMouseDown(Sender: TObject; Button: TMouseButton; Shift: TShiftState; X, Y: Integer);
begin
  FSpotX := X;
  FSpotY := Y;
  FDown := Tool_Random.Down;
end;

procedure TFormMain.PanelDrawMouseMove(Sender: TObject; Shift: TShiftState; X, Y: Integer);
var
  al, at: integer;
begin
  if not FDown then exit;
  with PanelDraw do begin
    if (FSpotX <> X) or (FSpotY <> Y) then begin
      al := FShowX + (X - FSpotX);
      at := FShowY + (Y - FSpotY);
      if al + Width < WINLEFT then
        al := WINLEFT - Width;
      if al > WINRIGHT then
        al := WINRIGHT;
      if at + Height < WINTOP then
        at := WINTOP - Height;
      if at > BOTTOMEDGE then
        at := BOTTOMEDGE;
      FShowX := al;
      FShowY := at;
      FSpotX := X;
      FSpotY := Y;
      RefStatusBar();
    end;
  end;
end;

procedure TFormMain.PanelDrawMouseUp(Sender: TObject; Button: TMouseButton; Shift: TShiftState; X, Y: Integer);
begin
  FDown := False;
end;

procedure TFormMain.MEMU_FILE_OPEN_DIYClick(Sender: TObject);
begin
  OpenDialog.FileName := '';
  OpenDialog.Filter := 'Mir3 Library File (*.Lib)|*' + MYFILEEXT;
  Initializeg_WMImages(t_wmMyImage);
end;

procedure TFormMain.RefStatusBar;
begin
  if g_WMImages <> nil then begin
    StatusBar.Panels[0].Text := Format('编号: %d/%d', [g_SelectImageIndex, g_WMImages.ImageCount - 1]);
    StatusBar.Panels[1].Text := '格式: 未知';

    if g_WMImages is TWMM3DefImages then begin
      if TWMM3DefImages(g_WMImages).NewFmt then
        StatusBar.Panels[1].Text := '格式: MIR3标准数据格式(新)'
      else
        StatusBar.Panels[1].Text := '格式: MIR3标准数据格式(旧)';
    end
    else if g_WMImages is TWMMyImageImages then begin
      StatusBar.Panels[1].Text := '格式: 专用图像文件模式'
    end;
  end
  else begin
    StatusBar.Panels[0].Text := '编号: 0/0';
    StatusBar.Panels[1].Text := '格式: 未知';
  end;
  StatusBar.Panels[2].Text := Format('规格: %d * %d', [g_TextureInfo.nWidth, g_TextureInfo.nHeight]);
  StatusBar.Panels[3].Text := Format('坐标X: %d', [g_TextureInfo.px]);
  StatusBar.Panels[4].Text := Format('坐标Y: %d', [g_TextureInfo.py]);
  case g_WILColorFormat of
    -1: StatusBar.Panels[5].Text := '格式: 默认';
    0: StatusBar.Panels[5].Text := '格式: A4R4G4B4';
    1: StatusBar.Panels[5].Text := '格式: A1R5G5B5';
    2: StatusBar.Panels[5].Text := '格式: R5G6B5';
    3: StatusBar.Panels[5].Text := '格式: A8R8G8B8';
    else StatusBar.Panels[5].Text := '格式: 未知';
  end;
  StatusBar.Panels[6].Text := Format('透明度: %d', [Tool_Alpha.Position]);
  StatusBar.Panels[7].Text := Format('影子: %d', [g_TextureInfo.bShadow]);
  StatusBar.Panels[8].Text := Format('影子偏移X: %d', [g_TextureInfo.shShadowPX]);
  StatusBar.Panels[9].Text := Format('影子偏移Y: %d', [g_TextureInfo.shShadowPY]);
  StatusBar.Panels[10].Text := Format('测试: (%d,%d)', [FShowX, FShowY]);
end;

procedure TFormMain.SaveRenderToBmp(sFileName: string);
var
  PrevTarget, Offscreen: IDirect3DSurface9;
  DRect: TRect;
  BItmap: TBitmap;
  LockedRect: TD3DLockedRect;
  y: Integer;
  WriteBuffer, ReadBuffer: PChar;
begin
  PrevTarget := nil;
  Offscreen := nil;
  Try
    if not Succeeded(Direct3DDevice.CreateOffscreenPlainSurface(FRenderSurface.Width,
      FRenderSurface.Height, FRenderSurface.Format, D3DPOOL_SYSTEMMEM, PrevTarget, nil)) then Exit;

    DRect := Rect(0, 0, FRenderSurface.Width, FRenderSurface.Height);

    if not Succeeded(FRenderSurface.Texture9.GetSurfaceLevel(0, Offscreen)) then Exit;
    if not Succeeded(Direct3DDevice.GetRenderTargetData(Offscreen, PrevTarget)) then Exit;
    if Succeeded(PrevTarget.LockRect(LockedRect, nil, D3DLOCK_READONLY)) then begin
      Bitmap := TBitmap.Create;
      Try
        Bitmap.PixelFormat := pf32bit;
        Bitmap.Width := FRight;
        Bitmap.Height := FBottom;
        for Y := 0 to Bitmap.Height - 1 do begin
          ReadBuffer := PChar(Integer(LockedRect.pBits) + LockedRect.Pitch * Y);
          WriteBuffer := Bitmap.ScanLine[Y];
          Move(ReadBuffer^, WriteBuffer^, Bitmap.Width * 4);
        end;
        Bitmap.SaveToFile(sFileName);
      Finally
        Bitmap.Free;
        PrevTarget.UnlockRect;
      End;
    end;
  Finally
    PrevTarget := nil;
    Offscreen := nil;
  End;

end;

function TFormMain.SetDrawGridIndex(Index: Integer): Boolean;
begin
  Result := False;
  if (g_WMImages <> nil) and g_WMImages.boInitialize then begin
    if (Index >= 0) and (Index <= (g_WMImages.ImageCount - 1)) then begin
      DrawGrid.Row := Index div COL_COUNT;
      DrawGrid.Col := Index mod COL_COUNT;
      Result := True;
    end;
  end;
end;

procedure TFormMain.TimerTimer(Sender: TObject);
const
  boRun: Boolean = False;
  WriteIndex: Byte = 0;
begin
  if boRun then
    exit;
  boRun := True;
  if MEMU_WORK_AUTOIMAGE.Checked and (GetTickCount > FAutoTick) then begin
    FAutoTick := GetTickCount + 200;
    if not SetDrawGridIndex(DrawGrid.Row * COL_COUNT + DrawGrid.Col + 1) then begin
      MEMU_WORK_AUTOIMAGE.Checked := False;
      Tool_AUTOIMAGE.ImageIndex := 28;
    end;
  end;
  try
    MyDevice.RenderOn(FRenderSurface, DrawRender, g_BackColor, True);
    if (FSaveDir <> '') and (FLastIndex <> g_SelectImageIndex) then begin
      FLastIndex := g_SelectImageIndex;
      SaveRenderToBmp(FSaveDir + Format('%.6d.bmp', [g_SelectImageIndex]));
    end;
    MyDevice.Render(g_BackColor, True);
    MyDevice.Flip;

  finally
    boRun := False;
  end;
end;

procedure TFormMain.Tool_AlignLineColorClick(Sender: TObject);
begin
  g_AlignLineColor := Tool_AlignLineColor.SymbolColor;
end;

procedure TFormMain.Tool_AlphaChange(Sender: TObject);
begin
  RefStatusBar;
end;

procedure TFormMain.Tool_BackColorClick(Sender: TObject);
begin
  g_BackColor := Tool_BackColor.SymbolColor;
  PanelDraw.Color := g_BackColor;
  ScrollBox.Color := g_BackColor;
  RefStatusBar;
end;

procedure TFormMain.Tool_BlendColorClick(Sender: TObject);
begin
  g_AlphaColor := Tool_BlendColor.SymbolColor;
  RefStatusBar;
end;

procedure TFormMain.Tool_BlendModeChange(Sender: TObject);
begin
  if (Tool_BlendMode.ItemIndex <> -1) and (Tool_BlendMode.ItemIndex < Tool_BlendMode.Items.Count) then
    FBlend := Cardinal(Tool_BlendMode.Items.Objects[Tool_BlendMode.ItemIndex]);
  Tool_SrcBlend.Enabled := g_CustomIndex = Tool_BlendMode.ItemIndex;
  Tool_DestBlend.Enabled := g_CustomIndex = Tool_BlendMode.ItemIndex;
  if Tool_SrcBlend.Enabled then
    Tool_DestBlendChange(Tool_DestBlend);
end;

procedure TFormMain.Tool_Image_GotoClick(Sender: TObject);
begin
  if (g_WMImages <> nil) and g_WMImages.boInitialize then begin
    SetDrawGridIndex(StrToIntDef(InputBox('跳转', '请输入图片索引号', IntToStr(g_SelectImageIndex)), 1));
  end;
end;

procedure TFormMain.Tool_NewClick(Sender: TObject);
var
  fhandle: THandle;
  sFileName: string;
  WMImageHeader: wmMyImage.TWMImageHeader;
begin
  SaveDialog.FileName := '';
  SaveDialog.Filter := 'Mir3 Library File(*' + MYFILEEXT + ')|*' + MYFILEEXT;
  if SaveDialog.Execute(Handle) and (SaveDialog.FileName <> '') then begin
    sFileName := SaveDialog.FileName;
    if CompareText(RightStr(sFileName, 4), MYFILEEXT) <> 0 then
      sFileName := sFileName + MYFILEEXT;

    if FileExists(sFileName) then begin
      if MessageBox(Handle, '文件已经存在，是否覆盖原文件？', '提示信息', MB_OKCANCEL + MB_ICONWARNING) = IDCANCEL then
        exit;
      DeleteFile(sFileName);
    end;
    fhandle := FileCreate(sFileName, fmOpenWrite);
    if fhandle > 0 then begin
      FillChar(WMImageHeader, SizeOf(WMImageHeader), #0);
      WMImageHeader.Title := HEADERNAME;
      WMImageHeader.UpDateTime := Now();
      FileWrite(fhandle, WMImageHeader, SizeOf(WMImageHeader));
      FileClose(fhandle);
      if MessageBox(Handle, '是否打开新创建的文件？', '提示信息', MB_YESNO + MB_ICONQUESTION) = IDYES then
        OpenWMFile(sFileName, t_wmMyImage);
    end;
  end;
end;

procedure TFormMain.Tool_NextClick(Sender: TObject);
begin
  if (g_WMImages <> nil) and g_WMImages.boInitialize then begin
    if (Sender = Tool_Next) or (Sender = MEMU_WORK_NEXT) then
      SetDrawGridIndex(DrawGrid.Row * COL_COUNT + DrawGrid.Col + 1)
    else
      SetDrawGridIndex(DrawGrid.Row * COL_COUNT + DrawGrid.Col - 1);
  end;
end;

procedure TFormMain.Tool_OffsetLineColorClick(Sender: TObject);
begin
  g_OffsetLineColor := Tool_OffsetLineColor.SymbolColor;
end;

procedure TFormMain.Tool_OutBackColorClick(Sender: TObject);
begin
  g_OutBackColor := Tool_OutBackColor.SymbolColor;
  FormMain.DrawGrid.Repaint;
end;

procedure TFormMain.Tool_ZoomChange(Sender: TObject);
var
  sInput: string;
  nInput: Integer;
begin
  case Tool_Zoom.ItemIndex of
    0: FZoomSize := 0.5;
    1: FZoomSize := 1;
    2: FZoomSize := 2;
    3: FZoomSize := 4;
    4: FZoomSize := 8;
    5: begin
      if not InputQuery('设置缩放比例', '例如：10 代表 10%', sInput) then
        Exit;
      nInput := StrToIntDef(sInput, 100);
      FZoomSize := nInput / 100;
    end;
  end;
end;

const
  REGPATH = 'SOFTWARE\Jason\RPGViewer\Path';

procedure TFormMain.AddOpenFileList(sFileName: string);
var
  Item: TMenuItem;
  i: Integer;
begin
  if sFileName = '' then exit;
  Item := TMenuItem.Create(MEMU_FILE_AGOFILE);
  Item.Caption := '&0 ' + sFileName;
  Item.Hint := sFileName;
  item.OnClick := MEMU_FILE_AGOFILE_PATHSClick;
  MEMU_FILE_AGOFILE.Insert(0, Item);
  for I := MEMU_FILE_AGOFILE.Count - 1 downto 1 do begin
    item := MEMU_FILE_AGOFILE.Items[I];
    if (item.Hint = '') or (item.Hint = sFileName) then begin
      MEMU_FILE_AGOFILE.Delete(I);
      item.Free;
    end else begin
      Item.Caption := '&' + IntToStr(I) + ' ' + item.Hint;
    end;
  end;
  if MEMU_FILE_AGOFILE.Count > 10 then
    MEMU_FILE_AGOFILE.Delete(10);
end;

procedure TFormMain.ReadOpenFileList;
var
  Reg: TRegistry;
  I: Integer;
  sFileName: string;
  Item: TMenuItem;
begin
  Reg := TRegistry.Create;
  Try
    Reg.RootKey := HKEY_LOCAL_MACHINE;
    if Reg.OpenKey(REGPATH, False) then begin
      for I := 0 to 9 do begin
        sFileName := Trim(Reg.ReadString(IntToStr(I)));
        if sFileName <> '' then begin
          if I = 0 then begin
            item := MEMU_FILE_AGOFILE.Items[0];
            item.Enabled := True;
            Item.Caption := '&' + IntToStr(I) + ' ' + sFileName;
            Item.Hint := sFileName;
            item.OnClick := MEMU_FILE_AGOFILE_PATHSClick;
          end else begin
            Item := TMenuItem.Create(MEMU_FILE_AGOFILE);
            Item.Caption := '&' + IntToStr(I) + ' ' + sFileName;
            Item.Hint := sFileName;
            item.OnClick := MEMU_FILE_AGOFILE_PATHSClick;
            MEMU_FILE_AGOFILE.Add(Item);
          end;
        end else break;
      end;
    end;
    Reg.CloseKey;
  Finally
    Reg.Free;
  End;
end;

procedure TFormMain.WriteOpenFileList;
var
  Reg: TRegistry;
  I: Integer;
begin
  Reg := TRegistry.Create;
  Try
    Reg.RootKey := HKEY_LOCAL_MACHINE;
    if Reg.OpenKey(REGPATH, True) then begin
      for I := 0 to MEMU_FILE_AGOFILE.Count - 1 do begin
        Reg.WriteString(IntToStr(I), MEMU_FILE_AGOFILE.Items[I].Hint);
      end;
    end;
    Reg.CloseKey;
  Finally
    Reg.Free;
  End;
end;

end.

