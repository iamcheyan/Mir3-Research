

#include "netloginserver.h"
#include "../common/sqlhandler.h"
#include "tablesdefine.h"
#include "dbsvrwnd.h"
#include "../common/mir2packet.h"
#include <stringex.h>
#include <stdlib.h>


static struct sLoginServerCmdList
{
	int  nPacketID;
	bool (CLoginServer:: *pfn)( char *pBody );
} g_cmdList[] = 
{
	ISM_PASSWDSUCCESS,		CLoginServer::OnPasswdSuccess,
	ISM_CANCELADMISSION,	CLoginServer::OnCancelAdmission,
	ISM_TOTALUSERCOUNT,		CLoginServer::OnTotalUserCount,
	ISM_SEND_PUBLICKEY,		CLoginServer::OnRecvPublicKey,
};


static const int g_nCmdCnt = sizeof( g_cmdList ) / sizeof( g_cmdList[0] );



CLoginServer::CLoginServer()
{
	SetClassId( CLASSID );

	m_nCntInvalidPacket = 0;
}


CLoginServer::~CLoginServer()
{
}


bool CLoginServer::SendUserCount()
{
		
	CMir2Packet *pPacket = new CMir2Packet;
	pPacket->Attach( "(" );
	pPacket->Attach( ISM_USERCOUNT );
	pPacket->Attach( "/" );
	pPacket->Attach( GetCfg()->szName );
//	pPacket->Attach( "/99/0)" );
	pPacket->Attach( "/99/" );
	pPacket->Attach( GetDBServer()->GetFreeDiskSpace( "D:" ) );
	pPacket->Attach( ")" );

	Lock();
	bool bRet = Send( pPacket );
	Unlock();

	return bRet;
}

bool CLoginServer::SendUserClosed( sGateUserInfo *pUser )
{
	CMir2Packet *pPacket = new CMir2Packet;
	pPacket->Attach( "(" );
	pPacket->Attach( ISM_USERCLOSED );
	pPacket->Attach( "/" );
	pPacket->Attach( pUser->szID );
	pPacket->Attach( "/" );
	pPacket->Attach( pUser->nCert );
	pPacket->Attach( ")" );	

	Lock();
	bool bRet = Send( pPacket );
	Unlock();

	return bRet;
}

bool CLoginServer::SendRequestPublicKey()
{
	CMir2Packet *pPacket = new CMir2Packet;
	pPacket->Attach( "(" );
	pPacket->Attach( ISM_REQUEST_PUBLICKEY );
	pPacket->Attach( ")" );	

	Lock();
	bool bRet = Send( pPacket );
	Unlock();

	return bRet;
}


bool CLoginServer::OnPasswdSuccess( char *pBody )
{
	bstr szID, szCert, szPay;
	// '/' -> '0x0a'

	_pickstring( pBody, 0x0a, 0, &szID );
	_pickstring( pBody, 0x0a, 1, &szCert );
	_pickstring( pBody, 0x0a, 2, &szPay );

	return GetDBServer()->InsertAdmission( szID, atoi( szCert ), atoi( szPay ) );
}


bool CLoginServer::OnCancelAdmission( char *pBody )
{
	bstr szID, szCert;
	_pickstring( pBody, '/', 0, &szID );
	_pickstring( pBody, '/', 1, &szCert );

	return GetDBServer()->RemoveAdmission( szID, atoi( szCert ) );
}


bool CLoginServer::OnTotalUserCount( char *pBody )
{
	//
	// 하는 일 없음
	//
	return true;
}

bool CLoginServer::OnRecvPublicKey( char *pBody )
{
	bstr szPubKey;
	_pickstring( pBody, '/', 0, &szPubKey );

	SetPublicKey( WORD(atoi( szPubKey )) );

	return true;
}


void CLoginServer::OnError( int nErrCode )
{
	GetApp()->SetErr( nErrCode );
}


void CLoginServer::OnSend( int nTransferred )
{
#ifdef _DEBUG
	GetApp()->SetLog( CSEND, "[ISM/%d]", nTransferred );
#endif
}


bool CLoginServer::OnRecv( char *pPacket, int nPacketLen )
{
#ifdef _DEBUG
	char __szPacket[256] = {0,};
	memcpy( __szPacket, pPacket, 
		nPacketLen >= sizeof( __szPacket ) ? sizeof( __szPacket ) - 1 : nPacketLen );
	GetApp()->SetLog( CRECV, "[ISM/%d] %s", nPacketLen, __szPacket );
#endif
	
	if ( NULL == pPacket ) return false;
	//
	// 패킷 유효성 검사
	//
	if ( pPacket[0] != '(' || pPacket[nPacketLen - 1] != ')' )
	{
		m_nCntInvalidPacket++;
		return true;
	}

	
	CCriticalSection cs;
	cs.Lock();
	
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
			try
			{
			(this->*g_cmdList[i].pfn)( pBody );
			}
			catch( char *str )
			{
			GetApp()->SetLog(0,"EXCEPT RUN %d %s",atoi( szPacketID ) , pBody );	
			}
			cs.Unlock();
			return true;
		}
	}
	cs.Unlock();
	m_nCntInvalidPacket++;
	return true;
}


bool CLoginServer::OnExtractPacket( char *pPacket, int *pPacketLen )
{
	char *pEnd = (char *) memchr( m_olRecv.szBuf, ')', m_olRecv.nBufLen );
	if ( !pEnd )
		return false;

	*pPacketLen = ++pEnd - m_olRecv.szBuf;
	memcpy( pPacket, m_olRecv.szBuf, *pPacketLen );

	return true;
}
