

#include <database.h>
#include "../common/mir2packet.h"
#include "../common/sqlhandler.h"
#include "netrungate.h"
#include "tablesdefine.h"
#include "dbsvrwnd.h"
#include <stringex.h>
#include <stdio.h>
#include <stdlib.h>

static struct sRunGateCmdList
{
	int  nPacketID;
	bool (CRunGate:: *pfn)( sGateUserInfo *pUser, char *pBody );
} g_cmdList[] = 
{
	CM_QUERYCHR,	CRunGate::OnQueryChr,
	CM_NEWCHR,		CRunGate::OnNewChr,
	CM_DELCHR,		CRunGate::OnDelChr,
	CM_SELCHR,		CRunGate::OnSelChr,
};

BOOL IsAlphabet(CHAR cChar);
BOOL IsNumeric(CHAR cChar);
BOOL IsHangul(CHAR* pszChar);
BOOL IsChinese(CHAR* pszChar);

static const int g_nCmdCnt = sizeof( g_cmdList ) / sizeof( g_cmdList[0] );


CRunGate::CRunGate( SOCKET sdClient )
{
	SetClassId( CLASSID );
	SetAcceptedSocket( sdClient );

	m_nCntInvalidPacket	= 0;

	m_listUser.SetCompareFunction( __cbCmpUserInfo, NULL );
}


CRunGate::~CRunGate()
{
}


bool CRunGate::SendResponse( int nHandle, 
							 int nPacketID, 
							 int nRecog, int nParam, int nTag, int nSeries, 
							 char *pData )
{	
	_TDEFAULTMESSAGE defMsg;
	fnMakeDefMessage( &defMsg, nPacketID, nRecog, nParam, nTag, nSeries );

	CMir2Packet *pPacket = new CMir2Packet;
	pPacket->Attach( "%" );
	pPacket->Attach( nHandle );
	pPacket->Attach( "/#" );
	pPacket->AttachWithEncoding( (char *) &defMsg, sizeof( defMsg ) );
	if ( pData )
		pPacket->AttachWithEncoding( pData, strlen( pData ) );
	pPacket->Attach( "!$" );
	
	return Send( pPacket );
}


//
// CM_QUERYCHR [BODY] -> uid/certstr
//
bool CRunGate::OnQueryChr( sGateUserInfo *pUser, char *pBody )
{
	int nCnt = 0;
	bool sqlfail = false;

	if ( pUser->bQueryChrFinished)// || GetTickCount() - pUser->nLastCmdTime <= 200 )
	{
		m_nCntInvalidPacket++;
		return false;
	}

	bstr szID, szCert;
	_pickstring( pBody, '/', 0, &szID );
	_pickstring( pBody, '/', 1, &szCert );

	//--------------------------------------------------
	//긴 문자열 체크 (DB-Server) (sonmg 2005/06/16)
	if( strlen(szID) > 20 )
	{
		GetApp()->SetLog( CERR, "[LONG-QUERY MESSAGE!!!19] %s", szID );
		GetDBServer()->m_Log.Log( szID );
	}
	//--------------------------------------------------

/*	
	char backid[256];
	sprintf(backid,"%s",(char *)szID);
	for ( int i = 0 ; i < strlen(backid)-1 ; i++)
	{
		switch( backid[i] )
		{
		case '\'':
		case ';':{  
			GetApp()->SetLog( 0, backid);	
			return false; 
				 }
		}
	
	}
*/

	int	nCert = atoi( szCert );
	if ( !nCert )
		nCert = -2; // default value

//	char temp[1024];
//	sprintf( temp , "BODY:%s,User:%s,Cert;%d",pBody,pUser->szID,pUser->nCert);
//	GetApp()->SetLog( 0, temp );	

	if ( GetDBServer()->IsRegisteredAdmission( szID, nCert ) )
	{

		strcpy( pUser->szID, szID );
		pUser->nCert = nCert;
		pUser->bSelChrFinished = false;

		CConnection *pConn = GetOdbcPool()->Alloc();   // 캐릭터정보를 찾을수 없습니다..오류

		if ( pConn )
		{
			char szQuery[1024];
			
			sprintf( szQuery, "SELECT FLD_CHARACTER, FLD_JOB, FLD_HAIR, FLD_LEVEL, FLD_SEX FROM TBL_CHARACTER WHERE FLD_DELETED=0  AND FLD_USERID='%s' ORDER BY FLD_UPDATEDATETIME DESC", 
								(char *) szID );

			bstr	szPacket;
			char	*pszData;

			CRecordset *pRec = pConn->CreateRecordset();

			sqlfail = false;
			if ( pRec->Execute( szQuery ) )
			{
				while ( pRec->Fetch() )
				{
					pszData = pRec->Get( "FLD_CHARACTER" );
					ChangeSpaceToNull(pszData);
					szPacket += pszData;
					szPacket += "/";
					pszData = pRec->Get( "FLD_JOB" );
					ChangeSpaceToNull(pszData);
					szPacket += pszData;
					szPacket += "/";
					pszData = pRec->Get( "FLD_HAIR" );
					ChangeSpaceToNull(pszData);
					szPacket += pszData;
					szPacket += "/";
					pszData = pRec->Get( "FLD_LEVEL" );
					ChangeSpaceToNull(pszData);
					szPacket += pszData;
					szPacket += "/";
					pszData = pRec->Get( "FLD_SEX" );
					ChangeSpaceToNull(pszData);
					szPacket += pszData;
					szPacket += "/";

					nCnt++;
				}
			}
			else
			{
				sqlfail = true;
			}
			
			pConn->DestroyRecordset( pRec );
			
			if ( sqlfail )
			{
				GetOdbcPool()->ReConnect( pConn );
			}
			else
			{
				GetOdbcPool()->Free( pConn );
			}

			SendResponse( pUser->nHandle, SM_QUERYCHR, nCnt, 0, 0, 1, szPacket );

			pUser->bQueryChrFinished = true;

			return true;
		}

	}

	SendResponse( pUser->nHandle, SM_QUERYCHR_FAIL, 0, 0, 0, 1 );
	RemoveUser( pUser->nHandle );

	return true;
}

int CRunGate::is_hangul(BYTE *str)
{
	if (str[0] >= 0xb0 && str[0] <= 0xc8 && str[1] >= 0xa1 && str[1] <= 0xfe)
		return 1;
 
	return 0;
}

//
// CM_NEWCHR [BODY] -> uid/uname/hair/job/sex/
//
bool CRunGate::OnNewChr( sGateUserInfo *pUser, char *pBody )
{
//	if ( GetTickCount() - pUser->nLastCmdTime <= 200 )
//	{
//		m_nCntInvalidPacket++;
//		return false;
//	}

	if ( !GetDBServer()->IsRegisteredAdmission( pUser->szID, pUser->nCert ) )
	{
		SendResponse( pUser->nHandle, SM_OUTOFCONNECTION );
		return true;
	}

	bstr szID, szName, szHair, szJob, szSex;

	_pickstring( pBody, '/', 0, &szID );
	_pickstring( pBody, '/', 1, &szName );
	_pickstring( pBody, '/', 2, &szHair );
	_pickstring( pBody, '/', 3, &szJob );
	_pickstring( pBody, '/', 4, &szSex );


	if ( stricmp( pUser->szID, szID ) !=0 )
	{
		SendResponse( pUser->nHandle, SM_OUTOFCONNECTION );
		return true;
	}

	//--------------------------------------------------
	//긴 문자열 체크 (DB-Server) (sonmg 2005/06/16)
	if( strlen(szID) > 20 )
	{
		GetApp()->SetLog( CERR, "[LONG-QUERY MESSAGE!!!20] ID : %s", szID );
		GetDBServer()->m_Log.Log( szID );
	}
	if( strlen(szName) > 20 )
	{
		GetApp()->SetLog( CERR, "[LONG-QUERY MESSAGE!!!20] NAME : %s", szName );
		GetDBServer()->m_Log.Log( szName );
	}
	if( strlen(szHair) > 3 )
	{
		GetApp()->SetLog( CERR, "[LONG-QUERY MESSAGE!!!20] HAIR : %s", szHair );
		GetDBServer()->m_Log.Log( szHair );
	}
	if( strlen(szJob) > 3 )
	{
		GetApp()->SetLog( CERR, "[LONG-QUERY MESSAGE!!!20] JOB : %s", szJob );
		GetDBServer()->m_Log.Log( szJob );
	}
	if( strlen(szSex) > 3 )
	{
		GetApp()->SetLog( CERR, "[LONG-QUERY MESSAGE!!!20] GENDER : %s", szSex );
		GetDBServer()->m_Log.Log( szSex );
	}
	//--------------------------------------------------

	int error = -1;

	char *pszName = (char *)szName;

	_trim(pszName);

	if (strlen(pszName) < 3 || strlen(pszName) > 14)
		error = 0;

	// 2003-06-04 프로토콜 점검 - PDS
	int hair_	= -1;
	int sex_	= -1;
	int job_	= -1;
	
	if ((char *)szHair != NULL)	hair_ = atoi((char *)szHair);
	if ((char *)szSex != NULL)	sex_  = atoi((char *)szSex);
	if ((char *)szJob != NULL)	job_  = atoi((char *)szJob);
	
	if ( !( sex_ == 0 || sex_ == 1 ) ) error = 0 ;
	if ( !( job_ == 0 || job_ == 1  || job_ == 2 ) ) error = 0;
	if ( !( hair_ >= 1 && hair_ <= 5 ) ) error =0;


	GetDBServer()->m_msgFilter.Filter(pszName);

	while (*pszName)
	{
		if ((*pszName == ' ') ||
			(*pszName == '/') || (*pszName == '@') || (*pszName == '?') ||
			(*pszName == '\'') || (*pszName == '"') || (*pszName == '\\') ||
			(*pszName == '.') || (*pszName == ',') || (*pszName == ':') ||
			(*pszName == ';') || (*pszName == '`') || (*pszName == '~') ||
			(*pszName == '!') || (*pszName == '#') || (*pszName == '$') ||
			(*pszName == '%') || (*pszName == '^') || (*pszName == '&') ||
			(*pszName == '*') || (*pszName == '(') || (*pszName == ')') ||
			(*pszName == '-') || (*pszName == '_') || (*pszName == '+') ||
			(*pszName == '=') || (*pszName == '|') || (*pszName == '[') ||
			(*pszName == '{') || (*pszName == ']') || (*pszName == '}'))
			error = 5; //invalid name
/*
		
//		if (is_hanguel(pszName))
//			pszName++;
		pszName++;
*/
		if ( !IsAlphabet(*pszName) )	
		{
			if ( !IsNumeric(*pszName) )
			{
				//if ( !IsHangul(pszName) )
				//{
					if ( !IsChinese(pszName) )
					{
						error = 5; //invalid name
					}
					else
					{
						// ????? 2??? ??? ????.
						pszName++;
				}
			}
		}
		pszName++;

	}

	if (error == -1)
	{
		char		szQuery[256];
		CRecordset	*pRec;
		CConnection *pConn;

		/* TO PDS:
		// Update TBL_CHAR_INFO in Account Database
		pConn = GetAcntOdbcPool()->Alloc();

		if ( pConn )
		{
			// 케릭터 이름 변경등록이 되어있는 케릭이지 본다.
			wsprintf( szQuery, "SELECT New_Chr FROM TBL_CHANGECHR WHERE New_Chr='%s'", (char *) szName );
	
			pRec = pConn->CreateRecordset();

			if ( pRec )
			{
				if ( pRec->Execute( szQuery ) )
				{
					if ( pRec->Fetch() )
						error = 2;
				}

				pConn->DestroyRecordset( pRec );
			}

			GetAcntOdbcPool()->Free( pConn );
		}
		*/

		if ( error == -1 )
		{
			pConn = GetOdbcPool()->Alloc();

			if ( pConn )
			{
				// 케릭터가 있는지 검사해보자 
				wsprintf( szQuery, "SELECT FLD_CHARACTER FROM TBL_CHARACTER WHERE FLD_CHARACTER='%s'", (char *) szName );
		
				pRec = pConn->CreateRecordset();

				if ( pRec )
				{
					if ( pRec->Execute( szQuery ) )
					{
						if ( pRec->Fetch() )
						{
							pConn->DestroyRecordset( pRec );
							error = 2;	//같은 이름의 캐릭터가 이미 존재함.
						}
						else // 케릭터가 없으니까 새로 만든다.
						{
							pConn->DestroyRecordset( pRec );
							
							TCHARACTERFIELDS	tCharVal;
							TABILITYFIELDS		tAbilVal;
							TQUESTFIELDS		tQuestVal;
							
							ZeroMemory(&tCharVal, sizeof(tCharVal));
							ZeroMemory(&tAbilVal, sizeof(tAbilVal));
							ZeroMemory(&tQuestVal, sizeof(tQuestVal));
							
							strcpy(tCharVal.fld_userid,	szID);
							strcpy(tCharVal.fld_character, szName);
							tCharVal.fld_hair	= atoi(szHair);
							tCharVal.fld_sex	= atoi(szSex);
							tCharVal.fld_job	= atoi(szJob);
							
							pRec = pConn->CreateRecordset();

							char	szNewChrQuery[8192];


							sprintf(szNewChrQuery, "INSERT TBL_CHARACTER ( FLD_CHARACTER, FLD_USERID, FLD_DELETED,"
																			"FLD_UPDATEDATETIME, FLD_DBVERSION, FLD_MAPNAME,"
																			"FLD_CX, FLD_CY, FLD_DIR, FLD_HAIR,"
																			"FLD_HAIRCOLORR, FLD_HAIRCOLORG, FLD_HAIRCOLORB,"
																			"FLD_SEX, FLD_JOB, FLD_LEVEL, FLD_GOLD,"
																			"FLD_HOMEMAP, FLD_HOMEX, FLD_HOMEY, FLD_PKPOINT,"
																			"FLD_ALLOWPARTY, FLD_FREEGULITYCOUNT, FLD_ATTACKMODE,"
																			"FLD_FIGHTZONEDIE, FLD_BODYLUCK, FLD_INCHEALTH,"
																			"FLD_INCSPELL, FLD_INCHEALING, FLD_BONUSAPPLY,"
																			"FLD_BONUSPOINT, FLD_HUNGRYSTATE, FLD_TESTSERVERRESETCOUNT,"
																			"FLD_CGHUSETIME, FLD_ENABLEGRECALL, FLD_BYTES_1, FLD_HORSERACE, FLD_MAKEDATE) VALUES"
																			"( '%s', '%s', 0, GETDATE(), 0, '', 0, 0, 0, %d,"
																			"0, 0, 0, %d, %d, 0, 0,"
																			"'', 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,"
																			"0, 0, 0, 0, 0, 0, 0, GETDATE())",						
													tCharVal.fld_character, tCharVal.fld_userid, tCharVal.fld_hair, tCharVal.fld_sex, tCharVal.fld_job);

							if ( pRec->Execute( szNewChrQuery ) )
							{
								if (pRec->GetRowCount())
									error = 1;
							}

							pConn->DestroyRecordset( pRec );
							
							// TO PDS: REMOVE ABILITYTABLE
							/*
							strcpy(tAbilVal.fld_character, szName);
														
							pRec = pConn->CreateRecordset();
							if (UpdateRecord(pRec, &__ABILITYTABLE, (unsigned char *)&tAbilVal, true))
								error = 1;
							pConn->DestroyRecordset( pRec );

							*/
							
							strcpy(tQuestVal.fld_character, szName);
							
							pRec = pConn->CreateRecordset();
							if (UpdateRecord(pRec, &__QUESTTABLE, (unsigned char *)&tQuestVal, true))
								error = 1;
							pConn->DestroyRecordset( pRec );
						}
					}
					else
					{
						pConn->DestroyRecordset( pRec );
						error = 2;	//같은 이름의 캐릭터가 이미 존재함.
					}
				}

				GetOdbcPool()->Free( pConn ); 
			}

			/* To PDS: 필요없음
			if ( error == 1 )
			{
				// Update TBL_CHAR_INFO in Account Database
				pConn = GetAcntOdbcPool()->Alloc();

				if ( pConn )
				{
					pRec = pConn->CreateRecordset();
					
					TCHARINFO tCharInfo;

					strcpy(tCharInfo.fld_userid, szID);
					strcpy(tCharInfo.fld_character,	szName);
					strcpy(tCharInfo.fld_servername, GetCfg()->szName);

					tCharInfo.fld_job = atoi(szJob);
					tCharInfo.fld_sex = atoi(szSex);

					if (UpdateRecord(pRec, &__CHAR_INFOTABLE, (unsigned char *)&tCharInfo, true))
						error = 1;
					
					pConn->DestroyRecordset( pRec );
					
					GetAcntOdbcPool()->Free( pConn ); 
				}
			}
			*/
		}
	}

	if (error == 1)
		SendResponse( pUser->nHandle, SM_NEWCHR_SUCCESS, error, 0, 0, 0 );
	else
		SendResponse( pUser->nHandle, SM_NEWCHR_FAIL, error, 0, 0, 0 );

	pUser->bQueryChrFinished = false;

	return true;
}


//
// CM_DELCHR [BODY] -> uname
//
bool CRunGate::OnDelChr( sGateUserInfo *pUser, char *pBody )
{
//	if ( GetTickCount() - pUser->nLastCmdTime <= 200 )
//	{
//		m_nCntInvalidPacket++;
//		return false;
//	}

	if ( !GetDBServer()->IsRegisteredAdmission( pUser->szID, pUser->nCert ) )
	{
		SendResponse( pUser->nHandle, SM_OUTOFCONNECTION );
		return true;
	}
	
	char		szQuery[256];
	CRecordset	*pRec;
	CConnection *pConn = GetOdbcPool()->Alloc();

	if ( pConn )
	{							
		//--------------------------------------------------
		//긴 문자열 체크 (DB-Server) (sonmg 2005/06/16)
		if( strlen(pBody) > 20 )
		{
			GetApp()->SetLog( CERR, "[LONG-QUERY MESSAGE!!!21] %s", pBody );
			GetDBServer()->m_Log.Log( pBody );
		}
		//--------------------------------------------------

		wsprintf( szQuery, "UPDATE TBL_CHARACTER SET FLD_DELETED=1 WHERE FLD_CHARACTER='%s'", pBody );

		pRec = pConn->CreateRecordset();

		if ( pRec->Execute( szQuery ) )
		{
			if (pRec->GetRowCount())
			{
				pConn->DestroyRecordset( pRec );
				GetOdbcPool()->Free( pConn ); 

				// Update TBL_CHAR_INFO in Account Database
				/*
				pConn = GetAcntOdbcPool()->Alloc();

				if ( pConn )
				{
					pRec = pConn->CreateRecordset();
					
					wsprintf( szQuery, "UPDATE TBL_CHAR_INFO SET FLD_DELETED=1 WHERE FLD_CHARACTER='%s'", pBody );

					pRec->Execute( szQuery );

					pConn->DestroyRecordset( pRec );

					GetAcntOdbcPool()->Free( pConn ); 
				}
				*/	
				SendResponse( pUser->nHandle, SM_DELCHR_SUCCESS, 1, 0, 0, 0 );
				pUser->bQueryChrFinished = false;

				return true;
			}
		}

		pConn->DestroyRecordset( pRec );
		GetOdbcPool()->Free( pConn );
	}

	SendResponse( pUser->nHandle, SM_DELCHR_FAIL, 0, 0, 0, 0 );

	pUser->bQueryChrFinished = false;

	return true;
}


//
// CM_SELCHR [BODY] -> uid/uname
//
bool CRunGate::OnSelChr( sGateUserInfo *pUser, char *pBody )
{
	if ( pUser->bSelChrFinished )
	{
		m_nCntInvalidPacket++;
		return false;
	}

	if ( !GetDBServer()->IsRegisteredAdmission( pUser->szID, pUser->nCert ) )
	{
		SendResponse( pUser->nHandle, SM_OUTOFCONNECTION );
		return true;
	}

	bstr szID, szName;
	_pickstring( pBody, '/', 0, &szID );
	_pickstring( pBody, '/', 1, &szName );	

	if ( stricmp( pUser->szID, szID ) !=0 )
	{
		SendResponse( pUser->nHandle, SM_OUTOFCONNECTION );
		return true;
	}

	//--------------------------------------------------
	//긴 문자열 체크 (DB-Server) (sonmg 2005/06/16)
	if( strlen(szID) > 20 )
	{
		GetApp()->SetLog( CERR, "[LONG-QUERY MESSAGE!!!22] ID : %s", szID );
		GetDBServer()->m_Log.Log( szID );
	}
	//--------------------------------------------------

/*
	char backid[256];
	sprintf(backid,"%s",(char *)szID);
	for ( int i = 0 ; i < strlen(backid)-1 ; i++)
	{
		switch( backid[i] )
		{
		case '\'':
		case ';':{  
			GetApp()->SetLog( 0, backid);	
			return false; 
				 }
		}
	
	}

	sprintf(backid,"%s",(char *)szName);
	for ( i = 0 ; i < strlen(backid)-1 ; i++)
	{
		switch( backid[i] )
		{
		case '\'':
//		case '-':
		case ';':{  
			GetApp()->SetLog( 0, backid);	
			return false; 
				 }
		}
	
	}
*/

	bool	fOK = false;
	bstr	szPacket;

	CConnection *pConn = GetOdbcPool()->Alloc();

	if ( pConn )
	{
		char	szQuery[256];

		wsprintf( szQuery, "SELECT FLD_MAPNAME FROM TBL_CHARACTER WHERE FLD_CHARACTER='%s' and FLD_USERID='%s'", (char *) szName , (char *)szID );

		CRecordset *pRec = pConn->CreateRecordset();

		if ( pRec->Execute( szQuery ) )
		{
			if ( pRec->Fetch() )
			{
				char *pszData = pRec->Get( "FLD_MAPNAME" );
				
				if (pszData)
				{
					ChangeSpaceToNull(pszData);
					szPacket += pszData;

					fOK = true;
				}
			}
		}
		
		pConn->DestroyRecordset( pRec );

		GetOdbcPool()->Free (pConn );
	}


	if (fOK)
	{
		char	szData[128];
		int		nServerIndex = GetDBServer()->GetServerFromMap((char *)szPacket);
		
		GetDBServer()->CheckSelectedAdmission( pUser->nCert ); // (*) for save selected character.

		sprintf(szData, "%s/%d", GetDBServer()->GetRunServerAddr(IP()), GetDBServer()->GetRunServerPort(IP()) + nServerIndex);

		//testcode
#ifdef _DEBUG
		GetApp()->SetLog(0, szData );
#endif
		SendResponse( pUser->nHandle, SM_STARTPLAY, 0, 0, 0, 0, szData );
	}
	else
		SendResponse( pUser->nHandle, SM_STARTFAIL, 0, 0, 0, 0 );

	pUser->bSelChrFinished = true;

	return true;
}


/*
	KeepAlive

	Syntax> %--$
*/
bool CRunGate::OnCheckCode( char *pBody )
{
	//
	// KeepAlive 패킷을 리턴한다.
	//
	CMir2Packet *pPacket = new CMir2Packet;
	if ( !pPacket )
		return false;

	if ( !pPacket->Attach( "%++$" ) )
	{
		delete pPacket;
		return false;
	}

	return Send( pPacket );
}


/*
	User Connection

	Syntax> %O[handle]/[addr]$
*/
bool CRunGate::OnUserOpen( char *pBody )
{
	bstr szHandle, szAddr;
	_pickstring( pBody, '/', 0, &szHandle );
	_pickstring( pBody, '/', 1, &szAddr );

	return InsertUser( atoi( szHandle ), szAddr );
}


/*
	User Disconnection

	Syntax> %X[handle]$
*/
bool CRunGate::OnUserClose( char *pBody )
{
	return RemoveUser( atoi( pBody ) );
}


/*
	Data Packet

	Syntax> %A[handle]/#?[DEFBLOCK][BODY]!$
*/
bool CRunGate::OnUserData( char *pBody )
{

	char *pData = strchr( pBody, '/' );
	if ( !pData )
	{
		m_nCntInvalidPacket++;
		return false;
	}
	*pData = NULL;


	int	nHandle = atoi( pBody );
	sGateUserInfo *pUser = m_listUser.Search( (sGateUserInfo *) &nHandle );
	if ( !pUser )
	{
		m_nCntInvalidPacket++;
		return false;
	}
	pData++;


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



	_TDEFAULTMESSAGE msg;
	fnDecodeMessage( &msg, pData );

	pData += _DEFBLOCKSIZE;

	CDecodedString *pdData = fnDecodeString( pData );

	//-----------------------------------------------------------
	//20040715 입력창을 통한 쿼리 실행 제거 -> 2005/06/10 특수문자 체크 추가
	//긴 문자열 체크 (DB-Server)
	if( strlen(pdData->m_pData) > 20+16+7 )
	{
		GetApp()->SetLog( CERR, "[LONG-QUERY MESSAGE!!!23] %s", pdData->m_pData );
		GetDBServer()->m_Log.Log( pdData->m_pData );
	}

	//특수 문자가 들어가 있으면 에러 리턴
	char *pDataNull = strchr( pdData->m_pData, ' ' );
	if ( pDataNull != NULL )
	{
		GetApp()->SetLog( CERR, "[QUERY WARNING!!!] %s", pdData->m_pData );
		GetDBServer()->m_Log.Log( pdData->m_pData );
		return false;
	}
	pDataNull = strchr( pdData->m_pData, '-' );
	if ( pDataNull != NULL )
	{
		GetApp()->SetLog( CERR, "[QUERY WARNING!!!] %s", pdData->m_pData );
		GetDBServer()->m_Log.Log( pdData->m_pData );
		return false;
	}
	pDataNull = strchr( pdData->m_pData, '\'' );
	if ( pDataNull != NULL )
	{
		GetApp()->SetLog( CERR, "[QUERY WARNING!!!] %s", pdData->m_pData );
		GetDBServer()->m_Log.Log( pdData->m_pData );
		return false;
	}
	//-----------------------------------------------------------

	//
	// 해당 프로토콜 함수를 호출한다.
	//
	pUser->nLastCmdTime = GetTickCount();

	for ( int i = 0; i < g_nCmdCnt; i++ )
	{
		if ( msg.wIdent == g_cmdList[i].nPacketID )
		{
			try 
			{
			(this->*g_cmdList[i].pfn)( pUser, *pdData );
			delete pdData;
			}
			catch ( char *str )
			{
			  GetApp()->SetLog(0,"EXCEPT RUNGATE" );
			}

			return true;
		}
	}

	delete pdData;

	m_nCntInvalidPacket++;
	return false;
}


void CRunGate::OnError( int nErrCode )
{
	GetApp()->SetErr( nErrCode );
}


void CRunGate::OnSend( int nTransferred )
{
//#ifdef _DEBUG
//	GetApp()->SetLog( CSEND, "[CM/%d]", nTransferred );
//#endif
}


bool CRunGate::OnRecv( char *pPacket, int nPacketLen )
{
 try 
 {
	char __szPacket[256] = {0,};
	memcpy( __szPacket, pPacket, 
		nPacketLen >= sizeof( __szPacket ) ? sizeof( __szPacket ) - 1 : nPacketLen );
#ifdef _DEBUG
	GetApp()->SetLog( CRECV, "[CM/%d] %s", nPacketLen, __szPacket );
#endif

	//-----------------------------
	// Monitoring
	if( nPacketLen > 7 )
	{
		char szEnTemp[256] = {0,};
		char szEnTemp2[400] = {0,};
		memcpy( szEnTemp, __szPacket, nPacketLen >= sizeof( szEnTemp ) ? sizeof( szEnTemp ) - 1 : nPacketLen );
		sprintf( szEnTemp2, "[CMEnLOG/%d] %s\r\n", nPacketLen, szEnTemp );
//		GetApp()->SetLog( CRECV, "[CMEnLOG/%d] %s", nPacketLen, szEnTemp );
		GetDBServer()->m_Log.Log( szEnTemp2 );

		char *pData = strchr( __szPacket, '/' );
		if ( pData )
		{
			*pData = NULL;
			pData++;
		
			// Relay 패킷 유효성 검사
			int nDataLen = strlen( pData );
			pData[nDataLen - 1] = NULL;
			nDataLen--;

			char szTemp[256] = {0,};
			char szTemp2[400] = {0,};
			if ( pData[0] == '#' && pData[nDataLen - 1] == '!' )
			{
				pData[nDataLen - 1] = NULL;
				pData += 2;

				_TDEFAULTMESSAGE msg;
				fnDecodeMessage( &msg, pData );

				pData += _DEFBLOCKSIZE;

				CDecodedString *pdData = fnDecodeString( pData );


				memcpy( szTemp, pdData->m_pData, nPacketLen >= sizeof( pdData->m_pData ) ? sizeof( pdData->m_pData ) - 1 : nPacketLen );
				sprintf( szTemp2, "[CMLOG] %s\r\n", pdData->m_pData );
//				GetApp()->SetLog( CRECV, "[CMLOG] %s", pdData->m_pData );
				GetDBServer()->m_Log.Log( szTemp2 );
			}
			else
			{
				memcpy( szTemp, pData, nPacketLen >= sizeof( pData ) ? sizeof( pData ) - 1 : nPacketLen );
				sprintf( szTemp2, "[CMLOGElse] %s\r\n", pData );
//				GetApp()->SetLog( CRECV, "[CMLOGElse] %s", pData );
				GetDBServer()->m_Log.Log( szTemp2 );
			}
		}
	}
	//-----------------------------
 }
 catch ( char *str )
 {
  GetApp()->SetLog(0,"EXCEPT RUNGATE OnRecv" );
 }

	//
	// 패킷 유효성 검사
	//
	if ( pPacket[0] != '%' || pPacket[nPacketLen - 1] != '$' )
	{
		m_nCntInvalidPacket++;
		return true;
	}
	
	CCriticalSection cs;
	cs.Lock();
	
	pPacket[nPacketLen - 1] = NULL;
	
	//
	// 해당 함수 호출
	//
	char *pBody = pPacket + 1;

	switch ( *(pBody++) )
	{
	case '-': OnCheckCode( pBody );	break;
	case 'O': OnUserOpen( pBody );	break;
	case 'X': OnUserClose( pBody );	break;
	case 'A': OnUserData( pBody );	break;
	default:	
		m_nCntInvalidPacket++;
		break;
	}

	cs.Unlock();

	return true;
}


bool CRunGate::OnExtractPacket( char *pPacket, int *pPacketLen )
{
	char *pEnd = (char *) memchr( m_olRecv.szBuf, '$', m_olRecv.nBufLen );
	if ( !pEnd )
		return false;

	*pPacketLen = ++pEnd - m_olRecv.szBuf;
	memcpy( pPacket, m_olRecv.szBuf, *pPacketLen );	

	return true;
}


bool CRunGate::IsValidData( char *pData, int nDataLen )
{
	if ( (nDataLen < _DEFBLOCKSIZE) || (nDataLen > _DEFBLOCKSIZE + 50) )
		return false;

	return true;
}


bool CRunGate::InsertUser( int nHandle, char *pAddr )
{
	//
	// 이미 존재하는 사용자라면 내부 데이터를 업데이트한다.
	//
	sGateUserInfo *pUser = m_listUser.Search( (sGateUserInfo *) &nHandle );
	if ( pUser )
	{
		memset( pUser, 0, sizeof( sGateUserInfo ) );
		strcpy( pUser->szAddr, pAddr );
		pUser->nHandle		= nHandle;
		pUser->nConnectTime	= GetTickCount();
		pUser->nLastCmdTime	= GetTickCount();
		return true;
	}

	pUser = new sGateUserInfo;
	memset( pUser, 0, sizeof( sGateUserInfo ) );
	strcpy( pUser->szAddr, pAddr );
	pUser->nHandle		= nHandle;
	pUser->nConnectTime	= GetTickCount();
	pUser->nLastCmdTime	= GetTickCount();

	return m_listUser.Insert( pUser );
}


bool CRunGate::RemoveUser( int nHandle )
{
	sGateUserInfo *pUser = m_listUser.Remove( (sGateUserInfo *) &nHandle );
	if ( !pUser )
		return false;

	if ( !GetDBServer()->IsSelectedAdmission( pUser->nCert ) ) // not selected anyone character when user has been disconnected.
		GetDBServer()->m_loginServer.SendUserClosed( pUser );

	delete pUser;
	return true;
}


int CRunGate::__cbCmpUserInfo( void *pArg, sGateUserInfo *pFirst, sGateUserInfo *pSecond )
{
	return pFirst->nHandle - pSecond->nHandle;
}

BOOL IsAlphabet(CHAR cChar)
{
	if ( ( (cChar >= 'a') && (cChar <= 'z') ) || ( (cChar >= 'A') && (cChar <= 'Z') ) )
	{
		return TRUE;
	}

	return FALSE;
}

BOOL IsNumeric(CHAR cChar)
{
	INT nNum = cChar-'0';

	if ( nNum >= 0 && nNum <= 9 )
	{
		return TRUE;
	}

	return FALSE;
}

BOOL IsHangul(CHAR* pszChar)
{
	CHAR	cChar;
	CHAR	cNextChar;
	WORD	wchDBCS;

	cChar	  = *pszChar;
	cNextChar = *(pszChar+1);

	if ( cChar & 0x800 )
	{
		if ( (wchDBCS = (cChar << 8) + cNextChar) > 0xCAA0 )
		{
			// 한자.
			return FALSE;
		}
		else
		{
			if ( (wchDBCS >= 0xafa1) && (wchDBCS < 0xc8f0) )
			{
				return TRUE;	// Hangul	단 KS완성형에 한함.
			}
			else
			{
				return FALSE;
			}
		}
	}

	return FALSE;
}

BOOL IsChinese(CHAR* pszChar)
{
	CHAR	cChar;
	CHAR	cNextChar;

	cChar	  = *pszChar;
	cNextChar = *(pszChar+1);

	if ( cChar & 0x80 )
	{
		if ( cNextChar & 0x80 ) 
		{
			return TRUE;
		}
		else
		{
			return FALSE;
		}
	}
	return FALSE;
}
