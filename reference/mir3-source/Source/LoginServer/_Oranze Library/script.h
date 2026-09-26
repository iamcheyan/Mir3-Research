

#ifndef __ORA_FILE_SCRIPT__
#define __ORZ_FILE_SCRIPT__


#include "file.h"
#include "list.h"


#define SCRIPT_MAXLINE		2048
#define SCRIPT_MAXNAME		128
#define SCRIPT_MAXVALUE		1024
#define SCRIPT_MAXARRAY		256
#define SCRIPT_MAXARRAYITEM	256

#define SCRIPT_INT			0
#define SCRIPT_STRING		1
#define SCRIPT_ARRAY		2


class CScriptArray
{
public:
	int  m_nItemCount;
	char m_szItems[SCRIPT_MAXARRAY][SCRIPT_MAXARRAYITEM];

public:
	CScriptArray();
	virtual ~CScriptArray();

	int  GetItemCount();
	char * GetItem( int nArray );
	char * operator[]( int nArray );
};


class CScript : public CFile
{
protected:
	struct SCRIPT_NODE
	{
		char szName[SCRIPT_MAXNAME];
		void *pValue;
		int  nType;
	};

	CList< SCRIPT_NODE > m_listNode;
	static int CompareNode( void *pArg, SCRIPT_NODE *pFirst, SCRIPT_NODE *pSecond );

public:
	CScript();
	virtual ~CScript();

	bool Open( char *pFile );
	bool Set( char *pName, void *pValue, int nType );
	bool Parse();

protected:
	void ParseArray( char *pValue, CScriptArray *pArray );
};


#endif