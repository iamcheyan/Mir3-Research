

#ifndef __ORZ_MIR2_WINDOW__
#define __ORZ_MIR2_WINDOW__


#pragma comment( lib, "comctl32.lib" )


#include <windows.h>
#include "res/resource.h"


#define WND_WIDTH	640
#define WND_HEIGHT	480

#define UM_SETLOG	WM_USER + 1


class CMir2Wnd
{
public:
	struct LISTDATA
	{
		long crFont;
	};

	struct SETLOGPARAM
	{
		COLORREF crFont;
		char	 szDate[32];
		char	 szText[1024];
	};

public:
	char *		m_pTitle;
	HINSTANCE	m_hInstance;
	HWND		m_hWnd;
	HWND		m_hWndToolbar, m_hWndList, m_hWndStatus;

public:
	CMir2Wnd();
	virtual ~CMir2Wnd();

	bool Init( HINSTANCE hInstance );
	void Run();
	void Uninit();

	void EnableCtrl( bool bEnableStart );
	void SetLog( COLORREF crFont, char *pMsg, ... );
	void SetErr( int nErrCode );
	void SetStatus( char *pMsg, ... );

	virtual long OnCreate();
	virtual long OnSize( int nWidth, int nHeight );
	virtual long OnDrawItem( int nCtlID, DRAWITEMSTRUCT *pDIS );
	virtual long OnCommand( int nCmdID );
	virtual long OnTimer( int nTimerID );
	virtual long OnDestroy();
	virtual long OnSetLog( SETLOGPARAM *pParam );

	bool CreateWnd();
	bool CreateToolbar();
	bool CreateList();
	bool CreateStatus();	

	LISTDATA * ListGetItemData( int nItem );
	void ListDrawItem( DRAWITEMSTRUCT *pDIS, LISTDATA *pData, int nSubItem );
	void ListClearAll();

public:
	virtual bool OnInit()			{ return true; }
	virtual void OnUninit()			{}
	virtual void OnStartService()	{}
	virtual void OnStopService()	{}
	virtual void OnReload()         {}
	virtual void OnNotInService()	{}
	virtual void OnConfiguration()	{}
	virtual void OnClearLog()		{ ListClearAll(); }
	virtual void OnInitDB()			{}
	virtual void OnExit()			{ PostMessage( m_hWnd, WM_CLOSE, 0, 0 ); }

	static long __stdcall WinProc( HWND hWnd, UINT nMsg, WPARAM wParam, LPARAM lParam ); 
};


CMir2Wnd *	OnCreateInstance ();
void		OnDestroyInstance( CMir2Wnd *pWnd );


#endif
