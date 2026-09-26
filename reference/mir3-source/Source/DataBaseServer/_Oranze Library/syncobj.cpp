

#include "syncobj.h"
#include "error.h"


CCriticalSection::CCriticalSection()
{
	InitializeCriticalSection( &m_csAccess );
}


CCriticalSection::~CCriticalSection()
{
	DeleteCriticalSection( &m_csAccess );
}


void CCriticalSection::Lock()
{
	EnterCriticalSection( &m_csAccess );
}


void CCriticalSection::Unlock()
{
	LeaveCriticalSection( &m_csAccess );
}




CMutex::CMutex( char *pName )
{
	m_hMutex = CreateMutex( NULL, FALSE, pName );
	if ( m_hMutex == NULL )
		throw CError( "CMutex::CMutex() 뮤텍스 생성 실패" );
}


CMutex::~CMutex()
{
	CloseHandle( m_hMutex );
}


void CMutex::Lock( int nTimeWait )
{
	WaitForSingleObject( m_hMutex, nTimeWait );
}


void CMutex::Unlock()
{
	ReleaseMutex( m_hMutex );
}
