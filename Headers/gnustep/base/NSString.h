/* Interface for NSObject for GNUStep
   Copyright (C) 1995, 1996 Free Software Foundation, Inc.

   Written by:  Andrew Kachites McCallum <mccallum@gnu.ai.mit.edu>
   Date: 1995
   
   This file is part of the GNUstep Base Library.

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

#ifndef __NSString_h_GNUSTEP_BASE_INCLUDE
#define __NSString_h_GNUSTEP_BASE_INCLUDE

#include <gnustep/base/preface.h>

#include <Foundation/NSRange.h>

typedef unsigned short unichar;

@class NSArray;
@class NSCharacterSet;
@class NSData;
@class NSDictionary;

#define NSMaximumStringLength	(INT_MAX-1)
#define NSHashStringLength	63

enum 
{
  NSCaseInsensitiveSearch = 1,
  NSLiteralSearch = 2,
  NSBackwardsSearch = 4,
  NSAnchoredSearch = 8
};

/*
typedef enum _NSStringEncoding 
{
  NSUnicodeStringEncoding = 0,
  NSASCIIStringEncoding,
  NSNEXTSTEPStringEncoding,
  NSEUCStringEncoding,
  NSUTFStringEncoding,
  NSISOLatin1StringEncoding,
  NSSymbolStringEncoding,
  NSCyrillicStringEncoding,
  NSNonLossyASCIIStringEncoding
} NSStringEncoding;
*/

typedef enum _NSStringEncoding
{
/* NB. Must not have an encoding with value zero - so we can use zero to
   tell that a variable that should contain an encoding has not yet been
   initialised */
		GSUndefinedEncoding = 0,
                NSASCIIStringEncoding = 1,
                NSNEXTSTEPStringEncoding = 2,
                NSJapaneseEUCStringEncoding = 3,
                NSUTF8StringEncoding = 4,
                NSISOLatin1StringEncoding = 5,
                NSSymbolStringEncoding = 6,
                NSNonLossyASCIIStringEncoding = 7,
                NSShiftJISStringEncoding = 8,
                NSISOLatin2StringEncoding = 9,
                NSUnicodeStringEncoding = 10,
                NSWindowsCP1251StringEncoding = 11,
                NSWindowsCP1252StringEncoding = 12,
                NSWindowsCP1253StringEncoding = 13,
                NSWindowsCP1254StringEncoding = 14,
                NSWindowsCP1250StringEncoding = 15,
                NSISO2022JPStringEncoding = 21,
// GNUstep additions
                NSCyrillicStringEncoding = 22

} NSStringEncoding;

enum {
                NSOpenStepUnicodeReservedBase = 0xF400
};

@protocol NSString  <NSCoding, NSCopying, NSMutableCopying>

// Creating Temporary Strings
+ (NSString*) string;
+ (NSString*) stringWithCharacters: (const unichar*)chars
   length: (unsigned int)length;
+ (NSString*) stringWithCString: (const char*)byteString
   length: (unsigned int)length;
+ (NSString*) stringWithCString: (const char*) byteString;
+ (NSString*) stringWithFormat: (NSString*)format,...;
+ (NSString*) stringWithContentsOfFile:(NSString *)path;

// Initializing Newly Allocated Strings
- (id) initWithCharactersNoCopy: (unichar*)chars
   length: (unsigned int)length
   freeWhenDone: (BOOL)flag;
- (id) initWithCharacters: (const unichar*)chars
   length: (unsigned int)length;
- (id) initWithCStringNoCopy: (char*)byteString
   length: (unsigned int)length
   freeWhenDone: (BOOL)flag;
- (id) initWithCString: (const char*)byteString
   length: (unsigned int)length;
- (id) initWithCString: (const char*)byteString;
- (id) initWithString: (NSString*)string;
- (id) initWithFormat: (NSString*)format,...;
- (id) initWithFormat: (NSString*)format
   arguments: (va_list)argList;
- (id) initWithData: (NSData*)data
   encoding: (NSStringEncoding)encoding;
- (id) initWithContentsOfFile: (NSString*)path;
- (id) init;

// Getting a String's Length
- (unsigned int) length;

// Accessing Characters
- (unichar) characterAtIndex: (unsigned int)index;
- (void) getCharacters: (unichar*)buffer;
- (void) getCharacters: (unichar*)buffer
   range: (NSRange)aRange;

// Combining Strings
- (NSString*) stringByAppendingFormat: (NSString*)format,...;
- (NSString*) stringByAppendingString: (NSString*)aString;

// Dividing Strings into Substrings
- (NSArray*) componentsSeparatedByString: (NSString*)separator;
- (NSString*) substringFromIndex: (unsigned int)index;
- (NSString*) substringFromRange: (NSRange)aRange;
- (NSString*) substringToIndex: (unsigned int)index;

// Finding Ranges of Characters and Substrings
- (NSRange) rangeOfCharacterFromSet: (NSCharacterSet*)aSet;
- (NSRange) rangeOfCharacterFromSet: (NSCharacterSet*)aSet
   options: (unsigned int)mask;
- (NSRange) rangeOfCharacterFromSet: (NSCharacterSet*)aSet
    options: (unsigned int)mask
    range: (NSRange)aRange;
- (NSRange) rangeOfString: (NSString*)string;
- (NSRange) rangeOfString: (NSString*)string
   options: (unsigned int)mask;
- (NSRange) rangeOfString: (NSString*)aString
   options: (unsigned int)mask
   range: (NSRange)aRange;

// Determining Composed Character Sequences
- (NSRange) rangeOfComposedCharacterSequenceAtIndex: (unsigned int)anIndex;

// Converting String Contents into a Property List
- (id)propertyList;
- (NSDictionary*) propertyListFromStringsFileFormat;

// Identifying and Comparing Strings
- (NSComparisonResult) compare: (NSString*)aString;
- (NSComparisonResult) compare: (NSString*)aString	
   options: (unsigned int)mask;
- (NSComparisonResult) compare: (NSString*)aString
   options: (unsigned int)mask
   range: (NSRange)aRange;
- (BOOL) hasPrefix: (NSString*)aString;
- (BOOL) hasSuffix: (NSString*)aString;
- (BOOL) isEqual: (id)anObject;
- (BOOL) isEqualToString: (NSString*)aString;
- (unsigned int) hash;

// Getting a Shared Prefix
- (NSString*) commonPrefixWithString: (NSString*)aString
   options: (unsigned int)mask;

// Changing Case
- (NSString*) capitalizedString;
- (NSString*) lowercaseString;
- (NSString*) uppercaseString;

// Getting C Strings
- (const char*) cString;
- (unsigned int) cStringLength;
- (void) getCString: (char*)buffer;
- (void) getCString: (char*)buffer
    maxLength: (unsigned int)maxLength;
- (void) getCString: (char*)buffer
   maxLength: (unsigned int)maxLength
   range: (NSRange)aRange
   remainingRange: (NSRange*)leftoverRange;

// Getting Numeric Values
- (float) floatValue;
- (int) intValue;

// Working With Encodings
- (BOOL) canBeConvertedToEncoding: (NSStringEncoding)encoding;
- (NSData*) dataUsingEncoding: (NSStringEncoding)encoding;
- (NSData*) dataUsingEncoding: (NSStringEncoding)encoding
   allowLossyConversion: (BOOL)flag;
+ (NSStringEncoding) defaultCStringEncoding;
- (NSString*) description;
- (NSStringEncoding) fastestEncoding;
- (NSStringEncoding) smallestEncoding;

// Manipulating File System Paths
- (unsigned int) completePathIntoString: (NSString**)outputName
   caseSensitive: (BOOL)flag
   matchesIntoArray: (NSArray**)outputArray
   filterTypes: (NSArray*)filterTypes;
- (const char*) fileSystemRepresentation;
- (BOOL) getFileSystemRepresentation: (char*)buffer maxLength: (unsigned int)l;
- (NSString*) lastPathComponent;
- (NSString*) pathExtension;
- (NSString*) stringByAbbreviatingWithTildeInPath;
- (NSString*) stringByAppendingPathComponent: (NSString*)aString;
- (NSString*) stringByAppendingPathExtension: (NSString*)aString;
- (NSString*) stringByDeletingLastPathComponent;
- (NSString*) stringByDeletingPathExtension;
- (NSString*) stringByExpandingTildeInPath;
- (NSString*) stringByResolvingSymlinksInPath;
- (NSString*) stringByStandardizingPath;

// for methods working with decomposed strings
- (int) _baseLength;
- (NSString*) _normalizedString;

#ifndef STRICT_OPENSTEP
+ (NSString*) pathWithComponents: (NSArray*)components;
- (BOOL) isAbsolutePath;
- (NSArray*) pathComponents;
- (NSArray*) stringsByAppendingPaths: (NSArray*)paths;
+ (NSString*) stringWithString: (NSString*) aString;
+ (NSString*) localizedStringWithFormat: (NSString*) format, ...;
+ (NSString*) stringWithFormat: (NSString*)format
   arguments: (va_list)argList;
- (id) initWithFormat: (NSString*)format
   locale: (NSDictionary*)dictionary;
- (id) initWithFormat: (NSString*)format
   locale: (NSDictionary*)dictionary
   arguments: (va_list)argList;
- (NSString*) substringWithRange: (NSRange)aRange;
- (NSComparisonResult) caseInsensitiveCompare: (NSString*)aString;
- (BOOL) writeToFile: (NSString*)filename
   atomically: (BOOL)useAuxiliaryFile;
- (double) doubleValue;
+ (NSStringEncoding*)availableStringEncodings;
+ (NSString*)localizedNameOfStringEncoding:(NSStringEncoding)encoding;
- (void)getLineStart:(unsigned int *)startIndex
                 end:(unsigned int *)lineEndIndex
         contentsEnd:(unsigned int *)contentsEndIndex
            forRange:(NSRange)aRange;
- (NSRange)lineRangeForRange:(NSRange)aRange;

#endif

#ifndef NO_GNUSTEP
- (NSString*) descriptionForPropertyList;
- (id) initWithCharactersNoCopy: (unichar*)chars
			 length: (unsigned int)length
		       fromZone: (NSZone*)zone;
- (id) initWithCStringNoCopy: (char*)byteString
		      length: (unsigned int)length
		    fromZone: (NSZone*)zone;
#endif /* NO_GNUSTEP */

@end

@interface NSString : NSObject <NSString>
@end

@class NSMutableString;

@protocol NSMutableString <NSString>

// Creating Temporary Strings
+ (NSMutableString*) stringWithCapacity:(unsigned)capacity;
#if 0
These methods were already declared above with different return type.
Including them again here with different return type causes a
compiler warning. 
+ (NSMutableString*) stringWithCharacters: (const unichar*)characters
   length: (unsigned)length;
+ (NSMutableString*) stringWithCString: (const char*)byteString;
+ (NSMutableString*) stringWithCString: (const char*)bytes
   length:(unsigned)length;
+ (NSMutableString*) stringWithFormat: (NSString*)format, ...;
#endif 

// Initializing Newly Allocated Strings
- initWithCapacity:(unsigned)capacity;

// Modify A String
- (void) appendFormat: (NSString*)format, ...;
- (void) appendString: (NSString*)aString;
- (void) deleteCharactersInRange: (NSRange)range;
- (void) insertString: (NSString*)aString atIndex:(unsigned)index;
- (void) replaceCharactersInRange: (NSRange)range 
   withString: (NSString*)aString;
- (void) setString: (NSString*)aString;

@end

@interface NSMutableString : NSString <NSMutableString>
@end

/* Because the compiler thinks that @".." strings are NXConstantString's. */
#include <Foundation/NSGString.h>
#include <Foundation/NSGCString.h>
@interface NXConstantString : NSGCString
@end

#endif /* __NSString_h_GNUSTEP_BASE_INCLUDE */
