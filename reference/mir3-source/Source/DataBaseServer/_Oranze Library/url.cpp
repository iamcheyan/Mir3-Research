

#include "url.h"
#include "datatype.h"
#include "util.h"
#include <stdio.h>


int CUrlItem::length()
{
	return proto.length() + addr.length() + port.length() + sub_addr.length();
}




void CUrl::Split( char *url, CUrlItem *info )
{
	char *next, *splt; // next pointer & spliting pointer

	// get protocol type
	next = strstr( url, "://" );
	if ( next )
	{
		info->proto.assign( url, next - url );
		url += (next - url) + 3;
	}

	// split address and port
	next = strchr( url, '/' );
	splt = strchr( url, ':' );	
	if ( next )
	{
		if ( splt && splt < next )
		{
			info->addr.assign( url, splt - url );
			info->port.assign( splt + 1, next - (splt + 1) );
		}
		else
		{
			info->addr.assign( url, next - url );
		}
		
		info->sub_addr = next + 1;
	}
	else
	{
		if ( splt )
		{
			info->addr.assign( url, splt - url );
			info->port = splt + 1;
		}
		else
		{
			info->addr = url;
		}
	}
	
	// encode sub_addr to url encoding type
	char *temp;
	int  temp_len;
	if ( CUrl::Encode( info->sub_addr, info->sub_addr.length(), &temp, &temp_len ) )
	{
		info->sub_addr = temp;
		delete[] temp;
	}
}


bool CUrl::Encode( char *pRaw, int nRawLen, char **ppDest, int *pDestLen )
{
	int nAllocLen = nRawLen * 3; // it can be 3 times greater than plain text
	
	*ppDest = new char[ nAllocLen + 1 ];
	if ( !*ppDest )
		return false;

	*pDestLen = 0;

	for ( int i = 0; i < nRawLen; i++ )
	{
		if ( IsRequireEncoding( pRaw[i] ) )
		{
			(*ppDest)[(*pDestLen)++] = '%';
			_dectohex( (byte) pRaw[i], *ppDest + *pDestLen, 2 );
			*pDestLen += 2;
		}
		else if ( (byte) pRaw[i] >= 0x80 ) // 2 byte character
		{			
			(*ppDest)[(*pDestLen)++] = '%';
			_dectohex( (byte) pRaw[i], *ppDest + *pDestLen, 2 );
			*pDestLen += 2;

			(*ppDest)[(*pDestLen)++] = '%';
			_dectohex( (byte) pRaw[++i], *ppDest + *pDestLen, 2 );
			*pDestLen += 2;
		}
		else
		{
			(*ppDest)[(*pDestLen)++] = pRaw[i];
		}
	}

	(*ppDest)[ *pDestLen ] = '\0';

	return true;
}


bool CUrl::Decode( char *pRaw, int nRawLen, char **ppDest, int *pDestLen )
{
	int nAllocLen = nRawLen;
	
	*ppDest = new char[ nAllocLen + 1 ];
	if ( !*ppDest )
		return false;

	*pDestLen = 0;

	for ( int i = 0; i < nRawLen; i++ )
	{
		if ( pRaw[i] == '%' )
		{
			++i; // skip character '%'
			(*ppDest)[(*pDestLen)++] = _hextodec( &pRaw[i++], 2 );
		}
		else if ( pRaw[i] == '+' )
		{
			(*ppDest)[(*pDestLen)++] = ' ';
		}
		else
		{
			(*ppDest)[(*pDestLen)++] = pRaw[i];
		}
	}

	(*ppDest)[ *pDestLen ] = '\0';
	
	return true;
}


bool CUrl::ExtractValue( char *pRaw, char *pName, char *pValue, int nValueLen )
{
	char *findName = new char[ strlen( pName ) + 2 ]; // 2: '=' + 'NULL'
	sprintf( findName, "%s=", pName );

	char *ptr = _memistr( pRaw, strlen( pRaw ), findName );
	if ( !ptr )
		return false;

	pRaw = ptr + strlen( findName );

	int extractLen = strlen( pRaw );
	if ( ptr = strchr( pRaw, '&' ) )
		extractLen = ptr - pRaw;	

	if ( extractLen >= nValueLen )
		return false;

	strncpy( pValue, pRaw, extractLen );
	pValue[ extractLen ] = '\0';

	return true;
}


bool CUrl::IsRequireEncoding( char c )
{	
	// alphanumerics are not required
	if ( (c >= '0' && c <= '9') || (c >= 'A' && c <= 'Z') || (c >= 'a' && c <= 'z') )
		return false;
	
	// this special characters are not required to be encoded
	static char g_szSpecialTable[] = "%?=&$-_+.!*'(),/";

	for ( int i = 0; i < sizeof( g_szSpecialTable ); i++ )
	{
		if ( g_szSpecialTable[i] == c )
			return false;
	}

	return true;
}
