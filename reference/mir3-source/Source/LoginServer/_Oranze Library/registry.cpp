

#include "registry.h"


CRegistry::CRegistry()
{
	m_hKey = NULL;
}


CRegistry::~CRegistry()
{
	if ( m_hKey )
		CloseKey();
}


bool CRegistry::OpenKey( char *pKeyName )
{
	char szKeyName[MAXREGKEY];
	wsprintf( szKeyName, "SOFTWARE\\%s", pKeyName );

	return RegCreateKeyEx( HKEY_LOCAL_MACHINE,
						   szKeyName,
						   0,
						   NULL,
						   REG_OPTION_NON_VOLATILE,
						   KEY_ALL_ACCESS,
						   NULL,
						   &m_hKey,
						   NULL ) == ERROR_SUCCESS ? true : false;
}


bool CRegistry::CloseKey()
{
	if ( RegCloseKey( m_hKey ) != ERROR_SUCCESS )
		return false;

	m_hKey = NULL;

	return true;
}


bool CRegistry::SetInteger( char *pValueName, int nValueInt )
{
	return RegSetValueEx( m_hKey,
						  pValueName,
						  0,
						  REG_DWORD,
						  (BYTE *) &nValueInt,
						  sizeof( DWORD ) ) == ERROR_SUCCESS ? true : false;
}


bool CRegistry::SetString( char *pValueName, char *pValueString )
{
	return RegSetValueEx( m_hKey,
						  pValueName,
						  0,
						  REG_SZ,
						  (BYTE *) pValueString,
						  lstrlen( pValueString ) ) == ERROR_SUCCESS ? true : false;
}


bool CRegistry::GetInteger( char *pValueName, int *pValueInt )
{
	DWORD dwType, dwSize;

	return RegQueryValueEx( m_hKey,
							pValueName,
							0,
							&dwType,
							(BYTE *) pValueInt,
							&dwSize ) == ERROR_SUCCESS ? true : false;
}


bool CRegistry::GetString( char *pValueName, char *pValueString, int nValueStringLen )
{
	DWORD dwType, dwSize = nValueStringLen;

	return RegQueryValueEx( m_hKey,
							pValueName,
							0,
							&dwType,
							(BYTE *) pValueString,
							&dwSize ) == ERROR_SUCCESS ? true : false;
}