

/*
	Quoted Printable Type Encoder/Decoder

	Date:
		2001/10/26
*/
#ifndef __ORZ_NETWORK_QUOTED_PRINTABLE__
#define __ORZ_NETWORK_QUOTED_PRINTABLE__


class CQuotedPrintable
{
public:
	/*
		Encode/Decode:
		함수 안에서 알맞은 크기의 메모리(ppDest)를 할당하므로
		호출자가 사용 후 직접 해제해야 한다.
	*/
	static bool Encode( char *pRaw, int nRawLen, char **ppDest, int *pDestLen );
	static bool Decode( char *pRaw, int nRawLen, char **ppDest, int *pDestLen );

protected:
	static char HexToDec( char *hex, int len );
};


#endif