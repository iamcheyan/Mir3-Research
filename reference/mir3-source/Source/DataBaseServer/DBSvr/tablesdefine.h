
#ifndef _TABLESDEFINE
#define _TABLESDEFINE

#include "../common/sqlhandler.h"

#define MAXQUESTINDEXBYTE		24
#define MAXQUESTBYTE			176

#define MAXBAGITEM				46
#define MAXBAGITEMALL			MAXBAGITEM + 12
#define MAXHORSEBAG				30
#define MAXUSERMAGIC			25//20  //(sonmg 2004/10/27)
#define MAXSAVEITEM				100

#define _MAX_ATOM_				8

#define ATOM_FIRE				0
#define ATOM_ICE				1
#define	ATOM_LIGHT				2
#define ATOM_WIND				3
#define ATOM_HOLY				4
#define ATOM_DARK				5
#define	ATOM_PHANTOM			6

#define U_DRESS					0
#define U_WEAPON				1
#define U_RIGHTHAND				2
#define U_NECKLACE				3
#define U_HELMET				4
#define U_ARMRINGL				5
#define U_ARMRINGR				6
#define U_RINGL					7
#define U_RINGR					8
#define U_BUJUCK				9
#define U_BELT					10
#define U_BOOTS					11
#define U_CHARM					12

#define U_BAG					77
#define U_SAVE					88

#pragma pack(1)

typedef struct tagTAbility
{
	BYTE			Level;

	WORD			AC;
//	WORD			MAC;
	WORD			DC;
//	WORD			MC;
//	WORD			SC;
	
	WORD			HP;
	WORD			MP;

	WORD			MaxHP;
	WORD			MAXMP;

	LONG			Exp;
	LONG			MaxExp;

	WORD			Weight;
	WORD			MaxWeight;

	BYTE			WearWeight;
	BYTE			MaxWearWeight;
	BYTE			HandWeight;
	BYTE			MaxHandWeight;

	BYTE			FameLevel;
	BYTE			MiningLevel;
	BYTE			FramingLevel;
	BYTE			FishingLevel;

	int				FameExp;
	int				FameMaxExp;
	int				MiningExp;
	int				MiningMaxExp;
	int				FramingExp;
	int				FramingMaxExp;
	int				FishingExp;
	int				FishingMaxExp;

	WORD			ATOM_MC[_MAX_ATOM_];
	WORD			ATOM_MAC[_MAX_ATOM_];
} TAbility, *LPTAbility;

typedef struct tagTUserItem
{
	int				MakeIndex;
	WORD			Index;
	WORD			Dura;
	WORD			DuraMax;
	BYTE			Desc[14];
	BYTE			ColorR;
	BYTE			ColorG;
	BYTE			ColorB;
	char			Prefix[13];
} TUserItem, *LPTUserItem;

typedef struct tagTNakedAbility
{
	WORD			DC;
	WORD			MC;
	WORD			SC;
	WORD			AC;
	WORD			MAC;
	WORD			HP;
	WORD			MP;
	WORD			Hit;
	WORD			Speed;
	WORD			Reserved;
} TNakedAbility, *LPTNakedAbility;

typedef struct tagTSkillInfo
{
	WORD			SkillIndex;
	WORD			Reserved;
	int				CurTrain;
} TSkillInfo, *LPTSkillInfo;

typedef struct tagTUseMagicInfo
{
	WORD			MagicId;
	BYTE			Level;
	char			Key;
	int				Curtrain;
} TUseMagicInfo, *LPTUseMagicInfo;

typedef struct tagTHuman
{
	char			UserName[20];
	char			MapName[20];
	WORD			CX;
	WORD			CY;
	BYTE			Dir;
	BYTE			Hair;
	BYTE			HairColorR;
	BYTE			HairColorG;
	BYTE			HairColorB;
	BYTE			Sex;
	BYTE			Job;
	int				Gold;
//	TAbility		Abil;	// TO PDS:
	BYTE			Abil_Level;
	WORD			Abil_HP;
	WORD			Abil_MP;
	long			Abil_EXP;
	WORD			StatusArr[16];
	char			HomeMap[20];
	WORD			HomeX;
	WORD			HomeY;
//	TSkillInfo		SkillArr[8];
	int				PkPoint;
	BYTE			AllowParty;
	BYTE			FreeGuiltyCount;
	BYTE			AttackMode;
	BYTE			IncHealth;
	BYTE			IncSpell;
	BYTE			IncHealing;
	BYTE			FightZoneDie;
	char			UserID[20];
	BYTE			DBVersion;
	BYTE			BonusApply;
//	TNakedAbility	BonusAbil;
//	TNakedAbility	CurBonusAbil;
	int				BonusPoint;
	LONG			DailyQuest;
	BYTE			HorseRide;
	WORD			CGHIUseTime;
	double			BodyLuck;
	bool			BoEnableGRecall;
	BYTE			bytes_1[3];
	BYTE			QuestOpenIndex[MAXQUESTINDEXBYTE];
	BYTE			QuestFinIndex[MAXQUESTINDEXBYTE];
	BYTE			Quest[MAXQUESTBYTE];
	BYTE			HorseRace;
	long			Abil_FameCur;	//현재 명성치(2004/10/22)
	long			Abil_FameBase;	//누적 명성치(2004/10/22)
} THuman, *LPTHuman;

typedef struct tagTBagItem
{
	TUserItem		uDress;
	TUserItem		uWeapon;
	TUserItem		uRightHand;  //초 잡는 자리
	TUserItem		uHelmet;
	TUserItem		uNecklace;
	TUserItem		uArmRingL;
	TUserItem		uArmRingR;
	TUserItem		uRingL;
	TUserItem		uRingR;

	TUserItem		uBujuck;		//부적(추가)
	TUserItem		uBelt;	//벨트,  (추가)
	TUserItem		uBoots;		//신발 (추가)
//TO PDS:
	TUserItem		uCharm;		//수호석 (미르2추가)
	TUserItem		Bags[MAXBAGITEM];
//	TUserItem		HorseBags[MAXHORSEBAG];
} TBagItem, *LPTBagItem;

typedef struct tagTUseMagic
{
	TUseMagicInfo	Magics[MAXUSERMAGIC];
} TUseMagic, *LPTUseMagic;

typedef struct tagTSaveItem
{
	TUserItem		Items[MAXSAVEITEM];
} TSaveItem, *LPTSaveItem;

typedef struct tagTMirDBBlockData
{
	THuman			DBHuman;
	TBagItem		DBBagItem;
	TUseMagic		DBUseMagic;
	TSaveItem		DBSaveItem;
} TMirDBBlockData, *LPTMirDBBlockData;

typedef struct tagFDBRecord
{
	bool			Deleted;
	double			UpdateDateTime;
	char			Key[15];
	TMirDBBlockData	Block;
} FDBRecord;

typedef struct tagTCHARINFO
{
	char	fld_userid[20];
	char	fld_character[20]; // 14 -> 20
	char	fld_servername[9];
	int		fld_job;
	int		fld_sex;
} TCHARINFO;


typedef struct tagTABILITYFIELDS
{
	char	fld_character[20];  // 14 -> 20
	int		fld_level;
//	int		fld_reserved1;
	int		fld_ac;
	int		fld_mac;
	int		fld_dc;
	int		fld_mc;
	int		fld_sc;
	int		fld_hp;
	int		fld_mp;
	int		fld_maxhp;
	int		fld_maxmp;
	int		fld_exp;
	int		fld_maxexp;
	int		fld_weight;
	int		fld_maxweight;
	int		fld_wearweight;
	int		fld_maxwearweight;
	int		fld_handweight;
	int		fld_maxhandweight;
	int		fld_atomfire_mc;
	int		fld_atomice_mc;
	int		fld_atomlight_mc;
	int		fld_atomwind_mc;
	int		fld_atomholy_mc;
	int		fld_atomdark_mc;
	int		fld_atomphantom_mc;
	int		fld_atomfire_mac;
	int		fld_atomice_mac;
	int		fld_atomlight_mac;
	int		fld_atomwind_mac;
	int		fld_atomholy_mac;
	int		fld_atomdark_mac;
	int		fld_atomphantom_mac;
} TABILITYFIELDS, *LPTABILITYFIELDS;

typedef struct tagTCHARACTERFIELDS
{
	char	fld_character[20]; // 14 -> 20
	char	fld_userid[20];
	int		fld_deleted;
	int		fld_dbversion;
	char	fld_mapname[20];
	int		fld_cx;
	int		fld_cy;
	int		fld_dir;
	int		fld_hair;
	int		fld_haircolorr;
	int		fld_haircolorg;
	int		fld_haircolorb;
	int		fld_sex;
	int		fld_job;
	int		fld_level;
	int		fld_hp;		// To PDS
	int		fld_mp;		// To PDS
	int		fld_exp;	// To PDS
	int		fld_gold;
	char	fld_homemap[20];
	int		fld_homex;
	int		fld_homey;
	int		fld_pkpoint;
	int		fld_allowparty;
	int		fld_fregulitycount;
	int		fld_attackmode;
	int		fld_fightzonedie;
	double	fld_bodyluck;
	int		fld_inchealth;
	int		fld_incspell;
	int		fld_inchealing;
	int		fld_bonusapply;
	int		fld_bonuspoint;
	int		fld_hungrystate;
	int		fld_testserverresetcount;
	int		fld_cghusetime;
	int		fld_enablegrecall;
	char	fld_bytes_1[3];
	int		fld_horserace;
//	int		fld_state_dechealth;
//	int		fld_state_datagearmor;
//	int		fld_state_lockspell;
//	int		fld_state_dontmove;
//	int		fld_state_stone;
//	int		fld_state_transparent;
//	int		fld_state_deffenceup;
//	int		fld_state_magdefenceup;
//	int		fld_state_bubbledefenceup;
	long	fld_famecur;	//명성치
	long	fld_famebase;	//명성치
} TCHARACTERFIELDS, *LPTCHARACTERFIELDS;

typedef struct tagTITEMFIELDS
{
	char	fld_character[20]; // 14 -> 20
	int		fld_type;
	int     fld_pos;		// 추가 박대성 
	int		fld_makeindex;
	int		fld_index;
	int		fld_dura;
	int		fld_duramax;
	int		fld_desc[14];
	int		fld_colorr;
	int		fld_colorg;
	int		fld_colorb;
	char	Prefix[13];
} TITEMFIELDS, *LPTITEMFIELDS;

// 2003/04/28 오프라인 금액 추가
typedef struct tagTITEMGIVEFIELDS
{
	char	fld_gametype[4];
	char	fld_server[20];
	char	fld_character[20];
	char	fld_from[10];
	int		fld_type;
	int     fld_value;
	double	fld_until;
	double	fld_register;
	char	fld_done[3];
	int     fld_status;
} TITEMGIVEFIELDS, *LPTITEMGIVEFIELDS;

typedef struct tagTMAGICFIELDS
{
	char	fld_character[20]; // 14 -> 20
	int		fld_magicid;
	int		fld_pos;			// 추가 박대성
	int		fld_level;
	int		fld_key;
	int		fld_curtrain;
} TMAGICFIELDS, *LPTMAGICFIELDS;

typedef struct tagTQUESTFIELDS
{
	char	fld_character[20];	// 14 -> 20
	char	fld_questopenindex[64];
	char	fld_questfinindex[64];
	char	fld_quest[256];
} TQUESTFIELDS, *LPTQUESTFIELDS;

#pragma pack(8)

extern MIRDB_TABLE	__CHAR_INFOTABLE;

extern MIRDB_TABLE	__ABILITYTABLE;
extern MIRDB_TABLE	__BONUSABILITYTABLE;
extern MIRDB_TABLE	__CHARACTERTABLE;
extern MIRDB_TABLE	__CURRENTABILITYTABLE;
extern MIRDB_TABLE	__ITEMTABLE;
extern MIRDB_TABLE	__MAGICTABLE;
extern MIRDB_TABLE	__QUESTTABLE;
extern MIRDB_TABLE	__SAVEDITEMTABLE;
extern MIRDB_TABLE	__SKILLTABLE;
// 2003/04/28 오프라인 금액 추가
extern MIRDB_TABLE	__ITEMGIVETABLE;

bool UpdateRecord(CRecordset *pRec, MIRDB_TABLE* pTable, unsigned char * lpVal, bool fNew);

void _setrecordTHuman(LPTCHARACTERFIELDS lpCharFields, LPTHuman lptHuman);
void _setrecordCharFields(LPTCHARACTERFIELDS lpCharFields, LPTHuman lptHuman);

void _setrecordTBagItem(LPTITEMFIELDS lpItemFields, LPTBagItem lptBagItem, int *pnBagItem);
void _setrecordTItemFields(LPTITEMFIELDS lpItemFields, LPTUserItem lpUserItem, int nType, char *pszName , int nPos);

void _StrucToFieldsAbil(LPTABILITYFIELDS lpAbilFields, TAbility* lptAbility, char *pszName);
void _FieldsToStrucAbil(LPTABILITYFIELDS lpAbilFields, TAbility* lptAbility);

void _FieldsToStrucUseMagic(LPTMAGICFIELDS lpMagicFields, TUseMagicInfo* lptUseMagicInfo);
void _StrucToFieldsUseMagic(LPTMAGICFIELDS lpMagicFields, TUseMagicInfo* lptUseMagicInfo, char *pszName ,int nPos);

#endif
