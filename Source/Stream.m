/* Implementation of GNU Objective C byte stream
   Copyright (C) 1994, 1995, 1996 Free Software Foundation, Inc.
   
   Written by:  R. Andrew McCallum <mccallum@gnu.ai.mit.edu>
   Created: July 1994
   
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
#include <objects/Stream.h>
#include <objects/Coder.h>
#include <objects/Coder.h>
#include <objects/NSString.h>

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

- (int) writeFormat: (id <String>)format
	  arguments: (va_list)arg
{
  [self subclassResponsibility:_cmd];
  return 0;
}

- (int) writeFormat: (id <String>)format, ...
{
  [self subclassResponsibility:_cmd];
  return 0;
}

- (int) readFormat: (id <String>)format
	 arguments: (va_list)arg
{
  [self subclassResponsibility:_cmd];
  return 0;
}

- (int) readFormat: (id <String>)format, ...
{
  [self subclassResponsibility:_cmd];
  return 0;
}

- (void) writeLine: (id <String>)l
{
  const char *s = [l cStringNoCopy];
  [self writeBytes:s length:strlen(s)];
  [self writeBytes:"\n" length:1];
}

- (id <String>) readLine
{
  char *l;
  [self readFormat: @"%a[^\n]\n", &l];
  return [NSString stringWithCStringNoCopy:l];
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

- (void) setStreamPosition: (unsigned)i
{
  [self subclassResponsibility:_cmd];
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
