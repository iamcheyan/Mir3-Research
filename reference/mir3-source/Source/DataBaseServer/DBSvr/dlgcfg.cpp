

#include "dlgcfg.h"
#include "res/resource.h"
//#include <registry.h>
#include <atlstr.h>

CDlgConfig::CDlgConfig()
{
	m_hWnd = NULL;
	memset( &m_conf, 0, sizeof( m_conf ) );
}


CDlgConfig::~CDlgConfig()
{

}


int CDlgConfig::DoModal( HINSTANCE hInstance, HWND hWndParent )
{
	return DialogBoxParam( hInstance, 
						   MAKEINTRESOURCE( IDD_CONFIG ), 
						   hWndParent, 
						   DlgProc, 
						   (LPARAM) this );
}


bool CDlgConfig::OnInitDialog()
{
	CenterWindow();

	SetFocus( GetDlgItem( m_hWnd, NAME ) );

	LPCTSTR lpFileName=".//DBSvr.ini";

    GetPrivateProfileString("Config","NAME","test", m_conf.szName,sizeof(m_conf.szName), lpFileName);
	GetPrivateProfileString("Config","ODBC_DSN","Game", m_conf.szOdbcDSN,sizeof(m_conf.szOdbcDSN), lpFileName);
	GetPrivateProfileString("Config","ODBC_ID","sa", m_conf.szOdbcID,sizeof(m_conf.szOdbcID), lpFileName);
	GetPrivateProfileString("Config","ODBC_PW","sa", m_conf.szOdbcPW,sizeof(m_conf.szOdbcPW), lpFileName);
	GetPrivateProfileString("Config","ODBC_DSN2","Account", m_conf.szOdbcDSN2,sizeof(m_conf.szOdbcDSN2), lpFileName);
	GetPrivateProfileString("Config","ODBC_ID2","sa", m_conf.szOdbcID2,sizeof(m_conf.szOdbcID2), lpFileName);
	GetPrivateProfileString("Config","ODBC_PW2","sa", m_conf.szOdbcPW2,sizeof(m_conf.szOdbcPW2), lpFileName);
	GetPrivateProfileString("Config","LS_ADDR","127.0.0.1", m_conf.szLSAddr,sizeof(m_conf.szLSAddr), lpFileName);
	GetPrivateProfileString("Config","MF_FILEPATH","..\\GameServer\\Envir", m_conf.szMFFilePath,sizeof(m_conf.szMFFilePath), lpFileName);

	m_conf.nLScPort = GetPrivateProfileInt("Config","LS_CPORT",5600, lpFileName);
	m_conf.nGSbPort = GetPrivateProfileInt("Config","GS_BPORT",6000, lpFileName);
	m_conf.nRGbPort = GetPrivateProfileInt("Config","RG_BPORT",5100, lpFileName);

	/*CRegistry reg;
	reg.OpenKey( "LegendOfMir\\DatabaseSvr" );
	reg.GetString( "NAME", m_conf.szName, DLG_MAXSTR );
	reg.GetString( "ODBC_DSN", m_conf.szOdbcDSN, DLG_MAXSTR );
	reg.GetString( "ODBC_ID", m_conf.szOdbcID, DLG_MAXSTR );
	reg.GetString( "ODBC_PW", m_conf.szOdbcPW, DLG_MAXSTR );
	reg.GetString( "ODBC_DSN2", m_conf.szOdbcDSN2, DLG_MAXSTR );
	reg.GetString( "ODBC_ID2", m_conf.szOdbcID2, DLG_MAXSTR );
	reg.GetString( "ODBC_PW2", m_conf.szOdbcPW2, DLG_MAXSTR );
	reg.GetString( "LS_ADDR", m_conf.szLSAddr, DLG_MAXSTR );
	reg.GetString( "MF_FILEPATH", m_conf.szMFFilePath, DLG_MAXSTR );
	if ( !reg.GetInteger( "LS_CPORT", &m_conf.nLScPort ) ) m_conf.nLScPort = 5600;
	if ( !reg.GetInteger( "GS_BPORT", &m_conf.nGSbPort ) ) m_conf.nGSbPort = 6000;
	if ( !reg.GetInteger( "RG_BPORT", &m_conf.nRGbPort ) ) m_conf.nRGbPort = 5100;
	reg.CloseKey();*/

	SetDlgItemText( m_hWnd, NAME, m_conf.szName );
	SetDlgItemText( m_hWnd, ODBC_DSN, m_conf.szOdbcDSN );
	SetDlgItemText( m_hWnd, ODBC_ID, m_conf.szOdbcID );
	SetDlgItemText( m_hWnd, ODBC_PW, m_conf.szOdbcPW );
	SetDlgItemText( m_hWnd, ODBC_DSN2, m_conf.szOdbcDSN2 );
	SetDlgItemText( m_hWnd, ODBC_ID2, m_conf.szOdbcID2 );
	SetDlgItemText( m_hWnd, ODBC_PW2, m_conf.szOdbcPW2 );
	SetDlgItemText( m_hWnd, LS_ADDR, m_conf.szLSAddr );
	SetDlgItemText( m_hWnd, MF_FILEPATH, m_conf.szMFFilePath );
	SetDlgItemInt( m_hWnd, LS_CPORT, m_conf.nLScPort, TRUE );
	SetDlgItemInt( m_hWnd, GS_BPORT, m_conf.nGSbPort, TRUE );
	SetDlgItemInt( m_hWnd, RG_BPORT, m_conf.nRGbPort, TRUE );

	return true;
}


bool CDlgConfig::OnKeyDown( int nVK )
{
	if ( nVK == VK_ESCAPE )
		EndDialog( m_hWnd, IDCANCEL );

	return true;
}


bool CDlgConfig::OnCommand( int nCmdID )
{
	switch ( nCmdID )
	{
	case IDOK:		OnOK();		break;
	case IDCANCEL:	OnCancel();	break;
	}

	return true;
}


bool CDlgConfig::OnClose()
{
	EndDialog( m_hWnd, IDCANCEL );

	return true;
}


void CDlgConfig::OnOK()
{
	GetDlgItemText( m_hWnd, NAME, m_conf.szName, DLG_MAXSTR );
	GetDlgItemText( m_hWnd, ODBC_DSN, m_conf.szOdbcDSN, DLG_MAXSTR );
	GetDlgItemText( m_hWnd, ODBC_ID, m_conf.szOdbcID, DLG_MAXSTR );
	GetDlgItemText( m_hWnd, ODBC_PW, m_conf.szOdbcPW, DLG_MAXSTR );
	GetDlgItemText( m_hWnd, ODBC_DSN2, m_conf.szOdbcDSN2, DLG_MAXSTR );
	GetDlgItemText( m_hWnd, ODBC_ID2, m_conf.szOdbcID2, DLG_MAXSTR );
	GetDlgItemText( m_hWnd, ODBC_PW2, m_conf.szOdbcPW2, DLG_MAXSTR );
	GetDlgItemText( m_hWnd, LS_ADDR, m_conf.szLSAddr, DLG_MAXSTR );
	GetDlgItemText( m_hWnd, MF_FILEPATH, m_conf.szMFFilePath, DLG_MAXSTR );
	m_conf.nLScPort = GetDlgItemInt( m_hWnd, LS_CPORT, NULL, TRUE );
	m_conf.nGSbPort = GetDlgItemInt( m_hWnd, GS_BPORT, NULL, TRUE );
	m_conf.nRGbPort = GetDlgItemInt( m_hWnd, RG_BPORT, NULL, TRUE );
	

	LPCTSTR lpFileName=".//DBSvr.ini";

    WritePrivateProfileString("Config","NAME", m_conf.szName, lpFileName);
    WritePrivateProfileString("Config","ODBC_DSN", m_conf.szOdbcDSN, lpFileName);
	WritePrivateProfileString("Config","ODBC_ID", m_conf.szOdbcID, lpFileName);
	WritePrivateProfileString("Config","ODBC_PW", m_conf.szOdbcPW, lpFileName);
	WritePrivateProfileString("Config","ODBC_DSN2", m_conf.szOdbcDSN2, lpFileName);
	WritePrivateProfileString("Config","ODBC_ID2", m_conf.szOdbcID2, lpFileName);
	WritePrivateProfileString("Config","ODBC_PW2", m_conf.szOdbcPW2, lpFileName);
	WritePrivateProfileString("Config","LS_ADDR", m_conf.szLSAddr, lpFileName);
	WritePrivateProfileString("Config","MF_FILEPATH", m_conf.szMFFilePath, lpFileName);

	char sPort [DLG_MAXSTR];
	sprintf(sPort, "%d", m_conf.nLScPort);
	WritePrivateProfileString("Config", "LS_CPORT", sPort, lpFileName);
	sprintf(sPort, "%d", m_conf.nGSbPort);
	WritePrivateProfileString("Config", "GS_BPORT", sPort, lpFileName);
	sprintf(sPort, "%d", m_conf.nRGbPort);
	WritePrivateProfileString("Config", "RG_BPORT", sPort, lpFileName);

	/*CRegistry reg;
	reg.OpenKey( "LegendOfMir\\DatabaseSvr" );
	reg.SetString( "NAME", m_conf.szName );
	reg.SetString( "ODBC_DSN", m_conf.szOdbcDSN );
	reg.SetString( "ODBC_ID", m_conf.szOdbcID );
	reg.SetString( "ODBC_PW", m_conf.szOdbcPW );
	reg.SetString( "ODBC_DSN2", m_conf.szOdbcDSN2 );
	reg.SetString( "ODBC_ID2", m_conf.szOdbcID2 );
	reg.SetString( "ODBC_PW2", m_conf.szOdbcPW2 );
	reg.SetString( "LS_ADDR", m_conf.szLSAddr );
	reg.SetString( "MF_FILEPATH", m_conf.szMFFilePath);
	reg.SetInteger( "LS_CPORT", m_conf.nLScPort );
	reg.SetInteger( "GS_BPORT", m_conf.nGSbPort );
	reg.SetInteger( "RG_BPORT", m_conf.nRGbPort );
	reg.CloseKey();
	*/
	EndDialog( m_hWnd, IDOK );
}


void CDlgConfig::OnCancel()
{	
	EndDialog( m_hWnd, IDCANCEL );
}


BOOL CDlgConfig::DlgProc( HWND hWnd, UINT nMsg, WPARAM wParam, LPARAM lParam )
{
	static CDlgConfig *pThis = NULL;

	switch ( nMsg )
	{	
	case WM_INITDIALOG:
		pThis = (CDlgConfig *) lParam;
		pThis->m_hWnd = hWnd;
		pThis->OnInitDialog();
		break;

	case WM_COMMAND:
		pThis->OnCommand( LOWORD( wParam ) );
		break;

	case WM_KEYDOWN:
		pThis->OnKeyDown( wParam );

	case WM_CLOSE:
		pThis->OnClose();
		break;
	}

	return FALSE;
}


void CDlgConfig::CenterWindow()
{	
	RECT rcP, rcM;

	GetWindowRect( GetParent( m_hWnd ), &rcP );
	GetWindowRect( m_hWnd, &rcM );

	SetWindowPos( m_hWnd, HWND_TOP, 
		rcP.left + ((rcP.right - rcP.left) - (rcM.right - rcM.left)) / 2,
		rcP.top + ((rcP.bottom - rcP.top) - (rcM.bottom - rcM.top)) / 2,
		0, 0, SWP_NOSIZE );
}