unit Light0b;

interface
uses
  Windows, SysUtils, Classes, Graphics, HGETextures, HGEBase, DirectX, DirectXGraphics, HGECanvas, Grobal2;

{$INCLUDE Light0b.inc}

var
  Light0bSurface: TDirectDrawSurface = nil;

procedure CreateLight0bSurface();
procedure DestroyLight0bSurface();

implementation
uses
  CLMain;

function DecodeRLE(const Source, Target: Pointer; Count: Cardinal; bitLength: Byte): Boolean;
var
  I, j: Integer;
  SourcePtr,
  TargetPtr: PByte;
  RunLength: Cardinal;
  Counter: Cardinal;
begin
  Counter := 0;
  TargetPtr := Target;
  SourcePtr := Source;

  while Counter < Count do begin
    RunLength := 1 + (SourcePtr^ and $7F);
    if SourcePtr^ > $7F then begin
      Inc(SourcePtr);
      for I := 0 to RunLength - 1 do begin
        for j := 1 to bitLength - 1 do
        begin
          TargetPtr^ := SourcePtr^;
          Inc(SourcePtr);
          Inc(TargetPtr);
        end;
        TargetPtr^ := SourcePtr^;
        Dec(SourcePtr, bitLength - 1);
        Inc(TargetPtr);
      end;
      Inc(SourcePtr, bitLength);
    end
    else begin
      Inc(SourcePtr);
      Move(SourcePtr^, TargetPtr^, bitLength * RunLength);
      Inc(SourcePtr, bitLength * RunLength);
      Inc(TargetPtr, bitLength * RunLength);
    end;
    Inc(Counter, bitLength * RunLength);
  end;
  Result := Counter = Count;
end;

procedure CreateLight0bSurface();
var
  Access: TDXAccessInfo;
  WriteBuffer, ReadBuffer, DecodeBuffer: PChar;
  Y: Integer;
begin
  DestroyLight0bSurface();
  Light0bSurface := TDXImageTexture.Create(g_DXCanvas);
  Light0bSurface.Size := Point(LightWidth, LightHeight);
  Light0bSurface.PatternSize := Point(LightWidth, LightHeight);
  Light0bSurface.Format := D3DFMT_A8R8G8B8;
  Light0bSurface.Active := True;
  if Light0bSurface.Active then begin
    if Light0bSurface.Lock(lfWriteOnly, Access) then begin
      GetMem(DecodeBuffer, LightWidth * LightHeight * 4);
      Try
        if DecodeRLE(@LightBuffer, DecodeBuffer, LightWidth * LightHeight * 4, 4) then
        begin
          for Y := 0 to LightHeight - 1 do begin
            ReadBuffer := @DecodeBuffer[Y * LightWidth * 4];
            WriteBuffer := Pointer(Integer(Access.Bits) + (Access.Pitch * Y));
            Move(ReadBuffer^, WriteBuffer^, LightWidth * 4);
          end;
        end;
      Finally
        FreeMem(DecodeBuffer);
        Light0bSurface.Unlock;
      End;
    end; 
  end else begin
    Light0bSurface.Free;
    Light0bSurface := nil;
  end;
end;

procedure DestroyLight0bSurface();
begin
  if Light0bSurface <> nil then Light0bSurface.Free;
  Light0bSurface := nil;
end;

end.
