/* Implementation for NSPipe for GNUStep
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
   Software Foundation, Inc., 675 Mass Ave, Cambridge, MA 02139, USA.
   */

#include <config.h>
#include <gnustep/base/preface.h>
#include <Foundation/NSObject.h>
#include <Foundation/NSFileHandle.h>

#ifndef __WIN32__
#include <unistd.h>
#endif

@implementation NSPipe

// Allocating and Initializing a FileHandle Object

+ (id)pipe
{
    return [[[self alloc] init] autorelease];
}

- (void)dealloc
{
    [readHandle release];
    [writeHandle release];
    [super dealloc];
}

- (id)init
{
  self = [super init];
  if (self)
    {
      int	p[2];

      if (pipe(p) == 0)
        {
          readHandle = [[NSFileHandle alloc] initWithFileDescriptor:p[0]];
          writeHandle = [[NSFileHandle alloc] initWithFileDescriptor:p[1]];
        }
    }
  return self;
}

- fileHandleForReading
{
  return readHandle;
}

- fileHandleForWriting
{
  return writeHandle;
}

@end

