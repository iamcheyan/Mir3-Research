unit NoticeM;

interface

uses
  Windows, Messages, SysUtils, Classes, Graphics, Controls, Dialogs,
  syncobjs, MudUtil, HUtil32, Grobal2;

const
   MAXNOTICE = 100;
   NoticeDir: string = '.\Notice\';

type
   TNoticeList = record
      Name: string;
      List: TStringList;
      Valid: Boolean;      //리프레쉬할때 쓰임
   end;

   TNoticeManager = class
   private
   public
      Notices: array[0..MAXNOTICE-1] of TNoticeList;
      constructor Create;
      destructor Destroy; override;
      procedure RefreshNoticeList;
      function  GetNoticList (nname: string; slist: TStringList): Boolean;
   end;


implementation

uses
   svMain;

constructor TNoticeManager.Create;
var
   i: integer;
begin
   for i:=0 to MAXNOTICE-1 do begin
      Notices[i].Name := '';
      Notices[i].List := nil;
      Notices[i].Valid := TRUE;
   end;
end;

destructor TNoticeManager.Destroy;
var
   i: integer;
begin
   for i:=0 to MAXNOTICE-1 do begin
      if Notices[i].List <> nil then
         Notices[i].List.Free;
   end;
end;

procedure TNoticeManager.RefreshNoticeList;
var
   i: integer;
   flname: string;
begin
   for i:=0 to MAXNOTICE-1 do begin
      flname := NoticeDir + Notices[i].Name + '.txt';
      if FileExists (flname) then begin
         try
            if Notices[i].List = nil then Notices[i].List := TStringList.Create;
            Notices[i].List.LoadFromFile (flname);
         except
            MainOutMessage ('Error in loading notice text. file name is ' + flname);
         end;
      end;
   end;
end;

function  TNoticeManager.GetNoticList (nname: string; slist: TStringList): Boolean;
var
   i: integer;
   noentry: Boolean;
   flname: string;
begin
   Result := FALSE;
   noentry := TRUE;
   for i:=0 to MAXNOTICE-1 do begin
      if CompareText (Notices[i].Name, nname) = 0 then begin
         if Notices[i].List <> nil then begin
            slist.Assign (Notices[i].List);
            Result := TRUE;
         end;
         noentry := FALSE;
         break;
      end;
   end;
   if noentry then begin //등록되지 않았으면 새로 등록한다.
      for i:=0 to MAXNOTICE-1 do begin
         if Notices[i].Name = '' then begin
            flname := NoticeDir + nname + '.txt';
            if FileExists (flname) then begin
               try
                  if Notices[i].List = nil then Notices[i].List := TStringList.Create;
                  Notices[i].List.LoadFromFile (flname);
                  slist.Assign (Notices[i].List);
               except
                  MainOutMessage ('Error in loading notice text. file name is ' + flname);
               end;
               Notices[i].Name := nname;
               Result := TRUE;
            end;
            break;
         end;
      end;
   end;
end;

end.
