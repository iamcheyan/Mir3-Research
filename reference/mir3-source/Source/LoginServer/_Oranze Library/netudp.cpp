

#include "netudp.h"
#include "process.h"


CUdpPacketHeader::CUdpPacketHeader()
{
	m_nIndex	= 0;
	m_nCount	= 0;
}


CUdpPacketHeader::~CUdpPacketHeader()
{
}




CUdpPacket::CUdpPacket()
{
	m_buf[0]            = NULL;

	m_nBufLen			= 0;
	m_nTime				= 0;
	m_nTimeWaitingAck	= 0;
}


CUdpPacket::~CUdpPacket()
{
}




CUdpHost::CUdpHost()
{
	m_nState			= 0;

	m_pHostData			= NULL;

	m_nLastSendIndex	= UDP_PACKET_START;
	m_nNextPollIndex	= UDP_PACKET_START;
	m_nLastRecvTime		= 0;
}


CUdpHost::~CUdpHost()
{
	m_qSend.ClearAll();
	m_qWaitingAck.ClearAll();
	m_qRecv.ClearAll();
}


/*
	InsertToSendQ()
*/
bool CUdpHost::InsertToSendQ( ulong nType, uint nIndex, char *pBuf, uint nBufLen )
{
	if ( nBufLen > UDP_MAXBUF )
		return false;

	CUdpPacket *pPacket = new CUdpPacket;
	if ( !pPacket )
		return false;

	pPacket->m_nIndex	= nIndex;
	pPacket->m_nCount	= nType;

	if ( nType != UDP_PACKET_ACK )
	{
		pPacket->m_nBufLen	= nBufLen;
		memcpy( pPacket->m_buf, pBuf, nBufLen );
	}

	return m_qSend.Enqueue( pPacket );
}


/*
	InsertToRecvQ()

	Note 1: 인덱스 순으로 정렬한다.
	Note 2: 이미 처리한 패킷은 무시한다. (재전송에 의해 발생될 수 있음)
*/
bool CUdpHost::InsertToRecvQ( ulong nIndex, char *pBuf, uint nBufLen )
{
	if ( nBufLen > UDP_MAXBUF )
		return false;

	CUdpPacket *pPacket = new CUdpPacket;
	if ( !pPacket )
		return false;

	// 이미 처리한 패킷은 무시한다.
	if ( nIndex < m_nNextPollIndex )
	{
		_outputerr( "CUdpHost::InsertToRecvQ 이미 처리한 패킷입니다.\n" );
		return true;
	}

	pPacket->m_nIndex	= nIndex;
	pPacket->m_nBufLen	= nBufLen;
	memcpy( pPacket->m_buf, pBuf, nBufLen );

	CListNode< CUdpPacket >	*pNode;
	CUdpPacket				*pNodePacket;

	for ( pNode = m_qRecv.GetHead(); pNode; pNode = pNode->GetNext() )
	{
		pNodePacket = pNode->GetData();

		// 이미 도착한 패킷은 무시한다.
		if ( pNodePacket->m_nIndex == pPacket->m_nIndex )
		{
			_outputerr( "CUdpHost::InsertToRecvQ 큐에 같은 패킷이 들어있습니다.\n" );
			return true;
		}

		if ( pNodePacket->m_nIndex > pPacket->m_nIndex )
		{
			_outputerr( "CUdpHost::InsertToRecvQ 패킷을 인덱스로 정렬한 후 삽입합니다.\n" );
			if ( pNode == m_qRecv.GetHead() )
				return m_qRecv.InsertHead( pPacket );
			else
				return m_qRecv.InsertAt( pNode->GetPrev(), pPacket );
		}
	}

	return m_qRecv.Insert( pPacket );
}


bool CUdpHost::RemoveFromSendQ( ulong nIndex )
{
	CListNode< CUdpPacket >	*pNode;
	CUdpPacket				*pPacket;

	for ( pNode = m_qSend.GetHead(); pNode; pNode = pNode->GetNext() )
	{
		pPacket = pNode->GetData();

		if ( pPacket->m_nIndex == nIndex )
		{
			delete m_qSend.RemoveNode( pNode );
			return true;
		}
	}

	return false;
}


/*
	RemoveFromWaitingAckQ()
*/
bool CUdpHost::RemoveFromWaitingAckQ( ulong nIndex )
{
	CListNode< CUdpPacket >	*pNode;
	CUdpPacket				*pPacket;

	for ( pNode = m_qWaitingAck.GetHead(); pNode; pNode = pNode->GetNext() )
	{
		pPacket = pNode->GetData();

		if ( pPacket->m_nIndex == nIndex )
		{
			delete m_qWaitingAck.RemoveNode( pNode );
			return true;
		}
	}

	return false;
}




CUdpHandler::CUdpHandler()
{
	m_nInstanceState		= UDP_UNINIT;
	m_hNetIoThread			= NULL;

	m_sdHost				= INVALID_SOCKET;

	m_nMaxSyncLatency		= 0;
	m_nMaxRTO				= 0;
	m_nMaxWaitingAckQSize	= 0;

	m_listHost.SetCompareFunction( __cbCompareHost, NULL );

#ifdef __UDP_DEBUG__
	srand( GetTickCount() );

	m_nPacketLoseProbability	= 0;
#endif
}


CUdpHandler::~CUdpHandler()
{
	Uninit();
}


/*
	Init( pAddr, nMaxSyncLatency, nMaxRTO )
	
	pAddr			: 바인드 어드레스
	nMaxSyncLatency	: 호스트간 동기화 시간
					  주> 액션 게임의 경우 짧은 시간으로 설정한다.
	nMaxRTO			: Retransmission TimeOut
					  주> nMaxSyncLatency보다 작은 값으로 설정하는 것이 좋다.

*/
bool CUdpHandler::Init( CSockAddr *pAddr, 
						uint nMaxSyncLatency, 
						uint nMaxRTO,
						uint nMaxWaitingAckQSize )
{
	m_sdHost = socket( AF_INET, SOCK_DGRAM, 0 );
	if ( m_sdHost == INVALID_SOCKET )
		throw CError( "CUdpHandler::Init socket 생성 실패" );

	if ( bind( m_sdHost, pAddr, sizeof( SOCKADDR ) ) == SOCKET_ERROR )
		throw CError( "CUdpHandler::Init socket 바인드 실패" );

	ulong nNonblock = 1;
	if ( ioctlsocket( m_sdHost, FIONBIO, &nNonblock ) == SOCKET_ERROR )
		throw CError( "CUdpHandler::Init socket 넌블럭 모드 실패" );

	m_nMaxSyncLatency		= nMaxSyncLatency;
	m_nMaxRTO				= nMaxRTO;
	m_nMaxWaitingAckQSize	= nMaxWaitingAckQSize;

	m_nInstanceState		= UDP_INIT;

	uint nThreadId;
	m_hNetIoThread = (HANDLE) _beginthreadex( NULL, 0, NetIoThread, this, 0, &nThreadId );
	if ( m_hNetIoThread == NULL )
		throw CError( "CUdpHandler::Init UDP 스레드 생성 실패" );

	return true;
}
	

void CUdpHandler::Uninit()
{
	Lock();
	
	if ( m_sdHost != INVALID_SOCKET )
	{
		shutdown( m_sdHost, SD_BOTH );
		closesocket( m_sdHost );
		m_sdHost = INVALID_SOCKET;
	}
	
	if ( m_hNetIoThread )
	{
		m_nInstanceState = UDP_WAITING_THREAD;
		
		WaitForSingleObject( m_hNetIoThread, INFINITE );
		CloseHandle( m_hNetIoThread );
		m_hNetIoThread = NULL;
	}
	
	m_nInstanceState = UDP_UNINIT;

	m_listHost.ClearAll();

	Unlock();
}


bool CUdpHandler::Poll( CUdpHost **ppHost, ushort *pState, char *pBuf, uint *pBufLen )
{
	CListNode< CUdpHost >	*pHostNode;
	CUdpHost				*pHost;
	CListNode< CUdpPacket >	*pPacketNode;
	CUdpPacket				*pPacket;

	Lock();

	for ( pHostNode = m_listHost.GetHead(); pHostNode; pHostNode = pHostNode->GetNext() )
	{
		pHost = pHostNode->GetData();
		
		if ( pHost->m_nState )
		{
			_outputerr( "CUdpHandler::Poll [%s:%d] 호스트 에러 코드 (%d)\n", pHost->IP(), pHost->Port(), pHost->m_nState );

			*ppHost = pHost;
			*pState = pHost->m_nState;

			Unlock();
			return true;
		}

		// 수신된 데이터 처리
		for ( pPacketNode = pHost->m_qRecv.GetHead(); pPacketNode; pPacketNode = pPacketNode->GetNext() )
		{
			pPacket = pPacketNode->GetData();

			*ppHost = pHost;

			// 버퍼 크기가 모자라면
			if ( *pBufLen < pPacket->m_nBufLen )
			{
				*pState	= UDP_ERR_NOT_ENOUGH_BUFFER;

				Unlock();
				return true;
			}
			
			// 받을 데이터가 있으면
			if ( pHost->m_nNextPollIndex == pPacket->m_nIndex )
			{
				++pHost->m_nNextPollIndex;

				*pState		= UDP_RECV;
				*pBufLen	= pPacket->m_nBufLen;
				memcpy( pBuf, pPacket->m_buf, *pBufLen );

				delete pHost->m_qRecv.RemoveNode( pPacketNode );
				
				Unlock();
				return true;
			}
		}
	}

	Unlock();
	return false;
}


void CUdpHandler::Send( CUdpHost *pHost, char *pBuf, uint nBufLen )
{
	Lock();

	if ( pHost )
	{
		pHost->InsertToSendQ( UDP_PACKET_DATA, pHost->m_nLastSendIndex++, pBuf, nBufLen );
	}
	else
	{
		CListNode< CUdpHost > *pNode;

		for ( pNode = m_listHost.GetHead(); pNode; pNode = pNode->GetNext() )
		{
			pHost = pNode->GetData();

			pHost->InsertToSendQ( UDP_PACKET_DATA, pHost->m_nLastSendIndex++, pBuf, nBufLen );
		}
	}
	
	Unlock();
}


CUdpHost * CUdpHandler::InsertHost( CSockAddr *pAddr, void *pHostData )
{
	_outputerr( "CUdpHandler::InsertHost 호스트를 추가합니다.\n" );

	CUdpHost *pHost = new CUdpHost;
	if ( !pHost )
		return false;

	memcpy( pHost, pAddr, sizeof( CSockAddr ) );
	pHost->m_pHostData		= pHostData;
	pHost->m_nLastRecvTime	= GetTickCount();

	Lock();
	m_listHost.Insert( pHost );
	Unlock();

	return pHost;
}


bool CUdpHandler::DeleteHost( CSockAddr *pAddr )
{
	_outputerr( "CUdpHandler::DeleteHost 호스트를 삭제합니다.\n" );

	char *ip = pAddr->IP();
	int port = pAddr->Port();

	Lock();
	CUdpHost *pHost = m_listHost.Remove( (CUdpHost *) pAddr );
	Unlock();

	ip   = pHost->IP();
	port = pHost->Port();

	if ( !pHost )
		return false;

	delete pHost;

	return true;
}


CUdpHost * CUdpHandler::GetHost( CSockAddr *pAddr )
{
	Lock();
	CUdpHost *pHost = m_listHost.Search( (CUdpHost *) pAddr );
	Unlock();

	return pHost;
}


void CUdpHandler::SetHostData( CUdpHost *pHost, void *pHostData )
{
	Lock();
	pHost->m_pHostData = pHostData;
	Unlock();
}


void CUdpHandler::ProcessInput()
{
	// recvfrom() 인자
	CSockAddr	addr;
	int			nAddrLen;
	CUdpPacket	packet;
	int			nRecvLen;
	
	CListNode< CUdpHost >	*pHostNode;
	CUdpHost				*pHost = NULL; // 추가되지 않은 호스트일 수 있다.

    while ( true )
    {
        nAddrLen = sizeof( addr );
        nRecvLen = recvfrom( m_sdHost, (char *) &packet, packet.Size(), 0, &addr, &nAddrLen );
        if ( nRecvLen < (signed) sizeof( CUdpPacketHeader ) )
        {
			// ICMP: Port Unreachable
            if ( WSAGetLastError() == WSAECONNRESET )
            {
                pHost = GetHost( &addr );
                if ( pHost )
                    pHost->m_nState = UDP_ERR_SEND;
            }
            
            break;
        }

		// 등록되지 않은 호스트라면
		pHost = GetHost( &addr );
		if ( pHost == NULL )
			pHost = InsertHost( &addr, NULL );
		
		// 동기화를 위해 받은 시간을 저장한다.
		pHost->m_nLastRecvTime = GetTickCount();
		
		if ( packet.m_nCount == UDP_PACKET_ACK )
		{
			_outputerr( "CUdpHandler::ProcessInput:RECV_ACK Index(%d)\n", packet.m_nIndex );
			
			pHost->RemoveFromSendQ( packet.m_nIndex );
			pHost->RemoveFromWaitingAckQ( packet.m_nIndex );
		}
		else if ( packet.m_nCount >= UDP_PACKET_DATA )
		{
			_outputerr( "CUdpHandler::ProcessInput:RECV_DATA Index(%d) Count(%d)\n", packet.m_nIndex, packet.m_nCount );
			
			pHost->InsertToRecvQ( packet.m_nIndex, packet.m_buf, nRecvLen - sizeof( CUdpPacketHeader ) );
			pHost->InsertToSendQ( UDP_PACKET_ACK, packet.m_nIndex, NULL, 0 );		
		}
        
        for ( pHostNode = m_listHost.GetHead(); pHostNode; pHostNode = pHostNode->GetNext() )
        {
            pHost = pHostNode->GetData();
               
            // 동기화 시간동안 아무 입력도 없었다면
            if ( GetTickCount() - pHost->m_nLastRecvTime > m_nMaxSyncLatency )
                pHost->m_nState = UDP_ERR_RECV_SYNC;
        }
    }
}


void CUdpHandler::ProcessOutput()
{
	CListNode< CUdpHost >	*pHostNode;
	CUdpHost				*pHost;
	CListNode< CUdpPacket >	*pPacketNode, *pPacketTemp;
	CUdpPacket				*pPacket;
	uint					nSendLen;

	for ( pHostNode = m_listHost.GetHead(); pHostNode; pHostNode = pHostNode->GetNext() )
	{
		pHost = pHostNode->GetData();

		// RTO(Retransmission TimeOut)을 넘어선 패킷을 재전송시킨다.
		for ( pPacketNode = pHost->m_qWaitingAck.GetHead(); pPacketNode; )
		{
			pPacket = pPacketNode->GetData();

			if ( (GetTickCount() - pPacket->m_nTime) > m_nMaxRTO )
			{
				_outputerr( "CUdpHandler::ProcessOutput:PACKET_RTO Index(%d) Count(%d)\n", pPacket->m_nIndex, pPacket->m_nCount );

				pPacketTemp = pPacketNode->GetNext();

				pPacket = pHost->m_qWaitingAck.RemoveNode( pPacketNode );
				pHost->InsertToSendQ( ++pPacket->m_nCount, pPacket->m_nIndex, pPacket->m_buf, pPacket->m_nBufLen );

				// 재전송 횟수가 최대 허용 수치를 초과했을 경우
				if ( pPacket->m_nCount > UDP_MAX_RETRANSMISSION )
					pHost->m_nState = UDP_ERR_SEND_RETRANSMISSION;

				delete pPacket;
				pPacketNode = pPacketTemp;

				continue;
			}
			else
			{
				break;
			}

			pPacketNode = pPacketNode->GetNext();
		}

		// 보낼 수 있는 만큼 보낸다.
		for ( pPacketNode = pHost->m_qSend.GetHead(); pPacketNode; )
		{
			if ( (ulong) pHost->m_qWaitingAck.GetCount() > m_nMaxWaitingAckQSize )
				break;

			pPacket = pPacketNode->GetData();

#ifdef __UDP_DEBUG__
			if ( (ulong) (rand() % 100) >= m_nPacketLoseProbability )
			{
#endif
			nSendLen = sendto( m_sdHost,
							   (char *) pPacket,
							   pPacket->UsedSize(),
							   0,
							   (CSockAddr *) pHost,
							   sizeof( CSockAddr ) );

			if ( nSendLen < pPacket->m_nBufLen )
				break;
#ifdef __UDP_DEBUG__
			}
			else
			{
				_outputerr( "CUdpHandler::ProcessOutput 다음의 패킷이 유실되었습니다.\n", pPacket->m_nIndex );
			}
#endif
			
			pPacketTemp = pPacketNode->GetNext();
			pPacket = pHost->m_qSend.RemoveNode( pPacketNode );
			pPacketNode = pPacketTemp;

			// ACK 패킷의 경우 유실 처리를 하지 않는다. (송신측에서 재전송하므로)
			if ( pPacket->m_nCount == UDP_PACKET_ACK )
			{
				_outputerr( "CUdpHandler::ProcessOutput:SEND_ACK Index(%d)\n", pPacket->m_nIndex );				
				continue;
			}

			_outputerr( "CUdpHandler::ProcessOutput:SEND_DATA Index(%d) Count(%d)\n", pPacket->m_nIndex, pPacket->m_nCount );
			
			// 최초로 발송된 패킷 시간을 기억한다.
			if ( !pPacket->m_nTime )
				pPacket->m_nTime = GetTickCount();
			// RTO를 계산하기 위해
			pPacket->m_nTimeWaitingAck = GetTickCount();
			pHost->m_qWaitingAck.Insert( pPacket );
			
			// 최초로 보내진 패킷이 동기화 시간을 벗어낫을 경우
			if ( GetTickCount() - pPacket->m_nTime > m_nMaxSyncLatency )
				pHost->m_nState = UDP_ERR_SEND_SYNC;
		}
	}
}


uint CUdpHandler::NetIoThread( void *pContext )
{
	CUdpHandler *pUdp = (CUdpHandler *) pContext;

	// select() 인자
	fd_set		readfds, writefds;
	timeval		timeout;

	while ( pUdp->m_nInstanceState != UDP_WAITING_THREAD )
	{
		Sleep( UDP_THREAD_LOOP_TERM );

		FD_ZERO( &readfds );
		FD_ZERO( &writefds );

		FD_SET( pUdp->m_sdHost, &readfds );
		FD_SET( pUdp->m_sdHost, &writefds );

		timeout.tv_sec	= 0;
		timeout.tv_usec	= 0;
		if ( select( 0, &readfds, &writefds, NULL, &timeout ) <= 0 )
			continue;

		pUdp->Lock();

		if ( FD_ISSET( pUdp->m_sdHost, &readfds ) )
			pUdp->ProcessInput();

		if ( FD_ISSET( pUdp->m_sdHost, &writefds ) )
			pUdp->ProcessOutput();

		pUdp->Unlock();
	}

	return 0;
}


int CUdpHandler::__cbCompareHost( void *pArg, CUdpHost *pFirst, CUdpHost *pSecond )
{
	return (*pFirst == *pSecond) ? 0 : -1;
}
