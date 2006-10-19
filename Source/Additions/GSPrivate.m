/* Private internal methods for use within the base library

   Copyright (C) 2006 Free Software Foundation, Inc.

   Written by:  Richard Frith-Macdonald <rfm@gnu.org>

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
   Software Foundation, Inc., 51 Franklin Street, Fifth Floor,
   Boston, MA 02111 USA.

*/
#include "config.h"
#include <string.h>
#include <Foundation/Foundation.h>
#include "GNUstepBase/GSCategories.h"
#include "GNUstepBase/GSLock.h"
#include "GSPrivate.h"

/* Test for ASCII whitespace which is safe for unicode characters */
#define	space(C)	((C) > 127 ? NO : isspace(C))

#ifndef HAVE_STRERROR
const char *
strerror(int eno)
{
  extern char  *sys_errlist[];
  extern int    sys_nerr;

  if (eno < 0 || eno >= sys_nerr)
    {
      return("unknown error number");
    }
  return(sys_errlist[eno]);
}
#endif

@implementation	GSPrivate

- (NSString*) error
{
#if defined(__MINGW32__)
  return [self error: GetLastError()];
#else
  extern int errno;
  return [self error: errno];
#endif
}

- (NSString*) error: (long)number
{
  NSString	*text;
#if defined(__MINGW32__)
  LPVOID	lpMsgBuf;

  FormatMessageW(FORMAT_MESSAGE_ALLOCATE_BUFFER | FORMAT_MESSAGE_FROM_SYSTEM,
    NULL, number, MAKELANGID(LANG_NEUTRAL, SUBLANG_DEFAULT),
    (LPWSTR) &lpMsgBuf, 0, NULL );
  text = [NSString stringWithCharacters: lpMsgBuf length: wcslen(lpMsgBuf)];
  LocalFree(lpMsgBuf);
#else
  text = [NSString stringWithCString: strerror(number)
			    encoding: [NSString defaultCStringEncoding]];
#endif
  return text;
}
@end


