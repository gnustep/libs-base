/* Implemenation of NSScanner class
   Copyright (C) 1996 Free Software Foundation, Inc.

   Author:  Eric Norum <eric@skatter.usask.ca>
   Date: 1996
   
   This file is part of the GNUstep Objective-C Library.

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

#include <config.h>
#include <base/fast.x>
#include <Foundation/NSScanner.h>
#include <Foundation/NSException.h>
#include <Foundation/NSGString.h>
#include <Foundation/NSUserDefaults.h>
#include <float.h>
#include <limits.h>
#include <math.h>
#include <ctype.h>    /* FIXME: May go away once I figure out Unicode */

@implementation NSScanner

static Class		NSString_class;
static Class		NSGString_class;
static NSCharacterSet	*defaultSkipSet;
static SEL		memSel = @selector(characterIsMember:);

/*
 * Hack for direct access to internals of an NSGString object.
 */
typedef struct {
  @defs(NSGString)
} *stringAccess;
#define	charAtIndex(I)	((stringAccess)string)->_contents_chars[I]

+ (void) initialize
{
  if (self == [NSScanner class])
    {
      defaultSkipSet = [NSCharacterSet whitespaceAndNewlineCharacterSet];
      RETAIN(defaultSkipSet);
      NSString_class = [NSString class];
      NSGString_class = [NSGString class];
    }
}

/*
 * Create and return a scanner that scans aString.
 */
+ (id) scannerWithString: (NSString *)aString
{
  return AUTORELEASE([[self alloc] initWithString: aString]);
}

+ (id) localizedScannerWithString: (NSString*)aString
{
  NSScanner		*scanner = [self scannerWithString: aString];
  NSUserDefaults	*defs = [NSUserDefaults standardUserDefaults];

  scanner->locale = RETAIN([defs dictionaryRepresentation]);
  return scanner;
}

/*
 * Initialize a a newly-allocated scanner to scan aString.
 * Returns self.
 */
- (id) initWithString: (NSString *)aString
{
  [super init];
  /*
   * Ensure that we have an NSGString so we can access its internals directly.
   */
  if (fastClass(aString) == NSGString_class)
    string = RETAIN(aString);
  else if ([aString isKindOfClass: NSString_class])
    string = [[NSGString_class alloc] initWithString: aString];
  else
    {
      [self dealloc];
      [NSException raise: NSInvalidArgumentException
		  format: @"Scanner initialised with something not a string"];
    }
  len = [string length];
  charactersToBeSkipped = RETAIN(defaultSkipSet);
  return self;
}

/*
 * Deallocate a scanner and all its associated storage.
 */
- (void) dealloc
{
  RELEASE(string);
  TEST_RELEASE(locale);
  RELEASE(charactersToBeSkipped);
  [super dealloc];
}

/*
 * Like scanCharactersFromSet: intoString: but no initial skip
 * For internal use only.
 */
- (BOOL) _scanCharactersFromSet: (NSCharacterSet *)set
		     intoString: (NSString **)value;
{
  unsigned int	start;
  BOOL		(*memImp)(NSCharacterSet*, SEL, unichar);

  if (scanLocation >= len)
    return NO;
  memImp = (BOOL (*)(NSCharacterSet*, SEL, unichar))
    [set methodForSelector: memSel];
  start = scanLocation;
  while (scanLocation < len)
    {
      if ((*memImp)(set, memSel, charAtIndex(scanLocation)) == NO)
	break;
      scanLocation++;
    }
  if (scanLocation == start)
    return NO;
  if (value)
    {
      NSRange range;
      range.location = start;
      range.length = scanLocation - start;
      *value = [string substringFromRange: range];
    }
  return YES;
}

/*
 * Scan characters to be skipped.
 * Return YES if there are more characters to be scanned.
 * Return NO if the end of the string is reached.
 * For internal use only.
 */
- (BOOL) _skipToNextField
{
  [self _scanCharactersFromSet: charactersToBeSkipped intoString: NULL];
  if (scanLocation >= len)
    return NO;
  return YES;
}

/*
 * Returns YES if no more characters remain to be scanned.
 * Returns YES if all characters remaining to be scanned are to be skipped.
 * Returns NO if there are characters left to scan.
 */
- (BOOL) isAtEnd
{
  unsigned int save_scanLocation;
  BOOL ret;

  if (scanLocation >= len)
    return YES;
  save_scanLocation = scanLocation;
  ret = ![self _skipToNextField];
  scanLocation = save_scanLocation;
  return ret;
}

/*
 * Internal version of scanInt: method.
 * Does the actual work for scanInt: except for the initial skip.
 * For internal use only.  This method may move the scan location
 * even if a valid integer is not scanned.
 * Based on the strtol code from the GNU C library.  A little simpler since
 * we deal only with base 10.
 * FIXME: I don't use the decimalDigitCharacterSet here since it
 * includes many more characters than the ASCII digits.  I don't
 * know how to convert those other characters, so I ignore them
 * for now.  For the same reason, I don't try to support all the
 * possible Unicode plus and minus characters.
 */
- (BOOL) _scanInt: (int*)value
{
  unsigned int num = 0;
  const unsigned int limit = UINT_MAX / 10;
  BOOL negative = NO;
  BOOL overflow = NO;
  BOOL got_digits = NO;

  /* Check for sign */
  if (scanLocation < len)
    {
      switch (charAtIndex(scanLocation))
	{
	  case '+': 
	    scanLocation++;
	    break;
	  case '-': 
	    negative = YES;
	    scanLocation++;
	    break;
	}
    }

  /* Process digits */
  while (scanLocation < len)
    {
      unichar digit = charAtIndex(scanLocation);
      if ((digit < '0') || (digit > '9'))
	break;
      if (!overflow) {
	if (num >= limit)
	  overflow = YES;
	else
	  num = num * 10 + (digit - '0');
      }
      scanLocation++;
      got_digits = YES;
    }

  /* Save result */
  if (!got_digits)
    return NO;
  if (value)
    {
      if (overflow
	|| (num > (negative ? (unsigned int)INT_MIN : (unsigned int)INT_MAX)))
	*value = negative ? INT_MIN: INT_MAX;
      else if (negative)
	*value = -num;
      else
	*value = num;
    }
  return YES;
}

/*
 * Scan an int into value.
 */
- (BOOL) scanInt: (int*)value
{
  unsigned int saveScanLocation = scanLocation;

  if ([self _skipToNextField] && [self _scanInt: value])
    return YES;
  scanLocation = saveScanLocation;
  return NO;
}

/*
 * Scan an unsigned int of the given radix into value.
 * Internal version used by scanRadixUnsignedInt: and scanHexInt: .
 */
- (BOOL) scanUnsignedInt_: (unsigned int *)value
		    radix: (int)radix
		gotDigits: (BOOL)gotDigits
{
  unsigned int num = 0;
  unsigned int numLimit, digitLimit, digitValue;
  BOOL overflow = NO;
  unsigned int saveScanLocation = scanLocation;

  /* Set limits */
  numLimit = UINT_MAX / radix;
  digitLimit = UINT_MAX % radix;

  /* Process digits */
  while (scanLocation < len)
    {
      unichar digit = charAtIndex(scanLocation);
      switch (digit)
	{
	  case '0': digitValue = 0; break;
	  case '1': digitValue = 1; break;
	  case '2': digitValue = 2; break;
	  case '3': digitValue = 3; break;
	  case '4': digitValue = 4; break;
	  case '5': digitValue = 5; break;
	  case '6': digitValue = 6; break;
	  case '7': digitValue = 7; break;
	  case '8': digitValue = 8; break;
	  case '9': digitValue = 9; break;
	  case 'a': digitValue = 0xA; break;
	  case 'b': digitValue = 0xB; break;
	  case 'c': digitValue = 0xC; break;
	  case 'd': digitValue = 0xD; break;
	  case 'e': digitValue = 0xE; break;
	  case 'f': digitValue = 0xF; break;
	  case 'A': digitValue = 0xA; break;
	  case 'B': digitValue = 0xB; break;
	  case 'C': digitValue = 0xC; break;
	  case 'D': digitValue = 0xD; break;
	  case 'E': digitValue = 0xE; break;
	  case 'F': digitValue = 0xF; break;
	  default: 
	    digitValue = radix;
	    break;
	}
      if (digitValue >= radix)
	break;
      if (!overflow)
	{
	  if ((num > numLimit)
	    || ((num == numLimit) && (digitValue > digitLimit)))
	    overflow = YES;
	  else
	    num = num * radix + digitValue;
	}
      scanLocation++;
      gotDigits = YES;
    }

  /* Save result */
  if (!gotDigits)
    {
      scanLocation = saveScanLocation;
      return NO;
    }
  if (value)
    {
      if (overflow)
	*value = UINT_MAX;
      else
	*value = num;
    }
  return YES;
}

/*
 * Scan an unsigned int of the given radix into value.
 */
- (BOOL) scanRadixUnsignedInt: (unsigned int *)value
{
  int radix;
  BOOL gotDigits = NO;
  unsigned int saveScanLocation = scanLocation;

  /* Skip whitespace */
  if (![self _skipToNextField])
    {
      scanLocation = saveScanLocation;
      return NO;
    }

  /* Check radix */
  radix = 10;
  if ((scanLocation < len) && (charAtIndex(scanLocation) == '0'))
    {
      radix = 8;
      scanLocation++;
      gotDigits = YES;
      if (scanLocation < len)
	{
	  switch (charAtIndex(scanLocation))
	    {
	      case 'x': 
	      case 'X': 
		scanLocation++;
		radix = 16;
		gotDigits = NO;
		break;
	    }
	}
    }
  if ( [self scanUnsignedInt_: value radix: radix gotDigits: gotDigits])
    return YES;
  scanLocation = saveScanLocation;
  return NO;
}

/*
 * Scan a hexadecimal unsigned integer into value.
 */
- (BOOL) scanHexInt: (unsigned int *)value
{
  unsigned int saveScanLocation = scanLocation;

  /* Skip whitespace */
  if (![self _skipToNextField])
    {
      scanLocation = saveScanLocation;
      return NO;
    }
  if ([self scanUnsignedInt_: value radix: 16 gotDigits: NO])
    return YES;
  scanLocation = saveScanLocation;
  return NO;
}

/*
 * Scan a long long int into value.
 * Same as scanInt, except with different variable types and limits.
 */
- (BOOL) scanLongLong: (long long *)value
{
#if defined(LONG_LONG_MAX)
  unsigned long long num = 0;
  const unsigned long long limit = ULONG_LONG_MAX / 10;
  BOOL negative = NO;
  BOOL overflow = NO;
  BOOL got_digits = NO;
  unsigned int saveScanLocation = scanLocation;

  /* Skip whitespace */
  if (![self _skipToNextField])
    {
      scanLocation = saveScanLocation;
      return NO;
    }

  /* Check for sign */
  if (scanLocation < len)
    {
      switch (charAtIndex(scanLocation))
	{
	  case '+': 
	    scanLocation++;
	    break;
	  case '-': 
	    negative = YES;
	    scanLocation++;
	    break;
	}
    }

    /* Process digits */
  while (scanLocation < len)
    {
      unichar digit = charAtIndex(scanLocation);
      if ((digit < '0') || (digit > '9'))
	break;
      if (!overflow) {
	if (num >= limit)
	  overflow = YES;
	else
	  num = num * 10 + (digit - '0');
      }
      scanLocation++;
      got_digits = YES;
    }

    /* Save result */
  if (!got_digits)
    {
      scanLocation = saveScanLocation;
      return NO;
    }
  if (value)
    {
      if (overflow || (num > (negative ? (unsigned long long)LONG_LONG_MIN : (unsigned long long)LONG_LONG_MAX)))
	*value = negative ? LONG_LONG_MIN: LONG_LONG_MAX;
      else if (negative)
	*value = -num;
      else
	*value = num;
    }
  return YES;
#else /* defined(LONG_LONG_MAX) */
  /*
   * Provide compile-time warning and run-time exception.
   */
#    warning "Can't use long long variables."
  [NSException raise: NSGenericException
	       format: @"Can't use long long variables."];
  return NO;
#endif /* defined(LONG_LONG_MAX) */
}

/*
 * Scan a double into value.
 * Returns YES if a valid floating-point expression was scanned. 
 * Returns NO otherwise.
 * On overflow, HUGE_VAL or -HUGE_VAL is put into value and YES is returned.
 * On underflow, 0.0 is put into value and YES is returned.
 * Based on the strtod code from the GNU C library.
 */
- (BOOL) scanDouble: (double *)value
{
  unichar	decimal = '.';
  unichar	c = 0;
  double	num = 0.0;
  long int	exponent = 0;
  BOOL		negative = NO;
  BOOL		got_dot = NO;
  BOOL		got_digit = NO;
  unsigned int	saveScanLocation = scanLocation;

  /* Skip whitespace */
  if (![self _skipToNextField])
    {
      scanLocation = saveScanLocation;
      return NO;
    }

  /*
   * Get decimal point character from locale if necessary.
   */
  if (locale != nil)
    {
      NSString	*pointString;

      pointString = [locale objectForKey: NSDecimalSeparator];
      if ([pointString length] > 0)
	decimal = [pointString characterAtIndex: 0];
    }

  /* Check for sign */
  if (scanLocation < len)
    {
      switch (charAtIndex(scanLocation))
	{
	  case '+': 
	    scanLocation++;
	    break;
	  case '-': 
	    negative = YES;
	    scanLocation++;
	    break;
	}
    }

    /* Process number */
  while (scanLocation < len)
    {
      c = charAtIndex(scanLocation);
      if ((c >= '0') && (c <= '9'))
	{
	  /* Ensure that the number being accumulated will not overflow. */
	  if (num >= (DBL_MAX / 10.000000001))
	    {
	      ++exponent;
	    }
	  else
	    {
	      num = (num * 10.0) + (c - '0');
	      got_digit = YES;
	    }
            /* Keep track of the number of digits after the decimal point.
	       If we just divided by 10 here, we would lose precision. */
	  if (got_dot)
	    --exponent;
        }
      else if (!got_dot && (c == decimal))
	{
	  /* Note that we have found the decimal point. */
	  got_dot = YES;
        }
      else
	{
	  /* Any other character terminates the number. */
	  break;
        }
      scanLocation++;
    }
  if (!got_digit)
    {
      scanLocation = saveScanLocation;
      return NO;
    }

  /* Check for trailing exponent */
  if ((scanLocation < len) && ((c == 'e') || (c == 'E')))
    {
      int expval;

      scanLocation++;
      if ([self _scanInt: &expval])
	{
      /* Check for exponent overflow */
	if (num)
	  {
	    if ((exponent > 0) && (expval > (LONG_MAX - exponent)))
	      exponent = LONG_MAX;
	    else if ((exponent < 0) && (expval < (LONG_MIN - exponent)))
	      exponent = LONG_MIN;
	    else
	      exponent += expval;
	  }
	}
      else
	{
#ifdef _ACCEPT_BAD_EXPONENTS_
	  /* Numbers like 1.23eFOO are accepted (as 1.23). */
	  scanLocation = expScanLocation;
#else
	  /* Numbers like 1.23eFOO are rejected. */
	  scanLocation = saveScanLocation;
	  return NO;
#endif
	}
    }
  if (value)
    {
      if (num && exponent)
	num *= pow(10.0, (double) exponent);
      if (negative)
	*value = -num;
      else
	*value = num;
    }
  return YES;
}

/*
 * Scan a float into value.
 * Returns YES if a valid floating-point expression was scanned. 
 * Returns NO otherwise.
 * On overflow, HUGE_VAL or -HUGE_VAL is put into value and YES is returned.
 * On underflow, 0.0 is put into value and YES is returned.
 */
- (BOOL) scanFloat: (float*)value
{
  double num;
  
  if (value == NULL)
    return [self scanDouble: NULL];
  if ([self scanDouble: &num])
    {
      *value = num;
      return YES;
    }
  return NO;
}
    
/*
 * Scan as long as characters from aSet are encountered.
 * Returns YES if any characters were scanned.
 * Returns NO if no characters were scanned.
 * If value is non-NULL, and any characters were scanned, a string
 * containing the scanned characters is returned by reference in value.
 */
- (BOOL) scanCharactersFromSet: (NSCharacterSet *)aSet 
		    intoString: (NSString **)value;
{
  unsigned int saveScanLocation = scanLocation;

  if ([self _skipToNextField]
      && [self _scanCharactersFromSet: aSet intoString: value])
    return YES;
  scanLocation = saveScanLocation;
  return NO;
}

/*
 * Scan until a character from aSet is encountered.
 * Returns YES if any characters were scanned.
 * Returns NO if no characters were scanned.
 * If value is non-NULL, and any characters were scanned, a string
 * containing the scanned characters is returned by reference in value.
 */
- (BOOL) scanUpToCharactersFromSet: (NSCharacterSet *)set 
		       intoString: (NSString **)value;
{
  unsigned int	saveScanLocation = scanLocation;
  unsigned int	start;
  BOOL		(*memImp)(NSCharacterSet*, SEL, unichar);

  if (![self _skipToNextField])
    return NO;
  start = scanLocation;
  memImp = (BOOL (*)(NSCharacterSet*, SEL, unichar))
    [set methodForSelector: memSel];
  while (scanLocation < len)
    {
      if ((*memImp)(set, memSel, charAtIndex(scanLocation)) == YES)
	break;
      scanLocation++;
    }
  if (scanLocation == start)
    {
      scanLocation = saveScanLocation;
      return NO;
    }
  if (value)
    {
      NSRange range;
      range.location = start;
      range.length = scanLocation - start;
      *value = [string substringFromRange: range];
    }
  return YES;
}

/*
 * Scans for aString.
 * Returns YES if the characters at the scan location match aString.
 * Returns NO if the characters at the scan location do not match aString.
 * If the characters at the scan location match aString.
 * If value is non-NULL, and the characters at the scan location match aString,
 * a string containing the matching string is returned by reference in value.
 */
- (BOOL) scanString: (NSString *)aString intoString: (NSString **)value;
{
  NSRange range;
  unsigned int saveScanLocation = scanLocation;
    
  [self _skipToNextField];
  range.location = scanLocation;
  range.length = [aString length];
  if (range.location + range.length > len)
    return NO;
  range = [string rangeOfString: aString
			options: caseSensitive ? 0 : NSCaseInsensitiveSearch
			  range: range];
  if (range.length == 0)
    {
      scanLocation = saveScanLocation;
      return NO;
    }
  if (value)
    *value = [string substringFromRange: range];
  scanLocation += range.length;
  return YES;
}

/*
 * Scans the string until aString is encountered..
 * Returns YES if any characters were scanned.
 * Returns NO if no characters were scanned.
 * If value is non-NULL, and any characters were scanned, a string
 * containing the scanned characters is returned by reference in value.
 */
- (BOOL) scanUpToString: (NSString *)aString 
	    intoString: (NSString **)value;
{
  NSRange range;
  NSRange found;
  unsigned int saveScanLocation = scanLocation;
    
  [self _skipToNextField];
  range.location = scanLocation;
  range.length = len - scanLocation;
  found = [string rangeOfString: aString
			options: caseSensitive ? 0 : NSCaseInsensitiveSearch
			  range: range];
  if (found.length)
    range.length = found.location - scanLocation;
  if (range.length == 0)
    {
      scanLocation = saveScanLocation;
      return NO;
    }
  if (value)
    *value = [string substringFromRange: range];
  scanLocation += range.length;
  return YES;
}

/*
 * Returns the string being scanned.
 */
- (NSString *) string
{
  return string;
}

/*
 * Returns the character index at which the scanner
 * will begin the next scanning operation.
 */
- (unsigned) scanLocation
{
  return scanLocation;
}

/*
 * Set the character location at which the scanner
 * will begin the next scanning operation to anIndex.
 */
- (void) setScanLocation: (unsigned int)anIndex
{
  scanLocation = anIndex;
}

/*
 * Returns YES if the scanner makes a distinction
 * between upper and lower case characters.
 */
- (BOOL) caseSensitive
{
  return caseSensitive;
}

/*
 * If flag is YES the scanner will consider upper and lower case
 * to be the same during scanning.  If flag is NO the scanner will
 * not make a distinction between upper and lower case characters.
 */
- (void) setCaseSensitive: (BOOL)flag
{
  caseSensitive = flag;
}

/*
 * Return a character set object containing the characters the scanner
 * will ignore when searching for the next element to be scanned.
 */
- (NSCharacterSet *) charactersToBeSkipped
{
  return charactersToBeSkipped;
}

/*
 * Set the characters to be ignored when the scanner
 * searches for the next element to be scanned.
 */
- (void) setCharactersToBeSkipped: (NSCharacterSet *)aSet
{
  ASSIGNCOPY(charactersToBeSkipped, aSet);
}

/*
 * Returns a dictionary object containing the locale
 * information used by the scanner.
 */
- (NSDictionary *) locale
{
  return locale;
}

/*
 * Set the dictionary containing the locale
 * information used by the scanner to localeDictionary.
 */
- (void) setLocale: (NSDictionary *)localeDictionary
{
  ASSIGN(locale, localeDictionary);
}

/*
 * NSCopying protocol
 */
- (id) copyWithZone: (NSZone *)zone
{
  NSScanner *n = [[self class] allocWithZone: zone];

  [n initWithString: string];
  [n setCharactersToBeSkipped: charactersToBeSkipped];
  [n setLocale: locale];
  [n setScanLocation: scanLocation];
  [n setCaseSensitive: caseSensitive];
  return n;
}

@end
