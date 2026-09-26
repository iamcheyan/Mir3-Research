unit Guild;

interface

uses
  Windows, Messages, SysUtils, Classes, Graphics, Controls, Dialogs,
  ScktComp, syncobjs, MudUtil, HUtil32, Grobal2, Envir, EdCode,
  M2Share, SQLEngn ;

const
   DEFRANK = 99; //문파의 가장 낮은 등급
   GUILDAGIT_DAYUNIT = 7;  //7일
   GUILDAGIT_SALEWAIT_DAYUNIT = 1;  //1일
   MAXGUILDAGITCOUNT = 100;
   GABOARD_NOTICE_LINE = 3;
   GABOARD_COUNT_PER_PAGE = 10;  //장원게시판 1페이지당 라인수.
   GABOARD_MAX_ARTICLE_COUNT = 73;  //장원게시판 최대 게시물 수.
   AGITDECOMONFILE = 'AgitDecoMon.txt';   //장원꾸미기 설치 아이템 리스트 저장.
   MAXCOUNT_DECOMON_PER_AGIT = 50;  //꾸미기 아이템 장원당 최대 설치 개수

   GUILDAGITMAXGOLD = 100000000;

   //문파 장원
   GUILDAGITREGFEE = 10000000;
   GUILDAGITEXTENDFEE = 1000000;

   GUILDWARTIME = 6; //문파전 시간 단위

   {$IFDEF KOREA}
   STR_NOTICE      = '문파공지';
   STR_ENEMYGUILD  = '적대문파';
   STR_ALLIEDGUILD = '동맹문파';
   STR_GUILDMEMBER = '문원들';
   STR_GUILDMASTER = '문주';
   {$ELSE}
   STR_NOTICE      = 'Notice';
   STR_ENEMYGUILD  = 'EnemyGuild';
   STR_ALLIEDGUILD = 'AlliedGuild';
   STR_GUILDMEMBER = 'GuildMember';
   STR_GUILDMASTER = 'GuildChief';
   {$ENDIF}

type
   TGuildRank = record
      Rank: integer;  //순위
      RankName: string;  //직책이름
      MemList: TStringList;  //맴버 리스트
   end;
   PTGuildRank = ^TGuildRank;

   TGuild = class;

   TGuildWarInfo = record
      WarGuild: TGuild;
      WarStartTime: longword;
      WarRemain: longword;
   end;
   PTGuildWarInfo = ^TGuildWarInfo;

   TGuild = class
      GuildName: string;
      NoticeList: TStringList;
      KillGuilds: TStringList;
      AllyGuilds: TStringList;
      MemberList: TList;  //list of PTGuildRank
      MatchPoint: integer;  //문파대전때의 점수
      BoStartGuildFight: Boolean;
      FightMemberList: TStringList; //문파대전시 우리편 리스트
      AllowAllyGuild: Boolean; //동맹 허용 여부
   private
      guildsavetime: longword;
      dosave: Boolean;
      procedure FreeMemberList;
   public
      constructor Create (gname: string);
      destructor Destroy; override;
      function  LoadGuild: Boolean;
      function  LoadGuildFile (flname: string): Boolean;
      procedure BackupGuild (flname: string);
      procedure SaveGuild;
      procedure GuildInfoChange;
      procedure CheckSave;

      function  IsMember (who: string): Boolean;
      function  GetGuildMaster: string;
      function  GetAnotherGuildMaster: string;
      function  AddGuildMaster (who: string): Boolean; //처음에 문파 생성될때만 사용
      function  DelGuildMaster (who: string): Boolean; //마지막 문주나가면 문파 깨짐
      procedure BreakGuild;  //강제로 문파가 없어짐. (주의)
      function  AddMember (who: TObject): Boolean;
      function  DelMember (who: string): Boolean;
      function  MemberLogin (who: TObject; var grank: integer): string;
      procedure MemberLogout (who: TObject);
      procedure MemberNameChanged;
      procedure GuildMsg (str: string; nameexcept: string = '');
      function  UpdateGuildRankStr (rankstr: string): integer;

      function  IsHostileGuild (aguild: TGuild): Boolean;
      function  DeclareGuildWar (aguild: TGuild; currenttime: longword; var backresult: integer): PTGuildWarInfo; //상대방 문파와 문파쌈을 건다.
                                                     //3시간동안 유효, 아무때나 할 수 있다.

      function  IsAllyGuild (aguild: TGuild): Boolean;
      function  IsRushAllyGuild (aguild: TGuild): Boolean;
      function  MakeAllyGuild (aguild: TGuild): Boolean;  //상대방 문파와 동맹을 결성한다.
                                                    //문주끼리 서로 마주보며 할 수 있다.
      function  CanAlly (aguild: TGuild): Boolean;
      function  BreakAlly (aguild: TGuild): Boolean;

      procedure CanceledGuildWar (aguild: TGuild);

      procedure TeamFightStart;
      procedure TeamFightEnd;
      procedure TeamFightAdd (whostr: string);
      procedure TeamFightWhoWinPoint (whostr: string; point: integer);
      procedure TeamFightWhoDead (whostr: string);

      function  GetTotalMemberCount : integer;
   end;


   TGuildManager = class
   private
   public
      GuildList: TList;
      constructor Create;
      destructor Destroy; override;
      procedure ClearGuildList;
      procedure LoadGuildList;
      procedure SaveGuildList;
      function GetGuild (gname: string): TGuild;
      function GetGuildFromMemberName (who: string): TGuild;
      function AddGuild (gname, mastername: string): Boolean;
      function DelGuild (gname: string): Boolean;
      procedure CheckGuildWarTimeOut;
   end;

   {-----------------------------------}
   // 문파장원(sonmg)
   TGuildAgit = class
      GuildAgitNumber : integer; // 장원번호(1-base)
      GuildName : string;        // 문파명
      GuildMasterName : string;  // 문주명
      GuildMasterNameSecond : string;  // 두번째 문주명
      RegistrationTime : string; // 등록일시
      ContractPeriod : integer;  // 계약기간(일)
      GuildAgitTotalGold : integer; // 장원 기부금

      ForSaleFlag : integer;              // 판매 플래그(1,0)
      ForSaleMoney : integer;             // 판매 금액
      ForSaleWait : integer;             // 구입 유예기간(일)
      ForSaleGuildName : string;          // 구입 예정 문파명
      ForSaleGuildMasterName : string;    // 구입 예정 문주명
      ForSaleTime : string;               // 구입 계약일시
   private
      procedure InitGuildAgitRecord;
   public
      constructor Create;
      destructor Destroy; override;
      procedure SetGuildAgitRecord( agitnumber: integer; gname, mastername, regtime: string; period, agittotalgold: integer );
      procedure SetGuildAgitForSaleRecord( saleflag, salemoney, salewait: integer; salegname, salemastername, saletime: string );
      function AddGuildAgitRecord( nextnumber: integer; gname, mastername, secondmastername: string ) : Boolean;
      function GetGuildAgitRemainDateTime : TDateTime;
      procedure ExpulsionMembers;
      function IsExpired : Boolean;
      function GetCurrentDelayStatus : integer;
      function GetGuildAgitRegDateTime : TDateTime;
      function ConvertStringToDatetime( datestring : string ) : TDateTime;
      function ConvertDateTimeToString( datetime : TDateTime ) : string;
      function IsForSale : Boolean;
      function IsSoldOut : Boolean;
      function IsSoldOutExpired : Boolean;
      procedure ResetForSaleFields;
      function ChangeGuildAgitMaster : Boolean;
      function UpdateGuildMaster : string;
   end;

   //-------------------------------
   // 문파장원관리(sonmg)
   TGuildAgitManager = class
      GuildAgitFileVersion : integer;
      ReturnMapName : string;
      ReturnX, ReturnY : integer;
      EntranceX, EntranceY : integer;
      GuildAgitMapName : array [0..3] of string; // 맵이름
   private
   public
      GuildAgitList: TList;
      // 장원꾸미기 오브젝트 리스트(sonmg 2004/06/23)
      AgitDecoMonList: TList;
      // 장원꾸미기 오브젝트 개수
      AgitDecoMonCount: array [1..MAXGUILDAGITCOUNT] of integer;

      constructor Create;
      destructor Destroy; override;
      procedure ClearGuildAgitList;
      procedure LoadGuildAgitList;
      procedure SaveGuildAgitList (bBackup : Boolean);
      function GetGuildAgit (gname: string): TGuildAgit;
      function AddGuildAgit (gname, mastername, secondmastername: string): integer;
      function DelGuildAgit (gname: string): Boolean;
      function GetNextGuildAgitNumber : integer;
      function CheckGuildAgitTimeOut(gaCount : integer) : Boolean;
      function ExtendTime (count : integer; gname : string) : integer;
      function GetRemainDateTime( gname : string ) : TDateTime;
      function GetTradingRemainDate( gname : string ) : integer;
      function IsDelayed( gname : string ) : Boolean;
      function ConvertDatetimeToFileName( datetime : TDateTime ) : string;
      procedure GetGuildAgitSaleList (var salelist: TStringList);
      function IsGuildAgitExpired (gname : string) : Boolean;
      function GuildAgitTradeOk( gname, new_gname, new_mastername: string ) : Boolean;
      function IsExistInForSaleGuild( gname : string ) : Boolean;
      function GetGuildNameFromAgitNum(AgitNum: integer): string;
      function GetGuildMasterNameFromAgitNum(AgitNum: integer): string;
      //장원꾸미기
      function MakeAgitDecoMon : integer;   //장원에 아이템을 젠시킨다.
      function MakeDecoItemToMap( DropMapName: string; ItemName: String; LookIndex, Durability: integer; dx, dy:integer ):integer;
      function DeleteAgitDecoMon(mapname : string; x, y : word) : Boolean;
      function AddAgitDecoMon(item : TAgitDecoItem) : Boolean;
      function UpdateDuraAgitDecoMon(mapname : string; x, y, dura : word) : Boolean;
      function LoadAgitDecoMon: integer;
      procedure SaveAgitDecoMonList;
      function  GetDecoItemName( index : integer; var price : string ) : string;
      function  GetAgitDecoMonCount( agitnum : integer ) : integer;
      procedure IncAgitDecoMonCount( gname : string );
      procedure IncAgitDecoMonCountByAgitNum( agitnum : integer );
      procedure DecAgitDecoMonCount( gname : string );
      procedure DecAgitDecoMonCountByAgitNum( agitnum : integer );
      procedure ArrangeEachAgitDecoMonCount;
      function  IsAvailableDecoMonCount(gname : string) : Boolean;
      function  IsMatchDecoItemInOutdoor( index : integer; mapname : string ) : Boolean;
      function  GetGuildAgitMapFloor( mapname : string ) : integer;
      function  GetGuildAgitNumFromMapName( gmapname : string ) : integer;
      function  DecreaseDecoMonDurability : Boolean;
   end;

   // 장원게시판관리(sonmg)
   TGuildAgitBoardManager = class
   private
      GaBoardList : TList; // List of List
      function GetAllPage( WholeLine: integer ) : integer;
      procedure ConvertNumSeriesToInteger( var NumSeries : string; var OrgNum, SrcNum1, SrcNum2, SrcNum3 : integer );
      function GetNewArticleNumber( gname : string; var OrgNum, SrcNum1, SrcNum2, SrcNum3 : integer ): integer;

   public
      constructor Create;
      destructor Destroy; override;
      function LoadOneGaBoard( uname : string ; nAgitNum : integer ) : Boolean;
      function LoadAllGaBoardList( uname : string ) : Boolean;
      procedure AddGaBoardList( pSearchInfo : PTSearchGaBoardList );
      function GetPageList( uname, gname : string; var nPage, nAllPage : integer; var subjectlist : TStringList ) : Boolean;
      function AddArticle( gname : string; nKind, AgitNum : integer; uname, data : string ) : Boolean;
      function GetArticle( gname : string; NumSeries : string ) : string;
      function DelArticle( gname, uname : string; NumSeries : string ) : Boolean;
      function EditArticle( gname, uname, data : string ) : Boolean;
   end;

implementation

uses
   svMain, ObjBase;


constructor TGuild.Create (gname: string);
begin
   inherited Create;
   GuildName := gname;
   NoticeList := TStringList.Create;
   KillGuilds := TStringList.Create;
   AllyGuilds := TStringList.Create;
   MemberList := TList.Create;
   FightMemberList := TStringList.Create;

   guildsavetime := 0;
   dosave := FALSE;
   MatchPoint := 0;
   BoStartGuildFight := FALSE;
   AllowAllyGuild := FALSE;

end;

destructor TGuild.Destroy;
begin
   NoticeList.Free;
   KillGuilds.Free;
   AllyGuilds.Free;
   FreeMemberList;
   MemberList.Free;
   FightMemberList.Free;
   inherited Destroy;
end;

procedure TGuild.FreeMemberList;
var
   i: integer;
   pgrank: PTGuildRank;
begin
   if MemberList <> nil then begin
      for i:=0 to MemberList.Count-1 do begin
         pgrank := PTGuildRank (MemberList[i]);
         if pgrank.MemList <> nil then begin
            pgrank.MemList.Free;
         end;
         Dispose (pgrank);
      end;
      MemberList.Clear;
   end;
end;

function  TGuild.LoadGuild: Boolean;
begin
   Result := LoadGuildFile (GuildName + '.txt');
end;

function  TGuild.LoadGuildFile (flname: string): Boolean;
var
   i: integer;
   strlist: TStringList;
   str, data, rtstr, rankname: string;
   step, rank: integer;
   pgrank: PTGuildRank;
   pgw: PTGuildWarInfo;
   aguild: TGuild;
begin
   Result := FALSE;
   pgrank := nil;

   if FileExists (GuildDir + flname) then begin

      FreeMemberList;
      NoticeList.Clear;
      for i:=0 to KillGuilds.Count-1 do
         Dispose (PTGuildWarInfo(KillGuilds.Objects[i]));
      KillGuilds.Clear;
      AllyGuilds.Clear;
      step := 0;
      rank := 0;
      rankname := '';

      strlist := TStringList.Create;
      strlist.LoadFromFile (GuildDir + flname);
      for i:=0 to strlist.Count-1 do begin
         str := strlist[i];
         if str <> '' then begin
            if str[1] = ';' then continue;
            if str[1] <> '+' then begin
               if str = STR_NOTICE then step := 1;
               if str = STR_ENEMYGUILD then step := 2;
               if str = STR_ALLIEDGUILD then step := 3;
               if str = STR_GUILDMEMBER then step := 4;
               if str[1] = '#' then begin
                  str := Copy (str, 2, length(str)-1);
                  str := GetValidStr3 (str, data, [',', ' ']);
                  rank := Str_ToInt (data, 0);
                  rankname := Trim(str);
                  pgrank := nil;
               end;
            end else begin
               str := Copy (str, 2, length(str)-1);
               case step of
                  1: begin
                     NoticeList.Add (str);
                  end;
                  2: begin
                     while str <> '' do begin
                        str := GetValidStr3 (str, data, [',', ' ']);
                        str := GetValidStr3 (str, rtstr, [',', ' ']);
                        if data <> '' then begin
                           new (pgw);
                           pgw.WarGuild := GuildMan.GetGuild(data);
                           if pgw.WarGuild <> nil then begin
                              pgw.WarStartTime := GetTickCount;
                              pgw.WarRemain := Str_ToInt(Trim(rtstr), 0);
                              KillGuilds.AddObject (pgw.WarGuild.GuildName, TObject(pgw));
                           end else
                              Dispose (pgw);
                        end else
                           break;
                     end;
                  end;
                  3: begin
                     while str <> '' do begin
                        str := GetValidStr3 (str, data, [',', ' ']);
                        if data <> '' then begin
                           aguild := GuildMan.GetGuild(data);
                           if aguild <> nil then
                              AllyGuilds.AddObject (data, aguild);
                        end else
                           break;
                     end;
                  end;
                  4: begin
                     if (rank > 0) and (rankname <> '') then begin
                        if pgrank = nil then begin
                           new (pgrank);
                           pgrank.Rank := rank;
                           pgrank.RankName := rankname;
                           pgrank.MemList := TStringList.Create;
                           MemberList.Add (pgrank);
                        end;
                        while str <> '' do begin
                           str := GetValidStr3 (str, data, [',', ' ']);
                           if data <> '' then begin
                              pgrank.MemList.Add (data);
                           end else
                              break;
                        end;
                     end;
                  end;
               end;
            end;
         end;
      end;
      strlist.Free;
      Result := TRUE;
   end;
end;

procedure TGuild.BackupGuild (flname: string);
var
   i, k, remain: integer;
   data: string;
   strlist: TStringList;
   pgr: PTGuildRank;
   pgw: PTGuildWarInfo;
begin
   strlist := TStringList.Create;

   strlist.Add (STR_NOTICE);

   for i:=0 to NoticeList.Count-1 do
      strlist.Add ('+' + NoticeList[i]);
   strlist.Add (' ');

   strlist.Add (STR_ENEMYGUILD);
   for i:=0 to KillGuilds.Count-1 do begin
      pgw := PTGuildWarInfo(KillGuilds.Objects[i]);
      remain := pgw.WarRemain - (GetTickCount - pgw.WarStartTime);
      if remain > 0 then
         strlist.Add ('+' + KillGuilds[i] + ' ' + IntToStr(remain));
   end;
   strlist.Add (' ');

   strlist.Add (STR_ALLIEDGUILD);
   for i:=0 to AllyGuilds.Count-1 do
      strlist.Add ('+' + AllyGuilds[i]);
   strlist.Add (' ');

   strlist.Add (STR_GUILDMEMBER);
   for i:=0 to MemberList.Count-1 do begin
      pgr := PTGuildRank (MemberList[i]);
      strlist.Add ('#' + IntTostr(pgr.Rank) + ' ' + pgr.RankName);
      for k:=0 to pgr.MemList.Count-1 do begin
         strlist.Add ('+' + pgr.MemList[k]);
      end;
   end;
   try
      strlist.SaveToFile (flname);
   except
      {$IFDEF KOREA}
      MainOutMessage (flname + ' 저장 오류...');
      {$ELSE}
      MainOutMessage (flname + 'Saving error...');
      {$ENDIF}
   end;
   strlist.Free;
end;

procedure TGuild.SaveGuild;
begin
   if ServerIndex = 0 then begin
      BackupGuild (GuildDir + GuildName + '.txt');
   end else begin
      BackupGuild (GuildDir + GuildName + '.' + IntToStr(ServerIndex));
   end;
end;

procedure TGuild.GuildInfoChange;
begin
   dosave := TRUE;
   guildsavetime := GetTickCount;
   SaveGuild;
end;

procedure TGuild.CheckSave;
begin
   if dosave then begin  //여기서 시간되면 저장함.
      if GetTickCount - guildsavetime > 30*1000 then begin  //변경된지 30초
         dosave := FALSE;
         SaveGuild;
      end;
   end;
end;

function  TGuild.IsMember (who: string): Boolean;
var
   i, k: integer;
   pgrank: PTGuildRank;
begin
   Result := FALSE;
   CheckSave;

   if MemberList <> nil then begin
      for i:=0 to MemberList.Count-1 do begin
         pgrank := PTGuildRank (MemberList[i]);
         for k:=0 to pgrank.MemList.Count-1 do begin
            if pgrank.MemList[k] = who then begin
               Result := TRUE;
               exit;
            end;
         end;
      end;
   end;
end;

function  TGuild.MemberLogin (who: TObject; var grank: integer): string;
var
   i, k: integer;
   pgrank: PTGuildRank;
begin
   Result := '';
   if MemberList <> nil then begin
      for i:=0 to MemberList.Count-1 do begin
         pgrank := PTGuildRank (MemberList[i]);
         for k:=0 to pgrank.MemList.Count-1 do begin
            if pgrank.MemList[k] = TCreature(who).UserName then begin
               pgrank.MemList.Objects[k] := who;
               grank := pgrank.Rank;
               Result := pgrank.RankName;
               TUserHuman(who).UserNameChanged;
               TUserHuman(who).SendMsg (TUserHuman(who), RM_CHANGEGUILDNAME, 0, 0, 0, 0, '');
               exit;
            end;
         end;
      end;
   end;
end;

function  TGuild.GetGuildMaster: string;
var
   i: integer;
begin
   Result := '';
   if MemberList <> nil then begin
      if MemberList.Count > 0 then begin
         if PTGuildRank (MemberList[0]).MemList.Count > 0 then begin
            Result := PTGuildRank (MemberList[0]).MemList[0];
         end;
      end;
   end;
end;

//또 다른 문주.
function  TGuild.GetAnotherGuildMaster: string;
var
   i: integer;
begin
   Result := '';
   if MemberList <> nil then begin
      if MemberList.Count > 0 then begin
         if PTGuildRank (MemberList[0]).MemList.Count >= 2 then begin
            Result := PTGuildRank (MemberList[0]).MemList[1];
         end;
      end;
   end;
end;

function  TGuild.AddGuildMaster (who: string): Boolean;
var
   pgrank: PTGuildRank;
begin
   Result := FALSE;
   if MemberList <> nil then begin
      if MemberList.Count = 0 then begin
         new (pgrank);
         pgrank.Rank := 1;
         pgrank.RankName := STR_GUILDMASTER;
         pgrank.MemList := TStringList.Create;
         pgrank.MemList.Add (who);
         MemberList.Add (pgrank);
         SaveGuild;
         Result := TRUE;
      end;
   end;
end;

function  TGuild.DelGuildMaster (who: string): Boolean;
var
   pgrank: PTGuildRank;
begin
   Result := FALSE;
   //문주 혼자 남았을 경우, 문주 탈퇴면 문파 깨짐..
   if MemberList <> nil then begin
      if MemberList.Count = 1 then begin  //모든 직책을 다 제거한 상태
         pgrank := PTGuildRank (MemberList[0]);
         if pgrank.MemList.Count = 1 then begin
            if pgrank.MemList[0] = who then begin
               BreakGuild;  //문파 깨짐... 모든문원 짤림
               Result := TRUE;
            end;
         end;
      end;
   end;
end;


procedure TGuild.BreakGuild;   //문파 사라짐, //길드에 로그인한 사람들을 문파에서 뺀다.
var
   i, k: integer;
   pgrank: PTGuildRank;
   hum: TUserHuman;
begin
   if ServerIndex = 0 then
      BackupGuild (GuildDir + GuildName + '.' + IntToStr(GetCurrentTime) + '.bak');

   if MemberList <> nil then begin
      for i:=0 to MemberList.Count-1 do begin
         pgrank := PTGuildRank (MemberList[i]);
         for k:=0 to pgrank.MemList.Count-1 do begin
            hum := TUserHuman (pgrank.MemList.Objects[k]);
            if hum <> nil then begin
               hum.MyGuild := nil;
               hum.GuildRankChanged (0, '');
            end;
         end;
         pgrank.MemList.Free;
      end;
      MemberList.Clear;
   end;
   if NoticeList <> nil then
      NoticeList.Clear;
   if KillGuilds <> nil then begin
      for i:=0 to KillGuilds.Count-1 do
         Dispose (PTGuildWarInfo(KillGuilds.Objects[i]));
      KillGuilds.Clear;
   end;

   if AllyGuilds <> nil then
      AllyGuilds.Clear;

   SaveGuild;
end;

function  TGuild.AddMember (who: TObject): Boolean;
var
   i: integer;
   pgrank, drank: PTGuildRank;
begin
   Result := FALSE;
   drank := nil;
   if MemberList <> nil then begin
      for i:=0 to MemberList.Count-1 do begin
         pgrank := PTGuildRank (MemberList[i]);
         if pgrank.Rank = DEFRANK then begin
            drank := pgrank;
            break;
         end;
      end;
      if drank = nil then begin
         new (drank);
         drank.Rank := DEFRANK;
         drank.RankName := STR_GUILDMEMBER;
         drank.MemList := TStringList.Create;
         MemberList.Add (drank);
      end;
      drank.MemList.AddObject (TCreature(who).UserName, who);
      GuildInfoChange;
      Result := TRUE;
   end;
end;

function  TGuild.DelMember (who: string): Boolean;
var
   i, k: integer;
   pgrank: PTGuildRank;
   done: Boolean;
begin
   Result := FALSE;
   done := FALSE;
   if MemberList <> nil then begin
      for i:=0 to MemberList.Count-1 do begin
         pgrank := PTGuildRank (MemberList[i]);
         for k:=0 to pgrank.MemList.Count-1 do begin
            if pgrank.MemList[k] = who then begin
               pgrank.MemList.Delete (k);
               done := TRUE;
               break;
            end;
         end;
         if done then break;
      end;
   end;
   if done then GuildInfoChange;
   Result := done;
end;

procedure TGuild.MemberLogout (who: TObject);
var
   i, k, j: integer;
   pgrank: PTGuildRank;
begin
   if self = nil then exit;   // 2004/04/28(sonmg)

   CheckSave;
   if MemberList <> nil then begin
      for i:=0 to MemberList.Count-1 do begin
         pgrank := PTGuildRank (MemberList[i]);
         for k:=0 to pgrank.MemList.Count-1 do begin
            if pgrank.MemList.Objects[k] = who then begin
               //------------------------------------------
               //적대문파도 함께 저장(sonmg 2005/11/21)
               if TCreature(who).MyGuild <> nil then begin
                  if TGuild(TCreature(who).MyGuild).KillGuilds <> nil then begin
                     for j:=0 to KillGuilds.Count-1 do begin
                        if PTGuildWarInfo(KillGuilds.Objects[j]).WarGuild <> nil then begin
                           PTGuildWarInfo(KillGuilds.Objects[j]).WarGuild.CheckSave;
                        end;
                     end;
                  end;
               end;
               //------------------------------------------
               pgrank.MemList.Objects[k] := nil;
               exit;
            end;
         end;
      end;
   end;
end;

procedure TGuild.MemberNameChanged;
var
   i, k: integer;
   prank: PTGuildRank;
   hum: TUserHuman;
begin
   if MemberList <> nil then begin
      for i:=0 to MemberList.Count-1 do begin
         prank := PTGuildRank(MemberList[i]);
         for k:=0 to prank.MemList.Count-1 do begin
            if prank.MemList.Objects[k] <> nil then begin
               hum := TUserHuman(prank.MemList.Objects[k]);
               hum.UserNameChanged;
            end;
         end;
      end;
   end;
end;

procedure  TGuild.GuildMsg (str: string; nameexcept: string);
var
   i, k: integer;
   prank: PTGuildRank;
   hum: TUserHuman;
begin
   if MemberList <> nil then begin
      for i:=0 to MemberList.Count-1 do begin
         prank := PTGuildRank(MemberList[i]);
         for k:=0 to prank.MemList.Count-1 do begin
            if prank.MemList.Objects[k] <> nil then begin
               hum := TUserHuman(prank.MemList.Objects[k]);
               if hum <> nil then begin
                  //문파전에 관한 메시지이면 이름색 바꾸기(sonmg 2005/10/27)
                  if CompareLStr(str, '***', 3) then
                     hum.ChangeNameColor;
                  //특정 이름 제외
                  if hum.UserName <> nameexcept then begin
                     if hum.BoHearGuildMsg then
                        hum.SendMsg (hum, RM_GUILDMESSAGE, 0, 0, 0, 0, str);
                  end;
               end;
            end;
         end;
      end;
   end;
end;


function  TGuild.UpdateGuildRankStr (rankstr: string): integer;
   procedure FreeMembs (var memb: TList);
   var
      i, k: integer;
   begin
      for i:=0 to memb.Count-1 do begin
         PTGuildRank(memb[i]).MemList.Free;
         Dispose (PTGuildRank(memb[i]));
      end;
      memb.Free;
   end;
var
   nmembs: TList;
   pgr, pgr2: PTGuildRank;
   i, j, k, m, oldcount, newcount: integer;
   data, s1, s2, mname: string;
   flag: Boolean;
   hum: TUserHuman;
begin
   Result := -1;
   //파싱 -> pgr의 리스트로 만든다.
   nmembs := TList.Create;
   pgr := nil;
   while TRUE do begin
      if rankstr = '' then break;
      rankstr := GetValidStr3 (rankstr, data, [#13]);
      data := Trim(data);
      if data <> '' then begin
         if data[1] = '#' then begin
            data := Copy(data, 2, length(data)-1);
            data := GetValidStr3 (data, s1, [' ', '<']);
            data := GetValidStr3 (data, s2, ['<', '>']);
            if pgr <> nil then nmembs.Add (pgr);
            new (pgr);
            pgr.Rank := Str_ToInt (s1, 99);
            pgr.RankName := Trim(s2);
            //직책이 비어있는 경우를 막는다.(sonmg 2004/08/16)
            if pgr.RankName = '' then begin
               Result := -7;
               exit;
            end;
            pgr.MemList := TStringList.Create;
         end else begin
            if pgr <> nil then
               for i:=0 to 9 do begin
                  if data = '' then break;
                  data := GetValidStr3(data, mname, [' ', ',']);
                  if mname <> '' then
                     pgr.MemList.Add (mname);
               end;
         end;
      end;
   end;
   if pgr <> nil then nmembs.Add (pgr);


   //이전 정보와 정확이 같으면 더 이상 처리 안함.
   if MemberList <> nil then begin
      if MemberList.Count = nmembs.Count then begin
         flag := TRUE;
         for i:=0 to MemberList.Count-1 do begin
            pgr  := PTGuildRank(MemberList[i]);
            pgr2 := PTGuildRank(nmembs[i]);
            if (pgr.Rank = pgr2.Rank) and (pgr.RankName = pgr2.RankName) and (pgr.MemList.Count = pgr2.MemList.Count) then begin
               for k:=0 to pgr.MemList.Count-1 do begin
                  if pgr.MemList[k] <> pgr2.MemList[k] then begin
                     flag := FALSE;  //다름
                     break;
                  end;
               end;
            end else begin
               flag := FALSE; //다름
               break;
            end;
         end;
         if flag then begin
            Result := -1;  //이전과 정확히 똑 같음.
            FreeMembs (nmembs);
            exit;
         end;
      end;
   end;


   //문주가 빠져있으면안됨.
   Result := -2;  //문주가 빠져 있음.
   if nmembs.Count > 0 then begin
      if PTGuildRank(nmembs[0]).Rank = 1 then begin
         if PTGuildRank(nmembs[0]).RankName <> '' then begin
            Result := 0; //정상
         end else
            Result := -3; //문주의 명칭이 없음.
      end;
   end;


   //새로 문주가 변경되는 경우, 새로 변경된 사람이 접속하고 있어야 한다.
   //문주의 수는 2명을 초과 못함
   if Result = 0 then begin
      pgr := PTGuildRank(nmembs[0]);
      if pgr.MemList.Count <= 2 then begin
         m := pgr.MemList.Count;
         for i:=0 to pgr.MemList.Count-1 do begin
            if UserEngine.GetUserHuman(pgr.MemList[i]) = nil then begin
               Dec (m);
               break;
            end;
         end;
         if m <= 0 then Result := -5;  //적어도 한명의 문주가 접속하고 있어야 한다.
      end else
         Result := -4; //문주 2명 초과 못함
   end;


   //모든 문원이 추가,삭제 되어 있지 않아야 한다.
   if Result = 0 then begin
      oldcount := 0;
      newcount := 0;
      //새로변경된 리스트와 이전리스트와 비교함
      for i:=0 to MemberList.Count-1 do begin
         pgr := PTGuildRank (MemberList[i]);
         flag := TRUE;
         for j:=0 to pgr.MemList.Count-1 do begin
            flag := FALSE;
            mname := pgr.MemList[j];
            Inc (oldcount);

            for k:=0 to nmembs.Count-1 do begin
               pgr2 := PTGuildRank (nmembs[k]);
               for m:=0 to pgr2.MemList.Count-1 do begin
                  if mname = pgr2.MemList[m] then begin
                     flag := TRUE;
                     break;
                  end;
               end;
               if flag then break;
            end;

            if not flag then begin
               Result := -6; //문원리스트가 일치하지 않음.
               break;
            end;
         end;
         if not flag then break;
      end;

      //다시한번 거꾸로 비교한다.
      for i:=0 to nmembs.Count-1 do begin
         pgr := PTGuildRank (nmembs[i]);
         flag := TRUE;
         for j:=0 to pgr.MemList.Count-1 do begin
            flag := FALSE;
            mname := pgr.MemList[j];
            Inc (newcount);

            for k:=0 to MemberList.Count-1 do begin
               pgr2 := PTGuildRank (MemberList[k]);
               for m:=0 to pgr2.MemList.Count-1 do begin
                  if mname = pgr2.MemList[m] then begin
                     flag := TRUE;
                     break;
                  end;
               end;
               if flag then break;
            end;

            if not flag then begin
               Result := -6; //문원리스트가 일치하지 않음.
               break;
            end;
         end;
         if not flag then break;
      end;

      if Result = 0 then
         if oldcount <> newcount then begin
            Result := -6;  //문원리스트가 일치하지 않음 .
         end;

   end;


   //직책이 중복되지 않았는지 검사.
   if Result = 0 then begin
      for i:=0 to nmembs.Count-1 do begin
         m := PTGuildRank(nmembs[i]).Rank;
         for k:=i+1 to nmembs.Count-1 do begin
            if (m = PTGuildRank(nmembs[k]).Rank) or (m <= 0) or (m > 99) then begin
               Result := -7; //직책 중복
               break;
            end;
         end;
         if Result <> 0 then break;
      end;
   end;


   //변경 -> 접속하고 있는 모든 문원에게 직책과 직책명을 날려준다.
   if Result = 0 then begin
      FreeMembs (MemberList); //완전히 Free시킴
      MemberList := nmembs;
      for i:=0 to MemberList.Count-1 do begin
         pgr := PTGuildRank (MemberList[i]);
         for k:=0 to pgr.MemList.Count-1 do begin
            hum := UserEngine.GetUserHuman (pgr.MemList[k]);
            if hum <> nil then begin
               pgr.MemList.Objects[k] := hum;
               hum.GuildRankChanged (pgr.Rank, pgr.RankName);
            end;
         end;
      end;
      GuildInfoChange;
   end else
      FreeMembs (nmembs);
end;

function  TGuild.IsHostileGuild (aguild: TGuild): Boolean;
var
   i: integer;
begin
   //적대문파인지...
   Result := FALSE;
   for i:=0 to KillGuilds.Count-1 do begin
      if PTGuildWarInfo(KillGuilds.Objects[i]).WarGuild = aguild then begin
         Result := TRUE;
         break;
      end;
   end;
end;

function  TGuild.DeclareGuildWar (aguild: TGuild; currenttime: longword; var backresult: integer): PTGuildWarInfo;
var
   i: integer;
   pgw: PTGuildWarInfo;
   timevalue: longword;
   timeunit: longword;
begin
   Result := nil;
   backresult := 0;
   timevalue := GUILDWARTIME; //시간
   timeunit := 60 * 60 * 1000; //시간 단위
{$IFDEF DEBUG} //문파전 신청 디버깅 모드에서는 시간->분 단위로 테스트...
   timeunit := 60 * 1000; //분 단위
{$ENDIF}
{
   if aguild <> nil then begin
      if not IsAllyGuild (aguild) then begin
         pgw := nil;
         for i:=0 to KillGuilds.Count-1 do begin
            if PTGuildWarInfo(KillGuilds.Objects[i]).WarGuild = aguild then begin
               pgw := PTGuildWarInfo(KillGuilds.Objects[i]);
               if pgw <> nil then begin
                  // 12시간 제한
                  if pgw.WarRemain < 12 * timeunit then begin
                     //문파전 연장 수정(sonmg 2005/08/05)
                     pgw.WarRemain := (pgw.WarStartTime + pgw.WarRemain - currenttime) + 3 * timeunit;
                     pgw.WarStartTime := currenttime;
                     GuildMsg ('***' + aguild.GuildName + '과(와)의 문파전이 3시간 연장되었습니다.(남은 시간 : 약 ' + IntToStr(pgw.WarRemain div timeunit) + '시간)');
                     UserEngine.SendInterMsg (ISM_GUILDMSG, ServerIndex, GuildName + '/' + '***' + aguild.GuildName + '과(와)의 문파전이 3시간 연장되었습니다.(남은 시간 : 약 ' + IntToStr(pgw.WarRemain div timeunit) + '시간)');
                     UserEngine.SendInterMsg (ISM_GUILDWAR, ServerIndex, GuildName + '/' + aguild.GuildName + '/' + IntToStr(pgw.WarStartTime) + '/' + IntToStr(pgw.WarRemain));
                     //서버 로그
                     MainOutMessage('[문파전 연장]' + GuildName + '<->' + aguild.GuildName + '과(와)의 문파전이 3시간 연장되었습니다.(남은 시간 : 약 ' + IntToStr(pgw.WarRemain div timeunit) + '시간)');
                     backresult := 2;  //연장
                     break;
                  end;
               end;
            end;
         end;
         if pgw = nil then begin
            new (pgw);
            pgw.WarGuild := aguild;
            pgw.WarStartTime := currenttime;
            pgw.WarRemain := 3 * timeunit;
            KillGuilds.AddObject (aguild.GuildName, TObject(pgw));
            GuildMsg ('***' + aguild.GuildName + '과(와) 문파전이 시작되었습니다.(3시간)');
            UserEngine.SendInterMsg (ISM_GUILDMSG, ServerIndex, GuildName + '/' + '***' + aguild.GuildName + '과(와) 문파전이 시작되었습니다.(3시간)');
            UserEngine.SendInterMsg (ISM_GUILDWAR, ServerIndex, GuildName + '/' + aguild.GuildName + '/' + IntToStr(pgw.WarStartTime) + '/' + IntToStr(pgw.WarRemain));
            //서버 로그
            MainOutMessage('[문파전 시작]' + GuildName + '<->' + aguild.GuildName + '과(와) 문파전이 시작되었습니다.(3시간)');
            backresult := 1;  //시작
         end;
         Result := pgw;
      end;
   end;
}
   //원래대로 복구(문파전)
   if aguild <> nil then begin
      if not IsAllyGuild (aguild) then begin
         pgw := nil;
         for i:=0 to KillGuilds.Count-1 do begin
            if PTGuildWarInfo(KillGuilds.Objects[i]).WarGuild = aguild then begin
               pgw := PTGuildWarInfo(KillGuilds.Objects[i]);
               //남은 시간이 한시간 이상이면 연장 불가(sonmg 2006/01/18)
               if (pgw.WarStartTime + pgw.WarRemain - currenttime) div timeunit <= 1 then begin
                  pgw.WarStartTime := currenttime;
                  pgw.WarRemain := timevalue * timeunit;
                  GuildMsg ('***' + aguild.GuildName + '과(와) 문파전이 앞으로 '+IntToStr(timevalue)+'시간 동안 연장되었습니다.');
                  backresult := 2;  //연장
                  //서버 로그
//                  MainOutMessage('[문파전 연장]' + GuildName + '<->' + aguild.GuildName + '과(와)의 문파전이 3시간 연장되었습니다.(남은 시간 : 약 ' + IntToStr(pgw.WarRemain div timeunit) + '시간)');
               end else begin
                  backresult := 0;  //실패
               end;
               break;
            end;
         end;
         if pgw = nil then begin
            new (pgw);
            pgw.WarGuild := aguild;
            pgw.WarStartTime := currenttime;
            pgw.WarRemain := timevalue * timeunit;
            KillGuilds.AddObject (aguild.GuildName, TObject(pgw));
            GuildMsg ('***' + aguild.GuildName + '과(와) 문파전이 시작되었습니다.('+IntToStr(timevalue)+'시간)');
            backresult := 1;  //시작
            //서버 로그
//            MainOutMessage('[문파전 시작]' + GuildName + '<->' + aguild.GuildName + '과(와) 문파전이 시작되었습니다.(3시간)');
         end;
         Result := pgw;
      end;
   end;
   MemberNameChanged;
   GuildInfoChange;
end;

procedure TGuild.CanceledGuildWar (aguild: TGuild);
begin
   GuildMsg ('***' + aguild.GuildName + '과(와) 문파전이 종료되었습니다.');
   //서버 로그
   MainOutMessage('[문파전 종료]' + GuildName + '<->' + aguild.GuildName + '과(와) 문파전이 종료되었습니다.');
end;

function  TGuild.IsAllyGuild (aguild: TGuild): Boolean;
var
   i: integer;
begin
   //동맹문파인지...
   Result := FALSE;
   if aguild = nil then exit;
   for i:=0 to AllyGuilds.Count-1 do begin
      if AllyGuilds.Objects[i] = aguild then begin  //
         Result := TRUE;
         exit;
      end;
   end;
end;

//공성문파의 동맹문파인지 확인 새로 추가 (sonmg 2005/11/29)
function  TGuild.IsRushAllyGuild (aguild: TGuild): Boolean;
var
   i, j: integer;
begin
   //공성문파의 동맹문파인지...
   Result := FALSE;
   if aguild = nil then exit;
   for i:=0 to AllyGuilds.Count-1 do begin
      if AllyGuilds.Objects[i] = aguild then begin  //

         for j:=0 to UserCastle.RushGuildList.Count-1 do begin
            if UserCastle.RushGuildList[j] = aguild then begin
               Result := TRUE;
               break;
            end;
         end;

         Result := TRUE;
         exit;
      end;
   end;
end;

function  TGuild.MakeAllyGuild (aguild: TGuild): Boolean;
var
   i: integer;
begin
   Result := FALSE;
   for i:=0 to AllyGuilds.Count-1 do begin
      if AllyGuilds.Objects[i] = aguild then begin  //중복검사
         exit;
      end;
   end;
   AllyGuilds.AddObject (aguild.GuildName, aguild);
   SaveGuild;
end;

function  TGuild.CanAlly (aguild: TGuild): Boolean;
var
   i: integer;
begin
   Result := FALSE;
   for i:=0 to KillGuilds.Count-1 do begin
      if PTGuildWarInfo(KillGuilds.Objects[i]).WarGuild = aguild then begin  //전쟁중이면 동맹을 못한다.
         exit;
      end;
   end;
   Result := TRUE;
end;

function  TGuild.BreakAlly (aguild: TGuild): Boolean;
var
   i: integer;
begin
   Result := FALSE;
   for i:=0 to AllyGuilds.Count-1 do begin
      if TGuild(AllyGuilds.Objects[i]) = aguild then begin  //동맹중이면
         AllyGuilds.Delete (i);
         Result := TRUE;
         break;
      end;
   end;
   SaveGuild;
end;



//문파 대련 관련 함수

procedure TGuild.TeamFightStart;
begin
   MatchPoint := 0;
   BoStartGuildFight := TRUE;
   FightMemberList.Clear;
end;

procedure TGuild.TeamFightEnd;
begin
   BoStartGuildFight := FALSE;
end;

procedure TGuild.TeamFightAdd (whostr: string);
begin
   FightMemberList.Add (whostr);
end;

procedure TGuild.TeamFightWhoWinPoint (whostr: string; point: integer);
var
   i, n: integer;
begin
   if BoStartGuildFight then begin  //문파전 중에만 점수가 올라간다.
      MatchPoint := MatchPoint + point;
      for i:=0 to FightMemberList.Count-1 do
         if FightMemberList[i] = whostr then begin
            n := Integer(FightMemberList.Objects[i]);
            //Loword: dead count, Hiword: win point
            FightMemberList.Objects[i] := TObject(MakeLong(Loword(n), Hiword(n)+point));
         end;
   end;
end;

procedure TGuild.TeamFightWhoDead (whostr: string);
var
   i, n: integer;
begin
   if BoStartGuildFight then begin  //문파전 중에만 기록된다.
      for i:=0 to FightMemberList.Count-1 do
         if FightMemberList[i] = whostr then begin
            n := Integer(FightMemberList.Objects[i]);
            //Loword: dead count, Hiword: win point
            FightMemberList.Objects[i] := TObject(MakeLong(Loword(n)+1, Hiword(n)));
         end;
   end;
end;

function TGuild.GetTotalMemberCount : integer;
var
   i: integer;
begin
   Result := 0;

   // 문주를 포함한 모든 문파원의 수를 알려줌.
   if MemberList <> nil then begin
      for i:=0 to MemberList.Count-1 do begin
         Result := Result + PTGuildRank (MemberList[i]).MemList.Count;
      end;
   end;
end;


{-------------------------------------------------------------------}



constructor TGuildManager.Create;
begin
   inherited Create;
   GuildList := TList.Create;
end;

destructor TGuildManager.Destroy;
begin
   GuildList.Free;
   inherited Destroy;
end;

procedure TGuildManager.ClearGuildList;
var
   i: integer;
begin
   for i:=0 to GuildList.Count-1 do
      TGuild(GuildList[i]).Free;
   GuildList.Clear;
end;

procedure TGuildManager.LoadGuildList;
var
   strlist: TStringList;
   i: integer;
   gname: string;
   guild: TGuild;
begin
   if FileExists (GuildFile) then begin
      strlist := TStringList.Create;
      strlist.LoadFromFile (GuildFile);
      for i:=0 to strlist.Count-1 do begin
         gname := Trim (strlist[i]);
         if gname <> '' then begin
            guild := TGuild.Create (gname);
            GuildList.Add (guild);
         end;
      end;
      strlist.Free;
      for i:=0 to GuildList.Count-1 do begin
         if not TGuild(GuildList[i]).LoadGuild then
            MainOutMessage (TGuild(GuildList[i]).GuildName + ' Information reading failure.');
      end;
      MainOutMessage ('Guild information ' + IntToStr(GuildList.Count) + ' read .');
   end else
      MainOutMessage ('no guild file loaded...');
end;

procedure TGuildManager.SaveGuildList;
var
   strlist: TStringList;
   i: integer;
begin
   if ServerIndex = 0 then begin  //마스터 서버만 저장을 한다.
      strlist := TStringList.Create;
      for i:=0 to GuildList.Count-1 do
         strlist.Add (TGuild(GuildList[i]).GuildName);
      try
         strlist.SaveToFile (GuildFile);
      except
         MainOutMessage (GuildFile + ' 저장 오류...');
      end;
      strlist.Free;
   end;
end;

function TGuildManager.GetGuild (gname: string): TGuild;
var
   i: integer;
begin
   Result := nil;
   for i:=0 to GuildList.Count-1 do begin
      if TGuild(GuildList[i]).GuildName = gname then begin
         Result := TGuild(GuildList[i]);
         break;
      end;
   end;
end;

function TGuildManager.GetGuildFromMemberName (who: string): TGuild;
var
   i: integer;
begin
   Result := nil;
   for i:=0 to GuildList.Count-1 do begin
      if TGuild(GuildList[i]).IsMember (who) then begin
         Result := TGuild(GuildList[i]);
         break;
      end;
   end;
end;

function TGuildManager.AddGuild (gname, mastername: string): Boolean;
var
   guild: TGuild;
begin
   Result := FALSE;
   if IsValidFileName (gname) then begin
      if GetGuild(gname) = nil then begin
         guild := TGuild.Create (gname);
         guild.AddGuildMaster (mastername);
         GuildList.Add (guild);
         SaveGuildList;
         Result := TRUE;
      end;
   end;
end;

function TGuildManager.DelGuild (gname: string): Boolean;
var
   i: integer;
begin
   Result := FALSE;
   for i:=0 to GuildList.Count-1 do begin
      if TGuild(GuildList[i]).GuildName = gname then begin
         if TGuild(GuildList[i]).MemberList.Count <= 1 then begin
            // 장원 반환 후 문파삭제.
            GuildAgitMan.DelGuildAgit( gname );

            TGuild(GuildList[i]).BreakGuild;
            //Guild는 일부러 메모리를 해제하지 않음
            //TGuild(GuildList[i]).Free;  //Free안한 경우 메모리 누적이 생긴다...
            GuildList.Delete (i);
            SaveGuildList;
            Result := TRUE;
         end;
         break;
      end;
   end;
end;

procedure TGuildManager.CheckGuildWarTimeOut;
var
   i, k: integer;
   g: TGuild;
   pgw: PTGuildWarInfo;
   changed: Boolean;
begin
   for i:=0 to GuildList.Count-1 do begin
      g := TGuild(GuildList[i]);
      changed := FALSE;
      for k:=g.KillGuilds.Count-1 downto 0 do begin
         pgw := PTGuildWarInfo(g.KillGuilds.Objects[k]);
         if GetTickCount - pgw.WarStartTime > pgw.WarRemain then begin
            g.CanceledGuildWar (pgw.WarGuild);
            g.KillGuilds.Delete (k);
            Dispose (pgw);
            changed := TRUE;
         end;
      end;
      if changed then
         g.GuildInfoChange;
   end;
end;


{-------------------------------------------------------------------}
// TGuildAgit

constructor TGuildAgit.Create;
begin
   inherited Create;
   InitGuildAgitRecord;
end;

destructor TGuildAgit.Destroy;
begin
   inherited Destroy;
end;

procedure TGuildAgit.InitGuildAgitRecord;
begin
   if self = nil then exit;

   GuildAgitNumber := -1;
   GuildName := '';
   GuildMasterName := '';
   GuildMasterNameSecond := '';
   RegistrationTime := '';
   ContractPeriod := -1;
   GuildAgitTotalGold := 0;

   ForSaleFlag := 0;
   ForSaleMoney := 0;
   ForSaleWait := 0;
   ForSaleGuildName := '';
   ForSaleGuildMasterName := '';
   ForSaleTime := '';
end;

procedure TGuildAgit.SetGuildAgitRecord( agitnumber: integer; gname, mastername, regtime: string; period, agittotalgold: integer );
var
   aguild : TGuild;
begin
   if self = nil then exit;

   GuildAgitNumber := agitnumber;
   GuildName := gname;
   GuildMasterName := mastername;
   GuildMasterNameSecond := '';
   RegistrationTime := regtime;
   ContractPeriod := period;
   GuildAgitTotalGold := agittotalgold;

   // 두번째 문주 얻어 오기.
   aguild := GuildMan.GetGuild(gname);
   if aguild <> nil then begin
      GuildMasterNameSecond := aguild.GetAnotherGuildMaster;
   end;
end;

procedure TGuildAgit.SetGuildAgitForSaleRecord( saleflag, salemoney, salewait: integer; salegname, salemastername, saletime: string );
begin
   if self = nil then exit;

   ForSaleFlag := saleflag;
   ForSaleMoney := salemoney;
   ForSaleWait := salewait;
   ForSaleGuildName := salegname;
   ForSaleGuildMasterName := salemastername;
   ForSaleTime := saletime;
end;

function TGuildAgit.AddGuildAgitRecord( nextnumber: integer; gname, mastername, secondmastername: string ) : Boolean;
var
   RegDateTime : TDateTime;
//   RegDate, RegTime : TDateTime;
//   Year, Month, Day : Word;
//   Hour, Min, Sec, MSec : Word;
begin
   Result := TRUE;

   if self = nil then begin
      Result := FALSE;
      exit;
   end;

   RegDateTime := Now;
   RegistrationTime := ConvertDatetimeToString( RegDateTime );

   GuildAgitNumber := nextnumber;
   GuildName := gname;
   GuildMasterName := mastername;
   GuildMasterNameSecond := secondmastername;
   ContractPeriod := GUILDAGIT_DAYUNIT; //7일(기본단위)
   // 장원 기부금
   GuildAgitTotalGold := 0;
end;

function TGuildAgit.GetGuildAgitRemainDateTime : TDateTime;
var
   regdatetime, regdate, regtime : TDateTime;
//   nowdatetime, nowdate, nowtime : TDateTime;
   enddatetime, enddate, endtime : TDateTime;
   remaindatetime, remaindate, remaintime : TDateTime;
//   str, data: string;
//   Year, Month, Day : Word;
//   Hour, Min, Sec, MSec : Word;
//   RemainSeconds : integer;
begin
   Result := -100;

   if self = nil then exit;

   regdatetime := ConvertStringToDatetime( RegistrationTime );

   // 마감일 계산
{$IFNDEF UNDEF_DEBUG}   //sonmg
   enddatetime := regdatetime + ContractPeriod;
{$ELSE}
   enddatetime := regdatetime + (ContractPeriod/60/24);
{$ENDIF}

   // 남은시간 = 마감일 - 현재시각.
   remaindatetime := enddatetime - Now;

   Result := remaindatetime;
end;

procedure TGuildAgit.ExpulsionMembers;
var
   list: TList;
   cret: TCreature;
   i, j, ix, iy: integer;
   env : TEnvirnoment;
begin
   if self = nil then exit;

   try
      list := TList.Create;
      // 장원 맵 전체 좌표를 검색하여 각 좌표에 있는
      // 모든 유저들을 지정된 장소로 강제 이동시킨다.
      for i := 0 to 3 do begin
         env := GrobalEnvir.GetEnvir( GuildAgitMan.GuildAgitMapName[i] + IntToStr(GuildAgitNumber) );
         if env <> nil then begin
            for ix := 0 to env.MapWidth -1 do begin
               for iy := 0 to env.MapHeight -1 do begin
                  list.Clear;
                  env.GetAllCreature (ix, iy, TRUE, list);

                  for j:=0 to list.Count-1 do begin
                     cret := TCreature(list[j]);
                     if cret <> nil then begin
                        if cret.RaceServer = RC_USERHUMAN then begin
                           //추방.
                           cret.SendRefMsg (RM_SPACEMOVE_HIDE, 0, 0, 0, 0, '');
//                           cret.SpaceMove (GuildAgitMan.ReturnMapName, GuildAgitMan.ReturnX, GuildAgitMan.ReturnY, 0); //공간이동
                           cret.UserSpaceMove (cret.HomeMap, IntToStr(cret.HomeX), IntToStr(cret.HomeY));
                           cret.SysMsg ('장원 기간이 만료되어 추방되었습니다.', 0);
                        end;
                     end;
                  end;
               end;
            end;
         end;
      end;
      list.Free;
   except
      MainOutMessage ('[Exception]TGuildAgit.ExpulsionMembers' );
   end;
end;

function TGuildAgit.IsExpired : Boolean;
begin
   Result := FALSE;

   if self = nil then begin
      Result := TRUE;
      exit;
   end;

{$IFNDEF UNDEF_DEBUG}   //sonmg
   if GetGuildAgitRemainDateTime <= -GUILDAGIT_DAYUNIT then begin
{$ELSE}
   if GetGuildAgitRemainDateTime <= -(GUILDAGIT_DAYUNIT / 60 / 24) then begin
{$ENDIF}
      Result := TRUE;
   end;
end;

function TGuildAgit.GetCurrentDelayStatus : integer;
var
   RemainDateTime : TDateTime;
begin
   //정상상태
   Result := 1;

   if self = nil then begin
      Result := -1;
      exit;
   end;

   RemainDateTime := GetGuildAgitRemainDateTime;

   if RemainDateTime < 0 then begin
      //연체상태
      Result := 0;
{$IFNDEF UNDEF_DEBUG}   //sonmg
      if RemainDateTime <= -GUILDAGIT_DAYUNIT then begin
{$ELSE}
      if RemainDateTime <= -(GUILDAGIT_DAYUNIT / 60 / 24) then begin
{$ENDIF}
         //해제상태
         Result := -1;
      end;
   end;
end;

function TGuildAgit.GetGuildAgitRegDateTime : TDateTime;
var
   regdatetime : TDateTime;
begin
   Result := -100;

   if self = nil then exit;

   regdatetime := ConvertStringToDatetime( RegistrationTime );

   Result := regdatetime;
end;

function TGuildAgit.ConvertStringToDatetime( datestring : string ) : TDateTime;
var
   regdatetime, regdate, regtime : TDateTime;
   str, data : string;
   Year, Month, Day : Word;
   Hour, Min, Sec, MSec : Word;
begin
   Result := -100;

   try
      str := datestring;

      str := GetValidStr3 (str, data, ['.', ':']);
         Year := Str_ToInt (data, 0);
      str := GetValidStr3 (str, data, ['.', ':']);
         Month := Str_ToInt (data, 0);
      str := GetValidStr3 (str, data, ['.', ':']);
         Day := Str_ToInt (data, 0);
      str := GetValidStr3 (str, data, ['.', ':']);
         Hour := Str_ToInt (data, 0);
      str := GetValidStr3 (str, data, ['.', ':']);
         Min := Str_ToInt (data, 0);
      str := GetValidStr3 (str, data, ['.', ':']);
         Sec := Str_ToInt (data, 0);
      str := GetValidStr3 (str, data, ['.', ':']);
         MSec := Str_ToInt (data, 0);

      // 등록일
      regdate := Trunc(EncodeDate(Year, Month, Day));
      regtime := EncodeTime(Hour, Min, Sec, MSec);

      regdatetime := regdate + regtime;

//      ReplaceDate(regdatetime, regdate);
//      ReplaceTime(regdatetime, regtime);

      Result := regdatetime;
   except
      MainOutMessage ('[Exception]TGuildAgit.ConvertStringToDatetime' );
   end;
end;

function TGuildAgit.ConvertDateTimeToString( datetime : TDateTime ) : string;
var
   Year, Month, Day : Word;
   Hour, Min, Sec, MSec : Word;
begin
   Result := '';

   try
      DecodeDate(datetime, Year, Month, Day);
      DecodeTime(datetime, Hour, Min, Sec, MSec);

      Result := IntToStr(Year) + '.' + IntToStr(Month) + '.' + IntToStr(Day) + '.' +
         IntToStr(Hour) + ':' + IntToStr(Min) + ':' + IntToStr(Sec);
   except
      MainOutMessage ('[Exception]TGuildAgit.ConvertDateTimeToString' );
   end;
end;

function TGuildAgit.IsForSale : Boolean;
begin
   Result := FALSE;

   // 플래그가 1이고, 구입신청문파가 없으면 TRUE
   if (ForSaleFlag = 1) and (ForSaleGuildName = '') then begin
      Result := TRUE;
   end;
end;

function TGuildAgit.IsSoldOut : Boolean;
begin
   Result := FALSE;

   // 플래그가 0이고, 구입신청문파가 있으면 거래 성사된 장원
   if (ForSaleFlag = 0) and (ForSaleGuildName <> '') then begin
      Result := TRUE;
   end;
end;

function TGuildAgit.IsSoldOutExpired : Boolean;
var
   SaleDateTime: TDateTime;
begin
   Result := FALSE;

   // 거래가 성사된 장원중에서
   if IsSoldOut then begin
      // 현재 시간이 판매시간 + ForSaleWait 보다 지났으면 Expired
      SaleDateTime := ConvertStringToDatetime(ForSaleTime);
{$IFNDEF UNDEF_DEBUG}   //sonmg
      if Now > SaleDateTime + ForSaleWait then begin
{$ELSE}
      if Now > SaleDateTime + (ForSaleWait / 24 / 60) then begin
{$ENDIF}
         Result := TRUE;
      end;
   end;
end;

procedure TGuildAgit.ResetForSaleFields;
begin
   ForSaleFlag := 0;
   ForSaleMoney := 0;
   ForSaleWait := 0;
   ForSaleGuildName := '';
   ForSaleGuildMasterName := '';
   ForSaleTime := '';
end;

function TGuildAgit.ChangeGuildAgitMaster : Boolean;
var
   RemainDateTime : TDateTime;
   RemainYear, RemainMonth, RemainDay : WORD;
begin
   Result := FALSE;

   if (ForSaleGuildName = '') or (ForSaleGuildMasterName = '') then exit;

   // 이전 장원의 남은 대여기간
   RemainDateTime := GetGuildAgitRemainDateTime;

   // 장원 문파를 새 문파로 교체
   GuildName := ForSaleGuildName;
   // 장원 문주를 새 문주로 교체
   GuildMasterName := ForSaleGuildMasterName;
   GuildMasterNameSecond := '';
   // 등록일 수정(현재시각)
   RegistrationTime := ConvertDateTimeToString(Now);
   // 대여기간 초기화
//   ContractPeriod := GUILDAGIT_DAYUNIT;
   // 대여기간 : 7일 이상 남았으면 7일로 초기화, 7일 이하이면 그대로 유지(?)
   if RemainDateTime <= 0 then begin
      ContractPeriod := 0;
//   end else if RemainDateTime >= GUILDAGIT_DAYUNIT then begin
//      ContractPeriod := GUILDAGIT_DAYUNIT;
   end else begin
      // 남은 기간 반올림
      ContractPeriod := Round(RemainDateTime);
   end;
   // 장원 기부금(초기화? or 그대로 인계?)
   GuildAgitTotalGold := GuildAgitTotalGold;//0;

   Result := TRUE;
end;

function TGuildAgit.UpdateGuildMaster : string;
var
   gname : string;
   aguild: TGuild;
begin
   // 문주를 현재 문주로 최신화시킨다.
   if GuildName <> '' then begin
      aguild := GuildMan.GetGuild( GuildName );
      if aguild <> nil then begin
         GuildMasterName := aguild.GetGuildMaster;
         GuildMasterNameSecond := aguild.GetAnotherGuildMaster;
      end;
   end;
end;


{-------------------------------------------------------------------}
// TGuildAgitManager

constructor TGuildAgitManager.Create;
var
   i : integer;
begin
   inherited Create;

   //파일 버전
   GuildAgitFileVersion := 0;
   //장원 목록
   GuildAgitList := TList.Create;
   //장원꾸미기
   AgitDecoMonList := TList.Create;

   // 기본 맵 이름 초기화.
   GuildAgitMapName[0] := 'GA0';
   GuildAgitMapName[1] := 'GA1';
   GuildAgitMapName[2] := 'GA2';
   GuildAgitMapName[3] := 'GA3';

   // 리턴할 맵, 좌표
   ReturnMapName := '0';
   ReturnX := 333;
   ReturnY := 276;

   // 입구 좌표
   EntranceX := 119;
   EntranceY := 122;

   // 장원꾸미기 오브젝트 개수 초기화
   for i:=1 to MAXGUILDAGITCOUNT do
      AgitDecoMonCount[i] := 0;
end;

destructor TGuildAgitManager.Destroy;
var
   i : integer;
begin
   GuildAgitList.Free;
   //장원꾸미기
   for i:=0 to AgitDecoMonList.Count-1 do
      Dispose(PTAgitDecoItem(AgitDecoMonList[i]));
   AgitDecoMonList.Free;

   inherited Destroy;
end;

procedure TGuildAgitManager.ClearGuildAgitList;
var
   i: integer;
begin
   for i:=0 to GuildAgitList.Count-1 do
      TGuildAgit(GuildAgitList[i]).Free;
   GuildAgitList.Clear;
end;

procedure TGuildAgitManager.LoadGuildAgitList;
var
   strlist: TStringList;
   i: integer;
   str, data: string;
   guildagit: TGuildAgit;

   agitnumber, period : integer;
   gname, mastername, regtime : string;
   saleflag, salemoney, salewait : integer;
   salegname, salemastername, saletime : string;
   agittotalgold : integer;
begin
   agittotalgold := 0;

   if FileExists (GuildAgitFile) then begin
      strlist := TStringList.Create;
      strlist.LoadFromFile (GuildAgitFile);
      for i:=0 to strlist.Count-1 do begin
         str := strlist[i];
         //파일 버전 확인
         if i = 0 then begin
            str := Trim(str);
            if str[1] = '[' then begin
               str := GetValidStr3 (str, data, ['=', '[', ' ', ',', #9]);
               if UPPERCASE(data) = 'VERSION' then begin
                  str := GetValidStr3 (str, data, ['=', '[', ']', ' ', ',', #9]);
                  GuildAgitFileVersion := Str_ToInt (data, 0);
                  continue;
               end;
            end;
         end;
         if str = '' then continue;
         if str[1] = ';' then continue;
         str := GetValidStr3 (str, data, [' ', ',', #9]);
            agitnumber := Str_ToInt (data, 0);

         if data = '' then continue;

         str := GetValidStr3 (str, data, [' ', ',', #9]);
            gname := data;
         str := GetValidStr3 (str, data, [' ', ',', #9]);
            mastername := data;
         str := GetValidStr3 (str, data, [' ', ',', #9]);
            regtime := data;
         str := GetValidStr3 (str, data, [' ', ',', #9]);
            period := Str_ToInt (data, 0);
         // 장원 기부금
         if GuildAgitFileVersion = 1 then begin
            str := GetValidStr3 (str, data, [' ', ',', #9]);
               agittotalgold := Str_ToInt (data, 0);
         end;

         if data = '' then begin
            MainOutMessage ('문파장원 ' + IntToStr(i) + '번째 라인 정보 읽기 오류.');
            continue; //장원 정보 부족.
         end;

         // 구입문파정보
         str := GetValidStr3 (str, data, [' ', ',', #9]);
            saleflag := Str_ToInt (data, 0);
         str := GetValidStr3 (str, data, [' ', ',', #9]);
            salemoney := Str_ToInt (data, -1);
         str := GetValidStr3 (str, data, [' ', ',', #9]);
            salewait := Str_ToInt (data, 0);
         str := GetValidStr3 (str, data, [' ', ',', #9]);
            salegname := data;
         str := GetValidStr3 (str, data, [' ', ',', #9]);
            salemastername := data;
         str := GetValidStr3 (str, data, [' ', ',', #9]);
            saletime := data;

         if agitnumber > -1 then begin
            guildagit := TGuildAgit.Create;
            if guildagit <> nil then begin
               guildagit.SetGuildAgitRecord (agitnumber, gname, mastername, regtime, period, agittotalgold);
               guildagit.SetGuildAgitForSaleRecord (saleflag, salemoney, salewait, salegname, salemastername, saletime);
               GuildAgitList.Add (guildagit)
            end;
         end;
      end;
      strlist.Free;
      MainOutMessage ('문파장원정보 ' + IntToStr(GuildAgitList.Count) + '개 읽었음.');

      // 시작할 때 버전 체크 0이면 1로 올리고 새로 백업 및 저장함
      if GuildAgitFileVersion <= 0 then
         GuildAgitMan.SaveGuildAgitList( TRUE );
   end else
      MainOutMessage ('No guildagit file loaded...');
end;

procedure TGuildAgitManager.SaveGuildAgitList (bBackup : Boolean);
var
   strlist: TStringList;
   i: integer;
begin
   if ServerIndex = 0 then begin  //마스터 서버만 저장을 한다.
      //백업
      if bBackup then begin
         FileCopy( GuildAgitFile, GuildAgitFile + ConvertDatetimeToFileName(Now) );
      end;

      strlist := TStringList.Create;

      //파일 버전 업데이트
      if GuildAgitFileVersion <= 0 then GuildAgitFileVersion := 1;

      //장원 목록 파일 버전 기록
      strlist.Add ('[VERSION=' + IntToStr(GuildAgitFileVersion) + ']');
      //항목 설명
      strlist.Add (';장원번호|문파명|문주명|대여일|잔여일수|기부금|판매중|판매금액|구입유예기간|구입문파명|구입문주명|구입계약일');

      if GuildAgitFileVersion <= 0 then begin
         for i:=0 to GuildAgitList.Count-1 do
            strlist.Add (IntToStr(TGuildAgit(GuildAgitList[i]).GuildAgitNumber) + #9 +
               TGuildAgit(GuildAgitList[i]).GuildName + #9 +
               TGuildAgit(GuildAgitList[i]).GuildMasterName + #9 +
               TGuildAgit(GuildAgitList[i]).RegistrationTime + #9 +
               IntToStr(TGuildAgit(GuildAgitList[i]).ContractPeriod) + #9 +
               // 구입문파 정보
               IntToStr(TGuildAgit(GuildAgitList[i]).ForSaleFlag) + #9 +
               IntToStr(TGuildAgit(GuildAgitList[i]).ForSaleMoney) + #9 +
               IntToStr(TGuildAgit(GuildAgitList[i]).ForSaleWait) + #9 +
               TGuildAgit(GuildAgitList[i]).ForSaleGuildName + #9 +
               TGuildAgit(GuildAgitList[i]).ForSaleGuildMasterName + #9 +
               TGuildAgit(GuildAgitList[i]).ForSaleTime
               );
      end else begin
         for i:=0 to GuildAgitList.Count-1 do
            strlist.Add (IntToStr(TGuildAgit(GuildAgitList[i]).GuildAgitNumber) + #9 +
               TGuildAgit(GuildAgitList[i]).GuildName + #9 +
               TGuildAgit(GuildAgitList[i]).GuildMasterName + #9 +
               TGuildAgit(GuildAgitList[i]).RegistrationTime + #9 +
               IntToStr(TGuildAgit(GuildAgitList[i]).ContractPeriod) + #9 +
               // 장원 기부금
               IntToStr(TGuildAgit(GuildAgitList[i]).GuildAgitTotalGold) + #9 +
               // 구입문파 정보
               IntToStr(TGuildAgit(GuildAgitList[i]).ForSaleFlag) + #9 +
               IntToStr(TGuildAgit(GuildAgitList[i]).ForSaleMoney) + #9 +
               IntToStr(TGuildAgit(GuildAgitList[i]).ForSaleWait) + #9 +
               TGuildAgit(GuildAgitList[i]).ForSaleGuildName + #9 +
               TGuildAgit(GuildAgitList[i]).ForSaleGuildMasterName + #9 +
               TGuildAgit(GuildAgitList[i]).ForSaleTime
               );
      end;

      try
         strlist.SaveToFile (GuildAgitFile);
      except
         MainOutMessage (GuildAgitFile + ' 저장 오류...');
      end;
      strlist.Free;
   end;
end;

function TGuildAgitManager.GetGuildAgit (gname: string): TGuildAgit;
var
   i: integer;
begin
   Result := nil;
   for i:=0 to GuildAgitList.Count-1 do begin
      if TGuildAgit(GuildAgitList[i]).GuildName = gname then begin
         Result := TGuildAgit(GuildAgitList[i]);
         break;
      end;
   end;
end;

// 리턴값 : 장원번호 (-1 이면 Error)
function TGuildAgitManager.AddGuildAgit (gname, mastername, secondmastername: string): integer;
var
   guildagit: TGuildAgit;
   nextnumber: integer;
begin
   Result := -1;
//   if IsValidFileName (gname) then begin   //공백특수문자 차단기능 해제(2004/11/05)
      if GetGuildAgit(gname) = nil then begin
         //문파장원 개수제한.
         if GuildAgitList.Count >= GuildAgitMaxNumber then
            exit;

         guildagit := TGuildAgit.Create;
         nextnumber := GetNextGuildAgitNumber;
         if guildagit.AddGuildAgitRecord( nextnumber, gname, mastername, secondmastername ) then begin
            GuildAgitList.Add (guildagit);
            SaveGuildAgitList (FALSE);
            Result := nextnumber;
         end;
      end;
//   end;
end;

function TGuildAgitManager.DelGuildAgit (gname: string): Boolean;
var
   guildagit: TGuildAgit;
   i, nextnumber: integer;
begin
   Result := FALSE;
   for i:=0 to GuildAgitList.Count-1 do begin
      guildagit := TGuildAgit(GuildAgitList[i]);
      if guildagit <> nil then begin
         if guildagit.GuildName = gname then begin
            //추방.
            guildagit.ExpulsionMembers;

            //Guild는 일부러 메모리를 해제하지 않음(why?)
            guildagit.Free;  //Free안한 경우 메모리 누적이 생긴다...
            GuildAgitList.Delete (i);
            SaveGuildAgitList (TRUE);
            Result := TRUE;
            break;
         end;
      end;
   end;
end;

function TGuildAgitManager.GetNextGuildAgitNumber : integer;
var
   i, j: integer;
begin
   Result := -1;
   if GuildAgitList.Count = 0 then begin
      Result := GuildAgitStartNumber;
      exit;
   end;

   for j:=GuildAgitStartNumber to GuildAgitMaxNumber do begin
      for i:=0 to GuildAgitList.Count-1 do begin
         if TGuildAgit(GuildAgitList[i]).GuildAgitNumber = j then
            break;
      end;
      // 번호가 없으면
      if i = GuildAgitList.Count then begin
         Result := j;
         exit;
      end;
   end;
end;

function TGuildAgitManager.CheckGuildAgitTimeOut(gaCount : integer) : Boolean;
var
   i : integer;
   SaveFlag : Boolean;
   agitnumber : integer;
   guildagit : TGuildAgit;
begin
   Result := FALSE;
   SaveFlag := FALSE;
   agitnumber := -1;
   guildagit := nil;

   // GuildAgitList에서 검사하여
   // 시간이 7일 지난 GuildAgit는 삭제하고
   // 그에 따른 조치(장원 내에 있는 문파원 추방)를 취한다.
   for i := GuildAgitList.Count-1 downto 0 do
   begin
      guildagit := TGuildAgit(GuildAgitList[i]);
      if gaCount = 0 then begin
         //10분에 한번씩
         //해당 문파의 문주가 바뀌었는지 검사하여 최신화 시킨다.
         guildagit.UpdateGuildMaster;
      end;

      // 1분에 한번씩
      // 장원 기부금 - 연체가 되면 현재 기부금을 검사하여 자동 연장 시킨다.
      if guildagit.GetCurrentDelayStatus <= 0 then begin
         if guildagit.GuildAgitTotalGold >= GUILDAGITEXTENDFEE then begin
            agitnumber := GuildAgitMan.ExtendTime( 1, guildagit.GuildName );
            if agitnumber > -1 then begin
               guildagit.GuildAgitTotalGold := guildagit.GuildAgitTotalGold - GUILDAGITEXTENDFEE;

               //로그남김
               AddUserLog ('38'#9 + //장연장_
                           'GUILDAGIT' + ''#9 +
                           '0' + ''#9 +
                           '0' + ''#9 +
                           'AUTOEXTEND' + ''#9 +
                           guildagit.GuildName + ''#9 +
                           IntToStr(agitnumber) + ''#9 +
                           '1'#9 +
                           IntToStr(GUILDAGITEXTENDFEE));

               SaveFlag := TRUE;

               UserEngine.SendInterMsg (ISM_RELOADGUILDAGIT, ServerIndex, '');
            end;
         end;
      end;

      //대여기간이 지난 장원을 삭제하기 전에 먼저 거래 성사된 장원 중에서
      //유예기간이 지난 장원의 주인을 교체한다.
      if guildagit.IsSoldOutExpired then begin
         guildagit.ChangeGuildAgitMaster;
         guildagit.ResetForSaleFields;

         //장원 내 문파원 추방
         guildagit.ExpulsionMembers;

         SaveFlag := TRUE;
         Result := TRUE;
      end;

      //대여기간이 지난 장원을 삭제한다.
      if guildagit.IsExpired then begin
         //장원 내 문파원 추방
         guildagit.ExpulsionMembers;

         //Guild는 일부러 메모리를 해제하지 않음(why?)
         guildagit.Free;  //Free안한 경우 메모리 누적이 생긴다...
         GuildAgitList.Delete (i);
         SaveFlag := TRUE;
         Result := TRUE;
      end;
   end;

   if SaveFlag then
      SaveGuildAgitList (TRUE);

end;

// 리턴값 : 장원번호 (-1 이면 Error)
function TGuildAgitManager.ExtendTime (count : integer; gname : string) : integer;
const
   LIMIT_DAY = 300;
var
   i : integer;
   guildagit : TGuildAgit;
   RegDateTime, NowDateTime : TDateTime;
   BackupFlag : Boolean;
begin
   Result := -1;
   BackupFlag := FALSE;

   // 한 번에 연장할 수 있는 count는 100으로 제한.
   if (count < 1) or (count > 100) then exit;

   // GuildAgit를 얻어온다.
   guildagit := GetGuildAgit( gname );

   if guildagit <> nil then begin
      // 재등록한 시점(현재)이 등록일로부터 300일이 지난 경우에는
      // 등록일자를 기존등록일+300일로 갱신하고
      // 계약기간을 기존계약기간-300일로 갱신한다.
      RegDateTime := guildagit.GetGuildAgitRegDateTime;
      NowDateTime := Now;

      if NowDateTime - RegDateTime > LIMIT_DAY then begin
         if guildagit.ContractPeriod > LIMIT_DAY then begin
            RegDateTime := RegDateTime + LIMIT_DAY;
            guildagit.RegistrationTime := guildagit.ConvertDatetimeToString( RegDateTime );
            guildagit.ContractPeriod := guildagit.ContractPeriod - LIMIT_DAY;
            BackupFlag := TRUE;
         end else begin
            exit;
         end;
      end else begin
         // 대여기간을 365일로 제한.
         if guildagit.ContractPeriod + (count * GUILDAGIT_DAYUNIT) > 365 then exit;
      end;

      // 대여기간을 count 만큼 연장한다.
      guildagit.ContractPeriod := guildagit.ContractPeriod + (count * GUILDAGIT_DAYUNIT);

      SaveGuildAgitList (BackupFlag);
      Result := guildagit.GuildAgitNumber;
   end;
end;

function TGuildAgitManager.GetRemainDateTime( gname : string ) : TDateTime;
var
   guildagit : TGuildAgit;
begin
   Result := -100;

   // GuildAgit를 얻어온다.
   guildagit := GetGuildAgit( gname );
   if guildagit <> nil then
      Result := guildagit.GetGuildAgitRemainDateTime;
end;

//장원 거래 성사되었을 때 남아 있을 대여 기간을 구한다.
function TGuildAgitManager.GetTradingRemainDate( gname : string ) : integer;
var
   guildagit : TGuildAgit;
begin
   Result := -100;

   // GuildAgit를 얻어온다.
   guildagit := GetGuildAgit( gname );
   if guildagit <> nil then
      Result := Round(guildagit.GetGuildAgitRemainDateTime);
end;

function TGuildAgitManager.IsDelayed( gname : string ) : Boolean;
var
   guildagit : TGuildAgit;
begin
   Result := FALSE;

   // GuildAgit를 얻어온다.
   guildagit := GetGuildAgit( gname );
   if guildagit <> nil then begin
      if guildagit.GetCurrentDelayStatus = 0 then
         Result := TRUE;
   end;
end;

function TGuildAgitManager.ConvertDatetimeToFileName( datetime : TDateTime ) : string;
var
   Year, Month, Day : Word;
   Hour, Min, Sec, MSec : Word;
begin
   Result := '.bak';

   DecodeDate(datetime, Year, Month, Day);
   DecodeTime(datetime, Hour, Min, Sec, MSec);

   Result := '.' + IntToStr(Year) + '_' + IntToStr(Month) + '_' + IntToStr(Day) + '_' +
      IntToStr(Hour) + '_' + IntToStr(Min) + '_' + IntToStr(Sec) + '.txt';
end;

procedure TGuildAgitManager.GetGuildAgitSaleList (var salelist: TStringList);
var
   guildagit : TGuildAgit;
   guild : TGuild;
   AnotherGuildMaster : string;
   i : integer;
   RemainDateTime : TDateTime;
   RemainDay : string;
   strStatus, strtemp : string;
begin
   salelist := nil;
   strStatus := '';
   AnotherGuildMaster := '';

   for i:=0 to GuildAgitList.Count-1 do begin
      guildagit := TGuildAgit(GuildAgitList[i]);

      strStatus := '소유';

      // 장원이 판매중이면
      if guildagit.IsForSale then begin
         strStatus := '판매중';
      end else if guildagit.IsSoldOut then begin
         strStatus := '거래성사';
      end;

      if salelist = nil then salelist := TStringList.Create;

      RemainDateTime := guildagit.GetGuildAgitRemainDateTime;
      if RemainDateTime <= 0 then begin
         RemainDay := '연체';
      end else begin
         // 지난 날짜를 소수점 1자리에서 절단.(예 : 10.5일)
         RemainDateTime := Trunc( RemainDateTime * 10 );
         RemainDateTime := RemainDateTime / 10;
         // 남은 날짜로 변환.
         RemainDateTime := GUILDAGIT_DAYUNIT - RemainDateTime;
{$IFNDEF DEBUG}   //sonmg
         RemainDay := FloatToStr( RemainDateTime ) + '일';
{$ELSE}
         RemainDay := FloatToStr( RemainDateTime ) + '분';
{$ENDIF}
      end;

      // 문자열 조합.
      strtemp := IntToStr(guildagit.GuildAgitNumber);
      if Length(strtemp) = 1 then
         strtemp := '0' + strtemp;

      // 또다른 문주가 있는지 검사.
      guild := GuildMan.GetGuild( guildagit.GuildName );
      if guild <> nil then begin
         AnotherGuildMaster := guildagit.GuildMasterNameSecond;   //수정
//         AnotherGuildMaster := guild.GetAnotherGuildMaster;
      end;

      if AnotherGuildMaster = '' then begin
         AnotherGuildMaster := '---';    //또 다른 문주 없음.
      end;

      salelist.Add( strtemp + '/' +
         guildagit.GuildName + '/' + guildagit.GuildMasterName + '/' +
         AnotherGuildMaster + '/' +
         IntToStr(guildagit.ForSaleMoney) + '/' + strStatus
         );
   end;

   // 판매 목록 소트.
   if salelist <> nil then
      salelist.Sort;
end;

function TGuildAgitManager.IsGuildAgitExpired (gname : string) : Boolean;
var
   i : integer;
   guildagit : TGuildAgit;
begin
   Result := FALSE;
   for i:=0 to GuildAgitList.Count-1 do begin
      guildagit := TGuildAgit(GuildAgitList[i]);
      if guildagit <> nil then begin
         if guildagit.GuildName = gname then begin
            if guildagit.IsExpired then begin
               Result := TRUE;
               break;
            end;
         end;
      end;
   end;
end;

function TGuildAgitManager.GuildAgitTradeOk( gname, new_gname, new_mastername: string ) : Boolean;
var
   i : integer;
   guildagit : TGuildAgit;
begin
   Result := FALSE;

   // 정보 오류.
   if (gname = '') or (new_gname = '') or (new_mastername = '') then exit;

   for i:=0 to GuildAgitList.Count-1 do begin
      guildagit := TGuildAgit(GuildAgitList[i]);
      if guildagit <> nil then begin
         if (guildagit.GuildName = gname) and (guildagit.ForSaleFlag = 1) then begin
            guildagit.ForSaleFlag := 0;
            //guildagit.ForSaleMoney := guildagit.ForSaleMoney;   //그대로
            guildagit.ForSaleWait := GUILDAGIT_SALEWAIT_DAYUNIT;
            guildagit.ForSaleGuildName := new_gname;
            guildagit.ForSaleGuildMasterName := new_mastername;
            guildagit.ForSaleTime := guildagit.ConvertDatetimeToString( Now );

            SaveGuildAgitList (TRUE);
            Result := TRUE;
            break;
         end;
      end;
   end;
end;

function TGuildAgitManager.IsExistInForSaleGuild( gname : string ) : Boolean;
var
   i : integer;
   guildagit : TGuildAgit;
begin
   Result := FALSE;

   for i:=0 to GuildAgitList.Count-1 do begin
      guildagit := TGuildAgit(GuildAgitList[i]);
      if guildagit <> nil then begin
         if guildagit.ForSaleGuildName = gname then begin
            Result := TRUE;
            break;
         end;
      end;
   end;
end;

function TGuildAgitManager.GetGuildNameFromAgitNum(AgitNum: integer): string;
var
   i : integer;
   guildagit : TGuildAgit;
begin
   Result := '';

   if AgitNum > -1 then begin
      for i:=0 to GuildAgitList.Count-1 do begin
         guildagit := TGuildAgit(GuildAgitList[i]);
         if guildagit <> nil then begin
            if guildagit.GuildAgitNumber = AgitNum then begin
               Result := guildagit.GuildName;
               break;
            end;
         end;
      end;
   end;
end;

function TGuildAgitManager.GetGuildMasterNameFromAgitNum(AgitNum: integer): string;
var
   i : integer;
   guildagit : TGuildAgit;
begin
   Result := '';

   if AgitNum > -1 then begin
      for i:=0 to GuildAgitList.Count-1 do begin
         guildagit := TGuildAgit(GuildAgitList[i]);
         if guildagit <> nil then begin
            if guildagit.GuildAgitNumber = AgitNum then begin
               Result := guildagit.GuildMasterName;
               break;
            end;
         end;
      end;
   end;
end;

function TGuildAgitManager.MakeAgitDecoMon : integer;
var
   env : TEnvirnoment;
   pmi, pr: PTMapItem;
   i : integer;
   pitem : PTAgitDecoItem;
   count : integer;
begin
   Result := 0;
   count := 0;

   for i:=0 to AgitDecoMonList.Count-1 do begin
      pitem := PTAgitDecoItem(AgitDecoMonList[i]);
      if pitem <> nil then begin
         if MakeDecoItemToMap( pitem.MapName, pitem.Name, pitem.Looks, pitem.Dura, pitem.x, pitem.y ) > 0 then begin
            Inc(count);
         end;
      end;
   end;

   Result := count;
end;

function TGuildAgitManager.MakeDecoItemToMap( DropMapName: string; ItemName: String; LookIndex, Durability: integer; dx, dy:integer ):integer;
var
   ps: PTStdItem;
   newpu: PTUserItem;
   pmi, pr: PTMapItem;
   iTemp: integer;
   dropenvir : TEnvirnoment;
   pricestr : string;
begin
   Result := 0;

   //리스트에 내용이 없으면 에러.
   if DecoItemList.Count <= 0 then exit;

   try
      ps := UserEngine.GetStdItemFromName ( NAME_OF_DECOITEM );

      if ps <> nil then begin
         new (newpu);
         if UserEngine.CopyToUserItemFromName(ps.Name, newpu^) then begin
            //상현주머니 종류 셋팅
            newpu.Dura := LookIndex;
            //상현주머니 내구 셋팅
            newpu.DuraMax := Durability;

            new (pmi);
            pmi.UserItem := newpu^;

            if (ps.StdMode = STDMODE_OF_DECOITEM) and (ps.Shape = SHAPE_OF_DECOITEM) then begin
               //장원꾸미기 - 상현주머니
               pmi.Name := GetDecoItemName(LookIndex, pricestr) + '[' + IntToStr(Round(Durability/1000)) + ']' + '/' + '1';
               pmi.Count := 1;
               pmi.Looks := LookIndex;
               pmi.AniCount := ps.AniCount;
               pmi.Reserved := 0;
               pmi.Ownership := nil;
               pmi.Droptime := GetTickCount;
               pmi.Droper := nil;
            end;

            dropenvir := GrobalEnvir.GetEnvir( DropMapName );
            pr := dropenvir.AddToMap (dx, dy, OS_ITEMOBJECT, TObject(pmi));
            if pr = pmi then begin
               // 결과값이 MakeIndex;
               Result := pmi.useritem.MakeIndex ;

               // 서버로그
               MainOutMessage( '[DecoItemGen] ' + pmi.Name + '(' + IntToStr(dx) + ',' + IntToStr(dy) + ')' );
            end else begin
               //실패인경우
               Dispose (pmi);
            end;
         end;

         if newpu <> nil then Dispose( newpu );   // Memory Leak sonmg
      end;
   except
      MainOutMessage( '[Exception] TGuildAgitManager.MakeDecoItemToMap' );
   end;
end;

//DecoMonList에서 오브젝트를 삭제한다.
function TGuildAgitManager.DeleteAgitDecoMon(mapname : string; x, y : word) : Boolean;
var
   i : integer;
   tempitem : PTAgitDecoItem;
   agitnum : integer;
begin
   Result := FALSE;

   try
      for i := 0 to AgitDecoMonList.Count-1 do begin
         tempitem := PTAgitDecoItem(AgitDecoMonList[i]);
         if tempitem <> nil then begin
            if (tempitem.MapName = mapname) and (tempitem.x = x) and (tempitem.y = y) then begin
               //장원꾸미기 오브젝트 삭제
               AgitDecoMonList.Delete(i);
               //장원꾸미기 오브젝트 개수 감소
               agitnum := GetGuildAgitNumFromMapName( mapname );
               if (agitnum > 0) and (agitnum <= MAXGUILDAGITCOUNT) then begin
                  DecAgitDecoMonCountByAgitNum( agitnum );
               end;
               Result := TRUE;
               break;
            end;
         end;
      end;
   except
      MainOutMessage( '[Exception] TGuildAgitManager.DeleteAgitDecoMon' );
   end;
end;

//DecoMonList에 오브젝트를 추가한다.
function TGuildAgitManager.AddAgitDecoMon(item : TAgitDecoItem) : Boolean;
var
   pitem: PTAgitDecoItem;
begin
   Result := FALSE;

   try
      new (pitem);
      pitem^ := item;     //이름이 없는 아이템은 사라진 아이템임...
      AgitDecoMonList.Add (pitem);

      Result := TRUE;
   except
      MainOutMessage( '[Exception] TGuildAgitManager.AddAgitDecoMon' );
   end;
end;

//DecoMonList에 아이템 내용을 업데이트한다.
function TGuildAgitManager.UpdateDuraAgitDecoMon(mapname : string; x, y, dura : word) : Boolean;
var
   i : integer;
   tempitem : PTAgitDecoItem;
begin
   Result := FALSE;

   try
      for i := 0 to AgitDecoMonList.Count-1 do begin
         tempitem := PTAgitDecoItem(AgitDecoMonList[i]);
         if tempitem <> nil then begin
            if (tempitem.MapName = mapname) and (tempitem.x = x) and (tempitem.y = y) then begin
               tempitem.Dura := dura;
               Result := TRUE;
               break;
            end;
         end;
      end;
   except
      MainOutMessage( '[Exception] TGuildAgitManager.UpdateDuraAgitDecoMon' );
   end;
end;

function  TGuildAgitManager.LoadAgitDecoMon: integer;
var
   i: integer;
   str, flname, decomonname, map, indexstr, xstr, ystr, maker, durastr: string;
//   nx, ny: integer;
   strlist: TStringList;
//   merchant: TMerchant;
//   cret: TCreature;
   item: TAgitDecoItem;
   pitem: PTAgitDecoItem;
begin
   flname := GuildBaseDir + AGITDECOMONFILE;
   if FileExists (flname) then begin
      strlist := TStringList.Create;
      strlist.LoadFromFile (flname);
      for i:=0 to strlist.Count-1 do begin
         str := Trim (strlist[i]);
         if str = '' then continue;
         if str[1] = ';' then continue;
         str := GetValidStr3 (str, decomonname, [' ', #9]);
         str := GetValidStr3 (str, indexstr, [' ', #9]);
         str := GetValidStr3 (str, map, [' ', #9]);
         str := GetValidStr3 (str, xstr, [' ', #9]);
         str := GetValidStr3 (str, ystr, [' ', #9]);

         str := GetValidStrCap (str, maker, [' ', #9]);
         str := GetValidStr3 (str, durastr, [' ', #9]);

         item.Name := Copy(decomonname, 0, 20);
         item.Looks := Str_ToInt(indexstr, 0);
         item.MapName := Copy(map, 0, 14);
         item.x := Str_ToInt(xstr, 0);
         item.y := Str_ToInt(ystr, 0);
         item.Maker := Copy(maker, 0, 14);
         item.Dura := Str_ToInt(durastr, 0);

         new (pitem);
         pitem^ := item;     //이름이 없는 아이템은 사라진 아이템임...
         AgitDecoMonList.Add (pitem);
      end;
      strlist.Free;
   end;
   Result := 1;
end;

procedure TGuildAgitManager.SaveAgitDecoMonList;
var
   strlist: TStringList;
   i: integer;
begin
   if ServerIndex = 0 then begin  //마스터 서버만 저장을 한다.
      strlist := TStringList.Create;
      for i:=0 to AgitDecoMonList.Count-1 do
         strlist.Add (PTAgitDecoItem(AgitDecoMonList[i]).Name + #9 +
            IntToStr(PTAgitDecoItem(AgitDecoMonList[i]).Looks) + #9 +
            PTAgitDecoItem(AgitDecoMonList[i]).MapName + #9 +
            IntToStr(PTAgitDecoItem(AgitDecoMonList[i]).x) + #9 +
            IntToStr(PTAgitDecoItem(AgitDecoMonList[i]).y) + #9 +
            PTAgitDecoItem(AgitDecoMonList[i]).Maker + #9 +
            IntToStr(PTAgitDecoItem(AgitDecoMonList[i]).Dura)
         );
      try
         strlist.SaveToFile (GuildBaseDir + AGITDECOMONFILE);
      except
         MainOutMessage (AGITDECOMONFILE + ' 저장 오류...');
      end;
      strlist.Free;
   end;
end;

function TGuildAgitManager.GetDecoItemName( index : integer; var price : string ) : string;
var
   str, name : string;
begin
   Result := '';
   str := '';

   if index < 0 then exit;
   if DecoItemList.Count <= index then exit;

   str := DecoItemList[index];
   price := GetValidStr3(str, name, ['/']);

   Result := name;
end;

function TGuildAgitManager.GetAgitDecoMonCount( agitnum : integer ) : integer;
begin
   Result := -1;

   if agitnum <= 0 then exit;
   if agitnum > MAXGUILDAGITCOUNT then exit;

   Result := AgitDecoMonCount[agitnum];
end;

procedure TGuildAgitManager.IncAgitDecoMonCount( gname : string );
var
   agitnum : integer;
   guildagit : TGuildAgit;
begin
   guildagit := GetGuildAgit( gname );

   if guildagit <> nil then begin
      agitnum := guildagit.GuildAgitNumber;
      if (agitnum > 0) and (agitnum <= MAXGUILDAGITCOUNT) then begin
         AgitDecoMonCount[agitnum] := AgitDecoMonCount[agitnum] + 1;
      end;
   end;
end;

procedure TGuildAgitManager.IncAgitDecoMonCountByAgitNum( agitnum : integer );
begin
   if (agitnum > 0) and (agitnum <= MAXGUILDAGITCOUNT) then begin
      AgitDecoMonCount[agitnum] := AgitDecoMonCount[agitnum] + 1;
   end;
end;

procedure TGuildAgitManager.DecAgitDecoMonCount( gname : string );
var
   agitnum : integer;
   guildagit : TGuildAgit;
begin
   guildagit := GetGuildAgit( gname );

   if guildagit <> nil then begin
      agitnum := guildagit.GuildAgitNumber;
      if (agitnum > 0) and (agitnum <= MAXGUILDAGITCOUNT) then begin
         AgitDecoMonCount[agitnum] := _MAX(0, AgitDecoMonCount[agitnum] - 1);
      end;
   end;
end;

procedure TGuildAgitManager.DecAgitDecoMonCountByAgitNum( agitnum : integer );
begin
   if (agitnum > 0) and (agitnum <= MAXGUILDAGITCOUNT) then begin
      AgitDecoMonCount[agitnum] := _MAX(0, AgitDecoMonCount[agitnum] - 1);
   end;
end;

procedure TGuildAgitManager.ArrangeEachAgitDecoMonCount;
var
   i, agitnum : integer;
   pitem : PTAgitDecoItem;
begin
   for i:=0 to AgitDecoMonList.Count-1 do begin
      pitem := PTAgitDecoItem(AgitDecoMonList[i]);
      if pitem <> nil then begin
         agitnum := GetGuildAgitNumFromMapName( pitem.MapName );
         if (agitnum > 0) and (agitnum <= MAXGUILDAGITCOUNT) then begin
            IncAgitDecoMonCountByAgitNum( agitnum );
         end;
      end;
   end;
end;

//장원꾸미기 아이템 설치 개수 초과 여부 검사
function TGuildAgitManager.IsAvailableDecoMonCount(gname : string) : Boolean;
var
   guildagit : TGuildAgit;
   decomoncount : integer;
begin
   Result := FALSE;
   decomoncount := -1;

   //장원 총 개수 제한
   if AgitDecoMonList.Count >= 1000 then exit;

   guildagit := GetGuildAgit( gname );
   if guildagit <> nil then begin
      decomoncount := GetAgitDecoMonCount( guildagit.GuildAgitNumber );
      if (decomoncount < 0 ) or (decomoncount >= MAXCOUNT_DECOMON_PER_AGIT) then
         exit;
      Result := TRUE;
   end;
end;

function TGuildAgitManager.IsMatchDecoItemInOutdoor( index : integer; mapname : string ) : Boolean;
var
   kind, floor : integer;
begin
   Result := FALSE;
   kind := -1;
   floor := -1;

   if DecoItemList = nil then exit;
   if (index < 0) or (index >= DecoItemList.Count) then exit;

   // 1:실내, 2:실외, 3:둘다
   kind := Hiword(integer(DecoItemList.Objects[index]));
   floor := GetGuildAgitMapFloor( mapname );

   if (kind = 1) and (floor = 2) then Result := TRUE;
   if (kind = 2) and (floor = 0) then Result := TRUE;
   if (kind = 3) and ((floor = 2) or (floor = 0)) then Result := TRUE;
end;

function TGuildAgitManager.GetGuildAgitMapFloor( mapname : string ) : integer;
begin
   Result := -1;

   if Length(mapname) < 3 then exit;

   //0: 마당, 1,2,3층
   Result := Str_ToInt(mapname[3], -1);
end;

function TGuildAgitManager.GetGuildAgitNumFromMapName( gmapname : string ) : integer;
var
   gname : string;
   agitnumstr : string;
   mapnamelen, agitnum : integer;
begin
   Result := -1;

   mapnamelen := Length(gmapname);
   if mapnamelen <= 3 then exit;

   agitnumstr := Copy(gmapname, 4, mapnamelen - 3);
   agitnum := Str_ToInt(agitnumstr, -1);
   if (agitnum > 0) and (agitnum <= MAXGUILDAGITCOUNT) then begin
      Result := agitnum;
   end;
end;

//장원꾸미기 아이템 내구 감소시킴.
function TGuildAgitManager.DecreaseDecoMonDurability : Boolean;
var
   list: TList;
   cret: TCreature;
   i, j, ix, iy: integer;
   env : TEnvirnoment;
   pm: PTMapInfo;
   pmapitem: PTMapItem;
   inrange : Boolean;
   down, k : integer;
   ObjShape : Byte;
   agitnum : integer;
   pricestr : string;
   ps : PTStdItem;
const
   //(내구 7,000 : 1시간에 40씩 감소 => 일주일이면 6,720감소)
   DEC_DURA = 40;
begin
   Result := FALSE;

   //전체 장원을 검사하여
   //맵에 있는 아이템이 장원꾸미기 아이템이면 내구 감소시킨다.
   //리스트에 업데이트하고
   //리스트를 저장한다.
   try
      list := TList.Create;
      // 장원 맵 전체 좌표를 검색하여 각 좌표에 있는 꾸미기 아이템의 내구를 감소시킨다.
      for i := 0 to 3 do begin
         for agitnum := 1 to GuildAgitMaxNumber do begin
            env := GrobalEnvir.GetEnvir( GuildAgitMapName[i] + IntToStr(agitnum) );
            if env <> nil then begin
               for ix := 0 to env.MapWidth -1 do begin
                  for iy := 0 to env.MapHeight -1 do begin
                     down := 0;
                     //------------------------------------------------------------
                     //장원꾸미기 아이템이 있으면 내구 감소
                     inrange := env.GetMapXY (ix, iy, pm);
                     if inrange then begin
                        if pm.ObjList <> nil then begin
                           k := 0;
                           while TRUE do begin
                              if k >= pm.ObjList.Count then break; //-1 do begin //downto 0 do begin
                              if pm.ObjList[k] <> nil then begin
                                 // Check Object wrong Memory 2003-09-15 PDS
                                 try
                                    // 메모리에서 에러가 있으면 익셉션 걸리구
                                    ObjShape := PTAThing (pm.ObjList[k]).Shape;
                                 except
                                    // 오브젝트에서 빼버리자.
                                    MainOutMessage ('[TGuildAgit.ExpulsionMembers] DELOBJ-WRONG MEMORY:'+ env.MapName + ',' + IntToStr(ix) + ',' + IntToStr(iy));
                                    pm.ObjList.delete(k);
                                    continue;
                                 end;

                                 {item}
                                 down := 6;
                                 if PTAThing (pm.ObjList[k]).Shape = OS_ITEMOBJECT then begin
                                    down := 10;
                                    pmapitem := PTMapItem (PTAThing (pm.ObjList[k]).AObject);
//                                    UpdateVisibleItems (i, j, pmapitem);

                                    //장원꾸미기 아이템인지 확인
                                    ps := UserEngine.GetStdItem(pmapitem.UserItem.Index);
                                    if ps <> nil then begin
                                       if (ps.StdMode = STDMODE_OF_DECOITEM) and (ps.Shape = SHAPE_OF_DECOITEM) then begin
                                          //내구가 DEC_DURA보다 크면 DEC_DURA를 감소시킨다.
                                          if pmapitem.UserItem.DuraMax >= DEC_DURA then begin
                                             pmapitem.UserItem.DuraMax := pmapitem.UserItem.DuraMax - DEC_DURA;
                                             pmapitem.Name := GetDecoItemName(pmapitem.Looks, pricestr) + '[' + IntToStr(Round(pmapitem.UserItem.DuraMax/1000)) + ']' + '/' + '1';
                                             //내구를 감소시키고 저장한다.
                                             if UpdateDuraAgitDecoMon(env.MapName, ix, iy, pmapitem.UserItem.DuraMax) then
                                                SaveAgitDecoMonList;
                                          end else begin
                                             pmapitem.UserItem.DuraMax := 0;
                                          end;

                                          //내구가 0이하이면 없앤다.
                                          if pmapitem.UserItem.DuraMax <= 0 then begin
                                             //리스트에서 삭제하고 저장한다.
                                             if DeleteAgitDecoMon(env.MapName, ix, iy) then
                                                SaveAgitDecoMonList;

                                             //버린지 1시간이 지난건 없앤다. -PDS 잘못될 가능성 있음
                                             // Dispose (PTMapItem (PTAThing (pm.ObjList[k]).AObject));

                                             Dispose (PTAThing(pm.ObjList[k]));
                                             pm.ObjList.Delete(k);
                                             down := 8;
                                             if pm.ObjList.Count <= 0 then begin
                                                down := 9;
                                                pm.ObjList.Free;
                                                pm.ObjList := nil;
                                                break;
                                             end;
                                             continue;
                                          end;

                                          if (pmapitem.Ownership <> nil) or (pmapitem.Droper <> nil) then begin
                                             if GetTickCount - pmapitem.Droptime > ANTI_MUKJA_DELAY then begin
                                                pmapitem.Ownership := nil;
                                                pmapitem.Droper := nil;
                                             end else begin
                                                //{주의} 먹자 보호 시간이 5분(죽은 캐릭 free 유예시간)을 초과하면
                                                //이 부분에서 버그가 발생한다.
                                                if pmapitem.Ownership <> nil then
                                                   if TCreature (pmapitem.Ownership).BoGhost then
                                                      pmapitem.Ownership := nil;
                                                if pmapitem.Droper <> nil then
                                                   if TCreature (pmapitem.Droper).BoGhost then
                                                      pmapitem.Droper := nil;
                                             end;
                                          end;
                                       end;
                                    end;
                                 end;
                              end;

                              Inc (k);

                           end;
                        end;
                     end;
                     //------------------------------------------------------------
                  end;
               end;
            end;
         end;
      end;
      list.Free;
   except
      MainOutMessage ('[Exception]TGuildAgitManager.DecreaseDecoMonDurability' );
   end;

   Result := TRUE;
end;


{-------------------------------------------------------------------}
// TGuildAgitBoardManager(장원게시판)


constructor TGuildAgitBoardManager.Create;
var
   i : integer;
begin
   inherited Create;

   // 장원개수 Overflow 검사
   if GuildAgitMaxNumber > MAXGUILDAGITCOUNT then begin
      MainOutMessage('[Exception] TGuildAgitBoardManager : GuildAgitMaxNumber > MAXGUILDAGITCOUNT');
      exit;
   end;

   GaBoardList := TList.Create;
end;

destructor TGuildAgitBoardManager.Destroy;
var
   i : integer;
begin
   GaBoardList.Free;
   inherited Destroy;
end;

function TGuildAgitBoardManager.LoadOneGaBoard( uname : string ; nAgitNum : integer ) : Boolean;
var
   gname : string;
begin
   Result := FALSE;

   if nAgitNum < 0 then exit;

   gname := GuildAgitMan.GetGuildNameFromAgitNum( nAgitNum );

   if gname = '' then exit;

   SQLEngine.RequestLoadGuildAgitBoard( uname, gname );

   Result := TRUE;
end;

function TGuildAgitBoardManager.LoadAllGaBoardList( uname : string ) : Boolean;
var
   i : integer;
begin
   Result := FALSE;

   //먼저 리스트를 지운다.
   GaBoardList.Clear;

   // DB에서 각 장원별 게시물을 모두 로딩한다.
   for i:=GuildAgitStartNumber to GuildAgitMaxNumber do begin
      LoadOneGaBoard( uname, i );

      Result := TRUE;
   end;
end;

procedure TGuildAgitBoardManager.AddGaBoardList( pSearchInfo : PTSearchGaBoardList );
var
    pSearchList : PTSearchGaBoardList;
    pArticleLoad: PTGaBoardArticleLoad;
    rList       : TList;
    i           : integer;
    ps          : PTStdItem;
    std         : TStdItem;
begin
//    if pInfo.IsOK <> UMRESULT_SUCCESS then Exit;

    if pSearchInfo.ArticleList <> nil then
    begin
        new( pSearchList );
        pSearchList.AgitNum := pSearchInfo.AgitNum;
        pSearchList.GuildName := pSearchInfo.GuildName;
        pSearchList.OrgNum := pSearchInfo.OrgNum;
        pSearchList.SrcNum1 := pSearchInfo.SrcNum1;
        pSearchList.SrcNum2 := pSearchInfo.SrcNum2;
        pSearchList.SrcNum3 := pSearchInfo.SrcNum3;
        pSearchList.Kind := pSearchInfo.Kind;

        rList := TList.Create;

        for i := 0 to pSearchInfo.ArticleList.Count -1 do
        begin
            new( pArticleLoad );
            pArticleLoad.AgitNum := PTGaBoardArticleLoad(pSearchInfo.ArticleList.Items[i]).AgitNum;
            pArticleLoad.GuildName := PTGaBoardArticleLoad(pSearchInfo.ArticleList.Items[i]).GuildName;
            pArticleLoad.OrgNum := PTGaBoardArticleLoad(pSearchInfo.ArticleList.Items[i]).OrgNum;
            pArticleLoad.SrcNum1 := PTGaBoardArticleLoad(pSearchInfo.ArticleList.Items[i]).SrcNum1;
            pArticleLoad.SrcNum2 := PTGaBoardArticleLoad(pSearchInfo.ArticleList.Items[i]).SrcNum2;
            pArticleLoad.SrcNum3 := PTGaBoardArticleLoad(pSearchInfo.ArticleList.Items[i]).SrcNum3;
            pArticleLoad.Kind := PTGaBoardArticleLoad(pSearchInfo.ArticleList.Items[i]).Kind;
            pArticleLoad.UserName := PTGaBoardArticleLoad(pSearchInfo.ArticleList.Items[i]).UserName;
            pArticleLoad.Content := PTGaBoardArticleLoad(pSearchInfo.ArticleList.Items[i]).Content;

            rList.Add( pArticleLoad );
        end;

        pSearchList.ArticleList := rList;

        GaBoardList.Add( pSearchList );

//        MainOutMessage( PTGaBoardArticleLoad(PTSearchGaBoardList(GaBoardList.Items[0]).ArticleList.Items[0]).Content );
//        MainOutMessage('GaBoardList.Count : ' + IntToStr(GaBoardList.Count));
//        MainOutMessage('PTSearchGaBoardList.Count : ' + IntToStr(pSearchList.ArticleList.Count));
    end else begin
//        GaBoardList.Add( nil );
    end;
end;

function TGuildAgitBoardManager.GetAllPage( WholeLine: integer ) : integer;
var
   iTemp : integer;
begin
   if WholeLine <= GABOARD_NOTICE_LINE then begin
      Result := 1;
   end else begin
      // (WholeLine - 4)를 7로 나눈 몫에...
      iTemp := (WholeLine -GABOARD_NOTICE_LINE -1) div (GABOARD_COUNT_PER_PAGE - GABOARD_NOTICE_LINE);
      // 1을 더한 값이 페이지가 됨.
      Result := iTemp + 1;
   end;
end;

procedure TGuildAgitBoardManager.ConvertNumSeriesToInteger( var NumSeries : string; var OrgNum, SrcNum1, SrcNum2, SrcNum3 : integer );
var
   strOrgNum, strSrcNum1, strSrcNum2, strSrcNum3 : string;
begin
   // 초기화.
   OrgNum := 0;
   SrcNum1 := 0;
   SrcNum2 := 0;
   SrcNum3 := 0;

   // 글번호 분리.
   NumSeries := GetValidStr3( NumSeries, strOrgNum, ['/'] );
   if NumSeries = '' then exit;
   NumSeries := GetValidStr3( NumSeries, strSrcNum1, ['/'] );
   if NumSeries = '' then exit;
   NumSeries := GetValidStr3( NumSeries, strSrcNum2, ['/'] );
   if NumSeries = '' then exit;
   NumSeries := GetValidStr3( NumSeries, strSrcNum3, ['/', #0] );

   // 값 입력.
   OrgNum := Str_ToInt( strOrgNum, 0 );
   SrcNum1 := Str_ToInt( strSrcNum1, 0 );
   SrcNum2 := Str_ToInt( strSrcNum2, 0 );
   SrcNum3 := Str_ToInt( strSrcNum3, 0 );
end;

// 새 글 번호를 부여한다.
function TGuildAgitBoardManager.GetNewArticleNumber( gname : string; var OrgNum, SrcNum1, SrcNum2, SrcNum3 : integer ): integer;
var
   i, j, newIndex : integer;
   IndentationFlag : integer;
   pEachSearchBoardList : PTSearchGaBoardList;
   pArticleList : TList;
   pArticleLoad : PTGaBoardArticleLoad;
   newOrgNum, newSrcNum1, newSrcNum2, newSrcNum3 : integer;
begin
   Result := -1;
   newIndex := GABOARD_NOTICE_LINE;

   //장원별 게시판 검색.
   for i:=0 to GaBoardList.Count-1 do begin
      pEachSearchBoardList := PTSearchGaBoardList(GaBoardList.Items[i]);

      // 해당 문파의 게시판 리스트.
      if pEachSearchBoardList.GuildName = gname then begin
         pArticleList := pEachSearchBoardList.ArticleList;
         if pArticleList = nil then continue;

         if (OrgNum <= 0) and (SrcNum1 <= 0) and (SrcNum2 <= 0) and (SrcNum3 <= 0) then begin
            // 원본글 쓰기이면...
            // 최근 공지사항 3개의 번호와 일반글의 첫번째 글 번호 중에서
            // 가장 큰 번호+1로 정한다.
            OrgNum := 0;   // 0으로 초기화.
            for j:=0 to pArticleList.Count-1 do begin
               pArticleLoad := pArticleList.Items[j];
               if pArticleLoad <> nil then begin
                  if OrgNum < pArticleLoad.OrgNum then begin
                     OrgNum := pArticleLoad.OrgNum;
                     SrcNum1 := 0;
                     SrcNum2 := 0;
                     SrcNum3 := 0;
                  end;
                  if j >= GABOARD_NOTICE_LINE then break;
               end;
            end;
            OrgNum := OrgNum + 1; //하나 증가.
            Result := newIndex;
         end else begin
            // 답글 쓰기이면...
            //초기화.
            IndentationFlag := 0;
            newOrgNum := 0;
            newSrcNum1 := 0;
            newSrcNum2 := 0;
            newSrcNum3 := 0;

            // 공지사항 제외.
            if pArticleList.Count <= GABOARD_NOTICE_LINE then begin
               //일반글은 없고 공지사항 밖에 없으면...
               break;
            end else begin
               /////////////////////////////////////////////////////////////
               //해당 원본글을 먼저 찾는다.
               //시작할 들여쓰기 수준(IndentationFlag)을 설정하고
               //그 이후로는 들여쓰기 수준 이전의 글번호가 달라질 때까지 검색 및 값을 대입한다.
               //들여쓰기 수준 이전의 글번호가 달라지면
               //맨 마지막에 대입한 글번호에서 들여쓰기 수준에 해당하는 글번호에 +1을 한다.
               /////////////////////////////////////////////////////////////
               for j:=GABOARD_NOTICE_LINE to pArticleList.Count-1 do begin
                  pArticleLoad := pArticleList.Items[j];
                  if pArticleLoad <> nil then begin
                     //해당 원본글을 찾아서 그 밑에 달려있는 [마지막 답글의 번호+1]을 부여한다.
                     if (pArticleLoad.OrgNum = OrgNum) and (pArticleLoad.SrcNum1 = SrcNum1) and
                           (pArticleLoad.SrcNum2 = SrcNum2) and (pArticleLoad.SrcNum3 = SrcNum3) then begin
                        newOrgNum := pArticleLoad.OrgNum;
                        newSrcNum1 := pArticleLoad.SrcNum1;
                        newSrcNum2 := pArticleLoad.SrcNum2;
                        newSrcNum3 := pArticleLoad.SrcNum3;

                        //답글 깊이 플래그 값 설정.
                        if SrcNum1 = 0 then begin
                           IndentationFlag := 1;
                        end else if SrcNum2 = 0 then begin
                           IndentationFlag := 2;
                        end else if SrcNum3 = 0 then begin
                           IndentationFlag := 3;
                        end else begin
                           IndentationFlag := 3;
                        end;

                        Inc(newIndex);
                        continue;
                     end;

                     if IndentationFlag = 1 then begin
                        if pArticleLoad.OrgNum = OrgNum then begin
                           newOrgNum := pArticleLoad.OrgNum;
                           newSrcNum1 := pArticleLoad.SrcNum1;
                        end else begin
                           break;
                        end;
                     end else if IndentationFlag = 2 then begin
                        if (pArticleLoad.OrgNum = OrgNum) and (pArticleLoad.SrcNum1 = SrcNum1) then begin
                           newOrgNum := pArticleLoad.OrgNum;
                           newSrcNum1 := pArticleLoad.SrcNum1;
                           newSrcNum2 := pArticleLoad.SrcNum2;
                        end else begin
                           break;
                        end;
                     end else if IndentationFlag = 3 then begin
                        if (pArticleLoad.OrgNum = OrgNum) and (pArticleLoad.SrcNum1 = SrcNum1) and
                           (pArticleLoad.SrcNum2 = SrcNum2) then begin
                           newOrgNum := pArticleLoad.OrgNum;
                           newSrcNum1 := pArticleLoad.SrcNum1;
                           newSrcNum2 := pArticleLoad.SrcNum2;
                           newSrcNum3 := pArticleLoad.SrcNum3;
                        end else begin
                           break;
                        end;
                     end;

                     Inc(newIndex);
                  end;
               end;//for

               // 나온 결과로 새 답글 번호 결정.
               if IndentationFlag = 1 then begin
                  OrgNum := newOrgNum;
                  SrcNum1 := newSrcNum1 + 1;
                  SrcNum2 := newSrcNum2;
                  SrcNum3 := newSrcNum3;
               end else if IndentationFlag = 2 then begin
                  OrgNum := newOrgNum;
                  SrcNum1 := newSrcNum1;
                  SrcNum2 := newSrcNum2 + 1;
                  SrcNum3 := newSrcNum3;
               end else if IndentationFlag = 3 then begin
                  OrgNum := newOrgNum;
                  SrcNum1 := newSrcNum1;
                  SrcNum2 := newSrcNum2;
                  SrcNum3 := newSrcNum3 + 1;
               end else begin
                  //해당 원본글이 없으면...(???)
                  OrgNum := newOrgNum + 1;
                  SrcNum1 := 0;
                  SrcNum2 := 0;
                  SrcNum3 := 0;
               end;

               Result := newIndex;
            end;//if
         end;//if
         break;
      end;//if
   end;//for
end;

function TGuildAgitBoardManager.GetPageList( uname, gname : string; var nPage, nAllPage : integer; var subjectlist : TStringList ) : Boolean;
var
   i, j, k : integer;
   pEachSearchBoardList : PTSearchGaBoardList;
   pArticleList : TList;
   pArticleLoad : PTGaBoardArticleLoad;
   subject : string[40];
   StartCount, LastCount : integer;
begin
   Result := FALSE;
   StartCount := 0;
   if nPage <= 0 then
      nPage := 1;

   //해당 문파의 게시판을 한 페이지 읽어옴.
   for i:=0 to GaBoardList.Count-1 do begin
      pEachSearchBoardList := PTSearchGaBoardList(GaBoardList.Items[i]);

      // 해당 문파의 게시판 리스트.
      if pEachSearchBoardList.GuildName = gname then begin
         pEachSearchBoardList.UserName := uname;

         pArticleList := pEachSearchBoardList.ArticleList;
         if pArticleList = nil then continue;

         // 개수가 부족함(최소 3개는 되어야 함).
         if pArticleList.Count < GABOARD_NOTICE_LINE then exit;

         // 공지사항은 무조건 윗줄에 추가.
         for j:=0 to GABOARD_NOTICE_LINE-1 do begin
            pArticleLoad := pArticleList.Items[j];
            if pArticleLoad <> nil then begin
               subject := Copy (pArticleLoad.Content, 0, sizeof(subject));
               subjectlist.Add( pArticleLoad.UserName + '/' +
                  IntToStr(pArticleLoad.OrgNum) + '/' +
                  IntToStr(pArticleLoad.SrcNum1) + '/' + IntToStr(pArticleLoad.SrcNum2) + '/' +
                  IntToStr(pArticleLoad.SrcNum3) + '/' + subject );
            end;
         end;

         nAllPage := GetAllPage(pArticleList.Count);
         StartCount := _MAX(GABOARD_NOTICE_LINE, ((nPage -1) * (GABOARD_COUNT_PER_PAGE -GABOARD_NOTICE_LINE)) + GABOARD_NOTICE_LINE);
         LastCount := _MIN(pArticleList.Count, nPage * GABOARD_COUNT_PER_PAGE);
         for j:=StartCount to LastCount-1 do begin
            pArticleLoad := pArticleList.Items[j];
            if pArticleLoad <> nil then begin
               subject := Copy (pArticleLoad.Content, 0, sizeof(subject));
               subjectlist.Add( pArticleLoad.UserName + '/' +
                  IntToStr(pArticleLoad.OrgNum) + '/' +
                  IntToStr(pArticleLoad.SrcNum1) + '/' + IntToStr(pArticleLoad.SrcNum2) + '/' +
                  IntToStr(pArticleLoad.SrcNum3) + '/' + subject );
               Result := TRUE;
            end;
         end;
         break;
      end;
   end;
end;

function TGuildAgitBoardManager.AddArticle( gname : string; nKind, AgitNum : integer; uname, data : string ) : Boolean;
var
   i, j, newIndex : integer;
   OrgNum, SrcNum1, SrcNum2, SrcNum3 : integer;
   pEachSearchBoardList : PTSearchGaBoardList;
   pArticleList : TList;
   pNewArticleLoad, pArticleLoad : PTGaBoardArticleLoad;
begin
   Result := FALSE;

   ConvertNumSeriesToInteger( data, OrgNum, SrcNum1, SrcNum2, SrcNum3 );

   // 내용이 없으면 글쓰기를 할 수 없음.
   if Trim(data) = '' then exit;

   // 새글번호를 생성한다. 리턴값은 인덱스.
   newIndex := GetNewArticleNumber( gname, OrgNum, SrcNum1, SrcNum2, SrcNum3 );
   if newIndex > 0 then begin
      // 리스트에 새글을 추가한다.
      GetMem (pNewArticleLoad, sizeof(TGaBoardArticleLoad));

      // 읽는 종류 생성
      pNewArticleLoad.AgitNum   := AgitNum;
      pNewArticleLoad.GuildName := gname;
      pNewArticleLoad.OrgNum    := OrgNum;
      pNewArticleLoad.SrcNum1   := SrcNum1;
      pNewArticleLoad.SrcNum2   := SrcNum2;
      pNewArticleLoad.SrcNum3   := SrcNum3;
      pNewArticleLoad.Kind      := nKind;
      pNewArticleLoad.UserName  := uname;
      FillChar(pNewArticleLoad.Content, sizeof(pNewArticleLoad.Content), #0);
      StrPLCopy (pNewArticleLoad.Content, data, sizeof(pNewArticleLoad.Content)-1);

      for i:=0 to GaBoardList.Count-1 do begin
         pEachSearchBoardList := PTSearchGaBoardList(GaBoardList.Items[i]);

         // 해당 문파의 게시판 리스트.
         if pEachSearchBoardList.GuildName = gname then begin
            pEachSearchBoardList.UserName := uname;

            pArticleList := pEachSearchBoardList.ArticleList;
            if pArticleList <> nil then begin
               // 공지사항 쓰기...
               if nKind = KIND_NOTICE then begin
                  // 마지막 공지를 지우고 첫번째 공지에 추가한다.
                  for j:=pArticleList.Count-1 downto 0 do begin
                     pArticleLoad := pArticleList.Items[j];

                     if pArticleLoad <> nil then begin
                        // 공지 마지막 글을 삭제한다.
                        if j = GABOARD_NOTICE_LINE-1 then begin
                           // DB에 삭제 요청.
                           SQLEngine.RequestGuildAgitBoardDelArticle( gname, pArticleLoad.OrgNum, pArticleLoad.SrcNum1, pArticleLoad.SrcNum2, pArticleLoad.SrcNum3, uname );

                           // 리스트에서 삭제.
                           pArticleList.Delete(j);
                           break;
                        end;
                     end;
                  end;

                  newIndex := 0;
                  // 글을 삽입한다.
                  pArticleList.Insert( newIndex, pNewArticleLoad );
               end else if nKind = KIND_GENERAL then begin
                  //게시물 수가 최대 수를 넘으면 가장 오래된 글 삭제 후 추가.
                  if pArticleList.Count >= GABOARD_MAX_ARTICLE_COUNT then begin
                     for j:=pArticleList.Count-1 downto 0 do begin
                        pArticleLoad := pArticleList.Items[j];

                        if pArticleLoad <> nil then begin
                           // 마지막 글을 삭제한다.
                           if j >= GABOARD_MAX_ARTICLE_COUNT-1 then begin
                              // DB에 삭제 요청.
                              SQLEngine.RequestGuildAgitBoardDelArticle( gname, pArticleLoad.OrgNum, pArticleLoad.SrcNum1, pArticleLoad.SrcNum2, pArticleLoad.SrcNum3, uname );

                              // 리스트에서 삭제.(넘어가는 글 모두 삭제)
                              pArticleList.Delete(j);
                           end else begin
                              break;
                           end;
                        end;
                     end;
                  end;

                  // 일반글 추가...
                  // 글을 삽입한다.
                  pArticleList.Insert( newIndex, pNewArticleLoad );
               end else begin
                  exit;
               end;

            end;
         end;
      end;

      // DB에 쓰기 요청한다.
      Result := SQLEngine.RequestGuildAgitBoardAddArticle( gname, OrgNum, SrcNum1, SrcNum2, SrcNum3, nKind, AgitNum, uname, data );
   end;
end;

// 글번호에 해당하는 글의 내용을 읽어온다.
function TGuildAgitBoardManager.GetArticle( gname, NumSeries : string ) : string;
var
   i, j : integer;
   pEachSearchBoardList : PTSearchGaBoardList;
   pArticleList : TList;
   pArticleLoad : PTGaBoardArticleLoad;
   OrgNum, SrcNum1, SrcNum2, SrcNum3 : integer;
begin
   Result := '';

   ConvertNumSeriesToInteger( NumSeries, OrgNum, SrcNum1, SrcNum2, SrcNum3 );

   if OrgNum <= 0 then exit;

   for i:=0 to GaBoardList.Count-1 do begin
      pEachSearchBoardList := PTSearchGaBoardList(GaBoardList.Items[i]);

      // 해당 문파의 게시판 리스트.
      if pEachSearchBoardList.GuildName = gname then begin
         pArticleList := pEachSearchBoardList.ArticleList;

         if pArticleList <> nil then begin
            for j:=0 to pArticleList.Count-1 do begin
               pArticleLoad := pArticleList.Items[j];

               if pArticleLoad <> nil then begin
                  //해당 문파 게시판에 글번호가 같은 글이 있으면...
                  if (pArticleLoad.OrgNum = OrgNum) and (pArticleLoad.SrcNum1 = SrcNum1) and
                        (pArticleLoad.SrcNum2 = SrcNum2) and (pArticleLoad.SrcNum3 = SrcNum3) then begin
                     //글번호/답글번호1/답글번호2/답글번호3/유저이름/내용
                     Result := IntToStr(OrgNum) + '/' + IntToStr(SrcNum1) + '/' +
                        IntToStr(SrcNum2) + '/' + IntToStr(SrcNum3) + '/' +
                        pArticleLoad.UserName + '/' + string(pArticleLoad.Content);
                     exit; //빠져나감.
                  end;
               end;
            end;
            // 결과가 없으면 0으로 변경.
            OrgNum := 0;
            SrcNum1 := 0;
            SrcNum2 := 0;
            SrcNum3 := 0;
            break;
         end;
      end;
   end;
end;

function TGuildAgitBoardManager.DelArticle( gname, uname : string; NumSeries : string ) : Boolean;
var
   i, j : integer;
   OrgNum, SrcNum1, SrcNum2, SrcNum3 : integer;
   pEachSearchBoardList : PTSearchGaBoardList;
   pArticleList : TList;
   pNewArticleLoad, pArticleLoad : PTGaBoardArticleLoad;
begin
   Result := FALSE;

   ConvertNumSeriesToInteger( NumSeries, OrgNum, SrcNum1, SrcNum2, SrcNum3 );

   for i:=0 to GaBoardList.Count-1 do begin
      pEachSearchBoardList := PTSearchGaBoardList(GaBoardList.Items[i]);

      // 해당 문파의 게시판 리스트.
      if pEachSearchBoardList.GuildName = gname then begin
         pArticleList := pEachSearchBoardList.ArticleList;

         if pArticleList <> nil then begin
            for j:=pArticleList.Count-1 downto 0 do begin
               pArticleLoad := pArticleList.Items[j];

               if pArticleLoad <> nil then begin
                  //해당 문파 게시판에 글번호가 같은 글이 있으면 삭제한다.
                  if (pArticleLoad.OrgNum = OrgNum) and (pArticleLoad.SrcNum1 = SrcNum1) and
                        (pArticleLoad.SrcNum2 = SrcNum2) and (pArticleLoad.SrcNum3 = SrcNum3) then begin
                     if pArticleLoad.Kind = KIND_NOTICE then begin
                        //공지 삭제는 삭제후에 마지막 글을 보충한다.
                        //삭제...
                        pArticleList.Delete(j);

                        // 리스트에 새글을 추가한다.
                        GetMem (pNewArticleLoad, sizeof(TGaBoardArticleLoad));

                        // 읽는 종류 생성
                        pNewArticleLoad.AgitNum   := 0;
                        pNewArticleLoad.GuildName := gname;
                        pNewArticleLoad.OrgNum    := 0;
                        pNewArticleLoad.SrcNum1   := 0;
                        pNewArticleLoad.SrcNum2   := 0;
                        pNewArticleLoad.SrcNum3   := 0;
                        pNewArticleLoad.Kind      := KIND_NOTICE;
                        pNewArticleLoad.UserName  := STR_GUILDMASTER;
                        pNewArticleLoad.Content := '문주 공지사항이 비어 있습니다.';

                        pArticleList.Insert( GABOARD_NOTICE_LINE-1, pNewArticleLoad );
                        break;
                     end else begin
                        //삭제...
                        pArticleList.Delete(j);
                        break;
                     end;
                  end;
               end;
            end;
         end;
      end;
   end;

   Result := SQLEngine.RequestGuildAgitBoardDelArticle( gname, OrgNum, SrcNum1, SrcNum2, SrcNum3, uname );
end;

function TGuildAgitBoardManager.EditArticle( gname, uname, data : string ) : Boolean;
var
   i, j : integer;
   OrgNum, SrcNum1, SrcNum2, SrcNum3 : integer;
   pEachSearchBoardList : PTSearchGaBoardList;
   pArticleList : TList;
   pArticleLoad : PTGaBoardArticleLoad;
begin
   Result := FALSE;

   ConvertNumSeriesToInteger( data, OrgNum, SrcNum1, SrcNum2, SrcNum3 );

   // 내용이 없으면 글수정을 할 수 없음.
   if Trim(data) = '' then exit;

   for i:=0 to GaBoardList.Count-1 do begin
      pEachSearchBoardList := PTSearchGaBoardList(GaBoardList.Items[i]);

      // 해당 문파의 게시판 리스트.
      if pEachSearchBoardList.GuildName = gname then begin
         pArticleList := pEachSearchBoardList.ArticleList;

         if pArticleList <> nil then begin
            for j:=pArticleList.Count-1 downto 0 do begin
               pArticleLoad := pArticleList.Items[j];

               if pArticleLoad <> nil then begin
                  //해당 문파 게시판에 글번호가 같은 글이 있으면 삭제한다.
                  if (pArticleLoad.OrgNum = OrgNum) and (pArticleLoad.SrcNum1 = SrcNum1) and
                        (pArticleLoad.SrcNum2 = SrcNum2) and (pArticleLoad.SrcNum3 = SrcNum3) then begin
                     //수정...
                     FillChar(pArticleLoad.Content, sizeof(pArticleLoad.Content), #0);
                     StrPLCopy (pArticleLoad.Content, data, sizeof(pArticleLoad.Content)-1);
                     break;
                  end;
               end;
            end;
         end;
      end;
   end;

   Result := SQLEngine.RequestGuildAgitBoardEditArticle( gname, OrgNum, SrcNum1, SrcNum2, SrcNum3, uname, data );
end;


end.

