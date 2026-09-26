

#include "netgameserver.h"
#include "loginsvrwnd.h"
#include <stringex.h>
#include <stdlib.h>
#include <stdio.h>
#include <TIME.H>
#include "../common/mir2packet.h"


static struct sGameServerCmdList
{
	int  nPacketID;
	bool (CGameServer:: *pfn)( char *pBody );
} g_cmdList[] = 
{
	ISM_USERCLOSED,	CGameServer::OnUserClosed,
	ISM_USERCOUNT,	CGameServer::OnUserCount,
	ISM_GAMETIMEOFTIMECARDUSER, CGameServer::OnGameTimeOfTimeUser,
	ISM_CHECKTIMEACCOUNT,	CGameServer::OnCheckTimeAccount,
	ISM_REQUEST_PUBLICKEY,	CGameServer::OnRequestPublicKey,
	ISM_PREMIUMCHECK,	CGameServer::OnPremiumCheck,
	ISM_EVENTCHECK,		CGameServer::OnEventCheck,
};


static const int g_nCmdCnt = sizeof( g_cmdList ) / sizeof( g_cmdList[0] );


CGameServer::CGameServer( SOCKET sdClient, char *szIP )
{
	SetClassId( CLASSID );
	SetAcceptedSocket( sdClient );


	strcpy(m_dbInfo.szIP, szIP);
	m_dbInfo.nID = 0;
	strcpy(m_dbInfo.szName , "");
	m_nCurUserCnt		= 0;
	m_nMaxUserCnt		= 0;
	m_nCntInvalidPacket	= 0;
	m_nLastTick			= GetTickCount();
}


CGameServer::~CGameServer()
{
}


bool CGameServer::SendCancelAdmissionCert( sCertUser *pUser )
{
	CMir2Packet *pPacket = new CMir2Packet;
	pPacket->Attach( '(' );
	pPacket->Attach( ISM_CANCELADMISSION );
	pPacket->Attach( '/' );
	pPacket->Attach( pUser->szLoginID );
	pPacket->Attach( '/' );
	pPacket->Attach( pUser->nCertification );
	pPacket->Attach( ')' );
#ifdef _DEBUG
	GetApp()->SetLog(0,"[GameServer/Send] ISM_CANCELADMISSION : %s TO (%s)", pUser->szLoginID , this->m_dbInfo.szIP);
#endif	
	Lock();
	bool bRet = Send( pPacket );
	Unlock();

/*	FILE *fp = fopen( "d:\\Admission.txt", "ab" );
	fprintf( fp, "[%s] [%s:%d] %s\r\n", pUser->szLoginID, IP(), Port(), pPacket->m_pPacket );
	fclose( fp );*/

	return bRet;
}

bool CGameServer::SendAccountExpire( sCertUser *pUser )
{
	CMir2Packet *pPacket = new CMir2Packet;
	pPacket->Attach( '(' );
	pPacket->Attach( ISM_ACCOUNTEXPIRED );
	pPacket->Attach( '/' );
	pPacket->Attach(pUser->szLoginID );
	pPacket->Attach( '/' );
	pPacket->Attach( pUser->nCertification );
	pPacket->Attach( ')' );
//#ifdef _DEBUG
	GetApp()->SetLog(0,"[GameServer/Send] ISM_ACCOUNTEXPIRED :%s TO (%s)",pUser->szLoginID, this->m_dbInfo.szIP );
//#endif	
	Lock();
	bool bRet = Send( pPacket );
	Unlock();

	//@@@ (sonmg 2005/02/17)
//	delete GetLoginServer()->m_listCert.Remove( pUser );	//안끊어질 수도 있으므로 미리 삭제하지 않는다.

	return bRet;
}


bool CGameServer::SendTotalUserCount(int nTotalUserCount)
{
	char szCount[10];
	CMir2Packet *pPacket = new CMir2Packet;
	pPacket->Attach( '(' );
	pPacket->Attach( ISM_TOTALUSERCOUNT );
	pPacket->Attach( '/' );
	pPacket->Attach( itoa(nTotalUserCount, szCount, 10 ));
	pPacket->Attach( ')' );

	Lock();
	bool bRet = Send( pPacket );
	Unlock();

	return bRet;

}

bool CGameServer::SendPublicKey(int nPubKey)
{
	char szCount[10];
	CMir2Packet *pPacket = new CMir2Packet;
	pPacket->Attach( '(' );
	pPacket->Attach( ISM_SEND_PUBLICKEY );
	pPacket->Attach( '/' );
	pPacket->Attach( itoa( nPubKey, szCount, 10 ) );
	pPacket->Attach( ')' );
#ifdef _DEBUG
	GetApp()->SetLog(0,"[GameServer/Send] ISM_SEND_PUBLICKEY : %s", szCount);
#endif	

	Lock();
	bool bRet = Send( pPacket );
	Unlock();

	return bRet;
}

bool CGameServer::SendPremiumResponse(int iGrade, char *pID, char *pUserName, char *szBirthDay)
{
	char cFlag = 0;
	if( iGrade == 2 )
	{
		cFlag = 'Y';
	}
	else if( iGrade == 1 )
	{
		cFlag = 'N';
	}
	else
	{
		return false;
	}

	CMir2Packet *pPacket = new CMir2Packet;
	pPacket->Attach( '(' );
	pPacket->Attach( ISM_PREMIUMCHECK );
	pPacket->Attach( '/' );
	pPacket->Attach( cFlag );
	pPacket->Attach( '/' );
	pPacket->Attach( pID );
	pPacket->Attach( '/' );
	pPacket->Attach( pUserName );
	pPacket->Attach( '/' );
	pPacket->Attach( szBirthDay );
	pPacket->Attach( ')' );
#ifdef _DEBUG
	GetApp()->SetLog(0,"[GameServer/Send] ISM_PREMIUMCHECK : %s (%c)", pID, cFlag);
#endif	

	Lock();
	bool bRet = Send( pPacket );
	Unlock();

	return bRet;
}

bool CGameServer::SendEventCheckResponse(char *pID, char *pUserName)
{
	CMir2Packet *pPacket = new CMir2Packet;
	pPacket->Attach( '(' );
	pPacket->Attach( ISM_EVENTCHECK );
	pPacket->Attach( '/' );
	pPacket->Attach( 'Y' );
	pPacket->Attach( '/' );
	pPacket->Attach( pID );
	pPacket->Attach( '/' );
	pPacket->Attach( pUserName );
	pPacket->Attach( ')' );
#ifdef _DEBUG
	GetApp()->SetLog(0,"[GameServer/Send] ISM_EVENTCHECK : %s", pID);
#endif	

	Lock();
	bool bRet = Send( pPacket );
	Unlock();

	return bRet;
}

bool CGameServer::SendPasswordSuccess( sGateUser *pUser )
{

	SYSTEMTIME st;
    GetLocalTime(&st);	//GetSystemTime
	DWORD nCurrentTime = GetDay(st.wYear, st.wMonth, st.wDay);

/*
	pUser->nAvailableType = 5;

	if ( pUser->dwSeconds + pUser->dwMSeconds  > 0 ) pUser->nAvailableType = 2;
	if ( pUser->dwIpSeconds + pUser->dwIpMSeconds > 0 ) pUser->nAvailableType = 4;
	if (((nCurrentTime > pUser->dwValidFrom )&&(nCurrentTime < pUser->dwValidUntil)) ||((nCurrentTime > pUser->dwMValidFrom ) && (nCurrentTime < pUser->dwMValidUntil)))
		pUser->nAvailableType = 1;	
	if (((nCurrentTime > pUser->dwIpMValidFrom ) && (nCurrentTime < pUser->dwIpMValidUntil))||
		((nCurrentTime > pUser->dwIpValidFrom ) && (nCurrentTime < pUser->dwIpValidUntil)))
		pUser->nAvailableType = 3;
*/

	CMir2Packet *pPacket = new CMir2Packet;
	char Deli = 0x0a;

	pPacket->Attach( '(' );
	pPacket->Attach( ISM_PASSWDSUCCESS );
	pPacket->Attach( '/' );
	pPacket->Attach( pUser->szID );
	pPacket->Attach( &Deli, 1 );
//	pPacket->Attach( '/' );
	pPacket->Attach( pUser->nCertification );
	pPacket->Attach( &Deli, 1 );
//	pPacket->Attach( '/' );
	pPacket->Attach( pUser->nPayMode );
	pPacket->Attach( &Deli, 1 );
//	pPacket->Attach( '/' );
	pPacket->Attach( pUser->nAvailableType );
	pPacket->Attach( &Deli, 1 );
//	pPacket->Attach( '/' );
	pPacket->Attach( pUser->szAddr );
	pPacket->Attach( &Deli, 1 );
	pPacket->Attach( pUser->nClientVersion );
	pPacket->Attach( ')' );

	Lock();
	bool bRet = Send( pPacket );
	Unlock();

/*	FILE *fp = fopen( "d:\\Admission.txt", "ab" );
	fprintf( fp, "[%s] [%s:%d] %s\r\n", pUser->szID, IP(), Port(), pPacket->m_pPacket );
	fclose( fp );*/

	return bRet;
}


bool CGameServer::OnUserClosed( char *pBody )
{
	bstr szID, szCert;
	_pickstring( pBody, '/', 0, &szID );
	_pickstring( pBody, '/', 1, &szCert );
	char szIPAddr[40];
	

	GetLoginServer()->m_csListCert.Lock();
	sCertUser *pUser = GetLoginServer()->m_listCert.SearchKey( szID );
	if ( !pUser )
	{
		GetLoginServer()->m_csListCert.Unlock();
		return true;
	}

/*	FILE *fp = fopen( "d:\\Admission.txt", "ab" );
	fprintf( fp, "CGameServer::OnUserClosed\r\n" );
	fclose( fp );*/

	strcpy(szIPAddr, pUser->szUserAddr);
	GetLoginServer()->SendCancelAdmissionUser( pUser );
#ifdef _DEBUG
	GetApp()->SetLog( 0, "[GameServer] %s was disconnected", pUser->szLoginID);	
#endif
	delete GetLoginServer()->m_listCert.Remove( pUser );

	GetLoginServer()->m_csListCert.Unlock();

	/* 2003/02/03 중복 아이피 체크
	CConnection *pConnPC = GetLoginServer()->m_dbPoolPC.Alloc();
	CRecordset  *pRec = NULL;
	int  nPCRoomIndex = 0;
	char szQuery[1024];

	if ( !pConnPC )
		return false;

	// 사용중인 IP가 피씨방인지 확인
	sprintf( szQuery, "SELECT * FROM TBL_USINGIP WHERE FLD_USINGIP='%s' AND FLD_GAMETYPE='%s'", szIPAddr, GetLoginServer()->m_szGameType );
#ifdef _DEBUG
	GetApp()->SetLog( 0, "[SQL QUERY] %s", szQuery);
#endif
	pRec = pConnPC->CreateRecordset();
	if(pRec && pRec->Execute( szQuery ) && pRec->Fetch())
	{
		nPCRoomIndex = atoi( pRec->Get("FLD_PCBANG") );
	}
	pConnPC->DestroyRecordset( pRec );

	if(nPCRoomIndex)
	{
		// 사용중인 IP리스트 삭제
		sprintf( szQuery, "DELETE FROM TBL_USINGIP WHERE FLD_USINGIP='%s' AND FLD_GAMETYPE='%s'", szIPAddr, GetLoginServer()->m_szGameType );
	#ifdef _DEBUG
		GetApp()->SetLog( 0, "[SQL QUERY] %s", szQuery);
	#endif
		pRec = pConnPC->CreateRecordset();
		if(pRec)
			pRec->Execute( szQuery );
		pConnPC->DestroyRecordset( pRec );

		// 사용중인 중복 IP삭제
		sprintf( szQuery, "UPDATE TBL_DUPIP SET FLD_ISOK='1', FLD_KICK = GetDate() FROM TBL_DUPIP WHERE FLD_IP='%s' AND FLD_GAMETYPE='%s' AND FLD_ISOK='0'", szIPAddr, GetLoginServer()->m_szGameType );
	#ifdef _DEBUG
		GetApp()->SetLog( 0, "[SQL QUERY] %s", szQuery);
	#endif
		pRec = pConnPC->CreateRecordset();
		if(pRec)
			pRec->Execute( szQuery );
		pConnPC->DestroyRecordset( pRec );

		// 사용중인 IP갯수 감소
		sprintf( szQuery, "UPDATE MR3_PCRoomStatusTable SET PCRoomStatus_UsingIPCount = PCRoomStatus_UsingIPCount-1 WHERE PCRoomStatus_PCRoomIndex=%d AND PCRoomStatus_UsingIPCount > 0", nPCRoomIndex);
	#ifdef _DEBUG
		GetApp()->SetLog( 0, "[SQL QUERY] %s", szQuery);
	#endif
		pRec = pConnPC->CreateRecordset();
		if(pRec)
			pRec->Execute( szQuery );
		pConnPC->DestroyRecordset( pRec );
	}
	GetLoginServer()->m_dbPoolPC.Free( pConnPC );
*/
	return true;
}


bool CGameServer::OnUserCount( char *pBody )
{
	//// 203/이벤트/0/124

	bstr szHandle, szName, szIndex, szCount;
	//_pickstring(pBody, '/',0,&szHandle);
	_pickstring(pBody, '/',0,&szName);
	_pickstring(pBody, '/',1,&szIndex);
	_pickstring(pBody, '/',2,&szCount);

#ifdef _DEBUG
//	GetApp()->SetLog( 0, "[OnUserCount] %s(%s)=%s", szName, szIndex, szCount );	
#endif

	m_dbInfo.nID = atoi(szIndex);
	strcpy(m_dbInfo.szName , szName);

	m_nCheckTime = GetTickCount();
	m_nCurUserCnt = atoi(szCount);
	
	if(m_nCurUserCnt > m_nMaxUserCnt)
		m_nMaxUserCnt = m_nCurUserCnt;

	int nTotalUserCount = GetLoginServer()->GetTotalUserCount();

	if(nTotalUserCount > GetLoginServer()->m_nMaxTotalUserCount)
		GetLoginServer()->m_nMaxTotalUserCount = nTotalUserCount;
	
	CListNode< CGameServer > *pNode;
	GetLoginServer()->m_listGameServer.Lock();
	pNode = GetLoginServer()->m_listGameServer.GetHead();
	for ( ; pNode; pNode = pNode->GetNext() )
	{
		CGameServer *pObj = pNode->GetData();
		if(pObj)
			pObj->SendTotalUserCount(nTotalUserCount);
	}	
	GetLoginServer()->m_listGameServer.Unlock();

	return true;
}

bool CGameServer::OnGameTimeOfTimeUser( char *pBody )
{
	return true;
}

bool CGameServer::OnCheckTimeAccount( char *pBody )
{
	bstr szID, szCert;
	_pickstring( pBody, '/', 0, &szID );
	_pickstring( pBody, '/', 1, &szCert );
	char szIPAddr[40];

	GetLoginServer()->m_csListCert.Lock();
	sCertUser *pUser = GetLoginServer()->m_listCert.SearchKey( szID );
	if ( !pUser )
	{
		GetLoginServer()->m_csListCert.Unlock();
		return true;
	}

	CConnection *pConn = GetLoginServer()->m_dbPool.Alloc();
	if ( !pConn )
	{
		GetLoginServer()->m_csListCert.Unlock();
		return false;
	}

	//------------------------------------
	// Query Warning(sonmg 2005/06/16)
	//긴 문자열 체크(LoginSvr)
	if( strlen(pUser->szLoginID) > 20 )
		GetApp()->SetLog( CERR, "[LONG-QUERY MESSAGE!!!] %s", pUser->szLoginID );
	//------------------------------------

	// DB에서 정량시간 검사...
	DWORD dwSeconds = 0;
	DWORD dwFreeSeconds = 0;
	DWORD dwMSeconds = 0;
	DWORD dwFreeMSeconds = 0;
	char szQuery[1024];
	sprintf( szQuery, "SELECT * FROM TBL_ACCOUNT WHERE FLD_LOGINID='%s'", pUser->szLoginID );
#ifdef _DEBUG
	GetApp()->SetLog( 0, "[SQL QUERY] %s", szQuery);
#endif

	CRecordset *pRec = pConn->CreateRecordset();
	if ( !pRec->Execute( szQuery ) || !pRec->Fetch() )
	{
		pConn->DestroyRecordset( pRec );
	}
	else
	{
		if( !pUser->bFreeMode )
		{
			if( pUser->nAvailableType == 2 || (pUser->nAvailableType >= 6 && pUser->nAvailableType <= 10) )
			{
				dwSeconds		= atoi(pRec->Get("FLD_SECONDS"));
				dwFreeSeconds	= atoi(pRec->Get("FLD_FreeSECONDS"));

				if(strcmp(GetLoginServer()->m_szGameType, "MIR2") ==0)
				{
					dwMSeconds		= atoi(pRec->Get("FLD_M2SECONDS"));

					//Free
					dwFreeMSeconds	= atoi(pRec->Get("FLD_FreeM2SECONDS"));
				}

				if(strcmp(GetLoginServer()->m_szGameType, "MIR3") ==0)
				{
					dwMSeconds		= atoi(pRec->Get("FLD_M3SECONDS"));

					//Free
					dwFreeMSeconds	= atoi(pRec->Get("FLD_FreeM3SECONDS"));
				}

				// 정량 시간 총합 : 남은 시간이 없으면...
				if( dwSeconds + dwFreeSeconds + dwMSeconds + dwFreeMSeconds == 0 )
				{
					strcpy(szIPAddr, pUser->szUserAddr);
//					GetLoginServer()->SendCancelAdmissionUser( pUser );
					GetLoginServer()->SendAccountExpireUser( pUser );
#ifdef _DEBUG
					GetApp()->SetLog( 0, "[GameServer] %s account is expired", pUser->szLoginID);
#endif
//					delete GetLoginServer()->m_listCert.Remove( pUser );	//안끊어질 수도 있으므로 미리 삭제하지 않는다.
				}
			}
		}

		//@@@ (sonmg 2005/02/17)
		pConn->DestroyRecordset( pRec );
	}

	GetLoginServer()->m_dbPool.Free( pConn );

	GetLoginServer()->m_csListCert.Unlock();

	return true;
}

bool CGameServer::OnRequestPublicKey( char *pBody )
{
	SendPublicKey( GetSavedKey() );

	return true;
}

bool CGameServer::OnPremiumCheck( char *pBody )
{
	bstr szID, szCert, szSvName, szUName;
	_pickstring( pBody, '/', 0, &szID );
	_pickstring( pBody, '/', 1, &szCert );
	_pickstring( pBody, '/', 2, &szSvName );
	_pickstring( pBody, '/', 3, &szUName );
	char szLoginID[40];
	char szServerName[40];
	char szUserName[40];
	strncpy( szLoginID, szID, 30 );
	strncpy( szServerName, szSvName, 30 );
	strncpy( szUserName, szUName, 30 );

	GetLoginServer()->m_csListCert.Lock();
	sCertUser *pUser = GetLoginServer()->m_listCert.SearchKey( szID );
	if ( !pUser )
	{
//		GetLoginServer()->m_csListCert.Unlock();
//		return true;
	}

	CConnection *pConn = GetLoginServer()->m_dbPool.Alloc();
	if ( !pConn )
	{
		GetLoginServer()->m_csListCert.Unlock();
		return false;
	}

	//------------------------------------
	// Query Warning(sonmg 2005/06/16)
	//긴 문자열 체크(LoginSvr)
//	if( strlen(pUser->szLoginID) > 20 )
//		GetApp()->SetLog( CERR, "[LONG-QUERY MESSAGE!!!] %s", pUser->szLoginID );
	//------------------------------------

	SYSTEMTIME st;
	GetLocalTime(&st);	//GetSystemTime
	unsigned int nCurrentTime = GetDay(st.wYear, st.wMonth, st.wDay);

	char cBasicFlag[10];
	char cSpecialFlag[10];
	DWORD dwEndDate = 0;
	DWORD dwForceDate = 0;

	char szQuery[1024];
	sprintf( szQuery, "SELECT * FROM TBL_M2PREMIUMUSER WHERE FLD_LOGINID='%s' AND FLD_SERVERNAME='%s' AND FLD_CHARNAME='%s'", szLoginID, szServerName, szUserName );
#ifdef _DEBUG
	GetApp()->SetLog( 0, "[SQL QUERY] %s", szQuery);
#endif

	int iGrade = 0;
	bool bResult = false;
	CRecordset *pRec = pConn->CreateRecordset();
	if ( !pRec->Execute( szQuery ) || !pRec->Fetch() )
	{
		pConn->DestroyRecordset( pRec );
	}
	else
	{
		memset(cSpecialFlag, 0, sizeof(cSpecialFlag));
		strcpy(cSpecialFlag , pRec->Get("FLD_SPECIALFLAG"));
		memset(cBasicFlag, 0, sizeof(cBasicFlag));
		strcpy(cBasicFlag , pRec->Get("FLD_BASICFLAG"));

		//플래그 검색
		if (cSpecialFlag[0] == 'Y' || cSpecialFlag[0] == 'y')
		{
			iGrade = 2;
			bResult = true;
		}
		else
		{
			if (cBasicFlag[0] == 'Y' || cBasicFlag[0] == 'y')
			{
				iGrade = 1;
				bResult = true;
			}
		}

		//유효 날짜 검색
		dwEndDate = GetTimeInfo(pRec->Get("FLD_ENDDATE"));

		//생일을 DWORD형식으로 보냄
		char szBirthDay[20];
		strcpy(szBirthDay, GetDateString(pRec->Get("FLD_BIRTHDAY")));

		//ForceDate(강제 허용 마감 날짜)
		dwForceDate = GetTimeInfo(pRec->Get("FLD_FORCEDATE"));

		//---------------------------------
		//현재 시간/날짜와 비교
		if( nCurrentTime <= dwEndDate )
		{
			bResult = true;
		}
		else
		{
			bResult = false;
		}
		//---------------------------------

		//---------------------------------
		//현재 시간/날짜와 비교
		if( nCurrentTime <= dwForceDate )
		{
			//생일을 오늘 날짜로 변경
			memset(szBirthDay, 0, sizeof(szBirthDay));
			sprintf(szBirthDay, "%d-%d-%d", st.wYear, st.wMonth, st.wDay);

			bResult = true;
		}
		//---------------------------------

		if( bResult )
		{
			//게임서버에 결과 보내기
			SendPremiumResponse( iGrade, szID, szUserName, szBirthDay );
		}

		//@@@ (sonmg 2005/02/17)
		pConn->DestroyRecordset( pRec );
	}

	GetLoginServer()->m_dbPool.Free( pConn );

	GetLoginServer()->m_csListCert.Unlock();

	return true;
}

bool CGameServer::OnEventCheck( char *pBody )
{
	bstr szID, szCert, szSvName, szUName;
	_pickstring( pBody, '/', 0, &szID );
	_pickstring( pBody, '/', 1, &szCert );
	_pickstring( pBody, '/', 2, &szSvName );
	_pickstring( pBody, '/', 3, &szUName );
	char szLoginID[40];
	char szServerName[40];
	char szUserName[40];
	strncpy( szLoginID, szID, 30 );
	strncpy( szServerName, szSvName, 30 );
	strncpy( szUserName, szUName, 30 );

	GetLoginServer()->m_csListCert.Lock();
	sCertUser *pUser = GetLoginServer()->m_listCert.SearchKey( szID );
	if ( !pUser )
	{
//		GetLoginServer()->m_csListCert.Unlock();
//		return true;
	}

	CConnection *pConn = GetLoginServer()->m_dbPool.Alloc();
	if ( !pConn )
	{
		GetLoginServer()->m_csListCert.Unlock();
		return false;
	}

	//------------------------------------
	// Query Warning(sonmg 2005/06/16)
	//긴 문자열 체크(LoginSvr)
//	if( strlen(pUser->szLoginID) > 20 )
//		GetApp()->SetLog( CERR, "[LONG-QUERY MESSAGE!!!] %s", pUser->szLoginID );
	//------------------------------------

	SYSTEMTIME st;
	GetLocalTime(&st);	//GetSystemTime
	unsigned int nCurrentTime = GetDay(st.wYear, st.wMonth, st.wDay);

	char cForceFlag[10];
	DWORD dwFirstLoginDate = 0;

	char szQuery[1024];
	sprintf( szQuery, "SELECT * FROM EVENT_COMEBACK2005 WHERE FLD_LOGINID='%s'", szLoginID );
#ifdef _DEBUG
	GetApp()->SetLog( 0, "[SQL QUERY] %s", szQuery);
#endif

	bool bResult = false;
	CRecordset *pRec = pConn->CreateRecordset();
	if ( !pRec->Execute( szQuery ) || !pRec->Fetch() )
	{
		pConn->DestroyRecordset( pRec );
	}
	else
	{
		memset(cForceFlag, 0, sizeof(cForceFlag));
		strcpy(cForceFlag , pRec->Get("FLD_FORCEFLAG"));

		//처음 접속 날짜 검색
		dwFirstLoginDate = GetTimeInfo(pRec->Get("FLD_FIRSTLOGIN"));

		//날짜가 없으면 처음 접속하는 것임.
		if( dwFirstLoginDate == 0 )
		{
			//처음 접속했을 때 현재 날짜/시간을 기록함.
			dwFirstLoginDate = nCurrentTime;
			sprintf( szQuery, "UPDATE EVENT_COMEBACK2005 SET FLD_FIRSTLOGIN=GETDATE() WHERE FLD_LOGINID='%s'", szLoginID );
			
			//업데이트 쿼리 실행
			CRecordset *pTempRec = pConn->CreateRecordset();
			if(pTempRec)
				pTempRec->Execute( szQuery );
			pConn->DestroyRecordset( pTempRec );
		}

		//현재 시각이 처음 접속했을 때부터 30일 범위 내에 있는지 확인
		if( (nCurrentTime >= dwFirstLoginDate) && (nCurrentTime <= dwFirstLoginDate + 30) )
		{
			bResult = true;
		}

		//강제 플래그 검색 : Y 이면 강제로 Enable 설정, N 이면 강제로 Disable 설정.
		if (cForceFlag[0] == 'Y' || cForceFlag[0] == 'y')
		{
			bResult = true;
		}
		else if (cForceFlag[0] == 'N' || cForceFlag[0] == 'n')
		{
			bResult = false;
		}

		//결과에 따라
		if( bResult )
		{
			//게임서버에 결과 보내기
			SendEventCheckResponse( szID, szUserName );
		}

		//@@@ (sonmg 2005/02/17)
		pConn->DestroyRecordset( pRec );
	}

	GetLoginServer()->m_dbPool.Free( pConn );

	GetLoginServer()->m_csListCert.Unlock();

	return true;
}

bool CGameServer::SaveServerUserCount()
{
	char szQuery[256];
	
	CConnection *pConn = GetLoginServer()->m_dbPool.Alloc();
	if ( !pConn )
		return false;
	
	sprintf(szQuery, "INSERT INTO TBL_USERCOUNT (FLD_NAME, FLD_INDEX, FLD_TIME,"
					" FLD_COUNT, FLD_MAXCOUNT,FLD_GAMETYPE) VALUES( '%s', %d, GetDate(),%d,%d,'%s')" 
					, m_dbInfo.szName, m_dbInfo.nID, m_nCurUserCnt, m_nMaxUserCnt,GetLoginServer()->m_szGameType  );

#ifdef _DEBUG
	GetApp()->SetLog( 0, "[SQL QUERY] %s", szQuery);
#endif

	CRecordset *pRec = pConn->CreateRecordset();
	pRec->Execute(szQuery);
	pConn->DestroyRecordset(pRec );
	m_nMaxUserCnt = 0;
	GetLoginServer()->m_dbPool.Free( pConn );
	return true;
}



void CGameServer::OnError( int nErrCode )
{
	GetApp()->SetErr( nErrCode );
}


void CGameServer::OnSend( int nTransferred )
{
#ifdef _DEBUG
//	if(nTransferred > 10)
//	GetApp()->SetLog( CSEND, "[GameServer/Send %d]  TO (%s)", nTransferred,this->m_dbInfo.szIP   );
#endif
}


bool CGameServer::OnRecv( char *pPacket, int nPacketLen )
{
#ifdef _DEBUG
	char __szPacket[256] = {0,};
	memcpy( __szPacket, pPacket, 
		nPacketLen >= sizeof( __szPacket ) ? sizeof( __szPacket ) - 1 : nPacketLen );
//	if(nPacketLen> 15)
//	GetApp()->SetLog( CRECV, "[GameServer/Recv %d] %s FROM (%s)", nPacketLen , __szPacket ,this->m_dbInfo.szIP);
#endif

	m_nLastTick = GetTickCount();
	
	//
	// 패킷 유효성 검사
	//
	if ( pPacket[0] != '(' || pPacket[nPacketLen - 1] != ')' )
	{
		m_nCntInvalidPacket++;
		return true;
	}

	pPacket[nPacketLen - 1] = NULL;

	//
	// 첫번째 엔트리가 패킷 ID이다.
	//
	bstr szPacketID;
	_pickstring( &pPacket[1], '/', 0, &szPacketID );

	char *pBody = pPacket + strlen( szPacketID ) + 2;

	//
	// 해당 프로토콜 함수를 호출한다.
	//
	for ( int i = 0; i < g_nCmdCnt; i++ )
	{
		if ( atoi( szPacketID ) == g_cmdList[i].nPacketID )
		{
			(this->*g_cmdList[i].pfn)( pBody );
			return true;
		}
	}
	GetApp()->SetLog( 0, "[Invalid Packet] %s", pPacket);
	m_nCntInvalidPacket++;
	return false;
}


bool CGameServer::OnExtractPacket( char *pPacket, int *pPacketLen )
{
	char *pEnd = (char *) memchr( m_olRecv.szBuf, ')', m_olRecv.nBufLen );
	if ( !pEnd )
		return false;

	*pPacketLen = ++pEnd - m_olRecv.szBuf;
	memcpy( pPacket, m_olRecv.szBuf, *pPacketLen );
	
	return true;
}

