

#ifndef __ORZ_MIR2_LOGIN_GATE__
#define __ORZ_MIR2_LOGIN_GATE__


#include <netiocp.h>
#include "dbtable.h"
#include <indexmap.h>
#include "../common/endecode.h"


#define MAX_GATEUSER_HASHSIZE	1000


struct sGateUser
{
	int		nGateSocket;		// User's LoginGate Socket
	char	szUserHandle[25];	// User's Socket in LoginGate (HashKey!)

	char	szID[25];
	char	szAddr[20];
	char	szSsno[20];
	BYTE	nPayMode;			// 과금모드  0:체험판, 1:유료, 2:무료이용자

	int		nClientVersion;
	int		nCertification;

	DWORD	nPassFailTime;
	int		nPassFailCount;
	bool	bVersionAccept;
	bool	bSelServerOK;		// 해킹 방지

	//개인 정액 사용자관련
	DWORD	dwValidFrom;
	DWORD	dwValidUntil;
	DWORD	dwMValidFrom;
	DWORD	dwMValidUntil;
	
	//개인 정량 사용자관련
	DWORD	dwSeconds;
	DWORD	dwMSeconds;

	///////////////////////////////////////
	//무료 정액 사용자관련(2004/06/07)
	DWORD	dwFreeValidFrom;
	DWORD	dwFreeValidUntil;
	DWORD	dwFreeMValidFrom;
	DWORD	dwFreeMValidUntil;
	
	///////////////////////////////////////
	//무료 정량 사용자관련(2004/06/07)
	DWORD	dwFreeSeconds;
	DWORD	dwFreeMSeconds;

	//게임방 정액관련
	DWORD	dwIpValidFrom;
	DWORD	dwIpValidUntil;
	DWORD	dwIpMValidFrom;
	DWORD	dwIpMValidUntil;

	//게임방 정량관련
	long	dwIpSeconds;
	long	dwIpMSeconds;
//	DWORD	dwIpSeconds;
//	DWORD	dwIpMSeconds;

	//제재관련
	DWORD	dwStopUntil;
	DWORD	dwMStopUntil;

	DWORD	dwMakeTime;
	DWORD	dwOpenTime;

	BYTE	nAvailableType;
	bool	bFreeMode;

	int		nServerID;
	int		nParentCheck;
};


class CLoginGate : public CIocpObject
{
public:
	enum { CLASSID = IOCP_OBJECT_CLASSID_0 + 3 };

	sTblPubIP	m_dbInfo;
	int			m_nCntInvalidPacket;

	CIndexMap< sGateUser >	m_listUser;

public:
	CLoginGate( SOCKET sdClient, sTblPubIP *pGateInfo );
	virtual ~CLoginGate();

	//
	// DB Server -> RunGate
	//
	bool SendKickUser( sGateUser *pUser );
	bool SendResponse( sGateUser *pUser, 
					   int nPacketID, 
					   int nRecog = 0, int nParam = 0, int nTag = 0, int nSeries = 0, char *pData = NULL );
	
	//
	// Data 패킷('A') Handler
	//
	bool OnIdPassword( sGateUser *pUser, char *pBody, _TDEFAULTMESSAGE msg );
	bool OnSelectServer( sGateUser *pUser, char *pBody, _TDEFAULTMESSAGE msg );
	bool OnProtocol( sGateUser *pUser, char *pBody, _TDEFAULTMESSAGE msg );

	//
	// LoginGate -> LoginServer
	//
	bool OnKeepAlive();
	bool OnUserData( char *pBody );
	bool OnUserOpen( char *pBody );
	bool OnUserClose( char *pBody );

	//
	// CIocpObject 가상함수 구현
	//
	void OnError( int nErrCode );
	void OnSend( int nTransferred );
	bool OnRecv( char *pPacket, int nPacketLen );
	bool OnExtractPacket( char *pPacket, int *pPacketLen );

	//
	// 기능 구현
	//
	int  GetCertification();


protected:
	static char * __cbGetUserKey( sGateUser *pUser );
};


#endif
