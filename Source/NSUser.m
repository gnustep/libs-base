/* Implementation of login-related functions for GNUstep
   Copyright (C) 1996 Free Software Foundation, Inc.
   
   Written by:  Andrew Kachites McCallum <mccallum@gnu.ai.mit.edu>
   Created: May 1996
   
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
   Software Foundation, Inc., 675 Mass Ave, Cambridge, MA 02139, USA.
   */ 

#include <gnustep/base/preface.h>
#include <Foundation/NSString.h>
#include <stdlib.h>		// for getenv()
#ifndef __WIN32__
#include <unistd.h>		// for getlogin()
#include <pwd.h>		// for getpwnam()
#endif
#include <sys/types.h>

/* Return the caller's login name as an NSString object. */
NSString *
NSUserName ()
{
#ifndef __WIN32__
  const char *login_name = getlogin ();
  
  if (login_name)
    return [NSString stringWithCString: login_name];
  else
    return nil;
#else
  return nil;
#endif /* __WIN32__ */
}

/* Return the caller's home directory as an NSString object. */
NSString *
NSHomeDirectory ()
{
  return [NSString stringWithCString: getenv ("HOME")];
}

/* Return LOGIN_NAME's home directory as an NSString object. */
NSString *
NSHomeDirectoryForUser (NSString *login_name)
{
#ifndef __WIN32__
  struct passwd *pw;
  pw = getpwnam ([login_name cStringNoCopy]);
  return [NSString stringWithCString: pw->pw_dir];
#else
  return nil;
#endif
}
