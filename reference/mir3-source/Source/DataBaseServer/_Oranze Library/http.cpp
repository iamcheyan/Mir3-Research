

#include "http.h"
#include "file.h"
#include "imsgfmt.h"
#include "base64.h"


CHttpHandler::CHttpHandler()
{
	m_sdHost			= INVALID_SOCKET;
	m_nRespCode			= 0;
	m_pfnStatus			= NULL;
	m_pStatusContext	= NULL;

	m_listCookie.SetCompareFunction( __cbCmpCookie, NULL );
	m_listParam.SetCompareFunction( __cbCmpParam, NULL );
}


CHttpHandler::~CHttpHandler()
{
	Reset();
}


void CHttpHandler::Reset()
{
	Disconnect();

	m_listCookie.ClearAll();
	m_listParam.ClearAll();

	m_qRecv.ClearAll();
}


bool CHttpHandler::InsertCookie( char *pCookieList )
{
	bstr szName, szValue;
	char *pDelim;

	bstr szCookieList = pCookieList;
	char *pToken = strtok( szCookieList, ";" );	

	while ( pToken )
	{
		pDelim = strchr( pToken, '=' );
		if ( pDelim )
		{			
			szName.assign( pToken, pDelim - pToken );
			szValue.assign( pDelim + 1 );
			
			if ( !InsertCookie( szName, szValue ) )
				return false;
		}

		pToken = strtok( NULL, ";" );
	}

	return true;
}


bool CHttpHandler::InsertCookie( char *pName, char *pValue )
{
	// it is already registered cookie
	if ( m_listCookie.Search( (CHttpCookie *) pName ) )
		return true;

	CHttpCookie *pCookie = new CHttpCookie;
	if ( !pCookie )
		return false;

	pCookie->szName	 = pName;
	pCookie->szValue = pValue;

	return m_listCookie.Insert( pCookie );
}


bool CHttpHandler::InsertParam( char *pParamList, int nEncodingType )
{
	bstr szName, szValue;
	char *pDelim;

	bstr szParamList = pParamList;
	char *pToken = strtok( szParamList, "&" );	

	while ( pToken )
	{
		pDelim = strchr( pToken, '=' );
		if ( pDelim )
		{			
			szName.assign( pToken, pDelim - pToken );
			szValue.assign( pDelim + 1 );
			
			if ( !InsertParam( szName, szValue, nEncodingType ) )
				return false;
		}

		pToken = strtok( NULL, "&" );
	}

	return true;
}


bool CHttpHandler::InsertParam( char *pName, char *pValue, int nEncodingType )
{
	CHttpParam *pParam = new CHttpParam;
	if ( !pParam )
		return false;

	pParam->bFile	= false;
	pParam->szName	= pName;
	
	switch ( nEncodingType )
	{
	case HTTP_ENCODING_NONE:
		pParam->szValue = pValue;
		break;
	case HTTP_ENCODING_URL:
		CUrl::Encode( pValue, strlen( pValue ), &pParam->szValue.ptr, &pParam->szValue.size );
		break;
	case HTTP_ENCODING_BASE64:
		CBase64::Encode( pValue, strlen( pValue ), &pParam->szValue.ptr, &pParam->szValue.size );
		break;
	}

	return m_listParam.Insert( pParam );
}


bool CHttpHandler::InsertFile( char *pName, char *pPath )
{
	CHttpParam *pParam = new CHttpParam;
	if ( !pParam )
		return false;

	pParam->bFile	= true;
	pParam->szName	= pName;
	pParam->szValue	= pPath;

	return m_listParam.Insert( pParam );
}


int CHttpHandler::OpenUrl( int  nMethod, 
						   char *pUrl, 
						   PHTTP_CALLBACK pfnStatus,
						   void *pContext, 
						   int  nFlag )
{
	m_pfnStatus			= pfnStatus;
	m_pStatusContext	= pContext;

	int nRetCode;
	if ( (nRetCode = OpenUrl_Connect( pUrl )) != HTTP_SUCCESS )
		return nRetCode;

	switch ( nMethod )
	{
	case HTTP_GET:
		if ( (nRetCode = OpenUrl_RequestGet()) != HTTP_SUCCESS )
			return OpenUrl_Disconnect(), nRetCode;
		break;
	case HTTP_POST:
		if ( (nRetCode = OpenUrl_RequestPost()) != HTTP_SUCCESS )
			return OpenUrl_Disconnect(), nRetCode;
		break;
	case HTTP_MULTIPART:		
		if ( (nRetCode = OpenUrl_RequestMultipart()) != HTTP_SUCCESS )
			return OpenUrl_Disconnect(), nRetCode;
		break;
	}

	if ( (nRetCode = OpenUrl_RespondContent()) != HTTP_SUCCESS )
		return OpenUrl_Disconnect(), nRetCode;

	OpenUrl_Disconnect();

	if ( !(nFlag & HTTP_FLAG_NO_AUTO_COOKIE) )
		InsertReturnedCookie();

	if ( !(nFlag & HTTP_FLAG_NO_AUTO_REDIRECT) && (m_nRespCode >= 300 && m_nRespCode < 400) )
		return RedirectUrl( nMethod, pfnStatus, pContext, nFlag );

	return HTTP_SUCCESS;
}


int CHttpHandler::OpenFile( char *pUrl,
						    char *pSavePath,
							bool bOverwrite,
							PHTTP_CALLBACK pfnStatus,
							void *pContext,
							int  nFlag )
{
	m_pfnStatus			= pfnStatus;
	m_pStatusContext	= pContext;

	int nRetCode;

	if ( (nRetCode = OpenUrl_Connect( pUrl )) != HTTP_SUCCESS )
		return nRetCode;

	if ( (nRetCode = OpenUrl_RequestGet( !bOverwrite ? CFile::GetLength( pSavePath ) : 0 )) != HTTP_SUCCESS )
		return OpenUrl_Disconnect(), nRetCode;

	if ( (nRetCode = OpenUrl_RespondContent( pSavePath, bOverwrite )) != HTTP_SUCCESS )
		return OpenUrl_Disconnect(), nRetCode;

	OpenUrl_Disconnect();

	if ( !(nFlag & HTTP_FLAG_NO_AUTO_COOKIE) )
		InsertReturnedCookie();

	if ( !(nFlag & HTTP_FLAG_NO_AUTO_REDIRECT) && m_nRespCode >= 300 && m_nRespCode < 400 )
		return RedirectFile( pSavePath, bOverwrite, pfnStatus, pContext );

	return HTTP_SUCCESS;
}


char * CHttpHandler::GetHeader()
{
	return m_szRespHeader;
}


int CHttpHandler::GetContentLength()
{
	char value[256];
	if ( !CIMsgFormat::QueryString( m_szRespHeader, "Content-Length", value, sizeof( value ) ) )
		return 0;

	return atoi( value );
}


char * CHttpHandler::GetContent()
{
	return m_qRecv;
}


int CHttpHandler::OpenUrl_Connect( char *pUrl )
{	
	SplitUrlItems( pUrl );

	m_status.pUrl				= pUrl;
	m_status.nStatus			= HTTP_STAT_CONNECTING;
	m_status.nContentLength		= 0;
	m_status.nBytesTransferred	= 0;
	m_status.pHandler			= this;
	if ( !CallbackStatus() )
		return HTTP_CANCEL;
	if ( !Connect( CSockAddr( m_urlItem.addr, m_urlItem.port ) ) )
		return HTTP_ERR_CONNECTING;

	return HTTP_SUCCESS;
}


int CHttpHandler::OpenUrl_RequestGet( int from, int to )
{
	bstr cookie = "";	// cookie 
	GetCookieString( cookie );
	bstr range = "";	// range
	GetRangeString( range, from, to );
	bstr param;			// url parameter
	GetParamString( param );

	bstr req_string;	// complete request string
	req_string.alloc( m_urlItem.length() + cookie.length() + 256 );
	if ( param.length() )
	{
		sprintf( req_string, 
			"GET /%s?%s HTTP/1.0\r\n"
			"Host: %s:%s\r\n"		
			"%s"
			"%s"
			"\r\n",					
			(char *) m_urlItem.sub_addr, (char *) param, 
			(char *) m_urlItem.addr, (char *) m_urlItem.port, 
			(char *) cookie,
			(char *) range );
	}
	else
	{
		sprintf( req_string, 
			"GET /%s HTTP/1.0\r\n"
			"Host: %s:%s\r\n"	
			"Content-Type: application/x-www-form-urlencoded\r\n"
			"%s"
			"%s"				
			"\r\n",	
			(char *) m_urlItem.sub_addr, 
			(char *) m_urlItem.addr, (char *) m_urlItem.port, 
			(char *) cookie,
			(char *) range );
	}

	m_status.nStatus			= HTTP_STAT_REQUESTING;
	m_status.nContentLength		= strlen( req_string );
	m_status.nBytesTransferred	= 0;
	if ( !CallbackStatus() )
		return HTTP_CANCEL;

	return Send( req_string, strlen( req_string ) );
}


int CHttpHandler::OpenUrl_RequestPost( int from, int to )
{
	bstr cookie = "";	// cookie 
	GetCookieString( cookie );
	bstr range = "";	// range
	GetRangeString( range, from, to );
	bstr param;			// url parameter
	GetParamString( param );

	bstr req_string;	// complete request string
	req_string.alloc( m_urlItem.length() + cookie.length() + 256 );
	sprintf( req_string, 
		"POST /%s HTTP/1.0\r\n"
		"Host: %s:%s\r\n"
		"Content-Type: application/x-www-form-urlencoded\r\n"
		"Content-Length: %d\r\n"
		"%s"
		"%s"
		"\r\n"
		"%s\r\n",	
		(char *) m_urlItem.sub_addr, 
		(char *) m_urlItem.addr, (char *) m_urlItem.port, 
		strlen( param ),
		(char *) cookie, 
		(char *) range,
		(char *) param );
	
	m_status.nStatus			= HTTP_STAT_REQUESTING;
	m_status.nContentLength		= strlen( req_string );
	m_status.nBytesTransferred	= 0;
	if ( !CallbackStatus() )
		return HTTP_CANCEL;

	return Send( req_string, strlen( req_string ) );
}


int CHttpHandler::OpenUrl_RequestMultipart()
{
	bstr cookie = "";
	GetCookieString( cookie );

	int nContentLength = GetMultipartContentLength();

	bstr req_header;
	req_header.alloc( m_urlItem.length() + cookie.length() + 256 );
	sprintf( req_header,
		"POST /%s HTTP/1.0\r\n"
		"Host: %s:%s\r\n"
		"Content-Type: multipart/form-data; boundary=%s\r\n"
		"Content-Length: %d\r\n"
		"%s"
		"\r\n",
		(char *) m_urlItem.sub_addr, 
		(char *) m_urlItem.addr, (char *) m_urlItem.port, 
		HTTP_MULTIPART_BOUNDARY,
		nContentLength,
		(char *) cookie );

	m_status.nStatus			= HTTP_STAT_REQUESTING;
	m_status.nContentLength		= nContentLength + strlen( req_header );
	m_status.nBytesTransferred	= 0;
	if ( !CallbackStatus() )
		return HTTP_CANCEL;

	int nRetCode;
	if ( (nRetCode = Send( req_header, strlen( req_header ) )) != HTTP_SUCCESS )
		return nRetCode;

	CListNode< CHttpParam >	*node = m_listParam.GetHead();
	CHttpParam				*data;
	bstr					disp_string;

	while ( node )
	{
		data = node->GetData();
		
		GetDispString( disp_string, data );
		if ( (nRetCode = Send( disp_string, strlen( disp_string ) )) != HTTP_SUCCESS )
			return nRetCode;

		if ( data->bFile )
		{
			if ( (nRetCode = SendFile( data->szValue )) != HTTP_SUCCESS )
				return nRetCode;
		}
		else
		{
			if ( (nRetCode = Send( data->szValue, strlen( data->szValue ) )) != HTTP_SUCCESS )
				return nRetCode;
		}

		if ( (nRetCode = Send( "\r\n", 2 )) != HTTP_SUCCESS )
			return nRetCode;

		if ( (node = node->GetNext()) == NULL )
			break;
	}

	char end_string[256];
	sprintf( end_string, "--%s--\r\n", HTTP_MULTIPART_BOUNDARY );
	if ( (nRetCode = Send( end_string, strlen( end_string ) )) != HTTP_SUCCESS )
			return nRetCode;
	
	return HTTP_SUCCESS;
}


int CHttpHandler::OpenUrl_RespondContent( char *pSavePath, bool bOverwrite )
{
	m_status.nStatus = HTTP_STAT_RESPONDING;
	m_status.nContentLength	   = 0;
	m_status.nBytesTransferred = 0;
	if ( !CallbackStatus() )
		return Disconnect(), HTTP_CANCEL;

	if ( pSavePath == NULL )
		return RecvContent();
	else
		return RecvContentToFile( pSavePath, bOverwrite );
}


void CHttpHandler::OpenUrl_Disconnect()
{
	Disconnect();
}


void CHttpHandler::SplitUrlItems( char *url )
{
	CUrl::Split( url, &m_urlItem );

	if ( !m_urlItem.proto.isassign() )
		m_urlItem.proto = "HTTP";

	if ( !m_urlItem.port.isassign() )
		m_urlItem.port = "80";
}


void CHttpHandler::GetCookieString( bstr &str )
{
	CListNode< CHttpCookie > *node = m_listCookie.GetHead();
	if ( !node )
		return;

	CHttpCookie	*data;

	str = "Cookie: ";

	while ( node )
	{
		data = node->GetData();

		str += data->szName;
		str += "=";
		str += data->szValue;

		if ( node = node->GetNext() )
			str += "; ";
		else
			break;
	}

	str += "\r\n";
}


void CHttpHandler::GetRangeString( bstr &str, int from, int to )
{
	if ( from <= 0 && to <= 0 )
		return;

	// format> Range: bytes=[from]-[to]
	str  = "Range: bytes=";
	str += from;
	str += "-";
	if ( to > 0 ) str += to;
	str += "\r\n";
}


void CHttpHandler::GetParamString( bstr &str )
{
	CListNode< CHttpParam >	*node = m_listParam.GetHead();
	if ( !node )
		return;

	CHttpParam *data;

	while ( node )
	{
		data = node->GetData();

		str += data->szName;
		str += "=";
		str += data->szValue;

		if ( node = node->GetNext() )
			str += "&";
		else
			break;
	}
}


int CHttpHandler::GetMultipartContentLength()
{
	CListNode< CHttpParam >	*node = m_listParam.GetHead();
	if ( !node )
		return 0;

	CHttpParam	*data;
	int			total_len = 0;
	bstr		str;

	while ( node )
	{
		data = node->GetData();

		GetDispString( str, data );
		total_len += (strlen( str ) + 2);

		if ( data->bFile )
			total_len += CFile::GetLength( data->szValue );
		else
			total_len += strlen( data->szValue );

		if ( (node = node->GetNext()) == NULL )
			break;
	}

	// --BOUNDARY--\r\n
	total_len += (strlen( HTTP_MULTIPART_BOUNDARY ) + 6);

	return total_len;
}


void CHttpHandler::GetDispString( bstr &str, CHttpParam *param )
{
	str  = "--"; // multipart item 'start' sign
	str += HTTP_MULTIPART_BOUNDARY;
	str += "\r\n";

	str += "Content-Disposition: form-data; name=\"";
	str += param->szName;
	str += "\"";

	if ( param->bFile )
	{
		str += "; filename=\"";
		str += param->szValue;
		str += "\"";
	}

	str += "\r\n\r\n";
}


void CHttpHandler::InsertReturnedCookie()
{
	static char *pToken = "Set-Cookie: ";

	char *pNext = strstr( m_szRespHeader, pToken );
	bstr szLine;
	
	while ( pNext )
	{
		_linecopy( &szLine, pNext );

		if ( strnicmp( szLine, pToken, strlen( pToken ) ) == 0 )
		{
			if ( InsertCookie( (char *) szLine + strlen( pToken ) ) == false )
				break;
		}

		pNext = strstr( pNext, "\r\n" );
		if ( pNext )
			pNext += strlen( "\r\n" );
	}
}


int CHttpHandler::RedirectUrl( int nMethod, PHTTP_CALLBACK pfnStatus, void *pContext, int nFlag )
{
	char szLocation[HTTP_MAXBUF] = {0,};
	if ( CIMsgFormat::QueryString( m_szRespHeader, "location", szLocation, sizeof( szLocation ) ) &&
		*szLocation )
	{
		// cleanup previous allocated buffers
		m_qRecv.ClearAll();
		m_urlItem.sub_addr = "";

		// if locate indicates relative url, append current base url
		if ( strnicmp( szLocation, "http", strlen( "http" ) ) != 0 )
		{
			bstr szAbsoluteURL = m_urlItem.addr + "/" + szLocation;

			return OpenUrl( nMethod, szAbsoluteURL, pfnStatus, pContext, nFlag );
		}
		
		return OpenUrl( nMethod, szLocation, pfnStatus, pContext, nFlag );
	}

	// there is no indicator. (location field not found)
	return HTTP_SUCCESS;
}


int CHttpHandler::RedirectFile( char *pSavePath, bool bOverwrite, PHTTP_CALLBACK pfnStatus, void *pContext )
{
	char szLocation[HTTP_MAXBUF] = {0,};
	if ( CIMsgFormat::QueryString( m_szRespHeader, "location", szLocation, sizeof( szLocation ) ) &&
		*szLocation )
	{
		// cleanup previous allocated buffer
		m_qRecv.ClearAll();
		m_urlItem.sub_addr = "";

		// if locate indicates relative url, append current base url
		if ( strnicmp( szLocation, "http", strlen( "http" ) ) != 0 )
		{
			bstr szAbsoluteURL = m_urlItem.addr + "/" + szLocation;

			return OpenFile( szAbsoluteURL, pSavePath, bOverwrite, pfnStatus, pContext );
		}
		
		return OpenFile( szLocation, pSavePath, bOverwrite, pfnStatus, pContext );
	}

	// there is no indicator. (location field not found)
	return HTTP_SUCCESS;
}


bool CHttpHandler::Connect( CSockAddr *pAddr )
{
	m_sdHost = socket( AF_INET, SOCK_STREAM, 0 );
	if ( m_sdHost == INVALID_SOCKET )
		return false;

	if ( connect( m_sdHost, pAddr, sizeof( SOCKADDR ) ) == SOCKET_ERROR )
		return false;

	return true;
}


void CHttpHandler::Disconnect()
{
	if ( m_sdHost != INVALID_SOCKET )
	{
		shutdown( m_sdHost, SD_BOTH );
		closesocket( m_sdHost );
		m_sdHost = INVALID_SOCKET;
	}
}


int CHttpHandler::Send( char *pBuf, int nBufLen )
{
	int nTotalLen = 0;
	int nSendLen;

	while ( nTotalLen < nBufLen )
	{
		nSendLen = send( m_sdHost, pBuf + nTotalLen, nBufLen - nTotalLen, 0 );
		if ( nSendLen < 0 )
			return HTTP_ERR_REQUESTING;

		nTotalLen += nSendLen;

		m_status.nBytesTransferred += nSendLen;
		if ( !CallbackStatus() )
			return HTTP_CANCEL;
	}

	return HTTP_SUCCESS;
}


int CHttpHandler::SendFile( char *pPath )
{
	CFile file;
	if ( file.Open( pPath, "rb" ) == false )
		return HTTP_ERR_GENERAL;

	char buf[HTTP_MAXBUF];
	int  nReadLen;
	int  nRetCode;

	while ( !file.IsEnd() )
	{
		nReadLen = file.Read( buf, sizeof( buf ) );

		if ( (nRetCode = Send( buf, nReadLen )) != HTTP_SUCCESS )
			return nRetCode;
	}

	return nRetCode;
}


int CHttpHandler::RecvContent()
{
	char buf[HTTP_MAXBUF];
	int  nRecvLen;
	bool bProcessHeader = true;
	char *pNext;

	while ( true )
	{
		nRecvLen = recv( m_sdHost, buf, sizeof( buf ), 0 );
		if ( nRecvLen < 0 )
			return HTTP_ERR_RESPONDING;
		if ( nRecvLen == 0 )
			break;

		m_qRecv.Append( buf, nRecvLen );

		if ( bProcessHeader )
		{
			if ( (pNext = strstr( m_qRecv, "\r\n\r\n" )) )
				pNext += 4;
			else if ( (pNext = strstr( m_qRecv, "\n\n" )) )
				pNext += 2;

			if ( pNext )
			{
				m_szRespHeader.assign( m_qRecv, pNext - m_qRecv );
				m_qRecv.Remove( pNext - m_qRecv );

				_pickstring( m_szRespHeader, ' ', 1, buf, sizeof( buf ) );
				m_nRespCode = atoi( buf );
				
				m_status.nContentLength = GetContentLength();
				m_status.nBytesTransferred += m_qRecv.Length();
				if ( !CallbackStatus() )
					return HTTP_CANCEL;

				bProcessHeader = false;
			}
		}
		else
		{
			m_status.nBytesTransferred += nRecvLen;
			if ( !CallbackStatus() )
				return HTTP_CANCEL;
		}
	}

	m_qRecv.Append( "\000", 1 ); // append NULL

	return HTTP_SUCCESS;
}


int CHttpHandler::RecvContentToFile( char *pPath, bool bOverwrite )
{
	char buf[HTTP_MAXBUF];
	int  nRecvLen;
	bool bProcessHeader = true;
	char *pNext;

	CFile file;
	if ( !file.Open( pPath, bOverwrite ? "wb" : "ab" ) )
		return HTTP_ERR_GENERAL;

	while ( true )
	{
		nRecvLen = recv( m_sdHost, buf, sizeof( buf ), 0 );
		if ( nRecvLen < 0 )
			return HTTP_ERR_RESPONDING;
		if ( nRecvLen == 0 )
			break;

		if ( bProcessHeader )
		{
			m_qRecv.Append( buf, nRecvLen );

			if ( (pNext = strstr( m_qRecv, "\r\n\r\n" )) )
				pNext += 4;
			else if ( (pNext = strstr( m_qRecv, "\n\n" )) )
				pNext += 2;

			if ( pNext )
			{
				m_szRespHeader.assign( m_qRecv, pNext - m_qRecv );
				m_qRecv.Remove( pNext - m_qRecv );

				_pickstring( m_szRespHeader, ' ', 1, buf, sizeof( buf ) );
				m_nRespCode = atoi( buf );

				int nFileLength = file.GetLength();
				
				if ( !bOverwrite &&
					 nFileLength &&
					 nFileLength == GetContentLength() )
				{
					return HTTP_SUCCESS;
				}
				
				m_status.nContentLength = GetContentLength();
				m_status.nBytesTransferred += m_qRecv.Length();
				if ( !CallbackStatus() )
					return HTTP_CANCEL;
				file.Write( m_qRecv, m_qRecv.Length() );
				m_qRecv.ClearAll();

				bProcessHeader = false;
			}
		}
		else
		{
			m_status.nBytesTransferred += nRecvLen;
			if ( !CallbackStatus() )
				return HTTP_CANCEL;
			file.Write( buf, nRecvLen );
		}
	}

	return HTTP_SUCCESS;
}


bool CHttpHandler::CallbackStatus()
{
	if ( !m_pfnStatus )
		return true;

	return m_pfnStatus( m_pStatusContext, &m_status );
}


int CHttpHandler::__cbCmpCookie( void *pArg, CHttpCookie *pFirst, CHttpCookie *pSecond )
{
	return stricmp( (char *) pFirst, pSecond->szName );
}


int CHttpHandler::__cbCmpParam ( void *pArg, CHttpParam  *pFirst, CHttpParam  *pSecond )
{
	return stricmp( (char *) pFirst, pSecond->szName );
}


static struct HTTP_ERRMSG
{
	int  code;
	char msg[256];
} g_errMsg[] = 
{
	100,	"100 Continue",
	101,	"101 Switching Protocols",

	200,	"200 OK",
	201,	"201 Created",
	202,	"202 Accepted",
	203,	"203 Non-Authoritative Information",
	204,	"204 No Content",
	205,	"205 Reset Content",
	206,	"206 Partial Content",

	300,	"300 Multiple Choices",
	301,	"301 Moved Permanently",
	302,	"302 Moved Temporarily",
	303,	"303 See Other",
	304,	"304 Not Modified",
	305,	"305 Use Proxy",

	400,	"400 Bad Request",
	401,	"401 Unauthorized",
	402,	"402 Payment Required",
	403,	"403 Forbidden",
	404,	"404 Not Found",
	405,	"405 Method Not Allowed",
	406,	"406 Not Acceptable",
	407,	"407 Proxy Authentification Required",
	408,	"408 Request Time-out",
	409,	"409 Confict",
	410,	"410 Gone",
	411,	"411 Length Required",
	412,	"412 Precondition Failed",
	413,	"413 Request Entity Too Large",
	414,	"414 Request-URI Too Long",
	415,	"415 Unsupported Media Type",
	416,	"416 Invalid Range Requested",

	500,	"500 Internal Server Error",
	501,	"501 Not Implemented",
	502,	"502 Bad Gateway",
	503,	"503 Service Unavailable",
	504,	"504 Gateway Time-out",
	505,	"505 HTTP Version Not Supported",
};

static int g_msgCnt = sizeof( g_errMsg ) / sizeof( g_errMsg[0] );


void CHttpHandler::OutputErrMsg()
{
	for ( int i = 0; i < g_msgCnt; i++ )
	{
		if ( g_errMsg[i].code == m_nRespCode )
		{
			OutputDebugString( g_errMsg[i].msg );
			OutputDebugString( "\n" );
			break;
		}
	}
}


void CHttpHandler::ErrMsgBox()
{
	for ( int i = 0; i < g_msgCnt; i++ )
	{
		if ( g_errMsg[i].code == m_nRespCode )
		{
			MessageBox( NULL, g_errMsg[i].msg, "Error", MB_ICONWARNING );
			break;
		}
	}
}


char * CHttpHandler::ErrMsg()
{
	for ( int i = 0; i < g_msgCnt; i++ )
	{
		if ( g_errMsg[i].code == m_nRespCode )
		{
			return g_errMsg[i].msg;
		}
	}

	return NULL;
}


int CHttpHandler::ErrCode()
{
	return m_nRespCode;
}