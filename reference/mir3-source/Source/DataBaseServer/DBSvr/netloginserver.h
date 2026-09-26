

#ifndef __ORZ_MIR2_LOGIN_SERVER__
#define __ORZ_MIR2_LOGIN_SERVER__


#include <netiocp.h>
#include "netrungate.h"


class CLoginServer : public CIocpObject
{
public:
	enum { CLASSID = IOCP_OBJECT_CLASSID_0 + 1 };

	int  m_nCntInvalidPacket;


public:
	CLoginServer();
	virtual ~CLoginServer();
	
	//
	// DB Server -> LoginServer
	//
	bool SendUserCount();
	bool SendUserClosed( sGateUserInfo *pUser );
	bool SendRequestPublicKey();

	//
	// LoginServer -> DB Server
	//
	bool OnPasswdSuccess( char *pBody );
	bool OnCancelAdmission( char *pBody );
	bool OnTotalUserCount( char *pBody );
	bool OnRecvPublicKey( char *pBody );

	//
	// CIocpObject 가상함수 구현
	//
	void OnError( int nErrCode );
	void OnSend( int nTransferred );
	bool OnRecv( char *pPacket, int nPacketLen );
	bool OnExtractPacket( char *pPacket, int *pPacketLen );
};


#endif
