

#include "mir2dbhandler.h"
#include "loginsvrwnd.h"


CDBSvrOdbcPool::CDBSvrOdbcPool()
{
	m_pListConn	= NULL;
	m_nMaxConn	= 0;
}


CDBSvrOdbcPool::~CDBSvrOdbcPool()
{
}


bool CDBSvrOdbcPool::Startup( char *pDSN, char *pID, char *pPW, int nMaxConn )
{
	if ( !Init() )
		return false;

	if ( !nMaxConn )
	{
		SYSTEM_INFO sysInfo;
		GetSystemInfo( &sysInfo );

		nMaxConn = sysInfo.dwNumberOfProcessors * 4;
	}

	m_pListConn = new sConnection[ nMaxConn ];
	if ( !m_pListConn )
		return false;

	memset( m_pListConn, 0, sizeof( sConnection ) * nMaxConn );

	m_nMaxConn = nMaxConn;

	for ( int i = 0; i < m_nMaxConn; i++ )
	{
		m_pListConn[i].pConn = CreateConnection( pDSN, pID, pPW );
		if ( !m_pListConn[i].pConn )
			return false;

		m_pListConn[i].bUsing = false;
	}

	return true;
}


void CDBSvrOdbcPool::Cleanup()
{
	if ( m_pListConn )
	{
		for ( int i = 0; i < m_nMaxConn; i++ )
		{
			if ( m_pListConn[i].pConn )
				DestroyConnection( m_pListConn[i].pConn );
		}

		delete[] m_pListConn;
		m_pListConn	= NULL;
		m_nMaxConn	= 0;
	}

	Uninit();
}


CConnection * CDBSvrOdbcPool::Alloc()
{
	Lock();

	for ( int i = 0; i < m_nMaxConn; i++ )
	{
		if ( !m_pListConn[i].bUsing )
		{
			m_pListConn[i].bUsing = true;

			Unlock();
			return m_pListConn[i].pConn;
		}
	}

	Unlock();

	return NULL;
}


void CDBSvrOdbcPool::Free( CConnection *pConn )
{
	Lock();

	for ( int i = 0; i < m_nMaxConn; i++ )
	{
		if ( m_pListConn[i].pConn == pConn )
		{
			m_pListConn[i].bUsing = false;

			Unlock();
			return;
		}
	}

	Unlock();
}