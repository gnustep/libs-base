/* Implementation of GNU Objective C byte stream
   Copyright (C) 1994, 1995, 1996 Free Software Foundation, Inc.
   
   Written by:  Andrew Kachites McCallum <mccallum@gnu.ai.mit.edu>
   Created: July 1994
   
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

#include <config.h>
#include <gnustep/base/preface.h>
#include <gnustep/base/Stream.h>
#include <gnustep/base/Coder.h>
#include <gnustep/base/Coder.h>
#include <gnustep/base/NSString.h>

@implementation Stream

/* This is the designated initializer. */
- init
{
  return [super init];
}

- (int) writeByte: (unsigned char)b
{
  return [self writeBytes:&b length:1];
}

- (int) readByte: (unsigned char*)b
{
  return [self readBytes:b length:1];
}

- (int) writeBytes: (const void*)b length: (int)l
{
  [self subclassResponsibility:_cmd];
  return 0;
}

- (int) readBytes: (void*)b length: (int)l
{
  [self subclassResponsibility:_cmd];
  return 0;
}

- (int) writeFormat: (NSString*)format
	  arguments: (va_list)arg
{
  [self subclassResponsibility:_cmd];
  return 0;
}

- (int) writeFormat: (NSString*)format, ...
{
  int ret;
  va_list ap;

  va_start(ap, format);
  ret = [self writeFormat: format arguments: ap];
  va_end(ap);
  return ret;
}

- (int) readFormat: (NSString*)format
	 arguments: (va_list)arg
{
  [self subclassResponsibility:_cmd];
  return 0;
}

- (int) readFormat: (NSString*)format, ...
{
  [self subclassResponsibility:_cmd];
  return 0;
}

- (void) writeLine: (NSString*)l
{
  const char *s = [l cStringNoCopy];
  [self writeBytes:s length:strlen(s)];
  [self writeBytes:"\n" length:1];
}

- (NSString*) readLine
{
  char *l;
  [self readFormat: @"%a[^\n]\n", &l];
  return [[[NSString alloc] initWithCStringNoCopy: l
			    length: strlen (l)
			    freeWhenDone: YES]
	   autorelease];
}

- (void) flushStream
{
  /* Do nothing. */
}

- (void) close
{
  /* Do nothing. */
}

- (BOOL) isClosed
{
  return NO;
}

- (void) setStreamPosition: (unsigned)i seekMode: (seek_mode_t)mode
{
  [self subclassResponsibility:_cmd];
}

- (void) setStreamPosition: (unsigned)i
{
  [self setStreamPosition: i seekMode: STREAM_SEEK_FROM_START];
}

- (void) rewindStream
{
  [self setStreamPosition:0];
}

- (unsigned) streamPosition
{
  [self subclassResponsibility:_cmd];
  return 0;
}

- (BOOL) isAtEof
{
  [self subclassResponsibility:_cmd];
  return YES;
}

- (BOOL) isWritable
{
  [self subclassResponsibility:_cmd];
  return NO;
}

- (void) encodeWithCoder: anEncoder
{
  [self subclassResponsibility:_cmd];
}

- initWithCoder: aDecoder
{
  [self subclassResponsibility:_cmd];
  return self;
}

@end
