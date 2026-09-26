

#ifndef __ORZ_MIR2_DB_CONNECTION_POOL__
#define __ORZ_MIR2_DB_CONNECTION_POOL__


#include <database.h>
#include <syncobj.h>


class CDBSvrOdbcPool : public CDatabase, CIntLock
{
protected:
	struct sConnection
	{
		CConnection	*pConn;
		bool		bUsing;
	};

protected:
	sConnection	*m_pListConn;
	int			m_nMaxConn;

public:
	CDBSvrOdbcPool();
	virtual ~CDBSvrOdbcPool();

	bool Startup( char *pDSN, char *pID, char *pPW, int nMaxConn = 0 );
	void Cleanup();

	CConnection * Alloc();
	void Free( CConnection *pConn );
};


#endif