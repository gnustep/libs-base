/* Interface for GNU Objective C memory stream
   Copyright (C) 1994, 1995, 1996 Free Software Foundation, Inc.
   
   Written by:  R. Andrew McCallum <mccallum@gnu.ai.mit.edu>
   Date: July 1994
   
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

#ifndef __MemoryStream_h_GNUSTEP_BASE_INCLUDE
#define __MemoryStream_h_GNUSTEP_BASE_INCLUDE

#include <gnustep/base/preface.h>
#include <gnustep/base/Stream.h>
#include <gnustep/base/Streaming.h>

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
  int type;
  char *buffer;
  int size;
  int eofPosition;
  int prefix;
  int position;
}

- initWithCapacity: (unsigned)capacity
	    prefix: (unsigned)prefix;

- initWithSize: (unsigned)s;	/* For backwards compatibility, depricated */

- (unsigned) streamBufferPrefix;
- (unsigned) streamBufferLength; /* prefix + eofPosition */

/* xxx This interface will change */
- _initOnMallocBuffer: (char*)b
   size: (unsigned)s		/* size of malloc'ed buffer */
   eofPosition: (unsigned)l	/* length of buffer with data for reading */
   prefix: (unsigned)p		/* reset for this position */
   position: (unsigned)i;	/* current position for reading/writing */
@end

#endif /* __MemoryStream_h_GNUSTEP_BASE_INCLUDE */
