

#ifndef __ORZ_MIR2_CONFIGURATION_DIALOG__
#define __ORZ_MIR2_CONFIGURATION_DIALOG__


#define DLG_MAXSTR	256


#include <windows.h>


struct SCFG
{
	char szOdbcDSN		[DLG_MAXSTR];
	char szOdbcID		[DLG_MAXSTR];
	char szOdbcPW		[DLG_MAXSTR];
	char szOdbcDSN_PC	[DLG_MAXSTR];
	char szOdbcID_PC	[DLG_MAXSTR];
	char szOdbcPW_PC	[DLG_MAXSTR];
	int	 nCSbPort;	// Check Server Binding Port
	int	 nGSbPort;	// Game Server Binding Port
	int	 nLGbPort;	// Login Gate Binding Port
};


class CDlgConfig
{
public:
	HWND m_hWnd;
	SCFG m_conf;

public:
	CDlgConfig();
	virtual ~CDlgConfig();

	int  DoModal( HINSTANCE hInstance, HWND hWndParent );

	bool OnInitDialog();
	bool OnCommand( int nCmdID );
	bool OnKeyDown( int nVK );
	bool OnClose();

	void OnOK();
	void OnCancel();

	static BOOL __stdcall DlgProc( HWND hWnd, UINT nMsg, WPARAM wParam, LPARAM lParam ); 

protected:
	void CenterWindow();
};


#endif