/* Interface for GNU Objective-C coder object for use serializing
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

#ifndef __Coder_h
#define __Coder_h

#include <objects/stdobjects.h>
#include <objects/Coding.h>

@class Stream;
@class Dictionary;
@class Stack;

@interface Coder : Object
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

- initEncodingOnStream: (Stream *)s;
- initDecodingOnStream: (Stream *)s;
- initEncoding;
- initDecoding;
- init;

- free;
- (BOOL) isDecoding;

- (void) encodeValueOfType: (const char*)type 
   at: (const void*)d 
   withName: (const char *)name;
- (void) decodeValueOfType: (const char*)type
   at: (void*)d 
   withName: (const char **)namePtr;

- (void) encodeWithName: (const char *)name
   valuesOfTypes: (const char *)types, ...;
- (void) decodeWithName: (const char **)name
   valuesOfTypes: (const char *)types, ...;

- (void) encodeArrayOfType: (const char *)type
   at: (const void *)d
   count: (unsigned)c
   withName: (const char *)name;
- (void) decodeArrayOfType: (const char *)type
   at: (void *)d
   count: (unsigned *)c
   withName: (const char **)name;

- (void) encodeObject: anObj
   withName: (const char *)name;
- (void) encodeObjectBycopy: anObj
   withName: (const char *)name;
- (void) decodeObjectAt: (id*)anObjPtr
   withName: (const char **)name;

- (void) encodeRootObject: anObj
   withName: (const char *)name;
- (void) encodeObjectReference: anObj
   withName: (const char *)name;
- (void) startEncodingInterconnectedObjects;
- (void) finishEncodingInterconnectedObjects;
- (void) startDecodingInterconnectedObjects;
- (void) finishDecodingInterconnectedObjects;

- (void) encodeAtomicString: (const char*)sp
   withName: (const char*)name;
- (const char *) decodeAtomicStringWithName: (const char **)name;

- decodeClass;
- (void) encodeClass: aClass;

/* For inserting a name into a TextCoder stream */
- (void) encodeName: (const char*)n;
- (void) decodeName: (const char**)n;

/* For subclasses that want to keep track of recursion */
- (void) encodeIndent;
- (void) encodeUnindent;
- (void) decodeIndent;
- (void) decodeUnindent;

/* Implemented by concrete subclasses */
- (void) encodeValueOfSimpleType: (const char*)type 
   at: (const void*)d 
   withName: (const char *)name;
- (void) decodeValueOfSimpleType: (const char*)type 
   at: (void*)d 
   withName: (const char **)namePtr;
- (void) encodeBytes: (const char *)b
   count: (unsigned)c
   withName: (const char *)name;
- (void) decodeBytes: (char *)b
   count: (unsigned*)c
   withName: (const char **)name;

- (int) coderFormatVersion;
- (int) coderConcreteFormatVersion;

- (void) resetCoder;		/* xxx remove this? */

- doInitOnStream: (Stream *)s isDecoding: (BOOL)f;
/* Internal designated initializer.  Override it, but don't call it yourself.
   This method name may change. */

+ (int) coderFormatVersion;
+ (int) coderConcreteFormatVersion;
+ (const char *) coderSignature;

@end

@interface Object (CoderAdditions) <Coding>
- (void) encodeWithCoder: (Coder*)anEncoder;
+ newWithCoder: (Coder*)aDecoder;

/* These methods here temporarily until ObjC runtime category bug fixed */
- classForConnectedCoder:aRmc;
+ (void) encodeObject: anObject withConnectedCoder: aRmc;
- (id) retain;
- (void) release;
- (void) dealloc;
- (unsigned) retainCount;
- (BOOL) isProxy;

@end

#endif __Coder_h
