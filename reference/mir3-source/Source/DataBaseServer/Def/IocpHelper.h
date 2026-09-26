

#pragma once


#define CLASSID_GATE		0x0001
#define CLASSID_GAMEDBSVR	0x0002


class CIocpObject
{
protected:
	int m_nClassId;

public:
	CIocpObject() : m_nClassId( 0 )		{}
	virtual ~CIocpObject()				{}

	void SetId( const int nClassId )	{ m_nClassId = nClassId; }
	int  GetId() const					{ return m_nClassId; }
};


class CIocpAcceptor
{
public:
	int		m_nPort;
	SOCKET	m_sdHost;
	HANDLE	m_hThread;

public:
	CIocpAcceptor();
	virtual ~CIocpAcceptor();

	bool Start( int nPort );
	void Stop();

	static unsigned __stdcall __tAcceptor( void *pContext );
	void __tcAcceptor();

	virtual void OnAccept( SOCKET sdClient, SOCKADDR_IN *pAddress ) = 0;
};