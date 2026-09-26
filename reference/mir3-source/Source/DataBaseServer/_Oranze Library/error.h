

/*
	C++ Exception Processing Class

	Date:
		2001/10/09
*/
#ifndef __ORZ_ERROR__
#define __ORZ_ERROR__


#define ERROR_MAXBUF	1024


class CError
{
protected:
	char	m_szMsg[ERROR_MAXBUF];

public:
	CError( char *pMsg );
	virtual ~CError();

	const char * GetMsg();
};


void _outputerr( char *pMsg, ... );


#endif