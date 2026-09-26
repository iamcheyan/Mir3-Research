#ifndef __MIR_UTP_SENEDER_H__
#define __MIR_UTP_SENEDER_H__

#include <windows.h> 



#include "stdio.h"
#include "stdlib.h"
#include "string.h"

#include "winsock2.h"



#define BUFSIZE		30
#define SEND_PORT	9999


class CUdpsender
{
public:
	int sock;
	struct sockaddr_in serv_addr1;
	struct sockaddr_in serv_addr2;
	struct sockaddr_in serv_addr3;
public:
	bool InitUtpsocket();
	void SetReceiverIp1(char * szReceiveIp);
	void SetReceiverIp2(char * szReceiveIp);
	void SetReceiverIp3(char * szReceiveIp);
	int	 SendMessages(char * szMessage);

};





#endif