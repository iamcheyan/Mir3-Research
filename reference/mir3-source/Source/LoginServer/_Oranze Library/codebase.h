


/*
	CodeBase Wrapper Class (SEQUITER Software Inc.)

	Date:
		2001/12/13
*/

#ifndef __ORZ_CODEBASE__
#define __ORZ_CODEBASE__


#include "_link/codebase/d4all.hpp"


#define CB_NUMBER	r4num
#define CB_CHAR		r4str
#define CB_VARCHAR	r4memo	
#define CB_BINARY	r4memo	
#define CB_DATE		r4date	


class CField;
class CFieldList;
class CIndex;
class CIndexList;


class CCodeBase : public Data4
{
public:
	static void Startup();
	static void Cleanup();

public:
	CCodeBase();
	virtual ~CCodeBase();

	bool Open  ( char *pPath );
	bool Create( char *pPath, CFieldList *pFieldList, CIndexList *pIndexList = NULL );
	bool Bind  ( char *pName, CField *pObject );
	bool Bind  ( int   nNum,  CField *pObject );
	bool Bind  ( char *pName, CIndex *pObject );

	// moving between records
	void Select();
	void Select( CIndex *pIndex );
	void Select( char *pIndexName );
	bool Top();
	bool Bottom();
	bool Skip( int nSkipNumber = 1 );
	bool Go( int nRecordNumber );
	bool Search( char *pString );
	bool SearchNext( char *pString );
	
	// records I/O (using current binding fields)
	void InsertStart();
	bool Insert();
	bool Delete( int nRecordNumber = -1, bool bPack = false );
	bool Pack();
	bool Compress();

	int  RecNo();
	int  GetCols();
	int  GetRowCount();
};


class CField : public Field4memo
{
public:
	CField() {}
	CField( CCodeBase &rDB, char *pName );
	CField( CCodeBase &rDB, int nField );

	bool Assign( char *pString );
	bool Assign( int   nNumber );
	bool Assign( char *pBuf, int nLen );
	
	CField * operator = ( char *pString );
	CField * operator = ( int   nNumber );
};


class CFieldList : public Field4info
{
public:
	CFieldList();
	virtual ~CFieldList();

	bool Insert( char *pFieldName,
				 int  nType,
				 int  nLength = 0 );
};


class CIndex : public Tag4
{
public:
	CIndex() {}
	CIndex( CCodeBase &rDB, char *pName );
};


class CIndexList : public Tag4info
{
public:
	CIndexList();
	virtual ~CIndexList();

	bool Insert( char *pIndexName, 
				 char *pFieldExpression, 
				 char *pFilter		= NULL, 
				 bool bUnique		= false,
				 bool bDescending	= false );
};


#endif