/* Implementation of GNUSTEP string class
   Copyright (C) 1995 Free Software Foundation, Inc.
   
   Written by:  R. Andrew McCallum <mccallum@gnu.ai.mit.edu>
   Date: January 1995
   
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

/* Caveats:

   Many method unimplemented.

   Only supports C Strings.  Some implementations will need to be 
   changed when we get other string backing classes.

   Does not support %@ in format strings.

*/

#include <objects/stdobjects.h>
#include <foundation/NSString.h>
#include <objects/IndexedCollection.h>
#include <objects/IndexedCollectionPrivate.h>
#include <objects/String.h>
#include <limits.h>

@implementation NSString

+ (void) initialize
{
  static int done = 0;
  if (!done)
    {
      done = 1;
      class_add_behavior([NSString class], [String class]);
    }
}

// Creating Temporary Strings

+ (NSString*) localizedStringWithFormat: (NSString*) format, ...
{
  [self notImplemented:_cmd];
  return self;
}

+ (NSString*) stringWithCString: (const char*) byteString
{
  return [[[NSCString alloc] initWithCString:byteString]
	  autorelease];
}

+ (NSString*) stringWithCString: (const char*)byteString
   length: (unsigned int)length
{
  return [[[NSCString alloc] initWithCString:byteString length:length]
	  autorelease];
}

+ (NSString*) stringWithCharacters: (const unichar*)chars
   length: (unsigned int)length
{
  [self notImplemented:_cmd];
  return self;
}

+ (NSString*) stringWithFormat: (NSString*)format,...
{
  va_list ap;
  id ret;

  va_start(ap, format);
  ret = [[[NSCString alloc] initWithFormat:format arguments:ap]
	 autorelease];
  va_end(ap);
  return ret;
}

+ (NSString*) stringWithFormat: (NSString*)format
   arguments: (va_list)argList
{
  return [[[NSCString alloc] initWithFormat:format arguments:argList]
	  autorelease];
}

// Initializing Newly Allocated Strings

- (id) init
{
  return [self initWithCString:""];
}

- (id) initWithCString: (const char*)byteString
{
  return [self initWithCString:byteString length:strlen(byteString)];
}

- (id) initWithCString: (const char*)byteString
   length: (unsigned int)length
{
  char *s;
  OBJC_MALLOC(s, char, length+1);
  memcpy(s, byteString, length);
  s[length] = '\0';
  return [self initWithCStringNoCopy:s length:length freeWhenDone:NO];
}

/* This is the designated initializer for CStrings. */
- (id) initWithCStringNoCopy: (char*)byteString
   length: (unsigned int)length
   freeWhenDone: (BOOL)flag
{
  [self notImplemented:_cmd];
  return self;
}

- (id) initWithCharacters: (const unichar*)chars
   length: (unsigned int)length
{
  [self notImplemented:_cmd];
  return self;
}

/* This is the designated initializer for unichar Strings. */
- (id) initWithCharactersNoCopy: (unichar*)chars
   length: (unsigned int)length
   freeWhenDone: (BOOL)flag
{
  [self notImplemented:_cmd];
  return self;
}

- (id) initWithContentsOfFile: (NSString*)path
{
  [self notImplemented:_cmd];
  return self;
}

- (id) initWithData: (NSData*)data
   encoding: (NSStringEncoding)encoding
{
  [self notImplemented:_cmd];
  return self;
}

- (id) initWithFormat: (NSString*)format,...
{
  va_list ap;
  va_start(ap, format);
  self = [self initWithFormat:format arguments:ap];
  va_end(ap);
  return self;
}

/* xxx Change this when we have non-CString classes */
- (id) initWithFormat: (NSString*)format
   arguments: (va_list)argList
{
#if HAVE_VSPRINTF
  char buf[128];		/* xxx horrible, disgusting, fix this! */
  vsprintf(buf, [format _cStringContents], argList);
  return [self initWithCString:buf];
#else
  [self notImplemented:_cmd];
  return self;
#endif
}

- (id) initWithFormat: (NSString*)format
   locale: (NSDictionary*)dictionary
{
  [self notImplemented:_cmd];
  return self;
}

- (id) initWithFormat: (NSString*)format
   locale: (NSDictionary*)dictionary
   arguments: (va_list)argList
{
  [self notImplemented:_cmd];
  return self;
}

/* xxx Change this when we have non-CString classes */
- (id) initWithString: (NSString*)string
{
  return [self initWithCString:[string _cStringContents]];
}


// Getting a String's Length

/* xxx Change this when we have non-CString classes */
- (unsigned int) length
{
  return [self cStringLength];
}


// Accessing Characters

/* xxx Change this when we have non-CString classes */
- (unichar) characterAtIndex: (unsigned int)index
{
  /* xxx raise NSException instead of assert. */
  assert(index < [self cStringLength]);
  return (unichar) [self _cStringContents][index];
}

/* Inefficient.  Should be overridden */
- (void) getCharacters: (unichar*)buffer
{
  [self getCharacters:buffer range:((NSRange){0,[self length]})];
  return;
}

/* Inefficient.  Should be overridden */
- (void) getCharacters: (unichar*)buffer
   range: (NSRange)aRange
{
  int i;
  for (i = aRange.location + aRange.length - 1; i >= aRange.location; i++)
    {
      buffer[i] = [self characterAtIndex:i];
    }
}


// Combining Strings

- (NSString*) stringByAppendingFormat: (NSString*)format,...
{
  va_list ap;
  id ret;
  va_start(ap, format);
  ret = [self stringByAppendingString:
	      [NSString stringWithFormat:format arguments:ap]];
  va_end(ap);
  return ret;
}

/* xxx Change this when we have non-CString classes */
- (NSString*) stringByAppendingString: (NSString*)aString
{
  unsigned len = [self cStringLength];
  char *s = alloca(len + [aString cStringLength] + 1);
  s = strcpy(s, [self _cStringContents]);
  strcpy(s + len, [aString _cStringContents]);
  return [NSString stringWithCString:s];
}


// Dividing Strings into Substrings

- (NSArray*) componentsSeparatedByString: (NSString*)separator
{
  [self notImplemented:_cmd];
  return nil;
}

- (NSString*) substringFromIndex: (unsigned int)index
{
  return [self substringFromRange:((NSRange){index, [self length]-index})];
}

- (NSString*) substringFromRange: (NSRange)aRange
{
  [self notImplemented:_cmd];
  return self;
}

- (NSString*) substringToIndex: (unsigned int)index
{
  return [self substringFromRange:((NSRange){0,index+1})];;
}


// Finding Ranges of Characters and Substrings

- (NSRange) rangeOfCharacterFromSet: (NSCharacterSet*)aSet
{
  [self notImplemented:_cmd];
  return ((NSRange){0,0});
}

- (NSRange) rangeOfCharacterFromSet: (NSCharacterSet*)aSet
   options: (unsigned int)mask
{
  [self notImplemented:_cmd];
  return ((NSRange){0,0});
}

- (NSRange) rangeOfCharacterFromSet: (NSCharacterSet*)aSet
    options: (unsigned int)mask
    range: (NSRange)aRange
{
  [self notImplemented:_cmd];
  return ((NSRange){0,0});
}

- (NSRange) rangeOfString: (NSString*)string
{
  [self notImplemented:_cmd];
  return ((NSRange){0,0});
}

- (NSRange) rangeOfString: (NSString*)string
   options: (unsigned int)mask
{
  [self notImplemented:_cmd];
  return ((NSRange){0,0});
}

- (NSRange) rangeOfString: (NSString*)aString
   options: (unsigned int)mask
   range: (NSRange)aRange
{
  [self notImplemented:_cmd];
  return ((NSRange){0,0});
}


// Determining Composed Character Sequences

- (NSRange) rangeOfComposedCharacterSequenceAtIndex: (unsigned int)anIndex
{
  [self notImplemented:_cmd];
  return ((NSRange){0,0});
}


// Identifying and Comparing Strings

- (NSComparisonResult) caseInsensitiveCompare: (NSString*)aString
{
  [self notImplemented:_cmd];
  return 0;
}

- (NSComparisonResult) compare: (NSString*)aString
{
  return [self compare:aString options:0];
}

- (NSComparisonResult) compare: (NSString*)aString	
   options: (unsigned int)mask
{
  return [self compare:aString options:mask 
	       range:((NSRange){0, [self length]})];
}

- (NSComparisonResult) compare: (NSString*)aString
   options: (unsigned int)mask
   range: (NSRange)aRange
{
  [self notImplemented:_cmd];
  return 0;
}

- (BOOL) hasPrefix: (NSString*)aString
{
  [self notImplemented:_cmd];
  return NO;
}

- (BOOL) hasSuffix: (NSString*)aString
{
  [self notImplemented:_cmd];
  return NO;
}

- (unsigned int) hash
{
  /* xxx need to use NSHashStringLength. */
  return elt_hash_string([self _cStringContents]);
}

- (BOOL) isEqual: (id)anObject
{
  if ([anObject isKindOf:[NSString class]])
    return [self isEqualToString:anObject];
  return NO;
}

- (BOOL) isEqualToString: (NSString*)aString
{
  return ! strcmp([self _cStringContents], [aString _cStringContents]);
}


// Storing the String

- (NSString*) description
{
  return self;
}

- (BOOL) writeToFile: (NSString*)filename
   atomically: (BOOL)useAuxiliaryFile
{
  [self notImplemented:_cmd];
  return NO;
}


// Getting a Shared Prefix

- (NSString*) commonPrefixWithString: (NSString*)aString
   options: (unsigned int)mask
{
  [self notImplemented:_cmd];
  return self;
}


// Changing Case

- (NSString*) capitalizedString
{
  [self notImplemented:_cmd];
  return self;
}

- (NSString*) lowercaseString
{
  [self notImplemented:_cmd];
  return self;
}

- (NSString*) uppercaseString
{
  [self notImplemented:_cmd];
  return self;
}


// Getting C Strings

- (const char*) cString
{
  [self notImplemented:_cmd];
  return NULL;
}

- (unsigned int) cStringLength
{
  [self notImplemented:_cmd];
  return 0;
}

- (void) getCString: (char*)buffer
{
  [self getCString:buffer maxLength:NSMaximumStringLength
	range:((NSRange){0, [self length]})
	remainingRange:NULL];
}

- (void) getCString: (char*)buffer
    maxLength: (unsigned int)maxLength
{
  [self getCString:buffer maxLength:maxLength 
	range:((NSRange){0, [self length]})
	remainingRange:NULL];
}

- (void) getCString: (char*)buffer
   maxLength: (unsigned int)maxLength
   range: (NSRange)aRange
   remainingRange: (NSRange*)leftoverRange
{
  int len;

  /* xxx check to make sure aRange is within self; raise NSStringBoundsError */
  assert(aRange.location + aRange.length < [self cStringLength]);
  if (maxLength < aRange.length)
    {
      len = maxLength;
      if (leftoverRange)
	{
	  leftoverRange->location = 0;
	  leftoverRange->length = 0;
	}
    }
  else
    {
      len = aRange.length;
      if (leftoverRange)
	{
	  leftoverRange->location = aRange.location + maxLength;
	  leftoverRange->length = aRange.length - maxLength;
	}
    }
  memcpy(buffer, [self _cStringContents] + aRange.location, len);
}


// Getting Numeric Values

- (double) doubleValue
{
  return atof([self _cStringContents]);
}

- (float) floatValue
{
  return (float) atof([self _cStringContents]);
}

- (int) intValue
{
  return atoi([self _cStringContents]);
}


// Working With Encodings

+ (NSStringEncoding) defaultCStringEncoding
{
  [self notImplemented:_cmd];
  return 0;
}

- (BOOL) canBeConvertedToEncoding: (NSStringEncoding)encoding
{
  [self notImplemented:_cmd];
  return NO;
}

- (NSData*) dataUsingEncoding: (NSStringEncoding)encoding
{
  [self notImplemented:_cmd];
  return nil;
}

- (NSData*) dataUsingEncoding: (NSStringEncoding)encoding
   allowLossyConversion: (BOOL)flag
{
  [self notImplemented:_cmd];
  return nil;
}

- (NSStringEncoding) fastestEncoding
{
  [self notImplemented:_cmd];
  return 0;
}

- (NSStringEncoding) smallestEncoding
{
  [self notImplemented:_cmd];
  return 0;
}


// Converting String Contents into a Property List

- (id)propertyList
{
  [self notImplemented:_cmd];
  return nil;
}

- (NSDictionary*) propertyListFromStringsFileFormat
{
  [self notImplemented:_cmd];
  return nil;
}


// Manipulating File System Paths

- (unsigned int) completePathIntoString: (NSString**)outputName
   caseSensitive: (BOOL)flag
   matchesIntoArray: (NSArray**)outputArray
   filterTypes: (NSArray*)filterTypes
{
  [self notImplemented:_cmd];
  return 0;
}

- (NSString*) lastPathComponent
{
  [self notImplemented:_cmd];
  return self;
}

- (NSString*) pathExtension
{
  [self notImplemented:_cmd];
  return self;
}

- (NSString*) stringByAbbreviatingWithTildeInPath
{
  [self notImplemented:_cmd];
  return self;
}

- (NSString*) stringByAppendingPathComponent: (NSString*)aString
{
  [self notImplemented:_cmd];
  return self;
}

- (NSString*) stringByAppendingPathExtension: (NSString*)aString
{
  [self notImplemented:_cmd];
  return self;
}

- (NSString*) stringByDeletingLastPathComponent
{
  [self notImplemented:_cmd];
  return self;
}

- (NSString*) stringByDeletingPathExtension
{
  [self notImplemented:_cmd];
  return self;
}

- (NSString*) stringByExpandingTildeInPath
{
  [self notImplemented:_cmd];
  return self;
}

- (NSString*) stringByResolvingSymlinksInPath
{
  [self notImplemented:_cmd];
  return self;
}

- (NSString*) stringByStandardizingPath
{
  [self notImplemented:_cmd];
  return self;
}

/* NSCopying Protocol */

- copyWithZone: (NSZone*)zone
{
  return [[[self class] allocWithZone:zone] initWithString:self];
}

/* xxx Change this when we have non-CString classes */
- mutableCopyWithZone: (NSZone*)zone
{
  return [[NSMutableCString allocWithZone:zone] initWithString:self];
}

@end

@implementation NSString (NSCStringAccess)
- (const char *) _cStringContents
{
  [self notImplemented:_cmd];
  return NULL;
}
@end

@implementation NSString (GNU)

- (elt) elementAtIndex: (unsigned)index
{
  elt ret_elt;
  CHECK_INDEX_RANGE_ERROR(index, [self cStringLength]);
  ret_elt.char_u = [self _cStringContents][index];
  return ret_elt;
}

/* The rest are handled by the class_add_behavior() call in +initialize. */

@end

@implementation NSMutableString

/* xxx This method may be removed in future. */
- (void) setCString: (const char *)byteString length: (unsigned)length
{
  [self notImplemented:_cmd];
}


// Initializing Newly Allocated Strings

- initWithCapacity:(unsigned)capacity
{
  [self notImplemented:_cmd];
  return self;
}


// Creating Temporary Strings

+ (NSMutableString*) stringWithCapacity:(unsigned)capacity
{
  return [[[NSMutableCString alloc] initWithCapacity:capacity] 
	  autorelease];
}

/* Inefficient. */
+ (NSString*) stringWithCharacters: (const unichar*)characters
   length: (unsigned)length
{
  id n;
  n = [self stringWithCapacity:length];
  [n setString: [NSString stringWithCharacters:characters length:length]];
  return n;
}

+ (NSString*) stringWithCString: (const char*)byteString
{
  return [self stringWithCString:byteString length:strlen(byteString)];
}

+ (NSString*) stringWithCString: (const char*)bytes
   length:(unsigned)length
{
  id n = [[NSMutableCString alloc] initWithCapacity:length];
  [n setCString:bytes length:length];
  return n;
}

/* xxx Change this when we have non-CString classes */
+ (NSString*) stringWithFormat: (NSString*)format, ...
{
  va_list ap;
  va_start(ap, format);
  self = [super stringWithFormat:format arguments:ap];
  va_end(ap);
  return self;
}


// Modify A String

/* Inefficient. */
- (void) appendString: (NSString*)aString
{
  id tmp = [self stringByAppendingString:aString];
  [self setString:tmp];
}

/* Inefficient. */
- (void) appendFormat: (NSString*)format, ...
{
  va_list ap;
  id tmp;
  va_start(ap, format);
  tmp = [NSString stringWithFormat:format arguments:ap];
  va_end(ap);
  [self appendString:tmp];
}

- (void) deleteCharactersInRange: (NSRange)range
{
  [self notImplemented:_cmd];
}

- (void) insertString: (NSString*)aString atIndex:(unsigned)loc
{
  [self notImplemented:_cmd];
}

/* Inefficient. */
- (void) replaceCharactersInRange: (NSRange)range 
   withString: (NSString*)aString
{
  [self deleteCharactersInRange:range];
  [self insertString:aString atIndex:range.location];
}

/* xxx Change this when we have non-CString classes */
- (void) setString: (NSString*)aString
{
  const char *s = [aString _cStringContents];
  [self setCString:s length:strlen(s)];
}


@end


@implementation NXConstantString
@end
