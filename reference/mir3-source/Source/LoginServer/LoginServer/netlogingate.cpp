/*


	FLD_SECEDE 가  Y 이면 탈퇴
*/
#include "netlogingate.h"
#include "loginsvrwnd.h"
#include "../common/mir2packet.h"
#include <stringex.h>
#include <stdlib.h>
#include <stdio.h>
#include <time.h>

// Update Log...2003/01/08 COPark
// ClientVersion Check를 위해 버젼 번호 삽입
#define VERSION_NUMBER	20050501
//#define VERSION_NUMBER	20030805

static struct sLoginGateCmdList
{
	int  nPacketID;
	bool (CLoginGate:: *pfn)( sGateUser *pUser, char *pBody, _TDEFAULTMESSAGE msg  );
} g_cmdList[] = 
{
	CM_IDPASSWORD,		CLoginGate::OnIdPassword,
	CM_SELECTSERVER,	CLoginGate::OnSelectServer,
	CM_PROTOCOL,        CLoginGate::OnProtocol,
};


static const int g_nCmdCnt = sizeof( g_cmdList ) / sizeof( g_cmdList[0] );


CLoginGate::CLoginGate( SOCKET sdClient, sTblPubIP *pGateInfo )
{
	SetClassId( CLASSID );
	SetAcceptedSocket( sdClient );
	
	m_dbInfo			= *pGateInfo;	
	m_nCntInvalidPacket	= 0;

	m_listUser.InitHashTable( MAX_GATEUSER_HASHSIZE, IHT_ROUNDUP );
	m_listUser.SetGetKeyFunction( __cbGetUserKey );
}


CLoginGate::~CLoginGate()
{
	m_listUser.UninitHashTable();
}


bool CLoginGate::SendKickUser( sGateUser *pUser )
{
	CMir2Packet *pPacket = new CMir2Packet;
	pPacket->Attach( "%+-" );
	pPacket->Attach( pUser->szUserHandle );
	pPacket->Attach( "$" );

	Lock();
	bool bRet = Send( pPacket );
	Unlock();

	return bRet;
}


bool CLoginGate::SendResponse( sGateUser *pUser,
							   int nPacketID, 
							   int nRecog, int nParam, int nTag, int nSeries, char *pData )
{
	_TDEFAULTMESSAGE defMsg;
	fnMakeDefMessage( &defMsg, nPacketID, nRecog, nParam, nTag, nSeries );

	CMir2Packet *pPacket = new  CMir2Packet;
	pPacket->Attach( "%" );
	pPacket->Attach( pUser->szUserHandle );
	pPacket->Attach( "/#" );
	pPacket->AttachWithEncoding( (char *) &defMsg, sizeof( defMsg ) );

	if ( pData )
		pPacket->AttachWithEncoding( pData, strlen( pData ) );

/*	if ( pPacket )
		pPacket->AttachWithEncoding( pData, strlen( pData ) );*/
	pPacket->Attach( "!$" );

#ifdef _DEBUG
	GetApp()->SetLog( 0, "[LoginGate/Send] %s", pPacket->m_pPacket);
#endif
	
	Lock();
	bool bRet = Send( pPacket );
	Unlock();

	return bRet;
}


/*
	CM_IDPASSWORD
*/
bool CLoginGate::OnIdPassword( sGateUser *pUser, char *pBody, _TDEFAULTMESSAGE msg )
{
	// 2003/02/18 추가된부분 (NotInServerMode : 회사 IP는 허용)
//	if(GetLoginServer()->m_IsNotInServiceMode && strcmp( pUser->szAddr , "211.214.89.250" )!=0)	 // 218.144.171.253"
//	if( GetLoginServer()->m_IsNotInServiceMode && strcmp( pUser->szAddr, "222.110.172.250" ) != 0 && strcmp( pUser->szAddr, "222.110.172.249" ) != 0 )
	if( GetLoginServer()->m_IsNotInServiceMode && strcmp( pUser->szAddr, "222.110.172.250" ) != 0 )
	{
		SendResponse( pUser, SM_NOT_IN_SERVICE, 0, 0, 0, 0 );
		return false;
	}

	CConnection *pConn = GetLoginServer()->m_dbPool.Alloc();
	if ( !pConn )
	{
		SendResponse( pUser, SM_NOT_IN_SERVICE, 0, 0, 0, 0 );
		return false;
	}
	CConnection *pConnPC = GetLoginServer()->m_dbPoolPC.Alloc();
	if ( !pConnPC )
	{
		SendResponse( pUser, SM_NOT_IN_SERVICE, 0, 0, 0, 0 );
		return false;
	}
	bstr szID, szPW;
	_pickstring( pBody, '/', 0, &szID );
	_pickstring( pBody, '/', 1, &szPW );

	//------------------------------------
	// Query Warning(sonmg 2005/06/16)
	//긴 문자열 체크(LoginSvr)
	if( strlen(szID) > 20 )
		GetApp()->SetLog( CERR, "[LONG-QUERY MESSAGE!!!] %s", szID );
	//------------------------------------

	strcpy( pUser->szID, szID );
	pUser->nClientVersion = msg.nRecog;

	/*
		nPacketRecog

		 0	정상
		-1	패스워드 틀림
		-2	패스워드를 5회 실패 후 10분이 지나지 않았음
		-3	같은 아이디가 있음
		-4
		-5	아이디 정지증
		-6	아이디 없음
		-7  미르2아이디.
		-8  허용 아이피 갯수 초과
		-9	주민등록번호 오류
		-10 14세 미만 부모동의서 필요 
	*/
	int  nPacketRecog = 0;
	int  nPacketParam = 0;
	bool bNeedUpdate = false;
	bool bAvailableSsn = false;    //올바르고 15세이상인지 저장하는 변수
	char szQuery[1024];
	char cFinished[10];

	SYSTEMTIME st;
    GetLocalTime(&st);	//GetSystemTime
	unsigned int nCurrentTime = GetDay(st.wYear, st.wMonth, st.wDay);

	sprintf( szQuery, "SELECT * FROM TBL_ACCOUNT WHERE FLD_LOGINID='%s'", pUser->szID );
#ifdef _DEBUG
	GetApp()->SetLog( 0, "[SQL QUERY] %s", szQuery);
#endif

	pUser->dwMValidFrom		= 0;
	pUser->dwMValidUntil	= 0;
	pUser->dwMSeconds		= 0;
	pUser->dwMStopUntil	    = 0;
	pUser->dwValidFrom		= 0;
	pUser->dwValidUntil		= 0;
	pUser->dwSeconds		= 0;
	pUser->dwStopUntil		= 0;
	pUser->dwIpValidFrom	= 0;
	pUser->dwIpValidUntil	= 0;
	pUser->dwIpSeconds		= -200000;
	pUser->dwIpMValidFrom	= 0;
	pUser->dwIpMValidUntil	= 0;
	pUser->dwIpMSeconds		= 0;
	pUser->nParentCheck		= 0;

	///////////////////////////////////////
	pUser->dwFreeValidFrom		= 0;
	pUser->dwFreeValidUntil		= 0;
	pUser->dwFreeMValidFrom		= 0;
	pUser->dwFreeMValidUntil	= 0;

	pUser->dwFreeSeconds		= 0;
	pUser->dwFreeMSeconds		= 0;
	///////////////////////////////////////

	//로그인 아이디 체크
	CRecordset *pRec = pConn->CreateRecordset();
	if ( !pRec->Execute( szQuery ) || !pRec->Fetch() )
	{
		nPacketRecog = -6;
		pConn->DestroyRecordset( pRec );
		SendResponse( pUser, SM_PASSWD_FAIL, nPacketRecog, 0, 0, 0 );

		#ifdef _DEBUG
			GetApp()->SetLog( 0, "[LoginGate/ Send] SM_PASSWD_FAIL : %d",nPacketRecog);
		#endif

	}
	else
	{
		pUser->nPassFailCount	= atoi( pRec->Get( "FLD_PASSFAILCOUNT" ) );
		pUser->nPassFailTime	= atoi( pRec->Get( "FLD_PASSFAILTIME" ) );

		//-----------------------------------------------------	
		// 2003/04/09 탈퇴회원 처리 추가
		memset(cFinished, 0, sizeof(cFinished));
		strcpy(cFinished , pRec->Get("FLD_SECEDE"));
		if (cFinished[0] == 'Y' || cFinished[0] == 'y')
		{
			nPacketRecog = -6;
#ifdef _DEBUG
			GetApp()->SetLog( 0, "%s:Closed User", pUser->szID);
#endif
		}


		//15세미만 및 주민번호 체크 추가된부분
		//-----------------------------------------------------	
		strcpy(pUser->szSsno , pRec->Get("FLD_SSNO"));
		_trim(pUser->szSsno);
	
		if(!isCorrectSsn(pUser->szSsno))
		{
//			nPacketRecog = -9;
			bAvailableSsn = false;
#ifdef _DEBUG
			GetApp()->SetLog( 0, "%s is not correst ssn", pUser->szSsno);
#endif
		}
		else
		{
//			if(isOlderthen15(pUser->szSsno))
//			{
				bAvailableSsn = true;
//			}
//			else
//			{
//				bAvailableSsn = false;
//			}
		}
		//-----------------------------------------------------
		pUser->nParentCheck		= atoi(pRec->Get("FLD_PCHECK"));
		if ( pUser->nParentCheck == 3 )
		{
			nPacketRecog = -10;
#ifdef _DEBUG
			GetApp()->SetLog( 0, "%s:ParentCheck is 3", pUser->szID);
#endif
		}
		
		//-----------------------------------------------------
		pUser->dwValidFrom		= GetTimeInfo(pRec->Get("FLD_VALIDFROM"));
		pUser->dwValidUntil		= GetTimeInfo(pRec->Get("FLD_VALIDUNTIL"));
		pUser->dwSeconds		= atoi(pRec->Get("FLD_SECONDS"));
		pUser->dwStopUntil		= GetTimeInfo( pRec->Get( "FLD_STOPUNTIL" ) );

		//Free
//		pUser->dwFreeValidFrom		= GetTimeInfo(pRec->Get("FLD_FreeVALIDFROM"));
		pUser->dwFreeValidUntil		= GetTimeInfo(pRec->Get("FLD_FreeVALIDUNTIL"));
		pUser->dwFreeSeconds		= atoi(pRec->Get("FLD_FreeSECONDS"));


		if(strcmp(GetLoginServer()->m_szGameType, "MIR2") ==0)
		{
			pUser->dwMValidFrom		= GetTimeInfo(pRec->Get("FLD_M2VALIDFROM"));
			pUser->dwMValidUntil	= GetTimeInfo(pRec->Get("FLD_M2VALIDUNTIL"));
			pUser->dwMSeconds		= atoi(pRec->Get("FLD_M2SECONDS"));
			pUser->dwMStopUntil	    = GetTimeInfo(pRec->Get("FLD_M2STOPUNTIL"));

			//Free
//			pUser->dwFreeMValidFrom		= GetTimeInfo(pRec->Get("FLD_FreeM2VALIDFROM"));
			pUser->dwFreeMValidUntil	= GetTimeInfo(pRec->Get("FLD_FreeM2VALIDUNTIL"));
			pUser->dwFreeMSeconds		= atoi(pRec->Get("FLD_FreeM2SECONDS"));
		}

		if(strcmp(GetLoginServer()->m_szGameType, "MIR3") ==0)
		{
			pUser->dwMValidFrom		= GetTimeInfo(pRec->Get("FLD_M3VALIDFROM"));
			pUser->dwMValidUntil	= GetTimeInfo(pRec->Get("FLD_M3VALIDUNTIL"));
			pUser->dwMSeconds		= atoi(pRec->Get("FLD_M3SECONDS"));
			pUser->dwMStopUntil	= GetTimeInfo(pRec->Get("FLD_M3STOPUNTIL"));

			//Free
//			pUser->dwFreeMValidFrom		= GetTimeInfo(pRec->Get("FLD_FreeM3VALIDFROM"));
			pUser->dwFreeMValidUntil	= GetTimeInfo(pRec->Get("FLD_FreeM3VALIDUNTIL"));
			pUser->dwFreeMSeconds		= atoi(pRec->Get("FLD_FreeM3SECONDS"));
		}

		// 회사 IP 확인(회사에서는 제재 캐릭 접속 허용)
//		if(strcmp( pUser->szAddr , "211.214.89.250")==0)	// 218.144.171.253
//		if( strcmp( pUser->szAddr, "222.110.172.250") == 0 || strcmp( pUser->szAddr, "222.110.172.249") == 0 )
		if( strcmp( pUser->szAddr, "222.110.172.250") == 0 )
		{
			pUser->dwStopUntil		= 0;
			pUser->dwMStopUntil		= 0;
		}

		pUser->dwMakeTime		= GetTimeInfo( pRec->Get( "FLD_MAKETIME" ) );
		int nVersion            = atoi( pRec->Get("FLD_VER"));
		bstr szDBPW				= pRec->Get( "FLD_PASSWORD" );
		pConn->DestroyRecordset( pRec );

		//정지기간 체크
		if ( (pUser->dwStopUntil > nCurrentTime ) ||( pUser->dwMStopUntil > nCurrentTime )  )
		{
			nPacketRecog = -5;
			nPacketParam = ( pUser->dwMStopUntil - nCurrentTime );
			if( nPacketParam <= 0 ) nPacketParam = ( pUser->dwStopUntil - nCurrentTime );
		}
		else
		{
			//비밀번호틀린 시간 및 횟수체크
			if ( pUser->nPassFailCount >= 3 || GetTickCount() - pUser->nPassFailTime < 60000 )
			{
				nPacketRecog = -2;
				pUser->nPassFailCount  =0;
				//pUser->nPassFailTime = GetTickCount();				
			}
			else
			{
				_trim( szPW ); 
				_trim( szDBPW );

				if ( szPW != szDBPW )
				{
					nPacketRecog = -1;
					pUser->nPassFailCount++;
					if (pUser->nPassFailCount >=3)
						pUser->nPassFailTime = GetTickCount();
				}
				else
				{
					pUser->nPassFailCount = 0;
					pUser->nPassFailTime  = 0;

					/*if ( strlen( szDBName ) == 0 )
						bNeedUpdate = true;*/
				}
			}
			pRec = pConn->CreateRecordset();
			sprintf( szQuery, 
					 "UPDATE TBL_ACCOUNT SET FLD_PASSFAILCOUNT = %d, FLD_PASSFAILTIME = %d "
					 "WHERE FLD_LOGINID='%s'",
					 pUser->nPassFailCount, pUser->nPassFailTime, pUser->szID );
#ifdef _DEBUG
			GetApp()->SetLog( 0, "[SQL QUERY] %s", szQuery);
#endif
			pRec->Execute( szQuery );
			pConn->DestroyRecordset( pRec );
		}



		if ( nPacketRecog == 0 )
		{
			GetLoginServer()->m_csListCert.Lock();
			sCertUser *psCertUser = GetLoginServer()->m_listCert.SearchKey( pUser->szID );

			if (psCertUser)
			//if ( GetLoginServer()->m_listCert.SearchKey( pUser->szID ) )
			{
				nPacketRecog = -3;
				/*	FILE *fp = fopen( "d:\\Admission.txt", "ab" );
					fprintf( fp, "CLoginGate::OnIdPassword\r\n" );
					fclose( fp );*/

				GetLoginServer()->SendCancelAdmissionUser( psCertUser );
				psCertUser->bClosing = true;
				if (!psCertUser->bClosing)
					psCertUser->nOpenTime = GetTickCount();
			}
			GetLoginServer()->m_csListCert.Unlock();
		}

		/*if ( bNeedUpdate )
			SendResponse( pUser, SM_NEEDUPDATE_ACCOUNT, 0, 0, 0, 0 );
		if(nVersion==0)
			nPacketRecog =-7;*/

		if ( nPacketRecog == 0 )
		{
			pUser->bSelServerOK		= false;
			pUser->nCertification	= GetCertification();
			int nPCBangIndex = 0;
			int nPCBangMaxCount = 0;
			int nPCBangCurrent = 0;

			sprintf( szQuery, "SELECT * FROM MR3_IPTable A, MR3_PCRoomStatusTable B WHERE A.IP_PCRoomIndex = B.PCRoomStatus_PCRoomIndex AND A.IP_Address = '%s'", pUser->szAddr );
//			sprintf( szQuery, "SELECT * FROM TBL_IPACCOUNT A, TBL_PCBANG B WHERE A.FLD_PCBANGINDEX = B.FLD_PCBANGINDEX AND A.FLD_IP = '%s'", pUser->szAddr );
#ifdef _DEBUG
			GetApp()->SetLog( 0, "[SQL QUERY] %s", szQuery);
#endif
			pRec = pConnPC->CreateRecordset();
			if (pRec) 
			{
				pRec->Execute( szQuery );
				if ( pRec->Fetch() )
				{
	//				GetApp()->SetLog( 0, "[SQL Execute OK] Fetch....");
					//게임방 정액관련
					char sztemp[30];
					strcpy(sztemp,pRec->Get( "PCRoomStatus_FromDate" )); 
					pUser->dwIpValidFrom	= GetTimeInfo( pRec->Get( "PCRoomStatus_FromDate" ) );
					strcpy(sztemp,pRec->Get( "PCRoomStatus_RemainedDay" ));
					pUser->dwIpValidUntil	= GetTimeInfo( pRec->Get( "PCRoomStatus_RemainedDay" ) );

					pUser->dwIpSeconds		= atoi( pRec->Get( "PCRoomStatus_RemainedTime" ) );
					nPCBangIndex			= atoi( pRec->Get( "IP_PCRoomIndex" ) );
					nPCBangMaxCount			= atoi( pRec->Get( "PCRoomStatus_IPCount" ) );
					nPCBangCurrent			= atoi( pRec->Get( "PCRoomStatus_UsingIPCount" ) );

					if(strcmp(GetLoginServer()->m_szGameType, "MIR2") ==0)
					{
						pUser->dwIpMValidFrom	= GetTimeInfo( pRec->Get( "PCRoomStatus_M2FromDate" ) );
						pUser->dwIpMValidUntil	= GetTimeInfo( pRec->Get( "PCRoomStatus_M2RemainedDay" ) );
						pUser->dwIpMSeconds		= atoi( pRec->Get( "PCRoomStatus_M2RemainedTime" ) );;
					}
					if(strcmp(GetLoginServer()->m_szGameType, "MIR3") ==0)
					{
						pUser->dwIpMValidFrom	= GetTimeInfo( pRec->Get( "PCRoomStatus_M3FromDate" ) );
						pUser->dwIpMValidUntil	= GetTimeInfo( pRec->Get( "PCRoomStatus_M3RemainedDay" ) );
						pUser->dwIpMSeconds		= atoi( pRec->Get( "PCRoomStatus_M3RemainedTime" ) );
					} 
					
					/* 2003/02/03 중복 아이피 체크
					//게임방이므로  아래 사항 체크
					
					//1. 중복 IP 체크
					//	 TBL_USINGIP에 있는지 확인, 없으면 아래 2번으로 진행
					//	 있으면 같은 게임타입인지 확인, 같으면 KICK 요청후 오류 진행 
					//	 같지 않으면 TBL_DUPIP에 기록하여 KICK 요청, 2번으로 진행
					sprintf( szQuery, "SELECT * FROM TBL_USINGIP WHERE FLD_USINGIP = '%s' AND FLD_GAMETYPE = '%s'", pUser->szAddr, GetLoginServer()->m_szGameType);
	#ifdef _DEBUG
					GetApp()->SetLog( 0, "[SQL QUERY] %s", szQuery);
	#endif
					CRecordset *pRec2 = pConnPC->CreateRecordset();
					if ( pRec2->Execute( szQuery ) && pRec2->Fetch() )
					{
						// 사용중으로 되어 있다면 같은 게임인 경우 KICK 처리, 아니면 TBL_DUPIP에 기록
						if(strcmp(GetLoginServer()->m_szGameType, pRec2->Get( "FLD_GAMETYPE" )) ==0)
						{
							GetLoginServer()->m_csListCert.Lock();
							sCertUser *psCertUser = GetLoginServer()->m_listCert.SearchKey( pRec2->Get( "FLD_USERID" ) );

							if (psCertUser)
							{
								nPacketRecog = -3;
								//	FILE *fp = fopen( "d:\\Admission.txt", "ab" );
								//	fprintf( fp, "CLoginGate::OnIdPassword\r\n" );
								//	fclose( fp );

								GetLoginServer()->SendCancelAdmissionUser( psCertUser );
								psCertUser->bClosing = true;
								if (!psCertUser->bClosing)
									psCertUser->nOpenTime = GetTickCount();
							}
							GetLoginServer()->m_csListCert.Unlock();
							pConnPC->DestroyRecordset( pRec2 );
						}
						// 같은 게임이 아니므로 디비에 기록하여 킥을 요청
						else
						{
							pConnPC->DestroyRecordset( pRec2 );
							// Write TBL_DUPIP
							sprintf( szQuery, "INSERT INTO TBL_DUPIP (FLD_IP, FLD_GAMETYPE, FLD_PCBANG, FLD_ISOK, FLD_REQUEST) VALUES ('%s', 'MIR3', %d, '0', GetDate())", pUser->szAddr, nPCBangIndex );
	#ifdef _DEBUG
							GetApp()->SetLog( 0, "[SQL QUERY] %s", szQuery);
	#endif
							pRec2 = pConnPC->CreateRecordset();
							pRec2->Execute( szQuery );
							pConnPC->DestroyRecordset( pRec2 );
						}
					}
					//2. 현재 사용 IP개수가 MAX갯수보다 작은지 확인
					//작은 경우 OK, TBL_USINGIP에 IP추가
					//크거나 같은 경우 FAIL, 현재 사용 IP갯수가 많다고 리턴코드 보냄
					if ( nPacketRecog == 0 )
					{
						if( nPCBangCurrent >= nPCBangMaxCount )
						{
							nPacketRecog = -8;
						}
						else
						{
							// Write TBL_USINGIP
							sprintf( szQuery, "INSERT INTO TBL_USINGIP (FLD_PCBANG, FLD_USINGIP, FLD_GAMETYPE, FLD_FROM, FLD_SERVER, FLD_USERID ) VALUES (%d, '%s', '%s', GetDate(), '%d', '%s')", nPCBangIndex, pUser->szAddr, GetLoginServer()->m_szGameType, pUser->nServerID, pUser->szID );
	#ifdef _DEBUG
							GetApp()->SetLog( 0, "[SQL QUERY] %s", szQuery);
	#endif
							pRec2 = pConnPC->CreateRecordset();
							pRec2->Execute( szQuery );
							pConnPC->DestroyRecordset( pRec2 );
							// 사용중인 IP Count 증가
							nPCBangCurrent++;
							sprintf( szQuery, "UPDATE MR3_PCRoomStatusTable SET PCRoomStatus_UsingIPCount = %d WHERE PCRoomStatus_PCRoomIndex = %d", nPCBangCurrent, nPCBangIndex );
	#ifdef _DEBUG
							GetApp()->SetLog( 0, "[SQL QUERY] %s", szQuery);
	#endif
							pRec2 = pConnPC->CreateRecordset();
							pRec2->Execute( szQuery );
							pConnPC->DestroyRecordset( pRec2 );
						}
					}
					*/
				}
			}
			pConnPC->DestroyRecordset( pRec );
			pUser->nPayMode = 0;
			
			//nPaymode => 0 : 체험판, 1 : 유료, 2 : 무료(만든지 기간)

			
			//통합정액인지 체크 
			//해당정액
			//정량

			if( ((nCurrentTime >= pUser->dwValidFrom )    && (nCurrentTime <= pUser->dwValidUntil )) ||			//개인		통합	정액에 해당하는경우.
				((nCurrentTime >= pUser->dwMValidFrom )   && (nCurrentTime <= pUser->dwMValidUntil ))||			//개인				정액에 해당하는 경우
			    ((nCurrentTime >= pUser->dwIpValidFrom )  && (nCurrentTime <= pUser->dwIpValidUntil )) ||		//게임방	통합	정액에 해당하는 경우
				((nCurrentTime >= pUser->dwIpMValidFrom ) && (nCurrentTime <= pUser->dwIpMValidUntil ))||		//게임방			정액에 해당 하는 경우
				((nCurrentTime >= pUser->dwFreeValidFrom )    && (nCurrentTime <= pUser->dwFreeValidUntil )) ||		//무료 개인 통합 정액에 해당하는경우.
				((nCurrentTime >= pUser->dwFreeMValidFrom )   && (nCurrentTime <= pUser->dwFreeMValidUntil ))||		//무료 개인	정액에 해당하는 경우
				(pUser->dwSeconds > 0) ||																		//개인		통합	정량에 해당하는 경우
				(pUser->dwMSeconds > 0 )||																		//개인				정량에 해당하는 경우
				(pUser->dwIpSeconds > -180000) ||																	//게임방 -50시간 보정	
				(pUser->dwFreeSeconds > 0) ||																		//무료 개인 통합 정량에 해당하는 경우
				(pUser->dwFreeMSeconds > 0 ))																		//무료 개인 정량에 해당하는 경우
//				(pUser->dwSeconds + pUser->dwIpSeconds + pUser->dwIpMSeconds + pUser->dwMSeconds > 0))
			{
				pUser->nPayMode = 1;
				// 개인 보정 (수정) : 남은 날짜 표시 방법 수정...
				if(pUser->dwValidUntil ==0)
					pUser->dwValidUntil = nCurrentTime;
				else //if(pUser->dwValidUntil ==nCurrentTime)
					pUser->dwValidUntil++;

#ifdef _DEBUG
			GetApp()->SetLog(0,"[Check1] dwValidUntil: %d, CurTime: %d", pUser->dwValidUntil, nCurrentTime );
#endif	

				if(pUser->dwMValidUntil ==0)
					pUser->dwMValidUntil = nCurrentTime;
				else if(pUser->dwMValidUntil ==nCurrentTime)
					pUser->dwMValidUntil++;
#ifdef _DEBUG
			GetApp()->SetLog(0,"[Check2] dwMValidUntil: %d, CurTime: %d", pUser->dwMValidUntil, nCurrentTime );
#endif	

				// 무료 개인 보정(2004/06/07) (수정) : 남은 날짜 표시 방법 수정...
				if(pUser->dwFreeValidUntil ==0)
					pUser->dwFreeValidUntil = nCurrentTime;
				else //if(pUser->dwFreeValidUntil ==nCurrentTime)
					pUser->dwFreeValidUntil++;
#ifdef _DEBUG
			GetApp()->SetLog(0,"[Check3] dwFreeValidUntil: %d, CurTime: %d", pUser->dwFreeValidUntil, nCurrentTime );
#endif	

				if(pUser->dwFreeMValidUntil ==0)
					pUser->dwFreeMValidUntil = nCurrentTime;
				else //if(pUser->dwFreeMValidUntil ==nCurrentTime)
					pUser->dwFreeMValidUntil++;
#ifdef _DEBUG
			GetApp()->SetLog(0,"[Check4] dwFreeMValidUntil: %d, CurTime: %d", pUser->dwFreeMValidUntil, nCurrentTime );
#endif	

				// 피씨방 보정 (수정) : 남은 날짜 표시 방법 수정...
				if(pUser->dwIpValidUntil ==0)
					pUser->dwIpValidUntil = nCurrentTime;
				else //if(pUser->dwIpValidUntil ==nCurrentTime)
					pUser->dwIpValidUntil++;

				if(pUser->dwIpMValidUntil ==0)
					pUser->dwIpMValidUntil = nCurrentTime;
				else //if(pUser->dwIpMValidUntil ==nCurrentTime)
					pUser->dwIpMValidUntil++;

				long RemainDays		= 0;
				long RemainM2Days	= 0;
				long RemainFreeDays		= 0;
				long RemainFreeM2Days	= 0;
				long RemainIpDays	= 0;
				long RemainHours	= 0;
				long RemainM2Hours	= 0;
				long RemainFreeHours	= 0;
				long RemainFreeM2Hours	= 0;
				long RemainIpHours	= 0;

				RemainDays    = pUser->dwValidUntil - nCurrentTime;
				RemainM2Days  = pUser->dwMValidUntil - nCurrentTime;
				RemainFreeDays    = pUser->dwFreeValidUntil - nCurrentTime;
				RemainFreeM2Days  = pUser->dwFreeMValidUntil - nCurrentTime;
				RemainIpDays  = pUser->dwIpValidUntil - nCurrentTime;
				RemainHours   = (pUser->dwSeconds + 1) / 3600;
				RemainM2Hours   = (pUser->dwMSeconds + 1) / 3600;
				RemainFreeHours   = (pUser->dwFreeSeconds + 1) / 3600;
				RemainFreeM2Hours   = (pUser->dwFreeMSeconds + 1) / 3600;
				RemainIpHours = (pUser->dwIpSeconds + 1) / 3600;

				if(RemainDays < 0)    RemainDays    = 0;
				if(RemainM2Days < 0)  RemainM2Days  = 0;
				if(RemainFreeDays < 0)    RemainFreeDays    = 0;
				if(RemainFreeM2Days < 0)  RemainFreeM2Days  = 0;
				if(RemainIpDays < 0)  RemainIpDays  = 0;
				if(RemainHours < 0)   RemainHours   = 0;
				if(RemainM2Hours < 0)   RemainM2Hours   = 0;
				if(RemainFreeHours < 0)   RemainFreeHours   = 0;
				if(RemainFreeM2Hours < 0)   RemainFreeM2Hours   = 0;
				if(RemainIpHours < 0) RemainIpHours = 0;

				//유료통합 vs 유료Mir2 중에 큰 값 대입.
				if(RemainM2Days > RemainDays)
					RemainDays = RemainM2Days;

				//(유료통합 vs 유료Mir2 중에 큰 값) vs 무료통합 중에 큰값 대입.
				if(RemainFreeDays > RemainDays)
					RemainDays = RemainFreeDays;

				//((유료통합 vs 유료Mir2 중에 큰 값) vs 무료통합) vs 무료Mir2 중에 큰값 대입.
				if(RemainFreeM2Days > RemainDays)
					RemainDays = RemainFreeM2Days;

				//유료 계정비가 없으면...
				if( RemainDays == 0 )
				{
					//무료 Mir2용을 넣는다.
					RemainDays = RemainFreeM2Days;
					if( RemainDays == 0 )
					{
						//무료 Mir2용도 없으면 무료 통합 정액을 넣는다.
						RemainDays = RemainFreeDays;
					}

				}

				// 유료 정량시간에 Mir2정량을 더해준다.
				RemainHours = RemainHours + RemainM2Hours;
				// 무료 정량시간에 Mir2무료정량을 더해준다.
				RemainFreeHours = RemainFreeHours + RemainFreeM2Hours;
				// 유료 정량이 없으면...
				if( RemainHours == 0 )
				{
					// 무료 정량을 넣는다.
					RemainHours = RemainFreeHours;
				}
				else
				{
					// 유료통합 + 유료Mir2 + 무료통합 + 무료Mir2
					RemainHours = RemainHours + RemainFreeHours;
				}

				//-50시간 보정   -50시간 = 50 * 3600 = 180,000
				if(pUser->dwIpSeconds > -180000 && RemainIpHours == 0)
				{
					RemainIpHours = 1;
				}

				//틀린 주민번호 또는 15세미만인경우 추가로 메세지 보냄
				// SM_PASSOK_WRONGSSN = 534
				if(!bAvailableSsn) 
				{
//					SendResponse( pUser, SM_PASSOK_WRONGSSN,0,0,0,0);
				}

				SendResponse( pUser, SM_PASSOK_SELECTSERVER, 
							  MAKELONG((WORD)(RemainDays), (WORD)(RemainHours)), 
							  RemainIpDays,
							  RemainIpHours,
							  0);

//						GetApp()->SetLog( 0, "[SQL QUERY] %02x %02x %02x %02x (%04x) ", 
//						  	  (WORD)(RemainDays),
//							  pUser->dwSeconds,
//							  RemainIpDays,
//							  pUser->dwIpSeconds,
//							  MAKELONG((WORD)(RemainDays), (WORD)(pUser->dwSeconds))
//							);
			}
			else
			{
				if(!bAvailableSsn) 
				{
//					SendResponse( pUser, SM_PASSOK_WRONGSSN,0,0,0,0);
				}
				pUser->nPayMode = 0;
				SendResponse( pUser, SM_PASSOK_SELECTSERVER, 0, 0, 0, 0 );
			}


#ifdef _DEBUG
			GetApp()->SetLog(0,"[LoginGate/Send] SM_PASSOK_SELECTSERVER : %s", pUser->szID );
#endif	

			GetLoginServer()->AddCertUser( pUser );
			GetLoginServer()->WriteConLog(pUser->szID , pUser->szAddr);

			//로그인시 아이디체크후 메세지 보내기
			if (GetLoginServer()->CheckBadAccount(pUser->szID))
			{
				char message[1024];
				sprintf(message, "%d-%d-%d %d:%d %d 접속아이디 %s가(이)  %s에서 접속을 시도했습니다.[%s]", st.wYear,st.wMonth,st.wDay, st.wHour, st.wMinute, st.wSecond, pUser->szID, pUser->szAddr, GetLoginServer()->m_szGameType);
				GetLoginServer()->m_udpSender.SendMessages(message);

			}
		}
		else{
			SendResponse( pUser, SM_PASSWD_FAIL, nPacketRecog, nPacketParam, 0, 0 );
#ifdef _DEBUG
			GetApp()->SetLog(0,"[LoginGate/Send] SM_PASSWD_FAIL : %d", nPacketRecog);
#endif	
		}
	}
	
	GetLoginServer()->m_dbPoolPC.Free( pConnPC );
	GetLoginServer()->m_dbPool.Free( pConn );
	return true;
}


/*
	CM_SELECTSERVER
*/

bool CLoginGate::OnSelectServer( sGateUser *pUser, char *pBody, _TDEFAULTMESSAGE msg )
{
	if ( strlen( pUser->szID ) == 0 )
	{
		SendKickUser( pUser );
		delete m_listUser.Remove( pUser );	//sonmg 2005/01/31
		return false;
	}

	pUser->bSelServerOK = true;
	
	char szServerName[32] = {0,};
	strcpy(szServerName, pBody);
	//fnDecode6BitBuf( pBody, szServerName, sizeof( szServerName ) );
	
	pUser->bFreeMode = false;	
	

	SYSTEMTIME st;
    GetLocalTime(&st);	//GetSystemTime
	int nCurrentTime = GetDay(st.wYear, st.wMonth, st.wDay);

/*
	if ( nCurrentTime - pUser->dwMakeTime < GetLoginServer()->m_nFreePeriods * 60 * 60 * 24 )
	{
		pUser->nPayMode = 2;
		pUser->bFreeMode = true;
	}
*/	
	//
	// 선택한 서버 seek
	//
	CGameServer *pGameServer = NULL;
	CGameServerInfo *pSelectServerInfo = NULL;
	sTblSelectGateIP	*pSelectGate = NULL;
	
	CListNode<CGameServerInfo> *pServerNode = GetLoginServer()->m_listServerInfo.GetHead();
	for(; pServerNode;pServerNode = pServerNode->GetNext())
	{
		CGameServerInfo *pServerInfo = pServerNode->GetData();
		if(strcmp(pServerInfo->szName, szServerName) == 0)
		{
			pSelectServerInfo = pServerInfo;
			pSelectGate = pServerInfo->GetSelectGate();
			if(pServerInfo->nFreemode == 0)
				pUser->bFreeMode = false;//true;	// fixed by sonmg(2005/03/29)
			break;
		}
	}
	
	if (!pSelectGate||
		(pSelectServerInfo->nMaxUserCount < GetLoginServer()->RecalUserCount(szServerName)))
	{
		GetLoginServer()->DelCertUser( pUser );
		SendResponse( pUser, SM_STARTFAIL, 0, 0, 0, 0 );
		
		return false;
	}
	
	
	GetLoginServer()->m_csListCert.Lock();
	sCertUser *pCert = GetLoginServer()->m_listCert.SearchKey( pUser->szID );
	if ( pCert )
	{
		strcpy( pCert->szServerName, szServerName );
		pCert->bFreeMode = pUser->bFreeMode;
	}
	GetLoginServer()->m_csListCert.Unlock();
	
	CListNode< CGameServer > *pNode;

	GetLoginServer()->m_listGameServer.Lock();

	// EXLOG
	int __CNT1 = 0;
	int __CNT2 = 0;

	pNode = GetLoginServer()->m_listGameServer.GetHead();
	for (pNode = GetLoginServer()->m_listGameServer.GetHead(); pNode; pNode = pNode->GetNext() )
	{
		CGameServer *pObj = pNode->GetData();

		if(pObj){
			if(stricmp(pObj->m_dbInfo.szName , szServerName)==0)
			{
				if(!pObj->SendPasswordSuccess( pUser ))
				{
#ifdef _DEBUG
					GetApp()->SetLog(0,"[SendPasswordFail]");
#endif
					__CNT2++;
				}

				__CNT1++;
			}

		}
		
	}	
	GetLoginServer()->m_listGameServer.Unlock();

/*	FILE *fp = fopen( "d:\\Admission.txt", "ab" );
	fprintf( fp, "==> Result: %d %d\r\n\r\n", __CNT1, __CNT2 );
	fclose( fp );*/

	//
	// 성공 메시지 send
	//
	char szText[1024];
	sprintf( szText, 
			 "%s/%d/%d", 
			 pSelectGate->szIP, pSelectGate->nPort, pUser->nCertification );
	SendResponse( pUser, SM_SELECTSERVER_OK, pUser->nCertification, 0, 0, 0, szText );

	return true;
}


/*
	KeepAlive

	%--$
*/
bool CLoginGate::OnKeepAlive()
{
	CMir2Packet *pPacket = new CMir2Packet;
	pPacket->Attach( "%++$" );
	Lock();
	bool bRet = Send( pPacket );
	Unlock();

	return bRet;
}


/*
	User Data

	%A[HANDLE]/#?[DefMsg][Data]!$
*/
bool CLoginGate::OnUserData( char *pBody )
{
	char *pData = strchr( pBody, '/' );
	if ( !pData )
	{
		m_nCntInvalidPacket++;
		return false;
	}
	*pData++ = NULL;

	sGateUser *pUser = m_listUser.SearchKey( pBody );
	if ( !pUser )
	{
		m_nCntInvalidPacket++;
		return false;
	}

	//
	// Relay 패킷 유효성 검사
	//
	int nDataLen = strlen( pData );
	if ( pData[0] != '#' || pData[nDataLen - 1] != '!' )
	{
		m_nCntInvalidPacket++;
		return true;
	}	
	pData[nDataLen - 1] = NULL;
	pData += 2;

	//
	// Default Message 디코딩
	//
	_TDEFAULTMESSAGE msg;
	fnDecodeMessage( &msg, pData );

	BYTE LeftByte = 0, RightByte = 0;

	switch( msg.wIdent )
	{
	case CM_IDPASSWORD:
//      smsg.Etc := WORD((smsg.Recog and $CD + smsg.Ident or $48 + smsg.Param or $30 + smsg.Tag and $2D + smsg.Series) xor GetPublicKey);
		// old version
//		if( WORD(((msg.nRecog & 0x57CD) + (msg.wIdent | 0x48) + (msg.wParam | 0x30) + (msg.wTag & 0x2D) + msg.wSeries) ^ GetPublicKey()) != msg.wEtc )
		// MAKEWORD( BYTE(((smsg.Recog and $57CD) + (smsg.Ident or $48) + (smsg.Param or $30) + (smsg.Tag and $2D) + smsg.Series) xor GetPublicKey), BYTE(Random(256) xor $08) );
		RightByte = LOBYTE( msg.wEtc ) ^ 0x08;
		LeftByte = BYTE( ((msg.nRecog & 0x57CD) + (msg.wIdent | 0x48) + (msg.wParam | 0x30) + (msg.wTag & 0x2D) + msg.wSeries) ^ (GetPublicKey() ^ RightByte) );
		if( LeftByte != HIBYTE(msg.wEtc) )
			return false;
	}
	
	pData +=  _DEFBLOCKSIZE;

	CDecodedString *pdData = fnDecodeString(pData);

/*
	//-----------------------------------------------------------
	//20040715 입력창을 통한 쿼리 실행 제거
	char *pDataNull = strchr( pdData->m_pData, ' ' );
	if ( pDataNull != NULL )
	{
		GetApp()->SetLog( CERR, "[QUERY WARNING!!!] %s", pdData->m_pData );
		return false;
	}
	//-----------------------------------------------------------
*/

	//ID 추출
	bstr szID;
	_pickstring( pdData->m_pData, '/', 0, &szID );

	//-----------------------------------------------------------
	//2005/06/10 - ID에 특수문자 체크 추가
	//긴 문자열 체크(LoginSvr)
	if( strlen(szID) > 20 )
		GetApp()->SetLog( CERR, "[LONG-QUERY MESSAGE!!!] %s", pdData->m_pData );

	//특수 문자가 들어가 있으면 에러 리턴
	char *pDataNull = strchr( szID, ' ' );
	if ( pDataNull != NULL )
	{
		GetApp()->SetLog( CERR, "[QUERY WARNING!!!] %s", pdData->m_pData );
		return false;
	}
	pDataNull = strchr( szID, '-' );
	if ( pDataNull != NULL )
	{
		GetApp()->SetLog( CERR, "[QUERY WARNING!!!] %s", pdData->m_pData );
		return false;
	}
	pDataNull = strchr( szID, '\'' );
	if ( pDataNull != NULL )
	{
		GetApp()->SetLog( CERR, "[QUERY WARNING!!!] %s", pdData->m_pData );
		return false;
	}
	//-----------------------------------------------------------

	//-----------------------------------------------------------
	//중복 ID 체크(sonmg 2004/08/18)
	CListNode< sGateUser > *pNode;
	pNode = m_listUser.GetHead();
	for ( ; pNode; pNode = pNode->GetNext() )
	{
		// 기존 사용자
		sGateUser *pTempUser = pNode->GetData();
		// 기존 사용자가 있으면...
		if( strcmp(pTempUser->szID, szID) == 0 )
		{
			if( strcmp(pTempUser->szUserHandle, pUser->szUserHandle) != 0 )
			{
				GetApp()->SetLog( CDBG, "[LoginGate/Duplicated User] %s %s[%s] %s[%s]", pTempUser->szID, pUser->szUserHandle, pUser->szAddr, pTempUser->szUserHandle, pTempUser->szAddr );

				//-----------------------------------------------------
				// 연결을 끊는다.(sonmg 2005/01/21)
				SendKickUser( pUser );
				delete m_listUser.Remove( pUser );	//sonmg 2005/01/31
				SendKickUser( pTempUser );
				//-----------------------------------------------------

				//현재 접속한 나 자신을 제거한다.
				if ( !pTempUser->bSelServerOK )
					GetLoginServer()->DelCertUser( pTempUser );

				//나 자신과 상대방을 제거한다.
				delete m_listUser.Remove( pTempUser );
				delete pdData;
				return false;
			}
		}
	}	
	//-----------------------------------------------------------

	//
	// 해당 프로토콜 함수를 호출한다.
	//
	for ( int i = 0; i < g_nCmdCnt; i++ )
	{
		if ( msg.wIdent == g_cmdList[i].nPacketID )
		{
			if ( !(this->*g_cmdList[i].pfn)( pUser, *pdData, msg ) )
			{
#ifdef _EX_DEBUG
				GetApp()->SetLog( CDBG, "에러! 로그인게이트 패킷 함수 실행 실패!! %s %d", __FILE__, __LINE__ );
#endif
			}
			delete pdData;
			return true;
		}
	}

	delete pdData;

	m_nCntInvalidPacket++;
	return false;
}


/*
	User Open

	%O[HANDLE]/[ADDR]$
*/
bool CLoginGate::OnUserOpen( char *pBody )
{
	bstr szHandle, szAddr;
	_pickstring( pBody, '/', 0, &szHandle );
	_pickstring( pBody, '/', 1, &szAddr );

	//
	// 중복 Open 처리
	//
	sGateUser *pUser = m_listUser.SearchKey( szHandle );
	if ( pUser )
		return true;

	pUser = new sGateUser;
	memset( pUser, 0, sizeof( sGateUser ) );

	pUser->nGateSocket = m_sdHost;
	strcpy( pUser->szUserHandle, szHandle );
	strcpy( pUser->szAddr, szAddr );

	bool bRet = m_listUser.Insert( pUser );
	
#ifdef _DEBUG
	GetApp()->SetLog( CDBG, "OPEN GATE_USER: %d", m_listUser.GetCount() );
#endif

	// ID와 Password가 맞으면 PublicKey를 XOR하여 XOR값과 함께 클라이언트로 전송함.(sonmg 2005/04/21)
	ChangeByDefaultKey();
	SendResponse( pUser, SM_SEND_PUBLICKEY, 0, GetSavedKey() ^ 0xF0E0, 0xF0E0, 0 );
	ChangeBySavedKey();

	return bRet;
}


/*
	User Close

	%X[HANDLE]$
*/
bool CLoginGate::OnUserClose( char *pBody )
{
	char *pHandle = pBody;

	sGateUser *pUser = m_listUser.SearchKey( pHandle );
	if ( !pUser )
		return true;

	if ( !pUser->bSelServerOK )
		GetLoginServer()->DelCertUser( pUser );

	delete m_listUser.Remove( pUser );

#ifdef _DEBUG
	GetApp()->SetLog( CDBG, "CLOSE GATE_USER: %d", m_listUser.GetCount() );
#endif

	return true;
}


void CLoginGate::OnError( int nErrCode )
{
	GetApp()->SetErr( nErrCode );
}


void CLoginGate::OnSend( int nTransferred )
{
#ifdef _DEBUG
//	if(nTransferred > 10)
//	GetApp()->SetLog( CSEND, "[LoginGate/%d] TO (%s)",nTransferred,this->m_dbInfo.szIP );
#endif
}


bool CLoginGate::OnRecv( char *pPacket, int nPacketLen )
{
#ifdef _DEBUG
	char __szPacket[256] = {0,};
	memcpy( __szPacket, pPacket, 
		nPacketLen >= sizeof( __szPacket ) ? sizeof( __szPacket ) - 1 : nPacketLen );
//?	if(nPacketLen >10)
//	GetApp()->SetLog( CRECV, "[LoginGate/%d] %s FROM (%s)", nPacketLen, __szPacket,this->m_dbInfo.szIP );
//	GetApp()->SetLog( CRECV, "[LoginGate] m_nCntInvalidPacket (%d)", m_nCntInvalidPacket);
#endif

	//
	// 패킷 유효성 검사
	//
	if ( pPacket[0] != '%' || pPacket[nPacketLen - 1] != '$' )
	{
		m_nCntInvalidPacket++;
		return true;
	}
	
	pPacket[nPacketLen - 1] = NULL;

	switch ( pPacket[1] ) 
	{
	case '-':
		OnKeepAlive();
		return true;

	case 'A':
		OnUserData( &pPacket[2] );
		return true;

	case 'O':
		OnUserOpen( &pPacket[2] );
		return true;
	
	case 'X':
		OnUserClose( &pPacket[2] );
		return true;
	}

	m_nCntInvalidPacket++;
#ifdef _EX_DEBUG
	GetApp()->SetLog( CDBG, "에러! LOGIN 게이트 잘못된 패킷 수신됨!! %s %d\n", __FILE__, __LINE__ );
#endif
	return false;
}


bool CLoginGate::OnExtractPacket( char *pPacket, int *pPacketLen )
{
	char *pEnd = (char *) memchr( m_olRecv.szBuf, '$', m_olRecv.nBufLen );
	if ( !pEnd )
		return false;

	*pPacketLen = ++pEnd - m_olRecv.szBuf;
	memcpy( pPacket, m_olRecv.szBuf, *pPacketLen );

	return true;
}



int CLoginGate::GetCertification()
{
	static long s_nCert = 30;

	InterlockedIncrement( &s_nCert );

	if ( s_nCert >= 0x7FFFFFFF ) 
		InterlockedExchange( &s_nCert, 30 );
	
	return s_nCert;
}



char * CLoginGate::__cbGetUserKey( sGateUser *pUser )
{
	return pUser->szUserHandle;
}

// Update Log...2003/01/08 COPark
// ClientVersion Check를 위해 OnProtocol 함수 추가
bool CLoginGate::OnProtocol( sGateUser *pUser, char *pBody, _TDEFAULTMESSAGE msg )
{
	if ( strlen( pUser->szID ) == 0 )
	{
		SendKickUser( pUser );
		delete m_listUser.Remove( pUser );	//sonmg 2005/01/31
		return false;
	}

	if(msg.nRecog < VERSION_NUMBER) 
	{
		SendResponse(pUser, SM_VERSION_FAIL, 0, 0, 0, 0);
		return false;
	}
	else 
	{
		SendResponse(pUser, SM_VERSION_AVAILABLE, 0, 0, 0, 0);
		pUser->nClientVersion = msg.nRecog;	
		pUser->bVersionAccept = true;
		return true;
	}
}	
