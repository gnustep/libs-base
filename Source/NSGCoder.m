/* Concrete NSCoder for GNUStep
   Copyright (C) 1995 Free Software Foundation, Inc.
   
   Written by:  R. Andrew McCallum <mccallum@gnu.ai.mit.edu>
   Date: March 1995
   
   This file is part of the GNU Objective C Class Library.
   
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

#include <foundation/NSConcreteArray.h>
#include <objects/NSCoder.h>
#include <objects/behavior.h>
#include <objects/Coder.h>

@implementation NSGNUCoder

+ (void) initialize
{
  static int done = 0;
  if (!done)
    {
      done = 1;
      class_add_behavior([NSConcreteCoder class], [Coder class]);
    }
}

/* This is the designated initializer for NSCoder. */
- init
{
  [self notImplemented:_cmd];
  [super init];
  return self;
}

// Encoding Data

- (void) encodeValueOfObjCType: (const char*)type
   at: (const void*)address;
{
  [self notImplemented:_cmd];
}

- (void) encodeObject: (id)anObject;
{
  [self encodeObject:anObject
	withName:""];
}

- (void) encodeConditionalObject: (id)anObject;
{
  [self encodeObjectReference:anObject
	withName:""];
}

- (void) encodeBycopyObject: (id)anObject;
{
  [self encodeObject:anObject];
}

- (void) encodeRootObject: (id)rootObject;
{
  [self encodeObject];
}


// Decoding Data

- (void) decodeValueOfObjCType: (const char*)type
   at: (void*)address
{
  [self notImplemented:_cmd];
}

- (id) decodeObject;
{
  [self notImplemented:_cmd];
  return nil;
}

// Managing Zones

- (NSZone*) objectZone;
{
  return object_zone;
}

- (void) setObjectZone: (NSZone*)zone;
{
  object_zone = zone;
}


@end
