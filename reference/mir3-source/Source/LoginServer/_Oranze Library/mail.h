

/*
	Mail Parser (Decode Only)

	Date:
		2001/11/05
*/
#ifndef __ORZ_NETWORK_MAIL__
#define __ORZ_NETWORK_MAIL__


#include "mime.h"
#include "stringex.h"


class CMail;
class CMailItem
{
protected:
	CListNode< CMimeItem >	*m_pNode;

public:
	CMailItem();
	virtual ~CMailItem();

	char * Name()				{ return m_pNode->GetData()->m_szFileName; }
	char * Data()				{ return m_pNode->GetData()->m_pData; }
	int  Size()					{ return m_pNode->GetData()->m_nDataLen; }

	char * Header()				{ return m_pNode->GetData()->m_pHeader; }
	int  HeaderSize()			{ return m_pNode->GetData()->m_nHeaderLen; }
	
	operator CMimeItem * ()		{ return m_pNode->GetData(); }

public:
	friend CMail;
};


class CMail : public CMimeDecoder
{
public:
	// part of MIME header
	bstr m_szFrom; 
	bstr m_szDate;
	bstr m_szTo;
	bstr m_szSubject;

	// part of MIME body
	bstr m_szContentText;
	bstr m_szContentHtml;

	// attached files (part of MIME body)
	CList< CMimeItem >	m_listFiles;

public:
	CMail();
	virtual ~CMail();

	void Reset();

	bool Parse( char *pRaw, int nRawLen );

	char * From();
	char * Date();
	char * To();
	char * Subject();
	char * Content( bool bPriorityHtml = true );

	int  GetNumFiles();
	bool GetFirstFile( CMailItem *pItem );
	bool GetNextFile ( CMailItem *pItem );
};


#endif