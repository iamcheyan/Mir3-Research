

#ifndef _LEGENDOFMIR_ENDECODE
#define _LEGENDOFMIR_ENDECODE


#include <windows.h>


#define _DEFBLOCKSIZE		22//16


typedef struct tag_TDEFAULTMESSAGE
{
	int		nRecog;
	WORD	wIdent;
	WORD	wParam;
	WORD	wTag;
	WORD	wSeries;
	WORD	wEtc;
	WORD	wEtc2;
} _TDEFAULTMESSAGE, *_LPTDEFAULTMESSAGE;


typedef struct tag_TMSGHEADER
{
	int		nCode;
	int		nSocket;
	WORD	wUserGateIndex;
	WORD	wIdent;
	WORD	wUserListIndex;
	WORD	wTemp;
	int		nLength;
} _TMSGHEADER, *_LPTMSGHEADER;

//---------------------------------
void LoadPublicKey( char *fname );
void SetPublicKey( WORD pubkey );
WORD GetPublicKey( void );
WORD GetSavedKey( void );
void ChangeByDefaultKey( void );
void ChangeBySavedKey( void );
//---------------------------------

int  WINAPI fnEncode6BitBuf(unsigned char *pszSrc, char *pszDest, int nSrcLen, int nDestLen);
int  WINAPI fnDecode6BitBuf(char *pwszSrc, char *pszDest, int nDestLen);
int  WINAPI fnEncode6BitBuf_old(unsigned char *pszSrc, char *pszDest, int nSrcLen, int nDestLen);
int  WINAPI fnDecode6BitBuf_old(char *pwszSrc, char *pszDest, int nDestLen);
int  WINAPI fnEncodeMessage(_LPTDEFAULTMESSAGE lptdm, char *pszBuf, int nLen);

__inline void  WINAPI fnDecodeMessage(_LPTDEFAULTMESSAGE lptdm, char *pszBuf)
{ 
	fnDecode6BitBuf(pszBuf, (char *)lptdm, sizeof(_TDEFAULTMESSAGE)); 
}

__inline void WINAPI fnMakeDefMessage(_LPTDEFAULTMESSAGE lptdm, WORD wIdent, int nRecog, WORD wParam, WORD wTag, WORD wSeries)
{ 
	lptdm->wIdent	= wIdent; 
	lptdm->nRecog	= nRecog; 
	lptdm->wParam	= wParam; 
	lptdm->wTag		= wTag; 
	lptdm->wSeries	= wSeries; 
}


/*
	ORZ: Decoding 유틸 추가
*/
class CDecodedString
{
public:
	char *m_pData;

public:
	CDecodedString( int nDataLen ) { m_pData = new char[nDataLen];}
	virtual ~CDecodedString() { if ( m_pData ) delete[] m_pData; }

	operator char * ()				{ return m_pData; }
	operator const char * const ()	{ return (const char *) m_pData; }
};


CDecodedString * WINAPI fnDecodeString( char *src );

void ChangeSpaceToNull(char *pszData);

#endif