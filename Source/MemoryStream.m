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

#include <gnustep/base/preface.h>
#include <gnustep/base/MemoryStream.h>
#include <gnustep/base/Coder.h>
#include <Foundation/NSException.h>
#include <stdarg.h>
#include <assert.h>

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

/* This could be done with a set of classes instead. */
enum {MALLOC_MEMORY_STREAM = 0, OBSTACK_MEMORY_STREAM, VM_MEMORY_STREAM};

enum {
  STREAM_READONLY = 0,
  STREAM_READWRITE,
  STREAM_WRITEONLY
};

#define DEFAULT_MEMORY_STREAM_SIZE 64

extern int
o_vscanf (void *stream, 
		int (*inchar_func)(void*), 
		void (*unchar_func)(void*,int),
		const char *format, va_list argptr);

static BOOL debug_memory_stream = NO;

/* A pretty stupid implementation based on realloc(), but it works for now. */

@implementation MemoryStream

/* xxx This interface will change */
- _initOnMallocBuffer: (char*)b
	 freeWhenDone: (BOOL)f
		 size: (unsigned)s /* size of malloc'ed buffer */
	  eofPosition: (unsigned)l /* length of buffer with data for reading */
	       prefix: (unsigned)p /* never read/write before this position */
	     position: (unsigned)i /* current position for reading/writing */
{
  [super init];
  buffer = b;
  size = s;
  prefix = p;
  position = i;
  eof_position = l;
  free_when_done = f;
  type = MALLOC_MEMORY_STREAM;
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
- initWithSize: (unsigned)s
   prefix: (unsigned)p
   position: (unsigned)i
{
  char *b;
  OBJC_MALLOC(b, char, s);
  return [self _initOnMallocBuffer:b 
	       freeWhenDone: YES
	       size: s
	       eofPosition: i
	       prefix: p
	       position: i];
}

- initWithCapacity: (unsigned)capacity
	    prefix: (unsigned)p
{
  return [self initWithSize: capacity
	       prefix: p
	       position: 0];
}

- initWithCapacity: (unsigned)capacity
{
  return [self initWithSize:capacity prefix:0 position:0];
}

- initWithSize: (unsigned)s
{
  return [self initWithCapacity:s];
}

- init
{
  return [self initWithCapacity: DEFAULT_MEMORY_STREAM_SIZE];
}

- (void) setFreeWhenDone: (BOOL)f
{
  free_when_done = f;
}

- (BOOL) isWritable
{
  return YES;
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

- (int) writeBytes: (const void*)b length: (int)l
{
  if (prefix+position+l > size)
    {
      size = MAX(prefix+position+l, size*2);
      buffer = objc_realloc (buffer, size);
    }
  memcpy(buffer+prefix+position, b, l);
  position += l;
  if (position > eof_position)
    eof_position = position;
  return l;
}

- (int) readBytes: (void*)b length: (int)l
{
  if (position+l > eof_position)
    l = eof_position-position;
  memcpy(b, buffer+prefix+position, l);
  position += l;
  return l;
}

- (NSString*) readLine
{
  char *nl = memchr(buffer+prefix+position, '\n', eof_position-position);
  char *ret = NULL;
  if (nl)
    {
      int len = nl-buffer-prefix-position;
      ret = objc_malloc (len+1);
      strncpy(ret, buffer+prefix+position, len);
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
  if (MS->prefix + MS->position >= MS->size)
    return EOF;
  MS->buffer[MS->prefix + MS->position++] = (char)c;
  return 1;
}

int inchar_func(void *s)
{
  if (MS->prefix + MS->position >= MS->size)
    return EOF;
  return (int) MS->buffer[MS->prefix + MS->position++];
}

void unchar_func(void *s, int c)
{
  if (MS->position > 0)
    MS->position--;
  MS->buffer[MS->prefix + MS->position] = (char)c;
}

#if HAVE_VSPRINTF
- (int) writeFormat: (NSString*)format
	  arguments: (va_list)arg
{
  int ret;

  /* xxx Using this ugliness we at least let ourselves safely print
     formatted strings up to 128 bytes long.
     It's digusting, though, and we need to fix it. 
     Using GNU stdio streams would do the trick. 
     */
  if (size - (prefix + position) < 128)
    [self setStreamBufferCapacity:size*2];

  ret = VSPRINTF_LENGTH (vsprintf(buffer+prefix+position,
				  [format cStringNoCopy], arg));
  position += ret;
  /* xxx Make sure we didn't overrun our buffer.
     As per above kludge, this would happen if we happen to have more than
     128 bytes left in the buffer and we try to write a string longer than
     the num bytes left in the buffer. */
  assert(prefix + position <= size);
  if (position > eof_position)
    eof_position = position;
  if (debug_memory_stream)
    {
      *(buffer+prefix+position) = '\0';
      fprintf(stderr, "%s\n", buffer+prefix);
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
		       [format cStringNoCopy], ap);
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
  if (free_when_done)
    OBJC_FREE(buffer);
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
  return size;
}

- (char*) streamBuffer
{
  return buffer;
}

- (void) setStreamBufferCapacity: (unsigned)s
{
  if (s > prefix + eof_position)
    {
      buffer = objc_realloc (buffer, s);
      size = s;
    }
}

- (unsigned) streamEofPosition
{
  return eof_position;
}

- (void) setStreamEofPosition: (unsigned)i
{
  if (i < size)
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
