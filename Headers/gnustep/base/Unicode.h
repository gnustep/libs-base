/* Interface for support functions for Unicode implementation.
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
   modify it under the terms of the GNU Library General Public
   License as published by the Free Software Foundation; either
   version 2 of the License, or (at your option) any later version.

   This library is distributed in the hope that it will be useful,
   but WITHOUT ANY WARRANTY; without even the implied warranty of
   MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
   Library General Public License for more details.

   You should have received a copy of the GNU Library General Public
   License along with this library; if not, write to the Free Software
   Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA 02111 USA.
*/

#ifndef __Unicode_h_OBJECTS_INCLUDE
#define __Unicode_h_OBJECTS_INCLUDE

#include <Foundation/NSString.h>	/* For string encodings */

/*
 * Private API used internally by NSString etc.
 */
#ifndef	NO_GNUSTEP

GS_EXPORT NSStringEncoding *GetAvailableEncodings();
GS_EXPORT NSStringEncoding GetDefEncoding();
GS_EXPORT NSString* GetEncodingName(NSStringEncoding encoding);

GS_EXPORT unichar chartouni(char c);
GS_EXPORT char unitochar(unichar u);
GS_EXPORT unichar encode_chartouni(char c, NSStringEncoding enc);
GS_EXPORT char encode_unitochar(unichar u, NSStringEncoding enc);
GS_EXPORT unsigned encode_unitochar_strict(unichar u, NSStringEncoding enc);

GS_EXPORT int encode_ustrtocstr(char *dst, int dl, const unichar *src, int sl, 
  NSStringEncoding enc, BOOL strict);
GS_EXPORT int encode_cstrtoustr(unichar *dst, int dl, const char *str, int sl, 
  NSStringEncoding enc);

GS_EXPORT unichar uni_tolower(unichar ch);
GS_EXPORT unichar uni_toupper(unichar ch);
GS_EXPORT unsigned char uni_cop(unichar u);
GS_EXPORT BOOL uni_isnonsp(unichar u);
GS_EXPORT unichar *uni_is_decomp(unichar u);

/*
 * Options when converting strings.
 */
#define	GSUniTerminate	0x01
#define	GSUniTemporary	0x02
#define	GSUniStrict	0x04

GS_EXPORT BOOL GSFromUnicode(unsigned char **dst, unsigned int *size,
  const unichar *src, unsigned int slen, NSStringEncoding enc, NSZone *zone,
  unsigned int options);
GS_EXPORT BOOL GSToUnicode(unichar **dst, unsigned int *size,
  const unsigned char *src, unsigned int slen, NSStringEncoding enc,
  NSZone *zone, unsigned int options);

#endif

#endif /* __Unicode_h_OBJECTS_INCLUDE */
