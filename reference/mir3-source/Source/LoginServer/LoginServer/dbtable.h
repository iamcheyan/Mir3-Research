

#pragma once

struct sTblServerInfo
{
	char szName[21];
	int		nMaxUserCount;
	int		nFreemode;
};


struct sTblPubIP
{
	char szIP[16];
	char szDesc[21];
};


struct sTblSvrIP
{
	int nID;
	char szIP[16];
	char szName[21];
};

struct sTblSelectGateIP
{
	char	szName[21];
	char	szIP[16];
	int		nPort;
};

