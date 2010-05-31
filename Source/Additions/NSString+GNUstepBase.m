/* Implementation of extension methods for base additions

   Copyright (C) 2010 Free Software Foundation, Inc.

   Written by:  Richard Frith-Macdonald <rfm@gnu.org>

   This file is part of the GNUstep Base Library.

   This library is free software; you can redistribute it and/or
   modify it under the terms of the GNU Lesser General Public
   License as published by the Free Software Foundation; either
   version 2 of the License, or (at your option) any later version.

   This library is distributed in the hope that it will be useful,
   but WITHOUT ANY WARRANTY; without even the implied warranty of
   MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
   Library General Public License for more details.

   You should have received a copy of the GNU Lesser General Public
   License along with this library; if not, write to the Free
   Software Foundation, Inc., 51 Franklin Street, Fifth Floor,
   Boston, MA 02111 USA.

*/
#import "common.h"
#include <string.h>
#include <ctype.h>
#import "Foundation/NSException.h"
#import "GNUstepBase/NSString+GNUstepBase.h"
#import "GNUstepBase/NSMutableString+GNUstepBase.h"

/* Test for ASCII whitespace which is safe for unicode characters */
#define	space(C)	((C) > 127 ? NO : isspace(C))

/**
 * GNUstep specific (non-standard) additions to the NSString class.
 */
@implementation NSString (GNUstepBase)

/**
 * Returns an autoreleased string initialized with -initWithFormat:arguments:.
 */
+ (id) stringWithFormat: (NSString*)format
	      arguments: (va_list)argList
{
  return AUTORELEASE([[self allocWithZone: NSDefaultMallocZone()]
    initWithFormat: format arguments: argList]);
}

#ifndef MAC_OS_X_VERSION_10_5
/**
 * Returns YES when scanning the receiver's text from left to right finds a
 * digit in the range 1-9 or a letter in the set ('Y', 'y', 'T', 't').<br />
 * Any trailing characters are ignored.<br />
 * Any leading whitespace or zeros or signs are also ignored.<br />
 * Returns NO if the above conditions are not met.
 */
- (BOOL) boolValue
{
  static NSCharacterSet *yes = nil;

  if (yes == nil)
    {
      yes = RETAIN([NSCharacterSet characterSetWithCharactersInString:
      @"123456789yYtT"]);
    }
  if ([self rangeOfCharacterFromSet: yes].length > 0)
    {
      return YES;
    }
  return NO;
}
#endif

/**
 * Returns a string formed by removing the prefix string from the
 * receiver.  Raises an exception if the prefix is not present.
 */
- (NSString*) stringByDeletingPrefix: (NSString*)prefix
{
  NSCAssert2([self hasPrefix: prefix],
    @"'%@' does not have the prefix '%@'", self, prefix);
  return [self substringFromIndex: [prefix length]];
}

/**
 * Returns a string formed by removing the suffix string from the
 * receiver.  Raises an exception if the suffix is not present.
 */
- (NSString*) stringByDeletingSuffix: (NSString*)suffix
{
  NSCAssert2([self hasSuffix: suffix],
    @"'%@' does not have the suffix '%@'", self, suffix);
  return [self substringToIndex: ([self length] - [suffix length])];
}

/**
 * Returns a string formed by removing leading white space from the
 * receiver.
 */
- (NSString*) stringByTrimmingLeadSpaces
{
  unsigned	length = [self length];

  if (length > 0)
    {
      unsigned	start = 0;
      unichar	(*caiImp)(NSString*, SEL, NSUInteger);
      SEL caiSel = @selector(characterAtIndex:);

      caiImp = (unichar (*)())[self methodForSelector: caiSel];
      while (start < length && space((*caiImp)(self, caiSel, start)))
	{
	  start++;
	}
      if (start > 0)
	{
	  return [self substringFromIndex: start];
	}
    }
  return self;
}

/**
 * Returns a string formed by removing trailing white space from the
 * receiver.
 */
- (NSString*) stringByTrimmingTailSpaces
{
  unsigned	length = [self length];

  if (length > 0)
    {
      unsigned	end = length;
      unichar	(*caiImp)(NSString*, SEL, NSUInteger);
      SEL caiSel = @selector(characterAtIndex:);

      caiImp = (unichar (*)())[self methodForSelector: caiSel];
      while (end > 0)
	{
	  if (!space((*caiImp)(self, caiSel, end - 1)))
	    {
	      break;
	    }
	  end--;
	}
      if (end < length)
	{
	  return [self substringToIndex: end];
	}
    }
  return self;
}

/**
 * Returns a string formed by removing both leading and trailing
 * white space from the receiver.
 */
- (NSString*) stringByTrimmingSpaces
{
  unsigned	length = [self length];

  if (length > 0)
    {
      unsigned	start = 0;
      unsigned	end = length;
      unichar	(*caiImp)(NSString*, SEL, NSUInteger);
      SEL caiSel = @selector(characterAtIndex:);

      caiImp = (unichar (*)())[self methodForSelector: caiSel];
      while (start < length && space((*caiImp)(self, caiSel, start)))
	{
	  start++;
	}
      while (end > start)
	{
	  if (!space((*caiImp)(self, caiSel, end - 1)))
	    {
	      break;
	    }
	  end--;
	}
      if (start > 0 || end < length)
	{
          if (start < end)
	    {
	      return [self substringFromRange:
		NSMakeRange(start, end - start)];
	    }
          else
	    {
	      return [NSString string];
	    }
	}
    }
  return self;
}

/**
 * Returns a string in which any (and all) occurrences of
 * replace in the receiver have been replaced with by.
 * Returns the receiver if replace
 * does not occur within the receiver.  NB. an empty string is
 * not considered to exist within the receiver.
 */
- (NSString*) stringByReplacingString: (NSString*)replace
			   withString: (NSString*)by
{
  NSRange range = [self rangeOfString: replace];

  if (range.length > 0)
    {
      NSMutableString	*tmp = [self mutableCopy];
      NSString		*str;

      [tmp replaceString: replace withString: by];
      str = AUTORELEASE([tmp copy]);
      RELEASE(tmp);
      return str;
    }
  else
    return self;
}

- (NSString*) substringFromRange:(NSRange)range
{
  return [self substringWithRange:range];
}

/**
 * Returns an NSStringEncoding from the given name or 
 * GSUndefinedEncoding / 0 if not found.
 * This code is used in GDL and GSWeb
 * It is here to avoid copy+paste code.
 */

+ (NSStringEncoding) encodingNamed:(NSString*) encName
{
  
  if ((!encName) || ([encName length] < 18)) {
    return 0;
  }

  // the most common on top
  if ([encName isEqual:@"NSUTF8StringEncoding"]) {
    return NSUTF8StringEncoding;
  }
  
  if ([encName isEqual:@"NSASCIIStringEncoding"]) {
    return NSASCIIStringEncoding;
  }

  if ([encName isEqual:@"NSNEXTSTEPStringEncoding"]) {
    return NSNEXTSTEPStringEncoding;
  }

  if ([encName isEqual:@"NSJapaneseEUCStringEncoding"]) {
    return NSJapaneseEUCStringEncoding;
  }
    
  if ([encName isEqual:@"NSISOLatin1StringEncoding"]) {
    return NSISOLatin1StringEncoding;
  }
  
  if ([encName isEqual:@"NSSymbolStringEncoding"]) {
    return NSSymbolStringEncoding;
  }
  
  if ([encName isEqual:@"NSNonLossyASCIIStringEncoding"]) {
    return NSNonLossyASCIIStringEncoding;
  }
  
  if ([encName isEqual:@"NSShiftJISStringEncoding"]) {
    return NSShiftJISStringEncoding;
  }
  
  if ([encName isEqual:@"NSUnicodeStringEncoding"]) {
    return NSUnicodeStringEncoding;
  }
  
  if ([encName isEqual:@"NSUTF16StringEncoding"]) {
    return NSUTF16StringEncoding;
  }
  
  if ([encName isEqual:@"NSWindowsCP1251StringEncoding"]) {
    return NSWindowsCP1251StringEncoding;
  }
  
  if ([encName isEqual:@"NSWindowsCP1252StringEncoding"]) {
    return NSWindowsCP1252StringEncoding;
  }

  if ([encName isEqual:@"NSWindowsCP1253StringEncoding"]) {
    return NSWindowsCP1253StringEncoding;
  }

  if ([encName isEqual:@"NSWindowsCP1254StringEncoding"]) {
    return NSWindowsCP1254StringEncoding;
  }
  
  if ([encName isEqual:@"NSWindowsCP1250StringEncoding"]) {
    return NSWindowsCP1250StringEncoding;
  }

  if ([encName isEqual:@"NSISO2022JPStringEncoding"]) {
    return NSISO2022JPStringEncoding;
  }

  if ([encName isEqual:@"NSMacOSRomanStringEncoding"]) {
    return NSMacOSRomanStringEncoding;
  }
  
  // does anybody need NSProprietaryStringEncoding?

#ifdef NSKOI8RStringEncoding
  if ([encName isEqual:@"NSKOI8RStringEncoding"]) {
    return NSKOI8RStringEncoding;
  }
#endif
  
#ifdef NSKOI8RStringEncoding
  if ([encName isEqual:@"NSISOLatin3StringEncoding"]) {
    return NSISOLatin3StringEncoding;
  }
#endif
  
#ifdef NSISOLatin4StringEncoding
  if ([encName isEqual:@"NSISOLatin4StringEncoding"]) {
    return NSISOLatin4StringEncoding;
  }
#endif

#ifdef NSISOCyrillicStringEncoding
  if ([encName isEqual:@"NSISOCyrillicStringEncoding"]) {
    return NSISOCyrillicStringEncoding;
  }
#endif

#ifdef NSISOArabicStringEncoding
  if ([encName isEqual:@"NSISOArabicStringEncoding"]) {
    return NSISOArabicStringEncoding;
  }
#endif

#ifdef NSISOGreekStringEncoding
  if ([encName isEqual:@"NSISOGreekStringEncoding"]) {
    return NSISOGreekStringEncoding;
  }
#endif

#ifdef NSISOHebrewStringEncoding
  if ([encName isEqual:@"NSISOHebrewStringEncoding"]) {
    return NSISOHebrewStringEncoding;
  }
#endif

#ifdef NSISOLatin5StringEncoding
  if ([encName isEqual:@"NSISOLatin5StringEncoding"]) {
    return NSISOLatin5StringEncoding;
  }
#endif

#ifdef NSISOLatin6StringEncoding
  if ([encName isEqual:@"NSISOLatin6StringEncoding"]) {
    return NSISOLatin6StringEncoding;
  }
#endif

#ifdef NSISOThaiStringEncoding
  if ([encName isEqual:@"NSISOThaiStringEncoding"]) {
    return NSISOThaiStringEncoding;
  }
#endif

#ifdef NSISOLatin7StringEncoding
  if ([encName isEqual:@"NSISOLatin7StringEncoding"]) {
    return NSISOLatin7StringEncoding;
  }
#endif

#ifdef NSISOLatin8StringEncoding
  if ([encName isEqual:@"NSISOLatin8StringEncoding"]) {
    return NSISOLatin8StringEncoding;
  }
#endif

#ifdef NSISOLatin9StringEncoding
  if ([encName isEqual:@"NSISOLatin9StringEncoding"]) {
    return NSISOLatin9StringEncoding;
  }
#endif

#ifdef NSGB2312StringEncoding
  if ([encName isEqual:@"NSGB2312StringEncoding"]) {
    return NSGB2312StringEncoding;
  }
#endif

#ifdef NSUTF7StringEncoding
  if ([encName isEqual:@"NSUTF7StringEncoding"]) {
    return NSUTF7StringEncoding;
  }
#endif

#ifdef NSGSM0338StringEncoding
  if ([encName isEqual:@"NSGSM0338StringEncoding"]) {
    return NSGSM0338StringEncoding;
  }
#endif

#ifdef NSBIG5StringEncoding
  if ([encName isEqual:@"NSBIG5StringEncoding"]) {
    return NSBIG5StringEncoding;
  }
#endif

#ifdef NSKoreanEUCStringEncoding
  if ([encName isEqual:@"NSKoreanEUCStringEncoding"]) {
    return NSKoreanEUCStringEncoding;
  }
#endif

#if OS_API_VERSION(100400,GS_API_LATEST) 

  if ([encName isEqual:@"NSUTF16BigEndianStringEncoding"]) {
    return NSUTF16BigEndianStringEncoding;
  }

  if ([encName isEqual:@"NSUTF16LittleEndianStringEncoding"]) {
    return NSUTF16LittleEndianStringEncoding;
  }

  if ([encName isEqual:@"NSUTF32StringEncoding"]) {
    return NSUTF32StringEncoding;
  }

  if ([encName isEqual:@"NSUTF32BigEndianStringEncoding"]) {
    return NSUTF32BigEndianStringEncoding;
  }
  
  if ([encName isEqual:@"NSUTF32LittleEndianStringEncoding"]) {
    return NSUTF32LittleEndianStringEncoding;
  }
  
#endif
  return 0;
}

@end
