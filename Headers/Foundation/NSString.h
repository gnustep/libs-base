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

/**
 * Type for representing unicode characters.  (16-bit)
 */
typedef unsigned short unichar;

@class NSArray;
@class NSCharacterSet;
@class NSData;
@class NSDictionary;
#ifndef STRICT_OPENSTEP
@class NSURL;
#endif

#define NSMaximumStringLength	(INT_MAX-1)

enum 
{
  NSCaseInsensitiveSearch = 1,
  NSLiteralSearch = 2,
  NSBackwardsSearch = 4,
  NSAnchoredSearch = 8
};

/**
 *  <p>Enumeration of available encodings for converting between bytes and
 *  characters (in [NSString]s).  The ones that are shared with OpenStep and
 *  Cocoa are: <code>NSASCIIStringEncoding, NSNEXTSTEPStringEncoding,
 *  NSJapaneseEUCStringEncoding, NSUTF8StringEncoding,
 *  NSISOLatin1StringEncoding, NSSymbolStringEncoding,
 *  NSNonLossyASCIIStringEncoding, NSShiftJISStringEncoding,
 *  NSISOLatin2StringEncoding, NSUnicodeStringEncoding,
 *  NSWindowsCP1251StringEncoding, NSWindowsCP1252StringEncoding,
 *  NSWindowsCP1253StringEncoding, NSWindowsCP1254StringEncoding,
 *  NSWindowsCP1250StringEncoding, NSISO2022JPStringEncoding,
 *  NSMacOSRomanStringEncoding, NSProprietaryStringEncoding</code>.</p>
 *  
 *  <p>Additional encodings available under GNUstep are:
 *  <code>NSKOI8RStringEncoding, NSISOLatin3StringEncoding,
 *  NSISOLatin4StringEncoding, NSISOCyrillicStringEncoding,
 *  NSISOArabicStringEncoding, NSISOGreekStringEncoding,
 *  NSISOHebrewStringEncoding, NSISOLatin5StringEncoding,
 *  NSISOLatin6StringEncoding, NSISOThaiStringEncoding,
 *  NSISOLatin7StringEncoding, NSISOLatin8StringEncoding,
 *  NSISOLatin9StringEncoding, NSGB2312StringEncoding, NSUTF7StringEncoding,
 *  NSGSM0338StringEncoding, NSBIG5StringEncoding,
 *  NSKoreanEUCStringEncoding</code>.</p>
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
  NSISOThaiStringEncoding = 59,		// ISO-8859-11
/* Possible future ISO-8859 additions
					// ISO-8859-12
*/
  NSISOLatin7StringEncoding = 61,	// ISO-8859-13
  NSISOLatin8StringEncoding = 62,	// ISO-8859-14
  NSISOLatin9StringEncoding = 63,	// ISO-8859-15; Replaces ISOLatin1
  NSGB2312StringEncoding = 56,
  NSUTF7StringEncoding = 64,		// RFC 2152
  NSGSM0338StringEncoding,		// GSM (mobile phone) default alphabet
  NSBIG5StringEncoding,			// Traditional chinese
  NSKoreanEUCStringEncoding		// Korean
} NSStringEncoding;

enum {
  NSOpenStepUnicodeReservedBase = 0xF400
};

/**
 * <p>
 *   <code>NSString</code> objects represent an immutable string of Unicode 3.0
 *   characters.  These may be accessed individually as type
 *   <code>unichar</code>, an unsigned short.<br/>
 *   The [NSMutableString] subclass represents a modifiable string.  Both are
 *   implemented as part of a class cluster and the instances you receive may
 *   actually be of unspecified concrete subclasses.
 * </p>
 * <p>
 *   A constant <code>NSString</code> can be created using the following syntax:
 *   <code>@"..."</code>, where the contents of the quotes are the
 *   string, using only ASCII characters.
 * </p>
 * <p>
 *   A variable string can be created using a C printf-like <em>format</em>,
 *   as in <code>[NSString stringWithFormat: @"Total is %f", t]</code>.
 * </p>
 * <p>
 *   To create a concrete subclass of <code>NSString</code>, you must have your
 *   class inherit from <code>NSString</code> and override at least the two
 *   primitive methods - -length and -characterAtIndex:
 * </p>
 * <p>
 *   In general the rule is that your subclass must override any
 *   initialiser that you want to use with it.  The GNUstep
 *   implementation relaxes that to say that, you may override
 *   only the <em>designated initialiser</em> and the other
 *   initialisation methods should work.
 * </p>
 * <p>
 *   Where an NSString instance method returns an NSString object,
 *   the class of the actual object returned may be any subclass
 *   of NSString.  The actual value returned may be a new
 *   autoreleased object, an autoreleased copy of the receiver,
 *   or the receiver itsself.  While the abstract base class
 *   implementations of methods (other than initialisers) will
 *   avoid returning mutable strings by returning an autoreleased
 *   copy of a mutable receiver, concrete subclasses may behave
 *   differently, so code should not rely upon the mutability of
 *   returned strings nor upon their lifetime being create than
 *   that of the receiver which returned them.
 * </p>
 */
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
#ifndef	STRICT_OPENSTEP
- (id) initWithBytes: (const void*)bytes
	      length: (unsigned int)length
	    encoding: (NSStringEncoding)encoding;
- (id) initWithBytesNoCopy: (const void*)bytes
		    length: (unsigned int)length
		  encoding: (NSStringEncoding)encoding 
	      freeWhenDone: (BOOL)flag;
#endif
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
- (NSComparisonResult) compare: (NSString*)string 
		       options: (unsigned int)mask 
			 range: (NSRange)compareRange 
			locale: (NSDictionary*)dict;
- (NSComparisonResult) localizedCompare: (NSString *)string;
- (NSComparisonResult) localizedCaseInsensitiveCompare: (NSString *)string;
- (BOOL) writeToFile: (NSString*)filename
	  atomically: (BOOL)useAuxiliaryFile;
- (BOOL) writeToURL: (NSURL*)anURL atomically: (BOOL)atomically;
- (double) doubleValue;
+ (NSStringEncoding*) availableStringEncodings;
+ (NSString*) localizedNameOfStringEncoding: (NSStringEncoding)encoding;
- (void) getLineStart: (unsigned int *)startIndex
                  end: (unsigned int *)lineEndIndex
          contentsEnd: (unsigned int *)contentsEndIndex
             forRange: (NSRange)aRange;
- (NSRange) lineRangeForRange: (NSRange)aRange;
- (const char*) lossyCString;
- (NSString*) stringByAddingPercentEscapesUsingEncoding: (NSStringEncoding)e;
- (NSString*) stringByPaddingToLength: (unsigned int)newLength
			   withString: (NSString*)padString
		      startingAtIndex: (unsigned int)padIndex;
- (NSString*) stringByReplacingPercentEscapesUsingEncoding: (NSStringEncoding)e;
- (NSString*) stringByTrimmingCharactersInSet: (NSCharacterSet*)aSet;
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
- (unsigned int) replaceOccurrencesOfString: (NSString*)replace
				 withString: (NSString*)by
				    options: (unsigned int)opts
				      range: (NSRange)searchRange;
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
 * preprocessor is used to change all occurences of NXConstantString
 * in the source code to NSConstantString).</p>
 * <p>Since GNUstep will generally use the GNUstep extension to the
 * compiler, you should never refer to the constant string class by
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
/** For internal use with NeXT runtime;
    needed, until Apple Radar 2870817 is fixed. */
extern struct objc_class _NSConstantStringClassReference;
#endif

#ifndef NO_GNUSTEP

@interface NSMutableString (GNUstep)
- (NSString*) immutableProxy;
@end

/**
 * Provides some additional (non-standard) utility methods.
 */
@interface NSString (GSCategories)
/**
 * Alternate way to invoke <code>stringWithFormat</code> if you have or wish
 * to build an explicit <code>va_list</code> structure.
 */
+ (id) stringWithFormat: (NSString*)format
	      arguments: (va_list)argList;

/**
 * Returns a string formed by removing the prefix string from the
 * receiver.  Raises an exception if the prefix is not present.
 */
- (NSString*) stringByDeletingPrefix: (NSString*)prefix;

/**
 * Returns a string formed by removing the suffix string from the
 * receiver.  Raises an exception if the suffix is not present.
 */
- (NSString*) stringByDeletingSuffix: (NSString*)suffix;

/**
 * Returns a string formed by removing leading white space from the
 * receiver.
 */
- (NSString*) stringByTrimmingLeadSpaces;

/**
 * Returns a string formed by removing trailing white space from the
 * receiver.
 */
- (NSString*) stringByTrimmingTailSpaces;

/**
 * Returns a string formed by removing both leading and trailing
 * white space from the receiver.
 */
- (NSString*) stringByTrimmingSpaces;

/**
 * Returns a string in which any (and all) occurrences of
 * replace in the receiver have been replaced with by.
 * Returns the receiver if replace
 * does not occur within the receiver.  NB. an empty string is
 * not considered to exist within the receiver.
 */
- (NSString*) stringByReplacingString: (NSString*)replace
			   withString: (NSString*)by;
@end


/**
 * GNUstep specific (non-standard) additions to the NSMutableString class.
 */
@interface NSMutableString (GSCategories)

/**
 * Removes the specified suffix from the string.  Raises an exception
 * if the suffix is not present.
 */
- (void) deleteSuffix: (NSString*)suffix;

/**
 * Removes the specified prefix from the string.  Raises an exception
 * if the prefix is not present.
 */
- (void) deletePrefix: (NSString*)prefix;

/**
 * Replaces all occurrances of the string replace with the string by
 * in the receiver.<br />
 * Has no effect if replace does not occur within the
 * receiver.  NB. an empty string is not considered to exist within
 * the receiver.<br />
 * Calls - replaceOccurrencesOfString:withString:options:range: passing
 * zero for the options and a range from 0 with the length of the receiver.
 */
- (void) replaceString: (NSString*)replace
	    withString: (NSString*)by;

/**
 * Removes all leading white space from the receiver.
 */
- (void) trimLeadSpaces;

/**
 * Removes all trailing white space from the receiver.
 */
- (void) trimTailSpaces;

/**
 * Removes all leading or trailing white space from the receiver.
 */
- (void) trimSpaces;
@end

#endif /* NO_GNUSTEP */

#endif /* __NSString_h_GNUSTEP_BASE_INCLUDE */
