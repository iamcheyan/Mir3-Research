unit SqlEngn;

interface

uses
  Windows, Messages, SysUtils, Classes, Graphics, Controls, Dialogs,
  ScktComp, syncobjs, MudUtil, HUtil32, ObjBase, Grobal2,
  M2Share, DBSQL ;

const
   // GAME --> DB
   LOADTYPE_REQGETLIST      = 100;  // 아이템 리스트를 요청한다.
   LOADTYPE_REQBUYITEM      = 101;  // 아이템 사기를 요청한다.
   LOADTYPE_REQSELLITEM     = 102;  // 아이템 등록
   LOADTYPE_REQGETPAYITEM   = 103;  // 동회수
   LOADTYPE_REQCANCELITEM   = 104;  // 내가 등록한 아이템 취소
   LOADTYPE_REQREADYTOSELL  = 105;  // 위탁가능한지 알아보는것
   LOADTYPE_REQCHECKTODB    = 106;  // 아이템 정상 수령 여부저장.

   // DB --> GAME
   LOADTYPE_GETLIST         = 200;  // 아이템 리스트 얻음
   LOADTYPE_BUYITEM         = 201;  // 아이템을 산다.
   LOADTYPE_SELLITEM        = 202;  // 아이템을 등록
   LOADTYPE_GETPAYITEM      = 203;  // 동회수
   LOADTYPE_CANCELITEM      = 204;  // 내가 등록한 아이템 취소
   LOADTYPE_READYTOSELL     = 205;  // 위탁가능한지 알아본다.

   //--------장원게시판(sonmg)--------
   KIND_NOTICE  = 0;
   KIND_GENERAL = 1;
   KIND_ERROR   = 255;

   // GAME --> DB
   GABOARD_REQGETLIST      = 500;   // 장원게시판 리스트 요청.
   GABOARD_REQADDARTICLE   = 501;   // 장원게시판 글쓰기 요청.
   GABOARD_REQDELARTICLE   = 502;   // 장원게시판 글삭제 요청.
   GABOARD_REQEDITARTICLE  = 503;   // 장원게시판 글수정 요청.

   // DB --> GAME
   GABOARD_GETLIST         = 600;   // 장원게시판 리스트 얻음.
   GABOARD_ADDARTICLE      = 601;
   GABOARD_DELARTICLE      = 602;
   GABOARD_EDITARTICLE     = 603;

type
    // 데이터 베이스에서 읽을겨우에 필요한 데이터 정의
    TSqlLoadRecord = record
        loadType    : integer;
        UserName    : string[20];
        pRcd        : pointer;  //
    end;
    PTSqlLoadRecord = ^TSqlLoadRecord;

    // 데이터베이스 실행에 관련된 쓰레드
    TSQLEngine = class(TThread)
    private
        SqlToDBList: TList;
        DbToGameList: TList;

//        SQLock      : TCriticalSection;
        FActive     : Boolean;
        procedure AddToDBList(   pInfo : pTSqlLoadRecord );
        procedure AddToGameList( pInfo : pTSqlLoadRecord );

        // 게임쪽에서 데이터를 가져다 쓰는 부분
        function GetGameExecuteData : pTSqlLoadRecord;

    protected
        procedure Execute; override;

    public
        constructor Create;
        destructor Destroy; override;

        procedure ExecuteSaveCommand;
        function ExecuteLoadCommand : integer;

        //UserMarket (위탁상점)=================================================
        // 아이템 리스트 읽기 요청
        function RequestLoadPageUserMarket(
                  ReqInfo_ : TMarKetReqInfo
                  ):Boolean;
        //아이템등록
        function RequestSellItemUserMarket(
                  UserName: string;
                  pselladd: PTMarketLoad
                  ):Boolean;

        //아이템 위탁 가능한지 검사
        function RequestReadyToSellUserMarket(
                  UserName    : String;
                  MarketName  : String;
                  sellwho     : String
                  ):Boolean;

        // 아이템 사기 요청
        function RequestBuyItemUserMarket(
                  UserName    : string;
                  MarketName  : string;
                  BuyWho      : string;
                  SellIndex   : integer
                  ):Boolean;

        //등록된 아이템 취소
        function RequestCancelSellUserMarket(
                  UserName    : String;
                  MarketName  : String;
                  sellwho     : String;
                  sellindex   : integer
                  ):Boolean;

        //아이템 삭제
        function RequestGetpayUserMarket(
                  UserName    : string;
                  MarketName  : string;
                  sellwho     : string;
                  sellindex   : integer
                  ):Boolean;

        // 아이템의 정상적인 수령여부저장
        procedure CheckToDB(
                  UserName    : string;
                  Marketname  : string;
                  SellWho     : string;
                  MakeIndex_  : integer;
                  SellIndex   : integer;
                  CheckType   : integer
                  );

        //위탁상점 열기 닫기
        procedure Open ( WantOpen : Boolean );

        procedure ExecuteRun ;

        {-----장원게시판-----}
        function RequestLoadGuildAgitBoard( UserName, gname : string ):Boolean;
        function RequestGuildAgitBoardAddArticle( gname : string; OrgNum, SrcNum1, SrcNum2, SrcNum3, nKind, AgitNum : integer; uname, data : string ):Boolean;
        function RequestGuildAgitBoardDelArticle( gname : string; OrgNum, SrcNum1, SrcNum2, SrcNum3 : integer; uname : string ):Boolean;
        function RequestGuildAgitBoardDelAll( gname : string; agitnum : integer; uname : string ):Boolean;
        function RequestGuildAgitBoardEditArticle( gname : string; OrgNum, SrcNum1, SrcNum2, SrcNum3 : integer; uname, data : string ):Boolean;

    end;
var
   SqlEngine   : TSQLEngine;
   g_UMDEBUG : integer;
implementation
uses
   svMain;

constructor TSQLEngine.Create;
begin
   inherited Create (TRUE);
//   FreeOnTerminate := TRUE;

   SqlToDBList := TList.Create;
   DbToGameList := TList.Create;

//   SQLock := TCriticalSection.Create;
   FActive := true;
   g_UMDEBUG := 0;
end;


destructor TSQLEngine.Destroy;
begin
   //메모리 삭제필요
   SqlToDBList.Free;

   //메모리 삭제 필요
   DbToGameList.Free;

//   SQLock.Free;
   inherited Destroy;
end;

procedure TSQLEngine.Open ( WantOpen : Boolean );
begin
   try
      SQLock.Enter;
      FActive := WantOpen;
   finally
      SQLock.Leave;
   end;
end;

procedure TSQLEngine.ExecuteSaveCommand;
begin

end;

function TSQLEngine.ExecuteLoadCommand : integer;
var
   pload       : PTSqlLoadRecord;
   bExit       : boolean;
   pSearchInfo : PTSearchSellItem;
   pLoadInfo   : PTMarketLoad;
   rInfoList   : TList;
   SqlResult   : integer;
   i           : integer;
   pSearchGaBoardList : PTSearchGaBoardList;
   pArticleLoad : PTGaBoardArticleLoad;
   loadtime     : LongWord;
   loadtype     : integer;
begin
   Result := 0;
   bExit := false;
   pLoad := nil;
   while (not bExit) do
   begin
      Result := 1;   //bug result

      try
         if not g_DBSQL.Connected then begin
            g_DBSQL.ReConnect;
            Continue;
         end;
      except
         MainOutMessage('[Exception]ExecuteLoadCommand - g_DBSQL.Connected');
      end;

      Result := 2;   //bug result

      // 명령어 리스트 얻기... 쓰레드 주의 ...
      try
         SQLock.Enter;
         if SQLToDBList <> nil then begin
            if SQLToDBList.count > 0 then begin
               if SQLToDBList.Items[0] = nil then begin
                  {debug code}MainOutMessage('SQLToDBList.Items[0] = nil' + ' [' + IntToStr(g_UMDEBUG) + ']');
               end;
               pLoad := SQLToDBList.Items[0];
               SQLToDBList.Delete(0);
               if g_UMDEBUG = 1000 then begin
                  {debug code}MainOutMessage('SQLToDBList.Delete(0) count:' + IntToStr(SQLToDBList.count) + ' [' + IntToStr(g_UMDEBUG) + ']');
                  g_UMDEBUG := 6;
                  bExit := false;
               end else begin
                  g_UMDEBUG := 2;
                  bExit := false;
               end;
            end else begin
//               {debug code}MainOutMessage('not SQLToDBList.count > 0');
               g_UMDEBUG := 3;
               pLoad := nil;
               bExit := true;
            end;
         end else begin
            if g_UMDEBUG = 1000 then {debug code}MainOutMessage('not SQLToDBList <> nil' + ' [' + IntToStr(g_UMDEBUG) + ']');
            g_UMDEBUG := 4;
            pLoad := nil;
            bExit := true;
         end;
      finally
         SQLock.Leave;
      end;

      Result := 3;   //bug result

      if pLoad <> nil then begin
         loadtime := GetTickCount;
         loadtype := pLoad.loadType;

         if (g_UMDEBUG > 0) and (g_UMDEBUG <> 2) then {debug code}MainOutMessage('[TestCode]ExecuteLoadCommand LoadType : ' + IntToStr(loadtype) + ' [' + IntToStr(g_UMDEBUG) + ']');
         g_UMDEBUG := 5;

         Result := 30000 + loadtype;  //extended bug result

         // 로드 타입에 의해 구별됨
         case pLoad.loadType of
            LOADTYPE_REQGETLIST:
            begin
               g_UMDEBUG := 11;
               Result := 4;   //bug result

               // 포인터 값을 얻어오자..
               pSearchInfo := PTSearchSellItem( pLoad.pRcd );
               g_UMDEBUG := 12;

               if pSearchInfo <> nil then begin
                  // 리스틀 하나 만든다음에.
                  rInfoList   := TList.Create;

                  g_UMDEBUG := 21;

                  if g_DBSql = nil then MainOutMessage('[Exception] g_DBSql = nil');

                  // 값을 읽어오자. 직접 SQL  에서 읽어오는부분(이 부분에서 오류나는 것 같음)
                  SqlResult := g_DBSql.LoadPageUserMarket(
                               pSearchInfo.MarketName,
                               pSearchInfo.Who,
                               pSearchInfo.ItemName,
                               pSearchInfo.ItemType,
                               pSearchInfo.ItemSet,
                               rInfoList
                               );

                  if rInfoList = nil then MainOutMessage('[Exception] rInfoList = nil');
                  g_UMDEBUG := 22;

                  // 리스트 얻은값을 넘겨주고
                  pSearchInfo.IsOK  := SqlResult;
                  pSearchInfo.pList := rInfoList;

                  g_UMDEBUG := 23;

                  // 리스트에 해당하는 포인트은 없에주고
                  rInfoList := nil;

                  g_UMDEBUG := 24;

                  // 살짝 타입만 바꾸고..
                  pLoad.loadType := LOADTYPE_GETLIST;

                  g_UMDEBUG := 13;

                  // 게임쪽에서 사용할수 있게 등록한후에
                  AddToGameList( pLoad );
                  // 읽은값은 없애준다.
                  pSearchInfo := nil;
                  pLoad := nil;

                  g_UMDEBUG := 14;
               end else begin
                  if g_UMDEBUG > 0 then {debug code}MainOutMessage('[TestCode]ExecuteLoadCommand : pSearchInfo = nil' + IntToStr(loadtype) + ' [' + IntToStr(g_UMDEBUG) + ']');
                  g_UMDEBUG := 15;
               end;

            end;
            LOADTYPE_REQBUYITEM:
            begin
               Result := 5;   //bug result

               g_UMDEBUG := 25;

               pLoadInfo := PTMarketLoad( pLoad.pRcd );
               if pLoadInfo <> nil then begin
                  SqlResult := g_DBSql.BuyOneUserMarket(pLoadInfo );
                  PLoadInfo.IsOK := SqlResult;
                  pLoad.loadType := LOADTYPE_BUYITEM;
                  AddToGameList( pLoad );
                  pLoadInfo := nil;
                  pLoad     := nil;
               end;

            end;
            LOADTYPE_REQSELLITEM:
            begin
               Result := 6;   //bug result

               g_UMDEBUG := 16;

               pLoadInfo := PTMarketLoad( pLoad.pRcd );
               if pLoadInfo <> nil then begin
                  g_UMDEBUG := 17;

                  SqlResult := g_DBSql.AddSellUserMarket( pLoadInfo );
                  PLoadInfo.IsOK := SqlResult;
                  pLoad.loadType := LOADTYPE_SELLITEM;
                  AddToGameList( pLoad );
                  pLoadInfo := nil;
                  pLoad     := nil;

                  g_UMDEBUG := 18;
               end else begin
                  g_UMDEBUG := 19;
               end;

            end;
            LOADTYPE_REQREADYTOSELL:
            begin
               Result := 7;   //bug result

               g_UMDEBUG := 26;

               pLoadInfo := PTMarketLoad( pLoad.pRcd );

               g_UMDEBUG := 30;

               if pLoadInfo <> nil then begin
                  SqlResult := g_DBSql.ReadyToSell( pLoadInfo );
                  PLoadInfo.IsOK := SqlResult;
                  pLoad.loadType := LOADTYPE_READYTOSELL;
                  AddToGameList( pLoad );
                  pLoadInfo := nil;
                  pLoad     := nil;
               end;

               g_UMDEBUG := 31;

            end;
            LOADTYPE_REQCANCELITEM:
            begin
               Result := 8;   //bug result

               g_UMDEBUG := 27;

               pLoadInfo := PTMarketLoad( pLoad.pRcd );
               if pLoadInfo <> nil then begin
                  SqlResult := g_DBSql.CancelUserMarket(pLoadInfo );
                  PLoadInfo.IsOK := SqlResult;
                  pLoad.loadType := LOADTYPE_CANCELITEM;
                  AddToGameList( pLoad );
                  pLoadInfo := nil;
                  pLoad     := nil;
               end;

            end;
            LOADTYPE_REQGETPAYITEM:
            begin
               Result := 9;   //bug result

               g_UMDEBUG := 28;

               pLoadInfo := PTMarketLoad( pLoad.pRcd );
               if pLoadInfo <> nil then begin
                  SqlResult := g_DBSql.GetPayUserMarket(pLoadInfo );
                  PLoadInfo.IsOK := SqlResult;
                  pLoad.loadType := LOADTYPE_GETPAYITEM;
                  AddToGameList( pLoad );
                  pLoadInfo := nil;
                  pLoad     := nil;
               end;
            end;

            LOADTYPE_REQCHECKTODB:
            begin
               Result := 10;   //bug result

               g_UMDEBUG := 29;

               pSearchInfo := PTSearchSellItem( pLoad.pRcd );
               if pSearchInfo <> nil then begin
                   case pSearchInfo.CheckType of
                   MARKET_CHECKTYPE_SELLOK://위탁 정상
                       begin
                       g_DBSql.ChkAddSellUserMarket( pSearchInfo , true);
                       end;
                   MARKET_CHECKTYPE_SELLFAIL://위탁 실패
                       begin
                       g_DBSql.ChkAddSellUserMarket( pSearchInfo , false);
                       end;
                   MARKET_CHECKTYPE_BUYOK://구입 정상
                       begin
                       g_DBSql.ChkBuyOneUserMarket( pSearchInfo , true);
                       end;
                   MARKET_CHECKTYPE_BUYFAIL://구입 실패
                       begin
                       g_DBSql.ChkBuyOneUserMarket( pSearchInfo , false);
                       end;
                   MARKET_CHECKTYPE_CANCELOK://취소 정상
                       begin
                       g_DBSql.ChkCancelUserMarket( pSearchInfo , true);
                       end;
                   MARKET_CHECKTYPE_CANCELFAIL://취소 실패
                       begin
                       g_DBSql.ChkCancelUserMarket( pSearchInfo , false);
                       end;
                   MARKET_CHECKTYPE_GETPAYOK://돈 회수 정상
                       begin
                       g_DBSql.ChkGetPayUserMarket( pSearchInfo , true);
                       end;
                   MARKET_CHECKTYPE_GETPAYFAIL://돈 회수 실패
                       begin
                       g_DBSql.ChkGetPayUserMarket( pSearchInfo , false);
                       end;
                   end;

                   FreeMem ( pSearchInfo );
                   pSearchInfo := nil;
               end;


            end;
            //------------------------------------------
            // 장원게시판 목록...
            GABOARD_REQGETLIST:
            begin
               Result := 11;   //bug result

               // 포인터 값을 얻어오자..
               pSearchGaBoardList := PTSearchGaBoardList( pLoad.pRcd );

               if pSearchGaBoardList <> nil then
               begin
                 // 리스트틀 하나 만든다음에.
                 rInfoList   := TList.Create;
                 // 값을 읽어오자. 직접 SQL에서 읽어오는부분
                 SqlResult := g_DBSql.LoadPageGaBoardList(
                               pSearchGaBoardList.GuildName,
                               pSearchGaBoardList.Kind,
                               rInfoList
                               );

                 // 리스트 얻은값을 넘겨주고
                 pSearchGaBoardList.ArticleList := rInfoList;
                 // 리스트에 해당하는 포인터는 없애주고
                 rInfoList := nil;
                 // 살짝 타입만 바꾸고..
                 pLoad.loadType := GABOARD_GETLIST;
                 // 게임쪽에서 사용할수 있게 등록한후에
                 AddToGameList( pLoad );
                 // 읽은 값은 없애준다.
                 pSearchGaBoardList := nil;
                 pLoad := nil;
               end;
            end;
            GABOARD_REQADDARTICLE:
            begin
               Result := 12;   //bug result

               // 포인터 값을 얻어오자..
               pArticleLoad := PTGaBoardArticleLoad( pLoad.pRcd );

               // 유저이름 복사.
               pArticleLoad.UserName := pLoad.UserName;

               if pArticleLoad <> nil then
               begin
                 // 값을 읽어오자. 직접 SQL에서 읽어오는부분
                 SqlResult := g_DBSql.AddGaBoardArticle( pArticleLoad );

                 // 살짝 타입만 바꾸고..
                 pLoad.loadType := GABOARD_ADDARTICLE;
                 // 게임쪽에서 사용할수 있게 등록한후에
                 AddToGameList( pLoad );
                 // 읽은 값은 없애준다.
                 pArticleLoad := nil;
                 pLoad := nil;
               end;
            end;
            GABOARD_REQDELARTICLE:
            begin
               Result := 13;   //bug result

               // 포인터 값을 얻어오자..
               pArticleLoad := PTGaBoardArticleLoad( pLoad.pRcd );

               // 유저이름 복사.
               pArticleLoad.UserName := pLoad.UserName;

               if pArticleLoad <> nil then
               begin
                 // 값을 읽어오자. 직접 SQL에서 읽어오는부분
                 SqlResult := g_DBSql.DelGaBoardArticle( pArticleLoad );

                 // 살짝 타입만 바꾸고..
                 pLoad.loadType := GABOARD_DELARTICLE;
                 // 게임쪽에서 사용할수 있게 등록한후에
                 AddToGameList( pLoad );
                 // 읽은 값은 없애준다.
                 pArticleLoad := nil;
                 pLoad := nil;
               end;
            end;
            GABOARD_REQEDITARTICLE:
            begin
               Result := 14;   //bug result

               // 포인터 값을 얻어오자..
               pArticleLoad := PTGaBoardArticleLoad( pLoad.pRcd );

               // 유저이름 복사.
               pArticleLoad.UserName := pLoad.UserName;

               if pArticleLoad <> nil then
               begin
                 // 값을 읽어오자. 직접 SQL에서 읽어오는부분
                 SqlResult := g_DBSql.EditGaBoardArticle( pArticleLoad );

                 // 살짝 타입만 바꾸고..
                 pLoad.loadType := GABOARD_EDITARTICLE;
                 // 게임쪽에서 사용할수 있게 등록한후에
                 AddToGameList( pLoad );
                 // 읽은 값은 없애준다.
                 pArticleLoad := nil;
                 pLoad := nil;
               end;
            end;
            else
            begin
               Result := 170000 + loadtype;  //extended bug result
               if g_UMDEBUG > 0 then {debug code}MainOutMessage('[TestCode]ExecuteLoadCommand : case else LoadType' + IntToStr(loadtype) + ' [' + IntToStr(g_UMDEBUG) + ']');
               g_UMDEBUG := 20;
            end;
            //------------------------------------------

         end;//case

         Result := 15;   //bug result

         if pLoad <> nil then
         begin
            Result := 16;   //bug result

            dispose( pLoad );
            pLoad := nil;
         end;

         // TEST_TIME
         if g_TestTime = 12 then
            MainOutMessage('SQLEng Load :'+IntToStr( GetTickCount-Loadtime)+','+IntToStr(Loadtype));

      end; // pload <> nil

   end;  // while...
end;

procedure TSQLEngine.Execute;
var
   buginfo : integer;
begin
   buginfo := 0;

//   Suspend;
   while TRUE do
   begin
      // 쓰레드 처리루틴

      try
         // 데이터베이스에 저장하는 명령을 먼저 실행한다.
         ExecuteSaveCommand;
      except
         MainOutMessage('EXCEPTION SQLEngine.ExecuteSaveCommand');
      end;


      // 데이터베이스에서 읽는 명령어 실행
      try
         buginfo := ExecuteLoadCommand;
      except
         MainOutMessage('EXCEPTION SQLEngine.ExecuteLoadCommand' + IntToStr(buginfo) + ' [' + IntToStr(g_UMDEBUG) + ']');
         if buginfo = 3 then g_UMDEBUG := 1000;
      end;

      sleep (1);  //부하문제로 1->50으로 수정(sonmg 2004/06/15)->디시 복원(2004/07/08)
      if Terminated then exit;

    end;

end;

// GAME SERVER ==> DB 데이터 전송 ==============================================
// 정보요청커멘트 등록
procedure TSQLEngine.AddToDBList( pInfo : pTSqlLoadRecord );
begin
   if pInfo = nil then exit;

   try
      SQLock.Enter;
      SqlToDBList.Add (pInfo);
   finally
      SQLock.Leave;
   end;

end;

// 아이템 리스트 읽기를 요청한다.
function TSQLEngine.RequestLoadPageUserMarket (
   ReqInfo_ : TMarKetReqInfo
   ):Boolean;
var
   pload: PTSqlLoadRecord;
   flag : Boolean;
begin
   Result := false;

   try
      SQLock.Enter;
      flag := FActive;
   finally
      SQLock.Leave;
   end;

   if not flag then Exit;

   // 읽기 레코드 생성
   new (pload);
   pload.loadType := LOADTYPE_REQGETLIST;
   pload.UserName := ReqInfo_.UserName;
   GetMem (pload.pRcd, sizeof(TSearchSellItem));
   // 읽는 종류 생성
   PTSearchSellItem(pload.pRcd).MarketName := ReqInfo_.marketname;
   PTSearchSellItem(pload.pRcd).Who        := ReqInfo_.searchwho;
   PTSearchSellItem(pload.pRcd).ItemName   := ReqInfo_.searchitem;
   PTSearchSellItem(pload.pRcd).ItemType   := ReqInfo_.itemtype;
   PTSearchSellItem(pload.pRcd).ItemSet    := ReqInfo_.itemSet;
   PTSearchSellItem(pload.pRcd).UserMode   := ReqInfo_.UserMode;

   {debug code}if pload = nil then exit;
   AddToDBList( pload );

   if g_UMDEBUG = 1000 then {debug code}MainOutMessage('RequestLoadPageUserMarket-AddToDBList' +  ' [' + IntToStr(g_UMDEBUG) + ']');
   g_UMDEBUG := 1;

   Result := true;

end;

//내가 판매올린 아이템을 취소시킨다.
function TSQLEngine.RequestReadyToSellUserMarket (
   UserName    : String;
   MarketName  : String;
   sellwho     : String
):Boolean;
var
   pload: PTSqlLoadRecord;
begin
   Result := false;
   if not FActive then Exit;

   new (pload);
   pload.loadType := LOADTYPE_REQREADYTOSELL;  //

   pload.UserName := UserName;
   GetMem (pload.pRcd, sizeof(TMarketLoad));  //대신 쓴다.

   PTMarketLoad(pload.pRcd).MarketName := marketname;
   PTMarketLoad(pload.pRcd).SellWho    := sellwho;

   {debug code}if pload = nil then exit;
   AddToDBList( pload );

   Result := true;
end;

//아이템 사기를 요청한다.
function TSQLEngine.RequestBuyItemUserMarket (
   UserName    : string;
   MarketName  : string;
   BuyWho      : string;
   SellIndex   : integer
):Boolean;
var
   pload: PTSqlLoadRecord;
begin
   Result := false;
   if not FActive then Exit;

   // 읽기 레코드 생성
   new (pload);
   pload.loadType := LOADTYPE_REQBUYITEM;
   pload.UserName := UserName;
   GetMem (pload.pRcd, sizeof(TMarketLoad));
   // 사고자하는 아이템 정보등록
   PTMarketLoad(pload.pRcd).MarketName     := marketname;
   PTMarketLoad(pload.pRcd).SellWho        := Buywho;
   PTMarketLoad(pload.pRcd).Index          := sellindex;

   {debug code}if pload = nil then exit;
   // 등록
   AddToDBList( pload );

   Result := true;
end;

// 아이템을 정확히 받았는지 저장
procedure TSQLEngine.CheckToDB (
   UserName    : string;
   Marketname  : string;
   SellWho     : string;
   MakeIndex_  : integer;
   SellIndex   : integer;
   CheckType   : integer
   );
var
   pload: PTSqlLoadRecord;
begin
   if not FActive then begin
      MainOutMessage('[TestCode2] TSqlEngine.CheckToDB FActive is FALSE');
   end;

   // 읽기 레코드 생성
   new (pload);
   pload.loadType := LOADTYPE_REQCHECKTODB;
   pload.UserName := UserName;
   GetMem (pload.pRcd, sizeof(TSearchSellItem));
   // 전달받은 아이템 성공여부 입력
   PTSearchSellItem(pload.pRcd).CheckType  := CheckType;
   PTSearchSellItem(pload.pRcd).MarketName := marketname;
   PTSearchSellItem(pload.pRcd).Who        := SellWho;
   PTSearchSellItem(pload.pRcd).makeindex  := MakeIndex_;
   PTSearchSellItem(pload.pRcd).SellIndex  := sellindex;

   {debug code}if pload = nil then exit;
   // 등록
   AddToDBList( pload );

end;

// 아이템 등록
function TSQLEngine.RequestSellItemUserMarket (
   UserName: string;
   pselladd: PTMarketLoad
):Boolean;
var
   pload: PTSqlLoadRecord;
begin
   Result := false;
   if not FActive then Exit;

   new (pload);
   pload.loadType := LOADTYPE_REQSELLITEM;  //

   pload.UserName := UserName;
   GetMem (pload.pRcd, sizeof(TMarketLoad));
   Move (pselladd^, pload.pRcd^, sizeof(TMarketLoad));

   {debug code}if pload = nil then exit;
   AddToDBList( pload );

   Result := true;
end;

//아이템 삭제
function TSQLEngine.RequestGetPayUserMarket(
   UserName    : string;
   MarketName  : string;
   sellwho     : string;
   sellindex   : integer
):Boolean;
var
   pload: PTSqlLoadRecord;
begin
   Result := false;
   if not FActive then Exit;

   new (pload);
   pload.loadType := LOADTYPE_REQGETPAYITEM;  //

   pload.UserName := UserName;
   GetMem (pload.pRcd, sizeof(TMarketLoad));  //대신 쓴다.

   PTMarketLoad(pload.pRcd).MarketName := marketname;
   PTMarketLoad(pload.pRcd).SellWho    := sellwho;
   PTMarketLoad(pload.pRcd).Index      := sellindex;

   {debug code}if pload = nil then exit;
   AddToDBList( pload );

   Result := true;
end;

//내가 판매올린 아이템을 취소시킨다.
function TSQLEngine.RequestCancelSellUserMarket (
   UserName    : String;
   MarketName  : String;
   sellwho     : String;
   sellindex   : integer
):Boolean;
var
   pload: PTSqlLoadRecord;
begin
   Result := false;
   if not FActive then Exit;

   new (pload);
   pload.loadType := LOADTYPE_REQCANCELITEM;  //

   pload.UserName := UserName;
   GetMem (pload.pRcd, sizeof(TMarketLoad));  //대신 쓴다.

   PTMarketLoad(pload.pRcd).MarketName := marketname;
   PTMarketLoad(pload.pRcd).SellWho    := sellwho;
   PTMarketLoad(pload.pRcd).Index      := sellindex;

   {debug code}if pload = nil then exit;
   AddToDBList( pload );

   Result := true;
end;

// DB --> GAME SERVER  데이터 전송 =============================================
procedure TSQLEngine.AddToGameList( pInfo : pTSqlLoadRecord );
begin
   if pInfo = nil then exit;

   try
      SQLock.Enter;
      DbToGameList.Add (pInfo);
   finally
      SQLock.Leave;
   end;

end;

// 이쪽 아래부터는 게임쪽에서 사용하는 부분이므로 쓰레드가 분리된다 주의!=======
// 게임쪽에서 데이터를 읽어서 처리해야되는 부분...
function TSQLEngine.GetGameExecuteData : pTSqlLoadRecord;
begin
   Result := nil;

   // 명령어 리스트 얻기... 쓰레드 주의 ...
   try
      SQLock.Enter;
      if DbToGameList <> nil then begin
         if DbTOGameList.count > 0 then begin
            Result := DbTOGameList.Items[0];
            DbTOGameList.Delete(0);
         end;
      end;
   finally
      SQLock.Leave;
   end;

end;

//게임쪽에서 실행하는 루틴
procedure TSQLEngine.ExecuteRun;
var
   pLoad       : PTSqlLoadRecord;
   pSearchInfo : PTSearchSellItem;
   pLoadInfo   : PTMarketLoad;
   hum         : TUserHuman;
   i           : integer;
   pBoardListInfo : PTSearchGaBoardList;
   pArticleInfo : PTGaBoardArticleLoad;
begin

   try
      // 한번에 하나만 실행하도록하자.. 1msec 타이머에 물려서 사용하게 된다.
      pLoad := GetGameExecuteData;

      if pLoad <> nil then begin
         case pLoad.loadType of
         LOADTYPE_GETLIST :
            begin
               pSearchInfo := pLoad.pRcd;

               if pSearchInfo <> nil then begin
                  hum := UserEngine.GetUserHuman ( pLoad.UserName);

                  // 유저가 있으면
                  if hum <> nil then begin
                     hum.GetMarketData( pSearchInfo );
                     hum.SendUserMarketList( 0 );
                  end else begin
                     // 유저가 없다.. 리스트 전송폐기..
                     MainOutMessage('INFO SQLENGINE DO NOT FIND USER FOR MARKETLIST!');
                  end;

                  // 메모리 해제..
                  if pSearchInfo.pList <> nil then begin
                     for i := pSearchInfo.pList.count -1 downto 0 do begin
                        if pSearchInfo.pList.items[0] <> nil then
                           dispose ( pSearchInfo.pList.items[0] );

                        pSearchInfo.pList.delete(0);
                     end;
                     pSearchInfo.pList.Free;
                     pSearchInfo.pList := nil;
                  end;
               end;
            end;
         LOADTYPE_SELLITEM :
            begin
               pLoadInfo := pLoad.pRcd;

               if pLoadInfo <> nil then begin
                  hum := UserEngine.GetUserHuman ( pLoad.UserName );

                  if hum <> nil then begin
                      hum.SellUserMarket( pLoadInfo );
                  end else begin
                      // 유저가 없다.. 리스트 전송폐기..
                      MainOutMessage('INFO SQLENGINE DO NOT FIND USER FOR SELLITEM!');
                      // 데이터베이스 쪽 내용 취소전송
                  end;
               end;
            end;
         LOADTYPE_READYTOSELL :
            begin
               pLoadInfo := pLoad.pRcd;

               if pLoadInfo <> nil then begin
                  hum := UserEngine.GetUserHuman ( pLoad.UserName);

                  if hum <> nil then begin
                     hum.ReadyToSellUserMarket( pLoadInfo );
                  end else begin
                     // 유저가 없다.. 리스트 전송폐기..
                     MainOutMessage('INFO SQLENGINE DO NOT FIND USER FOR SELLITEM!');
                     // 데이터베이스 쪽 내용 취소전송
                  end;
               end;
            end;
         LOADTYPE_BUYITEM:
            begin
               pLoadInfo := pLoad.pRcd;

               if pLoadInfo <> nil then begin
                  hum := UserEngine.GetUserHuman ( pLoad.UserName);

                  if hum <> nil then begin
                     hum.BuyUserMarket(pLoadInfo);
                  end else begin
                     // 유저가 없다.. 리스트 전송폐기..
                     MainOutMessage('INFO SQLENGINE DO NOT FIND USER FOR SELLITEM!');
                     // 데이터베이스 쪽 내용 취소전송
                  end;
               end;
            end;
         LOADTYPE_CANCELITEM:
            begin
               pLoadInfo := pLoad.pRcd;

               if pLoadInfo <> nil then begin
                  hum := UserEngine.GetUserHuman ( pLoad.UserName);

                  if hum <> nil then begin
                     hum.CancelUserMarket(pLoadInfo);
                  end else begin
                     // 유저가 없다.. 리스트 전송폐기..
                     MainOutMessage('INFO SQLENGINE DO NOT FIND USER FOR CANCEL!');
                     // 데이터베이스 쪽 내용 취소전송
                  end;
               end;
            end;
         LOADTYPE_GETPAYITEM:
            begin
               pLoadInfo := pLoad.pRcd;

               if pLoadInfo <> nil then begin
                  hum := UserEngine.GetUserHuman ( pLoad.UserName);

                  if hum <> nil then begin
                     hum.GetPayUserMarket(pLoadInfo);
                  end else begin
                     // 유저가 없다.. 리스트 전송폐기..
                     MainOutMessage('INFO SQLENGINE DO NOT FIND USER FOR GETPAY!');
                     // 데이터베이스 쪽 내용 취소전송
                  end;
               end;
            end;

         //------------------------------------------
         // 장원게시판 목록...
         GABOARD_GETLIST:
            begin
               pBoardListInfo := pLoad.pRcd;

               if pBoardListInfo <> nil then begin
                  if pBoardListInfo.GuildName <> '' then begin
                     // 장원게시판 리스트를 읽음.
                     GuildAgitBoardMan.AddGaBoardList( pBoardListInfo );

                     // 유저에게 Refresh시킴.
                     hum := UserEngine.GetUserHuman ( pBoardListInfo.UserName );

                     if hum <> nil then begin
                        hum.CmdReloadGaBoardList( pBoardListInfo.GuildName, 1);
                     end;
                  end;

                  // 메모리 해제..
                  if pBoardListInfo.ArticleList <> nil then begin
                     for i := pBoardListInfo.ArticleList.count -1 downto 0 do begin
                        if pBoardListInfo.ArticleList.items[0] <> nil then
                           dispose ( pBoardListInfo.ArticleList.items[0] );

                        pBoardListInfo.ArticleList.delete(0);
                     end;
                     pBoardListInfo.ArticleList.Free;
                     pBoardListInfo.ArticleList := nil;
                  end;
               end;
            end;
         GABOARD_ADDARTICLE :
            begin
               pArticleInfo := pLoad.pRcd;

               if pArticleInfo <> nil then begin
                  // 우선 DB에서 로드한다...
//                  GuildAgitBoardMan.LoadAllGaBoardList( pArticleInfo.UserName );
               end;
            end;
         GABOARD_DELARTICLE :
            begin
               pArticleInfo := pLoad.pRcd;

               if pArticleInfo <> nil then begin
                  // 우선 DB에서 로드한다...
//                  GuildAgitBoardMan.LoadAllGaBoardList( pArticleInfo.UserName );
               end;
            end;
         GABOARD_EDITARTICLE :
            begin
               pArticleInfo := pLoad.pRcd;

               if pArticleInfo <> nil then begin
                  // 우선 DB에서 로드한다...
//                  GuildAgitBoardMan.LoadAllGaBoardList( pArticleInfo.UserName );
               end;
            end;
        //------------------------------------------

        end;

        //메모리 해제.. pRcd
        if pLoad.pRcd <> nil then begin
           FreeMem( pLoad.pRcd );
        end;
        //메모리 해제
        dispose( pLoad );
        pLoad := nil;
     end;

   except
       MainOutMessage('SQLEngnExcept ExecuteRun!');
   end;

end;

{-----------------------------장원게시판-------------------------}
function TSQLEngine.RequestLoadGuildAgitBoard( UserName, gname : string ):Boolean;
var
   pload: PTSqlLoadRecord;
begin
   Result := FALSE;
   if not FActive then Exit;

   // 읽기 레코드 생성
   new (pload);
   pload.loadType := GABOARD_REQGETLIST;
   pload.UserName := UserName;
   GetMem (pload.pRcd, sizeof(TSearchGaBoardList));

   // 읽는 종류 생성
   PTSearchGaBoardList(pload.pRcd).AgitNum   := 0;
   PTSearchGaBoardList(pload.pRcd).GuildName := gname;  //장원이름으로 찾기.
   PTSearchGaBoardList(pload.pRcd).OrgNum    := -1;
   PTSearchGaBoardList(pload.pRcd).SrcNum1   := -1;
   PTSearchGaBoardList(pload.pRcd).SrcNum2   := -1;
   PTSearchGaBoardList(pload.pRcd).SrcNum3   := -1;
   PTSearchGaBoardList(pload.pRcd).Kind      := KIND_GENERAL;
   PTSearchGaBoardList(pload.pRcd).UserName  := UserName;

   {debug code}if pload = nil then exit;
   AddToDBList( pload );

   Result := TRUE;
end;

function TSQLEngine.RequestGuildAgitBoardAddArticle( gname : string; OrgNum, SrcNum1, SrcNum2, SrcNum3, nKind, AgitNum : integer; uname, data : string ):Boolean;
var
   pload: PTSqlLoadRecord;
begin
   Result := FALSE;
   if not FActive then Exit;

   // 읽기 레코드 생성
   new (pload);
   pload.loadType := GABOARD_REQADDARTICLE;
   pload.UserName := uname;
   GetMem (pload.pRcd, sizeof(TGaBoardArticleLoad));

   // 읽는 종류 생성
   PTGaBoardArticleLoad(pload.pRcd).AgitNum   := AgitNum;
   PTGaBoardArticleLoad(pload.pRcd).GuildName := gname;
   PTGaBoardArticleLoad(pload.pRcd).OrgNum    := OrgNum;
   PTGaBoardArticleLoad(pload.pRcd).SrcNum1   := SrcNum1;
   PTGaBoardArticleLoad(pload.pRcd).SrcNum2   := SrcNum2;
   PTGaBoardArticleLoad(pload.pRcd).SrcNum3   := SrcNum3;
   PTGaBoardArticleLoad(pload.pRcd).Kind      := nKind;
   PTGaBoardArticleLoad(pload.pRcd).UserName  := uname;
   FillChar(PTGaBoardArticleLoad(pload.pRcd).Content, sizeof(PTGaBoardArticleLoad(pload.pRcd).Content), #0);
   StrPLCopy (PTGaBoardArticleLoad(pload.pRcd).Content, data, sizeof(PTGaBoardArticleLoad(pload.pRcd).Content)-1);

   {debug code}if pload = nil then exit;
   AddToDBList( pload );

   Result := TRUE;
end;

function TSQLEngine.RequestGuildAgitBoardDelArticle( gname : string; OrgNum, SrcNum1, SrcNum2, SrcNum3 : integer; uname : string ):Boolean;
var
   pload: PTSqlLoadRecord;
begin
   Result := FALSE;
   if not FActive then Exit;

   // 읽기 레코드 생성
   new (pload);
   pload.loadType := GABOARD_REQDELARTICLE;
   pload.UserName := uname;
   GetMem (pload.pRcd, sizeof(TGaBoardArticleLoad));

   // 읽는 종류 생성
   PTGaBoardArticleLoad(pload.pRcd).AgitNum   := 0;
   PTGaBoardArticleLoad(pload.pRcd).GuildName := gname;
   PTGaBoardArticleLoad(pload.pRcd).OrgNum    := OrgNum;
   PTGaBoardArticleLoad(pload.pRcd).SrcNum1   := SrcNum1;
   PTGaBoardArticleLoad(pload.pRcd).SrcNum2   := SrcNum2;
   PTGaBoardArticleLoad(pload.pRcd).SrcNum3   := SrcNum3;
   PTGaBoardArticleLoad(pload.pRcd).Kind      := KIND_ERROR;
   PTGaBoardArticleLoad(pload.pRcd).UserName  := uname;
   FillChar(PTGaBoardArticleLoad(pload.pRcd).Content, sizeof(PTGaBoardArticleLoad(pload.pRcd).Content), #0);

   {debug code}if pload = nil then exit;
   AddToDBList( pload );

   Result := TRUE;
end;

function TSQLEngine.RequestGuildAgitBoardDelAll( gname : string; agitnum : integer; uname : string ):Boolean;
var
   pload: PTSqlLoadRecord;
begin
   Result := FALSE;
   if not FActive then Exit;

   if agitnum = 0 then exit;

   // 읽기 레코드 생성
   new (pload);
   pload.loadType := GABOARD_REQDELARTICLE;
   pload.UserName := uname;
   GetMem (pload.pRcd, sizeof(TGaBoardArticleLoad));

   // 읽는 종류 생성
   PTGaBoardArticleLoad(pload.pRcd).AgitNum   := agitnum;
   PTGaBoardArticleLoad(pload.pRcd).GuildName := gname;
   PTGaBoardArticleLoad(pload.pRcd).OrgNum    := 0;
   PTGaBoardArticleLoad(pload.pRcd).SrcNum1   := 0;
   PTGaBoardArticleLoad(pload.pRcd).SrcNum2   := 0;
   PTGaBoardArticleLoad(pload.pRcd).SrcNum3   := 0;
   PTGaBoardArticleLoad(pload.pRcd).Kind      := KIND_ERROR;
   PTGaBoardArticleLoad(pload.pRcd).UserName  := uname;
   FillChar(PTGaBoardArticleLoad(pload.pRcd).Content, sizeof(PTGaBoardArticleLoad(pload.pRcd).Content), #0);

   {debug code}if pload = nil then exit;
   AddToDBList( pload );

   Result := TRUE;
end;

function TSQLEngine.RequestGuildAgitBoardEditArticle( gname : string; OrgNum, SrcNum1, SrcNum2, SrcNum3 : integer; uname, data : string ):Boolean;
var
   pload: PTSqlLoadRecord;
begin
   Result := FALSE;
   if not FActive then Exit;

   // 읽기 레코드 생성
   new (pload);
   pload.loadType := GABOARD_REQEDITARTICLE;
   pload.UserName := uname;
   GetMem (pload.pRcd, sizeof(TGaBoardArticleLoad));

   // 읽는 종류 생성
   PTGaBoardArticleLoad(pload.pRcd).AgitNum   := 0;
   PTGaBoardArticleLoad(pload.pRcd).GuildName := gname;
   PTGaBoardArticleLoad(pload.pRcd).OrgNum    := OrgNum;
   PTGaBoardArticleLoad(pload.pRcd).SrcNum1   := SrcNum1;
   PTGaBoardArticleLoad(pload.pRcd).SrcNum2   := SrcNum2;
   PTGaBoardArticleLoad(pload.pRcd).SrcNum3   := SrcNum3;
   PTGaBoardArticleLoad(pload.pRcd).Kind      := KIND_ERROR;
   PTGaBoardArticleLoad(pload.pRcd).UserName  := uname;
   FillChar(PTGaBoardArticleLoad(pload.pRcd).Content, sizeof(PTGaBoardArticleLoad(pload.pRcd).Content), #0);
   StrPLCopy (PTGaBoardArticleLoad(pload.pRcd).Content, data, sizeof(PTGaBoardArticleLoad(pload.pRcd).Content)-1);

   {debug code}if pload = nil then exit;
   AddToDBList( pload );

   Result := TRUE;
end;


end.
