

#include "mir2dbhandler.h"


CDBSvrOdbcPool::CDBSvrOdbcPool()
{
	m_pListConn	= NULL;
	m_nMaxConn	= 0;
	m_nNowCount = 0;

	m_pDSN[0] = '\0';
	m_pID[0]  = '\0';
	m_pPW[0]  = '\0';

}


CDBSvrOdbcPool::~CDBSvrOdbcPool()
{
}


bool CDBSvrOdbcPool::Startup( char *pDSN, char *pID, char *pPW, int nMaxConn )
{
	strcpy ( m_pDSN , pDSN );
	strcpy ( m_pID  , pID  );
	strcpy ( m_pPW  , pPW  ); 

	if ( !Init() )
		return false;

	if ( !nMaxConn )
	{
		SYSTEM_INFO sysInfo;
		GetSystemInfo( &sysInfo );

		nMaxConn = sysInfo.dwNumberOfProcessors * 8; 
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


#ifdef _DEBUG
static long g_nAllocCount;
#endif


CConnection * CDBSvrOdbcPool::Alloc()
{
	Lock();

	for ( int i = 0; i < m_nMaxConn; i++ )
	{
		// 차례대로 돌아가자 
		m_nNowCount++;
		m_nNowCount %= m_nMaxConn;

		if ( !m_pListConn[m_nNowCount].bUsing )
		{
			if ( NULL == m_pListConn[m_nNowCount].pConn )
			{
				m_pListConn[m_nNowCount].bUsing = true;
				continue;
			}

#ifdef _DEBUG
			InterlockedIncrement( &g_nAllocCount );
			
			char __szMsg[256];
			wsprintf( __szMsg, "현재 할당된 ODBC 커넥션: %d 개\n", g_nAllocCount );
			OutputDebugString( __szMsg );
#endif

			m_pListConn[m_nNowCount].bUsing = true;
			
			Unlock();
			return m_pListConn[m_nNowCount].pConn;
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
#ifdef _DEBUG
			InterlockedDecrement( &g_nAllocCount );
			
			char __szMsg[256];
			wsprintf( __szMsg, "현재 할당된 ODBC 커넥션: %d 개\n", g_nAllocCount );
			OutputDebugString( __szMsg );
#endif
			m_pListConn[i].bUsing = false;

			Unlock();
			return;
		}
	}

	Unlock();
}

void CDBSvrOdbcPool::ReConnect( CConnection *pConn )
{
	Lock();

	for ( int i = 0; i < m_nMaxConn; i++ )
	{
		if ( m_pListConn[i].pConn == pConn )
		{
			m_pListConn[i].bUsing = true;
			
			DestroyConnection( m_pListConn[i].pConn );

			pConn = NULL;

			m_pListConn[i].pConn = CreateConnection( m_pDSN, m_pID, m_pPW );
			
			if ( m_pListConn[i].pConn )
			{
				m_pListConn[i].bUsing = false;
			}

			Unlock();
			return;
		}
	}

	Unlock();

}
