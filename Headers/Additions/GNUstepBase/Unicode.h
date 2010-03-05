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
#include <GNUstepBase/GSVersionMacros.h>

#import <Foundation/NSString.h>	/* For standard string encodings */

#if	OS_API_VERSION(GS_API_NONE,GS_API_LATEST)

#if	defined(__cplusplus)
extern "C" {
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
