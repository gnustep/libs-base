/* Protocol for GNU Objective-C objects that can write/read to a coder
   Copyright (C) 1993, 1994, 1995 Free Software Foundation, Inc.
   
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

#ifndef __Coding_h_OBJECTS_INCLUDE
#define __Coding_h_OBJECTS_INCLUDE

#include <objects/stdobjects.h>

@class Coder;			/* xxx remove this eventually */
@class Stream;			/* xxx remove this eventually */

@protocol CommonCoding

- (BOOL) isDecoding;

+ (int) coderFormatVersion;
+ (int) coderConcreteFormatVersion;
+ (const char *) coderSignature;

- doInitOnStream: (Stream *)s isDecoding: (BOOL)f;
/* Internal designated initializer.  Override it, but don't call it yourself.
   This method name may change. */

@end

@protocol Encoding <CommonCoding>

- initEncodingOnStream: (Stream *)s;
- initEncoding;

- (void) encodeValueOfType: (const char*)type 
   at: (const void*)d 
   withName: (const char *)name;

- (void) encodeWithName: (const char *)name
   valuesOfTypes: (const char *)types, ...;

- (void) encodeArrayOfType: (const char *)type
   at: (const void *)d
   count: (unsigned)c
   withName: (const char *)name;

- (void) encodeObject: anObj
   withName: (const char *)name;
- (void) encodeObjectBycopy: anObj
   withName: (const char *)name;

- (void) encodeRootObject: anObj
   withName: (const char *)name;
- (void) encodeObjectReference: anObj
   withName: (const char *)name;
- (void) startEncodingInterconnectedObjects;
- (void) finishEncodingInterconnectedObjects;

- (void) encodeAtomicString: (const char*)sp
   withName: (const char*)name;

- (void) encodeClass: aClass;

/* For inserting a name into a TextCoder stream */
- (void) encodeName: (const char*)n;

/* For subclasses that want to keep track of recursion */
- (void) encodeIndent;
- (void) encodeUnindent;

/* Implemented by concrete subclasses */
- (void) encodeValueOfSimpleType: (const char*)type 
   at: (const void*)d 
   withName: (const char *)name;
- (void) encodeBytes: (const char *)b
   count: (unsigned)c
   withName: (const char *)name;

@end

@protocol Decoding <CommonCoding>

- initDecodingOnStream: (Stream *)s;
- initDecoding;

- (void) decodeValueOfType: (const char*)type
   at: (void*)d 
   withName: (const char **)namePtr;

- (void) decodeWithName: (const char **)name
   valuesOfTypes: (const char *)types, ...;

- (void) decodeArrayOfType: (const char *)type
   at: (void *)d
   count: (unsigned)c
   withName: (const char **)name;

- (void) decodeObjectAt: (id*)anObjPtr
   withName: (const char **)name;

- (void) startDecodingInterconnectedObjects;
- (void) finishDecodingInterconnectedObjects;

- (const char *) decodeAtomicStringWithName: (const char **)name;

- decodeClass;

/* For inserting a name into a TextCoder stream */
- (void) decodeName: (const char**)n;

/* For subclasses that want to keep track of recursion */
- (void) decodeIndent;
- (void) decodeUnindent;

/* Implemented by concrete subclasses */
- (void) decodeValueOfSimpleType: (const char*)type 
   at: (void*)d 
   withName: (const char **)namePtr;
- (void) decodeBytes: (char *)b
   count: (unsigned*)c
   withName: (const char **)name;

@end

@interface NSObject (SelfCoding)

- (void) encodeWithCoder: (id <Encoding>)anEncoder;
- (id) initWithCoder: (id <Decoding>)aDecoder;
+ (id) newWithCoder: (id <Decoding>)aDecoder;

/* NOTE:

   If the class responds to +newWithCoder Coder will send it for
   decoding, otherwise Coder will allocate the object itself and send
   initWithCoder instead.

   +newWithCoder is useful because many classes keep track of their
   instances and only allow one instance of each configuration.  For
   example, see the designated initializers of SocketPort, Connection,
   and Proxy.

   Using +new.. instead of -init.. prevents us from having to waste
   the effort of allocating space for an object to be decoded, then
   immediately deallocating that space because we're just returning a
   pre-existing object.

   The newWithCoder and initWithCoder methods must return the decoded
   object.

   This is not a Protocol, because objects are not required to
   implement newWithCoder or initWithCoder.  They probably want to
   implement one of them, though.

   -mccallum  */

@end

#endif /* __Coding_h_OBJECTS_INCLUDE */
