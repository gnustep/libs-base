/* objc_streams - C-function interface to Objective-C streams
   Copyright (C) 1993,1994, 1996 Free Software Foundation, Inc.

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
   Software Foundation, Inc., 675 Mass Ave, Cambridge, MA 02139, USA.
*/ 

#ifndef __objc_stream_h_GNUSTEP_BASE_INCLUDE
#define __objc_stream_h_GNUSTEP_BASE_INCLUDE

#include <stdarg.h>
#include <objc/typedstream.h>

typedef struct _ostream {
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
#define OSTREAM_READFLAG     1               /* stream is for reading */
#define OSTREAM_WRITEFLAG    (1 << 1)        /* stream is for writing */
#define OSTREAM_ISBUFFER     (1 << 2)
#define OSTREAM_USER_OWNS_BUF (1 << 3)
#define OSTREAM_CANSEEK      (1 << 4)

extern int  ostream_getc(ostream* s);
extern void ostream_ungetc(ostream* s);
extern int  ostream_putc(ostream* s, int c);
extern BOOL ostream_at_eos(ostream* s);
extern char* ostream_gets(ostream* s, char* buf, int count);

extern int  ostream_flush(ostream *s);		
extern void ostream_seek(ostream *s, long offset, int mode);		
extern long ostream_tell(ostream *s);		
extern int  ostream_read(ostream* s, void* buf, int count);
extern int  ostream_write(ostream* s, const void* buf, int count);
extern void ostream_printf(ostream *s, const char *format, ...);
extern void ostream_vprintf(ostream *s, const char *format, va_list argList);
extern int ostream_scanf(ostream *s, const char *format, ...);
extern int ostream_vscanf(ostream *s, const char *format, va_list argList);

extern ostream *ostream_open_descriptor(int fd, int mode);
extern ostream *ostream_open_memory(const char *addr, int size, int mode);
extern ostream *ostream_map_file(const char *name, int mode);
extern int ostream_save_to_file(ostream *s, const char *name);
extern void ostream_get_memory_buffer(ostream *s, char **addr, 
				      int *len, int *maxlen);
extern void ostream_close_memory(ostream *s, int option);
extern void ostream_close(ostream *s);		

#define OSTREAM_FREEBUFFER	0
#define OSTREAM_TRUNCATEBUFFER	1
#define OSTREAM_SAVEBUFFER	2

#endif /* __objc_stream_h_GNUSTEP_BASE_INCLUDE */
