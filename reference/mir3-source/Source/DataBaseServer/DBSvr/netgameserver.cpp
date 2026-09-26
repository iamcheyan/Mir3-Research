
#include <database.h>
#include "../common/mir2packet.h"
#include "../common/sqlhandler.h"
#include "tablesdefine.h"
#include "netgameserver.h"
#include "dbsvrwnd.h"
#include <stringex.h>
#include <stdlib.h>
#ifdef _DEBUG
#include <crtdbg.h>
#endif

// 명령어와 내부 함수를 연결시켜 놓은 테이블
static struct sGameServerCmdList
{
	int  nPacketID;
	bool (CGameServer:: *pfn)( int nCert, char *pBody );
} g_cmdList[] = 
{
	DB_LOADHUMANRCD		,	CGameServer::OnLoadHumanRcd		,
	DB_SAVEHUMANRCD		,	CGameServer::OnSaveHumanRcd		,
	DB_SAVEANDCHANGE	,	CGameServer::OnSaveAndChange	,
	//-------------------------------------------------------
	DB_FRIEND_LIST		,	CGameServer::OnFriendList		,
	DB_FRIEND_ADD		,	CGameServer::OnFriendAdd		,
	DB_FRIEND_DELETE	,	CGameServer::OnFriendDelete		,
	DB_FRIEND_OWNLIST	,	CGameServer::OnFriendOwnList	,
	DB_FRIEND_EDIT		,	CGameServer::OnFriendEdit		,
	//-------------------------------------------------------
	DB_TAG_ADD			,	CGameServer::OnTagAdd			,
	DB_TAG_DELETE		,	CGameServer::OnTagDelete		,
	DB_TAG_DELETEALL	,	CGameServer::OnTagDeleteAll		,
	DB_TAG_LIST			,	CGameServer::OnTagList			,
	DB_TAG_SETINFO		,   CGameServer::OnTagSetInfo		,
	DB_TAG_REJECT_ADD	,	CGameServer::OnTagRejectAdd		,
	DB_TAG_REJECT_DELETE,	CGameServer::OnTagRejectDelete	,
	DB_TAG_REJECT_LIST	,	CGameServer::OnTagRejectList	,
	DB_TAG_NOTREADCOUNT	,	CGameServer::OnTagNotReadCount	,
	//-------------------------------------------------------
	DB_LM_LIST			,	CGameServer::OnLMList			,
	DB_LM_ADD			,	CGameServer::OnLMAdd			,
	DB_LM_EDIT			,	CGameServer::OnLMEdit			,
	DB_LM_DELETE		,	CGameServer::OnLMDelete			,

};


static const int g_nCmdCnt = sizeof( g_cmdList ) / sizeof( g_cmdList[0] );


CGameServer::CGameServer( SOCKET sdClient )
{
	SetClassId( CLASSID );
	SetAcceptedSocket( sdClient );

	m_nCntInvalidPacket = 0;

	m_nLoadCount		= 0;
	m_nLoadFailCount	= 0;
	m_nSaveCount		= 0;
	m_nSaveFailCount	= 0;
}


CGameServer::~CGameServer()
{
}


bool CGameServer::SendResponse( int nCert, char *pData )
{
	int		nLen = strlen(pData) + 6;
	LONG	lCert = MAKELONG(nCert ^ 0xAA, nLen);

	CMir2Packet *pPacket = new CMir2Packet;
	pPacket->Attach( "#" );
	pPacket->Attach( nCert );	
	pPacket->Attach( "/" );
	pPacket->Attach( pData );
	pPacket->AttachWithEncoding ( (char *)&lCert, sizeof(LONG) );
	pPacket->Attach( "!" );

	return Send( pPacket );
}

bool CGameServer::SendResponse( int nCert, int result ,char *UserName ,int RetCmdNum , int CmdNum ,char *pData  )
{
	char resultstr[8192];
	sprintf(resultstr , "%s/%d/%s",UserName,CmdNum , pData );


	_TDEFAULTMESSAGE	defMsg;
	char				szEncodeMsg[8192 ];
	int					size=0;

	fnMakeDefMessage( &defMsg, RetCmdNum, result, 0, 0, 0 );
	
	int	nPos = fnEncodeMessage(&defMsg, szEncodeMsg, sizeof(szEncodeMsg));

	szEncodeMsg[nPos] = '/';
	nPos++;
	
	nPos += fnEncode6BitBuf((unsigned char *)resultstr, &szEncodeMsg[nPos], strlen(resultstr), sizeof(szEncodeMsg) - nPos);
	szEncodeMsg[nPos] = '\0';

	return ( SendResponse( nCert, szEncodeMsg ) );
}


bool CGameServer::OnLoadHumanRcd( int nCert, char *pBody )
{
//	DWORD dwStart = GetTickCount();

	int rr = 0;
	
	sLoadHuman lhuman;
	fnDecode6BitBuf( pBody, (char *) &lhuman, sizeof( lhuman ) );

	FDBRecord			rcd;

	ZeroMemory(&rcd, sizeof(rcd));

	CConnection *pConn = GetOdbcPool()->Alloc();

	if ( pConn )
	{
		CRecordset *pRec = pConn->CreateRecordset();

		if (pRec)
		{
			char szQuery[1024];

			if (_makesqlparam(szQuery, SQLTYPE_SELECTWHERE, &__CHARACTERTABLE, lhuman.szName, lhuman.szID))
			{
				// To PDS
				// GetApp()->SetLog(0, "OnLoadHumanRcd:%s", szQuery);
				
				if ( pRec->Execute( szQuery )  )
				{

					if ( pRec->Fetch() )
					{
						TCHARACTERFIELDS	tCharFields;
	//					TABILITYFIELDS		tAbilFields;
						TMAGICFIELDS		tMagicFields;
						TITEMFIELDS			tItemFields;
						TITEMGIVEFIELDS		tItemGiveFields;
						
						_getfields(pRec, &__CHARACTERTABLE, (unsigned char *)&tCharFields);
						_setrecordTHuman(&tCharFields, &rcd.Block.DBHuman);
						
						pConn->DestroyRecordset( pRec );
						
						// TO PDS: DELETE ABIL RECORD
						/*
						pRec = pConn->CreateRecordset();

						
						_makesqlparam(szQuery, SQLTYPE_SELECTWHERE, &__ABILITYTABLE, lhuman.szName);
						
						if ( pRec->Execute( szQuery ) )
						{
							if ( pRec->Fetch() )
							{
								_getfields(pRec, &__ABILITYTABLE, (unsigned char *)&tAbilFields);
								_FieldsToStrucAbil(&tAbilFields, &rcd.Block.DBHuman.Abil);
							}
						}
						
						pConn->DestroyRecordset( pRec );
						*/

	// PDS ==============================================================================================================
//테스트서버에서는 막아주세요 꼭
//  /*

						// 2003/04/28 오프라인 금액 지급
						CConnection *pConn2 = GetAcntOdbcPool()->Alloc();
						pRec = pConn2->CreateRecordset();
						
						_makesqlparam(szQuery, SQLTYPE_SELECTWHERE, &__ITEMGIVETABLE, "MIR2", GetCfg()->szName, lhuman.szName, "0");
	//					GetApp()->SetLog( 0, szQuery);	
						
						if ( pRec->Execute( szQuery ) )
						{
							if ( pRec->Fetch() )
							{
								char szReg[256];
								strcpy(szReg, pRec->Get( "FLD_REGISTER" ));
								_getfields(pRec, &__ITEMGIVETABLE, (unsigned char *)&tItemGiveFields);
								pConn2->DestroyRecordset( pRec );

								tItemGiveFields.fld_done[0] = '1';

								CRecordset *pRec2 = pConn2->CreateRecordset();
								strcpy(szQuery, "UPDATE TBL_ITEMGIVE SET FLD_DONE = '1' WHERE FLD_GAMETYPE = 'MIR2' AND FLD_SERVER = '");
								strcat(szQuery, tItemGiveFields.fld_server);
								strcat(szQuery, "' AND FLD_CHARACTER = '");
								strcat(szQuery, tItemGiveFields.fld_character);
								strcat(szQuery, "' AND FLD_DONE = '0' AND FLD_REGISTER = '");
								strcat(szQuery, szReg);
								strcat(szQuery, "'");
								
	//							GetApp()->SetLog( 0, szQuery);	
								if ( pRec2->Execute( szQuery ) )
								{
									GetApp()->SetLog( 0, "Gold Add OK to (%s)(%d)", tItemGiveFields.fld_character, tItemGiveFields.fld_value);	
									rcd.Block.DBHuman.Gold += tItemGiveFields.fld_value;
								}
								else
								{
									GetApp()->SetLog( 0, "Gold Add Fail(%s)", szQuery);	
								}
								pConn2->DestroyRecordset( pRec2 );
							}
							else
								pConn2->DestroyRecordset( pRec );
						}
						else
							pConn2->DestroyRecordset( pRec );

						GetAcntOdbcPool()->Free( pConn2 );
						// 2003/04/28
// */
//테스트서버에서는 막아주세요 꼭 
	// PDS =========================================================================================================

						pRec = pConn->CreateRecordset();
						
						_makesqlparam(szQuery, SQLTYPE_SELECTWHERE, &__MAGICTABLE, lhuman.szName);
						strcat( szQuery ," order by fld_pos");
						
						if ( pRec->Execute( szQuery ) )
						{
							int nCnt = 0;
							
							while ( pRec->Fetch() )
							{
								_getfields(pRec, &__MAGICTABLE, (unsigned char *)&tMagicFields);
								_FieldsToStrucUseMagic(&tMagicFields, &rcd.Block.DBUseMagic.Magics[nCnt]);
								nCnt++;
							}
						}
						
						pConn->DestroyRecordset( pRec );
						
						LoadQuest(pConn, &rcd.Block.DBHuman, lhuman.szName);	// Fetch Quest Info.
						
						pRec = pConn->CreateRecordset();
						
						if (_makesqlparam(szQuery, SQLTYPE_SELECTWHERENOT, &__ITEMTABLE, lhuman.szName , U_SAVE))
						{
							strcat( szQuery ," order by FLD_TYPE"); // FLD_POS -> FLD_TYPE 2003-08-21 PDS

							if ( pRec->Execute( szQuery ) )
							{
								int			nBagItem = 0;
								
								while ( pRec->Fetch() )
								{
									_getfields(pRec, &__ITEMTABLE, (unsigned char *)&tItemFields);
									_setrecordTBagItem(&tItemFields, &rcd.Block.DBBagItem, &nBagItem);
								}
							}
						}
						
						pConn->DestroyRecordset( pRec );
						
						pRec = pConn->CreateRecordset();
						
						// TO PDS
						// if (_makesqlparam(szQuery, SQLTYPE_SELECTWHERE, &__SAVEDITEMTABLE, lhuman.szName ))
						if (_makesqlparam(szQuery, SQLTYPE_SELECTWHERE, &__ITEMTABLE, lhuman.szName , U_SAVE))
						{
							strcat( szQuery ," order by FLD_POS");

							if ( pRec->Execute( szQuery ) )
							{
								int			nSaveItem = 0;
								
								while ( pRec->Fetch() )
								{
									/// TO PDS
									//_getfields(pRec, &__SAVEDITEMTABLE, (unsigned char *)&tItemFields);
									_getfields(pRec, &__ITEMTABLE, (unsigned char *)&tItemFields);

									rcd.Block.DBSaveItem.Items[nSaveItem].MakeIndex	= tItemFields.fld_makeindex;
									rcd.Block.DBSaveItem.Items[nSaveItem].Index		= tItemFields.fld_index;
									rcd.Block.DBSaveItem.Items[nSaveItem].Dura		= tItemFields.fld_dura;
									rcd.Block.DBSaveItem.Items[nSaveItem].DuraMax	= tItemFields.fld_duramax;
									
									for (int i = 0; i < 14; i++)
										rcd.Block.DBSaveItem.Items[nSaveItem].Desc[i]	= (BYTE)tItemFields.fld_desc[i];

									rcd.Block.DBSaveItem.Items[nSaveItem].ColorR		= tItemFields.fld_colorr;
									rcd.Block.DBSaveItem.Items[nSaveItem].ColorG		= tItemFields.fld_colorg;
									rcd.Block.DBSaveItem.Items[nSaveItem].ColorB		= tItemFields.fld_colorb;

									if (strlen(tItemFields.Prefix))
									{
										GetApp()->SetLog( 0, "SavedItem[LOAD] : %c %c %c", tItemFields.Prefix[0], tItemFields.Prefix[1], tItemFields.Prefix[2]);	
										ZeroMemory(rcd.Block.DBSaveItem.Items[nSaveItem].Prefix, sizeof(rcd.Block.DBSaveItem.Items[nSaveItem].Prefix));
	//									strcpy(rcd.Block.DBSaveItem.Items[nSaveItem].Prefix, tItemFields.Prefix);
									}
									else
										ZeroMemory(rcd.Block.DBSaveItem.Items[nSaveItem].Prefix, sizeof(rcd.Block.DBSaveItem.Items[nSaveItem].Prefix));
									
									nSaveItem++;
								}
							}
						}
						
						pConn->DestroyRecordset( pRec );
						
						rr = 1;

					}
					else // if ( pRec->Fetch() )
						pConn->DestroyRecordset( pRec );
				}
				else
					pConn->DestroyRecordset( pRec );
			}
			else
				pConn->DestroyRecordset( pRec );
		}

		GetOdbcPool()->Free( pConn );
	}

	_TDEFAULTMESSAGE	defMsg;
	char				szEncodeMsg[8192 * 2];
	int					nPos = 0;
	int					size=0;
	
	if (rr == 1)
	{
		// total
		//size = sizeof( rcd ) ;
		//size = sizeof ( rcd.Block );
		//size = sizeof ( rcd.Block.DBHuman   );
		//size = sizeof ( rcd.Block.DBBagItem );
		//size = sizeof ( rcd.Block.DBSaveItem);
		//size = sizeof ( rcd.Block.DBUseMagic);

		fnMakeDefMessage( &defMsg, DBR_LOADHUMANRCD, 1, 0, 0, 1 );
		
		nPos = fnEncodeMessage(&defMsg, szEncodeMsg, sizeof(szEncodeMsg));
		
		nPos += fnEncode6BitBuf((unsigned char *)&lhuman.szName[0], &szEncodeMsg[nPos], strlen(lhuman.szName), sizeof(szEncodeMsg) - nPos);

		szEncodeMsg[nPos] = '/';
		nPos++;
		
		nPos += fnEncode6BitBuf((unsigned char *)&rcd, &szEncodeMsg[nPos], sizeof(rcd), sizeof(szEncodeMsg) - nPos);
		szEncodeMsg[nPos] = '\0';

		SendResponse(nCert, szEncodeMsg);

//		m_nLoadCount++;
	}
	else
	{
		fnMakeDefMessage( &defMsg, DBR_LOADHUMANRCD, rr, 0, 0, 0 );
		
		nPos = fnEncodeMessage(&defMsg, szEncodeMsg, sizeof(szEncodeMsg));
		szEncodeMsg[nPos] = '\0';

		SendResponse(nCert, szEncodeMsg);

//		m_nLoadFailCount++;
	}

	return true;
}

void CGameServer::ShowStatusLog()
{
	Lock();

	GetApp()->SetLog(0, "## Load/Save Human Data (%s:%d) => Load:%d/%d, Save:%d/%d", IP(), Port(), m_nLoadCount, m_nLoadFailCount,
							m_nSaveCount, m_nSaveFailCount);

	m_nLoadCount			= 0;
	m_nLoadFailCount		= 0;
	m_nSaveCount			= 0;
	m_nSaveFailCount		= 0;

	Unlock();
}

bool CGameServer::OnSaveHumanRcd( int nCert, char *pBody )
{
	bool				fFail = false;
	bool				fCommit = false;
//	char				szLogMsg [128];
	FDBRecord			rcd;

	char				*pszDevide1 = NULL, *pszDevide2 = NULL;
	
	if ( NULL == pBody ) return false;
	if (!(pszDevide1 = strchr(pBody, '/')))
		fFail = true;
	else
		*pszDevide1++ = '\0';

	if (!(pszDevide2 = strchr(pszDevide1, '/')))
		fFail = true;
	else
		*pszDevide2++ = '\0';

	CDecodedString *pdID = fnDecodeString( pBody );
	CDecodedString *pdName = fnDecodeString( pszDevide1 );
	
	ZeroMemory(&rcd, sizeof(FDBRecord));

// test
//int len = strlen(pszDevide2) - 6;
//GetApp()->SetLog(0, "OnSavedHumanRcdSize:%d", len);

//	if (strlen(pszDevide2) - 6 == (int)(sizeof(FDBRecord)*4/3))
	// SIZEOFFDB(6993) *4/3 == 9324
	if (strlen(pszDevide2) - 6 == 9324 ) //9260, 6594, 6583 , 6582	 // 6647  // Encode FDBRecord size
		fnDecode6BitBuf(pszDevide2, (char *)&rcd, sizeof(FDBRecord));
	else
	{
#ifdef _DEBUG
		char	szLogMsg[128];
		sprintf(szLogMsg, "[Real Packet Size : %d], (Struct Size:%d)\r\n", strlen(pszDevide2) - 6, (int)(sizeof(FDBRecord)*4/3));
		GetApp()->SetLog( 0, szLogMsg );
		GetDBServer()->m_Log.Log ( szLogMsg, false );
#endif
		fFail = true;
	}

	if (strlen(pdName->m_pData) == 0)
		fFail = true;

	if (!fFail)
	{
		CConnection *pConn = GetOdbcPool()->Alloc();

		if ( pConn )
		{
			// pConn->BeginTran();
			pConn->BeginTran();


			CRecordset *pRec = pConn->CreateRecordset();

			if (pRec)
			{
				TCHARACTERFIELDS	tCharFields;
//				TABILITYFIELDS		tAbilFields;

				_setrecordCharFields(&tCharFields, &rcd.Block.DBHuman);
				// To PDS
				//_StrucToFieldsAbil(&tAbilFields, &rcd.Block.DBHuman.Abil, pdName->m_pData);

//				sprintf( szLogMsg, "Update transaction -> User [%s/%s].", pdID->m_pData, pdName->m_pData );
//				GetDBServer()->m_TransLog.Log ( szLogMsg, true );

				if (UpdateRecord(pRec, &__CHARACTERTABLE, (unsigned char *)&tCharFields, false))
				{
					pConn->DestroyRecordset( pRec );
					
				//	pRec = pConn->CreateRecordset();
	
					// TO PDS: if (true)
					// if (UpdateRecord(pRec, &__ABILITYTABLE, (unsigned char *)&tAbilFields, false))
					if ( true )
					{
				//		pConn->DestroyRecordset( pRec );

						if (SaveUseMagic(pConn, &rcd.Block.DBUseMagic, pdName->m_pData))
						{
							if (SaveBagItem(pConn, &rcd.Block.DBBagItem, pdName->m_pData))
							{
								if (SaveSaveItem(pConn, &rcd.Block.DBSaveItem, pdName->m_pData))
								{
									if (SaveQuest(pConn, &rcd.Block.DBHuman, pdName->m_pData))
										fCommit = true;
									else
										fCommit = false;
								}
								else
									fCommit = false;
							}
							else
								fCommit = false;
						}
						else
							fCommit = false;
					}
					else
					{
						pConn->DestroyRecordset( pRec );
						fCommit = false;
					}
				}
				else
				{
					pConn->DestroyRecordset( pRec );
					fCommit = false;
				}
			}

			pConn->EndTran( true );

//			if (fCommit)
//				sprintf( szLogMsg, "Update transaction [commit] -> User [%s/%s].", pdID->m_pData, pdName->m_pData );
//			else
//				sprintf( szLogMsg, "Update transaction [rollback] -> User [%s/%s].", pdID->m_pData, pdName->m_pData );

//			GetApp()->SetLog ( CDBG, szLogMsg );
//			GetDBServer()->m_TransLog.Log ( szLogMsg, true );

			GetOdbcPool()->Free( pConn );
		}
		
	}

	_TDEFAULTMESSAGE	defMsg;
	char				szEncodeMsg[64];

	if (!fFail)
	{
/*		  for i:=0 to UserIdList.Count-1 do begin
			 puser := PTUserIdInfo (UserIdList[i]);
			 if (puser.ChrName = uname) and (puser.Certification = certify) then begin
				puser.OpenTime := GetCurrentTime; //Timeout 연장
			 end;
		  end; */
		fnMakeDefMessage( &defMsg, DBR_SAVEHUMANRCD, 1, 0, 0, 0 );
		
		int	nPos = fnEncodeMessage(&defMsg, szEncodeMsg, sizeof(szEncodeMsg));
		szEncodeMsg[nPos] = '\0';

		SendResponse(nCert, szEncodeMsg);

//		m_nSaveCount++;
	}
	else
	{
		fnMakeDefMessage( &defMsg, DBR_SAVEHUMANRCD, 0, 0, 0, 0 );
		
		int	nPos = fnEncodeMessage(&defMsg, szEncodeMsg, sizeof(szEncodeMsg));
		szEncodeMsg[nPos] = '\0';

		SendResponse(nCert, szEncodeMsg);

//		m_nSaveFailCount++;
	}

	delete pdID;
	delete pdName;

	return true;
}


bool CGameServer::OnSaveAndChange( int nCert, char *pBody )
{
//	bstr szID, szName;
//	_pickstring( pBody, '/', 0, &szID );
//	_pickstring( pBody, '/', 1, &szName );	

//	CDecodedString *pdID = fnDecodeString( szID );
//	CDecodedString *pdName = fnDecodeString( szName );
	// 접근> dID.m_pData

	/*
	   str := GetValidStr3 (body, uid, ['/']);
	   str := GetValidStr3 (str, uname, ['/']);
	   uname := DecodeString (uname);
	   uid := DecodeString (uid);
	   for i:=0 to UserIdList.Count-1 do begin
		  puid := PTUserIdInfo (UserIdList[i]);
		  if (puid.UsrId = uid) and (puid.Certification = certify) then begin
			 puid.RunConnect := FALSE;
			 puid.ServerSocket := usock;
			 puid.Connecting := TRUE;
			 puid.OpenTime := GetCurrentTime;
			 break;
		  end;
	   end;
	   GetSaveHumanRcd (certify, body, usock);
	*/

//	delete pdID;
//	delete pdName;
	OnSaveHumanRcd( nCert, pBody );

	return true;
}


void CGameServer::OnError( int nErrCode )
{
	GetApp()->SetErr( nErrCode );
}


void CGameServer::OnSend( int nTransferred )
{
#ifdef _DEBUG
	GetApp()->SetLog( CSEND, "[GS/%d]", nTransferred );
#endif
}


bool CGameServer::OnRecv( char *pPacket, int nPacketLen )
{
#ifdef _DEBUG
	char __szPacket[256] = {0,};
	memcpy( __szPacket, pPacket, 
		nPacketLen >= sizeof( __szPacket ) ? sizeof( __szPacket ) - 1 : nPacketLen );
	GetApp()->SetLog( CRECV, "[GS/%d]", nPacketLen );
#endif

	if ( NULL == pPacket) return false;
	//
	// 패킷 유효성 검사
	//
	if ( pPacket[0] != '#' || pPacket[nPacketLen - 1] != '!' )
	{
		m_nCntInvalidPacket++;
		return true;
	}

	CCriticalSection cs;
    cs.Lock();
	
	pPacket[nPacketLen - 1] = NULL;

	//
	// 인증 코드를 얻어 데이터가 올바른지 확인한다.
	//
	bstr szCert;
	_pickstring( &pPacket[1], '/', 0, &szCert );
	
	char *pBody = pPacket + strlen( szCert ) + 2;
	int nBodyLen = strlen( pBody );
	int nCert = atoi( szCert );

	if ( !IsValidData( nCert, pBody, nBodyLen ) )
	{
		m_nCntInvalidPacket++;
		cs.Unlock();
		return true;
	}

	//
	// 패킷 ID를 얻는다.
	//
	_TDEFAULTMESSAGE msg;
	fnDecodeMessage( &msg, pBody );

	pBody += _DEFBLOCKSIZE;

	//
	// 해당 프로토콜 함수를 호출한다.
	//
	for ( int i = 0; i < g_nCmdCnt; i++ )
	{
		if ( msg.wIdent == g_cmdList[i].nPacketID )
		{
			try 
			{

			(this->*g_cmdList[i].pfn)( nCert, pBody );
			
			}
			catch(char *str)
			{
			   GetApp()->SetLog(0,"EXCEPT GAME %d %s",nCert , pBody  );			
			}	
		
			cs.Unlock();

			return true;
		}
	}

	cs.Unlock();

	m_nCntInvalidPacket++;
	return true;
}


bool CGameServer::OnExtractPacket( char *pPacket, int *pPacketLen )
{
	char *pEnd = (char *) memchr( m_olRecv.szBuf, '!', m_olRecv.nBufLen );
	if ( !pEnd )
		return false;

	*pPacketLen = ++pEnd - m_olRecv.szBuf;
	memcpy( pPacket, m_olRecv.szBuf, *pPacketLen );	

	return true;
}

//=================================================================================================
// For Friend System...
//=================================================================================================
//-------------------------------------------------------------------------------------------------
// 자신이 등록한 친구 리스트 요청
//-------------------------------------------------------------------------------------------------
bool CGameServer::OnFriendList( int nCert, char *pBody )
{
	bool returnvalue = false;
	// SQL 커넥션을 하나 받아서 
	CConnection *pConn = GetOdbcPool()->Alloc();

	if ( pConn )
	{
		char	szQuery[1024];
		int		nCnt = 0;
		
		// 1000 명 가량 리스트를 구성할수 있다 
		char	szTemp1[8192]="";
		char	szTemp2[8192]="";
		char	*szFldFriend;
		char	*szFldState;
		char	*szFldDesc;

		bstr	szUserName;
		_pickstring( pBody, '/', 0, &szUserName  );

		// 레코드셋 생성
		CRecordset *pRec = pConn->CreateRecordset();

		//--------------------------------------
		//긴 문자열 체크 (DB-Server)
		if( strlen(szUserName) > 20 )
		{
			GetApp()->SetLog( CERR, "[LONG-QUERY MESSAGE!!!1] %s", szUserName );
			GetDBServer()->m_Log.Log( szUserName );
		}
		//--------------------------------------
		
		// 쿼리 생성 
		sprintf( szQuery , "EXEC SP_FRIEND_LIST '%s'",(char *)szUserName);

		// 쿼리 실행
		if ( pRec->Execute( szQuery ) )
		{
			// 컬리 패치 
			while ( pRec->Fetch() )
			{
				// 필드값 얻기
				szFldFriend = pRec->Get( "FLD_FRIEND" );
				szFldState	= pRec->Get( "FLD_STATE" );
				szFldDesc   = pRec->Get( "FLD_DESC" );

				// 세부항목 만들기
				sprintf(szTemp2 , "%s:%s:%s/",szFldState , szFldFriend , szFldDesc );
				strcat( szTemp1 , szTemp2 );
				nCnt++;
			}
			// 최종 리턴값 생성 
			sprintf(szTemp2 , "%d/%s", nCnt , szTemp1 );

			// 게임서버로 저송 
			returnvalue = SendResponse(nCert, 1, (char *)szUserName,DBR_FRIEND_LIST ,DB_FRIEND_LIST ,szTemp2);
		}
		else
		{
			// 쿼리 실패 에러 발생 
		}

		// 레코드셋 삭제 
		pConn->DestroyRecordset( pRec );

	}

	// 커넥션 반납
	GetOdbcPool()->Free( pConn );


	return returnvalue;
}

//-------------------------------------------------------------------------------------------------
// 자신을 등록한 친구 리스트 요청 
//-------------------------------------------------------------------------------------------------
bool CGameServer::OnFriendOwnList( int nCert, char *pBody )
{
	bool returnvalue = false;
	// SQL 커넥션을 하나 받아서 
	CConnection *pConn = GetOdbcPool()->Alloc();

	if ( pConn )
	{
		char	szQuery[1024];
		int		nCnt = 0;
		
		char	szTemp1[8192]="";
		char	szTemp2[8192]="";
		char	*szFldFriend;

		bstr	szUserName;
		_pickstring( pBody, '/', 0, &szUserName  );

		// 레코드셋 생성
		CRecordset *pRec = pConn->CreateRecordset();
		
		//--------------------------------------
		//긴 문자열 체크 (DB-Server)
		if( strlen(szUserName) > 20 )
		{
			GetApp()->SetLog( CERR, "[LONG-QUERY MESSAGE!!!2] %s", szUserName );
			GetDBServer()->m_Log.Log( szUserName );
		}
		//--------------------------------------

		// 쿼리 생성 
		sprintf( szQuery , "EXEC SP_FRIEND_LINKEDLIST '%s'",(char *)szUserName);

		// 쿼리 실행
		if ( pRec->Execute( szQuery ) )
		{
			// 컬리 패치 
			while ( pRec->Fetch() )
			{
				// 필드값 얻기
				szFldFriend = pRec->Get( "FLD_CHARACTER" );

				// 세부항목 만들기
				sprintf(szTemp2 , "%s/",szFldFriend );
				strcat( szTemp1 , szTemp2 );
				nCnt++;
			}
			// 최종 리턴값 생성 
			sprintf(szTemp2 , "%d/%s", nCnt , szTemp1 );

			// 게임서버로 저송 
			returnvalue = SendResponse(nCert, 1, (char *)szUserName,DBR_FRIEND_WONLIST , DB_FRIEND_OWNLIST,  szTemp2);
		}
		else
		{
			// 쿼리 실패 에러 발생 
		}

		// 레코드셋 삭제 
		pConn->DestroyRecordset( pRec );

	}

	// 커넥션 반납
	GetOdbcPool()->Free( pConn );


	return returnvalue;
}

//-------------------------------------------------------------------------------------------------
// 친구 추가 
//-------------------------------------------------------------------------------------------------
bool CGameServer::OnFriendAdd( int nCert, char *pBody )
{
	bool returnvalue = false;
	// SQL 커넥션을 하나 받아서 
	CConnection *pConn = GetOdbcPool()->Alloc();

	if ( pConn )
	{
		char	szQuery[1024];

		bstr	szOwner ;
		bstr	szFriend;
		bstr	szState ;
		bstr	szDesc  ;

		bstr	szUserName;
		_pickstring( pBody, '/', 0, &szUserName  );
		
		bstr	szData;
		_pickstring( pBody, '/', 1, &szData    );

		_pickstring( (char *)szData, ':', 0, &szState  );
		_pickstring( (char *)szData, ':', 1, &szFriend );
		_pickstring( (char *)szData, ':', 2, &szDesc   );

		// 레코드셋 생성
		CRecordset *pRec = pConn->CreateRecordset();
		
		//--------------------------------------
		//긴 문자열 체크 (DB-Server)
		if( strlen(szUserName) > 20 )
		{
			GetApp()->SetLog( CERR, "[LONG-QUERY MESSAGE!!!3] %s", szUserName );
			GetDBServer()->m_Log.Log( szUserName );
		}
		//--------------------------------------

		// 쿼리 생성 
		sprintf( szQuery , "EXEC SP_FRIEND_ADD '%s',%s,'%s','%s'",(char *)szUserName,  (char *)szState, (char *)szFriend, (char *)szDesc);

		// 쿼리 실행
		if ( pRec->Execute( szQuery ) )
			
		{
//			if( pRec->Fetch() )
//			{
//				char *szFldReturn = pRec->Get( "FLD_RETURN" );
//				int  fld_return = atoi(szFldReturn );
//			
//				returnvalue = SendResponse(nCert, fld_return ,(char *)szUserName,DBR_FRIEND_RESULT , DB_FRIEND_ADD ,"");
//			}
		}
		else
		{
			// 쿼리 실패 에러 발생 
		}

		// 레코드셋 삭제 
		pConn->DestroyRecordset( pRec );

	}

	// 커넥션 반납
	GetOdbcPool()->Free( pConn );


	return returnvalue ;
}

//-------------------------------------------------------------------------------------------------
// 친구 삭제 
//-------------------------------------------------------------------------------------------------
bool CGameServer::OnFriendDelete( int nCert, char *pBody )
{
	bool returnvalue = false;
	// SQL 커넥션을 하나 받아서 
	CConnection *pConn = GetOdbcPool()->Alloc();

	if ( pConn )
	{
		char	szQuery[1024];

		bstr	szOwner ;
		bstr	szFriend;

		bstr	szUserName;
		_pickstring( pBody, '/', 0, &szUserName  );
		_pickstring( pBody, '/', 1, &szFriend    );
		

		// 레코드셋 생성
		CRecordset *pRec = pConn->CreateRecordset();
		
		//--------------------------------------
		//긴 문자열 체크 (DB-Server)
		if( strlen(szUserName) > 20 )
		{
			GetApp()->SetLog( CERR, "[LONG-QUERY MESSAGE!!!4] %s", szUserName );
			GetDBServer()->m_Log.Log( szUserName );
		}
		//--------------------------------------

		// 쿼리 생성 
		sprintf( szQuery , "EXEC SP_FRIEND_DELETE '%s','%s'",(char *)szUserName, (char *)szFriend);

		// 쿼리 실행
		if ( pRec->Execute( szQuery ) )
		{
//			if( pRec->Fetch() )
//			{
//				char *szFldReturn = pRec->Get( "FLD_RETURN" );
//				int fld_return    = atoi(szFldReturn );
//
//				returnvalue = SendResponse(nCert, fld_return ,(char *)szUserName,DBR_FRIEND_RESULT , DB_FRIEND_DELETE ,"");
//			}
		}
		else
		{
			// 쿼리 실패 에러 발생 
		}

		// 레코드셋 삭제 
		pConn->DestroyRecordset( pRec );

	}

	// 커넥션 반납
	GetOdbcPool()->Free( pConn );


	return returnvalue ;
}

//-------------------------------------------------------------------------------------------------
// 친구 세부정보 변경 
//-------------------------------------------------------------------------------------------------
bool CGameServer::OnFriendEdit( int nCert, char *pBody )
{
	bool returnvalue = false;
	// SQL 커넥션을 하나 받아서 
	CConnection *pConn = GetOdbcPool()->Alloc();

	if ( pConn )
	{
		char	szQuery[1024];

		bstr	szOwner ;
		bstr	szFriend;
		bstr	szDesc  ;
		
		bstr	szUserName;
		_pickstring( pBody, '/', 0, &szUserName  );
		
		bstr	szData;
		_pickstring( pBody, '/', 1, &szData  );

		_pickstring( (char *)szData, ':', 0, &szFriend );
		_pickstring( (char *)szData, ':', 1, &szDesc   );

		// 레코드셋 생성
		CRecordset *pRec = pConn->CreateRecordset();
		
		//--------------------------------------
		//긴 문자열 체크 (DB-Server)
		if( strlen(szUserName) > 20 )
		{
			GetApp()->SetLog( CERR, "[LONG-QUERY MESSAGE!!!5] %s", szUserName );
			GetDBServer()->m_Log.Log( szUserName );
		}
		//--------------------------------------

		// 쿼리 생성 
		sprintf( szQuery , "EXEC SP_FRIEND_SETDESC '%s','%s','%s'",(char *)szUserName, (char *)szFriend, (char *)szDesc);

		// 쿼리 실행
		if ( pRec->Execute( szQuery )  )
		{
//			if( pRec->Fetch() )
//			{
//				char *szFldReturn = pRec->Get( "FLD_RETURN" );
//				int fld_return = atoi(szFldReturn );
//				returnvalue = SendResponse(nCert, fld_return ,(char *)szUserName,DBR_FRIEND_RESULT,DB_FRIEND_EDIT ,"");
//			}
		}
		else
		{
			// 쿼리 실패 에러 발생 
		}

		// 레코드셋 삭제 
		pConn->DestroyRecordset( pRec );

	}

	// 커넥션 반납
	GetOdbcPool()->Free( pConn );


	return returnvalue ;
}

	
// For Tag System...
//-------------------------------------------------------------------------------------------------
// 쪽지 추가
//-------------------------------------------------------------------------------------------------
bool CGameServer::OnTagAdd( int nCert, char *pBody )
{
	bool returnvalue = false;
	// SQL 커넥션을 하나 받아서 
	CConnection *pConn = GetOdbcPool()->Alloc();

	if ( pConn )
	{
		char	szQuery[1024];

		bstr	szReciever	;
		bstr	szDate		;
		bstr	szState		;
		bstr	szDesc		;
		
		bstr	szUserName;
		_pickstring( pBody, '/', 0, &szUserName  );
		
		bstr	szData;
		_pickstring( pBody, '/', 1, &szData  );

		_pickstring( (char *)szData, ':', 0, &szState	);
		_pickstring( (char *)szData, ':', 1, &szDate	);
		_pickstring( (char *)szData, ':', 2, &szReciever);
		_pickstring( (char *)szData, ':', 3, &szDesc	);

		// 레코드셋 생성
		CRecordset *pRec = pConn->CreateRecordset();
		
		//--------------------------------------
		//긴 문자열 체크 (DB-Server)
		if( strlen(szUserName) > 20 )
		{
			GetApp()->SetLog( CERR, "[LONG-QUERY MESSAGE!!!6] %s", szUserName );
			GetDBServer()->m_Log.Log( szUserName );
		}
		//--------------------------------------

		// 쿼리 생성 
		sprintf(	szQuery , "EXEC SP_TAG_ADD '%s','%s',%s,'%s','%s'",
					(char *)szReciever, (char *)szDate,(char *)szState,(char *)szUserName,(char *)szDesc);

		// 쿼리 실행
		if ( pRec->Execute( szQuery ) )
		{
//			if( pRec->Fetch() )
//			{
//				char *szFldReturn = pRec->Get( "FLD_RETURN" );
//				int fld_return = atoi(szFldReturn );
//				returnvalue = SendResponse(nCert, fld_return, (char *)szUserName,DBR_TAG_RESULT ,DB_TAG_ADD ,"");
//			}
		}
		else
		{
			// 쿼리 실패 에러 발생 
		}

		// 레코드셋 삭제 
		pConn->DestroyRecordset( pRec );

	}

	// 커넥션 반납
	GetOdbcPool()->Free( pConn );


	return returnvalue;
}

//-------------------------------------------------------------------------------------------------
// 쪽지 삭제 
//-------------------------------------------------------------------------------------------------
bool CGameServer::OnTagDelete( int nCert, char *pBody )
{
	bool returnvalue = false;
	// SQL 커넥션을 하나 받아서 
	CConnection *pConn = GetOdbcPool()->Alloc();

	if ( pConn )
	{
		char	szQuery[1024];

		bstr	szReciever	;
		bstr	szSendDate  ;
		
		bstr	szUserName;
		_pickstring( pBody, '/', 0, &szUserName  );
		_pickstring( pBody, '/', 1, &szSendDate  );


		// 레코드셋 생성
		CRecordset *pRec = pConn->CreateRecordset();
		
		//--------------------------------------
		//긴 문자열 체크 (DB-Server)
		if( strlen(szUserName) > 20 )
		{
			GetApp()->SetLog( CERR, "[LONG-QUERY MESSAGE!!!7] %s", szUserName );
			GetDBServer()->m_Log.Log( szUserName );
		}
		//--------------------------------------

		// 쿼리 생성 
		sprintf( szQuery , "EXEC SP_TAG_DELETE '%s','%s'",(char *)szUserName, (char *)szSendDate);

		// 쿼리 실행
		if ( pRec->Execute( szQuery ) )
		{
//			if( pRec->Fetch() )
//			{
//				char *szFldReturn = pRec->Get( "FLD_RETURN" );
//				int  fld_return = atoi(szFldReturn );
//				returnvalue = SendResponse(nCert, fld_return , (char *)szUserName,DBR_TAG_RESULT ,DB_TAG_DELETE , "");
//			}
		}
		else
		{
			// 쿼리 실패 에러 발생 
		}

		// 레코드셋 삭제 
		pConn->DestroyRecordset( pRec );

	}

	// 커넥션 반납
	GetOdbcPool()->Free( pConn );


	return returnvalue;
}

//-------------------------------------------------------------------------------------------------
// 쪽지 전부 삭제 
//-------------------------------------------------------------------------------------------------
bool CGameServer::OnTagDeleteAll( int nCert, char *pBody )
{
	bool returnvalue = false;
	// SQL 커넥션을 하나 받아서 
	CConnection *pConn = GetOdbcPool()->Alloc();

	if ( pConn )
	{
		char	szQuery[1024];


		bstr	szUserName;
		_pickstring( pBody, '/', 0, &szUserName  );

		// 레코드셋 생성
		CRecordset *pRec = pConn->CreateRecordset();
		
		//--------------------------------------
		//긴 문자열 체크 (DB-Server)
		if( strlen(szUserName) > 20 )
		{
			GetApp()->SetLog( CERR, "[LONG-QUERY MESSAGE!!!8] %s", szUserName );
			GetDBServer()->m_Log.Log( szUserName );
		}
		//--------------------------------------

		// 쿼리 생성 
		sprintf( szQuery , "EXEC SP_TAG_DELETEALL '%s'",(char *)szUserName);

		// 쿼리 실행
		if ( pRec->Execute( szQuery ) )
		{
//			if( pRec->Fetch() )
//			{
//				char *szFldReturn = pRec->Get( "FLD_RETURN" );
//				int fld_return = atoi(szFldReturn );
//				returnvalue = SendResponse(nCert, fld_return ,(char *)szUserName,DBR_TAG_RESULT ,DB_TAG_DELETEALL, "");
//			}
		}
		else
		{
			// 쿼리 실패 에러 발생 
		}

		// 레코드셋 삭제 
		pConn->DestroyRecordset( pRec );

	}

	// 커넥션 반납
	GetOdbcPool()->Free( pConn );


	return returnvalue;
}

//-------------------------------------------------------------------------------------------------
// 쪽지 리스트 요청 
//-------------------------------------------------------------------------------------------------
bool CGameServer::OnTagList( int nCert, char *pBody )
{
	bool returnvalue = false;
	// SQL 커넥션을 하나 받아서 
	CConnection *pConn = GetOdbcPool()->Alloc();

	if ( pConn )
	{
		char	szQuery[1024];
		int		nCnt = 0;
		
		char	szTemp1[8192]="";
		char	szTemp2[8192]="";
		char	*szFldState;
		char	*szFldDate;
		char    *szFldSender;
		char	*szFldDesc;

		bstr	szUserName;
		_pickstring( pBody, '/', 0, &szUserName  );

		// 레코드셋 생성
		CRecordset *pRec = pConn->CreateRecordset();
		
		//--------------------------------------
		//긴 문자열 체크 (DB-Server)
		if( strlen(szUserName) > 20 )
		{
			GetApp()->SetLog( CERR, "[LONG-QUERY MESSAGE!!!9] %s", szUserName );
			GetDBServer()->m_Log.Log( szUserName );
		}
		//--------------------------------------

		// 쿼리 생성 
		sprintf( szQuery , "EXEC SP_TAG_LIST '%s'", (char *)szUserName );

		// 쿼리 실행
		if ( pRec->Execute( szQuery ) )
		{
			// 컬리 패치 
			while ( pRec->Fetch() )
			{
				// 필드값 얻기
				szFldState	= pRec->Get( "FLD_STATE" );
				szFldDate   = pRec->Get( "FLD_DATE" );
				szFldSender = pRec->Get( "FLD_SENDER" );
				szFldDesc   = pRec->Get( "FLD_DESC" );

				// 세부항목 만들기
				sprintf(szTemp2 , "%s:%s:%s:%s/",szFldState , szFldDate ,szFldSender, szFldDesc );
				strcat( szTemp1 , szTemp2 );
				nCnt++;
			}
			// 최종 리턴값 생성 
			sprintf(szTemp2 , "%d/%s", nCnt , szTemp1 );

			// 게임서버로 저송 
			returnvalue = SendResponse(nCert, 1, (char *)szUserName,DBR_TAG_LIST ,DB_TAG_LIST,szTemp2);
		}
		else
		{
			// 쿼리 실패 에러 발생 
		}

		// 레코드셋 삭제 
		pConn->DestroyRecordset( pRec );

	}

	// 커넥션 반납
	GetOdbcPool()->Free( pConn );


	return returnvalue;
}

//-------------------------------------------------------------------------------------------------
// 쪽지 정보 변경  
//-------------------------------------------------------------------------------------------------
bool CGameServer::OnTagSetInfo( int nCert, char *pBody )
{
	bool returnvalue = false;
	// SQL 커넥션을 하나 받아서 
	CConnection *pConn = GetOdbcPool()->Alloc();

	if ( pConn )
	{
		char	szQuery[1024];


		bstr    szTemp;
		bstr	szDate;
		bstr    szState;
		bstr	szUserName;
		
		_pickstring( pBody, '/', 0, &szUserName  );
		_pickstring( pBody, '/', 1, &szTemp );

		_pickstring( szTemp, ':', 0, &szState );
		_pickstring( szTemp, ':', 1, &szDate );


		// 레코드셋 생성
		CRecordset *pRec = pConn->CreateRecordset();
		
		//--------------------------------------
		//긴 문자열 체크 (DB-Server)
		if( strlen(szUserName) > 20 )
		{
			GetApp()->SetLog( CERR, "[LONG-QUERY MESSAGE!!!10] %s", szUserName );
			GetDBServer()->m_Log.Log( szUserName );
		}
		//--------------------------------------

		// 쿼리 생성 
		sprintf( szQuery , "EXEC SP_TAG_SETINFO '%s','%s',%s",(char *)szUserName,(char *)szDate , (char *)szState);

		// 쿼리 실행
		if ( pRec->Execute( szQuery ) )
		{
//			if( pRec->Fetch() )
//			{
//				char *szFldReturn = pRec->Get( "FLD_RETURN" );
//				int fld_return = atoi(szFldReturn );
//				returnvalue = SendResponse(nCert, fld_return ,(char *)szUserName,DBR_TAG_RESULT ,DB_TAG_SETINFO, "");
//			}
		}
		else
		{
			// 쿼리 실패 에러 발생 
		}

		// 레코드셋 삭제 
		pConn->DestroyRecordset( pRec );

	}

	// 커넥션 반납
	GetOdbcPool()->Free( pConn );


	return returnvalue;
}

//-------------------------------------------------------------------------------------------------
// 거부자 추가
//-------------------------------------------------------------------------------------------------
bool CGameServer::OnTagRejectAdd( int nCert, char *pBody )
{
	bool returnvalue = false;
	// SQL 커넥션을 하나 받아서 
	CConnection *pConn = GetOdbcPool()->Alloc();

	if ( pConn )
	{
		char	szQuery[1024];

		bstr	szUserName	;
		bstr	szRejecter	;
		
		_pickstring( pBody, '/', 0, &szUserName );
		_pickstring( pBody, '/', 1, &szRejecter );
		// 레코드셋 생성
		CRecordset *pRec = pConn->CreateRecordset();
		
		//--------------------------------------
		//긴 문자열 체크 (DB-Server)
		if( strlen(szUserName) > 20 )
		{
			GetApp()->SetLog( CERR, "[LONG-QUERY MESSAGE!!!11] %s", szUserName );
			GetDBServer()->m_Log.Log( szUserName );
		}
		//--------------------------------------

		// 쿼리 생성 
		sprintf( szQuery , "EXEC SP_TAG_REJECTADD '%s','%s'",(char *)szUserName, (char *)szRejecter);

		// 쿼리 실행
		if ( pRec->Execute( szQuery ) )
		{
//			if( pRec->Fetch() )
//			{
//				char *szFldReturn = pRec->Get( "FLD_RETURN" );
//				int fld_return = atoi(szFldReturn );
//				returnvalue = SendResponse(nCert, fld_return , (char *)szUserName,DBR_TAG_RESULT,DB_TAG_REJECT_ADD ,"");
//			}
		}
		else
		{
			// 쿼리 실패 에러 발생 
		}

		// 레코드셋 삭제 
		pConn->DestroyRecordset( pRec );

	}

	// 커넥션 반납
	GetOdbcPool()->Free( pConn );


	return returnvalue;
}

//-------------------------------------------------------------------------------------------------
// 거부자 삭제 
//-------------------------------------------------------------------------------------------------
bool CGameServer::OnTagRejectDelete( int nCert, char *pBody )
{
	bool returnvalue = false;
	// SQL 커넥션을 하나 받아서 
	CConnection *pConn = GetOdbcPool()->Alloc();

	if ( pConn )
	{
		char	szQuery[1024];

		bstr	szUserName	;
		bstr	szRejecter	;
		
		_pickstring( pBody, '/', 0, &szUserName );
		_pickstring( pBody, '/', 1, &szRejecter );

		// 레코드셋 생성
		CRecordset *pRec = pConn->CreateRecordset();
		
		//--------------------------------------
		//긴 문자열 체크 (DB-Server)
		if( strlen(szUserName) > 20 )
		{
			GetApp()->SetLog( CERR, "[LONG-QUERY MESSAGE!!!12] %s", szUserName );
			GetDBServer()->m_Log.Log( szUserName );
		}
		//--------------------------------------

		// 쿼리 생성 
		sprintf( szQuery , "EXEC SP_TAG_REJECTDELETE '%s','%s'",(char *)szUserName, (char *)szRejecter);

		// 쿼리 실행
		if ( pRec->Execute( szQuery ) )
		{
//			if( pRec->Fetch() )
//			{
//				char *szFldReturn = pRec->Get( "FLD_RETURN" );
//				int  fld_return = atoi(szFldReturn );
//				returnvalue = SendResponse(nCert, fld_return, (char *)szUserName,DBR_TAG_RESULT ,DB_TAG_REJECT_DELETE ,"");
//			}
		}
		else
		{
			// 쿼리 실패 에러 발생 
		}

		// 레코드셋 삭제 
		pConn->DestroyRecordset( pRec );

	}

	// 커넥션 반납
	GetOdbcPool()->Free( pConn );


	return returnvalue;
}

//-------------------------------------------------------------------------------------------------
// 거부자 리스트 요청
//-------------------------------------------------------------------------------------------------
bool CGameServer::OnTagRejectList( int nCert, char *pBody )
{
	bool returnvalue = false;
	// SQL 커넥션을 하나 받아서 
	CConnection *pConn = GetOdbcPool()->Alloc();

	if ( pConn )
	{
		char	szQuery[1024];
		int		nCnt = 0;
		
		char	szTemp1[8192]="";
		char	szTemp2[8192]="";
		char	*szFldRejecter;

		bstr	szUserName;
		_pickstring( pBody, '/', 0, &szUserName  );
		// 레코드셋 생성
		CRecordset *pRec = pConn->CreateRecordset();
		
		//--------------------------------------
		//긴 문자열 체크 (DB-Server)
		if( strlen(szUserName) > 20 )
		{
			GetApp()->SetLog( CERR, "[LONG-QUERY MESSAGE!!!13] %s", szUserName );
			GetDBServer()->m_Log.Log( szUserName );
		}
		//--------------------------------------

		// 쿼리 생성 
		sprintf( szQuery , "EXEC SP_TAG_REJECTLIST '%s'", (char *)szUserName);

		// 쿼리 실행
		if ( pRec->Execute( szQuery ) )
		{
			// 컬리 패치 
			while ( pRec->Fetch() )
			{
				// 필드값 얻기
				szFldRejecter = pRec->Get( "FLD_REJECTER" );

				// 세부항목 만들기
				sprintf(szTemp2 , "%s/",szFldRejecter);
				strcat( szTemp1 , szTemp2 );
				nCnt++;
			}
			// 최종 리턴값 생성 
			sprintf(szTemp2 , "%d/%s", nCnt , szTemp1 );

			// 게임서버로 저송 
			returnvalue = SendResponse(nCert, 1, (char *)szUserName,DBR_TAG_REJECT_LIST, DB_TAG_REJECT_LIST ,szTemp2);
		}
		else
		{
			// 쿼리 실패 에러 발생 
		}

		// 레코드셋 삭제 
		pConn->DestroyRecordset( pRec );

	}

	// 커넥션 반납
	GetOdbcPool()->Free( pConn );

	return returnvalue;
}

//-------------------------------------------------------------------------------------------------
// 읽지않은 쪽지 개수 요청 
//-------------------------------------------------------------------------------------------------
bool CGameServer::OnTagNotReadCount( int nCert, char *pBody )
{
	bool returnvalue = false;
	// SQL 커넥션을 하나 받아서 
	CConnection *pConn = GetOdbcPool()->Alloc();

	if ( pConn )
	{
		char	szQuery[1024];
		int		nCnt = 0;
		
		char	szTemp2[2048]="";
		char	*szFldCount;

		bstr	szUserName;
		_pickstring( pBody, '/', 0, &szUserName  );
		// 레코드셋 생성
		CRecordset *pRec = pConn->CreateRecordset();
		
		//--------------------------------------
		//긴 문자열 체크 (DB-Server)
		if( strlen(szUserName) > 20 )
		{
			GetApp()->SetLog( CERR, "[LONG-QUERY MESSAGE!!!14] %s", szUserName );
			GetDBServer()->m_Log.Log( szUserName );
		}
		//--------------------------------------

		// 쿼리 생성 
		sprintf( szQuery , "EXEC SP_TAG_NOTREADCOUNT '%s'",(char *)szUserName);

		// 쿼리 실행
		if ( pRec->Execute( szQuery ) )
		{
			// 컬리 패치 
			if ( pRec->Fetch() )
			{
				// 필드값 얻기
				szFldCount = pRec->Get( "FLD_COUNT" );

			}
			// 최종 리턴값 생성 
			sprintf(szTemp2 , "%d/%s", nCnt , szFldCount );

			// 게임서버로 저송 
			returnvalue = SendResponse(nCert,1, (char *)szUserName,DBR_TAG_NOTREADCOUNT,DB_TAG_NOTREADCOUNT,szTemp2);
		}
		else
		{
			// 쿼리 실패 에러 발생 
		}

		// 레코드셋 삭제 
		pConn->DestroyRecordset( pRec );

	}

	// 커넥션 반납
	GetOdbcPool()->Free( pConn );


	return returnvalue;
}


//-------------------------------------------------------------------------------------------------
// 관계 리스트 요청 
//-------------------------------------------------------------------------------------------------
bool CGameServer::OnLMList( int nCert, char *pBody )
{
	bool returnvalue = false;
	// SQL 커넥션을 하나 받아서 
	CConnection *pConn = GetOdbcPool()->Alloc();

	if ( pConn )
	{
		char	szQuery[1024];
		int		nCnt = 0;
		
		char	szTemp1[2048]="";
		char	szTemp2[2048]="";
		char	*szFldOther;
		char	*szFldState;
		char	*szFldMsg;
		char	*szFldDate;
		char	*szFldLevel;
		char	*szFldSex;

		bstr	szUserName;
		_pickstring( pBody, '/', 0, &szUserName  );
		// 레코드셋 생성
		CRecordset *pRec = pConn->CreateRecordset();
		
		//--------------------------------------
		//긴 문자열 체크 (DB-Server)
		if( strlen(szUserName) > 20 )
		{
			GetApp()->SetLog( CERR, "[LONG-QUERY MESSAGE!!!15] %s", szUserName );
			GetDBServer()->m_Log.Log( szUserName );
		}
		//--------------------------------------

		// 쿼리 생성 
		sprintf( szQuery , "EXEC SP_LM_LIST '%s'", (char *)szUserName);

		// 쿼리 실행
		if ( pRec->Execute( szQuery ) )
		{
			// 컬리 패치 
			while ( pRec->Fetch() )
			{
				// 필드값 얻기
				// SELECT A.FLD_OTHER , A.FLD_STATE, A.FLD_MSG,A.FLD_DATE ,B.FLD_LEVEL,B.FLD_SEX  FROM TBL_LM A , TBL_CHARACTER B WHERE A.FLD_CHARACTER = @szReciever and A.FLD_OTHER = B.FLD_CHARACTER
				
				szFldOther = pRec->Get( "FLD_OTHER" );
				szFldState = pRec->Get( "FLD_STATE" );
				szFldMsg   = pRec->Get( "FLD_MSG" );
				szFldDate  = pRec->Get( "FLD_DATE" );
				szFldLevel = pRec->Get( "FLD_LEVEL" );
				szFldSex   = pRec->Get( "FLD_SEX" );

				// 세부항목 만들기 
				// 케릭터이름:등록상태:메세지:등록일자:레벨:성별/
				sprintf(szTemp2 , "%s:%s:%s:%s:%s:%s/",szFldOther, szFldState,szFldMsg,szFldDate,szFldLevel,szFldSex);
				strcat( szTemp1 , szTemp2 );
				nCnt++;
			}
			// 최종 리턴값 생성 
			sprintf(szTemp2 , "%d/%s", nCnt , szTemp1 );

			// 게임서버로 저송 
			returnvalue = SendResponse(nCert, 1, (char *)szUserName,DBR_LM_LIST, DB_LM_LIST ,szTemp2);
		}
		else
		{
			// 쿼리 실패 에러 발생 
		}

		// 레코드셋 삭제 
		pConn->DestroyRecordset( pRec );

	}

	// 커넥션 반납
	GetOdbcPool()->Free( pConn );

	return returnvalue;
}

//-------------------------------------------------------------------------------------------------
// 관계  추가 
//-------------------------------------------------------------------------------------------------
bool CGameServer::OnLMAdd( int nCert, char *pBody )
{
	bool returnvalue = false;
	// SQL 커넥션을 하나 받아서 
	CConnection *pConn = GetOdbcPool()->Alloc();

	if ( pConn )
	{
		char	szQuery[1024];

		bstr	szOwner ;
		bstr	szOther;
		bstr	szState ;
		bstr	szDate  ;

		bstr	szUserName;
		_pickstring( pBody, '/', 0, &szUserName  );
		
		bstr	szData;
		_pickstring( pBody, '/', 1, &szData    );

		_pickstring( (char *)szData, ':', 0, &szOther );
		_pickstring( (char *)szData, ':', 1, &szState );
		_pickstring( (char *)szData, ':', 2, &szDate  );

		// 레코드셋 생성
		CRecordset *pRec = pConn->CreateRecordset();
		
		//--------------------------------------
		//긴 문자열 체크 (DB-Server)
		if( strlen(szUserName) > 20 )
		{
			GetApp()->SetLog( CERR, "[LONG-QUERY MESSAGE!!!16] %s", szUserName );
			GetDBServer()->m_Log.Log( szUserName );
		}
		//--------------------------------------

		// 쿼리 생성 
		sprintf( szQuery , "EXEC SP_LM_ADD '%s','%s',%s,'%s'",(char *)szUserName,  (char *)szOther, (char *)szState, (char *)szDate);

		// 쿼리 실행
		if ( pRec->Execute( szQuery ) )
			
		{
			// 쿼리 성공 
		}
		else
		{
			// 쿼리 실패 에러 발생 
		}

		// 레코드셋 삭제 
		pConn->DestroyRecordset( pRec );

	}

	// 커넥션 반납
	GetOdbcPool()->Free( pConn );


	return returnvalue ;
}

//-------------------------------------------------------------------------------------------------
// 친구 삭제 
//-------------------------------------------------------------------------------------------------
bool CGameServer::OnLMDelete( int nCert, char *pBody )
{
	bool returnvalue = false;
	// SQL 커넥션을 하나 받아서 
	CConnection *pConn = GetOdbcPool()->Alloc();

	if ( pConn )
	{
		char	szQuery[1024];

		bstr	szOwner ;
		bstr	szOther;

		bstr	szUserName;
		_pickstring( pBody, '/', 0, &szUserName  );
		_pickstring( pBody, '/', 1, &szOther    );
		

		// 레코드셋 생성
		CRecordset *pRec = pConn->CreateRecordset();
		
		//--------------------------------------
		//긴 문자열 체크 (DB-Server)
		if( strlen(szUserName) > 20 )
		{
			GetApp()->SetLog( CERR, "[LONG-QUERY MESSAGE!!!17] %s", szUserName );
			GetDBServer()->m_Log.Log( szUserName );
		}
		//--------------------------------------

		// 쿼리 생성 
		sprintf( szQuery , "EXEC SP_LM_DELETE '%s','%s'",(char *)szUserName, (char *)szOther);

		// 쿼리 실행
		if ( pRec->Execute( szQuery ) )
		{
			// 쿼리 성공 
		}
		else
		{
			// 쿼리 실패 에러 발생 
		}

		// 레코드셋 삭제 
		pConn->DestroyRecordset( pRec );

	}

	// 커넥션 반납
	GetOdbcPool()->Free( pConn );


	return returnvalue ;
}

//-------------------------------------------------------------------------------------------------
// 친구 세부정보 변경 
//-------------------------------------------------------------------------------------------------
bool CGameServer::OnLMEdit( int nCert, char *pBody )
{
	bool returnvalue = false;
	// SQL 커넥션을 하나 받아서 
	CConnection *pConn = GetOdbcPool()->Alloc();

	if ( pConn )
	{
		char	szQuery[1024];

		bstr	szOwner ;
		bstr	szOther ;
		bstr	szState ;
		bstr	szMsg   ;
		
		bstr	szUserName;
		_pickstring( pBody, '/', 0, &szUserName  );
		
		bstr	szData;
		_pickstring( pBody, '/', 1, &szData  );

		_pickstring( (char *)szData, ':', 0, &szOther );
		_pickstring( (char *)szData, ':', 1, &szState );
		_pickstring( (char *)szData, ':', 2, &szMsg   );

		// 레코드셋 생성
		CRecordset *pRec = pConn->CreateRecordset();
		
		//--------------------------------------
		//긴 문자열 체크 (DB-Server)
		if( strlen(szUserName) > 20 )
		{
			GetApp()->SetLog( CERR, "[LONG-QUERY MESSAGE!!!18] %s", szUserName );
			GetDBServer()->m_Log.Log( szUserName );
		}
		//--------------------------------------

		// 쿼리 생성 
		sprintf( szQuery , "EXEC SP_LM_EDIT '%s','%s',%s,%s",(char *)szUserName, (char *)szOther, (char *)szState, (char *)szMsg);

		// 쿼리 실행
		if ( pRec->Execute( szQuery )  )
		{
			// 쿼리 성공 
		}
		else
		{
			// 쿼리 실패 에러 발생 
		}

		// 레코드셋 삭제 
		pConn->DestroyRecordset( pRec );

	}

	// 커넥션 반납
	GetOdbcPool()->Free( pConn );


	return returnvalue ;
}

//=================================================================================================
// 동작구현 
//=================================================================================================
bool CGameServer::IsValidData( int nCert, char *pData, int nDataLen )
{
	if ( nDataLen < _DEFBLOCKSIZE /*|| !nCert*/ )
		return false;
	
	if ( NULL == pData )
		return false;

	nCert = ((nCert & 0xFFFF) ^ 0xAA) | (nDataLen << 16);

	char szEncoded[6];
	fnEncode6BitBuf( (BYTE *) &nCert, szEncoded, 4, sizeof( szEncoded ) );

	return memcmp( szEncoded, (pData + nDataLen - sizeof( szEncoded )), sizeof( szEncoded ) ) == 0;
}

bool CGameServer::SaveUserItem(CConnection *pConn, MIRDB_TABLE* pTable, LPTUserItem pUserItem, int nType, char *pszName , int nPos)
{
	TITEMFIELDS	tItemFields;

	CRecordset *pRec = pConn->CreateRecordset();

	ZeroMemory(&tItemFields, sizeof(TITEMFIELDS));
	_setrecordTItemFields(&tItemFields, pUserItem, nType, pszName ,nPos);

	if (UpdateRecord(pRec, pTable, (unsigned char *)&tItemFields, true))
	{
		pConn->DestroyRecordset( pRec );
		return true;
	}

	pConn->DestroyRecordset( pRec );

	return false;
}

bool CGameServer::SaveBagItem(CConnection *pConn, LPTBagItem pBagItem, char *pszName)
{
	char		szQuery[1024];

	CRecordset *pRec = pConn->CreateRecordset();

	if (_makesqlparam(szQuery, SQLTYPE_DELETENOT, &__ITEMTABLE, pszName , U_SAVE))
	{
		pRec->Execute( szQuery );
//		if ( pRec->Execute( szQuery ) )
//		{
//			if ( pRec->GetRowCount() == 0)
//				fFail = true;
//		}
	}

	pConn->DestroyRecordset( pRec );

	if (pBagItem->uDress.MakeIndex)
	{
		SaveUserItem(pConn, &__ITEMTABLE, &pBagItem->uDress, U_DRESS, pszName , 0);
//		if (!SaveUserItem(pConn, &__ITEMTABLE, &pBagItem->uDress, U_DRESS, pszName))
//			return false;
	}

	if (pBagItem->uWeapon.MakeIndex)
	{
		SaveUserItem(pConn, &__ITEMTABLE, &pBagItem->uWeapon, U_WEAPON, pszName , 0);
//		if (!SaveUserItem(pConn, &__ITEMTABLE, &pBagItem->uWeapon, U_WEAPON, pszName))
//			return false;
	}

	if (pBagItem->uRightHand.MakeIndex)
	{
		SaveUserItem(pConn, &__ITEMTABLE, &pBagItem->uRightHand, U_RIGHTHAND, pszName , 0);
//		if (!SaveUserItem(pConn, &__ITEMTABLE, &pBagItem->uRightHand, U_RIGHTHAND, pszName))
//			return false;
	}

	if (pBagItem->uHelmet.MakeIndex)
	{
		SaveUserItem(pConn, &__ITEMTABLE, &pBagItem->uHelmet, U_HELMET, pszName ,0);
//		if (!SaveUserItem(pConn, &__ITEMTABLE, &pBagItem->uHelmet, U_HELMET, pszName))
//			return false;
	}

	if (pBagItem->uNecklace.MakeIndex)
	{
		SaveUserItem(pConn, &__ITEMTABLE, &pBagItem->uNecklace, U_NECKLACE, pszName ,0);
//		if (!SaveUserItem(pConn, &__ITEMTABLE, &pBagItem->uNecklace, U_NECKLACE, pszName))
//			return false;
	}

	if (pBagItem->uArmRingL.MakeIndex)
	{
		SaveUserItem(pConn, &__ITEMTABLE, &pBagItem->uArmRingL, U_ARMRINGL, pszName ,0);
//		if (!SaveUserItem(pConn, &__ITEMTABLE, &pBagItem->uArmRingL, U_ARMRINGL, pszName))
//			return false;
	}

	if (pBagItem->uArmRingR.MakeIndex)
	{
		SaveUserItem(pConn, &__ITEMTABLE, &pBagItem->uArmRingR, U_ARMRINGR, pszName ,0);
//		if (!SaveUserItem(pConn, &__ITEMTABLE, &pBagItem->uArmRingR, U_ARMRINGR, pszName))
//			return false;
	}

	if (pBagItem->uRingL.MakeIndex)
	{
		SaveUserItem(pConn, &__ITEMTABLE, &pBagItem->uRingL, U_RINGL, pszName, 0);
//		if (!SaveUserItem(pConn, &__ITEMTABLE, &pBagItem->uRingL, U_RINGL, pszName))
//			return false;
	}

	if (pBagItem->uRingR.MakeIndex)
	{
		SaveUserItem(pConn, &__ITEMTABLE, &pBagItem->uRingR, U_RINGR, pszName , 0);
//		if (!SaveUserItem(pConn, &__ITEMTABLE, &pBagItem->uRingR, U_RINGR, pszName))
//			return false;
	}

	if (pBagItem->uBujuck.MakeIndex)
		SaveUserItem(pConn, &__ITEMTABLE, &pBagItem->uBujuck, U_BUJUCK, pszName ,0);

	if (pBagItem->uBelt.MakeIndex)
		SaveUserItem(pConn, &__ITEMTABLE, &pBagItem->uBelt, U_BELT, pszName, 0);


	if (pBagItem->uBoots.MakeIndex)
		SaveUserItem(pConn, &__ITEMTABLE, &pBagItem->uBoots, U_BOOTS, pszName, 0);
	
	// TO PDS:
	if (pBagItem->uCharm.MakeIndex)
		SaveUserItem(pConn, &__ITEMTABLE, &pBagItem->uCharm, U_CHARM, pszName, 0);


	for (int i = 0; i < MAXBAGITEM; i++)
	{
		if (( pBagItem->Bags[i].MakeIndex ) && ( pBagItem->Bags[i].Index > 0  ))
		{
			SaveUserItem(pConn, &__ITEMTABLE, &pBagItem->Bags[i], U_BAG, pszName , i);
//			if (!SaveUserItem(pConn, &__ITEMTABLE, &pBagItem->Bags[i], U_BAG, pszName))
//				return false;
		}
	}

	return true;
}

bool CGameServer::SaveSaveItem(CConnection *pConn, LPTSaveItem pSaveItem, char *pszName)
{
	char		szQuery[512];

	CRecordset *pRec = pConn->CreateRecordset();

	// TO PDS:_makesqlparam(szQuery, SQLTYPE_DELETE, &__ITEMTABLE, U_SAVE ,pszName))로 
	// if (_makesqlparam(szQuery, SQLTYPE_DELETE, &__SAVEDITEMTABLE, pszName))
	 if (_makesqlparam(szQuery, SQLTYPE_DELETE, &__ITEMTABLE, pszName , U_SAVE))
	{
		pRec->Execute( szQuery );
//		if ( pRec->Execute( szQuery ) )
//		{
//			if ( pRec->GetRowCount() == 0)
//				fFail = true;
//		}
	}

	pConn->DestroyRecordset( pRec );

	for (int i = 0; i < MAXSAVEITEM; i++)
	{
		if ( ( pSaveItem->Items[i].MakeIndex > 0 ) && ( pSaveItem->Items[i].Index > 0 ))
		{
			// TO PDS:SaveUserItem(pConn, &__ITEMTABLE, &pSaveItem->Items[i], U_SAVE, pszName);
			// SaveUserItem(pConn, &__SAVEDITEMTABLE, &pSaveItem->Items[i], U_SAVE, pszName);
			SaveUserItem(pConn, &__ITEMTABLE, &pSaveItem->Items[i], U_SAVE, pszName , i);
//			if (!SaveUserItem(pConn, &__SAVEDITEMTABLE, &pSaveItem->Items[i], U_SAVE, pszName))
//				return false;
		}
	}

	return true;
}

bool CGameServer::SaveUseMagic(CConnection *pConn, LPTUseMagic pUseMagic, char *pszName)
{
	char				szQuery[512];
	TMAGICFIELDS		tMagicFields;
	CRecordset			*pRec = pConn->CreateRecordset();

	if (_makesqlparam(szQuery, SQLTYPE_DELETE, &__MAGICTABLE, pszName))
	{
		pRec->Execute( szQuery );
//		if ( pRec->Execute( szQuery ) )
//		{
//			if ( pRec->GetRowCount() == 0)
//				fFail = true;
//		}
	}

	pConn->DestroyRecordset( pRec );

	for (int i = 0; i < MAXUSERMAGIC; i++)
	{
		if (pUseMagic->Magics[i].MagicId)
		{
			_StrucToFieldsUseMagic(&tMagicFields, &pUseMagic->Magics[i], pszName , i);

			pRec = pConn->CreateRecordset();
			UpdateRecord(pRec, &__MAGICTABLE, (unsigned char *)&tMagicFields, true);
			pConn->DestroyRecordset( pRec );
		}
	}

	return true;
}

bool CGameServer::SaveQuest(CConnection *pConn, LPTHuman lptHuman, char *pszName)
{
	char			szQuery[8192];
	TQUESTFIELDS	tQuestFields;
	CRecordset		*pRec = pConn->CreateRecordset();

	ZeroMemory(&tQuestFields, sizeof(tQuestFields));

	int nPos = fnEncode6BitBuf_old(lptHuman->QuestOpenIndex, tQuestFields.fld_questopenindex, 
								sizeof(lptHuman->QuestOpenIndex), sizeof(tQuestFields.fld_questopenindex));
	tQuestFields.fld_questopenindex[nPos] = '\0';
 	
	nPos = fnEncode6BitBuf_old(lptHuman->QuestFinIndex, tQuestFields.fld_questfinindex, 
								sizeof(lptHuman->QuestFinIndex), sizeof(tQuestFields.fld_questfinindex));
	tQuestFields.fld_questfinindex[nPos] = '\0';

	nPos = fnEncode6BitBuf_old(lptHuman->Quest, tQuestFields.fld_quest, 
								sizeof(lptHuman->Quest), sizeof(tQuestFields.fld_quest));
	tQuestFields.fld_quest[nPos] = '\0';

	strcpy(tQuestFields.fld_character, pszName);

	_makesql(szQuery, SQLTYPE_UPDATE, &__QUESTTABLE, (unsigned char *)&tQuestFields);

	if ( pRec->Execute( szQuery ) )
	{
		if (pRec->GetRowCount())
		{
			pConn->DestroyRecordset( pRec );
			return true;
		}
	}

	GetDBServer()->m_TransLog.Log ( szQuery, true );

	pConn->DestroyRecordset( pRec );

	return false;
}

bool CGameServer::LoadQuest(CConnection *pConn, LPTHuman lptHuman, char *pszName)
{
	char			szQuery[8192];
	TQUESTFIELDS	tQuestFields;
	CRecordset		*pRec = pConn->CreateRecordset();

	_makesqlparam(szQuery, SQLTYPE_SELECTWHERE, &__QUESTTABLE, pszName);

	if ( pRec->Execute( szQuery ) )
	{
		if ( pRec->Fetch() )
		{
			_getfields(pRec, &__QUESTTABLE, (unsigned char *)&tQuestFields);

			if (strlen(tQuestFields.fld_questopenindex))
				fnDecode6BitBuf_old(tQuestFields.fld_questopenindex, (char *)lptHuman->QuestOpenIndex, sizeof(lptHuman->QuestOpenIndex));
			if (strlen(tQuestFields.fld_questfinindex))
				fnDecode6BitBuf_old(tQuestFields.fld_questfinindex, (char *)lptHuman->QuestFinIndex, sizeof(lptHuman->QuestFinIndex));
			if (strlen(tQuestFields.fld_quest))
				fnDecode6BitBuf_old(tQuestFields.fld_quest, (char *)lptHuman->Quest, sizeof(lptHuman->Quest));
		}
	}

	pConn->DestroyRecordset( pRec );

	return true;
}

