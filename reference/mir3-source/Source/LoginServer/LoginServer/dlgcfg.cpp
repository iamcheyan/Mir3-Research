

#include "dlgcfg.h"
#include "res/resource.h"
#include "../_Oranze Library/registry.h"
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

	SetFocus( GetDlgItem( m_hWnd, ODBC_DSN ) );


	LPCTSTR lpFileName=".//LoginSvr.ini";

    GetPrivateProfileString("Config","ODBC_DSN","", m_conf.szOdbcDSN,sizeof(m_conf.szOdbcDSN), lpFileName);
	GetPrivateProfileString("Config","ODBC_ID","", m_conf.szOdbcID,sizeof(m_conf.szOdbcID), lpFileName);
	GetPrivateProfileString("Config","ODBC_PW","", m_conf.szOdbcPW,sizeof(m_conf.szOdbcPW), lpFileName);
	GetPrivateProfileString("Config","ODBC_DSN_PC","", m_conf.szOdbcDSN_PC,sizeof(m_conf.szOdbcDSN_PC), lpFileName);
	GetPrivateProfileString("Config","ODBC_ID_PC","", m_conf.szOdbcID_PC,sizeof(m_conf.szOdbcID_PC), lpFileName);
	GetPrivateProfileString("Config","ODBC_PW_PC","", m_conf.szOdbcPW_PC,sizeof(m_conf.szOdbcPW_PC), lpFileName);

	m_conf.nCSbPort = GetPrivateProfileInt("Config","CS_BPORT",3000, lpFileName);
	m_conf.nGSbPort = GetPrivateProfileInt("Config","GS_BPORT",5600, lpFileName);
	m_conf.nLGbPort = GetPrivateProfileInt("Config","LG_BPORT",5500, lpFileName);

//	delete [] lpFileName; 


	/*CRegistry reg;
	reg.OpenKey( "LegendOfMir\\LoginSvr" );
	reg.GetString( "ODBC_DSN", m_conf.szOdbcDSN, DLG_MAXSTR );
	reg.GetString( "ODBC_ID", m_conf.szOdbcID, DLG_MAXSTR );
	reg.GetString( "ODBC_PW", m_conf.szOdbcPW, DLG_MAXSTR );
	reg.GetString( "ODBC_DSN_PC", m_conf.szOdbcDSN_PC, DLG_MAXSTR );
	reg.GetString( "ODBC_ID_PC", m_conf.szOdbcID_PC, DLG_MAXSTR );
	reg.GetString( "ODBC_PW_PC", m_conf.szOdbcPW_PC, DLG_MAXSTR );
	if ( !reg.GetInteger( "CS_BPORT", &m_conf.nCSbPort ) ) m_conf.nCSbPort = 3000;
	if ( !reg.GetInteger( "GS_BPORT", &m_conf.nGSbPort ) ) m_conf.nGSbPort = 5600;
	if ( !reg.GetInteger( "LG_BPORT", &m_conf.nLGbPort ) ) m_conf.nLGbPort = 5500;
	reg.CloseKey();*/

	SetDlgItemText( m_hWnd, ODBC_DSN, m_conf.szOdbcDSN );
	SetDlgItemText( m_hWnd, ODBC_ID, m_conf.szOdbcID );
	SetDlgItemText( m_hWnd, ODBC_PW, m_conf.szOdbcPW );
	SetDlgItemText( m_hWnd, ODBC_DSN_PC, m_conf.szOdbcDSN_PC );
	SetDlgItemText( m_hWnd, ODBC_ID_PC, m_conf.szOdbcID_PC );
	SetDlgItemText( m_hWnd, ODBC_PW_PC, m_conf.szOdbcPW_PC );
	SetDlgItemInt( m_hWnd, CS_BPORT, m_conf.nCSbPort, TRUE );
	SetDlgItemInt( m_hWnd, GS_BPORT, m_conf.nGSbPort, TRUE );
	SetDlgItemInt( m_hWnd, LG_BPORT, m_conf.nLGbPort, TRUE );

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
	GetDlgItemText( m_hWnd, ODBC_DSN, m_conf.szOdbcDSN, DLG_MAXSTR );
	GetDlgItemText( m_hWnd, ODBC_ID, m_conf.szOdbcID, DLG_MAXSTR );
	GetDlgItemText( m_hWnd, ODBC_PW, m_conf.szOdbcPW, DLG_MAXSTR );
	GetDlgItemText( m_hWnd, ODBC_DSN_PC, m_conf.szOdbcDSN_PC, DLG_MAXSTR );
	GetDlgItemText( m_hWnd, ODBC_ID_PC, m_conf.szOdbcID_PC, DLG_MAXSTR );
	GetDlgItemText( m_hWnd, ODBC_PW_PC, m_conf.szOdbcPW_PC, DLG_MAXSTR );
	m_conf.nCSbPort = GetDlgItemInt( m_hWnd, CS_BPORT, NULL, TRUE );
	m_conf.nGSbPort = GetDlgItemInt( m_hWnd, GS_BPORT, NULL, TRUE );
	m_conf.nLGbPort = GetDlgItemInt( m_hWnd, LG_BPORT, NULL, TRUE );
	


	LPCTSTR lpFileName=".//LoginSvr.ini";

    WritePrivateProfileString("Config","ODBC_DSN", m_conf.szOdbcDSN, lpFileName);
	WritePrivateProfileString("Config","ODBC_ID", m_conf.szOdbcID, lpFileName);
	WritePrivateProfileString("Config","ODBC_PW", m_conf.szOdbcPW, lpFileName);
	WritePrivateProfileString("Config","ODBC_DSN_PC", m_conf.szOdbcDSN_PC, lpFileName);
	WritePrivateProfileString("Config","ODBC_ID_PC", m_conf.szOdbcID_PC, lpFileName);
	WritePrivateProfileString("Config","ODBC_PW_PC", m_conf.szOdbcPW_PC, lpFileName);

	char sPort [DLG_MAXSTR];
	sprintf(sPort, "%d", m_conf.nCSbPort);
	WritePrivateProfileString("Config", "CS_BPORT", sPort, lpFileName);
	sprintf(sPort, "%d", m_conf.nGSbPort);
	WritePrivateProfileString("Config", "GS_BPORT", sPort, lpFileName);
	sprintf(sPort, "%d", m_conf.nLGbPort);
	WritePrivateProfileString("Config", "LG_BPORT", sPort, lpFileName);


//	delete [] lpFileName; 

/*	CRegistry reg;
	reg.OpenKey( "LegendOfMir\\LoginSvr" );
	reg.SetString( "ODBC_DSN", m_conf.szOdbcDSN );
	reg.SetString( "ODBC_ID", m_conf.szOdbcID );
	reg.SetString( "ODBC_PW", m_conf.szOdbcPW );
	reg.SetString( "ODBC_DSN_PC", m_conf.szOdbcDSN_PC );
	reg.SetString( "ODBC_ID_PC", m_conf.szOdbcID_PC );
	reg.SetString( "ODBC_PW_PC", m_conf.szOdbcPW_PC );
	reg.SetInteger( "CS_BPORT", m_conf.nCSbPort );
	reg.SetInteger( "GS_BPORT", m_conf.nGSbPort );
	reg.SetInteger( "LG_BPORT", m_conf.nLGbPort );
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