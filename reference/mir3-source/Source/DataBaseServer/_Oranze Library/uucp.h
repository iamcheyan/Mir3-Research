

/*
	UUDecoder

	Date:
		2001/10/26

	Note:
		UUEncoder는 더 이상 사용되지 않을 것이기 때문에 포함시키지 않았다.
*/
#ifndef __ORZ_NETWORK_UUENCODE__
#define __ORZ_NETWORK_UUENCODE__


class CUuDecoder
{
public:
	static bool IsEncoded( char *pRaw );
	static bool Decode( char *pRaw, int nRawLen, char *pName, char **ppDest, int *pDestLen );

protected:
	static void DecodeChunk( char *in, char *out, int count );
};


#endif