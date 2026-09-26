

#ifndef __ORZ_MIR2_LOGIN_SERVER__
#define __ORZ_MIR2_LOGIN_SERVER__


#pragma comment( lib, "ws2_32.lib" )


#include "../_Oranze Library/database.h"
#include "../_Oranze Library/netiocp.h"
#include <indexmap.h>
#include "dbtable.h"
#include "mir2dbhandler.h"
#include "protocol.h"
#include "netcheckserver.h"
#include "netgameserver.h"
#include "netlogingate.h"
#include <datelog.h>
#include "netUdpsender.h"     



#define MAX_HASHSIZE		1000


struct sCertUser
{
	char	szLoginID[21];
	char	szUserAddr[16];
	char	szServerName[20];
	bool	bFreeMode;
	int		nCertification;
	DWORD	nOpenTime;
	DWORD	nAccountCheckTime;
	bool	bClosing;

	BYTE	nAvailableType;
	int		nIDDay;
	unsigned	int		nIDHour;
	int		nIPDay;
	int		nIPHour;	
};

class CGameServerInfo
{
public:
	char szName[21];
	int		nMaxUserCount;
	int		nFreemode;
	int		nGateCount;
	int		nCurrentIndex;	

	CSList<sTblSelectGateIP>	m_listSelectGate;

public:
	CGameServerInfo();

	sTblSelectGateIP* GetSelectGate();
};


class CLoginSvr : public CIocpHandler
{
public:
	CDBSvrOdbcPool			m_dbPool;
	CDBSvrOdbcPool			m_dbPoolPC;
	CList< sTblSvrIP >		m_listServerIP;
	CList< sTblPubIP >		m_listGateIP;
	CList< CGameServerInfo>  m_listServerInfo;

	CSList< CCheckServer >	m_listCheckServer;
	CIocpAcceptor			m_csAcceptor;
	CSList< CGameServer >	m_listGameServer;
	CIocpAcceptor			m_gsAcceptor;
	CSList< CLoginGate >	m_listLoginGate;
	CIocpAcceptor			m_lgAcceptor;

	CIndexMap< sCertUser >	m_listCert;
	CIntLock				m_csListCert;
	CUdpsender				m_udpSender; // udp를 통해 데이터 전송

	int			m_nTotalCount;
	int			m_nMaxTotalUserCount;
	CHAR		m_szGameType[10];		
	int			m_nFreePeriods;
	bool		m_IsNotInServiceMode;

	CDateLog	m_log;
	CDateLog	m_log2;

	//0번 에러 발생시 체크서버에 응답없음 통보 여부.(2004/08/18)
	bool		m_bSendErrorToCheckServer;

public:
	CLoginSvr();
	virtual ~CLoginSvr();

	bool Startup();
	void Cleanup();

	//
	// CIocpHandler 가상함수 구현
	//
	void			OnError( int nErrCode );
	CIocpObject *	OnAccept( CIocpAcceptor *pAcceptor, SOCKET sdClient );
	void			OnAcceptError( CIocpAcceptor *pAcceptor, int nErrCode );
	void			OnClose( CIocpObject *pObject );

	//
	// 윈도우 타이머
	//
	void OnTimer( int nTimerID );

	//
	// 기능 구현
	//
	bool LoadDBTables();
	sTblSvrIP * FindServerInfo( SOCKET sdPeer );
	sTblPubIP * FindGateInfo( SOCKET sdPeer );

	bool AddCertUser( sGateUser *pUser );
	void DelCertUser( sGateUser *pUser );

	bool SaveCountLog();
	bool WriteConLog(char *pszLoginid, char *pszIP);
	int	 GetTotalUserCount();
	int  RecalUserCount(char *pszServerName);
	void CheckCertListTimeOuts();
	void CheckAccountExpire();
	void CheckDupIPs();
	bool SendCancelAdmissionUser( sCertUser *pCert );
	bool SendAccountExpireUser( sCertUser *pCert );
	//아이디 체크하는 함수
	bool CheckBadAccount(char szLoginid[30]);


protected:
	static void	__cbDBMsg( char *pState, int nErrCode, char *pDesc );
	static int	__cbCmpCheckServer( void *pArg, CCheckServer *pFirst, CCheckServer *pSecond );
	static int	__cbCmpGameServer( void *pArg, CGameServer *pFirst, CGameServer *pSecond );
	static int	__cbCmpLoginGate( void *pArg, CLoginGate *pFirst, CLoginGate *pSecond );
	static char * __cbGetCertKey( sCertUser *pObj );
};


#endif
