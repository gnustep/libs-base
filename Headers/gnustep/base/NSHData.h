/* Interface for GNU Objective C NSData classes
   Copyright (C) 1997 Free Software Foundation, Inc.

   Written by:  Richard Frith-Macdonald <richard@brainstorm.co.uk>
   Date: July 1997

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

#ifndef __NSHData_h
#define __NSHData_h

#include <gnustep/base/preface.h>
#include <gnustep/base/Streaming.h>
#include <gnustep/base/MemoryStream.h>
#include <Foundation/NSObject.h>
#include <Foundation/NSRange.h>
#include <Foundation/NSData.h>
#include <Foundation/NSSerialization.h>

typedef	enum {
    MALLOC_DATA = 0,	// This is data allocated by malloc.
    STATIC_DATA,	// This is data from somewhere else.
    SHARED_DATA,	// This is data allocated by shmget.
    MAPPED_DATA		// This is a memory mapped file.
} NSDataType;

@interface NSHData : NSData <MemoryStreaming,SeekableStreaming>
{
  NSDataType	type;
  char*		buffer;
  int		shm_id;
  unsigned int	size;
  unsigned int	eof_position;
  unsigned int	position;
}

+ (id) data;
+ (id) dataWithBytes: (const void*)bytes
	      length: (unsigned int)length;
+ (id) dataWithBytesNoCopy: (void*)bytes
		    length: (unsigned int)length;
+ (id) dataWithContentsOfFile: (NSString*)path;
+ (id) dataWithContentsOfMappedFile: (NSString*)path;
+ (id) dataWithData: (NSData*)other;

- (const void*)bytes;
- (NSString*) description;
- (void) getBytes: (void*)buffer;
- (void) getBytes: (void*)buffer
	   length: (unsigned int)length;
- (void) getBytes: (void*)buffer
	    range: (NSRange)aRange;

- (id) initWithBytes: (const void*)bytes
	      length: (unsigned int)length;
- (id) initWithBytesNoCopy: (void*)bytes
                    length: (unsigned int)length;
- (id) initWithContentsOfFile: (NSString*)path;
- (id) initWithContentsOfMappedFile: (NSString*)path;
- (id) initWithData: (NSData*)data;

- (BOOL) isEqualToData: (NSData*)other;
- (unsigned int) length;
- (NSData*)subdataWithRange: (NSRange)aRange;
- (BOOL) writeToFile: (NSString*)path
          atomically: (BOOL)useAuxiliaryFile;


- (unsigned int) deserializeAlignedBytesLengthAtCursor: (unsigned int*)cursor;
- (void) deserializeBytes: (void*)buffer
		   length: (unsigned int)bytes
		 atCursor: (unsigned int*)cursor;
- (void) deserializeDataAt: (void*)data
	        ofObjCType: (const char*)type
		  atCursor: (unsigned int*)cursor
		   context: (id <NSObjCTypeSerializationCallBack>)callback;
- (int) deserializeIntAtCursor: (unsigned int*)cursor;
- (int) deserializeIntAtIndex: (unsigned int)location;
- (void) deserializeInts: (int*)intBuffer
		   count: (unsigned int)numInts
		atCursor: (unsigned int*)cursor;
- (void) deserializeInts: (int*)intBuffer
		   count: (unsigned int)numInts
		 atIndex: (unsigned int)index;


/* GNUstep extensions to NSData primarily for the Streaming prototcol.
   The write operations have no effect on an NSData but work as expected
   for NSMutableData objects.
 */
+ (void) setVMThreshold:(unsigned int)size;
- (void) close;
- (void) flushStream;

/* How the internal designated initialiser works -
    if 't' is MALLOC_DATA
	if 'f' is YES
	    We set 'buffer' to 'b'
	else
	    We set 'buffer' to point to memory allocated of the size
	    specified in 's', and copy 'l' bytes from 'b' or clear
	    'l' bytes if 'b' is nul.  We set 'f' to YES.

    if 't' is STATIC_DATA
	If 'b' is zero
	    We set 'buffer' to "" and set 'size' to zero.
	else
	    We set 'buffer' to 'b'

    if 't' is SHARED_DATA
	If 'm' is non-zero
	    We attach to the specified chunk of shared memory and set
	    'buffer' to point to it.  We set 'size' to the size of the
	    shared memory.  We either clear the first 'l' bytes or we
	    copy them from 'b' if 'b' is not nul.
	else
	    We create a chunk of shared memory of at least 'size' bytes,
	    set 'buffer' to point to it, and set 'size' to the size of
	    the shared memory.
	    We either clear the first 'l' bytes or we copy them from 'b'
	    if 'b' is not nul.

    if 't' is MAPPED_DATA
	We map the file 'n' into memory and set 'buffer' to point to it.

 */
- initOnBuffer: (void*)b		/* data area or nul pointer	*/
	  size: (unsigned)s		/* size of the data area	*/
          type: (NSDataType)t		/* type of storage to use	*/
     sharedMem: (int)m			/* ID of shared memory segment	*/
      fileName: (NSString*)n		/* name of mmap file.		*/
   eofPosition: (unsigned)l		/* length of data for reading	*/
      position: (unsigned)i		/* current pos for read/write	*/
        noCopy: (BOOL)f;		

- initWithCapacity: (unsigned int)capacity;
- (BOOL) isAtEof;
- (BOOL) isClosed;
- (BOOL) isWritable;

- (int) readByte: (unsigned char*)b;
- (int) readBytes: (void*)b length: (int)l;
- (int) readFormat: (NSString*)format, ...;
- (int) readFormat: (NSString*)format arguments: (va_list)arg;
- (NSString*) readLine;

- (void) rewindStream;

- (void) setFreeWhenDone: (BOOL)f;
- (void) setStreamBufferCapacity: (unsigned)s;
- (void) setStreamEofPosition: (unsigned)i;
- (void) setStreamPosition: (unsigned)i;
- (void) setStreamPosition: (unsigned)i seekMode: (seek_mode_t)mode;

- (char*) streamBuffer;		/* Returns null for an NSData object. */
- (unsigned) streamBufferLength;
- (unsigned) streamEofPosition;
- (unsigned) streamPosition;
- (unsigned int) vmThreshold;

/* The following write operations have no effect on an NSData object. */
- (int) writeByte: (unsigned char)b;
- (int) writeBytes: (const void*)b length: (int)l;
- (int) writeFormat: (NSString*)format, ...;
- (int) writeFormat: (NSString*)format arguments: (va_list)arg;
- (void) writeLine: (NSString*)l;
@end

@interface NSHMutableData : NSHData
{
  int		vm_threshold;
}

+ (id) dataWithCapacity: (unsigned int)numBytes;
+ (id) dataWithLength: (unsigned int)length;

- (void) appendBytes:(const void*)bytes
	      length:(unsigned int)length;
- (void) appendData:(NSData*)other;
- (void) increaseLengthBy:(unsigned int)length;
- (id) initWithLength: (unsigned int)length;
- (void*) mutableBytes;
- (void) replaceBytesInRange: (NSRange)aRange
                   withBytes: (const void*)bytes;
- (void) resetBytesInRange: (NSRange)aRange;
- (void) setData:(NSData*)other;
- (void) setLength:(unsigned int)length;
- (void) setVMThreshold:(unsigned int)size;

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

- (void) increaseCapacityBy:(unsigned int)length;
@end

#endif /* __NSHData_h */
