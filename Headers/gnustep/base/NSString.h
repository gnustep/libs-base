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
  NSUTF7StringEncoding = 64,		// RFC 2152
  NSGSM0338StringEncoding,		// GSM (mobile phone) default alphabet
  NSBIG5StringEncoding			// Traditional chinese
} NSStringEncoding;

enum {
  NSOpenStepUnicodeReservedBase = 0xF400
};

@interface NSString :NSObject <NSCoding, NSCopying, NSMutableCopying>

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
- (id) initWithFormat: (NSString*)format, ...;
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
- (BOOL) getFileSystemRepresentation: (char*)buffer
			   maxLength: (unsigned int)size;
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
+ (id) stringWithContentsOfURL: (NSURL*)url;
+ (id) stringWithUTF8String: (const char*)bytes;
- (id) initWithFormat: (NSString*)format
	       locale: (NSDictionary*)locale, ...;
- (id) initWithFormat: (NSString*)format
	       locale: (NSDictionary*)locale
	    arguments: (va_list)argList;
- (id) initWithUTF8String: (const char *)bytes;
- (id) initWithContentsOfURL: (NSURL*)url;
- (NSString*) substringWithRange: (NSRange)aRange;
- (NSComparisonResult) caseInsensitiveCompare: (NSString*)aString;
- (NSComparisonResult)compare:(NSString *)string 
		      options:(unsigned int)mask 
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
+ (Class) constantStringClass;
- (BOOL) boolValue;
#endif /* NO_GNUSTEP */

@end

@interface NSMutableString : NSString

// Creating Temporary Strings
+ (id) string;
+ (id) stringWithCharacters: (const unichar*)characters
		     length: (unsigned int)length;
+ (id) stringWithCString: (const char*)byteString
		  length: (unsigned int)length;
+ (id) stringWithCString: (const char*) byteString;
+ (id) stringWithFormat: (NSString*)format,...;
+ (id) stringWithContentsOfFile: (NSString*)path;
+ (NSMutableString*) stringWithCapacity: (unsigned int)capacity;

// Initializing Newly Allocated Strings
- (id) initWithCapacity: (unsigned int)capacity;

// Modify A String
- (void) appendFormat: (NSString*)format, ...;
- (void) appendString: (NSString*)aString;
- (void) deleteCharactersInRange: (NSRange)range;
- (void) insertString: (NSString*)aString atIndex: (unsigned int)loc;
- (void) replaceCharactersInRange: (NSRange)range 
		       withString: (NSString*)aString;
- (void) setString: (NSString*)aString;

@end

/**
 * <p>The NXConstantString class is used to hold constant 8-bit character
 * string objects produced by the compiler where it sees @"..." in the
 * source.  The compiler generates the instances of this class - which
 * has three instance variables -</p>
 * <list>
 * <item>a pointer to the class (this is the sole ivar of NSObject)</item>
 * <item>a pointer to the 8-bit data</item>
 * <item>the length of the string</item>
 * </list>
 * <p>In older versions of the compiler, the isa variable is always set to
 * the NXConstantString class.  In newer versions a compiler option was
 * added for GNUstep, to permit the isa variable to be set to another
 * class, and GNUstep uses this to avoid conflicts with the default
 * implementation of NXConstantString in the ObjC runtime library (the
 * preprocessor is used to change all occurances of NXConstantString
 * in the source code to NSConstantString).</p>
 * <p>Since GNUstep will generally use the GNUstep extension to the
 * compiler, you should never refer to the constnat string class by
 * name, but should use the [NSString+constantStringClass] method to
 * get the actual class being used for constant strings.</p>
 * What follows is a dummy declaration of the class to keep the compiler
 * happy.
 */
@interface NXConstantString : NSString
{
  const char * const nxcsptr;
  const unsigned int nxcslen;
}
@end

#ifdef NeXT_RUNTIME
/* For internal use with NeXT runtime;
   needed, until Apple Radar 2870817 is fixed. */
extern struct objc_class _NSConstantStringClassReference;
#endif

#ifndef NO_GNUSTEP

@interface NSString (GSString)
- (NSString*) stringWithoutSuffix: (NSString*)_suffix;
- (NSString*) stringWithoutPrefix: (NSString*)_prefix;
- (NSString*) stringByReplacingString: (NSString*)_replace
			   withString: (NSString*)_by;
@end

@interface NSString(GSTrimming)
- (NSString*) stringByTrimmingLeadSpaces;
- (NSString*) stringByTrimmingTailSpaces;
- (NSString*) stringByTrimmingSpaces;
@end

@interface NSMutableString (GSString)
- (NSString*) immutableProxy;
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
