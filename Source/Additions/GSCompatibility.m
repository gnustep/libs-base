/* GSCompatibility - Extra definitions for compiling on MacOSX

   Copyright (C) 2002 Free Software Foundation, Inc.

   Written by:  Adam Fedor <fedor@gnu.org>

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
#include "config.h"
#include "GSCompatibility.h"

/* FIXME: Need to initialize this */
NSRecursiveLock *gnustep_global_lock = NULL;

NSString *GetEncodingName(NSStringEncoding availableEncodingValue)
{
return (NSString *)CFStringGetNameOfEncoding(CFStringConvertNSStringEncodingToEncoding(availableEncodingValue));
}

@implementation NSArray (GSCompatibility)

/**
 * Initialize the receiver with the contents of array.
 * The order of array is preserved.<br />
 * If shouldCopy is YES then the objects are copied
 * rather than simply retained.<br />
 * Invokes -initWithObjects:count:
 */
- (id) initWithArray: (NSArray*)array copyItems: (BOOL)shouldCopy
{
  unsigned	c = [array count];
  id		objects[c];

  [array getObjects: objects];
  if (shouldCopy == YES)
    {
      unsigned	i;

      for (i = 0; i < c; i++)
	{
	  objects[i] = [objects[i] copy];
	}
      self = [self initWithObjects: objects count: c];
#if GS_WITH_GC == 0
      while (i > 0)
	{
	  [objects[--i] release];
	}
#endif
    }
  else
    {
      self = [self initWithObjects: objects count: c];
    }
  return self;
}

@end
