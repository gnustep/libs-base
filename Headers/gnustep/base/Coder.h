/* Interface for GNU Objective-C coder object for use serializing
   Copyright (C) 1994, 1995 Free Software Foundation, Inc.
   
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

@class Stream;
@class Dictionary;
@class Stack;

@interface Coder : NSObject <Encoding, Decoding>
{
  int format_version;
  int concrete_format_version;
  Stream *stream;
  BOOL is_decoding;
  BOOL doing_root_object;
  Dictionary *object_table;	     /* read/written objects */
  Dictionary *const_ptr_table;       /* read/written const *'s */
  Stack *root_object_tables;         /* Stack of Dicts for interconnt'd objs */
  Stack *forward_object_tables;      /* Stack of Dictionaries for frwd refs */
}

+ (void) setDefaultStreamClass: sc;
+ defaultStreamClass;
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
