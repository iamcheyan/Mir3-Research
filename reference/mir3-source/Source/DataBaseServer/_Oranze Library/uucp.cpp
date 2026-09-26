

#include "uucp.h"
#include "datatype.h"
#include <stdio.h>
#include <windows.h>


#define DEC(c)	(((c) - ' ') & 077)


bool CUuDecoder::IsEncoded( char *pRaw )
{
	__try
	{
		char fileAccessMode[4];
		char fileName[MAX_PATH];
		
		if ( sscanf( pRaw, "begin %s %s", fileAccessMode, fileName ) < 2 )
			return false;
	}
	__except ( EXCEPTION_EXECUTE_HANDLER )
	{
		return false;
	}

	return true;
}


bool CUuDecoder::Decode( char *pRaw, int nRawLen, char *pName, char **ppDest, int *pDestLen )
{
	int nAllocLen = (nRawLen * 3) / 4;

	*ppDest = new char[ nAllocLen + 1 ];
	if ( !*ppDest )
		return false;

	*pDestLen = 0;
	
	char fileAccessMode[4];
	int  count;

	__try
	{
		// 헤더를 찾는다.
		// format: begin [unix_file_mode] [file_name]
		pRaw = strstr( pRaw, "begin " );		
		sscanf( pRaw, "begin %s %s", fileAccessMode, pName );

		do
		{
			// 다음 줄로 이동
			pRaw = strstr( pRaw, "\r\n" ) + 2;

			// UuCP의 끝인가?
			if ( strnicmp( pRaw, "end\r\n", 5 ) == 0 )
				break;

			// 한줄의 길이를 얻어온다.
			count = DEC( *pRaw++ );
			if ( count <= 0 )
				break;

			// 한줄을 디코딩한다.
			while ( count > 0 )
			{
				// 4byte -> 3byte
				DecodeChunk( pRaw, *ppDest + *pDestLen, count );

				if ( count >= 3 )
					*pDestLen += 3;
				else
					*pDestLen += count;

				pRaw += 4;
				count -= 3;				
			}

		} while ( true );
	}
	__except ( EXCEPTION_EXECUTE_HANDLER )
	{
		delete[] *ppDest;
		return false;
	}

	(*ppDest)[ *pDestLen ] = '\0';

	return true;
}


void CUuDecoder::DecodeChunk( char *in, char *out, int count )
{
	byte c1, c2, c3;

	c1 = (DEC( in[0] ) << 2) | (DEC( in[1] ) >> 4);
	c2 = (DEC( in[1] ) << 4) | (DEC( in[2] ) >> 2);
	c3 = (DEC( in[2] ) << 6) | (DEC( in[3] ) >> 0);

	if ( count >= 1 )
		out[0] = (char) c1;
	if ( count >= 2 )
		out[1] = (char) c2;
	if ( count >= 3 )
		out[2] = (char) c3;
}