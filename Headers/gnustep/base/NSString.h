/* Interface for NSObject for GNUStep
   Copyright (C) 1995, 1996, 1999 Free Software Foundation, Inc.

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
   Software Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA 02111 USA.
   */ 

#ifndef __NSString_h_GNUSTEP_BASE_INCLUDE
#define __NSString_h_GNUSTEP_BASE_INCLUDE

#include <Foundation/NSObject.h>
#include <Foundation/NSRange.h>

typedef unsigned short unichar;

@class NSArray;
@class NSCharacterSet;
@class NSData;
@class NSDictionary;
#ifndef STRICT_OPENSTEP
@class NSURL;
#endif

#define NSMaximumStringLength	(INT_MAX-1)
#define NSHashStringLength	63

enum 
{
  NSCaseInsensitiveSearch = 1,
  NSLiteralSearch = 2,
  NSBackwardsSearch = 4,
  NSAnchoredSearch = 8
};

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
  NSISOLatin1StringEncoding = 5,	// ISO-8859-1; West European
  NSSymbolStringEncoding = 6,
  NSNonLossyASCIIStringEncoding = 7,
  NSShiftJISStringEncoding = 8,
  NSISOLatin2StringEncoding = 9,	// ISO-8859-2; East European
  NSUnicodeStringEncoding = 10,
  NSWindowsCP1251StringEncoding = 11,
  NSWindowsCP1252StringEncoding = 12,	// WinLatin1
  NSWindowsCP1253StringEncoding = 13,	// Greek
  NSWindowsCP1254StringEncoding = 14,	// Turkish
  NSWindowsCP1250StringEncoding = 15,	// WinLatin2
  NSISO2022JPStringEncoding = 21,
  NSMacOSRomanStringEncoding = 30,
  NSProprietaryStringEncoding = 31,

// GNUstep additions
  NSKOI8RStringEncoding = 50,		// Russian/Cyrillic
  NSISOLatin3StringEncoding = 51,	// ISO-8859-3; South European
  NSISOLatin4StringEncoding = 52,	// ISO-8859-4; North European
  NSISOCyrillicStringEncoding = 22,	// ISO-8859-5
  NSISOArabicStringEncoding = 53,	// ISO-8859-6
  NSISOGreekStringEncoding = 54,	// ISO-8859-7
  NSISOHebrewStringEncoding = 55,	// ISO-8859-8
  NSISOLatin5StringEncoding = 57,	// ISO-8859-9; Turkish
  NSISOLatin6StringEncoding = 58,	// ISO-8859-10; Nordic
/* Possible future ISO-8859 additions
  NSISOThaiStringEncoding = 59,		// ISO-8859-11
					// ISO-8859-12
*/
  NSISOLatin7StringEncoding = 61,	// ISO-8859-13
  NSISOLatin8StringEncoding = 62,	// ISO-8859-14
  NSISOLatin9StringEncoding = 63,	// ISO-8859-15; Replaces ISOLatin1
  NSGB2312StringEncoding = 56,
  NSUTF7StringEncoding = 64		// RFC 2152
} NSStringEncoding;

enum {
  NSOpenStepUnicodeReservedBase = 0xF400
};

@protocol NSString  <NSCoding, NSCopying, NSMutableCopying>

// Creating Temporary Strings
+ (id) string;
+ (id) stringWithCharacters: (const unichar*)chars
		     length: (unsigned int)length;
+ (id) stringWithCString: (const char*)byteString
		  length: (unsigned int)length;
+ (id) stringWithCString: (const char*) byteString;
+ (id) stringWithFormat: (NSString*)format,...;
+ (id) stringWithContentsOfFile:(NSString *)path;

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

#ifndef STRICT_OPENSTEP
+ (NSString*) pathWithComponents: (NSArray*)components;
- (BOOL) isAbsolutePath;
- (NSArray*) pathComponents;
- (NSArray*) stringsByAppendingPaths: (NSArray*)paths;
+ (NSString*) localizedStringWithFormat: (NSString*) format, ...;

+ (id) stringWithFormat: (NSString*)format
	      arguments: (va_list)argList;
+ (id) stringWithString: (NSString*) aString;
+ (id) stringWithContentsOfURL: (NSURL*)anURL;
+ (id) stringWithUTF8String: (const char*)bytes;
- (id) initWithFormat: (NSString*)format
	       locale: (NSDictionary*)dictionary;
- (id) initWithFormat: (NSString*)format
	       locale: (NSDictionary*)dictionary
	    arguments: (va_list)argList;
- (id) initWithUTF8String: (const char *)bytes;
- (id) initWithContentsOfURL: (NSURL*)anURL;
- (NSString*) substringWithRange: (NSRange)aRange;
- (NSComparisonResult) caseInsensitiveCompare: (NSString*)aString;
- (NSComparisonResult)compare:(NSString *)string 
		      options:(unsigned)mask 
			range:(NSRange)compareRange 
		       locale:(NSDictionary *)dict;
- (NSComparisonResult)localizedCompare:(NSString *)string;
- (NSComparisonResult)localizedCaseInsensitiveCompare:(NSString *)string;
- (BOOL) writeToFile: (NSString*)filename
	  atomically: (BOOL)useAuxiliaryFile;
- (BOOL)writeToURL:(NSURL *)anURL atomically:(BOOL)atomically;
- (double) doubleValue;
+ (NSStringEncoding*) availableStringEncodings;
+ (NSString*) localizedNameOfStringEncoding: (NSStringEncoding)encoding;
- (void) getLineStart: (unsigned int *)startIndex
                  end: (unsigned int *)lineEndIndex
          contentsEnd: (unsigned int *)contentsEndIndex
             forRange: (NSRange)aRange;
- (NSRange) lineRangeForRange: (NSRange)aRange;
- (const char*) lossyCString;
- (const char *)UTF8String;
#endif

#ifndef NO_GNUSTEP
- (BOOL) boolValue;
#endif /* NO_GNUSTEP */

@end

@interface NSString : NSObject <NSString>
@end

@class NSMutableString;

@protocol NSMutableString <NSString>

// Creating Temporary Strings
+ (id) string;
+ (id) stringWithCharacters: (const unichar*)chars
		     length: (unsigned int)length;
+ (id) stringWithCString: (const char*)byteString
		  length: (unsigned int)length;
+ (id) stringWithCString: (const char*) byteString;
+ (id) stringWithFormat: (NSString*)format,...;
+ (id) stringWithContentsOfFile:(NSString *)path;
+ (NSMutableString*) stringWithCapacity: (unsigned)capacity;

// Initializing Newly Allocated Strings
- (id) initWithCapacity: (unsigned)capacity;

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

/*
 * Information for NXConstantString
 */
@interface NXConstantString : NSString
{
  union {
    unichar		*u;
    unsigned char	*c;
  } _contents;
  unsigned int	_count;
}
@end


#ifndef NO_GNUSTEP
/*
 * Private concrete string classes.
 * NB. All these concrete string classes MUST have the same initial ivar
 * layout so that we can swap between them as necessary.
 * The initial layout must also match that of NXConstantString (which is
 * determined by the compiler).
 */
@interface GSString : NSString
{
  union {
    unichar		*u;
    unsigned char	*c;
  } _contents;
  unsigned int	_count;
  struct {
    unsigned int	wide: 1;	// 16-bit characters in string?
    unsigned int	free: 1;	// Should free memory?
    unsigned int	unused: 2;
    unsigned int	hash: 28;
  } _flags;
}
@end

@interface NSString (GSString)
- (NSString*) stringWithoutSuffix: (NSString*)_suffix;
- (NSString*) stringWithoutPrefix: (NSString*)_prefix;
- (NSString*) stringByReplacingString: (NSString*)_replace
			   withString: (NSString*)_by;
@end

@interface NSString(GSTrimming)
- (NSString*) stringByTrimmingLeadWhiteSpaces;
- (NSString*) stringByTrimmingTailWhiteSpaces;
- (NSString*) stringByTrimmingWhiteSpaces;

- (NSString*) stringByTrimmingLeadSpaces;
- (NSString*) stringByTrimmingTailSpaces;
- (NSString*) stringByTrimmingSpaces;
@end

@interface NSMutableString (GSString)
- (void) removeSuffix: (NSString*)_suffix;
- (void) removePrefix: (NSString*)_prefix;
- (void) replaceString: (NSString*)_replace
	    withString: (NSString*)_by;
@end

@interface NSMutableString (GSTrimming)
- (void) trimLeadSpaces;
- (void) trimTailSpaces;
- (void) trimSpaces;
@end
#endif /* NO_GNUSTEP */

#endif /* __NSString_h_GNUSTEP_BASE_INCLUDE */
