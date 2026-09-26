

#include "file.h"
#include "io.h"


CFile::CFile()
{
	m_pFile = NULL;
}


CFile::~CFile()
{
	if ( m_pFile )
		Close();
}


bool CFile::Open( char *pFile, char *pMode )
{
	if ( m_pFile )
		return false;

	m_pFile = fopen( pFile, pMode );

	return m_pFile ? true : false;
}


void CFile::Close()
{
	if ( m_pFile )
	{
		fclose( m_pFile );
		m_pFile = NULL;
	}
}


int CFile::Read( char *pBuf, int nBufLen )
{
	return fread( pBuf, 1, nBufLen, m_pFile );
}


bool CFile::ReadString( char *pBuf, int nBufLen )
{
	return fgets( pBuf, nBufLen, m_pFile ) ? true : false;
}


int CFile::Write( char *pBuf, int nBufLen )
{
	return fwrite( pBuf, 1, nBufLen, m_pFile );
}


void CFile::Flush()
{
	fflush( m_pFile );
}


bool CFile::IsEnd()
{
	return feof( m_pFile ) ? true : false;
}


int CFile::GetLength()
{
	return _filelength( _fileno( m_pFile ) );
}


bool CFile::IsExist( char *pPath )
{
	CFile file;

	return file.Open( pPath, "rb" );
}


int CFile::GetLength( char *pPath )
{
	CFile file;
	if ( file.Open( pPath, "rb" ) == false )
		return 0;

	return file.GetLength();
}