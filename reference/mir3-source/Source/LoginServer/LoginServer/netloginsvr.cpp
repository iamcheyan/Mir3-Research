

#include "netloginsvr.h"
#include "loginsvrwnd.h"
#include <stringex.h>
#include <stdlib.h>
#include <stdio.h> 
#include <time.h>



#define TID_COUNTLOG		0
#define TIMER_COUNTLOG		1800000//000//10000
#define TID_CHECKSERVER		1
#define TIMER_CHECKSERVER	5000
#define TID_CHECKCERT		2
#define TIMER_CHECKCERT		1000
#define TID_CHECKEXPIRE		3
#define TIMER_CHECKEXPIRE	600000  //10 minute.


CGameServerInfo::CGameServerInfo()
{
	nMaxUserCount  =0;
	nFreemode = 0;
	nGateCount = 0;
	nCurrentIndex =0;
}


sTblSelectGateIP* CGameServerInfo::GetSelectGate()
{
	if(nGateCount ==0)
		return NULL;
	nCurrentIndex++;

	if(nCurrentIndex >= nGateCount)
		nCurrentIndex =0;

#ifdef _DEBUG
	GetApp()->SetLog( 0, "nCurrentIndex:%d/%d]", nCurrentIndex, nGateCount );
#endif	

		
	CListNode<sTblSelectGateIP> *pNode = m_listSelectGate.GetHead();
	int iCount = 0;
	for(; pNode;pNode = pNode->GetNext())
	{
		sTblSelectGateIP *pGateInfo = pNode->GetData();
		if(nCurrentIndex == iCount)
			return pGateInfo;
		iCount ++;
	}
	return NULL;
}


CLoginSvr::CLoginSvr()
{
	m_nTotalCount =0;
	m_nMaxTotalUserCount=0;

	strcpy(m_szGameType, "MIR2");
	m_nFreePeriods = 30;
	m_IsNotInServiceMode = false;		//추가 초기화 false

	CDBSvrOdbcPool::SetDiagRec( __cbDBMsg );
	m_listCheckServer.SetCompareFunction( __cbCmpCheckServer, NULL );
	m_listGameServer.SetCompareFunction( __cbCmpGameServer, NULL );
	m_listLoginGate.SetCompareFunction( __cbCmpLoginGate, NULL );

	//초기화 및 아이피세팅(지원팀 2개아이피)
	m_udpSender.InitUtpsocket();
	m_udpSender.SetReceiverIp1("172.20.4.77");
	m_udpSender.SetReceiverIp2("172.20.4.82");
//	m_udpSender.SetReceiverIp1("192.168.1.8");
//	m_udpSender.SetReceiverIp2("192.168.1.37");
//	m_udpSender.SetReceiverIp3("192.168.3.236");
//	m_udpSender.SetReceiverIp1("192.168.3.121");	//(sonmg 2005/04/06 수정됨)
//	m_udpSender.SetReceiverIp2("192.168.2.218");	//(sonmg 2005/04/06 수정됨)
//	m_udpSender.SetReceiverIp3("192.168.2.118");	//(sonmg 2005/04/06 수정됨)
//	m_udpSender.SetReceiverIp1("192.168.2.233");
//	m_udpSender.SetReceiverIp2("192.168.2.238");

	//0번 에러 발생시 체크서버에 응답없음 통보 여부.(2004/08/18)
	m_bSendErrorToCheckServer = false;
}


CLoginSvr::~CLoginSvr()
{
}


bool CLoginSvr::Startup()
{
	//
	// start logger
	//
	if ( !m_log.Create( "LoginSvr_", "Log" ) )
		return false;

	//
	// check configuration
	//
	if ( !GetCfg()->szOdbcDSN[0]	|| 
//		 !GetCfg()->szOdbcDSN_PC[0]	|| 
		 !GetCfg()->nCSbPort		||
		 !GetCfg()->nGSbPort		||
		 !GetCfg()->nLGbPort )
	{
		GetApp()->SetLog( CINFO, "%s %s %d %d %d ", GetCfg()->szOdbcDSN,GetCfg()->szOdbcDSN_PC,GetCfg()->nCSbPort,GetCfg()->nGSbPort,GetCfg()->nLGbPort);
		PostMessage( GetApp()->m_hWnd, WM_COMMAND, IDM_CONFIGURATION, 0 );
		return false;
	}

	//
	// initialize data structures
	//
	if ( !m_listCert.InitHashTable( MAX_HASHSIZE, IHT_ROUNDUP ) )
	{
		GetApp()->SetLog( CERR, "Failed to allocate hash table." );
		return false;
	}

	m_listCert.SetGetKeyFunction( __cbGetCertKey );
	
	//
	// initialize ODBC
	//
	if ( !m_dbPool.Startup( GetCfg()->szOdbcDSN, GetCfg()->szOdbcID, GetCfg()->szOdbcPW ) )
		return false;

	//
	// initialize ODBC for PC
	//
	if ( !m_dbPoolPC.Startup( GetCfg()->szOdbcDSN_PC, GetCfg()->szOdbcID_PC, GetCfg()->szOdbcPW_PC ) )
		return false;


	if ( !LoadDBTables() )
		return false;

	//
	// initialize IOCP handler (not use event dispatcher)
	//
	if ( !Init() )
	{
		GetApp()->SetErr( GetLastError() );
		return false;
	}

	//
	// start listen
	//
	if ( !m_csAcceptor.Init( CSockAddr( GetCfg()->nCSbPort ) )	||
		 !Accept( &m_csAcceptor )								||
		 !m_gsAcceptor.Init( CSockAddr( GetCfg()->nGSbPort ) )	||
		 !Accept( &m_gsAcceptor )								||
		 !m_lgAcceptor.Init( CSockAddr( GetCfg()->nLGbPort ) )	||
		 !Accept( &m_lgAcceptor ) )
	{
		GetApp()->SetErr( GetLastError() );
		return false;
	}

	//
	// start timer
	//
	SetTimer( GetApp()->m_hWnd, TID_COUNTLOG, TIMER_COUNTLOG, NULL );
	SetTimer( GetApp()->m_hWnd, TID_CHECKSERVER, TIMER_CHECKSERVER, NULL );
	SetTimer( GetApp()->m_hWnd, TID_CHECKCERT , TIMER_CHECKCERT, NULL);
//	SetTimer( GetApp()->m_hWnd, TID_CHECKEXPIRE, TIMER_CHECKEXPIRE, NULL);

	//
	// success!!
	//
	GetApp()->SetLog( CINFO, "Login Server initialized." );
	GetApp()->SetStatus( "Running.." );
	
#ifdef _DEBUG
	GetApp()->SetLog( CDBG, 
		"Login Server is running in Debug Mode. This will puts all input/output packets." );
#endif

	//0번 에러 발생시 체크서버에 응답없음 통보 여부.(2004/08/18)
	m_bSendErrorToCheckServer = false;

	return true;
}


void CLoginSvr::Cleanup()
{
	//
	// free timer
	//
	KillTimer( GetApp()->m_hWnd, TID_COUNTLOG );
	KillTimer( GetApp()->m_hWnd, TID_CHECKSERVER );
	KillTimer( GetApp()->m_hWnd, TID_CHECKCERT );
//	KillTimer( GetApp()->m_hWnd, TID_CHECKEXPIRE); // 2004-07-08

	//
	// release IOCP handler
	//
	Uninit();

	//
	// release network objects and linked resources
	// 
	m_listLoginGate.ClearAll();
	m_lgAcceptor.Uninit();
	m_listGameServer.ClearAll();
	m_gsAcceptor.Uninit();
	m_listCheckServer.ClearAll();
	m_csAcceptor.Uninit();

	//
	// release ODBC resources
	//
	m_listGateIP.ClearAll();
	m_listServerIP.ClearAll();
	m_dbPool.Cleanup();
	m_dbPoolPC.Cleanup();

	//
	// free data structures
	//
	m_listCert.UninitHashTable();

	//
	// success!!
	//
	GetApp()->SetLog( CINFO, "Login Server finalized." );
	GetApp()->SetStatus( "Ready.." );

	//
	// close log file
	//
	m_log.Close();
}


void CLoginSvr::OnError( int nErrCode )
{
	GetApp()->SetErr( nErrCode );
}




int  CLoginSvr::RecalUserCount(char *pszServerName)
{
	int nUserCount = 0;

	CListNode< CGameServer > *pNode = GetLoginServer()->m_listGameServer.GetHead();
	GetLoginServer()->m_listGameServer.Lock();
	pNode = GetLoginServer()->m_listGameServer.GetHead();
	for ( ; pNode; pNode = pNode->GetNext() )
	{
		CGameServer *pObj = pNode->GetData();
		
		if(pObj)
		{
			
			if ( stricmp( pObj->m_dbInfo.szName, pszServerName ) == 0 )
			{
				nUserCount = nUserCount + pObj->m_nCurUserCnt;
				
			}
		}
	}
	GetLoginServer()->m_listGameServer.Unlock();
	return nUserCount;
}

int CLoginSvr::GetTotalUserCount()
{
	int nTotalUserCount =0;

	CListNode< CGameServer > *pNode = m_listGameServer.GetHead();	
	m_listGameServer.Lock();
	pNode = GetLoginServer()->m_listGameServer.GetHead();

	for ( ; pNode; pNode = pNode->GetNext() )
	{
		CGameServer *pGameServer = pNode->GetData();
		if(pGameServer)
			nTotalUserCount += pGameServer->m_nCurUserCnt;
	}
	m_listGameServer.Unlock();
	m_nTotalCount = nTotalUserCount;
	return m_nTotalCount;
}


bool CLoginSvr::WriteConLog(char *pszLoginid, char *pszIP)
{
	char szQuery[256];
	CConnection *pConn = m_dbPool.Alloc();
	if ( !pConn )
		return false;

	sprintf(szQuery,"INSERT INTO TBL_CONNECTLOGS(FLD_LOGINID, FLD_LOGINIP, FLD_LOGINTIME, FLD_GAMETYPE) VALUES('%s', '%s',GetDate(),'%s')", pszLoginid, pszIP, m_szGameType);
#ifdef _DEBUG
	GetApp()->SetLog( 0, "[SQL QUERY] %s", szQuery);
#endif
	CRecordset *pRec = pConn->CreateRecordset();
	pRec->Execute(szQuery);
	pConn->DestroyRecordset(pRec );
	m_dbPool.Free( pConn );
	return true;

}
  

bool CLoginSvr::SaveCountLog()
{
	char szQuery[256];
	
	CConnection *pConn = m_dbPool.Alloc();
	if ( !pConn )
	{
#ifdef _EX_DEBUG
		GetApp()->SetLog( CDBG, "에러! TID_COUNTLOG DB 연결 할당 실패!! %s %d\n", __FILE__, __LINE__ );
#endif
		return false;
	}
	
	sprintf(szQuery, "INSERT INTO TBL_COUNTLOGS (FLD_TIME,"
					" FLD_COUNT, FLD_MAXCOUNT, FLD_GAMETYPE) VALUES( GetDate(), %d, %d,'%s')" 
					, m_nTotalCount,m_nMaxTotalUserCount, m_szGameType);

	CRecordset *pRec = pConn->CreateRecordset();
#ifdef _DEBUG
	GetApp()->SetLog(0,"[SQL QUERY] %s", szQuery);
#endif

	if ( !pRec->Execute(szQuery) )
	{
#ifdef _EX_DEBUG
		GetApp()->SetLog( CDBG, "에러! TID_COUNTLOG DB INSERT 쿼리 실패!! %s %d\n", __FILE__, __LINE__ );
#endif
	}
#ifdef _EX_DEBUG
	else if ( pRec->GetRowCount() == 0 )
	{
		GetApp()->SetLog( CDBG, "에러! TID_COUNTLOG DB INSERT ROWCOUNT = 0!! %s %d\n", __FILE__, __LINE__ );
	}	
#endif

	pConn->DestroyRecordset(pRec );
	m_dbPool.Free( pConn );


	m_nMaxTotalUserCount = 0;

	CListNode< CGameServer > *pNode;
	
#ifdef _EX_DEBUG
		GetApp()->SetLog( CDBG, "TID_COUNTLOG m_listGameServer 진입 시도!! %s %d\n", __FILE__, __LINE__ );
#endif
	m_listGameServer.Lock();
#ifdef _EX_DEBUG
		GetApp()->SetLog( CDBG, "TID_COUNTLOG m_listGameServer 진입!! %s %d\n", __FILE__, __LINE__ );
#endif
	pNode = GetLoginServer()->m_listGameServer.GetHead();
	
	for ( ; pNode; pNode = pNode->GetNext() )
	{
		CGameServer *pGameServer = pNode->GetData();
		if(pGameServer)
			pGameServer->SaveServerUserCount();
	}
	m_listGameServer.Unlock();
#ifdef _EX_DEBUG
		GetApp()->SetLog( CDBG, "TID_COUNTLOG m_listGameServer 해제!! %s %d\n", __FILE__, __LINE__ );
#endif
	
	return true;
}




CIocpObject * CLoginSvr::OnAccept( CIocpAcceptor *pAcceptor, SOCKET sdClient )
{
	if ( pAcceptor == &m_csAcceptor )
	{
		CCheckServer *pObject = new CCheckServer( sdClient );
		if ( !pObject )
			return NULL;

		m_listCheckServer.Lock();
		if ( !m_listCheckServer.Insert( pObject ) )
		{
			delete pObject;
			pObject = NULL;
		}
		else
		{
			GetApp()->SetLog( 0, "[CheckServer/Connect] CheckServer connected. [(%s):(%d)])", 
				pObject->IP(), pObject->Port() );
		}
		m_listCheckServer.Unlock();

		return pObject;
	}
	else if ( pAcceptor == &m_gsAcceptor )
	{		
		sTblPubIP *pGateInfo = FindGateInfo( sdClient );
		if ( !pGateInfo )
		{
			GetApp()->SetLog( CERR, "Unindentified GameServer has tried connection." );
			return NULL;
		}

		sTblSvrIP *pSvrInfo = new sTblSvrIP;
		ZeroMemory(pSvrInfo, sizeof(sTblSvrIP));

		CGameServer *pObject = new CGameServer( sdClient, pGateInfo->szIP );
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
			GetApp()->SetLog( 0, "[GameServer/Conn] GameServer connected. (%s):(%d)", 
				pObject->IP(), pObject->Port() );
		}
		m_listGameServer.Unlock();

		return pObject;
	}
	else if ( pAcceptor == &m_lgAcceptor )
	{
		sTblPubIP *pGateInfo = FindGateInfo( sdClient );
		if ( !pGateInfo )
		{
			// 2003/04/09 에러 메세지 수정
			CSockAddr sdAddr;
			int nAddrLen = sizeof( CSockAddr );
			getpeername( sdClient, &sdAddr, &nAddrLen );
			char *pPeerIP = sdAddr.IP();

			GetApp()->SetLog( CERR, "Unindentified LoginGate has tried connection. (%s):(%d)", pPeerIP );
			return NULL;
		}

		CLoginGate *pObject = new CLoginGate( sdClient, pGateInfo );
		if ( !pObject )
			return NULL;

		m_listLoginGate.Lock();
		if ( !m_listLoginGate.Insert( pObject ) )
		{
			delete pObject;
			pObject = NULL;
		}
		else
		{
			GetApp()->SetLog( 0, "[LoginGate/Conn] LoginGate connected.(%s):(%d)", 
				pObject->IP(), pObject->Port() );
		}
		m_listLoginGate.Unlock();

		return pObject;
	}
	
	return NULL;
}


void CLoginSvr::OnAcceptError( CIocpAcceptor *pAcceptor, int nErrCode )
{
	GetApp()->SetErr( nErrCode );
}


void CLoginSvr::OnClose( CIocpObject *pObject )
{
	switch ( pObject->GetClassId() )
	{
	case CCheckServer::CLASSID:
		GetApp()->SetLog( CERR, "CheckServer disconnected. [%s:%d]", pObject->IP(), pObject->Port() );
		m_listCheckServer.Lock();
		delete m_listCheckServer.Remove( (CCheckServer *) pObject );
		m_listCheckServer.Unlock();
		break;

	case CGameServer::CLASSID:
		GetApp()->SetLog( CERR, "GameServer(or ISM_ Server) disconnected.[%s:%d]", pObject->IP(), pObject->Port() );
		m_listGameServer.Lock();
		delete m_listGameServer.Remove( (CGameServer *) pObject );
		m_listGameServer.Unlock();
		break;

	case CLoginGate::CLASSID:
		GetApp()->SetLog( CERR, "LoginGate disconnected.[%s:%d] ", pObject->IP(), pObject->Port() );
		m_listLoginGate.Lock();
		delete m_listLoginGate.Remove( (CLoginGate *) pObject );
		m_listLoginGate.Unlock();
		break;
	}
}


void CLoginSvr::OnTimer( int nTimerID )
{
	switch ( nTimerID )
	{
	case TID_COUNTLOG:
		SaveCountLog();
		break;

	case TID_CHECKSERVER:
#ifdef _EX_DEBUG
		GetApp()->SetLog( CDBG, "TID_CHECKSERVER m_listCheckServer 진입 시도!! %s %d\n", __FILE__, __LINE__ );
#endif
		m_listCheckServer.Lock();
#ifdef _EX_DEBUG
		GetApp()->SetLog( CDBG, "TID_CHECKSERVER m_listCheckServer 진입!! %s %d\n", __FILE__, __LINE__ );
#endif
		{
			CListNode< CCheckServer > *pNode = m_listCheckServer.GetHead();

			for ( ; pNode; pNode = pNode->GetNext() )
			{
				CCheckServer *pObj = pNode->GetData();
				if(pObj)
					pObj->SendServerStatus();
			}
		}
		m_listCheckServer.Unlock();
#ifdef _EX_DEBUG
		GetApp()->SetLog( CDBG, "TID_CHECKSERVER m_listCheckServer 해제!! %s %d\n", __FILE__, __LINE__ );
#endif

		break;
	case TID_CHECKCERT :
		CheckCertListTimeOuts();
		break;
	case TID_CHECKEXPIRE:
		// 현재 Timer 실행되지 않음...
		CheckAccountExpire();
		/* 2003/02/03 중복 아이피 체크
//		CheckDupIPs();
		*/
		break;
	}
}


bool CLoginSvr::LoadDBTables()
{
	CConnection *pConn = m_dbPool.Alloc();
	if ( !pConn )
		return false;
/*
	CRecordset *pRec = pConn->CreateRecordset();
	if ( pRec->Execute( "SELECT * FROM TBL_SERVERIPS" ) )
	{
		//GetApp()->SetLog( 0, "SELECT * FROM TBL_SERVERIPS");
		while ( pRec->Fetch() )
		{
			sTblSvrIP *pSvrInfo = new sTblSvrIP;
			memset( pSvrInfo, 0, sizeof( sTblSvrIP ) );

			strcpy( pSvrInfo->szName, pRec->Get( "FLD_NAME" ) );
			strcpy( pSvrInfo->szIP, pRec->Get( "FLD_SERVERIP" ) );
			pSvrInfo->nID			= atoi( pRec->Get( "FLD_INDEX" ) );

			m_listServerIP.Insert( pSvrInfo );
		}
	}
	pConn->DestroyRecordset( pRec );*/
	
	CRecordset *pRec = pConn->CreateRecordset();
	char szQuery[100];
	sprintf(szQuery, "SELECT * FROM TBL_PUBIPS WHERE FLD_GAMETYPE='%s'",m_szGameType) ;
#ifdef _DEBUG
	GetApp()->SetLog(0,"[SQL QUERY] %s", szQuery);
#endif

					

	if ( pRec->Execute( szQuery ))
	{	
#ifdef _DEBUG
		GetApp()->SetLog( 0, "[SQL QUERY] %s", szQuery);
#endif
		while ( pRec->Fetch() )
		{
			sTblPubIP *pGateInfo = new sTblPubIP;
			memset( pGateInfo, 0, sizeof( sTblPubIP ) );

			bstr szPubIp			= pRec->Get( "FLD_PUBIP" );
			_trim(szPubIp);

			strcpy( pGateInfo->szIP, szPubIp );
			strcpy( pGateInfo->szDesc, pRec->Get( "FLD_DESCRIPTION" ) );
			// COPark...			
#ifdef _DEBUG
			GetApp()->SetLog( 0, "[PUBIPS] %s(%s)", pGateInfo->szDesc, pGateInfo->szIP);
#endif
			m_listGateIP.Insert( pGateInfo );
		}
	}
	pConn->DestroyRecordset( pRec );


	pRec = pConn->CreateRecordset();
	
	sprintf(szQuery, "SELECT * FROM TBL_SERVERINFO WHERE FLD_GAMETYPE='%s'",m_szGameType);
#ifdef _DEBUG
	GetApp()->SetLog(0,"[SQL QUERY] %s", szQuery);
#endif

	if(pRec->Execute(szQuery))
	{
		while(pRec->Fetch())
		{
			CGameServerInfo *pServerInfo = new CGameServerInfo;
			
			bstr szName = pRec->Get("FLD_SERVERNAME");
			_trim(szName);
			strcpy(pServerInfo->szName, szName);
			pServerInfo->nFreemode =  atoi(pRec->Get("FLD_FREEMODE"));
			pServerInfo->nMaxUserCount = atoi(pRec->Get("FLD_MAXUSERCOUNT"));
			pServerInfo->nGateCount = 0;
			pServerInfo->nCurrentIndex =0;
			
			m_listServerInfo.Insert(pServerInfo);

			
			sprintf(szQuery, "SELECT * FROM TBL_SELECTGATEIPS WHERE FLD_NAME = '%s' AND FLD_GAMETYPE='%s'", pServerInfo->szName, m_szGameType);
#ifdef _DEBUG
	GetApp()->SetLog(0,"[SQL QUERY] %s", szQuery);
#endif

			CConnection *pGateConn = m_dbPool.Alloc();
			CRecordset *pGateRec = pGateConn->CreateRecordset();
			if(pGateRec->Execute(szQuery))
			{
				while ( pGateRec->Fetch() )
				{
					pServerInfo->nGateCount ++;
					sTblSelectGateIP *pSelectGateInfo = new sTblSelectGateIP;
					memset( pSelectGateInfo, 0, sizeof( sTblSelectGateIP ));
					pSelectGateInfo->nPort	= atoi(pGateRec->Get("FLD_PORT"));
					bstr szServerName		= pGateRec->Get( "FLD_NAME" );
					bstr szServerIP			= pGateRec->Get( "FLD_IP" );
					
					
					_trim(szServerName);
					_trim(szServerIP);
					
					// COPark...			
					strcpy(pSelectGateInfo->szIP, szServerIP);
					strcpy(pSelectGateInfo->szName, szServerName);
#ifdef _DEBUG
					GetApp()->SetLog( 0, "[SELECTGATEIPS] %s(%s)", pSelectGateInfo->szName, pSelectGateInfo->szIP);
#endif
					pServerInfo->m_listSelectGate.Insert( pSelectGateInfo );
				}
			}
			pGateConn->DestroyRecordset( pGateRec );
			m_dbPool.Free( pGateConn );
		}

	}

	pConn->DestroyRecordset( pRec );

	
	m_dbPool.Free( pConn );

//	if ( m_listServerIP.IsEmpty() || m_listGateIP.IsEmpty() )
//		return false;

	return true;
}


sTblSvrIP * CLoginSvr::FindServerInfo( SOCKET sdPeer )
{
	CSockAddr sdAddr;
	int nAddrLen = sizeof( CSockAddr );
	getpeername( sdPeer, &sdAddr, &nAddrLen );
	
	char *pPeerIP = sdAddr.IP();

	CListNode< sTblSvrIP > *pNode;
	for ( pNode = m_listServerIP.GetHead(); pNode; pNode = pNode->GetNext() )
	{
		sTblSvrIP *pObj = pNode->GetData();
		
		if(pObj)
		{
			if ( stricmp( pObj->szIP, pPeerIP ) == 0 )
				return pObj;
		}
	}

	return NULL;
}


sTblPubIP * CLoginSvr::FindGateInfo( SOCKET sdPeer )
{
	CSockAddr sdAddr;
	int nAddrLen = sizeof( CSockAddr );
	getpeername( sdPeer, &sdAddr, &nAddrLen );
	
	char *pPeerIP = sdAddr.IP();

	CListNode< sTblPubIP > *pNode;
	for ( pNode = m_listGateIP.GetHead(); pNode; pNode = pNode->GetNext() )
	{
		sTblPubIP *pObj = pNode->GetData();

		if(pObj)
		{
			if ( stricmp( pObj->szIP, pPeerIP ) == 0 )
				return pObj;
		}
	}

	return NULL;
}


bool CLoginSvr::AddCertUser( sGateUser *pUser )
{
	sCertUser *pCert = new sCertUser;
	SYSTEMTIME st;
    GetLocalTime(&st);	//GetSystemTime
	int nCurrentTime = GetDay(st.wYear, st.wMonth, st.wDay);

	memset( pCert, 0, sizeof( sCertUser ) );

	strcpy( pCert->szLoginID, pUser->szID );
	strcpy( pCert->szUserAddr, pUser->szAddr );

	int iRemaindId = __max(pUser->dwValidUntil     , pUser->dwMValidUntil) - nCurrentTime;
	int iRemaindFreeId = __max(pUser->dwFreeValidUntil     , pUser->dwFreeMValidUntil) - nCurrentTime;
	int iRemaindIp = __max(pUser->dwIpValidUntil   , pUser->dwIpMValidUntil) - nCurrentTime;

	pCert->nIDHour = pUser->dwSeconds      + pUser->dwMSeconds
					+pUser->dwFreeSeconds      + pUser->dwFreeMSeconds;	//무료통합정량, 무료Mir2정량 추가
	//피씨방은 -50시간까지 허용한다
	pCert->nIPHour = pUser->dwIpSeconds    + 180000;	//+ pUser->dwIpMSeconds 
	pCert->nIPDay  = iRemaindIp;//pUser->dwIpValidUntil - nCurrentTime;
	pCert->nIDDay  = __max(iRemaindId, iRemaindFreeId);//pUser->dwValidUntil   - nCurrentTime;

	pUser->nAvailableType = 5;
	// 2003/02/06
//  if (pCert->nIDHour > 0) pUser->nAvailableType = 2;
	if(pUser->dwSeconds > 0) pUser->nAvailableType = 2;
	if(pUser->dwMSeconds> 0) pUser->nAvailableType = 6;	// Mir2 정량

	// 새로 추가된 Sect(2004/06/11)
	if(pUser->dwFreeSeconds > 0) pUser->nAvailableType = 8;	// 무료 통합 정량
	if(pUser->dwFreeMSeconds> 0) pUser->nAvailableType = 9;	// 무료 Mir2 정량

	if (pCert->nIPHour > 0) pUser->nAvailableType = 4;
    if (pCert->nIPDay > 0)  pUser->nAvailableType = 3;
    if (pCert->nIDDay > 0)
	{
		if( iRemaindId > iRemaindFreeId )
			pUser->nAvailableType = 1;
		else
			pUser->nAvailableType = 5;
	}

	pCert->nCertification		= pUser->nCertification;
	pCert->nOpenTime			= GetTickCount();
	pCert->nAccountCheckTime	= GetTickCount();
	pCert->nAvailableType		= pUser->nAvailableType;
	pCert->bClosing = false;

	pUser->dwOpenTime			= pCert->nOpenTime;

	m_csListCert.Lock();
	bool bRet = m_listCert.Insert( pCert );
	m_csListCert.Unlock();

	return bRet;
}


bool CLoginSvr::SendCancelAdmissionUser( sCertUser *pCert )
{
	if ( pCert->bClosing )
		return true;

	int __CNT1 = 0, __CNT2 = 0;

	m_listGameServer.Lock();
	{
		CListNode< CGameServer > *pNode = GetLoginServer()->m_listGameServer.GetHead();
		for ( ; pNode; pNode = pNode->GetNext() )
		{
			CGameServer *pObj = pNode->GetData();
			if(pObj)
				if(strcmp(pObj->m_dbInfo.szName, pCert->szServerName)==0)
				{
					if ( pObj->SendCancelAdmissionCert( pCert ) )
						__CNT1++;
					else
						__CNT2++;
				}
		}	
	}
	m_listGameServer.Unlock();

/*	FILE *fp = fopen( "d:\\Admission.txt", "ab" );
	fprintf( fp, "==> Result: %d %d\r\n\r\n", __CNT1, __CNT2 );
	fclose( fp );*/

	return true;
}

bool CLoginSvr::SendAccountExpireUser( sCertUser *pCert )
{
	if ( pCert->bClosing )
		return true;

	CListNode< CGameServer > *pNode;

	m_listGameServer.Lock();
	pNode = m_listGameServer.GetHead();
	
	for ( ; pNode; pNode = pNode->GetNext() )
	{
		CGameServer *pGameServer = pNode->GetData();
		
		if(pGameServer)
		{
			
			if ( stricmp( pGameServer->m_dbInfo.szName, pCert->szServerName ) == 0 )
				pGameServer->SendAccountExpire( pCert );
		}
	}
	m_listGameServer.Unlock();

	return true;
}



void CLoginSvr::CheckCertListTimeOuts()
{
#ifdef _EX_DEBUG
	GetApp()->SetLog( CDBG, "TID_CHECKCERT m_csListCert 진입 시도!! %s %d\n", __FILE__, __LINE__ );
#endif
	m_csListCert.Lock();
#ifdef _EX_DEBUG
	GetApp()->SetLog( CDBG, "TID_CHECKCERT m_csListCert 진입!! %s %d\n", __FILE__, __LINE__ );
#endif

	CListNode< sCertUser > *pTemp;
	CListNode< sCertUser > *pNode = m_listCert.GetHead();

	while ( pNode )
	{
		sCertUser *pUser = pNode->GetData();
		
		if ( pUser->bClosing && (GetTickCount() - pUser->nOpenTime > 5000) )
		{
#ifdef _DEBUG
			GetApp()->SetLog( 0, "DELETE CERTINFO LOGINID:  %s",pUser->szLoginID);
#endif

			pTemp = pNode->GetNext();
			sCertUser *pDelUser = m_listCert.Remove( (sCertUser *) pUser->szLoginID );
			if ( pDelUser )
				delete pDelUser;
			pNode = pTemp;
		}
		else
			pNode = pNode->GetNext();
	}
	
	m_csListCert.Unlock();
#ifdef _EX_DEBUG
	GetApp()->SetLog( CDBG, "TID_CHECKCERT m_csListCert 해제!! %s %d\n", __FILE__, __LINE__ );
#endif
}

void CLoginSvr::CheckAccountExpire()
{
	CListNode<sCertUser> *pNode = m_listCert.GetHead();
	while(pNode)
	{
		sCertUser *pUser = pNode->GetData();

#ifdef _DEBUG
	GetApp()->SetLog( CDBG, "[CheckAccountExpire] freemode : %d, availabletype : %d, opentime : %d, idhour : %d", pUser->bFreeMode, pUser->nAvailableType, pUser->nOpenTime, pUser->nIDHour);
#endif
		
		if(!pUser->bFreeMode)
		{
			// 2:개인정량, 6:미르2정량, 7:미르3정량, 8:무료통합정량, 9:무료미르2정량, 10:무료미르3정량
			if( ((pUser->nAvailableType == 2) || ((pUser->nAvailableType >= 6) && (pUser->nAvailableType <= 10)))
				&& ((GetTickCount() - pUser->nOpenTime) > (pUser->nIDHour*1000 /*+ 100*1000*/)) )	// 100초 플러스 시간
			{

//testcode
GetApp()->SetLog( CDBG, "[SendAccountExpireUser] Now - OpenTime : %d, IDHour(Sec) : %d", GetTickCount()-pUser->nOpenTime, pUser->nIDHour);

				SendAccountExpireUser( pUser );

				// delete GetLoginServer()->m_listCert.Remove( pUser );
			}
		}
		pNode = pNode->GetNext();
	}
	
	return;
}	
/*
void CLoginSvr::CheckAccountExpire()
{
#ifdef _EX_DEBUG
	GetApp()->SetLog( CDBG, "TID_CHECKEXPIRE m_csListCert 진입 시도!! %s %d\n", __FILE__, __LINE__ );
#endif
	m_csListCert.Lock();
#ifdef _EX_DEBUG
	GetApp()->SetLog( CDBG, "TID_CHECKEXPIRE m_csListCert 진입!! %s %d\n", __FILE__, __LINE__ );
#endif	
	CListNode<sCertUser> *pNode = m_listCert.GetHead();
	while(pNode)
	{
		sCertUser *pUser = pNode->GetData();
		
		if((!pUser->bFreeMode) &&(!pUser->bClosing))
		{
			// 2003/03/31 6번 미르2개인정량 추가 확인
			//개인정량
			if( ((pUser->nAvailableType == 2) &&(GetTickCount() - pUser->nOpenTime > pUser->nIDHour)) ||
			    ((pUser->nAvailableType == 6) &&(GetTickCount() - pUser->nOpenTime > pUser->nIDHour)) ||
				((pUser->nAvailableType == 4) &&(GetTickCount() - pUser->nOpenTime > pUser->nIPHour)) )
			{
				
//	FILE *fp = fopen( "d:\\Admission.txt", "ab" );
//	fprintf( fp, "CLoginSvr::CheckCertListTimeOuts\r\n" );
//	fclose( fp );

				SendCancelAdmissionUser( pUser );
				pUser->bClosing = true;
				pUser->nOpenTime = GetTickCount();
				SendAccountExpireUser( pUser );
			}
		}
		pNode = pNode->GetNext();
	}
	m_csListCert.Unlock();
#ifdef _EX_DEBUG
	GetApp()->SetLog( CDBG, "TID_CHECKEXPIRE m_csListCert 해제!! %s %d\n", __FILE__, __LINE__ );
#endif

	return;
}	
*/

void CLoginSvr::CheckDupIPs()
{
#ifdef _DEBUG
	OutputDebugString("[CheckDupIPs] Entered\n");
#endif
	CConnection *pConnPC = m_dbPoolPC.Alloc();
	bool bKickOK = false;

	if ( !pConnPC )
		return;

	char szQuery[1024];
	SYSTEMTIME st;
    GetLocalTime(&st);	//GetSystemTime
	int nCurrentTime = GetDay(st.wYear, st.wMonth, st.wDay);
	CRecordset *pRec = NULL;
	CRecordset *pRecLoop = NULL;

	sprintf( szQuery, "SELECT * FROM TBL_DUPIP WHERE FLD_GAMETYPE='%s' AND FLD_ISOK='0'", m_szGameType );
#ifdef _DEBUG
	GetApp()->SetLog( 0, "[SQL QUERY] %s", szQuery);
#endif
	pRecLoop = pConnPC->CreateRecordset();
	if ( pRecLoop->Execute( szQuery ) )
	{
		while (pRecLoop->Fetch() )
		{
			// Kick 해야 할 중복 IP가 있는 경우 Using IP에서 확인하여 해당 ID를 Kick
			char szIP[25];
			char szID[25];

			bKickOK = false;
			strcpy(szIP, pRecLoop->Get( "FLD_IP" ));

			sprintf( szQuery, "SELECT * FROM TBL_USINGIP WHERE FLD_USINGIP='%s' AND FLD_GAMETYPE='%s'", szIP, m_szGameType );
			pRec = pConnPC->CreateRecordset();
#ifdef _DEBUG
			GetApp()->SetLog( 0, "[SQL QUERY] %s", szQuery);
#endif
			if ( pRec->Execute( szQuery ) && pRec->Fetch() )
			{
				strcpy(szID, pRec->Get( "FLD_USERID" ));
				// Kick
				m_csListCert.Lock();
				sCertUser *psCertUser = m_listCert.SearchKey( szID );

				if (psCertUser)
				{
					SendCancelAdmissionUser( psCertUser );
					psCertUser->bClosing = true;
					if (!psCertUser->bClosing)
						psCertUser->nOpenTime = GetTickCount();
					bKickOK = true;
				}
				m_csListCert.Unlock();
			}
			pConnPC->DestroyRecordset( pRec );
			// Update TBL_DUPIP...킥이 되었던 않되었던 DUPIP에서 제외
//			if(bKickOK)
			{
				sprintf( szQuery, "UPDATE TBL_DUPIP SET FLD_ISOK='1', FLD_KICK=GetDate() WHERE FLD_IP='%s' AND FLD_GAMETYPE='%s' AND FLD_ISOK='0'", szIP, m_szGameType );
				pRec = pConnPC->CreateRecordset();
#ifdef _DEBUG
				GetApp()->SetLog( 0, "[SQL QUERY] %s", szQuery);
#endif
				if (pRec)
					pRec->Execute( szQuery );
				pConnPC->DestroyRecordset( pRec );
			}
		}
	}
	pConnPC->DestroyRecordset( pRecLoop );
	m_dbPoolPC.Free( pConnPC );
#ifdef _DEBUG
	OutputDebugString("[CheckDupIPs] Exit\n");
#endif
}

void CLoginSvr::DelCertUser( sGateUser *pUser )
{
	m_csListCert.Lock();
	sCertUser *pCert = m_listCert.Remove( (sCertUser *) pUser->szID );
	if ( pCert )
	{
		delete pCert;
	}
	m_csListCert.Unlock();
}


void CLoginSvr::__cbDBMsg( char *pState, int nErrCode, char *pDesc )
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

	// 로그 파일 열기
	if( GetLoginServer()->m_log2.Create( "ErrorCode_", "Log" ) )
	{
		// 파일 로그
		if ( GetLoginServer()->m_log2.m_pFile )
			GetLoginServer()->m_log2.Log( pDesc );//, true );

		// 파일 닫기
		GetLoginServer()->m_log2.Close();
	}

	//ErrorCode == 0 일때 처리
	if( nErrCode == 0 )
	{
		GetLoginServer()->m_bSendErrorToCheckServer = true;		
//		PostMessage( GetApp()->m_hWnd, WM_COMMAND, IDM_STOPSERVICE, 0 );
//		PostMessage( GetApp()->m_hWnd, WM_COMMAND, IDM_STARTSERVICE, 0 );
	}
	//-------------------------------------------------------------------------

	GetApp()->SetLog( CERR, pDesc );
}


int CLoginSvr::__cbCmpCheckServer( void *pArg, CCheckServer *pFirst, CCheckServer *pSecond )
{
	return pFirst - pSecond;
}


int CLoginSvr::__cbCmpGameServer( void *pArg, CGameServer *pFirst, CGameServer *pSecond )
{
	return pFirst - pSecond;
}


int CLoginSvr::__cbCmpLoginGate( void *pArg, CLoginGate *pFirst, CLoginGate *pSecond )
{
	return pFirst - pSecond;
}


char * CLoginSvr::__cbGetCertKey( sCertUser *pObj )
{
	return (char *) pObj->szLoginID;
}

bool CLoginSvr::CheckBadAccount(char szLoginid[30])
{
	char szQuery[1024];
	CConnection *pConn = m_dbPool.Alloc();
	if ( !pConn )
		return false;
	CRecordset *pCheckRec = pConn->CreateRecordset();
	sprintf(szQuery, "SELECT FLD_ID FROM TBL_CONNCHECKUSER WHERE FLD_ID='%s' AND FLD_ISDEL=0", szLoginid);	
	//sprintf(szQuery, "SELECT Getdate()");	
#ifdef _DEBUG
	GetApp()->SetLog( 0, "[SQL QUERY] %s", szQuery);
#endif	

	if(pCheckRec->Execute(szQuery))
	{
		if (pCheckRec->Fetch() )
		{
			pConn->DestroyRecordset( pCheckRec );
			m_dbPool.Free( pConn );
			return true;
		}
	}
	pConn->DestroyRecordset( pCheckRec );
	m_dbPool.Free( pConn );
	return false;

}
