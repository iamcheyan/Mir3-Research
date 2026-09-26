

/*
	URL(Uniform Resource Locators) Class (RFC 1738)

	Date:
		2001/11/13
*/
#ifndef __ORZ_NETWORK_URL_PARSER__
#define __ORZ_NETWORK_URL_PARSER__


#include "stringex.h"


class CUrlItem
{
public:
	bstr	proto;
	bstr	addr;
	bstr	port;
	bstr	sub_addr;

public:
	int		length();
};


class CUrl
{
public:
	static void Split( char *pUrl, CUrlItem *pInfo );

	static bool Encode( char *pRaw, int nRawLen, char **ppDest, int *pDestLen );
	static bool Decode( char *pRaw, int nRawLen, char **ppDest, int *pDestLen );

	static bool ExtractValue( char *pRaw, char *pName, char *pValue, int nValueLen );

protected:
	static bool IsRequireEncoding( char c );
};


#endif