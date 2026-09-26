

#include "pop3.h"
#include "stringex.h"
#include <stdio.h>


CPop3Handler::CPop3Handler()
{
	m_sdHost	= INVALID_SOCKET;
}


CPop3Handler::~CPop3Handler()
{
	Disconnect();
}


int CPop3Handler::Connect( CSockAddr *pAddr, char *pUser, char *pPass )
{
	m_sdHost = socket( AF_INET, SOCK_STREAM, 0 );
	if ( m_sdHost == INVALID_SOCKET )
		throw CError( "CPop3Handler::Init socket 생성 실패" );

	if ( connect( m_sdHost, pAddr, sizeof( SOCKADDR ) ) == SOCKET_ERROR )
		return POP3_ERR_CONNECT;
	
	// check connection response code
	if ( GetResponseCode() == false )
		return POP3_ERR_CONNECT;

	if ( Request( "USER %s\r\n", pUser ) == false )
		return POP3_ERR_AUTH;

	if ( Request( "PASS %s\r\n", pPass ) == false )
		return POP3_ERR_AUTH;

	return POP3_SUCCESS;
}


int CPop3Handler::Connect( char *pAddr, short nPort, char *pUser, char *pPass )
{
	return Connect( CSockAddr( pAddr, nPort ), pUser, pPass );
}


void CPop3Handler::Disconnect()
{
	if ( m_sdHost != INVALID_SOCKET )
	{
		shutdown( m_sdHost, SD_BOTH );
		closesocket( m_sdHost );
		m_sdHost = INVALID_SOCKET;
	}
}


int CPop3Handler::GetNumMsgs()
{
	if ( Request( "STAT\r\n" ) == false )
		return -1;

	// format: +OK [MSG_COUNT] [MSG_TOTAL_OCTETS]
	char szNum[POP3_MAXBUF];
	if ( _pickstring( m_szCurRespLine, ' ', 1, szNum, sizeof( szNum ) ) )
		return atoi( szNum );

	return -1;
}


bool CPop3Handler::GetMsgUidlList( CPop3UidlList *pList )
{
	if ( Request( "UIDL\r\n" ) == false )
		return false;

	// there is no message
	if ( strncmp( m_qRecv, ".\r\n", 3 ) == 0 )
	{
		m_qRecv.Remove( 3 );
		return true;
	}

	CPop3Uidl	*pUidl;
	char		buf[POP3_MAXBUF];
	char		*pEnd, *pNext;
	int			nRecvLen;

	while ( true )
	{
		if ( pEnd = _memstr( m_qRecv, m_qRecv.Length(), POP3_ENDOFMSG ) )
		{
			pNext = m_qRecv;

			do
			{
				if ( *pNext == '.' )
					break;
				
				pUidl = new CPop3Uidl;
				if ( !pUidl )
					return false;
				
				_linecopy( buf, pNext );
				_pickstring( buf, ' ', 0, pUidl->szUidl, sizeof( pUidl->szUidl ) );
				pUidl->nIndex = atoi( pUidl->szUidl );
				_pickstring( buf, ' ', 1, pUidl->szUidl, sizeof( pUidl->szUidl ) );

				pList->Insert( pUidl );

				pNext = _memstr( pNext, m_qRecv.Length() - (pNext - m_qRecv), POP3_NEWLINE ) + strlen( POP3_NEWLINE );
					
			} while ( pNext );

			m_qRecv.Remove( (pEnd + strlen( POP3_ENDOFMSG )) - m_qRecv );			
			break;
		}

		nRecvLen = recv( m_sdHost, buf, sizeof( buf ), 0 );
		if ( nRecvLen <= 0 )
			return false;

		m_qRecv.Append( buf, nRecvLen );
	}

	return true;
}


bool CPop3Handler::GetMsgUidl( int nIndex, char *pBuf )
{
	if ( Request( "UIDL %d\r\n", nIndex ) == false )
		return false;

	// format: +OK [MSG_INDEX] [MSG_UIDL]
	if ( _pickstring( m_szCurRespLine, ' ', 2, pBuf, POP3_MAXUIDL ) )
		return true;

	return false;
}


bool CPop3Handler::DeleteMsg( int nIndex )
{
	return Request( "DELE %d\r\n", nIndex );
}


int CPop3Handler::GetMsgSize( int nIndex )
{
	if ( Request( "LIST %d\r\n", nIndex ) == false )
		return -1;

	// format: +OK [MSG_INDEX] [MSG_OCTETS]
	char szSize[POP3_MAXBUF];
	if ( _pickstring( m_szCurRespLine, ' ', 2, szSize, sizeof( szSize ) ) )
		return atoi( szSize );

	return -1;
}


bool CPop3Handler::GetMsg( int nIndex, char **ppDest, int *pDestLen,
						   bool (*pfnCallback)( void *pContext, CPop3Status *pStatus ), 
						   void *pContext )
{	
	CPop3Status	pop3Status;
	memset( &pop3Status, 0, sizeof( pop3Status ) );

	pop3Status.nIndex		= nIndex;
	pop3Status.nBytesTotal	= GetMsgSize( nIndex );
	if ( pop3Status.nBytesTotal <= 0 )
		return false;

	// 충분한 크기의 버퍼를 미리 할당해 둔다.
	m_qRecv.Expand( pop3Status.nBytesTotal );

	if ( Request( "RETR %d\r\n", nIndex ) == false )
		return false;

	char buf[POP3_MAXBUF];
	char *pNext;
	int  nRecvLen;

	// 메시지 끝(.) 표시를 찾기 위해 필요한 최소 크기
	// 아래의 크기보다 작을 경우 버퍼의 처음부터 검색을 해야한다.
	int  nSearchSpace = POP3_MAXBUF + strlen( POP3_ENDOFMSG );

	while ( true )
	{
		if ( m_qRecv.Length() < nSearchSpace )
			pNext = _memstr( m_qRecv, m_qRecv.Length(), POP3_ENDOFMSG );
		else
			pNext = _memstr( m_qRecv + (m_qRecv.Length() - nSearchSpace), nSearchSpace, POP3_ENDOFMSG );

		if ( pNext )
		{
			*pDestLen = pNext - (char *) m_qRecv + strlen( POP3_NEWLINE );

			// call status callback
			if ( pfnCallback )
			{
				pop3Status.nBytesRecv = *pDestLen;
				if ( pfnCallback( pContext, &pop3Status ) == false )
					return false;
			}

			*ppDest = new char[ *pDestLen + 1 ];
			if ( !*ppDest )
				return false;

			memcpy( *ppDest, (char *) m_qRecv, *pDestLen );
			(*ppDest)[ *pDestLen ] = NULL;

			m_qRecv.Remove( *pDestLen + (strlen( POP3_ENDOFMSG ) - strlen( POP3_NEWLINE )) );
			return true;
		}

		// call status callback
		if ( pfnCallback )
		{
			pop3Status.nBytesRecv = m_qRecv.Length();
			if ( pfnCallback( pContext, &pop3Status ) == false )
				return false;
		}

		nRecvLen = recv( m_sdHost, buf, sizeof( buf ), 0 );
		if ( nRecvLen <= 0 )
			return false;

		m_qRecv.Append( buf, nRecvLen );
	}
	
	return true;
}


bool CPop3Handler::Quit()
{
	return Request( "QUIT %d\r\n" );
}


/*
	GetResponseCode()
*/
bool CPop3Handler::GetResponseCode()
{
	char *pNext;
	int  nRecvLen;
	int  nLineLen;

	while ( true )
	{
		if ( m_qRecv.Length() && (pNext = strstr( m_qRecv, POP3_NEWLINE )) )
		{
			nLineLen = pNext - (char *) m_qRecv;
			memcpy( m_szCurRespLine, (char *) m_qRecv, nLineLen );
			m_szCurRespLine[nLineLen] = NULL;

			m_qRecv.Remove( nLineLen + strlen( POP3_NEWLINE ) );
			break;
		}

		nRecvLen = recv( m_sdHost, m_szCurRespLine, sizeof( m_szCurRespLine ), 0 );
		if ( nRecvLen <= 0 )
			return false;

		m_qRecv.Append( m_szCurRespLine, nRecvLen );
	}

	if ( m_szCurRespLine[0] == '+' )
		return true;
	
	return false;
}


/*
	Request()

	desc	: request command buffer, and then return response code.
*/
bool CPop3Handler::Request( char *pMsg, ... )
{
	char szBuf[POP3_MAXBUF] = {0,};
	
	va_list	stream;		
	va_start( stream, pMsg );
	vsprintf( szBuf, pMsg, stream );
	va_end( stream );

	int nBufLen		= strlen( szBuf );
	int nTotalLen	= 0;
	int nSendLen;

	while ( nTotalLen < nBufLen )
	{
		nSendLen = send( m_sdHost, szBuf + nTotalLen, nBufLen - nTotalLen, 0 );
		if ( nSendLen < 0 )
			return false;

		nTotalLen += nSendLen;
	}

	return GetResponseCode();
}