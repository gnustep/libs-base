/* Implementation of GNU Objective C stdio stream
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

#ifndef _REENTRANT
#define _REENTRANT
#endif

#include <config.h>
#include <base/preface.h>
#include <base/StdioStream.h>
#include <base/Coder.h>
#include <Foundation/NSException.h>
#include <Foundation/NSDebug.h>
#include <stdarg.h>
#include <string.h>
#include <unistd.h>   /* SEEK_* on SunOS 4 */

#ifdef __WIN32__
#define fdopen _fdopen
#endif

enum {
  STREAM_READONLY = 0,
  STREAM_READWRITE,
  STREAM_WRITEONLY
};

extern int
o_vscanf (void *stream, 
		int (*inchar_func)(void*), 
		void (*unchar_func)(void*,int),
		const char *format, va_list argptr);

@implementation StdioStream

+ standardIn
{
  static id stdinStream = nil;

  if (!stdinStream)
    stdinStream = [[self alloc] initWithFilePointer:stdin fmode:"r"];
  return stdinStream;
}

+ standardOut
{
  static id stdoutStream = nil;

  if (!stdoutStream)
    stdoutStream = [[self alloc] initWithFilePointer:stdout fmode:"w"];
  return stdoutStream;
}

+ standardError
{
  static id stderrStream = nil;

  if (!stderrStream)
    stderrStream = [[self alloc] initWithFilePointer:stderr fmode:"w"];
  return stderrStream;
}

+ streamWithFilename: (NSString*)name fmode: (const char *)m
{
  return [[[self alloc]
	    initWithFilename: name fmode: m]
	   autorelease];
}

- initWithFilePointer: (FILE*)afp fmode: (const char *)mo
{
#if 0
  /* xxx Is this portable?  I don't think so. 
     How do I find out if a FILE* is open for reading/writing?
     I want to get rid of the "mode" instance variable. */
  if (afp->_flag & _IOREAD) 
    mode = STREAM_READONLY;
  else if (afp->_flag & _IOWRT) 
    mode = STREAM_WRITEONLY;
  else 
    mode = STREAM_READWRITE;
#else
  if (!strcmp(mo, "rw"))
    mode = STREAM_READWRITE;
  else if (*mo == 'r')
    mode = STREAM_READONLY;
  else if (*mo == 'w')
    mode = STREAM_WRITEONLY;
#endif
  [super init];
  fp = afp;
  return self;
}

- initWithFilename: (NSString*)name fmode: (const char *)m
{
  FILE *afp = fopen([name cString], (char*)m);
  if (!afp)
    {
      id message;

      message = [[NSString alloc] initWithFormat: @"Stream: %s",
		strerror(errno)];
      NSLog(message);
      [message release];
      [super dealloc];
      return nil;
    }
  return [self initWithFilePointer:afp fmode:m];
}

- initWithFileDescriptor: (int)fd fmode: (const char *)m
{
  FILE *afp = fdopen(fd, (char*)m);
  if (!afp)
    {
      id message;

      message = [[NSString alloc] initWithFormat: @"Stream: %s",
		strerror(errno)];
      NSLog(message);
      [message release];
      [super dealloc];
      return nil;
    }
  return [self initWithFilePointer:afp fmode:m];
}

- initWithPipeTo: (NSString*) systemCommand
{
#ifdef __WIN32__
  return nil;
#else
  return [self initWithFilePointer:
	       popen([systemCommand cString], "w")
	       fmode:"w"];
#endif
}

- initWithPipeFrom: (NSString*) systemCommand
{
#ifdef __WIN32__
  return nil;
#else
  return [self initWithFilePointer:
	       popen([systemCommand cString], "r")
	       fmode:"r"];
#endif
}

- init
{
  return [self initWithFilePointer:stdout fmode:"w"];
}

- (int) writeBytes: (const void*)b length: (int)len
{
  int ret = fwrite (b, 1, len, fp);
  if (ferror(fp))
    {
      [NSException raise: StreamException
        format: @"%s", strerror(errno)];
    }
  else if (ret != len)
    {
      [NSException raise: StreamException
        format: @"Write bytes differ"];
    }
  return ret;
}

- (int) readBytes: (void*)b length: (int)len
{
  int ret = fread (b, 1, len, fp);
  if (ferror(fp))
    {
      [NSException raise: StreamException
        format: @"%s", strerror(errno)];
    }
  return ret;
}

- (int) writeFormat: (NSString*)format
	  arguments: (va_list)arg
{
  return vfprintf(fp, [format cString], arg);
}

static int
stdio_inchar_func(void *s)
{
  return getc((FILE*)s);
}
static void
stdio_unchar_func(void *s, int c)
{
   ungetc(c, (FILE*)s);
}

- (int) readFormat: (NSString*)format, ...
{
  int ret;
  va_list ap;
/* Wow.  Why does putting in these nested functions crash the
   va_arg stuff in vscanf? */
#if 0 
  int inchar_func()
    {
      return getc(fp);
    }
  void unchar_func(int c)
    {
      ungetc(c, fp);
    }
#endif

  va_start(ap, format);
  ret = o_vscanf(fp, stdio_inchar_func, stdio_unchar_func, 
		       [format cString], ap);
  va_end(ap);
  return ret;
}

- (void) flushStream
{
  fflush(fp);
}

- (void) close
{
  fclose(fp);
  fp = 0;
}

- (BOOL) isClosed
{
  /* xxx How should this be implemented? */
  [self notImplemented:_cmd];
  return NO;
}

/* xxx Add "- (BOOL) isOpen" method? */

- (void) rewindStream
{
  rewind(fp);
}

- (void) setStreamPosition: (unsigned)i seekMode: (seek_mode_t)m
{
  fseek(fp, i, m + SEEK_SET - STREAM_SEEK_FROM_START);
}

- (unsigned) streamPosition
{
  return ftell(fp);
}

- (BOOL) isAtEof
{
  if (feof(fp))
    return YES;
  else
    return NO;
}

- (BOOL) isWritable
{
  if (mode)
    return YES;
  else
    return NO;
}

- (void) dealloc
{
  if (fp != 0)
    fclose(fp);
  [super dealloc];
}

- (void) encodeWithCoder: (Coder*)anEncoder
{
  [self notImplemented:_cmd];
}

- initWithCoder: (Coder*)aDecoder
{
  [self notImplemented:_cmd];
  return self;
}

@end
