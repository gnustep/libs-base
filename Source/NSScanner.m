/* Implemenation of NSScanner class
   Copyright (C) 1996,1999 Free Software Foundation, Inc.

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
#include <base/Unicode.h>
#include <Foundation/NSScanner.h>
#include <Foundation/NSException.h>
#include <Foundation/NSObjCRuntime.h>
#include <float.h>
#include <limits.h>
#include <math.h>
#include <ctype.h>    /* FIXME: May go away once I figure out Unicode */
#include "GSUserDefaults.h"

/* BSD and Solaris have this */
#if defined(HANDLE_LLONG_MAX) && !defined(HANDLE_LONG_LONG_MAX)
#define LONG_LONG_MAX LLONG_MAX
#define LONG_LONG_MIN LLONG_MIN
#define ULONG_LONG_MAX ULLONG_MAX
#endif

@implementation NSScanner

@class	GSCString;
@class	GSUnicodeString;
@class	GSMutableString;
@class	GSPlaceholderString;

static Class		NSStringClass;
static Class		GSCStringClass;
static Class		GSUnicodeStringClass;
static Class		GSMutableStringClass;
static Class		GSPlaceholderStringClass;
static Class		NSConstantStringClass;
static NSCharacterSet	*defaultSkipSet;
static SEL		memSel;

/*
 * Hack for direct access to internals of an concrete string object.
 */
typedef struct {
  @defs(GSString)
} *ivars;
#define	myLength()	(((ivars)_string)->_count)
#define	myUnicode(I)	(((ivars)_string)->_contents.u[I])
#define	myChar(I)	chartouni((((ivars)_string)->_contents.c[I]))
#define	myCharacter(I)	(_isUnicode ? myUnicode(I) : myChar(I))

/*
 * Scan characters to be skipped.
 * Return YES if there are more characters to be scanned.
 * Return NO if the end of the string is reached.
 * For internal use only.
 */
#define	skipToNextField()	({\
  while (_scanLocation < myLength() && _charactersToBeSkipped != nil \
    && (*_skipImp)(_charactersToBeSkipped, memSel, myCharacter(_scanLocation)))\
    _scanLocation++;\
  (_scanLocation >= myLength()) ? NO : YES;\
})

+ (void) initialize
{
  if (self == [NSScanner class])
    {
      memSel = @selector(characterIsMember:);
      defaultSkipSet = [NSCharacterSet whitespaceAndNewlineCharacterSet];
      IF_NO_GC(RETAIN(defaultSkipSet));
      NSStringClass = [NSString class];
      GSCStringClass = [GSCString class];
      GSUnicodeStringClass = [GSUnicodeString class];
      GSMutableStringClass = [GSMutableString class];
      GSPlaceholderStringClass = [GSPlaceholderString class];
      NSConstantStringClass = [NSString constantStringClass];
    }
}

/*
 * Create and return a scanner that scans aString.
 */
+ (id) scannerWithString: (NSString *)aString
{
  return AUTORELEASE([[self allocWithZone: NSDefaultMallocZone()]
    initWithString: aString]);
}

+ (id) localizedScannerWithString: (NSString*)aString
{
  NSScanner		*scanner = [self scannerWithString: aString];

  if (scanner != nil)
    {
      [scanner setLocale: GSUserDefaultsDictionaryRepresentation()];
    }
  return scanner;
}

/*
 * Initialize a a newly-allocated scanner to scan aString.
 * Returns self.
 */
- (id) initWithString: (NSString *)aString
{
  Class	c;

  if ((self = [super init]) == nil)
    return nil;
  /*
   * Ensure that we have a known string so we can access its internals directly.
   */
  if (aString == nil)
    {
      NSLog(@"Scanner initialised with nil string");
      aString = @"";
    }

  c = GSObjCClass(aString);
  if (GSObjCIsKindOf(c, GSUnicodeStringClass) == YES)
    {
      _isUnicode = YES;
      _string = RETAIN(aString);
    }
  else if (GSObjCIsKindOf(c, GSCStringClass) == YES)
    {
      _isUnicode = NO;
      _string = RETAIN(aString);
    }
  else if (GSObjCIsKindOf(c, GSMutableStringClass) == YES)
    {
      _string = (id)NSAllocateObject(GSPlaceholderStringClass, 0, 0);
      if (((ivars)aString)->_flags.wide == 1)
	{
	  _isUnicode = YES;
	  _string = [_string initWithCharacters: ((ivars)aString)->_contents.u
					 length: ((ivars)aString)->_count];
	}
      else
	{
	  _isUnicode = NO;
	  _string = [_string initWithCString: ((ivars)aString)->_contents.c
				      length: ((ivars)aString)->_count];
	}
    }
  else if (c == NSConstantStringClass)
    {
      _isUnicode = NO;
      _string = RETAIN(aString);
    }
  else if ([aString isKindOfClass: NSStringClass])
    {
      _isUnicode = YES;
      _string = (id)NSAllocateObject(GSPlaceholderStringClass, 0, 0);
      _string = [_string initWithString: aString];
    }
  else
    {
      RELEASE(self);
      NSLog(@"Scanner initialised with something not a string");
      return nil;
    }
  [self setCharactersToBeSkipped: defaultSkipSet];
  _decimal = '.';
  return self;
}

/*
 * Deallocate a scanner and all its associated storage.
 */
- (void) dealloc
{
  RELEASE(_string);
  TEST_RELEASE(_locale);
  RELEASE(_charactersToBeSkipped);
  [super dealloc];
}

/*
 * Returns YES if no more characters remain to be scanned.
 * Returns YES if all characters remaining to be scanned are to be skipped.
 * Returns NO if there are characters left to scan.
 */
- (BOOL) isAtEnd
{
  unsigned int	save__scanLocation;
  BOOL		ret;

  if (_scanLocation >= myLength())
    return YES;
  save__scanLocation = _scanLocation;
  ret = !skipToNextField();
  _scanLocation = save__scanLocation;
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
  if (_scanLocation < myLength())
    {
      switch (myCharacter(_scanLocation))
	{
	  case '+': 
	    _scanLocation++;
	    break;
	  case '-': 
	    negative = YES;
	    _scanLocation++;
	    break;
	}
    }

  /* Process digits */
  while (_scanLocation < myLength())
    {
      unichar digit = myCharacter(_scanLocation);

      if ((digit < '0') || (digit > '9'))
	break;
      if (!overflow)
	{
	  if (num >= limit)
	    overflow = YES;
	  else
	    num = num * 10 + (digit - '0');
	}
      _scanLocation++;
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
  unsigned int saveScanLocation = _scanLocation;

  if (skipToNextField() && [self _scanInt: value])
    return YES;
  _scanLocation = saveScanLocation;
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
  unsigned int	num = 0;
  unsigned int	numLimit, digitLimit, digitValue;
  BOOL		overflow = NO;
  unsigned int	saveScanLocation = _scanLocation;

  /* Set limits */
  numLimit = UINT_MAX / radix;
  digitLimit = UINT_MAX % radix;

  /* Process digits */
  while (_scanLocation < myLength())
    {
      unichar digit = myCharacter(_scanLocation);

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
      _scanLocation++;
      gotDigits = YES;
    }

  /* Save result */
  if (!gotDigits)
    {
      _scanLocation = saveScanLocation;
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
  int		radix;
  BOOL		gotDigits = NO;
  unsigned int	saveScanLocation = _scanLocation;

  /* Skip whitespace */
  if (!skipToNextField())
    {
      _scanLocation = saveScanLocation;
      return NO;
    }

  /* Check radix */
  radix = 10;
  if ((_scanLocation < myLength()) && (myCharacter(_scanLocation) == '0'))
    {
      radix = 8;
      _scanLocation++;
      gotDigits = YES;
      if (_scanLocation < myLength())
	{
	  switch (myCharacter(_scanLocation))
	    {
	      case 'x': 
	      case 'X': 
		_scanLocation++;
		radix = 16;
		gotDigits = NO;
		break;
	    }
	}
    }
  if ( [self scanUnsignedInt_: value radix: radix gotDigits: gotDigits])
    return YES;
  _scanLocation = saveScanLocation;
  return NO;
}

/*
 * Scan a hexadecimal unsigned integer into value.
 */
- (BOOL) scanHexInt: (unsigned int *)value
{
  unsigned int saveScanLocation = _scanLocation;

  /* Skip whitespace */
  if (!skipToNextField())
    {
      _scanLocation = saveScanLocation;
      return NO;
    }

  if ((_scanLocation < myLength()) && (myCharacter(_scanLocation) == '0'))
    {
      _scanLocation++;
      if (_scanLocation < myLength())
	{
	  switch (myCharacter(_scanLocation))
	    {
	      case 'x': 
	      case 'X': 
		_scanLocation++;	// Scan beyond the 0x prefix
		break;
	      default:
		_scanLocation--;	// Scan from the initial digit
	        break;
	    }
	}
      else
	{
	  _scanLocation--;	// Just scan the zero.
	}
    }
  if ([self scanUnsignedInt_: value radix: 16 gotDigits: NO])
    return YES;
  _scanLocation = saveScanLocation;
  return NO;
}

/*
 * Scan a long long int into value.
 * Same as scanInt, except with different variable types and limits.
 */
- (BOOL) scanLongLong: (long long *)value
{
#if defined(LONG_LONG_MAX)
  unsigned long long		num = 0;
  const unsigned long long	limit = ULONG_LONG_MAX / 10;
  BOOL				negative = NO;
  BOOL				overflow = NO;
  BOOL				got_digits = NO;
  unsigned int			saveScanLocation = _scanLocation;

  /* Skip whitespace */
  if (!skipToNextField())
    {
      _scanLocation = saveScanLocation;
      return NO;
    }

  /* Check for sign */
  if (_scanLocation < myLength())
    {
      switch (myCharacter(_scanLocation))
	{
	  case '+': 
	    _scanLocation++;
	    break;
	  case '-': 
	    negative = YES;
	    _scanLocation++;
	    break;
	}
    }

    /* Process digits */
  while (_scanLocation < myLength())
    {
      unichar digit = myCharacter(_scanLocation);

      if ((digit < '0') || (digit > '9'))
	break;
      if (!overflow) {
	if (num >= limit)
	  overflow = YES;
	else
	  num = num * 10 + (digit - '0');
      }
      _scanLocation++;
      got_digits = YES;
    }

    /* Save result */
  if (!got_digits)
    {
      _scanLocation = saveScanLocation;
      return NO;
    }
  if (value)
    {
      if (negative)
	{
	  if (overflow || (num > (unsigned long long)LONG_LONG_MIN))
	    *value = LONG_LONG_MIN;
	  else
	    *value = -num;
	}
      else
	{
	  if (overflow || (num > (unsigned long long)LONG_LONG_MAX))
	    *value = LONG_LONG_MAX;
	  else
	    *value = num;
	}
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

- (BOOL) scanDecimal: (NSDecimal*)value
{
  [self notImplemented:_cmd];			/* FIXME */
  return NO;
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
  unichar	c = 0;
  double	num = 0.0;
  long int	exponent = 0;
  BOOL		negative = NO;
  BOOL		got_dot = NO;
  BOOL		got_digit = NO;
  unsigned int	saveScanLocation = _scanLocation;

  /* Skip whitespace */
  if (!skipToNextField())
    {
      _scanLocation = saveScanLocation;
      return NO;
    }

  /* Check for sign */
  if (_scanLocation < myLength())
    {
      switch (myCharacter(_scanLocation))
	{
	  case '+': 
	    _scanLocation++;
	    break;
	  case '-': 
	    negative = YES;
	    _scanLocation++;
	    break;
	}
    }

    /* Process number */
  while (_scanLocation < myLength())
    {
      c = myCharacter(_scanLocation);
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
      else if (!got_dot && (c == _decimal))
	{
	  /* Note that we have found the decimal point. */
	  got_dot = YES;
        }
      else
	{
	  /* Any other character terminates the number. */
	  break;
        }
      _scanLocation++;
    }
  if (!got_digit)
    {
      _scanLocation = saveScanLocation;
      return NO;
    }

  /* Check for trailing exponent */
  if ((_scanLocation < myLength()) && ((c == 'e') || (c == 'E')))
    {
      int expval;

      _scanLocation++;
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
	  _scanLocation = expScanLocation;
#else
	  /* Numbers like 1.23eFOO are rejected. */
	  _scanLocation = saveScanLocation;
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
  unsigned int	saveScanLocation = _scanLocation;

  if (skipToNextField())
    {
      unsigned int	start;
      BOOL		(*memImp)(NSCharacterSet*, SEL, unichar);

      if (aSet == _charactersToBeSkipped)
	memImp = _skipImp;
      else
	memImp = (BOOL (*)(NSCharacterSet*, SEL, unichar))
	  [aSet methodForSelector: memSel];

      start = _scanLocation;
      if (_isUnicode)
	{
	  while (_scanLocation < myLength())
	    {
	      if ((*memImp)(aSet, memSel, myUnicode(_scanLocation)) == NO)
		break;
	      _scanLocation++;
	    }
	}
      else
	{
	  while (_scanLocation < myLength())
	    {
	      if ((*memImp)(aSet, memSel, myChar(_scanLocation)) == NO)
		break;
	      _scanLocation++;
	    }
	}
      if (_scanLocation != start)
	{
	  if (value != 0)
	    {
	      NSRange	range;

	      range.location = start;
	      range.length = _scanLocation - start;
	      *value = [_string substringWithRange: range];
	    }
	  return YES;
	}
    }
  _scanLocation = saveScanLocation;
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
  unsigned int	saveScanLocation = _scanLocation;
  unsigned int	start;
  BOOL		(*memImp)(NSCharacterSet*, SEL, unichar);

  if (!skipToNextField())
    return NO;

  if (set == _charactersToBeSkipped)
    memImp = _skipImp;
  else
    memImp = (BOOL (*)(NSCharacterSet*, SEL, unichar))
      [set methodForSelector: memSel];

  start = _scanLocation;
  if (_isUnicode)
    {
      while (_scanLocation < myLength())
	{
	  if ((*memImp)(set, memSel, myUnicode(_scanLocation)) == YES)
	    break;
	  _scanLocation++;
	}
    }
  else
    {
      while (_scanLocation < myLength())
	{
	  if ((*memImp)(set, memSel, myChar(_scanLocation)) == YES)
	    break;
	  _scanLocation++;
	}
    }

  if (_scanLocation == start)
    {
      _scanLocation = saveScanLocation;
      return NO;
    }
  if (value)
    {
      NSRange	range;

      range.location = start;
      range.length = _scanLocation - start;
      *value = [_string substringWithRange: range];
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
  NSRange	range;
  unsigned int	saveScanLocation = _scanLocation;
    
  skipToNextField();
  range.location = _scanLocation;
  range.length = [aString length];
  if (range.location + range.length > myLength())
    return NO;
  range = [_string rangeOfString: aString
			options: _caseSensitive ? 0 : NSCaseInsensitiveSearch
			  range: range];
  if (range.length == 0)
    {
      _scanLocation = saveScanLocation;
      return NO;
    }
  if (value)
    *value = [_string substringWithRange: range];
  _scanLocation += range.length;
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
  NSRange	range;
  NSRange	found;
  unsigned int	saveScanLocation = _scanLocation;
    
  skipToNextField();
  range.location = _scanLocation;
  range.length = myLength() - _scanLocation;
  found = [_string rangeOfString: aString
			 options: _caseSensitive ? 0 : NSCaseInsensitiveSearch
			   range: range];
  if (found.length)
    range.length = found.location - _scanLocation;
  if (range.length == 0)
    {
      _scanLocation = saveScanLocation;
      return NO;
    }
  if (value)
    *value = [_string substringWithRange: range];
  _scanLocation += range.length;
  return YES;
}

/*
 * Returns the string being scanned.
 */
- (NSString *) string
{
  return _string;
}

/*
 * Returns the character index at which the scanner
 * will begin the next scanning operation.
 */
- (unsigned) scanLocation
{
  return _scanLocation;
}

/*
 * Set the character location at which the scanner
 * will begin the next scanning operation to anIndex.
 */
- (void) setScanLocation: (unsigned int)anIndex
{
  if (_scanLocation <= myLength())
    _scanLocation = anIndex;
  else
    [NSException raise: NSRangeException
		format: @"Attempt to set scan location beyond end of string"];
}

/*
 * Returns YES if the scanner makes a distinction
 * between upper and lower case characters.
 */
- (BOOL) caseSensitive
{
  return _caseSensitive;
}

/*
 * If flag is YES the scanner will consider upper and lower case
 * to be the same during scanning.  If flag is NO the scanner will
 * not make a distinction between upper and lower case characters.
 */
- (void) setCaseSensitive: (BOOL)flag
{
  _caseSensitive = flag;
}

/*
 * Return a character set object containing the characters the scanner
 * will ignore when searching for the next element to be scanned.
 */
- (NSCharacterSet *) charactersToBeSkipped
{
  return _charactersToBeSkipped;
}

/*
 * Set the characters to be ignored when the scanner
 * searches for the next element to be scanned.
 */
- (void) setCharactersToBeSkipped: (NSCharacterSet *)aSet
{
  ASSIGNCOPY(_charactersToBeSkipped, aSet);
  _skipImp = (BOOL (*)(NSCharacterSet*, SEL, unichar))
    [_charactersToBeSkipped methodForSelector: memSel];
}

/*
 * Returns a dictionary object containing the locale
 * information used by the scanner.
 */
- (NSDictionary *) locale
{
  return _locale;
}

/*
 * Set the dictionary containing the locale
 * information used by the scanner to localeDictionary.
 */
- (void) setLocale: (NSDictionary *)localeDictionary
{
  ASSIGN(_locale, localeDictionary);
  /*
   * Get decimal point character from locale if necessary.
   */
  if (_locale == nil)
    {
      _decimal = '.';
    }
  else
    {
      NSString	*pointString;

      pointString = [_locale objectForKey: NSDecimalSeparator];
      if ([pointString length] > 0)
	_decimal = [pointString characterAtIndex: 0];
      else
	_decimal = '.';
    }
}

/*
 * NSCopying protocol
 */
- (id) copyWithZone: (NSZone *)zone
{
  NSScanner	*n = [[self class] allocWithZone: zone];

  [n initWithString: _string];
  [n setCharactersToBeSkipped: _charactersToBeSkipped];
  [n setLocale: _locale];
  [n setScanLocation: _scanLocation];
  [n setCaseSensitive: _caseSensitive];
  return n;
}

@end
