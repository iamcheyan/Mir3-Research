

/*
	Packet Handler -Mir2 Expansion Evil's Illusion-

	Date:
		2002/04/18
*/
#ifndef __ORZ_MIR2_PACKET_HANDLER__
#define __ORZ_MIR2_PACKET_HANDLER__


#include <netiocp.h>
#include "../common/endecode.h"


#define MIR2PACKET_DEFSIZE	256
#define MIR2PACKET_MAXSIZE	IOCP_MAXBUF


class CMir2Packet : public CIocpPacket
{
public:
	int m_nPacketMaxLen;

public:
	__declspec( nothrow ) CMir2Packet();
	__declspec( nothrow ) virtual ~CMir2Packet();

	bool Attach( char cByte );
	bool Attach( char *pBuf, int nLength );
	bool Attach( char *pStr );
	bool Attach( int nValue );
	bool AttachWithEncoding( char *pBuf, int nLength );

protected:
	bool Expand( int nSize );
};


#endif