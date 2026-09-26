

#include "imsgfmt.h"
#include "stringex.h"


bool CIMsgFormat::QueryString( char *pBuf, char *pName, char *pValue, int nValueLen )
{
	char szLine[IMSG_MAXLINE], szName[IMSG_MAXLINE];
	bool bFind = false;
	char *pStart, *pEnd = pBuf - strlen( IMSG_NEWLINE );
	char *pToken, *pTokenTmp;

	while ( true )
	{
		// 현재 라인에서 이름과 값을 분리한다.
		pStart = pEnd + strlen( IMSG_NEWLINE );
		pEnd = strstr( pStart, IMSG_NEWLINE );
		if ( !pEnd || (pEnd - pStart) >= IMSG_MAXLINE )
			break;

		memcpy( szLine, pStart, pEnd - pStart );
		szLine[ pEnd - pStart ] = NULL;

		// 첫 문자가 whitespace라면 이어지는 행이다.
		if ( bFind )
		{
			if ( szLine[0] == ' ' || szLine[0] == '\t' )
			{
				_trim( szLine );
				nValueLen -= strlen( szLine );
				if ( nValueLen <= 0 )
					break;

				strcat( pValue, szLine );
				continue;
			}
			break;
		}
		
		// 이름을 얻는다.
		pStart = _memistr( szLine, strlen( szLine ), pName );
		if ( !pStart )
			continue;
		
		if ( pStart != szLine && !_isspace( *(pStart - 1) ) && *(pStart - 1) != ';' )
			continue;

		pToken	  = strchr( pStart, ':' );
		pTokenTmp = strchr( pStart, '=' );

		if ( pToken && pTokenTmp )
			pToken = pToken < pTokenTmp ? pToken : pTokenTmp;
		if ( !pToken )
			pToken = pTokenTmp;
	
		if ( !pToken )
			continue;

		memcpy( szName, pStart, pToken - pStart );
		szName[ pToken - pStart ] = NULL;
		_trim( szName );

		// 이름 비교 (Case-Insensitive)
		if ( stricmp( szName, pName ) != 0 )
			continue;

		pStart = ++pToken;

		// 값을 얻는다.
		bFind = true;

		nValueLen -= strlen( pStart );
		if ( nValueLen <= 0 )
			return false;

		strcpy( pValue, pStart );
		_trim( pValue );
	}

	return bFind ? true : false;
};
