/* Implementation for GNU Objective-C MutableString object
   Copyright (C) 1993,1994, 1996 Free Software Foundation, Inc.

   Written by:  Andrew Kachites McCallum <mccallum@gnu.ai.mit.edu>
   Date: July 1994

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

#include <gnustep/base/String.h>
#include <gnustep/base/IndexedCollectionPrivate.h>
#include <gnustep/base/NSString.h>
/* memcpy(), strlen(), strcmp() are gcc builtin's */
#include <limits.h>

@implementation MutableString

/* This is the designated initializer */
- initWithCapacity: (unsigned)capacity
{
  return [self subclassResponsibility:_cmd];
}

+ (MutableString*) stringWithCapacity: (unsigned)capacity
{
  MutableCString *n = [[MutableCString alloc] initWithCapacity:capacity];
  return [n autorelease];
}

/* Subclasses need to implemented the next two methods */

- (void) removeRange: (IndexRange)range
{
  [self subclassResponsibility:_cmd];
}

- (void) insertString: (String*)string atIndex: (unsigned)index
{
  [self subclassResponsibility:_cmd];
}

- (void) setString: (String*)string
{
  [self replaceRange:(IndexRange){0,INT_MAX} withString:string];
}

- (void) appendString: (String*)string
{
  [self insertString:string atIndex:[self count]];
}

- (void) replaceRange: (IndexRange)range withString: (String*)string
{
  [self removeRange:range];
  [self insertString:string atIndex:range.location];
}

// SETTING VALUES;

- (void) setIntValue: (int)anInt
{
  [self setString:[String stringWithFormat:@"%d", anInt]];
}

- (void) setFloatValue: (float)aFloat
{
  [self setString:[String stringWithFormat:@"%f", aFloat]];
}

- (void) setDoubleValue: (double)aDouble
{
  [self setString:[String stringWithFormat:@"%f", aDouble]];
}

- (void) setCStringValue: (const char *)aCString
{
  [self setString:[String stringWithCString:aCString]];
}

- (void) setStringValue: (String*)aString
{
  [self setString:aString];
}

@end
