

#include "codebase.h"


static Code4	g_codeBase;


void CCodeBase::Startup()
{
	g_codeBase.errOpen		= 0;
	g_codeBase.safety		= 0;
	g_codeBase.lockEnforce	= 0;
	
}


void CCodeBase::Cleanup()
{
	g_codeBase.closeAll();
	g_codeBase.initUndo();
}


CCodeBase::CCodeBase()
{
}


CCodeBase::~CCodeBase()
{
}


bool CCodeBase::Open( char *pPath )
{
	return open( g_codeBase, pPath ) == r4success;
}


bool CCodeBase::Create( char *pPath, CFieldList *pFieldList, CIndexList *pIndexList )
{
	if ( pIndexList == NULL )
		return create( g_codeBase, pPath, *pFieldList ) == r4success;
	else
		return create( g_codeBase, pPath, *pFieldList, *pIndexList ) == r4success;
}


bool CCodeBase::Bind( char *pName, CField *pObject )
{
	return pObject->init( *this, pName ) == r4success;
}


bool CCodeBase::Bind( int nNum, CField *pObject )
{
	return pObject->init( *this, nNum ) == r4success;
}


bool CCodeBase::Bind( char *pName, CIndex *pObject )
{
	return pObject->init( *this, pName ), true;
}


void CCodeBase::Select()
{
	select();
}


void CCodeBase::Select( CIndex *pIndex )
{
	select( *pIndex );
}


void CCodeBase::Select( char *pString )
{
	select( pString );
}


bool CCodeBase::Top()
{
	return top() == r4success;
}


bool CCodeBase::Bottom()
{
	return bottom() == r4success;
}


bool CCodeBase::Skip( int nSkipNumber )
{
	return skip( nSkipNumber ) == r4success;
}


bool CCodeBase::Go( int nRecordNumber )
{
	return go( nRecordNumber ) == r4success;
}


bool CCodeBase::Search( char *pString )
{
	return seek( pString ) == r4success;
}


bool CCodeBase::SearchNext( char *pString )
{
	return seekNext( pString ) == r4success;
}


void CCodeBase::InsertStart()
{
	// lock change permission
	lockAll();
	// make record buffer
	appendStart();
	// set record buffer to spaces (changed flag: on, deleted flag: off)
	blank();
}


bool CCodeBase::Insert()
{
	// create new record using current fields
	int nRetCode = append();
	// unlock permission
	unlock();

	return nRetCode == r4success;
}


bool CCodeBase::Delete( int nRecordNumber, bool bPack )
{
	if ( nRecordNumber < 0 )
	{
		// delete current record
		deleteRec();
	}
	else
	{
		// move record
		if ( go( nRecordNumber ) != r4success )
			return false;

		deleteRec();
	}

	if ( bPack )
	{
		// physically removes all records marked for deletion
		return pack() == r4success;
	}

	return true;
}


bool CCodeBase::Pack()
{
	return pack() == r4success;
}


/*
	Compress()

	Warning! this function can be elapsed for a long time.
*/
bool CCodeBase::Compress()
{
	// the memo file(binary file) corresponding to the data file is compressed.
	// if the data file has no memo file, nothing happens.
	return memoCompress() == r4success;
}


int CCodeBase::RecNo()
{
	return recNo();
}


int CCodeBase::GetCols()
{
	return numFields();
}


int CCodeBase::GetRowCount()
{
	return recCount();
}




CField::CField( CCodeBase &rDB, char *pName )
{
	init( rDB, pName );
}


CField::CField( CCodeBase &rDB, int nField )
{
	init( rDB, nField );
}


bool CField::Assign( char *pString )
{
	return assign( pString ? pString : "" ) == r4success;
}


bool CField::Assign( int nNumber )
{
	char szTemp[12];
	_itoa( nNumber, szTemp, 10 );

	return Assign( szTemp );
}


bool CField::Assign( char *pBuf, int nLen )
{
	if ( pBuf == NULL )
		return Assign( NULL );
	else
		return assign( pBuf, nLen ) == r4success;
}


CField * CField::operator = ( char *pString )
{
	return Assign( pString ) ? this : NULL;
}


CField * CField::operator = ( int nNumber )
{
	return Assign( nNumber ) ? this : NULL;
}




CFieldList::CFieldList()
: Field4info( g_codeBase )
{
}


CFieldList::~CFieldList()
{
}


bool CFieldList::Insert( char *pFieldName, int nType, int nLength )
{
	return add( pFieldName, nType, nLength ) == r4success;
}




CIndex::CIndex( CCodeBase &rDB, char *pName )
{
	init( rDB, pName );
}


CIndexList::CIndexList()
: Tag4info( g_codeBase )
{
}


CIndexList::~CIndexList()
{
}


bool CIndexList::Insert( char *pIndexName, 
						 char *pFieldExpression,
						 char *pFilter,
						 bool bUnique,
						 bool bDescending )
{
	return add( pIndexName, pFieldExpression, pFilter, bUnique ? r4unique : 0, bDescending ) == r4success;
}
