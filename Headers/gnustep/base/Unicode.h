  /* Interface for support functions for Unicode implementation
   Copyright (C) 1997 Free Software Foundation, Inc.

   Written by: Stevo Crvenkovski <stevo@btinternet.com>
   Date: March 1997

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

unichar chartouni(char c);
char unitochar(unichar u);
unichar encode_chartouni(char c, NSStringEncoding enc);
char encode_unitochar(unichar u, NSStringEncoding enc);
unsigned encode_unitochar_strict(unichar u, NSStringEncoding enc);
int strtoustr(unichar * u1,const char *s1,int size);
int ustrtostr(char *s2,unichar *u1,int size);
int encode_strtoustr(unichar* u1,const char*s1,int size, NSStringEncoding enc);
int encode_ustrtostr(char *s2, unichar *u1, int size, NSStringEncoding enc);
int encode_ustrtostr_strict(char *s2, unichar *u1, int size, NSStringEncoding enc);

unichar uni_tolower(unichar ch);
unichar uni_toupper(unichar ch);
unsigned char uni_cop(unichar u);
BOOL uni_isnonsp(unichar u);
unichar *uni_is_decomp(unichar u);

#endif /* __Unicode_h_OBJECTS_INCLUDE */
