unit EDcode;

interface

uses
	Windows, SysUtils, Classes, Hutil32, Grobal2;

   function  LoadPublicKey( fname : string ): Boolean;
   procedure SetPublicKey( pubkey : WORD );
   function  GetPublicKey: WORD;
   function  EncodeMessage (smsg: TDefaultMessage): string;
   function  DecodeMessage (str: string): TDefaultMessage;
   function  EncodeString (str: string): string;
   function  DecodeString (str: string): string;
   function  DecodeString_old (str: string): string;
   function  EncodeBuffer (buf: pChar; bufsize: integer): string;
   procedure DecodeBuffer (src: string; buf: PChar; bufsize: integer);
var
	CSEncode: TRTLCriticalSection;

implementation

var
	EncBuf, TempBuf: PChar;


//--------------------------
// 치환 테이블 선언 시작...
//--------------------------
  cTable_src: array [0..255] of BYTE = (
 28, 171, 172, 131, 154, 114, 136, 222,  17,  46,  13, 234,  90, 228,  57, 116,
139,  51, 102,  89, 169, 191, 130,  48, 223,  88, 138, 214, 196, 233,  65, 158,
194, 212,  27, 201, 163, 120, 253,   6, 215,  87,  11, 244, 101,  59,  23, 254,
230, 205,  43,  94, 100, 178,  41,  34, 126,  77, 176,  30,   5, 235, 137, 108,
202,   0,  16, 159,  35, 119,  52, 113, 184,  54, 142, 140,  19, 252,  72,   1,
 25, 255, 198,  38, 111, 199,  39,  83, 203, 124, 164, 211, 232,  10,  82, 193,
115, 243, 227,  93,   4,   2,  49,  74, 175, 146, 217,  60, 216, 147, 182, 117,
 44, 104, 197, 156,  12, 141,   7,  81, 145,  24,  84,  96,  55, 107, 209,  92,
 36, 237, 121, 187, 135,  40, 240,  78, 210,   9,  67,  62,  68, 157,  50, 129,
127, 190, 192, 179, 238,   3, 174, 181, 245, 148, 177, 200,  70,  76, 225,  18,
112, 132, 165, 103,  20,  45,  15, 170, 219, 220,  56, 144,  14,  80,  98, 161,
151,  33, 239, 133, 231, 134,   8,  99, 122, 167, 162, 224, 226, 155, 153, 213,
173,  85, 242, 152, 221,  95,  97, 247, 128,  22,  53, 106, 188, 105, 206, 248,
204, 149, 143, 180,  31, 195, 207,  58,  66,  61, 246, 249,  29, 241,  91, 109,
185,  79, 229,  21, 208,  71,  47,  64, 186, 166, 189, 150,  63, 250,  73,  69,
183, 110, 218,  32, 125,  26, 118, 160, 168,  75,  37,  42, 251, 123,  86, 236
   );
  dTable_src: array [0..255] of BYTE = (
 84,  44,  40, 199,  45, 108,  22,  83,  63, 248,  48,  62, 220,  24, 189, 124,
132,  85,  43, 247, 178, 197, 103,  21,  34, 232,  41, 184, 219, 237, 240,  80,
227, 157,  12, 206,  73, 170, 212,  86,   8,   2,   5, 163, 235, 250, 210, 215,
131, 218,  53, 205, 255, 149,  58,   0,  10,  20, 111,  37, 102, 158,  11,  30,
145, 116, 229, 233,  32, 153,  76, 159, 191,  55, 117, 190,  25,  33,   4, 114,
177,  60, 128,  54, 100,  82, 243,  91, 110, 213,  87, 246, 188, 198,  23, 107,
225, 245,  96,  78,  99, 174, 208, 166, 168, 155,  46, 133, 209, 181, 104, 223,
 81, 141, 194,  88, 129, 186, 202, 112, 161,  56, 195,  19,  29, 204, 200, 134,
 66, 167, 136, 152, 242, 252, 203, 251,  18,  17, 126,  28,  79, 135, 192,  51,
 59, 144, 147, 214, 207, 142, 143, 139, 105, 140, 176, 146, 127, 130, 118,  93,
 72,  47, 221, 160,  15, 156,  97,  61, 241, 217,  49, 183,   3, 173, 151,  13,
150,   6,  57, 154, 122, 230,   7,  27, 249, 148, 123, 121, 193, 211, 169, 106,
109,  26,  71,  95,  94, 180, 254, 238, 244,  74, 187,  31,  64, 226, 228,  69,
 35,  14, 196, 253,  89, 115, 138,  68, 120, 119, 175, 162, 201, 236, 239,  16,
216, 172,  52,  38,  98, 234, 222,  90,  70,  67, 171, 179,  39,  92, 224, 165,
  1, 164, 231, 185,  50,  77, 113, 101,  36, 182,  75,  42, 137,  65, 125,   9
   );

  cTable_return: array [0..255] of BYTE = (
132, 223, 229, 173,  89,  93,  76, 159, 119,  43, 185,  71, 137,  48, 138, 247,
176, 129, 135, 149,  55,  34, 187, 252, 230, 126,  65, 127,  36,  46,  10,  50,
196,  90, 163, 231, 167,   1, 174,  14,  33, 165, 222, 248, 183, 220, 212, 124,
141, 221, 150, 110,  16, 142, 155, 195,  92, 162, 244,  54,  53, 147,  32, 204,
 28,  47, 139,  21, 111, 188,  74, 208,  44,  51, 240, 157, 156, 198,  94,  88,
 97, 102,  70,  40, 225,  20, 107, 166, 226, 250,   5, 228, 108, 116,  23, 175,
243, 238, 172,  31,  85, 246, 233, 178, 101,  27,  18, 121, 200, 217, 239, 251,
128,   4, 214,  57,  86, 136, 170, 143, 134, 160, 181, 203,   9,  63,  41, 104,
 26, 253, 215, 144, 120, 171,  60, 118, 224,  15, 232,  52,  22, 193, 100,  77,
 66,  19,   8,  80, 161,  81, 123, 117, 146, 152,  62,  64,  30, 105, 189, 130,
 72, 125, 254, 114,  37, 186,  82,  35, 216, 191, 237,  95,  25, 227,  58, 158,
 98, 103, 206, 180, 112,   3, 133, 199, 210,  61, 145,  68,   6, 207,   2, 177,
 29, 202, 245,  78,  99, 106,  67, 153, 241,   7,  87,  75, 234,  56,  39,  45,
209, 168, 219, 184, 190, 236,  42, 211, 213, 179,  13, 169, 205,  83, 218, 122,
113, 194,  91,  59,  84,  49, 115, 148, 164,  12, 192, 109, 201, 140, 182,  17,
151,  38,  24,   0, 131, 154, 242,  79,  96, 197, 235,  11,  73, 255, 249,  69
   );
  dTable_return: array [0..255] of BYTE = (
154, 132,   1, 141, 166, 175, 116, 165, 115,   9,  21, 145,  93, 135, 113, 183,
185,  75,  95,  36,   4, 169,  64, 102, 162, 161,  69, 173, 163, 226, 200, 182,
159, 205,  89, 241, 223,  32, 100, 174, 124, 127,  58, 104, 254,  65, 199,  47,
181,  83, 219, 197,  31, 239,  76, 151, 238,  81, 153, 213, 222,  17, 138,  92,
 27, 167, 109,  18, 137,  26,  88,  82,  91, 210, 150,  56,  40,   5, 157, 212,
 55, 105,  33, 230,  78,  70, 136, 186, 160,  23,   7,  73, 178,  66, 232,  74,
 39, 111,  85, 252,  98, 176, 156,  42,   0, 242, 231, 177, 179,  25, 140,  61,
198, 129, 118, 250,  20, 249,  84, 218, 234, 243,  41, 233,  24, 209, 119,  45,
106,  50,  35,  13,  79, 188, 189, 235, 255,  11,  72, 191, 131, 245, 120,  57,
130, 133,  30, 122, 152,  29, 196,   3, 144, 229, 155,  22,  10,  12, 203,  28,
125, 103,   6, 214, 187, 192, 158,  62,  60,  63, 147, 101, 164,   2, 134,  77,
216, 215,  15, 204, 228,  44, 121, 112, 149,  94,  48,  53,  38, 207,  46,  54,
110,  19,  37,  52,  51,  97,  68,  43, 247, 240, 171, 217,  99, 211, 224,  71,
246, 220, 251, 227, 221, 180, 201, 248, 184,  87, 193, 114, 206, 253,  16, 148,
237, 170, 126, 117, 225, 123, 194,  67, 168, 190, 202,  59, 142, 128, 143, 236,
 34,   8, 195,  96,  80, 208, 146,  86,  14, 108, 244,  49, 107, 139, 172,  90
   );
//--------------------------
// 치환 테이블 선언 끝...
//--------------------------

  cXorValue: BYTE = ($14);
  g_EndeKey: WORD = ($6501);
  // 치환 테이블 인코딩 값
  g_HideTable: BYTE = ($97);
  // 역치환 테이블 인코딩 값
  g_HideBackTable: BYTE = ($34);

//-------------------------------------------------
// Load public key.
function  LoadPublicKey( fname : string ): Boolean;
var
	strlist : TStringList;
begin
   Result := FALSE;

   if FileExists (fname) then begin
      strlist := TStringList.Create;
      strlist.LoadFromFile (fname);

      SetPublicKey( WORD(Str_ToInt(strlist[0], g_EndeKey)) );
   	Result := TRUE;

      strlist.Free;
   end;
end;

//-------------------------------------------------
// Set public key.
procedure SetPublicKey( pubkey : WORD );
begin
   g_EndeKey := pubkey;
end;

function  GetPublicKey: WORD;
begin
   Result := g_EndeKey;
end;

procedure Encode6BitBuf (src, dest: PChar; srclen, destlen: integer);
var
   i, restcount, destpos: integer;
   made, ch, rest: byte;
   sum: short;
begin
try
   restcount := 0;
   rest 		 := 0;
   destpos	 := 0;

   for i:=0 to srclen - 1 do begin
      if destpos >= destlen then break;
      ch := byte (src[i]);

      //---------------------------------------------------------------------
      // 치환
//      ch := ( cTable_src[ Integer(ch) ] xor g_HideTable ) xor cXorValue;   // added by sonmg

		ch := ch xor (((i+5)*2)+3);

      // XOR 연산
      ch := ch xor ( HIBYTE(g_EndeKey) + LOBYTE(g_EndeKey) );   // added by sonmg
      //---------------------------------------------------------------------

      made := byte ((rest or (ch shr (2+restcount))) and $3F);
      rest := byte (((ch shl (8 - (2+restcount))) shr 2) and $3F);
      Inc (restcount, 2);

      if restcount < 6 then begin
      	dest[destpos] := char(made + $3C);
         Inc (destpos);
      end else begin
      	if destpos < destlen-1 then begin
            dest[destpos]   := char(made + $3C);
            dest[destpos+1] := char(rest + $3C);
            Inc (destpos, 2);
         end else begin
            dest[destpos]   := char(made + $3C);
            Inc (destpos);
         end;
         restcount := 0;
         rest := 0;
      end;

   end;
   if restcount > 0 then begin
   	dest[destpos] := char (rest + $3C);
      Inc (destpos);
   end;

   dest[destpos] := #0;
except
end;
end;

procedure Decode6BitBuf (source: string; buf: PChar; buflen: integer);
const
	Masks: array[2..6] of byte = ($FC, $F8, $F0, $E0, $C0);
   //($FE, $FC, $F8, $F0, $E0, $C0, $80, $00);
var
	k, i, len, bitpos, madebit, bufpos: integer;
   ch, tmp, _byte: Byte;
   strKey2: string;
begin
try
	len := Length (source);
   bitpos  := 2;
   madebit := 0;
   bufpos  := 0;
   tmp	  := 0;
   Ch      := 0;

   for i:=1 to len do begin
   	if (Integer(source[i]) - $3C >= 0) and (Integer(source[i]) - $3C <= 64) then
   		ch := Byte(source[i]) - $3C
      else begin
         bufpos := 0;
      	break;
    	end;

      if bufpos >= buflen then break;

      if (madebit+6) >= 8 then begin

         _byte := Byte(tmp or ((ch and $3F) shr (6-bitpos)));

         //---------------------------------------------------------------------
         // XOR 연산
         _byte := _byte xor ( HIBYTE(g_EndeKey) + LOBYTE(g_EndeKey) );   // added by sonmg

			_byte := _byte xor (((bufpos+5)*2)+3);

         // 역치환
//         _byte := _byte xor cXorValue;   // added by sonmg
//         _byte := cTable_return[ Integer(_byte) ] xor g_HideBackTable;   // added by sonmg
         //---------------------------------------------------------------------

        	buf[bufpos] := Char(_byte);
         Inc (bufpos);
         madebit := 0;
         if bitpos < 6 then Inc (bitpos, 2)
         else begin
         	bitpos := 2;
            continue;
         end;
      end;

      tmp := Byte (Byte(ch shl bitpos) and Masks[bitpos]);   // #### ##--
      Inc (madebit, 8-bitpos);
   end;

   buf [bufpos] := #0;
except
end;
end;

procedure Encode6BitBuf_old (src, dest: PChar; srclen, destlen: integer);
var
   i, restcount, destpos: integer;
   made, ch, rest: byte;
begin
try
   restcount := 0;
   rest 		 := 0;
   destpos	 := 0;
   for i:=0 to srclen - 1 do begin
      if destpos >= destlen then break;
      ch := byte (src[i]);
      made := byte ((rest or (ch shr (2+restcount))) and $3F);
      rest := byte (((ch shl (8 - (2+restcount))) shr 2) and $3F);
      Inc (restcount, 2);

      if restcount < 6 then begin
      	dest[destpos] := char(made + $3C);
         Inc (destpos);
      end else begin
      	if destpos < destlen-1 then begin
            dest[destpos]   := char(made + $3C);
            dest[destpos+1] := char(rest + $3C);
            Inc (destpos, 2);
         end else begin
            dest[destpos]   := char(made + $3C);
            Inc (destpos);
         end;
         restcount := 0;
         rest := 0;
      end;

   end;
   if restcount > 0 then begin
   	dest[destpos] := char (rest + $3C);
      Inc (destpos);
   end;
   dest[destpos] := #0;
except
end;
end;

procedure Decode6BitBuf_old (source: string; buf: PChar; buflen: integer);
const
	Masks: array[2..6] of byte = ($FC, $F8, $F0, $E0, $C0);
   //($FE, $FC, $F8, $F0, $E0, $C0, $80, $00);
var
	i, len, bitpos, madebit, bufpos: integer;
   ch, tmp, _byte: Byte;
begin
try
	len := Length (source);
   bitpos  := 2;
   madebit := 0;
   bufpos  := 0;
   tmp	  := 0;
   Ch      := 0;
   for i:=1 to len do begin
   	if (Integer(source[i]) - $3C >= 0) and (Integer(source[i]) - $3C <= 64) then
   		ch := Byte(source[i]) - $3C
      else begin
         bufpos := 0;
      	break;
    	end;

      if bufpos >= buflen then break;

      if (madebit+6) >= 8 then begin
         _byte := Byte(tmp or ((ch and $3F) shr (6-bitpos)));
        	buf[bufpos] := Char(_byte);
         Inc (bufpos);
         madebit := 0;
         if bitpos < 6 then Inc (bitpos, 2)
         else begin
         	bitpos := 2;
            continue;
         end;
      end;

      tmp := Byte (Byte(ch shl bitpos) and Masks[bitpos]);   // #### ##--
      Inc (madebit, 8-bitpos);
   end;
   buf [bufpos] := #0;
except
end;
end;


function DecodeMessage (str: string): TDefaultMessage;
var
   msg: TDefaultMessage;
begin
   try
      EnterCriticalSection (CSencode);
      Decode6BitBuf (str, EncBuf, 1024);
      Move (EncBuf^, msg, sizeof(TDefaultMessage));
      Result := msg;
   finally
   	LeaveCriticalSection (CSencode);
   end;
end;


function DecodeString (str: string): string;
begin
   try
      EnterCriticalSection (CSencode);
      Decode6BitBuf (str, EncBuf, BUFFERSIZE);
      Result := StrPas (EncBuf); //error, 1, 2, 3,...
   finally
      LeaveCriticalSection (CSencode);
   end;
end;

function DecodeString_old (str: string): string;
begin
   try
      EnterCriticalSection (CSencode);
      Decode6BitBuf_old (str, EncBuf, BUFFERSIZE);
      Result := StrPas (EncBuf); //error, 1, 2, 3,...
   finally
      LeaveCriticalSection (CSencode);
   end;
end;

procedure DecodeBuffer (src: string; buf: PChar; bufsize: integer);
begin
   try
      EnterCriticalSection (CSencode);
      Decode6BitBuf (src, EncBuf, BUFFERSIZE);
      Move (EncBuf^, buf^, bufsize);
   finally
   	LeaveCriticalSection (CSencode);
   end;
end;


function  EncodeMessage (smsg: TDefaultMessage): string;
var
   RandKey: byte;
begin
   try
   	EnterCriticalSection (CSencode);
      //
      // old version
//      smsg.Etc := WORD(((smsg.Recog and $57CD) + (smsg.Ident or $48) + (smsg.Param or $30) + (smsg.Tag and $2D) + smsg.Series) xor GetPublicKey);
      RandKey := Random(256);
      smsg.Etc := MAKEWORD( BYTE(RandKey xor $08), BYTE(((smsg.Recog and $57CD) + (smsg.Ident or $48) + (smsg.Param or $30) + (smsg.Tag and $2D) + smsg.Series) xor (GetPublicKey xor RandKey)) );
      //
      Move (smsg, TempBuf^, sizeof(TDefaultMessage));
      Encode6BitBuf (TempBuf, EncBuf, sizeof(TDefaultMessage), 1024);
      Result := StrPas (EncBuf);  //Error: 1, 2, 3, 4, 5, 6, 7, 8, 9
   finally
   	LeaveCriticalSection (CSencode);
   end;
end;


function EncodeString (str: string): string;
begin
   try
   	EnterCriticalSection (CSencode);
      Encode6BitBuf (PChar(str), EncBuf, Length(str), BUFFERSIZE);
      Result := StrPas (EncBuf);
   finally
   	LeaveCriticalSection (CSencode);
   end;
end;


function  EncodeBuffer (buf: pChar; bufsize: integer): string;
begin
   try
      EnterCriticalSection (CSencode);
      if bufsize < BUFFERSIZE then begin
         Move (buf^, TempBuf^, bufsize);
         Encode6BitBuf (TempBuf, EncBuf, bufsize, BUFFERSIZE);
         Result := StrPas (EncBuf);
      end else
         Result := '';
   finally
   	LeaveCriticalSection (CSencode);
   end;
end;


initialization
begin
	GetMem (EncBuf, BUFFERSIZE + 100); //BUFFERSIZE + 100);
	GetMem (TempBuf, BUFFERSIZE + 100); //2048);
   InitializeCriticalSection (CSEncode);
end;


finalization
begin
	//FreeMem (EncBuf, BUFFERSIZE + 100);
   //FreeMem (TempBuf, 2048);
   DeleteCriticalSection (CSEncode);
end;


end.
