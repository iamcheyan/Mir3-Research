

#include "mail.h"


CMailItem::CMailItem()
{
	m_pNode	= NULL;
}


CMailItem::~CMailItem()
{
}




CMail::CMail()
{
	m_szFrom		= "";
	m_szDate		= "";
	m_szTo			= "";
	m_szSubject		= "";
	m_szContentHtml	= "";
	m_szContentText	= "";
}


CMail::~CMail()
{
	Reset();
}


void CMail::Reset()
{
	CMimeDecoder::Reset();

	m_szFrom.cleanup();
	m_szDate.cleanup();
	m_szTo.cleanup();
	m_szSubject.cleanup();

	m_szContentText.cleanup();
	m_szContentHtml.cleanup();

	m_listFiles.ClearAll( false );
}


bool CMail::Parse( char *pRaw, int nRawLen )
{
	if ( CMimeDecoder::Parse( pRaw, nRawLen ) == false )
		return false;
	
	char		szLine[MIME_MAXLINE];
	CMimeItem	*pItem;

	/*
		Parse Header
	*/
	pItem = GetItem( 0 );

	if ( pItem->QueryHeader( "From", szLine, sizeof( szLine ) ) )
		m_szFrom = szLine;
	if ( pItem->QueryHeader( "Date", szLine, sizeof( szLine ) ) )
		m_szDate = szLine;
	if ( pItem->QueryHeader( "To", szLine, sizeof( szLine ) ) )
		m_szTo = szLine;
	if ( pItem->QueryHeader( "Subject", szLine, sizeof( szLine ) ) )
		m_szSubject = szLine;

	/*
		Parse Body (get contents and attached files)
	*/
	for ( int i = 0; i < GetItemCount(); i++ )
	{
		pItem = GetItem( i );
		
		if ( pItem->m_bFile )
		{
			m_listFiles.Insert( pItem );
			continue;
		}

		if ( pItem->QueryHeader( "Content-Type", szLine, sizeof( szLine ) ) )
		{
			if ( pItem->DataSize() )
			{
				if ( _memistr( szLine, strlen( szLine ), "text/plain" ) )
					m_szContentText = pItem->Data();
				else if ( _memistr( szLine, strlen( szLine ), "text/html" ) )
					m_szContentHtml = pItem->Data();
			}
		}
	}

	// assign force if contents are not found
	pItem = GetItem( 0 );

	if ( !m_szContentText.isassign() && 
		 !m_szContentHtml.isassign() && 
		 pItem->m_bFile == false	 &&
		 pItem->DataSize() )
	{
		m_szContentText = pItem->Data();
	}

	return true;
}


char * CMail::From()
{
	return m_szFrom;
}


char * CMail::Date()
{
	return m_szDate;
}


char * CMail::To()
{
	return m_szTo;
}


char * CMail::Subject()
{
	return m_szSubject;
}


char * CMail::Content( bool bPriorityHtml )
{
	return 
		bPriorityHtml ? 
		( m_szContentHtml.isassign() ? m_szContentHtml : m_szContentText ):
		( m_szContentText.isassign() ? m_szContentText : m_szContentHtml );
}


int CMail::GetNumFiles()
{
	return m_listFiles.GetCount();
}


bool CMail::GetFirstFile( CMailItem *pItem )
{
	pItem->m_pNode = m_listFiles.GetHead();

	if ( pItem->m_pNode == NULL )
		return false;

	return true;
}


bool CMail::GetNextFile( CMailItem *pItem )
{
	pItem->m_pNode = pItem->m_pNode->GetNext();
	
	if ( pItem->m_pNode == NULL )
		return false;

	return true;
}
