

/*
	Winsock TCP/IP Base Class

	Date:
		2001/10/09
*/
#ifndef __ORZ_NETWORK_BASE__
#define __ORZ_NETWORK_BASE__


#include "datatype.h"
#include <winsock2.h>
#include "error.h"


#define NET_WINSOCK_VERSION		0x0202
#define NET_MAXIP				16


class CNetBase
{
protected:
	WSADATA	m_WsaData;

public:
	CNetBase();
	virtual ~CNetBase();

	void	EnumLocalNIC( void (*pfnEnum)( void *pContext, char *pIP ), void *pContext );
};


class CSockAddr : public SOCKADDR
{
public:
	CSockAddr();
	CSockAddr( ushort nPort );
	CSockAddr( const char *pAddr, ushort nPort );
	CSockAddr( const char *pAddr, const char *pPort );
	~CSockAddr();

	char	* IP();
	ushort	Port();

	operator CSockAddr * ()				{ return this; }
	operator const CSockAddr * () const	{ return (const CSockAddr *) this; }
	operator SOCKADDR * ()				{ return (SOCKADDR *) this; }
	operator const SOCKADDR * () const	{ return (const SOCKADDR *) this; }

	CSockAddr &	operator =  ( CSockAddr &rSockAddr );
	CSockAddr &	operator =  ( SOCKADDR  &rSockAddr );
	bool		operator == ( CSockAddr &rSockAddr );
	bool		operator == ( SOCKADDR  &rSockAddr );
	bool		operator != ( CSockAddr &rSockAddr );
	bool		operator != ( SOCKADDR  &rSockAddr );

public:
	static bool IsIP( const char *pAddr );
};


#endif