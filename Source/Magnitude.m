/* Implementation for Objective-C Magnitude object
   Copyright (C) 1993,1994 Free Software Foundation, Inc.

   Written by:  R. Andrew McCallum <mccallum@gnu.ai.mit.edu>
   Date: May 1993

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
#include <gnustep/base/Magnitude.h>

/* These methods accesses no instance variables.  It is exactly the kind
   of thing that should be a "behavior" associated with a protocol.
   i.e. #3 on Steve Naroff's wish list. */

@implementation Magnitude

- (int) compare: anObject
{
  return [super compare:anObject];
}

- (BOOL) greaterThan: anObject
{
  if ([self compare:anObject] > 0)
    return YES;
  else
    return NO;
}

- (BOOL) greaterThanOrEqual: anObject
{
  if ([self compare:anObject] >= 0)
    return YES;
  else
    return NO;
}


- (BOOL) lessThan: anObject
{
  if ([self compare:anObject] < 0)
    return YES;
  else
    return NO;
}

- (BOOL) lessThanOrEqual: anObject
{
  if ([self compare:anObject] <= 0)
    return YES;
  else
    return NO;
}


- (BOOL) between: firstObject and: secondObject
{
  if ([self compare:firstObject] >= 0
      && [self compare:secondObject] <= 0)
    return YES;
  else
    return NO;
}


- maximum: anObject
{
  if ([self compare:anObject] >= 0)
    return self;
  else
    return anObject;
}

- minimum: anObject
{
  if ([self compare:anObject] <= 0)
    return self;
  else
    return anObject;
}

@end
