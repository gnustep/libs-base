/**
   NSNumberFormatter class
   Copyright (C) 2000 Free Software Foundation, Inc.

   Written by: Fred Kiefer <FredKiefer@gmx.de>
   Created: July 2000
   Updated by: Richard Frith-Macdonald <rfm@gnu.org> Sept 2001

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

   <title>NSNumberFormatter class reference</title>
   $Date$ $Revision$
   */

#import "common.h"
#define	EXPOSE_NSNumberFormatter_IVARS	1
#import "Foundation/NSAttributedString.h"
#import "Foundation/NSDecimalNumber.h"
#import "Foundation/NSDictionary.h"
#import "Foundation/NSError.h"
#import "Foundation/NSException.h"
#import "Foundation/NSLocale.h"
#import "Foundation/NSMapTable.h"
#import "Foundation/NSValue.h"
#import "Foundation/NSNumberFormatter.h"
#import "Foundation/NSUserDefaults.h"
#import "Foundation/NSCharacterSet.h"

#import "GNUstepBase/GSLocale.h"

@class NSDoubleNumber;

#if	defined(HAVE_UNICODE_UNUM_H)
# include <unicode/unum.h>
#endif

#define BUFFER_SIZE 1024

/* Unfortunately, libicu does not define the maximum values allowed for all
   of these attributes.  We define them here to, though.
   These are based off libicu version 4.6.
 */
#define MAX_SYMBOLS 27
#define MAX_TEXTATTRIBUTES 8
#define MAX_ATTRIBUTES 20

#if GS_USE_ICU == 1
static inline UNumberFormatStyle
NSToICUFormatStyle (NSNumberFormatterStyle style)
{
  UNumberFormatStyle result;
  
  switch (style)
    {
      case NSNumberFormatterDecimalStyle:
        result = UNUM_DECIMAL;
        break;
      case NSNumberFormatterCurrencyStyle:
        result = UNUM_CURRENCY;
        break;
      case NSNumberFormatterPercentStyle:
        result = UNUM_PERCENT;
        break;
      case NSNumberFormatterScientificStyle:
        result = UNUM_SCIENTIFIC;
        break;
      case NSNumberFormatterSpellOutStyle:
        result = UNUM_SPELLOUT;
        break;
      case NSNumberFormatterNoStyle:
      default:
        result = UNUM_IGNORE;
    }
  
  return result;
}

static inline UNumberFormatPadPosition
NSToICUPadPosition (NSNumberFormatterPadPosition position)
{
  UNumberFormatPadPosition result = 0;
  
  switch (position)
    {
      case NSNumberFormatterPadBeforePrefix:
        result = UNUM_PAD_BEFORE_PREFIX;
        break;
      case NSNumberFormatterPadAfterPrefix:
        result = UNUM_PAD_AFTER_PREFIX;
        break;
      case NSNumberFormatterPadBeforeSuffix:
        result = UNUM_PAD_BEFORE_SUFFIX;
        break;
      case NSNumberFormatterPadAfterSuffix:
        result = UNUM_PAD_AFTER_SUFFIX;
        break;
    }
  
  return result;
}

static inline NSNumberFormatterPadPosition
ICUToNSPadPosition (UNumberFormatPadPosition position)
{
  NSNumberFormatterPadPosition result = 0;
  
  switch (position)
    {
      case UNUM_PAD_BEFORE_PREFIX:
        result = NSNumberFormatterPadBeforePrefix;
        break;
      case UNUM_PAD_AFTER_PREFIX:
        result = NSNumberFormatterPadAfterPrefix;
        break;
      case UNUM_PAD_BEFORE_SUFFIX:
        result = NSNumberFormatterPadBeforeSuffix;
        break;
      case UNUM_PAD_AFTER_SUFFIX:
        result = NSNumberFormatterPadAfterSuffix;
        break;
    }
  
  return result;
}

static inline UNumberFormatRoundingMode
NSToICURoundingMode (NSNumberFormatterRoundingMode mode)
{
  UNumberFormatRoundingMode result = 0;
  
  switch (mode)
    {
      case NSNumberFormatterRoundCeiling:
        result = UNUM_ROUND_CEILING;
        break;
      case NSNumberFormatterRoundFloor:
        result = UNUM_ROUND_FLOOR;
        break;
      case NSNumberFormatterRoundDown:
        result = UNUM_ROUND_DOWN;
        break;
      case NSNumberFormatterRoundUp:
        result = UNUM_ROUND_UP;
        break;
      case NSNumberFormatterRoundHalfEven:
        result = UNUM_ROUND_HALFEVEN;
        break;
      case NSNumberFormatterRoundHalfDown:
        result = UNUM_ROUND_HALFDOWN;
        break;
      case NSNumberFormatterRoundHalfUp:
        result = UNUM_ROUND_HALFUP;
        break;
    }
  
  return result;
}

static inline NSNumberFormatterRoundingMode
ICUToNSRoundingMode (UNumberFormatRoundingMode mode)
{
  NSNumberFormatterRoundingMode result = 0;
  
  switch (mode)
    {
      case UNUM_ROUND_CEILING:
        result = NSNumberFormatterRoundCeiling;
        break;
      case UNUM_ROUND_FLOOR:
        result = NSNumberFormatterRoundFloor;
        break;
      case UNUM_ROUND_DOWN:
        result = NSNumberFormatterRoundDown;
        break;
      case UNUM_ROUND_UP:
        result = NSNumberFormatterRoundUp;
        break;
      case UNUM_ROUND_HALFEVEN:
        result = NSNumberFormatterRoundHalfEven;
        break;
      case UNUM_ROUND_HALFDOWN:
        result = NSNumberFormatterRoundHalfDown;
        break;
      case UNUM_ROUND_HALFUP:
        result = NSNumberFormatterRoundHalfUp;
        break;
    }
  
  return result;
}

#define SET_SYMBOL(key, value, reset) do\
  { \
    unichar buffer[BUFFER_SIZE]; \
    NSUInteger length; \
    UErrorCode err = U_ZERO_ERROR; \
    \
    if (reset && ((value) == nil)) \
      break; \
    \
    length = [(value) length]; \
    if (length > BUFFER_SIZE) \
      length = BUFFER_SIZE; \
    [value getCharacters: buffer range: NSMakeRange (0, length)]; \
    \
    unum_setSymbol (internal->_formatter, key, buffer, length, &err); \
    \
    if (!reset) \
      { \
        if (internal->_symbols[key]) \
          RELEASE(internal->_symbols[key]); \
        internal->_symbols[key] = RETAIN(value); \
      } \
  } while(0)

#define SET_TEXTATTRIBUTE(key, value, reset) do\
  { \
    unichar buffer[BUFFER_SIZE]; \
    NSUInteger length; \
    UErrorCode err = U_ZERO_ERROR; \
    \
    if (reset && ((value) == nil)) \
      break; \
    \
    length = [(value) length]; \
    if (length > BUFFER_SIZE) \
      length = BUFFER_SIZE; \
    [value getCharacters: buffer range: NSMakeRange (0, length)]; \
    \
    unum_setTextAttribute (internal->_formatter, key, buffer, length, &err); \
    \
    if (!reset) \
      { \
        if (internal->_textAttributes[key]) \
          RELEASE(internal->_textAttributes[key]); \
        internal->_textAttributes[key] = RETAIN(value); \
      } \
  } while(0)

#define SET_ATTRIBUTE(key, value, reset) do \
  { \
    if (reset && ((int32_t)(value) < 0)) \
      break; \
    \
    unum_setAttribute (internal->_formatter, key, (int32_t)(value)); \
    \
    if (!reset) \
      internal->_attributes[key] = (int32_t)(value); \
  } while(0)

#define GET_SYMBOL(key, retval) do \
  { \
  UChar buffer[BUFFER_SIZE]; \
  int32_t length; \
  UErrorCode err = U_ZERO_ERROR; \
  \
  length = unum_getSymbol (internal->_formatter, key, buffer, \
    BUFFER_SIZE, &err); \
  if (length > BUFFER_SIZE) \
    length = BUFFER_SIZE; \
  \
  retval = [NSString stringWithCharacters: buffer length: length]; \
  } while(0)

#define GET_TEXTATTRIBUTE(key, retval) do \
  { \
  UChar buffer[BUFFER_SIZE]; \
  int32_t length; \
  UErrorCode err = U_ZERO_ERROR; \
  \
  length = unum_getTextAttribute (internal->_formatter, key, buffer, \
    BUFFER_SIZE, &err); \
  if (length > BUFFER_SIZE) \
    length = BUFFER_SIZE; \
  \
  retval = [NSString stringWithCharacters: buffer length: length]; \
  } while(0)

#define GET_ATTRIBUTE(key, retval) do \
  { \
    if (internal->_attributes[key]) \
      retval = internal->_attributes[key]; \
    else \
      retval = unum_getAttribute (internal->_formatter, key); \
  } while (0)

#endif

#define GS_NSNumberFormatter_IVARS \
  NSUInteger _behavior; \
  BOOL       _genDecimal; \
  NSUInteger _style; \
  NSLocale  *_locale; \
  void      *_formatter; \
  id *_symbols; \
  id *_textAttributes; \
  int *_attributes
 
#define GSInternal              NSNumberFormatterInternal
#include        "GSInternal.h"
GS_PRIVATE_INTERNAL(NSNumberFormatter)



@interface NSNumberFormatter (PrivateMethods)
- (void) _resetUNumberFormat;
@end

@implementation NSNumberFormatter

#if GS_USE_ICU == 1
#define	MYBEHAVIOR	internal->_behavior
#else
#define	MYBEHAVIOR	NSNumberFormatterBehavior10_0
#endif
static NSUInteger _defaultBehavior = NSNumberFormatterBehavior10_4;

- (BOOL) allowsFloats
{
  return _allowsFloats;
}

- (NSAttributedString*) attributedStringForObjectValue: (id)anObject
				 withDefaultAttributes: (NSDictionary*)attr
{
  NSDecimalNumber *zeroNumber = [NSDecimalNumber zero];
  NSDecimalNumber *nanNumber = [NSDecimalNumber notANumber];

  if (anObject == nil)
    {
      return [self attributedStringForNil];
    }
  else if (![anObject isKindOfClass: [NSNumber class]])
    {
      return [self attributedStringForNotANumber];
    }
  else if ([anObject isEqual: nanNumber])
    {
      return [self attributedStringForNotANumber];
    }
  else if ([anObject isEqual: zeroNumber])
    {
      return [self attributedStringForZero];
    }

  if (([(NSNumber*)anObject compare: zeroNumber] == NSOrderedDescending)
    && (_attributesForPositiveValues))
    {
      attr = _attributesForPositiveValues;
    }
  else if (([(NSNumber*)anObject compare: zeroNumber] == NSOrderedAscending)
    && (_attributesForNegativeValues))
    {
      attr = _attributesForNegativeValues;
    }

  return AUTORELEASE([[NSAttributedString alloc] initWithString:
    [self stringForObjectValue: anObject] attributes: attr]);
}

- (NSAttributedString*) attributedStringForNil
{
  return _attributedStringForNil;
}

- (NSAttributedString*) attributedStringForNotANumber
{
  return _attributedStringForNotANumber;
}

- (NSAttributedString*) attributedStringForZero
{
  return _attributedStringForZero;
}

- (id) copyWithZone: (NSZone *)zone
{
  NSNumberFormatter	*o = (NSNumberFormatter*) NSCopyObject(self, 0, zone);

  IF_NO_GC(RETAIN(o->_negativeFormat);)
  IF_NO_GC(RETAIN(o->_positiveFormat);)
  IF_NO_GC(RETAIN(o->_attributesForPositiveValues);)
  IF_NO_GC(RETAIN(o->_attributesForNegativeValues);)
  IF_NO_GC(RETAIN(o->_maximum);)
  IF_NO_GC(RETAIN(o->_minimum);)
  IF_NO_GC(RETAIN(o->_roundingBehavior);)
  IF_NO_GC(RETAIN(o->_attributedStringForNil);)
  IF_NO_GC(RETAIN(o->_attributedStringForNotANumber);)
  IF_NO_GC(RETAIN(o->_attributedStringForZero);)
  if (0 != internal)
    {
      GS_COPY_INTERNAL(o, zone)
      IF_NO_GC(RETAIN(GSIVar(o,_locale));)
#if GS_USE_ICU == 1
      {
        UErrorCode err = U_ZERO_ERROR;
        GSIVar(o,_formatter) = unum_clone (internal->_formatter, &err);
      }
#endif
    }
  return o;
}

- (void) dealloc
{
  RELEASE(_negativeFormat);
  RELEASE(_positiveFormat);
  RELEASE(_attributesForPositiveValues);
  RELEASE(_attributesForNegativeValues);
  RELEASE(_maximum);
  RELEASE(_minimum);
  RELEASE(_roundingBehavior);
  RELEASE(_attributedStringForNil);
  RELEASE(_attributedStringForNotANumber);
  RELEASE(_attributedStringForZero);
  if (internal != 0)
    {
      int idx;
      NSZone *z = [self zone];
      RELEASE(internal->_locale);
#if GS_USE_ICU == 1
      unum_close (internal->_formatter);
#endif
      if (internal->_symbols)
        {
          for (idx = 0 ; idx < MAX_SYMBOLS ; ++idx )
            RELEASE(internal->_symbols[idx]);
          NSZoneFree (z, internal->_symbols);
        }
      if (internal->_textAttributes)
        {
          for (idx = 0 ; idx < MAX_TEXTATTRIBUTES ; ++idx )
            RELEASE(internal->_textAttributes[idx]);
          NSZoneFree (z, internal->_textAttributes);
        }
      if (internal->_attributes)
        NSZoneFree (z, internal->_attributes);
      GS_DESTROY_INTERNAL(NSNumberFormatter)
    }
  [super dealloc];
}

- (NSString*) decimalSeparator
{
  if (MYBEHAVIOR == NSNumberFormatterBehavior10_4
    || MYBEHAVIOR == NSNumberFormatterBehaviorDefault)
    {
#if GS_USE_ICU == 1
      NSString *result;
      GET_SYMBOL(UNUM_DECIMAL_SEPARATOR_SYMBOL, result);
      return result;
#endif
    }
  else if (MYBEHAVIOR == NSNumberFormatterBehavior10_0)
    {
      if (_decimalSeparator == 0)
        return @"";
      else
        return [NSString stringWithCharacters: &_decimalSeparator length: 1];
    }
  return nil;
}

- (NSString*) editingStringForObjectValue: (id)anObject
{
  return [self stringForObjectValue: anObject];
}

- (void) encodeWithCoder: (NSCoder*)encoder
{
  [encoder encodeValueOfObjCType: @encode(BOOL) at: &_hasThousandSeparators];
  [encoder encodeValueOfObjCType: @encode(BOOL) at: &_allowsFloats];
  [encoder encodeValueOfObjCType: @encode(BOOL) at: &_localizesFormat];
  [encoder encodeValueOfObjCType: @encode(unichar) at: &_thousandSeparator];
  [encoder encodeValueOfObjCType: @encode(unichar) at: &_decimalSeparator];

  [encoder encodeObject: _roundingBehavior];
  [encoder encodeObject: _maximum];
  [encoder encodeObject: _minimum];
  [encoder encodeObject: _attributedStringForNil];
  [encoder encodeObject: _attributedStringForNotANumber];
  [encoder encodeObject: _attributedStringForZero];
  [encoder encodeObject: _negativeFormat];
  [encoder encodeObject: _positiveFormat];
  [encoder encodeObject: _attributesForPositiveValues];
  [encoder encodeObject: _attributesForNegativeValues];
  // FIXME: Add new ivars
}

- (NSString*) format
{
  if (_attributedStringForZero != nil)
    {
      return [NSString stringWithFormat: @"%@;%@;%@",
	_positiveFormat, [_attributedStringForZero string], _negativeFormat];
    }
  else
    {
      return [NSString stringWithFormat: @"%@;%@",
	_positiveFormat, _negativeFormat];
    }
}

- (BOOL) getObjectValue: (id*)anObject
	      forString: (NSString*)string
       errorDescription: (NSString**)error
{
  /* FIXME: This is just a quick hack implementation.  */
  NSLog(@"NSNumberFormatter-getObjectValue:forString:... not fully implemented");

  if (nil == string)
    {
      if (0 != error)
	{
	  *error = _(@"nil string");
	}
      return NO;
    }

  if (NO == [self allowsFloats] && [string rangeOfString: @"."].length > 0)
    {
      if (0 != error)
	{
	  *error = _(@"Floating Point not allowed");
	}
      return NO;
    }

  /* Just assume nothing else has been setup and do a simple conversion. */
  if ([self hasThousandSeparators])
    {
      NSRange range;
      
      range = [string rangeOfString: [self thousandSeparator]];
      if (range.length != 0)
        {
	  string = AUTORELEASE([string mutableCopy]);
	  [(NSMutableString*)string replaceOccurrencesOfString:
	    [self thousandSeparator]
	    withString: @""
	    options: 0
	    range: NSMakeRange(0, [string length])];
	}
    }

  if (anObject)
    {
      NSDictionary *locale;
      
      locale = [NSDictionary dictionaryWithObject: [self decimalSeparator] 
			     forKey: NSDecimalSeparator];
      *anObject = [NSDecimalNumber decimalNumberWithString: string
				   locale: locale];
      if (*anObject)
        {
	  return YES;
	}
    }

  return NO;
}

- (BOOL) hasThousandSeparators
{
  return _hasThousandSeparators;
}

- (id) init
{
  id	o;
  int idx;
  NSZone *z = [self zone];
  
  GS_CREATE_INTERNAL(NSNumberFormatter)
  
  _allowsFloats = YES;
  _decimalSeparator = '.';
  _thousandSeparator = ',';
  _hasThousandSeparators = YES;
  o = [[NSAttributedString alloc] initWithString: @""];
  [self setAttributedStringForNil: o];
  RELEASE(o);
  o = [[NSAttributedString alloc] initWithString: @"NaN"];
  [self setAttributedStringForNotANumber: o];
  RELEASE(o);
  
  internal->_behavior = _defaultBehavior;
  internal->_locale = RETAIN([NSLocale currentLocale]);
  internal->_style = NSNumberFormatterNoStyle;
  internal->_symbols = NSZoneCalloc (z, MAX_SYMBOLS, sizeof(id));
  internal->_textAttributes = NSZoneCalloc (z, MAX_TEXTATTRIBUTES, sizeof(id));
  internal->_attributes = NSZoneCalloc (z, MAX_ATTRIBUTES, sizeof(int));
  if (!(internal->_symbols
        && internal->_textAttributes
        && internal->_attributes))
    {
      RELEASE(self);
      return nil;
    }
  /* Set all attributes to -1 before resetting the formatter.  When
  resetting them only values < 0 will be skipped. */
  for (idx = 0 ; idx < MAX_ATTRIBUTES ; ++idx)
    internal->_attributes[idx] = -1;
  
  [self _resetUNumberFormat];
#if GS_USE_ICU == 1
  if (internal->_formatter == NULL)
    {
      RELEASE(self);
      return nil;
    }
#endif
  
  [self setMaximumFractionDigits: 0];
  
  return self;
}

- (id) initWithCoder: (NSCoder*)decoder
{
  GS_CREATE_INTERNAL(NSNumberFormatter)

  if ([decoder allowsKeyedCoding])
    {
      if ([decoder containsValueForKey: @"NS.allowsfloats"])
        {
	  [self setAllowsFloats:
	    [decoder decodeBoolForKey: @"NS.allowsfloats"]];
	}
      if ([decoder containsValueForKey: @"NS.decimal"])
        {
	  [self setDecimalSeparator:
	    [decoder decodeObjectForKey: @"NS.decimal"]];
	}
      if ([decoder containsValueForKey: @"NS.hasthousands"])
        {
	  [self setHasThousandSeparators:
	    [decoder decodeBoolForKey: @"NS.hasthousands"]];
	}
      if ([decoder containsValueForKey: @"NS.localized"])
        {
	  [self setLocalizesFormat:
	    [decoder decodeBoolForKey: @"NS.localized"]];
	}
      if ([decoder containsValueForKey: @"NS.max"])
        {
	  [self setMaximum: [decoder decodeObjectForKey: @"NS.max"]];
	}
      if ([decoder containsValueForKey: @"NS.min"])
        {
	  [self setMinimum: [decoder decodeObjectForKey: @"NS.min"]];
	}
      if ([decoder containsValueForKey: @"NS.nan"])
        {
	  [self setAttributedStringForNotANumber:
	    [decoder decodeObjectForKey: @"NS.nan"]];
	}
      if ([decoder containsValueForKey: @"NS.negativeattrs"])
        {
	  [self setTextAttributesForNegativeValues:
	    [decoder decodeObjectForKey: @"NS.negativeattrs"]];
	}
      if ([decoder containsValueForKey: @"NS.negativeformat"])
        {
	  [self setNegativeFormat:
	    [decoder decodeObjectForKey: @"NS.negativeformat"]];
	}
      if ([decoder containsValueForKey: @"NS.nil"])
        {
	  [self setAttributedStringForNil:
	    [decoder decodeObjectForKey: @"NS.nil"]];
	}
      if ([decoder containsValueForKey: @"NS.positiveattrs"])
        {
	  [self setTextAttributesForPositiveValues:
	    [decoder decodeObjectForKey: @"NS.positiveattrs"]];
	}
      if ([decoder containsValueForKey: @"NS.positiveformat"])
        {
	  [self setPositiveFormat:
	    [decoder decodeObjectForKey: @"NS.positiveformat"]];
	}
      if ([decoder containsValueForKey: @"NS.rounding"])
        {
	  [self setRoundingBehavior:
	    [decoder decodeObjectForKey: @"NS.rounding"]];
	}
      if ([decoder containsValueForKey: @"NS.thousand"])
        {
	  [self setThousandSeparator:
	    [decoder decodeObjectForKey: @"NS.thousand"]];
	}
      if ([decoder containsValueForKey: @"NS.zero"])
        {
	  [self setAttributedStringForZero:
	    [decoder decodeObjectForKey: @"NS.zero"]];
	}
    }
  else
    {
      [decoder decodeValueOfObjCType: @encode(BOOL)
				  at: &_hasThousandSeparators];
      [decoder decodeValueOfObjCType: @encode(BOOL) at: &_allowsFloats];
      [decoder decodeValueOfObjCType: @encode(BOOL) at: &_localizesFormat];
      [decoder decodeValueOfObjCType: @encode(unichar) at: &_thousandSeparator];
      [decoder decodeValueOfObjCType: @encode(unichar) at: &_decimalSeparator];

      [decoder decodeValueOfObjCType: @encode(id) at: &_roundingBehavior];
      [decoder decodeValueOfObjCType: @encode(id) at: &_maximum];
      [decoder decodeValueOfObjCType: @encode(id) at: &_minimum];
      [decoder decodeValueOfObjCType: @encode(id) at: &_attributedStringForNil];
      [decoder decodeValueOfObjCType: @encode(id)
	                          at: &_attributedStringForNotANumber];
      [decoder decodeValueOfObjCType: @encode(id)
				  at: &_attributedStringForZero];
      [decoder decodeValueOfObjCType: @encode(id) at: &_negativeFormat];
      [decoder decodeValueOfObjCType: @encode(id) at: &_positiveFormat];
      [decoder decodeValueOfObjCType: @encode(id)
	                          at: &_attributesForPositiveValues];
      [decoder decodeValueOfObjCType: @encode(id)
	                          at: &_attributesForNegativeValues];
    }
  return self;
  // FIXME: add new ivars
}

- (BOOL) isPartialStringValid: (NSString*)partialString
	     newEditingString: (NSString**)newString
	     errorDescription: (NSString**)error
{
  // FIXME
  if (newString != NULL)
    {
      *newString = partialString;
    }
  if (error)
    {
      *error = nil;
    }

  return YES;
}

- (BOOL) localizesFormat
{
  return _localizesFormat;
}

- (NSDecimalNumber*) maximum
{
  return _maximum;
}

- (NSDecimalNumber*) minimum
{
  return _minimum;
}

- (NSString*) negativeFormat
{
  return _negativeFormat;
}

- (NSString*) positiveFormat
{
  return _positiveFormat;
}

- (NSDecimalNumberHandler*) roundingBehavior
{
  return _roundingBehavior;
}

- (void) setAllowsFloats: (BOOL)flag
{
  _allowsFloats = flag;
}

- (void) setAttributedStringForNil: (NSAttributedString*)newAttributedString
{
  ASSIGN(_attributedStringForNil, newAttributedString);
}

- (void) setAttributedStringForNotANumber:
  (NSAttributedString*)newAttributedString
{
  ASSIGN(_attributedStringForNotANumber, newAttributedString);
}

- (void) setAttributedStringForZero: (NSAttributedString*)newAttributedString
{
  ASSIGN(_attributedStringForZero, newAttributedString);
}

- (void) setDecimalSeparator: (NSString*)newSeparator
{
  if (MYBEHAVIOR == NSNumberFormatterBehavior10_4
    || MYBEHAVIOR == NSNumberFormatterBehaviorDefault)
    {
#if GS_USE_ICU == 1
      SET_SYMBOL(UNUM_DECIMAL_SEPARATOR_SYMBOL, newSeparator, NO);
#endif
    }
  else if (MYBEHAVIOR == NSNumberFormatterBehavior10_0)
    {
      if ([newSeparator length] > 0)
        _decimalSeparator = [newSeparator characterAtIndex: 0];
      else
        _decimalSeparator = 0;
    }
}

- (void) setFormat: (NSString*)aFormat
{
  NSRange	r;

  r = [aFormat rangeOfString: @";"];
  if (r.length == 0)
    {
      [self setPositiveFormat: aFormat];
      [self setNegativeFormat: [@"-" stringByAppendingString: aFormat]];
    }
  else
    {
      [self setPositiveFormat: [aFormat substringToIndex: r.location]];
      aFormat = [aFormat substringFromIndex: NSMaxRange(r)];
      r = [aFormat rangeOfString: @";"];
      if (r.length == 0)
	{
	  [self setNegativeFormat: aFormat];
	}
      else
	{
	  RELEASE(_attributedStringForZero);
	  _attributedStringForZero = [[NSAttributedString alloc] initWithString:
	    [aFormat substringToIndex: r.location]];
	  [self setNegativeFormat: [aFormat substringFromIndex: NSMaxRange(r)]];
	}
    }
}

- (void) setHasThousandSeparators: (BOOL)flag
{
  _hasThousandSeparators = flag;
}

- (void) setLocalizesFormat: (BOOL)flag
{
  _localizesFormat = flag;
}

- (void) setMaximum: (NSDecimalNumber*)aMaximum
{
  // FIXME: NSNumberFormatterBehavior10_4
  ASSIGN(_maximum, aMaximum);
}

- (void) setMinimum: (NSDecimalNumber*)aMinimum
{
  // FIXME: NSNumberFormatterBehavior10_4
  ASSIGN(_minimum, aMinimum);
}

- (void) setNegativeFormat: (NSString*)aFormat
{
  // FIXME: Should extract separators and attributes
  ASSIGN(_negativeFormat, aFormat);
}

- (void) setPositiveFormat: (NSString*)aFormat
{
  // FIXME: Should extract separators and attributes
  ASSIGN(_positiveFormat, aFormat);
}

- (void) setRoundingBehavior: (NSDecimalNumberHandler*)newRoundingBehavior
{
  ASSIGN(_roundingBehavior, newRoundingBehavior);
}

- (void) setTextAttributesForNegativeValues: (NSDictionary*)newAttributes
{
  ASSIGN(_attributesForNegativeValues, newAttributes);
}

- (void) setTextAttributesForPositiveValues: (NSDictionary*)newAttributes
{
  ASSIGN(_attributesForPositiveValues, newAttributes);
}

- (void) setThousandSeparator: (NSString*)newSeparator
{
  if ([newSeparator length] > 0)
    _thousandSeparator = [newSeparator characterAtIndex: 0];
  else
    _thousandSeparator = 0;
}

- (NSString*) stringForObjectValue: (id)anObject
{
  if (MYBEHAVIOR == NSNumberFormatterBehaviorDefault
      || MYBEHAVIOR == NSNumberFormatterBehavior10_4)
    {
#if GS_USE_ICU == 1

#define STRING_FROM_NUMBER(function, number) do \
  { \
    UChar *outStr = buffer; \
    UErrorCode err = U_ZERO_ERROR; \
    int32_t len; \
    NSString *result; \
    \
    len = function (internal->_formatter, number, outStr, BUFFER_SIZE, NULL, &err); \
    if (len > BUFFER_SIZE) \
      outStr = NSZoneMalloc ([self zone], len * sizeof(UChar));\
    err = U_ZERO_ERROR; \
    function (internal->_formatter, number, outStr, BUFFER_SIZE, NULL, &err); \
    result = [NSString stringWithCharacters: outStr length: len]; \
    if (len > BUFFER_SIZE) \
      NSZoneFree ([self zone], outStr); \
    return result; \
  } while (0)

      // This is quite inefficient.  See the GSUText stuff for how
      // to use ICU 4.6 UText objects as NSStrings.  This saves us from
      // needing to do a load of O(n) things.  In 4.6, these APIs in ICU
      // haven't been updated to use UText (so we have to use the UChar buffer
      // approach), but they probably will be in the future.  We should
      // revisit this code when they have been.
      UChar buffer[BUFFER_SIZE];
      
      // FIXME: What to do with unsigned types?
      //
      // The only unsigned case we actually need to worry about is unsigned
      // long long - all of the others are stored as signed values.  We're now
      // falling through to the double case for this, which will lose us some
      // precision, but hopefully not matter too much...
      if (nil == anObject)
        return [self nilSymbol];
      if (![anObject isKindOfClass: [NSNumber class]])
        return [self notANumberSymbol];
      switch ([anObject objCType][0])
        {
          case _C_LNG_LNG:
            STRING_FROM_NUMBER(unum_formatInt64, [anObject longLongValue]);
            break;
          case _C_INT:
            STRING_FROM_NUMBER(unum_format, [anObject intValue]);
            break;
          // Note: This case is probably wrong: the compiler doesn't generate B
          // for bool, it generates C or c (depending on the platform).  I
          // don't think it matters, because we don't bother with anything
          // smaller than int for NSNumbers
          case _C_BOOL:
            STRING_FROM_NUMBER(unum_format, (int)[anObject boolValue]);
            break;
          // If it's not a type encoding that we recognise, let the receiver
          // cast it to a double, which probably has enough precision for what
          // we need.  This needs testing with NSDecimalNumber though, because
          // I managed to break stuff last time I did anything with NSNumber by
          // forgetting that NSDecimalNumber existed...
          default:
          case _C_DBL:
            STRING_FROM_NUMBER(unum_formatDouble, [anObject doubleValue]);
            break;
          case _C_FLT:
            STRING_FROM_NUMBER(unum_formatDouble, (double)[anObject floatValue]);
            break;
        }
#endif
    }
  else if (MYBEHAVIOR == NSNumberFormatterBehavior10_0)
    {
      NSMutableDictionary	*locale;
      NSCharacterSet	*formattingCharacters;
      NSCharacterSet	*placeHolders;
      NSString		*prefix;
      NSString		*suffix;
      NSString		*wholeString;
      NSString		*fracPad = nil;
      NSString		*fracPartString;
      NSMutableString	*intPartString;
      NSMutableString	*formattedNumber;
      NSMutableString	*intPad;
      NSRange		prefixRange;
      NSRange		decimalPlaceRange;
      NSRange		suffixRange;
      NSRange		intPartRange;
      NSDecimal		representativeDecimal;
      NSDecimal		roundedDecimal;
      NSDecimalNumber	*roundedNumber;
      NSDecimalNumber	*intPart;
      NSDecimalNumber	*fracPart;
      int			decimalPlaces = 0;
      BOOL			displayThousandsSeparators = NO;
      BOOL			displayFractionalPart = NO;
      BOOL			negativeNumber = NO;
      NSString		*useFormat;
      NSString		*defaultDecimalSeparator = nil;
      NSString		*defaultThousandsSeparator = nil;

      if (_localizesFormat)
        {
          NSDictionary *defaultLocale = GSDomainFromDefaultLocale();
          defaultDecimalSeparator 
      = [defaultLocale objectForKey: NSDecimalSeparator];
          defaultThousandsSeparator 
      = [defaultLocale objectForKey: NSThousandsSeparator];
        }

      if (defaultDecimalSeparator == nil)
        {
          defaultDecimalSeparator = @".";
        }
      if (defaultThousandsSeparator == nil)
        {
          defaultThousandsSeparator = @",";
        }
      formattingCharacters = [NSCharacterSet
        characterSetWithCharactersInString: @"0123456789#.,_"];
      placeHolders = [NSCharacterSet 
        characterSetWithCharactersInString: @"0123456789#_"];

      if (nil == anObject)
        return [[self attributedStringForNil] string];
      if (![anObject isKindOfClass: [NSNumber class]])
        return [[self attributedStringForNotANumber] string];
      if ([anObject isEqual: [NSDecimalNumber notANumber]])
        return [[self attributedStringForNotANumber] string];
      if (_attributedStringForZero
          && [anObject isEqual: [NSDecimalNumber zero]])
        return [[self attributedStringForZero] string];
      
      useFormat = _positiveFormat;
      if ([(NSNumber*)anObject compare: [NSDecimalNumber zero]]
        == NSOrderedAscending)
        {
          useFormat = _negativeFormat;
          negativeNumber = YES;
        }

      // if no format specified, use the same default that Cocoa does
      if (nil == useFormat)
        {
          useFormat = [NSString stringWithFormat: @"%@#%@###%@##",
	            negativeNumber ? @"-" : @"",
	            defaultThousandsSeparator,
	            defaultDecimalSeparator];
        }

      prefixRange = [useFormat rangeOfCharacterFromSet: formattingCharacters];
      if (NSNotFound != prefixRange.location)
        {
          prefix = [useFormat substringToIndex: prefixRange.location];
        }
      else
        {
          prefix = @"";
        }

      locale = [NSMutableDictionary dictionaryWithCapacity: 3];
      [locale setObject: @"" forKey: NSThousandsSeparator];
      [locale setObject: @"" forKey: NSDecimalSeparator];

      //should also set NSDecimalDigits?
      
      if ([self hasThousandSeparators]
        && (0 != [useFormat rangeOfString: defaultThousandsSeparator].length))
        {
          displayThousandsSeparators = YES;
        }

      if (NSNotFound
	!= [useFormat rangeOfString: defaultDecimalSeparator].location)
        {
          decimalPlaceRange = [useFormat rangeOfString: defaultDecimalSeparator
			           options: NSBackwardsSearch];
          if (NSMaxRange(decimalPlaceRange) == [useFormat length])
            {
              decimalPlaces = 0;
            }
          else
            {
              while ([placeHolders characterIsMember:
          [useFormat characterAtIndex: NSMaxRange(decimalPlaceRange)]])
                {
                  decimalPlaceRange.length++;
                  if (NSMaxRange(decimalPlaceRange) == [useFormat length])
                    break;
                }
              decimalPlaces=decimalPlaceRange.length -= 1;
              decimalPlaceRange.location += 1;
              fracPad = [useFormat substringWithRange:decimalPlaceRange];
            } 
          if (0 != decimalPlaces)
            displayFractionalPart = YES;
        }

      representativeDecimal = [anObject decimalValue];
      NSDecimalRound(&roundedDecimal, &representativeDecimal, decimalPlaces,
        NSRoundPlain);
      roundedNumber =
        [NSDecimalNumber decimalNumberWithDecimal: roundedDecimal];

      /* Arguably this fiddling could be done by GSDecimalString() but I
       * thought better to leave that behaviour as it is and provide the
       * desired prettification here
       */
      if (negativeNumber)
        roundedNumber = [roundedNumber decimalNumberByMultiplyingBy:
          (NSDecimalNumber*)[NSDecimalNumber numberWithInt: -1]];
      intPart = (NSDecimalNumber*)
        [NSDecimalNumber numberWithInt: (int)[roundedNumber doubleValue]];
      fracPart = [roundedNumber decimalNumberBySubtracting: intPart];
      intPartString
        = AUTORELEASE([[intPart descriptionWithLocale: locale] mutableCopy]);
      
      //sort out the padding for the integer part
      intPartRange = [useFormat rangeOfCharacterFromSet: placeHolders];
      if (NSMaxRange(intPartRange) < ([useFormat length] - 1))
        {
          while (([placeHolders characterIsMember:
            [useFormat characterAtIndex: NSMaxRange(intPartRange)]]
            || [[useFormat substringFromRange:
              NSMakeRange(NSMaxRange(intPartRange), 1)] isEqual:
          defaultThousandsSeparator])
            && NSMaxRange(intPartRange) < [useFormat length] - 1)
            {
              intPartRange.length++;
            }
        }
      intPad = [[[useFormat substringWithRange: intPartRange]
	mutableCopy] autorelease];
      [intPad replaceOccurrencesOfString: defaultThousandsSeparator
        withString: @""
        options: 0
        range: NSMakeRange(0, [intPad length])];
      [intPad replaceOccurrencesOfString: @"#"
        withString: @""
        options: NSAnchoredSearch
        range: NSMakeRange(0, [intPad length])];
      if ([intPad length] > [intPartString length])
        {
          NSRange		ipRange;

          ipRange =
            NSMakeRange(0, [intPad length] - [intPartString length] + 1);
          [intPartString insertString:
            [intPad substringWithRange: ipRange] atIndex: 0];
          [intPartString replaceOccurrencesOfString: @"_"
	    withString: @" "
	    options: 0
	    range: NSMakeRange(0, [intPartString length])];
          [intPartString replaceOccurrencesOfString: @"#"
	    withString: @"0"
	    options: 0
	    range: NSMakeRange(0, [intPartString length])];
        }
      // fix the thousands separators up
      if (displayThousandsSeparators && [intPartString length] > 3)
        {
          int index = [intPartString length];

          while (0 < (index -= 3))
	    {
	      [intPartString insertString: [self thousandSeparator]
				  atIndex: index];
	    }
        }

      formattedNumber = [intPartString mutableCopy];

      //fix up the fractional part
      if (displayFractionalPart)
        {
          if (0 != decimalPlaces)
            {
	      NSMutableString	*ms;

              fracPart = [fracPart decimalNumberByMultiplyingByPowerOf10:
		decimalPlaces];
              ms = [[fracPart descriptionWithLocale: locale] mutableCopy];
              [ms replaceOccurrencesOfString: @"0"
		withString: @""
		options: (NSBackwardsSearch | NSAnchoredSearch)
		range: NSMakeRange(0, [ms length])];
              if ([fracPad length] > [ms length])
                {
                  NSRange fpRange;

                  fpRange = NSMakeRange([ms length],
		    ([fracPad length] - [ms length]));
                  [ms appendString:
		    [fracPad substringWithRange: fpRange]];
                  [ms replaceOccurrencesOfString: @"#"
		    withString: @""
		    options: (NSBackwardsSearch | NSAnchoredSearch)
		    range: NSMakeRange(0, [ms length])];
                  [ms replaceOccurrencesOfString: @"#"
		    withString: @"0"
		    options: 0
		    range: NSMakeRange(0, [ms length])];
                  [ms replaceOccurrencesOfString: @"_"
		    withString: @" "
		    options: 0
		    range: NSMakeRange(0, [ms length])];
                }
	      fracPartString = AUTORELEASE(ms);
            }
          else
            {
              fracPartString = @"0";
            }
          [formattedNumber appendString: [self decimalSeparator]];
          [formattedNumber appendString: fracPartString];
        }
      /*FIXME - the suffix doesn't behave the same as on Mac OS X.
       * Our suffix is everything which follows the final formatting
       * character.  Cocoa's suffix is everything which isn't a
       * formatting character nor in the prefix
       */
      suffixRange = [useFormat rangeOfCharacterFromSet: formattingCharacters
        options: NSBackwardsSearch];
      suffix = [useFormat substringFromIndex: NSMaxRange(suffixRange)];
      wholeString = [[prefix stringByAppendingString: formattedNumber]
        stringByAppendingString: suffix];
      [formattedNumber release];
      return wholeString;
    }
  return nil;
}

- (NSDictionary*) textAttributesForNegativeValues
{
  return _attributesForNegativeValues;
}

- (NSDictionary*) textAttributesForPositiveValues
{
  return _attributesForPositiveValues;
}

- (NSString*) thousandSeparator
{
  if (!_thousandSeparator)
    return @"";
  else
    return [NSString stringWithCharacters: &_thousandSeparator length: 1];
}

- (NSString *) stringFromNumber: (NSNumber *)number
{
// This is a 10.4 and above method and should not work with earlier version.
  return [self stringForObjectValue: number];
}

- (NSNumber *) numberFromString: (NSString *)string
{
// This is a 10.4 and above method and should not work with earlier version.
#if GS_USE_ICU == 1
  NSNumber *result;
  NSUInteger length;
  NSRange range;
  UErrorCode err = U_ZERO_ERROR;
  unichar *ustring;
  int64_t intNum;
  double doubleNum;
  
  if (string == nil)
    return nil;
  
  length = [string length];
  ustring = NSZoneMalloc ([self zone], sizeof(unichar) * length);
  if (ustring == NULL)
    return nil;
  
  [string getCharacters: ustring range: NSMakeRange(0, length)];
  
  // FIXME: Not sure if this is correct....
  range = [string rangeOfString: @"."];
  if (range.location == NSNotFound)
    {
      intNum = unum_parseInt64 (internal->_formatter, ustring, length, NULL, &err);
      if (U_FAILURE(err))
        return nil;
      if (intNum == 0 || intNum == 1)
        result = [NSNumber numberWithBool: (BOOL) intNum];
      else if (intNum < INT_MAX && intNum > INT_MIN)
        result = [NSNumber numberWithInt: (int32_t)intNum];
      else
        result = [NSNumber numberWithLongLong: intNum];
    }
  else
    {
      doubleNum = unum_parseDouble (internal->_formatter, ustring, length, NULL, &err);
      if (U_FAILURE(err))
        return nil;
      result = [NSNumber numberWithDouble: doubleNum];
    }
  
  NSZoneFree ([self zone], ustring);
  return result;
#else
  return nil;
#endif
}



- (void) setFormatterBehavior: (NSNumberFormatterBehavior)behavior
{
  if (NSNumberFormatterBehavior10_4 == behavior
    || NSNumberFormatterBehavior10_0 == behavior
    || NSNumberFormatterBehaviorDefault == behavior)
    {
      internal->_behavior = behavior;
    }
}

- (NSNumberFormatterBehavior)formatterBehavior
{
  return internal->_behavior;
}

+ (void) setDefaultFormatterBehavior: (NSNumberFormatterBehavior)behavior
{
  if (NSNumberFormatterBehavior10_0 == behavior)
    {
      _defaultBehavior = behavior;
    }
  else if (NSNumberFormatterBehavior10_4 == behavior
    || NSNumberFormatterBehaviorDefault == behavior)
    {
      _defaultBehavior = NSNumberFormatterBehavior10_4;
    }
  else
    {
      _defaultBehavior = behavior;	// Yeuch ... but OSX accepts any value
    }
}

+ (NSNumberFormatterBehavior) defaultFormatterBehavior
{
  return _defaultBehavior;
}

- (void) setNumberStyle: (NSNumberFormatterStyle) style
{
  internal->_style = style;
  [self _resetUNumberFormat];
}

- (NSNumberFormatterStyle) numberStyle
{
  return internal->_style;
}

- (void) setGeneratesDecimalNumbers: (BOOL) flag
{
  internal->_genDecimal = flag;
}

- (BOOL) generatesDecimalNumbers
{
  return internal->_genDecimal; // FIXME
}


- (void) setLocale: (NSLocale *) locale
{
  RELEASE(internal->_locale);
  
  if (locale == nil)
    locale = [NSLocale currentLocale];
  internal->_locale = RETAIN(locale);
  
  [self _resetUNumberFormat];
}

- (NSLocale *) locale
{
  return internal->_locale;
}


- (void) setRoundingIncrement: (NSNumber *) number
{
  switch ([number objCType][0])
    {
      case 'd':
      case 'f':
#if GS_USE_ICU == 1
    unum_setDoubleAttribute (internal->_formatter, UNUM_ROUNDING_INCREMENT,
      [number doubleValue]);
#endif
      default:
        return;
    }
}

- (NSNumber *) roundingIncrement
{
#if GS_USE_ICU == 1
  double value = unum_getDoubleAttribute (internal->_formatter, UNUM_ROUNDING_INCREMENT);
  return [NSNumber numberWithDouble: value];
#else
  return nil;
#endif
}

- (void) setRoundingMode: (NSNumberFormatterRoundingMode) mode
{
#if GS_USE_ICU == 1
  SET_ATTRIBUTE(UNUM_ROUNDING_MODE, NSToICURoundingMode(mode), NO);
#else
  return;
#endif
}

- (NSNumberFormatterRoundingMode) roundingMode
{
#if GS_USE_ICU == 1
  int result;
  GET_ATTRIBUTE(UNUM_ROUNDING_MODE, result);
  return ICUToNSRoundingMode (result);
#else
  return 0;
#endif
}


- (void) setFormatWidth: (NSUInteger) number
{
#if GS_USE_ICU == 1
  SET_ATTRIBUTE(UNUM_FORMAT_WIDTH, number, NO);
#else
  return;
#endif
}

- (NSUInteger) formatWidth
{
#if GS_USE_ICU == 1
  NSUInteger result;
  GET_ATTRIBUTE (UNUM_FORMAT_WIDTH, result);
  return result;
#else
  return 0;
#endif
}

- (void) setMultiplier: (NSNumber *) number
{
#if GS_USE_ICU == 1
  int32_t value = [number intValue];
  SET_ATTRIBUTE(UNUM_MULTIPLIER, value, NO);
#else
  return;
#endif
}

- (NSNumber *) multiplier
{
#if GS_USE_ICU == 1
  int32_t value;
  GET_ATTRIBUTE(UNUM_MULTIPLIER, value);
  return [NSNumber numberWithInt: value];
#else
  return nil;
#endif
}


- (void) setPercentSymbol: (NSString *) string
{
#if GS_USE_ICU == 1
  SET_SYMBOL(UNUM_PERCENT_SYMBOL, string, NO);
#else
  return;
#endif
}

- (NSString *) percentSymbol
{
#if GS_USE_ICU == 1
  NSString *result;
  GET_SYMBOL(UNUM_PERCENT_SYMBOL, result);
  return result;
#else
  return nil;
#endif
}

- (void) setPerMillSymbol: (NSString *) string
{
#if GS_USE_ICU == 1
  SET_SYMBOL(UNUM_PERMILL_SYMBOL, string, NO);
#else
  return;
#endif
}

- (NSString *) perMillSymbol
{
#if GS_USE_ICU == 1
  NSString *result;
  GET_SYMBOL(UNUM_PERMILL_SYMBOL, result);
  return result;
#else
  return nil;
#endif
}

- (void) setMinusSign: (NSString *) string
{
#if GS_USE_ICU == 1
  SET_SYMBOL(UNUM_MINUS_SIGN_SYMBOL, string, NO);
#else
  return;
#endif
}

- (NSString *) minusSign
{
#if GS_USE_ICU == 1
  NSString *result;
  GET_SYMBOL(UNUM_MINUS_SIGN_SYMBOL, result);
  return result;
#else
  return nil;
#endif
}

- (void) setPlusSign: (NSString *) string
{
#if GS_USE_ICU == 1
  SET_SYMBOL(UNUM_PLUS_SIGN_SYMBOL, string, NO);
#else
  return;
#endif
}

- (NSString *) plusSign
{
#if GS_USE_ICU == 1
  NSString *result;
  GET_SYMBOL(UNUM_PLUS_SIGN_SYMBOL, result);
  return result;
#else
  return nil;
#endif
}

- (void) setExponentSymbol: (NSString *) string
{
#if GS_USE_ICU == 1
  SET_SYMBOL(UNUM_EXPONENTIAL_SYMBOL, string, NO);
#else
  return;
#endif
}

- (NSString *) exponentSymbol
{
#if GS_USE_ICU == 1
  NSString *result;
  GET_SYMBOL(UNUM_EXPONENTIAL_SYMBOL, result);
  return result;
#else
  return nil;
#endif
}

- (void) setZeroSymbol: (NSString *) string
{
#if GS_USE_ICU == 1
  SET_SYMBOL(UNUM_ZERO_DIGIT_SYMBOL, string, NO);
#else
  return;
#endif
}

- (NSString *) zeroSymbol
{
#if GS_USE_ICU == 1
  NSString *result;
  GET_SYMBOL(UNUM_ZERO_DIGIT_SYMBOL, result);
  return result;
#else
  return nil;
#endif
}

- (void) setNilSymbol: (NSString *) string
{
  return; // FIXME
}

- (NSString *) nilSymbol
{
  return nil; // FIXME
}

- (void) setNotANumberSymbol: (NSString *) string
{
#if GS_USE_ICU == 1
  SET_SYMBOL(UNUM_NAN_SYMBOL, string, NO);
#else
  return;
#endif
}

- (NSString *) notANumberSymbol
{
#if GS_USE_ICU == 1
  NSString *result;
  GET_SYMBOL(UNUM_NAN_SYMBOL, result);
  return result;
#else
  return nil;
#endif
}

- (void) setNegativeInfinitySymbol: (NSString *) string
{
#if GS_USE_ICU == 1
  // FIXME: ICU doesn't differenciate between positive and negative infinity.
  SET_SYMBOL(UNUM_INFINITY_SYMBOL, string, NO);
#else
  return;
#endif
}

- (NSString *) negativeInfinitySymbol
{
#if GS_USE_ICU == 1
  NSString *result;
  GET_SYMBOL(UNUM_INFINITY_SYMBOL, result);
  return result;
#else
  return nil;
#endif
}

- (void) setPositiveInfinitySymbol: (NSString *) string
{
#if GS_USE_ICU == 1
  // FIXME: ICU doesn't differenciate between positive and negative infinity.
  SET_SYMBOL(UNUM_INFINITY_SYMBOL, string, NO);
#else
  return;
#endif
}

- (NSString *) positiveInfinitySymbol
{
#if GS_USE_ICU == 1
  NSString *result;
  GET_SYMBOL(UNUM_INFINITY_SYMBOL, result);
  return result;
#else
  return nil;
#endif
}


- (void) setCurrencySymbol: (NSString *) string
{
#if GS_USE_ICU == 1
  SET_SYMBOL(UNUM_CURRENCY_SYMBOL, string, NO);
#else
  return;
#endif
}

- (NSString *) currencySymbol
{
#if GS_USE_ICU == 1
  NSString *result;
  GET_SYMBOL(UNUM_CURRENCY_SYMBOL, result);
  return result;
#else
  return nil;
#endif
}

- (void) setCurrencyCode: (NSString *) string
{
#if GS_USE_ICU == 1
  SET_SYMBOL(UNUM_CURRENCY_CODE, string, NO);
#else
  return;
#endif
}

- (NSString *) currencyCode
{
#if GS_USE_ICU == 1
  NSString *result;
  GET_TEXTATTRIBUTE(UNUM_CURRENCY_CODE, result);
  return result;
#else
  return nil;
#endif
}

- (void) setInternationalCurrencySymbol: (NSString *) string
{
#if GS_USE_ICU == 1
  SET_SYMBOL(UNUM_INTL_CURRENCY_SYMBOL, string, NO);
#else
  return;
#endif
}

- (NSString *) internationalCurrencySymbol
{
#if GS_USE_ICU == 1
  NSString *result;
  GET_SYMBOL(UNUM_INTL_CURRENCY_SYMBOL, result);
  return result;
#else
  return nil;
#endif
}


- (void) setPositivePrefix: (NSString *) string
{
#if GS_USE_ICU == 1
  SET_TEXTATTRIBUTE(UNUM_POSITIVE_PREFIX, string, NO);
#else
  return;
#endif
}

- (NSString *) positivePrefix
{
#if GS_USE_ICU == 1
  NSString *result;
  GET_TEXTATTRIBUTE(UNUM_POSITIVE_PREFIX, result);
  return result;
#else
  return nil;
#endif
}

- (void) setPositiveSuffix: (NSString *) string
{
#if GS_USE_ICU == 1
  SET_TEXTATTRIBUTE(UNUM_POSITIVE_SUFFIX, string, NO);
#else
  return;
#endif
}

- (NSString *) positiveSuffix
{
#if GS_USE_ICU == 1
  NSString *result;
  GET_TEXTATTRIBUTE(UNUM_POSITIVE_SUFFIX, result);
  return result;
#else
  return nil;
#endif
}

- (void) setNegativePrefix: (NSString *) string
{
#if GS_USE_ICU == 1
  SET_TEXTATTRIBUTE(UNUM_NEGATIVE_PREFIX, string, NO);
#else
  return;
#endif
}

- (NSString *) negativePrefix
{
#if GS_USE_ICU == 1
  NSString *result;
  GET_TEXTATTRIBUTE(UNUM_NEGATIVE_PREFIX, result);
  return result;
#else
  return nil;
#endif
}

- (void) setNegativeSuffix: (NSString *) string
{
#if GS_USE_ICU == 1
  SET_TEXTATTRIBUTE(UNUM_NEGATIVE_SUFFIX, string, NO);
#else
  return;
#endif
}

- (NSString *) negativeSuffix
{
#if GS_USE_ICU == 1
  NSString *result;
  GET_TEXTATTRIBUTE(UNUM_NEGATIVE_SUFFIX, result);
  return result;
#else
  return nil;
#endif
}


- (void) setTextAttributesForZero: (NSDictionary *) newAttributes
{
  return;  // FIXME
}

- (NSDictionary *) textAttributesForZero
{
  return nil; // FIXME
}

- (void) setTextAttributesForNil: (NSDictionary *) newAttributes
{
  return;
}

- (NSDictionary *) textAttributesForNil
{
  return nil; // FIXME
}

- (void) setTextAttributesForNotANumber: (NSDictionary *) newAttributes
{
  return; // FIXME
}

- (NSDictionary *) textAttributesForNotANumber
{
  return nil; // FIXME
}

- (void) setTextAttributesForPositiveInfinity: (NSDictionary *) newAttributes
{
  return; // FIXME
}

- (NSDictionary *) textAttributesForPositiveInfinity
{
  return nil; // FIXME
}

- (void) setTextAttributesForNegativeInfinity: (NSDictionary *) newAttributes
{
  return; // FIXME
}

- (NSDictionary *) textAttributesForNegativeInfinity
{
  return nil; // FIXME
}


- (void) setGroupingSeparator: (NSString *) string
{
#if GS_USE_ICU == 1
  SET_SYMBOL(UNUM_GROUPING_SEPARATOR_SYMBOL, string, NO);
#else
  return;
#endif
}

- (NSString *) groupingSeparator
{
#if GS_USE_ICU == 1
  NSString *result;
  GET_SYMBOL(UNUM_GROUPING_SEPARATOR_SYMBOL, result);
  return result;
#else
  return nil;
#endif
}

- (void) setUsesGroupingSeparator: (BOOL) flag
{

#if GS_USE_ICU == 1
  SET_ATTRIBUTE(UNUM_GROUPING_USED, flag, NO);
#else
  return;
#endif
}

- (BOOL) usesGroupingSeparator
{
#if GS_USE_ICU == 1
  int result;
  GET_ATTRIBUTE(UNUM_GROUPING_USED, result);
  return (BOOL)result;
#else
  return NO;
#endif
}

- (void) setAlwaysShowsDecimalSeparator: (BOOL) flag
{
#if GS_USE_ICU == 1
  SET_ATTRIBUTE(UNUM_DECIMAL_ALWAYS_SHOWN, flag, NO);
#else
  return;
#endif
}

- (BOOL) alwaysShowsDecimalSeparator
{
#if GS_USE_ICU == 1
  int result;
  GET_ATTRIBUTE(UNUM_DECIMAL_ALWAYS_SHOWN, result);
  return (BOOL)result;
#else
  return NO;
#endif
}

- (void) setCurrencyDecimalSeparator: (NSString *) string
{
#if GS_USE_ICU == 1
  SET_SYMBOL(UNUM_MONETARY_SEPARATOR_SYMBOL, string, NO);
#else
  return;
#endif
}

- (NSString *) currencyDecimalSeparator
{
#if GS_USE_ICU == 1
  NSString *result;
  GET_SYMBOL(UNUM_MONETARY_SEPARATOR_SYMBOL, result);
  return result;
#else
  return nil;
#endif
}

- (void) setGroupingSize: (NSUInteger) number
{
#if GS_USE_ICU == 1
  SET_ATTRIBUTE(UNUM_GROUPING_SIZE, number, NO);
#else
  return;
#endif
}

- (NSUInteger) groupingSize
{
#if GS_USE_ICU == 1
  int32_t result;
  GET_ATTRIBUTE(UNUM_GROUPING_SIZE, result);
  return (NSUInteger)result;
#else
  return 3;
#endif
}

- (void) setSecondaryGroupingSize: (NSUInteger) number
{
#if GS_USE_ICU == 1
  SET_ATTRIBUTE(UNUM_SECONDARY_GROUPING_SIZE, number, NO);
#else
  return;
#endif
}

- (NSUInteger) secondaryGroupingSize
{
#if GS_USE_ICU == 1
  int32_t result;
  GET_ATTRIBUTE(UNUM_SECONDARY_GROUPING_SIZE, result);
  return (NSUInteger)result;
#else
  return 3;
#endif
}


- (void) setPaddingCharacter: (NSString *) string
{
#if GS_USE_ICU == 1
  SET_TEXTATTRIBUTE(UNUM_PADDING_CHARACTER, string, NO);
#else
  return;
#endif
}

- (NSString *) paddingCharacter
{
#if GS_USE_ICU == 1
  NSString *result;
  GET_TEXTATTRIBUTE(UNUM_PADDING_CHARACTER, result);
  return result;
#else
  return nil;
#endif
}

- (void) setPaddingPosition: (NSNumberFormatterPadPosition) position
{
#if GS_USE_ICU == 1
  SET_ATTRIBUTE(UNUM_PADDING_POSITION, NSToICUPadPosition(position),  NO);
#else
  return;
#endif
}

- (NSNumberFormatterPadPosition) paddingPosition
{
#if GS_USE_ICU == 1
  int32_t result;
  GET_ATTRIBUTE(UNUM_PADDING_POSITION, result);
  return ICUToNSPadPosition(result);
#else
  return 0;
#endif
}


- (void) setMinimumIntegerDigits: (NSUInteger) number
{
#if GS_USE_ICU == 1
  SET_ATTRIBUTE(UNUM_MIN_INTEGER_DIGITS, number, NO);
#else
  return;
#endif
}

- (NSUInteger) minimumIntegerDigits
{
#if GS_USE_ICU == 1
  int32_t result;
  GET_ATTRIBUTE(UNUM_MIN_INTEGER_DIGITS, result);
  return (NSUInteger)result;
#else
  return 0;
#endif
}

- (void) setMinimumFractionDigits: (NSUInteger) number
{
#if GS_USE_ICU == 1
  SET_ATTRIBUTE(UNUM_MIN_FRACTION_DIGITS, number, NO);
#else
  return;
#endif
}

- (NSUInteger) minimumFractionDigits
{
#if GS_USE_ICU == 1
  int32_t result;
  GET_ATTRIBUTE(UNUM_MIN_FRACTION_DIGITS, result);
  return (NSUInteger)result;
#else
  return 0;
#endif
}

- (void) setMaximumIntegerDigits: (NSUInteger) number
{
#if GS_USE_ICU == 1
  SET_ATTRIBUTE(UNUM_MAX_INTEGER_DIGITS, number, NO);
#else
  return;
#endif
}

- (NSUInteger) maximumIntegerDigits
{
#if GS_USE_ICU == 1
  int32_t result;
  GET_ATTRIBUTE(UNUM_MAX_INTEGER_DIGITS, result);
  return (NSUInteger)result;
#else
  return 0;
#endif
}

- (void) setMaximumFractionDigits: (NSUInteger) number
{
#if GS_USE_ICU == 1
  SET_ATTRIBUTE(UNUM_MAX_FRACTION_DIGITS, number, NO);
#else
  return;
#endif
}

- (NSUInteger) maximumFractionDigits
{
#if GS_USE_ICU == 1
  int result;
  GET_ATTRIBUTE(UNUM_MAX_FRACTION_DIGITS, result);
  return (NSUInteger)result;
#else
  return 0;
#endif
}


- (BOOL) getObjectValue: (out id *) anObject
              forString: (NSString *) aString
                  range: (NSRange *) rangep
                  error: (out NSError **) error
{
#if GS_USE_ICU == 1
  BOOL result;
  BOOL genDec = [self generatesDecimalNumbers];
  NSUInteger inLen;
  int32_t parsePos = rangep->location;
  UChar inBuffer[BUFFER_SIZE];
  UErrorCode err = U_ZERO_ERROR;
  
  inLen = [aString length];
  if (inLen > BUFFER_SIZE)
    inLen = BUFFER_SIZE;
  [aString getCharacters: inBuffer range: NSMakeRange(0, inLen)];
  
  if (genDec)  // Generate decimal number?  This should be the default.
    {
      int32_t outLen;
      char outBuffer[BUFFER_SIZE];
      
      outLen = 
        unum_parseDecimal (internal->_formatter, inBuffer, inLen, &parsePos,
          outBuffer, BUFFER_SIZE-1, &err);
      if (U_SUCCESS(err))
        {
          NSString *outStr = [NSString stringWithCString: outBuffer
                                                  length: outLen];
          *anObject = [NSDecimalNumber decimalNumberWithString: outStr];
          result = YES;
        }
      else
        {
          if (error)
            *error = [NSError errorWithDomain: @"NSNumberFormatterParseError"
                                         code: err
                                     userInfo: nil];
          *anObject = nil;
          *rangep = NSMakeRange (rangep->location, parsePos);
          result = NO;
        }
    }
  else  // If not generating NSDecimalNumber use unum_parseDouble()
    {
      double output;
      
      output = 
        unum_parseDouble (internal->_formatter, inBuffer, inLen, &parsePos,
          &err);
      if (U_SUCCESS(err))
        {
          *anObject = [NSNumber numberWithDouble: output];
          result = YES;
        }
      else
        {
          if (error)
            *error = [NSError errorWithDomain: @"NSNumberFormatterParseError"
                                         code: err
                                     userInfo: nil];
          *anObject = nil;
          *rangep = NSMakeRange (rangep->location, parsePos);
          result = NO;
        }
    }
  
  return result;
#else
  return NO;
#endif
}


- (void) setUsesSignificantDigits: (BOOL) flag
{
#if GS_USE_ICU == 1
  SET_ATTRIBUTE(UNUM_SIGNIFICANT_DIGITS_USED, flag, NO);
#else
  return;
#endif
}

- (BOOL) usesSignificantDigits
{
#if GS_USE_ICU == 1
  int32_t result;
  GET_ATTRIBUTE(UNUM_SIGNIFICANT_DIGITS_USED, result);
  return (BOOL)result;
#else
  return NO;
#endif
}

- (void) setMinimumSignificantDigits: (NSUInteger) number
{
#if GS_USE_ICU == 1
  SET_ATTRIBUTE(UNUM_MIN_SIGNIFICANT_DIGITS, number, NO);
#else
  return;
#endif
}

- (NSUInteger) minimumSignificantDigits
{
#if GS_USE_ICU == 1
  int32_t result;
  GET_ATTRIBUTE(UNUM_MIN_SIGNIFICANT_DIGITS, result);
  return (NSUInteger)result;
#else
  return 0;
#endif
}

- (void) setMaximumSignificantDigits: (NSUInteger) number
{
#if GS_USE_ICU == 1
  SET_ATTRIBUTE(UNUM_MAX_SIGNIFICANT_DIGITS, number, NO);
#else
  return;
#endif
}

- (NSUInteger) maximumSignificantDigits
{
#if GS_USE_ICU == 1
  int32_t result;
  GET_ATTRIBUTE(UNUM_MAX_SIGNIFICANT_DIGITS, result);
  return (NSUInteger)result;
#else
  return 0;
#endif
}


- (void) setCurrencyGroupingSeparator: (NSString *) string
{
#if GS_USE_ICU == 1
  SET_SYMBOL(UNUM_MONETARY_GROUPING_SEPARATOR_SYMBOL, string, NO);
#else
  return;
#endif
}

- (NSString *) currencyGroupingSeparator
{
#if GS_USE_ICU == 1
  NSString *result;
  GET_SYMBOL(UNUM_MONETARY_GROUPING_SEPARATOR_SYMBOL, result);
  return result;
#else
  return nil;
#endif
}


- (void) setLenient: (BOOL) flag
{
#if GS_USE_ICU == 1
  SET_ATTRIBUTE(UNUM_LENIENT_PARSE, flag, NO);
#else
  return;
#endif
}

- (BOOL) isLenient
{
#if GS_USE_ICU == 1
  int32_t result;
  GET_ATTRIBUTE(UNUM_LENIENT_PARSE, result);
  return (BOOL)result;
#else
  return NO;
#endif
}


- (void) setPartialStringValidationEnabled: (BOOL) enabled
{
  return;
}

- (BOOL) isPartialStringValidationEnabled
{
  return NO;
}


+ (NSString *) localizedStringFromNumber: (NSNumber *) num
    numberStyle: (NSNumberFormatterStyle) localizationStyle
{
#if GS_USE_ICU == 1
  NSNumberFormatter *fmt;
  NSString *result;
  
  fmt = [[NSNumberFormatter alloc] init];
  [fmt setLocale: [NSLocale currentLocale]];
  [fmt setNumberStyle: localizationStyle];
  
  result = [fmt stringFromNumber: num];
  RELEASE(fmt);
  return result;
#else
  return nil;
#endif
}

@end

@implementation NSNumberFormatter (PrivateMethods)
- (void) _resetUNumberFormat
{
#if GS_USE_ICU == 1
  UNumberFormatStyle style;
  UErrorCode err = U_ZERO_ERROR;
  const char *cLocaleId;
  int32_t idx;
  
  if (internal->_formatter)
    unum_close(internal->_formatter);
  
  cLocaleId = [[internal->_locale localeIdentifier] UTF8String];
  style = NSToICUFormatStyle (internal->_style);
  
  internal->_formatter = unum_open (style, NULL, 0, cLocaleId, NULL, &err);
  if (U_FAILURE(err))
    internal->_formatter = NULL;
  
  // Reset all properties
  for (idx = 0 ; idx < MAX_SYMBOLS ; ++idx)
    SET_SYMBOL(idx, internal->_symbols[idx], YES);
  for (idx = 0 ; idx < MAX_TEXTATTRIBUTES ; ++idx)
    SET_TEXTATTRIBUTE(idx, internal->_textAttributes[idx], YES);
  for (idx = 0 ; idx < MAX_ATTRIBUTES ; ++idx)
    SET_ATTRIBUTE(idx, internal->_attributes[idx], YES);
#else
  return;
#endif
}
@end
