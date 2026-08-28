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
   Software Foundation, Inc., 31 Milk Street #960789 Boston, MA 02196 USA.

*/
#import "common.h"
#include <ctype.h>
#import "Foundation/NSArray.h"
#import "Foundation/NSException.h"
#import "Foundation/NSFileManager.h"
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

- (NSString*) pathRelativeTo: (NSString*)aFolder
{
  NSString	*filePath = self;
  NSString	*relative;
  NSString	*common;
  NSUInteger	length;
  NSUInteger	count;

  if ([aFolder length] == 0)
    {
      aFolder = [[NSFileManager defaultManager] currentDirectoryPath];
    }
  else if ([aFolder isAbsolutePath] == NO)
    {
      aFolder = [[[NSFileManager defaultManager] currentDirectoryPath]
	stringByAppendingPathComponent: aFolder];
    }
  aFolder = [aFolder stringByStandardizingPath];
  if ([aFolder hasSuffix: @"/"] == NO)
    {
      aFolder = [aFolder stringByAppendingString: @"/"];
    }

  if ([filePath length] == 0)
    {
      filePath = [[NSFileManager defaultManager] currentDirectoryPath];
    }
  else if ([filePath isAbsolutePath] == NO)
    {
      filePath = [[[NSFileManager defaultManager] currentDirectoryPath]
	stringByAppendingPathComponent: filePath];
    }
  filePath = [filePath stringByStandardizingPath];

  common = [filePath commonPrefixWithString: aFolder options: NSLiteralSearch];
  length = [common length];
  while (length > 0 && [common characterAtIndex: length - 1] != '/')
    {
      length--;
    }
  if (0 == length)
    {
      /* I guess this can happen on windows where paths are on different disks.
       */
      NSLog(@"Unable to make relative string because paths '%@' and '%@'"
	@" share no common prefix.", filePath, aFolder);
      return nil;
    }

  /* Get relative path from common root to our file.
   */
  relative = [filePath substringFromIndex: length];

  /* Find number of path components to step up to get to common root,
   * and prepend to relativew path.
   */
  count = [[[aFolder substringFromIndex: length]
    componentsSeparatedByString: @"/"] count];
  while (count-- > 1)
    {
      relative = [@"../" stringByAppendingString: relative];
    }
/*
NSLog(@"Adjust path from '%@' to '%@' (common '%@') as '%@'",
  aFolder, filePath, common, relative);
*/
  return relative;
}

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

@end
