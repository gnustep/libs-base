/* Interface for GNU Objective-C stream object for use in archiving
   Copyright (C) 1996, 1997 Free Software Foundation, Inc.
   
   Written by:  Andrew Kachites McCallum <mccallum@gnu.ai.mit.edu>
   Written: Jan 1996
   
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

#ifndef __CStream_h_GNUSTEP_BASE_INCLUDE
#define __CStream_h_GNUSTEP_BASE_INCLUDE

#include <base/Stream.h>
#include <base/CStreaming.h>

@interface CStream : Stream <CStreaming>
{
  Stream *stream;
  int format_version;
  int indentation;
}

/* These are the standard ways to create a new CStream from a Stream
   that is open for reading.
   It reads the CStream signature at the beginning of the file, and
   automatically creates the appropriate subclass of CStream with
   the correct format version. */
+ cStreamReadingFromFile: (NSString*) filename;
+ cStreamReadingFromStream: (id <Streaming>) stream;

/* These are standard ways to create a new CStream with a Stream 
   that is open for writing. */
- initForWritingToFile: (NSString*) filename;
- initForWritingToStream: (id <Streaming>) stream;

- initForWritingToStream: (id <Streaming>) s
       withFormatVersion: (int)version;

+ cStreamWritingToStream: (id <Streaming>) stream;
+ cStreamWritingToFile: (NSString*) filename;

/* This is the designated initializer for reading.  Don't call it yourself. */
- _initForReadingFromPostSignatureStream: (id <Streaming>)s
		       withFormatVersion: (int)version;

@end

#endif /* __CStream_h_GNUSTEP_BASE_INCLUDE */
