

#ifndef __MIR2_EI_MSG_FILTER__
#define __MIR2_EI_MSG_FILTER__


#define MSGFILTER_MAXNODE	1024
#define MSGFILTER_MAXABUSE	12


class CMsgFilter
{
public:
	char m_listAbuse[MSGFILTER_MAXNODE][MSGFILTER_MAXABUSE];
	int  m_nCnt;

public:
	CMsgFilter();
	virtual ~CMsgFilter();

	bool Init( char *pPath );
	void Uninit();

	void Filter( char *pMsg );
};


#endif