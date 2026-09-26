

/*
	MIME (Multipurpose Internet Mail Extensions) Encoder/Decoder

	Date:
		2001/10/25 (Last Updated: 2002/05/25)

	History:
		2002/05/18 - None-standard MIME newline(\n) process has been added.
*/
#ifndef __ORZ_NETWORK_MIME_PARSER__
#define __ORZ_NETWORK_MIME_PARSER__


#include <windows.h>
#include "list.h"
#include "stringex.h"


#define MIME_MAXLINE				4096
#define MIME_MULTIPART_BOUNDARY		"=-----------------------~g!e@n#i$u%s^o&r*z(--="
#define MIME_BOUNDARY				"\r\n\r\n"
#define MIME_NEWLINE				"\r\n"
#define MIME_BOUNDARY_START			"--"
#define MIME_BOUNDARY_END			"--"

#define MIME_ITEM_NORMAL			1
#define MIME_ITEM_BASE64			2
#define MIME_ITEM_QUOTED_PRINTABLE	3
#define MIME_ITEM_UUENCODE			4


class CMimeItem
{
public:
	char *m_pHeader;
	int	 m_nHeaderLen;
	char *m_pData;
	int	 m_nDataLen;

	int  m_nEncodingType;

	bool m_bFile;
	char m_szFileName[MAX_PATH];

public:
	CMimeItem();
	virtual ~CMimeItem();

	/*
		Access Member Variables
	*/
	char * Header();
	int  HeaderSize();
	char * Data();
	int  DataSize();
	
	bool IsFile();
	char * FileName();

	/*
		Parse/Retrieve
	*/
	bool QueryHeader( char *pName, char *pValue, int nValueLen );
	bool GetBoundary( char *pBuf, int nBufLen );
	
protected:
	void DecodeHeaderExtensions( char *pBuf );
};


class CMimeEncoder
{
public:
	bstr	m_szHeader;
	bstr	m_szData;

public:
	CMimeEncoder();
	virtual ~CMimeEncoder();

	char * Header();
	int  HeaderSize();
	char * Data();
	int  DataSize();

	void AddHeader ( char *pName, char *pValue );
	bool InsertItem( char *pContentType, 
					 char *pData,
					 int  nDataLen		= -1,
					 int  nEncodingType	= MIME_ITEM_BASE64,
					 char *pFileName	= NULL );
	bool InsertFile( char *pFileName,
					 int  nEncodingType	= MIME_ITEM_BASE64 );
	void End();
};


class CMimeDecoder
{
public:
	CList< CMimeItem >	m_listItem;

public:
	CMimeDecoder();
	virtual ~CMimeDecoder();

	void Reset();

	bool Parse( char *pBuf, int nBufLen );

	int  GetItemCount();
	CMimeItem * GetItem( int nItem );
	CMimeItem & operator[]( int nItem );

protected:
	bool DuplicateBuffer( char *pBuf, int nBufLen, char **ppDest, int *pDestLen );
	bool GetBoundaryBlockPointer( char *pMimeBoundary, 
								  char *pMimeNewline,
								  char *pBuf, 
								  char *pBoundary, 
								  char *pEncoding, 
								  char **ppStart, 
								  char **ppEnd );

	bool DecodeData( char *pBuf, int nBufLen, CMimeItem *pItem );
};


#endif