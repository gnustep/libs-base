/* Interface for NSData for GNUStep
   Copyright (C) 1995 Free Software Foundation, Inc.

   Written by:  Andrew Kachites McCallum <mccallum@gnu.ai.mit.edu>
   Date: 1995
   
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

#ifndef __NSData_h_GNUSTEP_BASE_INCLUDE
#define __NSData_h_GNUSTEP_BASE_INCLUDE

#include <Foundation/NSObject.h>
#include <Foundation/NSRange.h>
#include <Foundation/NSSerialization.h>

@interface NSData : NSObject <NSCoding, NSCopying, NSMutableCopying>

// Allocating and Initializing a Data Object

+ (id)data;
+ (id)dataWithBytes: (const void*)bytes
	     length: (unsigned int)length;
+ (id)dataWithBytesNoCopy: (void*)bytes
   		   length: (unsigned int)length;
+ (id)dataWithContentsOfFile: (NSString*)path;
+ (id)dataWithContentsOfMappedFile: (NSString*)path;
+ (id)dataWithData: (NSData*)data;
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
- (int)deserializeIntAtIndex: (unsigned int)location;
- (void)deserializeInts: (int*)intBuffer
                  count: (unsigned int)numInts
               atCursor: (unsigned int*)cursor;
- (void)deserializeInts: (int*)intBuffer
                  count: (unsigned int)numInts
                atIndex: (unsigned int)index;

@end

@interface NSData (GNUstepExtensions)
+ (id) dataWithShmID: (int)anID length: (unsigned) length;
+ (id) dataWithSharedBytes: (const void*)bytes length: (unsigned) length;
+ (id) dataWithStaticBytes: (const void*)bytes length: (unsigned) length;
/*
 *	-initWithBytesNoCopy:length:fromZone:
 *	The GNUstep designated initialiser for normal data objects - lets
 *	the class know what zone the data comes from, so we can avoid the
 *	overhead of an NSZoneFromPointer() call.
 *	A zone of zero denotes static memory rather than malloced memory.
 */
- (id) initWithBytesNoCopy: (void*)bytes
		    length: (unsigned)length
		  fromZone: (NSZone*)zone;
/*
 *	-relinquishAllocatedBytes
 *	For an NSData object with a malloced buffer, returns that buffer and
 *	removes it from the NSData object, otherwise returns a nul pointer.
 *	Use with care, preferably when no-one else has retained the NSData
 *	object - or they will find it's buffer disappearing unexpectedly.
 *	Once you have used this method, you own the malloced data and are
 *	responsible for freeing it.
 *	NB. While this buffer is guaranteed to be freeable by NSZoneFree(),
 *	it's not necessarily safe to pass it to free()/objc_free() and
 *	friends.  If you wish to pass the buffer to code that might use
 *	free() or realloc(), you should use the
 *	-relinquishAllocatedBytesFromZone: method instead - this method
 *	will only relinquich the buffer if it was allocated from the
 *	specified zone (a zone of 0 disables this checking).
 */
- (void*) relinquishAllocatedBytes;
- (void*) relinquishAllocatedBytesFromZone: (NSZone*)aZone;
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
- (void) setData: (NSData*)data;

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

@interface NSMutableData (GNUstepExtensions)
- (unsigned int) capacity;
- (id) setCapacity: (unsigned int)newCapacity;
- (int) shmID;
@end

/*
  Local Variables:
  mode: ObjC
  End:
  */

#endif /* __NSData_h_GNUSTEP_BASE_INCLUDE */
