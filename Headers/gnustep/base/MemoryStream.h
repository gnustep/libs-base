/* Interface for GNU Objective C memory stream
   Copyright (C) 1994, 1995, 1996 Free Software Foundation, Inc.
   
   Written by:  Andrew Kachites McCallum <mccallum@gnu.ai.mit.edu>
   Date: July 1994
   
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
   Software Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA 02111 USA.
   */ 

/*
   Modified by:  Richard Frith-Macdonald <richard@brainstorm.co.uk>
   Date: September 1997

   Modifications to use NSData and NSMutable data objects to hold data.
*/

#ifndef __MemoryStream_h_GNUSTEP_BASE_INCLUDE
#define __MemoryStream_h_GNUSTEP_BASE_INCLUDE

#include <base/preface.h>
#include <base/Stream.h>
#include <base/Streaming.h>

/* This protocol is preliminary and may change.
   This also may get pulled out into a separate .h file. */

@protocol MemoryStreaming <Streaming>

- initWithCapacity: (unsigned)capacity;

- (void) setStreamBufferCapacity: (unsigned)s;

- (char*) streamBuffer;
- (unsigned) streamBufferCapacity;
- (unsigned) streamEofPosition;

@end

@interface MemoryStream : Stream <MemoryStreaming>
{
  id data;
  int prefix;
  int position;
  int eof_position;
  BOOL isMutable;
}

+ (MemoryStream*)streamWithData: (id)anObject;

- initWithCapacity: (unsigned)capacity
	    prefix: (unsigned)prefix;
- initWithData: (id)anObject;

#if 0
- initWithSize: (unsigned)s;	/* For backwards compatibility, depricated */
#endif

- (id) data;
- (id) mutableData;
- (unsigned) streamBufferPrefix;
- (unsigned) streamBufferLength; /* prefix + eofPosition */

/* xxx This interface will change */
- _initOnMallocBuffer: (char*)b
   size: (unsigned)s		/* size of malloc'ed buffer */
   eofPosition: (unsigned)l	/* length of buffer with data for reading */
   prefix: (unsigned)p		/* reset for this position */
   position: (unsigned)i;	/* current position for reading/writing */
- _initOnMallocBuffer: (char*)b
   freeWhenDone: (BOOL)f
   size: (unsigned)s		/* size of malloc'ed buffer */
   eofPosition: (unsigned)l	/* length of buffer with data for reading */
   prefix: (unsigned)p		/* reset for this position */
   position: (unsigned)i;	/* current position for reading/writing */
@end

#endif /* __MemoryStream_h_GNUSTEP_BASE_INCLUDE */
