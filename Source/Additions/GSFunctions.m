/* Extension functions for GNUstep
   Copyright (C) 2005-2006 Free Software Foundation, Inc.

   Written by:  Richard Frith-Macdonald <rfm@gnu.org>
   Written by:  Manuel Guesdon <mguesdon@orange-concept.com>
   Date: Nov 2002
   Written by:  Sheldon Gill
   Date:    2005

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
   Software Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA 02111 USA.

   <title>NSPathUtilities function reference</title>
   $Date$ $Revision$
   */

#include "config.h"
#include "GNUstepBase/preface.h"
#include "GNUstepBase/GSFunctions.h"
#include "Foundation/Foundation.h"
#include "GNUstepBase/Win32_Utilities.h"


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

/*
 * Gets the last error from the system libraries...
 */
NSString *
GSErrorString(long error_id)
{
#ifdef __MINGW32__
  return Win32ErrorString(error_id);
#else
  return [NSString stringWithCString: strerror(error_id)
                            encoding: NSUTF8StringEncoding];
#endif
}

BOOL
GSPrintf (FILE *fptr, NSString* format, ...)
{
  static Class                  stringClass = 0;
  static NSStringEncoding       enc;
  CREATE_AUTORELEASE_POOL(arp);
  va_list       ap;
  NSString      *message;
  NSData        *data;
  BOOL          ok = NO;

  if (stringClass == 0)
    {
      stringClass = [NSString class];
      enc = [stringClass defaultCStringEncoding];
    }
  message = [stringClass allocWithZone: NSDefaultMallocZone()];
  va_start (ap, format);
  message = [message initWithFormat: format locale: nil arguments: ap];
  va_end (ap);
  data = [message dataUsingEncoding: enc];
  if (data == nil)
    {
      data = [message dataUsingEncoding: NSUTF8StringEncoding];
    }
  RELEASE(message);

  if (data != nil)
    {
      unsigned int      length = [data length];

      if (length == 0 || fwrite([data bytes], 1, length, fptr) == length)
        {
          ok = YES;
        }
    }
  RELEASE(arp);
  return ok;
}

NSString *
GSFindNamedFile(NSArray *paths, NSString *aName, NSString *anExtension)
{
  NSFileManager *file_mgr = [NSFileManager defaultManager];
  NSString *file_name, *file_path, *path;
  NSEnumerator *enumerator;

  NSCParameterAssert(aName != nil);
  NSCParameterAssert(paths != nil);

  /* make up the name with extension if given */
  if (anExtension != nil)
    {
      file_name = [aName stringByAppendingPathExtension: anExtension];
    }
  else
    {
      file_name = aName;
    }

  enumerator = [paths objectEnumerator];
  while ((path = [enumerator nextObject]))
    {
      file_path = [path stringByAppendingPathComponent: file_name];

      if ([file_mgr fileExistsAtPath: file_path] == YES)
        {
          return file_path; // Found it!
        }
    }
  return nil;
}
