#include "stdafx.h"

CIocpAcceptor::CIocpAcceptor()
{
	m_nPort		= 0;
	m_sdHost	= INVALID_SOCKET;	
	m_hThread	= INVALID_HANDLE_VALUE;
}


CIocpAcceptor::~CIocpAcceptor()
{
	if ( m_hThread != INVALID_HANDLE_VALUE )
		Stop();

	if ( m_sdHost != INVALID_SOCKET )
		closesocket( m_sdHost );
}


bool CIocpAcceptor::Start( int nPort )
{
	m_sdHost = socket( AF_INET, SOCK_STREAM, 0 );
	
	if ( m_sdHost == INVALID_SOCKET )
		return false;

	SOCKADDR_IN sdAddr = {AF_INET, htons( nPort ), INADDR_ANY, 0, };

	if ( bind( m_sdHost, (SOCKADDR *) &sdAddr, sizeof( sdAddr ) ) == INVALID_SOCKET )
		return false;

	if ((listen(m_sdHost, 5)) == SOCKET_ERROR)
		return false;

	unsigned nId;
	
	m_hThread = (HANDLE) _beginthreadex( NULL, 0, __tAcceptor, this, 0, &nId );
	
	if ( m_hThread == INVALID_HANDLE_VALUE )
		return false;

	return true;
}


void CIocpAcceptor::Stop()
{
	TerminateThread( m_hThread, 0 );
	CloseHandle( m_hThread );

	m_hThread = INVALID_HANDLE_VALUE;
}


unsigned CIocpAcceptor::__tAcceptor( void *pContext )
{
	((CIocpAcceptor *) pContext)->__tcAcceptor();

	return 0;
}


void CIocpAcceptor::__tcAcceptor()
{
	SOCKET				sdClient;
	SOCKADDR_IN			Address;

	int					nLen = sizeof(SOCKADDR_IN);

	while ( true )
	{
		sdClient = accept( m_sdHost, (struct sockaddr FAR *)&Address, &nLen );

		OnAccept( sdClient, &Address );
	}
}
