unit Grobal2;

interface

uses
	Windows, SysUtils, Classes, Hutil32;

type
   TMsgHeader = record  //°ÔÀÌÆ®¿Í ¼­¹ö Åë½Å¿¡ »ç¿ë
      Code:          integer;  //$aa55aa55;
      SNumber:       integer;  //socket number
      UserGateIndex: word;    //Gate¿¡¼­ÀÇ Index
      Ident:         word;    //
      UserListIndex: word;    //¼­¹ö¿¡ UserList¿¡¼­ÀÇ Index
      temp:          word;
      length:        integer;  //body binary ÀÇ ±æÀÌ
   end;
   PTMsgHeader = ^TMsgHeader;

   TDefaultMessage = record
      Recog:   integer;       //4
      Ident:   word;          //2
      Param:   word;          //2
      Tag:     word;          //2
      Series:  word;          //2
      Etc:     word;//
      Etc2:    word;//
   end;
   PTDefaultMessage = ^TDefaultMessage;

   //Å¬¶óÀÌ¾ğÆ®¿¡¼­ »ç¿ë
   TChrMsg = record
      ident:   integer;
      x:       integer;
      y:       integer;
      dir:     integer;
      feature: integer;
      state:   integer;
      saying:  string;
      sound:   integer;
   end;
   PTChrMsg = ^TChrMsg;

   //¼­¹ö¿¡¼­ »ç¿ë
   TMessageInfo = record
      Ident	: word;
      wParam	: word;
      lParam1	: Longint;
      lParam2 : Longint;
      lParam3 : Longint;
      sender	: TObject;
      target  : TObject;
      description : string;
   end;
   PTMessageInfo = ^TMessageInfo;

   TMessageInfoPtr = record
      Ident	: word;
      wParam	: word;
      lParam1	: Longint;
      lParam2 : Longint;
      lParam3 : Longint;
      sender	: TObject;
      //target  : TObject;
      deliverytime: longword;  //µµÂø ½Ã°£...
      descptr : PChar;
   end;
   PTMessageInfoPtr = ^TMessageInfoPtr;

   TShortMessage = record
      Ident    : word;
      msg      : word;
   end;

   TMessageBodyW = record
     Param1    : word;
     Param2    : word;
     Tag1      : word;
     Tag2      : word;
   end;

   TMessageBodyWL = record
     lParam1   : longint;
     lParam2   : longint;
     lTag1     : longint;
     lTag2     : longint;
   end;

   TCharDesc = record                	// sm_walk ÀÇ ÀÌµ¿ Á¤º¸
     Feature : integer;                // 4 = (9)
     Status  : integer;
   end;

   TPowerClass = record
      Min   : byte;
      Ever  : byte;
      Max   : byte;
      dummy : byte;
   end;

   TNakedAbility = record
      DC          : word;
      MC          : word;
      SC          : word;
      AC          : word;
      MAC         : word;
      HP          : word;
      MP          : word;
      Hit         : word;
      Speed       : word;
      Reserved    : word;
   end;
   PTNakedAbility = ^TNakedAbility;

   TChgAttr = record
      attr         : byte;          //º¯°æµÈ ¼Ó¼º ½Äº° 1:AC 2:MAC 3:DC 4:MC 5:SC
      min          : byte;          //DC,MC,SCÀÇ min/max  AC,MACÀÎ°æ¿ì MakeWord(min,max)°ªÀÓ
      max          : byte;
   end;

{$ifdef MIR2EI}  //ei¿¡¼­ º¯°æ µÇ´Â °Íµé

   //ei
   TStdItem = record
      Name		    : string[30];        //14, º¯°æ  ¾ÆÀÌÅÛ ÀÌ¸§ (ÃµÇÏÁ¦ÀÏ°Ë)
      StdMode      : byte;              //
      Shape 	   : byte;              // ÇüÅÂº° ÀÌ¸§ (Ã¶°Ë)
      CharLooks    : byte;              // gadget
      Weight       : byte;              // ¹«°Ô
      AniCount     : byte;              // 1º¸´Ù Å©¸é ¾Ö´Ï¸ŞÀÌ¼Ç µÇ´Â ¾ÆÀÌÅÛ (´Ù¸¥ ¿ëµµ·Î ¸¹ÀÌ ¾²ÀÓ)
      SpecialPwr   : shortint;          // +ÀÌ¸é »ı¹°°ø°İ+´É·Â, -ÀÌ¸é ¾ğµ¥µå°ø°İ+
                                        //1~10 °­µµ
                                        //-50~-1 ¾ğµ¥µå ´É·ÂÄ¡ Çâ»ó
                                        //-100~-51 ¾ğµ¥µå ´É·ÂÄ¡ °¨¼Ò
      ItemDesc     : byte;              //$01 IDC_UNIDENTIFIED  (¾ÆÀÌ´íÆ¼ÆÄÀÌ ¾È µÈ °Í, Å¬¶óÀÌ¾ğÆ®¿¡¼­¸¸ »ç¿ëµÊ)
                                        //$02 IDC_UNABLETAKEOFF (¼Õ¿¡¼­ ¶³¾îÁöÁö ¾ÊÀ½, ¹ÌÁö¼ö »ç¿ë °¡´É)
                                        //$04 IDC_NEVERTAKEOFF  (¼Õ¿¡¼­ ¶³¾îÁöÁö ¾ÊÀ½, ¹ÌÁö¼ö »ç¿ë ºÒ°¡´É)
                                        //$08 IDC_DIEANDBREAK   (Á×À¸¸é ±úÁö´Â ¼Ó¼º)
                                        //$10 IDC_NEVERLOSE     (Á×¾î´õ ¶³¾îÁöÁö ¾ÊÀ½)
      Looks        : word;              // ±×¸² ¹øÈ£
      DuraMax      : word;
      AC           : word;              // ¹æ¾î·Â
      MACType      : byte;
      MAC          : word;              // ¸¶Ç×·Â
      DC           : word;              // µ¥¹ÌÁö
      MCType       : byte;
      MC           : word;              // ¼ú»çÀÇ ¸¶¹ı ÆÄ¿ö
      AtomDCType   : byte;
      AtomDC       : word;
//      SCType       : byte;
//      SC           : word;              // µµ»çÀÇ Á¤½Å·Â gadget
      Need         : byte;              // 0:Level, 1:DC, 2:MC, 3:SC
      NeedLevel    : byte;              // 1..60 level value...
      Price        : integer;
      FuncType     : byte;
      Throw        : byte;              // 1: Á×¾úÀ»¶§ ¾È¶³±À (gagdet)
                                        // 2: Ä«¿îÆ®Çü ¾ÆÀÌÅÛ (gadget)
      Reserved     : array[0..11] of byte;
   end;
   PTStdItem = ^TStdItem;

    TStdItemPack = packed record         // Gadget
        Name	    : array[0..29] of char;       // ¾ÆÀÌÅÛ ÀÌ¸§ (ÃµÇÏÁ¦ÀÏ°Ë)
        StdMode     : byte;              //
        Shape       : byte;             // ÇüÅÂº° ÀÌ¸§ (Ã¶°Ë)
        Weight      : byte;              // ¹«°Ô
        AniCount    : byte;              // 1º¸´Ù Å©¸é ¾Ö´Ï¸ŞÀÌ¼Ç µÇ´Â ¾ÆÀÌÅÛ (´Ù¸¥ ¿ëµµ·Î ¸¹ÀÌ ¾²ÀÓ)
        SpecialPwr  : shortint;          // +ÀÌ¸é »ı¹°°ø°İ+´É·Â, -ÀÌ¸é ¾ğµ¥µå°ø°İ+
                                        //1~10 °­µµ
                                        //-50~-1 ¾ğµ¥µå ´É·ÂÄ¡ Çâ»ó
                                        //-100~-51 ¾ğµ¥µå ´É·ÂÄ¡ °¨¼Ò
        ItemDesc     : byte;              //$01 IDC_UNIDENTIFIED  (¾ÆÀÌ´íÆ¼ÆÄÀÌ ¾È µÈ °Í, Å¬¶óÀÌ¾ğÆ®¿¡¼­¸¸ »ç¿ëµÊ)
                                        //$02 IDC_UNABLETAKEOFF (¼Õ¿¡¼­ ¶³¾îÁöÁö ¾ÊÀ½, ¹ÌÁö¼ö »ç¿ë °¡´É)
                                        //$04 IDC_NEVERTAKEOFF  (¼Õ¿¡¼­ ¶³¾îÁöÁö ¾ÊÀ½, ¹ÌÁö¼ö »ç¿ë ºÒ°¡´É)
                                        //$08 IDC_DIEANDBREAK   (Á×À¸¸é ±úÁö´Â ¼Ó¼º)
                                        //$10 IDC_NEVERLOSE     (Á×¾î´õ ¶³¾îÁöÁö ¾ÊÀ½)
        Looks        : word;              // ±×¸² ¹øÈ£
        DuraMax      : word;
        AC           : word;              // ¹æ¾î·Â
        MACType      : byte;
        MAC          : word;              // ¸¶Ç×·Â
        DC           : word;              // µ¥¹ÌÁö
        MCType       : byte;
        MC           : word;              // ¼ú»çÀÇ ¸¶¹ı ÆÄ¿ö
        AtomDCType   : byte;
        AtomDC       : word;
        Need         : byte;              // 0:Level, 1:DC, 2:MC, 3:SC
        NeedLevel    : byte;              // 1..60 level value...
        Price        : integer;
        FuncType     : byte;
        Throw        : byte;                // 1: Á×¾úÀ»¶§ ¾È¶³±À (gagdet)
                                            // 2: Ä«¿îÆ®Çü ¾ÆÀÌÅÛ (gadget)
    end;
   PTStdItemPack = ^TStdItemPack;

   //ei
   TUserItem = packed record // gadget
      MakeIndex  : integer;      //¼­¹ö¿¡¼­ÀÇ ¾ÆÀÌÅÛ ÀÎµ¦½º(¸¸µé¾î Áú¶§ ÀÎµ¦½º ¸Å°ÜÁü, Áßº¹°¡´É)
      Index        : word;          //Ç¥ÁØ¾ÆÀÌÅÛÀÇ ÀÎµ¦½º  0:¾øÀ½, 1ºÎÅÍ ½ÃÀÛÇÔ..
      Dura         : word;
      DuraMax      : word;          //º¯°æµÈ ³»±¸¼º ÃÖ´ë°ª
      Desc         : array[0..13] of byte;
           //0..7 ¾ÆÀÌÅÛ ¾÷±×·¹ÀÌµå »óÅÂ
           //10 0:¾÷±×·¹ÀÌµå¿Í »ó°ü ¾øÀ½
           //   1:ÆÄ±«·Â ¾÷±×·¹ÀÌµå ¾ÆÀÌ´íÆ¼ÆÄÀÌ ¾È µÇ¾úÀ½
           //   2:¸¶·Â (ÀÚ¿¬°è) ¾÷±×·¹ÀÌµå ¾ÆÀÌ´íÆ¼ÆÄÀÌ ¾È µÇ¾úÀ½
           //   3:µµ·Â ¾÷±×·¹ÀÌµå ¾ÆÀÌ´íÆ¼ÆÄÀÌ ¾È µÇ¾úÀ½ - Mir2
           //   3:¸¶·Â (¿µÈ¥°è) ¾÷±×·¹ÀÌµå ¾ÆÀÌµ§Æ¼ÆÄÀÌ ¾È µÇ¾úÀ½ - Mir3
           //   5:°ø°İ¼Óµµ ¾÷±×·¹ÀÌµå ¾ÆÀÌ´íÆ¼ÆÄÀÌ ¾È µÇ¾úÀ½
           //   9:½ÇÆĞ, Æ÷°³Áü
           //11 MAC_TYPE : gadget
           //12 MC_TYPE : gadget
      ColorR       : byte;
      ColorG       : byte;
      ColorB       : byte;
      Prefix       : array [0..12] of char;
   end;
   PTUserItem = ^TUserItem;

   //ei (gadget)
   TAbility = packed record
      Level       : byte;
//      reserved1   : byte;     // remaek by gadget
      AC          : word;     //armor class

//      MAC         : word;     //magic armor class
      DC          : word;    //damage class  -> makeword(min/max)

//      MC          : word;    //magic power class   -> makeword(min/max)
//      SC          : word;    //sprite energy class    -> makeword(min/max)

      HP          : word;     //health point
      MP          : word;     //magic point

      MaxHP       : word;     //max health point
      MaxMP       : word;     //max magic point

//      ExpCount    : byte;   //»ç¿ë¾ÈÇÔ , »èÁ¦
//      ExpMaxCount : byte;   //»ç¿ë¾ÈÇÔ , »èÁ¦

      Exp         : longword;  //ÇöÀç °æÇèÄ¡
      MaxExp      : longword;  //ÇöÀç ÃÖ´ë °æÇèÄ¡

      Weight      : word;  //ÇöÀç ¹«°Ô
      MaxWeight   : word;  //µé ¼ö ÀÖ´Â ÃÖ´ë ¹«°Ô

      WearWeight    : byte;
      MaxWearWeight : byte;  //°ËÀ» Á¦¿ÜÇÑ Âø¿ë °¡´ÉÇÑ ¾ÆÀÌÅÛÀÇ ¹«°Ô (ÃÊ°úÇÏ¸é ±²ÀåÈ÷ ´À¸®´Ù 2-3¹è´À¸²)
      HandWeight    : byte;
      MaxHandWeight : byte;  //µé ¼ö ÀÖ´Â °ËÀÇ ¹«°Ô (¹«°Ô¸¦ ÃÊ°úÇÏ¸é ±²ÀåÈ÷ ´À¸®°Ô °ø°İÇÑ´Ù 2-3¹è´À¸²)

      //ei Ãß°¡
{      FameLevel      : byte;  //¸í¼º
      MiningLevel    : byte;  //±¤ºÎ ·¹º§
      FramingLevel   : byte;  //°æÀÛ
      FishingLevel   : byte;  //³¬½Ã

      FameExp        : integer;
      FameMaxExp     : integer;
      MiningExp      : integer;
      MiningMaxExp   : integer;
      FramingExp     : integer;
      FramingMaxExp  : integer;
      FishingExp     : integer;
      FishingMaxExp  : integer;                      }

      ATOM_DC        : array [0.._MAX_ATOM_] of word;
      ATOM_MC        : array [0.._MAX_ATOM_] of word;   // 0: Fire
                                                        // 1: Ice
                                                        // 2: Light
                                                        // 3: Wind
                                                        // 4: Holy
                                                        // 5: Dark
                                                        // 6: Phantom
      ATOM_MAC       : array [0.._MAX_ATOM_] of word;
   end;

   //ei
   TAddAbility = record       //¾ÆÀÌÅÛ Âø¿ëÀ¸·Î ´Ã¾î³ª´Â ´É·ÂÄ¡
      HP          : word;
      MP          : word;
      HIT         : word;
      SPEED       : word;
      AC          : word;
//      MAC         : word;
      DC          : word;
//      MC          : word;
//      SC          : word;
      AntiPoison  : word;    //%
      PoisonRecover : word;  //%
      HealthRecover : word;  //%
      SpellRecover : word;   //%
      AntiMagic   : word; //¸¶¹ı È¸ÇÇÀ² %
      Luck        : byte; //Çà¿î Æ÷ÀÎÆ®
      UnLuck      : byte; //ºÒÇà Æ÷ÀÎÆ®
      WeaponStrong : byte;
      UndeadPower : byte;
      HitSpeed    : shortint;
      ATOM_DC        : array [0.._MAX_ATOM_] of word;
      ATOM_MC        : array [0.._MAX_ATOM_] of word;
      ATOM_MAC       : array [0.._MAX_ATOM_] of word;
   end;

{$else}

   //¹Ì¸£2
   TStdItem = record
  	   Name		    : string[14];        // ¾ÆÀÌÅÛ ÀÌ¸§ (ÃµÇÏÁ¦ÀÏ°Ë)
      StdMode      : byte;              //
      Shape 	    : byte;              // ÇüÅÂº° ÀÌ¸§ (Ã¶°Ë)
      Weight       : byte;              // ¹«°Ô
      AniCount     : byte;              // 1º¸´Ù Å©¸é ¾Ö´Ï¸ŞÀÌ¼Ç µÇ´Â ¾ÆÀÌÅÛ (´Ù¸¥ ¿ëµµ·Î ¸¹ÀÌ ¾²ÀÓ)
      SpecialPwr   : shortint;          // +ÀÌ¸é »ı¹°°ø°İ+´É·Â, -ÀÌ¸é ¾ğµ¥µå°ø°İ+
                                        //1~10 °­µµ
                                        //-50~-1 ¾ğµ¥µå ´É·ÂÄ¡ Çâ»ó
                                        //-100~-51 ¾ğµ¥µå ´É·ÂÄ¡ °¨¼Ò
      ItemDesc     : byte;              //$01 IDC_UNIDENTIFIED  (¾ÆÀÌ´íÆ¼ÆÄÀÌ ¾È µÈ °Í, Å¬¶óÀÌ¾ğÆ®¿¡¼­¸¸ »ç¿ëµÊ)
                                        //$02 IDC_UNABLETAKEOFF (¼Õ¿¡¼­ ¶³¾îÁöÁö ¾ÊÀ½, ¹ÌÁö¼ö »ç¿ë °¡´É)
                                        //$04 IDC_NEVERTAKEOFF  (¼Õ¿¡¼­ ¶³¾îÁöÁö ¾ÊÀ½, ¹ÌÁö¼ö »ç¿ë ºÒ°¡´É)
                                        //$08 IDC_DIEANDBREAK   (Âø¿ë¾ÆÀÌÅÛ¿¡¼­ Á×À¸¸é ±úÁö´Â ¼Ó¼º)
                                        //$10 IDC_NEVERLOSE     (Âø¿ë¾ÆÀÌÅÛ¿¡¼­ Á×¾îµµ ¶³¾îÁöÁö ¾ÊÀ½)
      Looks        : word;              // ±×¸² ¹øÈ£
      DuraMax      : word;
      AC           : word;              // ¹æ¾î·Â
      MAC          : word;              // ¸¶Ç×·Â
      DC           : word;              // µ¥¹ÌÁö
      MC           : word;              // ¼ú»çÀÇ ¸¶¹ı ÆÄ¿ö
      SC           : word;              // µµ»çÀÇ Á¤½Å·Â
      Need         : byte;              // 0:Level, 1:DC, 2:MC, 3:SC
      NeedLevel    : byte;              // 1..60 level value...
      Price        : integer;           // °¡°İ
      Stock        : integer;           // º¸À¯·®
      AtkSpd       : byte;              // °ø°İ¼Óµµ
      Agility      : byte;              // ¹ÎÃ¸
      Accurate     : byte;              // Á¤È®
      MgAvoid      : byte;              // ¸¶¹ıÈ¸ÇÇ -> ¸¶¹ıÀúÇ×(sonmg)
      Strong       : byte;              // °­µµ
      Undead       : byte;              // »çÀÚ
      HpAdd        : integer;           // Ãß°¡HP
      MpAdd        : integer;           // Ãß°¡MP
      ExpAdd       : integer;           // Ãß°¡ °æÇèÄ¡
      EffType1     : byte;              // È¿°úÁ¾·ù1
      EffRate1     : byte;              // È¿°úÈ®·ü1
      EffValue1    : byte;              // È¿°ú°ª1
      EffType2     : byte;              // È¿°úÁ¾·ù2
      EffRate2     : byte;              // È¿°úÈ®·ü2
      EffValue2    : byte;              // È¿°ú°ª2
      {--------------------}
      // added by sonmg
      Slowdown     : byte;              // µĞÈ­
      Tox          : byte;              // Áßµ¶
      ToxAvoid     : byte;              // Áßµ¶ÀúÇ×
      UniqueItem   : byte;              // À¯´ÏÅ©¼Ó¼º
                                        // À¯´ÏÅ© --- $01:Á¦·Ã/¾÷±×·¹ÀÌµå ¾ÈµÊ
                                        // À¯´ÏÅ© --- $02:¼ö¸®ºÒ°¡
                                        // À¯´ÏÅ© --- $04:¹ö¸®¸é»ç¶óÁü(°¡¹æÃ¢¿¡¼­ ¶³±¸Áö ¾ÊÀ½)
                                        // À¯´ÏÅ© --- $08:±³È¯ ¹× »óÁ¡°Å·¡ºÒ°¡(12=4+8 : °Å·¡ºÒ°¡,¶³±ÀºÒ°¡)
      OverlapItem  : byte;              // Áßº¹Çã¿ë
      light        : byte;              // ºûÀ»³»´Â ¾ÆÀÌÅÛ
      {--------------------}
      ItemType     : byte;              // ¾ÆÀÌÅÛÀÇ ±¸ºĞ
      ItemSet      : Word;              // ¼ÂÆ® ¾ÆÀÌÅÛ ±¸ºĞ
      Reference    : string[14];        // ÂüÁ¶ ¹®ÀÚ¿­
   end;

   PTStdItem = ^TStdItem;

   //¹Ì¸£2
   TUserItem = packed record
      MakeIndex  : integer;      //¼­¹ö¿¡¼­ÀÇ ¾ÆÀÌÅÛ ÀÎµ¦½º(¸¸µé¾î Áú¶§ ÀÎµ¦½º ¸Å°ÜÁü, Áßº¹°¡´É)
      Index        : word;          //Ç¥ÁØ¾ÆÀÌÅÛÀÇ ÀÎµ¦½º  0:¾øÀ½, 1ºÎÅÍ ½ÃÀÛÇÔ..
      Dura         : word;
      DuraMax      : word;          //º¯°æµÈ ³»±¸¼º ÃÖ´ë°ª
      Desc         : array[0..13] of byte;
           //0..7 ¾ÆÀÌÅÛ ¾÷±×·¹ÀÌµå »óÅÂ
           //10 0:¾÷±×·¹ÀÌµå¿Í »ó°ü ¾øÀ½
           //   1:ÆÄ±«·Â ¾÷±×·¹ÀÌµå ¾ÆÀÌ´íÆ¼ÆÄÀÌ ¾È µÇ¾úÀ½
           //   2:¸¶·Â ¾÷±×·¹ÀÌµå ¾ÆÀÌ´íÆ¼ÆÄÀÌ ¾È µÇ¾úÀ½
           //   3:µµ·Â ¾÷±×·¹ÀÌµå ¾ÆÀÌ´íÆ¼ÆÄÀÌ ¾È µÇ¾úÀ½
           //   5:°ø°İ¼Óµµ ¾÷±×·¹ÀÌµå ¾ÆÀÌ´íÆ¼ÆÄÀÌ ¾È µÇ¾úÀ½
           //   9:½ÇÆĞ, Æ÷°³Áü
      ColorR        : byte;
      ColorG        : byte;
      ColorB        : byte;
      Prefix        : array [0..12] of char;
   end;
   PTUserItem = ^TUserItem;

   //¹Ì¸£2
   TAbility = record
      Level       : byte;
      reserved1   : byte;
      AC          : word;     //armor class
      MAC         : word;     //magic armor class
      DC          : word;    //damage class  -> makeword(min/max)
      MC          : word;    //magic power class   -> makeword(min/max)
      SC          : word;    //sprite energy class    -> makeword(min/max)
      HP          : word;     //health point
      MP          : word;     //magic point
      MaxHP       : word;     //max health point
      MaxMP       : word;     //max magic point
      ExpCount    : byte;   //»ç¿ë¾ÈÇÔ
      ExpMaxCount : byte;   //»ç¿ë¾ÈÇÔ
      Exp         : longword;  //ÇöÀç °æÇèÄ¡
      MaxExp      : longword;  //ÇöÀç ÃÖ´ë °æÇèÄ¡
      Weight      : word;  //ÇöÀç ¹«°Ô
      MaxWeight   : word;  //µé ¼ö ÀÖ´Â ÃÖ´ë ¹«°Ô
      WearWeight    : byte;
      MaxWearWeight : byte;  //°ËÀ» Á¦¿ÜÇÑ Âø¿ë °¡´ÉÇÑ ¾ÆÀÌÅÛÀÇ ¹«°Ô (ÃÊ°úÇÏ¸é ±²ÀåÈ÷ ´À¸®´Ù 2-3¹è´À¸²)
      HandWeight    : byte;
      MaxHandWeight : byte;  //µé ¼ö ÀÖ´Â °ËÀÇ ¹«°Ô (¹«°Ô¸¦ ÃÊ°úÇÏ¸é ±²ÀåÈ÷ ´À¸®°Ô °ø°İÇÑ´Ù 2-3¹è´À¸²)

      FameCur     : integer; //ÇöÀç ¸í¼ºÄ¡(2004/10/22)
      FameBase    : integer; //´©Àû ¸í¼ºÄ¡(2004/10/22)
   end;

  TNewAbility = packed record
    bLevel: Byte;    // µÈ¼¶OK
    LoAC: Word;      //·ÀÓùÉÏÏŞ ok
    HiAC: Word;      //·ÀÓùÏÂÏŞ ok
    LoMAC: Word;     // Ä§·¨·ÀÓùÉÏÏŞok
    HiMAC: Word;     // Ä§·¨·ÀÓùÏÂÏŞok
    LoDC: Word;      // ¹¥»÷Á¦ÉÏÏŞ OK
    HiDC: Word;      // ¹¥»÷Á¦ÏÂÏŞ OK
    LoMC: Word;      // ×ÔÈ»Á¦ ÉÏÏŞOK
    HiMC: Word;      // ×ÔÈ»Á¦ ÏÂÏŞOK
    LoSC: Word;      // Áé»êÏµ ÉÏÏŞ ok
    HiSC: Word;      // Áé»êÏµ ÏÂÏŞ ok
    wHP: Word;       // µ±Ç°ÉúÃüÖµ  Ok
    wMP: Word;       // µ±Ç°·¨Á¦Öµ  ok
    wMaxHP: Word;    // ×î´óÉúÃüÖµ OK
    wMaxMP: Word;    // ×î´ó·¨Á¦Öµ OK
    dlngExp: Int64;    // ¾­Ñé OK
    dlngMaxExp: Int64;   // ×î´ó¾­Ñé OK
    wWeight: Word;     // µ±Ç°±³°ü¸ºÖØ OK
    wMaxWeight: Word;    // ×î´ó±³°ü¸ºÖØ   OK
    bWearWeight: Word;  // ¸ºÖØ OK
    bMaxWearWeight: word;  // ×î´ó¸ºÖØOK
    bHandWeight: Word;    // ÊÖ¸ºÖØ   OK
    bMaxHandWeight: Word;  // ×î´óÊÖ¸ºÖØ OK
    Atm_Dc: array [0..6] of Word;  // 7  * 2
    Atm_Good : array[0..6] of Char; // 7
    Atm_Bad  : array[0..6] of Char; // 7
  end;
   //¹Ì¸£2
   TAddAbility = record       //¾ÆÀÌÅÛ Âø¿ëÀ¸·Î ´Ã¾î³ª´Â ´É·ÂÄ¡
      HP          : word;
      MP          : word;
      HIT         : word;   // Á¤È®
      SPEED       : word;   // ¹ÎÃ¸
      AC          : word;
      MAC         : word;
      DC          : word;
      MC          : word;
      SC          : word;
      AntiPoison  : word;    //%  // Áßµ¶ÀúÇ×
      PoisonRecover : word;  //%
      HealthRecover : word;  //%
      SpellRecover : word;   //%
      AntiMagic   : word; //¸¶¹ı È¸ÇÇÀ² % // => ¸¶¹ıÀúÇ×
      Luck        : byte; //Çà¿î Æ÷ÀÎÆ®
      UnLuck      : byte; //ºÒÇà Æ÷ÀÎÆ®
      WeaponStrong : byte;
      UndeadPower : byte;
      HitSpeed    : shortint;
      // added by sonmg
      Slowdown    : byte;
      Poison      : byte;
   end;

{$endif} //¹Ì¸£2


   TPricesInfo = record            //°¡°İ Á¤º¸
      Index       : word;  //Ç¥ÁØ ¾ÆÀÌÅÛÀÇ ÀÎµ¦½º
      SellPrice   : integer;    //±âº» °¡°İ, BuyPrice´Â SellPriceÀÇ Àı¹İ
   end;
   PTPricesInfo = ^TPricesInfo;

   TClientGoods = record
      Name        : string[14];
      SubMenu     : byte;
      Price       : integer;
      Stock       : integer;  //°³º°¾ÆÀÌÅÛÀÎ°æ¿ì, ItemÀÇ ServerIndex ÀÓ
      //Dura        : word;
      //DuraMax     : word;
      Grade       : ShortInt;     //»óÅÂ
   end;
   PTClientGoods = ^TClientGoods;

   TClientJangwon = record //Àå¿ø ¸®½ºÆ®
      Num           : integer;
      GuildName     : string[20];
      CaptaineName1 : string[14];
      CaptaineName2 : string[14];
      SellPrice     : integer;
      SellState     : string[10];
   end;
   PTClientJangwon = ^TClientJangwon;

   TClientGABoard = record //Àå¿ø °Ô½ÃÆÇ ¸®½ºÆ®
      WrigteUser   : string[14];
      TitleMsg     : string[40];
      IndexType1   : integer;
      IndexType2   : integer;
      IndexType3   : integer;
      IndexType4   : integer;
      ReplyCount   : integer;
   end;
   PTClientGABoard = ^TClientGABoard;

   TClientGADecoration = record //Àå¿ø ²Ù¹Ì±â
      Num       : integer;
      Name      : string[25];
      Price     : integer;
      ImgIndex  : integer;
      CaseNum   : integer;
//      Hint      : string[40];
   end;
   PTClientGADecoration = ^TClientGADecoration;


   TClientItem = record      //Å¬¶óÀÌ¾ğÆ®¿¡¼­ ÇÊ¿äÇÑ Æ÷¸ä
      S            : TStdItem;  //º¯°æµÈ ´É·ÂÄ¡´Â ¿©±â¿¡ Àû¿ëµÊ.
      MakeIndex    : integer;
      Dura         : word;
      DuraMax      : word;
      UpgradeOpt   : integer;    //¾÷±×·¹ÀÌµå µÈ °³¼ö
   end;
   PTClientItem = ^TClientItem;

   TUserStateInfo = record
      Feature     : integer;
      UserName    : string[14];
      NameColor   : integer;
      GuildName   : string[20];//[14]; //¼öÁ¤(2004/12/22)
      GuildRankName : string[14];
      UseItems : array[0..12] of TClientItem;    // 8->12
      bExistLover : Boolean;     //¿¬ÀÎ »óÅÂ(2004/10/27)
      LoverName   : string[14];  //¿¬ÀÎ ÀÌ¸§(2004/11/03)
      FameName    : string[20];  //¸í¼º È£Äª(2004/10/27)
   end;
   PTUserStateInfo = ^TUserStateInfo;

   TDropItem = record  //Å¬¶óÀÌ¾ğÆ®¿¡¼­ »ç¿ë
      Id          : integer;
      X           : word;
      Y           : word;
      Looks       : word;
      FlashTime   : longword; //¸¶Áö¸·À¸·Î ¹İÂ¦°Å¸° ½Ã°£
      BoFlash     : Boolean;
      FlashStepTime : longword;
      FlashStep   : integer;
      Name        : string[25];
      BoDeco      : Boolean;
   end;
   PTDropItem = ^TDropItem;

   TDefMagic = record
      MagicId: word;
      MagicName: string[14];       //Ä­ ´Ã¸±°Í 12->14(Å¬¶óÀÌ¾ğÆ®¿Í ÇÔ²² »ç¿ë)
      EffectType: byte;
      Effect: byte;
      Spell: word;
      MinPower: word;
      NeedLevel: array[0..3] of byte;
      MaxTrain: array[0..3] of integer;
      MaxTrainLevel: byte;  //¼ö·Ã ·¹º§
      Job: byte;         //0: Àü»ç 1:¼ú»ç  2:µµ»ç   99:¸ğµÎ°¡´É
      DelayTime: integer; //ÇÑ¹æ ½ğ´ÙÀ½¿¡ ´ÙÀ½ ¸¶¹ıÀ» ¾µ ¼ö ÀÖ´Âµ¥ °É¸®´Â ½Ã°£
      DefSpell: byte;
      DefMinPower: byte;
      MaxPower: word;
      DefMaxPower: byte;
      Desc: string[15];
   end;
   PTDefMagic = ^TDefMagic;

   TUserMagic = record
      pDef        : PTDefMagic;  //¹İµå½Ã nilÀÌ ¾Æ´Ï¾î¾ß ÇÑ´Ù.
      MagicId     : word;     //Magic Index ÀúÀå. À¯´ÏÅ©ÇØ¾ßÇÏ¸ç, º¯µ¿µÇ¸é ¾ÈµÊ, Ç×»ó 0º¸´Ù Å©´Ù.
      Level       : byte;
      Key         : char;     //»ç¿ëÀÚ°¡ ÁöÁ¤ÇÑ Å°
      CurTrain    : integer;  //ÇöÀç ¼ö·ÃÄ¡
   end;
   PTUserMagic = ^TUserMagic;

   TClientMagic = record
      Key: char;
      Level: byte;
      CurTrain: integer;
      Def: TDefMagic;
   end;
   PTClientMagic = ^TClientMagic;

   //¼¼ÄÜÊ÷Í¼±ê¶¨Î»
   TMagicIconPos = record
     nMagicID: integer;
     nPosX: integer;
     nPosY: integer;
   end;
   PTMagicIconPos = ^TMagicIconPos;

   // 2003/04/15 Ä£±¸, ÂÊÁö
   TFriend = record
      CharID: String;
      Status: Byte;
      Memo  : String;
   end;
   PTFriend = ^TFriend;
   TMail = record
      Sender: String;
      Date  : String;
      Mail  : String;
      Status: Byte;
   end;
   PTMail = ^TMail;

   TRelationship = record
      CharID: String;
      Level : Byte;
      Sex   : Byte;
      Status: Byte;
      Date  : String;
   end;
   PTRelationship = ^TRelationship;

   TSkillInfo = record
      SkillIndex  : word;
      Reserved    : word;
      CurTrain    : integer;
   end;
   PTSkillInfo = ^TSkillInfo;

   TMapItem = record
      UserItem: TUserItem;
      Name: string[25];
      Looks: word;
      AniCount: byte;
      Reserved: byte;
      Count: integer;
      Ownership: TObject; //¹°°ÇÀ» ÁıÀ» ¼ö ÀÖ´Â »ç¶÷
      Droptime: longword; //¹°°ÇÀ» Èê¸° ½Ã°£
      Droper: TObject;  //¹°°ÇÀ» ¶³¾î¶ß¸° ÀÚ (»ç¶÷? ¸ó½ºÅÍ?)
   end;
   PTMapItem = ^TMapItem;

   //Àå¿ø²Ù¹Ì±â ¾ÆÀÌÅÛ(sonmg)
   TAgitDecoItem = record
      Name: string[25];
      Looks: word;
      MapName:  string[14];
      x: word;
      y: word;
      Maker: string[14];
      Dura: word;
   end;
   PTAgitDecoItem = ^TAgitDecoItem;

   {map¿ë ¾ÆÀÌÅÛ}
   TVisibleItemInfo = record
      check: byte;
      x: word;
      y: word;
      Id: longint;
      Name: string[25];
      looks: word;
   end;
   PTVisibleItemInfo = ^TVisibleItemInfo;

   TVisibleActor = record
      check: byte;
      cret: TObject;
   end;
   PTVisibleActor = ^TVisibleActor;

   {¸Ê ¿¡¼­ ÀÏ¾î³ª´Â ÀÌº¥Æ®, activate½ÃÄÑ¾ß¸¸ ÀÌº¥Æ®°¡ ¹ß»ıÇÑ´Ù.}
   TMapEventInfo = record
      check: byte;
      X: integer;
      Y: integer;
      EventObject: TObject;  {TMapEvent}
   end;
   PTMapEventInfo = ^TMapEventInfo;

   TGateInfo = record
      GateType: byte;
      EnterEnvir: TObject;  //TEnvirnoment;
      EnterX: integer;
      EnterY: integer;
   end;
   PTGateInfo = ^TGateInfo;

   //¸Ê¿¡ °ü·ÃµÈ ·¹ÄÚµå
   TAThing = record
      Shape  	: byte;
      AObject : TObject;
      ATime   : longword;
   end;
   PTAThing = ^TAThing;

   TMapInfo = record
      MoveAttr	: byte;    //0: can move  1: can't move  2: can't move and cant't fly
      Door     : Boolean; //¹®ÀÌÀÖÀ½, OBJListÁß¿¡ ¹® ÀÖÀ½
      Area     : byte;    //Áö¿ª ±¸ºĞ (¸¶À»,¼ö·ÃÀå,µîµî)
      Reserved : byte;    //¹Ì»ç¿ë
      OBJList	: TList;   // list of TAThing
   end;
   PTMapInfo = ^TMapInfo;


   TUserEntryInfo = record              // »ç¿ëÀÚ µî·ÏÁ¤º¸, logonÀü¿¡ ¾²ÀÓ
      LoginId  : string[10];
      Password : string[10];
      UserName : string[20];     //*
      SSNo     : string[14];     //* 721109-1476110
      Phone    : string[14];     //ÁıÀüÈ­ ¹øÈ£
      Quiz     : string[20];     //*
      Answer   : string[12];     //*
      EMail    : string[40];  //25];
   end;
   TUserEntryAddInfo = record
      //temp     : array[0..14] of byte;
      Quiz2    : string[20];     //*
      Answer2  : string[12];     //*
      Birthday : string[10];     //* 1972/11/09
      MobilePhone: string[13];   //017-6227-1234
      Memo1: string[20];    //*
      Memo2: string[20];    //*
   end;

   TUserCharacterInfo = record          // °¡»ó¼¼°è¿¡ µé¾î¿À±â Àü¿¡ »ç¿ëÀÚ¿¡°Ô Àü´ŞµÇ´Â
      EncName	: string[20];              // ÄÉ·¢ÅÍ Á¤º¸
      Sex		: byte;
      Hair      : byte;
      Job       : byte;                 //0:Àü»ç 1: ¼ú»ç 2:µµ»ç
      Level	    : byte;
      Feature	: integer;
      EncEncName: string[30];              // ÄÉ·¢ÅÍ Á¤º¸
   end;
   PTUserCharacterInfo = ^TUserCharacterInfo;

   TLoadHuman = packed record
      UsrId: array [0..20] of char;
      ChrName: array [0..19] of char; // 13 -> 19
      UsrAddr: array [0..14] of char;
      CertifyCode: integer;
   end;
   PTLoadHuman = ^TLoadHuman;

   TMonsterInfo = record
      Name: string[14];
      Race: byte;   //¼­¹öÀÇ AI ÇÁ·Î±×·¥
      RaceImg: byte;  //Å¬¶óÀÌ¾ğÆ® ÇÁ·¡ÀÓ ½Äº°
      Appr: word;   //ÀÌ¹ÌÁö ¹øÈ£
      Level: byte;
      LifeAttrib: byte;
      CoolEye: byte;  //´«ÀÇ ÁÁÀ½, 100% ÀÌ¸é Àº½ÅÀ» º½, 50%ÀÌ¸é Àº½ÅÀ» º¼ È®·üÀÌ 50%
      Exp: word;
      HP: word;
      MP: word;
      AC: byte;
      MAC: byte;
      DC: byte;
      MaxDC: byte;
      MC: byte;
      SC: byte;
      Speed: Byte;
      Hit: Byte;
      WalkSpeed: word;
      WalkStep: word;
      WalkWait: word;
      AttackSpeed: word;
      //////////////////////////
      // newly added by sonmg.
      Tame: word;
      AntiPush: word;
      AntiUndead: word;
      SizeRate: word;
      AntiStop: word;
      //////////////////////////
      ItemList: TList;
   end;
   PTMonsterInfo = ^TMonsterInfo;

   TZenInfo = record
      MapName:  string[14];
      X: integer;
      Y: integer;
      MonName: string[14];
      MonRace: integer; //
      Area: integer;  //¹üÀ§ +area, -area rectangle
      Count: integer;
      MonZenTime: longword; //¹Ğ¸®¼¼ÄÁµå ´ÜÀ§
      StartTime: longword;
      Mons: TList;
      SmallZenRate: integer;
      // 2003/06/20 ÀÌº¥Æ®¿ë ¸÷ Ã³¸®
      TX : integer;
      TY : integer;
      ZenShoutType : integer;
      ZenShoutMsg  : integer;
   end;
   PTZenInfo = ^TZenInfo;

   TMonItemInfo = record
      SelPoint: integer;
      MaxPoint: integer;
      ItemName: string[14];
      Count: integer;  //°¹¼ö,
   end;
   PTMonItemInfo = ^TMonItemInfo;

   TMarketProduct = record
      GoodsName: string[14];
      Count: integer;
      ZenHour: integer; //hour
      ZenTime: longword; //ÃÖ±Ù¿¡ Á¨½ÃÅ² ½Ã°£
   end;
   PTMarketProduct = ^TMarketProduct;

   //QuestDiary¿ë
   TQDDinfo = record
      Index: integer;
      Title: string;
      SList: TStringList;
   end;
   PTQDDinfo = ^TQDDinfo;

   // À§Å¹ÆÇ¸Å¿ë ¾ÆÀÌÅÛ --------------------------------------------------------
   TMarketItem = record
      Item   	: TClientItem;	// º¯°æµÈ ´É·ÂÄ¡´Â ¿©±â¿¡ Àû¿ëµÊ.
      UpgCount  : integer;      // Ãß°¡·Î ¾÷±×·¹ÀÌµå µÈ °³¼ö
      Index	    : integer;	    // ÆÇ¸Å¹øÈ£
      SellPrice	: integer;	    // ÆÇ¸Å °¡°İ
      SellWho	: string[20];	// ÆÇ¸ÅÀÚ
      Selldate	: string[10]; 	// ÆÇ¸Å³¯Â¥(0312311210 = 2003-12-31 12:10 )
      SellState : word          // 1 = ÆÇ¸ÅÁß , 2 = ÆÇ¸Å¿Ï·á
   end;
   PTMarketItem = ^TMarketItem;

   // À§Å¹ÆÇ¸Å ÀĞ±â¿ë ----------------------------------------------------------
   TMarketLoad = record
      UserItem  : TUserItem;    // DB ÀúÀå¿ë
      Index     : Integer;      // DB ÀÎµ¦½º
      MarketType: integer;      // ºĞ¸®µÈ ¾ÆÀÌÅÛ Á¾·ù
      SetType   : integer;      // ¼ÂÆ® ¾ÆÀÌÅÛ Á¾·ù
      SellCount : integer;
      SellPrice : integer;      // ÆÇ¸Å °¡°İ
      ItemName  : string[30];   // ¾ÆÀÌÅÛÀÌ¸§
      MarketName: string[30];   // ÆÇ¸ÅÀÚ¸í
      SellWho	: string[20];	// ÆÇ¸ÅÀÚ
      Selldate	: string[10]; 	// ÆÇ¸Å³¯Â¥(0312311210 = 2003-12-31 12:10 )
      SellState : word;         // 1 = ÆÇ¸ÅÁß , 2 = ÆÇ¸Å¿Ï·á
      IsOK      : integer;      // °á°ú°ª
   end;
   PTMarketLoad   = ^TMarketLoad;

    //¾ÆÀÌÅÛ °Ë»ö¿ë ------------------------------------------------------------
    TSearchSellItem = record
        MarketName  : string[25];   // ¼­¹öÀÌ¸§_NPC  ÀÌ¸§ÀÌ »ç¿ëµÊ
        Who         : string[25];   // ¾ÆÀÌÅÛ ÆÇ¸ÅÀÚ °Ë»ö½Ã »ç¿ë ,
        ItemName    : string[25];   // ¾ÆÀÌÅÛ ÀÌ¸§ °Ë»ö½Ã »ç¿ë
        MakeIndex   : integer;      // ¾ÆÀÌÅÛÀÇ À¯´ÏÅ© ¹øÈ£  
        ItemType    : integer;      // ¾ÆÀÌÅ× Á¾·ù °Ë»ö½Ã »ç¿ë
        ItemSet     : integer;      // ¾ÆÀÌÅÛ ¼ÂÆ® Á¶È¸½Ã »ç¿ë
        SellIndex   : integer;      // ÆÇ¸Å ÀÎµ¦½º ¾ÆÀÌÅÛ »ì¶§ , Ãë¼Ò , ±İ¾×È¸¼öµî¿¡ »ç¿ë
        CheckType   : integer;      // DB ÀÇ Ã¼Å©Å¸ÀÔ
        IsOK        : integer;      // °á°ú°ª
        UserMode    : integer;      // 1= ¾ÆÀÌÅÛ »ç±â  , 2= ÀÚ½ÅÀÇ ¾ÆÀÌÅÛ °Ë»ö
        pList       : TList;        // À§Å¹¾ÆÀÌÅÛÀÇ ¸®½ºÆ®
    end;
    PTSearchSellItem = ^TSearchSellItem;

    //À§Å¹°Ë»ç¿ë....------------------------------------------------------------
    TMarKetReqInfo  = Record
        UserName    :   string[30];
        MarketName  :   string[30];
        SearchWho   :   string[30];
        SearchItem  :   string[30];
        ItemType    :   integer;
        ItemSet     :   integer;
        UserMode    :   integer;
    end;

    //Àå¿ø°Ô½ÃÆÇ ¸®½ºÆ® °Ë»ö¿ë....------------------------------------------------------------
    TSearchGaBoardList  = Record
        AgitNum     :   integer;      // ¹Ì»ç¿ë
        GuildName   :   string[30];
        OrgNum      :   integer;      // ¹Ì»ç¿ë
        SrcNum1     :   integer;      // ¹Ì»ç¿ë
        SrcNum2     :   integer;      // ¹Ì»ç¿ë
        SrcNum3     :   integer;      // ¹Ì»ç¿ë
        Kind        :   integer;
        UserName    :   string[20];   // ¹Ì»ç¿ë
        ArticleList :   TList;        // °Ô½ÃÆÇ ¸®½ºÆ®
    end;
    PTSearchGaBoardList = ^TSearchGaBoardList;

{
    //Àå¿ø°Ô½ÃÆÇ Á¦¸ñ ¸®½ºÆ®¿ë....------------------------------------------------------------
    TGaBoardListLoad  = Record
        AgitNum     :   integer;
        GuildName   :   string[30];
        OrgNum      :   integer;
        SrcNum      :   integer;
        Kind        :   integer;
        UserName    :   string[20];
        Subject     :   array [0..40] of char;
    end;
    PTGaBoardListLoad = ^TGaBoardListLoad;
}

    //Àå¿ø°Ô½ÃÆÇ ±Û³»¿ë....------------------------------------------------------------
    TGaBoardArticleLoad  = Record
        AgitNum     :   integer;
        GuildName   :   string[30];
        OrgNum      :   integer;
        SrcNum1     :   integer;
        SrcNum2     :   integer;
        SrcNum3     :   integer;
        Kind        :   integer;
        UserName    :   string[20];
        Content     :   array [0..500] of char;
    end;
    PTGaBoardArticleLoad = ^TGaBoardArticleLoad;

const
  _BLEND_NORMAL		   = 0;			// ÀÏ¹İÀûÀÎ±×¸®±â.(¾ËÆÄ°ªÀÌ Àû¿ëµÉ¼öÀÖ´Ù.)
  _BLEND_LIGHT		   = 1;			// ¼¶±¤È¿°úÇüÅÂÀÇ ºí·»µù.
  _BLEND_LIGHTINV		 = 2;
  _BLEND_INVNORMAL	 = 3;
  _BLEND_INVLIGHT		 = 4;
  _BLEND_INVLIGHTINV = 5;

  _GENDER_MAN   = 0;
  _GENDER_WOMAN = 1;

  _JOB_GUNGSA   = 3;
  _JOB_DOSA     = 2;
  _JOB_SULSA    = 1;
  _JOB_JUNSA    = 0;

  _CHR_PROC_IMG_SELECT          = 50;
  _CHR_PROC_IMG_CREATE          = 80;
  _CHR_PROC_IMG_CREATE_STONE    = 81;
  _CHR_PROC_IMG_CREATE_STONE_S  = 82;

  _MAX_CHAR      = 4;
  _MAX_SHOW_CHAR = 2;
  _MAX_SPR_KIND  = 40;

  _CHR_MAX_MT = 5;

  _CHR_MT_NS = 0;
  _CHR_MT_SM = 1;
  _CHR_MT_SS = 2;
  _CHR_MT_R  = 3;
  _CHR_MT_CC = 4;

  _CHR_PROC_SELECT    = 0;
  _CHR_PROC_CREATEIN  = 1;
  _CHR_PROC_CREATE    = 2;
  _CHR_PROC_CREATEOUT = 3;
  _CHR_PROC_START     = 4;

  _SELECTED_FST_CHR   = 0;
  _SELECTED_SND_CHR   = 1;
  _SELECTED_TRD_CHR   = 2;
  _SELECTED_4TH_CHR   = 3;
  _SELECTED_NONE      = -1;

  _CHR_EXPLAIN_WIDTH  = 430;

//******************************************************************************************************************
//	#1. Map Handler
//******************************************************************************************************************
  _BASETILE_WIDTH  = 96;
  _BASETILE_HEIGHT = 64;

  _CELL_WIDTH  = 48;
  _CELL_HEIGHT = 32;

//  _VIEW_CELL_X_COUNT = 24
//  _VIEW_CELL_Y_COUNT = 26
//  _VIEW_CELL_Y_COUNT_FOR_OBJ = 44
//
//  _MEMVIEW_CELL_X_COUNT = 36
//  _MEMVIEW_CELL_Y_COUNT = 36
//
//  _VIEW_CELL_X_START = -200
//  _VIEW_CELL_Y_START = -157
//
//  _VIEW_CELL_X_START_INVEN = -196
//  _VIEW_CELL_Y_START_INVEN = -157
//
//  _VIEW_CELL_X_START_STATUS = -186
//  _VIEW_CELL_Y_START_STATUS = -157
//
//  _MAX_TILE_FILE = 14

//******************************************************************************************************************
//	#1. Magic Window
//******************************************************************************************************************
  _MAX_TYPE_MAGIC = 8;
  _MAX_MAGICSLOT = 15;//29;
  _MAX_MAGIC_BTN = 3;

  _BTN_ID_CLOSE = 0;
  _BTN_ID_PREV = 1;
  _BTN_ID_NEXT = 2;

  _MAGIC_MAX_CELL = 29;
  _MAGIC_MAX_KEY = 12;
//******************************************************************************************************************
//	#1. Inventory Window
//******************************************************************************************************************
  _INVEN_MAX_CELL = 36;
  _INVEN_CELL_XCNT = 6;
  _INVEN_CELL_YCNT = 6;
  _INVEN_TOTAL_CELL = 600;
  _INVEN_MAX_CELL_YCNT = 100;
  _INVEN_CELL_XSTART = 25;
  _INVEN_CELL_YSTART = 41;

  _NEW_INVEN_CELL_YCNT = 8;

  _NEW_INVEN_CELL_XSTART = 17;
  _NEW_INVEN_CELL_YSTART = 71;

  _MAX_INVEN_BTN = 4;
  _MAX_INVEN_ITEM = 46;

  _MAX_INVENEX_ITEM = 50;

  _BTN_ID_INVENCLOSE = 0;
  _BTN_ID_FUN1 = 1;
  _BTN_ID_FUN2 = 2;
  _BTN_ID_MINIMAPBOOK = 3;

  _MAX_TYPE = 3;

  _INVEN_TYPE_BAG = 0;
  _INVEN_TYPE_REPAIR = 1;
  _INVEN_TYPE_SELL = 2;
  _INVEN_TYPE_STORAGE = 3;

  _PRICE_NONE = 0;
  _PRICE_RECEIVING = 1;
  _PRICE_RECEIVED = 2;


//******************************************************************************************************************
//  #1. Item Define
//******************************************************************************************************************

  _INVENTORY_CELL_WIDTH = 38;
  _INVENTORY_CELL_HEIGHT = 38;

  _NEW_INVENTORY_CELL_WIDTH = 38;
  _NEW_INVENTORY_CELL_HEIGHT = 38;

//******************************************************************************************************************
//	#1. Magic
//******************************************************************************************************************
  _MAGIC_ACTIVE = 0;	// ¸¶¹ıÈ°¼º»óÅÂ.
  _LIGHT_ACTIVE = 1;	// ¸¶¹ı±¤¿øÈ°¼º»óÅÂ.
  _MAGIC_FINISH = 2;	// ¸¶¹ı¼Ò¸ê.

  _SKILL_FIREBALL = 1;	// È­¿°Àå.(È­)
  _SKILL_HEALLING = 2;	// È¸º¹¼ú.
  _SKILL_ONESWORD = 3;	// ¿Ü¼ö.(¹«)
  _SKILL_ILKWANG = 4;	// ÀÏ±¤.
  _SKILL_FIREBALL2 = 5;	// ±İ°­È­¿°Àå.
  _SKILL_AMYOUNSUL = 6;	// ¾Ï¿¬¼ú.
  _SKILL_YEDO = 	7;	// ¿¹µµ.
  _SKILL_FIREWIND = 8;	// È­¿°Ç³.
  _SKILL_FIRE = 	9;	// ¿°»çÀå.
  _SKILL_SHOOTLIGHTEN = 10;	// ·ÚÀÎÀå.
  _SKILL_LIGHTENING = 11;	// °­°İ.
  _SKILL_ERGUM = 12;	// ¾î°Ë¼ú.
  _SKILL_FIRECHARM = 13;	// Æø»ì°è.
  _SKILL_HANGMAJINBUB = 14;	// Ç×¸¶Áø¹ı.
  _SKILL_DEJIWONHO = 15;	// ´ëÁö¿øÈ£.
  _SKILL_HOLYSHIELD = 16;	// °á°è.
  _SKILL_SKELLETON = 17;	// ¹é°ñ¼ÒÈ¯¼ú.
  _SKILL_CLOAK = 18;	// Àº½Å.
  _SKILL_BIGCLOAK = 19;	// ´ëÀº½Å.
  _SKILL_TAMMING = 20;	// ·ÚÈ¥°İ.
  _SKILL_SPACEMOVE = 21;	// ¾Æ°øÇà¹ı.
  _SKILL_EARTHFIRE = 22;	// Áö¿°¼ú.
  _SKILL_FIREBOOM = 23;	// Æø¿­ÆÄ.
  _SKILL_LIGHTFLOWER = 24;	// ·Ú¼³È­.
  _SKILL_BANWOL = 25;	// ¹İ¿ù.
  _SKILL_FIRESWORD = 26;	// ¿°È­°á.
  _SKILL_MOOTEBO = 27;	// ¹«ÅÂº¸.
  _SKILL_SHOWHP = 28;	// Å½±âÆÄ¿¬.
  _SKILL_BIGHEALLING = 29;	// ´ëÈ¸º¹.
  _SKILL_SINSU = 30;	// ½Å¼ö¼ÒÈ¯.
  _SKILL_SHIELD = 31;	// ÁÖ¼úÀÇ¸·.
  _SKILL_KILLUNDEAD = 32;	// »çÀÚÀ±È¸.
  _SKILL_SNOWWIND = 33;	// ºù¼³Ç³.

  _SKILL_RANDSWING = 34;	// ¿¬¿ùÂü.
  _SKILL_JUMPSHOT = 35;	// ¸Í·æ½ÂÃµ¼¼.
  _SKILL_KICK = 	36;	// ¹«»ó°¢.

  _SKILL_MOONOK = 37;	// ¿ù¿µ¿Á.
  _SKILL_MOONCHAM = 38;	// ¿ù¿µÆÄ.
  _SKILL_ICEBOLT = 39;	// ºù¿ùÀå.
  _SKILL_SUPERICEBOLT = 40;	// ºù¿ùÁøÃµÀå.
  _SKILL_MAGICARROW = 41;	// ºñ°İÀå.
  _SKILL_FIREBOOMUP = 47;	// Æø¿­ÆÄ¾÷.(Áö·ÚÇüÆø¿­ÆÄ???????).
  _SKILL_EARTH_SUMMON = 48;	// ´ëÁö¼ÒÈ¯¼ú.(¿î¼®¼ÒÈ¯???????).
  _SKILL_ICE = 	53;	// ºù»çÀå.
  _SKILL_LIGHTWALL = 63;	// ·Úº®.(ºñ°İº®???????).
  _SKILL_LIGHTFLOWERUP = 64;	// ·Ú¼³È­¾÷.(¿ø°Å¸®·Ú¼³È­???????).
  _SKILL_MAGICTRAP = 66;	// ºñ°İÆ®·¦.
  _SKILL_HANDWIND = 67;	// ÀåÇ³.
  _SKILL_HURRICANE = 72;	// ¿ë¼±Ç³.
  _SKILL_HURRICANESHOT = 73;	// Ç³ÁøÂü
  _SKILL_HURRICANEBOMB = 74;	// °İÇ³
  _SKILL_REVIVE = 77;	// ¼Ò»ı¼ú.
  _SKILL_TRANSFORM = 78;	// µĞ°©¼ú.
  _SKILL_ANTIMAGIC_FIRE = 85;	// Ç×¸¶Áø¹ı(È­).
  _SKILL_ANTIMAGIC_ICE = 86;	// Ç×¸¶Áø¹ı(ºù).
  _SKILL_ANTIMAGIC_LIGHTENING = 87;	// Ç×¸¶Áø¹ı(·Ú).
  _SKILL_ANTIMAGIC_WIND = 88;	// Ç×¸¶Áø¹ı(Ç³).
  _SKILL_MAGICUP = 89;	// °­¸¶Áø¹ı.
  _SKILL_MAGICUP_FIRE = 90;	// °­¸¶Áø¹ı(È­).
  _SKILL_MAGICUP_ICE = 91;	// °­¸¶Áø¹ı(ºù).
  _SKILL_MAGICUP_LIGHTENING = 92;	// °­¸¶Áø¹ı(·Ú).
  _SKILL_MAGICUP_WIND = 93;	// °­¸¶Áø¹ı(Ç³).
  _SKILL_POWERUP = 94;	// ¸ÍÈ£°­¼¼.
  _SKILL_WITH_FIRE = 95;	// ¸ÍÈ£°­¼¼(È­).
  _SKILL_WITH_ICE = 96;	// ¸ÍÈ£°­¼¼(ºù).
  _SKILL_WITH_LIGHT = 97;	// ¸ÍÈ£°­¼¼(·Ú).
  _SKILL_WITH_WIND = 98;	// ¸ÍÈ£°­¼¼(Ç³).
  _SKILL_WITH_DEF = 99;	// ¸ÍÈ£°­¼¼(¹æ¾î).
  _SKILL_WITH_MAGIC = 100;	// ¸ÍÈ£°­¼¼(¸¶¹ı).
  _SKILL_WITH_ATT = 101;	// ¸ÍÈ£°­¼¼(°ø°İ).
  _SKILL_MAXDEFENCE = 102;	// Ã¶Æ÷»ï
  _SKILL_MANWOL = 103;	// È¸¼±Âü
  _SKILL_SMALLSPACEMOVE = 104;	// ÀÌÇüÈ¯À§.
  _SKILL_POWERSKELLETON = 105;	// Áø°ñ¼ÒÈ¯¼ú.
  _SKILL_MAXOFENCE = 106;	// ±¤¸¶°á
  _SKILL_CHANGEPOSITION = 107;	// ÀüÀ§º¸
  _SKILL_PULL = 	108;	// °İ°ø¼·¹°
  _SKILL_THUNDERSTORM = 111;	// ·ÚÈ­³­¹«
  _SKILL_MAXDEFEECEMAGIC = 112;	// ¿ªÇ÷¸¶°ø
  _SKILL_FIREBALL10 = 113;	// ¸¸ÃµÈ­¿ì
  _SKILL_REMOVEPOISON = 120;	// Á¤È­¼ú
  _SKILL_FULLCLOAK = 121;	// ±âÈ¯¼ú
  _SKILL_DOSASHIELD = 122;	// ¼±Ãµ±â°ø
  _SKILL_MONSTERUP = 123;	// ÀüÀÌ¼ú
  _SKILL_CROSS_ICE = 110;	// ºù·ÄÆÄ

  _SKILL_PAWHANGBO = 109;	// ÆÄÈ²º¸
  _SKILL_KANGMAK = 114;	// È¸Ç³°­¸·
  _SKILL_MYULSAL = 124;	// ¸ê»ì°è
  _SKILL_TAWOO = 125;	// °İ»êÅ¸¿ì
  _SKILL_BANTAN = 126;	// ¹İÅº°­±â
  _SKILL_COPY = 	127;	// Çã»óºĞ½Å
  _SKILL_FREEMOVE = 128;	// ±İ°­ºÎµ¿
  _SKILL_HEALX = 129;	// ¾ç»ı¼ú
  _SKILL_BIGMOUNTAIN = 130;	// ÅÂ»ê¾ĞÁ¤
  _SKILL_HYPERSWORD = 131;	// Äèµµ³­¸¶
  _SKILL_POTIONUP = 132;	// ¿î±â¿ä»ó
  _SKILL_1000THUNDER = 133;	// Ãµ·Ú
  _SKILL_CLOUDTHUNDER = 134;	// ¿îÁß³ú°İ
  _SKILL_BIGAM = 135;	// ´ë¾Ï¿¬¼ú
  _SKILL_INHALEHP = 136;	// Èí¼º´ë¹ı
  _SKILL_DOLL = 	137;	// ºĞ¿­È¥

  _SKILL_BALSACHE = 138;	// ¹ß»çÃ¼
  _SKILL_JIKSUNGYE = 139;	// Á÷¼±°è
  _SKILL_JUMPSHOT_HIGH = 143;	// °í±Ş¸Í·æ½ÂÃµ¼¼
  _SKILL_PAWHANGBO_HIGH = 144;	// °í±ŞÆÄÈ²º¸
  _SKILL_SHIELD_HIGH = 145;	// °í±ŞÁÖ¼úÀÇ¸·
  _SKILL_MAXDEFEECEMAGIC_HIGH = 146;	// °í±Ş¿ªÇ÷¸¶°ø
  _SKILL_DEJIWONHO_HIGH = 147;	// °í±Ş´ëÁö¿øÈ£
  _SKILL_CLOAK_HIGH = 148;	// °í±ŞÀº½Å¼ú
  _SKILL_MOONCHAM_HIGH = 149;	// °í±Ş¿ù¿µÆÄ
  _SKILL_POKBAL = 150;	// Æø¹ßÇü
  _SKILL_JISOKGYE = 151;	// Áö¼Ó°è
  _SKILL_RANDSWING_HIGH = 152;	// °í±Ş¿¬¿ùÂü
  
   DEFBLOCKSIZE  = 22;//16;

{$ifdef MIR2EI}

   MAXBAGITEM = 46;
   MAXHORSEBAG = 30;
   MAXUSERMAGIC = 20;
   MAXSAVEITEM = 100;

   MAXQUESTINDEXBYTE = 24; //ei¿ë
   MAXQUESTBYTE = 176; //ei¿ë

{$else}  //±âÁ¸ ¹Ì¸£2

   MAXBAGITEM = 46;
   MAXHORSEBAG = 30;
   MAXUSERMAGIC = 25;//20;   //(sonmg 2004/10/27)
   MAXSAVEITEM = 100;

   MAXQUESTINDEXBYTE = 24;       // To PDS:13;  //100;
   MAXQUESTBYTE = 176;           // TO PDS:100; //13;

{$endif}

   //Å¬¶óÀÌ¾ğÆ®¿¡¼­ ¾²ÀÓ
   LOGICALMAPUNIT    = 40;
   UNITX             = 48;
   UNITY             = 32;
   HALFX             = 24;
   HALFY             = 16;

   OS_MOVINGOBJECT  = 1;
   OS_ITEMOBJECT     = 2;
   OS_EVENTOBJECT    = 3;
   OS_GATEOBJECT     = 4;
   OS_SWITCHOBJECT   = 5;
   OS_MAPEVENT       = 6;
   OS_DOOR           = 7;
   OS_ROON           = 8;

   // StatusArr Size ÁöÁ¤(sonmg 2004/03/19)
   STATUSARR_SIZE    = 16;
   EXTRAABIL_SIZE    = 7;
   // 2003/07/15 »óÅÂÀÌ»ó Ãß°¡
   POISON_DECHEALTH     = 0;   //$80000000
   POISON_DAMAGEARMOR   = 1;   //$40000000
   POISON_ICE           = 2;   //$20000000
   POISON_STUN          = 3;   //$10000000
   POISON_SLOW          = 4;   //$08000000
   POISON_STONE         = 5;   //$04000000
   POISON_DONTMOVE      = 6;   //$02000000

   STATE_BLUECHAR       = 2;
   STATE_FASTMOVE       = 7;   //$01000000
   STATE_TRANSPARENT    = 8;   //$00800000
   STATE_DEFENCEUP      = 9;   //$00400000
   STATE_MAGDEFENCEUP   = 10;  //$00200000
   STATE_BUBBLEDEFENCEUP = 11; //$00100000

   // 2004/03/19 Ä³¸¯ÅÍ È¿°ú Ãß°¡(sonmg)
   STATE_50LEVELEFFECT  = 12;  //$00080000
   STATE_TEMPORARY1     = 13;  //$00040000  //ÀÓ½Ã1(»©»©·ÎÀÌÆåÆ®)
   STATE_TEMPORARY2     = 14;  //$00020000  //ÀÓ½Ã2(È£¹Ú¸Ó¸®)
   STATE_TEMPORARY3     = 15;  //$00010000  //ÀÓ½Ã3(ÇÏÆ®»©»©·Î)

   EABIL_DCUP       = 0;   //¼ø°£ÀûÀ¸·Î ÆÄ±«·ÂÀ» ¿Ã¸² (ÀÏÁ¤ ½Ã°£)
   EABIL_MCUP       = 1;
   EABIL_SCUP       = 2;
   EABIL_HITSPEEDUP = 3;
   EABIL_HPUP       = 4;
   EABIL_MPUP       = 5;
   EABIL_PWRRATE    = 6;   // °ø°İ·Â ·¹ÀÌÆ® Á¶Á¤ 

   //ItemDesc ÀÇ ¼Ó¼º
   IDC_UNIDENTIFIED     = $01;   //´É·Â È®ÀÎ ¾ÈµÊ
   IDC_UNABLETAKEOFF    = $02;   //¼Õ¿¡¼­ ¶³¾îÁöÁö ¾ÊÀ½, ¹ÌÁö¼ö »ç¿ëÀ¸·Î ¶³¾îÁü
   IDC_NEVERTAKEOFF     = $04;   //¼Õ¿¡¼­ Àı´ë·Î ¶³¾îÁöÁö ¾ÊÀ½
   IDC_DIEANDBREAK      = $08;   //Á×À¸¸é ±úÁü
   IDC_NEVERLOSE        = $10;   //Á×¾îµµ ÀÒ¾î¹ö¸®Áö ¾ÊÀ½


   STATE_STONE_MODE     = $00000001;  //¼®»ó¸ó½ºÅÍÀÇ ¸ğ½À(¼®»óÀ¸·Î ÀÖÀ½)
   STATE_OPENHEATH      = $00000002;  //Ã¼·Â °ø°³»óÅÂ


   HAM_ALL              = 0;  //¸ğµÎ °ø°İ
   HAM_PEACE            = 1;  //ÆòÈ­¸ğµå, ¸ó½ºÅÍ¸¸ °ø°İ
   HAM_GROUP            = 2;  //±×·ì¿ø ÀÌ¿Ü ¾Æ¹«³ª °ø°İ
   HAM_GUILD            = 3; //±æµå¿ø ÀÌ¿Ü ¾Æ¹«³ª °ø°İ
   HAM_PKATTACK         = 4; //»¡°»ÀÌ ´ë ÈòµÕÀÌ
   HAM_GUILDWAR         = 5; //Àû´ë¹®ÆÄ¸¸ °ø°İ

   HAM_MAXCOUNT         = 6;


   AREA_FIGHT        = $01;
   AREA_SAFE         = $02;
   AREA_FREEPK       = $04;


   HM_HIT            = 0;
   HM_HEAVYHIT       = 1;
   HM_BIGHIT         = 2;
   HM_POWERHIT       = 3;
   HM_LONGHIT        = 4;
   HM_WIDEHIT        = 5;
   // 2003/03/15 ½Å±Ô¹«°ø
   HM_CROSSHIT       = 6;  //4 °÷ ¸ÂÀ½ -> 8°÷ ¸ÂÀ½
   HM_FIREHIT        = 7;
   HM_TWINHIT        = 8;  //2¹ø °ø°İ
   HM_STONEHIT       = 9;  //4 °÷ ¸ÂÀ½ -> 8°÷ ¸ÂÀ½

   {----------------------------}

   //SM_??    ¼­¹ö -> Å¬¶óÀÌ¾ğÆ®·Î
   //  1 ~ 2000
   SM_TEST                 = 1;
   //Èå¸§Á¦¾î ¸í·É
   SM_STOPACTIONS          = 2;  //¸ğµç Ä³¸¯ÅÍ/¸¶¹ıÀÇ µ¿ÀÛÀ» ¸ØÃá´Ù.
                                 //´Ù¸¥ ¸Ê¿¡ µé¾î°£ °æ¿ì,

   //Çàµ¿¿¡ °ü·Ã ¸í·É
   SM_ACTION_MIN           = 5;
   SM_THROW                = 5;
   SM_RUSH                 = 6;  //¾ÕÀ¸·Î ÀüÁø
   SM_RUSHKUNG             = 7;  //¾ÕÀ¸·Î ÀüÁø½ÇÆĞ
   SM_FIREHIT              = 8;  //¿°È­°á
   SM_BACKSTEP             = 9;  //µŞ°ÉÀ½Áú,
   SM_TURN                 = 10;
   SM_WALK                 = 11;
   SM_SITDOWN              = 12;
   SM_RUN                  = 13;
   SM_HIT                  = 14;
   SM_HEAVYHIT             = 15;
   SM_BIGHIT               = 16;
   SM_SPELL                = 17;
   SM_POWERHIT             = 18;
   SM_LONGHIT              = 19;  //´õ ¼¼°Ô ¶§¸²
   SM_DIGUP                = 20;  //¶¥ÆÄ°í ³ª¿À´Ù.
   SM_DIGDOWN              = 21;  //¶¥ÆÄ°í µé¾î°¡ ¼û´Ù.
   SM_FLYAXE               = 22;
   SM_LIGHTING             = 23;  //¸¶¹ı »ç¿ë
   SM_WIDEHIT              = 24;
   SM_ACTION_MAX           = 25;

   // 2003/03/15 ½Å±Ô¹«°ø
   SM_CROSSHIT             = 35;  //±¤Ç³Âü, ÁÖº¯8Å¸ÀÏ °ø°İ
   SM_TWINHIT              = 36;  //½Ö·æÂü, ºü¸£°Ô 2¹ø °ø°İ
   SM_STONEHIT             = 37;  //»çÀÚÈÄ, ÁÖº¯8Å¸ÀÏ µ¹·Î¸¸µë
   SM_WINDCUT              = 38;  //°øÆÄ¼¶,  ¾ÕÅ¸ÀÏ 9°³ °ø°İ
   SM_DRAGONFIRE           = 39; // Ãµ·æ±â¿°(È­·æ±â¿°)  ÀÚ½ÅÁÖº¯ Å¸ÀÏ 25°³ °ø°İ
   SM_CURSE                = 40; // ÀúÁÖ¼ú
   // 2004/06/22 ½Å±Ô¹«°ø(Æ÷½Â°Ë, ÈíÇ÷¼ú, ¸Í¾È¼ú)
   SM_PULLMON              = 41;  //Æ÷½Â°Ë, ²ø¾î´ç±è
   SM_SUCKBLOOD            = 42;  //ÈíÇ÷¼ú, ÇÇ¸¦ »¡¾ÆµéÀÓ
   SM_BLINDMON             = 43;  //¸Í¾È¼ú, ÀûÀÇ ½Ã¾ß¸¦ °¡¸²

   // FireDragon ------------------------ by Leekg...2003/11/27
   MAGIC_DUN_THUNDER       = 70; //¿ë´øÁ¯ ¹ø°³  // FireDragon
   MAGIC_DUN_FIRE1         = 71; //¿ë´øÁ¯ ¿ë¾Ï µ¢¾î¸®
   MAGIC_DUN_FIRE2         = 72; //¿ë´øÁ¯ ¿ë¾Ï ÀÓÆåÆ®
   MAGIC_DRAGONFIRE        = 73; //¿ëºÒ°ø°İ ÅÍÁü
   MAGIC_FIREBURN          = 74; //¿ë¼®»ó°ø°İ ÅÍÁü Å¸¿À¸§

   MAGIC_SERPENT_1         = 75; //ÀÌ¹«±â ¸êÃµÈ­
   MAGIC_JW_EFFECT1        = 76; //Àå¿ø ÀÓÆåÆ® 1
   MAGIC_FOX_THUNDER       = 78; //¼ú»çºñ¿ù¿©¿ì °­°İ
   MAGIC_FOX_FIRE1         = 79; //¼ú»çºñ¿ù¿©¿ì È­¿°

   SM_DRAGON_LIGHTING      = 80;
   SM_DRAGON_FIRE1         = 81;
   SM_DRAGON_FIRE2         = 82;
   SM_DRAGON_FIRE3         = 83;

   SM_DRAGON_STRUCK        = 85;
   SM_DRAGON_DROPITEM      = 86;
   SM_LIGHTING_1           = 87; //¸¶¹ı_1:ÀÌ¹«±â ¸êÃµÈ­
   SM_LIGHTING_2           = 88;
   SM_LIGHTING_3           = 89; //Çö¹«Çö½Å

   MAGIC_FOX_FIRE2         = 90; //µµ»çºñ¿ù¿©¿ì Æø»ì°è
   MAGIC_FOX_CURSE         = 91; //µµ»çºñ¿ù¿©¿ì ÀúÁÖ¼ú
   MAGIC_SOULBALL_ATT1     = 93; //ºñ¿ùÃµÁÖ Àü±â °ø°İ(±ÙÁ¢¹üÀ§)
   MAGIC_SOULBALL_ATT2     = 94; //ºñ¿ùÃµÁÖ Àü±â °ø°İ(¿ø°Å¸®)
   MAGIC_SOULBALL_ATT3_1   = 95; //ºñ¿ùÃµÁÖ Àü±â °ø°İ(ÇÊ»ç±â) 5°¡Áö ÀÓÆåÆ®
   MAGIC_SOULBALL_ATT3_2   = 96;
   MAGIC_SOULBALL_ATT3_3   = 97;
   MAGIC_SOULBALL_ATT3_4   = 98;
   MAGIC_SOULBALL_ATT3_5   = 99;
   MAGIC_SIDESTONE_ATT1    = 100; //È£È¥±â¼® Àü±â °ø°İ
   MAGIC_TURTLE_WARTERATT  = 101; //°©Ã¶±Í¼ö ¹°°ø°İ

   MAGIC_KINGTURTLE_ATT1   = 102; //Çö¹«Çö½Å-Èú¸µ
   MAGIC_KINGTURTLE_ATT2_1 = 103; //Çö¹«Çö½Å-ÀüÃ¼¹°°ø°İ1
   MAGIC_KINGTURTLE_ATT2_2 = 104; //Çö¹«Çö½Å-ÀüÃ¼¹°°ø°İ2
   MAGIC_KINGTURTLE_ATT3   = 105; //Çö¹«Çö½Å-¸ó½ºÅÍ¼ÒÈ¯

   SM_ACTION2_MIN          = 1000;
   //SM_READYFIREHIT         = 1000;  //Å¬¶óÀÌ¾ğÆ®¿¡¼­¸¸ ¾²ÀÓ, ¿°È­°á ÁØºñ

   SM_ACTION2_MAX          = 1099;

   SM_DIE                  = 26; //»ç¶ó Áü
   SM_ALIVE                = 27;
   SM_MOVEFAIL             = 28;
   SM_HIDE                 = 29;
   SM_DISAPPEAR            = 30;
   SM_STRUCK               = 31;
   SM_DEATH                = 32;
   SM_SKELETON             = 33;
   SM_NOWDEATH             = 34;

   SM_HEAR                 = 40;
   SM_FEATURECHANGED       = 41;
   SM_USERNAME             = 42;
   SM_WINEXP               = 44;
   SM_LEVELUP              = 45;
   SM_DAYCHANGING          = 46;
   SM_POWERUP              = 47;  //Ìú²¼ÉÀ

   SM_LOGON                = 50;
   SM_NEWMAP               = 51;
   SM_ABILITY              = 52;
   SM_HEALTHSPELLCHANGED   = 53;
   SM_MAPDESCRIPTION       = 54;

   SM_CHANGEFAMEPOINT      = 55; //¸í¼ºÄ¡ º¯È­(2004/11/04)

   SM_SYSMESSAGE           = 100;
   SM_GROUPMESSAGE         = 101;
   SM_CRY                  = 102;
   SM_WHISPER              = 103;
   SM_GUILDMESSAGE         = 104;
   SM_SYSMSG_REMARK        = 105;

   //ITEM ?
   SM_ADDITEM              = 200;  //¾ÆÀÌÅÛÀ» »õ·Î ¾òÀ½  Series(¼ö·®)
   SM_BAGITEMS             = 201;  //°¡¹æÀÇ ¸ğµç ¾ÆÀÌÅÛ
   SM_DELITEM              = 202;  //´â¾Æ¼­ ¾ø¾îÁö´Â µîÀÇ ÀÌÀ¯·Î ¾ø¾îÁü
   SM_UPDATEITEM           = 203;  //¾ÆÀÌÅÛÀÇ »ç¾çÀÌ º¯ÇÔ
   //Magic
   SM_ADDMAGIC             = 210;
   SM_SENDMYMAGIC          = 211;  //
   SM_DELMAGIC             = 212;

   SM_VERSION_AVAILABLE    = 500;
   SM_VERSION_FAIL         = 501;
   SM_PASSWD_SUCCESS       = 502;
   SM_PASSWD_FAIL          = 503;
   SM_NEWID_SUCCESS        = 504;  //»õ¾ÆÀÌµğ Àß ¸¸µé¾î Á³À½
   SM_NEWID_FAIL           = 505;  //»õ¾ÆÀÌµğ ¸¸µé±â ½ÇÆĞ
   SM_CHGPASSWD_SUCCESS    = 506;
   SM_CHGPASSWD_FAIL       = 507;
   SM_QUERYCHR             = 520;  //Ä³¸¯¸®½ºÆ®
   SM_NEWCHR_SUCCESS       = 521;
   SM_NEWCHR_FAIL          = 522;
   SM_DELCHR_SUCCESS       = 523;
   SM_DELCHR_FAIL          = 524;
   SM_STARTPLAY            = 525;
   SM_STARTFAIL            = 526;
   SM_QUERYCHR_FAIL        = 527;
   SM_OUTOFCONNECTION      = 528;  //¿¬°á ÇØÁ¦µÊ
   SM_PASSOK_SELECTSERVER  = 529;
   SM_SELECTSERVER_OK      = 530;
   SM_NEEDUPDATE_ACCOUNT   = 531;  //°èÁ¤ÀÇ Á¤º¸¸¦ ´Ù½Ã ÀÔ·ÂÇÏ±â ¹Ù¶÷ Ã¢..
   SM_UPDATEID_SUCCESS     = 532;
   SM_UPDATEID_FAIL        = 533;
   SM_PASSOK_WRONGSSN      = 534;
   SM_NOT_IN_SERVICE       = 535;
   SM_SEND_PUBLICKEY       = 536;
   SM_FOXSTATE             = 537;   //ºñ¿ùÃµÁÖ »óÅÂ


   SM_DROPITEM_SUCCESS     = 600;  //¾ÆÀÌÅÛ ¹ö¸®±â ¼º°ø
   SM_DROPITEM_FAIL        = 601;  //
   SM_ITEMSHOW             = 610;
   SM_ITEMHIDE             = 611;
   SM_OPENDOOR_OK          = 612;
   SM_OPENDOOR_LOCK        = 613;
   SM_CLOSEDOOR            = 614;
   SM_TAKEON_OK            = 615; //Âø¿ë ¼º°ø, + New Feature
   SM_TAKEON_FAIL          = 616; //Âø¿ë ½ÇÆĞ
   SM_EXCHGTAKEON_OK       = 617; //Âø¿ë¾ÆÀÌÅÛ ±³È¯ ¼º°ø
   SM_EXCHGTAKEON_FAIL     = 618; //Âø¿ë¾ÆÀÌÅÛ ±³È¯ ½ÇÆĞ
   SM_TAKEOFF_OK           = 619; //¹ş±â ¼º°ø, + New Feature
   SM_TAKEOFF_FAIL         = 620; //
   SM_SENDUSEITEMS         = 621; //Âø¿ë ¾ÆÀÌÅÛ ¸ğµÎ º¸³¿
   SM_WEIGHTCHANGED        = 622;
   SM_CLEAROBJECTS         = 633;
   SM_CHANGEMAP            = 634;
   SM_EAT_OK               = 635;
   SM_EAT_FAIL             = 636;
   SM_BUTCH                = 637;
   SM_MAGICFIRE            = 638; //¸¶¹ı ¹ß»çµÊ  CM_SPELL -> SM_SPELL + SM_MAGICFIRE
   SM_MAGICFIRE_FAIL       = 639;
   SM_MAGIC_LVEXP          = 640;
   SM_SOUND                = 641;
   SM_DURACHANGE           = 642;
   SM_MERCHANTSAY          = 643;
   SM_MERCHANTDLGCLOSE     = 644;
   SM_SENDGOODSLIST        = 645;
   SM_SENDUSERSELL         = 646;
   SM_SENDBUYPRICE         = 647;
   SM_USERSELLITEM_OK      = 648;
   SM_USERSELLITEM_FAIL    = 649;
   SM_BUYITEM_SUCCESS      = 650;
   SM_BUYITEM_FAIL         = 651;
   SM_SENDDETAILGOODSLIST  = 652;
   SM_GOLDCHANGED          = 653;
   SM_CHANGELIGHT          = 654;
   SM_LAMPCHANGEDURA       = 655;
   SM_CHANGENAMECOLOR      = 656;
   SM_CHARSTATUSCHANGED    = 657;
   SM_SENDNOTICE           = 658;
   SM_GROUPMODECHANGED     = 659;
   SM_CREATEGROUP_OK       = 660;
   SM_CREATEGROUP_FAIL     = 661;
   SM_GROUPADDMEM_OK       = 662;
   SM_GROUPDELMEM_OK       = 663;
   SM_GROUPADDMEM_FAIL     = 664;
   SM_GROUPDELMEM_FAIL     = 665;
   SM_GROUPCANCEL          = 666;
   SM_GROUPMEMBERS         = 667;
   SM_SENDUSERREPAIR       = 668;
   SM_USERREPAIRITEM_OK    = 669;
   SM_USERREPAIRITEM_FAIL  = 670;
   SM_SENDREPAIRCOST       = 671;
   SM_DEALMENU             = 673;
   SM_DEALTRY_FAIL         = 674;
   SM_DEALADDITEM_OK       = 675;
   SM_DEALADDITEM_FAIL     = 676;
   SM_DEALDELITEM_OK       = 677;
   SM_DEALDELITEM_FAIL     = 678;
   //SM_DEALREMOTEADDITEM_OK = 679;
   //SM_DEALREMOTEDELITEM_OK = 680;
   SM_DEALCANCEL           = 681; //µµÁß¿¡ °Å·¡ Ãë¼ÒµÊ
   SM_DEALREMOTEADDITEM    = 682; //»ó´ë¹æÀÌ ±³È¯ ¾ÆÀÌÅÛÀ» Ãß°¡
   SM_DEALREMOTEDELITEM    = 683; //»ó´ë¹æÀÌ ±³È¯ ¾ÆÀÌÅÛÀ» »­
   SM_DEALCHGGOLD_OK       = 684;
   SM_DEALCHGGOLD_FAIL     = 685;
   SM_DEALREMOTECHGGOLD    = 686;
   SM_DEALSUCCESS          = 687;
   SM_SENDUSERSTORAGEITEM  = 700;
   SM_STORAGE_OK           = 701;
   SM_STORAGE_FULL         = 702; //´õ º¸°ü ¸ø ÇÔ.
   SM_STORAGE_FAIL         = 703; //º¸°ü ¿¡·¯
   SM_SAVEITEMLIST         = 704;
   SM_TAKEBACKSTORAGEITEM_OK = 705;
   SM_TAKEBACKSTORAGEITEM_FAIL = 706;
   SM_TAKEBACKSTORAGEITEM_FULLBAG = 707;
   SM_AREASTATE            = 708; //¾ÈÀü,´ë·Ã,ÀÏ¹İ..
   SM_DELITEMS             = 709;
   SM_READMINIMAP_OK       = 710;
   SM_READMINIMAP_FAIL     = 711;
   SM_SENDUSERMAKEDRUGITEMLIST = 712;
   SM_MAKEDRUG_SUCCESS     = 713;
   SM_MAKEDRUG_FAIL        = 714;
   SM_ALLOWPOWERHIT        = 715;
   SM_NORMALEFFECT         = 716;  //±âº» È¿°ú
   // ¾ÆÀÌÅÛ Á¦Á¶
   SM_SENDUSERMAKEITEMLIST = 717;

   SM_CHANGEGUILDNAME      = 750;  //±æµåÀÇ ÀÌ¸§ È¤ÀÇ ±æµå³»ÀÇ Á÷Ã¥ÀÌ¸§ÀÌ º¯°æ
   SM_SENDUSERSTATE        = 751;  //
   SM_SUBABILITY           = 752;
   SM_OPENGUILDDLG         = 753;
   SM_OPENGUILDDLG_FAIL    = 754;
   SM_SENDGUILDHOME        = 755;
   SM_SENDGUILDMEMBERLIST  = 756;
   SM_GUILDADDMEMBER_OK    = 757;
   SM_GUILDADDMEMBER_FAIL  = 758;
   SM_GUILDDELMEMBER_OK    = 759;
   SM_GUILDDELMEMBER_FAIL  = 760;
   SM_GUILDRANKUPDATE_FAIL = 761;
   SM_BUILDGUILD_OK        = 762;
   SM_BUILDGUILD_FAIL      = 763;
   SM_DONATE_FAIL          = 764;
   SM_DONATE_OK            = 765;
   SM_MYSTATUS             = 766;
   SM_MENU_OK              = 767;  //descriptionÀ¸·Î ¸Ş¼¼Áö Àü´Ş
   SM_GUILDMAKEALLY_OK     = 768;
   SM_GUILDMAKEALLY_FAIL   = 769;
   SM_GUILDBREAKALLY_OK    = 770;
   SM_GUILDBREAKALLY_FAIL  = 771;
   SM_DLGMSG               = 772;

   SM_SPACEMOVE_HIDE       = 800;  //¼ø°£ÀÌµ¿ »ç¶óÁü
   SM_SPACEMOVE_SHOW       = 801;  //³ªÅ¸³²
   SM_RECONNECT            = 802;
   SM_GHOST                = 803;  //È­¸é¿¡ ³ªÅ¸³­ ÀÜ»óÀÓ
   SM_SHOWEVENT            = 804;
   SM_HIDEEVENT            = 805;
   SM_SPACEMOVE_HIDE2      = 806;  //¼ø°£ÀÌµ¿ »ç¶óÁü
   SM_SPACEMOVE_SHOW2      = 807;  //³ªÅ¸³²
   SM_SPACEMOVE_SHOW_NO    = 808;  //³ªÅ¸³²(ÀÌÆåÆ® ¾øÀ½)

   SM_TIMECHECK_MSG        = 810;  //Å¬¶óÀÌ¾ğÆ®¿¡¼­ ½Ã°£
   SM_ADJUST_BONUS         = 811;  //º¸³Ê½º Æ÷ÀÎÆ®¸¦ Á¶Á¤ÇÏ¶ó.
   // Frined System -------------
   SM_FRIEND_DELETE        = 812;   //Ä£±¸ »èÁ¦
   SM_FRIEND_INFO          = 813;   //Ä£±¸ Ãß°¡ ¹× Á¤º¸º¯°æ
   SM_FRIEND_RESULT        = 814;   //Ä£±¸°ü·Ã °á°ú°ª Àü¼Û
   // Tag System ----------------
   SM_TAG_ALARM            = 815;   //ÂÊÁö¿ÔÀ½ ¾Ë¸²
   SM_TAG_LIST             = 816;   //ÂÊÁö¸®½ºÆ®
   SM_TAG_INFO             = 817;   //ÂÊÁöÁ¤º¸ º¯°æ
   SM_TAG_REJECT_LIST      = 818;   //°ÅºÎÀÚ ¸®½ºÆ®
   SM_TAG_REJECT_ADD       = 819;   //°ÅºÎÀÚ Ãß°¡
   SM_TAG_REJECT_DELETE    = 820;   //°ÅºÎÀÚ »èÁ¦
   SM_TAG_RESULT           = 821;   //ÂÊÁö°ü·Ã °á°ú°ª Àü¼Û
   // User System ---------------
   SM_USER_INFO            = 822;   //À¯ÀúÀÇ Á¢¼Ó»óÅÂ¹× ¸ÊÁ¤º¸Àü¼Û
   // RelationShip --------------
   SM_LM_LIST              = 823;   //°ü°è ¸®½ºÆ®
   SM_LM_OPTION            = 824;   //°ü°è ¿É¼Ç
   SM_LM_REQUEST           = 825;   //°ü°è ¼³Á¤ ¿ä±¸
   SM_LM_DELETE            = 826;   //°ü°è »èÁ¦
   SM_LM_RESULT            = 827;   //°ü°è °á°ú°ª Àü¼Û
   // À§Å¹ÆÇ¸Å ---------------------
   SM_MARKET_LIST          = 828;   // À§Å¹¸®½ºÆ®Àü¼Û
   SM_MARKET_RESULT        = 829;   // À§Å¹°á°ú  Àü¼Û

   // ¹®ÆÄÀå¿ø ---------------------
   SM_GUILDAGITLIST        = 830;   //Àå¿ø ÆÇ¸Å ¸ñ·Ï
   SM_GUILDAGITDEALMENU    = 831;   //Àå¿ø°Å·¡

   // Àå¿ø°Ô½ÃÆÇ
   SM_GABOARD_LIST         = 832;  // Àå¿ø°Ô½ÃÆÇ ¸®½ºÆ®
   SM_GABOARD_READ         = 833;  // Àå¿ø°Ô½ÃÆÇ ±ÛÀĞ±â
   SM_GABOARD_NOTICE_OK    = 834;  // Àå¿ø°Ô½ÃÆÇ °øÁö»çÇ× ¾²±â OK
   SM_GABOARD_NOTICE_FAIL  = 835;  // Àå¿ø°Ô½ÃÆÇ °øÁö»çÇ× ¾²±â FAIL

   // Àå¿ø²Ù¹Ì±â
   SM_DECOITEM_LIST        = 836;  // Àå¿ø²Ù¹Ì±â ¾ÆÀÌÅÛ ¸®½ºÆ®
   SM_DECOITEM_LISTSHOW    = 837;  // Àå¿ø²Ù¹Ì±â ¾ÆÀÌÅÛ ¸®½ºÆ®

   // ±×·ì °á¼º È®ÀÎ
   SM_CREATEGROUPREQ       = 838;   //±×·ì °á¼º È®ÀÎ
   SM_ADDGROUPMEMBERREQ    = 839;   //±×·ì °á¼º È®ÀÎ
   // RelationShip (cont.)--------------
   SM_LM_DELETE_REQ        = 840;   //°ü°è »èÁ¦ È®ÀÎ

   //1000 ~ 1099  ¾×¼ÇÀ¸·Î ¿¹¾à

   SM_OPENHEALTH           = 1100;  //Ã¼·ÂÀÌ »ó´ë¹æ¿¡ º¸ÀÓ
   SM_CLOSEHEALTH          = 1101;  //Ã¼·ÂÀÌ »ó´ë¹æ¿¡°Ô º¸ÀÌÁö ¾ÊÀ½
   SM_BREAKWEAPON          = 1102;
   SM_INSTANCEHEALGUAGE    = 1103;
   SM_CHANGEFACE           = 1104;  //º¯½Å...
   SM_NEXTTIME_PASSWORD    = 1105;  //´ÙÀ½¹ø¿¡´Â ºñ¹Ğ¹øÈ£ ÀÔ·Â ¸ğµåÀÌ´Ù.
   SM_CHECK_CLIENTVALID    = 1106;  //Å¬¶óÀÌ¾ğÆ®ÀÇ ¼öÁ¤ ¿©ºÎ È®ÀÎ

   SM_LOOPNORMALEFFECT     = 1107;  //·çÇÁ ÀÓÆåÆ® È¿°ú
   SM_LOOPSCREENEFFECT     = 1108;  //È­¸é ÀÌÆåÆ®

   SM_PLAYDICE             = 1200;
   SM_PLAYROCK             = 1201;
   // 2003/02/11 ±×·ì¿ø À§Ä¡ Á¤º¸
   SM_GROUPPOS             = 1312;

   // UpgradeItem_Result ---------------- by sonmg...2003/10/02
   SM_UPGRADEITEM_RESULT     = 1300;
   // °ãÄ¡±â
   SM_COUNTERITEMCHANGE      = 1301;
   SM_USERSELLCOUNTITEM_OK   = 1302;
   SM_USERSELLCOUNTITEM_FAIL = 1303;

   SM_CANCLOSE_OK            = 1304;
   SM_CANCLOSE_FAIL          = 1305;


   //CM_??   Å¬¶óÀÌ¾ğÆ® -> ¼­¹ö·Î
   //  2000 ~ 4000
   CM_PROTOCOL             = 2000;
   CM_IDPASSWORD           = 2001;
   CM_ADDNEWUSER           = 2002;
   CM_CHANGEPASSWORD       = 2003;
   CM_UPDATEUSER           = 2004;

   {----------------------------}

   CM_QUERYCHR             = 100;
   CM_NEWCHR               = 101;
   CM_DELCHR               = 102;
   CM_SELCHR               = 103;
   CM_SELECTSERVER         = 104;  //¼­¹ö¸¦ ¼±ÅÃ (+ ¼­¹öÀÌ¸§)

   //3000 - 3099 Å¬¶óÀÌ¾ğÆ® ÀÌµ¿ ¸Ş¼¼Áöµµ ¿¹¾à
   //¼­¹ö¿¡¼­ ÀÌµ¿ ¸Ş¼¼Áöµµ 0..99 »çÀÌ ÀÌ¾î¾ß ÇÑ´Ù.
   CM_THROW                = 3005;
   CM_TURN                 = 3010;    //CM_TURN - 3000 = SM_TURN ±ÔÄ¢À» ¹İµå½Ã ÁöÄÑ¾ß ÇÔ
   CM_WALK                 = 3011;
   CM_SITDOWN              = 3012;
   CM_RUN                  = 3013;
   CM_HIT                  = 3014;
   CM_HEAVYHIT             = 3015;
   CM_BIGHIT               = 3016;
   CM_SPELL                = 3017;
   CM_POWERHIT             = 3018;  //´õ ¼¼°Ô ¶§¸²
   CM_LONGHIT              = 3019;  //´õ ¼¼°Ô ¶§¸²
   CM_WIDEHIT              = 3024;
   CM_FIREHIT              = 3025;
   CM_SAY                  = 3030;
   // 2003/03/15 ½Å±Ô¹«°ø
   CM_CROSSHIT             = 3035;
   CM_TWINHIT              = 3036;

   CM_QUERYUSERNAME        = 80;  //QUERY ½Ã¸®Áî ¸í·É¾î
   CM_QUERYBAGITEMS        = 81;
   CM_QUERYUSERSTATE       = 82;  //Å¸ÀÎÀÇ »óÅÂ º¸±â

   CM_DROPITEM             = 1000;
   CM_PICKUP               = 1001;
   CM_OPENDOOR             = 1002;
   CM_TAKEONITEM           = 1003;  //º¹ÀåÀ» Âø¿ë
   CM_TAKEOFFITEM          = 1004;  //º¹ÀåÀ» ¹ş´Â´Ù
   CM_EXCHGTAKEONITEM      = 1005;  //Âø¿ëÇÑ ¾ÆÀÌÅÛÀ» ÁÂ¿ì¸¦ ¹Ù²Û´Ù.(¹İÁö,ÆÈÂî)
   CM_EAT                  = 1006;  //¸Ô´Ù, ¸¶½Ã´Ù
   CM_BUTCH                = 1007;  //µµ·úÇÏ´Ù
   CM_MAGICKEYCHANGE       = 1008;
   CM_SOFTCLOSE            = 1009;
   CM_CLICKNPC             = 1010;
   CM_MERCHANTDLGSELECT    = 1011;
   CM_MERCHANTQUERYSELLPRICE = 1012;
   CM_USERSELLITEM         = 1013;  //¾ÆÀÌÅÛ ÆÈ±â
   CM_USERBUYITEM          = 1014;
   CM_USERGETDETAILITEM    = 1015;
   CM_DROPGOLD             = 1016;
   CM_TEST                 = 1017;  //Å×½ºÆ®
   CM_LOGINNOTICEOK        = 1018;
   CM_GROUPMODE            = 1019;
   CM_CREATEGROUP          = 1020;
   CM_ADDGROUPMEMBER       = 1021;
   CM_DELGROUPMEMBER       = 1022;
   CM_USERREPAIRITEM       = 1023;
   CM_MERCHANTQUERYREPAIRCOST = 1024;
   CM_DEALTRY              = 1025;
   CM_DEALADDITEM          = 1026;
   CM_DEALDELITEM          = 1027;
   CM_DEALCANCEL           = 1028;
   CM_DEALCHGGOLD          = 1029; //±³È¯ÇÏ´Â µ·ÀÌ º¯°æµÊ
   CM_DEALEND              = 1030;
   CM_USERSTORAGEITEM      = 1031;
   CM_USERTAKEBACKSTORAGEITEM = 1032;
   CM_WANTMINIMAP          = 1033;
   CM_USERMAKEDRUGITEM     = 1034;
   CM_OPENGUILDDLG         = 1035;
   CM_GUILDHOME            = 1036;
   CM_GUILDMEMBERLIST      = 1037;
   CM_GUILDADDMEMBER       = 1038;
   CM_GUILDDELMEMBER       = 1039;
   CM_GUILDUPDATENOTICE    = 1040;
   CM_GUILDUPDATERANKINFO  = 1041;
   CM_SPEEDHACKUSER        = 1042;
   CM_ADJUST_BONUS         = 1043;
   CM_GUILDMAKEALLY        = 1044;
   CM_GUILDBREAKALLY       = 1045;
   // Frined System---------------
   CM_FRIEND_ADD           = 1046;  // Ä£±¸Ãß°¡
   CM_FRIEND_DELETE        = 1047;  // Ä£±¸»èÁ¦
   CM_FRIEND_EDIT          = 1048;  // Ä£±¸¼³¸í º¯°æ
   CM_FRIEND_LIST          = 1049;  // Ä£±¸ ¸®½ºÆ® ¿äÃ»
   // Tag System -----------------
   CM_TAG_ADD              = 1050;  // ÂÊÁö Ãß°¡
   CM_TAG_DELETE           = 1051;  // ÂÊÁö »èÁ¦
   CM_TAG_SETINFO          = 1052;  // ÂÊÁö »óÅÂ º¯°æ
   CM_TAG_LIST             = 1053;  // ÂÊÁö ¸®½ºÆ® ¿äÃ»
   CM_TAG_NOTREADCOUNT     = 1054;  // ÀĞÁö¾ÊÀº ÂÊÁö °³¼ö ¿äÃ»
   CM_TAG_REJECT_LIST      = 1055;  // °ÅºÎÀÚ ¸®½ºÆ®
   CM_TAG_REJECT_ADD       = 1056;  // °ÅºÎÀÚ Ãß°¡
   CM_TAG_REJECT_DELETE    = 1057;  // °ÅºÎÀÚ »èÁ¦
   // Relationship ---------------
   CM_LM_OPTION            = 1058;  // °ü°è È°¼º / ºñÈ°¼º
   CM_LM_REQUEST           = 1059;  // °ü°è µî·Ï ¿äÃ»
   CM_LM_Add               = 1060;  // °ü°è Ãß°¡ ( ³»ºÎÀûÀ¸·Î ¾²ÀÓ )
   CM_LM_EDIT              = 1061;  // °ü°è ¼öÁ¤
   CM_LM_DELETE            = 1062;  // °ü°è ÆÄ±â
   // UpgradeItem ---------------- by sonmg...2003/10/02
   CM_UPGRADEITEM          = 1063;  // ¾ÆÀÌÅÛ ¾÷±×·¹ÀÌµå ¿äÃ»
   // Ä«¿îÆ® ¾ÆÀÌÅÛ
   CM_DROPCOUNTITEM        = 1064;  // °ãÄ¡±â ¾ÆÀÌÅÛ ¶³¾î¶ß¸²
   // ¾ÆÀÌÅÛ Á¦Á¶
   CM_USERMAKEITEMSEL      = 1065;
   CM_USERMAKEITEM         = 1066;
   CM_ITEMSUMCOUNT         = 1067;

   // À§Å¹ÆÇ¸Å -------------------
   CM_MARKET_LIST          = 1068;  // À§Å¹ÆÇ¸Å ·¹½ºÆ® ¿äÃ»
   CM_MARKET_SELL          = 1069;  // À§Å¹ÆÇ¸Å À¯Àú -> NPC
   CM_MARKET_BUY           = 1070;  // À§Å¹»ç±â NPC -> À¯Àú
   CM_MARKET_CANCEL        = 1071;  // À§Å¹Ãë¼Ò NPC -> À¯Àú
   CM_MARKET_GETPAY        = 1072;  // À§Å¹±İÈ¸¼ö NPC -> À¯Àú
   CM_MARKET_CLOSE         = 1073;  // À§Å¹»óÁ¡ ÀÌ¿ë ³¡

   // Àå¿ø ÆÇ¸Å ¸ñ·Ï
   CM_GUILDAGITLIST        = 1074;
   CM_GUILDAGIT_TAG_ADD    = 1075;  // Àå¿ø ÂÊÁö º¸³»±â

   // Àå¿ø°Ô½ÃÆÇ
   CM_GABOARD_LIST         = 1076;  // Àå¿ø°Ô½ÃÆÇ ¸®½ºÆ®
   CM_GABOARD_ADD          = 1077;  // Àå¿ø°Ô½ÃÆÇ ±Û¾²±â
   CM_GABOARD_READ         = 1078;  // Àå¿ø°Ô½ÃÆÇ ±ÛÀĞ±â
   CM_GABOARD_EDIT         = 1079;  // Àå¿ø°Ô½ÃÆÇ ±Û¼öÁ¤
   CM_GABOARD_DEL          = 1080;  // Àå¿ø°Ô½ÃÆÇ ±Û»èÁ¦
   CM_GABOARD_NOTICE_CHECK = 1081;  // Àå¿ø°Ô½ÃÆÇ °øÁö»çÇ× ¾²±â Ã¼Å©

   CM_TAG_ADD_DOUBLE       = 1082;  // µÎ¸í µ¿½Ã ÂÊÁö Ãß°¡

   // Àå¿ø²Ù¹Ì±â -------------------
   CM_DECOITEM_BUY         = 1083;  // Àå¿ø²Ù¹Ì±â ¾ÆÀÌÅÛ ±¸ÀÔ

   //±×·ì °á¼º È®ÀÎ
   CM_CREATEGROUPREQ_OK    = 1084;  //±×·ì °á¼º È®ÀÎ
   CM_CREATEGROUPREQ_FAIL  = 1085;  //±×·ì °á¼º È®ÀÎ

   CM_ADDGROUPMEMBERREQ_OK   = 1086;  //±×·ì °á¼º È®ÀÎ
   CM_ADDGROUPMEMBERREQ_FAIL = 1087;  //±×·ì °á¼º È®ÀÎ

   // Relationship (cont.)---------------
   CM_LM_DELETE_REQ_OK     = 1088;  // °ü°è ÆÄ±â OK
   CM_LM_DELETE_REQ_FAIL   = 1089;  // °ü°è ÆÄ±â FAIL

   CM_CLIENT_CHECKTIME     = 1100;
   CM_CANCLOSE             = 1101;

   {----------------------------}

   RM_TURN                 = 10001;
   RM_WALK                 = 10002;
   RM_RUN                  = 10003;
   RM_HIT                  = 10004;
   RM_HEAVYHIT             = 10005;
   RM_BIGHIT               = 10006;
   RM_SPELL                = 10007;
   RM_POWERHIT             = 10008;
   RM_SITDOWN              = 10009;
   RM_MOVEFAIL             = 10010;
   RM_LONGHIT              = 10011;
   RM_WIDEHIT              = 10012;
   RM_PUSH                 = 10013;
   RM_FIREHIT              = 10014;
   RM_RUSH                 = 10015;
   RM_RUSHKUNG             = 10016;
   // 2003/03/15 ½Å±Ô¹«°ø
   RM_CROSSHIT             = 10017;
   RM_TWINHIT              = 10019;
   RM_DECREFOBJCOUNT       = 10018;

   RM_STRUCK               = 10020;
   RM_DEATH                = 10021;
   RM_DISAPPEAR            = 10022;
//   RM_HIDE                 = 10023;
   RM_SKELETON             = 10024;
   RM_MAGSTRUCK            = 10025;  //Ã¼·ÂÀÌ ÀÌ ½ÃÁ¡¿¡¼­ ´â´Â´Ù.
   RM_MAGHEALING           = 10026;  //Èú¸µ
   RM_STRUCK_MAG           = 10027;  //¸¶¹ıÀ¸·Î ¸ÂÀ½
   RM_MAGSTRUCK_MINE       = 10028;  //Áö·Ú“PÀ½
   RM_STONEHIT             = 10029;

   RM_HEAR                 = 10030;
   RM_WHISPER              = 10031;
   RM_CRY                  = 10032;
   RM_TAG_ADD              = 10033;

   RM_WINDCUT              = 10040; // °øÆÄ¼¶
   RM_DRAGONFIRE           = 10041; // Ãµ·æ±â¿°(->È­·æ±â¿°)
   RM_CURSE                = 10042; // ÀúÁÖ¼ú

   RM_LOGON                = 10050;
   RM_ABILITY              = 10051;
   RM_HEALTHSPELLCHANGED   = 10052;
   RM_DAYCHANGING          = 10053;

   RM_USERNAME             = 10043;
   RM_WINEXP               = 10044;
   RM_LEVELUP              = 10045;
   RM_CHANGENAMECOLOR      = 10046;

   //2004/06/22 ½Å±Ô¹«°ø(Æ÷½Â°Ë, ÈíÇ÷¼ú, ¸Í¾È¼ú)
   RM_PULLMON              = 10047;  //Æ÷½Â°Ë, ²ø¾î´ç±è
   RM_SUCKBLOOD            = 10048;  //ÈíÇ÷¼ú, ÇÇ¸¦ »¡¾ÆµéÀÓ
   RM_BLINDMON             = 10049;  //¸Í¾È¼ú, ÀûÀÇ ½Ã¾ß¸¦ °¡¸²

   RM_CHANGEFAMEPOINT      = 10054;    //¸í¼ºÄ¡ º¯È­(2004/11/04)
   RM_GMWHISPER            = 10055;    //¿î¿µÀÚ ¸ğµåÀÏ ¶§ ±Ó¸»(2004/11/18)
   RM_LM_WHISPER           = 10056;    //¿¬ÀÎ ±Ó¼Ó¸»

   RM_FOXSTATE             = 10057;    //ºñ¿ùÃµÁÖ »óÅÂ

   RM_POWERUP              = 10058;  //Ìú²¼ÉÀ

   RM_SYSMESSAGE           = 10100;
   RM_REFMESSAGE           = 10101;
   RM_GROUPMESSAGE         = 10102;
   RM_SYSMESSAGE2          = 10103;
   RM_GUILDMESSAGE         = 10104;
   RM_SYSMSG_BLUE          = 10105;
   RM_SYSMESSAGE3          = 10106;
   RM_SYSMSG_REMARK        = 10107;
   RM_SYSMSG_PINK          = 10108;
   RM_SYSMSG_GREEN         = 10109;

   RM_ITEMSHOW             = 10110;
   RM_ITEMHIDE             = 10111;
   RM_OPENDOOR_OK          = 10112;
   RM_CLOSEDOOR            = 10113;
   RM_SENDUSEITEMS         = 10114;
   RM_WEIGHTCHANGED        = 10115;
   RM_FEATURECHANGED       = 10116;
   RM_CLEAROBJECTS         = 10117;
   RM_CHANGEMAP            = 10118;
   RM_BUTCH                = 10119; //
   RM_MAGICFIRE            = 10120;
   RM_MAGICFIRE_FAIL       = 10121;
   RM_SENDMYMAGIC          = 10122;
   RM_MAGIC_LVEXP          = 10123;
   RM_SOUND                = 10124;
   RM_DURACHANGE           = 10125;
   RM_MERCHANTSAY          = 10126;
   RM_MERCHANTDLGCLOSE     = 10127;
   RM_SENDGOODSLIST        = 10128;
   RM_SENDUSERSELL         = 10129;
   RM_SENDBUYPRICE         = 10130;  //»óÁ¡¿¡¼­ »ç¿ëÀÚÀÇ ¾ÆÀÌÅÛÀ» »ç´Â °¡°İ
   RM_USERSELLITEM_OK      = 10131;
   RM_USERSELLITEM_FAIL    = 10132;
   RM_BUYITEM_SUCCESS      = 10133;
   RM_BUYITEM_FAIL         = 10134;
   RM_SENDDETAILGOODSLIST  = 10135;
   RM_GOLDCHANGED          = 10136;
   RM_CHANGELIGHT          = 10137;
   RM_LAMPCHANGEDURA       = 10138;
   RM_CHARSTATUSCHANGED    = 10139;
   RM_GROUPCANCEL          = 10140;
   RM_SENDUSERREPAIR       = 10141;
   RM_SENDREPAIRCOST       = 10142;
   RM_USERREPAIRITEM_OK    = 10143;
   RM_USERREPAIRITEM_FAIL  = 10144;
   //RM_ITEMDURACHANGE       = 10145;
   RM_SENDUSERSTORAGEITEM  = 10146;
   RM_SENDUSERSTORAGEITEMLIST = 10147;
   RM_DELITEMS             = 10148;  //¾ÆÀÌÅÛ ÀĞ¾î ¹ö¸², Å¬¶óÀÌ¾ğÅ×¿¡ ¾Ë¸².
   RM_SENDUSERMAKEDRUGITEMLIST = 10149;
   RM_MAKEDRUG_SUCCESS     = 10150;
   RM_MAKEDRUG_FAIL        = 10151;
   RM_SENDUSERSPECIALREPAIR = 10152;
   RM_ALIVE                = 10153;
   RM_DELAYMAGIC           = 10154;
   RM_RANDOMSPACEMOVE      = 10155;
   // ¾ÆÀÌÅÛ Á¦Á¶
   RM_SENDUSERMAKEITEMLIST = 10156;

   RM_DIGUP                = 10200;
   RM_DIGDOWN              = 10201;
   RM_FLYAXE               = 10202;
   RM_ALLOWPOWERHIT        = 10203;
   RM_LIGHTING             = 10204;
   RM_NORMALEFFECT         = 10205;  //±âº» È¿°ú
   RM_DRAGON_FIRE1         = 10206;
   RM_DRAGON_FIRE2         = 10207;
   RM_DRAGON_FIRE3         = 10208;
   RM_LIGHTING_1           = 10209;
   RM_LIGHTING_2           = 10210;
   RM_LIGHTING_3           = 10211;

   RM_MAKEPOISON           = 10300;
   RM_CHANGEGUILDNAME      = 10301; //±æµåÀÇ ÀÌ¸§, ±æµå³» Á÷Ã¥ÀÌ¸§ º¯°æ
   RM_SUBABILITY           = 10302;
   RM_BUILDGUILD_OK        = 10303;
   RM_BUILDGUILD_FAIL      = 10304;
   RM_DONATE_FAIL          = 10305;
   RM_DONATE_OK            = 10306;
   RM_MYSTATUS             = 10307;
   RM_TRANSPARENT          = 10308;
   RM_MENU_OK              = 10309;

   RM_SPACEMOVE_HIDE       = 10330;
   RM_SPACEMOVE_SHOW       = 10331;
   RM_RECONNECT            = 10332;
   RM_HIDEEVENT            = 10333;
   RM_SHOWEVENT            = 10334;
   RM_SPACEMOVE_HIDE2      = 10335;
   RM_SPACEMOVE_SHOW2      = 10336;
   RM_ZEN_BEE              = 10337;  //ºñ¸·¿øÃæÀÌ ºñ¸·ÃæÀ» ¸¸µé¾î ³½´Ù.
   RM_DELAYATTACK          = 10338;  //Å¸°İ ½ÃÁ¡À» ¸ÂÃß±â À§ÇØ¼­
   RM_SPACEMOVE_SHOW_NO    = 10339;  //ÀÌÆåÆ® ¾øÀÌ ³ªÅ¸³²

   RM_ADJUST_BONUS         = 10400;  //º¸³Ê½º Æ÷ÀÎÆ®¸¦ Á¶Á¤ÇÏ¶ó.
   RM_MAKE_SLAVE           = 10401;  //¼­¹öÀÌµ¿À¸·Î ºÎÇÏ°¡ µû¶ó¿Â´Ù.

   RM_OPENHEALTH           = 10410;  //Ã¼·ÂÀÌ »ó´ë¹æ¿¡ º¸ÀÓ
   RM_CLOSEHEALTH          = 10411;  //Ã¼·ÂÀÌ »ó´ë¹æ¿¡°Ô º¸ÀÌÁö ¾ÊÀ½
   RM_DOOPENHEALTH         = 10412;
   RM_BREAKWEAPON          = 10413;  //¹«±â°¡ ±úÁü, ¾Ö¹Ì¸ŞÀÌ¼Ç È¿°ú
   RM_INSTANCEHEALGUAGE    = 10414;
   RM_CHANGEFACE           = 10415;  //º¯½Å...
   RM_NEXTTIME_PASSWORD    = 10416;  //´ÙÀ½ ÇÑ¹øÀº ºñ¹Ğ¹øÈ£ÀÔ·Â ¸ğµå
   RM_DOSTARTUPQUEST       = 10417;
   RM_TAG_ALARM            = 10418;  //³»ºÎÀûÀ¸·Î ÂÊÁö¿ÔÀ½¾Ë¸²

   RM_LM_DBWANTLIST        = 10420;  // ¿¬ÀÎ»çÁ¦ ¸®½ºÆ®¿øÇÔ
   RM_LM_DBADD             = 10421;  // ¿¬ÀÎ»çÁ¦ ¸®½ºÆ®¿øÇÔ
   RM_LM_DBEDIT            = 10422;  // ¿¬ÀÎ»çÁ¦ ¸®½ºÆ®¿øÇÔ
   RM_LM_DBDELETE          = 10423;  // ¿¬ÀÎ»çÁ¦ ¸®½ºÆ®¿øÇÔ
   RM_LM_DBGETLIST         = 10424;  // ¿¬ÀÎ»çÁ¦ ¸®½ºÆ®¾òÀ½
   RM_LM_LOGOUT            = 10425;  // ¿¬ÀÎ Á¾·á¸¦ ¾Ë·ÁÁÜ

   RM_DRAGON_EXP           = 10430;  // ¿ë½Ã½ºÅÛ¿¡ °æÇèÄ¡ ÁØ´Ù.

   RM_LOOPNORMALEFFECT     = 10431;  //·çÇÁ ÀÓÆåÆ® È¿°ú
   RM_LOOPSCREENEFFECT     = 10432;  //È­¸é ÀÌÆåÆ®

   RM_PLAYDICE             = 10500;
   RM_PLAYROCK             = 10501;
   //2003/02/11 ±×·ì¿ø À§Ä¡ Á¤º¸
   RM_GROUPPOS             = 11008;

   // Ä«¿îÆ® ¾ÆÀÌÅÛ
   RM_COUNTERITEMCHANGE    = 11011;
   RM_USERSELLCOUNTITEM_OK = 11012;
   RM_USERSELLCOUNTITEM_FAIL = 11013;
   // ¾ÆÀÌÅÛ Á¦Á¶
   RM_SENDUSERMAKEFOODLIST = 11014;
   // ¾ÆÀÌÅÛ À§Å¹ÆÇ¸Å
   RM_MARKET_LIST          = 11015;
   RM_MARKET_RESULT        = 11016;

   // Àå¿ø ÆÇ¸Å ¸ñ·Ï
   RM_GUILDAGITLIST     = 11017;
   RM_GUILDAGITDEALTRY  = 11018;

   // Àå¿ø°Ô½ÃÆÇ
   RM_GABOARD_LIST         = 11019;  // Àå¿ø°Ô½ÃÆÇ ¸®½ºÆ®
   RM_GABOARD_NOTICE_OK    = 11020;  // Àå¿ø°Ô½ÃÆÇ °øÁö»çÇ× ¾²±â OK
   RM_GABOARD_NOTICE_FAIL  = 11021;  // Àå¿ø°Ô½ÃÆÇ °øÁö»çÇ× ¾²±â FAIL

   // Àå¿ø²Ù¹Ì±â
   RM_DECOITEM_LIST        = 11022;  // Àå¿ø²Ù¹Ì±â ¾ÆÀÌÅÛ ¸®½ºÆ®
   RM_DECOITEM_LISTSHOW    = 11023;  // Àå¿ø²Ù¹Ì±â ¾ÆÀÌÅÛ ¸®½ºÆ®Ã¢ ¶ç¿ì±â

   RM_CANCLOSE_OK          = 11024;
   RM_CANCLOSE_FAIL        = 11025;



   {----------------------------}
   //¼­¹ö°£ ¸Ş¼¼Áö¼­¹ö¸¦ °ÅÄ¡Áö ¾ÊÀº ¸Ş¼¼Â¡

   ISM_PASSWDSUCCESS       = 100;  //ÆĞ½º¿öµå Åë°ú, Certification+ID
   ISM_CANCELADMISSION     = 101;  //Certification ½ÂÀÎÃë¼Ò..
   ISM_USERCLOSED          = 102;  //»ç¿ëÀÚ Á¢¼Ó ²÷À½
   ISM_USERCOUNT           = 103;  //ÀÌ ¼­¹öÀÇ »ç¿ëÀÚ ¼ö
   ISM_TOTALUSERCOUNT      = 104;
   ISM_SHIFTVENTURESERVER  = 110;
   ISM_ACCOUNTEXPIRED      = 111;
   ISM_GAMETIMEOFTIMECARDUSER = 112;
   ISM_USAGEINFORMATION    = 113;
   ISM_FUNC_USEROPEN       = 114;
   ISM_FUNC_USERCLOSE      = 115;
   ISM_CHECKTIMEACCOUNT    = 116;
   ISM_REQUEST_PUBLICKEY   = 117;
   ISM_SEND_PUBLICKEY      = 118;
   ISM_PREMIUMCHECK        = 119;
   ISM_EVENTCHECK          = 120;

   {----------------------------}

   ISM_USERSERVERCHANGE    = 200;
   ISM_USERLOGON           = 201;
   ISM_USERLOGOUT          = 202;
   ISM_WHISPER             = 203;
   ISM_SYSOPMSG            = 204;
   ISM_ADDGUILD            = 205;
   ISM_DELGUILD            = 206;
   ISM_RELOADGUILD         = 207;
   ISM_GUILDMSG            = 208;
   ISM_CHATPROHIBITION     = 209;    //Ã¤±İ
   ISM_CHATPROHIBITIONCANCEL = 210;  //Ã¤±İÇØÁ¦
   ISM_CHANGECASTLEOWNER   = 211;   //»çºÏ¼º ÁÖÀÎ º¯°æ
   ISM_RELOADCASTLEINFO    = 212;   //»çºÏ¼ºÁ¤º¸°¡ º¯°æµÊ
   ISM_RELOADADMIN         = 213;

   // Friend System -------------
   ISM_FRIEND_INFO         = 214;    // Ä£±¸Á¤º¸ Ãß°¡
   ISM_FRIEND_DELETE       = 215;    // Ä£±¸ »èÁ¦
   ISM_FRIEND_OPEN         = 216;    // Ä£±¸ ½Ã½ºÅÛ ¿­±â
   ISM_FRIEND_CLOSE        = 217;    // Ä£±¸ ½Ã½ºÅÛ ´İ±â
   ISM_FRIEND_RESULT       = 218;    // °á°ú°ª Àü¼Û
   // Tag System ----------------
   ISM_TAG_SEND            = 219;    // ÂÊÁö Àü¼Û
   ISM_TAG_RESULT          = 220;    // °á°ú°ª Àü¼Û
   // User System --------------
   ISM_USER_INFO           = 221;    // À¯ÀúÀÇ Á¢¼Ó»óÅÂ Àü¼Û
   // 2003/06/12 ½½·¹ÀÌºê ÆĞÄ¡
   ISM_CHANGESERVERRECIEVEOK = 222;
   // 2003/08/28 Ã¤ÆÃ·Î±×
   ISM_RELOADCHATLOG       = 223;
   // À§Å¹ÆÇ¸Å ¿­°í ´İÀ½
   ISM_MARKETOPEN          = 224;
   ISM_MARKETCLOSE         = 225;  
   // relationship --------------
//   ISM_LM_INFO             = 224;   // °ü°è Á¤º¸ Àü¼Û
//   ISM_LM_LEVELINFO        = 225;   // °ü°è ·¹º§Á¤º¸ Àü¼Û
   ISM_LM_DELETE           = 226;

   // Á¦Á¶ Àç·á ¸ñ·Ï ------------(sonmg)
   ISM_RELOADMAKEITEMLIST  = 227;   // Á¦Á¶ Àç·á ¸ñ·Ï ¸®·Îµå

   // ¹®¿ø¼ÒÈ¯ ------------(sonmg)
   ISM_GUILDMEMBER_RECALL  = 228;   // ¹®¿ø¼ÒÈ¯
   ISM_RELOADGUILDAGIT     = 229;   // ¹®ÆÄÀå¿øÁ¤º¸ ¸®·Îµå.

   //¿¬ÀÎ
   ISM_LM_WHISPER          = 230;
   ISM_GMWHISPER           = 231;   //¿î¿µÀÚ ±Ó¸»
   //¿¬ÀÎ(sonmg 2005/04/04)
   ISM_LM_LOGIN            = 232;   //¿¬ÀÎ ·Î±×ÀÎ
   ISM_LM_LOGOUT           = 233;   //¿¬ÀÎ ·Î±×¾Æ¿ô
   ISM_REQUEST_RECALL      = 234;   //¼ÒÈ¯ ¿äÃ»
   ISM_RECALL              = 235;   //¼­¹ö°£ ¼ÒÈ¯
   ISM_LM_LOGIN_REPLY      = 236;   //·Î±×ÀÎ ÇßÀ» ¶§ ¿¬ÀÎÀÇ À§Ä¡Á¤º¸
   ISM_LM_KILLED_MSG       = 237;   //¿¬ÀÎ »ìÇØ ¸Ş½ÃÁö
   ISM_REQUEST_LOVERRECALL = 238;   //¿¬ÀÎ ¼ÒÈ¯ ¿äÃ»

   ISM_GUILDWAR            = 239;   //¹®ÆÄÀü ½ÅÃ»¿¬Àå
   ISM_STANDARDTICK        = 240;   //0¹ø ¼­¹öÀÇ Ç¥ÁØ Æ½ Á¤º¸

   {----------------------------}

   DB_LOADHUMANRCD         = 100;
   DB_SAVEHUMANRCD         = 101;
   DB_SAVEANDCHANGE        = 102;
   DB_IDPASSWD             = 103;
   DB_NEWUSERID            = 104;
   DB_CHANGEPASSWD         = 105;
   DB_QUERYCHR             = 106;
   DB_NEWCHR               = 107;
   DB_GETOTHERNAMES        = 108;
   DB_ISVALIDUSER          = 111;
   DB_DELCHR               = 112;
   DB_ISVALIDUSERWITHID    = 113;
   DB_CONNECTIONOPEN       = 114;
   DB_CONNECTIONCLOSE      = 115;
   DB_SAVELOGO             = 116;
   DB_GETACCOUNT           = 117;
   DB_SAVESPECFEE          = 118;
   DB_SAVELOGO2            = 119;
   DB_GETSERVER            = 120;
   DB_CHANGESERVER         = 121;
   DB_LOGINCLOSEUSER       = 122;
   DB_RUNCLOSEUSER         = 123;
   DB_UPDATEUSERINFO       = 124;
   // Friend System -------------
   DB_FRIEND_LIST          = 125;   // Ä£±¸ ¸®½ºÆ® ¿ä±¸
   DB_FRIEND_ADD           = 126;   // Ä£±¸ Ãß°¡
   DB_FRIEND_DELETE        = 127;   // Ä£±¸ »èÁ¦
   DB_FRIEND_OWNLIST       = 128;   // Ä£±¸·Î µî·ÏÇÑ »ç¶÷ ¸®½ºÆ® ¿ä±¸
   DB_FRIEND_EDIT          = 129;   // Ä£±¸ ¼³¸í ¼öÁ¤
   // Tag System ----------------
   DB_TAG_ADD              = 130;   // ÂÊÁö Ãß°¡
   DB_TAG_DELETE           = 131;   // ÂÊÁö »èÁ¦
   DB_TAG_DELETEALL        = 132;   // ÂÊÁö ÀüºÎ »èÁ¦ ( °¡´ÉÇÑ°Í¸¸ )
   DB_TAG_LIST             = 133;   // ÂÊÁö ¸®½ºÆ® Ãß°¡
   DB_TAG_SETINFO          = 134;   // ÃËÁö »óÅÂ º¯°æ
   DB_TAG_REJECT_ADD       = 135;   // °ÅºÎÀÚ Ãß°¡
   DB_TAG_REJECT_DELETE    = 136;   // °ÅºÎÀÚ »èÁ¦
   DB_TAG_REJECT_LIST      = 137;   // °ÅºÎÀÚ ¸®½ºÆ® ¿äÃ»
   DB_TAG_NOTREADCOUNT     = 138;   // ÀĞÁö¾ÊÀº ÂÊÁö °³¼ö ¿äÃ»
   // RelationShip --------------
   DB_LM_LIST              = 139;   // °ü°èÀÚ ¸®½ºÆ® ¿ä±¸
   DB_LM_ADD               = 140;   // °ü°èÀÚ Ãß°¡
   DB_LM_EDIT              = 141;   // °ü°èÀÚ ¼³Á¤ º¯°æ
   DB_LM_DELETE            = 142;   // °ü°èÀÚ »èÁ¦

   DBR_LOADHUMANRCD         = 1100;
   DBR_SAVEHUMANRCD         = 1101;
   DBR_IDPASSWD             = 1103;
   DBR_NEWUSERID            = 1104;
   DBR_CHANGEPASSWD         = 1105;
   DBR_QUERYCHR             = 1106;
   DBR_NEWCHR               = 1107;
   DBR_GETOTHERNAMES        = 1108;
   DBR_ISVALIDUSER          = 1111;
   DBR_DELCHR               = 1112;
   DBR_ISVALIDUSERWITHID    = 1113;
   DBR_GETACCOUNT           = 1117;
   DBR_GETSERVER            = 1200;
   DBR_CHANGESERVER         = 1201;
   DBR_UPDATEUSERINFO       = 1202;
   // Friend System ---------------
   DBR_FRIEND_LIST          = 1203; // Ä£±¸ ¸®½ºÆ® Àü¼Û
   DBR_FRIEND_WONLIST       = 1204; // Ä£±¸·Î µî·ÏÇÑ »ç¶÷ Àü¼Û
   DBR_FRIEND_RESULT        = 1205; // ¸í·É¾î¿¡ ´ëÇÑ °á°ú°ª
   // Tag System ------------------
   DBR_TAG_LIST             = 1206; // ÂÊÁö ¸®½ºÆ® Àü¼Û
   DBR_TAG_REJECT_LIST      = 1207; // °ÅºÎÀÚ ¸®½ºÆ® Àü¼Û
   DBR_TAG_NOTREADCOUNT     = 1208; // ÀĞÁö¾ÊÀº ÂÊÁö »õ¼ö Àü¼Û
   DBR_TAG_RESULT           = 1209; // ¸ê·É¿¡ ´ëÇÑ °á°ú°ª
   // RelationShip ---------------
   DBR_LM_LIST              = 1210; // °ü°è ¸®½ºÆ® ¾ò¾î¿À±â
   DBR_LM_RESULT            = 1211; // ¸í·É¾î¿¡ ´ëÇÑ °á°ú°ª

   DBR_FAIL                 = 2000;
   DBR_NONE                 = 2000;

   {----------------------------}

   MSM_LOGIN            = 1;
   MSM_GETUSERKEY       = 100;
   MSM_SELECTUSERKEY    = 101;
   MSM_GETGROUPKEY      = 102;
   MSM_SELECTGROUPKEY   = 103;
   MSM_UPDATEFEERCD     = 120;
   MSM_DELETEFEERCD     = 121;
   MSM_ADDFEERCD        = 122;
   MSM_GETTIMEOUTLIST   = 123;

   MCM_PASSWDSUCCESS    = 10;
   MCM_PASSWDFAIL       = 11;
   MCM_IDONUSE          = 12;
   MCM_GETFEERCD        = 1000;
   MCM_ADDFEERCD        = 1001;
   MCM_ENDTIMEOUT       = 1002;
   MCM_ONUSETIMEOUT     = 1003;


   //°ÔÀÌÆ®¿Í ¼­¹ö¿ÍÀÇ Åë½Å

   GM_OPEN              = 1;
   GM_CLOSE             = 2;
   GM_CHECKSERVER       = 3;     //¼­¹ö¿¡¼­ Ã¤Å© ½ÅÈ£¸¦ º¸³¿
   GM_CHECKCLIENT       = 4;     //Å¬¶óÀÌ¾ğÆ®¿¡¼­ Ã¤Å© ½ÅÈ£¸¦ º¸³¿
   GM_DATA              = 5;
   GM_SERVERUSERINDEX   = 6;
   GM_RECEIVE_OK        = 7;
   GM_SENDPUBLICKEY     = 8;
   GM_TEST              = 20;

   {----------------------------}


   //Á¾Á·
   RC_USERHUMAN   = 0;           //°æÇèÄ¡¸¦ ¾òÀ» ¼ö ¾øÀ½
   RC_NPC         = 10;
   RC_DOORGUARD   = 11;          //¹®Áö±â °æºñº´
   RC_PEACENPC    = 15;

   RC_ARCHERPOLICE = 20;

   RC_ANIMAL      = 50;
   RC_HEN         = 51;     //´ß
   RC_DEER        = 52;     //»ç½¿...
   RC_WOLF        = 53;     //´Á´ë
   RC_RUNAWAYHEN  = 54;     //´Ş¾Æ³ª´Â ´ß
   RC_TRAINER     = 55;     //¼ö·ÃÁ¶±³
   RC_MONSTER     = 80;     //ºñ¼±¸÷
   RC_OMA         = 81;
   RC_SPITSPIDER  = 82;
   RC_SLOWMONSTER = 83;
   RC_SCORPION     = 84;  //Àü°¥
   RC_KILLINGHERB  = 85;  //½ÄÀÎÃÊ
   RC_SKELETON     = 86;  //ÇØ°ñ
   RC_DUALAXESKELETON = 87;  //½Öµµ³¢ÇØ°ñ
   RC_HEAVYAXESKELETON = 88;  //Å«µµ³¢ÇØ°ñ
   RC_KNIGHTSKELETON = 89;  //ÇØ°ñÀü»ç
   RC_BIGKUDEKI      = 90;
   RC_MAGCOWFACEMON  = 91;
   RC_COWFACEKINGMON = 92;
   RC_THORNDARK      = 93;
   RC_LIGHTINGZOMBI  = 94;
   RC_DIGOUTZOMBI    = 95;
   RC_ZILKINZOMBI    = 96;
   RC_COWMON         = 97;   //¿ì¸é±Í
   RC_WHITESKELETON  = 100;  //¹é°ñ
   RC_SCULTUREMON    = 101;  //¼®»ó¸ó½ºÅÍ
   RC_SCULKING       = 102;  //ÁÖ¸¶¿Õ
   RC_BEEQUEEN       = 103;  //¹úÅë
   RC_ARCHERMON      = 104;  //¸¶±Ã»ç, ÇØ°ñ±Ã¼ö
   RC_GASMOTH        = 105;
   RC_DUNG           = 106;  //µÕ, °¡½º
   RC_CENTIPEDEKING  = 107;  //Áö³×¿Õ
   RC_BLACKPIG       = 108;  //Èæµ·
   RC_CASTLEDOOR     = 110;  //»çºÏ¼º¹®, ¼ºº®,..
   RC_WALL           = 111;  //»çºÏ¼º¹®, ¼ºº®,..
   RC_ARCHERGUARD    = 112;  //±Ã¼ö°æºñ
   RC_ELFMON         = 113;
   RC_ELFWARRIORMON  = 114;
   RC_BIGHEARTMON    = 115;  //Ç÷°ÅÀÎ ¿Õ Å« ½ÉÀå
   RC_SPIDERHOUSEMON = 116;  //Æø¾È°Å¹Ì
   RC_EXPLOSIONSPIDER = 117; //ÆøÁÖ
   RC_HIGHRISKSPIDER      = 118;    //°Å´ë °Å¹Ì
   RC_BIGPOISIONSPIDER = 119;  //°Å´ë µ¶°Å¹Ì
   RC_SOCCERBALL     = 120;   //Ãà±¸°ø
   RC_BAMTREE        = 121;

   RC_SCULKING_2     = 122;  //Â¦Åü ÁÖ¸¶¿Õ
   RC_BLACKSNAKEKING = 123;  //Èæ»ç¿Õ
   RC_NOBLEPIGKING   = 124;   //±Íµ·¿Õ
   RC_FEATHERKINGOFKING = 125; //ÈæÃµ¸¶¿Õ
   // 2003/02/11 Ãß°¡ ¸÷
   RC_SKELETONKING      = 126; //ÇØ°ñ¹İ¿Õ
   RC_TOXICGHOST        = 127; //ºÎ½Ä±Í
   RC_SKELETONSOLDIER   = 128; //ÇØ°ñº´Á¹
   // 2003/03/04 Ãß°¡ ¸÷
   RC_BANYAGUARD        = 129; //¹İ¾ßÁÂ»ç/¹İ¾ß¿ì»ç
   RC_DEADCOWKING       = 130; //»ç¿ìÃµ¿Õ
   // 2003/07/15 Ãß°¡ ¸÷
   RC_PBOMA1         = 131; //³¯°³¿À¸¶
   RC_PBOMA2         = 132; //¼è¹¶Ä¡»ó±Ş¿À¸¶
   RC_PBOMA3         = 133; //¸ùµÕÀÌ»ó±Ş¿À¸¶
   RC_PBOMA4         = 134; //Ä®ÇÏ±Ş¿À¸¶
   RC_PBOMA5         = 135; //µµ³¢ÇÏ±Ş¿À¸¶
   RC_PBOMA6         = 136; //È°ÇÏ±Ş¿À¸¶
   RC_PBGUARD        = 137; //°ú°ÅºñÃµ Ã¢°æºñ
   RC_PBMSTONE1      = 138; //¸¶°è¼®1
   RC_PBMSTONE2      = 139; //¸¶°è¼®2
   RC_PBKING         = 140; //¿À¸¶ÆÄÃµÈ²(ÆÄÈ²¸¶½Å)
   RC_MINE           = 141; //Áö·Ú

   RC_ANGEL          = 142; //¿ù·É(Ãµ³à)
   RC_CLONE          = 143; //ºĞ½Å
   RC_FIREDRAGON     = 144; //ÆÄÃµ¸¶·æ (È­·æ)
   RC_DRAGONBODY     = 145; //È­·æ¸ö
   RC_DRAGONSTATUE   = 146; //¿ë¼®»ó

   RC_EYE_PROG       = 147; //¼³ÀÎ´ëÃæ
   RC_STON_SPIDER    = 148; //½Å¼®µ¶¸¶ÁÖ
   RC_GHOST_TIGER    = 149; //È¯¿µÇÑÈ£
   RC_JUMA_THUNDER   = 150; //ÁÖ¸¶°İ·ÚÀå

   RC_GOLDENIMUGI    = 151; //È²±İÀÌ¹«±â

   RC_MONSTERBOX     = 152; //¸ó½ºÅÍ¹Ú½º
   RC_STICKBLOCK     = 153; //È£È¥¼®
   RC_FOXWARRIOR     = 154; //ºñ¿ù¿©¿ì(Àü»ç) ºñ¿ùÈæÈ£
   RC_FOXWIZARD      = 155; //ºñ¿ù¿©¿ì(¼ú»ç) ºñ¿ùÀûÈ£
   RC_FOXTAOIST      = 156; //ºñ¿ù¿©¿ì(µµ»ç) ºñ¿ù¼ÒÈ£
   RC_PUSHEDMON      = 157; //È£±â¿¬
   RC_PUSHEDMON2     = 158; //È£±â¿Á
   RC_FOXPILLAR      = 159; //È£È¥±â¼®
   RC_FOXBEAD        = 160; //ºñ¿ùÃµÁÖ
   RC_ARCHERMASTER   = 161;  //±Ã¼öÈ£À§º´(2005/08)
   //2005/12/14
   RC_NEARTURTLE     = 162; //±Ù°Å¸® °ÅºÏ
   RC_FARTURTLE      = 163; //¿ø°Å¸® °ÅºÏ
   RC_BOSSTURTLE     = 164; //º¸½º °ÅºÏ(Çö¹«)
   //2005/11/01
   RC_SUPEROMA       = 181; //¼öÆÛ¿À¸¶
   RC_TOGETHEROMA    = 182; //¹¶Ä¡¸é °­ÇØÁö´Â ¿À¸¶

   RC_CLONEMON       = 183; //ºĞ½Å¸ó½ºÅÍ


   //Å¬¶óÀÌ¾ğÆ® Á¾Á·...
   RCC_HUMAN      = 0;
   RCC_GUARD      = 12;
   RCC_GUARD2     = 24;
   RCC_MERCHANT   = 50;
   RCC_FIREDRAGON   = 83; // ÆÄÃµ¸¶·æ (È­·æ)

   LA_CREATURE    = 0;
   LA_UNDEAD      = 1;

   
   MP_CANMOVE		= 0;
   MP_WALL			= 1;
   MP_HIGHWALL    = 2;
   
   DR_UP          = 0;
   DR_UPRIGHT     = 1;
   DR_RIGHT       = 2;
   DR_DOWNRIGHT   = 3;
   DR_DOWN        = 4;
   DR_DOWNLEFT    = 5;
   DR_LEFT        = 6;
   DR_UPLEFT      = 7;

   U_DRESS        = 0;
   U_WEAPON       = 1;
   U_RIGHTHAND    = 2;
   U_NECKLACE     = 3;
   U_HELMET       = 4;
   U_ARMRINGL     = 5;
   U_ARMRINGR     = 6;
   U_RINGL        = 7;
   U_RINGR        = 8;
   // 2003/03/15 ¾ÆÀÌÅÛ ÀÎº¥Åä¸® È®Àå
   U_BUJUK        = 9;
   U_BELT         = 10;
   U_BOOTS        = 11;
   U_CHARM        = 12;

   UD_USER        = 0;
   UD_USER2       = 1;
   UD_OBSERVER    = 2;   // '2' µî±Ş
   UD_ASSISTANT   = 4;   // 'A' µî±Ş(observerµî±Ş°ú sysopµî±Ş »çÀÌ¿¡ Ãß°¡)
   UD_SYSOP       = 6;   // '1' µî±Ş
   UD_ADMIN       = 8;   // '*' µî±Ş
   UD_SUPERADMIN  = 10;  // '*' µî±Ş(Å×½ºÆ® ¼­¹ö ¶Ç´Â ÆĞ½º¿öµå ¼º°ø ÈÄ)

   ET_DIGOUTZOMBI    = 1;  //Á»ºñ°¡ ¶¥ÆÄ°í ³ª¿Â ÈçÀû
   ET_MINE           = 2;  //±¤¼®ÀÌ ¸ÅÀåµÇ¾î ÀÖÀ½
   ET_PILESTONES     = 3;  //µ¹¹«´õ±â
   ET_HOLYCURTAIN    = 4;  //°á°è
   ET_FIRE           = 5;
   ET_SCULPEICE      = 6;  //ÁÖ¸¶¿ÕÀÇ µ¹±úÁø Á¶°¢
   ET_HEARTPALP      = 7;  //Ç÷°ÅÀÎ ¿Õ(½ÉÀå)¹æÀÇ ÃË¼ö °ø°İ
   ET_MINE2          = 8;  //º¸¼®ÀÌ ¸ÅÀåµÇ¾î ÀÖÀ½
   ET_JUMAPEICE      = 9;  //ÁÖ¸¶°İ·ÚÀå ƒÆÁø Á¶°¢
   ET_MINE3          = 10;  //ÀÌº¥Æ®¿ë ±¤¼® ¹× º¸¼®ÀÌ ¸ÅÀåµÇ¾î ÀÖÀ½(2004/11/03)

   NE_HEARTPALP      = 1;  //±âº» È¿°ú ½Ã¸®Áî, 1¹ø ÃË¼ö°ø°İ
   NE_CLONESHOW      = 2;  //ºĞ½Å³ªÅ¸³²
   NE_CLONEHIDE      = 3;  //ºĞ½Å»ç¶óÁü
   NE_THUNDER        = 4;  //¿ë´øÁ¯ ¹ø°³
   NE_FIRE           = 5;  //¿ë´øÁ¯ ¿ë¾Ï
   NE_DRAGONFIRE     = 6;  //¿ëºÒ°ø°İ ÅÍÁü
   NE_FIREBURN       = 7;  //¿ë¼®»ó°ø°İ ÅÍÁü Å¸¿À¸§
   NE_FIRECIRCLE     = 8;  //È­·æ±â¿°
   //2004/06/22 ½Å±Ô¹«°ø ÀÌÆåÆ®.
   NE_MONCAPTURE     = 9;  //Æ÷½Â°Ë-Æ÷È¹ ÀÌÆåÆ®
   NE_BLOODSUCK      = 10; //ÈíÇ÷¼ú-ÈíÀÔ ÀÌÆåÆ®
   NE_BLINDEFFECT    = 11; //¸Í¾È¼ú ÀÌÆåÆ®
   NE_FLOWERSEFFECT  = 12; //²ÉÀÙ ÀÌÆåÆ®
   NE_LEVELUP        = 13; //·¹º§¾÷ ÀÌÆåÆ®
   NE_RELIVE         = 14; //ºÎÈ° ÀÌÆåÆ®
   NE_POISONFOG      = 15; //ÀÌ¹«±â µ¶¾È°³ ÀÓÆåÆ®
   NE_SN_MOVEHIDE    = 16; //ÀÌ¹«±â ¿öÇÁ »ç¶óÁö´ÂÀÓÆåÆ®
   NE_SN_MOVESHOW    = 17; //ÀÌ¹«±â ¿öÇÁ ³ªÅ¸³ª´ÂÀÓÆåÆ®
   NE_SN_RELIVE      = 18; //ÀÌ¹«±â ºÎÈ° ÀÓÆåÆ®
   NE_BIGFORCE       = 19; //¹«±ØÁø±â ÀÓÆåÆ®
   NE_JW_EFFECT1     = 20; //Àå¿ø ÀÌÆåÆ®
   NE_FOX_MOVEHIDE   = 21; //¼ú»çºñ¿ù¿©¿ì ¼ø°£ÀÌµ¿ ÀÓÆåÆ®
   NE_FOX_FIRE       = 22; //¼ú»çºñ¿ù¿©¿ì È­¿° ·çÇÁ ÀÓÆåÆ®
   NE_FOX_MOVESHOW   = 23; //¼ú»çºñ¿ù¿©¿ì ³ªÅ¸³ª´Â ÀÓÆåÆ®
   NE_SOULSTONE_HIT  = 24; //È£È¥¼® °ø°İ ÀÓÆåÆ®
   NE_KINGSTONE_RECALL_1  = 25; //ºñ¿ùÃµÁÖ ¼ÒÈ¯ ºñ¿ùÃµÁÖ¿¡°Ô »Ñ·ÁÁÜ
   NE_KINGSTONE_RECALL_2  = 26; //ºñ¿ùÃµÁÖ ¼ÒÈ¯ Ä³¸¯¿¡°Ô »Ñ·ÁÁÜ
   NE_SIDESTONE_PULL = 27; //È£È¥±â¼® ´ç±â±â
   NE_HAPPYBIRTHDAY  = 28; //ÇÁ¸®¹Ì¾ö »ıÀÏ ÀÓÆåÆ®
   NE_KINGTURTLE_MOBSHOW  = 29; //Çö¹«Çö½Å ¼ÒÈ¯¸÷ ³ªÅ¸³ª´ÂÀÓÆåÆ®
   NE_USERHEALING    = 30; //ÃÊº¸ÀÚÁö¿ª NPCÈú ÀÌÆåÆ®
   NE_DEFENCEEFFECT  = 31; //¿µÁ¤°©ÁÖ ¹İ»ç ÀÌÆåÆ®
   NE_KOREAFIGHTING  = 32; //¿ùµåÄÅÀÀ¿ø

   SWD_LONGHIT       = 12; //¾î°Ë¼ú
   SWD_WIDEHIT       = 25; //¹İ¿ù°Ë¹ı
   SWD_FIREHIT       = 26; //¿°È­°á
   SWD_RUSHRUSH      = 27; //¹«ÅÂº¸
   // 2003/03/15 ½Å±Ô¹«°ø
   SWD_CROSSHIT      = 34; //±¤Ç³Âü
   SWD_TWINHIT       = 38; //½Ö·æÂü
   SWD_STONEHIT      = 43; //»çÀÚÈÄ

   SKILL_MAXDEFENCE = 102;			// Ã¶Æ÷»ï

   //Äù½ºÆ® °ü·Ã
   //IF
   QI_CHECK          = 1;  //101ÀÌ»ó
   QI_RANDOM         = 2;
   QI_GENDER         = 3;  //MAN or WOMAN
   QI_DAYTIME        = 4;  //SUNRAISE DAY SUNSET NIGHT
   QI_CHECKOPENUNIT  = 5;  //À¯´ÖÃ¼Å©
   QI_CHECKUNIT      = 6;  //À¯´ÖÃ¼Å©
   QI_CHECKLEVEL     = 7;
   QI_CHECKJOB       = 8;  //Warrior, Wizard, Taoist
   QI_CHECKITEM      = 20;
   QI_CHECKITEMW     = 21;
   QI_CHECKGOLD      = 22;
   QI_ISTAKEITEM     = 23;  //¹æ±İÀü¿¡ ¹ŞÀº ¾ÆÀÌÅÛÀÌ ¹«¾ùÀÎÁö °Ë»ç
   QI_CHECKDURA      = 24;  //¾ÆÀÌÅÛÀÇ ¾ÆÀÌÅÛÀÇ Æò±Õ ³»±¸(dura / 1000) °Ë»ç
                            //¿©·¯°³ ÀÖ´Â °æ¿ì ÃÖ°í ³»±¸¸¦ °Ë»ç
   QI_CHECKDURAEVA   = 25;
   QI_DAYOFWEEK      = 26;  //¿äÀÏ °Ë»ç
   QI_TIMEHOUR       = 27;  //½Ã°£´ÜÀ§ °Ë»ç(0..23)
   QI_TIMEMIN        = 28;  //ºĞ °Ë»ç
   QI_CHECKPKPOINT   = 29;
   QI_CHECKLUCKYPOINT = 30;
   QI_CHECKMON_MAP   = 31;  //ÇöÀç ¸Ê¿¡ ¸÷ÀÌ ÀÖ´ÂÁö
   QI_CHECKMON_AREA  = 32;  //Æ¯Á¤ Áö¿ª¿¡ ¸÷ÀÌ ÀÖ´ÂÁö
   QI_CHECKHUM       = 33;
   QI_CHECKBAGGAGE   = 34;  //»ç¿ëÀÚ¿¡°Ô ÁÙ ¼ö ÀÖ´ÂÁö?
   //6-11
   QI_CHECKNAMELIST  = 35;
   QI_CHECKANDDELETENAMELIST  = 36;
   QI_CHECKANDDELETEIDLIST    = 37;
   //*dq
   QI_IFGETDAILYQUEST = 40;  //¿À´Ã Äù½ºÆ®¸¦ ¹Ş¾Ò´ÂÁö °Ë»ç, À¯È¿±â°£ °Ë»ç Æ÷ÇÔ
   QI_CHECKDAILYQUEST = 41;  //Æ¯Á¤ ¹øÈ£ÀÇ Äù½ºÆ®¸¦ ¼öÇàÁßÀÎÁö °Ë»ç, À¯È¿±â°£ °Ë»ç Æ÷ÇÔ
   QI_RANDOMEX        = 42;  //ÆÄ¶ó¸ŞÅ¸  5 100   5%ÀÓ...

   QI_CHECKMON_NORECALLMOB_MAP = 43;   //ÇöÀç ¸Ê¿¡ ÀÖ´Â ¸÷ ¼ö(¼ÒÈ¯¸÷ Á¦¿Ü)
   QI_CHECKBAGREMAIN  = 44;  //À¯Àú °¡¹æÀÇ °ø°£ÀÌ N°³ ³²¾Æ ÀÖ´ÂÁö

   QI_CHECKGRADEITEM  = 50;

   QI_EQUALVAR        = 51;   //EQUALV D1 P1  //D1ÀÌ P1°ú °°ÀºÁö

   QI_EQUAL          = 135;  //EQUAL P1 10   //P1ÀÌ 10ÀÎÁö
   QI_LARGE          = 136;  //LARGE P1 10   //P1ÀÌ 10º¸´Ù Å«Áö
   QI_SMALL          = 137;  //SMALL P1 10   //P1ÀÌ 10º¸´Ù ÀÛÀºÁö °Ë»ç

   QI_ISGROUPOWNER   = 138;  //±×·ì ¼ÒÀ¯ÁÖÀÎÁö ¾Æ´ÑÁö °Ë»ç
   QI_ISEXPUSER      = 139;  //Ã¼ÇèÆÇ »ç¿ëÀÚÀÎÁö °Ë»ç
   QI_CHECKLOVERFLAG = 140;  //¿¬ÀÎÀÇ ÇÃ·¡±×°¡ TRUEÀÎÁö °Ë»ç(¿¬ÀÎÁ¤º¸¸¦ Ã£À» ¼ö ¾øÀ¸¸é FALSE ¸®ÅÏ)
   QI_CHECKLOVERRANGE = 141;  //¿¬ÀÎÀÌ ÀÏÁ¤ ¹üÀ§ ¾È¿¡ ÀÖ´ÂÁö
   QI_CHECKLOVERDAY  = 142;  //¿¬ÀÎ°úÀÇ ±³Á¦ÀÏÀÌ ÀÏÁ¤ÀÏ ÀÌ»ó µÇ´ÂÁö
   //¸í¼ºÄ¡
   QI_CHECKFAMEGRADE = 143;  //¸í¼º µî±ŞÀÌ N ÀÌ»ó µÇ´ÂÁö Ã¼Å©
   QI_CHECKFAMEPOINT = 144;  //¸í¼º FameCur Æ÷ÀÎÆ®°¡ N ÀÌ»ó µÇ´ÂÁö Ã¼Å©
   QI_CHECKFAMEBASEPOINT = 145;  //¸í¼º FameBase Æ÷ÀÎÆ®°¡ N ÀÌ»ó µÇ´ÂÁö Ã¼Å©
   //Àå¿ø±âºÎ±İ
   QI_CHECKDONATION      = 146;    // ÇöÀç ±âºÎ±İ ÀÜ¾× Ã¼Å©
   QI_ISGUILDMASTER      = 147;    // GuildmasterÀÎÁö Ã¼Å©
   QI_CHECKWEAPONBADLUCK = 148;     //¹«±âÀÇ ÀúÁÖ Ã¼Å©
   QI_CHECKPREMIUMGRADE  = 149;    // ÇÁ¸®¹Ì¾ö µî±Ş Ã¼Å©
   QI_CHECKCHILDMOB      = 150;    // ¼ÒÈ¯ÁßÀÎ ¸ó½ºÅÍ ÀÌ¸§À¸·Î Ã¼Å©(CHECKRECALLMOB)

   QI_CHECKGROUPJOBBALANCE = 151;    // ±×·ì¿¡ Àü»ç, ¼ú»ç, µµ»ç ¼ö°¡ °°ÀºÁö Ã¼Å©
   QI_CHECKRANGEONELOVER   = 152;    // ¹üÀ§³»¿¡ ¿¬ÀÎÀÎ »ç¶÷ÀÌ ÀÖ´ÂÁö Ã¼Å©

   QI_EVENTCHECK     = 153; // ComeBack2005 ÀÌº¥Æ® Ã¼Å©
   QI_CHECKITEMWVALUE    = 154; //Âø¿ëÁßÀÎ °íÅë ¾ÆÀÌÅÛ ±â¼öÄ¡ Ã¼Å©

   //Action

   QA_SET            = 1;   //101ÀÌ»ó
   QA_TAKE           = 2;   //¾ÆÀÌÅÛÀ» ¹Ş´Ù
   QA_GIVE           = 3;
   QA_TAKEW          = 4;   //Âø¿ëÇÏ°í ÀÖ´Â ¾ÆÀÌÅÛÀ» ¹Ş´Ù
   QA_CLOSE          = 5;   //´ëÈ­Ã¢À» ´İÀ½
   QA_RESET          = 6;   //
   QA_OPENUNIT       = 7;
   QA_SETUNIT        = 8;  //À¯´Ö¼Â  1..100
   QA_RESETUNIT      = 9;  //À¯´Ö¸®¼Â   1..100
   QA_BREAK          = 10;
   QA_TIMERECALL     = 11;  // ÁöÁ¤µÈ ½Ã°£ÀÌ Áö³ª¸é ÇöÀç Àå¼Ò·Î ¼ÒÈ¯ µÈ´Ù.
   QA_PARAM1         = 12;
   QA_PARAM2         = 13;
   QA_PARAM3         = 14;
   QA_PARAM4         = 15;
   QA_MAPMOVE        = 20;
   QA_MAPRANDOM      = 21;
   QA_TAKECHECKITEM  = 22;  //CHECKÇ×¸ñ¿¡¼­ °Ë»çµÈ ¾ÆÀÌÅÛÀ» ¹Ş´Â´Ù.
   QA_MONGEN         = 23;  //¸ó½ºÅÍ¸¦ Á¨½ÃÅ´
   QA_MONCLEAR       = 24;  //¸ó½ºÅÍ¸¦ ¸ğµÎ Á¦°Å ½ÃÅ²´Ù
   QA_MOV            = 25;
   QA_INC            = 26;
   QA_DEC            = 27;
   QA_SUM            = 28; //SUM P1 P2 //P9 = P1 + P2
   QA_BREAKTIMERECALL = 29;
   QA_TIMERECALLGROUP = 30;  // ÁöÁ¤µÈ ½Ã°£ÀÌ Áö³ª¸é ±×·ì ÀüÃ¼°¡ ÇöÀç Àå¼Ò·Î ¼ÒÈ¯ µÈ´Ù.
   QA_CLOSENOINVEN    = 31;   //´ëÈ­Ã¢À» ´İÀ½(ÀÎº¥Ã¢Àº °Çµå¸®Áö ¾ÊÀ½)

   QA_MOVRANDOM      = 50;  //MOVR
   QA_EXCHANGEMAP    = 51;  //EXCHANGEMAP R001  //R001¿¡ ÀÖ´Â ÇÑ »ç¶÷°ú ÀÚ¸®¸¦ ¹Ù²Û´Ù.
   QA_RECALLMAP      = 52;  //RECALLMAP R001  //R001¿¡ ÀÖ´Â »ç¶÷µéÀ» ¸ğµÎ ¼ÒÈ¯ ÇÑ´Ù.
   QA_ADDBATCH       = 53;
   QA_BATCHDELAY     = 54;
   QA_BATCHMOVE      = 55;
   QA_PLAYDICE       = 56;  //PLAYDICE 2 @diceresult //2°³ÀÇ ÁÖ»çÀ§¸¦ ±¼¸°´Ù. ±×ÈÄ @diceresult ¼¼¼ÇÀ¸·Î °£´Ù
   //6-11
   QA_ADDNAMELIST     = 57;
   QA_DELETENAMELIST  = 58;
   QA_PLAYROCK       = 59;  //PLAYDICE 2 @diceresult //2°³ÀÇ ÁÖ»çÀ§¸¦ ±¼¸°´Ù. ±×ÈÄ @diceresult ¼¼¼ÇÀ¸·Î °£´Ù
   //*dq
   QA_RANDOMSETDAILYQUEST = 60;  //ÆÄ¶ó¸ŞÅÍ,  ÃÖ¼Ò, ÃÖ´ë  ¿¹) 401 450  401¿¡¼­ 450¹ø±îÁö ·£´ıÀ¸·Î ¼³Á¤
   QA_SETDAILYQUEST  = 61;

   QA_GIVEEXP        = 63; // °æÇèÄ¡ ÁÖ±â(ÀÌº¥Æ® Á¾·áÈÄ ±â´É »èÁ¦)

   QA_TAKEGRADEITEM  = 70;

   QA_GOTOQUEST      = 100;
   QA_ENDQUEST       = 101;
   QA_GOTO           = 102;
   QA_SOUND          = 103;
   QA_CHANGEGENDER   = 104;
   QA_KICK           = 105;
   QA_MOVEALLMAP     = 106;    // ÇöÀç ¸Ê À¯ÀúµéÀ» ¸ğµÎ Æ¯Á¤ ¸ÊÀ¸·Î ÀÌµ¿½ÃÅ´.
   QA_MOVEALLMAPGROUP = 107;    // ±×·ì ¸â¹öµé Áß¿¡ ÇöÀç ¸Ê¿¡ ÀÖ´Â ¸â¹öµé¸¸ Æ¯Á¤ ¸ÊÀ¸·Î ÀÌµ¿½ÃÅ´.
   QA_RECALLMAPGROUP = 108;    // ±×·ì ¸â¹öµé Áß¿¡ Æ¯Á¤ ¸Ê¿¡ ÀÖ´Â ¸â¹öµé¸¸ ÇöÀç ¸ÊÀ¸·Î ÀÌµ¿½ÃÅ´.
   QA_WEAPONUPGRADE  = 109;    // µé°í ÀÖ´Â ¹«±â¿¡ ¿É¼ÇÀ» ºÙÀÎ´Ù.
   QA_SETALLINMAP    = 110;    // ÇöÀç ¸Ê¿¡ ÀÖ´Â ¸ğµç À¯ÀúµéÀÇ ÇÃ·¡±×¸¦ SETÇÑ´Ù.
   QA_INCPKPOINT     = 111;    // PK Point¸¦ Áõ°¡½ÃÅ²´Ù.
   QA_DECPKPOINT     = 112;    // PK Point¸¦ °¨¼Ò½ÃÅ²´Ù.
   //¿¬ÀÎ
   QA_MOVETOLOVER    = 113;    // ¿¬ÀÎ¾ÕÀ¸·Î ÀÌµ¿ÇÑ´Ù.
   QA_BREAKLOVER     = 114;    // ¿¬ÀÎ°ü°è¸¦ ÀÏ¹æÀûÀ¸·Î ÇØÁ¦½ÃÅ²´Ù.
   QA_SOUNDALL       = 115;    // ÁÖº¯»ç¶÷¿¡°Ô »ç¿îµå¸¦ µé·ÁÁÜ
   //¸í¼ºÄ¡
   QA_USEFAMEPOINT   = 116;    // ÀÚ½ÅÀÇ ¸í¼ºÄ¡ »ç¿ë
   QA_DECWEAPONBADLUCK = 117;    // ÀúÁÖ°¡ ºÙÀº ¹«±âÀÇ ÀúÁÖ¸¦ 1 °¨¼Ò ½ÃÅ²´Ù.
   //Àå¿ø±âºÎ±İ
   QA_DECDONATION    = 118;    // ±âºÎ±İ ÀÜ¾×À» °¨¼Ò ½ÃÅ²´Ù.
   QA_SHOWEFFECT     = 119;    // Àå¿øÀÌÆåÆ®¸¦ º¸¿©ÁØ´Ù.
   QA_MONGENAROUND   = 120;    // Ä³¸¯ÀÇ ÁÖÀ§¿¡ ¸ó½ºÅÍ¸¦ Á¨ ½ÃÅ²´Ù.
   QA_RECALLMOB      = 121;    // ºÎÇÏ ¸ó½ºÅÍ ¼ÒÈ¯

   QA_SETLOVERFLAG   = 122;    //¿¬ÀÎÀÇ ÇÃ·¡±×¸¦ SETÇÑ´Ù.
   QA_GUILDSECESSION = 123;    //¹®ÆÄÅ»Åğ
   QA_GIVETOLOVER    = 124;    //¿¬ÀÎ¿¡°Ô ¾ÆÀÌÅÛ ÁÖ±â
   QA_INCMEMORIALCOUNT  = 125;    //NPCº° Ä«¿îÆ® Áõ°¡
   QA_DECMEMORIALCOUNT  = 126;    //NPCº° Ä«¿îÆ® °¨¼Ò
   QA_SAVEMEMORIALCOUNT = 127;    //NPCº° Ä«¿îÆ® ÆÄÀÏ ÀúÀå

   QA_INSTANTPOWERUP   = 128; //¼ø°£ ´É·ÂÄ¡ »ó½Â
   QA_INSTANTEXPDOUBLE = 129; //¼ø°£ °æÇèÄ¡ 2¹è
   QA_HEALING          = 130; //Èú¸µ
   QA_UNIFYITEM        = 131; //¾ÆÀÌÅÛÀ» ÇÕÄ£´Ù

   QA_MISSION          = 132; //¹Ì¼Ç ¼³Á¤
   QA_MOBPLACE         = 133; //¹Ì¼Ç¸÷ ¹èÄ¡

   VERSION_NUMBER = 20050501;
   VERSION_NUMBER_20030805 = 20030805;
   VERSION_NUMBER_20030715 = 20030715;
   VERSION_NUMBER_20030527 =20030527;
   VERSION_NUMBER_20030403 = 20030403;
   VERSION_NUMBER_030328 = 20030328;
   VERSION_NUMBER_030317 = 20030317;
   VERSION_NUMBER_030211 = 20030211;
   VERSION_NUMBER_030122 = 20030122;
   VERSION_NUMBER_020819 = 20020819;
   VERSION_NUMBER_0522 = 20020522;
   VERSION_NUMBER_02_0403 = 20020403;
   VERSION_NUMBER_01_1006 = 20011006;
   VERSION_NUMBER_0925 = 20010925;
   VERSION_NUMBER_0704 = 20010704;
   //VERSION_NUMBER_0522 = 20010522;
   VERSION_NUMBER_0419 = 20010419;
   VERSION_NUMBER_0407 = 20010407;
   VERSION_NUMBER_0305 = 20010305;
   VERSION_NUMBER_0216 = 20010216;
   BUFFERSIZE = 10000;

    // ¾ÆÀÌÅÛÀÇ º¯È­°ª Á¤ÀÇ
    EFFTYPE_TWOHAND_WEHIGHT_ADD  = 1;
    EFFTYPE_EQUIP_WHEIGHT_ADD    = 2;
    EFFTYPE_LUCK_ADD             = 3;
    EFFTYPE_BAG_WHIGHT_ADD       = 4;
    EFFTYPE_HP_MP_ADD            = 5;
    EFFTYPE2_EVENT_GRADE         = 6;

    // Comand Result Defines... PDS:2003-03-31 ---------------------------------
    CR_SUCCESS          = 0;       // ¼º°ø
    CR_FAIL             = 1;       // ½ÇÆĞ
    CR_DONTFINDUSER     = 2;       // À¯Àú¸¦ Ã£À» ¼ö ¾øÀ½
    CR_DONTADD          = 3;       // Ãß°¡ÇÒ ¼ö ¾øÀ½
    CR_DONTDELETE       = 4;       // »èÁ¦ÇÒ ¼ö ¾øÀ½
    CR_DONTUPDATE       = 5;       // º¯°æÇÒ ¼ö ¾øÀ½
    CR_DONTACCESS       = 6;       // ½ÇÇà ºÒ°¡´É
    CR_LISTISMAX        = 7;       // ¸®½ºÆ®ÀÇ ÃÖ´ëÄ¡ÀÌ¹Ç·Î ºÒ°¡´É
    CR_LISTISMIN        = 8;       // ¸®½ºÆ®ÀÇ ÃÖ¼ÒÄ¡ÀÌ¹Ç·Î ºÒ°¡´É
    CR_DBWAIT           = 9;       // DB¿¡¼­ ±â´Ù¸®°í ÀÖ´ÂÁß 

    // Á¢¼Ó»óÅÂ  PDS:2003-03-31 ------------------------------------------------
    CONNSTATE_UNKNOWN    = 0;       // ¾Ë¼ö ¾øÀ½
    CONNSTATE_DISCONNECT = 1;       // ºñÁ¢¼Ó »óÅÂ
    CONNSTATE_NOUSE1     = 2;       // »ç¿ë¾ÈÇÔ
    CONNSTATE_NOUSE2     = 3;       // »ç¿ë¾ÈÇÔ
    CONNSTATE_CONNECT_0  = 4;       // 0¹ø¼­¹ö¿¡ Á¢¼ÓÇÔ
    CONNSTATE_CONNECT_1  = 5;       // 1¹ø¼­¹ö¿¡ Á¢¼ÓÇÔ
    CONNSTATE_CONNECT_2  = 6;       // 2¹ø¼­¹ö¿¡ Á¢¼ÓÇÔ
    CONNSTATE_CONNECT_3  = 7;       // 3¹ø¼­¹ö¿¡ Á¢¼ÓÇÔ : ¿¹ºñ·Î¸¸µë

    // °ü°èºĞ·ù  2003/04/15 Ä£±¸, ÂÊÁö
    RT_FRIENDS          = 1;       // Ä£±¸
    RT_LOVERS           = 2;       // ¿¬ÀÎ
    RT_MASTER           = 3;       // »çºÎ
    RT_DISCIPLE         = 4;       // Á¦ÀÚ
    RT_BLACKLIST        = 8;       // ¾Ç¿¬

    // ÂÊÁö»óÅÂ  PDS:2003-03-31 ------------------------------------------------
    TAGSTATE_NOTREAD     = 0;       // ÀĞÁö¾ÊÀ½
    TAGSTATE_READ        = 1;       // ÀĞÀ½
    TAGSTATE_DONTDELETE  = 2;       // »èÁ¦±İÁö
    TAGSTATE_DELETED     = 3;       // »èÁ¦µÊ

    // ÂÊÁö»óÅÂ º¯°æ¿¡¼­ ¾²ÀÓ
    TAGSTATE_WANTDELETABLE = 3;     // »èÁ¦°¡´ÉÇÏ°Ô º¯°æ

// Relationship Request Sequences...
    RsReq_None             = 0;        // ±âº»»óÅÂ
    RsReq_WantToJoinOther  = 1;        // ´©±¸¿¡°Ô Âü°¡½ÅÃ»À» ÇÔ
    RsReq_WaitAnser        = 2;        // ÀÀ´äÀ» ±â´Ù¸²
    RsReq_WhoWantJoin      = 3;        // ´©±º°¡ Âü°¡¸¦ ¿øÇÔ
    RsReq_AloowJoin        = 4;        // Âü°¡¸¦ Çã¶ôÇÔ
    RsReq_DenyJoin         = 5;        // Âü°¡¸¦ °ÅÀıÇÔ
    RsReq_Cancel           = 6;        // Ãë¼Ò

    RaReq_CancelTime       = 30 * 1000; // ÀÚµ¿ Ãë¼Ò ½Ã°£ 30ÃÊ msec
    MAX_WAITTIME           = 60 * 1000; // ÃÖ´ë ±â´Ù¸®´Â ½Ã°£
// Relationship State Define...
    RsState_None           = 0;         // ±âº»»óÅÂ
    RsState_Lover          = 10;        // ¿¬ÀÎ
    RsState_LoverEnd       = 11;        // ¿¬ÀÎÅ»Åğ
    RsState_Married        = 20;        // °áÈ¥
    RsState_MarriedEnd     = 21;        // °áÈ¥Å»Åğ
    RsState_Master         = 30;        // »çºÎ
    RsState_MasterEnd      = 31;        // »çºÎÅ»Åğ
    RsState_Pupil          = 40;        // Á¦ÀÚ
    RsState_PupilEnd       = 41;        // Á¦ÀÚÅ»Åğ
    RsState_TempPupil      = 50;        // ÀÓ½ÃÁ¦ÀÚ
    RsState_TempPupilEnd   = 51;        // ÀÓ½ÃÁ¦ÀÚÅ»Åğ

// RelationShip Error Code...
    RsError_SuccessJoin    = 1;         // Âü°¡¿¡ ¼º°øÇÏ¿´´Ù ( Âü°¡ÇÑ»ç¶÷ÂÊ)
    RsError_SuccessJoined  = 2;         // Âü°¡¿¡ ¼º°øµÇ¾îÁ³´Ù ( Âü°¡µÈ »ç¶÷ÂÊ)
    RsError_DontJoin       = 3;         // Âü°¡ÇÒ¼ö ¾ø´Ù
    RsError_DontLeave      = 4;         // ¶°³¯¼ö ¾ø´Ù.
    RsError_RejectMe       = 5;         // °ÅºÎ»óÅÂÀÌ´Ù
    RsError_RejectOther    = 6;         // °ÅºÎ»óÅÂÀÌ´Ù
    RsError_LessLevelMe    = 7;         // ³ªÀÇ·¹º§ÀÌ ³·´Ù
    RsError_LessLevelOther = 8;         // »ó´ë¹æÀÇ·¹º§ÀÌ ³·´Ù
    RsError_EqualSex       = 9;         // ¼ºº°ÀÌ °°´Ù
    RsError_FullUser       = 10;        // Âü¿©ÀÎ¿øÀÌ °¡µæÃ¡´Ù
    RsError_CancelJoin     = 11;        // Âü°¡Ãë¼Ò
    RsError_DenyJoin       = 12;        // Âü°¡¸¦ °ÅÀıÇÔ
    RsError_DontDelete     = 13;        // Å»Åğ½ÃÅ³¼ö ¾ø´Ù.
    RsError_SuccessDelete  = 14;        // Å»Åğ½ÃÄ×À½
    RsError_NotRelationShip= 15;        // ±³Á¦»óÅÂ°¡ ¾Æ´Ï´Ù.

    // °ãÄ¡±â
    MAX_OVERLAPITEM = 1000;

    // À§Å¹»óÁ¡ ÆÇ¸ÅÁ¾·ù
    // °³º°¾ÆÀÌÅÛ·ù
    USERMARKET_TYPE_ALL     = 0   ;     // ¸ğµÎ
    USERMARKET_TYPE_WEAPON  = 1   ;     // ¹«±â
    USERMARKET_TYPE_NECKLACE= 2   ;     // ¸ñ°ÉÀÌ
    USERMARKET_TYPE_RING    = 3   ;     // ¹İÁö
    USERMARKET_TYPE_BRACELET= 4   ;     // ÆÈÂî,Àå°©
    USERMARKET_TYPE_CHARM   = 5   ;     // ¼öÈ£¼®
    USERMARKET_TYPE_HELMET  = 6   ;     // Åõ±¸
    USERMARKET_TYPE_BELT    = 7   ;     // Çã¸®¶ì
    USERMARKET_TYPE_SHOES   = 8   ;     // ½Å¹ß
    USERMARKET_TYPE_ARMOR   = 9   ;     // °©¿Ê
    USERMARKET_TYPE_DRINK   = 10  ;     // ½Ã¾à
    USERMARKET_TYPE_JEWEL   = 11  ;     // º¸¿Á,½ÅÁÖ
    USERMARKET_TYPE_BOOK    = 12  ;     // Ã¥
    USERMARKET_TYPE_MINERAL = 13  ;     // ±¤¼®
    USERMARKET_TYPE_QUEST   = 14  ;     // Äù½ºÆ®¾ÆÀÌÅÛ
    USERMARKET_TYPE_ETC     = 15  ;     // ±âÅ¸
    USERMARKET_TYPE_ITEMNAME= 16  ;     // ¾ÆÀÌÅÛÀÌ¸§
    // ¼ÂÆ®·ù
    USERMARKET_TYPE_SET     = 100 ;     // ¼ÂÆ® ¾ÆÀÌÅÛ
    // À¯Àú·ù
    USERMARKET_TYPE_MINE    = 200 ;     // ÀÚ½ÅÀÌÆÇ¹°°Ç
    USERMARKET_TYPE_OTHER   = 300 ;     // ´Ù¸¥»ç¶÷ÀÌ ÆÇ¹°°Ç

    USERMARKET_MODE_NULL    = 0   ;     // ÃÊ±â°ª
    USERMARKET_MODE_BUY     = 1   ;     // »ç´Â¸ğµå
    USERMARKET_MODE_INQUIRY = 2   ;     // Á¶È¸¸ğµå
    USERMARKET_MODE_SELL    = 3   ;     // ÆÇ¸Å¸ğµå


    MARKET_CHECKTYPE_SELLOK     = 1;    //À§Å¹ Á¤»ó
    MARKET_CHECKTYPE_SELLFAIL   = 2;    //À§Å¹ ½ÇÆĞ
    MARKET_CHECKTYPE_BUYOK      = 3;    //±¸ÀÔ Á¤»ó
    MARKET_CHECKTYPE_BUYFAIL    = 4;    //±¸ÀÔ ½ÇÆĞ
    MARKET_CHECKTYPE_CANCELOK   = 5;    //Ãë¼Ò Á¤»ó
    MARKET_CHECKTYPE_CANCELFAIL = 6;    //Ãë¼Ò ½ÇÆĞ
    MARKET_CHECKTYPE_GETPAYOK   = 7;    //µ· È¸¼ö Á¤»ó
    MARKET_CHECKTYPE_GETPAYFAIL = 8;    //µ· È¸¼ö ½ÇÆĞ

    MARKET_DBSELLTYPE_SELL          = 1;//ÆÇ¸ÅÁß
    MARKET_DBSELLTYPE_BUY           = 2;//»òÀ½
    MARKET_DBSELLTYPE_CANCEL        = 3;//Ãë¼Ò
    MARKET_DBSELLTYPE_GETPAY        = 4;//±İ¾×È¸¼ö
    MARKET_DBSELLTYPE_READYSELL     = 11;//ÀÓ½Ã ÆÇ¸ÅÁß
    MARKET_DBSELLTYPE_READYBUY      = 12;//ÀÓ½Ã »ç´ÂÁß
    MARKET_DBSELLTYPE_READYCANCEL   = 13;//ÀÓ½Ã Ãë¼ÒÁß
    MARKET_DBSELLTYPE_READYGETPAY   = 14;//ÀÓ½Ã È¸¼öÁß
    MARKET_DBSELLTYPE_DELETE        = 20;//»èÁ¦

    // À§Å¹»óÁ¡ ¸®ÅÏ°ª
    UMResult_Success         = 0   ;     // ¼º°ø
    UMResult_Fail            = 1   ;     // ½ÇÆĞ
    UMResult_ReadFail        = 2   ;     // ÀĞ±â ½ÇÆĞ
    UMResult_WriteFail       = 3   ;     // ÀúÀå ½ÇÆĞ
    UMResult_ReadyToSell     = 4   ;     // ÆÇ¸Å°¡´É
    UMResult_OverSellCount   = 5   ;     // ÆÇ¸Å ¾ÆÀÌÅÛ °³¼ö ÃÊ°ú
    UMResult_LessMoney       = 6   ;     // ±İÀüºÎÁ·
    UMResult_LessLevel       = 7   ;     // ·¹º§ºÎÁ·
    UMResult_MaxBagItemCount = 8   ;     // °¡¹æ¿¡ ¾ÆÀÌÅÛ²ËÂü
    UMResult_NoItem          = 9   ;     // ¾ÆÀÌÅÛÀÌ ¾øÀ½
    UMResult_DontSell        = 10  ;     // ÆÇ¸ÅºÒ°¡
    UMResult_DontBuy         = 11  ;     // ±¸ÀÔºÒ°¡
    UMResult_DontGetMoney    = 12  ;     // ±İ¾×È¸¼ö ºÒ°¡
    UMResult_MarketNotReady  = 13  ;     // À§Å¹½Ã½ºÅÛ ÀÚÃ¼°¡ ºÒ°¡´É
    UMResult_LessTrustMoney  = 14  ;     // À§Å¹±İ¾×ÀÌ ºÎÁ· 1000 Àü º¸´Ù´Â Ä¿¾ßµÊ
    UMResult_MaxTrustMoney   = 15  ;     // À§Å¹±İ¾×ÀÌ ³Ê¹« Å­
    UMResult_CancelFail      = 16  ;     // À§Å¹Ãë¼Ò ½ÇÆĞ
    UMResult_OverMoney       = 17  ;     // ¼ÒÀ¯±İ¾× ÃÖ´ëÄ¡°¡ ³Ñ¾î°¨
    UMResult_SellOK          = 18  ;     // ÆÇ¸Å°¡ Àß‰çÀ½
    UMResult_BuyOK           = 19  ;     // ±¸ÀÔÀÌ Àß‰çÀ½
    UMResult_CancelOK        = 20  ;     // ÆÇ¸ÅÃë¼Ò°¡ Àß‰çÀ½
    UMResult_GetPayOK        = 21  ;     // ÆÇ¸Å±İ È¸¼ö°¡ Àß‰çÀ½

    // °¡°İÃÖ´ëÄ¡
    MAX_MARKETPRICE = 50000000;  //5000¸¸Àü


function  RACEfeature (feature: Longint): byte;
function  DRESSfeature (feature: Longint): byte;
function  WEAPONfeature (feature: Longint): byte;
function  HAIRfeature (feature: Longint): byte;
function  APPRfeature (feature: Longint): word;
function  MakeFeature (race, dress, weapon, face: byte): Longint;
function  MakeFeatureAp (race, state: byte; appear: word): Longint;
function  MakeDefaultMsg (msg: word; soul: integer; wparam, atag, nseries: word; hid: integer = 200): TDefaultMessage;
function  UpInt (r: Real): integer;


implementation


function RACEfeature (feature: Longint): byte;
begin
	Result := LOBYTE (LOWORD (feature));
end;

function WEAPONfeature (feature: Longint): byte;
begin
	Result := HIBYTE (LOWORD (feature));
end;

function HAIRfeature (feature: Longint): byte;
begin
	Result := LOBYTE (HIWORD (feature));
end;

function DRESSfeature (feature: Longint): byte;
begin
	Result := HIBYTE (HIWORD (feature));
end;

function APPRfeature (feature: Longint): word;
begin
	Result := HIWORD (feature);
end;

function MakeFeature (race, dress, weapon, face: byte): Longint;
begin
	Result := MakeLong (MakeWord (race, weapon), MakeWord (face, dress));
end;

function MakeFeatureAp (race, state: byte; appear: word): Longint;
begin
	Result := MakeLong (MakeWord (race, state), appear);
end;

function  MakeDefaultMsg (msg: word; soul: integer; wparam, atag, nseries: word; hid: integer = 200): TDefaultMessage;
begin
   with Result do begin
      Ident := msg;
      Recog := soul;
      param := wparam;
      Tag	:= atag;
      Series := nseries;
      Etc := ((HIWORD(hid) and $A3) or $58) xor $8A;
      Etc2 := ((LOWORD(hid) and $EC) or $28) xor $A9;
   end;
end;

function UpInt (r: Real): integer;
begin
   if r > int(r) then Result := Trunc(r)+1 else Result := Trunc(r);
end;


end.



