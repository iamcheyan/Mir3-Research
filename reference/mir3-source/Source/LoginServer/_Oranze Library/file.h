

#ifndef __ORZ_FILE__
#define __ORZ_FILE__


#include <stdio.h>


class CFile
{
public:
	FILE *m_pFile;

public:
	CFile();
	virtual ~CFile();

	virtual bool Open( char *pFile, char *pMode );
	virtual void Close();
	virtual int  Read( char *pBuf, int nBufLen );
	virtual bool ReadString( char *pBuf, int nBufLen );
	virtual int  Write( char *pBuf, int nBufLen );
	virtual void Flush();
	virtual bool IsEnd();
	virtual int  GetLength();

public:
	// Static Helper Functions
	static bool	 IsExist( char *pPath );
	static int   GetLength( char *pPath );
};


#endif