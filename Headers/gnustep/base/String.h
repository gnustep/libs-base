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

/* Values for comparisonFlags arguments */
#define STRING_EXACT_MATCH = 0x0
#define STRING_IGNORE_CASE = 0x1

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
- initWithCString: (char*)aCharPtr range: (IndexRange)aRange;
- initWithCString: (char*)aCharPtr length: (unsigned)aLength;
- initWithCString: (char*)aCharPtr;
- initWithCStringNoCopy: (char*)cp length: (unsigned)l freeWhenDone: (BOOL)f;
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
+ (String*) stringWithCString: (char*)cp range: (IndexRange)r noCopy: (BOOL)f;
+ (String*) stringWithCString: (char*)aCharPtr range: (IndexRange)aRange;
+ (String*) stringWithCString: (char*)aCharPtr length: (unsigned)aLength;
+ (String*) stringWithCString: (char*)aCharPtr;

- (String*) stringByAppendingFormat: (String*)aString, ...;
- (String*) stringByPrependingFormat: (String*)aString, ...;
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
- (int) compare: anObject comparisonFlags: (int)f;
- copy;
- (IndexRange) range;
- (unsigned) indexOfString: (String*)aString comparisonFlags: (int)f;
- (unsigned) indexOfString: (String*)aString;
- (unsigned) indexOfChar: (char)aChar comparisonFlags: (int)f;
- (unsigned) indexOfChar: (char)aChar;
- (unsigned) indexOfLastChar: (char)aChar comparisonFlags: (int)f;
- (unsigned) indexOfLastChar: (char)aChar;
- (unsigned) indexOfCharacter: (Character)aChar comparisonFlags: (int)f;
- (unsigned) indexOfCharacter: (Character)aChar;
- (unsigned) indexOfLastCharacter: (Character)aChar comparisonFlags: (int)f;
- (unsigned) indexOfLastCharacter: (Character)aChar;

// FOR FILE NAMES (don't use the name "path", gnu will not use it for this);
- (IndexRange) fileRange;
- (IndexRange) directoriesRange;
- (IndexRange) extensionRange;
- (IndexRange) fileWithoutExtensionRange;
- (BOOL) isAbsolute;
- (BOOL) isRelative;

// GETTING VALUES;
- (int) intValue;
- (float) floatValue;
- (double) doubleValue;
- (const char *) cStringValue;
- (String *) stringValue;

@end

@protocol MutableString <String, ValueHolding>

- initWithCapacity: (unsigned)capacity;

- (void) setCString: (char *)buffer range: (IndexRange)aRange;
- (void) setCString: (char *)buffer length: (unsigned)aLength;
- (void) setCString: (char *)buffer;
- (void) setString: (String*)string;

- (void) appendFormat: (String*)format, ...;
- (void) appendString: (String*)string;

- (void) removeRange: (IndexRange)range;
- (void) insertString: (String*)string atIndex: (unsigned)index;

// REPLACING;
- (void) replaceRange: (IndexRange)range withString: (String*)string;
- (void) replaceAllStrings: (String*)oldString with: (String*)newString;
- (void) replaceFirstString: (String*)oldString with: (String*)newString;
- (void) replaceFirstString: (String*)oldString 
    afterIndex: (unsigned)index 
    with: (String*)newString;

- capitalize;
- makeLowercase;
- makeUppercase;
- trimBlanks;

/* Value Holding protocol */

// SETTING VALUES;
- setIntValue: (int)anInt;
- setFloatValue: (float)aFloat;
- setDoubleValue: (double)aDouble;
- setCStringValue: (const char *)aCString;
- setStringValue: (String*)aString;

/* Don't forget about appendContentsOf: and prependContentsOf:
   from IndexedCollecting */

@end

@interface String : IndexedCollection <String>
@end

@interface MutableString : String <MutableString>
@end

@interface ConcreteString : MutableString
{
  char * _contents_chars;
  int _count;
}
@end

@interface MutableConcreteString : ConcreteString
{
  int _capacity;
}
@end

@interface ConstantString : ConcreteString
@end

@interface NXConstantString : ConstantString
@end

#endif /* __String_h_OBJECTS_INCLUDE */
