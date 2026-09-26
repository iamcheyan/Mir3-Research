

#ifndef __ORZ_MIR2_GAME_SERVER__
#define __ORZ_MIR2_GAME_SERVER__


#include <netiocp.h>

class CGameServer : public CIocpObject
{
private:
	UINT	m_nLoadCount;
	UINT	m_nSaveCount;
	UINT	m_nLoadFailCount;
	UINT	m_nSaveFailCount;

public:
	enum { CLASSID = IOCP_OBJECT_CLASSID_0 + 2 };

	int  m_nCntInvalidPacket;
	
public:
	CGameServer( SOCKET sdClient );
	virtual ~CGameServer();

	//---------------------------------------------------------------------------------------------
	// DB Server -> Game SErver
	//---------------------------------------------------------------------------------------------
	bool SendResponse		( int nCert, char *pData );
	bool SendResponse		( int nCert, int result , char *UserName , int RetCmdNum , int CmdNum ,char *pData  );
	
	
	//---------------------------------------------------------------------------------------------
	// GameServer -> DB Server
	//---------------------------------------------------------------------------------------------
	bool OnLoadHumanRcd		( int nCert, char *pBody );	// 케릭터 정보를 읽음
	bool OnSaveHumanRcd		( int nCert, char *pBody ); // 케릭터 정보를 저장
	bool OnSaveAndChange	( int nCert, char *pBody ); // 

	// For Friend System...
	bool OnFriendList		( int nCert, char *pBody ); // 자신이 등록한 유저 리스트 요청
	bool OnFriendOwnList	( int nCert, char *pBody ); // 자신을 등록한 유저 리스트 요청 
	bool OnFriendAdd		( int nCert, char *pBody ); // 유저 추가 
	bool OnFriendDelete		( int nCert, char *pBody ); // 유저 삭제 
	bool OnFriendEdit		( int nCert, char *pBody ); // 친구 세부정보 변경 
	
	// For Tag System...
	bool OnTagAdd			( int nCert, char *pBody ); // 쪽지 추가
	bool OnTagDelete		( int nCert, char *pBody ); // 쪽지 삭제 
	bool OnTagDeleteAll		( int nCert, char *pBody ); // 쪽지 전부 삭제 
	bool OnTagList			( int nCert, char *pBody ); // 쪽지 리스트 요청 
	bool OnTagSetInfo		( int nCert, char *pBody ); // 쪽지 상태수정 
	bool OnTagRejectAdd		( int nCert, char *pBody ); // 거부자 추가
	bool OnTagRejectDelete	( int nCert, char *pBody ); // 거부자 삭제 
	bool OnTagRejectList	( int nCert, char *pBody ); // 거부자 리스트 요청
	bool OnTagNotReadCount	( int nCert, char *pBody ); // 읽지않은 쪽지 개수 요청 

	// For RelationShip...
	bool OnLMList			( int nCert, char *pBody ); // 관계 리스트 요청 
	bool OnLMAdd			( int nCert, char *pBody ); // 관계 추가 
	bool OnLMEdit			( int nCert, char *pBody ); // 관계 세부정보 변경 
	bool OnLMDelete			( int nCert, char *pBody ); // 관계 삭제 
	
	//---------------------------------------------------------------------------------------------
	// CIocpObject 가상함수 구현
	//---------------------------------------------------------------------------------------------
	void OnError( int nErrCode );
	void OnSend( int nTransferred );
	bool OnRecv( char *pPacket, int nPacketLen );
	bool OnExtractPacket( char *pPacket, int *pPacketLen );

	//---------------------------------------------------------------------------------------------
	// 동작 구현
	//---------------------------------------------------------------------------------------------
	bool IsValidData( int nCert, char *pData, int nDataLen );

	bool SaveUserItem(CConnection *pConn, MIRDB_TABLE* pTable, LPTUserItem pUserItem, int nType, char *pszName , int nPos);
	bool SaveBagItem(CConnection *pConn, LPTBagItem pBagItem, char *pszName);
	bool SaveSaveItem(CConnection *pConn, LPTSaveItem pSaveItem, char *pszName);
	bool SaveUseMagic(CConnection *pConn, LPTUseMagic pUseMagic, char *pszName );
	bool SaveQuest(CConnection *pConn, LPTHuman lptHuman, char *pszName);

	bool LoadQuest(CConnection *pConn, LPTHuman lptHuman, char *pszName);

	//
	void ShowStatusLog();
};


#endif