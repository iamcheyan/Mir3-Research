

#include "error.h"
#include <windows.h>
#include <stdio.h>


CError::CError( char *pMsg )
{
	lstrcpy( m_szMsg, pMsg );
}


CError::~CError()
{
}


const char * CError::GetMsg()
{
	return m_szMsg;
}


void _outputerr( char *pMsg, ... )
{
	char szBuffer[ERROR_MAXBUF] = {0,};
	
	va_list	stream;		
	va_start( stream, pMsg );
	vsprintf( szBuffer, pMsg, stream );
	va_end( stream );
	
	OutputDebugString( szBuffer );
}