

#include "tablesdefine.h"
#include "netdbserver.h"
#include "dbsvrwnd.h"
#include <stdio.h>
#include <stdlib.h>
#ifdef _DEBUG
#include <crtdbg.h>
#endif
#include <stringex.h>

CDBServer::CDBServer()
{
	CDBSvrOdbcPool::SetDiagRec( __cbDBMsg );
	m_listGameServer.SetCompareFunction( __cbCmpGameServer, NULL );
	m_listRunGate.SetCompareFunction( __cbCmpRunGate, NULL );
	m_listAdmission.SetCompareFunction( __cbCmpAdmission, NULL );
	
	m_listMapServerInfo.SetCompareFunction( __cbCmpServerFromMap, NULL );

	ZeroMemory(m_ServerConnInfo, sizeof(m_ServerConnInfo));

	m_dwStatusLogTick = GetTickCount();

	m_MegaFreeSpase = 0;

	bRequestPublicKey = false;
}


CDBServer::~CDBServer()
{
}

int CDBServer::GetFreeDiskSpace( char *szDirectoryName )
{
	ULARGE_INTEGER FreeBytesAvailableToCaller;
	ULARGE_INTEGER TotalNumberOfBytes;    
	ULARGE_INTEGER TotalNumberOfFreeBytes ;

	GetDiskFreeSpaceEx(
	szDirectoryName,             
	&FreeBytesAvailableToCaller, 
	&TotalNumberOfBytes,    
	&TotalNumberOfFreeBytes 
	);

	return ( (int)(TotalNumberOfFreeBytes.QuadPart / (1024*1024*1024)) ) ;

 
}

bool CDBServer::Startup()
{
	//
	// check configuration
	//
	if ( !GetCfg()->szName[0]		||
		 !GetCfg()->szOdbcDSN[0]	|| 
		 !GetCfg()->szLSAddr[0]		||
		 !GetCfg()->nLScPort		||
		 !GetCfg()->nGSbPort		||
		 !GetCfg()->nRGbPort )
	{
		PostMessage( GetApp()->m_hWnd, WM_COMMAND, IDM_CONFIGURATION, 0 );
		return false;
	}

	m_Log.Create("DBS_", "Log");
	m_TransLog.Create("TRANS_", "Trans_Log");

	m_Log.Log("Startup DB Server\r\n");
	m_TransLog.Log ("Start Transaction Log\r\n" );

	char buffer[1024];
	sprintf( buffer , "HDD FREE SPACE C:%d GByte", GetFreeDiskSpace( "C:" ) );
	GetApp()->SetLog( CINFO, buffer );
	sprintf( buffer , "HDD FREE SPACE D:%d GByte", GetFreeDiskSpace( "D:" ) );
	GetApp()->SetLog( CINFO, buffer );

	//
	// initialize message filter (abuse filter)
	//
	if ( !m_msgFilter.Init( "badid.txt" ) )
	{
		GetApp()->SetErr( GetLastError() );
		return false;
	}
	
	//
	// initialize server infomation
	//
	if ( !InitServerInfo( "!serverinfo.txt" ) )
	{
		GetApp()->SetErr( GetLastError() );
		return false;
	}

	//
	//
	//
	char szPath[256];
	
	strcpy(szPath, GetCfg()->szMFFilePath);
	strcat(szPath, "\\");
	strcat(szPath, "MapInfo.txt");

	if ( !InitMapServerInfo( szPath ) )
	{
		GetApp()->SetErr( GetLastError() );
		return false;
	}

	//
	// initialize ODBC
	//
	if ( !m_dbPool.Startup( GetCfg()->szOdbcDSN, GetCfg()->szOdbcID, GetCfg()->szOdbcPW ) )
		return false;

	if ( !m_AcntDBPool.Startup( GetCfg()->szOdbcDSN2, GetCfg()->szOdbcID2, GetCfg()->szOdbcPW2 ) )
		return false;

	//
	// initialize IOCP handler
	//
	if ( !Init( FALSE ) )
	{
		GetApp()->SetErr( GetLastError() );
		return false;
	}

	//
	// connect & listen with local servers
	//
	if ( !Connect( &m_loginServer, CSockAddr( GetCfg()->szLSAddr, GetCfg()->nLScPort ) ) )
	{
		GetApp()->SetErr( GetLastError() );
		return false;
	}

	if ( !m_gsAcceptor.Init( CSockAddr( GetCfg()->nGSbPort ) )	||
		 !Accept( &m_gsAcceptor )								||
		 !m_rgAcceptor.Init( CSockAddr( GetCfg()->nRGbPort ) )	||
		 !Accept( &m_rgAcceptor ) )
	{
		GetApp()->SetErr( GetLastError() );
		return false;
	}

	//
	// success!!
	//
	GetApp()->SetLog( CINFO, "DB Server initialized." );
	GetApp()->SetStatus( "Running.." );
	
#ifdef _DEBUG
	GetApp()->SetLog( CDBG, 
		"DB Server is running in Debug Mode. This will puts all input/output packets." );
#endif

	return true;
}


void CDBServer::Cleanup()
{
	//
	// free timer
	//
	KillTimer( GetApp()->m_hWnd, TIMER_KEEPALIVE );
	KillTimer( GetApp()->m_hWnd, TIMER_CONNLOGINSERVER );
	//
	// release IOCP handler
	//
	Uninit();

	//
	// release network objects and linked resources
	// 
	m_listAdmission.ClearAll();

	m_listRunGate.ClearAll();
	m_rgAcceptor.Uninit();
	m_listGameServer.ClearAll();
	m_gsAcceptor.Uninit();
	m_loginServer.Uninit();

	//
	//
	m_listMapServerInfo.ClearAll();

	//
	// release ODBC resources
	//
	m_dbPool.Cleanup();
	m_AcntDBPool.Cleanup();

	//
	// release message filter
	//
	m_msgFilter.Uninit();

	//
	// success!!
	//
	GetApp()->SetLog( CINFO, "DB Server finalized." );
	GetApp()->SetStatus( "Ready.." );

	m_Log.Log("Cleanup DB Server\r\n");
}


void CDBServer::OnError( int nErrCode )
{
	GetApp()->SetErr( nErrCode );
}


CIocpObject * CDBServer::OnAccept( CIocpAcceptor *pAcceptor, SOCKET sdClient )
{
	if ( pAcceptor == &m_gsAcceptor )
	{
		CGameServer *pObject = new CGameServer( sdClient );
		if ( !pObject )
			return NULL;

		m_listGameServer.Lock();
		if ( !m_listGameServer.Insert( pObject ) )
		{
			delete pObject;
			pObject = NULL;
		}
		else
		{
			char szLogMsg[128];
			
			sprintf(szLogMsg, "[%s:%d] GameServer connected.", pObject->IP(), pObject->Port() );
//			GetApp()->SetLog( 0, "[%s:%d] GameServer connected.", pObject->IP(), pObject->Port() );
			GetApp()->SetLog( 0, szLogMsg );
			m_Log.Log(szLogMsg, true);
		}
		m_listGameServer.Unlock();

		return pObject;
	}
	else if ( pAcceptor == &m_rgAcceptor )
	{
		CRunGate *pObject = new CRunGate( sdClient );
		if ( !pObject )
			return NULL;

		m_listRunGate.Lock();
		if ( !m_listRunGate.Insert( pObject ) )
		{
			delete pObject;
			pObject = NULL;
		}
		else
		{
			char szLogMsg[128];
			
			sprintf(szLogMsg, "[%s:%d] RunGate connected.", pObject->IP(), pObject->Port() );
//			GetApp()->SetLog( 0, "[%s:%d] RunGate connected.", pObject->IP(), pObject->Port() );
			GetApp()->SetLog( 0, szLogMsg );
			m_Log.Log( szLogMsg, true );
		}
		m_listRunGate.Unlock();

		return pObject;
	}

	return NULL;
}


void CDBServer::OnAcceptError( CIocpAcceptor *pAcceptor, int nErrCode )
{
	GetApp()->SetErr( nErrCode );
}


bool CDBServer::OnConnect( CIocpObject *pObject )
{
	GetApp()->SetLog( 0, "Connected to LoginServer." );
	m_Log.Log( "Connected to LoginServer.\r\n" );

	KillTimer( GetApp()->m_hWnd, TIMER_CONNLOGINSERVER ); 
	SetTimer( GetApp()->m_hWnd, TIMER_KEEPALIVE, TIMER_INTERVAL, NULL );

	m_Log.Log( "KillTimer : TIMER_CONNLOGINSERVER, StartTimer : TIMER_KEEPALIVE\r\n" );

	return true;
}


void CDBServer::OnConnectError( CIocpObject *pObject, int nErrCode )
{
	GetApp()->SetLog( CERR, "Unable to connect to LoginServer." );
	GetApp()->SetErr( nErrCode );

	SetTimer( GetApp()->m_hWnd, TIMER_CONNLOGINSERVER, TIMER_INTERVAL, NULL );
}


void CDBServer::OnClose( CIocpObject *pObject )
{
	char szLogMsg[128];

	switch ( pObject->GetClassId() )
	{
		case CLoginServer::CLASSID:
			sprintf( szLogMsg, "[%s:%d] LoginServer disconnected.", pObject->IP(), pObject->Port() );
			GetApp()->SetLog( CERR, szLogMsg );
			m_Log.Log( szLogMsg, true );
			m_loginServer.Uninit();
			SetTimer( GetApp()->m_hWnd, TIMER_CONNLOGINSERVER, TIMER_INTERVAL, NULL );
			m_Log.Log( "StartTimer : TIMER_CONNLOGINSERVER\r\n" );
			break;
		case CGameServer::CLASSID:
			sprintf( szLogMsg, "[%s:%d] GameServer disconnected.", pObject->IP(), pObject->Port() );
			GetApp()->SetLog( CERR, szLogMsg );
			m_Log.Log( szLogMsg, true );
			m_listGameServer.Lock();
			delete m_listGameServer.Remove( (CGameServer *) pObject );
			m_listGameServer.Unlock();
			break;
		case CRunGate::CLASSID:
			sprintf( szLogMsg, "[%s:%d] RunGate disconnected.", pObject->IP(), pObject->Port() );
			GetApp()->SetLog( CERR, szLogMsg );
			m_Log.Log( szLogMsg, true );
			m_listRunGate.Lock();
			delete m_listRunGate.Remove( (CRunGate *) pObject );
			m_listRunGate.Unlock();
			break;
	}
}


void CDBServer::OnTimer( int nTimerID )
{
	switch ( nTimerID )
	{
		case TIMER_KEEPALIVE:
		{
			//로그인서버로 Publickey를 요청한다.
			if( !bRequestPublicKey )
			{
				bRequestPublicKey = true;
				m_loginServer.SendRequestPublicKey();
			}

			m_loginServer.SendUserCount();

/*			if (GetTickCount() - m_dwStatusLogTick >= 60 * 1000)
			{
				CListNode< CGameServer > *pNode;
				CGameServer				 *pGameSvr;

				m_listGameServer.Lock();

				for ( pNode = m_listGameServer.GetHead(); pNode; pNode = pNode->GetNext() )
				{
					pGameSvr = pNode->GetData();
					if (pGameSvr) pGameSvr->ShowStatusLog();
				}

				m_listGameServer.Unlock();

				m_dwStatusLogTick = GetTickCount(); 
			} */

			break;
		}
		case TIMER_CONNLOGINSERVER:
			GetApp()->SetLog( 0, "Retry to connect to LoginServer." );
			if ( !Connect( &m_loginServer, CSockAddr( GetCfg()->szLSAddr, GetCfg()->nLScPort ) ) ) // connect & listen with local servers
				GetApp()->SetErr( GetLastError() );
			break;
	}
}


bool CDBServer::InsertAdmission( char *pID, int nCert, int nPayMode )
{
	sAdmission *pAI = new sAdmission;
	if ( !pAI )
	{
		char szLogMsg[128];
		sprintf(szLogMsg, "InsertAdmission Failed:%s, [%d]\r\n", pID, nCert);
		m_Log.Log( szLogMsg );
		
		return false;
	}

	memset( pAI, 0, sizeof( sAdmission ) );
	strcpy( pAI->szID, pID );
	pAI->nCert		= nCert;
	pAI->nPayMode	= nPayMode;
	pAI->bSelected	= false;

	m_listAdmission.Lock();
	if ( !m_listAdmission.Insert( pAI ) )
	{
		m_listAdmission.Unlock();
		delete pAI;

		char szLogMsg[128];
		sprintf(szLogMsg, "InsertAdmission Failed:%s, [%d]\r\n", pID, nCert);
		m_Log.Log( szLogMsg );
		
		return false;
	}

	m_listAdmission.Unlock();
	return true;
}


bool CDBServer::RemoveAdmission( char *pID, int nCert )
{
	sAdmission search;
	strcpy( search.szID, pID );
	search.nCert = nCert;

	m_listAdmission.Lock();
	sAdmission *pAI = m_listAdmission.Remove( &search );
	m_listAdmission.Unlock();
	if ( !pAI )
		return false;

	delete pAI;
	return true;
}


bool CDBServer::IsRegisteredAdmission( char *pID, int nCert )
{
	sAdmission search;
	strcpy( search.szID, pID );
	search.nCert = nCert;

	m_listAdmission.Lock();
	bool bRet = m_listAdmission.Search( &search ) ? true : false;
	m_listAdmission.Unlock();

	return bRet;
}

bool CDBServer::IsRegisteredUserId( char *pID )
{
	sAdmission search;

	m_listAdmission.Lock();
	bool bRet = m_listAdmission.Search( &search ) ? true : false;
	m_listAdmission.Unlock();

	return bRet;
}

bool CDBServer::IsSelectedAdmission( int nCert )
{
	CListNode< sAdmission >	*pNode;
	sAdmission				*pAdmission;

	m_listAdmission.Lock();

	for ( pNode = m_listAdmission.GetHead(); pNode; pNode = pNode->GetNext() )
	{
		pAdmission = pNode->GetData();

		if ( pAdmission->nCert == nCert )
		{
			m_listAdmission.Unlock();
			return pAdmission->bSelected;			
		}
	}

	m_listAdmission.Unlock();
	
	return false;
}


bool CDBServer::CheckSelectedAdmission( int nCert )
{
	CListNode< sAdmission >	*pNode;
	sAdmission				*pAdmission;

	m_listAdmission.Lock();
	for ( pNode = m_listAdmission.GetHead(); pNode; pNode = pNode->GetNext() )
	{
		pAdmission = pNode->GetData();

		if (pAdmission->nCert == nCert)
		{
			pAdmission->bSelected = true;
			m_listAdmission.Unlock();
			return true;
		}
	}

	m_listAdmission.Unlock();
	return false;
}


void CDBServer::__cbDBMsg( char *pState, int nErrCode, char *pDesc )
{
	//
	// ignore information message
	//
	if ( nErrCode == 5701 || nErrCode == 5703 )
		return;

	//-------------------------------------------------------------------------
	//ErrorCode 추가 (2004/07/23 sonmg)
	char temp[20] = {0,}, temp2[20] = {0,};
	itoa(nErrCode, temp, 10);
	wsprintf(temp2, " [%s]", temp);
	strcat(pDesc, temp2);

/* 로그 확인후 에러코드 맞춰서 수정해야 함.
	//ErrorCode == 0 일때 처리
	if( nErrCode == 0 )
	{
		PostMessage( GetApp()->m_hWnd, WM_COMMAND, IDM_STOPSERVICE, 0 );
		PostMessage( GetApp()->m_hWnd, WM_COMMAND, IDM_STARTSERVICE, 0 );
	}
*/
	//-------------------------------------------------------------------------

	GetApp()->SetLog( CERR, pDesc );
	GetDBServer()->m_TransLog.Log( pDesc, true );
}


int CDBServer::__cbCmpGameServer( void *pArg, CGameServer *pFirst, CGameServer *pSecond )
{
	return pFirst - pSecond;
}


int CDBServer::__cbCmpRunGate( void *pArg, CRunGate *pFirst, CRunGate *pSecond )
{
	return pFirst - pSecond;
}


int CDBServer::__cbCmpAdmission( void *pArg, sAdmission *pFirst, sAdmission *pSecond )
{
//	return stricmp( pFirst->szID, pSecond->szID ) && (pFirst->nCert == pSecond->nCert);
	if ( ( stricmp( pFirst->szID, pSecond->szID )==0 ) && (pFirst->nCert == pSecond->nCert) )
	return 0;
	else
	return 1;

}

int CDBServer::__cbCmpServerFromMap( void *pArg, CMapServerInfo *pFirst, CMapServerInfo *pSecond )
{
	return stricmp( pFirst->szMapName, pSecond->szMapName );
}

bool CDBServer::InitServerInfo(char *pszFilePath)
{
	char	szConnInfo[1024];
	char	*pszAddr = NULL, *pszPort = NULL;
	char	*pszAddr2 = NULL, *pszPort2 = NULL, *pszAddr3 = NULL, *pszPort3 = NULL;
	int		nCnt = 0;
	FILE	*fp = fopen( pszFilePath, "rb" );

	if ( !fp )
		return false;

	__try
	{
		while ( !feof( fp ) || nCnt < MAXPLAYSERVER)
		{
			if (fgets( szConnInfo, sizeof(szConnInfo), fp ) == NULL)
				break;

			if (pszAddr = strchr(szConnInfo, ','))
			{
				*pszAddr++ = '\0';

				if (pszPort = strchr(pszAddr, ':'))
				{
					*pszPort++ = '\0';

					strcpy(m_ServerConnInfo[nCnt].szRemote, szConnInfo);
					strcpy(m_ServerConnInfo[nCnt].szAddr,	pszAddr);
					m_ServerConnInfo[nCnt].nPort = atoi(pszPort);

					if (pszAddr2 = strchr(pszPort, ','))
					{
						*pszAddr2++ = '\0';

						if (pszPort2 = strchr(pszAddr2, ':'))
						{
							*pszPort2++ = '\0';

							strcpy(m_ServerConnInfo[nCnt].szAddr2, pszAddr2);
							m_ServerConnInfo[nCnt].nPort2 = atoi(pszPort2);
							
							if (pszAddr3 = strchr(pszPort2, ','))
							{
								*pszAddr3++ = '\0';

								if (pszPort3 = strchr(pszAddr3, ':'))
								{
									strcpy(m_ServerConnInfo[nCnt].szAddr3, pszAddr3);
									m_ServerConnInfo[nCnt].nPort3 = atoi(pszPort3);
								}
							}
						}
					}

					nCnt++;
				}

#ifdef _DEBUG
				if (nCnt)
					_RPT3(_CRT_WARN, "%s %s %d", m_ServerConnInfo[nCnt - 1].szRemote, m_ServerConnInfo[nCnt - 1].szAddr,
																m_ServerConnInfo[nCnt - 1].nPort);
					_RPT4(_CRT_WARN, " %s %d %s %d\n",	m_ServerConnInfo[nCnt - 1].szAddr2, m_ServerConnInfo[nCnt - 1].nPort2,
														m_ServerConnInfo[nCnt - 1].szAddr3, m_ServerConnInfo[nCnt - 1].nPort3);
#endif
			}																					  
		}
	}
	__except ( EXCEPTION_EXECUTE_HANDLER )
	{
		fclose( fp );
		return false;
	}

	fclose( fp );

	return true;
}

bool CDBServer::InitMapServerInfo(char *pszFilePath)
{
	FILE *fp = fopen( pszFilePath, "rb" );
	if ( !fp )
		return false;

	char szLine[2048];
	char szName[64], szDesc[512], szIdx[64];

	while ( fgets( szLine, sizeof( szLine ), fp ) )
	{
		_trim( szLine );

		if ( sscanf( szLine, "%s %s %s", szName, szDesc, szIdx ) < 3 )
			continue;

		if ( szName[0] != '[' || szIdx[ strlen( szIdx ) - 1 ] != ']' )
			continue;

		szIdx[ strlen( szIdx ) - 1 ] = '\0';

		CMapServerInfo *pSI = new CMapServerInfo;
		if ( !pSI )
			continue;

		strcpy( pSI->szMapName, szName + 1 );
		pSI->nServerIndex = atoi( szIdx );

		if ( !m_listMapServerInfo.Insert( pSI ) )
		{
			delete pSI;
			continue;
		}

#ifdef _DEBUG
		_RPT2(_CRT_WARN, "%s, %d\n", pSI->szMapName, pSI->nServerIndex);
#endif
	}

	fclose( fp );

	return true;
}

int CDBServer::GetServerFromMap(char *pszMapName)
{
	CMapServerInfo MapServerInfo;

	strcpy(MapServerInfo.szMapName, pszMapName);

	CMapServerInfo* pMapServerInfo = m_listMapServerInfo.Search( &MapServerInfo );

	if (pMapServerInfo)
		return pMapServerInfo->nServerIndex;

	return 0;
}

char *CDBServer::GetRunServerAddr(char *pszRemote)
{
	for (int i = 0; i < MAXPLAYSERVER; i++)
	{
		if (strcmp(m_ServerConnInfo[i].szRemote, pszRemote) == 0)
		{
			if (strlen(m_ServerConnInfo[i].szAddr2))
			{
				if (strlen(m_ServerConnInfo[i].szAddr3))
				{
					switch (rand() % 3)
					{
						case 0: return m_ServerConnInfo[i].szAddr;
						case 1: return m_ServerConnInfo[i].szAddr2;
						case 2: return m_ServerConnInfo[i].szAddr3;
					}
				}
				else
				{
					if ((rand() % 2) == 0)
						return m_ServerConnInfo[i].szAddr;
					else
						return m_ServerConnInfo[i].szAddr2;
				}
			}
			else
				return m_ServerConnInfo[i].szAddr;
		}
	}

	return NULL;
}

int CDBServer::GetRunServerPort(char *pszRemote)
{
	for (int i = 0; i < MAXPLAYSERVER; i++)
	{
		if (strcmp(m_ServerConnInfo[i].szRemote, pszRemote) == 0)
		{
			if (strlen(m_ServerConnInfo[i].szAddr2))
			{
				if (strlen(m_ServerConnInfo[i].szAddr3))
				{
					switch (rand() % 3)
					{
						case 0: return m_ServerConnInfo[i].nPort;
						case 1: return m_ServerConnInfo[i].nPort2;
						case 2: return m_ServerConnInfo[i].nPort3;
					}
				}
				else
				{
					if ((rand() % 2) == 0)
						return m_ServerConnInfo[i].nPort;
					else
						return m_ServerConnInfo[i].nPort2;
				}
			}
			else
				return m_ServerConnInfo[i].nPort;
		}
	}

	return 0;
}
