/* Implementation of GNU Objective C stdio stream
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
#include <objects/StdioStream.h>
#include <objects/Coder.h>
#include <stdarg.h>

extern int
objects_vscanf (void *stream, 
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

- initWithFilePointer: (FILE*)afp fmode: (const char *)mo
{
  int m;
#if 0
  /* xxx Is this portable?  I don't think so. 
     How do I find out if a FILE* is open for reading/writing? */
  if (afp->_flag & _IOREAD) 
    m = STREAM_READONLY;
  else if (afp->_flag & _IOWRT) 
    m = STREAM_WRITEONLY;
  else 
    m = STREAM_READWRITE;
#else
  if (!strcmp(mo, "rw"))
    m = STREAM_READWRITE;
  else if (*mo == 'r')
    m = STREAM_READONLY;
  else if (*mo == 'w')
    m = STREAM_WRITEONLY;
#endif
  [super initWithMode:m];
  fp = afp;
  return self;
}

- initWithFilename: (const char *)name fmode: (const char *)m
{
  FILE *afp = fopen(name, (char*)m);
  return [self initWithFilePointer:afp fmode:m];
}

- initWithFileDescriptor: (int)fd fmode: (const char *)m
{
  FILE *afp = fdopen(fd, (char*)m);
  return [self initWithFilePointer:afp fmode:m];
}

- initWithPipeTo: (const char *)systemCommand
{
  return [self initWithFilePointer:
	       popen(systemCommand, "w")
	       fmode:"w"];
}

- initWithPipeFrom: (const char *)systemCommand
{
  return [self initWithFilePointer:
	       popen(systemCommand, "r")
	       fmode:"r"];
}

- init
{
  return [self initWithFilePointer:stdout fmode:"w"];
}

- (int) writeBytes: (const void*)b length: (int)len
{
  return fwrite(b, 1, len, fp);
}

- (int) readBytes: (void*)b length: (int)len
{
  return fread(b, 1, len, fp);
}

- (int) writeFormat: (const char *)format, ...
{
  int ret;
  va_list ap;

  va_start(ap, format);
  ret = vfprintf(fp, format, ap);
  va_end(ap);
  return ret;
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

- (int) readFormat: (const char *)format, ...
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
  ret = objects_vscanf(fp, stdio_inchar_func, stdio_unchar_func, format, ap);
  va_end(ap);
  return ret;
}

- (void) flushStream
{
  fflush(fp);
}

- (void) rewindStream
{
  rewind(fp);
}

- (void) setStreamPosition: (unsigned)i
{
  fseek(fp, i, 0);
}

- (unsigned) streamPosition
{
  return ftell(fp);
}

- (BOOL) streamEof
{
  if (feof(fp))
    return YES;
  else
    return NO;
}

- free
{
  fclose(fp);
  return [super free];
}

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
