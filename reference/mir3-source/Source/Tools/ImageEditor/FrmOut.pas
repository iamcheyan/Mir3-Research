unit FrmOut;

interface

uses
  Windows, Messages, SysUtils, StrUtils, Variants, Classes, Graphics, Controls,
  Forms, TDX9Textures, MyD3DX9, Dialogs, StdCtrls, Spin, ComCtrls, ImageHlp, MyDirect3D9,
  ExtCtrls;

type
  TFormOut = class(TForm)
    GroupBox1: TGroupBox;
    Label2: TLabel;
    Label3: TLabel;
    edtIndexStart: TSpinEdit;
    edtIndexEnd: TSpinEdit;
    GroupBox2: TGroupBox;
    edtSaveDir: TEdit;
    Button1: TButton;
    Label1: TLabel;
    GroupBox3: TGroupBox;
    Out_Offset: TCheckBox;
    btnGo: TButton;
    btnExit: TButton;
    ProgressBar: TProgressBar;
    Out_Format: TCheckBox;
    RadioGroupImageFormat: TRadioGroup;
    Out_Alpha: TCheckBox;
    Out_Clear: TCheckBox;
    procedure Button1Click(Sender: TObject);
    procedure btnGoClick(Sender: TObject);
    procedure Out_OffsetClick(Sender: TObject);
    procedure SaveTextureToFile(Texture: TDXImageTexture; SaveDir: string; Index:
      Integer);
  private
    { Private declarations }
  public
    procedure Open();
  end;

var
  FormOut: TFormOut;

implementation

{$R *.dfm}

uses
  ZShare, FrmMain, WIL, wmMyImage, HUtil32;

{ TFormOut }

procedure DeleteDirectory(const Name: string);
var
  F: TSearchRec;
begin
  if FindFirst(Name + '\*', faAnyFile, F) = 0 then begin
    try
      repeat
        if (F.Attr and faDirectory <> 0) then begin
          if (F.Name <> '.') and (F.Name <> '..') then begin
            DeleteDirectory(Name + '\' + F.Name);
          end;
        end else begin
          DeleteFile(Name + '\' + F.Name);
        end;
      until FindNext(F) <> 0;
    finally
      FindClose(F);
    end;
    RemoveDir(Name);
  end;
end;

procedure TFormOut.btnGoClick(Sender: TObject);
var
  StartInt, EndInt, I: Integer;
  m_SaveDir: string;
  m_SaveXYDir: string;
  StringList: TStringList;
  Bitmap, EmptyBitmap: TBitmap;
  Y, nX, nY, nS, nSX, nSY: Integer;
  MemoryStream: TMemoryStream;
  FileName: string;
  Access: TDXAccessInfo;
  WriteBuffer, ReadBuffer: PChar;
begin
  if (g_WMImages = nil) or (not g_WMImages.boInitialize) then
    exit;
  edtSaveDir.Enabled := False;
  Button1.Enabled := False;
  edtIndexStart.Enabled := False;
  edtIndexEnd.Enabled := False;
  Out_Alpha.Enabled := False;
  Out_Offset.Enabled := False;
  Out_Format.Enabled := False;
  btnGo.Enabled := False;
  btnExit.Enabled := False;
  ProgressBar.Position := 0;
  try
    StartInt := StrToIntDef(edtIndexStart.Text, -1);
    EndInt := StrToIntDef(edtIndexEnd.Text, -1);

    m_SaveDir := Trim(edtSaveDir.Text);
    if Out_Clear.Checked then DeleteDirectory(m_SaveDir);
    if RightStr(m_SaveDir, 1) <> '\' then
      m_SaveDir := m_SaveDir + '\';
    m_SaveXYDir := m_SaveDir + IMAGEOFFSETDIR;

    if (StartInt < 0) then begin
      Application.MessageBox('数据起始编号设置错误', '提示信息', MB_OK or MB_ICONASTERISK);
      exit;
    end;
    if (EndInt < 0) then begin
      Application.MessageBox('数据结束编号设置错误', '提示信息', MB_OK or MB_ICONASTERISK);
      exit;
    end;
    if (EndInt >= g_WMImages.ImageCount) then begin
      Application.MessageBox('数据结束编号设置错误，不能大于总数据数量', '提示信息', MB_OK or MB_ICONASTERISK);
      exit;
    end;
    if (StartInt > EndInt) then begin
      Application.MessageBox('数据起始编号设置错误，不能大于结号编号', '提示信息', MB_OK or MB_ICONASTERISK);
      exit;
    end;
    if Out_Offset.Checked then
      MakeSureDirectoryPathExists(PChar(m_SaveXYDir))
    else
      MakeSureDirectoryPathExists(PChar(m_SaveDir));
    StringList := TStringList.Create;
    EmptyBitmap := TBitmap.Create;
    EmptyBitmap.Width := 1;
    EmptyBitmap.Height := 1;
    EmptyBitmap.PixelFormat := pf32bit;
    Bitmap := nil;
    for I := StartInt to EndInt do begin
      nX := 0;
      nY := 0;
      nSX := 0;
      nSY := 0;
      nS := 0;

     { if Out_Alpha.Checked then begin
        if g_WMImages.CopyDataToTexture(I, g_Texture[1]) then begin
          nX := g_WMImages.LastImageInfo.px;
          nY := g_WMImages.LastImageInfo.py;
          nSX := g_WMImages.LastImageInfo.shShadowPX;
          nSY := g_WMImages.LastImageInfo.shShadowPY;
          nS := g_WMImages.LastImageInfo.bShadow;
          Bitmap := TBitmap.Create;
          Bitmap.PixelFormat := pf32bit;
          Bitmap.Width := g_Texture[1].Width;
          Bitmap.Height := g_Texture[1].Height;
          if g_Texture[1].Lock(lfReadOnly, Access) then begin
            try
              for Y := 0 to Bitmap.Height - 1 do begin
                ReadBuffer := Pointer(Integer(Access.Bits) + (Access.Pitch * Y));
                WriteBuffer := Bitmap.ScanLine[y];
                Move(ReadBuffer^, WriteBuffer^, Bitmap.Width * 4);
              end;
            finally
              g_Texture[1].Unlock;
            end;
          end;
        end;
      end else begin
        Bitmap := TBitmap.Create;
        Bitmap.PixelFormat := pf16bit;
        BitMap := g_WMImages.Bitmap[I];
        if Bitmap <> nil then begin
          nX := g_WMImages.LastImageInfo.px;
          nY := g_WMImages.LastImageInfo.py;
          nSX := g_WMImages.LastImageInfo.shShadowPX;
          nSY := g_WMImages.LastImageInfo.shShadowPY;
          nS := g_WMImages.LastImageInfo.bShadow;
//          if Bitmap.PixelFormat = pf8bit then
//            SetDIBColorTable(Bitmap.Canvas.Handle, 0, 256, g_DefMainPalette);
        end;
      end;
      if Bitmap <> nil then Bitmap.SaveToFile(Format('%s%.8d.bmp', [m_SaveDir, I]))
      else EmptyBitmap.SaveToFile(Format('%s%.8d.bmp', [m_SaveDir, I]));    }

      if Out_Alpha.Checked then begin
        if g_WMImages.CopyDataToTexture(I, g_Texture[1]) then begin
          nX := g_WMImages.LastImageInfo.px;
          nY := g_WMImages.LastImageInfo.py;
          nSX := g_WMImages.LastImageInfo.shShadowPX;
          nSY := g_WMImages.LastImageInfo.shShadowPY;
          nS := g_WMImages.LastImageInfo.bShadow;
          SaveTextureToFile(g_Texture[1], m_SaveDir, I);
          g_Texture[1].Unlock;
        end
        else begin
          g_Texture[1].Active := False;
          g_Texture[1].Format := D3DFMT_A8R8G8B8;
          g_Texture[1].Size := Point(EmptyBitmap.Width, EmptyBitmap.Height);
          g_Texture[1].PatternSize := Point(EmptyBitmap.Width, EmptyBitmap.Height);
          g_Texture[1].Active := True;

          SafeFillChar(Access.Bits^, Access.Pitch * g_Texture[1].Size.Y, #0);
          SaveTextureToFile(g_Texture[1], m_SaveDir, I);
          g_Texture[1].Unlock;
//          if g_Texture[1].Lock(lfReadOnly, Access) then begin
//            try
//              for Y := 0 to EmptyBitmap.Height - 1 do begin
//                ReadBuffer := EmptyBitmap.ScanLine[Y];
//                WriteBuffer := Pointer(Integer(Access.Bits) + (Access.Pitch * Y));
//                Move(ReadBuffer^, WriteBuffer^, EmptyBitmap.Width * 4);
//              end;
//              SaveTextureToFile(g_Texture[1], m_SaveDir, I);
//            finally
//              g_Texture[1].Unlock;
//            end;
//          end;
        end;
      end else begin
        Bitmap := TBitmap.Create;
        Bitmap.PixelFormat := pf16bit;
        BitMap := g_WMImages.Bitmap[I];
        if Bitmap <> nil then begin
          nX := g_WMImages.LastImageInfo.px;
          nY := g_WMImages.LastImageInfo.py;
          nSX := g_WMImages.LastImageInfo.shShadowPX;
          nSY := g_WMImages.LastImageInfo.shShadowPY;
          nS := g_WMImages.LastImageInfo.bShadow;
//          if Bitmap.PixelFormat = pf8bit then
//            SetDIBColorTable(Bitmap.Canvas.Handle, 0, 256, g_DefMainPalette);
        end;
        if Bitmap <> nil then Bitmap.SaveToFile(Format('%s%.8d.bmp', [m_SaveDir, I]))
        else EmptyBitmap.SaveToFile(Format('%s%.8d.bmp', [m_SaveDir, I]));
      end;

      if Out_Offset.Checked then begin
        StringList.Clear;
        StringList.Add(IntToStr(nX));
        StringList.Add(IntToStr(nY));
        StringList.Add(IntToStr(nSX));
        StringList.Add(IntToStr(nSY));
        StringList.Add(IntToStr(nS));
        if Out_Format.Checked and (g_WMImages is TWMMyImageImages) then begin
          StringList.Add(IntToStr(Integer(g_WMImages.LastColorFormat)));
        end;
        StringList.SaveToFile(Format('%s%.8d.txt', [m_SaveXYDir, I]));
      end;

      if (EndInt - StartInt) > 0 then
        ProgressBar.Position := _MAX(0, Trunc(I / (EndInt - StartInt) * 100))
      else
        ProgressBar.Position := 100;
    end;
    StringList.Free;
    Application.MessageBox('导出数据完成', '提示信息', MB_OK or MB_ICONASTERISK);
    Close
  finally
    edtSaveDir.Enabled := True;
    Button1.Enabled := True;
    edtIndexStart.Enabled := True;
    edtIndexEnd.Enabled := True;
    Out_Alpha.Enabled := True;
    Out_Offset.Enabled := True;
    Out_Format.Enabled := True;
    btnGo.Enabled := True;
    btnExit.Enabled := True;
  end;
end;

procedure TFormOut.Button1Click(Sender: TObject);
var
  sStr: string;
begin
  sStr := BrowseForFolder(Handle, '请选择保存文件夹');
  if sStr <> '' then begin
    edtSaveDir.Text := sStr;
  end;
end;

procedure TFormOut.Open;
begin
  edtIndexStart.MaxValue := g_WMImages.ImageCount - 1;
  edtIndexEnd.MaxValue := g_WMImages.ImageCount - 1;
  if g_SelectImageIndex <> -1 then begin
    edtIndexStart.Value := g_SelectImageIndex;
    edtIndexEnd.Value := g_SelectImageIndex;
  end else begin
    edtIndexStart.Value := 0;
    edtIndexEnd.Value := g_WMImages.ImageCount - 1;
  end;
  ProgressBar.Position := 0;
  RadioGroupImageFormat.ItemIndex := 0;
  ShowModal;
end;

procedure TFormOut.Out_OffsetClick(Sender: TObject);
begin
  if not Out_Offset.Checked then
    Out_Format.Checked := False;
end;

procedure TFormOut.SaveTextureToFile(Texture: TDXImageTexture; SaveDir: string;
  Index: Integer);
var
  FileName: PAnsiChar;
begin
  case RadioGroupImageFormat.ItemIndex of
    0: begin
      FileName := PAnsiChar(Format('%s%.8d.bmp', [SaveDir, Index]));
      D3DXSaveTextureToFile(FileName, D3DXIFF_BMP, Texture.Texture9, nil);
    end;
    1: begin
      FileName := PAnsiChar(Format('%s%.8d.png', [SaveDir, Index]));
      D3DXSaveTextureToFile(FileName, D3DXIFF_PNG, Texture.Texture9, nil);
    end;
    2: begin
      FileName := PAnsiChar(Format('%s%.8d.tga', [SaveDir, Index]));
      D3DXSaveTextureToFile(FileName, D3DXIFF_TGA, Texture.Texture9, nil);
    end;
    3: begin
      FileName := PAnsiChar(Format('%s%.8d.dds', [SaveDir, Index]));
      D3DXSaveTextureToFile(FileName, D3DXIFF_DDS, Texture.Texture9, nil);
    end;
  end;
end;

end.

