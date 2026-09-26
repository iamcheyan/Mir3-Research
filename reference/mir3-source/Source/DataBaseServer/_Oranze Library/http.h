

/*
	Http Handler

	Date:
		2001/11/30 (Last Updated: 2001/12/19)
*/
#ifndef __ORZ_NETWORK_HTTP_HANDLER__
#define __ORZ_NETWORK_HTTP_HANDLER__


#include "netbase.h"
#include "streambf.h"
#include "list.h"
#include "url.h"
#include "stringex.h"


#define HTTP_MAXBUF					4096

#define HTTP_GET					1
#define HTTP_POST					2
#define HTTP_MULTIPART				3

#define HTTP_MULTIPART_BOUNDARY		"--------------------------------boundary.from.orzlib"

#define HTTP_ENCODING_NONE			1
#define HTTP_ENCODING_URL			2
#define HTTP_ENCODING_BASE64		3

#define HTTP_STAT_CONNECTING		1
#define HTTP_STAT_REQUESTING		2
#define HTTP_STAT_RESPONDING		3

#define HTTP_FLAG_NO_AUTO_REDIRECT	0x0001
#define HTTP_FLAG_NO_AUTO_COOKIE	0x0002

#define HTTP_SUCCESS				1
#define HTTP_CANCEL					-1
#define HTTP_ERR_GENERAL			-2
#define HTTP_ERR_CONNECTING			-3
#define HTTP_ERR_REQUESTING			-4
#define HTTP_ERR_RESPONDING			-5
#define HTTP_ERR_INVALID_METHOD		-9


class CHttpHandler;
class CHttpStatus
{
public:
	char *pUrl;
	int  nStatus;
	int  nContentLength;
	int  nBytesTransferred;

	CHttpHandler *pHandler;

public:
	CHttpStatus() : pUrl( NULL ), 
					nStatus( 0 ), 
					nContentLength( 0 ), 
					nBytesTransferred( 0 ),
					pHandler( NULL )
	{}
};


typedef bool (*PHTTP_CALLBACK)( void *pContext, CHttpStatus *pStatus );


class CHttpHandler : public CNetBase
{
protected:
	class CHttpCookie
	{
	public:
		bstr szName;
		bstr szValue;
	};
	
	class CHttpParam
	{
	public:		
		bstr szName;
		bstr szValue;
		
		bool bFile;
		
	public:
		CHttpParam() : bFile( false ) {}
	};

public:
	SOCKET					m_sdHost;		// socket descriptor

	CUrlItem				m_urlItem;		// splited url items
	CList< CHttpCookie >	m_listCookie;	// cookie list to be attached
	CList< CHttpParam >		m_listParam;	// parameter list to be attached
	
	CStreamBuffer< char >	m_qRecv;		// recv queue (resopnse storage)
	bstr					m_szRespHeader;	// response header
	int						m_nRespCode;	// response code from http server

	CHttpStatus				m_status;		// current http status
	PHTTP_CALLBACK			m_pfnStatus;
	void					*m_pStatusContext;

public:
	CHttpHandler();
	virtual ~CHttpHandler();

	void Reset();
	
	bool InsertCookie( char *pCookieList );
	bool InsertCookie( char *pName, char *pValue );
	bool InsertParam ( char *pParamList, int nEncodingType = HTTP_ENCODING_URL );
	bool InsertParam ( char *pName, char *pValue, int nEncodingType = HTTP_ENCODING_URL );
	bool InsertFile  ( char *pName, char *pPath );

	int  OpenUrl ( int  nMethod, 
				   char *pUrl, 
				   PHTTP_CALLBACK pfnStatus = NULL,
				   void *pContext = NULL,
				   int  nFlag = 0 );

	int  OpenFile( char *pUrl,
				   char *pSavePath, 
				   bool bOverwrite = true,
				   PHTTP_CALLBACK pfnStatus = NULL,
				   void *pContext = NULL,
				   int  nFlag = 0 );

	/*
		Functions for HTTP Response
	*/
	char * GetHeader();
	int  GetContentLength();
	char * GetContent();

protected:
	int  OpenUrl_Connect( char *pUrl );
	int  OpenUrl_RequestGet ( int from = 0, int to = 0 );
	int  OpenUrl_RequestPost( int from = 0, int to = 0 );
	int  OpenUrl_RequestMultipart();
	int  OpenUrl_RespondContent( char *pSavePath = NULL, bool bOverwrite = true );
	void OpenUrl_Disconnect();

	void SplitUrlItems( char *url );
	void GetCookieString( bstr &str );
	void GetRangeString( bstr &str, int from, int to );
	void GetParamString( bstr &str );
	int  GetMultipartContentLength();
	void GetDispString( bstr &str, CHttpParam *param );
	void InsertReturnedCookie();
	int  RedirectUrl( int nMethod, PHTTP_CALLBACK pfnStatus, void *pContext, int nFlag );
	int  RedirectFile( char *pSavePath, bool bOverwrite, PHTTP_CALLBACK pfnStatus, void *pContext );

	bool Connect( CSockAddr *pAddr );
	void Disconnect();
	int  Send( char *pBuf, int nBufLen );
	int  SendFile( char *pPath );
	int  RecvContent();
	int  RecvContentToFile( char *pPath, bool bOverwrite );

	bool CallbackStatus();

	static int __cbCmpCookie( void *pArg, CHttpCookie *pFirst, CHttpCookie *pSecond );
	static int __cbCmpParam ( void *pArg, CHttpParam  *pFirst, CHttpParam  *pSecond );

public:
	/*
		Retrieve Error Message
	*/
	void OutputErrMsg();
	void ErrMsgBox();
	char * ErrMsg();
	int	 ErrCode();
};


#endif