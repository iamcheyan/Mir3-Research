#include <stdio.h>
#include <stdarg.h>
#include <string.h>
#include <stdlib.h>
#include <database.h>
#include "../common/mir2packet.h"
#include "sqlhandler.h"
#ifdef _DEBUG
#include <crtdbg.h>
#endif

bool _makesqlparam(char *pszSQL, int nSQLType, LPMIRDB_TABLE lpTable, ...)
{
	va_list		v;
	int			nCnt = 0, nCnt2 = 0;
	char		szTemp[256];

	switch (nSQLType)
	{
		case SQLTYPE_SELECT:
			sprintf(pszSQL, "SELECT * FROM %s", lpTable->szTableName);
			return true;
		case SQLTYPE_SELECTWHERE:
		{
			sprintf(pszSQL, "SELECT * FROM %s WHERE ", lpTable->szTableName);
			
			va_start(v, lpTable);

			for (int i = 0; i < lpTable->nNumOfFields; i++)
			{
				if (lpTable->lpFields[i].fIsKey)
				{
					if (nCnt >= 1)
						strcat(pszSQL, "AND ");

					if (lpTable->lpFields[i].btType == TABLETYPE_STR)
						sprintf(szTemp, "%s='%s' ", lpTable->lpFields[i].szFieldName, va_arg(v, char *));
					else
						sprintf(szTemp, "%s=%d ", lpTable->lpFields[i].szFieldName, va_arg(v, int));

					strcat(pszSQL, szTemp);
					nCnt++;
				}
			}
		
			va_end(v);

			return true;
		}
		case SQLTYPE_SELECTWHERENOT: // TO PDS
		{
			sprintf(pszSQL, "SELECT * FROM %s WHERE ", lpTable->szTableName);
			
			va_start(v, lpTable);

			for (int i = 0; i < lpTable->nNumOfFields; i++)
			{
				if (lpTable->lpFields[i].fIsKey)
				{
					if (nCnt >= 1)
						strcat(pszSQL, "AND ");
					
					if ( nCnt )
					{
						if (lpTable->lpFields[i].btType == TABLETYPE_STR)
							sprintf(szTemp, "%s<>'%s' ", lpTable->lpFields[i].szFieldName, va_arg(v, char *));
						else
							sprintf(szTemp, "%s<>%d ", lpTable->lpFields[i].szFieldName, va_arg(v, int));
					}
					else
					{
						if (lpTable->lpFields[i].btType == TABLETYPE_STR)
							sprintf(szTemp, "%s='%s' ", lpTable->lpFields[i].szFieldName, va_arg(v, char *));
						else
							sprintf(szTemp, "%s=%d ", lpTable->lpFields[i].szFieldName, va_arg(v, int));
			
					}

					strcat(pszSQL, szTemp);
					nCnt++;
				}
			}
		
			va_end(v);

			return true;
		}
		case SQLTYPE_UPDATE:
		{
			char	szWhere[128];
			char	szWhereFull[512];

			sprintf(pszSQL, "UPDATE %s SET ", lpTable->szTableName);
			
			strcpy(szWhereFull, "WHERE ");			
			
			va_start(v, lpTable);

			for (int i = 0; i < lpTable->nNumOfFields; i++)
			{
				if (lpTable->lpFields[i].fIsKey)
				{
					if (nCnt >= 1)
						strcat(szWhereFull, "AND ");

					if (lpTable->lpFields[i].btType == TABLETYPE_STR)
						sprintf(szWhere, "%s='%s' ", lpTable->lpFields[i].szFieldName, va_arg(v, char *));
					else
						sprintf(szWhere, "%s=%d ", lpTable->lpFields[i].szFieldName, va_arg(v, int));

					strcat(szWhereFull, szWhere);
					nCnt++;
				}
				else
				{
					if (nCnt2 >= 1)
						strcat(szTemp, ", ");

					if (lpTable->lpFields[i].btType == TABLETYPE_STR)
						sprintf(szTemp, "%s='%s'", lpTable->lpFields[i].szFieldName, va_arg(v, char *));
					else if (lpTable->lpFields[i].btType == TABLETYPE_DAT)
						sprintf(szWhere, "%s=GETDATE()", lpTable->lpFields[i].szFieldName);
					else
						sprintf(szTemp, "%s=%d", lpTable->lpFields[i].szFieldName, va_arg(v, int));

					strcat(pszSQL, szTemp);
					nCnt++;
				}
			}

			va_end(v);

			strcat(pszSQL, szWhereFull);

			return true;
		}
		case SQLTYPE_INSERT:
		{
			sprintf(pszSQL, "INSERT %s (", lpTable->szTableName);

			for (int i = 0; i < lpTable->nNumOfFields; i++)
			{
				strcat(pszSQL, lpTable->lpFields[i].szFieldName);

				if (i + 1 != lpTable->nNumOfFields)
					strcat(pszSQL, ", ");
				else
					strcat(pszSQL, ") ");
			}

			strcat(pszSQL, "VALUES (");

			va_start(v, lpTable);

			for (i = 0; i < lpTable->nNumOfFields; i++)
			{
				if (lpTable->lpFields[i].btType == TABLETYPE_STR)
					sprintf(szTemp, "'%s'", va_arg(v, char *));
				else if (lpTable->lpFields[i].btType == TABLETYPE_DAT)
					sprintf(szTemp, "GETDATE()");
				else
					sprintf(szTemp, "%d", va_arg(v, int));

				strcat(pszSQL, szTemp);

				if (i + 1 != lpTable->nNumOfFields)
					strcat(pszSQL, ", ");
				else
					strcat(pszSQL, ")");
			}

			va_end(v);

			return true;
		}
		case SQLTYPE_DELETE:
		{
			sprintf(pszSQL, "DELETE FROM %s WHERE ", lpTable->szTableName);

			va_start(v, lpTable);

			for (int i = 0; i < lpTable->nNumOfFields; i++)
			{
				if (lpTable->lpFields[i].fIsKey)
				{
					if (nCnt >= 1)
						strcat(pszSQL, "AND ");

					if (lpTable->lpFields[i].btType == TABLETYPE_STR)
						sprintf(szTemp, "%s='%s' ", lpTable->lpFields[i].szFieldName, va_arg(v, char *));
					else
						sprintf(szTemp, "%s=%d ", lpTable->lpFields[i].szFieldName, va_arg(v, int));

					strcat(pszSQL, szTemp);

					nCnt++;
				}
			}

			va_end(v);

			return true;
		}
		case SQLTYPE_DELETENOT:
		{
			sprintf(pszSQL, "DELETE FROM %s WHERE ", lpTable->szTableName);

			va_start(v, lpTable);

			for (int i = 0; i < lpTable->nNumOfFields; i++)
			{
				if (lpTable->lpFields[i].fIsKey)
				{
					if (nCnt >= 1)
						strcat(pszSQL, "AND ");

					if ( nCnt )
					{
						if (lpTable->lpFields[i].btType == TABLETYPE_STR)
							sprintf(szTemp, "%s<>'%s' ", lpTable->lpFields[i].szFieldName, va_arg(v, char *));
						else
							sprintf(szTemp, "%s<>%d ", lpTable->lpFields[i].szFieldName, va_arg(v, int));
					}
					else
					{
						if (lpTable->lpFields[i].btType == TABLETYPE_STR)
							sprintf(szTemp, "%s='%s' ", lpTable->lpFields[i].szFieldName, va_arg(v, char *));
						else
							sprintf(szTemp, "%s=%d ", lpTable->lpFields[i].szFieldName, va_arg(v, int));
					}

					strcat(pszSQL, szTemp);

					nCnt++;
				}
			}

			va_end(v);

			return true;
		}
	}

	return false;
}

bool _makesql(char *pszSQL, int nSQLType, LPMIRDB_TABLE lpTable, unsigned char *pData)
{
	int			nCnt = 0, nCnt2 = 0;
	char		szTemp[1024];

	switch (nSQLType)
	{
		case SQLTYPE_SELECT:
			sprintf(pszSQL, "SELECT * FROM %s", lpTable->szTableName);
			return true;
		case SQLTYPE_SELECTWHERE:
		{
			sprintf(pszSQL, "SELECT * FROM %s WHERE ", lpTable->szTableName);
			
			for (int i = 0; i < lpTable->nNumOfFields; i++)
			{
				if (lpTable->lpFields[i].fIsKey)
				{
					if (nCnt >= 1)
						strcat(pszSQL, "AND ");

					if (lpTable->lpFields[i].btType == TABLETYPE_STR)
						sprintf(szTemp, "%s='%s' ", lpTable->lpFields[i].szFieldName, (char *)pData);
					else if (lpTable->lpFields[i].btType == TABLETYPE_INT)
						sprintf(szTemp, "%s=%d ", lpTable->lpFields[i].szFieldName, *(int *)pData);
					else if (lpTable->lpFields[i].btType == TABLETYPE_DBL)
						sprintf(szTemp, "%s=%f ", lpTable->lpFields[i].szFieldName, *(double *)pData);

					pData += lpTable->lpFields[i].nSize;

					strcat(pszSQL, szTemp);
					nCnt++;
				}
			}
		
			return true;
		}
		case SQLTYPE_UPDATE:
		{
			char	szWhere[1024];
			char	szWhereFull[4096];

			sprintf(pszSQL, "UPDATE %s SET ", lpTable->szTableName);
			
			strcpy(szWhereFull, " WHERE ");			
			
			for (int i = 0; i < lpTable->nNumOfFields; i++)
			{
				if (lpTable->lpFields[i].fIsKey)
				{
					if (nCnt >= 1)
						strcat(szWhereFull, "AND ");

					if (lpTable->lpFields[i].btType == TABLETYPE_STR)
						sprintf(szWhere, "%s='%s' ", lpTable->lpFields[i].szFieldName, (char *)pData);
					else if (lpTable->lpFields[i].btType == TABLETYPE_INT)
						sprintf(szWhere, "%s=%d ", lpTable->lpFields[i].szFieldName, *(int *)pData);
					else if (lpTable->lpFields[i].btType == TABLETYPE_DBL)
						sprintf(szWhere, "%s=%d ", lpTable->lpFields[i].szFieldName, *(double *)pData);

					pData += lpTable->lpFields[i].nSize;

					strcat(szWhereFull, szWhere);
					nCnt++;
				}
				else
				{
					if (nCnt2 >= 1)
						strcat(pszSQL, ", ");

					if (lpTable->lpFields[i].btType == TABLETYPE_STR)
					{
						sprintf(szTemp, "%s='%s'", lpTable->lpFields[i].szFieldName, (char *)pData);
						pData += lpTable->lpFields[i].nSize;
					}
					else if (lpTable->lpFields[i].btType == TABLETYPE_DAT)
					{
						sprintf(szTemp, "%s=GETDATE()", lpTable->lpFields[i].szFieldName);
					}
					else if (lpTable->lpFields[i].btType == TABLETYPE_INT)
					{
						sprintf(szTemp, "%s=%d", lpTable->lpFields[i].szFieldName, *(int *)pData);
						pData += lpTable->lpFields[i].nSize;
					}
					else if (lpTable->lpFields[i].btType == TABLETYPE_DBL)
					{
						sprintf(szTemp, "%s=%f", lpTable->lpFields[i].szFieldName, *(double *)pData);
						pData += lpTable->lpFields[i].nSize;
					}

					strcat(pszSQL, szTemp);
					nCnt2++;
				}
			}

			strcat(pszSQL, szWhereFull);

#ifdef _DEBUG
			_RPT1(_CRT_WARN, "%s\n", pszSQL);
#endif
			return true;
		}
		case SQLTYPE_INSERT:
		{
			sprintf(pszSQL, "INSERT %s ( ", lpTable->szTableName);

			for (int i = 0; i < lpTable->nNumOfFields; i++)
			{
				strcat(pszSQL, lpTable->lpFields[i].szFieldName);

				if (i + 1 != lpTable->nNumOfFields)
					strcat(pszSQL, ", ");
				else
					strcat(pszSQL, ") ");
			}

			strcat(pszSQL, "VALUES ( ");

			for (i = 0; i < lpTable->nNumOfFields; i++)
			{
				if (lpTable->lpFields[i].btType == TABLETYPE_STR)
				{
					if (strcmp(lpTable->lpFields[i].szFieldName, "FLD_NAMEPREFIX") == 0)
					{
/*						int dataLen = strlen( (char *) pData );	  						
						FILE *fp = fopen( "d:\\moya.log", "wb" );
						fprintf( fp, "\r\n\r\nDataSize: %d Bytes\r\n", dataLen ); 
						if ( dataLen <= 10000 )
							fwrite( pData, 1, dataLen, fp );
						fclose( fp );
*/
						sprintf(szTemp, "''");
					}
					else
						sprintf(szTemp, "'%s'", (char *)pData);

					pData += lpTable->lpFields[i].nSize;
				}
				else if (lpTable->lpFields[i].btType == TABLETYPE_DAT)
					sprintf(szTemp, "GETDATE()");
				else if (lpTable->lpFields[i].btType == TABLETYPE_INT)
				{
					sprintf(szTemp, "%d", *(int *)pData);
					pData += lpTable->lpFields[i].nSize;
				}
				else if (lpTable->lpFields[i].btType == TABLETYPE_DBL)
				{
					sprintf(szTemp, "%f", *(double *)pData);
					pData += lpTable->lpFields[i].nSize;
				}

				strcat(pszSQL, szTemp);

				if (i + 1 != lpTable->nNumOfFields)
					strcat(pszSQL, ", ");
				else
					strcat(pszSQL, ") ");
			}

			return true;
		}
	}

	return false;
}

void _getfields(CRecordset *pRec, LPMIRDB_TABLE lpTable, unsigned char *pData)
{
	char *pszData = NULL;

	for (int i = 0; i < lpTable->nNumOfFields; i++)
	{
		if (lpTable->lpFields[i].btType == TABLETYPE_STR)
		{
			pszData = pRec->Get( lpTable->lpFields[i].szFieldName );
			ChangeSpaceToNull(pszData);

			strcpy((char *)pData, pszData);

			pData += lpTable->lpFields[i].nSize;
		}
		else if (lpTable->lpFields[i].btType == TABLETYPE_INT)
		{
			*((int *)pData) = (int)atoi( pRec->Get( lpTable->lpFields[i].szFieldName ) );

			pData += lpTable->lpFields[i].nSize;
		}
		else if (lpTable->lpFields[i].btType == TABLETYPE_DBL)
		{
			*((double *)pData) = (double)atof( pRec->Get( lpTable->lpFields[i].szFieldName ) );

			pData += lpTable->lpFields[i].nSize;
		}
		else if (lpTable->lpFields[i].btType == TABLETYPE_DAT)
		{
		}
	}
}
