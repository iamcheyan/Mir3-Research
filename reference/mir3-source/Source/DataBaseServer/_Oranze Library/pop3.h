

/*
	POP3 Handler

	Date:
		2001/10/29
*/
#ifndef __ORZ_NETWORK_POP3_HANDLER__
#define __ORZ_NETWORK_POP3_HANDLER__


#include "netbase.h"
#include "streambf.h"
#include "list.h"


#define POP3_MAXBUF			4096
#define POP3_MAXUIDL		80

#define POP3_NEWLINE		"\r\n"
#define POP3_ENDOFMSG		POP3_NEWLINE "." POP3_NEWLINE

#define POP3_SUCCESS		1
#define POP3_ERR_CONNECT	-1
#define POP3_ERR_AUTH		-2


class CPop3Status
{
public:
	int  nIndex;
	int  nBytesRecv;
	int  nBytesTotal;
};


class CPop3Uidl
{
public:
	int  nIndex;
	char szUidl[POP3_MAXUIDL];
};


typedef CList< CPop3Uidl >		CPop3UidlList;
typedef CListNode< CPop3Uidl >	CPop3UidlNode;


class CPop3Handler : public CNetBase
{
public:
	SOCKET					m_sdHost;
	CStreamBuffer< char >	m_qRecv;
	char					m_szCurRespLine[POP3_MAXBUF];

public:
	CPop3Handler();
	virtual ~CPop3Handler();

	int  Connect( CSockAddr *pAddr, char *pUser, char *pPass );
	int  Connect( char *pAddr, short nPort, char *pUser, char *pPass );
	void Disconnect();

	int  GetNumMsgs();
	bool GetMsgUidlList( CPop3UidlList *pList );
	bool GetMsgUidl( int nIndex, char *pUidl );
	bool DeleteMsg( int nIndex );
	int  GetMsgSize( int nIndex );
	bool GetMsg( int nIndex, char **ppDest, int *pDestLen, 
				 bool (*pfnCallback)( void *pContext, CPop3Status *pStatus ) = NULL, 
				 void *pContext = NULL);
	bool Quit();

protected:
	bool GetResponseCode();
	bool Request( char *pMsg, ... );
};


#endif