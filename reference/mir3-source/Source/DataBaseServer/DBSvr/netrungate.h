

#ifndef __ORZ_MIR2_RUN_GATE__
#define __ORZ_MIR2_RUN_GATE__


#include <netiocp.h>
#include <list.h>


struct sGateUserInfo
{
	int  nHandle;
	int  nCert;
	char szID[21]; // 10 -> 21
	char szAddr[20];
	long nConnectTime;
	long nLastCmdTime;
	bool bQueryChrFinished;
	bool bSelChrFinished;
};


class CRunGate : public CIocpObject
{
public:
	enum { CLASSID = IOCP_OBJECT_CLASSID_0 + 3 };

	int  m_nCntInvalidPacket;
	
	CList< sGateUserInfo > m_listUser;
	
public:
	CRunGate( SOCKET sdClient );
	virtual ~CRunGate();

	int is_hangul(BYTE *str);

	//
	// DB Server -> RunGate
	//
	bool SendResponse( int nHandle, 
					   int nPacketID, 
					   int nRecog = 0, int nParam = 0, int nTag = 0, int nSeries = 0, 
					   char *pData = NULL );

	//
	// Data 패킷('A') Handler
	//
	bool OnQueryChr( sGateUserInfo *pUser, char *pBody );
	bool OnNewChr( sGateUserInfo *pUser, char *pBody );
	bool OnDelChr( sGateUserInfo *pUser, char *pBody );
	bool OnSelChr( sGateUserInfo *pUser, char *pBody );

	//
	// RunGate -> DB Server
	//
	bool OnCheckCode( char *pBody );
	bool OnUserOpen( char *pBody );
	bool OnUserClose( char *pBody );
	bool OnUserData( char *pBody );

	//
	// CIocpObject 가상함수 구현
	//	
	void OnError( int nErrCode );
	void OnSend( int nTransferred );
	bool OnRecv( char *pPacket, int nPacketLen );
	bool OnExtractPacket( char *pPacket, int *pPacketLen );
	
	//
	// 동작 구현
	//
	bool IsValidData( char *pData, int nDataLen );
	bool InsertUser( int nHandle, char *pAddr );
	bool RemoveUser( int nHandle );

protected:
	static int __cbCmpUserInfo( void *pArg, sGateUserInfo *pFirst, sGateUserInfo *pSecond );
};


#endif
