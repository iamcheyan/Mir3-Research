

#ifndef __ORZ_THREAD_SYNCHRONIZATION_OBJECT__
#define __ORZ_THREAD_SYNCHRONIZATION_OBJECT__


#include <windows.h>


class CCriticalSection 
{
public:
	CRITICAL_SECTION	m_csAccess;

public:
	CCriticalSection();
	virtual ~CCriticalSection();

	void Lock();
	void Unlock();
};


class CMutex
{
public:
    HANDLE	m_hMutex;

public:
	CMutex( char *pName );
	virtual ~CMutex();

	void Lock( int nTimeWait = INFINITE );
	void Unlock();
};


typedef CCriticalSection	CIntLock;	// InterThread Lock
typedef CMutex				CInpLock;	// InterProcess Lock


#endif