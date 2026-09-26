

/*
	DateLog Class

	Date:
		2002/06/27
*/
#ifndef __ORZ_FILE_DATALOG__
#define __ORZ_FILE_DATALOG__


#include "file.h"
#include <windows.h>


class CDateLog : public CFile
{
public:
	char m_szInitial[MAX_PATH];
	char m_szDir[MAX_PATH];
	char m_szFilePath[MAX_PATH];

	SYSTEMTIME m_sysTime;

public:
	CDateLog();
	virtual ~CDateLog();

	bool Create( char *pInitial, char *pDir = NULL );
	bool Log( char *pText, bool bWithCRLF = false );

	bool CreateLogFile();
};


#endif