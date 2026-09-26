

#ifndef __ORZ_MIR2_CONFIGURATION_DIALOG__
#define __ORZ_MIR2_CONFIGURATION_DIALOG__


#define DLG_MAXSTR	256


#include <windows.h>


struct SCFG
{
	char szName		[DLG_MAXSTR];
	char szOdbcDSN	[DLG_MAXSTR];
	char szOdbcID	[DLG_MAXSTR];
	char szOdbcPW	[DLG_MAXSTR];
	char szLSAddr	[DLG_MAXSTR];
	char szMFFilePath[DLG_MAXSTR];
	int	 nLScPort;
	int	 nGSbPort;
	int	 nRGbPort;
	char szOdbcDSN2	[DLG_MAXSTR];
	char szOdbcID2	[DLG_MAXSTR];
	char szOdbcPW2	[DLG_MAXSTR];
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