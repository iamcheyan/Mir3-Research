unit DrawScrn;

interface

uses
  Windows, Messages, SysUtils, Classes, Graphics, Controls, Forms, Dialogs,
  HGETextures, IntroScn, Actor, cliUtil, ClFunc, HUtil32;

const
  MAXSYSLINE = 8;
  BOTTOMBOARD = 1;
  VIEWCHATLINE = 9;
  AREASTATEICONBASE = 150;
  HEALTHBAR_BLACK = 2;
  HEALTHBAR_RED = 3;
  HEALTHBAR_BLUE = 10;

type
  TDrawScreen = class
  private
    frametime, framecount, drawframecount: longword;
    SysMsg: TStringList;
  public
    CurrentScene: TScene;
    ChatStrs: TStringList;
    ChatBks: TList;
    ChatBoardTop: integer;
    HintList: TStringList;
    HintX, HintY, HintWidth, HintHeight: integer;
    HintUp: Boolean;
    HintColor: TColor;
    HintStyle: integer;

    constructor Create;
    destructor Destroy; override;
    procedure KeyPress(var Key: Char);
    procedure KeyDown(var Key: Word; Shift: TShiftState);
    procedure MouseMove(Shift: TShiftState; X, Y: Integer);
    procedure MouseDown(Button: TMouseButton; Shift: TShiftState; X, Y: Integer);
    procedure Initialize;
    procedure Finalize;
    procedure ChangeScene(scenetype: TSceneType);
    procedure DrawScreen(MSurface: TDirectDrawSurface);
    procedure DrawScreenTop(MSurface: TDirectDrawSurface);
    procedure AddSysMsg(msg: string);
    procedure AddChatBoardString(str: string; fcolor, bcolor: integer);
    procedure ClearChatBoard;

    procedure ShowHint(x, y: integer; str: string; color: TColor; drawup: Boolean; drawstyle: byte = 0);
    procedure ClearHint;
    procedure DrawHint(MSurface: TDirectDrawSurface);
  end;

implementation

uses
  ClMain, uWilFile, HGEFont;


constructor TDrawScreen.Create;
var
  i: integer;
begin
  CurrentScene := nil;
  frametime := GetTickCount;
  framecount := 0;
  SysMsg := TStringList.Create;
  ChatStrs := TStringList.Create;
  ChatBks := TList.Create;
  ChatBoardTop := 0;
  HintList := TStringList.Create;
end;

destructor TDrawScreen.Destroy;
begin
  SysMsg.Free;
  ChatStrs.Free;
  ChatBks.Free;
  HintList.Free;
  inherited Destroy;
end;

procedure TDrawScreen.Initialize;
begin
end;

procedure TDrawScreen.Finalize;
begin
end;

procedure TDrawScreen.KeyPress(var Key: Char);
begin
  if CurrentScene <> nil then
    CurrentScene.KeyPress(Key);
end;

procedure TDrawScreen.KeyDown(var Key: Word; Shift: TShiftState);
begin
  if CurrentScene <> nil then
    CurrentScene.KeyDown(Key, Shift);
end;

procedure TDrawScreen.MouseMove(Shift: TShiftState; X, Y: Integer);
begin
  if CurrentScene <> nil then
    CurrentScene.MouseMove(Shift, X, Y);
end;

procedure TDrawScreen.MouseDown(Button: TMouseButton; Shift: TShiftState; X, Y: Integer);
begin
  if CurrentScene <> nil then
    CurrentScene.MouseDown(Button, Shift, X, Y);
end;

procedure TDrawScreen.ChangeScene (scenetype: TSceneType);
begin
  if CurrentScene <> nil then CurrentScene.CloseScene;
  case scenetype of
    stIntro: CurrentScene := IntroScene;
    stLogin: CurrentScene := LoginScene;
    stSelectCountry: ;
    stSelectChr: CurrentScene := SelectChrScene;
    stNewChr: ;
    stLoading: CurrentScene := LoadingScene;
    stLoginNotice: CurrentScene := LoginNoticeScene;
    stPlayGame: CurrentScene := PlayScene;
  end;
  if CurrentScene <> nil then CurrentScene.OpenScene;
end;

procedure TDrawScreen.AddSysMsg(msg: string);
begin
  if SysMsg.Count >= 10 then SysMsg.Delete(0);
  SysMsg.AddObject(msg, TObject(GetTickCount));
end;

procedure TDrawScreen.AddChatBoardString(str: string; fcolor, bcolor: integer);
var
  i, len, aline: integer;
  dline, temp: string;
const
  BOXWIDTH = 328; //41;
begin
  len := Length(str);
  temp := '';
  i := 1;
  while TRUE do begin
    if i > len then
      break;
    if byte(str[i]) >= 128 then begin
      temp := temp + str[i];
      Inc(i);
      if i <= len then
        temp := temp + str[i]
      else
        break;
    end
    else
      temp := temp + str[i];

    aline := FrmMain.Canvas.TextWidth(temp);
    if aline > BOXWIDTH then begin
      ChatStrs.AddObject(temp, TObject(fcolor));
      ChatBks.Add(Pointer(bcolor));
      str := Copy(str, i + 1, len - i);
      temp := '';
      break;
    end;
    Inc(i);
  end;

  if temp <> '' then begin
    ChatStrs.AddObject(temp, TObject(fcolor));
    ChatBks.Add(Pointer(bcolor));
    str := '';
  end;
  if ChatStrs.Count > 200 then begin
    ChatStrs.Delete(0);
    ChatBks.Delete(0);
    if ChatStrs.Count - ChatBoardTop < VIEWCHATLINE then Dec(ChatBoardTop);
  end
  else if (ChatStrs.Count - ChatBoardTop) > VIEWCHATLINE then begin
    Inc(ChatBoardTop);
  end;

  if str <> '' then
    AddChatBoardString(' ' + str, fcolor, bcolor);
end;

procedure TDrawScreen.ShowHint(x, y: integer; str: string; color: TColor; drawup: Boolean; drawstyle: byte);
var
  data, data1, data2: string;
  w, h: integer;
begin
  ClearHint;
  HintX := x;
  HintY := y;
  HintWidth := 0;
  HintHeight := 0;
  HintUp := drawup;
  HintColor := color;
  HintStyle  := drawstyle;
  while TRUE do begin
    if str = '' then break;
    str := GetValidStr3 (str, data, ['\']);

    // Added by rainee 2016-12-25 去掉颜色标识的宽度
    data1 := data;
    if (Pos('<F:', data1) > 0) and (Pos('>', data1) > 0) then begin
      while True do begin
        data2 := Copy(data1, Pos('>', data1)+1, Length(data1));
        data1 := Copy(data1, 1, Pos('<', data1)-1);
        data1 :=  data1 + data2;
        if (Pos('<F:', data1) = 0) or (Pos('>', data1) = 0) then Break;
      end;
      if data1 = '' then data := '';
    end;

    w := FrmMain.Canvas.TextWidth (data1) + 4{咯归} * 2;
    if w > HintWidth then HintWidth := w;
    if data <> '' then
       HintList.Add (data)
  end;
  HintHeight := (FrmMain.Canvas.TextHeight('A') + 1) * HintList.Count + 3{咯归}  * 2;
  if HintUp then
    HintY := HintY - HintHeight;
end;

procedure TDrawScreen.ClearHint;
begin
  HintList.Clear;
end;

procedure TDrawScreen.ClearChatBoard;
begin
  SysMsg.Clear;
  ChatStrs.Clear;
  ChatBks.Clear;
  ChatBoardTop := 0;
end;

procedure TDrawScreen.DrawScreen(MSurface: TDirectDrawSurface);
  procedure NameTextOut(surface: TDirectDrawSurface; x, y, fcolor, bcolor:
    integer; namestr: string);
  var
    i, row: integer;
    nstr: string;
  begin
    row := 0;
    for i := 0 to 10 do begin
      if namestr = '' then
        break;
      namestr := GetValidStr3(namestr, nstr, ['\']);
      g_DXCanvas.TextOutX(x - g_DXCanvas.TextWidth(nstr) div 2,
                          y + row * 12,
                          fcolor,
                          nstr);
      Inc(row);
    end;
  end;
var
  i, k, line, sx, sy, fcolor, bcolor: integer;
  actor: TActor;
  str, uname: string;
  dsurface: TDirectDrawSurface;
  d: TDirectDrawSurface;
  rc: TRect;
begin
  if CurrentScene <> nil then
    CurrentScene.PlayScene(MSurface);

  if GetTickCount - frametime > 1000 then begin
    frametime := GetTickCount;
    drawframecount := framecount;
    framecount := 0;
  end;
  Inc(framecount);

  if MySelf = nil then Exit;

  if CurrentScene = PlayScene then begin
    with MSurface do begin
      with PlayScene do begin
        for k := 0 to ActorList.Count - 1 do begin
          actor := ActorList[k];
          if (actor.BoOpenHealth or actor.BoInstanceOpenHealth) and not actor.Death
            then begin
            if actor.BoInstanceOpenHealth then
              if GetTickCount - actor.OpenHealthStart > actor.OpenHealthTime then
                actor.BoInstanceOpenHealth := False;
            d := g_WProgUse.Images[HEALTHBAR_BLACK];
            if d <> nil then
              MSurface.Draw(actor.SayX - d.Width div 2, actor.SayY - 10, d.ClientRect,
                d, True);

            if actor.Race = 0 then
              d := g_WProgUse.Images[HEALTHBAR_RED]
            else
              d := g_WProgUse.Images[HEALTHBAR_RED];
            if d <> nil then begin
              rc := d.ClientRect;
              if actor.Abil.MaxHP > 0 then
                rc.Right := Round((rc.Right - rc.Left) / actor.Abil.MaxHP *
                  actor.Abil.HP);
              MSurface.Draw(actor.SayX - d.Width div 2, actor.SayY - 10, rc, d, True);
            end;
          end;
        end;
      end;

      if (FocusCret <> nil) and PlayScene.IsValidActor(FocusCret) then begin
        if FocusCret.Race = 95 then begin
          if FocusCret.Death then
            FocusCret.UserName := '酒滚瘤'
          else
            FocusCret.UserName := '禁扁唱规';
        end
        else if FocusCret.Race = 96 then
          FocusCret.UserName := '';

        uname := FocusCret.DescUserName + '\' + FocusCret.UserName;
        if (FocusCret.Race = 50) and (FocusCret.Appearance = 57) then uname := '';

        NameTextOut(MSurface,
                    FocusCret.SayX,
                    FocusCret.SayY + 30,
                    FocusCret.NameColor,
                    clBlack,
                    uname);
      end;
      if BoSelectMyself then begin
        uname := MySelf.DescUserName + '\' + MySelf.UserName;
        NameTextOut (MSurface,
                     Myself.SayX,
                     Myself.SayY + 30,
                     Myself.NameColor, clBlack,
                     uname);
      end;
      //char saying
      with PlayScene do begin
        for k := 0 to ActorList.Count - 1 do begin
          actor := ActorList[k];
          if actor.Saying[0] <> '' then begin
            if GetTickCount - actor.SayTime < 4 * 1000 then begin
              for i := 0 to actor.SayLineCount - 1 do
                if actor.Death then
                  g_DXCanvas.TextOutX(actor.SayX - (actor.SayWidths[i] div 2),
                                      actor.SayY - (actor.SayLineCount * 16) + i * 14,
                                      clGray,
                                      actor.Saying[i])
                else
                  g_DXCanvas.TextOutX(actor.SayX - (actor.SayWidths[i] div 2),
                                      actor.SayY - (actor.SayLineCount * 16) + i * 14,
                                      clWhite,
                                      actor.Saying[i]);
            end
            else
              actor.Saying[0] := '';
          end;
        end;
      end;

      if (AreaStateValue and $04) <> 0 then begin
        g_DXCanvas.BoldTextOut(0, 0, clWhite, '攻城战地区');
      end;

      k := 0;
      for i:=0 to 15 do begin
        if AreaStateValue and ($01 shr i) <> 0 then begin
          d := g_WProgUse.Images[AREASTATEICONBASE + i];
          if d <> nil then begin
            k := k + d.Width;
            MSurface.Draw(SCREENWIDTH - k, 0, d.ClientRect, d, True);
          end;
        end;
      end;
    end;
  end;
end;

procedure TDrawScreen.DrawScreenTop(MSurface: TDirectDrawSurface);
var
  i, sx, sy: integer;
  TempMsg: string;
begin
  if Myself = nil then exit;
  if CurrentScene = PlayScene then begin
    with MSurface do begin
      if SysMsg.Count > 0 then begin
        sx := 30;
        sy := 40;
        for i := 0 to SysMsg.Count - 1 do begin
          if Copy(SysMsg[i], 1, 8) = 'clYellow' then begin
            TempMsg := Copy(SysMsg[i], 9, Length(SysMsg[i]) - 8);
            g_DXCanvas.BoldTextOut(sx, sy, clYellow, TempMsg);
          end
          else
            g_DXCanvas.BoldTextOut(sx, sy, clGreen, SysMsg[i]);
          inc(sy, 16);
        end;
        if GetTickCount - longword(SysMsg.Objects[0]) >= 3000 then
          SysMsg.Delete(0);
      end;
    end;
  end;
end;

procedure TDrawScreen.DrawHint(MSurface: TDirectDrawSurface);
var
  d: TDirectDrawSurface;
  n, i, hx, hy, FontColor, RectAlpha, FontBold, FontSize, nTextHeight: integer;
  rc: TRect;
  RectColor, FrameColor: TColor;
  str, data, scmdcolor, scfg: string;
  OldFontStyle: TFontStyles;
  old: Integer;
begin
  if HintList.Count > 0 then begin
    if HintX + HintWidth > SCREENWIDTH then hx := SCREENWIDTH - HintWidth
    else hx := HintX;
    if HintY < 0 then hy := 0
    else hy := HintY;
    if hx < 0 then hx := 0;

    rc.Left := hx;
    rc.Top := hy;
    rc.Right := rc.Left + HintWidth;
    rc.Bottom := rc.Top + HintHeight;

    if HintColor = $393800 then begin
      RectColor := $FFFFA6;
      RectAlpha := 230;
    end else if HintColor = $80FFFF then begin  //地面物品显示名字
      RectColor := $503C28;
      RectAlpha := 150;
    end else begin
      RectColor := $503C28;
      RectAlpha := 230;
    end;

    if HintColor = $393800 then FrameColor := $FF393800
    else FrameColor := $FF969632;

    g_DXCanvas.Draw2DRect(rc, RectColor, RectAlpha);
    if HintStyle = 0 then g_DXCanvas.Draw2DRectLine(rc, FrameColor);
  end;
  with g_DXCanvas do begin
    if HintList.Count > 0 then begin
      FrmMain.Canvas.Font.Color := HintColor;
      case HintStyle of
        0: //默认文字显示
          begin
            for i:=0 to HintList.Count-1 do begin
              str := HintList[i];
              n:=0;
              while True do begin
                if str = '' then Break;
                FontColor := HintColor;
                FontBold := 0;
                FontSize := 9;
                if (Pos('<F:', str) > 0) then begin
                  if str[1] = '<' then begin
                    str := ArrestStringEx(str, '<F:', '>', data);
                    if data <> '' then begin
                      data := Copy(data, 3, Length(data) - 2);
                      while data <> '' do begin
                        data := GetValidStr3(data, scfg, [' ']);
                        if scfg <> '' then begin
                          scfg := UpperCase(scfg);

                          case scfg[1] of
//                            'I': begin
//                                //Image
//                                scfg := Copy(scfg, 3, Length(scfg) - 2);
//                                Segment.Image := StrToInt(scfg);
//                              end;
                            'C': begin
                                scfg := Copy(scfg, 3, Length(scfg) - 2);
                                if CompareText('ORANGE', scfg) = 0 then FontColor := GetRGB(116)
                                else if not IdentToColor(scfg, FontColor) then FontColor := StrToInt64(scfg); //颜色字符串转颜色

//                                if CompareText('clLtGray', scfg) = 0 then
//                                  FontColor := clLtGray
//                                else if CompareText('clDkGray', scfg) = 0 then
//                                  FontColor := clDkGray
//                                else
//                                  FontColor := StringToColor(scfg);
                              end;
                            'S': begin
                                scfg := Copy(scfg, 3, Length(scfg) - 2);
                                FontSize := StrToInt(scfg);
                              end;
                            'B': begin
                                scfg := Copy(scfg, 3, Length(scfg) - 2);
                                FontBold := 0;
                                if CompareText(scfg, 'BOLD') = 0 then
                                  FontBold := 1
                                else if CompareText(scfg, 'UNDERLINE') = 0 then
                                  FontBold := 2;
                              end;
                          end;
                        end;
//                        scmdcolor := GetValidStr3(data, data, ['=']);
//                        if CompareText('ORANGE', scmdcolor) = 0 then FontColor := GetRGB(116)
//                        else if not IdentToColor(scmdcolor, FontColor) then FontColor := StrToInt64(scmdcolor); //颜色字符串转颜色
                      end;
                    end;
                  end;
                   //判断是否有多个标识符
                  if Pos('<F:', str) > 0 then begin
                    data := Copy(str, 1, Pos('<', str) - 1);
                    str := Copy(str, Pos('<F:', str), Length(str));
                  end else data := str;

                  old := MainForm.Canvas.Font.Size;
                  OldFontStyle := MainForm.Canvas.Font.Style;
                  MainForm.Canvas.Font.Size := FontSize;
                  if FontBold = 1 then MainForm.Canvas.Font.Style := [fsBold];
                //   FrmMain.Canvas.Font.Color := FontColor;
                  TextOut(hx+4+n, hy+3+nTextHeight+(TextHeight('A')+1)*i, FontColor, data);
                  MainForm.Canvas.Font.Style := OldFontStyle;
                  MainForm.Canvas.Font.Size := old;

//                  nTextHeight := 0;
//                  if 9 < FontSize then nTextHeight := FontSize - old;
//                  if FontBold = 1 then nTextHeight := nTextHeight + (FontBold * 2);

                  if (Pos('<F:', str) = 0) or ((Pos('>', str) = 0)) then Break;
                  n:= n + TextWidth(data);
                end else begin
                  TextOut(hx+4, hy+3+nTextHeight+(TextHeight('A')+1)*i, HintColor, str);
//                  nTextHeight := 0;
                  Break;
                end;
              end;
            end;
          end;
        1: //地面物品文字显示
          begin
            FrmMain.Canvas.Font.Color := HintColor;
            for i := 0 to HintList.Count - 1 do begin
              ShadowTextOut(hx + 4, hy + 3 + (TextHeight('A') + 1) * i, HintColor, HintList[i]);
            end;
          end;
      end;
    end;
  end;
end;

end.
