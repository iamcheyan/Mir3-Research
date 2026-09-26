unit Mpeg;

interface

uses
  Windows, DShow, ActiveX, Controls;

type
  TMPEG = class
  private
    g_pGraphBuilder: IGraphBuilder;
    g_pMediaControl: IMediaControl; // 播放狀態設置.
    g_pMediaSeeking: IMediaSeeking; // 播放位置.
    g_pAudioControl: IBasicAudio; // 音量/平衡設置.
    g_pVideoWindow: IVideoWindow; //設置播放表單.
    boInit: Boolean;
    boPlay: Boolean;
    MovieWindow: TWinControl;
    function Init(): Boolean;
    procedure Close();
//    function boStop(): Boolean; //判断是否结束
    { Private declarations }
  public
    constructor Create(PlayWindow: TWinControl);
    destructor Destroy; override;
    function GetState: Longint;
    function GetPosition: Int64;
    function GetStopPosition: Int64;
    function Play(sFileName: string; vLeft, vTop, vRight, vBottom:Integer): Boolean;
    procedure Pause();
    procedure Stop();
    { Public declarations }
  end;

implementation

uses
  ClMain;

{ TMPEG }

procedure TMPEG.Close;
begin
  if Assigned(g_pMediaControl) then
    g_pMediaControl.Stop; // 釋放所有用到的介面。
  if Assigned(g_pAudioControl) then
    g_pAudioControl := nil;
  if Assigned(g_pMediaSeeking) then
    g_pMediaSeeking := nil;
  if Assigned(g_pMediaControl) then
    g_pMediaControl := nil;
  if Assigned(g_pVideoWindow) then
    g_pVideoWindow := nil;
  if Assigned(g_pGraphBuilder) then
    g_pGraphBuilder := nil;

  CoUninitialize;
  boInit := False;
end;

constructor TMPEG.Create(PlayWindow: TWinControl);
begin
  MovieWindow := PlayWindow;
  g_pGraphBuilder := nil;
  g_pMediaControl := nil;
  g_pMediaSeeking := nil;
  g_pAudioControl := nil;
  g_pVideoWindow := nil;
//  boInit:=Init();
  boInit := False;
end;

destructor TMPEG.Destroy;
begin
  Close();
  inherited;
end;

function TMPEG.Init: Boolean;
begin
  Result := false; // 初始化COM介面
  if failed(CoInitialize(nil)) then
    exit; // 創建DirectShow Graph
  if failed(CoCreateInstance(TGUID(CLSID_FilterGraph), nil, CLSCTX_INPROC, TGUID
    (IID_IGraphBuilder), g_pGraphBuilder)) then
    exit; // 獲取IMediaControl 介面
  if failed(g_pGraphBuilder.QueryInterface(IID_IMediaControl, g_pMediaControl)) then
    exit; // 獲取IMediaSeeking 介面
  if failed(g_pGraphBuilder.QueryInterface(IID_IMediaSeeking, g_pMediaSeeking)) then
    exit; // 獲取IBasicAudio 介面
  if failed(g_pGraphBuilder.QueryInterface(IID_IBasicAudio, g_pAudioControl)) then
    exit; // 獲取IVideowindow 介面
  if failed(g_pGraphBuilder.QueryInterface(IID_IVideoWindow, g_pVideoWindow)) then
    exit; // 所有介面獲取成功 R
  Result := true;
end;

procedure TMPEG.Pause;
begin
  g_pMediaControl.Pause;
end;

function TMPEG.Play(sFileName: string; vLeft, vTop, vRight, vBottom:Integer): Boolean;
var
  _hr: Hresult;
  wFile: array[0..(MAX_PATH * 2) - 1] of char;
begin
  try
    Result := False;
    boInit := Init();
    MultiByteToWideChar(CP_ACP, 0, pchar(sFileName), -1, @wFile, MAX_PATH); //轉換格式
    _hr := g_pGraphBuilder.renderfile(@wFile, nil);
    if failed(_hr) then
      exit;

    if m_hwnd <> 0 then begin
      g_pVideoWindow.put_Owner(m_hwnd);
      g_pVideoWindow.put_windowstyle(WS_CHILD or WS_CLIPSIBLINGS);
      g_pVideoWindow.SetWindowposition(vLeft, vTop, vRight-vLeft, vBottom-vTop);
        //播放的圖像爲整個panel1的ClientRect//
    end;
//    g_pVideoWindow.SetWindowposition(0, 0, MovieWindow.Width, MovieWindow.Handle); //播放的圖像爲整個panel1的ClientRect//
    g_pAudioControl.put_Volume(100);//設置爲最大音量

    if Failed(g_pMediaControl.Run) then
      Exit;
    Result := True;
    boPlay := true;
  except
  end;
end;

function TMPEG.GetState: Longint;
var
  AState: Longint;
begin
  if not boInit then
    exit;
  g_pMediaControl.GetState(0, AState);
  Result := AState;
end;

function TMPEG.GetPosition: Int64;
begin
  if boInit then
    g_pMediaSeeking.GetCurrentPosition(Result)
  else
    Result := 0;
    //DebugOutStr('GetPosition:'+inttostr(Result));
end;

function TMPEG.GetStopPosition: Int64;
begin
  if boInit then
    g_pMediaSeeking.GetStopPosition(Result)
  else
    Result := 0;
    //DebugOutStr('GetStopPosition'+inttostr(Result));
end;

procedure TMPEG.Stop;
begin
  if not boInit then
    exit;
  g_pMediaControl.Stop;
  Close();
end;

end.

