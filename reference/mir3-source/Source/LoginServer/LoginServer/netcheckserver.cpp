

#include "netcheckserver.h"
#include "loginsvrwnd.h"
#include "../common/mir2packet.h"


CCheckServer::CCheckServer( SOCKET sdClient )
{
	SetClassId( CLASSID );
	SetAcceptedSocket( sdClient );
}


CCheckServer::~CCheckServer()
{
}


bool CCheckServer::SendServerStatus()
{
	CMir2Packet *pPacket = new CMir2Packet;
	

	pPacket->Attach( GetLoginServer()->m_listGameServer.GetCount() );
	pPacket->Attach( ";" );

	CListNode< CGameServer > *pNode;

	GetLoginServer()->m_listGameServer.Lock();
	pNode = GetLoginServer()->m_listGameServer.GetHead();
	for ( ; pNode; pNode = pNode->GetNext() )
	{
		CGameServer *pObj = pNode->GetData();
		
		if(pObj)
		{
			
			if ( strlen( pObj->m_dbInfo.szName ) > 0 )
			{
				pPacket->Attach( pObj->m_dbInfo.szName );
				pPacket->Attach( "/" );
				pPacket->Attach( pObj->m_dbInfo.nID);
				pPacket->Attach( "/" );
				pPacket->Attach( pObj->m_nCurUserCnt );
				pPacket->Attach( "/" );
				
				if ( GetTickCount() - pObj->m_nLastTick < 30000 )
				{
					if( GetLoginServer()->m_bSendErrorToCheckServer == false )
						pPacket->Attach( "정상;" );
					else
						pPacket->Attach( "응답없음;" );
				}
				else
					pPacket->Attach( "응답없음;" );
			}
			else
			{
				pPacket->Attach( "-/-/-/-;" );
			}
		}
	}
	GetLoginServer()->m_listGameServer.Unlock();

	Lock();
	bool bRet = Send( pPacket );
	Unlock();

	return bRet;
}


void CCheckServer::OnError( int nErrCode )
{
	GetApp()->SetErr( nErrCode );
}


void CCheckServer::OnSend( int nTransferred )
{
#ifdef _DEBUG
	GetApp()->SetLog( CSEND, "[CheckServer/%d]", nTransferred );
#endif
}


bool CCheckServer::OnRecv( char *pPacket, int nPacketLen )
{
	return false;
}


bool CCheckServer::OnExtractPacket( char *pPacket, int *pPacketLen )
{
	return false;
}
