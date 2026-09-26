

#include "mime.h"
#include "stringex.h"
#include "imsgfmt.h"
#include "base64.h"
#include "quotedpr.h"
#include "uucp.h"
#include "stringex.h"
#include "file.h"
#include <stdio.h>


static void ParseQuotedString( char *str )
{
	int str_len = strlen( str );

	// check quoted single-character
	for ( int i = 0; i < str_len; i++ )
	{
		if ( str[i] == '\\' )
		{
			// skip next character
			strcpy( &str[i], &str[i + 1] );
			++i;
		}
		else if ( str[i] == '\"' )
		{
			// remove quoted character
			strcpy( &str[i], &str[i + 1] );
			--i;
			--str_len;
		}
	}
}


CMimeItem::CMimeItem()
{
	m_pHeader		= NULL;
	m_nHeaderLen	= 0;
	m_pData			= NULL;
	m_nDataLen		= 0;

	m_nEncodingType	= 0;

	m_bFile			= false;
	m_szFileName[0]	= NULL;
}


CMimeItem::~CMimeItem()
{
	if ( m_pHeader )
		delete[] m_pHeader;

	if ( m_pData )
		delete[] m_pData;
}


char * CMimeItem::Header()
{
	return m_pHeader;
}


int CMimeItem::HeaderSize()
{
	return m_nHeaderLen;
}


char * CMimeItem::Data()
{
	return m_pData;
}


int CMimeItem::DataSize()
{
	return m_nDataLen;
}


bool CMimeItem::IsFile()
{
	return m_bFile;
}


char * CMimeItem::FileName()
{
	return m_szFileName;
}


bool CMimeItem::QueryHeader( char *pName, char *pValue, int nValueLen )
{
	if ( !m_pHeader )
		return false;

	if ( CIMsgFormat::QueryString( m_pHeader, pName, pValue, nValueLen ) )
	{
		DecodeHeaderExtensions( pValue );
		ParseQuotedString( pValue );
		return true;
	}

	return false;
}


bool CMimeItem::GetBoundary( char *pBuf, int nBufLen )
{
	if ( !m_pHeader )
		return false;

	char szTmp[MIME_MAXLINE] = {0,};
	if ( CIMsgFormat::QueryString( m_pHeader, "boundary", szTmp, sizeof( szTmp ) ) == false )
		return false;

	ParseQuotedString( szTmp );

	memcpy( pBuf, MIME_BOUNDARY_START, strlen( MIME_BOUNDARY_START ) );
	strcat( pBuf, szTmp );

	return true;
}


/*
	DecodeHeaderExtensions()

	format	: "=?" charset "?" encoding "?" encoded-text "?="
	note	: above format can be repeated.
*/
void CMimeItem::DecodeHeaderExtensions( char *pBuf )
{
	char *pPos = pBuf, *pNext = NULL;
	int  nBufPos = 0;
	char szTmp[MIME_MAXLINE];

	char szCharSet[MIME_MAXLINE];
	char cEncodingType;
	char szEncodedText[MIME_MAXLINE];

	while ( true )
	{
		// 헤더 확장 시작 바이트 검사
		if ( (pNext = strstr( pPos, "=?" )) == NULL )
		{
			strcpy( pBuf + nBufPos, pPos );
			return;
		}

		memcpy( szTmp, pPos, pNext - pPos );
		szTmp[ pNext - pPos ] = NULL;
		_trim( szTmp );

		strcpy( pBuf + nBufPos, szTmp );
		nBufPos += strlen( szTmp );

		pPos = pNext + 2;
		
		// charset을 얻는다.
		if ( (pNext = strstr( pPos, "?" )) == NULL )
			return;
		memcpy( szCharSet, pPos, pNext - pPos );
		szCharSet[ pNext - pPos ] = NULL;
		pPos = pNext + 1;
		
		// encoding type을 얻는다.
		if ( (pNext = strstr( pPos, "?" )) == NULL )
			return;	
		cEncodingType = *(pNext - 1);
		pPos = pNext + 1;
		
		// encoded_text를 얻는다.
		if ( (pNext = strstr( pPos, "?=" )) == NULL )
			return;
		memcpy( szEncodedText, pPos, pNext - pPos );
		szEncodedText[ pNext - pPos ] = NULL;
		pPos = pNext + 2;
		
		// decoding한다.
		char *pTmp;
		int  nTmpLen;
		
		switch ( toupper( cEncodingType ) )
		{
		case 'Q': // Quoted Printable
			CQuotedPrintable::Decode( szEncodedText, 
				strlen( szEncodedText ), 
				&pTmp, 
				&nTmpLen );
			break;
		case 'B': // Base64
			CBase64::Decode( szEncodedText, 
				strlen( szEncodedText ), 
				&pTmp, 
				&nTmpLen );
			break;
		default:
			return;
		}
		
		memcpy( pBuf + nBufPos, pTmp, nTmpLen );
		pBuf[ nBufPos + nTmpLen ] = NULL;
		nBufPos += nTmpLen;
		
		delete[] pTmp;
	}
}




CMimeEncoder::CMimeEncoder()
{
	m_szHeader = 
		"MIME-Version: 1.0\r\n"
		"Content-Type: multipart/mixed; boundary=\"" MIME_MULTIPART_BOUNDARY "\"\r\n";

	m_szData =
		"This is a multi-part message in MIME format.\r\n"
		"\r\n";
}


CMimeEncoder::~CMimeEncoder()
{
}


char * CMimeEncoder::Header()
{
	return m_szHeader;
}


int CMimeEncoder::HeaderSize()
{
	return m_szHeader.length() - 1;
}


char * CMimeEncoder::Data()
{
	return m_szData;
}


int CMimeEncoder::DataSize()
{
	return m_szData.length() - 1;
}


void CMimeEncoder::AddHeader( char *pName, char *pValue )
{
	m_szHeader += pName;
	m_szHeader += ": ";
	m_szHeader += pValue;
	m_szHeader += "\r\n";
}


/*
	InsertItem()

	인자설명>
	pContentType	= text/plain, text/html, application/octet-stream, ...
	nDataLen		= 바이너리 데이터의 경우 길이를 명시한다.
	pFileName		= 첨부 파일임을 나타낼 때에 사용한다. (보통은 NULL)
*/
bool CMimeEncoder::InsertItem( char *pContentType, 
							   char *pData,
							   int  nDataLen,
							   int  nEncodingType, 
							   char *pFileName )
{
	if ( nDataLen < 0 )
		nDataLen = strlen( pData );
	
	bstr szEncodingType;
	char *pEncodedData;
	int  nEncodedLen;

	switch ( nEncodingType )
	{
	case MIME_ITEM_BASE64:
		{
			szEncodingType = "base64";
			if ( !CBase64::Encode( pData, nDataLen, &pEncodedData, &nEncodedLen ) )
				return false;
		}
		break;
	case MIME_ITEM_QUOTED_PRINTABLE:
		{
			szEncodingType = "quoted-printable";
			if ( !CQuotedPrintable::Encode( pData, nDataLen, &pEncodedData, &nEncodedLen ) )
				return false;
		}
		break;
	default:
		{
			szEncodingType = "7bit";
			pEncodedData = new char[ (nEncodedLen = nDataLen) + 1 ];
			if ( !pEncodedData )
				return false;
			memcpy( pEncodedData, pData, nDataLen );
			pEncodedData[ nEncodedLen ] = '\0';
		}
		break;
	}
	
	m_szData += "--" MIME_MULTIPART_BOUNDARY "\r\n";
	m_szData += "Content-Type: ";
	m_szData += pContentType;
	m_szData += "\r\n";
	m_szData += "Content-Transfer-Encoding: ";
	m_szData += szEncodingType;
	m_szData += "\r\n";

	if ( pFileName )
	{		
		m_szData += "Content-Disposition: attachment; filename=\"";
		m_szData += strrchr( pFileName, '\\' ) ? strrchr( pFileName, '\\' ) + 1 : pFileName;
		m_szData += "\"\r\n";
	}

	m_szData += "\r\n";
	m_szData += pEncodedData;
	m_szData += "\r\n";

	return true;
}


bool CMimeEncoder::InsertFile( char *pFileName, int nEncodingType )
{
	CFile file;
	if ( !file.Open( pFileName, "rb" ) )
		return false;

	char *pData = new char[	file.GetLength() ];
	if ( !pData )
		return false;

	file.Read( pData, file.GetLength() );

	return InsertItem( "application/octet-stream", 
					   pData, 
					   file.GetLength(), 
					   nEncodingType, 
					   pFileName );
}


void CMimeEncoder::End()
{
	m_szHeader	+= "\r\n";
	m_szData	+= "--" MIME_MULTIPART_BOUNDARY "--";
}




CMimeDecoder::CMimeDecoder()
{
}


CMimeDecoder::~CMimeDecoder()
{
	Reset();
}


void CMimeDecoder::Reset()
{
	m_listItem.ClearAll();
}


bool CMimeDecoder::Parse( char *pBuf, int nBufLen )
{
	CMimeItem *pItem = new CMimeItem;
	if ( !pItem )
		return false;

	char *pMimeBoundary = MIME_BOUNDARY;
	char *pMimeNewline  = MIME_NEWLINE;

	// MIME 헤더 복사
	char *pEnd = strstr( pBuf, pMimeBoundary );
	if ( !pEnd )
	{
		pEnd = strstr( pBuf, "\n\n" );
		if ( !pEnd )
			return NULL;
		
		pMimeBoundary = "\n\n";
		pMimeNewline  = "\n";
	}

	pEnd	+= strlen( pMimeBoundary );
	
	if ( DuplicateBuffer( pBuf, pEnd - pBuf, &pItem->m_pHeader, &pItem->m_nHeaderLen ) == false )
	{
		delete pItem;
		return false;
	}

	pBuf	+= (pItem->m_nHeaderLen);
	nBufLen	-= (pItem->m_nHeaderLen);

	// MIME 본문 파싱
	char szContentType[MIME_MAXLINE] = {0,};
	pItem->QueryHeader( "Content-Type", szContentType, sizeof( szContentType ) );

	if ( _memistr( szContentType, strlen( szContentType ), "multipart" ) )
	{			
		char szBoundary[MIME_MAXLINE] = {0,};
		if ( pItem->GetBoundary( szBoundary, sizeof( szBoundary ) ) == false )
		{
			delete pItem;
			return false;
		}
		
		// 본문 저장
		pEnd = _memistr( pBuf, strlen( pBuf ), szBoundary ) - strlen( pMimeNewline );

		if ( DecodeData( pBuf, pEnd - pBuf, pItem ) == false )
		{
			delete pItem;
			return false;
		}

		m_listItem.Insert( pItem );

		// Multi Part 처리 (Recursive Call)
		char *pItemStart, *pItemEnd;

		while ( true )
		{	
			char szEncoding[MIME_MAXLINE] = {0,};
			CIMsgFormat::QueryString( pBuf, "Content-Transfer-Encoding", szEncoding, sizeof( szEncoding ) );
			
			GetBoundaryBlockPointer( pMimeBoundary, pMimeNewline, 
				pBuf, szBoundary, szEncoding, &pItemStart, &pItemEnd );
			if ( !pItemStart || !pItemEnd )
				break;

			if ( Parse( pItemStart, pItemEnd - pItemStart ) == false )
				return false;
			
			if ( stricmp( szEncoding, "base64" ) == 0 )
				pBuf = pItemEnd + strlen( pMimeBoundary );
			else
				pBuf = pItemEnd + strlen( pMimeNewline );
		}
	}
	else
	{
		// check whether data is file
		char szFile[MIME_MAXLINE] = {0,};
		if ( pItem->QueryHeader( "filename", szFile, sizeof( szFile ) ) || 
			 pItem->QueryHeader( "file", szFile, sizeof( szFile ) )		||
			 pItem->QueryHeader( "name", szFile, sizeof( szFile ) ) )
		{
			pItem->m_bFile	= true;
			strcpy( pItem->m_szFileName, szFile );
		}
		
		if ( DecodeData( pBuf, nBufLen, pItem ) == false )
		{
			delete pItem;
			return false;
		}

		m_listItem.Insert( pItem );

		return true;
	}

	return true;
}


int CMimeDecoder::GetItemCount()
{
	return m_listItem.GetCount();
}


CMimeItem * CMimeDecoder::GetItem( int nItem )
{
	CListNode< CMimeItem > *pNode;

	for ( pNode = m_listItem.GetHead(); pNode; pNode = pNode->GetNext(), nItem-- )
	{
		if ( nItem == 0 )
			return pNode->GetData();
	}

	return NULL;
}


CMimeItem & CMimeDecoder::operator[]( int nItem )
{
	return * GetItem( nItem );
}


/*
	DuplicateBuffer()

	주어진 버퍼(pBuf)로부터 길이(nBufLen)만큼 메모리를 할당한 후 복사한다.
*/
bool CMimeDecoder::DuplicateBuffer( char *pBuf, int nBufLen, char **ppDest, int *pDestLen )
{
	*pDestLen = nBufLen;

	*ppDest = new char[ *pDestLen + 1 ]; // NULL을 표시할 여분을 둔다.
	if ( !ppDest )
		return false;

	memcpy( *ppDest, pBuf, *pDestLen );
	(*ppDest)[ *pDestLen ] = NULL;

	return true;
}


/*
	GetBoundaryBlockPointer()

	Desc> 주어진 버퍼로부터 현재 블럭의 시작과 끝 포인터를 구한다.
*/
bool CMimeDecoder::GetBoundaryBlockPointer( char *pMimeBoundary,
											char *pMimeNewline,
											char *pBuf, 
											char *pBoundary, 
											char *pEncoding, 
											char **ppStart, 
											char **ppEnd )
{
	char szBoundary[MIME_MAXLINE];
	sprintf( szBoundary, "%s%s", pBoundary, pMimeNewline );

	*ppStart = _memistr( pBuf, strlen( pBuf ), szBoundary );
	if ( !*ppStart )
		return false;

	*ppStart += strlen( pBoundary );

	*ppEnd = _memistr( *ppStart, strlen( *ppStart ), szBoundary );
	if ( !*ppEnd )
	{
		sprintf( szBoundary, "%s--", pBoundary );
		*ppEnd = _memistr( *ppStart, strlen( *ppStart ), szBoundary );

		if ( !*ppEnd )
			return false;
	}

	if ( stricmp( pEncoding, "base64" ) == 0 )
		*ppEnd -= strlen( pMimeBoundary );
	else
		*ppEnd -= strlen( pMimeNewline );

	return true;
}


bool CMimeDecoder::DecodeData( char *pBuf, int nBufLen, CMimeItem *pItem )
{
	if ( nBufLen <= 0 )
		return true;

	char szEncoding[MIME_MAXLINE] = {0,};
	pItem->QueryHeader( "Content-Transfer-Encoding", szEncoding, sizeof( szEncoding ) );

	if ( stricmp( szEncoding, "base64" ) == 0 )
	{		
		pItem->m_nEncodingType	= MIME_ITEM_BASE64;

		return CBase64::Decode( pBuf, 
								nBufLen, 
								&pItem->m_pData,
								&pItem->m_nDataLen );
	}
	else if ( stricmp( szEncoding, "quoted-printable" ) == 0 )
	{
		pItem->m_nEncodingType	= MIME_ITEM_QUOTED_PRINTABLE;

		return CQuotedPrintable::Decode( pBuf,
										 nBufLen,
										 &pItem->m_pData,
										 &pItem->m_nDataLen );
	}

	// check for uuencode
	if ( CUuDecoder::IsEncoded( pBuf ) )
	{
		pItem->m_nEncodingType	= MIME_ITEM_UUENCODE;
		pItem->m_bFile			= true;

		return CUuDecoder::Decode( pBuf,
								   nBufLen,
								   pItem->m_szFileName,
								   &pItem->m_pData,
								   &pItem->m_nDataLen );
	}

	// default: 7bit, 8bit, binary and not specified encoding types
	pItem->m_nEncodingType	= MIME_ITEM_NORMAL;
 
	return DuplicateBuffer( pBuf,
						    nBufLen,
						    &pItem->m_pData,
						    &pItem->m_nDataLen );
}
