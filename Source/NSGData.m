/* Concrete NSData for GNUStep based on GNU MemoryStream class
   Copyright (C) 1995 Free Software Foundation, Inc.
   
   Written by:  R. Andrew McCallum <mccallum@gnu.ai.mit.edu>
   Date: April 1995
   
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
#include <foundation/NSGData.h>
#include <objects/NSCoder.h>
#include <objects/behavior.h>
#include <objects/MemoryStream.h>
#include <foundation/NSString.h>

/* This from objects/MemoryStream.h */
@interface NSGData (MemoryStream)
- _initOnMallocBuffer: (char*)b
   size: (unsigned)s		/* size of malloc'ed buffer */
   eofPosition: (unsigned)l	/* length of buffer with data for reading */
   prefix: (unsigned)p		/* reset for this position */
   position: (unsigned)i;	/* current position for reading/writing */
@end

@implementation NSGData

+ (void) initialize
{
  static int done = 0;
  if (!done)
    {
      done = 1;
      class_add_behavior([NSGData class], [MemoryStream class]);
    }
}

/* This is the designated initializer */
- (id) initWithBytesNoCopy: (void*)bytes
   length: (unsigned int)length
{
  [self _initOnMallocBuffer:bytes
	size:length
	eofPosition:length
	prefix:0
	position:0];
  return self;
}

- (const void*) bytes
{
  return buffer;
}

- (unsigned int) length
{
  return eofPosition;
}

// Storing Data

- (BOOL) writeToFile: (NSString*)path
   atomically: (BOOL)useAuxiliaryFile
{
  /* xxx This currently ignores useAuxiliaryFile. */
  int written;
  FILE* fp = fopen([path cString], "w");
  assert (fp);			/* This should raise NSException instead. */
  written = fwrite(buffer+prefix, 1, eofPosition, fp);
  assert (eofPosition == written);
  fclose(fp);
  return YES;
}

@end


@implementation NSGMutableData

+ (void) initialize
{
  static int done = 0;
  if (!done)
    {
      done = 1;
      class_add_behavior([NSGMutableData class], [NSGData class]);
    }
}

/* Make sure we do this, and not what MemoryStream says. */
- (id) initWithCapacity: (unsigned int)capacity
{
  return [self initWithBytesNoCopy:(*objc_malloc)(capacity)
	       length:capacity];
}

/* This is the designated initializer.  The behavior comes from NSGData. 
   - (id) initWithBytesNoCopy: (void*)bytes
   length: (unsigned int)length */

- (unsigned) capacity
{
  return size;
}

- (void) setLength: (unsigned int)length
{
  [self setStreamBufferCapacity:length];
}

- (void*) mutableBytes
{
  return buffer;
}

- (void) appendBytes: (const void*)bytes
	      length: (unsigned int)length
{
  [self writeBytes:bytes length:length];
}

@end
