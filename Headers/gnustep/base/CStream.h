/* Interface for GNU Objective-C stream object for use in archiving
   Copyright (C) 1996 Free Software Foundation, Inc.
   
   Written by:  R. Andrew McCallum <mccallum@gnu.ai.mit.edu>
   Written: Jan 1996
   
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

#ifndef __CStream_h_OBJECTS_INCLUDE
#define __CStream_h_OBJECTS_INCLUDE

#include <gnustep/base/preface.h>
#include <gnustep/base/Stream.h>
#include <gnustep/base/CStreaming.h>

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
+ cStreamReadingFromFile: (id <String>) filename;
+ cStreamReadingFromStream: (id <Streaming>) stream;

/* These are standard ways to create a new CStream with a Stream 
   that is open for writing. */
- initForWritingToFile: (id <String>) filename;
- initForWritingToStream: (id <Streaming>) stream;

- initForWritingToStream: (id <Streaming>) s
       withFormatVersion: (int)version;

+ cStreamWritingToStream: (id <Streaming>) stream;
+ cStreamWritingToFile: (id <String>) filename;

@end

#endif /* __CStream_h_OBJECTS_INCLUDE */
