/* Implementation of GNU Objective C memory stream
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
   Software Foundation, Inc., 675 Mass Ave, Cambridge, MA 02139, USA.
   */ 

#include <config.h>
#include <gnustep/base/preface.h>
#include <gnustep/base/MemoryStream.h>
#include <gnustep/base/Coder.h>
#include <Foundation/NSData.h>
#include <Foundation/NSException.h>
#include <stdarg.h>

/* Deal with memchr: */
#if STDC_HEADERS || HAVE_STRING_H
#include <string.h>
/* An ANSI string.h and pre-ANSI memory.h might conflict.  */
#if !STDC_HEADERS && HAVE_MEMORY_H
#include <memory.h>
#endif /* not STDC_HEADERS and HAVE_MEMORY_H */
#define rindex strrchr
#define bcopy(s, d, n) memcpy ((d), (s), (n))
#define bcmp(s1, s2, n) memcmp ((s1), (s2), (n))
#define bzero(s, n) memset ((s), 0, (n))
#else /* not STDC_HEADERS and not HAVE_STRING_H */
#include <strings.h>
/* memory.h and strings.h conflict on some systems.  */
#endif /* not STDC_HEADERS and not HAVE_STRING_H */

#define DEFAULT_MEMORY_STREAM_SIZE 64

extern int
o_vscanf (void *stream, 
		int (*inchar_func)(void*), 
		void (*unchar_func)(void*,int),
		const char *format, va_list argptr);

static BOOL debug_memory_stream = NO;

/* A pretty stupid implementation based on realloc(), but it works for now. */

@implementation MemoryStream

+ (MemoryStream*)streamWithData: (id)anObject
{
  return [[[MemoryStream alloc] initWithData:anObject] autorelease];
}

- (id) data
{
  return data;
}

/* xxx This interface will change */
- _initOnMallocBuffer: (char*)b
	 freeWhenDone: (BOOL)f
		 size: (unsigned)s /* size of malloc'ed buffer */
	  eofPosition: (unsigned)l /* length of buffer with data for reading */
	       prefix: (unsigned)p /* never read/write before this position */
	     position: (unsigned)i /* current position for reading/writing */
{
  self = [super init];
  if (self)
    {
      if (b)
	if (f)
	  data = [[NSMutableData alloc] initWithBytesNoCopy: b length: s];
	else
	  data = [[NSMutableData alloc] initWithBytes: b length: s];
      else
	{
	  data = [[NSMutableData alloc] initWithCapacity: s];
	  if (data)
	    [data setLength: s];
	}

      if (data)
	{
	  prefix = p;
	  position = i;
	  eof_position = l;
	  isMutable = YES;
	  if ([data length] < prefix + MAX(position, eof_position))
	    [data setLength: prefix + MAX(position, eof_position)];
	}
      else
	{
	  [self release];
	  self = nil;
	}
    }
  return self;
}

- _initOnMallocBuffer: (char*)b
		 size: (unsigned)s /* size of malloc'ed buffer */
	  eofPosition: (unsigned)l /* length of buffer with data for reading */
	       prefix: (unsigned)p /* never read/write before this position */
	     position: (unsigned)i /* current position for reading/writing */
{
  return [self _initOnMallocBuffer: b
	       freeWhenDone: YES
	       size: s
	       eofPosition: l
	       prefix: p
	       position: i];
}

/* xxx This method will disappear. */
#if 0
- initWithSize: (unsigned)s
   prefix: (unsigned)p
   position: (unsigned)i
{
  return [self _initOnMallocBuffer: 0
	       freeWhenDone: YES
	       size: s
	       eofPosition: i
	       prefix: p
	       position: i];
}
#endif

- initWithCapacity: (unsigned)capacity
	    prefix: (unsigned)p
{
  return [self _initOnMallocBuffer: 0
	       freeWhenDone: YES
	       size: capacity
	       eofPosition: 0
	       prefix: p
	       position: 0];
}

- initWithCapacity: (unsigned)capacity
{
  return [self _initOnMallocBuffer: 0
	       freeWhenDone: YES
	       size: capacity
	       eofPosition: 0
	       prefix: 0
	       position: 0];
}

- initWithData: (id)anObject
{
  self = [super init];
  if (self)
    {
      if (anObject && [anObject isKindOfClass:[NSData class]])
        {
	  data = [anObject retain];
	  if ([data isKindOfClass:[NSMutableData class]])
	    isMutable = YES;
	  eof_position = [data length];
	  position = 0;
	  prefix = 0;
	}
      else
	{
	  [self dealloc];
	  self = nil;
	}
    }
  return self;
}

#if 0
- initWithSize: (unsigned)s
{
  return [self initWithCapacity:s];
}
#endif

- init
{
  return [self initWithCapacity: DEFAULT_MEMORY_STREAM_SIZE];
}

- (BOOL) isWritable
{
  return isMutable;
}

- (void) encodeWithCoder: anEncoder
{
  [self notImplemented:_cmd];
}

+ newWithCoder: aDecoder
{
  [self notImplemented:_cmd];
  return self;
}

- (id) mutableData
{
  if (isMutable)
    return data;
  return nil;
}

- (int) writeBytes: (const void*)b length: (int)l
{
  unsigned size;

  if (isMutable)
    {
      size = [data capacity];
      if (prefix+position+l > size)
	{
	  size = MAX(prefix+position+l, size*2);
	  [data setCapacity: size];
	}
      if (position+prefix+l > [data length])
	[data setLength: position+prefix+l];
      memcpy([data mutableBytes]+prefix+position, b, l);
      position += l;
      if (position > eof_position)
	eof_position = position;
      return l;
    }
  return 0;
}

- (int) readBytes: (void*)b length: (int)l
{
  if (position+l > eof_position)
    l = eof_position-position;
  memcpy(b, [data bytes]+prefix+position, l);
  position += l;
  return l;
}

- (NSString*) readLine
{
  char *nl = memchr([data bytes]+prefix+position, '\n', eof_position-position);
  char *ret = NULL;
  if (nl)
    {
      int len = nl-((char*)[data bytes])-prefix-position;
      ret = objc_malloc (len+1);
      strncpy(ret, ((char*)[data bytes])+prefix+position, len);
      ret[len] = '\0';
      position += len+1;
    }
  return [[[NSString alloc] initWithCStringNoCopy: ret 
			    length: strlen (ret)
			    freeWhenDone: YES]
	   autorelease];
}

/* Making these nested functions (which is what I'd like to do) is
   crashing the va_arg stuff in vscanf().  Why? */
#define MS ((MemoryStream*)s)

int outchar_func(void *s, int c)
{
  if (MS->isMutable)
    {
      if (MS->prefix + MS->position >= [MS->data capacity])
        return EOF;
      ((char*)[MS->data mutableBytes])[MS->prefix + MS->position++] = (char)c;
      return 1;
    }
  return EOF;
}

int inchar_func(void *s)
{
  if (MS->prefix + MS->position >= [MS->data length])
    return EOF;
  return (int) ((char*)[MS->data bytes])[MS->prefix + MS->position++];
}

void unchar_func(void *s, int c)
{
  if (MS->position > 0)
    MS->position--;
  if (MS->isMutable)
    ((char*)[MS->data mutableBytes])[MS->prefix + MS->position] = (char)c;
}

#if HAVE_VSPRINTF
- (int) writeFormat: (NSString*)format
	  arguments: (va_list)arg
{ 
  unsigned size;
  int ret;

  if (!isMutable)
    return 0;
  /* xxx Using this ugliness we at least let ourselves safely print
     formatted strings up to 128 bytes long.
     It's digusting, though, and we need to fix it. 
     Using GNU stdio streams would do the trick. 
     */
  size = [data capacity];
  if (size - (prefix + position) < 128)
    size = MAX(size+128, size*2);
  [data setLength: size];
  
  ret = VSPRINTF_LENGTH (vsprintf([data mutableBytes]+prefix+position,
				[format cString], arg));
  position += ret;
  /* xxx Make sure we didn't overrun our buffer.
     As per above kludge, this would happen if we happen to have more than
     128 bytes left in the buffer and we try to write a string longer than
     the num bytes left in the buffer. */
  NSAssert(prefix + position <= [data capacity], @"buffer overrun");
  if (position > eof_position)
    eof_position = position;
  [data setLength:eof_position + prefix];
  if (debug_memory_stream)
    {
      *(char*)([data mutableBytes]+prefix+position) = '\0';
      fprintf(stderr, "%s\n", (char*)[data mutableBytes]+prefix);
    }
  return ret;
}
#endif

- (int) readFormat: (NSString*)format, ...
{
  int ret;
  va_list ap;

  va_start(ap, format);
  ret = o_vscanf(self, inchar_func, unchar_func, 
		       [format cString], ap);
  va_end(ap);
  return ret;
}

- (void) setStreamPosition: (unsigned)i  seekMode: (seek_mode_t)mode
{
  switch (mode)
    {
    case STREAM_SEEK_FROM_START:
      position = i;
      break;
    case STREAM_SEEK_FROM_CURRENT:
      position += i;
      break;
    case STREAM_SEEK_FROM_END:
      position = eof_position + i;
      break;
    }
}

- (unsigned) streamPosition
{
  return position;
}

- (void) close
{
  [self flushStream];
}

- (void) dealloc
{
  [data release];
  [super dealloc];
}

- (BOOL) streamEof
{
  if (position == eof_position)
    return YES;
  else
    return NO;
}

- (unsigned) streamBufferCapacity
{
  if (isMutable)
    return [data capacity];
  return [data length];
}

- (char*) streamBuffer
{
  if (isMutable)
    return (char*)[data mutableBytes];
  return 0;
}

- (void) setStreamBufferCapacity: (unsigned)s
{
  if (isMutable)
    if (s > prefix + eof_position)
      [data setCapacity:s];
}

- (unsigned) streamEofPosition
{
  return eof_position;
}

- (void) setStreamEofPosition: (unsigned)i
{
  if (i < [data length] - prefix)
    eof_position = i;
}  

- (unsigned) streamBufferPrefix
{
  return prefix;
}

- (unsigned) streamBufferLength
{
  return prefix + eof_position;
}

@end
