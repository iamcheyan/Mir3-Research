


/*
	Registry Class

	Date:
		2001/04/12

	Note:
		간단한 레지스트리 I/O 클래스
*/

#ifndef __ORZ_MISC_REGISTRY__
#define __ORZ_MISC_REGISTRY__


#include <windows.h>


#define MAXREGKEY	1024


class CRegistry
{
protected:
	HKEY	m_hKey;

public:
	CRegistry();
	virtual ~CRegistry();

	bool OpenKey( char *pKeyName );
	bool CloseKey();

	bool SetInteger( char *pValueName, int nValueInt );
	bool SetString( char *pValueName, char *pValueString );

	bool GetInteger( char *pValueName, int *pValueInt );
	bool GetString( char *pValueName, char *pValueString, int nValueStringLen );
};


#endif