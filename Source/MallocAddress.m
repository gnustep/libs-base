/* Provides autoreleasing of malloc'ed pointers
   Copyright (C) 1995, 1996 Free Software Foundation, Inc.
   
   Written by:  Andrew Kachites McCallum <mccallum@gnu.ai.mit.edu>
   Created: January 1995
   
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
#include <gnustep/base/MallocAddress.h>
#include <gnustep/base/Dictionary.h>
#include <Foundation/NSMapTable.h>

static NSMapTable* mallocAddresses;

@implementation MallocAddress

+ (void) initialize
{
  if (self == [MallocAddress class])
    {
      mallocAddresses = 
	NSCreateMapTable (NSNonOwnedPointerMapKeyCallBacks,
			  NSNonOwnedPointerMapValueCallBacks, 0);
    }
}

+ objectForAddress: (void*)addr
{
  return NSMapGet (mallocAddresses, addr);
}

+ autoreleaseMallocAddress: (void*)addr
{
  id n = [[self alloc] initWithAddress:addr];
  NSMapInsert (mallocAddresses, addr, n);
  return [n autorelease];
}

- initWithAddress: (void*)addr
{
  [super init];
  address = addr;
  return self;
}

- (void) dealloc
{
  NSMapRemove (mallocAddresses, address);
  OBJC_FREE(address);
  [super dealloc];
}

@end

