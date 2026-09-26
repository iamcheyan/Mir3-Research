

#ifndef __ORZ_MIR2_DB_CONNECTION_POOL__
#define __ORZ_MIR2_DB_CONNECTION_POOL__


#include <database.h>
#include <syncobj.h>


class CDBSvrOdbcPool : public CDatabase, public CIntLock
{
protected:
	struct sConnection
	{
		CConnection	*pConn;
		bool		bUsing;
	};

protected:
	sConnection	 *m_pListConn;
	int			 m_nMaxConn;
	unsigned int m_nNowCount;

	char m_pDSN[256];
	char m_pID[256];
	char m_pPW[256];

public:
	CDBSvrOdbcPool();
	virtual ~CDBSvrOdbcPool();

	bool Startup( char *pDSN, char *pID, char *pPW, int nMaxConn = 0 );
	void Cleanup();

	CConnection * Alloc();
	void Free( CConnection *pConn );
	void ReConnect( CConnection *pConn );
};


#endif