/* Interface for GNU Objective-C coder object for use serializing
   Copyright (C) 1994, 1995, 1996 Free Software Foundation, Inc.
   
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

#ifndef __Coder_h_OBJECTS_INCLUDE
#define __Coder_h_OBJECTS_INCLUDE

#include <objects/stdobjects.h>
#include <objects/Coding.h>
#include <objects/Streaming.h>
#include <objects/String.h>

@class CStream;
@class Dictionary;
@class Stack;
@class Array;			/* xxx Change this to "Set" */

@interface Coder : NSObject <Encoding, Decoding>
{
  int format_version;
  CStream *cstream;
  BOOL is_decoding;
  Dictionary *classname_map;         /* for changing class names on r/w */
  Dictionary *object_table;	     /* read/written objects */
  Dictionary *const_ptr_table;       /* read/written const *'s */
  Dictionary *root_object_table;     /* table of interconnected objects */
  Dictionary *forward_object_table;  /* table of forward references */
  Array *in_progress_table;          /* objects started r/w, but !finished */
  int interconnected_stack_height;   /* number of nested root objects */
}

+ coderReadingFromStream: (id <Streaming>)stream;
+ coderReadingFromFile: (id <String>) filename;

+ coderWritingToStream: (id <Streaming>)stream;
+ coderWritingToFile: (id <String>)filename;

+ decodeObjectFromStream: (id <Streaming>)stream;
+ decodeObjectFromFile: (id <String>) filename;

- initForReadingFromStream: (id <Streaming>) stream
	     formatVersion: (int)version;
- initForReadingFromStream: (id <Streaming>) stream;

- initForWritingToStream: (id <Streaming>) s
	   formatVersion: (int) version;
- initForWritingToStream: (id <Streaming>) s;


+ (void) setDefaultStreamClass: sc;
+ defaultStreamClass;
+ (int) defaultFormatVersion;

+ setDebugging: (BOOL)f;

@end

@interface NSObject (OptionalNewWithCoder)
+ newWithCoder: (Coder*)aDecoder;
@end

@interface NSObject (CoderAdditions) 
/* <SelfCoding> not needed because of NSCoding */

/* These methods here temporarily until ObjC runtime category bug fixed */
- classForConnectedCoder:aRmc;
+ (void) encodeObject: anObject withConnectedCoder: aRmc;

@end

#endif /* __Coder_h_OBJECTS_INCLUDE */
