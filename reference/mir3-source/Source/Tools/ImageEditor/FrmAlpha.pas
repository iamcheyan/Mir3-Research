unit FrmAlpha;

interface

uses
  Windows, Messages, SysUtils, Variants, Classes, Graphics, Controls, Forms,
  Dialogs, StdCtrls, ComCtrls, DropGroupPas, Buttons, Mask, RzEdit, RzBtnEdt;

type
  TfrmConvertDlg = class(TForm)
    RzLabel: TLabel;
    EditFileDir: TRzButtonEdit;
    RzLabel1: TLabel;
    EditSaveDir: TRzButtonEdit;
    BitBtnOK: TBitBtn;
    BitBtnClose: TBitBtn;
    CheckBox1: TCheckBox;
    Memo1: TMemo;
    OpenDialog: TOpenDialog;
    SaveDialog: TSaveDialog;
    ProgressBar1: TProgressBar;
    ProgressBar: TProgressBar;
    procedure CheckBox1Click(Sender: TObject);
    procedure EditFileDirButtonClick(Sender: TObject);
    procedure EditSaveDirButtonClick(Sender: TObject);
    procedure FormCreate(Sender: TObject);
    procedure FormDestroy(Sender: TObject);
    procedure FormCloseQuery(Sender: TObject; var CanClose: Boolean);
    procedure BitBtnCloseClick(Sender: TObject);
    procedure BitBtnOKClick(Sender: TObject);
  private
    { Private declarations }
    procedure GetSourceList(sPath: string);
    function FormatBitmap(const Bitmap: TBitmap; BColor: TColor; var Data: PChar): Integer;
    procedure ConvertSource(SourceName, DestName: string; sText: string);
  public
    procedure Open();
  end;

var
  frmConvertDlg: TfrmConvertDlg;
  StringList: TStringList;
  sFileName: string;

implementation

{$R *.dfm}

uses
  Wil, wmMyImage, wmM3Def, ZShare, HUtil32;

{ TFormAlpha }

procedure TfrmConvertDlg.GetSourceList(sPath: string);
var
  I: Integer;
begin
  StringList.Clear;
  DoSearchFile(sPath, '.Wil', StringList);

  for I := 0 to StringList.Count - 1 do
    Memo1.Lines.Add(StringList.Strings[I])
end;

function TfrmConvertDlg.FormatBitmap(const Bitmap: TBitmap; BColor: TColor; var Data: PChar): Integer;
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

procedure TfrmConvertDlg.ConvertSource(SourceName, DestName: string; sText: string);
const
  MAXBUFFERLEN = 1024 * 1024 * 50;
var
  fhandle: THandle;
  I, nX, nY, nShadowX, nShadowY, nShadow: Integer;
  WMImageHeader: wmMyImage.TWMImageHeader;
  ImageInfo: wmMyImage.TWMImageInfo;
  WMImages: wmMyImage.TWMMyImageImages;
  Bitmap: TBitmap;
  DataBuffer: PChar;
  DataBufferLen: Integer;
begin
  try
    DataBuffer := nil;
    Bitmap := nil;
    ProgressBar.Max := 0;
    ProgressBar.Position := 0;
    if FileExists(SourceName) then begin
      if g_OldWMImages <> nil then begin
        g_OldWMImages.Free;
        g_OldWMImages := nil;
      end;

      g_OldWMImages := CreateWMImages(t_wmM3Def);
      if g_OldWMImages <> nil then begin
        g_OldWMImages.FileName := SourceName;
        g_OldWMImages.LibType := ltLoadBmp;
        g_OldWMImages.Initialize;
        ProgressBar.Max := g_OldWMImages.ImageCount;

        if FileExists(DestName) then begin
          if MessageBox(Handle, '文件已经存在，是否覆盖原文件？', '提示信息', MB_OKCANCEL + MB_ICONWARNING) = IDCANCEL then
            exit;
          DeleteFile(DestName);
        end;
        fhandle := FileCreate(DestName, fmOpenWrite);
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
            g_NewWMImages.FileName := DestName;
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
                  Application.ProcessMessages;
                  ProgressBar.Position := ProgressBar.Position + 1;

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

    if g_NewWMImages <> nil then begin
      FreeAndNil(g_NewWMImages);
    end;
    if g_OldWMImages <> nil then begin
      FreeAndNil(g_OldWMImages);
    end;
  except
    Memo1.Lines.Add('effor ');
  end;
end;


procedure TfrmConvertDlg.BitBtnCloseClick(Sender: TObject);
begin
  Close;
end;

procedure TfrmConvertDlg.BitBtnOKClick(Sender: TObject);
var
  I: Integer;
  sFileName, sDestFile, Name: string;
  btEncr: Byte;
begin
  if g_boWalking then Exit;
  sFileName := Trim(EditFileDir.Text);
  sDestFile := Trim(EditSaveDir.Text);

  if CompareText(sFileName, sDestFile) = 0 then
  begin
    Application.MessageBox('转换路径或文件名不能相同 ！！！', '提示信息', MB_ICONQUESTION);
    Exit;
  end;
  CheckBox1.Enabled := False;
  BitBtnOK.Enabled := False;
  BitBtnClose.Enabled := False;
  EditFileDir.Enabled := False;
  EditSaveDir.Enabled := False;
  g_boWalking := True;
  try
    if CheckBox1.Checked then
    begin
      Memo1.Clear;
      ProgressBar1.Max := StringList.Count;
      ProgressBar1.Position := 0;
      Name := '.Lib';

      for I := 0 to StringList.Count - 1 do
      begin
     //   Application.ProcessMessages;
        sFileName := StringList.Strings[I];
        sDestFile := Trim(EditSaveDir.Text) + ExtractFileNameOnly(sFileName) + Name;
        Memo1.Lines.Add(sFileName + ' -> ' + sDestFile);

        ConvertSource(sFileName, sDestFile, '批量数据转换(%d/%d)');
        ProgressBar1.Position := ProgressBar1.Position + 1;
      end;
      Application.MessageBox('转换成功 ！！！', '提示信息', MB_ICONQUESTION);
    end
    else
    begin
      ConvertSource(sFileName, sDestFile, '数据转换(%d/%d)');
      Application.MessageBox('转换成功 ！！！', '提示信息', MB_ICONQUESTION);
    end;

  finally
    g_boWalking := False;
    CheckBox1.Enabled := True;
    BitBtnOK.Enabled := True;
    BitBtnClose.Enabled := True;
    EditFileDir.Enabled := True;
    EditSaveDir.Enabled := True;
  end;
end;
procedure TfrmConvertDlg.CheckBox1Click(Sender: TObject);
begin
  if CheckBox1.Checked then
  begin
    RzLabel.Caption := '旧文件目录:';
    RzLabel1.Caption := '新文件目录:';
  end
  else
  begin
    RzLabel.Caption := '旧文件:';
    RzLabel1.Caption := '新文件:';
  end;
end;

procedure TfrmConvertDlg.EditFileDirButtonClick(Sender: TObject);
var
  Directory: string;
  sPath: string;
begin
  if CheckBox1.Checked then
  begin
    if SelectDirectory('浏览文件夹', '', sPath, frmConvertDlg.Handle) then
    begin
      if (sPath <> '') and (sPath[Length(sPath)] <> '\') then sPath := sPath + '\';
      EditFileDir.Text := sPath;
      GetSourceList(EditFileDir.Text);
    end;
  end
  else
  begin
    with OpenDialog do
    begin
      if Execute and (FileName <> '') then
      begin
        sFileName := OpenDialog.FileName;
        EditFileDir.Text := FileName;
      end;
    end;
  end;
end;

procedure TfrmConvertDlg.EditSaveDirButtonClick(Sender: TObject);
var
  sPath: string;
begin
  if CheckBox1.Checked then
  begin
    if SelectDirectory('浏览文件夹', '', sPath, frmConvertDlg.Handle) then
    begin
      if (sPath <> '') and (sPath[Length(sPath)] <> '\') then sPath := sPath + '\';
      EditSaveDir.Text := sPath;
    end;
  end
  else
  begin
    with SaveDialog do
    begin
      Filter := 'Mir3 Library File (*.Lib)|*' + MYFILEEXT;
      FileName := ExtractFilePath(EditFileDir.Text) + ExtractFileNameOnly(EditFileDir.Text){ + ExtractFileExt(EditFileDir.Text)};
      if Execute and (FileName <> '') then
      begin
        FileName := ExtractFilePath(FileName) + ExtractFileNameOnly(FileName);

        EditSaveDir.Text := FileName;
      end;
    end;
  end;
end;

procedure TfrmConvertDlg.FormCloseQuery(Sender: TObject; var CanClose: Boolean);
begin
  CanClose := not g_boWalking;
end;

procedure TfrmConvertDlg.FormCreate(Sender: TObject);
begin
  ModalResult := 0;
  StringList := TStringList.Create;
  OpenDialog.Filter := '传奇3复刻版资源文件|*.Lib;*.Wil';
end;

procedure TfrmConvertDlg.FormDestroy(Sender: TObject);
begin
  StringList.Free;
end;

procedure TfrmConvertDlg.Open;
begin
  ShowModal;
end;

end.
