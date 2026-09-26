

#include "netiocp.h"
#include "process.h"


CIocpPacket::CIocpPacket()
{
	m_pPacket		= NULL;
	m_nPacketLen	= 0;
}


CIocpPacket::~CIocpPacket()
{
}




CIocpAcceptor::CIocpAcceptor()
{
	m_sdHost = INVALID_SOCKET;
}


CIocpAcceptor::~CIocpAcceptor()
{
	Uninit();
}


bool CIocpAcceptor::Init( CSockAddr *pAddr )
{
	m_sdHost = WSASocket( AF_INET, SOCK_STREAM, IPPROTO_IP, NULL, 0, WSA_FLAG_OVERLAPPED );
	if ( m_sdHost == INVALID_SOCKET )
		return false;

	if ( bind( m_sdHost, pAddr, sizeof( CSockAddr ) ) == SOCKET_ERROR )
		return false;

	BOOL bNonblock = TRUE;
	if ( ioctlsocket( m_sdHost, FIONBIO, (unsigned long *) &bNonblock ) == SOCKET_ERROR )
		return false;

	return true;
}


void CIocpAcceptor::Uninit()
{
	if ( m_sdHost != INVALID_SOCKET )
	{
		closesocket( m_sdHost );
		m_sdHost = INVALID_SOCKET;
	}
}




CIocpObject::CIocpObject()
{
	Init();
}


CIocpObject::~CIocpObject()
{
	Uninit();
}


void CIocpObject::Init()
{
	m_nClassId	= 0;
	m_sdHost	= INVALID_SOCKET;
	m_nRefCnt	= 0;
	m_bClosed	= false;
	
	memset( &m_olSend, 0, sizeof( OLEX ) );
	memset( &m_olRecv, 0, sizeof( OLEX ) );
	m_olSend.nOpCode = IOCP_SEND;
	m_olRecv.nOpCode = IOCP_RECV;

	m_pPacketPosted	= NULL;

	memset( m_szExtBuf, 0, sizeof( m_szExtBuf ) );
	m_nExtLen = 0;
}


void CIocpObject::Uninit()
{
	memset( m_szExtBuf, 0, sizeof( m_szExtBuf ) );
	m_nExtLen = 0;

	if ( m_pPacketPosted )
	{
		delete m_pPacketPosted;
		m_pPacketPosted = NULL;
	}

	m_qSend.ClearAll();

	if ( m_sdHost != INVALID_SOCKET )
	{
		closesocket( m_sdHost );
		m_sdHost = INVALID_SOCKET;
	}

	memset( &m_olSend, 0, sizeof( OLEX ) );
	memset( &m_olRecv, 0, sizeof( OLEX ) );
	m_olSend.nOpCode = IOCP_SEND;
	m_olRecv.nOpCode = IOCP_RECV;

	m_bClosed	= false;
	m_nRefCnt	= 0;
}


void CIocpObject::SetClassId( int nClassId )
{
	m_nClassId = nClassId;
}


int CIocpObject::GetClassId()
{
	return m_nClassId;
}


void CIocpObject::SetAcceptedSocket( SOCKET sdHost )
{
	m_sdHost = sdHost;

	int nAddrLen = sizeof( CSockAddr );
	getpeername( m_sdHost, &m_sdAddr, &nAddrLen );
}


bool CIocpObject::Send( CIocpPacket *pPacket )
{
	if ( pPacket )
		m_qSend.Enqueue( pPacket );

	if ( m_olSend.bProcessing )
		return true;

	if ( m_pPacketPosted )
	{
		delete m_pPacketPosted;
		m_pPacketPosted = NULL;
	}

	m_pPacketPosted = m_qSend.Dequeue();
	if ( !m_pPacketPosted )
		return false;

	memset( &m_olSend, 0, sizeof( OVERLAPPED ) );
	
	if ( m_qSend.IsEmpty() || m_pPacketPosted->m_nPacketLen > IOCP_MAXBUF )
	{
		m_olSend.wsaBuf.buf = m_pPacketPosted->m_pPacket;
		m_olSend.wsaBuf.len = m_pPacketPosted->m_nPacketLen;
	}
	else
	{		
		//
		// 패킷을 합친다.
		//
		m_olSend.nBufLen = 0;

		do
		{
			memcpy( &m_olSend.szBuf[m_olSend.nBufLen], 
					m_pPacketPosted->m_pPacket, 
					m_pPacketPosted->m_nPacketLen );
			m_olSend.nBufLen += m_pPacketPosted->m_nPacketLen;

			delete m_pPacketPosted;
			m_pPacketPosted = NULL;

			if ( m_qSend.GetCount() && 
				 m_olSend.nBufLen + m_qSend.GetHead()->GetData()->m_nPacketLen > IOCP_MAXBUF )
				 break;

		} while ( m_pPacketPosted = m_qSend.Dequeue() );

		m_olSend.wsaBuf.buf = m_olSend.szBuf;
		m_olSend.wsaBuf.len = m_olSend.nBufLen;
	}

	DWORD nBytesSent;
	
	if ( WSASend( m_sdHost, 
				  &m_olSend.wsaBuf, 
				  1,
				  &nBytesSent,
				  0,
				  (OVERLAPPED *) &m_olSend,
				  NULL ) == SOCKET_ERROR )
	{
		if ( WSAGetLastError() != ERROR_IO_PENDING )
		{
			OnError( WSAGetLastError() );
			return false;
		}
	}

	m_olSend.bProcessing = true;
	m_nRefCnt++;

	return true;
}


bool CIocpObject::Recv()
{
	if ( m_olRecv.bProcessing )
		return true;

	memset( &m_olRecv, 0, sizeof( OVERLAPPED ) );
	m_olRecv.wsaBuf.buf = m_olRecv.szBuf + m_olRecv.nBufLen;
	m_olRecv.wsaBuf.len = IOCP_MAXBUF - m_olRecv.nBufLen;

	DWORD nBytesReceived;
	DWORD nFlag = 0;

	if ( WSARecv( m_sdHost,
				  &m_olRecv.wsaBuf,
				  1,
				  &nBytesReceived,
				  &nFlag,
				  (OVERLAPPED *) &m_olRecv,
				  NULL ) == SOCKET_ERROR )
	{
		if ( WSAGetLastError() != ERROR_IO_PENDING )
		{
			OnError( WSAGetLastError() );
			return false;
		}
	}

	m_olRecv.bProcessing = true;
	m_nRefCnt++;

	return true;
}


bool CIocpObject::ExtractPacket( char *pPacket, int *pPacketLen )
{
	if ( !m_olRecv.nBufLen || !OnExtractPacket( pPacket, pPacketLen ) )
		return false;
	
	memmove( m_olRecv.szBuf, m_olRecv.szBuf + *pPacketLen, m_olRecv.nBufLen - *pPacketLen);
	m_olRecv.nBufLen -= *pPacketLen;
	
	return true;
}


CIocpHandler::CIocpHandler()
{
	m_hIocp				= INVALID_HANDLE_VALUE;
	m_nWorkerCnt		= 0;
	m_phWorkers			= NULL;

	m_bUseDispatcher	= false;
	m_hStartDispatch	= INVALID_HANDLE_VALUE;
	m_hCloseDispatcher	= INVALID_HANDLE_VALUE;
	m_hDispatcher		= INVALID_HANDLE_VALUE;
	m_pListWaiting		= NULL;
	m_pListProcessing	= NULL;

	m_hStartAccept		= INVALID_HANDLE_VALUE;
	m_hCloseAcceptor	= INVALID_HANDLE_VALUE;
	m_hAcceptor			= INVALID_HANDLE_VALUE;

	m_hStartConnect		= INVALID_HANDLE_VALUE;
	m_hCloseConnector	= INVALID_HANDLE_VALUE;
	m_hConnector		= INVALID_HANDLE_VALUE;
}


CIocpHandler::~CIocpHandler()
{
}


bool CIocpHandler::Init( bool bUseDispatcher, int nConcurrentThreads, int nWorkers )
{
	m_hIocp = CreateIoCompletionPort( INVALID_HANDLE_VALUE, NULL, 0, nConcurrentThreads );
	if ( !m_hIocp )
		return false;

	if ( m_bUseDispatcher = bUseDispatcher )
	{
		if ( !InitDispatcher() )
			return false;
	}

	return InitWorkers( nWorkers )	&&
		   InitAcceptor()			&&
		   InitConnector();
}


void CIocpHandler::Uninit()
{
	//
	// 종료 후 불필요한 i/o 를 없애기 위해 worker를 가장 먼저 닫는다.
	//
	// ex> connector를 먼저 닫아버리면 connector에서 bind한 모든 iocp object들에 대해서
	//     스레드 종료 이벤트가 worker로 보내진다.
	//
	UninitWorkers();
	if ( m_bUseDispatcher )
		UninitDispatcher();
	UninitConnector();
	UninitAcceptor();

	if ( m_hIocp != INVALID_HANDLE_VALUE )
	{
		CloseHandle( m_hIocp );
		m_hIocp = INVALID_HANDLE_VALUE;
	}
}


bool CIocpHandler::Accept( CIocpAcceptor *pAcceptor )
{
	m_listAccepting.Lock();

	//
	// WSAEventSelect() 함수에 소켓 갯수 제한이 있다.
	//
	if ( m_listAccepting.GetCount() == MAXIMUM_WAIT_OBJECTS - 2 )
	{
		m_listAccepting.Unlock();
		return false;
	}

	if ( listen( pAcceptor->m_sdHost, SOMAXCONN ) == SOCKET_ERROR )
	{
		m_listAccepting.Unlock();
		return false;
	}

	if ( !m_listAccepting.Insert( pAcceptor ) )
	{
		m_listAccepting.Unlock();
		return false;
	}

	m_listAccepting.Unlock();

	SetEvent( m_hStartAccept );

	return true;
}


bool CIocpHandler::Connect( CIocpObject *pObject, CSockAddr *pAddr )
{
	m_listConnecting.Lock();

	//
	// WSAEventSelect() 함수에 소켓 갯수 제한이 있다.
	// 이 부분은 플랫폼을 XP로 교체할 때 ConnectEx()로 바꾸도록 하자.
	//
	if ( m_listConnecting.GetCount() == MAXIMUM_WAIT_OBJECTS - 2 )
	{
		m_listConnecting.Unlock();
		return false;
	}

	pObject->m_sdHost = WSASocket( AF_INET, SOCK_STREAM, IPPROTO_IP, NULL, 0, WSA_FLAG_OVERLAPPED );
	if ( pObject->m_sdHost == INVALID_SOCKET )
	{		
		m_listConnecting.Unlock();
		return false;
	}
	
	BOOL bNonblock = TRUE;
	if ( ioctlsocket( pObject->m_sdHost, FIONBIO, (unsigned long *) &bNonblock ) == SOCKET_ERROR )
	{
		m_listConnecting.Unlock();
		return false;
	}

	if ( connect( pObject->m_sdHost, pAddr, sizeof( CSockAddr ) ) == SOCKET_ERROR )
	{
		if ( GetLastError() != WSAEWOULDBLOCK )
		{
			m_listConnecting.Unlock();
			return false;
		}
	}

	if ( !m_listConnecting.Insert( pObject ) )
	{
		m_listConnecting.Unlock();
		return false;
	}

	m_listConnecting.Unlock();

	SetEvent( m_hStartConnect );

	return true;
}


void CIocpHandler::Close( CIocpObject *pObject )
{
	pObject->Lock();

	if ( CloseObject( pObject ) )
		return;

	pObject->Unlock();
}


bool CIocpHandler::CloseObject( CIocpObject *pObject )
{
	pObject->m_bClosed = true;

	//
	// issue된 다른 thread event가 있다면 아직 삭제할 때가 아니다.
	//
	if ( !pObject->m_bClosed || pObject->m_nRefCnt )
		return false;
	
	//
	// 오브젝트를 잠근(lock) 상태로 이 함수가 호출되기 때문에 지우기 전 풀어준다(unlock).
	//
	pObject->Unlock();

	OnClose( pObject );
	return true;
}


bool CIocpHandler::InitDispatcher()
{	
	m_pListWaiting		= new CSList< CIocpObject >;
	m_pListWaiting->SetCompareFunction( __cbCmpObject, NULL );

	m_pListProcessing	= new CSList< CIocpObject >;	
	m_pListProcessing->SetCompareFunction( __cbCmpObject, NULL );

	m_hStartDispatch	= CreateEvent( NULL, FALSE, FALSE, NULL );
	m_hCloseDispatcher	= CreateEvent( NULL, FALSE, FALSE, NULL );
	
	unsigned nID;
	m_hDispatcher = (HANDLE) _beginthreadex( NULL, 0, __tDispatcher, this, 0, &nID );
	if ( m_hDispatcher == INVALID_HANDLE_VALUE )
		return false;
	
	return true;
}


void CIocpHandler::UninitDispatcher()
{
	if ( m_hDispatcher != INVALID_HANDLE_VALUE )
	{
		SetEvent( m_hCloseDispatcher );
		WaitForSingleObject( m_hDispatcher, INFINITE );
		CloseHandle( m_hDispatcher );
		m_hDispatcher = INVALID_HANDLE_VALUE;

		CloseHandle( m_hStartDispatch );
		m_hStartDispatch = INVALID_HANDLE_VALUE;
		CloseHandle( m_hCloseDispatcher );
		m_hCloseDispatcher = INVALID_HANDLE_VALUE;
	}

	if ( m_pListWaiting )
	{
		m_pListWaiting->ClearAll( false );
		delete m_pListWaiting;
		m_pListWaiting = NULL;
	}

	if ( m_pListProcessing )
	{
		m_pListProcessing->ClearAll( false );
		delete m_pListProcessing;
		m_pListProcessing = NULL;
	}
}


bool CIocpHandler::InitWorkers( int nWorkers )
{	
	SYSTEM_INFO sysInfo;
	GetSystemInfo( &sysInfo );

	if ( !nWorkers )
		nWorkers = sysInfo.dwNumberOfProcessors * 2;

	m_nWorkerCnt	= nWorkers;
	m_phWorkers		= new HANDLE[ m_nWorkerCnt ];
	if ( !m_phWorkers )
		return false;

	unsigned nID;

	for ( int i = 0; i < nWorkers; i++ )
	{
		m_phWorkers[i] = (HANDLE) _beginthreadex( NULL, 0, __tWorker, this, 0, &nID );
		if ( m_phWorkers[i] == INVALID_HANDLE_VALUE )
			return false;
	}

	return true;
}


void CIocpHandler::UninitWorkers()
{
	if ( m_phWorkers )
	{
		for ( int i = 0; i < m_nWorkerCnt; i++ )
			PostQueuedCompletionStatus( m_hIocp, 0, 0, NULL );

		WaitForMultipleObjects( m_nWorkerCnt, m_phWorkers, TRUE, INFINITE );

		for ( i = 0; i < m_nWorkerCnt; i++ )
			CloseHandle( m_phWorkers[i] );

		delete[] m_phWorkers;
		m_phWorkers = NULL;
	}

	m_nWorkerCnt = 0;
}


bool CIocpHandler::InitAcceptor()
{
	m_hStartAccept		= CreateEvent( NULL, FALSE, FALSE, NULL );
	m_hCloseAcceptor	= CreateEvent( NULL, FALSE, FALSE, NULL );

	unsigned nID;
	m_hAcceptor = (HANDLE) _beginthreadex( NULL, 0, __tAcceptor, this, 0, &nID );
	if ( m_hAcceptor == INVALID_HANDLE_VALUE )
		return false;

	return true;
}


void CIocpHandler::UninitAcceptor()
{
	if ( m_hAcceptor != INVALID_HANDLE_VALUE )
	{
		SetEvent( m_hCloseAcceptor );			
		WaitForSingleObject( m_hAcceptor, INFINITE );
		CloseHandle( m_hAcceptor );
		m_hAcceptor = INVALID_HANDLE_VALUE;
		
		CloseHandle( m_hStartAccept );
		m_hStartAccept = INVALID_HANDLE_VALUE;
		CloseHandle( m_hCloseAcceptor );
		m_hCloseAcceptor = INVALID_HANDLE_VALUE;
	}

	m_listAccepting.ClearAll( false );
}


bool CIocpHandler::InitConnector()
{
	m_hStartConnect		= CreateEvent( NULL, FALSE, FALSE, NULL );
	m_hCloseConnector	= CreateEvent( NULL, FALSE, FALSE, NULL );

	unsigned nID;
	m_hConnector = (HANDLE) _beginthreadex( NULL, 0, __tConnector, this, 0, &nID );
	if ( m_hConnector == INVALID_HANDLE_VALUE )
		return false;

	return true;
}


void CIocpHandler::UninitConnector()
{
	if ( m_hConnector != INVALID_HANDLE_VALUE )
	{
		SetEvent( m_hCloseConnector );			
		WaitForSingleObject( m_hConnector, INFINITE );
		CloseHandle( m_hConnector );
		m_hConnector = INVALID_HANDLE_VALUE;
		
		CloseHandle( m_hStartConnect );
		m_hStartConnect = INVALID_HANDLE_VALUE;
		CloseHandle( m_hCloseConnector );
		m_hCloseConnector = INVALID_HANDLE_VALUE;
	}

	m_listConnecting.ClearAll( false );
}


unsigned CIocpHandler::__tDispatcher( void *pContext )
{
	((CIocpHandler *) pContext)->__tcDispatcher();

	return 0;
}


unsigned CIocpHandler::__tWorker( void *pContext )
{
	((CIocpHandler *) pContext)->__tcWorker();

	return 0;
}


unsigned CIocpHandler::__tAcceptor( void *pContext )
{
	((CIocpHandler *) pContext)->__tcAcceptor();

	return 0;
}


unsigned CIocpHandler::__tConnector( void *pContext )
{
	((CIocpHandler *) pContext)->__tcConnector();

	return 0;
}


void CIocpHandler::__tcDispatcher()
{
	HANDLE	hEvents[2] = { m_hStartDispatch, m_hCloseDispatcher };
	int		nEventCnt = 2;
	int		nRet;
	char	szPacket[IOCP_MAXBUF];
	int		nPacketLen;

	CListNode< CIocpObject >	*pNode;
	CIocpObject					*pObject;

	while ( true )
	{
		nRet = WaitForMultipleObjects( nEventCnt, hEvents, FALSE, INFINITE );
		if ( nRet == WAIT_OBJECT_0 + 1 )
			break;
		
		//
		// exchange object lists
		//
		m_pListWaiting->Lock();
		m_pListProcessing->Lock();
		{
			m_pListWaiting->Swap( m_pListProcessing );
		}
		m_pListProcessing->Unlock();
		m_pListWaiting->Unlock();
		
		//
		// start dispatch!
		//
		OnBeginDispatch();

		m_pListProcessing->Lock();		
		for ( pNode = m_pListProcessing->GetHead(); pNode; pNode = pNode->GetNext() )
		{
			pObject = pNode->GetData();
			
			pObject->Lock();
			pObject->m_nRefCnt--;
			
			while ( pObject->ExtractPacket( szPacket, &nPacketLen ) )
			{
				if ( !pObject->OnRecv( szPacket, nPacketLen ) )
				{
					pObject->m_bClosed = true;
					break;
				}
			}
			
			//
			// 수신 버퍼가 꽉 찼을 때까지 버퍼 처리를 전혀 할 수 없었다면 연결을 끊어버린다.
			//
			if ( pObject->m_olRecv.nBufLen == IOCP_MAXBUF )
				pObject->m_bClosed = true;
			
			if ( pObject->m_bClosed || !pObject->Recv() )
			{
				if ( CloseObject( pObject ) )
					continue;
			}
			
			pObject->Unlock();
		}		
		m_pListProcessing->ClearAll( false );
		m_pListProcessing->Unlock();

		OnEndDispatch();
	}
}


void CIocpHandler::__tcWorker()
{
	BOOL				bRet;
	DWORD				nTransferred;
	CIocpObject			*pObject;
	CIocpObject::OLEX	*pOverlapped;

	while ( true )
	{
		bRet = GetQueuedCompletionStatus( m_hIocp, 
										  &nTransferred,
										  (DWORD *) &pObject,
										  (OVERLAPPED **) &pOverlapped,
										  INFINITE );
		if ( !pObject || !pOverlapped )
			break;

		pObject->Lock();

		pObject->m_nRefCnt--;

		if ( !bRet || nTransferred == 0 )
			pObject->m_bClosed = true;

		if ( pObject->m_bClosed || !DispatchObject( pObject, nTransferred, pOverlapped->nOpCode ) )
		{
			if ( CloseObject( pObject ) )
				continue;
		}

		pObject->Unlock();
	}
}


void CIocpHandler::__tcAcceptor()
{
	HANDLE	hEvents[MAXIMUM_WAIT_OBJECTS] = { m_hStartAccept, m_hCloseAcceptor, (HANDLE) -1, };
	int		nEventCnt = 2;
	int		nRet;
	DWORD	nBytesReturned;

	WSANETWORKEVENTS	eventResult;
	tcp_keepalive		keepAlive = { TRUE, IOCP_KEEPALIVE_TIME, IOCP_KEEPALIVE_INTERVAL };

	CListNode< CIocpAcceptor >	*pNode;
	CIocpAcceptor				*pAcceptor;

	CIocpObject					*pObject;
	SOCKET						sdClient;
	CSockAddr					sdAddr;
	int							nAddrLen;

	//
	// 윈속 연결 감지 이벤트 생성
	//
	for ( int i = 2; i < MAXIMUM_WAIT_OBJECTS; i++ )
		hEvents[i] = WSACreateEvent();

	while ( true )
	{
		nRet = WSAWaitForMultipleEvents( nEventCnt, hEvents, FALSE, INFINITE, FALSE );
		if ( nRet == WAIT_OBJECT_0 )
		{
			m_listAccepting.Lock();

			nEventCnt = 2;

			for ( pNode = m_listAccepting.GetHead(); pNode; pNode = pNode->GetNext() )
			{
				pAcceptor = pNode->GetData();

				WSAResetEvent( hEvents[nEventCnt] );
				WSAEventSelect( pAcceptor->m_sdHost, hEvents[nEventCnt], FD_ACCEPT );

				nEventCnt++;
			}
			
			m_listAccepting.Unlock();
			continue;
		}
		else if ( nRet == WAIT_OBJECT_0 + 1 )
			break;

		//
		// 윈속 이벤트가 감지된 모든 소켓들을 검색하여 처리한다.
		//
		m_listAccepting.Lock();

		for ( i = 2, pNode = m_listAccepting.GetHead(); i < nEventCnt && pNode; i++, pNode = pNode->GetNext() )
		{
			pAcceptor = pNode->GetData();

			WSAEnumNetworkEvents( pAcceptor->m_sdHost, hEvents[i], &eventResult );

			if ( !eventResult.lNetworkEvents )
				continue;

			WSAResetEvent( hEvents[i] );
			
			nAddrLen = sizeof( CSockAddr );
			sdClient = accept( pAcceptor->m_sdHost, &sdAddr, &nAddrLen );
			if ( sdClient == INVALID_SOCKET )
			{
				OnAcceptError( pAcceptor, GetLastError() );
				continue;
			}
			
			pObject = OnAccept( pAcceptor, sdClient );
			if ( pObject )
			{
				pObject->Lock();
			
				//
				// 비정상 연결을 감지하기 위해 KeepAlive 패킷을 이용한다. 
				// NT 4.0 이하는 아래 함수가 적용되지 않으므로 스스로 구현해야 한다.
				//
				WSAIoctl( pObject->m_sdHost, SIO_KEEPALIVE_VALS, &keepAlive, sizeof( keepAlive ), 
					0, 0, &nBytesReturned, NULL, NULL );
				
				if ( !CreateIoCompletionPort( (HANDLE) pObject->m_sdHost, m_hIocp, (DWORD) pObject, 0 ) ||
					 !pObject->Recv() )
				{
					if ( CloseObject( pObject ) )
						continue;
				}
				
				pObject->Unlock();
			}
		}

		m_listAccepting.Unlock();
	}

	for ( i = 2; i < MAXIMUM_WAIT_OBJECTS; i++ )
		WSACloseEvent( hEvents[i] );
}


void CIocpHandler::__tcConnector()
{
	HANDLE	hEvents[MAXIMUM_WAIT_OBJECTS] = { m_hStartConnect, m_hCloseConnector, (HANDLE) -1, };
	int		nEventCnt = 2;
	int		nRet;
	DWORD	nBytesReturned;

	WSANETWORKEVENTS	eventResult;
	tcp_keepalive		keepAlive = { TRUE, IOCP_KEEPALIVE_TIME, IOCP_KEEPALIVE_INTERVAL };

	CListNode< CIocpObject >	*pNode, *pTemp;
	CIocpObject					*pObject;

	//
	// 윈속 연결 감지 이벤트 생성
	//
	for ( int i = 2; i < MAXIMUM_WAIT_OBJECTS; i++ )
		hEvents[i] = WSACreateEvent();

	while ( true )
	{
		nRet = WSAWaitForMultipleEvents( nEventCnt, hEvents, FALSE, INFINITE, FALSE );
		if ( nRet == WAIT_OBJECT_0 )
		{
			m_listConnecting.Lock();

			nEventCnt = 2;

			for ( pNode = m_listConnecting.GetHead(); pNode; pNode = pNode->GetNext() )
			{
				pObject = pNode->GetData();

				WSAResetEvent( hEvents[nEventCnt] );
				WSAEventSelect( pObject->m_sdHost, hEvents[nEventCnt], FD_CONNECT );

				nEventCnt++;
			}
			
			m_listConnecting.Unlock();
			continue;
		}
		else if ( nRet == WAIT_OBJECT_0 + 1 )
			break;

		//
		// 윈속 이벤트가 감지된 모든 소켓들을 검색하여 처리한다.
		//
		m_listConnecting.Lock();

		for ( i = 2, pNode = m_listConnecting.GetHead(); i < nEventCnt && pNode; i++ )
		{
			pObject = pNode->GetData();

			WSAEnumNetworkEvents( pObject->m_sdHost, hEvents[i], &eventResult );

			if ( !eventResult.lNetworkEvents )
			{
				pNode = pNode->GetNext();
				continue;
			}

			WSAResetEvent( hEvents[i] );
			
			if ( eventResult.iErrorCode[FD_CONNECT_BIT] )
			{
				OnConnectError( pObject, eventResult.iErrorCode[FD_CONNECT_BIT] );
			}
			else if ( OnConnect( pObject ) )
			{
				pObject->Lock();

				nBytesReturned = sizeof( CSockAddr );
				getpeername( pObject->m_sdHost, pObject->m_sdAddr, (int *) &nBytesReturned );
				
				//
				// 비정상 연결을 감지하기 위해 KeepAlive 패킷을 이용한다.
				//
				WSAIoctl( pObject->m_sdHost, SIO_KEEPALIVE_VALS, &keepAlive, sizeof( keepAlive ), 
				   0, 0, &nBytesReturned, NULL, NULL );
				
				if ( !CreateIoCompletionPort( (HANDLE) pObject->m_sdHost, m_hIocp, (DWORD) pObject, 0 ) ||
					 !pObject->Recv() )
				{
					if ( CloseObject( pObject ) )
					{
						pTemp = pNode->GetNext();
						m_listConnecting.RemoveNode( pNode );
						pNode = pTemp;
						continue;
					}
				}

				pObject->Unlock();
			}			
			
			pTemp = pNode->GetNext();
			m_listConnecting.RemoveNode( pNode );
			pNode = pTemp;
		}

		m_listConnecting.Unlock();
	}

	for ( i = 2; i < MAXIMUM_WAIT_OBJECTS; i++ )
		WSACloseEvent( hEvents[i] );
}


bool CIocpHandler::DispatchObject( CIocpObject *pObject, int nTransferred, int nOpCode )
{
	//
	// 오퍼레이션 코드 비교 루틴을 줄이기 위해 함수 포인터 테이블을 사용한다.
	//
	static struct OPERATION_HANDLER
	{
		bool (CIocpHandler:: *pfnFunc)( CIocpObject *pObject, int nTransferred );

	} s_dispatchTable[] = 
	{
		CIocpHandler::DispatchSend,
		m_bUseDispatcher ? CIocpHandler::DispatchRecv : CIocpHandler::DispatchRecvDirect,
	};

	return (this->*s_dispatchTable[ nOpCode ].pfnFunc)( pObject, nTransferred );
}


bool CIocpHandler::DispatchSend( CIocpObject *pObject, int nTransferred )
{
	pObject->m_olSend.bProcessing = false;

	pObject->OnSend( nTransferred );

	//
	// 다음 데이터를 보낸다.
	//
	if ( pObject->m_qSend.GetCount() )
		return pObject->Send();

	return true;
}


bool CIocpHandler::DispatchRecv( CIocpObject *pObject, int nTransferred )
{
	pObject->m_olRecv.bProcessing = false;
	pObject->m_olRecv.nBufLen += nTransferred;

	m_pListWaiting->Lock();

	if ( !m_pListWaiting->Insert( pObject ) )
	{
		m_pListWaiting->Unlock();
		return false;
	}

	pObject->m_nRefCnt++;

	m_pListWaiting->Unlock();
	
	if ( m_hDispatcher != INVALID_HANDLE_VALUE )
		SetEvent( m_hStartDispatch );

	return true;
}


bool CIocpHandler::DispatchRecvDirect( CIocpObject *pObject, int nTransferred )
{
	pObject->m_olRecv.bProcessing = false;
	pObject->m_olRecv.nBufLen += nTransferred;

	while ( pObject->ExtractPacket( pObject->m_szExtBuf, &pObject->m_nExtLen ) )
	{
		if ( !pObject->OnRecv( pObject->m_szExtBuf, pObject->m_nExtLen ) )
			return false;
	}

	//
	// 수신 버퍼가 꽉 찼을 때까지 버퍼 처리를 전혀 할 수 없었다면 연결을 끊어버린다.
	//
	if ( pObject->m_olRecv.nBufLen == IOCP_MAXBUF )
		return false;

	return pObject->Recv();
}


int CIocpHandler::__cbCmpObject( void *pArg, CIocpObject *pFirst, CIocpObject *pSecond )
{
	return pFirst - pSecond;
}
