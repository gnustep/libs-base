/* Implementation of GNU Objective C byte stream
   Copyright (C) 1994 Free Software Foundation, Inc.
   
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

#include <objects/stdobjects.h>
#include <objects/Stream.h>
#include <objects/Coder.h>
#include <objects/Coder.h>

@implementation Stream

- initWithMode: (int)m
{
  [super init];
  mode = m;
  return self;
}

- init
{
  return [self initWithMode:STREAM_READWRITE];
}

#if 0
- (void) close
{
  /* nothing needed */
}
#endif

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
  [self notImplemented:_cmd];
  return 0;
}

- (int) readBytes: (void*)b length: (int)l
{
  [self notImplemented:_cmd];
  return 0;
}

- (int) writeFormat: (const char *)format, ...
{
  [self notImplemented:_cmd];
  return 0;
}

- (int) readFormat: (const char *)format, ...
{
  [self notImplemented:_cmd];
  return 0;
}

- (void) writeLine: (const char *)l
{
  [self writeFormat:"%s\n", l];
}

/* This malloc's the buffer pointed to by the return value */
- (char *) readLine
{
  char *l;
  [self readFormat:"%a[^\n]\n", &l];
  return l;
}

- (void) rewindStream
{
  [self setStreamPosition:0];
}

- (void) flushStream
{
  [self notImplemented:_cmd];
}

- (void) setStreamPosition: (unsigned)i
{
  [self notImplemented:_cmd];
}

- (unsigned) streamPosition
{
  [self notImplemented:_cmd];
  return 0;
}

- (BOOL) streamEof
{
  [self notImplemented:_cmd];
  return YES;
}

- (int) streamMode
{
  return mode;
}

#if 0 /* Put this into a StreamStream class? */
- initWithStream: (Stream *)s mode: (int)m
{
  if (m == STREAM_READONLY && [s streamMode] == STREAM_READONLY
      || m == STREAM_WRITEONLY && [s streamMode] == STREAM_WRITEONLY)
    [self error:"Streams read/write modes conflict"];
  [super initWithMode:m];
  otherStream = s;
  return self;
}
#endif

- (void) encodeWithCoder: (Coder*)anEncoder
{
  [self notImplemented:_cmd];
}

+ newWithCoder: (Coder*)aDecoder
{
  [self notImplemented:_cmd];
  return self;
}

@end
