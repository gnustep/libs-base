/* Protocol for GNU Objective C byte streams
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

#ifndef __Streaming_h__OBJECTS_INCLUDE
#define __Streaming_h__OBJECTS_INCLUDE

#include <objects/stdobjects.h>

@protocol Streaming

- (int) writeByte: (unsigned char)b;
- (int) readByte: (unsigned char*)b;

- (int) writeBytes: (const void*)b length: (int)l;
- (int) readBytes: (void*)b length: (int)l;

- (int) writeFormat: (const char *)format, ...;
- (int) readFormat: (const char *)format, ...;

- (void) writeLine: (const char *)l;
- (char *) readLine;

- (void) rewindStream;
- (void) setStreamPosition: (unsigned)i;
- (unsigned) streamPosition;
- (BOOL) isAtEof;
- (void) flushStream;

- (BOOL) isWritable;

@end

#endif /* __Streaming_h__OBJECTS_INCLUDE */

