/* Interface for NSData for GNUStep
   Copyright (C) 1994 NeXT Computer, Inc.
   
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

#ifndef __NSData_h_OBJECTS_INCLUDE
#define __NSData_h_OBJECTS_INCLUDE

#include <Foundation/NSObject.h>
#include <Foundation/NSRange.h>
#include <Foundation/NSSerialization.h>

@interface NSData : NSObject <NSCopying, NSMutableCopying>

// Allocating and Initializing a Data Object

+ (id)data;
+ (id)dataWithBytes: (const void*)bytes
   length: (unsigned int)length;
+ (id)dataWithBytesNoCopy: (void*)bytes
   length: (unsigned int)length;
+ (id)dataWithContentsOfFile: (NSString*)path;
+ (id)dataWithContentsOfMappedFile: (NSString*)path;
- (id)initWithBytes: (const void*)bytes
   length: (unsigned int)length;
- (id)initWithBytesNoCopy: (void*)bytes
                   length: (unsigned int)length;
- (id)initWithContentsOfFile: (NSString*)path;
- (id)initWithContentsOfMappedFile: (NSString*)path;
- (id)initWithData: (NSData*)data;

// Accessing Data 

- (const void*)bytes;
- (NSString*)description;
- (void)getBytes: (void*)buffer;
- (void)getBytes: (void*)buffer
   length: (unsigned int)length;
- (void)getBytes: (void*)buffer
   range: (NSRange)aRange;
- (NSData*)subdataWithRange: (NSRange)aRange;

// Querying a Data Object

- (BOOL)isEqualToData: (NSData*)other;
- (unsigned int)length;

// Storing Data

- (BOOL)writeToFile: (NSString*)path
         atomically: (BOOL)useAuxiliaryFile;

// Deserializing Data

- (unsigned int)deserializeAlignedBytesLengthAtCursor: (unsigned int*)cursor;
- (void)deserializeBytes: (void*)buffer
   length: (unsigned int)bytes
   atCursor: (unsigned int*)cursor;
- (void)deserializeDataAt: (void*)data
   ofObjCType: (const char*)type
   atCursor: (unsigned int*)cursor
   context: (id <NSObjCTypeSerializationCallBack>)callback;
- (int)deserializeIntAtCursor: (unsigned int*)cursor;
- (int)deserializeIntAtLocation: (unsigned int)location;
- (void)deserializeInts: (int*)intBuffer
   count: (unsigned int)numInts
   atCursor: (unsigned int*)cursor;
- (void)deserializeInts: (int*)intBuffer;

@end


@interface NSMutableData :  NSData

+ (id) dataWithCapacity: (unsigned int)numBytes;
+ (id) dataWithLength: (unsigned int)length;
- (id) initWithCapacity: (unsigned int)capacity;
- (id) initWithLength: (unsigned int)length;

// Adjusting Capacity

- (void) increaseLengthBy: (unsigned int)extraLength;
- (void) setLength: (unsigned int)length;
- (void*) mutableBytes;

// Appending Data

- (void) appendBytes: (const void*)bytes
	      length: (unsigned int)length;
- (void) appendData: (NSData*)other;

// Modifying Data

- (void) replaceBytesInRange: (NSRange)aRange
		   withBytes: (const void*)bytes;
- (void) resetBytesInRange: (NSRange)aRange;

// Serializing Data

- (void) serializeAlignedBytesLength: (unsigned int)length;
- (void) serializeDataAt: (const void*)data
	      ofObjCType: (const char*)type
		 context: (id <NSObjCTypeSerializationCallBack>)callback;
- (void) serializeInt: (int)value;
- (void) serializeInt: (int)value
	      atIndex: (unsigned int)location;
- (void) serializeInts: (int*)intBuffer
		 count: (unsigned int)numInts;
- (void) serializeInts: (int*)intBuffer
		 count: (unsigned int)numInts
	       atIndex: (unsigned int)location;

@end

/*
  Local Variables:
  mode: ObjC
  End:
  */

#endif /* __NSData_h_OBJECTS_INCLUDE */
