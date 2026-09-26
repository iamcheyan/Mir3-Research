unit MaketSystem;

interface

uses
  Windows, Messages, SysUtils, Classes, Graphics, Controls, Dialogs,
  Grobal2;

const

    MAKET_ITEMCOUNT_PER_PAGE    = 10;
    MAKET_MAX_PAGE              = 15;
    MAKET_MAX_ITEM_COUNT        = MAKET_ITEMCOUNT_PER_PAGE * MAKET_MAX_PAGE;
    MARKET_CHARGE_MONEY         = 1000;
    MARKET_ALLOW_LEVEL          = 1;   // 1 레벨 이상만 된다.
    MARKET_COMMISION            = 10;   // 1000 분의 1 단위로 저장
    MARKET_MAX_TRUST_MONEY      = 50000000; //최대금액
    MARKET_MAX_SELL_COUNT       = 5;    // 최대 몇개까지 되나.

    MAKET_STATE_EMPTY           = 0;
    MAKET_STATE_LOADING         = 1;
    MAKET_STATE_LOADED          = 2;

{
    TMaketItem = record
      Item   	: TClientItem;	// 변경된 능력치는 여기에 적용됨.
      SellIndex	: integer;	    // 판매번호
      SellPrice	: integer;	    // 판매 가격
      SellWho	: string[20];	// 판매자
      Selldate	: string[10] 	// 판매날짜(0312311210 = 2003-12-31 12:10 )
      SellState : word          // 1 = 판매중 , 2 = 판매완료
   end;
}

type

    TMarketItemManager = class(TObject)
    private
        FState          : integer;  // 메니저 상태  0 = Empty , 1 = Loading 2 = Full

        FMaxPage        : integer;  // 최대 페이지
        FCurrPage       : integer;  // 현재 페이지
        FLoadedpage     : integer;  // 로딩된 최대 페이지

        FItems          : TList;    // MaketItem 의 리스트
        FSelectedIndex  : integer;  // 선택된 인덱스

        FUserMode       : integer;  //
        FItemType       : integer;
    private
        procedure   RemoveAll;
        procedure   InitFirst;

        function    CheckIndex( index_ : integer) : Boolean;
    public
        ReqInfo     : TMarKetReqInfo;
        constructor Create;
        destructor  Destroy; override;

        procedure   Load;
        procedure   ReLoad;

        Procedure   Add( pInfo_ :PTMarketItem );
        Procedure   Delete( Index_ : integer );
        Procedure   Clear;

        function    GetItem( Index_ : integer ; var rSelected : Boolean):PTMarketItem; overload;
        function    GetItem( Index_ : integer ):PTMarketItem; overload;
        function    IsExistIndex( Index_ : integer ; var rMoney_ : integer):Boolean;
        function    IsMyItem( Index_ : integer ; CharName_ : string ):Boolean;
        function    Select( Index_ :integer): Boolean;
        function    IsEmpty : Boolean;
        function    Count   : integer;
        function    PageCount:integer;

        procedure   OnMsgReadData;
        procedure   OnMsgWriteData;

        property    UserMode : integer Read FUserMode   Write FUserMode;
        property    ItemType : integer Read FItemType   Write FItemType;
        property    LodedPage: integer Read FLoadedPage;
        property    CurrPage : integer Read FCurrPage   Write FCurrPage;

    end;

implementation

// 생성자
constructor TMarketItemManager.Create;
begin
    InitFirst;
end;
// 소멸자
destructor  TMarketItemManager.Destroy;
begin
    RemoveAll;

    inherited;
end;

// 데이터 삭제
procedure TMarketItemManager.RemoveAll;
var
    i : integer;
    pinfo : PTMarketItem;
begin

    for i := FItems.count -1 downto 0 do
    begin
        pinfo := FItems.Items[i];

        if pinfo <> nil then dispose ( pinfo );

        FItems.delete(i);
    end;

    FItems.Clear;

    FState := MAKET_STATE_EMPTY;

end;

function TMarketItemManager.CheckIndex ( Index_ : integer ) : Boolean;
begin
    if ( Index_ >= 0 )and ( Index_ < FItems.count ) then result := true
    else result := false;
end;

// 초기화
procedure TMarketItemManager.InitFirst;
begin
    FItems := TList.Create;
    FSelectedIndex := -1;
    FState := MAKET_STATE_EMPTY;

    ReqInfo.UserName    := '';
    ReqInfo.MarketName  := '';
    ReqInfo.SearchWho   := '';
    ReqInfo.SearchItem  := '';
    ReqInfo.ItemType    := 0;
    ReqInfo.ItemSet     := 0;
    ReqInfo.UserMode    := 0;

end;

// 데이터 읽어옴
procedure TMarketItemManager.Load;
begin
    if IsEmpty and ( FState = MAKET_STATE_EMPTY) then
    begin
        // 데이터 읽기위한 메세지 전송
        OnMsgReadData;
    end;
end;

procedure TMarketItemManager.ReLoad;
begin
    if not IsEmpty then RemoveAll;

    Load;
end;

//아이템 추가
Procedure TMarketItemManager.Add( pInfo_ :PTMarketItem );
begin
    if (FItems <> nil) and ( pInfo_ <> nil) then
    begin
        FItems.Add ( pInfo_ );
    end;

    //페이지수자 갱신
    if (FItems.Count mod MAKET_ITEMCOUNT_PER_PAGE )= 0 then
        FLoadedpage := (FItems.Count div MAKET_ITEMCOUNT_PER_PAGE)
    else
        FLoadedpage := (FItems.Count div MAKET_ITEMCOUNT_PER_PAGE) + 1;

end;

//아이템 삭제
Procedure TMarketItemManager.Delete( Index_ : integer );
begin


end;

Procedure TMarketItemManager.Clear;
begin
    RemoveAll;
    FSelectedIndex := -1;
    FState := MAKET_STATE_EMPTY;

End;

// 데이터 선택
function TMarketItemManager.Select( Index_ : integer): Boolean;
begin
    Result := false;

    if  CheckIndex(Index_) then
    begin
        FSelectedIndex := Index_;
        Result := true;
    end;
end;

//데이터가 비어있는지
function TMarketItemManager.IsEmpty : Boolean;
begin
    if FItems.Count > 0 then Result := false
    else Result := true ;

end;

//개수를 얻어온다.
function TMarketItemManager.Count : integer;
begin
    Result := FItems.Count;
end;

// 페이지수자를 가져온다.
function TMarketItemManager.PageCount : integer;
begin
    if FItems.Count mod MAKET_ITEMCOUNT_PER_PAGE  = 0 then
    Result := FItems.Count div MAKET_ITEMCOUNT_PER_PAGE
    else  Result := (FItems.Count div MAKET_ITEMCOUNT_PER_PAGE ) +1;
end;



//데이터를 읽어올때 선택된넘인지 구별한다.
function TMarketItemManager.GetItem(
    Index_          : integer ;     // 아이템 인덱스
    var rSelected    : Boolean      // 선택된넘인지 리턴함
    ):PTMarketItem;
begin
    // 데이터를 얻고
    Result := GetItem( Index_ );

    // 선택된넘과 같으면 TRUE
    if Result <> nil then
    begin
        if Index_ = FSelectedIndex then rSelected := true
        else rSelected := false;
    end;

end;

// 데이터 읽어들이기.
function TMarketItemManager.GetItem(
    Index_          : integer      // 아이템 인덱스
    ):PTMarketItem;
begin
    Result := nil;

    if checkIndex( Index_ ) then
    begin
        result := PTMarketItem( FItems.Items[Index_]);

    end;
end;

//인데스가 있나 살펴보자.
function TMarketItemManager.IsExistIndex( Index_ : integer ; var rMoney_ : integer):Boolean;
var
    i       : integer;
    pInfo   : PTMarketItem;
begin
    Result  := false;
    rMoney_ := 0;

    for i := 0 to FItems.Count -1 do
    begin
        pInfo := FItems[i];

        if pInfo <> nil then
        begin
            if pInfo.Index = index_ then
            begin
                Result := true;
                rMoney_ := pInfo.SellPrice;
                Exit;
            end;
        end;

    end;

end;

function TMarketItemManager.IsMyItem( Index_ : integer ; CharName_ : string ):Boolean;
var
    i       : integer;
    pInfo   : PTMarketItem;
begin
    Result  := false;
    if CharName_ = '' then Exit;

    for i := 0 to FItems.Count -1 do
    begin
        pInfo := FItems[i];

        if pInfo <> nil then
        begin
            if pInfo.Index = index_ then
            begin
                if ( pInfo.SellWho = CharName_) then Result := true;
                Exit;
            end;
        end;

    end;

end;

// 여러가지 메세지 전송및 수신 -------------------------------------------------
procedure TMarketItemManager.OnMsgReadData;
begin

end;

procedure TMarketItemManager.OnMsgWriteData;
begin

end;

end.
