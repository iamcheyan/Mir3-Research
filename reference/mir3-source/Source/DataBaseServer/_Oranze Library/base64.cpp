

#include "base64.h"
#include "util.h"
#include <memory.h>


static char g_szBase64Table[] = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/";


bool CBase64::Encode( char *pRaw, int nRawLen, char **ppDest, int *pDestLen )
{
	int nAllocLen = (nRawLen * 4) / 3;
	nAllocLen = _roundup( nAllocLen, 4 );

	*ppDest = new char[ nAllocLen + 1 ];
	if ( !*ppDest )
		return false;
	
	*pDestLen = 0;

	for ( int i = 0; i < nRawLen; i += 3 )
	{
		EncodeChunk( (byte *) &pRaw[i], 
					 (byte *) &(*ppDest)[*pDestLen], 
					 (nRawLen - i) >= 3 ? 3 : nRawLen - i );

		*pDestLen += 4;
	}

	(*ppDest)[ *pDestLen ] = '\0';

	return true;
}


bool CBase64::Decode( char *pRaw, int nRawLen, char **ppDest, int *pDestLen )
{
	int nAllocLen = (nRawLen * 3) / 4;

	*ppDest = new char[ nAllocLen + 1 ];
	if ( !*ppDest )
		return false;
 
	*pDestLen = 0;

	byte in[4];		
	byte inPos = 0;	
	byte out[3];	
	byte outBytes;	

	for ( int i = 0; i < nRawLen; i++ )
	{
		if ( pRaw[i] != '\r' && pRaw[i] != '\n' && pRaw[i] != ' ' )
			in[inPos++] = pRaw[i];

		if ( inPos == 4 )
		{
			outBytes = DecodeChunk( in, out );
			
			memcpy( *ppDest + *pDestLen, out, outBytes );
			*pDestLen += outBytes;

			inPos = 0;
		}
	}

	(*ppDest)[ *pDestLen ] = '\0';

	return true;
}


byte CBase64::FindBase64Val( char c )
{
	for ( int i = 0; i < 64; i++ )
	{
		if ( g_szBase64Table[i] == c )
			return i;
	}

	return (byte) -1;
}


void CBase64::EncodeChunk( byte *in, byte *out, byte count )
{
	byte index1, index2, index3, index4;
	index1 =  ((in[0] >> 2) & 63);
	index2 = (((in[0] << 4) & 48) | ((in[1] >> 4) & 15));
	index3 = (((in[1] << 2) & 60) | ((in[2] >> 6) & 3));
	index4 = (in[2] & 63);
	
	out[0] = g_szBase64Table[ index1 ];
	out[1] = g_szBase64Table[ index2 ];
	out[2] = g_szBase64Table[ index3 ];
	out[3] = g_szBase64Table[ index4 ];

	// 패딩 문자를 추가한다.
	switch ( count )
	{
	case 1:
		out[2] = '=';
	case 2:
		out[3] = '=';
	}
}


byte CBase64::DecodeChunk( byte *in, byte *out )
{
	byte c1, c2, c3, c4;
	c1 = FindBase64Val( in[0] );
	c2 = FindBase64Val( in[1] );
	c3 = FindBase64Val( in[2] );
	c4 = FindBase64Val( in[3] );

	out[0] = (byte) (((c1 & 63) << 2)	| ((c2 & 48) >> 4));
	out[1] = (byte) (((c2 & 15) << 4)	| ((c3 & 60) >> 2));
	out[2] = (byte) (((c3 & 3)  << 6)	|  (c4 & 63));

	// 패딩 문자('=')를 찾아 실제 길이를 구한다.
	// 1byte를 인코딩하는데 최소 2바이트가 필요하므로 3번째 바이트부터 검사한다.
	if ( in[2] == '=' )
		return 1;

	if ( in[3] == '=' )
		return 2;

	return 3;
}