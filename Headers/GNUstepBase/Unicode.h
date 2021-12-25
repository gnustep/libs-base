/** Interface for support functions for Unicode implementation.
   Interface for GetDefEncoding function to determine default c
   string encoding for GNUstep based on GNUSTEP_STRING_ENCODING
   environment variable.
   Copyright (C) 1997 Free Software Foundation, Inc.

   Written by: Stevo Crvenkovski <stevo@btinternet.com>
   Date: March 1997
   Merged with GetDefEncoding.h: Fred Kiefer <fredkiefer@gmx.de>
   Date: September 2000

   This file is part of the GNUstep Base Library.

   This library is free software; you can redistribute it and/or
   modify it under the terms of the GNU Lesser General Public
   License as published by the Free Software Foundation; either
   version 2 of the License, or (at your option) any later version.

   This library is distributed in the hope that it will be useful,
   but WITHOUT ANY WARRANTY; without even the implied warranty of
   MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
   Library General Public License for more details.

   You should have received a copy of the GNU Lesser General Public
   License along with this library; if not, write to the Free Software
   Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA 02111 USA.

   AutogsdocSource: Additions/Unicode.m

*/

#ifndef __Unicode_h_OBJECTS_INCLUDE
#define __Unicode_h_OBJECTS_INCLUDE
#import <GNUstepBase/GSVersionMacros.h>

#import <Foundation/NSString.h>	/* For standard string encodings */

#if	OS_API_VERSION(GS_API_NONE,GS_API_LATEST)

#if	defined(__cplusplus)
extern "C" {
#endif

#if	defined(NeXT_Foundation_LIBRARY)

/* Taken from base/Headers/Foundation/NSString.h */
typedef enum _NSGNUstepStringEncoding
{
/* NB. Must not have an encoding with value zero - so we can use zero to
   tell that a variable that should contain an encoding has not yet been
   initialised */
  GSUndefinedEncoding = 0,

// GNUstep additions
  NSKOI8RStringEncoding = 50,		// Russian/Cyrillic
  NSISOLatin3StringEncoding = 51,	// ISO-8859-3; South European
  NSISOLatin4StringEncoding = 52,	// ISO-8859-4; North European
  NSISOCyrillicStringEncoding = 22,	// ISO-8859-5
  NSISOArabicStringEncoding = 53,	// ISO-8859-6
  NSISOGreekStringEncoding = 54,	// ISO-8859-7
  NSISOHebrewStringEncoding = 55,	// ISO-8859-8
  NSISOLatin5StringEncoding = 57,	// ISO-8859-9; Turkish
  NSISOLatin6StringEncoding = 58,	// ISO-8859-10; Nordic
  NSISOThaiStringEncoding = 59,		// ISO-8859-11
/* Possible future ISO-8859 additions
					// ISO-8859-12
*/
  NSISOLatin7StringEncoding = 61,	// ISO-8859-13
  NSISOLatin8StringEncoding = 62,	// ISO-8859-14
  NSISOLatin9StringEncoding = 63,  // ISO-8859-15; Replaces ISOLatin1
  NSGB2312StringEncoding = 56,
  NSUTF7StringEncoding = 64, // RFC 2152
  NSGSM0338StringEncoding = 65, // GSM (mobile phone) default alphabet
  NSBIG5StringEncoding = 66, // Traditional chinese
  NSKoreanEUCStringEncoding = 67, // Korean

  NSDOSLatinUSStringEncoding = 68, // code page 437
  NSDOSGreekStringEncoding, // code page 737 (formerly code page 437G) */
  NSDOSBalticRimStringEncoding, // code page 775
  NSDOSLatin1StringEncoding, // code page 850, "Multilingual"
  NSDOSGreek1StringEncoding, // code page 851
  NSDOSLatin2StringEncoding, // code page 852, Slavic
  NSDOSCyrillicStringEncoding, // code page 855, IBM Cyrillic
  NSDOSTurkishStringEncoding, // code page 857, IBM Turkish
  NSDOICortugueseStringEncoding, // code page 860
  NSDOSIcelandicStringEncoding, // code page 861
  NSDOSHebrewStringEncoding, // code page 862
  NSDOSCanadianFrenchStringEncoding, // code page 863
  NSDOSArabicStringEncoding, // code page 864
  NSDOSNordicStringEncoding, // code page 865
  NSDOSRussianStringEncoding, // code page 866
  NSDOSGreek2StringEncoding, // code page 869, IBM Modern Greek
  NSDOSThaiStringEncoding, // code page 874, also for Windows
  NSDOSJapaneseStringEncoding, // code page 932, also for Windows
  NSDOSChineseSimplifStringEncoding, // code page 936, also for Windows
  NSDOSKoreanStringEncoding, // code page 949, also for Windows; Unified Hangul Code
  NSDOSChineseTradStringEncoding, // code page 950, also for Windows
  // NSWindowsLatin1StringEncoding, // code page 1252, NSWindowsCP1252StringEncoding
  // NSWindowsLatin2StringEncoding, // code page 1250, Central Europe, NSWindowsCP1250StringEncoding
  // NSWindowsCyrillicStringEncoding, // code page 1251, Slavic Cyrillic. NSWindowsCP1251StringEncoding
  // NSWindowsGreekStringEncoding, // code page 1253, NSWindowsCP1253StringEncoding
  // NSWindowsLatin5StringEncoding, // code page 1254, Turkish, NSWindowsCP1254StringEncoding
  NSWindowsHebrewStringEncoding, // code page 1255
  NSWindowsArabicStringEncoding, // code page 1256
  NSWindowsBalticRimStringEncoding, // code page 1257
  NSWindowsVietnameseStringEncoding, // code page 1258
  NSWindowsKoreanJohabStringEncoding, // code page 1361, for Windows NT

#if OS_API_VERSION(MAC_OS_X_VERSION_10_4,GS_API_ANY)
  NSUTF16BigEndianStringEncoding = 0x90000100,
  NSUTF16LittleEndianStringEncoding = 0x94000100,
  NSUTF32StringEncoding = 0x8c000100,
  NSUTF32BigEndianStringEncoding = 0x98000100,
  NSUTF32LittleEndianStringEncoding = 0x9c000100,
#endif

  GSEncodingUnusedLast
} NSGNUstepStringEncoding;

#endif

#if GS_API_VERSION(GS_API_NONE,011500)
/* Deprecated functions */
GS_EXPORT NSStringEncoding GSEncodingFromLocale(const char *clocale);
GS_EXPORT NSStringEncoding GSEncodingForRegistry(NSString *registry, 
  NSString *encoding);
GS_EXPORT unichar uni_tolower(unichar ch);
GS_EXPORT unichar uni_toupper(unichar ch);

GS_EXPORT unsigned char uni_cop(unichar u);
GS_EXPORT BOOL uni_isnonsp(unichar u);
GS_EXPORT unichar *uni_is_decomp(unichar u);
GS_EXPORT unsigned GSUnicode(const unichar *chars, unsigned length,
  BOOL *isASCII, BOOL *isLatin1);
#endif


/*
 * Options when converting strings.
 */
#define	GSUniTerminate	0x01
#define	GSUniTemporary	0x02
#define	GSUniStrict	0x04
#define	GSUniBOM	0x08
#define	GSUniShortOk	0x10

GS_EXPORT BOOL GSFromUnicode(unsigned char **dst, unsigned int *size,
  const unichar *src, unsigned int slen, NSStringEncoding enc, NSZone *zone,
  unsigned int options);
GS_EXPORT BOOL GSToUnicode(unichar **dst, unsigned int *size,
  const unsigned char *src, unsigned int slen, NSStringEncoding enc,
  NSZone *zone, unsigned int options);

#if	defined(__cplusplus)
}
#endif

#endif	/* OS_API_VERSION(GS_API_NONE,GS_API_NONE) */

#endif /* __Unicode_h_OBJECTS_INCLUDE */
