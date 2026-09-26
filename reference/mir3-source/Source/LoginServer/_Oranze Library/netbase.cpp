

#include "netbase.h"
#include <stdlib.h>


CNetBase::CNetBase()
{
	if ( WSAStartup( NET_WINSOCK_VERSION, &m_WsaData ) != NULL )
		throw CError( "CNetBase::CNetBase() WSAStartup 실패" );
}


CNetBase::~CNetBase()
{
	if ( WSACleanup() != NULL )
		throw CError( "CNetBase::~CNetBase() WSACleanup 실패" );
}


void CNetBase::EnumLocalNIC( void (*pfnEnum)( void *pContext, char *pIP ), void *pContext )
{
	char szHostName[256];
	if ( gethostname( szHostName, sizeof( szHostName ) ) != NULL )
		return;

	HOSTENT *pHost = gethostbyname( szHostName );

	if ( pHost->h_addrtype == AF_INET )
	{
		for ( int i = 0; pHost->h_addr_list[i]; i++ )
			pfnEnum( pContext, inet_ntoa( *((in_addr *) pHost->h_addr_list[i]) ) );
	}
}




CSockAddr::CSockAddr()
{
	memset( this, 0, sizeof( SOCKADDR ) );
}


CSockAddr::CSockAddr( ushort nPort )
{
	memset( this, 0, sizeof( SOCKADDR ) );

	((SOCKADDR_IN *) this)->sin_family		= AF_INET;
	((SOCKADDR_IN *) this)->sin_addr.s_addr	= INADDR_ANY;
	((SOCKADDR_IN *) this)->sin_port		= htons( nPort );
}


CSockAddr::CSockAddr( const char *pAddr, ushort nPort )
{
	memset( this, 0, sizeof( SOCKADDR ) );

	((SOCKADDR_IN *) this)->sin_family = AF_INET;

	if ( IsIP( pAddr ) )
	{
		((SOCKADDR_IN *) this)->sin_addr.s_addr	= inet_addr( pAddr );
	}
	else
	{
		HOSTENT *pHE = gethostbyname( pAddr );
		if ( pHE )
			((SOCKADDR_IN *) this)->sin_addr.s_addr = *((ulong *) pHE->h_addr_list[0]);
	}

	((SOCKADDR_IN *) this)->sin_port = htons( nPort );
}


CSockAddr::CSockAddr( const char *pAddr, const char *pPort )
{
	memset( this, 0, sizeof( SOCKADDR ) );

	((SOCKADDR_IN *) this)->sin_family = AF_INET;

	if ( IsIP( pAddr ) )
	{
		((SOCKADDR_IN *) this)->sin_addr.s_addr	= inet_addr( pAddr );
	}
	else
	{
		HOSTENT *pHE = gethostbyname( pAddr );
		if ( pHE )
			((SOCKADDR_IN *) this)->sin_addr.s_addr = *((ulong *) pHE->h_addr_list[0]);
	}

	((SOCKADDR_IN *) this)->sin_port = htons( atoi( pPort ) );	
}


CSockAddr::~CSockAddr()
{
}


char * CSockAddr::IP()
{
	return inet_ntoa( ((SOCKADDR_IN *) this)->sin_addr );
}


ushort CSockAddr::Port()
{
	return ntohs( ((SOCKADDR_IN *) this)->sin_port );
}


CSockAddr & CSockAddr::operator = ( CSockAddr &rSockAddr )
{
	memcpy( this, &rSockAddr, sizeof( SOCKADDR ) );

	return *this;
}


CSockAddr & CSockAddr::operator = ( SOCKADDR &rSockAddr )
{
	memcpy( this, &rSockAddr, sizeof( SOCKADDR ) );

	return *this;
}


bool CSockAddr::operator == ( CSockAddr &rSockAddr )
{
	char szIP[NET_MAXIP];
	lstrcpy( szIP, IP() );

	return (lstrcmp( szIP, rSockAddr.IP() ) == 0 && Port() == rSockAddr.Port());
}


bool CSockAddr::operator == ( SOCKADDR &rSockAddr )
{
	char szIP[NET_MAXIP];
	lstrcpy( szIP, IP() );

	return (lstrcmp( szIP, inet_ntoa( ((SOCKADDR_IN *) &rSockAddr)->sin_addr ) ) == 0 && Port() == ntohs( ((SOCKADDR_IN *) &rSockAddr)->sin_port ));
}


bool CSockAddr::operator != ( CSockAddr &rSockAddr )
{
	char szIP[NET_MAXIP];
	lstrcpy( szIP, IP() );

	return (lstrcmp( szIP, rSockAddr.IP() ) != 0 || Port() != rSockAddr.Port());
}


bool CSockAddr::operator != ( SOCKADDR &rSockAddr )
{
	char szIP[NET_MAXIP];
	lstrcpy( szIP, IP() );

	return (lstrcmp( szIP, inet_ntoa( ((SOCKADDR_IN *) &rSockAddr)->sin_addr ) ) != 0 || Port() != ntohs( ((SOCKADDR_IN *) &rSockAddr)->sin_port ));
}


bool CSockAddr::IsIP( const char *pAddr )
{
	int nLen = strlen( pAddr );

	for ( int i = 0; i < nLen; i++ )
	{
		if ( pAddr[i] == '.' )
			continue;

		if ( pAddr[i] < '0' || pAddr[i] > '9' )
			return false;
	}

	return true;
}