

/*
	UDP Handler for Game

	Date:
		2001/10/23

	Note:
		PACKET 구조
	
		HEADER	: INDEX[4BYTE] + TYPE[2BYTE]
		DATA	: HEADER + DATA
		ACK		: HEADER (HEADER부의 INDEX가 ACK INDEX)
*/
#ifndef __ORZ_NETWORK_UDP_HANDLER__
#define __ORZ_NETWORK_UDP_HANDLER__


#include "netbase.h"
#include "list.h"
#include "queue.h"
#include "syncobj.h"


/*
	UDP 패킷 손실률을 테스트 하기 위해서 다음을 선언할 수 있다.

	#define __UDP_DEBUG__

	Desc:
		SetPacketLoseProbability() 함수가 활성화된다.
*/
#define __UDP_DEBUG__


#define UDP_MAXBUF						4096
#define UDP_THREAD_LOOP_TERM			40

// 호스트 WAITING ACK 큐 기본 크기 (Sliding Window Size)
#define UDP_DEF_WAITING_ACK_Q_SIZE		10

// 네트웍 지연시간 기본 설정 값
#define UDP_DEF_SYNC_LATENCY			10000
#define UDP_DEF_RTO						1000
#define	UDP_MAX_RETRANSMISSION			10

// 클래스(CUdpHandler) 인스턴스의 상태값
#define UDP_UNINIT						0
#define UDP_INIT						1
#define UDP_WAITING_THREAD				11

// Poll 함수의 상태 반환 값
#define UDP_RECV						1	// 수신된 데이터가 있음
#define UDP_ERR_SEND					11	// 송신할 수 없음 (ICMP Port Error)
#define UDP_ERR_SEND_RETRANSMISSION		12	// 송신할 수 없음 (Retransmission Error)
#define UDP_ERR_SEND_SYNC				21	// 송신 동기화 시간이 초과되었음
#define UDP_ERR_RECV_SYNC				22	// 수신 동기화 시간이 초과되었음
#define UDP_ERR_NOT_ENOUGH_BUFFER		91	// 데이터를 저장할 버퍼가 부족함

// UDP 헤더 인덱스 (CUdpPacketHeader::m_nIndex)
#define UDP_PACKET_START				0x00000000
#define UDP_PACKET_END					0xFFFFFFFF

// UDP 패킷 헤더 타입 (CUdpPacketHeader::m_nCount)
#define UDP_PACKET_ACK					0
#define UDP_PACKET_DATA					1



class CUdpPacketHeader
{
public:
	ulong	m_nIndex;	// 패킷 인덱스
	ulong	m_nCount;	// 재전송 횟수 (이 값이 0이면 ACK 패킷이다.)

	CUdpPacketHeader();
	virtual ~CUdpPacketHeader();
};



class CUdpPacket : public CUdpPacketHeader
{
public:
	char	m_buf[UDP_MAXBUF];

	ulong	m_nBufLen;			// 사용된 버퍼의 크기
	ulong	m_nTime;			// 패킷이 최초로 보내진 시점
	ulong	m_nTimeWaitingAck;	// 패킷이 보내진 시점 (재전송 포함)

public:
	CUdpPacket();
	virtual ~CUdpPacket();

	operator char * ()				{ return (char *) this; }
	operator const char * () const	{ return (const char *) this; }

	ulong	Size()		{ return sizeof( CUdpPacketHeader ) + UDP_MAXBUF; }
	ulong	UsedSize()	{ return sizeof( CUdpPacketHeader ) + m_nBufLen; }
};



class CUdpHost : public CSockAddr
{
public:
	ushort					m_nState;			// 호스트의 상태 값

	void					*m_pHostData;		// 호스트의 부가 정보를 담을 버퍼

	CQueue< CUdpPacket >	m_qSend;
	CQueue< CUdpPacket >	m_qWaitingAck;
	CQueue< CUdpPacket >	m_qRecv;

	ulong					m_nLastSendIndex;	// 패킷 일렬화를 위한 인덱스

	ulong					m_nNextPollIndex;	// 패킷 일렬화를 위한 인덱스
	ulong					m_nLastRecvTime;	// 동기화 처리를 위해 마지막 패킷이 도착한 시간을 저장한다.

public:
	CUdpHost();
	~CUdpHost();

	bool	InsertToSendQ( ulong nType, uint nIndex, char *pBuf, uint nBufLen );
	bool	InsertToRecvQ( ulong nIndex, char *pBuf, uint nBufLen );
	bool	RemoveFromSendQ( ulong nIndex );
	bool	RemoveFromWaitingAckQ( ulong nIndex );
};



/*
	CUdpHandler Class
*/
class CUdpHandler : public CNetBase, CIntLock
{
public:
	byte				m_nInstanceState;	// 클래스 인스턴스의 상태 값
	HANDLE				m_hNetIoThread;		// UDP IO 스레드 핸들

	CSockAddr			m_addr;				
	SOCKET				m_sdHost;
	ulong				m_nMaxSyncLatency;
	ulong				m_nMaxRTO;
	ulong				m_nMaxWaitingAckQSize;

	CList< CUdpHost >	m_listHost;

public:
	CUdpHandler();
	virtual ~CUdpHandler();

	bool Init( CSockAddr *pAddr,
			   uint nMaxSyncLatency = UDP_DEF_SYNC_LATENCY,
			   uint nMaxRTO = UDP_DEF_RTO,
			   uint nMaxWaitingAckQSize = UDP_DEF_WAITING_ACK_Q_SIZE );
	void Uninit();

	bool Poll( CUdpHost **ppHost, ushort *pState, char *pBuf, uint *pBufLen );
	void Send( CUdpHost *pHost, char *pBuf, uint nBufLen );

	CUdpHost * InsertHost( CSockAddr *pAddr, void *pHostData = NULL );
	bool DeleteHost( CSockAddr *pAddr );
	
	CUdpHost * GetHost( CSockAddr *pAddr );
	void SetHostData( CUdpHost *pHost, void *pHostData );

protected:
	void ProcessInput();	// NetIoThread 안에서 호출되는 내부 함수
	void ProcessOutput();	

	static uint __stdcall NetIoThread( void *pContext );
	static int  __cbCompareHost( void *pArg, CUdpHost *pFirst, CUdpHost *pSecond );

#ifdef __UDP_DEBUG__
public:
	ulong	m_nPacketLoseProbability;

	void SetPacketLoseProbability( ulong nPacketLoseProbability )
	{
		m_nPacketLoseProbability = nPacketLoseProbability;
	}
#endif
};


#endif


