/**
   NSNumberFormatter class
   Copyright (C) 2000 Free Software Foundation, Inc.

   Written by: Fred Kiefer <FredKiefer@gmx.de>
   Created: July 2000
   Updated by: Richard Frith-Macdonald <rfm@gnu.org> Sept 2001

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
   Software Foundation, Inc., 51 Franklin Street, Fifth Floor,
   Boston, MA 02111 USA.

   <title>NSNumberFormatter class reference</title>
   $Date$ $Revision$
   */

#include "Foundation/NSAttributedString.h"
#include "Foundation/NSDecimalNumber.h"
#include "Foundation/NSDictionary.h"
#include "Foundation/NSException.h"
#include "Foundation/NSNumberFormatter.h"
#include "Foundation/NSString.h"
#include "Foundation/NSUserDefaults.h"


@implementation NSNumberFormatter

- (BOOL) allowsFloats
{
  return _allowsFloats;
}

- (NSAttributedString*) attributedStringForObjectValue: (id)anObject
				 withDefaultAttributes: (NSDictionary*)attr
{
  float val;

  if (anObject == nil)
    {
      return [self attributedStringForNil];
    }
  else if (![anObject isKindOfClass: [NSNumber class]])
    {
      return [self attributedStringForNotANumber];
    }
  else if ([anObject intValue] == 0)
    {
      return [self attributedStringForZero];
    }

  val = [anObject intValue];
  if ((val > 0) && (_attributesForPositiveValues))
    {
      attr = _attributesForPositiveValues;
    }
  else if ((val < 0) && (_attributesForNegativeValues))
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
  NSNumberFormatter	*c = (NSNumberFormatter*) NSCopyObject(self, 0, zone);

  RETAIN(c->_negativeFormat);
  RETAIN(c->_positiveFormat);
  RETAIN(c->_attributesForPositiveValues);
  RETAIN(c->_attributesForNegativeValues);
  RETAIN(c->_maximum);
  RETAIN(c->_minimum);
  RETAIN(c->_roundingBehavior);
  RETAIN(c->_roundingBehavior);
  RETAIN(c->_attributedStringForNil);
  RETAIN(c->_attributedStringForNotANumber);
  RETAIN(c->_attributedStringForZero);

  return c;
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
  RELEASE(_roundingBehavior);
  RELEASE(_attributedStringForNil);
  RELEASE(_attributedStringForNotANumber);
  RELEASE(_attributedStringForZero);
  [super dealloc];
}

- (NSString*) decimalSeparator
{
  if (_decimalSeparator == 0)
    return @"";
  else
    return [NSString stringWithCharacters: &_decimalSeparator length: 1];
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

  /* Just assume nothing else has been setup and do a simple conversion. */
  if ([self hasThousandSeparators])
    {
      NSRange range;
      
      range = [string rangeOfString: [self thousandSeparator]];
      if (range.length != 0)
        {
	  string = AUTORELEASE([string mutableCopy]);
	  [(NSMutableString*)string replaceOccurrencesOfString: [self thousandSeparator]
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

  _allowsFloats = YES;
  _decimalSeparator = '.';
  _thousandSeparator = ',';
  o = [[NSAttributedString alloc] initWithString: @""];
  [self setAttributedStringForNil: o];
  RELEASE(o);
  o = [[NSAttributedString alloc] initWithString: @"NaN"];
  [self setAttributedStringForNotANumber: o];
  RELEASE(o);

  return self;
}

- (id) initWithCoder: (NSCoder*)decoder
{
  if ([decoder allowsKeyedCoding])
    {
      if ([decoder containsValueForKey: @"NS.allowsfloats"])
        {
	  [self setAllowsFloats: [decoder decodeBoolForKey: @"NS.allowsfloats"]];
	}
      if ([decoder containsValueForKey: @"NS.decimal"])
        {
	  [self setDecimalSeparator: [decoder decodeObjectForKey: @"NS.decimal"]];
	}
      if ([decoder containsValueForKey: @"NS.hasthousands"])
        {
	  [self setHasThousandSeparators: [decoder decodeBoolForKey: @"NS.hasthousands"]];
	}
      if ([decoder containsValueForKey: @"NS.localized"])
        {
	  [self setLocalizesFormat: [decoder decodeBoolForKey: @"NS.localized"]];
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
	  [self setAttributedStringForNotANumber: [decoder decodeObjectForKey: @"NS.nan"]];
	}
      if ([decoder containsValueForKey: @"NS.negativeattrs"])
        {
	  [self setTextAttributesForNegativeValues: [decoder decodeObjectForKey: @"NS.negativeattrs"]];
	}
      if ([decoder containsValueForKey: @"NS.negativeformat"])
        {
	  [self setNegativeFormat: [decoder decodeObjectForKey: @"NS.negativeformat"]];
	}
      if ([decoder containsValueForKey: @"NS.nil"])
        {
	  [self setAttributedStringForNil: [decoder decodeObjectForKey: @"NS.nil"]];
	}
      if ([decoder containsValueForKey: @"NS.positiveattrs"])
        {
	  [self setTextAttributesForPositiveValues: [decoder decodeObjectForKey: @"NS.positiveattrs"]];
	}
      if ([decoder containsValueForKey: @"NS.positiveformat"])
        {
	  [self setPositiveFormat: [decoder decodeObjectForKey: @"NS.positiveformat"]];
	}
      if ([decoder containsValueForKey: @"NS.rounding"])
        {
	  [self setRoundingBehavior: [decoder decodeObjectForKey: @"NS.rounding"]];
	}
      if ([decoder containsValueForKey: @"NS.thousand"])
        {
	  [self setThousandSeparator: [decoder decodeObjectForKey: @"NS.thousand"]];
	}
      if ([decoder containsValueForKey: @"NS.zero"])
        {
	  [self setAttributedStringForZero: [decoder decodeObjectForKey: @"NS.zero"]];
	}
    }
  else
    {
      [decoder decodeValueOfObjCType: @encode(BOOL) at: &_hasThousandSeparators];
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
      [decoder decodeValueOfObjCType: @encode(id) at: &_attributedStringForZero];
      [decoder decodeValueOfObjCType: @encode(id) at: &_negativeFormat];
      [decoder decodeValueOfObjCType: @encode(id) at: &_positiveFormat];
      [decoder decodeValueOfObjCType: @encode(id)
	                          at: &_attributesForPositiveValues];
      [decoder decodeValueOfObjCType: @encode(id)
	                          at: &_attributesForNegativeValues];
    }
  return self;
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
  if ([newSeparator length] > 0)
    _decimalSeparator = [newSeparator characterAtIndex: 0];
  else
    _decimalSeparator = 0;
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
  ASSIGN(_maximum, aMaximum);
}

- (void) setMinimum: (NSDecimalNumber*)aMinimum
{
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
  NSMutableDictionary *locale;

  if (nil == anObject)
    return [[self attributedStringForNil] string];

  /* FIXME: This is just a quick hack implementation.  */
  NSLog(@"NSNumberFormatter-stringForObjectValue:... not fully implemented");

  locale = [NSMutableDictionary dictionaryWithCapacity: 3];
  if ([self hasThousandSeparators])
    {
      [locale setObject: [self thousandSeparator] forKey: NSThousandsSeparator];
    }

  if ([self allowsFloats])
    {
      [locale setObject: [self decimalSeparator] forKey: NSDecimalSeparator];
      // Should also set: NSDecimalDigits
    }

  return [anObject descriptionWithLocale: locale];
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

@end
