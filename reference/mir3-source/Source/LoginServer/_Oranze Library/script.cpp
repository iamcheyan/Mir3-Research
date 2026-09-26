

#include "script.h"
#include "stringex.h"
#include <stdlib.h>


CScriptArray::CScriptArray()
{
	m_nItemCount = 0;
	memset( m_szItems, 0, sizeof( m_szItems ) );
}


CScriptArray::~CScriptArray()
{
}


int CScriptArray::GetItemCount()
{
	return m_nItemCount;
}

char * CScriptArray::GetItem( int nArray )
{
	return m_szItems[ nArray ];
}


char * CScriptArray::operator[]( int nArray )
{
	return GetItem( nArray );
}


int CScript::CompareNode( void *pArg, SCRIPT_NODE *pFirst, SCRIPT_NODE *pSecond )
{
	return stricmp( pFirst->szName, pSecond->szName );
}


CScript::CScript()
{
	m_listNode.SetCompareFunction( CompareNode, NULL );
}


CScript::~CScript()
{
	m_listNode.ClearAll();
}


bool CScript::Open( char *pFile )
{
	return CFile::Open( pFile, "rt" );
}


bool CScript::Set( char *pName, void *pValue, int nType )
{
	SCRIPT_NODE *pNode = new SCRIPT_NODE;
	if ( pNode == NULL )
		return false;

	strcpy( pNode->szName, pName );
	pNode->pValue	= pValue;
	pNode->nType	= nType;

	return m_listNode.Insert( pNode );
}


bool CScript::Parse()
{
	char szLine[SCRIPT_MAXLINE];
	char szName[SCRIPT_MAXNAME], szValue[SCRIPT_MAXVALUE], *pDelim;

	while ( IsEnd() == false )
	{
		if ( ReadString( szLine, SCRIPT_MAXLINE ) == NULL )
			break;

		_trim( szLine );
		if ( strlen( szLine ) == 0 || szLine[0] == '#' || szLine[0] == '\'' || szLine[0] == ';' )
			continue;

		pDelim = strchr( szLine, ':' );
		if ( pDelim == NULL )
		{
			pDelim = strchr( szLine, '=' );
			if ( pDelim == NULL )
				continue;
		}

		strncpy( szName, szLine, pDelim - szLine );
		szName[ pDelim - szLine ] = '\0';
		_trim( szName );

		strcpy( szValue, pDelim + 1 );
		_trim( szValue );

		SCRIPT_NODE *pNode = m_listNode.Search( (SCRIPT_NODE *) szName );
		if ( pNode )
		{
			switch ( pNode->nType )
			{
			case SCRIPT_INT:
				*((int *) pNode->pValue) = atoi( szValue );
				break;

			case SCRIPT_STRING:
				strcpy( (char *) pNode->pValue, szValue );
				break;

			case SCRIPT_ARRAY:
				ParseArray( szValue, (CScriptArray *) pNode->pValue );
				break;
			}
		}
	}

	return true;
}


void CScript::ParseArray( char *pValue, CScriptArray *pArray )
{
	char *pToken = strtok( pValue, "," );

	while ( pToken )
	{
		if ( strlen( pToken ) < SCRIPT_MAXARRAYITEM )
		{
			strcpy( pArray->m_szItems[ pArray->m_nItemCount ], pToken );
			_trim( pArray->m_szItems[ pArray->m_nItemCount ] );

			pArray->m_nItemCount++;
		}

		pToken = strtok( NULL, "," );
	}
}
