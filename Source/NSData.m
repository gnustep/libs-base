/* Stream of bytes class for serialization and persistance in GNUStep
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

#include <objects/stdobjects.h>
#include <Foundation/NSData.h>
#include <Foundation/NSString.h>
#include <Foundation/NSGData.h>

/* xxx Pretty messy.  Needs work. */

@implementation NSData

// Allocating and Initializing a Data Object

+ (id) data
{
  return [[[NSGData alloc] init] 
	  autorelease];
}

+ (id) dataWithBytes: (const void*)bytes
   length: (unsigned int)length
{
  return [[[NSGData alloc] initWithBytes:bytes length:length] 
	  autorelease];
}

+ (id) dataWithBytesNoCopy: (void*)bytes
   length: (unsigned int)length
{
  return [[[self alloc] initWithBytesNoCopy:bytes length:length]
	  autorelease];
}

+ (id)dataWithContentsOfFile: (NSString*)path
{
  return [self notImplemented:_cmd];
}

+ (id) dataWithContentsOfMappedFile: (NSString*)path
{
  return [self notImplemented:_cmd];
}

- (id) initWithBytes: (const void*)bytes
   length: (unsigned int)length
{
  /* xxx Eventually we'll have to be aware of malloc'ed memory
     vs vm_allocate'd memory, etc. */
  void *buf = NSZoneMalloc([self zone], length);
  memcpy(buf, bytes, length);
  return [self initWithBytesNoCopy:buf length:length];
}

/* This is the designated initializer for NSData */
- (id) initWithBytesNoCopy: (void*)bytes
   length: (unsigned int)length
{
  /* xxx Eventually we'll have to be aware of malloc'ed memory
     vs vm_allocate'd memory, etc. */
  [self notImplemented:_cmd];
  return nil;
}

- init
{
  /* xxx Is this right? */
  return [self initWithBytesNoCopy:NULL
	       length:0];
}

- (id) initWithContentsOfFile: (NSString*)path
{
  return [self notImplemented:_cmd];
}

- (id) initWithContentsOfMappedFile: (NSString*)path;
{
  return [self notImplemented:_cmd];
}

- (id) initWithData: (NSData*)data
{
  return [self initWithBytes:[data bytes] length:[data length]];
}


// Accessing Data 

- (const void*) bytes
{
  [self notImplemented:_cmd];
  return NULL;
}

- (NSString*) description
{
  /* xxx worry about escaping, NSString does that? */
  return [NSString stringWithCString:[self bytes] length:[self length]];
}

- (void)getBytes: (void*)buffer
{
  [self getBytes:buffer length:[self length]];
}

- (void)getBytes: (void*)buffer
   length: (unsigned int)length
{
  [self getBytes:buffer range:((NSRange){0, length})];
}

- (void)getBytes: (void*)buffer
   range: (NSRange)aRange
{
  /* xxx need to do range checking */
  memcpy(buffer, [self bytes] + aRange.location, aRange.length);
}

- (NSData*) subdataWithRange: (NSRange)aRange
{
  [self notImplemented:_cmd];
  return nil;
}

- (BOOL) isEqual: anObject
{
  if ([anObject isKindOf:[NSData class]])
    return [self isEqualToData:anObject];
  return NO;
}

// Querying a Data Object
- (BOOL) isEqualToData: (NSData*)other;
{
  int len;
  if ((len = [self length]) != [other length])
    return NO;
  return (memcmp([self bytes], [other bytes], len) ? NO : YES);
}

- (unsigned int)length;
{
  [self notImplemented:_cmd];
  return 0;
}


// Storing Data

- (BOOL) writeToFile: (NSString*)path
   atomically: (BOOL)useAuxiliaryFile
{
  [self notImplemented:_cmd];
  return NO;
}


// Deserializing Data

- (unsigned int) deserializeAlignedBytesLengthAtCursor: (unsigned int*)cursor
{
  [self notImplemented:_cmd];
  return 0;
}

- (void)deserializeBytes: (void*)buffer
   length: (unsigned int)bytes
   atCursor: (unsigned int*)cursor
{
  [self notImplemented:_cmd];
}

- (void)deserializeDataAt: (void*)data
   ofObjCType: (const char*)type
   atCursor: (unsigned int*)cursor
   context: (id <NSObjCTypeSerializationCallBack>)callback
{
  return;
}


- (int) deserializeIntAtCursor: (unsigned int*)cursor
{
  [self notImplemented:_cmd];
  return 0;
}

- (int) deserializeIntAtLocation: (unsigned int)location
{
  [self notImplemented:_cmd];
  return 0;
}

- (void)deserializeInts: (int*)intBuffer
   count: (unsigned int)numInts
   atCursor: (unsigned int*)cursor
{
  [self notImplemented:_cmd];
}

- (void)deserializeInts: (int*)intBuffer
{
  [self notImplemented:_cmd];
}

- (id) copyWithZone: (NSZone*)zone
{
  [self notImplemented:_cmd];
  return nil;
}

- (id) mutableCopyWithZone: (NSZone*)zone
{
  [self notImplemented:_cmd];
  return nil;
}

@end


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
  [self notImplemented:_cmd];
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
  [self notImplemented:_cmd];
  return 0;
}

// Adjusting Capacity

- (void) increaseLengthBy: (unsigned int)extraLength
{
  [self setLength:[self length]+extraLength];
}

- (void) setLength: (unsigned int)length
{
  [self notImplemented:_cmd];
}

- (void*) mutableBytes
{
  [self notImplemented:_cmd];
  return NULL;
}

// Appending Data

- (void) appendBytes: (const void*)bytes
	      length: (unsigned int)length
{
  [self notImplemented:_cmd];
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

