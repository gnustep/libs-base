/* Some preliminary ideas about what a String class might look like.
   Copyright (C) 1993,1994 Free Software Foundation, Inc.

   Written by:  R. Andrew McCallum <mccallum@gnu.ai.mit.edu>
   Date: May 1993

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

#ifndef __String_h_OBJECTS_INCLUDE
#define __String_h_OBJECTS_INCLUDE

#include <objects/objc-gnu2next.h>
#include <objects/IndexedCollection.h>
#include <objects/ValueHolding.h>
#include <stdarg.h>

typedef unsigned short Character;

@class String;
@class ConstantString;
@class MutableString;

/* Like in SmallTalk, the String class is a subclass of Collection---a
   collection of characters.  So, all the collection methods are
   available.  Nice. */

@protocol String <IndexedCollecting, ValueGetting>

// INITIALIZING NEWLY ALLOCATED STRINGS.  DON'T FORGET TO RELEASE THEM!;
- init;
- initWithString: (String*)aString range: (IndexRange)aRange;
- initWithString: (String*)aString length: (unsigned)aLength;
- initWithString: (String*)aString;
- initWithFormat: (String*)aFormatString, ...;
- initWithFormat: (String*)aFormatString arguments: (va_list)arg;
- initWithCString: (const char*)aCharPtr range: (IndexRange)aRange;
- initWithCString: (const char*)aCharPtr length: (unsigned)aLength;
- initWithCString: (const char*)aCharPtr;
- initWithCStringNoCopy: (const char*)cp length: (unsigned)l
   freeWhenDone: (BOOL)f;
- initWithStream: (Stream*)aStream;
- initWithStream: (Stream*)aStream length: (unsigned)aLength;

// GETTING C CHARS;
- (char) charAtIndex: (unsigned)index;
- (const char *) cString;
- (unsigned) cStringLength;
- (void) getCString: (char*)buffer;
- (void) getCString: (char*)buffer range: (IndexRange)aRange;
- (void) getCString: (char*)buffer length: (unsigned)aLength;

- (unsigned) length;

// GETTING NEW, AUTORELEASED STRING OBJECTS, NO NEED TO RELEASE THESE;
+ (String*) stringWithString: (String*)aString range: (IndexRange)aRange;
+ (String*) stringWithString: (String*)aString length: (unsigned)aLength;
+ (String*) stringWithString: (String*)aString;
+ (String*) stringWithFormat: (String*)aFormatString, ...;
+ (String*) stringWithFormat: (String*)aFormatString arguments: (va_list)arg;
+ (String*) stringWithCString: (const char*)cp range: (IndexRange)r
   noCopy: (BOOL)f;
+ (String*) stringWithCString: (const char*)aCharPtr range: (IndexRange)aRange;
+ (String*) stringWithCString: (const char*)aCharPtr length: (unsigned)aLength;
+ (String*) stringWithCString: (const char*)aCharPtr;

- (String*) stringByAppendingFormat: (String*)aString, ...;
- (String*) stringByAppendingFormat: (String*)aString arguments: (va_list)arg;
- (String*) stringByPrependingFormat: (String*)aString, ...;
- (String*) stringByPrependingFormat: (String*)aString arguments: (va_list)arg;
- (String*) stringByAppendingString: (String*)aString;
- (String*) stringByPrependingString: (String*)aString;

- (String*) substringWithRange: (IndexRange)aRange;
- (String*) substringWithLength: (unsigned)l;
- (String*) substringAfterIndex: (unsigned)i;
- (id <IndexedCollecting>) substringsSeparatedByString: (String*)separator;

- (String*) capitalizedString;
- (String*) lowercaseString;
- (String*) uppercaseString;

// TESTING;
- (BOOL) isEqual: anObject;
- (unsigned) hash;
- (int) compare: anObject;
- copy;
- (IndexRange) range;
- (unsigned) indexOfString: (String*)aString;
- (unsigned) indexOfChar: (char)aChar;
- (unsigned) indexOfLastChar: (char)aChar;
- (unsigned) indexOfCharacter: (Character)aChar;
- (unsigned) indexOfLastCharacter: (Character)aChar;

// FOR FILE NAMES (don't use the name "path", gnu will not use it for this);
- (IndexRange) fileRange;
- (IndexRange) directoriesRange;
- (IndexRange) extensionRange;
- (IndexRange) fileWithoutExtensionRange;
- (BOOL) isAbsolute;
- (BOOL) isRelative;

@end

@protocol MutableString <String, ValueHolding>

+ (MutableString*) stringWithCapacity: (unsigned)capacity;
- initWithCapacity: (unsigned)capacity;

/* This from IndexedCollecting: - removeRange: (IndexRange)range; */
- (void) insertString: (String*)string atIndex: (unsigned)index;

- (void) setString: (String*)string;
- (void) appendString: (String*)string;
- (void) replaceRange: (IndexRange)range withString: (String*)string;

@end

/* Abstract string classes */

@interface String : IndexedCollection <String>
@end

@interface MutableString : String <MutableString>
@end

/* Some concrete string classes */

@interface CString : String
{
  char * _contents_chars;
  int _count;
}
@end

@interface MutableCString : MutableString
{
  char * _contents_chars;
  int _count;
  int _capacity;
}
@end

@interface ConstantString : CString
@end

/* The compiler makes @""-strings into NXConstantString's */
@interface NXConstantString : ConstantString
@end

#endif /* __String_h_OBJECTS_INCLUDE */
