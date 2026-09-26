

/*
	TCP Handler for Game

	Date:
		2001/10/23

	Note:
		프로토콜에 맞춰 CopyCompletionPacket() 함수를 오버라이딩한다.
*/
#ifndef __ORZ_NETWORK_TCP_HANDLER__
#define __ORZ_NETWORK_TCP_HANDLER__


#include "netbase.h"
#include "queue.h"
#include "streambf.h"
#include "syncobj.h"


#define TCP_MAXBUF						4096
#define TCP_THREAD_LOOP_TERM			40

// 네트웍 지연시간 기본 설정 값
#define TCP_DEF_TIMEOUT					30000

// 클래스(CTcpHandler)의 상태값
#define TCP_UNINIT						0
#define TCP_INIT						1
#define TCP_WAITING_THREAD				11

// Poll 함수의 반환 값
#define TCP_CONNECT_TRYING				1	// 접속 시도중
#define TCP_CONNECT						2	// 접속 성공
#define TCP_RECV						3	// 수신된 데이터가 있음
#define TCP_DISCONNECT					11	// 접속 끊김
#define TCP_ERR_CONNECT					21	// 접속할 수 없음
#define TCP_ERR_SEND					22	// 송신할 수 없음
#define TCP_ERR_RECV					23	// 수신할 수 없음


class CTcpPacket
{
public:
	char	*m_pBuf;
	ulong	m_nBufLen;
	
public:
	CTcpPacket( int nBufLen );
	virtual ~CTcpPacket();

	operator char * ()				{ return m_pBuf; }
	operator const char * const ()	{ return (const char *) m_pBuf; }

	char *	Data()					{ return m_pBuf; }
	ulong	Size()					{ return m_nBufLen; }
};


class CTcpHandler : public CNetBase, CIntLock
{
public:
	byte	m_nInstanceState;	// 인스턴스의 상태 값
	HANDLE	m_hNetIoThread;		// TCP IO 스레드 핸들

	uint	m_nMaxTimeOut;

	ushort	m_nState;			// 네트웍 상태 값 (Poll 함수의 반환 값)
	SOCKET	m_sdHost;

	CQueue< CTcpPacket >	m_qSend;	
	CTcpPacket				*m_pOutputPacket;	// 현재 출력 패킷
	ulong					m_nOutputBytes;		// 현재 출력 패킷의 보낸 길이
	CStreamBuffer< char >	m_qRecv;			// 개념적으로 Queue와 같다.	

public:
	CTcpHandler();
	virtual ~CTcpHandler();

	void Reset();

	bool Connect( CSockAddr *pAddr, uint nMaxTimeOut = TCP_DEF_TIMEOUT );
	bool Connect( char *pAddr, short nPort, uint nMaxTimeOut = TCP_DEF_TIMEOUT );
	void Disconnect();

	bool Poll( ushort *pState, CTcpPacket **ppPacket );
	void Send( char *pBuf, uint nBufLen );

protected:
	virtual bool CopyCompletionPacket( char *pBuf, int nBufLen, CTcpPacket **ppPacket );

	void ProcessInput();
	void ProcessOutput();
	void ProcessExcept();

	static uint __stdcall NetIoThread( void *pContext );
};


#endif