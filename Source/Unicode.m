/** Support functions for Unicode implementation
   Function to determine default c string encoding for
   GNUstep based on GNUSTEP_STRING_ENCODING environment variable.

   Copyright (C) 1997 Free Software Foundation, Inc.

   Written by: Stevo Crvenkovski < stevo@btinternet.com >
   Date: March 1997
   Merged with GetDefEncoding.m and iconv by: Fred Kiefer <fredkiefer@gmx.de>
   Date: September 2000

   This file is part of the GNUstep Base Library.

   This library is free software; you can redistribute it and/or
   modify it under the terms of the GNU Library General Public
   License as published by the Free Software Foundation; either
   version 2 of the License, or (at your option) any later version.
   
   This library is distributed in the hope that it will be useful,
   but WITHOUT ANY WARRANTY; without even the implied warranty of
   MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
   Library General Public License for more details.

   You should have received a copy of the GNU Library General Public
   License along with this library; if not, write to the Free
   Software Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA 02111 USA.
*/ 

#include <config.h>
#include <Foundation/NSString.h>
#include <base/Unicode.h>
#include <stdio.h>
#include <stdlib.h>

typedef struct {unichar from; char to;} _ucc_;

#include "unicode/cyrillic.h"
#include "unicode/latin2.h"
#include "unicode/nextstep.h"
#include "unicode/caseconv.h"
#include "unicode/cop.h"
#include "unicode/decomp.h"
#include "unicode/gsm0338.h"

#ifdef HAVE_ICONV
#ifdef HAVE_GICONV_H
#include <giconv.h>
#else
#include <iconv.h>
#endif
#include <errno.h>

// The rest of the GNUstep code stores UNICODE in internal byte order,
// so we do the same. This should be UCS-2-INTERNAL for libiconv
#ifdef WORDS_BIGENDIAN
#define UNICODE_INT "UNICODEBIG"
#else
#define UNICODE_INT "UNICODELITTLE"
#endif

#define UNICODE_ENC ((unicode_enc) ? unicode_enc : internal_unicode_enc())

static const char *unicode_enc = NULL;

#endif 


typedef	unsigned char	unc;
static NSStringEncoding	defEnc = GSUndefinedEncoding;

#ifdef HAVE_ICONV
/*
 * FIXME: We should check dynamically which encodings are found on this
 * computer as different implementation of iconv will support different
 * encodings. 
 */
static NSStringEncoding _availableEncodings[] = {
    NSASCIIStringEncoding,
    NSNEXTSTEPStringEncoding,
    NSJapaneseEUCStringEncoding,
    NSUTF8StringEncoding,
    NSISOLatin1StringEncoding,
//    NSSymbolStringEncoding,
//    NSNonLossyASCIIStringEncoding,
    NSShiftJISStringEncoding,
    NSISOLatin2StringEncoding,
    NSUnicodeStringEncoding,
    NSWindowsCP1251StringEncoding,
    NSWindowsCP1252StringEncoding,
    NSWindowsCP1253StringEncoding,
    NSWindowsCP1254StringEncoding,
    NSWindowsCP1250StringEncoding,
    NSISO2022JPStringEncoding,
    NSMacOSRomanStringEncoding,
//    NSProprietaryStringEncoding,
// GNUstep additions
    NSISOCyrillicStringEncoding,
    NSKOI8RStringEncoding,
    NSISOLatin3StringEncoding,
    NSISOLatin4StringEncoding,
    NSISOArabicStringEncoding,
    NSISOGreekStringEncoding,
    NSISOHebrewStringEncoding,
    NSGB2312StringEncoding,
    NSGSM0338StringEncoding,
    NSBIG5StringEncoding,
    0
};
#else
// Uncomment when implemented
static NSStringEncoding _availableEncodings[] = {
    NSASCIIStringEncoding,
    NSNEXTSTEPStringEncoding,
//    NSJapaneseEUCStringEncoding,
//    NSUTF8StringEncoding,
    NSISOLatin1StringEncoding,
//    NSSymbolStringEncoding,
//    NSNonLossyASCIIStringEncoding,
//    NSShiftJISStringEncoding,
    NSISOLatin2StringEncoding,
    NSUnicodeStringEncoding,
//    NSWindowsCP1251StringEncoding,
//    NSWindowsCP1252StringEncoding,
//    NSWindowsCP1253StringEncoding,
//    NSWindowsCP1254StringEncoding,
//    NSWindowsCP1250StringEncoding,
//    NSISO2022JPStringEncoding,
//    NSMacOSRomanStringEncoding,
//    NSProprietaryStringEncoding,
// GNUstep additions
    NSISOCyrillicStringEncoding,
//    NSKOI8RStringEncoding,
//    NSISOLatin3StringEncoding,
//    NSISOLatin4StringEncoding,
//    NSISOArabicStringEncoding,
//    NSISOGreekStringEncoding,
//    NSISOHebrewStringEncoding,
//    NSGB2312StringEncoding,
    NSGSM0338StringEncoding,
    NSBIG5StringEncoding,
    0
};
#endif 

struct _strenc_ {NSStringEncoding enc; char *ename;};
const struct _strenc_ str_encoding_table[]=
{
  {NSASCIIStringEncoding,"NSASCIIStringEncoding"},
  {NSNEXTSTEPStringEncoding,"NSNEXTSTEPStringEncoding"},
  {NSJapaneseEUCStringEncoding, "NSJapaneseEUCStringEncoding"},
  {NSUTF8StringEncoding,"NSUTF8StringEncoding"},
  {NSISOLatin1StringEncoding,"NSISOLatin1StringEncoding"},
  {NSSymbolStringEncoding,"NSSymbolStringEncoding"},
  {NSNonLossyASCIIStringEncoding,"NSNonLossyASCIIStringEncoding"},
  {NSShiftJISStringEncoding,"NSShiftJISStringEncoding"},
  {NSISOLatin2StringEncoding,"NSISOLatin2StringEncoding"},
  {NSUnicodeStringEncoding, "NSUnicodeStringEncoding"},
  {NSWindowsCP1251StringEncoding,"NSWindowsCP1251StringEncoding"},
  {NSWindowsCP1252StringEncoding,"NSWindowsCP1252StringEncoding"},
  {NSWindowsCP1253StringEncoding,"NSWindowsCP1253StringEncoding"},
  {NSWindowsCP1254StringEncoding,"NSWindowsCP1254StringEncoding"},
  {NSWindowsCP1250StringEncoding,"NSWindowsCP1250StringEncoding"},
  {NSISO2022JPStringEncoding,"NSISO2022JPStringEncoding "},
  {NSMacOSRomanStringEncoding, "NSMacOSRomanStringEncoding"},
  {NSProprietaryStringEncoding, "NSProprietaryStringEncoding"},

// GNUstep additions
  {NSISOCyrillicStringEncoding,"NSISOCyrillicStringEncoding"},
  {NSKOI8RStringEncoding, "NSKOI8RStringEncoding"},
  {NSISOLatin3StringEncoding, "NSISOLatin3StringEncoding"},
  {NSISOLatin4StringEncoding, "NSISOLatin4StringEncoding"},
  {NSISOArabicStringEncoding, "NSISOArabicStringEncoding"},
  {NSISOGreekStringEncoding, "NSISOGreekStringEncoding"},
  {NSISOHebrewStringEncoding, "NSISOHebrewStringEncoding"},
  {NSISOLatin5StringEncoding, "NSISOLatin5StringEncoding"},
  {NSISOLatin6StringEncoding, "NSISOLatin6StringEncoding"},
  {NSISOLatin7StringEncoding, "NSISOLatin7StringEncoding"},
  {NSISOLatin8StringEncoding, "NSISOLatin8StringEncoding"},
  {NSISOLatin9StringEncoding, "NSISOLatin9StringEncoding"},
  {NSUTF7StringEncoding, "NSUTF7StringEncoding"},
  {NSGB2312StringEncoding, "NSGB2312StringEncoding"},
  {NSGSM0338StringEncoding, "NSGSM0338StringEncoding"},
  {NSBIG5StringEncoding, "NSBIG5StringEncoding"},

  {0, "Unknown encoding"}
};



NSStringEncoding *GetAvailableEncodings()
{
  // FIXME: This should check which iconv definitions are available and 
  // add them to the availble encodings
  return _availableEncodings;
}

NSStringEncoding
GetDefEncoding()
{
  if (defEnc == GSUndefinedEncoding)
    {
      char		*encoding;
      unsigned int	count;
      NSStringEncoding	tmp;
      NSStringEncoding	*availableEncodings;

      availableEncodings = GetAvailableEncodings();

      encoding = getenv("GNUSTEP_STRING_ENCODING");
      if (encoding != 0)
	{
	  count = 0;
	  while (str_encoding_table[count].enc
	    && strcmp(str_encoding_table[count].ename,encoding))
	    {
	      count++;
	    }
	  if (str_encoding_table[count].enc)
	    {
	      defEnc = str_encoding_table[count].enc;
	      if ((defEnc == NSUnicodeStringEncoding)
		|| (defEnc == NSUTF8StringEncoding)
		|| (defEnc == NSSymbolStringEncoding))
		{
		  fprintf(stderr, "WARNING: %s - encoding not supported as "
		    "default c string encoding.\n", encoding);
		  fprintf(stderr,
		    "NSISOLatin1StringEncoding set as default.\n");
		  defEnc = NSISOLatin1StringEncoding;
		}
	      else /*encoding should be supported but is it implemented?*/
		{
		  count = 0;
		  tmp = 0;
		  while (availableEncodings[count] != 0)
		    {
		      if (defEnc != availableEncodings[count])
			{
			  tmp = 0;
			}
		      else
			{
			  tmp = defEnc;
			  break;
			}
		      count++;
		    }
		  if (tmp == 0 && defEnc != NSISOLatin1StringEncoding)
		    {
		      fprintf(stderr,
			"WARNING: %s - encoding not yet implemented.\n",
			encoding);
		      fprintf(stderr,
			"NSISOLatin1StringEncoding set as default.\n");
		      defEnc = NSISOLatin1StringEncoding;
		    }
		}
	    }
	  else /* encoding not found */
	    {
	      fprintf(stderr,
		"WARNING: %s - encoding not supported.\n", encoding);
	      fprintf(stderr, "NSISOLatin1StringEncoding set as default.\n");
	      defEnc = NSISOLatin1StringEncoding;
	    }
	}
      else /* environment var not found */
	{
	  /* shouldn't be required. It really should be in UserDefaults - asf */
	  //fprintf(stderr, "WARNING: GNUSTEP_STRING_ENCODING environment");
	  //fprintf(stderr, " variable not found.\n");
	  //fprintf(stderr, "NSISOLatin1StringEncoding set as default.\n");
	  defEnc = NSISOLatin1StringEncoding;
	}
    }
  return defEnc;
}

NSString*
GetEncodingName(NSStringEncoding encoding)
{
  unsigned int count=0;

  while (str_encoding_table[count].enc
    && (str_encoding_table[count].enc != encoding))
    {
      count++;
    }

  return [NSString stringWithCString: str_encoding_table[count].ename];
}

#ifdef HAVE_ICONV

/* Check to see what type of internal unicode format the library supports */
static const char *
internal_unicode_enc()
{
  iconv_t conv;
  unicode_enc = UNICODE_INT;
  conv = iconv_open(unicode_enc, "ASCII");
  if (conv != (iconv_t)-1)
    {
      iconv_close(conv);
      return unicode_enc;
    }
  unicode_enc = "UCS-2-INTERNAL";
  conv = iconv_open(unicode_enc, "ASCII");
  if (conv != (iconv_t)-1)
    {
      iconv_close(conv);
      return unicode_enc;
    }
  unicode_enc = "UCS-2";
  /* This had better work */
  return unicode_enc;
}

static const char *
iconv_stringforencoding(NSStringEncoding enc)
{
  switch (enc)
    {
      case NSASCIIStringEncoding: 
	return "ASCII";
      case NSNEXTSTEPStringEncoding:
	return "NEXTSTEP";
      case NSISOLatin1StringEncoding: 
	return "ISO-8859-1";
      case NSISOLatin2StringEncoding: 
	return "ISO-8859-2";
      case NSUnicodeStringEncoding: 
	return UNICODE_ENC;
      case NSJapaneseEUCStringEncoding: 
	return "EUC-JP";
      case NSUTF8StringEncoding:
	return "UTF-8";
      case NSShiftJISStringEncoding:
	return "SHIFT-JIS";
      case NSWindowsCP1250StringEncoding:
	return "CP1250";
      case NSWindowsCP1251StringEncoding:
	return "CP1251";
      case NSWindowsCP1252StringEncoding:
	return "CP1252";
      case NSWindowsCP1253StringEncoding:
	return "CP1253";
      case NSWindowsCP1254StringEncoding:
	return "CP1254";
      case NSISO2022JPStringEncoding:
	return "ISO-2022-JP";
      case NSMacOSRomanStringEncoding:
	return "MACINTOSH";

      // GNUstep extensions
      case NSKOI8RStringEncoding: 
	return "KOI8-R";
      case NSISOLatin3StringEncoding: 
	return "ISO-8859-3";
      case NSISOLatin4StringEncoding: 
	return "ISO-8859-4";
      case NSISOCyrillicStringEncoding:
	return "ISO-8859-5";
      case NSISOArabicStringEncoding: 
	return "ISO-8859-6";
      case NSISOGreekStringEncoding: 
	return "ISO-8859-7";
      case NSISOHebrewStringEncoding:
	return "ISO-8859-8";

      case NSISOLatin5StringEncoding: 
	return "ISO-8859-9";
      case NSISOLatin6StringEncoding: 
	return "ISO-8859-10";
      case NSISOLatin7StringEncoding: 
	return "ISO-8859-13";
      case NSISOLatin8StringEncoding: 
	return "ISO-8859-14";
      case NSISOLatin9StringEncoding: 
	return "ISO-8859-15";

      case NSGB2312StringEncoding:
	return "EUC-CN";

      case NSBIG5StringEncoding:
	return "BIG5";
      default:
	return "";
    }
}

int
iconv_cstrtoustr(unichar *u2, int size2, const char *s1, int size1,
  NSStringEncoding enc)
{
  iconv_t conv;
  int usize = sizeof(unichar)*size2;
  char *u1 = (char*)u2;
  int ret_val;

  conv = iconv_open(UNICODE_ENC, iconv_stringforencoding(enc));
  if (conv == (iconv_t)-1)
    {
      NSLog(@"No iconv for encoding %@ tried to use %s", 
	    GetEncodingName(enc), iconv_stringforencoding(enc));
      return 0;
    }

  ret_val = iconv(conv, (char**)&s1, &size1, &u1, &usize);
  // close the converter
  iconv_close(conv);
  if (ret_val == -1)
    {
      return 0;
    }

  return (u1 - (char*)u2)/sizeof(unichar);	// Num unicode chars produced.
}

int
iconv_ustrtocstr(char *s2, int size2, const unichar *u1, int size1,
  NSStringEncoding enc)
{
  iconv_t	conv;
  int		usize = sizeof(unichar)*size1;
  char		*s1 = s2;
  const		char *u2 = (const char*)u1;
  int		ret_val;

  conv = iconv_open(iconv_stringforencoding(enc), UNICODE_ENC);
  if (conv == (iconv_t)-1)
    {
      NSLog(@"No iconv for encoding %@ tried to use %s", 
	    GetEncodingName(enc), iconv_stringforencoding(enc));
      return 0;
    }

  ret_val = iconv(conv, (char**)&u2, &usize, &s2, &size2);
  // close the converter
  iconv_close(conv);
  if (ret_val == -1)
    {
      return 0;
    }

  return s2 - s1;
}

#endif

unichar
encode_chartouni(char c, NSStringEncoding enc)
{
  /* All that I could find in Next documentation
    on NSNonLossyASCIIStringEncoding was << forthcoming >>. */
  switch (enc)
    {
      case NSNonLossyASCIIStringEncoding:
      case NSASCIIStringEncoding:
      case NSISOLatin1StringEncoding:
      case NSUnicodeStringEncoding:	  
	return (unichar)((unc)c);

      case NSNEXTSTEPStringEncoding:
	if ((unc)c < Next_conv_base)
	  return (unichar)((unc)c);
	else
	  return(Next_char_to_uni_table[(unc)c - Next_conv_base]);

      case NSISOCyrillicStringEncoding:
	if ((unc)c < Cyrillic_conv_base)
	  return (unichar)((unc)c);
	else
	  return(Cyrillic_char_to_uni_table[(unc)c - Cyrillic_conv_base]);

      case NSISOLatin2StringEncoding:
	if ((unc)c < Latin2_conv_base)
	  return (unichar)((unc)c);
	else
	  return(Latin2_char_to_uni_table[(unc)c - Latin2_conv_base]);

      case NSGSM0338StringEncoding:
	return(GSM0338_char_to_uni_table[(unc)c]);

#if 0
      case NSSymbolStringEncoding:
	if ((unc)c < Symbol_conv_base)
	  return (unichar)((unc)c);
	else
	  return(Symbol_char_to_uni_table[(unc)c - Symbol_conv_base]);
#endif

      default:
#ifdef HAVE_ICONV
      {
	unichar u;
	
	if (iconv_cstrtoustr(&u, 1, &c, 1, enc) > 0)
	  return u;
	else
	  return 0;
      }
#else 
	return 0;
#endif 
    }
}

char
encode_unitochar(unichar u, NSStringEncoding enc)
{
  int	res;
  int	i = 0;

  switch (enc)
    {
      case NSNonLossyASCIIStringEncoding:
	if (u < 128)
	  return (char)u;
	else
	  return '*';

      case NSASCIIStringEncoding:
	if (u < 128)
	  return (char)u;
	else
	  return '*';

      case NSISOLatin1StringEncoding:
      case NSUnicodeStringEncoding:	  
	if (u < 256)
	  return (char)u;
	else
	  return '*';

      case NSNEXTSTEPStringEncoding:
	if (u < (unichar)Next_conv_base)
	  return (char)u;
	else
	  {
	    while (((res = u - Next_uni_to_char_table[i++].from) > 0)
	      && (i < Next_uni_to_char_table_size));
	    return res ? '*' : Next_uni_to_char_table[--i].to;
	  }

      case NSISOCyrillicStringEncoding:
	if (u < (unichar)Cyrillic_conv_base)
	  return (char)u;
	else
	  {
	    while (((res = u - Cyrillic_uni_to_char_table[i++].from) > 0)
	      && (i < Cyrillic_uni_to_char_table_size));
	    return res ? '*' : Cyrillic_uni_to_char_table[--i].to;
	  }

      case NSISOLatin2StringEncoding:
	if (u < (unichar)Latin2_conv_base)
	  return (char)u;
	else
	  {
	    while (((res = u - Latin2_uni_to_char_table[i++].from) > 0)
	      && (i < Latin2_uni_to_char_table_size));
	    return res ? '*' : Latin2_uni_to_char_table[--i].to;
	  }

      case NSGSM0338StringEncoding:
	{
	  while (((res = u - GSM0338_uni_to_char_table[i++].from) > 0)
	    && (i < GSM0338_tsize));
	  return res ? '*' : GSM0338_uni_to_char_table[--i].to;
	}
#if 0
      case NSSymbolStringEncoding:
	if (u < (unichar)Symbol_conv_base)
	  return (char)u;
	else
	  {
	    while (((res = u - Symbol_uni_to_char_table[i++].from) > 0)
	      && (i < Symbol_uni_to_char_table_size));
	    return res ? '*' : Symbol_uni_to_char_table[--i].to;
	  }
#endif

      default:
#ifdef HAVE_ICONV
      {
	char c[4];
	int r = iconv_ustrtocstr(c, 4, &u, 1, enc);

	if (r > 0)
	  return c[0];
	else
	  return '*';
      }
#else
	return '*';
#endif 
    }
}

unsigned
encode_unitochar_strict(unichar u, NSStringEncoding enc)
{
  int	res;
  int	i = 0;

  switch (enc)
    {
      case NSNonLossyASCIIStringEncoding:
	if (u < 128)
	  return (char)u;
	else
	  return 0;

      case NSASCIIStringEncoding:
	if (u < 128)
	  return (char)u;
	else
	  return 0;

      case NSISOLatin1StringEncoding:
	if (u < 256)
	  return (char)u;
	else
	  return 0;

      case NSUnicodeStringEncoding: 
	return u;

      case NSNEXTSTEPStringEncoding:
	if (u < (unichar)Next_conv_base)
	  return (char)u;
	else
	  {
	    while (((res = u - Next_uni_to_char_table[i++].from) > 0)
	      && (i < Next_uni_to_char_table_size));
	    return res ? 0 : Next_uni_to_char_table[--i].to;
	  }

      case NSISOCyrillicStringEncoding:
	if (u < (unichar)Cyrillic_conv_base)
	  return (char)u;
	else
	  {
	    while (((res = u - Cyrillic_uni_to_char_table[i++].from) > 0)
	      && (i < Cyrillic_uni_to_char_table_size));
	    return res ? 0 : Cyrillic_uni_to_char_table[--i].to;
	  }

      case NSISOLatin2StringEncoding:
	if (u < (unichar)Latin2_conv_base)
	  return (char)u;
	else
	  {
	    while (((res = u - Latin2_uni_to_char_table[i++].from) > 0)
	      && (i < Latin2_uni_to_char_table_size));
	    return res ? 0 : Latin2_uni_to_char_table[--i].to;
	  }

      case NSGSM0338StringEncoding:
	{
	  while (((res = u - GSM0338_uni_to_char_table[i++].from) > 0)
	    && (i < GSM0338_tsize));
	  return res ? 0 : GSM0338_uni_to_char_table[--i].to;
	}

#if 0
      case NSSymbolStringEncoding:
	if (u < (unichar)Symbol_conv_base)
	  return (char)u;
	else
	  {
	    while (((res = u - Symbol_uni_to_char_table[i++].from) > 0)
	      && (i < Symbol_uni_to_char_table_size));
	    return res ? 0 : Symbol_uni_to_char_table[--i].to;
	  }
#endif

      default:
#ifdef HAVE_ICONV
      {
	unsigned char c[4];
	int r = iconv_ustrtocstr(c, 4, &u, 1, enc);

	if (r == 2)
#ifdef WORDS_BIGENDIAN
	  return 256*c[0] + c[1];
#else
	  return 256*c[1] + c[0];
#endif
	else if (r > 0)
	  return c[0];
	else
	  return 0;
      }
#else
	return 0;
#endif 
    }
}

unichar
chartouni(char c)
{
  if (defEnc == GSUndefinedEncoding)
    {
      defEnc = GetDefEncoding();
    }
  return encode_chartouni(c, defEnc);
}

char
unitochar(unichar u)
{
  if (defEnc == GSUndefinedEncoding)
    {
      defEnc = GetDefEncoding();
    }
  return encode_unitochar(u, defEnc);
}

/*
 * These two functions use direct access into a two-level table to map cases.
 * The two-level table method is less space efficient (but still not bad) than
 * a single table and a linear search, but it reduces the number of
 * conditional statements to just one.
 */
unichar
uni_tolower(unichar ch)
{
  unichar result = gs_tolower_map[ch / 256][ch % 256];

  return result ? result : ch;
}
 
unichar
uni_toupper(unichar ch)
{
  unichar result = gs_toupper_map[ch / 256][ch % 256];

  return result ? result : ch;
}

unsigned char
uni_cop(unichar u)
{
  unichar	count, first, last, comp;
  BOOL		notfound;

  first = 0;
  last = uni_cop_table_size;
  notfound = YES;
  count = 0;

  if (u > (unichar)0x0080)  // no nonspacing in ascii
    {
      while (notfound && (first <= last))
	{
	  if (first != last)
	    {
	      count = (first + last) / 2;
	      comp = uni_cop_table[count].code;
	      if (comp < u)
		{
		  first = count+1;
		}
	      else
		{
		  if (comp > u)
		    last = count-1;
		  else
		    notfound = NO;
		}
	    }
	  else  /* first == last */
	    {
	      if (u == uni_cop_table[first].code)
		return uni_cop_table[first].cop;
	      return 0;
	    } /* else */
	} /* while notfound ...*/
      return notfound ? 0 : uni_cop_table[count].cop;
    }
  else /* u is ascii */
    return 0;
}

BOOL
uni_isnonsp(unichar u)
{
// check is uni_cop good for this
  if (uni_cop(u))
    return YES;
  else
    return NO;
}

unichar*
uni_is_decomp(unichar u)
{
  unichar	count, first, last, comp;
  BOOL		notfound;

  first = 0;
  last = uni_dec_table_size;
  notfound = YES;
  count = 0;

  if (u > (unichar)0x0080)  // no composites in ascii
    {
      while (notfound && (first <= last))
	{
	  if (!(first == last))
	    {
	      count = (first + last) / 2;
	      comp = uni_dec_table[count].code;
	      if (comp < u)
		first = count+1;
	      else
		{
		  if (comp > u)
		    last = count-1;
		  else
		    notfound = NO;
		}
	    }
	  else  /* first == last */
	    {
	      if (u == uni_dec_table[first].code)
		return uni_dec_table[first].decomp;
	      return 0;
	    } /* else */
	} /* while notfound ...*/
      return notfound ? 0 : uni_dec_table[count].decomp;
    }
  else /* u is ascii */
    return 0;
}


int encode_ustrtocstr(char *dst, int dl, const unichar *src, int sl, 
  NSStringEncoding enc, BOOL strict)
{
  if (strict == YES)
    {
      int count;
      unichar u;

      switch (enc)
	{
	  case NSNonLossyASCIIStringEncoding:
	    for (count = 0; count < sl && count < dl; count++)
	      {
		u = src[count];
		if (u < 128)
		  dst[count] = (char)u;
		else
		  return 0;
	      }
	    if (count < sl)
	      return 0;		// Not all characters converted.
	    return count;

	  case NSASCIIStringEncoding:
	    for (count = 0; count < sl && count < dl; count++)
	      {
		u = src[count];
		if (u < 128)
		  dst[count] = (char)u;
		else
		  return 0;
	      }
	    if (count < sl)
	      return 0;		// Not all characters converted.
	    return count;

	  case NSISOLatin1StringEncoding:
	  case NSUnicodeStringEncoding: 	  
	    for (count = 0; count < sl && count < dl; count++)
	      {
		u = src[count];
		if (u < 256)
		  dst[count] = (char)u;
		else
		  return 0;
	      }
	    if (count < sl)
	      return 0;		// Not all characters converted.
	    return count;

	  case NSNEXTSTEPStringEncoding:
	    for (count = 0; count < sl && count < dl; count++)
	      {
		u = src[count];
		if (u < (unichar)Next_conv_base)
		  {
		    dst[count] = (char)u;
		  }
		else
		  {
		    int res;
		    int i = 0;

		    while (((res = u - Next_uni_to_char_table[i++].from) > 0)
		      && (i < Next_uni_to_char_table_size));
		    if (!res)
		      dst[count] = Next_uni_to_char_table[--i].to;
		    else
		      return 0;
		  }
	      }
	    if (count < sl)
	      return 0;		// Not all characters converted.
	    return count;

	  case NSISOCyrillicStringEncoding:
	    for (count = 0; count < sl && count < dl; count++)
	      {
		u = src[count];
		if (u < (unichar)Cyrillic_conv_base)
		  dst[count] = (char)u;
		else
		  {
		    int res;
		    int i = 0;

		    while (((res = u - Cyrillic_uni_to_char_table[i++].from)
		      > 0) && (i < Cyrillic_uni_to_char_table_size));
		    if (!res)
		      dst[count] = Cyrillic_uni_to_char_table[--i].to;
		    else
		      return 0;
		  }
	      }
	    if (count < sl)
	      return 0;		// Not all characters converted.
	    return count;

	  case NSISOLatin2StringEncoding:
	    for (count = 0; count < sl && count < dl; count++)
	      {
		u = src[count];
		if (u < (unichar)Latin2_conv_base)
		  {
		    dst[count] = (char)u;
		  }
		else
		  {
		    int res;
		    int i = 0;

		    while (((res = u - Latin2_uni_to_char_table[i++].from) > 0)
		      && (i < Latin2_uni_to_char_table_size));
		    if (!res)
		      dst[count] = Latin2_uni_to_char_table[--i].to;
		    else
		      return 0;
		  }
	      }
	    if (count < sl)
	      return 0;		// Not all characters converted.
	    return count;

	  case NSGSM0338StringEncoding:
	    {
	      int	dc;

	      for (dc = count = 0; count < sl && dc < dl; count++, dc++)
		{
		  int res;
		  int i = 0;

		  u = src[count];

		  while (((res = u - GSM0338_uni_to_char_table[i++].from) > 0)
		    && (i < GSM0338_tsize));
		  if (!res)
		    {
		      dst[dc] = GSM0338_uni_to_char_table[--i].to;
		    }
		  else if (dc < dl - 1)
		    {
		      for (i = 0; i < GSM0338_esize; i++)
			{
			  if (GSM0338_escapes[i].from == u)
			    {
			      dst[dc++] = 0x1b;
			      dst[dc] = GSM0338_escapes[i].to;
			      break;
			    }
			}
		      if (i == GSM0338_esize)
			{
			  return 0;
			}
		    }
		  else
		    {
		      return 0;
		    }
		}
	      if (count < sl)
		{
		  return 0;		// Not all characters converted.
		}
	      return dc;
	    }

#if 0
	  case NSSymbolStringEncoding:
	    for (count = 0; count < sl && count < dl; count++)
	      {
		u = src[count];
		if (u < (unichar)Symbol_conv_base)
		  dst[count] = (char)u;
		else
		  {
		    int res;
		    int i = 0;

		    while (((res = u - Symbol_uni_to_char_table[i++].from) > 0)
		      && (i < Symbol_uni_to_char_table_size));
		    if (!res)
		      dst[count] = Symbol_uni_to_char_table[--i].to;
		    else
		      return 0;
		  }
	      }
	    if (count < sl)
	      return 0;		// Not all characters converted.
	    return count;
#endif

	  default:
#ifdef HAVE_ICONV
	    return iconv_ustrtocstr(dst, dl, src, sl, enc);
#else
	    return 0;
#endif 
	}
    }
  else
    {
      int count;
      unichar u;

      switch (enc)
	{
	  case NSNonLossyASCIIStringEncoding:
	    for (count = 0; count < sl && count < dl; count++)
	      {
		u = src[count];
		if (u < 128)
		  dst[count] = (char)u;
		else
		  dst[count] =  '*';
	      }
	    if (count < sl)
	      return 0;		// Not all characters converted.
	    return count;

	  case NSASCIIStringEncoding:
	    for (count = 0; count < sl && count < dl; count++)
	      {
		u = src[count];
		if (u < 128)
		  dst[count] = (char)u;
		else
		  dst[count] =  '*';
	      }
	    if (count < sl)
	      return 0;		// Not all characters converted.
	    return count;

	  case NSISOLatin1StringEncoding:
	  case NSUnicodeStringEncoding: 	  
	    for (count = 0; count < sl && count < dl; count++)
	      {
		u = src[count];
		if (u < 256)
		  dst[count] = (char)u;
		else
		  dst[count] = '*';
	      }
	    if (count < sl)
	      return 0;		// Not all characters converted.
	    return count;

	  case NSNEXTSTEPStringEncoding:
	    for (count = 0; count < sl && count < dl; count++)
	      {
		u = src[count];
		if (u < (unichar)Next_conv_base)
		  dst[count] = (char)u;
		else
		  {
		    int res;
		    int i = 0;

		    while (((res = u - Next_uni_to_char_table[i++].from) > 0)
		      && (i < Next_uni_to_char_table_size));
		    dst[count] = res ? '*' : Next_uni_to_char_table[--i].to;
		  }
	      }
	    if (count < sl)
	      return 0;		// Not all characters converted.
	    return count;

	  case NSISOCyrillicStringEncoding:
	    for (count = 0; count < sl && count < dl; count++)
	      {
		u = src[count];
		if (u < (unichar)Cyrillic_conv_base)
		  dst[count] = (char)u;
		else
		  {
		    int res;
		    int i = 0;

		    while (((res = u - Cyrillic_uni_to_char_table[i++].from)
		      > 0) && (i < Cyrillic_uni_to_char_table_size));
		    dst[count] = res ? '*' : Cyrillic_uni_to_char_table[--i].to;
		  }
	      }
	    if (count < sl)
	      return 0;		// Not all characters converted.
	    return count;

	  case NSISOLatin2StringEncoding:
	    for (count = 0; count < sl && count < dl; count++)
	      {
		u = src[count];
		if (u < (unichar)Latin2_conv_base)
		  dst[count] = (char)u;
		else
		  {
		    int res;
		    int i = 0;

		    while (((res = u - Latin2_uni_to_char_table[i++].from) > 0)
		      && (i < Latin2_uni_to_char_table_size));
		    dst[count] = res ? '*' : Latin2_uni_to_char_table[--i].to;
		  }
	      }
	    if (count < sl)
	      return 0;		// Not all characters converted.
	    return count;

	  case NSGSM0338StringEncoding:
	    {
	      int	dc;

	      for (dc = count = 0; count < sl && dc < dl; count++, dc++)
		{
		  int res;
		  int i = 0;

		  u = src[count];

		  while (((res = u - GSM0338_uni_to_char_table[i++].from) > 0)
		    && (i < GSM0338_tsize));
		  if (!res)
		    {
		      dst[dc] = GSM0338_uni_to_char_table[--i].to;
		    }
		  else if (dc < dl - 1)
		    {
		      for (i = 0; i < GSM0338_esize; i++)
			{
			  if (GSM0338_escapes[i].from == u)
			    {
			      dst[dc++] = 0x1b;
			      dst[dc] = GSM0338_escapes[i].to;
			      break;
			    }
			}
		      if (i == GSM0338_esize)
			{
			  dst[dc] = '*';
			}
		    }
		  else
		    {
		      dst[dc] = '*';
		    }
		}
	      if (count < sl)
		{
		  return 0;		// Not all characters converted.
		}
	      return dc;
	    }

#if 0
	  case NSSymbolStringEncoding:
	    for (count = 0; count < sl && count < dl; count++)
	      {
		u = src[count];
		if (u < (unichar)Symbol_conv_base)
		  dst[count] = (char)u;
		else
		  {
		    int res;
		    int i = 0;

		    while (((res = u - Symbol_uni_to_char_table[i++].from) > 0)
		      && (i < Symbol_uni_to_char_table_size));
		    dst[count] = res ? '*' : Symbol_uni_to_char_table[--i].to;
		  }
	      }
	    if (count < sl)
	      return 0;		// Not all characters converted.
	    return count;
#endif

	  default:
#ifdef HAVE_ICONV
	    // FIXME: The non-strict encoding is still missing
	    return iconv_ustrtocstr(dst, dl, src, sl, enc);
#else
	    return 0;
#endif 
	}
    }
}

/**
 * Convert to unicode .. return the number of unicode characters produced.
 */
int encode_cstrtoustr(unichar *dst, int dl, const char *src, int sl, 
  NSStringEncoding enc)
{
  int count;

  switch (enc)
    {
      case NSNonLossyASCIIStringEncoding:
      case NSASCIIStringEncoding:
      case NSISOLatin1StringEncoding:
      case NSUnicodeStringEncoding: 	  
	for (count = 0; count < sl && count < dl; count++)
	  {
	    dst[count] = (unichar)((unc)src[count]);
	  }
	if (count < sl)
	  return 0;		// Not all characters converted.
	return count;

      case NSNEXTSTEPStringEncoding:
	for (count = 0; count < sl && count < dl; count++)
	  {
	    unc c = (unc)src[count];

	    if (c < Next_conv_base)
	      dst[count] = (unichar)c;
	    else
	      dst[count] = Next_char_to_uni_table[c - Next_conv_base];
	  }
	if (count < sl)
	  return 0;		// Not all characters converted.
	return count;

      case NSISOCyrillicStringEncoding:
	for (count = 0; count < sl && count < dl; count++)
	  {
	    unc c = (unc)src[count];

	    if (c < Cyrillic_conv_base)
	      dst[count] = (unichar)c;
	    else
	      dst[count] = Cyrillic_char_to_uni_table[c - Cyrillic_conv_base];
	  }
	if (count < sl)
	  return 0;		// Not all characters converted.
	return count;

      case NSISOLatin2StringEncoding:
	for (count = 0; count < sl && count < dl; count++)
	  {
	    unc c = (unc)src[count];

	    if (c < Latin2_conv_base)
	      dst[count] = (unichar)c;
	    else
	      dst[count] = Latin2_char_to_uni_table[c - Latin2_conv_base];
	  }
	if (count < sl)
	  return 0;		// Not all characters converted.
	return count;
	    
      case NSGSM0338StringEncoding:
	{
	  int	dc;

	  for (dc = count = 0; count < sl && dc < dl; count++, dc++)
	    {
	      unc c = (unc)src[count];

	      dst[dc] = GSM0338_char_to_uni_table[c];
	      if (c == 0x1b && count < sl)
		{
		  unsigned	i = 0;

		  c = (unc)src[count+1];
		  while (i < sizeof(GSM0338_escapes)/sizeof(GSM0338_escapes[0]))
		    {
		      if (GSM0338_escapes[i].to == c)
			{
			  dst[dc] = GSM0338_escapes[i].from;
			  count++;
			  break;
			}
		    }
		}
	    }
	  if (count < sl)
	    return 0;		// Not all characters converted.
	  return dc;    
	}

#if 0
      case NSSymbolStringEncoding:
	for (count = 0; count < sl && count < dl; count++)
	  {
	    unc c = (unc)src[count];

	    if (c < Symbol_conv_base)
		dst[count] = (unichar)c;
	    else
		dst[count] = Symbol_char_to_uni_table[c - Symbol_conv_base];
	  }
	if (count < sl)
	  return 0;		// Not all characters converted.
	return count;    
#endif

      default:
#ifdef HAVE_ICONV
	return iconv_cstrtoustr(dst, dl, src, sl, enc);
#else 
	return 0;
#endif 
    }
/*
  for (count = 0; count < sl && count < dl; count++)
    {
      dst[count] = encode_chartouni(src[count], enc);
    }
  if (count < sl)
    return 0;		// Not all characters converted.
  return count;
*/
}




#define	GROW() \
if (dst == 0) \
  { \
    /* \
     * Data is just being discarded anyway, so we can \
     * adjust the offset into the local buffer on the \
     * stack and pretend the buffer has grown. \
     */ \
    ptr -= BUFSIZ; \
    bsize += BUFSIZ; \
  } \
else if (zone == 0) \
  { \
    return NO; /* No buffer growth possible ... fail. */ \
  } \
else \
  { \
    unsigned	grow = slen; \
\
    if (grow < bsize + BUFSIZ) \
      { \
	grow = bsize + BUFSIZ; \
      } \
    grow *= sizeof(unichar); \
\
    if (ptr == buf || ptr == *dst) \
      { \
	unichar	*tmp; \
\
	tmp = NSZoneMalloc(zone, grow + extra); \
	if (tmp != 0) \
	  { \
	    memcpy(tmp, ptr, bsize * sizeof(unichar)); \
	  } \
	ptr = tmp; \
      } \
    else \
      { \
	ptr = NSZoneRealloc(zone, ptr, grow + extra); \
      } \
    if (ptr == 0) \
      { \
	return NO;	/* Not enough memory */ \
      } \
    bsize = grow / sizeof(unichar); \
  }

/**
 * Function to convert from 8-bit character data to 16-bit unicode.
 * <p>The dst argument is a pointer to a pointer to a buffer in which the
 * converted string is to be stored.  If it is a nul pointer, this function
 * discards converted data, and is used only to determine the length of the
 * converted string.  If the zone argument is non-nul, the function is free
 * to allocate a larger buffer if necessary, and store this new buffer in
 * the dst argument.  It will *NOT* deallocate the original buffer!
 * </p>
 * <p>The size argument is a pointer to the initial size of the destination
 * buffer.  If the function changes the buffer size, this value will be
 * altered to the new size.  This is measured in characters, not bytes.
 * </p>
 * <p>The src argument is a pointer to the 8-bit character string which is
 * to be converted to 16-bit unicode.
 * </p>
 * <p>The slen argument is the length (bytes) of the 8-bit character string
 * which is to be converted to 16-bit unicode.
 * This is measured in characters, not bytes.
 * </p>
 * <p>The end argument specifies the encoding type of the 8-bit character
 * string which is to be converted to 16-bit unicode.
 * </p>
 * <p>The zone argument specifies a memory zone in which the function may
 * allocate a buffer to return data in.
 * If this is nul, the function will fail if the originally supplied buffer
 * is not big enough (unless dst is a nul pointer ... indicating that
 * converted data is to be discarded).
 * </p>
 * The options argument controls some special behavior.
 * <list>
 * <item>If GSUniTerminate is set, the function is expected to nul terminate
 * the output string, and will assume that it is safe to place the nul
 * just beyond the ned of the stated buffer size.
 * Also, if the function grows the buffer, it will allow for an extra
 * termination character.</item>
 * <item>If GSUniTemporary is set, the function will return the results in
 * an autoreleased buffer rather than in a buffer that the caller must
 * release.</item>
 * </list>
 * <p>On return, the function result is a flag indicating success (YES)
 * or failure (NO), and on success, the value stored in size is the number
 * of characters in the converted string.  The converted string itsself is
 * stored in the location gioven by dst.<br />
 * NB. If the value stored in dst has been changed, it is a pointer to
 * allocated memory which the caller is responsible for freeing, and the
 * caller is <em>still</em> responsible for freeing the original buffer.
 * </p>
 */
BOOL
GSToUnicode(unichar **dst, unsigned int *size, const unsigned char *src,
  unsigned int slen, NSStringEncoding enc, NSZone *zone,
  unsigned int options)
{
  unichar	buf[BUFSIZ];
  unichar	*ptr;
  unsigned	bsize;
  unsigned	dpos = 0;	// Offset into destination buffer.
  unsigned	spos = 0;	// Offset into source buffer.
  unsigned	extra = (options & GSUniTerminate) ? sizeof(unichar) : 0;
  unichar	base = 0;
  unichar	*table = 0;

  if (slen == 0)
    {
      return YES;
    }

  /*
   * Ensure we have an initial buffer set up to decode data into.
   */
  if (dst == 0 || *size == 0)
    {
      ptr = buf;
      bsize = (extra != 0) ? BUFSIZ - 1 : BUFSIZ;
    }
  else
    {
      ptr = *dst;
      bsize = *size;
    }

  switch (enc)
    {
      case NSNonLossyASCIIStringEncoding:
      case NSASCIIStringEncoding:
      case NSISOLatin1StringEncoding:
      case NSUnicodeStringEncoding: 	  
	while (spos < slen)
	  {
	    if (dpos >= bsize)
	      {
		GROW();
	      }
	    ptr[dpos++] = (unichar)((unc)src[spos++]);
	  }
	break;

      case NSNEXTSTEPStringEncoding:
	base = Next_conv_base;
	table = Next_char_to_uni_table;
	goto tables;

      case NSISOCyrillicStringEncoding:
	base = Cyrillic_conv_base;
	table = Cyrillic_char_to_uni_table;
	goto tables;

      case NSISOLatin2StringEncoding:
	base = Latin2_conv_base;
	table = Latin2_char_to_uni_table;
	goto tables;
	    
#if 0
      case NSSymbolStringEncoding:
	base = Symbol_conv_base;
	table = Symbol_char_to_uni_table;
	goto tables;    
#endif

tables:
	while (spos < slen)
	  {
	    unc c = (unc)src[spos];

	    if (dpos >= bsize)
	      {
		GROW();
	      }
	    if (c < base)
	      {
		ptr[dpos++] = c;
	      }
	    else
	      {
		ptr[dpos++] = table[c - base];
	      }
	    spos++;
	  }
	break;

      case NSGSM0338StringEncoding:
	while (spos < slen)
	  {
	    unc c = (unc)src[spos];

	    if (dpos >= bsize)
	      {
		GROW();
	      }

	    ptr[dpos] = GSM0338_char_to_uni_table[c];
	    if (c == 0x1b && spos < slen)
	      {
		unsigned	i = 0;

		c = (unc)src[spos+1];
		while (i < sizeof(GSM0338_escapes)/sizeof(GSM0338_escapes[0]))
		  {
		    if (GSM0338_escapes[i].to == c)
		      {
			ptr[dpos] = GSM0338_escapes[i].from;
			spos++;
			break;
		      }
		  }
	      }
	    dpos++;
	    spos++;
	  }
	break;

      default:
#ifdef HAVE_ICONV
	{
	  iconv_t	cd;
	  char		*inbuf;
	  char		*outbuf;
	  size_t	inbytesleft;
	  size_t	outbytesleft;
	  size_t	result;

	  cd = iconv_open(UNICODE_ENC, iconv_stringforencoding(enc));
	  if (cd == (iconv_t)-1)
	    {
	      NSLog(@"No iconv for encoding %@ tried to use %s", 
		GetEncodingName(enc), iconv_stringforencoding(enc));
	      return NO;
	    }

	  inbuf = (char*)src;
	  inbytesleft = slen;
	  outbuf = (char*)ptr;
	  outbytesleft = bsize * sizeof(unichar);
	  while (inbytesleft > 0)
	    {
	      if (dpos >= bsize)
		{
		  unsigned	old = bsize;

		  GROW();
		  outbuf = (char*)&ptr[dpos];
		  outbytesleft = (bsize - old) * sizeof(unichar);
		}
	      result = iconv(cd, &inbuf, &inbytesleft, &outbuf, &outbytesleft);
	      if (result == (size_t)-1 && errno != E2BIG)
		{
		  return NO;
		}
	      dpos = (bsize * sizeof(unichar) - outbytesleft) / sizeof(unichar);
	    }
	  // close the converter
	  iconv_close(cd);
	}
#else 
	return NO;
#endif 
    }

  /*
   * Post conversion ... set output values.
   */
  if (extra != 0)
    {
      ptr[dpos] = (unichar)0;
    }
  *size = dpos;
  if (dst != 0)
    {
      if (options & GSUniTemporary)
	{
	  unsigned	bytes = dpos * sizeof(unichar) + extra;
	  void		*r;

	  /*
	   * Temporary string was requested ... make one.
	   */
	  r = _fastMallocBuffer(bytes);
	  memcpy(r, ptr, bytes);
	  if (ptr != buf && ptr != *dst)
	    {
	      NSZoneFree(zone, ptr);
	    }
	  ptr = r;
	}
      else if (zone != 0 && bsize > dpos)
	{
	  unsigned	bytes = dpos * sizeof(unichar) + extra;

	  /*
	   * Resizing is permitted, try ensure we return a buffer which
	   * is just big enough to hold the converted string.
	   */
	  if (ptr == buf || ptr == *dst)
	    {
	      unichar	*tmp;

	      tmp = NSZoneMalloc(zone, bytes);
	      if (tmp != 0)
		{
		  memcpy(tmp, ptr, bytes);
		}
	      ptr = tmp;
	    }
	  else
	    {
	      ptr = NSZoneRealloc(zone, ptr, bytes);
	    }
	  if (ptr == 0)
	    {
	      return NO;
	    }
	}
      *dst = ptr;
    }
  return YES;
}

#undef	GROW


#define	GROW() \
if (dst == 0) \
  { \
    /* \
     * Data is just being discarded anyway, so we can \
     * adjust the offset into the local buffer on the \
     * stack and pretend the buffer has grown. \
     */ \
    ptr -= BUFSIZ; \
    bsize += BUFSIZ; \
  } \
else if (zone == 0) \
  { \
    return NO; /* No buffer growth possible ... fail. */ \
  } \
else \
  { \
    unsigned	grow = slen; \
\
    if (grow < bsize + BUFSIZ) \
      { \
	grow = bsize + BUFSIZ; \
      } \
\
    if (ptr == buf || ptr == *dst) \
      { \
	unsigned char	*tmp; \
\
	tmp = NSZoneMalloc(zone, grow + extra); \
	if (tmp != 0) \
	  { \
	    memcpy(tmp, ptr, bsize); \
	  } \
	ptr = tmp; \
      } \
    else \
      { \
	ptr = NSZoneRealloc(zone, ptr, grow + extra); \
      } \
    if (ptr == 0) \
      { \
	return NO;	/* Not enough memory */ \
      } \
    bsize = grow; \
  }

/**
 * Function to convert from 16-bit unicode to 8-bit character data.
 * <p>The dst argument is a pointer to a pointer to a buffer in which the
 * converted string is to be stored.  If it is a nul pointer, this function
 * discards converted data, and is used only to determine the length of the
 * converted string.  If the zone argument is non-nul, the function is free
 * to allocate a larger buffer if necessary, and store this new buffer in
 * the dst argument.  It will *NOT* deallocate the original buffer!
 * </p>
 * <p>The size argument is a pointer to the initial size of the destination
 * buffer.  If the function changes the buffer size, this value will be
 * altered to the new size.  This is measured in characters, not bytes.
 * </p>
 * <p>The src argument is a pointer to the 16-bit unicode string which is
 * to be converted to 8-bit data.
 * </p>
 * <p>The slen argument is the length (bytes) of the 16-bit unicode string
 * which is to be converted to 8-bit data.
 * This is measured in characters, not bytes.
 * </p>
 * <p>The end argument specifies the encoding type of the 8-bit character
 * string which is to be produced from the 16-bit unicode.
 * </p>
 * <p>The zone argument specifies a memory zone in which the function may
 * allocate a buffer to return data in.
 * If this is nul, the function will fail if the originally supplied buffer
 * is not big enough (unless dst is a nul pointer ... indicating that
 * converted data is to be discarded).
 * </p>
 * The options argument controls some special behavior.
 * <list>
 * <item>If GSUniStrict is set, the function will fail if a character is
 * encountered which can't be displayed in the source.  Otherwise, some
 * approximation or marker will be placed in the destination.</item>
 * </list>
 * <item>If GSUniTerminate is set, the function is expected to nul terminate
 * the output string, and will assume that it is safe to place the nul
 * just beyond the ned of the stated buffer size.
 * Also, if the function grows the buffer, it will allow for an extra
 * termination character.</item>
 * <item>If GSUniTemporary is set, the function will return the results in
 * an autoreleased buffer rather than in a buffer that the caller must
 * release.</item>
 * </list>
 * <p>On return, the function result is a flag indicating success (YES)
 * or failure (NO), and on success, the value stored in size is the number
 * of characters in the converted string.  The converted string itsself is
 * stored in the location gioven by dst.<br />
 * NB. If the value stored in dst has been changed, it is a pointer to
 * allocated memory which the caller is responsible for freeing, and the
 * caller is <em>still</em> responsible for freeing the original buffer.
 * </p>
 */
BOOL
GSFromUnicode(unsigned char **dst, unsigned int *size, const unichar *src,
  unsigned int slen, NSStringEncoding enc, NSZone *zone,
  unsigned int options)
{
  unsigned char	buf[BUFSIZ];
  unsigned char	*ptr;
  unsigned	bsize;
  unsigned	dpos = 0;	// Offset into destination buffer.
  unsigned	spos = 0;	// Offset into source buffer.
  unsigned	extra = (options & GSUniTerminate) ? 1 : 0;
  BOOL		strict = (options & GSUniStrict) ? YES : NO;
  unichar	base = 0;
  _ucc_		*table = 0;
  unsigned	tsize = 0;
  
  if (slen == 0)
    {
      return YES;
    }
    
  /*
   * Ensure we have an initial buffer set up to decode data into.
   */
  if (dst == 0 || *size == 0)
    {
      ptr = buf;
      bsize = (extra != 0) ? BUFSIZ - 1 : BUFSIZ;
    }
  else
    {
      ptr = *dst;
      bsize = *size;
    }

  switch (enc)
    {
      case NSNonLossyASCIIStringEncoding:
      case NSASCIIStringEncoding:
	base = 128;
	goto bases;
      case NSISOLatin1StringEncoding:
      case NSUnicodeStringEncoding: 	  
	base = 256;
	goto bases;

bases:
	if (strict == YES)
	  {
	    while (spos < slen)
	      {
		unichar	u = src[spos++];

		if (dpos >= bsize)
		  {
		    GROW();
		  }
		if (u < 128)
		  {
		    ptr[dpos++] = (char)u;
		  }
		else
		  {
		    ptr[dpos++] =  '*';
		  }
	      }
	  }
	else
	  {
	    while (spos < slen)
	      {
		unichar	u = src[spos++];

		if (dpos >= bsize)
		  {
		    GROW();
		  }
		if (u < 128)
		  {
		    ptr[dpos++] = (char)u;
		  }
		else
		  {
		    return NO;
		  }
	      }
	  }
	break;

      case NSNEXTSTEPStringEncoding:
	base = (unichar)Next_conv_base;
	table = Next_uni_to_char_table;
	tsize = Next_uni_to_char_table_size;
	goto tables;

      case NSISOCyrillicStringEncoding:
	base = (unichar)Cyrillic_conv_base;
	table = Cyrillic_uni_to_char_table;
	tsize = Cyrillic_uni_to_char_table_size;
	goto tables;

      case NSISOLatin2StringEncoding:
	base = (unichar)Latin2_conv_base;
	table = Latin2_uni_to_char_table;
	tsize = Latin2_uni_to_char_table_size;
	goto tables;

#if 0
      case NSSymbolStringEncoding:
	base = (unichar)Symbol_conv_base;
	table = Symbol_uni_to_char_table;
	tsize = Symbol_uni_to_char_table_size;
	goto tables;
#endif

tables:
	if (strict == YES)
	  {
	    while (spos < slen)
	      {
		unichar	u = src[spos++];

		if (dpos >= bsize)
		  {
		    GROW();
		  }
		if (u < base)
		  {
		    ptr[dpos++] = (char)u;
		  }
		else
		  {
		    int res;
		    int i = 0;

		    while ((res = u - table[i].from) > 0)
		      {
			if (++i >= tsize)
			  {
			    break;
			  }
		      }
		    if (res > 0)
		      {
			ptr[dpos++] = '*';
		      }
		    else
		      {
			ptr[dpos++] = table[--i].to;
		      }
		  }
	      }
	  }
	else
	  {
	    while (spos < slen)
	      {
		unichar	u = src[spos++];

		if (dpos >= bsize)
		  {
		    GROW();
		  }
		if (u < base)
		  {
		    ptr[dpos++] = (char)u;
		  }
		else
		  {
		    int res;
		    int i = 0;

		    while ((res = u - table[i].from) > 0)
		      {
			if (++i >= tsize)
			  {
			    return NO;
			  }
		      }
		    ptr[dpos++] = table[--i].to;
		  }
	      }
	  }
	break;

      case NSGSM0338StringEncoding:
	while (spos < slen)
	  {
	    unichar	u = src[spos++];
	    int	res;
	    int	i = 0;

	    if (dpos >= bsize)
	      {
		GROW();
	      }

	    while ((res = u - GSM0338_uni_to_char_table[i].from) > 0)
	      {
		if (++i >= GSM0338_tsize)
		  {
		    break;
		  }
	      }
	    if (res == 0)
	      {
		ptr[dpos] = GSM0338_uni_to_char_table[--i].to;
	      }
	    else
	      {
		if (strict == YES)
		  {
		    return NO;
		  }
		for (i = 0; i < GSM0338_esize; i++)
		  {
		    if (GSM0338_escapes[i].from == u)
		      {
			ptr[dpos++] = 0x1b;
			if (dpos >= bsize)
			  {
			    GROW();
			  }
			ptr[dpos] = GSM0338_escapes[i].to;
			break;
		      }
		  }
		if (i == GSM0338_esize)
		  {
		    ptr[dpos] = '*';
		  }
	      }
	    dpos++;
	  }
	break;

      default:
#ifdef HAVE_ICONV
	{
	  iconv_t	cd;
	  char		*inbuf;
	  char		*outbuf;
	  size_t	inbytesleft;
	  size_t	outbytesleft;
	  size_t	result;

	  cd = iconv_open(iconv_stringforencoding(enc), UNICODE_ENC);
	  if (cd == (iconv_t)-1)
	    {
	      NSLog(@"No iconv for encoding %@ tried to use %s", 
		GetEncodingName(enc), iconv_stringforencoding(enc));
	      return NO;
	    }

	  inbuf = (char*)src;
	  inbytesleft = slen * sizeof(unichar);
	  outbuf = (char*)ptr;
	  outbytesleft = bsize;
	  while (inbytesleft > 0)
	    {
	      if (dpos >= bsize)
		{
		  unsigned	old = bsize;

		  GROW();
		  outbuf = (char*)&ptr[dpos];
		  outbytesleft = (bsize - old);
		}
	      result = iconv(cd, &inbuf, &inbytesleft, &outbuf, &outbytesleft);
	      if (result == (size_t)-1 && errno != E2BIG)
		{
		  if (errno == EILSEQ)
		    {
		      if (strict == YES)
			{
			  return NO;
			}
		      /*
		       * If we are allowing lossy conversion, we replace any
		       * unconvertable character with an asterisk.
		       */
		      if (outbytesleft > 0)
			{
			  *outbuf++ = '*';
			  outbytesleft--;
			  inbuf++;
			  inbytesleft--;
			}
		    }
		  else if (errno != E2BIG)
		    {
		      return NO;
		    }
		}
	      dpos = bsize - outbytesleft;
	    }
	  // close the converter
	  iconv_close(cd);
	}
#else 
	return NO;
#endif 
    }

  /*
   * Post conversion ... set output values.
   */
  if (extra != 0)
    {
      ptr[dpos] = (unsigned char)0;
    }
  *size = dpos;
  if (dst != 0)
    {
      if (options & GSUniTemporary)
	{
	  unsigned	bytes = dpos + extra;
	  void		*r;

	  /*
	   * Temporary string was requested ... make one.
	   */
	  r = _fastMallocBuffer(bytes);
	  memcpy(r, ptr, bytes);
	  if (ptr != buf && ptr != *dst)
	    {
	      NSZoneFree(zone, ptr);
	    }
	  ptr = r;
	}
      else if (zone != 0 && bsize > dpos)
	{
	  unsigned	bytes = dpos + extra;

	  /*
	   * Resizing is permitted - try ensure we return a buffer
	   * which is just big enough to hold the converted string.
	   */
	  if (ptr == buf || ptr == *dst)
	    {
	      unsigned char	*tmp;

	      tmp = NSZoneMalloc(zone, bytes);
	      if (tmp != 0)
		{
		  memcpy(tmp, ptr, bytes);
		}
	      ptr = tmp;
	    }
	  else
	    {
	      ptr = NSZoneRealloc(zone, ptr, bytes);
	    }
	  if (ptr == 0)
	    {
	      return NO;
	    }
	}
      *dst = ptr;
    }
  return YES;
}

#undef	GROW

