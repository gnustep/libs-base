/* Protocol for GNU Objective-C objects that can write/read to a coder
   Copyright (C) 1993, 1994, 1995, 1996 Free Software Foundation, Inc.
   
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

/* #include <objects/String.h>
   xxx Think about trying to get <String> back in types,
   but now there is a circular dependancy in the include files. */

@protocol CommonCoding
- (BOOL) isDecoding;
- (void) closeCoder;
- (BOOL) isClosed;
+ (int) defaultFormatVersion;
@end

@protocol Encoding <CommonCoding>

- (void) encodeValueOfObjCType: (const char*)type 
   at: (const void*)d 
   withName: (id /*<String>*/)name;

- (void) encodeValueOfCType: (const char*)type 
   at: (const void*)d 
   withName: (id /*<String>*/)name;

- (void) encodeWithName: (id /*<String>*/)name
   valuesOfObjCTypes: (const char *)types, ...;

- (void) encodeArrayOfObjCType: (const char *)type
   at: (const void *)d
   count: (unsigned)c
   withName: (id /*<String>*/)name;

- (void) encodeObject: anObj
   withName: (id /*<String>*/)name;
- (void) encodeObjectBycopy: anObj
   withName: (id /*<String>*/)name;

- (void) encodeRootObject: anObj
   withName: (id /*<String>*/)name;
- (void) encodeObjectReference: anObj
   withName: (id /*<String>*/)name;
- (void) startEncodingInterconnectedObjects;
- (void) finishEncodingInterconnectedObjects;

- (void) encodeAtomicString: (const char*)sp
   withName: (id /*<String>*/)name;

- (void) encodeClass: aClass;

/* For inserting a name into a TextCoder stream */
- (void) encodeName: (id /*<String>*/) n;

/* For classes that want to keep track of recursion */
- (void) encodeIndent;
- (void) encodeUnindent;

- (void) encodeBytes: (const char *)b
   count: (unsigned)c
   withName: (id /*<String>*/)name;

@end

@protocol Decoding <CommonCoding>

- (void) decodeValueOfObjCType: (const char*)type
   at: (void*)d 
   withName: (id /*<String>*/ *) namePtr;

- (void) decodeValueOfCType: (const char*)type
   at: (void*)d 
   withName: (id /*<String>*/ *) namePtr;

- (void) decodeWithName: (id /*<String>*/*)name
   valuesOfObjCTypes: (const char *) types, ...;

- (void) decodeArrayOfObjCType: (const char *)type
   at: (void *)d
   count: (unsigned)c
   withName: (id /*<String>*/*)name;

- (void) decodeObjectAt: (id*)anObjPtr
   withName: (id /*<String>*/*)name;

- (void) startDecodingInterconnectedObjects;
- (void) finishDecodingInterconnectedObjects;

- (const char *) decodeAtomicStringWithName: (id /*<String>*/*) name;

- decodeClass;

/* For inserting a name into a TextCoder stream */
- (void) decodeName: (id /*<String>*/ *)n;

/* For classes that want to keep track of recursion */
- (void) decodeIndent;
- (void) decodeUnindent;

- (void) decodeBytes: (char *)b
   count: (unsigned*)c
   withName: (id /*<String>*/ *) name;

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
