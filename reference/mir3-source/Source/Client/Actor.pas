unit Actor;

interface

uses
  Windows, Messages, SysUtils, Classes, Graphics, Controls, Forms, Dialogs,
  Grobal2, HGETextures, CliUtil, magiceff, Wil, ClFunc;

const
   MAXACTORSOUND = 3;
   CMMX     = 150;
   CMMY     = 200;

   HUMANFRAME = 3000;
   MONFRAME  = 280;
   EXPMONFRAME = 360;
   SCULMONFRAME = 440;
   ZOMBIFRAME = 430;
   MERCHANTFRAME = 100;
   MAXSAY = 5;
//   MON1_FRAME =
//   MON2_FRAME =

   RUN_MINHEALTH = 10;
   DEFSPELLFRAME = 10;
   FIREHIT_READYFRAME = 6;  //¿°È­°á ½ÃÀü ÇÁ·¡ÀÓ
   MAGBUBBLEBASE = 3890;
   MAGBUBBLESTRUCKBASE = 3900;
   MAXWPEFFECTFRAME = 5;
   WPEFFECTBASE = 3750;
   EFFECTBASE = 0;

type
   TActionInfo = record
      start   : word;              // ½ÃÀÛ ÇÁ·¡ÀÓ
      frame   : word;              // ÇÁ·¡ÀÓ °¹¼ö
      skip    : word;
      ftime   : word;              // ÇÁ·¡ÀÓ °¹¼ö
      usetick : byte;              // »ç¿ëÆ½, ÀÌµ¿ µ¿ÀÛ¿¡¸¸ »ç¿ëµÊ
   end;
   PTActionInfo = ^TActionInfo;

   THumanAction = record
      ActStand:      TActionInfo;   //1
      ActWalk:       TActionInfo;   //8
      ActRun:        TActionInfo;   //8
      ActRushLeft:   TActionInfo;
      ActRushRight:  TActionInfo;
      ActWarMode:    TActionInfo;   //1
      ActHit:        TActionInfo;   //6
      ActHeavyHit:   TActionInfo;   //6
      ActBigHit:     TActionInfo;   //6
      ActFireHitReady: TActionInfo; //6
      ActSpell:      TActionInfo;   //6
      ActSitdown:    TActionInfo;   //1
      ActStruck:     TActionInfo;   //3
      ActDie:        TActionInfo;   //4
   end;
   PTHumanAction = ^THumanAction;

   TMonsterAction = record
      ActStand:      TActionInfo;   //1
      ActWalk:       TActionInfo;   //8
      ActAttack:     TActionInfo;   //6
      ActCritical:   TActionInfo;   //6
      ActStruck:     TActionInfo;   //3
      ActDie:        TActionInfo;   //4
      ActDeath:      TActionInfo;
   end;
   PTMonsterAction = ^TMonsterAction;

const
   HA: THumanAction = (
        ActStand:  (start: 0;      frame: 4;  skip: 6;  ftime: 200;  usetick: 0);
        ActWalk:   (start: 1680;     frame: 6;  skip: 4;  ftime: 90;   usetick: 2);
        ActRun:    (start: 1760;    frame: 6;  skip: 4;  ftime: 120;  usetick: 3);
        ActRushLeft: (start: 128;    frame: 3;  skip: 5;  ftime: 120;  usetick: 3);
        ActRushRight:(start: 131;    frame: 3;  skip: 5;  ftime: 120;  usetick: 3);
        ActWarMode:(start: 560;    frame: 3;  skip: 7;  ftime: 200;  usetick: 0);
        //ActHit:    (start: 200;    frame: 5;  skip: 3;  ftime: 140;  usetick: 0);
        ActHit:    (start: 720;    frame: 6;  skip: 4;  ftime: 85;   usetick: 0);
        ActHeavyHit:(start: 800;   frame: 6;  skip: 4;  ftime: 85;   usetick: 0);
        ActBigHit: (start: 880;    frame: 6;  skip: 4;  ftime: 85;   usetick: 0);
        ActFireHitReady: (start: 192; frame: 6;  skip: 4;  ftime: 70;   usetick: 0);
        ActSpell:  (start: 240;    frame: 5;  skip: 5;  ftime: 75;   usetick: 0);
        ActSitdown:(start: 640;    frame: 2;  skip: 8;  ftime: 400;  usetick: 0);
        ActStruck: (start: 1200;    frame: 3;  skip: 7;  ftime: 100;  usetick: 0);
        ActDie:    (start: 1520;    frame: 10;  skip: 0;  ftime: 120;  usetick: 0)
      );

   MA9: TMonsterAction = (  //Ãà±¸°ø
        ActStand:  (start: 0;      frame: 1;  skip: 7;  ftime: 200;  usetick: 0);
        ActWalk:   (start: 64;     frame: 6;  skip: 2;  ftime: 120;  usetick: 3);
        ActAttack: (start: 64;     frame: 6;  skip: 2;  ftime: 150;  usetick: 0);
        ActCritical:(start: 0;     frame: 0;  skip: 0;  ftime: 0;    usetick: 0);
        ActStruck: (start: 64;     frame: 6;  skip: 2;  ftime: 100;  usetick: 0);
        ActDie:    (start: 0;      frame: 1;  skip: 7;  ftime: 140;  usetick: 0);
        ActDeath:  (start: 0;      frame: 1;  skip: 7;  ftime: 0;    usetick: 0);
      );
   MA10: TMonsterAction = (  //´ß, ¹¶ÄÚ(8FrameÂ¥¸®)
        ActStand:  (start: 0;      frame: 4;  skip: 4;  ftime: 200;  usetick: 0);
        ActWalk:   (start: 64;     frame: 6;  skip: 2;  ftime: 120;  usetick: 3);
        ActAttack: (start: 128;    frame: 4;  skip: 4;  ftime: 150;  usetick: 0);
        ActCritical:(start: 0;     frame: 0;  skip: 0;  ftime: 0;    usetick: 0);
        ActStruck: (start: 192;    frame: 2;  skip: 0;  ftime: 100;  usetick: 0);
        ActDie:    (start: 208;    frame: 4;  skip: 4;  ftime: 140;  usetick: 0);
        ActDeath:  (start: 272;    frame: 1;  skip: 0;  ftime: 0;    usetick: 0);
      );
   MA11: TMonsterAction = (  //»ç½¿(10FrameÂ¥¸®)
        ActStand:  (start: 0;      frame: 4;  skip: 6;  ftime: 200;  usetick: 0);
        ActWalk:   (start: 80;     frame: 6;  skip: 4;  ftime: 120;  usetick: 3);
        ActAttack: (start: 160;    frame: 6;  skip: 4;  ftime: 100;  usetick: 0);
        ActCritical:(start: 0;     frame: 0;  skip: 0;  ftime: 0;    usetick: 0);
        ActStruck: (start: 240;    frame: 2;  skip: 0;  ftime: 100;  usetick: 0);
        ActDie:    (start: 260;    frame: 10; skip: 0;  ftime: 140;  usetick: 0);
        ActDeath:  (start: 340;    frame: 1;  skip: 0;  ftime: 0;    usetick: 0);
      );
   MA12: TMonsterAction = (  //°æºñº´, ¶§¸®´Â ¼Óµµ ºü¸£´Ù.
        ActStand:  (start: 0;      frame: 4;  skip: 4;  ftime: 200;  usetick: 0);
        ActWalk:   (start: 64;     frame: 6;  skip: 2;  ftime: 120;  usetick: 3);
        ActAttack: (start: 128;    frame: 6;  skip: 2;  ftime: 150;  usetick: 0);
        ActCritical:(start: 0;     frame: 0;  skip: 0;  ftime: 0;    usetick: 0);
        ActStruck: (start: 192;    frame: 2;  skip: 0;  ftime: 150;  usetick: 0);
        ActDie:    (start: 208;    frame: 4;  skip: 4;  ftime: 160;  usetick: 0);
        ActDeath:  (start: 272;    frame: 1;  skip: 0;  ftime: 0;    usetick: 0);
      );
   MA13: TMonsterAction = (  //½ÄÀÎÃÊ
        ActStand:  (start: 0;      frame: 4;  skip: 6;  ftime: 200;  usetick: 0);
        ActWalk:   (start: 10;     frame: 8;  skip: 2;  ftime: 160;  usetick: 0); //µîÀå...
        ActAttack: (start: 30;     frame: 6;  skip: 4;  ftime: 120;  usetick: 0);
        ActCritical:(start: 0;     frame: 0;  skip: 0;  ftime: 0;    usetick: 0);
        ActStruck: (start: 110;    frame: 2;  skip: 0;  ftime: 100;  usetick: 0);
        ActDie:    (start: 130;    frame: 10; skip: 0;  ftime: 120;  usetick: 0);
        ActDeath:  (start: 20;     frame: 9;  skip: 0;  ftime: 150;  usetick: 0); //¼ûÀ½..
      );
   MA14: TMonsterAction = (  //ÇØ°ñ ¿À¸¶
        ActStand:  (start: 0;      frame: 4;  skip: 6;  ftime: 200;  usetick: 0);
        ActWalk:   (start: 80;     frame: 6;  skip: 4;  ftime: 160;  usetick: 3); //
        ActAttack: (start: 160;    frame: 6;  skip: 4;  ftime: 100;  usetick: 0);
        ActCritical:(start: 0;     frame: 0;  skip: 0;  ftime: 0;    usetick: 0);
        ActStruck: (start: 240;    frame: 2;  skip: 0;  ftime: 100;  usetick: 0);
        ActDie:    (start: 260;    frame: 10; skip: 0;  ftime: 120;  usetick: 0);
        ActDeath:  (start: 340;    frame: 10; skip: 0;  ftime: 100;  usetick: 0); //¹é°ñÀÎ°æ¿ì(¼ÒÈ¯)
      );
   MA15: TMonsterAction = (  //µµ³¢´øÁö´Â ¿À¸¶
        ActStand:  (start: 0;      frame: 4;  skip: 6;  ftime: 200;  usetick: 0);
        ActWalk:   (start: 80;     frame: 6;  skip: 4;  ftime: 160;  usetick: 3); //
        ActAttack: (start: 160;    frame: 6;  skip: 4;  ftime: 100;  usetick: 0);
        ActCritical:(start: 0;     frame: 0;  skip: 0;  ftime: 0;    usetick: 0);
        ActStruck: (start: 240;    frame: 2;  skip: 0;  ftime: 100;  usetick: 0);
        ActDie:    (start: 260;    frame: 10; skip: 0;  ftime: 120;  usetick: 0);
        ActDeath:  (start: 1;      frame: 1;  skip: 0;  ftime: 100;  usetick: 0);
      );
   MA16: TMonsterAction = (  //°¡½º½î´Â ±¸µ¥±â
        ActStand:  (start: 0;      frame: 4;  skip: 6;  ftime: 200;  usetick: 0);
        ActWalk:   (start: 80;     frame: 6;  skip: 4;  ftime: 160;  usetick: 3); //
        ActAttack: (start: 160;    frame: 6;  skip: 4;  ftime: 160;  usetick: 0);
        ActCritical:(start: 0;     frame: 0;  skip: 0;  ftime: 0;    usetick: 0);
        ActStruck: (start: 240;    frame: 2;  skip: 0;  ftime: 100;  usetick: 0);
        ActDie:    (start: 260;    frame: 4;  skip: 6;  ftime: 160;  usetick: 0);
        ActDeath:  (start: 0;      frame: 1;  skip: 0;  ftime: 160;  usetick: 0);
      );
   MA17: TMonsterAction = (  //¹Ùµü²¨¸®´Â ¸÷
        ActStand:  (start: 0;      frame: 4;  skip: 6;  ftime: 60;  usetick: 0);
        ActWalk:   (start: 80;     frame: 6;  skip: 4;  ftime: 160;  usetick: 3); //
        ActAttack: (start: 160;    frame: 6;  skip: 4;  ftime: 100;  usetick: 0);
        ActCritical:(start: 0;     frame: 0;  skip: 0;  ftime: 0;    usetick: 0);
        ActStruck: (start: 240;    frame: 2;  skip: 0;  ftime: 100;  usetick: 0);
        ActDie:    (start: 260;    frame: 10; skip: 0;  ftime: 100;  usetick: 0);
        ActDeath:  (start: 340;    frame: 1;  skip: 0;  ftime: 140;  usetick: 0); //
      );
   MA19: TMonsterAction = (  //¿ì¸é±Í (Á×´Â°Å »¡¸®Á×À½)
//        ActStand:  (start: 0;      frame: 4;  skip: 6;  ftime: 200;  usetick: 0);
//        ActWalk:   (start: 80;     frame: 6;  skip: 4;  ftime: 160;  usetick: 3); //
//        ActAttack: (start: 160;    frame: 6;  skip: 4;  ftime: 100;  usetick: 0);
//        ActCritical:(start: 0;     frame: 0;  skip: 0;  ftime: 0;    usetick: 0);
//        ActStruck: (start: 240;    frame: 2;  skip: 0;  ftime: 100;  usetick: 0);
//        ActDie:    (start: 260;    frame: 10; skip: 0;  ftime: 140;  usetick: 0);
//        ActDeath:  (start: 340;    frame: 1;  skip: 0;  ftime: 140;  usetick: 0); //

    ActStand: (start: 0; frame: 4; skip: 6; ftime: 70; usetick: 0);
    ActWalk: (start: 80; frame: 6; skip: 4; ftime: 90; usetick: 3);
    ActAttack: (start: 160; frame: 10; skip: 0; ftime: 120; usetick: 0);
    ActCritical: (start: 0; frame: 0; skip: 0; ftime: 0; usetick: 0);
    ActStruck: (start: 240; frame: 2; skip: 8; ftime: 70; usetick: 0);
    ActDie: (start: 320; frame: 10; skip: 0; ftime: 120; usetick: 0);
    ActDeath: (start: 329; frame: 1; skip: 9; ftime: 0; usetick: 0);
    //    ActSpell: (start: 400; frame: 6; skip: 4; ftime: 100; usetick: 0);
      );
   MA20: TMonsterAction = (  //Á×¾ú´Ù »ì¾Æ³ª´Â Á»ºñ)
        ActStand:  (start: 0;      frame: 4;  skip: 6;  ftime: 200;  usetick: 0);
        ActWalk:   (start: 80;     frame: 6;  skip: 4;  ftime: 160;  usetick: 3); //
        ActAttack: (start: 160;    frame: 6;  skip: 4;  ftime: 120;  usetick: 0);
        ActCritical:(start: 0;     frame: 0;  skip: 0;  ftime: 0;    usetick: 0);
        ActStruck: (start: 240;    frame: 2;  skip: 0;  ftime: 100;  usetick: 0);
        ActDie:    (start: 260;    frame: 10; skip: 0;  ftime: 100;  usetick: 0);
        ActDeath:  (start: 340;    frame: 10; skip: 0;  ftime: 170;  usetick: 0); //´Ù½Ã »ì¾Æ³ª±â
      );
   MA21: TMonsterAction = (  //¹úÁý
        ActStand:  (start: 0;      frame: 4;  skip: 6;  ftime: 200;  usetick: 0);
        ActWalk:   (start: 0;      frame: 0;  skip: 0;  ftime: 0;    usetick: 0); //
        ActAttack: (start: 10;     frame: 6;  skip: 4;  ftime: 120;  usetick: 0); //¹ú ¹ß»ç
        ActCritical:(start: 0;     frame: 0;  skip: 0;  ftime: 0;    usetick: 0);
        ActStruck: (start: 20;     frame: 2;  skip: 0;  ftime: 100;  usetick: 0);
        ActDie:    (start: 30;     frame: 10; skip: 0;  ftime: 160;  usetick: 0);
        ActDeath:  (start: 0;      frame: 0;  skip: 0;  ftime: 0;    usetick: 0); //
      );
   MA22: TMonsterAction = (  //¼®»ó¸ó½ºÅÍ(¿°¼Ò´ëÀå,¿°¼ÒÀå±º)
        ActStand:  (start: 80;     frame: 4;  skip: 6;  ftime: 200;  usetick: 0);
        ActWalk:   (start: 160;    frame: 6;  skip: 4;  ftime: 160;  usetick: 3); //
        ActAttack: (start: 240;    frame: 6;  skip: 4;  ftime: 100;  usetick: 0); //
        ActCritical:(start: 0;     frame: 0;  skip: 0;  ftime: 0;    usetick: 0);
        ActStruck: (start: 320;    frame: 2;  skip: 0;  ftime: 100;  usetick: 0);
        ActDie:    (start: 340;    frame: 10; skip: 0;  ftime: 160;  usetick: 0);
        ActDeath:  (start: 0;      frame: 6;  skip: 4;  ftime: 170;  usetick: 0); //¼®»ó³ìÀ½
      );
   MA23: TMonsterAction = (  //ÁÖ¸¶¿Õ
        ActStand:  (start: 20;     frame: 4;  skip: 6;  ftime: 200;  usetick: 0);
        ActWalk:   (start: 100;    frame: 6;  skip: 4;  ftime: 160;  usetick: 3); //
        ActAttack: (start: 180;    frame: 6;  skip: 4;  ftime: 100;  usetick: 0); //
        ActCritical:(start: 0;     frame: 0;  skip: 0;  ftime: 0;    usetick: 0);
        ActStruck: (start: 260;    frame: 2;  skip: 0;  ftime: 100;  usetick: 0);
        ActDie:    (start: 280;    frame: 10; skip: 0;  ftime: 160;  usetick: 0);
        ActDeath:  (start: 0;      frame: 20; skip: 0;  ftime: 100;  usetick: 0); //¼®»ó³ìÀ½
      );
   MA24: TMonsterAction = (  //Àü°¥, °ø°Ý 2°¡Áö
        ActStand:  (start: 0;      frame: 4;  skip: 6;  ftime: 200;  usetick: 0);
        ActWalk:   (start: 80;     frame: 6;  skip: 4;  ftime: 160;  usetick: 3); //
        ActAttack: (start: 160;    frame: 6;  skip: 4;  ftime: 100;  usetick: 0);
        ActCritical:(start:240;    frame: 6;  skip: 4;  ftime: 100;  usetick: 0);
        ActStruck: (start: 320;    frame: 2;  skip: 0;  ftime: 100;  usetick: 0);
        ActDie:    (start: 340;    frame: 10; skip: 0;  ftime: 140;  usetick: 0);
        ActDeath:  (start: 420;    frame: 1;  skip: 0;  ftime: 140;  usetick: 0); //
      );
   MA25: TMonsterAction = (  //Áö³×¿Õ
        ActStand:  (start: 0;      frame: 4;  skip: 6;  ftime: 200;  usetick: 0);
        ActWalk:   (start: 70;     frame: 10; skip: 0;  ftime: 200;  usetick: 3); //µîÀå
        ActAttack: (start: 20;     frame: 6;  skip: 4;  ftime: 120;  usetick: 0); //Á÷Á¢°ø°Ý
        ActCritical:(start: 10;    frame: 6;  skip: 4;  ftime: 120;  usetick: 0); //µ¶Ä§°ø°Ý(¿ø°Å¸®)
        ActStruck: (start: 50;     frame: 2;  skip: 0;  ftime: 100;  usetick: 0);
        ActDie:    (start: 60;     frame: 10; skip: 0;  ftime: 200;  usetick: 0);
        ActDeath:  (start: 80;     frame: 10; skip: 0;  ftime: 200;  usetick: 3); //
      );
   MA26: TMonsterAction = (  //¼º¹®,
        ActStand:  (start: 0;      frame: 1;  skip: 7;  ftime: 200;  usetick: 0);
        ActWalk:   (start: 0;      frame: 0;  skip: 0;  ftime: 160;  usetick: 0); //µîÀå...
        ActAttack: (start: 56;     frame: 6;  skip: 2;  ftime: 500;  usetick: 0); //¿­±â
        ActCritical:(start: 64;    frame: 6;  skip: 2;  ftime: 500;  usetick: 0); //´Ý±â
        ActStruck: (start: 0;      frame: 4;  skip: 4;  ftime: 100;  usetick: 0);
        ActDie:    (start: 24;     frame: 10; skip: 0;  ftime: 120;  usetick: 0);
        ActDeath:  (start: 0;      frame: 0;  skip: 0;  ftime: 150;  usetick: 0); //¼ûÀ½..
      );
   MA27: TMonsterAction = (  //¼ºº®
        ActStand:  (start: 0;     frame: 1;  skip: 7;  ftime: 200;  usetick: 0);
        ActWalk:   (start: 0;     frame: 0;  skip: 0;  ftime: 160;  usetick: 0); //µîÀå...
        ActAttack: (start: 0;     frame: 0;  skip: 0;  ftime: 250;  usetick: 0);
        ActCritical:(start: 0;    frame: 0;  skip: 0;  ftime: 250;  usetick: 0);
        ActStruck: (start: 0;     frame: 0;  skip: 0;  ftime: 100;  usetick: 0);
        ActDie:    (start: 0;     frame: 10; skip: 0;  ftime: 120;  usetick: 0);
        ActDeath:  (start: 0;     frame: 0;  skip: 0;  ftime: 150;  usetick: 0); //¼ûÀ½..
      );
   MA28: TMonsterAction = (  //½Å¼ö (º¯½Å Àü)
        ActStand:  (start: 80;     frame: 4;  skip: 6;  ftime: 200;  usetick: 0);
        ActWalk:   (start: 160;    frame: 6;  skip: 4;  ftime: 160;  usetick: 3); //
        ActAttack: (start:  0;     frame: 6;  skip: 4;  ftime: 100;  usetick: 0);
        ActCritical:(start: 0;     frame: 0;  skip: 0;  ftime: 0;    usetick: 0);
        ActStruck: (start: 240;    frame: 2;  skip: 0;  ftime: 100;  usetick: 0);
        ActDie:    (start: 260;    frame: 10; skip: 0;  ftime: 120;  usetick: 0);
        ActDeath:  (start:  0;     frame: 10; skip: 0;  ftime: 100;  usetick: 0); //µîÀå..
      );
   MA29: TMonsterAction = (  //½Å¼ö (º¯½Å ÈÄ)
        ActStand:  (start: 80;     frame: 4;  skip: 6;  ftime: 200;  usetick: 0);
        ActWalk:   (start: 160;    frame: 6;  skip: 4;  ftime: 160;  usetick: 3); //
        ActAttack: (start: 240;    frame: 6;  skip: 4;  ftime: 100;  usetick: 0);
        ActCritical:(start: 0;     frame: 10; skip: 0;  ftime: 100;  usetick: 0);
        ActStruck: (start: 320;    frame: 2;  skip: 0;  ftime: 100;  usetick: 0);
        ActDie:    (start: 340;    frame: 10; skip: 0;  ftime: 120;  usetick: 0);
        ActDeath:  (start:  0;     frame: 10; skip: 0;  ftime: 100;  usetick: 0); //µîÀå..
      );

   MA30: TMonsterAction = (  //Ç÷°ÅÀÎ¿Õ, ½ÉÀå, Àû¿ù¸¶
        ActStand:  (start: 0;      frame: 4;  skip: 6;  ftime: 200;  usetick: 0);
        ActWalk:   (start: 0;     frame: 10; skip: 0;  ftime: 200;  usetick: 3); //
        ActAttack: (start: 10;     frame: 6;  skip: 4;  ftime: 120;  usetick: 0); //°ø°ÝÆû
        ActCritical:(start: 10;    frame: 6;  skip: 4;  ftime: 120;  usetick: 0); //
        ActStruck: (start: 20;     frame: 2;  skip: 0;  ftime: 100;  usetick: 0);
        ActDie:    (start: 30;     frame: 20; skip: 0;  ftime: 150;  usetick: 0);
        ActDeath:  (start: 0;     frame: 10; skip: 0;  ftime: 200;  usetick: 3); //
      );
   MA31: TMonsterAction = (  //Æø¾È°Å¹Ì
        ActStand:  (start: 0;      frame: 4;  skip: 6;  ftime: 200;  usetick: 0);
        ActWalk:   (start: 0;     frame: 10; skip: 0;  ftime: 200;  usetick: 3); //
        ActAttack: (start: 10;     frame: 6;  skip: 4;  ftime: 120;  usetick: 0); //°ø°ÝÆû
        ActCritical:(start: 0;    frame: 6;  skip: 4;  ftime: 120;  usetick: 0); //
        ActStruck: (start: 0;     frame: 2;  skip: 8;  ftime: 100;  usetick: 0);
        ActDie:    (start: 20;     frame: 10; skip: 0;  ftime: 200;  usetick: 0);
        ActDeath:  (start: 0;     frame: 10; skip: 0;  ftime: 200;  usetick: 3); //
      );
   MA32: TMonsterAction = (  //ÆøÁÖ
        ActStand:  (start: 0;      frame: 1;  skip: 9;  ftime: 200;  usetick: 0);
        ActWalk:   (start: 0;     frame: 6; skip: 4;  ftime: 200;  usetick: 3); //
        ActAttack: (start: 0;     frame: 6;  skip: 4;  ftime: 120;  usetick: 0); //°ø°ÝÆû
        ActCritical:(start: 0;    frame: 6;  skip: 4;  ftime: 120;  usetick: 0); //
        ActStruck: (start: 0;     frame: 2;  skip: 8;  ftime: 100;  usetick: 0);
        ActDie:    (start: 80;     frame: 10; skip: 0;  ftime: 80;  usetick: 0);
        ActDeath:  (start: 80;     frame: 10; skip: 0;  ftime: 200;  usetick: 3); //
      );
   MA33: TMonsterAction = (  //·ÚÇ÷»ç, ¿ÕÁß¾Ó (ÁÖ¸¶º»¿Õ), ¿Õµ·
        ActStand:  (start: 0;      frame: 4;  skip: 6;  ftime: 200;  usetick: 0);
        ActWalk:   (start: 80;     frame: 6;  skip: 4;  ftime: 200;  usetick: 3); //
        ActAttack: (start: 160;    frame: 6;  skip: 4;  ftime: 120;  usetick: 0); //°ø°ÝÆû
        ActCritical:(start: 340;   frame: 6;  skip: 4;  ftime: 120;  usetick: 0); //
        ActStruck: (start: 240;    frame: 2;  skip: 0;  ftime: 100;  usetick: 0);
        ActDie:    (start: 260;    frame: 10; skip: 0;  ftime: 200;  usetick: 0);
        ActDeath:  (start: 260;    frame: 10; skip: 0;  ftime: 200;  usetick: 0); //
      );
   // 2003/02/11
   MA34: TMonsterAction = (  //ÇØ°ñ¹Ý¿Õ
        ActStand:  (start: 0;      frame: 4;  skip: 6;  ftime: 200;  usetick: 0);
        ActWalk:   (start: 80;     frame: 6;  skip: 4;  ftime: 200;  usetick: 3); //
        ActAttack: (start: 160;    frame: 6;  skip: 4;  ftime: 120;  usetick: 0); //°ø°ÝÆû
        ActCritical:(start: 320;   frame: 6;  skip: 4;  ftime: 120;  usetick: 0); //
        ActStruck: (start: 400;    frame: 2;  skip: 0;  ftime: 100;  usetick: 0);
        ActDie:    (start: 420;    frame: 20; skip: 0;  ftime: 200;  usetick: 0);
        ActDeath:  (start: 420;    frame: 20; skip: 0;  ftime: 200;  usetick: 0); //
      );
   MA50: TMonsterAction = (  //ÀÏ¹Ý NPC
        ActStand:  (start: 0;    frame: 4;  skip: 6;  ftime: 200;  usetick: 0);
        ActWalk:   (start: 0;    frame: 0;  skip: 0;  ftime: 0;  usetick: 0);
        ActAttack: (start: 30;   frame: 10; skip: 0;  ftime: 150;  usetick: 0);
        ActCritical:(start: 0;     frame: 0;  skip: 0;  ftime: 0;    usetick: 0);
        ActStruck: (start: 0;    frame: 1;  skip: 9;  ftime: 0;  usetick: 0);
        ActDie:    (start: 0;    frame: 0;  skip: 0;  ftime: 0;  usetick: 0);
        ActDeath:  (start: 0;    frame: 0;  skip: 0;  ftime: 0;  usetick: 0);
      );
   MA51: TMonsterAction = (
        ActStand:  (start: 0;    frame: 4;  skip: 6;  ftime: 200;  usetick: 0);
        ActWalk:   (start: 0;    frame: 0;  skip: 0;  ftime: 0;  usetick: 0);
        ActAttack: (start: 30;   frame: 20; skip: 0;  ftime: 150;  usetick: 0);
        ActCritical:(start: 0;     frame: 0;  skip: 0;  ftime: 0;    usetick: 0);
        ActStruck: (start: 0;    frame: 1;  skip: 9;  ftime: 0;  usetick: 0);
        ActDie:    (start: 0;    frame: 0;  skip: 0;  ftime: 0;  usetick: 0);
        ActDeath:  (start: 0;    frame: 0;  skip: 0;  ftime: 0;  usetick: 0);
      );
   MA52: TMonsterAction = (  //
        ActStand:  (start: 30;    frame: 4;  skip: 6;  ftime: 200;  usetick: 0);
        ActWalk:   (start: 0;    frame: 0;  skip: 0;  ftime: 0;  usetick: 0);
        ActAttack: (start: 30;   frame: 4; skip: 6;  ftime: 150;  usetick: 0);
        ActCritical:(start: 0;     frame: 0;  skip: 0;  ftime: 0;    usetick: 0);
        ActStruck: (start: 0;    frame: 1;  skip: 9;  ftime: 0;  usetick: 0);
        ActDie:    (start: 0;    frame: 0;  skip: 0;  ftime: 0;  usetick: 0);
        ActDeath:  (start: 0;    frame: 0;  skip: 0;  ftime: 0;  usetick: 0);
      );
   // 2003/07/15 Ãß°¡µÈ °ú°ÅºñÃµ ¸÷
   MA53: TMonsterAction = (  //°ú°Å ºñÃµ °æºñº´, ¶§¸®´Â ¼Óµµ ºü¸£´Ù.
        ActStand:  (start: 0;      frame: 4;  skip: 6;  ftime: 200;  usetick: 0);
        ActWalk:   (start: 0;      frame: 0;  skip: 0;  ftime: 0;    usetick: 0);
        ActAttack: (start: 80;     frame: 6;  skip: 4;  ftime: 150;  usetick: 0);
        ActCritical:(start: 0;     frame: 0;  skip: 0;  ftime: 0;    usetick: 0);
        ActStruck: (start: 0;      frame: 0;  skip: 0;  ftime: 0;    usetick: 0);
        ActDie:    (start: 0;      frame: 0;  skip: 0;  ftime: 0;    usetick: 0);
        ActDeath:  (start: 0;      frame: 0;  skip: 0;  ftime: 0;    usetick: 0);
      );
   MA54: TMonsterAction = (  //¸¶°è¼®
        ActStand:  (start: 0;      frame: 4;  skip: 6;  ftime: 300;  usetick: 0);
        ActWalk:   (start: 0;      frame: 0;  skip: 0;  ftime: 0;    usetick: 0);
        ActAttack: (start: 10;     frame: 6;  skip: 4;  ftime: 150;  usetick: 0);
        ActCritical:(start: 0;     frame: 0;  skip: 0;  ftime: 0;    usetick: 0);
        ActStruck: (start: 20;     frame: 2;  skip: 0;  ftime: 150;  usetick: 0);
        ActDie:    (start: 30;     frame: 10; skip: 0;  ftime: 80;   usetick: 0);
        ActDeath:  (start: 0;      frame: 0;  skip: 0;  ftime: 0;    usetick: 0);
      );
   MA55: TMonsterAction = (  //¿À¸¶ÆÐ¿Õ
        ActStand:  (start: 0;      frame: 4;  skip: 6;  ftime: 250;  usetick: 0);
        ActWalk:   (start: 80;     frame: 6;  skip: 4;  ftime: 210;  usetick: 3); //
        ActAttack: (start: 160;    frame: 6;  skip: 4;  ftime: 110;  usetick: 0); //°ø°ÝÆû
        ActCritical:(start: 580;   frame: 20; skip: 0;  ftime: 135;  usetick: 0); //
        ActStruck: (start: 240;    frame: 2;  skip: 0;  ftime: 120;  usetick: 0);
        ActDie:    (start: 260;    frame: 20; skip: 0;  ftime: 130;  usetick: 0);
        ActDeath:  (start: 260;    frame: 20; skip: 0;  ftime: 130;  usetick: 0); //
      );
   MA56: TMonsterAction = ( //¼®»ó
        ActStand:  (start: 0;    frame: 2;  skip: 8;  ftime: 200;  usetick: 0);
        ActWalk:   (start: 0;    frame: 2;  skip: 8;  ftime: 200;  usetick: 0);
        ActAttack: (start: 0;    frame: 2;  skip: 8;  ftime: 200;  usetick: 0);
        ActCritical:(start: 0;   frame: 2;  skip: 8;  ftime: 200;  usetick: 0);
        ActStruck: (start: 0;    frame: 2;  skip: 8;  ftime: 200;  usetick: 0);
        ActDie:    (start: 0;    frame: 2;  skip: 8;  ftime: 200;  usetick: 0);
        ActDeath:  (start: 0;    frame: 2;  skip: 8;  ftime: 200;  usetick: 0);
      );
   MA57: TMonsterAction = (  // µµ±úºñºÒ, ²É´«
        ActStand:  (start: 0;      frame: 4;  skip: 6;  ftime: 200;  usetick: 0);
        ActWalk:   (start: 10;     frame: 8;  skip: 2;  ftime: 160;  usetick: 0); //µîÀå...
        ActAttack: (start:  0;     frame: 0;  skip: 0;  ftime: 0;    usetick: 0);
        ActCritical:(start: 0;     frame: 0;  skip: 0;  ftime: 0;    usetick: 0);
        ActStruck: (start:  0;     frame: 0;  skip: 0;  ftime: 0;    usetick: 0);
//        ActDie:    (start: 30;     frame: 20; skip: 0;  ftime: 120;  usetick: 0); //²É´«
//        ActDeath:  (start: 30;     frame: 20; skip: 0;  ftime: 150;  usetick: 0);
        ActDie:    (start: 30;     frame: 10; skip: 0;  ftime: 120;  usetick: 0); //µµ±úºñºÒ
        ActDeath:  (start: 30;     frame: 10; skip: 0; ftime: 150;  usetick: 0); //¼ûÀ½..
      );
   MA58: TMonsterAction = (  // ¿ù·É(Ãµ³à)
        ActStand:  (start: 0;      frame: 4;  skip: 6;  ftime: 200;  usetick: 0);
        ActWalk:   (start: 80;     frame: 6;  skip: 4;  ftime: 160;  usetick: 0);
        ActAttack: (start: 160;    frame: 6;  skip: 4;  ftime: 160;  usetick: 0);
        ActCritical:(start:160;    frame: 6;  skip: 4;  ftime: 160;  usetick: 0); // SM_LIGHTING(¸¶¹ý»ç¿ë=>°­°Ý) ¶§ ¾²ÀÓ
        ActStruck: (start: 240;    frame: 2;  skip: 0;  ftime: 150;  usetick: 0);
        ActDie:    (start: 260;    frame: 10; skip: 0;  ftime: 120;  usetick: 0);
        ActDeath:  (start: 340;    frame: 10; skip: 0;  ftime: 100;  usetick: 0);
      );
   MA59: TMonsterAction = (  // FireDragon (È­·æ)
        ActStand:  (start: 0;     frame: 10; skip: 0;  ftime: 300;  usetick: 0);
        ActWalk:   (start: 10;    frame: 6;  skip: 4;  ftime: 150;  usetick: 0);
        ActAttack: (start: 20;    frame: 6;  skip: 4;  ftime: 150;  usetick: 0);
        ActCritical:(start:40;    frame: 10; skip: 0;  ftime: 150;  usetick: 0);
        ActStruck: (start: 40;    frame: 2;  skip: 8;  ftime: 150;  usetick: 0);
        ActDie:    (start: 30;    frame: 6;  skip:  4; ftime: 150;  usetick: 0);
        ActDeath:  (start: 0;     frame: 0;  skip:  0; ftime: 0;    usetick: 0);
      );
   MA60: TMonsterAction = (  // ¿ëÁ¶½Å»ó (¿ë¼®»ó)
        ActStand:  (start: 0;     frame: 10; skip: 0;  ftime: 300;  usetick: 0);
        ActWalk:   (start: 0;     frame: 10; skip: 0;  ftime: 300;  usetick: 0);
        ActAttack: (start: 10;    frame: 10; skip: 0;  ftime: 300;  usetick: 0);
        ActCritical:(start: 10;   frame: 10; skip: 0;  ftime: 100;  usetick: 0);
        ActStruck: (start: 0;     frame: 1;  skip: 9;  ftime: 300;  usetick: 0);
        ActDie:    (start: 0;     frame: 1;  skip: 9;  ftime: 300;  usetick: 0);
        ActDeath:  (start: 0;     frame: 1;  skip: 9;  ftime: 300;    usetick: 0);
      );
   MA61: TMonsterAction = ( // ¸¶·æÀÇÀü°¢ ºÒ²ÉNPC
        ActStand:  (start: 0;    frame: 20; skip: 0;  ftime: 100;  usetick: 0);
        ActWalk:   (start: 0;    frame: 0;  skip: 0;  ftime: 0;    usetick: 0);
        ActAttack: (start: 0;    frame: 0;  skip: 0;  ftime: 0;  usetick: 0);
        ActCritical: (start: 0;   frame: 0; skip: 0;  ftime: 0;  usetick: 0);
        ActStruck: (start: 0;    frame: 0;  skip: 0;  ftime: 0;  usetick: 0);
        ActDie:    (start: 0;    frame: 0;  skip: 0;  ftime: 0;  usetick: 0);
        ActDeath:  (start: 0;    frame: 0;  skip: 0;  ftime: 0;  usetick: 0);
      );
   MA62: TMonsterAction = (  //¼³ÀÎ´ëÃæ,ÁÖ¸¶°Ý·ÚÀå,È¯¿µÇÑÈ£, °Å¹Ì(½Å¼®µ¶¸¶ÁÖ)
        ActStand:  (start: 0;      frame: 4;  skip: 6;  ftime: 250;  usetick: 0);
        ActWalk:   (start: 80;     frame: 6;  skip: 4;  ftime: 100;  usetick: 3); //
        ActAttack: (start: 160;    frame: 6;  skip: 4;  ftime: 110;  usetick: 0);
        ActCritical:(start: 340;   frame: 6;  skip: 4;  ftime: 150;  usetick: 0);
        ActStruck: (start: 240;    frame: 2;  skip: 0;  ftime: 120;  usetick: 0);
        ActDie:    (start: 260;    frame: 10; skip: 0;  ftime: 90;   usetick: 0);
        ActDeath:  (start: 420;    frame: 1;  skip: 0;  ftime: 140;  usetick: 0); //
      );
   MA63: TMonsterAction = (  //º¸¹°ÇÔ
        ActStand:  (start: 0;      frame: 2;  skip: 8;  ftime: 1000;  usetick: 0);
        ActWalk:   (start: 0;      frame: 2;  skip: 8;  ftime: 1000;  usetick: 0);
        ActAttack: (start: 0;      frame: 2;  skip: 8;  ftime: 1000;  usetick: 0);
        ActCritical:(start: 0;     frame: 2;  skip: 8;  ftime: 1000;  usetick: 0);
        ActStruck: (start: 10;     frame: 6;  skip: 4;  ftime: 150;   usetick: 0);
        ActDie:    (start: 20;     frame: 2;  skip: 8;  ftime: 1000;  usetick: 0);
        ActDeath:  (start: 20;     frame: 2;  skip: 8;  ftime: 1000;  usetick: 0);
      );
   MA64: TMonsterAction = (  //È£È¥¼®(ÇÊµå)
        ActStand:  (start: 0;      frame: 4;  skip: 6;  ftime: 200;  usetick: 0);
        ActWalk:   (start: 10;     frame: 4;  skip: 6;  ftime: 200;  usetick: 0); //µîÀå...
        ActAttack: (start: 20;     frame: 6;  skip: 4;  ftime: 120;  usetick: 0);
        ActCritical:(start:20;     frame: 6;  skip: 4;  ftime: 120;  usetick: 0);
        ActStruck: (start: 30;     frame: 2;  skip: 8;  ftime: 100;  usetick: 0);
        ActDie:    (start: 40;     frame: 10; skip: 0;  ftime: 120;  usetick: 0);
        ActDeath:  (start: 40;     frame: 10; skip: 0;  ftime: 120;  usetick: 0); //¼ûÀ½..
      );
   MA65: TMonsterAction = (  //È£±â¿¬
        ActStand:  (start: 0;      frame: 10; skip: 0;  ftime: 150;  usetick: 0);
        ActWalk:   (start: 10;     frame: 10; skip: 0;  ftime: 150;  usetick: 0);
        ActAttack: (start: 20;     frame: 10; skip: 0;  ftime: 150;  usetick: 0);
        ActCritical:(start:20;     frame: 10; skip: 0;  ftime: 150;  usetick: 0);
        ActStruck: (start: 30;     frame: 4;  skip: 6;  ftime: 100;  usetick: 0);
        ActDie:    (start: 40;     frame: 10; skip: 0;  ftime: 150;  usetick: 0);
        ActDeath:  (start: 40;     frame: 10; skip: 0;  ftime: 150;  usetick: 0);
      );
   MA66: TMonsterAction = (  //ºñ¿ùÃµÁÖ
        ActStand:  (start: 0;     frame: 20;  skip: 0;  ftime: 150;  usetick: 0);
        ActWalk:   (start: 0;     frame: 20;  skip: 0;  ftime: 150;  usetick: 3);
        ActAttack: (start: 20;    frame: 10;  skip: 0;  ftime: 150;  usetick: 0);
        ActCritical:(start:20;    frame: 10;  skip: 0;  ftime: 150;  usetick: 0);
        ActStruck: (start: 30;    frame: 2;   skip: 8;  ftime: 100;  usetick: 0);
        ActDie:    (start: 400;   frame: 18;  skip: 0;  ftime: 150;  usetick: 0);
        ActDeath:  (start: 400;   frame: 18;  skip: 0;  ftime: 150;  usetick: 0);
      );
   MA67: TMonsterAction = (  //È£È¥±â¼®
        ActStand:  (start: 0;     frame: 4;   skip: 6;  ftime: 150;  usetick: 0);
        ActWalk:   (start: 0;     frame: 4;   skip: 6;  ftime: 150;  usetick: 3);
        ActAttack: (start: 10;    frame: 4;   skip: 6;  ftime: 300;  usetick: 0);
        ActCritical:(start:10;    frame: 4;   skip: 6;  ftime: 300;  usetick: 0);
        ActStruck: (start: 0;     frame: 4;   skip: 6;  ftime: 150;  usetick: 0);
        ActDie:    (start: 0;     frame: 4;   skip: 6;  ftime: 300;  usetick: 0);
        ActDeath:  (start: 0;     frame: 4;   skip: 6;  ftime: 300;  usetick: 0);
      );
   MA68: TMonsterAction = (  //NPC 3¹æÇâ ¼­ÀÖ±â ¸ð¼Ç¸¸
        ActStand:  (start: 0;     frame: 4;   skip: 6;  ftime: 150;  usetick: 0);
        ActWalk:   (start: 0;     frame: 4;   skip: 6;  ftime: 150;  usetick: 3);
        ActAttack: (start: 0;     frame: 4;   skip: 6;  ftime: 150;  usetick: 0);
        ActCritical:(start:0;     frame: 4;   skip: 6;  ftime: 150;  usetick: 0);
        ActStruck: (start: 0;     frame: 4;   skip: 6;  ftime: 150;  usetick: 0);
        ActDie:    (start: 0;     frame: 4;   skip: 6;  ftime: 150;  usetick: 0);
        ActDeath:  (start: 0;     frame: 4;   skip: 6;  ftime: 150;  usetick: 0);
      );
   MA69: TMonsterAction = (  //¶±
        ActStand:  (start: 0;     frame: 4;   skip: 6;  ftime: 150;  usetick: 0);
        ActWalk:   (start: 0;     frame: 4;   skip: 6;  ftime: 150;  usetick: 0);
        ActAttack: (start: 0;     frame: 4;   skip: 6;  ftime: 150;  usetick: 0);
        ActCritical:(start:0;     frame: 10;  skip: 0;  ftime: 150;  usetick: 0);
        ActStruck: (start: 10;    frame: 2;   skip: 8;  ftime: 150;  usetick: 0);
        ActDie:    (start: 20;    frame: 6;   skip: 4;  ftime: 150;  usetick: 0);
        ActDeath:  (start: 20;    frame: 6;   skip: 4;  ftime: 150;  usetick: 0);
      );

  WORDER: array[0..1, 0..2999] of byte =(//1: Ä®ÀÌ ¾ÕÀ¸·Î,  0: Ä®ÀÌ µÚ·Î
    (                                   //³²ÀÚ
      //Õ¾Á¢
    0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1,
    1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1, 1, 1, 1, 1, 1,
    0, 0, 0, 0, 1, 1, 1, 1, 1, 1, 0, 0, 0, 0, 1, 1, 1, 1, 1, 1, {0..79}
      //¿ÕÍ¼Æ¬
    0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
    0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
    0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, {80..159}
      //Î´Öª¶¯×÷{5ÕÅÍ¼Æ¬}
    0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1,
    1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1, 1, 1, 1, 1, 1,
    0, 0, 0, 0, 1, 1, 1, 1, 1, 1, 0, 0, 0, 0, 1, 1, 1, 1, 1, 1, {160..239}
      //Î´Öª¶¯×÷{5ÕÅÍ¼Æ¬}
    0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1,
    1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1, 1, 1, 1, 1, 1,
    0, 0, 0, 0, 1, 1, 1, 1, 1, 1, 0, 0, 0, 0, 1, 1, 1, 1, 1, 1, {240..319}
      //µ²(1ÕÅÍ¼)
    0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1,
    1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1, 1, 1, 1, 1, 1,
    0, 0, 0, 0, 1, 1, 1, 1, 1, 1, 0, 0, 0, 0, 1, 1, 1, 1, 1, 1, {320..399}
      //Î´Öª¶¯×÷(1ÕÅÍ¼)
    0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1,
    1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1, 1, 1, 1, 1, 1,
    0, 0, 0, 0, 1, 1, 1, 1, 1, 1, 0, 0, 0, 0, 1, 1, 1, 1, 1, 1, {400..479}
      //Î´Öª¶¯×÷(1ÕÅÍ¼)
    0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1,
    1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1, 1, 1, 1, 1, 1,
    0, 0, 0, 0, 1, 1, 1, 1, 1, 1, 0, 0, 0, 0, 1, 1, 1, 1, 1, 1, {480..559}
      //×¼±¸¹¥»÷(3ÕÅÍ¼)
    0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1,
    1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1, 1, 1, 1, 1, 1, 1,
    0, 0, 0, 1, 1, 1, 1, 1, 1, 1, 0, 0, 0, 1, 1, 1, 1, 1, 1, 1, {560..639}
      //ÌÍÈâ¶¯×÷(2ÕÅÍ¼)
    0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1, 0, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 0, 0, 0, 0, 0, 0, 0, 0,
    1, 1, 0, 0, 0, 0, 0, 0, 0, 0, 1, 1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
    0, 1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, {640..719}
      //¹¥»÷
    1, 1, 1, 0, 0, 0, 1, 1, 1, 1, 1, 1, 1, 0, 0, 0, 0, 0, 0, 0, 1, 1, 1, 0, 0, 0, 0, 0, 0, 0,
    1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 0, 0, 0, 0, 0, 0, 0,
    0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1, 1, 1, 1, 0, 0, 1, 1, 1, 1, {720..799}
      //¿ÕÍ¼Æ¬
    0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
    0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
    0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, {800..879}
      //Î´Öª¶¯×÷(6ÕÅÍ¼Æ¬)
    0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
    0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
    0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, {880..959}
      //¿ÕÍ¼Æ¬
    0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
    0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
    0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, {960..1039}
    0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
    0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
    0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, {1040..1119}
    0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
    0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
    0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, {1020..1199}
      //ºóÑö
    0, 0, 0, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1,
    1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 0, 0, 0, 1, 1, 1, 1, 1, 1, 1, 0, 0, 0, 1, 1, 1, 1, 1, 1, 1,
    0, 0, 0, 1, 1, 1, 1, 1, 1, 1, 0, 0, 0, 1, 1, 1, 1, 1, 1, 1, {1200..1279}
      //Î´Öª¶¯×÷(10Í¼Æ¬)
    0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
    0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
    0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, {1280..1359}
      //Î´Öª¶¯×÷(10Í¼Æ¬)
    0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
    0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
    0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, {1360..1439}
      //ÌßÍÈ¶¯×÷(10Í¼Æ¬)
    0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
    0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
    0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, {1440..1519}
      //ËÀÍö¶¯×÷(10Í¼Æ¬)
    0, 0, 1, 1, 1, 1, 1, 1, 1, 1, 0, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1,
    1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 0, 0, 0, 1, 1, 1, 1, 1, 1, 1, 0, 0, 0, 1, 1, 1, 1, 1, 1, 1,
    0, 0, 0, 1, 1, 1, 1, 1, 1, 1, 0, 0, 0, 1, 1, 1, 1, 1, 1, 1, {1520..1599}
      //¿ÕÍ¼Æ¬
    0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
    0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
    0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, {1600..1679}
      //×ßÂ·
    0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1,
    1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 0, 0, 0, 1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1,
    0, 0, 0, 0, 0, 0, 0, 0, 0, 1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1, {1680..1759}

      //ÅÜ
    0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1,
    1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 0, 0, 1, 1, 1, 1, 1, 1, 1, 1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
    0, 0, 0, 0, 0, 0, 0, 0, 0, 1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1, {1760..1839}
      //´Ì¿ÍÅÜ
    0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1,
    1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 0, 0, 1, 1, 1, 1, 1, 1, 1, 1, 0, 0, 1, 1, 1, 0, 0, 1, 1, 1,
    0, 0, 0, 0, 0, 0, 0, 0, 0, 1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1, {1840..1919}
      //¿ÕÍ¼Æ¬
    0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
    0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
    0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, {1920..1999}
      //¿ÕÍ¼Æ¬
    0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
    0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
    0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, {2000..2079}
      //¿ÕÍ¼Æ¬
    0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
    0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
    0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, {2080..2159}
      //¿ÕÍ¼Æ¬
    0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
    0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
    0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, {2160..2239}
      //¿ÕÍ¼Æ¬
    0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
    0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
    0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, {2240..2319}
      //ÆïÂí²»¶¯
    0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
    0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
    0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, {2320..2399}
      //ÆïÂí×ß
    0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
    0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
    0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, {2400..2479}
      //ÆïÂíÅÜ
    0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
    0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
    0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, {2480..2559}
      //ÂíÉÏºóÑö
    0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
    0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
    0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, {2560..2639}
      //¿ÕÍ¼Æ¬
    0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
    0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
    0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, {2640..2719}
      //¿ÕÍ¼Æ¬
    0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
    0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
    0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, {2720..2799}
      //¿ÕÍ¼Æ¬
    0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
    0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
    0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, {2800..2879}
      //¿ÕÍ¼Æ¬
    0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
    0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
    0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, {2880..2959}
      //¿ÕÍ¼Æ¬
    0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
    0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0 {2960..2999}
    ),

    (
      //Õ¾Á¢
    0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1,
    1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1, 1, 1, 1, 1, 1,
    0, 0, 0, 0, 1, 1, 1, 1, 1, 1, 0, 0, 0, 0, 1, 1, 1, 1, 1, 1, {0..79}
      //¿ÕÍ¼Æ¬
    0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
    0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
    0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, {80..159}
      //Î´Öª¶¯×÷{5ÕÅÍ¼Æ¬}
    0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1,
    1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1, 1, 1, 1, 1, 1,
    0, 0, 0, 0, 1, 1, 1, 1, 1, 1, 0, 0, 0, 0, 1, 1, 1, 1, 1, 1, {160..239}
      //Î´Öª¶¯×÷{5ÕÅÍ¼Æ¬}
    0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1,
    1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1, 1, 1, 1, 1, 1,
    0, 0, 0, 0, 1, 1, 1, 1, 1, 1, 0, 0, 0, 0, 1, 1, 1, 1, 1, 1, {240..319}
      //µ²(1ÕÅÍ¼)
    0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1,
    1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1, 1, 1, 1, 1, 1,
    0, 0, 0, 0, 1, 1, 1, 1, 1, 1, 0, 0, 0, 0, 1, 1, 1, 1, 1, 1, {320..399}
      //Î´Öª¶¯×÷(1ÕÅÍ¼)
    0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1,
    1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1, 1, 1, 1, 1, 1,
    0, 0, 0, 0, 1, 1, 1, 1, 1, 1, 0, 0, 0, 0, 1, 1, 1, 1, 1, 1, {400..479}
      //Î´Öª¶¯×÷(1ÕÅÍ¼)
    0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1,
    1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1, 1, 1, 1, 1, 1,
    0, 0, 0, 0, 1, 1, 1, 1, 1, 1, 0, 0, 0, 0, 1, 1, 1, 1, 1, 1, {480..559}
      //×¼±¸¹¥»÷(3ÕÅÍ¼)
    0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1,
    1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1, 1, 1, 1, 1, 1, 1,
    0, 0, 0, 1, 1, 1, 1, 1, 1, 1, 0, 0, 0, 1, 1, 1, 1, 1, 1, 1, {560..639}
      //ÌÍÈâ¶¯×÷(2ÕÅÍ¼)
    0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1, 0, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 0, 0, 0, 0, 0, 0, 0, 0,
    1, 1, 0, 0, 0, 0, 0, 0, 0, 0, 1, 1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
    0, 1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, {640..719}
      //¹¥»÷
    1, 1, 1, 0, 0, 0, 1, 1, 1, 1, 1, 1, 1, 0, 0, 0, 0, 0, 0, 0, 1, 1, 1, 0, 0, 0, 0, 0, 0, 0,
    1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 0, 0, 0, 0, 0, 0, 0,
    0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1, 1, 1, 1, 0, 0, 1, 1, 1, 1, {720..799}
      //¿ÕÍ¼Æ¬
    0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
    0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
    0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, {800..879}
      //Î´Öª¶¯×÷(6ÕÅÍ¼Æ¬)
    0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
    0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
    0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, {880..959}
      //¿ÕÍ¼Æ¬
    0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
    0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
    0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, {960..1039}
    0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
    0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
    0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, {1040..1119}
    0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
    0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
    0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, {1020..1199}
      //ºóÑö
    0, 0, 0, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1,
    1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 0, 0, 0, 1, 1, 1, 1, 1, 1, 1, 0, 0, 0, 1, 1, 1, 1, 1, 1, 1,
    0, 0, 0, 1, 1, 1, 1, 1, 1, 1, 0, 0, 0, 1, 1, 1, 1, 1, 1, 1, {1200..1279}
      //Î´Öª¶¯×÷(10Í¼Æ¬)
    0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
    0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
    0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, {1280..1359}
      //Î´Öª¶¯×÷(10Í¼Æ¬)
    0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
    0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
    0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, {1360..1439}
      //ÌßÍÈ¶¯×÷(10Í¼Æ¬)
    0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
    0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
    0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, {1440..1519}
      //ËÀÍö¶¯×÷(10Í¼Æ¬)
    0, 0, 1, 1, 1, 1, 1, 1, 1, 1, 0, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1,
    1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 0, 0, 0, 1, 1, 1, 1, 1, 1, 1, 0, 0, 0, 1, 1, 1, 1, 1, 1, 1,
    0, 0, 0, 1, 1, 1, 1, 1, 1, 1, 0, 0, 0, 1, 1, 1, 1, 1, 1, 1, {1520..1599}
      //¿ÕÍ¼Æ¬
    0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
    0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
    0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, {1600..1679}
      //×ßÂ·
    0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1,
    1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1,
    0, 0, 0, 0, 0, 0, 0, 0, 0, 1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1, {1680..1759}

      //ÅÜ
    0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1,
    1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 0, 0, 1, 1, 1, 1, 1, 1, 1, 1, 0, 0, 1, 1, 1, 0, 0, 1, 1, 1,
    0, 0, 0, 0, 0, 0, 0, 0, 0, 1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1, {1760..1839}
      //´Ì¿ÍÅÜ
    0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1,
    1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 0, 0, 1, 1, 1, 1, 1, 1, 1, 1, 0, 0, 1, 1, 1, 0, 0, 1, 1, 1,
    0, 0, 0, 0, 0, 0, 0, 0, 0, 1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1, {1840..1919}
      //¿ÕÍ¼Æ¬
    0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
    0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
    0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, {1920..1999}
      //¿ÕÍ¼Æ¬
    0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
    0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
    0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, {2000..2079}
      //¿ÕÍ¼Æ¬
    0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
    0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
    0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, {2080..2159}
      //¿ÕÍ¼Æ¬
    0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
    0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
    0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, {2160..2239}
      //¿ÕÍ¼Æ¬
    0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
    0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
    0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, {2240..2319}
      //ÆïÂí²»¶¯
    0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
    0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
    0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, {2320..2399}
      //ÆïÂí
    0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
    0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
    0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, {2400..2479}
      //ÆïÂí
    0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
    0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
    0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, {2480..2559}
      //ÂíÉÏºóÑö
    0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
    0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
    0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, {2560..2639}
      //¿ÕÍ¼Æ¬
    0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
    0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
    0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, {2640..2719}
      //¿ÕÍ¼Æ¬
    0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
    0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
    0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, {2720..2799}
      //¿ÕÍ¼Æ¬
    0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
    0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
    0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, {2800..2879}
      //¿ÕÍ¼Æ¬
    0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
    0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
    0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, {2880..2959}
      //¿ÕÍ¼Æ¬
    0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
    0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0 {2960..2999}
    )
    );

{   WORDER: Array[0..1, 0..599] of byte = (  //1: Ä®ÀÌ ¾ÕÀ¸·Î,  0: Ä®ÀÌ µÚ·Î
      (       //³²ÀÚ
      //Á¤Áö
      0,0,0,0,0,0,0,0,    1,1,1,1,1,1,1,1,    1,1,1,1,1,1,1,1,
      1,1,1,1,1,1,1,1,    0,0,0,0,0,0,0,0,    0,0,0,0,1,1,1,1,
      0,0,0,0,1,1,1,1,    0,0,0,0,1,1,1,1,
      //°È±â
      0,0,0,0,0,0,0,0,    1,1,1,1,1,1,1,1,    1,1,1,1,1,1,1,1,
      1,1,1,1,1,1,1,1,    0,0,0,0,0,0,0,0,    0,0,0,0,0,0,0,1,
      0,0,0,0,0,0,0,1,    0,0,0,0,0,0,0,1,
      //¶Ù±â
      0,0,0,0,0,0,0,0,    1,1,1,1,1,1,1,1,    1,1,1,1,1,1,1,1,
      1,1,1,1,1,1,1,1,    0,0,1,1,1,1,1,1,    0,0,1,1,1,0,0,1,
      0,0,0,0,0,0,0,1,    0,0,0,0,0,0,0,1,
      //war¸ðµå
      0,1,1,1,0,0,0,0,
      //°ø°Ý
      1,1,1,0,0,0,1,1,    1,1,1,0,0,0,0,0,    1,1,1,0,0,0,0,0,
      1,1,1,1,1,1,1,1,    1,1,1,1,1,1,1,1,    1,1,1,0,0,0,0,0,
      0,0,0,0,0,0,0,0,    1,1,1,1,0,0,1,1,
      //°ø°Ý 2
      0,1,1,0,0,0,1,1,    0,1,1,0,0,0,1,1,    1,1,1,0,0,0,0,0,
      1,1,1,0,0,1,1,1,    1,1,1,1,1,1,1,1,    0,1,1,1,1,1,1,1,
      0,0,0,1,1,1,0,0,    0,1,1,1,1,0,1,1,
      //°ø°Ý3
      1,1,0,1,0,0,0,0,    1,1,0,0,0,0,0,0,    1,1,1,1,1,0,0,0,
      1,1,0,0,1,0,0,0,    1,1,1,0,0,0,0,1,    0,1,1,0,0,0,0,0,
      0,0,0,0,1,1,1,0,    1,1,1,1,1,0,0,0,
      //¸¶¹ý
      0,0,0,0,0,0,1,1,    0,0,0,0,0,0,1,1,    0,0,0,0,0,0,1,1,
      1,0,0,0,0,1,1,1,    1,1,1,1,1,1,1,1,    0,1,1,1,1,1,1,1,
      0,0,1,1,0,0,1,1,    0,0,0,1,0,0,1,1,
      //Ø±â
      0,0,1,0,1,1,1,1,    1,1,0,0,0,1,0,0,
      //¸Â±â
      0,0,0,1,1,1,1,1,    1,1,1,1,1,1,1,1,    1,1,1,1,1,1,1,1,
      1,1,1,1,1,1,1,1,    0,0,0,1,1,1,1,1,    0,0,0,1,1,1,1,1,
      0,0,0,1,1,1,1,1,    0,0,0,1,1,1,1,1,
      //¾²·¯Áü
      0,0,1,1,1,1,1,1,    0,1,1,1,1,1,1,1,    1,1,1,1,1,1,1,1,
      1,1,1,1,1,1,1,1,    0,0,0,1,1,1,1,1,    0,0,0,1,1,1,1,1,
      0,0,0,1,1,1,1,1,    0,0,0,1,1,1,1,1
      ),

      (
      //Á¤Áö
      0,0,0,0,0,0,0,0,    1,1,1,1,1,1,1,1,    1,1,1,1,1,1,1,1,
      1,1,1,1,1,1,1,1,    0,0,0,0,0,0,0,0,    0,0,0,0,1,1,1,1,
      0,0,0,0,1,1,1,1,    0,0,0,0,1,1,1,1,
      //°È±â
      0,0,0,0,0,0,0,0,    1,1,1,1,1,1,1,1,    1,1,1,1,1,1,1,1,
      1,1,1,1,1,1,1,1,    0,0,0,0,0,0,0,0,    0,0,0,0,0,0,0,1,
      0,0,0,0,0,0,0,1,    0,0,0,0,0,0,0,1,
      //¶Ù±â
      0,0,0,0,0,0,0,0,    1,1,1,1,1,1,1,1,    1,1,1,1,1,1,1,1,
      1,1,1,1,1,1,1,1,    0,0,1,1,1,1,1,1,    0,0,1,1,1,0,0,1,
      0,0,0,0,0,0,0,1,    0,0,0,0,0,0,0,1,
      //war¸ðµå
      1,1,1,1,0,0,0,0,
      //°ø°Ý
      1,1,1,0,0,0,1,1,    1,1,1,0,0,0,0,0,    1,1,1,0,0,0,0,0,
      1,1,1,1,1,1,1,1,    1,1,1,1,1,1,1,1,    1,1,1,0,0,0,0,0,
      0,0,0,0,0,0,0,0,    1,1,1,1,0,0,1,1,
      //°ø°Ý 2
      0,1,1,0,0,0,1,1,    0,1,1,0,0,0,1,1,    1,1,1,0,0,0,0,0,
      1,1,1,0,0,1,1,1,    1,1,1,1,1,1,1,1,    0,1,1,1,1,1,1,1,
      0,0,0,1,1,1,0,0,    0,1,1,1,1,0,1,1,
      //°ø°Ý3
      1,1,0,1,0,0,0,0,    1,1,0,0,0,0,0,0,    1,1,1,1,1,0,0,0,
      1,1,0,0,1,0,0,0,    1,1,1,0,0,0,0,1,    0,1,1,0,0,0,0,0,
      0,0,0,0,1,1,1,0,    1,1,1,1,1,0,0,0,
      //¸¶¹ý
      0,0,0,0,0,0,1,1,    0,0,0,0,0,0,1,1,    0,0,0,0,0,0,1,1,
      1,0,0,0,0,1,1,1,    1,1,1,1,1,1,1,1,    0,1,1,1,1,1,1,1,
      0,0,1,1,0,0,1,1,    0,0,0,1,0,0,1,1,
      //Ø±â
      0,0,1,0,1,1,1,1,    1,1,0,0,0,1,0,0,
      //¸Â±â
      0,0,0,1,1,1,1,1,    1,1,1,1,1,1,1,1,    1,1,1,1,1,1,1,1,
      1,1,1,1,1,1,1,1,    0,0,0,1,1,1,1,1,    0,0,0,1,1,1,1,1,
      0,0,0,1,1,1,1,1,    0,0,0,1,1,1,1,1,
      //¾²·¯Áü
      0,0,1,1,1,1,1,1,    0,1,1,1,1,1,1,1,    1,1,1,1,1,1,1,1,
      1,1,1,1,1,1,1,1,    0,0,0,1,1,1,1,1,    0,0,0,1,1,1,1,1,
      0,0,0,1,1,1,1,1,    0,0,0,1,1,1,1,1
      )
   ); }

   EffDir : array[0..7] of byte = (0, 0, 1, 1, 1, 1, 1, 0);


type
   TActor = class
      RecogId: integer;
      XX:   word;
      YY:   word;
      Dir:  byte;
      Sex:  byte;
      Race:    byte;
      Hair:    byte;
      Dress:   byte;
      Weapon:  byte;
      Job:  byte; //Á÷¾÷ 0:Àü»ç  1:¼ú»ç  2:µµ»ç
      Appearance: word;
//      DeathState: byte;
      Feature: integer;
      State:   integer;
      Death: Boolean;
      Skeleton: Boolean;
      BoDelActor: Boolean;
      BoDelActionAfterFinished: Boolean;
      DescUserName: string;
      FameName: string;
      UserName: string;
      NameColor: integer;
      Abil: TAbility;
      Gold: integer;
      HitSpeed: shortint; //°ø°Ý¼Óµµ 0: ±âº», (-)´À¸² (+)ºü¸§
      Visible: Boolean;
      BoHoldPlace: Boolean;

      Saying: array[0..MAXSAY-1] of string;
      SayWidths: array[0..MAXSAY-1] of integer;
      SayTime: longword;
      SayX, SayY: integer;
      SayLineCount: integer;

      ShiftX:  integer;
      ShiftY:  integer;

      px:   integer;
      py:   integer;
      spx:   integer;
      spy:   integer;
      stype:   integer;
      Rx, Ry: integer;
      DownDrawLevel: integer;  //¸î ¼¿ ÀÌÀü¿¡ ±×¸®°Ô ÇÔ...
      TargetX, TargetY: integer; //¸ó½ºÅÍÀÎ °æ¿ì, ´øÁö´Â °ø°ÝÀ» ÇÏ´Â °æ¿ì Å¸°ÝÀÇ À§Ä¡
      TargetRecog: integer; //
      HiterCode: integer;
      MagicNum: integer;
      CurrentEvent: integer; //¼­¹öÀÇ ÀÌº¥Æ® ¾ÆÀÌµð
      BoDigFragment: Boolean;  //ÀÌ¹ø °î±ªÀÌ ÁúÀÌ Ä³Á³´ÂÁö..
      BoThrow: Boolean;

      BodyOffset, HairOffset, WingOffset, WeaponOffset, WeaponEffectOffset: integer;
      BoUseMagic: Boolean;
      BoHitEffect: Boolean;
      BoUseEffect: Boolean;  //È¿°ú¸¦ »ç¿ëÇÏ´ÂÁö..
      HitEffectNumber: integer;
      WaitMagicRequest: longword;
      WaitForRecogId: integer;  //ÀÚ½ÅÀÌ »ç¶óÁö¸é WaitForÀÇ actor¸¦ visible ½ÃÅ²´Ù.
      WaitForFeature: integer;
      WaitForStatus: integer;
      //BoEatEffect: Boolean;  //¾à ¸Ô´Â È¿°ú
      //EatEffectFrame: integer;
      //EatEffectTime: longword;

      CurEffFrame: integer;
      SpellFrame: integer; //¸¶¹ýÀÇ ½ÃÀü ÇÁ·¡ÀÓ
      CurMagic: TUseMagicInfo;
      //GlimmingMode: Boolean;
      //CurGlimmer: integer;
      //MaxGlimmer: integer;
      //GlimmerTime: longword;
      GenAniCount: integer;
      BoOpenHealth: Boolean;
      BoInstanceOpenHealth: Boolean;
      OpenHealthStart: longword;
      OpenHealthTime: integer;

      //SRc: TRect;  //Screen Rect È­¸éÀÇ ½ÇÁ¦ÁÂÇ¥(¸¶¿ì½º ±âÁØ)
      BodySurface: TDirectDrawSurface;
      ShadowSurface: TDirectDrawSurface;

      Grouped: Boolean; //³ª¿Í ±×·ìÀÎ »ç¶÷
      CurrentAction: integer;
      ReverseFrame: Boolean;
      WarMode: Boolean;
      WarModeTime: longword;
      ChrLight: integer;
      MagLight: integer;
      RushDir: integer;  //0, 1 ÇÑ¹øÀº ¿ÞÂÊ ÇÑ¹øÀº ¿À¸¥ÂÊ

      WalkFrameDelay: integer;  //±âº» °ªÀº Å¬¶óÀÌ¾ðÆ®ÀÇ ftime ÀÌ¸é
                                //¼­¹ö¿¡¼­ ¹ÞÀ¸¸é ¼­¹ö¿¡¼­ ¹ÞÀº °ªÀ¸·Î ÇÑ´Ù.

      LockEndFrame: Boolean;
      LastStruckTime: longword;
      SendQueryUserNameTime: longword;
      DeleteTime: longword;

      //»ç¿îµå È¿°ú
      MagicStruckSound: integer;
      borunsound: Boolean;
      footstepsound: integer;  //ÁÖÀÎ°øÀÎ°æ¿ì, CM_WALK, CM_RUN
      strucksound: integer;  //¸ÂÀ»¶§ ³ª´Â ¼Ò¸®    SM_STRUCK
      struckweaponsound: integer;

      appearsound: integer;  //µîÀå¼Ò¸® 0
      normalsound: integer;  //ÀÏ¹Ý¼Ò¸® 1
      attacksound: integer;  //         2
      weaponsound: integer; //          3
      screamsound: integer;  //         4
      diesound: integer;     //Á×À»¶§   5  ³ª´Â ¼Ò¸®    SM_DEATHNOW
      die2sound: integer;

      magicstartsound: integer;
      magicfiresound: integer;
      magicexplosionsound: integer;

      Bo50LevelEffect: Boolean;
      FoodStickType: integer;
//      BoWriterEffect: Boolean;
      TempState:   byte; //ºñ¿ùÃµÁÖ ÇöÁ¦ »óÅÂ

   private
   protected
      startframe: integer;
      endframe: integer;
      currentframe: integer;
      effectstart: integer;
      effectframe: integer;
      effectend: integer;
      effectstarttime: longword;
      effectframetime: longword;
      frametime: longword;   //ÇÑ ÇÁ·¡ÀÓ´ç ½Ã°£
      starttime: longword;   //ÃÖ±ÙÀÇ ÇÁ·¡ÀÓÀ» ÂïÀº ½Ã°£
      maxtick: integer;
      curtick: integer;
      movestep: integer;
      msgmuch: Boolean;
      struckframetime: longword;
      currentdefframe: integer;
      defframetime: longword;
      defframecount: integer;
      SkipTick, SkipTick2: integer;
      smoothmovetime: longword;
      genanicounttime: longword;
      loadsurfacetime: longword;

      oldx, oldy, olddir: integer;
      actbeforex, actbeforey: integer;  //Çàµ¿ ÀüÀÇ ÁÂÇ¥
      wpord: integer;

      procedure CalcActorFrame; dynamic;
      procedure DefaultMotion; dynamic;
      function  GetDefaultFrame (wmode: Boolean): integer; dynamic;
      procedure DrawEffSurface (dsurface, source: TDirectDrawSurface; ddx, ddy: integer; blend: Boolean; ceff: TColorEffect);
      procedure DrawWeaponGlimmer (dsurface: TDirectDrawSurface; ddx, ddy: integer);
   public
      MsgList: TList;       //list of PTChrMsg
      RealActionMsg: TChrMsg; //FrmMain¿¡¼­ »ç¿ëÇÔ

      constructor Create; dynamic;
      destructor Destroy; override;
      procedure  SendMsg (ident: word; x, y, cdir, feature, state: integer; str: string; sound: integer);
      procedure  UpdateMsg (ident: word; x, y, cdir, feature, state: integer; str: string; sound: integer);
      procedure  CleanUserMsgs;
      procedure  ProcMsg;
      procedure  ProcHurryMsg;
      function   IsIdle: Boolean;
      function   ActionFinished: Boolean;
      function   CanWalk: Integer;
      function   CanRun: Integer;
      function   Strucked: Boolean;
      procedure  Shift (dir, step, cur, max: integer);
      procedure  ReadyAction (msg: TChrMsg);
      function   CharWidth: Integer;
      function   CharHeight: Integer;
      function   CheckSelect (dx, dy: integer): Boolean;
      procedure  CleanCharMapSetting (x, y: integer);
      procedure  Say (str: string);
      procedure  SetSound; dynamic;
      procedure  Run; dynamic;
      procedure  RunSound; dynamic;
      procedure  RunActSound (frame: integer); dynamic;
      procedure  RunFrameAction (frame: integer); dynamic;  //ÇÁ·¡ÀÓ¸¶´Ù µ¶Æ¯ÇÏ°Ô ÇØ¾ßÇÒÀÏ
      procedure  ActionEnded; dynamic;
      function   Move (step: integer; out boChange: Boolean): Boolean;
      procedure  MoveFail;
      function   CanCancelAction: Boolean;
      procedure  CancelAction;
      procedure  FeatureChanged; dynamic;
      function   Light: integer; dynamic;
      procedure  LoadSurface; dynamic;
      function   GetDrawEffectValue: TColorEffect;
      procedure  DrawChr (dsurface: TDirectDrawSurface; dx, dy: integer; blend: Boolean; WingDraw: Boolean ); dynamic;
      procedure  DrawEff (dsurface: TDirectDrawSurface; dx, dy: integer); dynamic;
   end;


   TNpcActor = class (TActor)
   private
      // 2003/07/15 ½Å±Ô NPC Ãß°¡
      ax, ay: integer;
      PlaySnow: Boolean;
      SnowStartTime: longword;
      EffectSurface: TDirectDrawSurface;
   public
      constructor Create; override;
      procedure  Run; override;
      procedure  CalcActorFrame; override;
      function   GetDefaultFrame (wmode: Boolean): integer; override;
      procedure  LoadSurface; override;
      // 2003/07/15 ½Å±Ô NPC Ãß°¡
      procedure  DrawChr (dsurface: TDirectDrawSurface; dx, dy: integer; blend: Boolean; WingDraw: Boolean ); override;
      procedure  DrawEff (dsurface: TDirectDrawSurface; dx, dy: integer); override;
   end;

   THumActor = class (TActor)
   private
      HairSurface: TDirectDrawSurface;
      WeaponSurface: TDirectDrawSurface;
      WingSurface: TDirectDrawSurface;
      BoWeaponEffect: Boolean;  //¹«±â Á¦·Ã¼º°ø,±úÁü È¿°ú
      CurWpEffect: integer;
      CurBubbleStruck: integer;
      wpeffecttime: longword;
      BoHideWeapon: Boolean;

      hpx, epx, epx2, epx3, epx4, wpx, wpx2:   integer;
      hpy, epy, epy2, epy3, epy4, wpy, wpy2:   integer;

      wstype:   integer;
      wspx:   integer;
      wspy:   integer;
      WingCurrentFrame   : integer;
      WingStartTime   : longword;
      WingFrameTime   : longword;              // ÇÁ·¡ÀÓ °¹¼ö
      // 50Level Effect
      H50LevelEffectSurface: TDirectDrawSurface;
      H50LevelEffectOffset: integer;
      H50LevelEffectCurrentFrame   : integer;
      H50LevelEffectStartTime   : longword;
      H50LevelEffectFrameTime   : longword;
      Bo50LevelHEffect: Boolean;

      // »©»©·Î Event
      FoodStickDayEffectSurface: TDirectDrawSurface;
      FoodStickDayEffectSurface2: TDirectDrawSurface;
      FoodStickDayEffectOffset: integer;
      FoodStickDayEffectOffset2: integer;
      FoodStickDayEffectCurrentFrame   : integer;
      FoodStickDayEffectStartTime   : longword;
      FoodStickDayEffectFrameTime   : longword;
      BoFoodStickDayEffect: Boolean;

      // Writer Effect
{      HWriterEffectSurface: TDirectDrawSurface;
      HWriterEffectOffset: integer;
      HWriterEffectCurrentFrame   : integer;
      HWriterEffectStartTime   : longword;
      HWriterEffectFrameTime   : longword;
      BoWriterHEffect: Boolean;}
      // °øÆÄ¼¶
      SKillCurrentFrame   : integer;
      SKillStartTime   : longword;
      SKillFrameTime   : longword;
      // 50LevelDress Effect
      Bo50DressHEffect: Boolean;

      WeaponEffectSurface: TDirectDrawSurface; //ÆÄ°üÁø°Ë
      WeaponEffectCurrentFrame   : integer;
      WeaponEffectStartTime   : longword;
      WeaponEffectFrameTime   : longword;

   protected
      procedure CalcActorFrame; override;
      procedure DefaultMotion; override;
      function  GetDefaultFrame (wmode: Boolean): integer; override;
   public
      constructor Create; override;
      destructor Destroy; override;
      procedure  Run; override;
      procedure  RunFrameAction (frame: integer); override;
      function   Light: integer; override;
      procedure  LoadSurface; override;
      procedure  DoWeaponBreakEffect;
      procedure  DrawChr (dsurface: TDirectDrawSurface; dx, dy: integer; blend: Boolean; WingDraw: Boolean ); override;
   end;

   function RaceByPM (race, appr: integer): PTMonsterAction;
   function GetMonImg (appr: integer): TWMImages;
   function GetMonSImg (appr: integer): TWMImages;
   function GetOffset (appr: integer): integer;



implementation

uses
   ClMain, SoundUtil, clEvent, uWilFile;


function RaceByPM (race, appr: integer): PTMonsterAction;
begin
   Result := nil;
   case race of   // ¿©±âÀÇ Race´Â RaceImg ·Î »ý°¢µÊ ... COPARK
      9:       Result := @MA9;
      10:      Result := @MA10;
      11:      Result := @MA11;
      12, 24:  Result := @MA12;
      13:      Result := @MA13;
      14, 17, 18, 23:  Result := @MA14;
      15, 22, 111,112:  Result := @MA15; //ºñ¿ù´ÙÅ©
      16:      Result := @MA16;
      30, 31:  Result := @MA17;
      19, 20, 21,
      37,                        //ºñµ¶°Å¹Ì
      101, //¹é»ç(Ã»¿µ»ç)
      40, 45, 52, 53, 95, 113,114,116:  //Ä¡Ãæ, °©¼®±Í¼ö
               Result := @MA19;
      41, 42:  Result := @MA20;
      43:      Result := @MA21;
      47:      Result := @MA22;
      48, 49:  Result := @MA23;
      32:      Result := @MA24;  //Àü°¥, °ø°ÝÀÌ 2°¡Áö ¹æ½Ä
      33:      Result := @MA25;  //Áö³×¿Õ, ÃË·æ½Å
      34,90:      Result := @MA30;  //Ç÷°ÅÀÎ¿Õ, ½ÉÀå, 90=>È­·æ¸ö
      35:      Result := @MA31;  //Æø¾È°Å¹Ì
      36:      Result := @MA32;  //ÆøÁÖ
      54:      Result := @MA28;
      55:      Result := @MA29;  //½Å¼ö(º¯½ÅÈÄ)
      60,61,62:Result := @MA33;  //·ÚÇ÷»ç, ¿Õµ·, ÁÖº»¿Õ(¿ÕÁß¿Õ)
      // 2003/02/11
      63:      Result := @MA34;
      64, 65, 66, 67, 68, 69, 102:    //³¶ÀÎ±Í, ºÎ½Ä±Í, ÇØ°ñ¹«Àå, ÇØ°ñº´Á¹, ÇØ°ñ¹«»ç, ÇØ°ñ±Ã¼ö Ãß°¡
               Result := @MA19;
      // 2003/03/04
      70,71,72,103,104,105,117,118:
               Result := @MA33;  //¹Ý¾ß¿ì»ç, ¹Ý¾ßÁÂ»ç, »ç¿ìÃµ¿Õ, °©Ã¶±Í¼ö
      // 2003/07/15
      73:      Result := @MA19;  // ³¯°³¿À¸¶
      74:      Result := @MA19;  // ¼è¹¶Ä¡»ó±Þ¿À¸¶, ¸ùµÕÀÌ»ó±Þ¿À¸¶, Ä®ÇÏ±Þ¿À¸¶, µµ³¢ÇÏ±Þ¿À¸¶
      75:      Result := @MA54;  // ¸¶°è¼®1
      76:      Result := @MA53;  // °ú°ÅºñÃµ °æºñ
      77:      Result := @MA54;  // ¸¶°è¼®2
      78:      Result := @MA55;  // °ú°ÅºñÃµº¸½º
      79:      Result := @MA19;  // È°ÇÏ±Þ¿À¸¶
      80, 96:
               Result := @MA57;  // Çà¿îÀÇÁö·Ú

      81:      Result := @MA58;  // ¿ù·É
      83:      Result := @MA59;  // È­·æ FireDragon
      84,85,86,87,88,89:   Result := @MA60; // ¿ëÁ¶½Å»ó

      91,92,93,94:   Result := @MA62;  // 2004/03/23 ¼³ÀÎ´ëÃæ, ÁÖ¸¶°Ý·ÚÀå, È¯¿µÇÑÈ£, °Å¹Ì(½Å¼®µ¶¸¶ÁÖ) Ãß°¡
      97:      Result := @MA63;  // º¸¹°ÇÔ

      98:      Result := @MA27;
      99:      Result := @MA26;

      100:      Result := @MA62; // È²±ÝÀÌ¹«±â
      106:      Result := @MA64; // È£È¥¼®
      107:      Result := @MA67; // È£È¥±â¼®
      108,109:  Result := @MA65; // È£±â¿¬
      110:      Result := @MA66; // ºñ¿ùÃµÁÖ
      115:      Result := @MA11; // È£¹Ú
      119:      Result := @MA69; // ¶±

      50:  //npc
         case appr of
            23:
               begin
                  Result := @MA51;
               end;
            // 2003/07/15 °ú°ÅºñÃµ NPC
            27, 32,
            24, 25:
               begin
                  Result := @MA52;
               end;
            35..41, 48,49,50,52,53,54,55,57,58,60,74,78..80: // npcÃß°¡
               begin
                  Result := @MA56;//¼®»ó
               end;
            42,43,44,45,46,47:// NewNpc
               begin
                  Result := @MA61;
               end;
            56,59,68..73,75..77:
               begin
                  Result := @MA68; //¼­ÀÖ±â ¸ð¼Ç¸¸ ÀÖ´Â°Íµé
               end;

            else
               Result := @MA50; //ÀÏ¹Ý NPC
         end;
   end;
end;

function GetMonImg (appr: integer): TWMImages;
begin
   Result := g_WMon[0]; //Default
   case (appr div 10) of
      0..19: Result := g_WMon[(appr div 10)];   //
      80: Result := g_WDragonImg; // FireDragon
//      90: Result := g_WEffectImg;  //¼º¹®, ¼ºº®
   end;
end;

function GetMonSImg (appr: integer): TWMImages;
begin
   Result := g_WMonS[0]; //Default
   case (appr div 10) of
      0..19: Result := g_WMonS[(appr div 10)];   //
   end;
end;

function GetOffset(appr: integer): integer;
var
  nrace, npos: integer;
begin
  Result := 0;
  nrace := appr div 10;
  npos := appr mod 10;
  Result := npos * 1000;
end;

function GetNpcOffset(appr: integer): integer;
begin
  Result := MERCHANTFRAME * appr;
end;

constructor TActor.Create;
begin
   inherited Create;
   MsgList := TList.Create;
   RecogId := 0;
   BodySurface := nil;
   ShadowSurface := nil;
   FillChar (Abil, sizeof(TAbility), 0);
   Gold := 0;
   Visible := TRUE;
   BoHoldPlace := TRUE;

   //ÇöÀç ÁøÇàÁßÀÎ µ¿ÀÛ, Á¾·á‰ç¾îµµ °¡Áö°í ÀÖÀ½
   //µ¿ÀÛÀÇ currentframeÀÌ endframeÀ» ³Ñ¾úÀ¸¸é µ¿ÀÛÀÌ ¿Ï·áµÈ°ÍÀ¸·Î º½
   CurrentAction := 0;
   ReverseFrame := FALSE;
   ShiftX := 0;
   ShiftY := 0;
   DownDrawLevel := 0;
   currentframe := -1;
   effectframe := -1;
   RealActionMsg.Ident := 0;
   UserName := '';
   NameColor := clWhite;
   SendQueryUserNameTime := 0; //GetTickCount;

   WarMode := FALSE;
   WarModeTime := 0;    //War mode·Î º¯°æµÈ ½ÃÁ¡ÀÇ ½Ã°£
   Death := FALSE;
   Skeleton := FALSE;
   BoDelActor := FALSE;
   BoDelActionAfterFinished := FALSE;
   
   ChrLight := 0;
   MagLight := 0;
   LockEndFrame := FALSE;
   smoothmovetime := 0; //GetTickCount;
   genanicounttime := 0;
   defframetime := 0;
   loadsurfacetime := GetTickCount;
   Grouped := FALSE;
   BoOpenHealth := FALSE;
   BoInstanceOpenHealth := FALSE;

   CurMagic.ServerMagicCode := 0;
   //CurMagic.MagicSerial := 0;

   SpellFrame := DEFSPELLFRAME;

   normalsound := -1;
   footstepsound := -1; //¾øÀ½  //ÁÖÀÎ°øÀÎ°æ¿ì, CM_WALK, CM_RUN
   attacksound := -1;
   weaponsound := -1;
   strucksound := s_struck_body_longstick;  //¸ÂÀ»¶§ ³ª´Â ¼Ò¸®    SM_STRUCK
   struckweaponsound := -1;
   screamsound := -1;
   diesound := -1;    //¾øÀ½    //Á×À»¶§ ³ª´Â ¼Ò¸®    SM_DEATHNOW
   die2sound := -1;

//   BoWriterEffect := False;
   TempState := 1;
   FoodStickType := 0;
end;

destructor TActor.Destroy;
begin
   MsgList.Free;
   inherited Destroy;
end;

procedure TActor.SendMsg (ident: word; x, y, cdir, feature, state: integer; str: string; sound: integer);
var
   pmsg: PTChrMsg;
begin
   new (pmsg);
   pmsg.ident  := ident;
   pmsg.x      := x;
   pmsg.y      := y;
   pmsg.dir    := cdir;
   pmsg.feature:= feature;
   pmsg.state  := state;
   pmsg.saying := str;
   pmsg.Sound := sound;
   MsgList.Add (pmsg);
end;

procedure TActor.UpdateMsg (ident: word; x, y, cdir, feature, state: integer; str: string; sound: integer);
var
   i, n: integer;
   pmsg: PTChrMsg;
begin
   if self = Myself then begin
      n := 0;
      while TRUE do begin
         if n >= MsgList.Count then break;
         if (PTChrMsg (MsgList[n]).Ident >= 3000) and //Å¬¶óÀÌ¾ðÆ®¿¡¼­ º¸³½ ¸Þ¼¼Áö´Â
            (PTChrMsg (MsgList[n]).Ident <= 3099) or     //¹«½ÃÇØµµ µÈ´Ù.
            (PTChrMsg (MsgList[n]).Ident = ident) //°°Àº°Ç ¹«½Ã
         then begin
            Dispose (PTChrMsg (MsgList[n]));
            MsgList.Delete (n);
         end else
            Inc (n);
      end;
      SendMsg (ident, x, y, cdir, feature, state, str, sound);
   end else begin
      //if not ((ident = SM_STRUCK) and (MsgList.Count >= 2)) then //¸Â´Â µ¿ÀÛ »ý·«
      if MsgList.Count > 0 then begin
         for i:=0 to MsgList.Count-1 do begin
            if PTChrMsg (MsgList[i]).Ident = ident then begin
               Dispose (PTChrMsg (MsgList[i]));
               MsgList.Delete (i);
               break;
            end;
         end;
      end;
      SendMsg (ident, x, y, cdir, feature, state, str, sound);
   end;
end;

procedure TActor.CleanUserMsgs;
var
   n: integer;
begin
   n := 0;
   while TRUE do begin
      if n >= MsgList.Count then break;
      if (PTChrMsg (MsgList[n]).Ident >= 3000) and //Å¬¶óÀÌ¾ðÆ®¿¡¼­ º¸³½ ¸Þ¼¼Áö´Â
         (PTChrMsg (MsgList[n]).Ident <= 3099)     //¹«½ÃÇØµµ µÈ´Ù.
         then begin
         Dispose (PTChrMsg (MsgList[n]));
         MsgList.Delete (n);
      end else
         Inc (n);
   end;
end;

procedure TActor.CalcActorFrame;
var
   pm: PTMonsterAction;
   haircount: integer;
begin
   BoUseMagic := FALSE;
   currentframe := -1;

   BodyOffset := GetOffset (Appearance);
   pm := RaceByPM (Race, Appearance);
   if pm = nil then exit;

   case CurrentAction of
      SM_TURN:
         begin
            startframe := pm.ActStand.start + Dir * (pm.ActStand.frame + pm.ActStand.skip);
            endframe := startframe + pm.ActStand.frame - 1;
            frametime := pm.ActStand.ftime;
            starttime := GetTickCount;
            defframecount := pm.ActStand.frame;
            Shift (Dir, 0, 0, 1);
         end;
      SM_WALK, SM_RUSH, SM_RUSHKUNG, SM_BACKSTEP:
         begin
            startframe := pm.ActWalk.start + Dir * (pm.ActWalk.frame + pm.ActWalk.skip);
            endframe := startframe + pm.ActWalk.frame - 1;
            frametime := WalkFrameDelay; //pm.ActWalk.ftime;
            starttime := GetTickCount;
            maxtick := pm.ActWalk.UseTick;
            curtick := 0;
            movestep := 1;
            if CurrentAction = SM_BACKSTEP then
               Shift (GetBack(Dir), movestep, 0, endframe-startframe+1)
            else
               Shift (Dir, movestep, 0, endframe-startframe+1);
         end;
      {SM_BACKSTEP:
         begin
            startframe := pm.ActWalk.start + (pm.ActWalk.frame - 1) + Dir * (pm.ActWalk.frame + pm.ActWalk.skip);
            endframe := startframe - (pm.ActWalk.frame - 1);
            frametime := WalkFrameDelay; //pm.ActWalk.ftime;
            starttime := GetTickCount;
            maxtick := pm.ActWalk.UseTick;
            curtick := 0;
            movestep := 1;
            Shift (GetBack(Dir), movestep, 0, endframe-startframe+1);
         end;}
      SM_HIT:
         begin
            startframe := pm.ActAttack.start + Dir * (pm.ActAttack.frame + pm.ActAttack.skip);
            endframe := startframe + pm.ActAttack.frame - 1;
            frametime := pm.ActAttack.ftime;
            starttime := GetTickCount;
            //WarMode := TRUE;
            WarModeTime := GetTickCount;
            Shift (Dir, 0, 0, 1);
         end;
      SM_STRUCK:
         begin
            startframe := pm.ActStruck.start + Dir * (pm.ActStruck.frame + pm.ActStruck.skip);
            endframe := startframe + pm.ActStruck.frame - 1;
            frametime := struckframetime; //pm.ActStruck.ftime;
            starttime := GetTickCount;
            Shift (Dir, 0, 0, 1);
         end;
      SM_DEATH:
         begin
            startframe := pm.ActDie.start + Dir * (pm.ActDie.frame + pm.ActDie.skip);
            endframe := startframe + pm.ActDie.frame - 1;
            startframe := endframe; //
            frametime := pm.ActDie.ftime;
            starttime := GetTickCount;
         end;
      SM_NOWDEATH:
         begin
            startframe := pm.ActDie.start + Dir * (pm.ActDie.frame + pm.ActDie.skip);
            endframe := startframe + pm.ActDie.frame - 1;
            frametime := pm.ActDie.ftime;
            starttime := GetTickCount;
         end;
      SM_SKELETON:
         begin
            startframe := pm.ActDeath.start + Dir;
            endframe := startframe + pm.ActDeath.frame - 1;
            frametime := pm.ActDeath.ftime;
            starttime := GetTickCount;
         end;
   end;
end;

procedure TActor.ReadyAction (msg: TChrMsg);
var
   i, n: integer;
   pmag: PTUseMagicInfo;
   gCheck : Boolean;
begin
   actbeforex := XX;
   actbeforey := YY;

{   if msg.Ident = SM_ALIVE then begin
      Death := FALSE;
      Skeleton := FALSE;
   end;}

   if not Death then begin
      case msg.Ident of
         SM_TURN, SM_WALK, SM_BACKSTEP, SM_RUSH, SM_RUSHKUNG, SM_RUN, SM_DIGUP, SM_ALIVE:
            begin
               Feature := msg.feature;
               if msg.Ident <> SM_RUSH then State := msg.state;

               //Ä³¸¯ÅÍÀÇ ºÎ°¡ÀûÀÎ »óÅÂ Ç¥½Ã
               if State and STATE_OPENHEATH <> 0 then BoOpenHealth := TRUE
               // 2003/03/04 ±×·ì¿ø Å½±âÇ¥½Ã
               else begin
                   n := 0;
                   for i:=1 to ViewListCount do
                       if (ViewList[i].Index = RecogId) then n := i;
                   if n = 0 then
                       BoOpenHealth := FALSE;
               end;
            end;
      end;
//      if (msg.Ident = SM_DRAGON_FIRE1) or (msg.Ident = SM_DRAGON_FIRE2) or (msg.Ident = SM_DRAGON_FIRE3) or
//         (msg.Ident = SM_LIGHTING_1) then
      if msg.Ident in [SM_DRAGON_FIRE1,SM_DRAGON_FIRE2,SM_DRAGON_FIRE3,SM_LIGHTING_1..SM_LIGHTING_3] then
         n := 0;
      if msg.ident = SM_LIGHTING then
         n := 0;
      if Myself = self then begin
         if (msg.Ident = CM_WALK) then
            if not PlayScene.CanWalk (msg.x, msg.y) then
               exit;  //ÀÌµ¿ ºÒ°¡
         if (msg.Ident = CM_RUN) then
            if not PlayScene.CanRun (Myself.XX, Myself.YY, msg.x, msg.y) then
               exit; //ÀÌµ¿ ºÒ°¡

         //msg
         case msg.Ident of
            CM_TURN,
            CM_WALK,
            CM_SITDOWN,
            CM_RUN,
            CM_HIT,
            CM_POWERHIT,
            CM_LONGHIT,
            CM_WIDEHIT,
            // 2003/03/15 ½Å±Ô¹«°ø
            CM_CROSSHIT,
            CM_HEAVYHIT,
            CM_BIGHIT:
               begin
                  RealActionMsg := msg; //ÇöÀç ½ÇÇàµÇ°í ÀÖ´Â Çàµ¿, ¼­¹ö¿¡ ¸Þ¼¼Áö¸¦ º¸³¿.
                  msg.Ident := msg.Ident - 3000;  //SM_?? À¸·Î º¯È¯ ÇÔ
               end;
            CM_THROW:
               begin
                  if feature <> 0 then begin
                     TargetX := TActor(msg.feature).XX;  //x ´øÁö´Â ¸ñÇ¥
                     TargetY := TActor(msg.feature).YY;    //y
                     TargetRecog := TActor(msg.feature).RecogId;
                  end;
                  RealActionMsg := msg;
                  msg.Ident := SM_THROW;
               end;
            CM_FIREHIT:
               begin
                  RealActionMsg := msg;
                  msg.Ident := SM_FIREHIT;
               end;
            // 2003/07/15 ½Å±Ô¹«°ø
            CM_TWINHIT:
               begin
                  RealActionMsg := msg;
                  msg.Ident := SM_TWINHIT;
               end;
            CM_SPELL:
               begin
                  RealActionMsg := msg;
                  pmag := PTUseMagicInfo (msg.feature);
                  RealActionMsg.Dir := pmag.MagicSerial;
                  msg.Ident := msg.Ident - 3000;  //SM_?? À¸·Î º¯È¯ ÇÔ
               end;
         end;

         oldx := XX;
         oldy := YY;
         olddir := Dir;
      end;
      case msg.Ident of
         SM_STRUCK:
            begin
               //Abil.HP := msg.x; {HP}
               //Abil.MaxHP := msg.y; {maxHP}
               //msg.dir {damage}
               //·¹º§ÀÌ ³ôÀ¸¸é ¸Â´Â ½Ã°£ÀÌ Âª´Ù.
               MagicStruckSound := msg.x; //1ÀÌ»ó, ¸¶¹ýÈ¿°ú
               n := Round (200 - Abil.Level * 5);
               if n > 80 then struckframetime := n
               else struckframetime := 80;
               LastStruckTime := GetTickCount;
               gCheck := False;
               if GroupIdList.Count > 0 then
                  for i := 0 to GroupIdList.Count-1 do begin
                      if integer(GroupIdList[i]) = HiterCode then begin
                         gCheck := True;
                         Break;
                      end;
                  end;

               if ((Race <> 0) and (Race <> 34) and (HiterCode = Myself.RecogId) or gCheck) and (Abil.MaxHP < 2000) then begin   //MonOpenHp
                  if not BoInstanceOpenHealth then begin
                     BoInstanceOpenHealth := TRUE;
                     OpenHealthTime := 60 * 1000;
                     OpenHealthStart := GetTickCount;
                  end;
               end;
               if Race = 0 then BoInstanceOpenHealth := False;
            end;
         SM_SPELL:
            begin
               Dir := msg.dir;
               //msg.x  :targetx
               //msg.y  :targety
               pmag := PTUseMagicInfo (msg.feature);
               if pmag <> nil then begin
                  CurMagic := pmag^;
                  CurMagic.ServerMagicCode := -1; //FIRE ´ë±â
                  //CurMagic.MagicSerial := 0;
                  CurMagic.TargX := msg.x;
                  CurMagic.TargY := msg.y;
                  Dispose (pmag);
               end;
               //DScreen.AddSysMsg ('SM_SPELL');
            end;
         else begin
               XX := msg.x;
               YY := msg.y;
               Dir := msg.dir;
            end;
      end;

      CurrentAction := msg.Ident;
      CalcActorFrame;
      //DScreen.AddSysMsg (IntToStr(msg.Ident) + ' ' + IntToStr(XX) + ' ' + IntToStr(YY) + ' : ' + IntToStr(msg.x) + ' ' + IntToStr(msg.y));
   end else begin
      if msg.Ident = SM_SKELETON then begin
         CurrentAction := msg.Ident;
         CalcActorFrame;
         Skeleton := TRUE;
      end;
   end;
   if (msg.Ident = SM_DEATH) or (msg.Ident = SM_NOWDEATH) then begin
      if GroupIdList.Count > 0 then
         for i := 0 to GroupIdList.Count-1 do begin  // MonOpenHp
             if integer(GroupIdList[i]) = RecogId then begin
                GroupIdList.Delete(i);
                Break;
             end;
         end;
      Death := TRUE;
      PlayScene.ActorDied (self);
   end;

   RunSound;
end;

procedure TActor.ProcMsg;
var
   msg: TChrMsg;
   meff: TMagicEff;
begin
   while TRUE do begin
      if MsgList.Count <= 0 then break;
      if CurrentAction <> 0 then break;
      msg := PTChrMsg (MsgList[0])^;
      Dispose (PTChrMsg (MsgList[0]));
      MsgList.Delete (0);

      case msg.ident of
         SM_STRUCK:
            begin
               HiterCode := msg.Sound; //³ª¸¦ ¶§¸°³ð
               ReadyAction (msg);
            end;
         SM_DEATH,
         SM_NOWDEATH,
         SM_SKELETON,
         SM_ALIVE,
         // 2003/04/01 ±¤Ç³Âü ½ÃÀü ¸ð½À
         SM_CROSSHIT,
         SM_TWINHIT,
         SM_STONEHIT,
         SM_ACTION_MIN..SM_ACTION_MAX,
         SM_ACTION2_MIN..SM_ACTION2_MAX,
         SM_DRAGON_LIGHTING..SM_LIGHTING_3,
         3000..3099: //Å¬¶óÀÌ¾ðÆ® ÀÌµ¿ ¸Þ¼¼Áö·Î ¿¹¾àµÊ
            begin
               ReadyAction (msg);
            end;
         SM_SPACEMOVE_HIDE:
            begin
               meff := TScrollHideEffect.Create (2410, 20, XX, YY, self);
               PlayScene.EffectList.Add (meff);
               PlaySound (s_spacemove_out);
            end;
         SM_SPACEMOVE_HIDE2:
            begin
               meff := TScrollHideEffect.Create (1590, 10, XX, YY, self);
               PlayScene.EffectList.Add (meff);
               PlaySound (s_spacemove_out);
            end;
         SM_SPACEMOVE_SHOW:
            begin
               meff := TCharEffect.Create (2390, 20, self);
               PlayScene.EffectList.Add (meff);
               msg.ident := SM_TURN;
               ReadyAction (msg);
               PlaySound (s_spacemove_in);
            end;
         SM_SPACEMOVE_SHOW2:
            begin
               meff := TCharEffect.Create (1600, 10, self);
               PlayScene.EffectList.Add (meff);
               msg.ident := SM_TURN;
               ReadyAction (msg);
               PlaySound (s_spacemove_in);
            end;
         else
            begin
            end;
      end;
   end;

end;

procedure TActor.ProcHurryMsg; //»¡¸® Ã³¸®ÇØ¾ß µÇ´Â ¸Þ¼¼Áö Ã³¸®ÇÔ..
var
   n: integer;
   msg: TChrMsg;
   fin: Boolean;
begin
   n := 0;
   while TRUE do begin
      if MsgList.Count <= n then break;
      msg := PTChrMsg (MsgList[n])^;
      fin := FALSE;
      case msg.Ident of
         SM_MAGICFIRE:
            if CurMagic.ServerMagicCode <> 0 then begin
               CurMagic.ServerMagicCode := 111;
               CurMagic.Target := msg.x;
               if msg.y in [0..MAXMAGICTYPE-1] then
                  CurMagic.EffectType := TMagicType(msg.y);
               CurMagic.EffectNumber := msg.dir;
               CurMagic.TargX := msg.feature;
               CurMagic.TargY := msg.state;
               CurMagic.Recusion := TRUE;
               fin := TRUE;
               //DScreen.AddSysMsg ('SM_MAGICFIRE GOOD');
            end;
         SM_MAGICFIRE_FAIL:
            if CurMagic.ServerMagicCode <> 0 then begin
               CurMagic.ServerMagicCode := 0;
               fin := TRUE;
            end;
      end;
      if fin then begin
         Dispose (PTChrMsg (MsgList[n]));
         MsgList.Delete (n);
      end else
         Inc (n);
   end;
end;

function  TActor.IsIdle: Boolean;
begin
   if (CurrentAction = 0) and (MsgList.Count = 0) then
      Result := TRUE
   else Result := FALSE;
end;

function  TActor.ActionFinished: Boolean;
begin
   if (CurrentAction = 0) or (currentframe >= endframe) then
      Result := TRUE
   else Result := FALSE;
end;

function  TActor.CanWalk: Integer;
begin
   //¾ò¾î ¸ÂÀº ´ÙÀ½¿¡ °ÉÀ» ¼ö ¾ø´Ù. or ¸¶¹ý µô·¡ÀÌ
   if {(GetTickCount - LastStruckTime < 1300) or}(GetTickCount - LatestSpellTime < MagicPKDelayTime) then
      Result := -1   //µô·¹ÀÌ
   else
      Result := 1;
end;

function  TActor.CanRun: Integer;
begin
   //¹ÎÃ¸ÀÌ ¶³¾îÁ³°Å³ª, Ã¼·ÂÀÌ ¼Ò¸ðµÇ¾úÀ¸¸é ¶Û ¼ö ¾øÀ½..
   //¾ò¾î ¸ÂÀº ´ÙÀ½¿¡ ¹Ù·Î ¶Û ¼ö ¾øÀ½..
   Result := 1;
   if Abil.HP < RUN_MINHEALTH then begin
      Result := -1;
   end else
   if (GetTickCount - LastStruckTime < RUN_STRUCK_DELAY) or (GetTickCount - LatestSpellTime < MagicPKDelayTime) then
      Result := -2;

end;

function  TActor.Strucked: Boolean;
var
   i: integer;
begin
   Result := FALSE;
   for i:=0 to MsgList.Count-1 do begin
      if PTChrMsg (MsgList[i]).Ident = SM_STRUCK then begin
         Result := TRUE;
         break;
      end;
   end;
end;


//dir : ¹æÇâ
//step : ÀÌµ¿ Ä­
//cur : ÇöÀç ½ºÅÜ
//max : ÃÖ´ë ½ºÅÜ
procedure TActor.Shift(dir, step, cur, max: integer);
var
  unx, uny, ss, v: Integer;
  funx, funy:Integer;
begin
  unx := UNITX * step;
  uny := UNITY * step;
  if cur > max then cur := max;
  Rx := XX;
  Ry := YY;
//   ss := Round((max-cur-1) / max) * step;
  case dir of
    DR_UP: begin
      ss := Round((max - cur) / max) * step;
      Ry := YY + ss;
      if ss = step then begin
        funx := -Round(uny / max * cur);
        if (funx mod 2) <> 0 then
          funx:= funx + 1;
        ShiftY:= funx;
      end else begin
        funx := Round(uny / max * (max - cur));
        if (funx mod 2) <> 0 then
          funx:= funx + 1;
        ShiftY:= funx;
      end;
    end;
    DR_UPRIGHT: begin
      if max >= 6 then
        v := 2
      else
        v := 0;
      ss := Round((max - cur + v) / max) * step;
      Rx := XX - ss;
      Ry := YY + ss;
      if ss = step then begin
        funx := Round(unx / max * cur);
        if (funx mod 2) <> 0 then
          funx:= funx + 1;
        ShiftX:= funx;
        funy := -Round(uny / max * cur);
        if (funy mod 2) <> 0 then
          funy:= funy + 1;
        ShiftY:= funy;
      end else begin
        funx := -Round(unx / max * (max - cur));
        if (funx mod 2) <> 0 then
          funx:= funx + 1;
        ShiftX:= funx;
        funy := Round(uny / max * (max - cur));
        if (funy mod 2) <> 0 then
          funy:= funy + 1;
        ShiftY:= funy;
      end;
    end;
    DR_RIGHT: begin
      ss := Round((max - cur) / max) * step;
      Rx := XX - ss;
      if ss = step then begin
        ShiftX := Round(unx / max * cur)
      end else begin
        ShiftX := -Round(unx / max * (max - cur));
      end;
      ShiftY := 0;
    end;
    DR_DOWNRIGHT: begin
      if max >= 6 then
        v := 2
      else
        v := 0;
      ss := Round((max - cur - v) / max) * step;
      Rx := XX - ss;
      Ry := YY - ss;
      if ss = step then begin
        funx := Round(unx / max * cur);
        if (funx mod 2) <> 0 then
          funx:= funx + 1;
        ShiftX:= funx;

        funy := Round(uny / max * cur);
        if (funy mod 2) <> 0 then
          funy:= funy + 1;
        ShiftY:= funy;
      end else begin
        funx := -Round(unx / max * (max - cur));
        if (funx mod 2) <> 0 then
          funx:= funx + 1;
        ShiftX:= funx;
        funy := -Round(uny / max * (max - cur));
        if (funy mod 2) <> 0 then
          funy:= funy + 1;
        ShiftY:= funy;
      end;
    end;
    DR_DOWN: begin
      if max >= 6 then
        v := 1
      else
        v := 0;
      ss := Round((max - cur - v) / max) * step;
      ShiftX := 0;
      Ry := YY - ss;
      if ss = step then begin
        funy := Round(uny / max * cur);
        if (funy mod 2) <> 0 then
          funy:= funy + 1;
        ShiftY:= funy;
      end else begin
        funy := -Round(uny / max * (max - cur));
        if (funy mod 2) <> 0 then
          funy:= funy + 1;
        ShiftY:= funy;
      end;
    end;
    DR_DOWNLEFT:  begin
      if max >= 6 then
        v := 2
      else
        v := 0;
      ss := Round((max - cur - v) / max) * step;
      Rx := XX + ss;
      Ry := YY - ss;
      if ss = step then begin
        funx := -Round(unx / max * cur);
        if (funx mod 2) <> 0 then
          funx:= funx + 1;
        ShiftX:= funx;
        funy := Round(uny / max * cur);
        if (funy mod 2) <> 0 then
          funy:= funy + 1;
        ShiftY:= funy;
      end else begin
        funx := Round(unx / max * (max - cur));
        if (funx mod 2) <> 0 then
          funx:= funx + 1;
        ShiftX:= funx;
        funy := -Round(uny / max * (max - cur));
        if (funy mod 2) <> 0 then
          funy:= funy + 1;
        ShiftY:= funy;
      end;
    end;
    DR_LEFT: begin
            ss := Round((max - cur) / max) * step;
      Rx := XX + ss;
      if ss = step then begin
        ShiftX := -Round(unx / max * cur)
      end else begin
        ShiftX := Round(unx / max * (max - cur));
      end;
      ShiftY := 0;
    end;
    DR_UPLEFT: begin
      if max >= 6 then
        v := 2
      else
        v := 0;
      ss := Round((max - cur + v) / max) * step;
      Rx := XX + ss;
      Ry := YY + ss;
      if ss = step then begin
        funx := -Round(unx / max * cur);
        if (funx mod 2) <> 0 then
          funx:= funx + 1;
        ShiftX:= funx;
        funy := -Round(uny / max * cur);
          if (funy mod 2) <> 0 then
            funy:= funy + 1;
        ShiftY:= funy;
      end else begin
        funx := Round(unx / max * (max - cur));
        if (funx mod 2) <> 0 then
          funx:= funx + 1;
        ShiftX:= funx;
        funy := Round(uny / max * (max - cur));
        if (funy mod 2) <> 0 then
          funy:= funy + 1;
        ShiftY:= funy;
      end;
    end;
  end;
end;
{
procedure TActor.Shift (dir, step, cur, max: integer);
var
   unx, uny, ss, v: integer;
begin
   unx := UNITX * step;
   uny := UNITY * step;
   if cur > max then cur := max;
   Rx := XX;
   Ry := YY;
   ss := Round((max-cur-1) / max) * step;
   case dir of
      DR_UP:
         begin
            ss := Round((max-cur) / max) * step;
            ShiftX := 0;
            Ry := YY + ss;
            if ss = step then ShiftY := -Round(uny / max * cur)
            else ShiftY := Round(uny / max * (max-cur));
         end;
      DR_UPRIGHT:
         begin
            if max >= 6 then v := 2
            else v := 0;
            ss := Round((max-cur+v) / max) * step;
            Rx := XX - ss;
            Ry := YY + ss;
            if ss = step then begin
               ShiftX :=  Round(unx / max * cur);
               ShiftY := -Round(uny / max * cur);
            end else begin
               ShiftX := -Round(unx / max * (max-cur));
               ShiftY :=  Round(uny / max * (max-cur));
            end;
         end;
      DR_RIGHT:
         begin
            ss := Round((max-cur) / max) * step;
            Rx := XX - ss;
            if ss = step then ShiftX := Round(unx / max * cur)
            else ShiftX := -Round(unx / max * (max-cur));
            ShiftY := 0;
         end;
      DR_DOWNRIGHT:
         begin
            if max >= 6 then v := 2
            else v := 0;
            ss := Round((max-cur-v) / max) * step;
            Rx := XX - ss;
            Ry := YY - ss;
            if ss = step then begin
               ShiftX := Round(unx / max * cur);
               ShiftY := Round(uny / max * cur);
            end else begin
               ShiftX := -Round(unx / max * (max-cur));
               ShiftY := -Round(uny / max * (max-cur));
            end;
         end;
      DR_DOWN:
         begin
            if max >= 6 then v := 1
            else v := 0;
            ss := Round((max-cur-v) / max) * step;
            ShiftX := 0;
            Ry := YY - ss;
            if ss = step then ShiftY := Round(uny / max * cur)
            else ShiftY := -Round(uny / max * (max-cur));
         end;
      DR_DOWNLEFT:
         begin
            if max >= 6 then v := 2
            else v := 0;
            ss := Round((max-cur-v) / max) * step;
            Rx := XX + ss;
            Ry := YY - ss;
            if ss = step then begin
               ShiftX := -Round(unx / max * cur);
               ShiftY :=  Round(uny / max * cur);
            end else begin
               ShiftX :=  Round(unx / max * (max-cur));
               ShiftY := -Round(uny / max * (max-cur));
            end;
         end;
      DR_LEFT:
         begin
            ss := Round((max-cur) / max) * step;
            Rx := XX + ss;
            if ss = step then ShiftX := -Round(unx / max * cur)
            else ShiftX := Round(unx / max * (max-cur));
            ShiftY := 0;
         end;
      DR_UPLEFT:
         begin
            if max >= 6 then v := 2
            else v := 0;
            ss := Round((max-cur+v) / max) * step;
            Rx := XX + ss;
            Ry := YY + ss;
            if ss = step then begin
               ShiftX := -Round(unx / max * cur);
               ShiftY := -Round(uny / max * cur);
            end else begin
               ShiftX := Round(unx / max * (max-cur));
               ShiftY := Round(uny / max * (max-cur));
            end;
         end;
   end;
end; }

procedure  TActor.FeatureChanged;
var
   haircount: integer;
begin
   case Race of
      //human
      0: begin
         hair   := HAIRfeature (Feature);         //º¯°æµÈ´Ù.
         dress  := DRESSfeature (Feature);
         weapon := WEAPONfeature (Feature);
         BodyOffset := HUMANFRAME * (Dress div 2); //³²ÀÚ0, ¿©ÀÚ1

         if hair > 1 then
            HairOffset := HUMANFRAME * hair
         else HairOffset := -1;


//         haircount := g_WHairImg.ImageCount div HUMANFRAME div 2;
//         if hair > haircount-1 then hair := haircount-1;
//         hair := hair * 2;
//         if hair > 1 then
//            HairOffset := HUMANFRAME * (hair + Sex)
//         else HairOffset := -1;

         if weapon = 254 then
            WeaponOffset := HUMANFRAME * (weapon mod 10)
         else if weapon in [101..200] then
            WeaponOffset := HUMANFRAME * ((weapon - 101) mod 10)
         else
            WeaponOffset := HUMANFRAME * ((weapon - 1) mod 10);


         if dress = 18 then WingOffset := 0                  // ÃµÀÇ¹«ºÀ(³²)
         else if dress = 19 then WingOffset := HUMANFRAME    // ÃµÀÇ¹«ºÀ(¿©)
         else if dress = 20 then WingOffset := HUMANFRAME*2  // Ãµ·æºÒ»çÀÇ(³²)
         else if dress = 21 then WingOffset := HUMANFRAME*3  // Ãµ·æºÒ»çÀÇ(¿©)
         else if dress in [22,23] then WingOffset := 352;    // 50·¹º§¿Ê

         //²âÊÔ
         if (Dress div 2) = 1 then WingOffset := 2180;
              

         if weapon = 254 then begin
           if sex = 0 then WeaponEffectOffset := 1900        // ÆÄ°üÁø°Ë ÀÌÆåÆ®(³²)
           else WeaponEffectOffset := 2900;
         end;
         if weapon = 76 then WeaponEffectOffset := HUMANFRAME*4        // ÆÄ°üÁø°Ë ÀÌÆåÆ®(³²)
         else if weapon = 77 then WeaponEffectOffset := HUMANFRAME*5;  // ÆÄ°üÁø°Ë ÀÌÆåÆ®(¿©)
      end;
      50: ;  //npc
      else begin
         Appearance := APPRfeature (Feature);
         BodyOffset := GetOffset (Appearance);
         //BodyOffset := MONFRAME * (Appearance mod 10);
      end;
   end;
end;

function   TActor.Light: integer;
begin
   Result := ChrLight;
end;

procedure  TActor.LoadSurface;
var
   msimg, mimg: TWMImages;
begin

   msimg := GetMonSImg (Appearance);
   if msimg <> nil then begin
      if (not ReverseFrame) then
         ShadowSurface := msimg.GetCachedImage (GetOffset (Appearance) + currentframe, spx, spy)
      else
         ShadowSurface := msimg.GetCachedImage (
                            GetOffset (Appearance) + endframe - (currentframe-startframe),
                            spx, spy);
   end;

   mimg := GetMonImg (Appearance);
   if mimg <> nil then begin
      if ShadowSurface <> nil then begin
         if (not ReverseFrame) then
            BodySurface := mimg.GetCachedImage (GetOffset (Appearance) + currentframe, px, py)
         else
            BodySurface := mimg.GetCachedImage (
                               GetOffset (Appearance) + endframe - (currentframe-startframe),
                               px, py);
      end else begin
         if (not ReverseFrame) then
            BodySurface := mimg.GetCachedImageEx (GetOffset (Appearance) + currentframe, px, py, spx, spy, stype)
         else
            BodySurface := mimg.GetCachedImageEx (
                               GetOffset (Appearance) + endframe - (currentframe-startframe),
                               px, py, spx, spy, stype);
      end;
   end;
end;

function  TActor.CharWidth: Integer;
begin
   if BodySurface <> nil then
      Result := BodySurface.Width
   else Result := 48;
end;

function  TActor.CharHeight: Integer;
begin
   if BodySurface <> nil then
      Result := BodySurface.Height
   else Result := 70;
end;

function  TActor.CheckSelect (dx, dy: integer): Boolean;
var
   c: integer;
begin
   Result := FALSE;
   if BodySurface <> nil then begin
      c := BodySurface.Pixels[dx, dy];
      if (c <> 0) and
         ((BodySurface.Pixels[dx-1, dy] <> 0) and
          (BodySurface.Pixels[dx+1, dy] <> 0) and
          (BodySurface.Pixels[dx, dy-1] <> 0) and
          (BodySurface.Pixels[dx, dy+1] <> 0)) then
         Result := TRUE;
   end;
end;

procedure TActor.DrawEffSurface (dsurface, source: TDirectDrawSurface; ddx, ddy: integer; blend: Boolean; ceff: TColorEffect);
begin
   if State and $00800000 <> 0 then begin
      blend := TRUE;  //Åõ¸í
   end;
   if not Blend then begin
      if ceff = ceNone then begin
         if source <> nil then
            dsurface.Draw (ddx, ddy, source.ClientRect, source, TRUE);
      end else begin
         if source <> nil then begin
            dsurface.Draw(ddx, ddy, source.ClientRect, source, TRUE);
            DrawEffect(dsurface, ddx, ddy, source, ceff, blend, 0);
         end;
      end;
   end else begin
      if ceff = ceNone then begin
         if source <> nil then
            DrawBlend (dsurface, ddx, ddy, source, 0);
      end else begin
         if source <> nil then begin
            DrawEffect(dsurface, ddx, ddy, source, ceff, blend, 1);
         end;
      end;
   end;
end;

procedure TActor.DrawWeaponGlimmer (dsurface: TDirectDrawSurface; ddx, ddy: integer);
var
   idx, ax, ay: integer;
   d: TDirectDrawSurface;
begin
   //»ç¿ë¾ÈÇÔ..(¿°È­°á) ±×·¡ÇÈ ¿À·ù...
   (*if BoNextTimeFireHit and WarMode and GlimmingMode then begin
      if GetTickCount - GlimmerTime > 200 then begin
         GlimmerTime := GetTickCount;
         Inc (CurGlimmer);
         if CurGlimmer >= MaxGlimmer then CurGlimmer := 0;
      end;
      idx := GetEffectBase (5-1{¿°È­°á¹ÝÂ¦ÀÓ}, 1) + Dir*10 + CurGlimmer;
      d := FrmMain.WMagic.GetCachedImage (idx, ax, ay);
      if d <> nil then
         DrawBlend (dsurface, ddx + ax, ddy + ay, d, 1);
                          //dx + ax + ShiftX,
                          //dy + ay + ShiftY,
                          //d, 1);
   end;*)
end;

function TActor.GetDrawEffectValue: TColorEffect;
var
   ceff: TColorEffect;
begin
   ceff := ceNone;

   //¼±ÅÃµÈ Ä³¸¯ ¹à°Ô.
   if (FocusCret = self) or (MagicTarget = self) then begin
      ceff := ceBright;
   end;

   //Áßµ¶
   if State and $80000000 <> 0 then begin        //POISON_DECHEALTH
      ceff := ceGreen;
   end;
   if State and $40000000 <> 0 then begin        //POISON_DAMAGEARMOR
      ceff := ceRed;
   end;
   if State and $20000000 <> 0 then begin        //POISON_ICE
      ceff := ceBlue;
   end;
   if State and $10000000 <> 0 then begin        //POISON_STUN
      ceff := ceYellow;
   end;
   if State and $08000000 <> 0 then begin        //POISON_SLOW
      ceff := ceFuchsia;
   end;
   if State and $04000000 <> 0 then begin        //POISON_STONE
      ceff := ceGrayScale;
   end;
   if State and $02000000 <> 0 then begin        //POISON_DONTMOVE
      ceff := ceGrayScale;   // »çÀÚÈÄ °ü·Ã
   end;

   // 2004/03/22 50 LevelEffect
   if (Race = 0) and ((State and $00080000) <> 0) then //50LEVELEFFECT
      Bo50LevelEffect := True
   else Bo50LevelEffect := False;

{   FoodStickType := 0;
   if (Race = 0) and ((State and $00040000) <> 0) then //»©»©·Î
      FoodStickType := 2;
   if (Race = 0) and ((State and $00020000) <> 0) then //È£¹Ú
      FoodStickType := 1;
   if (Race = 0) and ((State and $00010000) <> 0) then //ÇÏÆ®
      FoodStickType := 3;}

//   if (Race = 0) and (State and $00080000 <> 0) then //WRITEREFFECT
//      BoWriterEffect := True
//   else BoWriterEffect := False;

   Result := ceff;
end;

procedure  TActor.DrawChr (dsurface: TDirectDrawSurface; dx, dy: integer; blend: Boolean; WingDraw: Boolean );
var
   idx, ax, ay: integer;
   d: TDirectDrawSurface;
   ceff: TColorEffect;
   wimg: TWMImages;
begin
   if not (Dir in [0..7]) then exit;
   if GetTickCount - loadsurfacetime > 60 * 1000 then begin
      loadsurfacetime := GetTickCount;
      LoadSurface; //bodysurfaceµîÀÌ loadsurface¸¦ ´Ù½Ã ºÎ¸£Áö ¾Ê¾Æ ¸Þ¸ð¸®°¡ ÇÁ¸®µÇ´Â °ÍÀ» ¸·À½
   end;

   if ShadowSurface <> nil then begin
     DrawBlendShadow(dsurface, dx + spx + ShiftX, dy + spy + ShiftY, 50, ShadowSurface, g_boShadowBlend)
   end else begin
     if BodySurface <> nil then begin
       if Death then DrawBlendShadow(dsurface, dx + spx + 3 + ShiftX, dy + spy + 2 + ShiftY, 50, BodySurface, g_boShadowBlend)
       else DrawBlendShadow(dsurface, dx + spx + ShiftX, dy + spy + ShiftY, stype, BodySurface, g_boShadowBlend);
     end;
   end;

   ceff := GetDrawEffectValue;
   if BodySurface <> nil then begin
      DrawEffSurface (dsurface, BodySurface, dx + px + ShiftX, dy + py + ShiftY, blend, ceff);
   end;

   if BoUseMagic {and (EffDir[Dir] = 1)} and (CurMagic.EffectNumber > 0) then
      if CurEffFrame in [0..SpellFrame-1] then begin
         GetEffectBase (Curmagic.EffectNumber-1, 0, wimg, idx);
         idx := idx + CurEffFrame;
         if wimg <> nil then
            d := wimg.GetCachedImage (idx, ax, ay);
         if d <> nil then
            DrawBlend (dsurface,
                             dx + ax + ShiftX,
                             dy + ay + ShiftY,
                             d, 1);
      end;
end;

procedure  TActor.DrawEff (dsurface: TDirectDrawSurface; dx, dy: integer);
begin
end;


function  TActor.GetDefaultFrame (wmode: Boolean): integer;
var
   cf, dr: integer;
   pm: PTMonsterAction;
begin
   pm := RaceByPm (Race, Appearance);
   if pm = nil then exit;

   if Death then begin
      if Skeleton then
         Result := pm.ActDeath.start
      else Result := pm.ActDie.start + Dir * (pm.ActDie.frame + pm.ActDie.skip) + (pm.ActDie.frame - 1);
   end else begin
      defframecount := pm.ActStand.frame;
      if currentdefframe < 0 then cf := 0
      else if currentdefframe >= pm.ActStand.frame then cf := 0
      else cf := currentdefframe;
      Result := pm.ActStand.start + Dir * (pm.ActStand.frame + pm.ActStand.skip) + cf;
   end;
end;

procedure TActor.DefaultMotion;   //µ¿ÀÛ ¾øÀ½,  ±âº» ÀÚ¼¼..
begin
   ReverseFrame := FALSE;
   if WarMode then begin
      if (GetTickCount - WarModeTime > 4*1000) then //and not BoNextTimeFireHit then
         WarMode := FALSE;
   end;
   currentframe := GetDefaultFrame (WarMode);
   Shift (Dir, 0, 1, 1);
end;

//»ç¿îµå º¯¼ö¸¦ ÃÊ±âÈ­ ÇÑ´Ù.
procedure TActor.SetSound;
var
   cx, cy, bidx, wunit, attackweapon: integer;
   hiter: TActor;
begin
   if Race = 0 then begin
      if (self = Myself) and
         ((CurrentAction=SM_WALK) or
          (CurrentAction=SM_BACKSTEP) or
          (CurrentAction=SM_RUN) or
          (CurrentAction=SM_RUSH) or
          (CurrentAction=SM_RUSHKUNG)
         )
      then begin
         cx := Myself.XX - Map.BlockLeft;
         cy := Myself.YY - Map.BlockTop;
         cx := cx div 2 * 2;
         cy := cy div 2 * 2;
//         bidx := Map.MArr[cx, cy].BkImg and $7FFF;
//         wunit := Map.MArr[cx, cy].Area;
         bidx := wunit * 10000 + bidx - 1;
         case bidx of
            //ÂªÀº Ç®
            330..349, 450..454, 550..554, 750..754,
            950..954, 1250..1254, 1400..1424, 1455..1474,
            1500..1524, 1550..1574:
               footstepsound := s_walk_lawn_l;

            //Áß°£Ç®

            //±ä Ç®
            250..254, 1005..1009, 1050..1054, 1060..1064, 1450..1454,
            1650..1654:
               footstepsound := s_walk_rough_l;

            //µ¹ ±æ
            //´ë¸®¼® ¹Ù´Ú
            605..609, 650..654, 660..664, 2000..2049,
            3025..3049, 2400..2424, 4625..4649, 4675..4678:
               footstepsound := s_walk_stone_l;

            //µ¿±¼¾È
            1825..1924, 2150..2174, 3075..3099, 3325..3349,
            3375..3399:
               footstepsound := s_walk_cave_l;

            //³ª¹«¹Ù´Ú
           3230, 3231, 3246, 3277:
               footstepsound := s_walk_wood_l;

           //´øÀü..
           3780..3799:
               footstepsound := s_walk_wood_l;

           3825..4434:
               if (bidx-3825) mod 25 = 0 then footstepsound := s_walk_wood_l
               else footstepsound := s_walk_ground_l;


            //Áý¾È(¼Ò¸® º°·ç ¾È³²)
             2075..2099, 2125..2149:
               footstepsound := s_walk_room_l;

            //°³¿ï
            1800..1824:
               footstepsound := s_walk_water_l;

            else
               footstepsound := s_walk_ground_l;
         end;
         //±ÃÀü³»ºÎ
         if (bidx >= 825) and (bidx <= 1349) then begin
            if ((bidx-825) div 25) mod 2 = 0 then
               footstepsound := s_walk_stone_l;
         end;
         //µ¿±¼³»ºÎ
         if (bidx >= 1375) and (bidx <= 1799) then begin
            if ((bidx-1375) div 25) mod 2 = 0 then
               footstepsound := s_walk_cave_l;
         end;
         case bidx of
            1385, 1386, 1391, 1392:
               footstepsound := s_walk_wood_l;
         end;

//         bidx := Map.MArr[cx, cy].MidImg and $7FFF;
         bidx := bidx - 1;
         case bidx of
            0..115:
               footstepsound := s_walk_ground_l;
            120..124:
               footstepsound := s_walk_lawn_l;
         end;

//         bidx := Map.MArr[cx, cy].FrImg and $7FFF;
         bidx := bidx - 1;
         case bidx of
            //º®µ¹±æ
            221..289, 583..658, 1183..1206, 7163..7295,
            7404..7414:
               footstepsound := s_walk_stone_l;
            //³ª¹«¸¶·ç
            3125..3267, {3319..3345, 3376..3433,} 3757..3948,
            6030..6999:
               footstepsound := s_walk_wood_l;
            //¹æ¹Ù´Ú
            3316..3589:
               footstepsound := s_walk_room_l;
         end;
         if CurrentAction = SM_RUN then
            footstepsound := footstepsound + 2;

         //´«Ææ3ÐÞ¸Ä
         footstepsound := s_walk_ground_l;
      end;

      if Sex = 0 then begin //³²ÀÚ
         screamsound := s_man_struck;
         diesound := s_man_die;
      end else begin //¿©ÀÚ
         screamsound := s_wom_struck;
         diesound := s_wom_die;
      end;

      case CurrentAction of
         // 2003/03/15 ½Å±Ô¹«°ø
         SM_THROW, SM_HIT, SM_HIT+1, SM_HIT+2, SM_POWERHIT, SM_LONGHIT,
         SM_WIDEHIT, SM_FIREHIT, SM_CROSSHIT, SM_TWINHIT , SM_STONEHIT:
            begin
               case (weapon div 2) of
                  6, 20:  weaponsound := s_hit_short;
                  1, 27, 28 , 33:  weaponsound := s_hit_wooden;
                  2, 13, 9, 5, 14, 22, 25, 30, 35, 36, 37,38:  weaponsound := s_hit_sword;
                  4, 17, 10, 15, 16, 23, 26, 29, 31, 34:  weaponsound := s_hit_do;
                  3, 7, 11:  weaponsound := s_hit_axe;
                  24:  weaponsound := s_hit_club;
                  8, 12, 18, 21, 32:  weaponsound := s_hit_long;
                  else weaponsound := s_hit_fist;
               end;
            end;
         SM_STRUCK:
            begin
               if MagicStruckSound >= 1 then begin  //¸¶¹ýÀ¸·Î ¸ÂÀ½
                  //strucksound := s_struck_magic;  //ÀÓ½Ã..
               end else begin
                  hiter := PlayScene.FindActor (HiterCode);
                  attackweapon := 0;
                  if hiter <> nil then begin //¶§¸°³ðÀÌ ¹«¾ùÀ¸·Î ¶§·È´ÂÁö °Ë»ç
                     attackweapon := hiter.weapon div 2;
                     if hiter.Race = 0 then
                        case (dress div 2) of
                           3: //°©¿Ê
                              case attackweapon of
                                 6:  strucksound := s_struck_armor_sword;
                                 1,2,4,5,9,10,13,14,15,16,17,
                                 22,23,24,25,26,27,28,29,30,31,33,34,35,36,37,38:
                                    strucksound := s_struck_armor_sword;
                                 3,7,11: strucksound := s_struck_armor_axe;
                                 8,12,18,21,32: strucksound := s_struck_armor_longstick;
                                 else strucksound := s_struck_armor_fist;
                              end;
                           else //ÀÏ¹Ý
                              case attackweapon of
                                 6: strucksound := s_struck_body_sword;
                                 1,2,4,5,9,10,13,14,15,16,17,
                                 22,23,24,25,26,27,28,29,30,31,33,34,35,36,37,38:
                                    strucksound := s_struck_body_sword;
                                 3,7,11: strucksound := s_struck_body_axe;
                                 8,12,18,21,32: strucksound := s_struck_body_longstick;
                                 else strucksound := s_struck_body_fist;
                              end;
                        end;
                  end;
               end;
            end;
      end;

      //¸¶¹ý ¼Ò¸®
      if BoUseMagic and (CurMagic.MagicSerial > 0) then begin
         magicstartsound := 10000 + CurMagic.MagicSerial * 10;
         magicfiresound := 10000 + CurMagic.MagicSerial * 10 + 1;
         magicexplosionsound := 10000 + CurMagic.MagicSerial * 10 + 2;
      end;

   end else begin
      if CurrentAction = SM_STRUCK then begin
         if MagicStruckSound >= 1 then begin  //¸¶¹ýÀ¸·Î ¸ÂÀ½
            //strucksound := s_struck_magic;  //ÀÓ½Ã..
         end else begin
            hiter := PlayScene.FindActor (HiterCode);
            if hiter <> nil then begin  //¶§¸°³ðÀÌ ¹«¾ùÀ¸·Î ¶§·È´ÂÁö °Ë»ç
               attackweapon := hiter.weapon div 2;
               case attackweapon of
                  6: strucksound := s_struck_body_sword;
                  1,2,4,5,9,10,13,14,15,16,17,
                  22,23,24,25,26,27,28,29,30,31,33,34,35,36,37,38:
                  strucksound := s_struck_body_sword;
                  3,7,11: strucksound := s_struck_body_axe;
                  8,12,18,21,32: strucksound := s_struck_body_longstick;
                  else strucksound := s_struck_body_fist;
               end;
            end;
         end;
      end;

      if Race = 50 then begin
      end else begin
//      if Race = 91 then   // ¼³ÀÎ´ëÃæ Appearance=> 220
//         DScreen.AddChatBoardString ('[Race = 91]Appearance=> '+IntToStr(Appearance), clYellow, clRed);
         appearsound := 200 + (Appearance) * 10;
         normalsound := 200 + (Appearance) * 10 + 1;
         attacksound := 200 + (Appearance) * 10 + 2;  //¿ì¿ö¾ï
         weaponsound := 200 + (Appearance) * 10 + 3;  //È×(¹«±âÈÖµÎ·ë)
         screamsound := 200 + (Appearance) * 10 + 4;
         diesound := 200 + (Appearance) * 10 + 5;
         die2sound := 200 + (Appearance) * 10 + 6;
      end;
   end;

   //Ä® ¸Â´Â ¼Ò¸®
   if CurrentAction = SM_STRUCK then begin
      hiter := PlayScene.FindActor (HiterCode);
      attackweapon := 0;
      if hiter <> nil then begin  //¶§¸°³ðÀÌ ¹«¾ùÀ¸·Î ¶§·È´ÂÁö °Ë»ç
         attackweapon := hiter.weapon div 2;
         if hiter.Race = 0 then
            case (attackweapon div 2) of
               6, 20:  struckweaponsound := s_struck_short;
               1,27,28,33:  struckweaponsound := s_struck_wooden;
               2, 13, 9, 5, 14, 22,25,30,35,36,37,38:  struckweaponsound := s_struck_sword;
               4, 17, 10, 15, 16, 23,26,29,31,34:  struckweaponsound := s_struck_do;
               3, 7, 11:  struckweaponsound := s_struck_axe;
               24:  struckweaponsound := s_struck_club;
               8, 12, 18, 21,32:  struckweaponsound := s_struck_wooden; //long;
               //else struckweaponsound := s_struck_fist;
            end;
      end;
   end;
end;

procedure  TActor.RunSound;
begin
   borunsound := TRUE;
   SetSound;
   case CurrentAction of
      SM_STRUCK:
         begin
            if (struckweaponsound >= 0) then PlaySound (struckweaponsound);
            if (strucksound >= 0) then PlaySound (strucksound);
            if (screamsound >= 0) then PlaySound (screamsound);
         end;
      SM_NOWDEATH:
         begin
            if (diesound >= 0) then PlaySound (diesound);
         end;
      SM_THROW, SM_HIT, SM_FLYAXE, SM_LIGHTING, SM_DIGDOWN{¹®´ÝÈû}:
         begin
            if((Race = 91) and (CurrentAction = SM_LIGHTING)) then PlaySound (2406) // ¼³ÀÎ´ëÃæ Attact2 »ç¿îµå
            else if((Race = 92) and (CurrentAction = SM_LIGHTING)) then PlaySound (2416) // ÁÖ¸¶°Ý·ÚÀå Attact2 »ç¿îµå
            else if((Race = 93) and (CurrentAction = SM_LIGHTING)) then PlaySound (2426) // È¯¿µÇÑÈ£ Attact2 »ç¿îµå
            else if((Race = 94) and (CurrentAction = SM_LIGHTING)) then PlaySound (2436) // °Å¹Ì Attact2 »ç¿îµå
            else if attacksound >= 0 then PlaySound (attacksound);
         end;
//      SM_ALIVE, SM_DIGUP{µîÀå,¹®¿­¸²}:
      SM_DIGUP{µîÀå,¹®¿­¸²}: //####
         begin
            PlaySound (appearsound);
         end;
      SM_SPELL:
         begin
            PlaySound (magicstartsound);
         end;
   end;
end;

procedure  TActor.RunActSound (frame: integer);
begin
   if borunsound then begin
      if Race = 0 then begin
         case CurrentAction of
            SM_THROW, SM_HIT, SM_HIT+1, SM_HIT+2:
               if frame = 2 then begin
                  PlaySound (weaponsound);
                  borunsound := FALSE;
               end;
            SM_POWERHIT:
               if frame = 2 then begin
                  PlaySound (weaponsound);
                  if Sex = 0 then PlaySound (s_yedo_man)
                  else PlaySound (s_yedo_woman);
                  borunsound := FALSE;
               end;
            SM_LONGHIT:
               if frame = 2 then begin
                  PlaySound (weaponsound);
                  PlaySound (s_longhit);
                  borunsound := FALSE; //ÇÑ¹ø¸¸ ¼Ò¸®³¿
               end;
            SM_WIDEHIT:
               if frame = 2 then begin
                  PlaySound (weaponsound);
                  PlaySound (s_widehit);
                  borunsound := FALSE;
               end;
            SM_FIREHIT:
               if frame = 2 then begin
                  PlaySound (weaponsound);
                  PlaySound (s_firehit);
                  borunsound := FALSE;
               end;
            SM_CROSSHIT:
               if frame = 2 then begin
                  PlaySound (weaponsound);
                  PlaySound (s_crosshit);
                  borunsound := FALSE; //ÇÑ¹ø¸¸ ¼Ò¸®³¿
               end;
            SM_TWINHIT:
               if frame = 2 then begin
                  PlaySound (weaponsound);
                  PlaySound (s_twinhit);
                  borunsound := FALSE;
               end;
         end;
      end else begin
         if Race = 50 then begin
         end else begin
          //(** »õ »ç¿îµå
            if (CurrentAction = SM_WALK) or (CurrentAction = SM_TURN) then begin
               if (frame = 1) and (Random(8) = 1) then begin
                  PlaySound (normalsound);
                  borunsound := FALSE; //ÇÑ¹ø¸¸ ¼Ò¸®³¿
               end;
            end;
            if CurrentAction = SM_HIT then begin
               if (frame = 3) and (attacksound >= 0) then begin
                  PlaySound (weaponsound);
                  borunsound := FALSE;
               end;
            end;
            case Appearance of
               80: //°ü¹ÚÁã
                  begin
                     if CurrentAction = SM_NOWDEATH then begin
                        if (frame = 2) then begin
                           PlaySound (die2sound);
                           borunsound := FALSE; //ÇÑ¹ø¸¸ ¼Ò¸®³¿
                        end;
                     end;
                  end;
            end;
         end; //*)

      end;
   end;
end;

procedure  TActor.RunFrameAction (frame: integer);
begin
end;

procedure  TActor.ActionEnded;
begin
end;

procedure TActor.Run;
   function MagicTimeOut: Boolean;
   begin
//      if self = Myself then begin
         Result := GetTickCount - WaitMagicRequest > 3000;
//      end else
//         Result := GetTickCount - WaitMagicRequest > 2000;
      if Result then
         CurMagic.ServerMagicCode := 0;
   end;
var
   prv: integer;
   frametimetime: longword;
   bofly: Boolean;
begin

   if (CurrentAction = SM_WALK) or
      (CurrentAction = SM_BACKSTEP) or
      (CurrentAction = SM_RUN) or
      (CurrentAction = SM_RUSH) or
      (CurrentAction = SM_RUSHKUNG)
   then exit;

   msgmuch := FALSE;
   if self <> Myself then begin
      if MsgList.Count >= 2 then msgmuch := TRUE;
   end;

   //»ç¿îµå È¿°ú
   RunActSound (currentframe - startframe);
   RunFrameAction (currentframe - startframe);

   prv := currentframe;
   if CurrentAction <> 0 then begin
      if (currentframe < startframe) or (currentframe > endframe) then
         currentframe := startframe;

//      if (self <> Myself) and (BoUseMagic) then begin
//         frametimetime := Round(frametime / 1.8);
//      end else begin
         if msgmuch then frametimetime := Round(frametime * 2 / 3)
         else frametimetime := frametime; //2004/04/07 ¼Óµµ°ü·Ã ¼öÁ¤
//      end;

      if GetTickCount - starttime > frametimetime then begin
         if currentframe < endframe then begin
            //¸¶¹ýÀÎ °æ¿ì ¼­¹öÀÇ ½ÅÈ£¸¦ ¹Þ¾Æ, ¼º°ø/½ÇÆÐ¸¦ È®ÀÎÇÑÈÄ
            //¸¶Áö¸·µ¿ÀÛÀ» ³¡³½´Ù.
            if BoUseMagic then begin
               if (CurEffFrame = SpellFrame-2) or (MagicTimeOut) then begin //±â´Ù¸² ³¡
                  if (CurMagic.ServerMagicCode >= 0) or (MagicTimeOut) then begin //¼­¹ö·Î ºÎÅÍ ¹ÞÀº °á°ú. ¾ÆÁ÷ ¾È¿ÔÀ¸¸é ±â´Ù¸²
                    Inc (currentframe);
                    Inc (CurEffFrame);
                    starttime := GetTickCount;
                  end;
               end else begin
                   if currentframe < endframe - 1 then Inc (currentframe);
                   Inc (CurEffFrame);
                   starttime := GetTickCount;
               end;
            end else begin
               Inc (currentframe);
               starttime := GetTickCount;
            end;

         end else begin
            if BoDelActionAfterFinished then begin
               //ÀÌ µ¿ÀÛÈÄ »ç¶óÁü.
               BoDelActor := TRUE;
            end;
            //µ¿ÀÛÀÌ ³¡³².
            if self = Myself then begin
               //ÁÖÀÎ°ø ÀÎ°æ¿ì
               if FrmMain.ServerAcceptNextAction then begin
                  ActionEnded;
                  CurrentAction := 0;
                  BoUseMagic := FALSE;
               end;
            end else begin
               ActionEnded;
               CurrentAction := 0; //µ¿ÀÛ ¿Ï·á
               BoUseMagic := FALSE;
            end;
         end;
         if BoUseMagic then begin
            //¸¶¹ýÀ» ¾²´Â °æ¿ì
            if CurEffFrame = SpellFrame-1 then begin //¸¶¹ý ¹ß»ç ½ÃÁ¡
               //¸¶¹ý ¹ß»ç
               if CurMagic.ServerMagicCode > 0 then begin
                  with CurMagic do
                     PlayScene.NewMagic (self,
                                      ServerMagicCode,
                                      EffectNumber,
                                      XX,
                                      YY,
                                      TargX,
                                      TargY,
                                      Target,
                                      EffectType,
                                      Recusion,
                                      AniTime,
                                      bofly);
                  if bofly then
                     PlaySound (magicfiresound)
                  else
                     PlaySound (magicexplosionsound);
               end;
               //LatestSpellTime := GetTickCount;
               CurMagic.ServerMagicCode := 0;
            end;
         end;
      end;
      if Appearance in [0, 1, 43] then currentdefframe := -10
      else currentdefframe := 0;
      defframetime := GetTickCount;
   end else begin
      if GetTickCount - smoothmovetime > 200 then begin
         if GetTickCount - defframetime > 500 then begin
            defframetime := GetTickCount;
            Inc (currentdefframe);
            if currentdefframe >= defframecount then
               currentdefframe := 0;
         end;
         DefaultMotion;
      end;
   end;

   if prv <> currentframe then begin
      loadsurfacetime := GetTickCount;
      LoadSurface;
   end;

end;

function  TActor.Move (step: integer; out boChange: Boolean): Boolean;
var
   prv, curstep, maxstep: integer;
   fastmove, normmove: Boolean;
begin
   Result := FALSE;
   fastmove := FALSE;
   normmove := FALSE;
   boChange := False;
   if (CurrentAction = SM_BACKSTEP) then //or (CurrentAction = SM_RUSH) or (CurrentAction = SM_RUSHKUNG) then
      fastmove := TRUE;
   if (CurrentAction = SM_RUSH) or (CurrentAction = SM_RUSHKUNG) then
      normmove := TRUE;
   // 2003/07/03 ÀÌº¥Æ®¿ë ÄÚµå
//   if ((UseItems[U_DRESS].S.Shape = 10) or
//       (UseItems[U_DRESS].S.Shape = 12) )and (UseItems[U_DRESS].Dura > 0) then begin
//      fastmove := TRUE;
//   end;

   if (self = Myself) and (not fastmove) and (not normmove) then begin
      BoMoveSlow := FALSE;
      BoMoveSlow2 := FALSE;      
      BoAttackSlow := FALSE;
      MoveSlowLevel := 0;
      MoveSlowValue := 0;
      if Abil.Weight > Abil.MaxWeight then begin
         MoveSlowLevel := Abil.Weight div Abil.MaxWeight;
         BoMoveSlow := TRUE;
      end;
      if Abil.WearWeight > Abil.MaxWearWeight then begin
         MoveSlowLevel := MoveSlowLevel + Abil.WearWeight div Abil.MaxWearWeight;
         BoMoveSlow := TRUE;
      end;
      if Abil.HandWeight > Abil.MaxHandWeight then begin
         BoAttackSlow := TRUE;
      end;
      // 2003/07/15 »óÅÂÀÌ»ó Ãß°¡ µÐÈ­ ... ÀÌµ¿ ¼Óµµ, °ø°Ý ¼Óµµ µÐÈ­
      if State and $08000000 <> 0 then begin        //POISON_SLOW
         MoveSlowLevel := MoveSlowLevel + 5;
         MoveSlowValue := 1; //ÀúÁÖ¼ú ½½·Î¿ì ¼Óµµ Á¶Á¤
         BoMoveSlow2 := TRUE;
         BoAttackSlow := TRUE;
      end;

      if BoMoveSlow and (SkipTick < MoveSlowLevel) then begin
         Inc (SkipTick); //ÇÑ¹ø ½®´Ù.
         exit;
      end else begin
         SkipTick := 0;
      end;

      if BoMoveSlow2 and (SkipTick2 > MoveSlowValue) then
      begin
         SkipTick2 := 0;
         exit;
      end else begin
         Inc (SkipTick2);
      end;

      //»ç¿îµå È¿°ú
      if (CurrentAction = SM_WALK) or
         (CurrentAction = SM_BACKSTEP) or
         (CurrentAction = SM_RUN) or
         (CurrentAction = SM_RUSH) or
         (CurrentAction = SM_RUSHKUNG)
      then begin
         case (currentframe - startframe) of
            1: PlaySound (footstepsound);
            4: PlaySound (footstepsound + 1);
         end;
      end;
   end;

   Result := FALSE;
   msgmuch := FALSE;
   if self <> Myself then begin
      if MsgList.Count >= 2 then msgmuch := TRUE;
   end;
   prv := currentframe;
   //°È±â ¶Ù±â
   if (CurrentAction = SM_WALK) or
      (CurrentAction = SM_RUN) or
      (CurrentAction = SM_RUSH) or
      (CurrentAction = SM_RUSHKUNG)
   then begin
      if (currentframe < startframe) or (currentframe > endframe) then begin
         currentframe := startframe - 1;
      end;
      if currentframe < endframe then begin
         Inc (currentframe);
         if msgmuch and not normmove then //or fastmove then
            if currentframe < endframe then
               Inc (currentframe);

         //ºÎµå·´°Ô ÀÌµ¿ÇÏ°Ô ÇÏ·Á°í
         curstep := currentframe-startframe + 1;
         maxstep := endframe-startframe + 1;
         Shift (Dir, movestep, curstep, maxstep);
      end;
      if currentframe >= endframe then begin
         if self = Myself then begin
            if FrmMain.ServerAcceptNextAction then begin
               CurrentAction := 0;     //¼­¹öÀÇ ½ÅÈ£¸¦ ¹ÞÀ¸¸é ´ÙÀ½ µ¿ÀÛ
               LockEndFrame := TRUE;   //¼­¹öÀÇ½ÅÈ£°¡ ¾ø¾î¼­ ¸¶Áö¸·ÇÁ·¡ÀÓ¿¡¼­ ¸ØÃã
               smoothmovetime := GetTickCount;
            end;
         end else begin
            CurrentAction := 0; //µ¿ÀÛ ¿Ï·á
            LockEndFrame := TRUE;
            smoothmovetime := GetTickCount;
         end;
         Result := TRUE;
      end;
      if CurrentAction = SM_RUSH then begin
         if self = Myself then begin
            DizzyDelayStart := GetTickCount;
            DizzyDelayTime := 300; //µô·¹ÀÌ
         end;
      end;
      if CurrentAction = SM_RUSHKUNG then begin
         if currentframe >= endframe - 3 then begin
            XX := actbeforex;
            YY := actbeforey;
            Rx := XX;
            Ry := YY;
            CurrentAction := 0;
            LockEndFrame := TRUE;
            //smoothmovetime := GetTickCount;
         end;
      end;
      Result := TRUE;
   end;
   //µÞ°ÉÀ½Áú
   if (CurrentAction = SM_BACKSTEP) then begin
      if (currentframe > endframe) or (currentframe < startframe) then begin
         currentframe := endframe + 1;
      end;
      if currentframe > startframe then begin
         Dec (currentframe);
         if msgmuch or fastmove then
            if currentframe > startframe then Dec (currentframe);

         //ºÎµå·´°Ô ÀÌµ¿ÇÏ°Ô ÇÏ·Á°í
         curstep := endframe - currentframe + 1;
         maxstep := endframe - startframe + 1;
         Shift (GetBack(Dir), movestep, curstep, maxstep);
      end;
      if currentframe <= startframe then begin
         if self = Myself then begin
            //if FrmMain.ServerAcceptNextAction then begin
               CurrentAction := 0;     //¼­¹öÀÇ ½ÅÈ£¸¦ ¹ÞÀ¸¸é ´ÙÀ½ µ¿ÀÛ
               LockEndFrame := TRUE;   //¼­¹öÀÇ½ÅÈ£°¡ ¾ø¾î¼­ ¸¶Áö¸·ÇÁ·¡ÀÓ¿¡¼­ ¸ØÃã
               smoothmovetime := GetTickCount;

               //µÚ·Î ¹Ð¸° ´ÙÀ½ ÇÑµ¿¾È ¸ø ¿òÁ÷ÀÎ´Ù.
               DizzyDelayStart := GetTickCount;
               DizzyDelayTime := 1000; //1ÃÊ µô·¹ÀÌ
            //end;
         end else begin
            CurrentAction := 0; //µ¿ÀÛ ¿Ï·á
            LockEndFrame := TRUE;
            smoothmovetime := GetTickCount;
         end;
         Result := TRUE;
      end;
      Result := TRUE;
   end;
   if prv <> currentframe then begin
      loadsurfacetime := GetTickCount;
      LoadSurface;
      boChange := TRUE;
   end;
end;

procedure TActor.MoveFail;
begin
   CurrentAction := 0; //µ¿ÀÛ ¿Ï·á
   LockEndFrame := TRUE;
   Myself.XX := oldx;
   Myself.YY := oldy;
   Myself.Dir := olddir;
   CleanUserMsgs;
end;

function  TActor.CanCancelAction: Boolean;
begin
   Result := FALSE;
   if CurrentAction = SM_HIT then
      if not BoUseEffect then
         Result := TRUE;
end;

procedure TActor.CancelAction;
begin
   CurrentAction := 0; //µ¿ÀÛ ¿Ï·á
   LockEndFrame := TRUE;
end;

procedure TActor.CleanCharMapSetting (x, y: integer);
begin
   Myself.XX := x;
   Myself.YY := y;
   Myself.RX := x;
   Myself.RY := y;
   oldx := x;
   oldy := y;
   CurrentAction := 0;
   currentframe := -1;
   CleanUserMsgs;
end;

procedure TActor.Say (str: string);
var
   i, len, aline, n: integer;
   dline, temp: string;
   loop: Boolean;
const
   MAXWIDTH = 150;
begin
   SayTime := GetTickCount;
   SayLineCount := 0;

   n := 0;
   loop := TRUE;
   while loop do begin
      temp := '';
      i := 1;
      len := Length (str);
      while TRUE do begin
         if i > len then begin
            loop := FALSE;
            break;
         end;
         if byte (str[i]) >= 128 then begin
            temp := temp + str[i];
            Inc (i);
            if i <= len then temp := temp + str[i]
            else begin
               loop := FALSE;
               break;
            end;
         end else
            temp := temp + str[i];

         aline := FrmMain.Canvas.TextWidth (temp);
         if aline > MAXWIDTH then begin
            Saying[n] := temp;
            SayWidths[n] := aline;
            Inc (SayLineCount);
            Inc (n);
            if n >= MAXSAY then begin
               loop := FALSE;
               break;
            end;
            str := Copy (str, i+1, Len-i);
            temp := '';
            break;
         end;
         Inc (i);
      end;
      if temp <> '' then begin
         if n < MAXWIDTH then begin
            Saying[n] := temp;
            SayWidths[n] := FrmMain.Canvas.TextWidth (temp);
            Inc (SayLineCount);
         end;
      end;
   end;
end;



{============================== NPCActor =============================}


// 2003/07/15 ½Å±Ô NPC Ãß°¡
constructor TNpcActor.Create;
begin
   inherited Create;
   EffectSurface := nil;
   BoUseEffect   := FALSE;
   PlaySnow      := False;
end;

procedure TNpcActor.CalcActorFrame;
var
   pm: PTMonsterAction;
   haircount: integer;
begin
   BoUseMagic := FALSE;
   currentframe := -1;

   BodyOffset := GetNpcOffset (Appearance);

   pm := RaceByPm (Race, Appearance);
   if pm = nil then exit;
   Dir := Dir mod 3;  //¹æÇâÀº 0, 1, 2 ¹Û¿¡ ¾øÀ½..
   case CurrentAction of
      SM_TURN: //NewNpc
         begin
            if Appearance = 57 then begin
               Dir := 0;
               pm.ActStand.frame := 10;
               pm.ActStand.ftime := 120;
            end
            else if Appearance in [58,60,69..74,78..80] then Dir := 0;

            startframe := pm.ActStand.start + Dir * (pm.ActStand.frame + pm.ActStand.skip);
            endframe := startframe + pm.ActStand.frame - 1;
            frametime := pm.ActStand.ftime;
            starttime := GetTickCount;
            defframecount := pm.ActStand.frame;
            Shift (Dir, 0, 0, 1);

            if ((Appearance = 33) or (Appearance = 34)) and (not BoUseEffect) then begin
               BoUseEffect   := TRUE;
               effectstart   := 30;
               effectframe   := effectstart;
               effectend     := effectstart + 9;
               effectstarttime := GetTickCount;
               effectframetime := 300;
            end
            else if Appearance in [42..47] then begin //FireDragon
               startframe := 20;
               endframe := 10;
               BoUseEffect   := TRUE;
               effectstart   := 0;
               effectframe   := 0;
               effectend     := 19;
               effectstarttime := GetTickCount;
               effectframetime := 100;
            end
            else if Appearance = 51 then begin //2004/05/27 50LevelQuest ¹Î±Ô
               BoUseEffect   := TRUE;
               effectstart   := 60;
               effectframe   := effectstart;
               effectend     := effectstart + 7;
               effectstarttime := GetTickCount;
               effectframetime := 500;
            end
            else if Appearance in [61..64] then begin //ºñ¿ù½ÅÀü ºÒ²É
               startframe := 6;
               endframe := 7;
               BoUseEffect   := TRUE;
               effectstart   := 0;
               effectframe   := 0;
               effectend     := 4;
               effectstarttime := GetTickCount;
               effectframetime := 100;
            end
            else if Appearance = 65 then begin //¸ð´ÚºÒ
               startframe := 8;
               endframe := 9;
               BoUseEffect   := TRUE;
               effectstart   := 0;
               effectframe   := 0;
               effectend     := 5;
               effectstarttime := GetTickCount;
               effectframetime := 100;
            end
            else if Appearance = 66 then begin
               startframe := 0;
               endframe := 19;
               frametime := 200;
               starttime := GetTickCount;
               defframecount := 19;
               BoUseEffect   := TRUE;
               effectstart   := 20;
               effectframe   := effectstart;
               effectend     := effectstart + 19;
               effectstarttime := GetTickCount;
               effectframetime := 200;
            end

         end;
      SM_HIT:
         begin
            // 2003/07/15 ½Å±Ô NPC Ãß°¡
            if Appearance = 57 then begin
               Dir := 0;
               pm.ActStand.frame := 10;
               pm.ActStand.ftime := 120;
            end
            else if Appearance in [58,60,69..74,78..80] then Dir := 0;

            if Appearance in [33,34,52,55..60,68..77] then begin //Çàµ¿ ¸ð¼Ç¾øÀ½, ¼­ÀÖ±â¸ð¼Ç¸¸ ÀÖÀ½
//            if Appearance = 55 then DScreen.AddChatBoardString ('Appearance = 55', clYellow, clRed);
               startframe := pm.ActStand.start + Dir * (pm.ActStand.frame + pm.ActStand.skip);
               endframe   := startframe + pm.ActStand.frame - 1;
               frametime  := pm.ActStand.ftime;
               starttime  := GetTickCount;
               defframecount := pm.ActStand.frame;
            end else begin
               startframe := pm.ActAttack.start + Dir * (pm.ActAttack.frame + pm.ActAttack.skip);
               endframe := startframe + pm.ActAttack.frame - 1;
               if Appearance = 67 then endframe := startframe + 5;
               frametime := pm.ActAttack.ftime;
               starttime := GetTickCount;
               if Appearance = 51 then begin //2004/05/27 50LevelQuest ¹Î±Ô
                  BoUseEffect   := TRUE;
                  effectstart   := 60;
                  effectframe   := effectstart;
                  effectend     := effectstart + 7;
                  effectstarttime := GetTickCount;
                  effectframetime := 500;
               end
            end;
            if Appearance in [61..64] then begin //ºñ¿ù½ÅÀü ºÒ²É
               startframe := 6;
               endframe := 7;
               BoUseEffect   := TRUE;
               effectstart   := 0;
               effectframe   := 0;
               effectend     := 4;
               effectstarttime := GetTickCount;
               effectframetime := 100;
            end
            else if Appearance = 65 then begin //¸ð´ÚºÒ
               startframe := 8;
               endframe := 9;
               BoUseEffect   := TRUE;
               effectstart   := 0;
               effectframe   := 0;
               effectend     := 5;
               effectstarttime := GetTickCount;
               effectframetime := 100;
            end
            else if Appearance = 66 then begin //Å©¸®½º¸¶½ºÆ®¸®
               startframe := 0;
               endframe := 19;
               frametime := 200;
               starttime := GetTickCount;
               defframecount := 19;
               BoUseEffect   := TRUE;
               effectstart   := 20;
               effectframe   := effectstart;
               effectend     := effectstart + 19;
               effectstarttime := GetTickCount;
               effectframetime := 200;
            end;
         end;
      SM_DIGUP:
         begin
            if Appearance = 52 then begin //2004/12/14 ´«»ç¶÷
               PlaySnow := True;
               SnowStartTime := GetTickCount + 23000;
               Randomize;
               SilenceSound;
               PlaySound (146+Random(7));
//   DScreen.AddChatBoardString ('´«»ç¶÷ SM_DIGUP PlaySong=> '+IntToStr(146+Random(7)), clYellow, clRed);
               BoUseEffect   := TRUE;
               effectstart   := 60;
               effectframe   := effectstart;
               effectend     := effectstart + 11;
               effectstarttime := GetTickCount;
               effectframetime := 100;
            end;
         end;
   end;
   if Appearance in [35..41,48..50,52..55,57..65,69..74,78..80] then Dir := 0; //ÇÑ¹æÇâ °íÁ¤ NewNpc
end;

function  TNpcActor.GetDefaultFrame (wmode: Boolean): integer;
var
   cf, dr: integer;
   pm: PTMonsterAction;
begin
   pm := RaceByPm (Race, Appearance);
   if pm = nil then exit;
   Dir := Dir mod 3;  //¹æÇâÀº 0, 1, 2 ¹Û¿¡ ¾øÀ½..

   if Appearance in [35..41,48..50,52..55,57..65,69..74,78..80] then Dir := 0; //ÇÑ¹æÇâ °íÁ¤ NewNpc
//   if Appearance in [35,36,37,38,39,40,41,48,49,50,52,53,54,55,57,58] then Dir := 0;

   if currentdefframe < 0 then cf := 0
   else if currentdefframe >= pm.ActStand.frame then cf := 0
   else cf := currentdefframe;
   Result := pm.ActStand.start + Dir * (pm.ActStand.frame + pm.ActStand.skip) + cf;

   if Appearance in [61..64] then begin //ºñ¿ù½ÅÀü ºÒ²É
      Result := 6;
      BoUseEffect   := TRUE;
   end
   else if Appearance =65 then begin //¸ð´ÚºÒ
      Result := 8;
      BoUseEffect   := TRUE;
   end
   else if Appearance = 66 then begin  //Å©¸®½º¸¶½ºÆ®¸®
      Result := cf;
      BoUseEffect   := TRUE;
   end;
end;

procedure TNpcActor.LoadSurface;
begin
   case Race of
      //»óÀÎ Npc
      50: BodySurface := g_WNpcImg.GetCachedImageEx (BodyOffset + currentframe, px, py, spx, spy, stype);
   end;

   if Appearance in [42..47,61..65] then begin // BodySurface ÇÊ¿ä¾øÀ½ ºÒÀÇ°æ¿ì ÀÌÆåÆ®¸¸ ÇÊ¿ä (Å¾Àº Object)
      BodySurface := nil;
   end;

   if BoUseEffect then begin // ½Ã°ø¼®,È­·ÔºÒ,Å¾ºÒ,±Í½Ånpc
      if Appearance in [33,34] then begin // È­¸é¿¡ ³ªÅ¸³ª´Â À§Ä¡ º¸Á¤
         EffectSurface := g_WNpcImg.GetCachedImage (BodyOffset + effectframe, ax, ay);
      end
      else if Appearance = 42 then begin// ºÒÇ×¾Æ¸®(¿ì) Object¿Í À§Ä¡¸¦ °¢ÀÚ ¸ÂÃç¾ßÇÔ.  FireDragon
         EffectSurface := g_WNpcImg.GetCachedImage (BodyOffset + effectframe, ax, ay);
         ax := ax + 71;
         ay := ay + 5;
      end
      else if Appearance = 43 then begin// ºÒÇ×¾Æ¸®(ÁÂ)
         EffectSurface := g_WNpcImg.GetCachedImage (BodyOffset + effectframe, ax, ay);
         ax := ax + 71;
         ay := ay + 37;
      end
      else if Appearance = 44 then begin// Å¾ºÒ(¿ìÇÏ)
         EffectSurface := g_WNpcImg.GetCachedImage (BodyOffset + effectframe, ax, ay);
         ax := ax + 7;
         ay := ay - 12;
      end
      else if Appearance = 45 then begin// Å¾ºÒ(¿ì»ó)
         EffectSurface := g_WNpcImg.GetCachedImage (BodyOffset + effectframe, ax, ay);
         ax := ax + 6;
         ay := ay - 12;
      end
      else if Appearance = 46 then begin// Å¾ºÒ(ÁÂÇÏ)
         EffectSurface := g_WNpcImg.GetCachedImage (BodyOffset + effectframe, ax, ay);
         ax := ax + 7;
         ay := ay - 12;
      end
      else if Appearance = 47 then begin// Å¾ºÒ(ÁÂ»ó)
         EffectSurface := g_WNpcImg.GetCachedImage (BodyOffset + effectframe, ax, ay);
         ax := ax + 8;
         ay := ay - 12;
      end
      else if Appearance = 51 then begin// ±Í½Å npc
         EffectSurface := g_WNpcImg.GetCachedImage (BodyOffset + effectframe, ax, ay);
      end
      else if Appearance = 52 then begin// ´«»ç¶÷
         EffectSurface := g_WNpcImg.GetCachedImage (BodyOffset + effectframe, ax, ay);
      end
      else if Appearance = 61 then begin// ºñ¿ù½ÅÀü ºÒ²É(ÁÂ»ó)
         EffectSurface := g_WNpcImg.GetCachedImage (BodyOffset + effectframe, ax, ay);
         ax := ax + 25;
         ay := ay - 8;
      end
      else if Appearance = 62 then begin// ºñ¿ù½ÅÀü ºÒ²É(¿ì»ó)
         EffectSurface := g_WNpcImg.GetCachedImage (BodyOffset + effectframe, ax, ay);
         ax := ax + 7;
         ay := ay - 7;
      end
      else if Appearance = 63 then begin// ºñ¿ù½ÅÀü ºÒ²É(ÁÂÇÏ)
         EffectSurface := g_WNpcImg.GetCachedImage (BodyOffset + effectframe, ax, ay);
         ax := ax - 4;
         ay := ay + 8;
      end
      else if Appearance = 64 then begin// ºñ¿ù½ÅÀü ºÒ²É(¿ìÇÏ)
         EffectSurface := g_WNpcImg.GetCachedImage (BodyOffset + effectframe, ax, ay);
         ax := ax - 11;
         ay := ay + 8;
      end
      else if Appearance = 65 then begin// ¸ð´ÚºÒ
         EffectSurface := g_WNpcImg.GetCachedImage (BodyOffset + effectframe, ax, ay);
      end
      else if Appearance = 66 then begin// Å©¸®½º¸¶½ºÆ®¸®
         EffectSurface := g_WNpcImg.GetCachedImage (BodyOffset + effectframe, ax, ay);
      end;

   end;

end;

procedure TNpcActor.Run;
var
   prv : integer;
   effectframetimetime : longword;
begin
   inherited Run;
   // 2003/07/15 ½Å±Ô NPC Ãß°¡
   prv := effectframe;
   if BoUseEffect then begin
      if msgmuch then effectframetimetime := Round(effectframetime * 2 / 3)
      else effectframetimetime := effectframetime;
      if GetTickCount - effectstarttime > effectframetimetime then begin
         effectstarttime := GetTickCount;
         if effectframe < effectend then begin
            Inc (effectframe);
         end else begin
            if PlaySnow then begin
               if SnowStartTime < GetTickCount then begin
                  BoUseEffect := False;
                  PlaySnow    := False;
                  SnowStartTime := GetTickCount;
               end;
               effectframe := effectstart;
            end
            else effectframe := effectstart;
            effectstarttime := GetTickCount;
         end;
      end;
   end;
   if (prv <> effectframe) then begin
      loadsurfacetime := GetTickCount;
      LoadSurface;
   end;
end;

// 2003/07/15 ½Å±Ô NPC Ãß°¡
procedure  TNpcActor.DrawChr (dsurface: TDirectDrawSurface; dx, dy: integer; blend: Boolean; WingDraw: Boolean );
var
   idx, ax, ay: integer;
   d: TDirectDrawSurface;
   ceff: TColorEffect;
   wimg: TWMImages;
begin
   Dir := Dir mod 3;  //¹æÇâÀº 0, 1, 2 ¹Û¿¡ ¾øÀ½..
   if GetTickCount - loadsurfacetime > 60 * 1000 then begin
      loadsurfacetime := GetTickCount;
      LoadSurface;
   end;

   ceff := GetDrawEffectValue;

   if BodySurface <> nil then begin
//      if Appearance = 51 then begin //±Í½Å npc
//         DrawEffSurface (dsurface, BodySurface, dx + px + ShiftX, dy + py + ShiftY, True, ceff);
//         DrawEffSurface (dsurface, BodySurface, dx + px + ShiftX, dy + py + ShiftY, True, ceff);
//      end
//      else
     if not (Appearance in [51..57,59,71..75,87]) then
       DrawBlendShadow (dsurface, dx + spx + ShiftX, dy + spy + ShiftY, stype, BodySurface, g_boShadowBlend);

         DrawEffSurface (dsurface, BodySurface, dx + px + ShiftX, dy + py + ShiftY, blend, ceff);
   end;
// inherited DrawChr(dsurface, dx, dy, blend);
end;

procedure TNpcActor.DrawEff (dsurface: TDirectDrawSurface; dx, dy: integer);
begin
   if BoUseEffect then
      if EffectSurface <> nil then begin
         DrawBlend (dsurface,
                    dx + ax + ShiftX,
                    dy + ay + ShiftY,
                    EffectSurface, 1);
      end;
end;


{============================== HUMActor =============================}

//            »ç¶÷

{-------------------------------}


constructor THumActor.Create;
begin
   inherited Create;
   HairSurface := nil;
   WeaponSurface := nil;
   WingSurface := nil;
   WeaponEffectSurface := nil;
   BoWeaponEffect := FALSE;

   WingFrameTime := 150;
   WingStartTime := GetTickCount;
   WingCurrentFrame := 0;
   WingOffset := 0;

   WeaponEffectFrameTime := 150;
   WeaponEffectStartTime := GetTickCount;
   WeaponEffectCurrentFrame := 0;
   WeaponEffectOffset := HUMANFRAME*4;

   H50LevelEffectSurface := nil;
   H50LevelEffectFrameTime := 150;
   H50LevelEffectStartTime := GetTickCount;
   H50LevelEffectCurrentFrame := 0;
   H50LevelEffectOffset := 312;

   FoodStickDayEffectSurface := nil;
   FoodStickDayEffectSurface2 := nil;
   FoodStickDayEffectFrameTime := 120;
   FoodStickDayEffectStartTime := GetTickCount;
   FoodStickDayEffectCurrentFrame := 0;
   FoodStickDayEffectOffset := 440;
   FoodStickDayEffectOffset2 := 420;

{   HWriterEffectSurface := nil;
   HWriterEffectFrameTime := 90;
   HWriterEffectStartTime := GetTickCount;
   HWriterEffectCurrentFrame := 0;
   HWriterEffectOffset := 328;}

end;

destructor THumActor.Destroy;
begin
   inherited Destroy;
end;

procedure THumActor.CalcActorFrame;
var
   haircount: integer;
begin
   BoUseMagic := FALSE;
   BoHitEffect := FALSE;
   currentframe := -1;
   //human
   hair   := HAIRfeature (Feature);         //º¯°æµÈ´Ù.
//   dress  := DRESSfeature (Feature); //¹«ÅÂº¸½Ã ¿Ê°¥¾ÆÀÔÀ¸¸é ¹®Á¦°¡ µÊ, ±×·¡¼­ ÁÖ¼® Ã³¸®
//      DScreen.AddChatBoardString ('CalcActorFrame() dress=> '+IntToStr(dress), clYellow, clRed);
   weapon := WEAPONfeature (Feature);
   BodyOffset := HUMANFRAME * (Dress div 2); //Sex; //³²ÀÚ0, ¿©ÀÚ1

  if hair > 1 then
    HairOffset := HUMANFRAME * hair
  else
    HairOffset := -1;

//   haircount := g_WHairImg.ImageCount div HUMANFRAME div 2;
//   if hair > haircount-1 then hair := haircount-1;
//   hair := hair * 2;
//   if hair > 1 then
//      HairOffset := HUMANFRAME * (hair + Sex)
//   else HairOffset := -1;

   if weapon = 254 then
      WeaponOffset := HUMANFRAME * (weapon mod 10)
   else if weapon in [101..200] then
      WeaponOffset := HUMANFRAME * ((weapon - 101) mod 10)
   else
      WeaponOffset := HUMANFRAME * ((weapon - 1) mod 10);

   if dress = 18 then WingOffset := 0                  // ÃµÀÇ¹«ºÀ(³²)
   else if dress = 19 then WingOffset := HUMANFRAME    // ÃµÀÇ¹«ºÀ(¿©)
   else if dress = 20 then WingOffset := HUMANFRAME*2  // Ãµ·æºÒ»çÀÇ(³²)
   else if dress = 21 then WingOffset := HUMANFRAME*3 // Ãµ·æºÒ»çÀÇ(¿©)
   else if dress in [22,23] then WingOffset := 352; // 50·¹º§¿Ê

   //²âÊÔ
   if (Dress div 2) = 1 then WingOffset := 2180;

   if weapon = 254 then begin
     if sex = 0 then WeaponEffectOffset := 1900        // ÆÄ°üÁø°Ë ÀÌÆåÆ®(³²)
     else WeaponEffectOffset := 2900;
   end;
   if weapon = 76 then WeaponEffectOffset := HUMANFRAME*4        // ÆÄ°üÁø°Ë ÀÌÆåÆ®(³²)
   else if weapon = 77 then WeaponEffectOffset := HUMANFRAME*5;  // ÆÄ°üÁø°Ë ÀÌÆåÆ®(¿©)

   case CurrentAction of
      SM_TURN:
         begin
            startframe := HA.ActStand.start + Dir * (HA.ActStand.frame + HA.ActStand.skip);
            endframe := startframe + HA.ActStand.frame - 1;
            frametime := HA.ActStand.ftime;
            starttime := GetTickCount;
            defframecount := HA.ActStand.frame;
            Shift (Dir, 0, 0, endframe-startframe+1);
         end;
      SM_WALK,
      SM_BACKSTEP:
         begin
            startframe := HA.ActWalk.start + Dir * (HA.ActWalk.frame + HA.ActWalk.skip);
            endframe := startframe + HA.ActWalk.frame - 1;
            frametime := HA.ActWalk.ftime;
            starttime := GetTickCount;
            maxtick := HA.ActWalk.UseTick;
            curtick := 0;
            //WarMode := FALSE;
            movestep := 1;
            if CurrentAction = SM_BACKSTEP then
               Shift (GetBack(Dir), movestep, 0, endframe-startframe+1)
            else
               Shift (Dir, movestep, 0, endframe-startframe+1);
         end;
      SM_RUSH:
         begin
            if RushDir = 0 then begin
               RushDir := 1;
               startframe := HA.ActRushLeft.start + Dir * (HA.ActRushLeft.frame + HA.ActRushLeft.skip);
               endframe := startframe + HA.ActRushLeft.frame - 1;
               frametime := HA.ActRushLeft.ftime;
               starttime := GetTickCount;
               maxtick := HA.ActRushLeft.UseTick;
               curtick := 0;
               movestep := 1;
               Shift (Dir, 1, 0, endframe-startframe+1);
            end else begin
               RushDir := 0;
               startframe := HA.ActRushRight.start + Dir * (HA.ActRushRight.frame + HA.ActRushRight.skip);
               endframe := startframe + HA.ActRushRight.frame - 1;
               frametime := HA.ActRushRight.ftime;
               starttime := GetTickCount;
               maxtick := HA.ActRushRight.UseTick;
               curtick := 0;
               movestep := 1;
               Shift (Dir, 1, 0, endframe-startframe+1);
            end;
         end;
      SM_RUSHKUNG:
         begin
            startframe := HA.ActRun.start + Dir * (HA.ActRun.frame + HA.ActRun.skip);
            endframe := startframe + HA.ActRun.frame - 1;
            frametime := HA.ActRun.ftime;
            starttime := GetTickCount;
            maxtick := HA.ActRun.UseTick;
            curtick := 0;
            movestep := 1;
            Shift (Dir, movestep, 0, endframe-startframe+1);
         end;
      {SM_BACKSTEP:
         begin
            startframe := pm.ActWalk.start + (pm.ActWalk.frame - 1) + Dir * (pm.ActWalk.frame + pm.ActWalk.skip);
            endframe := startframe - (pm.ActWalk.frame - 1);
            frametime := pm.ActWalk.ftime;
            starttime := GetTickCount;
            maxtick := pm.ActWalk.UseTick;
            curtick := 0;
            movestep := 1;
            Shift (GetBack(Dir), movestep, 0, endframe-startframe+1);
         end;  }
      SM_SITDOWN:
         begin
            startframe := HA.ActSitdown.start + Dir * (HA.ActSitdown.frame + HA.ActSitdown.skip);
            endframe := startframe + HA.ActSitdown.frame - 1;
            frametime := HA.ActSitdown.ftime;
            starttime := GetTickCount;
         end;
      SM_RUN:
         begin
            startframe := HA.ActRun.start + Dir * (HA.ActRun.frame + HA.ActRun.skip);
            endframe := startframe + HA.ActRun.frame - 1;
            frametime := HA.ActRun.ftime;
            starttime := GetTickCount;
            maxtick := HA.ActRun.UseTick;
            curtick := 0;
            //WarMode := FALSE;
            if CurrentAction = SM_RUN then movestep := 2
            else movestep := 1;
            //movestep := 2;
            Shift (Dir, movestep, 0, endframe-startframe+1);
         end;
      SM_THROW:
         begin
            startframe := HA.ActHit.start + Dir * (HA.ActHit.frame + HA.ActHit.skip);
            endframe := startframe + HA.ActHit.frame - 1;
            frametime := HA.ActHit.ftime;
            starttime := GetTickCount;
            WarMode := TRUE;
            WarModeTime := GetTickCount;
            BoThrow := TRUE;
            Shift (Dir, 0, 0, 1);
         end;
      // 2003/03/15 ½Å±Ô¹«°ø
      SM_HIT, SM_POWERHIT, SM_LONGHIT, SM_WIDEHIT, SM_FIREHIT, SM_CROSSHIT, SM_TWINHIT:
         begin
//          DScreen.AddSysMsg (UserName +' ''s Current Action =' + IntToStr(CurrentAction));
            startframe := HA.ActHit.start + Dir * (HA.ActHit.frame + HA.ActHit.skip);
            endframe := startframe + HA.ActHit.frame - 1;
            frametime := HA.ActHit.ftime;
            starttime := GetTickCount;
            WarMode := TRUE;
            WarModeTime := GetTickCount;
            if (CurrentAction = SM_POWERHIT) then begin
               BoHitEffect := TRUE;
               MagLight := 2;
               HitEffectNumber := 1;
            end;
            if (CurrentAction = SM_LONGHIT) then begin
               BoHitEffect := TRUE;
               MagLight := 2;
               HitEffectNumber := 2;
            end;
            if (CurrentAction = SM_WIDEHIT) then begin
               BoHitEffect := TRUE;
               MagLight := 2;
               HitEffectNumber := 3;
            end;
            if (CurrentAction = SM_FIREHIT) then begin
               BoHitEffect := TRUE;
               MagLight := 2;
               HitEffectNumber := 4;
            end;
            // 2003/03/15 ½Å±Ô¹«°ø
            if (CurrentAction = SM_CROSSHIT) then begin
               BoHitEffect := TRUE;
               MagLight := 2;
               HitEffectNumber := 6;
            end;
            if (CurrentAction = SM_TWINHIT) then begin
               BoHitEffect := TRUE;
               MagLight := 2;
               HitEffectNumber := 7;
            end;

            Shift (Dir, 0, 0, 1);
         end;
      SM_HEAVYHIT:
         begin
            startframe := HA.ActHeavyHit.start + Dir * (HA.ActHeavyHit.frame + HA.ActHeavyHit.skip);
            endframe := startframe + HA.ActHeavyHit.frame - 1;
            frametime := HA.ActHeavyHit.ftime;
            starttime := GetTickCount;
            WarMode := TRUE;
            WarModeTime := GetTickCount;
            Shift (Dir, 0, 0, 1);
         end;
      SM_BIGHIT:
         begin
            startframe := HA.ActBigHit.start + Dir * (HA.ActBigHit.frame + HA.ActBigHit.skip);
            endframe := startframe + HA.ActBigHit.frame - 1;
            frametime := HA.ActBigHit.ftime;
            starttime := GetTickCount;
            WarMode := TRUE;
            WarModeTime := GetTickCount;
            Shift (Dir, 0, 0, 1);
         end;
      SM_SPELL:
         begin
            startframe := HA.ActSpell.start + Dir * (HA.ActSpell.frame + HA.ActSpell.skip);
            endframe := startframe + HA.ActSpell.frame - 1;
            frametime := HA.ActSpell.ftime;
            starttime := GetTickCount;
            CurEffFrame := 0;
            BoUseMagic := TRUE;
            case CurMagic.EffectNumber of
               22: begin //·Ú¼³È­
                     MagLight := 4;  //·Ú¼³È­
                     SpellFrame := 10; //·Ú¼³È­´Â 10 ÇÁ·¡ÀÓÀ¸·Î º¯°æ
                  end;
               26: begin //Å½±âÆÄ¿¬
                     MagLight := 2;
                     SpellFrame := 20;
                     frametime := frametime div 2;
                  end;
               35: begin //¹«±ØÁø±â PDS 2003-03-27
                     MagLight := 2;  //¹«±ØÁø±â
                     SpellFrame := 15; //¹«±ØÁø±â´Â 15 ÇÁ·¡ÀÓÀ¸·Î º¯°æ
                  end;
               43: begin // »çÀÚÈÄ
                     MagLight := 2;
                     SpellFrame := 20;
                     frametime := 70;
                  end;
               44: begin // °øÆÄ¼¶
                  startframe := HA.ActBigHit.start + Dir * (HA.ActBigHit.frame + HA.ActBigHit.skip);
                  endframe := startframe + HA.ActBigHit.frame - 1;
//                  frametime := HA.ActBigHit.ftime;
                  frametime := 50;   //2004/09/09 °øÆÄ¼¶ ¼Óµµ ºü¸£°Ô
                  starttime := GetTickCount;
                  MagLight := 2;
                  SpellFrame := 20;
                  SKillStartTime    := GetTickCount;
                  SKillCurrentFrame := 0;
//                  SKillFrametime    := 80;
                  SKillFrametime    := frametime;
                  BoHitEffect := TRUE;
                  HitEffectNumber := 8;
                  PlaySound (weaponsound);
                  PlaySound (s_twinhit);
                  end;
               45: begin //È­·æ±â¿°
                     MagLight := 2;
                     SpellFrame := 10;//23;
                     frametime := 100;//100;
                     FrmMain.UseNormalEffect (NE_FIRECIRCLE, self.XX, self.YY); // ¸¶¹ý ½ÃÁ¯Áß ¿òÁ÷ÀÏ¼ö ÀÖ°Ô ÇÏ·Á°í
                  end;
               47: begin // Æ÷½Â°Ë
                     MagLight := 2;
                     SpellFrame := 10;
                     frametime := 80;
                  end;
               else begin //.....  ´ëÈ¸º¹¼ú, »çÀÚÀ±È¸, ºù¼³Ç³
                  MagLight := 2;
                  SpellFrame := DEFSPELLFRAME;
               end;
            end;
            WaitMagicRequest := GetTickCount;
            WarMode := TRUE;
            WarModeTime := GetTickCount;
            Shift (Dir, 0, 0, 1);
         end;
      (*SM_READYFIREHIT:
         begin
            startframe := HA.ActFireHitReady.start + Dir * (HA.ActFireHitReady.frame + HA.ActFireHitReady.skip);
            endframe := startframe + HA.ActFireHitReady.frame - 1;
            frametime := HA.ActFireHitReady.ftime;
            starttime := GetTickCount;

            BoHitEffect := TRUE;
            HitEffectNumber := 4;
            MagLight := 2;

            CurGlimmer := 0;
            MaxGlimmer := 6;

            WarMode := TRUE;
            WarModeTime := GetTickCount;
            Shift (Dir, 0, 0, 1);
         end; *)
      SM_STRUCK:
         begin
            startframe := HA.ActStruck.start + Dir * (HA.ActStruck.frame + HA.ActStruck.skip);
            endframe := startframe + HA.ActStruck.frame - 1;
            frametime := struckframetime; //HA.ActStruck.ftime;
            starttime := GetTickCount;
            Shift (Dir, 0, 0, 1);

            genanicounttime := GetTickCount;
            CurBubbleStruck := 0;
         end;
      SM_NOWDEATH:
         begin
            startframe := HA.ActDie.start + Dir * (HA.ActDie.frame + HA.ActDie.skip);
            endframe := startframe + HA.ActDie.frame - 1;
            frametime := HA.ActDie.ftime;
            starttime := GetTickCount;
         end;
   end;
end;

procedure THumActor.DefaultMotion;
begin
   inherited DefaultMotion;
//   if (Dress in [22,23]) and (currentframe < 536) then begin
//      if GetTickCount - WingStartTime > 100 then begin
//         if WingCurrentFrame < 19 then
//            Inc (WingCurrentFrame)
//         else begin
//            if Not Bo50DressHEffect then Bo50DressHEffect := True
//            else Bo50DressHEffect := False;
//            WingCurrentFrame := 0;
//         end;
//         DScreen.AddSysMsg ('THumActor.DefaultMotion=>(Dress in [22,23])');
//         WingStartTime := GetTickCount;
//      end;
//      WingSurface := g_WEffectImg.GetCachedImage (WingOffset + WingCurrentFrame, epx, epy);
//   end
//   else if (Dress in [18,19,20,21]) and (currentframe < 64) then begin
//      if GetTickCount - WingStartTime > WingFrametime then begin
//         if WingCurrentFrame < 7 then
//            Inc (WingCurrentFrame)
//         else
//            WingCurrentFrame := 0;
////         DScreen.AddSysMsg ('THumActor.DefaultMotion=>(Dress in [Wing])');
//         WingStartTime := GetTickCount;
//      end;
//      WingSurface := g_WHumWing.GetCachedImage (WingOffset + Dir*8 + WingCurrentFrame, epx, epy);
//   end;
//   if currentframe > 535 then Bo50DressHEffect := False;

   if (Dress div 2) = 1 then begin
      if GetTickCount - WingStartTime > 100 then begin
         if WingCurrentFrame < 15 then
            Inc (WingCurrentFrame)
         else begin
            WingCurrentFrame := 0;
         end;
//         DScreen.AddSysMsg ('THumActor.DefaultMotion=>(Dress in [22,23])');
         WingStartTime := GetTickCount;
      end;
      WingSurface := g_WGameInter1.GetCachedImage (WingOffset + WingCurrentFrame, epx, epy);
   end;
         
//   if Bo50LevelEffect then begin
//      if GetTickCount - H50LevelEffectStartTime > H50LevelEffectFrameTime then begin
//         if H50LevelEffectCurrentFrame < 7 then
//            Inc (H50LevelEffectCurrentFrame)
//         else begin
//            H50LevelEffectCurrentFrame := 0;
//            Bo50LevelHEffect := Not Bo50LevelHEffect;
//         end;
//         H50LevelEffectStartTime := GetTickCount;
//      end;
//      H50LevelEffectSurface := g_WEffectImg.GetCachedImage (H50LevelEffectOffset + H50LevelEffectCurrentFrame, epx2, epy2);
//   end;

//   if FoodStickType > 0 then begin
//      if GetTickCount - FoodStickDayEffectStartTime > FoodStickDayEffectFrameTime then begin
//         if FoodStickDayEffectCurrentFrame < 14 then
//            Inc (FoodStickDayEffectCurrentFrame)
//         else begin
//            FoodStickDayEffectCurrentFrame := 0;
//         end;
//         FoodStickDayEffectStartTime := GetTickCount;
//      end;
//      FoodStickDayEffectSurface := g_WEffectImg.GetCachedImage (FoodStickDayEffectOffset + FoodStickDayEffectCurrentFrame, epx3, epy3);
//      FoodStickDayEffectSurface2 := g_WEffectImg.GetCachedImage (FoodStickDayEffectOffset2 + FoodStickDayEffectCurrentFrame, epx4, epy4);
//   end;

{   if BoWriterEffect then begin
      if GetTickCount - HWriterEffectStartTime > HWriterEffectFrameTime then begin
         if HWriterEffectCurrentFrame < 9 then
            Inc (HWriterEffectCurrentFrame)
         else begin
            HWriterEffectCurrentFrame := 0;
            BoWriterHEffect := Not BoWriterHEffect;
         end;
         HWriterEffectStartTime := GetTickCount;
      end;
      HWriterEffectSurface := FrmMain.WEffectImg.GetCachedImage (HWriterEffectOffset + HWriterEffectCurrentFrame, epx3, epy3);
   end;}

end;

function  THumActor.GetDefaultFrame (wmode: Boolean): integer;
var
   cf, dr: integer;
   pm: PTMonsterAction;
begin
   //GlimmingMode := FALSE;
   //dr := Dress div 2;            //HUMANFRAME * (dr)
   if Death then
      Result := HA.ActDie.start + Dir * (HA.ActDie.frame + HA.ActDie.skip) + (HA.ActDie.frame - 1)
   else
   if wmode then begin
      //GlimmingMode := TRUE;
      Result := HA.ActWarMode.start + Dir * (HA.ActWarMode.frame + HA.ActWarMode.skip);
   end else begin
      defframecount := HA.ActStand.frame;
      if currentdefframe < 0 then cf := 0
      else if currentdefframe >= HA.ActStand.frame then cf := 0 //HA.ActStand.frame-1
      else cf := currentdefframe;
      Result := HA.ActStand.start + Dir * (HA.ActStand.frame + HA.ActStand.skip) + cf;
   end;
end;

procedure  THumActor.RunFrameAction (frame: integer);
var
   meff: TMapEffect;
   event: TClEvent;
   mfly: TFlyingAxe;
begin
   BoHideWeapon := FALSE;
   if CurrentAction = SM_HEAVYHIT then begin
      if (frame = 5) and (BoDigFragment) then begin
         BoDigFragment := FALSE;
         meff := TMapEffect.Create (8 * Dir, 3, XX, YY);
//         meff.ImgLib := g_WEffectImg;
         meff.NextFrameTime := 80;
         PlaySound (s_strike_stone);
         //PlaySound (s_drop_stonepiece);
         PlayScene.EffectList.Add (meff);
         event := EventMan.GetEvent (XX, YY, ET_PILESTONES);
         if event <> nil then
            event.EventParam := event.EventParam + 1;
      end;
   end;
   if CurrentAction = SM_THROW then begin
      if (frame = 3) and (BoThrow) then begin
         BoThrow := FALSE;
         mfly := TFlyingAxe (PlayScene.NewFlyObject (self,
                          XX,
                          YY,
                          TargetX,
                          TargetY,
                          TargetRecog,
                          mtFlyAxe));
         if mfly <> nil then begin
            TFlyingAxe(mfly).ReadyFrame := 40;
            mfly.ImgLib := g_WMon3Img;
            mfly.FlyImageBase := FLYOMAAXEBASE;
         end;

      end;
      if frame >= 3 then
         BoHideWeapon := TRUE;
   end;
end;

procedure  THumActor.DoWeaponBreakEffect;
begin
   BoWeaponEffect := TRUE;
   CurWpEffect := 0;
end;

procedure  THumActor.Run;
   function MagicTimeOut: Boolean;
   begin
//      if self = Myself then begin
         Result := GetTickCount - WaitMagicRequest > 3000;
//      end else
//         Result := GetTickCount - WaitMagicRequest > 2000;
      if Result then
         CurMagic.ServerMagicCode := 0;
   end;
var
   prv: integer;
   frametimetime: longword;
   bofly: Boolean;
begin
   if GetTickCount - genanicounttime > 120 then begin //ÁÖ¼úÀÇ¸· µî... ¾Ö´Ï¸ÞÀÌ¼Ç È¿°ú
      genanicounttime := GetTickCount;
      Inc (GenAniCount);
      if GenAniCount > 100000 then GenAniCount := 0;
      Inc (CurBubbleStruck);
   end;
   if BoWeaponEffect then begin  //¹«±â Çâ»ó/ºÎ¼­Áü È¿°ú
      if GetTickCount - wpeffecttime > 120 then begin
         wpeffecttime := GetTickCount;
         Inc (CurWpEffect);
         if CurWpEffect >= MAXWPEFFECTFRAME then
            BoWeaponEffect := FALSE;
      end;
   end;

   if (CurrentAction = SM_WALK) or
      (CurrentAction = SM_BACKSTEP) or
      (CurrentAction = SM_RUN) or
      (CurrentAction = SM_RUSH) or
      (CurrentAction = SM_RUSHKUNG)
   then exit;

   msgmuch := FALSE;
   if self <> Myself then begin
      if MsgList.Count >= 2 then msgmuch := TRUE;
   end;

   //»ç¿îµå È¿°ú
   RunActSound (currentframe - startframe);
   RunFrameAction (currentframe - startframe);

   prv := currentframe;
   if CurrentAction <> 0 then begin
      if (currentframe < startframe) or (currentframe > endframe) then
         currentframe := startframe;

//      if (self <> Myself) and (BoUseMagic) then begin
//         frametimetime := Round(frametime / 1.8);
//      end else begin
         if msgmuch then frametimetime := Round(frametime * 2 / 3)
         else frametimetime := frametime; //2004/04/07 ¼Óµµ°ü·Ã ¼öÁ¤
//      end;

      if GetTickCount - starttime > frametimetime then begin
         if currentframe < endframe then begin

            //¸¶¹ýÀÎ °æ¿ì ¼­¹öÀÇ ½ÅÈ£¸¦ ¹Þ¾Æ, ¼º°ø/½ÇÆÐ¸¦ È®ÀÎÇÑÈÄ
            //¸¶Áö¸·µ¿ÀÛÀ» ³¡³½´Ù.
            if BoUseMagic then begin
               if (CurEffFrame = SpellFrame-2) or (MagicTimeOut) then begin //±â´Ù¸² ³¡
                  if (CurMagic.ServerMagicCode >= 0) or (MagicTimeOut) then begin //¼­¹ö·Î ºÎÅÍ ¹ÞÀº °á°ú. ¾ÆÁ÷ ¾È¿ÔÀ¸¸é ±â´Ù¸²
                     Inc (currentframe);
                     Inc(CurEffFrame);
                     starttime := GetTickCount;
                  end;
               end else begin
                  if currentframe < endframe - 1 then Inc (currentframe);
                  Inc (CurEffFrame);
                  starttime := GetTickCount;
               end;
            end else begin
               Inc (currentframe);
               starttime := GetTickCount;
            end;

         end else begin
            if self = Myself then begin
               if FrmMain.ServerAcceptNextAction then begin
                  CurrentAction := 0;
                  BoUseMagic := FALSE;
               end;
            end else begin
               CurrentAction := 0; //µ¿ÀÛ ¿Ï·á
               BoUseMagic := FALSE;
            end;
            BoHitEffect := FALSE;
         end;
         if BoUseMagic then begin
            if CurEffFrame = SpellFrame-1 then begin //¸¶¹ý ¹ß»ç ½ÃÁ¡
               //¸¶¹ý ¹ß»ç
               if CurMagic.ServerMagicCode > 0 then begin
                  with CurMagic do
                     PlayScene.NewMagic (self,
                                      ServerMagicCode,
                                      EffectNumber,
                                      XX,
                                      YY,
                                      TargX,
                                      TargY,
                                      Target,
                                      EffectType,
                                      Recusion,
                                      AniTime,
                                      bofly);
                  if bofly then
                     PlaySound (magicfiresound)
                  else
                     PlaySound (magicexplosionsound);
               end;
               if self = Myself then
                  LatestSpellTime := GetTickCount;
               CurMagic.ServerMagicCode := 0;
            end;
         end;

      end;
      if Race = 0 then currentdefframe := 0
      else currentdefframe := -10;
      defframetime := GetTickCount;
   end else begin
      if GetTickCount - smoothmovetime > 200 then begin
         if GetTickCount - defframetime > 500 then begin
            defframetime := GetTickCount;
            Inc (currentdefframe);
            if currentdefframe >= defframecount then
               currentdefframe := 0;
         end;
         DefaultMotion;
      end;
   end;

   if prv <> currentframe then begin
      loadsurfacetime := GetTickCount;
      LoadSurface;
   end;

end;

function   THumActor.Light: integer;
var
   l: integer;
begin
   l := ChrLight;
   if l < MagLight then begin
      if BoUseMagic or BoHitEffect then
         l := MagLight;
   end;
   Result := l;
end;

procedure  THumActor.LoadSurface;
var
  nWeaponFile: integer;
begin
  if Sex = 0 then BodySurface := g_WM_HumImg.GetCachedImageEx (BodyOffset + currentframe, px, py, spx, spy, stype)
  else BodySurface := g_WWM_HumImg.GetCachedImageEx (BodyOffset + currentframe, px, py, spx, spy, stype);

  if HairOffset >= 0 then begin
    if Sex = 0 then
      HairSurface := g_WM_Hair.GetCachedImage(HairOffset + currentframe, hpx, hpy)
    else
      HairSurface := g_WWM_Hair.GetCachedImage(HairOffset + currentframe, hpx, hpy)
  end
  else
    HairSurface := nil;

//   if (Dress in [22,23]) and (currentframe < 536) then begin
//      if GetTickCount - WingStartTime > 100 then begin
//         if WingCurrentFrame < 19 then
//            Inc (WingCurrentFrame)
//         else begin
//            if Not Bo50DressHEffect then Bo50DressHEffect := True
//            else Bo50DressHEffect := False;
//            WingCurrentFrame := 0;
//         end;
//
////         DScreen.AddSysMsg ('SF=>'+ IntToStr(Dir*8)+' CF=>'+ IntToStr(WingCurrentFrame)+' THumActor');
//         WingStartTime := GetTickCount;
//      end;
//      WingSurface := g_WEffectImg.GetCachedImage (WingOffset + WingCurrentFrame, epx, epy);
//   end;
//   else if (Dress in [18,19,20,21]) and (currentframe < 64) then begin
//      if GetTickCount - WingStartTime > WingFrametime then begin
//         if WingCurrentFrame < 7 then
//            Inc (WingCurrentFrame)
//         else
//            WingCurrentFrame := 0;
////         DScreen.AddSysMsg ('SF=>'+ IntToStr(Dir*8)+' CF=>'+ IntToStr(WingCurrentFrame)+' THumActor');
//         WingStartTime := GetTickCount;
//      end;
//      WingSurface := g_WHumWing.GetCachedImage (WingOffset + Dir*8 + WingCurrentFrame, epx, epy)
//   end
//   else if Dress in [18,19,20,21] then
//      WingSurface := g_WHumWing.GetCachedImage (WingOffset + currentframe, epx, epy);

//   if currentframe > 535 then Bo50DressHEffect := False;

   if (Dress div 2) = 1 then begin
      if GetTickCount - WingStartTime > 100 then begin
         if WingCurrentFrame < 15 then
            Inc (WingCurrentFrame)
         else begin
            WingCurrentFrame := 0;
         end;
//         DScreen.AddSysMsg ('THumActor.DefaultMotion=>(Dress in [22,23])');
         WingStartTime := GetTickCount;
      end;
      WingSurface := g_WGameInter1.GetCachedImage (WingOffset + WingCurrentFrame, epx, epy);
   end;

//   if Bo50LevelEffect then begin
//      if GetTickCount - H50LevelEffectStartTime > H50LevelEffectFrameTime then begin
//         if H50LevelEffectCurrentFrame < 7 then
//            Inc (H50LevelEffectCurrentFrame)
//         else begin
//            H50LevelEffectCurrentFrame := 0;
//            Bo50LevelHEffect := Not Bo50LevelHEffect;
//         end;
//         H50LevelEffectStartTime := GetTickCount;
//      end;
//      H50LevelEffectSurface := g_WEffectImg.GetCachedImage (H50LevelEffectOffset + H50LevelEffectCurrentFrame, epx2, epy2);
//   end;

//   if FoodStickType > 0 then begin
//      if GetTickCount - FoodStickDayEffectStartTime > FoodStickDayEffectFrameTime then begin
//         if FoodStickDayEffectCurrentFrame < 14 then
//            Inc (FoodStickDayEffectCurrentFrame)
//         else begin
//            FoodStickDayEffectCurrentFrame := 0;
//         end;
//         FoodStickDayEffectStartTime := GetTickCount;
//      end;
//      FoodStickDayEffectSurface := g_WEffectImg.GetCachedImage (FoodStickDayEffectOffset + FoodStickDayEffectCurrentFrame, epx3, epy3);
//      FoodStickDayEffectSurface2 := g_WEffectImg.GetCachedImage (FoodStickDayEffectOffset2 + FoodStickDayEffectCurrentFrame, epx4, epy4);
//   end;

{   if (Weapon in [76,77]) and (currentframe < 64) then begin
      if GetTickCount - WeaponEffectStartTime > WeaponEffectFrametime then begin
         if WeaponEffectCurrentFrame < 7 then
            Inc (WeaponEffectCurrentFrame)
         else
            WeaponEffectCurrentFrame := 0;
//         DScreen.AddSysMsg ('THumActor.DefaultMotion=>(Dress in [Wing])');
         WeaponEffectStartTime := GetTickCount;
      end;
      WeaponEffectSurface := FrmMain.WHumWing.GetCachedImage (WeaponEffectOffset + Dir*8 + WeaponEffectCurrentFrame, wpx2, wpy2);
   end;}

{   if BoWriterEffect then begin
      if GetTickCount - HWriterEffectStartTime > HWriterEffectFrameTime then begin
         if HWriterEffectCurrentFrame < 9 then
            Inc (HWriterEffectCurrentFrame)
         else begin
            HWriterEffectCurrentFrame := 0;
            BoWriterHEffect := Not BoWriterHEffect;
         end;
         HWriterEffectStartTime := GetTickCount;
      end;
      HWriterEffectSurface := FrmMain.WEffectImg.GetCachedImage (HWriterEffectOffset + HWriterEffectCurrentFrame, epx3, epy3);
   end;}

  if Weapon > 0 then begin
    nWeaponFile := (Weapon - 1) div 10;
    if Weapon = 254 then nWeaponFile:= 4;

    if Sex = 0 then begin
      if nWeaponFile > 9 then WeaponSurface := g_WM_WeaponEx[nWeaponFile-10].GetCachedImageEx (WeaponOffset + currentframe, wpx, wpy, wspx, wspy, wstype)
      else WeaponSurface := g_WM_Weapon[nWeaponFile].GetCachedImageEx (WeaponOffset + currentframe, wpx, wpy, wspx, wspy, wstype);
    end else begin
      if nWeaponFile > 9 then WeaponSurface := g_WWM_WeaponEx[nWeaponFile-10].GetCachedImageEx (WeaponOffset + currentframe, wpx, wpy, wspx, wspy, wstype)
      else WeaponSurface := g_WWM_Weapon[nWeaponFile].GetCachedImageEx (WeaponOffset + currentframe, wpx, wpy, wspx, wspy, wstype);
    end;
    if Weapon = 254 then
      WeaponEffectSurface := g_WMonMagicEx[3].GetCachedImage (WeaponEffectOffset + currentframe, wpx2, wpy2);
  end;
end;

procedure THumActor.DrawChr(dsurface: TDirectDrawSurface; dx, dy: integer; blend: Boolean; WingDraw: Boolean);
var
  idx, ax, ay: integer;
  d: TDirectDrawSurface;
  ceff: TColorEffect;
  wimg: TWMImages;
begin
  if not (dir in [0..7]) then exit;
  if GetTickCount - loadsurfacetime > 60 * 1000 then begin
    loadsurfacetime := GetTickCount;
    LoadSurface; //bodysurfaceµîÀÌ loadsurface¸¦ ´Ù½Ã ºÎ¸£Áö ¾Ê¾Æ ¸Þ¸ð¸®°¡ ÇÁ¸®µÇ´Â °ÍÀ» ¸·À½
  end;

  ceff := GetDrawEffectValue;

  if Race = 0 then begin
    if (currentframe >= 0) and (currentframe <= 2999) then
      wpord := WORDER[Sex, currentframe];

// 2¹ø ¸ðµå --------------------------------------------------------------------
//      if Dress in [18,19,20,21] then
//      begin
//
//        if self = Myself then
//        begin
//           if blend then
//              if ((Dir = DR_DOWN ) or (Dir = DR_DOWNRIGHT) or (Dir = DR_DOWNLEFT )) and (WingSurface <> nil)
//                   and (not WingDraw) then
//                    DrawBlend (dsurface, dx + epx + ShiftX, dy + epy + ShiftY, WingSurface, 1)
//           else
//              if ((Dir = DR_DOWN ) or (Dir = DR_DOWNRIGHT) or (Dir = DR_DOWNLEFT )) and (WingSurface <> nil)
//                   and WingDraw then
//                    DrawBlend (dsurface, dx + epx + ShiftX, dy + epy + ShiftY, WingSurface, 1);
//        end
//        else
//        begin
//           if ((FocusCret <> nil) or (MagicTarget <> nil)) and blend and
//               ((Dir = DR_DOWN ) or (Dir = DR_DOWNRIGHT) or (Dir = DR_DOWNLEFT )) and (WingSurface <> nil)
//                   and (not WingDraw) then
//                    DrawBlend (dsurface, dx + epx + ShiftX, dy + epy + ShiftY, WingSurface, 1)
//           else if ((Dir = DR_DOWN ) or (Dir = DR_DOWNRIGHT) or (Dir = DR_DOWNLEFT )) and (WingSurface <> nil)
//                and WingDraw then
//                DrawBlend (dsurface, dx + epx + ShiftX, dy + epy + ShiftY, WingSurface, 1);
//        end;
//
//      end;

// 2¹ø ¸ðµå --------------------------------------------------------------------
    if (wpord = 0) and (not blend) and (Weapon >= 2) and (WeaponSurface <> nil) and (not BoHideWeapon) then begin
      if Death then DrawBlendShadow(dsurface, dx + wpx + 3 + ShiftX, dy + wpy + 2 + ShiftY, 50, WeaponSurface, g_boShadowBlend)
      else DrawBlendShadow(dsurface, dx + wpx + ShiftX, dy + wpy + ShiftY, dx + wpx + ShiftX, dy + wpy + ShiftY, wstype, WeaponSurface, g_boShadowBlend);
      DrawEffSurface(dsurface, WeaponSurface, dx + wpx + ShiftX, dy + wpy + ShiftY, blend, ceNone);  //Ä®Àº »öÀÌ ¾Èº¯ÇÔ
      if (Weapon in [76, 77, 254]) and (WeaponEffectSurface <> nil) then begin
        DrawBlend(dsurface, dx + wpx2 + ShiftX, dy + wpy2 + ShiftY, WeaponEffectSurface, 1);
      end;
    end;

      //¸öÅë ±×¸®°í
    if BodySurface <> nil then begin
      if Death then DrawBlendShadow(dsurface, dx + px + 3 + ShiftX, dy + py + 2 + ShiftY, 50, BodySurface, g_boShadowBlend)
      else DrawBlendShadow(dsurface, dx + spx + ShiftX, dy + spy + ShiftY, stype, BodySurface, g_boShadowBlend);
      DrawEffSurface(dsurface, BodySurface, dx + px + ShiftX, dy + py + ShiftY, blend, ceff);
    end;

      if Not (Dress in [24,25]) then
         if HairSurface <> nil then
            DrawEffSurface (dsurface, HairSurface, dx + hpx + ShiftX, dy + hpy + ShiftY, blend, ceff);

      //º¸ÀÌ´Â °¢µµ¿¡ µû¶ó¼­ ¸ö,¸Ó¸®,¹«±â¸¦ ±×¸®´Â ¼ø¼­°¡ ´Þ¶óÁø´Ù.
    if (wpord = 1) and {(not blend) and} (Weapon >= 2) and (WeaponSurface <> nil) and (not BoHideWeapon) then begin
      if Death then DrawBlendShadow(dsurface, dx + wpx + 3 + ShiftX, dy + wpy + 2 + ShiftY, 50, WeaponSurface, g_boShadowBlend)
      else DrawBlendShadow(dsurface, dx + wpx + ShiftX, dy + wpy + ShiftY, dx + wpx + ShiftX, dy + wpy + ShiftY, wstype, WeaponSurface, g_boShadowBlend);
      DrawEffSurface(dsurface, WeaponSurface, dx + wpx + ShiftX, dy + wpy + ShiftY, blend, ceNone);
      if (Weapon in [76, 77, 254]) and (WeaponEffectSurface <> nil) then begin
        DrawBlend(dsurface, dx + wpx2 + ShiftX, dy + wpy2 + ShiftY, WeaponEffectSurface, 1);
      end;
    end;

// 2¹ø¸ðµå ---------------------------------------------------------------------
//      if Dress in [18,19,20,21] then
//      begin
//
//        if self = Myself then
//        begin
//           if blend then
//             if ((Dir = DR_UP ) or (Dir = DR_UPLEFT) or (Dir = DR_UPRIGHT ) or (Dir = DR_LEFT) or (Dir = DR_RIGHT ))
//                   and (WingSurface <> nil) and (not WingDraw) then
//                    DrawBlend (dsurface, dx + epx + ShiftX, dy + epy + ShiftY, WingSurface, 1)
//           else
//              if ((Dir = DR_UP ) or (Dir = DR_UPLEFT) or (Dir = DR_UPRIGHT ) or (Dir = DR_LEFT) or (Dir = DR_RIGHT ))
//                   and (WingSurface <> nil) and WingDraw then
//                    DrawBlend (dsurface, dx + epx + ShiftX, dy + epy + ShiftY, WingSurface, 1);
//        end
//        else
//        begin
//           if ((FocusCret <> nil) or (MagicTarget <> nil)) and
//               ((Dir = DR_UP ) or (Dir = DR_UPLEFT) or (Dir = DR_UPRIGHT ) or (Dir = DR_LEFT) or (Dir = DR_RIGHT ))
//                   and (WingSurface <> nil) and (not WingDraw) then
//                    DrawBlend (dsurface, dx + epx + ShiftX, dy + epy + ShiftY, WingSurface, 1)
//           else if ((Dir = DR_UP ) or (Dir = DR_UPLEFT) or (Dir = DR_UPRIGHT ) or (Dir = DR_LEFT) or (Dir = DR_RIGHT ))
//                and (WingSurface <> nil) and WingDraw then
//                 DrawBlend (dsurface, dx + epx + ShiftX, dy + epy + ShiftY, WingSurface, 1);
//        end;
//
//      end;

// 2¹ø¸ðµå ---------------------------------------------------------------------

      // 50·¹º§¿Ê ÀÓÆåÆ®
//      if (Dress in [22,23] )and Bo50DressHEffect and (WingSurface <> nil) then
//         DrawBlend (dsurface, dx + epx + ShiftX, dy + epy + ShiftY, WingSurface, 1);

      if ((Dress div 2) in [1]) and (WingSurface <> nil) then
         DrawBlend (dsurface, dx + epx + ShiftX, dy + epy + ShiftY, WingSurface, 1);
      // 50Level Effect
//      if (Bo50LevelEffect) and (Bo50LevelHEffect) then
//         DrawBlend (dsurface, dx + epx2 + ShiftX, dy + epy2 + ShiftY, H50LevelEffectSurface, 1);

      // Writer Effect
//      if (BoWriterEffect) and (BoWriterHEffect) then
//         DrawBlend (dsurface, dx + epx3 + ShiftX, dy + epy3 + ShiftY, HWriterEffectSurface, 1);

      //ÁÖ¼úÀÇ¸·ÀÎ °æ¿ì
      if State and $00100000{STATE_BUBBLEDEFENCEUP} <> 0 then begin  //ÁÖ¼úÀÇ¸·
         if (CurrentAction = SM_STRUCK) and (CurBubbleStruck < 3) then
            idx := MAGBUBBLESTRUCKBASE + CurBubbleStruck
         else
            idx := MAGBUBBLEBASE + (GenAniCount mod 3);
         d := g_WMagic.GetCachedImage (idx, ax, ay);
         if d <> nil then
            DrawBlend (dsurface,
                             dx + ax + ShiftX,
                             dy + ay + ShiftY,
                             d, 1);
      end;

      //---»©»©·Îµ¥ÀÌ ÀÌº¥Æ®------------------------------------------------------------------------------
//      FoodStickType := 0;
//      if RecogId = Myself.RecogId then begin
//      if (UseItems[U_RIGHTHAND].S.Name <> '') and (UseItems[U_RIGHTHAND].S.Looks = 863) and CouplePower then begin
//         FoodStickType := 3;
//         FoodStickDayEffectOffset  := 550;
//         FoodStickDayEffectOffset2 := 530;
//         BoFoodStickDayEffect := True;
//         FoodStickDayEffectFrameTime := 100;
//         if FoodStickDayEffectSurface <> nil then
//            DrawBlend (dsurface, dx + epx3 + ShiftX, dy + epy3 + ShiftY, FoodStickDayEffectSurface, 1);
//         if FoodStickDayEffectSurface2 <> nil then
//            dsurface.Draw (dx + epx4 + ShiftX, dy + epy4 + ShiftY, FoodStickDayEffectSurface2.ClientRect, FoodStickDayEffectSurface2, TRUE);
//      end
//      else if (UseItems[U_RIGHTHAND].S.Name <> '') and (UseItems[U_RIGHTHAND].S.Looks = 863) then begin
//         FoodStickType := 1;
//         if MySelf.Sex = 0 then begin
//            FoodStickDayEffectOffset  := 490;
//            FoodStickDayEffectOffset2 := 470;
//         end
//         else begin
//            FoodStickDayEffectOffset  := 510;
//            FoodStickDayEffectOffset2 := 470;
//         end;
//         BoFoodStickDayEffect := True;
//         FoodStickDayEffectFrameTime := 100;
//         if FoodStickDayEffectSurface <> nil then
//            DrawBlend (dsurface, dx + epx3 + ShiftX, dy + epy3 + ShiftY, FoodStickDayEffectSurface, 1);
//         if FoodStickDayEffectSurface2 <> nil then
//            dsurface.Draw (dx + epx4 + ShiftX, dy + epy4 + ShiftY, FoodStickDayEffectSurface2.ClientRect, FoodStickDayEffectSurface2, TRUE);
//      end
//      else if (UseItems[U_RIGHTHAND].S.Name <> '') and (UseItems[U_RIGHTHAND].S.Looks = 918) then begin
//         FoodStickType := 2;
//         FoodStickDayEffectOffset  := 440;
//         FoodStickDayEffectOffset2 := 420;
//         BoFoodStickDayEffect := True;
//         FoodStickDayEffectFrameTime := 120;
//         if FoodStickDayEffectSurface <> nil then
//            DrawBlend (dsurface, dx + epx3 + ShiftX, dy + epy3 + ShiftY, FoodStickDayEffectSurface, 1);
//         if FoodStickDayEffectSurface2 <> nil then
//            dsurface.Draw (dx + epx4 + ShiftX, dy + epy4 + ShiftY, FoodStickDayEffectSurface2.ClientRect, FoodStickDayEffectSurface2, TRUE);
////               DrawEffSurface (dsurface, FoodStickDayEffectSurface2, dx + epx4 + ShiftX, dy + epy4 + ShiftY, blend, ceNone);
//      end;
//      end;
//      else FoodStickType := 0;
      //-------------------------------------------------------------------------------------------------

  end;

   if BoHitEffect and (HitEffectNumber = 8) then begin
   end else begin
   if BoUseMagic {and (EffDir[Dir] = 1)} and (CurMagic.EffectNumber > 0) then begin
      if CurEffFrame in [0..SpellFrame-1] then begin
         GetEffectBase (CurMagic.EffectNumber-1, 0, wimg, idx);
         idx := idx + CurEffFrame;
         if wimg <> nil then
            d := wimg.GetCachedImage (idx, ax, ay);
         if d <> nil then
            DrawBlend (dsurface,
                             dx + ax + ShiftX,
                             dy + ay + ShiftY,
                             d, 1);
      end;
   end;
   end;

   // °øÆÄ¼¶ º°µµ Ã³¸®
   if BoHitEffect and (HitEffectNumber = 8) then begin
      if GetTickCount - SKillStartTime > SKillFrametime then begin
         if SKillCurrentFrame < (14) then
            Inc (SKillCurrentFrame)
         else begin
            SKillCurrentFrame := 0;
            BoHitEffect := False;
         end;
         SKillStartTime := GetTickCount;
      end;
      idx := Dir*20;
      wimg := g_WMagicEx[1];
      if wimg <> nil then
         d := wimg.GetCachedImage ((740+idx) + SKillCurrentFrame, ax, ay);
//      DScreen.AddChatBoardString ('SKillCurrentFrame=>'+IntToStr(SKillCurrentFrame), clYellow, clRed);
      if d <> nil then
         DrawBlend (dsurface,
                          dx + ax + ShiftX,
                          dy + ay + ShiftY,
                          d, 1);
   end
   //°Ë¹ý È¿°ú
   else if BoHitEffect and (HitEffectNumber > 0) then begin
      GetEffectBase (HitEffectNumber-1, 1, wimg, idx);
      idx := idx + Dir*10 + (currentframe-startframe);
      if wimg <> nil then
         d := wimg.GetCachedImage (idx, ax, ay);
      if d <> nil then
         DrawBlend (dsurface,
                          dx + ax + ShiftX,
                          dy + ay + ShiftY,
                          d, 1);
   end;

   //¹°¾à ¸Ô°í ³ª´Â È¿°ú
   //if BoEatEffect then begin
   //   if GetTickCount - EatEffectTime > 70 then begin
   //      EatEffectTime := GetTickCount;
   //      Inc (EatEffectFrame);
   //   end;
   //   if EatEffectFrame >= 6 then begin
   //      BoEatEffect := FALSE;
   //      EatEffectFrame := 0;
   //   end;
   //
   //   d := FrmMain.WEffectImg.GetCachedImage (296 + EatEffectFrame, ax, ay);
   //   if d <> nil then
   //      DrawBlend (dsurface,
   //                       dx + ax + ShiftX,
   //                       dy + ay + ShiftY,
   //                       d, 1);
   //end;

   //¹«±â Çâ»ó/ºÎ¼­Áü È¿°ú
   if BoWeaponEffect then begin
      idx := WPEFFECTBASE + Dir*10 + CurWpEffect;
      d := g_WMagic.GetCachedImage (idx, ax, ay);
      if d <> nil then
         DrawBlend (dsurface,
                     dx + ax + ShiftX,
                     dy + ay + ShiftY,
                     d, 1);
   end;

end;

end.


