/* Implementation of NSMutableData for GNUStep
   Copyright (C) 1995, 1996 Free Software Foundation, Inc.
   
   Written by:  Andrew Kachites McCallum <mccallum@gnu.ai.mit.edu>
   Date: April 1995
   
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

#include <foundation/NSData.h>

/* xxx Pretty messy.  Needs work. */

@implementation NSMutableData

+ (id) dataWithCapacity: (unsigned int)numBytes
{
  return [[[[NSGMutableData class] alloc] initWithCapacity:numBytes]
	  autorelease];
}

+ (id) dataWithLength: (unsigned int)length
{
  return [[[[NSGMutableData class] alloc] initWithLength:length]
	  autorelease];
}

- (id) initWithCapacity: (unsigned int)capacity
{
  return [self initWithBytesNoCopy:(*objc_malloc)(capacity)
	       length:capacity];
}

/* This is the designated initializer */
- (id) initWithBytesNoCopy: (void*)bytes
   length: (unsigned int)length
{
  /* xxx Eventually we'll have to be aware of malloc'ed memory
     vs vm_allocate'd memory, etc. */
  [self subclassResponsibility:_cmd];
  return nil;
}

- (id) initWithLength: (unsigned int)length
{
  [self initWithCapacity:length];
  memset([self bytes], 0, length);
  return self;
}

/* This method not in OpenStep */
- (unsigned) capacity
{
  [self subclassResponsibility:_cmd];
  return 0;
}

// Adjusting Capacity

- (void) increaseLengthBy: (unsigned int)extraLength
{
  [self setLength:[self length]+extraLength];
}

- (void) setLength: (unsigned int)length
{
  [self subclassResponsibility:_cmd];
}

- (void*) mutableBytes
{
  [self subclassResponsibility:_cmd];
  return NULL;
}

// Appending Data

- (void) appendBytes: (const void*)bytes
	      length: (unsigned int)length
{
  [self subclassResponsibility:_cmd];
}

- (void) appendData: (NSData*)other
{
  [self appendBytes:[other bytes]
	length:[other length]];
}


// Modifying Data

- (void) replaceBytesInRange: (NSRange)aRange
		   withBytes: (const void*)bytes
{
  memcpy([self bytes] + aRange.location, bytes, aRange.length);
}

- (void) resetBytesInRange: (NSRange)aRange
{
  memset([self bytes] + aRange.location, 0, aRange.length);
}

// Serializing Data

- (void) serializeAlignedBytesLength: (unsigned int)length
{
  [self notImplemented:_cmd];
}

- (void) serializeDataAt: (const void*)data
	      ofObjCType: (const char*)type
		 context: (id <NSObjCTypeSerializationCallBack>)callback
{
  [self notImplemented:_cmd];
}

- (void) serializeInt: (int)value
{
  [self notImplemented:_cmd];
}

- (void) serializeInt: (int)value
	      atIndex: (unsigned int)location
{
  [self notImplemented:_cmd];
}

- (void) serializeInts: (int*)intBuffer
		 count: (unsigned int)numInts
{
  [self notImplemented:_cmd];
}

- (void) serializeInts: (int*)intBuffer
		 count: (unsigned int)numInts
	       atIndex: (unsigned int)location
{
  [self notImplemented:_cmd];
}

@end

