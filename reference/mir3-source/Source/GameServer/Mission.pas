unit Mission;

interface

uses
  Windows, Messages, SysUtils, Classes, Graphics, Controls, Dialogs,
  ScktComp, syncobjs, MudUtil, HUtil32, ObjBase, Grobal2,
  Envir, M2Share;

const
   MISSIONBASE = '.\MissionBase\';

type
   TMission = class
      MissionName: string;
      BoPlay: Boolean;  //실행되는 미션인지..
   private
      function LoadMissionFile (flname: string): Boolean;
   public
      constructor Create (mission: string);
      destructor Destroy; override;
      procedure Run;
   end;

implementation


constructor TMission.Create (mission: string);
var
   flname: string;
begin
   inherited Create;
   BoPlay := FALSE;
   MissionName := mission;
   flname := MISSIONBASE + mission + '.txt';
   if FileExists (flname) then
      if LoadMissionFile (flname) then
         BoPlay := TRUE;
end;

destructor TMission.Destroy;
begin
   inherited Destroy;
end;

function TMission.LoadMissionFile (flname: string): Boolean;
var
   strlist: TStringList;
begin
   strlist := TStringList.Create;
   strlist.LoadFromFile (flname);


   strlist.Free;
   
   Result := TRUE;
end;

procedure TMission.Run;
begin
end;

end.
