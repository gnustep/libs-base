/* objc_streams - C-function interface to Objective-C streams
   Copyright (C) 1996 Free Software Foundation, Inc.

   Written by:  Adam Fedor <fedor@boulder.colorado.edu>
   Date: Aug 1996

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
#include <stdio.h>
#include "gnustep/base/ostream.h"
#include "gnustep/base/MemoryStream.h"
#include "gnustep/base/StdioStream.h"
#include "gnustep/base/String.h"

#define OSTREAM_EOF EOF

/* Handle a stream error - FIXME: not sure if this should throw an exception
   or what... */
static void
_ostream_error (const char* message)
{
  fprintf (stderr, "ostream error: %s\n", message);
}

int  
ostream_getc (ostream* s)
{
  char c = 0;
  if (s->flags & OSTREAM_READFLAG)
    [(id <Streaming>)s->stream_obj readByte: &c];
  else
    c = OSTREAM_EOF;
  return c;
}

void 
ostream_ungetc (ostream* s)
{
  if ((s->flags & OSTREAM_READFLAG) && (s->flags & OSTREAM_CANSEEK))
    {
      long pos = [(id <SeekableStreaming>)s->stream_obj streamPosition];
      [(id <SeekableStreaming>)s->stream_obj setStreamPosition: pos-1];
    }
  else
    _ostream_error("Tried to unget on non-readable/non-seekable stream");
}

int  
ostream_putc (ostream* s, int c)
{
  if (s->flags & OSTREAM_WRITEFLAG)
    return [(id <Streaming>)s->stream_obj writeByte: c];
  else
    return OSTREAM_EOF;
}

BOOL 
ostream_at_eos (ostream* s)
{
  return [(id <Streaming>)s->stream_obj isAtEof];
}


int  
ostream_flush (ostream *s)
{
  int pos;
  pos = [(id <Streaming>)s->stream_obj streamPosition];
  [(id <Streaming>)s->stream_obj flushStream];
  return [(id <Streaming>)s->stream_obj streamPosition] - pos;
}

void 
ostream_seek (ostream *s, long offset, int mode)	
{
  if (!(s->flags & OSTREAM_CANSEEK))
    return;

  [(id <SeekableStreaming>)s->stream_obj setStreamPosition: offset
     seekMode: (mode - OSTREAM_SEEK_FROM_START + STREAM_SEEK_FROM_START)];
}

long 
ostream_tell (ostream *s)
{
  return [(id <Streaming>)s->stream_obj streamPosition];
}

int  
ostream_read (ostream* s, void* buf, int count)
{
  assert(buf); /* xxxFIXME: should be an exception ? */
  if (s->flags & OSTREAM_READFLAG)
    return [(id <Streaming>)s->stream_obj readBytes: buf length: count];
  return OSTREAM_EOF;
}

char* ostream_gets (ostream* s, char* buf, int count)
{
  char c;
  int i = 0;
    
  assert(buf); /* xxxFIXME: should be an exception ? */
  if (!(s->flags & OSTREAM_READFLAG))
    return NULL;
  while (i < count-1) {
    [(id <Streaming>)s->stream_obj readByte: &c];
    if (c == -1)
      break;
    buf[i++] = c;
    if (c == '\n')
      break;
  }
  buf[i++] = 0;
  
  return i > 1 ? buf : NULL;
}

int  
ostream_write (ostream* s, const void* buf, int count)
{
  assert(buf); /* xxxFIXME: should be an exception ? */
  if (s->flags & OSTREAM_WRITEFLAG)
    return [(id <Streaming>)s->stream_obj writeBytes: buf length: count];
  return OSTREAM_EOF;
}

void 
ostream_printf (ostream *s, const char *format, ...)
{
  va_list args;
  va_start(args, format);
  ostream_vprintf(s, format, args);
  va_end(args);
}

void 
ostream_vprintf (ostream *s, const char *format, va_list argList)
{
  id <String> str = [String stringWithCString: format];
  if (s->flags & OSTREAM_WRITEFLAG)
    [(id <Streaming>)s->stream_obj writeFormat: str arguments: argList];
  else
    _ostream_error("Tried to write to non-writable stream");
}

int 
ostream_scanf (ostream *s, const char *format, ...)
{
  int ret;
  va_list args;
  va_start(args, format);
  ret = ostream_vscanf(s, format, args);
  va_end(args);
  return ret;
}

int 
ostream_vscanf (ostream *s, const char *format, va_list argList)
{
  id <String> str = [String stringWithCString: format];
  if (s->flags & OSTREAM_READFLAG)
    return [(id <Streaming>)s->stream_obj readFormat: str 
	     arguments: argList];
  _ostream_error("Tried to read from non-readable stream");
  return OSTREAM_EOF;
}

static ostream *
_ostream_new_stream_struct (int mode, char** cmode)
{
  char* fmode;
  ostream* stream;
  OBJC_MALLOC(stream, ostream, 1);
  stream->flags = 0;
  switch (mode)
    {
    case OSTREAM_READONLY: 
      fmode = "r"; 
      stream->flags |= OSTREAM_READFLAG; 
      break;
    case OSTREAM_WRITEONLY: 
      fmode = "w"; 
      stream->flags |= OSTREAM_WRITEFLAG; 
      break;
    case OSTREAM_READWRITE: 
      fmode = "w+"; 
      stream->flags |= OSTREAM_READFLAG; 
      stream->flags |= OSTREAM_WRITEFLAG; 
      break;
    case OSTREAM_APPEND: 
      fmode = "w"; 
      stream->flags |= OSTREAM_WRITEFLAG; 
      break;
    default: 
      fmode = "r";
      break;
    }
  if (cmode)
    *cmode = fmode;
  return stream;
}

ostream *
ostream_open_descriptor (int fd, int mode)
{
  char* fmode;
  ostream* stream = _ostream_new_stream_struct(mode, &fmode);
  stream->stream_obj = [[StdioStream alloc] initWithFileDescriptor: fd
		         fmode: fmode];
  /* FIXME: Just assuming we can seek FILE streams */
  stream->flags |= OSTREAM_CANSEEK;
  return stream;
}

ostream *
ostream_open_memory (const char *addr, int size, int mode)
{
  char* fmode;
  ostream* stream = _ostream_new_stream_struct(mode, &fmode);
  if (addr)
    {
      stream->stream_obj = [[MemoryStream alloc] 
			     _initOnMallocBuffer: addr
			     freeWhenDone: NO
			     size: size
			     eofPosition: size
			     prefix: 0
			     position: 0];
      if (!stream->stream_obj)
	return NULL;
    }
  else
    {
      stream->stream_obj = [[MemoryStream alloc] initWithCapacity: size
			  prefix: 0];
    }
  if (mode == OSTREAM_APPEND)
    ostream_seek(stream, 0, OSTREAM_SEEK_FROM_END);
  stream->flags |= OSTREAM_CANSEEK;
  stream->flags |= OSTREAM_ISBUFFER;
  return stream;
}

ostream *
ostream_map_file (const char *name, int mode)
{
  char* fmode;
  String* str = [String stringWithCString: name];
  ostream* stream = _ostream_new_stream_struct(mode, &fmode);
  stream->stream_obj = [[StdioStream alloc] initWithFilename: str
		         fmode: fmode];
  if (!stream->stream_obj)
    return NULL;

  /* xxxFIXME: Just assuming that we can seek: */
  stream->flags |= OSTREAM_CANSEEK;
  if (mode == OSTREAM_APPEND)
    ostream_seek(stream, 0, OSTREAM_SEEK_FROM_END);
  return stream;
}

/* Would like to use NSData for this, but it's to hard to pass the buffer
   and tell NSData not to free it */
int 
ostream_save_to_file (ostream *s, const char *name)
{
  StdioStream* output;
  if (!(s->flags & OSTREAM_ISBUFFER))
    {
      _ostream_error("Tried to save non-memory stream");
      return -1;
    }

  output = [[StdioStream alloc] initWithFilename: 
	        [NSString stringWithCString: name] fmode: "w"];
  if (!output)
    {
      _ostream_error("Unable to open save file");
      return -1;
    }

  [output writeBytes: [(id <MemoryStreaming>)s->stream_obj streamBuffer]
              length: [(id <MemoryStreaming>)s->stream_obj streamEofPosition]];
  [output release];
  return 0;
}

void 
ostream_get_memory_buffer (ostream *s, char **addr, int *len, int *maxlen)
{
  if (!(s->flags & OSTREAM_ISBUFFER))
    {
      if (addr)
	*addr = 0;
      return;
    }

  if (addr)
    *addr = [(id <MemoryStreaming>)s->stream_obj streamBuffer];
  if (len)
    *len = [(id <MemoryStreaming>)s->stream_obj streamEofPosition];
  if (maxlen)
    *maxlen = [(id <MemoryStreaming>)s->stream_obj streamBufferCapacity];
}

void 
ostream_close_memory (ostream *s, int option)
{
  if (s->flags & OSTREAM_ISBUFFER)
    {
      /* Here's the extra release that allows MemoryStream to dealloc itself */
      if (option == OSTREAM_FREEBUFFER)
	[(id)s->stream_obj release];
    }
  ostream_close(s);
}

void 
ostream_close (ostream *s)
{
  [(id <Streaming>)s->stream_obj close];
  [(id)s->stream_obj release];
  s->stream_obj = 0;
  OBJC_FREE(s);
}


