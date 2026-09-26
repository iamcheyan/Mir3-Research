

#ifndef __ORZ_MIR2_CHECK_SERVER__
#define __ORZ_MIR2_CHECK_SERVER__


#include "../_Oranze Library/netiocp.h"


class CCheckServer : public CIocpObject
{
public:
	enum { CLASSID = IOCP_OBJECT_CLASSID_0 + 1 };

public:
	CCheckServer( SOCKET sdClient );
	virtual ~CCheckServer();

	//
	// CLoginSvr -> CCheckServer
	//
	bool SendServerStatus();

	//
	// CIocpObject 가상함수 구현
	//
	void OnError( int nErrCode );
	void OnSend( int nTransferred );
	bool OnRecv( char *pPacket, int nPacketLen );
	bool OnExtractPacket( char *pPacket, int *pPacketLen );
};


#endif