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

#include <foundation/NSGCoder.h>
#include <objects/NSCoder.h>
#include <objects/behavior.h>
#include <objects/Coder.h>

@implementation NSGCoder

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
  [self encodeValueOfType:type at:address 
	withName:NULL];
}

- (void) encodeObject: (id)anObject;
{
  [self encodeObject:anObject
	withName:NULL];
}

- (void) encodeConditionalObject: (id)anObject;
{
  [self encodeObjectReference:anObject
	withName:NULL];
}

- (void) encodeBycopyObject: (id)anObject;
{
  [self encodeObjectBycopy:anObject 
	withName:NULL];
}

- (void) encodeRootObject: (id)rootObject;
{
  [self encodeRootObject:rootObject 
	withName:NULL];
}


// Decoding Data

- (void) decodeValueOfObjCType: (const char*)type
   at: (void*)address
{
  [self decodeValueOfType:type at:address 
	withName:NULL];
}

- (id) decodeObject;
{
  id o;
  /* xxx Warning!!! this won't work with encoded object references! 
     We need to fix this! (But how?) */
  [self decodeObjectAt:&o 
	withName:NULL];
  return o;
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
