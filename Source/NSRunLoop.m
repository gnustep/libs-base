/* NSRunLoop class for GNUstep
   Copyright (C) 1995, 1996 Free Software Foundation, Inc.
   
   Written by:  Andrew Kachites McCallum <mccallum@gnu.ai.mit.edu>
   Created: April 1995
   
   This file is part of the Gnustep Base Library.
   
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
#include <Foundation/NSRunLoop.h>
#include <gnustep/base/RunLoop.h>
#include <gnustep/base/Connection.h>

@implementation NSRunLoop

/* This class is almost fully implemented in GNU's RunLoop. */

+ (void) initialize
{
  if (self == [NSRunLoop class])
    behavior_class_add_class (self, [RunLoop class]);
}

+ (NSRunLoop*) currentRunLoop
{
  return [self currentInstance];
}

- (BOOL) runMode: (NSString*)mode beforeDate: (NSDate*)limit_date
{
  return [(id)self runOnceBeforeDate: limit_date forMode: mode];
}

@end
