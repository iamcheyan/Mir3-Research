// EnDecode.cpp : Defines the entry point for the DLL application.
//


#include <stdio.h>
#include <stdlib.h>
#include "endecode.h"

BYTE cTable_src[256] = {
 28, 171, 172, 131, 154, 114, 136, 222,  17,  46,  13, 234,  90, 228,  57, 116,
139,  51, 102,  89, 169, 191, 130,  48, 223,  88, 138, 214, 196, 233,  65, 158,
194, 212,  27, 201, 163, 120, 253,   6, 215,  87,  11, 244, 101,  59,  23, 254,
230, 205,  43,  94, 100, 178,  41,  34, 126,  77, 176,  30,   5, 235, 137, 108,
202,   0,  16, 159,  35, 119,  52, 113, 184,  54, 142, 140,  19, 252,  72,   1,
 25, 255, 198,  38, 111, 199,  39,  83, 203, 124, 164, 211, 232,  10,  82, 193,
115, 243, 227,  93,   4,   2,  49,  74, 175, 146, 217,  60, 216, 147, 182, 117,
 44, 104, 197, 156,  12, 141,   7,  81, 145,  24,  84,  96,  55, 107, 209,  92,
 36, 237, 121, 187, 135,  40, 240,  78, 210,   9,  67,  62,  68, 157,  50, 129,
127, 190, 192, 179, 238,   3, 174, 181, 245, 148, 177, 200,  70,  76, 225,  18,
112, 132, 165, 103,  20,  45,  15, 170, 219, 220,  56, 144,  14,  80,  98, 161,
151,  33, 239, 133, 231, 134,   8,  99, 122, 167, 162, 224, 226, 155, 153, 213,
173,  85, 242, 152, 221,  95,  97, 247, 128,  22,  53, 106, 188, 105, 206, 248,
204, 149, 143, 180,  31, 195, 207,  58,  66,  61, 246, 249,  29, 241,  91, 109,
185,  79, 229,  21, 208,  71,  47,  64, 186, 166, 189, 150,  63, 250,  73,  69,
183, 110, 218,  32, 125,  26, 118, 160, 168,  75,  37,  42, 251, 123,  86, 236
};

BYTE dTable_src[256] = {
 84,  44,  40, 199,  45, 108,  22,  83,  63, 248,  48,  62, 220,  24, 189, 124,
132,  85,  43, 247, 178, 197, 103,  21,  34, 232,  41, 184, 219, 237, 240,  80,
227, 157,  12, 206,  73, 170, 212,  86,   8,   2,   5, 163, 235, 250, 210, 215,
131, 218,  53, 205, 255, 149,  58,   0,  10,  20, 111,  37, 102, 158,  11,  30,
145, 116, 229, 233,  32, 153,  76, 159, 191,  55, 117, 190,  25,  33,   4, 114,
177,  60, 128,  54, 100,  82, 243,  91, 110, 213,  87, 246, 188, 198,  23, 107,
225, 245,  96,  78,  99, 174, 208, 166, 168, 155,  46, 133, 209, 181, 104, 223,
 81, 141, 194,  88, 129, 186, 202, 112, 161,  56, 195,  19,  29, 204, 200, 134,
 66, 167, 136, 152, 242, 252, 203, 251,  18,  17, 126,  28,  79, 135, 192,  51,
 59, 144, 147, 214, 207, 142, 143, 139, 105, 140, 176, 146, 127, 130, 118,  93,
 72,  47, 221, 160,  15, 156,  97,  61, 241, 217,  49, 183,   3, 173, 151,  13,
150,   6,  57, 154, 122, 230,   7,  27, 249, 148, 123, 121, 193, 211, 169, 106,
109,  26,  71,  95,  94, 180, 254, 238, 244,  74, 187,  31,  64, 226, 228,  69,
 35,  14, 196, 253,  89, 115, 138,  68, 120, 119, 175, 162, 201, 236, 239,  16,
216, 172,  52,  38,  98, 234, 222,  90,  70,  67, 171, 179,  39,  92, 224, 165,
  1, 164, 231, 185,  50,  77, 113, 101,  36, 182,  75,  42, 137,  65, 125,   9
};

BYTE cTable_return[256] = {
132, 223, 229, 173,  89,  93,  76, 159, 119,  43, 185,  71, 137,  48, 138, 247,
176, 129, 135, 149,  55,  34, 187, 252, 230, 126,  65, 127,  36,  46,  10,  50,
196,  90, 163, 231, 167,   1, 174,  14,  33, 165, 222, 248, 183, 220, 212, 124,
141, 221, 150, 110,  16, 142, 155, 195,  92, 162, 244,  54,  53, 147,  32, 204,
 28,  47, 139,  21, 111, 188,  74, 208,  44,  51, 240, 157, 156, 198,  94,  88,
 97, 102,  70,  40, 225,  20, 107, 166, 226, 250,   5, 228, 108, 116,  23, 175,
243, 238, 172,  31,  85, 246, 233, 178, 101,  27,  18, 121, 200, 217, 239, 251,
128,   4, 214,  57,  86, 136, 170, 143, 134, 160, 181, 203,   9,  63,  41, 104,
 26, 253, 215, 144, 120, 171,  60, 118, 224,  15, 232,  52,  22, 193, 100,  77,
 66,  19,   8,  80, 161,  81, 123, 117, 146, 152,  62,  64,  30, 105, 189, 130,
 72, 125, 254, 114,  37, 186,  82,  35, 216, 191, 237,  95,  25, 227,  58, 158,
 98, 103, 206, 180, 112,   3, 133, 199, 210,  61, 145,  68,   6, 207,   2, 177,
 29, 202, 245,  78,  99, 106,  67, 153, 241,   7,  87,  75, 234,  56,  39,  45,
209, 168, 219, 184, 190, 236,  42, 211, 213, 179,  13, 169, 205,  83, 218, 122,
113, 194,  91,  59,  84,  49, 115, 148, 164,  12, 192, 109, 201, 140, 182,  17,
151,  38,  24,   0, 131, 154, 242,  79,  96, 197, 235,  11,  73, 255, 249,  69
};

BYTE dTable_return[256] = {
154, 132,   1, 141, 166, 175, 116, 165, 115,   9,  21, 145,  93, 135, 113, 183,
185,  75,  95,  36,   4, 169,  64, 102, 162, 161,  69, 173, 163, 226, 200, 182,
159, 205,  89, 241, 223,  32, 100, 174, 124, 127,  58, 104, 254,  65, 199,  47,
181,  83, 219, 197,  31, 239,  76, 151, 238,  81, 153, 213, 222,  17, 138,  92,
 27, 167, 109,  18, 137,  26,  88,  82,  91, 210, 150,  56,  40,   5, 157, 212,
 55, 105,  33, 230,  78,  70, 136, 186, 160,  23,   7,  73, 178,  66, 232,  74,
 39, 111,  85, 252,  98, 176, 156,  42,   0, 242, 231, 177, 179,  25, 140,  61,
198, 129, 118, 250,  20, 249,  84, 218, 234, 243,  41, 233,  24, 209, 119,  45,
106,  50,  35,  13,  79, 188, 189, 235, 255,  11,  72, 191, 131, 245, 120,  57,
130, 133,  30, 122, 152,  29, 196,   3, 144, 229, 155,  22,  10,  12, 203,  28,
125, 103,   6, 214, 187, 192, 158,  62,  60,  63, 147, 101, 164,   2, 134,  77,
216, 215,  15, 204, 228,  44, 121, 112, 149,  94,  48,  53,  38, 207,  46,  54,
110,  19,  37,  52,  51,  97,  68,  43, 247, 240, 171, 217,  99, 211, 224,  71,
246, 220, 251, 227, 221, 180, 201, 248, 184,  87, 193, 114, 206, 253,  16, 148,
237, 170, 126, 117, 225, 123, 194,  67, 168, 190, 202,  59, 142, 128, 143, 236,
 34,   8, 195,  96,  80, 208, 146,  86,  14, 108, 244,  49, 107, 139, 172,  90
};

const char cXorValue = 0x14;

// 치환 테이블 인코딩 값
const BYTE g_HideTable = 0x97;
// 역치환 테이블 인코딩 값
const BYTE g_HideBackTable = 0x34;
//--------------------------

static unsigned char Decode6BitMask[5] = { 0xfc, 0xf8, 0xf0, 0xe0, 0xc0 };

WORD g_DefaultPubKey = 0x6501;	//기본값
WORD g_SavedPubKey = g_DefaultPubKey;
WORD g_EndeKey = g_DefaultPubKey;


//-------------------------------------------------
// Load public key.
void LoadPublicKey( char *fname )
//-------------------------------------------------
{
	char szKey[100+1] = {0,};
	char *stopstring;
	FILE *fp;

	if( (fp = fopen(fname, "r")) != NULL )
	{
		if( fgets(szKey, 100, fp) != NULL )
		{
			SetPublicKey( WORD( strtoul(szKey, &stopstring, 10) ) );
		}

		fclose(fp);
	}
}

void SetPublicKey( WORD pubkey )
{
	g_EndeKey = pubkey;
	// 저장키에도 동일하게 저장
	g_SavedPubKey = g_EndeKey;
}

WORD GetPublicKey( void )
{
	return g_EndeKey;
}

WORD GetSavedKey( void )
{
	return g_SavedPubKey;
}

void ChangeByDefaultKey( void )
{
	// 현재키 임시 저장
	g_SavedPubKey = g_EndeKey;
	// 기본값으로 변경
	g_EndeKey = g_DefaultPubKey;
}

void ChangeBySavedKey( void )
{
	g_EndeKey = g_SavedPubKey;
}


/* **************************************************************************************

		Encode/Decode Routine for ANSI character

   ************************************************************************************** */
int WINAPI fnEncode6BitBuf(unsigned char *pszSrc, char *pszDest, int nSrcLen, int nDestLen)
{
	int				nDestPos	= 0;
	int				nRestCount	= 0;
	unsigned char	chMade = 0, chRest = 0;

	for (int i = 0; i < nSrcLen; i++)
	{
		if (nDestPos >= nDestLen) break;

		//---------------------------------------------------------------------
		// 치환
//		pszSrc[i] = ( cTable_src[ pszSrc[i] ] ^ g_HideTable ) ^ cXorValue;   // added by sonmg

		pszSrc[i] = pszSrc[i] ^ (((i+5)*2)+3);

		// XOR 연산
		pszSrc[i] = pszSrc[i] ^ ( HIBYTE(g_EndeKey) + LOBYTE(g_EndeKey) );   // added by sonmg
		//---------------------------------------------------------------------
		
		chMade = ((chRest | (pszSrc[i] >> (2 + nRestCount))) & 0x3f);
		chRest = (((pszSrc[i] << (8 - (2 + nRestCount))) >> 2) & 0x3f);

		nRestCount += 2;

		if (nRestCount < 6)
			pszDest[nDestPos++] = chMade + 0x3c;
		else
		{
			if (nDestPos < nDestLen - 1)
			{
				pszDest[nDestPos++]	= chMade + 0x3c;
				pszDest[nDestPos++]	= chRest + 0x3c;
			}
			else
				pszDest[nDestPos++] = chMade + 0x3c;

			nRestCount	= 0;
			chRest		= 0;
		}
	}

	if (nRestCount > 0)
		pszDest[nDestPos++] = chRest + 0x3c;

//	pszDest[nDestPos] = '\0';

	return nDestPos;
}

int  WINAPI fnDecode6BitBuf(char *pszSrc, char *pszDest, int nDestLen)
{
	int				nLen = strlen((const char *)pszSrc);
	int				nDestPos = 0, nBitPos = 2;
	int				nMadeBit = 0;
	unsigned char	ch, chCode, tmp;

	for (int i = 0; i < nLen; i++)
	{
		if ((pszSrc[i] - 0x3c) >= 0)
			ch = pszSrc[i] - 0x3c;
		else
		{
			nDestPos = 0;
			break;
		}

		if (nDestPos >= nDestLen) break;

		if ((nMadeBit + 6) >= 8)
		{
			chCode = (tmp | ((ch & 0x3f) >> (6 - nBitPos)));

			//---------------------------------------------------------------------
			// XOR 연산
			chCode = chCode ^ ( HIBYTE(g_EndeKey) + LOBYTE(g_EndeKey) );   // added by sonmg

			chCode = chCode ^ (((nDestPos+5)*2)+3);

			// 역치환
//			chCode = chCode ^ cXorValue;   // added by sonmg
//			chCode = cTable_return[ chCode ] ^ g_HideBackTable;   // added by sonmg
			//---------------------------------------------------------------------

			pszDest[nDestPos++] = chCode;

			nMadeBit = 0;

			if (nBitPos < 6) 
				nBitPos += 2;
			else
			{
				nBitPos = 2;
				continue;
			}
		}

		tmp = ((ch << nBitPos) & Decode6BitMask[nBitPos - 2]);

		nMadeBit += (8 - nBitPos);
	}

//	pszDest[nDestPos] = '\0';

	return nDestPos;
}

int WINAPI fnEncode6BitBuf_old(unsigned char *pszSrc, char *pszDest, int nSrcLen, int nDestLen)
{
	int				nDestPos	= 0;
	int				nRestCount	= 0;
	unsigned char	chMade = 0, chRest = 0;

	for (int i = 0; i < nSrcLen; i++)
	{
		if (nDestPos >= nDestLen) break;
		
		chMade = ((chRest | (pszSrc[i] >> (2 + nRestCount))) & 0x3f);
		chRest = (((pszSrc[i] << (8 - (2 + nRestCount))) >> 2) & 0x3f);

		nRestCount += 2;

		if (nRestCount < 6)
			pszDest[nDestPos++] = chMade + 0x3c;
		else
		{
			if (nDestPos < nDestLen - 1)
			{
				pszDest[nDestPos++]	= chMade + 0x3c;
				pszDest[nDestPos++]	= chRest + 0x3c;
			}
			else
				pszDest[nDestPos++] = chMade + 0x3c;

			nRestCount	= 0;
			chRest		= 0;
		}
	}

	if (nRestCount > 0)
		pszDest[nDestPos++] = chRest + 0x3c;

//	pszDest[nDestPos] = '\0';

	return nDestPos;
}

int  WINAPI fnDecode6BitBuf_old(char *pszSrc, char *pszDest, int nDestLen)
{
	int				nLen = strlen((const char *)pszSrc);
	int				nDestPos = 0, nBitPos = 2;
	int				nMadeBit = 0;
	unsigned char	ch, chCode, tmp;

	for (int i = 0; i < nLen; i++)
	{
		if ((pszSrc[i] - 0x3c) >= 0)
			ch = pszSrc[i] - 0x3c;
		else
		{
			nDestPos = 0;
			break;
		}

		if (nDestPos >= nDestLen) break;

		if ((nMadeBit + 6) >= 8)
		{
			chCode = (tmp | ((ch & 0x3f) >> (6 - nBitPos)));
			pszDest[nDestPos++] = chCode;

			nMadeBit = 0;

			if (nBitPos < 6) 
				nBitPos += 2;
			else
			{
				nBitPos = 2;
				continue;
			}
		}

		tmp = ((ch << nBitPos) & Decode6BitMask[nBitPos - 2]);

		nMadeBit += (8 - nBitPos);
	}

//	pszDest[nDestPos] = '\0';

	return nDestPos;
}

int WINAPI fnEncodeMessage(_LPTDEFAULTMESSAGE lptdm, char *pszBuf, int nLen)
{ 
	return fnEncode6BitBuf((unsigned char *)lptdm, pszBuf, sizeof(_TDEFAULTMESSAGE), nLen); 
}


CDecodedString * WINAPI fnDecodeString( char *src )
{
	int destLen = int( (strlen( src )) * 3 / 4 ) + 2;

	CDecodedString *d = new CDecodedString( destLen );
	d->m_pData[ fnDecode6BitBuf( src, d->m_pData, destLen ) ] = '\0';

	return d;
}

void ChangeSpaceToNull(char *pszData)
{
	char *pszCheck = pszData;

	if (pszCheck)
	{
		while (*pszCheck)
		{
			if (*pszCheck == 0x20 && *(pszCheck + 1) == 0x20)
			{
				*pszCheck = '\0';
				return;
			}

			pszCheck++;
		}
	}
}

