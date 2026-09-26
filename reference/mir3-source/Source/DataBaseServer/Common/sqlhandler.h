#ifndef _SQLHANDLER_MIR2
#define _SQLHANDLER_MIR2

#include <database.h>

#define SQLTYPE_SELECT			1
#define SQLTYPE_SELECTWHERE		2
#define SQLTYPE_UPDATE			3
#define SQLTYPE_INSERT			4
#define SQLTYPE_DELETE			5
#define SQLTYPE_SELECTWHERENOT	6
#define SQLTYPE_DELETENOT		7

#define TABLETYPE_STR			1
#define TABLETYPE_INT			2
#define TABLETYPE_DAT			3
#define TABLETYPE_DBL			4

typedef struct tagMIRDB_FIELDS
{
	char			szFieldName[30];
	unsigned char	btType;
	bool			fIsKey;
	int				nSize;
} MIRDB_FIELDS, *LPMIRDB_FIELDS;

typedef struct tagMIRDB_TABLE
{
	char			szTableName[30];
	int				nNumOfFields;
	LPMIRDB_FIELDS	lpFields;
} MIRDB_TABLE, *LPMIRDB_TABLE;

bool _makesqlparam(char *pszSQL, int nSQLType, LPMIRDB_TABLE lpTable, ...);
bool _makesql(char *pszSQL, int nSQLType, LPMIRDB_TABLE lpTable, unsigned char *pData);
void _getfields(CRecordset *pRec, LPMIRDB_TABLE lpTable, unsigned char *pData);

#endif
