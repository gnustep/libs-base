/* Protocol for GNU Objective C byte streams
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

#ifndef __Streaming_h__GNUSTEP_BASE_INCLUDE
#define __Streaming_h__GNUSTEP_BASE_INCLUDE

#include <base/preface.h>

@protocol Streaming <NSObject>

- (int) writeByte: (unsigned char)b;
- (int) readByte: (unsigned char*)b;

- (int) writeBytes: (const void*)b length: (int)l;
- (int) readBytes: (void*)b length: (int)l;

- (int) writeFormat: (NSString*)format, ...;
- (int) readFormat: (NSString*)format, ...;
- (int) writeFormat: (NSString*)format arguments: (va_list)arg;
- (int) readFormat: (NSString*)format arguments: (va_list)arg;

- (void) writeLine: (NSString*)l;
- (NSString*) readLine;

- (unsigned) streamPosition;
- (BOOL) isAtEof;
- (void) flushStream;

/* We must separate the idea of "closing" a stream and "deallocating" a
   stream because of delays in deallocation due to -autorelease. */
- (void) close;
- (BOOL) isClosed;

- (BOOL) isWritable;

@end

typedef enum _seek_mode_t
{
  STREAM_SEEK_FROM_START, 
  STREAM_SEEK_FROM_CURRENT, 
  STREAM_SEEK_FROM_END
} seek_mode_t;

@protocol SeekableStreaming

- (void) rewindStream;
- (void) setStreamPosition: (unsigned)i;
- (void) setStreamPosition: (unsigned)i seekMode: (seek_mode_t)mode;

@end


#endif /* __Streaming_h__GNUSTEP_BASE_INCLUDE */

