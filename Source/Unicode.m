/** Support functions for Unicode implementation
   Function to determine default c string encoding for
   GNUstep based on GNUSTEP_STRING_ENCODING environment variable.

   Copyright (C) 1997 Free Software Foundation, Inc.

   Written by: Stevo Crvenkovski < stevo@btinternet.com >
   Date: March 1997
   Merged with GetDefEncoding.m and iconv by: Fred Kiefer <fredkiefer@gmx.de>
   Date: September 2000
   Rewrite by: Richard Frith-Macdonald <rfm@gnu.org>

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
#include <Foundation/NSArray.h>
#include <Foundation/NSBundle.h>
#include <Foundation/NSDictionary.h>
#include <Foundation/NSString.h>
#include <Foundation/NSLock.h>
#include <Foundation/NSPathUtilities.h>
#include <base/Unicode.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

typedef struct {unichar from; unsigned char to;} _ucc_;

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

/*
 * The whole of the GNUstep code stores UNICODE in internal byte order,
 * so we do the same. This should be UCS-2-INTERNAL for libiconv
 */
#ifdef WORDS_BIGENDIAN
#define UNICODE_INT "UNICODEBIG"
#else
#define UNICODE_INT "UNICODELITTLE"
#endif

#define UNICODE_ENC ((unicode_enc) ? unicode_enc : internal_unicode_enc())

static const char *unicode_enc = NULL;

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

#endif 

typedef	unsigned char	unc;
static NSStringEncoding	defEnc = GSUndefinedEncoding;
static NSStringEncoding *_availableEncodings = 0;

struct _strenc_ {
  NSStringEncoding	enc;		// Constant representing the encoding.
  const char		*ename;		// ASCII string representation of name.
  const char		*iconv;		/* Iconv name of encoding.  If this
					 * is the empty string, we cannot use
					 * iconv perform conversions to/from
					 * this encoding.
					 * NB. do not put a null pointer in this
					 * field in the table, use "" instread.
					 */
  BOOL			eightBit;	/* Flag to say whether this encoding
					 * can be stored in a byte array ...
					 * ie whether the encoding consists
					 * entirely of single byte charcters
					 * and the first 128 are identical to
					 * the ASCII character set.
					 */
  char			supported;	/* Is this supported?  Some encodings
					 * have builtin conversion to/from
					 * unicode, but for others we must
					 * check with iconv to see if it
					 * supports them on this platform.
					 * A one means supported.
					 * A negative means unsupported.
					 * A zero means not yet checked.
					 */
};

/*
 * The str_encoding_table is a compact representation of all the string
 * encoding information we might need.  It gets modified at runtime.
 */
static struct _strenc_ str_encoding_table[] = {
  {NSASCIIStringEncoding,"NSASCIIStringEncoding","ASCII",1,1},
  {NSNEXTSTEPStringEncoding,"NSNEXTSTEPStringEncoding","NEXTSTEP",1,1},
  {NSJapaneseEUCStringEncoding, "NSJapaneseEUCStringEncoding","EUC-JP",0,0},
  {NSUTF8StringEncoding,"NSUTF8StringEncoding","UTF-8",0,0},
  {NSISOLatin1StringEncoding,"NSISOLatin1StringEncoding","ISO-8859-1",1,1},
  {NSSymbolStringEncoding,"NSSymbolStringEncoding","",0,0},
  {NSNonLossyASCIIStringEncoding,"NSNonLossyASCIIStringEncoding","",1,1},
  {NSShiftJISStringEncoding,"NSShiftJISStringEncoding","SHIFT-JIS",0,0},
  {NSISOLatin2StringEncoding,"NSISOLatin2StringEncoding","ISO-8859-2",1,1},
  {NSUnicodeStringEncoding, "NSUnicodeStringEncoding","",0,1},
  {NSWindowsCP1251StringEncoding,"NSWindowsCP1251StringEncoding","CP1251",0,0},
  {NSWindowsCP1252StringEncoding,"NSWindowsCP1252StringEncoding","CP1252",0,0},
  {NSWindowsCP1253StringEncoding,"NSWindowsCP1253StringEncoding","CP1253",0,0},
  {NSWindowsCP1254StringEncoding,"NSWindowsCP1254StringEncoding","CP1254",0,0},
  {NSWindowsCP1250StringEncoding,"NSWindowsCP1250StringEncoding","CP1250",0,0},
  {NSISO2022JPStringEncoding,"NSISO2022JPStringEncoding","ISO-2022-JP",0,0},
  {NSMacOSRomanStringEncoding, "NSMacOSRomanStringEncoding","MACINTOSH",0,0},
  {NSProprietaryStringEncoding, "NSProprietaryStringEncoding","",0,0},

// GNUstep additions
  {NSISOCyrillicStringEncoding,"NSISOCyrillicStringEncoding","ISO-8859-5",0,1},
  {NSKOI8RStringEncoding, "NSKOI8RStringEncoding","KOI8-R",0,0},
  {NSISOLatin3StringEncoding, "NSISOLatin3StringEncoding","ISO-8859-3",0,0},
  {NSISOLatin4StringEncoding, "NSISOLatin4StringEncoding","ISO-8859-4",0,0},
  {NSISOArabicStringEncoding, "NSISOArabicStringEncoding","ISO-8859-6",0,0},
  {NSISOGreekStringEncoding, "NSISOGreekStringEncoding","ISO-8859-7",0,0},
  {NSISOHebrewStringEncoding, "NSISOHebrewStringEncoding","ISO-8859-8",0,0},
  {NSISOLatin5StringEncoding, "NSISOLatin5StringEncoding","ISO-8859-9",0,0},
  {NSISOLatin6StringEncoding, "NSISOLatin6StringEncoding","ISO-8859-10",0,0},
  {NSISOLatin7StringEncoding, "NSISOLatin7StringEncoding","ISO-8859-13",0,0},
  {NSISOLatin8StringEncoding, "NSISOLatin8StringEncoding","ISO-8859-14",0,0},
  {NSISOLatin9StringEncoding, "NSISOLatin9StringEncoding","ISO-8859-15",0,0},
  {NSUTF7StringEncoding, "NSUTF7StringEncoding","",0,0},
  {NSGB2312StringEncoding, "NSGB2312StringEncoding","EUC-CN",0,0},
  {NSGSM0338StringEncoding, "NSGSM0338StringEncoding","",0,1},
  {NSBIG5StringEncoding, "NSBIG5StringEncoding","BIG5",0,0},

  {0,"Unknown encoding","",0,0}
};

static struct _strenc_	**encodingTable = 0;
static unsigned		encTableSize = 0;

static void GSSetupEncodingTable()
{
  if (encodingTable == 0)
    {
      [gnustep_global_lock lock];
      if (encodingTable == 0)
	{
	  static struct _strenc_	**encTable = 0;
	  unsigned		count;
	  unsigned		i;

	  /*
	   * We want to store pointers to our string encoding info in a
	   * large table so we can do efficient lookup by encoding value.
	   */
#define	MAX_ENCODING	128
	  count = sizeof(str_encoding_table) / sizeof(struct _strenc_);

	  /*
	   * First determine the largest encoding value and create a
	   * large enough table of pointers.
	   */
	  encTableSize = 0;
	  for (i = 0; i < count; i++)
	    {
	      unsigned	tmp = str_encoding_table[i].enc;

	      if (tmp >= MAX_ENCODING)
		{
		  fprintf(stderr, "ERROR ... illegal NSStringEncoding "
		    "value in str_encoding_table. Ignored\n");
		} 
	      else if (tmp > encTableSize)
		{
		  encTableSize = tmp;
		}
	    }
	  encTable = malloc((encTableSize+1)*sizeof(struct _strenc_ *));
	  memset(encTable, 0, (encTableSize+1)*sizeof(struct _strenc_ *));

	  /*
	   * Now set up the pointers at the correct location in the table.
	   */
	  for (i = 0; i < count; i++)
	    {
	      unsigned	tmp = str_encoding_table[i].enc;

	      if (tmp < MAX_ENCODING)
		{
		  encTable[tmp] = &str_encoding_table[i];
		}
	    }
	  encodingTable = encTable;
	}
      [gnustep_global_lock unlock];
    }
}

static BOOL GSEncodingSupported(NSStringEncoding enc)
{
  GSSetupEncodingTable();

  if (enc == 0 || enc > encTableSize || encodingTable[enc] == 0)
    {
      return NO;
    }
#ifdef HAVE_ICONV
  if (encodingTable[enc]->iconv != 0 && encodingTable[enc]->supported == 0)
    {
      if (enc == NSUnicodeStringEncoding)
	{
	  encodingTable[enc]->iconv = UNICODE_ENC;
	  encodingTable[enc]->supported = 1;
	}
      else
	{
	  iconv_t	c;

	  c = iconv_open(UNICODE_ENC, encodingTable[enc]->iconv);
	  if (c == (iconv_t)-1)
	    {
	      encodingTable[enc]->supported = -1;
	    }
	  else
	    {
	      iconv_close(c);
	      c = iconv_open(encodingTable[enc]->iconv, UNICODE_ENC);
	      if (c == (iconv_t)-1)
		{
		  encodingTable[enc]->supported = -1;
		}
	      else
		{
		  iconv_close(c);
		  encodingTable[enc]->supported = 1;
		}
	    }
	}
    }
#endif
  if (encodingTable[enc]->supported == 1)
    {
      return YES;
    }
  return NO;
}

NSStringEncoding *GetAvailableEncodings()
{
  if (_availableEncodings == 0)
    {
      [gnustep_global_lock lock];
      if (_availableEncodings == 0)
	{
	  NSStringEncoding	*encodings;
	  unsigned		pos;
	  unsigned		i;

	  /*
	   * Now build up a list of supported encodings ... in the
	   * format needed to support [NSString+availableStringEncodings]
	   * Check to see what iconv support we have as we go along.
	   * This is also the place where we determine the name we use
	   * for iconv to support unicode.
	   */
	  GSSetupEncodingTable();
	  encodings = objc_malloc(sizeof(NSStringEncoding) * encTableSize);
	  pos = 0;
	  for (i = 0; i < encTableSize; i++)
	    {
	      if (GSEncodingSupported(i) == YES)
		{
		  encodings[pos++] = i;
		}
	    }
	  encodings[pos] = 0;
	  _availableEncodings = encodings;
	}
      [gnustep_global_lock unlock];
    }
  return _availableEncodings;
}

/** Returns the NSStringEncoding that matches the specified
 *  character set registry and encoding information. For instance,
 *  for the iso8859-5 character set, the registry is iso8859 and
 *  the encoding is 5, and the returned NSStringEncoding is
 *  NSISOCyrillicStringEncoding. If there is no specific encoding,
 *  use @"0". Returns GSUndefinedEncoding if there is no match.
 */
NSStringEncoding
GSEncodingForRegistry (NSString *registry, NSString *encoding)
{
  if ([registry isEqualToString: @"iso8859"])
    {
      if ([encoding isEqualToString: @"1"])
	return NSISOLatin1StringEncoding;
      else if ([encoding isEqualToString: @"2"])
	return NSISOLatin2StringEncoding;
      else if ([encoding isEqualToString: @"3"])
	return NSISOLatin3StringEncoding;
      else if ([encoding isEqualToString: @"4"])
	return NSISOLatin4StringEncoding;
      else if ([encoding isEqualToString: @"5"])
	return NSISOCyrillicStringEncoding;
      else if ([encoding isEqualToString: @"6"])
	return NSISOArabicStringEncoding;
      else if ([encoding isEqualToString: @"7"])
	return NSISOGreekStringEncoding;
      else if ([encoding isEqualToString: @"8"])
	return NSISOHebrewStringEncoding;
      // Other latin encodings are currently not supported
    }
  else if ([registry isEqualToString: @"iso10646"])
    {
      if ([encoding isEqualToString: @"1"])
	return NSUnicodeStringEncoding;
    }
  else if ([registry isEqualToString: @"microsoft"])
    {
      if ([encoding isEqualToString: @"symbol"])
	return NSSymbolStringEncoding;
      else if ([encoding isEqualToString: @"cp1250"])
	return NSWindowsCP1250StringEncoding;
      else if ([encoding isEqualToString: @"cp1251"])
	return NSWindowsCP1251StringEncoding;
      else if ([encoding isEqualToString: @"cp1252"])
	return NSWindowsCP1252StringEncoding;
      else if ([encoding isEqualToString: @"cp1253"])
	return NSWindowsCP1253StringEncoding;
      else if ([encoding isEqualToString: @"cp1254"])
	return NSWindowsCP1254StringEncoding;
    }
  else if ([registry isEqualToString: @"apple"])
    {
      if ([encoding isEqualToString: @"roman"])
	return NSMacOSRomanStringEncoding;
    }
  else if ([registry isEqualToString: @"jisx0201.1976"])
    {
      if ([encoding isEqualToString: @"0"])
	return NSShiftJISStringEncoding;
    }
  else if ([registry isEqualToString: @"iso646.1991"])
    {
      if ([encoding isEqualToString: @"irv"])
	return NSASCIIStringEncoding;
    }
  else if ([registry isEqualToString: @"koi8"])
    {
      if ([encoding isEqualToString: @"r"])
	return NSKOI8RStringEncoding;
    }
  else if ([registry isEqualToString: @"gb2312.1980"])
    {
      if ([encoding isEqualToString: @"0"])
	return NSGB2312StringEncoding;
    }
  else if ([registry isEqualToString: @"big5"])
    {
      if ([encoding isEqualToString: @"0"])
        return NSBIG5StringEncoding;
    }
  else if ([registry isEqualToString:@"utf8"]
	   || [registry isEqualToString:@"utf-8"] )
    {
      return NSUTF8StringEncoding;
    }

  return GSUndefinedEncoding;
}

/** Try to deduce the string encoding from the locale string
 *  clocale. This function looks in the Locale.encodings file
 *  installed as part of GNUstep Base if the encoding cannot be
 *  deduced from the clocale string itself. If  clocale isn't set or
 *  no match can be found, returns GSUndefinedEncoding.
 */
/* It would be really nice if this could be used in GetDefEncoding, but
 * there are too many dependancies on other parts of the library to
 * make this practical (even if everything possible was written in C,
 * we'd still need some way to find the Locale.encodings file).
 */
NSStringEncoding
GSEncodingFromLocale(const char *clocale)
{
  NSStringEncoding encoding;
  NSString *encodstr;

  if (clocale == NULL || strcmp(clocale, "C") == 0 
      || strcmp(clocale, "POSIX") == 0) 
    {
      /* Don't make any assumptions. Let caller handle that */
      return GSUndefinedEncoding;
    }

  if (strchr (clocale, '.') != NULL)
    {
      /* Locale contains the 'codeset' section. Parse it and see
	 if we know what encoding this cooresponds to */
      NSString *registry;
      NSArray *array;
      char *s;
      s = strchr (clocale, '.');
      registry = [[NSString stringWithCString: s+1] lowercaseString];
      array = [registry componentsSeparatedByString: @"-"];
      registry = [array objectAtIndex: 0];
      if ([array count] > 1)
	{
	  encodstr = [array lastObject];
	}
      else
	{
	  encodstr = @"0";
	}
      
      encoding = GSEncodingForRegistry(registry, encodstr);
    }
  else
    {
      /* Look up the locale in our table of encodings */
      NSString *table;

      table = [NSBundle pathForGNUstepResource: @"Locale"
		                        ofType: @"encodings"
		                   inDirectory: @"Resources/Languages"];  
      if (table != nil)
	{
	  int count;
	  NSDictionary	*dict;
	  
	  dict = [NSDictionary dictionaryWithContentsOfFile: table];
	  encodstr = [dict objectForKey: 
			     [NSString stringWithCString: clocale]];
	  if (encodstr == nil)
	    return GSUndefinedEncoding;

	  /* Find the matching encoding */
	  count = 0;
	  while (str_encoding_table[count].enc
		 && strcmp(str_encoding_table[count].ename, 
			   [encodstr lossyCString]))
	    {
	      count++;
	    }
	  if (str_encoding_table[count].enc)
	    {
	      encoding = str_encoding_table[count].enc;
	    }
	  if (encoding == GSUndefinedEncoding)
	    {
	      NSLog(@"No known GNUstep encoding for %s = %@",
		    clocale, encodstr);
	    }
	}
    }
      
  return encoding;
}

/**
 * Return the default encoding
 */
NSStringEncoding
GetDefEncoding()
{
  if (defEnc == GSUndefinedEncoding)
    {
      char		*encoding;
      unsigned int	count;

      [gnustep_global_lock lock];
      if (defEnc != GSUndefinedEncoding)
	{
	  [gnustep_global_lock unlock];
	  return defEnc;
	}

      GSSetupEncodingTable();

      encoding = getenv("GNUSTEP_STRING_ENCODING");
      if (encoding != 0)
	{
	  count = 0;
	  while (str_encoding_table[count].enc
		 && strcmp(str_encoding_table[count].ename, encoding))
	    {
	      count++;
	    }
	  if (str_encoding_table[count].enc)
	    {
	      defEnc = str_encoding_table[count].enc;
	    }
	  else
	    {
	      fprintf(stderr,
		      "WARNING: %s - encoding not supported.\n", encoding);
	      fprintf(stderr, 
		      "  NSISOLatin1StringEncoding set as default.\n");
	      defEnc = NSISOLatin1StringEncoding;
	    }
	}
      if (defEnc == GSUndefinedEncoding)
	{
	  /* Encoding not set */
	  defEnc = NSISOLatin1StringEncoding;
	}
      else if (GSEncodingSupported(defEnc) == NO)
	{
	  fprintf(stderr, "WARNING: %s - encoding not implemented as "
		  "default c string encoding.\n", encoding);
	  fprintf(stderr,
		  "  NSISOLatin1StringEncoding set as default.\n");
	  defEnc = NSISOLatin1StringEncoding;
	}
      [gnustep_global_lock unlock];
    }
  return defEnc;
}

BOOL
GSIsByteEncoding(NSStringEncoding encoding)
{
  if (GSEncodingSupported(encoding) == NO)
    {
      return NO;
    }
  return encodingTable[encoding]->eightBit;
}

NSString*
GSEncodingName(NSStringEncoding encoding)
{
  if (GSEncodingSupported(encoding) == NO)
    {
      return @"Unknown encoding";
    }
  return [NSString stringWithCString: encodingTable[encoding]->ename];
}

NSString*
GetEncodingName(NSStringEncoding encoding)
{
  return GSEncodingName(encoding);
}

static const char *
iconv_stringforencoding(NSStringEncoding encoding)
{
  if (GSEncodingSupported(encoding) == NO)
    {
      return "";
    }
  return encodingTable[encoding]->iconv;
}

unichar
encode_chartouni(unsigned char c, NSStringEncoding enc)
{
  BOOL		result;
  unsigned int	size = 1;
  unichar	u = 0;
  unichar	*dst = &u;

  result = GSToUnicode(&dst, &size, &c, 1, enc, 0, 0);
  if (result == NO)
    {
      return 0;
    }
  return u;
}

unsigned char
encode_unitochar(unichar u, NSStringEncoding enc)
{
  BOOL		result;
  unsigned int	size = 1;
  unsigned char	c = 0;
  unsigned char	*dst = &c;

  result = GSFromUnicode(&dst, &size, &u, 1, enc, 0, 0);
  if (result == NO)
    {
      return 0;
    }
  return c;
}

unsigned
encode_unitochar_strict(unichar u, NSStringEncoding enc)
{
  BOOL		result;
  unsigned int	size = 1;
  unsigned char	c = 0;
  unsigned char	*dst = &c;

  result = GSFromUnicode(&dst, &size, &u, 1, enc, 0, GSUniStrict);
  if (result == NO)
    {
      return 0;
    }
  return c;
}

unichar
chartouni(unsigned char c)
{
  if (defEnc == GSUndefinedEncoding)
    {
      defEnc = GetDefEncoding();
    }
  return encode_chartouni(c, defEnc);
}

unsigned char
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
  BOOL		result;
  unsigned int	options = (strict == YES) ? GSUniStrict : 0;
  unsigned int	old = dl;

  result = GSFromUnicode((unsigned char**)&dst, (unsigned int*)&dl,
    src, sl, enc, 0, options);
  if (result == NO)
    {
      return 0;
    }
  return old - dl;	// Number of characters.
}

/**
 * Convert to unicode .. return the number of unicode characters produced.
 */
int encode_cstrtoustr(unichar *dst, int dl, const char *src, int sl, 
  NSStringEncoding enc)
{
  BOOL		result;
  unsigned int	old = dl;

  result = GSToUnicode(&dst, &dl, src, sl, enc, 0, 0);
  if (result == NO)
    {
      return 0;
    }
  return old - dl;
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
    result = NO; /* No buffer growth possible ... fail. */ \
    break; \
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
	result = NO;	/* Not enough memory */ \
	break; \
      } \
    bsize = grow / sizeof(unichar); \
  }

/**
 * Function to convert from 8-bit character data to 16-bit unicode.
 * <p>The dst argument is a pointer to a pointer to a buffer in which the
 * converted string is to be stored.  If it is a null pointer, this function
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
 * is not big enough (unless dst is a null pointer ... indicating that
 * converted data is to be discarded).
 * </p>
 * The options argument controls some special behavior.
 * <list>
 * <item>If GSUniTerminate is set, the function is expected to null terminate
 * the output string, and will assume that it is safe to place the nul
 * just beyond the ned of the stated buffer size.
 * Also, if the function grows the buffer, it will allow for an extra
 * termination character.</item>
 * <item>If GSUniTemporary is set, the function will return the results in
 * an autoreleased buffer rather than in a buffer that the caller must
 * release.</item>
 * <item>If GSUniBOM is set, the function will write the first unicode
 * character as a byte order marker.</item>
 * </list>
 * <item>If GSUniShortOk is set, the function will return a buffer containing
 * any decoded characters even if the whole conversion fails.</item>
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
  BOOL		result = YES;

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

  if (options & GSUniBOM)
    {
      while (dpos >= bsize)
	{
	  GROW();
	}
      ptr[dpos++] = (unichar)0xFEFF;	// Insert byte order marker.
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
		    i++;
		  }
	      }
	    dpos++;
	    spos++;
	  }
	break;

      default:
#ifdef HAVE_ICONV
	{
	  char		*inbuf;
	  char		*outbuf;
	  size_t	inbytesleft;
	  size_t	outbytesleft;
	  size_t	rval;
	  iconv_t	cd;

	  cd = iconv_open(UNICODE_ENC, iconv_stringforencoding(enc));
	  if (cd == (iconv_t)-1)
	    {
	      NSLog(@"No iconv for encoding %@ tried to use %s", 
		GetEncodingName(enc), iconv_stringforencoding(enc));
	      result = NO;
	      break;
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
		  outbytesleft += (bsize - old) * sizeof(unichar);
		}
	      rval = iconv(cd, &inbuf, &inbytesleft, &outbuf, &outbytesleft);
	      dpos = (bsize * sizeof(unichar) - outbytesleft) / sizeof(unichar);
	      if (rval == (size_t)-1)
		{
		  if (errno == E2BIG)
		    {
		      unsigned	old = bsize;

		      GROW();
		      outbuf = (char*)&ptr[dpos];
		      outbytesleft += (bsize - old) * sizeof(unichar);
		    }
		  else
		    {
		      result = NO;
		      break;
		    }
		}
	    }
	  // close the converter
	  iconv_close(cd);
	}
#else 
	result = NO;
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
  if (dst != 0 && (result == YES || (options & GSUniShortOk)))
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
	  if (ptr != buf && (dst == 0 || ptr != *dst))
	    {
	      NSZoneFree(zone, ptr);
	    }
	  ptr = r;
	}
      else if (zone != 0 && (ptr == buf || bsize > dpos))
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
	}
      *dst = ptr;
    }
  else if (ptr != buf && dst != 0 && ptr != *dst)
    {
      NSZoneFree(zone, ptr);
    }
  return result;
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
    result = NO; /* No buffer growth possible ... fail. */ \
    break; \
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
	result = NO;	/* Not enough memory */ \
	break; \
      } \
    bsize = grow; \
  }


static inline int chop(unichar c, _ucc_ *table, int hi)
{
  int	lo = 0;

  while (hi > lo)
    {
      int	i = (hi + lo) / 2;
      unichar	from = table[i].from;

      if (from < c)
        {
	  lo = i + 1;
	}
      else if (from > c)
        {
	  hi = i;
	}
      else
        {
	  return i;	// Found
	}
    }
  return -1;		// Not found
}

/**
 * Function to convert from 16-bit unicode to 8-bit character data.
 * <p>The dst argument is a pointer to a pointer to a buffer in which the
 * converted string is to be stored.  If it is a null pointer, this function
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
 * is not big enough (unless dst is a null pointer ... indicating that
 * converted data is to be discarded).
 * </p>
 * The options argument controls some special behavior.
 * <list>
 * <item>If GSUniStrict is set, the function will fail if a character is
 * encountered which can't be displayed in the source.  Otherwise, some
 * approximation or marker will be placed in the destination.</item>
 * </list>
 * <item>If GSUniTerminate is set, the function is expected to null terminate
 * the output string, and will assume that it is safe to place the nul
 * just beyond the ned of the stated buffer size.
 * Also, if the function grows the buffer, it will allow for an extra
 * termination character.</item>
 * <item>If GSUniTemporary is set, the function will return the results in
 * an autoreleased buffer rather than in a buffer that the caller must
 * release.</item>
 * <item>If GSUniBOM is set, the function will read the first unicode
 * character as a byte order marker.</item>
 * <item>If GSUniShortOk is set, the function will return a buffer containing
 * any decoded characters even if the whole conversion fails.</item>
 * </list>
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
  unsigned char	escape = 0;
  _ucc_		*etable = 0;
  unsigned	etsize = 0;
  _ucc_		*ltable = 0;
  unsigned	ltsize = 0;
  BOOL		swapped = NO;
  BOOL		result = YES;
  
  if (options & GSUniBOM)
    {
      if (slen == 0)
	{
	  *size = 0;
	  result = NO;	// Missing byte order marker.
	}
      else
	{
	  unichar	c;

	  c = *src++;
	  slen--;
	  if (c != 0xFEFF)
	    {
	      if (c == 0xFFFE)
		{
		  swapped = YES;
		}
	      else
		{
		  *size = 0;
		  result = NO;	// Illegal byte order marker.
		}
	    }
	}
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
	if (strict == NO)
	  {
	    while (spos < slen)
	      {
		unichar	u = src[spos++];

		if (swapped == YES)
		  {
		    u = ((u & 0xff00 >> 8) + ((u & 0x00ff) << 8));
		  }
		
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
		    ptr[dpos++] =  '*';
		  }
	      }
	  }
	else
	  {
	    while (spos < slen)
	      {
		unichar	u = src[spos++];

		if (swapped == YES)
		  {
		    u = ((u & 0xff00 >> 8) + ((u & 0x00ff) << 8));
		  }
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
		    result = NO;
		    break;
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

      case NSGSM0338StringEncoding:
	base = 0;
	table = GSM0338_uni_to_char_table;
	tsize = GSM0338_tsize;
        escape = 0x1b;
	etable = GSM0338_escapes;
	etsize = GSM0338_esize;
	if (strict == NO)
	  {
	    ltable = GSM0338_lossy;
	    ltsize = GSM0338_lsize;
	  }
	goto tables;

tables:
	while (spos < slen)
	  {
	    unichar	u = src[spos++];
	    int	i;

	    /* Swap byte order if necessary */
	    if (swapped == YES)
	      {
		u = ((u & 0xff00 >> 8) + ((u & 0x00ff) << 8));
	      }

	    /* Grow output buffer to make room if necessary */
	    if (dpos >= bsize)
	      {
		GROW();
	      }

	    if (u < base)
	      {
		/*
		 * The character set has a lower section whose contents
		 * are identical to unicode, so no mapping is needed.
		 */
		ptr[dpos++] = (char)u;
	      }
	    else if (table != 0 && (i = chop(u, table, tsize)) >= 0)
	      {
		/*
		 * The character mapping is found in a basic table.
		 */
		ptr[dpos++] = table[i].to;
	      }
	    else if (etable != 0 && (i = chop(u, etable, etsize)) >= 0)
	      {
		/*
		 * The character mapping is found in a table of simple
		 * escape sequences consisting of an escape byte followed
		 * by another single byte.
		 */
		ptr[dpos++] = escape;
		if (dpos >= bsize)
		  {
		    GROW();
		  }
		ptr[dpos++] = etable[i].to;
	      }
	    else if (ltable != 0 && (i = chop(u, ltable, ltsize)) >= 0)
	      {
		/*
		 * The character is found in a lossy mapping table.
		 */
		ptr[dpos++] = ltable[i].to;
	      }
	    else if (strict == NO)
	      {
		/*
		 * The default lossy mapping generates an asterisk.
		 */
		ptr[dpos++] = '*';
	      }
	    else
	      {
		/*
		 * No mapping has been found.
		 */
		result = NO;
		spos = slen;
		break;
	      }
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
	  size_t	rval;

	  cd = iconv_open(iconv_stringforencoding(enc), UNICODE_ENC);
	  if (cd == (iconv_t)-1)
	    {
	      NSLog(@"No iconv for encoding %@ tried to use %s", 
		GetEncodingName(enc), iconv_stringforencoding(enc));
	      result = NO;
	      break;
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
		  outbytesleft += (bsize - old);
		}
	      rval = iconv(cd, &inbuf, &inbytesleft, &outbuf, &outbytesleft);
	      dpos = bsize - outbytesleft;
	      if (rval != 0)
		{
		  if (rval == (size_t)-1)
		    {
		      if (errno == E2BIG)
			{
			  unsigned	old = bsize;

			  GROW();
			  outbuf = (char*)&ptr[dpos];
			  outbytesleft += (bsize - old);
			}
		      else if (errno == EILSEQ)
			{
			  if (strict == YES)
			    {
			      result = NO;
			      break;
			    }
			  /*
			   * If we are allowing lossy conversion, we replace any
			   * unconvertable character with an asterisk.
			   */
			  if (outbytesleft > 0)
			    {
			      *outbuf++ = '*';
			      outbytesleft--;
			      inbuf += sizeof(unichar);
			      inbytesleft -= sizeof(unichar);
			    }
			}
		      else
			{
			  result = NO;
			  break;
			}
		    }
		  else if (strict == YES)
		    {
		      /*
		       * A positive return from iconv indicates some
		       * irreversible (ie lossy) conversions took place,
		       * so if we are doing strict conversions we must fail.
		       */
		      result = NO;
		      break;
		    }
		}
	    }
	  // close the converter
	  iconv_close(cd);
	}
#else 
	result = NO;
	break;
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
  if (dst != 0 && (result == YES || (options & GSUniShortOk)))
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
	  if (ptr != buf && (dst == 0 || ptr != *dst))
	    {
	      NSZoneFree(zone, ptr);
	    }
	  ptr = r;
	}
      else if (zone != 0 && (ptr == buf || bsize > dpos))
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
	}
      *dst = ptr;
    }
  else if (ptr != buf && dst != 0 && ptr != *dst)
    {
      NSZoneFree(zone, ptr);
    }
  return result;
}

#undef	GROW

