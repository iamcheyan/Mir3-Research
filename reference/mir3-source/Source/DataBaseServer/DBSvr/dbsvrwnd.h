

#ifndef __ORZ_MIR2_DBSVR_WINDOW__
#define __ORZ_MIR2_DBSVR_WINDOW__


#include "mir2wnd.h"
#include "dlgcfg.h"
#include "netdbserver.h"


//
// 리스트 컨트롤 텍스트 컬러
//
#define CINFO		RGB(  0,  0,255)
#define CERR		RGB(255,  0,  0)
#define CNORMAL		RGB(  0,  0,  0)
#define CDBG		RGB(255,128, 64)
#define CSEND		RGB( 64, 64,128)
#define CRECV		RGB( 32,128, 64)


class CDBSvrWnd : public CMir2Wnd
{
public:
	SCFG		m_conf;
	CDBServer	m_dbServer;

public:
	CDBSvrWnd();
	virtual ~CDBSvrWnd();

	bool OnInit();
	void OnUninit();
	void OnStartService();
	void OnStopService();
	void OnConfiguration();
	long OnTimer( int nTimerID );
};


CDBSvrWnd		* GetApp();
SCFG			* GetCfg();
CDBServer		* GetDBServer();
CDBSvrOdbcPool	* GetOdbcPool();
CDBSvrOdbcPool  * GetAcntOdbcPool();

#endif