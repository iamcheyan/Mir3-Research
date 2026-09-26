

#ifndef __ORZ_MIR2_DB_SERVER__
#define __ORZ_MIR2_DB_SERVER__


#pragma comment( lib, "ws2_32.lib" )


#include <database.h>
#include <netiocp.h>
#include "protocol.h"
#include "netloginserver.h"
#include "netgameserver.h"
#include "netrungate.h"
#include "mir2dbhandler.h"
#include "msgfilter.h"
#include "datelog.h"

#define TIMER_KEEPALIVE				0
#define TIMER_CONNLOGINSERVER		1

#define TIMER_INTERVAL				10000
#define	MAXPLAYSERVER				20

class CServerConnInfo
{
public:
	char	szRemote[32];
	char	szAddr[32];
	int		nPort;
	char	szAddr2[32];
	int		nPort2;
	char	szAddr3[32];
	int		nPort3;
};

class CMapServerInfo
{
public:
	char	szMapName[32];
	int		nServerIndex;
};

class CDBServer : public CIocpHandler
{
private:
	DWORD						m_dwStatusLogTick;
	bool						bRequestPublicKey;


public:
	CMsgFilter					m_msgFilter;

	CDBSvrOdbcPool				m_dbPool;
	CDBSvrOdbcPool				m_AcntDBPool;

	CLoginServer				m_loginServer;
	CIocpAcceptor				m_gsAcceptor;	
	CSList< CGameServer >		m_listGameServer;
	CIocpAcceptor				m_rgAcceptor;
	CSList< CRunGate >			m_listRunGate;

	CSList< sAdmission >		m_listAdmission;

	CServerConnInfo				m_ServerConnInfo[MAXPLAYSERVER];
	CSList< CMapServerInfo >	m_listMapServerInfo;

	CDateLog					m_Log;
	CDateLog					m_TransLog;

public:
	CDBServer();
	virtual ~CDBServer();

	bool Startup();
	void Cleanup();

	//
	// CIocpHandler 가상함수 구현
	//
	void			OnError( int nErrCode );
	CIocpObject *	OnAccept( CIocpAcceptor *pAcceptor, SOCKET sdClient );
	void			OnAcceptError( CIocpAcceptor *pAcceptor, int nErrCode );
	bool			OnConnect( CIocpObject *pObject );
	void			OnConnectError( CIocpObject *pObject, int nErrCode );
	void			OnClose( CIocpObject *pObject );

	bool			InitServerInfo(char *pszFilePath);
	bool			InitMapServerInfo(char *pszFilePath);

	int				GetServerFromMap(char *pszMapName);
	char			*GetRunServerAddr(char *pszRemote);
	int				GetRunServerPort(char *pszRemote);
	//
	// 윈도우 타이머
	//
	void OnTimer( int nTimerID );

	//
	// DB Server 동작 구현
	//
	bool InsertAdmission( char *pID, int nCert, int nPayMode );
	bool RemoveAdmission( char *pID, int nCert );
	bool IsRegisteredAdmission( char *pID, int nCert );
	bool IsSelectedAdmission( int nCert );
	bool CheckSelectedAdmission( int nCert );
	bool IsRegisteredUserId( char *pID );

	int m_MegaFreeSpase;
	int GetFreeDiskSpace( char *szDirectoryName );


protected:
	static void	__cbDBMsg( char *pState, int nErrCode, char *pDesc );
	static int	__cbCmpGameServer( void *pArg, CGameServer *pFirst, CGameServer *pSecond );
	static int	__cbCmpRunGate( void *pArg, CRunGate *pFirst, CRunGate *pSecond );
	static int	__cbCmpAdmission( void *pArg, sAdmission *pFirst, sAdmission *pSecond );
	static int	__cbCmpServerFromMap( void *pArg, CMapServerInfo *pFirst, CMapServerInfo *pSecond );
};


#endif
