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

@protocol String <ValueGetting>

// INITIALIZING NEWLY ALLOCATED STRINGS.  DON'T FORGET TO RELEASE THEM!;
- init;
- initWithString: (String*)aString;
- initWithString: (String*)aString range: (IndexRange)aRange;
- initWithFormat: (String*)aFormatString, ...;
- initWithFormat: (String*)aFormatString arguments: (va_list)arg;
- initWithCString: (const char*)aCharPtr;
- initWithCString: (const char*)aCharPtr range: (IndexRange)aRange;
//- initWithStream: (Stream*)aStream;
//- initWithStream: (Stream*)aStream length: (unsigned)aLength;

// GETTING NEW, AUTORELEASED STRING OBJECTS, NO NEED TO RELEASE THESE;
+ (String*) stringWithString: (String*)aString;
+ (String*) stringWithString: (String*)aString range: (IndexRange)aRange;
+ (String*) stringWithFormat: (String*)aFormatString, ...;
+ (String*) stringWithFormat: (String*)aFormatString arguments: (va_list)arg;
+ (String*) stringWithCString: (const char*)aCharPtr;
+ (String*) stringWithCString: (const char*)aCharPtr range: (IndexRange)aRange;

- (String*) stringByAppendingFormat: (String*)aString, ...;
- (String*) stringByAppendingFormat: (String*)aString arguments: (va_list)arg;
- (String*) stringByPrependingFormat: (String*)aString, ...;
- (String*) stringByPrependingFormat: (String*)aString arguments: (va_list)arg;
- (String*) stringByAppendingString: (String*)aString;
- (String*) stringByPrependingString: (String*)aString;

//- (String*) substringWithRange: (IndexRange)aRange;
//- (String*) substringWithLength: (unsigned)l;
//- (String*) substringAfterIndex: (unsigned)i;
//- (id <IndexedCollecting>) substringsSeparatedByString: (String*)separator;

//- (String*) capitalizedString;
//- (String*) lowercaseString;
//- (String*) uppercaseString;

- mutableCopy;
- copy;

// QUERYING
- (unsigned) length;
- (IndexRange) range;
- (BOOL) isEqual: anObject;
- (unsigned) hash;
- (int) compare: anObject;
- copy;
- (unsigned) indexOfString: (String*)aString;
- (unsigned) indexOfChar: (char)aChar;
- (unsigned) indexOfLastChar: (char)aChar;
//- (unsigned) indexOfCharacter: (Character)aChar;
//- (unsigned) indexOfLastCharacter: (Character)aChar;

// GETTING C CHARS;
- (char) charAtIndex: (unsigned)index;
- (const char *) cString;
- (unsigned) cStringLength;
- (void) getCString: (char*)buffer;
- (void) getCString: (char*)buffer range: (IndexRange)aRange;

// FOR FILE NAMES (don't use the name "path", gnu will not use it for this);
//- (IndexRange) fileRange;
//- (IndexRange) directoriesRange;
//- (IndexRange) extensionRange;
//- (IndexRange) fileWithoutExtensionRange;
//- (BOOL) isAbsolute;
//- (BOOL) isRelative;

@end

@protocol MutableString <ValueHolding>

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
