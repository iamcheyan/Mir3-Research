

#include "nettcp.h"
#include "process.h"


CTcpPacket::CTcpPacket( int nBufLen )
{
	m_pBuf		= new char[ nBufLen ];
	if ( m_pBuf == NULL )
		throw CError( "CTcpPacket::CTcpPacket 메모리 할당 실패" );
	m_nBufLen	= nBufLen;
}


CTcpPacket::~CTcpPacket()
{
	if ( m_pBuf )
		delete[] m_pBuf;
}




CTcpHandler::CTcpHandler()
{
	m_nInstanceState	= TCP_UNINIT;
	m_hNetIoThread		= NULL;

	m_nMaxTimeOut		= 0;

	m_nState			= 0;
	m_sdHost			= INVALID_SOCKET;

	m_pOutputPacket		= NULL;
	m_nOutputBytes		= 0;
}


CTcpHandler::~CTcpHandler()
{
	Reset();
}


void CTcpHandler::Reset()
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
		m_nInstanceState = TCP_WAITING_THREAD;
		
		WaitForSingleObject( m_hNetIoThread, INFINITE );
		CloseHandle( m_hNetIoThread );
		m_hNetIoThread = NULL;
	}

	if ( m_pOutputPacket )
	{
		delete m_pOutputPacket;
		m_pOutputPacket = NULL;
	}
	
	m_nInstanceState = TCP_UNINIT;

	m_qSend.ClearAll();

	Unlock();
}


bool CTcpHandler::Connect( CSockAddr *pAddr, uint nMaxTimeOut )
{
	m_sdHost = socket( AF_INET, SOCK_STREAM, 0 );
	if ( m_sdHost == INVALID_SOCKET )
		throw CError( "CTcpHandler::Init socket 생성 실패" );

	ulong nNonblock = 1;
	if ( ioctlsocket( m_sdHost, FIONBIO, &nNonblock ) == SOCKET_ERROR )
		throw CError( "CTcpHandler::Init socket 넌블럭 모드 실패" );

	if ( setsockopt( m_sdHost, SOL_SOCKET, SO_SNDTIMEO, (char *) &nMaxTimeOut, sizeof( nMaxTimeOut ) ) == SOCKET_ERROR )
		throw CError( "CTcpHandler::Init setsockopt( SO_SNDTIMEO ) 호출 실패" );

	if ( setsockopt( m_sdHost, SOL_SOCKET, SO_RCVTIMEO, (char *) &nMaxTimeOut, sizeof( nMaxTimeOut ) ) == SOCKET_ERROR )
		throw CError( "CTcpHandler::Init setsockopt( SO_RCVTIMEO ) 호출 실패" );

	if ( connect( m_sdHost, pAddr, sizeof( SOCKADDR ) ) == SOCKET_ERROR )
	{
		if ( WSAGetLastError() != WSAEWOULDBLOCK )
			throw CError( "CTcpHandler::Init connect 실패" );
	}

	m_nMaxTimeOut		= nMaxTimeOut;

	m_nInstanceState	= TCP_INIT;
	m_nState			= TCP_CONNECT_TRYING;

	uint nThreadId;
	m_hNetIoThread = (HANDLE) _beginthreadex( NULL, 0, NetIoThread, this, 0, &nThreadId );
	if ( m_hNetIoThread == NULL )
		throw CError( "CTcpHandler::Init UDP 스레드 생성 실패" );

	return true;
}


bool CTcpHandler::Connect( char *pAddr, short nPort, uint nMaxTimeOut )
{
	return Connect( CSockAddr( pAddr, nPort ), nMaxTimeOut );
}


void CTcpHandler::Disconnect()
{
	Reset();
}


/*
	Poll()

	이 함수의 상태 값이 TCP_RECV라면, 사용자가 할당된 메모리를 직접 해제해야 한다.

	사용 예>
	---------------------------------------------------------------
	ushort		nState;
	CTcpPacket	*pPacket;

	while ( Poll( &nState, &pPacket ) )
	{
		if ( nState == TCP_RECV )
		{
			ProcessRecvPacket();
			delete pPacket;  <-----
		}
	}
	---------------------------------------------------------------
*/
bool CTcpHandler::Poll( ushort *pState, CTcpPacket **ppPacket )
{
	Lock();

	if ( m_qRecv.Length() &&
		 CopyCompletionPacket( m_qRecv.Buffer(), m_qRecv.Length(), ppPacket ) )
	{
		m_qRecv.Remove( (*ppPacket)->Size() );

		*pState = TCP_RECV;

		Unlock();
		return true;
	}

	if ( m_nState && m_nState != TCP_RECV )
	{
		*pState = m_nState;

		// 정상적인 상태이므로 다음 진행을 위해 한번만 알려준다. 
		if ( m_nState == TCP_CONNECT )
			m_nState = 0;

		Unlock();
		return true;
	}

	Unlock();
	return false;
}


void CTcpHandler::Send( char *pBuf, uint nBufLen )
{
	CTcpPacket *pPacket = new CTcpPacket( nBufLen );
	if ( pPacket == NULL )
		throw CError( "CTcpHandler::Send 메모리 할당 실패" );

	memcpy( pPacket->m_pBuf, pBuf, nBufLen );

	Lock();
	m_qSend.Enqueue( pPacket );
	Unlock();
}


/*
	CopyCompletionPacket()

	인자 설명>
	pBuf		: 수신된 데이터 스트림
	nBufLen		: 데이터 스트림의 크기
	pPacket		: 복사할 대상 (함수 안에서 메모리를 할당해야 한다.)

	기본 동작>
	수신된 데이터를 그대로 복사한다.
*/
bool CTcpHandler::CopyCompletionPacket( char *pBuf, int nBufLen, CTcpPacket **ppPacket )
{
	*ppPacket = new CTcpPacket( nBufLen );
	if ( ppPacket == NULL )
		return false;

	memcpy( (*ppPacket)->m_pBuf, pBuf, nBufLen );

	return true;
}


void CTcpHandler::ProcessInput()
{
	// recv() 인자
	char buf[TCP_MAXBUF];
	int	 nRecvLen;

	while ( true )
	{
		nRecvLen = recv( m_sdHost, buf, sizeof( buf ), 0 );
		if ( nRecvLen == 0 )
		{
			m_nState = TCP_DISCONNECT;
			break;
		}
		else if ( nRecvLen < 0 )
		{
			if ( WSAGetLastError() != WSAEWOULDBLOCK )
				m_nState = TCP_ERR_RECV;

			break;
		}

		m_qRecv.Append( buf, nRecvLen );
	}
}


void CTcpHandler::ProcessOutput()
{
	// TCP 연결이 이루어진 시점부터 출력이 가능해진다.
	if ( m_nState == TCP_CONNECT_TRYING )
		m_nState = TCP_CONNECT;

	// send() 인자
	uint nSendLen;

	if ( m_pOutputPacket == NULL )
		m_pOutputPacket = m_qSend.Dequeue();
	
	while ( m_pOutputPacket )
	{			
		nSendLen = send( m_sdHost, 
						 m_pOutputPacket->Data() + m_nOutputBytes, 
						 m_pOutputPacket->Size() - m_nOutputBytes, 
						 0 );
		
		if ( nSendLen < 0 )
		{
			if ( WSAGetLastError() != WSAEWOULDBLOCK )
				m_nState = TCP_ERR_SEND;

			break;
		}
		
		m_nOutputBytes += nSendLen;
		
		if ( m_pOutputPacket->Size() == m_nOutputBytes )
		{
			delete m_pOutputPacket;
			m_pOutputPacket = m_qSend.Dequeue();
		}
	}
}


/*
	넌블럭 모드에서 except는 접속 실패를 의미한다.
*/
void CTcpHandler::ProcessExcept()
{
	m_nState = TCP_ERR_CONNECT;
}


uint CTcpHandler::NetIoThread( void *pContext )
{
	CTcpHandler *pTcp = (CTcpHandler *) pContext;

	// select() 인자
	fd_set		readfds, writefds, exceptfds;
	timeval		timeout;

	while ( pTcp->m_nInstanceState != TCP_WAITING_THREAD )
	{
		Sleep( TCP_THREAD_LOOP_TERM );

		FD_ZERO( &readfds );
		FD_ZERO( &writefds );
		FD_ZERO( &exceptfds );

		FD_SET( pTcp->m_sdHost, &readfds );
		FD_SET( pTcp->m_sdHost, &writefds );
		FD_SET( pTcp->m_sdHost, &exceptfds );

		timeout.tv_sec	= 0;
		timeout.tv_usec	= 0;
		if ( select( 0, &readfds, &writefds, &exceptfds, &timeout ) <= 0 )
			continue;

		pTcp->Lock();

		if ( FD_ISSET( pTcp->m_sdHost, &readfds ) )
			pTcp->ProcessInput();

		if ( FD_ISSET( pTcp->m_sdHost, &writefds ) )
			pTcp->ProcessOutput();

		if ( FD_ISSET( pTcp->m_sdHost, &exceptfds ) )
			pTcp->ProcessExcept();

		pTcp->Unlock();
	}

	return 0;
}
