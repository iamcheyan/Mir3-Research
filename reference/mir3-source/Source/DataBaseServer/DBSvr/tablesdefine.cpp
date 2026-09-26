#include <database.h>
#include "..\common\sqlhandler.h"
#include "tablesdefine.h"
#include "dbsvrwnd.h"

MIRDB_FIELDS __CHAR_INFOFIELDS[]	= {		{ "FLD_LOGINID",		TABLETYPE_STR, true,	20 },
											{ "FLD_CHARACTER",		TABLETYPE_STR, true,	20 }, // 14 -> 20
											{ "FLD_SERVERNAME",		TABLETYPE_STR, false,	9 },
											{ "FLD_JOB",			TABLETYPE_INT, false,	4 },
											{ "FLD_SEX",			TABLETYPE_INT, false,	4 },
										};

MIRDB_FIELDS __ABILITYFIELDS[]	= {		{ "FLD_CHARACTER",		TABLETYPE_STR, true,	20 }, // 14 -> 20
										{ "FLD_LEVEL",			TABLETYPE_INT, false,	4 },
//										{ "FLD_RESERVED1",		TABLETYPE_INT, false,	4 },
										{ "FLD_AC",				TABLETYPE_INT, false,	4 },
										{ "FLD_MAC",			TABLETYPE_INT, false,	4 },
										{ "FLD_DC",				TABLETYPE_INT, false,	4 },
										{ "FLD_MC",				TABLETYPE_INT, false,	4 },
										{ "FLD_SC",				TABLETYPE_INT, false,	4 },
										{ "FLD_HP",				TABLETYPE_INT, false,	4 },
										{ "FLD_MP",				TABLETYPE_INT, false,	4 },
										{ "FLD_MAXHP",			TABLETYPE_INT, false,	4 },
										{ "FLD_MAXMP",			TABLETYPE_INT, false,	4 },
										{ "FLD_EXP",			TABLETYPE_INT, false,	4 },
										{ "FLD_MAXEXP",			TABLETYPE_INT, false,	4 },
										{ "FLD_WEIGHT",			TABLETYPE_INT, false,	4 },
										{ "FLD_MAXWEIGHT",		TABLETYPE_INT, false,	4 },
										{ "FLD_WEARWEIGHT",		TABLETYPE_INT, false,	4 },
										{ "FLD_MAXWEARWEIGHT",	TABLETYPE_INT, false,	4 },
										{ "FLD_HANDWEIGHT",		TABLETYPE_INT, false,	4 },
										{ "FLD_MAXHANDWEIGHT",	TABLETYPE_INT, false,	4 },
										{ "FLD_ATOMFIRE_MC",	TABLETYPE_INT, false,	4 },
										{ "FLD_ATOMICE_MC",		TABLETYPE_INT, false,	4 },
										{ "FLD_ATOMLIGHT_MC",	TABLETYPE_INT, false,	4 },
										{ "FLD_ATOMWIND_MC",	TABLETYPE_INT, false,	4 },
										{ "FLD_ATOMHOLY_MC",	TABLETYPE_INT, false,	4 },
										{ "FLD_ATOMDARK_MC",	TABLETYPE_INT, false,	4 },
										{ "FLD_ATOMPHANTOM_MC",	TABLETYPE_INT, false,	4 },
										{ "FLD_ATOMFIRE_MAC",	TABLETYPE_INT, false,	4 },
										{ "FLD_ATOMICE_MAC",	TABLETYPE_INT, false,	4 },
										{ "FLD_ATOMLIGHT_MAC",	TABLETYPE_INT, false,	4 },
										{ "FLD_ATOMWIND_MAC",	TABLETYPE_INT, false,	4 },
										{ "FLD_ATOMHOLY_MAC",	TABLETYPE_INT, false,	4 },
										{ "FLD_ATOMDARK_MAC",	TABLETYPE_INT, false,	4 },
										{ "FLD_ATOMPHANTOM_MAC",TABLETYPE_INT, false,	4 },
								};

MIRDB_FIELDS __BONUSABILITYFIELDS[]	= {		{ "FLD_CHARACTER",		TABLETYPE_STR, true,	0 },
											{ "FLD_DC",				TABLETYPE_INT, false,	0 },
											{ "FLD_MC",				TABLETYPE_INT, false,	0 },
											{ "FLD_SC",				TABLETYPE_INT, false,	0 },
											{ "FLD_AC",				TABLETYPE_INT, false,	0 },
											{ "FLD_MAC",			TABLETYPE_INT, false,	0 },
											{ "FLD_HP",				TABLETYPE_INT, false,	0 },
											{ "FLD_MP",				TABLETYPE_INT, false,	0 },
											{ "FLD_HIT",			TABLETYPE_INT, false,	0 },
											{ "FLD_SPEED",			TABLETYPE_INT, false,	0 },
											{ "FLD_RESERVED",		TABLETYPE_INT, false,	0 },
										};

MIRDB_FIELDS __CHARACTERFIELDS[] = {		{ "FLD_CHARACTER",				TABLETYPE_STR, true,	20 },	// 14 -> 20	
											{ "FLD_USERID",					TABLETYPE_STR, true,	20 },		
											{ "FLD_DELETED",				TABLETYPE_INT, false,	4 },		
											{ "FLD_UPDATEDATETIME",			TABLETYPE_DAT, false,	0 },		
											{ "FLD_DBVERSION",				TABLETYPE_INT, false,	4 },
											{ "FLD_MAPNAME",				TABLETYPE_STR, false,	20 },		
											{ "FLD_CX",						TABLETYPE_INT, false,	4 },		
											{ "FLD_CY",						TABLETYPE_INT, false,	4 },		
											{ "FLD_DIR",					TABLETYPE_INT, false,	4 },		
											{ "FLD_HAIR",					TABLETYPE_INT, false,	4 },		
											{ "FLD_HAIRCOLORR",				TABLETYPE_INT, false,	4 },		
											{ "FLD_HAIRCOLORG",				TABLETYPE_INT, false,	4 },		
											{ "FLD_HAIRCOLORB",				TABLETYPE_INT, false,	4 },		
											{ "FLD_SEX",					TABLETYPE_INT, false,	4 },		
											{ "FLD_JOB",					TABLETYPE_INT, false,	4 },
											{ "FLD_LEVEL",					TABLETYPE_INT, false,	4 },
											{ "FLD_HP",						TABLETYPE_INT, false,	4 },
											{ "FLD_MP",						TABLETYPE_INT, false,	4 },
											{ "FLD_EXP",					TABLETYPE_INT, false,	4 },
											{ "FLD_GOLD",					TABLETYPE_INT, false,	4 },		
											{ "FLD_HOMEMAP",				TABLETYPE_STR, false,	20 },		
											{ "FLD_HOMEX",					TABLETYPE_INT, false,	4 },		
											{ "FLD_HOMEY",					TABLETYPE_INT, false,	4 },		
											{ "FLD_PKPOINT",				TABLETYPE_INT, false,	4 },		
											{ "FLD_ALLOWPARTY",				TABLETYPE_INT, false,	4 },		
											{ "FLD_FREEGULITYCOUNT",		TABLETYPE_INT, false,	4 },		
											{ "FLD_ATTACKMODE",				TABLETYPE_INT, false,	4 },		
											{ "FLD_FIGHTZONEDIE",			TABLETYPE_INT, false,	4 },		
											{ "FLD_BODYLUCK",				TABLETYPE_DBL, false,	8 },		
											{ "FLD_INCHEALTH",				TABLETYPE_INT, false,	4 },		
											{ "FLD_INCSPELL",				TABLETYPE_INT, false,	4 },		
											{ "FLD_INCHEALING",				TABLETYPE_INT, false,	4 },		
											{ "FLD_BONUSAPPLY",				TABLETYPE_INT, false,	4 },		
											{ "FLD_BONUSPOINT",				TABLETYPE_INT, false,	4 },		
											{ "FLD_HUNGRYSTATE",			TABLETYPE_INT, false,	4 },	// Horse Ride		
											{ "FLD_TESTSERVERRESETCOUNT",	TABLETYPE_INT, false,	4 },		
											{ "FLD_CGHUSETIME",				TABLETYPE_INT, false,	4 },		
											{ "FLD_ENABLEGRECALL",			TABLETYPE_INT, false,	4 },
											{ "FLD_BYTES_1",				TABLETYPE_STR, false,	3 },
											{ "FLD_HORSERACE",				TABLETYPE_INT, false,	4 },
//											{ "FLD_STATE_DECHEALTH",		TABLETYPE_INT, false },
//											{ "FLD_STATE_DATAGEARMOR",		TABLETYPE_INT, false },
//											{ "FLD_STATE_LOCKSPELL",		TABLETYPE_INT, false },
//											{ "FLD_STATE_DONTMOVE",			TABLETYPE_INT, false },
//											{ "FLD_STATE_STONE",			TABLETYPE_INT, false },
//											{ "FLD_STATE_TRANSPARENT",		TABLETYPE_INT, false },
//											{ "FLD_STATE_DEFFENCEUP",		TABLETYPE_INT, false },
//											{ "FLD_STATE_MAGDEFENCEUP",		TABLETYPE_INT, false },
//											{ "FLD_STATE_BUBBLEDEFENCEUP",	TABLETYPE_INT, false },
											{ "FLD_FAMECUR",				TABLETYPE_INT, false,	4 },	//명성치
											{ "FLD_FAMEBASE",				TABLETYPE_INT, false,	4 },	//명성치
										};

MIRDB_FIELDS __CURRENTABILITYFIELDS[] = {	{ "FLD_CHARACTER",	TABLETYPE_STR, true,	0 },
											{ "FLD_DC",			TABLETYPE_INT, false,	0 },
											{ "FLD_MC",			TABLETYPE_INT, false,	0 },
											{ "FLD_SC",			TABLETYPE_INT, false,	0 },
											{ "FLD_AC",			TABLETYPE_INT, false,	0 },
											{ "FLD_MAC",		TABLETYPE_INT, false,	0 },
											{ "FLD_HP",			TABLETYPE_INT, false,	0 },
											{ "FLD_MP",			TABLETYPE_INT, false,	0 },
											{ "FLD_HIT",		TABLETYPE_INT, false,	0 },
											{ "FLD_SPEED",		TABLETYPE_INT, false,	0 },
											{ "FLD_RESERVED",	TABLETYPE_INT, false,	0 },
										};

MIRDB_FIELDS __ITEMFIELDS[] = {	{ "FLD_CHARACTER",	TABLETYPE_STR, true,	20 }, // 14 -> 20
								{ "FLD_TYPE",		TABLETYPE_INT, true,	4 },
								{ "FLD_POS",		TABLETYPE_INT, false,	4 }, // 추가 
								{ "FLD_MAKEINDEX",	TABLETYPE_INT, false,	4 },
								{ "FLD_INDEX",		TABLETYPE_INT, false,	4 },
								{ "FLD_DURA",		TABLETYPE_INT, false,	4 },
								{ "FLD_DURAMAX",	TABLETYPE_INT, false,	4 },
								{ "FLD_DESC0",		TABLETYPE_INT, false,	4 },
								{ "FLD_DESC1",		TABLETYPE_INT, false,	4 },
								{ "FLD_DESC2",		TABLETYPE_INT, false,	4 },
								{ "FLD_DESC3",		TABLETYPE_INT, false,	4 },
								{ "FLD_DESC4",		TABLETYPE_INT, false,	4 },
								{ "FLD_DESC5",		TABLETYPE_INT, false,	4 },
								{ "FLD_DESC6",		TABLETYPE_INT, false,	4 },
								{ "FLD_DESC7",		TABLETYPE_INT, false,	4 },
								{ "FLD_DESC8",		TABLETYPE_INT, false,	4 },
								{ "FLD_DESC9",		TABLETYPE_INT, false,	4 },
								{ "FLD_DESC10",		TABLETYPE_INT, false,	4 },
								{ "FLD_DESC11",		TABLETYPE_INT, false,	4 },
								{ "FLD_DESC12",		TABLETYPE_INT, false,	4 },
								{ "FLD_DESC13",		TABLETYPE_INT, false,	4 },
								{ "FLD_COLORR",		TABLETYPE_INT, false,	4 },
								{ "FLD_COLORG",		TABLETYPE_INT, false,	4 },
								{ "FLD_COLORB",		TABLETYPE_INT, false,	4 },
								{ "FLD_NAMEPREFIX",		TABLETYPE_STR, false,	13 },
							};

MIRDB_FIELDS __MAGICFIELDS[] = {	{ "FLD_CHARACTER",	TABLETYPE_STR, true,	20 }, // 14 -> 20
									{ "FLD_MAGICID",	TABLETYPE_INT, false,	4 },
									{ "FLD_POS",		TABLETYPE_INT, false,	4 }, // 추가,
									{ "FLD_LEVEL",		TABLETYPE_INT, false,	4 },
									{ "FLD_KEY",		TABLETYPE_INT, false,	4 },
									{ "FLD_CURTRAIN",	TABLETYPE_INT, false,	4 },
								};

MIRDB_FIELDS __QUESTFIELDS[] = {	{ "FLD_CHARACTER",	TABLETYPE_STR, true,	20 }, // 14-> 20
									{ "FLD_QUESTOPENINDEX",	TABLETYPE_STR, false,	64 },
									{ "FLD_QUESTFININDEX",	TABLETYPE_STR, false,	64 },
									{ "FLD_QUEST",	TABLETYPE_STR, false,	256 },
								};

MIRDB_FIELDS __SAVEDITEMFIELDS[] = {	{ "FLD_CHARACTER",	TABLETYPE_STR, true,	20 }, // 14 -> 20
										{ "FLD_MAKEINDEX",	TABLETYPE_INT, false,	4 },
										{ "FLD_INDEX",		TABLETYPE_INT, false,	4 },
										{ "FLD_DURA",		TABLETYPE_INT, false,	4 },
										{ "FLD_DURAMAX",	TABLETYPE_INT, false,	4 },
										{ "FLD_DESC0",		TABLETYPE_INT, false,	4 },
										{ "FLD_DESC1",		TABLETYPE_INT, false,	4 },
										{ "FLD_DESC2",		TABLETYPE_INT, false,	4 },
										{ "FLD_DESC3",		TABLETYPE_INT, false,	4 },
										{ "FLD_DESC4",		TABLETYPE_INT, false,	4 },
										{ "FLD_DESC5",		TABLETYPE_INT, false,	4 },
										{ "FLD_DESC6",		TABLETYPE_INT, false,	4 },
										{ "FLD_DESC7",		TABLETYPE_INT, false,	4 },
										{ "FLD_DESC8",		TABLETYPE_INT, false,	4 },
										{ "FLD_DESC9",		TABLETYPE_INT, false,	4 },
										{ "FLD_DESC10",		TABLETYPE_INT, false,	4 },
										{ "FLD_DESC11",		TABLETYPE_INT, false,	4 },
										{ "FLD_DESC12",		TABLETYPE_INT, false,	4 },
										{ "FLD_DESC13",		TABLETYPE_INT, false,	4 },
										{ "FLD_TYPE",		TABLETYPE_INT, false,	4 },
										{ "FLD_COLORR",		TABLETYPE_INT, false,	4 },
										{ "FLD_COLORG",		TABLETYPE_INT, false,	4 },
										{ "FLD_COLORB",		TABLETYPE_INT, false,	4 },
										{ "FLD_NAMEPREFIX",		TABLETYPE_STR, false,	13 }
								};

MIRDB_FIELDS __SKILLFIELDS[] = {	{ "FLD_CHARACTER",		TABLETYPE_STR, true,	0 },
									{ "FLD_SKILLINDEX",		TABLETYPE_INT, false,	0 },
									{ "FLD_RESERVED",		TABLETYPE_INT, false,	0 },
									{ "FLD_CURTRAIN",		TABLETYPE_INT, false,	0 },
								};

// 2003/04/28 오프라인 금액 지급
MIRDB_FIELDS __ITEMGIVEFIELDS[]	= {		{ "FLD_GAMETYPE",		TABLETYPE_STR, true,	4 },
										{ "FLD_SERVER",			TABLETYPE_STR, true,	20 },
										{ "FLD_CHARACTER",		TABLETYPE_STR, true,	20 },
										{ "FLD_FROM",			TABLETYPE_STR, false,	10 },
										{ "FLD_TYPE",			TABLETYPE_INT, false,	4 },
										{ "FLD_VALUE",			TABLETYPE_INT, false,	4 },
										{ "FLD_UNTIL",			TABLETYPE_DAT, false,	0 },
										{ "FLD_REGISTER",		TABLETYPE_DAT, false,	0 },
										{ "FLD_DONE",			TABLETYPE_STR, true,	3 },
										{ "FLD_STATUS",			TABLETYPE_INT, false,	4 },
									};


MIRDB_TABLE	__CHAR_INFOTABLE		= { "TBL_CHAR_INFO",		sizeof(__CHAR_INFOFIELDS)/sizeof(MIRDB_FIELDS),			__CHAR_INFOFIELDS };

MIRDB_TABLE	__ABILITYTABLE			= { "TBL_ABILITY",			sizeof(__ABILITYFIELDS)/sizeof(MIRDB_FIELDS),			__ABILITYFIELDS };
MIRDB_TABLE	__BONUSABILITYTABLE		= { "TBL_BONUSABILITY",		sizeof(__BONUSABILITYFIELDS)/sizeof(MIRDB_FIELDS),		__BONUSABILITYFIELDS };
MIRDB_TABLE	__CHARACTERTABLE		= { "TBL_CHARACTER",		sizeof(__CHARACTERFIELDS)/sizeof(MIRDB_FIELDS),			__CHARACTERFIELDS };
MIRDB_TABLE	__CURRENTABILITYTABLE	= { "TBL_CURRENTABILITY",	sizeof(__CURRENTABILITYFIELDS)/sizeof(MIRDB_FIELDS),	__CURRENTABILITYFIELDS };
MIRDB_TABLE	__ITEMTABLE				= { "TBL_ITEM",				sizeof(__ITEMFIELDS)/sizeof(MIRDB_FIELDS),				__ITEMFIELDS };
MIRDB_TABLE	__MAGICTABLE			= { "TBL_MAGIC",			sizeof(__MAGICFIELDS)/sizeof(MIRDB_FIELDS),				__MAGICFIELDS };
MIRDB_TABLE	__QUESTTABLE			= { "TBL_QUEST",			sizeof(__QUESTFIELDS)/sizeof(MIRDB_FIELDS),				__QUESTFIELDS };
MIRDB_TABLE	__SAVEDITEMTABLE		= { "TBL_SAVEDITEM",		sizeof(__SAVEDITEMFIELDS)/sizeof(MIRDB_FIELDS),			__SAVEDITEMFIELDS };
MIRDB_TABLE	__SKILLTABLE			= { "TBL_SKILL",			sizeof(__SKILLFIELDS)/sizeof(MIRDB_FIELDS),				__SKILLFIELDS };

// 2003/04/28 오프라인 금액 지급
MIRDB_TABLE	__ITEMGIVETABLE			= { "TBL_ITEMGIVE",			sizeof(__ITEMGIVEFIELDS)/sizeof(MIRDB_FIELDS),			__ITEMGIVEFIELDS };

/*CREATE TABLE [dbo].[FLD_ITEMTYPE] (
	[FLD_TYPE] [tinyint] NULL ,
	[FLD_NAME] [char] (10) COLLATE Korean_Wansung_CI_AS NULL 
) ON [PRIMARY] */

bool UpdateRecord(CRecordset *pRec, MIRDB_TABLE* pTable, unsigned char * lpVal, bool fNew)
{
	char	szQuery[8192];

	if (fNew)
		_makesql(szQuery, SQLTYPE_INSERT, pTable, lpVal);
	else
		_makesql(szQuery, SQLTYPE_UPDATE, pTable, lpVal);

	if ( pRec->Execute( szQuery ) )
	{
		if (pRec->GetRowCount())
			return true;
	}

	GetDBServer()->m_TransLog.Log ( szQuery, true );

	return false;
}

void _setrecordTHuman(LPTCHARACTERFIELDS lpCharFields, LPTHuman lptHuman)
{
	strcpy(lptHuman->UserName, lpCharFields->fld_character);
	strcpy(lptHuman->MapName, lpCharFields->fld_mapname);
	
	lptHuman->CX	= lpCharFields->fld_cx;
	lptHuman->CY	= lpCharFields->fld_cy;
	lptHuman->Dir	= lpCharFields->fld_dir;
	lptHuman->Hair	= lpCharFields->fld_hair;
	lptHuman->Sex	= lpCharFields->fld_sex;
	lptHuman->Job	= lpCharFields->fld_job;
	lptHuman->Gold	= lpCharFields->fld_gold;
	
	lptHuman->HairColorR	= lpCharFields->fld_haircolorr;
	lptHuman->HairColorG	= lpCharFields->fld_haircolorg;
	lptHuman->HairColorB	= lpCharFields->fld_haircolorb;

	// TO PDS:
	//lptHuman->Abil.Level = lpCharFields->fld_level;
	lptHuman->Abil_Level	= lpCharFields->fld_level;
	lptHuman->Abil_HP		= lpCharFields->fld_hp;
	lptHuman->Abil_MP		= lpCharFields->fld_mp;
	lptHuman->Abil_EXP		= lpCharFields->fld_exp;

	strcpy(lptHuman->HomeMap, lpCharFields->fld_homemap);

	lptHuman->HomeX				= lpCharFields->fld_homex;
	lptHuman->HomeY				= lpCharFields->fld_homey;

	lptHuman->PkPoint			= lpCharFields->fld_pkpoint;
	lptHuman->AllowParty		= lpCharFields->fld_allowparty;
	lptHuman->FreeGuiltyCount	= lpCharFields->fld_fregulitycount;
	lptHuman->AttackMode		= lpCharFields->fld_attackmode;
	lptHuman->IncHealth			= lpCharFields->fld_inchealth;
	lptHuman->IncSpell			= lpCharFields->fld_incspell;
	lptHuman->IncHealing		= lpCharFields->fld_inchealing;
	lptHuman->FightZoneDie		= lpCharFields->fld_fightzonedie;

	strcpy(lptHuman->UserID, lpCharFields->fld_userid);

	lptHuman->DBVersion				= lpCharFields->fld_dbversion;
	lptHuman->BonusApply			= lpCharFields->fld_bonusapply;
	lptHuman->BonusPoint			= lpCharFields->fld_bonuspoint;
	lptHuman->HorseRide				= lpCharFields->fld_hungrystate;
	lptHuman->DailyQuest			= lpCharFields->fld_testserverresetcount;
	lptHuman->CGHIUseTime			= lpCharFields->fld_cghusetime;
	lptHuman->BodyLuck				= lpCharFields->fld_bodyluck;
	(lpCharFields->fld_enablegrecall ? lptHuman->BoEnableGRecall = true : lptHuman->BoEnableGRecall = false);

	lptHuman->HorseRace		= lpCharFields->fld_horserace;

	//명성치
	lptHuman->Abil_FameCur		= lpCharFields->fld_famecur;
	lptHuman->Abil_FameBase		= lpCharFields->fld_famebase;
}

void _setrecordCharFields(LPTCHARACTERFIELDS lpCharFields, LPTHuman lptHuman)
{
	ZeroMemory(lpCharFields, sizeof(TCHARACTERFIELDS));

	strcpy(lpCharFields->fld_character, lptHuman->UserName);
	strcpy(lpCharFields->fld_mapname, lptHuman->MapName);
	
	lpCharFields->fld_cx	= lptHuman->CX;
	lpCharFields->fld_cy	= lptHuman->CY;
	lpCharFields->fld_dir	= lptHuman->Dir;
	lpCharFields->fld_hair	= lptHuman->Hair;
	lpCharFields->fld_sex	= lptHuman->Sex;
	lpCharFields->fld_job	= lptHuman->Job;
	lpCharFields->fld_gold	= lptHuman->Gold;

	lpCharFields->fld_haircolorr	= lptHuman->HairColorR;
	lpCharFields->fld_haircolorg	= lptHuman->HairColorG;
	lpCharFields->fld_haircolorb	= lptHuman->HairColorB;

	// TO PDS
	lpCharFields->fld_level = lptHuman->Abil_Level;
	lpCharFields->fld_hp	= lptHuman->Abil_HP;
	lpCharFields->fld_mp	= lptHuman->Abil_MP;
	lpCharFields->fld_exp	= lptHuman->Abil_EXP;

	strcpy(lpCharFields->fld_homemap, lptHuman->HomeMap);

	lpCharFields->fld_homex				= lptHuman->HomeX;
	lpCharFields->fld_homey				= lptHuman->HomeY;
#ifdef _DEBUG
	GetApp()->SetLog( 0, "%s, %d, %d", lptHuman->HomeMap, lptHuman->HomeX, lptHuman->HomeY );
#endif
	lpCharFields->fld_pkpoint			= lptHuman->PkPoint;
	lpCharFields->fld_allowparty		= lptHuman->AllowParty;
	lpCharFields->fld_fregulitycount	= lptHuman->FreeGuiltyCount;
	lpCharFields->fld_attackmode		= lptHuman->AttackMode;
	lpCharFields->fld_inchealth			= lptHuman->IncHealth;
	lpCharFields->fld_incspell			= lptHuman->IncSpell;
	lpCharFields->fld_inchealing		= lptHuman->IncHealing;
	lpCharFields->fld_fightzonedie		= lptHuman->FightZoneDie;

	strcpy(lpCharFields->fld_userid, lptHuman->UserID);

	lpCharFields->fld_dbversion					= lptHuman->DBVersion;
	lpCharFields->fld_bonusapply				= lptHuman->BonusApply;
	lpCharFields->fld_bonuspoint				= lptHuman->BonusPoint;
	lpCharFields->fld_hungrystate				= lptHuman->HorseRide;
	lpCharFields->fld_testserverresetcount		= lptHuman->DailyQuest;
	lpCharFields->fld_cghusetime				= lptHuman->CGHIUseTime;
	lpCharFields->fld_bodyluck					= lptHuman->BodyLuck;
	lpCharFields->fld_enablegrecall				= lptHuman->BoEnableGRecall;

	lpCharFields->fld_horserace		= lptHuman->HorseRace;

	//명성치
	lpCharFields->fld_famecur	= lptHuman->Abil_FameCur;
	lpCharFields->fld_famebase	= lptHuman->Abil_FameBase;
}

void _setrecordTBagItem(LPTITEMFIELDS lpItemFields, LPTBagItem lptBagItem, int *pnBagItem)
{
	LPTUserItem lpUserItem = NULL;

	switch (lpItemFields->fld_type)
	{
		case U_DRESS:
			lpUserItem = &lptBagItem->uDress;
			break;
		case U_WEAPON:
			lpUserItem = &lptBagItem->uWeapon;
			break;
		case U_RIGHTHAND:
			lpUserItem = &lptBagItem->uRightHand;
			break;
		case U_NECKLACE:
			lpUserItem = &lptBagItem->uNecklace;
			break;
		case U_HELMET:
			lpUserItem = &lptBagItem->uHelmet;
			break;
		case U_ARMRINGL:
			lpUserItem = &lptBagItem->uArmRingL;
			break;
		case U_ARMRINGR:
			lpUserItem = &lptBagItem->uArmRingR;
			break;
		case U_RINGL:
			lpUserItem = &lptBagItem->uRingL;
			break;
		case U_RINGR:
			lpUserItem = &lptBagItem->uRingR;
			break;
		case U_BUJUCK:
			lpUserItem = &lptBagItem->uBujuck;
			break;
		case U_BELT:
			lpUserItem = &lptBagItem->uBelt;
			break;
		case U_BOOTS:
			lpUserItem = &lptBagItem->uBoots;
			break;
		case U_CHARM:
			lpUserItem = &lptBagItem->uCharm;
			break;
		default:
			lpUserItem = &(lptBagItem->Bags[*pnBagItem]);
			*pnBagItem += 1;
	}

	lpUserItem->MakeIndex	= lpItemFields->fld_makeindex;
	lpUserItem->Index		= lpItemFields->fld_index;
	lpUserItem->Dura		= lpItemFields->fld_dura;
	lpUserItem->DuraMax		= lpItemFields->fld_duramax;
	for (int i = 0; i < 14; i++)
		lpUserItem->Desc[i]	= (BYTE)lpItemFields->fld_desc[i];
	lpUserItem->ColorR		= lpItemFields->fld_colorr;
	lpUserItem->ColorG		= lpItemFields->fld_colorg;
	lpUserItem->ColorB		= lpItemFields->fld_colorb;

	if (strlen(lpItemFields->Prefix))
		strcpy(lpUserItem->Prefix, lpItemFields->Prefix);
	else
		ZeroMemory(lpUserItem->Prefix, sizeof(lpUserItem->Prefix));
}

void _setrecordTItemFields(LPTITEMFIELDS lpItemFields, LPTUserItem lpUserItem, int nType, char *pszName , int nPos)
{
	strcpy(lpItemFields->fld_character, pszName);

	lpItemFields->fld_type = nType;
	lpItemFields->fld_pos  = nPos;

	lpItemFields->fld_makeindex	= lpUserItem->MakeIndex;
	lpItemFields->fld_index		= lpUserItem->Index;
	lpItemFields->fld_dura		= lpUserItem->Dura;
	lpItemFields->fld_duramax	= lpUserItem->DuraMax;

	for (int i = 0; i < 14; i++)
		lpItemFields->fld_desc[i] = lpUserItem->Desc[i];

	lpItemFields->fld_colorr	= lpUserItem->ColorR;
	lpItemFields->fld_colorg	= lpUserItem->ColorG;
	lpItemFields->fld_colorb	= lpUserItem->ColorB;

	if (strlen(lpUserItem->Prefix))
	{
//		strcpy(lpItemFields->Prefix, lpUserItem->Prefix);
		GetApp()->SetLog( 0, "SavedItem[SAVE] : %c %c %c", lpUserItem->Prefix[0], lpUserItem->Prefix[1], lpUserItem->Prefix[2]);	
		ZeroMemory(lpItemFields->Prefix, sizeof(lpItemFields->Prefix));
	}
	else
	{
		ZeroMemory(lpItemFields->Prefix, sizeof(lpItemFields->Prefix));
	}
}

void _StrucToFieldsAbil(LPTABILITYFIELDS lpAbilFields, TAbility* lptAbility,  char *pszName)
{
	strcpy(lpAbilFields->fld_character, pszName);

	lpAbilFields->fld_level		= lptAbility->Level;

	lpAbilFields->fld_ac		= lptAbility->AC;
	lpAbilFields->fld_mac		= 0;
	lpAbilFields->fld_dc		= lptAbility->DC;
	lpAbilFields->fld_mc		= 0;
	lpAbilFields->fld_sc		= 0;

	lpAbilFields->fld_hp		= lptAbility->HP;
	lpAbilFields->fld_mp		= lptAbility->MP;

	lpAbilFields->fld_maxhp		= lptAbility->MaxHP;
	lpAbilFields->fld_maxmp		= lptAbility->MAXMP;

	lpAbilFields->fld_exp		= lptAbility->Exp;
	lpAbilFields->fld_maxexp	= lptAbility->MaxExp;

	lpAbilFields->fld_weight	= lptAbility->Weight;
	lpAbilFields->fld_maxweight	= lptAbility->MaxWeight;

	lpAbilFields->fld_wearweight		= lptAbility->WearWeight;
	lpAbilFields->fld_maxwearweight		= lptAbility->MaxWearWeight;
	lpAbilFields->fld_handweight		= lptAbility->HandWeight;
	lpAbilFields->fld_maxhandweight		= lptAbility->MaxHandWeight;

/*	lptAbility->FameLevel;
	lptAbility->MiningLevel;
	lptAbility->FramingLevel;
	lptAbility->FishingLevel;

	lptAbility->FameExp;
	lptAbility->FameMaxExp;
	lptAbility->MiningExp;
	lptAbility->MiningMaxExp;
	lptAbility->FramingExp;
	lptAbility->FramingMaxExp;
	lptAbility->FishingExp;
	lptAbility->FishingMaxExp; */
	lpAbilFields->fld_atomfire_mc		= lptAbility->ATOM_MC[ATOM_FIRE];
	lpAbilFields->fld_atomice_mc		= lptAbility->ATOM_MC[ATOM_ICE];
	lpAbilFields->fld_atomlight_mc		= lptAbility->ATOM_MC[ATOM_LIGHT];
	lpAbilFields->fld_atomwind_mc		= lptAbility->ATOM_MC[ATOM_WIND];
	lpAbilFields->fld_atomholy_mc		= lptAbility->ATOM_MC[ATOM_HOLY];
	lpAbilFields->fld_atomdark_mc		= lptAbility->ATOM_MC[ATOM_DARK];
	lpAbilFields->fld_atomphantom_mc	= lptAbility->ATOM_MC[ATOM_PHANTOM];
	lpAbilFields->fld_atomfire_mac		= lptAbility->ATOM_MAC[ATOM_FIRE];
	lpAbilFields->fld_atomice_mac		= lptAbility->ATOM_MAC[ATOM_ICE];
	lpAbilFields->fld_atomlight_mac		= lptAbility->ATOM_MAC[ATOM_LIGHT];
	lpAbilFields->fld_atomwind_mac		= lptAbility->ATOM_MAC[ATOM_WIND];
	lpAbilFields->fld_atomholy_mac		= lptAbility->ATOM_MAC[ATOM_HOLY];
	lpAbilFields->fld_atomdark_mac		= lptAbility->ATOM_MAC[ATOM_DARK];
	lpAbilFields->fld_atomphantom_mac	= lptAbility->ATOM_MAC[ATOM_PHANTOM];
}

void _FieldsToStrucAbil(LPTABILITYFIELDS lpAbilFields, TAbility* lptAbility)
{
	lptAbility->Level		= lpAbilFields->fld_level;
	                      
	lptAbility->AC			= lpAbilFields->fld_ac;
	lptAbility->DC			= lpAbilFields->fld_dc;
	                      
	lptAbility->HP			= lpAbilFields->fld_hp;
	lptAbility->MP			= lpAbilFields->fld_mp;
	                      
	lptAbility->MaxHP		= lpAbilFields->fld_maxhp;
	lptAbility->MAXMP		= lpAbilFields->fld_maxmp;
	                      
	lptAbility->Exp			= lpAbilFields->fld_exp;
	lptAbility->MaxExp		= lpAbilFields->fld_maxexp;
	                      
	lptAbility->Weight		= lpAbilFields->fld_weight;
	lptAbility->MaxWeight	= lpAbilFields->fld_maxweight;

	lptAbility->WearWeight		= lpAbilFields->fld_wearweight;
	lptAbility->MaxWearWeight	= lpAbilFields->fld_maxwearweight;
	lptAbility->HandWeight		= lpAbilFields->fld_handweight;
	lptAbility->MaxHandWeight	= lpAbilFields->fld_maxhandweight;
										  
	lptAbility->ATOM_MC[ATOM_FIRE]		= lpAbilFields->fld_atomfire_mc;
	lptAbility->ATOM_MC[ATOM_ICE]		= lpAbilFields->fld_atomice_mc;
	lptAbility->ATOM_MC[ATOM_LIGHT]		= lpAbilFields->fld_atomlight_mc;
	lptAbility->ATOM_MC[ATOM_WIND]		= lpAbilFields->fld_atomwind_mc;
	lptAbility->ATOM_MC[ATOM_HOLY]		= lpAbilFields->fld_atomholy_mc;
	lptAbility->ATOM_MC[ATOM_DARK]		= lpAbilFields->fld_atomdark_mc;
	lptAbility->ATOM_MC[ATOM_PHANTOM]	= lpAbilFields->fld_atomphantom_mc;
	lptAbility->ATOM_MAC[ATOM_FIRE]		= lpAbilFields->fld_atomfire_mac;
	lptAbility->ATOM_MAC[ATOM_ICE]		= lpAbilFields->fld_atomice_mac;
	lptAbility->ATOM_MAC[ATOM_LIGHT]	= lpAbilFields->fld_atomlight_mac;
	lptAbility->ATOM_MAC[ATOM_WIND]		= lpAbilFields->fld_atomwind_mac;
	lptAbility->ATOM_MAC[ATOM_HOLY]		= lpAbilFields->fld_atomholy_mac;
	lptAbility->ATOM_MAC[ATOM_DARK]		= lpAbilFields->fld_atomdark_mac;
	lptAbility->ATOM_MAC[ATOM_PHANTOM]	= lpAbilFields->fld_atomphantom_mac;
/*	lptAbility->FameLevel;				  
	lptAbility->MiningLevel;			  
	lptAbility->FramingLevel;
	lptAbility->FishingLevel;

	lptAbility->FameExp;
	lptAbility->FameMaxExp;
	lptAbility->MiningExp;
	lptAbility->MiningMaxExp;
	lptAbility->FramingExp;
	lptAbility->FramingMaxExp;
	lptAbility->FishingExp;
	lptAbility->FishingMaxExp; */
}

void _FieldsToStrucUseMagic(LPTMAGICFIELDS lpMagicFields, TUseMagicInfo* lptUseMagicInfo )
{
	lptUseMagicInfo->MagicId	= lpMagicFields->fld_magicid;
	lptUseMagicInfo->Level		= lpMagicFields->fld_level;
	lptUseMagicInfo->Key		= lpMagicFields->fld_key;
	lptUseMagicInfo->Curtrain	= lpMagicFields->fld_curtrain;
}

void _StrucToFieldsUseMagic(LPTMAGICFIELDS lpMagicFields, TUseMagicInfo* lptUseMagicInfo, char *pszName , int nPos)
{
	strcpy(lpMagicFields->fld_character, pszName);

	lpMagicFields->fld_pos			= nPos;
	lpMagicFields->fld_magicid		= lptUseMagicInfo->MagicId;
	lpMagicFields->fld_level		= lptUseMagicInfo->Level;
	lpMagicFields->fld_key			= lptUseMagicInfo->Key;
	lpMagicFields->fld_curtrain		= lptUseMagicInfo->Curtrain;
}
