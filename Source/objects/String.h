/* Some preliminary ideas about what a String class might look like.
   Copyright (C) 1993,1994, 1995, 1996 Free Software Foundation, Inc.

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

/* xxx These method names need to be fixed because we will get
   type conflicts with GNUSTEP.
   Perhaps I'll just get rid of the GNU String objects and just
   transfer this functionality into NSSTring and friends. */

#include <objects/stdobjects.h>
#include <objects/IndexedCollection.h>
#include <objects/ValueHolding.h>
#include <Foundation/NSString.h>
#include <stdarg.h>

typedef unsigned short Character;

@class String;
@class ConstantString;
@class MutableString;

/* Like in SmallTalk, the String class is a subclass of Collection---a
   collection of characters.  So, all the collection methods are
   available.  Nice. */

/* Think about changing these names to avoid conflicts with OpenStep? */

@protocol String <ValueGetting, IndexedCollecting, NSString>

// INITIALIZING NEWLY ALLOCATED STRINGS.  DON'T FORGET TO RELEASE THEM!;
- init;
- initWithString: (id <String>)aString;
- initWithString: (id <String>)aString range: (IndexRange)aRange;
- initWithFormat: (id <String>)aFormatString, ...;
- initWithFormat: (id <String>)aFormatString arguments: (va_list)arg;
- initWithCString: (const char*)aCharPtr;
- initWithCString: (const char*)aCharPtr range: (IndexRange)aRange;
//- initWithStream: (Stream*)aStream;
//- initWithStream: (Stream*)aStream length: (unsigned)aLength;

// GETTING NEW, AUTORELEASED STRING OBJECTS, NO NEED TO RELEASE THESE;
+ stringWithString: (id <String>)aString;
+ stringWithString: (id <String>)aString range: (IndexRange)aRange;
+ stringWithFormat: (id <String>)aFormatString, ...;
+ stringWithFormat: (id <String>)aFormatString arguments: (va_list)arg;
+ stringWithCString: (const char*)aCharPtr;
+ stringWithCString: (const char*)aCharPtr range: (IndexRange)aRange;
+ stringWithCStringNoCopy: (const char*)aCharPtr
	     freeWhenDone: (BOOL) f;
+ stringWithCStringNoCopy: (const char*)aCharPtr;

- stringByAppendingFormat: (id <String>)aString, ...;
- stringByAppendingFormat: (id <String>)aString arguments: (va_list)arg;
- stringByPrependingFormat: (id <String>)aString, ...;
- stringByPrependingFormat: (id <String>)aString arguments: (va_list)arg;
- stringByAppendingString: (id <String>)aString;
- stringByPrependingString: (id <String>)aString;

//- substringWithRange: (IndexRange)aRange;
//- substringWithLength: (unsigned)l;
//- substringAfterIndex: (unsigned)i;
//- (id <IndexedCollecting>) substringsSeparatedByString: (id <String>)sep;

//- capitalizedString;
//- lowercaseString;
//- uppercaseString;

- mutableCopy;
- copy;

// QUERYING
- (unsigned) length;
- (IndexRange) range;
- (BOOL) isEqual: anObject;
- (unsigned) hash;
- (int) compare: anObject;
- copy;
- (unsigned) indexOfString: (id <String>)aString;
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

@protocol MutableString <ValueSetting>

+ stringWithCapacity: (unsigned)capacity;
- initWithCapacity: (unsigned)capacity;

/* This from IndexedCollecting: - removeRange: (IndexRange)range; */
- (void) insertString: (id <String>)string atIndex: (unsigned)index;

- (void) setString: (id <String>)string;
- (void) appendString: (id <String>)string;
- (void) replaceRange: (IndexRange)range withString: (id <String>)string;

@end

/* Abstract string classes */

@interface String : IndexedCollection
@end

/* To prevent complaints about protocol conformance. */
@interface String (StringProtocol) <String>
@end

@interface MutableString : String
@end

/* To prevent complaints about protocol conformance. */
@interface MutableString (MutableStringProtocol) <MutableString>
@end

/* Some concrete string classes */

@interface CString : String
{
  char * _contents_chars;
  int _count;
  BOOL _free_contents;
}
@end

@interface MutableCString : MutableString
{
  char *_contents_chars;
  int _count;
  BOOL _free_contents;
  int _capacity;
}
@end

@interface ConstantString : CString
@end

#if 0 /* Moved to foundation/NSString.h */
/* The compiler makes @""-strings into NXConstantString's */
@interface NXConstantString : ConstantString
@end
#endif /* 0 */

#endif /* __String_h_OBJECTS_INCLUDE */
