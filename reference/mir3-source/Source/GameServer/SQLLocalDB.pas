{ ==============================================================================
    SQLLocal DB :
    게임안에서 사용되는 데이타베이스를 읽어들이는 클래스 정의
        StdItems    : 아이템  정보
        Monster     : 몬스터 정보
        MonsterItem : 몬스터가 떨구는 아이템 정보
        Magic       : 기술 (무공) 정보

    외부 화일   : .\!DBSETUP.TXT    : DB 접속 정보
        ALIAS NAME=                 : BDE Alias Setting
        SERVER NAME=                : Name or IP
        DATABASE NAME=              : Resource DataBase Name
        USER NAME=                  : DB Owner's User Name
        PASSWORD=                   : Password
        TABLE_STDITEMS=             : Table Name of StdItems
        TABLE_MONSTER=              : Table Name of Monster
        TABLE_MOBITEM=              : Table Name of Monster's Drop Items
        TABLE_MAGIC=                : Table Name of Magic

    클래스 정의
        TDataMgr        =  Base Class of Data Manager ( Don't Use Directly )
        TItemMgr        = class of TDataMgr
        TMonsterMgr     = class of TDataMgr
        TMonsterItemMgr = class of TDataMgr
        TMagicMgr       = class of TDAtaMgr

    작성자 : 박대성 ,2003.2.24
===============================================================================}
unit SQLLocalDB;

interface

uses
  Windows, Messages, SysUtils, Classes, Graphics, Controls, Forms, Dialogs,
  Db, DBTables,Grobal2,HUtil32, AdoDB, WideStrings
  ;

const LinkInfoFileName = '.\Setup\!DBSETUP.TXT';

type
    TLoadType = (ltFILE , ltSQL); // 데이터를 읽는방법 파일 , FILE OR SQL
    PInteger  = ^Integer;
    PString   = ^String;

    TSQLDetails = record
        Alias   : string;
        Server  : string;
        Database: string;
        User    : string;
        Pass    : string;

    end;

    // Base Class --------------------------------------------------------------
    TDataMgr  = class ( TObject )
    private
        FInfos          : TStringList;  // 데이터읽은후 간략한 결과값 저장
        FLoadType       : TLoadType;    // 데이터를 읽는 방법
        FLinkInfo       : TStringList;  // DB 연결 정보
        FQuery          : TAdoQuery;    // DB 에 연결될 쿼리
        FCompareStr     : String;       // 비교문에 사용될 스트링
        FDataBase       : TADOConnection;// BDE 로 접속할 데이터베이스
        FConnected      : Boolean;      // DataBase 에 연결됬는지 판단

        FTableName      : string;       // 테이블 이름
        FTableNameIndex : string;       // 외부정보에서 테이블이름을 찾을 인덱스

        procedure AddBDEalias(SQLDetails: TSQLDetails); // DB에 동적으로 ALias 생성
        function  GetLinkInfo( LinkInfo : TStringList ):Boolean;
        function  SaveLinkInfo( LinkInfo : TStringList ):Boolean;
        function  DBConnect: Boolean;       // TQuery 생성및 DB 접속하기
        procedure DBDisConnect;             // TQuery 해제 및 DB 점속 끊기

        // 쿼리 정보를 얻는 부분
        procedure OnGetSelectQuery  ( Query :TWideStrings ; TableName ,CompareStr : String); virtual;
        // 상속받은 클레승에서 메모리 겍체를 만들어 주면 된다.
        function  OnMakeData( pDataName :PString; pDataIndex :PInteger; Fields : TFields ): pointer;virtual;

        function  LoadFromFile( DataList : TList  ) : Boolean ; // 화일로 정보 얻기
        function  LoadFromSQL ( DataList : TList ; TableKind : integer ) : Boolean ; // SQL 로 정보 얻기
    public

        constructor Create;
        destructor  Destroy; override;

        function  Load ( DataList : TList ; LoadType : TLoadType ; TableKind : integer ): Boolean;
        procedure SetCompareStr  ( CompareStr :string  );   // SQL 의 WHERE 절에 사용될 스트링
        function  GetLoadedDataInfos: TStrings;             // 데이터 읽은후 간략한 정보를 얻는다.

        property IsConected : Boolean Read FConnected;      // DB 에 접속되었는지 앍수있다.
    end;

    // ItemMgr Class -----------------------------------------------------------
    TItemMgr    = class ( TDataMgr )
    private
        procedure OnGetSelectQuery( Query :TWideStrings ; TableName , CompareStr : String ); override;
        function  OnMakeData( pDataName :PString; pDataIndex :PInteger; Fields : TFields ): pointer;override;
    public
        constructor Create;
        destructor  Destroy; override;
    end;

    // MonsterMgr Class --------------------------------------------------------
    TMonsterMgr    = class ( TDataMgr )
    private
        procedure OnGetSelectQuery( Query :TWideStrings ; TableName ,CompareStr : String ); override;
        function  OnMakeData( pDataName :PString; pDataIndex :PInteger; Fields : TFields ): pointer;override;
    public
        constructor Create;
        destructor  Destroy; override;
    end;

    // MonsterItem Class -------------------------------------------------------
    TMonsterItemMgr    = class ( TDataMgr )
    private
        procedure OnGetSelectQuery( Query :TWideStrings ; TableName ,CompareStr : String ); override;
        function  OnMakeData( pDataName :PString; pDataIndex :PInteger; Fields : TFields ): pointer;override;
    public
        constructor Create;
        destructor  Destroy; override;
    end;

    // MagicMgr Class ----------------------------------------------------------
    TMagicMgr    = class ( TDataMgr )
    private
        procedure OnGetSelectQuery( Query :TWideStrings ; TableName ,CompareStr : String); override;
        function  OnMakeData( pDataName :PString; pDataIndex :PInteger; Fields : TFields ): pointer;override;
    public
        constructor Create;
        destructor  Destroy; override;
    end;

var

// 기본으로 설정된 외부 전역 변수들 사용안해도 괜찮음
    gItemMgr            : TItemMgr;
    gMonsterMgr         : TMOnsterMgr;
    gMonsterItemMgr     : TMonsterItemMgr;
    gMagicMgr           : TMagicMgr;

implementation

uses
   svMain;

// Class TDataMgr ==============================================================
constructor TDataMgr.Create;
begin
    inherited;

    FQuery      := TAdoQuery.Create( nil );
    FDataBase   := TADOConnection.Create( nil );
    FInfos      := TStringList.Create;
    FLinkInfo   := TStringList.Create;
    FConnected  := false;
    FTableName  := '';

end;

destructor TDataMgr.Destroy;
begin

    DBDisConnect;
    FQuery.Free;
    FDataBase.Free;
    FInfos.Free;
    FLinkInfo.Free;

    // TODO
    inherited;
end;

//------------------------------------------------------------------------------
// DBE 에 동적으로 Alias 생성
//------------------------------------------------------------------------------
procedure TDataMgr.AddBDEalias(SQLDetails: TSQLDetails );
var
    sAlias: string;
    slParams, slaliasList: TStringList;
begin
    slParams    := nil;
    slaliasList := nil;
    try
        slParams := TStringList.Create;
        slaliasList := TStringList.Create;
        sAlias := SQLDetails.alias;
        slParams.Add('SERVER NAME='+SQLDetails.Server);
        slParams.Add('DATABASE NAME='+SQLDetails.Database);
        slParams.Add('USER NAME='+SQLDetails.User);
        slParams.Add('PASSWORD='+SQLDetails.Pass);
    begin
        begin

            try
                Session.ConfigMode := cmPersistent;
                Session.GetAliasNames(slaliasList);

                if slAliasList.IndexOf(salias) > -1 then
                begin
                    Session.DeleteAlias(salias);
                    Session.SaveConfigFile;
                end;

                Session.AddAlias(salias, 'MSSQL', slParams);
                Session.SaveConfigFile;

            except
                On E:Exception do
                    MessageDlg({TranslateString(MSG_ADDaliasFAIL)+}':'
                    + E.Message, mtWarning, [mbOK], 0);
                end;

            end;

        end;

    finally
        if slParams <> nil then slParams.Free;
        if slaliasList <> nil then slaliasList.Free;
    end;
end;

//------------------------------------------------------------------------------
// DB 접속정보읽기
//------------------------------------------------------------------------------
function TDataMgr.GetLinkInfo( LinkInfo : TStringList ):Boolean;
Begin
   Result := false;

   if FileExists( LinkInfoFileName ) then
   begin
      LinkInfo.LoadFromFile( LinkInfoFileName );
      Result := true;
   end;
end;

//------------------------------------------------------------------------------
// DB 접속정보저장
//------------------------------------------------------------------------------
function TDataMgr.SaveLinkInfo( LinkInfo : TStringList ):Boolean;
Begin
   Result := false;

   if FileExists( LinkInfoFileName ) then
   begin
      LinkInfo.SaveToFile( LinkInfoFileName );
      Result := true;
   end;
end;

//------------------------------------------------------------------------------
// 화일로 읽을 경우
// 추후 구현 예정 현재는 필요없어서 함수만 생성해놓은 상태
//------------------------------------------------------------------------------
function TDataMgr.LoadFromFile( DataList : TList ) : Boolean ;
begin
    Result := false;
end;

//------------------------------------------------------------------------------
// SQL 로 데이터 읽음
//------------------------------------------------------------------------------
function TDataMgr.LoadFromSQL ( DataList : TList ; TableKind : integer ) : Boolean ;
var
    i           : Integer;
    pItem       : pointer;
    DataName    : String;
    DataIndex   : Integer;
begin
    Result := false;

    // 데이터가 존재하면
    if ( FQuery.RecordCount > 0 ) then
    begin
        Result := true;
        pItem   := nil;

        // 처음부터 데이터를 순차적으로 읽어들인다.
        FQuery.First;
        for i := 0 to FQuery.RecordCount -1 do
        begin
            pItem := OnMakeData( @DataName , @DataIndex , FQuery.Fields );

            // TableKind : 0이상이면 Index의 순서가 반드시 맞아야 하는 테이블(0 : 0부터 시작, 1 : 1부터 시작)
            //             -1이면 Index의 순서에 상관없는 테이블
            //Zero-based
//            if (TableKind = 0) and (i <> DataIndex) then
//               MainOutMessage('CRITICAL ERROR!!! Record Index does not match in StdItem DB ' + IntToStr(DataIndex))
//            //One-based
//            else if (TableKind = 1) and (i+1 <> DataIndex) then
//               MainOutMessage('CRITICAL ERROR!!! Record Index does not match in StdItem DB ' + IntToStr(DataIndex));

            if  pItem <> nil then
            begin
                DataList.Add ( pItem );

                // TOTEST...
                // FInfos.Add ( IntToStr(DataIndex ) +' / '+Dataname  );

                pItem := nil;
            end;

            FQuery.Next;
        end; // for...

        // 간략한 정보 저장
        FInfos.Clear;
        FInfos.Add( FTableName + ':'+ FCompareStr+' Load. Count Is '+ IntToStr( FQuery.RecordCount ) );
    end;// if ...

end;

//------------------------------------------------------------------------------
// 데잍터 읽기
// ltFILE : 파일로 부터 읽기
// ltSQL  : SQL로 부터 읽기
// DataList 의 초기화및 메모리는 해제 시키지 않으니 알아서 처리하기 바람
//------------------------------------------------------------------------------
function  TDataMgr.Load ( DataList : TList ;  LoadType : TLoadType ; TableKind : integer ): Boolean;
begin
    // TableKind : 0이상이면 Index의 순서가 반드시 맞아야 하는 테이블(0 : 0부터 시작, 1 : 1부터 시작)
    //             -1이면 Index의 순서에 상관없는 테이블

    Result := false;

    FLoadType := LoadType;

    if ( DBConnect ) then
    begin

        case LoadType of
        ltFILE : Result := LoadFromFile( DataList );
        ltSQL  : Result := LoadFromSQL ( DataList, TableKind );
        end;

    end;

    DBDisConnect;

end;

//------------------------------------------------------------------------------
// 데이터를 읽으면 내부적으로 간략한 정보를 남기는데 이정보를 읽어들임
//------------------------------------------------------------------------------
function TDataMgr.GetLoadedDataInfos: TStrings;
begin
    Result := FInfos;
end;

//------------------------------------------------------------------------------
// SQL 비교시 WHERE 절에 해당되는 문자열을 넣는다.
// 몬스터 아이템정보 읽을 떄 몬스터 이름을 WHERE = MONNAME 넣는다.
//------------------------------------------------------------------------------
procedure TDataMgr.SetCompareStr  ( CompareStr :string  );
begin
    FCompareStr := CompareStr;
end;

//------------------------------------------------------------------------------
// SELECT 에 관련된 QUERY를 입력하는 부분
// 하위클레스에서 꼭 구체화 시켜야 한다.
//------------------------------------------------------------------------------
procedure TDataMgr.OnGetSelectQuery( Query :TWideStrings ; TableName ,CompareStr : String);
begin
    Query.Clear;
    // TODO : ADD SQL QUERY To Query
end;

//------------------------------------------------------------------------------
// QUERY 필드에서 구조체에 데이터를 변경하는 부분
// 하위클레스에서 꼭 구체화 시켜야 한다.
//------------------------------------------------------------------------------
function  TDataMgr.OnMakeData( pDataName :PString; pDataIndex :PInteger; Fields : TFields ): pointer;
begin
    Result := nil;
end;

//------------------------------------------------------------------------------
// SQL2K 에 데이터베이스 접속후 SQL 를 연결한다.
//------------------------------------------------------------------------------
function TDataMgr.DBConnect: Boolean;
var
   SQLDetails : TSQLDetails;
   TempConnInfo, EncodePwd: string;
   i, j: integer;
   slist: TStringList;
begin
   Result := false;

   // 외부 환경 설정 화일을 읽는다. ( ./!DBSETUP.TXT )
   if ( GetLinkInfo( FLinkInfo ) ) then
   begin

      // 접속이 되지 않았다면  환경변수에 의해 접속
      if not FConnected then
      begin
         with FDataBase do
         begin
            LoginPrompt := false;

            // Params.Assign( FLinkInfo );

            SQLDetails.Alias    := 'MIR_RES';
            SQLDetails.Server   := FLinkInfo.Values['SERVER NAME'];
            SQLDetails.Database := FLinkInfo.Values['DATABASE NAME'];
            SQLDetails.User     := FLinkInfo.Values['USER NAME'];
            SQLDetails.Pass     := FLinkInfo.Values['PASSWORD'];

            // ADO Connection Info
            ConnectionString :=
                'Provider=SQLOLEDB.1;Password='         + SQLDetails.Pass +
                ';Persist Security Info=True;User ID='  + SQLDetails.User +
                ';Initial Catalog='                     + SQLDetails.Database +
                ';Data Source='                         + SQLDetails.Server ;

            // AddBDEalias(SQLDetails );

            // AliasName  := SQLDetails.Alias;
            FTableName := FLinkInfo.Values[FTableNameIndex];

            //DataBaseName := 'InterBase';
            Connected := true;
            FConnected := Connected;
         end;

      end; // if not...

      // 접속이 되었다면
      if FConnected then
      begin
         // TQuery 에 데이터 베이스 연결
         FQuery.Connection := FDataBase;
         // SELECT 에 관련된 쿼리를 읽고
         OnGetSelectQuery( FQuery.SQL ,FTableName , FCompareStr);

         // 쿼리가 존재하면 쿼리실행
         if ( FQuery.SQL.Count > 0 ) then
         begin
            FQuery.Active := false;
            FQuery.Active := true;
            Result := FQuery.Active;
         end;

      end; // if FCon...


   end;

end;

//------------------------------------------------------------------------------
// 데이터 베이스 끊기
//------------------------------------------------------------------------------
procedure TDataMgr.DBDisConnect;
begin
    FQuery.Active := false;
    FDataBase.Connected := False;
end;

// Class TItemMgr  =============================================================
constructor TItemMgr.Create;
begin
    inherited;
    FTableNameIndex := 'TABLE_STDITEMS';
end;

destructor TItemMgr.Destroy;
begin
    // TODO
    inherited;
end;

procedure TItemMgr.OnGetSelectQuery( Query :TWideStrings ; TableName ,CompareStr : String);
begin
    Query.Clear;
    Query.Add ( 'SELECT * FROM '+TableName);
end;

function  TItemMgr.OnMakeData( pDataName : PString; pDataIndex : PInteger; Fields : TFields ): pointer;
var
    pitem   : PTStdItem;
begin

    new (pitem);
    if ( pitem <> nil ) then
    begin
      with Fields do
      begin
         FillChar (pitem^, sizeof(TStdItem), #0);
         pDataIndex^        := FieldByName('ITEM_ID'         ).AsInteger;
         pitem^.Name        := FieldByName('NAME'       ).AsString;
         pitem^.StdMode     := FieldByName('STDMODE'    ).AsInteger;
         pitem^.Shape       := FieldByName('SHAPE'      ).AsInteger;
         pitem^.Weight      := FieldByName('WEIGHT'     ).AsInteger;
         pitem^.AniCount    := FieldByName('ANICOUNT'   ).AsInteger;
         pitem^.SpecialPwr  := FieldByName('SOURCE'     ).AsInteger;
         pitem^.ItemDesc    := FieldByName('RESERVED'   ).AsInteger;
         pitem^.Looks       := FieldByName('LOOKS'   ).AsInteger;
         pitem^.DuraMax     := FieldByName('DURAMAX'    ).AsInteger;
         pitem^.Ac          := MakeWord (FieldByName('AC' ).AsInteger, FieldByName('AC2' ).AsInteger);
         pitem^.Mac         := MakeWord (FieldByName('MAC').AsInteger, FieldByName('MAC2').AsInteger);
         pitem^.Dc          := MakeWord (FieldByName('DC_MIN' ).AsInteger, FieldByName('DC_MAX' ).AsInteger);
         pitem^.Mc          := MakeWord (FieldByName('MC_MIN' ).AsInteger, FieldByName('MC_MAX' ).AsInteger);
//         pitem^.Sc          := MakeWord (FieldByName('SC_MIN' ).AsInteger, FieldByName('SC_MAX' ).AsInteger);
         pitem^.Need        := FieldByName('NEED'       ).AsInteger;
         pitem^.NeedLevel   := FieldByName('NEEDLEVEL'  ).AsInteger;
         pitem^.Price       := FieldByName('PRICE'      ).AsInteger;
         // 2003/03/15 아이템 인벤토리 확장
//         pitem^.Stock       := FieldByName('STOCK'      ).AsInteger;
//         pitem^.AtkSpd      := FieldByName('ATKSPD'     ).AsInteger;
         pitem^.Agility     := FieldByName('AGILITY'    ).AsInteger;
         pitem^.Accurate    := FieldByName('ACCUR'   ).AsInteger;
         pitem^.MgAvoid     := FieldByName('MAGICEVADE'    ).AsInteger;
//         pitem^.Strong      := FieldByName('STRONG'     ).AsInteger;
//         pitem^.Undead      := FieldByName('UNDEAD'     ).AsInteger;
         pitem^.HpAdd       := FieldByName('HP'      ).AsInteger;
         pitem^.MpAdd       := FieldByName('MP'      ).AsInteger;
//         pitem^.ExpAdd      := FieldByName('EXPADD'     ).AsInteger;
//         pitem^.EffType1    := FieldByName('EFFTYPE1'   ).AsInteger;
//         pitem^.EffRate1    := FieldByName('EFFRATE1'   ).AsInteger;
//         pitem^.EffValue1   := FieldByName('EFFVALUE1'  ).AsInteger;
//         pitem^.EffType2    := FieldByName('EFFTYPE2'   ).AsInteger;
//         pitem^.EffRate2    := FieldByName('EFFRATE2'   ).AsInteger;
//         pitem^.EffValue2   := FieldByName('EFFVALUE2'  ).AsInteger;
//         pitem^.Slowdown    := FieldByName('SLOWDOWN'   ).AsInteger;
//         pitem^.Tox         := FieldByName('TOX'        ).AsInteger;
//         pitem^.ToxAvoid    := FieldByName('TOXAVOID'   ).AsInteger;
//         pitem^.UniqueItem  := FieldByName('UNIQUEITEM' ).AsInteger;
//         pitem^.OverlapItem := FieldByName('OVERLAPITEM').AsInteger;
//         pitem^.light       := FieldByName('LIGHT'      ).AsInteger;
//         pitem^.ItemType    := FieldByName('ITEMTYPE'   ).AsInteger;
//         pitem^.ItemSet     := FieldByName('ITEMSET'    ).AsInteger;
//         pitem^.Reference   := FieldByName('REFERENCE'  ).AsString;
      end;
    end;

    pDataName^ := pitem^.Name;

    // 가격 반값 이벤트
//    pitem^.Price := pitem^.Price div 2;

    Result  := pitem;
end;

//function  TItemMgr.OnMakeData( pDataName : PString; pDataIndex : PInteger; Fields : TFields ): pointer;
//var
//    pitem   : PTStdItem;
//begin
//
//    new (pitem);
//    if ( pitem <> nil ) then
//    begin
//      with Fields do
//      begin
//         pDataIndex^        := FieldByName('ID'         ).AsInteger;
//         pitem^.Name        := FieldByName('NAME'       ).AsString;
//         pitem^.StdMode     := FieldByName('STDMode'    ).AsInteger;
//         pitem^.Shape       := FieldByName('SHAPE'      ).AsInteger;
//         pitem^.Weight      := FieldByName('WEIGHT'     ).AsInteger;
//         pitem^.AniCount    := FieldByName('ANICOUNT'   ).AsInteger;
//         pitem^.SpecialPwr  := FieldByName('SOURCE'     ).AsInteger;
//         pitem^.ItemDesc    := FieldByName('RESERVED'   ).AsInteger;
//         pitem^.Looks       := FieldByName('IMGINDEX'   ).AsInteger;
//         pitem^.DuraMax     := FieldByName('DURAMAX'    ).AsInteger;
//         pitem^.Ac          := MakeWord (FieldByName('AC' ).AsInteger, FieldByName('ACMAX' ).AsInteger);
//         pitem^.Mac         := MakeWord (FieldByName('MAC').AsInteger, FieldByName('MACMAX').AsInteger);
//         pitem^.Dc          := MakeWord (FieldByName('DC' ).AsInteger, FieldByName('DCMAX' ).AsInteger);
//         pitem^.Mc          := MakeWord (FieldByName('MC' ).AsInteger, FieldByName('MCMAX' ).AsInteger);
//         pitem^.Sc          := MakeWord (FieldByName('SC' ).AsInteger, FieldByName('SCMAX' ).AsInteger);
//         pitem^.Need        := FieldByName('NEED'       ).AsInteger;
//         pitem^.NeedLevel   := FieldByName('NEEDLEVEL'  ).AsInteger;
//         pitem^.Price       := FieldByName('PRICE'      ).AsInteger;
//         // 2003/03/15 아이템 인벤토리 확장
//         pitem^.Stock       := FieldByName('STOCK'      ).AsInteger;
//         pitem^.AtkSpd      := FieldByName('ATKSPD'     ).AsInteger;
//         pitem^.Agility     := FieldByName('AGILITY'    ).AsInteger;
//         pitem^.Accurate    := FieldByName('ACCURATE'   ).AsInteger;
//         pitem^.MgAvoid     := FieldByName('MGAVOID'    ).AsInteger;
//         pitem^.Strong      := FieldByName('STRONG'     ).AsInteger;
//         pitem^.Undead      := FieldByName('UNDEAD'     ).AsInteger;
//         pitem^.HpAdd       := FieldByName('HPADD'      ).AsInteger;
//         pitem^.MpAdd       := FieldByName('MPADD'      ).AsInteger;
//         pitem^.ExpAdd      := FieldByName('EXPADD'     ).AsInteger;
//         pitem^.EffType1    := FieldByName('EFFTYPE1'   ).AsInteger;
//         pitem^.EffRate1    := FieldByName('EFFRATE1'   ).AsInteger;
//         pitem^.EffValue1   := FieldByName('EFFVALUE1'  ).AsInteger;
//         pitem^.EffType2    := FieldByName('EFFTYPE2'   ).AsInteger;
//         pitem^.EffRate2    := FieldByName('EFFRATE2'   ).AsInteger;
//         pitem^.EffValue2   := FieldByName('EFFVALUE2'  ).AsInteger;
//         pitem^.Slowdown    := FieldByName('SLOWDOWN'   ).AsInteger;
//         pitem^.Tox         := FieldByName('TOX'        ).AsInteger;
//         pitem^.ToxAvoid    := FieldByName('TOXAVOID'   ).AsInteger;
//         pitem^.UniqueItem  := FieldByName('UNIQUEITEM' ).AsInteger;
//         pitem^.OverlapItem := FieldByName('OVERLAPITEM').AsInteger;
//         pitem^.light       := FieldByName('LIGHT'      ).AsInteger;
//         pitem^.ItemType    := FieldByName('ITEMTYPE'   ).AsInteger;
//         pitem^.ItemSet     := FieldByName('ITEMSET'    ).AsInteger;
//         pitem^.Reference   := FieldByName('REFERENCE'  ).AsString;
//      end;
//    end;
//
//    pDataName^ := pitem^.Name;
//
//    // 가격 반값 이벤트
////    pitem^.Price := pitem^.Price div 2;
//
//    Result  := pitem;
//end;

// Class TMonsterMgr ===========================================================
constructor TMonsterMgr.Create;
begin
    inherited;
    FTableNameIndex := 'TABLE_MONSTER';
end;

destructor TMonsterMgr.Destroy;
begin
    // TODO
    inherited;
end;

procedure TMonsterMgr.OnGetSelectQuery( Query :TWideStrings ; TableName ,CompareStr : String );
begin
    Query.Clear;
    Query.Add ( 'SELECT * FROM '+TableName);

end;

function TMonsterMgr.OnMakeData( pDataName :PString; pDataIndex :PInteger;Fields : TFields ): pointer;
var
    pitem   : PTMonsterInfo;
    temphp  : integer;
begin

    new (pitem);
    if ( pitem <> nil ) then
    begin
      with Fields do
      begin
         pDataIndex^        := FieldByName('ID'         ).AsInteger;
         pitem^.Name        := FieldByName('NAME'       ).AsString;
         pitem^.Race        := FieldByName('RACE'       ).AsInteger;
         pitem^.RaceImg     := FieldByName('RACEIMG'    ).AsInteger;
         pitem^.Appr        := FieldByName('IMGINDEX'   ).AsInteger;
         pitem^.Level       := FieldByName('LV'         ).AsInteger;
         pitem^.LifeAttrib  := FieldByName('UNDEAD'     ).AsInteger;
         pitem^.CoolEye     := FieldByName('COOLEYE'    ).AsInteger;
         pitem^.Exp         := FieldByName('EXP'        ).AsInteger;
         pitem^.HP          := FieldByName('HP'         ).AsInteger;
         pitem^.MP          := FieldByName('MP'         ).AsInteger;
         pitem^.AC          := FieldByName('AC'         ).AsInteger;
//         pitem^.MAC         := FieldByName('MAC'        ).AsInteger;
         pitem^.DC          := FieldByName('DC'         ).AsInteger;
         pitem^.MaxDC       := FieldByName('DCMAX'      ).AsInteger;
         pitem^.MC          := FieldByName('MC'         ).AsInteger;
//         pitem^.SC          := FieldByName('SC'         ).AsInteger;
         pitem^.Speed       := FieldByName('AGILITY'    ).AsInteger;
         pitem^.Hit         := FieldByName('ACCURATE'   ).AsInteger;
         pitem^.WalkSpeed   := _MAX(200,FieldByName('WALK_SPD').AsInteger);
         pitem^.WalkStep    := _MAX(1,  FieldByName('WALKSTEP').AsInteger);
         pitem^.WalkWait    := FieldByName('WALKWAIT'   ).AsInteger;
         pitem^.AttackSpeed := FieldByName('ATTACK_SPD' ).AsInteger;
         // newly added by sonmg.
//         pitem^.Tame        := FieldByName('TAME'       ).AsInteger;
//         pitem^.AntiPush    := FieldByName('ANTIPUSH'   ).AsInteger;
//         pitem^.AntiUndead  := FieldByName('ANTIUNDEAD' ).AsInteger;
//         pitem^.SizeRate    := FieldByName('SIZERATE'   ).AsInteger;
//         pitem^.AntiStop    := FieldByName('ANTISTOP'   ).AsInteger;

         if ( pitem^.WalkSpeed   < 200 ) then pitem^.WalkSpeed      := 200;
         if ( pitem^.AttackSpeed < 200 ) then pitem^.AttackSpeed    := 200;

         // 몬스터의 HP  를 80% 로 일괄변경
//         temphp := ( pitem^.HP * 80 ) div 100;
//         pitem^.HP := word(temphp);
//         if ( temphp <= 0 ) or ( temphp > 65535 )then
//             MainOutMessage('Monster HP WORONG ='+IntToStr(temphp));


      end;
    end;
    pDataName^ := pitem^.Name;

    Result  := pitem;


end;

// Class TMonsterMgr ===========================================================
constructor TMonsterItemMgr.Create;
begin
    inherited;
    FTableNameIndex := 'TABLE_MOBITEM';
end;

destructor TMonsterItemMgr.Destroy;
begin
    // TODO
    inherited;
end;

procedure TMonsterItemMgr.OnGetSelectQuery( Query :TWideStrings ; TableName ,CompareStr : String );
begin
    Query.Clear;
    Query.Add ( 'SELECT * FROM '+TableName+' WHERE MOBNAME='''+CompareStr+'''');

end;

function TMonsterItemMgr.OnMakeData( pDataName :PString; pDataIndex :PInteger;Fields : TFields ): pointer;
var
    pitem   : PTMonItemInfo;
begin

    new (pitem);
    if ( pitem <> nil ) then
    begin
      with Fields do
      begin
            pDataIndex^     := FieldByName('ID'         ).AsInteger;
            pitem^.SelPoint := FieldByName('SELPOINT'   ).AsInteger - 1;
            pitem^.MaxPoint := FieldByName('MAXPOINT'   ).AsInteger;
            pitem^.ItemName := FieldByName('ITEMNAME'   ).AsString;
            pitem^.Count    := FieldByName('COUNT'      ).AsInteger;
      end;
    end;
    pDataName^ := pitem^.ItemName;

    Result  := pitem;


end;

//==============================================================================
// Class TMagicMgr
//==============================================================================
constructor TMagicMgr.Create;
begin
    inherited;
    FTableNameIndex := 'TABLE_MAGIC';
end;

destructor TMagicMgr.Destroy;
begin
    // TODO
    inherited;
end;

procedure TMagicMgr.OnGetSelectQuery( Query :TWideStrings ; TableName ,CompareStr : String);
begin
    Query.Clear;
    Query.Add ( 'SELECT * FROM '+TableName);

end;

function TMagicMgr.OnMakeData( pDataName :PString; pDataIndex :PInteger;Fields : TFields ): pointer;
var
    pitem   : PTDefMagic;
begin
    new (pitem);

    if ( pitem <> nil ) then
    begin
      with Fields do
      begin
         pitem^.MagicId         := FieldByName('ID'      ).AsInteger;
         pitem^.MagicName       := FieldByName('NAME'    ).AsString;
         pitem^.EffectType      := FieldByName('EFFECTTYPE' ).AsInteger;
         pitem^.Effect          := FieldByName('EFFECT'     ).AsInteger;
         pitem^.Spell           := FieldByName('SPELL'      ).AsInteger;
         pitem^.MinPower        := FieldByName('POWER'      ).AsInteger;
         pitem^.MaxPower        := FieldByName('MAXPOWER'   ).AsInteger;
         pitem^.Job             := FieldByName('JOB'        ).AsInteger;
         pitem^.NeedLevel[0]    := FieldByName('NEEDL1'     ).AsInteger;
         pitem^.NeedLevel[1]    := FieldByName('NEEDL2'     ).AsInteger;
         pitem^.NeedLevel[2]    := FieldByName('NEEDL3'     ).AsInteger;
         pitem^.NeedLevel[3]    := FieldByName('NEEDL3'     ).AsInteger;
         pitem^.MaxTrain[0]     := FieldByName('L1TRAIN'    ).AsInteger;
         pitem^.MaxTrain[1]     := FieldByName('L2TRAIN'    ).AsInteger;
         pitem^.MaxTrain[2]     := FieldByName('L3TRAIN'    ).AsInteger;
         pitem^.MaxTrain[3]     := pitem^.MaxTrain[2];//FieldByName('L2Train').AsInteger;
         pitem^.MaxTrainLevel   := 3; ///FieldByName('TrainLevel').AsInteger;
         pitem^.DelayTime       := FieldByName('DELAY'      ).AsInteger * 10;
         pitem^.DefSpell        := FieldByName('DEFSPELL'   ).AsInteger;
         pitem^.DefMinPower     := FieldByName('DEFPOWER'   ).AsInteger;
         pitem^.DefMaxPower     := FieldByName('DEFMAXPOWER').AsInteger;
         pitem^.Desc            := FieldByName('DESCR'      ).AsString;
      end;
    end;

    pDataIndex^:= pitem^.MagicId;
    pDataName^ := pitem^.MagicName;

    Result  := pitem;


end;

end.
