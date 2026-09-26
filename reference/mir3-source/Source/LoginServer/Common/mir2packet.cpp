

#include "mir2packet.h"
#include "util.h"
#include <stdlib.h>



CMir2Packet::CMir2Packet()
{
	m_pPacket		= (char *) HeapAlloc( GetProcessHeap(), HEAP_ZERO_MEMORY, MIR2PACKET_DEFSIZE );
	m_nPacketMaxLen	= m_pPacket ? MIR2PACKET_DEFSIZE : 0;
}


CMir2Packet::~CMir2Packet()
{
	if ( m_pPacket )
	{
		HeapFree( GetProcessHeap(), 0, m_pPacket );
		m_pPacket = NULL;
	}
}


bool CMir2Packet::Attach( char cByte )
{
	if ( m_nPacketLen + 1 > MIR2PACKET_MAXSIZE )
		return false;

	if ( m_nPacketLen + 1 > m_nPacketMaxLen )
	{
		if ( !Expand( 1 ) )
			return false;
	}

	m_pPacket[ m_nPacketLen++ ] = cByte;

	return true;
}


bool CMir2Packet::Attach( char *pBuf, int nLength )
{
	if ( nLength < 0 || (m_nPacketLen + nLength > MIR2PACKET_MAXSIZE) )
		return false;

	if ( m_nPacketLen + nLength > m_nPacketMaxLen )
	{
		if ( !Expand( nLength ) )
			return false;
	}

	memcpy( &m_pPacket[ m_nPacketLen ], pBuf, nLength );
	m_nPacketLen += nLength;

	return true;
}


bool CMir2Packet::Attach( char *pStr )
{
	return Attach( pStr, strlen( pStr ) );
}


bool CMir2Packet::Attach( int nValue )
{
	char szNum[12] = {0,};
	itoa( nValue, szNum, 10 );

	return Attach( szNum, strlen( szNum ) );
}
 

bool CMir2Packet::AttachWithEncoding( char *pBuf, int nLength )
{
	int nNeedLen = int( (nLength + 0.5) * 4 / 3 );

	if ( nLength < 0 || (m_nPacketLen + nNeedLen > MIR2PACKET_MAXSIZE) )
		return false;

	if ( m_nPacketLen + nNeedLen > m_nPacketMaxLen )
	{
		if ( !Expand( nNeedLen ) )
			return false;
	}

	fnEncode6BitBuf( (byte *) pBuf, &m_pPacket[ m_nPacketLen ], nLength, nNeedLen );
	m_nPacketLen += nNeedLen;

	return true;
}


bool CMir2Packet::Expand( int nSize )
{
	m_nPacketMaxLen = _roundup( m_nPacketLen + nSize, MIR2PACKET_DEFSIZE );

	m_pPacket = (char *) HeapReAlloc( GetProcessHeap(), HEAP_ZERO_MEMORY, m_pPacket, m_nPacketMaxLen );
	if ( !m_pPacket )
	{
		m_nPacketLen	= 0;
		m_nPacketMaxLen	= 0;

		return false;
	}

	return true;
}