/* ostream.h - C-function interface to GNUstep Objective-C streams
   Copyright (C) 1996 Free Software Foundation, Inc.

   Written by:  Adam Fedor <fedor@boulder.colorado.edu>
   Date: Jun 1996

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
   Software Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA 02111 USA.
*/ 

#ifndef __objc_stream_h_GNUSTEP_BASE_INCLUDE
#define __objc_stream_h_GNUSTEP_BASE_INCLUDE

#include <stdarg.h>
#include <objc/typedstream.h>
#include <Foundation/NSObjCRuntime.h>

typedef struct _ostream
{
  void* stream_obj;
  int   flags;
} ostream;

/* Access modes */
#define OSTREAM_READONLY             1      /* read on stream only */
#define OSTREAM_WRITEONLY            2      /* write on stream only */
#define OSTREAM_READWRITE            4      /* do read & write */
#define OSTREAM_APPEND               8      /* append (write at end of file) */

/* Seek modes */
#define OSTREAM_SEEK_FROM_START      0
#define OSTREAM_SEEK_FROM_CURRENT    1
#define OSTREAM_SEEK_FROM_END        2

/* Private flags */
#define OSTREAM_READFLAG       1               /* stream is for reading */
#define OSTREAM_WRITEFLAG      (1 << 1)        /* stream is for writing */
#define OSTREAM_ISBUFFER       (1 << 2)
#define OSTREAM_USER_OWNS_BUF  (1 << 3)
#define OSTREAM_CANSEEK        (1 << 4)

GS_EXPORT int  ostream_getc (ostream* s);
GS_EXPORT void ostream_ungetc (ostream* s);
GS_EXPORT int  ostream_putc (ostream* s, int c);
GS_EXPORT BOOL ostream_at_eos (ostream* s);
GS_EXPORT char* ostream_gets (ostream* s, char* buf, int count);

GS_EXPORT int  ostream_flush (ostream *s);		
GS_EXPORT void ostream_seek (ostream *s, long offset, int mode);		
GS_EXPORT long ostream_tell (ostream *s);		
GS_EXPORT int  ostream_read (ostream* s, void* buf, int count);
GS_EXPORT int  ostream_write (ostream* s, const void* buf, int count);
GS_EXPORT void ostream_printf (ostream *s, const char *format, ...);
GS_EXPORT void ostream_vprintf (ostream *s, const char *format, va_list argList);
GS_EXPORT int ostream_scanf (ostream *s, const char *format, ...);
GS_EXPORT int ostream_vscanf (ostream *s, const char *format, va_list argList);

GS_EXPORT ostream *ostream_open_descriptor (int fd, int mode);
GS_EXPORT ostream *ostream_open_memory (const char *addr, int size, int mode);
GS_EXPORT ostream *ostream_map_file (const char *name, int mode);
GS_EXPORT int ostream_save_to_file (ostream *s, const char *name);
GS_EXPORT void ostream_get_memory_buffer (ostream *s, char **addr, 
				       int *len, int *maxlen);
GS_EXPORT void ostream_close_memory (ostream *s, int option);
GS_EXPORT void ostream_close (ostream *s);		

#define OSTREAM_FREEBUFFER	0
#define OSTREAM_TRUNCATEBUFFER	1
#define OSTREAM_SAVEBUFFER	2

#endif /* __objc_stream_h_GNUSTEP_BASE_INCLUDE */
