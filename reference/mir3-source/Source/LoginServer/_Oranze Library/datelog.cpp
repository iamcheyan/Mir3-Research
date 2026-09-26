

#include "datelog.h"


CDateLog::CDateLog()
{
	m_szInitial[0]	= '\0';
	m_szDir[0]		= '\0';
	m_szFilePath[0]	= '\0';
}


CDateLog::~CDateLog()
{
}


bool CDateLog::Create( char *pInitial, char *pDir )
{
	strcpy( m_szInitial, pInitial );
	strcpy( m_szDir, pDir );

	if ( CreateLogFile() == false )
		return false;

	return true;
}


bool CDateLog::Log( char *pText, bool bWithCRLF )
{
	SYSTEMTIME sysTime;
	GetLocalTime( &sysTime );

	if ( m_sysTime.wYear != sysTime.wYear	||
		 m_sysTime.wMonth != sysTime.wMonth	||
		 m_sysTime.wDay != sysTime.wDay )
	{
		Close();

		if ( CreateLogFile() == false )
			return false;
	}

	char szTmp[16];
	sprintf( szTmp, "%02d:%02d:%02d ", 
		sysTime.wHour, sysTime.wMinute, sysTime.wSecond );

	Write( szTmp, strlen( szTmp ) );
	Write( pText, strlen( pText ) );

	if ( bWithCRLF )
		Write( "\r\n", strlen( "\r\n" ) );

	Flush();

	return true;
}


bool CDateLog::CreateLogFile()
{
	GetLocalTime( &m_sysTime );

	if ( m_szDir )
	{
		CreateDirectory( m_szDir, NULL );

		if ( m_szDir[ strlen( m_szDir ) - 1 ] == '\\' )
		{
			sprintf( m_szFilePath, "%s%s%04d%02d%02d.log", 
				m_szDir, m_szInitial, 
				m_sysTime.wYear, m_sysTime.wMonth, m_sysTime.wDay );
		}
		else
		{
			sprintf( m_szFilePath, "%s\\%s%04d%02d%02d.log", 
				m_szDir, m_szInitial, 
				m_sysTime.wYear, m_sysTime.wMonth, m_sysTime.wDay );
		}
	}
	else
	{
		sprintf( m_szFilePath, "%s%04d%02d%02d.log", 
			m_szInitial, 
			m_sysTime.wYear, m_sysTime.wMonth, m_sysTime.wDay );
	}

	return Open( m_szFilePath, "ab" );
}
