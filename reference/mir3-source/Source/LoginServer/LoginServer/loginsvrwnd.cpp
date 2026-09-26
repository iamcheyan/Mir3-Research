

#include "loginsvrwnd.h"
#include "database.h"
#include <registry.h>
#include <stdio.h>
#include <stdlib.h>


CLoginSvrWnd::CLoginSvrWnd()
{
	m_pTitle = "Legend of Mir 3 - Login Server V20180602";
	memset( &m_conf, 0, sizeof( m_conf ) );

	// LoadPublicKey
	LoadPublicKey("enckey.txt");
}


CLoginSvrWnd::~CLoginSvrWnd()
{
}


bool CLoginSvrWnd::OnInit()
{	



	LPCTSTR lpFileName=".//LoginSvr.ini";

    if ( !GetPrivateProfileString("Config","ODBC_DSN","", m_conf.szOdbcDSN,sizeof(m_conf.szOdbcDSN), lpFileName)	||
		 !GetPrivateProfileString("Config","ODBC_ID","", m_conf.szOdbcID,sizeof(m_conf.szOdbcID), lpFileName)	||
		 !GetPrivateProfileString("Config","ODBC_PW","", m_conf.szOdbcPW,sizeof(m_conf.szOdbcPW), lpFileName)	||
		 !GetPrivateProfileString("Config","ODBC_DSN_PC","", m_conf.szOdbcDSN_PC,sizeof(m_conf.szOdbcDSN_PC), lpFileName)	||
		 !GetPrivateProfileString("Config","ODBC_ID_PC","", m_conf.szOdbcID_PC,sizeof(m_conf.szOdbcID_PC), lpFileName)	||
		 !GetPrivateProfileString("Config","ODBC_PW_PC","", m_conf.szOdbcPW_PC,sizeof(m_conf.szOdbcPW_PC), lpFileName)	||

		 !GetPrivateProfileInt("Config","CS_BPORT",m_conf.nCSbPort, lpFileName)		||
		 !GetPrivateProfileInt("Config","GS_BPORT",m_conf.nGSbPort, lpFileName)		||
		 !GetPrivateProfileInt("Config","LG_BPORT",m_conf.nLGbPort, lpFileName) )

	/*CRegistry reg;
	reg.OpenKey( "LegendOfMir\\LoginSvr" );

	if ( !reg.GetString( "ODBC_DSN", m_conf.szOdbcDSN, DLG_MAXSTR )	||
		 !reg.GetString( "ODBC_ID", m_conf.szOdbcID, DLG_MAXSTR )	||
		 !reg.GetString( "ODBC_PW", m_conf.szOdbcPW, DLG_MAXSTR )	||
		 !reg.GetString( "ODBC_DSN_PC", m_conf.szOdbcDSN_PC, DLG_MAXSTR )	||
		 !reg.GetString( "ODBC_ID_PC", m_conf.szOdbcID_PC, DLG_MAXSTR )	||
		 !reg.GetString( "ODBC_PW_PC", m_conf.szOdbcPW_PC, DLG_MAXSTR )	||
		 !reg.GetInteger( "CS_BPORT", &m_conf.nCSbPort )			||
		 !reg.GetInteger( "GS_BPORT", &m_conf.nGSbPort )			||
		 !reg.GetInteger( "LG_BPORT", &m_conf.nLGbPort ) )*/
	{		
		PostMessage( m_hWnd, WM_COMMAND, IDM_CONFIGURATION, 0 );
	}
	else
	{	
	    m_conf.nCSbPort = GetPrivateProfileInt("Config","CS_BPORT",3000, lpFileName);
	    m_conf.nGSbPort = GetPrivateProfileInt("Config","GS_BPORT",5600, lpFileName);
	    m_conf.nLGbPort = GetPrivateProfileInt("Config","LG_BPORT",5500, lpFileName);
		//OnStartService();// 
		PostMessage( m_hWnd, WM_COMMAND, IDM_STARTSERVICE, 0 );
	}
//	delete [] lpFileName;
 
//	reg.CloseKey();	

	return true;
}



void CLoginSvrWnd::OnUninit()
{
	m_loginSvr.Cleanup();
}


void CLoginSvrWnd::OnStartService()
{
	if ( !m_loginSvr.Startup() )
	{
		m_loginSvr.Cleanup();
		return;
	}

	EnableCtrl( false );
}

void CLoginSvrWnd::OnReload()
{
	//각종 세팅 다시 읽기
	GetLoginServer()->LoadDBTables();

}


void CLoginSvrWnd::OnStopService()
{
	m_loginSvr.Cleanup();

	EnableCtrl( true );
}


void CLoginSvrWnd::OnConfiguration()
{
	CDlgConfig dlg;

	if ( dlg.DoModal( m_hInstance, m_hWnd ) == IDOK )
		m_conf = dlg.m_conf;
}

void CLoginSvrWnd::OnInitDB()
{
	// 2003/01/22...미구현
	// 1. Delete TBL_USINGIP where FLD_GAMETYPE='MIR2'
	// 2. Update TBL_DUPIP Set FLD_ISOK='1' where FLD_GAMETYPE='MIR2'
	// 3. Update MR3_PCRoomStatusTable Set PCRoomStatus_UsingIPCount = 0

	CConnection *pConnPC = GetLoginServer()->m_dbPoolPC.Alloc();
	CRecordset  *pRec = NULL;
	int  nPCRoomIndex = 0;
	char szQuery[1024];

	if ( !pConnPC )
		return;

	// 1. Delete TBL_USINGIP where FLD_GAMETYPE='MIR2'
	sprintf( szQuery, "DELETE TBL_USINGIP WHERE FLD_GAMETYPE='%s'", GetLoginServer()->m_szGameType );
#ifdef _DEBUG
	GetApp()->SetLog( 0, "[SQL QUERY] %s", szQuery);
#endif
	pRec = pConnPC->CreateRecordset();
	if(pRec)
		pRec->Execute( szQuery );
	pConnPC->DestroyRecordset( pRec );

	// 2. Update TBL_DUPIP Set FLD_ISOK='1' where FLD_GAMETYPE='MIR2'
	sprintf( szQuery, "UPDATE TBL_DUPIP SET FLD_ISOK='1' WHERE FLD_GAMETYPE='%s'", GetLoginServer()->m_szGameType );
#ifdef _DEBUG
	GetApp()->SetLog( 0, "[SQL QUERY] %s", szQuery);
#endif
	pRec = pConnPC->CreateRecordset();
	if(pRec)
		pRec->Execute( szQuery );
	pConnPC->DestroyRecordset( pRec );

	// 3. Update MR3_PCRoomStatusTable Set PCRoomStatus_UsingIPCount = 0
	sprintf( szQuery, "UPDATE MR3_PCRoomStatusTable SET PCRoomStatus_UsingIPCount = 0" );
#ifdef _DEBUG
	GetApp()->SetLog( 0, "[SQL QUERY] %s", szQuery);
#endif
	pRec = pConnPC->CreateRecordset();
	if(pRec)
		pRec->Execute( szQuery );
	pConnPC->DestroyRecordset( pRec );

	GetLoginServer()->m_dbPoolPC.Free( pConnPC );
}

void CLoginSvrWnd::OnNotInService()
{
	char szCaption[100];
	strcpy(szCaption, m_pTitle);
	
	GetLoginServer()->m_IsNotInServiceMode = !(GetLoginServer()->m_IsNotInServiceMode);
	if(GetLoginServer()->m_IsNotInServiceMode)
	{
		strcat(szCaption, "(NOT IN SERVICE MODE)");
		SetWindowText(m_hWnd,szCaption);
		GetApp()->SetLog( 0, "LoginServer is not In Service Mode");
	}
	else
	{
		strcat(szCaption, "(SERVICE MODE)");
		SetWindowText(m_hWnd,szCaption);
		GetApp()->SetLog( 0, "LoginServer is  In Service Mode");
	}
}

long CLoginSvrWnd::OnTimer( int nTimerID )
{
	m_loginSvr.OnTimer( nTimerID );
	return 0;
}

static CLoginSvrWnd *g_pWnd;


CMir2Wnd * OnCreateInstance()
{
	return g_pWnd = new CLoginSvrWnd;
}


void OnDestroyInstance( CMir2Wnd *pWnd )
{
	if ( pWnd )
	{
		delete pWnd;
		pWnd = NULL;
	}
}


CLoginSvrWnd * GetApp()
{
	return g_pWnd;
}


SCFG * GetCfg()
{
	return &g_pWnd->m_conf;
}

CLoginSvr * GetLoginServer()
{
	return &g_pWnd->m_loginSvr;
}


CDBSvrOdbcPool * GetOdbcPool()
{
	return &g_pWnd->m_loginSvr.m_dbPool;
}

CDBSvrOdbcPool * GetOdbcPoolPC()
{
	return &g_pWnd->m_loginSvr.m_dbPoolPC;
}

/*
int GetTimeInfo(char* buf)
{
	char yyyy[10], mm[10], dd[10];
	char hour[10], min[10], sec[10], msec[10];
	struct tm *temp;

	sscanf( buf, "%[^-]-%[^-]-%s %[^:]:%[^:]:%[^.].%s", yyyy, mm, dd, hour, min, sec, msec );


	temp = (tm*)malloc(sizeof(tm));	



	temp->tm_year = atoi(yyyy);
	temp->tm_mon = atoi(mm);
	temp->tm_mday = atoi(dd);
	temp->tm_hour = atoi(hour);
	temp->tm_min = atoi(min);
	temp->tm_sec = atoi(sec);

	if(strlen(buf)==0)
		return 0;

	return GetDay(temp->tm_year, temp->tm_mon, temp->tm_mday);
}
*/

int GetTimeInfo(char* buf)
{
	char yyyy[10], mm[10], dd[10];
	char hour[10], min[10], sec[10], msec[10];
	struct tm temp;

	sscanf( buf, "%[^-]-%[^-]-%s %[^:]:%[^:]:%[^.].%s", yyyy, mm, dd, hour, min, sec, msec );


//	temp = (tm*)malloc(sizeof(tm));	



	temp.tm_year = atoi(yyyy);
	temp.tm_mon = atoi(mm);
	temp.tm_mday = atoi(dd);
	temp.tm_hour = atoi(hour);
	temp.tm_min = atoi(min);
	temp.tm_sec = atoi(sec);

	if(strlen(buf)==0)
		return 0;

	return GetDay(temp.tm_year, temp.tm_mon, temp.tm_mday);
}

char* GetDateString(char* buf)
{
	static char szReturn[15];
	char yyyy[10], mm[10], dd[10];
	char hour[10], min[10], sec[10], msec[10];
	struct tm temp;

	strcpy(szReturn, "0000-00-00");

	sscanf( buf, "%[^-]-%[^-]-%s %[^:]:%[^:]:%[^.].%s", yyyy, mm, dd, hour, min, sec, msec );

	temp.tm_year = atoi(yyyy);
	temp.tm_mon = atoi(mm);
	temp.tm_mday = atoi(dd);
	temp.tm_hour = atoi(hour);
	temp.tm_min = atoi(min);
	temp.tm_sec = atoi(sec);

	if(strlen(buf)==0)
		return szReturn;

	sprintf(szReturn, "%04d-%02d-%02d\0", temp.tm_year, temp.tm_mon, temp.tm_mday);

	return szReturn;
}

////////////////////////////////////////////////////////////////////////////
// 1. 1년은 평년 (365)
// 2. 4년 마다 윤년 (366)
// 3. 100년 단위는 평년.
// 4. 400년 단위는 윤년.
////////////////////////////////////////////////////////////////////////////
int GetDay (int iYear, int iMonth, int iDay)
{
	int  iTotalDay	= 0;
	int  iTemp		= 0;
	bool bYun		= false;
	int  i			= 0;
	int  iStartYear = 1;
	
	// 미리 계산되어진 날짜 1999-12-31 까지..
	const int DAYTOYEAR1999  = 730119;

    if ( iYear > 0 )
	{
		// 연도가 2000년 이후라면 1999 까지 날짜를 바로 계산하자.
		if ( iYear > 1999 )
		{
			iStartYear = 2000;
			iTotalDay  = DAYTOYEAR1999;
		}
		else 
		{
			iStartYear = 1;
			iTotalDay  = 0;
		}

		// 연도에 따라 날수를 더해준다. 
		for (int i=iStartYear; i < iYear; i++)
		{
			if (i%400 == 0)
				iTemp=366;
			else if (i%100 == 0)
				iTemp=365;
			else if (i%4 == 0)
				iTemp=366;
			else
				iTemp=365;
			iTotalDay += iTemp;
		}

	}
	else
	{
		return 0 ;
	}

	// 윤년계산 
	if (iYear%400 == 0)
		bYun=true;
	else if (iYear%100 == 0)
		bYun=false;
	else if (iYear%4 == 0)
		bYun=true;
	else
		bYun=false;

	// 달에 해당되는 날짜 테이블 
	const int MONTH_DAY[13]={ 0, 31,29,31,30,31,30,31,31,30,31,30,31};

	// 달을 기준으로 날짜 계산 
    if ( iMonth >= 1 && iMonth <= 12 )
	{
		for ( i=1 ; i<iMonth; i++)
		{
			iTotalDay += MONTH_DAY[i];
			if (i==2 && bYun == false)
			{
				iTotalDay -= 1;    //--- 윤년 2월달은 29일까지 , 평년은 28일까지.
			}
		}
	}
	else
	{
		return 0;
	}

	// 날을 더하자..
	int MaxDay = MONTH_DAY[iMonth];
	if ( iMonth == 2 && bYun == false ) MaxDay = 28;
	if ( iDay >= 1 && iDay <= MaxDay )
	{
		iTotalDay += iDay;
	}
	else
	{
		return 0;
	}
	
    return iTotalDay;
}
/*
int GetDay (int iYear, int iMonth, int iDay)
{
    
    // 1. 1년은 평년 (365)
    // 2. 4년 마다 윤년 (366)
    // 3. 100년 단위는 평년.
    // 4. 400년 단위는 윤년.
    
    int i=0;
    int iTotalDay=0;
    int iTemp=0;
    bool bYun;
    for (i=1; i<iYear; i++)
    {
        if (i%400 == 0)
            iTemp=366;
        else if (i%100 == 0)
            iTemp=365;
        else if (i%4 == 0)
            iTemp=366;
        else
            iTemp=365;
        iTotalDay += iTemp;
    }
    if (iYear%400 == 0)
        bYun=true;
    else if (iYear%100 == 0)
        bYun=false;
    else if (iYear%4 == 0)
        bYun=true;
    else
        bYun=false;

    for (i=1; i<iMonth; i++)
    {
        if (i==2 && bYun == true)
            iTotalDay += 29;    //--- 윤년
        else if (i==2 && bYun == false)
            iTotalDay += 28;    //--- 평년
        else if (i%2==0)
            iTotalDay += 30;
        else
            iTotalDay += 31;
    }
    iTotalDay += iDay;
    return iTotalDay;
}
*/
bool isCorrectSsn(char * szSsn)
{
	//13개 자리인지 체크
	if(strlen(szSsn) !=13)
	{
		return false;
	}

	//숫자인지체크
	for(int i=0; i <=12; i++)
	{
		if((szSsn[i] < '0')||(szSsn[i] >'9'))
		{
			return false;
		}

	}

	//주민등록번호규칙에 맞는지 체크
	int iSum = 0;
	char szTemp[2];
	
	for( i=0 ; i<=11; i++)
	{
		strncpy(szTemp, szSsn+i,1);
		szTemp[1] = NULL;
		iSum = iSum + (i % 8+2)*atoi(szTemp);
	}

	iSum =  11 - (iSum % 11);
	iSum = iSum % 10;
	if(iSum != atoi(szSsn+12))
	{
		return false;
	}

	return true;
}

bool isOlderthen15(char *szSsn)
{
	SYSTEMTIME st;
    GetSystemTime(&st); 
	int nCurrentTime = GetDay(st.wYear, st.wMonth, st.wDay);
	
	char szTemp[7];
	strncpy(szTemp, szSsn, 6);
	szTemp[6] = NULL;
	
	int iYear, iMonth, iDay ;
	char szYear[3], szMonth[3], szDay[3];

	strncpy(szYear, szSsn,2);
	strncpy(szMonth, szSsn+2,2);
	strncpy(szDay, szSsn+4,2);

	szYear[3] = NULL;
	szMonth[3] = NULL;
	szDay[3] = NULL;

	iYear = atoi(szYear);
	iMonth = atoi(szMonth);
	iDay = atoi(szDay);

	if(iYear > 10)
	{
		iYear = iYear + 1900;
	}
	else
	{
		iYear = iYear + 2000;
	}
	
	
	int nUserDay = GetDay(iYear, iMonth, iDay);

	if((nCurrentTime - nUserDay) >= 365*15)
	{
		return true;
	}
	else
	{
		return false;
	}
}

bool CompareBirthDay(int nCurrent, DWORD dwBirthDay)
{
	SYSTEMTIME st;
	FILETIME ft;
	LARGE_INTEGER largeint;

	largeint.LowPart = 0;
	largeint.HighPart = 0;

	ft.dwLowDateTime = 0;
	ft.dwHighDateTime = dwBirthDay;

	FileTimeToSystemTime( &ft, &st );

	st.wYear;
	st.wMonth;
	st.wDay;

	return true;
}
