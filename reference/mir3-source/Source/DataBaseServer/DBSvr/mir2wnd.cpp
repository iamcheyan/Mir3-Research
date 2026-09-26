

#include "mir2wnd.h"
#include <commctrl.h>
#include <stdio.h>


CMir2Wnd::CMir2Wnd()
{
	m_pTitle		= NULL;
	m_hInstance		= NULL;
	m_hWnd			= NULL;
	m_hWndToolbar	= NULL;
	m_hWndList		= NULL;
	m_hWndStatus	= NULL;
}


CMir2Wnd::~CMir2Wnd()
{
}


bool CMir2Wnd::Init( HINSTANCE hInstance )
{
	m_hInstance = hInstance;

	InitCommonControls();

	if ( !CreateWnd() || !CreateToolbar() || !CreateList() || !CreateStatus() )
		return false;

	EnableCtrl( true );
	ShowWindow( m_hWnd, SW_SHOWDEFAULT );

	if ( !OnInit() )
		return false;
	
	SetStatus( "Ready.." );

	return true;
}


void CMir2Wnd::Run()
{
	MSG msg;
	memset( &msg, 0, sizeof( msg ) );
	
	while ( GetMessage( &msg, NULL, 0, 0 ) )
	{
		TranslateMessage( &msg );
		DispatchMessage( &msg );
	}
}


void CMir2Wnd::Uninit()
{
	OnUninit();

	UnregisterClass( m_pTitle, m_hInstance );
}


void CMir2Wnd::EnableCtrl( bool bEnableStart )
{
	HMENU hMenu = GetSubMenu( GetMenu( m_hWnd ), 0 );

	if ( bEnableStart )
	{
		EnableMenuItem( hMenu, IDM_STARTSERVICE,	MF_ENABLED | MF_BYCOMMAND );
		EnableMenuItem( hMenu, IDM_STOPSERVICE,		MF_GRAYED  | MF_BYCOMMAND );
		EnableMenuItem( hMenu, IDM_CONFIGURATION,	MF_ENABLED | MF_BYCOMMAND );

		SendMessage( m_hWndToolbar, TB_SETSTATE, IDM_STARTSERVICE, 
			(LPARAM) MAKELONG( TBSTATE_ENABLED, 0 ) );
		SendMessage( m_hWndToolbar, TB_SETSTATE, IDM_STOPSERVICE,
			(LPARAM) MAKELONG( TBSTATE_INDETERMINATE, 0 ) );
	}
	else
	{
		EnableMenuItem( hMenu, IDM_STARTSERVICE,	MF_GRAYED  | MF_BYCOMMAND );
		EnableMenuItem( hMenu, IDM_STOPSERVICE,		MF_ENABLED | MF_BYCOMMAND );
		EnableMenuItem( hMenu, IDM_CONFIGURATION,	MF_GRAYED  | MF_BYCOMMAND );

		SendMessage( m_hWndToolbar, TB_SETSTATE, IDM_STARTSERVICE, 
			(LPARAM) MAKELONG( TBSTATE_INDETERMINATE, 0 ) );
		SendMessage( m_hWndToolbar, TB_SETSTATE, IDM_STOPSERVICE,
			(LPARAM) MAKELONG( TBSTATE_ENABLED, 0 ) );
	}
}

void CMir2Wnd::SetLog( COLORREF crFont, char *pMsg, ... )
{
	SETLOGPARAM *pParam = new SETLOGPARAM;
	if ( !pParam )
		return;

	pParam->crFont = crFont;

	SYSTEMTIME st;
	GetLocalTime( &st );
	wsprintf( pParam->szDate, "%04d-%02d-%02d %02d:%02d:%02d", 
		st.wYear, st.wMonth, st.wDay, st.wHour, st.wMinute, st.wSecond );

	va_list	vList;
	va_start( vList, pMsg );
	vsprintf( pParam->szText, pMsg, vList );
	va_end  ( vList );

	PostMessage( m_hWnd, UM_SETLOG, (WPARAM) pParam, 0 );
}


void CMir2Wnd::SetErr( int nErrCode )
{
	char *pMsg;
	
	FormatMessage( 
		FORMAT_MESSAGE_ALLOCATE_BUFFER | FORMAT_MESSAGE_FROM_SYSTEM | FORMAT_MESSAGE_IGNORE_INSERTS,
		NULL,
		nErrCode,
		MAKELANGID( LANG_NEUTRAL, SUBLANG_DEFAULT ),
		(char *) &pMsg,
		0,
		NULL );

	*(strrchr( pMsg, '\r' )) = NULL;	
	SetLog( RGB(255, 0, 0), "[Win32 Error] %s", pMsg );
	
	HeapFree( GetProcessHeap(), 0, pMsg );
}


void CMir2Wnd::SetStatus( char *pMsg, ... )
{
	char szBuf[1024];

	va_list	vList;
	va_start( vList, pMsg );
	vsprintf( szBuf, pMsg, vList );
	va_end  ( vList );

	SendMessage( m_hWndStatus, SB_SETTEXT, 0, (long) szBuf );	
}


long CMir2Wnd::OnCreate()
{
	return 0;
}


long CMir2Wnd::OnSize( int nWidth, int nHeight )
{	
	RECT rcTb, rcSt;

	GetWindowRect( m_hWndToolbar, &rcTb );
	MoveWindow( m_hWndToolbar, 0, 0, 
		nWidth, rcTb.bottom - rcTb.top, TRUE );

	GetWindowRect( m_hWndStatus, &rcSt );
	MoveWindow( m_hWndStatus, 0, nHeight - (rcSt.bottom - rcSt.top), 
		nWidth, rcSt.bottom - rcSt.top, TRUE );

	MoveWindow( m_hWndList, 0, rcTb.bottom - rcTb.top - 1, 
		nWidth, nHeight - ((rcTb.bottom - rcTb.top) + (rcSt.bottom - rcSt.top)) + 2, TRUE );

	return 0;
}


long CMir2Wnd::OnDrawItem( int nCtlID, DRAWITEMSTRUCT *pDIS )
{
	LISTDATA *pData = ListGetItemData( pDIS->itemID );

	ListDrawItem( pDIS, pData, 0 );
	ListDrawItem( pDIS, pData, 1 );

	return 0;
}


long CMir2Wnd::OnCommand( int nCmdID )
{
	switch ( nCmdID )
	{
	case IDM_STARTSERVICE:	OnStartService();	break;
	case IDM_STOPSERVICE:	OnStopService();	break;
	case IDM_CONFIGURATION:	OnConfiguration();	break;
	case IDM_CLEARLOG:		OnClearLog();		break;
	case IDM_EXIT:			OnExit();			break;
	}

	return 0;
}


long CMir2Wnd::OnTimer( int nTimerID )
{
	return 0;
}


long CMir2Wnd::OnDestroy()
{
	ListClearAll();
	PostQuitMessage( 0 );

	return 0;
}


long CMir2Wnd::OnSetLog( CMir2Wnd::SETLOGPARAM *pParam )
{
	if ( ListView_GetItemCount( m_hWndList ) >= 200 )
	{
		delete (LISTDATA *) ListGetItemData( 0 );
		ListView_DeleteItem( m_hWndList, 0 );
	}

	LISTDATA *pData = new LISTDATA;
	if ( !pData )
	{
		delete pParam;
		return 0;
	}

	LV_ITEM lvi;
	memset( &lvi, 0, sizeof( lvi ) );
	lvi.mask	= LVIF_TEXT | LVIF_PARAM;
	lvi.iItem	= ListView_GetItemCount( m_hWndList );
	lvi.pszText	= pParam->szDate;
	lvi.lParam	= (LPARAM) pData;
	ListView_InsertItem( m_hWndList, &lvi );
	ListView_SetItemText( m_hWndList, lvi.iItem, 1, pParam->szText );
	ListView_EnsureVisible( m_hWndList, lvi.iItem, TRUE );

	delete pParam;
	return 0;
}


bool CMir2Wnd::CreateWnd()
{
	WNDCLASSEX wc = { sizeof( WNDCLASSEX ), CS_CLASSDC, WinProc, 0, 0, m_hInstance, 
		LoadIcon( m_hInstance, "IDI_MIR2" ), 0, 0, "IDR_MENU", m_pTitle, 0 };

	if ( !RegisterClassEx( &wc ) )
		return false;

	m_hWnd = CreateWindow( m_pTitle, m_pTitle, WS_OVERLAPPEDWINDOW, 
		CW_USEDEFAULT, CW_USEDEFAULT, WND_WIDTH, WND_HEIGHT, 0, 0, m_hInstance, this );

	return true;
}


bool CMir2Wnd::CreateToolbar()
{
	TBBUTTON tbBtns[] = 
	{
		{0, IDM_STARTSERVICE, TBSTATE_ENABLED, TBSTYLE_BUTTON},
		{1, IDM_STOPSERVICE,  TBSTATE_ENABLED, TBSTYLE_BUTTON},
	};
	
	int nBtnCnt = sizeof( tbBtns ) / sizeof( tbBtns[0] );
	
	m_hWndToolbar = CreateToolbarEx( m_hWnd, WS_CHILD | WS_VISIBLE | WS_BORDER,
		IDC_TOOLBAR, nBtnCnt, m_hInstance, IDB_TOOLBAR,
		(LPCTBBUTTON) &tbBtns, nBtnCnt, 16, 16, 16, 16, sizeof( TBBUTTON ) );

	return m_hWndToolbar ? true : false;
}


bool CMir2Wnd::CreateList()
{
	m_hWndList = CreateWindow( WC_LISTVIEW, "", 
		WS_CHILD | WS_VISIBLE | LVS_REPORT | LVS_OWNERDRAWFIXED,
		0, 0, 0, 0, m_hWnd, 0, m_hInstance, 0 );
	
	if ( !m_hWndList )
		return false;

	ListView_SetExtendedListViewStyleEx( m_hWndList, 0, LVS_EX_FULLROWSELECT );

	LVCOLUMN lvc;
	lvc.mask		= LVCF_FMT | LVCF_WIDTH | LVCF_TEXT;
	lvc.fmt			= LVCFMT_LEFT;
	lvc.cx			= 115;
	lvc.pszText		= "Date";
	ListView_InsertColumn( m_hWndList, 0, &lvc );
	lvc.cx			= WND_WIDTH - 140;
	lvc.pszText		= "Message";
	ListView_InsertColumn( m_hWndList, 1, &lvc );
	
	return true;
}


bool CMir2Wnd::CreateStatus()
{
	m_hWndStatus = CreateWindow( STATUSCLASSNAME, "", 
		WS_CHILD | WS_VISIBLE | WS_BORDER | SBS_SIZEGRIP,
		100, 100, 500, 300, m_hWnd, 0, m_hInstance, 0 );

	if ( !m_hWndStatus )
		return false;

	return true;
}


CMir2Wnd::LISTDATA * CMir2Wnd::ListGetItemData( int nItem )
{
	LV_ITEM lvi;
	memset( &lvi, 0, sizeof( lvi ) );
	lvi.mask	= LVIF_PARAM;
	lvi.iItem	= nItem;
	ListView_GetItem( m_hWndList, &lvi );

	return (LISTDATA *) lvi.lParam;
}


void CMir2Wnd::ListDrawItem( DRAWITEMSTRUCT *pDIS, CMir2Wnd::LISTDATA *pData, int nSubItem )
{
	char szText[1024];
	ListView_GetItemText( m_hWndList, pDIS->itemID, nSubItem, szText, sizeof( szText ) );

	LV_ITEM lvi;
	memset( &lvi, 0, sizeof( lvi ) );
	lvi.mask		= LVIF_STATE;
	lvi.iItem		= pDIS->itemID;
	lvi.stateMask	= 0xFFFF;
	ListView_GetItem( m_hWndList, &lvi );
	bool bHighlight = (lvi.state & LVIS_DROPHILITED) || (lvi.state & LVIS_SELECTED);

	RECT rcItem;
	ListView_GetSubItemRect( m_hWndList, pDIS->itemID, nSubItem, LVIR_LABEL, &rcItem );

	if ( bHighlight )
	{
		SetBkColor( pDIS->hDC, GetSysColor( COLOR_HIGHLIGHT ) );
		ExtTextOut( pDIS->hDC, 0, 0, ETO_OPAQUE, &rcItem, NULL, 0, NULL );
		SetTextColor( pDIS->hDC, GetSysColor( COLOR_WINDOW ) );		
	}
	else
	{
		SetBkColor( pDIS->hDC, GetSysColor( COLOR_WINDOW ) );
		ExtTextOut( pDIS->hDC, 0, 0, ETO_OPAQUE, &rcItem, NULL, 0, NULL );
		SetTextColor( pDIS->hDC, pData->crFont );
	}
	
	DrawText( pDIS->hDC, szText, strlen( szText ), &rcItem, 
		DT_NOPREFIX | DT_SINGLELINE | DT_END_ELLIPSIS | DT_LEFT | DT_VCENTER );
}


void CMir2Wnd::ListClearAll()
{
	for ( int i = 0; i < ListView_GetItemCount( m_hWndList ); i++ )
		delete (LISTDATA *) ListGetItemData( i );

	ListView_DeleteAllItems( m_hWndList );
}


long CMir2Wnd::WinProc( HWND hWnd, UINT nMsg, WPARAM wParam, LPARAM lParam )
{
	static CMir2Wnd *pThis = NULL;	

	switch ( nMsg )
	{
	case WM_CREATE:
		pThis = (CMir2Wnd *) ((CREATESTRUCT *) lParam)->lpCreateParams;
		return pThis->OnCreate();

	case WM_SIZE:
		return pThis->OnSize( LOWORD( lParam ), HIWORD( lParam ) );

	case WM_DRAWITEM:
		return pThis->OnDrawItem( wParam, (DRAWITEMSTRUCT *) lParam );

	case WM_COMMAND:
		return pThis->OnCommand( LOWORD( wParam ) );

	case WM_TIMER:
		return pThis->OnTimer( wParam );

	case WM_DESTROY:
		return pThis->OnDestroy();

	case UM_SETLOG:
		return pThis->OnSetLog( (CMir2Wnd::SETLOGPARAM *) wParam );
	}

	return DefWindowProc( hWnd, nMsg, wParam, lParam );
}




/*

	Win32 Primary Thread Entry!!

*/
int __stdcall WinMain( HINSTANCE hInstance, HINSTANCE, char *, int )
{
	CMir2Wnd *pWnd = OnCreateInstance();
	
	if ( !pWnd->Init( hInstance ) )
	{
		MessageBox( NULL, "Failed to initialize windows", pWnd->m_pTitle, MB_ICONERROR );
		OnDestroyInstance( pWnd );
		return -1;
	}

	pWnd->Run();
	pWnd->Uninit();

	OnDestroyInstance( pWnd );
	
	return 0;
}
