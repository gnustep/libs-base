/* Support functions for Unicode implementation
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

struct _ucc_ {unichar from; char to;};

#include "unicode/cyrillic.h"
#include "unicode/latin2.h"
#include "unicode/nextstep.h"
#include "unicode/caseconv.h"
#include "unicode/cop.h"
#include "unicode/decomp.h"

#ifdef HAVE_ICONV
#include <iconv.h>
#include <errno.h>

// The rest of the GNUstep code stores UNICODE in internal byte order,
// so we do the same. This should be UCS-2-INTERNAL for libiconv
#ifdef WORDS_BIGENDIAN
#define UNICODE_ENC "UNICODEBIG"
#else
#define UNICODE_ENC "UNICODELITTLE"
#endif

#endif 


typedef	unsigned char	unc;
static NSStringEncoding	defEnc = GSUndefinedEncoding;

#ifdef HAVE_ICONV
// FIXME: We should check dynamically which encodings are found on this computer,
// as different implementation of iconv will support different encodings. 
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
  char			*encoding;
  unsigned int		count;
  NSStringEncoding	ret;
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
	  ret = str_encoding_table[count].enc;
	  if ((ret == NSUnicodeStringEncoding)
	    || (ret == NSSymbolStringEncoding))
	    {
	      fprintf(stderr, "WARNING: %s - encoding not supported as "
		"default c string encoding.\n", encoding);
	      fprintf(stderr, "NSISOLatin1StringEncoding set as default.\n");
	      ret = NSISOLatin1StringEncoding;
	    }
	  else /*encoding should be supported but is it implemented?*/
	    {
	      count = 0;
	      tmp = 0;
	      while (availableEncodings[count] != 0)
		{
		  if (ret != availableEncodings[count])
		    {
		      tmp = 0;
		    }
		  else
		    {
		      tmp = ret;
		      break;
		    }
		  count++;
		}
	      if (tmp == 0 && ret != NSISOLatin1StringEncoding)
		{
		  fprintf(stderr, "WARNING: %s - encoding not yet "
		    "implemented.\n", encoding);
		  fprintf(stderr,
		    "NSISOLatin1StringEncoding set as default.\n");
		  ret = NSISOLatin1StringEncoding;
		}
	    }
	}
      else /* encoding not found */
	{
	  fprintf(stderr, "WARNING: %s - encoding not supported.\n", encoding);
	  fprintf(stderr, "NSISOLatin1StringEncoding set as default.\n");
	  ret = NSISOLatin1StringEncoding;
	}
    }
  else /* environment var not found */
    {
      /* shouldn't be required. It really should be in UserDefaults - asf */
      //fprintf(stderr,"WARNING: GNUSTEP_STRING_ENCODING environment found\n");
      //fprintf(stderr, "NSISOLatin1StringEncoding set as default.\n");
      ret = NSISOLatin1StringEncoding;
    }

  // Cache the encoding
  defEnc = ret;
  return ret;
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

static char *
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
      case NSGB2312StringEncoding:
	return "EUC-CN";
      default:
	return "";
    }
}

int
iconv_strtoustr(unichar *u2, int size2, const char *s1, int size1, NSStringEncoding enc)
{
  iconv_t conv;
  int usize = sizeof(unichar)*size2;
  char *u1 = (char*)u2;
  int ret_val;

  conv = iconv_open(UNICODE_ENC, iconv_stringforencoding(enc));
  if (conv == (iconv_t)-1)
    {
      return 0;
    }

  ret_val = iconv(conv, &s1, &size1, &u1, &usize);
  // close the converter
  iconv_close(conv);
  if (ret_val == -1)
    {
      return 0;
    }

  return u1 - (char*)u2;
}

int
iconv_ustrtostr(char *s2, int size2, unichar *u1, int size1,
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
      return 0;
    }

  ret_val = iconv(conv, &u2, &usize, &s2, &size2);
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
	
	if (iconv_strtoustr(&u, 1, &c, 1, enc) > 0)
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
	int r = iconv_ustrtostr(c, 4, &u, 1, enc);

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
	int r = iconv_ustrtostr(c, 4, &u, 1, enc);

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
      defEnc = [NSString defaultCStringEncoding];
    }
  return encode_chartouni(c, defEnc);
}

char
unitochar(unichar u)
{
  if (defEnc == GSUndefinedEncoding)
    {
      defEnc = [NSString defaultCStringEncoding];
    }
  return encode_unitochar(u, defEnc);
}

int
strtoustr(unichar *u1, const char *s1, int size)
{
  if (defEnc == GSUndefinedEncoding)
    {
      defEnc = [NSString defaultCStringEncoding];
    }

  return encode_strtoustr(u1, s1, size, defEnc);
}
 
int
ustrtostr(char *s2, unichar *u1, int size)
{
  if (defEnc == GSUndefinedEncoding)
    {
      defEnc = [NSString defaultCStringEncoding];
    }

  return encode_ustrtostr(s2, u1, size, defEnc);
}
 
int
encode_strtoustr(unichar *u1, const char *s1, int size, NSStringEncoding enc)
{
  int count;

  switch (enc)
    {
      case NSNonLossyASCIIStringEncoding:
      case NSASCIIStringEncoding:
      case NSISOLatin1StringEncoding:
      case NSUnicodeStringEncoding: 	  
	for (count = 0; (count < size) && (s1[count] != 0); count++)
	  {
	    u1[count] = (unichar)((unc)s1[count]);
	  }
	return count;

      case NSNEXTSTEPStringEncoding:
	for (count = 0; (count < size) && (s1[count] != 0); count++)
	  {
	    unc c = (unc)s1[count];

	    if (c < Next_conv_base)
	      u1[count] = (unichar)c;
	    else
	      u1[count] = Next_char_to_uni_table[c - Next_conv_base];
	  }
	return count;

      case NSISOCyrillicStringEncoding:
	for (count = 0; (count < size) && (s1[count] != 0); count++)
	  {
	    unc c = (unc)s1[count];

	    if (c < Cyrillic_conv_base)
	      u1[count] = (unichar)c;
	    else
	      u1[count] = Cyrillic_char_to_uni_table[c - Cyrillic_conv_base];
	  }
	return count;

      case NSISOLatin2StringEncoding:
	for (count = 0; (count < size) && (s1[count] != 0); count++)
	  {
	    unc c = (unc)s1[count];

	    if (c < Latin2_conv_base)
	      u1[count] = (unichar)c;
	    else
	      u1[count] = Latin2_char_to_uni_table[c - Latin2_conv_base];
	  }
	return count;
	    
#if 0
      case NSSymbolStringEncoding:
	for (count = 0; (count < size) && (s1[count] != 0); count++)
	  {
	    unc c = (unc)s1[count];

	    if (c < Symbol_conv_base)
		u1[count] = (unichar)c;
	    else
		u1[count] = Symbol_char_to_uni_table[c - Symbol_conv_base];
	  }
	return count;    
#endif

      default:
#ifdef HAVE_ICONV
	return iconv_strtoustr(u1, size, s1, size, enc);
#else 
	return 0;
#endif 
    }
/*
  for (count = 0; (count < size) && (s1[count] != 0); count++)
    {
      u1[count] = encode_chartouni(s1[count], enc);
    }
  return count;
*/
}

int
encode_ustrtostr(char *s2, unichar *u1, int size, NSStringEncoding enc)
{
  int count;
  unichar u;

  switch (enc)
    {
      case NSNonLossyASCIIStringEncoding:
        for (count = 0; (count < size) && (u1[count] != (unichar)0); count++)
	  {
	    u = u1[count];
	    if (u < 128)
	      s2[count] = (char)u;
	    else
	      s2[count] =  '*';
	  }
	return count;

      case NSASCIIStringEncoding:
        for (count = 0; (count < size) && (u1[count] != (unichar)0); count++)
	  {
	    u = u1[count];
	    if (u < 128)
	      s2[count] = (char)u;
	    else
	      s2[count] =  '*';
	  }
	return count;

      case NSISOLatin1StringEncoding:
      case NSUnicodeStringEncoding: 	  
        for (count = 0; (count < size) && (u1[count] != (unichar)0); count++)
	  {
	    u = u1[count];
	    if (u < 256)
	      s2[count] = (char)u;
	    else
	      s2[count] = '*';
	  }
	return count;

      case NSNEXTSTEPStringEncoding:
        for (count = 0; (count < size) && (u1[count] != (unichar)0); count++)
	  {
	    u = u1[count];
	    if (u < (unichar)Next_conv_base)
	      s2[count] = (char)u;
	    else
	      {
		int res;
		int i = 0;

		while (((res = u - Next_uni_to_char_table[i++].from) > 0)
		       && (i < Next_uni_to_char_table_size));
		s2[count] = res ? '*' : Next_uni_to_char_table[--i].to;
	      }
	  }
	return count;

      case NSISOCyrillicStringEncoding:
        for (count = 0; (count < size) && (u1[count] != (unichar)0); count++)
	  {
	    u = u1[count];
	    if (u < (unichar)Cyrillic_conv_base)
	      s2[count] = (char)u;
	    else
	      {
		int res;
		int i = 0;

		while (((res = u - Cyrillic_uni_to_char_table[i++].from) > 0)
		       && (i < Cyrillic_uni_to_char_table_size));
		s2[count] = res ? '*' : Cyrillic_uni_to_char_table[--i].to;
	      }
	  }
	return count;

      case NSISOLatin2StringEncoding:
        for (count = 0; (count < size) && (u1[count] != (unichar)0); count++)
	  {
	    u = u1[count];
	    if (u < (unichar)Latin2_conv_base)
	      s2[count] = (char)u;
	    else
	      {
		int res;
		int i = 0;

		while (((res = u - Latin2_uni_to_char_table[i++].from) > 0)
		       && (i < Latin2_uni_to_char_table_size));
		s2[count] = res ? '*' : Latin2_uni_to_char_table[--i].to;
	      }
	  }
	return count;

#if 0
      case NSSymbolStringEncoding:
        for (count = 0; (count < size) && (u1[count] != (unichar)0); count++)
	  {
	    u = u1[count];
	    if (u < (unichar)Symbol_conv_base)
	      s2[count] = (char)u;
	    else
	      {
		int res;
		int i = 0;

		while (((res = u - Symbol_uni_to_char_table[i++].from) > 0)
		       && (i < Symbol_uni_to_char_table_size));
		s2[count] = res ? '*' : Symbol_uni_to_char_table[--i].to;
	      }
	  }
	return count;
#endif

      default:
#ifdef HAVE_ICONV
	// FIXME: The non-strict encoding is still missing
	return iconv_ustrtostr(s2, size, u1, size, enc);
#else
	return 0;
#endif 
    }
}

int
encode_ustrtostr_strict(char *s2, unichar *u1, int size, NSStringEncoding enc)
{
  int count;
  unichar u;

  switch (enc)
    {
      case NSNonLossyASCIIStringEncoding:
        for (count = 0; count < size; count++)
	  {
	    u = u1[count];
	    if (u < 128)
	      s2[count] = (char)u;
	    else
	      return 0;
	  }
	return count;

      case NSASCIIStringEncoding:
        for (count = 0; count < size; count++)
	  {
	    u = u1[count];
	    if (u < 128)
	      s2[count] = (char)u;
	    else
	      return 0;
	  }
	return count;

      case NSISOLatin1StringEncoding:
      case NSUnicodeStringEncoding: 	  
        for (count = 0; count < size; count++)
	  {
	    u = u1[count];
	    if (u < 256)
	      s2[count] = (char)u;
	    else
	      return 0;
	  }
	return count;

      case NSNEXTSTEPStringEncoding:
        for (count = 0; count < size; count++)
	  {
	    u = u1[count];
	    if (u < (unichar)Next_conv_base)
	      s2[count] = (char)u;
	    else
	      {
		int res;
		int i = 0;

		while (((res = u - Next_uni_to_char_table[i++].from) > 0)
		  && (i < Next_uni_to_char_table_size));
		if (!res)
		  s2[count] = Next_uni_to_char_table[--i].to;
		else
		  return 0;
	      }
	  }
	return count;

      case NSISOCyrillicStringEncoding:
        for (count = 0; count < size; count++)
	  {
	    u = u1[count];
	    if (u < (unichar)Cyrillic_conv_base)
	      s2[count] = (char)u;
	    else
	      {
		int res;
		int i = 0;

		while (((res = u - Cyrillic_uni_to_char_table[i++].from) > 0)
		  && (i < Cyrillic_uni_to_char_table_size));
		if (!res)
		  s2[count] = Cyrillic_uni_to_char_table[--i].to;
		else
		  return 0;
	      }
	  }
	return count;

      case NSISOLatin2StringEncoding:
        for (count = 0; count < size; count++)
	  {
	    u = u1[count];
	    if (u < (unichar)Latin2_conv_base)
	      s2[count] = (char)u;
	    else
	      {
		int res;
		int i = 0;

		while (((res = u - Latin2_uni_to_char_table[i++].from) > 0)
		  && (i < Latin2_uni_to_char_table_size));
		if (!res)
		  s2[count] = Latin2_uni_to_char_table[--i].to;
		else
		  return 0;
	      }
	  }
	return count;

#if 0
      case NSSymbolStringEncoding:
        for (count = 0; count < size; count++)
	  {
	    u = u1[count];
	    if (u < (unichar)Symbol_conv_base)
	      s2[count] = (char)u;
	    else
	      {
		int res;
		int i = 0;

		while (((res = u - Symbol_uni_to_char_table[i++].from) > 0)
		  && (i < Symbol_uni_to_char_table_size));
		if (!res)
		  s2[count] = Symbol_uni_to_char_table[--i].to;
		else
		  return 0;
	      }
	  }
	return count;
#endif

      default:
#ifdef HAVE_ICONV
	return iconv_ustrtostr(s2, size, u1, size, enc);
#else
	return 0;
#endif 
    }
}

// These two functions use direct access into a two-level table to map cases.
// The two-level table method is less space efficient (but still not bad) than
// a single table and a linear search, but it reduces the number of
// conditional statements to just one.
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

