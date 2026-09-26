

/*
	Windows NT IOCP(IO Completion Port) Handler for TCP/IP

	Date:
		2002/04/08 (Last Updated: 2002/04/13)
*/
#ifndef __ORZ_NETWORK_IOCP_HANDLER__
#define __ORZ_NETWORK_IOCP_HANDLER__


#include <winsock2.h>	// winsock basic
#include <mswsock.h>	// winsock extension functions
#include <mstcpip.h>	// WSAIoctl() options


#include <netbase.h>
#include <syncobj.h>
#include <queue.h>	
#include <slist.h>	


//
// IOCP 핸들러 오퍼레이션 코드
//
// ConnectEx(), DisconnectEx() 호출이 추가될 때 아래 코드들도 확장된다.
//
#define IOCP_SEND				0
#define IOCP_RECV				1


//
// IOCP 핸들러 상수 정의
//
#define IOCP_OBJECT_CLASSID_0	0
#define IOCP_MAXBUF				32768
#define IOCP_KEEPALIVE_TIME		8000
#define IOCP_KEEPALIVE_INTERVAL	2000


//
//	IOCP 패킷 클래스
//
class CIocpPacket
{
public:
	char	*m_pPacket;
	int		m_nPacketLen;

public:
	CIocpPacket();
	virtual ~CIocpPacket();
};


//
//	IOCP 서버 오브젝트 클래스
//
class CIocpAcceptor : public CIntLock
{
public:
	SOCKET		m_sdHost;

public:
	CIocpAcceptor();
	virtual ~CIocpAcceptor();

	bool Init( CSockAddr *pAddr );
	void Uninit();
};


//
//	IOCP 클라이언트 오브젝트 클래스
//
class CIocpObject : public CIntLock
{
public:
	struct OLEX : public OVERLAPPED
	{
		int		nOpCode;
		WSABUF	wsaBuf;
		char	szBuf[IOCP_MAXBUF];
		int		nBufLen;
		bool	bProcessing;
	};

public:
	int						m_nClassId;			// class identifier for inheritance
	SOCKET					m_sdHost;			// socket descriptor
	CSockAddr				m_sdAddr;			// peer address
	bool					m_bClosed;			// close flag
	int						m_nRefCnt;			// reference count

	OLEX					m_olSend;
	CQueue< CIocpPacket >	m_qSend;
	CIocpPacket				*m_pPacketPosted;
	
	OLEX					m_olRecv;
	char					m_szExtBuf[IOCP_MAXBUF];
	int						m_nExtLen;

public:
	CIocpObject();
	virtual ~CIocpObject();

	void Init();
	void Uninit();

	void SetClassId( int nClassId );
	int  GetClassId();
	void SetAcceptedSocket( SOCKET sdHost );

	bool Send( CIocpPacket *pPacket = NULL );
	bool Recv();
	bool ExtractPacket( char *pPacket, int *pPacketLen );

	virtual void OnError( int nErrCode )							= 0;
	virtual void OnSend( int nTransferred )							= 0;
	virtual bool OnRecv( char *pPacket, int nPacketLen )			= 0;
	virtual bool OnExtractPacket( char *pPacket, int *pPacketLen )	= 0;

public:
	inline char * IP() { return m_sdAddr.IP(); }
	inline int  Port() { return m_sdAddr.Port(); }
};


//
//	IOCP 핸들러 메인 클래스
//
class CIocpHandler : public CNetBase
{
public:
	HANDLE					m_hIocp;
	int						m_nWorkerCnt;
	HANDLE					*m_phWorkers;

	bool					m_bUseDispatcher;
	HANDLE					m_hStartDispatch;
	HANDLE					m_hCloseDispatcher;
	HANDLE					m_hDispatcher;
	CSList< CIocpObject >	*m_pListWaiting;
	CSList< CIocpObject >	*m_pListProcessing;

	HANDLE					m_hStartAccept;
	HANDLE					m_hCloseAcceptor;
	HANDLE					m_hAcceptor;
	CSList< CIocpAcceptor >	m_listAccepting;

	HANDLE					m_hStartConnect;
	HANDLE					m_hCloseConnector;
	HANDLE					m_hConnector;
	CSList< CIocpObject >	m_listConnecting;

public:
	CIocpHandler();
	virtual ~CIocpHandler();

	bool Init( bool bUseDispatcher = true, int nConcurrentThreads = 0, int nWorkers = 0 );
	void Uninit();

	bool Accept( CIocpAcceptor *pAcceptor );
	bool Connect( CIocpObject *pObject, CSockAddr *pAddr );
	void Close( CIocpObject *pObject );
	bool CloseObject( CIocpObject *pObject );

	// Pure Virtual Functions
	virtual void OnError( int nErrCode )										{}
	virtual CIocpObject * OnAccept( CIocpAcceptor *pAcceptor, SOCKET sdClient )	{ return NULL; }
	virtual void OnAcceptError( CIocpAcceptor *pAcceptor, int nErrCode )		{}
	virtual bool OnConnect( CIocpObject *pObject )								{ return true; }
	virtual void OnConnectError( CIocpObject *pObject, int nErrCode )			{}
	virtual void OnClose( CIocpObject *pObject )								{}
	virtual void OnBeginDispatch()												{}
	virtual void OnEndDispatch()												{}

protected:
	bool InitDispatcher();
	void UninitDispatcher();
	bool InitWorkers( int nWorkers );
	void UninitWorkers();
	bool InitAcceptor();
	void UninitAcceptor();
	bool InitConnector();
	void UninitConnector();
	
	static unsigned __stdcall __tDispatcher( void *pContext );
	static unsigned __stdcall __tWorker( void *pContext );
	static unsigned __stdcall __tAcceptor( void *pContext );
	static unsigned __stdcall __tConnector( void *pContext );

	void __tcDispatcher();
	void __tcWorker();
	void __tcAcceptor();
	void __tcConnector();

	bool DispatchObject		( CIocpObject *pObject, int nTransferred, int nOpCode );
	bool DispatchSend		( CIocpObject *pObject, int nTransferred );
	bool DispatchRecv		( CIocpObject *pObject, int nTransferred );
	bool DispatchRecvDirect	( CIocpObject *pObject, int nTransferred );

	static int __cbCmpObject( void *pArg, CIocpObject *pFirst, CIocpObject *pSecond );
};


#endif