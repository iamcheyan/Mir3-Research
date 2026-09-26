

#include "msgfilter.h"
#include <windows.h>
#include <stdio.h>
#include <memory.h>
#include <string.h>


CMsgFilter::CMsgFilter()
{
	memset( m_listAbuse, 0, sizeof( m_listAbuse ) );
	m_nCnt = 0;
}	


CMsgFilter::~CMsgFilter()
{
}


bool CMsgFilter::Init( char *pPath )
{
	FILE *fp = fopen( pPath, "rb" );
	if ( !fp )
		return false;

	__try
	{
		while ( !feof( fp ) )
		{
			if ( fscanf( fp, "%s", m_listAbuse[m_nCnt] ) > 0 )
				m_nCnt++;
		}
	}
	__except ( EXCEPTION_EXECUTE_HANDLER )
	{
		fclose( fp );
		return false;
	}

	fclose( fp );
	return true;
}


void CMsgFilter::Uninit()
{
	memset( m_listAbuse, 0, sizeof( m_listAbuse ) );
	m_nCnt = 0;
}


void CMsgFilter::Filter( char *pMsg )
{
	char *pPos;
	int   nLen;

	for ( int i = 0; i < m_nCnt; i++ )
	{
		pPos = pMsg;
		nLen = strlen( m_listAbuse[i] );

		while ( pPos = strstr( pPos, m_listAbuse[i] ) )
		{
			memset( pPos, '*', nLen );
			pPos += nLen;
		}
	}
}