
#include "netUdpsender.h"

bool CUdpsender::InitUtpsocket()
{
	WSADATA		wsaData;
	if(WSAStartup(MAKEWORD(2,2), &wsaData ) != 0)
		return false;


	sock = socket(PF_INET, SOCK_DGRAM, 0);
	if(sock == -1)
		return false;


	return true;
}

int CUdpsender::SendMessages(char * szMessage)
{
	sendto(sock, szMessage, strlen(szMessage),0, (struct sockaddr*)&serv_addr1, sizeof(serv_addr1));
	sendto(sock, szMessage, strlen(szMessage),0, (struct sockaddr*)&serv_addr2, sizeof(serv_addr2));
	sendto(sock, szMessage, strlen(szMessage),0, (struct sockaddr*)&serv_addr3, sizeof(serv_addr3));

	return strlen(szMessage);
}

void CUdpsender::SetReceiverIp1(char *szReceiveIp)
{
	memset(&serv_addr1, 0, sizeof(serv_addr1));
	serv_addr1.sin_family = AF_INET;
	serv_addr1.sin_addr.s_addr = inet_addr(szReceiveIp);
	serv_addr1.sin_port = htons(SEND_PORT);
};

void CUdpsender::SetReceiverIp2(char *szReceiveIp)
{
	memset(&serv_addr2, 0, sizeof(serv_addr2));
	serv_addr2.sin_family = AF_INET;
	serv_addr2.sin_addr.s_addr = inet_addr(szReceiveIp);
	serv_addr2.sin_port = htons(SEND_PORT);
};

void CUdpsender::SetReceiverIp3(char *szReceiveIp)
{
	memset(&serv_addr3, 0, sizeof(serv_addr3));
	serv_addr3.sin_family = AF_INET;
	serv_addr3.sin_addr.s_addr = inet_addr(szReceiveIp);
	serv_addr3.sin_port = htons(SEND_PORT);
};