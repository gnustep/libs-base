/** Implementation for NSPipe for GNUStep
   Copyright (C) 1997 Free Software Foundation, Inc.

   Written by:  Richard Frith-Macdonald <richard@brainstorm.co.uk>
   Date: 1997

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
#include <base/preface.h>
#include <Foundation/NSObject.h>
#include <Foundation/NSFileHandle.h>
#include <Foundation/NSDebug.h>
#include <unistd.h>

@implementation NSPipe

// Allocating and Initializing a FileHandle Object

+ (id) pipe
{
  return AUTORELEASE([[self alloc] init]);
}

- (void) dealloc
{
  RELEASE(readHandle);
  RELEASE(writeHandle);
  [super dealloc];
}

- (id) init
{
  self = [super init];
  if (self != nil)
    {
#ifndef __MINGW__
      int	p[2];

      if (pipe(p) == 0)
        {
          readHandle = [[NSFileHandle alloc] initWithFileDescriptor: p[0]];
          writeHandle = [[NSFileHandle alloc] initWithFileDescriptor: p[1]];
        }
      else
	{
	  NSLog(@"Failed to create pipe ... %s", GSLastErrorStr(errno));
	  DESTROY(self);
	}
#else
      HANDLE readh, writeh;

      if (CreatePipe(&readh, &writeh, NULL, 0) != 0)
        {
          readHandle = [[NSFileHandle alloc] initWithNativeHandle: readh];
          writeHandle = [[NSFileHandle alloc] initWithNativeHandle: writeh];
        }
#endif
    }
  return self;
}

- (id) fileHandleForReading
{
  return readHandle;
}

- (id) fileHandleForWriting
{
  return writeHandle;
}

@end

