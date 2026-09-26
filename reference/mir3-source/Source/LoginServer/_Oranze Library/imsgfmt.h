

/*
	Simple Internet Message Format Manipulation Class

	Date:
		2001/10/25 (Last Updated: 2002/05/18)
*/
#ifndef __ORZ_NETWORK_INTERNET_MESSAGE_FORMAT__
#define __ORZ_NETWORK_INTERNET_MESSAGE_FORMAT__


#define IMSG_MAXLINE	1024
#define IMSG_NEWLINE	"\n"


class CIMsgFormat
{
public:
	static bool QueryString( char *pBuf, char *pName, char *pValue, int nValueLen );
};


#endif